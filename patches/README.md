# patches —— 对上游仓库的补丁

用于记录我们对以下上游仓库所做的所有修改（除配置外的代码改动）：

- `RoboTwin`（commit `266f3aad...`）
- `XPolicyLab`（commit `c37109c5...`）
- `lingbot-vla-v2`（commit `951475ae...`）

## 为什么需要

云端镜像里的代码是固定的。我们的代码改动必须显式记录，才能在：
- 换实例 / 重装镜像后复现
- 提交作品时说明改动
- 回滚

## 使用方式

1. 在云端实例里改代码后，回到该仓库目录生成 diff：
   ```bash
   git -C /RoboTwin diff > /workspace/runtime/changes/RoboTwin_$(date +%F).patch
   ```
2. 把 patch 拉回本地，放到 `patches/`
3. 文件名：`<repo>_<日期>_<简述>.patch`，例如 `lingbot-vla-v2_2026-10-05_fix-norm-path.patch`

## 应用

```bash
git -C /RoboTwin apply /path/to/patches/xxx.patch
```

## 注意事项

- 官方镜像已包含若干兼容补丁（MPLib 规划、SAPIEN denoiser 关闭、norm 路径修复等），
  这些**不用**我们再打
- 只记录**我们自己**新增的改动
