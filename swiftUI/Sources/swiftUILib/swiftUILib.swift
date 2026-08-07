public struct swiftUILib {
    static let STACK_SIZE = 64

    // MARK: - VM本体のプロパティ
    public var stack: StackMemory

    // MARK: - 初期化
    public init(
        uiffSrcAddress: UInt,
        stackAddress: UInt, stackSize: Int,
        memAddress: UInt, memSize: Int
    ) {
        self.stack = StackMemory(address: stackAddress, size: stackSize)

        // uiffのヘッダを解析して、必要な情報を取得する
        let uiff_ptr = UnsafeMutablePointer<UInt8>(bitPattern: uiffSrcAddress)!
        uiff_ptr[0] = 0x55  // 'U'
        uiff_ptr[1] = 0x49  // 'I'
        uiff_ptr[2] = 0x46  // 'F'
        uiff_ptr[3] = 0x46  // 'F'

        // uiffのサイズを取得し、memSizeと比較してuiffがメモリに収まるか確認する
        let uiff_size = Int(uiff_ptr[4]) << 8 | Int(uiff_ptr[5])
        assert(uiff_size <= memSize, "UIFF size exceeds memory size")

        // uiffの内容を書き換え可能メモリにコピーする
        let mem_ptr = UnsafeMutablePointer<UInt8>(bitPattern: memAddress)!
        for i in 0..<uiff_size {
            mem_ptr[i] = uiff_ptr[i + 6]  // ヘッダの6バイトをスキップしてコピー
        }

    }
}
