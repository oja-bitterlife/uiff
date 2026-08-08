public struct swiftUILib {
    // MARK: - VM本体のプロパティ
    public var stack: StackMemory
    public var workMemory: WorkMemory

    // MARK: - 初期化
    public init(
        uiffSrcAddress: UInt,
        stackAddress: UInt, stackSize: Int,
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
        self.workMemory = WorkMemory(address: memAddress, size: uiff_size)
        self.stack = StackMemory(address: stackAddress, size: stackSize)
    }

    public var root: UiffEntry {
        return UiffEntry(workMemory: self.workMemory, offset: 0)
    }
}
