//see LICENSE for license
//authors: Duc-Thuan Dam, UEC
package KECCAK

object keccakRegs {
  val rst           = 0x00
  val write_enable  = 0x08
  val write_data    = 0x10
  val data_len      = 0x18
  val end_packet    = 0x20
  val final_packet  = 0x28
  val in_ready      = 0x30
  val read_enable   = 0x38
  val read_done     = 0x40
  val read_data     = 0x48
  val out_valid     = 0x50
  val out_ready     = 0x58
  val mode          = 0x60
}