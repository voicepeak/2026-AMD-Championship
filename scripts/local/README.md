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

## 前置

- 本机已 `ssh-keygen` 并把公钥加到 Radeon Cloud（Settings → New SSH Key）
- Windows 自带 OpenSSH（`ssh` / `scp`），已确认可用

## 建议

- 大文件（checkpoint、视频）**不要**用这些脚本拉，改用云端打包 + 网盘/对象存储
- 每次全量评测后立即 `sync_down`，避免实例销毁后丢结果
