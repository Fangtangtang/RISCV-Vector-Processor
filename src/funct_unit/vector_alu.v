// #############################################################################################################################
// VECTOR ALU
// 
// 向量计算时每个lane中一个
// 
// - 操作数形式
// | + vd[i] = vs2[i] op vs1[i]
// 
// - 输入输出向量数据为64位，根据vsew截取需要的位
// - imm和rs和标量公用，32位再符号位拓展或者截断
// - mask按序排列 1bit
// #############################################################################################################################
`include"src/defines.v"

module VECTOR_ALU#(parameter ADDR_WIDTH = 17,
                   parameter DATA_LEN = 32,                // 内存数据单元
                   parameter SCALAR_REG_LEN = 64,          // 标量寄存器
                   parameter LONGEST_LEN = 64,             // 标量寄存器
                   parameter BYTE_SIZE = 8,
                   parameter VECTOR_SIZE = 8,
                   parameter ENTRY_INDEX_SIZE = 3,
                   parameter LANE_INDEX_SIZE = 1)
                  (input [2:0] PREV_VSEW,
                   input [2:0] CUR_VSEW,
                   input vm,
                   input [LONGEST_LEN - 1:0] vs1,
                   input [LONGEST_LEN - 1:0] vs2,
                   input [LONGEST_LEN - 1:0] vs3,
                   input mask,
                   input [SCALAR_REG_LEN - 1:0] imm,       // 立即数，符号位拓展
                   input [SCALAR_REG_LEN - 1:0] rs,        // 标量操作数，符号位拓展
                   input [3:0] alu_signal,
                   input [1:0] vec_operand_type,
                   input is_mask_operation,
                   input [5:0] opcode,
                   output reg [LONGEST_LEN - 1:0] result);
    
    wire [63:0] e_byte_vs1;
    wire [63:0] e_byte_vs2;
    wire [63:0] e_byte_vs3;
    wire [63:0] e_byte_imm;
    wire [63:0] e_byte_rs;
    assign e_byte_vs1 = vs1;
    assign e_byte_vs2 = vs2;
    assign e_byte_vs3 = vs3;
    assign e_byte_imm = imm;
    assign e_byte_rs  = rs;
    
    wire [31:0] f_byte_vs1;
    wire [31:0] f_byte_vs2;
    wire [31:0] f_byte_vs3;
    wire [31:0] f_byte_imm;
    wire [31:0] f_byte_rs;
    assign f_byte_vs1 = vs1[31:0];
    assign f_byte_vs2 = vs2[31:0];
    assign f_byte_vs3 = vs3[31:0];
    assign f_byte_imm = imm[31:0];
    assign f_byte_rs  = rs[31:0];
    
    wire [15:0] t_byte_vs1;
    wire [15:0] t_byte_vs2;
    wire [15:0] t_byte_vs3;
    wire [15:0] t_byte_imm;
    wire [15:0] t_byte_rs;
    assign t_byte_vs1 = vs1[15:0];
    assign t_byte_vs2 = vs2[15:0];
    assign t_byte_vs3 = vs3[15:0];
    assign t_byte_imm = imm[15:0];
    assign t_byte_rs  = rs[15:0];
    
    wire [7:0] o_byte_vs1;
    wire [7:0] o_byte_vs2;
    wire [7:0] o_byte_vs3;
    wire [7:0] o_byte_imm;
    wire [7:0] o_byte_rs;
    assign o_byte_vs1 = vs1[7:0];
    assign o_byte_vs2 = vs2[7:0];
    assign o_byte_vs3 = vs3[7:0];
    assign o_byte_imm = imm[7:0];
    assign o_byte_rs  = rs[7:0];
    
    reg [63:0] e_alu_result;
    reg [31:0] f_alu_result;
    reg [15:0] t_alu_result;
    reg [7:0] o_alu_result;
    
    always @(*) begin
        case (opcode)
            `VECTOR_ADD:begin
                if (mask||vm) begin
                    e_alu_result = e_byte_vs1 + e_byte_vs2;
                    f_alu_result = f_byte_vs1 + f_byte_vs2;
                    t_alu_result = t_byte_vs1 + t_byte_vs2;
                    o_alu_result = o_byte_vs1 + o_byte_vs2;
                end
                else begin
                    e_alu_result = 0;
                    f_alu_result = 0;
                    t_alu_result = 0;
                    o_alu_result = 0;
                end
            end
            `VECTOR_SUB:begin
                if (mask||vm) begin
                    e_alu_result = e_byte_vs2 - e_byte_vs1;
                    f_alu_result = f_byte_vs2 - f_byte_vs1;
                    t_alu_result = t_byte_vs2 - t_byte_vs1;
                    o_alu_result = o_byte_vs2 - o_byte_vs1;
                end
                else begin
                    e_alu_result = 0;
                    f_alu_result = 0;
                    t_alu_result = 0;
                    o_alu_result = 0;
                end
            end
            `VECTOR_WADDU:begin
                // 2*SEW = SEW + SEW
                if (mask||vm) begin
                    e_alu_result = {32'b0,f_byte_vs1} + {32'b0,f_byte_vs2};
                    f_alu_result = {16'b0,t_byte_vs1} + {16'b0,t_byte_vs2};
                    t_alu_result = {8'b0,o_byte_vs1} + {8'b0,o_byte_vs2};
                    o_alu_result = 0;
                end
                else begin
                    e_alu_result = 0;
                    f_alu_result = 0;
                    t_alu_result = 0;
                    o_alu_result = 0;
                end
            end
            `VECTOR_WSUBU:begin
                // 2*SEW = SEW + SEW
                if (mask||vm) begin
                    e_alu_result = {32'b0,f_byte_vs2} - {32'b0,f_byte_vs1};
                    f_alu_result = {16'b0,t_byte_vs2} - {16'b0,t_byte_vs1};
                    t_alu_result = {8'b0,o_byte_vs2} - {8'b0,o_byte_vs1};
                    o_alu_result = 0;
                end
                else begin
                    e_alu_result = 0;
                    f_alu_result = 0;
                    t_alu_result = 0;
                    o_alu_result = 0;
                end
            end
            `VECTOR_WADD:begin
                // 2*SEW = SEW + SEW
                if (mask||vm) begin
                    e_alu_result = {{32{f_byte_vs1[31]}},f_byte_vs1} + {{32{f_byte_vs2[31]}},f_byte_vs2};
                    f_alu_result = {{16{t_byte_vs1[15]}},t_byte_vs1} + {{16{t_byte_vs2[15]}},t_byte_vs2};
                    t_alu_result = {{8{o_byte_vs1[7]}},o_byte_vs1} + {{8{o_byte_vs2[7]}},o_byte_vs2};
                    o_alu_result = 0;
                end
                else begin
                    e_alu_result = 0;
                    f_alu_result = 0;
                    t_alu_result = 0;
                    o_alu_result = 0;
                end
            end
            `VECTOR_WSUB:begin
                // 2*SEW = SEW + SEW
                if (mask||vm) begin
                    e_alu_result = {{32{f_byte_vs1[31]}},f_byte_vs2} - {{32{f_byte_vs2[31]}},f_byte_vs1};
                    f_alu_result = {{16{t_byte_vs1[15]}},t_byte_vs2} - {{16{t_byte_vs2[15]}},t_byte_vs1};
                    t_alu_result = {{8{o_byte_vs1[7]}},o_byte_vs2} - {{8{o_byte_vs2[7]}},o_byte_vs1};
                    o_alu_result = 0;
                end
                else begin
                    e_alu_result = 0;
                    f_alu_result = 0;
                    t_alu_result = 0;
                    o_alu_result = 0;
                end
            end
            `VECTOR_ADC:begin
                // Add-with-Carry
                // vd[i] = vs2[i] + vs1[i] + v0.mask[i]
                if (mask||vm)begin
                    e_alu_result = e_byte_vs1 + e_byte_vs2 + mask;
                    f_alu_result = f_byte_vs1 + f_byte_vs2 + mask;
                    t_alu_result = t_byte_vs1 + t_byte_vs2 + mask;
                    o_alu_result = o_byte_vs1 + o_byte_vs2 + mask;
                end
                else begin
                    e_alu_result = e_byte_vs1 + e_byte_vs2;
                    f_alu_result = f_byte_vs1 + f_byte_vs2;
                    t_alu_result = t_byte_vs1 + t_byte_vs2;
                    o_alu_result = o_byte_vs1 + o_byte_vs2;
                end
            end
            `VECTOR_SBC:begin
                // Subtract-with-Borrow
                // vd[i] = vs2[i] - vs1[i] - v0.mask[i]
                if (mask||vm)begin
                    e_alu_result = e_byte_vs2 - e_byte_vs1 - mask;
                    f_alu_result = f_byte_vs2 - f_byte_vs1 - mask;
                    t_alu_result = t_byte_vs2 - t_byte_vs1 - mask;
                    o_alu_result = o_byte_vs2 - o_byte_vs1 - mask;
                end
                else begin
                    e_alu_result = e_byte_vs2 - e_byte_vs1;
                    f_alu_result = f_byte_vs2 - f_byte_vs1;
                    t_alu_result = t_byte_vs2 - t_byte_vs1;
                    o_alu_result = o_byte_vs2 - o_byte_vs1;
                end
            end
            `VECTOR_MADC:begin
                if (mask||vm)begin
                    e_alu_result = !((e_byte_vs2 + e_byte_vs1)<65'b10000000000000000000000000000000000000000000000000000000000000000);
                    f_alu_result = !((f_byte_vs2 + f_byte_vs1)<33'b100000000000000000000000000000000);
                    t_alu_result = !((t_byte_vs2 + t_byte_vs1)<17'b10000000000000000);
                    o_alu_result = !((o_byte_vs2 + o_byte_vs1)<9'b100000000);
                end
                else begin
                    e_alu_result = 0;
                    f_alu_result = 0;
                    t_alu_result = 0;
                    o_alu_result = 0;
                end
            end
            `VECTOR_MSBC:begin
                if (mask||vm) begin
                    e_alu_result = !(e_byte_vs2 - e_byte_vs1<0);
                    f_alu_result = !(f_byte_vs2 - f_byte_vs1<0);
                    t_alu_result = !(t_byte_vs2 - t_byte_vs1<0);
                    o_alu_result = !(o_byte_vs2 - o_byte_vs1<0);
                end
                else begin
                    e_alu_result = 0;
                    f_alu_result = 0;
                    t_alu_result = 0;
                    o_alu_result = 0;
                end
            end
            `VECTOR_MACC:begin
                // vd[i] = +(vs1[i] * vs2[i]) + vd[i]
                if (mask||vm) begin
                    e_alu_result = e_byte_vs1 * e_byte_vs2 + e_byte_vs3;
                    f_alu_result = f_byte_vs1 * f_byte_vs2 + f_byte_vs3;
                    t_alu_result = t_byte_vs1 * t_byte_vs2 + t_byte_vs3;
                    o_alu_result = o_byte_vs1 * o_byte_vs2 + o_byte_vs3;
                end
                else begin
                    e_alu_result = 0;
                    f_alu_result = 0;
                    t_alu_result = 0;
                    o_alu_result = 0;
                end
            end
            `VECTOR_NMSAC:begin
                // vd[i] = -(vs1[i] * vs2[i]) + vd[i]
                if (mask||vm) begin
                    e_alu_result = e_byte_vs3 - e_byte_vs1 * e_byte_vs2;
                    f_alu_result = f_byte_vs3 - f_byte_vs1 * f_byte_vs2;
                    t_alu_result = t_byte_vs3 - t_byte_vs1 * t_byte_vs2;
                    o_alu_result = o_byte_vs3 - o_byte_vs1 * o_byte_vs2;
                end
                else begin
                    e_alu_result = 0;
                    f_alu_result = 0;
                    t_alu_result = 0;
                    o_alu_result = 0;
                end
            end
            `VECTOR_MADD:begin
                // vd[i] = (vs1[i] * vd[i]) + vs2[i]
                if (mask||vm) begin
                    e_alu_result = e_byte_vs3 * e_byte_vs1 + e_byte_vs2;
                    f_alu_result = f_byte_vs3 * f_byte_vs1 + f_byte_vs2;
                    t_alu_result = t_byte_vs3 * t_byte_vs1 + t_byte_vs2;
                    o_alu_result = o_byte_vs3 * o_byte_vs1 + o_byte_vs2;
                end
                else begin
                    e_alu_result = 0;
                    f_alu_result = 0;
                    t_alu_result = 0;
                    o_alu_result = 0;
                end
            end
            `VECTOR_ZEXT2:begin
                // Zero-extend SEW/2 source to SEW destination
                if (mask||vm) begin
                    e_alu_result = {32'b0,f_byte_vs2};
                    f_alu_result = {16'b0,t_byte_vs2};
                    t_alu_result = {8'b0,o_byte_vs2};
                    o_alu_result = 0;
                end
                else begin
                    e_alu_result = 0;
                    f_alu_result = 0;
                    t_alu_result = 0;
                    o_alu_result = 0;
                end
            end
            `VECTOR_SEXT2:begin
                // Sign-extend SEW/2 source to SEW destination
                if (mask||vm) begin
                    e_alu_result = {{32{f_byte_vs2[31]}},f_byte_vs2};
                    f_alu_result = {{16{t_byte_vs2[15]}},t_byte_vs2};
                    t_alu_result = {{8{o_byte_vs2[7]}},o_byte_vs2};
                    o_alu_result = 0;
                end
                else begin
                    e_alu_result = 0;
                    f_alu_result = 0;
                    t_alu_result = 0;
                    o_alu_result = 0;
                end
            end
            `VECTOR_ZEXT4:begin
                // Zero-extend SEW/4 source to SEW destination
                if (mask||vm) begin
                    e_alu_result = {48'b0,f_byte_vs2};
                    f_alu_result = {24'b0,t_byte_vs2};
                    t_alu_result = 0;
                    o_alu_result = 0;
                end
                else begin
                    e_alu_result = 0;
                    f_alu_result = 0;
                    t_alu_result = 0;
                    o_alu_result = 0;
                end
            end
            `VECTOR_SEXT4:begin
                // Sign-extend SEW/4 source to SEW destination
                if (mask||vm) begin
                    e_alu_result = {{48{f_byte_vs2[31]}},f_byte_vs2};
                    f_alu_result = {{24{t_byte_vs2[15]}},t_byte_vs2};
                    t_alu_result = 0;
                    o_alu_result = 0;
                end
                else begin
                    e_alu_result = 0;
                    f_alu_result = 0;
                    t_alu_result = 0;
                    o_alu_result = 0;
                end
            end
            `VECTOR_ZEXT8:begin
                // Zero-extend SEW/8 source to SEW destination
                if (mask||vm) begin
                    e_alu_result = {56'b0,f_byte_vs2};
                    f_alu_result = 0;
                    t_alu_result = 0;
                    o_alu_result = 0;
                end
                else begin
                    e_alu_result = 0;
                    f_alu_result = 0;
                    t_alu_result = 0;
                    o_alu_result = 0;
                end
            end
            `VECTOR_SEXT8:begin
                // Sign-extend SEW/8 source to SEW destination
                if (mask||vm) begin
                    e_alu_result = {{56{f_byte_vs2[31]}},f_byte_vs2};
                    f_alu_result = 0;
                    t_alu_result = 0;
                    o_alu_result = 0;
                end
                else begin
                    e_alu_result = 0;
                    f_alu_result = 0;
                    t_alu_result = 0;
                    o_alu_result = 0;
                end
            end
            default:
            $display("[ERROR]:unexpected opcode in vector alu\n");
        endcase
    end
    
    // 根据CUR_VSEW输出数据
    always @(*) begin
        if (is_mask_operation) begin
            result = {63'b0,o_alu_result[0:0]};
        end
        else begin
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
    end
endmodule
