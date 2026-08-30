//see LICENSE for license
//authors: Colin Schmidt, Adam Izraelevitz
package AdderRocc

import Chisel._
import freechips.rocketchip.tile._
import org.chipsalliance.cde.config._
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.rocket.{TLBConfig, HellaCacheReq}
import freechips.rocketchip.tile.{RoCCIO, LazyRoCC, LazyRoCCModuleImp, OpcodeSet, BuildRoCC}


case object AdderRoccFastMem extends Field[Boolean]
case object AdderRoccPrintfEnable extends Field[Boolean](false)

class AdderRoccAccel(opcodes: OpcodeSet)(implicit p: Parameters) extends LazyRoCC(
    opcodes = opcodes, nPTWPorts = if (p(AdderRoccTLB).isDefined) 1 else 0) {
  override lazy val module = new AdderRoccAccelImp(this)
  val dmemOpt = p(AdderRoccTLB).map { _ =>
    val dmem = LazyModule(new DmemModule)
    tlNode := dmem.node
    dmem
  }
}

class AdderRoccAccelImp(outer: AdderRoccAccel)(implicit p: Parameters) extends LazyRoCCModuleImp(outer) {

  chisel3.dontTouch(io)
  io.resp.valid := Bool(false)
  val ctrl = Module(new CtrlModule()(p))

    ctrl.io.rocc_req_val   <> io.cmd.valid
    io.cmd.ready := ctrl.io.rocc_req_rdy
    ctrl.io.rocc_funct     <> io.cmd.bits.inst.funct
    ctrl.io.rocc_rs1       <> io.cmd.bits.rs1
    ctrl.io.rocc_rs2       <> io.cmd.bits.rs2
    ctrl.io.rocc_rd        <> io.cmd.bits.inst.rd
    io.busy := ctrl.io.busy

    val status = RegEnable(io.cmd.bits.status, io.cmd.fire())
    val dmem_data = Wire(Bits())
    def dmem_ctrl(req: DecoupledIO[HellaCacheReq]) {
      req.valid := ctrl.io.dmem_req_val
      ctrl.io.dmem_req_rdy := req.ready
      req.bits.tag := ctrl.io.dmem_req_tag
      req.bits.addr := ctrl.io.dmem_req_addr
      req.bits.cmd := ctrl.io.dmem_req_cmd
      req.bits.size := ctrl.io.dmem_req_size
      req.bits.data := dmem_data
      req.bits.signed := Bool(false)
      req.bits.dprv := status.dprv
      req.bits.dv := status.dv
      req.bits.phys := Bool(false)
    }

    outer.dmemOpt match {
      case Some(m) => {
        val dmem = m.module
        dmem_ctrl(dmem.io.req)
        io.mem.req <> dmem.io.mem
        io.ptw.head <> dmem.io.ptw

        dmem.io.status := status
        dmem.io.sfence := ctrl.io.sfence
      }
      case None => dmem_ctrl(io.mem.req)
    }

    ctrl.io.dmem_resp_val  <> io.mem.resp.valid
    ctrl.io.dmem_resp_tag  <> io.mem.resp.bits.tag
    ctrl.io.dmem_resp_data := io.mem.resp.bits.data

    dmem_data := ctrl.io.out_data
}


class WithAdderRoccAccel(fastMem: Boolean = true) extends Config ((site, here, up) => {
  case AdderRoccFastMem => fastMem
  case AdderRoccTLB => Some(TLBConfig(nSets = 1, nWays = 4, nSectors = 1, nSuperpageEntries = 1))
  case BuildRoCC => up(BuildRoCC) ++ Seq(
    (p: Parameters) => {
      val adderrocc = LazyModule.apply(new AdderRoccAccel(OpcodeSet.custom2)(p))
      adderrocc
    }
  )
})
