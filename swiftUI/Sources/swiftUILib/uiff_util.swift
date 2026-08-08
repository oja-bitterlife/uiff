// uiffチャンクの操作

// ファイルヘッダー用
// ****************************************************************************
public struct UiffFileHeader {
    private let ptr: UnsafeMutablePointer<UInt16>

    public init(address: UInt) {
        self.ptr = UnsafeMutablePointer<UInt16>(bitPattern: address)!
    }

    public var magic: UInt32 {
        return UInt32(ptr[0] & 0xff) | (UInt32(ptr[0] >> 8) << 8) | (UInt32(ptr[1] & 0xff) << 16)
            | (UInt32(ptr[1] >> 8) << 24)
    }

    public var size: UInt16 {
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
    public var chunkType: UInt16 {
        return chunkMemory[0]
    }

    public var payloadSize: Int {
        assert(chunkMemory[1] < 32767, "Payload size is too large")
        return Int(chunkMemory[1])
    }

    public var payloadPtr: UnsafeMutablePointer<UInt16> {
        return UnsafeMutablePointer<UInt16>(bitPattern: chunkMemory.getAddress() + 4)!
    }

    public var chunkSize: Int {
        return payloadSize + 4  // ヘッダの4バイトを加える
    }
}

// UiffChunkの実体
public struct UiffProp: UiffChunk {
    public var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offset: Int) {
        self.chunkMemory = UiffProp.assign(workMemory: workMemory, offset: offset)
    }
}

// 特別なChunk
// ****************************************************************************
// UiffEnetryHeader
public struct UiffEntry: UiffChunk {
    var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offset: Int) {
        self.chunkMemory = UiffEntry.assign(workMemory: workMemory, offset: offset)
    }

    public var typeID: UInt16 {
        return chunkMemory[2]
    }

    public var subTypeID: UInt16 {
        return chunkMemory[3]
    }

    public var enable: Bool {
        return chunkMemory[4] != 0
    }

    public var visible: Bool {
        return chunkMemory[5] != 0
    }

    public var x: Int16 {
        return Int16(bitPattern: chunkMemory[6])
    }

    public var y: Int16 {
        return Int16(bitPattern: chunkMemory[7])
    }

    public var w: UInt16 {
        return chunkMemory[8]
    }

    public var h: UInt16 {
        return chunkMemory[9]
    }
}

// IFF_SELECTチャンク
public struct UiffSelect: UiffChunk {
    public var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offset: Int) {
        self.chunkMemory = UiffSelect.assign(workMemory: workMemory, offset: offset)
    }

    // 選択肢を横に並べる数
    public var selRows: UInt16 {
        return chunkMemory[0]
    }

    public var selItemNum: UInt16 {
        return chunkMemory[1]
    }

    public func getSelItem(index: Int) -> UiffProp {
        let item_num = selItemNum
        assert(index < item_num, "index out of range")

        var sel_item = UiffProp(workMemory: chunkMemory, offset: 2)  // sel_rowsとsel_item_numを飛ばす
        for _ in 0..<index {
            sel_item = UiffProp(workMemory: chunkMemory, offset: sel_item.chunkSize)
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

    public var eventNum: Int {
        return payloadSize / 2  // 1イベントあたり2バイト
    }

    public func getEventID(index: Int) -> UInt16 {
        assert(index < eventNum, "index out of range")
        return payloadPtr[index]
    }
}

public struct UiffScript: UiffChunk {
    public var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offset: Int) {
        self.chunkMemory = UiffScript.assign(workMemory: workMemory, offset: offset)
    }
}

public struct UiffColors: UiffChunk {
    public var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offset: Int) {
        self.chunkMemory = UiffColors.assign(workMemory: workMemory, offset: offset)
    }

    public var colorNum: Int {
        return payloadSize / 4  // 1色あたり4バイト
    }

    public func getColor(index: Int) -> UInt32 {
        assert(index < colorNum, "index out of range")
        let color_low = payloadPtr[index * 2]  // 1色あたり4バイト
        let color_high = payloadPtr[index * 2 + 1]
        return UInt32(color_high) << 16 | UInt32(color_low)
    }
}

public struct UiffText: UiffChunk {
    public var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offset: Int) {
        self.chunkMemory = UiffText.assign(workMemory: workMemory, offset: offset)
    }

    public var textLength: Int {
        return Int(chunkMemory[0])
    }
}
