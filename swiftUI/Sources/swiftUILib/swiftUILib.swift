import swiftVMLib

public struct swiftUILib {
    // MARK: - VM本体のプロパティ
    public var uiffWork: WorkMemory
    public var entryList: RingQueueMemory
    public var eventQueue: RingQueueMemory
    public var vmWork: WorkMemory
    public var vmStack: WorkMemory

    // MARK: - 初期化
    // ************************************************************************
    public init(
        uiffRomAddress: UInt,  // uiffデータのROM上の先頭アドレス
        workMemoryAddress: UInt,  // 作業用メモリの先頭アドレス
        workMemorySize: Int,  // 作業用メモリの総サイズ
        entryListSize: Int,  // 作用用メモリ内の中間Entryリストのサイズ
        eventQueueSize: Int,  // 作用用メモリ内のイベントキューのサイズ
        vmWorkSize: Int,  // VMメモリのサイズ
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
        assert(magic_ok, "Invalid uiff file")
        if !magic_ok {
            WorkMemory.onFatal(code: UIFF_ERR_FILE_INVALID)
        }

        // workMemoryのサイズから、キューのサイズを引いた残りのサイズを計算する
        let queueTotalByteSize =
            ExpandEven(value: entryListSize)
            + ExpandEven(value: eventQueueSize)
            + ExpandEven(value: vmWorkSize)
            + ExpandEven(value: vmStackSize)
        let remainingByteSize = workMemorySize - queueTotalByteSize

        // uiffのサイズを取得し、memSizeと比較してuiffがメモリに収まるか確認する
        let uiff_size = Int(uiffHeader.size)
        assert(uiff_size <= remainingByteSize, "UIFF size exceeds memory size")
        if uiff_size > remainingByteSize {
            WorkMemory.onFatal(code: UIFF_ERR_FILE_TOO_LARGE)
        }

        // uiffの内容を書き換え可能メモリにコピーする(状態変化対応)
        if let mem_ptr = UnsafeMutablePointer<UInt8>(bitPattern: workMemoryAddress) {
            for i in 0..<uiff_size {
                mem_ptr[i] = uiffHeader.data[i]  // UIFFのデータ部をコピー
            }
        } else {
            assert(false, "Failed to create memory pointer for work memory")
            WorkMemory.onFatal(code: MEM_ERR_INVALID_ADDRESS)  // 作業用メモリのポインタ作成失敗
        }

        // uiff作業用メモリ
        self.uiffWork = WorkMemory(address: workMemoryAddress, byteSize: uiff_size)

        // 各用途のメモリを固定位置に配置する
        var queueOffset = workMemoryAddress + UInt(remainingByteSize)
        self.entryList = RingQueueMemory(
            address: queueOffset, byteSize: ExpandEven(value: entryListSize))
        queueOffset += UInt(self.entryList.getByteSize())
        self.eventQueue = RingQueueMemory(
            address: queueOffset, byteSize: ExpandEven(value: eventQueueSize))
        queueOffset += UInt(self.eventQueue.getByteSize())
        self.vmWork = WorkMemory(address: queueOffset, byteSize: ExpandEven(value: vmWorkSize))
        queueOffset += UInt(self.vmWork.getByteSize())
        self.vmStack = WorkMemory(address: queueOffset, byteSize: ExpandEven(value: vmStackSize))
        queueOffset += UInt(self.vmStack.getByteSize())
    }

    // ユーザー向け関数
    // ************************************************************************
    // MARK: - ルートチャンクの取得。Entryのはず
    public func getRoot() -> UiffEntry {
        return UiffEntry(workMemory: self.uiffWork)
    }

    // MARK: - 発生したUIイベントの登録
    public mutating func notify(eventID: UInt16) {
        assert(eventID != 0, "Invalid eventID: 0")
        if eventID == 0 {
            WorkMemory.onFatal(code: UIFF_ERR_EVENT_INVALID)  // 無効なイベントID
        }

        self.eventQueue.enqueue(value: eventID)
    }

    // MARK: - UIFFの逐次処理
    public mutating func run(
        firstEntry: UiffEntry,
        onEntry: (swiftUILib, UiffEntry, UiffPropIter) -> Void
    ) {
        // ルートから子をトラバースして、entryQueueに積み込む
        traverseEntries(firstEntry: firstEntry)

        // イベントの処理
        processEvents()  // eventキューが空になるまで処理される

        // entryQueueの処理
        while !self.entryList.isEmpty() {  // entryQueueが空になるまで処理される
            // entryQueueからエントリを取り出す
            let offsetBytes = self.entryList.dequeue()
            let entry = UiffEntry(workMemory: self.uiffWork, offsetBytes: Int(offsetBytes))

            // propIterを用意する。使う時に便利用
            var propIter = UiffPropIter(workMemory: entry.payload)
            propIter.setBlackList(blackList: [UIFF_CHILD, UIFF_EVENTS, UIFF_LISTEN])  // 子チャンク、イベントチャンク、リスナーチャンクは無視する

            // エントリーの処理を呼び出す
            onEntry(self, entry, propIter)
        }
    }

    // エントリートラバース用
    // ************************************************************************
    // MARK: - エントリーをentryListに積み込む
    private mutating func appendEntry(entry: UiffEntry) {
        // Entryのオフセットアドレスを記録する
        let offsetBytes = entry.chunkMemory.getAddress() - self.uiffWork.getAddress()

        assert(offsetBytes <= 0xffff, "UIFF child chunk offset exceeds UInt16 max")
        if offsetBytes > 0xffff {
            WorkMemory.onFatal(code: UIFF_ERR_CHUNK_INVALID)  // UIFF子チャンクのオフセットがUInt16の最大値を超える
        }

        self.entryList.enqueue(value: UInt16(offsetBytes))
    }

    // entryQueueに積み込むだけ
    private mutating func traverseEntries(firstEntry: UiffEntry) {
        // 兄弟Entryを先に処理する
        // ----------------------------------------------------------
        for entry in UiffEntryIter(workMemory: firstEntry.chunkMemory) {
            appendEntry(entry: entry)
        }

        // 子Entryを処理する
        // ----------------------------------------------------------
        for entry in UiffEntryIter(workMemory: firstEntry.chunkMemory) {
            // propertiesからプロパティを取得する
            for prop in UiffPropIter(workMemory: entry.payload) {
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
        for prop in UiffPropIter(workMemory: entry.payload) {
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
        for prop in UiffPropIter(workMemory: entry.payload) {
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
