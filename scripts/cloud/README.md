# scripts/cloud —— 在 Radeon Cloud 实例里运行

上传到云端（如 `~/challenge/scripts/cloud`）后使用。所有脚本会自动 `source env.sh`。

## 使用顺序

```bash
cd scripts/cloud
bash 00_check_env.sh                        # 1. 环境自检，全绿再继续

# 终端 1：启动模型 server（保持前台运行）
bash 10_launch_server.sh 0 13400

# 终端 2：
until curl -fsS http://127.0.0.1:13400/healthz; do sleep 2; done
bash 20_eval_single.sh adjust_bottle demo_clean 1     # 2. 先用 1 个 episode 验链路
bash 20_eval_single.sh adjust_bottle demo_clean 10    #    OK 后跑 10 个

# 3. 训练（会占满 GPU，先停掉 server）
bash 30_train_lora.sh 100 8                 # 冒烟
bash 30_train_lora.sh 1000 8                # 正式（上游配置）
# T2 配置生成后：bash 30_train_lora.sh 1000 8 ~/challenge/configs/lora_1000_8gpu.yaml
bash 31_merge_lora.sh 1000 8                # 合并 LoRA

# 4. 全量评测（约 15h/8卡，19h/4卡）
bash 40_benchmark_full.sh 8 both100x10_lora_1000 "/workspace/runtime/outputs/lora_1000steps_8gpu/merged_checkpoint/global_step_1000/hf_ckpt"
```

## 脚本一览

| 脚本 | 作用 |
|---|---|
| `env.sh` | 环境变量（source 用） |
| `00_check_env.sh` | GPU / 挂载 / 版本 / 数据 / 磁盘 自检 |
| `10_launch_server.sh` | 启动官方或指定 checkpoint 的模型 server |
| `20_eval_single.sh` | 单任务闭环评测（验链路） |
| `30_train_lora.sh` | LoRA 训练 |
| `31_merge_lora.sh` | 合并 LoRA checkpoint |
| `40_benchmark_full.sh` | 全量 100 task × 10 ep benchmark |

## 覆盖默认值

脚本支持用环境变量覆盖：

```bash
PORT=13402 bash 10_launch_server.sh 0 13402
EPISODES=5 bash 40_benchmark_full.sh 8 debug_run
```

## 注意

- 这些脚本是官方流程的**封装**，实际逻辑仍在镜像内的
  `experiments/lingbot_vla_v2_6b_robotwin/scripts/` 下。上游升级后请核对参数。
- 训练/评测输出一律落 `/workspace/runtime/...`，销毁实例前记得拉回本地。
