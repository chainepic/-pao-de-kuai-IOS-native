# 🎴 跑得快 · 纯原生单机扑克游戏 (Paodekuai Native)

<p align="center">
  <img src="https://img.shields.io/badge/Swift-5.9%20%2F%206.0-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="Swift" />
  <img src="https://img.shields.io/badge/SwiftUI-iOS%2017%2B-007AFF?style=for-the-badge&logo=apple&logoColor=white" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/Platform-iOS%20%7C%20iPadOS%20%7C%20macOS-333333?style=for-the-badge&logo=apple&logoColor=white" alt="Platforms" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="License" />
  <img src="https://img.shields.io/badge/Dependencies-0%20(Pure%20Native)-blueviolet?style=for-the-badge" alt="Zero Dependencies" />
</p>

<p align="center">
  <strong>一款基于 SwiftUI + 纯算法构建的现代湖南跑得快（16张）单机纸牌游戏。</strong><br>
  包含完整的地道规则引擎、启发式 AI 决策系统、离线语音播报、多语言支持以及百万级对局自博弈（Self-Play）评测框架。
</p>

---

## ✨ 项目亮点 (Highlights)

* 🃏 **地道湖南跑得快规则**：48 张牌（去 2H/2D/2C/AD），三人对战，首局黑桃3必出，严格支持“有大必出”、“下家剩单必出最大单牌”、“放走包赔”等经典玩法。
* 🤖 **启发式高拟真 AI**：内置基于估值函数、危险牌判定与拆牌权衡算法的单机 AI，支持自博弈仿真（可在后台自动对决数千手用于策略调优与评估）。
* 🚀 **100% 纯原生 & 零外部依赖**：仅基于 Apple 官方 SwiftUI / AVFoundation，不依赖任何第三方 Pods/SPM 库，开箱即编，极度轻量且性能强劲。
* 🌐 **国际化双语支持**：内置英文与简体中文本地化方案，支持实时动态切换。
* 🔊 **离线语音合成**：采用系统原生 `AVSpeechSynthesizer`，纯离线语音播报，无需麦克风与网络权限。
* 📊 **仿真测试与数据分析**：内置完整的自博弈与日志导出机制，搭配配套 Python 数据分析工具链。

---

## 🎮 游戏规则与支持牌型

| 牌型 | 规则说明 | 示例 |
| :--- | :--- | :--- |
| **单张** | 单张牌点数比较（3 最小，2 最大） | `♠3`, `♥A`, `♠2` |
| **对子** | 两张点数相同的牌 | `♥8 ♠8` |
| **顺子** | 5 张或以上连续单牌（不可包含 2） | `♠4 ♦5 ♣6 ♥7 ♠8` |
| **连对** | 2 对或以上连续对子（不可包含 2） | `33 44`, `77 88 99` |
| **三带二** | 三张同点数牌 + 两张散牌/对子 | `999 + 45` 或 `999 + JJ` |
| **飞机带翅膀** | 连续三张同点数牌 + 对应数量翅膀 | `JJJ QQQ + 34 56` |
| **炸弹** | 四张同点数牌（可压所有非炸弹牌型，炸弹之间比大小） | `AAAA`, `8888` |

### 特殊规则机制
1. **有大必出**：当手牌中有可压过桌面牌型的合法牌时，系统强制禁止过牌。
2. **报单预警**：当下家手牌仅剩 1 张（报单）且轮到本家出单牌时，强制要求出当前手中的**最大单牌**（顶大）。
3. **规则预设与自定义**：支持切换「湖南常规」、「宽松模式」、「仅炸必出」等预设，可自由配置是否允许三带一、三不带及炸弹触发条件。

---

## 🏛️ 核心架构设计 (Architecture)

工程结构清晰，采用分层与单一数据流驱动：

```text
PaodekuaiNative/
├── App/
│   └── PaodekuaiNativeApp.swift      # SwiftUI App 入口与场景分发
├── Core/
│   ├── GameCore.swift                # 核心规则引擎、牌型识别、有大必出与 AI 决策模型
│   ├── GameStore.swift               # 游戏全局状态机、对局循环、计分与自博弈引擎
│   └── Localization.swift            # 中英双语本地化与动态文案引擎
├── Features/
│   ├── Game/
│   │   ├── Components/
│   │   │   ├── PlayingCardView.swift # 扑克牌视图组件（花色、点数与高亮状态）
│   │   │   └── GameTheme.swift       # 桌面背景、牌背、配色与主题风格
│   │   ├── GameView.swift            # 牌桌主视图（手牌布局、出牌区、玩家信息与交互）
│   │   └── RulesView.swift           # 规则说明与牌局设置面板
│   └── Welcome/
│       └── WelcomeView.swift         # 启动欢迎界面
├── Services/
│   └── SpeechService.swift           # 原生 AVSpeech 语音播报服务
└── Resources/
    ├── Assets.xcassets               # 图标、配色与启动图资源
    └── Voice.bundle                  # 预置音效资源与配置
```

---

## 🛠️ 快速开始 (Getting Started)

### 环境要求
* **Xcode 15.0+** 或 **Xcode 16.0+**
* **iOS 17.0+** / **iPadOS 17.0+** / **macOS 13.5+ (Designed for iPad)**
* **Swift 5.9+**

### 本地编译运行

1. 克隆代码仓库：
   ```bash
   git clone https://github.com/your-username/paodekuai-native.git
   cd paodekuai-native
   ```

2. 打开项目：
   ```bash
   open PaodekuaiNative.xcodeproj
   ```

3. 在 Xcode 顶部选择目标设备（例如 `iPhone 16 Pro` 模拟器），直接按下 `Cmd + R` 即可运行体验！

---

## 🤖 AI 自博弈与算法仿真 (Self-Play Simulation)

本项目内置了完整的对局仿真与数据分析套件，无需连接任何服务器即可进行 AI 自博弈：

1. 打开游戏内「设置 / 规则」面板。
2. 在开发选项中启用 **「自博弈运行」**，设定仿真局数（例如 1,000 手）。
3. 引擎将以极高速度在内存中完成全自动对弈，并自动导出 `selfplay-summary.json` 和 `latest-game-log.json`。
4. 使用 `scripts/` 目录下的 Python 工具进行胜率、得分方差与危险牌行为分析：
   ```bash
   python3 scripts/analyze_ai.py --log selfplay-summary.json
   ```

---

## 🌐 跨平台 / 微信小游戏移植建议

`Core/GameCore.swift` 和 `Core/GameStore.swift` 采用了纯函数与清晰的数据结构设计，非常易于转译到其他平台：

* **微信小游戏 / 抖音小游戏 / Web**：
  * 核心逻辑可直接使用 **TypeScript** 1:1 转译。
  * 推荐搭配 **Cocos Creator 3.x** 或 **Pixi.js** 进行 2D 牌桌渲染与动画绑定。
* **Flutter / React Native**：
  * 状态流与牌型检测模型可直接无缝移植到 Dart / TS。

---

## 🤝 贡献指南 (Contributing)

欢迎提交 Issue 或 Pull Request！
1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交修改 (`git commit -m 'Add some amazing feature'`)
4. 推送分支 (`git push origin feature/amazing-feature`)
5. 新建 Pull Request

---

## 📄 开源许可证 (License)

本项目采用 [MIT License](LICENSE) 开源。欢迎个人学习、技术研究或商业二次开发。
