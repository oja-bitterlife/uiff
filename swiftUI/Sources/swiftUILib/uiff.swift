// uiffチャンクの操作
public struct UiffFile {
    private let ptr: UnsafeMutablePointer<UInt16>

    public init(address: UInt) {
        self.ptr = UnsafeMutablePointer<UInt16>(bitPattern: address)!
    }

    public func getMagic() -> [UInt8] {
        return [
            UInt8(ptr[0] & 0xff), UInt8(ptr[0] >> 8),
            UInt8(ptr[1] & 0xff), UInt8(ptr[1] >> 8),
        ]
    }

    public func getSize() -> UInt16 {
        return ptr[2]
    }
}

public struct UiffType {
    static let TYPE_CHUNK_SIZE = 10  // type chunkのサイズ

    private let workMemory: WorkMemory
    private let offset: Int

    public init(workMemory: WorkMemory, offset: Int) {
        self.workMemory = workMemory
        self.offset = offset
    }

    public func getChunkID() -> UInt16 {
        return workMemory[offset]
    }

    public func getPayloadSize() -> UInt16 {
        return workMemory[offset + 1]
    }

    public func getType() -> UInt16 {
        return workMemory[offset + 2]
    }

    public func getSubType() -> UInt16 {
        return workMemory[offset + 3]
    }

    public func getEnable() -> Bool {
        return workMemory[offset + 4] != 0
    }

    public func getVisible() -> Bool {
        return workMemory[offset + 5] != 0
    }

    public func getX() -> Int16 {
        return Int16(bitPattern: workMemory[offset + 6])
    }

    public func getY() -> Int16 {
        return Int16(bitPattern: workMemory[offset + 7])
    }

    public func getW() -> UInt16 {
        return workMemory[offset + 8]
    }

    public func getH() -> UInt16 {
        return workMemory[offset + 9]
    }
}

public struct UiffSelect {
    private let workMemory: WorkMemory
    private let offset: Int

    public init(workMemory: WorkMemory, offset: Int) {
        self.workMemory = workMemory
        self.offset = offset
    }

    public func getSelRows() -> UInt16 {
        return workMemory[offset]
    }

    public func getSelItem() -> UiffProp {
        return UiffProp(workMemory: workMemory, offset: offset + 1)
    }
}

public struct UiffProp {
    private let workMemory: WorkMemory
    private let offset: Int

    public init(workMemory: WorkMemory, offset: Int) {
        self.workMemory = workMemory
        self.offset = offset
    }

    public func getType() -> UiffType {
        return UiffType(workMemory: workMemory, offset: offset + 0)
    }

    public func getPayload(offset: Int) -> UInt16 {
        return workMemory[self.offset + UiffType.TYPE_CHUNK_SIZE + offset]
    }
}
