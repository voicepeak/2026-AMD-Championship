# 10 · CUDA / 4090 上跑 LoRA 全量（Runbook）

> 用于不依赖 AMD 算力、直接在 NVIDIA 卡上训练。已在 1×RTX 4090 48G 验证。
> 环境搭建见 `docs/09-4090-debug-env.md`；本文件是从"有环境"到"训练中"的步骤。

## 0. 前置（一次性）

```bash
# 1) 上游代码 + 固定版本（见 docs/09）
#    lingbot-vla-v2 @ 951475ae, RoboTwin @ 266f3aad（含 XPolicyLab 子模块）
# 2) conda 环境 lingbotvla（见 docs/09）
# 3) 数据中心：/home/featurize/runtime/{models,data,outputs,outputs/logs}
```

## 1. 关键补丁（必须）

上游 `lingbot-vla-v2 @951475ae` **没有 LoRA 参数**，LoRA 支持来自 AMD 官方补丁：

```bash
cd <work>/lingbot-vla-v2
git apply /path/to/patches/amd-lingbot-vla-v2-rocm.patch   # 仓库 patches/amd-lingbot-vla-v2-rocm.patch
```

补丁带来：LoRA 参数（`use_lora/lora_rank/lora_alpha/lora_scope/lora_target_modules`）、
空列表解析修复、LeRobot 0.6 兼容、推理端修复。
> 若只做全参数 SFT（不用 LoRA），仍建议打此补丁（含解析修复等）。

## 2. 下载全量 clean 数据（50 任务）

```bash
cd <work>/RoboTwin
PATH=<env>/bin:$PATH ROBOTWIN_DATA_ROOT=<runtime>/data/robotwin \
  HF_ARCHIVE_CACHE=<runtime>/data/download_cache HF_KEEP_ARCHIVES=0 \
  bash scripts/download_xpolicylab_data.sh            # 无参 = 全部 50 任务
```

## 3. 转换为 LeRobot 数据集（并行）

```bash
# v21 转换器（本机 lerobot 0.4.2；v30 需要 lerobot 0.6.0）
JOBS=6 bash <repo>/scripts/cuda/convert_all_data_v21.sh
# 产物：<runtime>/data/lerobot/<task>_joint_v21
# 清单：<runtime>/data/robotwin_demo_clean_joint_v21.txt
```

## 4. 启动 LoRA 训练（后台）

```bash
cd <repo>
nohup env NGPU=1 STEPS=2000 SAVE=250 MICRO=1 WORKERS=8 GLOBAL_BATCH=8 \
  RUN_NAME=lora_full_1gpu bash scripts/cuda/train_lora.sh \
  > <runtime>/outputs/logs/lora_full_1gpu_outer.log 2>&1 &
```

- 8 卡：`NGPU=8`（grad_accum 自动 = `GLOBAL_BATCH/(MICRO*NGPU)`）
- 2000 步 ≈ 8.5 小时（1×4090，~15s/步）；checkpoint 每 250 步一存
- 全程写 `<runtime>/outputs/lora_full_1gpu/`

## 5. 合并 LoRA（训练后）

参考 `scripts/cloud/31_merge_lora.sh` 的 `merge_lora_dcp.py` 调用，路径改为本机：

```bash
<env>/bin/python <work>/RoboTwin/experiments/.../scripts/merge_lora_dcp.py \
  --checkpoint <out>/checkpoints/global_step_2000 \
  --training-output <out> \
  --base-model <runtime>/models/robbyant_lingbot-vla-v2-6b \
  --output <out>/merged_checkpoint/global_step_2000/hf_ckpt \
  --rank 8 --alpha 16
```

## 6. 评测（闭环）

需要仿真资产：

```bash
cd <work>/RoboTwin && PATH=<env>/bin:/usr/bin:/bin bash scripts/_download_assets.sh
```

然后按 `docs/04-cloud-runbook.md` 第 6/7 节的 RoboTwin 闭环流程（把模型服务指向合并后的 `hf_ckpt`）。
> CUDA 上可用 CuRobo（默认），无需像 AMD 那样设 `ROBOTWIN_DISABLE_CUROBO=1`。

## 7. 结果汇总

```powershell
powershell -File scripts\local\summarize_benchmark.ps1 -RunDir results\<run>
powershell -File scripts\local\report_experiments.ps1
```

## 已知坑

| 现象 | 解决 |
|---|---|
| `Some specified arguments are not used ... ['--train.use_lora' ...]` | 打 AMD 补丁（第 1 节） |
| `--model.basic_modules: expected at least one argument` | 配置里空列表改 `null`，或打补丁 |
| `leRobotDataset.create() ... streaming_encoding` | 用 v21 转换器（本机 lerobot 0.4.2） |
| `find` 找不到任务 | `RoboTwin/data/demo_clean` 是符号链接，用真实路径 |
