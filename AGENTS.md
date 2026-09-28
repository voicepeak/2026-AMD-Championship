# AGENTS.md — 给 AI 编码助手的项目说明

本仓库是「蚂蚁灵波具身大模型挑战赛」的参赛工作区。

## 背景速览

- 赛题：基于 **LingBot-VLA 2.0 (6B)** 在 **RoboTwin 2.0 仿真**上做后训练/调优
- 计算在 **AMD Radeon Cloud**（W7900D 48GB × 4/8，ROCm 7.2.1 + PyTorch 2.9.1）上执行
- 最终评测指标：RoboTwin 50 个任务在 `demo_clean` 和 `demo_randomized` 下的成功率
- 本地（Windows）只用于编辑、Git 管理、收结果；**不要**在本地跑训练

## 目录约定

| 目录 | 用途 |
|---|---|
| `docs/` | 比赛信息、排期、算力申请、云端操作手册、已知坑 |
| `configs/` | 我们派生的训练/评测 YAML（不直接改上游） |
| `patches/` | 对上游仓库（RoboTwin / lingbot-vla-v2 / XPolicyLab）的补丁 |
| `experiments/` | 每次实验一份 `YYYY-MM-DD_<name>.md`，从 `_TEMPLATE.md` 复制 |
| `results/` | 从云端拉回的成功率 JSON/日志摘要（仅小文件） |
| `scripts/cloud/` | **在云端 bash 里运行**的脚本（入口 `env.sh` 提供变量） |
| `scripts/local/` | 本地 PowerShell 辅助脚本（同步、打包） |

## 硬性规则

1. 训练只允许用 clean 数据；不得用 randomized 数据训练
2. 必须从官方基础 checkpoint 起步
3. 不要把大文件（权重、数据集、checkpoint、zip）提交进 Git —— 见 `.gitignore`
4. 云端脚本一律写输出到 `/workspace/runtime/...`，不要写到根盘

## 云端常用变量（scripts/cloud/env.sh 已定义）

- `ROBOTWIN_ROOT=/RoboTwin`
- `LINGBOT_RUNTIME=/workspace/runtime`
- `PORT=13400`
- 必需环境变量：`AITER_TRITON_ONLY=1`、`FLASH_ATTENTION_TRITON_AMD_ENABLE=TRUE`、
  `ROBOTWIN_DISABLE_CUROBO=1`、`ROBOTWIN_EE_PLANNER=mplib`、`PYOPENGL_PLATFORM=egl`

## 参考

- 官方仓库：`github.com/Robbyant/lingbot-vla-v2`
- AMD 复现指南：`github.com/ZiguanWang/Robotwin-radeon-cloud`（`Reproduce_Guide.md`）
- 详细云端流程见 `docs/04-cloud-runbook.md`
