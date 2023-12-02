// #############################################################################################################################
// MAIN MEMORY
// 
// 和cache直接交互，带宽4bytes
// #############################################################################################################################
`include"src/defines.v"

module MAIN_MEMORY#(parameter ADDR_WIDTH = 17,
                    parameter LEN = 32,
                    parameter BYTE_SIZE = 8,
                    parameter VECTOR_SIZE = 8,
                    parameter ENTRY_INDEX_SIZE = 3)
                   (input wire clk,
                    input [1:0] i_cache_mem_vis_signal,          // instruction cache
                    input [1:0] d_cache_mem_vis_signal,          // data cache
                    input [ADDR_WIDTH-1:0] i_cache_mem_vis_addr,
                    input [ADDR_WIDTH-1:0] d_cache_mem_vis_addr,
                    input [ENTRY_INDEX_SIZE-1:0] length,
                    input [LEN-1:0] writen_data,
                    output [LEN-1:0] mem_data,
                    output reg [1:0] mem_status);
    
    reg [BYTE_SIZE-1:0] storage [0:2**ADDR_WIDTH-1];
    
    initial begin
        for (integer i = 0;i < 2**ADDR_WIDTH;i = i + 1) begin
            storage[i] = 0;
        end
        $readmemh("/mnt/f/repo/ToyCPU/user/testspace/test.data", storage);
    end
    
    // 内存任务类型，data优先
    wire [1:0] mem_tast_type;
    assign mem_tast_type = !(d_cache_mem_vis_signal == `MEM_NOP)?d_cache_mem_vis_signal:i_cache_mem_vis_signal;
    
    // count for write and burst read
    reg [ENTRY_INDEX_SIZE-1:0] write_length;
    reg [ENTRY_INDEX_SIZE-1:0] CNT = 0;
    
    reg [LEN-1:0] read_data;
    assign mem_data = read_data;
    
    always @(posedge clk) begin
        case (mem_tast_type)
            `MEM_NOP:begin
                mem_status <= `MEM_FINISHED;
            end
            `MEM_READ:begin
                mem_status <= `MEM_FINISHED;
                read_data  <= {storage[i_cache_mem_vis_addr+3],storage[i_cache_mem_vis_addr+2],storage[i_cache_mem_vis_addr+1],storage[i_cache_mem_vis_addr]};
            end
            `MEM_WRITE: begin
                if (CNT == 0) begin
                    CNT          <= CNT + 1;
                    write_length <= length;
                    mem_status   <= `MEM_DATA_WORKING;
                end
                else if (CNT + 1 == write_length) begin
                    CNT          <= 0;
                    write_length <= 0;
                    mem_status   <= `MEM_FINISHED;
                end
                else begin
                    CNT        <= CNT + 1;
                    mem_status <= `MEM_DATA_WORKING;
                end
                storage[d_cache_mem_vis_addr+3] <= writen_data[31:24];
                storage[d_cache_mem_vis_addr+2] <= writen_data[23:16];
                storage[d_cache_mem_vis_addr+1] <= writen_data[15:8];
                storage[d_cache_mem_vis_addr]   <= writen_data[7:0];
            end
            `MEM_READ_BURST:begin
                if (CNT == 0) begin
                    CNT        <= CNT + 1;
                    mem_status <= `MEM_DATA_WORKING;
                end
                else if (CNT + 1 == ENTRY_INDEX_SIZE)begin
                    CNT        <= 0;
                    mem_status <= `MEM_FINISHED;
                end
                else begin
                    CNT        <= CNT + 1;
                    mem_status <= `MEM_DATA_WORKING;
                end
                read_data <= {storage[d_cache_mem_vis_addr+3],storage[d_cache_mem_vis_addr+2],storage[d_cache_mem_vis_addr+1],storage[d_cache_mem_vis_addr]};
            end
            default:
            $display("[ERROR]:unexpected mem_tast_type in main memory\n");
        endcase   
    end
    
endmodule
