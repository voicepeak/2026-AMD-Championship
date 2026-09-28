# 04 · 云端操作手册（Radeon Cloud Runbook）

> 所有命令都在**云端实例**里执行（bash）。本地脚本见 `scripts/local/`。
> 本文命令均来自 AMD 官方复现指南 `Robotwin-radeon-cloud/Reproduce_Guide.md`，已整理。
> 对应的封装脚本在 `scripts/cloud/`，可直接上传使用。

## 0. 固定版本（官方复现基准）

| 组件 | 版本/提交 |
|---|---|
| 基础镜像 | `rocm/pytorch:rocm7.2.1_ubuntu24.04_py3.12_pytorch_release_2.9.1` |
| 赛事镜像 | `robotwin-lingbot-vla-v2:rocm7.2.1_...`（full / external-data 两版） |
| RoboTwin | `266f3aadf505a4f7fe9af0faa41a20f5f47cd123` |
| XPolicyLab | `c37109c500be67d0dea6b36bf7337bbd26e763cd` |
| LingBot-VLA-v2 | `951475ae1b1d87553e7dc47c97b53a3d695c0d13` |
| AMD 复现仓库（本次核对） | `27b2f6fcb6c715e2cbb6db4431381f87c94b86ed` |
| PyTorch / ROCm | 2.9.1 / 7.2.1 |
| LeRobot | 0.6.0 |
| FlashAttention2 | 2.8.4 |

> AMD 环境关闭 CuRobo，改用 **MPLib** 做末端位姿规划。闭环结果须注明
> `ROCm + MPLib + expert_check=true`，**不要**直接和 CUDA/CuRobo 结果对比。

## 1. 创建并配置实例

1. 登录 Radeon Cloud，右下角 **Switch to the new design** 切到新版界面
2. 本地没有 SSH key 先生成：`ssh-keygen -t ed25519`，
   然后在 **Settings → New SSH Key** 粘贴 `~/.ssh/id_ed25519.pub`（**只传公钥**）
3. 实例配置 **Customize**：
   - GPU：**4 GPUs** 或 **8 GPUs**
   - Image：`robotwin`
   - Resource Pool：**Dev**（本次比赛对应资源池）
   - Workspace Storage：**Persistent /workspace**
   - Mount a model：**Devzone**（不选则不会挂载 external-data 数据）
4. 启动，等待 **Your workspace is ready** → **Open Notebook** 进 JupyterLab
5. 或用 SSH 登录：
   ```bash
   ssh <user>@<host> -p <port>
   ```

**持久化空间只有 100GB**，LoRA/SFT checkpoint 可能占用数十 GB，注意清理。

## 2. 进入实例后的目录准备

```bash
# JupyterLab 默认打开 /workspace，先建软链方便浏览
ln -sfn /RoboTwin /workspace/RoboTwin

# 检查后台挂载
pwd
findmnt -T /models/robotwin-persistent
ls -l /RoboTwin/assets /RoboTwin/data \
      /RoboTwin/experiments/lingbot_vla_v2_6b_robotwin/models

# 建运行目录
mkdir -p /workspace/runtime/eval_result \
         /workspace/runtime/outputs/logs \
         /workspace/runtime/outputs/benchmarks \
         /workspace/runtime/.cache/huggingface
```

> 云端实例里**不要**再起第二层 Docker。

## 3. 环境变量（每个新 shell 都要设）

```bash
export ROBOTWIN_ROOT=/RoboTwin
export LINGBOT_VLA_SOURCE=/RoboTwin/experiments/lingbot_vla_v2_6b_robotwin/source/lingbot-vla-v2
export QWEN3VL_PATH=/RoboTwin/experiments/lingbot_vla_v2_6b_robotwin/models/Qwen3-VL-4B-Instruct-config-tokenizer
export LINGBOT_VLA_PYTHON=/opt/robotwin-env/bin/python
export HF_LEROBOT_HOME=/RoboTwin/data/lerobot
export HF_HOME=/workspace/runtime/.cache/huggingface
export ROBOTWIN_DISABLE_CUROBO=1
export ROBOTWIN_EE_PLANNER=mplib
export PYOPENGL_PLATFORM=egl
export AITER_TRITON_ONLY=1
export FLASH_ATTENTION_TRITON_AMD_ENABLE=TRUE
export SETUPTOOLS_SCM_PRETEND_VERSION=0.0.0
export PYTHONPATH=/opt/aiter${PYTHONPATH:+:${PYTHONPATH}}
```

> `scripts/cloud/env.sh` 已封装好，用 `source env.sh` 即可。
> 镜像已通过 `ENV` 持久设置 `AITER_TRITON_ONLY` 和 `FLASH_ATTENTION_TRITON_AMD_ENABLE`。

## 4. 环境自检

```bash
cd ~/challenge/scripts/cloud
bash 00_check_env.sh
```

该脚本会硬检查 3 个固定 commit、4/8 张 GPU、FlashAttention 2.8.4、50 个 clean
任务、50 行 clean 训练清单、训练清单不含 randomized，以及所有推理/训练入口。任何
`[FAIL]` 都会以非零状态退出，修复后再继续。

## 5. 启动官方模型 server + 推理验证

终端 1：
```bash
cd /RoboTwin
bash experiments/lingbot_vla_v2_6b_robotwin/scripts/launch_official_server.sh \
  0 13400 /workspace/runtime/outputs/logs/official_server.log False
```

终端 2：
```bash
cd /RoboTwin
until curl -fsS http://127.0.0.1:13400/healthz; do sleep 2; done

source /opt/robotwin-env/bin/activate
export PYTHONPATH=/RoboTwin/experiments/lingbot_vla_v2_6b_robotwin/source/lingbot-vla-v2:/RoboTwin

python experiments/lingbot_vla_v2_6b_robotwin/scripts/benchmark_official_inference.py \
  --port 13400 --repeats 3 --batch-sizes 1 2 4 \
  --output /workspace/runtime/outputs/benchmarks/official_inference.json
```
正常 action 形状 `[25, 14]`；首次请求含 warm-up，性能比较用后续请求。

## 6. 单任务闭环评测（先验证链路）

保持 server 运行，终端 2：
```bash
cd /RoboTwin
source /opt/robotwin-env/bin/activate
export ROBOTWIN_DISABLE_CUROBO=1 ROBOTWIN_EE_PLANNER=mplib PYOPENGL_PLATFORM=egl

python scripts/eval_policy_xpolicylab.py \
  --task_name adjust_bottle --task_config demo_clean \
  --policy_name LingBot-VLA-v2 --protocol lingbot_vla_v2 \
  --host 127.0.0.1 --port 13400 --device_id 0 --seed 0 \
  --test_num 10 --expert_check true --accept_expert_info_on_failure true \
  --eval_batch false --additional_info eval_video_log=false
```
首次可临时 `--test_num 1` 确认渲染/MPLib/WebSocket 正常。结果写入 `/workspace/runtime/eval_result`。

## 7. 全量闭环 Benchmark（4 / 8 卡）

> **一条命令跑 100 task × 10 episode（clean + randomized）**，会自行启动 4/8 个模型服务。
> 运行前确认端口 `13400~13403`（4 卡）或 `13400~13407`（8 卡）空闲。

四卡（约 18h56m）：
```bash
cd /RoboTwin && source /opt/robotwin-env/bin/activate
python experiments/lingbot_vla_v2_6b_robotwin/scripts/run_clean_benchmark.py \
  --gpu-count 4 --episodes 10 --expert-check --accept-expert-info-on-failure \
  --no-video --run-name both100x10_4gpu --runtime-dir /workspace/runtime --resume
```

八卡（约 15h12m）：把 `--gpu-count 8`、`--run-name both100x10_8gpu`。
- 支持 `--resume` 跳过 `done/<task_config>__<task>.done` 已完成任务
- 全部完成后检查日志里的 `Final success rate`

| 机器 | 配置 | 任务/回合 | 墙钟时间 |
|---|---|---:|---:|
| 4× W7900 | clean | 50/500 | 8h26m |
| 4× W7900 | randomized | 50/500 | 10h29m |
| 4× W7900 | **合计** | 100/1000 | **18h56m** |
| 8× W7900 | clean | 50/500 | 6h34m |
| 8× W7900 | randomized | 50/500 | 8h38m |
| 8× W7900 | **合计** | 100/1000 | **15h12m** |

## 8. LoRA 训练 → 合并 → 重新评测

### 8.1 训练（示例：100 steps 冒烟；正式用 1000/5000）
```bash
cd /RoboTwin/experiments/lingbot_vla_v2_6b_robotwin/source/lingbot-vla-v2
source /opt/robotwin-env/bin/activate
mkdir -p /workspace/runtime/outputs/logs

export HIP_VISIBLE_DEVICES=0,1,2,3     # 8 卡则 0..7
unset ROCR_VISIBLE_DEVICES CUDA_VISIBLE_DEVICES

python -m torch.distributed.run --standalone --nproc-per-node=4 \
  -m tasks.vla.train_lingbotvla \
  /RoboTwin/experiments/lingbot_vla_v2_6b_robotwin/training/lingbotvla_cli.yaml \
  --train.data_parallel_shard_size 4 \
  --train.gradient_accumulation_steps 1 \
  --train.global_batch_size 4 \
  --train.max_steps 100 --train.save_steps 100 \
  --train.output_dir /workspace/runtime/outputs/lora_100steps_4gpu \
  2>&1 | tee /workspace/runtime/outputs/logs/lora_100steps_4gpu.log
```
- **不要**直接调用 PATH 里的 `torchrun`（可能绑错 Python）
- `HIP_VISIBLE_DEVICES` 数量必须等于 `--nproc-per-node`
- LoRA 若用 8 卡：`data_parallel_shard_size 8`、`global_batch_size 8`、`nproc-per-node 8`
- 封装脚本支持第三个参数传入派生配置：
  `bash 30_train_lora.sh 1000 8 ~/challenge/configs/lora_1000_8gpu.yaml`

### 8.2 合并 LoRA 并重新推理
```bash
cd /RoboTwin && source /opt/robotwin-env/bin/activate
MERGED=/workspace/runtime/outputs/lora_100steps_8gpu/merged_checkpoint/global_step_100/hf_ckpt

python experiments/lingbot_vla_v2_6b_robotwin/scripts/merge_lora_dcp.py \
  --checkpoint /workspace/runtime/outputs/lora_100steps_8gpu/checkpoints/global_step_100 \
  --training-output /workspace/runtime/outputs/lora_100steps_8gpu \
  --base-model /RoboTwin/experiments/lingbot_vla_v2_6b_robotwin/models/robbyant_lingbot-vla-v2-6b \
  --output "$MERGED" --rank 8 --alpha 16

bash experiments/lingbot_vla_v2_6b_robotwin/scripts/launch_official_server.sh \
  0 13400 /workspace/runtime/outputs/logs/merged_server.log False "$MERGED"
```
然后按第 6 节单任务验证，或用 `run_clean_benchmark.py --model-path "$MERGED"` 跑全量。

## 9. 全参数 SFT（可选，更强但更贵）

```bash
cd /RoboTwin
TEACHER_MODE=full GPU_COUNT=8 OPTIMIZER=adamw \
MICRO_BATCH_SIZE=16 GLOBAL_BATCH_SIZE=256 \
TIMEOUT_SECONDS=0 MAX_STEPS=10 SAVE_STEPS=10 \
OUTPUT_DIR=/workspace/runtime/outputs/full_sft_full_8gpu_10steps \
bash experiments/lingbot_vla_v2_6b_robotwin/training/train_full_sft.sh
```

| GPU 数 | data_parallel_shard_size | micro_batch | grad_accum | global_batch |
|---:|---:|---:|---:|---:|
| 8（默认） | 8 | 16 | 2 | 256 |
| 4 | 4 | 16 | 4 | 256 |

- 正式训练 `TIMEOUT_SECONDS=0`
- 完整 teacher（LingBot-Depth + DINO-VIDEO）需要额外下载 `moge-2-vitb-normal/model.pt`
- 转换 checkpoint 后（部署 patch 会过滤训练专用 head）再推理评测
- 详见 `Reproduce_Guide.md` 第 8 节

## 10. 输出与持久化

- 评测结果 → `/workspace/runtime/eval_result`
- 训练 checkpoint / 日志 → `/workspace/runtime/outputs`
- **只有 `/workspace` 持久**；实例根盘内容销毁即丢
- 销毁实例前，务必把要保留的结果复制到 `/workspace`，再拉回本地（`scripts/local/sync_down.ps1`）
