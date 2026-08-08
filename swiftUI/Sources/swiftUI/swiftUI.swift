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

        // let resultCode = [0]
        // let gba_util = GBAUtil(
        //     FatalCodeAddr: UInt(bitPattern: resultCode.withUnsafeBufferPointer { $0.baseAddress! }))

        let root = uiff.getRoot()
        uiff.traverse(
            root: root,
            onEntry: { entry in
                printEntryHeader(entry: entry)
            },
            // onTraverse: { chunk in
            //     if chunk is UiffChild {
            //         print("in Child chunk")
            //     } else if chunk is UiffProp {
            //         printPropInfo(prop: chunk as! UiffProp)
            //     }
            // })
        )
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
