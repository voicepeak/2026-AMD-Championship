# scripts/local —— 本地管理脚本（PowerShell / Windows）

## 首次使用

```powershell
cd D:\LingBot-VLA-Challenge
Copy-Item scripts\local\config.example.ps1 scripts\local\config.secret.ps1
notepad scripts\local\config.secret.ps1   # 填入实例 host / port / user
```

> `config.secret.ps1` 已被 `.gitignore` 忽略，不会入库。

## 常用

| 命令 | 作用 |
|---|---|
| `powershell -File scripts\local\sync_up.ps1` | 上传 `scripts/cloud` 和 `configs` 到实例 |
| `powershell -File scripts\local\sync_down.ps1` | 拉回 `eval_result` |
| `powershell -File scripts\local\sync_down.ps1 both100x10_8gpu` | 拉回指定 benchmark 结果 |
| `powershell -File scripts\local\summarize_benchmark.ps1 -RunDir results\<run>` | 汇总单个 run 的成功率 → `SUMMARY.md` |
| `powershell -File scripts\local\report_experiments.ps1` | 汇总所有 run → `results\OVERVIEW.md` |

## 前置

- 本机已 `ssh-keygen` 并把公钥加到 Radeon Cloud（Settings → New SSH Key）
- Windows 自带 OpenSSH（`ssh` / `scp`），已确认可用

## 注意：`.ps1` 必须 UTF-8 with BOM

Windows PowerShell 5.1 读取无 BOM 的 UTF-8 `.ps1` 会乱码并解析失败（中文尤甚）。
本目录脚本均已带 BOM。**新增/改动 `.ps1` 后请确认保留 BOM**：

```powershell
$enc = New-Object System.Text.UTF8Encoding($true)
$f = "scripts\local\xxx.ps1"
[System.IO.File]::WriteAllText($f, [System.IO.File]::ReadAllText($f,[Text.Encoding]::UTF8), $enc)
```

## 建议

- 大文件（checkpoint、视频）**不要**用这些脚本拉，改用云端打包 + 网盘/对象存储
- 每次全量评测后立即 `sync_down` + `summarize_benchmark`，避免实例销毁后丢结果
