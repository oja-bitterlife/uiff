// .tileファイルの読み込みとタイル/スプライト描画を行う
import UIFFLib

// 定数
// ********************************************************************
public enum SIZE_MODE: Int {
    case SIZE_8x8 = 0
    case SIZE_16x16 = 1
    case SIZE_32x32 = 2
    case SIZE_64x64 = 3
    case SIZE_16x8 = 4
    case SIZE_32x8 = 5
    case SIZE_32x16 = 6
    case SIZE_64x32 = 7
    case SIZE_8x16 = 8
    case SIZE_8x32 = 9
    case SIZE_16x32 = 10
    case SIZE_32x64 = 11
}

public enum COLOR_MODE: Int {
    case COLOR_16 = 0
    case COLOR_256 = 1
}

// .tileファイルの読み込み基本クラス
// ********************************************************************
private struct TileBase {
    // .tileファイルのmagicをチェックする
    static private func checkMagic(romOffset: Int) {
        let magic = ROM.readUInt(offset: romOffset)  // タイルデータの存在確認
        if magic != 0x454c_4954 {  // "ITLE"
            FatalMsg("Invalid Magic for .tile file")  // FATAL_TILE_INVALID_MAGIC
        }
    }

    // パレットデータ部を読み込んで転送
    static public func loadPaletteData(romOffset: Int, palBlock: Int, isObj: Bool) {
        checkMagic(romOffset: romOffset)

        let paletteDataOffset = Int(ROM.readUInt(offset: romOffset + 12)) + romOffset
        let tileDataOffset = Int(ROM.readUInt(offset: romOffset + 16)) + romOffset
        let paletteNum = (tileDataOffset - paletteDataOffset) / 2  // パレット数

        // indexの範囲チェック
        if paletteNum * palBlock >= 256 {
            FatalMsg("Palette block index out of bounds")  // FATAL_TILE_PALETTE_OUTOFBOUNDS
        }

        // DMAでパレットデータを転送する
        let palOffset = palBlock * (paletteNum * 2) + (isObj ? 0x200 : 0)
        DMA3_UInt(
            srcAddr: ROM_ADDR + UInt(paletteDataOffset),
            dstAddr: PALETTE_ADDR + UInt(palOffset),
            size: paletteNum * 2
        )
    }

    // .tileファイルを読み込み、VRAMにタイルデータを転送する
    static public func loadTileData(romTileOffset: Int, tileBlock: Int, tileBlockOffset: Int) {
        checkMagic(romOffset: romTileOffset)

        let tileVramOffset = tileBlock * 0x4000 + tileBlockOffset  // タイルデータのオフセットは16KB単位で切り替え可能

        // タイルデータ設定。デカイのでDMAで転送するのが良いかも
        let tileDataOffset = Int(ROM.readUInt(offset: romTileOffset + 16)) + romTileOffset
        let tileSize = Int(ROM.readUInt(offset: tileDataOffset))

        // タイルデータがVRAMの範囲を超えているか
        if tileVramOffset + tileSize > 0x18000 {  // VRAMのサイズは96KBまで
            FatalMsg("Tile VRAM offset out of bounds")  // FATAL_TILE_VRAM_OUTOFBOUNDS
        }

        // 何も考えずタイルデータを全部転送すればいいはず
        DMA3_UInt(
            srcAddr: ROM_ADDR + UInt(tileDataOffset + 4),
            dstAddr: VRAM_ADDR + UInt(tileVramOffset),
            size: tileSize
        )
    }
}

// タイルをマップ描画する
// ********************************************************************
public struct BGTile {
    let mapBlock: Int
    let offsetGridY: Int

    public init(mapBlock: Int, offsetGridY: Int = 0) {
        self.mapBlock = mapBlock
        self.offsetGridY = offsetGridY
    }

    static public func loadPaletteData(romOffset: Int, palBlock: Int) {
        TileBase.loadPaletteData(romOffset: romOffset, palBlock: palBlock, isObj: false)
    }

    static public func loadTileData(
        romOffset: Int, tileBlock: Int, colorMode: COLOR_MODE = .COLOR_16, offsetGridY: Int = 0
    ) {
        TileBase.loadTileData(
            romTileOffset: romOffset, tileBlock: tileBlock,
            tileBlockOffset: offsetGridY * (colorMode == .COLOR_256 ? 256 : 128) * 8
        )
    }

    // タイル番号をタイルサイズ単位で取得する
    // --------------------------------------------------------------
    public func getTileNo8(_ tileX: Int, _ tileY: Int) -> Int {
        return tileY * 32 + tileX
    }
    public func getTileNo16(_ tileX: Int, _ tileY: Int) -> Int {
        return tileY * 32 * 2 + tileX * 2
    }
    public func getTileNo24(_ tileX: Int, _ tileY: Int) -> Int {
        return tileY * 32 * 3 + tileX * 3
    }
    public func getTileNo32(_ tileX: Int, _ tileY: Int) -> Int {
        return tileY * 32 * 4 + tileX * 4
    }

    // マップ描画
    // --------------------------------------------------------------
    public func drawMap8(
        tileNo: Int, gridX: Int, gridY: Int,
        palBlk: Int = 0, HR: Bool = false, VR: Bool = false,
    ) {
        let mapOffset = mapBlock * 0x800
        let mapPtr = VRAM.getDirectPtr(as: UInt16.self, offset: mapOffset)

        let HR = UInt16(HR ? 1 : 0) << 10  // Horizontal Flip
        let VR = UInt16(VR ? 1 : 0) << 11  // Vertical Flip
        let PB = UInt16(palBlk) << 12  // Palette Bank

        let tileNo = tileNo + offsetGridY * 32  // タイル番号のオフセットを加算

        mapPtr[gridY * 32 + gridX] = PB | VR | HR | UInt16(tileNo)
    }

    public func drawMap16(
        tileNo: Int, gridX: Int, gridY: Int,
        palBlk: Int = 0, HR: Bool = false, VR: Bool = false,
    ) {
        let mapOffset = mapBlock * 0x800
        let mapPtr = VRAM.getDirectPtr(as: UInt16.self, offset: mapOffset)

        let HR = UInt16(HR ? 1 : 0) << 10  // Horizontal Flip
        let VR = UInt16(VR ? 1 : 0) << 11  // Vertical Flip
        let PB = UInt16(palBlk) << 12  // Palette Bank

        withUnsafeTemporaryAllocation(of: Int.self, capacity: 4) { tileNoList in
            // 座標設定
            for y in 0..<2 {
                for x in 0..<2 {
                    let tileNo = tileNo + y * 32 + x
                    tileNoList[y * 2 + x] = tileNo
                }
            }

            if HR == 1 {
                tileNoList.swapAt(0, 3)
                tileNoList.swapAt(1, 2)
            }
            if VR == 1 {
                tileNoList.swapAt(0, 2)
                tileNoList.swapAt(1, 3)
            }

            for y in 0..<2 {
                for x in 0..<2 {
                    let tileNo = tileNoList[y * 2 + x]
                    mapPtr[(gridY + y) * 32 + (gridX + x)] = PB | VR | HR | UInt16(tileNo)
                }
            }
        }
    }

    public func drawMap24(
        tileNo: Int, gridX: Int, gridY: Int,
        palBlk: Int = 0, HR: Bool = false, VR: Bool = false,
    ) {
        let mapOffset = mapBlock * 0x800
        let mapPtr = VRAM.getDirectPtr(as: UInt16.self, offset: mapOffset)

        let HR = UInt16(HR ? 1 : 0) << 10  // Horizontal Flip
        let VR = UInt16(VR ? 1 : 0) << 11  // Vertical Flip
        let PB = UInt16(palBlk) << 12  // Palette Bank

        withUnsafeTemporaryAllocation(of: Int.self, capacity: 9) { tileNoList in
            // 座標設定
            for y in 0..<3 {
                for x in 0..<3 {
                    let tileNo = tileNo + y * 32 + x
                    tileNoList[y * 3 + x] = tileNo
                }
            }

            if HR == 1 {
                for y in 0..<3 {
                    tileNoList.swapAt(y * 3 + 0, y * 3 + 2)
                }
            }
            if VR == 1 {
                for x in 0..<3 {
                    tileNoList.swapAt(0 * 3 + x, 2 * 3 + x)
                }
            }

            for y in 0..<3 {
                for x in 0..<3 {
                    let tileNo = tileNoList[y * 3 + x]
                    mapPtr[(gridY + y) * 32 + (gridX + x)] = PB | VR | HR | UInt16(tileNo)
                }
            }
        }
    }

    public func drawMap32(
        tileNo: Int, gridX: Int, gridY: Int,
        palBlk: Int = 0, HR: Bool = false, VR: Bool = false,
    ) {
        let mapOffset = mapBlock * 0x800
        let mapPtr = VRAM.getDirectPtr(as: UInt16.self, offset: mapOffset)

        let HR = UInt16(HR ? 1 : 0) << 10  // Horizontal Flip
        let VR = UInt16(VR ? 1 : 0) << 11  // Vertical Flip
        let PB = UInt16(palBlk) << 12  // Palette Bank

        withUnsafeTemporaryAllocation(of: Int.self, capacity: 16) { tileNoList in
            // 座標設定
            for y in 0..<4 {
                for x in 0..<4 {
                    let tileNo = tileNo + y * 32 + x
                    tileNoList[y * 4 + x] = tileNo
                }
            }

            if HR == 1 {
                for y in 0..<4 {
                    tileNoList.swapAt(y * 4 + 0, y * 4 + 3)
                    tileNoList.swapAt(y * 4 + 1, y * 4 + 2)
                }
            }
            if VR == 1 {
                for x in 0..<4 {
                    tileNoList.swapAt(0 * 4 + x, 3 * 4 + x)
                    tileNoList.swapAt(1 * 4 + x, 2 * 4 + x)
                }
            }

            for y in 0..<4 {
                for x in 0..<4 {
                    let tileNo = tileNoList[y * 4 + x]
                    mapPtr[(gridY + y) * 32 + (gridX + x)] = PB | VR | HR | UInt16(tileNo)
                }
            }
        }
    }
}

// タイルをスプライト描画する
// ********************************************************************
public struct OBJTile {
    private var tile: TileBase
    let objNo: Int
    let sizeMode: SIZE_MODE
    let colorMode: COLOR_MODE

    public init(objNo: Int, size: SIZE_MODE, colorMode: COLOR_MODE = .COLOR_16) {
        tile = TileBase()
        self.objNo = objNo
        self.sizeMode = size
        self.colorMode = colorMode
    }

    static public func loadPaletteData(romOffset: Int, palBlock: Int) {
        TileBase.loadPaletteData(romOffset: romOffset, palBlock: palBlock, isObj: true)
    }

    static public func loadTileData(
        romOffset: Int, colorMode: COLOR_MODE = .COLOR_16, offsetGridY: Int = 0
    ) {
        // OBJのタイルデータはキャラクターブロック4以降に配置される
        TileBase.loadTileData(
            romTileOffset: romOffset, tileBlock: 4,
            tileBlockOffset: offsetGridY * (colorMode == .COLOR_256 ? 256 : 128) * 8
        )
    }

    public func getTileNoFromGrid(gridX: Int, gridY: Int) -> Int {
        switch sizeMode {
        case .SIZE_8x8:
            return gridY * 32 + gridX
        case .SIZE_16x16:
            return gridY * 32 * 2 + gridX * 2
        case .SIZE_32x32:
            return gridY * 32 * 4 + gridX * 4
        case .SIZE_64x64:
            return gridY * 32 * 8 + gridX * 8
        case .SIZE_16x8:
            return gridY * 32 + gridX * 2
        case .SIZE_32x8:
            return gridY * 32 + gridX * 4
        case .SIZE_32x16:
            return gridY * 32 * 2 + gridX * 4
        case .SIZE_64x32:
            return gridY * 32 * 4 + gridX * 8
        case .SIZE_8x16:
            return gridY * 32 * 2 + gridX
        case .SIZE_8x32:
            return gridY * 32 * 4 + gridX
        case .SIZE_16x32:
            return gridY * 32 * 4 + gridX * 2
        case .SIZE_32x64:
            return gridY * 32 * 8 + gridX * 4
        }
    }

    public func draw(
        objGridX: Int, objGridY: Int,
        x: Int, y: Int, palBlk: Int = 0,
        prio: Int, HR: Bool, VR: Bool,
    ) {
        let tileNo = getTileNoFromGrid(gridX: objGridX, gridY: objGridY)

        let OAM0_Y: UInt16 = UInt16(y)
        let OAM0_MT: UInt16 = UInt16(0) << 8  // 回転OFF
        let OAM0_DM: UInt16 = UInt16(0) << 10  // 描画モード
        let OAM0_MZ: UInt16 = UInt16(0) << 12  // モザイクモード
        let OAM0_CM: UInt16 = UInt16(self.colorMode.rawValue) << 13  // 16色/256色モード
        let OAM0_SZ: UInt16 = UInt16(sizeMode.rawValue >> 2) << 14  // スプライトサイズHB
        let OAM1_X: UInt16 = UInt16(x)
        let OAM1_HR: UInt16 = UInt16(HR ? 1 : 0) << 12  // 水平反転OFF
        let OAM1_VR: UInt16 = UInt16(VR ? 1 : 0) << 13  // 垂直反転OFF
        let OAM1_SZ: UInt16 = UInt16(sizeMode.rawValue & 0x3) << 14  // スプライトサイズLB
        let OAM2_TN: UInt16 = UInt16(tileNo)  // タイル番号
        let OAM2_PR: UInt16 = UInt16(prio) << 10  // 優先度
        let OAM2_PL: UInt16 = UInt16(palBlk) << 12  // パレット番号
        let OAM3_RS: UInt16 = UInt16(0) << 14  // 回転スケール(8bit固定少数点)

        let oam0 = OAM0_Y | OAM0_MT | OAM0_DM | OAM0_MZ | OAM0_CM | OAM0_SZ
        let oam1 = OAM1_X | OAM1_HR | OAM1_VR | OAM1_SZ
        let oam2 = OAM2_TN | OAM2_PR | OAM2_PL
        let oam3 = OAM3_RS

        OAM.writeUInt16(offset: objNo * 8, value: oam0)
        OAM.writeUInt16(offset: objNo * 8 + 2, value: oam1)
        OAM.writeUInt16(offset: objNo * 8 + 4, value: oam2)
        OAM.writeUInt16(offset: objNo * 8 + 6, value: oam3)
    }

    static public func clean() {
        for i in 0..<128 {
            OAM.writeUInt16(offset: i * 8, value: 160)  // Y座標を画面外に設定
            OAM.writeUInt16(offset: i * 8 + 2, value: 0)
            OAM.writeUInt16(offset: i * 8 + 4, value: 0)
            OAM.writeUInt16(offset: i * 8 + 6, value: 0)
        }
    }
}
