# 禁区清单（不可乱动项）——双工程协作红线

> 来源：历轮事故复盘（作者令："总结哪些地方必须要保留不能乱动"）。
> **改动前必读本清单**；触碰禁区项=需作者批准+回归全套。

## 一、project.godot（两仓各自）★最高危★
| 规则 | 事故史 |
|---|---|
| **注释符只准 `;`**——`##`/`#` 会断行解析失败（工程打不开） | m43/m50 两例 |
| **enabled 插件条目必须 `res://` 全路径**——相对路径 addons/... 被编辑器双拼出 res://addons/addons/.../plugin.cfg | m50 plugin.cfg 加载失败 |
| autoload/主场景段任何改动=整工程风险——改后必跑 `--quit-after` 启动验证 | m40/m45 |
| **单行 read-modify-write 禁令**（写空文件两例同源）——一律 read→变量→write 分步+回读 | m43/m46 |

## 二、th75 宿主边界（submodule）
| 规则 | 事故史 |
|---|---|
| **kit/project.godot 在 th75 内必须改名 .standalone**（同步脚本/手动 mv）——否则内核全局类不注册=类全失效 | m34 起反复 |
| **standalone 文件不入库**（git rm --cached 重申） | m40/m47 |
| 副本 pull/stash/checkout 后**三查**：project.godot 在位/standalone 不入库/类缓存重建 | m50 |
| .godot/extension_list.cfg 陈旧项随类缓存一起清 | m46 |

## 三、类命名与全局类
| 规则 | 事故史 |
|---|---|
| **内核与插件不得同名 class_name**（注册竞争抢注）——新类先查重 | m38 PrivateFormation |
| **@tool 内核 preload 禁字面量路径**（挂载点无关）——用类名直引 | m46 |
| **强类型推断链**（`: T :=` 接弱化返回）在编辑器扫描期爆——@tool 链内显式类型 | m46 |
| **autoload 引用（THXKit/GameGlobals）在 @tool 编辑器态不存在**——引用处判空/镜像 | m46 |

## 四、渲染与场景
| 规则 | 事故史 |
|---|---|
| **Window/FileDialog 挂编辑器自身**（不挂 root——change_scene 后永生残留空转烧帧） | m45/m47 |
| **project.godot 的 vsync/low_processor 显式设置保留**（Optimus 双 GPU 空转 14958fps） | m47-48 |
| **GDScript lambda 内变量不得与外层函数域同名**（捕获撞名 parse 错） | m50 dirs |
| **`## 注释禁入 project.godot`**（见一） | m43/m50 |

## 五、流程铁律（作者令 20261114）
1. **SCRIPT ERROR 不当噪声**——任何报错当场追查到清零。
2. **单行文件写禁令**——read→变量→write 分步+回读验证。
3. **双副本双验证**——每轮 KIT+EDT+SMOKE 两侧都跑（th75 副本过≠GameKit 副本过）。
4. **批处理插入禁单行链式**——插入代码分步+括号配对回读。
5. **探针新增文件后 --import 重建**（kit/th75 两仓）。

## 六、改动自检表（PR/commit 前跑一遍）
- [ ] project.godot 注释全是 `;`？enabled 全 res:// 路径？
- [ ] standalone 在位（th75）/不入库（GameKit）？
- [ ] 全局类名无新增冲突？
- [ ] 新 preload/类引用在编辑器扫描期可用？
- [ ] --import + --editor 双遍零 SCRIPT ERROR？
- [ ] KIT/ENT/EDT/SMOKE 双侧绿？
- [ ] SMOKE 的每一条 FAIL 都已追查？
