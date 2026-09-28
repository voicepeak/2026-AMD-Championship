#!/usr/bin/env bash
# 环境自检：GPU、挂载、固定版本、数据和运行入口
# 用法：bash 00_check_env.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/env.sh"

EXPECTED_ROBOTWIN="266f3aadf505a4f7fe9af0faa41a20f5f47cd123"
EXPECTED_XPOLICYLAB="c37109c500be67d0dea6b36bf7337bbd26e763cd"
EXPECTED_LINGBOT="951475ae1b1d87553e7dc47c97b53a3d695c0d13"
FAILURES=0

pass() { printf '[PASS] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*" >&2; FAILURES=$((FAILURES + 1)); }

check_commit() {
  local name="$1" path="$2" expected="$3" actual
  actual="$(git -C "$path" rev-parse HEAD 2>/dev/null || true)"
  if [[ "$actual" == "$expected" ]]; then
    pass "$name commit = $actual"
  else
    fail "$name commit = ${actual:-N/A}，期望 $expected"
  fi
}

check_path() {
  local path="$1"
  if [[ -e "$path" ]]; then pass "存在 $path"; else fail "缺少 $path"; fi
}

echo "==================== 1. GPU / 设备 ===================="
if [[ -e /dev/kfd && -d /dev/dri ]]; then
  pass "/dev/kfd 与 /dev/dri 可用"
else
  fail "缺少 /dev/kfd 或 /dev/dri"
fi
rocminfo 2>/dev/null | sed -n '1,5p' || warn "rocminfo 不可用"

echo "==================== 2. 挂载 ===================="
pwd
check_path "${ROBOTWIN_ROOT}"
check_path "${ROBOTWIN_ROOT}/assets"
check_path "${ROBOTWIN_ROOT}/data"
check_path "${ROBOTWIN_ROOT}/experiments/lingbot_vla_v2_6b_robotwin/models/robbyant_lingbot-vla-v2-6b/model.safetensors.index.json"
check_path "${QWEN3VL_PATH}"
if findmnt -T /models/robotwin-persistent >/dev/null 2>&1; then
  pass "Devzone 持久数据已挂载到 /models/robotwin-persistent"
else
  warn "未检测到 Devzone 挂载；full 镜像可忽略，external-data 镜像必须先修复"
fi

echo "==================== 3. Git commit（应匹配固定版本）===================="
check_commit "RoboTwin" "${ROBOTWIN_ROOT}" "$EXPECTED_ROBOTWIN"
check_commit "XPolicyLab" "${ROBOTWIN_ROOT}/XPolicyLab" "$EXPECTED_XPOLICYLAB"
check_commit "LingBot-VLA" "${LINGBOT_VLA_SOURCE}" "$EXPECTED_LINGBOT"

echo "==================== 4. Python 环境 ===================="
if "${LINGBOT_VLA_PYTHON}" - <<'PY'
import importlib
for m in ["torch","triton","flash_attn","aiter","open3d","sapien","mplib","lerobot"]:
    mod = importlib.import_module(m)
    print(f"  {m:12s}", getattr(mod, "__version__", "?"))
import torch
print("  torch.hip  ", torch.version.hip)
print("  cuda.available", torch.cuda.is_available(), "count", torch.cuda.device_count())
assert torch.cuda.is_available()
assert torch.cuda.device_count() in (4, 8), torch.cuda.device_count()
import flash_attn
assert flash_attn.__version__ == "2.8.4", flash_attn.__version__
x = torch.randn(1024, 1024, device="cuda")
print("  matmul", (x @ x).shape)
PY
then
  pass "Python/ROCm 栈与 4/8 张 GPU 自检通过"
else
  fail "Python/ROCm 栈自检失败"
fi

echo "==================== 5. 数据（应为 50 任务）===================="
DEMO_COUNT="$(find "${ROBOTWIN_ROOT}/data/demo_clean" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
LEROBOT_COUNT="$(find "${ROBOTWIN_ROOT}/data/lerobot" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
TRAIN_LIST="${ROBOTWIN_ROOT}/data/robotwin_demo_clean_joint_v30.txt"
TRAIN_COUNT="$(awk 'NF {count++} END {print count+0}' "$TRAIN_LIST" 2>/dev/null || echo 0)"
[[ "$DEMO_COUNT" == 50 ]] && pass "demo_clean 任务目录 = 50" || fail "demo_clean 任务目录 = $DEMO_COUNT，期望 50"
[[ "$LEROBOT_COUNT" == 50 ]] && pass "LeRobot 任务目录 = 50" || fail "LeRobot 任务目录 = $LEROBOT_COUNT，期望 50"
[[ "$TRAIN_COUNT" == 50 ]] && pass "clean 训练清单 = 50 行" || fail "clean 训练清单 = $TRAIN_COUNT 行，期望 50"
if [[ ! -f "$TRAIN_LIST" ]]; then
  fail "缺少 clean 训练清单: $TRAIN_LIST"
elif grep -Eqi 'randomized' "$TRAIN_LIST"; then
  fail "训练清单包含 randomized 路径，违反比赛规则"
else
  pass "训练清单未发现 randomized 数据"
fi

echo "==================== 6. 上游入口 ===================="
check_path "${ROBOTWIN_ROOT}/scripts/eval_policy_xpolicylab.py"
check_path "${ROBOTWIN_ROOT}/experiments/lingbot_vla_v2_6b_robotwin/scripts/launch_official_server.sh"
check_path "${ROBOTWIN_ROOT}/experiments/lingbot_vla_v2_6b_robotwin/scripts/run_clean_benchmark.py"
check_path "${ROBOTWIN_ROOT}/experiments/lingbot_vla_v2_6b_robotwin/scripts/merge_lora_dcp.py"
check_path "${ROBOTWIN_ROOT}/experiments/lingbot_vla_v2_6b_robotwin/scripts/convert_full_sft_dcp.py"
check_path "${ROBOTWIN_ROOT}/experiments/lingbot_vla_v2_6b_robotwin/training/lingbotvla_cli.yaml"
check_path "${ROBOTWIN_ROOT}/experiments/lingbot_vla_v2_6b_robotwin/training/train_full_sft.sh"

echo "==================== 7. 运行目录 / 磁盘 ===================="
mkdir -p "${LINGBOT_RUNTIME}/eval_result" "${LINGBOT_RUNTIME}/outputs/logs" \
         "${LINGBOT_RUNTIME}/outputs/benchmarks" "${LINGBOT_RUNTIME}/.cache/huggingface"
df -h / /workspace 2>/dev/null || df -h /
if (( FAILURES > 0 )); then
  echo "[check] 失败：共 ${FAILURES} 项未通过；修复后再训练。" >&2
  exit 1
fi
echo "[check] 全部硬检查通过，可以进入单任务链路验证。"
