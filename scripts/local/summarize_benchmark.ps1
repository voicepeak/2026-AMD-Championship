<#
.SYNOPSIS
    汇总 RoboTwin 全量 benchmark 的日志，计算 clean / randomized 成功率，产出 SUMMARY.md。

.DESCRIPTION
    扫描 <RunDir> 下的文本日志，提取每一行的 "Final success rate"，
    按 demo_clean / demo_randomized 分组求平均，写入 <RunDir>/SUMMARY.md。

    支持三种数值写法：
        Final success rate: 0.90        -> 90%
        Final success rate: 90.0%       -> 90%
        Final success rate: 9/10        -> 90%
    任务名尽量从行首 [task] 或文件名取得，取不到就留空。
    分组依据：路径或文件名出现 randomized -> randomized；否则出现 clean -> clean；都不匹配 -> unknown。

.PARAMETER RunDir
    benchmark 输出目录（例如 results/both100x10_8gpu）。

.PARAMETER OutFile
    输出文件，默认 <RunDir>/SUMMARY.md。

.EXAMPLE
    powershell -File scripts\local\summarize_benchmark.ps1 -RunDir results\both100x10_8gpu

.NOTES
    本文件必须保存为 UTF-8 with BOM，否则 Windows PowerShell 5.1 会乱码。
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RunDir,
    [string]$OutFile
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $RunDir)) { throw "RunDir 不存在: $RunDir" }
$RunDir = (Resolve-Path -LiteralPath $RunDir).Path
if (-not $OutFile) { $OutFile = Join-Path $RunDir "SUMMARY.md" }

function Get-Config([string]$path) {
    if ($path -match 'randomized') { return 'randomized' }
    if ($path -match 'clean')      { return 'clean' }
    return 'unknown'
}

function Parse-Rate([string]$line) {
    $m = [regex]::Match($line, '(\d+)\s*/\s*(\d+)')
    if ($m.Success) {
        $num = [double]$m.Groups[1].Value
        $den = [double]$m.Groups[2].Value
        if ($den -gt 0) { return [math]::Round(100.0 * $num / $den, 2) }
    }
    $m = [regex]::Match($line, '([0-9]+(?:\.[0-9]+)?)\s*%')
    if ($m.Success) { return [math]::Round([double]$m.Groups[1].Value, 2) }
    $m = [regex]::Match($line, '([0-9]*\.[0-9]+)')
    if ($m.Success) {
        $v = [double]$m.Groups[1].Value
        if ($v -le 1.0) { return [math]::Round($v * 100.0, 2) }
        return [math]::Round($v, 2)
    }
    $m = [regex]::Match($line, '([0-9]+)')
    if ($m.Success) { return [math]::Round([double]$m.Groups[1].Value, 2) }
    return $null
}

$files = @(Get-ChildItem -LiteralPath $RunDir -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -in @('.log', '.txt', '.out', '.md') -and $_.Name -ne 'SUMMARY.md' })

$rows = @()
foreach ($f in $files) {
    $rel = $f.FullName.Substring($RunDir.Length).TrimStart('\')
    $cfg = Get-Config $rel
    $lineNo = 0
    foreach ($line in (Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue)) {
        $lineNo++
        if ($line -notmatch 'Final success rate') { continue }
        $rate = Parse-Rate $line
        if ($null -eq $rate) { continue }
        $task = ''
        $tm = [regex]::Match($line, '\[([^\]]+)\]')
        if ($tm.Success) { $task = $tm.Groups[1].Value }
        if (-not $task) { $task = [System.IO.Path]::GetFileNameWithoutExtension($f.Name) }
        $rows += [pscustomobject]@{
            Config = $cfg
            Task   = $task
            Rate   = $rate
            File   = $rel
            Line   = $lineNo
        }
    }
}
$rows = @($rows)

$done = 0
$doneDir = Join-Path $RunDir 'done'
if (Test-Path -LiteralPath $doneDir) {
    $done = @(Get-ChildItem -LiteralPath $doneDir -File -ErrorAction SilentlyContinue).Count
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("# Benchmark 汇总")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("- 目录: ``$RunDir``")
[void]$sb.AppendLine("- 生成时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
[void]$sb.AppendLine("- 扫描文件数: $(@($files).Count)")
[void]$sb.AppendLine("- 命中 'Final success rate' 行数: $(@($rows).Count)")
[void]$sb.AppendLine("- done 标记数: $done")
[void]$sb.AppendLine("")

if (@($rows).Count -eq 0) {
    [void]$sb.AppendLine("> 未解析到任何 'Final success rate'。请确认日志已拉回本地，或日志格式有变。")
} else {
    [void]$sb.AppendLine("## 分组成功率")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| 分组 | 任务数 | 平均成功率 |")
    [void]$sb.AppendLine("|---|---:|---:|")
    foreach ($cfg in @('clean', 'randomized', 'unknown')) {
        $g = @($rows | Where-Object { $_.Config -eq $cfg })
        if ($g.Count -eq 0) { continue }
        $avg = [math]::Round(($g | Measure-Object -Property Rate -Average).Average, 2)
        [void]$sb.AppendLine("| $cfg | $($g.Count) | $avg% |")
    }

    $overall = [math]::Round((@($rows) | Measure-Object -Property Rate -Average).Average, 2)
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("**总平均: $overall%**（所有分组混合）")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## 逐条明细")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| 分组 | 任务 | 成功率 | 文件:行 |")
    [void]$sb.AppendLine("|---|---|---:|---|")
    foreach ($r in ($rows | Sort-Object Config, Task)) {
        [void]$sb.AppendLine("| $($r.Config) | $($r.Task) | $($r.Rate)% | ``$($r.File):$($r.Line)`` |")
    }
}

Set-Content -LiteralPath $OutFile -Encoding UTF8 -Value $sb.ToString()

$nClean = @($rows | Where-Object { $_.Config -eq 'clean' }).Count
$nRand  = @($rows | Where-Object { $_.Config -eq 'randomized' }).Count
Write-Host ("[summarize] 已写入 {0}" -f $OutFile) -ForegroundColor Green
Write-Host ("[summarize] 命中 {0} 条（clean={1}, randomized={2}）" -f @($rows).Count, $nClean, $nRand) -ForegroundColor Cyan
