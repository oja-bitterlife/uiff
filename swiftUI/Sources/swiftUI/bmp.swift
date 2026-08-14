import Foundation

func outputBMP(bmpBuf: [UInt], width: Int, height: Int) {
    let bmpHeaderSize = 54
    let bmpWidth = 240
    let bmpHeight = 160
    let bmpDataSize = bmpWidth * bmpHeight * 4
    let bmpFileSize = bmpHeaderSize + bmpDataSize
    var bmpFileData = Data(count: bmpFileSize)
    bmpFileData.withUnsafeMutableBytes { (bmpPtr: UnsafeMutableRawBufferPointer) in
        let bmpHeaderPtr = bmpPtr.baseAddress!.assumingMemoryBound(to: UInt8.self)
        // BMPヘッダの作成
        bmpHeaderPtr[0] = 0x42  // 'B'
        bmpHeaderPtr[1] = 0x4D  // 'M'
        bmpHeaderPtr[2] = UInt8(bmpFileSize & 0xFF)
        bmpHeaderPtr[3] = UInt8((bmpFileSize >> 8) & 0xFF)
        bmpHeaderPtr[4] = UInt8((bmpFileSize >> 16) & 0xFF)
        bmpHeaderPtr[5] = UInt8((bmpFileSize >> 24) & 0xFF)
        bmpHeaderPtr[10] = UInt8(bmpHeaderSize)  // ピクセルデータのオフセット
        bmpHeaderPtr[14] = 40  // DIBヘッダのサイズ
        bmpHeaderPtr[18] = UInt8(bmpWidth & 0xFF)
        bmpHeaderPtr[19] = UInt8((bmpWidth >> 8) & 0xFF)
        bmpHeaderPtr[22] = UInt8(bmpHeight & 0xFF)
        bmpHeaderPtr[23] = UInt8((bmpHeight >> 8) & 0xFF)
        bmpHeaderPtr[26] = 1  // カラープレーン数
        bmpHeaderPtr[28] = 32  // ビット数
        // ピクセルデータのコピー
        let bmpDataPtr = bmpHeaderPtr.advanced(by: bmpHeaderSize)
        for y in 0..<bmpHeight {
            for x in 0..<bmpWidth {
                let pixelIndex = (bmpHeight - 1 - y) * bmpWidth + x
                let pixelValue = bmpBuf[pixelIndex]
                let pixelOffset = (y * bmpWidth + x) * 4
                bmpDataPtr[pixelOffset + 0] = UInt8(pixelValue & 0xFF)  // Blue
                bmpDataPtr[pixelOffset + 1] = UInt8((pixelValue >> 8) & 0xFF)  // Green
                bmpDataPtr[pixelOffset + 2] = UInt8((pixelValue >> 16) & 0xFF)  // Red
                bmpDataPtr[pixelOffset + 3] = UInt8((pixelValue >> 24) & 0xFF)  // Alpha
            }
        }
    }
    try! bmpFileData.write(to: URL(fileURLWithPath: bmpFile))
}
