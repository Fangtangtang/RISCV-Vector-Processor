// #############################################################################################################################
// DEFINE
// 
// 为二进制编码重命名，增加可读性
// #############################################################################################################################

// logic
`define     FALSE               1'b0
`define     TRUE                1'b1

// sign bit
`define     ZERO                2'b00
`define     POS                 2'b01
`define     NEG                 2'b11

// IMPLEMENTATION-DEFINED CONSTANT PARAMETERS
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// maximum size in bits of a vector element
`define     ELEN                32
// number of bits in a single vector register
`define     VLEN                256

// CSR
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// - VSEW     [2:0]
// | dynamic selected element width
// | By default, a vector register is viewed as being divided into VLEN/SEW elements
// - 访存数据类型
`define     ONE_BYTE            3'b000
`define     TWO_BYTE            3'b001
`define     FOUR_BYTE           3'b010
`define     EIGHT_BYTE          3'b011 

`define     NOT_ACCESS          3'b100

`define     ONE_BIT             3'b111

// SIGNAL
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

// MAIN Memory
// -------------------------------------------------------------------------
// task type
`define     MEM_NOP             2'b00
`define     MEM_READ            2'b01
`define     MEM_READ_BURST      2'b10
`define     MEM_WRITE           2'b11

// working status
`define     MEM_RESTING         2'b00
`define     MEM_INST_FINISHED   2'b01
`define     MEM_DATA_FINISHED   2'b10
`define     MEM_FINISHED        2'b11


// INSTRUCTION CACHE
// -------------------------------------------------------------------------
`define     I_CACHE_STALL        2'b00
`define     I_CACHE_WORKING      2'b01
`define     IF_FINISHED          2'b10
`define     I_CACHE_RESTING      2'b11



// DATA CACHE
// -------------------------------------------------------------------------
// task type
`define     D_CACHE_NOP          2'b00
`define     D_CACHE_LOAD         2'b01
`define     D_CACHE_STORE        2'b10
`define     D_CACHE_REST         2'b11


// working status
`define     D_CACHE_STALL        2'b00
`define     D_CACHE_WORKING      2'b01
`define     L_S_FINISHED         2'b10
`define     D_CACHE_RESTING      2'b11


// MEMORY CONTROLER
// -------------------------------------------------------------------------
// task type
`define     MEM_CTR_NOP             2'b00
`define     MEM_CTR_LOAD            2'b01
`define     MEM_CTR_STORE           2'b10
`define     MEM_CTR_REST            2'b11


// working status
`define     MEM_CTR_STALL           2'b00
`define     MEM_CTR_WORKING         2'b01
`define     MEM_CTR_FINISHED        2'b10
`define     MEM_CTR_RESTING         2'b11

// Reg File
// -------------------------------------------------------------------------
// working status
`define     RF_NOP                  2'b00
`define     SCALAR_RF_WRITE         2'b01
`define     VECTOR_RF_WRITE         2'b01
`define     RF_FINISHED             2'b11

// ALU
// ----------------------------------------------------------
// 计算控制信号
`define     ALU_NOP                 4'b0000
`define     BINARY                  4'b0001
`define     IMM_BINARY              4'b0010
`define     BRANCH_COND             4'b0011
`define     MEM_ADDR                4'b0100
`define     PC_BASED                4'b0101
`define     IMM                     4'b0110

`define     SET_CFG                 4'b0111

`define     BINARY_WORD             4'b1000
`define     IMM_BINARY_WORD         4'b1001

`define     READ_CSR                4'b1010
`define     VEC_MEM_ADDR            4'b1011


// vector运算类型
`define     NOT_VEC_ARITH           2'b00
`define     VEC_VEC                 2'b01
`define     VEC_IMM                 2'b10
`define     VEC_SCALAR              2'b11

// vector alu working status
`define     VEC_ALU_NOP             2'b00
`define     VEC_ALU_WORKING         2'b01
`define     VEC_ALU_FINISHED        2'b10

// BINARY
`define     ADD                     4'b0000
`define     SUB                     4'b1000

// IMM
`define     ADDI                    3'b000
`define     SLTI                    3'b010

// CSR读写
`define     CSRRS                   3'b010

// VECTOR
`define     VECTOR_ADD                   6'b000000
`define     VECTOR_SUB                   6'b000001
`define     VECTOR_WADDU                 6'b000010
`define     VECTOR_WSUBU                 6'b000011
`define     VECTOR_WADD                  6'b000100
`define     VECTOR_WSUB                  6'b000101
`define     VECTOR_ADC                   6'b000110
`define     VECTOR_SBC                   6'b000111
`define     VECTOR_MADC                  6'b001000
`define     VECTOR_MSBC                  6'b001001
`define     VECTOR_MACC                  6'b001010
`define     VECTOR_NMSAC                 6'b001011
`define     VECTOR_MADD                  6'b001100
`define     VECTOR_ZEXT2                 6'b001101
`define     VECTOR_SEXT2                 6'b001110
`define     VECTOR_ZEXT4                 6'b001111
`define     VECTOR_SEXT4                 6'b010000
`define     VECTOR_ZEXT8                 6'b010001
`define     VECTOR_SEXT8                 6'b010010

// DECODE
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// Type Code
// ----------------------------------------------------------
`define     P_TYPE                  8'b10000000
`define     V_TYPE                  8'b01000000
`define     R_TYPE                  8'b00100000
`define     I_TYPE                  8'b00010000
`define     S_TYPE                  8'b00001000
`define     B_TYPE                  8'b00000100
`define     U_TYPE                  8'b00000010
`define     J_TYPE                  8'b00000001

// Vector Opcode
`define     VL                      7'b0000111
`define     VS                      7'b0100111
`define     VARITH                  7'b1010111

// vector访存形式
`define     STRIDE                  2'b01
`define     WHOLE_REG               2'b10
`define     MASK                    2'b11

// BRANCH
// ----------------------------------------------------------
`define     NOT_BRANCH              2'b00
`define     UNCONDITIONAL           2'b01
`define     CONDITIONAL             2'b10
`define     UNCONDITIONAL_RESULT    2'b11 // jalr

// WB 写寄存器
// ----------------------------------------------------------
`define     WB_NOP                  3'b000
`define     MEM_TO_REG              3'b001
`define     ARITH                   3'b010
`define     INCREASED_PC            3'b011
`define     CSR_TO_REG              3'b100

// ENCODING
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// Vector L\S Encoding
// ----------------------------------------------------------
// vector addressing modes
// (mop[1:0])
// unit-stride, indexed-unordered, strided, indexed-ordered
`define     VLE                 2'b00
`define     VLUXEI              2'b01
`define     VLSE                2'b10
`define     VLOXEI              2'b11

`define     VSE                 2'b00
`define     VSUXEI              2'b01
`define     VSSE                2'b10
`define     VSOXEI              2'b11

// additional unit-stride vector addressing modes
// (lumop[4:0],sumop[4:0])
`define     E_BASIC             5'b00000
`define     E_WHOLE_REG         5'b01000
`define     E_MASK              5'b01011


// Vector Arithmetic/Configuration Encoding
// ----------------------------------------------------------
// operand type and source locations
// (funct3[2:0])
`define     OPIVV               3'b000
`define     OPFVV               3'b001
`define     OPMVV               3'b010
`define     OPIVI               3'b011
`define     OPIVX               3'b100
`define     OPFVF               3'b101
`define     OPMVX               3'b110
`define     OPCFG               3'b111 // configuration

// opcode
// (func6[5:0])
`define     V_ADD                   6'b000000
`define     V_SUB                   6'b000010
`define     V_WADDU                 6'b110000
`define     V_WSUBU                 6'b110010
`define     V_WADD                  6'b110001
`define     V_WSUB                  6'b110011
`define     V_ADC                   6'b010000
`define     V_SBC                   6'b010010 // funct3 = 000
`define     V_MADC                  6'b010001
`define     V_MSBC                  6'b010011
`define     V_MACC                  6'b101101
`define     V_NMSAC                 6'b101111
`define     V_MADD                  6'b101001

`define     V_ZEXT                  6'b010010 // in need of funct3, vs1 to determine
`define     V_SEXT                  6'b010010

// ext type
// (vs1[4:0])
`define     ZEXT2                  5'b00110
`define     SEXT2                  5'b00111
`define     ZEXT4                  5'b00100
`define     SEXT4                  5'b00101
`define     ZEXT8                  5'b00010
`define     SEXT8                  5'b00011

// CSR Read/Write Encoding
// ----------------------------------------------------------
`define     VLENB                  12'b110000100010
