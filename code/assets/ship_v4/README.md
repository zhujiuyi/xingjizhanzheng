# 原创舰船造型 v4

覆盖18艘目录舰和`enemy_silent`，每艘有独立主轮廓、GLB、Blender源文件及384×384烘焙缩略图。设计参考与逐舰范围见[造型重建记录](../../../doc/70-舰船造型重建.md)。不携带EVE原始模型、贴图或标志。

`jiaoben/art/build_ships_v4.py`在Blender 4.5.14 LTS运行；`ship_v4_common.py`和`ship_v4_civilizations.py`给出19个独立造型，`ship_v4_geometry.py`提供确定性实体、弧壳、桁架和维护板工具。生成过程严格检查原物理包围范围，炮口和发动机来自既有几何/挂点；不会改动旧wrapper或平衡数值。

运行与机库通过`runtime/rendering/ship_v4_factory.gd`和`ship_v4_hangar.gd`接入。统一PBR适配来自`materials_v1`，19张新缩略图由Godot原生渲染器直接生成。`manifest.json`登记实际源文件与运行资源摘要；它本身只证明构建身份，实际验收见正式交付记录。
