let ADDR_ERROR = 0xFFFF  // エラー終了用のPC値

// OPコード
// ****************************************************************************
let OP_HALT = 0x00
let OP_PUSHA = 0x01  // Push VM[<address>] onto the stack
let OP_PUSHB = 0x02  // Push byte onto the stack
let OP_PUSHW = 0x03  // Push word onto the stack
let OP_POPA = 0x04  // Pop from stack into VM[<address>]
let OP_DUP = 0x05  // Duplicate the top value of the stack
let OP_OVER = 0x06  // Duplicate the second value from the top of the stack
let OP_SWP = 0x07  // Swap the top two values of the stack
let OP_DEL = 0x08  // Pop from stack and discard
let OP_JMP = 0x10  // Jump
let OP_JZ = 0x11  // Jump if Zero (R0 == 0)
let OP_CMP = 0x20  // R0とR1を比較してR0に 0 or 1 で結果を格納。比較演算はSubコードで指定する。
let OP_AND = 0x21  // R0 = R0 & R1
let OP_OR = 0x22  // R0 = R0 | R1
let OP_XOR = 0x23  // R0 = R0 ^ R1
let OP_ADD = 0x30  // R0 = R0 + R1
let OP_SUB = 0x31  // R0 = R0 - R1
let OP_MUL = 0x32  // R0 = R0 * R1
let OP_DIV = 0x33  // R0 = R0 / R1
let OP_MOD = 0x34  // R0 = R0 % R1

// 比較演算のサブコード
let CMP_EQ = 0x00  // R0 == R1
let CMP_NE = 0x01  // R0 != R1
let CMP_LT = 0x02  // R0 < R1
let CMP_LE = 0x03  // R0 <= R1
let CMP_GT = 0x04  // R0 > R1
let CMP_GE = 0x05  // R0 >= R1
