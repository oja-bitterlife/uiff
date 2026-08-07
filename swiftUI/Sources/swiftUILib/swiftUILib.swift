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
            uiffHeader.getMagic() == [
                UInt8(ascii: "U"), UInt8(ascii: "I"), UInt8(ascii: "F"), UInt8(ascii: "F"),
            ], "Invalid uiff file")

        // uiffのサイズを取得し、memSizeと比較してuiffがメモリに収まるか確認する
        let uiff_size = Int(uiffHeader.getSize())
        assert(uiff_size <= memSize, "UIFF size exceeds memory size")

        // uiffの内容を書き換え可能メモリにコピーする
        let uiff_ptr = UnsafeMutablePointer<UInt8>(bitPattern: uiffSrcAddress)!
        let mem_ptr = UnsafeMutablePointer<UInt8>(bitPattern: memAddress)!
        for i in 0..<uiff_size {
            mem_ptr[i] = uiff_ptr[i + 6]  // ヘッダの6バイトをスキップしてコピー
        }

        // スタックと作業用メモリのアクセッサを作る
        self.workMemory = WorkMemory(address: memAddress, size: uiff_size)
        self.stack = StackMemory(address: stackAddress, size: stackSize)
    }

    public func getChunk(offset: Int) -> UiffType {
        return UiffType(workMemory: self.workMemory, offset: offset)
    }

}
