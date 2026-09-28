#!/usr/bin/env bash
# LoRA 训练
# 用法：
#   bash 30_train_lora.sh 100 8                     # 上游配置，冒烟
#   bash 30_train_lora.sh 1000 8 ~/challenge/configs/lora_1000_8gpu.yaml
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/env.sh"

STEPS="${1:-100}"
NGPU="${2:-8}"
DEFAULT_CONFIG="${ROBOTWIN_ROOT}/experiments/lingbot_vla_v2_6b_robotwin/training/lingbotvla_cli.yaml"
CONFIG="${3:-${CONFIG:-$DEFAULT_CONFIG}}"
RUN_NAME="${RUN_NAME:-lora_${STEPS}steps_${NGPU}gpu}"
OUT="${OUT_DIR}/${RUN_NAME}"

[[ "$STEPS" =~ ^[1-9][0-9]*$ ]] || { echo "[lora] steps 必须是正整数: $STEPS" >&2; exit 2; }
case "$NGPU" in
  4) export HIP_VISIBLE_DEVICES=0,1,2,3 ;;
  8) export HIP_VISIBLE_DEVICES=0,1,2,3,4,5,6,7 ;;
  *) echo "[lora] GPU 数只支持 4 或 8: $NGPU" >&2; exit 2 ;;
esac
[[ -f "$CONFIG" ]] || { echo "[lora] 找不到训练配置: $CONFIG" >&2; exit 2; }
if grep -Eqi 'demo_randomized|randomized' "$CONFIG"; then
  echo "[lora] 配置疑似引用 randomized 数据，拒绝训练: $CONFIG" >&2
  exit 2
fi
unset ROCR_VISIBLE_DEVICES CUDA_VISIBLE_DEVICES || true

mkdir -p "${LOG_DIR}"
echo "[lora] steps=$STEPS gpus=$NGPU config=$CONFIG -> ${OUT}"

cd "${LINGBOT_VLA_SOURCE}"

# 注意：不要直接调用 torchrun（可能绑错 Python），用 python -m torch.distributed.run
"${LINGBOT_VLA_PYTHON}" -m torch.distributed.run \
  --standalone \
  --nproc-per-node="$NGPU" \
  -m tasks.vla.train_lingbotvla \
  "$CONFIG" \
  --train.data_parallel_shard_size "$NGPU" \
  --train.gradient_accumulation_steps 1 \
  --train.global_batch_size "$NGPU" \
  --train.max_steps "$STEPS" \
  --train.save_steps "$STEPS" \
  --train.output_dir "$OUT" \
  2>&1 | tee "${LOG_DIR}/${RUN_NAME}.log"

echo "[lora] 完成。checkpoint: ${OUT}/checkpoints/global_step_${STEPS}"
echo "[lora] 合并：bash 31_merge_lora.sh ${STEPS} ${NGPU}"
