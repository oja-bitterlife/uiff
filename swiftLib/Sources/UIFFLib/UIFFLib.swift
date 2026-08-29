// OnEntryの呼び出しを、UIFFLibIFプロトコルに準拠した型のメソッドとして呼び出すように変更
public protocol UIFFEntryHandler {
    mutating func OnUIFFEntry(lib: UIFFLib, entry: UiffEntry, propIter: UiffPropIter)
}

// UI用のUIFFデータを扱う
public struct UIFFLib {
    // MARK: - VM本体のプロパティ
    public var uiffWork: WorkMemory
    public var entryList: RingQueueMemory
    public var eventQueue: RingQueueMemory
    public var vmMem: WorkMemory
    public var vmStack: StackMemory

    // MARK: - 初期化
    // ************************************************************************
    public init(
        uiffRomAddress: UInt,  // uiffデータのROM上の先頭アドレス
        uiffWork: WorkMemory,  // 作業用メモリ。UIFFデータのコピーと各種キュー/VMが置かれる
        entryListSize: Int,  // 作用用メモリ内の中間Entryリストのサイズ
        eventQueueSize: Int,  // 作用用メモリ内のイベントキューのサイズ
        vmMemSize: Int,  // VMメモリのサイズ
        vmStackSize: Int,  // VMのスタックサイズ
    ) {
        // uiffのヘッダを解析して、必要な情報を取得する
        let uiffHeader = UiffFileHeader(address: uiffRomAddress)
        let magic_ok =
            uiffHeader.magic
            == (UInt(UInt8(ascii: "U"))
                | UInt(UInt8(ascii: "I")) << 8
                | UInt(UInt8(ascii: "F")) << 16
                | UInt(UInt8(ascii: "F")) << 24)
        if !magic_ok {
            FatalMsg("Invalid UIFF file")  // UIFF_ERR_FILE_INVALID
        }

        // workMemoryのサイズから、キューのサイズを引いた残りのサイズを計算する
        let queueTotalByteSize =
            entryListSize * 2
            + eventQueueSize * 2
            + vmMemSize * 2
            + vmStackSize * 2
        let remainingByteSize = uiffWork.getByteSize() - queueTotalByteSize

        // uiffのサイズを取得し、memSizeと比較してuiffがメモリに収まるか確認する
        let uiff_file_size = Int(uiffHeader.size)
        if uiff_file_size > remainingByteSize {
            FatalMsg("UIFF file too large")  // UIFF_ERR_FILE_TOO_LARGE
        }

        // uiffの内容を書き換え可能メモリにコピーする(状態変化対応)
        for i in 0..<uiff_file_size {
            uiffWork.writeUInt8(offset: i, value: uiffHeader.data[i])
        }

        // uiff作業用メモリ
        // 終端を確定させるためサイズはUIFFファイルサイズにする
        self.uiffWork = uiffWork.slice(byteSize: uiff_file_size)

        // 各用途のメモリを固定位置に配置する
        var addr = uiffWork.getAddress() + UInt(remainingByteSize)
        self.entryList = RingQueueMemory(address: addr, byteSize: entryListSize * 2)

        addr += UInt(self.entryList.getByteSize())
        self.eventQueue = RingQueueMemory(address: addr, byteSize: eventQueueSize * 2)

        addr += UInt(self.eventQueue.getByteSize())
        self.vmMem = WorkMemory(address: addr, byteSize: vmMemSize * 2)

        addr += UInt(self.vmMem.getByteSize())
        self.vmStack = StackMemory(address: addr, byteSize: vmStackSize * 2)
    }

    // ユーザー向け関数
    // ************************************************************************
    // MARK: - 発生したUIイベントの登録
    public mutating func notify(eventID: UInt16) {
        if eventID == 0 {
            FatalMsg("Invalid event ID")  // UIFF_ERR_EVENT_INVALID
        }

        self.eventQueue.enqueue(value: eventID)
    }

    // MARK: - UIFFの逐次処理
    public mutating func run<T: UIFFEntryHandler>(handler: T) {
        // ルートから子をトラバースして、entryQueueに積み込む
        traverseEntries(firstEntry: UiffEntry(workMemory: self.uiffWork))

        // イベントの処理
        processEvents()  // eventキューが空になるまで処理される

        // entryQueueの処理
        while !self.entryList.isEmpty() {  // entryQueueが空になるまで処理される
            // entryQueueからエントリを取り出す
            let offsetBytes = self.entryList.dequeue()
            let entry = UiffEntry(workMemory: self.uiffWork, offsetBytes: Int(offsetBytes))

            // propIterを用意する。使う時に便利用
            var propIter = UiffPropIter(workMemory: entry.payload)

            // システムで処理するプロパティは無視する
            propIter.addBlackList(eventID: UIFF_CHILD)
            propIter.addBlackList(eventID: UIFF_EVENTS)
            propIter.addBlackList(eventID: UIFF_LISTEN)

            // エントリーの処理を呼び出す
            var handler = handler  // mutatingを呼び出すためにvarにする
            handler.OnUIFFEntry(lib: self, entry: entry, propIter: propIter)
        }
    }

    // エントリートラバース用
    // ************************************************************************
    // MARK: - エントリーをentryListに積み込む
    private mutating func appendEntry(entry: UiffEntry) {
        // Entryのオフセットアドレスを記録する
        let offsetBytes = entry.chunkMemory.getAddress() - self.uiffWork.getAddress()

        if offsetBytes > 0xffff {
            FatalMsg("UIFF child chunk offset exceeds UInt16 max value")  // UIFF子チャンクのオフセットがUInt16の最大値を超える
        }

        self.entryList.enqueue(value: UInt16(offsetBytes))
    }

    // entryQueueに積み込むだけ
    private mutating func traverseEntries(firstEntry: UiffEntry) {
        // 兄弟Entryを先に処理する
        // ----------------------------------------------------------
        var entryIter = UiffEntryIter(workMemory: firstEntry.chunkMemory)
        while let entry = entryIter.next() {
            appendEntry(entry: entry)
        }

        // 子Entryを処理する
        // ----------------------------------------------------------
        entryIter = UiffEntryIter(workMemory: firstEntry.chunkMemory)
        while let entry = entryIter.next() {
            // propertiesからプロパティを取得する
            var propIter = UiffPropIter(workMemory: entry.payload)
            while let prop = propIter.next() {
                // 子があれば再帰
                if prop.chunkType == UInt16(UIFF_CHILD) {
                    let children = UiffChild(workMemory: prop.chunkMemory)
                    if let first_child = children.getFirstEntry() {
                        traverseEntries(firstEntry: first_child)  // 再帰呼び出し
                    }
                }
            }
        }
    }

    // イベントの処理
    // ************************************************************************
    private mutating func processEvents() {
        // 現在のイベントのクリア
        for i in 0..<self.entryList.getLength() {
            let offsetBytes = self.entryList.peek(index: i)
            var entry = UiffEntry(workMemory: self.uiffWork, offsetBytes: Int(offsetBytes))
            entry.recvEventID = 0
        }

        // イベントをEntryに配っていく
        while !self.eventQueue.isEmpty() {
            let eventID = self.eventQueue.dequeue()
            if eventID == 0 { continue }  // 無効なイベントは無視する

            // 後ろから前へ、つまり子を優先する。子で消費したら親へは届かない
            for i in stride(from: self.entryList.getLength() - 1, through: 0, by: -1) {
                let offsetBytes = self.entryList.peek(index: i)
                var entry = UiffEntry(workMemory: self.uiffWork, offsetBytes: Int(offsetBytes))

                // Listenerがあれば処理する
                if hasListener(entry: entry, eventID: eventID) {
                    entry.recvEventID = eventID
                }
                // Eventがあれば処理する
                if hasEvent(entry: entry, eventID: eventID) {
                    entry.recvEventID = eventID
                    break  // Eventはブロック
                }
            }
        }
    }

    // MARK: - UIFFのイベントブロッカー有無チェック
    public func hasEvent(entry: UiffEntry, eventID: UInt16) -> Bool {
        var propIter = UiffPropIter(workMemory: entry.payload)
        while let prop = propIter.next() {
            if prop.chunkType == UIFF_EVENTS {
                let events = UiffEvents(workMemory: prop.chunkMemory)
                if events.hasEventID(eventID: eventID) {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - UIFFのイベントリスナーの有無チェック
    public func hasListener(entry: UiffEntry, eventID: UInt16) -> Bool {
        var propIter = UiffPropIter(workMemory: entry.payload)
        while let prop = propIter.next() {
            if prop.chunkType == UIFF_LISTEN {
                let listen = UiffListen(workMemory: prop.chunkMemory)
                if listen.hasEventID(eventID: eventID) {
                    return true
                }
            }
        }
        return false
    }

}
