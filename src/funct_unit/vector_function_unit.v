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
                             parameter LEN = 32,
                             parameter BYTE_SIZE = 8,
                             parameter VECTOR_SIZE = 8,
                             parameter ENTRY_INDEX_SIZE = 3,
                             parameter LANE_SIZE = 2,
                             parameter LANE_INDEX_SIZE = 1)
                            (input wire clk,                            // clock
                             input rst,
                             input rdy_in,
                             input execute,
                             input [ENTRY_INDEX_SIZE:0] length,
                             input [VECTOR_SIZE*LEN - 1:0] vs1,
                             input [VECTOR_SIZE*LEN - 1:0] vs2,
                             input [VECTOR_SIZE*LEN - 1:0] mask,
                             input [LEN - 1:0] imm,                     // 立即数
                             input [LEN - 1:0] rs,                      // 标量操作数
                             input [2:0] alu_signal,
                             input [1:0] vec_operand_type,
                             input [5:0] funct6,
                             output [VECTOR_SIZE*LEN - 1:0] result,
                             output [1:0] vector_alu_status);
    
    
    reg [ENTRY_INDEX_SIZE:0] vector_length; // 记录所需运算的向量长度
    reg [VECTOR_SIZE*LEN - 1:0] vs1_;
    reg [VECTOR_SIZE*LEN - 1:0] vs2_;
    reg [VECTOR_SIZE*LEN - 1:0] mask_;
    reg [LEN - 1:0] imm_;
    reg [LEN - 1:0] rs_;
    reg [2:0] task_type;
    reg [1:0] operand_type;
    reg [5:0] funct6_;
    reg [1:0] working_status;
    
    reg [ENTRY_INDEX_SIZE:0] next;          // 下一周期起始index
    
    reg [VECTOR_SIZE*LEN - 1:0] alu_result;
    
    // Dispatcher
    always @(posedge clk) begin
        case (working_status)
            `VEC_ALU_NOP:begin
                if (execute&&length > 0) begin
                    vector_length  <= length;
                    vs1_           <= vs1;
                    vs2_           <= vs2;
                    mask_          <= mask;
                    imm_           <= imm;
                    rs_            <= rs;
                    task_type      <= alu_signal;
                    operand_type   <= vec_operand_type;
                    funct6_        <= funct6;
                    working_status <= `VEC_ALU_WORKING;
                end
            end
            `VEC_ALU_WORKING:begin
                for (integer j = 0;j < LANE_SIZE;j = j + 1) begin
                    if (!(next + j > vector_length)) begin
                        alu_result[(next+j)*LEN +: LEN] <= out_signals[j];
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
                    vector_length  <= length;
                    vs1_           <= vs1;
                    vs2_           <= vs2;
                    mask_          <= mask;
                    imm_           <= imm;
                    rs_            <= rs;
                    task_type      <= alu_signal;
                    operand_type   <= vec_operand_type;
                    funct6_        <= funct6;
                    working_status <= `VEC_ALU_WORKING;
                    next           <= 0;
                end
                else begin
                    working_status <= `VEC_ALU_NOP;
                end
            end
            default:
            $display("[ERROR]:unexpected working status in vector alu\n");
        endcase
    end
    
    // Lanes
    wire [LEN-1:0] out_signals[LANE_SIZE-1:0];
    
    generate
    genvar i;
    for (i = 0; i < LANE_SIZE; i = i + 1) begin :instances
    VECTOR_ALU #(i) vector_alu (
    .vs1                (vs1_[(next+i)*LEN +: LEN]),
    .vs2                (vs2_[(next+i)*LEN +: LEN]),
    .mask               (mask_[(next+i)*LEN +: LEN]),
    .imm                (imm_),
    .rs                 (rs_),
    .alu_signal         (task_type),
    .vec_operand_type   (operand_type),
    .funct6             (funct6_),
    .result             (out_signals[i])
    );
    end
    endgenerate
    
    // Recaller
    assign result = alu_result;
    assign vector_alu_status = working_status;

endmodule
