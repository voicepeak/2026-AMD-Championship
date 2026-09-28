# 交接文档 · START HERE

> 人先花 3 分钟读第 1–3 节；第 4 节起是**给 AI agent 的任务书**。
> 最后更新：2026-09-28 · 当前阶段：**CUDA 调试实例已就绪；AMD 正式算力仍待申请/开通**

---

## 0. 一句话现状

仓库已建好并推到远端 `https://github.com/voicepeak/2026-AMD-Championship`。
单卡 **RTX 4090 48GB CUDA 调试实例已完成初始化**，环境与最小 clean 数据链已验证，见
`experiments/2026-09-28_cuda4090_bootstrap.md`。正式训练和全量评测所需的 **AMD 算力仍未拿到**，
相关人工步骤见第 2、3 节；等待期间继续完成第 4 节任务，并可在 CUDA 实例做短烟测。

---

## 1. 仓库怎么用

- 本地就是 `D:\LingBot-VLA-Challenge`（远端仓库名 `2026-AMD-Championship`）
- 结构见 `README.md`；云端操作手册见 `docs/04-cloud-runbook.md`
- **计算在云端，本地不跑训练**。本仓库 = 代码改动 + 配置 + 实验记录 + 结果的"控制台"

关键入口：

| 我想… | 看这里 |
|---|---|
| 了解比赛 | `docs/01-competition.md` |
| 知道什么时候做什么 | `docs/02-timeline.md` |
| 申请算力 | `docs/03-amd-compute.md` |
| 到云端后怎么操作 | `docs/04-cloud-runbook.md` |
| 踩了什么坑 | `docs/05-pitfalls.md` |
| 找链接 | `docs/06-resources.md` |

---

## 2. 现在卡在哪（阻塞项）

| 阻塞项 | 谁做 | 怎么解 | 解除后解锁 |
|---|---|---|---|
| 天池报名 + 组队 | **人** | 见第 3 节 | 算力申请的前置 |
| AMD 开发者计划注册 | **人** | `developer.amd.com.cn/login?source=sSEUZ7cAA` | 算力申请的前置 |
| 加入官方钉钉群 | **人** | 报名后按页面提示 | 拿到算力申请入口 |
| 提交 GPU 算力申请（每人） | **人** | `developer.amd.com.cn/contestgpu_apply01` | 云实例 |
| AMD 实例 + SSH 信息 | **人** | `docs/04` 第 1 节 | 正式训练与全量评测 |

---

## 3. 人现在要做的（约 30 分钟）

1. **天池报名**：https://tianchi.aliyun.com/competition/entrance/532514
   - 组 2–5 人队，**指定队长**（队长领算力、负责提交）
   - 记下**天池团队 ID**
2. **注册 AMD 开发者计划（ADP）**：https://developer.amd.com.cn/login?source=sSEUZ7cAA
3. **加入官方钉钉群**（报名页/官方仓库里有入口）
4. **每人提交算力申请**：https://developer.amd.com.cn/contestgpu_apply01（填天池团队 ID）
5. 拿到实例后，把 SSH 信息填进 `scripts/local/config.secret.ps1`（复制 `config.example.ps1`）
6. 把本文件第 9 节的 prompt 发给 agent

> 完成 1–4 后 agent 就能开始"上云"部分；完成 5 后 agent 可端到端操作。

---

## 4. 无需算力的任务（T1–T8）

> 状态：**T1–T7 已完成**（T1 由 Codex 完成；T2–T7 由 opencode 完成，2026-09-28）。T8 为可选，未做。

| 任务 | 内容 | 状态 | 产物 |
|---|---|---|---|
| T1 | 上游对齐、修正云端脚本 | ✅ | `docs/07-upstream-parity.md`、`scripts/cloud/*` |
| T2 | 派生训练配置 | ✅ | `configs/lora_1000_8gpu.yaml`、`configs/sft_full_8gpu.yaml` |
| T3 | benchmark 结果汇总 | ✅ | `scripts/local/summarize_benchmark.ps1`（样例验证通过） |
| T4 | 实验总表 | ✅ | `scripts/local/report_experiments.ps1`（样例验证通过） |
| T5 | 50 任务清单 + 验证子集 | ✅ | `data/manifests/robotwin_tasks.{md,txt}` |
| T6 | 训练方案 | ✅ | `docs/08-training-plan.md` |
| T7 | 提交物 checklist | ✅ | `submission/CHECKLIST.md` |
| T8 | 本地只读镜像上游代码 | ⬜ 可选 | （未做，按需再做） |

补充产物：`docs/09-4090-debug-env.md`（CUDA 调试环境搭建步骤）。

### 接下来仍需人工 / 算力的事

1. （人在 4090）用验证子集跑一次 LoRA 冒烟：`bash scripts/cloud/30_train_lora.sh 100 8 configs/lora_1000_8gpu.yaml`
2. （算力）下载全量 50 任务数据 + 仿真资产
3. （算力）baseline 单任务闭环 → 记录到 `experiments/`
4. （算力）正式训练：`configs/lora_1000_8gpu.yaml`（保底）→ `configs/sft_full_8gpu.yaml`（冲分）

> Agent 注意：`docs/` 文档用**中文**；`.sh` 必须 LF（`.gitattributes` 已配）；
> **`.ps1` 必须保存为 UTF-8 with BOM**，否则 Windows PowerShell 5.1 会乱码解析失败。

---

## 5. 拿到实例后 Agent 要做的

严格照 `docs/04-cloud-runbook.md` 执行，顺序：

1. `scripts/local/sync_up.ps1` 上传
2. 云端 `bash 00_check_env.sh`（全绿才继续）
3. `bash 10_launch_server.sh 0 13400` + `bash 20_eval_single.sh adjust_bottle demo_clean 1` 验链路
4. baseline 10-episode 闭环 → 记录到 `experiments/`
5. 训练（`30_train_lora.sh` → `31_merge_lora.sh`）→ 小规模选点 → 全量 `40_benchmark_full.sh`
6. 结果 `sync_down.ps1` 拉回，跑 T3/T4 工具出汇总

**硬约束**：只用 clean 数据训练；从官方 baseline 起步；输出写 `/workspace/runtime`。

---

## 6. 交付物与验收

| 交付物 | 验收 |
|---|---|
| 初赛提交物 | 按官方要求（`submission/CHECKLIST.md`）在 **10/26 24:00** 前提交 |
| 可复现记录 | `experiments/` 每次实验有记录；`results/` 有汇总 |
| 最优模型 | 全量 clean + randomized 成功率，`results/OVERVIEW.md` 可比 |

---

## 7. 算力方案

| 机器 | 角色 | 说明 |
|---|---|---|
| **AMD Radeon Cloud**（W7900D 48GB × 4/8） | **主力训练 + 全量评测** | 官方环境、免费，优先使用 |
| 自租 **4090（48GB）** | **仅调试 / 小规模验证 / 备用推理** | 已完成 CUDA 环境、clean 数据链、基础模型与 fused MoE 验证；**不做主力训练** |

- 单卡 4090（48G）不承担正式全参数 SFT；LoRA 先做 1–10 步烟测，再迁移 AMD 多卡
- 用途：提前在 CUDA 上跑通代码/数据/评测链路、跑 LoRA 冒烟（1–10 步）、少量任务闭环验证
- **权重可跨环境迁移**：4090 上产出的 checkpoint 可在 AMD 上评测，不锁环境

## 8. 决策点（需要人拍板）

- [ ] **主攻路线**：LoRA 还是全参数 SFT？（默认建议 LoRA 起步，先保交付，再上 SFT 冲分）
- [ ] **仓库可见性**：当前 public，是否改 private？
- [ ] **GPU 规格**：申请/使用 4 卡还是 8 卡？（全量评测时间差 4h）
- [ ] **团队分工**：谁负责报名/提交，谁负责算法，谁负责工程

---

## 9. 怎么让 agent 接手（复制这段发给它）

```
你在 D:\LingBot-VLA-Challenge 工作。先读 HANDOFF.md，然后读 README.md 和 docs/04-cloud-runbook.md。
现在先做 HANDOFF.md 第 4 节里"无需算力"的任务，从 P0 开始：
T1（上游对齐）→ T2（派生配置）→ T3/T4（结果汇总工具）→ T5（任务清单）。
每完成一项：更新对应文件、在 experiments/ 或文档里留下验收证据、用中文写清改了什么。
不要提交或推送 git，除非我明确要求。做完一项就告诉我，等我确认再继续下一项。
```

---

## 10. 变更记录

| 日期 | 变更 |
|---|---|
| 2026-09-28 | 建立工作区；新增本交接文档 |
| 2026-09-28 | 明确算力方案：AMD 主力，4090 仅调试；实例实测为 48GB |
| 2026-09-28 | 4090 48GB 调试实例就绪：PyTorch/FlashAttention、clean 数据转换、基础权重与 fused MoE 验证通过 |
| 2026-09-28 | 完成 T2–T7：派生配置、结果汇总工具、任务清单、训练方案、提交 checklist；新增 `docs/08`、`docs/09` |
| 2026-09-28 | 约定：本地 `.ps1` 必须 UTF-8 with BOM，已对全部脚本生效 |
