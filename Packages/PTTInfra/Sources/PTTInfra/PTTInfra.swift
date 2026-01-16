// PTTInfra - 基础设施层
//
// 包含：网络通信、音频引擎、存储、后台保活

@_exported import Foundation
@_exported import PTTCodec

// 公开导出主要组件
// - AudioUnitEngine: 音频录放引擎
// - AudioRingBuffer: 音频环形缓冲
// - BackgroundKeepAlive: 后台保活
// - UDPClient: UDP 客户端
// - JitterBuffer: 网络抖动缓冲
// - NRL21Protocol: 协议解析
