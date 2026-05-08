`timescale 1ns / 1ps

// ============================================================
// FULL AHB (AMBA 2) Interconnect Multiplexer
// ============================================================

module ahb_mux #(
    parameter NUM_MASTERS = 4
)(
    input  wire        HCLK,
    input  wire        HRESETn,

    // ========================================================
    // CONTROL FROM ARBITER / DECODER
    // ========================================================

    input  wire [$clog2(NUM_MASTERS)-1:0] HMASTER,
    input  wire                           HMASTLOCK, // FIX 2: Thêm HMASTLOCK input

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
    input  wire [15:0] HSPLIT_S0,

    // ========================================================
    // SLAVE 1
    // ========================================================

    input  wire [31:0] HRDATA_S1,
    input  wire        HREADYOUT_S1,
    input  wire [1:0]  HRESP_S1,
    input  wire [15:0] HSPLIT_S1,

    // ========================================================
    // SLAVE 2
    // ========================================================

    input  wire [31:0] HRDATA_S2,
    input  wire        HREADYOUT_S2,
    input  wire [1:0]  HRESP_S2,
    input  wire [15:0] HSPLIT_S2,

    // ========================================================
    // SLAVE 3
    // ========================================================

    input  wire [31:0] HRDATA_S3,
    input  wire        HREADYOUT_S3,
    input  wire [1:0]  HRESP_S3,
    input  wire [15:0] HSPLIT_S3,

    // ========================================================
    // DEFAULT SLAVE
    // ========================================================

    input  wire [31:0] HRDATA_DEF,
    input  wire        HREADYOUT_DEF,
    input  wire [1:0]  HRESP_DEF,
    input  wire [15:0] HSPLIT_DEF,

    // ========================================================
    // BROADCAST TO SLAVES
    // ========================================================

    output wire [$clog2(NUM_MASTERS)-1:0] HMASTER_OUT,
    output wire                           HMASTLOCK_OUT, // FIX 2: Phát sóng HMASTLOCK
    
    output wire [31:0] HADDR,
    output wire [31:0] HWDATA,
    output wire [1:0]  HTRANS,
    output wire        HWRITE,
    output wire [2:0]  HSIZE,
    output wire [2:0]  HBURST,
    output wire [3:0]  HPROT,

    // ========================================================
    // RETURN TO MASTERS / ARBITER
    // ========================================================

    output wire [31:0] HRDATA,
    output wire        HREADY,
    output wire [1:0]  HRESP,
    output wire [15:0] HSPLIT
);

//////////////////////////////////////////////////////////////
// LOCAL PARAMETERS
//////////////////////////////////////////////////////////////

localparam TR_IDLE   = 2'b00;
localparam TR_BUSY   = 2'b01;
localparam TR_NONSEQ = 2'b10;
localparam TR_SEQ    = 2'b11;

localparam RESP_OKAY  = 2'b00;
localparam RESP_ERROR = 2'b01;

localparam MASTER_W = $clog2(NUM_MASTERS);

//////////////////////////////////////////////////////////////
// INTERNAL SIGNALS
//////////////////////////////////////////////////////////////

wire hready_global;
wire [1:0] htrans_int; // Dùng để trích xuất HTRANS cho pipeline

//////////////////////////////////////////////////////////////
// DATA PHASE PIPELINE REGISTERS
//////////////////////////////////////////////////////////////

reg [MASTER_W-1:0] HMASTER_data;
reg [1:0]          HTRANS_data; // FIX 5: Theo dõi loại giao dịch ở Data Phase

reg HSEL_S0_data;
reg HSEL_S1_data;
reg HSEL_S2_data;
reg HSEL_S3_data;
reg HSEL_DEFAULT_data;

//////////////////////////////////////////////////////////////
// ADDRESS -> DATA PHASE PIPELINE
//////////////////////////////////////////////////////////////

always @(posedge HCLK or negedge HRESETn) begin

    if (!HRESETn) begin

        HMASTER_data      <= {MASTER_W{1'b0}};
        HTRANS_data       <= TR_IDLE;

        HSEL_S0_data      <= 1'b0;
        HSEL_S1_data      <= 1'b0;
        HSEL_S2_data      <= 1'b0;
        HSEL_S3_data      <= 1'b0;
        HSEL_DEFAULT_data <= 1'b0;

    end
    else if (hready_global) begin

        HMASTER_data      <= HMASTER;
        HTRANS_data       <= htrans_int; // Chốt HTRANS của Pha Địa Chỉ sang Pha Dữ Liệu

        HSEL_S0_data      <= HSEL_S0;
        HSEL_S1_data      <= HSEL_S1;
        HSEL_S2_data      <= HSEL_S2;
        HSEL_S3_data      <= HSEL_S3;
        HSEL_DEFAULT_data <= HSEL_DEFAULT;

    end
end

//////////////////////////////////////////////////////////////
// MASTER -> SLAVE ADDRESS / CONTROL MUX
//////////////////////////////////////////////////////////////

// FIX 1: HMASTER_OUT phải lấy từ Data Phase để Slave báo SPLIT cho đúng Master
assign HMASTER_OUT = HMASTER;
// FIX 2 & 3: Route HMASTLOCK thẳng xuống Slave (Address Phase timing)
assign HMASTLOCK_OUT = HMASTLOCK;

assign HADDR =
        (HMASTER == 0) ? HADDR_M0 :
        (HMASTER == 1) ? HADDR_M1 :
        (HMASTER == 2) ? HADDR_M2 :
        (HMASTER == 3) ? HADDR_M3 :
                         32'd0;

assign htrans_int =
        (HMASTER == 0) ? HTRANS_M0 :
        (HMASTER == 1) ? HTRANS_M1 :
        (HMASTER == 2) ? HTRANS_M2 :
        (HMASTER == 3) ? HTRANS_M3 :
                         TR_IDLE;

assign HTRANS = htrans_int;

assign HWRITE =
        (HMASTER == 0) ? HWRITE_M0 :
        (HMASTER == 1) ? HWRITE_M1 :
        (HMASTER == 2) ? HWRITE_M2 :
        (HMASTER == 3) ? HWRITE_M3 :
                         1'b0;

assign HSIZE =
        (HMASTER == 0) ? HSIZE_M0 :
        (HMASTER == 1) ? HSIZE_M1 :
        (HMASTER == 2) ? HSIZE_M2 :
        (HMASTER == 3) ? HSIZE_M3 :
                         3'b000;

assign HBURST =
        (HMASTER == 0) ? HBURST_M0 :
        (HMASTER == 1) ? HBURST_M1 :
        (HMASTER == 2) ? HBURST_M2 :
        (HMASTER == 3) ? HBURST_M3 :
                         3'b000;

assign HPROT =
        (HMASTER == 0) ? HPROT_M0 :
        (HMASTER == 1) ? HPROT_M1 :
        (HMASTER == 2) ? HPROT_M2 :
        (HMASTER == 3) ? HPROT_M3 :
                         4'b0011;

//////////////////////////////////////////////////////////////
// WRITE DATA MUX (Data Phase timing)
//////////////////////////////////////////////////////////////

assign HWDATA =
        (HMASTER_data == 0) ? HWDATA_M0 :
        (HMASTER_data == 1) ? HWDATA_M1 :
        (HMASTER_data == 2) ? HWDATA_M2 :
        (HMASTER_data == 3) ? HWDATA_M3 :
                              32'd0;

//////////////////////////////////////////////////////////////
// SLAVE -> MASTER RESPONSE MUX (Data Phase timing)
//////////////////////////////////////////////////////////////

assign HRDATA =
        (HSEL_S0_data)      ? HRDATA_S0 :
        (HSEL_S1_data)      ? HRDATA_S1 :
        (HSEL_S2_data)      ? HRDATA_S2 :
        (HSEL_S3_data)      ? HRDATA_S3 :
        (HSEL_DEFAULT_data) ? HRDATA_DEF :
                              32'd0;

assign hready_global =
        (HSEL_S0_data)      ? HREADYOUT_S0 :
        (HSEL_S1_data)      ? HREADYOUT_S1 :
        (HSEL_S2_data)      ? HREADYOUT_S2 :
        (HSEL_S3_data)      ? HREADYOUT_S3 :
        (HSEL_DEFAULT_data) ? HREADYOUT_DEF :
                              1'b1;

assign HREADY = hready_global;

// FIX 5: Logic Default Slave chuẩn mực. 
// Chỉ ném ERROR khi truy cập vô thừa nhận là NONSEQ hoặc SEQ.
assign HRESP =
        (HSEL_S0_data)      ? HRESP_S0 :
        (HSEL_S1_data)      ? HRESP_S1 :
        (HSEL_S2_data)      ? HRESP_S2 :
        (HSEL_S3_data)      ? HRESP_S3 :
        (HSEL_DEFAULT_data) ? HRESP_DEF :
        (HTRANS_data == TR_NONSEQ || HTRANS_data == TR_SEQ) ? RESP_ERROR : 
                              RESP_OKAY;

//////////////////////////////////////////////////////////////
// SLAVE -> ARBITER HSPLIT AGGREGATION
//////////////////////////////////////////////////////////////

assign HSPLIT = HSPLIT_S0 | HSPLIT_S1 | HSPLIT_S2 | HSPLIT_S3 | HSPLIT_DEF;

endmodule
