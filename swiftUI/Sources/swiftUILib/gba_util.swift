public struct GBAUtil {
    let FatalCodeAddr: UInt

    public init(FatalCodeAddr: UInt) {
        self.FatalCodeAddr = FatalCodeAddr
    }

    // エラー処理
    let NULL_PTR_ERROR: UInt8 = 0x01
    let TYPE_ERROR: UInt8 = 0x02
    let VALUE_ERROR: UInt8 = 0x03

    public func fatalError(fatal_code: UInt8) -> Never {
        // 生のアドレスから直接ポインタを作る（オプショナルにならない）
        let fatal_code_ptr = UnsafeMutablePointer<UInt8>(
            mutating: UnsafePointer<UInt8>(bitPattern: UInt(FatalCodeAddr))!)
        fatal_code_ptr.pointee = fatal_code
        #if EMBEDDED
            while true {}
        #else
            assert(false, "Fatal error occurred with code: \(fatal_code)")
        #endif
    }

    // どんな型（T）のオプショナルでも受け取れる汎用チェック関数
    public func unwrap<T>(_ optionalValue: T?) -> T {
        guard let value = optionalValue else {
            fatalError(fatal_code: NULL_PTR_ERROR)
        }
        // nil でなければ、アンラップされた安全な値を返す
        return value
    }
}
