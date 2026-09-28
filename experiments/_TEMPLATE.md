# 实验记录模板 —— 复制到 experiments/YYYY-MM-DD_<名称>.md

## 元信息
- 日期：
- 负责人：
- 实验 ID / 名称：
- 云端实例：卡数 __ / 端口 __ / run-name __

## 目标（一句话）
<!-- 这次想验证什么？ -->

## 配置
- 路线：LoRA / 全参数 SFT / 无训练（baseline）
- 起点 checkpoint：官方 baseline / step_xxx
- 关键参数：max_steps __ / micro_batch __ / global_batch __ / 优化器 __
- 数据：demo_clean（必须）
- 配置文件：configs/xxx.yaml
- 对上游的补丁：patches/xxx.patch（无则写"无"）

## 命令
```bash
# 粘贴实际执行的命令
```

## 结果
| 指标 | clean | randomized |
|---|---|---|
| success rate | | |
| 评测任务数 / episodes | | |

- 耗时：
- 产物路径（云）：`/workspace/runtime/outputs/<run-name>`
- 本地结果：`results/<run-name>/`

## 观察与结论
<!-- 现象、异常、是否达到目标 -->

## 下一步
<!-- 下一步做什么 -->

## 相关链接
- 上游 issue / commit：
