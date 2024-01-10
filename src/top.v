// #############################################################################################################################
// TOP
// 
// - 组成部分
// | + Core
// |
// | + I-Cache
// |
// | + D-Cache
// |
// | + Main memory
// |
// #############################################################################################################################
`include"src/core.v"
`include"src/mem_ctr.v"
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
    
    localparam ADDR_WIDTH       = 17;
    localparam BYTE_SIZE        = 32;
    localparam VECTOR_SIZE      = 8;
    localparam ENTRY_INDEX_SIZE = 3;
    localparam LONGEST_LEN      = 64;
    
    localparam I_CACHE_SIZE       = 2;
    localparam I_CACHE_INDEX_SIZE = 1;
    localparam CACHE_SIZE       	 = 16;
    localparam CACHE_INDEX_SIZE 	 = 4;
    
    
    // CORE
    // ---------------------------------------------------------------------------------------------
    // outports wire
    wire [LEN-1:0]             	mem_write_scalar_data;
    wire [LEN*VECTOR_SIZE-1:0] 	mem_write_vector_data;
    wire [ENTRY_INDEX_SIZE:0]  	vector_length;
    wire [ADDR_WIDTH-1:0]      	mem_inst_addr;
    wire [ADDR_WIDTH-1:0]      	mem_data_addr;
    wire                       	inst_fetch_enabled;
    wire                       	mem_vis_enabled;
    wire [1:0]                 	memory_vis_signal;
    wire [2:0]                 	data_type;           // todo
    wire                        is_vector;

    CORE #(
    .ADDR_WIDTH       	(ADDR_WIDTH),
    .LEN              	(LEN),
    .BYTE_SIZE        	(BYTE_SIZE),
    .VECTOR_SIZE      	(VECTOR_SIZE),
    .ENTRY_INDEX_SIZE 	(ENTRY_INDEX_SIZE),
    .LONGEST_LEN      	(LONGEST_LEN)
    )
    core(
    .clk                   	(clk),
    .rst                   	(rst),
    .rdy_in                	(rdy_in),
    .instruction           	(instruction),
    .mem_read_scalar_data  	(scalar_data),
    .mem_read_vector_data  	(vector_data),
    .mem_vis_status        	(mem_vis_status),
    .mem_write_scalar_data 	(mem_write_scalar_data),
    .mem_write_vector_data 	(mem_write_vector_data),
    .vector_length         	(vector_length),
    .mem_inst_addr         	(mem_inst_addr),
    .mem_data_addr         	(mem_data_addr),
    .inst_fetch_enabled    	(inst_fetch_enabled),
    .mem_vis_enabled       	(mem_vis_enabled),
    .memory_vis_signal     	(memory_vis_signal),
    .data_type             	(data_type),
    .is_vector              (is_vector)
    );
    
    
    // INSTRUCTION CACHE
    // ---------------------------------------------------------------------------------------------
    
    // outports wire
    wire [LEN-1:0]        	instruction;
    wire [1:0]            	inst_fetch_status;
    wire [ADDR_WIDTH-1:0] 	i_cache_mem_vis_addr;
    wire [1:0]            	i_cache_mem_vis_signal;
    
    INSTRUCTION_CACHE#(
    .ADDR_WIDTH   	(ADDR_WIDTH),
    .LEN          	(LEN),
    .BYTE_SIZE    	(BYTE_SIZE),
    .I_CACHE_SIZE 	(I_CACHE_SIZE),
    .INDEX_SIZE   	(I_CACHE_INDEX_SIZE)
    )
    instruction_cache(
    .clk                	(clk),
    .inst_addr          	(mem_inst_addr),
    .inst_fetch_enabled 	(inst_fetch_enabled),
    .instruction        	(instruction),
    .inst_fetch_status  	(inst_fetch_status),
    .mem_data           	(mem_data),
    .mem_status         	(mem_status),
    .mem_vis_addr       	(i_cache_mem_vis_addr),
    .mem_vis_signal     	(i_cache_mem_vis_signal)
    );
    
    // MEMORY CONTROLER
    // ---------------------------------------------------------------------------------------------
    
    // DATA CACHE
    // ---------------------------------------------------------------------------------------------
    
    
    // MAIN MEMORY
    // ---------------------------------------------------------------------------------------------
    // outports wire
    wire [LEN-1:0]              	mem_data;
    wire [1:0]                  	mem_status;
    
    MAIN_MEMORY #(
    .ADDR_WIDTH       	(ADDR_WIDTH),
    .LEN              	(LEN),
    .BYTE_SIZE        	(BYTE_SIZE),
    .VECTOR_SIZE      	(VECTOR_SIZE),
    .ENTRY_INDEX_SIZE 	(ENTRY_INDEX_SIZE)
    )main_memory(
    .clk                    	(clk),
    .i_cache_mem_vis_signal 	(i_cache_mem_vis_signal),
    .d_cache_mem_vis_signal 	(d_cache_mem_vis_signal),
    .i_cache_mem_vis_addr   	(i_cache_mem_vis_addr),
    .d_cache_mem_vis_addr   	(d_cache_mem_vis_addr),
    .length                 	(write_length),
    .writen_data            	(mem_writen_data),
    .mem_data               	(mem_data),
    .mem_status             	(mem_status)
    );
    
endmodule
