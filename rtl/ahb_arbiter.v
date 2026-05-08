`timescale 1ns/1ps

module ahb_arbiter #(
    parameter NUM_MASTERS    = 4,
    parameter DEFAULT_MASTER = 0
)(
    input  wire                               HCLK,
    input  wire                               HRESETn,

    // Master request signals
    input  wire [NUM_MASTERS-1:0]             HBUSREQ,
    input  wire [NUM_MASTERS-1:0]             HLOCK,

    // AHB bus monitor signals
    input  wire [NUM_MASTERS-1:0]             HSPLIT,   // Slave re-enables split masters
    input  wire [1:0]                         HTRANS,
    input  wire [2:0]                         HBURST,
    input  wire [1:0]                         HRESP,
    input  wire                               HREADY,

    // Arbiter outputs
    output reg  [NUM_MASTERS-1:0]             HGRANT,
    output reg  [$clog2(NUM_MASTERS)-1:0]     HMASTER,
    output reg                                HMASTLOCK
);

// Transfer Types (AMBA 2 AHB Table 3-1)

localparam TR_IDLE   = 2'b00;
localparam TR_BUSY   = 2'b01;
localparam TR_NONSEQ = 2'b10;
localparam TR_SEQ    = 2'b11;

// Response Types (AMBA 2 AHB Table 6-1)

localparam RESP_OKAY  = 2'b00;
localparam RESP_ERROR = 2'b01;
localparam RESP_RETRY = 2'b10;
localparam RESP_SPLIT = 2'b11;

// Internal Parameters

localparam MASTER_W = $clog2(NUM_MASTERS);

// Internal Registers

reg [MASTER_W-1:0]   current_master;
reg [MASTER_W-1:0]   next_master;
reg [MASTER_W-1:0]   last_granted;
reg [MASTER_W-1:0]   addr_phase_master;

// SPLIT state tracking — one bit per master
// split_masters[n] = 1 means master n is suspended (waiting for HSPLIT)
reg [NUM_MASTERS-1:0] split_masters;

reg [4:0] beat_cnt;
reg       burst_active;

integer i;

reg [MASTER_W-1:0] temp_idx;
reg                found;

// Continuous Assignments

wire current_lock;
wire transfer_valid;
wire fixed_burst;
wire burst_last;
wire error_response;
wire retry_response;
wire split_response;
wire hold_bus;

// Current master lock status
assign current_lock =
    (HMASTER < NUM_MASTERS) ? HLOCK[HMASTER] : 1'b0;

// A valid transfer is NONSEQ or SEQ (HTRANS[1] = 1)
assign transfer_valid = HTRANS[1];

// Fixed-length burst types
assign fixed_burst =
       (HBURST == 3'b010)   // WRAP4
    || (HBURST == 3'b011)   // INCR4
    || (HBURST == 3'b100)   // WRAP8
    || (HBURST == 3'b101)   // INCR8
    || (HBURST == 3'b110)   // WRAP16
    || (HBURST == 3'b111);  // INCR16

// Response detects — all require HREADY=1 to complete (AMBA 2 spec section 6.2)
assign error_response = HREADY && (HRESP == RESP_ERROR);
assign retry_response = HREADY && (HRESP == RESP_RETRY);
assign split_response = HREADY && (HRESP == RESP_SPLIT);

// Last beat of a fixed burst
assign burst_last = (beat_cnt == 0);

assign hold_bus =
       (current_lock    && !split_response && !retry_response)
    || (burst_active    && !split_response && !retry_response)
    || (transfer_valid  && !HREADY
                        && !split_response
                        && !retry_response);

always @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
        split_masters <= {NUM_MASTERS{1'b0}};
    end
    else begin
        // Re-enable masters indicated by slave via HSPLIT
        // HSPLIT[n]=1 means slave is ready to serve master n again
        split_masters <= split_masters & ~HSPLIT;

        // Suspend current master on SPLIT response
        if (split_response && (HMASTER < NUM_MASTERS))
            split_masters[HMASTER] <= 1'b1;
    end
end

always @(*) begin

    next_master = current_master;
    found       = 1'b0;

    for (i = 1; i <= NUM_MASTERS; i = i + 1) begin

        temp_idx = last_granted + i[MASTER_W-1:0];

        if (temp_idx >= NUM_MASTERS)
            temp_idx = temp_idx - NUM_MASTERS[MASTER_W-1:0];

        // Grant only if:
        //   1. Master is requesting
        //   2. Master is NOT suspended in SPLIT state
        if (HBUSREQ[temp_idx] && !split_masters[temp_idx] && !found) begin
            next_master = temp_idx;
            found       = 1'b1;
        end
    end

    // Parking: no requests → default master gets the bus
    if (!found)
        next_master = DEFAULT_MASTER[MASTER_W-1:0];

end

always @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
        burst_active <= 1'b0;
        beat_cnt     <= 5'd0;
    end
    else begin

        // Abort burst on error or bus re-arbitration
        if (error_response || retry_response || split_response) begin
            burst_active <= 1'b0;
            beat_cnt     <= 5'd0;
        end
        else if (HREADY) begin

            // Start of a new fixed-length burst
            if ((HTRANS == TR_NONSEQ) && fixed_burst) begin
                burst_active <= 1'b1;
                case (HBURST)
                    3'b010, 3'b011: beat_cnt <= 5'd2;   // WRAP4 / INCR4  (3 beats, 2 remaining after NONSEQ)
                    3'b100, 3'b101: beat_cnt <= 5'd6;   // WRAP8 / INCR8
                    3'b110, 3'b111: beat_cnt <= 5'd14;  // WRAP16 / INCR16
                    default:        beat_cnt <= 5'd0;
                endcase
            end

            // Continue burst — count down remaining SEQ beats
            else if (burst_active && (HTRANS == TR_SEQ)) begin
                if (!burst_last)
                    beat_cnt <= beat_cnt - 1'b1;
                else
                    burst_active <= 1'b0;
            end

        end
    end
end

always @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
        current_master    <= DEFAULT_MASTER[MASTER_W-1:0];
        addr_phase_master <= DEFAULT_MASTER[MASTER_W-1:0];
        last_granted      <= DEFAULT_MASTER[MASTER_W-1:0];
    end
    else begin
        if (!hold_bus) begin
            current_master    <= next_master;
            addr_phase_master <= next_master;
            last_granted      <= next_master;
        end
    end
end

always @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
        HGRANT <= ({{(NUM_MASTERS-1){1'b0}}, 1'b1} << DEFAULT_MASTER);
    end
    else begin
        if (!hold_bus)
            HGRANT <= ({{(NUM_MASTERS-1){1'b0}}, 1'b1} << next_master);
    end
end

always @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
        HMASTER   <= DEFAULT_MASTER[MASTER_W-1:0];
        HMASTLOCK <= 1'b0;
    end
    else begin
        if (HREADY) begin
            HMASTER <= addr_phase_master;
            HMASTLOCK <= (addr_phase_master < NUM_MASTERS) ?
                          HLOCK[addr_phase_master] : 1'b0;
        end
    end
end

endmodule