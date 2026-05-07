`timescale 1ns / 1ps

module ahb_decoder (

    input  wire [31:0] HADDR,

    output reg         HSEL_S0,
    output reg         HSEL_S1,
    output reg         HSEL_S2,
    output reg         HSEL_S3,
    output reg         HSEL_DEFAULT

);

always @(*) begin

    // Default values
    HSEL_S0      = 1'b0;
    HSEL_S1      = 1'b0;
    HSEL_S2      = 1'b0;
    HSEL_S3      = 1'b0;
    HSEL_DEFAULT = 1'b0;

    case (HADDR[31:28])

        // ROM / BOOT FLASH
        4'h0: begin
            HSEL_S0 = 1'b1;
        end

        // SRAM
        4'h2: begin
            HSEL_S1 = 1'b1;
        end

        // AHB-APB BRIDGE
        4'h4: begin
            HSEL_S2 = 1'b1;
        end

        // EXTERNAL DDR
        4'h6,
        4'h7,
        4'h8,
        4'h9: begin
            HSEL_S3 = 1'b1;
        end

        // DEFAULT SLAVE
        default: begin
            HSEL_DEFAULT = 1'b1;
        end

    endcase
end

endmodule
