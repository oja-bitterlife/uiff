public struct swiftUILib {
    // MARK: - VM本体のプロパティ
    public var uiffWork: WorkMemory
    public var entryQueue: RingQueueMemory
    public var eventQueue: RingQueueMemory
    public var vmMemory: WorkMemory

    // MARK: - 初期化
    // ************************************************************************
    public init(
        uiffRomAddress: UInt,  // uiffデータのROM上の先頭アドレス
        workMemoryAddress: UInt,  // 作業用メモリの先頭アドレス
        workMemorySize: Int,  // 作業用メモリの総サイズ
        entryWorkSize: Int,  // 作用用メモリ内の子キューのサイズ
        eventWorkSize: Int,  // 作用用メモリ内のイベントキューのサイズ
        vmWorkSize: Int  // VMの作業用メモリのサイズ
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
            ExpandEven(value: entryWorkSize)
            + ExpandEven(value: eventWorkSize)
            + ExpandEven(value: vmWorkSize)
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
        self.entryQueue = RingQueueMemory(
            address: queueOffset, byteSize: ExpandEven(value: entryWorkSize))
        queueOffset += UInt(self.entryQueue.getByteSize())
        self.eventQueue = RingQueueMemory(
            address: queueOffset, byteSize: ExpandEven(value: eventWorkSize))
        queueOffset += UInt(self.eventQueue.getByteSize())
        self.vmMemory = WorkMemory(address: queueOffset, byteSize: ExpandEven(value: vmWorkSize))
    }

    // ユーザー向け関数
    // ************************************************************************
    // MARK: - ルートチャンクの取得。Entryのはず
    public func getRoot() -> UiffEntry {
        return UiffEntry(workMemory: self.uiffWork)
    }

    // MARK: - 発生したUIイベントの登録
    public mutating func notify(eventID: UInt16) {
        self.eventQueue.enqueue(value: eventID)
    }

    // MARK: - UIFFの逐次処理
    public mutating func run(firstEntry: UiffEntry, onEntry: (UiffEntry, UiffPropIter) -> Void) {
        // ルートから子をトラバースして、entryQueueに積み込む
        traverseEntries(firstEntry: firstEntry)

        // イベントの処理
        processEvents()  // eventキューが空になるまで処理される

        // entryQueueの処理
        while !self.entryQueue.isEmpty() {  // entryQueueが空になるまで処理される
            // entryQueueからエントリを取り出して処理
            let offsetBytes = self.entryQueue.dequeue()
            let entry = UiffEntry(workMemory: self.uiffWork, offsetBytes: Int(offsetBytes))
            let propIter = UiffPropIter(workMemory: entry.payload)
            onEntry(entry, propIter)
        }
    }

    // MARK: - UIFFの子チャンクのキュー処理
    private mutating func enqueueEntry(entry: UiffEntry) {
        // キューにチャンクのオフセットアドレスをエンキューする
        let offsetBytes = entry.chunkMemory.getAddress() - self.uiffWork.getAddress()

        assert(offsetBytes <= 0xffff, "UIFF child chunk offset exceeds UInt16 max")
        if offsetBytes > 0xffff {
            WorkMemory.onFatal(code: UIFF_ERR_CHUNK_INVALID)  // UIFF子チャンクのオフセットがUInt16の最大値を超える
        }

        self.entryQueue.enqueue(value: UInt16(offsetBytes))
    }

    // entryQueueに積み込むだけ
    private mutating func traverseEntries(
        firstEntry: UiffEntry,
    ) {
        // 兄弟Entryを先に処理する
        // ----------------------------------------------------------
        var entryIter = UiffEntryIter(workMemory: firstEntry.chunkMemory)
        while let entry = entryIter.next() {
            enqueueEntry(entry: entry)
        }

        // 子Entryを処理する
        // ----------------------------------------------------------
        entryIter = UiffEntryIter(workMemory: firstEntry.chunkMemory)
        while let entry = entryIter.next() {
            // propertiesからプロパティを取得する
            var prop_iter = UiffPropIter(workMemory: entry.payload)
            while let prop = prop_iter.next() {
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
        for i in 0..<self.entryQueue.getLength() {
            let offsetBytes = self.entryQueue.peek(index: i)
            var entry = UiffEntry(workMemory: self.uiffWork, offsetBytes: Int(offsetBytes))
            entry.hitEventID = 0
        }

        // イベントをEntryに配っていく
        while !self.eventQueue.isEmpty() {
            let eventID = self.eventQueue.dequeue()

            // 後ろから前へ、つまり子を優先する。子で消費したら親へは届かない
            for i in stride(from: self.entryQueue.getLength() - 1, through: 0, by: -1) {
                let offsetBytes = self.entryQueue.peek(index: i)
                var entry = UiffEntry(workMemory: self.uiffWork, offsetBytes: Int(offsetBytes))

                // Listenerがあれば処理する
                if hasListener(entry: entry, eventID: eventID) {
                    entry.hitEventID = eventID
                }
                // Eventがあれば処理する
                if hasEvent(entry: entry, eventID: eventID) {
                    entry.hitEventID = eventID
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
                if events.hasEvent(eventID: eventID) {
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
                if listen.hasEvent(eventID: eventID) {
                    return true
                }
            }
        }
        return false
    }

}
