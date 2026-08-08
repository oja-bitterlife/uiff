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

    public var data: UnsafeMutablePointer<UInt8> {
        return UnsafeMutablePointer<UInt8>(bitPattern: UInt(bitPattern: ptr) + 6)!
    }
}

// uiffチャンク共通
// ****************************************************************************
public protocol UiffChunk {
    var chunkMemory: WorkMemory { get }
    var chunkType: UInt16 { get }
    var payload: WorkMemory { get }
    var chunkSize: Int { get }
}
extension UiffChunk {
    public static func assign(workMemory: WorkMemory, offsetBytes: Int) -> WorkMemory {
        return WorkMemory(
            address: workMemory.getAddress() + UInt(offsetBytes),
            byteSize: workMemory.getByteSize() - offsetBytes)
    }
    public var chunkType: UInt16 {
        return chunkMemory[0]
    }

    public var chunkSize: Int {
        return Int(chunkMemory[1]) + 4  // ヘッダの4バイトを加える
    }

    public var payload: WorkMemory {
        return WorkMemory(
            address: chunkMemory.getAddress() + 4,
            byteSize: Int(chunkMemory[1]))
    }

    public func getNext() -> UiffChunk? {
        // 最後まで到達
        if chunkMemory.getByteSize() <= chunkSize {
            return nil
        }

        switch chunkMemory[chunkSize / 2] {  // 次のチャンクのタイプを取得
        case UInt16(UIFF_ENTRY):
            return UiffEntry(workMemory: chunkMemory, offsetBytes: self.chunkSize)
        case UInt16(UIFF_CHILD):
            return UiffChild(workMemory: chunkMemory, offsetBytes: self.chunkSize)
        default:
            return UiffProp(workMemory: chunkMemory, offsetBytes: self.chunkSize)
        }
    }
}

// 基本的なデータアクセス
// ****************************************************************************
// Enetry単位アクセス用チャンク
public struct UiffEntry: UiffChunk {
    static let HEADER_BYTESIZE = 10 * 2  // ヘッダのサイズ(バイト単位)
    public private(set) var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offsetBytes: Int) {
        self.chunkMemory = UiffEntry.assign(workMemory: workMemory, offsetBytes: offsetBytes)
    }

    public var typeID: UInt16 {
        return chunkMemory[2]
    }

    public var subTypeID: UInt16 {
        return chunkMemory[3]
    }

    public var isEnabled: Bool {
        get {
            return chunkMemory[4] != 0
        }
        set {
            chunkMemory[4] = newValue ? 1 : 0
        }
    }

    public var isVisible: Bool {
        get {
            return chunkMemory[5] != 0
        }
        set {
            chunkMemory[5] = newValue ? 1 : 0
        }
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

    public func getProp() -> UiffProp? {
        // Entryのpayloads部分がなければnilを返す
        if payload.getByteSize() <= UiffEntry.HEADER_BYTESIZE {
            return nil
        }

        return UiffProp(workMemory: self.chunkMemory, offsetBytes: UiffEntry.HEADER_BYTESIZE)
    }
}

// child管理用チャンク
public struct UiffChild: UiffChunk {
    public private(set) var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offsetBytes: Int) {
        self.chunkMemory = UiffChild.assign(workMemory: workMemory, offsetBytes: offsetBytes)
    }

    // 最初の子チャンクを取得する
    public func getFirst() -> UiffChunk? {
        // 子のチャンクが存在するか確認する
        assert(0 < chunkSize, "UiffChild has no child chunks")
        if chunkSize <= 0 {
            return nil
        }

        switch chunkMemory[2] {  // 子チャンクのタイプを取得
        case UInt16(UIFF_ENTRY):
            return UiffEntry(workMemory: chunkMemory, offsetBytes: 4)
        default:
            // childの中は必ずEntryのリストのはず
            assert(false, "UiffChild must contain UiffEntry chunks")
            return nil
        }
    }
}

// プロパティ管理用チャンク
public struct UiffProp: UiffChunk {
    public private(set) var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offsetBytes: Int) {
        self.chunkMemory = UiffProp.assign(workMemory: workMemory, offsetBytes: offsetBytes)
    }
}

// 特別なType
// ****************************************************************************
// IFF_SELECTチャンク
public struct UiffSelect: UiffChunk {
    public private(set) var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offsetBytes: Int) {
        self.chunkMemory = UiffSelect.assign(workMemory: workMemory, offsetBytes: offsetBytes)
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

        var sel_item = UiffProp(workMemory: chunkMemory, offsetBytes: 2)  // sel_rowsとsel_item_numを飛ばす
        for _ in 0..<index {
            sel_item = UiffProp(workMemory: chunkMemory, offsetBytes: sel_item.chunkSize)
        }
        return sel_item
    }
}

// プロパティ各種
// ****************************************************************************
public struct UiffEvents: UiffChunk {
    public private(set) var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offsetBytes: Int) {
        self.chunkMemory = UiffEvents.assign(workMemory: workMemory, offsetBytes: offsetBytes)
    }

    public var eventNum: Int {
        return payload.getByteSize() / 2  // 1イベントあたり2バイト
    }

    public func getEventID(index: Int) -> UInt16 {
        assert(index < eventNum, "index out of range")
        return payload[index]
    }
}

public struct UiffScript: UiffChunk {
    public private(set) var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offsetBytes: Int) {
        self.chunkMemory = UiffScript.assign(workMemory: workMemory, offsetBytes: offsetBytes)
    }
}

public struct UiffColors: UiffChunk {
    public private(set) var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offsetBytes: Int) {
        self.chunkMemory = UiffColors.assign(workMemory: workMemory, offsetBytes: offsetBytes)
    }

    public var colorNum: Int {
        return payload.getByteSize() / 4  // 1色あたり4バイト
    }

    public func getColor(index: Int) -> UInt32 {
        assert(index < colorNum, "index out of range")
        let color_low = payload[index * 2]  // 1色あたり4バイト
        let color_high = payload[index * 2 + 1]
        return UInt32(color_high) << 16 | UInt32(color_low)
    }
}

public struct UiffText: UiffChunk {
    public private(set) var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offsetBytes: Int) {
        self.chunkMemory = UiffText.assign(workMemory: workMemory, offsetBytes: offsetBytes)
    }

    public var textLength: Int {
        return Int(chunkMemory[0])
    }
}
