package chipyard.KECCAK

import Chisel._
import KECCAK.keccakRegs
import chisel3.WireInit
import chisel3.util.HasBlackBoxResource
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.regmapper.{RegField, RegFieldDesc}
import freechips.rocketchip.subsystem.BaseSubsystem
import freechips.rocketchip.tilelink.{TLFragmenter, TLRegisterNode}
import freechips.rocketchip.util.ElaborationArtefacts
import org.chipsalliance.cde.config._


case class KECCAKParams
(
  Addr: BigInt = 0x06400000,
  dataWidth: Int = 64
){}

case object KECCAKKeys extends Field[Option[KECCAKParams]](None)

class pqc_keccak_top_general()(implicit p: Parameters) extends BlackBox with HasBlackBoxResource {
  override def desiredName = "pqc_keccak_top_general"
  val io = IO (new Bundle{
    val iClk          = Input(Clock())
    val iRst          = Input(Bool())
    val iWriteEn      = Input(Bool())
    val iWriteData    = Input(UInt(64.W))
    val iDataLen      = Input(UInt(12.W))
    val iEndPacket    = Input(Bool())
    val iFinalPacket  = Input(Bool())
    val iReadEn       = Input(Bool())
    val iReadDone     = Input(Bool())
    val iMode         = Input(UInt(3.W))

    val oInReady      = Output(Bool())
    val oReadData     = Output(UInt(64.W))
    val oDigestValid  = Output(Bool())
    val oOutReady     = Output(Bool())
  })
  addResource("/keccak_vsrc/pqc_keccak_top_general.v")
  addResource("/keccak_vsrc/sha3.v")
  addResource("/keccak_vsrc/keccak_f.v")
}

class KECCAKDevice(val params: KECCAKParams, beatBytes: Int = 8)(implicit p: Parameters)
  extends LazyModule {
  val device = new SimpleDevice("KECCAK", Seq("SoC,KECCAK"))
  val mmioNode = TLRegisterNode(
    address   = Seq(AddressSet(params.Addr, 4096-1)),
    device    = device,
    beatBytes = beatBytes,
    concurrency = 1
  )
  lazy val module = new KECCAKDeviceImp(this)
}


class KECCAKDeviceImp(outer: KECCAKDevice)(implicit p: Parameters)
  extends LazyModuleImp(outer) {

  val params = outer.params
  val keccak = Module(new pqc_keccak_top_general())

  // ==== MMIO Registers ====
  val r_reset         = RegInit(false.B)
  val r_wr_enable     = RegInit(false.B)
  val r_wr_data       = RegInit(0.U(params.dataWidth.W))
  val r_data_len      = RegInit(0.U(12.W))
  val r_end_packet    = RegInit(false.B)
  val r_final_packet  = RegInit(false.B)
  val r_in_ready      = WireInit(false.B)

  val r_rd_enable     = RegInit(false.B)
  val r_rd_done       = RegInit(false.B)
  val r_rd_data       = WireInit(0.U(params.dataWidth.W))
  val r_out_valid     = WireInit(false.B)
  val r_out_ready     = WireInit(false.B)
  val r_mode          = RegInit(0.U(3.W))

  keccak.io.iClk          := clock
  keccak.io.iRst          := r_reset
  keccak.io.iWriteEn      := r_wr_enable
  keccak.io.iWriteData    := r_wr_data
  keccak.io.iDataLen      := r_data_len
  keccak.io.iEndPacket    := r_end_packet
  keccak.io.iFinalPacket  := r_final_packet
  keccak.io.iMode         := r_mode
  keccak.io.iReadEn       := r_rd_enable
  keccak.io.iReadDone     := r_rd_done

  r_in_ready              := keccak.io.oInReady
  r_rd_data               := keccak.io.oReadData
  r_out_valid             := keccak.io.oDigestValid
  r_out_ready             := keccak.io.oOutReady
  // ==== MMIO Mapping ====
  outer.mmioNode.regmap(
    keccakRegs.rst          -> Seq(RegField(1, r_reset, RegFieldDesc("r_reset", "reset"))),
    keccakRegs.write_enable -> Seq(RegField(1, r_wr_enable, RegFieldDesc("r_wr_enable", "r_wr_enable"))),
    keccakRegs.write_data   -> Seq(RegField(params.dataWidth, r_wr_data, RegFieldDesc("r_wr_data", "r_wr_data"))),
    keccakRegs.data_len     -> Seq(RegField(12, r_data_len, RegFieldDesc("r_data_len", "r_data_len"))),
    keccakRegs.end_packet   -> Seq(RegField(1, r_end_packet, RegFieldDesc("r_end_packet", "r_end_packet"))),
    keccakRegs.final_packet -> Seq(RegField(1, r_final_packet, RegFieldDesc("r_final_packet", "r_final_packet"))),
    keccakRegs.mode         -> Seq(RegField(3, r_mode, RegFieldDesc("r_mode", "r_mode"))),
    keccakRegs.read_enable  -> Seq(RegField(1, r_rd_enable, RegFieldDesc("r_rd_enable", "r_rd_enable"))),
    keccakRegs.read_done    -> Seq(RegField(1, r_rd_done, RegFieldDesc("r_rd_done", "r_rd_done"))),

    keccakRegs.in_ready     -> Seq(RegField.r(1, r_in_ready, RegFieldDesc("r_in_ready", "r_in_ready"))),
    keccakRegs.read_data    -> Seq(RegField.r(params.dataWidth, r_rd_data, RegFieldDesc("r_rd_data", "r_rd_data"))),
    keccakRegs.out_valid    -> Seq(RegField.r(1, r_out_valid, RegFieldDesc("r_out_valid", "r_out_valid"))),
    keccakRegs.out_ready    -> Seq(RegField.r(1, r_out_ready, RegFieldDesc("r_out_ready", "r_out_ready"))),
  )
}

object KECCAKID{
  val nextId = {
    var i = -1; () => {
      i += 1; i
    }
  }
}

trait CanHavePeripheryKECCAK{ this: BaseSubsystem =>
  private val portName = "keccak"

  val keccakDeviceOpt: Option[KECCAKDevice] = p(KECCAKKeys).map {params =>
    val keccakWrapper = LazyModule( new KECCAKDevice(params, pbus.beatBytes)(p))
    pbus.coupleTo(s"keccak_mmio_at_${params.Addr.toString(16)}") {
      keccakWrapper.mmioNode := TLFragmenter(pbus) := _
    }
    keccakWrapper
  }
}

class WithKECCAK(base: BigInt = 0x06400000, width: Int = 64) extends Config((site, here, up) => {
  case KECCAKKeys => Some(KECCAKParams(Addr = base, dataWidth = width))
})
