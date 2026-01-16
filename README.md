# PTT 互联 iOS

原生 iOS PTT（Push-To-Talk）对讲机应用，支持 Apple Watch。

## 功能特性

- **语音对讲** - 长按/点击说话，实时语音通信
- **Apple Watch** - 手表独立 PTT 控制
- **灵动岛** - Live Activity 实时状态显示
- **多编码支持** - G.711 A-law / Opus
- **AI 降噪** - RNNoise 实时语音降噪
- **文本消息** - 群组文字聊天
- **通话记录** - 自动保存，支持回放
- **后台运行** - 断线自动重连

## 环境要求

| 项目 | 版本 |
|------|------|
| Xcode | 15.0+ |
| iOS | 15.0+ |
| watchOS | 10.0+ |
| Swift | 5.9+ |

## 快速开始

```bash
# 克隆项目
git clone https://github.com/cnlghui/PTTApp-iOS.git
cd PTTApp-iOS

# 安装依赖
pod install

# 打开工程
open PTTApp.xcworkspace
```

## 项目结构

```
PTTApp-iOS/
├── PTTApp-SwiftUI/          # iOS 主应用
├── PTTWatch/                # Apple Watch 应用
├── PTTLiveActivity/         # 灵动岛扩展
├── Shared/                  # 共享代码
│   ├── ViewModels/          # ViewModel
│   └── WatchConnectivity/   # Watch 通信
└── Packages/                # Swift Package
    ├── PTTInfra/            # 基础设施 (音频/网络)
    └── PTTCodec/            # 编解码器
```

## 技术架构

```
┌─────────────────────────────────────┐
│          UI Layer (SwiftUI)         │
├─────────────────────────────────────┤
│     PTTViewModel (@MainActor)       │
├─────────────────────────────────────┤
│   PTTService / WatchSessionManager  │
├──────────────┬──────────────────────┤
│ AudioUnit    │   NRL21 Protocol     │
│ G711/Opus    │   UDP/HTTP           │
└──────────────┴──────────────────────┘
```

## 相关项目

- [nrllink](https://github.com/hicaoc/nrllink) - 网络转发服务器
- [nrllink-web](https://github.com/hicaoc/nrllink-web) - Web 版本
- [nrllink-mp](https://github.com/hicaoc/nrllink-mp) - 微信小程序版本
- [nrlnanny](https://github.com/hicaoc/nrlnanny) - 管理后台

## License

[MIT License](LICENSE)
