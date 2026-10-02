# Unity 技术栈备选方案

记录日期：2026-10-02。状态：用户要求保留的历史备选方案；当前正式路线已确定为 [Godot](05-技术栈与空间玩法建议.md)，本方案未实施。

## 用户要求与安装授权

- 《星际战舰》比较的目标是 3D 游戏，最终以 macOS `.app` 与 Windows `.exe` 独立客户端运行。
- 保留 Unity 路线，优先使用符合资格的免费开发工具，不依赖额外付费的 Scenario 云素材生成服务。
- 用户已授权：后续需要时，由助手按相关文档完成开发环境和配套软件的安装。路线确定后，常规必要软件安装不重复请求确认；当前选型阶段先不安装 Unity。
- 软件安装授权不等于选择付费订阅或购买素材。账号登录、系统认证若必须由用户操作，再说明实际需要。

## 技术组成

建议采用 Unity Editor + C#。安装时从 Unity Hub 选择当前受支持的 LTS 及其 Apple Silicon 版本，记录实际 Editor 版本与项目依赖，不预先固定未知补丁号。

| 软件或组件 | 用途 | 安装时机 |
| --- | --- | --- |
| Unity Hub | 管理 Editor、模块、项目及许可 | Unity 路线确定后安装 |
| Unity Editor（LTS，Apple Silicon） | 编辑、运行、调试、构建 3D 游戏 | 必需 |
| Unity ID / Personal 激活 | 使用符合资格的免费许可 | 按 Hub 提示完成 |
| macOS / Windows Build Support | 构建目标桌面客户端 | 按目标平台及构建后端补齐 |
| Xcode / Command Line Tools / Rosetta 2 | 满足所选 Editor 与构建工具的 macOS 要求 | 先检查现有环境，再按对应版本官方要求补齐 |
| C# 编辑器、独立 .NET SDK | 专用编辑、调试或外部工具支持 | 仅在所选工作流需要时安装 |
| Blender | 制作、修改和导出 3D 模型 | 模型工作流需要时安装 |

## 素材路线

- 原画、图标、背景和贴图：使用本会话图片生成工具，消耗现有 Codex 使用额度；不额外采购 Scenario 服务，不声称无限免费。
- 3D 战舰、空间站、陨石：原型先采用 Unity 程序化网格或 Blender 脚本；复杂模型按建模、材质和导入流程打磨。
- 音效：原型可程序合成炮击、引擎、爆炸等简单音效。复杂配乐与配音另行选择来源和工具，不假定当前已有一键生成工具。
- Scenario 的本地 Unity / Blender 专家技能可按需要选用，使用前检查其实际工具依赖。云生成与本地工具技能分别评估。

## 安装与验收顺序

1. 按 [本机操作参考](/Users/a0000/.codex/本机操作参考.md) 核验已安装工具、磁盘和对应版本的系统要求。
2. 从官方渠道安装 Hub、Editor 与实际需要的平台模块；完成账号和免费许可激活。
3. 在 `code/` 创建最小 3D 工程；测试、环境检查与临时安装文件放 `jiaoben/`。
4. 验证 C# 编译、场景启动、模型与材质导入、基础音频。
5. 验证 macOS 桌面构建；按所选后端安排 Windows 构建环境及实际运行检查。不能把产出 `.exe` 文件视为 Windows 已运行通过。
6. 将实际安装版本、启动与构建命令、验证结果补入 [开发环境](02-开发环境.md)。

## 费用与交付边界

Unity Personal 当前允许符合资格的免费商业开发。官方页面的资格门槛涉及最近 12 个月收入及融资低于 20 万美元，具体适用主体和条件以采用时的条款为准。免费引擎不代表所有付费资源、服务和发行环节免费。

macOS `.app` 是应用包；Windows 客户端可能包含 `.exe`、资源和动态库目录，不预设最终必须只有一个文件。公开分发所需签名、公证与本地原型验证分开安排。

## 官方依据

- [Unity Personal 与资格](https://unity.com/products/unity-personal)
- [Unity Hub 安装](https://docs.unity.com/en-us/hub/install-hub-win-mac)
- [通过 Hub 安装 Editor](https://docs.unity.com/en-us/hub/add-editor)
- [Unity 6.3 系统要求（安装时复核目标版本）](https://docs.unity.com/en-us/engine/6000.3/manual/get-started/install-and-upgrade/getting-started-installing-unity/system-requirements)
- [Scenario 本地与云端技能](https://github.com/scenario-labs/skills/blob/main/INSTALL.md)
- [Scenario 免费范围](https://www.scenario.com/pricing)
- [Codex 图片生成与额度](https://learn.chatgpt.com/docs/image-generation)
