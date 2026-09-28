<#
.SYNOPSIS
    汇总各实验的 SUMMARY.md，生成 results/OVERVIEW.md 对比总表。

.DESCRIPTION
    扫描 <ResultsRoot> 下每个子目录的 SUMMARY.md（由 summarize_benchmark.ps1 产出），
    提取 clean / randomized / 总平均成功率，汇总成一张对比表。

.PARAMETER ResultsRoot
    结果根目录，默认 <仓库>/results。

.EXAMPLE
    powershell -File scripts\local\report_experiments.ps1

.NOTES
    本文件必须保存为 UTF-8 with BOM，否则 Windows PowerShell 5.1 会乱码。
#>
[CmdletBinding()]
param(
    [string]$ResultsRoot
)

$ErrorActionPreference = "Stop"

if (-not $ResultsRoot) {
    $ResultsRoot = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "results"
}
if (-not (Test-Path -LiteralPath $ResultsRoot)) { throw "ResultsRoot 不存在: $ResultsRoot" }
$ResultsRoot = (Resolve-Path -LiteralPath $ResultsRoot).Path

$summaries = @(Get-ChildItem -LiteralPath $ResultsRoot -Recurse -File -Filter 'SUMMARY.md' -ErrorAction SilentlyContinue)
$rows = @()

foreach ($s in $summaries) {
    $run = $s.Directory.Name
    $text = Get-Content -LiteralPath $s.FullName -Raw -Encoding UTF8
    $clean = ''
    $rand = ''
    $overall = ''
    foreach ($line in ($text -split "`r?`n")) {
        $m = [regex]::Match($line, '^\|\s*(clean|randomized)\s*\|\s*\d+\s*\|\s*([0-9.]+)%\s*\|')
        if ($m.Success) {
            if ($m.Groups[1].Value -eq 'clean') { $clean = $m.Groups[2].Value }
            else { $rand = $m.Groups[2].Value }
        }
        $m2 = [regex]::Match($line, '总平均[:：]\s*([0-9.]+)%')
        if ($m2.Success) { $overall = $m2.Groups[1].Value }
    }
    $rows += [pscustomobject]@{
        Run       = $run
        Clean     = if ($clean)   { "$clean%" }   else { '-' }
        Randomized= if ($rand)    { "$rand%" }    else { '-' }
        Overall   = if ($overall) { "$overall%" } else { '-' }
        Path      = $run
    }
}
$rows = @($rows | Sort-Object Run)

$out = Join-Path $ResultsRoot 'OVERVIEW.md'
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("# 实验总览")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("- 生成时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
[void]$sb.AppendLine("- 来源: ``$ResultsRoot`` 下各子目录的 SUMMARY.md")
[void]$sb.AppendLine("- 实验数: $(@($rows).Count)")
[void]$sb.AppendLine("")
if (@($rows).Count -eq 0) {
    [void]$sb.AppendLine("> 还没有任何 SUMMARY.md。先跑全量 benchmark，再运行 summarize_benchmark.ps1。")
} else {
    [void]$sb.AppendLine("| run-name | clean | randomized | 总平均 |")
    [void]$sb.AppendLine("|---|---:|---:|---:|")
    foreach ($r in $rows) {
        [void]$sb.AppendLine("| $($r.Run) | $($r.Clean) | $($r.Randomized) | $($r.Overall) |")
    }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("> 说明：clean / randomized 为该组任务平均成功率；总平均为所有命中条目混合平均。")
}

Set-Content -LiteralPath $out -Encoding UTF8 -Value $sb.ToString()
Write-Host ("[report] 已写入 {0}（{1} 个实验）" -f $out, @($rows).Count) -ForegroundColor Green
