// #############################################################################################################################
// DATA CACHE
// 
// 直接映射write through cache
// cache line为4byte
// 
// 接受来自memory controller的访存请求
// - load:组合逻辑判断是否hit并反馈
// |      如果miss，向memory发请求
// - store:组合逻辑判断是否hit
// |       如果hit，修改cache，否则直接写内存
// 
// cache中数据保持memory中顺序
// 传出数据时转为正常顺序
// #############################################################################################################################
`include"src/defines.v"

module DATA_CACHE#(parameter ADDR_WIDTH = 20,
                   parameter DATA_LEN = 32,
                   parameter BYTE_SIZE = 8,
                   parameter VECTOR_SIZE = 8,
                   parameter ENTRY_INDEX_SIZE = 3,
                   parameter CACHE_SIZE = 16,
                   parameter CACHE_INDEX_SIZE = 4)
                  (input wire clk,
                   input [ADDR_WIDTH-1:0] data_addr,
                   input [2:0] data_type,                      // vsew
                   input [DATA_LEN-1:0] cache_written_data,
                   input [1:0] cache_vis_signal,
                   input [ENTRY_INDEX_SIZE:0] length,          // 1：单个
                   output cache_hit,
                   output reg [DATA_LEN-1:0] data,
                   output reg [1:0] d_cache_vis_status,
                   input [DATA_LEN-1:0] mem_data,
                   input [1:0] mem_status,
                   output reg [DATA_LEN-1:0] mem_written_data,
                   output reg [2:0] written_data_type,
                   output [ENTRY_INDEX_SIZE:0] write_length,   // 1：单个
                   output reg [ADDR_WIDTH-1:0] mem_vis_addr,   // 访存地址
                   output reg [1:0] mem_vis_signal);
    
    localparam BYTE_SELECT     = 2;
    localparam CACHE_LINE_SIZE = 1<<BYTE_SELECT;
    localparam TAG_SIZE        = ADDR_WIDTH - CACHE_INDEX_SIZE - BYTE_SELECT;
    
    // 缓存数据
    reg valid [CACHE_SIZE-1:0];
    reg [TAG_SIZE-1:0] tag [CACHE_SIZE-1:0];
    reg [DATA_LEN-1:0] data_line [CACHE_SIZE-1:0]; // 一个cache line
    
    wire [DATA_LEN-1:0] storage0Value  = data_line[0];
    wire [DATA_LEN-1:0] storage1Value  = data_line[1];
    wire [DATA_LEN-1:0] storage2Value  = data_line[2];
    wire [DATA_LEN-1:0] storage3Value  = data_line[3];
    wire [DATA_LEN-1:0] storage4Value  = data_line[4];
    wire [DATA_LEN-1:0] storage5Value  = data_line[5];
    wire [DATA_LEN-1:0] storage6Value  = data_line[6];
    wire [DATA_LEN-1:0] storage7Value  = data_line[7];
    wire [DATA_LEN-1:0] storage8Value  = data_line[8];
    wire [DATA_LEN-1:0] storage9Value  = data_line[9];
    wire [DATA_LEN-1:0] storage10Value = data_line[10];
    wire [DATA_LEN-1:0] storage11Value = data_line[11];
    wire [DATA_LEN-1:0] storage12Value = data_line[12];
    wire [DATA_LEN-1:0] storage13Value = data_line[13];
    wire [DATA_LEN-1:0] storage14Value = data_line[14];
    wire [DATA_LEN-1:0] storage15Value = data_line[15];
    
    wire [TAG_SIZE-1:0] storage0Tag  = tag[0];
    wire [TAG_SIZE-1:0] storage1Tag  = tag[1];
    wire [TAG_SIZE-1:0] storage2Tag  = tag[2];
    wire [TAG_SIZE-1:0] storage3Tag  = tag[3];
    wire [TAG_SIZE-1:0] storage4Tag  = tag[4];
    wire [TAG_SIZE-1:0] storage5Tag  = tag[5];
    wire [TAG_SIZE-1:0] storage6Tag  = tag[6];
    wire [TAG_SIZE-1:0] storage7Tag  = tag[7];
    wire [TAG_SIZE-1:0] storage8Tag  = tag[8];
    wire [TAG_SIZE-1:0] storage9Tag  = tag[9];
    wire [TAG_SIZE-1:0] storage10Tag = tag[10];
    wire [TAG_SIZE-1:0] storage11Tag = tag[11];
    wire [TAG_SIZE-1:0] storage12Tag = tag[12];
    wire [TAG_SIZE-1:0] storage13Tag = tag[13];
    wire [TAG_SIZE-1:0] storage14Tag = tag[14];
    wire [TAG_SIZE-1:0] storage15Tag = tag[15];

    wire [TAG_SIZE-1:0] addr_tag                 = data_addr[ADDR_WIDTH-1:CACHE_INDEX_SIZE+BYTE_SELECT];
    wire [CACHE_INDEX_SIZE-1:0] cache_line_index = data_addr[CACHE_INDEX_SIZE+BYTE_SELECT-1:BYTE_SELECT];
    wire [BYTE_SELECT-1:0] select_bit            = data_addr[BYTE_SELECT-1:0];
    
    // + load hit判断
    // 单字节
    wire byte_load_hit = valid[cache_line_index]&&tag[cache_line_index] == addr_tag;
    // 半字
    wire half_word_load_hit = valid[cache_line_index]&&tag[cache_line_index] == addr_tag&&(select_bit+1<CACHE_LINE_SIZE||(valid[(cache_line_index+1)%CACHE_SIZE]&&tag[(cache_line_index+1)%CACHE_SIZE] == addr_tag));
    // 全字
    wire word_load_hit = valid[cache_line_index]&&tag[cache_line_index] == addr_tag&&(select_bit+3<CACHE_LINE_SIZE|| (valid[(cache_line_index+1)%CACHE_SIZE]&&tag[(cache_line_index+1)%CACHE_SIZE] == addr_tag));
    // 如果所要的数据都有，hit
    // EIGHT_BYTE被拆解为2个4byte
    wire load_hit    = (data_type == `ONE_BYTE&&byte_load_hit)||(data_type == `TWO_BYTE&&half_word_load_hit)||(data_type == `FOUR_BYTE&&word_load_hit)||(data_type == `EIGHT_BYTE&&word_load_hit);
    assign cache_hit = load_hit;
    
    assign write_length = length;
    
    // 接线取数据（从请求地址开始取字节，转为正常顺序）
    reg [DATA_LEN-1:0]          direct_data;
    
    reg [BYTE_SIZE-1:0]         direct_byte ;
    reg [2*BYTE_SIZE-1:0]       direct_half_word;
    reg [DATA_LEN-1:0]          direct_word;
    
    reg [DATA_LEN-1:0]          indirect_data;
    
    reg [BYTE_SIZE-1:0]         indirect_byte ;
    reg [2*BYTE_SIZE-1:0]       indirect_half_word;
    reg [DATA_LEN-1:0]          indirect_word;
    
    always @(*) begin
        case (select_bit)
            0:begin
                direct_byte      = data_line[cache_line_index][31:24];
                direct_half_word = data_line[cache_line_index][31:16];
                direct_word      = data_line[cache_line_index][31:0];
            end
            1:begin
                direct_byte      = data_line[cache_line_index][23:16];
                direct_half_word = data_line[cache_line_index][23:8];
                direct_word      = {data_line[cache_line_index][23:0],data_line[(cache_line_index+1)%CACHE_SIZE][31:24]};
            end
            2:begin
                direct_byte      = data_line[cache_line_index][15:8];
                direct_half_word = data_line[cache_line_index][15:0];
                direct_word      = {data_line[cache_line_index][15:0],data_line[(cache_line_index+1)%CACHE_SIZE][31:16]};
            end
            3:begin
                direct_byte      = data_line[cache_line_index][7:0];
                direct_half_word = {data_line[cache_line_index][7:0],data_line[(cache_line_index+1)%CACHE_SIZE][31:24]};
                direct_word      = {data_line[cache_line_index][7:0],data_line[(cache_line_index+1)%CACHE_SIZE][31:8]};
            end
            default:
            $display("[ERROR]:unexpected select_bit in data cache\n");
        endcase
    end
    
    always @(*) begin
        case(data_type)
            `ONE_BYTE:begin
                direct_data = {{24{direct_byte[BYTE_SIZE-1]}},direct_byte};
            end
            `TWO_BYTE:begin
                direct_data = {{16{direct_half_word[BYTE_SIZE-1]}},direct_half_word[BYTE_SIZE-1:0],direct_half_word[2*BYTE_SIZE-1:BYTE_SIZE]};
            end
            `FOUR_BYTE:begin
                direct_data = {direct_word[BYTE_SIZE-1:0],direct_word[2*BYTE_SIZE-1:BYTE_SIZE],direct_word[3*BYTE_SIZE-1:2*BYTE_SIZE],direct_word[4*BYTE_SIZE-1:3*BYTE_SIZE]};
            end
            `EIGHT_BYTE:begin
                direct_data = {direct_word[BYTE_SIZE-1:0],direct_word[2*BYTE_SIZE-1:BYTE_SIZE],direct_word[3*BYTE_SIZE-1:2*BYTE_SIZE],direct_word[4*BYTE_SIZE-1:3*BYTE_SIZE]};
            end
            default:
            $display("[ERROR]:unexpected data type in data cache\n");
        endcase
    end
    
    always @(*) begin
        case (load_select_bit)
            0:begin
                indirect_byte      = data_line[load_cache_line_index][31:24];
                indirect_half_word = data_line[load_cache_line_index][31:16];
                indirect_word      = data_line[load_cache_line_index][31:0];
            end
            1:begin
                indirect_byte      = data_line[load_cache_line_index][23:16];
                indirect_half_word = data_line[load_cache_line_index][23:8];
                indirect_word      = {data_line[load_cache_line_index][23:0],data_line[(load_cache_line_index+1)%CACHE_SIZE][31:24]};
            end
            2:begin
                indirect_byte      = data_line[load_cache_line_index][15:8];
                indirect_half_word = data_line[load_cache_line_index][15:0];
                indirect_word      = {data_line[load_cache_line_index][15:0],data_line[(load_cache_line_index+1)%CACHE_SIZE][31:16]};
            end
            3:begin
                indirect_byte      = data_line[load_cache_line_index][7:0];
                indirect_half_word = {data_line[load_cache_line_index][7:0],data_line[(load_cache_line_index+1)%CACHE_SIZE][31:24]};
                indirect_word      = {data_line[load_cache_line_index][7:0],data_line[(load_cache_line_index+1)%CACHE_SIZE][31:8]};
            end
            default:
            $display("[ERROR]:unexpected load_select_bit in data cache\n");
        endcase
    end
    
    always @(*) begin
        case(requested_data_type)
            `ONE_BYTE:begin
                indirect_data = {{24{indirect_byte[BYTE_SIZE-1]}},indirect_byte};
            end
            `TWO_BYTE:begin
                indirect_data = {{16{indirect_half_word[BYTE_SIZE-1]}},indirect_half_word[BYTE_SIZE-1:0],indirect_half_word[2*BYTE_SIZE-1:BYTE_SIZE]};
            end
            `FOUR_BYTE:begin
                indirect_data = {indirect_word[BYTE_SIZE-1:0],indirect_word[2*BYTE_SIZE-1:BYTE_SIZE],indirect_word[3*BYTE_SIZE-1:2*BYTE_SIZE],indirect_word[4*BYTE_SIZE-1:3*BYTE_SIZE]};
            end
            `EIGHT_BYTE:begin
                indirect_data = {indirect_word[BYTE_SIZE-1:0],indirect_word[2*BYTE_SIZE-1:BYTE_SIZE],indirect_word[3*BYTE_SIZE-1:2*BYTE_SIZE],indirect_word[4*BYTE_SIZE-1:3*BYTE_SIZE]};
            end
            default:
            $display("[ERROR]:unexpected requested data type in data cache\n");
        endcase
    end
    
    // + store hit判断
    // 最多有效字节数4
    // 内存+cache中：[b1][b2][b3][b4]
    // 真实数据中:   [b4][b3][b2][b1]
    // 第一个字节
    wire byte1_store_hit = valid[cache_line_index]&&tag[cache_line_index] == addr_tag;
    // 第二个字节
    wire byte2_store_hit = (valid[cache_line_index]&&tag[cache_line_index] == addr_tag&&select_bit+1<CACHE_LINE_SIZE)||(valid[(cache_line_index+1)%CACHE_SIZE]&&tag[(cache_line_index+1)%CACHE_SIZE] == addr_tag);
    // 第三个字节
    wire byte3_store_hit = (valid[cache_line_index]&&tag[cache_line_index] == addr_tag&&select_bit+2<CACHE_LINE_SIZE)||(valid[(cache_line_index+1)%CACHE_SIZE]&&tag[(cache_line_index+1)%CACHE_SIZE] == addr_tag);
    // 第四个字节
    wire byte4_store_hit = (valid[cache_line_index]&&tag[cache_line_index] == addr_tag&&select_bit+3<CACHE_LINE_SIZE)||(valid[(cache_line_index+1)%CACHE_SIZE]&&tag[(cache_line_index+1)%CACHE_SIZE] == addr_tag);
    
    // 转为内存顺序的数据
    reg [DATA_LEN-1:0] written_data;
    reg [DATA_LEN-1:0] requested_written_data;
    always @(*) begin
        case(requested_data_type)
            `ONE_BYTE:begin
                written_data = {cache_written_data[7:0],24'b0};
            end
            `TWO_BYTE:begin
                written_data = {cache_written_data[7:0],cache_written_data[15:8],16'b0};
            end
            `FOUR_BYTE:begin
                written_data = {cache_written_data[7:0],cache_written_data[15:8],cache_written_data[23:16],cache_written_data[31:24]};
            end
            `EIGHT_BYTE:begin
                written_data = {cache_written_data[7:0],cache_written_data[15:8],cache_written_data[23:16],cache_written_data[31:24]};
            end
            default:
            $display("[ERROR]:unexpected data type in data cache\n");
        endcase
    end
    
    reg [2:0] requested_data_type;
    reg [ADDR_WIDTH-1:0] load_addr;     // 待加载部分
    reg [ADDR_WIDTH-1:0] _current_addr; // 访存使用地址
    
    wire [TAG_SIZE-1:0] load_addr_tag                  = load_addr[ADDR_WIDTH-1:CACHE_INDEX_SIZE+BYTE_SELECT];
    wire [CACHE_INDEX_SIZE-1:0] load_cache_line_index  = load_addr[CACHE_INDEX_SIZE+BYTE_SELECT-1:BYTE_SELECT];
    wire [BYTE_SELECT-1:0] load_select_bit             = load_addr[BYTE_SELECT-1:0];
    wire [TAG_SIZE-1:0] extra_addr_tag                 = _current_addr[ADDR_WIDTH-1:CACHE_INDEX_SIZE+BYTE_SELECT];
    wire [CACHE_INDEX_SIZE-1:0] extra_cache_line_index = _current_addr[CACHE_INDEX_SIZE+BYTE_SELECT-1:BYTE_SELECT];
    
    
    reg [2:0] CNT = 0;
    reg [1:0] task_type;
    
    always @(posedge clk) begin
        case(CNT)
            // 等待开始工作
            4:begin
                if (mem_status == `MEM_RESTING) begin
                    d_cache_vis_status <= `D_CACHE_WORKING;
                    case (task_type)
                        `D_CACHE_LOAD:begin
                            CNT            <= 3;
                            mem_vis_signal <= `MEM_READ; // 读取单个数据
                            mem_vis_addr   <= {_current_addr[ADDR_WIDTH-1:BYTE_SELECT],{BYTE_SELECT{1'b0}}};
                            _current_addr  <= _current_addr+CACHE_LINE_SIZE;
                        end
                        `D_CACHE_STORE:begin
                            CNT               <= 1;
                            mem_vis_signal    <= `MEM_WRITE;
                            mem_vis_addr      <= _current_addr;
                            mem_written_data  <= requested_written_data;
                            written_data_type <= requested_data_type;
                        end
                        default:
                        $display("[ERROR]:unexpected task_type when cnt == 4 in data cache\n");
                    endcase
                end
                else begin
                    CNT                <= 4;
                    d_cache_vis_status <= `D_CACHE_STALL;
                end
            end
            // load等一周期
            3:begin
                if (mem_status == `MEM_DATA_FINISHED) begin
                    CNT                              <= 2;
                    mem_vis_signal                   <= `MEM_NOP;
                    valid[load_cache_line_index]     <= 1;
                    tag[load_cache_line_index]       <= load_addr_tag;
                    data_line[load_cache_line_index] <= mem_data;
                end
                else begin
                    CNT                <= 3;
                    d_cache_vis_status <= `D_CACHE_STALL;
                end
            end
            // 工作中，处理mem数据，再次发起访存
            // load:一次要填充两个cache line，再从cache line中取数据
            2:begin
                CNT            <= 1;
                mem_vis_signal <= `MEM_READ; // 读取单个数据
                mem_vis_addr   <= {_current_addr[ADDR_WIDTH-1:BYTE_SELECT],{BYTE_SELECT{1'b0}}};
            end
            // 工作中，处理mem数据
            // load:填充两个cache line
            // store:直接向内存指定位置写该数据
            1:begin
                if (mem_status == `MEM_DATA_FINISHED) begin
                    CNT                <= 0;
                    mem_vis_signal     <= `MEM_NOP;
                    d_cache_vis_status <= `L_S_FINISHED;
                    case (task_type)
                        `D_CACHE_LOAD:begin
                            valid[extra_cache_line_index]     <= 1;
                            tag[extra_cache_line_index]       <= extra_addr_tag;
                            data_line[extra_cache_line_index] <= mem_data;
                            data                              <= indirect_data;
                        end
                        `D_CACHE_STORE:begin
                            // todo?
                        end
                        default:
                        $display("[ERROR]:unexpected task_type when cnt == 1 in data cache\n");
                    endcase
                end
                else begin
                    CNT                <= 1;
                    d_cache_vis_status <= `D_CACHE_STALL;
                end
            end
            // 工作完成或任务发布
            0:begin
                mem_vis_signal <= `MEM_NOP;
                // data cache处于空闲状态，开启新任务
                if (task_type == `D_CACHE_REST) begin
                    requested_data_type <= data_type;
                    case (cache_vis_signal)
                        `D_CACHE_NOP:begin
                            task_type          <= `D_CACHE_REST;
                            CNT                <= 0;
                            d_cache_vis_status <= `D_CACHE_RESTING;
                        end
                        // 都表现为
                        `D_CACHE_LOAD:begin
                            if (load_hit)begin
                                task_type          <= `D_CACHE_LOAD; // 形式记号，todo：D_CACHE_REST？
                                data               <= direct_data;
                                CNT                <= 0;
                                d_cache_vis_status <= `L_S_FINISHED;
                            end
                            else begin
                                task_type          <= `D_CACHE_LOAD;
                                CNT                <= 4;
                                d_cache_vis_status <= `D_CACHE_WORKING;
                                _current_addr      <= data_addr;
                                load_addr          <= data_addr;
                            end
                        end
                        `D_CACHE_STORE:begin
                            // 修改cache line
                            // 内存+cache中：[b1][b2][b3][b4]
                            // 真实数据中:   [b4][b3][b2][b1]
                            // [b1] hit
                            if (byte1_store_hit) begin
                                case (select_bit)
                                    0:data_line[cache_line_index][31:24] <= cache_written_data[7:0];
                                    1:data_line[cache_line_index][23:16] <= cache_written_data[7:0];
                                    2:data_line[cache_line_index][15:8]  <= cache_written_data[7:0];
                                    3:data_line[cache_line_index][7:0]   <= cache_written_data[7:0];
                                endcase
                            end
                            // [b2] hit
                            if (byte2_store_hit&&(!(data_type == `ONE_BYTE))) begin
                                case (select_bit)
                                    0:data_line[cache_line_index][23:16]                <= cache_written_data[15:8];
                                    1:data_line[cache_line_index][15:8]                 <= cache_written_data[15:8];
                                    2:data_line[cache_line_index][7:0]                  <= cache_written_data[15:8];
                                    3:data_line[(cache_line_index+1)%CACHE_SIZE][31:24] <= cache_written_data[15:8];
                                endcase
                            end
                            // [b3] hit
                            if (byte3_store_hit&&(data_type == `FOUR_BYTE||data_type == `EIGHT_BYTE)) begin
                                case (select_bit)
                                    0:data_line[cache_line_index][15:8]                 <= cache_written_data[23:16];
                                    1:data_line[cache_line_index][7:0]                  <= cache_written_data[23:16];
                                    2:data_line[(cache_line_index+1)%CACHE_SIZE][31:24] <= cache_written_data[23:16];
                                    3:data_line[(cache_line_index+1)%CACHE_SIZE][23:16] <= cache_written_data[23:16];
                                endcase
                            end
                            // [b4] hit
                            if (byte4_store_hit&&(data_type == `FOUR_BYTE||data_type == `EIGHT_BYTE)) begin
                                case (select_bit)
                                    0:data_line[cache_line_index][7:0]                  <= cache_written_data[31:24];
                                    1:data_line[(cache_line_index+1)%CACHE_SIZE][31:24] <= cache_written_data[31:24];
                                    2:data_line[(cache_line_index+1)%CACHE_SIZE][23:16] <= cache_written_data[31:24];
                                    3:data_line[(cache_line_index+1)%CACHE_SIZE][15:8]  <= cache_written_data[31:24];
                                endcase
                            end
                            requested_written_data <= written_data;
                            task_type              <= `D_CACHE_STORE;
                            CNT                    <= 4;
                            d_cache_vis_status     <= `D_CACHE_WORKING;
                            _current_addr          <= data_addr;
                        end
                        default:
                        $display("[ERROR]:unexpected cache_vis_signal in data cache\n");
                    endcase
                end
                else begin
                    task_type          <= `D_CACHE_REST;
                    d_cache_vis_status <= `D_CACHE_RESTING;
                end
            end
            default:
            $display("[ERROR]:unexpected cnt in data cache\n");
        endcase
    end
endmodule
