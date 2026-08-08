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
        var stackMem = [UInt8](repeating: 0, count: 64)

        // uiffを解析する
        let uiff = swiftUILib(
            uiffSrcAddress: UInt(bitPattern: data.withUnsafeBytes { $0.baseAddress! }),
            queueAddress: UInt(
                bitPattern: stackMem.withUnsafeMutableBufferPointer { $0.baseAddress! }),
            queueSize: stackMem.count,
            memAddress: UInt(
                bitPattern: workMem.withUnsafeMutableBufferPointer { $0.baseAddress! }),
            memSize: workMem.count)

        var chunk = uiff.getRoot()

        // ルートを基準に潜っていく
        while chunk != nil {
            // ルートの情報を表示する
            switch chunk!.chunkType {
            case UInt16(UIFF_ENTRY):
                let entry = chunk as! UiffEntry
                printEntryHeader(entry: entry)
                // payloadに進める
                chunk = entry.getProp()
            case UInt16(UIFF_CHILD):
                print("in children")
                // 子チャンクの最初を取得してスタックに積む
                let child = (chunk as! UiffChild).getFirst()

                // 次に進める
                chunk = (chunk as! UiffChild).getNext()
            default:
                print("UIFF ID: \(chunk!.chunkType), size: \(chunk!.chunkSize) bytes")
                // 次に進める
                chunk = (chunk as! UiffProp).getNext()
            }

            // この階層が終わったら子を処理する
            if chunk == nil {
            }
        }
    }

    static func printEntryHeader(entry: UiffEntry) {
        print(
            "type: \(entry.typeID), subType: \(entry.subTypeID), enable: \(entry.isEnabled), visible: \(entry.isVisible), x: \(entry.x), y: \(entry.y), width: \(entry.w), height: \(entry.h)"
        )
    }

}
