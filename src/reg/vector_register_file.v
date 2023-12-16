// #############################################################################################################################
// VECTOR REGISTER FILE
// 
// 32个向量寄存器，每个向量vector_size个4byte整数
// 
// 访问场景：
// - instruction decode阶段读取数据（输出完整向量，即使部分invalid）
// - write back阶段向rd写（仅写length个，其余不变）
// - v0 also used as mask register
// #############################################################################################################################
`include"src/defines.v"

module VECTOR_REGISTER_FILE#(parameter ADDR_WIDTH = 17,
                             parameter LEN = 32,
                             parameter BYTE_SIZE = 8,
                             parameter VECTOR_SIZE = 8,
                             parameter ENTRY_INDEX_SIZE = 3)
                            (input wire clk,                        // clock
                             input rst,
                             input rdy_in,
                             input [1:0] rf_signal,                 // nop、读、写
                             input wire [4:0] rs1,                  // index of rs1
                             input wire [4:0] rs2,                  // index of rs2
                             input wire [4:0] rd,                   // index of rd
                             input [VECTOR_SIZE*LEN-1:0] data,      // write back data
                             input [ENTRY_INDEX_SIZE-1:0] length,
                             input write_back_enabled,
                             output [VECTOR_SIZE*LEN-1:0] rs1_data,
                             output [VECTOR_SIZE*LEN-1:0] rs2_data,
                             output [1:0] rf_status);
    // 32 registers
    reg [4:0]                   rs1_index;
    reg [4:0]                   rs2_index;
    reg [VECTOR_SIZE*LEN-1:0]   register[31:0];
    
    reg [1:0]                   status;
    assign rf_status = status;
    
    assign rs1_data = register[rs1_index];
    assign rs2_data = register[rs2_index];
    
    reg [VECTOR_SIZE*LEN-1:0] writen_data;
    
    
    always @(posedge clk) begin
        if ((!rst)&&rdy_in)begin
            // 读
            rs1_index = rs1;
            rs2_index = rs2;
            // 写
            if (write_back_enabled)begin
                if (rf_signal == `VECTOR_RF_WRITE) begin
                    for (integer i = 0;i < length;i = i + 1) begin
                        register[rd][i*LEN +: LEN] <= data[i*LEN +: LEN]; // 更新length个
                    end
                end
                status <= `RF_FINISHED;
            end
            else begin
                status <= `RF_NOP;
            end
        end
    end
    
endmodule
