# 复制此文件为 config.secret.ps1 并填入你的实例信息
# config.secret.ps1 已被 .gitignore 忽略，不会入库

$Config = @{
    # Radeon Cloud 实例（从 SSH 窗口复制）
    SshHost = "192.0.2.10"
    SshPort = 22
    SshUser = "root"

    # 云端工作目录（放 scripts/cloud 的地方）
    RemoteDir = "~/challenge"

    # 远程运行时目录（评测/训练输出）
    RemoteRuntime = "/workspace/runtime"

    # 本地仓库根目录
    LocalRoot = "D:\LingBot-VLA-Challenge"
}
