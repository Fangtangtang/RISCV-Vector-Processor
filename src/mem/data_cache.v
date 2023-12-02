// #############################################################################################################################
// DATA CACHE
// 
// 存放向量数据
// - 享有访存优先
// - read burst
// #############################################################################################################################
`include"src/defines.v"

module DATA_CACHE#(parameter ADDR_WIDTH = 17,
                   parameter LEN = 32,
                   parameter BYTE_SIZE = 8,
                   parameter VECTOR_SIZE = 8,
                   parameter ENTRY_INDEX_SIZE = 3,
                   parameter D_CACHE_SIZE = 1)
                  (input wire clk,
                   input [ADDR_WIDTH-1:0] data_addr,
                   input mem_access_enabled,
                   input [1:0] d_cache_vis_signal,
                   input [ENTRY_INDEX_SIZE-1:0] length,
                   output reg [LEN*VECTOR_SIZE-1:0] vector_data,
                   output reg [LEN*VECTOR_SIZE-1:0] writen_vector_data,
                   output reg [1:0] mem_vis_status,
                   input [LEN-1:0] mem_data,                            // interact with main memory
                   input [1:0] mem_status,
                   output reg [LEN-1:0] mem_writen_data,                // 写入memory的数据
                   output [ENTRY_INDEX_SIZE-1:0] write_length,
                   output [ADDR_WIDTH-1:0] mem_vis_addr,                // 访存地址
                   output reg [1:0] mem_vis_signal);
    
    reg [ADDR_WIDTH-1:0] starting_addr;
    reg valid[VECTOR_SIZE-1:0];
    reg [LEN-1:0] data[VECTOR_SIZE-1:0];
    
    wire [LEN*VECTOR_SIZE-1:0] _data;
    assign _data = {data[0],data[1],data[2],data[3],data[4],data[5],data[6],data[7]};
    wire [LEN-1:0] _writen_data[VECTOR_SIZE-1:0];
    assign _writen_data[0] = writen_vector_data[(VECTOR_SIZE-0)*LEN-1:(VECTOR_SIZE-1)*LEN];
    assign _writen_data[1] = writen_vector_data[(VECTOR_SIZE-1)*LEN-1:(VECTOR_SIZE-2)*LEN];
    assign _writen_data[2] = writen_vector_data[(VECTOR_SIZE-2)*LEN-1:(VECTOR_SIZE-3)*LEN];
    assign _writen_data[3] = writen_vector_data[(VECTOR_SIZE-3)*LEN-1:(VECTOR_SIZE-4)*LEN];
    assign _writen_data[4] = writen_vector_data[(VECTOR_SIZE-4)*LEN-1:(VECTOR_SIZE-5)*LEN];
    assign _writen_data[5] = writen_vector_data[(VECTOR_SIZE-5)*LEN-1:(VECTOR_SIZE-6)*LEN];
    assign _writen_data[6] = writen_vector_data[(VECTOR_SIZE-6)*LEN-1:(VECTOR_SIZE-7)*LEN];
    assign _writen_data[7] = writen_vector_data[(VECTOR_SIZE-7)*LEN-1:(VECTOR_SIZE-8)*LEN];
    
    
    reg [1:0] CNT = 0;
    reg [1:0] task_type;
    
    reg [ENTRY_INDEX_SIZE-1:0] _requested_length;
    
    reg [ENTRY_INDEX_SIZE-1:0] _current_index;
    reg [ADDR_WIDTH-1:0] _current_addr;
    
    assign mem_vis_addr = _current_addr;
    assign write_length = length;
    
    always @(posedge clk) begin
        case (CNT)
            // 等待开始工作
            2:begin
                case (mem_status)
                    `MEM_INST_WORKING:begin
                        CNT            <= 2;
                        mem_vis_signal <= `MEM_NOP;
                        mem_vis_status <= `D_CACHE_STALL;
                    end
                    `MEM_DATA_WORKING:begin
                        CNT            <= 2;
                        mem_vis_signal <= `MEM_NOP;
                        mem_vis_status <= `D_CACHE_STALL;
                    end
                    `MEM_RESTING:begin
                        CNT            <= 1;
                        mem_vis_status <= `D_CACHE_WORKING;
                        case (task_type)
                            `D_CACHE_LOAD:begin
                                mem_vis_signal <= `MEM_READ_BURST; // 批量读取
                            end
                            `D_CACHE_STORE:begin
                                mem_vis_signal  <= `MEM_WRITE;      // 批量写
                                mem_writen_data <= _writen_data[0]; // 第一个待写数据
                            end
                            default:
                            $display("[ERROR]:unexpected task_type when cnt == 2 in data cache\n");
                        endcase
                    end
                    default:
                    $display("[ERROR]:unexpected mem_status when cnt == 2 in data cache\n");
                endcase
            end
            // 工作中，处理mem数据，再次发起访存
            1:begin
                case (task_type)
                    `D_CACHE_LOAD:begin
                        data[_current_index]  <= mem_data;
                        valid[_current_index] <= 1;
                        // data burst未完成
                        if (_current_index+1 < VECTOR_SIZE) begin
                            _current_index <= _current_index + 1;
                            CNT            <= 1;
                            mem_vis_signal <= `MEM_READ_BURST;
                            // 需要的数据已经取到
                            if (_current_index+1 == _requested_length) begin
                                vector_data    <= _data; // todo:要不要只取length个
                                mem_vis_status <= `L_S_FINISHED;
                            end
                            else begin
                                mem_vis_status <= `D_CACHE_WORKING;
                            end
                        end
                        // data burst完成
                        else begin
                            CNT <= 0;
                            // 需要的数据已经取到
                            if (_current_index+1 == _requested_length) begin
                                vector_data    <= _data; // todo:要不要只取length个
                                mem_vis_status <= `L_S_FINISHED;
                            end
                            else begin
                                mem_vis_signal <= `MEM_NOP;
                                mem_vis_status <= `D_CACHE_RESTING;
                            end
                        end
                    end
                    `D_CACHE_STORE:begin
                        // 未结束
                        if (_current_index+1 < VECTOR_SIZE)begin
                            _current_index  <= _current_index + 1;
                            mem_writen_data <= _writen_data[_current_index+1];
                            CNT             <= 1;
                            mem_vis_signal  <= `MEM_WRITE;
                            mem_vis_status  <= `D_CACHE_WORKING;
                        end
                        // 结束
                        else begin
                            CNT            <= 0;
                            mem_vis_status <= `L_S_FINISHED;
                            mem_vis_signal <= `MEM_NOP;
                        end
                    end
                    default:
                    $display("[ERROR]:unexpected task_type when cnt == 1 in data cache\n");
                endcase
            end
            // 工作完成或任务发布
            0:begin
                mem_vis_signal <= `MEM_NOP;
                // data cache处于空闲状态
                if (task_type == `D_CACHE_REST) begin
                    if (mem_access_enabled) begin
                        task_type <= d_cache_vis_signal;
                        case (d_cache_vis_signal)
                            `D_CACHE_NOP:begin
                                CNT            <= 0;
                                mem_vis_status <= `L_S_FINISHED;
                            end
                            `D_CACHE_LOAD:begin
                                // hit(可以进一步优化)
                                if (data_addr == starting_addr&&valid[length-1]) begin
                                    vector_data    <= _data; // todo:要不要只取length个
                                    CNT            <= 0;
                                    mem_vis_status <= `L_S_FINISHED;
                                end
                                else begin
                                    CNT               <= 2;
                                    mem_vis_status    <= `D_CACHE_WORKING;
                                    _requested_length <= length;
                                    starting_addr     <= data_addr;
                                    _current_addr     <= data_addr;
                                    _current_index    <= 0;
                                    for (integer i = 0;i < VECTOR_SIZE;i = i + 1) begin
                                        valid[i] <= 0;
                                    end
                                end
                            end
                            `D_CACHE_STORE:begin
                                CNT               <= 2;
                                mem_vis_status    <= `D_CACHE_WORKING;
                                _requested_length <= length;
                                starting_addr     <= data_addr;
                                _current_addr     <= data_addr;
                                _current_index    <= 0;
                                // update cache
                                for (integer i = 0;i < length;i = i + 1) begin
                                    valid[i] <= 1;
                                    data[i]  <= _writen_data[i];
                                end
                                for (integer i = length;i < VECTOR_SIZE;i = i + 1) begin
                                    valid[i] <= 0;
                                end
                            end
                            default:
                            $display("[ERROR]:unexpected vis_signal in data cache\n");
                        endcase
                    end
                end
                else begin
                    task_type      <= `D_CACHE_REST;
                    mem_vis_status <= `D_CACHE_RESTING;
                end
            end
            default:
            $display("[ERROR]:unexpected cnt in data cache\n");
        endcase
    end
    
endmodule
