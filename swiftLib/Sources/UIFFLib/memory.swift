#if !EMBEDDED
    import Foundation
#endif

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

    // メモリダイレクトアクセス用
    public func getDirectPtr<T>(as type: T.Type, offset: Int = 0) -> UnsafeMutablePointer<T> {
        if offset < 0 || offset >= self.getByteSize() {  // out of bounds
            FatalMsg("Memory offset out of bounds")
        }
        if let bytePtr = UnsafeMutablePointer<T>(bitPattern: self.getAddress() + UInt(offset)) {
            return bytePtr
        } else {
            FatalMsg("Invalid memory address")
        }
    }

    // デバッグ用
    public func setMagic(count: Int = 2, magic: UInt16 = 0xBADE) {
        for i in 0..<count {
            ptr[i] = magic
        }
        for i in capacity - count..<capacity {
            ptr[i] = magic
        }
    }
    public func checkMagic(count: Int = 2, magic: UInt16 = 0xBADE) {
        for i in 0..<count {
            if ptr[i] != magic {
                FatalMsg("Magic value mismatch at the beginning of memory")
            }
        }
        for i in capacity - count..<capacity {
            if ptr[i] != magic {
                FatalMsg("Magic value mismatch at the end of memory")
            }
        }
    }
}

// MARK: - ワーク用メモリ（RAM領域）
// ------------------------------------------------------------------
public struct WorkMemory: MemoryInt16 {
    public private(set) var ptr: UnsafeMutablePointer<UInt16>
    public private(set) var capacity: Int

    public init(address: UInt, byteSize: Int) {
        if byteSize % 2 != 0 {
            FatalMsg("Byte size must be even")
        }

        if let ptr = UnsafeMutablePointer<UInt16>(bitPattern: address) {
            self.ptr = ptr
            self.capacity = byteSize / 2  // UInt16のサイズで割る
        } else {
            FatalMsg("Invalid memory address")
        }
    }

    // メモリの一部を切り出す
    public func take(offset: Int, byteSize: Int) -> WorkMemory {
        if offset < 0 || byteSize < 0 || (offset + byteSize) > self.getByteSize() {
            FatalMsg("Invalid memory range")
        }
        return WorkMemory(address: self.getAddress() + UInt(offset), byteSize: byteSize)
    }
    public func take(offset: Int) -> WorkMemory {
        return take(offset: offset, byteSize: self.getByteSize() - offset)
    }

    // インデックスアクセス
    // --------------------------------------------------------------
    public subscript(index: Int) -> UInt16 {
        get {
            if index < 0 || index >= self.capacity {
                FatalMsg("Index out of bounds")
            }
            return ptr[index]
        }
        set {
            if index < 0 || index >= self.capacity {
                FatalMsg("Index out of bounds")
            }
            ptr[index] = newValue
        }
    }

    // メモリダイレクトアクセス
    // --------------------------------------------------------------
    public func writeUInt8(offset: Int = 0, value: UInt8) {
        let bytePtr = self.getDirectPtr(as: UInt8.self, offset: offset)
        bytePtr.pointee = value
    }
    public func readUInt8(offset: Int = 0) -> UInt8 {
        let bytePtr = self.getDirectPtr(as: UInt8.self, offset: offset)
        return bytePtr.pointee
    }
    public func writeUInt16(offset: Int = 0, value: UInt16) {
        let wordPtr = self.getDirectPtr(as: UInt16.self, offset: offset)
        wordPtr.pointee = value
    }
    public func readUInt16(offset: Int = 0) -> UInt16 {
        let wordPtr = self.getDirectPtr(as: UInt16.self, offset: offset)
        return wordPtr.pointee
    }
    public func writeUInt(offset: Int = 0, value: UInt) {
        let dwordPtr = self.getDirectPtr(as: UInt.self, offset: offset)
        dwordPtr.pointee = value
    }
    public func writeInt(offset: Int = 0, value: Int) {
        writeUInt(offset: offset, value: UInt(bitPattern: value))
    }
    public func readUInt(offset: Int = 0) -> UInt {
        let dwordPtr = self.getDirectPtr(as: UInt.self, offset: offset)
        return dwordPtr.pointee
    }

    // 固定文字列を書き込む
    public func writeStr(text: StaticString, offset: Int = 0) {
        text.withUTF8Buffer { buffer in
            for i in 0..<buffer.count {
                self.writeUInt8(offset: offset + i, value: buffer[i])
            }
        }
    }

    // 構造体単位でアクセスする
    // --------------------------------------------------------------
    public func Bind<T>(_ type: T.Type) -> UnsafeMutablePointer<T> {
        guard let ptr = UnsafeMutablePointer<T>(bitPattern: getAddress()) else {
            FatalMsg("Invalid memory address")
        }
        return ptr
    }
}

// キュー・スタック
// ****************************************************************************
public protocol QueueStack16: MemoryInt16 {
    func isEmpty() -> Bool
    func getLength() -> Int
    func peek(index: Int) -> UInt16
    mutating func clear()  // キュー・スタックをクリアする

    func contains(value: UInt16) -> Bool
}

// 共通実装
extension QueueStack16 {
    public func contains(value: UInt16) -> Bool {
        for i in 0..<self.getLength() {
            if self.peek(index: i) == value {
                return true
            }
        }
        return false
    }
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
        if byteSize % 2 != 0 {
            FatalMsg("Byte size must be even")
        }

        if let ptr = UnsafeMutablePointer<UInt16>(bitPattern: address) {
            self.ptr = ptr
        } else {
            FatalMsg("Invalid memory address")
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
        if index < 0 || index >= self.sp {
            FatalMsg("Index out of bounds")
        }
        return self.ptr[self.sp - 1 - index]
    }
    public mutating func clear() {
        self.sp = 0
    }

    // スタック操作
    public mutating func push(value: UInt16) {
        if self.sp >= self.capacity {
            FatalMsg("Stack overflow")
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
        if self.sp <= 0 {
            FatalMsg("Stack underflow")
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
        if byteSize % 2 != 0 {
            FatalMsg("Byte size must be even")
        }

        if let ptr = UnsafeMutablePointer<UInt16>(bitPattern: address) {
            self.ptr = ptr
        } else {
            FatalMsg("Invalid memory address")
        }
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
        if self.qBgn == self.qEnd {
            FatalMsg("Queue underflow")
        }

        return self.ptr[(self.qBgn + index) % self.capacity]
    }
    public mutating func clear() {
        self.qBgn = 0
        self.qEnd = 0
    }

    // キュー操作
    public mutating func enqueue(value: UInt16) {
        if (self.qEnd + 1) % self.capacity == self.qBgn {
            FatalMsg("Queue overflow")
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
        if self.qBgn == self.qEnd {
            FatalMsg("Queue underflow")
        }

        let value = self.ptr[self.qBgn]
        self.qBgn = (self.qBgn + 1) % self.capacity
        return value
    }
}
