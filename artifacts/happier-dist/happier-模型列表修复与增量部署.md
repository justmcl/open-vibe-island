# Happier qwen 模型列表修复 — 改动与部署说明

> 2026-09-23 · 分支 `feat/qwen-settings-models-probe` · 提交 `04eb85d6`
> 仓库：`/Users/just/Documents/repo/ai-visual/happier`

## 一、问题

qwen-code 的 ACP 握手响应**不暴露模型能力**（完整响应实测：agentCapabilities 只有 loadSession / promptCapabilities / sessionCapabilities / mcpCapabilities / _meta，无 modelCapabilities）。
而 qwen 的模型都定义在 **`~/.qwen/settings.json` 的 `modelProviders`** 里（每台机器一份，自定义模型）。
Happier 对 qwen 只走 ACP → 模型探测四路全空 → UI 模型选择器只剩 "Default"。
Paseo 能显示是因为它额外读了 qwen 的 settings.json。

## 二、修复

给 qwen 后端加了一个 **preflight probe adapter**（参考 claude/cursor 同款机制），直接读 `~/.qwen/settings.json` 的 `modelProviders`，把 `{id, name}` 喂给 Happier 标准模型探测管线。

改动文件：
- `apps/cli/src/backends/qwen/preflight/qwenSettingsModelsProbe.ts`（新增：解析 + adapter）
- `apps/cli/src/backends/qwen/preflight/qwenSettingsModelsProbe.test.ts`（新增：4 个单元测试）
- `apps/cli/src/backends/qwen/index.ts`（注册 `getPreflightSessionControlsProbeAdapter`）

## 三、验证结果

| 验证 | 结果 |
|---|---|
| 单元测试（解析逻辑 4 例） | ✅ 全过 |
| 既有模型探测测试（agentModelsProbe.staticOnly 6 例） | ✅ 未破坏 |
| typecheck（apps/cli） | ✅ 通过 |
| 真实链路 `probeAgentModelsBestEffort(qwen)` | ✅ `source: "dynamic"`，返回 Mac 上 10 个模型 + Default |
| Mac daemon（0.2.13，新构建） | ✅ 运行中 |

Mac 上 probe 实际返回的模型（来自 `~/.qwen/settings.json`）：
doubao-seed-2.0-lite-plan_hs_p、glm-5.2-plan_hs_p、glm5.3flash2（默认）、glm5.3flash、glm-5.3、deepseek-v4-flash、glm-5.2-plan_hs_p-2、deepseek-v4-flash_hs_p、deepseek-v4.1-flash_hs_p、deepseek-v4.1-flash_hs_p-2

## 四、已运行新版本（Mac）

- CLI 构建产物：`apps/cli/dist/`（0.2.13，rollup 自包含 bundle，0 外部依赖）
- daemon：`node apps/cli/dist/index.mjs daemon start` 启动，状态 ✓ 0.2.13（PID 19798）
- 登录自启：LaunchAgent `~/Library/LaunchAgents/com.happier.cli.daemon.manual.plist`
  （登录时用 nvm node 跑 `daemon start`，不涉及服务模式授权等待）
- ⚠️ 曾尝试 `service install`（launchd 服务模式），因 `HAPPIER_DAEMON_WAIT_FOR_AUTH=1`
  （首次后台服务需要用户在 App 授权）在无人值守时无法完成，已 `service uninstall` 回退到手动 + 登录自启。

## 五、Windows 部署（待执行）

Mac 上已打包好新构建（自包含，无需 node_modules）：
- **包**：`open-vibe-island/artifacts/happier-dist/happier-cli-dist-v0.2.13.tar.gz`（5.6MB）
- **脚本**：`open-vibe-island/artifacts/happier-dist/deploy-happier-dist.ps1`

在 Windows 上执行（把两个文件拷过去）：
```powershell
powershell -ExecutionPolicy Bypass -File .\deploy-happier-dist.ps1 -PackagePath .\happier-cli-dist-v0.2.13.tar.gz
```
脚本会：解压到 `%USERPROFILE%\.happier-dist` → 停旧 daemon（0.2.12）→ `node dist\index.mjs daemon start` → 验证 0.2.13。
之后 Windows 上新建 qwen 会话也能显示模型列表。

## 六、日常命令备忘

```bash
# 启动 daemon（Mac，新构建）
node /Users/just/Documents/repo/ai-visual/happier/apps/cli/dist/index.mjs daemon start
# 查看状态
node /Users/just/Documents/repo/ai-visual/happier/apps/cli/dist/index.mjs daemon status
# CLI 指定模型启动 qwen
happier qwen --model glm5.3flash2
```

## 七、遗留说明

- UI 端到端（手机/Web 新建 qwen 会话看到模型列表）需要登录态，未做自动化验证；
  逻辑链路（supportsSelection=true + dynamicProbe=auto + probe 返回 10 模型）已全部确认，UI 显示是 Happier 既有机制。
- qwen 模型选择后生效方式：CLI `--model <id>`（settings.json 里的 id），或 qwen 默认模型（settings.json `model.name`）。
- 若要向 Happier 上游贡献，可按此分支提 PR（dev 分支基线）。
