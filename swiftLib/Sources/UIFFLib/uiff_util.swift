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
        if let ptr = UnsafeMutablePointer<UInt16>(bitPattern: address) {
            self.ptr = ptr
        } else {
            FatalMsg("Invalid memory address")
        }
    }

    public var magic: UInt {
        return UInt(ptr[0] & 0xff) | (UInt(ptr[0] >> 8) << 8) | (UInt(ptr[1] & 0xff) << 16)
            | (UInt(ptr[1] >> 8) << 24)
    }

    public var size: UInt16 {
        return ptr[2]
    }

    public var data: UnsafeMutablePointer<UInt8> {
        let data_offset: UInt = 4 + 2  // magic + size
        if let ptr = UnsafeMutablePointer<UInt8>(
            bitPattern: UInt(bitPattern: self.ptr) + data_offset)
        {
            return ptr
        } else {
            FatalMsg("Invalid memory address")
        }
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
        if offsetBytes % 2 != 0 {
            FatalMsg("Invalid memory address")  // 偶数バイト境界でない
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
        if workMemory[offsetBytes / 2] != UIFF_ENTRY {
            FatalMsg("UiffEntry must start with UIFF_ENTRY")  // UiffEntry must start with UIFF_ENTRY
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
    private var offsetBytes: Int

    public init(workMemory: WorkMemory, offsetBytes: Int = 0) {
        self.chunkMemory = workMemory
        self.offsetBytes = offsetBytes
    }

    public mutating func next() -> UiffEntry? {
        while chunkMemory.getByteSize() > offsetBytes {
            let entry = UiffEntry(workMemory: chunkMemory, offsetBytes: offsetBytes)
            offsetBytes += entry.chunkSize
            return entry
        }
        return nil
    }
}

// Entryのpropertysを扱う
// ****************************************************************************
// プロパティ管理用チャンク
public struct UiffPropIter {
    public private(set) var chunkMemory: WorkMemory
    private var offsetBytes: Int

    /// ブラックリスト。ここに含まれるchunkTypeは無視する。最大8個まで
    private var blackListBuf:
        (
            UInt16, UInt16, UInt16, UInt16,
            UInt16, UInt16, UInt16, UInt16,
        ) = (0, 0, 0, 0, 0, 0, 0, 0)
    private var blackList: RingQueueMemory

    public init(workMemory: WorkMemory, offsetBytes: Int = 0) {
        self.chunkMemory = workMemory
        self.offsetBytes = offsetBytes

        // 8個のUInt16を格納するリングバッファ
        let blackListPtr = withUnsafeMutablePointer(to: &self.blackListBuf) { ptr in
            UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: UInt8.self)
        }
        self.blackList = RingQueueMemory(address: UInt(bitPattern: blackListPtr), byteSize: 8 * 2)
    }

    public mutating func addBlackList(eventID: UInt16) {
        blackList.enqueue(value: eventID)
    }
    public mutating func clearBlackList() {
        blackList.clear()
    }

    public mutating func next() -> UiffProp? {
        while chunkMemory.getByteSize() > offsetBytes {
            let prop = UiffProp(workMemory: chunkMemory, offsetBytes: offsetBytes)
            offsetBytes += prop.chunkSize

            if !blackList.contains(value: prop.chunkType) {
                return prop
            }
        }
        return nil
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
        if workMemory[0] != UIFF_SELECT_INFO {
            FatalMsg("UiffSelect must start with UIFF_SELECT")  // UiffSelect must start with UIFF_SELECT
        }

        self.chunkMemory = UiffSelect.assign(workMemory: workMemory, offsetBytes: offsetBytes)
    }

    // 選択肢を横に並べる数
    public var selRows: Int {
        return Int(chunkMemory[0])
    }

    public var selItemNum: Int {
        return Int(chunkMemory[1])
    }

    public func getSelItem(index: Int) -> UiffProp {
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
        if workMemory[0] != UIFF_CHILD {
            FatalMsg("UiffChild must start with UIFF_CHILD")  // UiffChild
        }

        self.chunkMemory = UiffChild.assign(workMemory: workMemory, offsetBytes: offsetBytes)
    }

    // 最初の子チャンクを取得する
    public func getFirstEntry() -> UiffEntry? {
        // 子のチャンクが存在するか確認する
        if chunkSize <= 0 {
            return nil
        }

        return UiffEntry(workMemory: chunkMemory, offsetBytes: 4)  // childのヘッダ4バイトを飛ばす
    }
}

public struct UiffEvents: UiffChunk {
    public private(set) var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offsetBytes: Int = 0) {
        if workMemory[0] != UIFF_EVENTS {
            FatalMsg("UiffEvents must start with UIFF_EVENTS")  // UiffEvents
        }

        self.chunkMemory = UiffEvents.assign(workMemory: workMemory, offsetBytes: offsetBytes)
    }

    public func getEventNum() -> Int {
        return payload.getByteSize() / 2  // 1イベントあたり2バイト
    }

    public func getEventID(index: Int) -> UInt16 {
        return payload[index]
    }

    public func hasEventID(eventID: UInt16) -> Bool {
        for i in 0..<getEventNum() {
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
        if workMemory[0] != UIFF_LISTEN {
            FatalMsg("UiffListen must start with UIFF_LISTEN")  // UiffListen
        }

        self.chunkMemory = UiffListen.assign(workMemory: workMemory, offsetBytes: offsetBytes)
    }

    public func getEventNum() -> Int {
        return payload.getByteSize() / 2  // 1イベントあたり2バイト
    }

    public func getEventID(index: Int) -> UInt16 {
        return payload[index]
    }

    public func hasEventID(eventID: UInt16) -> Bool {
        for i in 0..<getEventNum() {
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
        if workMemory[0] != UIFF_SCRIPT {
            FatalMsg("UiffScript must start with UIFF_SCRIPT")  // UiffScript
        }

        self.chunkMemory = UiffScript.assign(workMemory: workMemory, offsetBytes: offsetBytes)
    }

    public func run(lib: UIFFLib) -> Int {
        // VMの初期化
        var vm = PYVM(
            codeAddress: payload.getAddress(),
            stackAddress: lib.vmStack.getAddress(), stackByteSize: lib.vmStack.getByteSize(),
            memAddress: lib.vmWork.getAddress(), memByteSize: lib.vmWork.getByteSize()
        )

        // VMの実行
        while vm.step() {}

        // VMの結果を返す
        return vm.result()
    }
}

public struct UiffColors: UiffChunk {
    public private(set) var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offsetBytes: Int = 0) {
        if workMemory[0] != UIFF_COLORS {
            FatalMsg("UiffColors must start with UIFF_COLORS")  // UiffColors
        }

        self.chunkMemory = UiffColors.assign(workMemory: workMemory, offsetBytes: offsetBytes)
    }

    public func getColorNum() -> Int {
        return payload.getByteSize() / 4  // 1色あたり4バイト
    }

    public func getColor(index: Int) -> UInt {
        let color_low = payload[index * 2]  // 1色あたり4バイト
        let color_high = payload[index * 2 + 1]
        return UInt(color_high) << 16 | UInt(color_low)
    }
}

public struct UiffText: UiffChunk {
    public private(set) var chunkMemory: WorkMemory

    public init(workMemory: WorkMemory, offsetBytes: Int = 0) {
        if workMemory[0] != UIFF_TEXT {
            FatalMsg("UiffText must start with UIFF_TEXT")  // UiffText
        }

        self.chunkMemory = UiffText.assign(workMemory: workMemory, offsetBytes: offsetBytes)
    }

    public func getTextLength() -> Int {
        return payload.getByteSize() - 2  // textLengthの2バイトを減らす
    }

    public func getTextAddr() -> UInt {
        return payload.getAddress() + 2  // textLengthの2バイトを飛ばす
    }
}
