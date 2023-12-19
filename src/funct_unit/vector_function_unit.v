// #############################################################################################################################
// VECTOR FUNCTION UNIT
// 
// 处理一条指令的execution
// - 组成部分
// | + Dispatcher
// |     将数据下放到各个lane
// |
// | + Lanes
// |     处理单组数据的运算，多个vector alu
// |
// | + Recaller
// |     收束，把数据收到一个result里面
// #############################################################################################################################
`include "src/defines.v"
`include "src/funct_unit/vector_alu.v"

module VECTOR_FUNCTION_UNIT#(parameter ADDR_WIDTH = 17,
                             parameter LEN = 32,                    // int数据大小
                             parameter LONGEST_LEN = 64,
                             parameter BYTE_SIZE = 8,               // int数据数量
                             parameter VECTOR_SIZE = 8,             // int数据数量
                             parameter ENTRY_INDEX_SIZE = 3,
                             parameter LANE_SIZE = 2,
                             parameter LANE_INDEX_SIZE = 1)
                            (input wire clk,                        // clock
                             input rst,
                             input rdy_in,
                             input execute,
                             input [2:0] VSEW,
                             input vm,
                             input [ENTRY_INDEX_SIZE:0] length,
                             input [VECTOR_SIZE*LEN - 1:0] vs1,
                             input [VECTOR_SIZE*LEN - 1:0] vs2,
                             input [VECTOR_SIZE*LEN - 1:0] mask,
                             input [LEN - 1:0] imm,                 // 立即数
                             input [LEN - 1:0] rs,                  // 标量操作数
                             input [2:0] alu_signal,
                             input [1:0] vec_operand_type,
                             input [4:0] ext_type,
                             input [5:0] funct6,
                             output [VECTOR_SIZE*LEN - 1:0] result,
                             output [1:0] vector_alu_status);
    
    
    reg [2:0] previous_vsew;
    reg [2:0] current_vsew;
    reg masked;
    reg [ENTRY_INDEX_SIZE:0] vector_length; // 记录所需运算的向量长度
    reg [VECTOR_SIZE*LEN - 1:0] vs1_;
    reg [VECTOR_SIZE*LEN - 1:0] vs2_;
    reg [VECTOR_SIZE*LEN - 1:0] mask_;
    reg [LEN - 1:0] imm_;
    reg [LEN - 1:0] rs_;
    reg [2:0] task_type;
    reg [1:0] operand_type;
    reg [5:0] alu_opcode;
    reg [1:0] working_status;
    
    reg [ENTRY_INDEX_SIZE:0] next;          // 下一周期起始index
    
    reg [VECTOR_SIZE*LEN - 1:0] alu_result;
    
    reg [5:0] opcode;
    reg [2:0] vsew;
    always @(*) begin
        case (funct6)
            `V_ADD:begin
                opcode = `VECTOR_ADD;
                vsew   = VSEW;
            end
            `V_SUB:begin
                opcode = `VECTOR_SUB;
                vsew   = VSEW;
            end
            `V_WADDU:begin
                opcode = `VECTOR_WADDU;
            end
            `V_WSUBU:begin
                opcode = `VECTOR_WSUBU;
            end
            `V_WADD:begin
                opcode = `VECTOR_WADD;
            end
            `V_WSUB:begin
                opcode = `VECTOR_WSUB;
            end
            `V_ADC:begin
                opcode = `VECTOR_ADC;
            end
            `V_SBC:begin
                if (vec_operand_type == `OPIVV)begin
                    opcode = `VECTOR_SBC;
                end
            end
            `V_MSBC:begin
                opcode = `VECTOR_MSBC;
            end
            `V_MACC:begin
                opcode = `VECTOR_MACC;
            end
            `V_NMSAC:begin
                opcode = `VECTOR_NMSAC;
            end
            `V_MADD:begin
                opcode = `VECTOR_MADD;
            end
            `V_ZEXT:begin
                if (vec_operand_type == `OPMVV)begin
                    case (ext_type)
                        `ZEXT2:begin
                            opcode = `VECTOR_ZEXT2;
                        end
                        `ZEXT4:begin
                            opcode = `VECTOR_ZEXT4;
                        end
                        `ZEXT8:begin
                            opcode = `VECTOR_ZEXT8;
                        end
                        default:
                        $display("[ERROR]:unexpected zext type in vector function unit\n");
                    endcase
                end
            end
            `V_SEXT:begin
                if (vec_operand_type == `OPMVV)begin
                    case (ext_type)
                        `SEXT2:begin
                            opcode = `VECTOR_SEXT2;
                        end
                        `SEXT4:begin
                            opcode = `VECTOR_SEXT4;
                        end
                        `SEXT8:begin
                            opcode = `VECTOR_SEXT8;
                        end
                        default:
                        $display("[ERROR]:unexpected sext type in vector function unit\n");
                    endcase
                end
            end
            default:
            $display("[ERROR]:unexpected funct6 in vector function unit\n");
        endcase
    end
    
    // 各type数据
    // 64bits
    wire [63:0] e_byte_vs1 [VECTOR_SIZE>>1-1:0];
    wire [63:0] e_byte_vs2 [VECTOR_SIZE>>1-1:0];
    wire [63:0] e_byte_mask [VECTOR_SIZE>>1-1:0];
    
    generate
    genvar e_i;
    for (e_i = 0;e_i < (VECTOR_SIZE>>1);e_i = e_i + 1) begin
        assign e_byte_vs1[e_i]  = vs1_[(e_i+1)*64-1 -: 64];
        assign e_byte_vs2[e_i]  = vs2_[(e_i+1)*64-1 -: 64];
        assign e_byte_mask[e_i] = mask_[(e_i+1)*64-1 -: 64];
    end
    endgenerate
    
    // 32bits
    wire [31:0] f_byte_vs1 [VECTOR_SIZE-1:0];
    wire [31:0] f_byte_vs2 [VECTOR_SIZE-1:0];
    wire [31:0] f_byte_mask [VECTOR_SIZE-1:0];
    
    generate
    genvar f_i;
    for (f_i = 0;f_i < (VECTOR_SIZE>>1);f_i = f_i + 1) begin
        assign f_byte_vs1[f_i]  = vs1_[(f_i+1)*32-1 -: 32];
        assign f_byte_vs2[f_i]  = vs2_[(f_i+1)*32-1 -: 32];
        assign f_byte_mask[f_i] = mask_[(f_i+1)*32-1 -: 32];
    end
    endgenerate
    
    // 16bits
    wire [15:0] t_byte_vs1 [VECTOR_SIZE<<1-1:0];
    wire [15:0] t_byte_vs2 [VECTOR_SIZE<<1-1:0];
    wire [15:0] t_byte_mask [VECTOR_SIZE<<1-1:0];
    
    generate
    genvar t_i;
    for (t_i = 0;t_i < (VECTOR_SIZE>>1);t_i = t_i + 1) begin
        assign t_byte_vs1[t_i]  = vs1_[(t_i+1)*16-1 -: 16];
        assign t_byte_vs2[t_i]  = vs2_[(t_i+1)*16-1 -: 16];
        assign t_byte_mask[t_i] = mask_[(t_i+1)*16-1 -: 16];
    end
    endgenerate
    
    // 8bits
    wire [7:0] o_byte_vs1 [VECTOR_SIZE<<2-1:0];
    wire [7:0] o_byte_vs2 [VECTOR_SIZE<<2-1:0];
    wire [7:0] o_byte_mask [VECTOR_SIZE<<2-1:0];
    
    generate
    genvar o_i;
    for (o_i = 0;o_i < (VECTOR_SIZE>>1);o_i = o_i + 1) begin
        assign o_byte_vs1[o_i]  = vs1_[(o_i+1)*8-1 -: 8];
        assign o_byte_vs2[o_i]  = vs2_[(o_i+1)*8-1 -: 8];
        assign o_byte_mask[o_i] = mask_[(o_i+1)*8-1 -: 8];
    end
    endgenerate
    
    // Dispatcher
    always @(posedge clk) begin
        case (working_status)
            `VEC_ALU_NOP:begin
                if (execute&&length > 0) begin
                    previous_vsew  <= VSEW;
                    masked         <= vm;
                    vector_length  <= length;
                    vs1_           <= vs1;
                    vs2_           <= vs2;
                    mask_          <= mask;
                    imm_           <= imm;
                    rs_            <= rs;
                    task_type      <= alu_signal;
                    operand_type   <= vec_operand_type;
                    alu_opcode     <= opcode;
                    current_vsew   <= vsew;
                    working_status <= `VEC_ALU_WORKING;
                end
            end
            `VEC_ALU_WORKING:begin
                for (integer j = 0;j < LANE_SIZE;j = j + 1) begin
                    if (!(next + j > vector_length)) begin
                        case (current_vsew)
                            `ONE_BYTE:begin
                                alu_result[(next+j+1)*8-1 -: 8] <= out_signals[j][7:0];
                            end
                            `TWO_BYTE:begin
                                alu_result[(next+j+1)*16-1 -: 16] <= out_signals[j][15:0];
                            end
                            `FOUR_BYTE:begin
                                alu_result[(next+j+1)*32-1 -: 32] <= out_signals[j][31:0];
                            end
                            `EIGHT_BYTE:begin
                                alu_result[(next+j+1)*64-1 -: 64] <= out_signals[j][63:0];
                            end
                            default:
                            $display("[ERROR]:unexpected current vsew in vector function unit\n");
                        endcase
                    end
                end
                if (next + LANE_SIZE<vector_length) begin
                    next <= next + LANE_SIZE;
                end
                // 完成整个向量的计算
                else begin
                    next           <= 0;
                    working_status <= `VEC_ALU_FINISHED;
                end
            end
            `VEC_ALU_FINISHED:begin
                if (execute&&length > 0) begin
                    previous_vsew  <= VSEW;
                    masked         <= vm;
                    vector_length  <= length;
                    vs1_           <= vs1;
                    vs2_           <= vs2;
                    mask_          <= mask;
                    imm_           <= imm;
                    rs_            <= rs;
                    task_type      <= alu_signal;
                    operand_type   <= vec_operand_type;
                    alu_opcode     <= opcode;
                    current_vsew   <= vsew;
                    working_status <= `VEC_ALU_WORKING;
                    next           <= 0;
                end
                else begin
                    working_status <= `VEC_ALU_NOP;
                end
            end
            default:
            $display("[ERROR]:unexpected working status in vector function unit\n");
        endcase
    end
    
    // Lanes
    reg [LONGEST_LEN-1:0] in_vs1        [LANE_SIZE-1:0];
    reg [LONGEST_LEN-1:0] in_vs2        [LANE_SIZE-1:0];
    reg [LONGEST_LEN-1:0] in_mask       [LANE_SIZE-1:0];
    wire [LONGEST_LEN-1:0] out_signals  [LANE_SIZE-1:0];
    
    always @(*) begin
        case (previous_vsew)
            `ONE_BYTE:begin
                for (integer k = 0;k < LANE_SIZE;k = k + 1) begin
                    in_vs1[k]  = {56'b0,o_byte_vs1[next+k]};
                    in_vs2[k]  = {56'b0,o_byte_vs2[next+k]};
                    in_mask[k] = {56'b0,o_byte_mask[next+k]};
                end
            end
            `TWO_BYTE:begin
                for (integer k = 0;k < LANE_SIZE;k = k + 1) begin
                    in_vs1[k]  = {48'b0,t_byte_vs1[next+k]};
                    in_vs2[k]  = {48'b0,t_byte_vs2[next+k]};
                    in_mask[k] = {48'b0,t_byte_mask[next+k]};
                end
            end
            `FOUR_BYTE:begin
                for (integer k = 0;k < LANE_SIZE;k = k + 1) begin
                    in_vs1[k]  = {32'b0,f_byte_vs1[next+k]};
                    in_vs2[k]  = {32'b0,f_byte_vs2[next+k]};
                    in_mask[k] = {32'b0,f_byte_mask[next+k]};
                end
            end
            `EIGHT_BYTE:begin
                for (integer k = 0;k < LANE_SIZE;k = k + 1) begin
                    in_vs1[k]  = e_byte_vs1[next+k];
                    in_vs2[k]  = e_byte_vs2[next+k];
                    in_mask[k] = e_byte_mask[next+k];
                end
            end
            default:
            $display("[ERROR]:unexpected prev vsew in vector function unit\n");
        endcase
    end
    
    generate
    genvar i;
    for (i = 0; i < LANE_SIZE; i = i + 1) begin :instances
    VECTOR_ALU #(i) vector_alu (
    .PREV_VSEW          (previous_vsew),
    .CUR_VSEW           (current_vsew),
    .vm                 (masked),
    .vs1                (in_vs1[i]), 
    .vs2                (in_vs2[i]),
    .mask               (in_mask[i]),
    .imm                (imm_),
    .rs                 (rs_),
    .alu_signal         (task_type),
    .vec_operand_type   (operand_type),
    .opcode             (alu_opcode),
    .result             (out_signals[i])
    );
    end
    endgenerate
    
    // Recaller
    assign result            = alu_result;
    assign vector_alu_status = working_status;
    
endmodule
