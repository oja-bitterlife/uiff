public struct swiftUILib {
    // MARK: - VM本体のプロパティ
    private var queue: QueueMemory
    private var workMemory: WorkMemory

    // MARK: - 初期化
    public init(
        uiffSrcAddress: UInt,
        queueAddress: UInt, queueByteSize: Int,
        workAddress: UInt, workByteSize: Int,
    ) {
        // uiffのヘッダを解析して、必要な情報を取得する
        let uiffHeader = UiffFileHeader(address: uiffSrcAddress)
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

        // uiffのサイズを取得し、memSizeと比較してuiffがメモリに収まるか確認する
        let uiff_size = Int(uiffHeader.size)
        assert(uiff_size <= workByteSize, "UIFF size exceeds memory size")
        if uiff_size > workByteSize {
            WorkMemory.onFatal(code: UIFF_ERR_FILE_TOO_LARGE)
        }

        // uiffの内容を書き換え可能メモリにコピーする(状態変化対応)
        if let mem_ptr = UnsafeMutablePointer<UInt8>(bitPattern: workAddress) {
            for i in 0..<uiff_size {
                mem_ptr[i] = uiffHeader.data[i]  // UIFFのデータ部をコピー
            }
        } else {
            assert(false, "Failed to create memory pointer for work memory")
            WorkMemory.onFatal(code: MEM_ERR_INVALID_ADDRESS)  // 作業用メモリのポインタ作成失敗
        }

        // スタックと作業用メモリのアクセッサを作る
        self.workMemory = WorkMemory(address: workAddress, byteSize: uiff_size)
        self.queue = QueueMemory(address: queueAddress, byteSize: queueByteSize)
    }

    public func getRoot() -> UiffChunk? {
        // ルートチャンクがEntryであることを確認する
        assert(workMemory[0] == UInt16(UIFF_ENTRY), "UIFF root chunk must be Entry")
        if workMemory[0] != UInt16(UIFF_ENTRY) {
            WorkMemory.onFatal(code: UIFF_ERR_CHUNK_INVALID)  // UIFFルートチャンクがEntryでない
        }

        return UiffEntry(workMemory: workMemory)
    }

    public mutating func enqueueChild(entry: UiffEntry) {
        // キューにチャンクのオフセットアドレスをエンキューする
        let offsetBytes = entry.chunkMemory.getAddress() - self.workMemory.getAddress()
        assert(offsetBytes <= 0xffff, "UIFF child chunk offset exceeds UInt16 max")
        if offsetBytes > 0xffff {
            WorkMemory.onFatal(code: UIFF_ERR_CHUNK_INVALID)  // UIFF子チャンクのオフセットがUInt16の最大値を超える
        }
        self.queue.enqueue(value: UInt16(offsetBytes))
    }

    public mutating func dequeueChild() -> UiffEntry? {
        // キューからチャンクのオフセットアドレスをデキューする
        if self.queue.isEmpty() {
            return nil  // キューが空の場合はnilを返す
        }

        let offsetBytes = Int(self.queue.dequeue())
        let chunk_type = self.workMemory[offsetBytes / 2]

        if chunk_type != UInt16(UIFF_ENTRY) {
            assert(false, "UIFF child chunk must be Entry")
            WorkMemory.onFatal(code: UIFF_ERR_CHUNK_INVALID)  // UIFF子チャンクがEntryでない
        }

        return UiffEntry(workMemory: self.workMemory, offsetBytes: offsetBytes)
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
