#!/usr/bin/env bash
# 全量闭环 Benchmark（50 clean + 50 randomized 任务，每个 10 episodes）
# 警告：8 卡约 15 小时，4 卡约 19 小时。运行前确认端口空闲、磁盘充足。
# 用法：
#   bash 40_benchmark_full.sh 8 both100x10_8gpu                 # 官方 baseline
#   bash 40_benchmark_full.sh 8 both100x10_lora "$MERGED"        # 合并后的 LoRA
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/env.sh"

NGPU="${1:-8}"
RUN_NAME="${2:-both100x10_${NGPU}gpu}"
MODEL_PATH="${3:-}"
EPISODES="${EPISODES:-10}"

case "$NGPU" in 4|8) ;; *) echo "[bench] GPU 数只支持 4 或 8: $NGPU" >&2; exit 2 ;; esac
[[ "$EPISODES" =~ ^[1-9][0-9]*$ ]] || { echo "[bench] EPISODES 必须是正整数: $EPISODES" >&2; exit 2; }
[[ "$PORT" =~ ^[0-9]+$ ]] && (( PORT >= 1 && PORT + NGPU - 1 <= 65535 )) || {
  echo "[bench] 起始端口无效: $PORT" >&2
  exit 2
}
if [[ -n "$MODEL_PATH" ]]; then
  [[ -d "$MODEL_PATH" ]] || { echo "[bench] 找不到模型目录: $MODEL_PATH" >&2; exit 2; }
  [[ -f "$MODEL_PATH/lingbotvla_cli.yaml" ]] || {
    echo "[bench] 找不到模型推理配置: $MODEL_PATH/lingbotvla_cli.yaml" >&2
    exit 2
  }
fi

for ((gpu = 0; gpu < NGPU; gpu++)); do
  port=$((PORT + gpu))
  if ss -H -ltn "sport = :${port}" 2>/dev/null | grep -q .; then
    echo "[bench] 端口 ${port} 已占用；先停止现有模型 server" >&2
    exit 2
  fi
done

echo "[bench] gpus=$NGPU run=$RUN_NAME episodes=$EPISODES"
echo "[bench] 预计墙钟时间：8 卡 ~15h，4 卡 ~19h"

cd "${ROBOTWIN_ROOT}"

if [ -n "$MODEL_PATH" ]; then
  export LINGBOTVLA_TRAINING_CONFIG="${MODEL_PATH}/lingbotvla_cli.yaml"
  echo "[bench] model path: $MODEL_PATH"
  "${LINGBOT_VLA_PYTHON}" experiments/lingbot_vla_v2_6b_robotwin/scripts/run_clean_benchmark.py \
    --gpu-count "$NGPU" --episodes "$EPISODES" \
    --task-config both \
    --model-path "$MODEL_PATH" \
    --expert-check --accept-expert-info-on-failure --no-video \
    --run-name "$RUN_NAME" --runtime-dir "${LINGBOT_RUNTIME}" --resume
else
  "${LINGBOT_VLA_PYTHON}" experiments/lingbot_vla_v2_6b_robotwin/scripts/run_clean_benchmark.py \
    --gpu-count "$NGPU" --episodes "$EPISODES" \
    --task-config both \
    --expert-check --accept-expert-info-on-failure --no-video \
    --run-name "$RUN_NAME" --runtime-dir "${LINGBOT_RUNTIME}" --resume
fi

echo "[bench] 结果目录: ${LINGBOT_RUNTIME}/outputs/${RUN_NAME}"
echo "[bench] 汇总各日志里的 'Final success rate'"
