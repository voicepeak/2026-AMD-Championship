#!/usr/bin/env bash
# 单任务闭环评测（用于快速验证渲染 / MPLib / WebSocket 链路）
# 用法：
#   bash 20_eval_single.sh                             # adjust_bottle + demo_clean + 10 ep
#   bash 20_eval_single.sh adjust_bottle demo_clean 10 13400
#   bash 20_eval_single.sh adjust_bottle demo_randomized 1
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/env.sh"

TASK="${1:-adjust_bottle}"
TASK_CONFIG="${2:-demo_clean}"
TEST_NUM="${3:-10}"
PORT_ARG="${4:-$PORT}"

echo "[eval] task=$TASK config=$TASK_CONFIG episodes=$TEST_NUM port=$PORT_ARG"
echo "[eval] 请确保模型 server 已在 port $PORT_ARG 运行"

cd "${ROBOTWIN_ROOT}"
source /opt/robotwin-env/bin/activate

python scripts/eval_policy_xpolicylab.py \
  --task_name "$TASK" \
  --task_config "$TASK_CONFIG" \
  --policy_name LingBot-VLA-v2 \
  --protocol lingbot_vla_v2 \
  --host 127.0.0.1 \
  --port "$PORT_ARG" \
  --device_id 0 \
  --seed 0 \
  --test_num "$TEST_NUM" \
  --expert_check true \
  --accept_expert_info_on_failure true \
  --eval_batch false \
  --additional_info eval_video_log=false

echo "[eval] 结果见 ${LINGBOT_RUNTIME}/eval_result"
