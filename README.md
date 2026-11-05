# PowerControl · iOS 原生控制端

自己写的一个小 App，管家里那台电脑的开关机。用的是你已有的付费开发者证书，签一次管一年。

## 工程结构

```
ios/
├── project.yml                    XcodeGen 工程描述
├── PowerControl/
│   ├── PowerControlApp.swift      入口
│   ├── ContentView.swift          主界面
│   ├── SettingsView.swift         设置页
│   ├── Network.swift              HTTP + WoL
│   ├── Store.swift                配置存储
│   └── Info.plist                 ATS、本地网络权限
└── .github/workflows/build.yml    云端编译出未签名 ipa
```

## 编译

### 有 Mac

```bash
brew install xcodegen
cd ios
xcodegen generate
open PowerControl.xcodeproj
```

Xcode 里选中 target → Signing & Capabilities：

- Team 选你自己的开发者账号
- Bundle Identifier 改成你账号下没被占用的，比如 `com.yourname.powercontrol`
- 手机用数据线连上，选它作为运行目标

按 ⌘R 就装进去了。付费证书签的包有效期一年，到期重新签一次即可。

### 没 Mac

推到 GitHub，Actions 会自动跑 `build-ipa`，产出 `PowerControl-unsigned.ipa`。

这个 ipa 没有签名，要用 Sideloadly 或 AltStore 拿你的证书签：

```
Sideloadly 里填：
  IPA      = PowerControl-unsigned.ipa
  Apple ID = 你的开发者账号
  然后 Start
```

付费证书签出来的包，Sideloadly 会走 `Apple Distribution` 而不是 7 天那种临时证书。

## 装完先设三样

打开 App 右上角齿轮：

| 项 | 填什么 | 说明 |
|---|---|---|
| 小米路由器 | `http://192.168.1.88` | 局域网里发魔术包 |
| 外网地址 | 小米的 ZeroTier IP | 出门时打开下面那个开关 |
| 电脑 | `http://192.168.1.235:8765` | 关机/重启打这里 |
| 口令 | `77c52ec8a779849b` | 和 config.json 一致 |

设完点「测试连接」，会分别测电脑和路由器两条路。

## 它做什么

- **开机**：GET `http://小米/cgi-bin/wake?token=xxx`，路由器收到后 `etherwake` 发魔术包
- **关机/重启/睡眠/锁屏**：POST `http://电脑:8765/api/action`，body `{"action":"shutdown"}`
- **状态**：每 10 秒 GET 一次 `/api/status`，顶部圆点跟着变

## 出门用

手机装 ZeroTier One，加入家里那个网络，然后在 App 设置里：

1. 「外网地址」填小米的 `10.147.x.x`
2. 打开「出门时用这个地址」

之后在外面点开机，请求走 ZeroTier 隧道进小米，照样能发魔术包。关机那条还是会失败，因为电脑不在隧道里——除非你也在 Windows 上装 ZeroTier 客户端。

## 已知限制

- iOS 不允许后台常驻，App 关掉之后状态就不刷了，重新打开会立刻刷新一次
- 魔术包必须由局域网内的设备发，手机直接发 UDP 广播只在手机连着家里 WiFi 时有效，所以走路由器那条路更稳
- `Network.swift` 里留了 `wakeDirect()`，是手机在家时绕过路由器的备用方案，目前界面上没接
