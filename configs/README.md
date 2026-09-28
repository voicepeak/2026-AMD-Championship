# configs —— 我们的训练/评测配置

原则：**不直接改上游仓库的配置**，把改动以"派生配置"形式放这里，便于追踪和回滚。

## 上游配置位置（云端）

| 用途 | 路径 |
|---|---|
| 赛事训练 CLI 配置 | `/RoboTwin/experiments/lingbot_vla_v2_6b_robotwin/training/lingbotvla_cli.yaml` |
| 全参数 SFT 脚本 | `/RoboTwin/experiments/lingbot_vla_v2_6b_robotwin/training/train_full_sft.sh` |
| RoboTwin feature mapping | 上游 `configs/robot_configs/robotwin.yaml` |
| 归一化统计 | 上游 `assets/norm_stats/robotwin.json` |
| 官方后训练示例 | 上游 `configs/vla/robotwin/*.yaml`（Muon / dist_muon） |

## 命名约定

- `lora_<steps>_<gpu>.yaml` —— LoRA 实验配置
- `sft_<variant>_<gpu>.yaml` —— 全参数 SFT 配置
- 每个配置文件顶部写上：目的、相对上游的改动、对应 experiment 记录

## 用法

配置文件通过 `--train.xxx` 覆盖或直接替换路径传入，例如：

```bash
bash 30_train_lora.sh 1000 8
# 或手动指定自定义配置：
# python -m torch.distributed.run ... -m tasks.vla.train_lingbotvla /path/to/my_config.yaml
```

> 具体参数含义见官方 `configs/vla/Training_Config.md`。
