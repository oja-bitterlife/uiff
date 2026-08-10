// uiffチャンクの操作

// 定数
// ****************************************************************************
// SYSTEM_TYPEの定義
public let ENTRY_TYPE_LAYOUT: UInt16 = 1
public let ENTRY_TYPE_WINDOW: UInt16 = 2
public let ENTRY_TYPE_LABEL: UInt16 = 3
public let ENTRY_TYPE_SELECT: UInt16 = 4

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
        assert(offsetBytes % 2 == 0, "offsetBytes must be even")
        if offsetBytes % 2 != 0 {
            WorkMemory.onFatal(code: MEM_ERR_INVALID_ADDRESS)  // 偶数バイト境界でない
        }

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
            address: chunkMemory.getAddress() + 4,  // ヘッダの4バイトを加える
            byteSize: Int(chunkMemory[1]))
    }
}

// 基本的なデータアクセス
// ****************************************************************************
// Enetry単位アクセス用チャンク
public struct UiffEntry: UiffChunk {
    static let HEADER_BYTESIZE = 11 * 2  // ヘッダのサイズ(バイト単位)
    public private(set) var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offsetBytes: Int = 0) {
        // 子チャンクのタイプを確認
        assert(workMemory[offsetBytes / 2] == UIFF_ENTRY, "UiffEntry must start with UIFF_ENTRY")
        if workMemory[offsetBytes / 2] != UIFF_ENTRY {
            WorkMemory.onFatal(code: UIFF_ERR_CHUNK_INVALID)  // UiffEntry must start with UIFF_ENTRY
        }

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

    public var x: Int {
        return Int(chunkMemory[6])
    }

    public var y: Int {
        return Int(chunkMemory[7])
    }

    public var w: Int {
        return Int(chunkMemory[8])
    }

    public var h: Int {
        return Int(chunkMemory[9])
    }

    // Runtime用。受信したイベントID
    public var recvEventID: UInt16 {
        get {
            return chunkMemory[10]
        }
        set {
            chunkMemory[10] = newValue
        }
    }

    // Entryはヘッダの後をpayloadとして扱う
    public var payload: WorkMemory {
        return WorkMemory(
            address: chunkMemory.getAddress() + UInt(UiffEntry.HEADER_BYTESIZE),
            byteSize: chunkSize - UiffEntry.HEADER_BYTESIZE)
    }
}

// Entryのイテレータ
public struct UiffEntryIter {
    public private(set) var chunkMemory: WorkMemory
    var offsetBytes: Int

    public init(workMemory: WorkMemory, offsetBytes: Int = 0) {
        self.chunkMemory = workMemory
        self.offsetBytes = offsetBytes
    }

    public mutating func next() -> UiffEntry? {
        // 終端に達した
        if chunkMemory.getByteSize() <= offsetBytes {
            return nil
        }

        // Entryチャンクを返す
        let entry = UiffEntry(workMemory: chunkMemory, offsetBytes: offsetBytes)
        offsetBytes += entry.chunkSize  // 次のEntryチャンクのオフセットを更新する
        return entry
    }
}

// Entryのpropertysを扱う
// ****************************************************************************
// プロパティ管理用チャンク
public struct UiffPropIter {
    public private(set) var chunkMemory: WorkMemory
    var offsetBytes: Int

    public init(workMemory: WorkMemory, offsetBytes: Int = 0) {
        self.chunkMemory = workMemory
        self.offsetBytes = offsetBytes
    }

    public mutating func next() -> UiffProp? {
        // 終端に達した
        if chunkMemory.getByteSize() <= offsetBytes {
            return nil
        }

        // プロパティチャンクを返す
        let prop = UiffProp(workMemory: chunkMemory, offsetBytes: offsetBytes)
        offsetBytes += prop.chunkSize  // 次のプロパティチャンクのオフセットを更新する
        return prop
    }
}

// propertys用
public struct UiffProp: UiffChunk {
    public private(set) var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offsetBytes: Int = 0) {
        self.chunkMemory = UiffProp.assign(workMemory: workMemory, offsetBytes: offsetBytes)
    }
}

// 特別なType
// ****************************************************************************
// IFF_SELECTチャンク
public struct UiffSelect: UiffChunk {
    public private(set) var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offsetBytes: Int = 0) {
        assert(workMemory[0] == UIFF_SELECT, "UiffSelect must start with UIFF_SELECT")
        if workMemory[0] != UIFF_SELECT {
            WorkMemory.onFatal(code: UIFF_ERR_CHUNK_INVALID)  // UiffSelect must start with UIFF_SELECT
        }

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
// child管理プロパティ
public struct UiffChild: UiffChunk {
    public private(set) var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offsetBytes: Int = 0) {
        assert(workMemory[0] == UIFF_CHILD, "UiffChild must start with UIFF_CHILD")
        if workMemory[0] != UIFF_CHILD {
            WorkMemory.onFatal(code: UIFF_ERR_CHUNK_INVALID)  // UiffChild
        }

        self.chunkMemory = UiffChild.assign(workMemory: workMemory, offsetBytes: offsetBytes)
    }

    // 最初の子チャンクを取得する
    public func getFirstEntry() -> UiffEntry? {
        // 子のチャンクが存在するか確認する
        assert(0 < chunkSize, "UiffChild has no child chunks")
        if chunkSize <= 0 {
            return nil
        }

        return UiffEntry(workMemory: chunkMemory, offsetBytes: 4)  // childのヘッダ4バイトを飛ばす
    }
}

public struct UiffEvents: UiffChunk {
    public private(set) var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offsetBytes: Int = 0) {
        assert(workMemory[0] == UIFF_EVENTS, "UiffEvents must start with UIFF_EVENTS")
        if workMemory[0] != UIFF_EVENTS {
            WorkMemory.onFatal(code: UIFF_ERR_CHUNK_INVALID)  // UiffEvents
        }

        self.chunkMemory = UiffEvents.assign(workMemory: workMemory, offsetBytes: offsetBytes)
    }

    public var eventNum: Int {
        return payload.getByteSize() / 2  // 1イベントあたり2バイト
    }

    public func getEventID(index: Int) -> UInt16 {
        assert(index < eventNum, "index out of range")
        return payload[index]
    }

    public func hasEvent(eventID: UInt16) -> Bool {
        for i in 0..<eventNum {
            if getEventID(index: i) == eventID {
                return true
            }
        }
        return false
    }
}

public struct UiffListen: UiffChunk {
    public private(set) var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offsetBytes: Int = 0) {
        assert(workMemory[0] == UIFF_LISTEN, "UiffListen must start with UIFF_LISTEN")
        if workMemory[0] != UIFF_LISTEN {
            WorkMemory.onFatal(code: UIFF_ERR_CHUNK_INVALID)  // UiffListen
        }

        self.chunkMemory = UiffListen.assign(workMemory: workMemory, offsetBytes: offsetBytes)
    }

    public var eventNum: Int {
        return payload.getByteSize() / 2  // 1イベントあたり2バイト
    }

    public func getEventID(index: Int) -> UInt16 {
        assert(index < eventNum, "index out of range")
        return payload[index]
    }

    public func hasEvent(eventID: UInt16) -> Bool {
        for i in 0..<eventNum {
            if getEventID(index: i) == eventID {
                return true
            }
        }
        return false
    }
}

public struct UiffScript: UiffChunk {
    public private(set) var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offsetBytes: Int = 0) {
        assert(workMemory[0] == UIFF_SCRIPT, "UiffScript must start with UIFF_SCRIPT")
        if workMemory[0] != UIFF_SCRIPT {
            WorkMemory.onFatal(code: UIFF_ERR_CHUNK_INVALID)  // UiffScript
        }

        self.chunkMemory = UiffScript.assign(workMemory: workMemory, offsetBytes: offsetBytes)
    }
}

public struct UiffColors: UiffChunk {
    public private(set) var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offsetBytes: Int = 0) {
        assert(workMemory[0] == UIFF_COLORS, "UiffColors must start with UIFF_COLORS")
        if workMemory[0] != UIFF_COLORS {
            WorkMemory.onFatal(code: UIFF_ERR_CHUNK_INVALID)  // UiffColors
        }

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

    public init(workMemory: WorkMemory, offsetBytes: Int = 0) {
        assert(workMemory[0] == UIFF_TEXT, "UiffText must start with UIFF_TEXT")
        if workMemory[0] != UIFF_TEXT {
            WorkMemory.onFatal(code: UIFF_ERR_CHUNK_INVALID)  // UiffText
        }

        self.chunkMemory = UiffText.assign(workMemory: workMemory, offsetBytes: offsetBytes)
    }

    public var textLength: Int {
        return Int(chunkMemory[0])
    }
}
