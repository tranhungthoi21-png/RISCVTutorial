`timescale 1ns / 1ps
module SHA256(
    input wire clk,
    input wire rstn,
    slv_interface.slv bus_if
);

    reg[31:0] h0, h1, h2, h3, h4, h5, h6, h7;
    reg[31:0] a, b, c, d, e, f, g, h;

    // -- Bus read -----------------------------------------------------
    reg[31:0] rdata_out;
    wire message_queue_ready;

    always @(posedge clk or negedge rstn)
        if (!rstn) rdata_out <= '0;
        else if (bus_if.avalid)
            case ({bus_if.addr[11:2], 2'b00})
                32'h00: rdata_out <= h0;
                32'h04: rdata_out <= h1;
                32'h08: rdata_out <= h2;
                32'h0C: rdata_out <= h3;
                32'h10: rdata_out <= h4;
                32'h14: rdata_out <= h5;
                32'h18: rdata_out <= h6;
                32'h1C: rdata_out <= h7;
                32'h20: rdata_out <= message_queue_ready;
                default: rdata_out <= '0;
            endcase

    reg rvalid;
    always @(posedge clk or negedge rstn)
        if (!rstn) rvalid <= 1'b0;
        else       rvalid <= bus_if.avalid;

    assign bus_if.rvalid = rvalid;
    assign bus_if.aready = 1'b1;
    assign bus_if.rdata  = rdata_out;

    // -- Hash accumulation ---------------------------------------------
    always @(posedge clk or negedge rstn)
        if (!rstn) begin
            h0 <= 32'h6a09e667; h1 <= 32'hbb67ae85;
            h2 <= 32'h3c6ef372; h3 <= 32'ha54ff53a;
            h4 <= 32'h510e527f; h5 <= 32'h9b05688c;
            h6 <= 32'h1f83d9ab; h7 <= 32'h5be0cd19;
        end else begin
            if (state == SHA256_ADD) begin
                h0<=h0+a; h1<=h1+b; h2<=h2+c; h3<=h3+d;
                h4<=h4+e; h5<=h5+f; h6<=h6+g; h7<=h7+h;
            end
            if (bus_if.avalid && bus_if.awren)
                case ({bus_if.addr[11:2], 2'b00})
                    32'h00: h0 <= bus_if.awdata[31:0];
                    32'h04: h1 <= bus_if.awdata[31:0];
                    32'h08: h2 <= bus_if.awdata[31:0];
                    32'h0C: h3 <= bus_if.awdata[31:0];
                    32'h10: h4 <= bus_if.awdata[31:0];
                    32'h14: h5 <= bus_if.awdata[31:0];
                    32'h18: h6 <= bus_if.awdata[31:0];
                    32'h1C: h7 <= bus_if.awdata[31:0];
                endcase
        end

    // -- Message schedule ----------------------------------------------
    wire message_valid_w = ({bus_if.addr[11:2], 2'b00} == 32'h20)
                           && bus_if.avalid && bus_if.awren;
    reg[31:0] w[64];

    typedef enum { SHA256_SCHEDULE, SHA256_EXPAND, SHA256_ROUND, SHA256_ADD } STATE;
    STATE state;

    // -- Helpers -------------------------------------------------------
    function automatic [31:0] rotr32(input logic[31:0] x, input logic[4:0] s);
        return (x >> s) | (x << (32-s));
    endfunction
    function automatic [31:0] sigma0(input logic[31:0] x);
        return rotr32(x,7) ^ rotr32(x,18) ^ (x >> 3);
    endfunction
    function automatic [31:0] sigma1(input logic[31:0] x);
        return rotr32(x,17) ^ rotr32(x,19) ^ (x >> 10);
    endfunction
    function automatic [31:0] Sigma0(input logic[31:0] x);
        return rotr32(x,2) ^ rotr32(x,13) ^ rotr32(x,22);
    endfunction
    function automatic [31:0] Sigma1(input logic[31:0] x);
        return rotr32(x,6) ^ rotr32(x,11) ^ rotr32(x,25);
    endfunction
    function automatic [31:0] Ch(input logic[31:0] xe, xf, xg);
        return (xe & xf) ^ (~xe & xg);
    endfunction
    function automatic [31:0] Maj(input logic[31:0] xa, xb, xc);
        return (xa & xb) ^ (xa & xc) ^ (xb & xc);
    endfunction

    // -- Round constants -----------------------------------------------
    localparam [31:0] k[64] = '{
        32'h428a2f98,32'h71374491,32'hb5c0fbcf,32'he9b5dba5,
        32'h3956c25b,32'h59f111f1,32'h923f82a4,32'hab1c5ed5,
        32'hd807aa98,32'h12835b01,32'h243185be,32'h550c7dc3,
        32'h72be5d74,32'h80deb1fe,32'h9bdc06a7,32'hc19bf174,
        32'he49b69c1,32'hefbe4786,32'h0fc19dc6,32'h240ca1cc,
        32'h2de92c6f,32'h4a7484aa,32'h5cb0a9dc,32'h76f988da,
        32'h983e5152,32'ha831c66d,32'hb00327c8,32'hbf597fc7,
        32'hc6e00bf3,32'hd5a79147,32'h06ca6351,32'h14292967,
        32'h27b70a85,32'h2e1b2138,32'h4d2c6dfc,32'h53380d13,
        32'h650a7354,32'h766a0abb,32'h81c2c92e,32'h92722c85,
        32'ha2bfe8a1,32'ha81a664b,32'hc24b8b70,32'hc76c51a3,
        32'hd192e819,32'hd6990624,32'hf40e3585,32'h106aa070,
        32'h19a4c116,32'h1e376c08,32'h2748774c,32'h34b0bcb5,
        32'h391c0cb3,32'h4ed8aa4a,32'h5b9cca4f,32'h682e6ff3,
        32'h748f82ee,32'h78a5636f,32'h84c87814,32'h8cc70208,
        32'h90befffa,32'ha4506ceb,32'hbef9a3f7,32'hc67178f2
    };

    reg [5:0] i;

    // w[i] — balanced tree
    wire [31:0] pA0 = w[i-16] + sigma0(w[i-15]);   // parallel pair A
    wire [31:0] pB0 = w[i-7]  + sigma1(w[i-2]);    // parallel pair B
    wire [31:0] w0_nxt = pA0 + pB0;                // 2nd level

    // w[i+1] — balanced tree, fully parallel with w[i]
    wire [31:0] pA1 = w[i-15] + sigma0(w[i-14]);
    wire [31:0] pB1 = w[i-6]  + sigma1(w[i-1]);
    wire [31:0] w1_nxt = pA1 + pB1;

    wire [31:0] S1     = Sigma1(e);
    wire [31:0] ch     = Ch(e, f, g);
    wire [31:0] tA     = h + S1;              // pair A
    wire [31:0] kw     = k[i] + w[i];         // pair B-pre (k const + w)
    wire [31:0] tB     = ch + kw;             // pair B
    wire [31:0] temp1  = tA + tB;             // final: 3 levels total
    wire [31:0] S0     = Sigma0(a);
    wire [31:0] maj    = Maj(a, b, c);
    wire [31:0] temp2  = S0 + maj;

    // ================================================================
    // FSM
    // ================================================================
    always_ff @(posedge clk or negedge rstn)
        if (!rstn) begin
            state <= SHA256_SCHEDULE;
            a<=0; b<=0; c<=0; d<=0; e<=0; f<=0; g<=0; h<=0;
            i <= 0;
            w <= '{default: '0};
        end
        else case (state)

            // SCHEDULE: 1 word/cycle (16 cycles)
            SHA256_SCHEDULE: if (message_valid_w) begin
                w[i] <= bus_if.awdata[31:0];
                i <= i + 1;
                if (i == 6'd15) begin
                    i <= 6'd16;
                    state <= SHA256_EXPAND;
                end
            end

            SHA256_EXPAND: begin
                w[i]   <= w0_nxt;
                w[i+1] <= w1_nxt;
                i <= i + 2;
                if (i == 6'd62) begin
                    a <= h0; b <= h1; c <= h2; d <= h3;
                    e <= h4; f <= h5; g <= h6; h <= h7;
                    i <= 6'd0;
                    state <= SHA256_ROUND;
                end
            end

            // ROUND ×1 balanced tree: 64 cycles
            SHA256_ROUND: begin
                h <= g; g <= f; f <= e; e <= d + temp1;
                d <= c; c <= b; b <= a; a <= temp1 + temp2;
                i <= i + 1;
                if (i == 6'd63) state <= SHA256_ADD;
            end

            // ADD: 1 cycle
            SHA256_ADD: begin
                state <= SHA256_SCHEDULE;
                i <= 0;
            end

        endcase

    assign message_queue_ready = (state == SHA256_SCHEDULE);

endmodule