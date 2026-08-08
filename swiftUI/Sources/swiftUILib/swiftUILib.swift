public struct swiftUILib {
    // MARK: - VM本体のプロパティ
    private var queue: QueueMemory
    private var workMemory: WorkMemory

    // MARK: - 初期化
    public init(
        uiffSrcAddress: UInt,
        queueAddress: UInt, queueByteSize: Int,
        workAddress: UInt, workByteSize: Int
    ) {
        // uiffのヘッダを解析して、必要な情報を取得する
        let uiffHeader = UiffFileHeader(address: uiffSrcAddress)
        assert(
            uiffHeader.magic == UInt(UInt8(ascii: "U"))
                | UInt(UInt8(ascii: "I")) << 8
                | UInt(UInt8(ascii: "F")) << 16
                | UInt(UInt8(ascii: "F")) << 24,
            "Invalid uiff file")

        // uiffのサイズを取得し、memSizeと比較してuiffがメモリに収まるか確認する
        let uiff_size = Int(uiffHeader.size)
        assert(uiff_size <= workByteSize, "UIFF size exceeds memory size")

        // uiffの内容を書き換え可能メモリにコピーする(状態変化対応)
        if let mem_ptr = UnsafeMutablePointer<UInt8>(bitPattern: workAddress) {
            for i in 0..<uiff_size {
                mem_ptr[i] = uiffHeader.data[i]  // UIFFのデータ部をコピー
            }
        } else {
            assert(false, "Failed to create memory pointer for work memory")
        }

        // スタックと作業用メモリのアクセッサを作る
        self.workMemory = WorkMemory(address: workAddress, byteSize: uiff_size)
        self.queue = QueueMemory(address: queueAddress, byteSize: queueByteSize)
    }

    public func getRoot() -> UiffChunk? {
        let chunkMemory = self.workMemory
        switch chunkMemory[0] {  // チャンクのタイプを取得
        case UInt16(UIFF_ENTRY):
            return UiffEntry(workMemory: chunkMemory, offsetBytes: 0)
        case UInt16(UIFF_CHILD):
            return UiffChild(workMemory: chunkMemory, offsetBytes: 0)
        default:
            // 最初は必ずEntryかChildのはず
            assert(false, "UIFF root chunk must be Entry or Child")
            return nil
        }
    }

    public mutating func enqueueChild(entry: UiffEntry) {
        // キューにチャンクのオフセットアドレスをエンキューする
        let offsetBytes = entry.chunkMemory.getAddress() - self.workMemory.getAddress()
        assert(offsetBytes <= 0xffff, "UIFF child chunk offset exceeds UInt16 max")
        self.queue.enqueue(value: UInt16(offsetBytes))
    }

    public mutating func dequeueChild() -> UiffChunk? {
        // キューからチャンクのオフセットアドレスをデキューする
        if self.queue.isEmpty() {
            return nil  // キューが空の場合はnilを返す
        }

        let offsetBytes = Int(self.queue.dequeue())
        let chunk_type = self.workMemory[offsetBytes / 2]

        switch chunk_type {  // チャンクのタイプを取得
        case UInt16(UIFF_ENTRY):
            return UiffEntry(workMemory: self.workMemory, offsetBytes: offsetBytes)
        default:
            assert(false, "UIFF child chunk must be Entry")
            return nil
        }
    }

    public mutating func traverse(
        root: UiffChunk?,
        onEntry: (UiffEntry) -> Void,
        onTraverse: ((UiffChunk) -> Void)? = nil
    ) {
        var next_chunk = root

        // ルートを基準に潜っていく
        while let chunk = next_chunk {
            // 全てのチャンクに対して処理を行う
            if let onTraverse = onTraverse {
                onTraverse(chunk)
            }

            // ルートの情報を表示する
            switch chunk.chunkType {
            case UInt16(UIFF_ENTRY):
                let entry = UiffEntry(workMemory: chunk.chunkMemory)
                // printEntryHeader(entry: entry)
                onEntry(entry)

                // payloadからプロパティを取得する
                var prop_iter = entry.getPropIter()
                if let prop = prop_iter.next() {
                    next_chunk = prop
                } else {
                    // payloadがなければ次のEnetryに進む
                    next_chunk = entry.getNext()
                }

            case UInt16(UIFF_CHILD):
                let children = UiffChild(workMemory: chunk.chunkMemory)

                // 子をキューに積む
                if let first_child = children.getFirstEntry() {
                    enqueueChild(entry: first_child)
                }
                next_chunk = children.getNext()  // 次に進める

            default:
                // プロパティはここでは処理しない
                let prop = UiffProp(workMemory: chunk.chunkMemory)
                next_chunk = prop.getNext()  // 次に進める
            }

            // この階層が終わったら子を処理する
            if next_chunk == nil {
                next_chunk = dequeueChild()
            }
        }
    }
}
