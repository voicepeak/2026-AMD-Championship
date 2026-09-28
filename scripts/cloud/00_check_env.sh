#!/usr/bin/env bash
# 环境自检：GPU、挂载、版本、数据
# 用法：bash 00_check_env.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/env.sh"

echo "==================== 1. GPU / 设备 ===================="
ls -l /dev/kfd /dev/dri 2>&1 || true
rocminfo 2>/dev/null | head -n 5 || echo "(rocminfo 不可用)"

echo "==================== 2. 挂载 ===================="
pwd
findmnt -T "${ROBOTWIN_ROOT}" 2>/dev/null || echo "(未找到 ${ROBOTWIN_ROOT} 挂载点)"
ls -l "${ROBOTWIN_ROOT}/assets" "${ROBOTWIN_ROOT}/data" 2>&1 || true

echo "==================== 3. Git commit（应匹配固定版本）===================="
git -C "${ROBOTWIN_ROOT}" rev-parse HEAD 2>/dev/null || echo "RoboTwin: N/A"
git -C "${ROBOTWIN_ROOT}/XPolicyLab" rev-parse HEAD 2>/dev/null || echo "XPolicyLab: N/A"
git -C "${LINGBOT_VLA_SOURCE}" rev-parse HEAD 2>/dev/null || echo "LingBot-VLA: N/A"

echo "==================== 4. Python 环境 ===================="
"${LINGBOT_VLA_PYTHON}" - <<'PY' || echo "(python 自检失败)"
import importlib
for m in ["torch","triton","flash_attn","aiter","open3d","sapien","mplib","lerobot"]:
    try:
        mod = importlib.import_module(m)
        print(f"  {m:12s}", getattr(mod, "__version__", "?"))
    except Exception as e:
        print(f"  {m:12s} MISSING: {e}")
import torch
print("  torch.hip  ", torch.version.hip)
print("  cuda.available", torch.cuda.is_available(), "count", torch.cuda.device_count())
PY

echo "==================== 5. 数据（应为 50 任务）===================="
echo "demo_clean dirs : $(find "${ROBOTWIN_ROOT}/data/demo_clean" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)  (期望 50)"
echo "lerobot dirs    : $(find "${ROBOTWIN_ROOT}/data/lerobot" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)  (期望 50)"
echo "train list lines: $(wc -l < "${ROBOTWIN_ROOT}/data/robotwin_demo_clean_joint_v30.txt" 2>/dev/null || echo N/A)  (期望 50)"

echo "==================== 6. 运行目录 / 磁盘 ===================="
mkdir -p "${LINGBOT_RUNTIME}/eval_result" "${LINGBOT_RUNTIME}/outputs/logs" \
         "${LINGBOT_RUNTIME}/outputs/benchmarks" "${LINGBOT_RUNTIME}/.cache/huggingface"
df -h / /workspace 2>/dev/null || df -h /
echo "[check] 完成。若有 MISSING / 数量不为 50，先排查再进入训练。"
