// The Swift Programming Language
// https://docs.swift.org/swift-book
import Foundation
import swiftUILib

// 読み込むファイル名
let uiff_file = "assets/title.uiff"

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

        let resultCode = [0]
        let gba_util = GBAUtil(
            FatalCodeAddr: UInt(bitPattern: resultCode.withUnsafeBufferPointer { $0.baseAddress! }))

        var next_chunk = uiff.getRoot()  // nilでないことを保証するchunk

        // ルートを基準に潜っていく
        while let chunk = next_chunk {
            // ルートの情報を表示する
            switch chunk.chunkType {
            case UInt16(UIFF_ENTRY):
                let entry = UiffEntry(workMemory: chunk.chunkMemory)
                printEntryHeader(entry: entry)

                // payloadからプロパティを取得する
                if let prop = entry.getProp() {
                    next_chunk = prop
                } else {
                    // payloadがなければ次のEnetryに進む
                    next_chunk = entry.getNext()
                }
            case UInt16(UIFF_CHILD):
                let children = UiffChild(workMemory: chunk.chunkMemory)
                print("in children")

                // 子をキューに積む
                uiff.enqueueChild(chunk: gba_util.unwrap(children.getFirst()))

                // 次に進める
                next_chunk = children.getNext()
            default:
                let prop = UiffProp(workMemory: chunk.chunkMemory)
                printPropInfo(prop: prop)

                // 次に進める
                next_chunk = prop.getNext()
            }

            // この階層が終わったら子を処理する
            if next_chunk == nil {
                next_chunk = uiff.dequeueChild()
            }
        }
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

}
