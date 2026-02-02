# Month 39: Conan包管理器——去中心化的C++依赖管理

## 本月主题概述

本月学习Conan，这是一个去中心化的C/C++包管理器。与vcpkg不同，Conan支持私有仓库、灵活的构建配置和更强大的版本控制。学习Conan的核心概念、配置文件编写，以及如何发布自己的包到ConanCenter或私有仓库。

**学习目标**：
- 掌握Conan 2.x的安装、配置和基本使用
- 理解conanfile.py和conanfile.txt的编写
- 学会创建和发布Conan包
- 对比vcpkg和Conan，理解各自的适用场景

---

## 理论学习内容

### 第一周：Conan基础入门（35小时）

```
┌─────────────────────────────────────────────────────────────────┐
│  Week 1: Conan 基础入门                                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Day 1-2: Conan安装与核心架构                                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │ conan客户 │→│ 本地缓存  │→│ 远端仓库  │→│ 二进制包  │       │
│  │ 端(Python)│  │~/.conan2 │  │ConanCenter│  │ 预编译   │       │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘       │
│                                                                 │
│  Day 3-4: Profile系统与三层配置体系                               │
│  ┌─────────────────────────────────────────────────────┐       │
│  │  Settings (编译器/OS/架构)                            │       │
│  │  Options  (库级开关: shared/fPIC/with_ssl)           │       │
│  │  Conf     (工具级配置: generator/jobs/sudo)          │       │
│  │  双Profile: -pr:h (host) + -pr:b (build)            │       │
│  └─────────────────────────────────────────────────────┘       │
│                                                                 │
│  Day 5-7: Conan 2.x新特性与缓存体系                             │
│  ┌─────────────────────────────────────────────────────┐       │
│  │  Conan 2.x: 全新API / 新缓存结构 / Generators重构   │       │
│  │  缓存: ~/.conan2/p/ (包数据) + profiles/ + remotes/  │       │
│  │  命令: conan install/create/upload/graph/lock        │       │
│  └─────────────────────────────────────────────────────┘       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### 每日任务分解

| Day | 时间 | 上午任务(2.5h) | 下午任务(2.5h) | 输出物 |
|-----|------|---------------|---------------|--------|
| 1 | 5h | Conan安装(pip/pipx)与初始化配置 | Conan架构原理(客户端→缓存→远端) | notes/conan_setup.md |
| 2 | 5h | Conan 2.x vs 1.x核心变化对比 | 阅读Conan 2.0迁移指南 | notes/conan2_changes.md |
| 3 | 5h | Profile系统基础(settings/options/conf) | 双Profile机制(-pr:h/-pr:b) | notes/conan_profiles.md |
| 4 | 5h | 多平台Profile编写(Linux/macOS/Windows) | Profile composition与include | profiles/各平台profile文件 |
| 5 | 5h | Conan缓存目录结构详解(~/.conan2/) | 远端仓库管理(remote add/login) | notes/conan_cache.md |
| 6 | 5h | 基本命令实践(search/install/inspect) | 阅读Conan客户端源码入口 | notes/conan_commands.md |
| 7 | 5h | Settings/Options/Conf三层体系总结 | Week 1知识总结与实践验证 | notes/week1_summary.md |

**学习目标**：安装Conan并理解基本概念

**阅读材料**：
- [ ] Conan官方文档 (docs.conan.io)
- [ ] Conan 2.0迁移指南
- [ ] ConanCenter仓库浏览 (conan.io/center)
- [ ] Conan源码：`conan/client/` 目录（客户端核心逻辑）
- [ ] Conan源码：`conan/tools/cmake/` 目录（CMake集成）

**核心概念**：

#### Conan架构原理

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Conan 核心架构                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────┐                                                │
│  │    Conan客户端       │ ← Python编写的命令行工具                       │
│  │  (conan executable)  │    conan install / create / upload             │
│  └──────────┬──────────┘                                                │
│             │                                                            │
│  ┌──────────▼──────────────────────────────────────────────────────┐    │
│  │                  本地缓存 (~/.conan2/)                           │    │
│  │                                                                  │    │
│  │  profiles/              ← Profile配置文件                        │    │
│  │  ├── default            ← 默认编译配置                           │    │
│  │  ├── linux-release      ← 自定义profile                         │    │
│  │  └── cross-arm64        ← 交叉编译profile                       │    │
│  │                                                                  │    │
│  │  p/                     ← 包数据存储（Conan 2.x新结构）          │    │
│  │  ├── <hash1>/                                                    │    │
│  │  │   ├── e/             ← export (recipe导出)                    │    │
│  │  │   │   ├── conanfile.py                                        │    │
│  │  │   │   └── conandata.yml                                       │    │
│  │  │   ├── s/             ← source (源码)                          │    │
│  │  │   ├── b/             ← build (构建临时目录)                   │    │
│  │  │   └── p/             ← package (打包结果)                     │    │
│  │  │       └── <pkg_hash>/                                         │    │
│  │  │           ├── include/                                        │    │
│  │  │           ├── lib/                                            │    │
│  │  │           └── conaninfo.txt                                   │    │
│  │  └── <hash2>/                                                    │    │
│  │                                                                  │    │
│  │  remotes.json           ← 远端仓库列表                           │    │
│  │  settings.yml           ← 全局settings定义                       │    │
│  │  global.conf            ← 全局conf配置                           │    │
│  │  extensions/            ← 自定义扩展/hooks                       │    │
│  └──────────────────────────────────────────────────────────────────┘    │
│             │                                                            │
│  ┌──────────▼──────────────────────────────────────────────────────┐    │
│  │                     远端仓库                                      │    │
│  │                                                                  │    │
│  │  ConanCenter          ← 官方公共仓库（~1500+ recipes）           │    │
│  │  Artifactory          ← JFrog商业方案（企业首选）                │    │
│  │  Conan Server         ← 开源轻量服务器                          │    │
│  │  自定义Remote          ← 任何支持Conan协议的服务                  │    │
│  └──────────────────────────────────────────────────────────────────┘    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### Conan 2.x vs 1.x 核心变化

```
┌─────────────────────────────────────────────────────────────────────────┐
│                  Conan 2.x vs 1.x 核心变化                               │
├──────────────────────────────┬──────────────────────────────────────────┤
│       Conan 1.x              │         Conan 2.x                        │
├──────────────────────────────┼──────────────────────────────────────────┤
│ 缓存路径: ~/.conan/          │ 缓存路径: ~/.conan2/                     │
│ 缓存结构: 按包名/版本        │ 缓存结构: 按hash（扁平化）               │
│ Generators: cmake, cmake_find│ Generators: CMakeDeps, CMakeToolchain    │
│ imports from conans          │ imports from conan                       │
│ self.copy()                  │ conan.tools.files.copy()                 │
│ build_requires               │ tool_requires                            │
│ python_requires直接import    │ python_requires声明式引用                │
│ 环境变量注入                  │ Environment模型(buildenv/runenv)         │
│ 隐式settings传播              │ 显式的package_type                       │
│ conanfile.txt常用             │ conanfile.py推荐（更灵活）               │
│ cmake_paths generator        │ CMakeToolchain + cmake_layout            │
│ 包ID hash不一致              │ 统一的包ID计算                            │
├──────────────────────────────┴──────────────────────────────────────────┤
│                                                                         │
│  迁移关键：                                                              │
│  1. from conans → from conan                                             │
│  2. self.copy() → copy(self, ...)                                       │
│  3. cmake/cmake_find_package → CMakeDeps + CMakeToolchain               │
│  4. build_requires → tool_requires                                      │
│  5. 配置文件路径 ~/.conan/ → ~/.conan2/                                 │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

```bash
# ==========================================
# Conan 2.x 安装
# ==========================================

# 使用pip安装（推荐）
pip install conan

# 或使用pipx（隔离环境）
pipx install conan

# 验证安装
conan --version

# 初始化配置（首次使用）
conan profile detect

# ==========================================
# 基本命令
# ==========================================

# 搜索包（本地缓存）
conan search "*"

# 搜索远程仓库
conan search fmt -r conancenter

# 安装依赖
conan install . --output-folder=build --build=missing

# 创建包
conan create .

# 上传包到远程仓库
conan upload mylib/1.0.0 -r myremote

# 查看包信息
conan inspect fmt/10.0.0

# 列出远程仓库
conan remote list

# 添加远程仓库
conan remote add myremote https://my.conan.server/artifactory/api/conan/conan-local

# ==========================================
# Profile（构建配置）
# ==========================================

# 查看默认profile
conan profile show

# 创建新profile
conan profile detect --name=gcc12

# Profile文件位置
# ~/.conan2/profiles/default

# profile示例
cat > ~/.conan2/profiles/linux-release << 'EOF'
[settings]
arch=x86_64
build_type=Release
compiler=gcc
compiler.cppstd=17
compiler.libcxx=libstdc++11
compiler.version=12
os=Linux

[buildenv]
CC=gcc-12
CXX=g++-12
EOF
```

**Profile详解**：

```ini
# ==========================================
# ~/.conan2/profiles/default
# ==========================================

[settings]
arch=x86_64
build_type=Release
compiler=gcc
compiler.cppstd=17
compiler.libcxx=libstdc++11
compiler.version=12
os=Linux

[options]
mylib/*:shared=True
*:fPIC=True

[buildenv]
CC=gcc
CXX=g++
CFLAGS=-march=native
CXXFLAGS=-march=native

[runenv]
LD_LIBRARY_PATH=/custom/lib

[conf]
tools.cmake.cmaketoolchain:generator=Ninja
tools.build:jobs=8
tools.system.package_manager:mode=install
tools.system.package_manager:sudo=True

# ==========================================
# 跨平台profile示例
# ==========================================

# Windows MSVC
[settings]
arch=x86_64
build_type=Release
compiler=msvc
compiler.cppstd=17
compiler.runtime=dynamic
compiler.version=193
os=Windows

# macOS Clang
[settings]
arch=armv8
build_type=Release
compiler=apple-clang
compiler.cppstd=17
compiler.libcxx=libc++
compiler.version=14
os=Macos

# 交叉编译
[settings]
arch=armv8
build_type=Release
compiler=gcc
compiler.version=11
os=Linux

[buildenv]
CC=aarch64-linux-gnu-gcc
CXX=aarch64-linux-gnu-g++
```

#### Settings / Options / Conf 三层配置体系

```
┌─────────────────────────────────────────────────────────────────────────┐
│                 Conan 三层配置体系                                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  1. Settings（全局编译环境，影响包ID）                                    │
│  ┌──────────────────────────────────────────────────────────────┐       │
│  │  定义在: settings.yml（全局）/ profile的[settings]            │       │
│  │  作用: 描述编译环境，决定二进制兼容性                         │       │
│  │                                                              │       │
│  │  os           = Linux | Windows | Macos                      │       │
│  │  arch         = x86_64 | armv8 | x86                        │       │
│  │  compiler     = gcc | clang | msvc | apple-clang             │       │
│  │  compiler.version = 12 | 13 | 14                            │       │
│  │  compiler.cppstd  = 14 | 17 | 20 | 23                      │       │
│  │  compiler.libcxx  = libstdc++11 | libc++                    │       │
│  │  build_type   = Release | Debug | RelWithDebInfo             │       │
│  └──────────────────────────────────────────────────────────────┘       │
│                                                                         │
│  2. Options（包级选项，影响包ID）                                         │
│  ┌──────────────────────────────────────────────────────────────┐       │
│  │  定义在: conanfile.py的options / profile的[options]           │       │
│  │  作用: 包的编译开关，每个包可以不同                           │       │
│  │                                                              │       │
│  │  *:shared      = True | False    ← 所有包                   │       │
│  │  *:fPIC        = True | False                                │       │
│  │  boost/*:without_locale = True   ← 特定包                   │       │
│  │  mylib/*:with_ssl = True         ← 自定义选项               │       │
│  └──────────────────────────────────────────────────────────────┘       │
│                                                                         │
│  3. Conf（工具级配置，不影响包ID）                                        │
│  ┌──────────────────────────────────────────────────────────────┐       │
│  │  定义在: profile的[conf] / global.conf / conanfile.py        │       │
│  │  作用: 控制构建工具行为，不影响二进制结果                     │       │
│  │                                                              │       │
│  │  tools.cmake.cmaketoolchain:generator = Ninja                │       │
│  │  tools.build:jobs = 8                                        │       │
│  │  tools.system.package_manager:mode = install                 │       │
│  │  tools.system.package_manager:sudo = True                    │       │
│  │  tools.build:skip_test = True                                │       │
│  │  core:default_profile = my_profile                           │       │
│  └──────────────────────────────────────────────────────────────┘       │
│                                                                         │
│  优先级: 命令行 > profile > conanfile.py > global.conf                  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### 双Profile机制（Host与Build）

```bash
# ==========================================
# 双Profile: 交叉编译的关键
# ==========================================

# -pr:h (--profile:host)    目标机器的profile
# -pr:b (--profile:build)   构建机器的profile

# 场景: 在x86_64 Linux上交叉编译ARM64 Linux
conan install . \
    -pr:b=default \              # 构建机器: x86_64 Linux
    -pr:h=arm64-linux \          # 目标机器: ARM64 Linux
    --build=missing

# 为什么需要两个profile？
# tool_requires (如protoc, cmake) 需要在构建机器上运行 → 使用build profile
# requires (如fmt, spdlog) 需要在目标机器上运行 → 使用host profile

# Profile Composition (组合/继承)
# ~/.conan2/profiles/base-linux
# [settings]
# os=Linux
# compiler=gcc
# compiler.libcxx=libstdc++11

# ~/.conan2/profiles/release
# include(base-linux)
# [settings]
# build_type=Release
# compiler.cppstd=17

# ~/.conan2/profiles/debug-asan
# include(base-linux)
# [settings]
# build_type=Debug
# [buildenv]
# CXXFLAGS=-fsanitize=address -fno-omit-frame-pointer

# 使用组合profile
conan install . -pr=release
conan install . -pr=debug-asan
```

#### Week 1 输出物清单

| 编号 | 输出物 | 说明 | 检验方式 |
|------|--------|------|----------|
| 1 | notes/conan_setup.md | Conan安装与配置笔记 | 文档完整性 |
| 2 | notes/conan2_changes.md | Conan 2.x vs 1.x变化分析 | 包含迁移要点 |
| 3 | notes/conan_profiles.md | Profile系统深入笔记 | 包含三层体系图 |
| 4 | profiles/各平台profile文件 | 多平台profile集合 | 至少4个平台 |
| 5 | notes/conan_cache.md | 缓存目录结构详解 | 包含目录结构图 |
| 6 | notes/conan_commands.md | 常用命令参考 | 命令覆盖完整 |
| 7 | notes/week1_summary.md | Week 1知识总结 | 覆盖所有知识点 |

#### Week 1 检验标准

- [ ] 能独立安装Conan 2.x并完成profile detect初始化
- [ ] 能画出Conan的核心架构图（客户端→缓存→远端仓库）
- [ ] 能列举Conan 2.x相比1.x的至少8个核心变化
- [ ] 能编写多平台Profile（Linux/macOS/Windows/交叉编译）
- [ ] 能解释Settings/Options/Conf三层配置体系的区别
- [ ] 能使用双Profile机制(-pr:h/-pr:b)进行交叉编译配置
- [ ] 能使用Profile composition实现profile继承与组合
- [ ] 能解释~/.conan2/p/目录的hash-based缓存结构
- [ ] 能管理远端仓库（remote add/login/list）

---

### 第二周：conanfile编写与CMake集成（35小时）

```
┌─────────────────────────────────────────────────────────────────┐
│  Week 2: conanfile编写与CMake集成                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Day 8-9: conanfile.txt vs conanfile.py                          │
│  ┌──────────────────────────────────────────────────┐           │
│  │  conanfile.txt:  声明式，简单消费者               │           │
│  │  conanfile.py:   编程式，完全控制（推荐）         │           │
│  │  ┌──────┐  ┌──────────┐  ┌──────────┐           │           │
│  │  │requires│ │generators│ │ options  │           │           │
│  │  └──────┘  └──────────┘  └──────────┘           │           │
│  └──────────────────────────────────────────────────┘           │
│                                                                 │
│  Day 10-11: Generators系统与Layout系统                           │
│  ┌──────────────────────────────────────────────────┐           │
│  │  CMakeDeps      → find_package()兼容文件          │           │
│  │  CMakeToolchain → conan_toolchain.cmake           │           │
│  │  PkgConfigDeps  → .pc文件                         │           │
│  │  cmake_layout   → 标准化目录结构                  │           │
│  └──────────────────────────────────────────────────┘           │
│                                                                 │
│  Day 12-14: 依赖模型与CMake集成原理                               │
│  ┌──────────────────────────────────────────────────┐           │
│  │  requires       → 运行时依赖（目标平台）          │           │
│  │  tool_requires  → 构建工具（构建平台）            │           │
│  │  test_requires  → 测试依赖（不传播）              │           │
│  │  python_requires→ 共享Python构建逻辑              │           │
│  └──────────────────────────────────────────────────┘           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### 每日任务分解

| Day | 时间 | 上午任务(2.5h) | 下午任务(2.5h) | 输出物 |
|-----|------|---------------|---------------|--------|
| 8 | 5h | conanfile.txt基础语法 | conanfile.py消费者模式 | notes/conanfile_basics.md |
| 9 | 5h | conanfile.txt vs conanfile.py深入对比 | 实践：两种方式构建同一项目 | practice/conanfile_comparison/ |
| 10 | 5h | Generators系统(CMakeDeps/CMakeToolchain) | PkgConfigDeps/MesonToolchain等其他Generator | notes/generators.md |
| 11 | 5h | Layout系统(cmake_layout/basic_layout) | 自定义layout编写 | notes/layout_system.md |
| 12 | 5h | 依赖模型(requires/tool_requires/test_requires) | 依赖传播与可见性控制 | notes/dependency_model.md |
| 13 | 5h | CMake集成原理(conan_toolchain.cmake分析) | Conan generate阶段详解 | notes/cmake_integration.md |
| 14 | 5h | 综合实践：完整Conan+CMake项目 | Week 2知识总结 | practice/conan_cmake_project/ |

**学习目标**：掌握conanfile.txt和conanfile.py的编写

**阅读材料**：
- [ ] Conan文档：conanfile.py
- [ ] Conan文档：Generators
- [ ] Conan文档：Layouts
- [ ] Conan文档：Dependencies
- [ ] Conan源码：`conan/tools/cmake/toolchain/` 目录

```txt
# ==========================================
# conanfile.txt - 简单消费者
# ==========================================
[requires]
fmt/10.0.0
spdlog/1.12.0
boost/1.82.0
nlohmann_json/3.11.2

[generators]
CMakeDeps
CMakeToolchain

[options]
boost/*:without_locale=True
boost/*:without_log=True
spdlog/*:header_only=True

[layout]
cmake_layout
```

```python
# ==========================================
# conanfile.py - 消费者（推荐）
# ==========================================
from conan import ConanFile
from conan.tools.cmake import CMake, cmake_layout, CMakeDeps, CMakeToolchain


class MyAppRecipe(ConanFile):
    name = "myapp"
    version = "1.0.0"

    # 源码设置
    settings = "os", "compiler", "build_type", "arch"

    # 依赖
    requires = (
        "fmt/10.0.0",
        "spdlog/1.12.0",
        "boost/1.82.0",
        "nlohmann_json/3.11.2",
    )

    # 构建依赖
    tool_requires = "cmake/3.27.0"

    # 选项
    options = {
        "shared": [True, False],
        "fPIC": [True, False],
    }
    default_options = {
        "shared": False,
        "fPIC": True,
        "boost/*:without_locale": True,
        "boost/*:without_log": True,
    }

    # 依赖的选项传播
    def configure(self):
        if self.options.shared:
            self.options.rm_safe("fPIC")

    def requirements(self):
        # 条件依赖
        if self.settings.os == "Windows":
            self.requires("winsock2/cci.20180802")

    def build_requirements(self):
        self.tool_requires("ninja/1.11.1")

    def layout(self):
        cmake_layout(self)

    def generate(self):
        deps = CMakeDeps(self)
        deps.generate()

        tc = CMakeToolchain(self)
        tc.variables["MY_OPTION"] = "value"
        tc.generate()

    def build(self):
        cmake = CMake(self)
        cmake.configure()
        cmake.build()

    def package(self):
        cmake = CMake(self)
        cmake.install()

    def package_info(self):
        self.cpp_info.libs = ["myapp"]
```

**CMake集成**：

```cmake
# ==========================================
# CMakeLists.txt - 使用Conan生成的文件
# ==========================================
cmake_minimum_required(VERSION 3.16)
project(MyApp VERSION 1.0.0 LANGUAGES CXX)

# 设置C++标准
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 查找Conan生成的依赖
find_package(fmt REQUIRED)
find_package(spdlog REQUIRED)
find_package(Boost REQUIRED)
find_package(nlohmann_json REQUIRED)

add_executable(myapp src/main.cpp)

target_link_libraries(myapp
    PRIVATE
        fmt::fmt
        spdlog::spdlog
        Boost::boost
        nlohmann_json::nlohmann_json
)
```

```bash
# ==========================================
# 构建流程
# ==========================================

# 安装依赖并生成CMake配置
conan install . --output-folder=build --build=missing

# 配置CMake（使用Conan生成的toolchain）
cmake -B build -S . -DCMAKE_TOOLCHAIN_FILE=build/conan_toolchain.cmake -DCMAKE_BUILD_TYPE=Release

# 构建
cmake --build build

# 或者使用CMake preset（推荐）
cmake --preset conan-release
cmake --build --preset conan-release
```

#### Generators系统详解

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Conan Generators 系统                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Generators将Conan依赖信息转换为构建系统可识别的文件                      │
│                                                                         │
│  ┌─────────────────────┬──────────────────────────────────────┐        │
│  │    Generator        │    生成文件                            │        │
│  ├─────────────────────┼──────────────────────────────────────┤        │
│  │ CMakeDeps           │ *Config.cmake / *-config.cmake        │        │
│  │                     │ (使find_package()能找到Conan包)       │        │
│  ├─────────────────────┼──────────────────────────────────────┤        │
│  │ CMakeToolchain      │ conan_toolchain.cmake                 │        │
│  │                     │ (编译器flags/标准/build_type等)       │        │
│  ├─────────────────────┼──────────────────────────────────────┤        │
│  │ PkgConfigDeps       │ *.pc 文件                              │        │
│  │                     │ (pkg-config兼容)                       │        │
│  ├─────────────────────┼──────────────────────────────────────┤        │
│  │ MesonToolchain      │ conan_meson_native/cross.ini          │        │
│  ├─────────────────────┼──────────────────────────────────────┤        │
│  │ MSBuildDeps         │ conandeps.props / conan*.props        │        │
│  │ MSBuildToolchain    │ conantoolchain.props                  │        │
│  ├─────────────────────┼──────────────────────────────────────┤        │
│  │ BazelDeps           │ BUILD.bazel / conandeps/              │        │
│  │ BazelToolchain      │ conan_bzl.rc                          │        │
│  └─────────────────────┴──────────────────────────────────────┘        │
│                                                                         │
│  推荐组合: CMakeDeps + CMakeToolchain + cmake_layout                    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### 依赖模型深入

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Conan 依赖类型体系                                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────────┐                                                   │
│  │    requires       │ ← 运行时依赖（传递给消费者）                      │
│  │  "fmt/10.0.0"     │   编译到目标二进制中                              │
│  │  "spdlog/1.12.0"  │   使用host profile                              │
│  └────────┬─────────┘                                                   │
│           │                                                              │
│  ┌────────▼─────────┐                                                   │
│  │  tool_requires    │ ← 构建工具依赖（不传递）                          │
│  │  "cmake/3.27.0"   │   只在构建时使用                                  │
│  │  "protobuf/3.21"  │   使用build profile                              │
│  │  "ninja/1.11.1"   │   如: cmake, protoc, ninja                       │
│  └────────┬─────────┘                                                   │
│           │                                                              │
│  ┌────────▼─────────┐                                                   │
│  │  test_requires    │ ← 测试依赖（不传递，不进入包）                    │
│  │  "gtest/1.14.0"   │   仅在运行测试时需要                             │
│  │  "catch2/3.4.0"   │   conan create时的test_package会用到             │
│  └────────┬─────────┘                                                   │
│           │                                                              │
│  ┌────────▼─────────┐                                                   │
│  │ python_requires   │ ← 共享Python构建逻辑                             │
│  │  "mybase/1.0.0"   │   在conanfile.py中复用代码                       │
│  │                   │   不产生C++依赖                                    │
│  └───────────────────┘                                                   │
│                                                                         │
│  依赖可见性控制:                                                         │
│  ┌───────────────────────────────────────────────────────────┐          │
│  │  self.requires("fmt/10.0.0")                → 普通依赖    │          │
│  │  self.requires("fmt/10.0.0", visible=False) → 不传播头文件│          │
│  │  self.requires("fmt/10.0.0", transitive_headers=False)    │          │
│  │  self.requires("fmt/10.0.0", transitive_libs=False)       │          │
│  └───────────────────────────────────────────────────────────┘          │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### CMake集成原理（conan_toolchain.cmake分析）

```
┌─────────────────────────────────────────────────────────────────────────┐
│           conan_toolchain.cmake 工作原理                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  conan install . → 运行generate() → 生成以下文件:                       │
│                                                                         │
│  build/                                                                  │
│  ├── conan_toolchain.cmake      ← CMakeToolchain生成                    │
│  │   ├── CMAKE_BUILD_TYPE = Release                                     │
│  │   ├── CMAKE_CXX_STANDARD = 17                                       │
│  │   ├── CMAKE_CXX_FLAGS = "-march=native ..."                         │
│  │   ├── CMAKE_PREFIX_PATH += (Conan包路径)                             │
│  │   └── 其他编译器/链接器flags                                          │
│  │                                                                       │
│  ├── fmtConfig.cmake            ← CMakeDeps为每个依赖生成               │
│  ├── fmt-config-version.cmake                                           │
│  ├── fmtTargets.cmake                                                   │
│  ├── fmt-Target-release.cmake                                           │
│  ├── spdlogConfig.cmake                                                 │
│  ├── ...                                                                │
│  │                                                                       │
│  ├── CMakePresets.json          ← 自动生成的预设文件                     │
│  │   └── conan-release preset                                           │
│  │       └── toolchainFile = conan_toolchain.cmake                      │
│  │                                                                       │
│  └── conanrun.sh / conanrun.bat ← 运行环境变量脚本                      │
│                                                                         │
│  使用流程:                                                               │
│  cmake --preset conan-release   ← 自动使用conan_toolchain.cmake        │
│  cmake --build --preset conan-release                                   │
│  或手动:                                                                 │
│  cmake -B build -DCMAKE_TOOLCHAIN_FILE=build/conan_toolchain.cmake     │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### Week 2 输出物清单

| 编号 | 输出物 | 说明 | 检验方式 |
|------|--------|------|----------|
| 1 | notes/conanfile_basics.md | conanfile编写基础 | 文档完整性 |
| 2 | practice/conanfile_comparison/ | txt vs py对比实践 | 两种方式均可构建 |
| 3 | notes/generators.md | Generators系统详解 | 包含6种Generator |
| 4 | notes/layout_system.md | Layout系统笔记 | 包含自定义layout |
| 5 | notes/dependency_model.md | 依赖模型详解 | 包含4种依赖类型 |
| 6 | notes/cmake_integration.md | CMake集成原理分析 | 包含toolchain分析 |
| 7 | practice/conan_cmake_project/ | 完整Conan+CMake项目 | conan install+cmake构建通过 |

#### Week 2 检验标准

- [ ] 能编写conanfile.txt和conanfile.py两种格式
- [ ] 能解释conanfile.txt和conanfile.py各自的适用场景
- [ ] 能使用CMakeDeps+CMakeToolchain+cmake_layout组合
- [ ] 能解释至少6种Generators的用途和生成文件
- [ ] 能区分requires/tool_requires/test_requires/python_requires
- [ ] 能解释依赖可见性控制(visible/transitive_headers)
- [ ] 能解释conan_toolchain.cmake的工作原理
- [ ] 能使用CMake Preset（conan-release/conan-debug）构建
- [ ] 能编写自定义generate()方法注入CMake变量
- [ ] 完整的Conan+CMake项目能通过构建和测试

---

### 第三周：创建和发布Conan包（35小时）

```
┌─────────────────────────────────────────────────────────────────┐
│  Week 3: 创建和发布Conan包                                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Day 15-16: 包创建完整生命周期                                   │
│  ┌──────────────────────────────────────────────────┐           │
│  │  conan export → conan create → conan upload       │           │
│  │       │              │              │              │           │
│  │  导出recipe   编译+打包+测试   上传到远端          │           │
│  └──────────────────────────────────────────────────┘           │
│                                                                 │
│  Day 17-18: package_info与组件系统                                │
│  ┌──────────────────────────────────────────────────┐           │
│  │  cpp_info.libs          ← 库文件                  │           │
│  │  cpp_info.set_property  ← CMake target名          │           │
│  │  cpp_info.components    ← 多组件包                │           │
│  │    └─ "core": libs=["core"]                       │           │
│  │    └─ "net": libs=["net"], requires=["core"]      │           │
│  └──────────────────────────────────────────────────┘           │
│                                                                 │
│  Day 19-20: 特殊类型包与非CMake项目                               │
│  ┌──────────────────────────────────────────────────┐           │
│  │  Header-only → package_type = "header-library"    │           │
│  │  Meson项目   → MesonToolchain                     │           │
│  │  Autotools   → AutotoolsToolchain                 │           │
│  │  自定义      → 手动build()/package()               │           │
│  └──────────────────────────────────────────────────┘           │
│                                                                 │
│  Day 21: test_package与ConanCenter贡献                           │
│  ┌──────────────────────────────────────────────────┐           │
│  │  test_package/conanfile.py → 最小化验证            │           │
│  │  ConanCenter贡献: fork → PR → CI验证 → 合并       │           │
│  └──────────────────────────────────────────────────┘           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### 每日任务分解

| Day | 时间 | 上午任务(2.5h) | 下午任务(2.5h) | 输出物 |
|-----|------|---------------|---------------|--------|
| 15 | 5h | conan create完整工作流分析 | export/source/build/package各阶段详解 | notes/package_lifecycle.md |
| 16 | 5h | conandata.yml源码信息管理 | 补丁机制(apply_conandata_patches) | notes/conandata.md |
| 17 | 5h | package_info基础(libs/defines/system_libs) | cpp_info组件系统(components) | notes/package_info.md |
| 18 | 5h | set_property设置CMake target名和文件名 | 实践：创建多组件Conan包 | practice/multi_component_pkg/ |
| 19 | 5h | Header-only包编写(package_type="header-library") | 非CMake项目包(Meson/Autotools) | practice/header_only_pkg/ |
| 20 | 5h | test_package最佳实践 | 阅读ConanCenter recipes(fmt/boost) | notes/test_package.md |
| 21 | 5h | ConanCenter贡献流程 | Week 3知识总结 | notes/week3_summary.md |

**学习目标**：学会创建完整的Conan包

**阅读材料**：
- [ ] Conan文档：Creating Packages
- [ ] Conan文档：Packaging Approaches
- [ ] ConanCenter贡献指南
- [ ] ConanCenter Index：`recipes/fmt/all/conanfile.py`
- [ ] Conan文档：package_info() and Components

```python
# ==========================================
# conanfile.py - 库包定义
# ==========================================
from conan import ConanFile
from conan.tools.cmake import CMake, CMakeToolchain, CMakeDeps, cmake_layout
from conan.tools.files import copy, get, rmdir, save, load
from conan.tools.build import check_min_cppstd
import os


class MyLibRecipe(ConanFile):
    name = "mylib"
    version = "1.0.0"
    license = "MIT"
    author = "Your Name <your.email@example.com>"
    url = "https://github.com/username/mylib"
    homepage = "https://github.com/username/mylib"
    description = "A modern C++ library"
    topics = ("cpp", "library", "modern")

    # 包设置
    package_type = "library"
    settings = "os", "compiler", "build_type", "arch"

    options = {
        "shared": [True, False],
        "fPIC": [True, False],
        "with_ssl": [True, False],
    }
    default_options = {
        "shared": False,
        "fPIC": True,
        "with_ssl": True,
    }

    # 导出源码和CMakeLists
    exports_sources = "CMakeLists.txt", "src/*", "include/*", "cmake/*"

    def validate(self):
        check_min_cppstd(self, "17")

    def configure(self):
        if self.options.shared:
            self.options.rm_safe("fPIC")

    def requirements(self):
        self.requires("fmt/10.0.0")
        self.requires("spdlog/1.12.0")
        if self.options.with_ssl:
            self.requires("openssl/3.1.0")

    def build_requirements(self):
        self.tool_requires("cmake/3.27.0")

    def layout(self):
        cmake_layout(self)

    def generate(self):
        deps = CMakeDeps(self)
        deps.generate()

        tc = CMakeToolchain(self)
        tc.variables["MYLIB_BUILD_SHARED"] = self.options.shared
        tc.variables["MYLIB_WITH_SSL"] = self.options.with_ssl
        tc.generate()

    def build(self):
        cmake = CMake(self)
        cmake.configure()
        cmake.build()

    def package(self):
        copy(self, "LICENSE", src=self.source_folder,
             dst=os.path.join(self.package_folder, "licenses"))
        copy(self, "*.hpp", src=os.path.join(self.source_folder, "include"),
             dst=os.path.join(self.package_folder, "include"))

        cmake = CMake(self)
        cmake.install()

        # 清理不需要的文件
        rmdir(self, os.path.join(self.package_folder, "lib", "cmake"))
        rmdir(self, os.path.join(self.package_folder, "lib", "pkgconfig"))

    def package_info(self):
        self.cpp_info.libs = ["mylib"]

        # 定义宏
        self.cpp_info.defines = ["MYLIB_VERSION={}".format(self.version)]

        if self.options.with_ssl:
            self.cpp_info.defines.append("MYLIB_WITH_SSL")

        # 设置组件（可选，用于更细粒度的依赖）
        self.cpp_info.set_property("cmake_file_name", "MyLib")
        self.cpp_info.set_property("cmake_target_name", "MyLib::MyLib")

        # 系统库依赖
        if self.settings.os in ["Linux", "FreeBSD"]:
            self.cpp_info.system_libs = ["pthread", "m"]
        elif self.settings.os == "Windows":
            self.cpp_info.system_libs = ["ws2_32"]
```

```python
# ==========================================
# 从远程源码获取的包
# ==========================================
from conan import ConanFile
from conan.tools.cmake import CMake, CMakeToolchain, cmake_layout
from conan.tools.files import get, copy
import os


class ExternalLibRecipe(ConanFile):
    name = "externallib"
    version = "2.0.0"
    license = "BSD-3-Clause"
    url = "https://github.com/original/externallib"

    settings = "os", "compiler", "build_type", "arch"
    options = {"shared": [True, False], "fPIC": [True, False]}
    default_options = {"shared": False, "fPIC": True}

    def source(self):
        get(self, **self.conan_data["sources"][self.version], strip_root=True)

    def layout(self):
        cmake_layout(self, src_folder="src")

    def generate(self):
        tc = CMakeToolchain(self)
        tc.variables["BUILD_SHARED_LIBS"] = self.options.shared
        tc.variables["BUILD_TESTS"] = False
        tc.generate()

    def build(self):
        cmake = CMake(self)
        cmake.configure()
        cmake.build()

    def package(self):
        copy(self, "LICENSE*", src=self.source_folder,
             dst=os.path.join(self.package_folder, "licenses"))
        cmake = CMake(self)
        cmake.install()

    def package_info(self):
        self.cpp_info.libs = ["externallib"]
```

```yaml
# ==========================================
# conandata.yml - 源码信息
# ==========================================
sources:
  "2.0.0":
    url: "https://github.com/original/externallib/archive/v2.0.0.tar.gz"
    sha256: "abc123..."
  "1.9.0":
    url: "https://github.com/original/externallib/archive/v1.9.0.tar.gz"
    sha256: "def456..."

patches:
  "2.0.0":
    - patch_file: "patches/fix_windows.patch"
      patch_description: "Fix Windows build"
      patch_type: "portability"
```

#### conan create 完整工作流

```
┌─────────────────────────────────────────────────────────────────────────┐
│                  conan create . 完整工作流                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  1. Export阶段                                                          │
│  ┌────────────────────────────────────────────────────────────┐        │
│  │  将recipe导出到本地缓存                                     │        │
│  │  conanfile.py + conandata.yml → ~/.conan2/p/<hash>/e/      │        │
│  │  export_sources中的文件 → 缓存                              │        │
│  └────────────────────────────────────────────────────────────┘        │
│                         │                                               │
│  2. Source阶段          ▼                                               │
│  ┌────────────────────────────────────────────────────────────┐        │
│  │  调用 source() 方法获取源码                                 │        │
│  │  get(self, **self.conan_data["sources"][self.version])      │        │
│  │  下载 → 校验SHA256 → 解压 → ~/.conan2/p/<hash>/s/          │        │
│  │  应用补丁: apply_conandata_patches(self)                    │        │
│  └────────────────────────────────────────────────────────────┘        │
│                         │                                               │
│  3. Generate阶段       ▼                                               │
│  ┌────────────────────────────────────────────────────────────┐        │
│  │  调用 generate() 方法生成构建文件                           │        │
│  │  CMakeDeps → *Config.cmake文件                              │        │
│  │  CMakeToolchain → conan_toolchain.cmake                     │        │
│  └────────────────────────────────────────────────────────────┘        │
│                         │                                               │
│  4. Build阶段          ▼                                               │
│  ┌────────────────────────────────────────────────────────────┐        │
│  │  调用 build() 方法编译                                      │        │
│  │  cmake.configure() → cmake.build()                          │        │
│  │  构建产物 → ~/.conan2/p/<hash>/b/<build_hash>/              │        │
│  └────────────────────────────────────────────────────────────┘        │
│                         │                                               │
│  5. Package阶段        ▼                                               │
│  ┌────────────────────────────────────────────────────────────┐        │
│  │  调用 package() 方法打包                                    │        │
│  │  cmake.install() → copy头文件/库文件/LICENSE                 │        │
│  │  → ~/.conan2/p/<hash>/p/<pkg_hash>/                         │        │
│  │    ├── include/                                              │        │
│  │    ├── lib/                                                  │        │
│  │    ├── licenses/                                             │        │
│  │    └── conaninfo.txt + conanmanifest.txt                    │        │
│  └────────────────────────────────────────────────────────────┘        │
│                         │                                               │
│  6. Test阶段           ▼                                               │
│  ┌────────────────────────────────────────────────────────────┐        │
│  │  运行 test_package/conanfile.py                             │        │
│  │  安装刚创建的包作为依赖 → 编译测试程序 → 运行测试           │        │
│  │  验证包的安装是否正确                                        │        │
│  └────────────────────────────────────────────────────────────┘        │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### package_info组件系统详解

```python
# ==========================================
# 多组件包的package_info（如Boost）
# ==========================================

def package_info(self):
    # === 基本设置 ===
    # CMake文件名: find_package(MyLib)
    self.cpp_info.set_property("cmake_file_name", "MyLib")

    # === 组件定义 ===
    # 组件: MyLib::core
    self.cpp_info.components["core"].libs = ["mylib_core"]
    self.cpp_info.components["core"].set_property(
        "cmake_target_name", "MyLib::core")
    self.cpp_info.components["core"].defines = ["MYLIB_CORE"]
    self.cpp_info.components["core"].requires = ["fmt::fmt"]

    if self.settings.os in ["Linux", "FreeBSD"]:
        self.cpp_info.components["core"].system_libs = ["pthread"]

    # 组件: MyLib::net (依赖core)
    self.cpp_info.components["net"].libs = ["mylib_net"]
    self.cpp_info.components["net"].set_property(
        "cmake_target_name", "MyLib::net")
    self.cpp_info.components["net"].requires = [
        "core",                    # 内部组件依赖
        "boost::boost",            # 外部包依赖
    ]

    if self.options.with_ssl:
        self.cpp_info.components["net"].requires.append("openssl::openssl")
        self.cpp_info.components["net"].defines.append("MYLIB_WITH_SSL")

    # 组件: MyLib::utils (header-only组件)
    self.cpp_info.components["utils"].set_property(
        "cmake_target_name", "MyLib::utils")
    self.cpp_info.components["utils"].includedirs = ["include"]
    # header-only不需要libs

    # 使用方式:
    # find_package(MyLib REQUIRED)
    # target_link_libraries(app PRIVATE MyLib::core MyLib::net)
```

#### Header-only包编写

```python
# ==========================================
# Header-only库的Conan包
# ==========================================
from conan import ConanFile
from conan.tools.files import copy
from conan.tools.layout import basic_layout
import os


class HeaderOnlyRecipe(ConanFile):
    name = "my-header-lib"
    version = "1.0.0"
    license = "MIT"

    # 关键: 声明为header-library
    package_type = "header-library"

    # Header-only不受settings影响
    # 但仍需声明以支持consumer的settings
    settings = "os", "compiler", "build_type", "arch"

    # 没有options（无需shared/fPIC）
    exports_sources = "include/*", "LICENSE"

    # 不需要settings影响package_id
    # Conan 2.x对header-library自动处理

    def layout(self):
        basic_layout(self)

    # 不需要build() — 没有编译步骤

    def package(self):
        copy(self, "LICENSE", src=self.source_folder,
             dst=os.path.join(self.package_folder, "licenses"))
        copy(self, "*.hpp", src=os.path.join(self.source_folder, "include"),
             dst=os.path.join(self.package_folder, "include"))

    def package_info(self):
        # Header-only: bindirs和libdirs为空
        self.cpp_info.bindirs = []
        self.cpp_info.libdirs = []

        self.cpp_info.set_property("cmake_file_name", "MyHeaderLib")
        self.cpp_info.set_property("cmake_target_name", "MyHeaderLib::MyHeaderLib")

    def package_id(self):
        # Header-only包: 所有配置共享同一个包
        self.info.clear()
```

#### 非CMake项目包编写

```python
# ==========================================
# 基于Autotools的库包
# ==========================================
from conan import ConanFile
from conan.tools.gnu import AutotoolsToolchain, Autotools, AutotoolsDeps
from conan.tools.files import get, copy, rmdir
from conan.tools.layout import basic_layout
import os


class AutotoolsLibRecipe(ConanFile):
    name = "legacy-lib"
    version = "1.0.0"
    settings = "os", "compiler", "build_type", "arch"
    options = {"shared": [True, False], "fPIC": [True, False]}
    default_options = {"shared": False, "fPIC": True}

    def source(self):
        get(self, **self.conan_data["sources"][self.version], strip_root=True)

    def layout(self):
        basic_layout(self)

    def generate(self):
        deps = AutotoolsDeps(self)
        deps.generate()

        tc = AutotoolsToolchain(self)
        tc.configure_args.append("--disable-docs")
        tc.generate()

    def build(self):
        autotools = Autotools(self)
        autotools.autoreconf()   # 如果需要
        autotools.configure()
        autotools.make()

    def package(self):
        autotools = Autotools(self)
        autotools.install()

        copy(self, "COPYING", src=self.source_folder,
             dst=os.path.join(self.package_folder, "licenses"))
        rmdir(self, os.path.join(self.package_folder, "lib", "pkgconfig"))

    def package_info(self):
        self.cpp_info.libs = ["legacy"]
```

```python
# ==========================================
# 基于Meson的库包
# ==========================================
from conan import ConanFile
from conan.tools.meson import MesonToolchain, Meson
from conan.tools.files import get, copy
import os


class MesonLibRecipe(ConanFile):
    name = "meson-lib"
    version = "2.0.0"
    settings = "os", "compiler", "build_type", "arch"
    options = {"shared": [True, False], "fPIC": [True, False]}
    default_options = {"shared": False, "fPIC": True}

    def source(self):
        get(self, **self.conan_data["sources"][self.version], strip_root=True)

    def generate(self):
        tc = MesonToolchain(self)
        tc.project_options["tests"] = "false"
        tc.generate()

    def build(self):
        meson = Meson(self)
        meson.configure()
        meson.build()

    def package(self):
        meson = Meson(self)
        meson.install()
        copy(self, "LICENSE", src=self.source_folder,
             dst=os.path.join(self.package_folder, "licenses"))

    def package_info(self):
        self.cpp_info.libs = ["mesonlib"]
```

#### Week 3 输出物清单

| 编号 | 输出物 | 说明 | 检验方式 |
|------|--------|------|----------|
| 1 | notes/package_lifecycle.md | 包创建生命周期详解 | 包含6阶段流程图 |
| 2 | notes/conandata.md | conandata.yml与补丁机制 | 包含补丁应用示例 |
| 3 | notes/package_info.md | package_info详解 | 包含组件系统 |
| 4 | practice/multi_component_pkg/ | 多组件包实践 | conan create通过 |
| 5 | practice/header_only_pkg/ | Header-only包 | conan create通过 |
| 6 | notes/test_package.md | test_package最佳实践 | 包含完整示例 |
| 7 | notes/week3_summary.md | Week 3知识总结 | 覆盖所有知识点 |

#### Week 3 检验标准

- [ ] 能解释conan create的6个阶段（export→source→generate→build→package→test）
- [ ] 能编写完整的conandata.yml（含sources和patches）
- [ ] 能使用package_info定义库信息（libs/defines/system_libs）
- [ ] 能使用cpp_info.components定义多组件包
- [ ] 能使用set_property设置CMake target名
- [ ] 能为Header-only库编写Conan包（package_type="header-library"）
- [ ] 能为Autotools项目编写Conan包
- [ ] 能为Meson项目编写Conan包
- [ ] 能编写正确的test_package验证包安装
- [ ] 能通过conan create成功创建并测试自定义包

---

### 第四周：高级特性与最佳实践（35小时）

```
┌─────────────────────────────────────────────────────────────────┐
│  Week 4: 高级特性与最佳实践                                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Day 22-23: Lockfile与依赖图分析                                 │
│  ┌──────────────────────────────────────────────────┐           │
│  │  conan lock create → conan.lock                   │           │
│  │  conan graph info → 依赖图可视化                  │           │
│  │  conan graph build-order → CI构建顺序             │           │
│  └──────────────────────────────────────────────────┘           │
│                                                                 │
│  Day 24-25: 私有仓库与python_requires                            │
│  ┌──────────────────────────────────────────────────┐           │
│  │  Artifactory                                      │           │
│  │  ┌──────┐  ┌──────┐  ┌───────┐                  │           │
│  │  │Local │  │Remote│  │Virtual│                  │           │
│  │  │Repo  │  │Proxy │  │ Repo  │                  │           │
│  │  └──────┘  └──────┘  └───────┘                  │           │
│  │  python_requires: 共享构建逻辑                    │           │
│  └──────────────────────────────────────────────────┘           │
│                                                                 │
│  Day 26-28: 深度对比与企业实践                                    │
│  ┌──────────────────────────────────────────────────┐           │
│  │  vcpkg vs Conan 深度对比(10个维度)                │           │
│  │  企业级Conan最佳实践                              │           │
│  │  Hook系统与自定义扩展                             │           │
│  │  CI/CD中的Conan集成                               │           │
│  └──────────────────────────────────────────────────┘           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### 每日任务分解

| Day | 时间 | 上午任务(2.5h) | 下午任务(2.5h) | 输出物 |
|-----|------|---------------|---------------|--------|
| 22 | 5h | Lockfile原理与使用 | conan graph info依赖图可视化 | notes/lockfiles.md |
| 23 | 5h | conan graph build-order与CI集成 | 依赖冲突解决策略 | notes/graph_analysis.md |
| 24 | 5h | Artifactory架构(Local/Remote/Virtual) | Conan Server搭建与配置 | notes/conan_server.md |
| 25 | 5h | python_requires共享构建逻辑 | Hook系统与自定义扩展 | practice/python_requires/ |
| 26 | 5h | vcpkg vs Conan深度对比(10维度) | 包管理器选型决策框架 | notes/vcpkg_vs_conan_deep.md |
| 27 | 5h | 企业级Conan最佳实践 | CI/CD中的Conan集成(GitHub Actions) | .github/workflows/conan.yml |
| 28 | 5h | 月度知识总结 | 准备Month 40预习 | notes/month39_summary.md |

**学习目标**：掌握Conan的高级用法

**阅读材料**：
- [ ] Conan文档：Lockfiles
- [ ] Conan文档：Graph Analysis
- [ ] Conan文档：python_requires
- [ ] Conan文档：Hooks
- [ ] JFrog Artifactory文档：Conan仓库配置

```python
# ==========================================
# 测试包（test_package/conanfile.py）
# ==========================================
from conan import ConanFile
from conan.tools.cmake import CMake, cmake_layout
from conan.tools.build import can_run
import os


class MyLibTestConan(ConanFile):
    settings = "os", "compiler", "build_type", "arch"
    generators = "CMakeDeps", "CMakeToolchain"

    def requirements(self):
        self.requires(self.tested_reference_str)

    def layout(self):
        cmake_layout(self)

    def build(self):
        cmake = CMake(self)
        cmake.configure()
        cmake.build()

    def test(self):
        if can_run(self):
            cmd = os.path.join(self.cpp.build.bindir, "example")
            self.run(cmd, env="conanrun")
```

```cpp
// test_package/src/example.cpp
#include <mylib/mylib.hpp>
#include <iostream>

int main() {
    std::cout << "MyLib version: " << mylib::version() << std::endl;
    return 0;
}
```

```bash
# ==========================================
# Lockfile管理（版本锁定）
# ==========================================

# 生成lockfile
conan lock create .

# 使用lockfile安装
conan install . --lockfile=conan.lock

# 更新特定依赖
conan lock create . --lockfile=conan.lock --lockfile-out=conan.lock --update

# 查看依赖图
conan graph info . --format=html > graph.html

# ==========================================
# 私有仓库设置
# ==========================================

# 添加Artifactory仓库
conan remote add artifactory https://company.jfrog.io/artifactory/api/conan/conan-local
conan remote login artifactory user -p password

# 上传包
conan create .
conan upload mylib/1.0.0 -r artifactory --all

# ==========================================
# 多配置构建
# ==========================================

# 同时构建多个配置
conan install . -s build_type=Debug --output-folder=build-debug --build=missing
conan install . -s build_type=Release --output-folder=build-release --build=missing

# 使用profile文件
conan install . -pr:b=default -pr:h=linux-arm64 --output-folder=build-arm64
```

```python
# ==========================================
# 高级conanfile.py特性
# ==========================================
from conan import ConanFile
from conan.tools.cmake import CMake, cmake_layout
from conan.tools.files import copy, save
from conan.tools.scm import Git
import os


class AdvancedRecipe(ConanFile):
    name = "advanced"
    version = "1.0.0"

    settings = "os", "compiler", "build_type", "arch"

    def export(self):
        # 导出时执行的操作
        git = Git(self)
        scm_url, scm_commit = git.get_url_and_commit()
        save(self, os.path.join(self.export_folder, "scm_info.txt"),
             f"{scm_url}\n{scm_commit}")

    def set_version(self):
        # 动态设置版本号
        git = Git(self)
        self.version = git.run("describe --tags --abbrev=0").strip()

    def export_sources(self):
        # 导出源码时执行
        copy(self, "*", src=self.recipe_folder,
             dst=self.export_sources_folder,
             excludes=["build*", ".git*", "*.pyc"])

    def generate(self):
        # 生成版本头文件
        version_header = f'''
#pragma once
#define ADVANCED_VERSION_MAJOR {self.version.split(".")[0]}
#define ADVANCED_VERSION_MINOR {self.version.split(".")[1]}
#define ADVANCED_VERSION_PATCH {self.version.split(".")[2]}
#define ADVANCED_VERSION "{self.version}"
'''
        save(self, os.path.join(self.build_folder, "version.hpp"), version_header)

    def package_id(self):
        # 自定义包ID计算
        # 忽略某些选项
        self.info.options.rm_safe("with_tests")

        # 兼容性设置
        if self.info.settings.compiler == "gcc":
            if self.info.settings.compiler.version >= "10":
                self.info.settings.compiler.version = "10+"

    def compatibility(self):
        # 定义包兼容性
        return [
            {"settings": [("compiler.version", v) for v in ("11", "12", "13")]}
        ]
```

#### Lockfile工作原理

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Conan Lockfile 工作原理                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  问题: 不同时间/机器上conan install可能解析出不同版本                     │
│  解决: Lockfile记录完整的依赖图快照                                      │
│                                                                         │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐            │
│  │ conan lock    │ ──▶ │  conan.lock  │ ──▶ │ conan install│            │
│  │    create     │     │  (JSON文件)  │     │  --lockfile  │            │
│  └──────────────┘     └──────────────┘     └──────────────┘            │
│                                                                         │
│  conan.lock 记录内容:                                                    │
│  ┌──────────────────────────────────────────────────────────┐          │
│  │  {                                                        │          │
│  │    "version": "0.5",                                      │          │
│  │    "requires": [                                          │          │
│  │      "fmt/10.0.0#abc123...",     ← recipe revision        │          │
│  │      "spdlog/1.12.0#def456...",                           │          │
│  │      "boost/1.82.0#789abc..."                             │          │
│  │    ],                                                     │          │
│  │    "build_requires": [                                    │          │
│  │      "cmake/3.27.0#111222..."                             │          │
│  │    ]                                                      │          │
│  │  }                                                        │          │
│  └──────────────────────────────────────────────────────────┘          │
│                                                                         │
│  关键概念: Recipe Revision (RREV)                                        │
│  ┌──────────────────────────────────────────────────────────┐          │
│  │  fmt/10.0.0#abc123                                        │          │
│  │            ^^^^^^^^                                       │          │
│  │            recipe revision = conanfile.py内容的hash        │          │
│  │            同一版本，不同的portfile修改 → 不同的RREV       │          │
│  └──────────────────────────────────────────────────────────┘          │
│                                                                         │
│  Lockfile工作流:                                                         │
│  开发者: conan lock create . → 提交 conan.lock 到 git                   │
│  CI:     conan install . --lockfile=conan.lock → 使用锁定版本           │
│  更新:   conan lock create . --lockfile-out=new.lock → 更新锁           │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### Conan Server / Artifactory架构

```
┌─────────────────────────────────────────────────────────────────────────┐
│                  企业级Conan仓库架构 (Artifactory)                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────┐       │
│  │                    JFrog Artifactory                          │       │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │       │
│  │  │ conan-local   │  │ conan-remote │  │ conan-virtual│      │       │
│  │  │ (本地仓库)    │  │ (远端代理)   │  │ (虚拟聚合)   │      │       │
│  │  │              │  │              │  │              │      │       │
│  │  │ 存储内部包   │  │ 代理         │  │ 聚合local    │      │       │
│  │  │ mylib/1.0.0  │  │ ConanCenter  │  │ + remote     │      │       │
│  │  │ internal/2.0 │  │ 缓存外部包   │  │ 统一访问入口 │      │       │
│  │  └──────────────┘  └──────────────┘  └──────────────┘      │       │
│  └─────────────────────────────────────────────────────────────┘       │
│                                                                         │
│  开发者配置:                                                             │
│  conan remote add company https://company.jfrog.io/artifactory/        │
│                            api/conan/conan-virtual                       │
│  只需一个remote → virtual仓库自动聚合内部包+外部包                       │
│                                                                         │
│  轻量替代: Conan Server (开源)                                           │
│  ┌──────────────────────────────────────────────────────────────┐      │
│  │  pip install conan_server                                     │      │
│  │  conan_server  # 默认端口9300                                  │      │
│  │  conan remote add local http://localhost:9300                  │      │
│  │  功能有限: 无缓存代理、无权限管理、无虚拟仓库                  │      │
│  └──────────────────────────────────────────────────────────────┘      │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### python_requires——共享构建逻辑

```python
# ==========================================
# python_requires: 基类包 (mycompany-base/1.0.0)
# ==========================================
# mycompany_base/conanfile.py
from conan import ConanFile
from conan.tools.cmake import CMake, CMakeToolchain, CMakeDeps, cmake_layout


class MyCompanyBase:
    """公司统一的构建基类"""

    settings = "os", "compiler", "build_type", "arch"
    options = {"shared": [True, False], "fPIC": [True, False]}
    default_options = {"shared": False, "fPIC": True}

    def configure(self):
        if self.options.shared:
            self.options.rm_safe("fPIC")

    def layout(self):
        cmake_layout(self)

    def generate(self):
        deps = CMakeDeps(self)
        deps.generate()
        tc = CMakeToolchain(self)
        tc.variables["CMAKE_CXX_STANDARD"] = "17"
        tc.variables["CMAKE_CXX_STANDARD_REQUIRED"] = "ON"
        tc.generate()

    def build(self):
        cmake = CMake(self)
        cmake.configure()
        cmake.build()

    def package(self):
        cmake = CMake(self)
        cmake.install()


class MyCompanyBaseRecipe(ConanFile):
    name = "mycompany-base"
    version = "1.0.0"
    exports_sources = "conanfile.py"
```

```python
# ==========================================
# 使用python_requires的子包
# ==========================================
from conan import ConanFile
from conan.tools.files import copy
import os


class MyServiceRecipe(ConanFile):
    name = "my-service"
    version = "2.0.0"

    # 引用基类包
    python_requires = "mycompany-base/1.0.0"
    python_requires_extend = "mycompany-base.MyCompanyBase"

    # 继承了: settings, options, configure, layout, generate, build, package

    exports_sources = "CMakeLists.txt", "src/*", "include/*"

    def requirements(self):
        self.requires("fmt/10.0.0")
        self.requires("spdlog/1.12.0")

    def package_info(self):
        self.cpp_info.libs = ["my_service"]
```

#### CI/CD中的Conan集成

```yaml
# ==========================================
# .github/workflows/conan-ci.yml
# ==========================================
name: C++ CI with Conan

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    strategy:
      matrix:
        include:
          - os: ubuntu-latest
            profile: linux-gcc
          - os: macos-latest
            profile: macos-clang
          - os: windows-latest
            profile: windows-msvc

    runs-on: ${{ matrix.os }}

    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install Conan
        run: |
          pip install conan
          conan profile detect

      - name: Cache Conan packages
        uses: actions/cache@v4
        with:
          path: ~/.conan2
          key: conan-${{ matrix.os }}-${{ hashFiles('conanfile.py', 'conan.lock') }}
          restore-keys: conan-${{ matrix.os }}-

      - name: Install dependencies
        run: |
          conan install . \
            --output-folder=build \
            --build=missing \
            -s build_type=Release

      - name: Build
        run: |
          cmake --preset conan-release
          cmake --build --preset conan-release

      - name: Test
        run: ctest --preset conan-release --output-on-failure
```

#### vcpkg vs Conan 深度对比

```
┌─────────────────────────────────────────────────────────────────────────┐
│                  vcpkg vs Conan 深度对比（10个维度）                      │
├──────────────────────┬──────────────────┬───────────────────────────────┤
│      维度            │    vcpkg         │    Conan                      │
├──────────────────────┼──────────────────┼───────────────────────────────┤
│ 1. 实现语言           │ C++ (vcpkg-tool) │ Python                       │
│ 2. 包描述语言         │ CMake(portfile)  │ Python(conanfile.py)          │
│ 3. 构建方式           │ 始终源码编译      │ 二进制优先,按需源码编译        │
│ 4. 包ID计算           │ ABI hash         │ settings+options+requires     │
│ 5. 二进制兼容         │ 简单(triplet)     │ 精细(package_id/compatibility)│
│ 6. 版本控制           │ baseline+override │ ranges+lockfile+revisions    │
│ 7. 私有仓库           │ Git Registry     │ Artifactory/Server(更成熟)    │
│ 8. 多构建系统         │ CMake为主        │ CMake/Meson/Autotools/Bazel   │
│ 9. 交叉编译           │ triplet文件      │ 双profile(-pr:h/-pr:b)        │
│ 10. 包数量(2024)      │ ~2,500 ports     │ ~1,500 recipes               │
├──────────────────────┴──────────────────┴───────────────────────────────┤
│                                                                         │
│  选型建议:                                                               │
│  ┌──────────────────────────────────────────────────────────────┐       │
│  │  选vcpkg:                                                    │       │
│  │  • 纯CMake项目                                                │       │
│  │  • Windows/VS开发优先                                         │       │
│  │  • 团队不熟悉Python                                           │       │
│  │  • 新项目/小团队/快速起步                                      │       │
│  │  • 不需要精细二进制兼容控制                                    │       │
│  │                                                               │       │
│  │  选Conan:                                                     │       │
│  │  • 多构建系统混合(CMake+Meson+...)                            │       │
│  │  • 需要精细控制二进制兼容性(package_id)                       │       │
│  │  • 企业已有Artifactory基础设施                                │       │
│  │  • 需要成熟的私有仓库方案                                     │       │
│  │  • 大型组织级包管理                                           │       │
│  │  • 需要python_requires共享构建逻辑                            │       │
│  │                                                               │       │
│  │  两者共存:                                                    │       │
│  │  • 可以在同一项目中同时使用(互不干扰)                         │       │
│  │  • vcpkg管理部分依赖 + Conan管理部分依赖                     │       │
│  └──────────────────────────────────────────────────────────────┘       │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### 企业级Conan最佳实践

```
┌─────────────────────────────────────────────────────────────────────────┐
│                企业级 Conan 最佳实践                                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  1. 仓库架构                                                            │
│  ┌───────────────────────────────────────────────────────┐              │
│  │  Artifactory:                                          │              │
│  │  ├── conan-local       ← 内部包（自研库）              │              │
│  │  ├── conan-staging     ← 测试中的包                    │              │
│  │  ├── conan-release     ← 已验证发布的包                │              │
│  │  ├── conan-proxy       ← ConanCenter代理缓存          │              │
│  │  └── conan-virtual     ← 聚合所有仓库                  │              │
│  └───────────────────────────────────────────────────────┘              │
│                                                                         │
│  2. 版本策略                                                            │
│  ┌───────────────────────────────────────────────────────┐              │
│  │  • 所有项目使用conan.lock提交到git                     │              │
│  │  • 定期更新lockfile（如每月一次）                      │              │
│  │  • 安全补丁时立即更新对应依赖                          │              │
│  │  • 使用version ranges时限定主版本: [>1.0 <2.0]        │              │
│  └───────────────────────────────────────────────────────┘              │
│                                                                         │
│  3. CI/CD集成                                                           │
│  ┌───────────────────────────────────────────────────────┐              │
│  │  • 使用graph build-order确定多包构建顺序               │              │
│  │  • 利用二进制缓存避免重复编译                          │              │
│  │  • 不同分支使用不同的remote channel                    │              │
│  │    - main分支 → stable channel                         │              │
│  │    - develop分支 → testing channel                     │              │
│  │  • PR合并前自动运行conan create验证                    │              │
│  └───────────────────────────────────────────────────────┘              │
│                                                                         │
│  4. 安全治理                                                            │
│  ┌───────────────────────────────────────────────────────┐              │
│  │  • 使用Hooks验证包的license合规性                      │              │
│  │  • 扫描依赖的CVE漏洞(结合JFrog Xray)                 │              │
│  │  • 限制可使用的外部包列表(白名单机制)                  │              │
│  │  • 审核python_requires的变更                           │              │
│  └───────────────────────────────────────────────────────┘              │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### Week 4 输出物清单

| 编号 | 输出物 | 说明 | 检验方式 |
|------|--------|------|----------|
| 1 | notes/lockfiles.md | Lockfile原理与使用 | 包含工作流图 |
| 2 | notes/graph_analysis.md | 依赖图分析笔记 | 包含graph命令 |
| 3 | notes/conan_server.md | 仓库架构与配置 | 包含Artifactory |
| 4 | practice/python_requires/ | python_requires实践 | conan create通过 |
| 5 | notes/vcpkg_vs_conan_deep.md | 深度对比分析(10维度) | 对比表完整 |
| 6 | .github/workflows/conan.yml | CI/CD集成配置 | CI运行通过 |
| 7 | notes/month39_summary.md | 月度总结 | 覆盖所有知识点 |

#### Week 4 检验标准

- [ ] 能创建conan.lock并使用lockfile确保依赖可重现
- [ ] 能解释Recipe Revision(RREV)的概念和作用
- [ ] 能使用conan graph info分析依赖图
- [ ] 能使用conan graph build-order规划CI构建顺序
- [ ] 能配置Artifactory的Local/Remote/Virtual仓库
- [ ] 能编写python_requires共享构建逻辑并在子包中继承
- [ ] 能编写GitHub Actions CI/CD流水线（含Conan缓存）
- [ ] 能从10个维度对比vcpkg和Conan
- [ ] 能为企业设计Conan仓库架构和版本策略
- [ ] 综合项目config-lib构建+测试+CI全部通过

---

## 源码阅读任务

### 本月源码阅读

1. **Conan客户端源码**
   - 仓库：https://github.com/conan-io/conan
   - 重点：`conan/tools/cmake/` 目录
   - 学习目标：理解CMake集成的实现

2. **ConanCenter索引**
   - 仓库：https://github.com/conan-io/conan-center-index
   - 重点：`recipes/fmt`、`recipes/boost`
   - 学习目标：学习高质量recipe的编写

3. **Conan与vcpkg对比**
   - 分析两者的设计理念差异
   - 理解各自的优缺点

---

## 实践项目

### 项目：跨平台配置管理库

创建一个使用Conan管理的配置管理库，支持YAML、JSON、TOML格式。

**项目结构**：

```
config-lib/
├── conanfile.py
├── conandata.yml
├── CMakeLists.txt
├── include/
│   └── configlib/
│       ├── config.hpp
│       ├── parser.hpp
│       ├── json_parser.hpp
│       ├── yaml_parser.hpp
│       └── toml_parser.hpp
├── src/
│   ├── CMakeLists.txt
│   ├── config.cpp
│   ├── json_parser.cpp
│   ├── yaml_parser.cpp
│   └── toml_parser.cpp
├── tests/
│   ├── CMakeLists.txt
│   └── test_config.cpp
└── test_package/
    ├── conanfile.py
    ├── CMakeLists.txt
    └── src/
        └── example.cpp
```

**conanfile.py**：

```python
from conan import ConanFile
from conan.tools.cmake import CMake, CMakeToolchain, CMakeDeps, cmake_layout
from conan.tools.files import copy
from conan.tools.build import check_min_cppstd
import os


class ConfigLibRecipe(ConanFile):
    name = "configlib"
    version = "1.0.0"
    license = "MIT"
    author = "Your Name <your.email@example.com>"
    url = "https://github.com/username/configlib"
    description = "A cross-platform configuration library supporting JSON, YAML, and TOML"
    topics = ("config", "json", "yaml", "toml", "modern-cpp")

    package_type = "library"
    settings = "os", "compiler", "build_type", "arch"

    options = {
        "shared": [True, False],
        "fPIC": [True, False],
        "with_yaml": [True, False],
        "with_toml": [True, False],
    }
    default_options = {
        "shared": False,
        "fPIC": True,
        "with_yaml": True,
        "with_toml": True,
    }

    exports_sources = "CMakeLists.txt", "src/*", "include/*", "cmake/*"

    def validate(self):
        check_min_cppstd(self, "17")

    def configure(self):
        if self.options.shared:
            self.options.rm_safe("fPIC")

    def requirements(self):
        self.requires("nlohmann_json/3.11.2")
        self.requires("fmt/10.0.0")
        if self.options.with_yaml:
            self.requires("yaml-cpp/0.8.0")
        if self.options.with_toml:
            self.requires("toml11/3.7.1")

    def build_requirements(self):
        self.test_requires("gtest/1.14.0")

    def layout(self):
        cmake_layout(self)

    def generate(self):
        deps = CMakeDeps(self)
        deps.generate()

        tc = CMakeToolchain(self)
        tc.variables["CONFIGLIB_BUILD_SHARED"] = self.options.shared
        tc.variables["CONFIGLIB_WITH_YAML"] = self.options.with_yaml
        tc.variables["CONFIGLIB_WITH_TOML"] = self.options.with_toml
        tc.variables["CONFIGLIB_BUILD_TESTS"] = not self.conf.get(
            "tools.build:skip_test", default=False)
        tc.generate()

    def build(self):
        cmake = CMake(self)
        cmake.configure()
        cmake.build()
        if not self.conf.get("tools.build:skip_test", default=False):
            cmake.test()

    def package(self):
        copy(self, "LICENSE", src=self.source_folder,
             dst=os.path.join(self.package_folder, "licenses"))
        cmake = CMake(self)
        cmake.install()

    def package_info(self):
        self.cpp_info.libs = ["configlib"]

        self.cpp_info.set_property("cmake_file_name", "ConfigLib")
        self.cpp_info.set_property("cmake_target_name", "ConfigLib::ConfigLib")

        if self.options.with_yaml:
            self.cpp_info.defines.append("CONFIGLIB_WITH_YAML")
        if self.options.with_toml:
            self.cpp_info.defines.append("CONFIGLIB_WITH_TOML")
```

**include/configlib/config.hpp**：

```cpp
#pragma once

#include <string>
#include <string_view>
#include <memory>
#include <variant>
#include <vector>
#include <map>
#include <optional>
#include <stdexcept>
#include <filesystem>

namespace configlib {

// 前向声明
class ConfigNode;
class ConfigParser;

/**
 * @brief 配置值类型
 */
using ConfigValue = std::variant<
    std::nullptr_t,
    bool,
    int64_t,
    double,
    std::string,
    std::vector<ConfigNode>,
    std::map<std::string, ConfigNode>
>;

/**
 * @brief 配置节点
 */
class ConfigNode {
public:
    ConfigNode() : value_(nullptr) {}
    ConfigNode(ConfigValue value) : value_(std::move(value)) {}

    // 类型检查
    bool is_null() const;
    bool is_bool() const;
    bool is_int() const;
    bool is_double() const;
    bool is_string() const;
    bool is_array() const;
    bool is_object() const;

    // 值获取（带默认值）
    template<typename T>
    T get(T default_value = T{}) const;

    // 值获取（可能抛出异常）
    template<typename T>
    T as() const;

    // 数组访问
    const ConfigNode& operator[](size_t index) const;
    size_t size() const;

    // 对象访问
    const ConfigNode& operator[](std::string_view key) const;
    bool contains(std::string_view key) const;
    std::vector<std::string> keys() const;

    // 获取可选值
    template<typename T>
    std::optional<T> get_optional() const;

    // 路径访问（支持点分隔）
    const ConfigNode& at(std::string_view path) const;
    std::optional<std::reference_wrapper<const ConfigNode>>
        find(std::string_view path) const;

private:
    ConfigValue value_;
    static const ConfigNode null_node_;
};

/**
 * @brief 配置异常
 */
class ConfigError : public std::runtime_error {
public:
    using std::runtime_error::runtime_error;
};

class ConfigParseError : public ConfigError {
public:
    ConfigParseError(const std::string& msg, size_t line = 0, size_t column = 0)
        : ConfigError(msg), line_(line), column_(column) {}

    size_t line() const { return line_; }
    size_t column() const { return column_; }

private:
    size_t line_;
    size_t column_;
};

class ConfigTypeError : public ConfigError {
public:
    using ConfigError::ConfigError;
};

/**
 * @brief 配置格式
 */
enum class ConfigFormat {
    JSON,
    YAML,
    TOML,
    AUTO  // 根据文件扩展名自动检测
};

/**
 * @brief 配置类
 */
class Config {
public:
    Config() = default;

    /**
     * @brief 从文件加载配置
     */
    static Config load(const std::filesystem::path& path,
                       ConfigFormat format = ConfigFormat::AUTO);

    /**
     * @brief 从字符串解析配置
     */
    static Config parse(std::string_view content, ConfigFormat format);

    /**
     * @brief 保存配置到文件
     */
    void save(const std::filesystem::path& path,
              ConfigFormat format = ConfigFormat::AUTO) const;

    /**
     * @brief 序列化为字符串
     */
    std::string serialize(ConfigFormat format) const;

    /**
     * @brief 获取根节点
     */
    const ConfigNode& root() const { return root_; }
    ConfigNode& root() { return root_; }

    /**
     * @brief 便捷访问
     */
    const ConfigNode& operator[](std::string_view key) const {
        return root_[key];
    }

    template<typename T>
    T get(std::string_view path, T default_value = T{}) const {
        auto node = root_.find(path);
        if (node) {
            return node->get().get<T>(std::move(default_value));
        }
        return default_value;
    }

    /**
     * @brief 合并另一个配置
     */
    void merge(const Config& other);

    /**
     * @brief 设置值
     */
    template<typename T>
    void set(std::string_view path, T value);

private:
    ConfigNode root_;

    static ConfigFormat detect_format(const std::filesystem::path& path);
    static std::unique_ptr<ConfigParser> create_parser(ConfigFormat format);
};

/**
 * @brief 配置解析器接口
 */
class ConfigParser {
public:
    virtual ~ConfigParser() = default;
    virtual ConfigNode parse(std::string_view content) = 0;
    virtual std::string serialize(const ConfigNode& node) = 0;
};

} // namespace configlib
```

**src/config.cpp**：

```cpp
#include "configlib/config.hpp"
#include "configlib/json_parser.hpp"

#ifdef CONFIGLIB_WITH_YAML
#include "configlib/yaml_parser.hpp"
#endif

#ifdef CONFIGLIB_WITH_TOML
#include "configlib/toml_parser.hpp"
#endif

#include <fstream>
#include <sstream>
#include <algorithm>

namespace configlib {

const ConfigNode ConfigNode::null_node_{};

bool ConfigNode::is_null() const {
    return std::holds_alternative<std::nullptr_t>(value_);
}

bool ConfigNode::is_bool() const {
    return std::holds_alternative<bool>(value_);
}

bool ConfigNode::is_int() const {
    return std::holds_alternative<int64_t>(value_);
}

bool ConfigNode::is_double() const {
    return std::holds_alternative<double>(value_);
}

bool ConfigNode::is_string() const {
    return std::holds_alternative<std::string>(value_);
}

bool ConfigNode::is_array() const {
    return std::holds_alternative<std::vector<ConfigNode>>(value_);
}

bool ConfigNode::is_object() const {
    return std::holds_alternative<std::map<std::string, ConfigNode>>(value_);
}

template<>
bool ConfigNode::get<bool>(bool default_value) const {
    if (auto* val = std::get_if<bool>(&value_)) {
        return *val;
    }
    return default_value;
}

template<>
int64_t ConfigNode::get<int64_t>(int64_t default_value) const {
    if (auto* val = std::get_if<int64_t>(&value_)) {
        return *val;
    }
    return default_value;
}

template<>
int ConfigNode::get<int>(int default_value) const {
    return static_cast<int>(get<int64_t>(default_value));
}

template<>
double ConfigNode::get<double>(double default_value) const {
    if (auto* val = std::get_if<double>(&value_)) {
        return *val;
    }
    if (auto* val = std::get_if<int64_t>(&value_)) {
        return static_cast<double>(*val);
    }
    return default_value;
}

template<>
std::string ConfigNode::get<std::string>(std::string default_value) const {
    if (auto* val = std::get_if<std::string>(&value_)) {
        return *val;
    }
    return default_value;
}

const ConfigNode& ConfigNode::operator[](size_t index) const {
    if (auto* arr = std::get_if<std::vector<ConfigNode>>(&value_)) {
        if (index < arr->size()) {
            return (*arr)[index];
        }
    }
    return null_node_;
}

size_t ConfigNode::size() const {
    if (auto* arr = std::get_if<std::vector<ConfigNode>>(&value_)) {
        return arr->size();
    }
    if (auto* obj = std::get_if<std::map<std::string, ConfigNode>>(&value_)) {
        return obj->size();
    }
    return 0;
}

const ConfigNode& ConfigNode::operator[](std::string_view key) const {
    if (auto* obj = std::get_if<std::map<std::string, ConfigNode>>(&value_)) {
        auto it = obj->find(std::string(key));
        if (it != obj->end()) {
            return it->second;
        }
    }
    return null_node_;
}

bool ConfigNode::contains(std::string_view key) const {
    if (auto* obj = std::get_if<std::map<std::string, ConfigNode>>(&value_)) {
        return obj->find(std::string(key)) != obj->end();
    }
    return false;
}

std::vector<std::string> ConfigNode::keys() const {
    std::vector<std::string> result;
    if (auto* obj = std::get_if<std::map<std::string, ConfigNode>>(&value_)) {
        result.reserve(obj->size());
        for (const auto& [key, _] : *obj) {
            result.push_back(key);
        }
    }
    return result;
}

const ConfigNode& ConfigNode::at(std::string_view path) const {
    auto result = find(path);
    if (!result) {
        throw ConfigError("Path not found: " + std::string(path));
    }
    return result->get();
}

std::optional<std::reference_wrapper<const ConfigNode>>
ConfigNode::find(std::string_view path) const {
    const ConfigNode* current = this;

    size_t pos = 0;
    while (pos < path.size()) {
        size_t dot = path.find('.', pos);
        if (dot == std::string_view::npos) {
            dot = path.size();
        }

        std::string_view key = path.substr(pos, dot - pos);

        if (!current->is_object()) {
            return std::nullopt;
        }

        if (!current->contains(key)) {
            return std::nullopt;
        }

        current = &((*current)[key]);
        pos = dot + 1;
    }

    return std::cref(*current);
}

// Config implementation

Config Config::load(const std::filesystem::path& path, ConfigFormat format) {
    if (format == ConfigFormat::AUTO) {
        format = detect_format(path);
    }

    std::ifstream file(path);
    if (!file) {
        throw ConfigError("Cannot open file: " + path.string());
    }

    std::stringstream buffer;
    buffer << file.rdbuf();

    return parse(buffer.str(), format);
}

Config Config::parse(std::string_view content, ConfigFormat format) {
    auto parser = create_parser(format);
    Config config;
    config.root_ = parser->parse(content);
    return config;
}

void Config::save(const std::filesystem::path& path, ConfigFormat format) const {
    if (format == ConfigFormat::AUTO) {
        format = detect_format(path);
    }

    std::ofstream file(path);
    if (!file) {
        throw ConfigError("Cannot open file for writing: " + path.string());
    }

    file << serialize(format);
}

std::string Config::serialize(ConfigFormat format) const {
    auto parser = create_parser(format);
    return parser->serialize(root_);
}

ConfigFormat Config::detect_format(const std::filesystem::path& path) {
    std::string ext = path.extension().string();
    std::transform(ext.begin(), ext.end(), ext.begin(), ::tolower);

    if (ext == ".json") return ConfigFormat::JSON;
    if (ext == ".yaml" || ext == ".yml") return ConfigFormat::YAML;
    if (ext == ".toml") return ConfigFormat::TOML;

    throw ConfigError("Unknown file format: " + path.string());
}

std::unique_ptr<ConfigParser> Config::create_parser(ConfigFormat format) {
    switch (format) {
        case ConfigFormat::JSON:
            return std::make_unique<JsonParser>();
#ifdef CONFIGLIB_WITH_YAML
        case ConfigFormat::YAML:
            return std::make_unique<YamlParser>();
#endif
#ifdef CONFIGLIB_WITH_TOML
        case ConfigFormat::TOML:
            return std::make_unique<TomlParser>();
#endif
        default:
            throw ConfigError("Unsupported format");
    }
}

} // namespace configlib
```

**tests/test_config.cpp**：

```cpp
#include <gtest/gtest.h>
#include <configlib/config.hpp>
#include <fstream>

using namespace configlib;

class ConfigTest : public ::testing::Test {
protected:
    void SetUp() override {
        json_content_ = R"({
            "name": "test",
            "version": 1,
            "enabled": true,
            "ratio": 3.14,
            "tags": ["a", "b", "c"],
            "database": {
                "host": "localhost",
                "port": 5432
            }
        })";
    }

    std::string json_content_;
};

TEST_F(ConfigTest, ParseJson) {
    auto config = Config::parse(json_content_, ConfigFormat::JSON);

    EXPECT_EQ(config.get<std::string>("name"), "test");
    EXPECT_EQ(config.get<int>("version"), 1);
    EXPECT_EQ(config.get<bool>("enabled"), true);
    EXPECT_NEAR(config.get<double>("ratio"), 3.14, 0.001);
}

TEST_F(ConfigTest, AccessNestedValues) {
    auto config = Config::parse(json_content_, ConfigFormat::JSON);

    EXPECT_EQ(config.get<std::string>("database.host"), "localhost");
    EXPECT_EQ(config.get<int>("database.port"), 5432);
}

TEST_F(ConfigTest, AccessArray) {
    auto config = Config::parse(json_content_, ConfigFormat::JSON);
    const auto& tags = config.root()["tags"];

    EXPECT_EQ(tags.size(), 3);
    EXPECT_EQ(tags[0].get<std::string>(), "a");
    EXPECT_EQ(tags[1].get<std::string>(), "b");
    EXPECT_EQ(tags[2].get<std::string>(), "c");
}

TEST_F(ConfigTest, DefaultValues) {
    auto config = Config::parse(json_content_, ConfigFormat::JSON);

    EXPECT_EQ(config.get<std::string>("missing", "default"), "default");
    EXPECT_EQ(config.get<int>("missing", 42), 42);
}

TEST_F(ConfigTest, TypeChecks) {
    auto config = Config::parse(json_content_, ConfigFormat::JSON);
    const auto& root = config.root();

    EXPECT_TRUE(root["name"].is_string());
    EXPECT_TRUE(root["version"].is_int());
    EXPECT_TRUE(root["enabled"].is_bool());
    EXPECT_TRUE(root["ratio"].is_double());
    EXPECT_TRUE(root["tags"].is_array());
    EXPECT_TRUE(root["database"].is_object());
}

TEST_F(ConfigTest, Contains) {
    auto config = Config::parse(json_content_, ConfigFormat::JSON);

    EXPECT_TRUE(config.root().contains("name"));
    EXPECT_TRUE(config.root().contains("database"));
    EXPECT_FALSE(config.root().contains("nonexistent"));
}

TEST_F(ConfigTest, Keys) {
    auto config = Config::parse(json_content_, ConfigFormat::JSON);
    auto keys = config.root().keys();

    EXPECT_EQ(keys.size(), 6);
    EXPECT_TRUE(std::find(keys.begin(), keys.end(), "name") != keys.end());
    EXPECT_TRUE(std::find(keys.begin(), keys.end(), "database") != keys.end());
}

TEST_F(ConfigTest, InvalidJson) {
    EXPECT_THROW(Config::parse("invalid json", ConfigFormat::JSON), ConfigParseError);
}

#ifdef CONFIGLIB_WITH_YAML
TEST_F(ConfigTest, ParseYaml) {
    std::string yaml = R"(
name: test
version: 1
enabled: true
database:
  host: localhost
  port: 5432
)";

    auto config = Config::parse(yaml, ConfigFormat::YAML);

    EXPECT_EQ(config.get<std::string>("name"), "test");
    EXPECT_EQ(config.get<int>("database.port"), 5432);
}
#endif

#ifdef CONFIGLIB_WITH_TOML
TEST_F(ConfigTest, ParseToml) {
    std::string toml = R"(
name = "test"
version = 1
enabled = true

[database]
host = "localhost"
port = 5432
)";

    auto config = Config::parse(toml, ConfigFormat::TOML);

    EXPECT_EQ(config.get<std::string>("name"), "test");
    EXPECT_EQ(config.get<int>("database.port"), 5432);
}
#endif
```

---

## 月度验收标准

### 知识维度检验

#### 基础概念（Week 1）
- [ ] 能独立安装Conan 2.x并完成环境配置
- [ ] 能画出Conan核心架构图（客户端→缓存→远端）
- [ ] 能列举Conan 2.x相比1.x的至少8个核心变化
- [ ] 能编写多平台Profile并使用profile composition
- [ ] 能解释Settings/Options/Conf三层配置体系

#### 项目集成（Week 2）
- [ ] 能编写conanfile.txt和conanfile.py两种格式
- [ ] 能使用CMakeDeps+CMakeToolchain+cmake_layout组合
- [ ] 能区分4种依赖类型（requires/tool_requires/test_requires/python_requires）
- [ ] 能解释conan_toolchain.cmake的工作原理

#### 包开发（Week 3）
- [ ] 能独立编写完整的Conan库包（含所有生命周期方法）
- [ ] 能使用cpp_info.components定义多组件包
- [ ] 能为Header-only库和非CMake项目编写Conan包
- [ ] 能编写正确的test_package

#### 工程实践（Week 4）
- [ ] 能使用Lockfile确保依赖可重现
- [ ] 能配置Artifactory仓库架构
- [ ] 能使用python_requires共享构建逻辑
- [ ] 能从10个维度对比vcpkg和Conan

### 实践维度检验

- [ ] config-lib项目能通过conan create完整创建和测试
- [ ] Header-only包和多组件包能正确安装
- [ ] CI/CD流水线能成功运行
- [ ] Lockfile生成和使用流程正确
- [ ] 所有单元测试通过

### 知识检验问题

1. Conan的Profile和vcpkg的Triplet有什么区别？Profile更灵活在哪里？
2. conanfile.py中的`package_id()`和`compatibility()`各自的作用是什么？
3. 如何在Conan中处理可选依赖？options和requires的配合方式？
4. Conan的lockfile机制解决了什么问题？Recipe Revision是什么？
5. CMakeDeps和CMakeToolchain各自生成什么文件？为什么需要两个Generator？
6. requires和tool_requires的区别？为什么交叉编译时需要区分？
7. python_requires的作用和使用场景？如何实现公司级构建逻辑复用？
8. Conan 2.x的缓存结构(~/.conan2/p/)与1.x有何不同？为什么改为hash-based？
9. Artifactory的Local/Remote/Virtual三种仓库类型各自的作用？
10. 在什么场景下应该选择vcpkg，什么场景下选择Conan？两者能否共存？

---

## 月度知识地图

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Month 39 知识地图：Conan包管理器                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│                    ┌───────────────────┐                                │
│                    │   Conan 包管理器   │                                │
│                    └─────────┬─────────┘                                │
│              ┌───────────────┼───────────────┐                          │
│              ▼               ▼               ▼                          │
│     ┌────────────┐  ┌────────────┐  ┌────────────────┐                 │
│     │  基础架构   │  │  项目集成   │  │  高级特性       │                 │
│     └──────┬─────┘  └──────┬─────┘  └──────┬─────────┘                 │
│            │               │               │                            │
│     ┌──────▼──────┐ ┌──────▼──────┐ ┌──────▼──────────┐               │
│     │安装与配置   │ │conanfile.py │ │Lockfile         │               │
│     │缓存结构     │ │conanfile.txt│ │依赖图分析        │               │
│     │Profile系统  │ │Generators   │ │Artifactory       │               │
│     │ 三层配置    │ │ CMakeDeps   │ │Conan Server      │               │
│     │ 双Profile   │ │ CMakeToolchain│                  │               │
│     │2.x新特性    │ │Layout系统   │ │python_requires   │               │
│     │远端仓库     │ │依赖模型     │ │Hook系统          │               │
│     └─────────────┘ │ requires    │ │CI/CD集成         │               │
│                      │ tool_requires│ │vcpkg vs Conan   │               │
│                      │ test_requires│ │企业级实践        │               │
│                      └─────────────┘ └─────────────────┘               │
│                                                                         │
│                    ┌─────────────┐                                      │
│                    │  包开发      │                                      │
│                    └──────┬──────┘                                      │
│                           │                                             │
│                    ┌──────▼──────┐                                      │
│                    │conan create │                                      │
│                    │6阶段生命周期│                                       │
│                    │package_info │                                      │
│                    │组件系统     │                                       │
│                    │Header-only  │                                      │
│                    │非CMake项目  │                                       │
│                    │test_package │                                      │
│                    │ConanCenter  │                                      │
│                    └─────────────┘                                      │
│                                                                         │
│  ┌────────────────────────────────────────────────────────────────┐     │
│  │                      实践项目                                   │     │
│  │  config-lib: JSON/YAML/TOML配置库 + Conan包 + test_package     │     │
│  └────────────────────────────────────────────────────────────────┘     │
│                                                                         │
│  Month 38 (vcpkg) ──→ Month 39 (Conan) ──→ Month 40 (CI/CD)          │
│  包管理方案A           包管理方案B           自动化流水线               │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 输出物清单

### 完整输出物列表

| 编号 | 类别 | 输出物 | 说明 |
|------|------|--------|------|
| 1 | 项目 | config-lib/ | 完整的配置管理库(JSON/YAML/TOML) |
| 2 | 项目 | conanfile.py | 库包定义 |
| 3 | 项目 | conandata.yml | 源码和补丁信息 |
| 4 | 项目 | test_package/ | 包安装验证 |
| 5 | 包 | practice/multi_component_pkg/ | 多组件包实践 |
| 6 | 包 | practice/header_only_pkg/ | Header-only包实践 |
| 7 | 包 | practice/python_requires/ | 共享构建逻辑实践 |
| 8 | Profile | profiles/各平台profile文件 | 至少4个平台profile |
| 9 | CI/CD | .github/workflows/conan.yml | GitHub Actions配置 |
| 10 | 文档 | notes/month39_conan.md | 学习笔记总结 |
| 11 | 文档 | notes/vcpkg_vs_conan_deep.md | 深度对比分析(10维度) |
| 12 | 文档 | notes/conan_profiles.md | Profile系统详解 |
| 13 | 文档 | notes/generators.md | Generators系统详解 |
| 14 | 脚本 | scripts/build-all.sh | 多配置构建脚本 |
| 15 | 脚本 | scripts/upload.sh | 包上传脚本 |

---

## 时间分配表

| 周次 | 主题 | 理论学习 | 实践编码 | 源码阅读 | 合计 |
|------|------|----------|----------|----------|------|
| 第1周 | Conan基础入门 | 12h | 18h | 5h | 35h |
| 第2周 | conanfile编写与CMake集成 | 10h | 20h | 5h | 35h |
| 第3周 | 创建和发布Conan包 | 8h | 22h | 5h | 35h |
| 第4周 | 高级特性与最佳实践 | 8h | 22h | 5h | 35h |
| **合计** | | **38h** | **82h** | **20h** | **140h** |

---

## 下月预告

Month 40将学习**CI/CD流水线（GitHub Actions）**，实现代码的自动化构建、测试和部署。重点内容：

- GitHub Actions核心概念（workflow/job/step/action）
- 矩阵构建（多平台/多编译器/多配置）
- 缓存策略（依赖缓存/构建缓存/ccache）
- 自动化测试（单元测试/集成测试/代码覆盖率）
- 自动化发布（版本号/Changelog/Release/包发布）
- 自定义Action开发

```
Month 37 (CMake)    Month 38 (vcpkg)    Month 39 (Conan)    Month 40 (CI/CD)
构建系统            包管理方案A          包管理方案B          自动化流水线
     │                   │                   │                    │
     └───────────────────┴───────────────────┴────────────────────┘
                                    │
                                    ▼
                    完整的C++工程化工具链
                    (构建 + 包管理 + CI/CD)
```
