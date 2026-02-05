# Month 43: Clang-Tidy静态分析——代码质量的守护者

## 本月主题概述

本月深入学习Clang-Tidy，这是LLVM项目提供的强大静态分析工具。学习如何配置和使用各类检查器，实现代码风格统一、潜在Bug检测、性能优化建议，以及现代C++迁移。

**学习目标**：
- 掌握Clang-Tidy的安装、配置和使用
- 理解各类检查器的作用和使用场景
- 学会创建自定义检查规则
- 将静态分析集成到开发流程中

---

## 理论学习内容

### 第一周：Clang-Tidy基础

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Week 1: Clang-Tidy基础与静态分析概述                       │
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │  Day 1-2    │───▶│  Day 3-4    │───▶│  Day 5-6    │───▶│   Day 7     │  │
│  │ 静态分析    │    │ Clang-Tidy  │    │ 编译数据库  │    │ 检查器分类  │  │
│  │ 生态与原理  │    │ 安装与使用  │    │ 与工作流    │    │ 源码阅读    │  │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘  │
│                                                                             │
│  核心技能：                                                                  │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │ • 静态分析工具对比（Clang-Tidy/Cppcheck/PVS-Studio/SonarQube）      │ │
│  │ • Clang-Tidy内部架构（Frontend→AST→Matchers→Checks→Diagnostics）    │ │
│  │ • compile_commands.json生成与结构理解                                 │ │
│  │ • 检查器分类体系与选择策略                                            │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
│  输出物：基础环境 + 分析工具对比文档 + 笔记                学习时间：35小时 │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Week 1 每日任务分解

| 天数 | 时间 | 主题 | 具体任务 | 输出物 |
|------|------|------|----------|--------|
| Day 1 | 5h | 静态分析概论 | 1. 静态分析 vs 动态分析原理 2. C++静态分析工具全景 3. 工具能力矩阵对比 4. 误报/漏报权衡 | notes/static_analysis_overview.md |
| Day 2 | 5h | Clang-Tidy架构 | 1. LLVM/Clang工具链架构 2. Clang-Tidy内部流程 3. AST概念入门 4. 检查器注册机制 | notes/clang_tidy_architecture.md |
| Day 3 | 5h | 安装与基本使用 | 1. 多平台安装（apt/brew/LLVM包） 2. 基本命令行参数 3. 分析单文件/多文件 4. --fix自动修复体验 | practice/basic_usage/ |
| Day 4 | 5h | 编译数据库 | 1. compile_commands.json结构与字段 2. CMake/Bear/Ninja生成方式 3. 与IDE集成 4. 常见问题排查 | notes/compile_database.md |
| Day 5 | 5h | 检查器分类体系 | 1. 12大检查器类别详解 2. --list-checks与--explain-check 3. 启用/禁用语法 4. 按项目类型选择组合 | notes/checker_categories.md |
| Day 6 | 5h | 工作流实践 | 1. run-clang-tidy并行分析 2. export-fixes导出修复 3. clang-apply-replacements 4. 编辑器集成 | practice/workflow_demo/ |
| Day 7 | 5h | 源码阅读与总结 | 1. 阅读clang-tidy源码目录结构 2. 阅读modernize-use-nullptr实现 3. Week 1知识总结 | notes/week1_clang_tidy_basics.md |

---

**学习目标**：安装和基本使用Clang-Tidy

**阅读材料**：
- [ ] Clang-Tidy官方文档
- [ ] LLVM Coding Standards
- [ ] Extra Clang Tools文档

**核心概念**：

#### 静态分析工具生态对比

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    C++ 静态分析工具生态                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ Clang-Tidy   │  │  Cppcheck    │  │ PVS-Studio   │  │  SonarQube   │   │
│  ├──────────────┤  ├──────────────┤  ├──────────────┤  ├──────────────┤   │
│  │ 类型: 开源   │  │ 类型: 开源   │  │ 类型: 商业   │  │ 类型: 混合   │   │
│  │ 基于: Clang  │  │ 基于: 独立   │  │ 基于: 独立   │  │ 基于: 平台   │   │
│  │ AST级分析    │  │ Token级分析  │  │ 深度路径分析 │  │ 多语言支持   │   │
│  │ 自动修复 ✓   │  │ 自动修复 ✗   │  │ 自动修复 ✗   │  │ 自动修复 ✗   │   │
│  │ 扩展性 ★★★ │  │ 扩展性 ★★   │  │ 扩展性 ★    │  │ 扩展性 ★★★ │   │
│  │ 速度   ★★   │  │ 速度   ★★★ │  │ 速度   ★★   │  │ 速度   ★    │   │
│  │ 检查数 600+  │  │ 检查数 200+  │  │ 检查数 900+  │  │ 检查数 500+  │   │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘   │
│                                                                             │
│  选择建议：                                                                  │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │ • 开源项目/个人学习   → Clang-Tidy + Cppcheck（互补）             │    │
│  │ • 企业级项目           → Clang-Tidy + PVS-Studio（深度）          │    │
│  │ • 多语言大型项目       → SonarQube + Clang-Tidy（全面）           │    │
│  │ • CI/CD集成优先        → Clang-Tidy（原生支持最好）               │    │
│  └────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Clang-Tidy 内部架构

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Clang-Tidy 内部处理流程                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  源代码文件 (.cpp/.hpp)                                                     │
│       │                                                                     │
│       ▼                                                                     │
│  ┌──────────────────┐                                                      │
│  │  Clang Frontend   │  预处理 → 词法分析 → 语法分析                        │
│  │  (编译前端)       │  生成编译单元的完整表示                              │
│  └────────┬─────────┘                                                      │
│           │                                                                 │
│           ▼                                                                 │
│  ┌──────────────────┐                                                      │
│  │  AST Construction │  抽象语法树构建                                      │
│  │  (AST构建)        │  类型信息、作用域、声明/定义                         │
│  └────────┬─────────┘                                                      │
│           │                                                                 │
│           ▼                                                                 │
│  ┌──────────────────┐  ┌────────────────────────────────────────────┐      │
│  │  AST Matchers     │  │  匹配规则示例：                            │      │
│  │  (AST匹配器)      │──│  hasName("NULL") → modernize-use-nullptr │      │
│  │                   │  │  isExpansionInMainFile() → 过滤系统头文件 │      │
│  └────────┬─────────┘  └────────────────────────────────────────────┘      │
│           │                                                                 │
│           ▼                                                                 │
│  ┌──────────────────┐  ┌────────────────────────────────────────────┐      │
│  │  Check Modules    │  │  检查器模块列表：                          │      │
│  │  (检查器模块)      │──│  bugprone-* │ modernize-* │ performance-*│      │
│  │                   │  │  readability-* │ cppcoreguidelines-*      │      │
│  └────────┬─────────┘  └────────────────────────────────────────────┘      │
│           │                                                                 │
│           ▼                                                                 │
│  ┌──────────────────┐                                                      │
│  │  Diagnostics      │  警告/错误信息 + 源码位置 + 修复建议                │
│  │  (诊断输出)       │  → 终端输出 / YAML导出 / SARIF格式                  │
│  └──────────────────┘                                                      │
└─────────────────────────────────────────────────────────────────────────────┘
```

```bash
# ==========================================
# 安装Clang-Tidy
# ==========================================

# Ubuntu/Debian
sudo apt-get install clang-tidy

# 指定版本
sudo apt-get install clang-tidy-15

# macOS
brew install llvm
export PATH="/opt/homebrew/opt/llvm/bin:$PATH"

# Windows (通过LLVM安装包)
# 下载: https://releases.llvm.org/

# 验证安装
clang-tidy --version

# ==========================================
# 基本使用
# ==========================================

# 分析单个文件
clang-tidy source.cpp -- -std=c++17 -I/path/to/include

# 使用编译数据库
clang-tidy -p build source.cpp

# 分析多个文件
clang-tidy -p build src/*.cpp

# 使用run-clang-tidy脚本（并行）
run-clang-tidy -p build

# 自动修复
clang-tidy -p build -fix source.cpp

# 导出修复建议
clang-tidy -p build -export-fixes=fixes.yaml source.cpp
clang-apply-replacements fixes.yaml
```

**生成编译数据库**：

```bash
# ==========================================
# compile_commands.json生成
# ==========================================

# CMake方式（推荐）
cmake -B build -S . -DCMAKE_EXPORT_COMPILE_COMMANDS=ON

# 或在CMakeLists.txt中设置
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Bear工具（包装make）
bear -- make

# Ninja
ninja -t compdb > compile_commands.json

# 符号链接到源码目录（方便IDE使用）
ln -s build/compile_commands.json .
```

#### compile_commands.json 结构详解

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                compile_commands.json 文件结构                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  [                                                                          │
│    {                                                                        │
│      "directory": "/path/to/build",    ← 编译工作目录                      │
│      "command": "g++ -std=c++17 ...",  ← 完整编译命令                      │
│      "file": "/path/to/source.cpp"     ← 源文件绝对路径                    │
│    },                                                                       │
│    ...                                                                      │
│  ]                                                                          │
│                                                                             │
│  关键字段说明：                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ directory │ 编译时的工作目录，用于解析相对路径的include             │  │
│  │ command   │ 完整的编译命令（或 arguments 数组形式）                 │  │
│  │ file      │ 被编译的源文件路径                                      │  │
│  │ output    │ （可选）编译输出文件路径                                 │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  Clang-Tidy使用此文件获取：                                                 │
│  • 编译器标志（-std=, -D, -I 等）                                          │
│  • 头文件搜索路径                                                           │
│  • 预定义宏                                                                 │
│  • 源文件列表                                                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

**检查器分类**：

```bash
# ==========================================
# 检查器类别
# ==========================================

# 列出所有检查器
clang-tidy --list-checks -checks='*'

# 主要类别：
# bugprone-*      - 潜在Bug检测
# cert-*          - CERT编码标准
# clang-analyzer-* - Clang静态分析器
# cppcoreguidelines-* - C++ Core Guidelines
# google-*        - Google编码规范
# hicpp-*         - High Integrity C++
# llvm-*          - LLVM编码规范
# misc-*          - 杂项检查
# modernize-*     - 现代C++迁移
# performance-*   - 性能优化
# portability-*   - 可移植性
# readability-*   - 可读性

# 查看检查器详情
clang-tidy --explain-check=modernize-use-nullptr
```

#### Week 1 输出物清单

| 类别 | 文件/目录 | 说明 |
|------|-----------|------|
| 对比文档 | `notes/static_analysis_overview.md` | 静态分析工具生态对比 |
| 架构笔记 | `notes/clang_tidy_architecture.md` | Clang-Tidy内部架构分析 |
| 实践代码 | `practice/basic_usage/` | 基本使用与工作流示例 |
| 编译数据库 | `notes/compile_database.md` | compile_commands.json详解 |
| 分类笔记 | `notes/checker_categories.md` | 12大检查器类别参考 |
| 学习笔记 | `notes/week1_clang_tidy_basics.md` | Week 1核心概念总结 |

#### Week 1 检验标准

- [ ] 能在macOS/Linux上安装并运行Clang-Tidy
- [ ] 理解Clang-Tidy与Cppcheck/PVS-Studio的区别
- [ ] 能解释Clang-Tidy的AST匹配工作原理
- [ ] 能生成和使用compile_commands.json
- [ ] 能列出并解释12大检查器类别的用途
- [ ] 能使用run-clang-tidy进行并行分析

---

### 第二周：.clang-tidy配置

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Week 2: .clang-tidy配置与项目定制                         │
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │  Day 8-9    │───▶│  Day 10-11  │───▶│  Day 12-13  │───▶│   Day 14    │  │
│  │ 配置文件    │    │ 命名规范    │    │ 预设方案    │    │ 源码阅读    │  │
│  │ 语法与继承  │    │ 与选项调优  │    │ 与检查器交互│    │ 综合实践    │  │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘  │
│                                                                             │
│  核心技能：                                                                  │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │ • .clang-tidy文件格式与字段含义                                       │ │
│  │ • 配置继承机制（目录层级搜索路径）                                     │ │
│  │ • readability-identifier-naming完整选项配置                            │ │
│  │ • 项目预设方案设计（strict/moderate/minimal）                          │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
│  输出物：三套预设配置 + 命名规范配置 + 笔记                学习时间：35小时 │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Week 2 每日任务分解

| 天数 | 时间 | 主题 | 具体任务 | 输出物 |
|------|------|------|----------|--------|
| Day 8 | 5h | 配置文件基础 | 1. .clang-tidy YAML格式详解 2. Checks字段通配符语法 3. WarningsAsErrors配置 4. HeaderFilterRegex过滤策略 | notes/config_basics.md |
| Day 9 | 5h | 配置继承机制 | 1. 目录层级搜索路径 2. 子目录覆盖父目录 3. --config-file命令行指定 4. InheritParentConfig选项 | notes/config_inheritance.md |
| Day 10 | 5h | 命名规范配置 | 1. readability-identifier-naming全部选项 2. CamelCase/lower_case/UPPER_CASE策略 3. 前后缀配置（m_/k/s_） 4. 匈牙利命名法兼容 | practice/naming_configs/ |
| Day 11 | 5h | 检查器选项调优 | 1. modernize-*关键选项 2. performance-*阈值调整 3. readability-function-size参数 4. bugprone-*严格模式 | practice/tuned_configs/ |
| Day 12 | 5h | 项目预设方案(上) | 1. 设计strict预设（新项目） 2. 设计moderate预设（现有项目） 3. 设计minimal预设（遗留代码） | configs/strict.clang-tidy等 |
| Day 13 | 5h | 检查器交互分析 | 1. cert/hicpp/cppcoreguidelines别名与重复 2. 冲突检查器识别 3. 依赖关系 4. 最优组合策略 | notes/checker_interactions.md |
| Day 14 | 5h | 源码阅读与总结 | 1. 阅读LLVM项目.clang-tidy 2. 阅读Chromium配置 3. 对比策略差异 4. Week 2总结 | notes/week2_config.md |

---

#### 配置继承与搜索路径

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                 .clang-tidy 配置文件搜索路径                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  项目目录结构                        搜索顺序（由近到远）                    │
│  ┌─────────────────────────────┐                                           │
│  │  project/                   │    clang-tidy分析 src/module/foo.cpp 时：  │
│  │  ├── .clang-tidy  ←────────│──── ③ 最后查找                             │
│  │  ├── src/                   │                                           │
│  │  │   ├── .clang-tidy ←─────│──── ② 其次查找                             │
│  │  │   └── module/            │                                           │
│  │  │       ├── .clang-tidy ←─│──── ① 首先查找（最高优先级）               │
│  │  │       └── foo.cpp        │                                           │
│  │  └── tests/                 │                                           │
│  │      ├── .clang-tidy  ←────│──── 测试目录独立配置（可放宽规则）         │
│  │      └── test_foo.cpp       │                                           │
│  └─────────────────────────────┘                                           │
│                                                                             │
│  策略示例：                                                                  │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  project/.clang-tidy    : 全局严格规则                               │  │
│  │  src/legacy/.clang-tidy : 放宽modernize-*（遗留代码兼容）            │  │
│  │  tests/.clang-tidy      : 禁用readability-function-size（测试较长）  │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 项目预设方案对比

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    三种预设方案对比                                           │
├─────────────┬─────────────────┬──────────────────┬─────────────────────────┤
│  检查器类别  │ Strict (新项目) │ Moderate (维护中) │ Minimal (遗留代码)     │
├─────────────┼─────────────────┼──────────────────┼─────────────────────────┤
│ bugprone-*  │ 全部启用        │ 全部启用          │ 高危项启用              │
│ modernize-* │ 全部启用        │ 选择性启用        │ 仅use-nullptr/override │
│ performance │ 全部启用        │ 全部启用          │ 全部启用                │
│ readability │ 全部+严格阈值   │ 全部+宽松阈值     │ 仅identifier-naming    │
│ cppcore.*   │ 全部启用        │ 选择性启用        │ 禁用                   │
│ WarningsAs  │ 关键项=Error    │ 无               │ 无                     │
│ Errors      │                 │                  │                        │
├─────────────┼─────────────────┼──────────────────┼─────────────────────────┤
│ 适用场景    │ 从零开始的项目  │ 活跃开发的项目    │ 仅做关键修复的旧项目    │
│ 预计警告数  │ 少（代码干净）  │ 中等             │ 少（规则少）            │
└─────────────┴─────────────────┴──────────────────┴─────────────────────────┘
```

**学习目标**：配置项目级别的检查规则

**阅读材料**：
- [ ] Clang-Tidy Configuration
- [ ] 各检查器的详细文档

```yaml
# ==========================================
# .clang-tidy - 完整配置示例
# ==========================================

# 检查器配置
Checks: >
  -*,
  bugprone-*,
  -bugprone-easily-swappable-parameters,
  cert-*,
  -cert-err58-cpp,
  clang-analyzer-*,
  cppcoreguidelines-*,
  -cppcoreguidelines-avoid-magic-numbers,
  -cppcoreguidelines-owning-memory,
  -cppcoreguidelines-pro-bounds-array-to-pointer-decay,
  google-*,
  -google-build-using-namespace,
  -google-readability-todo,
  hicpp-*,
  -hicpp-no-array-decay,
  misc-*,
  -misc-non-private-member-variables-in-classes,
  modernize-*,
  -modernize-use-trailing-return-type,
  performance-*,
  portability-*,
  readability-*,
  -readability-magic-numbers,
  -readability-identifier-length

# 警告当作错误
WarningsAsErrors: ''

# 头文件过滤（正则表达式）
HeaderFilterRegex: '.*'

# 分析系统头文件
AnalyzeTemporaryDtors: false
FormatStyle: file

# 检查器选项
CheckOptions:
  # readability
  - key: readability-identifier-naming.ClassCase
    value: CamelCase
  - key: readability-identifier-naming.ClassMemberCase
    value: lower_case
  - key: readability-identifier-naming.ClassMemberSuffix
    value: '_'
  - key: readability-identifier-naming.ConstantCase
    value: UPPER_CASE
  - key: readability-identifier-naming.EnumCase
    value: CamelCase
  - key: readability-identifier-naming.EnumConstantCase
    value: CamelCase
  - key: readability-identifier-naming.FunctionCase
    value: lower_case
  - key: readability-identifier-naming.GlobalConstantCase
    value: UPPER_CASE
  - key: readability-identifier-naming.GlobalConstantPrefix
    value: 'k'
  - key: readability-identifier-naming.LocalVariableCase
    value: lower_case
  - key: readability-identifier-naming.MemberCase
    value: lower_case
  - key: readability-identifier-naming.MethodCase
    value: lower_case
  - key: readability-identifier-naming.NamespaceCase
    value: lower_case
  - key: readability-identifier-naming.ParameterCase
    value: lower_case
  - key: readability-identifier-naming.PrivateMemberSuffix
    value: '_'
  - key: readability-identifier-naming.StructCase
    value: CamelCase
  - key: readability-identifier-naming.TypedefCase
    value: CamelCase
  - key: readability-identifier-naming.VariableCase
    value: lower_case

  # modernize
  - key: modernize-use-auto.MinTypeNameLength
    value: '5'
  - key: modernize-use-auto.RemoveStars
    value: 'false'
  - key: modernize-loop-convert.MinConfidence
    value: 'reasonable'
  - key: modernize-pass-by-value.IncludeStyle
    value: 'llvm'

  # performance
  - key: performance-move-const-arg.CheckTriviallyCopyableMove
    value: 'true'
  - key: performance-unnecessary-value-param.AllowedTypes
    value: 'std::function.*'

  # misc
  - key: misc-non-private-member-variables-in-classes.IgnoreClassesWithAllMemberVariablesBeingPublic
    value: 'true'

  # cppcoreguidelines
  - key: cppcoreguidelines-special-member-functions.AllowSoleDefaultDtor
    value: 'true'
  - key: cppcoreguidelines-special-member-functions.AllowMissingMoveFunctions
    value: 'true'

  # bugprone
  - key: bugprone-argument-comment.StrictMode
    value: 'true'
  - key: bugprone-assert-side-effect.AssertMacros
    value: 'assert,ASSERT'

  # readability-function-cognitive-complexity
  - key: readability-function-cognitive-complexity.Threshold
    value: '25'
  - key: readability-function-cognitive-complexity.DescribeBasicIncrements
    value: 'false'

  # readability-function-size
  - key: readability-function-size.LineThreshold
    value: '100'
  - key: readability-function-size.StatementThreshold
    value: '50'
  - key: readability-function-size.BranchThreshold
    value: '10'
  - key: readability-function-size.ParameterThreshold
    value: '6'

# 使用颜色输出
UseColor: true
```

#### Week 2 输出物清单

| 类别 | 文件/目录 | 说明 |
|------|-----------|------|
| 配置笔记 | `notes/config_basics.md` | .clang-tidy格式与字段详解 |
| 继承笔记 | `notes/config_inheritance.md` | 配置继承与覆盖机制 |
| 预设配置 | `configs/strict.clang-tidy` | 新项目严格预设 |
| 预设配置 | `configs/moderate.clang-tidy` | 维护项目中等预设 |
| 预设配置 | `configs/minimal.clang-tidy` | 遗留代码最小预设 |
| 交互分析 | `notes/checker_interactions.md` | 检查器重叠与冲突分析 |
| 学习笔记 | `notes/week2_config.md` | Week 2核心概念总结 |

#### Week 2 检验标准

- [ ] 能从零编写完整的.clang-tidy配置文件
- [ ] 理解配置文件的目录层级搜索和继承机制
- [ ] 能配置readability-identifier-naming的完整命名规范
- [ ] 能根据项目类型选择合适的预设方案
- [ ] 理解cert/hicpp/cppcoreguidelines之间的别名关系
- [ ] 能识别并解决检查器冲突问题

---

### 第三周：重要检查器详解

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Week 3: 重要检查器详解与实战                               │
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │  Day 15-16  │───▶│  Day 17-18  │───▶│  Day 19-20  │───▶│   Day 21    │  │
│  │ bugprone-*  │    │ modernize-* │    │ readability  │    │ 选择策略    │  │
│  │ 详解实战    │    │ performance │    │ cppcore      │    │ 综合对比    │  │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘  │
│                                                                             │
│  核心技能：                                                                  │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │ • bugprone-*:  use-after-move/dangling-handle/sizeof等高频检查器      │ │
│  │ • modernize-*: nullptr/override/auto/emplace等现代化迁移              │ │
│  │ • performance-*: for-range-copy/move-const-arg/unnecessary-copy       │ │
│  │ • readability-*: cognitive-complexity/function-size/naming             │ │
│  │ • cppcoreguidelines-*: ownership/bounds/type-safety                   │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
│  输出物：5大类检查器示例代码 + 选择策略文档 + 笔记        学习时间：35小时 │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Week 3 每日任务分解

| 天数 | 时间 | 主题 | 具体任务 | 输出物 |
|------|------|------|----------|--------|
| Day 15 | 5h | bugprone-*(上) | 1. use-after-move深入 2. dangling-handle/string-view 3. exception-escape分析 4. forwarding-reference-overload | practice/bugprone_examples_1.cpp |
| Day 16 | 5h | bugprone-*(下) | 1. sizeof-expression陷阱 2. narrowing-conversions 3. branch-clone检测 4. suspicious-semicolon | practice/bugprone_examples_2.cpp |
| Day 17 | 5h | modernize-* | 1. use-nullptr/use-override核心 2. use-auto/use-emplace迁移 3. loop-convert/make-unique 4. pass-by-value优化决策 | practice/modernize_examples.cpp |
| Day 18 | 5h | performance-* | 1. for-range-copy/unnecessary-copy 2. move-const-arg/noexcept-move 3. inefficient-string-concatenation 4. inefficient-vector-operation | practice/performance_examples.cpp |
| Day 19 | 5h | readability-* | 1. function-cognitive-complexity原理 2. function-size多维限制 3. identifier-naming实战 4. else-after-return/simplify-boolean | practice/readability_examples.cpp |
| Day 20 | 5h | cppcoreguidelines-* | 1. owning-memory/owner<T>概念 2. pro-bounds-*数组安全 3. pro-type-*类型安全 4. special-member-functions | practice/cppcore_examples.cpp |
| Day 21 | 5h | 选择策略与总结 | 1. 按项目类型选择检查器 2. 渐进启用策略 3. 检查器分类交互地图 4. Week 3总结 | notes/week3_checkers.md |

---

**学习目标**：深入理解常用检查器

**阅读材料**：
- [ ] Bugprone Checks
- [ ] Modernize Checks
- [ ] Performance Checks

```cpp
// ==========================================
// bugprone-* 示例
// ==========================================

// bugprone-argument-comment
void process(bool enable, bool verbose);
// 错误：参数顺序可能混淆
process(true, false);
// 建议：使用参数注释
process(/*enable=*/true, /*verbose=*/false);

// bugprone-branch-clone
if (condition) {
    doA();
} else {
    doA();  // 警告：分支内容相同
}

// bugprone-copy-constructor-init
class Derived : public Base {
    Derived(const Derived& other)
        // 警告：应该调用基类拷贝构造
        : Base() {}
};

// bugprone-dangling-handle
std::string_view sv = std::string("temp");  // 警告：悬垂引用

// bugprone-exception-escape
void func() noexcept {
    throw std::runtime_error("oops");  // 警告：异常逃逸
}

// bugprone-forwarding-reference-overload
class Widget {
public:
    template<typename T>
    Widget(T&& param) {}  // 警告：可能遮蔽拷贝构造

    Widget(const Widget&) = default;
};

// bugprone-infinite-loop
while (true) {  // 警告：可能的无限循环
    if (condition) break;
}

// bugprone-integer-division
double result = 5 / 3;  // 警告：整数除法

// bugprone-move-forwarding-reference
template<typename T>
void func(T&& param) {
    auto x = std::move(param);  // 警告：应使用std::forward
}

// bugprone-narrowing-conversions
void func(long value) {
    int x = value;  // 警告：窄化转换
}

// bugprone-sizeof-expression
int arr[10];
int count = sizeof(arr);  // 警告：可能想用sizeof(arr)/sizeof(arr[0])

// bugprone-string-constructor
std::string s('x', 10);   // 警告：参数顺序错误
std::string s(10, 'x');   // 正确

// bugprone-suspicious-semicolon
if (condition);  // 警告：可疑的分号
{
    doSomething();
}

// bugprone-too-small-loop-variable
std::vector<int> v(100000);
for (short i = 0; i < v.size(); ++i) {}  // 警告：循环变量太小

// bugprone-use-after-move
auto widget = std::make_unique<Widget>();
auto other = std::move(widget);
widget->doSomething();  // 警告：移动后使用
```

```cpp
// ==========================================
// modernize-* 示例
// ==========================================

// modernize-avoid-bind
auto f = std::bind(&Foo::bar, this, _1, _2);
// 建议：
auto f = [this](auto a, auto b) { return bar(a, b); };

// modernize-avoid-c-arrays
int arr[10];  // 警告
// 建议：
std::array<int, 10> arr;

// modernize-concat-nested-namespaces（C++17）
namespace A { namespace B { namespace C {
}}}
// 建议：
namespace A::B::C {
}

// modernize-deprecated-headers
#include <stdio.h>   // 警告
#include <cstdio>    // 建议

// modernize-loop-convert
for (std::vector<int>::iterator it = v.begin(); it != v.end(); ++it) {
    *it *= 2;
}
// 建议：
for (auto& elem : v) {
    elem *= 2;
}

// modernize-make-shared
std::shared_ptr<Foo> p(new Foo());
// 建议：
auto p = std::make_shared<Foo>();

// modernize-make-unique
std::unique_ptr<Foo> p(new Foo());
// 建议：
auto p = std::make_unique<Foo>();

// modernize-pass-by-value
void setName(const std::string& name) {
    name_ = name;
}
// 建议（当需要复制时）：
void setName(std::string name) {
    name_ = std::move(name);
}

// modernize-raw-string-literal
std::string path = "C:\\Users\\name";
// 建议：
std::string path = R"(C:\Users\name)";

// modernize-redundant-void-arg
void func(void);
// 建议：
void func();

// modernize-replace-auto-ptr
std::auto_ptr<Foo> p;  // 警告：已废弃
// 建议：
std::unique_ptr<Foo> p;

// modernize-return-braced-init-list
Foo createFoo() {
    return Foo(1, 2, 3);
}
// 建议：
Foo createFoo() {
    return {1, 2, 3};
}

// modernize-shrink-to-fit
v.erase(v.begin(), v.end());
std::vector<int>(v).swap(v);
// 建议：
v.clear();
v.shrink_to_fit();

// modernize-use-auto
std::map<std::string, std::vector<int>>::iterator it = m.begin();
// 建议：
auto it = m.begin();

// modernize-use-bool-literals
int x = (condition) ? 1 : 0;  // 当类型是bool时警告
// 建议：
bool x = condition;

// modernize-use-default-member-init
class Foo {
    int x;
    Foo() : x(0) {}
};
// 建议：
class Foo {
    int x = 0;
    Foo() = default;
};

// modernize-use-emplace
v.push_back(Foo(1, 2));
// 建议：
v.emplace_back(1, 2);

// modernize-use-equals-default
Foo() {}
~Foo() {}
// 建议：
Foo() = default;
~Foo() = default;

// modernize-use-equals-delete
private:
    Foo(const Foo&);  // 阻止拷贝
// 建议：
public:
    Foo(const Foo&) = delete;

// modernize-use-nodiscard（C++17）
bool isEmpty() const { return size_ == 0; }
// 建议：
[[nodiscard]] bool isEmpty() const { return size_ == 0; }

// modernize-use-noexcept
void func() throw() {}
// 建议：
void func() noexcept {}

// modernize-use-nullptr
int* p = 0;
int* q = NULL;
// 建议：
int* p = nullptr;

// modernize-use-override
class Derived : public Base {
    void func() {}  // 重写但没有override
};
// 建议：
class Derived : public Base {
    void func() override {}
};

// modernize-use-transparent-functors
std::set<std::string, std::less<std::string>> s;
// 建议（C++14）：
std::set<std::string, std::less<>> s;

// modernize-use-using
typedef int MyInt;
// 建议：
using MyInt = int;
```

```cpp
// ==========================================
// performance-* 示例
// ==========================================

// performance-faster-string-find
str.find("a") != std::string::npos;  // 单字符用char更快
// 建议：
str.find('a') != std::string::npos;

// performance-for-range-copy
for (const auto item : container) {  // 复制每个元素
    use(item);
}
// 建议：
for (const auto& item : container) {
    use(item);
}

// performance-implicit-conversion-in-loop
for (auto elem : map) {  // pair被隐式转换
}
// 建议：
for (const auto& [key, value] : map) {
}

// performance-inefficient-algorithm
auto it = std::find(s.begin(), s.end(), value);
// 建议（对于关联容器）：
auto it = s.find(value);

// performance-inefficient-string-concatenation
std::string result = a + b + c + d;  // 多次分配
// 建议：
std::string result;
result.reserve(a.size() + b.size() + c.size() + d.size());
result += a;
result += b;
result += c;
result += d;

// performance-inefficient-vector-operation
std::vector<int> v;
for (int i = 0; i < n; ++i) {
    v.push_back(i);  // 多次重新分配
}
// 建议：
std::vector<int> v;
v.reserve(n);
for (int i = 0; i < n; ++i) {
    v.push_back(i);
}

// performance-move-const-arg
const std::string s = "hello";
func(std::move(s));  // move对const无效
// 警告：std::move对const参数无效

// performance-move-constructor-init
class Foo {
    std::string str_;
    Foo(Foo&& other) : str_(other.str_) {}  // 应该move
};
// 建议：
Foo(Foo&& other) : str_(std::move(other.str_)) {}

// performance-no-automatic-move
std::string func() {
    std::string s = "hello";
    return std::move(s);  // 阻止NRVO优化
}
// 建议：
std::string func() {
    std::string s = "hello";
    return s;  // 编译器会自动move
}

// performance-noexcept-move-constructor
class Foo {
    Foo(Foo&&) {}  // 缺少noexcept
};
// 建议：
class Foo {
    Foo(Foo&&) noexcept {}
};

// performance-trivially-destructible
class Simple {
    int x;
    ~Simple() {}  // 空析构函数阻止平凡析构
};
// 建议：
class Simple {
    int x;
    ~Simple() = default;
};

// performance-type-promotion-in-math-fn
float x = 1.5f;
double y = std::sin(x);  // float提升为double
// 建议：
float y = std::sin(x);  // 使用结果类型匹配

// performance-unnecessary-copy-initialization
auto copy = container.at(index);  // 不必要的拷贝
// 建议：
const auto& ref = container.at(index);

// performance-unnecessary-value-param
void func(std::string s) {  // 大对象按值传递
    // 只读取s，不修改
}
// 建议：
void func(const std::string& s) {
}
```

```cpp
// ==========================================
// readability-* 示例
// ==========================================

// readability-function-cognitive-complexity
// 认知复杂度：每层嵌套+1，每个分支+1
void processData(const std::vector<Data>& items) {  // 可能超过阈值
    for (const auto& item : items) {        // +1
        if (item.isValid()) {               // +2 (嵌套)
            switch (item.type()) {          // +3 (嵌套)
                case Type::A:
                    if (item.hasFlag()) {   // +4 (嵌套)
                        // 过深嵌套，建议提取子函数
                    }
                    break;
            }
        }
    }
}

// readability-function-size
// 配置项: LineThreshold=100, StatementThreshold=50,
//         BranchThreshold=10, ParameterThreshold=6
void tooLargeFunction(int a, int b, int c, int d, int e, int f, int g) {
    // 警告：参数超过6个阈值
    // 建议：使用参数对象或Builder模式
}

// readability-implicit-bool-conversion
void func(int* ptr) {
    if (ptr) {}        // 警告：隐式转换为bool
    if (ptr != nullptr) {}  // 建议：显式比较
}

// readability-else-after-return
int classify(int x) {
    if (x > 0) {
        return 1;
    } else {           // 警告：return后不需要else
        return -1;
    }
}
// 建议：
int classify_fixed(int x) {
    if (x > 0) {
        return 1;
    }
    return -1;
}

// readability-redundant-string-cstr
void func(const std::string& s) {
    std::string copy(s.c_str());  // 警告：不必要的c_str()
    std::string copy2(s);         // 建议
}

// readability-simplify-boolean-expr
bool isReady(bool a, bool b) {
    if (a && b) {
        return true;    // 警告：可以简化
    } else {
        return false;
    }
}
// 建议：
bool isReady_fixed(bool a, bool b) {
    return a && b;
}
```

```cpp
// ==========================================
// cppcoreguidelines-* 示例
// ==========================================

// cppcoreguidelines-owning-memory
void func_raw() {
    int* p = new int(42);  // 警告：裸指针拥有资源
    delete p;
}
// 建议：使用智能指针
void func_smart() {
    auto p = std::make_unique<int>(42);
}

// cppcoreguidelines-pro-bounds-array-to-pointer-decay
void func_array(int arr[]) {
    // 警告：数组退化为指针，丢失大小信息
}
// 建议：使用std::span（C++20）
// void func_span(std::span<int> arr) {}

// cppcoreguidelines-pro-bounds-pointer-arithmetic
void func_ptr(int* p, int n) {
    int x = *(p + 3);  // 警告：指针算术不安全
    int y = p[3];       // 同样警告
}
// 建议：使用容器或span

// cppcoreguidelines-pro-type-reinterpret-cast
void func_cast(int* p) {
    auto fp = reinterpret_cast<float*>(p);  // 警告：危险的类型转换
}

// cppcoreguidelines-pro-type-static-cast-downcast
class Base { virtual ~Base() = default; };
class Derived : public Base {};
void func_downcast(Base* b) {
    auto d = static_cast<Derived*>(b);      // 警告：使用dynamic_cast更安全
    auto d2 = dynamic_cast<Derived*>(b);    // 建议
}

// cppcoreguidelines-special-member-functions (Rule of Five)
class Resource {
    int* data_;
public:
    ~Resource() { delete data_; }
    // 警告：定义了析构函数但没有定义拷贝/移动操作
    // 建议：遵循Rule of Five
    Resource(const Resource&) = delete;
    Resource& operator=(const Resource&) = delete;
    Resource(Resource&&) noexcept = default;
    Resource& operator=(Resource&&) noexcept = default;
};

// cppcoreguidelines-init-variables
void func_init() {
    int x;       // 警告：变量未初始化
    int y = 0;   // 建议：始终初始化
}

// cppcoreguidelines-avoid-goto
void func_goto() {
    goto label;  // 警告：避免使用goto
label:
    return;
}
```

#### 检查器选择策略

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    检查器选择策略（按项目类型）                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  新项目（从零开始）                                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  必选：bugprone-* + modernize-* + performance-* + readability-*    │   │
│  │  推荐：cppcoreguidelines-* + cert-*                                │   │
│  │  可选：google-* 或 llvm-*（根据团队规范）                           │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  现有项目（渐进引入）                                                       │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Phase 1: bugprone-*（高价值，低噪音）                              │   │
│  │  Phase 2: + performance-*（明确的性能提升）                         │   │
│  │  Phase 3: + modernize-*（逐步现代化）                               │   │
│  │  Phase 4: + readability-*（代码风格统一）                           │   │
│  │  Phase 5: + cppcoreguidelines-*（全面合规）                         │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  安全关键项目                                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  必选：cert-* + bugprone-* + cppcoreguidelines-*                   │   │
│  │  必选：WarningsAsErrors: bugprone-use-after-move,                  │   │
│  │        bugprone-dangling-handle, cert-err58-cpp                    │   │
│  │  推荐：clang-analyzer-*（深度路径分析）                             │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Week 3 输出物清单

| 类别 | 文件/目录 | 说明 |
|------|-----------|------|
| 示例代码 | `practice/bugprone_examples_1.cpp` | bugprone-*高频检查器示例 |
| 示例代码 | `practice/bugprone_examples_2.cpp` | bugprone-*补充检查器示例 |
| 示例代码 | `practice/modernize_examples.cpp` | modernize-*现代化迁移示例 |
| 示例代码 | `practice/performance_examples.cpp` | performance-*性能检查器示例 |
| 示例代码 | `practice/readability_examples.cpp` | readability-*可读性检查器示例 |
| 示例代码 | `practice/cppcore_examples.cpp` | cppcoreguidelines-*示例 |
| 学习笔记 | `notes/week3_checkers.md` | 检查器详解与选择策略总结 |

#### Week 3 检验标准

- [ ] 能列举bugprone-*中最高价值的5个检查器及其检测场景
- [ ] 能解释modernize-use-auto/use-override/use-nullptr的工作原理
- [ ] 能识别performance-for-range-copy等常见性能问题
- [ ] 理解readability-function-cognitive-complexity的计算方式
- [ ] 能解释cppcoreguidelines中ownership和bounds safety概念
- [ ] 能根据项目类型制定渐进式检查器引入计划

---

### 第四周：CMake集成与自定义检查

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Week 4: CMake集成、CI/CD与自定义检查                       │
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │  Day 22-23  │───▶│  Day 24-25  │───▶│  Day 26-27  │───▶│   Day 28    │  │
│  │ CMake集成   │    │ CI/CD集成   │    │ 自定义检查  │    │ 综合项目    │  │
│  │ NOLINT抑制  │    │ GitHub/预提 │    │ AST Matcher │    │ 月度总结    │  │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘  │
│                                                                             │
│  核心技能：                                                                  │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │ • CMAKE_CXX_CLANG_TIDY属性与可复用CMake模块                          │ │
│  │ • GitHub Actions CI集成 + clang-tidy-diff PR检查                      │ │
│  │ • Pre-commit hook + 警告抑制最佳实践                                  │ │
│  │ • 自定义检查器开发入门（AST Matchers API）                            │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
│  输出物：CMake模块 + CI配置 + 自定义检查器 + 完整项目       学习时间：35小时│
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Week 4 每日任务分解

| 天数 | 时间 | 主题 | 具体任务 | 输出物 |
|------|------|------|----------|--------|
| Day 22 | 5h | CMake集成基础 | 1. CMAKE_CXX_CLANG_TIDY属性 2. 全局 vs 目标级配置 3. 自定义target 4. 排除第三方代码 | cmake/ClangTidy.cmake |
| Day 23 | 5h | 警告抑制策略 | 1. NOLINT/NOLINTNEXTLINE/NOLINTBEGIN 2. 按检查器精确抑制 3. 最佳实践 4. 可复用模块完善 | practice/suppression_demo/ |
| Day 24 | 5h | GitHub Actions CI | 1. CI工作流YAML编写 2. SARIF报告上传 3. PR注释集成 4. 缓存compile_commands.json | .github/workflows/clang-tidy.yml |
| Day 25 | 5h | PR增量检查 | 1. clang-tidy-diff.py原理 2. 仅检查PR变更文件 3. Pre-commit hook编写 4. 本地与CI一致性 | scripts/clang-tidy-diff.sh |
| Day 26 | 5h | 自定义检查器(上) | 1. AST Matchers API概述 2. clang-query交互式探索 3. 简单匹配器编写 4. MatchFinder回调 | notes/ast_matchers_intro.md |
| Day 27 | 5h | 自定义检查器(下) | 1. 编写完整自定义检查器 2. 注册到模块 3. FixIt自动修复 4. 测试检查器 | practice/custom_check/ |
| Day 28 | 5h | 综合实战与总结 | 1. 整合code-quality项目 2. 端到端流程验证 3. 月度知识回顾 4. Month 44预习 | notes/week4_integration.md |

---

**学习目标**：将Clang-Tidy集成到构建系统

**阅读材料**：
- [ ] CMake: CMAKE_CXX_CLANG_TIDY
- [ ] Writing Clang-Tidy Checks

```cmake
# ==========================================
# CMakeLists.txt - Clang-Tidy集成
# ==========================================
cmake_minimum_required(VERSION 3.16)
project(MyProject)

# 选项
option(ENABLE_CLANG_TIDY "Enable clang-tidy analysis" ON)
option(CLANG_TIDY_FIX "Apply clang-tidy fixes" OFF)

# 查找clang-tidy
if(ENABLE_CLANG_TIDY)
    find_program(CLANG_TIDY_EXE
        NAMES clang-tidy clang-tidy-15 clang-tidy-14
        DOC "Path to clang-tidy executable"
    )

    if(CLANG_TIDY_EXE)
        message(STATUS "Found clang-tidy: ${CLANG_TIDY_EXE}")

        # 基本配置
        set(CLANG_TIDY_COMMAND "${CLANG_TIDY_EXE}")

        # 添加修复选项
        if(CLANG_TIDY_FIX)
            list(APPEND CLANG_TIDY_COMMAND "-fix")
        endif()

        # 设置全局属性（影响所有目标）
        set(CMAKE_CXX_CLANG_TIDY ${CLANG_TIDY_COMMAND})

        # 或者只对特定目标启用
        # set_target_properties(mytarget PROPERTIES
        #     CXX_CLANG_TIDY "${CLANG_TIDY_COMMAND}"
        # )
    else()
        message(WARNING "clang-tidy not found, static analysis disabled")
    endif()
endif()

# 添加库/可执行文件
add_library(mylib src/mylib.cpp)

# 为特定目标配置不同的检查
set_target_properties(mylib PROPERTIES
    CXX_CLANG_TIDY "${CLANG_TIDY_EXE};-checks=-*,modernize-*,performance-*"
)

# 排除某些目标
add_executable(tests tests/main.cpp)
set_target_properties(tests PROPERTIES
    CXX_CLANG_TIDY ""  # 禁用
)

# ==========================================
# 自定义目标：手动运行clang-tidy
# ==========================================
if(CLANG_TIDY_EXE)
    add_custom_target(clang-tidy
        COMMAND ${CLANG_TIDY_EXE}
            -p ${CMAKE_BINARY_DIR}
            ${CMAKE_SOURCE_DIR}/src/*.cpp
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Running clang-tidy..."
    )

    add_custom_target(clang-tidy-fix
        COMMAND ${CLANG_TIDY_EXE}
            -p ${CMAKE_BINARY_DIR}
            -fix
            ${CMAKE_SOURCE_DIR}/src/*.cpp
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Running clang-tidy with fixes..."
    )
endif()
```

```cmake
# ==========================================
# cmake/ClangTidy.cmake - 可复用模块
# ==========================================
function(enable_clang_tidy target)
    find_program(CLANG_TIDY_EXE NAMES clang-tidy)

    if(NOT CLANG_TIDY_EXE)
        message(WARNING "clang-tidy not found")
        return()
    endif()

    # 解析参数
    set(options FIX)
    set(oneValueArgs CONFIG)
    set(multiValueArgs CHECKS EXTRA_ARGS)
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # 构建命令
    set(CLANG_TIDY_CMD "${CLANG_TIDY_EXE}")

    if(ARG_CHECKS)
        string(REPLACE ";" "," CHECKS_STR "${ARG_CHECKS}")
        list(APPEND CLANG_TIDY_CMD "-checks=${CHECKS_STR}")
    endif()

    if(ARG_CONFIG)
        list(APPEND CLANG_TIDY_CMD "--config-file=${ARG_CONFIG}")
    endif()

    if(ARG_FIX)
        list(APPEND CLANG_TIDY_CMD "-fix")
    endif()

    if(ARG_EXTRA_ARGS)
        list(APPEND CLANG_TIDY_CMD ${ARG_EXTRA_ARGS})
    endif()

    set_target_properties(${target} PROPERTIES
        CXX_CLANG_TIDY "${CLANG_TIDY_CMD}"
    )
endfunction()

# 使用示例
# enable_clang_tidy(mylib
#     CHECKS modernize-* performance-*
#     CONFIG ${CMAKE_SOURCE_DIR}/.clang-tidy
# )
```

**自定义抑制警告**：

```cpp
// ==========================================
// 抑制警告的方法
// ==========================================

// 方法1：NOLINT注释
void func() {
    int x = 0;  // NOLINT
    int y = 0;  // NOLINT(clang-analyzer-deadcode.DeadStores)
    int z = 0;  // NOLINT(modernize-*, performance-*)
}

// 方法2：NOLINTNEXTLINE
// NOLINTNEXTLINE(bugprone-branch-clone)
if (condition) {
    doA();
} else {
    doA();
}

// 方法3：区域禁用
// NOLINTBEGIN(modernize-use-nullptr)
int* p = 0;
int* q = NULL;
// NOLINTEND(modernize-use-nullptr)

// 方法4：文件级别禁用
// 在文件开头添加
// NOLINTBEGIN(*)
// ... entire file ...
// NOLINTEND(*)

// 方法5：使用宏封装
#define SUPPRESS_WARNING(check) // NOLINT(check)
```

#### GitHub Actions CI集成

将Clang-Tidy集成到CI/CD流水线，实现每次提交和PR的自动代码质量检查：

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Clang-Tidy CI/CD 集成架构                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  开发者                                                                     │
│    │                                                                        │
│    ├──push──▶ ┌─────────────────────────────────────────────────────┐       │
│    │          │              GitHub Actions Workflow                 │       │
│    │          │                                                     │       │
│    │          │  ┌─────────┐  ┌──────────┐  ┌─────────────────┐   │       │
│    │          │  │ Checkout │─▶│ 构建编译 │─▶│ run-clang-tidy  │   │       │
│    │          │  │ + Cache  │  │ 数据库   │  │ 全量 / 增量     │   │       │
│    │          │  └─────────┘  └──────────┘  └────────┬────────┘   │       │
│    │          │                                       │            │       │
│    │          │  ┌──────────────────────────────────┐ │            │       │
│    │          │  │ Upload SARIF │ PR Comment │ Badge │◀┘            │       │
│    │          │  └──────────────────────────────────┘              │       │
│    │          └─────────────────────────────────────────────────────┘       │
│    │                                                                        │
│    └──PR──▶ ┌───────────────────────────────────────────────────────┐      │
│              │  clang-tidy-diff: 仅检查变更文件（增量模式）          │      │
│              │  结果作为PR Review Comment显示                        │      │
│              └───────────────────────────────────────────────────────┘      │
│                                                                             │
│  本地开发                                                                   │
│    │                                                                        │
│    └──commit──▶ ┌──────────────────────────────────────┐                   │
│                  │  Pre-commit Hook: 检查暂存文件        │                   │
│                  │  通过 → 允许提交  失败 → 阻止提交     │                   │
│                  └──────────────────────────────────────┘                   │
└─────────────────────────────────────────────────────────────────────────────┘
```

**.github/workflows/clang-tidy.yml**（完整CI工作流）：

```yaml
# Clang-Tidy 静态分析 CI 工作流
name: Clang-Tidy Analysis

on:
  push:
    branches: [main, develop]
    paths:
      - '**.cpp'
      - '**.hpp'
      - '**.h'
      - '.clang-tidy'
      - '.github/workflows/clang-tidy.yml'
  pull_request:
    branches: [main]
    paths:
      - '**.cpp'
      - '**.hpp'
      - '**.h'
      - '.clang-tidy'

# 同一分支的多次推送，取消之前的运行
concurrency:
  group: clang-tidy-${{ github.ref }}
  cancel-in-progress: true

jobs:
  # ──────────────────────────────────────────────────────────
  # Job 1: 全量分析（push到主分支时触发）
  # ──────────────────────────────────────────────────────────
  full-analysis:
    if: github.event_name == 'push'
    runs-on: ubuntu-24.04

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install Dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y clang-tidy-18 cmake ninja-build
          sudo update-alternatives --install /usr/bin/clang-tidy \
            clang-tidy /usr/bin/clang-tidy-18 100

      # 缓存vcpkg/conan依赖（如果使用）
      - name: Cache Dependencies
        uses: actions/cache@v4
        with:
          path: |
            build/_deps
            ~/.cache/vcpkg
          key: deps-${{ runner.os }}-${{ hashFiles('vcpkg.json', 'CMakeLists.txt') }}
          restore-keys: deps-${{ runner.os }}-

      # 生成compile_commands.json
      - name: Configure CMake
        run: |
          cmake -B build -G Ninja \
            -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
            -DCMAKE_CXX_COMPILER=clang++-18

      # 缓存compile_commands.json（加速后续构建）
      - name: Cache Compile Commands
        uses: actions/cache@v4
        with:
          path: build/compile_commands.json
          key: compile-cmds-${{ hashFiles('CMakeLists.txt', '**/CMakeLists.txt') }}

      # 运行clang-tidy全量分析
      - name: Run Clang-Tidy
        run: |
          run-clang-tidy-18 \
            -p build \
            -j $(nproc) \
            -header-filter='include/.*' \
            -export-fixes=clang-tidy-fixes.yaml \
            2>&1 | tee clang-tidy-output.txt

      # 生成SARIF格式报告（用于GitHub Code Scanning）
      - name: Generate SARIF Report
        if: always()
        run: |
          pip install clang-tidy-sarif
          clang-tidy-sarif \
            --input clang-tidy-output.txt \
            --output clang-tidy-results.sarif

      # 上传SARIF到GitHub Security Tab
      - name: Upload SARIF
        if: always()
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: clang-tidy-results.sarif
          category: clang-tidy

      # 上传修复建议作为Artifact
      - name: Upload Fixes
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: clang-tidy-fixes
          path: clang-tidy-fixes.yaml
          retention-days: 7

      # 分析结果摘要
      - name: Analysis Summary
        if: always()
        run: |
          echo "## Clang-Tidy Analysis Results" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY

          WARNINGS=$(grep -c "warning:" clang-tidy-output.txt || true)
          ERRORS=$(grep -c "error:" clang-tidy-output.txt || true)

          echo "| Metric | Count |" >> $GITHUB_STEP_SUMMARY
          echo "|--------|-------|" >> $GITHUB_STEP_SUMMARY
          echo "| Warnings | $WARNINGS |" >> $GITHUB_STEP_SUMMARY
          echo "| Errors | $ERRORS |" >> $GITHUB_STEP_SUMMARY

          if [ "$ERRORS" -gt 0 ]; then
            echo "" >> $GITHUB_STEP_SUMMARY
            echo ":x: **Analysis found errors!**" >> $GITHUB_STEP_SUMMARY
            exit 1
          fi

  # ──────────────────────────────────────────────────────────
  # Job 2: PR增量分析（仅检查变更文件）
  # ──────────────────────────────────────────────────────────
  pr-analysis:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-24.04
    permissions:
      pull-requests: write     # 允许写入PR评论
      contents: read

    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0        # 需要完整历史来计算diff

      - name: Install Dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y clang-tidy-18 cmake ninja-build python3-pip
          pip install clang-tidy-diff

      - name: Configure CMake
        run: |
          cmake -B build -G Ninja \
            -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
            -DCMAKE_CXX_COMPILER=clang++-18

      # 获取PR变更文件的diff
      - name: Get Changed Files
        id: diff
        run: |
          git diff -U0 origin/${{ github.base_ref }}...HEAD \
            -- '*.cpp' '*.hpp' '*.h' > changes.diff

          CHANGED=$(wc -l < changes.diff)
          echo "changed_lines=$CHANGED" >> $GITHUB_OUTPUT
          echo "Found $CHANGED lines of diff"

      # 仅对变更行运行clang-tidy（增量检查）
      - name: Run Clang-Tidy Diff
        if: steps.diff.outputs.changed_lines > 0
        run: |
          # clang-tidy-diff.py 只检查diff中变更的行
          clang-tidy-diff-18.py \
            -p1 \
            -path build \
            -j $(nproc) \
            -clang-tidy-binary clang-tidy-18 \
            < changes.diff \
            2>&1 | tee pr-analysis.txt

      # 将结果作为PR评论
      - name: Post PR Comment
        if: always() && steps.diff.outputs.changed_lines > 0
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const output = fs.readFileSync('pr-analysis.txt', 'utf8');

            const warnings = (output.match(/warning:/g) || []).length;
            const errors = (output.match(/error:/g) || []).length;

            let body = '## 🔍 Clang-Tidy Analysis\n\n';
            body += `| Metric | Count |\n`;
            body += `|--------|-------|\n`;
            body += `| Warnings | ${warnings} |\n`;
            body += `| Errors | ${errors} |\n\n`;

            if (warnings === 0 && errors === 0) {
              body += '✅ No issues found in changed code!\n';
            } else {
              body += '<details>\n<summary>Details</summary>\n\n```\n';
              body += output.slice(0, 60000);  // GitHub评论大小限制
              body += '\n```\n</details>\n';
            }

            // 查找并更新已有评论，避免重复
            const { data: comments } = await github.rest.issues.listComments({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
            });

            const botComment = comments.find(
              c => c.body.includes('Clang-Tidy Analysis')
            );

            if (botComment) {
              await github.rest.issues.updateComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                comment_id: botComment.id,
                body: body,
              });
            } else {
              await github.rest.issues.createComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: context.issue.number,
                body: body,
              });
            }
```

#### clang-tidy-diff：PR增量检查详解

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    clang-tidy-diff 增量检查原理                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  git diff main...feature                                                    │
│    │                                                                        │
│    ▼                                                                        │
│  ┌──────────────────────────────────┐                                      │
│  │ --- a/src/parser.cpp             │   提取变更文件和行号范围              │
│  │ +++ b/src/parser.cpp             │──▶ parser.cpp: lines 42-58, 120-135  │
│  │ @@ -42,5 +42,12 @@              │   config.cpp: lines 10-25            │
│  │ +    auto val = getValue();      │                                      │
│  │ @@ -120,3 +127,10 @@            │                                      │
│  └──────────────────────────────────┘                                      │
│                    │                                                        │
│                    ▼                                                        │
│  ┌──────────────────────────────────┐                                      │
│  │  clang-tidy                      │                                      │
│  │  -line-filter='[                 │   仅分析变更行                        │
│  │    {"name":"parser.cpp",         │   （忽略未修改代码的警告）             │
│  │     "lines":[[42,58],[120,135]]},│                                      │
│  │    {"name":"config.cpp",         │                                      │
│  │     "lines":[[10,25]]}           │                                      │
│  │  ]'                              │                                      │
│  └──────────────────────────────────┘                                      │
│                    │                                                        │
│                    ▼                                                        │
│  优势：                                                                     │
│  • 速度快：只分析变更部分，适合大型项目                                      │
│  • 噪声低：不报告历史遗留问题                                               │
│  • 渐进改善：新代码必须满足质量标准                                          │
└─────────────────────────────────────────────────────────────────────────────┘
```

**手动使用clang-tidy-diff**：

```bash
#!/bin/bash
# scripts/clang-tidy-diff.sh - PR增量检查脚本

set -euo pipefail

# 配置
BUILD_DIR="${BUILD_DIR:-build}"
BASE_BRANCH="${BASE_BRANCH:-main}"
CLANG_TIDY="${CLANG_TIDY:-clang-tidy}"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Clang-Tidy Incremental Analysis ===${NC}"
echo -e "Base branch: ${BASE_BRANCH}"
echo -e "Build dir:   ${BUILD_DIR}"

# 确保编译数据库存在
if [ ! -f "${BUILD_DIR}/compile_commands.json" ]; then
    echo -e "${YELLOW}Generating compile_commands.json...${NC}"
    cmake -B "${BUILD_DIR}" -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
fi

# 获取与目标分支的diff
echo -e "\n${BLUE}Fetching diff against ${BASE_BRANCH}...${NC}"
git diff -U0 "origin/${BASE_BRANCH}"...HEAD \
    -- '*.cpp' '*.hpp' '*.h' '*.cc' '*.hh' > /tmp/changes.diff

# 检查是否有变更
if [ ! -s /tmp/changes.diff ]; then
    echo -e "${GREEN}No C++ files changed. Nothing to check.${NC}"
    exit 0
fi

# 提取变更的文件列表
CHANGED_FILES=$(grep '^+++ b/' /tmp/changes.diff | sed 's|^+++ b/||' | sort -u)
echo -e "\n${BLUE}Changed files:${NC}"
for f in $CHANGED_FILES; do
    echo "  - $f"
done

# 使用clang-tidy-diff.py进行增量检查
echo -e "\n${BLUE}Running clang-tidy on changed lines...${NC}"
RESULT=0
clang-tidy-diff.py \
    -p1 \
    -path "${BUILD_DIR}" \
    -j "$(nproc 2>/dev/null || sysctl -n hw.ncpu)" \
    -clang-tidy-binary "${CLANG_TIDY}" \
    < /tmp/changes.diff 2>&1 | tee /tmp/clang-tidy-diff-output.txt || RESULT=$?

# 统计结果
WARNINGS=$(grep -c "warning:" /tmp/clang-tidy-diff-output.txt 2>/dev/null || echo 0)
ERRORS=$(grep -c "error:" /tmp/clang-tidy-diff-output.txt 2>/dev/null || echo 0)

echo -e "\n${BLUE}=== Results ===${NC}"
echo -e "Warnings: ${YELLOW}${WARNINGS}${NC}"
echo -e "Errors:   ${RED}${ERRORS}${NC}"

if [ "$ERRORS" -gt 0 ]; then
    echo -e "\n${RED}❌ Clang-Tidy found errors in changed code!${NC}"
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    echo -e "\n${YELLOW}⚠ Clang-Tidy found warnings in changed code.${NC}"
    exit 0  # 警告不阻止合并，可改为exit 1使其更严格
else
    echo -e "\n${GREEN}✅ No issues found in changed code!${NC}"
    exit 0
fi
```

#### Pre-commit Hook

使用Git hook在提交前自动检查暂存的C++文件：

```bash
#!/bin/bash
# .git/hooks/pre-commit (或使用pre-commit框架)
# 在git commit之前自动运行clang-tidy

set -euo pipefail

BUILD_DIR="build"
CLANG_TIDY="${CLANG_TIDY:-clang-tidy}"

# 获取暂存的C++文件
STAGED_FILES=$(git diff --cached --name-only --diff-filter=d \
    | grep -E '\.(cpp|cc|cxx|hpp|h|hh)$' || true)

if [ -z "$STAGED_FILES" ]; then
    exit 0  # 没有C++文件变更，跳过检查
fi

echo "🔍 Running clang-tidy on staged files..."

# 确保编译数据库存在
if [ ! -f "${BUILD_DIR}/compile_commands.json" ]; then
    echo "⚠ No compile_commands.json found. Skipping clang-tidy."
    echo "  Run: cmake -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON"
    exit 0
fi

# 逐文件检查
FAILED=0
for file in $STAGED_FILES; do
    if [ -f "$file" ]; then
        echo "  Checking: $file"
        if ! $CLANG_TIDY -p "${BUILD_DIR}" \
            --warnings-as-errors='bugprone-*,modernize-use-nullptr' \
            "$file" 2>&1 | grep -v "^$"; then
            FAILED=1
        fi
    fi
done

if [ "$FAILED" -eq 1 ]; then
    echo ""
    echo "❌ clang-tidy found issues. Please fix before committing."
    echo "   Use 'git commit --no-verify' to skip this check."
    exit 1
fi

echo "✅ clang-tidy passed!"
exit 0
```

**使用pre-commit框架**（推荐，更易管理）：

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/pocc/pre-commit-hooks
    rev: v1.3.5
    hooks:
      - id: clang-tidy
        args:
          - -p=build
          - --warnings-as-errors=bugprone-*
        types_or: [c, c++]
        additional_dependencies: ['clang-tidy>=18']

  # 配合clang-format使用
  - repo: https://github.com/pre-commit/mirrors-clang-format
    rev: v18.1.0
    hooks:
      - id: clang-format
        types_or: [c, c++]
```

```bash
# 安装pre-commit框架
pip install pre-commit
pre-commit install

# 手动运行所有hooks
pre-commit run --all-files

# 仅运行clang-tidy hook
pre-commit run clang-tidy --all-files
```

#### 自定义检查器开发入门

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    自定义 Clang-Tidy 检查器开发流程                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Step 1: 使用clang-query探索AST                                            │
│  ┌─────────────────────────────────────────────────────────────────┐       │
│  │  $ clang-query source.cpp --                                    │       │
│  │  clang-query> match functionDecl(hasName("main"))               │       │
│  │  clang-query> match varDecl(hasType(isInteger()))               │       │
│  │  clang-query> match cxxMethodDecl(isVirtual(), unless(isOverride))│     │
│  └─────────────────────────────────────────────────────────────────┘       │
│                    │                                                        │
│                    ▼                                                        │
│  Step 2: 编写AST Matcher表达式                                              │
│  ┌─────────────────────────────────────────────────────────────────┐       │
│  │  // 匹配：裸new表达式（应使用make_unique/make_shared）           │       │
│  │  auto matcher = cxxNewExpr(                                     │       │
│  │    unless(hasParent(cxxBindTemporaryExpr())),                    │       │
│  │    unless(hasAncestor(cxxConstructExpr(                          │       │
│  │      hasType(cxxRecordDecl(hasName("unique_ptr"))))))            │       │
│  │  ).bind("raw_new");                                              │       │
│  └─────────────────────────────────────────────────────────────────┘       │
│                    │                                                        │
│                    ▼                                                        │
│  Step 3: 实现Check类                                                        │
│  ┌─────────────────────────────────────────────────────────────────┐       │
│  │  class AvoidRawNewCheck : public ClangTidyCheck {               │       │
│  │    void registerMatchers(MatchFinder*) override;                │       │
│  │    void check(const MatchFinder::MatchResult&) override;        │       │
│  │  };                                                              │       │
│  └─────────────────────────────────────────────────────────────────┘       │
│                    │                                                        │
│                    ▼                                                        │
│  Step 4: 注册到Module → 编译 → 测试                                         │
│  ┌─────────────────────────────────────────────────────────────────┐       │
│  │  // 在Module中注册                                               │       │
│  │  class MyModule : public ClangTidyModule {                      │       │
│  │    void addCheckFactories(CheckFactories& facts) override {     │       │
│  │      facts.registerCheck<AvoidRawNewCheck>("my-avoid-raw-new"); │       │
│  │    }                                                             │       │
│  │  };                                                              │       │
│  └─────────────────────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────────────────┘
```

**使用clang-query交互式探索AST**：

```bash
# clang-query是AST匹配的交互式工具
# 安装（通常随clang-tools-extra一起安装）
sudo apt-get install clang-tools

# 基本使用（-- 后面可加编译选项）
clang-query source.cpp -- -std=c++17

# 常用clang-query命令
# match <matcher>     - 查找匹配节点
# set output diag     - 设置输出为诊断信息格式
# set output dump     - 设置输出为AST dump格式
# set output print    - 设置输出为源码打印格式
# let <name> <matcher> - 定义命名匹配器
```

```cpp
// ============================================================
// 示例：自定义检查器 - 检测裸new表达式
// ============================================================
// 文件：AvoidRawNewCheck.h

#ifndef AVOID_RAW_NEW_CHECK_H
#define AVOID_RAW_NEW_CHECK_H

#include "clang-tidy/ClangTidyCheck.h"

namespace clang::tidy::custom {

/// 检测裸new/delete表达式，建议使用智能指针
///
/// 触发场景:
///   int* p = new int(42);        // 警告：使用std::make_unique
///   delete p;                    // 警告：使用智能指针自动管理
///   auto arr = new int[100];     // 警告：使用std::make_unique<int[]>
///
/// 不触发:
///   auto p = std::make_unique<int>(42);  // OK
///   placement new                        // OK（放置new不管理内存）
class AvoidRawNewCheck : public ClangTidyCheck {
public:
    AvoidRawNewCheck(StringRef Name, ClangTidyContext* Context)
        : ClangTidyCheck(Name, Context),
          // 从.clang-tidy配置读取选项
          WarnOnArrayNew(Options.get("WarnOnArrayNew", true)),
          WarnOnDelete(Options.get("WarnOnDelete", true)) {}

    // 注册AST匹配器
    void registerMatchers(ast_matchers::MatchFinder* Finder) override {
        using namespace ast_matchers;

        // 匹配裸new表达式（排除placement new）
        Finder->addMatcher(
            cxxNewExpr(
                unless(isPlacementNew())   // 排除placement new
            ).bind("raw_new"),
            this
        );

        // 匹配delete表达式
        if (WarnOnDelete) {
            Finder->addMatcher(
                cxxDeleteExpr().bind("raw_delete"),
                this
            );
        }
    }

    // 对每个匹配结果生成诊断
    void check(const ast_matchers::MatchFinder::MatchResult& Result) override {
        // 处理new表达式
        if (const auto* NewExpr =
                Result.Nodes.getNodeAs<CXXNewExpr>("raw_new")) {
            handleNewExpr(NewExpr, Result);
        }

        // 处理delete表达式
        if (const auto* DeleteExpr =
                Result.Nodes.getNodeAs<CXXDeleteExpr>("raw_delete")) {
            diag(DeleteExpr->getBeginLoc(),
                 "avoid bare 'delete'; use smart pointers for automatic "
                 "memory management");
        }
    }

    // 存储配置选项
    void storeOptions(ClangTidyOptions::OptionMap& Opts) override {
        Options.store(Opts, "WarnOnArrayNew", WarnOnArrayNew);
        Options.store(Opts, "WarnOnDelete", WarnOnDelete);
    }

private:
    void handleNewExpr(const CXXNewExpr* NewExpr,
                       const ast_matchers::MatchFinder::MatchResult& Result) {
        if (NewExpr->isArray()) {
            if (WarnOnArrayNew) {
                // 数组new：建议使用std::make_unique<T[]>
                diag(NewExpr->getBeginLoc(),
                     "avoid bare 'new[]'; use 'std::make_unique<T[]>(n)' "
                     "instead")
                    << FixItHint::CreateReplacement(
                        NewExpr->getSourceRange(),
                        "std::make_unique</*type*/[]>(/*size*/)");
            }
        } else {
            // 单个对象new：建议使用std::make_unique<T>
            diag(NewExpr->getBeginLoc(),
                 "avoid bare 'new'; use 'std::make_unique<%0>()' instead")
                << NewExpr->getAllocatedType()
                << FixItHint::CreateReplacement(
                    NewExpr->getSourceRange(),
                    "std::make_unique<" +
                        NewExpr->getAllocatedType().getAsString() + ">(...)");
        }
    }

    const bool WarnOnArrayNew;
    const bool WarnOnDelete;
};

} // namespace clang::tidy::custom

#endif // AVOID_RAW_NEW_CHECK_H
```

```cpp
// ============================================================
// 自定义检查器模块注册
// ============================================================
// 文件：CustomModule.cpp

#include "AvoidRawNewCheck.h"
#include "clang-tidy/ClangTidyModule.h"
#include "clang-tidy/ClangTidyModuleRegistry.h"

namespace clang::tidy::custom {

class CustomModule : public ClangTidyModule {
public:
    void addCheckFactories(ClangTidyCheckFactories& CheckFactories) override {
        // 注册检查器，名称格式：<module>-<check-name>
        CheckFactories.registerCheck<AvoidRawNewCheck>(
            "custom-avoid-raw-new");

        // 可以注册更多自定义检查器
        // CheckFactories.registerCheck<MyOtherCheck>("custom-other-check");
    }
};

// 注册模块到全局注册表
static ClangTidyModuleRegistry::Add<CustomModule>
    X("custom-module", "Adds custom project-specific checks.");

} // namespace clang::tidy::custom
```

**AST Matchers常用参考**：

```cpp
// ============================================================
// AST Matchers 常用表达式速查
// ============================================================

// ── 声明匹配器 ──
functionDecl()                     // 匹配函数声明
functionDecl(hasName("foo"))       // 匹配名为foo的函数
functionDecl(returns(asString("int")))  // 匹配返回int的函数
varDecl(hasType(isInteger()))      // 匹配整数类型变量
cxxRecordDecl(isDerivedFrom("Base"))   // 匹配继承自Base的类
cxxMethodDecl(isVirtual())         // 匹配虚函数
cxxMethodDecl(isOverride())        // 匹配override函数

// ── 语句匹配器 ──
callExpr(callee(functionDecl(hasName("printf"))))  // 匹配printf调用
cxxNewExpr()                       // 匹配new表达式
cxxDeleteExpr()                    // 匹配delete表达式
ifStmt(hasCondition(boolLiteral())) // 匹配条件为字面bool的if
forStmt()                          // 匹配for循环
returnStmt(hasReturnValue(nullPointerConstant()))  // 匹配return nullptr

// ── 组合器 ──
allOf(matcher1, matcher2)          // 同时满足
anyOf(matcher1, matcher2)          // 满足其一
unless(matcher)                    // 取反
has(matcher)                       // 直接子节点匹配
hasDescendant(matcher)             // 后代节点匹配
hasAncestor(matcher)               // 祖先节点匹配
hasParent(matcher)                 // 父节点匹配

// ── 绑定与引用 ──
// .bind("name")将匹配的节点绑定到名称，在check()中通过
// Result.Nodes.getNodeAs<Type>("name")获取
functionDecl(hasName("main")).bind("main_func")
```

#### Week 4 输出物清单

| # | 输出物 | 说明 | 检验标准 |
|---|--------|------|----------|
| 1 | cmake/ClangTidy.cmake | 可复用CMake模块 | 支持ENABLE开关和WARNINGS_AS_ERRORS |
| 2 | practice/cmake_integration/ | CMake集成示例项目 | cmake --build构建时自动运行clang-tidy |
| 3 | practice/suppression_demo/ | NOLINT各种用法示例 | 5种抑制方式均有示例 |
| 4 | .github/workflows/clang-tidy.yml | CI工作流配置 | 全量+PR增量双模式 |
| 5 | scripts/clang-tidy-diff.sh | PR增量检查脚本 | 只检查变更文件的变更行 |
| 6 | .pre-commit-config.yaml | Pre-commit配置 | git commit前自动检查 |
| 7 | practice/custom_check/ | 自定义检查器示例 | 包含AvoidRawNewCheck实现 |
| 8 | notes/ast_matchers_intro.md | AST Matchers学习笔记 | 包含10+常用Matcher示例 |
| 9 | notes/week4_cmake_ci.md | Week 4学习总结 | 覆盖CMake/CI/自定义检查器 |

#### Week 4 检验标准

- [ ] 能够编写ClangTidy.cmake模块并在项目中使用
- [ ] 理解CMAKE_CXX_CLANG_TIDY属性的工作原理
- [ ] 能够正确使用NOLINT/NOLINTNEXTLINE/NOLINTBEGIN-END
- [ ] 能够编写GitHub Actions工作流进行全量和增量分析
- [ ] 理解clang-tidy-diff增量检查的原理和使用方法
- [ ] 能够配置pre-commit hook进行提交前检查
- [ ] 理解AST Matchers API的基本概念
- [ ] 能够使用clang-query交互式探索AST
- [ ] 能够编写简单的自定义Clang-Tidy检查器
- [ ] 理解检查器注册机制（Module→CheckFactories→Check）

---

## 源码阅读任务

### 本月源码阅读

1. **Clang-Tidy源码**
   - 仓库：https://github.com/llvm/llvm-project
   - 路径：`clang-tools-extra/clang-tidy/`
   - 重点：`modernize/UseNullptrCheck.cpp`

2. **知名项目的配置**
   - LLVM项目的.clang-tidy
   - Chromium的clang-tidy配置

3. **检查器实现**
   - 理解AST匹配器
   - 理解诊断报告

---

## 实践项目

### 项目：代码质量检查集成工具

创建一个集成Clang-Tidy的代码质量检查工具。

**项目结构**：

```
code-quality/
├── CMakeLists.txt
├── .clang-tidy
├── cmake/
│   └── ClangTidy.cmake
├── include/
│   └── quality/
│       ├── analyzer.hpp
│       └── report.hpp
├── src/
│   ├── analyzer.cpp
│   └── report.cpp
├── tools/
│   └── check_quality.cpp
└── scripts/
    ├── run-clang-tidy.sh
    └── generate-report.py
```

**.clang-tidy**（项目配置）：

```yaml
Checks: >
  -*,
  bugprone-*,
  clang-analyzer-*,
  cppcoreguidelines-*,
  -cppcoreguidelines-avoid-magic-numbers,
  -cppcoreguidelines-pro-bounds-pointer-arithmetic,
  -cppcoreguidelines-pro-type-reinterpret-cast,
  google-*,
  -google-build-using-namespace,
  -google-readability-todo,
  misc-*,
  modernize-*,
  -modernize-use-trailing-return-type,
  performance-*,
  readability-*,
  -readability-magic-numbers,
  -readability-identifier-length

WarningsAsErrors: >
  bugprone-use-after-move,
  bugprone-dangling-handle,
  modernize-use-nullptr,
  modernize-use-override

HeaderFilterRegex: '.*'

CheckOptions:
  - key: readability-identifier-naming.ClassCase
    value: CamelCase
  - key: readability-identifier-naming.FunctionCase
    value: camelBack
  - key: readability-identifier-naming.VariableCase
    value: camelBack
  - key: readability-identifier-naming.PrivateMemberSuffix
    value: '_'
  - key: readability-function-cognitive-complexity.Threshold
    value: '20'
  - key: modernize-use-auto.MinTypeNameLength
    value: '5'
```

**include/quality/analyzer.hpp**：

```cpp
#pragma once

#include <string>
#include <vector>
#include <filesystem>
#include <optional>
#include <functional>

namespace quality {

/**
 * @brief 诊断信息
 */
struct Diagnostic {
    enum class Severity {
        Warning,
        Error,
        Note
    };

    std::string file;
    int line;
    int column;
    Severity severity;
    std::string check_name;
    std::string message;
    std::optional<std::string> fix;

    [[nodiscard]] std::string to_string() const;
};

/**
 * @brief 分析结果
 */
struct AnalysisResult {
    std::vector<Diagnostic> diagnostics;
    int warnings_count = 0;
    int errors_count = 0;
    double analysis_time_seconds = 0.0;

    [[nodiscard]] bool has_errors() const { return errors_count > 0; }
    [[nodiscard]] bool is_clean() const { return diagnostics.empty(); }
};

/**
 * @brief 分析器配置
 */
struct AnalyzerConfig {
    std::filesystem::path compile_commands_path;
    std::filesystem::path config_file;
    std::vector<std::string> checks;
    std::vector<std::string> warnings_as_errors;
    bool apply_fixes = false;
    int jobs = 0;  // 0表示自动检测
    std::string header_filter;
};

/**
 * @brief 代码分析器
 */
class Analyzer {
public:
    using ProgressCallback = std::function<void(const std::string& file, int current, int total)>;

    explicit Analyzer(AnalyzerConfig config);
    ~Analyzer();

    // 禁用拷贝
    Analyzer(const Analyzer&) = delete;
    Analyzer& operator=(const Analyzer&) = delete;

    /**
     * @brief 分析单个文件
     */
    AnalysisResult analyzeFile(const std::filesystem::path& file);

    /**
     * @brief 分析多个文件
     */
    AnalysisResult analyzeFiles(const std::vector<std::filesystem::path>& files);

    /**
     * @brief 分析整个项目
     */
    AnalysisResult analyzeProject();

    /**
     * @brief 设置进度回调
     */
    void setProgressCallback(ProgressCallback callback);

    /**
     * @brief 获取可用的检查器列表
     */
    static std::vector<std::string> getAvailableChecks();

    /**
     * @brief 检查clang-tidy是否可用
     */
    static bool isAvailable();

    /**
     * @brief 获取clang-tidy版本
     */
    static std::string getVersion();

private:
    class Impl;
    std::unique_ptr<Impl> impl_;
};

} // namespace quality
```

**include/quality/report.hpp**：

```cpp
#pragma once

#include "analyzer.hpp"
#include <ostream>

namespace quality {

/**
 * @brief 报告格式
 */
enum class ReportFormat {
    Text,
    JSON,
    HTML,
    SARIF,  // Static Analysis Results Interchange Format
    JUnit   // 用于CI集成
};

/**
 * @brief 报告生成器
 */
class ReportGenerator {
public:
    virtual ~ReportGenerator() = default;

    virtual void generate(const AnalysisResult& result, std::ostream& out) = 0;

    static std::unique_ptr<ReportGenerator> create(ReportFormat format);
};

/**
 * @brief 文本报告生成器
 */
class TextReportGenerator : public ReportGenerator {
public:
    void generate(const AnalysisResult& result, std::ostream& out) override;
};

/**
 * @brief JSON报告生成器
 */
class JsonReportGenerator : public ReportGenerator {
public:
    void generate(const AnalysisResult& result, std::ostream& out) override;
};

/**
 * @brief HTML报告生成器
 */
class HtmlReportGenerator : public ReportGenerator {
public:
    void generate(const AnalysisResult& result, std::ostream& out) override;

    void setTitle(const std::string& title) { title_ = title; }
    void setStylesheet(const std::string& css) { stylesheet_ = css; }

private:
    std::string title_ = "Code Quality Report";
    std::string stylesheet_;
};

/**
 * @brief SARIF报告生成器（用于GitHub Code Scanning等）
 */
class SarifReportGenerator : public ReportGenerator {
public:
    void generate(const AnalysisResult& result, std::ostream& out) override;

    void setToolName(const std::string& name) { tool_name_ = name; }
    void setToolVersion(const std::string& version) { tool_version_ = version; }

private:
    std::string tool_name_ = "clang-tidy";
    std::string tool_version_;
};

} // namespace quality
```

**src/report.cpp**：

```cpp
#include "quality/report.hpp"
#include <nlohmann/json.hpp>
#include <sstream>
#include <iomanip>
#include <chrono>

namespace quality {

using json = nlohmann::json;

std::unique_ptr<ReportGenerator> ReportGenerator::create(ReportFormat format) {
    switch (format) {
        case ReportFormat::Text:
            return std::make_unique<TextReportGenerator>();
        case ReportFormat::JSON:
            return std::make_unique<JsonReportGenerator>();
        case ReportFormat::HTML:
            return std::make_unique<HtmlReportGenerator>();
        case ReportFormat::SARIF:
            return std::make_unique<SarifReportGenerator>();
        default:
            return std::make_unique<TextReportGenerator>();
    }
}

void TextReportGenerator::generate(const AnalysisResult& result, std::ostream& out) {
    out << "=== Code Quality Report ===\n\n";
    out << "Summary:\n";
    out << "  Warnings: " << result.warnings_count << "\n";
    out << "  Errors: " << result.errors_count << "\n";
    out << "  Analysis time: " << std::fixed << std::setprecision(2)
        << result.analysis_time_seconds << "s\n\n";

    if (result.diagnostics.empty()) {
        out << "No issues found!\n";
        return;
    }

    out << "Issues:\n";
    for (const auto& diag : result.diagnostics) {
        out << diag.to_string() << "\n";
    }
}

void JsonReportGenerator::generate(const AnalysisResult& result, std::ostream& out) {
    json j;
    j["summary"] = {
        {"warnings", result.warnings_count},
        {"errors", result.errors_count},
        {"analysis_time_seconds", result.analysis_time_seconds}
    };

    j["diagnostics"] = json::array();
    for (const auto& diag : result.diagnostics) {
        json d;
        d["file"] = diag.file;
        d["line"] = diag.line;
        d["column"] = diag.column;
        d["severity"] = static_cast<int>(diag.severity);
        d["check"] = diag.check_name;
        d["message"] = diag.message;
        if (diag.fix) {
            d["fix"] = *diag.fix;
        }
        j["diagnostics"].push_back(d);
    }

    out << j.dump(2);
}

void HtmlReportGenerator::generate(const AnalysisResult& result, std::ostream& out) {
    out << R"(<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>)" << title_ << R"(</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 20px; }
        .summary { background: #f5f5f5; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .diagnostic { border-left: 4px solid #ccc; padding: 10px; margin: 10px 0; }
        .warning { border-color: #ffa500; background: #fff8e1; }
        .error { border-color: #f44336; background: #ffebee; }
        .location { font-family: monospace; color: #666; }
        .check { color: #1976d2; font-size: 0.9em; }
        .message { margin-top: 5px; }
        .fix { background: #e8f5e9; padding: 10px; margin-top: 5px; font-family: monospace; }
    </style>
</head>
<body>
    <h1>)" << title_ << R"(</h1>
    <div class="summary">
        <h2>Summary</h2>
        <p>Warnings: )" << result.warnings_count << R"(</p>
        <p>Errors: )" << result.errors_count << R"(</p>
        <p>Analysis time: )" << std::fixed << std::setprecision(2)
                             << result.analysis_time_seconds << R"(s</p>
    </div>
    <h2>Diagnostics</h2>
)";

    for (const auto& diag : result.diagnostics) {
        std::string severity_class =
            diag.severity == Diagnostic::Severity::Error ? "error" : "warning";

        out << R"(    <div class="diagnostic )" << severity_class << R"(">
        <div class="location">)" << diag.file << ":" << diag.line
            << ":" << diag.column << R"(</div>
        <div class="check">)" << diag.check_name << R"(</div>
        <div class="message">)" << diag.message << R"(</div>)";

        if (diag.fix) {
            out << R"(
        <div class="fix"><strong>Fix:</strong> )" << *diag.fix << R"(</div>)";
        }

        out << R"(
    </div>
)";
    }

    out << R"(</body>
</html>)";
}

void SarifReportGenerator::generate(const AnalysisResult& result, std::ostream& out) {
    json sarif;
    sarif["$schema"] = "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json";
    sarif["version"] = "2.1.0";

    json run;
    run["tool"]["driver"]["name"] = tool_name_;
    if (!tool_version_.empty()) {
        run["tool"]["driver"]["version"] = tool_version_;
    }

    // Rules
    json rules = json::array();
    std::set<std::string> seen_checks;
    for (const auto& diag : result.diagnostics) {
        if (seen_checks.insert(diag.check_name).second) {
            json rule;
            rule["id"] = diag.check_name;
            rule["shortDescription"]["text"] = diag.check_name;
            rules.push_back(rule);
        }
    }
    run["tool"]["driver"]["rules"] = rules;

    // Results
    json results = json::array();
    for (const auto& diag : result.diagnostics) {
        json r;
        r["ruleId"] = diag.check_name;
        r["level"] = diag.severity == Diagnostic::Severity::Error ? "error" : "warning";
        r["message"]["text"] = diag.message;

        json location;
        location["physicalLocation"]["artifactLocation"]["uri"] = diag.file;
        location["physicalLocation"]["region"]["startLine"] = diag.line;
        location["physicalLocation"]["region"]["startColumn"] = diag.column;
        r["locations"] = json::array({location});

        if (diag.fix) {
            json fix;
            fix["description"]["text"] = *diag.fix;
            r["fixes"] = json::array({fix});
        }

        results.push_back(r);
    }
    run["results"] = results;

    sarif["runs"] = json::array({run});

    out << sarif.dump(2);
}

std::string Diagnostic::to_string() const {
    std::ostringstream oss;
    oss << file << ":" << line << ":" << column << ": ";

    switch (severity) {
        case Severity::Warning: oss << "warning: "; break;
        case Severity::Error: oss << "error: "; break;
        case Severity::Note: oss << "note: "; break;
    }

    oss << message << " [" << check_name << "]";

    if (fix) {
        oss << "\n  Fix: " << *fix;
    }

    return oss.str();
}

} // namespace quality
```

**scripts/run-clang-tidy.sh**：

```bash
#!/bin/bash
set -e

# 配置
BUILD_DIR="${BUILD_DIR:-build}"
JOBS="${JOBS:-$(nproc)}"
FIX="${FIX:-false}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Running clang-tidy analysis...${NC}"

# 检查编译数据库
if [ ! -f "$BUILD_DIR/compile_commands.json" ]; then
    echo -e "${YELLOW}Generating compile_commands.json...${NC}"
    cmake -B "$BUILD_DIR" -S . -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
fi

# 构建clang-tidy命令
CLANG_TIDY_CMD="run-clang-tidy"

if command -v run-clang-tidy-15 &> /dev/null; then
    CLANG_TIDY_CMD="run-clang-tidy-15"
fi

# 运行分析
if [ "$FIX" = "true" ]; then
    echo -e "${YELLOW}Applying fixes...${NC}"
    $CLANG_TIDY_CMD -p "$BUILD_DIR" -j "$JOBS" -fix
else
    $CLANG_TIDY_CMD -p "$BUILD_DIR" -j "$JOBS"
fi

echo -e "${GREEN}Analysis complete!${NC}"
```

---

## 月度验收标准

### 知识验收（10项）

1. - [ ] 能够解释静态分析 vs 动态分析的区别，以及各自的优劣势
2. - [ ] 能够描述Clang-Tidy的内部处理流程（源码→预处理→AST→Matchers→Checks→Diagnostics→FixIt）
3. - [ ] 能够列举并解释至少8个检查器类别（bugprone/modernize/performance/readability/cppcoreguidelines/clang-analyzer/cert/misc等）
4. - [ ] 能够解释.clang-tidy配置文件的搜索路径和继承机制（子目录覆盖父目录）
5. - [ ] 能够区分检查器别名关系（如cert-dcl21-cpp → bugprone-unhandled-self-assignment，hicpp映射）
6. - [ ] 能够解释compile_commands.json的作用、结构和三种生成方式（CMake/Bear/Ninja）
7. - [ ] 能够描述CMAKE_CXX_CLANG_TIDY属性的工作原理（每次编译自动触发分析）
8. - [ ] 能够解释NOLINT/NOLINTNEXTLINE/NOLINTBEGIN-END的语法和作用域差异
9. - [ ] 能够描述AST Matchers API的基本概念（节点匹配器/缩窄匹配器/遍历匹配器）
10. - [ ] 能够解释clang-tidy-diff增量检查的原理（基于git diff提取变更行，通过-line-filter限制分析范围）

### 实践验收（10项）

1. - [ ] 成功安装Clang-Tidy并对示例项目运行全量分析，正确解读输出
2. - [ ] 编写完整的.clang-tidy配置文件，包含Checks、WarningsAsErrors、HeaderFilterRegex、CheckOptions
3. - [ ] 创建三种项目预设配置（strict/moderate/minimal），并说明各自适用场景
4. - [ ] 对每个主要检查器类别（bugprone/modernize/performance/readability/cppcoreguidelines）编写触发和修复的示例代码
5. - [ ] 编写ClangTidy.cmake可复用模块，支持ENABLE开关和自定义选项
6. - [ ] 编写GitHub Actions工作流，实现push全量分析和PR增量分析双模式
7. - [ ] 配置pre-commit hook，实现提交前自动Clang-Tidy检查
8. - [ ] 使用clang-query交互式探索AST，编写至少5个有效的匹配表达式
9. - [ ] 实现一个完整的自定义检查器（含AST Matcher注册、诊断输出、FixIt建议）
10. - [ ] 完成code-quality实践项目，包含analyzer/report/SARIF输出/脚本自动化

---

## 知识地图

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                Month 43: Clang-Tidy静态分析 知识地图                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│                        ┌───────────────────┐                               │
│                        │   Clang-Tidy      │                               │
│                        │   静态分析        │                               │
│                        └─────────┬─────────┘                               │
│                                  │                                          │
│              ┌───────────────────┼───────────────────┐                     │
│              │                   │                   │                     │
│              ▼                   ▼                   ▼                     │
│   ┌──────────────────┐ ┌────────────────┐ ┌──────────────────┐            │
│   │   基础架构        │ │  检查器体系    │ │   工程集成       │            │
│   │   (Week 1)       │ │  (Week 2-3)    │ │   (Week 4)       │            │
│   └────────┬─────────┘ └───────┬────────┘ └────────┬─────────┘            │
│            │                   │                   │                       │
│   ┌────────┴────────┐ ┌───────┴────────┐ ┌────────┴─────────┐            │
│   │ • 静态分析原理  │ │ • .clang-tidy  │ │ • CMake集成      │            │
│   │ • LLVM/Clang    │ │   配置语法     │ │   (属性/模块)    │            │
│   │   工具链        │ │ • bugprone-*   │ │ • CI/CD集成      │            │
│   │ • AST概念       │ │ • modernize-*  │ │   (GitHub Actions)│            │
│   │ • 编译数据库    │ │ • performance-*│ │ • PR增量检查     │            │
│   │ • 工具生态对比  │ │ • readability-*│ │   (clang-tidy-diff)│           │
│   │   (Clang-Tidy/  │ │ • cppcore      │ │ • Pre-commit     │            │
│   │    Cppcheck/    │ │   guidelines-* │ │   Hook           │            │
│   │    PVS-Studio)  │ │ • cert/hicpp   │ │ • 自定义检查器   │            │
│   │ • 检查器分类    │ │   别名关系     │ │   (AST Matchers) │            │
│   │   (12大类)      │ │ • 项目预设     │ │ • NOLINT抑制     │            │
│   └─────────────────┘ │   方案对比     │ │ • SARIF报告      │            │
│                        └────────────────┘ └──────────────────┘            │
│                                                                             │
│   关联知识:                                                                 │
│   ┌─────────────────────────────────────────────────────────────────┐      │
│   │ Month 37(CMake) → CMake集成基础                                 │      │
│   │ Month 40(CI/CD) → GitHub Actions工作流编写                      │      │
│   │ Month 42(测试)  → 代码质量保证的另一维度                        │      │
│   │ Month 44(Sanitizers) → 运行时检测，与静态分析互补               │      │
│   └─────────────────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 完整输出物清单

| # | 类别 | 输出物 | 说明 |
|---|------|--------|------|
| 1 | 笔记 | notes/static_analysis_overview.md | 静态分析概论与工具对比 |
| 2 | 笔记 | notes/clang_tidy_architecture.md | Clang-Tidy内部架构与流程 |
| 3 | 笔记 | notes/compile_database.md | 编译数据库详解 |
| 4 | 笔记 | notes/checker_categories.md | 12大检查器分类详解 |
| 5 | 笔记 | notes/week1_clang_tidy_basics.md | Week 1学习总结 |
| 6 | 笔记 | notes/clang_tidy_config.md | .clang-tidy配置详解 |
| 7 | 笔记 | notes/project_presets.md | 项目预设方案对比 |
| 8 | 笔记 | notes/week2_configuration.md | Week 2学习总结 |
| 9 | 笔记 | notes/bugprone_checks.md | bugprone-*检查器详解 |
| 10 | 笔记 | notes/modernize_checks.md | modernize-*检查器详解 |
| 11 | 笔记 | notes/performance_checks.md | performance-*检查器详解 |
| 12 | 笔记 | notes/readability_checks.md | readability-*检查器详解 |
| 13 | 笔记 | notes/cppcoreguidelines_checks.md | cppcoreguidelines-*检查器详解 |
| 14 | 笔记 | notes/week3_checkers.md | Week 3学习总结 |
| 15 | 笔记 | notes/ast_matchers_intro.md | AST Matchers学习笔记 |
| 16 | 笔记 | notes/week4_cmake_ci.md | Week 4学习总结 |
| 17 | 笔记 | notes/month43_clang_tidy.md | 月度总结笔记 |
| 18 | 配置 | .clang-tidy | 项目Clang-Tidy配置 |
| 19 | 配置 | .clang-tidy-strict | 严格模式预设 |
| 20 | 配置 | .clang-tidy-minimal | 最小模式预设 |
| 21 | 配置 | .pre-commit-config.yaml | Pre-commit框架配置 |
| 22 | 代码 | cmake/ClangTidy.cmake | 可复用CMake模块 |
| 23 | 代码 | practice/custom_check/AvoidRawNewCheck.h | 自定义检查器实现 |
| 24 | 代码 | practice/custom_check/CustomModule.cpp | 检查器模块注册 |
| 25 | 项目 | code-quality/ | 完整实践项目（analyzer+report+SARIF） |
| 26 | 脚本 | scripts/run-clang-tidy.sh | 全量分析脚本 |
| 27 | 脚本 | scripts/clang-tidy-diff.sh | PR增量检查脚本 |
| 28 | CI | .github/workflows/clang-tidy.yml | GitHub Actions工作流 |

---

## 详细时间分配表

| 周次 | 主题 | 理论学习 | 实践编码 | 源码阅读 | 小计 |
|------|------|----------|----------|----------|------|
| **Week 1** | **Clang-Tidy基础** | | | | **35h** |
| Day 1 | 静态分析概论 | 3h | 1.5h | 0.5h | 5h |
| Day 2 | Clang-Tidy架构 | 3h | 1h | 1h | 5h |
| Day 3 | 安装与基本使用 | 1h | 3.5h | 0.5h | 5h |
| Day 4 | 编译数据库 | 2h | 2.5h | 0.5h | 5h |
| Day 5 | 检查器分类体系 | 2.5h | 2h | 0.5h | 5h |
| Day 6 | 工作流实践 | 1h | 3.5h | 0.5h | 5h |
| Day 7 | 源码阅读与总结 | 1.5h | 1h | 2.5h | 5h |
| **Week 2** | **.clang-tidy配置** | | | | **35h** |
| Day 8 | 配置文件语法 | 3h | 1.5h | 0.5h | 5h |
| Day 9 | 继承与搜索路径 | 2h | 2.5h | 0.5h | 5h |
| Day 10 | CheckOptions详解 | 1.5h | 3h | 0.5h | 5h |
| Day 11 | 命名规范配置 | 1h | 3.5h | 0.5h | 5h |
| Day 12 | 严格模式预设 | 1h | 3h | 1h | 5h |
| Day 13 | 中等/最小预设 | 1h | 3h | 1h | 5h |
| Day 14 | 源码阅读与总结 | 1.5h | 1h | 2.5h | 5h |
| **Week 3** | **重要检查器详解** | | | | **35h** |
| Day 15 | bugprone-*系列(上) | 1.5h | 3h | 0.5h | 5h |
| Day 16 | bugprone-*系列(下) | 1.5h | 3h | 0.5h | 5h |
| Day 17 | modernize-*系列(上) | 1.5h | 3h | 0.5h | 5h |
| Day 18 | modernize-*系列(下) | 1.5h | 3h | 0.5h | 5h |
| Day 19 | performance-*系列 | 1.5h | 3h | 0.5h | 5h |
| Day 20 | readability-* + cppcoreguidelines-* | 1.5h | 3h | 0.5h | 5h |
| Day 21 | 检查器选择策略与总结 | 2h | 1h | 2h | 5h |
| **Week 4** | **CMake集成与CI/CD** | | | | **35h** |
| Day 22 | CMake集成 | 1.5h | 3h | 0.5h | 5h |
| Day 23 | NOLINT警告抑制 | 1h | 3.5h | 0.5h | 5h |
| Day 24 | GitHub Actions CI | 1.5h | 3h | 0.5h | 5h |
| Day 25 | PR增量检查与Pre-commit | 1h | 3.5h | 0.5h | 5h |
| Day 26 | 自定义检查器(上) | 2h | 2h | 1h | 5h |
| Day 27 | 自定义检查器(下) | 1.5h | 2.5h | 1h | 5h |
| Day 28 | 实践项目完善与月度总结 | 1h | 2.5h | 1.5h | 5h |
| | | | | | |
| **合计** | | **43h** | **77h** | **20h** | **140h** |

---

## 下月预告

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Month 43 → Month 44 衔接                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Month 43: Clang-Tidy静态分析          Month 44: Sanitizers运行时检测       │
│  ┌───────────────────────┐             ┌───────────────────────┐           │
│  │ • 编译期代码分析       │             │ • 运行时错误检测       │           │
│  │ • AST模式匹配         │             │ • 插桩(Instrumentation)│           │
│  │ • 风格/规范/潜在Bug   │             │ • 内存/线程/未定义行为 │           │
│  │ • 零运行时开销        │  互补关系    │ • 有运行时开销        │           │
│  │ • 误报较多            │◀──────────▶│ • 几乎零误报          │           │
│  │ • 覆盖面广但浅       │             │ • 覆盖面窄但深        │           │
│  └───────────────────────┘             └───────────────────────┘           │
│                                                                             │
│  衔接知识点：                                                               │
│  ┌─────────────────────────────────────────────────────────────────┐      │
│  │ 1. Clang-Tidy的clang-analyzer-*检查器 → Sanitizers更深层检测  │      │
│  │ 2. CI中Clang-Tidy静态分析 → CI中Sanitizers测试运行            │      │
│  │ 3. 编译期发现潜在Bug → 运行时确认和复现Bug                     │      │
│  │ 4. CMake集成Clang-Tidy → CMake配置Sanitizer编译选项           │      │
│  └─────────────────────────────────────────────────────────────────┘      │
│                                                                             │
│  Month 44 预览：                                                            │
│  ┌─────────────────────────────────────────────────────────────────┐      │
│  │ Week 1: AddressSanitizer (ASan) — 内存错误检测                  │      │
│  │         堆溢出/栈溢出/UAF/双重释放/内存泄漏                     │      │
│  │ Week 2: ThreadSanitizer (TSan) — 数据竞争检测                   │      │
│  │         竞态条件/死锁/线程安全违规                               │      │
│  │ Week 3: UndefinedBehaviorSanitizer (UBSan) — 未定义行为检测     │      │
│  │         整数溢出/空指针解引用/对齐违规/类型混淆                  │      │
│  │ Week 4: MemorySanitizer (MSan) + 综合实践                       │      │
│  │         未初始化内存读取/CI集成/性能影响分析                     │      │
│  └─────────────────────────────────────────────────────────────────┘      │
│                                                                             │
│  完整的C++代码质量保障链：                                                   │
│  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐             │
│  │编码规范 │─▶│静态分析│─▶│单元测试│─▶│运行时  │─▶│性能    │             │
│  │(格式化) │  │(M43)   │  │(M42)   │  │检测    │  │分析    │             │
│  │clang-   │  │clang-  │  │GTest/  │  │(M44)   │  │(未来)  │             │
│  │format   │  │tidy    │  │Catch2  │  │ASan/   │  │perf/   │             │
│  │         │  │        │  │        │  │TSan/   │  │VTune   │             │
│  │         │  │        │  │        │  │UBSan   │  │        │             │
│  └────────┘  └────────┘  └────────┘  └────────┘  └────────┘             │
│    编译前       编译期       测试期       运行期       优化期               │
└─────────────────────────────────────────────────────────────────────────────┘
```

Month 44将学习**Sanitizers（ASan/TSan/UBSan/MSan）**，掌握运行时错误检测工具，与本月的静态分析形成互补，构建完整的C++代码质量保障体系。
