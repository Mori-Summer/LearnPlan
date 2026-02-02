# Month 37: Modern CMake深度使用——构建系统的现代化实践

## 本月主题概述

进入第四年的现代工程化学习。本月深入掌握Modern CMake（3.x版本）的最佳实践，从传统的变量驱动方式转向目标驱动的现代风格。学习如何编写可维护、可复用的CMake代码，为后续的包管理和CI/CD打下坚实基础。

**学习目标**：
- 掌握Modern CMake的核心概念（Target、Properties、Generator Expressions）
- 理解PUBLIC/PRIVATE/INTERFACE的依赖传播机制
- 学会编写可复用的CMake模块和函数
- 构建跨平台的专业级项目结构

---

## 理论学习内容

### 第一周：Modern CMake基础理念（35小时）

```
┌─────────────────────────────────────────────────────────────────┐
│  Week 1: Modern CMake 基础理念                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Day 1-2: CMake执行模型与核心概念                                │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │配置阶段   │→│生成阶段   │→│构建阶段   │→│安装阶段   │       │
│  │Configure │  │Generate  │  │ Build    │  │Install   │       │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘       │
│                                                                 │
│  Day 3-4: Target-centric模型与属性系统                          │
│  ┌─────────────────────────────────────────────────────┐       │
│  │  Target = 编译产物 + 属性(Properties) + 依赖        │       │
│  │  Properties: COMPILE_OPTIONS, INCLUDE_DIRECTORIES...│       │
│  └─────────────────────────────────────────────────────┘       │
│                                                                 │
│  Day 5-7: 变量系统、缓存与传统vs现代对比                         │
│  ┌─────────────────────────────────────────────────────┐       │
│  │  Normal Variables → Cache Variables → Environment    │       │
│  │  传统CMake(全局) → Modern CMake(Target级)            │       │
│  └─────────────────────────────────────────────────────┘       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### 每日任务分解

| Day | 时间 | 上午任务(2.5h) | 下午任务(2.5h) | 输出物 |
|-----|------|---------------|---------------|--------|
| 1 | 5h | CMake执行流程(Configure/Generate/Build) | 阅读《Professional CMake》1-2章 | notes/cmake_execution.md |
| 2 | 5h | project()命令详解、版本策略 | cmake_minimum_required策略实践 | notes/cmake_project.md |
| 3 | 5h | Target类型(EXECUTABLE/LIBRARY/ALIAS等) | Target属性系统深入 | notes/cmake_targets.md |
| 4 | 5h | 传统CMake反模式分析 | Modern CMake最佳实践重写 | cmake_comparison.cmake |
| 5 | 5h | 变量作用域与缓存变量 | option()与set(CACHE)机制 | notes/cmake_variables.md |
| 6 | 5h | 阅读fmt库CMakeLists.txt | 分析其Target-centric设计 | notes/fmt_cmake_analysis.md |
| 7 | 5h | 编写第一个Modern CMake项目 | "Effective Modern CMake"演讲学习 | practice/week1_project/ |

**学习目标**：理解Modern CMake与传统CMake的区别

**阅读材料**：
- [ ] 《Professional CMake: A Practical Guide》第1-5章
- [ ] CMake官方教程 (cmake.org/cmake/help/latest/guide/tutorial)
- [ ] "Effective Modern CMake" by Daniel Pfeifer (YouTube演讲)

---

#### CMake执行流程详解

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CMake 执行流程                                    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. Configure阶段                                                   │
│  ┌────────────────────────────────────────────────┐                 │
│  │  cmake -S . -B build                           │                 │
│  │                                                 │                 │
│  │  ┌──────────────┐     ┌──────────────┐         │                 │
│  │  │CMakeLists.txt│────►│ CMake解释器  │         │                 │
│  │  └──────────────┘     └──────┬───────┘         │                 │
│  │                              │                  │                 │
│  │                    ┌─────────▼─────────┐       │                 │
│  │                    │  CMakeCache.txt   │       │                 │
│  │                    │  (缓存变量)       │       │                 │
│  │                    └──────────────────┘       │                 │
│  └────────────────────────────────────────────────┘                 │
│                              │                                       │
│  2. Generate阶段             ▼                                       │
│  ┌────────────────────────────────────────────────┐                 │
│  │  根据Generator生成构建系统文件                  │                 │
│  │                                                 │                 │
│  │  ┌──────────────┐  ┌──────────────┐  ┌───────┐│                 │
│  │  │  Makefile    │  │  Ninja.build │  │ .sln  ││                 │
│  │  │  (Unix)      │  │  (跨平台)    │  │(MSVC) ││                 │
│  │  └──────────────┘  └──────────────┘  └───────┘│                 │
│  └────────────────────────────────────────────────┘                 │
│                              │                                       │
│  3. Build阶段                ▼                                       │
│  ┌────────────────────────────────────────────────┐                 │
│  │  cmake --build build                           │                 │
│  │                                                 │                 │
│  │  编译器(gcc/clang/msvc) → 链接器 → 可执行文件  │                 │
│  └────────────────────────────────────────────────┘                 │
│                              │                                       │
│  4. Install阶段              ▼                                       │
│  ┌────────────────────────────────────────────────┐                 │
│  │  cmake --install build --prefix /usr/local     │                 │
│  │                                                 │                 │
│  │  bin/ lib/ include/ share/cmake/               │                 │
│  └────────────────────────────────────────────────┘                 │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

#### Target属性模型

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Target 属性模型                                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   一个Target = 编译产物 + 属性集合 + 依赖关系                      │
│                                                                     │
│   ┌─────────────────────────────────────────────────┐              │
│   │                Target "mylib"                    │              │
│   ├─────────────────────────────────────────────────┤              │
│   │                                                  │              │
│   │  构建属性 (BUILD):                               │              │
│   │  ├── COMPILE_OPTIONS: -Wall -Wextra             │              │
│   │  ├── COMPILE_DEFINITIONS: MYLIB_DEBUG           │              │
│   │  ├── INCLUDE_DIRECTORIES: /src/include          │              │
│   │  ├── COMPILE_FEATURES: cxx_std_17              │              │
│   │  └── SOURCES: a.cpp b.cpp c.cpp               │              │
│   │                                                  │              │
│   │  链接属性 (LINK):                                │              │
│   │  ├── LINK_LIBRARIES: fmt::fmt spdlog::spdlog   │              │
│   │  ├── LINK_OPTIONS: -lpthread                   │              │
│   │  └── LINK_DIRECTORIES: /usr/local/lib          │              │
│   │                                                  │              │
│   │  输出属性 (OUTPUT):                              │              │
│   │  ├── OUTPUT_NAME: mylib                        │              │
│   │  ├── VERSION: 1.2.3                            │              │
│   │  └── SOVERSION: 1                              │              │
│   │                                                  │              │
│   │  传播属性 (INTERFACE):                           │              │
│   │  ├── INTERFACE_INCLUDE_DIRECTORIES              │              │
│   │  ├── INTERFACE_COMPILE_DEFINITIONS              │              │
│   │  └── INTERFACE_LINK_LIBRARIES                   │              │
│   │                                                  │              │
│   └─────────────────────────────────────────────────┘              │
│                                                                     │
│   属性传播规则:                                                     │
│   ┌────────────┬──────────────────┬──────────────────┐            │
│   │  关键字     │  Target自身使用  │  传播给消费者     │            │
│   ├────────────┼──────────────────┼──────────────────┤            │
│   │  PRIVATE   │       ✓         │       ✗          │            │
│   │  PUBLIC    │       ✓         │       ✓          │            │
│   │  INTERFACE │       ✗         │       ✓          │            │
│   └────────────┴──────────────────┴──────────────────┘            │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

#### 核心概念深入

**cmake_minimum_required 版本策略**：

```cmake
# ==========================================
# cmake_minimum_required 与策略(Policy)系统
# ==========================================

# 这不仅设置最低版本，还影响CMake的行为策略！
cmake_minimum_required(VERSION 3.16)
# 等价于设置了3.16及之前所有策略为NEW行为

# 版本范围语法（CMake 3.12+）
cmake_minimum_required(VERSION 3.16...3.28)
# 允许3.16~3.28之间的CMake运行，且设置对应版本的策略

# 策略示例
# CMP0076 (3.13): target_sources()支持相对路径
# CMP0077 (3.13): option()不覆盖已有的缓存变量
# CMP0091 (3.15): MSVC运行时库选择（动态/静态）
# CMP0135 (3.24): FetchContent下载时间戳处理

# 手动设置策略（不推荐，但有时需要兼容）
cmake_policy(SET CMP0077 NEW)
```

**变量作用域与缓存变量**：

```cmake
# ==========================================
# CMake 变量系统详解
# ==========================================

# 1. 普通变量 (Normal Variables) - 当前作用域
set(MY_VAR "hello")
message(STATUS "MY_VAR = ${MY_VAR}")  # hello

# 2. 作用域规则
#    - add_subdirectory() 创建新作用域（子目录继承父目录变量的拷贝）
#    - function() 创建新作用域
#    - macro() 不创建新作用域！（在调用者作用域中执行）

# 3. 向父作用域传递变量
function(my_function)
    set(RESULT "from_function")
    # 必须显式传递给父作用域
    set(RESULT "${RESULT}" PARENT_SCOPE)
endfunction()

# 4. 缓存变量 (Cache Variables) - 全局持久化
set(MY_CACHE_VAR "default" CACHE STRING "Description of the variable")
# 类型: BOOL, STRING, PATH, FILEPATH, INTERNAL
# 首次configure写入CMakeCache.txt，后续不覆盖

# 5. option() 是 set(CACHE BOOL) 的简写
option(ENABLE_TESTS "Enable unit tests" ON)
# 等价于:
set(ENABLE_TESTS ON CACHE BOOL "Enable unit tests")

# 6. 环境变量
message(STATUS "HOME = $ENV{HOME}")
set(ENV{MY_ENV} "value")  # 只在当前CMake进程中有效

# 7. 变量作用域可视化
#
#   ┌─────────────── 根 CMakeLists.txt ────────────────┐
#   │  set(ROOT_VAR "root")                             │
#   │                                                    │
#   │  ┌───────── src/CMakeLists.txt ──────────────┐   │
#   │  │  # ROOT_VAR = "root" (继承拷贝)           │   │
#   │  │  set(SRC_VAR "src")                        │   │
#   │  │  set(ROOT_VAR "modified")  ← 只修改本地   │   │
#   │  └───────────────────────────────────────────┘   │
#   │                                                    │
#   │  # ROOT_VAR 仍然是 "root"                         │
#   │  # SRC_VAR 不可见                                  │
#   └──────────────────────────────────────────────────┘
#
#   ┌────── CMakeCache.txt (全局持久) ──────┐
#   │  ENABLE_TESTS:BOOL=ON                  │
#   │  CMAKE_BUILD_TYPE:STRING=Release       │
#   │  CMAKE_INSTALL_PREFIX:PATH=/usr/local  │
#   └────────────────────────────────────────┘

# 8. 列表变量
set(MY_LIST "a" "b" "c")           # 等价于 "a;b;c"
list(APPEND MY_LIST "d")           # "a;b;c;d"
list(LENGTH MY_LIST LEN)           # LEN = 4
list(GET MY_LIST 0 FIRST)          # FIRST = "a"
list(FIND MY_LIST "b" INDEX)       # INDEX = 1
list(REMOVE_ITEM MY_LIST "b")      # "a;c;d"
list(SORT MY_LIST)                  # "a;c;d" (已排序)
list(JOIN MY_LIST ", " JOINED)     # "a, c, d"
```

**核心概念**：

```cmake
# ==========================================
# 传统CMake（反模式，不推荐）
# ==========================================
cmake_minimum_required(VERSION 2.8)
project(OldStyle)

# 全局变量污染
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra")
include_directories(${PROJECT_SOURCE_DIR}/include)
link_directories(/usr/local/lib)

add_executable(myapp main.cpp)
target_link_libraries(myapp boost_system pthread)

# ==========================================
# Modern CMake（推荐方式）
# ==========================================
cmake_minimum_required(VERSION 3.16)
project(ModernStyle
    VERSION 1.0.0
    DESCRIPTION "A modern CMake example"
    LANGUAGES CXX
)

# 设置C++标准（目标级别）
add_executable(myapp main.cpp)
target_compile_features(myapp PRIVATE cxx_std_17)
target_compile_options(myapp PRIVATE -Wall -Wextra)
target_include_directories(myapp PRIVATE ${PROJECT_SOURCE_DIR}/include)

# 使用imported targets
find_package(Boost REQUIRED COMPONENTS system)
find_package(Threads REQUIRED)
target_link_libraries(myapp PRIVATE Boost::system Threads::Threads)
```

**关键原则**：
1. **Target-centric**：所有属性都应该绑定到target上
2. **No global state**：避免使用全局变量和全局命令
3. **Explicit dependencies**：明确声明依赖关系
4. **Config files over Find modules**：优先使用现代的Config文件

#### Week 1 输出物清单

| 文件 | 说明 | 完成状态 |
|------|------|---------|
| `notes/cmake_execution.md` | CMake执行流程笔记 | [ ] |
| `notes/cmake_project.md` | project()与版本策略 | [ ] |
| `notes/cmake_targets.md` | Target属性系统详解 | [ ] |
| `notes/cmake_variables.md` | 变量系统深入笔记 | [ ] |
| `cmake_comparison.cmake` | 传统vs现代CMake对比 | [ ] |
| `notes/fmt_cmake_analysis.md` | fmt库CMake分析 | [ ] |
| `practice/week1_project/` | 第一个Modern CMake项目 | [ ] |

#### Week 1 检验标准

- [ ] 能够解释CMake的Configure/Generate/Build三个阶段
- [ ] 理解Generator的概念（Makefile/Ninja/MSBuild）
- [ ] 能够区分普通变量、缓存变量和环境变量的作用域
- [ ] 能够解释为什么不应该使用include_directories()
- [ ] 掌握Target的四种类型(EXECUTABLE/STATIC/SHARED/INTERFACE)
- [ ] 理解cmake_minimum_required与策略系统的关系
- [ ] 能够将传统CMake项目重写为Modern风格
- [ ] 完成fmt库CMake配置的阅读分析

---

### 第二周：依赖传播与可见性（35小时）

```
┌─────────────────────────────────────────────────────────────────┐
│  Week 2: 依赖传播机制深入                                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Day 8-9: PUBLIC/PRIVATE/INTERFACE 完全理解                     │
│  ┌────────────────────────────────────────────────────────┐    │
│  │            依赖传播链                                   │    │
│  │  app ──PRIVATE──► mylib ──PUBLIC──► fmt                │    │
│  │  app 获得: mylib + fmt (传递依赖)                      │    │
│  │  app 不获得: mylib的PRIVATE依赖                        │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
│  Day 10-11: find_package 深入与IMPORTED targets                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐       │
│  │ MODULE模式  │    │ CONFIG模式  │    │  IMPORTED    │       │
│  │ FindXxx.cmake│   │XxxConfig.cmake│  │  Target      │       │
│  └─────────────┘    └─────────────┘    └─────────────┘       │
│                                                                 │
│  Day 12-14: Generator Expressions 实战                          │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  $<CONDITION:VALUE>  $<TARGET_PROPERTY:prop>            │    │
│  │  BUILD_INTERFACE / INSTALL_INTERFACE                    │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### 每日任务分解

| Day | 时间 | 上午任务(2.5h) | 下午任务(2.5h) | 输出物 |
|-----|------|---------------|---------------|--------|
| 8 | 5h | PUBLIC/PRIVATE/INTERFACE基础 | 传递依赖(Transitive)机制 | notes/dependency_propagation.md |
| 9 | 5h | INTERFACE库与header-only模式 | 依赖链路调试(cmake --graphviz) | dependency_graph.dot |
| 10 | 5h | find_package MODULE模式 | find_package CONFIG模式 | notes/find_package.md |
| 11 | 5h | IMPORTED target详解 | 编写自定义FindXxx.cmake | cmake/FindMyDep.cmake |
| 12 | 5h | Generator Expressions基础语法 | 条件编译与平台判断表达式 | notes/genexpr.md |
| 13 | 5h | BUILD_INTERFACE vs INSTALL_INTERFACE | TARGET_PROPERTY查询表达式 | practice/genexpr_demo/ |
| 14 | 5h | 阅读spdlog CMake配置 | 综合练习：多库依赖项目 | practice/week2_multi_lib/ |

**学习目标**：深入理解PUBLIC/PRIVATE/INTERFACE

**阅读材料**：
- [ ] CMake文档：target_link_libraries
- [ ] CMake文档：Transitive Usage Requirements

---

#### 依赖传播链路可视化

```
┌─────────────────────────────────────────────────────────────────────┐
│                    依赖传播（Transitive Dependencies）               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   示例依赖图：                                                      │
│                                                                     │
│   app ──PRIVATE──► mylib ──PUBLIC──► fmt::fmt                      │
│                       │                                             │
│                       ├──PRIVATE──► nlohmann_json                  │
│                       │                                             │
│                       └──INTERFACE──► MYLIB_EXPORTS                │
│                                                                     │
│   传播结果分析:                                                     │
│   ┌────────────────────────────────────────────────────────────┐   │
│   │  Target: app                                                │   │
│   │                                                              │   │
│   │  编译时获得:                                                 │   │
│   │  ├── mylib 的 PUBLIC include dirs                           │   │
│   │  ├── fmt::fmt 的 INTERFACE include dirs (通过mylib PUBLIC) │   │
│   │  ├── MYLIB_EXPORTS 宏定义 (通过mylib INTERFACE)            │   │
│   │  └── cxx_std_17 (如果mylib PUBLIC声明)                     │   │
│   │                                                              │   │
│   │  编译时不获得:                                               │   │
│   │  ├── nlohmann_json 的任何属性 (mylib PRIVATE)              │   │
│   │  └── mylib 的 PRIVATE include dirs                         │   │
│   │                                                              │   │
│   │  链接时获得:                                                 │   │
│   │  ├── mylib 库文件                                           │   │
│   │  └── fmt 库文件 (传递依赖)                                 │   │
│   └────────────────────────────────────────────────────────────┘   │
│                                                                     │
│   可视化命令:                                                       │
│   cmake --graphviz=deps.dot build/                                  │
│   dot -Tpng deps.dot -o deps.png                                   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

#### find_package 两种模式对比

```cmake
# ==========================================
# find_package 的 MODULE 模式与 CONFIG 模式
# ==========================================

# MODULE模式 (传统方式)
# - 搜索 FindXxx.cmake 文件
# - 由CMake或项目提供
# - 设置 Xxx_FOUND, Xxx_INCLUDE_DIRS, Xxx_LIBRARIES 等变量
find_package(ZLIB REQUIRED)  # 使用CMake自带的FindZLIB.cmake

# CONFIG模式 (现代方式，推荐)
# - 搜索 XxxConfig.cmake 或 xxx-config.cmake
# - 由库自身提供（安装时生成）
# - 提供 IMPORTED targets（如 fmt::fmt）
find_package(fmt CONFIG REQUIRED)  # 搜索 fmtConfig.cmake

# 搜索路径顺序:
#
# ┌──────────────────────────────────────────────────────────────┐
# │  find_package(Foo REQUIRED)                                  │
# ├──────────────────────────────────────────────────────────────┤
# │                                                              │
# │  1. CMAKE_PREFIX_PATH 中的路径                               │
# │  2. Foo_DIR 变量指定的路径                                    │
# │  3. 环境变量 CMAKE_PREFIX_PATH                               │
# │  4. 系统标准路径:                                             │
# │     - /usr/local/lib/cmake/Foo/                             │
# │     - /usr/lib/cmake/Foo/                                    │
# │     - Windows: C:/Program Files/Foo/                        │
# │  5. CMAKE_MODULE_PATH (仅MODULE模式)                        │
# │                                                              │
# └──────────────────────────────────────────────────────────────┘

# 编写自定义 Find 模块
# cmake/FindMyDep.cmake
# ==========================================
# find_path(MYDEP_INCLUDE_DIR
#     NAMES mydep/mydep.h
#     PATHS
#         /usr/local/include
#         /opt/mydep/include
#         ${MYDEP_ROOT}/include
# )
#
# find_library(MYDEP_LIBRARY
#     NAMES mydep
#     PATHS
#         /usr/local/lib
#         /opt/mydep/lib
#         ${MYDEP_ROOT}/lib
# )
#
# include(FindPackageHandleStandardArgs)
# find_package_handle_standard_args(MyDep
#     REQUIRED_VARS MYDEP_LIBRARY MYDEP_INCLUDE_DIR
# )
#
# if(MyDep_FOUND AND NOT TARGET MyDep::MyDep)
#     add_library(MyDep::MyDep UNKNOWN IMPORTED)
#     set_target_properties(MyDep::MyDep PROPERTIES
#         IMPORTED_LOCATION "${MYDEP_LIBRARY}"
#         INTERFACE_INCLUDE_DIRECTORIES "${MYDEP_INCLUDE_DIR}"
#     )
# endif()
```

#### IMPORTED Target详解

```cmake
# ==========================================
# IMPORTED Targets 详解
# ==========================================

# IMPORTED target是代表外部库的"虚拟"target
# 它不参与构建，但携带使用该库所需的所有信息

# 1. 手动创建IMPORTED target
add_library(external::mylib SHARED IMPORTED)
set_target_properties(external::mylib PROPERTIES
    IMPORTED_LOCATION "/usr/local/lib/libmylib.so"
    INTERFACE_INCLUDE_DIRECTORIES "/usr/local/include"
    INTERFACE_COMPILE_DEFINITIONS "MYLIB_SHARED"
)

# 2. IMPORTED target的类型
# STATIC IMPORTED   - 静态库(.a / .lib)
# SHARED IMPORTED   - 动态库(.so / .dll)
# MODULE IMPORTED   - 插件模块
# UNKNOWN IMPORTED  - 类型未知（find模块常用）
# INTERFACE IMPORTED - 纯接口库(header-only)

# 3. Header-only库的IMPORTED target
add_library(header_only::lib INTERFACE IMPORTED)
set_target_properties(header_only::lib PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "/path/to/headers"
    INTERFACE_COMPILE_FEATURES "cxx_std_17"
)

# 4. 带多配置的IMPORTED target
add_library(ext::lib SHARED IMPORTED)
set_target_properties(ext::lib PROPERTIES
    IMPORTED_LOCATION_RELEASE "/opt/lib/libext.so"
    IMPORTED_LOCATION_DEBUG "/opt/lib/libext_d.so"
    IMPORTED_CONFIGURATIONS "Release;Debug"
    INTERFACE_INCLUDE_DIRECTORIES "/opt/include"
)

# 使用时完全透明，与普通target一样
# target_link_libraries(myapp PRIVATE external::mylib)
```

```cmake
# ==========================================
# 理解 PUBLIC / PRIVATE / INTERFACE
# ==========================================

# 假设我们有一个库的层次结构
#
#   app
#    |
#    v
#   mylib (uses json internally, exposes fmt in API)
#    |
#    v
#   json (internal), fmt (exposed in headers)

# --- mylib/CMakeLists.txt ---
add_library(mylib
    src/mylib.cpp
)

# PRIVATE: 只在编译mylib时需要，不传播给使用者
target_link_libraries(mylib PRIVATE nlohmann_json::nlohmann_json)

# PUBLIC: 编译mylib需要，且传播给使用者（头文件中暴露了fmt）
target_link_libraries(mylib PUBLIC fmt::fmt)

# INTERFACE: mylib本身不需要，但使用者需要
target_compile_definitions(mylib INTERFACE MYLIB_USER)

# 头文件目录的可见性
target_include_directories(mylib
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
)

# --- app/CMakeLists.txt ---
add_executable(app main.cpp)
target_link_libraries(app PRIVATE mylib)
# app 自动获得：
# - fmt::fmt（因为mylib PUBLIC链接）
# - include目录（因为mylib PUBLIC导出）
# - MYLIB_USER定义（因为mylib INTERFACE设置）
# app 不会获得：
# - nlohmann_json（因为mylib PRIVATE链接）
```

**Generator Expressions深入**：

```cmake
# ==========================================
# Generator Expressions（生成器表达式）
# ==========================================

# 基本语法: $<CONDITION:VALUE> 或 $<EXPRESSION>

# 1. 条件表达式
target_compile_definitions(mylib
    PRIVATE
        $<$<CONFIG:Debug>:DEBUG_MODE>
        $<$<CONFIG:Release>:NDEBUG>
)

# 2. 编译器判断
target_compile_options(mylib
    PRIVATE
        $<$<CXX_COMPILER_ID:GNU>:-Wall -Wextra -Wpedantic>
        $<$<CXX_COMPILER_ID:Clang>:-Wall -Wextra -Wpedantic>
        $<$<CXX_COMPILER_ID:MSVC>:/W4 /WX>
)

# 3. 平台判断
target_compile_definitions(mylib
    PRIVATE
        $<$<PLATFORM_ID:Windows>:WIN32_LEAN_AND_MEAN>
        $<$<PLATFORM_ID:Linux>:LINUX_PLATFORM>
        $<$<PLATFORM_ID:Darwin>:MACOS_PLATFORM>
)

# 4. BUILD_INTERFACE vs INSTALL_INTERFACE
target_include_directories(mylib
    PUBLIC
        # 构建时使用源码目录
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        # 安装后使用安装目录
        $<INSTALL_INTERFACE:include>
)

# 5. 复合条件
target_compile_options(mylib
    PRIVATE
        $<$<AND:$<CXX_COMPILER_ID:GNU>,$<CONFIG:Debug>>:-O0 -g3>
        $<$<AND:$<CXX_COMPILER_ID:GNU>,$<CONFIG:Release>>:-O3 -DNDEBUG>
)

# 6. 目标属性查询
target_link_libraries(myapp
    PRIVATE
        $<$<TARGET_EXISTS:OpenSSL::SSL>:OpenSSL::SSL>
)
```

#### Week 2 输出物清单

| 文件 | 说明 | 完成状态 |
|------|------|---------|
| `notes/dependency_propagation.md` | 依赖传播机制笔记 | [ ] |
| `dependency_graph.dot` | 依赖关系图(graphviz) | [ ] |
| `notes/find_package.md` | find_package两种模式 | [ ] |
| `cmake/FindMyDep.cmake` | 自定义Find模块 | [ ] |
| `notes/genexpr.md` | Generator Expressions详解 | [ ] |
| `practice/genexpr_demo/` | 生成器表达式练习项目 | [ ] |
| `practice/week2_multi_lib/` | 多库依赖综合项目 | [ ] |

#### Week 2 检验标准

- [ ] 能够准确解释PUBLIC/PRIVATE/INTERFACE的传播规则
- [ ] 能够用cmake --graphviz生成依赖图并分析
- [ ] 理解INTERFACE库的设计（header-only场景）
- [ ] 能够区分find_package的MODULE和CONFIG模式
- [ ] 能够编写自定义FindXxx.cmake模块
- [ ] 掌握IMPORTED target的创建与属性设置
- [ ] 能够编写复合Generator Expressions
- [ ] 理解BUILD_INTERFACE和INSTALL_INTERFACE的区别

---

### 第三周：CMake模块与函数（35小时）

```
┌─────────────────────────────────────────────────────────────────┐
│  Week 3: CMake模块化编程                                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Day 15-16: function/macro 与代码组织                            │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  function() = 新作用域，安全                            │    │
│  │  macro()    = 调用者作用域，文本替换                     │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
│  Day 17-18: FetchContent 与远程依赖                              │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  FetchContent_Declare → FetchContent_MakeAvailable      │    │
│  │  ExternalProject_Add (构建时下载)                        │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
│  Day 19-21: 自定义命令与代码生成                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  add_custom_command → add_custom_target                 │    │
│  │  configure_file → file(GENERATE)                        │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### 每日任务分解

| Day | 时间 | 上午任务(2.5h) | 下午任务(2.5h) | 输出物 |
|-----|------|---------------|---------------|--------|
| 15 | 5h | function() vs macro()对比 | 参数解析cmake_parse_arguments | notes/cmake_functions.md |
| 16 | 5h | 编写可复用CMake模块 | 模块测试与调试技巧 | cmake/MyModule.cmake |
| 17 | 5h | FetchContent基础使用 | FetchContent高级配置 | notes/fetchcontent.md |
| 18 | 5h | ExternalProject_Add深入 | FetchContent vs ExternalProject对比 | practice/fetchcontent_demo/ |
| 19 | 5h | add_custom_command实战 | add_custom_target实战 | notes/custom_commands.md |
| 20 | 5h | configure_file模板生成 | file(GENERATE)运行时生成 | cmake/version.hpp.in |
| 21 | 5h | 综合练习：代码生成管道 | 阅读《Professional CMake》17-20章 | practice/codegen_demo/ |

**学习目标**：编写可复用的CMake代码

**阅读材料**：
- [ ] CMake文档：cmake-developer
- [ ] 《Professional CMake》第17-20章

```cmake
# ==========================================
# cmake/CompilerWarnings.cmake
# ==========================================
function(set_project_warnings target_name)
    set(MSVC_WARNINGS
        /W4     # 基础警告级别
        /w14242 # 类型转换警告
        /w14254 # 位操作警告
        /w14263 # 虚函数隐藏
        /w14265 # 虚析构函数
        /w14287 # 无符号/负数比较
        /we4289 # 循环变量作用域
        /w14296 # 表达式永远为false
        /w14311 # 指针截断
        /w14545 # 逗号表达式
        /w14546 # 函数调用前缺少参数
        /w14547 # 逗号前的操作符无效
        /w14549 # 逗号前的操作符无效
        /w14555 # 表达式无副作用
        /w14619 # pragma warning未知
        /w14640 # 线程不安全静态初始化
        /w14826 # 有符号扩展转换
        /w14905 # LPSTR转LPWSTR
        /w14906 # LPWSTR转LPSTR
        /w14928 # 非法的拷贝初始化
        /permissive-
    )

    set(CLANG_WARNINGS
        -Wall
        -Wextra
        -Wshadow
        -Wnon-virtual-dtor
        -Wold-style-cast
        -Wcast-align
        -Wunused
        -Woverloaded-virtual
        -Wpedantic
        -Wconversion
        -Wsign-conversion
        -Wnull-dereference
        -Wdouble-promotion
        -Wformat=2
        -Wimplicit-fallthrough
    )

    set(GCC_WARNINGS
        ${CLANG_WARNINGS}
        -Wmisleading-indentation
        -Wduplicated-cond
        -Wduplicated-branches
        -Wlogical-op
        -Wuseless-cast
    )

    if(MSVC)
        set(PROJECT_WARNINGS ${MSVC_WARNINGS})
    elseif(CMAKE_CXX_COMPILER_ID MATCHES ".*Clang")
        set(PROJECT_WARNINGS ${CLANG_WARNINGS})
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        set(PROJECT_WARNINGS ${GCC_WARNINGS})
    endif()

    target_compile_options(${target_name} PRIVATE ${PROJECT_WARNINGS})
endfunction()

# ==========================================
# cmake/Sanitizers.cmake
# ==========================================
function(enable_sanitizers target_name)
    if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" OR CMAKE_CXX_COMPILER_ID MATCHES ".*Clang")
        option(ENABLE_ASAN "Enable Address Sanitizer" OFF)
        option(ENABLE_UBSAN "Enable Undefined Behavior Sanitizer" OFF)
        option(ENABLE_TSAN "Enable Thread Sanitizer" OFF)

        set(SANITIZERS "")

        if(ENABLE_ASAN)
            list(APPEND SANITIZERS "address")
        endif()

        if(ENABLE_UBSAN)
            list(APPEND SANITIZERS "undefined")
        endif()

        if(ENABLE_TSAN)
            if(ENABLE_ASAN)
                message(WARNING "TSAN and ASAN cannot be used together")
            else()
                list(APPEND SANITIZERS "thread")
            endif()
        endif()

        if(SANITIZERS)
            list(JOIN SANITIZERS "," SANITIZERS_STR)
            target_compile_options(${target_name} PRIVATE -fsanitize=${SANITIZERS_STR})
            target_link_options(${target_name} PRIVATE -fsanitize=${SANITIZERS_STR})
        endif()
    endif()
endfunction()

# ==========================================
# cmake/StaticAnalyzers.cmake
# ==========================================
function(enable_clang_tidy target_name)
    find_program(CLANG_TIDY_EXE NAMES clang-tidy)
    if(CLANG_TIDY_EXE)
        set_target_properties(${target_name}
            PROPERTIES CXX_CLANG_TIDY "${CLANG_TIDY_EXE};-checks=*,-fuchsia-*"
        )
    else()
        message(WARNING "clang-tidy not found")
    endif()
endfunction()

function(enable_cppcheck target_name)
    find_program(CPPCHECK_EXE NAMES cppcheck)
    if(CPPCHECK_EXE)
        set_target_properties(${target_name}
            PROPERTIES CXX_CPPCHECK "${CPPCHECK_EXE};--enable=all;--suppress=missingInclude"
        )
    else()
        message(WARNING "cppcheck not found")
    endif()
endfunction()
```

#### function() vs macro() 深入对比

```cmake
# ==========================================
# function vs macro 关键区别
# ==========================================

# function: 创建新作用域
function(my_function arg1 arg2)
    set(LOCAL_VAR "only visible inside function")
    set(RESULT "${arg1}_${arg2}")
    # 必须用PARENT_SCOPE传递给调用者
    set(RESULT "${RESULT}" PARENT_SCOPE)
endfunction()

# macro: 文本替换，在调用者作用域执行
macro(my_macro arg1 arg2)
    set(LOCAL_VAR "visible in caller scope!")
    set(RESULT "${arg1}_${arg2}")
    # 直接修改调用者的变量，无需PARENT_SCOPE
endmacro()

# 对比图:
#
# ┌────────────────────────┬────────────────────────┐
# │      function()        │       macro()          │
# ├────────────────────────┼────────────────────────┤
# │  创建新作用域           │  不创建新作用域         │
# │  ARGV/ARGC是真变量     │  ARGV/ARGC是文本替换    │
# │  return()退出函数      │  return()退出调用者!    │
# │  安全，推荐使用         │  小心使用              │
# │  需要PARENT_SCOPE      │  直接修改调用者变量     │
# └────────────────────────┴────────────────────────┘

# cmake_parse_arguments 高级参数解析
function(my_library)
    # 定义参数规范
    set(options STATIC SHARED HEADER_ONLY)
    set(oneValueArgs NAME ALIAS NAMESPACE)
    set(multiValueArgs SOURCES HEADERS DEPENDENCIES)

    cmake_parse_arguments(ARG
        "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN}
    )

    # 使用解析后的参数
    if(ARG_HEADER_ONLY)
        add_library(${ARG_NAME} INTERFACE)
    elseif(ARG_STATIC)
        add_library(${ARG_NAME} STATIC ${ARG_SOURCES})
    elseif(ARG_SHARED)
        add_library(${ARG_NAME} SHARED ${ARG_SOURCES})
    else()
        add_library(${ARG_NAME} ${ARG_SOURCES})
    endif()

    if(ARG_ALIAS)
        add_library(${ARG_ALIAS} ALIAS ${ARG_NAME})
    endif()

    if(ARG_DEPENDENCIES)
        target_link_libraries(${ARG_NAME} PUBLIC ${ARG_DEPENDENCIES})
    endif()
endfunction()

# 使用示例:
# my_library(
#     NAME mylib
#     ALIAS MyProject::mylib
#     STATIC
#     SOURCES src/a.cpp src/b.cpp
#     HEADERS include/a.hpp include/b.hpp
#     DEPENDENCIES fmt::fmt spdlog::spdlog
# )
```

#### FetchContent 远程依赖管理

```cmake
# ==========================================
# FetchContent - 配置时下载依赖
# ==========================================
include(FetchContent)

# 声明依赖
FetchContent_Declare(
    googletest
    GIT_REPOSITORY https://github.com/google/googletest.git
    GIT_TAG        v1.14.0
    GIT_SHALLOW    TRUE       # 浅克隆，加速下载
)

FetchContent_Declare(
    fmt
    GIT_REPOSITORY https://github.com/fmtlib/fmt.git
    GIT_TAG        10.2.1
)

FetchContent_Declare(
    json
    URL https://github.com/nlohmann/json/releases/download/v3.11.3/json.tar.xz
    URL_HASH SHA256=d6c65aca6b1ed68e7a182f4757f0f1b0e9eb3d4cf3e5a25e6e9dd3a1a5e926e3
)

# 一次性获取所有依赖
FetchContent_MakeAvailable(googletest fmt json)

# 现在可以直接使用
# target_link_libraries(myapp PRIVATE fmt::fmt nlohmann_json::nlohmann_json)

# ==========================================
# FetchContent 高级用法
# ==========================================

# 自定义构建选项
FetchContent_Declare(spdlog
    GIT_REPOSITORY https://github.com/gabime/spdlog.git
    GIT_TAG        v1.13.0
)
FetchContent_GetProperties(spdlog)
if(NOT spdlog_POPULATED)
    FetchContent_Populate(spdlog)
    set(SPDLOG_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
    set(SPDLOG_BUILD_TESTS OFF CACHE BOOL "" FORCE)
    add_subdirectory(${spdlog_SOURCE_DIR} ${spdlog_BINARY_DIR})
endif()

# ==========================================
# FetchContent vs ExternalProject 对比
# ==========================================
#
# ┌──────────────────┬──────────────────────┐
# │   FetchContent   │   ExternalProject    │
# ├──────────────────┼──────────────────────┤
# │  配置时下载       │  构建时下载           │
# │  融入当前构建树   │  独立构建系统         │
# │  target直接可用   │  需手动创建IMPORTED   │
# │  CMake项目适用    │  任何构建系统都可     │
# │  简单依赖推荐     │  复杂外部项目推荐     │
# └──────────────────┴──────────────────────┘
```

#### 自定义命令与代码生成

```cmake
# ==========================================
# add_custom_command 与 add_custom_target
# ==========================================

# 1. 生成文件的自定义命令
add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/generated_version.hpp
    COMMAND ${CMAKE_COMMAND}
        -DVERSION=${PROJECT_VERSION}
        -DINPUT=${CMAKE_CURRENT_SOURCE_DIR}/version.hpp.in
        -DOUTPUT=${CMAKE_CURRENT_BINARY_DIR}/generated_version.hpp
        -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/GenerateVersion.cmake
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/version.hpp.in
    COMMENT "Generating version header"
)

# 2. 将生成的文件关联到target
target_sources(mylib PRIVATE
    ${CMAKE_CURRENT_BINARY_DIR}/generated_version.hpp
)

# 3. configure_file 模板替换
configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/config.hpp.in
    ${CMAKE_CURRENT_BINARY_DIR}/config.hpp
    @ONLY  # 只替换@VAR@格式，不替换${VAR}
)

# config.hpp.in 模板:
# #pragma once
# #define PROJECT_VERSION "@PROJECT_VERSION@"
# #define PROJECT_NAME "@PROJECT_NAME@"
# #cmakedefine ENABLE_FEATURE_X
# #cmakedefine01 HAS_OPENSSL

# 4. add_custom_target (总是执行)
add_custom_target(format
    COMMAND clang-format -i ${ALL_SOURCE_FILES}
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    COMMENT "Running clang-format on all source files"
)

# 5. 构建前/后钩子
add_custom_command(
    TARGET mylib POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        $<TARGET_FILE:mylib>
        ${CMAKE_SOURCE_DIR}/output/
    COMMENT "Copying library to output directory"
)
```

#### Week 3 输出物清单

| 文件 | 说明 | 完成状态 |
|------|------|---------|
| `notes/cmake_functions.md` | function/macro对比笔记 | [ ] |
| `cmake/MyModule.cmake` | 可复用CMake模块 | [ ] |
| `notes/fetchcontent.md` | FetchContent使用笔记 | [ ] |
| `practice/fetchcontent_demo/` | FetchContent练习项目 | [ ] |
| `notes/custom_commands.md` | 自定义命令笔记 | [ ] |
| `cmake/version.hpp.in` | 版本头文件模板 | [ ] |
| `practice/codegen_demo/` | 代码生成管道练习 | [ ] |

#### Week 3 检验标准

- [ ] 能够解释function和macro的作用域区别
- [ ] 掌握cmake_parse_arguments参数解析
- [ ] 能够编写可复用的CMake函数模块
- [ ] 掌握FetchContent的基础和高级用法
- [ ] 理解FetchContent与ExternalProject的区别与选择
- [ ] 能够编写add_custom_command生成文件
- [ ] 掌握configure_file模板替换机制
- [ ] 理解构建前/后钩子的使用场景

---

### 第四周：跨平台项目结构与安装（35小时）

```
┌─────────────────────────────────────────────────────────────────┐
│  Week 4: 专业级项目工程化                                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Day 22-23: 项目结构与安装导出                                   │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  install(TARGETS) → install(EXPORT) → Config.cmake    │    │
│  │  让其他项目能 find_package 找到你的库                   │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
│  Day 24-25: 测试与打包                                          │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐       │
│  │   CTest     │    │   CPack     │    │  Presets    │       │
│  │   测试框架  │    │   打包工具  │    │ 构建预设    │       │
│  └─────────────┘    └─────────────┘    └─────────────┘       │
│                                                                 │
│  Day 26-28: Toolchain与综合实战                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  Toolchain文件(交叉编译) + CI/CD集成 + 综合项目完善    │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### 每日任务分解

| Day | 时间 | 上午任务(2.5h) | 下午任务(2.5h) | 输出物 |
|-----|------|---------------|---------------|--------|
| 22 | 5h | 标准项目目录结构设计 | install规则与导出系统 | notes/project_structure.md |
| 23 | 5h | Config.cmake与版本兼容 | 实践：让库可被find_package | practice/installable_lib/ |
| 24 | 5h | CTest深入（add_test/ctest) | CPack打包(DEB/RPM/ZIP/NSIS) | notes/ctest_cpack.md |
| 25 | 5h | CMakePresets.json编写 | 多配置构建预设实践 | CMakePresets.json |
| 26 | 5h | Toolchain文件编写 | 交叉编译实践(ARM) | cmake/toolchain_arm.cmake |
| 27 | 5h | CI/CD中的CMake最佳实践 | GitHub Actions CMake配置 | .github/workflows/cmake.yml |
| 28 | 5h | 综合项目完善与集成 | 最终测试与文档完善 | 完整项目模板 |

**学习目标**：构建专业的项目结构，支持安装和导出

**阅读材料**：
- [ ] CMake文档：cmake-packages
- [ ] 《Professional CMake》第25-28章

```cmake
# ==========================================
# 项目根目录 CMakeLists.txt
# ==========================================
cmake_minimum_required(VERSION 3.16)

project(MyProject
    VERSION 1.2.3
    DESCRIPTION "A professional C++ project"
    HOMEPAGE_URL "https://github.com/user/myproject"
    LANGUAGES CXX
)

# 防止in-source构建
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_BINARY_DIR)
    message(FATAL_ERROR "In-source builds are not allowed")
endif()

# 标准项目选项
option(MYPROJECT_BUILD_TESTS "Build tests" ON)
option(MYPROJECT_BUILD_DOCS "Build documentation" OFF)
option(MYPROJECT_BUILD_EXAMPLES "Build examples" ON)
option(MYPROJECT_INSTALL "Generate install target" ON)

# C++标准
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# 输出目录
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

# 模块路径
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# 包含自定义模块
include(CompilerWarnings)
include(Sanitizers)

# 子目录
add_subdirectory(src)
add_subdirectory(apps)

if(MYPROJECT_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()

if(MYPROJECT_BUILD_EXAMPLES)
    add_subdirectory(examples)
endif()

# ==========================================
# src/CMakeLists.txt - 库定义
# ==========================================
add_library(myproject
    core/engine.cpp
    core/config.cpp
    utils/logger.cpp
    utils/string_utils.cpp
)
add_library(MyProject::myproject ALIAS myproject)

target_include_directories(myproject
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../include>
        $<INSTALL_INTERFACE:include>
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
)

target_compile_features(myproject PUBLIC cxx_std_17)

# 应用警告设置
set_project_warnings(myproject)

# 查找依赖
find_package(fmt REQUIRED)
find_package(spdlog REQUIRED)

target_link_libraries(myproject
    PUBLIC
        fmt::fmt
    PRIVATE
        spdlog::spdlog
)

# 版本信息
set_target_properties(myproject PROPERTIES
    VERSION ${PROJECT_VERSION}
    SOVERSION ${PROJECT_VERSION_MAJOR}
)

# ==========================================
# cmake/MyProjectConfig.cmake.in
# ==========================================
@PACKAGE_INIT@

include(CMakeFindDependencyMacro)

find_dependency(fmt)

include("${CMAKE_CURRENT_LIST_DIR}/MyProjectTargets.cmake")

check_required_components(MyProject)

# ==========================================
# 安装规则（在根CMakeLists.txt或单独文件）
# ==========================================
if(MYPROJECT_INSTALL)
    include(GNUInstallDirs)
    include(CMakePackageConfigHelpers)

    # 安装库文件
    install(TARGETS myproject
        EXPORT MyProjectTargets
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
        INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
    )

    # 安装头文件
    install(DIRECTORY include/
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
    )

    # 安装导出目标
    install(EXPORT MyProjectTargets
        FILE MyProjectTargets.cmake
        NAMESPACE MyProject::
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/MyProject
    )

    # 生成版本文件
    write_basic_package_version_file(
        "${CMAKE_CURRENT_BINARY_DIR}/MyProjectConfigVersion.cmake"
        VERSION ${PROJECT_VERSION}
        COMPATIBILITY SameMajorVersion
    )

    # 配置Config文件
    configure_package_config_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/cmake/MyProjectConfig.cmake.in"
        "${CMAKE_CURRENT_BINARY_DIR}/MyProjectConfig.cmake"
        INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/MyProject
    )

    # 安装Config文件
    install(FILES
        "${CMAKE_CURRENT_BINARY_DIR}/MyProjectConfig.cmake"
        "${CMAKE_CURRENT_BINARY_DIR}/MyProjectConfigVersion.cmake"
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/MyProject
    )
endif()
```

#### CTest 测试框架深入

```cmake
# ==========================================
# CTest 深入使用
# ==========================================

enable_testing()

# 基本测试注册
add_test(NAME unit_tests COMMAND myproject_tests)

# 带参数的测试
add_test(NAME integration_test
    COMMAND myapp --config ${CMAKE_SOURCE_DIR}/test/config.json
)

# 设置测试属性
set_tests_properties(unit_tests PROPERTIES
    TIMEOUT 60                    # 超时秒数
    LABELS "unit"                 # 标签分类
    ENVIRONMENT "ENV_VAR=value"   # 环境变量
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
)

set_tests_properties(integration_test PROPERTIES
    LABELS "integration"
    TIMEOUT 300
    FIXTURES_REQUIRED server_running  # 依赖fixture
)

# 使用GTest自动发现测试
include(GoogleTest)
gtest_discover_tests(myproject_tests
    PROPERTIES
        LABELS "unit"
        TIMEOUT 30
    DISCOVERY_TIMEOUT 10
)

# 运行测试命令：
# ctest --test-dir build            # 运行所有测试
# ctest -L unit                     # 只运行unit标签
# ctest -R "test_engine*"           # 正则匹配
# ctest -j$(nproc)                  # 并行运行
# ctest --output-on-failure         # 失败时显示输出
# ctest --rerun-failed              # 重跑失败的测试
```

#### CPack 打包配置

```cmake
# ==========================================
# CPack 打包配置
# ==========================================
include(CPack)

# 基本信息
set(CPACK_PACKAGE_NAME "${PROJECT_NAME}")
set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "${PROJECT_DESCRIPTION}")
set(CPACK_PACKAGE_VENDOR "MyOrg")
set(CPACK_PACKAGE_CONTACT "dev@example.com")
set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_SOURCE_DIR}/LICENSE")
set(CPACK_RESOURCE_FILE_README "${CMAKE_SOURCE_DIR}/README.md")

# 按平台配置
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(CPACK_GENERATOR "DEB;RPM;TGZ")

    # DEB包配置
    set(CPACK_DEBIAN_PACKAGE_DEPENDS "libfmt-dev (>= 10.0)")
    set(CPACK_DEBIAN_PACKAGE_SECTION "devel")

    # RPM包配置
    set(CPACK_RPM_PACKAGE_REQUIRES "fmt-devel >= 10.0")

elseif(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    set(CPACK_GENERATOR "NSIS;ZIP")

    # NSIS安装器配置
    set(CPACK_NSIS_DISPLAY_NAME "${PROJECT_NAME}")
    set(CPACK_NSIS_INSTALL_ROOT "C:\\\\Program Files")

elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    set(CPACK_GENERATOR "DragNDrop;TGZ")
endif()

# 打包命令：
# cmake --build build --target package
# 或: cd build && cpack -G DEB
```

#### CMakePresets.json

```json
// CMakePresets.json - 构建预设配置
{
    "version": 6,
    "cmakeMinimumRequired": {
        "major": 3,
        "minor": 25,
        "patch": 0
    },
    "configurePresets": [
        {
            "name": "default",
            "hidden": true,
            "generator": "Ninja",
            "binaryDir": "${sourceDir}/build/${presetName}",
            "cacheVariables": {
                "CMAKE_CXX_STANDARD": "17",
                "CMAKE_EXPORT_COMPILE_COMMANDS": "ON"
            }
        },
        {
            "name": "debug",
            "inherits": "default",
            "displayName": "Debug",
            "cacheVariables": {
                "CMAKE_BUILD_TYPE": "Debug",
                "ENABLE_ASAN": "ON"
            }
        },
        {
            "name": "release",
            "inherits": "default",
            "displayName": "Release",
            "cacheVariables": {
                "CMAKE_BUILD_TYPE": "Release"
            }
        },
        {
            "name": "ci",
            "inherits": "default",
            "displayName": "CI Build",
            "cacheVariables": {
                "CMAKE_BUILD_TYPE": "Release",
                "BUILD_TESTING": "ON",
                "MYPROJECT_BUILD_DOCS": "OFF"
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
    ],
    "testPresets": [
        {
            "name": "default",
            "configurePreset": "debug",
            "output": {
                "outputOnFailure": true
            },
            "execution": {
                "noTestsAction": "error",
                "timeout": 120
            }
        }
    ]
}
```

```
使用预设的命令：
cmake --preset debug           # 配置
cmake --build --preset debug   # 构建
ctest --preset default         # 测试
```

#### Toolchain文件与交叉编译

```cmake
# ==========================================
# cmake/toolchain_arm.cmake
# ARM交叉编译Toolchain文件
# ==========================================

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)

# 交叉编译工具链路径
set(TOOLCHAIN_PREFIX arm-linux-gnueabihf)
set(CMAKE_C_COMPILER ${TOOLCHAIN_PREFIX}-gcc)
set(CMAKE_CXX_COMPILER ${TOOLCHAIN_PREFIX}-g++)

# Sysroot（目标系统的根文件系统）
set(CMAKE_SYSROOT /opt/arm-sysroot)

# 查找策略
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)   # 主机程序
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)    # 目标库
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)    # 目标头文件
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)    # 目标包

# 使用方式：
# cmake -S . -B build-arm -DCMAKE_TOOLCHAIN_FILE=cmake/toolchain_arm.cmake
```

#### CI/CD集成示例

```yaml
# .github/workflows/cmake.yml
name: CMake Build & Test

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        build_type: [Debug, Release]

    runs-on: ${{ matrix.os }}

    steps:
    - uses: actions/checkout@v4

    - name: Configure
      run: >
        cmake -S . -B build
        -DCMAKE_BUILD_TYPE=${{ matrix.build_type }}
        -DBUILD_TESTING=ON

    - name: Build
      run: cmake --build build --config ${{ matrix.build_type }}

    - name: Test
      run: ctest --test-dir build -C ${{ matrix.build_type }} --output-on-failure
```

#### Week 4 输出物清单

| 文件 | 说明 | 完成状态 |
|------|------|---------|
| `notes/project_structure.md` | 项目结构设计笔记 | [ ] |
| `practice/installable_lib/` | 可安装库练习项目 | [ ] |
| `notes/ctest_cpack.md` | CTest与CPack笔记 | [ ] |
| `CMakePresets.json` | 构建预设配置 | [ ] |
| `cmake/toolchain_arm.cmake` | ARM交叉编译Toolchain | [ ] |
| `.github/workflows/cmake.yml` | CI/CD配置 | [ ] |
| 完整项目模板 | 综合项目最终版 | [ ] |

#### Week 4 检验标准

- [ ] 能够设计符合规范的C++项目目录结构
- [ ] 掌握install()和export()的配合使用
- [ ] 能够让自己的库被find_package找到并使用
- [ ] 掌握CTest的测试注册与运行
- [ ] 能够配置CPack生成安装包（DEB/RPM/ZIP）
- [ ] 能够编写CMakePresets.json简化构建配置
- [ ] 理解Toolchain文件在交叉编译中的作用
- [ ] 能够配置GitHub Actions进行CI/CD

---

## 源码阅读任务

### 本月源码阅读

1. **CMake官方示例**
   - 仓库：https://github.com/Kitware/CMake
   - 重点：`Tests/Tutorial` 目录
   - 学习目标：理解官方推荐的项目结构

2. **fmtlib的CMake配置**
   - 仓库：https://github.com/fmtlib/fmt
   - 重点：根目录`CMakeLists.txt`和`support/cmake`目录
   - 学习目标：学习高质量库的CMake实践

3. **spdlog的CMake配置**
   - 仓库：https://github.com/gabime/spdlog
   - 重点：CMake配置和header-only模式处理
   - 学习目标：理解header-only库的导出方式

---

## 实践项目

### 项目：构建专业级C++项目模板

创建一个可复用的C++项目模板，包含完整的Modern CMake配置。

```
myproject/
├── CMakeLists.txt
├── cmake/
│   ├── CompilerWarnings.cmake
│   ├── Sanitizers.cmake
│   ├── StaticAnalyzers.cmake
│   └── MyProjectConfig.cmake.in
├── include/
│   └── myproject/
│       ├── myproject.hpp
│       ├── core/
│       │   └── engine.hpp
│       └── utils/
│           └── string_utils.hpp
├── src/
│   ├── CMakeLists.txt
│   ├── core/
│   │   └── engine.cpp
│   └── utils/
│       └── string_utils.cpp
├── apps/
│   ├── CMakeLists.txt
│   └── main.cpp
├── tests/
│   ├── CMakeLists.txt
│   └── test_engine.cpp
└── examples/
    ├── CMakeLists.txt
    └── basic_example.cpp
```

**include/myproject/myproject.hpp**：

```cpp
#pragma once

// 主头文件，包含所有公共API
#include "myproject/core/engine.hpp"
#include "myproject/utils/string_utils.hpp"

// 版本信息（由CMake生成）
#define MYPROJECT_VERSION_MAJOR @PROJECT_VERSION_MAJOR@
#define MYPROJECT_VERSION_MINOR @PROJECT_VERSION_MINOR@
#define MYPROJECT_VERSION_PATCH @PROJECT_VERSION_PATCH@

namespace myproject {

inline constexpr const char* version() {
    return "@PROJECT_VERSION@";
}

} // namespace myproject
```

**include/myproject/core/engine.hpp**：

```cpp
#pragma once

#include <string>
#include <memory>
#include <functional>
#include <vector>

namespace myproject::core {

// 前向声明
class EngineImpl;

/**
 * @brief 核心引擎类
 *
 * 使用PImpl模式隐藏实现细节
 */
class Engine {
public:
    struct Config {
        std::string name = "default";
        size_t thread_count = 4;
        bool enable_logging = true;
    };

    explicit Engine(Config config = {});
    ~Engine();

    // 禁用拷贝
    Engine(const Engine&) = delete;
    Engine& operator=(const Engine&) = delete;

    // 允许移动
    Engine(Engine&&) noexcept;
    Engine& operator=(Engine&&) noexcept;

    // 核心API
    void start();
    void stop();
    bool is_running() const;

    // 任务调度
    using Task = std::function<void()>;
    void submit(Task task);
    void wait_all();

    // 状态查询
    size_t pending_tasks() const;
    const Config& config() const;

private:
    std::unique_ptr<EngineImpl> impl_;
};

} // namespace myproject::core
```

**include/myproject/utils/string_utils.hpp**：

```cpp
#pragma once

#include <string>
#include <string_view>
#include <vector>
#include <algorithm>
#include <sstream>

namespace myproject::utils {

/**
 * @brief 字符串工具函数集合
 */
class StringUtils {
public:
    // 删除默认构造（纯静态类）
    StringUtils() = delete;

    /**
     * @brief 去除字符串两端空白
     */
    static std::string trim(std::string_view str) {
        auto start = str.find_first_not_of(" \t\n\r");
        if (start == std::string_view::npos) return "";
        auto end = str.find_last_not_of(" \t\n\r");
        return std::string(str.substr(start, end - start + 1));
    }

    /**
     * @brief 分割字符串
     */
    static std::vector<std::string> split(std::string_view str, char delimiter) {
        std::vector<std::string> result;
        std::stringstream ss(std::string(str));
        std::string item;
        while (std::getline(ss, item, delimiter)) {
            if (!item.empty()) {
                result.push_back(item);
            }
        }
        return result;
    }

    /**
     * @brief 连接字符串
     */
    template<typename Container>
    static std::string join(const Container& parts, std::string_view separator) {
        std::string result;
        bool first = true;
        for (const auto& part : parts) {
            if (!first) result += separator;
            result += part;
            first = false;
        }
        return result;
    }

    /**
     * @brief 转小写
     */
    static std::string to_lower(std::string_view str) {
        std::string result(str);
        std::transform(result.begin(), result.end(), result.begin(),
                       [](unsigned char c) { return std::tolower(c); });
        return result;
    }

    /**
     * @brief 转大写
     */
    static std::string to_upper(std::string_view str) {
        std::string result(str);
        std::transform(result.begin(), result.end(), result.begin(),
                       [](unsigned char c) { return std::toupper(c); });
        return result;
    }

    /**
     * @brief 检查前缀
     */
    static bool starts_with(std::string_view str, std::string_view prefix) {
        return str.size() >= prefix.size() &&
               str.substr(0, prefix.size()) == prefix;
    }

    /**
     * @brief 检查后缀
     */
    static bool ends_with(std::string_view str, std::string_view suffix) {
        return str.size() >= suffix.size() &&
               str.substr(str.size() - suffix.size()) == suffix;
    }

    /**
     * @brief 替换所有匹配项
     */
    static std::string replace_all(std::string_view str,
                                    std::string_view from,
                                    std::string_view to) {
        std::string result(str);
        size_t pos = 0;
        while ((pos = result.find(from, pos)) != std::string::npos) {
            result.replace(pos, from.length(), to);
            pos += to.length();
        }
        return result;
    }
};

} // namespace myproject::utils
```

**src/core/engine.cpp**：

```cpp
#include "myproject/core/engine.hpp"
#include <thread>
#include <queue>
#include <mutex>
#include <condition_variable>
#include <atomic>

namespace myproject::core {

class EngineImpl {
public:
    explicit EngineImpl(Engine::Config config)
        : config_(std::move(config))
        , running_(false) {}

    ~EngineImpl() {
        stop();
    }

    void start() {
        if (running_.exchange(true)) return;

        for (size_t i = 0; i < config_.thread_count; ++i) {
            workers_.emplace_back([this] { worker_loop(); });
        }
    }

    void stop() {
        if (!running_.exchange(false)) return;

        cv_.notify_all();
        for (auto& worker : workers_) {
            if (worker.joinable()) {
                worker.join();
            }
        }
        workers_.clear();
    }

    bool is_running() const {
        return running_.load();
    }

    void submit(Engine::Task task) {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            tasks_.push(std::move(task));
        }
        cv_.notify_one();
    }

    void wait_all() {
        std::unique_lock<std::mutex> lock(mutex_);
        done_cv_.wait(lock, [this] {
            return tasks_.empty() && active_tasks_ == 0;
        });
    }

    size_t pending_tasks() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return tasks_.size();
    }

    const Engine::Config& config() const {
        return config_;
    }

private:
    void worker_loop() {
        while (running_.load()) {
            Engine::Task task;
            {
                std::unique_lock<std::mutex> lock(mutex_);
                cv_.wait(lock, [this] {
                    return !tasks_.empty() || !running_.load();
                });

                if (!running_.load() && tasks_.empty()) return;

                task = std::move(tasks_.front());
                tasks_.pop();
                ++active_tasks_;
            }

            task();

            {
                std::lock_guard<std::mutex> lock(mutex_);
                --active_tasks_;
            }
            done_cv_.notify_all();
        }
    }

    Engine::Config config_;
    std::atomic<bool> running_;
    std::vector<std::thread> workers_;
    std::queue<Engine::Task> tasks_;
    mutable std::mutex mutex_;
    std::condition_variable cv_;
    std::condition_variable done_cv_;
    size_t active_tasks_ = 0;
};

// Engine实现
Engine::Engine(Config config)
    : impl_(std::make_unique<EngineImpl>(std::move(config))) {}

Engine::~Engine() = default;

Engine::Engine(Engine&&) noexcept = default;
Engine& Engine::operator=(Engine&&) noexcept = default;

void Engine::start() { impl_->start(); }
void Engine::stop() { impl_->stop(); }
bool Engine::is_running() const { return impl_->is_running(); }
void Engine::submit(Task task) { impl_->submit(std::move(task)); }
void Engine::wait_all() { impl_->wait_all(); }
size_t Engine::pending_tasks() const { return impl_->pending_tasks(); }
const Engine::Config& Engine::config() const { return impl_->config(); }

} // namespace myproject::core
```

**tests/CMakeLists.txt**：

```cmake
# 查找测试框架
find_package(GTest REQUIRED)
include(GoogleTest)

# 创建测试可执行文件
add_executable(myproject_tests
    test_engine.cpp
    test_string_utils.cpp
)

target_link_libraries(myproject_tests
    PRIVATE
        myproject
        GTest::gtest
        GTest::gtest_main
)

# 发现并注册测试
gtest_discover_tests(myproject_tests)
```

**tests/test_engine.cpp**：

```cpp
#include <gtest/gtest.h>
#include <myproject/core/engine.hpp>
#include <atomic>
#include <chrono>

using namespace myproject::core;

class EngineTest : public ::testing::Test {
protected:
    void SetUp() override {
        config_.name = "test_engine";
        config_.thread_count = 2;
        config_.enable_logging = false;
    }

    Engine::Config config_;
};

TEST_F(EngineTest, DefaultConstruction) {
    Engine engine;
    EXPECT_FALSE(engine.is_running());
}

TEST_F(EngineTest, StartStop) {
    Engine engine(config_);

    engine.start();
    EXPECT_TRUE(engine.is_running());

    engine.stop();
    EXPECT_FALSE(engine.is_running());
}

TEST_F(EngineTest, SubmitTask) {
    Engine engine(config_);
    engine.start();

    std::atomic<int> counter{0};

    for (int i = 0; i < 10; ++i) {
        engine.submit([&counter] {
            ++counter;
        });
    }

    engine.wait_all();
    EXPECT_EQ(counter.load(), 10);

    engine.stop();
}

TEST_F(EngineTest, MoveSemantics) {
    Engine engine1(config_);
    engine1.start();

    Engine engine2 = std::move(engine1);
    EXPECT_TRUE(engine2.is_running());

    engine2.stop();
}
```

---

## 检验标准

- [ ] 理解Modern CMake的Target-centric理念
- [ ] 掌握PUBLIC/PRIVATE/INTERFACE的使用场景
- [ ] 能编写Generator Expressions处理跨平台需求
- [ ] 能创建可复用的CMake模块和函数
- [ ] 能配置完整的项目安装和导出
- [ ] 项目能在Windows/Linux/macOS上正确构建

### 知识检验问题

1. `target_link_libraries`中PUBLIC和PRIVATE的区别是什么？
2. 为什么要用`$<BUILD_INTERFACE:...>`和`$<INSTALL_INTERFACE:...>`？
3. 如何让find_package找到自己的库？
4. CMake中如何实现跨编译器的警告配置？

---

## 输出物清单

1. **项目模板**
   - `myproject/` - 完整的项目结构
   - 可在GitHub上作为template使用

2. **CMake模块库**
   - `cmake/CompilerWarnings.cmake`
   - `cmake/Sanitizers.cmake`
   - `cmake/StaticAnalyzers.cmake`

3. **文档**
   - `notes/month37_cmake.md` - 学习笔记
   - `notes/cmake_cheatsheet.md` - 常用命令速查表

4. **示例配置**
   - 多平台构建脚本
   - VSCode/CLion配置文件

---

## 时间分配表

| 周次 | 主题 | 理论学习 | 实践编码 | 源码阅读 |
|------|------|----------|----------|----------|
| 第1周 | Modern CMake基础 | 15h | 15h | 5h |
| 第2周 | 依赖传播机制 | 12h | 18h | 5h |
| 第3周 | 模块与函数 | 10h | 20h | 5h |
| 第4周 | 项目结构与安装 | 8h | 22h | 5h |
| **合计** | | **45h** | **75h** | **20h** |

---

## 月度验收标准

### 知识掌握

- [ ] 能够流利解释Modern CMake与传统CMake的核心区别
- [ ] 掌握Target-centric理念并应用于实际项目
- [ ] 理解CMake的Configure/Generate/Build/Install四个阶段
- [ ] 掌握变量作用域、缓存变量和策略系统

### 实践能力

- [ ] 能够从零搭建一个完整的Modern CMake项目
- [ ] 掌握PUBLIC/PRIVATE/INTERFACE的传播规则
- [ ] 能够编写Generator Expressions处理跨平台需求
- [ ] 能够编写可复用的CMake函数和模块
- [ ] 掌握FetchContent管理远程依赖

### 工程化能力

- [ ] 项目支持install和find_package
- [ ] 集成CTest测试框架
- [ ] 配置CPack生成安装包
- [ ] 编写CMakePresets.json
- [ ] 理解Toolchain文件与交叉编译
- [ ] 能够配置CI/CD自动化构建

### 综合项目检验

- [ ] 项目模板能在Linux/macOS/Windows上正确构建
- [ ] 所有单元测试通过
- [ ] 生成的库可以被其他项目通过find_package使用
- [ ] 代码通过静态分析（clang-tidy/cppcheck）

---

### 本月知识图谱

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Month 37: Modern CMake 知识体系                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   基础层                                                            │
│   ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐             │
│   │执行流程   │ │Target模型 │ │变量系统   │ │策略系统   │             │
│   │Configure │ │Properties│ │ Scope    │ │ Policy   │             │
│   │Generate  │ │ PUBLIC   │ │ Cache    │ │ CMP0xxx  │             │
│   │ Build    │ │ PRIVATE  │ │ Env      │ │          │             │
│   └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘             │
│        └────────────┴────────────┴────────────┘                    │
│                          │                                          │
│   依赖管理层             ▼                                          │
│   ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐             │
│   │find_pkg  │ │IMPORTED  │ │GenExpr   │ │Transitive│             │
│   │MODULE    │ │ Targets  │ │$<...>    │ │Dependency│             │
│   │CONFIG    │ │          │ │          │ │          │             │
│   └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘             │
│        └────────────┴────────────┴────────────┘                    │
│                          │                                          │
│   模块化层               ▼                                          │
│   ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐             │
│   │function  │ │Fetch     │ │External  │ │Custom    │             │
│   │macro     │ │Content   │ │Project   │ │Command   │             │
│   │parse_args│ │          │ │          │ │configure │             │
│   └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘             │
│        └────────────┴────────────┴────────────┘                    │
│                          │                                          │
│   工程化层               ▼                                          │
│   ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐             │
│   │Install   │ │CTest     │ │CPack     │ │Presets   │             │
│   │Export    │ │GTest     │ │DEB/RPM   │ │Toolchain │             │
│   │Config.cmake│        │ │NSIS/ZIP  │ │CI/CD     │             │
│   └──────────┘ └──────────┘ └──────────┘ └──────────┘             │
│                                                                     │
│   ═════════════════════════════════════════════════                 │
│                    ▼                                                │
│              专业级C++项目模板                                       │
│              (Month 37 毕业项目)                                    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 下月预告

Month 38将学习**vcpkg包管理器**，掌握微软开源的跨平台C++包管理工具，实现依赖的自动化管理。将与本月学习的CMake深度配合，建立完整的C++项目依赖管理链。

```
Month 37 (CMake)          Month 38 (vcpkg)
┌─────────────────┐      ┌─────────────────┐
│ Modern CMake    │  →   │ 包管理          │
│ Target-centric  │      │ 依赖自动化      │
│ Install/Export  │      │ Manifest模式    │
│ CI/CD          │      │ vcpkg.json     │
└─────────────────┘      └─────────────────┘
```

