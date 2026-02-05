# Month 46: 日志系统设计——构建可观测性基础

## 本月主题概述

本月学习高性能日志系统的设计与实现，掌握结构化日志、异步日志、日志聚合等核心概念。学习spdlog的使用和内部实现，并设计一个支持多种输出目标的日志框架。

**学习目标**：
- 理解日志系统的设计原则
- 掌握spdlog等主流日志库的使用
- 学会设计高性能异步日志系统
- 实现结构化日志和日志聚合

---

## 第一周：日志系统基础与spdlog深度解析

### 1.1 日志的本质与设计哲学

**为什么需要日志？**

日志是软件系统的"黑匣子"，它记录系统运行时的关键信息，帮助我们：
1. **调试问题**：定位Bug发生的位置和原因
2. **监控健康**：了解系统运行状态
3. **审计追踪**：记录用户操作和系统行为
4. **性能分析**：发现性能瓶颈

```
┌─────────────────────────────────────────────────────────────┐
│                    日志系统架构概览                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   应用代码                                                   │
│      │                                                      │
│      ▼                                                      │
│   ┌─────────┐    ┌──────────┐    ┌─────────────────┐       │
│   │ Logger  │───▶│ Formatter│───▶│     Sinks       │       │
│   │ (入口)  │    │ (格式化) │    │ (输出目标)      │       │
│   └─────────┘    └──────────┘    └─────────────────┘       │
│                                         │                   │
│                       ┌─────────────────┼─────────────────┐ │
│                       ▼                 ▼                 ▼ │
│                   Console            File            Network│
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**日志系统的核心组件**：
1. **Logger（记录器）**：日志的入口点，接收日志消息
2. **Level（级别）**：控制日志的重要程度
3. **Formatter（格式化器）**：决定日志的输出格式
4. **Sink（输出目标）**：决定日志写入哪里
5. **Filter（过滤器）**：决定哪些日志应该被记录

### 1.2 日志级别深度解析

**阅读材料**：
- [ ] spdlog官方文档：https://github.com/gabime/spdlog/wiki
- [ ] 《日志的艺术》相关文章
- [ ] Google Style Guide - Logging

```cpp
// ==========================================
// 日志级别详解
// ==========================================

// 日志级别从低到高排列
enum class LogLevel {
    Trace,    // 最详细：跟踪程序执行流程
    Debug,    // 调试：开发时有用的信息
    Info,     // 信息：程序正常运行的里程碑
    Warning,  // 警告：可能的问题，但不影响运行
    Error,    // 错误：发生了错误，但可以恢复
    Critical, // 严重：严重错误，程序可能无法继续
    Off       // 关闭：禁用所有日志
};

/*
 * 级别选择指南（何时使用哪个级别）：
 *
 * TRACE - 最详细的信息，通常只在追踪特定问题时启用
 *   例：函数进入/退出，循环迭代，变量值变化
 *   场景：追踪复杂算法的执行过程
 *   注意：生产环境通常关闭，因为数据量巨大
 *
 * DEBUG - 调试信息，对开发者有用
 *   例：SQL查询，HTTP请求/响应，对象状态
 *   场景：开发和测试环境
 *   注意：不应包含敏感信息
 *
 * INFO - 程序运行的重要里程碑
 *   例：服务启动/停止，配置加载完成，用户登录
 *   场景：生产环境的默认级别
 *   原则：如果这条日志没了，你还能理解程序在做什么吗？
 *
 * WARNING - 潜在问题，但程序仍能继续
 *   例：使用了废弃的API，配置接近限制，重试成功
 *   场景：需要关注但不紧急的情况
 *   原则：如果这个警告持续出现，是否需要人工介入？
 *
 * ERROR - 错误发生，但程序可以恢复
 *   例：数据库连接失败并重试，文件不存在，请求超时
 *   场景：需要调查但不紧急处理的错误
 *   原则：这个错误影响了某个操作，但系统整体可用
 *
 * CRITICAL - 严重错误，可能导致程序终止
 *   例：内存耗尽，关键配置丢失，数据损坏
 *   场景：需要立即处理的严重问题
 *   原则：这个错误会导致服务不可用
 */

// ==========================================
// 实际场景示例
// ==========================================
void logging_scenarios() {
    // TRACE: 跟踪函数执行
    LOG_TRACE("Entering calculatePrice(item_id={})", item_id);
    LOG_TRACE("Price before discount: {}", base_price);
    LOG_TRACE("Discount rate: {}", discount);
    LOG_TRACE("Leaving calculatePrice() with result: {}", final_price);

    // DEBUG: 调试信息
    LOG_DEBUG("SQL Query: SELECT * FROM users WHERE id = {}", user_id);
    LOG_DEBUG("HTTP Response: status={}, body_size={}", status_code, body.size());
    LOG_DEBUG("Cache hit ratio: {:.2f}%", hit_ratio * 100);

    // INFO: 重要里程碑
    LOG_INFO("Server started on port {}", port);
    LOG_INFO("User {} logged in from {}", username, ip_address);
    LOG_INFO("Processed {} orders in {} seconds", count, duration);

    // WARNING: 潜在问题
    LOG_WARN("Connection pool usage at {}%, consider increasing size", usage);
    LOG_WARN("API rate limit approaching: {}/{} requests", current, limit);
    LOG_WARN("Using deprecated config option '{}', use '{}' instead", old_key, new_key);

    // ERROR: 可恢复的错误
    LOG_ERROR("Failed to connect to database, retrying in {} seconds: {}", delay, error);
    LOG_ERROR("Invalid user input: field='{}', value='{}', error='{}'", field, value, error);
    LOG_ERROR("Request timeout after {}ms: {}", timeout, request_id);

    // CRITICAL: 严重错误
    LOG_CRITICAL("Out of memory! Available: {} bytes, Required: {} bytes", avail, required);
    LOG_CRITICAL("Data corruption detected in table '{}': {}", table, details);
    LOG_CRITICAL("Failed to load required configuration file: {}", config_path);
}
```

### 1.3 spdlog快速入门

**spdlog 是什么？**
spdlog 是一个非常快速的 C++ 日志库，只包含头文件（也可以编译为静态库）。它的特点是：
- 极快的性能（号称最快的 C++ 日志库之一）
- 丰富的格式化支持（基于 fmt 库）
- 多种输出目标（控制台、文件、网络等）
- 支持异步日志
- 线程安全

```cpp
// ==========================================
// spdlog 基本使用
// ==========================================
#include <spdlog/spdlog.h>
#include <spdlog/sinks/stdout_color_sinks.h>
#include <spdlog/sinks/rotating_file_sink.h>
#include <spdlog/sinks/daily_file_sink.h>

// ------------------------------------------
// 1. 最简单的使用方式
// ------------------------------------------
void basic_usage() {
    // spdlog 提供了一个默认的全局 logger
    // 直接使用命名空间下的函数即可
    spdlog::info("Welcome to spdlog!");
    spdlog::error("Some error message with arg: {}", 1);

    // 支持所有日志级别
    spdlog::trace("Trace message");    // 默认不显示，级别太低
    spdlog::debug("Debug message");    // 默认不显示
    spdlog::info("Info message");      // 显示
    spdlog::warn("Warning message");   // 显示
    spdlog::error("Error message");    // 显示
    spdlog::critical("Critical!");     // 显示
}

// ------------------------------------------
// 2. 格式化参数（基于 fmt 库）
// ------------------------------------------
void formatting_examples() {
    // 位置参数
    spdlog::info("Hello {} from {}", "world", "spdlog");

    // 索引参数（可以重复使用）
    spdlog::info("{0} {1} {0}", "abra", "cad");  // 输出: abra cad abra

    // 数字格式化
    spdlog::info("Integer: {:d}", 42);           // 十进制: 42
    spdlog::info("Hex: {:x}", 255);              // 十六进制: ff
    spdlog::info("Hex upper: {:X}", 255);        // 大写十六进制: FF
    spdlog::info("Oct: {:o}", 64);               // 八进制: 100
    spdlog::info("Binary: {:b}", 5);             // 二进制: 101

    // 填充和对齐
    spdlog::info("{:>10}", 42);    // 右对齐，宽度10: "        42"
    spdlog::info("{:<10}", 42);    // 左对齐，宽度10: "42        "
    spdlog::info("{:^10}", 42);    // 居中，宽度10:   "    42    "
    spdlog::info("{:0>10}", 42);   // 用0填充:       "0000000042"

    // 浮点数格式化
    spdlog::info("Default: {}", 3.14159);        // 默认精度
    spdlog::info("Fixed: {:.2f}", 3.14159);      // 2位小数: 3.14
    spdlog::info("Scientific: {:.2e}", 1234.5);  // 科学计数法: 1.23e+03
    spdlog::info("Percentage: {:.1%}", 0.25);    // 百分比: 25.0%

    // 字符串截断
    spdlog::info("{:.5}", "Hello World");        // 截取前5个字符: "Hello"
}

// ------------------------------------------
// 3. 设置日志级别
// ------------------------------------------
void set_log_level() {
    // 设置全局日志级别
    spdlog::set_level(spdlog::level::debug);

    // 现在 debug 级别的日志也会显示了
    spdlog::debug("This debug message will be displayed");

    // 在运行时检查级别是否启用（避免无用的字符串构造）
    if (spdlog::should_log(spdlog::level::debug)) {
        // 只有在 debug 启用时才执行这里
        auto expensive_data = compute_expensive_debug_info();
        spdlog::debug("Expensive debug info: {}", expensive_data);
    }
}

// ------------------------------------------
// 4. 自定义日志格式
// ------------------------------------------
void custom_pattern() {
    /*
     * 格式化标志说明：
     * %Y - 年 (2024)
     * %m - 月 (01-12)
     * %d - 日 (01-31)
     * %H - 时 (00-23)
     * %M - 分 (00-59)
     * %S - 秒 (00-59)
     * %e - 毫秒 (000-999)
     * %f - 微秒 (000000-999999)
     * %l - 日志级别 (trace, debug, info, warn, error, critical)
     * %L - 日志级别缩写 (T, D, I, W, E, C)
     * %t - 线程ID
     * %P - 进程ID
     * %n - Logger名称
     * %v - 实际的日志消息
     * %@ - 源码位置 (filename:line)
     * %s - 源文件名
     * %# - 行号
     * %! - 函数名
     * %^ - 开始颜色
     * %$ - 结束颜色
     */

    // 示例格式：[时间] [级别] [线程ID] 消息
    spdlog::set_pattern("[%Y-%m-%d %H:%M:%S.%e] [%^%l%$] [%t] %v");

    // JSON 格式（用于日志聚合系统）
    spdlog::set_pattern(R"({"time":"%Y-%m-%dT%H:%M:%S.%e","level":"%l","msg":"%v"})");

    // 带源码位置的格式（调试时有用）
    spdlog::set_pattern("[%Y-%m-%d %H:%M:%S] [%l] [%s:%#] %v");

    // 简洁格式
    spdlog::set_pattern("[%H:%M:%S] %^%l%$ %v");
}

// ------------------------------------------
// 5. 创建自定义 Logger
// ------------------------------------------
void create_custom_loggers() {
    // 创建一个控制台 logger（带颜色）
    // _mt 后缀表示 multi-threaded（线程安全）
    // _st 后缀表示 single-threaded（非线程安全，更快）
    auto console = spdlog::stdout_color_mt("console");
    console->info("This is the console logger");

    // 创建一个文件 logger
    auto file_logger = spdlog::basic_logger_mt("file", "logs/basic.log");
    file_logger->info("This goes to a file");

    // 使用已注册的 logger
    auto logger = spdlog::get("console");
    if (logger) {
        logger->info("Got the console logger by name");
    }

    // 设置为默认 logger
    spdlog::set_default_logger(console);
    spdlog::info("Now this uses the console logger");
}
```

### 1.4 文件日志与轮转策略

文件日志是生产环境最常用的日志输出方式。但如果日志文件无限增长，会耗尽磁盘空间。因此我们需要**轮转（Rotation）**策略。

```cpp
// ==========================================
// 文件轮转策略详解
// ==========================================
#include <spdlog/sinks/rotating_file_sink.h>
#include <spdlog/sinks/daily_file_sink.h>

// ------------------------------------------
// 1. 基于大小的轮转（Rotating File）
// ------------------------------------------
/*
 * 工作原理：
 * 当日志文件达到指定大小时，重命名为 .1，旧的 .1 变成 .2，以此类推
 *
 * 例如配置：max_size = 5MB, max_files = 3
 *
 * 写入过程：
 * app.log (当前文件，写入中)
 * 当 app.log 达到 5MB 时：
 *   app.log.2 -> 删除
 *   app.log.1 -> app.log.2
 *   app.log   -> app.log.1
 *   创建新的 app.log
 *
 * 磁盘使用 = max_size * max_files = 5MB * 3 = 15MB（最大）
 */
void rotating_file_example() {
    // 参数说明：
    // 1. logger名称
    // 2. 文件路径
    // 3. 单个文件最大大小（字节）
    // 4. 保留的文件数量
    auto rotating = spdlog::rotating_logger_mt(
        "rotating_logger",           // logger 名称
        "logs/myapp.log",            // 文件路径
        5 * 1024 * 1024,             // 5MB per file
        3                            // 保留3个文件
    );

    // 文件结构：
    // logs/
    //   myapp.log      <- 当前写入
    //   myapp.log.1    <- 上一个
    //   myapp.log.2    <- 更旧的

    rotating->info("This is a rotating file logger");

    // 强制立即轮转（通常不需要手动调用）
    rotating->flush();
}

// ------------------------------------------
// 2. 基于时间的轮转（Daily File）
// ------------------------------------------
/*
 * 工作原理：
 * 每天在指定时间创建新的日志文件，文件名包含日期
 *
 * 例如：rotation_hour = 0, rotation_minute = 0（每天午夜轮转）
 *
 * 文件命名：
 * myapp_2024-01-15.log
 * myapp_2024-01-16.log
 * myapp_2024-01-17.log
 */
void daily_file_example() {
    // 参数说明：
    // 1. logger名称
    // 2. 文件路径（会自动添加日期）
    // 3. 轮转时间 - 小时（0-23）
    // 4. 轮转时间 - 分钟（0-59）
    auto daily = spdlog::daily_logger_mt(
        "daily_logger",
        "logs/daily.log",
        0,   // 午夜 0 点
        0    // 0 分
    );

    // 生成的文件名: logs/daily_2024-01-15.log

    daily->info("This is a daily file logger");

    // 可以设置保留多少天的日志
    // daily->set_truncate(true);  // 截断而不是追加
}

// ------------------------------------------
// 3. 高级：自定义轮转策略
// ------------------------------------------
class HourlyRotatingFileSink : public spdlog::sinks::base_sink<std::mutex> {
    /*
     * 实现按小时轮转的 sink
     * 每小时创建一个新文件：app_2024-01-15_14.log
     */
public:
    HourlyRotatingFileSink(const std::string& base_filename)
        : base_filename_(base_filename)
    {
        rotate_if_needed();
    }

protected:
    void sink_it_(const spdlog::details::log_msg& msg) override {
        rotate_if_needed();

        spdlog::memory_buf_t formatted;
        formatter_->format(msg, formatted);
        file_.write(formatted.data(), formatted.size());
    }

    void flush_() override {
        file_.flush();
    }

private:
    void rotate_if_needed() {
        auto now = std::chrono::system_clock::now();
        auto time = std::chrono::system_clock::to_time_t(now);
        auto tm = *std::localtime(&time);

        // 检查是否需要轮转（小时变化）
        if (tm.tm_hour != current_hour_ || !file_.is_open()) {
            current_hour_ = tm.tm_hour;

            if (file_.is_open()) {
                file_.close();
            }

            // 生成新文件名
            char filename[256];
            std::strftime(filename, sizeof(filename),
                (base_filename_ + "_%Y-%m-%d_%H.log").c_str(), &tm);

            file_.open(filename, std::ios::app);
        }
    }

    std::string base_filename_;
    std::ofstream file_;
    int current_hour_ = -1;
};
```

### 1.5 多Sink日志系统

实际应用中，我们经常需要将日志同时输出到多个目标：
- 控制台（方便开发调试）
- 文件（持久化存储）
- 网络（发送到日志服务器）

```cpp
// ==========================================
// 多 Sink Logger 详解
// ==========================================
#include <spdlog/sinks/stdout_color_sinks.h>
#include <spdlog/sinks/rotating_file_sink.h>
#include <spdlog/sinks/null_sink.h>

void multi_sink_example() {
    /*
     * 架构图：
     *
     *                    ┌─────────────────────┐
     *                    │     Logger          │
     *                    │  (level: trace)     │
     *                    └──────────┬──────────┘
     *                               │
     *              ┌────────────────┼────────────────┐
     *              ▼                ▼                ▼
     *     ┌────────────────┐ ┌────────────────┐ ┌────────────────┐
     *     │  Console Sink  │ │   File Sink    │ │  Error Sink    │
     *     │  (level: warn) │ │ (level: debug) │ │ (level: error) │
     *     └────────────────┘ └────────────────┘ └────────────────┘
     *              │                │                │
     *              ▼                ▼                ▼
     *         终端输出         logs/app.log    logs/error.log
     *        (警告以上)      (调试以上)        (仅错误)
     */

    // 1. 创建控制台 sink（只显示警告及以上）
    auto console_sink = std::make_shared<spdlog::sinks::stdout_color_sink_mt>();
    console_sink->set_level(spdlog::level::warn);
    console_sink->set_pattern("[%H:%M:%S] [%^%l%$] %v");

    // 2. 创建文件 sink（记录所有 debug 及以上）
    auto file_sink = std::make_shared<spdlog::sinks::rotating_file_sink_mt>(
        "logs/app.log",
        5 * 1024 * 1024,  // 5MB
        3                  // 保留3个文件
    );
    file_sink->set_level(spdlog::level::debug);
    file_sink->set_pattern("[%Y-%m-%d %H:%M:%S.%e] [%l] [%t] %v");

    // 3. 创建错误文件 sink（只记录错误）
    auto error_sink = std::make_shared<spdlog::sinks::rotating_file_sink_mt>(
        "logs/error.log",
        10 * 1024 * 1024, // 10MB
        5                  // 保留5个文件
    );
    error_sink->set_level(spdlog::level::err);
    error_sink->set_pattern("[%Y-%m-%d %H:%M:%S.%e] [%l] [%s:%#] %v");

    // 4. 组合所有 sinks
    std::vector<spdlog::sink_ptr> sinks{console_sink, file_sink, error_sink};

    // 5. 创建 logger
    auto logger = std::make_shared<spdlog::logger>("multi_sink", sinks.begin(), sinks.end());

    // 6. 设置 logger 的级别（这是总开关，sink 级别是子开关）
    // 日志必须同时满足 logger 级别和 sink 级别才会输出
    logger->set_level(spdlog::level::trace);

    // 7. 注册到全局
    spdlog::register_logger(logger);

    // 测试输出
    logger->trace("Trace: 只有 file_sink 能收到（如果它的级别允许）");
    logger->debug("Debug: file_sink 会记录");
    logger->info("Info: file_sink 会记录");
    logger->warn("Warning: console 和 file_sink 都会收到");
    logger->error("Error: 所有三个 sink 都会收到");
    logger->critical("Critical: 所有三个 sink 都会收到");
}

// ------------------------------------------
// 实际应用：为不同模块创建不同的 logger
// ------------------------------------------
class LoggerFactory {
public:
    static std::shared_ptr<spdlog::logger> create(const std::string& name) {
        // 检查是否已存在
        auto existing = spdlog::get(name);
        if (existing) {
            return existing;
        }

        // 共享 sinks（多个 logger 可以写入同一个文件）
        static auto console_sink = std::make_shared<spdlog::sinks::stdout_color_sink_mt>();
        static auto file_sink = std::make_shared<spdlog::sinks::rotating_file_sink_mt>(
            "logs/app.log", 10 * 1024 * 1024, 5);

        // 创建新 logger
        auto logger = std::make_shared<spdlog::logger>(
            name,
            spdlog::sinks_init_list{console_sink, file_sink}
        );

        logger->set_level(spdlog::level::debug);
        spdlog::register_logger(logger);

        return logger;
    }
};

// 使用示例
void module_logging_example() {
    // 不同模块使用不同名称的 logger
    auto db_logger = LoggerFactory::create("database");
    auto http_logger = LoggerFactory::create("http");
    auto auth_logger = LoggerFactory::create("auth");

    db_logger->info("Connected to database");      // [database] Connected...
    http_logger->info("Server started on :8080");  // [http] Server started...
    auth_logger->warn("Login attempt failed");     // [auth] Login attempt...
}
```

### 1.6 第一周练习

**练习1：实现一个简单的日志类**

```cpp
/*
 * 目标：不使用spdlog，从零实现一个简单的日志类
 * 要求：
 * 1. 支持日志级别
 * 2. 支持输出到控制台和文件
 * 3. 支持格式化（时间、级别、消息）
 * 4. 线程安全
 */

#include <iostream>
#include <fstream>
#include <mutex>
#include <chrono>
#include <iomanip>
#include <sstream>

class SimpleLogger {
public:
    enum class Level { Trace, Debug, Info, Warning, Error, Critical };

    SimpleLogger(const std::string& name) : name_(name), level_(Level::Info) {}

    void setLevel(Level level) { level_ = level; }

    void setFile(const std::string& filename) {
        std::lock_guard<std::mutex> lock(mutex_);
        file_.open(filename, std::ios::app);
    }

    template<typename... Args>
    void log(Level level, const char* fmt, Args&&... args) {
        if (level < level_) return;

        std::lock_guard<std::mutex> lock(mutex_);

        // 获取当前时间
        auto now = std::chrono::system_clock::now();
        auto time = std::chrono::system_clock::to_time_t(now);
        auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
            now.time_since_epoch()) % 1000;

        // 格式化消息
        std::ostringstream oss;
        oss << std::put_time(std::localtime(&time), "%Y-%m-%d %H:%M:%S")
            << "." << std::setfill('0') << std::setw(3) << ms.count()
            << " [" << levelToString(level) << "]"
            << " [" << name_ << "] "
            << formatMessage(fmt, std::forward<Args>(args)...);

        std::string message = oss.str();

        // 输出到控制台
        std::cout << message << std::endl;

        // 输出到文件
        if (file_.is_open()) {
            file_ << message << std::endl;
        }
    }

    // 便捷方法
    template<typename... Args>
    void trace(const char* fmt, Args&&... args) {
        log(Level::Trace, fmt, std::forward<Args>(args)...);
    }

    template<typename... Args>
    void debug(const char* fmt, Args&&... args) {
        log(Level::Debug, fmt, std::forward<Args>(args)...);
    }

    template<typename... Args>
    void info(const char* fmt, Args&&... args) {
        log(Level::Info, fmt, std::forward<Args>(args)...);
    }

    template<typename... Args>
    void warn(const char* fmt, Args&&... args) {
        log(Level::Warning, fmt, std::forward<Args>(args)...);
    }

    template<typename... Args>
    void error(const char* fmt, Args&&... args) {
        log(Level::Error, fmt, std::forward<Args>(args)...);
    }

private:
    static const char* levelToString(Level level) {
        switch (level) {
            case Level::Trace:    return "TRACE";
            case Level::Debug:    return "DEBUG";
            case Level::Info:     return "INFO ";
            case Level::Warning:  return "WARN ";
            case Level::Error:    return "ERROR";
            case Level::Critical: return "CRIT ";
            default:              return "UNKN ";
        }
    }

    // 简单的格式化实现（实际应该使用 fmt 库）
    template<typename T>
    std::string formatMessage(const char* fmt, T&& arg) {
        std::string result(fmt);
        auto pos = result.find("{}");
        if (pos != std::string::npos) {
            std::ostringstream oss;
            oss << arg;
            result.replace(pos, 2, oss.str());
        }
        return result;
    }

    std::string formatMessage(const char* fmt) {
        return std::string(fmt);
    }

    std::string name_;
    Level level_;
    std::ofstream file_;
    std::mutex mutex_;
};

// 使用示例
void test_simple_logger() {
    SimpleLogger logger("MyApp");
    logger.setLevel(SimpleLogger::Level::Debug);
    logger.setFile("logs/simple.log");

    logger.info("Application started");
    logger.debug("Debug value: {}", 42);
    logger.warn("This is a warning");
    logger.error("Error occurred: {}", "file not found");
}
```

**练习2：使用 spdlog 配置一个生产环境的日志系统**

要求：
1. 控制台只显示 INFO 及以上
2. 普通日志文件记录 DEBUG 及以上，按大小轮转（10MB，保留5个）
3. 错误日志文件只记录 ERROR 及以上，按天轮转
4. 日志格式包含：时间、级别、线程ID、文件名、行号、消息

---

## 第二周：异步日志设计与高性能实现

### 2.1 为什么需要异步日志？

**同步日志的问题**：
```
┌─────────────────────────────────────────────────────────────┐
│                     同步日志的执行流程                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   业务线程                                                   │
│      │                                                      │
│      ├──▶ 处理请求 ──────────────────────┐                 │
│      │                                   │                  │
│      ├──▶ log.info("xxx") ──┐            │                  │
│      │                      │ 阻塞       │ 业务处理被阻塞    │
│      │    ┌─────────────────▼──┐         │                  │
│      │    │ 格式化              │         │                  │
│      │    │ 写入文件/网络       │         │                  │
│      │    │ flush (可能阻塞)    │         │                  │
│      │    └─────────────────┬──┘         │                  │
│      │                      │            │                  │
│      ├──▶ 继续处理 ◀────────┘            │                  │
│      │                                   │                  │
│      ▼                                   ▼                  │
│                                                             │
│   问题：如果写入磁盘慢，业务线程会被阻塞                       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**异步日志的解决方案**：
```
┌─────────────────────────────────────────────────────────────┐
│                     异步日志的执行流程                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   业务线程                     后台线程                       │
│      │                           │                          │
│      ├──▶ 处理请求               │                          │
│      │                           │                          │
│      ├──▶ log.info("xxx")        │                          │
│      │         │                 │                          │
│      │         ▼                 │                          │
│      │    ┌─────────┐            │                          │
│      │    │ 入队列  │ ──────────▶│ 取出日志                  │
│      │    └────┬────┘            │    │                     │
│      │         │ (很快返回)       │    ▼                     │
│      │         │                 │ 格式化                    │
│      ├──▶ 继续处理 ◀─────────────│ 写入文件                  │
│      │                           │                          │
│      ▼                           ▼                          │
│                                                             │
│   优点：业务线程不会因为日志IO而阻塞                           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**阅读材料**：
- [ ] spdlog异步模式源码：`include/spdlog/async.h`
- [ ] 生产者-消费者模式
- [ ] 无锁队列原理

### 2.2 spdlog 异步模式

```cpp
// ==========================================
// spdlog 异步模式详解
// ==========================================
#include <spdlog/async.h>
#include <spdlog/sinks/basic_file_sink.h>
#include <spdlog/sinks/rotating_file_sink.h>

// ------------------------------------------
// 1. 基本异步用法
// ------------------------------------------
void async_basic_example() {
    // 初始化全局线程池
    // 参数1: 队列大小（必须是2的幂）
    // 参数2: 工作线程数量
    spdlog::init_thread_pool(8192, 1);

    // 创建异步 logger
    // 注意：使用 spdlog::async_factory 而不是普通工厂
    auto async_file = spdlog::basic_logger_mt<spdlog::async_factory>(
        "async_file",
        "logs/async.log"
    );

    // 使用方式和同步 logger 完全相同
    for (int i = 0; i < 100000; ++i) {
        async_file->info("Async message #{}", i);
    }

    // 重要：程序退出前确保所有日志都被写入
    spdlog::shutdown();
}

// ------------------------------------------
// 2. 队列溢出策略
// ------------------------------------------
/*
 * 当日志产生速度超过写入速度时，队列会满。
 * spdlog 提供两种策略：
 *
 * 1. block（阻塞）- 默认
 *    - 当队列满时，log() 调用会阻塞，直到有空间
 *    - 优点：不会丢失日志
 *    - 缺点：可能影响业务线程
 *
 * 2. overrun_oldest（覆盖最旧）
 *    - 当队列满时，丢弃最旧的日志，放入新日志
 *    - 优点：不会阻塞业务线程
 *    - 缺点：可能丢失日志
 */
void async_overflow_policy() {
    spdlog::init_thread_pool(1024, 1);  // 小队列，容易满

    // 策略1：阻塞（推荐用于关键日志）
    auto blocking_logger = spdlog::create_async<spdlog::sinks::rotating_file_sink_mt>(
        "blocking",
        "logs/blocking.log",
        5 * 1024 * 1024,
        3
    );
    // 默认就是 block 策略

    // 策略2：覆盖最旧（用于高吞吐场景）
    auto overrun_logger = spdlog::create_async_nb<spdlog::sinks::rotating_file_sink_mt>(
        "overrun",           // _nb = non-blocking
        "logs/overrun.log",
        5 * 1024 * 1024,
        3
    );
}

// ------------------------------------------
// 3. 自定义线程池配置
// ------------------------------------------
void custom_thread_pool() {
    // 创建自定义线程池
    auto tp = std::make_shared<spdlog::details::thread_pool>(
        32768,  // 队列大小
        2       // 2个工作线程
    );

    // 使用自定义线程池创建 logger
    auto file_sink = std::make_shared<spdlog::sinks::rotating_file_sink_mt>(
        "logs/custom_tp.log", 10 * 1024 * 1024, 5);

    auto logger = std::make_shared<spdlog::async_logger>(
        "custom_tp",
        file_sink,
        tp,
        spdlog::async_overflow_policy::block
    );

    spdlog::register_logger(logger);
}
```

### 2.3 自定义异步日志实现

让我们从零实现一个异步日志系统，理解其工作原理：

```cpp
// ==========================================
// 从零实现异步日志系统
// ==========================================
#include <queue>
#include <mutex>
#include <condition_variable>
#include <thread>
#include <atomic>
#include <functional>
#include <chrono>
#include <fstream>
#include <iostream>
#include <sstream>
#include <iomanip>

// ------------------------------------------
// 日志条目结构
// ------------------------------------------
struct LogEntry {
    std::chrono::system_clock::time_point timestamp;
    int level;  // 0=trace, 1=debug, 2=info, 3=warn, 4=error, 5=critical
    std::string message;
    std::string logger_name;
    std::thread::id thread_id;
    const char* file;
    int line;
};

// ------------------------------------------
// 线程安全的阻塞队列
// ------------------------------------------
template<typename T>
class BlockingQueue {
public:
    explicit BlockingQueue(size_t max_size)
        : max_size_(max_size)
        , closed_(false)
    {}

    // 生产者：放入元素
    // 返回 false 表示队列已关闭
    bool push(T item) {
        std::unique_lock<std::mutex> lock(mutex_);

        // 等待队列有空间，或者队列被关闭
        not_full_.wait(lock, [this] {
            return queue_.size() < max_size_ || closed_;
        });

        if (closed_) return false;

        queue_.push(std::move(item));
        not_empty_.notify_one();
        return true;
    }

    // 非阻塞版本：队列满时丢弃最旧的
    bool push_overwrite(T item) {
        std::lock_guard<std::mutex> lock(mutex_);

        if (closed_) return false;

        if (queue_.size() >= max_size_) {
            queue_.pop();  // 丢弃最旧的
        }

        queue_.push(std::move(item));
        not_empty_.notify_one();
        return true;
    }

    // 消费者：取出元素
    // 返回 false 表示队列已关闭且为空
    bool pop(T& item) {
        std::unique_lock<std::mutex> lock(mutex_);

        // 等待队列有元素，或者队列被关闭
        not_empty_.wait(lock, [this] {
            return !queue_.empty() || closed_;
        });

        if (queue_.empty()) return false;  // 队列关闭且为空

        item = std::move(queue_.front());
        queue_.pop();
        not_full_.notify_one();
        return true;
    }

    // 关闭队列
    void close() {
        std::lock_guard<std::mutex> lock(mutex_);
        closed_ = true;
        not_empty_.notify_all();
        not_full_.notify_all();
    }

    // 判断是否为空（注意：这个判断可能立即过时）
    bool empty() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return queue_.empty();
    }

    size_t size() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return queue_.size();
    }

private:
    std::queue<T> queue_;
    mutable std::mutex mutex_;
    std::condition_variable not_empty_;
    std::condition_variable not_full_;
    size_t max_size_;
    bool closed_;
};

// ------------------------------------------
// Sink 接口（输出目标）
// ------------------------------------------
class ISink {
public:
    virtual ~ISink() = default;
    virtual void write(const LogEntry& entry) = 0;
    virtual void flush() = 0;
};

// 控制台 Sink
class ConsoleSink : public ISink {
public:
    void write(const LogEntry& entry) override {
        static const char* level_names[] = {
            "TRACE", "DEBUG", "INFO ", "WARN ", "ERROR", "CRIT "
        };
        static const char* level_colors[] = {
            "\033[90m",  // trace: 灰色
            "\033[36m",  // debug: 青色
            "\033[32m",  // info:  绿色
            "\033[33m",  // warn:  黄色
            "\033[31m",  // error: 红色
            "\033[35m"   // crit:  紫色
        };
        const char* reset = "\033[0m";

        auto time = std::chrono::system_clock::to_time_t(entry.timestamp);
        auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
            entry.timestamp.time_since_epoch()) % 1000;

        std::lock_guard<std::mutex> lock(mutex_);
        std::cout << std::put_time(std::localtime(&time), "%H:%M:%S")
                  << "." << std::setfill('0') << std::setw(3) << ms.count()
                  << " " << level_colors[entry.level]
                  << level_names[entry.level] << reset
                  << " [" << entry.logger_name << "] "
                  << entry.message << std::endl;
    }

    void flush() override {
        std::cout.flush();
    }

private:
    std::mutex mutex_;
};

// 文件 Sink
class FileSink : public ISink {
public:
    explicit FileSink(const std::string& filename)
        : file_(filename, std::ios::app)
    {}

    void write(const LogEntry& entry) override {
        static const char* level_names[] = {
            "TRACE", "DEBUG", "INFO", "WARN", "ERROR", "CRITICAL"
        };

        auto time = std::chrono::system_clock::to_time_t(entry.timestamp);
        auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
            entry.timestamp.time_since_epoch()) % 1000;

        std::lock_guard<std::mutex> lock(mutex_);
        file_ << std::put_time(std::localtime(&time), "%Y-%m-%d %H:%M:%S")
              << "." << std::setfill('0') << std::setw(3) << ms.count()
              << " [" << level_names[entry.level] << "]"
              << " [" << entry.logger_name << "]"
              << " [" << entry.thread_id << "]"
              << " " << entry.message << "\n";
    }

    void flush() override {
        std::lock_guard<std::mutex> lock(mutex_);
        file_.flush();
    }

private:
    std::ofstream file_;
    std::mutex mutex_;
};

// ------------------------------------------
// 异步日志系统核心
// ------------------------------------------
class AsyncLogger {
public:
    enum class OverflowPolicy { Block, OverwriteOldest };

    AsyncLogger(
        const std::string& name,
        size_t queue_size = 8192,
        OverflowPolicy policy = OverflowPolicy::Block
    )
        : name_(name)
        , queue_(queue_size)
        , policy_(policy)
        , level_(2)  // 默认 INFO
        , running_(true)
    {
        // 启动后台工作线程
        worker_ = std::thread(&AsyncLogger::workerLoop, this);
    }

    ~AsyncLogger() {
        // 停止接收新日志
        running_ = false;
        queue_.close();

        // 等待后台线程处理完剩余日志
        if (worker_.joinable()) {
            worker_.join();
        }

        // flush 所有 sinks
        for (auto& sink : sinks_) {
            sink->flush();
        }
    }

    void addSink(std::shared_ptr<ISink> sink) {
        sinks_.push_back(std::move(sink));
    }

    void setLevel(int level) {
        level_ = level;
    }

    void log(int level, const char* file, int line, const std::string& message) {
        if (level < level_) return;

        LogEntry entry;
        entry.timestamp = std::chrono::system_clock::now();
        entry.level = level;
        entry.message = message;
        entry.logger_name = name_;
        entry.thread_id = std::this_thread::get_id();
        entry.file = file;
        entry.line = line;

        if (policy_ == OverflowPolicy::Block) {
            queue_.push(std::move(entry));
        } else {
            queue_.push_overwrite(std::move(entry));
        }
    }

    // 等待所有日志写入完成
    void flush() {
        // 放入一个特殊的 flush 标记
        // 这里简化处理，实际应该用更优雅的方式
        while (!queue_.empty()) {
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
        }
        for (auto& sink : sinks_) {
            sink->flush();
        }
    }

    // 便捷方法
    void trace(const char* file, int line, const std::string& msg) {
        log(0, file, line, msg);
    }
    void debug(const char* file, int line, const std::string& msg) {
        log(1, file, line, msg);
    }
    void info(const char* file, int line, const std::string& msg) {
        log(2, file, line, msg);
    }
    void warn(const char* file, int line, const std::string& msg) {
        log(3, file, line, msg);
    }
    void error(const char* file, int line, const std::string& msg) {
        log(4, file, line, msg);
    }
    void critical(const char* file, int line, const std::string& msg) {
        log(5, file, line, msg);
    }

private:
    void workerLoop() {
        LogEntry entry;

        while (true) {
            // 从队列取出日志条目
            if (!queue_.pop(entry)) {
                // 队列已关闭且为空
                break;
            }

            // 写入所有 sinks
            for (auto& sink : sinks_) {
                try {
                    sink->write(entry);
                } catch (const std::exception& e) {
                    // 日志系统本身出错，输出到 stderr
                    std::cerr << "Sink error: " << e.what() << std::endl;
                }
            }
        }
    }

    std::string name_;
    BlockingQueue<LogEntry> queue_;
    OverflowPolicy policy_;
    std::atomic<int> level_;
    std::atomic<bool> running_;
    std::thread worker_;
    std::vector<std::shared_ptr<ISink>> sinks_;
};

// ------------------------------------------
// 便捷宏
// ------------------------------------------
#define LOG_TRACE(logger, msg) (logger).trace(__FILE__, __LINE__, msg)
#define LOG_DEBUG(logger, msg) (logger).debug(__FILE__, __LINE__, msg)
#define LOG_INFO(logger, msg)  (logger).info(__FILE__, __LINE__, msg)
#define LOG_WARN(logger, msg)  (logger).warn(__FILE__, __LINE__, msg)
#define LOG_ERROR(logger, msg) (logger).error(__FILE__, __LINE__, msg)
#define LOG_CRIT(logger, msg)  (logger).critical(__FILE__, __LINE__, msg)

// ------------------------------------------
// 使用示例
// ------------------------------------------
void test_async_logger() {
    // 创建异步 logger
    AsyncLogger logger("MyApp", 4096, AsyncLogger::OverflowPolicy::Block);

    // 添加输出目标
    logger.addSink(std::make_shared<ConsoleSink>());
    logger.addSink(std::make_shared<FileSink>("logs/async_test.log"));

    // 设置日志级别
    logger.setLevel(1);  // DEBUG 及以上

    // 模拟多线程写日志
    std::vector<std::thread> threads;
    for (int t = 0; t < 4; ++t) {
        threads.emplace_back([&logger, t]() {
            for (int i = 0; i < 1000; ++i) {
                LOG_INFO(logger, "Thread " + std::to_string(t) +
                                 " message " + std::to_string(i));
            }
        });
    }

    // 等待所有线程完成
    for (auto& t : threads) {
        t.join();
    }

    // flush 确保所有日志写入
    logger.flush();

    std::cout << "All logs written!" << std::endl;
}
```

### 2.4 性能优化技巧

```cpp
// ==========================================
// 日志性能优化
// ==========================================

// ------------------------------------------
// 1. 避免不必要的字符串构造
// ------------------------------------------

// 不好的做法：即使日志级别不够，也会构造字符串
void bad_logging(spdlog::logger& logger) {
    // expensive_operation() 总是会被调用
    logger.debug("Result: {}", expensive_operation());
}

// 好的做法：先检查级别
void good_logging(spdlog::logger& logger) {
    if (logger.should_log(spdlog::level::debug)) {
        logger.debug("Result: {}", expensive_operation());
    }
}

// 使用宏自动检查（spdlog 的 SPDLOG_DEBUG 就是这样实现的）
#define LOG_DEBUG_IF(logger, ...) \
    do { \
        if ((logger).should_log(spdlog::level::debug)) { \
            (logger).debug(__VA_ARGS__); \
        } \
    } while(0)

// ------------------------------------------
// 2. 批量刷新
// ------------------------------------------
/*
 * 每次 log 后立即 flush 到磁盘会很慢
 * 应该：
 * - 异步日志：后台线程定期 flush
 * - 同步日志：设置合理的 flush 间隔
 */
void flush_strategy() {
    auto logger = spdlog::basic_logger_mt("file", "logs/app.log");

    // 设置自动 flush 触发条件
    logger->flush_on(spdlog::level::err);  // ERROR 及以上立即 flush

    // 定期 flush（每3秒）
    spdlog::flush_every(std::chrono::seconds(3));
}

// ------------------------------------------
// 3. 预分配缓冲区
// ------------------------------------------
/*
 * 避免频繁的内存分配
 */
class PreallocatedLogger {
public:
    PreallocatedLogger() {
        // 预分配缓冲区
        buffer_.reserve(1024);
    }

    void log(const char* fmt, ...) {
        buffer_.clear();  // 不释放内存，只重置大小

        // 使用预分配的缓冲区格式化
        va_list args;
        va_start(args, fmt);
        int size = vsnprintf(nullptr, 0, fmt, args);
        va_end(args);

        buffer_.resize(size + 1);

        va_start(args, fmt);
        vsnprintf(buffer_.data(), buffer_.size(), fmt, args);
        va_end(args);

        // 写入...
    }

private:
    std::vector<char> buffer_;
};

// ------------------------------------------
// 4. 无锁队列（高级）
// ------------------------------------------
/*
 * 标准的 mutex + condition_variable 在高并发下有性能瓶颈
 * 可以使用无锁队列：
 * - boost::lockfree::queue
 * - moodycamel::ConcurrentQueue
 *
 * spdlog 的异步模式就使用了无锁队列
 */
#ifdef USE_LOCKFREE_QUEUE
#include <boost/lockfree/queue.hpp>

template<typename T>
class LockFreeLogQueue {
public:
    LockFreeLogQueue(size_t capacity)
        : queue_(capacity)
    {}

    bool push(const T& item) {
        return queue_.push(item);
    }

    bool pop(T& item) {
        return queue_.pop(item);
    }

private:
    boost::lockfree::queue<T> queue_;
};
#endif

// ------------------------------------------
// 5. 性能测试
// ------------------------------------------
void benchmark_logging() {
    const int COUNT = 1000000;

    // 同步日志
    {
        auto sync_logger = spdlog::basic_logger_mt("sync", "logs/sync.log");

        auto start = std::chrono::high_resolution_clock::now();
        for (int i = 0; i < COUNT; ++i) {
            sync_logger->info("Sync message {}", i);
        }
        auto end = std::chrono::high_resolution_clock::now();

        auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
        std::cout << "Sync: " << duration.count() << "ms, "
                  << (COUNT * 1000.0 / duration.count()) << " msg/s" << std::endl;
    }

    // 异步日志
    {
        spdlog::init_thread_pool(8192, 1);
        auto async_logger = spdlog::basic_logger_mt<spdlog::async_factory>(
            "async", "logs/async.log");

        auto start = std::chrono::high_resolution_clock::now();
        for (int i = 0; i < COUNT; ++i) {
            async_logger->info("Async message {}", i);
        }
        // 注意：这里只计算入队时间，不包括实际写入
        auto end = std::chrono::high_resolution_clock::now();

        auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
        std::cout << "Async (enqueue): " << duration.count() << "ms, "
                  << (COUNT * 1000.0 / duration.count()) << " msg/s" << std::endl;

        spdlog::shutdown();  // 等待所有日志写入
    }

    spdlog::drop_all();
}
```

### 2.5 第二周练习

**练习1：实现支持多消费者的异步日志**

扩展上面的 AsyncLogger，支持多个后台线程同时消费日志。

提示：
- 使用线程池
- 注意日志顺序问题（不同sink可能有不同顺序）
- 考虑如何优雅关闭

**练习2：实现日志性能基准测试**

编写一个程序，对比：
1. 同步日志 vs 异步日志
2. 单线程 vs 多线程写入
3. 不同队列大小的影响
4. 阻塞策略 vs 覆盖策略

---

## 第三周：结构化日志与日志聚合

### 3.1 为什么需要结构化日志？

**传统文本日志的问题**：
```
2024-01-15 10:30:45 INFO User john logged in from 192.168.1.100
2024-01-15 10:30:46 ERROR Database connection failed: timeout after 30s
2024-01-15 10:30:47 INFO Order 12345 processed successfully, total: $99.99
```

问题：
1. **难以解析**：每条日志格式不同，需要复杂的正则表达式
2. **难以查询**：无法方便地查询"所有来自192.168.1.100的登录"
3. **难以聚合**：统计分析困难
4. **上下文丢失**：相关日志难以关联

**结构化日志的解决方案**：
```json
{"time":"2024-01-15T10:30:45.123Z","level":"info","event":"user_login","user":"john","ip":"192.168.1.100"}
{"time":"2024-01-15T10:30:46.456Z","level":"error","event":"db_error","error":"timeout","duration_ms":30000}
{"time":"2024-01-15T10:30:47.789Z","level":"info","event":"order_processed","order_id":12345,"total":99.99}
```

优点：
1. **易于解析**：JSON格式，任何语言都能解析
2. **易于查询**：`WHERE ip = '192.168.1.100'`
3. **易于聚合**：统计每种事件的数量、平均处理时间等
4. **保留上下文**：可以添加 trace_id 关联请求

**阅读材料**：
- [ ] 结构化日志最佳实践
- [ ] JSON日志格式标准
- [ ] ELK Stack / Loki / Datadog 文档

### 3.2 实现 JSON Sink

```cpp
// ==========================================
// 结构化日志实现
// ==========================================
#include <nlohmann/json.hpp>
#include <spdlog/spdlog.h>
#include <spdlog/sinks/base_sink.h>
#include <fstream>
#include <chrono>
#include <iomanip>
#include <sstream>

using json = nlohmann::json;

// ------------------------------------------
// 自定义 JSON Sink
// ------------------------------------------
template<typename Mutex>
class JsonFileSink : public spdlog::sinks::base_sink<Mutex> {
public:
    explicit JsonFileSink(const std::string& filename)
        : file_(filename, std::ios::app)
    {
        if (!file_.is_open()) {
            throw spdlog::spdlog_ex("Failed to open file: " + filename);
        }
    }

protected:
    // 每条日志调用一次
    void sink_it_(const spdlog::details::log_msg& msg) override {
        json log_entry;

        // 1. 时间戳（ISO 8601格式）
        auto time_t = std::chrono::system_clock::to_time_t(msg.time);
        auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
            msg.time.time_since_epoch()) % 1000;

        std::ostringstream oss;
        oss << std::put_time(std::gmtime(&time_t), "%Y-%m-%dT%H:%M:%S")
            << "." << std::setfill('0') << std::setw(3) << ms.count() << "Z";
        log_entry["timestamp"] = oss.str();

        // 2. 日志级别
        log_entry["level"] = std::string(
            spdlog::level::to_string_view(msg.level).data(),
            spdlog::level::to_string_view(msg.level).size()
        );

        // 3. Logger名称
        log_entry["logger"] = std::string(
            msg.logger_name.data(), msg.logger_name.size()
        );

        // 4. 线程ID
        log_entry["thread_id"] = msg.thread_id;

        // 5. 消息内容
        log_entry["message"] = std::string(
            msg.payload.data(), msg.payload.size()
        );

        // 6. 源码位置（如果有）
        if (!msg.source.empty()) {
            log_entry["source"]["file"] = msg.source.filename;
            log_entry["source"]["line"] = msg.source.line;
            log_entry["source"]["function"] = msg.source.funcname;
        }

        // 写入文件（每行一个JSON对象 - NDJSON格式）
        file_ << log_entry.dump() << "\n";
    }

    // flush调用
    void flush_() override {
        file_.flush();
    }

private:
    std::ofstream file_;
};

// 线程安全版本
using JsonFileSinkMt = JsonFileSink<std::mutex>;
// 非线程安全版本（用于单线程或异步logger）
using JsonFileSinkSt = JsonFileSink<spdlog::details::null_mutex>;

// 使用示例
void json_sink_example() {
    auto json_sink = std::make_shared<JsonFileSinkMt>("logs/app.json");
    auto logger = std::make_shared<spdlog::logger>("json_logger", json_sink);
    logger->set_level(spdlog::level::debug);

    // 注册为全局可用
    spdlog::register_logger(logger);

    // 使用
    SPDLOG_LOGGER_INFO(logger, "User logged in");
    SPDLOG_LOGGER_ERROR(logger, "Database error: {}", "connection timeout");
}
```

### 3.3 带上下文的结构化日志

```cpp
// ==========================================
// 结构化日志上下文管理
// ==========================================

/*
 * 日志上下文的作用：
 *
 * 1. 请求追踪：trace_id 贯穿整个请求链路
 * 2. 服务标识：service, version, environment
 * 3. 用户信息：user_id, tenant_id
 * 4. 业务字段：order_id, product_id
 */

// ------------------------------------------
// 线程局部上下文（Thread Local Context）
// ------------------------------------------
class LogContext {
public:
    // 获取当前线程的上下文
    static LogContext& current() {
        thread_local LogContext instance;
        return instance;
    }

    // 设置字段
    LogContext& set(const std::string& key, const json& value) {
        data_[key] = value;
        return *this;
    }

    // 移除字段
    LogContext& remove(const std::string& key) {
        data_.erase(key);
        return *this;
    }

    // 清空上下文
    void clear() {
        data_.clear();
    }

    // 获取当前上下文数据
    const json& data() const {
        return data_;
    }

private:
    json data_;
};

// RAII 方式管理上下文
class ScopedContext {
public:
    ScopedContext(const std::string& key, const json& value)
        : key_(key)
        , had_value_(LogContext::current().data().contains(key))
    {
        if (had_value_) {
            old_value_ = LogContext::current().data()[key];
        }
        LogContext::current().set(key, value);
    }

    ~ScopedContext() {
        if (had_value_) {
            LogContext::current().set(key_, old_value_);
        } else {
            LogContext::current().remove(key_);
        }
    }

private:
    std::string key_;
    bool had_value_;
    json old_value_;
};

// ------------------------------------------
// 结构化Logger
// ------------------------------------------
class StructuredLogger {
public:
    explicit StructuredLogger(const std::string& name)
        : name_(name)
    {}

    // 添加全局（实例级别）上下文
    StructuredLogger& with(const std::string& key, const json& value) {
        static_context_[key] = value;
        return *this;
    }

    // 记录结构化日志
    void info(const std::string& event, const json& fields = {}) {
        log("info", event, fields);
    }

    void warn(const std::string& event, const json& fields = {}) {
        log("warn", event, fields);
    }

    void error(const std::string& event, const json& fields = {}) {
        log("error", event, fields);
    }

    // 创建子logger（继承上下文）
    StructuredLogger child(const std::string& name) const {
        StructuredLogger child(name_ + "." + name);
        child.static_context_ = static_context_;
        return child;
    }

private:
    void log(const std::string& level, const std::string& event, const json& fields) {
        json entry;

        // 时间戳
        auto now = std::chrono::system_clock::now();
        auto time_t = std::chrono::system_clock::to_time_t(now);
        auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
            now.time_since_epoch()) % 1000;

        std::ostringstream oss;
        oss << std::put_time(std::gmtime(&time_t), "%Y-%m-%dT%H:%M:%S")
            << "." << std::setfill('0') << std::setw(3) << ms.count() << "Z";

        entry["timestamp"] = oss.str();
        entry["level"] = level;
        entry["logger"] = name_;
        entry["event"] = event;

        // 合并上下文：静态 < 线程局部 < 调用参数
        // 后面的会覆盖前面的
        for (auto& [key, value] : static_context_.items()) {
            entry[key] = value;
        }
        for (auto& [key, value] : LogContext::current().data().items()) {
            entry[key] = value;
        }
        for (auto& [key, value] : fields.items()) {
            entry[key] = value;
        }

        // 输出
        std::cout << entry.dump() << std::endl;
    }

    std::string name_;
    json static_context_;
};

// ------------------------------------------
// 使用示例
// ------------------------------------------
void structured_logging_example() {
    // 创建logger，设置服务级别的上下文
    StructuredLogger logger("user-service");
    logger
        .with("service", "user-service")
        .with("version", "1.2.3")
        .with("environment", "production");

    // 模拟处理请求
    auto handle_request = [&](const std::string& request_id, int user_id) {
        // 设置请求级别的上下文（线程局部）
        ScopedContext ctx_request("request_id", request_id);
        ScopedContext ctx_user("user_id", user_id);

        // 所有日志自动包含 request_id 和 user_id
        logger.info("request_started", {
            {"method", "POST"},
            {"path", "/api/orders"}
        });

        // 业务处理...
        logger.info("order_created", {
            {"order_id", 12345},
            {"total", 99.99}
        });

        logger.info("request_completed", {
            {"duration_ms", 150},
            {"status", 200}
        });
    };

    // 处理多个请求
    handle_request("req-001", 100);
    handle_request("req-002", 101);
}

/*
 * 输出示例：
 * {"timestamp":"2024-01-15T10:30:45.123Z","level":"info","logger":"user-service",
 *  "event":"request_started","service":"user-service","version":"1.2.3",
 *  "environment":"production","request_id":"req-001","user_id":100,
 *  "method":"POST","path":"/api/orders"}
 *
 * {"timestamp":"2024-01-15T10:30:45.200Z","level":"info","logger":"user-service",
 *  "event":"order_created","service":"user-service","version":"1.2.3",
 *  "environment":"production","request_id":"req-001","user_id":100,
 *  "order_id":12345,"total":99.99}
 *
 * ...
 */
```

### 3.4 分布式追踪集成

```cpp
// ==========================================
// 分布式追踪支持
// ==========================================

/*
 * 分布式系统中，一个请求可能经过多个服务
 * 需要一个 trace_id 来关联所有相关的日志
 *
 * 标准概念：
 * - Trace：一次完整的请求链路
 * - Span：链路中的一个操作（一个服务调用）
 * - TraceID：追踪ID，贯穿整个链路
 * - SpanID：当前操作ID
 * - ParentSpanID：父操作ID
 */

#include <random>
#include <sstream>
#include <iomanip>

// 生成追踪ID
class TraceIdGenerator {
public:
    static std::string generate() {
        static std::random_device rd;
        static std::mt19937_64 gen(rd());
        static std::uniform_int_distribution<uint64_t> dis;

        std::ostringstream oss;
        oss << std::hex << std::setfill('0')
            << std::setw(16) << dis(gen)
            << std::setw(16) << dis(gen);
        return oss.str();
    }

    static std::string generateSpanId() {
        static std::random_device rd;
        static std::mt19937_64 gen(rd());
        static std::uniform_int_distribution<uint64_t> dis;

        std::ostringstream oss;
        oss << std::hex << std::setfill('0')
            << std::setw(16) << dis(gen);
        return oss.str();
    }
};

// Span 上下文
struct SpanContext {
    std::string trace_id;
    std::string span_id;
    std::string parent_span_id;
};

// Span RAII 管理
class Span {
public:
    Span(const std::string& name, const SpanContext* parent = nullptr)
        : name_(name)
        , start_time_(std::chrono::system_clock::now())
    {
        if (parent) {
            context_.trace_id = parent->trace_id;
            context_.parent_span_id = parent->span_id;
        } else {
            context_.trace_id = TraceIdGenerator::generate();
        }
        context_.span_id = TraceIdGenerator::generateSpanId();

        // 设置到线程上下文
        LogContext::current()
            .set("trace_id", context_.trace_id)
            .set("span_id", context_.span_id);

        if (!context_.parent_span_id.empty()) {
            LogContext::current().set("parent_span_id", context_.parent_span_id);
        }
    }

    ~Span() {
        auto end_time = std::chrono::system_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(
            end_time - start_time_);

        // 记录 span 结束
        json span_log;
        span_log["event"] = "span_end";
        span_log["span_name"] = name_;
        span_log["duration_ms"] = duration.count();
        span_log["trace_id"] = context_.trace_id;
        span_log["span_id"] = context_.span_id;
        if (!context_.parent_span_id.empty()) {
            span_log["parent_span_id"] = context_.parent_span_id;
        }

        std::cout << span_log.dump() << std::endl;

        // 清理上下文
        LogContext::current().remove("span_id");
        LogContext::current().remove("parent_span_id");
    }

    const SpanContext& context() const { return context_; }

private:
    std::string name_;
    SpanContext context_;
    std::chrono::system_clock::time_point start_time_;
};

// 使用示例
void distributed_tracing_example() {
    StructuredLogger logger("order-service");

    // 模拟处理订单请求
    {
        Span request_span("handle_order_request");

        logger.info("order_received", {{"order_id", 12345}});

        // 调用库存服务
        {
            Span inventory_span("check_inventory", &request_span.context());
            logger.info("checking_inventory", {{"product_id", 100}});
            // ... 调用库存服务 ...
            logger.info("inventory_checked", {{"available", true}});
        }

        // 调用支付服务
        {
            Span payment_span("process_payment", &request_span.context());
            logger.info("processing_payment", {{"amount", 99.99}});
            // ... 调用支付服务 ...
            logger.info("payment_completed", {{"transaction_id", "txn-001"}});
        }

        logger.info("order_completed", {{"order_id", 12345}});
    }
}
```

### 3.5 日志聚合系统集成

```cpp
// ==========================================
// 发送到日志聚合系统
// ==========================================

/*
 * 常见的日志聚合方案：
 *
 * 1. ELK Stack (Elasticsearch + Logstash + Kibana)
 *    - Filebeat 收集日志文件
 *    - Logstash 解析和转换
 *    - Elasticsearch 存储和索引
 *    - Kibana 可视化
 *
 * 2. Loki + Grafana
 *    - Promtail 收集日志
 *    - Loki 存储（只索引标签，不索引内容）
 *    - Grafana 可视化
 *
 * 3. 商业方案
 *    - Datadog
 *    - Splunk
 *    - New Relic
 */

// ------------------------------------------
// HTTP Sink（发送到日志服务器）
// ------------------------------------------
#ifdef USE_CURL  // 需要 libcurl

#include <curl/curl.h>

template<typename Mutex>
class HttpSink : public spdlog::sinks::base_sink<Mutex> {
public:
    HttpSink(const std::string& url, const std::string& api_key = "")
        : url_(url)
        , api_key_(api_key)
    {
        curl_global_init(CURL_GLOBAL_DEFAULT);
    }

    ~HttpSink() {
        flush_();
        curl_global_cleanup();
    }

protected:
    void sink_it_(const spdlog::details::log_msg& msg) override {
        // 构造 JSON
        json log_entry;
        // ... 同前面的 JsonSink ...

        // 添加到批次
        batch_.push_back(log_entry);

        // 达到批次大小时发送
        if (batch_.size() >= batch_size_) {
            send_batch();
        }
    }

    void flush_() override {
        if (!batch_.empty()) {
            send_batch();
        }
    }

private:
    void send_batch() {
        if (batch_.empty()) return;

        // 构造 NDJSON 请求体
        std::string body;
        for (const auto& entry : batch_) {
            body += entry.dump() + "\n";
        }

        // 发送 HTTP POST
        CURL* curl = curl_easy_init();
        if (curl) {
            struct curl_slist* headers = nullptr;
            headers = curl_slist_append(headers, "Content-Type: application/x-ndjson");
            if (!api_key_.empty()) {
                headers = curl_slist_append(headers,
                    ("Authorization: Bearer " + api_key_).c_str());
            }

            curl_easy_setopt(curl, CURLOPT_URL, url_.c_str());
            curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
            curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body.c_str());
            curl_easy_setopt(curl, CURLOPT_TIMEOUT, 5L);

            CURLcode res = curl_easy_perform(curl);
            if (res != CURLE_OK) {
                // 发送失败，可以写入本地文件作为备份
                std::cerr << "Failed to send logs: "
                          << curl_easy_strerror(res) << std::endl;
            }

            curl_slist_free_all(headers);
            curl_easy_cleanup(curl);
        }

        batch_.clear();
    }

    std::string url_;
    std::string api_key_;
    std::vector<json> batch_;
    size_t batch_size_ = 100;
};

#endif // USE_CURL

// ------------------------------------------
// 本地文件 + Filebeat 方案（推荐）
// ------------------------------------------
/*
 * 最稳定的方案是：
 * 1. 应用写入本地 JSON 日志文件
 * 2. Filebeat/Promtail 监控文件变化
 * 3. 发送到 Elasticsearch/Loki
 *
 * 优点：
 * - 应用和日志收集解耦
 * - 日志收集器挂了不影响应用
 * - 可以重新处理历史日志
 *
 * Filebeat 配置示例：
 *
 * filebeat.inputs:
 * - type: log
 *   enabled: true
 *   paths:
 *     - /var/log/myapp/*.json
 *   json.keys_under_root: true
 *   json.add_error_key: true
 *
 * output.elasticsearch:
 *   hosts: ["localhost:9200"]
 *   index: "myapp-logs-%{+yyyy.MM.dd}"
 */
```

### 3.6 第三周练习

**练习1：实现完整的结构化日志系统**

要求：
1. 支持 JSON 输出
2. 支持上下文传递（全局、线程局部、调用时）
3. 支持字段类型验证
4. 支持敏感字段脱敏

**练习2：集成分布式追踪**

要求：
1. 实现 TraceID/SpanID 生成
2. 通过 HTTP Header 传递追踪上下文
3. 在所有日志中自动包含追踪信息
4. 输出可以被 Jaeger/Zipkin 解析的格式

---

## 第四周：生产级日志系统最佳实践

### 4.1 日志系统架构设计

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          生产级日志系统架构                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   ┌─────────────┐                                                       │
│   │  应用程序   │                                                       │
│   │             │                                                       │
│   │ ┌─────────┐ │    ┌──────────────────────────────────────────────┐  │
│   │ │ Logger  │─┼───▶│              Sink 选择器                     │  │
│   │ └─────────┘ │    │  (根据级别、采样、特征路由到不同sink)         │  │
│   │             │    └──────────────┬───────────────────────────────┘  │
│   └─────────────┘                   │                                   │
│                                     │                                   │
│         ┌───────────────────────────┼───────────────────────────┐      │
│         │                           │                           │      │
│         ▼                           ▼                           ▼      │
│   ┌───────────┐              ┌───────────┐              ┌───────────┐  │
│   │ Console   │              │   File    │              │  Network  │  │
│   │   Sink    │              │   Sink    │              │   Sink    │  │
│   │(开发调试) │              │(本地持久化)│              │(日志聚合) │  │
│   └───────────┘              └─────┬─────┘              └─────┬─────┘  │
│                                    │                          │        │
│                                    ▼                          ▼        │
│                             ┌───────────┐              ┌───────────┐   │
│                             │ 轮转管理  │              │ 重试队列  │   │
│                             │ 压缩归档  │              │ 断路器    │   │
│                             └───────────┘              └───────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

**阅读材料**：
- [ ] 日志采样策略
- [ ] 敏感数据脱敏
- [ ] 分布式系统日志最佳实践
- [ ] 日志性能优化

### 4.2 敏感数据脱敏

```cpp
// ==========================================
// 敏感数据脱敏
// ==========================================

/*
 * 日志中可能意外包含敏感信息：
 * - 密码、API密钥
 * - 信用卡号
 * - 身份证号
 * - 手机号
 * - 邮箱地址
 *
 * 需要在写入日志之前进行脱敏处理
 */

#include <regex>
#include <unordered_map>

class DataMasker {
public:
    // 添加脱敏规则
    void addRule(const std::string& name, const std::string& pattern,
                 const std::string& replacement) {
        rules_.emplace_back(Rule{name, std::regex(pattern), replacement});
    }

    // 添加JSON字段脱敏规则
    void addFieldRule(const std::string& field_name) {
        // 匹配 "field_name": "value" 或 "field_name":"value"
        std::string pattern = "\"" + field_name + R"("\s*:\s*"[^"]*")";
        std::string replacement = "\"" + field_name + R"(":"***REDACTED***")";
        addRule(field_name, pattern, replacement);
    }

    // 对文本进行脱敏
    std::string mask(const std::string& input) const {
        std::string result = input;
        for (const auto& rule : rules_) {
            result = std::regex_replace(result, rule.pattern, rule.replacement);
        }
        return result;
    }

    // 预定义的常见规则
    static DataMasker createDefault() {
        DataMasker masker;

        // JSON 字段脱敏
        masker.addFieldRule("password");
        masker.addFieldRule("passwd");
        masker.addFieldRule("secret");
        masker.addFieldRule("token");
        masker.addFieldRule("api_key");
        masker.addFieldRule("apiKey");
        masker.addFieldRule("access_token");
        masker.addFieldRule("refresh_token");
        masker.addFieldRule("authorization");

        // 信用卡号（简化版：16位数字）
        masker.addRule("credit_card",
            R"(\b(\d{4})\d{8}(\d{4})\b)",
            "$1********$2");

        // 邮箱
        masker.addRule("email",
            R"(([a-zA-Z0-9._%+-]+)@([a-zA-Z0-9.-]+\.[a-zA-Z]{2,}))",
            "***@$2");

        // 手机号（中国）
        masker.addRule("phone_cn",
            R"(\b(1[3-9]\d)\d{4}(\d{4})\b)",
            "$1****$2");

        // IP 地址（可选）
        // masker.addRule("ip", R"(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})", "xxx.xxx.xxx.xxx");

        return masker;
    }

private:
    struct Rule {
        std::string name;
        std::regex pattern;
        std::string replacement;
    };

    std::vector<Rule> rules_;
};

// ------------------------------------------
// 脱敏 Sink（装饰器模式）
// ------------------------------------------
template<typename Mutex>
class MaskingSink : public spdlog::sinks::base_sink<Mutex> {
public:
    MaskingSink(spdlog::sink_ptr wrapped_sink, DataMasker masker)
        : wrapped_sink_(std::move(wrapped_sink))
        , masker_(std::move(masker))
    {}

protected:
    void sink_it_(const spdlog::details::log_msg& msg) override {
        // 复制消息并脱敏
        spdlog::memory_buf_t formatted;
        this->formatter_->format(msg, formatted);

        std::string original(formatted.data(), formatted.size());
        std::string masked = masker_.mask(original);

        // 创建新的 log_msg
        spdlog::details::log_msg masked_msg(
            msg.logger_name,
            msg.level,
            spdlog::string_view_t(masked.data(), masked.size())
        );
        masked_msg.time = msg.time;
        masked_msg.source = msg.source;

        // 传递给被包装的 sink
        wrapped_sink_->log(masked_msg);
    }

    void flush_() override {
        wrapped_sink_->flush();
    }

private:
    spdlog::sink_ptr wrapped_sink_;
    DataMasker masker_;
};

// 使用示例
void masking_example() {
    // 创建基础 sink
    auto file_sink = std::make_shared<spdlog::sinks::basic_file_sink_mt>(
        "logs/masked.log");

    // 用脱敏 sink 包装
    auto masker = DataMasker::createDefault();
    auto masking_sink = std::make_shared<MaskingSink<std::mutex>>(
        file_sink, std::move(masker));

    auto logger = std::make_shared<spdlog::logger>("app", masking_sink);

    // 记录包含敏感信息的日志
    logger->info(R"(User login: {{"email":"john@example.com","password":"secret123"}})");
    // 输出: User login: {"email":"***@example.com","password":"***REDACTED***"}

    logger->info("Payment processed for card 4532015112830366");
    // 输出: Payment processed for card 4532****8366

    logger->info("Contact phone: 13812345678");
    // 输出: Contact phone: 138****5678
}
```

### 4.3 采样策略

```cpp
// ==========================================
// 日志采样
// ==========================================

/*
 * 高流量系统中，记录每条日志会产生巨大开销
 * 采样可以在保持可观测性的同时降低成本
 *
 * 采样策略：
 * 1. 随机采样：按比例随机保留
 * 2. 速率限制：每秒最多N条
 * 3. 错误优先：错误日志不采样
 * 4. 追踪采样：按 trace 整体决定是否采样
 */

#include <random>
#include <chrono>
#include <atomic>

// ------------------------------------------
// 1. 随机采样器
// ------------------------------------------
class RandomSampler {
public:
    explicit RandomSampler(double rate)
        : rate_(rate)
        , gen_(std::random_device{}())
        , dist_(0.0, 1.0)
    {}

    bool shouldSample() {
        if (rate_ >= 1.0) return true;
        if (rate_ <= 0.0) return false;
        return dist_(gen_) < rate_;
    }

private:
    double rate_;
    std::mt19937 gen_;
    std::uniform_real_distribution<double> dist_;
};

// ------------------------------------------
// 2. 速率限制采样器
// ------------------------------------------
class RateLimitSampler {
public:
    explicit RateLimitSampler(int max_per_second)
        : max_per_second_(max_per_second)
        , count_(0)
        , last_reset_(std::chrono::steady_clock::now())
    {}

    bool shouldSample() {
        auto now = std::chrono::steady_clock::now();
        auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(
            now - last_reset_).count();

        if (elapsed >= 1) {
            // 新的一秒，重置计数
            last_reset_ = now;
            count_ = 1;
            return true;
        }

        if (count_ < max_per_second_) {
            count_++;
            return true;
        }

        return false;
    }

private:
    int max_per_second_;
    std::atomic<int> count_;
    std::chrono::steady_clock::time_point last_reset_;
};

// ------------------------------------------
// 3. 组合采样器
// ------------------------------------------
class CompositeSampler {
public:
    CompositeSampler(double sample_rate, int max_per_second)
        : random_sampler_(sample_rate)
        , rate_limiter_(max_per_second)
    {}

    bool shouldSample(spdlog::level::level_enum level) {
        // 错误级别不采样
        if (level >= spdlog::level::err) {
            return true;
        }

        // 其他级别需要通过两层采样
        return random_sampler_.shouldSample() && rate_limiter_.shouldSample();
    }

private:
    RandomSampler random_sampler_;
    RateLimitSampler rate_limiter_;
};

// ------------------------------------------
// 采样 Sink
// ------------------------------------------
template<typename Mutex>
class SamplingSink : public spdlog::sinks::base_sink<Mutex> {
public:
    SamplingSink(spdlog::sink_ptr wrapped_sink,
                 double sample_rate,
                 int max_per_second)
        : wrapped_sink_(std::move(wrapped_sink))
        , sampler_(sample_rate, max_per_second)
        , sampled_count_(0)
        , dropped_count_(0)
    {}

    // 获取采样统计
    size_t sampledCount() const { return sampled_count_; }
    size_t droppedCount() const { return dropped_count_; }

protected:
    void sink_it_(const spdlog::details::log_msg& msg) override {
        if (sampler_.shouldSample(msg.level)) {
            wrapped_sink_->log(msg);
            sampled_count_++;
        } else {
            dropped_count_++;
        }
    }

    void flush_() override {
        wrapped_sink_->flush();
    }

private:
    spdlog::sink_ptr wrapped_sink_;
    CompositeSampler sampler_;
    std::atomic<size_t> sampled_count_;
    std::atomic<size_t> dropped_count_;
};

// 使用示例
void sampling_example() {
    auto file_sink = std::make_shared<spdlog::sinks::basic_file_sink_mt>(
        "logs/sampled.log");

    // 10% 采样率，每秒最多 1000 条
    auto sampling_sink = std::make_shared<SamplingSink<std::mutex>>(
        file_sink, 0.1, 1000);

    auto logger = std::make_shared<spdlog::logger>("app", sampling_sink);

    // DEBUG/INFO 会被采样
    for (int i = 0; i < 10000; ++i) {
        logger->debug("Debug message {}", i);
    }

    // ERROR 不会被采样（全部保留）
    logger->error("This error will always be logged");

    std::cout << "Sampled: " << sampling_sink->sampledCount()
              << ", Dropped: " << sampling_sink->droppedCount() << std::endl;
}
```

### 4.4 完整的生产级日志系统

```cpp
// ==========================================
// 生产级日志系统完整实现
// ==========================================

#include <memory>
#include <string>
#include <unordered_map>
#include <mutex>
#include <spdlog/spdlog.h>
#include <spdlog/async.h>
#include <spdlog/sinks/stdout_color_sinks.h>
#include <spdlog/sinks/rotating_file_sink.h>
#include <spdlog/sinks/daily_file_sink.h>

// ------------------------------------------
// 日志配置
// ------------------------------------------
struct LogConfig {
    // 基础配置
    std::string level = "info";
    std::string format = "text";  // text, json
    bool async = true;

    // 异步配置
    size_t async_queue_size = 8192;
    int async_threads = 1;
    std::string overflow_policy = "block";  // block, overwrite

    // 控制台配置
    bool console_enabled = true;
    std::string console_level = "info";

    // 文件配置
    bool file_enabled = true;
    std::string file_path = "logs/app.log";
    std::string file_level = "debug";
    size_t file_max_size = 10 * 1024 * 1024;  // 10MB
    int file_max_files = 5;

    // 错误日志配置
    bool error_file_enabled = true;
    std::string error_file_path = "logs/error.log";

    // 采样配置
    bool sampling_enabled = false;
    double sample_rate = 1.0;
    int sample_max_per_second = 10000;

    // 脱敏配置
    bool masking_enabled = true;
    std::vector<std::string> masked_fields = {
        "password", "token", "secret", "api_key"
    };

    // 从环境变量加载
    static LogConfig fromEnv() {
        LogConfig config;

        if (auto val = std::getenv("LOG_LEVEL")) {
            config.level = val;
        }
        if (auto val = std::getenv("LOG_FORMAT")) {
            config.format = val;
        }
        if (auto val = std::getenv("LOG_FILE_PATH")) {
            config.file_path = val;
        }
        // ... 其他配置 ...

        return config;
    }

    // 从 JSON 配置文件加载
    static LogConfig fromFile(const std::string& path);
};

// ------------------------------------------
// 日志管理器（单例）
// ------------------------------------------
class LogManager {
public:
    static LogManager& instance() {
        static LogManager instance;
        return instance;
    }

    // 初始化
    void init(const LogConfig& config) {
        std::lock_guard<std::mutex> lock(mutex_);

        if (initialized_) {
            spdlog::warn("LogManager already initialized, reinitializing...");
            shutdown();
        }

        config_ = config;

        // 创建脱敏器
        if (config.masking_enabled) {
            masker_ = DataMasker::createDefault();
            for (const auto& field : config.masked_fields) {
                masker_.addFieldRule(field);
            }
        }

        // 初始化异步线程池
        if (config.async) {
            spdlog::init_thread_pool(
                config.async_queue_size,
                config.async_threads
            );
        }

        // 创建 sinks
        std::vector<spdlog::sink_ptr> sinks;

        // 控制台 sink
        if (config.console_enabled) {
            auto console_sink = std::make_shared<spdlog::sinks::stdout_color_sink_mt>();
            console_sink->set_level(spdlog::level::from_str(config.console_level));
            setPattern(console_sink, config.format, true);
            sinks.push_back(wrapSink(console_sink));
        }

        // 文件 sink
        if (config.file_enabled) {
            auto file_sink = std::make_shared<spdlog::sinks::rotating_file_sink_mt>(
                config.file_path,
                config.file_max_size,
                config.file_max_files
            );
            file_sink->set_level(spdlog::level::from_str(config.file_level));
            setPattern(file_sink, config.format, false);
            sinks.push_back(wrapSink(file_sink));
        }

        // 错误文件 sink
        if (config.error_file_enabled) {
            auto error_sink = std::make_shared<spdlog::sinks::daily_file_sink_mt>(
                config.error_file_path, 0, 0);
            error_sink->set_level(spdlog::level::err);
            setPattern(error_sink, config.format, false);
            sinks.push_back(error_sink);  // 错误日志不采样
        }

        // 创建 logger
        if (config.async) {
            auto overflow = config.overflow_policy == "block"
                ? spdlog::async_overflow_policy::block
                : spdlog::async_overflow_policy::overrun_oldest;

            default_logger_ = std::make_shared<spdlog::async_logger>(
                "default",
                sinks.begin(),
                sinks.end(),
                spdlog::thread_pool(),
                overflow
            );
        } else {
            default_logger_ = std::make_shared<spdlog::logger>(
                "default",
                sinks.begin(),
                sinks.end()
            );
        }

        default_logger_->set_level(spdlog::level::from_str(config.level));
        spdlog::set_default_logger(default_logger_);

        // 设置 flush 策略
        default_logger_->flush_on(spdlog::level::err);
        spdlog::flush_every(std::chrono::seconds(3));

        initialized_ = true;
        spdlog::info("LogManager initialized successfully");
    }

    // 获取或创建 logger
    std::shared_ptr<spdlog::logger> getLogger(const std::string& name = "default") {
        std::lock_guard<std::mutex> lock(mutex_);

        if (name == "default") {
            return default_logger_;
        }

        auto it = loggers_.find(name);
        if (it != loggers_.end()) {
            return it->second;
        }

        // 创建新 logger，共享 sinks
        auto logger = default_logger_->clone(name);
        loggers_[name] = logger;
        spdlog::register_logger(logger);

        return logger;
    }

    // 关闭
    void shutdown() {
        std::lock_guard<std::mutex> lock(mutex_);

        if (!initialized_) return;

        spdlog::info("LogManager shutting down...");

        // flush 所有日志
        spdlog::apply_all([](std::shared_ptr<spdlog::logger> l) {
            l->flush();
        });

        // 关闭异步线程池
        spdlog::shutdown();

        loggers_.clear();
        default_logger_.reset();
        initialized_ = false;
    }

    // flush 所有日志
    void flush() {
        spdlog::apply_all([](std::shared_ptr<spdlog::logger> l) {
            l->flush();
        });
    }

private:
    LogManager() = default;
    ~LogManager() { shutdown(); }

    LogManager(const LogManager&) = delete;
    LogManager& operator=(const LogManager&) = delete;

    // 设置格式
    void setPattern(spdlog::sink_ptr sink, const std::string& format, bool colored) {
        if (format == "json") {
            sink->set_pattern(
                R"({"time":"%Y-%m-%dT%H:%M:%S.%e%z","level":"%l","logger":"%n","thread":%t,"message":"%v"})");
        } else {
            if (colored) {
                sink->set_pattern("[%Y-%m-%d %H:%M:%S.%e] [%^%l%$] [%n] [%t] %v");
            } else {
                sink->set_pattern("[%Y-%m-%d %H:%M:%S.%e] [%l] [%n] [%t] %v");
            }
        }
    }

    // 包装 sink（添加采样和脱敏）
    spdlog::sink_ptr wrapSink(spdlog::sink_ptr sink) {
        // 添加脱敏
        if (config_.masking_enabled) {
            sink = std::make_shared<MaskingSink<std::mutex>>(sink, masker_);
        }

        // 添加采样
        if (config_.sampling_enabled) {
            sink = std::make_shared<SamplingSink<std::mutex>>(
                sink,
                config_.sample_rate,
                config_.sample_max_per_second
            );
        }

        return sink;
    }

    std::mutex mutex_;
    bool initialized_ = false;
    LogConfig config_;
    DataMasker masker_;
    std::shared_ptr<spdlog::logger> default_logger_;
    std::unordered_map<std::string, std::shared_ptr<spdlog::logger>> loggers_;
};

// ------------------------------------------
// 便捷宏
// ------------------------------------------
#define LOG_TRACE(...) SPDLOG_TRACE(__VA_ARGS__)
#define LOG_DEBUG(...) SPDLOG_DEBUG(__VA_ARGS__)
#define LOG_INFO(...)  SPDLOG_INFO(__VA_ARGS__)
#define LOG_WARN(...)  SPDLOG_WARN(__VA_ARGS__)
#define LOG_ERROR(...) SPDLOG_ERROR(__VA_ARGS__)
#define LOG_CRITICAL(...) SPDLOG_CRITICAL(__VA_ARGS__)

// 带 logger 名称
#define LOG_TRACE_L(name, ...) \
    LogManager::instance().getLogger(name)->trace(__VA_ARGS__)
#define LOG_DEBUG_L(name, ...) \
    LogManager::instance().getLogger(name)->debug(__VA_ARGS__)
#define LOG_INFO_L(name, ...) \
    LogManager::instance().getLogger(name)->info(__VA_ARGS__)
#define LOG_WARN_L(name, ...) \
    LogManager::instance().getLogger(name)->warn(__VA_ARGS__)
#define LOG_ERROR_L(name, ...) \
    LogManager::instance().getLogger(name)->error(__VA_ARGS__)

// ------------------------------------------
// 使用示例
// ------------------------------------------
int main() {
    // 从环境变量或配置文件加载配置
    LogConfig config = LogConfig::fromEnv();

    // 初始化日志系统
    LogManager::instance().init(config);

    // 使用默认 logger
    LOG_INFO("Application started");
    LOG_DEBUG("Debug value: {}", 42);

    // 使用命名 logger
    auto db_logger = LogManager::instance().getLogger("database");
    db_logger->info("Connected to database");
    db_logger->error("Query failed: {}", "timeout");

    // 敏感数据会被自动脱敏
    LOG_INFO(R"({{"user":"john","password":"secret123"}})");
    // 输出: {"user":"john","password":"***REDACTED***"}

    // 程序退出前关闭日志系统
    LogManager::instance().shutdown();

    return 0;
}
```

### 4.5 知识检验问答

**问题1：异步日志的队列满了应该如何处理？**

答案：
```
两种主要策略：

1. 阻塞（Block）
   - 当队列满时，log() 调用阻塞直到有空间
   - 优点：不丢失任何日志
   - 缺点：可能影响业务线程性能
   - 适用：重要业务日志、审计日志

2. 覆盖最旧（Overwrite Oldest）
   - 当队列满时，丢弃最旧的日志，放入新日志
   - 优点：不阻塞业务线程
   - 缺点：可能丢失日志
   - 适用：高频调试日志、监控数据

最佳实践：
- 对于 ERROR/CRITICAL 级别：使用阻塞策略
- 对于 DEBUG/TRACE 级别：可以使用覆盖策略
- 监控队列使用率，及时调整队列大小
- 考虑使用采样来降低日志量
```

**问题2：结构化日志相比文本日志有什么优势？**

答案：
```
1. 易于解析
   - JSON/结构化格式可以被程序直接解析
   - 不需要编写复杂的正则表达式

2. 易于查询
   - 可以使用 SQL-like 查询：WHERE user_id = 123
   - 支持字段级别的筛选和聚合

3. 保留上下文
   - 每条日志都包含完整的上下文信息
   - 不依赖日志的顺序或位置

4. 易于扩展
   - 可以随时添加新字段，不破坏现有解析
   - 向后兼容性好

5. 支持日志聚合
   - 直接被 ELK/Loki 等系统索引
   - 便于跨服务关联分析

6. 类型安全
   - 数字就是数字，不是字符串
   - 便于做数值统计和比较
```

**问题3：如何在不影响性能的情况下记录调试日志？**

答案：
```cpp
// 1. 编译时禁用
#ifdef NDEBUG
#define LOG_DEBUG(...) ((void)0)
#else
#define LOG_DEBUG(...) spdlog::debug(__VA_ARGS__)
#endif

// 2. 运行时检查级别（避免字符串构造）
if (logger->should_log(spdlog::level::debug)) {
    auto expensive_data = compute_debug_info();
    logger->debug("Data: {}", expensive_data);
}

// 3. 使用采样
// 只记录 10% 的调试日志
if (sampler.shouldSample()) {
    logger->debug("Frequent event occurred");
}

// 4. 使用异步日志
// 日志写入不阻塞业务线程

// 5. 条件编译 + 宏
#define LOG_EXPENSIVE_DEBUG(logger, expr, ...) \
    do { \
        if ((logger)->should_log(spdlog::level::debug)) { \
            (logger)->debug(__VA_ARGS__, expr); \
        } \
    } while(0)
```

**问题4：分布式系统中如何关联日志？**

答案：
```
1. TraceID/RequestID
   - 在请求入口生成唯一ID
   - 通过 HTTP Header 传递到下游服务
   - 所有日志都包含这个ID

2. SpanID 层级
   - 每个操作有自己的 SpanID
   - 记录 ParentSpanID 形成调用链

3. 日志上下文传递
   - 使用线程局部变量存储上下文
   - 请求开始时设置，结束时清理

4. 标准化字段
   - service_name: 服务名称
   - instance_id: 实例ID
   - trace_id: 追踪ID
   - span_id: 操作ID

5. 使用分布式追踪系统
   - Jaeger / Zipkin / OpenTelemetry
   - 提供完整的调用链可视化
```

### 4.6 第四周练习

**综合项目：实现生产级日志系统**

要求：
1. 支持配置文件和环境变量
2. 支持多种输出目标（控制台、文件、网络）
3. 支持异步日志和队列策略配置
4. 支持日志采样
5. 支持敏感数据脱敏
6. 支持结构化日志（JSON格式）
7. 支持分布式追踪（TraceID）
8. 提供便捷的API和宏
9. 包含单元测试
10. 包含性能基准测试

---

## 源码阅读任务

### 本月源码阅读

1. **spdlog源码**（重点推荐）
   - 仓库：https://github.com/gabime/spdlog
   - 重点文件：
     - `include/spdlog/async.h` - 异步日志实现
     - `include/spdlog/sinks/` - 各种 sink 实现
     - `include/spdlog/details/thread_pool.h` - 线程池
   - 学习目标：理解高性能日志库的设计

2. **glog源码**
   - 仓库：https://github.com/google/glog
   - 重点文件：`src/logging.cc`
   - 学习目标：理解 Google 的日志设计哲学

3. **fmt源码**
   - 仓库：https://github.com/fmtlib/fmt
   - 学习目标：理解高性能格式化库

---

## 实践项目

### 项目：高性能结构化日志系统

**项目结构**：

```
logger/
├── CMakeLists.txt
├── include/
│   └── logger/
│       ├── logger.hpp          # 主要API
│       ├── config.hpp          # 配置定义
│       ├── sink.hpp            # Sink接口
│       ├── formatter.hpp       # 格式化器
│       ├── sampler.hpp         # 采样器
│       ├── masker.hpp          # 数据脱敏
│       └── context.hpp         # 日志上下文
├── src/
│   ├── logger.cpp
│   ├── config.cpp
│   └── sinks/
│       ├── console_sink.cpp
│       ├── file_sink.cpp
│       ├── rotating_sink.cpp
│       └── network_sink.cpp
├── tests/
│   ├── test_logger.cpp
│   ├── test_sampler.cpp
│   └── test_masker.cpp
├── benchmarks/
│   └── benchmark_logger.cpp
└── examples/
    ├── basic_usage.cpp
    ├── structured_logging.cpp
    └── distributed_tracing.cpp
```

**CMakeLists.txt**：
```cmake
cmake_minimum_required(VERSION 3.14)
project(logger VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 依赖
find_package(spdlog CONFIG REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)

# 库
add_library(logger
    src/logger.cpp
    src/config.cpp
    src/sinks/console_sink.cpp
    src/sinks/file_sink.cpp
    src/sinks/rotating_sink.cpp
)

target_include_directories(logger PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

target_link_libraries(logger
    PUBLIC spdlog::spdlog
    PUBLIC nlohmann_json::nlohmann_json
)

# 测试
enable_testing()
add_executable(test_logger tests/test_logger.cpp)
target_link_libraries(test_logger logger)
add_test(NAME test_logger COMMAND test_logger)

# 基准测试
add_executable(benchmark_logger benchmarks/benchmark_logger.cpp)
target_link_libraries(benchmark_logger logger)

# 示例
add_executable(example_basic examples/basic_usage.cpp)
target_link_libraries(example_basic logger)
```

---

## 检验标准

- [ ] 能够配置和使用spdlog的各种功能
- [ ] 理解同步和异步日志的区别和适用场景
- [ ] 能够实现结构化JSON日志
- [ ] 能够设计多sink日志系统
- [ ] 理解日志采样策略和实现
- [ ] 能够实现敏感数据脱敏
- [ ] 理解分布式追踪的基本概念
- [ ] 能够设计生产级日志系统

---

## 输出物清单

1. **项目代码**
   - `logger/` - 完整的日志系统实现

2. **配置模板**
   - 开发环境配置
   - 生产环境配置
   - 高性能配置

3. **文档**
   - `notes/month46_logging.md` - 学习笔记
   - `notes/logging_best_practices.md` - 最佳实践总结
   - `notes/spdlog_source_analysis.md` - spdlog源码分析

---

## 时间分配表

| 周次 | 主题 | 理论学习 | 实践编码 | 源码阅读 |
|------|------|----------|----------|----------|
| 第1周 | 日志系统基础与spdlog | 15h | 15h | 5h |
| 第2周 | 异步日志设计 | 12h | 18h | 5h |
| 第3周 | 结构化日志 | 10h | 20h | 5h |
| 第4周 | 最佳实践与综合项目 | 8h | 22h | 5h |
| **合计** | | **45h** | **75h** | **20h** |

---

## 下月预告

Month 47将学习**指标收集与监控**，构建应用的可观测性系统，包括：
- Prometheus 指标收集
- Grafana 可视化
- 告警规则设计
- 应用性能监控（APM）
