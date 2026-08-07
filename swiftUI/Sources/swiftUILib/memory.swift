// MARK: - ワーク用メモリ（RAM領域）
public struct WorkMemory {
    private let ptr: UnsafeMutablePointer<UInt16>
    private let size: Int

    public init(address: UInt, size: Int) {
        self.ptr = UnsafeMutablePointer<UInt16>(bitPattern: address)!
        self.size = size / 2  // UInt16のサイズで割る
    }

    public subscript(index: Int) -> UInt16 {
        get {
            #if !EMBEDDED
                assert(index >= 0 && index < self.size, "Memory index out of range")
            #endif
            return ptr[index]
        }
        set {
            #if !EMBEDDED
                assert(index >= 0 && index < self.size, "Memory index out of range")
            #endif
            ptr[index] = newValue
        }
    }
}

// MARK: - スタック操作
public struct StackMemory {
    private let ptr: UnsafeMutablePointer<UInt16>
    private let size: Int
    private var sp: Int
    #if !EMBEDDED
        public var stackMax: Int = 0  // スタックの最大使用量を追跡するためのデバッグ用変数
    #endif

    public init(address: UInt, size: Int) {
        self.ptr = UnsafeMutablePointer<UInt16>(bitPattern: address)!
        self.size = size / 2  // UInt16のサイズで割る
        self.sp = 0
    }

    public mutating func push(value: UInt16) {
        #if !EMBEDDED
            assert(self.sp < self.size, "Stack overflow")
        #endif
        self.ptr[self.sp] = value
        self.sp += 1
        #if !EMBEDDED
            if self.sp > self.stackMax {
                self.stackMax = self.sp
            }
        #endif
    }
    public mutating func pop() -> UInt16 {
        #if !EMBEDDED
            assert(self.sp > 0, "Stack underflow")
        #endif
        self.sp -= 1
        return self.ptr[self.sp]
    }

    public func peek() -> UInt16 {
        #if !EMBEDDED
            assert(self.sp > 0, "Stack is empty")
        #endif
        return self.ptr[self.sp - 1]
    }
}
