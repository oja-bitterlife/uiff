// System定義 chunk type
// *****************************************************************************
public let UIFF_ENTRY: UInt16 = 0x01
// [type_id(2byte)][subtype_id(2byte)][Enable(2byte)][Visible(2byte)]
// [X(2byte)][Y(2byte)][W(2byte)][H(2byte)]
// [payloads...]
public let UIFF_CHILD: UInt16 = 0x02  // [child chunk][child_chunk]...

// 選択系
public let UIFF_DEF_SELECT: UInt16 = 0x10
public let UIFF_SELECT: UInt16 = UIFF_DEF_SELECT + 1  // [SelRows(2byte)][item_num(2byte)][SEL_ITEM][SEL_ITEM]...

// イベント
public let UIFF_DEF_EVENT: UInt16 = 0x20
public let UIFF_EVENTS: UInt16 = UIFF_DEF_EVENT + 1  // ブロック受信 [event_id(2byte)][event_id(2byte)]...
public let UIFF_LISTEN: UInt16 = UIFF_DEF_EVENT + 2  // リスナー [event_id(2byte)][event_id(2byte)]...

// データ系
public let UIFF_DEF_DATA: UInt16 = 0x30
public let UIFF_TEXT: UInt16 = UIFF_DEF_DATA + 1  // [len(2byte)][data + padding(2)]
public let UIFF_SCRIPT: UInt16 = UIFF_DEF_DATA + 2  // [bytecode(padding4)]
public let UIFF_COLORS: UInt16 = UIFF_DEF_DATA + 3  // [color(4byte)][color(4byte)]...

// ユーザー定義 chunk type
// *****************************************************************************
public let UIFF_DEF_USER: UInt16 = 0x100  // これ以降はユーザー定義chunk typeとして使用
