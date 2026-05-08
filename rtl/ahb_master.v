`timescale 1ns / 1ps
`include "ahb_defines.v"

module ahb_master (
    input  wire        HCLK,      
    input  wire        HRESETn,   
    
    // Tín hiệu giao diện AHB
    input  wire        HGRANT,
    input  wire        HREADY,    
    input  wire [1:0]  HRESP,     
    input  wire [31:0] HRDATA,    

    output reg         HBUSREQ,   
    output reg         HLOCK,     
    output reg  [1:0]  HTRANS,    
    output reg  [31:0] HADDR,     
    output reg         HWRITE,    
    output reg  [2:0]  HSIZE,     
    output reg  [2:0]  HBURST,    
    output reg  [31:0] HWDATA,

    // Giao diện điều khiển (Dành cho Testbench ra lệnh)
    input  wire        cmd_start,   // Xung kích hoạt giao dịch
    input  wire [31:0] cmd_addr,    // Địa chỉ muốn truy cập
    input  wire [31:0] cmd_wdata,   // Dữ liệu muốn ghi
    input  wire        cmd_write,   // 1 = Ghi, 0 = Đọc
    input  wire        cmd_lock,    // 1 = Yêu cầu khóa Bus (Scenario 5)
    output reg         done         // Báo cáo đã xong giao dịch
);

    // Máy trạng thái FSM
    localparam ST_IDLE = 2'd0;
    localparam ST_REQ  = 2'd1;
    localparam ST_ADDR = 2'd2;
    localparam ST_DATA = 2'd3;

    reg [1:0] state;
    reg [31:0] r_data_to_write;

    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            state    <= ST_IDLE;
            HBUSREQ  <= 1'b0;
            HLOCK    <= 1'b0;
            HTRANS   <= `AHB_HTRANS_IDLE;
            HADDR    <= 32'd0;
            HWRITE   <= 1'b0;
            HSIZE    <= `AHB_HSIZE_WORD;
            HBURST   <= `AHB_HBURST_SINGLE;
            HWDATA   <= 32'd0;
            done     <= 1'b0;
        end else begin
            done <= 1'b0; // Pulse 1 chu kỳ khi xong

            case (state)
                ST_IDLE: begin
                    HTRANS <= `AHB_HTRANS_IDLE;
                    if (cmd_start) begin
                        HBUSREQ <= 1'b1;
                        HLOCK   <= cmd_lock;
                        state   <= ST_REQ;
                        r_data_to_write <= cmd_wdata; // Lưu lại data để dùng ở pha sau
                    end
                end

                ST_REQ: begin
                    if (HGRANT && HREADY) begin
                        // Đã được cấp quyền, xuất Pha Địa chỉ
                        HTRANS <= `AHB_HTRANS_NONSEQ;
                        HADDR  <= cmd_addr;
                        HWRITE <= cmd_write;
                        state  <= ST_ADDR;
                    end
                end

                ST_ADDR: begin
                    if (HREADY) begin
                        // Hết pha địa chỉ, chuyển sang Pha Dữ liệu
                        HTRANS <= `AHB_HTRANS_IDLE; 
                        HBUSREQ <= 1'b0; // Nhả request
                        HLOCK   <= 1'b0;
                        if (HWRITE) HWDATA <= r_data_to_write;
                        state  <= ST_DATA;
                    end
                end

                ST_DATA: begin
                    if (HREADY) begin
                        // Slave báo xong
                        done <= 1'b1;
                        state <= ST_IDLE;
                    end
                end
            endcase
        end
    end
endmodule
