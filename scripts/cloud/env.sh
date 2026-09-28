#!/usr/bin/env bash
# 云端环境变量 —— 所有脚本第一行都 source 这个文件
# 用法：source env.sh
#
# 说明：镜像已通过 ENV 持久设置 AITER_TRITON_ONLY 与 FLASH_ATTENTION_TRITON_AMD_ENABLE，
# 这里再显式设置一次，保证从干净 shell 也能工作。

export ROBOTWIN_ROOT="${ROBOTWIN_ROOT:-/RoboTwin}"
export LINGBOT_RUNTIME="${LINGBOT_RUNTIME:-/workspace/runtime}"

export LINGBOT_VLA_SOURCE="${ROBOTWIN_ROOT}/experiments/lingbot_vla_v2_6b_robotwin/source/lingbot-vla-v2"
export QWEN3VL_PATH="${ROBOTWIN_ROOT}/experiments/lingbot_vla_v2_6b_robotwin/models/Qwen3-VL-4B-Instruct-config-tokenizer"
export LINGBOT_VLA_PYTHON="/opt/robotwin-env/bin/python"
export ROBOTWIN_MODEL_ROOT="${ROBOTWIN_MODEL_ROOT:-/models/robotwin-persistent/models}"
export HF_LEROBOT_HOME="${ROBOTWIN_ROOT}/data/lerobot"

# 环境（AMD 环境用 MPLib 替代 CuRobo）
export ROBOTWIN_DISABLE_CUROBO=1
export ROBOTWIN_EE_PLANNER=mplib
export PYOPENGL_PLATFORM=egl

# ROCm / Triton
export AITER_TRITON_ONLY=1
export FLASH_ATTENTION_TRITON_AMD_ENABLE=TRUE
export PYTHONPATH="/opt/aiter${PYTHONPATH:+:${PYTHONPATH}}"

# 默认端口与卡数（脚本可用环境变量覆盖）
export PORT="${PORT:-13400}"
export GPUS="${GPUS:-8}"

export LOG_DIR="${LINGBOT_RUNTIME}/outputs/logs"
export OUT_DIR="${LINGBOT_RUNTIME}/outputs"

echo "[env] ROBOTWIN_ROOT=${ROBOTWIN_ROOT}"
echo "[env] runtime=${LINGBOT_RUNTIME}  GPUS=${GPUS}  PORT=${PORT}"
