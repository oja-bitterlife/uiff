// The Swift Programming Language
// https://docs.swift.org/swift-book
import Foundation
import swiftUILib

// 読み込むファイル名
let uiff_file = "assets/title.uiff"
let bmpFile = "swiftUI/.build/output.bmp"

@main
struct swiftUI {
    static func main() {
        // uiffファイルを読み込む
        let data = try! Data(contentsOf: URL(fileURLWithPath: uiff_file))

        // メモリを確保する
        var workMem = [UInt8](repeating: 0, count: 4 * 1024)  // 4KBの作業用メモリ
        var chileQueueMem = [UInt8](repeating: 0, count: 2 * 32)  // 子を積めるキュー(最大32個の子)

        // uiffを解析する
        var uiff = swiftUILib(
            uiffSrcAddress: UInt(bitPattern: data.withUnsafeBytes { $0.baseAddress! }),
            queueAddress: UInt(
                bitPattern: chileQueueMem.withUnsafeMutableBufferPointer { $0.baseAddress! }),
            queueByteSize: chileQueueMem.count,
            workAddress: UInt(
                bitPattern: workMem.withUnsafeMutableBufferPointer { $0.baseAddress! }),
            workByteSize: workMem.count)

        // let resultCode = [0]
        // let gba_util = GBAUtil(
        //     FatalCodeAddr: UInt(bitPattern: resultCode.withUnsafeBufferPointer { $0.baseAddress! }))

        let root = uiff.getRoot()
        uiff.traverse(
            root: root,
            onEntry: onEntry
        )

        // bmpの書き出し
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

    static func printEntryHeader(entry: UiffEntry) {
        print(
            "type: \(entry.typeID), subType: \(entry.subTypeID), enable: \(entry.isEnabled), visible: \(entry.isVisible), x: \(entry.x), y: \(entry.y), width: \(entry.w), height: \(entry.h)"
        )
    }
    static func printPropInfo(prop: UiffProp) {
        print(
            "type: \(prop.chunkType), size: \(prop.chunkSize) bytes"
        )
    }

    // bmp画像用バッファ
    nonisolated(unsafe) static var bmpBuf: [UInt32] = [UInt32](repeating: 0, count: 240 * 160)

    // UIの処理を書いていく
    static func onEntry(entry: UiffEntry, propIter: UiffPropIter) {
        switch entry.typeID {
        case ENTRY_TYPE_LAYOUT:
            print("Layout Entry found")
            printEntryHeader(entry: entry)
        case ENTRY_TYPE_WINDOW:
            printEntryHeader(entry: entry)
            windowDraw(window: entry, propIter: propIter)
        case ENTRY_TYPE_LABEL:
            print("Label Entry found")
            printEntryHeader(entry: entry)
        case ENTRY_TYPE_SELECT:
            print("Select Entry found")
            printEntryHeader(entry: entry)
        default:
            print("Unknown Entry type: \(entry.typeID)")
            printEntryHeader(entry: entry)
        }
    }

    static func windowDraw(window: UiffEntry, propIter: UiffPropIter) {
        var color: UInt32 = 0xff00_0000
        var iter = propIter

        while let prop = iter.next() {
            switch prop.chunkType {
            case UIFF_COLORS:
                let colorProp = UiffColors(workMemory: prop.chunkMemory)
                color = colorProp.getColor(index: 1)
                print(
                    "    FG: \(String(format: "%08X", colorProp.getColor(index: 0))), BG: \(String(format: "%08X", colorProp.getColor(index: 1)))"
                )
            case UIFF_EVENTS:
                break
            default:
                print("Unknown prop type: \(prop.chunkType)")
            }
        }

        let x = window.x * 8
        let y = window.y * 8
        let w = window.w * 8
        let h = window.h * 8

        for j in y..<(y + h) {
            if j < 0 || j >= 160 { continue }
            for i in x..<(x + w) {
                if i < 0 || i >= 240 { continue }
                let index = j * 240 + i
                bmpBuf[index] = color
            }
        }
    }
}
