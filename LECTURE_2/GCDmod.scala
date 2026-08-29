package chipyard.GCDmod.src.main.scala

import Chisel._
import GCDmod.src.main.scala.GCDRegs
import chisel3.WireInit
import chisel3.util.HasBlackBoxResource
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.regmapper.{RegField, RegFieldDesc}
import freechips.rocketchip.subsystem.BaseSubsystem
import freechips.rocketchip.tilelink.{TLFragmenter, TLRegisterNode}
import freechips.rocketchip.util.ElaborationArtefacts
import org.chipsalliance.cde.config._


case class GCDParams
(
  Addr: BigInt = 0x06400000,
  dataWidth: Int = 64
){}

case object GCDKeys extends Field[Option[GCDParams]](None)

class GCD()(implicit p: Parameters) extends BlackBox with HasBlackBoxResource {
  override def desiredName = "GCD"
  val io = IO (new Bundle{
    val iClk    = Input(Clock())
    val iRst    = Input(Bool())
    val iValid  = Input(Bool())
    val iA      = Input(UInt(16.W))
    val iB      = Input(UInt(16.W))
    val oValid  = Output(Bool())
    val oReady  = Output(Bool())
    val oC      = Output(UInt(16.W))
  })
  addResource("/vsrc/GCD.v")
}

class GCDDevice(val params: GCDParams, beatBytes: Int = 8)(implicit p: Parameters)
  extends LazyModule {
  val device = new SimpleDevice("GCDmod", Seq("SoC,GCD"))
  val mmioNode = TLRegisterNode(
    address   = Seq(AddressSet(params.Addr, 4096-1)),
    device    = device,
    beatBytes = beatBytes,
    concurrency = 1
  )
  lazy val module = new GCDDeviceImp(this)
}


class GCDDeviceImp(outer: GCDDevice)(implicit p: Parameters)
  extends LazyModuleImp(outer) {

  val params = outer.params
  val gcd = Module(new GCD())

  // ==== MMIO Registers ====
  val r_reset     = RegInit(false.B)
  val r_in_valid  = RegInit(false.B)
  val r_data_a    = RegInit(0.U(params.dataWidth.W))
  val r_data_b    = RegInit(0.U(params.dataWidth.W))
  val r_data_c    = WireInit(0.U(params.dataWidth.W))
  val r_out_valid = WireInit(false.B)
  val r_out_ready = WireInit(false.B)

  gcd.io.iClk   := clock
  gcd.io.iRst   := r_reset
  gcd.io.iValid := r_in_valid
  gcd.io.iA     := r_data_a
  gcd.io.iB     := r_data_b

  r_out_valid   := gcd.io.oValid
  r_data_c      := RegEnable(gcd.io.oC, r_out_valid)
  r_out_ready   := gcd.io.oReady

  // ==== MMIO Mapping ====
  outer.mmioNode.regmap(
    GCDRegs.trigger   -> Seq(
      RegField(1, r_in_valid, RegFieldDesc("r_in_valid", "GCD trigger")),
      RegField(7),
      RegField(1, r_reset, RegFieldDesc("r_reset", "GCD reset", reset = Some(0)))),
    GCDRegs.data_a    -> Seq(RegField(16, r_data_a, RegFieldDesc("r_data_a", "input A"))),
    GCDRegs.data_b    -> Seq(RegField(16, r_data_b, RegFieldDesc("r_data_b", "input B"))),
    GCDRegs.data_c    -> Seq(RegField.r(16, r_data_c, RegFieldDesc("r_data_c", "output C", volatile = true))),
    GCDRegs.status    -> Seq(RegField.r(1, r_out_ready, RegFieldDesc("r_out_ready", "output ready", volatile = true)))
  )
}



























object GCDID{
  val nextId = {
    var i = -1; () => {
      i += 1; i
    }
  }
}

trait CanHavePeripheryGCDmod{ this: BaseSubsystem =>
  private val portName = "gcd"

  val GCDDeviceOpt: Option[GCDDevice] = p(GCDKeys).map {params =>
    val gcdWrapper = LazyModule( new GCDDevice(params, pbus.beatBytes)(p))
    pbus.coupleTo(s"gcd_mmio_at_${params.Addr.toString(16)}") {
      gcdWrapper.mmioNode := TLFragmenter(pbus) := _
    }
    gcdWrapper
  }
}

class WithGCDmod (base: BigInt = 0x06400000, width: Int = 64) extends Config((site, here, up) => {
  case GCDKeys => Some(GCDParams(Addr = base, dataWidth = width))
})
