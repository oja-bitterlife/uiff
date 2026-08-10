public struct swiftUILib {
    // MARK: - VM本体のプロパティ
    public var uiffWork: WorkMemory
    public var childQueue: RingQueueMemory
    public var eventQueue: RingQueueMemory
    public var vmMemory: WorkMemory

    // MARK: - 初期化
    public init(
        uiffRomAddress: UInt,  // uiffデータのROM上の先頭アドレス
        workMemoryAddress: UInt,  // 作業用メモリの先頭アドレス
        workMemorySize: Int,  // 作業用メモリの総サイズ
        childWorkSize: Int,  // 作用用メモリ内の子キューのサイズ
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
            ExpandEven(value: childWorkSize)
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
        self.childQueue = RingQueueMemory(
            address: queueOffset, byteSize: ExpandEven(value: childWorkSize))
        queueOffset += UInt(self.childQueue.getByteSize())
        self.eventQueue = RingQueueMemory(
            address: queueOffset, byteSize: ExpandEven(value: eventWorkSize))
        queueOffset += UInt(self.eventQueue.getByteSize())
        self.vmMemory = WorkMemory(address: queueOffset, byteSize: ExpandEven(value: vmWorkSize))
    }

    public func getRoot() -> UiffChunk? {
        // ルートチャンクがEntryであることを確認する
        assert(uiffWork[0] == UInt16(UIFF_ENTRY), "UIFF root chunk must be Entry")
        if uiffWork[0] != UInt16(UIFF_ENTRY) {
            WorkMemory.onFatal(code: UIFF_ERR_CHUNK_INVALID)  // UIFFルートチャンクがEntryでない
        }

        return UiffEntry(workMemory: uiffWork)
    }

    public mutating func enqueueChild(entry: UiffEntry) {
        // キューにチャンクのオフセットアドレスをエンキューする
        let offsetBytes = entry.chunkMemory.getAddress() - self.uiffWork.getAddress()
        assert(offsetBytes <= 0xffff, "UIFF child chunk offset exceeds UInt16 max")
        if offsetBytes > 0xffff {
            WorkMemory.onFatal(code: UIFF_ERR_CHUNK_INVALID)  // UIFF子チャンクのオフセットがUInt16の最大値を超える
        }
        self.childQueue.enqueue(value: UInt16(offsetBytes))
    }

    public mutating func dequeueChild() -> UiffEntry? {
        // キューからチャンクのオフセットアドレスをデキューする
        if self.childQueue.isEmpty() {
            return nil  // キューが空の場合はnilを返す
        }

        let offsetBytes = Int(self.childQueue.dequeue())
        let chunk_type = self.uiffWork[offsetBytes / 2]

        if chunk_type != UInt16(UIFF_ENTRY) {
            assert(false, "UIFF child chunk must be Entry")
            WorkMemory.onFatal(code: UIFF_ERR_CHUNK_INVALID)  // UIFF子チャンクがEntryでない
        }

        return UiffEntry(workMemory: self.uiffWork, offsetBytes: offsetBytes)
    }

    public mutating func traverse(
        root: UiffChunk?,
        onEntry: (UiffEntry, UiffPropIter) -> Void,
    ) {
        // rootの値チェック
        // ----------------------------------------------------------
        guard let root = root else {
            assert(false, "UIFF root chunk is nil")
            WorkMemory.onFatal(code: UIFF_ERR_CHUNK_INVALID)  // UIFFルートチャンクがnil
        }
        if root.chunkType != UInt16(UIFF_ENTRY) {
            assert(false, "UIFF root chunk must be Entry")
            WorkMemory.onFatal(code: UIFF_ERR_CHUNK_INVALID)  // UIFFルートチャンクがEntryでない
        }

        // エントリーのループ処理
        // ----------------------------------------------------------
        // rootをキューに積む
        enqueueChild(entry: UiffEntry(workMemory: root.chunkMemory))

        // キューが空になるまでループする
        while let childEntry = dequeueChild() {
            var entryIter = UiffEntryIter(workMemory: childEntry.chunkMemory)

            // エントリー単位で処理する
            while let entry = entryIter.next() {
                onEntry(entry, UiffPropIter(workMemory: entry.payload))

                // propertiesからプロパティを取得する
                var prop_iter = UiffPropIter(workMemory: entry.payload)
                while let prop = prop_iter.next() {
                    // 子があればキューに積む
                    if prop.chunkType == UInt16(UIFF_CHILD) {
                        let children = UiffChild(workMemory: prop.chunkMemory)
                        if let first_child = children.getFirstEntry() {
                            enqueueChild(entry: first_child)
                        }
                    }
                }
            }
        }
    }
}
