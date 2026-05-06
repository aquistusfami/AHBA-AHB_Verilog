`timescale 1ns / 1ps
`include "ahb_defines.v"

module ahb_tb;
    // 1. KHAI BÁO TÍN HIỆU ĐỒNG HỒ & RESET
    reg HCLK;
    reg HRESETn;
    // 2. TÍN HIỆU GIAO TIẾP VỚI CÁC MASTER (COMMAND INTERFACE)
    // Master 1
    reg         cmd_start_m1, cmd_write_m1, cmd_lock_m1;
    reg  [31:0] cmd_addr_m1, cmd_wdata_m1;
    wire        done_m1;
    
    // Master 2
    reg         cmd_start_m2, cmd_write_m2, cmd_lock_m2;
    reg  [31:0] cmd_addr_m2, cmd_wdata_m2;
    wire        done_m2;

    // Master 3
    reg         cmd_start_m3, cmd_write_m3, cmd_lock_m3;
    reg  [31:0] cmd_addr_m3, cmd_wdata_m3;
    wire        done_m3;
    // 3. TÍN HIỆU ĐIỀU KHIỂN SLAVE TỪ TESTBENCH
    reg stall_req_s1; // Kích hoạt Wait State cho Slave 1
    reg stall_req_s2; // Kích hoạt Wait State cho Slave 2
    // 4. KHAI BÁO DÂY NỐI BUS (NỐI BÊN TRONG TESTBENCH THAY CHO AHB_TOP)
    // Dây tín hiệu tổng (Broadcast)
    wire [31:0] sys_HADDR, sys_HWDATA, sys_HRDATA;
    wire [1:0]  sys_HTRANS, sys_HRESP;
    wire        sys_HWRITE, sys_HREADY;
    wire [3:0]  sys_HMASTER, sys_HGRANT;
    wire        sys_HMASTLOCK;
    // Dây tín hiệu từ các Master
    wire [3:0]  sys_HBUSREQ, sys_HLOCK;
    wire [31:0] haddr_m1, hwdata_m1; wire [1:0] htrans_m1; wire hwrite_m1;
    wire [31:0] haddr_m2, hwdata_m2; wire [1:0] htrans_m2; wire hwrite_m2;
    wire [31:0] haddr_m3, hwdata_m3; wire [1:0] htrans_m3; wire hwrite_m3;

    // Dây tín hiệu từ Decoder & Slaves
    wire hsel_s0, hsel_s1, hsel_s2, hsel_s3, hsel_def;
    wire [31:0] hrdata_s1, hrdata_s2;
    wire hreadyout_s1, hreadyout_s2;
    wire [1:0] hresp_s1, hresp_s2;
    // 5. KHỞI TẠO CÁC MODULE (INSTANTIATION)
    // --- 5.1. ARBITER (Phân xử) ---
    ahb_arbiter u_arbiter (
        .HCLK(HCLK), .HRESETn(HRESETn),
        .HBUSREQ(sys_HBUSREQ), .HLOCK(sys_HLOCK),
        .HTRANS(sys_HTRANS), .HBURST(3'b000), .HRESP(sys_HRESP), .HREADY(sys_HREADY),
        .HGRANT(sys_HGRANT), .HMASTER(sys_HMASTER), .HMASTLOCK(sys_HMASTLOCK)
    );

    // --- 5.2. DECODER (Giải mã địa chỉ) ---
    ahb_decoder u_decoder (
        .HADDR(sys_HADDR),
        .HSEL_S0(hsel_s0), .HSEL_S1(hsel_s1), .HSEL_S2(hsel_s2), 
        .HSEL_S3(hsel_s3), .HSEL_DEFAULT(hsel_def)
    );

    // --- 5.3. MUX (Định tuyến dữ liệu) ---
    ahb_mux u_mux (
        .HCLK(HCLK), .HRESETn(HRESETn),
        .HMASTER(sys_HMASTER),
        .HSEL_S0(hsel_s0), .HSEL_S1(hsel_s1), .HSEL_S2(hsel_s2), .HSEL_S3(hsel_s3), .HSEL_DEFAULT(hsel_def),
        // M0 (Default Master - Không làm gì)
        .HADDR_M0(32'd0), .HWDATA_M0(32'd0), .HTRANS_M0(2'd0), .HWRITE_M0(1'b0),
        // M1, M2, M3
        .HADDR_M1(haddr_m1), .HWDATA_M1(hwdata_m1), .HTRANS_M1(htrans_m1), .HWRITE_M1(hwrite_m1),
        .HADDR_M2(haddr_m2), .HWDATA_M2(hwdata_m2), .HTRANS_M2(htrans_m2), .HWRITE_M2(hwrite_m2),
        .HADDR_M3(haddr_m3), .HWDATA_M3(hwdata_m3), .HTRANS_M3(htrans_m3), .HWRITE_M3(hwrite_m3),
        // Slave 1 & 2 (Có thật)
        .HRDATA_S1(hrdata_s1), .HREADYOUT_S1(hreadyout_s1), .HRESP_S1(hresp_s1),
        .HRDATA_S2(hrdata_s2), .HREADYOUT_S2(hreadyout_s2), .HRESP_S2(hresp_s2),
        // Slave 0, 3, Def (Dummy - Luôn sẵn sàng)
        .HRDATA_S0(32'd0), .HREADYOUT_S0(1'b1), .HRESP_S0(2'd0),
        .HRDATA_S3(32'd0), .HREADYOUT_S3(1'b1), .HRESP_S3(2'd0),
        .HRDATA_DEF(32'd0), .HREADYOUT_DEF(1'b1), .HRESP_DEF(2'd0),
        // Outputs
        .HADDR(sys_HADDR), .HWDATA(sys_HWDATA), .HTRANS(sys_HTRANS), .HWRITE(sys_HWRITE),
        .HRDATA(sys_HRDATA), .HREADY(sys_HREADY), .HRESP(sys_HRESP)
    );

    // --- 5.4. MASTERS ---
    assign sys_HBUSREQ[0] = 1'b0; assign sys_HLOCK[0] = 1'b0;

    ahb_master u_master1 (
        .HCLK(HCLK), .HRESETn(HRESETn), .HGRANT(sys_HGRANT[1]), .HREADY(sys_HREADY), .HRESP(sys_HRESP), .HRDATA(sys_HRDATA),
        .HBUSREQ(sys_HBUSREQ[1]), .HLOCK(sys_HLOCK[1]), .HTRANS(htrans_m1), .HADDR(haddr_m1), .HWRITE(hwrite_m1), .HWDATA(hwdata_m1),
        .cmd_start(cmd_start_m1), .cmd_addr(cmd_addr_m1), .cmd_wdata(cmd_wdata_m1), .cmd_write(cmd_write_m1), .cmd_lock(cmd_lock_m1), .done(done_m1)
    );

    ahb_master u_master2 (
        .HCLK(HCLK), .HRESETn(HRESETn), .HGRANT(sys_HGRANT[2]), .HREADY(sys_HREADY), .HRESP(sys_HRESP), .HRDATA(sys_HRDATA),
        .HBUSREQ(sys_HBUSREQ[2]), .HLOCK(sys_HLOCK[2]), .HTRANS(htrans_m2), .HADDR(haddr_m2), .HWRITE(hwrite_m2), .HWDATA(hwdata_m2),
        .cmd_start(cmd_start_m2), .cmd_addr(cmd_addr_m2), .cmd_wdata(cmd_wdata_m2), .cmd_write(cmd_write_m2), .cmd_lock(cmd_lock_m2), .done(done_m2)
    );

    ahb_master u_master3 (
        .HCLK(HCLK), .HRESETn(HRESETn), .HGRANT(sys_HGRANT[3]), .HREADY(sys_HREADY), .HRESP(sys_HRESP), .HRDATA(sys_HRDATA),
        .HBUSREQ(sys_HBUSREQ[3]), .HLOCK(sys_HLOCK[3]), .HTRANS(htrans_m3), .HADDR(haddr_m3), .HWRITE(hwrite_m3), .HWDATA(hwdata_m3),
        .cmd_start(cmd_start_m3), .cmd_addr(cmd_addr_m3), .cmd_wdata(cmd_wdata_m3), .cmd_write(cmd_write_m3), .cmd_lock(cmd_lock_m3), .done(done_m3)
    );

    // --- 5.5. SLAVES ---
    ahb_slave u_slave1 ( // Chịu trách nhiệm dải 0x2000_0000
        .HCLK(HCLK), .HRESETn(HRESETn), .HSEL(hsel_s1), .HADDR(sys_HADDR), .HTRANS(sys_HTRANS), .HWRITE(sys_HWRITE), .HWDATA(sys_HWDATA), .HREADY_IN(sys_HREADY),
        .HREADY_OUT(hreadyout_s1), .HRESP(hresp_s1), .HRDATA(hrdata_s1), .stall_req(stall_req_s1)
    );

    ahb_slave u_slave2 ( // Chịu trách nhiệm dải 0x4000_0000
        .HCLK(HCLK), .HRESETn(HRESETn), .HSEL(hsel_s2), .HADDR(sys_HADDR), .HTRANS(sys_HTRANS), .HWRITE(sys_HWRITE), .HWDATA(sys_HWDATA), .HREADY_IN(sys_HREADY),
        .HREADY_OUT(hreadyout_s2), .HRESP(hresp_s2), .HRDATA(hrdata_s2), .stall_req(stall_req_s2)
    );

    // 6. PHÁT XUNG NHỊP (CLOCK GENERATOR)
    initial begin
        HCLK = 0;
        forever #5 HCLK = ~HCLK; // 10ns = 100MHz
    end
    // 7. KỊCH BẢN CHẠY TESTBENCH (TEST SCENARIOS)
    initial begin
        // Cấu hình xuất file VCD cho GTKWave
        $dumpfile("ahb_wave.vcd");
        $dumpvars(0, ahb_tb);

        // Khởi tạo các tín hiệu Command ban đầu
        cmd_start_m1 = 0; cmd_lock_m1 = 0;
        cmd_start_m2 = 0; cmd_lock_m2 = 0;
        cmd_start_m3 = 0; cmd_lock_m3 = 0;
        stall_req_s1 = 0; stall_req_s2 = 0;

        // Reset hệ thống
        HRESETn = 0;
        #15; HRESETn = 1;
        $display("---------------------------------------------------");
        $display("[%0t] HỆ THỐNG KHỞI ĐỘNG XONG", $time);
        
        // ---------------------------------------------------------
        // SCENARIO 4: BUS IDLE
        // ---------------------------------------------------------
        $display("\n[%0t] SCENARIO 4: Kiem tra trang thai Bus ranh (Idle)", $time);
        #20; // Đợi 2 chu kỳ để thấy sys_HMASTER trỏ về 0 (Default Master)

        // ---------------------------------------------------------
        // SCENARIO 1: SINGLE TRANSFER (M1 Ghi vào Slave 1)
        // ---------------------------------------------------------
        $display("\n[%0t] SCENARIO 1: Master 1 Ghi du lieu vao Slave 1", $time);
        @(posedge HCLK);
        cmd_addr_m1  = 32'h2000_0004; 
        cmd_wdata_m1 = 32'hDEADBEEF; 
        cmd_write_m1 = 1'b1; 
        cmd_start_m1 = 1'b1; 
        
        @(posedge HCLK) cmd_start_m1 = 1'b0; // Xung kích hoạt chỉ cần 1 chu kỳ
        wait(done_m1); // Lệnh này giúp Testbench tự động chờ Master làm xong việc
        $display("[%0t] => Master 1 Giao dich thanh cong!", $time);
        #20;

        // ---------------------------------------------------------
        // SCENARIO 3: WAIT STATES (Kiểm tra Pipelining khi Slave báo bận)
        // ---------------------------------------------------------
        $display("\n[%0t] SCENARIO 3: Kiem tra Wait States voi Slave 1", $time);
        @(posedge HCLK);
        stall_req_s1 = 1'b1; // Ép Slave 1 kéo HREADY xuống 0
        
        cmd_addr_m1  = 32'h2000_0008; 
        cmd_wdata_m1 = 32'hBEEFCAFE; 
        cmd_write_m1 = 1'b1; 
        cmd_start_m1 = 1'b1;
        
        @(posedge HCLK) cmd_start_m1 = 1'b0;
        
        #30; // Hệ thống sẽ bị đóng băng ở đây do Slave 1 chưa sẵn sàng
        $display("[%0t] => He thong dang bi treo vi Slave 1 ban (HREADY = 0)", $time);
        
        stall_req_s1 = 1'b0; // Nhả bận cho Slave 1
        $display("[%0t] => Slave 1 da san sang, tiep tuc xu ly...", $time);
        
        wait(done_m1);
        $display("[%0t] => Master 1 Giao dich xuyen Wait States thanh cong!", $time);
        #20;

        // ---------------------------------------------------------
        // SCENARIO 2: ROUND-ROBIN ARBITRATION (Tranh chấp Bus)
        // ---------------------------------------------------------
        $display("\n[%0t] SCENARIO 2: Tranh chap Bus (M1, M2, M3 xin cung luc)", $time);
        @(posedge HCLK);
        // Thiết lập lệnh cho 3 Master
        cmd_addr_m1 = 32'h2000_0010; cmd_wdata_m1 = 32'h11111111; cmd_write_m1 = 1'b1;
        cmd_addr_m2 = 32'h4000_0014; cmd_wdata_m2 = 32'h22222222; cmd_write_m2 = 1'b1;
        cmd_addr_m3 = 32'h2000_0018; cmd_wdata_m3 = 32'h33333333; cmd_write_m3 = 1'b1;
        
        // Nhấn nút kích hoạt cả 3 cùng lúc
        cmd_start_m1 = 1'b1; cmd_start_m2 = 1'b1; cmd_start_m3 = 1'b1;
        
        @(posedge HCLK);
        cmd_start_m1 = 1'b0; cmd_start_m2 = 1'b0; cmd_start_m3 = 1'b0;
        
        // Đợi cả 3 ông báo done
        wait(done_m1 && done_m2 && done_m3);
        $display("[%0t] => Arbiter da phan xu xong cho ca 3 Master!", $time);
        #20;

        // ---------------------------------------------------------
        // SCENARIO 5: LOCKED TRANSFER
        // ---------------------------------------------------------
        $display("\n[%0t] SCENARIO 5: Locked Transfer (M1 khoa Bus)", $time);
        @(posedge HCLK);
        // Master 1 xin Bus và yêu cầu khóa (cmd_lock = 1)
        cmd_addr_m1  = 32'h4000_0020; 
        cmd_wdata_m1 = 32'h99999999; 
        cmd_write_m1 = 1'b1; 
        cmd_lock_m1  = 1'b1; // Tín hiệu Khóa
        cmd_start_m1 = 1'b1;
        
        // Vài nhịp sau, M2 cố gắng chen ngang
        #10; 
        cmd_start_m1 = 1'b0;
        cmd_addr_m2  = 32'h4000_0024; 
        cmd_wdata_m2 = 32'h88888888; 
        cmd_write_m2 = 1'b1; 
        cmd_start_m2 = 1'b1;
        
        @(posedge HCLK) cmd_start_m2 = 1'b0;
        
        wait(done_m1);
        cmd_lock_m1 = 1'b0; // M1 làm xong, nhả khóa
        $display("[%0t] => Master 1 da xong viec va nha khoa HLOCK.", $time);
        
        wait(done_m2);
        $display("[%0t] => Master 2 bi doi den bay gio moi duoc ghi.", $time);

        $display("\n[%0t] KET THUC TOAN BO KIEM THU (ALL TESTS PASSED).", $time);
        $display("---------------------------------------------------");
        $finish;
    end

endmodule
