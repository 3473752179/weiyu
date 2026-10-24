# 未语远端书写服务

提供两个不依赖第三方模型的接口：

- `POST /api/v1/prompts/match`：按写信对象和情绪匹配远端书写提示，支持自定义文本与兜底。
- `POST /api/v1/afterglow`：按对象、情绪和标题从规则模板库组合余光候选、关键词和回声。

## 本地运行

1. 安装 Node.js 18 或更高版本。
2. 执行 `npm test`。
3. DevEco 模拟器联调时执行 `powershell -ExecutionPolicy Bypass -File .\start-emulator-service.ps1`。
4. 脚本会建立 `tcp:8787` 反向映射并启动服务，应用优先通过 `http://127.0.0.1:8787` 访问。

余光灵感不会读取或上传正文、照片，也不需要 API Key。自定义写信对象与自定义情绪会先经过关键词归类，无法识别时使用通用模板兜底。

部署到云端后，将 `RemoteWritingConfig.ets` 中的 HTTPS 地址放在 `API_BASE_URLS` 数组首位，并重新构建应用。
