# 09 · 4090 / CUDA 调试环境搭建

> 用途：在**自租的 NVIDIA 4090（24/48G）**上提前跑通代码/数据/推理链路，不等 AMD 排队。
> **不做主力训练**（显存与多卡限制）；正式训练与全量评测仍在 AMD Radeon Cloud。
> 来源：`experiments/2026-09-28_cuda4090_bootstrap.md` 的实操记录。
> 前置：实例已能 SSH；已装 conda；有 GitHub/HuggingFace 访问。

## 0. 角色定位

| 能在这台机做 | 不建议/做不了 |
|---|---|
| 环境搭建、模型加载、算子验证 | 全参数 SFT（显存不够） |
| 数据下载与 LeRobot 转换 | 全量评测（单卡要几天） |
| 1–10 步 LoRA 训练冒烟 | 主力 LoRA 正式训练 |
| 少量任务闭环验证 | — |

> 好消息：模型 bf16 只需 **约 13.6GB** 显存，48G 绰绰有余；权重可跨环境迁移到 AMD。

## 1. 固定版本

| 组件 | 版本 |
|---|---|
| Python | 3.12 |
| PyTorch | 2.8.0+cu128 |
| FlashAttention | 2.8.3（cp312 / torch2.8 / cu12 wheel） |
| LingBot-VLA-v2 | `951475ae1b1d87553e7dc47c97b53a3d695c0d13` |
| RoboTwin | `266f3aadf505a4f7fe9af0faa41a20f5f47cd123` |
| XPolicyLab | `c37109c500be67d0dea6b36bf7337bbd26e763cd` |

## 2. 目录布局（示例）

```
<work>/projects/
├── LingBot-VLA-Challenge/     # 本仓库
├── lingbot-vla-v2/            # 上游模型代码
└── RoboTwin/                  # 仿真评测代码

<runtime>/
├── cache/huggingface/
├── data/robotwin/             # 原始 demo_clean
├── data/lerobot/              # 转换后的 LeRobot 数据
├── models/robbyant_lingbot-vla-v2-6b/
├── models/Qwen3-VL-4B-Instruct-config-tokenizer/
└── outputs/
```

## 3. 步骤

### 3.1 克隆并固定上游版本
```bash
git clone https://github.com/Robbyant/lingbot-vla-v2.git
git -C lingbot-vla-v2 fetch origin 951475ae1b1d87553e7dc47c97b53a3d695c0d13
git -C lingbot-vla-v2 checkout 951475ae1b1d87553e7dc47c97b53a3d695c0d13

git clone https://github.com/RoboTwin-Platform/RoboTwin.git
git -C RoboTwin fetch origin 266f3aadf505a4f7fe9af0faa41a20f5f47cd123 --depth=1
git -C RoboTwin checkout --detach 266f3aadf505a4f7fe9af0faa41a20f5f47cd123
git -C RoboTwin submodule update --init --recursive XPolicyLab
```

### 3.2 建 conda 环境（官方脚本 + 预编译 flash-attn）
```bash
# 下载 cp312 / torch2.8 / cu12 的 flash-attn wheel，并校验
WHEEL=flash_attn-2.8.3+cu12torch2.8cxx11abiTRUE-cp312-cp312-linux_x86_64.whl
curl -fL --retry 3 -o "$WHEEL" \
  'https://github.com/Dao-AILab/flash-attention/releases/download/v2.8.3/flash_attn-2.8.3%2Bcu12torch2.8cxx11abiTRUE-cp312-cp312-linux_x86_64.whl'
sha256sum -c <<< "f25da18657a87fc83dc1bfb8b7751b82246e9db355510226b674fd437c34b5fb  $WHEEL"

cd lingbot-vla-v2
bash tools/create_train_env.sh --env-name lingbotvla --flash-attn-wheel "$WHEEL"
```

### 3.3 修正被覆盖的依赖版本
```bash
PY=<conda env lingbotvla>/bin/python
$PY -m pip install --no-deps numpy==1.26.4 huggingface-hub==0.34.3
# 官方脚本会装 MoGe 并把 numpy 升到 2.2.6 / hub 留在 0.34.0，需恢复
```

### 3.4 安装系统 ffmpeg（TorchCodec 解码视频需要）
```bash
sudo apt-get update -qq && sudo apt-get install -y ffmpeg
```

### 3.5 下载模型
```bash
export HF_HOME=<runtime>/cache/huggingface
$PY - <<'PY'
from huggingface_hub import snapshot_download
snapshot_download("robbyant/lingbot-vla-v2-6b",
                  local_dir="<runtime>/models/robbyant_lingbot-vla-v2-6b")
snapshot_download("Qwen/Qwen3-VL-4B-Instruct",
                  local_dir="<runtime>/models/Qwen3-VL-4B-Instruct-config-tokenizer",
                  allow_patterns=["*.json","*.txt","*.jinja","*.model"])
PY
```

### 3.6 下载并转换 clean 数据（先单任务冒烟）
```bash
cd RoboTwin
ln -sfn <runtime>/data/robotwin data
PATH=<env>/bin:$PATH ROBOTWIN_DATA_ROOT=<runtime>/data/robotwin \
  HF_ARCHIVE_CACHE=<runtime>/data/download_cache HF_KEEP_ARCHIVES=0 \
  bash scripts/download_xpolicylab_data.sh click_bell

HF_LEROBOT_HOME=<runtime>/data/lerobot PATH=<env>/bin:$PATH $PY \
  XPolicyLab/scripts/transform_lerobot_v21_format.py \
  'demo_clean.click_bell.aloha_agilex' --repo_id smoke_demo_clean_click_bell --max_episode 2
```

## 4. 验收检查（都应通过）

```bash
$PY - <<'PY'
import torch, flash_attn
print(torch.__version__, torch.version.cuda, torch.cuda.is_available(),
      torch.cuda.get_device_name(0))
from flash_attn import flash_attn_func
q = torch.randn((2,128,8,64), device="cuda", dtype=torch.float16)
print(tuple(flash_attn_func(q,q,q).shape))
PY
```

模型加载（关键：必须 `moe_implementation=fused`，否则严格加载失败）：
- 期望输出：`MODEL_LOAD_OK 6375906359 cuda:0 torch.bfloat16`，显存约 **12.8–13.6GB**
- fused MoE 前向：输出 `(1,8,768)` 且全为有限值

## 5. 已知坑

| 现象 | 原因/解决 |
|---|---|
| 基础镜像自带 torch 2.2.2 不符合要求 | 用官方 `create_train_env.sh` 建独立环境 |
| `ModuleNotFoundError: h5py` | `source /opt/lerobot-env`（或转换环境）后 `pip install h5py` |
| 视频读不出 | 装系统 `ffmpeg`（TorchCodec 依赖共享库） |
| `numpy`/`huggingface-hub` 被升版 | 恢复 `numpy==1.26.4`、`huggingface-hub==0.34.3` |
| 严格加载失败 | 必须 `moe_implementation: fused`，不能改 eager |
| SSH 密码泄露风险 | 用密钥登录；密码不要写进仓库或实例配置 |

## 6. 下一步

1. 数据转为全量（50 任务）后再接入正式验证子集。
2. 接 LoRA 训练入口跑 1–10 步冒烟。
3. 正式训练与全量评测移交 AMD Radeon Cloud（见 `docs/04-cloud-runbook.md`）。
