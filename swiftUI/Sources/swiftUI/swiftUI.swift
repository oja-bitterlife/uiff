// The Swift Programming Language
// https://docs.swift.org/swift-book

import swiftUILib

// 読み込むファイル名
let uiff_file = "assets/title.uiff"

@main
struct swiftUI {
    static func main() {
        // uiffファイルを読み込む
        let data = try! Data(contentsOf: URL(fileURLWithPath: uiff_file))

        // uiffを解析する

        print(swiftUILib().text)
    }
}
