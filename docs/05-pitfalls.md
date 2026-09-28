# 05 · 已知坑与排查

> 来源：AMD 官方复现指南 FAQ + 实际环境注意事项。

## 环境 / 依赖

### `ModuleNotFoundError: h5py`
用的是缺少数据转换依赖的旧环境。完整镜像已包含该依赖，若仍报错：
```bash
source /opt/lerobot-env/bin/activate
python -m pip install h5py==3.14.0
```

### 找不到 `assets/norm_stats/robotwin.json`
`robotwin.yaml` 的相对路径是相对 **LingBot-VLA 仓库根目录**解析的。
先进入源码目录再启动训练（新版补丁已修复，但旧镜像仍需注意）：
```bash
cd /RoboTwin/experiments/lingbot_vla_v2_6b_robotwin/source/lingbot-vla-v2
```

### PyTorch 看不到 AMD GPU
```bash
ls -l /dev/kfd /dev/dri
python -c 'import torch; print(torch.__version__, torch.version.hip, torch.cuda.is_available())'
```
确认容器启动传入了 `/dev/kfd`、`/dev/dri`，且没有装 CUDA/PyPI 版 torch 覆盖 ROCm 版。

### 训练进程用错了 Python
**不要**直接调用 `torchrun`。激活环境后用：
```bash
python -m torch.distributed.run --standalone --nproc-per-node=4 ...
```

## 渲染（可忽略）

### SAPIEN / svulkan2 日志
启动时若出现：
```
[svulkan2] [error] CUDA Error: cudaErrorInsufficientDriver
[svulkan2] [error] Failed to initialize denoiser
```
这是 svulkan2 尝试初始化**可选**的 NVIDIA CUDA 去噪器，**不代表 ROCm 评测失败**。
当前镜像补丁已在创建任何 SAPIEN engine/scene/renderer 之前关闭该去噪器。

若仍无法创建 renderer：
```bash
export PYOPENGL_PLATFORM=egl
vulkaninfo --summary
```
确认 `/dev/dri` 已传入，且装了 `libvulkan1`、`mesa-vulkan-drivers`。

## 训练 / 评测

### attention 实现的三种名字（容易混淆）
- `model.attn_implementation: flash_attention_2` → HuggingFace/Qwen 模型
- `model.vit_attn_implementation: flash_attention_2` → 视觉编码器
- `train.attention_implementation: flex_cached` → VLM + action expert 联合注意力
  （用自定义二维 block mask，**不能**设成 `flash_attention_2`，否则报
  `Invalid attention implementation`）

### batch size 公式
```
global_batch_size = micro_batch_size × data_parallel_size × gradient_accumulation_steps
```

### 端口冲突
全量 benchmark 会自行占用 `13400~13403`（4 卡）或 `13400~13407`（8 卡）。
启动前确认没有被其它 server 占用。

### 评测要不要录视频
- 单 episode：`--additional_info eval_video_log=false`（关）/ `true`（开）
- 长 benchmark：`--no-video`（关）/ `--video`（开）
- 注意：只删 `--no-video` **不会**开录，脚本默认仍是不录

### checkpoint 没有持久化
要跨实例保留，训练 `output_dir` 必须在 `/workspace/runtime/outputs` 下；
本地容器需把宿主目录挂到 `/workspace/runtime`。

## 平台 / 磁盘

- 云端实例里**不要**再启动第二层 Docker
- Radeon Cloud 持久化 `/workspace` **只有 100GB**，LoRA/SFT checkpoint 可能数十 GB
  ```bash
  df -h / /workspace
  du -d1 -h /workspace/runtime/outputs
  ```
- 旧的 LoRA 结果和中间输出及时清理
- 中间缓存可放根盘临时目录，但根盘**不持久**，最终结果必须落 `/workspace`

## 合规（会取消资格）

- 训练只用**指定 clean 数据**，禁止用 randomized 数据训练
- 必须从官方基础 checkpoint 起步，不得从已训好的 robotwin checkpoint 开始
- 禁止伪造评测结果、多账号刷分、抄袭
