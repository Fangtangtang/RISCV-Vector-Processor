// #############################################################################################################################
// VECTOR ALU
// 
// 向量计算时每个lane中一个
// #############################################################################################################################
module VECTOR_ALU#(parameter ADDR_WIDTH = 17,
                   parameter LEN = 32,
                   parameter BYTE_SIZE = 8,
                   parameter VECTOR_SIZE = 8,
                   parameter ENTRY_INDEX_SIZE = 3,
                   parameter LANE_INDEX_SIZE = 1)
                  (input [LEN - 1:0] vs1,
                   input [LEN - 1:0] vs2,
                   input [LEN - 1:0] mask,
                   input [LEN - 1:0] imm,               // 立即数
                   input [LEN - 1:0] rs,                // 标量操作数
                   input [2:0] alu_signal,
                   input [1:0] vec_operand_type,
                   input [5:0] opcode,
                   output reg [LEN - 1:0] result);
    
endmodule
