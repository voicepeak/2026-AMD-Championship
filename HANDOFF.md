# 交接文档 · START HERE

> 人先花 3 分钟读第 1–3 节；第 4 节起是**给 AI agent 的任务书**。
> 最后更新：2026-09-28 · 当前阶段：**准备启动（卡在人工步骤）**

---

## 0. 一句话现状

仓库已建好并推到远端 `https://github.com/voicepeak/2026-AMD-Championship`。
**比赛报名、AMD 算力、云实例都还没拿到** —— 这些**只能人工完成**（见第 2、3 节）。
但在拿到算力**之前**，agent 就能并行完成第 4 节的一批本地工作，不要干等。

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
| 建实例 + 拿 SSH 信息 | **人** | `docs/04` 第 1 节 | agent 上云执行 |

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

## 4. Agent 现在就能做的（**无需算力**，本地/网络即可）

> 原则：**能验证的才算完成**。每项都给出验收标准（DoD）。完成后更新 `experiments/` 或对应文档。
> 优先级 P0 > P1 > P2。

### P0 · 对齐上游，消除 runbook 与真实脚本的偏差
- **T1｜核对并补全训练/评测参数**
  - 抓取上游 `Robbyant/lingbot-vla-v2`：`configs/vla/Training_Config.md`、
    `configs/vla/robotwin/*.yaml`、`configs/robot_configs/robotwin.yaml`、
    `lingbotvla/data/vla_data/README.md`
  - 抓取 `ZiguanWang/Robotwin-radeon-cloud`：`docker/`、
    `experiments/lingbot_vla_v2_6b_robotwin/scripts/*`、`training/*`
  - 核对 `scripts/cloud/*.sh` 与 `docs/04-cloud-runbook.md` 里的**路径、参数名、脚本名**是否与实际一致，不一致就改
  - DoD：产出一份 `docs/07-upstream-parity.md`（逐条对照表：我们的写法 vs 上游实际），并把 `scripts/cloud` 修正到可直接跑
- **T2｜产出派生训练配置**
  - 基于上游 robotwin 配置，写 `configs/lora_1000_8gpu.yaml`、`configs/sft_full_8gpu.yaml`（含注释：相对上游改了什么）
  - DoD：每个 yaml 顶部写清目的/改动/对应实验；能被 `30_train_lora.sh` 正确引用

### P1 · 工具：让"评测 → 结论"自动化
- **T3｜benchmark 结果汇总脚本**
  - 写 `scripts/local/summarize_benchmark.ps1`：解析 `results/<run>/` 下日志里的
    `Final success rate`，输出 clean/randomized 总成功率并写入 `results/<run>/SUMMARY.md`
  - DoD：对一份**样例日志**能跑出正确表格（自己造样例验证）
- **T4｜实验总表生成**
  - 写 `scripts/local/report_experiments.ps1`：扫描 `results/*/SUMMARY.md` → 生成 `results/OVERVIEW.md`
  - DoD：≥2 个 run 时表格正确
- **T5｜任务清单**
  - 从 RoboTwin 2.0 抓取 50 任务名，生成 `data/manifests/robotwin_tasks.md`，
    并**标出 8–10 个推荐验证子集**（快、有代表性，用于小规模选点）
  - DoD：清单与官方一致，子集有理由说明

### P2 · 方案与提交物
- **T6｜训练方案文档**
  - 写 `docs/08-training-plan.md`：LoRA vs 全参数 SFT 权衡、超参建议、验证子集策略、
    按 `docs/02` 的时间预算表（含"一次全量 15–19h"的排期）
  - DoD：给出**明确推荐**（默认走哪条）与备选
- **T7｜初赛提交物模板**
  - 建 `submission/` + `submission/CHECKLIST.md`（按官方要求的材料清单，待官方细则补充）
  - DoD：清单可勾选，说明每项怎么产出

### 可选
- **T8｜本地只读镜像上游代码** 到 `third_party/`（**不入库**，仅便于 grep 与 ctrl-F 查阅）

> Agent 注意：`docs/` 文档要用**中文**，代码注释保持简洁；`.sh` 必须 LF（`.gitattributes` 已配）。

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
| 自租 **4090（24GB）** | **仅调试 / 小规模验证 / 备用推理** | 显存不足，**不做主力训练** |

- 4090（24G）**跑不了全参数 SFT**；LoRA 也过于勉强（6B + 视觉编码器 + depth/video teacher）
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
| 2026-09-28 | 明确算力方案：AMD 主力，4090(24G) 仅调试 |
