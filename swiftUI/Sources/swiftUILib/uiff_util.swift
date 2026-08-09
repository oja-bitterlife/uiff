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
    static let HEADER_BYTESIZE = 10 * 2  // ヘッダのサイズ(バイト単位)
    public private(set) var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offsetBytes: Int = 0) {
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

    // Entryはヘッダの後をpayloadとして扱う
    public var payload: WorkMemory {
        return WorkMemory(
            address: chunkMemory.getAddress() + UInt(UiffEntry.HEADER_BYTESIZE),
            byteSize: chunkSize - UiffEntry.HEADER_BYTESIZE)
    }

    public func getNextEntry() -> UiffEntry? {
        if chunkMemory.getByteSize() <= chunkSize {
            return nil  // 次のチャンクが存在しない場合はnilを返す
        }
        return UiffEntry(workMemory: chunkMemory, offsetBytes: chunkSize)
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
        print("size: \(chunkMemory.getByteSize()), offset: \(offsetBytes)")
    }

    public mutating func next() -> UiffProp? {
        // 終端に達した
        if chunkMemory.getByteSize() <= offsetBytes {
            return nil
        }

        // プロパティチャンクを返す
        let prop = UiffProp(workMemory: chunkMemory, offsetBytes: offsetBytes)
        print(
            "  prop type: \(prop.chunkType), size: 4+\(prop.chunkSize-4) bytes, next: \(offsetBytes + prop.chunkSize)/\(chunkMemory.getByteSize())"
        )
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
        self.chunkMemory = UiffChild.assign(workMemory: workMemory, offsetBytes: offsetBytes)
    }

    // 最初の子チャンクを取得する
    public func getFirstEntry() -> UiffEntry? {
        // 子のチャンクが存在するか確認する
        assert(0 < chunkSize, "UiffChild has no child chunks")
        if chunkSize <= 0 {
            return nil
        }

        // 子チャンクのタイプを確認
        assert(chunkMemory[2] == UIFF_ENTRY, "UiffChild must contain UiffEntry chunks")
        if chunkMemory[2] != UIFF_ENTRY {
            return nil
        }

        return UiffEntry(workMemory: chunkMemory, offsetBytes: 4)  // childのヘッダ4バイトを飛ばす
    }
}

public struct UiffEvents: UiffChunk {
    public private(set) var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offsetBytes: Int = 0) {
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

    public init(workMemory: WorkMemory, offsetBytes: Int = 0) {
        self.chunkMemory = UiffScript.assign(workMemory: workMemory, offsetBytes: offsetBytes)
    }
}

public struct UiffColors: UiffChunk {
    public private(set) var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offsetBytes: Int = 0) {
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
        self.chunkMemory = UiffText.assign(workMemory: workMemory, offsetBytes: offsetBytes)
    }

    public var textLength: Int {
        return Int(chunkMemory[0])
    }
}
