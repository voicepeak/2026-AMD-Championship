#!/usr/bin/env bash
# 合并 LoRA checkpoint 为可推理的 hf_ckpt
# 用法：bash 31_merge_lora.sh 1000 8
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/env.sh"

STEPS="${1:-100}"
NGPU="${2:-8}"
RUN_NAME="lora_${STEPS}steps_${NGPU}gpu"
OUT="${OUT_DIR}/${RUN_NAME}"
CKPT="${OUT}/checkpoints/global_step_${STEPS}"
MERGED="${OUT}/merged_checkpoint/global_step_${STEPS}/hf_ckpt"
BASE_MODEL="${ROBOTWIN_ROOT}/experiments/lingbot_vla_v2_6b_robotwin/models/robbyant_lingbot-vla-v2-6b"

if [ ! -d "$CKPT" ]; then
  echo "[merge] 找不到 checkpoint: $CKPT" >&2
  exit 1
fi

cd "${ROBOTWIN_ROOT}"
source /opt/robotwin-env/bin/activate

python experiments/lingbot_vla_v2_6b_robotwin/scripts/merge_lora_dcp.py \
  --checkpoint "$CKPT" \
  --training-output "$OUT" \
  --base-model "$BASE_MODEL" \
  --output "$MERGED" \
  --rank 8 \
  --alpha 16

echo "[merge] 完成: $MERGED"
echo "[merge] 启动推理：bash 10_launch_server.sh 0 13400 \"$MERGED\""
echo "[merge] 全量评测：bash 40_benchmark_full.sh 8 both100x10_lora_${STEPS} \"$MERGED\""
