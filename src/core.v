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
             input [1:0] i_cache_vis_status,
             input [1:0] d_cache_vis_status,
             output [LEN-1:0] mem_write_scalar_data,
             output vm,
             output [LEN*VECTOR_SIZE-1:0] mask,
             output [LEN*VECTOR_SIZE-1:0] mem_write_vector_data,
             output [ENTRY_INDEX_SIZE:0] vector_length,
             output [ADDR_WIDTH-1:0] mem_inst_addr,
             output [ADDR_WIDTH-1:0] mem_data_addr,
             output inst_fetch_enabled,
             output mem_vis_enabled,
             output [1:0] memory_vis_signal,
             output [2:0] data_type,
             output is_vector);
    
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
    
    reg                         ID_EXE_IS_VEC_INST;
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
    reg [LEN-1:0]               EXE_MEM_RS2;                 // 可能用于写的标量数据
    reg [VECTOR_SIZE*LEN - 1:0] EXE_MEM_VS3;                 // 可能用于写的向量数据
    
    reg                         EXE_MEM_VM;
    reg [31:0]                  EXE_MEM_VL;
    reg [31:0]                  EXE_MEM_VTYPE;
    wire [2:0]                  EXE_MEM_VSEW  = EXE_MEM_VTYPE[5:3];
    wire [2:0]                  EXE_MEM_VLMUL = EXE_MEM_VTYPE[2:0];
    
    reg [LEN-1:0]               EXE_MEM_IMM;
    reg [4:0]                   EXE_MEM_RD_INDEX;           // 记录的rd位置
    reg [3:0]                   EXE_MEM_FUNC_CODE;
    
    reg                         EXE_MEM_IS_VEC_INST;
    reg                         EXE_MEM_OP_ON_MASK;            // 是对mask的操作
    reg [1:0]                   EXE_MEM_MEM_VIS_SIGNAL;
    reg [1:0]                   EXE_MEM_MEM_VIS_DATA_SIZE;
    reg [1:0]                   EXE_MEM_BRANCH_SIGNAL;
    reg [1:0]                   EXE_MEM_WB_SIGNAL;
    
    // mem-wb
    reg [LEN-1:0]               MEM_WB_PC;
    
    reg [LEN-1:0]               MEM_WB_MEM_SCALAR_DATA;     // 从内存读取的scalar数据
    reg [VECTOR_SIZE*LEN - 1:0] MEM_WB_MEM_VECTOR_DATA;     // 从内存读取的vector数据
    reg [VECTOR_SIZE*LEN - 1:0] MEM_WB_MASK;
    reg [LEN-1:0]               MEM_WB_SCALAR_RESULT;       // scalar计算结果
    reg [VECTOR_SIZE*LEN - 1:0] MEM_WB_VECTOR_RESULT;       // vector计算结果
    
    reg                         MEM_WB_VM;
    reg [31:0]                  MEM_WB_VL;
    reg [31:0]                  MEM_WB_VTYPE;
    wire [2:0]                  MEM_WB_VSEW  = MEM_WB_VTYPE[5:3];
    wire [2:0]                  MEM_WB_VLMUL = MEM_WB_VTYPE[2:0];
    
    reg [4:0]                   MEM_WB_RD_INDEX;
    
    reg                         MEM_WB_IS_VEC_INST;
    reg                         MEM_WB_OP_ON_MASK;            // 是对mask的操作
    reg [1:0]                   MEM_WB_WB_SIGNAL;
    
    // MEM VISIT
    // ---------------------------------------------------------------------------------------------
    reg [2:0] scalar_data_type;
    always @(*) begin
        case (EXE_MEM_MEM_VIS_DATA_SIZE)
            `BYTE: scalar_data_type = `ONE_BYTE;
            `HALF: scalar_data_type = `TWO_BYTE;
            `WORD: scalar_data_type = `FOUR_BYTE;
        endcase
    end
    
    assign mem_inst_addr         = PC[ADDR_WIDTH-1:0];
    assign inst_fetch_enabled    = IF_STATE_CTR;
    assign mem_write_scalar_data = EXE_MEM_RS2;
    
    assign mem_data_addr         = EXE_MEM_SCALAR_RESULT[ADDR_WIDTH-1:0];
    assign mem_vis_enabled       = MEM_STATE_CTR;
    assign memory_vis_signal     = MEM_STATE_CTR ? EXE_MEM_MEM_VIS_SIGNAL:`MEM_CTR_NOP;
    assign vm                    = EXE_MEM_VM;
    assign mask                  = EXE_MEM_MASK;
    assign mem_write_vector_data = EXE_MEM_VS3;
    assign vector_length         = EXE_MEM_VL;
    assign is_vector             = EXE_MEM_IS_VEC_INST;
    assign data_type             = EXE_MEM_IS_VEC_INST? EXE_MEM_VSEW : scalar_data_type;
    
    
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
    .zimm                    	(decoder_zimm), // todo:zimm in vector instruction
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
    
    assign  scalar_rf_rf_signal          = (WB_STATE_CTR&&scalar_rb_flag)? `SCALAR_RF_WRITE:`RF_NOP;
    assign  scalar_rf_write_back_enabled = WB_STATE_CTR;
    
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
    reg [VECTOR_SIZE*LEN-1:0]   vector_rf_reg_write_data;
    wire                        vector_rf_write_back_enabled;
    
    assign  vector_rf_rf_signal          = (WB_STATE_CTR&&vector_rb_flag)? `VECTOR_RF_WRITE:`RF_NOP;
    assign  vector_rf_write_back_enabled = WB_STATE_CTR;
    
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
    .mask               	(MEM_WB_MASK),
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
    assign vector_function_unit_execute = ID_EXE_IS_VEC_INST;
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
    
    // STAGE1 : INSTRUCTION FETCH
    // - memory visit取指令
    // - 更新transfer register的PC
    // ---------------------------------------------------------------------------------------------
    
    always @(posedge clk) begin
        if (rdy_in) begin
            if (chip_enabled&&start_cpu) begin
                if (IF_STATE_CTR) begin
                    IF_ID_PC <= PC;
                end
                // IF没有结束，向下加stall
                if (i_cache_vis_status == `IF_FINISHED) begin
                    ID_STATE_CTR <= 1;
                end
                else begin
                    ID_STATE_CTR <= 0;
                end
            end
            else begin
                PC <= 0;
            end
        end
    end
    
    // STAGE2 : INSTRUCTION DECODE
    // - decoder解码
    // - 访问register file取值
    // ---------------------------------------------------------------------------------------------
    
    always @(posedge clk) begin
        if ((!rst)&&rdy_in&&start_cpu) begin
            if (ID_STATE_CTR) begin
                ID_EXE_PC <= IF_ID_PC;
                
                ID_EXE_RS1  <= scalar_rf_rs1_data;
                ID_EXE_RS2  <= scalar_rf_rs2_data;
                ID_EXE_MASK <= vector_rf_v0_data;
                ID_EXE_VS1  <= vector_rf_rs1_data;
                ID_EXE_VS2  <= vector_rf_rs2_data;
                ID_EXE_VS3  <= vector_rf_rs3_data;
                
                ID_EXE_VM    <= decoder_vm;
                ID_EXE_VL    <= VL;
                ID_EXE_VTYPE <= VTYPE;
                
                ID_EXE_IMM              <= decoder_output_immediate;
                ID_EXE_RD_INDEX         <= decoder_reg3_index;
                ID_EXE_FUNC_CODE        <= decoder_output_func_code;
                ID_EXE_VEC_OPERAND_TYPE <= decoder_output_vec_operand_type;
                ID_EXE_EXT_TYPE         <= decoder_reg1_index;
                ID_EXE_FUNCT6           <= decoder_output_func6;
                
                ID_EXE_IS_VEC_INST       <= decoder_is_vector_instruction;
                ID_EXE_ALU_SIGNAL        <= decoder_output_exe_signal;
                ID_EXE_MEM_VIS_SIGNAL    <= decoder_output_mem_vis_signal;
                ID_EXE_MEM_VIS_DATA_SIZE <= decoder_output_data_size;
                ID_EXE_BRANCH_SIGNAL     <= decoder_output_branch_signal;
                ID_EXE_WB_SIGNAL         <= decoder_output_wb_signal;
                
                EXE_STATE_CTR <= 1;
            end
            else begin
                EXE_STATE_CTR <= 0;
            end
        end
    end
    
    // STAGE3 : EXECUTE
    // - alu执行运算
    // scalar 和 vector运行需要时间的差距
    // ---------------------------------------------------------------------------------------------
    always @(posedge clk) begin
        if ((!rst)&&rdy_in&&start_cpu)begin
            // 标量指令
            if (EXE_STATE_CTR && !ID_EXE_IS_VEC_INST) begin
                EXE_MEM_PC <= ID_EXE_PC;
                
                EXE_MEM_SCALAR_RESULT <= scalar_alu_result;
                EXE_MEM_ZERO_BITS     <= scalar_alu_sign_bits;
                EXE_MEM_RS2           <= ID_EXE_RS2;
                EXE_MEM_VS3           <= ID_EXE_VS3;
                
                EXE_MEM_IMM       <= ID_EXE_IMM;
                EXE_MEM_RD_INDEX  <= ID_EXE_RD_INDEX;
                EXE_MEM_FUNC_CODE <= ID_EXE_FUNC_CODE;
                
                EXE_MEM_IS_VEC_INST       <= ID_EXE_IS_VEC_INST;
                EXE_MEM_MEM_VIS_SIGNAL    <= ID_EXE_MEM_VIS_SIGNAL;
                EXE_MEM_MEM_VIS_DATA_SIZE <= ID_EXE_MEM_VIS_DATA_SIZE;
                EXE_MEM_BRANCH_SIGNAL     <= ID_EXE_BRANCH_SIGNAL;
                EXE_MEM_WB_SIGNAL         <= ID_EXE_WB_SIGNAL;
                
                MEM_STATE_CTR <= 1;
            end
            else begin
                // 要做向量运算
                if (EXE_STATE_CTR) begin
                    if (vector_function_unit_vector_alu_status == `VEC_ALU_NOP) begin
                        // 更新transfer register
                        EXE_MEM_PC <= ID_EXE_PC;
                        
                        EXE_MEM_MASK <= ID_EXE_MASK;
                        
                        EXE_MEM_VM    <= ID_EXE_VM;
                        EXE_MEM_VL    <= ID_EXE_VL;
                        EXE_MEM_VTYPE <= ID_EXE_VTYPE;
                        
                        EXE_MEM_IMM       <= ID_EXE_IMM;
                        EXE_MEM_RD_INDEX  <= ID_EXE_RD_INDEX;
                        EXE_MEM_FUNC_CODE <= ID_EXE_FUNC_CODE;
                        
                        EXE_MEM_IS_VEC_INST       <= ID_EXE_IS_VEC_INST;
                        EXE_MEM_MEM_VIS_SIGNAL    <= ID_EXE_MEM_VIS_SIGNAL;
                        EXE_MEM_MEM_VIS_DATA_SIZE <= ID_EXE_MEM_VIS_DATA_SIZE;
                        EXE_MEM_BRANCH_SIGNAL     <= ID_EXE_BRANCH_SIGNAL;
                        EXE_MEM_WB_SIGNAL         <= ID_EXE_WB_SIGNAL;
                    end
                end
                // 所有向量计算完成
                if (vector_function_unit_vector_alu_status == `VEC_ALU_FINISHED) begin
                    // 记录结果
                    EXE_MEM_VECTOR_RESULT <= vector_function_unit_result;
                    EXE_MEM_OP_ON_MASK    <= vector_function_unit_is_mask;
                    
                    MEM_STATE_CTR <= 1;
                end
                else begin
                    MEM_STATE_CTR <= 0;
                end
            end
        end
    end
    
    // STAGE4 : MEMORY VISIT
    // - visit memory
    // | + 标量访存照常
    // | + 带mask的向量访存，仅load/store被激活的数据位
    // |   load未激活部分用默认数值填充，write back带mask
    // - pc update
    // ---------------------------------------------------------------------------------------------
    reg [LEN-1:0] increased_pc;
    reg [LEN-1:0] special_pc;
    
    reg branch_flag;
    
    // branch
    always @(*) begin
        case (EXE_MEM_BRANCH_SIGNAL)
            `CONDITIONAL:begin
                case (EXE_MEM_FUNC_CODE[2:0])
                    3'b000:begin
                        if (EXE_MEM_ZERO_BITS == `ZERO) begin
                            branch_flag = 1;
                        end
                        else begin
                            branch_flag = 0;
                        end
                    end
                    3'b001:begin
                        if (EXE_MEM_ZERO_BITS == `ZERO) begin
                            branch_flag = 0;
                        end
                        else begin
                            branch_flag = 1;
                        end
                    end
                    default:
                    $display("[ERROR]:unexpected branch instruction\n");
                endcase
            end
            `UNCONDITIONAL:begin
                branch_flag = 1;
            end
            `UNCONDITIONAL_RESULT:begin
                branch_flag = 1;
            end
            `NOT_BRANCH:begin
                branch_flag = 0;
            end
            default:
            $display("[ERROR]:unexpected EXE_MEM_BRANCH_SIGNAL in core\n");
        endcase
    end
    
    always @(*) begin
        increased_pc = EXE_MEM_PC + 4;
        if (EXE_MEM_BRANCH_SIGNAL == `UNCONDITIONAL_RESULT) begin
            special_pc = EXE_MEM_SCALAR_RESULT &~ 1;
        end
        else begin
            special_pc = EXE_MEM_PC + EXE_MEM_IMM;
        end
    end
    
    reg mem_working_on_vector;
    
    // memory visit
    always @(posedge clk) begin
        if ((!rst)&&rdy_in&&start_cpu) begin
            if (MEM_STATE_CTR) begin
                if (d_cache_vis_status == `MEM_CTR_RESTING) begin
                    // update pc
                    if (branch_flag) begin
                        PC <= special_pc;
                    end
                    else begin
                        PC <= increased_pc;
                    end
                    MEM_WB_PC <= EXE_MEM_PC;
                    
                    MEM_WB_RD_INDEX <= EXE_MEM_RD_INDEX;
                    
                    MEM_WB_IS_VEC_INST <= EXE_MEM_IS_VEC_INST;
                    MEM_WB_WB_SIGNAL   <= EXE_MEM_WB_SIGNAL;
                    
                    if (EXE_MEM_IS_VEC_INST) begin
                        // 向量load/store
                        mem_working_on_vector <= `TRUE;
                        
                        MEM_WB_MASK          <= EXE_MEM_MASK;
                        MEM_WB_VECTOR_RESULT <= EXE_MEM_VECTOR_RESULT;
                        
                        MEM_WB_VM    <= EXE_MEM_VM;
                        MEM_WB_VL    <= EXE_MEM_VL;
                        MEM_WB_VTYPE <= EXE_MEM_VTYPE;
                        
                        MEM_WB_OP_ON_MASK <= EXE_MEM_OP_ON_MASK;
                    end
                    else begin
                        // 标量load/store
                        mem_working_on_vector <= `FALSE;
                        MEM_WB_SCALAR_RESULT  <= EXE_MEM_SCALAR_RESULT;
                    end
                end
            end
            
            if (d_cache_vis_status == `MEM_CTR_FINISHED) begin
                if (mem_working_on_vector) begin
                    // 向量
                    MEM_WB_MEM_VECTOR_DATA <= mem_read_vector_data;
                end
                else begin
                    // 标量
                    MEM_WB_MEM_SCALAR_DATA <= mem_read_scalar_data;
                end
                WB_STATE_CTR <= 1;
            end
            else begin
                WB_STATE_CTR <= 0;
            end
        end
    end
    
    // STAGE5 : WRITE BACK
    // - write back to register
    // ---------------------------------------------------------------------------------------------
    // 标量
    reg scalar_rb_flag;
    
    always @(*) begin
        case (MEM_WB_WB_SIGNAL)
            `MEM_TO_REG:begin
                scalar_rf_reg_write_data = MEM_WB_MEM_SCALAR_DATA;
                scalar_rb_flag           = 1;
            end
            `ARITH:begin
                scalar_rf_reg_write_data = MEM_WB_SCALAR_RESULT;
                scalar_rb_flag           = 1;
            end
            `INCREASED_PC:begin
                scalar_rf_reg_write_data = 4 + MEM_WB_PC;
                scalar_rb_flag           = 1;
            end
            `WB_NOP:begin
                scalar_rb_flag = 0;
            end
        endcase
    end
    
    // 向量
    reg vector_rb_flag;
    
    always @(*) begin
        case (MEM_WB_WB_SIGNAL)
            `MEM_TO_REG:begin
                vector_rf_reg_write_data = MEM_WB_MEM_VECTOR_DATA;
                vector_rb_flag           = 1;
            end
            `ARITH:begin
                vector_rf_reg_write_data = MEM_WB_VECTOR_RESULT;
                vector_rb_flag           = 1;
            end
            `WB_NOP:begin
                vector_rb_flag = 0;
            end
        endcase
    end
    
    always @(posedge clk) begin
        if ((!rst)&&rdy_in&&start_cpu)begin
            if (scalar_rf_rf_status == `RF_FINISHED||vector_rf_rf_status == `RF_FINISHED) begin
                IF_STATE_CTR <= 1;
            end
            else begin
                IF_STATE_CTR <= 0;
            end
        end
    end
    
endmodule
