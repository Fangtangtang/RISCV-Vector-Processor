// #############################################################################################################################
// DECODER
// 
// 组合逻辑 解码指令
// #############################################################################################################################
`include "src/defines.v"

module DECODER#(parameter ADDR_WIDTH = 20,
                parameter DATA_LEN = 32,
                parameter SCALAR_REG_LEN = 64,                     // 标量寄存器
                parameter BYTE_SIZE = 8,
                parameter VECTOR_SIZE = 8,
                parameter ENTRY_INDEX_SIZE = 3)
               (input chip_enabled,
                input wire [DATA_LEN-1:0] instruction,
                output wire is_vector_instruction,
                output wire [4:0] reg1_index,
                output wire [4:0] reg2_index,
                output wire [4:0] reg3_index,
                output wire [11:0] csr_encoding,
                output wire vm,
                output wire [10:0] zimm,                           // 在vector指令中可能被拆解
                output wire [3:0] output_func_code,                // 包含funct3
                output wire [5:0] output_func6,                    // 在vector指令中可能被拆解
                output wire [SCALAR_REG_LEN-1:0] output_immediate,
                output wire [3:0] output_exe_signal,
                output wire [1:0] output_vec_operand_type,
                output wire [1:0] output_mem_vis_signal,
                output wire [2:0] output_data_size,
                output wire [1:0] output_vector_l_s_type,
                output wire [1:0] output_branch_signal,
                output wire [2:0] output_wb_signal);
    
    // 使用的向量或标量寄存器下标
    assign reg1_index   = instruction[19:15];
    assign reg2_index   = instruction[24:20];
    assign reg3_index   = instruction[11:7];
    assign csr_encoding = instruction[31:20];
    
    wire [6:0]      opcode;
    wire [2:0]      func3;
    wire [5:0]      func6;
    wire [3:0]      func_code;
    assign opcode    = instruction[6:0];
    assign func3     = instruction[14:12];
    assign func6     = instruction[31:26];
    assign func_code = {instruction[30],instruction[14:12]};
    
    assign vm               = instruction[25];
    assign zimm             = instruction[30:20];
    assign output_func6     = instruction[31:26];
    assign output_func_code = {instruction[30],instruction[14:12]};
    
    assign is_vector_instruction = opcode == `VL||opcode == `VS||opcode == `VARITH;
    wire            P_type; // privilege instruction
    wire            V_type; // vector instruction
    wire            R_type; // binary and part of imm binary
    wire            I_type; // jalr,load and part of imm binary
    wire            S_type; // store
    wire            B_type; // branch
    wire            U_type; // big int
    wire            J_type; // jump
    
    wire special_func_code = func_code == 4'b0001||func_code == 4'b0101||func_code == 4'b1101;
    
    assign P_type = opcode == 7'b1110011;
    assign V_type = opcode == `VL||opcode == `VS||opcode == `VARITH;
    assign R_type = (opcode == 7'b0110011)||(opcode == 7'b0010011&&special_func_code)||opcode == 7'b0111011;
    assign I_type = (opcode == 7'b0010011&&(!special_func_code))||(opcode == 7'b0000011)||((opcode == 7'b1100111||opcode == 7'b0011011)&&func_code[2:0] == 3'b000);
    assign S_type = opcode == 7'b0100011;
    assign B_type = opcode == 7'b1100011;
    assign U_type = opcode == 7'b0110111||opcode == 7'b0010111;
    assign J_type = opcode == 7'b1101111;
    
    // IMMEDIATE
    wire sign_bit;
    assign sign_bit = instruction[31];
    
    wire signed [SCALAR_REG_LEN-1:0] P_imm = {{59{1'b0}},instruction[19:15]};
    wire signed [SCALAR_REG_LEN-1:0] V_imm = {{59{instruction[19]}},instruction[19:15]};
    wire signed [SCALAR_REG_LEN-1:0] R_imm = {{59{instruction[24]}},instruction[24:20]};
    wire signed [SCALAR_REG_LEN-1:0] I_imm = {{52{sign_bit}}, instruction[31:20]};
    wire signed [SCALAR_REG_LEN-1:0] S_imm = {{52{sign_bit}}, instruction[31:25], instruction[11:7]};
    // B:在立即数中已经处理移位
    wire signed [SCALAR_REG_LEN-1:0] B_imm = {{51{sign_bit}}, sign_bit, instruction[7], instruction[30:25], instruction[11:8],1'b0};
    wire signed [SCALAR_REG_LEN-1:0] U_imm = {{32{sign_bit}},instruction[31:12],{12{1'b0}}};
    // J:在立即数中已经处理移位
    wire signed [SCALAR_REG_LEN-1:0] J_imm = {{44{sign_bit}}, instruction[31], instruction[19:12], instruction[20], instruction[30:21],1'b0};
    
    reg [SCALAR_REG_LEN-1:0]    immediate;
    reg [3:0]                   exe_signal;
    reg [1:0]                   vec_operand_type;
    reg [1:0]                   mem_vis_signal;
    reg [2:0]                   data_size;
    reg [1:0]                   vector_l_s_type;
    reg [1:0]                   branch_signal;
    reg [2:0]                   wb_signal;
    
    assign output_immediate        = immediate;
    assign output_exe_signal       = exe_signal;
    assign output_vec_operand_type = vec_operand_type;
    assign output_mem_vis_signal   = mem_vis_signal;
    assign output_data_size        = data_size;
    assign output_vector_l_s_type  = vector_l_s_type;
    assign output_branch_signal    = branch_signal;
    assign output_wb_signal        = wb_signal;
    
    always @(*) begin
        case ({P_type,V_type,R_type,I_type,S_type,B_type,U_type,J_type})
            `P_TYPE:begin
                immediate        = P_imm;
                vec_operand_type = `NOT_VEC_ARITH;
                vector_l_s_type  = `NOT_ACCESS;
                case (func3)
                    `CSRRS:begin
                        exe_signal     = `READ_CSR;
                        mem_vis_signal = `MEM_CTR_NOP;
                        data_size      = `NOT_ACCESS;
                        branch_signal  = `NOT_BRANCH;
                        wb_signal      = `CSR_TO_REG;
                    end
                    default:
                    $display("[ERROR]:unexpected data width in privilege instruction\n");
                endcase
            end
            `V_TYPE:begin
                immediate = V_imm;
                case (opcode)
                    // vector load
                    `VL:begin
                        exe_signal       = `VEC_MEM_ADDR;
                        vec_operand_type = `NOT_VEC_ARITH;
                        mem_vis_signal   = `MEM_CTR_LOAD;
                        case (func3)
                            3'b000:begin
                                data_size = `ONE_BYTE;
                            end
                            3'b101:begin
                                data_size = `TWO_BYTE;
                            end
                            3'b110:begin
                                data_size = `FOUR_BYTE;
                            end
                            3'b111:begin
                                data_size = `EIGHT_BYTE;
                            end
                            default:
                            $display("[ERROR]:unexpected data width in VL instruction\n");
                        endcase
                        case (instruction[24:20])
                            `E_BASIC:begin
                                vector_l_s_type = `STRIDE;
                            end
                            `E_WHOLE_REG:begin
                                vector_l_s_type = `WHOLE_REG;
                            end
                            `E_MASK:begin
                                vector_l_s_type = `MASK; // load as mask
                            end
                            default:
                            $display("[ERROR]:unexpected lumop in VL instruction\n");
                        endcase
                        branch_signal = `NOT_BRANCH;
                        wb_signal     = `MEM_TO_REG;
                    end
                    // vector store
                    `VS:begin
                        exe_signal       = `VEC_MEM_ADDR;
                        vec_operand_type = `NOT_VEC_ARITH;
                        mem_vis_signal   = `MEM_CTR_STORE;
                        case (func3)
                            3'b000:begin
                                data_size = `ONE_BYTE;
                            end
                            3'b101:begin
                                data_size = `TWO_BYTE;
                            end
                            3'b110:begin
                                data_size = `FOUR_BYTE;
                            end
                            3'b111:begin
                                data_size = `EIGHT_BYTE;
                            end
                            default:
                            $display("[ERROR]:unexpected data width in VS instruction\n");
                        endcase
                        case (instruction[24:20])
                            `E_BASIC:begin
                                vector_l_s_type = `STRIDE;
                            end
                            `E_WHOLE_REG:begin
                                vector_l_s_type = `WHOLE_REG;
                            end
                            `E_MASK:begin
                                vector_l_s_type = `MASK; // store as mask
                            end
                            default:
                            $display("[ERROR]:unexpected lumop in VS instruction\n");
                        endcase
                        branch_signal = `NOT_BRANCH;
                        wb_signal     = `WB_NOP;
                    end
                    // arithmetic\configuration
                    `VARITH:begin
                        mem_vis_signal  = `MEM_CTR_NOP;
                        data_size       = `NOT_ACCESS;
                        vector_l_s_type = `NOT_ACCESS;
                        branch_signal   = `NOT_BRANCH;
                        wb_signal       = `ARITH;
                        case (func3)
                            `OPIVV:begin // integer vec-vec
                                exe_signal       = `BINARY;
                                vec_operand_type = `VEC_VEC;
                            end
                            `OPMVV:begin // mask vec-vec
                                exe_signal       = `BINARY;
                                vec_operand_type = `VEC_VEC;
                            end
                            `OPIVI:begin // integer vec-imm
                                exe_signal       = `IMM_BINARY;
                                vec_operand_type = `VEC_IMM;
                            end
                            `OPIVX:begin // integer vec-scalar
                                exe_signal       = `BINARY;
                                vec_operand_type = `VEC_SCALAR;
                            end
                            `OPMVX:begin // mask vec-scalar
                                exe_signal       = `BINARY;
                                vec_operand_type = `VEC_SCALAR;
                            end
                            // configuration setting
                            `OPCFG:begin
                                exe_signal       = `SET_CFG;
                                vec_operand_type = `NOT_VEC_ARITH;
                            end
                            default:
                            $display("[ERROR]:unexpected func3 in VA/VCFG instruction\n");
                        endcase
                    end
                    default:
                    $display("[ERROR]:unexpected V type instruction\n");
                endcase
            end
            `R_TYPE:begin
                immediate        = R_imm;
                vec_operand_type = `NOT_VEC_ARITH;
                vector_l_s_type  = `NOT_ACCESS;
                case (opcode)
                    7'b0110011: begin
                        exe_signal     = `BINARY;
                        mem_vis_signal = `MEM_CTR_NOP;
                        data_size      = `NOT_ACCESS;
                        branch_signal  = `NOT_BRANCH;
                        wb_signal      = `ARITH;
                    end
                    7'b0010011: begin
                        exe_signal     = `IMM_BINARY;
                        mem_vis_signal = `MEM_CTR_NOP;
                        data_size      = `NOT_ACCESS;
                        branch_signal  = `NOT_BRANCH;
                        wb_signal      = `ARITH;
                    end
                    // addw
                    7'b0111011:begin
                        exe_signal     = `BINARY_WORD;
                        mem_vis_signal = `MEM_CTR_NOP;
                        data_size      = `NOT_ACCESS;
                        branch_signal  = `NOT_BRANCH;
                        wb_signal      = `ARITH;
                    end
                    default:
                    $display("[ERROR]:unexpected R type instruction\n");
                endcase
            end
            `I_TYPE:begin
                immediate        = I_imm;
                vec_operand_type = `NOT_VEC_ARITH;
                vector_l_s_type  = `NOT_ACCESS;
                case (opcode)
                    7'b0010011: begin
                        exe_signal     = `IMM_BINARY;
                        mem_vis_signal = `MEM_CTR_NOP;
                        data_size      = `NOT_ACCESS;
                        branch_signal  = `NOT_BRANCH;
                        wb_signal      = `ARITH;
                    end
                    // addiw
                    7'b0011011:begin
                        exe_signal     = `IMM_BINARY_WORD;
                        mem_vis_signal = `MEM_CTR_NOP;
                        data_size      = `NOT_ACCESS;
                        branch_signal  = `NOT_BRANCH;
                        wb_signal      = `ARITH;
                    end
                    // load
                    7'b0000011:begin
                        exe_signal     = `MEM_ADDR;
                        mem_vis_signal = `MEM_CTR_LOAD;
                        branch_signal  = `NOT_BRANCH;
                        wb_signal      = `MEM_TO_REG;
                        case (func_code[2:0])
                            3'b000:data_size = `ONE_BYTE;
                            3'b001:data_size = `TWO_BYTE;
                            3'b010:data_size = `FOUR_BYTE;
                            3'b011:data_size = `EIGHT_BYTE;
                            default:
                            $display("[ERROR]:unexpected load instruction\n");
                        endcase
                    end
                    // jalr
                    7'b1100111:begin
                        exe_signal     = `MEM_ADDR;
                        mem_vis_signal = `MEM_CTR_NOP;
                        data_size      = `NOT_ACCESS;
                        branch_signal  = `UNCONDITIONAL_RESULT;
                        wb_signal      = `INCREASED_PC;
                    end
                    default:
                    $display("[ERROR]:unexpected I type instruction\n");
                endcase
            end
            `S_TYPE:begin
                immediate        = S_imm;
                vec_operand_type = `NOT_VEC_ARITH;
                vector_l_s_type  = `NOT_ACCESS;
                exe_signal       = `MEM_ADDR;
                mem_vis_signal   = `MEM_CTR_STORE;
                branch_signal    = `NOT_BRANCH;
                wb_signal        = `WB_NOP;
                case (func_code[2:0])
                    3'b000:data_size = `ONE_BYTE;
                    3'b001:data_size = `TWO_BYTE;
                    3'b010:data_size = `FOUR_BYTE;
                    3'b011:data_size = `EIGHT_BYTE;
                    default:
                    $display("[ERROR]:unexpected load instruction\n");
                endcase
            end
            `B_TYPE:begin
                immediate        = B_imm;
                vec_operand_type = `NOT_VEC_ARITH;
                vector_l_s_type  = `NOT_ACCESS;
                exe_signal       = `BRANCH_COND;
                mem_vis_signal   = `MEM_CTR_NOP;
                data_size        = `NOT_ACCESS;
                branch_signal    = `CONDITIONAL;
                wb_signal        = `WB_NOP;
            end
            `U_TYPE:begin
                immediate        = U_imm;
                vec_operand_type = `NOT_VEC_ARITH;
                vector_l_s_type  = `NOT_ACCESS;
                case (opcode)
                    7'b0110111:begin
                        exe_signal     = `IMM;
                        mem_vis_signal = `MEM_CTR_NOP;
                        data_size      = `NOT_ACCESS;
                        branch_signal  = `NOT_BRANCH;
                        wb_signal      = `ARITH;
                    end
                    7'b0010111:begin
                        exe_signal     = `PC_BASED;
                        mem_vis_signal = `MEM_CTR_NOP;
                        data_size      = `NOT_ACCESS;
                        branch_signal  = `NOT_BRANCH;
                        wb_signal      = `ARITH;
                    end
                    default:
                    $display("[ERROR]:unexpected U type instruction\n");
                endcase
            end
            `J_TYPE:begin
                immediate        = J_imm;
                vec_operand_type = `NOT_VEC_ARITH;
                vector_l_s_type  = `NOT_ACCESS;
                exe_signal       = `PC_BASED;
                mem_vis_signal   = `MEM_CTR_NOP;
                data_size        = `NOT_ACCESS;
                branch_signal    = `UNCONDITIONAL;
                wb_signal        = `INCREASED_PC;
            end
            default:
            $display("[ERROR]:invalid instruction type\n");
        endcase
    end
    
endmodule
