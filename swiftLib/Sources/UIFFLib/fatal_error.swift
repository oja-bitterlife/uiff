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

// 便利関数
// ****************************************************************************
public func strlen(_ str: UnsafePointer<CChar>, maxLen: Int = 256) -> Int {
    var len = 0
    while str.advanced(by: len).pointee != 0 && len < maxLen {
        len += 1
    }
    return len
}

public struct I2AIter {
    private var value: UInt
    private var divisor: UInt

    // 初期化
    public init(_ number: UInt, minDigits: Int = 0) {
        // 負数は考慮せず正の整数（行番号など）を想定
        self.value = number

        // 桁数のベース（例: 123なら 100 を作る）
        var d: UInt = 1
        var digitCount = 0
        if number >= 10 {
            var temp = number
            while temp >= 10 {
                d *= 10
                temp /= 10
                digitCount += 1
            }
        }

        // 最小桁数を満たすために、必要に応じて桁数を増やす
        while digitCount < minDigits {
            d *= 10
            digitCount += 1
        }

        self.divisor = d
    }

    // 次の桁を返す
    public mutating func next() -> UInt8? {
        guard divisor > 0 else { return nil }

        let digit = (value / divisor) % 10
        value %= divisor
        divisor /= 10

        // 数字を ASCII の文字コード (0x30〜) に変換
        return UInt8(48 + digit)
    }

    // 残り桁数を返す
    public func remainingDigits() -> Int {
        var tempDivisor = divisor
        var count = 0
        while tempDivisor > 0 {
            count += 1
            tempDivisor /= 10
        }
        return count
    }
}
