# CUDA 4090 调试实例初始化

## 元信息

- 日期：2026-09-28
- 负责人：Codex
- 实验 ID / 名称：`cuda4090_bootstrap`
- 云端实例：NVIDIA GeForce RTX 4090 48GB × 1；仅作 CUDA 调试和小规模验证

## 目标（一句话）

在通用 Ubuntu CUDA 实例上固定上游版本，跑通 LingBot-VLA 环境、clean 数据转换、基础权重加载和关键 GPU 算子，为后续 1–10 步训练烟测做准备。

## 配置

- 路线：无训练（环境与数据链验证）
- 起点 checkpoint：`robbyant/lingbot-vla-v2-6b` 官方基础 checkpoint
- GPU / 驱动：RTX 4090 48GB；NVIDIA 驱动 610.57.04
- Python / PyTorch：Python 3.12；PyTorch 2.8.0+cu128
- FlashAttention：2.8.3，使用官方匹配的 cp312 / torch2.8 / CUDA 12 wheel
- 数据：仅 `demo_clean.click_bell.aloha_agilex`；下载 50 episodes，转换其中 2 episodes 作烟测
- 上游提交：
  - LingBot-VLA：`951475ae1b1d87553e7dc47c97b53a3d695c0d13`
  - RoboTwin：`266f3aadf505a4f7fe9af0faa41a20f5f47cd123`
  - XPolicyLab：`c37109c500be67d0dea6b36bf7337bbd26e763cd`
- 对上游的补丁：无

## 云端布局

代码放在持久盘，模型、数据和输出放在实例本地高速盘：

```text
/home/featurize/work/projects/
├── LingBot-VLA-Challenge/
├── lingbot-vla-v2/
└── RoboTwin/

/home/featurize/runtime/
├── cache/huggingface/
├── data/robotwin/
├── data/lerobot/
├── models/robbyant_lingbot-vla-v2-6b/
├── models/Qwen3-VL-4B-Instruct-config-tokenizer/
└── outputs/
```

## 验收结果

| 检查 | 结果 |
|---|---|
| PyTorch CUDA 矩阵运算 | 通过，GPU 为 RTX 4090 |
| FlashAttention CUDA 内核 | 通过，输出形状 `(2, 128, 8, 64)` 且全为有限值 |
| 训练 CLI 参数解析 | 通过，`train_lingbotvla.py --help` 返回 0 |
| clean 原始数据下载与规范化 | 通过，50 个 HDF5 episode、152 个文件 |
| LeRobot v2.1 转换 | 通过，烟测数据含 2 episodes / 155 frames |
| LeRobot 视频解码 | 通过，四路相机均为 `(3, 240, 320)` |
| 官方基础权重严格加载 | 通过，6,375,906,359 参数，BF16 显存约 12.84GB |
| fused MoE CUDA 前向 | 通过，输出 `(1, 8, 768)` 且全为有限值 |

## 观察与结论

- 不需要在创建实例时预装“PyTorch 2”；基础镜像自带的 PyTorch 2.2.2 不符合上游锁定版本，最终按官方脚本建立独立 `lingbotvla` 环境。
- 官方环境脚本安装 MoGe 后会把 `numpy` 升到 2.2.6，并把 `huggingface-hub` 留在 0.34.0；已恢复为项目锁定的 `numpy==1.26.4` 和 `huggingface-hub==0.34.3`。
- LeRobot 视频读取还需要系统 FFmpeg 共享库；安装 Ubuntu `ffmpeg` 后，TorchCodec 可以读取样本。
- 官方基础 checkpoint 必须按 `moe_implementation=fused` 加载；切到 eager 会因 checkpoint 的 fused expert 权重命名不同而严格加载失败。
- 这台机器适合数据链、模型加载、CUDA 算子和短训练烟测。正式多卡训练及全量评测仍使用 AMD Radeon Cloud。
- SSH 密码没有写入仓库或实例配置文件。

## 下一步

1. 产出 `configs/lora_1000_8gpu.yaml` 和 `configs/sft_full_8gpu.yaml`，完成 HANDOFF T2。
2. 在 AMD 官方镜像到位后运行 `scripts/cloud/00_check_env.sh`，再做 baseline 单任务闭环。
3. 如需在本实例继续，先为当前上游训练入口接入 LoRA，再运行 1–10 步 clean 数据烟测；不在本实例做全参数正式训练。

## 相关链接

- 上游 LingBot-VLA：<https://github.com/Robbyant/lingbot-vla-v2>
- 上游 RoboTwin：<https://github.com/RoboTwin-Platform/RoboTwin>

