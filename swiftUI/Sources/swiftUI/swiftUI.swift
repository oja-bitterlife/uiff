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

    // VMとのやり取り用
    static func setVMEvent(lib: swiftUILib, eventID: UInt16) {
        var vm = lib.vmWork
        vm[1] = eventID
    }
    static func setVMSelectNo(lib: swiftUILib, selectNo: UInt16) {
        var vm = lib.vmWork
        vm[2] = selectNo
    }
    static func recvVMNotify(lib: swiftUILib) {
        let vm = lib.vmWork
        var sendLib = lib
        sendLib.notify(eventID: vm[3])
    }

    // UIの処理を書いていく
    static func onEntry(lib: swiftUILib, entry: UiffEntry, propIter: UiffPropIter) {
        switch entry.typeID {
        case ENTRY_TYPE_LAYOUT:
            break
        case ENTRY_TYPE_WINDOW:
            windowDraw(lib: lib, entry: entry, propIter: propIter)
        case ENTRY_TYPE_LABEL:
            labelDraw(lib: lib, entry: entry, propIter: propIter)
        case ENTRY_TYPE_SELECT:
            selectDraw(lib: lib, entry: entry, propIter: propIter)
        default:
            print(
                "Unknown Entry type: \(entry.typeID), subType: \(entry.subTypeID), enable: \(entry.isEnabled), visible: \(entry.isVisible), x: \(entry.x), y: \(entry.y), width: \(entry.w), height: \(entry.h)"
            )
        }
    }

    static func windowDraw(lib: swiftUILib, entry: UiffEntry, propIter: UiffPropIter) {
        var color: UInt32 = 0xff00_0000

        for prop in propIter {
            switch prop.chunkType {
            case UIFF_COLORS:
                let colorProp = UiffColors(workMemory: prop.chunkMemory)
                color = colorProp.getColor(index: 1)
            default:
                print("Unknown prop type: \(prop.chunkType)")
            }
        }

        let x = entry.x * 8
        let y = entry.y * 8
        let w = entry.w * 8
        let h = entry.h * 8

        for j in y..<(y + h) {
            if j < 0 || j >= 160 { continue }
            for i in x..<(x + w) {
                if i < 0 || i >= 240 { continue }
                let index = j * 240 + i
                bmpBuf[index] = color
            }
        }
    }

    static func labelDraw(lib: swiftUILib, entry: UiffEntry, propIter: UiffPropIter) {
        let color: UInt32 = 0xffff_ffff

        let x = entry.x * 8
        let y = entry.y * 8
        var w = entry.w * 8
        let h = entry.h * 8

        for prop in propIter {
            switch prop.chunkType {
            case UIFF_TEXT:
                let textProp = UiffText(workMemory: prop.chunkMemory)
                let textLen = textProp.getTextLength()
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

    static func selectDraw(lib: swiftUILib, entry: UiffEntry, propIter: UiffPropIter) {
        let color: UInt32 = 0xff80_0000
        setVMEvent(lib: lib, eventID: entry.recvEventID)
        setVMSelectNo(lib: lib, selectNo: 0)

        for prop in propIter {
            switch prop.chunkType {
            case UIFF_SELECT_INFO:
                break
            case UIFF_SCRIPT:
                let scriptProp = UiffScript(workMemory: prop.chunkMemory)
                let result = scriptProp.run(lib: lib)
                print("VM Result: \(result)")
                print("VM Notify: \(lib.vmWork[3])")
                recvVMNotify(lib: lib)

            default:
                print("Unknown prop type: \(prop.chunkType)")
            }
        }

        let x = entry.x * 8
        let y = entry.y * 8
        let w = entry.w * 8
        let h = entry.h * 8

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
