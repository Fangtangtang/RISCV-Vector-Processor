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
// 
// - todo: is mask operation: 结果为1bit
// - todo: 提前结束store这类的alu时间？
// #############################################################################################################################
`include "src/defines.v"
`include "src/funct_unit/vector_alu.v"

module VECTOR_FUNCTION_UNIT#(parameter ADDR_WIDTH = 20,
                             parameter DATA_LEN = 32,                    // 内存数据单元
                             parameter SCALAR_REG_LEN = 64,              // 标量寄存器
                             parameter LONGEST_LEN = 64,                 // 标量寄存器
                             parameter BYTE_SIZE = 8,                    // int数据数量
                             parameter VECTOR_SIZE = 8,                  // int数据数量
                             parameter ENTRY_INDEX_SIZE = 3,
                             parameter LANE_SIZE = 2,
                             parameter LANE_INDEX_SIZE = 1)
                            (input wire clk,                             // clock
                             input rst,
                             input rdy_in,
                             input execute,
                             input [2:0] VSEW,
                             input vm,
                             input [DATA_LEN-1:0] length,
                             input [VECTOR_SIZE*DATA_LEN - 1:0] vs1,
                             input [VECTOR_SIZE*DATA_LEN - 1:0] vs2,
                             input [VECTOR_SIZE*DATA_LEN - 1:0] vs3,
                             input [VECTOR_SIZE*DATA_LEN - 1:0] mask,
                             input [SCALAR_REG_LEN - 1:0] imm,           // 立即数
                             input [SCALAR_REG_LEN - 1:0] rs,            // 标量操作数
                             input [3:0] alu_signal,
                             input [1:0] vec_operand_type,
                             input [4:0] ext_type,
                             input [5:0] funct6,
                             output is_mask,
                             output [VECTOR_SIZE*DATA_LEN - 1:0] result,
                             output [1:0] vector_alu_status);
    
    
    reg [2:0] previous_vsew;
    reg [2:0] current_vsew;
    reg masked;
    reg [ENTRY_INDEX_SIZE:0] vector_length; // 记录所需运算的向量长度
    reg [VECTOR_SIZE*DATA_LEN - 1:0] vs1_;
    reg [VECTOR_SIZE*DATA_LEN - 1:0] vs2_;
    reg [VECTOR_SIZE*DATA_LEN - 1:0] vs3_;
    reg [VECTOR_SIZE*DATA_LEN - 1:0] mask_;
    reg [SCALAR_REG_LEN - 1:0] imm_;
    reg [SCALAR_REG_LEN - 1:0] rs_;
    reg [3:0] task_type;
    reg [1:0] operand_type;
    reg [5:0] alu_opcode;
    reg is_mask_operation;
    reg [1:0] working_status = `VEC_ALU_NOP;
    
    reg [ENTRY_INDEX_SIZE:0] next;          // 下一周期起始index
    
    reg [VECTOR_SIZE*DATA_LEN - 1:0] alu_result;
    
    reg [5:0] opcode;
    reg is_mask_op;
    reg [2:0] vsew;
    always @(*) begin
        case (funct6)
            `V_ADD:begin
                opcode     = `VECTOR_ADD;
                vsew       = VSEW;
                is_mask_op = `FALSE;
            end
            `V_SUB:begin
                opcode     = `VECTOR_SUB;
                vsew       = VSEW;
                is_mask_op = `FALSE;
            end
            `V_WADDU:begin
                opcode     = `VECTOR_WADDU;
                vsew       = VSEW << 1;
                is_mask_op = `FALSE;
            end
            `V_WSUBU:begin
                opcode     = `VECTOR_WSUBU;
                vsew       = VSEW << 1;
                is_mask_op = `FALSE;
            end
            `V_WADD:begin
                opcode     = `VECTOR_WADD;
                vsew       = VSEW << 1;
                is_mask_op = `FALSE;
            end
            `V_WSUB:begin
                opcode     = `VECTOR_WSUB;
                vsew       = VSEW << 1;
                is_mask_op = `FALSE;
            end
            `V_ADC:begin
                opcode     = `VECTOR_ADC;
                vsew       = VSEW;
                is_mask_op = `FALSE;
            end
            `V_SBC:begin
                if (vec_operand_type == `OPIVV)begin
                    opcode     = `VECTOR_SBC;
                    vsew       = VSEW;
                    is_mask_op = `FALSE;
                end
            end
            `V_MADC:begin
                opcode     = `VECTOR_MADC;
                vsew       = VSEW;
                is_mask_op = `TRUE;
            end
            `V_MSBC:begin
                opcode     = `VECTOR_MSBC;
                vsew       = VSEW;
                is_mask_op = `TRUE;
            end
            `V_MACC:begin
                opcode     = `VECTOR_MACC;
                vsew       = VSEW;
                is_mask_op = `FALSE;
            end
            `V_NMSAC:begin
                opcode     = `VECTOR_NMSAC;
                vsew       = VSEW;
                is_mask_op = `FALSE;
            end
            `V_MADD:begin
                opcode     = `VECTOR_MADD;
                vsew       = VSEW;
                is_mask_op = `FALSE;
            end
            `V_ZEXT:begin
                if (vec_operand_type == `OPMVV)begin
                    is_mask_op = `FALSE;
                    case (ext_type)
                        `ZEXT2:begin
                            opcode = `VECTOR_ZEXT2;
                            vsew   = VSEW << 1;
                        end
                        `ZEXT4:begin
                            opcode = `VECTOR_ZEXT4;
                            vsew   = VSEW << 2;
                        end
                        `ZEXT8:begin
                            opcode = `VECTOR_ZEXT8;
                            vsew   = VSEW << 3;
                        end
                        default:
                        $display("[ERROR]:unexpected zext type in vector function unit\n");
                    endcase
                end
            end
            `V_SEXT:begin
                if (vec_operand_type == `OPMVV)begin
                    is_mask_op = `FALSE;
                    case (ext_type)
                        `SEXT2:begin
                            opcode = `VECTOR_SEXT2;
                            vsew   = VSEW << 1;
                        end
                        `SEXT4:begin
                            opcode = `VECTOR_SEXT4;
                            vsew   = VSEW << 2;
                        end
                        `SEXT8:begin
                            opcode = `VECTOR_SEXT8;
                            vsew   = VSEW << 3;
                        end
                        default:
                        $display("[ERROR]:unexpected sext type in vector function unit\n");
                    endcase
                end
            end
            `V_MOVE:begin
                case (ext_type[4:2])
                    `SEG_1:begin
                        opcode = `VECTOR_MOVE1;
                    end
                    `SEG_2:begin
                        opcode = `VECTOR_MOVE2;
                    end
                    `SEG_4:begin
                        opcode = `VECTOR_MOVE4;
                    end
                    `SEG_8:begin
                        opcode = `VECTOR_MOVE8;
                    end
                    default:
                    $display("[ERROR]:unexpected sext type in vector function unit\n");
                endcase
                vsew       = VSEW;
                is_mask_op = `FALSE;
            end
            default:
            $display("[ERROR]:unexpected funct6 in vector function unit\n");
        endcase
    end
    
    // 各type数据
    // 64bits
    wire [63:0] e_byte_vs1 [VECTOR_SIZE>>1-1:0];
    wire [63:0] e_byte_vs2 [VECTOR_SIZE>>1-1:0];
    wire [63:0] e_byte_vs3 [VECTOR_SIZE>>1-1:0];
    
    generate
    genvar e_i;
    for (e_i = 0;e_i < (VECTOR_SIZE>>1);e_i = e_i + 1) begin
        assign e_byte_vs1[e_i] = vs1_[(e_i+1)*64-1 -: 64];
        assign e_byte_vs2[e_i] = vs2_[(e_i+1)*64-1 -: 64];
        assign e_byte_vs3[e_i] = vs3_[(e_i+1)*64-1 -: 64];
    end
    endgenerate
    
    // 32bits
    wire [31:0] f_byte_vs1 [VECTOR_SIZE-1:0];
    wire [31:0] f_byte_vs2 [VECTOR_SIZE-1:0];
    wire [31:0] f_byte_vs3 [VECTOR_SIZE-1:0];
    
    generate
    genvar f_i;
    for (f_i = 0;f_i < (VECTOR_SIZE>>1);f_i = f_i + 1) begin
        assign f_byte_vs1[f_i] = vs1_[(f_i+1)*32-1 -: 32];
        assign f_byte_vs2[f_i] = vs2_[(f_i+1)*32-1 -: 32];
        assign f_byte_vs3[f_i] = vs3_[(f_i+1)*32-1 -: 32];
    end
    endgenerate
    
    // 16bits
    wire [15:0] t_byte_vs1 [(VECTOR_SIZE<<1)-1:0];
    wire [15:0] t_byte_vs2 [(VECTOR_SIZE<<1)-1:0];
    wire [15:0] t_byte_vs3 [(VECTOR_SIZE<<1)-1:0];
    
    generate
    genvar t_i;
    for (t_i = 0;t_i < (VECTOR_SIZE>>1);t_i = t_i + 1) begin
        assign t_byte_vs1[t_i] = vs1_[(t_i+1)*16-1 -: 16];
        assign t_byte_vs2[t_i] = vs2_[(t_i+1)*16-1 -: 16];
        assign t_byte_vs3[t_i] = vs3_[(t_i+1)*16-1 -: 16];
    end
    endgenerate
    
    // 8bits
    wire [7:0] o_byte_vs1 [(VECTOR_SIZE<<2)-1:0];
    wire [7:0] o_byte_vs2 [(VECTOR_SIZE<<2)-1:0];
    wire [7:0] o_byte_vs3 [(VECTOR_SIZE<<2)-1:0];
    
    generate
    genvar o_i;
    for (o_i = 0;o_i < (VECTOR_SIZE>>1);o_i = o_i + 1) begin
        assign o_byte_vs1[o_i] = vs1_[(o_i+1)*8-1 -: 8];
        assign o_byte_vs2[o_i] = vs2_[(o_i+1)*8-1 -: 8];
        assign o_byte_vs3[o_i] = vs3_[(o_i+1)*8-1 -: 8];
    end
    endgenerate
    
    wire is_move         = (opcode == `VECTOR_MOVE1)||(opcode == `VECTOR_MOVE2)||(opcode == `VECTOR_MOVE4)||(opcode == `VECTOR_MOVE8);
    wire dispatch_needed = !(vec_operand_type == `NOT_VEC_ARITH||is_move)&&length > 0;
    // Dispatcher
    always @(posedge clk) begin
        case (working_status)
            `VEC_ALU_NOP:begin
                if (execute) begin
                    if (dispatch_needed) begin
                        previous_vsew     <= VSEW;
                        masked            <= vm;
                        vector_length     <= length;
                        vs1_              <= vs1;
                        vs2_              <= vs2;
                        vs3_              <= vs3;
                        mask_             <= mask;
                        imm_              <= imm;
                        rs_               <= rs;
                        task_type         <= alu_signal;
                        operand_type      <= vec_operand_type;
                        alu_opcode        <= opcode;
                        is_mask_operation <= is_mask_op;
                        current_vsew      <= vsew;
                        working_status    <= `VEC_ALU_WORKING;
                    end
                    else if (is_move) begin
                        case (opcode)
                            `VECTOR_MOVE1: begin
                                alu_result <= vs2;
                            end
                        endcase
                        next           <= 0;
                        working_status <= `VEC_ALU_FINISHED;
                    end
                    else begin
                        next           <= 0;
                        working_status <= `VEC_ALU_FINISHED;
                    end
                end
            end
            `VEC_ALU_WORKING:begin
                for (integer j = 0;j < LANE_SIZE;j = j + 1) begin
                    if (!(next + j > vector_length)) begin
                        // mask operation result
                        if (is_mask_operation)begin
                            alu_result[(next+j+1)-1 -: 1] <= out_signals[j][0:0];
                        end
                        else begin
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
                next           <= 0;
                working_status <= `VEC_ALU_NOP;
            end
            default:
            $display("[ERROR]:unexpected working status in vector function unit\n");
        endcase
    end
    
    // Lanes
    reg [LONGEST_LEN-1:0] in_vs1        [LANE_SIZE-1:0];
    reg [LONGEST_LEN-1:0] in_vs2        [LANE_SIZE-1:0];
    reg [LONGEST_LEN-1:0] in_vs3        [LANE_SIZE-1:0];
    wire [LONGEST_LEN-1:0] out_signals  [LANE_SIZE-1:0];
    
    always @(*) begin
        case (previous_vsew)
            `ONE_BYTE:begin
                for (integer k = 0;k < LANE_SIZE;k = k + 1) begin
                    in_vs1[k] = {56'b0,o_byte_vs1[next+k]};
                    in_vs2[k] = {56'b0,o_byte_vs2[next+k]};
                    in_vs3[k] = {56'b0,o_byte_vs3[next+k]};
                end
            end
            `TWO_BYTE:begin
                for (integer k = 0;k < LANE_SIZE;k = k + 1) begin
                    in_vs1[k] = {48'b0,t_byte_vs1[next+k]};
                    in_vs2[k] = {48'b0,t_byte_vs2[next+k]};
                    in_vs3[k] = {48'b0,t_byte_vs3[next+k]};
                end
            end
            `FOUR_BYTE:begin
                for (integer k = 0;k < LANE_SIZE;k = k + 1) begin
                    in_vs1[k] = {32'b0,f_byte_vs1[next+k]};
                    in_vs2[k] = {32'b0,f_byte_vs2[next+k]};
                    in_vs3[k] = {32'b0,f_byte_vs3[next+k]};
                end
            end
            `EIGHT_BYTE:begin
                for (integer k = 0;k < LANE_SIZE;k = k + 1) begin
                    in_vs1[k] = e_byte_vs1[next+k];
                    in_vs2[k] = e_byte_vs2[next+k];
                    in_vs3[k] = e_byte_vs3[next+k];
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
    .vs3                (in_vs3[i]),
    .mask               (mask_[next+i]),
    .imm                (imm_),
    .rs                 (rs_),
    .alu_signal         (task_type),
    .vec_operand_type   (operand_type),
    .is_mask_operation  (is_mask_operation),
    .opcode             (alu_opcode),
    .result             (out_signals[i])
    );
    end
    endgenerate
    
    // Recaller
    assign is_mask           = is_mask_operation;
    assign result            = alu_result;
    assign vector_alu_status = working_status;
    
endmodule
