#if !EMBEDDED
    import Foundation
#endif

// MARK: - ワーク用メモリ（RAM領域）
public struct WorkMemory {
    private let ptr: UnsafeMutablePointer<UInt16>
    private let size: Int

    public init(address: UInt, byteSize: Int) {
        assert(byteSize % 2 == 0, "WorkMemory size must be even")
        if byteSize % 2 != 0 {
            WorkMemory.onFatal(code: MEM_ERR_EVEN)
        }

        self.ptr = UnsafeMutablePointer<UInt16>(bitPattern: address)!
        self.size = byteSize / 2  // UInt16のサイズで割る
    }

    public func getAddress() -> UInt {
        return UInt(bitPattern: ptr)
    }

    public func getByteSize() -> Int {
        return size * 2  // バイト単位で返す
    }
    public func getIndexSize() -> Int {
        return size  // インデックス単位で返す
    }

    // インデックスアクセス
    public subscript(index: Int) -> UInt16 {
        get {
            assert(index >= 0 && index < self.size, "Memory index out of range")
            if index < 0 || index >= self.size {
                WorkMemory.onFatal(code: MEM_ERR_OUTOFBOUNDS)
            }
            return ptr[index]
        }
        set {
            assert(index >= 0 && index < self.size, "Memory index out of range")
            if index < 0 || index >= self.size {
                WorkMemory.onFatal(code: MEM_ERR_OUTOFBOUNDS)
            }
            ptr[index] = newValue
        }
    }

    // Fatal時にメモリに書き込んで終了する
    // --------------------------------------------------------------
    static private nonisolated(unsafe) var fatalFunc: (Int) -> Never = { code in
        #if !EMBEDDED
            let hexCode = String(format: "0x%08X", code)
            fatalError("Fatal error occurred with code: \(hexCode)")
        #endif
        while true {}
    }
    static public func setFatalFunc(fatalFunc: @escaping (Int) -> Never) {
        self.fatalFunc = fatalFunc
    }
    static public func onFatal(code: Int) -> Never {
        fatalFunc(code)
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

    public init(address: UInt, byteSize: Int) {
        assert(byteSize % 2 == 0, "StackMemory size must be even")
        if byteSize % 2 != 0 {
            WorkMemory.onFatal(code: MEM_ERR_EVEN)
        }

        if let ptr = UnsafeMutablePointer<UInt16>(bitPattern: address) {
            self.ptr = ptr
        } else {
            WorkMemory.onFatal(code: MEM_ERR_INVALID_ADDRESS)
        }
        self.size = byteSize / 2  // UInt16のサイズで割る
        self.sp = 0
    }

    public func getAddress() -> UInt {
        return UInt(bitPattern: ptr)
    }

    public func getByteSize() -> Int {
        return size * 2  // バイト単位で返す
    }
    public func getIndexSize() -> Int {
        return size  // インデックス単位で返す
    }
    public func isEmpty() -> Bool {
        return self.sp == 0
    }

    public mutating func push(value: UInt16) {
        assert(self.sp < self.size, "Stack overflow")
        if self.sp >= self.size {
            WorkMemory.onFatal(code: MEM_ERR_OVERFLOW)
        }

        self.ptr[self.sp] = value
        self.sp += 1
        #if !EMBEDDED
            if self.sp > self.stackMax {
                self.stackMax = self.sp
            }
        #endif
    }
    public mutating func pop() -> UInt16 {
        assert(self.sp > 0, "Stack underflow")
        if self.sp <= 0 {
            WorkMemory.onFatal(code: MEM_ERR_UNDERFLOW)
        }

        self.sp -= 1
        return self.ptr[self.sp]
    }

    public func peek() -> UInt16 {
        assert(self.sp > 0, "Stack is empty")
        if self.sp <= 0 {
            WorkMemory.onFatal(code: MEM_ERR_UNDERFLOW)
        }
        return self.ptr[self.sp - 1]
    }
}

// MARK: - キュー操作
public struct QueueMemory {
    private let ptr: UnsafeMutablePointer<UInt16>
    private let size: Int
    private var qp: Int
    #if !EMBEDDED
        public var queueMax: Int = 0  // スタックの最大使用量を追跡するためのデバッグ用変数
    #endif

    public init(address: UInt, byteSize: Int) {
        assert(byteSize % 2 == 0, "QueueMemory size must be even")
        if byteSize % 2 != 0 {
            WorkMemory.onFatal(code: MEM_ERR_EVEN)
        }

        self.ptr = UnsafeMutablePointer<UInt16>(bitPattern: address)!
        self.size = byteSize / 2  // UInt16のサイズで割る
        self.qp = 0
    }

    public func getAddress() -> UInt {
        return UInt(bitPattern: ptr)
    }

    public func getByteSize() -> Int {
        return size * 2  // バイト単位で返す
    }
    public func getIndexSize() -> Int {
        return size  // インデックス単位で返す
    }
    public func isEmpty() -> Bool {
        return self.qp == 0
    }

    public mutating func enqueue(value: UInt16) {
        assert(self.qp < self.size, "Queue overflow")
        if self.qp >= self.size {
            WorkMemory.onFatal(code: MEM_ERR_OVERFLOW)
        }

        self.ptr[self.qp] = value
        self.qp += 1
        #if !EMBEDDED
            if self.qp > self.queueMax {
                self.queueMax = self.qp
            }
        #endif
    }
    public mutating func dequeue() -> UInt16 {
        assert(self.qp > 0, "Queue underflow")
        if self.qp <= 0 {
            WorkMemory.onFatal(code: MEM_ERR_UNDERFLOW)
        }

        let value = self.ptr[0]
        for i in 1..<self.qp {
            self.ptr[i - 1] = self.ptr[i]
        }
        self.qp -= 1
        return value
    }

    public func peek() -> UInt16 {
        assert(self.qp > 0, "Queue is empty")
        if self.qp <= 0 {
            WorkMemory.onFatal(code: MEM_ERR_UNDERFLOW)
        }

        return self.ptr[0]
    }
}
