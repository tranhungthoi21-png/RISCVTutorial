//======================================================================
//
// AEAD_chacha_poly.v
// --------------
// Verilog 2001 implementation of the AEAD_ChaCha20_Poly1305.
// This is the internal core with wide interfaces.
//
//
// Copyright (c) 2021. The University of Electro-Communications
// Author: Ronaldo Serrano
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or
// without modification, are permitted provided that the following
// conditions are met:
//
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in
//    the documentation and/or other materials provided with the
//    distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
// FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
// COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//======================================================================

module AEAD_chacha_poly(
                   input wire            clk,
                   input wire            reset_n,

                   input wire            init_aead,
                   input wire            next_aead,
                   input wire            finish_aead,
                   input wire            encript_aead,

                   input wire [255 : 0]  key,
                   input wire [95 : 0]   iv,
                   input wire [127 : 0]  AAD,
                   input wire [6 : 0]    block_len,
                   input wire [511 : 0]  plain_text,

                   output wire           ready,

                   output wire [511 : 0] cipher_text,
                   output wire [127 : 0] tag
                  );


  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  // Datapath quartterround states names.


  localparam CTRL_KEY_GEN                     = 5'h0;
  localparam CTRL_KEY_STREAM                  = 5'h1;
  localparam CTRL_KEY_STREAM_WAIT             = 5'h2;
  localparam CTRL_POLY_KEY                    = 5'h3;
  localparam CTRL_ADD                         = 5'h4;
  localparam CTRL_ADD_NEXT                    = 5'h5;
  localparam CTRL_ADD_NEXT_WAIT               = 5'h6;
  localparam CTRL_ADD_CHACHA_POLY             = 5'h7;
  localparam CTRL_ADD_CHACHA_POLY_WAIT        = 5'h8;
  localparam CTRL_ADD_CHACHA_POLY_UPDATE      = 5'h9;
  localparam CTRL_ADD_CHACHA_POLY_UPDATE_W    = 5'ha;
  localparam CTRL_ADD_CHACHA_POLY_UPDATE_WAIT = 5'hb;
  localparam CTRL_ADD_FINAL                   = 5'hc; 
  localparam CTRL_ADD_FINAL_WAIT              = 5'hd;
  localparam CTRL_ADD_FINAL_READY             = 5'he;
  localparam CTRL_ADD_FINAL_READY_FINAL       = 5'hf;

  


  localparam BLOCK_LEN_POLY   = 5'd16;

  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  
  reg [511 : 0] cipher_text_reg;
  reg [511 : 0] cipher_text_new;
  
  reg  [31 : 0] counter_chacha;
  reg           counter_chacha_inc;
  reg           block_ctr_set;

  reg           qr_ctr_reg;
  reg           qr_ctr_new;
  reg           qr_ctr_we;
  reg           qr_ctr_inc;
  reg           qr_ctr_rst;

  reg           ready_reg;
  reg           ready_new;
  reg           ready_we;
   
  reg [4 : 0]   aead_ctrl_reg;
  reg [4 : 0]   aead_ctrl_new;
  reg           aead_ctrl_we;

  reg           state_init;
  
  reg           encrypt;
  reg           update_encrypt;
  
  //Poly Regs
  
  reg poly_init;
  wire poly_ready;
  wire [127 : 0] auxiliar_poly; 
  
  reg [2 : 0] counter_poly;
  reg [2 : 0] counter_poly_max;
  reg         update_counter_poly;
  reg         update_count;
  //ChaCha20 Regs
  
  reg chacha_next;
  
  
  //AEAD Regs
  
  reg          AEAD_status;
  reg          update_AEAD_status;
  
  
  reg [63 : 0] counter_AEAD;
  reg [63 : 0] counter_plaintext;
  
  reg update_counter_AEAD;
  reg update_counter_plaintext;
  
  reg final_block;
  reg counter_delay;
  reg update_counter_delay;
  
  reg valid_block;
  reg valid_counters;
  reg update_valid_counter;
  reg off_valid_counter;
  
  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------

  reg [511 : 0]  chacha_input;
  wire [511 : 0] chacha_output;  



  reg init_state;
  reg update_state;
  reg detector;
  reg update_output;
  reg update_block;
  reg AAD_input;
  reg chacha_init;

  reg poly_next;
  reg poly_finish;

  reg [4 : 0] poly_blocklen;
  wire [127 : 0] poly_mac;
  wire ready_chacha;
  
  
  reg [127 : 0] poly_block;


  //----------------------------------------------------------------
  // Instantiation of the qr modules.
  //----------------------------------------------------------------
  chacha_core chacha0(
                .clk      (clk),
                .reset_n  (reset_n),
                .init     (chacha_init),
                .next     (chacha_next),
                .key      (key),
                .iv       (iv),
                .ctr      (counter_chacha),
                .data_in  (chacha_input),
                .ready    (ready_chacha),
                .data_out (chacha_output)
               );

  poly1305_core poly0(
                .clk      (clk),
                .reset_n  (reset_n),
                .init     (poly_init),
                .next     (poly_next),
                .finish   (poly_finish),
                .key      (chacha_output [511 : 256]),//poly_key),
                .ready    (poly_ready),
                .block    (poly_block),
                .blocklen (BLOCK_LEN_POLY),
                .mac      (poly_mac)
               );


/////////////////////////////////////////////////////////////
////                Functions
////////////////////////////////////////////////////////////
  
  function [512 : 0] expand (input [6 : 0] block_len);
    begin
      expand = 512'hffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
      expand = expand >> (64-block_len)*8;
      expand = {expand[7 : 0],expand[15 : 8],expand[23 : 16],expand[31 : 24],
                expand[39 : 32],expand[47 : 40],expand[55 : 48],expand[63 : 56],
                expand[71 : 64],expand[79 : 72],expand[87 : 80],expand[95 : 88],
                expand[103 : 96],expand[111 : 104],expand[119 : 112],expand[127 : 120],
                expand[135 : 128],expand[143 : 136],expand[151 : 144],expand[159 : 152],
                expand[167 : 160],expand[175 : 168],expand[183 : 176],expand[191 : 184],
                expand[199 : 192],expand[207 : 200],expand[215 : 208],expand[223 : 216],
                expand[231 : 224],expand[239 : 232],expand[247 : 240],expand[255 : 248],
                expand[263 : 256],expand[271 : 264],expand[279 : 272],expand[287 : 280],
                expand[295 : 288],expand[303 : 296],expand[311 : 304],expand[319 : 312],
                expand[327 : 320],expand[335 : 328],expand[343 : 336],expand[351 : 344],
                expand[359 : 352],expand[367 : 360],expand[375 : 368],expand[383 : 376],
                expand[391 : 384],expand[399 : 392],expand[407 : 400],expand[415 : 408],
                expand[423 : 416],expand[431 : 424],expand[439 : 432],expand[447 : 440],
                expand[455 : 448],expand[463 : 456],expand[471 : 464],expand[479 : 472],
                expand[487 : 480],expand[495 : 488],expand[503 : 496],expand[511 : 504]};
    
    end
  endfunction // expand
  
  wire [511 : 0] filter = expand(block_len);
  
  wire [127 : 0] block_final = {
  counter_AEAD[7 : 0],counter_AEAD[15 : 8],counter_AEAD[23 : 16],counter_AEAD[31 : 24],
  counter_AEAD[39 : 32],counter_AEAD[47 : 40],counter_AEAD[55 : 48],counter_AEAD[63 : 56],
  counter_plaintext[7 : 0],counter_plaintext[15 : 8],counter_plaintext[23 : 16],counter_plaintext[31 : 24],
  counter_plaintext[39 : 32],counter_plaintext[47 : 40],counter_plaintext[55 : 48],counter_plaintext[63 : 56]};
  
  
  
  function [2:0] init_counter (input [6 : 0] block_len);
    begin
        if(block_len<17)
            begin
                init_counter = 1;
            end
        else if (block_len<33)
            begin 
                init_counter = 2;
            end
        else if (block_len<48)
            begin 
                init_counter = 3;
            end
        else
            init_counter = 4;            
       
        
    end
  endfunction // init counter
  
  
  //----------------------------------------------------------------
  // reg_update
  //
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with synchronous
  // active low reset.
  //----------------------------------------------------------------
  always @ (posedge clk)
    begin : reg_update
      if (!reset_n)
        begin
          counter_chacha    <= 32'h0;
          chacha_init       <= 1'h0; 
          cipher_text_reg   <= 512'h0;
          counter_poly      <= 2'h0;
          counter_AEAD      <= 1'h0;
          counter_plaintext <= 1'h0; 
          aead_ctrl_reg     <= CTRL_KEY_GEN;
          poly_block        <= 128'h0;
          counter_poly_max  <= 2'h0;
          counter_delay     <= 1'h0;  
          valid_block       <= 1'h0; 
          valid_counters    <= 1'h0;

          

          
        end
      else
        begin

          if (state_init)
            chacha_init   <= 1'h1; 
            chacha_input  <= 512'h0;
            
          if (!state_init)
            chacha_init   <= 1'h0; 
            chacha_input  <= plain_text;  
            
          if (ready_we)   
            ready_reg     <= ready_new;
            
          if (aead_ctrl_we)   
            aead_ctrl_reg <= aead_ctrl_new;
            
          if (update_output)   
            cipher_text_reg <= cipher_text_new; 
            
          if (update_counter_AEAD)   
            counter_AEAD <= counter_AEAD + block_len;  
            
          
          if (update_counter_plaintext)   
            counter_plaintext <= counter_plaintext + block_len;  
            
          if(update_encrypt)
            encrypt <= encript_aead;
            
          if(update_counter_poly)
            counter_poly_max <= init_counter(block_len);


           if(update_counter_poly)
            counter_poly  <=  2'h0; 
  
          if(update_counter_delay)
            counter_delay <= counter_delay + 1;  
                    


          if(update_valid_counter)
            valid_counters <= 1'h1;
            
          if(off_valid_counter)
            valid_counters <= 1'h0;  
            valid_block   <=  1'h0;           
 
          if((counter_poly == counter_poly_max) & valid_counters)
            valid_block   <=  1'h1;
          

          if(update_count)
            counter_poly  <= counter_poly + 1;           
                       
         
          if(update_block)
            if (AAD_input)   
                poly_block <= AAD;
            else 
                if(encrypt)
                    case(counter_poly)
                        2'b00  :poly_block <= cipher_text [511 : 384];
                        2'b01  :poly_block <= cipher_text [383 : 256];
                        2'b10  :poly_block <= cipher_text [255 : 128];
                        2'b11  :poly_block <= cipher_text [127 : 0];
                        default:poly_block <= cipher_text [511 : 384];
                    endcase
                else
                    case(counter_poly)
                        2'b00  :poly_block <= plain_text [511 : 384];
                        2'b01  :poly_block <= plain_text [383 : 256];
                        2'b10  :poly_block <= plain_text [255 : 128];
                        2'b11  :poly_block <= plain_text [127 : 0];
                        default:poly_block <= plain_text [511 : 384];
                    endcase
                
          if(final_block)
            poly_block <= block_final;
        end
    end // reg_update


  //----------------------------------------------------------------
  // poly1305_core_ctrl
  //----------------------------------------------------------------
  always @*
    begin : poly1305_core_ctrl
      ready_new                = 1'h0;
      ready_we                 = 1'h0;
      aead_ctrl_new            = CTRL_KEY_GEN;
      aead_ctrl_we             = 1'h0;
      poly_init                = 1'h0;
      poly_next                = 1'h0;
      chacha_next              = 1'h0;
      poly_finish              = 1'h0;
      AAD_input                = 1'h0;
      state_init               = 1'h0;
      update_block             = 1'h0;
      update_counter_AEAD      = 1'h0;
      update_counter_plaintext = 1'h0;
      final_block              = 1'h0;
      //update_poly_key          = 1'h0;
      update_encrypt           = 1'h0;
      update_counter_poly      = 1'h0;
      update_counter_delay     = 1'h0;
      //reset_counter_delay      = 1'h0;
      update_count             = 1'h0;
      update_valid_counter     = 1'h0;
      off_valid_counter        = 1'h0; 


      case (aead_ctrl_reg)
      
        CTRL_KEY_GEN:
          begin
            if (init_aead)
              begin
                update_encrypt         = 1'h1;
                state_init             = 1'h1;
                ready_new              = 1'h0;
                ready_we               = 1'h1;
                aead_ctrl_we           = 1'h1;
                aead_ctrl_new          = CTRL_KEY_STREAM;
              end
            end
         
        CTRL_KEY_STREAM:
          begin
            if(ready_chacha)
                begin                   
                    ready_new              = 1'h0;
                    ready_we               = 1'h1;
                    aead_ctrl_we           = 1'h1;
                    cipher_text_new        = chacha_output;
                    aead_ctrl_new          = CTRL_KEY_STREAM_WAIT;

                end
             end
             
        CTRL_KEY_STREAM_WAIT:
          begin
            if(ready_chacha)
                begin                   
                    ready_new              = 1'h0;
                    ready_we               = 1'h1;
                    aead_ctrl_we           = 1'h1;
                    aead_ctrl_new          = CTRL_POLY_KEY;
                    //update_poly_key        = 1'h1;
                end
             end

             
        CTRL_POLY_KEY:
          begin
            if(ready_chacha)
                begin                   
                    ready_new              = 1'h0;
                    ready_we               = 1'h1;
                    aead_ctrl_we           = 1'h1;
                    aead_ctrl_new          = CTRL_ADD;
                    poly_init              = 1'h1;
                end
             end
             

        CTRL_ADD:
          begin
            if(poly_ready)
                begin                   
                    ready_new              = 1'h1;
                    ready_we               = 1'h1;
                    aead_ctrl_we           = 1'h1;
                    aead_ctrl_new          = CTRL_ADD_NEXT;
                end
             end  
           
           
         CTRL_ADD_NEXT_WAIT:
          begin
                    poly_next              = 1'h1;                  
                    ready_new              = 1'h0;
                    ready_we               = 1'h1;
                    aead_ctrl_we           = 1'h1;
                    aead_ctrl_new          = CTRL_ADD;
             end            
  
           
        CTRL_ADD_NEXT:
          begin
          if(next_aead)
                begin
                    update_counter_poly    = 1'h1;
                    update_counter_AEAD    = 1'h1;                 
                    ready_new              = 1'h0;
                    ready_we               = 1'h1;
                    aead_ctrl_we           = 1'h1;
                    aead_ctrl_new          = CTRL_ADD_NEXT_WAIT;
                    AAD_input              = 1'h1;
                    update_block           = 1'h1;
                end
           else if(finish_aead)
                begin                   
                    ready_new              = 1'h0;
                    ready_we               = 1'h1;
                    aead_ctrl_we           = 1'h1;
                    aead_ctrl_new          = CTRL_ADD_CHACHA_POLY;
                    AAD_input              = 1'h0;
                    poly_next              = 1'h0; 
                end
             end   
             

        CTRL_ADD_CHACHA_POLY:
          begin
 //         if(next_aead)
 //               begin
                    update_counter_poly      = 1'h1;
                    update_counter_plaintext = 1'h1;                  
                    ready_new                = 1'h0;
                    ready_we                 = 1'h1;
                    aead_ctrl_we             = 1'h1;
                    aead_ctrl_new            = CTRL_ADD_CHACHA_POLY_WAIT;
                    chacha_next              = 1'h1;
 //               end
             end   
           
             
        CTRL_ADD_CHACHA_POLY_WAIT:
          begin
          if(ready_chacha)
                begin                  
                    ready_new              = 1'h0;
                    ready_we               = 1'h1;
                    aead_ctrl_we           = 1'h1;
                    aead_ctrl_new          = CTRL_ADD_CHACHA_POLY_UPDATE;
                    state_init             = 1'h0;
                    chacha_next            = 1'h0;
                    update_valid_counter   = 1'h1;
                end
             end  
                    
 
         CTRL_ADD_CHACHA_POLY_UPDATE:
          begin
            if ( valid_block & poly_ready)
                begin
                    ready_new              = 1'h1;
                    ready_we               = 1'h1;                    
                    aead_ctrl_we           = 1'h1;
                    aead_ctrl_new          = CTRL_ADD_FINAL;
                    poly_next              = 1'h0;
                    //counter_poly           = 1'h0;  //second driver
                     off_valid_counter      = 1'h1;
                end
            else if(ready_chacha & poly_ready)
                begin
                    update_block           = 1'h1;
                    ready_new              = 1'h0;
                    ready_we               = 1'h1;
                    aead_ctrl_we           = 1'h1;
                    aead_ctrl_new          = CTRL_ADD_CHACHA_POLY_UPDATE_W;
                    poly_next              = 1'h0;
                    //update_counter_delay   = 1'h1;
                end   
          end                    

         CTRL_ADD_CHACHA_POLY_UPDATE_W:
          begin
            //if(counter_delay)
            //    begin
                    ready_new              = 1'h0;
                    ready_we               = 1'h1;
                    aead_ctrl_we           = 1'h1;
                    aead_ctrl_new          = CTRL_ADD_CHACHA_POLY_UPDATE;
                    poly_next              = 1'h1;
                    update_count           = 1'h1;
                    //valid_counters         = 1'h1;
                //    update_counter_delay   = 1'h1;
              //  end   
          end
              

        CTRL_ADD_FINAL:
          begin
          if(next_aead)
                begin                   
                    update_counter_plaintext = 1'h1; 
                    ready_new                = 1'h0;
                    ready_we                 = 1'h1;
                    aead_ctrl_we             = 1'h1;
                    aead_ctrl_new            = CTRL_ADD_CHACHA_POLY_WAIT;
                    chacha_next              = 1'h1;
                    update_counter_poly      = 1'h1;
                    
                end
           if(finish_aead)
                begin                   
                    ready_new              = 1'h0;
                    ready_we               = 1'h1;
                    aead_ctrl_we           = 1'h1;
                    aead_ctrl_new          = CTRL_ADD_FINAL_WAIT;
                    final_block            = 1'h1;
                end
             end  
             


        CTRL_ADD_FINAL_WAIT:
          begin
            if(poly_ready)
                begin
                    poly_next              = 1'h1;
                    ready_new              = 1'h0;
                    ready_we               = 1'h1;
                    aead_ctrl_we           = 1'h1;
                    aead_ctrl_new          = CTRL_ADD_FINAL_READY;
                end
             end 
         
         CTRL_ADD_FINAL_READY:
          begin
          if(poly_ready)
                begin
                    poly_finish              = 1'h1;                    
                    ready_new                = 1'h0;
                    ready_we                 = 1'h1;
                    aead_ctrl_we             = 1'h1;
                    aead_ctrl_new            = CTRL_ADD_FINAL_READY_FINAL;
                end
             end              


         CTRL_ADD_FINAL_READY_FINAL:
          begin
          if(poly_ready)
                begin                    
                    ready_new                = 1'h1;
                    ready_we                 = 1'h1;
                    aead_ctrl_we             = 1'h1;
                    aead_ctrl_new            = CTRL_ADD_FINAL_READY_FINAL;
                end
             end              


        default:
          begin
          end
      endcase 
    end
  
  
  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign cipher_text   = chacha_output & filter;
  assign ready         = ready_reg;
  assign tag           = poly_mac;
  
  
  
endmodule // AEAD_chacha_poly

//======================================================================
// EOF AEAD_chacha_poly.v
//======================================================================
