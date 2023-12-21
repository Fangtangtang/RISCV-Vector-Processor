// #############################################################################################################################
// TOP
// 
// #############################################################################################################################
`include"src/core.v"
`include"src/mem/data_cache.v"
`include"src/mem/instruction_cache.v"
`include"src/mem/main_memory.v"

module top#(parameter SIM = 0,
            parameter LEN = 32)
           (input wire EXCLK,
            input wire btnC,
            output wire Tx,
            input wire Rx,
            output wire led);
    
    localparam SYS_CLK_FREQ = 100000000;		 // 系统时钟频率
    localparam UART_BAUD_RATE = 115200;			 // UART通信的波特率（数据在串行通信中传输的速率。它表示每秒传输的位数）
    
    reg rst;
    reg rst_delay;
    
    wire clk;	          // 时钟
    assign clk = EXCLK; // 内部时钟和外部输入的时钟相连
    
    always @(posedge clk or posedge btnC)
    begin
        if (btnC)
        begin
            rst       <= 1'b1;
            rst_delay <= 1'b1;
        end
        else
        begin
            rst_delay <= 1'b0;
            rst       <= rst_delay;
        end
    end
    
    wire core_rdy = 1;
    
    // todo: add module

endmodule
