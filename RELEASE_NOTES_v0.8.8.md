# SakuraMedia v0.8.8

本版本是个人本地媒体库桌面端的受控封板版本，基于 v0.7.7 稳定客户端增加：

- 媒体库只读扫描 Preview，显示 NEW、MOVED、MISSING 与 UNCHANGED 汇总和明细；
- 对稳定 NEW 文件提供人工确认导入入口，原文件保持在原路径；
- MOVED 与 MISSING 在当前版本中仅展示，不自动执行重绑或失效操作；
- 修复长时间扫描请求超时与扫描结果对话框文字可读性；
- 保持现有播放器、媒体库与登录流程兼容。

已验证边界：

- Storage Watcher 仍是唯一的扫描内核；
- Preview 为手动、只读操作；
- 自动发现和自动导入保持关闭；
- 剩余 NEW 文件仍需逐项人工处理；
- 外置盘离线/上线验收因 Docker Desktop 虚拟化进程拒绝普通卸载而记为 `SKIPPED_SAFETY`，不是 PASS；
- 本次发布未启用自动 Import、Rebind、Missing 或 Restore。

发布制品为未公证的 ad-hoc 签名 macOS 通用架构应用；签名和 Gatekeeper 状态以发布清单为准。
