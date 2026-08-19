// Errorベース
// ****************************************************************************
private let MEM_ERR_BASE = 0x1000_0000
private let VM_ERR_BASE = 0x2000_0000
private let UIFF_ERR_BASE = 0x3000_0000

// メモリ関連のエラーコード
// ****************************************************************************
public let MEM_ERR_EVEN = MEM_ERR_BASE | 0x1
public let MEM_ERR_OVERFLOW = MEM_ERR_BASE | 0x2
public let MEM_ERR_UNDERFLOW = MEM_ERR_BASE | 0x3
public let MEM_ERR_OUTOFBOUNDS = MEM_ERR_BASE | 0x4
public let MEM_ERR_INVALID_ADDRESS = MEM_ERR_BASE | 0x5
public let MEM_ERR_INVALID_SIZE = MEM_ERR_BASE | 0x6

// VM関連のエラーコード
// ****************************************************************************
public let VM_ERR_ZERO_DIV = VM_ERR_BASE | 0x1
public let VM_ERR_UNKNOWN_CMP = VM_ERR_BASE | 0x2
public let VM_ERR_UNKNOWN_OP = VM_ERR_BASE | 0x3

// UIFF関連のエラーコード
// ****************************************************************************
// UIFFのファイル関連のエラーコード
public let UIFF_ERR_FILE_INVALID = UIFF_ERR_BASE | 0x1
public let UIFF_ERR_FILE_TOO_LARGE = UIFF_ERR_BASE | 0x2
public let UIFF_ERR_CHUNK_INVALID = UIFF_ERR_BASE | 0x3

// UIFFのEvent関連のエラーコード
private let UIFF_ERR_EVENT_BASE = UIFF_ERR_BASE | 0x0100_0000
public let UIFF_ERR_EVENT_INVALID = UIFF_ERR_EVENT_BASE | 0x1

// Fatal
// ****************************************************************************
// 1. コールバックの型を 「整数(Int)」 から 「文字列ポインタ(UnsafePointer<CChar>)」 にする
nonisolated(unsafe) private var UIFF_FatalFunc:
    @convention(c) (UnsafePointer<CChar>, UnsafePointer<CChar>, Int) -> Void = {
        msgPtr, filePtr, line in
        #if !EMBEDDED
            let message = String(cString: msgPtr)
            let file = String(cString: filePtr)
            fatalError("Fatal error occurred: \(message) in file: \(file) at line: \(line)")
        #endif
        while true {}
    }

public func SetFatalFunc(
    fatalFunc: @convention(c) (UnsafePointer<CChar>, UnsafePointer<CChar>, Int) -> Void
) {
    UIFF_FatalFunc = fatalFunc
}

// 番号管理が面倒になったので、文字列管理に
public func FatalMsg(_ msg: StaticString, file: StaticString = #file, line: Int = #line) -> Never {
    let msgPtr = msg.withUTF8Buffer {
        UnsafeRawPointer($0.baseAddress!).assumingMemoryBound(to: CChar.self)
    }
    let filePtr = file.withUTF8Buffer {
        UnsafeRawPointer($0.baseAddress!).assumingMemoryBound(to: CChar.self)
    }

    UIFF_FatalFunc(msgPtr, filePtr, line)
    while true {}
}
