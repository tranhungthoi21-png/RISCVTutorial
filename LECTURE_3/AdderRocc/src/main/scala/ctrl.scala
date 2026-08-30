//see LICENSE for license
//authors: Colin Schmidt, Adam Izraelevitz
package AdderRocc

import Chisel._
import scala.collection.mutable.HashMap
import scala.collection.mutable.ArrayBuffer
import chisel3.util.{HasBlackBoxResource}
import scala.util.Random
import Chisel.ImplicitConversions._
import freechips.rocketchip.tile.HasCoreParameters
import freechips.rocketchip.rocket.constants.MemoryOpConstants
import org.chipsalliance.cde.config._
import freechips.rocketchip.tile.{RoCCIO, LazyRoCC, LazyRoCCModuleImp, OpcodeSet, BuildRoCC}

class AdderRocc ()(implicit p: Parameters) extends BlackBox with HasBlackBoxResource {
  val io = IO (new Bundle{
    val iClk   = Input(Clock())
    val iRst   = Input(Bool())
    val iWrEn  = Input(Bool(false))
    val iRdEn  = Input(Bool(false))
    val iValid = Input(Bool(false))
    val iSel   = Input(Bool())
    val iData  = Input(UInt(64.W))
    val oData  = Output(UInt(64.W))
    val oValid = Output(Bool())
    val oReady = Output(Bool())
  })
  addResource("/vsrc/AdderRocc.v")
  addResource("/vsrc/adder.v")
  addResource("/vsrc/controller.v")
  addResource("/vsrc/counter5.v")
  addResource("/vsrc/FIFO_32x64.v")
}

class CtrlModule()(implicit val p: Parameters) extends Module
  with HasCoreParameters
  with MemoryOpConstants {
  val io = new Bundle {
    val rocc_req_val      = Bool(INPUT)
    val rocc_req_rdy      = Bool(OUTPUT)
    val rocc_funct        = Bits(INPUT, 2)
    val rocc_rs1          = Bits(INPUT, 64)
    val rocc_rs2          = Bits(INPUT, 64)
    val rocc_rd           = Bits(INPUT, 5)

    val busy              = Bool(OUTPUT)

    val dmem_req_val      = Bool(OUTPUT)
    val dmem_req_rdy      = Bool(INPUT)
    val dmem_req_tag      = Bits(OUTPUT, coreParams.dcacheReqTagBits)
    val dmem_req_addr     = Bits(OUTPUT, coreMaxAddrBits)
    val dmem_req_cmd      = Bits(OUTPUT, M_SZ)
    val dmem_req_size     = Bits(OUTPUT, log2Ceil(coreDataBytes + 1))

    val dmem_resp_val     = Bool(INPUT)
    val dmem_resp_tag     = Bits(INPUT, 7)
    val dmem_resp_data    = Bits(INPUT, 64)

    val sfence            = Bool(OUTPUT)

// output of rocc
    val out_data          = Bits(OUTPUT, 64)
  }

  val rocc_adder  = Module(new AdderRocc())
  val mux_sel = Reg(init = Bool(false))   // select the in/out of FIFO
  val out_valid = Reg(init = Bool(false)) // turn true when function is finished
  val out_ready = Reg(init = Bool(false)) // turn true when function is finished
  val in_valid = Reg(init = Bool(false))  // Trigger to execute the function
  val write_en = Reg(init = Bool(false))  // enable to write data to FIFO
  val read_en = Reg(init = Bool(false))   // enable to read data from FIFO

  rocc_adder.io.iClk := clock
  rocc_adder.io.iRst := reset
  rocc_adder.io.iData := io.dmem_resp_data
  rocc_adder.io.iSel := mux_sel
  rocc_adder.io.iValid := in_valid
  rocc_adder.io.iWrEn := write_en
  rocc_adder.io.iRdEn := read_en

  out_valid := rocc_adder.io.oValid
  out_ready := rocc_adder.io.oReady
  io.out_data := rocc_adder.io.oData

  val read    = Reg(init = UInt(0,32)) // counter read from FIFO
  val mindex  = Reg(init = UInt(0,5))  // counter for reading data from mem
  val windex  = Reg(init = UInt(0,6))  // counter for writing data to mem
  //RoCC HANDLER
  //rocc pipe state
  val r_idle :: Nil = Enum(UInt(), 1)

  val in_addr = Reg(init = UInt(0,64))  // input address
  val out_addr= Reg(init = UInt(0,64))  // output address
  val msg_len = Reg(init = UInt(0,64))  // len of message

  val busy = Reg(init=Bool(false))
  val rocc_s = Reg(init=r_idle)
  //register inputs
  val rocc_req_val_reg = Reg(next=io.rocc_req_val)
  val rocc_funct_reg = Reg(init = Bits(0,2))
  rocc_funct_reg := io.rocc_funct
  val rocc_rs1_reg = Reg(next=io.rocc_rs1)
  val rocc_rs2_reg = Reg(next=io.rocc_rs2)
  val rocc_rd_reg = Reg(next=io.rocc_rd)

  val dmem_resp_val_reg = Reg(next=io.dmem_resp_val)
  val dmem_resp_tag_reg = Reg(next=io.dmem_resp_tag)
  //memory pipe state
  val m_idle :: m_read :: m_wait :: m_write :: Nil = Enum(UInt(), 4)

  val fast_mem = p(AdderRoccFastMem)
  val mem_s = Reg(init=m_idle)
  val read_send :: read_trig :: read_wait :: read_valid_trig_on :: read_valid_trig_off :: Nil = Enum(UInt(), 5)
  val read_s = Reg(init=read_send)
  val write_trig_on :: write_send ::  write_trig_off_1 :: write_trig_off_2 :: Nil = Enum(UInt(), 4)
  val write_s = Reg(init=write_trig_on)

  //default
  io.rocc_req_rdy := Bool(false)
  io.busy := busy
  io.dmem_req_val:= Bool(false)
  io.dmem_req_tag:= UInt(0)
  io.dmem_req_addr:= Bits(0, 32)
  io.dmem_req_cmd:= M_XRD
  io.dmem_req_size:= log2Ceil(8).U
  io.sfence      := Bool(false)

 // read the instructions to get the function
  switch(rocc_s) {
  is(r_idle) {
    io.rocc_req_rdy := !busy
    when(io.rocc_req_val && !busy){
      when(io.rocc_funct === UInt(0)){
        io.rocc_req_rdy := Bool(true)
        in_addr  := io.rocc_rs1
        out_addr := io.rocc_rs2
        io.busy := Bool(true)
      }.elsewhen(io.rocc_funct === UInt(1)) {
        busy := Bool(true)
        io.rocc_req_rdy := Bool(true)
        io.busy := Bool(true)
        msg_len := io.rocc_rs1
      }
      if (p(AdderRoccTLB).isDefined) {
        when (io.rocc_funct === UInt(2)) {
          io.rocc_req_rdy := Bool(true)
          io.sfence := Bool(true)
        }
      }
    }
  }
  }
  val writes_done  = Reg( init=Vec.fill(32) { Bool(false) })
  //END RoCC HANDLER
  //START MEM HANDLER
  switch(mem_s) {
    //-------------------------------------------------------------------------------------------
    // State IDLE when receiving ROCC instructions, busy turned true when get enough information
    //-------------------------------------------------------------------------------------------
    is(m_idle) {
      val canRead = busy && (read < msg_len)
      when(!canRead) {
        mindex := UInt(0)
        mem_s := m_idle
      }.otherwise {
        mem_s := m_read
      }
    }
    //---------------------------------------------------------------------------------
    //------------ State READ when reading data from cache to FIFO buffer -------------
    //---------------------------------------------------------------------------------
    is(m_read) {
      when(mem_s =/= m_write) { // do read when not writing
        switch(read_s){
          is(read_send) {
            io.dmem_req_val := read < msg_len
            io.dmem_req_addr := in_addr
            io.dmem_req_tag := mindex
            io.dmem_req_cmd := M_XRD
            io.dmem_req_size := log2Ceil(8).U

            when(io.dmem_req_rdy && io.dmem_req_val) {
              mindex := mindex + UInt(1)
              in_addr := in_addr + UInt(8)
              read := read + UInt(8) //read 16 bytes
              read_s := read_trig
            }
          }

          is(read_trig){
            when(io.dmem_resp_val) {
              when(io.dmem_resp_tag(4, 0) < UInt(32)) {
                write_en := Bool(true)
                read_s := read_wait
              }
            }
          }

          is(read_wait){
            write_en := Bool(false)
            read_s := read_send
            when(read < msg_len){
              mem_s := m_read
            }.otherwise{
              mux_sel := Bool(true)
              read_s := read_valid_trig_on
            }
          }

          is(read_valid_trig_on){
            in_valid := Bool(true)
            write_en := Bool(false)
            read_en := Bool(false)
            read_s := read_valid_trig_off
          }

          is(read_valid_trig_off){
            in_valid := Bool(false)
            //read_s := read_send
            mem_s := m_wait
          }
        }
      }
    }
    //---------------------------------------------------------------------------------
    //------------------ State WAIT when executing the operation ----------------------
    //---------------------------------------------------------------------------------
    is(m_wait) {
    //the code to process read responses
      when(!(out_ready && out_valid)) {
        mem_s := m_wait
      }.otherwise{
        mux_sel := Bool(false)
        mem_s := m_write
      }
    }
    //---------------------------------------------------------------------------------
    //------------------ State WRITE when writing the result to memory ----------------
    //---------------------------------------------------------------------------------
    is(m_write) {
      when(windex < UInt(32)){
        switch(write_s){
          is(write_trig_on){ // read data from FIFO
            read_en := Bool(true)
            write_s := write_trig_off_1
          }

          is(write_trig_off_1){ // read data from FIFO
            read_en := Bool(false)
            write_s := write_trig_off_2
          }

          is(write_trig_off_2){ // read data from FIFO
            read_en := Bool(false)
            write_s := write_send
          }

          is(write_send) {
            read_en := Bool(false)
            io.dmem_req_val := windex < UInt(32) // 32 = 128/4 number
            io.dmem_req_addr := out_addr
            io.dmem_req_tag := UInt(32) + windex
            io.dmem_req_cmd := M_XWR

            when(io.dmem_req_rdy) {
              windex := windex + UInt(1)
              out_addr := out_addr + UInt(8)
              write_s := write_trig_on
            }
          }
        }
      }.otherwise{
          busy := Bool(false)
          writes_done := Vec.fill(32) {Bool(false)}
          windex := UInt(0)
          in_addr := UInt(0)
          out_addr := UInt(0)
          msg_len := UInt(0)
          read := UInt(0)
          write_s := write_trig_on
          mem_s := m_idle
          read_s := read_send
      }
    }
  }
}