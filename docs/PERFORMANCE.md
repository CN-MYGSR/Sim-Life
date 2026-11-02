# 性能实测与验收（2026-11-02）

Windows x64，AMD FirePro W2100（2 GiB），Godot **4.7.2.stable.official.ed1daf0bf**，
Forward+ / Vulkan 1.2.133。窗口与输出 PNG 为 **1280×720**；项目逻辑视口为 **1600×900**。
固定种子 20261102、相同默认玩家位置、早上 08:00，关闭垂直同步。预热至少 3 秒与
120 帧，采样 600 帧。三组依次串行运行，没有同时运行另一份游戏或自动化测试。

## 4×4 同场景合批对照

| Godot 指标 | 合批前 `fc95af7` | 合批后 `ddb359f` |
| --- | ---: | ---: |
| 平均实际帧间隔 | 75.33 ms | 51.14 ms |
| 等效平均 FPS（1000 / 平均帧间隔） | 13.27 | 19.55 |
| P95 帧间隔 | 152.62 ms | 92.58 ms |
| 物理处理监视器均值 | 7.71 ms | 7.28 ms |
| 末帧 Draw Calls | 6,306 | 1,642 |
| 末帧渲染图元 | 309,426 | 311,598 |
| 节点数 | 6,140 | 2,986 |
| Godot 静态内存 | 208.24 MiB | 125.68 MiB |
| Godot 视频内存监视器 | 353.33 MiB | 355.64 MiB |
| 场景构建时间 | 2.97 s | 2.86 s |

这两组均保持原有 SSAO、阴影、抗锯齿和几何布局。静态家具使用按材质分组的
MultiMesh，保留碰撞；绘制调用下降约 **74%**，静态内存下降约 **40%**，平均帧间隔
下降约 **32%**。视频内存没有下降。图元数量的小幅差异包含移动 NPC 的可见性变化。
Draw Calls、图元、内存、节点为结束时的监视器快照；帧间隔及处理时间是采样均值。

原始记录：[合批前](benchmarks/2026-11-02-before4.json)、[合批后](benchmarks/2026-11-02-after4.json)。

## 6×6 成品场景

最终运行代码为 `4bc3b5a9a689bb62f0769b5c1cdea903b311fe05`。此后收尾修改仅涉及
旧调试截图路径、调试启动的存档隔离、验收截图视角、音频退出等待改按真实时间
（发生于帧采样结束后）和文档。

| 指标 | 最终实测 |
| --- | ---: |
| 平均实际帧间隔 / 等效 FPS | 50.20 ms / 19.92 FPS |
| P50 / P95 帧间隔 | 40.18 / 107.95 ms |
| 物理处理监视器均值 | 8.28 ms |
| 末帧 Draw Calls / 图元 | 2,459 / 471,852 |
| 节点数 | 6,158 |
| 活跃环境 NPC / 总数 | 17 / 36 |
| Godot 静态内存 | 174.93 MiB |
| Godot 视频内存监视器 | 356.60 MiB |
| 场景构建时间 | 5.40 s |

6×6 使用已验证的 W2100 SSAO 兼容配置，其余 Forward+、阴影、抗锯齿保留。
它与 4×4 的地点、NPC 数量和 SSAO 状态不同，不能当作纯合批的等条件对照。
本机仍有明显帧时间波动，**没有达到 60 FPS**，因此扩展止于 6×6。

环境行人的物理休眠对照：加入距离管理前物理均值为 14.67 ms，首轮加入后为
8.91 ms，最终复测为 8.28 ms。160 m 外休眠、140 m 内唤醒，保留实体；任务目标和
限时顾客不参与休眠。夜间窗口/灯光更新、隐藏地图绘制与重复 UI 重建也做了节流。

原始记录：[6×6 休眠前](benchmarks/2026-11-02-city6-before-lod.json)、
[首轮休眠](benchmarks/2026-11-02-city6-lod.json)、[最终复测](benchmarks/2026-11-02-city6-final.json)。
内存为引擎监视器数值，不等于 Windows 整个进程或显卡全部占用。这是单机样本，未做跨硬件性能承诺。

## 复测

```powershell
./tools/test.ps1
./tools/godot.ps1 --windowed --audio-driver Dummy --disable-vsync --scene res://tests/benchmark.tscn -- --seed=20261102 --no-save --output=res://.artifacts/benchmark.json
./tools/godot.ps1 --verbose --windowed --audio-driver Dummy --scene res://tests/visual_smoke.tscn -- --seed=20261102 --no-save
```

需要查看引擎环境设定时可参考 [Godot Sky 文档](https://docs.godotengine.org/en/stable/classes/class_sky.html)。
天空材质变化会更新辐射立方体贴图；项目对小于 0.5% 的昼夜颜色变化去重，保留太阳运动。
