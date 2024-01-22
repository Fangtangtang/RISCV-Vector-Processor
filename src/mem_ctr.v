// #############################################################################################################################
// MEMORY CONTROLLER
// 
// 控制数据访存
// 连接core和data cache
// 
// - core发来标量或向量访存请求，由memory controller拆成数据类型+首地址访存
// | + 标量访存照常：标量寄存器64位，内存数据单元32位
// | + 带mask的向量访存，仅load/store被激活的数据位
// |   load未激活部分用默认数值0填充，write back带mask
// 
// - 未激活，快进；发向cache的地址hit（组合逻辑实现），快进
// 
// todo: mask的load，被mask部分用0替换？
// todo: data cache hit?
// todo: correct addr update??
// #############################################################################################################################
`include"src/defines.v"

module MEMORY_CONTROLLER#(parameter ADDR_WIDTH = 20,
                          parameter DATA_LEN = 32,                              // 内存数据单元
                          parameter SCALAR_REG_LEN = 64,                        // 标量寄存器
                          parameter BYTE_SIZE = 8,
                          parameter VECTOR_SIZE = 8,
                          parameter ENTRY_INDEX_SIZE = 3,
                          parameter CACHE_SIZE = 16,
                          parameter CACHE_INDEX_SIZE = 4)
                         (input wire clk,
                          input [ADDR_WIDTH-1:0] data_addr,
                          input mem_access_enabled,
                          input is_vector,                                      // 是否为向量访存
                          input [1:0] data_vis_signal,
                          input[2:0] mem_data_type,
                          input [ENTRY_INDEX_SIZE:0] length,
                          input vm,
                          input [DATA_LEN*VECTOR_SIZE-1:0] mask,                // 向量访存掩码
                          output reg [SCALAR_REG_LEN-1:0] scalar_data,
                          output [DATA_LEN*VECTOR_SIZE-1:0] vector_data,
                          input [SCALAR_REG_LEN-1:0] written_scalar_data,
                          input [DATA_LEN*VECTOR_SIZE-1:0] written_vector_data,
                          output reg [1:0] mem_vis_status,                      // interact with data cache
                          input [DATA_LEN-1:0] mem_data,
                          input [1:0] d_cache_status,
                          output reg [DATA_LEN-1:0] cache_written_data,         // 写入memory的数据
                          output [ENTRY_INDEX_SIZE:0] write_length,             // 1:单个数
                          output [ADDR_WIDTH-1:0] mem_vis_addr,                 // 访存地址
                          output [2:0] d_cache_data_type,                       // 数据类型（包括标量向量）
                          output reg [1:0] cache_vis_signal);
    
    reg [1:0]                   CNT = 0;
    reg [1:0]                   task_type;
    
    reg _vm;
    reg [DATA_LEN*VECTOR_SIZE-1:0]  _mask;
    
    reg                             visit_vector;
    reg [2:0]                       requested_data_type;
    reg [ADDR_WIDTH-1:0]            current_addr;
    reg [ENTRY_INDEX_SIZE:0]        requested_length;
    reg [ENTRY_INDEX_SIZE:0]        current_length;
    reg [SCALAR_REG_LEN-1:0]        _written_scalar_data;
    reg [DATA_LEN*VECTOR_SIZE-1:0]  _written_vector_data;
    assign mem_vis_addr = current_addr;
    
    wire [BYTE_SIZE-1:0] _written_vector_data_slices [0:DATA_LEN*VECTOR_SIZE/BYTE_SIZE-1];
    
    genvar i;
    for (i = 0;i<DATA_LEN*VECTOR_SIZE/BYTE_SIZE;i = i+1) begin
        assign _written_vector_data_slices[i] = _written_vector_data[BYTE_SIZE*(i+1)-1:BYTE_SIZE*i];
    end
    
    wire _written_vector_data_tiny_slices [0:DATA_LEN*VECTOR_SIZE-1];
    
    for (i = 0;i<DATA_LEN*VECTOR_SIZE;i = i+1) begin
        assign _written_vector_data_tiny_slices[i] = _written_vector_data[i];
    end
    
    reg [DATA_LEN-1:0] written_data1;
    reg [DATA_LEN-1:0] written_data2; // 8byte 分两次存
    always @(*) begin
        case(requested_data_type)
            `ONE_BIT:begin
                written_data1 = {31'b0,_written_vector_data_tiny_slices[current_length]};
            end
            `ONE_BYTE:begin
                written_data1 = {24'b0,_written_vector_data_slices[current_length]};
            end
            `TWO_BYTE:begin
                written_data1 = {16'b0,_written_vector_data_slices[(current_length<<1)+1],_written_vector_data_slices[(current_length<<1)]};
            end
            `FOUR_BYTE:begin
                written_data1 = {_written_vector_data_slices[(current_length<<2)+3],_written_vector_data_slices[(current_length<<2)+2],_written_vector_data_slices[(current_length<<2)+1],_written_vector_data_slices[(current_length<<2)]};
            end
            `EIGHT_BYTE:begin
                written_data2 = {_written_vector_data_slices[(current_length<<3)+7],_written_vector_data_slices[(current_length<<3)+6],_written_vector_data_slices[(current_length<<3)+5],_written_vector_data_slices[(current_length<<3)+4]};
                written_data1 = {_written_vector_data_slices[(current_length<<3)+3],_written_vector_data_slices[(current_length<<3)+2],_written_vector_data_slices[(current_length<<3)+1],_written_vector_data_slices[(current_length<<3)]};
            end
            default:
            $display("[ERROR]:unexpected requested_data_type in mem ctr\n");
        endcase
    end
    
    wire [DATA_LEN*VECTOR_SIZE-1:0]   load_vector_data; // 存要读取的vector
    reg [BYTE_SIZE-1:0] load_vector_data_slices [0:DATA_LEN*VECTOR_SIZE/BYTE_SIZE-1];
    for (i = 0;i<DATA_LEN*VECTOR_SIZE/BYTE_SIZE;i = i+1) begin
        assign load_vector_data[(i+1)*8 - 1 : i*8] = load_vector_data_slices[i];
    end
    
    wire [DATA_LEN*VECTOR_SIZE-1:0]   load_vector_mask; // 存要读取的mask vector
    reg [BYTE_SIZE-1:0] load_vector_mask_slices [0:DATA_LEN*VECTOR_SIZE-1];
    for (i = 0;i<DATA_LEN*VECTOR_SIZE;i = i+1) begin
        assign load_vector_mask[i] = load_vector_mask_slices[i];
    end
    
    assign vector_data = (requested_data_type == `ONE_BIT) ? load_vector_mask:load_vector_data;
    
    
    wire [BYTE_SIZE-1:0] storage0Value  = load_vector_data_slices[0];
    wire [BYTE_SIZE-1:0] storage1Value  = load_vector_data_slices[1];
    wire [BYTE_SIZE-1:0] storage2Value  = load_vector_data_slices[2];
    wire [BYTE_SIZE-1:0] storage3Value  = load_vector_data_slices[3];
    wire [BYTE_SIZE-1:0] storage4Value  = load_vector_data_slices[4];
    wire [BYTE_SIZE-1:0] storage5Value  = load_vector_data_slices[5];
    wire [BYTE_SIZE-1:0] storage6Value  = load_vector_data_slices[6];
    wire [BYTE_SIZE-1:0] storage7Value  = load_vector_data_slices[7];
    wire [BYTE_SIZE-1:0] storage8Value  = load_vector_data_slices[8];
    wire [BYTE_SIZE-1:0] storage9Value  = load_vector_data_slices[9];
    wire [BYTE_SIZE-1:0] storage10Value = load_vector_data_slices[10];
    wire [BYTE_SIZE-1:0] storage11Value = load_vector_data_slices[11];
    wire [BYTE_SIZE-1:0] storage12Value = load_vector_data_slices[12];
    wire [BYTE_SIZE-1:0] storage13Value = load_vector_data_slices[13];
    wire [BYTE_SIZE-1:0] storage14Value = load_vector_data_slices[14];
    wire [BYTE_SIZE-1:0] storage15Value = load_vector_data_slices[15];
    
    assign d_cache_data_type = (requested_data_type == `ONE_BIT) ? `ONE_BYTE:requested_data_type;
    
    always @(posedge clk) begin
        case (CNT)
            // 等待开始工作
            3:begin
                if (d_cache_status == `D_CACHE_RESTING)begin
                    mem_vis_status <= `MEM_CTR_WORKING;
                    case (task_type)
                        `MEM_CTR_LOAD:begin
                            if (visit_vector)begin
                                if (_mask[current_length]||_vm)begin
                                    cache_vis_signal <= `D_CACHE_LOAD;
                                end
                                else begin
                                    cache_vis_signal <= `D_CACHE_NOP;
                                end
                                if (requested_data_type == `EIGHT_BYTE)begin
                                    CNT <= 2;
                                end
                                else begin
                                    CNT <= 1;
                                end
                            end
                            else begin
                                if (requested_data_type == `EIGHT_BYTE)begin
                                    CNT <= 2;
                                end
                                else begin
                                    CNT <= 1;
                                end
                                cache_vis_signal <= `D_CACHE_LOAD;
                            end
                        end
                        `MEM_CTR_STORE:begin
                            if (visit_vector) begin
                                if (_mask[current_length]||_vm)begin
                                    cache_vis_signal <= `D_CACHE_STORE;
                                end
                                else begin
                                    cache_vis_signal <= `D_CACHE_NOP;
                                end
                                cache_written_data <= written_data1; // 第一个待写数据
                                if (requested_data_type == `EIGHT_BYTE)begin
                                    CNT <= 2;
                                end
                                else begin
                                    CNT <= 1;
                                end
                            end
                            else begin
                                if (requested_data_type == `EIGHT_BYTE)begin
                                    CNT <= 2;
                                end
                                else begin
                                    CNT <= 1;
                                end
                                cache_written_data <= _written_scalar_data[DATA_LEN-1:0]; // 64位数据后半部分
                                cache_vis_signal   <= `D_CACHE_STORE;
                            end
                        end
                        default:
                        $display("[ERROR]:unexpected task_type when cnt == 3 in memory controller\n");
                    endcase
                end
                else begin
                    CNT              <= 3;
                    cache_vis_signal <= `D_CACHE_NOP;
                    mem_vis_status   <= `MEM_CTR_STALL;
                end
            end
            // 8byte的前半部分
            2:begin
                if (d_cache_status == `L_S_FINISHED)begin
                    case (task_type)
                        `MEM_CTR_LOAD:begin
                            current_addr <= current_addr+4;
                            if (visit_vector) begin
                                load_vector_data_slices[(current_length<<3)]   <= mem_data[7:0];
                                load_vector_data_slices[(current_length<<3)+1] <= mem_data[15:8];
                                load_vector_data_slices[(current_length<<3)+2] <= mem_data[23:16];
                                load_vector_data_slices[(current_length<<3)+3] <= mem_data[31:24];
                                CNT                                            <= 1;
                                cache_vis_signal                               <= `D_CACHE_LOAD;
                            end
                            else begin
                                scalar_data[DATA_LEN-1:0] <= mem_data;
                                CNT                       <= 1;
                                cache_vis_signal          <= `D_CACHE_LOAD;
                            end
                        end
                        `MEM_CTR_STORE:begin
                            current_addr <= current_addr+4;
                            if (visit_vector) begin
                                CNT                <= 1;
                                cache_vis_signal   <= `D_CACHE_STORE;
                                cache_written_data <= written_data2;
                            end
                            else begin
                                CNT                <= 1;
                                cache_vis_signal   <= `D_CACHE_STORE;
                                cache_written_data <= _written_scalar_data[SCALAR_REG_LEN-1:DATA_LEN]; // 64位数据前半部分
                            end
                        end
                        default:
                        $display("[ERROR]:unexpected task_type when cnt == 2 in memory controller\n");
                    endcase
                end
                else begin
                    CNT              <= 2;
                    cache_vis_signal <= `D_CACHE_NOP;
                    mem_vis_status   <= `MEM_CTR_STALL;
                end
            end
            // 工作中
            1:begin
                case (task_type)
                    `MEM_CTR_LOAD:begin
                        if (d_cache_status == `L_S_FINISHED) begin
                            if (visit_vector) begin
                                case(requested_data_type)
                                    `ONE_BIT:begin
                                        load_vector_mask_slices[current_length] <= mem_data[0];
                                        current_addr                            <= current_addr+1;
                                    end
                                    `ONE_BYTE:begin
                                        load_vector_data_slices[current_length] <= mem_data[7:0];
                                        current_addr                            <= current_addr+1;
                                    end
                                    `TWO_BYTE:begin
                                        load_vector_data_slices[((current_length)<<1)]   <= mem_data[7:0];
                                        load_vector_data_slices[((current_length)<<1)+1] <= mem_data[15:8];
                                        current_addr                                     <= current_addr+2;
                                    end
                                    `FOUR_BYTE:begin
                                        load_vector_data_slices[(current_length)<<2]     <= mem_data[7:0];
                                        load_vector_data_slices[((current_length)<<2)+1] <= mem_data[15:8];
                                        load_vector_data_slices[((current_length)<<2)+2] <= mem_data[23:16];
                                        load_vector_data_slices[((current_length)<<2)+3] <= mem_data[31:24];
                                        current_addr                                     <= current_addr+4;
                                    end
                                    `EIGHT_BYTE:begin
                                        load_vector_data_slices[(current_length<<3)+4] <= mem_data[7:0];
                                        load_vector_data_slices[(current_length<<3)+5] <= mem_data[15:8];
                                        load_vector_data_slices[(current_length<<3)+6] <= mem_data[23:16];
                                        load_vector_data_slices[(current_length<<3)+7] <= mem_data[31:24];
                                        current_addr                                   <= current_addr+4;
                                    end
                                    default:
                                    $display("[ERROR]:unexpected requested_data_type in mem ctr\n");
                                endcase
                                if (current_length+1 == requested_length)begin
                                    CNT              <= 0;
                                    mem_vis_status   <= `MEM_CTR_FINISHED;
                                    cache_vis_signal <= `D_CACHE_NOP;
                                end
                                else begin
                                    current_length <= current_length+1;
                                    // todo?
                                    CNT              <= 3;
                                    mem_vis_status   <= `MEM_CTR_WORKING;
                                    cache_vis_signal <= `D_CACHE_NOP;
                                end
                            end
                            else begin
                                if (requested_data_type == `EIGHT_BYTE)begin
                                    scalar_data[SCALAR_REG_LEN-1:DATA_LEN] <= mem_data;
                                end
                                else begin
                                    scalar_data <= {{32{mem_data[31]}},mem_data};
                                end
                                CNT              <= 0;
                                mem_vis_status   <= `MEM_CTR_FINISHED;
                                cache_vis_signal <= `D_CACHE_NOP;
                            end
                        end
                        else begin
                            CNT              <= 1;
                            cache_vis_signal <= `D_CACHE_NOP;
                            mem_vis_status   <= `MEM_CTR_STALL;
                        end
                    end
                    `MEM_CTR_STORE:begin
                        if (d_cache_status == `L_S_FINISHED)begin
                            if (!visit_vector||(current_length+1 == requested_length)) begin
                                CNT              <= 0;
                                mem_vis_status   <= `MEM_CTR_FINISHED;
                                cache_vis_signal <= `D_CACHE_NOP;
                            end
                            else begin
                                current_length   <= current_length+1;
                                cache_vis_signal <= `D_CACHE_NOP;
                                CNT              <= 3;
                                mem_vis_status   <= `MEM_CTR_WORKING;
                                case (requested_data_type)
                                    `EIGHT_BYTE:current_addr <= current_addr+4;
                                    `FOUR_BYTE:current_addr  <= current_addr+4;
                                    `TWO_BYTE:current_addr   <= current_addr+2;
                                    `ONE_BYTE:current_addr   <= current_addr+1;
                                    `ONE_BIT:current_addr    <= current_addr+1;
                                    default:
                                    $display("[ERROR]:unexpected data type when cnt == 1 in memory controller\n");
                                endcase
                            end
                        end
                        else begin
                            CNT              <= 1;
                            cache_vis_signal <= `D_CACHE_NOP;
                            mem_vis_status   <= `MEM_CTR_STALL;
                        end
                    end
                    default:
                    $display("[ERROR]:unexpected task_type when cnt == 1 in memory controller\n");
                endcase
            end
            // 工作完成或任务发布
            0:begin
                current_length   <= 0;
                cache_vis_signal <= `D_CACHE_NOP;
                // 空闲
                if (task_type == `MEM_CTR_REST) begin
                    if (mem_access_enabled) begin
                        visit_vector        <= is_vector;
                        requested_data_type <= mem_data_type;
                        current_addr        <= data_addr;
                        if (data_vis_signal == `MEM_CTR_NOP) begin
                            task_type      <= `MEM_CTR_LOAD; // 形式记号，todo：REST？
                            CNT            <= 0;
                            mem_vis_status <= `MEM_CTR_FINISHED;
                        end
                        else begin
                            task_type      <= data_vis_signal;
                            CNT            <= 3;
                            mem_vis_status <= `MEM_CTR_WORKING;
                            if (is_vector) begin
                                requested_length     <= length;
                                _vm                  <= vm;
                                _mask                <= mask;
                                _written_vector_data <= written_vector_data;
                            end
                            else begin
                                _written_scalar_data <= written_scalar_data;
                                requested_length     <= 1;
                            end
                        end
                    end
                end
                else begin
                    task_type      <= `MEM_CTR_REST;
                    mem_vis_status <= `MEM_CTR_RESTING;
                end
            end
            default:
            $display("[ERROR]:unexpected CNT in memory controller\n");
        endcase
    end
    
endmodule
    
