# Month 38: vcpkg包管理器——微软开源的跨平台依赖管理

## 本月主题概述

本月深入学习vcpkg，这是微软开源的C/C++包管理器。vcpkg支持Windows、Linux和macOS，能够自动下载、编译和安装第三方库。学习如何将vcpkg集成到项目中，管理依赖版本，以及创建自定义的port。

**学习目标**：
- 掌握vcpkg的安装、配置和基本使用
- 理解manifest模式和classic模式的区别
- 学会创建自定义port发布自己的库
- 实现vcpkg与CMake的无缝集成

---

## 理论学习内容

### 第一周：vcpkg基础入门（35小时）

```
┌─────────────────────────────────────────────────────────────────┐
│  Week 1: vcpkg 基础入门                                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Day 1-2: vcpkg安装与核心架构                                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │ Port树   │→│ 构建树    │→│ 已安装树  │→│ 包信息   │       │
│  │ports/    │  │buildtrees│  │installed/ │  │packages/ │       │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘       │
│                                                                 │
│  Day 3-4: Triplet系统与平台管理                                  │
│  ┌─────────────────────────────────────────────────────┐       │
│  │  Triplet = <架构>-<系统>[-<链接方式>]                  │       │
│  │  x64-linux / x64-windows-static / arm64-osx          │       │
│  │  内置triplet / 社区triplet / 自定义triplet            │       │
│  └─────────────────────────────────────────────────────┘       │
│                                                                 │
│  Day 5-7: Classic模式与命令行工具                                │
│  ┌─────────────────────────────────────────────────────┐       │
│  │  vcpkg search → install → list → remove → upgrade   │       │
│  │  vcpkg integrate → export → env                      │       │
│  │  依赖解析 → 版本选择 → 构建执行 → 安装验证            │       │
│  └─────────────────────────────────────────────────────┘       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### 每日任务分解

| Day | 时间 | 上午任务(2.5h) | 下午任务(2.5h) | 输出物 |
|-----|------|---------------|---------------|--------|
| 1 | 5h | vcpkg安装与bootstrap原理 | 核心目录结构分析(ports/buildtrees/installed) | notes/vcpkg_setup.md |
| 2 | 5h | vcpkg内部工作流程(下载→配置→构建→安装) | 阅读vcpkg-tool源码入口 | notes/vcpkg_internals.md |
| 3 | 5h | Triplet系统详解(内置/社区/自定义) | 自定义triplet编写实践 | custom-triplets/x64-linux-custom.cmake |
| 4 | 5h | 平台检测与条件编译在triplet中的应用 | 交叉编译triplet(ARM/WASM) | notes/triplet_deep_dive.md |
| 5 | 5h | Classic模式基本命令(search/install/remove) | 依赖解析算法与版本选择策略 | notes/classic_mode.md |
| 6 | 5h | vcpkg integrate命令与IDE集成 | 阅读ports/fmt和ports/spdlog源码 | notes/vcpkg_ide_integration.md |
| 7 | 5h | vcpkg环境变量完整参考 | Week 1知识总结与实践验证 | notes/week1_summary.md |

**学习目标**：安装vcpkg并理解基本概念

**阅读材料**：
- [ ] vcpkg官方文档 (vcpkg.io/en/getting-started)
- [ ] Microsoft Learn: vcpkg入门教程
- [ ] vcpkg GitHub仓库README
- [ ] vcpkg-tool源码：`src/vcpkg/install.cpp`（安装流程）
- [ ] vcpkg-tool源码：`src/vcpkg/triplet.cpp`（triplet解析）

**核心概念**：

#### vcpkg架构原理

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        vcpkg 核心架构                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────┐                                                │
│  │    vcpkg-tool        │ ← C++编写的核心工具（命令行前端）              │
│  │  (vcpkg executable)  │                                                │
│  └──────────┬──────────┘                                                │
│             │                                                            │
│  ┌──────────▼──────────────────────────────────────────────────────┐    │
│  │                     vcpkg 仓库目录结构                           │    │
│  │                                                                  │    │
│  │  ports/                    ← Port树（包定义仓库）                │    │
│  │  ├── fmt/                  ← 每个包一个目录                      │    │
│  │  │   ├── portfile.cmake    ← 构建脚本（下载/配置/构建/安装）     │    │
│  │  │   └── vcpkg.json        ← 包元数据（版本/依赖/描述）         │    │
│  │  ├── spdlog/                                                     │    │
│  │  └── boost-asio/                                                 │    │
│  │                                                                  │    │
│  │  buildtrees/               ← 构建树（临时构建目录）              │    │
│  │  ├── fmt/                  ← 源码下载+CMake构建                  │    │
│  │  │   ├── src/              ← 解压后的源码                        │    │
│  │  │   └── x64-linux-dbg/    ← 构建产物目录                       │    │
│  │  └── detect_compiler/                                            │    │
│  │                                                                  │    │
│  │  packages/                 ← 打包树（安装暂存区）                │    │
│  │  └── fmt_x64-linux/        ← 单包安装结果                       │    │
│  │      ├── include/                                                │    │
│  │      ├── lib/                                                    │    │
│  │      └── share/                                                  │    │
│  │                                                                  │    │
│  │  installed/                ← 已安装树（最终安装位置）             │    │
│  │  ├── x64-linux/            ← 按triplet分组                      │    │
│  │  │   ├── include/          ← 头文件                              │    │
│  │  │   ├── lib/              ← 库文件                              │    │
│  │  │   ├── share/            ← CMake config文件                    │    │
│  │  │   └── tools/            ← 工具可执行文件                      │    │
│  │  └── vcpkg/                                                      │    │
│  │      └── status             ← 安装状态数据库                     │    │
│  │                                                                  │    │
│  │  downloads/                ← 下载缓存                            │    │
│  │  scripts/                  ← CMake辅助脚本                       │    │
│  │  triplets/                 ← Triplet定义文件                     │    │
│  │  └── community/            ← 社区triplet                        │    │
│  └──────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
```

#### vcpkg安装流程详解

```
┌─────────────────────────────────────────────────────────────────────────┐
│                  vcpkg install <package> 完整流程                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  1. 解析阶段                                                            │
│  ┌────────────────────────────────────────────────────────────┐        │
│  │  vcpkg install fmt:x64-linux                               │        │
│  │         │                                                   │        │
│  │         ├─→ 解析包名: fmt                                   │        │
│  │         ├─→ 解析triplet: x64-linux                         │        │
│  │         └─→ 读取 ports/fmt/vcpkg.json                      │        │
│  │              └─→ 递归解析所有依赖                            │        │
│  └────────────────────────────────────────────────────────────┘        │
│                         │                                               │
│  2. 依赖解析            ▼                                               │
│  ┌────────────────────────────────────────────────────────────┐        │
│  │  构建安装计划（拓扑排序）                                    │        │
│  │                                                             │        │
│  │  fmt → 无依赖 → 直接构建                                    │        │
│  │  spdlog → 依赖fmt → 先构建fmt                               │        │
│  │  boost-asio → 依赖boost-system → 递归解析                   │        │
│  │                                                             │        │
│  │  检查已安装状态 → 跳过已满足的依赖                           │        │
│  └────────────────────────────────────────────────────────────┘        │
│                         │                                               │
│  3. 下载阶段            ▼                                               │
│  ┌────────────────────────────────────────────────────────────┐        │
│  │  执行 portfile.cmake 中的下载命令                           │        │
│  │                                                             │        │
│  │  vcpkg_from_github()                                        │        │
│  │    └─→ 下载 tar.gz → downloads/ (有缓存则跳过)              │        │
│  │    └─→ 验证 SHA512                                          │        │
│  │    └─→ 解压到 buildtrees/<port>/src/                        │        │
│  └────────────────────────────────────────────────────────────┘        │
│                         │                                               │
│  4. 配置+构建阶段       ▼                                               │
│  ┌────────────────────────────────────────────────────────────┐        │
│  │  vcpkg_cmake_configure()                                    │        │
│  │    └─→ cmake -S src -B buildtrees/<port>/x64-linux-rel     │        │
│  │    └─→ 注入triplet变量(CXX_FLAGS, LINK_FLAGS等)            │        │
│  │                                                             │        │
│  │  vcpkg_cmake_build()                                        │        │
│  │    └─→ cmake --build . (Release + Debug)                    │        │
│  └────────────────────────────────────────────────────────────┘        │
│                         │                                               │
│  5. 安装阶段            ▼                                               │
│  ┌────────────────────────────────────────────────────────────┐        │
│  │  vcpkg_cmake_install()                                      │        │
│  │    └─→ cmake --install → packages/<port>_<triplet>/         │        │
│  │                                                             │        │
│  │  vcpkg_cmake_config_fixup()                                 │        │
│  │    └─→ 修正CMake config路径                                  │        │
│  │                                                             │        │
│  │  合并到 installed/<triplet>/                                 │        │
│  │    └─→ include/ + lib/ + share/ + tools/                    │        │
│  │                                                             │        │
│  │  更新 installed/vcpkg/status                                │        │
│  └────────────────────────────────────────────────────────────┘        │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

```bash
# ==========================================
# vcpkg安装（跨平台）
# ==========================================

# 克隆仓库
git clone https://github.com/microsoft/vcpkg.git
cd vcpkg

# Linux/macOS
./bootstrap-vcpkg.sh

# Windows
.\bootstrap-vcpkg.bat

# 设置环境变量（推荐）
export VCPKG_ROOT=/path/to/vcpkg
export PATH=$VCPKG_ROOT:$PATH

# ==========================================
# 基本命令
# ==========================================

# 搜索包
vcpkg search json
vcpkg search boost

# 安装包（Classic模式）
vcpkg install fmt
vcpkg install spdlog
vcpkg install boost-asio

# 指定triplet（目标平台）
vcpkg install fmt:x64-windows
vcpkg install fmt:x64-linux
vcpkg install fmt:x64-osx
vcpkg install fmt:arm64-osx

# 查看已安装包
vcpkg list

# 移除包
vcpkg remove fmt

# 更新vcpkg自身
git pull
./bootstrap-vcpkg.sh

# 更新所有包
vcpkg upgrade --no-dry-run
```

**Triplet详解**：

```bash
# ==========================================
# Triplet = 架构-系统-链接方式
# ==========================================

# 常用triplet
# x64-windows        - Windows 64位 动态链接
# x64-windows-static - Windows 64位 静态链接
# x86-windows        - Windows 32位 动态链接
# x64-linux          - Linux 64位
# x64-osx            - macOS x64
# arm64-osx          - macOS Apple Silicon
# arm64-linux        - Linux ARM64

# 查看所有可用triplet
vcpkg help triplet

# 自定义triplet文件
# triplets/x64-linux-custom.cmake
set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)  # 静态库
set(VCPKG_CMAKE_SYSTEM_NAME Linux)

# C++标准
set(VCPKG_CXX_FLAGS "-std=c++17")
set(VCPKG_C_FLAGS "")

# 编译器设置
set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "/path/to/toolchain.cmake")
```

#### Triplet系统深入分析

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      Triplet 层级体系                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  内置Triplet（官方维护，稳定性保证）                                     │
│  ┌───────────────────────────────────────────────────────────────┐      │
│  │  x64-windows          x64-windows-static     x86-windows     │      │
│  │  x64-linux            x64-osx                arm64-osx       │      │
│  │  arm64-windows        arm-linux               arm64-linux     │      │
│  └───────────────────────────────────────────────────────────────┘      │
│                         │                                               │
│  社区Triplet（社区贡献，best-effort支持）                                │
│  ┌───────────────────────────────────────────────────────────────┐      │
│  │  x64-linux-dynamic    x64-windows-static-md   x64-mingw-*    │      │
│  │  arm-neon-android     x64-freebsd             wasm32-emscripten│     │
│  │  x64-ios              arm64-ios               ppc64le-linux   │      │
│  └───────────────────────────────────────────────────────────────┘      │
│                         │                                               │
│  自定义Triplet（项目级覆盖）                                             │
│  ┌───────────────────────────────────────────────────────────────┐      │
│  │  ./custom-triplets/x64-linux-asan.cmake                       │      │
│  │  ./custom-triplets/x64-linux-tsan.cmake                       │      │
│  │  ./custom-triplets/arm64-embedded.cmake                       │      │
│  └───────────────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────────────┘
```

```cmake
# ==========================================
# 高级自定义Triplet示例
# ==========================================

# --- x64-linux-asan.cmake ---
# 用于Address Sanitizer测试的triplet
set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE dynamic)
set(VCPKG_CMAKE_SYSTEM_NAME Linux)

# 注入ASan编译选项
set(VCPKG_CXX_FLAGS "-fsanitize=address -fno-omit-frame-pointer -g")
set(VCPKG_C_FLAGS "-fsanitize=address -fno-omit-frame-pointer -g")
set(VCPKG_LINKER_FLAGS "-fsanitize=address")

# --- arm64-embedded.cmake ---
# 嵌入式ARM交叉编译triplet
set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE static)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_CMAKE_SYSTEM_NAME Linux)

# 使用交叉编译工具链
set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE
    "${CMAKE_CURRENT_LIST_DIR}/../toolchains/arm64-linux-gnu.cmake")

# 禁用不适合嵌入式的特性
set(VCPKG_CMAKE_CONFIGURE_OPTIONS "-DBUILD_SHARED_LIBS=OFF")

# --- wasm32-emscripten.cmake ---
# WebAssembly编译triplet
set(VCPKG_TARGET_ARCHITECTURE wasm32)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_CMAKE_SYSTEM_NAME Emscripten)

set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE
    "$ENV{EMSDK}/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake")
```

#### vcpkg环境变量完整参考

```bash
# ==========================================
# vcpkg 环境变量参考
# ==========================================

# === 核心路径 ===
export VCPKG_ROOT=/path/to/vcpkg              # vcpkg根目录
export VCPKG_DOWNLOADS=/path/to/downloads     # 下载缓存目录（共享节省磁盘）
export VCPKG_DEFAULT_TRIPLET=x64-linux        # 默认triplet（省略:triplet时使用）
export VCPKG_DEFAULT_HOST_TRIPLET=x64-linux   # 默认host triplet（工具编译用）

# === 二进制缓存 ===
export VCPKG_BINARY_SOURCES="clear;files,/cache,readwrite"  # 二进制缓存源
export VCPKG_KEEP_ENV_VARS="MY_TOKEN;MY_KEY"  # 传递到构建环境的环境变量

# === 构建控制 ===
export VCPKG_MAX_CONCURRENCY=8                # 最大并行构建数
export VCPKG_FORCE_SYSTEM_BINARIES=1          # 使用系统cmake/ninja（非下载）
export VCPKG_DISABLE_METRICS=1                # 禁用遥测数据

# === 资产缓存 ===
export X_VCPKG_ASSET_SOURCES="x-azurl,https://mirror/;x-block-origin"

# === 调试 ===
export VCPKG_VISUAL_STUDIO_PATH="..."         # 指定VS安装路径(Windows)
export VCPKG_OVERLAY_PORTS=/path/to/overlay    # Overlay ports路径
export VCPKG_OVERLAY_TRIPLETS=/path/to/triplets # Overlay triplets路径
```

#### Classic模式深入——依赖解析与安装管理

```bash
# ==========================================
# Classic模式高级用法
# ==========================================

# 安装带Features的包
vcpkg install curl[ssl,http2]           # 启用ssl和http2 feature
vcpkg install opencv[contrib,ffmpeg]    # OpenCV带contrib模块

# 查看包的可用features
vcpkg search opencv
# opencv4           4.8.0    computer vision library
# opencv4[contrib]           opencv_contrib modules
# opencv4[cuda]              CUDA support
# opencv4[ffmpeg]            FFmpeg support

# 导出已安装的包（用于离线分发）
vcpkg export fmt spdlog --zip           # 导出为zip
vcpkg export fmt spdlog --nuget         # 导出为NuGet包
vcpkg export fmt spdlog --raw           # 导出原始文件

# 查看依赖树
vcpkg depend-info spdlog
# spdlog[core]:x64-linux -> fmt[core]:x64-linux

# IDE集成命令
vcpkg integrate install                 # 全局集成(VS/MSBuild自动发现)
vcpkg integrate remove                  # 移除全局集成
vcpkg integrate project                 # 生成项目级NuGet包(VS)

# 查看包安装详情
vcpkg list --x-full-desc               # 完整描述
vcpkg owns fmt/format.h                 # 查找文件属于哪个包

# 编辑port（调试用）
vcpkg edit fmt                          # 用$EDITOR打开portfile
```

#### Week 1 输出物清单

| 编号 | 输出物 | 说明 | 检验方式 |
|------|--------|------|----------|
| 1 | notes/vcpkg_setup.md | vcpkg安装与配置笔记 | 文档完整性 |
| 2 | notes/vcpkg_internals.md | vcpkg内部架构分析 | 包含目录结构图 |
| 3 | notes/triplet_deep_dive.md | Triplet系统深入分析 | 包含3种自定义triplet |
| 4 | custom-triplets/*.cmake | 自定义triplet文件 | vcpkg install可用 |
| 5 | notes/classic_mode.md | Classic模式使用笔记 | 包含命令速查表 |
| 6 | notes/vcpkg_ide_integration.md | IDE集成配置指南 | 实际IDE可用 |
| 7 | notes/week1_summary.md | Week 1知识总结 | 覆盖所有知识点 |

#### Week 1 检验标准

- [ ] 能独立从零安装vcpkg并配置环境变量
- [ ] 能画出vcpkg的核心目录结构图（ports/buildtrees/packages/installed）
- [ ] 能解释vcpkg install的完整流程（5个阶段）
- [ ] 能编写自定义triplet（至少3种：ASan/嵌入式/WASM）
- [ ] 能使用Classic模式安装、查询、删除包
- [ ] 能使用vcpkg integrate完成IDE集成
- [ ] 能使用vcpkg depend-info分析依赖树
- [ ] 能解释downloads/packages/installed三个缓存目录的区别
- [ ] 能列举至少5个vcpkg环境变量及其作用

---

### 第二周：Manifest模式与项目集成（35小时）

```
┌─────────────────────────────────────────────────────────────────┐
│  Week 2: Manifest模式与项目集成                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Day 8-9: vcpkg.json依赖声明                                    │
│  ┌──────────────────────────────────────────────────┐           │
│  │  vcpkg.json                                       │           │
│  │  ┌─────────┐ ┌──────────┐ ┌──────────┐          │           │
│  │  │基本依赖  │ │版本约束   │ │Feature   │          │           │
│  │  │"fmt"    │ │version>= │ │"tests":  │          │           │
│  │  │"spdlog" │ │overrides │ │ "gtest"  │          │           │
│  │  └─────────┘ └──────────┘ └──────────┘          │           │
│  └──────────────────────────────────────────────────┘           │
│                                                                 │
│  Day 10-11: vcpkg-configuration.json与Registry                  │
│  ┌──────────────────────────────────────────────────┐           │
│  │  default-registry ──→ Microsoft官方仓库           │           │
│  │  registries[]     ──→ 私有/第三方仓库             │           │
│  │  overlay-ports    ──→ 本地port覆盖                │           │
│  │  overlay-triplets ──→ 本地triplet覆盖             │           │
│  └──────────────────────────────────────────────────┘           │
│                                                                 │
│  Day 12-14: CMake工具链集成原理与实践                             │
│  ┌──────────────────────────────────────────────────┐           │
│  │  CMAKE_TOOLCHAIN_FILE → vcpkg.cmake               │           │
│  │    → 自动安装manifest依赖                          │           │
│  │    → 注入find_package搜索路径                      │           │
│  │    → 设置triplet相关变量                           │           │
│  └──────────────────────────────────────────────────┘           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### 每日任务分解

| Day | 时间 | 上午任务(2.5h) | 下午任务(2.5h) | 输出物 |
|-----|------|---------------|---------------|--------|
| 8 | 5h | vcpkg.json完整字段参考学习 | Manifest模式vs Classic模式对比分析 | notes/manifest_mode.md |
| 9 | 5h | 版本约束机制(baseline/overrides/version>=) | Feature依赖系统(default-features/条件依赖) | notes/version_constraints.md |
| 10 | 5h | vcpkg-configuration.json详解 | Registry系统（default/git/filesystem） | notes/vcpkg_configuration.md |
| 11 | 5h | overlay-ports和overlay-triplets机制 | 多项目共享overlay实践 | overlay-ports/example/ |
| 12 | 5h | CMake工具链集成原理(vcpkg.cmake分析) | find_package在vcpkg中的工作方式 | notes/cmake_integration.md |
| 13 | 5h | 实践：创建Manifest模式项目 | 添加多种依赖并测试构建 | practice/manifest_project/ |
| 14 | 5h | 阅读vcpkg.cmake工具链源码 | Week 2知识总结 | notes/week2_summary.md |

**学习目标**：使用vcpkg.json管理项目依赖

**阅读材料**：
- [ ] vcpkg文档：Manifest Mode
- [ ] vcpkg.json规范
- [ ] vcpkg文档：Versioning
- [ ] vcpkg文档：Registries
- [ ] vcpkg源码：`scripts/buildsystems/vcpkg.cmake`（工具链文件）

#### Manifest模式 vs Classic模式对比

```
┌─────────────────────────────────────────────────────────────────────────┐
│               Manifest模式 vs Classic模式 对比                           │
├──────────────────────────────┬──────────────────────────────────────────┤
│       Classic模式            │         Manifest模式（推荐）              │
├──────────────────────────────┼──────────────────────────────────────────┤
│ 全局安装到vcpkg/installed/   │ 项目级安装到build/vcpkg_installed/       │
│ 手动vcpkg install命令        │ CMake配置时自动安装                      │
│ 无版本锁定                   │ builtin-baseline锁定版本                 │
│ 所有项目共享同一份库          │ 每个项目独立的依赖树                     │
│ 无法声明features             │ 支持features条件依赖                     │
│ 适合快速原型/个人实验         │ 适合团队协作/生产项目                    │
│ 无法提交到版本控制            │ vcpkg.json可提交到git                    │
│ 依赖不可重现                 │ 依赖完全可重现                           │
├──────────────────────────────┴──────────────────────────────────────────┤
│                                                                         │
│  Classic:  vcpkg install fmt → installed/x64-linux/ (全局)              │
│                                                                         │
│  Manifest: cmake -B build → build/vcpkg_installed/x64-linux/ (项目级)  │
│            └─→ 自动读取vcpkg.json                                       │
│            └─→ 自动安装所有声明的依赖                                    │
│            └─→ 自动传递给find_package                                    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### vcpkg.json完整字段参考

```json
// ==========================================
// vcpkg.json 完整字段说明
// ==========================================
{
  // === 基本信息 ===
  "name": "my-application",          // 包名（小写字母、数字、连字符）
  "version-string": "1.0.0",         // 版本（自由格式字符串）
  // 或使用语义化版本：
  // "version": "1.2.3",             // 语义化版本 (semver)
  // "version-semver": "1.2.3",      // 严格semver
  // "version-date": "2024-01-15",   // 日期版本
  "port-version": 0,                 // port修订号（修复port本身的bug时递增）
  "description": "Project description",
  "homepage": "https://github.com/user/project",
  "documentation": "https://docs.example.com",
  "license": "MIT",
  "supports": "!uwp & !arm",         // 平台支持表达式

  // === 依赖声明 ===
  "dependencies": [
    "fmt",                            // 简单依赖（任意版本）
    {
      "name": "boost-asio",
      "version>=": "1.81.0"          // 最低版本约束
    },
    {
      "name": "openssl",
      "platform": "!windows"          // 平台条件（仅非Windows）
    },
    {
      "name": "catch2",
      "host": true                    // host依赖（构建工具，非目标库）
    },
    {
      "name": "curl",
      "default-features": false,      // 禁用默认features
      "features": ["ssl", "http2"]    // 显式启用features
    }
  ],

  // === 版本控制 ===
  "builtin-baseline": "a34c873...",   // 锁定所有包的基线版本
  "overrides": [                      // 强制覆盖特定包版本
    {
      "name": "fmt",
      "version": "9.1.0"
    }
  ],

  // === Features系统 ===
  "features": {
    "tests": {
      "description": "Build tests",
      "supports": "!uwp",
      "dependencies": ["gtest"]
    },
    "benchmarks": {
      "description": "Build benchmarks",
      "dependencies": ["benchmark"]
    },
    "ssl": {
      "description": "Enable SSL support",
      "dependencies": [
        {
          "name": "openssl",
          "version>=": "3.0.0"
        }
      ]
    }
  },
  "default-features": ["ssl"]         // 默认启用的features
}
```

```json
// ==========================================
// vcpkg.json - 项目依赖清单
// ==========================================
{
  "name": "my-application",
  "version-string": "1.0.0",
  "description": "My awesome C++ application",
  "homepage": "https://github.com/user/my-application",
  "license": "MIT",
  "supports": "!uwp",
  "dependencies": [
    "fmt",
    "spdlog",
    {
      "name": "boost-asio",
      "version>=": "1.81.0"
    },
    {
      "name": "openssl",
      "platform": "!windows"
    },
    {
      "name": "catch2",
      "host": true
    }
  ],
  "builtin-baseline": "a34c873a9717a888f58dc05268dea15592c2f0ff",
  "overrides": [
    {
      "name": "fmt",
      "version": "9.1.0"
    }
  ],
  "features": {
    "tests": {
      "description": "Build tests",
      "dependencies": [
        "gtest"
      ]
    },
    "benchmarks": {
      "description": "Build benchmarks",
      "dependencies": [
        "benchmark"
      ]
    }
  },
  "default-features": []
}
```

```json
// ==========================================
// vcpkg-configuration.json - 高级配置
// ==========================================
{
  "default-registry": {
    "kind": "git",
    "repository": "https://github.com/microsoft/vcpkg",
    "baseline": "a34c873a9717a888f58dc05268dea15592c2f0ff"
  },
  "registries": [
    {
      "kind": "git",
      "repository": "https://github.com/mycompany/vcpkg-registry",
      "baseline": "abc123...",
      "packages": ["my-internal-lib", "another-lib"]
    }
  ],
  "overlay-ports": ["./custom-ports"],
  "overlay-triplets": ["./custom-triplets"]
}
```

#### Registry系统详解

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     vcpkg Registry 系统                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────────┐                                                   │
│  │  default-registry │ ← 处理所有未被其他registry声明的包               │
│  │  (Microsoft官方)  │    通常指向 github.com/microsoft/vcpkg            │
│  └────────┬─────────┘                                                   │
│           │                                                              │
│  ┌────────▼─────────┐  ┌───────────────────┐  ┌──────────────────┐     │
│  │ Git Registry      │  │ Filesystem Registry│  │ overlay-ports    │     │
│  │ (远程git仓库)     │  │ (本地文件系统)     │  │ (最高优先级覆盖) │     │
│  │                   │  │                    │  │                  │     │
│  │ packages:         │  │ path: /local/reg   │  │ path: ./ports    │     │
│  │  - "my-lib"       │  │ packages:          │  │ 直接覆盖同名port │     │
│  │  - "internal-lib" │  │  - "legacy-lib"    │  │                  │     │
│  └───────────────────┘  └────────────────────┘  └──────────────────┘     │
│                                                                         │
│  解析优先级: overlay-ports > registries[] > default-registry             │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

```json
// ==========================================
// vcpkg-configuration.json - 完整Registry配置示例
// ==========================================
{
  "default-registry": {
    "kind": "git",
    "repository": "https://github.com/microsoft/vcpkg",
    "baseline": "a34c873a9717a888f58dc05268dea15592c2f0ff"
  },
  "registries": [
    {
      // Git Registry: 公司内部私有库
      "kind": "git",
      "repository": "https://github.com/mycompany/vcpkg-registry",
      "baseline": "abc123def456...",
      "packages": ["internal-rpc", "internal-logging", "internal-config"]
    },
    {
      // Filesystem Registry: 本地开发中的库
      "kind": "filesystem",
      "path": "/home/dev/local-registry",
      "packages": ["dev-utils", "test-helpers"]
    }
  ],
  "overlay-ports": [
    "./custom-ports"         // 项目级port覆盖（最高优先级）
  ],
  "overlay-triplets": [
    "./custom-triplets"      // 项目级triplet覆盖
  ]
}
```

#### Overlay Ports机制——本地覆盖已有Port

```bash
# ==========================================
# Overlay Ports使用场景
# ==========================================

# 场景1：修复上游bug，等待合并前使用本地补丁版本
# 场景2：使用特定版本/配置的包
# 场景3：添加vcpkg官方仓库中没有的包

# 项目结构：
# my-project/
# ├── vcpkg.json
# ├── vcpkg-configuration.json  (overlay-ports: ["./custom-ports"])
# ├── custom-ports/
# │   └── fmt/                   ← 覆盖官方的fmt port
# │       ├── portfile.cmake     ← 自定义构建脚本
# │       └── vcpkg.json         ← 自定义元数据
# └── CMakeLists.txt

# 也可以通过命令行指定overlay：
vcpkg install --overlay-ports=./custom-ports
cmake -B build -DVCPKG_OVERLAY_PORTS=./custom-ports
```

#### CMake工具链集成原理

```
┌─────────────────────────────────────────────────────────────────────────┐
│           vcpkg.cmake 工具链文件工作原理                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  cmake -B build -DCMAKE_TOOLCHAIN_FILE=vcpkg/scripts/buildsystems/     │
│                                        vcpkg.cmake                      │
│                                                                         │
│  vcpkg.cmake 做了什么？                                                  │
│  ┌──────────────────────────────────────────────────────────────┐       │
│  │                                                              │       │
│  │  1. 检测Manifest模式                                         │       │
│  │     └─ 如果存在vcpkg.json → 自动运行vcpkg install            │       │
│  │        └─ 安装到 ${CMAKE_BINARY_DIR}/vcpkg_installed/        │       │
│  │                                                              │       │
│  │  2. 设置搜索路径                                              │       │
│  │     └─ CMAKE_PREFIX_PATH += vcpkg_installed/<triplet>/       │       │
│  │     └─ CMAKE_LIBRARY_PATH += vcpkg_installed/<triplet>/lib   │       │
│  │     └─ CMAKE_INCLUDE_PATH += vcpkg_installed/<triplet>/include│      │
│  │                                                              │       │
│  │  3. 处理find_package                                         │       │
│  │     └─ 拦截find_package调用                                   │       │
│  │     └─ 优先从vcpkg_installed/搜索                             │       │
│  │     └─ 支持CONFIG和MODULE两种模式                             │       │
│  │                                                              │       │
│  │  4. 设置triplet变量                                           │       │
│  │     └─ VCPKG_TARGET_TRIPLET                                   │       │
│  │     └─ VCPKG_HOST_TRIPLET                                     │       │
│  │     └─ VCPKG_INSTALLED_DIR                                    │       │
│  │                                                              │       │
│  │  5. 链接工具链(如果有VCPKG_CHAINLOAD_TOOLCHAIN_FILE)          │       │
│  │     └─ 先加载vcpkg工具链                                      │       │
│  │     └─ 再加载用户指定的工具链                                  │       │
│  │                                                              │       │
│  └──────────────────────────────────────────────────────────────┘       │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

**CMake集成**：

```cmake
# ==========================================
# CMakeLists.txt - vcpkg集成
# ==========================================
cmake_minimum_required(VERSION 3.16)

# 方法1：通过CMake命令行设置toolchain
# cmake -B build -S . -DCMAKE_TOOLCHAIN_FILE=$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake

# 方法2：在CMakeLists.txt中设置（需在project之前）
if(DEFINED ENV{VCPKG_ROOT})
    set(CMAKE_TOOLCHAIN_FILE "$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake"
        CACHE STRING "Vcpkg toolchain file")
endif()

project(MyApplication VERSION 1.0.0 LANGUAGES CXX)

# vcpkg manifest模式会自动安装vcpkg.json中的依赖
# 然后可以正常使用find_package

find_package(fmt CONFIG REQUIRED)
find_package(spdlog CONFIG REQUIRED)
find_package(Boost REQUIRED COMPONENTS system asio)

add_executable(myapp main.cpp)

target_link_libraries(myapp
    PRIVATE
        fmt::fmt
        spdlog::spdlog
        Boost::system
        Boost::asio
)

# 设置C++标准
target_compile_features(myapp PRIVATE cxx_std_17)
```

#### Week 2 输出物清单

| 编号 | 输出物 | 说明 | 检验方式 |
|------|--------|------|----------|
| 1 | notes/manifest_mode.md | Manifest模式完整学习笔记 | 文档完整性 |
| 2 | notes/version_constraints.md | 版本约束机制详解 | 包含baseline/overrides示例 |
| 3 | notes/vcpkg_configuration.md | Registry系统配置指南 | 包含多registry配置 |
| 4 | overlay-ports/example/ | overlay port实践 | 能覆盖官方port |
| 5 | notes/cmake_integration.md | CMake工具链集成原理 | 包含vcpkg.cmake分析 |
| 6 | practice/manifest_project/ | Manifest模式示例项目 | cmake构建通过 |
| 7 | notes/week2_summary.md | Week 2知识总结 | 覆盖所有知识点 |

#### Week 2 检验标准

- [ ] 能从零创建vcpkg.json并声明多种形式的依赖
- [ ] 能解释builtin-baseline的作用和版本锁定机制
- [ ] 能使用overrides强制指定特定包版本
- [ ] 能编写带features的依赖声明（default-features、条件依赖）
- [ ] 能配置vcpkg-configuration.json（多registry、overlay-ports）
- [ ] 能解释overlay-ports、registries、default-registry的优先级关系
- [ ] 能解释vcpkg.cmake工具链文件的5个核心功能
- [ ] 能区分host依赖和target依赖（"host": true的作用）
- [ ] 能使用platform表达式实现条件依赖（"platform": "!windows"）
- [ ] Manifest模式项目能通过cmake -B build自动安装所有依赖

---

### 第三周：创建自定义Port（35小时）

```
┌─────────────────────────────────────────────────────────────────┐
│  Week 3: 创建自定义Port                                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Day 15-16: Port文件结构与portfile.cmake基础                     │
│  ┌──────────────────────────────────────────────────┐           │
│  │  ports/mylib/                                     │           │
│  │  ├── portfile.cmake    ← 构建脚本（核心）         │           │
│  │  ├── vcpkg.json        ← 包元数据                 │           │
│  │  ├── usage             ← 使用说明                 │           │
│  │  └── fix-build.patch   ← 可选补丁文件             │           │
│  └──────────────────────────────────────────────────┘           │
│                                                                 │
│  Day 17-18: portfile辅助函数与高级构建                           │
│  ┌──────────────────────────────────────────────────┐           │
│  │  vcpkg_from_github()  → 下载源码                  │           │
│  │  vcpkg_cmake_configure() → CMake配置              │           │
│  │  vcpkg_cmake_build()    → 编译构建                │           │
│  │  vcpkg_cmake_install()  → 安装                    │           │
│  │  vcpkg_cmake_config_fixup() → 修正config路径      │           │
│  │  vcpkg_apply_patches()  → 应用补丁                │           │
│  └──────────────────────────────────────────────────┘           │
│                                                                 │
│  Day 19-20: 特殊类型Port与非CMake项目                            │
│  ┌──────────────────────────────────────────────────┐           │
│  │  Header-only库 → vcpkg_cmake_configure()+file()   │           │
│  │  Makefile项目  → vcpkg_build_make()               │           │
│  │  Meson项目     → vcpkg_configure_meson()          │           │
│  │  Autotools项目 → vcpkg_configure_make()           │           │
│  └──────────────────────────────────────────────────┘           │
│                                                                 │
│  Day 21: vcpkg Registry创建与发布                                │
│  ┌──────────────────────────────────────────────────┐           │
│  │  Git Registry结构:                                │           │
│  │  ├── ports/<name>/     ← port文件                 │           │
│  │  ├── versions/<n->/    ← 版本数据库               │           │
│  │  └── versions/baseline.json ← 基线版本            │           │
│  └──────────────────────────────────────────────────┘           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### 每日任务分解

| Day | 时间 | 上午任务(2.5h) | 下午任务(2.5h) | 输出物 |
|-----|------|---------------|---------------|--------|
| 15 | 5h | Port目录结构与portfile.cmake基础 | vcpkg_from_github/vcpkg_from_git详解 | notes/port_basics.md |
| 16 | 5h | vcpkg_cmake_configure高级选项 | vcpkg_cmake_config_fixup原理 | notes/portfile_functions.md |
| 17 | 5h | 补丁机制(vcpkg_apply_patches) | 实践：为GitHub库创建CMake port | ports/practice-lib/portfile.cmake |
| 18 | 5h | Header-only库port编写 | 多Feature port编写实践 | ports/header-only-lib/ |
| 19 | 5h | 非CMake项目port(Makefile/Autotools) | Meson项目port编写 | ports/non-cmake-lib/ |
| 20 | 5h | port测试与验证(vcpkg_test_cmake) | 阅读ports/fmt和ports/boost-asio源码 | notes/port_testing.md |
| 21 | 5h | 创建Git Registry(版本数据库) | Registry发布与团队共享 | my-vcpkg-registry/ |

**学习目标**：为自己的库或第三方库创建vcpkg port

**阅读材料**：
- [ ] vcpkg文档：Creating Ports
- [ ] vcpkg文档：Portfile Functions
- [ ] vcpkg文档：Registries (Creating)
- [ ] vcpkg源码：`scripts/cmake/vcpkg_from_github.cmake`
- [ ] vcpkg源码：`scripts/cmake/vcpkg_cmake_configure.cmake`

```cmake
# ==========================================
# ports/mylib/portfile.cmake
# ==========================================

# 从GitHub下载源码
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO username/mylib
    REF v${VERSION}
    SHA512 abc123...
    HEAD_REF main
)

# 或者从其他来源下载
# vcpkg_download_distfile(ARCHIVE
#     URLS "https://example.com/mylib-${VERSION}.tar.gz"
#     FILENAME "mylib-${VERSION}.tar.gz"
#     SHA512 abc123...
# )
# vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE ${ARCHIVE})

# 配置CMake项目
vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DMYLIB_BUILD_TESTS=OFF
        -DMYLIB_BUILD_EXAMPLES=OFF
)

# 构建
vcpkg_cmake_build()

# 安装
vcpkg_cmake_install()

# 修复CMake配置文件路径
vcpkg_cmake_config_fixup(
    PACKAGE_NAME mylib
    CONFIG_PATH lib/cmake/mylib
)

# 处理版权文件
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")

# 移除空目录
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")

# 生成使用说明
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
```

```json
// ports/mylib/vcpkg.json
{
  "name": "mylib",
  "version": "1.2.3",
  "port-version": 0,
  "description": "My awesome library",
  "homepage": "https://github.com/username/mylib",
  "license": "MIT",
  "supports": "!uwp",
  "dependencies": [
    "fmt",
    {
      "name": "vcpkg-cmake",
      "host": true
    },
    {
      "name": "vcpkg-cmake-config",
      "host": true
    }
  ],
  "features": {
    "ssl": {
      "description": "Enable SSL support",
      "dependencies": ["openssl"]
    }
  }
}
```

```
# ports/mylib/usage
mylib provides CMake targets:

    find_package(mylib CONFIG REQUIRED)
    target_link_libraries(main PRIVATE mylib::mylib)
```

#### portfile.cmake辅助函数完整参考

```cmake
# ==========================================
# portfile.cmake 核心辅助函数速查
# ==========================================

# === 源码获取函数 ===

# 从GitHub下载（最常用）
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO username/repo              # GitHub仓库
    REF v${VERSION}                 # Git ref（tag/commit）
    SHA512 abc123...                # 校验和（首次可填0，错误信息会给出正确值）
    HEAD_REF main                   # HEAD分支（用于--head模式开发）
    PATCHES
        fix-cmake.patch             # 可选补丁列表
        fix-install.patch
)

# 从Git仓库下载（非GitHub）
vcpkg_from_git(
    OUT_SOURCE_PATH SOURCE_PATH
    URL https://gitlab.com/user/repo.git
    REF abc123def456...             # commit hash
    PATCHES fix-build.patch
)

# 下载压缩包
vcpkg_download_distfile(ARCHIVE
    URLS "https://example.com/lib-${VERSION}.tar.gz"
         "https://mirror.example.com/lib-${VERSION}.tar.gz"  # 备用镜像
    FILENAME "lib-${VERSION}.tar.gz"
    SHA512 abc123...
)
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")

# === CMake构建函数 ===

# CMake配置（完整选项）
vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    DISABLE_PARALLEL_CONFIGURE       # 禁用并行配置（某些项目需要）
    WINDOWS_USE_MSBUILD              # Windows上使用MSBuild而非Ninja
    OPTIONS
        -DBUILD_TESTS=OFF
        -DBUILD_EXAMPLES=OFF
        -DBUILD_SHARED_LIBS=OFF
    OPTIONS_RELEASE
        -DCUSTOM_RELEASE_FLAG=ON     # 仅Release配置
    OPTIONS_DEBUG
        -DCUSTOM_DEBUG_FLAG=ON       # 仅Debug配置
    MAYBE_UNUSED_VARIABLES
        CUSTOM_UNUSED_VAR            # 允许未使用的变量（避免警告）
)

# 构建
vcpkg_cmake_build(
    LOGFILE_BASE build              # 日志文件前缀
    TARGET install                   # 指定构建目标（默认是default target）
)

# 安装
vcpkg_cmake_install()

# 修正CMake config路径（关键！）
vcpkg_cmake_config_fixup(
    PACKAGE_NAME mylib               # find_package的包名
    CONFIG_PATH lib/cmake/mylib      # 原始config路径
    # CONFIG_PATH share/mylib/cmake  # 某些库的路径不同
    DO_NOT_DELETE_PARENT_CONFIG_PATH # 不删除原路径
)

# === 非CMake构建函数 ===

# Makefile项目
vcpkg_build_make(
    BUILD_TARGET all
    INSTALL_TARGET install
    MAKEFILE Makefile                # 指定Makefile名
)

# Autotools项目 (./configure && make)
vcpkg_configure_make(
    SOURCE_PATH "${SOURCE_PATH}"
    AUTOCONFIG                       # 运行autoreconf
    OPTIONS
        --disable-shared
        --enable-static
)
vcpkg_install_make()

# Meson项目
vcpkg_configure_meson(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -Dtests=false
)
vcpkg_install_meson()

# === 安装后处理函数 ===

# 安装版权文件（必须）
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
# 或者手动：
# file(INSTALL "${SOURCE_PATH}/LICENSE.md"
#      DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
#      RENAME copyright)

# 清理空目录（标准操作）
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")

# 复制工具（如果有可执行文件）
vcpkg_copy_tools(
    TOOL_NAMES mytool myothertool
    AUTO_CLEAN                       # 自动清理lib中的exe
)

# 复制pdbs（Windows调试符号）
vcpkg_copy_pdbs()
```

#### Header-only库Port编写

```cmake
# ==========================================
# ports/my-header-lib/portfile.cmake
# Header-only库的portfile（更简单）
# ==========================================

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO username/my-header-lib
    REF v${VERSION}
    SHA512 abc123...
    HEAD_REF main
)

# 方法1：如果有CMakeLists.txt
vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DMY_HEADER_LIB_BUILD_TESTS=OFF
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/my-header-lib)

# 方法2：如果没有CMake（纯头文件复制）
# file(INSTALL "${SOURCE_PATH}/include/"
#      DESTINATION "${CURRENT_PACKAGES_DIR}/include")
#
# # 手动创建CMake config文件
# file(WRITE "${CURRENT_PACKAGES_DIR}/share/${PORT}/${PORT}Config.cmake"
# [=[
# if(NOT TARGET my-header-lib::my-header-lib)
#     add_library(my-header-lib::my-header-lib INTERFACE IMPORTED)
#     set_target_properties(my-header-lib::my-header-lib PROPERTIES
#         INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_CURRENT_LIST_DIR}/../../include"
#     )
# endif()
# ]=])

# 标记为header-only（重要！避免空lib目录报错）
set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)  # 如果include在子目录
# 或者用：
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")  # header-only没有debug

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
```

#### 非CMake项目Port编写示例

```cmake
# ==========================================
# ports/legacy-c-lib/portfile.cmake
# 基于Makefile的C库port
# ==========================================

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO username/legacy-c-lib
    REF v${VERSION}
    SHA512 abc123...
    PATCHES
        fix-makefile-install.patch    # 通常需要修补Makefile的install目标
)

# 对于简单的Makefile项目，可能需要手动处理
if(VCPKG_TARGET_IS_WINDOWS)
    # Windows上可能需要特殊处理
    vcpkg_build_nmake(
        SOURCE_PATH "${SOURCE_PATH}"
        PROJECT_NAME "Makefile.msc"
    )
else()
    vcpkg_build_make(
        BUILD_TARGET all
    )
    vcpkg_install_make()
endif()

# 如果Makefile没有install目标，手动安装
# file(INSTALL "${SOURCE_PATH}/include/"
#      DESTINATION "${CURRENT_PACKAGES_DIR}/include")
# file(INSTALL "${SOURCE_PATH}/libfoo.a"
#      DESTINATION "${CURRENT_PACKAGES_DIR}/lib")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")

# 修复pkgconfig
vcpkg_fixup_pkgconfig()
```

#### 创建vcpkg Git Registry

```bash
# ==========================================
# 创建私有vcpkg Registry
# ==========================================

# Registry目录结构
# my-vcpkg-registry/
# ├── ports/
# │   ├── my-lib-a/
# │   │   ├── portfile.cmake
# │   │   └── vcpkg.json
# │   └── my-lib-b/
# │       ├── portfile.cmake
# │       └── vcpkg.json
# └── versions/
#     ├── baseline.json           ← 所有包的最新版本
#     ├── m-/
#     │   ├── my-lib-a.json       ← my-lib-a的版本历史
#     │   └── my-lib-b.json       ← my-lib-b的版本历史
#     └── ...
```

```json
// versions/baseline.json
{
  "default": {
    "my-lib-a": {
      "baseline": "1.2.0",
      "port-version": 0
    },
    "my-lib-b": {
      "baseline": "0.5.1",
      "port-version": 2
    }
  }
}
```

```json
// versions/m-/my-lib-a.json
{
  "versions": [
    {
      "version": "1.2.0",
      "port-version": 0,
      "git-tree": "abc123..."
    },
    {
      "version": "1.1.0",
      "port-version": 0,
      "git-tree": "def456..."
    },
    {
      "version": "1.0.0",
      "port-version": 0,
      "git-tree": "789abc..."
    }
  ]
}
```

```bash
# 获取git-tree值（用于版本数据库）
# 在registry仓库中执行：
git add ports/my-lib-a
git commit -m "Add my-lib-a 1.2.0"

# 获取ports/my-lib-a目录的tree hash
git rev-parse HEAD:ports/my-lib-a
# 输出: abc123... ← 这就是git-tree值

# 更新versions文件后再次提交
git add versions/
git commit -m "Update version database for my-lib-a 1.2.0"
git push
```

#### Port测试与验证

```bash
# ==========================================
# Port测试方法
# ==========================================

# 1. 使用overlay测试本地port
vcpkg install mylib --overlay-ports=./ports

# 2. 使用--editable模式（修改源码后不重新下载）
vcpkg install mylib --editable --overlay-ports=./ports

# 3. 验证安装结果
vcpkg list mylib
# 检查 installed/<triplet>/include/ 下有头文件
# 检查 installed/<triplet>/lib/ 下有库文件
# 检查 installed/<triplet>/share/mylib/ 下有CMake config

# 4. 在测试项目中验证find_package
# test-project/CMakeLists.txt:
# cmake_minimum_required(VERSION 3.16)
# project(test)
# find_package(mylib CONFIG REQUIRED)
# add_executable(test main.cpp)
# target_link_libraries(test PRIVATE mylib::mylib)

# 5. 运行vcpkg的ci验证
vcpkg ci mylib --overlay-ports=./ports

# 6. 检查端口文件合规性
vcpkg format-manifest ports/mylib/vcpkg.json
```

#### Week 3 输出物清单

| 编号 | 输出物 | 说明 | 检验方式 |
|------|--------|------|----------|
| 1 | notes/port_basics.md | Port文件结构学习笔记 | 文档完整性 |
| 2 | notes/portfile_functions.md | portfile辅助函数参考 | 函数覆盖完整 |
| 3 | ports/practice-lib/ | CMake项目port实践 | vcpkg install成功 |
| 4 | ports/header-only-lib/ | Header-only库port | vcpkg install成功 |
| 5 | ports/non-cmake-lib/ | 非CMake项目port | vcpkg install成功 |
| 6 | notes/port_testing.md | Port测试方法总结 | 包含验证流程 |
| 7 | my-vcpkg-registry/ | 私有Registry | 能被其他项目引用 |

#### Week 3 检验标准

- [ ] 能独立编写完整的portfile.cmake（从下载到安装）
- [ ] 能使用vcpkg_from_github/vcpkg_from_git获取源码
- [ ] 能使用vcpkg_cmake_configure的高级选项（OPTIONS/PATCHES等）
- [ ] 能解释vcpkg_cmake_config_fixup的作用和CONFIG_PATH参数
- [ ] 能为Header-only库编写port
- [ ] 能为非CMake项目（Makefile/Autotools/Meson）编写port
- [ ] 能使用补丁机制修复上游构建问题
- [ ] 能创建Git Registry并维护版本数据库
- [ ] 能使用overlay-ports测试本地port
- [ ] 能使用vcpkg_install_copyright正确安装版权文件

---

### 第四周：高级特性与最佳实践（35小时）

```
┌─────────────────────────────────────────────────────────────────┐
│  Week 4: 高级特性与最佳实践                                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Day 22-23: 二进制缓存与资产缓存                                 │
│  ┌──────────────────────────────────────────────────┐           │
│  │         二进制缓存层级                             │           │
│  │  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐         │           │
│  │  │本地FS │→│NuGet │→│ AWS  │→│Azure │         │           │
│  │  │Cache  │  │Feed  │  │ S3   │  │Blob  │         │           │
│  │  └──────┘  └──────┘  └──────┘  └──────┘         │           │
│  │  读优先级: 左→右    写策略: 可配置readwrite        │           │
│  └──────────────────────────────────────────────────┘           │
│                                                                 │
│  Day 24-25: CI/CD集成与版本管理策略                               │
│  ┌──────────────────────────────────────────────────┐           │
│  │  GitHub Actions / Azure DevOps / GitLab CI        │           │
│  │  ┌────────┐  ┌──────────┐  ┌──────────┐         │           │
│  │  │缓存恢复│→│vcpkg安装 │→│构建+测试 │         │           │
│  │  │Cache   │  │Install   │  │Build+Test│         │           │
│  │  └────────┘  └──────────┘  └──────────┘         │           │
│  └──────────────────────────────────────────────────┘           │
│                                                                 │
│  Day 26-28: vcpkg vs Conan对比与大型项目最佳实践                  │
│  ┌──────────────────────────────────────────────────┐           │
│  │  vcpkg              vs         Conan              │           │
│  │  ┌─────────────┐        ┌─────────────┐          │           │
│  │  │CMake-native │        │多构建系统   │          │           │
│  │  │源码编译     │        │预编译二进制  │          │           │
│  │  │Microsoft维护│        │社区驱动     │          │           │
│  │  └─────────────┘        └─────────────┘          │           │
│  └──────────────────────────────────────────────────┘           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### 每日任务分解

| Day | 时间 | 上午任务(2.5h) | 下午任务(2.5h) | 输出物 |
|-----|------|---------------|---------------|--------|
| 22 | 5h | 二进制缓存原理与本地文件系统缓存 | NuGet/GitHub Packages缓存配置 | notes/binary_caching.md |
| 23 | 5h | AWS S3/Azure Blob缓存配置 | 资产缓存与下载加速 | notes/asset_caching.md |
| 24 | 5h | GitHub Actions中vcpkg CI/CD | Azure DevOps/GitLab CI集成 | .github/workflows/vcpkg.yml |
| 25 | 5h | 版本管理策略(版本方案/port-version) | Monorepo中vcpkg最佳实践 | notes/version_strategy.md |
| 26 | 5h | vcpkg vs Conan全方位对比 | 大型项目依赖治理策略 | notes/vcpkg_vs_conan.md |
| 27 | 5h | 综合实践：network-toolkit项目完善 | 添加CI/CD和二进制缓存 | network-toolkit完整项目 |
| 28 | 5h | 月度知识总结 | 准备Month 39预习 | notes/month38_summary.md |

**学习目标**：掌握vcpkg的高级用法

**阅读材料**：
- [ ] vcpkg文档：Binary Caching
- [ ] vcpkg文档：Asset Caching
- [ ] vcpkg文档：Registries
- [ ] vcpkg文档：Versioning
- [ ] Conan文档（对比学习）：docs.conan.io

#### 二进制缓存架构详解

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    vcpkg 二进制缓存架构                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  二进制缓存的核心思想：                                                   │
│  避免重复编译 = 用 (包名+版本+triplet+编译器+选项) 作为缓存键             │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────┐       │
│  │                     缓存键（ABI Hash）                       │       │
│  │                                                              │       │
│  │  hash = f(package_name, version, port-version,               │       │
│  │           triplet, compiler_id, compiler_version,             │       │
│  │           cmake_options, patches, dependencies_abi)           │       │
│  │                                                              │       │
│  │  例: fmt-9.1.0_x64-linux_gcc-12.2_abc123def456               │       │
│  └─────────────────────────────────────────────────────────────┘       │
│                                                                         │
│  缓存层级（从快到慢）:                                                    │
│                                                                         │
│  ┌──────────┐   ┌──────────────┐   ┌───────────────┐                   │
│  │ 1. 本地   │   │ 2. 共享文件   │   │ 3. 远端存储    │                   │
│  │ 文件系统  │──▶│ 系统(NFS)    │──▶│ (S3/Azure/    │                   │
│  │ ~/.cache  │   │ /shared/cache│   │  NuGet/GH)    │                   │
│  └──────────┘   └──────────────┘   └───────────────┘                   │
│   最快(本机)      快(局域网)          慢(但团队共享)                       │
│                                                                         │
│  读策略: 按配置顺序依次查找，找到即返回                                    │
│  写策略: readwrite的源都会写入（可用read-only保护某些源）                   │
│                                                                         │
│  典型CI配置:                                                             │
│  ┌─────────────────────────────────────────────────┐                   │
│  │  "clear"           ← 清除默认源                   │                   │
│  │  "files,/local,read"  ← 本地缓存只读              │                   │
│  │  "nuget,remote,readwrite" ← 远端缓存读写          │                   │
│  └─────────────────────────────────────────────────┘                   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

```bash
# ==========================================
# 二进制缓存（加速CI/CD）
# ==========================================

# 文件系统缓存（默认）
export VCPKG_BINARY_SOURCES="clear;files,/path/to/cache,readwrite"

# NuGet缓存
export VCPKG_BINARY_SOURCES="clear;nuget,https://nuget.example.com/index.json,readwrite"

# GitHub Packages
export VCPKG_BINARY_SOURCES="clear;nuget,GitHub,readwrite"

# AWS S3
export VCPKG_BINARY_SOURCES="clear;x-aws,s3://my-bucket/vcpkg-cache/,readwrite"

# Azure Blob Storage
export VCPKG_BINARY_SOURCES="clear;x-azblob,https://myaccount.blob.core.windows.net/vcpkg,readwrite"

# 多个缓存源（优先级从左到右）
export VCPKG_BINARY_SOURCES="clear;files,/local/cache,read;nuget,https://remote/,readwrite"

# ==========================================
# 资产缓存（下载源码缓存）
# ==========================================

# 使用镜像加速下载
export X_VCPKG_ASSET_SOURCES="x-azurl,https://mirror.example.com/;x-block-origin"

# ==========================================
# 版本控制
# ==========================================

# 查看包的所有可用版本
vcpkg x-history fmt

# 使用特定版本（在vcpkg.json中）
{
  "dependencies": [
    {
      "name": "fmt",
      "version>=": "9.0.0"
    }
  ],
  "overrides": [
    {
      "name": "fmt",
      "version": "9.1.0"
    }
  ]
}
```

```cmake
# ==========================================
# CMake预设与vcpkg集成
# ==========================================
# CMakePresets.json
{
  "version": 6,
  "configurePresets": [
    {
      "name": "vcpkg-base",
      "hidden": true,
      "cacheVariables": {
        "CMAKE_TOOLCHAIN_FILE": {
          "type": "FILEPATH",
          "value": "$env{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake"
        }
      }
    },
    {
      "name": "debug",
      "displayName": "Debug",
      "inherits": "vcpkg-base",
      "binaryDir": "${sourceDir}/build/debug",
      "cacheVariables": {
        "CMAKE_BUILD_TYPE": "Debug"
      }
    },
    {
      "name": "release",
      "displayName": "Release",
      "inherits": "vcpkg-base",
      "binaryDir": "${sourceDir}/build/release",
      "cacheVariables": {
        "CMAKE_BUILD_TYPE": "Release"
      }
    },
    {
      "name": "windows-x64",
      "displayName": "Windows x64",
      "inherits": "vcpkg-base",
      "binaryDir": "${sourceDir}/build/windows",
      "cacheVariables": {
        "VCPKG_TARGET_TRIPLET": "x64-windows"
      },
      "condition": {
        "type": "equals",
        "lhs": "${hostSystemName}",
        "rhs": "Windows"
      }
    }
  ],
  "buildPresets": [
    {
      "name": "debug",
      "configurePreset": "debug"
    },
    {
      "name": "release",
      "configurePreset": "release"
    }
  ]
}
```

#### GitHub Actions CI/CD完整集成

```yaml
# ==========================================
# .github/workflows/vcpkg-ci.yml
# vcpkg + CMake 完整CI/CD配置
# ==========================================
name: C++ CI with vcpkg

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  VCPKG_BINARY_SOURCES: "clear;x-gha,readwrite"  # GitHub Actions缓存

jobs:
  build:
    strategy:
      matrix:
        include:
          - os: ubuntu-latest
            triplet: x64-linux
            compiler: gcc
          - os: ubuntu-latest
            triplet: x64-linux
            compiler: clang
          - os: macos-latest
            triplet: x64-osx
            compiler: clang
          - os: windows-latest
            triplet: x64-windows
            compiler: msvc

    runs-on: ${{ matrix.os }}

    steps:
      - uses: actions/checkout@v4
        with:
          submodules: true

      # vcpkg GitHub Actions集成（官方推荐方式）
      - name: Export GitHub Actions cache environment variables
        uses: actions/github-script@v7
        with:
          script: |
            core.exportVariable('ACTIONS_CACHE_URL',
              process.env.ACTIONS_CACHE_URL || '');
            core.exportVariable('ACTIONS_RUNTIME_TOKEN',
              process.env.ACTIONS_RUNTIME_TOKEN || '');

      - name: Setup vcpkg
        uses: lukka/run-vcpkg@v11
        with:
          vcpkgGitCommitId: 'a34c873a9717a888f58dc05268dea15592c2f0ff'

      - name: Configure CMake
        uses: lukka/run-cmake@v10
        with:
          configurePreset: 'ci-${{ matrix.triplet }}'
          buildPreset: 'ci-${{ matrix.triplet }}'
          testPreset: 'ci-${{ matrix.triplet }}'

      # 或者手动方式：
      # - name: Configure
      #   run: |
      #     cmake -B build -S . \
      #       --preset ci-${{ matrix.triplet }} \
      #       -DCMAKE_TOOLCHAIN_FILE=$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake
      #
      # - name: Build
      #   run: cmake --build build --config Release
      #
      # - name: Test
      #   run: ctest --test-dir build --config Release --output-on-failure
```

```yaml
# ==========================================
# Azure DevOps Pipeline配置
# ==========================================
# azure-pipelines.yml
trigger:
  branches:
    include:
      - main

pool:
  vmImage: 'ubuntu-latest'

variables:
  VCPKG_BINARY_SOURCES: 'clear;nuget,$(vcpkgNuGetFeed),readwrite'

steps:
  - task: NuGetAuthenticate@1

  - script: |
      git clone https://github.com/microsoft/vcpkg.git
      ./vcpkg/bootstrap-vcpkg.sh
    displayName: 'Setup vcpkg'

  - script: |
      cmake -B build -S . \
        -DCMAKE_TOOLCHAIN_FILE=vcpkg/scripts/buildsystems/vcpkg.cmake \
        -DCMAKE_BUILD_TYPE=Release
      cmake --build build --config Release
    displayName: 'Build'

  - script: |
      cd build && ctest --output-on-failure
    displayName: 'Test'
```

#### 版本管理策略详解

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    vcpkg 版本管理体系                                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  四种版本方案:                                                           │
│  ┌──────────────────┬─────────────────────────────────────────┐        │
│  │ version-string   │ 自由格式，如 "Vista", "2024a"            │        │
│  │ version          │ 宽松semver: "1.2.3" (允许4段 "1.2.3.4")  │        │
│  │ version-semver   │ 严格semver: "1.2.3-alpha+build"          │        │
│  │ version-date     │ 日期格式: "2024-01-15"                    │        │
│  └──────────────────┴─────────────────────────────────────────┘        │
│                                                                         │
│  port-version:                                                          │
│  ┌──────────────────────────────────────────────────────────────┐      │
│  │  version = "1.2.0", port-version = 0  ← 初始发布             │      │
│  │  version = "1.2.0", port-version = 1  ← 修复portfile bug     │      │
│  │  version = "1.2.0", port-version = 2  ← 添加补丁             │      │
│  │  version = "1.3.0", port-version = 0  ← 新上游版本,重置为0   │      │
│  └──────────────────────────────────────────────────────────────┘      │
│                                                                         │
│  版本解析优先级:                                                         │
│  ┌──────────────────────────────────────────────────────────────┐      │
│  │  overrides > version>= 约束 > builtin-baseline              │      │
│  │                                                              │      │
│  │  overrides:     强制使用指定版本（无视所有约束）               │      │
│  │  version>=:     声明最低版本需求                              │      │
│  │  baseline:      所有包的默认版本（如果没有其他约束）           │      │
│  └──────────────────────────────────────────────────────────────┘      │
│                                                                         │
│  版本锁定策略（团队协作推荐）:                                            │
│  ┌──────────────────────────────────────────────────────────────┐      │
│  │  1. 初始化：选择一个vcpkg commit作为baseline                  │      │
│  │  2. 锁定：将baseline写入vcpkg.json的builtin-baseline         │      │
│  │  3. 更新：定期更新baseline（如每月/每季度）                    │      │
│  │  4. 覆盖：特殊需求用overrides锁定个别包                       │      │
│  │  5. 提交：vcpkg.json + vcpkg-configuration.json提交到git     │      │
│  └──────────────────────────────────────────────────────────────┘      │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### vcpkg vs Conan 全方位对比

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    vcpkg vs Conan 对比分析                                │
├──────────────────────────────┬──────────────────────────────────────────┤
│         vcpkg                │            Conan                         │
├──────────────────────────────┼──────────────────────────────────────────┤
│ 语言: C++ (vcpkg-tool)       │ 语言: Python                             │
│ 维护: Microsoft              │ 维护: JFrog + 社区                       │
│ 构建: 源码编译为主            │ 构建: 预编译二进制 + 源码                 │
│ 构建系统: CMake优先           │ 构建系统: 多系统支持(CMake/Meson/...)     │
│ 包描述: CMake (portfile)     │ 包描述: Python (conanfile.py)            │
│ 元数据: JSON (vcpkg.json)    │ 元数据: Python/INI (conanfile.txt)       │
│ 仓库: 集中式 (ports/)        │ 仓库: 分布式 (Conan Center + remote)     │
│ 版本控制: baseline + override│ 版本控制: version ranges + lockfile      │
│ 二进制缓存: 内置              │ 二进制缓存: 内置 (更成熟)               │
│ IDE集成: VS原生               │ IDE集成: 需配置                          │
│ 学习曲线: CMake基础即可       │ 学习曲线: 需了解Python                   │
├──────────────────────────────┼──────────────────────────────────────────┤
│ 适合场景:                    │ 适合场景:                                │
│ • CMake为主的项目             │ • 多构建系统混合项目                     │
│ • Windows/VS开发              │ • 需要精细控制二进制兼容性               │
│ • 不想引入Python依赖          │ • 已有成熟的Conan基础设施               │
│ • 新项目/团队起步              │ • 大型企业级包管理                       │
├──────────────────────────────┴──────────────────────────────────────────┤
│                                                                         │
│  包数量 (2024):                                                          │
│  vcpkg: ~2,500+ ports    Conan Center: ~1,500+ recipes                  │
│                                                                         │
│  社区活跃度:                                                             │
│  vcpkg: GitHub 20k+ stars    Conan: GitHub 7k+ stars                    │
│                                                                         │
│  建议: 新项目优先考虑vcpkg (CMake集成更好，微软维护更稳定)                │
│        如果已有Conan基础设施或需要复杂二进制管理，使用Conan                │
│        两者可以共存于同一项目中                                           │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### 大型项目依赖治理策略

```
┌─────────────────────────────────────────────────────────────────────────┐
│                大型项目 vcpkg 最佳实践                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  1. Monorepo结构                                                        │
│  ┌───────────────────────────────────────────────────────┐              │
│  │  monorepo/                                             │              │
│  │  ├── vcpkg.json              ← 根级依赖声明            │              │
│  │  ├── vcpkg-configuration.json ← 全局registry配置      │              │
│  │  ├── custom-ports/            ← 共享overlay ports      │              │
│  │  ├── custom-triplets/         ← 共享triplet           │              │
│  │  ├── services/                                         │              │
│  │  │   ├── service-a/           ← 各服务可有自己的       │              │
│  │  │   │   └── vcpkg.json       ← vcpkg.json            │              │
│  │  │   └── service-b/                                    │              │
│  │  └── libs/                    ← 内部共享库             │              │
│  │      └── internal-lib/                                 │              │
│  └───────────────────────────────────────────────────────┘              │
│                                                                         │
│  2. 依赖审计流程                                                         │
│  ┌───────────────────────────────────────────────────────┐              │
│  │  • 定期审查vcpkg.json中的依赖列表                      │              │
│  │  • 检查依赖的安全漏洞(结合OSV/CVE数据库)               │              │
│  │  • 限制transitive依赖的引入                            │              │
│  │  • 使用overrides锁定关键依赖版本                       │              │
│  │  • 建立内部port审核制度                                │              │
│  └───────────────────────────────────────────────────────┘              │
│                                                                         │
│  3. 构建加速策略                                                         │
│  ┌───────────────────────────────────────────────────────┐              │
│  │  • 二进制缓存分层: 本地 → 共享NFS → 云端S3             │              │
│  │  • CI矩阵: 并行构建多triplet/多平台                    │              │
│  │  • 增量更新: 只更新变化的依赖                           │              │
│  │  • 预热缓存: 定时任务预构建常用组合                     │              │
│  │  • VCPKG_MAX_CONCURRENCY调优                           │              │
│  └───────────────────────────────────────────────────────┘              │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### Week 4 输出物清单

| 编号 | 输出物 | 说明 | 检验方式 |
|------|--------|------|----------|
| 1 | notes/binary_caching.md | 二进制缓存配置指南 | 包含多种后端配置 |
| 2 | notes/asset_caching.md | 资产缓存与镜像配置 | 包含镜像配置示例 |
| 3 | .github/workflows/vcpkg.yml | GitHub Actions CI | CI运行通过 |
| 4 | notes/version_strategy.md | 版本管理策略笔记 | 包含4种方案对比 |
| 5 | notes/vcpkg_vs_conan.md | vcpkg vs Conan对比 | 多维度对比表 |
| 6 | network-toolkit/ | 完善的综合项目 | 构建+测试+CI通过 |
| 7 | notes/month38_summary.md | 月度总结 | 覆盖所有知识点 |

#### Week 4 检验标准

- [ ] 能配置文件系统二进制缓存并验证缓存命中
- [ ] 能配置NuGet/S3/Azure Blob远端二进制缓存
- [ ] 能解释二进制缓存键（ABI Hash）的计算因素
- [ ] 能编写完整的GitHub Actions CI/CD流水线（含vcpkg缓存）
- [ ] 能解释vcpkg的四种版本方案及port-version的作用
- [ ] 能制定团队级版本锁定策略（baseline定期更新）
- [ ] 能从多维度对比vcpkg和Conan的优劣
- [ ] 能为大型项目设计vcpkg依赖治理方案
- [ ] 能配置Monorepo中的多项目vcpkg共享
- [ ] 综合项目network-toolkit构建+测试+CI全部通过

---

## 源码阅读任务

### 本月源码阅读

1. **vcpkg核心代码**
   - 仓库：https://github.com/microsoft/vcpkg-tool
   - 重点：`src/vcpkg/` 目录
   - 学习目标：理解包管理器的实现原理

2. **热门port示例**
   - 仓库：https://github.com/microsoft/vcpkg
   - 重点：`ports/fmt`、`ports/spdlog`、`ports/boost`
   - 学习目标：学习高质量port的编写方式

3. **vcpkg-cmake辅助函数**
   - 路径：`scripts/cmake/`
   - 重点：`vcpkg_from_github.cmake`、`vcpkg_cmake_configure.cmake`
   - 学习目标：理解portfile辅助函数的实现

---

## 实践项目

### 项目：vcpkg集成的跨平台网络库

创建一个使用vcpkg管理依赖的网络工具库。

**项目结构**：

```
network-toolkit/
├── CMakeLists.txt
├── CMakePresets.json
├── vcpkg.json
├── vcpkg-configuration.json
├── include/
│   └── nettool/
│       ├── http_client.hpp
│       ├── dns_resolver.hpp
│       └── url_parser.hpp
├── src/
│   ├── CMakeLists.txt
│   ├── http_client.cpp
│   ├── dns_resolver.cpp
│   └── url_parser.cpp
├── apps/
│   ├── CMakeLists.txt
│   └── http_get.cpp
├── tests/
│   ├── CMakeLists.txt
│   └── test_url_parser.cpp
└── ports/
    └── nettool/
        ├── portfile.cmake
        ├── vcpkg.json
        └── usage
```

**vcpkg.json**：

```json
{
  "name": "network-toolkit",
  "version": "1.0.0",
  "description": "A cross-platform network toolkit",
  "homepage": "https://github.com/user/network-toolkit",
  "license": "MIT",
  "dependencies": [
    "fmt",
    "spdlog",
    {
      "name": "openssl",
      "version>=": "3.0.0"
    },
    {
      "name": "boost-asio",
      "version>=": "1.81.0"
    },
    {
      "name": "boost-beast",
      "version>=": "1.81.0"
    },
    {
      "name": "nlohmann-json",
      "version>=": "3.11.0"
    }
  ],
  "builtin-baseline": "a34c873a9717a888f58dc05268dea15592c2f0ff",
  "features": {
    "tests": {
      "description": "Build tests",
      "dependencies": [
        {
          "name": "gtest",
          "version>=": "1.12.0"
        }
      ]
    }
  }
}
```

**CMakeLists.txt**（根目录）：

```cmake
cmake_minimum_required(VERSION 3.16)

project(NetworkToolkit
    VERSION 1.0.0
    DESCRIPTION "A cross-platform network toolkit"
    LANGUAGES CXX
)

# C++标准
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 选项
option(NETTOOL_BUILD_TESTS "Build tests" ON)
option(NETTOOL_BUILD_APPS "Build applications" ON)

# 查找依赖（vcpkg会自动处理）
find_package(fmt CONFIG REQUIRED)
find_package(spdlog CONFIG REQUIRED)
find_package(OpenSSL REQUIRED)
find_package(Boost REQUIRED COMPONENTS system)
find_package(nlohmann_json CONFIG REQUIRED)

# 子目录
add_subdirectory(src)

if(NETTOOL_BUILD_APPS)
    add_subdirectory(apps)
endif()

if(NETTOOL_BUILD_TESTS)
    enable_testing()
    find_package(GTest CONFIG REQUIRED)
    add_subdirectory(tests)
endif()
```

**include/nettool/url_parser.hpp**：

```cpp
#pragma once

#include <string>
#include <string_view>
#include <optional>
#include <stdexcept>

namespace nettool {

/**
 * @brief URL解析结果
 */
struct Url {
    std::string scheme;      // http, https
    std::string host;        // www.example.com
    uint16_t port = 0;       // 80, 443
    std::string path;        // /path/to/resource
    std::string query;       // key=value&foo=bar
    std::string fragment;    // section1

    // 获取完整URL
    std::string to_string() const;

    // 获取带端口的host
    std::string host_with_port() const;

    // 检查是否为HTTPS
    bool is_secure() const { return scheme == "https"; }

    // 获取默认端口
    static uint16_t default_port(std::string_view scheme);
};

/**
 * @brief URL解析异常
 */
class UrlParseError : public std::runtime_error {
public:
    using std::runtime_error::runtime_error;
};

/**
 * @brief URL解析器
 */
class UrlParser {
public:
    /**
     * @brief 解析URL字符串
     * @param url_string URL字符串
     * @return 解析结果
     * @throws UrlParseError 解析失败时抛出
     */
    static Url parse(std::string_view url_string);

    /**
     * @brief 尝试解析URL字符串
     * @param url_string URL字符串
     * @return 解析结果，失败返回nullopt
     */
    static std::optional<Url> try_parse(std::string_view url_string) noexcept;

    /**
     * @brief URL编码
     */
    static std::string encode(std::string_view str);

    /**
     * @brief URL解码
     */
    static std::string decode(std::string_view str);

private:
    static bool is_unreserved(char c);
};

} // namespace nettool
```

**src/url_parser.cpp**：

```cpp
#include "nettool/url_parser.hpp"
#include <fmt/format.h>
#include <sstream>
#include <iomanip>
#include <cctype>
#include <algorithm>
#include <regex>

namespace nettool {

std::string Url::to_string() const {
    std::string result = scheme + "://" + host;

    if (port != 0 && port != default_port(scheme)) {
        result += ":" + std::to_string(port);
    }

    result += path.empty() ? "/" : path;

    if (!query.empty()) {
        result += "?" + query;
    }

    if (!fragment.empty()) {
        result += "#" + fragment;
    }

    return result;
}

std::string Url::host_with_port() const {
    uint16_t p = port != 0 ? port : default_port(scheme);
    return fmt::format("{}:{}", host, p);
}

uint16_t Url::default_port(std::string_view scheme) {
    if (scheme == "http") return 80;
    if (scheme == "https") return 443;
    if (scheme == "ftp") return 21;
    if (scheme == "ssh") return 22;
    return 0;
}

Url UrlParser::parse(std::string_view url_string) {
    auto result = try_parse(url_string);
    if (!result) {
        throw UrlParseError(fmt::format("Invalid URL: {}", url_string));
    }
    return *result;
}

std::optional<Url> UrlParser::try_parse(std::string_view url_string) noexcept {
    try {
        // 使用正则表达式解析URL
        // scheme://[user:pass@]host[:port][/path][?query][#fragment]
        static const std::regex url_regex(
            R"(^([a-zA-Z][a-zA-Z0-9+.-]*):\/\/)"  // scheme
            R"((?:[^:@]+(?::[^@]*)?@)?)"           // user:pass@ (optional)
            R"(([^:/?#]+))"                        // host
            R"((?::(\d+))?)"                       // :port (optional)
            R"((\/[^?#]*)?)"                       // /path (optional)
            R"((?:\?([^#]*))?)"                    // ?query (optional)
            R"((?:#(.*))?$)"                       // #fragment (optional)
        );

        std::string url_str(url_string);
        std::smatch match;

        if (!std::regex_match(url_str, match, url_regex)) {
            return std::nullopt;
        }

        Url url;
        url.scheme = match[1].str();

        // 转小写scheme
        std::transform(url.scheme.begin(), url.scheme.end(),
                       url.scheme.begin(), ::tolower);

        url.host = match[2].str();

        // 解析端口
        if (match[3].matched && !match[3].str().empty()) {
            url.port = static_cast<uint16_t>(std::stoi(match[3].str()));
        } else {
            url.port = Url::default_port(url.scheme);
        }

        url.path = match[4].matched ? match[4].str() : "/";
        url.query = match[5].matched ? match[5].str() : "";
        url.fragment = match[6].matched ? match[6].str() : "";

        return url;
    } catch (...) {
        return std::nullopt;
    }
}

bool UrlParser::is_unreserved(char c) {
    return std::isalnum(static_cast<unsigned char>(c)) ||
           c == '-' || c == '_' || c == '.' || c == '~';
}

std::string UrlParser::encode(std::string_view str) {
    std::ostringstream encoded;
    encoded << std::hex << std::uppercase;

    for (char c : str) {
        if (is_unreserved(c)) {
            encoded << c;
        } else {
            encoded << '%' << std::setw(2) << std::setfill('0')
                    << static_cast<int>(static_cast<unsigned char>(c));
        }
    }

    return encoded.str();
}

std::string UrlParser::decode(std::string_view str) {
    std::string decoded;
    decoded.reserve(str.size());

    for (size_t i = 0; i < str.size(); ++i) {
        if (str[i] == '%' && i + 2 < str.size()) {
            int value;
            std::istringstream iss(std::string(str.substr(i + 1, 2)));
            if (iss >> std::hex >> value) {
                decoded += static_cast<char>(value);
                i += 2;
                continue;
            }
        } else if (str[i] == '+') {
            decoded += ' ';
            continue;
        }
        decoded += str[i];
    }

    return decoded;
}

} // namespace nettool
```

**include/nettool/http_client.hpp**：

```cpp
#pragma once

#include "nettool/url_parser.hpp"
#include <string>
#include <map>
#include <functional>
#include <memory>
#include <chrono>
#include <variant>

namespace nettool {

/**
 * @brief HTTP方法
 */
enum class HttpMethod {
    GET,
    POST,
    PUT,
    DELETE,
    PATCH,
    HEAD,
    OPTIONS
};

/**
 * @brief HTTP响应
 */
struct HttpResponse {
    int status_code = 0;
    std::string status_message;
    std::map<std::string, std::string> headers;
    std::string body;

    bool is_success() const { return status_code >= 200 && status_code < 300; }
    bool is_redirect() const { return status_code >= 300 && status_code < 400; }
    bool is_client_error() const { return status_code >= 400 && status_code < 500; }
    bool is_server_error() const { return status_code >= 500; }
};

/**
 * @brief HTTP请求配置
 */
struct HttpRequest {
    HttpMethod method = HttpMethod::GET;
    Url url;
    std::map<std::string, std::string> headers;
    std::string body;

    // 超时设置
    std::chrono::seconds connect_timeout{10};
    std::chrono::seconds read_timeout{30};

    // 是否跟随重定向
    bool follow_redirects = true;
    int max_redirects = 5;

    // 是否验证SSL证书
    bool verify_ssl = true;
};

/**
 * @brief HTTP客户端接口
 */
class HttpClient {
public:
    virtual ~HttpClient() = default;

    /**
     * @brief 发送HTTP请求
     */
    virtual HttpResponse send(const HttpRequest& request) = 0;

    /**
     * @brief 便捷GET请求
     */
    HttpResponse get(const std::string& url);
    HttpResponse get(const std::string& url,
                     const std::map<std::string, std::string>& headers);

    /**
     * @brief 便捷POST请求
     */
    HttpResponse post(const std::string& url, const std::string& body);
    HttpResponse post(const std::string& url, const std::string& body,
                      const std::map<std::string, std::string>& headers);

    /**
     * @brief 创建默认HTTP客户端
     */
    static std::unique_ptr<HttpClient> create();
};

/**
 * @brief 基于Boost.Beast的HTTP客户端实现
 */
class BeastHttpClient : public HttpClient {
public:
    BeastHttpClient();
    ~BeastHttpClient() override;

    HttpResponse send(const HttpRequest& request) override;

private:
    class Impl;
    std::unique_ptr<Impl> impl_;
};

} // namespace nettool
```

**tests/test_url_parser.cpp**：

```cpp
#include <gtest/gtest.h>
#include <nettool/url_parser.hpp>

using namespace nettool;

class UrlParserTest : public ::testing::Test {};

TEST_F(UrlParserTest, ParseSimpleUrl) {
    auto url = UrlParser::parse("https://www.example.com/path");

    EXPECT_EQ(url.scheme, "https");
    EXPECT_EQ(url.host, "www.example.com");
    EXPECT_EQ(url.port, 443);
    EXPECT_EQ(url.path, "/path");
    EXPECT_TRUE(url.query.empty());
    EXPECT_TRUE(url.fragment.empty());
}

TEST_F(UrlParserTest, ParseUrlWithPort) {
    auto url = UrlParser::parse("http://localhost:8080/api/v1");

    EXPECT_EQ(url.scheme, "http");
    EXPECT_EQ(url.host, "localhost");
    EXPECT_EQ(url.port, 8080);
    EXPECT_EQ(url.path, "/api/v1");
}

TEST_F(UrlParserTest, ParseUrlWithQuery) {
    auto url = UrlParser::parse("https://api.example.com/search?q=hello&page=1");

    EXPECT_EQ(url.host, "api.example.com");
    EXPECT_EQ(url.path, "/search");
    EXPECT_EQ(url.query, "q=hello&page=1");
}

TEST_F(UrlParserTest, ParseUrlWithFragment) {
    auto url = UrlParser::parse("https://docs.example.com/guide#section-1");

    EXPECT_EQ(url.path, "/guide");
    EXPECT_EQ(url.fragment, "section-1");
}

TEST_F(UrlParserTest, ParseCompleteUrl) {
    auto url = UrlParser::parse(
        "https://api.example.com:8443/v2/users?active=true#top");

    EXPECT_EQ(url.scheme, "https");
    EXPECT_EQ(url.host, "api.example.com");
    EXPECT_EQ(url.port, 8443);
    EXPECT_EQ(url.path, "/v2/users");
    EXPECT_EQ(url.query, "active=true");
    EXPECT_EQ(url.fragment, "top");
}

TEST_F(UrlParserTest, InvalidUrl) {
    EXPECT_THROW(UrlParser::parse("not-a-url"), UrlParseError);
    EXPECT_THROW(UrlParser::parse("://missing-scheme.com"), UrlParseError);
}

TEST_F(UrlParserTest, TryParse) {
    auto result = UrlParser::try_parse("invalid");
    EXPECT_FALSE(result.has_value());

    result = UrlParser::try_parse("https://valid.com");
    EXPECT_TRUE(result.has_value());
}

TEST_F(UrlParserTest, UrlEncode) {
    EXPECT_EQ(UrlParser::encode("hello world"), "hello%20world");
    EXPECT_EQ(UrlParser::encode("foo=bar&baz"), "foo%3Dbar%26baz");
    EXPECT_EQ(UrlParser::encode("test_value-123"), "test_value-123");
}

TEST_F(UrlParserTest, UrlDecode) {
    EXPECT_EQ(UrlParser::decode("hello%20world"), "hello world");
    EXPECT_EQ(UrlParser::decode("hello+world"), "hello world");
    EXPECT_EQ(UrlParser::decode("foo%3Dbar%26baz"), "foo=bar&baz");
}

TEST_F(UrlParserTest, UrlToString) {
    Url url;
    url.scheme = "https";
    url.host = "example.com";
    url.port = 443;
    url.path = "/api";
    url.query = "key=value";

    EXPECT_EQ(url.to_string(), "https://example.com/api?key=value");

    url.port = 8443;
    EXPECT_EQ(url.to_string(), "https://example.com:8443/api?key=value");
}

TEST_F(UrlParserTest, DefaultPorts) {
    EXPECT_EQ(Url::default_port("http"), 80);
    EXPECT_EQ(Url::default_port("https"), 443);
    EXPECT_EQ(Url::default_port("ftp"), 21);
    EXPECT_EQ(Url::default_port("unknown"), 0);
}
```

---

## 月度验收标准

### 知识维度检验

#### 基础概念（Week 1）
- [ ] 能从零安装vcpkg并完成环境配置
- [ ] 能画出vcpkg的核心架构图（ports/buildtrees/packages/installed）
- [ ] 能解释vcpkg install的5个完整阶段
- [ ] 能编写3种以上自定义triplet
- [ ] 能使用vcpkg integrate完成IDE集成

#### 项目集成（Week 2）
- [ ] 能编写完整的vcpkg.json（含依赖、版本约束、features）
- [ ] 能配置vcpkg-configuration.json（多registry、overlay）
- [ ] 能解释vcpkg.cmake工具链的工作原理
- [ ] 能区分Manifest模式和Classic模式的8个核心差异

#### Port开发（Week 3）
- [ ] 能独立编写CMake项目的portfile.cmake
- [ ] 能为Header-only库和非CMake项目编写port
- [ ] 能创建并维护Git Registry
- [ ] 能使用补丁机制修复上游构建问题

#### 工程实践（Week 4）
- [ ] 能配置多层级二进制缓存（本地+远端）
- [ ] 能编写完整的GitHub Actions CI/CD流水线
- [ ] 能制定团队级版本管理策略
- [ ] 能对比分析vcpkg和Conan的适用场景

### 实践维度检验

- [ ] network-toolkit项目能通过Manifest模式构建
- [ ] 自定义port能通过vcpkg install安装
- [ ] 私有Registry能被其他项目正确引用
- [ ] CI/CD流水线能成功运行并使用二进制缓存
- [ ] 所有单元测试通过

### 知识检验问题

1. vcpkg的triplet是什么？如何创建自定义triplet？列举至少5个内置triplet。
2. vcpkg.json中的builtin-baseline有什么作用？overrides的优先级如何？
3. 如何在CI环境中使用vcpkg的二进制缓存？ABI Hash包含哪些因素？
4. VCPKG_TARGET_TRIPLET和VCPKG_HOST_TRIPLET的区别是什么？host依赖的场景？
5. overlay-ports、registries、default-registry的解析优先级是什么？
6. vcpkg_cmake_config_fixup的作用是什么？为什么它是port的必要步骤？
7. 四种版本方案（version/version-semver/version-date/version-string）各适合什么场景？
8. 为什么Manifest模式比Classic模式更适合团队协作？
9. 如何为一个基于Autotools的C库编写vcpkg port？
10. vcpkg和Conan在二进制分发策略上的核心差异是什么？

---

## 月度知识地图

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Month 38 知识地图：vcpkg包管理器                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│                    ┌───────────────────┐                                │
│                    │    vcpkg 包管理器   │                                │
│                    └─────────┬─────────┘                                │
│              ┌───────────────┼───────────────┐                          │
│              ▼               ▼               ▼                          │
│     ┌────────────┐  ┌────────────┐  ┌────────────────┐                 │
│     │  基础架构   │  │  项目集成   │  │  高级特性       │                 │
│     └──────┬─────┘  └──────┬─────┘  └──────┬─────────┘                 │
│            │               │               │                            │
│     ┌──────▼──────┐ ┌──────▼──────┐ ┌──────▼──────────┐               │
│     │安装与配置   │ │Manifest模式 │ │二进制缓存        │               │
│     │目录结构     │ │vcpkg.json   │ │FS/NuGet/S3/Azure│               │
│     │Triplet系统  │ │版本约束     │ │资产缓存          │               │
│     │Classic模式  │ │Feature系统  │ │                  │               │
│     │命令行工具   │ │Registry     │ │CI/CD集成         │               │
│     │环境变量     │ │Overlay      │ │GitHub Actions    │               │
│     │IDE集成      │ │CMake工具链  │ │Azure DevOps      │               │
│     └─────────────┘ └─────────────┘ │版本管理策略      │               │
│                                      │vcpkg vs Conan   │               │
│                    ┌─────────────┐   │大型项目实践      │               │
│                    │  Port开发    │   └─────────────────┘               │
│                    └──────┬──────┘                                      │
│                           │                                             │
│                    ┌──────▼──────┐                                      │
│                    │portfile.cmake│                                     │
│                    │源码获取函数  │                                      │
│                    │CMake构建函数 │                                      │
│                    │非CMake项目   │                                      │
│                    │Header-only  │                                      │
│                    │补丁机制     │                                       │
│                    │Git Registry │                                      │
│                    └─────────────┘                                      │
│                                                                         │
│  ┌────────────────────────────────────────────────────────────────┐     │
│  │                      实践项目                                   │     │
│  │  network-toolkit: URL解析 + HTTP客户端 + 自定义port + CI/CD     │     │
│  └────────────────────────────────────────────────────────────────┘     │
│                                                                         │
│  Month 37 (CMake) ──→ Month 38 (vcpkg) ──→ Month 39 (Conan)           │
│  构建系统基础         包管理集成            对比学习第二套方案            │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 输出物清单

### 完整输出物列表

| 编号 | 类别 | 输出物 | 说明 |
|------|------|--------|------|
| 1 | 项目 | network-toolkit/ | 完整的vcpkg集成示例项目 |
| 2 | 项目 | vcpkg.json | Manifest模式依赖声明 |
| 3 | 项目 | vcpkg-configuration.json | Registry与overlay配置 |
| 4 | 项目 | CMakePresets.json | CMake预设配置 |
| 5 | Port | ports/nettool/ | 自己库的vcpkg port |
| 6 | Port | ports/header-only-lib/ | Header-only库port |
| 7 | Port | ports/non-cmake-lib/ | 非CMake项目port |
| 8 | Registry | my-vcpkg-registry/ | 私有Git Registry |
| 9 | Triplet | custom-triplets/*.cmake | 自定义triplet文件 |
| 10 | CI/CD | .github/workflows/vcpkg.yml | GitHub Actions配置 |
| 11 | 文档 | notes/month38_vcpkg.md | 学习笔记总结 |
| 12 | 文档 | notes/vcpkg_cheatsheet.md | 常用命令速查 |
| 13 | 文档 | notes/vcpkg_vs_conan.md | 包管理器对比分析 |
| 14 | 脚本 | scripts/setup-vcpkg.sh | vcpkg安装脚本 |
| 15 | 脚本 | scripts/build.sh | 跨平台构建脚本 |

---

## 时间分配表

| 周次 | 主题 | 理论学习 | 实践编码 | 源码阅读 | 合计 |
|------|------|----------|----------|----------|------|
| 第1周 | vcpkg基础入门 | 12h | 18h | 5h | 35h |
| 第2周 | Manifest模式与项目集成 | 10h | 20h | 5h | 35h |
| 第3周 | 创建自定义Port | 8h | 22h | 5h | 35h |
| 第4周 | 高级特性与最佳实践 | 8h | 22h | 5h | 35h |
| **合计** | | **38h** | **82h** | **20h** | **140h** |

---

## 下月预告

Month 39将学习**Conan包管理器**，掌握另一个流行的C++包管理工具。重点内容：

- Conan 2.x架构与conanfile.py编写
- Conan Center Index与自建Remote
- 预编译二进制分发策略
- Conan与CMake/Meson/Bazel集成
- 企业级Conan Server (Artifactory)部署
- vcpkg与Conan在实际项目中的选型决策

```
Month 37 (CMake)     Month 38 (vcpkg)     Month 39 (Conan)
构建系统             包管理方案A           包管理方案B
     │                    │                     │
     └────────────────────┼─────────────────────┘
                          ▼
              完整的C++工程化工具链
              (构建 + 包管理 + CI/CD)
```
