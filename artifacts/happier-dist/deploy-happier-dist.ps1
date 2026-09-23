# Happier 自托管 CLI 新构建部署脚本（Windows）
# 用途：把 Mac 上构建好的 v0.2.13（含 qwen 模型列表修复）部署到 Windows，
#       替换官方 0.2.12，让 Windows daemon 也能显示 qwen 模型列表。
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File .\deploy-happier-dist.ps1 -PackagePath C:\path\to\happier-cli-dist-v0.2.13.tar.gz
#
# 前置：本机有 node（PATH 中），tar.exe（Windows 10+ 自带）

param(
    [Parameter(Mandatory = $true)]
    [string]$PackagePath
)

$ErrorActionPreference = 'Stop'

$deployDir = Join-Path $env:USERPROFILE '.happier-dist'
$distEntry = Join-Path $deployDir 'dist\index.mjs'

Write-Host "==> 1/4 解压新构建到 $deployDir"
New-Item -ItemType Directory -Force -Path $deployDir | Out-Null
tar -xzf $PackagePath -C $deployDir
if (-not (Test-Path $distEntry)) { throw "解压失败：$distEntry 不存在" }
Write-Host "    完成（入口: $distEntry）"

Write-Host "==> 2/4 停止旧 daemon（0.2.12，官方安装）"
$oldCli = Join-Path $env:USERPROFILE '.happier\bin\happier.exe'
if (Test-Path $oldCli) {
    try { & $oldCli daemon stop 2>&1 | Out-Null; Write-Host "    旧 daemon 已停止" }
    catch { Write-Host "    （旧 daemon 未在运行或停止失败，继续）" }
} else {
    Write-Host "    （未找到旧 CLI，跳过）"
}
Start-Sleep -Seconds 3

Write-Host "==> 3/4 用新构建启动 daemon"
& node $distEntry daemon start
if ($LASTEXITCODE -ne 0) { throw "daemon start 失败（exit $LASTEXITCODE）" }
Start-Sleep -Seconds 5

Write-Host "==> 4/4 验证 daemon 状态（应显示 0.2.13）"
& node $distEntry daemon status

Write-Host ""
Write-Host "部署完成。日常查看模型列表：新建 qwen 会话时模型选择器应显示 settings.json 中的模型。"
