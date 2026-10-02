# 数据服务历史夹具

`catalog-b-baseline.db` 是格式1验收时冻结的 v0.3-devready 内容副本：73表、4受审视图，逻辑摘要 `a91984499698ef653026bbfeef36ba22b752d457dd3d880f11098f85ebc2b617`。由当时完整冻结内容恢复，专用于证明历史内容能独立于当前catalog读回和迁移。

正式客户端从 `res://data/catalog.db` 新建世界，不引用本目录。`store_prepare.py` 只核验并复制到tmp，不依赖临时用户档。原生 `store_migration.gd` 用原四份固定迁移和该内容创建真实历史库，再验证升级和故障恢复。
