# 初赛提交物 · Checklist

> 截止：**2026-10-26 24:00**。官方提交细则尚未完全公开，凡标 ⚠️ 的项须到官方钉钉群确认后勾选。
> 每项写清"怎么产出"，完成后打勾。

## 0. 官方细则确认（先去群里问清楚）

- [ ] ⚠️ 提交入口/格式（模型 checkpoint？代码？评测结果？）
- [ ] ⚠️ 官方评测环境（AMD ROCm 统一评测，还是选手自跑？）
- [ ] ⚠️ 是否要求/检查使用 AMD 算力
- [ ] ⚠️ 文件体积、命名、截止精确时间
- [ ] ⚠️ 决赛真机平台与接口要求

## 1. 模型产出

- [ ] 从**官方基础 checkpoint** 起训（记录起点 revision）
- [ ] 训练只用 **clean 数据**（保留 `train_path` 指向的清单截图/记录）
- [ ] 合并/转换出可推理的 `hf_ckpt`
  - LoRA：`merge_lora_dcp.py` → `merged_checkpoint/global_step_<N>/hf_ckpt`
  - SFT：`convert_full_sft_dcp.py`
- [ ] 在官方环境（AMD 镜像）**完整跑一遍推理**，确认可加载、action 形状 `[25,14]`
- [ ] 记录模型体积、参数量、显存占用

## 2. 评测结果

- [ ] 全量评测：50 `demo_clean` + 50 `demo_randomized` × 10 episodes
- [ ] 用 `scripts/local/summarize_benchmark.ps1` 生成 `results/<run>/SUMMARY.md`
- [ ] 用 `scripts/local/report_experiments.ps1` 生成 `results/OVERVIEW.md`
- [ ] 关键日志、截图、成功率表归档

## 3. 代码与复现

- [ ] 训练/评测命令完整记录（`experiments/*.md`）
- [ ] 派生配置（`configs/*.yaml`）与上游改动（`patches/`）
- [ ] 环境版本固定（上游 commit、镜像 tag、torch/ROCm 版本）
- [ ] 无 randomized 参与训练的证明

## 4. 文档

- [ ] 方案说明（思路、数据、配置、结论）
- [ ] 复现步骤（可从零跑通）
- [ ] 与 baseline 的对比

## 5. 合规

- [ ] 无抄袭、无第三方侵权；开源组件许可合规
- [ ] 账号唯一，无多队刷分
- [ ] 提交材料与实际结果一致

## 6. 备份

- [ ] 模型 checkpoint 存到持久存储并另存一份
- [ ] 结果/日志/文档 `git push` 到远端
- [ ] 实例销毁前确认所有产出已落 `/workspace` 并拉回本地

---

## 提交前最终检查（提交当天）

```
[ ] 模型能在官方环境加载并跑通
[ ] 结果表已填、已复核
[ ] 所有材料已备份
[ ] 已在截止前提交并截图留证
```
