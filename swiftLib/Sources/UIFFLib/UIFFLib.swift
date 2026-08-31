// UI用のUIFFデータを扱う
public struct UIFFLib {
    // MARK: - VM本体のプロパティ
    public var uiffWorkMemory: WorkMemory

    // 個別用途スライス
    public var entryList: RingQueueMemory
    public var eventQueue: RingQueueMemory
    public var uiffData: WorkMemory

    // MARK: - 初期化
    // ************************************************************************
    public init(
        uiffWorkMemory: WorkMemory,  // 作業用メモリ。UIFFデータのコピーと各種キュー/VMが置かれる
        entryListSize: Int = 64,  // 作用用メモリ内の中間Entryリストのサイズ
        eventQueueSize: Int = 32,  // 作用用メモリ内のイベントキューのサイズ
        uiffRomAddress: UInt? = nil,  // uiffデータのROM上の先頭アドレス
    ) {
        // 各メモリ割り当て
        self.uiffWorkMemory = uiffWorkMemory
        self.entryList = RingQueueMemory(self.uiffWorkMemory.pop(byteSize: entryListSize * 2))
        self.eventQueue = RingQueueMemory(self.uiffWorkMemory.pop(byteSize: eventQueueSize * 2))
        self.uiffData = self.uiffWorkMemory.slice(offset: 0)  // 一旦残り全部で初期化

        // ROMからUIFFのデータを読み込む
        if uiffRomAddress != nil {
            load(uiffRomAddress: uiffRomAddress!)
        }
    }

    // UIFFデータをROMから読み込む
    public mutating func load(uiffRomAddress: UInt) {
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

        // データ置き場サイズ修正
        self.uiffData = self.uiffWorkMemory.slice(byteSize: Int(uiffHeader.size))

        // uiffの内容をROMからEWRAMにコピーする(状態変化対応)
        for i in 0..<Int(uiffHeader.size / 2) {
            self.uiffData[i] = uiffHeader.data[i]
        }

        // ルートから子をトラバースして、entryQueueに積み込んでおく
        // 入れ替え対応をしてないので基本的に処理順は変わらないはず
        traverseEntries(entries: UiffEntry(workMemory: self.uiffData))
    }

    // MARK: EntryをトラバースしてentryQueueに積み込む
    // ------------------------------------------------------------------------
    // entryを再帰的にトラバース
    private func traverseEntries(entries: UiffEntry) {
        // 兄弟Entryを先に処理する
        // ----------------------------------------------------------
        var entryList = self.entryList
        var entryIter = UiffEntryIter(workMemory: entries.chunkMemory)
        while let entry = entryIter.next() {
            let offsetBytes = entry.chunkMemory.getAddress() - self.uiffData.getAddress()
            entryList.enqueue(UInt16(offsetBytes))
        }

        // 子Entryを処理する
        // ----------------------------------------------------------
        entryIter = UiffEntryIter(workMemory: entries.chunkMemory)
        while let entry = entryIter.next() {
            // propertiesからプロパティを取得する
            var propIter = UiffPropIter(workMemory: entry.payload)
            while let prop = propIter.next() {
                // 子があれば再帰
                if prop.getChunkType() == UInt16(UIFF_CHILD) {
                    let children = UiffChild(workMemory: prop.chunkMemory)
                    if let first_child = children.getFirstEntry() {
                        traverseEntries(entries: first_child)  // 再帰呼び出し
                    }
                }
            }
        }
    }

    // イベントの割り当て処理
    // ************************************************************************
    private func processEvents() {
        // 現在のイベントのクリア
        for i in 0..<self.entryList.getLength() {
            let offsetBytes = self.entryList.peek(i)
            var entry = UiffEntry(workMemory: self.uiffData, offsetBytes: Int(offsetBytes))
            entry.recvEventID = 0
        }

        // イベントをEntryに配っていく
        var eventQueue = self.eventQueue
        while !eventQueue.isEmpty() {
            let eventID = eventQueue.dequeue()
            if eventID == 0 { continue }  // 無効なイベントは無視する

            // 後ろから前へ、つまり子を優先する。子で消費したら親へは届かない
            for i in stride(from: self.entryList.getLength() - 1, through: 0, by: -1) {
                let offsetBytes = self.entryList.peek(i)
                var entry = UiffEntry(workMemory: self.uiffData, offsetBytes: Int(offsetBytes))

                // Listenerがあれば処理する
                if hasListener(entry: entry, eventID: eventID) {
                    entry.recvEventID = eventID
                }
                // Eventがあれば処理する
                if hasEventBlocker(entry: entry, eventID: eventID) {
                    entry.recvEventID = eventID
                    break  // Eventはブロック
                }
            }
        }
    }

    // ユーザー向け関数
    // ************************************************************************
    // MARK: - 発生したUIイベントの登録
    public func notify(eventID: UInt16) {
        if eventID == 0 {
            FatalMsg("Invalid event ID")  // UIFF_ERR_EVENT_INVALID
        }

        var eventQueue = self.eventQueue
        eventQueue.enqueue(eventID)
    }

    // MARK: - UIFFの逐次処理
    public func run<T>(
        with: inout T, onEntry: (inout T, inout UiffEntry, UiffPropIter) -> Void
    ) {
        // イベントの割り当て処理
        processEvents()  // eventキューが空になるまで処理される

        // entryQueueの処理
        for i in 0..<self.entryList.getLength() {
            // entryQueueからエントリを取り出す
            let offsetBytes = self.entryList.peek(i)
            var entry = UiffEntry(workMemory: self.uiffData, offsetBytes: Int(offsetBytes))

            // propIterを用意する。使う時に便利用
            var propIter = UiffPropIter(workMemory: entry.payload)

            // システムで処理するプロパティは無視する
            propIter.addBlackList(eventID: UIFF_CHILD)
            propIter.addBlackList(eventID: UIFF_EVENTS)
            propIter.addBlackList(eventID: UIFF_LISTEN)

            // エントリーの処理を呼び出す
            onEntry(&with, &entry, propIter)
        }
    }

    public func run(onEntry: (inout UiffEntry, UiffPropIter) -> Void) {
        // caller不要版
        var dummy: Void = ()
        self.run(with: &dummy) { _, entry, propIter in
            onEntry(&entry, propIter)
        }
    }

    // MARK: - UIFFのイベントブロッカー有無チェック
    public func hasEventBlocker(entry: UiffEntry, eventID: UInt16) -> Bool {
        var propIter = UiffPropIter(workMemory: entry.payload)
        while let prop = propIter.next() {
            if prop.getChunkType() == UIFF_EVENTS {
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
            if prop.getChunkType() == UIFF_LISTEN {
                let listen = UiffListen(workMemory: prop.chunkMemory)
                if listen.hasEventID(eventID: eventID) {
                    return true
                }
            }
        }
        return false
    }

}
