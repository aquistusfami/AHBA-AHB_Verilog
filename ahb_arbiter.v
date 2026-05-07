`timescale 1ns/1ps

module ahb_arbiter #(
    parameter NUM_MASTERS = 4,
    parameter DEFAULT_MASTER = 0
)(
    input  wire                   HCLK,
    input  wire                   HRESETn,

    input  wire [NUM_MASTERS-1:0] HBUSREQ,
    input  wire [NUM_MASTERS-1:0] HLOCK,

    input  wire [1:0]             HTRANS,
    input  wire [2:0]             HBURST,
    input  wire [1:0]             HRESP,
    input  wire                   HREADY,

    output reg  [NUM_MASTERS-1:0] HGRANT,
    output reg  [3:0]             HMASTER,
    output reg                    HMASTLOCK
);

localparam TR_IDLE   = 2'b00;
localparam TR_BUSY   = 2'b01;
localparam TR_NONSEQ = 2'b10;
localparam TR_SEQ    = 2'b11;

localparam RESP_OKAY = 2'b00;

reg [3:0] current_master;
reg [3:0] next_master;
reg [3:0] last_granted;

reg [3:0] beat_cnt;
reg       burst_active;

integer i;

wire current_lock;

assign current_lock =
    (current_master < NUM_MASTERS) ?
    HLOCK[current_master] : 1'b0;

////////////////////////////////////////////////////////////
// ROUND ROBIN
////////////////////////////////////////////////////////////

always @(*) begin
    next_master = current_master;

    for (i = 1; i <= NUM_MASTERS; i = i + 1) begin
        if (HBUSREQ[(last_granted + i) % NUM_MASTERS]) begin
            next_master = (last_granted + i) % NUM_MASTERS;
            disable for;
        end
    end
end

////////////////////////////////////////////////////////////
// BURST DETECT
////////////////////////////////////////////////////////////

wire fixed_burst;

assign fixed_burst =
       (HBURST == 3'b011)
    || (HBURST == 3'b101)
    || (HBURST == 3'b111);

always @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
        burst_active <= 0;
        beat_cnt <= 0;
    end
    else if (HREADY) begin

        if ((HTRANS == TR_NONSEQ) && fixed_burst) begin

            burst_active <= 1'b1;

            case(HBURST)
                3'b011: beat_cnt <= 3;
                3'b101: beat_cnt <= 7;
                3'b111: beat_cnt <= 15;
            endcase

        end
        else if (burst_active && HTRANS == TR_SEQ) begin

            if (beat_cnt == 1) begin
                beat_cnt <= 0;
                burst_active <= 0;
            end
            else begin
                beat_cnt <= beat_cnt - 1;
            end
        end
    end
end

////////////////////////////////////////////////////////////
// ARBITRATION
////////////////////////////////////////////////////////////

wire hold_bus;

assign hold_bus =
       current_lock
    || burst_active
    || (!HREADY);

always @(posedge HCLK or negedge HRESETn) begin

    if (!HRESETn) begin

        current_master <= DEFAULT_MASTER;
        last_granted   <= DEFAULT_MASTER;

        HMASTER   <= DEFAULT_MASTER;
        HGRANT    <= (1'b1 << DEFAULT_MASTER);
        HMASTLOCK <= 0;

    end
    else begin

        if (!hold_bus) begin

            current_master <= next_master;
            last_granted   <= next_master;

            HGRANT <= (1'b1 << next_master);
        end

        if (HREADY) begin
            HMASTER   <= current_master;
            HMASTLOCK <= current_lock;
        end
    end
end

endmodule
