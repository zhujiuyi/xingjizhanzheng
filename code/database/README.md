# 首轮数值数据库

`catalog_schema.sql` 与 `catalog_seed.sql` 是可审阅的构建输入，运行时数值来源为 `../data/catalog.db`。当前版本与规则集标识存于 `catalog_meta`；这是一份首轮基线，不是完整世界数据库。

从工作区根目录重建与校验：

```sh
# 当前本机 Python；不需要额外依赖
/usr/local/bin/python3.14 jiaoben/build_catalog.py
/usr/local/bin/python3.14 jiaoben/tests/test_balance.py --report
/usr/local/bin/python3.14 jiaoben/tests/test_content.py
```

其他机器需要 Python 3.10+ 与支持 STRICT 的 SQLite 3.37+。报告位于 `jiaoben/logs/数值校验报告.md`。

构建在 `jiaoben/tmp/` 中完成：DDL、种子、约束检查、逻辑摘要属于同一事务；关闭连接后原子替换目标。摘要按注册表/列/主键与稳定顺序编码，对注册 SQL view 的精确定义文本一并哈希；排除摘要自身。增加表、列、类型、主键或 view 必须同步审阅 `jiaoben/build_catalog.py` 中的注册表及冻结迁移。

当前 `v0.3-devready` 包括四舰、十模块、物品/配方、八任务、两个星区地点、NPC行为、门、站点库存及镜头表现。`module_salvage_recipe_defs` 定义采购模块的标准拆解来源，`recycle_outputs` 是标准配方返料预览；制造实例必须保存实际投入。进度正式结构及冻结定义在 [progress](progress/README.md)，catalog 本身不存玩家实例。交易执行、Godot SaveService 与权威模拟待实现。

测试读取实际数据库，Python函数仅用于独立核验参考公式，不应复制为另一套游戏数值源。扩大配方/市场/声望范围后应重新验证递归制造与拆解经济约束。
