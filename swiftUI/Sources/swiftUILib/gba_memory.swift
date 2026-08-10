#if !EMBEDDED
    import Foundation
#endif

// ユーティリティ
public func ExpandEven(value: Int) -> Int {
    return (value + 1) & ~1  // 偶数に拡張する
}

// MARK: - 16bitのメモリ操作の共通プロトコル
// ****************************************************************************
public protocol MemoryInt16 {
    var ptr: UnsafeMutablePointer<UInt16> { get }
    var capacity: Int { get }

    func getAddress() -> UInt
    func getByteSize() -> Int
}

extension MemoryInt16 {
    public func getAddress() -> UInt {
        return UInt(bitPattern: ptr)
    }
    public func getByteSize() -> Int {
        return capacity * 2  // バイト単位で返す
    }
    public func getCapacity() -> Int {
        return capacity
    }
}

// MARK: - ワーク用メモリ（RAM領域）
// ------------------------------------------------------------------
public struct WorkMemory: MemoryInt16 {
    public private(set) var ptr: UnsafeMutablePointer<UInt16>
    public private(set) var capacity: Int

    public init(address: UInt, byteSize: Int) {
        assert(byteSize % 2 == 0, "WorkMemory size must be even")
        if byteSize % 2 != 0 {
            WorkMemory.onFatal(code: MEM_ERR_EVEN)
        }

        self.ptr = UnsafeMutablePointer<UInt16>(bitPattern: address)!
        self.capacity = byteSize / 2  // UInt16のサイズで割る
    }

    // インデックスアクセス
    public subscript(index: Int) -> UInt16 {
        get {
            assert(
                index >= 0 && index < self.capacity,
                "Memory index out of range: \(index)/\(self.capacity)")
            if index < 0 || index >= self.capacity {
                WorkMemory.onFatal(code: MEM_ERR_OUTOFBOUNDS)
            }
            return ptr[index]
        }
        set {
            assert(
                index >= 0 && index < self.capacity,
                "Memory index out of range: \(index)/\(self.capacity)")
            if index < 0 || index >= self.capacity {
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
// キュー・スタック
// ****************************************************************************
public protocol QueueStack16: MemoryInt16 {
    func isEmpty() -> Bool
    func getLength() -> Int
    func peek(index: Int) -> UInt16
    mutating func clear()  // キュー・スタックをクリアする
}

// MARK: - スタック操作
// ------------------------------------------------------------------
public struct StackMemory: QueueStack16 {
    public private(set) var ptr: UnsafeMutablePointer<UInt16>
    public private(set) var capacity: Int

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
        self.capacity = byteSize / 2  // UInt16のサイズで割る
        self.sp = 0
    }

    // IFの実装
    public func isEmpty() -> Bool {
        return self.sp == 0
    }
    public func getLength() -> Int {
        return self.sp
    }
    public func peek(index: Int = 0) -> UInt16 {
        assert(index >= 0 && index < self.sp, "Stack index out of range")
        if index < 0 || index >= self.sp {
            WorkMemory.onFatal(code: MEM_ERR_OUTOFBOUNDS)
        }
        return self.ptr[self.sp - 1 - index]
    }
    public mutating func clear() {
        self.sp = 0
    }

    // スタック操作
    public mutating func push(value: UInt16) {
        assert(self.sp < self.capacity, "Stack overflow")
        if self.sp >= self.capacity {
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
}

// MARK: - キュー操作(Ringバッファ)
// ------------------------------------------------------------------
public struct RingQueueMemory: QueueStack16 {
    public private(set) var ptr: UnsafeMutablePointer<UInt16>
    public private(set) var capacity: Int

    private var qBgn: Int
    private var qEnd: Int
    #if !EMBEDDED
        public var queueMax: Int = 0  // キューの最大使用量を追跡するためのデバッグ用変数
    #endif

    public init(address: UInt, byteSize: Int) {
        assert(byteSize % 2 == 0, "QueueMemory size must be even")
        if byteSize % 2 != 0 {
            WorkMemory.onFatal(code: MEM_ERR_EVEN)
        }

        self.ptr = UnsafeMutablePointer<UInt16>(bitPattern: address)!
        self.capacity = byteSize / 2  // UInt16のサイズで割る
        self.qBgn = 0
        self.qEnd = 0
    }

    // IFの実装
    public func isEmpty() -> Bool {
        return self.qBgn == self.qEnd
    }
    public func getLength() -> Int {
        return (self.qEnd - self.qBgn + self.capacity) % self.capacity
    }
    public func peek(index: Int = 0) -> UInt16 {
        assert(self.qBgn != self.qEnd, "Queue is empty")
        if self.qBgn == self.qEnd {
            WorkMemory.onFatal(code: MEM_ERR_UNDERFLOW)
        }

        return self.ptr[(self.qBgn + index) % self.capacity]
    }
    public mutating func clear() {
        self.qBgn = 0
        self.qEnd = 0
    }

    // キュー操作
    public mutating func enqueue(value: UInt16) {
        assert((self.qEnd + 1) % self.capacity != self.qBgn, "Queue overflow")
        if (self.qEnd + 1) % self.capacity == self.qBgn {
            WorkMemory.onFatal(code: MEM_ERR_OVERFLOW)
        }

        self.ptr[self.qEnd] = value
        self.qEnd = (self.qEnd + 1) % self.capacity
        #if !EMBEDDED
            let currentSize = (self.qEnd - self.qBgn + self.capacity) % self.capacity
            if currentSize > self.queueMax {
                self.queueMax = currentSize
            }
        #endif
    }
    public mutating func dequeue() -> UInt16 {
        assert(self.qBgn != self.qEnd, "Queue underflow")
        if self.qBgn == self.qEnd {
            WorkMemory.onFatal(code: MEM_ERR_UNDERFLOW)
        }

        let value = self.ptr[self.qBgn]
        self.qBgn = (self.qBgn + 1) % self.capacity
        return value
    }
}
