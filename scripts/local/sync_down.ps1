# 从云端实例拉回评测/训练结果（只拉小文件：json / md / 日志摘要 / txt）
# 用法：powershell -File scripts\local\sync_down.ps1 [run-name]
#   例：powershell -File scripts\local\sync_down.ps1 both100x10_8gpu
param(
    [string]$RunName = ""
)
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here "config.secret.ps1")

$root = $Config.LocalRoot
$target = "$($Config.SshUser)@$($Config.SshHost)"
$port = $Config.SshPort
$remote = $Config.RemoteRuntime
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"

$dest = if ($RunName) { Join-Path $root "results\$RunName" } else { Join-Path $root "results\inbox_$stamp" }
New-Item -ItemType Directory -Force -Path $dest | Out-Null

Write-Host "[down] 拉取 $target:$remote -> $dest" -ForegroundColor Cyan

# 评测结果目录
scp -P $port -r "${target}:$remote/eval_result" "$dest\"

# 只拉 benchmark 输出里的小文件（json/log/txt/csv），避免拉回巨大 checkpoint
if ($RunName) {
    scp -P $port -r "${target}:$remote/outputs/$RunName" "$dest\"
} else {
    Write-Host "[down] 未指定 run-name，只拉了 eval_result。要拉具体 benchmark 请传入 run-name。" -ForegroundColor Yellow
}

Write-Host "[down] 完成 -> $dest" -ForegroundColor Green
Get-ChildItem -Recurse -File $dest | Select-Object FullName, @{n="KB";e={[math]::Round($_.Length/1KB,1)}} | Format-Table -AutoSize
