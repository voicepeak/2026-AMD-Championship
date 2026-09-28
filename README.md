# LingBot-VLA 挑战赛 · 工作区

蚂蚁灵波具身大模型挑战赛（天池 532514）的参赛工作区。
目标：在 **RoboTwin 2.0 仿真** 上，基于 **LingBot-VLA 2.0 (6B)** 做后训练/调优，
冲进 **11/13–11/15 上海线下真机决赛**。

> 计算发生在云端（AMD Radeon Cloud / 服务器），**不是**本地。
> 本仓库是"控制台 + 唯一真相源"：管理代码改动、配置、实验记录和结果。

**👉 新加入的成员或 AI agent，先读 [`HANDOFF.md`](HANDOFF.md)（交接文档 / 任务书）。**

## 时间线（今天 2026-09-28）

| 日期 | 事项 |
|---|---|
| 即日 – **10/26 24:00** | 报名 + 线上初赛作品提交（**硬截止**） |
| 10/27 – 11/15 | 初赛评审 |
| **11/16** | 公示入围决赛名单 |
| **11/13 – 11/15** | 上海线下真机决赛 |

## 目录结构

```
LingBot-VLA-Challenge/
├── README.md              # 本文件：总览与入口
├── AGENTS.md              # 给 AI 编码助手的项目说明
├── docs/                  # 所有文档（先读这里）
│   ├── 01-competition.md  # 比赛规则/赛题/奖项
│   ├── 02-timeline.md     # 排期与执行 checklist
│   ├── 03-amd-compute.md  # AMD 算力申请流程
│   ├── 04-cloud-runbook.md# 云端实例操作手册（命令）
│   ├── 05-pitfalls.md     # 已知坑与排查
│   ├── 06-resources.md    # 资源链接汇总
│   └── 07-upstream-parity.md # 上游版本、路径和参数逐项对照
├── configs/               # 我们的训练/评测配置（覆盖官方）
├── patches/               # 对上游仓库的补丁
├── experiments/           # 每次实验的记录（复制 _TEMPLATE.md）
├── results/               # 从云端拉回的评测结果（小文件）
└── scripts/
    ├── cloud/             # 在 Radeon Cloud 实例里执行的脚本
    └── local/             # 本地管理脚本（同步/打包）
```

## 快速开始

1. 先读 `docs/01-competition.md` 和 `docs/02-timeline.md`
2. 按 `docs/03-amd-compute.md` 完成报名 + AMD 算力申请（**有排队风险，越早越好**）
3. 拿到实例后，把 `scripts/cloud/` 上传，按 `docs/04-cloud-runbook.md` 逐条执行
4. 每次实验在 `experiments/` 下建记录，结果存 `results/`

## 核心约束（务必牢记）

- 必须是**团队**（2–5 人），一人一队，指定队长
- 训练**只能用指定的 clean 数据**，禁止用 randomized 数据训练
- 必须从**官方基础 checkpoint** 起步，**不能**用已训好的 `...-6b-robotwin` 作为起点
- 云端实例是临时的，**只有 `/workspace` 持久**；要保留的东西务必先落 `/workspace`
