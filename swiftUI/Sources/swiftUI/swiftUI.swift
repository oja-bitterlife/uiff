// The Swift Programming Language
// https://docs.swift.org/swift-book
import Foundation
import swiftUILib

// 読み込むファイル名
let uiff_file = "build/title.uiff"
let bmpFile = "build/output.bmp"

@main
struct swiftUI {
    // bmp画像用バッファ
    nonisolated(unsafe) static var bmpBuf: [UInt32] = [UInt32](repeating: 0, count: 240 * 160)

    static func main() {
        // uiffファイルを読み込む
        let data = try! Data(contentsOf: URL(fileURLWithPath: uiff_file))

        // メモリを確保する
        var workMem = [UInt8](repeating: 0, count: 16 * 1024)  // 16KBの作業用メモリ

        // uiffを解析する
        var uiff = swiftUILib(
            uiffRomAddress: UInt(bitPattern: data.withUnsafeBytes { $0.baseAddress! }),
            workMemoryAddress: UInt(
                bitPattern: workMem.withUnsafeMutableBufferPointer { $0.baseAddress! }),
            workMemorySize: workMem.count,
            entryListSize: 2 * 64,
            eventQueueSize: 2 * 32,
            vmWorkSize: 2 * 64,
            vmStackSize: 2 * 64
        )

        // お試し実行
        // --------------------------------------------------------------------
        uiff.notify(eventID: 17)
        uiff.notify(eventID: 25)
        uiff.run(
            firstEntry: uiff.getRoot(),
            onEntry: swiftUI.onEntry
        )

        // bmpの書き出し
        // --------------------------------------------------------------------
        outputBMP(bmpBuf: bmpBuf, width: 240, height: 160)
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

    // UIの処理を書いていく
    static func onEntry(lib: swiftUILib, entry: UiffEntry, propIter: UiffPropIter) {
        switch entry.typeID {
        case ENTRY_TYPE_LAYOUT:
            break
        case ENTRY_TYPE_WINDOW:
            windowDraw(lib: lib, window: entry, propIter: propIter)
        case ENTRY_TYPE_LABEL:
            labelDraw(lib: lib, window: entry, propIter: propIter)
        case ENTRY_TYPE_SELECT:
            selectDraw(lib: lib, window: entry, propIter: propIter)
        default:
            print("Unknown Entry type: \(entry.typeID)")
            printEntryHeader(entry: entry)
        }
    }

    static func windowDraw(lib: swiftUILib, window: UiffEntry, propIter: UiffPropIter) {
        var color: UInt32 = 0xff00_0000
        var iter = propIter

        while let prop = iter.next() {
            switch prop.chunkType {
            case UIFF_COLORS:
                let colorProp = UiffColors(workMemory: prop.chunkMemory)
                color = colorProp.getColor(index: 1)
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

    static func labelDraw(lib: swiftUILib, window: UiffEntry, propIter: UiffPropIter) {
        let color: UInt32 = 0xffff_ffff

        let x = window.x * 8
        let y = window.y * 8
        var w = window.w * 8
        let h = window.h * 8

        var iter = propIter
        while let prop = iter.next() {
            switch prop.chunkType {
            case UIFF_TEXT:
                let textProp = UiffText(workMemory: prop.chunkMemory)
                let textLen = textProp.textLength
                if textLen * 8 < w {
                    w = textLen * 8
                }
            default:
                print("Unknown prop type: \(prop.chunkType)")
            }
        }

        print("drawing label at (\(x), \(y)) with size (\(w), \(h))")

        for j in y..<(y + h) {
            if j < 0 || j >= 160 { continue }
            for i in x..<(x + w) {
                if i < 0 || i >= 240 { continue }
                let index = j * 240 + i
                bmpBuf[index] = color
            }
        }

    }

    static func selectDraw(lib: swiftUILib, window: UiffEntry, propIter: UiffPropIter) {
        let color: UInt32 = 0xff80_0000

        var iter = propIter
        while let prop = iter.next() {
            switch prop.chunkType {
            case UIFF_SCRIPT:
                let scriptProp = UiffScript(workMemory: prop.chunkMemory)
                scriptProp.run(lib: lib)
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

func outputBMP(bmpBuf: [UInt32], width: Int, height: Int) {
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
