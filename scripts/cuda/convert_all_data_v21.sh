#!/usr/bin/env bash
# CUDA / 4090 侧：批量把 RoboTwin demo_clean 转成 LeRobot v2.1，并生成训练清单。
#
# 与 AMD 官方镜像的差异：官方用 transform_lerobot_v30_format.py + lerobot 0.6.0；
# 本机 lerobot 为 0.4.2，v30 转换器需要的 API 不存在，故改用 v21 转换器
# （上游 README 明确支持 LeRobot v2.1 或 v3.0 两种数据集）。
#
# 用法：JOBS=4 bash convert_all_data_v21.sh
set -Eeuo pipefail

RUNTIME="${RUNTIME:-/home/featurize/runtime}"
ROBOTWIN_ROOT="${ROBOTWIN_ROOT:-/home/featurize/work/projects/RoboTwin}"
LINGBOT_PY="${LINGBOT_PY:-/environment/miniconda3/envs/lingbotvla/bin/python}"
export HF_LEROBOT_HOME="${HF_LEROBOT_HOME:-${RUNTIME}/data/lerobot}"
export PATH="${LINGBOT_PY%/bin/python}/bin:${PATH}"

MANIFEST="${RUNTIME}/data/robotwin_demo_clean_joint_v21.txt"
LOG_DIR="${RUNTIME}/outputs/logs"
CLEAN_ROOT="${CLEAN_ROOT:-${RUNTIME}/data/robotwin/demo_clean}"
JOBS="${JOBS:-4}"
mkdir -p "${HF_LEROBOT_HOME}" "${LOG_DIR}"

# 注意：RoboTwin/data/demo_clean 常是指向真实目录的符号链接，
# 所以任务列表直接用真实路径（否则 find 默认不跟随符号链接，会得到 0 个任务）。
cd "${ROBOTWIN_ROOT}"
mapfile -t tasks < <(find "${CLEAN_ROOT}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
echo "[convert] 发现任务数: ${#tasks[@]}，并行度=${JOBS}"
if [[ "${#tasks[@]}" -ne 50 ]]; then
  echo "[convert] 警告：任务数不是 50，可能数据未下载完。继续，但请检查。" >&2
fi

convert_one() {
  local t="$1" rid="${1}_joint_v21"
  if [[ -f "${HF_LEROBOT_HOME}/${rid}/meta/info.json" ]]; then
    echo "[skip] ${t}"
    return 0
  fi
  echo "[convert] ${t}"
  if "${LINGBOT_PY}" XPolicyLab/scripts/transform_lerobot_v21_format.py \
        "demo_clean.${t}.aloha_agilex" --repo_id "${rid}" --max_episode 50 \
        >"${LOG_DIR}/convert_${t}.log" 2>&1; then
    echo "[ok] ${t}"
  else
    echo "[FAIL] ${t}"
    return 1
  fi
}
export -f convert_one
export HF_LEROBOT_HOME LINGBOT_PY LOG_DIR

printf '%s\n' "${tasks[@]}" | \
  xargs -r -P "${JOBS}" -I{} bash -c 'convert_one "$@"' _ {}

: >"${MANIFEST}"
for t in "${tasks[@]}"; do
  printf 'robotwin %s/%s_joint_v21\n' "${HF_LEROBOT_HOME}" "${t}" >>"${MANIFEST}"
done

ok=$(ls "${HF_LEROBOT_HOME}" 2>/dev/null | grep -c '_joint_v21' || true)
echo "[convert] 完成。产物数=${ok}/50；清单: ${MANIFEST} ($(wc -l < "${MANIFEST}") 行)"
