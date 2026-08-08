public struct swiftUILib {
    // MARK: - VM本体のプロパティ
    private var queue: QueueMemory
    private var workMemory: WorkMemory

    // MARK: - 初期化
    public init(
        uiffSrcAddress: UInt,
        queueAddress: UInt, queueSize: Int,
        memAddress: UInt, memSize: Int
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
        assert(uiff_size <= memSize, "UIFF size exceeds memory size")

        // uiffの内容を書き換え可能メモリにコピーする(状態変化対応)
        let mem_ptr = UnsafeMutablePointer<UInt8>(bitPattern: memAddress)!
        for i in 0..<uiff_size {
            mem_ptr[i] = uiffHeader.data[i]  // UIFFのデータ部をコピー
        }

        // スタックと作業用メモリのアクセッサを作る
        self.workMemory = WorkMemory(address: memAddress, byteSize: uiff_size)
        self.queue = QueueMemory(address: queueAddress, byteSize: queueSize)
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

    public mutating func pushChild(chunk: UiffChunk) {
        // キューにチャンクのオフセットアドレスをエンキューする
        let offsetBytes = chunk.chunkMemory.getAddress() - self.workMemory.getAddress()
        assert(offsetBytes <= 0xffff, "UIFF child chunk offset exceeds UInt16 max")
        self.queue.enqueue(value: UInt16(offsetBytes))
    }

    public mutating func popChild() -> UiffChunk? {
        // キューからチャンクのオフセットアドレスをデキューする
        if self.queue.getIndexSize() < 2 {
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
}
