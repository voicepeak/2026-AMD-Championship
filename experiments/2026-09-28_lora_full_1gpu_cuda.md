# CUDA 4090 · LoRA 全量训练

## 元信息

- 日期：2026-09-28
- 实例：Featurize RTX 4090 48GB × 1（CUDA）
- 负责人：opencode
- 目的：不等 AMD 审批，先在 4090 上跑通并启动 **LoRA 全量训练**（50 任务，clean）

## 数据准备

- 下载：`scripts/download_xpolicylab_data.sh`（无参 = 50 任务）→ `runtime/data/robotwin/demo_clean`（50 任务）
- 转换：`scripts/cuda/convert_all_data_v21.sh`（并行 6，约 50 分钟）→ `runtime/data/lerobot/<task>_joint_v21`
- 清单：`runtime/data/robotwin_demo_clean_joint_v21.txt`（50 行，格式 `robotwin <path>`）

> 转换用 **v21** 而非官方的 v30：镜像里 lerobot 为 0.4.2，v30 转换器需要的
> `LeRobotDataset.create(streaming_encoding=...)` 不存在。上游 README 明确支持 v2.1/v3.0 两种数据集。

## 关键发现 / 修复

1. **LoRA 支持来自 AMD 补丁，不在上游 951475ae 里**。
   上游 `tasks/vla/train_lingbotvla.py` 没有 `use_lora/lora_rank/lora_alpha/lora_scope/lora_target_modules`
   等参数，直接跑 LoRA 配置会报 `Some specified arguments are not used by the ArgumentParser`。
   → 应用了 AMD 官方补丁 `docker/patches/lingbot-vla-v2-rocm.patch`（已存 `patches/amd-lingbot-vla-v2-rocm.patch`），
   它同时带来 LoRA 支持 + 空列表解析修复 + LeRobot 0.6 兼容 + 推理端若干修复。

2. **上游 `parse_args` 对空列表有 bug**：YAML 里 `[]` 会被转成"只有 flag 没有值"，
   触发 `--model.basic_modules: expected at least one argument`。
   → 派生配置里所有空列表改成 `null`（代码会跳过并使用默认值）；补丁也修了此问题。

3. `RoboTwin/data/demo_clean` 是符号链接，`find` 默认不跟随 → 脚本改用真实路径。

## 训练配置

- 配置：`configs/lora_1000_8gpu.yaml`（用 CLI 覆盖路径/并行/步数/输出）
- 启动：`scripts/cuda/train_lora.sh`
- 命令：
  ```bash
  NGPU=1 STEPS=2000 SAVE=250 MICRO=1 WORKERS=8 GLOBAL_BATCH=8 \
  RUN_NAME=lora_full_1gpu bash scripts/cuda/train_lora.sh
  ```
- 关键参数：`use_lora=true`、`lora_scope=action_expert`、rank 8、alpha 16、目标 `q/k/v/o_proj`、AdamW、lr 1e-4
- 并行：fsdp2，shard=1，micro=1，grad_accum=8 → global_batch=8

## 性能实测（1×4090 48G）

| 配置 | 每步耗时 | 显存峰值 |
|---|---|---|
| micro=1, workers=4 | ~20.6s | 24.8GB |
| micro=4, workers=4 | ~19.7s | 27.3GB |
| micro=4, workers=12 | ~20.7s | 27.3GB |
| 正式运行 micro=1, workers=8 | **~15.4s** | ~25GB |

结论：**不是数据/worker 瓶颈，是单卡算力瓶颈**；micro batch 加大无明显收益。
2000 步 ≈ **8.5 小时**。要提速需多卡（2×4090 FSDP2 约可减半）。

## 验收证据

- 冒烟 5 步通过：checkpoint 存于 `outputs/lora_smoke/checkpoints/global_step_5`
- 全量训练进行中：`outputs/lora_full_1gpu/checkpoints/global_step_{250,500,...}`

## 下一步

1. 训练完成后合并：`merge_lora_dcp.py`（参考 `scripts/cloud/31_merge_lora.sh`，改路径）
2. 下载仿真资产（进行中）→ 单任务闭环验证 → 验证子集评测
3. 全量评测（50 clean + 50 randomized）或用 `scripts/local/summarize_benchmark.ps1` 汇总

## 相关

- 环境搭建：`docs/09-4090-debug-env.md`
- 补丁：`patches/amd-lingbot-vla-v2-rocm.patch`
- 转换脚本：`scripts/cuda/convert_all_data_v21.sh`；训练脚本：`scripts/cuda/train_lora.sh`
