# 双工程协作与记忆共享指南（THX75 × THXGameKit）

> 读者：并行管理两个项目的作者；分叉/部署本内核的开发者与其 AI 助手。
> 背景：THX75（游戏本体）与 THXGameKit（内核）为双仓协作，AI 助手使用
> 按工程目录分区的持久记忆。本文说明双轨协作、记忆共享与分叉规则。

## 一、双工程版本与同步协议

| 项 | 约定 |
|---|---|
| 版本 | 两工程各自 0.0.x 版本线（当前均 0.0.9）；变更范围清单注明适用范围 |
| 同步铁律 | 内核变更=commit/push GameKit 仓 → th75 `submodule update --remote`（或 `同步THXGameKit内核.bat`）→ **确认 project.godot.standalone 改名在位** → 再测 |
| 变更范围清单 | `THX75/gameAssetBase/aiTest/0.0.9/变更范围清单.md`——每轮标注【THX75 专属／GameKit 下属默认同步／某插件】 |
| 副本维护 | GameKit 独立副本（如 D:/Hyomumoene/game/THXGameKit）pull/stash 后**必查 project.godot 在位+删 .godot/global_script_class_cache.cfg 后 --import 重建**（缓存陈旧=全局类全失效） |

## 二、AI 记忆分区与共享

AI 助手的持久记忆按工程目录分区（各自 MEMORY.md 索引）。双工程并行时：

1. **分叉会话**：在 th75 目录开的会话=THX75 记忆区；THXGameKit 目录开的会话=GameKit 记忆区。两边各自演进，互不污染。
2. **互相访问**：记忆条目用 `[[另一侧条目名]]` 链接标注关联（如 GameKit 侧记 `[[th75-next-steps]]`）。会话开始时 AI 主动读对方索引，需要细节时按链接取。
3. **显式请求**：作者在分叉会话说一句"请同步读 THX75 的记忆索引"，AI 即载入对方 MEMORY.md 要点到上下文。
4. **同步点**（两边会话都要遵守）：
   - 每轮双仓 commit/push（内核变更 GameKit 先推，th75 跟进指针）
   - 版本号对齐声明（当前双 0.0.9）
   - 变更范围清单每轮追加

## 三、分叉规则（日后一个专注 THX75、一个专注 THXGameKit）

- **目录即身份**：分叉任务请在对应工程根目录开新会话——记忆分区天然隔离。
- **内核→宿主单向流**：内核改动只在 GameKit 侧记忆沉淀；宿主玩法（AI/机控/热力图）只在 th75 侧。跨界变更（如 m43 @tool 化影响 th75 编辑器）在**两边记忆各记一条**并互链。
- **新部署者**：克隆两仓后，THXGameKit 独立开发需自建记忆目录（首次会话 AI 自动建立）；THX75 侧已有完整记忆可直接续用。
- **词典先行**：报障/修复报告按 `docs/TERMINOLOGY.md`（消歧义词典）的固定名与模板——双工程通用。

## 四、快速检查单（每轮结束）

- [ ] GameKit 仓 commit+push
- [ ] th75 submodule update+standalone 改名确认+commit+push
- [ ] 变更范围清单追加（含范围标注）
- [ ] 版本工作清单追加（各自工程）
- [ ] 探针回归绿（套件清单见 th75 记忆）
- [ ] 若动过副本：project.godot 在位+类缓存重建
