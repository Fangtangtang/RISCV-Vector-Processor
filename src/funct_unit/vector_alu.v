// #############################################################################################################################
// VECTOR ALU
// 
// 向量计算时每个lane中一个
// #############################################################################################################################
`include"src/defines.v"

module VECTOR_ALU#(parameter ADDR_WIDTH = 17,
                   parameter LEN = 32,
                   parameter LONGEST_LEN = 64,
                   parameter BYTE_SIZE = 8,
                   parameter VECTOR_SIZE = 8,
                   parameter ENTRY_INDEX_SIZE = 3,
                   parameter LANE_INDEX_SIZE = 1)
                  (input [2:0] PREV_VSEW,
                   input [2:0] CUR_VSEW,
                   input vm,
                   input [LEN - 1:0] vs1,
                   input [LEN - 1:0] vs2,
                   input [LEN - 1:0] mask,
                   input [LEN - 1:0] imm,                  // 立即数
                   input [LEN - 1:0] rs,                   // 标量操作数
                   input [2:0] alu_signal,
                   input [1:0] vec_operand_type,
                   input [5:0] opcode,
                   output reg [LONGEST_LEN - 1:0] result);
    
    wire [63:0] e_byte_vs1;
    wire [63:0] e_byte_vs2;
    wire [63:0] e_byte_mask;
    assign e_byte_vs1  = vs1;
    assign e_byte_vs2  = vs2;
    assign e_byte_mask = mask;
    
    wire [31:0] f_byte_vs1;
    wire [31:0] f_byte_vs2;
    wire [31:0] f_byte_mask;
    assign f_byte_vs1  = vs1[31:0];
    assign f_byte_vs2  = vs2[31:0];
    assign f_byte_mask = mask[31:0];
    
    wire [15:0] t_byte_vs1;
    wire [15:0] t_byte_vs2;
    wire [15:0] t_byte_mask;
    assign t_byte_vs1  = vs1[15:0];
    assign t_byte_vs2  = vs2[15:0];
    assign t_byte_mask = mask[15:0];
    
    wire [7:0] o_byte_vs1;
    wire [7:0] o_byte_vs2;
    wire [7:0] o_byte_mask;
    assign o_byte_vs1  = vs1[7:0];
    assign o_byte_vs2  = vs2[7:0];
    assign o_byte_mask = mask[7:0];
    
    reg [63:0] e_alu_result;
    reg [31:0] f_alu_result;
    reg [15:0] t_alu_result;
    reg [7:0] o_alu_result;
    
    always @(*) begin
        case (opcode)
            `VECTOR_ADD:begin
                e_alu_result = e_byte_vs1 + e_byte_vs2;
                f_alu_result = f_byte_vs1 + f_byte_vs2;
                t_alu_result = t_byte_vs1 + t_byte_vs2;
                o_alu_result = o_byte_vs1 + o_byte_vs2;
            end
            `VECTOR_SUB:begin
                e_alu_result = e_byte_vs1 - e_byte_vs2;
                f_alu_result = f_byte_vs1 - f_byte_vs2;
                t_alu_result = t_byte_vs1 - t_byte_vs2;
                o_alu_result = o_byte_vs1 - o_byte_vs2;
            end
            `VECTOR_WADDU:begin
                
            end
            `VECTOR_WSUBU:begin
                
            end
            `VECTOR_WADD:begin
                
            end
            `VECTOR_WSUB:begin
                
            end
            `VECTOR_ADC:begin
                
            end
            `VECTOR_SBC:begin
                
            end
            `VECTOR_MSBC:begin
                
            end
            `VECTOR_MACC:begin
                
            end
            `VECTOR_NMSAC:begin
                
            end
            `VECTOR_MADD:begin
                
            end
            `VECTOR_ZEXT2:begin
                
            end
            `VECTOR_SEXT2:begin
                
            end
            `VECTOR_ZEXT4:begin
                
            end
            `VECTOR_SEXT4:begin
                
            end
            `VECTOR_ZEXT8:begin
                
            end
            `VECTOR_SEXT8:begin
                
            end
            default:
            $display("[ERROR]:unexpected opcode in vector alu\n");
        endcase
    end
    
    // 根据CUR_VSEW输出数据
    always @(*) begin
        case (CUR_VSEW)
            `ONE_BYTE:begin
                result = {56'b0,o_alu_result};
            end
            `TWO_BYTE:begin
                result = {48'b0,t_alu_result};
            end
            `FOUR_BYTE:begin
                result = {32'b0,f_alu_result};
            end
            `EIGHT_BYTE:begin
                result = e_alu_result;
            end
            default:
            $display("[ERROR]:unexpected current vsew in vector alu\n");
        endcase
    end
endmodule
