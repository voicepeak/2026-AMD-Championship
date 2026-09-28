#!/usr/bin/env bash
# LoRA 训练
# 用法：
#   bash 30_train_lora.sh 100 8      # 100 steps, 8 卡（冒烟）
#   bash 30_train_lora.sh 1000 8     # 1000 steps, 8 卡（正式）
#   bash 30_train_lora.sh 5000 4     # 5000 steps, 4 卡
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/env.sh"

STEPS="${1:-100}"
NGPU="${2:-8}"
RUN_NAME="lora_${STEPS}steps_${NGPU}gpu"
OUT="${OUT_DIR}/${RUN_NAME}"

if [ "$NGPU" -eq 8 ]; then
  export HIP_VISIBLE_DEVICES=0,1,2,3,4,5,6,7
else
  export HIP_VISIBLE_DEVICES=0,1,2,3
fi
unset ROCR_VISIBLE_DEVICES CUDA_VISIBLE_DEVICES || true

mkdir -p "${LOG_DIR}"
echo "[lora] steps=$STEPS gpus=$NGPU -> ${OUT}"

cd "${LINGBOT_VLA_SOURCE}"
source /opt/robotwin-env/bin/activate

# 注意：不要直接调用 torchrun（可能绑错 Python），用 python -m torch.distributed.run
python -m torch.distributed.run \
  --standalone \
  --nproc-per-node="$NGPU" \
  -m tasks.vla.train_lingbotvla \
  "${ROBOTWIN_ROOT}/experiments/lingbot_vla_v2_6b_robotwin/training/lingbotvla_cli.yaml" \
  --train.data_parallel_shard_size "$NGPU" \
  --train.gradient_accumulation_steps 1 \
  --train.global_batch_size "$NGPU" \
  --train.max_steps "$STEPS" \
  --train.save_steps "$STEPS" \
  --train.output_dir "$OUT" \
  2>&1 | tee "${LOG_DIR}/${RUN_NAME}.log"

echo "[lora] 完成。checkpoint: ${OUT}/checkpoints/global_step_${STEPS}"
echo "[lora] 合并：bash 31_merge_lora.sh ${STEPS} ${NGPU}"
