// #############################################################################################################################
// CORE
// 
// vector processor core
// pipeline
// 
// - 组成部分
// | + Register
// |     PC
// |     scalar registers file, vector register file, 7 unprivileged CSRs
// |
// | + Storage
// |     main memory
// |     instruction cache, data cache
// |
// | + Function Unit
// |     alu
// #############################################################################################################################
`include"src/defines.v"
`include"src/decoder.v"
`include"src/funct_unit/scalar_alu.v"
`include"src/funct_unit/vector_function_unit.v"
`include"src/reg/scalar_register_file.v"
`include"src/reg/vector_register_file.v"


module CORE#(parameter ADDR_WIDTH = 17,
             parameter LEN = 32,
             parameter BYTE_SIZE = 8,
             parameter VECTOR_SIZE = 8,
             parameter ENTRY_INDEX_SIZE = 3,
             parameter LONGEST_LEN = 64)
            (input clk,
             input rst,
             input rdy_in,
             input [LEN-1:0] instruction,
             input [LEN-1:0] mem_read_scalar_data,
             input [LEN*VECTOR_SIZE-1:0] mem_read_vector_data,
             input [1:0] mem_vis_status,
             output [LEN-1:0] mem_write_scalar_data,
             output [LEN*VECTOR_SIZE-1:0] mem_write_vector_data,
             output [ENTRY_INDEX_SIZE:0] vector_length,
             output [ADDR_WIDTH-1:0] mem_inst_addr,
             output [ADDR_WIDTH-1:0] mem_data_addr,
             output inst_fetch_enabled,
             output mem_vis_enabled,
             output [1:0] memory_vis_signal,
             output [2:0] data_type);
    
    // REGISTER
    // ---------------------------------------------------------------------------------------------
    // Program Counter
    reg [LEN-1:0]   PC;
    
    // Control and Status Register
    
    // vl:vector length
    reg [31:0] VL;
    
    // vlenb:`VLEN`/8 (vector register length in bytes), read only
    reg [31:0] VLENB = LEN*VECTOR_SIZE/BYTE_SIZE;
    
    // vtype:vector data type register
    reg [31:0] VTYPE;
    // vsew[2:0]:Selected element width (SEW) setting
    wire [2:0] VSEW = VTYPE[5:3];
    // vlmul[2:0].:vector register group multiplier (LMUL) setting
    wire [2:0] VLMUL = VTYPE[2:0];
    
    // Transfer Register
    
    // if-id
    reg [LEN-1:0]               IF_ID_PC;
    
    // id-exe
    reg [LEN-1:0]               ID_EXE_PC;
    
    reg [LEN-1:0]               ID_EXE_RS1;              // 从register file读取到的rs1数据
    reg [LEN-1:0]               ID_EXE_RS2;              // 从register file读取到的rs2数据
    reg [VECTOR_SIZE*LEN - 1:0] ID_EXE_MASK;
    reg [VECTOR_SIZE*LEN - 1:0] ID_EXE_VS1;
    reg [VECTOR_SIZE*LEN - 1:0] ID_EXE_VS2;
    reg [VECTOR_SIZE*LEN - 1:0] ID_EXE_VS3;
    
    reg                         ID_EXE_VM;
    reg [31:0]                  ID_EXE_VL;
    reg [31:0]                  ID_EXE_VTYPE;
    wire [2:0]                  ID_EXE_VSEW  = ID_EXE_VTYPE[5:3];
    wire [2:0]                  ID_EXE_VLMUL = ID_EXE_VTYPE[2:0];
    
    reg [LEN-1:0]               ID_EXE_IMM;              // immediate generator提取的imm
    reg [4:0]                   ID_EXE_RD_INDEX;         // 记录的rd位置
    reg [3:0]                   ID_EXE_FUNC_CODE;        // scalar func部分
    reg [1:0]                   ID_EXE_VEC_OPERAND_TYPE;
    reg [4:0]                   ID_EXE_EXT_TYPE;
    reg [5:0]                   ID_EXE_FUNCT6;
    
    reg [2:0]                   ID_EXE_ALU_SIGNAL;        // ALU信号
    reg [1:0]                   ID_EXE_MEM_VIS_SIGNAL;    // 访存信号
    reg [1:0]                   ID_EXE_MEM_VIS_DATA_SIZE; // todo:scalar?
    reg [1:0]                   ID_EXE_BRANCH_SIGNAL;
    reg [1:0]                   ID_EXE_WB_SIGNAL;
    
    // exe-mem
    reg [LEN-1:0]               EXE_MEM_PC;
    
    reg [LEN-1:0]               EXE_MEM_SCALAR_RESULT;       // scalar计算结果
    reg [VECTOR_SIZE*LEN - 1:0] EXE_MEM_VECTOR_RESULT;       // vector计算结果
    reg [VECTOR_SIZE*LEN - 1:0] EXE_MEM_MASK;
    reg [1:0]                   EXE_MEM_ZERO_BITS;           // condition
    reg [LEN-1:0]               EXE_MEM_RS2;                 // 可能用于写的数据
    
    reg                         EXE_MEM_VM;
    reg [31:0]                  EXE_MEM_VL;
    reg [31:0]                  EXE_MEM_VTYPE;
    wire [2:0]                  EXE_MEM_VSEW  = EXE_MEM_VTYPE[5:3];
    wire [2:0]                  EXE_MEM_VLMUL = EXE_MEM_VTYPE[2:0];
    
    reg [LEN-1:0]               EXE_MEM_IMM;
    reg [4:0]                   EXE_MEM_RD_INDEX;           // 记录的rd位置
    reg [3:0]                   EXE_MEM_FUNC_CODE;
    
    reg                         EXE_MEM_OP_ON_MASK;            // 是对mask的操作
    reg [1:0]                   EXE_MEM_MEM_VIS_SIGNAL;
    reg [1:0]                   EXE_MEM_MEM_VIS_DATA_SIZE;
    reg [1:0]                   EXE_MEM_BRANCH_SIGNAL;
    reg [1:0]                   EXE_MEM_WB_SIGNAL;
    
    // mem-wb
    reg [LEN-1:0]               MEM_WB_PC;
    
    reg [LEN-1:0]               MEM_WB_MEM_SCALAR_DATA;     // 从内存读取的scalar数据
    reg [VECTOR_SIZE*LEN - 1:0] MEM_WB_MEM_VECTOR_DATA;     // 从内存读取的vector数据
    reg [LEN-1:0]               MEM_WB_SCALAR_RESULT;       // scalar计算结果
    reg [VECTOR_SIZE*LEN - 1:0] MEM_WB_VECTOR_RESULT;       // vector计算结果
    
    reg                         EXE_WB_VM;
    reg [31:0]                  MEM_WB_VL;
    reg [31:0]                  MEM_WB_VTYPE;
    wire [2:0]                  MEM_WB_VSEW  = MEM_WB_VTYPE[5:3];
    wire [2:0]                  MEM_WB_VLMUL = MEM_WB_VTYPE[2:0];
    
    reg [4:0]                   MEM_WB_RD_INDEX;
    
    reg                         MEM_WB_OP_ON_MASK;            // 是对mask的操作
    reg [1:0]                   MEM_WB_WB_SIGNAL;
    
    
    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    // PIPELINE
    
    // STATE CONTROLER
    // 
    // stall or not
    // 可能因为访存等原因stall
    
    reg         IF_STATE_CTR  = 0;
    reg         ID_STATE_CTR  = 0;
    reg         EXE_STATE_CTR = 0;
    reg         MEM_STATE_CTR = 0;
    reg         WB_STATE_CTR  = 0;
    
    // DECODER
    // outports wire
    wire           	decoder_is_vector_instruction;
    wire [4:0]     	decoder_reg1_index;
    wire [4:0]     	decoder_reg2_index;
    wire [4:0]     	decoder_reg3_index;
    wire           	decoder_vm;
    wire [10:0]    	decoder_zimm;
    wire [3:0]     	decoder_output_func_code;
    wire [5:0]     	decoder_output_func6;
    wire [LEN-1:0] 	decoder_output_immediate;
    wire [2:0]     	decoder_output_exe_signal;
    wire [1:0]     	decoder_output_vec_operand_type;
    wire [1:0]     	decoder_output_mem_vis_signal;
    wire [1:0]     	decoder_output_data_size;
    wire [1:0]     	decoder_output_vector_l_s_type;
    wire [1:0]     	decoder_output_branch_signal;
    wire [1:0]     	decoder_output_wb_signal;
    
    DECODER #(
    .ADDR_WIDTH       	(ADDR_WIDTH),
    .LEN              	(LEN),
    .BYTE_SIZE        	(BYTE_SIZE),
    .VECTOR_SIZE      	(VECTOR_SIZE),
    .ENTRY_INDEX_SIZE 	(ENTRY_INDEX_SIZE)
    )
    decoder(
    .chip_enabled            	(chip_enabled),
    .instruction             	(instruction),
    .is_vector_instruction   	(decoder_is_vector_instruction),
    .reg1_index              	(decoder_reg1_index),
    .reg2_index              	(decoder_reg2_index),
    .reg3_index              	(decoder_reg3_index),
    .vm                      	(decoder_vm),
    .zimm                    	(decoder_zimm),
    .output_func_code        	(decoder_output_func_code),
    .output_func6            	(decoder_output_func6),
    .output_immediate        	(decoder_output_immediate),
    .output_exe_signal       	(decoder_output_exe_signal),
    .output_vec_operand_type 	(decoder_output_vec_operand_type),
    .output_mem_vis_signal   	(decoder_output_mem_vis_signal),
    .output_data_size        	(decoder_output_data_size),
    .output_vector_l_s_type  	(decoder_output_vector_l_s_type),
    .output_branch_signal    	(decoder_output_branch_signal),
    .output_wb_signal        	(decoder_output_wb_signal)
    );
    
    // SCALAR REGISTER FILE
    // inports wire
    wire [1:0]              scalar_rf_rf_signal;
    reg [LEN-1:0]           scalar_rf_reg_write_data;
    wire                    scalar_rf_write_back_enabled;
    
    // outports wire
    wire [LEN-1:0] 	        scalar_rf_rs1_data;
    wire [LEN-1:0] 	        scalar_rf_rs2_data;
    wire [1:0]     	        scalar_rf_rf_status;
    
    SCALAR_REGISTER_FILE #(
    .ADDR_WIDTH       	(ADDR_WIDTH),
    .LEN              	(LEN),
    .BYTE_SIZE        	(BYTE_SIZE),
    .VECTOR_SIZE      	(VECTOR_SIZE),
    .ENTRY_INDEX_SIZE 	(ENTRY_INDEX_SIZE)
    )
    scalar_register_file(
    .clk                	(clk),
    .rst                	(rst),
    .rdy_in             	(rdy_in),
    .rf_signal          	(scalar_rf_rf_signal),
    .rs1                	(decoder_reg1_index),
    .rs2                	(decoder_reg2_index),
    .rd                 	(MEM_WB_RD_INDEX),
    .data               	(scalar_rf_reg_write_data),
    .write_back_enabled 	(scalar_rf_write_back_enabled),
    .rs1_data           	(scalar_rf_rs1_data),
    .rs2_data           	(scalar_rf_rs2_data),
    .rf_status          	(scalar_rf_rf_status)
    );
    
    // VECTOR REGISTER FILE
    // inports wire
    wire [1:0]                  vector_rf_rf_signal;
    wire [VECTOR_SIZE*LEN-1:0] 	vector_rf_mask;         // mask bits in v0
    reg [VECTOR_SIZE*LEN-1:0]   vector_rf_reg_write_data;
    wire                        vector_rf_write_back_enabled;
    
    // outports wire
    wire [VECTOR_SIZE*LEN-1:0] 	vector_rf_v0_data;
    wire [VECTOR_SIZE*LEN-1:0] 	vector_rf_rs1_data;
    wire [VECTOR_SIZE*LEN-1:0] 	vector_rf_rs2_data;
    wire [VECTOR_SIZE*LEN-1:0] 	vector_rf_rs3_data;
    wire [1:0]                 	vector_rf_rf_status;
    
    VECTOR_REGISTER_FILE#(
    .ADDR_WIDTH       	(ADDR_WIDTH),
    .LEN              	(LEN),
    .BYTE_SIZE        	(BYTE_SIZE),
    .VECTOR_SIZE      	(VECTOR_SIZE),
    .ENTRY_INDEX_SIZE 	(ENTRY_INDEX_SIZE)
    )
    vector_register_file(
    .clk                	(clk),
    .rst                	(rst),
    .rdy_in             	(rdy_in),
    .rf_signal          	(vector_rf_rf_signal),
    .rs1                	(decoder_reg1_index),
    .rs2                	(decoder_reg2_index),
    .rs3                	(decoder_reg3_index),
    .rd                 	(MEM_WB_RD_INDEX),
    .vm                 	(MEM_WB_VM),
    .mask               	(vector_rf_mask),
    .data               	(vector_rf_reg_write_data),
    .length             	(MEM_WB_VL),
    .data_type          	(MEM_WB_VSEW),
    .write_back_enabled 	(vector_rf_write_back_enabled),
    .v0_data            	(vector_rf_v0_data),
    .rs1_data           	(vector_rf_rs1_data),
    .rs2_data           	(vector_rf_rs2_data),
    .rs3_data           	(vector_rf_rs3_data),
    .rf_status          	(vector_rf_rf_status)
    );
    
    // SCALAR ALU
    // outports wire
    wire [LEN-1:0] 	scalar_alu_result;
    wire [1:0]     	scalar_alu_sign_bits;
    
    SCALAR_ALU #(
    .ADDR_WIDTH       	(ADDR_WIDTH),
    .LEN              	(LEN),
    .BYTE_SIZE        	(BYTE_SIZE),
    .VECTOR_SIZE      	(VECTOR_SIZE),
    .ENTRY_INDEX_SIZE 	(ENTRY_INDEX_SIZE)
    )
    scalar_alu(
    .rs1        	(ID_EXE_RS1),
    .rs2        	(ID_EXE_RS2),
    .imm        	(ID_EXE_IMM),
    .pc         	(ID_EXE_PC),
    .alu_signal 	(ID_EXE_ALU_SIGNAL),
    .func_code  	(ID_EXE_FUNC_CODE),
    .result     	(scalar_alu_result),
    .sign_bits  	(scalar_alu_sign_bits)
    );
    
    // VECTOR FUNCTION UNIT
    localparam LANE_SIZE       = 2;
    localparam LANE_INDEX_SIZE = 1;
    // inports wire
    wire                        vector_function_unit_execute;
    // outports wire
    wire                       	vector_function_unit_is_mask;
    wire [VECTOR_SIZE*LEN-1:0] 	vector_function_unit_result;
    wire [1:0]                 	vector_function_unit_vector_alu_status;
    
    VECTOR_FUNCTION_UNIT #(
    .ADDR_WIDTH       	(ADDR_WIDTH),
    .LEN              	(LEN),
    .LONGEST_LEN      	(LONGEST_LEN),
    .BYTE_SIZE        	(BYTE_SIZE),
    .VECTOR_SIZE      	(VECTOR_SIZE),
    .ENTRY_INDEX_SIZE 	(ENTRY_INDEX_SIZE),
    .LANE_SIZE        	(LANE_SIZE),
    .LANE_INDEX_SIZE  	(LANE_INDEX_SIZE)
    )
    vector_function_unit(
    .clk               	(clk),
    .rst               	(rst),
    .rdy_in            	(rdy_in),
    .execute           	(vector_function_unit_execute), // 是否要求vector function unit做运算
    .VSEW              	(ID_EXE_VSEW),
    .vm                	(ID_EXE_VM),
    .length            	(ID_EXE_VL),
    .vs1               	(ID_EXE_VS1),
    .vs2               	(ID_EXE_VS2),
    .vs3               	(ID_EXE_VS3),
    .mask              	(ID_EXE_MASK),
    .imm               	(ID_EXE_IMM),
    .rs                	(ID_EXE_RS1),       // 标量操作数rs1
    .alu_signal        	(ID_EXE_ALU_SIGNAL),
    .vec_operand_type  	(ID_EXE_VEC_OPERAND_TYPE),
    .ext_type          	(ID_EXE_EXT_TYPE),
    .funct6            	(ID_EXE_FUNCT6),
    .is_mask           	(vector_function_unit_is_mask),
    .result            	(vector_function_unit_result),
    .vector_alu_status 	(vector_function_unit_vector_alu_status)
    );
    
    // rst为1，整体开始工作
    // -------------------------------------------------------------------------------
    reg chip_enabled;
    reg start_cpu = 0;
    
    always @ (posedge clk) begin
        if (rst == 0) begin
            if (!start_cpu) begin
                IF_STATE_CTR <= 1;
                start_cpu    <= 1;
            end
            chip_enabled <= 1;
        end
        else
            chip_enabled <= 0;
    end
    
endmodule
