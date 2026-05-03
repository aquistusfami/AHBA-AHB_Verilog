`timescale 1ns / 1ps

module ahb_arbiter #(
    parameter NUM_MASTERS = 4,
    parameter DEFAULT_MASTER = 4'd0
)(
    input  wire                   HCLK,
    input  wire                   HRESETn,

    // Tín hiệu yêu cầu từ Masters
    input  wire [NUM_MASTERS-1:0] HBUSREQ,
    input  wire [NUM_MASTERS-1:0] HLOCK,

    // Tín hiệu giám sát Bus
    input  wire [1:0]             HTRANS,
    input  wire [2:0]             HBURST,
    input  wire [1:0]             HRESP,
    input  wire                   HREADY,

    // Tín hiệu điều khiển xuất ra
    output reg  [NUM_MASTERS-1:0] HGRANT,
    output reg  [3:0]             HMASTER,
    output reg                    HMASTLOCK
);

    // --- Định nghĩa Localparam ---
    localparam TR_IDLE   = 2'b00;
    localparam TR_BUSY   = 2'b01;
    localparam TR_NONSEQ = 2'b10;
    localparam TR_SEQ    = 2'b11;

    localparam RESP_OKAY = 2'b00;

    // --- Thanh ghi trạng thái nội bộ ---
    reg  [3:0] last_master;
    reg  [3:0] beat_cnt;       // Bộ đếm nhịp cho Burst
    reg        burst_active;   // Cờ báo hiệu đang trong một gói Burst không thể ngắt

    // --- Biến Combinational ---
    wire [NUM_MASTERS-1:0] mask;
    wire [NUM_MASTERS-1:0] masked_req;
    wire [NUM_MASTERS-1:0] active_req;
    wire [NUM_MASTERS-1:0] next_grant_oh; // One-hot vector cho Next Grant
    reg  [3:0]             next_master_id;
    wire                   error_or_retry;

    //--------------------------------------------------------------------------
    // 1. QUẢN LÝ BURST & NGOẠI LỆ (BEAT COUNTER & HRESP)
    //--------------------------------------------------------------------------
    assign error_or_retry = (HRESP != RESP_OKAY); // Slave báo lỗi hoặc Retry

    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            beat_cnt     <= 4'd0;
            burst_active <= 1'b0;
        end else if (error_or_retry) begin
            // Ngoại lệ: Nếu Slave báo lỗi/retry -> Lập tức bẻ gãy Burst
            beat_cnt     <= 4'd0;
            burst_active <= 1'b0;
        end else if (HREADY) begin
            if (HTRANS == TR_NONSEQ) begin
                // Bắt đầu một giao dịch mới, nạp số nhịp đếm dựa trên HBURST
                case (HBURST)
                    3'b011: begin beat_cnt <= 4'd3;  burst_active <= 1'b1; end // INCR4 / WRAP4
                    3'b101: begin beat_cnt <= 4'd7;  burst_active <= 1'b1; end // INCR8 / WRAP8
                    3'b111: begin beat_cnt <= 4'd15; burst_active <= 1'b1; end // INCR16 / WRAP16
                    default:begin beat_cnt <= 4'd0;  burst_active <= 1'b0; end // SINGLE hoặc INCR vô hạn
                endcase
            end else if (HTRANS == TR_SEQ && burst_active) begin
                // Đang truyền gói Burst, giảm bộ đếm
                if (beat_cnt > 4'd1) begin
                    beat_cnt <= beat_cnt - 1'b1;
                end else begin
                    beat_cnt <= 4'd0;
                    burst_active <= 1'b0; // Hoàn tất gói Burst
                end
            end
        end
    end

    //--------------------------------------------------------------------------
    // 2. LOGIC TỔ HỢP TÌM MASTER TIẾP THEO (KHÔNG DÙNG VÒNG LẶP FOR)
    //--------------------------------------------------------------------------
    // Tạo mặt nạ (mask) để che đi các Master có độ ưu tiên thấp (nhỏ hơn hoặc bằng last_master)
    assign mask = ~((1 << (last_master + 1)) - 1);
    
    // Áp dụng mặt nạ vào yêu cầu hiện tại
    assign masked_req = HBUSREQ & mask;
    
    // Nếu vùng ưu tiên cao có yêu cầu -> dùng masked_req, ngược lại vòng lại quét từ đầu (HBUSREQ)
    assign active_req = (|masked_req) ? masked_req : HBUSREQ;
    
    // Mạch Priority Encoder siêu tốc bằng phép toán bit: Cô lập bit 1 ngoài cùng bên phải (LSB)
    assign next_grant_oh = active_req & ~(active_req - 1);

    // Chuyển đổi One-hot sang Binary ID (Bộ giải mã thuần túy)
    always @(*) begin
        case (next_grant_oh)
            4'b0001: next_master_id = 4'd0;
            4'b0010: next_master_id = 4'd1;
            4'b0100: next_master_id = 4'd2;
            4'b1000: next_master_id = 4'd3;
            default: next_master_id = DEFAULT_MASTER; // Default Master Fallback
        endcase
    end

    //--------------------------------------------------------------------------
    // 3. TÍNH TOÁN QUYẾT ĐỊNH CẤP QUYỀN (ARBITRATION DECISION)
    //--------------------------------------------------------------------------
    reg [3:0] final_next_master;

    always @(*) begin
        // Kiểm tra Lớp 1: Khóa (HLOCK) hoặc Đang trong gói Burst (burst_active)
        if (!error_or_retry && (HLOCK[HMASTER] || burst_active || HTRANS == TR_BUSY)) begin
            final_next_master = HMASTER; // Giữ chặt Bus
        end 
        // Kiểm tra Lớp 2 & 3: Round-Robin hoặc Default Master
        else begin
            if (|HBUSREQ) final_next_master = next_master_id;
            else          final_next_master = DEFAULT_MASTER;
        end
    end

    //--------------------------------------------------------------------------
    // 4. LOGIC TUẦN TỰ (PIPELINE & CHUYỂN GIAO QUYỀN)
    //--------------------------------------------------------------------------
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            last_master <= DEFAULT_MASTER;
            HMASTER     <= DEFAULT_MASTER;
            HGRANT      <= (1 << DEFAULT_MASTER);
            HMASTLOCK   <= 1'b0;
        end else begin
            // HGRANT luôn được "Dự báo trước" và xuất ra ngay để Master kịp chuẩn bị địa chỉ
            if (HREADY || error_or_retry) begin
                HGRANT <= (1 << final_next_master);
            end

            // HMASTER chỉ thay đổi ở nhịp HREADY == 1 (Bảo vệ Pipelining)
            if (HREADY) begin
                last_master <= final_next_master;
                HMASTER     <= final_next_master;
                HMASTLOCK   <= HLOCK[final_next_master];
            end
        end
    end

endmodule
