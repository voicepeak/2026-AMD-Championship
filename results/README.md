# results —— 从云端拉回的评测结果

存放小型结果文件：成功率 JSON、日志摘要、汇总表（`scripts/local/sync_down.ps1` 会写到这里）。

## 约定

- 每次评测一个子目录，用 run-name 命名：`results/both100x10_8gpu/`
- 大文件（checkpoint、视频）不要放这里
- 建议每个 run 目录里放一份 `SUMMARY.md`：

```
results/both100x10_8gpu/
├── SUMMARY.md      # 成功率、耗时、结论
├── eval_result/    # 原始结果
└── outputs/        # 日志摘要
```

## 汇总表（手动维护，方便对比）

| run-name | 模型 | clean | randomized | 备注 |
|---|---|---|---|---|
| | | | | |
