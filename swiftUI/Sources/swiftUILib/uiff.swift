// uiffチャンクの操作

// ファイルヘッダー用
// ****************************************************************************
public struct UiffFileHeader {
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

// uiffチャンク共通
// ****************************************************************************
protocol UiffChunk {
    var chunkMemory: WorkMemory { get set }
}
extension UiffChunk {
    static func assign(workMemory: WorkMemory, offset: Int) -> WorkMemory {
        return WorkMemory(
            address: workMemory.getAddress() + UInt(offset),
            size: Int(workMemory.getSize()) - offset)
    }

    public func getChunkType() -> UInt16 {
        return chunkMemory[0]
    }

    public func getPayloadSize() -> Int {
        assert(chunkMemory[1] < 32767, "Payload size is too large")
        return Int(chunkMemory[1])
    }

    public func getPayloadPtr() -> UnsafeMutablePointer<UInt16> {
        return UnsafeMutablePointer<UInt16>(bitPattern: chunkMemory.getAddress() + 4)!
    }

    public func getChunkSize() -> Int {
        return getPayloadSize() + 4  // ヘッダの4バイトを加える
    }
}

public struct UiffProp: UiffChunk {
    public var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offset: Int) {
        self.chunkMemory = UiffProp.assign(workMemory: workMemory, offset: offset)
    }
}

// 特別なType
// ****************************************************************************
public struct UiffType: UiffChunk {
    var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offset: Int) {
        self.chunkMemory = UiffType.assign(workMemory: workMemory, offset: offset)
    }

    public func getTypeID() -> UInt16 {
        return chunkMemory[2]
    }

    public func getSubTypeID() -> UInt16 {
        return chunkMemory[3]
    }

    public func getEnable() -> Bool {
        return chunkMemory[4] != 0
    }

    public func getVisible() -> Bool {
        return chunkMemory[5] != 0
    }

    public func getX() -> Int16 {
        return Int16(bitPattern: chunkMemory[6])
    }

    public func getY() -> Int16 {
        return Int16(bitPattern: chunkMemory[7])
    }

    public func getW() -> UInt16 {
        return chunkMemory[8]
    }

    public func getH() -> UInt16 {
        return chunkMemory[9]
    }
}

public struct UiffSelect: UiffChunk {
    public var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offset: Int) {
        self.chunkMemory = UiffSelect.assign(workMemory: workMemory, offset: offset)
    }

    public func getSelRows() -> UInt16 {
        return chunkMemory[0]
    }

    public func getSelItemNum() -> UInt16 {
        return chunkMemory[1]
    }

    public func getSelItem(index: Int) -> UiffProp {
        let item_num = getSelItemNum()
        assert(index < item_num, "index out of range")

        var sel_item = UiffProp(workMemory: chunkMemory, offset: 2)  // sel_rowsとsel_item_numを飛ばす
        for _ in 0..<index {
            sel_item = UiffProp(workMemory: chunkMemory, offset: sel_item.getChunkSize())
        }
        return sel_item
    }
}

// プロパティ各種
// ****************************************************************************
public struct UiffEvents: UiffChunk {
    public var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offset: Int) {
        self.chunkMemory = UiffEvents.assign(workMemory: workMemory, offset: offset)
    }

    public func getEventNum() -> Int {
        return getPayloadSize() / 2  // 1イベントあたり2バイト
    }

    public func getEventID(index: Int) -> UInt16 {
        assert(index < getEventNum(), "index out of range")
        return chunkMemory[index * 2 + 2]  // 1イベントあたり2バイト
    }
}

public struct UiffScript: UiffChunk {
    public var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offset: Int) {
        self.chunkMemory = UiffScript.assign(workMemory: workMemory, offset: offset)
    }

    public func getScriptPtr() -> UnsafeMutablePointer<UInt16> {
        return getPayloadPtr()
    }
}

public struct UiffColors: UiffChunk {
    public var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offset: Int) {
        self.chunkMemory = UiffColors.assign(workMemory: workMemory, offset: offset)
    }

    public func getColorNum() -> Int {
        return Int(getPayloadSize() / 4)  // 1色あたり4バイト
    }

    public func getColor(index: Int) -> UInt32 {
        assert(index < getColorNum(), "index out of range")
        let color_low = chunkMemory[index * 2 + 2]  // 1色あたり4バイト
        let color_high = chunkMemory[index * 2 + 3]
        return UInt32(color_high) << 16 | UInt32(color_low)
    }
}

public struct UiffText: UiffChunk {
    public var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offset: Int) {
        self.chunkMemory = UiffText.assign(workMemory: workMemory, offset: offset)
    }

    public func getTextSize() -> Int {
        return Int(chunkMemory[0])
    }

    public func getTextPtr() -> UnsafeMutablePointer<UInt16> {
        return getPayloadPtr()
    }
}
