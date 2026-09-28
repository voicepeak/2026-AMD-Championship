#!/usr/bin/env bash
# 启动官方模型 server
# 用法：
#   bash 10_launch_server.sh                       # 官方 baseline，GPU0，端口 13400
#   bash 10_launch_server.sh 0 13400               # 指定 GPU / 端口
#   bash 10_launch_server.sh 0 13400 /path/to/ckpt # 指定 checkpoint（如合并后的 LoRA）
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/env.sh"

GPU="${1:-0}"
PORT_ARG="${2:-$PORT}"
CKPT="${3:-}"

mkdir -p "${LOG_DIR}"

if [ -n "$CKPT" ]; then
  echo "[server] 使用 checkpoint: $CKPT"
  : "${LINGBOTVLA_TRAINING_CONFIG:=$CKPT/lingbotvla_cli.yaml}"
  export LINGBOTVLA_TRAINING_CONFIG
  LOG="${LOG_DIR}/server_gpu${GPU}_port${PORT_ARG}_$(date +%Y%m%d_%H%M%S).log"
  cd "${ROBOTWIN_ROOT}"
  exec bash experiments/lingbot_vla_v2_6b_robotwin/scripts/launch_official_server.sh \
    "$GPU" "$PORT_ARG" "$LOG" False "$CKPT"
else
  echo "[server] 使用官方 baseline checkpoint"
  LOG="${LOG_DIR}/official_server_gpu${GPU}_port${PORT_ARG}.log"
  cd "${ROBOTWIN_ROOT}"
  exec bash experiments/lingbot_vla_v2_6b_robotwin/scripts/launch_official_server.sh \
    "$GPU" "$PORT_ARG" "$LOG" False
fi

# 另一个终端等待健康检查：
#   until curl -fsS http://127.0.0.1:${PORT_ARG}/healthz; do sleep 2; done
