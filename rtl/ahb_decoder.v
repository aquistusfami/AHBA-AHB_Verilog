`timescale 1ns / 1ps

module ahb_decoder (
    input  wire [31:0] HADDR,

    // Sử dụng output wire thay vì output reg
    output wire        HSEL_S0,
    output wire        HSEL_S1,
    output wire        HSEL_S2,
    output wire        HSEL_S3,
    output wire        HSEL_DEFAULT
);

// Phân giải địa chỉ bằng assign liên tục thuần tổ hợp.
// Các khoảng trống (gaps) bộ nhớ: 0x1, 0x3, 0x5 và từ 0xA đến 0xF hiện là RESERVED. 
// Bất kỳ truy cập nào vào các dải này sẽ tự động rơi vào Default Slave.

// ROM / BOOT FLASH (0x0000_0000 - 0x0FFF_FFFF)
assign HSEL_S0 = (HADDR[31:28] == 4'h0);

// SRAM (0x2000_0000 - 0x2FFF_FFFF)
assign HSEL_S1 = (HADDR[31:28] == 4'h2);

// AHB-APB BRIDGE (0x4000_0000 - 0x4FFF_FFFF)
assign HSEL_S2 = (HADDR[31:28] == 4'h4);

// EXTERNAL DDR (0x6000_0000 - 0x9FFF_FFFF)
assign HSEL_S3 = (
    (HADDR[31:28] == 4'h6) || 
    (HADDR[31:28] == 4'h7) || 
    (HADDR[31:28] == 4'h8) || 
    (HADDR[31:28] == 4'h9)
);

// DEFAULT SLAVE (Bắt toàn bộ các khoảng trống địa chỉ chưa được map ở trên)
assign HSEL_DEFAULT = !(HSEL_S0 || HSEL_S1 || HSEL_S2 || HSEL_S3);

endmodule
