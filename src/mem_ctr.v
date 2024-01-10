// #############################################################################################################################
// MEMORY CONTROLER
// 
// 控制数据访存
// 连接core和data cache
// 
// - core发来标量或向量访存请求，由memory controler拆成数据类型+首地址访存
// | + 标量访存照常
// | + 带mask的向量访存，仅load/store被激活的数据位
// |   load未激活部分用默认数值0填充，write back带mask
// 
// - 未激活，快进；发向cache的地址hit（组合逻辑实现），快进
// 
// todo: mask的load，被mask部分用0替换？
// todo: data cache hit?
// #############################################################################################################################
`include"src/defines.v"

module MEMORY_CONTROLER#(parameter ADDR_WIDTH = 17,
                         parameter LEN = 32,
                         parameter BYTE_SIZE = 8,
                         parameter VECTOR_SIZE = 8,
                         parameter ENTRY_INDEX_SIZE = 3,
                         parameter CACHE_SIZE = 16,
                         parameter CACHE_INDEX_SIZE = 4)
                        (input wire clk,
                         input [ADDR_WIDTH-1:0] data_addr,
                         input mem_access_enabled,
                         input is_vector,                                 // 是否为向量访存
                         input [1:0] data_vis_signal,
                         input[2:0] mem_data_type,
                         input [ENTRY_INDEX_SIZE:0] length,
                         input vm,
                         input [LEN*VECTOR_SIZE-1:0] mask,                // 向量访存掩码
                         output reg [LEN-1:0] scalar_data,
                         output [LEN*VECTOR_SIZE-1:0] vector_data,
                         input [LEN-1:0] written_scalar_data,
                         input [LEN*VECTOR_SIZE-1:0] written_vector_data,
                         output reg [1:0] mem_vis_status,                 // interact with data cache
                         input [LEN-1:0] mem_data,
                         input [1:0] d_cache_status,
                         output reg [LEN-1:0] cache_written_data,         // 写入memory的数据
                         output [ENTRY_INDEX_SIZE:0] write_length,        // 1:单个数
                         output [ADDR_WIDTH-1:0] mem_vis_addr,            // 访存地址
                         output [2:0] d_cache_data_type,                  // 数据类型（包括标量向量）
                         output reg [1:0] cache_vis_signal);
    
    reg [1:0]                   CNT = 0;
    reg [1:0]                   task_type;
    
    reg _vm;
    reg [LEN*VECTOR_SIZE-1:0] _mask;
    
    reg                         visit_vector;
    reg [2:0]                   requested_data_type;
    reg [ADDR_WIDTH-1:0]        current_addr;
    reg [ENTRY_INDEX_SIZE:0]    requested_length;
    reg [ENTRY_INDEX_SIZE:0]    current_length;
    reg [LEN-1:0]               _written_scalar_data;
    reg [LEN*VECTOR_SIZE-1:0]   _written_vector_data;
    
    wire [BYTE_SIZE-1:0] _written_vector_data_slices [0:LEN*VECTOR_SIZE/BYTE_SIZE-1];
    
    genvar i;
    for (i = 0;i<LEN*VECTOR_SIZE/BYTE_SIZE;i = i+1) begin
        assign _written_vector_data_slices[i] = _written_vector_data[BYTE_SIZE*(i+1)-1:BYTE_SIZE*i];
    end
    
    reg [LEN-1:0] written_data;
    always @(*) begin
        case(requested_data_type)
            `ONE_BYTE:begin
                written_data = {24'b0,_written_vector_data_slices[current_length]};
            end
            `TWO_BYTE:begin
                written_data = {16'b0,_written_vector_data_slices[current_length<<1+1],_written_vector_data_slices[current_length<<1]};
            end
            `FOUR_BYTE:begin
                written_data = {_written_vector_data_slices[current_length<<2+3],_written_vector_data_slices[current_length<<2+2],_written_vector_data_slices[current_length<<2+1],_written_vector_data_slices[current_length<<2]};
            end
            default:
            $display("[ERROR]:unexpected requested_data_type in mem ctr\n");
        endcase
    end
    
    wire [LEN*VECTOR_SIZE-1:0]   load_vector_data; // 存要读取的vector
    assign vector_data = load_vector_data;
    reg [BYTE_SIZE-1:0] load_vector_data_slices [0:LEN*VECTOR_SIZE/BYTE_SIZE-1];
    
    for (i = 0;i<LEN*VECTOR_SIZE/BYTE_SIZE;i = i+1) begin
        assign load_vector_data[(i+1)*8 - 1 : i*8] = load_vector_data_slices[i];
    end
    
    assign d_cache_data_type = requested_data_type;
    
    always @(posedge clk) begin
        case (CNT)
            // 等待开始工作
            2:begin
                if (d_cache_status == `D_CACHE_RESTING)begin
                    CNT            <= 1;
                    mem_vis_status <= `MEM_WORKING;
                    case (task_type)
                        `MEM_CTR_LOAD:begin
                            if (!visit_vector||(_mask[current_length]||_vm))begin
                                cache_vis_signal <= `D_CACHE_LOAD;
                            end
                            else begin
                                cache_vis_signal <= `D_CACHE_NOP;
                            end
                            current_length <= current_length+1;
                        end
                        `MEM_CTR_STORE:begin
                            cache_vis_signal <= `D_CACHE_STORE;
                            if (visit_vector) begin
                                if (_mask[current_length]||_vm)begin
                                    cache_vis_signal <= `D_CACHE_STORE;
                                end
                                else begin
                                    cache_vis_signal <= `D_CACHE_NOP;
                                end
                                cache_written_data <= written_data; // 第一个待写数据
                                current_length     <= current_length+1;
                            end
                            else begin
                                cache_vis_signal   <= `D_CACHE_STORE;
                                cache_written_data <= _written_scalar_data;
                            end
                        end
                        default:
                        $display("[ERROR]:unexpected task_type when cnt == 2 in memory controler\n");
                    endcase
                end
                else begin
                    CNT              <= 2;
                    cache_vis_signal <= `D_CACHE_NOP;
                    mem_vis_status   <= `MEM_STALL;
                end
            end
            // 工作中
            1:begin
                case (task_type)
                    `MEM_CTR_LOAD:begin
                        if (d_cache_status == `L_S_FINISHED) begin
                            if (visit_vector) begin
                                case(requested_data_type)
                                    `ONE_BYTE:begin
                                        load_vector_data_slices[current_length-1] <= mem_data[7:0];
                                    end
                                    `TWO_BYTE:begin
                                        load_vector_data_slices[(current_length-1)<<1]   <= mem_data[7:0];
                                        load_vector_data_slices[(current_length-1)<<1+1] <= mem_data[15:8];
                                    end
                                    `FOUR_BYTE:begin
                                        load_vector_data_slices[(current_length-1)<<2]   <= mem_data[7:0];
                                        load_vector_data_slices[(current_length-1)<<2+1] <= mem_data[15:8];
                                        load_vector_data_slices[(current_length-1)<<2+2] <= mem_data[23:16];
                                        load_vector_data_slices[(current_length-1)<<2+3] <= mem_data[31:24];
                                    end
                                    default:
                                    $display("[ERROR]:unexpected requested_data_type in mem ctr\n");
                                endcase
                                if (current_length+1 == requested_length)begin
                                    CNT              <= 0;
                                    mem_vis_status   <= `MEM_FINISHED;
                                    cache_vis_signal <= `D_CACHE_NOP;
                                end
                            end
                            else begin
                                scalar_data      <= mem_data;
                                CNT              <= 0;
                                mem_vis_status   <= `MEM_FINISHED;
                                cache_vis_signal <= `D_CACHE_NOP;
                            end
                        end
                        if (d_cache_status == `D_CACHE_RESTING)begin
                            if (visit_vector) begin
                                // 未结束
                                if (current_length+1 < requested_length)begin
                                    current_length <= current_length+1;
                                    CNT            <= 1;
                                    mem_vis_status <= `MEM_WORKING;
                                    if (_mask[current_length]||_vm)begin
                                        cache_vis_signal <= `D_CACHE_LOAD;
                                    end
                                    else begin
                                        cache_vis_signal <= `D_CACHE_NOP;
                                    end
                                end
                            end
                        end
                    end
                    `MEM_CTR_STORE:begin
                        if (d_cache_status == `L_S_FINISHED)begin
                            if (!visit_vector||(current_length+1 == requested_length)) begin
                                CNT              <= 0;
                                mem_vis_status   <= `MEM_FINISHED;
                                cache_vis_signal <= `D_CACHE_NOP;
                            end
                        end
                        if (d_cache_status == `D_CACHE_RESTING)begin
                            if (visit_vector&&(current_length+1 < requested_length)) begin
                                // 未结束
                                cache_written_data <= written_data;
                                current_length     <= current_length+1;
                                CNT                <= 1;
                                mem_vis_status     <= `MEM_WORKING;
                                if (_mask[current_length]||_vm)begin
                                    cache_vis_signal <= `D_CACHE_STORE;
                                end
                                else begin
                                    cache_vis_signal <= `D_CACHE_NOP;
                                end
                            end
                        end
                    end
                    default:
                    $display("[ERROR]:unexpected task_type when cnt == 1 in memory controler\n");
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
                        task_type           <= data_vis_signal;
                        requested_data_type <= mem_data_type;
                        current_addr        <= data_addr;
                        if (data_vis_signal == `MEM_CTR_NOP) begin
                            CNT            <= 0;
                            mem_vis_status <= `MEM_FINISHED;
                            end else begin
                                CNT            <= 2;
                                mem_vis_status <= `MEM_WORKING;
                                if (is_vector) begin
                                    requested_length     <= length;
                                    _vm                  <= vm;
                                    _mask                <= mask;
                                    _written_scalar_data <= written_scalar_data;
                                    _written_vector_data <= written_vector_data;
                                end
                                else begin
                                    requested_length <= 1;
                                end
                            end
                        end
                    end
                    else begin
                        task_type      <= `MEM_CTR_REST;
                        mem_vis_status <= `MEM_RESTING;
                    end
                end
                default:
                $display("[ERROR]:unexpected CNT in memory controler\n");
        endcase
    end
    
endmodule
    
