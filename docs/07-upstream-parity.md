# 07 · 上游对齐记录

> 核对日期：2026-09-28。本文是 `scripts/cloud/` 与 AMD 官方复现环境之间的验收依据。
> 训练和评测以 AMD 镜像固定版本为准；LingBot-VLA 当前 `main` 只用于识别后续变化，不能
> 直接替换镜像中的固定版本。

## 1. 核对基线

| 来源 | 本次读取的版本 | 用途 |
|---|---|---|
| `Robbyant/lingbot-vla-v2` 镜像固定版本 | `951475ae1b1d87553e7dc47c97b53a3d695c0d13` | 镜像实际安装的训练代码与 RoboTwin 配置 |
| `Robbyant/lingbot-vla-v2` 当前 `main` | `be969b8fd117fb70550c5d4bf4bc328211b5b1b6` | 检查新文档与 `dist_muon` 等后续变化 |
| `ZiguanWang/Robotwin-radeon-cloud` | `27b2f6fcb6c715e2cbb6db4431381f87c94b86ed` | AMD 镜像、复现指南和比赛脚本的直接来源 |
| RoboTwin 镜像固定版本 | `266f3aadf505a4f7fe9af0faa41a20f5f47cd123` | 仿真与评测入口 |
| XPolicyLab 镜像固定版本 | `c37109c500be67d0dea6b36bf7337bbd26e763cd` | 策略接口与 LeRobot 兼容层 |

本地只读镜像位于被 `.gitignore` 排除的 `third_party/`。AMD 仓库里的比赛脚本源码在
`docker/assets/experiments/lingbot_vla_v2_6b_robotwin/`；Dockerfile 构建时将它复制到
镜像内的 `/RoboTwin/experiments/lingbot_vla_v2_6b_robotwin/`。因此本仓库 runbook 的
云端路径是正确的，不能照搬上游 Git 仓库的源码路径。

## 2. 数据与模型配置

| 项目 | 上游实际 | 本仓库结论 |
|---|---|---|
| 训练起点 | `robbyant/lingbot-vla-v2-6b` 基础 checkpoint | 保持；不使用已训好的 `-robotwin` checkpoint 起训 |
| 训练清单 | `/RoboTwin/data/robotwin_demo_clean_joint_v30.txt`，50 行 | 只允许该 clean 清单；自检和训练脚本会拦截 randomized 字样 |
| 原始/转换数据 | `data/demo_clean` 与 `data/lerobot` 各 50 个任务 | `00_check_env.sh` 硬检查数量 |
| 状态映射 | 双臂关节切片 `[0:6)+[7:13)`；夹爪 `[6:7)+[13:14)` | 保持上游 `configs/robot_configs/robotwin.yaml` |
| 相机映射 | `cam_high`、`cam_left_wrist`、`cam_right_wrist` | 分别映射为 top、wrist_left、wrist_right |
| 归一化 | `bounds_99_woclip`，统计文件 `assets/norm_stats/robotwin.json` | 保持，不重新计算或混入 randomized 统计 |
| 损失 | RoboTwin 使用 `L1_fm` | 保持 |

AMD 的 `training/lingbotvla_cli.yaml` 是比赛镜像可直接运行的 LoRA 基线：
`use_lora=true`、`lora_scope=action_expert`、rank 8、alpha 16、目标层
`q_proj,k_proj,v_proj,o_proj`、micro batch 1、AdamW、FSDP2。四卡/八卡命令只覆盖
shard size、梯度累积、global batch、步数、保存步数和输出目录。

LingBot-VLA 当前 `configs/vla/robotwin/robotwin.yaml` 面向 32 GPU 的通用全参数训练，默认
micro batch 32、global batch 1024、Muon 和 depth/video alignment。它不是 AMD 4/8 卡
复现配置，不能原样传给比赛镜像。T2 的派生 YAML 应以 AMD 的
`training/lingbotvla_cli.yaml` 为可执行基线，再明确记录相对改动。

## 3. 云端脚本逐项对照

| 本仓库入口 | 上游实际接口 | 原问题 | 本次修正 |
|---|---|---|---|
| `env.sh` | Dockerfile 固定 `HF_HOME`、ROCm/Triton、MPLib 等变量 | 本地封装缺 `HF_HOME` 与 setuptools-scm 兜底 | 补齐并继续将缓存写入 `/workspace/runtime` |
| `00_check_env.sh` | 镜像固定 3 个源码 commit、FA2 2.8.4、4/8 GPU、50 任务 | 原脚本只打印异常且总是成功退出 | 改为 PASS/FAIL 硬检查；失败退出 1；验证 clean-only 与全部入口 |
| `10_launch_server.sh` | `launch_official_server.sh HIP_ID PORT LOG_FILE [USE_COMPILE] [MODEL_PATH]` | 缺参数、checkpoint 与配置存在性检查 | 校验 GPU/端口/路径；按上游第 5 参数传模型 |
| `20_eval_single.sh` | `eval_policy_xpolicylab.py` 接受 task/config/port/test_num 等参数 | 不先检查 server，可能启动仿真后才失败 | 增加健康检查、参数检查并固定使用模型环境 Python |
| `30_train_lora.sh` | `python -m torch.distributed.run ... -m tasks.vla.train_lingbotvla CONFIG` | 任意 GPU 数会错误映射成四卡；不能引用 T2 配置 | 只接受 4/8 卡；第三参数可传 YAML；拒绝含 randomized 的配置 |
| `31_merge_lora.sh` | `merge_lora_dcp.py` 要求 checkpoint、training-output、base-model、output、rank、alpha | 缺输入/输出保护；自定义 run name 无法衔接 | 补路径检查、输出冲突检查并支持同一 `RUN_NAME` |
| `40_benchmark_full.sh` | `run_clean_benchmark.py` 默认/显式 `--task-config both`，支持 4/8 卡 | 未显式声明 both；端口冲突可能误连旧 server | 显式跑 clean+randomized；检查 4/8 卡、模型配置和端口占用 |
| 全参数 SFT | `training/train_full_sft.sh` 通过环境变量配置 | runbook 参数与上游一致 | 保持；T2 再生成可审阅的派生 YAML/调用方式 |

全量脚本会跑 `demo_clean` 和 `demo_randomized` 两组各 50 个任务。完成标记真实名称为
`done/<task_config>__<task>.done`；原 runbook 写成 `done/<task>.done`，本次已纠正。

## 4. 参数与路径结论

| 检查项 | 我们的最终写法 | 上游证据 |
|---|---|---|
| 模型服务日志 | `/workspace/runtime/outputs/logs/*.log` | server 第 3 参数是日志文件 |
| 单任务入口 | `/RoboTwin/scripts/eval_policy_xpolicylab.py` | AMD patch 与复现指南第 6 节 |
| LoRA 配置 | `/RoboTwin/experiments/.../training/lingbotvla_cli.yaml` 或上传的派生 YAML | 复现指南第 7.1 节 |
| LoRA DCP | `<output>/checkpoints/global_step_<N>` | `merge_lora_dcp.py --checkpoint` |
| 合并模型 | `<output>/merged_checkpoint/global_step_<N>/hf_ckpt` | 复现指南第 7.2 节 |
| 全量评测输出 | `/workspace/runtime/outputs/<run-name>/` | `run_clean_benchmark.py` 的 `run_dir` |
| 全参转换 | `convert_full_sft_dcp.py`，不是 LoRA merge | 复现指南第 8.4 节 |

## 5. 验收证据与剩余验证

- `scripts/cloud/*.sh` 共 7 个文件已使用 Git Bash 执行 `bash -n`，全部通过。
- 所有脚本仍只把缓存、日志、checkpoint 和评测结果写入 `/workspace/runtime/...`。
- `.gitignore` 已排除 `third_party/`，不会把上游镜像或大文件提交进仓库。
- 本地 Windows 没有 ROCm、RoboTwin 数据和比赛镜像，因此不能完成运行时验收。实例到手后
  第一条命令必须是 `bash 00_check_env.sh`；只有它零退出后才运行单任务评测。

T1 到此完成。T2 需要从 AMD 可执行 LoRA 配置派生
`configs/lora_1000_8gpu.yaml`，并为 full SFT 明确 teacher 路径、batch 关系和输出路径。
