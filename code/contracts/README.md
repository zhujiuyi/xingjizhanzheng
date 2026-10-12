# 接口与状态类型

- [contract_types.gd](contract_types.gd)：动作、拒绝、保存、加载、跨区与表现协议枚举，显式整数仅供运行期类型使用，SQL 编码稳定字符串名。
- [contract_dtos.gd](contract_dtos.gd)：纯 RefCounted typed DTO；命令 envelope、业务/存读档结果、完整世界快照、87种进度状态行、场景加载/工厂结果和只读界面视图示例。
- [模块接口与验收](../../doc/21-模块接口与开发验收规格.md)：正式端口签名、所有权、SQL 字段映射、状态机与开发验收。

项目根是 `code/`；DTO 用 `res://contracts/contract_types.gd` preload。构造默认值只是占位，不是合法起始游戏数据；所有正式发布对象必须经过业务与存档验证。无 Node/Resource/RID、SQL、游戏循环或平衡常量。NULL 用 `has_` 标记，不以空字符串伪造外键。typed 与枚举不替代入口验证，也不自动冻结数组。

进度 schema 新增列/表时须同步 DTO 与 adapter；完整快照的共同 snapshot/world/content 上下文由顶层 meta 一次注入。纯数据定义可用于后续实施，不表示对应服务已经实现。

后续迁移须同时追加状态行声明、WorldSnapshot数组及RuntimeState注册。`sync_contract_state_dtos.py`只适用于早期核心DDL；检测到扩展状态后会拒绝覆盖，以免删掉历史声明。执行 `python3 jiaoben/tests/test_contract_assets.py` 检查 SQL字段、NULL标记、全部槽与manifest；Godot探针为 [contracts_probe.gd](../../jiaoben/tests/contracts_probe.gd)，从工作区根用本机 Godot 执行 `--headless --path code --script <该脚本绝对路径>`。日志 [contracts-probe.log](../../jiaoben/logs/contracts-probe.log) 记录实际 typed DTO与场景解析/实例化，未验证飞行、UI或存档玩法。
