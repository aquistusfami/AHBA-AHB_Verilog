`timescale 1ns / 1ps

// ============================================================
// AHB-Lite Interconnect Multiplexer
// ============================================================

module ahb_mux #(
    parameter NUM_MASTERS = 4
)(
    input  wire        HCLK,
    input  wire        HRESETn,

    // ========================================================
    // CONTROL FROM ARBITER / DECODER
    // ========================================================

    input  wire [3:0]  HMASTER,

    input  wire        HSEL_S0,
    input  wire        HSEL_S1,
    input  wire        HSEL_S2,
    input  wire        HSEL_S3,
    input  wire        HSEL_DEFAULT,

    // ========================================================
    // MASTER 0
    // ========================================================

    input  wire [31:0] HADDR_M0,
    input  wire [31:0] HWDATA_M0,
    input  wire [1:0]  HTRANS_M0,
    input  wire        HWRITE_M0,
    input  wire [2:0]  HSIZE_M0,
    input  wire [2:0]  HBURST_M0,
    input  wire [3:0]  HPROT_M0,

    // ========================================================
    // MASTER 1
    // ========================================================

    input  wire [31:0] HADDR_M1,
    input  wire [31:0] HWDATA_M1,
    input  wire [1:0]  HTRANS_M1,
    input  wire        HWRITE_M1,
    input  wire [2:0]  HSIZE_M1,
    input  wire [2:0]  HBURST_M1,
    input  wire [3:0]  HPROT_M1,

    // ========================================================
    // MASTER 2
    // ========================================================

    input  wire [31:0] HADDR_M2,
    input  wire [31:0] HWDATA_M2,
    input  wire [1:0]  HTRANS_M2,
    input  wire        HWRITE_M2,
    input  wire [2:0]  HSIZE_M2,
    input  wire [2:0]  HBURST_M2,
    input  wire [3:0]  HPROT_M2,

    // ========================================================
    // MASTER 3
    // ========================================================

    input  wire [31:0] HADDR_M3,
    input  wire [31:0] HWDATA_M3,
    input  wire [1:0]  HTRANS_M3,
    input  wire        HWRITE_M3,
    input  wire [2:0]  HSIZE_M3,
    input  wire [2:0]  HBURST_M3,
    input  wire [3:0]  HPROT_M3,

    // ========================================================
    // SLAVE 0
    // ========================================================

    input  wire [31:0] HRDATA_S0,
    input  wire        HREADYOUT_S0,
    input  wire [1:0]  HRESP_S0,

    // ========================================================
    // SLAVE 1
    // ========================================================

    input  wire [31:0] HRDATA_S1,
    input  wire        HREADYOUT_S1,
    input  wire [1:0]  HRESP_S1,

    // ========================================================
    // SLAVE 2
    // ========================================================

    input  wire [31:0] HRDATA_S2,
    input  wire        HREADYOUT_S2,
    input  wire [1:0]  HRESP_S2,

    // ========================================================
    // SLAVE 3
    // ========================================================

    input  wire [31:0] HRDATA_S3,
    input  wire        HREADYOUT_S3,
    input  wire [1:0]  HRESP_S3,

    // ========================================================
    // DEFAULT SLAVE
    // ========================================================

    input  wire [31:0] HRDATA_DEF,
    input  wire        HREADYOUT_DEF,
    input  wire [1:0]  HRESP_DEF,

    // ========================================================
    // BROADCAST TO SLAVES
    // ========================================================

    output wire [31:0] HADDR,
    output wire [31:0] HWDATA,
    output wire [1:0]  HTRANS,
    output wire        HWRITE,
    output wire [2:0]  HSIZE,
    output wire [2:0]  HBURST,
    output wire [3:0]  HPROT,

    // ========================================================
    // RETURN TO MASTERS
    // ========================================================

    output wire [31:0] HRDATA,
    output wire        HREADY,
    output wire [1:0]  HRESP
);

//////////////////////////////////////////////////////////////
// OPTIONAL COMMON DEFINES
//////////////////////////////////////////////////////////////

`include "ahb_defines.v"

localparam TR_IDLE = 2'b00;

localparam RESP_OKAY = 2'b00;
localparam RESP_ERROR = 2'b01;

//////////////////////////////////////////////////////////////
// DATA PHASE PIPELINE REGISTERS
//////////////////////////////////////////////////////////////

reg [3:0] HMASTER_data;

reg HSEL_S0_data;
reg HSEL_S1_data;
reg HSEL_S2_data;
reg HSEL_S3_data;
reg HSEL_DEFAULT_data;

//////////////////////////////////////////////////////////////
// ADDRESS PHASE -> DATA PHASE PIPELINE
//////////////////////////////////////////////////////////////

// DOCUMENTATION: HMASTER input may transition during a bus stall (HREADY = 0). 
// This is safe because HMASTER_data is explicitly gated by HREADY in the pipeline register.
always @(posedge HCLK or negedge HRESETn) begin

    if (!HRESETn) begin

        HMASTER_data      <= 4'd0;

        HSEL_S0_data      <= 1'b0;
        HSEL_S1_data      <= 1'b0;
        HSEL_S2_data      <= 1'b0;
        HSEL_S3_data      <= 1'b0;

        // FIX:
        // do NOT depend on Default Slave reset behavior
        HSEL_DEFAULT_data <= 1'b0;

    end
    else if (HREADY) begin

        HMASTER_data      <= HMASTER;

        HSEL_S0_data      <= HSEL_S0;
        HSEL_S1_data      <= HSEL_S1;
        HSEL_S2_data      <= HSEL_S2;
        HSEL_S3_data      <= HSEL_S3;
        HSEL_DEFAULT_data <= HSEL_DEFAULT;

    end
end

//////////////////////////////////////////////////////////////
// MASTER -> SLAVE ADDRESS/CONTROL MUX
//////////////////////////////////////////////////////////////

assign HADDR  = (HMASTER == 4'd0) ? HADDR_M0  :
                (HMASTER == 4'd1) ? HADDR_M1  :
                (HMASTER == 4'd2) ? HADDR_M2  :
                (HMASTER == 4'd3) ? HADDR_M3  : 32'd0;

assign HTRANS = (HMASTER == 4'd0) ? HTRANS_M0 :
                (HMASTER == 4'd1) ? HTRANS_M1 :
                (HMASTER == 4'd2) ? HTRANS_M2 :
                (HMASTER == 4'd3) ? HTRANS_M3 : TR_IDLE;

assign HWRITE = (HMASTER == 4'd0) ? HWRITE_M0 :
                (HMASTER == 4'd1) ? HWRITE_M1 :
                (HMASTER == 4'd2) ? HWRITE_M2 :
                (HMASTER == 4'd3) ? HWRITE_M3 : 1'b0;

assign HSIZE  = (HMASTER == 4'd0) ? HSIZE_M0  :
                (HMASTER == 4'd1) ? HSIZE_M1  :
                (HMASTER == 4'd2) ? HSIZE_M2  :
                (HMASTER == 4'd3) ? HSIZE_M3  : 3'b000;

assign HBURST = (HMASTER == 4'd0) ? HBURST_M0 :
                (HMASTER == 4'd1) ? HBURST_M1 :
                (HMASTER == 4'd2) ? HBURST_M2 :
                (HMASTER == 4'd3) ? HBURST_M3 : 3'b000;

assign HPROT  = (HMASTER == 4'd0) ? HPROT_M0  :
                (HMASTER == 4'd1) ? HPROT_M1  :
                (HMASTER == 4'd2) ? HPROT_M2  :
                (HMASTER == 4'd3) ? HPROT_M3  : 4'b0011;

//////////////////////////////////////////////////////////////
// WRITE DATA MUX
//////////////////////////////////////////////////////////////

assign HWDATA = (HMASTER_data == 4'd0) ? HWDATA_M0 :
                (HMASTER_data == 4'd1) ? HWDATA_M1 :
                (HMASTER_data == 4'd2) ? HWDATA_M2 :
                (HMASTER_data == 4'd3) ? HWDATA_M3 : 32'd0;

//////////////////////////////////////////////////////////////
// SLAVE -> MASTER RESPONSE MUX
//////////////////////////////////////////////////////////////

assign HRDATA = (HSEL_S0_data)      ? HRDATA_S0 :
                (HSEL_S1_data)      ? HRDATA_S1 :
                (HSEL_S2_data)      ? HRDATA_S2 :
                (HSEL_S3_data)      ? HRDATA_S3 :
                (HSEL_DEFAULT_data) ? HRDATA_DEF : 32'd0;

assign HREADY = (HSEL_S0_data)      ? HREADYOUT_S0 :
                (HSEL_S1_data)      ? HREADYOUT_S1 :
                (HSEL_S2_data)      ? HREADYOUT_S2 :
                (HSEL_S3_data)      ? HREADYOUT_S3 :
                (HSEL_DEFAULT_data) ? HREADYOUT_DEF : 1'b1;

assign HRESP  = (HSEL_S0_data)      ? HRESP_S0 :
                (HSEL_S1_data)      ? HRESP_S1 :
                (HSEL_S2_data)      ? HRESP_S2 :
                (HSEL_S3_data)      ? HRESP_S3 :
                (HSEL_DEFAULT_data) ? HRESP_DEF : RESP_ERROR;

endmodule
