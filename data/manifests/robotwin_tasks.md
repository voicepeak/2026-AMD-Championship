# RoboTwin 2.0 · 50 个任务清单与验证子集

> 来源：HuggingFace 数据集 `TianxingChen/RoboTwin2.0` 的 `dataset/` 目录（共 50 个任务目录）。
> 每个任务对应一个 `demo_clean` 数据集；初赛评测在 `demo_clean` 与 `demo_randomized` 两组各跑 50 个任务。
> 本清单用于：① 核对下载/转换是否完整；② 挑小规模验证子集，避免每次跑全量（一次全量 15–19 小时）。
>
> 机器可读版本：`data/manifests/robotwin_tasks.txt`（每行一个任务，共 50 行）。

## 50 个任务（按字母序）

1. adjust_bottle
2. beat_block_hammer
3. blocks_ranking_rgb
4. blocks_ranking_size
5. click_alarmclock
6. click_bell
7. dump_bin_bigbin
8. grab_roller
9. handover_block
10. handover_mic
11. hanging_mug
12. lift_pot
13. move_can_pot
14. move_pillbottle_pad
15. move_playingcard_away
16. move_stapler_pad
17. open_laptop
18. open_microwave
19. pick_diverse_bottles
20. pick_dual_bottles
21. place_a2b_left
22. place_a2b_right
23. place_bread_basket
24. place_bread_skillet
25. place_burger_fries
26. place_can_basket
27. place_cans_plasticbox
28. place_container_plate
29. place_dual_shoes
30. place_empty_cup
31. place_fan
32. place_mouse_pad
33. place_object_basket
34. place_object_scale
35. place_object_stand
36. place_phone_stand
37. place_shoe
38. press_stapler
39. put_bottles_dustbin
40. put_object_cabinet
41. rotate_qrcode
42. scan_object
43. shake_bottle
44. shake_bottle_horizontally
45. stack_blocks_three
46. stack_blocks_two
47. stack_bowls_three
48. stack_bowls_two
49. stamp_seal
50. turn_switch

## 建议的验证子集（10 个，用于快速选点）

在**不跑全量**时，用这 10 个任务做闭环验证，覆盖"短程抓放 / 精细操作 / 开关 / 旋转 / 动态"多种技能：

| 任务 | 类型 | 选它的理由 |
|---|---|---|
| `adjust_bottle` | 调整姿态 | 官方单任务 smoke 用的就是它，链路已验证 |
| `click_bell` | 点击/精细 | 已下载并转换过（`smoke_demo_clean_click_bell`） |
| `click_alarmclock` | 点击/精细 | 同类精细操作，短程 |
| `lift_pot` | 抓取抬升 | 经典抓取，短程 |
| `open_laptop` | 开合 | 铰链关节操作，与纯抓放不同 |
| `press_stapler` | 按压 | 接触力/精细控制 |
| `rotate_qrcode` | 旋转 | 需要旋转自由度 |
| `shake_bottle` | 动态操作 | 与静态抓放分布不同 |
| `turn_switch` | 开关 | 小物件精细操作 |
| `place_empty_cup` | 放置 | 稳定放置，验证 place 类泛化 |

> 该子集是**建议**，不是官方要求。首轮可用 3–5 个（如 `adjust_bottle` + `click_bell` + `lift_pot`）
> 进一步压低验证时间；确认有效后再扩到 10 个或全量。

## 用法

```bash
# 只下载/转换几个任务做验证（在云端）：见 RoboTwin scripts/download_xpolicylab_data.sh
#  和 XPolicyLab/scripts/transform_lerobot_v21_format.py

# 全量评测仍是 50 clean + 50 randomized（每个 10 episodes）
bash scripts/cloud/40_benchmark_full.sh 8 both100x10_8gpu
```

## 合规提醒

- **训练只能用 `demo_clean`**；`demo_randomized` 只能用于评测，绝不能进训练数据。
- 训练清单固定为 `/RoboTwin/data/robotwin_demo_clean_joint_v30.txt`（50 行）。
