// #############################################################################################################################
// MAIN MEMORY
// 
// 和cache直接交互，带宽4bytes
// 从内存中读出的数据仍然为内存中顺序
// 
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
                    input [ENTRY_INDEX_SIZE:0] length,
                    input [LEN-1:0] written_data,
                    input [2:0] data_type,
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
    wire read_data_flag  = i_cache_mem_vis_signal == `MEM_NOP;
    
    reg [LEN-1:0] read_data;
    assign mem_data = read_data;
    
    
    // wire [31:0] storage0Value = storage[0];
    // wire [31:0] storage1Value = storage[1];
    // wire [31:0] storage2Value = storage[2];
    // wire [31:0] storage3Value = storage[3];
    
    
    always @(posedge clk) begin
        case (mem_tast_type)
            `MEM_NOP:begin
                mem_status <= `MEM_RESTING;
            end
            `MEM_READ:begin
                if (read_data_flag) begin
                    mem_status <= `MEM_DATA_FINISHED;
                end
                else begin
                    mem_status <= `MEM_INST_FINISHED;
                end
                read_data[31:24] <= storage[i_cache_mem_vis_addr];
                read_data[23:16] <= storage[i_cache_mem_vis_addr+1];
                read_data[15:8]  <= storage[i_cache_mem_vis_addr+2];
                read_data[7:0]   <= storage[i_cache_mem_vis_addr+3];
            end
            `MEM_WRITE: begin
                mem_status <= `MEM_DATA_FINISHED;
                case (data_type)
                    `ONE_BYTE:begin
                        storage[d_cache_mem_vis_addr] <= written_data[31:24];
                    end
                    `TWO_BYTE:begin
                        storage[d_cache_mem_vis_addr]   <= written_data[31:24];
                        storage[d_cache_mem_vis_addr+1] <= written_data[23:16];
                    end
                    `FOUR_BYTE:begin
                        storage[d_cache_mem_vis_addr]   <= written_data[31:24];
                        storage[d_cache_mem_vis_addr+1] <= written_data[23:16];
                        storage[d_cache_mem_vis_addr+2] <= written_data[15:8];
                        storage[d_cache_mem_vis_addr+3] <= written_data[7:0];
                    end
                    default:
                    $display("[ERROR]:unexpected data type in main memory\n");
                endcase
            end
            default:
            $display("[ERROR]:unexpected mem_tast_type in main memory\n");
        endcase
    end
    
endmodule
