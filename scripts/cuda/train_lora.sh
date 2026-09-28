#!/usr/bin/env bash
# CUDA / 4090 侧：LoRA 全量训练（支持 1 / 4 / 8 卡）
#
# 复用仓库里的派生配置 configs/lora_1000_8gpu.yaml，用 CLI 覆盖：
#   - 路径（模型 / tokenizer / norm_stats / robot_configs / 数据清单）
#   - 并行（shard = GPU 数；micro=1；global=8，故 grad_accum = 8/GPU数）
#   - 步数 / 保存 / 输出目录
#
# 用法：
#   NGPU=1 STEPS=3000 SAVE=500 bash train_lora.sh
#   NGPU=4 STEPS=3000 SAVE=500 bash train_lora.sh
set -Eeuo pipefail

RUNTIME="${RUNTIME:-/home/featurize/runtime}"
REPO="${REPO:-/home/featurize/work/projects/LingBot-VLA-Challenge}"
LINGBOT_VLA_SOURCE="${LINGBOT_VLA_SOURCE:-/home/featurize/work/projects/lingbot-vla-v2}"
LINGBOT_PY="${LINGBOT_PY:-/environment/miniconda3/envs/lingbotvla/bin/python}"
MODEL="${MODEL:-${RUNTIME}/models/robbyant_lingbot-vla-v2-6b}"
TOKENIZER="${TOKENIZER:-${RUNTIME}/models/Qwen3-VL-4B-Instruct-config-tokenizer}"
MANIFEST="${MANIFEST:-${RUNTIME}/data/robotwin_demo_clean_joint_v21.txt}"
CONFIG="${CONFIG:-${REPO}/configs/lora_1000_8gpu.yaml}"

NGPU="${NGPU:-1}"
STEPS="${STEPS:-3000}"
SAVE="${SAVE:-500}"
GLOBAL_BATCH="${GLOBAL_BATCH:-8}"
MICRO="${MICRO:-1}"
WORKERS="${WORKERS:-4}"
PREFETCH="${PREFETCH:-4}"
RUN_NAME="${RUN_NAME:-lora_full_${NGPU}gpu}"
OUT="${RUNTIME}/outputs/${RUN_NAME}"
LOG="${RUNTIME}/outputs/logs/${RUN_NAME}.log"

case "$NGPU" in
  1) export CUDA_VISIBLE_DEVICES=0 ;;
  4) export CUDA_VISIBLE_DEVICES=0,1,2,3 ;;
  8) export CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7 ;;
  *) echo "NGPU 只支持 1/4/8，收到 $NGPU" >&2; exit 2 ;;
esac
unset HIP_VISIBLE_DEVICES || true

if (( GLOBAL_BATCH % (MICRO * NGPU) != 0 )); then
  echo "GLOBAL_BATCH($GLOBAL_BATCH) 必须能被 MICRO($MICRO)*NGPU($NGPU) 整除" >&2; exit 2
fi
ACCUM=$(( GLOBAL_BATCH / (MICRO * NGPU) ))

for f in "$CONFIG" "$MANIFEST" "$MODEL/model.safetensors.index.json"; do
  [[ -e "$f" ]] || { echo "缺少: $f" >&2; exit 2; }
done

mkdir -p "$OUT" "$(dirname "$LOG")"
export PYTHONUNBUFFERED=1

cd "$LINGBOT_VLA_SOURCE"
echo "[lora] gpus=$NGPU steps=$STEPS save=$SAVE micro=$MICRO accum=$ACCUM global=$GLOBAL_BATCH workers=$WORKERS"
echo "[lora] out=$OUT"

"$LINGBOT_PY" -m torch.distributed.run \
  --standalone \
  --nproc-per-node="$NGPU" \
  -m tasks.vla.train_lingbotvla \
  "$CONFIG" \
  --model.model_path "$MODEL" \
  --model.config_path "$MODEL" \
  --model.tokenizer_path "$TOKENIZER" \
  --data.norm_stats_file "${LINGBOT_VLA_SOURCE}/assets/norm_stats/robotwin.json" \
  --data.robot_config_root "${LINGBOT_VLA_SOURCE}/configs/robot_configs" \
  --data.train_path "$MANIFEST" \
  --data.num_workers "$WORKERS" \
  --data.prefetch_factor "$PREFETCH" \
  --train.data_parallel_mode fsdp2 \
  --train.data_parallel_replicate_size 1 \
  --train.data_parallel_shard_size "$NGPU" \
  --train.micro_batch_size "$MICRO" \
  --train.gradient_accumulation_steps "$ACCUM" \
  --train.global_batch_size "$GLOBAL_BATCH" \
  --train.max_steps "$STEPS" \
  --train.save_steps "$SAVE" \
  --train.output_dir "$OUT" \
  2>&1 | tee "$LOG"
