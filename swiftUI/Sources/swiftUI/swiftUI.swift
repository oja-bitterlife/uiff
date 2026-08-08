// The Swift Programming Language
// https://docs.swift.org/swift-book
import Foundation
import swiftUILib

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
            stackAddress: UInt(
                bitPattern: stackMem.withUnsafeMutableBufferPointer { $0.baseAddress! }),
            stackSize: stackMem.count,
            memAddress: UInt(
                bitPattern: workMem.withUnsafeMutableBufferPointer { $0.baseAddress! }),
            memSize: workMem.count)

        print("UIFF ID: \(uiff.root.chunkType), size: \(uiff.root.chunkSize) bytes")
        let root = uiff.root
        if root.typeID == IFF_CHILD {
            print("Root is a container")
        } else {
            print("Root is not a container")
        }
        swiftUI.printEntryHeader(entry: root)
    }

    static func printEntryHeader(entry: UiffEntry) {
        print(
            "type: \(entry.typeID), subType: \(entry.subTypeID), enable: \(entry.isEnabled), visible: \(entry.isVisible), x: \(entry.x), y: \(entry.y), width: \(entry.w), height: \(entry.h)"
        )
    }
}
