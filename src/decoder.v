// #############################################################################################################################
// DECODER
// 
// 组合逻辑 解码指令
// #############################################################################################################################
`include "src/defines.v"

module DECODER#(parameter ADDR_WIDTH = 17,
                parameter LEN = 32,
                parameter BYTE_SIZE = 8,
                parameter VECTOR_SIZE = 8,
                parameter ENTRY_INDEX_SIZE = 3)
               (input chip_enabled,
                input wire [LEN-1:0] instruction,
                output wire is_vector_instruction,
                output wire [4:0] s1_index,
                output wire [4:0] s2_insdex,
                output wire [4:0] d_index,
                output wire [LEN-1:0] immediate,
                output wire [2:0] alu_signal,
                output wire [1:0] mem_vis_signal,
                output wire [1:0] branch_signal,
                output wire [1:0] wb_signal);

    // 使用的向量或标量寄存器下标
    assign s1_index  = instruction[19:15];
    assign s2_insdex = instruction[24:20];
    assign d_index   = instruction[11:7];

    
endmodule
