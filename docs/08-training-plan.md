# 08 · 训练方案

> 目标：在 RoboTwin 2.0 上把 LingBot-VLA 2.0（6B）从官方基础 checkpoint 后训练到尽量高的成功率，
> 并在 **10/26 24:00** 前交出一个可复现的结果。
> 关联：`docs/02-timeline.md`（排期）、`configs/`（配置）、`data/manifests/`（验证子集）。

## 1. 结论（推荐策略）

**先 LoRA 保底，再全参数 SFT 冲分**（两步走，不是二选一）：

```
第 1 步（保底）  LoRA 打通全链路 → 拿到可提交结果 → 锁死底线
第 2 步（冲分）  在保底之上做全参数 SFT → 更好就替换，卡住就放弃
```

理由：截止日期紧、一次全量评测就要 15–19 小时，迭代窗口窄。先用低风险方案确保"有东西可交"，再争取更高分。

## 2. 两条路线对比

| 维度 | LoRA | 全参数 SFT |
|---|---|---|
| 训练参数 | 仅 action_expert 的 q/k/v/o_proj 适配器 | 全部 6B |
| 显存/成本 | 低 | 高（需 FSDP2 分片） |
| 效果上限 | 中（适配为主） | 高（真正吸收数据分布） |
| depth/video teacher | 不启用 | 默认启用，效果更好 |
| 稳定性 | 稳 | 需调参，可能不稳 |
| 产物 | 小适配器，需 merge（`merge_lora_dcp.py`） | 同尺寸 ckpt，需转换（`convert_full_sft_dcp.py`） |

## 3. 具体配置（已生成）

### 3.1 LoRA（[`configs/lora_1000_8gpu.yaml`](../configs/lora_1000_8gpu.yaml)）
- `use_lora=true`, `lora_scope=action_expert`, `lora_rank=8`, `lora_alpha=16`
- `lora_target_modules=q_proj,k_proj,v_proj,o_proj`
- `micro_batch_size=1`, 8 卡 `data_parallel_shard_size=8`, `gradient_accumulation_steps=1` → `global_batch=8`
- `optimizer=adamw`, `lr=1e-4`, `max_steps=1000`, `save_steps=1000`
- 依据：AMD 官方镜像的 `lingbotvla_cli.yaml`（即官方 LoRA 基线）

运行：
```bash
bash scripts/cloud/30_train_lora.sh 1000 8 configs/lora_1000_8gpu.yaml
bash scripts/cloud/31_merge_lora.sh 1000 8
```

### 3.2 全参数 SFT（[`configs/sft_full_8gpu.yaml`](../configs/sft_full_8gpu.yaml)）
- `use_lora=false`, 启用完整 depth + video teacher（`align_params`）
- `micro_batch_size=16`, `global_batch_size=256`, `data_parallel_shard_size=8`, `gradient_accumulation_steps=2`
- 4 卡时：`shard=4`, `gradient_accumulation_steps=4`（`16*4*4=256`）
- `optimizer=adamw`（也可试 Muon，收敛更好但更慢）

运行（官方脚本会自行拼装 `align_params`）：
```bash
TEACHER_MODE=full GPU_COUNT=8 OPTIMIZER=adamw MICRO_BATCH_SIZE=16 \
GLOBAL_BATCH_SIZE=256 TIMEOUT_SECONDS=0 MAX_STEPS=5000 SAVE_STEPS=5000 \
OUTPUT_DIR=/workspace/runtime/outputs/sft_full_8gpu \
bash experiments/lingbot_vla_v2_6b_robotwin/training/train_full_sft.sh
```

## 4. 执行排期

| 阶段 | 事项 | 产出 | 目标日 |
|---|---|---|---|
| A | 环境自检 + baseline 单任务闭环 | 成功率基线 | D+5 |
| B | LoRA 冒烟（100 步）→ 合并 → 小规模验证 | 链路通 | D+7 |
| C | LoRA 正式训练（1000–5000 步）+ 10 任务验证 | 保底模型 | D+13 |
| D | 保底模型**全量评测**（预留 16–19h） | clean/randomized 成功率 | D+17 |
| E | 全参数 SFT（在 D 的同时或之后） | 冲分模型 | D+20 |
| F | 最优模型确定 + 全量复测 | 最终结果 | D+24 |
| G | 提交 + 备份 | 提交完成 | **10/26** |

> 全量评测很贵，**只在关键节点跑**。日常迭代用验证子集（`data/manifests/robotwin_tasks.md`）。

## 5. 验证子集策略

- 日常选点：跑 3–5 个任务（如 `adjust_bottle`+`click_bell`+`lift_pot`），快速看趋势
- 阶段确认：跑 10 任务子集
- 定稿：跑全量 50 clean + 50 randomized × 10 episodes
- 记录：每次实验按 `experiments/_TEMPLATE.md` 记录，结果存 `results/<run-name>/`

## 6. 决策规则（何时切换/放弃）

| 情况 | 动作 |
|---|---|
| LoRA 全量分明显偏低，且剩余 ≥10 天、算力充足 | 上全参数 SFT |
| 到 D+20 仍没有超过 LoRA 的 SFT 结果 | **放弃 SFT，锁定 LoRA 版本** |
| 算力排队/实例不稳，时间不足 | 只做 LoRA，优先保证提交 |
| 训练出现 OOM/不收敛 | 降 micro batch、开梯度检查点、换 AdamW |

**原则：保底 > 完美。任何时刻都要有一个"能提交"的版本。**

## 7. 风险与回退

| 风险 | 回退 |
|---|---|
| 训练 OOM | 降 `micro_batch_size`、开 `enable_gradient_checkpointing` |
| 收敛差 | 换优化器（AdamW↔Muon）、调 lr、加步数 |
| 合并/转换失败 | 保留 DCP 中间产物，按 `docs/05-pitfalls.md` 排查 |
| 时间不够 | 缩小验证子集，直接锁 LoRA 提交 |

## 8. 合规红线

- 训练**只用 `demo_clean`**，禁止 randomized
- 从**官方基础 checkpoint** 起步，不得从已训好的 `-robotwin` checkpoint 起训
- 提交物保证原创合规
