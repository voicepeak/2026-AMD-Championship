# 把 scripts/cloud 和 configs 上传到云端实例
# 用法：powershell -File scripts\local\sync_up.ps1
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here "config.secret.ps1")

$root = $Config.LocalRoot
$target = "$($Config.SshUser)@$($Config.SshHost)"
$port = $Config.SshPort
$remote = $Config.RemoteDir

Write-Host "[up] 目标 $target  (port $port)  远程: $remote" -ForegroundColor Cyan

ssh -p $port $target "mkdir -p '$remote/scripts/cloud' '$remote/configs'"

Write-Host "[up] 上传 scripts/cloud ..." -ForegroundColor Cyan
scp -P $port -r "$root\scripts\cloud" "${target}:$remote/scripts/"

if (Test-Path "$root\configs") {
    Write-Host "[up] 上传 configs ..." -ForegroundColor Cyan
    scp -P $port -r "$root\configs" "${target}:$remote/"
}

Write-Host "[up] 完成。到云端执行：" -ForegroundColor Green
Write-Host "     ssh -p $port $target" -ForegroundColor Gray
Write-Host "     cd $remote/scripts/cloud; bash 00_check_env.sh" -ForegroundColor Gray
