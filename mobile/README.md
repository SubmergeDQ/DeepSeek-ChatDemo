# DeepChat（Android / iOS）

基于本仓库 Web 聊天示例实现的 Flutter 移动端：自带 API Key，支持多服务商与多模型切换。

## 功能

- 多会话：自动标题、重命名、删除、按日期分组、本地搜索。
- 流式回复、深度思考展示、停止生成、重新生成、继续生成、消息分支切换。
- 编辑提问、复制、分享、朗读、Markdown / 代码高亮 / KaTeX 公式 / 表格。
- 联网搜索与来源引用（DeepSeek 官方协议）、链接阅读。
- 附件：图片、PDF、Word、PPT 与文本文件（服务商能力不同）。
- 语音输入（DeepSeek / OpenAI 兼容服务）与系统 TTS 朗读。
- 浅色 / 深色 / 跟随系统，简体中文 / English。
- 对话 JSON 导入导出；API Key 仅保存在本机。

## 服务商

| 服务商 | 协议 | 说明 |
| --- | --- | --- |
| DeepSeek | Anthropic 兼容扩展 | 深度思考、联网搜索、文件上传、自动标题 |
| DeepSeek (OpenAI) | OpenAI Chat Completions | 开放平台 `deepseek-chat` / `deepseek-reasoner` |
| OpenAI | OpenAI Chat Completions | 可获取模型列表 |
| Anthropic | Messages API | 扩展思考、图片 |
| Google Gemini | generateContent | 思考过程、图片 |
| OpenRouter | OpenAI 兼容 | 自动模型路由 |
| 自定义 | OpenAI / Anthropic / Gemini / DeepSeek | 任意兼容接口，支持改 Base URL |

本地 Ollama / LM Studio 等无需鉴权的服务，API Key 填任意非空值即可。

## 运行与构建

```sh
cd mobile
flutter pub get
flutter run
```

构建签名 APK：

1. 在 `android/key.properties` 填写 `storePassword`、`keyPassword`、`keyAlias` 与 `storeFile`（该文件已被 git 忽略）。
2. 执行：

```sh
flutter build apk --release
```

产物：`build/app/outputs/flutter-apk/app-release.apk`。

## 说明

- 聊天与附件保存在本机 SQLite / 应用文档目录；设置与 API Key 保存在 SharedPreferences。
- DeepSeek 官方协议依赖本仓库示例使用的 Anthropic 兼容接口；若你的 Key 不可用，可改用内置的 `DeepSeek (OpenAI)` 或自定义 OpenAI 兼容服务。
- 语音输入使用对应服务商的 ASR：DeepSeek `/v1/tools/asr`，OpenAI 兼容 `/audio/transcriptions`（`whisper-1`）。
- 朗读使用设备自带 TTS，不消耗 API 额度。
- iOS 工程已配置麦克风权限；iOS 构建需要 macOS 与 Xcode。
