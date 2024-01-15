// #############################################################################################################################
// VECTOR REGISTER FILE
// 
// 32个向量寄存器，每个向量vector_size个整数
// 数据类型不同，位宽不同。紧密排列
// 
// 访问场景：
// - instruction decode阶段读取数据（输出完整向量，即使部分invalid）
// - write back阶段向rd写（仅写length个，其余不变）
// - v0 also used as mask register
// 
// #############################################################################################################################
`include"src/defines.v"

module VECTOR_REGISTER_FILE#(parameter ADDR_WIDTH = 17,
                             parameter DATA_LEN = 32,                      // 内存数据单元
                             parameter SCALAR_REG_LEN = 64,                // 标量寄存器
                             parameter BYTE_SIZE = 8,
                             parameter VECTOR_SIZE = 8,
                             parameter ENTRY_INDEX_SIZE = 3)
                            (input wire clk,                               // clock
                             input rst,
                             input rdy_in,
                             input [1:0] rf_signal,                        // nop、读、写
                             input wire [4:0] rs1,                         // index of rs1
                             input wire [4:0] rs2,                         // index of rs2
                             input wire [4:0] rs3,                         // index of rs3(rd)
                             input wire [4:0] rd,                          // index of rd
                             input vm,
                             input [VECTOR_SIZE*DATA_LEN - 1:0] mask,
                             input [VECTOR_SIZE*DATA_LEN - 1:0] data,      // write back data
                             input [DATA_LEN-1:0] length,
                             input [2:0] data_type,
                             input write_back_enabled,
                             output [VECTOR_SIZE*DATA_LEN - 1:0] v0_data,
                             output [VECTOR_SIZE*DATA_LEN - 1:0] rs1_data,
                             output [VECTOR_SIZE*DATA_LEN - 1:0] rs2_data,
                             output [VECTOR_SIZE*DATA_LEN - 1:0] rs3_data,
                             output [1:0] rf_status);
    // 32 registers
    reg [4:0]                   rs1_index;
    reg [4:0]                   rs2_index;
    reg [4:0]                   rs3_index;
    reg [VECTOR_SIZE*DATA_LEN-1:0]   register[31:0];
    
    reg [1:0]                   status;
    assign rf_status = status;
    
    assign v0_data  = register[0];
    assign rs1_data = register[rs1_index];
    assign rs2_data = register[rs2_index];
    assign rs3_data = register[rs3_index];
    
    reg [VECTOR_SIZE*DATA_LEN-1:0] writen_data;
    
    
    always @(posedge clk) begin
        if ((!rst)&&rdy_in)begin
            // 读
            rs1_index = rs1;
            rs2_index = rs2;
            rs3_index = rs3;
            // 写
            if (write_back_enabled)begin
                if (rf_signal == `VECTOR_RF_WRITE) begin
                    case (data_type)
                        `ONE_BYTE: begin
                            for (integer i = 0;i < length;i = i + 1) begin
                                if (mask[i]||vm) begin
                                    register[rd][(i+1)*8-1 -: 8] <= data[(i+1)*8-1 -: 8];
                                end
                            end
                        end
                        `TWO_BYTE:begin
                            for (integer i = 0;i < length;i = i + 1) begin
                                if (mask[i]||vm) begin
                                    register[rd][(i+1)*16-1 -: 16] <= data[(i+1)*16-1 -: 16];
                                end
                            end
                        end
                        `FOUR_BYTE:begin
                            for (integer i = 0;i < length;i = i + 1) begin
                                if (mask[i]||vm) begin
                                    register[rd][(i+1)*32-1 -: 32] <= data[(i+1)*32-1 -: 32];
                                end
                            end
                        end
                        `EIGHT_BYTE:begin
                            for (integer i = 0;i < length;i = i + 1) begin
                                if (mask[i]||vm) begin
                                    register[rd][(i+1)*64-1 -: 64] <= data[(i+1)*64-1 -: 64];
                                end
                            end
                        end
                        default:
                        $display("[ERROR]:unexpected data type in vector rf\n");
                    endcase
                end
                status <= `RF_FINISHED;
            end
            else begin
                status <= `RF_NOP;
            end
        end
    end
    
endmodule
