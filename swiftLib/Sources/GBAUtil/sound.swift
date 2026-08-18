// Sound関係(libmm)
// ****************************************************************************
public enum MM_PLAY_MODE: UInt32 {
    case LOOP = 0
    case ONCE = 1
}

// Maxmodの型や関数をSwift側に宣言
// 初期化
// --------------------------------------------------------
@_silgen_name("mmInitDefault")
public func mmInitDefault(soundbank: UInt, channels: UInt16)

@_silgen_name("mmFrame")
public func mmFrame()

@_silgen_name("mmVBlank")
public func mmVBlank()  // Maxmod の VBlank 更新関数

// SE
// --------------------------------------------------------
@_silgen_name("mmEffect")
public func mmEffect(sfxID: UInt16) -> UInt

@_silgen_name("mmEffectVolume")
public func mmEffectVolume(sfxHandle: UInt16, volume: UInt8)

@_silgen_name("mmSetEffectsVolume")
public func mmSetEffectsVolume(volume: UInt8)

@_silgen_name("mmEffectCancel")
public func mmEffectCancel(sfxHandle: UInt16)

@_silgen_name("mmEffectCancelAll")
public func mmEffectCancelAll()

@_silgen_name("mmLoadEffect")
public func mmLoadEffect(sfxID: UInt16)

@_silgen_name("mmUnloadEffect")
public func mmUnloadEffect(sfxID: UInt16)

// BGM
// --------------------------------------------------------
@_silgen_name("mmStart")
public func mmStart(modID: UInt16, mode: MM_PLAY_MODE)

@_silgen_name("mmStop")
public func mmStop()

@_silgen_name("mmPause")
public func mmPause()

@_silgen_name("mmResume")
public func mmResume()

@_silgen_name("mmLoad")
public func mmLoad(modID: UInt16)

@_silgen_name("mmUnload")
public func mmUnload(modID: UInt16)

@_silgen_name("mmSetModuleVolume")
public func mmSetModuleVolume(volume: UInt16)
