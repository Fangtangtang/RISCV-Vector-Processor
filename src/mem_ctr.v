// #############################################################################################################################
// MEMORY CONTROLER
// 
// 控制数据访存
// 连接core和data cache
// 
// - core发来标量或向量访存请求，由memory controler拆成数据类型+首地址访存
// | + 标量访存照常
// | + 带mask的向量访存，仅load/store被激活的数据位
// |   load未激活部分用默认数值0填充，write back带mask
// 
// - 未激活，快进；发向cache的地址hit（组合逻辑实现），快进
// #############################################################################################################################
`include"src/defines.v"

module MEMORY_CONTROLER#(parameter ADDR_WIDTH = 17,
                         parameter LEN = 32,
                         parameter BYTE_SIZE = 8,
                         parameter VECTOR_SIZE = 8,
                         parameter ENTRY_INDEX_SIZE = 3,
                         parameter CACHE_SIZE = 16,
                         parameter CACHE_INDEX_SIZE = 4)
                        (input wire clk,
                         input [ADDR_WIDTH-1:0] data_addr,
                         input mem_access_enabled,
                         input is_vector,                                // 是否为向量访存
                         input [1:0] d_cache_vis_signal,
                         input[2:0] scalar_data_type,
                         input [ENTRY_INDEX_SIZE:0] length,
                         input [LEN*VECTOR_SIZE-1:0] mask,               // 向量访存掩码
                         output reg [LEN-1:0] scalar_data,
                         output reg [LEN*VECTOR_SIZE-1:0] vector_data,
                         input [LEN-1:0] writen_scalar_data,
                         input [LEN*VECTOR_SIZE-1:0] writen_vector_data,
                         output reg [1:0] mem_vis_status,                // interact with main memory
                         input [LEN-1:0] mem_data,
                         input [1:0] mem_status,
                         output reg [LEN-1:0] mem_writen_data,           // 写入memory的数据
                         output [ENTRY_INDEX_SIZE:0] write_length,
                         output [ADDR_WIDTH-1:0] mem_vis_addr,           // 访存地址
                         output [2:0] data_type,                         // 数据类型（包括标量向量）
                         output reg [1:0] mem_vis_signal);
endmodule
    
