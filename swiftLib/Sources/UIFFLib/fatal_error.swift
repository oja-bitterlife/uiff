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
