`timescale 1ns / 1ps

module ahb_top (
    input wire HCLK,
    input wire HRESETn
);

    // Master interfaces
    wire [31:0] HADDR_M[3:0], HWDATA_M[3:0], HRDATA_M[3:0];
    wire [1:0]  HTRANS_M[3:0], HRESP_M[3:0];
    wire [2:0]  HBURST_M[3:0];
    wire        HWRITE_M[3:0], HBUSREQ_M[3:0], HLOCK_M[3:0];
    wire        HREADY_M[3:0], HGRANT_M[3:0];

    // Shared bus signals
    wire [31:0] HADDR, HWDATA;
    wire [1:0]  HTRANS;
    wire [2:0]  HBURST;
    wire        HWRITE;

    // Slave interfaces
    wire        HSEL_S[3:0], HSEL_DEFAULT;
    wire [31:0] HRDATA_S[3:0], HRDATA_DEF;
    wire        HREADYOUT_S[3:0], HREADYOUT_DEF;
    wire [1:0]  HRESP_S[3:0], HRESP_DEF;

    // Arbiter signals
    wire [3:0] HBUSREQ = {HBUSREQ_M[3], HBUSREQ_M[2], HBUSREQ_M[1], HBUSREQ_M[0]};
    wire [3:0] HLOCK   = {HLOCK_M[3],   HLOCK_M[2],   HLOCK_M[1],   HLOCK_M[0]};
    wire [3:0] HGRANT, HMASTER;

    // MUX outputs
    wire [31:0] HRDATA_mux;
    wire        HREADY_mux;
    wire [1:0]  HRESP_mux;

    // Connect shared responses to all masters
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin
            assign HRDATA_M[i] = HRDATA_mux;
            assign HREADY_M[i] = HREADY_mux;
            assign HRESP_M[i]  = HRESP_mux;
            assign HGRANT_M[i] = HGRANT[i];
        end
    endgenerate

    // Arbiter
    ahb_arbiter #(
        .NUM_MASTERS(4),
        .DEFAULT_MASTER(4'd0)
    ) arbiter_inst (
        .HCLK(HCLK),
        .HRESETn(HRESETn),
        .HBUSREQ(HBUSREQ),
        .HLOCK(HLOCK),
        .HTRANS(HTRANS),
        .HBURST(HBURST),
        .HRESP(HRESP_mux),
        .HREADY(HREADY_mux),
        .HGRANT(HGRANT),
        .HMASTER(HMASTER),
        .HMASTLOCK()
    );

    // Decoder
    ahb_decoder decoder_inst (
        .HADDR(HADDR),
        .HSEL_S0(HSEL_S[0]),
        .HSEL_S1(HSEL_S[1]),
        .HSEL_S2(HSEL_S[2]),
        .HSEL_S3(HSEL_S[3]),
        .HSEL_DEFAULT(HSEL_DEFAULT)
    );

    // MUX
    ahb_mux mux_inst (
        .HCLK(HCLK),
        .HRESETn(HRESETn),
        .HMASTER(HMASTER),
        .HSEL_S0(HSEL_S[0]),
        .HSEL_S1(HSEL_S[1]),
        .HSEL_S2(HSEL_S[2]),
        .HSEL_S3(HSEL_S[3]),
        .HSEL_DEFAULT(HSEL_DEFAULT),
        .HADDR_M0(HADDR_M[0]), .HWDATA_M0(HWDATA_M[0]),
        .HTRANS_M0(HTRANS_M[0]), .HBURST_M0(HBURST_M[0]), .HWRITE_M0(HWRITE_M[0]),
        .HADDR_M1(HADDR_M[1]), .HWDATA_M1(HWDATA_M[1]),
        .HTRANS_M1(HTRANS_M[1]), .HBURST_M1(HBURST_M[1]), .HWRITE_M1(HWRITE_M[1]),
        .HADDR_M2(HADDR_M[2]), .HWDATA_M2(HWDATA_M[2]),
        .HTRANS_M2(HTRANS_M[2]), .HBURST_M2(HBURST_M[2]), .HWRITE_M2(HWRITE_M[2]),
        .HADDR_M3(HADDR_M[3]), .HWDATA_M3(HWDATA_M[3]),
        .HTRANS_M3(HTRANS_M[3]), .HBURST_M3(HBURST_M[3]), .HWRITE_M3(HWRITE_M[3]),
        .HRDATA_S0(HRDATA_S[0]), .HREADYOUT_S0(HREADYOUT_S[0]), .HRESP_S0(HRESP_S[0]),
        .HRDATA_S1(HRDATA_S[1]), .HREADYOUT_S1(HREADYOUT_S[1]), .HRESP_S1(HRESP_S[1]),
        .HRDATA_S2(HRDATA_S[2]), .HREADYOUT_S2(HREADYOUT_S[2]), .HRESP_S2(HRESP_S[2]),
        .HRDATA_S3(HRDATA_S[3]), .HREADYOUT_S3(HREADYOUT_S[3]), .HRESP_S3(HRESP_S[3]),
        .HRDATA_DEF(HRDATA_DEF), .HREADYOUT_DEF(HREADYOUT_DEF), .HRESP_DEF(HRESP_DEF),
        .HADDR(HADDR), .HWDATA(HWDATA), .HTRANS(HTRANS), .HBURST(HBURST), .HWRITE(HWRITE),
        .HRDATA(HRDATA_mux), .HREADY(HREADY_mux), .HRESP(HRESP_mux)
    );

    // Master placeholders
    generate
        for (i = 0; i < 4; i = i + 1) begin
            assign HADDR_M[i]  = 32'h0000_0000;
            assign HWDATA_M[i] = 32'h0000_0000;
            assign HTRANS_M[i] = 2'b00;
            assign HBURST_M[i] = 3'b000;
            assign HWRITE_M[i] = 1'b0;
            assign HBUSREQ_M[i] = 1'b0;
            assign HLOCK_M[i]  = 1'b0;
        end
    endgenerate

    // Slave placeholders
    assign HRDATA_S[0] = 32'hDEAD_BEEF;
    assign HRDATA_S[1] = 32'hCAFE_BABE;
    assign HRDATA_S[2] = 32'h1234_5678;
    assign HRDATA_S[3] = 32'hABCD_EF01;

    generate
        for (i = 0; i < 4; i = i + 1) begin
            assign HREADYOUT_S[i] = 1'b1;
            assign HRESP_S[i]     = 2'b00;
        end
    endgenerate

    // Default slave
    assign HRDATA_DEF    = 32'h0000_0000;
    assign HREADYOUT_DEF = 1'b1;
    assign HRESP_DEF     = 2'b01; // ERROR

endmodule