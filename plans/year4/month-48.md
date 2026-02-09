# Month 48: 第四年总结与综合项目——现代C++工程化实践

## 本月主题概述

本月是第四年的总结月，将整合全年学习的现代工程化知识，构建一个完整的、生产级的C++微服务项目。项目将包含完整的构建系统、测试框架、CI/CD流水线、容器化部署、日志和监控。

**学习目标**：
- 综合运用全年学习的工程化技能
- 构建一个完整的生产级C++项目
- 掌握项目从零到部署的全流程
- 为第五年的高级主题做准备

---

## 第四年知识回顾

### 知识体系总结

```
第四年：现代工程化与独立开发者全栈能力
├── 构建系统（Month 37-39）
│   ├── Modern CMake深度使用
│   ├── vcpkg包管理器
│   └── Conan包管理器
│
├── 持续集成与部署（Month 40-41）
│   ├── GitHub Actions CI/CD
│   └── Docker容器化
│
├── 代码质量（Month 42-44）
│   ├── 单元测试（Google Test/Catch2）
│   ├── Clang-Tidy静态分析
│   └── Sanitizers运行时检测
│
└── 可观测性（Month 45-47）
    ├── 性能分析与Profiling
    ├── 日志系统设计
    └── 指标收集与监控
```

### 技能检验清单

**构建系统**：
- [ ] 能够编写Modern CMake配置
- [ ] 能够使用vcpkg/Conan管理依赖
- [ ] 理解跨平台构建的最佳实践

**CI/CD**：
- [ ] 能够配置GitHub Actions工作流
- [ ] 能够实现多平台自动化构建
- [ ] 能够配置自动化测试和发布

**容器化**：
- [ ] 能够编写优化的Dockerfile
- [ ] 能够使用Docker Compose编排服务
- [ ] 理解容器安全最佳实践

**测试**：
- [ ] 能够编写单元测试和集成测试
- [ ] 能够使用Mock进行依赖隔离
- [ ] 能够实现测试覆盖率分析

**代码质量**：
- [ ] 能够配置Clang-Tidy检查
- [ ] 能够使用Sanitizers检测问题
- [ ] 能够进行性能分析和优化

**可观测性**：
- [ ] 能够设计结构化日志系统
- [ ] 能够实现Prometheus指标暴露
- [ ] 能够配置监控和告警

---

## 详细四周学习计划

### 学习时间安排

- **每日学习时间**：5小时
- **每周学习时间**：35小时
- **本月总学习时间**：140小时

---

## Week 1: 项目规划与架构设计（35小时）

### 1.1 本周学习路线图

```
Week 1: 项目规划与架构设计（35小时）

Day 1-2              Day 3-4              Day 5-7
项目初始化           核心接口设计         依赖集成与框架
    │                    │                    │
    ▼                    ▼                    ▼
┌─────────────┐   ┌──────────────┐   ┌──────────────┐
│目录结构设计 │   │Task数据模型  │   │vcpkg依赖配置 │
│CMake配置    │   │Scheduler接口 │   │Boost.Asio    │
│CMakePresets │   │API路由设计   │   │spdlog集成    │
│编译器警告   │   │存储层抽象    │   │基础框架搭建  │
└─────────────┘   └──────────────┘   └──────────────┘
    │                    │                    │
    ▼                    ▼                    ▼
 输出：可构建         输出：完整的          输出：可编译
 的空项目框架         头文件接口            的基础框架
```

### 1.2 每日任务分解

| Day | 时间 | 主题 | 具体任务 | 输出物 |
|-----|------|------|----------|--------|
| Day 1 | 5h | 项目初始化 | 1. 创建目录结构 2. 编写根CMakeLists.txt 3. 配置C++20标准 4. 设置编译器警告模块 | CMakeLists.txt, cmake/CompilerWarnings.cmake |
| Day 2 | 5h | CMake进阶配置 | 1. 编写CMakePresets.json 2. 配置Sanitizers模块 3. 配置静态分析模块 4. 测试构建流程 | CMakePresets.json, cmake/Sanitizers.cmake |
| Day 3 | 5h | Task模型设计 | 1. 设计TaskStatus枚举 2. 设计TaskPriority枚举 3. 设计Task类接口 4. 设计序列化接口 | include/scheduler/core/task.hpp |
| Day 4 | 5h | 核心接口设计 | 1. 设计Scheduler接口 2. 设计TaskQueue接口 3. 设计Executor接口 4. 设计Repository接口 | include/scheduler/core/*.hpp |
| Day 5 | 5h | vcpkg配置 | 1. 编写vcpkg.json 2. 配置依赖版本 3. 测试依赖安装 4. 集成到CMake | vcpkg.json |
| Day 6 | 5h | 基础库集成 | 1. 集成fmt库 2. 集成spdlog 3. 集成nlohmann_json 4. 编写测试代码 | src/main.cpp (基础版) |
| Day 7 | 5h | 框架完善 | 1. 集成Boost.Asio 2. 配置yaml-cpp 3. 编写Config模块 4. 整体构建测试 | include/scheduler/config/config.hpp |

### 1.3 核心知识点详解

#### 1.3.1 Modern CMake 项目结构

**设计原则**：
- **Target-Centric**：以目标为中心，而非变量
- **属性传播**：使用PUBLIC/PRIVATE/INTERFACE控制依赖传播
- **模块化**：将可复用配置抽取为独立模块

```cmake
# ============================================================
# CMakeLists.txt - 项目根配置
# 遵循Modern CMake最佳实践
# ============================================================

cmake_minimum_required(VERSION 3.20)

# 项目定义 - 包含版本和描述
project(TaskScheduler
    VERSION 1.0.0
    DESCRIPTION "A high-performance distributed task scheduler"
    LANGUAGES CXX
)

# ============================================================
# 防护措施
# ============================================================

# 禁止in-source构建（污染源代码目录）
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_BINARY_DIR)
    message(FATAL_ERROR
        "In-source builds are not allowed. "
        "Please create a build directory and run cmake from there."
    )
endif()

# 仅在顶层项目时设置某些选项
if(CMAKE_PROJECT_NAME STREQUAL PROJECT_NAME)
    # 确保使用-std=c++xx而非-std=gnu++xx
    set(CMAKE_CXX_EXTENSIONS OFF)

    # 支持IDE的文件夹组织
    set_property(GLOBAL PROPERTY USE_FOLDERS ON)

    # 生成compile_commands.json供工具使用
    set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
endif()

# ============================================================
# C++标准设置
# ============================================================

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ============================================================
# 构建选项
# ============================================================

option(SCHEDULER_BUILD_TESTS "Build tests" ON)
option(SCHEDULER_BUILD_DOCS "Build documentation" OFF)
option(SCHEDULER_ENABLE_COVERAGE "Enable coverage reporting" OFF)

# Sanitizer选项（互斥，不能同时启用）
option(SCHEDULER_ENABLE_ASAN "Enable AddressSanitizer" OFF)
option(SCHEDULER_ENABLE_TSAN "Enable ThreadSanitizer" OFF)
option(SCHEDULER_ENABLE_UBSAN "Enable UndefinedBehaviorSanitizer" OFF)

# ============================================================
# 模块路径
# ============================================================

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# 包含自定义模块
include(CompilerWarnings)
include(Sanitizers)
include(StaticAnalyzers)
```

#### 1.3.2 编译器警告配置模块

```cmake
# ============================================================
# cmake/CompilerWarnings.cmake
# 统一的编译器警告配置
# ============================================================

# 定义警告标志
function(set_project_warnings target_name)
    # 基础警告集（所有编译器通用概念）
    set(CLANG_WARNINGS
        -Wall                   # 基础警告
        -Wextra                 # 额外警告
        -Wpedantic              # 严格ISO C++
        -Wshadow                # 变量遮蔽
        -Wnon-virtual-dtor      # 非虚析构函数
        -Wold-style-cast        # C风格转换
        -Wcast-align            # 对齐转换
        -Wunused                # 未使用
        -Woverloaded-virtual    # 虚函数重载隐藏
        -Wconversion            # 类型转换
        -Wsign-conversion       # 符号转换
        -Wnull-dereference      # 空指针解引用
        -Wdouble-promotion      # float到double隐式提升
        -Wformat=2              # printf格式检查
        -Wimplicit-fallthrough  # switch穿透
    )

    set(GCC_WARNINGS
        ${CLANG_WARNINGS}
        -Wmisleading-indentation    # 缩进误导
        -Wduplicated-cond           # 重复条件
        -Wduplicated-branches       # 重复分支
        -Wlogical-op                # 逻辑运算符错误
        -Wuseless-cast              # 无用转换
    )

    # 根据编译器选择警告集
    if(CMAKE_CXX_COMPILER_ID MATCHES ".*Clang")
        set(PROJECT_WARNINGS ${CLANG_WARNINGS})
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        set(PROJECT_WARNINGS ${GCC_WARNINGS})
    elseif(MSVC)
        set(PROJECT_WARNINGS
            /W4         # 警告级别4
            /permissive- # 严格标准
            /w14242     # 转换警告
            /w14254     # 运算符优先级
            /w14263     # 重载隐藏
            /w14265     # 非虚析构
            /w14287     # 无符号负值
            /w14296     # 表达式始终false
            /w14311     # 指针截断
            /w14545     # 逗号表达式
            /w14546
            /w14547
            /w14549
            /w14555     # 无副作用表达式
            /w14619     # pragma warning无效
            /w14640     # 线程不安全静态初始化
            /w14826     # 符号转换
            /w14905     # LPSTR转换
            /w14906     # LPWSTR转换
            /w14928     # 非法拷贝初始化
        )
    else()
        message(WARNING "Unknown compiler, no warnings set")
        return()
    endif()

    # 应用警告到目标
    target_compile_options(${target_name} PRIVATE ${PROJECT_WARNINGS})
endfunction()
```

#### 1.3.3 CMakePresets.json 配置

```json
{
    "version": 6,
    "cmakeMinimumRequired": {
        "major": 3,
        "minor": 20,
        "patch": 0
    },
    "configurePresets": [
        {
            "name": "base",
            "hidden": true,
            "generator": "Ninja",
            "binaryDir": "${sourceDir}/build/${presetName}",
            "cacheVariables": {
                "CMAKE_TOOLCHAIN_FILE": {
                    "type": "FILEPATH",
                    "value": "$env{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake"
                }
            }
        },
        {
            "name": "debug",
            "inherits": "base",
            "displayName": "Debug",
            "cacheVariables": {
                "CMAKE_BUILD_TYPE": "Debug"
            }
        },
        {
            "name": "release",
            "inherits": "base",
            "displayName": "Release",
            "cacheVariables": {
                "CMAKE_BUILD_TYPE": "Release"
            }
        },
        {
            "name": "ci-gcc",
            "inherits": "base",
            "displayName": "CI GCC",
            "cacheVariables": {
                "CMAKE_BUILD_TYPE": "Release",
                "CMAKE_C_COMPILER": "gcc",
                "CMAKE_CXX_COMPILER": "g++"
            }
        },
        {
            "name": "ci-clang",
            "inherits": "base",
            "displayName": "CI Clang",
            "cacheVariables": {
                "CMAKE_BUILD_TYPE": "Release",
                "CMAKE_C_COMPILER": "clang",
                "CMAKE_CXX_COMPILER": "clang++"
            }
        },
        {
            "name": "asan",
            "inherits": "debug",
            "displayName": "AddressSanitizer",
            "cacheVariables": {
                "SCHEDULER_ENABLE_ASAN": "ON"
            }
        },
        {
            "name": "tsan",
            "inherits": "debug",
            "displayName": "ThreadSanitizer",
            "cacheVariables": {
                "SCHEDULER_ENABLE_TSAN": "ON"
            }
        },
        {
            "name": "ubsan",
            "inherits": "debug",
            "displayName": "UBSanitizer",
            "cacheVariables": {
                "SCHEDULER_ENABLE_UBSAN": "ON"
            }
        },
        {
            "name": "coverage",
            "inherits": "debug",
            "displayName": "Coverage",
            "cacheVariables": {
                "SCHEDULER_ENABLE_COVERAGE": "ON"
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
            "name": "debug",
            "configurePreset": "debug",
            "output": {
                "outputOnFailure": true
            }
        }
    ]
}
```

#### 1.3.4 Task 数据模型设计

```cpp
// ============================================================
// include/scheduler/core/task.hpp
// 任务数据模型 - 核心领域对象
// ============================================================

#pragma once

#include <string>
#include <chrono>
#include <optional>
#include <functional>
#include <nlohmann/json.hpp>

namespace scheduler {

// ============================================================
// 任务状态枚举
// 使用enum class确保类型安全
// ============================================================
enum class TaskStatus {
    Pending,    // 等待执行
    Running,    // 正在执行
    Completed,  // 执行完成
    Failed,     // 执行失败
    Cancelled,  // 已取消
    Retrying    // 重试中
};

// 状态转字符串（用于日志和序列化）
constexpr const char* to_string(TaskStatus status) {
    switch (status) {
        case TaskStatus::Pending:   return "pending";
        case TaskStatus::Running:   return "running";
        case TaskStatus::Completed: return "completed";
        case TaskStatus::Failed:    return "failed";
        case TaskStatus::Cancelled: return "cancelled";
        case TaskStatus::Retrying:  return "retrying";
    }
    return "unknown";
}

// ============================================================
// 任务优先级
// 数值越大优先级越高
// ============================================================
enum class TaskPriority {
    Low = 0,
    Normal = 1,
    High = 2,
    Critical = 3
};

// ============================================================
// 任务配置
// 控制任务的执行行为
// ============================================================
struct TaskConfig {
    int max_retries = 3;                           // 最大重试次数
    std::chrono::seconds retry_delay{60};          // 重试间隔
    std::chrono::seconds timeout{300};             // 执行超时
    TaskPriority priority = TaskPriority::Normal;  // 优先级

    // JSON序列化支持
    NLOHMANN_DEFINE_TYPE_INTRUSIVE(TaskConfig,
        max_retries, priority)
};

// ============================================================
// Task类 - 核心任务实体
//
// 设计要点：
// 1. 不可变ID - 创建后不可更改
// 2. 状态机 - 通过方法控制状态转换
// 3. 时间追踪 - 记录完整生命周期
// 4. 序列化支持 - 支持持久化存储
// ============================================================
class Task {
public:
    // 类型别名，提高可读性
    using Id = std::string;
    using Timestamp = std::chrono::system_clock::time_point;
    using Payload = nlohmann::json;

    // ========================================================
    // 构造函数
    // ========================================================

    /// @brief 创建新任务
    /// @param type 任务类型（用于路由到对应handler）
    /// @param payload 任务载荷数据
    /// @param config 任务配置（可选）
    Task(std::string type, Payload payload, TaskConfig config = {});

    // 禁用拷贝，允许移动
    Task(const Task&) = delete;
    Task& operator=(const Task&) = delete;
    Task(Task&&) noexcept = default;
    Task& operator=(Task&&) noexcept = default;

    ~Task() = default;

    // ========================================================
    // Getters - 只读访问
    // ========================================================

    [[nodiscard]] const Id& id() const noexcept { return id_; }
    [[nodiscard]] const std::string& type() const noexcept { return type_; }
    [[nodiscard]] const Payload& payload() const noexcept { return payload_; }
    [[nodiscard]] TaskStatus status() const noexcept { return status_; }
    [[nodiscard]] TaskPriority priority() const noexcept {
        return config_.priority;
    }
    [[nodiscard]] int retryCount() const noexcept { return retry_count_; }
    [[nodiscard]] const TaskConfig& config() const noexcept { return config_; }

    // 时间戳访问
    [[nodiscard]] Timestamp createdAt() const noexcept { return created_at_; }
    [[nodiscard]] std::optional<Timestamp> startedAt() const noexcept {
        return started_at_;
    }
    [[nodiscard]] std::optional<Timestamp> completedAt() const noexcept {
        return completed_at_;
    }

    // 结果访问
    [[nodiscard]] std::optional<std::string> error() const noexcept {
        return error_;
    }
    [[nodiscard]] std::optional<Payload> result() const noexcept {
        return result_;
    }

    // ========================================================
    // 状态转换方法
    // 封装状态机逻辑，确保状态转换合法性
    // ========================================================

    /// @brief 开始执行任务
    /// @throws std::logic_error 如果当前状态不允许开始
    void start();

    /// @brief 标记任务完成
    /// @param result 执行结果
    void complete(Payload result);

    /// @brief 标记任务失败
    /// @param error 错误信息
    void fail(const std::string& error);

    /// @brief 重试任务
    /// @return 是否还可以重试
    bool retry();

    /// @brief 取消任务
    void cancel();

    // ========================================================
    // 序列化
    // ========================================================

    /// @brief 转换为JSON
    [[nodiscard]] nlohmann::json toJson() const;

    /// @brief 从JSON恢复
    static Task fromJson(const nlohmann::json& json);

    // ========================================================
    // 比较运算符（用于优先级队列）
    // ========================================================

    bool operator<(const Task& other) const noexcept {
        // 优先级高的排在前面
        if (config_.priority != other.config_.priority) {
            return config_.priority < other.config_.priority;
        }
        // 同优先级按创建时间排序（先创建的优先）
        return created_at_ > other.created_at_;
    }

private:
    // 核心属性
    Id id_;
    std::string type_;
    Payload payload_;
    TaskStatus status_ = TaskStatus::Pending;
    TaskConfig config_;
    int retry_count_ = 0;

    // 时间追踪
    Timestamp created_at_;
    std::optional<Timestamp> started_at_;
    std::optional<Timestamp> completed_at_;

    // 结果
    std::optional<std::string> error_;
    std::optional<Payload> result_;

    // ID生成（使用UUID）
    static Id generateId();
};

// ============================================================
// TaskHandler类型定义
// 任务处理函数签名
// ============================================================
using TaskHandler = std::function<nlohmann::json(const Task&)>;

} // namespace scheduler
```

### 1.4 Week 1 检验标准

完成本周学习后，你应该能够：

- [ ] 从零创建符合Modern CMake规范的C++项目
- [ ] 配置CMakePresets支持多种构建模式
- [ ] 设计清晰的头文件接口
- [ ] 使用vcpkg管理项目依赖
- [ ] 项目能够成功编译（无警告）

### 1.5 Week 1 输出物清单

| 文件 | 说明 | 完成状态 |
|------|------|---------|
| `CMakeLists.txt` | 项目根配置 | [ ] |
| `CMakePresets.json` | 构建预设 | [ ] |
| `cmake/CompilerWarnings.cmake` | 警告配置 | [ ] |
| `cmake/Sanitizers.cmake` | Sanitizer配置 | [ ] |
| `vcpkg.json` | 依赖配置 | [ ] |
| `include/scheduler/core/task.hpp` | Task接口 | [ ] |
| `include/scheduler/core/scheduler.hpp` | Scheduler接口 | [ ] |
| `include/scheduler/config/config.hpp` | 配置接口 | [ ] |

### 1.6 扩展阅读

1. **Modern CMake官方教程**: https://cmake.org/cmake/help/latest/guide/tutorial/
2. **Professional CMake（书籍）**: Craig Scott著，Modern CMake权威指南
3. **vcpkg文档**: https://vcpkg.io/en/docs/README.html
4. **C++ Core Guidelines**: https://isocpp.github.io/CppCoreGuidelines/

---

## Week 2: 核心功能实现（35小时）

### 2.1 本周学习路线图

```
Week 2: 核心功能实现（35小时）

Day 8-10             Day 11-12            Day 13-14
Task模型实现         Scheduler引擎        HTTP API服务
    │                    │                    │
    ▼                    ▼                    ▼
┌─────────────┐   ┌──────────────┐   ┌──────────────┐
│Task类实现   │   │工作线程池    │   │Boost.Beast   │
│TaskQueue    │   │任务调度逻辑  │   │路由处理      │
│序列化/反序列│   │Handler注册   │   │JSON请求/响应 │
│状态机验证   │   │生命周期管理  │   │错误处理      │
└─────────────┘   └──────────────┘   └──────────────┘
    │                    │                    │
    ▼                    ▼                    ▼
 输出：完整的         输出：可运行          输出：完整
 Task模块             的调度引擎            的API服务
```

### 2.2 每日任务分解

| Day | 时间 | 主题 | 具体任务 | 输出物 |
|-----|------|------|----------|--------|
| Day 8 | 5h | Task实现 | 1. 实现Task构造函数 2. 实现状态转换方法 3. 实现UUID生成 4. 单元测试 | src/core/task.cpp |
| Day 9 | 5h | TaskQueue实现 | 1. 实现优先级队列 2. 线程安全封装 3. 阻塞/非阻塞操作 4. 单元测试 | src/core/queue.cpp |
| Day 10 | 5h | 序列化实现 | 1. Task JSON序列化 2. 反序列化与验证 3. 时间戳处理 4. 边界测试 | tests/unit/task_test.cpp |
| Day 11 | 5h | Scheduler核心 | 1. 工作线程池创建 2. 任务分发逻辑 3. Handler注册机制 4. 基础测试 | src/core/scheduler.cpp |
| Day 12 | 5h | Scheduler完善 | 1. 生命周期管理(start/stop) 2. 优雅关闭 3. 统计信息收集 4. 集成测试 | tests/integration/ |
| Day 13 | 5h | HTTP服务器 | 1. Boost.Beast服务器框架 2. 异步I/O处理 3. 连接管理 4. 基础路由 | src/api/server.cpp |
| Day 14 | 5h | API实现 | 1. POST /tasks 2. GET /tasks/{id} 3. DELETE /tasks/{id} 4. GET /health | src/api/routes.cpp |

### 2.3 核心知识点详解

#### 2.3.1 线程安全的优先级队列

```cpp
// ============================================================
// include/scheduler/core/queue.hpp
// 线程安全的优先级任务队列
// ============================================================

#pragma once

#include "scheduler/core/task.hpp"
#include <queue>
#include <mutex>
#include <condition_variable>
#include <optional>
#include <chrono>

namespace scheduler {

/// @brief 线程安全的优先级任务队列
///
/// 设计要点：
/// 1. 使用mutex保护内部状态
/// 2. 使用condition_variable实现阻塞等待
/// 3. 支持优雅关闭
class TaskQueue {
public:
    explicit TaskQueue(size_t capacity = 10000);
    ~TaskQueue();

    // 禁用拷贝和移动
    TaskQueue(const TaskQueue&) = delete;
    TaskQueue& operator=(const TaskQueue&) = delete;

    // ========================================================
    // 入队操作
    // ========================================================

    /// @brief 添加任务到队列
    /// @param task 要添加的任务（移动语义）
    /// @return 是否成功（队列满时返回false）
    bool push(std::unique_ptr<Task> task);

    /// @brief 阻塞添加任务
    /// @param task 要添加的任务
    /// @param timeout 超时时间
    /// @return 是否成功
    bool push_wait(std::unique_ptr<Task> task,
                   std::chrono::milliseconds timeout);

    // ========================================================
    // 出队操作
    // ========================================================

    /// @brief 非阻塞获取任务
    /// @return 任务（队列空时返回nullptr）
    std::unique_ptr<Task> try_pop();

    /// @brief 阻塞获取任务
    /// @param timeout 超时时间
    /// @return 任务（超时返回nullptr）
    std::unique_ptr<Task> pop_wait(std::chrono::milliseconds timeout);

    // ========================================================
    // 状态查询
    // ========================================================

    [[nodiscard]] size_t size() const;
    [[nodiscard]] bool empty() const;
    [[nodiscard]] bool full() const;
    [[nodiscard]] size_t capacity() const { return capacity_; }

    // ========================================================
    // 生命周期
    // ========================================================

    /// @brief 关闭队列（唤醒所有等待线程）
    void shutdown();

    /// @brief 是否已关闭
    [[nodiscard]] bool is_shutdown() const;

private:
    // 自定义比较器（优先级高的在前）
    struct TaskComparator {
        bool operator()(const std::unique_ptr<Task>& a,
                        const std::unique_ptr<Task>& b) const {
            return *a < *b;  // 使用Task的operator<
        }
    };

    std::priority_queue<std::unique_ptr<Task>,
                        std::vector<std::unique_ptr<Task>>,
                        TaskComparator> queue_;

    mutable std::mutex mutex_;
    std::condition_variable not_empty_;
    std::condition_variable not_full_;

    size_t capacity_;
    bool shutdown_ = false;
};

} // namespace scheduler
```

#### 2.3.2 TaskQueue 实现

```cpp
// ============================================================
// src/core/queue.cpp
// TaskQueue实现
// ============================================================

#include "scheduler/core/queue.hpp"
#include <stdexcept>

namespace scheduler {

TaskQueue::TaskQueue(size_t capacity)
    : capacity_(capacity) {
    if (capacity == 0) {
        throw std::invalid_argument("Queue capacity must be positive");
    }
}

TaskQueue::~TaskQueue() {
    shutdown();
}

bool TaskQueue::push(std::unique_ptr<Task> task) {
    if (!task) return false;

    std::lock_guard<std::mutex> lock(mutex_);

    if (shutdown_ || queue_.size() >= capacity_) {
        return false;
    }

    queue_.push(std::move(task));
    not_empty_.notify_one();
    return true;
}

bool TaskQueue::push_wait(std::unique_ptr<Task> task,
                          std::chrono::milliseconds timeout) {
    if (!task) return false;

    std::unique_lock<std::mutex> lock(mutex_);

    // 等待队列有空间或关闭
    bool success = not_full_.wait_for(lock, timeout, [this] {
        return shutdown_ || queue_.size() < capacity_;
    });

    if (!success || shutdown_) {
        return false;
    }

    queue_.push(std::move(task));
    not_empty_.notify_one();
    return true;
}

std::unique_ptr<Task> TaskQueue::try_pop() {
    std::lock_guard<std::mutex> lock(mutex_);

    if (queue_.empty()) {
        return nullptr;
    }

    // priority_queue的top()返回const引用，需要const_cast
    auto task = std::move(const_cast<std::unique_ptr<Task>&>(queue_.top()));
    queue_.pop();
    not_full_.notify_one();
    return task;
}

std::unique_ptr<Task> TaskQueue::pop_wait(std::chrono::milliseconds timeout) {
    std::unique_lock<std::mutex> lock(mutex_);

    // 等待队列非空或关闭
    bool success = not_empty_.wait_for(lock, timeout, [this] {
        return shutdown_ || !queue_.empty();
    });

    if (!success || queue_.empty()) {
        return nullptr;
    }

    auto task = std::move(const_cast<std::unique_ptr<Task>&>(queue_.top()));
    queue_.pop();
    not_full_.notify_one();
    return task;
}

size_t TaskQueue::size() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return queue_.size();
}

bool TaskQueue::empty() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return queue_.empty();
}

bool TaskQueue::full() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return queue_.size() >= capacity_;
}

void TaskQueue::shutdown() {
    {
        std::lock_guard<std::mutex> lock(mutex_);
        shutdown_ = true;
    }
    // 唤醒所有等待的线程
    not_empty_.notify_all();
    not_full_.notify_all();
}

bool TaskQueue::is_shutdown() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return shutdown_;
}

} // namespace scheduler
```

#### 2.3.3 Scheduler 核心引擎

```cpp
// ============================================================
// src/core/scheduler.cpp
// 核心调度引擎实现
// ============================================================

#include "scheduler/core/scheduler.hpp"
#include "scheduler/observability/logger.hpp"
#include <algorithm>

namespace scheduler {

Scheduler::Scheduler(SchedulerConfig config)
    : config_(std::move(config))
    , queue_(std::make_unique<TaskQueue>(config_.queue_capacity))
    , metrics_(Metrics::create()) {

    LOG_INFO("Scheduler created with {} worker threads",
             config_.worker_threads);
}

Scheduler::~Scheduler() {
    stop();
}

void Scheduler::start() {
    if (running_.exchange(true)) {
        LOG_WARN("Scheduler already running");
        return;
    }

    LOG_INFO("Starting scheduler...");

    // 启动工作线程
    workers_.reserve(config_.worker_threads);
    for (size_t i = 0; i < config_.worker_threads; ++i) {
        workers_.emplace_back([this, i] {
            LOG_DEBUG("Worker {} started", i);
            workerLoop();
            LOG_DEBUG("Worker {} stopped", i);
        });
    }

    // 启动调度线程（处理定时任务）
    scheduler_thread_ = std::thread([this] {
        LOG_DEBUG("Scheduler thread started");
        schedulerLoop();
        LOG_DEBUG("Scheduler thread stopped");
    });

    LOG_INFO("Scheduler started with {} workers", workers_.size());
}

void Scheduler::stop() {
    if (!running_.exchange(false)) {
        return;
    }

    LOG_INFO("Stopping scheduler...");

    // 关闭队列（唤醒所有等待的工作线程）
    queue_->shutdown();

    // 等待工作线程结束
    for (auto& worker : workers_) {
        if (worker.joinable()) {
            worker.join();
        }
    }
    workers_.clear();

    // 等待调度线程结束
    if (scheduler_thread_.joinable()) {
        scheduler_thread_.join();
    }

    LOG_INFO("Scheduler stopped");
}

Task::Id Scheduler::submit(Task task) {
    auto id = task.id();

    LOG_INFO("Submitting task: id={}, type={}", id, task.type());

    auto task_ptr = std::make_unique<Task>(std::move(task));

    if (!queue_->push(std::move(task_ptr))) {
        LOG_ERROR("Failed to submit task {}: queue full", id);
        throw std::runtime_error("Task queue is full");
    }

    metrics_->taskSubmitted(task.type());
    return id;
}

void Scheduler::registerHandler(const std::string& task_type,
                                 TaskHandler handler) {
    std::lock_guard<std::mutex> lock(handlers_mutex_);

    if (handlers_.count(task_type)) {
        LOG_WARN("Overwriting handler for task type: {}", task_type);
    }

    handlers_[task_type] = std::move(handler);
    LOG_INFO("Registered handler for task type: {}", task_type);
}

void Scheduler::workerLoop() {
    while (running_) {
        // 从队列获取任务（带超时）
        auto task = queue_->pop_wait(std::chrono::milliseconds(100));

        if (!task) {
            continue;
        }

        processTask(*task);
    }
}

void Scheduler::processTask(Task& task) {
    auto start_time = std::chrono::steady_clock::now();

    LOG_INFO("Processing task: id={}, type={}", task.id(), task.type());

    // 查找handler
    TaskHandler handler;
    {
        std::lock_guard<std::mutex> lock(handlers_mutex_);
        auto it = handlers_.find(task.type());
        if (it == handlers_.end()) {
            LOG_ERROR("No handler for task type: {}", task.type());
            task.fail("No handler registered for task type: " + task.type());
            metrics_->taskFailed(task.type(), "no_handler");
            return;
        }
        handler = it->second;
    }

    // 执行任务
    task.start();
    metrics_->taskStarted(task.type());

    try {
        auto result = handler(task);
        task.complete(std::move(result));

        auto duration = std::chrono::steady_clock::now() - start_time;
        auto duration_sec = std::chrono::duration<double>(duration).count();

        metrics_->taskCompleted(task.type(), duration_sec);
        LOG_INFO("Task completed: id={}, duration={:.3f}s",
                 task.id(), duration_sec);

    } catch (const std::exception& e) {
        LOG_ERROR("Task failed: id={}, error={}", task.id(), e.what());
        task.fail(e.what());
        metrics_->taskFailed(task.type(), "exception");

        // 检查是否可以重试
        if (task.retry()) {
            LOG_INFO("Retrying task: id={}, attempt={}",
                     task.id(), task.retryCount());
            metrics_->taskRetried(task.type());
            queue_->push(std::make_unique<Task>(std::move(task)));
        }
    }
}

void Scheduler::schedulerLoop() {
    while (running_) {
        // 定时任务调度逻辑
        std::this_thread::sleep_for(config_.polling_interval);

        // TODO: 检查定时任务，将到期的任务加入队列
    }
}

Scheduler::Stats Scheduler::getStats() const {
    return Stats{
        .pending_tasks = queue_->size(),
        .running_tasks = 0,  // TODO: 跟踪运行中的任务
        .completed_tasks = 0,
        .failed_tasks = 0,
        .avg_processing_time_ms = 0.0,
        .workers_active = workers_.size()
    };
}

} // namespace scheduler
```

#### 2.3.4 HTTP API 服务器

```cpp
// ============================================================
// src/api/server.cpp
// HTTP API服务器实现（基于Boost.Beast）
// ============================================================

#include "scheduler/api/server.hpp"
#include "scheduler/observability/logger.hpp"
#include <boost/beast/core.hpp>
#include <boost/beast/http.hpp>
#include <regex>

namespace scheduler::api {

namespace beast = boost::beast;
namespace http = beast::http;
namespace net = boost::asio;
using tcp = net::ip::tcp;

// ============================================================
// 会话类 - 处理单个HTTP连接
// ============================================================
class Session : public std::enable_shared_from_this<Session> {
public:
    Session(tcp::socket socket, std::shared_ptr<Scheduler> scheduler)
        : socket_(std::move(socket))
        , scheduler_(std::move(scheduler)) {}

    void run() {
        doRead();
    }

private:
    void doRead() {
        auto self = shared_from_this();

        http::async_read(socket_, buffer_, request_,
            [self](beast::error_code ec, std::size_t bytes) {
                if (ec) {
                    if (ec != http::error::end_of_stream) {
                        LOG_ERROR("Read error: {}", ec.message());
                    }
                    return;
                }
                self->handleRequest();
            });
    }

    void handleRequest() {
        // 构建响应
        response_ = handleRoute(request_);
        response_.version(request_.version());
        response_.keep_alive(request_.keep_alive());
        response_.prepare_payload();

        doWrite();
    }

    http::response<http::string_body> handleRoute(
        const http::request<http::string_body>& req) {

        auto target = std::string(req.target());
        auto method = req.method();

        LOG_DEBUG("Request: {} {}", http::to_string(method), target);

        // 路由匹配
        if (target == "/health" && method == http::verb::get) {
            return handleHealth();
        }

        if (target == "/tasks" && method == http::verb::post) {
            return handleSubmitTask(req);
        }

        if (target == "/tasks" && method == http::verb::get) {
            return handleListTasks();
        }

        // 匹配 /tasks/{id}
        std::regex task_id_regex("/tasks/([a-zA-Z0-9-]+)");
        std::smatch match;
        if (std::regex_match(target, match, task_id_regex)) {
            std::string task_id = match[1];
            if (method == http::verb::get) {
                return handleGetTask(task_id);
            }
            if (method == http::verb::delete_) {
                return handleCancelTask(task_id);
            }
        }

        if (target == "/stats" && method == http::verb::get) {
            return handleStats();
        }

        // 404 Not Found
        return makeResponse(http::status::not_found,
                            R"({"error": "Not Found"})");
    }

    http::response<http::string_body> handleHealth() {
        return makeResponse(http::status::ok,
                            R"({"status": "healthy"})");
    }

    http::response<http::string_body> handleSubmitTask(
        const http::request<http::string_body>& req) {
        try {
            auto body = nlohmann::json::parse(req.body());

            if (!body.contains("type")) {
                return makeResponse(http::status::bad_request,
                    R"({"error": "Missing 'type' field"})");
            }

            std::string type = body["type"];
            auto payload = body.value("payload", nlohmann::json::object());
            TaskConfig config;
            if (body.contains("config")) {
                config = body["config"].get<TaskConfig>();
            }

            Task task(type, payload, config);
            auto id = scheduler_->submit(std::move(task));

            nlohmann::json response = {
                {"id", id},
                {"status", "submitted"}
            };

            return makeResponse(http::status::created, response.dump());

        } catch (const std::exception& e) {
            LOG_ERROR("Failed to submit task: {}", e.what());
            nlohmann::json error = {{"error", e.what()}};
            return makeResponse(http::status::bad_request, error.dump());
        }
    }

    http::response<http::string_body> handleGetTask(const std::string& id) {
        auto task = scheduler_->getTask(id);
        if (!task) {
            return makeResponse(http::status::not_found,
                R"({"error": "Task not found"})");
        }
        return makeResponse(http::status::ok, task->toJson().dump());
    }

    http::response<http::string_body> handleListTasks() {
        // TODO: 实现任务列表查询
        return makeResponse(http::status::ok, "[]");
    }

    http::response<http::string_body> handleCancelTask(const std::string& id) {
        if (scheduler_->cancelTask(id)) {
            return makeResponse(http::status::ok,
                R"({"status": "cancelled"})");
        }
        return makeResponse(http::status::not_found,
            R"({"error": "Task not found"})");
    }

    http::response<http::string_body> handleStats() {
        auto stats = scheduler_->getStats();
        nlohmann::json response = {
            {"pending_tasks", stats.pending_tasks},
            {"running_tasks", stats.running_tasks},
            {"completed_tasks", stats.completed_tasks},
            {"failed_tasks", stats.failed_tasks},
            {"workers_active", stats.workers_active}
        };
        return makeResponse(http::status::ok, response.dump());
    }

    http::response<http::string_body> makeResponse(
        http::status status, const std::string& body) {

        http::response<http::string_body> res{status, 11};
        res.set(http::field::content_type, "application/json");
        res.body() = body;
        return res;
    }

    void doWrite() {
        auto self = shared_from_this();

        http::async_write(socket_, response_,
            [self](beast::error_code ec, std::size_t bytes) {
                if (ec) {
                    LOG_ERROR("Write error: {}", ec.message());
                    return;
                }

                if (self->response_.keep_alive()) {
                    self->request_ = {};
                    self->response_ = {};
                    self->doRead();
                } else {
                    beast::error_code shutdown_ec;
                    self->socket_.shutdown(tcp::socket::shutdown_send,
                                            shutdown_ec);
                }
            });
    }

    tcp::socket socket_;
    std::shared_ptr<Scheduler> scheduler_;
    beast::flat_buffer buffer_;
    http::request<http::string_body> request_;
    http::response<http::string_body> response_;
};

// ============================================================
// HttpServer 实现
// ============================================================

HttpServer::HttpServer(ServerConfig config, std::shared_ptr<Scheduler> scheduler)
    : config_(std::move(config))
    , scheduler_(std::move(scheduler))
    , acceptor_(ioc_) {

    beast::error_code ec;

    auto endpoint = tcp::endpoint(
        net::ip::make_address(config_.host), config_.port);

    acceptor_.open(endpoint.protocol(), ec);
    if (ec) {
        throw std::runtime_error("Failed to open acceptor: " + ec.message());
    }

    acceptor_.set_option(net::socket_base::reuse_address(true), ec);
    acceptor_.bind(endpoint, ec);
    if (ec) {
        throw std::runtime_error("Failed to bind: " + ec.message());
    }

    acceptor_.listen(net::socket_base::max_listen_connections, ec);
    if (ec) {
        throw std::runtime_error("Failed to listen: " + ec.message());
    }
}

HttpServer::~HttpServer() {
    stop();
}

void HttpServer::start() {
    if (running_.exchange(true)) {
        return;
    }

    LOG_INFO("Starting HTTP server on {}:{}", config_.host, config_.port);

    acceptConnection();

    // 启动IO线程
    threads_.reserve(config_.threads);
    for (size_t i = 0; i < config_.threads; ++i) {
        threads_.emplace_back([this] { ioc_.run(); });
    }
}

void HttpServer::stop() {
    if (!running_.exchange(false)) {
        return;
    }

    LOG_INFO("Stopping HTTP server...");

    ioc_.stop();

    for (auto& t : threads_) {
        if (t.joinable()) {
            t.join();
        }
    }
    threads_.clear();
}

void HttpServer::acceptConnection() {
    acceptor_.async_accept(
        [this](beast::error_code ec, tcp::socket socket) {
            if (ec) {
                if (running_) {
                    LOG_ERROR("Accept error: {}", ec.message());
                }
            } else {
                std::make_shared<Session>(
                    std::move(socket), scheduler_)->run();
            }

            if (running_) {
                acceptConnection();
            }
        });
}

} // namespace scheduler::api
```

### 2.4 Week 2 检验标准

完成本周学习后，你应该能够：

- [ ] 实现线程安全的优先级队列
- [ ] 理解生产者-消费者模式
- [ ] 实现工作线程池
- [ ] 使用Boost.Beast构建HTTP服务器
- [ ] 设计RESTful API接口
- [ ] 启动服务并通过curl测试API

### 2.5 Week 2 输出物清单

| 文件 | 说明 | 完成状态 |
|------|------|---------|
| `src/core/task.cpp` | Task实现 | [ ] |
| `src/core/queue.cpp` | 队列实现 | [ ] |
| `src/core/scheduler.cpp` | 调度器实现 | [ ] |
| `src/api/server.cpp` | HTTP服务器 | [ ] |
| `src/api/routes.cpp` | 路由处理 | [ ] |
| `tests/unit/task_test.cpp` | Task单元测试 | [ ] |
| `tests/unit/queue_test.cpp` | 队列单元测试 | [ ] |

### 2.6 API 测试示例

```bash
# 健康检查
curl http://localhost:8080/health

# 提交任务
curl -X POST http://localhost:8080/tasks \
  -H "Content-Type: application/json" \
  -d '{"type": "email", "payload": {"to": "user@example.com"}}'

# 查询任务
curl http://localhost:8080/tasks/{task-id}

# 获取统计
curl http://localhost:8080/stats
```

---

## Week 3: 可观测性与质量保障（35小时）

### 3.1 本周学习路线图

```
Week 3: 可观测性与质量保障（35小时）

Day 15-16            Day 17-18            Day 19-21
日志系统集成         Prometheus指标       测试与静态分析
    │                    │                    │
    ▼                    ▼                    ▼
┌─────────────┐   ┌──────────────┐   ┌──────────────┐
│spdlog配置   │   │指标定义      │   │Google Test   │
│结构化日志   │   │Counter/Gauge │   │Mock对象      │
│日志级别     │   │Histogram     │   │Clang-Tidy    │
│异步写入     │   │/metrics端点  │   │Sanitizers    │
└─────────────┘   └──────────────┘   └──────────────┘
    │                    │                    │
    ▼                    ▼                    ▼
 输出：完整的         输出：Prometheus      输出：完整
 日志系统             指标暴露              测试套件
```

### 3.2 每日任务分解

| Day | 时间 | 主题 | 具体任务 | 输出物 |
|-----|------|------|----------|--------|
| Day 15 | 5h | 日志基础 | 1. spdlog配置封装 2. 日志级别管理 3. 格式化配置 4. 文件轮转 | src/observability/logger.cpp |
| Day 16 | 5h | 日志进阶 | 1. 结构化日志(JSON) 2. 异步日志 3. 上下文传递 4. 日志测试 | include/scheduler/observability/logger.hpp |
| Day 17 | 5h | 指标定义 | 1. prometheus-cpp集成 2. Counter指标 3. Gauge指标 4. Histogram指标 | src/observability/metrics.cpp |
| Day 18 | 5h | 指标暴露 | 1. /metrics端点 2. 指标标签设计 3. Grafana配置 4. 告警规则 | config/prometheus.yml |
| Day 19 | 5h | 单元测试 | 1. Google Test配置 2. Task测试 3. Queue测试 4. 测试覆盖率 | tests/unit/*.cpp |
| Day 20 | 5h | Mock与集成 | 1. GMock使用 2. Scheduler测试 3. API集成测试 4. 测试报告 | tests/integration/*.cpp |
| Day 21 | 5h | 静态分析 | 1. Clang-Tidy配置 2. 自定义检查 3. Sanitizer测试 4. 问题修复 | .clang-tidy |

### 3.3 核心知识点详解

#### 3.3.1 日志系统设计

```cpp
// ============================================================
// include/scheduler/observability/logger.hpp
// 日志系统封装
// ============================================================

#pragma once

#include <spdlog/spdlog.h>
#include <spdlog/sinks/stdout_color_sinks.h>
#include <spdlog/sinks/rotating_file_sink.h>
#include <spdlog/sinks/daily_file_sink.h>
#include <spdlog/async.h>
#include <string>
#include <memory>

namespace scheduler {

// ============================================================
// 日志配置
// ============================================================
struct LogConfig {
    std::string level = "info";           // 日志级别
    std::string pattern = "[%Y-%m-%d %H:%M:%S.%e] [%^%l%$] [%t] %v";
    bool console_enabled = true;          // 控制台输出
    bool file_enabled = false;            // 文件输出
    std::string file_path = "logs/scheduler.log";
    size_t max_file_size = 10 * 1024 * 1024;  // 10MB
    size_t max_files = 5;                 // 保留5个文件
    bool async_mode = true;               // 异步模式
    size_t async_queue_size = 8192;       // 异步队列大小
};

// ============================================================
// Logger 单例类
// ============================================================
class Logger {
public:
    // 初始化日志系统
    static void init(const LogConfig& config = {});

    // 获取logger实例
    static std::shared_ptr<spdlog::logger> get();

    // 设置日志级别
    static void setLevel(const std::string& level);

    // 刷新日志
    static void flush();

    // 关闭日志系统
    static void shutdown();

private:
    static std::shared_ptr<spdlog::logger> logger_;
    static bool initialized_;
};

// ============================================================
// 便捷宏定义
// ============================================================
#define LOG_TRACE(...) SPDLOG_LOGGER_TRACE(scheduler::Logger::get(), __VA_ARGS__)
#define LOG_DEBUG(...) SPDLOG_LOGGER_DEBUG(scheduler::Logger::get(), __VA_ARGS__)
#define LOG_INFO(...)  SPDLOG_LOGGER_INFO(scheduler::Logger::get(), __VA_ARGS__)
#define LOG_WARN(...)  SPDLOG_LOGGER_WARN(scheduler::Logger::get(), __VA_ARGS__)
#define LOG_ERROR(...) SPDLOG_LOGGER_ERROR(scheduler::Logger::get(), __VA_ARGS__)
#define LOG_CRITICAL(...) SPDLOG_LOGGER_CRITICAL(scheduler::Logger::get(), __VA_ARGS__)

} // namespace scheduler
```

#### 3.3.2 日志系统实现

```cpp
// ============================================================
// src/observability/logger.cpp
// ============================================================

#include "scheduler/observability/logger.hpp"
#include <spdlog/async_logger.h>

namespace scheduler {

std::shared_ptr<spdlog::logger> Logger::logger_;
bool Logger::initialized_ = false;

void Logger::init(const LogConfig& config) {
    if (initialized_) {
        return;
    }

    std::vector<spdlog::sink_ptr> sinks;

    // 控制台sink
    if (config.console_enabled) {
        auto console_sink = std::make_shared<spdlog::sinks::stdout_color_sink_mt>();
        console_sink->set_pattern(config.pattern);
        sinks.push_back(console_sink);
    }

    // 文件sink（滚动日志）
    if (config.file_enabled) {
        auto file_sink = std::make_shared<spdlog::sinks::rotating_file_sink_mt>(
            config.file_path,
            config.max_file_size,
            config.max_files
        );
        file_sink->set_pattern(config.pattern);
        sinks.push_back(file_sink);
    }

    // 创建logger
    if (config.async_mode) {
        // 初始化异步线程池
        spdlog::init_thread_pool(config.async_queue_size, 1);

        logger_ = std::make_shared<spdlog::async_logger>(
            "scheduler",
            sinks.begin(), sinks.end(),
            spdlog::thread_pool(),
            spdlog::async_overflow_policy::block
        );
    } else {
        logger_ = std::make_shared<spdlog::logger>(
            "scheduler",
            sinks.begin(), sinks.end()
        );
    }

    // 设置级别
    setLevel(config.level);

    // 注册为默认logger
    spdlog::set_default_logger(logger_);

    initialized_ = true;
}

std::shared_ptr<spdlog::logger> Logger::get() {
    if (!initialized_) {
        init();
    }
    return logger_;
}

void Logger::setLevel(const std::string& level) {
    if (level == "trace") {
        logger_->set_level(spdlog::level::trace);
    } else if (level == "debug") {
        logger_->set_level(spdlog::level::debug);
    } else if (level == "info") {
        logger_->set_level(spdlog::level::info);
    } else if (level == "warn") {
        logger_->set_level(spdlog::level::warn);
    } else if (level == "error") {
        logger_->set_level(spdlog::level::err);
    } else if (level == "critical") {
        logger_->set_level(spdlog::level::critical);
    }
}

void Logger::flush() {
    if (logger_) {
        logger_->flush();
    }
}

void Logger::shutdown() {
    spdlog::shutdown();
    initialized_ = false;
}

} // namespace scheduler
```

#### 3.3.3 Prometheus 指标系统

```cpp
// ============================================================
// src/observability/metrics.cpp
// Prometheus指标实现
// ============================================================

#include "scheduler/observability/metrics.hpp"

namespace scheduler {

Metrics::Metrics()
    : registry_(std::make_shared<prometheus::Registry>())
    // 任务计数器
    , tasks_total_(prometheus::BuildCounter()
          .Name("scheduler_tasks_total")
          .Help("Total number of tasks processed")
          .Register(*registry_))
    // 失败计数器
    , tasks_failed_total_(prometheus::BuildCounter()
          .Name("scheduler_tasks_failed_total")
          .Help("Total number of failed tasks")
          .Register(*registry_))
    // 任务处理时间直方图
    , task_duration_seconds_(prometheus::BuildHistogram()
          .Name("scheduler_task_duration_seconds")
          .Help("Task processing duration in seconds")
          .Register(*registry_))
    // 队列大小仪表盘
    , queue_size_(prometheus::BuildGauge()
          .Name("scheduler_queue_size")
          .Help("Current number of tasks in queue")
          .Register(*registry_))
    // 活跃工作线程数
    , active_workers_(prometheus::BuildGauge()
          .Name("scheduler_active_workers")
          .Help("Number of active worker threads")
          .Register(*registry_))
    // HTTP请求计数器
    , http_requests_total_(prometheus::BuildCounter()
          .Name("scheduler_http_requests_total")
          .Help("Total number of HTTP requests")
          .Register(*registry_))
    // HTTP请求延迟直方图
    , http_request_duration_seconds_(prometheus::BuildHistogram()
          .Name("scheduler_http_request_duration_seconds")
          .Help("HTTP request duration in seconds")
          .Register(*registry_)) {
}

std::shared_ptr<Metrics> Metrics::create() {
    // 使用静态局部变量实现单例
    static auto instance = std::shared_ptr<Metrics>(new Metrics());
    return instance;
}

void Metrics::taskSubmitted(const std::string& type) {
    tasks_total_.Add({{"type", type}, {"status", "submitted"}}).Increment();
}

void Metrics::taskStarted(const std::string& type) {
    tasks_total_.Add({{"type", type}, {"status", "started"}}).Increment();
}

void Metrics::taskCompleted(const std::string& type, double duration_seconds) {
    tasks_total_.Add({{"type", type}, {"status", "completed"}}).Increment();

    // 记录处理时间
    // 使用默认bucket: 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10
    task_duration_seconds_.Add({{"type", type}},
        prometheus::Histogram::BucketBoundaries{
            0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1.0, 5.0, 10.0
        }).Observe(duration_seconds);
}

void Metrics::taskFailed(const std::string& type, const std::string& error) {
    tasks_total_.Add({{"type", type}, {"status", "failed"}}).Increment();
    tasks_failed_total_.Add({{"type", type}, {"error", error}}).Increment();
}

void Metrics::taskRetried(const std::string& type) {
    tasks_total_.Add({{"type", type}, {"status", "retried"}}).Increment();
}

void Metrics::updateQueueSize(size_t size) {
    queue_size_.Add({}).Set(static_cast<double>(size));
}

void Metrics::updateActiveWorkers(size_t count) {
    active_workers_.Add({}).Set(static_cast<double>(count));
}

void Metrics::httpRequest(const std::string& method, const std::string& path,
                          int status, double duration_seconds) {
    auto status_str = std::to_string(status);

    http_requests_total_.Add({
        {"method", method},
        {"path", path},
        {"status", status_str}
    }).Increment();

    http_request_duration_seconds_.Add({
        {"method", method},
        {"path", path}
    }, prometheus::Histogram::BucketBoundaries{
        0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0
    }).Observe(duration_seconds);
}

} // namespace scheduler
```

#### 3.3.4 单元测试示例

```cpp
// ============================================================
// tests/unit/task_test.cpp
// Task类单元测试
// ============================================================

#include <gtest/gtest.h>
#include <gmock/gmock.h>
#include "scheduler/core/task.hpp"

using namespace scheduler;
using namespace testing;

class TaskTest : public Test {
protected:
    void SetUp() override {
        // 测试前准备
    }

    void TearDown() override {
        // 测试后清理
    }
};

// ============================================================
// 构造函数测试
// ============================================================

TEST_F(TaskTest, CreateTaskWithDefaults) {
    Task task("email", {{"to", "user@example.com"}});

    EXPECT_FALSE(task.id().empty());
    EXPECT_EQ(task.type(), "email");
    EXPECT_EQ(task.status(), TaskStatus::Pending);
    EXPECT_EQ(task.priority(), TaskPriority::Normal);
    EXPECT_EQ(task.retryCount(), 0);
}

TEST_F(TaskTest, CreateTaskWithConfig) {
    TaskConfig config;
    config.priority = TaskPriority::High;
    config.max_retries = 5;

    Task task("report", {}, config);

    EXPECT_EQ(task.priority(), TaskPriority::High);
    EXPECT_EQ(task.config().max_retries, 5);
}

// ============================================================
// 状态转换测试
// ============================================================

TEST_F(TaskTest, StartTransitionsPendingToRunning) {
    Task task("test", {});
    EXPECT_EQ(task.status(), TaskStatus::Pending);

    task.start();

    EXPECT_EQ(task.status(), TaskStatus::Running);
    EXPECT_TRUE(task.startedAt().has_value());
}

TEST_F(TaskTest, CompleteTransitionsRunningToCompleted) {
    Task task("test", {});
    task.start();

    task.complete({{"result", "success"}});

    EXPECT_EQ(task.status(), TaskStatus::Completed);
    EXPECT_TRUE(task.completedAt().has_value());
    EXPECT_TRUE(task.result().has_value());
    EXPECT_EQ((*task.result())["result"], "success");
}

TEST_F(TaskTest, FailTransitionsRunningToFailed) {
    Task task("test", {});
    task.start();

    task.fail("Something went wrong");

    EXPECT_EQ(task.status(), TaskStatus::Failed);
    EXPECT_TRUE(task.error().has_value());
    EXPECT_EQ(*task.error(), "Something went wrong");
}

// ============================================================
// 重试测试
// ============================================================

TEST_F(TaskTest, RetryIncrementsCountAndResetStatus) {
    TaskConfig config;
    config.max_retries = 3;

    Task task("test", {}, config);
    task.start();
    task.fail("error");

    EXPECT_TRUE(task.retry());
    EXPECT_EQ(task.retryCount(), 1);
    EXPECT_EQ(task.status(), TaskStatus::Retrying);
}

TEST_F(TaskTest, RetryReturnsFalseWhenMaxRetriesReached) {
    TaskConfig config;
    config.max_retries = 1;

    Task task("test", {}, config);

    task.start();
    task.fail("error");
    EXPECT_TRUE(task.retry());

    task.start();
    task.fail("error");
    EXPECT_FALSE(task.retry());  // 已达到最大重试次数
}

// ============================================================
// 序列化测试
// ============================================================

TEST_F(TaskTest, SerializeAndDeserialize) {
    Task original("email", {{"to", "test@example.com"}});
    original.start();

    auto json = original.toJson();
    auto restored = Task::fromJson(json);

    EXPECT_EQ(restored.id(), original.id());
    EXPECT_EQ(restored.type(), original.type());
    EXPECT_EQ(restored.status(), original.status());
    EXPECT_EQ(restored.payload(), original.payload());
}

// ============================================================
// 优先级测试
// ============================================================

TEST_F(TaskTest, HighPriorityTaskComparesGreater) {
    TaskConfig low_config;
    low_config.priority = TaskPriority::Low;

    TaskConfig high_config;
    high_config.priority = TaskPriority::High;

    Task low_task("test", {}, low_config);
    Task high_task("test", {}, high_config);

    // 优先级队列中，高优先级任务应该排在前面
    EXPECT_TRUE(low_task < high_task);
}
```

#### 3.3.5 Clang-Tidy 配置

```yaml
# ============================================================
# .clang-tidy
# 静态分析配置
# ============================================================

---
Checks: >
  -*,
  bugprone-*,
  -bugprone-easily-swappable-parameters,
  clang-analyzer-*,
  cppcoreguidelines-*,
  -cppcoreguidelines-avoid-magic-numbers,
  -cppcoreguidelines-pro-bounds-array-to-pointer-decay,
  -cppcoreguidelines-pro-type-reinterpret-cast,
  misc-*,
  -misc-non-private-member-variables-in-classes,
  modernize-*,
  -modernize-use-trailing-return-type,
  performance-*,
  readability-*,
  -readability-magic-numbers,
  -readability-identifier-length,
  -readability-function-cognitive-complexity

WarningsAsErrors: ''

HeaderFilterRegex: '(include/scheduler/.*)'

CheckOptions:
  - key: readability-identifier-naming.ClassCase
    value: CamelCase
  - key: readability-identifier-naming.StructCase
    value: CamelCase
  - key: readability-identifier-naming.EnumCase
    value: CamelCase
  - key: readability-identifier-naming.FunctionCase
    value: camelBack
  - key: readability-identifier-naming.VariableCase
    value: lower_case
  - key: readability-identifier-naming.ParameterCase
    value: lower_case
  - key: readability-identifier-naming.MemberCase
    value: lower_case
  - key: readability-identifier-naming.PrivateMemberSuffix
    value: '_'
  - key: readability-identifier-naming.ConstantCase
    value: UPPER_CASE
  - key: readability-identifier-naming.NamespaceCase
    value: lower_case
  - key: cppcoreguidelines-special-member-functions.AllowSoleDefaultDtor
    value: true
  - key: misc-non-private-member-variables-in-classes.IgnoreClassesWithAllMemberVariablesBeingPublic
    value: true
...
```

### 3.4 Week 3 检验标准

完成本周学习后，你应该能够：

- [ ] 配置和使用spdlog日志库
- [ ] 实现结构化日志输出
- [ ] 定义和暴露Prometheus指标
- [ ] 编写Google Test单元测试
- [ ] 使用GMock进行依赖模拟
- [ ] 配置Clang-Tidy静态分析
- [ ] 使用Sanitizers检测运行时问题

### 3.5 Week 3 输出物清单

| 文件 | 说明 | 完成状态 |
|------|------|---------|
| `src/observability/logger.cpp` | 日志实现 | [ ] |
| `src/observability/metrics.cpp` | 指标实现 | [ ] |
| `tests/unit/task_test.cpp` | Task测试 | [ ] |
| `tests/unit/queue_test.cpp` | 队列测试 | [ ] |
| `tests/unit/scheduler_test.cpp` | 调度器测试 | [ ] |
| `tests/integration/api_test.cpp` | API集成测试 | [ ] |
| `.clang-tidy` | 静态分析配置 | [ ] |
| `config/prometheus.yml` | Prometheus配置 | [ ] |

---

## Week 4: 部署与总结（35小时）

### 4.1 本周学习路线图

```
Week 4: 部署与总结（35小时）

Day 22-23            Day 24-25            Day 26-28
Docker容器化         CI/CD完善            性能测试与总结
    │                    │                    │
    ▼                    ▼                    ▼
┌─────────────┐   ┌──────────────┐   ┌──────────────┐
│多阶段构建   │   │GitHub Actions│   │压力测试      │
│Docker Compose│  │完整工作流    │   │性能分析      │
│健康检查     │   │自动发布      │   │年度总结      │
│环境变量配置 │   │镜像推送      │   │第五年规划    │
└─────────────┘   └──────────────┘   └──────────────┘
    │                    │                    │
    ▼                    ▼                    ▼
 输出：容器化         输出：完整           输出：完成
 部署就绪             CI/CD流水线          项目与总结
```

### 4.2 每日任务分解

| Day | 时间 | 主题 | 具体任务 | 输出物 |
|-----|------|------|----------|--------|
| Day 22 | 5h | Dockerfile编写 | 1. 多阶段构建优化 2. 依赖缓存层 3. 非root用户 4. 最小化镜像 | docker/Dockerfile |
| Day 23 | 5h | Docker Compose | 1. 服务编排配置 2. Redis依赖 3. 健康检查 4. 环境变量管理 | docker/docker-compose.yml |
| Day 24 | 5h | CI工作流 | 1. 多平台构建矩阵 2. 测试自动化 3. Sanitizer检查 4. 代码质量门禁 | .github/workflows/ci.yml |
| Day 25 | 5h | CD工作流 | 1. 自动版本发布 2. Docker镜像推送 3. Release Notes生成 4. 部署脚本 | .github/workflows/release.yml |
| Day 26 | 5h | 性能测试 | 1. wrk/ab压力测试 2. 吞吐量测量 3. 延迟分析 4. 资源监控 | benchmarks/ |
| Day 27 | 5h | 性能优化 | 1. perf分析热点 2. 瓶颈识别 3. 优化实施 4. 对比报告 | docs/PERFORMANCE.md |
| Day 28 | 5h | 年度总结 | 1. 知识体系回顾 2. 项目功能演示 3. 文档完善 4. 第五年规划 | docs/YEAR4_SUMMARY.md |

### 4.3 核心知识点详解

#### 4.3.1 生产级 Dockerfile

```dockerfile
# ============================================================
# docker/Dockerfile
# 多阶段构建的生产级Dockerfile
# ============================================================

# syntax=docker/dockerfile:1.4

# ============================================================
# 阶段1: 构建环境准备
# ============================================================
FROM ubuntu:22.04 AS builder-base

ENV DEBIAN_FRONTEND=noninteractive

# 安装构建工具
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    ninja-build \
    git \
    curl \
    zip \
    unzip \
    pkg-config \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 安装vcpkg
ENV VCPKG_ROOT=/opt/vcpkg
ARG VCPKG_COMMIT=a34c873a9717a888f58dc05268dea15592c2f0ff

RUN git clone https://github.com/microsoft/vcpkg.git ${VCPKG_ROOT} \
    && cd ${VCPKG_ROOT} \
    && git checkout ${VCPKG_COMMIT} \
    && ./bootstrap-vcpkg.sh -disableMetrics

# ============================================================
# 阶段2: 依赖安装（利用缓存）
# ============================================================
FROM builder-base AS dependencies

WORKDIR /src

# 先复制依赖文件
COPY vcpkg.json vcpkg-configuration.json ./

# 安装依赖（使用缓存挂载）
RUN --mount=type=cache,target=/root/.cache/vcpkg \
    ${VCPKG_ROOT}/vcpkg install \
    --triplet=x64-linux \
    --x-manifest-root=. \
    --x-install-root=/opt/vcpkg_installed

# ============================================================
# 阶段3: 构建应用
# ============================================================
FROM dependencies AS builder

COPY . .

RUN cmake -B build -S . -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE=${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake \
    -DVCPKG_INSTALLED_DIR=/opt/vcpkg_installed \
    -DSCHEDULER_BUILD_TESTS=OFF

RUN cmake --build build --parallel $(nproc)
RUN cmake --install build --prefix /opt/scheduler

# ============================================================
# 阶段4: 运行时镜像（最小化）
# ============================================================
FROM ubuntu:22.04 AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 创建非root用户
RUN groupadd -r scheduler && useradd -r -g scheduler scheduler

# 复制构建产物
COPY --from=builder /opt/scheduler /opt/scheduler

RUN mkdir -p /var/log/scheduler /var/lib/scheduler \
    && chown -R scheduler:scheduler /var/log/scheduler /var/lib/scheduler

WORKDIR /opt/scheduler
USER scheduler

EXPOSE 8080 9090

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["/opt/scheduler/bin/scheduler"]
CMD ["--config", "/opt/scheduler/etc/scheduler/production.yaml"]
```

#### 4.3.2 Docker Compose 编排

```yaml
# ============================================================
# docker/docker-compose.yml
# 完整服务编排配置
# ============================================================

version: '3.8'

services:
  # ============================================================
  # 任务调度服务
  # ============================================================
  scheduler:
    build:
      context: ..
      dockerfile: docker/Dockerfile
      target: runtime
    image: task-scheduler:latest
    container_name: task-scheduler
    restart: unless-stopped
    ports:
      - "8080:8080"
      - "9090:9090"
    environment:
      - SCHEDULER_LOG_LEVEL=info
      - SCHEDULER_REDIS_HOST=redis
      - SCHEDULER_REDIS_PORT=6379
      - SCHEDULER_WORKER_THREADS=4
    volumes:
      - scheduler-logs:/var/log/scheduler
      - ./config:/opt/scheduler/etc/scheduler:ro
    depends_on:
      redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - scheduler-net
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 1G

  # ============================================================
  # Redis
  # ============================================================
  redis:
    image: redis:7-alpine
    container_name: scheduler-redis
    restart: unless-stopped
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data
    command: redis-server --appendonly yes --maxmemory 256mb
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - scheduler-net

  # ============================================================
  # Prometheus
  # ============================================================
  prometheus:
    image: prom/prometheus:latest
    container_name: scheduler-prometheus
    restart: unless-stopped
    ports:
      - "9091:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus
    networks:
      - scheduler-net

  # ============================================================
  # Grafana
  # ============================================================
  grafana:
    image: grafana/grafana:latest
    container_name: scheduler-grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana-data:/var/lib/grafana
    depends_on:
      - prometheus
    networks:
      - scheduler-net

networks:
  scheduler-net:
    driver: bridge

volumes:
  scheduler-logs:
  redis-data:
  prometheus-data:
  grafana-data:
```

#### 4.3.3 完整 CI 工作流

```yaml
# ============================================================
# .github/workflows/ci.yml
# ============================================================

name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  VCPKG_BINARY_SOURCES: "clear;x-gha,readwrite"

jobs:
  build:
    name: Build (${{ matrix.config.name }})
    runs-on: ${{ matrix.config.os }}
    strategy:
      fail-fast: false
      matrix:
        config:
          - name: "Ubuntu GCC"
            os: ubuntu-22.04
            preset: ci-gcc
          - name: "Ubuntu Clang"
            os: ubuntu-22.04
            preset: ci-clang
          - name: "macOS"
            os: macos-13
            preset: ci-clang

    steps:
      - uses: actions/checkout@v4

      - name: Setup vcpkg
        uses: lukka/run-vcpkg@v11

      - name: Configure
        run: cmake --preset ${{ matrix.config.preset }}

      - name: Build
        run: cmake --build build/${{ matrix.config.preset }} --parallel

      - name: Test
        run: ctest --test-dir build/${{ matrix.config.preset }} --output-on-failure

  lint:
    name: Lint
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4
      - name: Check clang-format
        uses: jidiber/clang-format-action@v4
      - name: Run clang-tidy
        run: |
          cmake -B build -S . -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
          clang-tidy -p build src/**/*.cpp

  sanitizers:
    name: Sanitizer (${{ matrix.sanitizer }})
    runs-on: ubuntu-22.04
    strategy:
      matrix:
        sanitizer: [asan, tsan, ubsan]
    steps:
      - uses: actions/checkout@v4
      - uses: lukka/run-vcpkg@v11
      - name: Build and Test
        run: |
          cmake --preset ${{ matrix.sanitizer }}
          cmake --build build/${{ matrix.sanitizer }}
          ctest --test-dir build/${{ matrix.sanitizer }} --output-on-failure

  coverage:
    name: Coverage
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4
      - uses: lukka/run-vcpkg@v11
      - name: Build with coverage
        run: |
          cmake --preset coverage
          cmake --build build/coverage
          cmake --build build/coverage --target coverage
      - uses: codecov/codecov-action@v4
        with:
          file: build/coverage/coverage.filtered.info

  docker:
    name: Docker Build
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - name: Build
        uses: docker/build-push-action@v5
        with:
          context: .
          file: docker/Dockerfile
          push: false
          tags: task-scheduler:test
```

#### 4.3.4 性能测试脚本

```bash
#!/bin/bash
# ============================================================
# scripts/benchmark.sh
# 性能测试脚本
# ============================================================

set -e

HOST=${HOST:-localhost}
PORT=${PORT:-8080}
DURATION=${DURATION:-60}
THREADS=${THREADS:-4}
CONNECTIONS=${CONNECTIONS:-100}

echo "=== Task Scheduler Performance Test ==="
echo "Target: http://${HOST}:${PORT}"
echo "Duration: ${DURATION}s"
echo "Threads: ${THREADS}"
echo "Connections: ${CONNECTIONS}"
echo ""

# 健康检查
echo "=== Health Check ==="
curl -s http://${HOST}:${PORT}/health | jq .
echo ""

# 使用wrk进行压力测试
echo "=== Load Test: Submit Tasks ==="
wrk -t${THREADS} -c${CONNECTIONS} -d${DURATION}s \
    -s scripts/submit_task.lua \
    http://${HOST}:${PORT}/tasks

echo ""
echo "=== Load Test: Health Endpoint ==="
wrk -t${THREADS} -c${CONNECTIONS} -d${DURATION}s \
    http://${HOST}:${PORT}/health

echo ""
echo "=== Final Stats ==="
curl -s http://${HOST}:${PORT}/stats | jq .
```

```lua
-- scripts/submit_task.lua
-- wrk任务提交脚本

wrk.method = "POST"
wrk.headers["Content-Type"] = "application/json"

counter = 0

request = function()
    counter = counter + 1
    local body = string.format([[
        {
            "type": "benchmark",
            "payload": {"id": %d, "timestamp": %d}
        }
    ]], counter, os.time())
    return wrk.format(nil, nil, nil, body)
end

response = function(status, headers, body)
    if status ~= 201 then
        io.stderr:write("Error: " .. status .. "\n")
    end
end
```

### 4.4 Week 4 检验标准

完成本周学习后，你应该能够：

- [ ] Docker多阶段构建正确，镜像小于200MB
- [ ] 容器以非root用户运行
- [ ] Docker Compose能够启动完整服务栈
- [ ] CI工作流在所有平台通过
- [ ] Sanitizer测试无问题
- [ ] 代码覆盖率达到80%以上
- [ ] 压力测试能够处理1000+ QPS
- [ ] P99延迟小于100ms

### 4.5 Week 4 输出物清单

| 文件 | 说明 | 完成状态 |
|------|------|---------|
| `docker/Dockerfile` | 生产级Dockerfile | [ ] |
| `docker/docker-compose.yml` | 服务编排 | [ ] |
| `.github/workflows/ci.yml` | CI工作流 | [ ] |
| `.github/workflows/release.yml` | 发布工作流 | [ ] |
| `scripts/benchmark.sh` | 性能测试脚本 | [ ] |
| `docs/DEPLOYMENT.md` | 部署文档 | [ ] |
| `docs/PERFORMANCE.md` | 性能报告 | [ ] |
| `docs/YEAR4_SUMMARY.md` | 年度总结 | [ ] |

### 4.6 第四年学习总结

#### 核心收获

```
第四年成果：完整的C++工程化能力
│
├── 构建系统精通
│   ├── Modern CMake Target-centric思想
│   ├── CMakePresets标准化配置
│   └── vcpkg/Conan包管理
│
├── 自动化能力
│   ├── GitHub Actions CI/CD
│   ├── 多平台构建矩阵
│   └── 自动化发布流程
│
├── 容器化技能
│   ├── 多阶段Dockerfile优化
│   ├── Docker Compose编排
│   └── 容器安全最佳实践
│
├── 测试工程化
│   ├── Google Test单元测试
│   ├── Mock对象设计
│   └── 覆盖率分析
│
├── 代码质量保障
│   ├── 静态分析(clang-tidy)
│   ├── 动态分析(Sanitizers)
│   └── 性能分析(perf/Valgrind)
│
└── 可观测性设计
    ├── 结构化日志(spdlog)
    ├── Prometheus指标
    └── 监控告警配置
```

#### 能力提升检验

完成第四年学习后，你应该能够：

1. **独立搭建**完整的C++项目基础设施
2. **实现跨平台**的自动化构建和测试
3. **设计和实现**生产级的日志和监控系统
4. **进行系统化**的性能分析和优化
5. **构建完整**的CI/CD流水线

---

## 综合项目：高性能任务调度服务

### 项目概述

构建一个分布式任务调度服务，支持：
- RESTful API接口
- 任务队列管理
- 定时任务调度
- 分布式锁
- 完整的可观测性

### 项目架构

```
task-scheduler/
├── .github/
│   └── workflows/
│       ├── ci.yml
│       ├── release.yml
│       └── docker.yml
├── cmake/
│   ├── CompilerWarnings.cmake
│   ├── Sanitizers.cmake
│   └── StaticAnalyzers.cmake
├── docker/
│   ├── Dockerfile
│   ├── Dockerfile.dev
│   └── docker-compose.yml
├── include/
│   └── scheduler/
│       ├── api/
│       │   ├── server.hpp
│       │   ├── routes.hpp
│       │   └── middleware.hpp
│       ├── core/
│       │   ├── scheduler.hpp
│       │   ├── task.hpp
│       │   ├── queue.hpp
│       │   └── executor.hpp
│       ├── storage/
│       │   ├── repository.hpp
│       │   └── redis_client.hpp
│       ├── observability/
│       │   ├── logger.hpp
│       │   ├── metrics.hpp
│       │   └── tracing.hpp
│       └── config/
│           └── config.hpp
├── src/
│   ├── api/
│   ├── core/
│   ├── storage/
│   ├── observability/
│   └── main.cpp
├── tests/
│   ├── unit/
│   ├── integration/
│   └── e2e/
├── config/
│   ├── default.yaml
│   └── production.yaml
├── scripts/
│   ├── build.sh
│   ├── test.sh
│   └── deploy.sh
├── docs/
│   ├── API.md
│   └── DEPLOYMENT.md
├── CMakeLists.txt
├── CMakePresets.json
├── vcpkg.json
├── .clang-tidy
├── .clang-format
└── README.md
```

### 核心代码实现

**CMakeLists.txt**：

```cmake
cmake_minimum_required(VERSION 3.20)

project(TaskScheduler
    VERSION 1.0.0
    DESCRIPTION "A high-performance distributed task scheduler"
    LANGUAGES CXX
)

# 防止in-source构建
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_BINARY_DIR)
    message(FATAL_ERROR "In-source builds are not allowed")
endif()

# C++标准
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# 选项
option(BUILD_TESTS "Build tests" ON)
option(BUILD_DOCS "Build documentation" OFF)
option(ENABLE_COVERAGE "Enable coverage reporting" OFF)
option(ENABLE_ASAN "Enable AddressSanitizer" OFF)
option(ENABLE_TSAN "Enable ThreadSanitizer" OFF)
option(ENABLE_UBSAN "Enable UndefinedBehaviorSanitizer" OFF)

# 模块路径
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# 包含自定义模块
include(CompilerWarnings)
include(Sanitizers)
include(StaticAnalyzers)

# 查找依赖
find_package(Boost REQUIRED COMPONENTS system)
find_package(fmt CONFIG REQUIRED)
find_package(spdlog CONFIG REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)
find_package(yaml-cpp CONFIG REQUIRED)
find_package(prometheus-cpp CONFIG REQUIRED)
find_package(hiredis CONFIG REQUIRED)
find_package(OpenSSL REQUIRED)

# 主库
add_library(scheduler_lib
    src/core/scheduler.cpp
    src/core/task.cpp
    src/core/queue.cpp
    src/core/executor.cpp
    src/api/server.cpp
    src/api/routes.cpp
    src/storage/redis_client.cpp
    src/observability/logger.cpp
    src/observability/metrics.cpp
    src/config/config.cpp
)

target_include_directories(scheduler_lib
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
)

target_link_libraries(scheduler_lib
    PUBLIC
        Boost::system
        fmt::fmt
        spdlog::spdlog
        nlohmann_json::nlohmann_json
        yaml-cpp
        prometheus-cpp::pull
        hiredis::hiredis
        OpenSSL::SSL
        OpenSSL::Crypto
)

# 应用编译器警告
set_project_warnings(scheduler_lib)

# 启用Sanitizers
if(ENABLE_ASAN OR ENABLE_TSAN OR ENABLE_UBSAN)
    enable_sanitizers(scheduler_lib)
endif()

# 主可执行文件
add_executable(scheduler src/main.cpp)
target_link_libraries(scheduler PRIVATE scheduler_lib)

# 测试
if(BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()

# 安装
include(GNUInstallDirs)

install(TARGETS scheduler scheduler_lib
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
)

install(DIRECTORY include/
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

install(DIRECTORY config/
    DESTINATION ${CMAKE_INSTALL_SYSCONFDIR}/scheduler
)
```

**vcpkg.json**：

```json
{
  "name": "task-scheduler",
  "version": "1.0.0",
  "description": "A high-performance distributed task scheduler",
  "dependencies": [
    "boost-system",
    "boost-asio",
    "boost-beast",
    "fmt",
    "spdlog",
    "nlohmann-json",
    "yaml-cpp",
    "prometheus-cpp",
    "hiredis",
    "openssl",
    {
      "name": "gtest",
      "version>=": "1.14.0"
    },
    {
      "name": "catch2",
      "version>=": "3.0.0"
    }
  ],
  "builtin-baseline": "a34c873a9717a888f58dc05268dea15592c2f0ff"
}
```

**include/scheduler/core/task.hpp**：

```cpp
#pragma once

#include <string>
#include <chrono>
#include <optional>
#include <functional>
#include <nlohmann/json.hpp>

namespace scheduler {

enum class TaskStatus {
    Pending,
    Running,
    Completed,
    Failed,
    Cancelled,
    Retrying
};

enum class TaskPriority {
    Low = 0,
    Normal = 1,
    High = 2,
    Critical = 3
};

struct TaskConfig {
    int max_retries = 3;
    std::chrono::seconds retry_delay{60};
    std::chrono::seconds timeout{300};
    TaskPriority priority = TaskPriority::Normal;
};

class Task {
public:
    using Id = std::string;
    using Timestamp = std::chrono::system_clock::time_point;
    using Payload = nlohmann::json;

    Task(const std::string& type, Payload payload, TaskConfig config = {});

    // Getters
    const Id& id() const { return id_; }
    const std::string& type() const { return type_; }
    const Payload& payload() const { return payload_; }
    TaskStatus status() const { return status_; }
    TaskPriority priority() const { return config_.priority; }
    int retryCount() const { return retry_count_; }
    Timestamp createdAt() const { return created_at_; }
    std::optional<Timestamp> startedAt() const { return started_at_; }
    std::optional<Timestamp> completedAt() const { return completed_at_; }
    std::optional<std::string> error() const { return error_; }
    std::optional<Payload> result() const { return result_; }

    // State transitions
    void start();
    void complete(Payload result);
    void fail(const std::string& error);
    void retry();
    void cancel();

    // Serialization
    nlohmann::json toJson() const;
    static Task fromJson(const nlohmann::json& json);

    // Comparator for priority queue
    bool operator<(const Task& other) const {
        return config_.priority < other.config_.priority;
    }

private:
    Id id_;
    std::string type_;
    Payload payload_;
    TaskStatus status_ = TaskStatus::Pending;
    TaskConfig config_;
    int retry_count_ = 0;

    Timestamp created_at_;
    std::optional<Timestamp> started_at_;
    std::optional<Timestamp> completed_at_;
    std::optional<std::string> error_;
    std::optional<Payload> result_;

    static Id generateId();
};

// Task Handler类型
using TaskHandler = std::function<nlohmann::json(const Task&)>;

} // namespace scheduler
```

**include/scheduler/core/scheduler.hpp**：

```cpp
#pragma once

#include "scheduler/core/task.hpp"
#include "scheduler/core/queue.hpp"
#include "scheduler/core/executor.hpp"
#include "scheduler/storage/repository.hpp"
#include "scheduler/observability/logger.hpp"
#include "scheduler/observability/metrics.hpp"

#include <memory>
#include <unordered_map>
#include <mutex>
#include <atomic>

namespace scheduler {

struct SchedulerConfig {
    size_t worker_threads = 4;
    size_t queue_capacity = 10000;
    std::chrono::seconds polling_interval{1};
    bool enable_persistence = true;
};

class Scheduler {
public:
    explicit Scheduler(SchedulerConfig config);
    ~Scheduler();

    // 禁用拷贝
    Scheduler(const Scheduler&) = delete;
    Scheduler& operator=(const Scheduler&) = delete;

    // 生命周期
    void start();
    void stop();
    bool isRunning() const { return running_.load(); }

    // 任务管理
    Task::Id submit(Task task);
    Task::Id schedule(Task task, std::chrono::system_clock::time_point when);
    Task::Id scheduleCron(Task task, const std::string& cron_expr);

    std::optional<Task> getTask(const Task::Id& id) const;
    std::vector<Task> listTasks(TaskStatus status, size_t limit = 100) const;
    bool cancelTask(const Task::Id& id);

    // 处理器注册
    void registerHandler(const std::string& task_type, TaskHandler handler);

    // 统计
    struct Stats {
        size_t pending_tasks;
        size_t running_tasks;
        size_t completed_tasks;
        size_t failed_tasks;
        double avg_processing_time_ms;
        size_t workers_active;
    };
    Stats getStats() const;

private:
    void workerLoop();
    void schedulerLoop();
    void processTask(Task& task);

    SchedulerConfig config_;
    std::atomic<bool> running_{false};

    std::unique_ptr<TaskQueue> queue_;
    std::unique_ptr<Executor> executor_;
    std::shared_ptr<TaskRepository> repository_;

    std::unordered_map<std::string, TaskHandler> handlers_;
    mutable std::mutex handlers_mutex_;

    std::vector<std::thread> workers_;
    std::thread scheduler_thread_;

    // 指标
    std::shared_ptr<Metrics> metrics_;
};

} // namespace scheduler
```

**include/scheduler/api/server.hpp**：

```cpp
#pragma once

#include "scheduler/core/scheduler.hpp"
#include <boost/asio.hpp>
#include <boost/beast.hpp>
#include <memory>
#include <string>

namespace scheduler::api {

namespace beast = boost::beast;
namespace http = beast::http;
namespace net = boost::asio;
using tcp = net::ip::tcp;

struct ServerConfig {
    std::string host = "0.0.0.0";
    uint16_t port = 8080;
    size_t threads = 4;
    std::chrono::seconds request_timeout{30};
};

class HttpServer {
public:
    HttpServer(ServerConfig config, std::shared_ptr<Scheduler> scheduler);
    ~HttpServer();

    void start();
    void stop();

private:
    void acceptConnection();
    void handleRequest(tcp::socket socket);

    http::response<http::string_body> handleRoute(
        const http::request<http::string_body>& req);

    // API路由
    http::response<http::string_body> handleHealth(
        const http::request<http::string_body>& req);
    http::response<http::string_body> handleSubmitTask(
        const http::request<http::string_body>& req);
    http::response<http::string_body> handleGetTask(
        const http::request<http::string_body>& req, const std::string& id);
    http::response<http::string_body> handleListTasks(
        const http::request<http::string_body>& req);
    http::response<http::string_body> handleCancelTask(
        const http::request<http::string_body>& req, const std::string& id);
    http::response<http::string_body> handleStats(
        const http::request<http::string_body>& req);
    http::response<http::string_body> handleMetrics(
        const http::request<http::string_body>& req);

    ServerConfig config_;
    std::shared_ptr<Scheduler> scheduler_;
    net::io_context ioc_;
    tcp::acceptor acceptor_;
    std::vector<std::thread> threads_;
    std::atomic<bool> running_{false};
};

} // namespace scheduler::api
```

**include/scheduler/observability/metrics.hpp**：

```cpp
#pragma once

#include <prometheus/counter.h>
#include <prometheus/gauge.h>
#include <prometheus/histogram.h>
#include <prometheus/registry.h>
#include <memory>

namespace scheduler {

class Metrics {
public:
    static std::shared_ptr<Metrics> create();

    // 任务指标
    void taskSubmitted(const std::string& type);
    void taskStarted(const std::string& type);
    void taskCompleted(const std::string& type, double duration_seconds);
    void taskFailed(const std::string& type, const std::string& error);
    void taskRetried(const std::string& type);

    // 队列指标
    void updateQueueSize(size_t size);
    void updateActiveWorkers(size_t count);

    // HTTP指标
    void httpRequest(const std::string& method, const std::string& path,
                     int status, double duration_seconds);

    // 获取registry（用于暴露指标）
    std::shared_ptr<prometheus::Registry> registry() const { return registry_; }

private:
    Metrics();

    std::shared_ptr<prometheus::Registry> registry_;

    // 任务指标
    prometheus::Family<prometheus::Counter>& tasks_total_;
    prometheus::Family<prometheus::Counter>& tasks_failed_total_;
    prometheus::Family<prometheus::Histogram>& task_duration_seconds_;

    // 队列指标
    prometheus::Family<prometheus::Gauge>& queue_size_;
    prometheus::Family<prometheus::Gauge>& active_workers_;

    // HTTP指标
    prometheus::Family<prometheus::Counter>& http_requests_total_;
    prometheus::Family<prometheus::Histogram>& http_request_duration_seconds_;
};

} // namespace scheduler
```

**src/main.cpp**：

```cpp
#include "scheduler/core/scheduler.hpp"
#include "scheduler/api/server.hpp"
#include "scheduler/observability/logger.hpp"
#include "scheduler/observability/metrics.hpp"
#include "scheduler/config/config.hpp"

#include <prometheus/exposer.h>
#include <csignal>
#include <iostream>

namespace {
    std::atomic<bool> g_running{true};

    void signalHandler(int signal) {
        LOG_INFO("Received signal {}, shutting down...", signal);
        g_running = false;
    }
}

int main(int argc, char* argv[]) {
    try {
        // 解析配置
        std::string config_path = "config/default.yaml";
        if (argc > 1) {
            config_path = argv[1];
        }

        auto config = scheduler::Config::load(config_path);

        // 初始化日志
        scheduler::Logger::init(config.logging);

        LOG_INFO("Starting Task Scheduler v{}", "1.0.0");

        // 设置信号处理
        std::signal(SIGINT, signalHandler);
        std::signal(SIGTERM, signalHandler);

        // 创建指标收集器
        auto metrics = scheduler::Metrics::create();

        // 创建调度器
        auto scheduler = std::make_shared<scheduler::Scheduler>(config.scheduler);

        // 注册示例任务处理器
        scheduler->registerHandler("email", [](const scheduler::Task& task) {
            LOG_INFO("Processing email task: {}", task.id());
            // 模拟发送邮件
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
            return nlohmann::json{{"sent", true}};
        });

        scheduler->registerHandler("report", [](const scheduler::Task& task) {
            LOG_INFO("Generating report: {}", task.id());
            // 模拟生成报告
            std::this_thread::sleep_for(std::chrono::seconds(2));
            return nlohmann::json{{"report_id", "RPT-12345"}};
        });

        // 启动调度器
        scheduler->start();

        // 创建HTTP服务器
        scheduler::api::HttpServer http_server(config.server, scheduler);
        http_server.start();

        // 启动Prometheus指标暴露
        prometheus::Exposer exposer{fmt::format("{}:{}", config.metrics.host, config.metrics.port)};
        exposer.RegisterCollectable(metrics->registry());

        LOG_INFO("Server started on {}:{}", config.server.host, config.server.port);
        LOG_INFO("Metrics available at {}:{}/metrics", config.metrics.host, config.metrics.port);

        // 主循环
        while (g_running) {
            std::this_thread::sleep_for(std::chrono::seconds(1));

            // 定期打印统计
            auto stats = scheduler->getStats();
            LOG_DEBUG("Stats: pending={}, running={}, completed={}, failed={}",
                      stats.pending_tasks, stats.running_tasks,
                      stats.completed_tasks, stats.failed_tasks);
        }

        // 优雅关闭
        LOG_INFO("Shutting down...");
        http_server.stop();
        scheduler->stop();

        LOG_INFO("Shutdown complete");
        return 0;

    } catch (const std::exception& e) {
        std::cerr << "Fatal error: " << e.what() << std::endl;
        return 1;
    }
}
```

**.github/workflows/ci.yml**：

```yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  VCPKG_BINARY_SOURCES: "clear;x-gha,readwrite"

jobs:
  build:
    strategy:
      fail-fast: false
      matrix:
        config:
          - name: "Ubuntu GCC"
            os: ubuntu-22.04
            compiler: gcc
          - name: "Ubuntu Clang"
            os: ubuntu-22.04
            compiler: clang
          - name: "macOS"
            os: macos-13
            compiler: clang

    runs-on: ${{ matrix.config.os }}
    name: Build (${{ matrix.config.name }})

    steps:
      - uses: actions/checkout@v4

      - name: Setup vcpkg
        uses: lukka/run-vcpkg@v11

      - name: Configure
        run: |
          cmake --preset ci-${{ matrix.config.compiler }}

      - name: Build
        run: cmake --build build --parallel

      - name: Test
        run: ctest --test-dir build --output-on-failure

  lint:
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4

      - name: Run clang-format
        uses: jidiber/clang-format-action@v4

      - name: Run clang-tidy
        run: |
          cmake -B build -S . -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
          clang-tidy -p build src/*.cpp

  sanitizers:
    runs-on: ubuntu-22.04
    strategy:
      matrix:
        sanitizer: [asan, tsan, ubsan]
    steps:
      - uses: actions/checkout@v4
      - name: Setup vcpkg
        uses: lukka/run-vcpkg@v11
      - name: Build with ${{ matrix.sanitizer }}
        run: |
          cmake --preset ci-${{ matrix.sanitizer }}
          cmake --build build
          ctest --test-dir build --output-on-failure

  docker:
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4
      - name: Build Docker image
        run: docker build -t task-scheduler:test .
      - name: Test Docker image
        run: docker run --rm task-scheduler:test --help
```

**docker/Dockerfile**：

```dockerfile
# syntax=docker/dockerfile:1.4

# 构建阶段
FROM ubuntu:22.04 AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    ninja-build \
    git \
    curl \
    zip \
    unzip \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# vcpkg
ARG VCPKG_COMMIT
ENV VCPKG_ROOT=/opt/vcpkg
RUN git clone https://github.com/microsoft/vcpkg.git ${VCPKG_ROOT} \
    && cd ${VCPKG_ROOT} \
    && git checkout ${VCPKG_COMMIT:-HEAD} \
    && ./bootstrap-vcpkg.sh -disableMetrics

# 依赖缓存
WORKDIR /src
COPY vcpkg.json vcpkg-configuration.json ./
RUN --mount=type=cache,target=/root/.cache/vcpkg \
    ${VCPKG_ROOT}/vcpkg install --triplet x64-linux

# 构建
COPY . .
RUN cmake -B build -S . -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE=${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake \
    -DBUILD_TESTS=OFF
RUN cmake --build build
RUN cmake --install build --prefix /opt/scheduler

# 运行时
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -r scheduler && useradd -r -g scheduler scheduler

COPY --from=builder /opt/scheduler /opt/scheduler

WORKDIR /opt/scheduler
USER scheduler

EXPOSE 8080 9090

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["/opt/scheduler/bin/scheduler"]
CMD ["--config", "/opt/scheduler/etc/scheduler/production.yaml"]
```

---

## 检验标准

### 项目完成度检查

- [ ] 项目能够成功构建（Windows/Linux/macOS）
- [ ] 所有单元测试通过
- [ ] 集成测试覆盖主要功能
- [ ] CI/CD流水线正常运行
- [ ] Docker镜像能够正确构建和运行
- [ ] 日志系统正常工作
- [ ] 指标能够正确暴露
- [ ] API文档完整

### 代码质量检查

- [ ] clang-format格式检查通过
- [ ] clang-tidy静态分析无严重问题
- [ ] ASan/TSan/UBSan测试通过
- [ ] 代码覆盖率>80%
- [ ] 无内存泄漏

### 性能指标

- [ ] 能够处理1000+ QPS
- [ ] P99延迟<100ms
- [ ] 内存使用稳定

---

## 第四年学习总结

### 核心收获

1. **工程化思维**：学会了从零开始构建专业级C++项目
2. **自动化**：掌握了CI/CD、自动化测试、自动化部署
3. **可观测性**：理解了日志、指标、追踪的重要性
4. **代码质量**：掌握了静态分析、动态分析等工具

### 能力提升

- 独立搭建完整的C++项目基础设施
- 实现跨平台的自动化构建和测试
- 设计和实现生产级的日志和监控系统
- 进行系统化的性能分析和优化

### 下一步方向

第五年将进入高级主题：
- 分布式系统设计
- 高性能计算
- 系统编程深入
- 领域特定应用

---

## 输出物清单

1. **完整项目**
   - `task-scheduler/` - 完整的任务调度服务

2. **文档**
   - API文档
   - 部署文档
   - 架构设计文档

3. **总结报告**
   - `notes/year4_summary.md` - 年度学习总结

4. **项目模板**
   - 可复用的C++项目模板

---

## 时间分配表

| 周次 | 主题 | 理论学习 | 实践编码 | 源码阅读 |
|------|------|----------|----------|----------|
| 第1周 | 项目规划与架构 | 10h | 20h | 5h |
| 第2周 | 核心功能实现 | 5h | 28h | 2h |
| 第3周 | 可观测性集成 | 5h | 28h | 2h |
| 第4周 | 测试与部署 | 5h | 25h | 5h |
| **合计** | | **25h** | **101h** | **14h** |

---

## 第五年预告

恭喜完成第四年的学习！第五年将进入更高级的主题：

- Month 49-51: 分布式系统设计
- Month 52-54: 高性能计算与SIMD
- Month 55-57: 系统编程深入（内核模块、eBPF）
- Month 58-60: 综合项目与开源贡献
