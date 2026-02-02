# Month 30: Reactor模式——事件驱动架构

> **本月主题**：深入学习Reactor模式，掌握事件驱动架构的核心思想与实现技术
> **前置知识**：Month-29 零拷贝技术（sendfile、splice、mmap）
> **学习时长**：140小时（4周 × 35小时/周）
> **难度评级**：★★★★☆（高级进阶）

---

## 本月导航

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Month 30 学习路径导航                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  第一周                第二周                第三周                第四周     │
│  ┌─────────┐          ┌─────────┐          ┌─────────┐          ┌─────────┐ │
│  │ Reactor │    →     │单线程    │    →     │多线程    │    →     │主从     │ │
│  │ 模式概述 │          │Reactor  │          │Reactor  │          │Reactor  │ │
│  │         │          │实现      │          │         │          │模式      │ │
│  └────┬────┘          └────┬────┘          └────┬────┘          └────┬────┘ │
│       │                    │                    │                    │      │
│       ▼                    ▼                    ▼                    ▼      │
│  ┌─────────┐          ┌─────────┐          ┌─────────┐          ┌─────────┐ │
│  │• 核心思想│          │• EventLoop│        │• ThreadPool│        │• MainReactor│
│  │• 组件模型│          │• Channel │          │• 线程安全 │          │• SubReactor│
│  │• 多路复用│          │• Acceptor│          │• runInLoop│          │• muduo分析│
│  │• epoll  │          │• Buffer  │          │• 同步机制 │          │• 完整框架│
│  └─────────┘          └─────────┘          └─────────┘          └─────────┘ │
│                                                                             │
│  ════════════════════════════════════════════════════════════════════════  │
│                                                                             │
│                          学习成果：完整的Reactor网络框架                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 本月主题概述

### 为什么学习Reactor模式？

Reactor模式是高性能网络服务器的核心架构，几乎所有现代网络框架都基于这一模式：

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Reactor模式在现代系统中的应用                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         经典实现                                      │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                     │   │
│  │   Redis          Nginx          Node.js        Netty               │   │
│  │   ┌───┐          ┌───┐          ┌───┐          ┌───┐               │   │
│  │   │ R │          │ R │          │ R │          │ R │               │   │
│  │   └───┘          └───┘          └───┘          └───┘               │   │
│  │   单线程         多进程          单线程         主从                  │   │
│  │   Reactor        Reactor        Reactor        Reactor             │   │
│  │                                                                     │   │
│  │   libevent       libuv          muduo          Boost.Asio          │   │
│  │   ┌───┐          ┌───┐          ┌───┐          ┌───┐               │   │
│  │   │ R │          │ R │          │ R │          │ R │               │   │
│  │   └───┘          └───┘          └───┘          └───┘               │   │
│  │   跨平台         跨平台          one loop       Proactor            │   │
│  │   Reactor        Reactor        per thread     模拟                 │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  应用场景：                                                                  │
│  • 高并发网络服务器（10K+ 连接）                                              │
│  • 实时消息系统                                                              │
│  • 游戏服务器                                                                │
│  • API网关                                                                   │
│  • 代理服务器                                                                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 与Month-29的衔接

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    零拷贝 + Reactor = 高性能网络服务器                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Month-29 零拷贝技术                    Month-30 Reactor模式               │
│   ┌────────────────────┐                ┌────────────────────┐             │
│   │ • sendfile         │                │ • 事件驱动         │             │
│   │ • splice/vmsplice  │   +            │ • 非阻塞I/O        │   =         │
│   │ • mmap             │                │ • I/O多路复用      │             │
│   │ • 减少数据拷贝     │                │ • 高效调度         │             │
│   └────────────────────┘                └────────────────────┘             │
│                                                                             │
│                              ▼                                              │
│                                                                             │
│                 ┌────────────────────────────────┐                         │
│                 │    高性能网络服务器架构         │                         │
│                 ├────────────────────────────────┤                         │
│                 │ • 单机百万连接                 │                         │
│                 │ • 低延迟响应                   │                         │
│                 │ • 高吞吐量                     │                         │
│                 │ • 资源高效利用                 │                         │
│                 └────────────────────────────────┘                         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 知识体系总览

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Reactor模式知识体系                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                           理论基础                                    │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Douglas Schmidt     │  POSA Vol.2      │  事件驱动架构              │   │
│  │  Reactor论文         │  设计模式         │  演进历史                  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│                                    ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                           核心组件                                    │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                     │   │
│  │    Handle            Event Handler        Demultiplexer             │   │
│  │   ┌─────┐            ┌─────────────┐      ┌──────────────┐          │   │
│  │   │ fd  │            │ callback    │      │ select/poll  │          │   │
│  │   └─────┘            │ interface   │      │ epoll/kqueue │          │   │
│  │                      └─────────────┘      └──────────────┘          │   │
│  │                              │                    │                  │   │
│  │                              └────────┬───────────┘                  │   │
│  │                                       ▼                              │   │
│  │                              ┌─────────────┐                         │   │
│  │                              │   Reactor   │                         │   │
│  │                              │  注册/分发   │                         │   │
│  │                              └─────────────┘                         │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│                                    ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                          实现模式                                     │   │
│  ├──────────────────┬──────────────────┬──────────────────────────────┤   │
│  │   单线程Reactor   │  多线程Reactor   │      主从Reactor             │   │
│  │   ┌────────────┐ │ ┌──────────────┐ │ ┌────────────────────────┐   │   │
│  │   │ EventLoop  │ │ │Reactor       │ │ │ MainReactor            │   │   │
│  │   │ + Channel  │ │ │+ ThreadPool  │ │ │ + SubReactor×N         │   │   │
│  │   └────────────┘ │ └──────────────┘ │ └────────────────────────┘   │   │
│  │                  │                  │                              │   │
│  │   适用：低并发   │  适用：计算密集  │  适用：高并发I/O密集         │   │
│  └──────────────────┴──────────────────┴──────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 本月学习目标

### 理论目标

| 序号 | 目标 | 验证方式 |
|:----:|------|----------|
| T1 | 理解Reactor模式的核心思想 | 能够画出Reactor架构图并解释 |
| T2 | 掌握事件多路复用机制 | 能够比较select/poll/epoll |
| T3 | 理解LT与ET触发模式 | 能够解释区别及适用场景 |
| T4 | 掌握EventLoop设计原理 | 能够实现完整EventLoop |
| T5 | 理解Channel抽象的作用 | 能够解释fd与回调的绑定 |
| T6 | 掌握线程池设计 | 能够实现高效线程池 |
| T7 | 理解one loop per thread | 能够解释其优势 |
| T8 | 掌握主从Reactor架构 | 能够设计完整架构 |

### 实践目标

| 序号 | 目标 | 产出物 |
|:----:|------|--------|
| P1 | 实现select/poll/epoll对比 | `multiplexer_compare.cpp` |
| P2 | 实现单线程Reactor | `single_reactor/` |
| P3 | 实现线程池 | `thread_pool.hpp` |
| P4 | 实现多线程Reactor | `multi_thread_reactor/` |
| P5 | 实现主从Reactor | `master_slave_reactor/` |
| P6 | 分析muduo源码 | `notes/muduo_analysis.md` |
| P7 | 实现完整Reactor框架 | `reactor_framework/` |
| P8 | 性能测试与调优 | `benchmark/` |

---

## 第一周：Reactor模式概述（Day 1-7）

> **本周目标**：理解Reactor模式的核心思想与组件模型，深入掌握事件多路复用机制
> **学习时长**：35小时
> **核心产出**：多路复用对比实验代码

---

### Day 1-2：Reactor模式起源与核心思想（10小时）

#### 1.1 Reactor模式的历史背景

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        事件驱动架构演进历史                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1970s-1980s                    1990s                      2000s-至今       │
│  ┌────────────────┐            ┌────────────────┐         ┌──────────────┐ │
│  │  阻塞I/O       │            │ Douglas Schmidt │         │  现代框架    │ │
│  │  + 多进程/线程 │  ────────→ │ 提出Reactor    │ ──────→ │  广泛应用    │ │
│  │                │            │ 模式           │         │              │ │
│  └────────────────┘            └────────────────┘         └──────────────┘ │
│                                                                             │
│  问题：                         解决方案：                   应用：          │
│  • 每连接一线程                 • 事件驱动                 • Nginx         │
│  • 资源消耗大                   • 非阻塞I/O               • Redis         │
│  • 上下文切换开销               • I/O多路复用              • Node.js       │
│  • 难以扩展                     • 回调机制                 • Netty         │
│                                                                             │
│  ═══════════════════════════════════════════════════════════════════════   │
│                                                                             │
│  Douglas Schmidt (1994)                                                     │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ "An Object Behavioral Pattern for Demultiplexing and Dispatching    │   │
│  │  Handles for Synchronous Events"                                    │   │
│  │                                                                     │   │
│  │  ACE (Adaptive Communication Environment) 框架                       │   │
│  │  - 最早的跨平台Reactor实现                                           │   │
│  │  - 影响了后来的所有网络框架设计                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 1.2 传统多线程模型的问题

```cpp
// traditional_server.cpp - 传统的每连接一线程模型
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <thread>
#include <vector>
#include <iostream>

/*
传统模型架构：

    Client1 ──────┐
                  │     ┌─────────────┐
    Client2 ──────┼────→│   Accept    │
                  │     │   Thread    │
    Client3 ──────┘     └──────┬──────┘
                               │
                               ▼
              ┌────────────────┼────────────────┐
              │                │                │
              ▼                ▼                ▼
        ┌──────────┐    ┌──────────┐    ┌──────────┐
        │ Thread 1 │    │ Thread 2 │    │ Thread 3 │
        │ handle   │    │ handle   │    │ handle   │
        │ client1  │    │ client2  │    │ client3  │
        └──────────┘    └──────────┘    └──────────┘

问题分析：
1. 线程资源消耗：
   - 每个线程栈默认8MB（可配置）
   - 10000连接 = 80GB内存（仅栈空间）

2. 上下文切换开销：
   - 保存/恢复寄存器
   - 切换页表
   - 刷新TLB和Cache
   - 10000线程时切换开销巨大

3. 难以扩展：
   - C10K问题（单机10000连接）
   - 线程数受限于系统资源
*/

class TraditionalServer {
public:
    TraditionalServer(int port) : port_(port) {}

    bool start() {
        listen_fd_ = socket(AF_INET, SOCK_STREAM, 0);
        if (listen_fd_ < 0) {
            perror("socket");
            return false;
        }

        int opt = 1;
        setsockopt(listen_fd_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = INADDR_ANY;
        addr.sin_port = htons(port_);

        if (bind(listen_fd_, (sockaddr*)&addr, sizeof(addr)) < 0) {
            perror("bind");
            return false;
        }

        if (listen(listen_fd_, SOMAXCONN) < 0) {
            perror("listen");
            return false;
        }

        return true;
    }

    void run() {
        std::cout << "Traditional server running on port " << port_ << std::endl;

        while (running_) {
            sockaddr_in client_addr{};
            socklen_t client_len = sizeof(client_addr);

            // 阻塞等待连接
            int client_fd = accept(listen_fd_, (sockaddr*)&client_addr, &client_len);
            if (client_fd < 0) {
                if (errno == EINTR) continue;
                perror("accept");
                continue;
            }

            // 为每个连接创建新线程
            // 问题：连接数增加时，线程数也线性增加
            std::thread([this, client_fd]() {
                handle_client(client_fd);
            }).detach();
        }
    }

    void stop() {
        running_ = false;
        if (listen_fd_ >= 0) close(listen_fd_);
    }

private:
    void handle_client(int client_fd) {
        char buffer[1024];

        while (true) {
            // 阻塞读取
            ssize_t n = read(client_fd, buffer, sizeof(buffer));

            if (n <= 0) {
                if (n < 0) perror("read");
                break;
            }

            // 阻塞写入
            ssize_t written = write(client_fd, buffer, n);
            if (written < 0) {
                perror("write");
                break;
            }
        }

        close(client_fd);
    }

private:
    int port_;
    int listen_fd_ = -1;
    bool running_ = true;
};

/*
性能问题量化分析：

场景：10000并发连接

传统多线程模型：
┌─────────────────────────────────────────────────────────────┐
│ 资源消耗                                                    │
├─────────────────────────────────────────────────────────────┤
│ 线程栈（假设1MB/线程）：10000 × 1MB = 10GB                  │
│ 线程控制块：10000 × ~8KB = 80MB                             │
│ 上下文切换：10000线程 × ~1μs/切换 = 严重延迟                │
│ 调度开销：O(n)或O(log n)                                    │
└─────────────────────────────────────────────────────────────┘

Reactor模型（单线程）：
┌─────────────────────────────────────────────────────────────┐
│ 资源消耗                                                    │
├─────────────────────────────────────────────────────────────┤
│ 线程栈：1 × 8MB = 8MB                                       │
│ 连接上下文：10000 × ~1KB = 10MB                             │
│ 无线程切换开销                                               │
│ epoll事件分发：O(1)                                          │
└─────────────────────────────────────────────────────────────┘
*/
```

#### 1.3 Reactor模式核心思想

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Reactor模式核心思想                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  核心理念：事件分离与分发                                                    │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                                                                     │   │
│  │   传统模型：                    Reactor模型：                        │   │
│  │                                                                     │   │
│  │   ┌─────┐                      ┌─────────────────────┐              │   │
│  │   │     │ 阻塞等待             │                     │              │   │
│  │   │ I/O │ ─────────→           │      Reactor        │              │   │
│  │   │     │ 数据到达             │                     │              │   │
│  │   └─────┘                      │  1. 注册感兴趣的事件│              │   │
│  │      │                         │  2. 等待事件发生    │              │   │
│  │      ▼                         │  3. 分发给处理器    │              │   │
│  │   处理数据                     │                     │              │   │
│  │                                └──────────┬──────────┘              │   │
│  │   问题：阻塞期间                          │                         │   │
│  │   线程无法做其他事               事件1 ───┼─── 事件2                │   │
│  │                                    │      │      │                  │   │
│  │                                    ▼      ▼      ▼                  │   │
│  │                               Handler1 Handler2 Handler3           │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ═══════════════════════════════════════════════════════════════════════   │
│                                                                             │
│  Reactor模式的三个关键点：                                                  │
│                                                                             │
│  1. 事件驱动（Event-Driven）                                                │
│     ┌─────────────────────────────────────────────────────────────────┐   │
│     │ • 不主动轮询，而是等待事件通知                                    │   │
│     │ • 只在有事件时才执行处理逻辑                                      │   │
│     │ • 避免忙等待，提高CPU利用率                                       │   │
│     └─────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  2. 非阻塞I/O（Non-blocking I/O）                                          │
│     ┌─────────────────────────────────────────────────────────────────┐   │
│     │ • I/O操作立即返回，不阻塞线程                                     │   │
│     │ • 通过返回值判断操作状态                                          │   │
│     │ • 配合I/O多路复用使用                                             │   │
│     └─────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  3. I/O多路复用（I/O Multiplexing）                                        │
│     ┌─────────────────────────────────────────────────────────────────┐   │
│     │ • 单线程同时监控多个fd                                            │   │
│     │ • 内核通知哪些fd就绪                                              │   │
│     │ • select/poll/epoll实现                                           │   │
│     └─────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 1.4 Reactor与传统模型对比

```cpp
// reactor_vs_traditional.cpp - 两种模型的对比演示
#include <iostream>
#include <chrono>
#include <vector>
#include <sys/epoll.h>
#include <fcntl.h>

/*
┌─────────────────────────────────────────────────────────────────────────────┐
│                     Reactor vs 传统多线程模型对比                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  维度              │  传统多线程          │  Reactor                        │
│  ─────────────────┼──────────────────────┼─────────────────────────────────│
│  线程模型          │  每连接一线程        │  单线程/少量线程                  │
│  资源消耗          │  高（线程栈、TCB）   │  低（仅连接上下文）              │
│  上下文切换        │  频繁                │  几乎没有                        │
│  编程模型          │  同步阻塞，直观      │  异步回调，较复杂                │
│  适用场景          │  低并发、长连接      │  高并发、短连接                  │
│  扩展性            │  差（受线程数限制）  │  好（单机百万连接）              │
│  调试难度          │  低                  │  中等                            │
│  CPU利用率         │  低（大量阻塞）      │  高（事件驱动）                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
*/

// 性能对比数据结构
struct PerformanceMetrics {
    size_t connections;
    size_t memory_usage_mb;
    double latency_us;
    double throughput_qps;
};

// 理论分析函数
void analyze_traditional_model(size_t connections) {
    std::cout << "\n=== 传统多线程模型分析 ===" << std::endl;
    std::cout << "连接数: " << connections << std::endl;

    // 计算资源消耗
    size_t stack_per_thread = 1;  // MB，可通过ulimit配置
    size_t tcb_per_thread = 8;    // KB，线程控制块

    size_t total_stack = connections * stack_per_thread;
    size_t total_tcb = connections * tcb_per_thread / 1024;

    std::cout << "线程栈总消耗: " << total_stack << " MB" << std::endl;
    std::cout << "TCB总消耗: " << total_tcb << " MB" << std::endl;
    std::cout << "总内存消耗: " << (total_stack + total_tcb) << " MB" << std::endl;

    // 上下文切换开销估算
    // 假设每个连接每秒100次I/O操作，每次操作可能触发切换
    double switches_per_second = connections * 100;
    double switch_overhead_us = 1.0;  // 微秒
    double total_overhead_ms = switches_per_second * switch_overhead_us / 1000;

    std::cout << "每秒上下文切换: " << switches_per_second << std::endl;
    std::cout << "切换开销: " << total_overhead_ms << " ms/秒" << std::endl;
}

void analyze_reactor_model(size_t connections) {
    std::cout << "\n=== Reactor模型分析 ===" << std::endl;
    std::cout << "连接数: " << connections << std::endl;

    // Reactor模型资源消耗
    size_t reactor_threads = 4;  // 主从Reactor，假设4个工作线程
    size_t stack_per_thread = 1; // MB
    size_t conn_context = 1;     // KB，每连接上下文

    size_t total_stack = reactor_threads * stack_per_thread;
    size_t total_context = connections * conn_context / 1024;

    std::cout << "线程栈总消耗: " << total_stack << " MB" << std::endl;
    std::cout << "连接上下文消耗: " << total_context << " MB" << std::endl;
    std::cout << "总内存消耗: " << (total_stack + total_context) << " MB" << std::endl;

    // epoll开销
    std::cout << "epoll事件复杂度: O(1)" << std::endl;
    std::cout << "无线程上下文切换开销" << std::endl;
}

/*
实际对比结果（10000连接）：

┌─────────────────────────────────────────────────────────────────────────────┐
│                          10000 连接资源对比                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────┐    ┌─────────────────────────────┐        │
│  │      传统多线程模型          │    │        Reactor模型          │        │
│  ├─────────────────────────────┤    ├─────────────────────────────┤        │
│  │  线程数: 10000              │    │  线程数: 4                  │        │
│  │  线程栈: 10000 MB           │    │  线程栈: 4 MB               │        │
│  │  TCB: ~80 MB                │    │  连接上下文: ~10 MB         │        │
│  │  ─────────────────          │    │  ─────────────────          │        │
│  │  总计: ~10080 MB            │    │  总计: ~14 MB               │        │
│  │                             │    │                             │        │
│  │  上下文切换: 频繁           │    │  上下文切换: 几乎没有       │        │
│  │  调度开销: 高               │    │  调度开销: 低               │        │
│  └─────────────────────────────┘    └─────────────────────────────┘        │
│                                                                             │
│  内存节省: ~99.86%                                                          │
│  性能提升: 5-10倍（取决于场景）                                             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
*/

int main() {
    std::vector<size_t> connection_counts = {100, 1000, 10000, 100000};

    for (size_t count : connection_counts) {
        std::cout << "\n" << std::string(60, '=') << std::endl;
        std::cout << "分析场景: " << count << " 并发连接" << std::endl;
        std::cout << std::string(60, '=') << std::endl;

        analyze_traditional_model(count);
        analyze_reactor_model(count);
    }

    return 0;
}
```

---

### Day 3-4：Reactor模式核心组件（10小时）

#### 2.1 组件架构图

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Reactor模式组件架构                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│                              ┌─────────────────┐                            │
│                              │   Application   │                            │
│                              └────────┬────────┘                            │
│                                       │                                     │
│                                       │ 创建/使用                           │
│                                       ▼                                     │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         Concrete Event Handler                       │   │
│  │  ┌────────────────┐ ┌────────────────┐ ┌────────────────┐           │   │
│  │  │ AcceptHandler  │ │  ReadHandler   │ │  WriteHandler  │           │   │
│  │  └───────┬────────┘ └───────┬────────┘ └───────┬────────┘           │   │
│  │          │                  │                  │                     │   │
│  │          └──────────────────┼──────────────────┘                     │   │
│  │                             │                                        │   │
│  └─────────────────────────────┼────────────────────────────────────────┘   │
│                                │ 实现接口                                   │
│                                ▼                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                          Event Handler                               │   │
│  │  ┌──────────────────────────────────────────────────────────────┐   │   │
│  │  │  virtual int handle() = 0;           // 返回关联的Handle     │   │   │
│  │  │  virtual void handle_read() = 0;     // 处理读事件           │   │   │
│  │  │  virtual void handle_write() = 0;    // 处理写事件           │   │   │
│  │  │  virtual void handle_close() = 0;    // 处理关闭事件         │   │   │
│  │  └──────────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────┬────────────────────────────────────────┘   │
│                                │ 注册到                                     │
│                                ▼                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                            Reactor                                   │   │
│  │  ┌──────────────────────────────────────────────────────────────┐   │   │
│  │  │  register_handler(handler, events)  // 注册处理器            │   │   │
│  │  │  remove_handler(handle)             // 移除处理器            │   │   │
│  │  │  run()                              // 事件循环              │   │   │
│  │  │  stop()                             // 停止循环              │   │   │
│  │  └──────────────────────────────────────────────────────────────┘   │   │
│  │                                │                                     │   │
│  │                                │ 使用                                │   │
│  │                                ▼                                     │   │
│  │  ┌──────────────────────────────────────────────────────────────┐   │   │
│  │  │            Synchronous Event Demultiplexer                   │   │   │
│  │  │                                                              │   │   │
│  │  │   select()  │  poll()  │  epoll_wait()  │  kqueue()         │   │   │
│  │  │                                                              │   │   │
│  │  └──────────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                │                                            │
│                                │ 监控                                       │
│                                ▼                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                            Handle                                    │   │
│  │  ┌──────────────────────────────────────────────────────────────┐   │   │
│  │  │  文件描述符(fd) - 操作系统资源标识                            │   │   │
│  │  │  • socket fd                                                  │   │   │
│  │  │  • pipe fd                                                    │   │   │
│  │  │  • eventfd                                                    │   │   │
│  │  │  • timerfd                                                    │   │   │
│  │  └──────────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 2.2 组件详解与实现

```cpp
// reactor_components.hpp - Reactor模式核心组件
#pragma once

#include <sys/epoll.h>
#include <unistd.h>
#include <functional>
#include <unordered_map>
#include <memory>
#include <vector>
#include <iostream>

/*
组件职责划分：

┌─────────────────────────────────────────────────────────────────────────────┐
│  组件                │  职责                        │  生命周期管理          │
├─────────────────────────────────────────────────────────────────────────────┤
│  Handle              │  OS资源标识（fd）            │  由具体处理器管理      │
│  Event Handler       │  定义事件处理接口            │  抽象基类              │
│  Concrete Handler    │  实现具体事件处理逻辑        │  应用程序管理          │
│  Demultiplexer       │  等待并返回就绪事件          │  Reactor管理           │
│  Reactor             │  注册处理器、分发事件        │  应用程序管理          │
└─────────────────────────────────────────────────────────────────────────────┘
*/

namespace reactor {

// =============================================================================
// Handle - 操作系统资源标识
// =============================================================================

// Handle就是文件描述符，在POSIX系统中是int类型
// 可以是socket、pipe、eventfd、timerfd等
using Handle = int;

constexpr Handle INVALID_HANDLE = -1;

// =============================================================================
// Event Handler - 事件处理器接口
// =============================================================================

class EventHandler {
public:
    virtual ~EventHandler() = default;

    // 返回关联的Handle（fd）
    virtual Handle handle() const = 0;

    // 处理可读事件
    virtual void handle_read() = 0;

    // 处理可写事件
    virtual void handle_write() = 0;

    // 处理关闭/错误事件
    virtual void handle_close() = 0;

    // 处理错误事件（可选，默认调用handle_close）
    virtual void handle_error() { handle_close(); }
};

// =============================================================================
// Event Types - 事件类型
// =============================================================================

enum EventType : uint32_t {
    EVENT_NONE   = 0,
    EVENT_READ   = EPOLLIN,
    EVENT_WRITE  = EPOLLOUT,
    EVENT_ERROR  = EPOLLERR,
    EVENT_CLOSE  = EPOLLHUP | EPOLLRDHUP,
    EVENT_ET     = EPOLLET,    // 边缘触发
    EVENT_ONESHOT = EPOLLONESHOT  // 一次性事件
};

// =============================================================================
// Synchronous Event Demultiplexer - 同步事件多路分离器
// =============================================================================

class Demultiplexer {
public:
    Demultiplexer() {
        epfd_ = epoll_create1(EPOLL_CLOEXEC);
        if (epfd_ < 0) {
            throw std::runtime_error("Failed to create epoll instance");
        }
    }

    ~Demultiplexer() {
        if (epfd_ >= 0) {
            close(epfd_);
        }
    }

    // 禁止拷贝
    Demultiplexer(const Demultiplexer&) = delete;
    Demultiplexer& operator=(const Demultiplexer&) = delete;

    // 注册Handle和事件
    bool add(Handle handle, uint32_t events) {
        epoll_event ev{};
        ev.events = events;
        ev.data.fd = handle;
        return epoll_ctl(epfd_, EPOLL_CTL_ADD, handle, &ev) == 0;
    }

    // 修改监听的事件
    bool modify(Handle handle, uint32_t events) {
        epoll_event ev{};
        ev.events = events;
        ev.data.fd = handle;
        return epoll_ctl(epfd_, EPOLL_CTL_MOD, handle, &ev) == 0;
    }

    // 移除Handle
    bool remove(Handle handle) {
        return epoll_ctl(epfd_, EPOLL_CTL_DEL, handle, nullptr) == 0;
    }

    // 等待事件，返回就绪的Handle数量
    int wait(std::vector<epoll_event>& events, int timeout_ms) {
        return epoll_wait(epfd_, events.data(),
                         static_cast<int>(events.size()), timeout_ms);
    }

private:
    int epfd_ = -1;
};

// =============================================================================
// Reactor - 反应器（事件分发中心）
// =============================================================================

class Reactor {
public:
    Reactor() : events_(1024) {}

    ~Reactor() {
        stop();
    }

    // 注册事件处理器
    void register_handler(std::shared_ptr<EventHandler> handler, uint32_t events) {
        Handle h = handler->handle();
        handlers_[h] = handler;

        if (!demux_.add(h, events)) {
            handlers_.erase(h);
            throw std::runtime_error("Failed to register handler");
        }

        std::cout << "[Reactor] Registered handler for fd " << h << std::endl;
    }

    // 修改事件处理器的监听事件
    void modify_events(Handle handle, uint32_t events) {
        if (handlers_.find(handle) == handlers_.end()) {
            throw std::runtime_error("Handler not found");
        }
        demux_.modify(handle, events);
    }

    // 移除事件处理器
    void remove_handler(Handle handle) {
        demux_.remove(handle);
        handlers_.erase(handle);
        std::cout << "[Reactor] Removed handler for fd " << handle << std::endl;
    }

    // 运行事件循环
    void run() {
        running_ = true;
        std::cout << "[Reactor] Event loop started" << std::endl;

        while (running_) {
            // 等待事件，超时1秒
            int n = demux_.wait(events_, 1000);

            if (n < 0) {
                if (errno == EINTR) continue;
                perror("epoll_wait");
                break;
            }

            // 分发事件
            for (int i = 0; i < n; ++i) {
                dispatch_event(events_[i]);
            }
        }

        std::cout << "[Reactor] Event loop stopped" << std::endl;
    }

    // 停止事件循环
    void stop() {
        running_ = false;
    }

private:
    void dispatch_event(const epoll_event& ev) {
        Handle h = ev.data.fd;
        auto it = handlers_.find(h);

        if (it == handlers_.end()) {
            std::cerr << "[Reactor] No handler for fd " << h << std::endl;
            return;
        }

        auto& handler = it->second;
        uint32_t events = ev.events;

        // 错误或关闭事件优先处理
        if (events & (EPOLLERR | EPOLLHUP | EPOLLRDHUP)) {
            handler->handle_close();
            return;
        }

        // 可读事件
        if (events & EPOLLIN) {
            handler->handle_read();
        }

        // 可写事件
        if (events & EPOLLOUT) {
            handler->handle_write();
        }
    }

private:
    Demultiplexer demux_;
    std::unordered_map<Handle, std::shared_ptr<EventHandler>> handlers_;
    std::vector<epoll_event> events_;
    bool running_ = false;
};

} // namespace reactor
```

#### 2.3 组件交互序列

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Reactor模式交互序列图                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Application      Reactor        Demultiplexer      Handler      Handle    │
│      │              │                │                │            │        │
│      │  1.创建      │                │                │            │        │
│      │─────────────→│                │                │            │        │
│      │              │                │                │            │        │
│      │  2.创建处理器│                │                │  3.创建    │        │
│      │──────────────────────────────────────────────→│───────────→│        │
│      │              │                │                │            │        │
│      │  4.注册      │                │                │            │        │
│      │─────────────→│  5.添加到      │                │            │        │
│      │              │  epoll         │                │            │        │
│      │              │───────────────→│                │            │        │
│      │              │                │                │            │        │
│      │  6.run()    │                │                │            │        │
│      │─────────────→│  7.等待事件    │                │            │        │
│      │              │───────────────→│                │            │        │
│      │              │                │                │            │        │
│      │              │                │  8.事件到达    │            │        │
│      │              │                │◀═══════════════════════════╡        │
│      │              │                │                │            │        │
│      │              │  9.返回就绪    │                │            │        │
│      │              │◀───────────────│                │            │        │
│      │              │                │                │            │        │
│      │              │  10.分发事件   │                │            │        │
│      │              │───────────────────────────────→│            │        │
│      │              │                │                │            │        │
│      │              │                │                │  11.处理   │        │
│      │              │                │                │───────────→│        │
│      │              │                │                │            │        │
│      │              │                │                │  12.I/O    │        │
│      │              │                │                │◀───────────│        │
│      │              │                │                │            │        │
│      │              │  7.继续等待    │                │            │        │
│      │              │───────────────→│                │            │        │
│      │              │                │                │            │        │
│      │              │      ... 循环 ...              │            │        │
│      │              │                │                │            │        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 2.4 具体处理器示例

```cpp
// concrete_handlers.hpp - 具体事件处理器实现
#pragma once

#include "reactor_components.hpp"
#include <sys/socket.h>
#include <netinet/in.h>
#include <fcntl.h>
#include <cstring>

namespace reactor {

// 设置文件描述符为非阻塞
inline bool set_nonblocking(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags < 0) return false;
    return fcntl(fd, F_SETFL, flags | O_NONBLOCK) >= 0;
}

// =============================================================================
// Acceptor Handler - 接受新连接的处理器
// =============================================================================

class AcceptHandler : public EventHandler {
public:
    using NewConnectionCallback = std::function<void(int client_fd)>;

    AcceptHandler(int port, NewConnectionCallback callback)
        : callback_(std::move(callback)) {

        // 创建监听socket
        listen_fd_ = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK, 0);
        if (listen_fd_ < 0) {
            throw std::runtime_error("Failed to create socket");
        }

        // 设置地址重用
        int opt = 1;
        setsockopt(listen_fd_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

        // 绑定地址
        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = INADDR_ANY;
        addr.sin_port = htons(port);

        if (bind(listen_fd_, (sockaddr*)&addr, sizeof(addr)) < 0) {
            close(listen_fd_);
            throw std::runtime_error("Failed to bind");
        }

        // 开始监听
        if (listen(listen_fd_, SOMAXCONN) < 0) {
            close(listen_fd_);
            throw std::runtime_error("Failed to listen");
        }

        std::cout << "[AcceptHandler] Listening on port " << port << std::endl;
    }

    ~AcceptHandler() {
        if (listen_fd_ >= 0) {
            close(listen_fd_);
        }
    }

    Handle handle() const override { return listen_fd_; }

    void handle_read() override {
        // 接受所有待处理的连接（边缘触发模式下必须这样做）
        while (true) {
            sockaddr_in client_addr{};
            socklen_t client_len = sizeof(client_addr);

            int client_fd = accept4(listen_fd_,
                                   (sockaddr*)&client_addr,
                                   &client_len,
                                   SOCK_NONBLOCK);

            if (client_fd < 0) {
                if (errno == EAGAIN || errno == EWOULDBLOCK) {
                    // 没有更多连接了
                    break;
                }
                perror("accept");
                continue;
            }

            std::cout << "[AcceptHandler] New connection: fd=" << client_fd << std::endl;

            // 通知应用程序处理新连接
            if (callback_) {
                callback_(client_fd);
            }
        }
    }

    void handle_write() override {
        // AcceptHandler不需要处理写事件
    }

    void handle_close() override {
        std::cout << "[AcceptHandler] Closing listen socket" << std::endl;
        if (listen_fd_ >= 0) {
            close(listen_fd_);
            listen_fd_ = -1;
        }
    }

private:
    int listen_fd_ = -1;
    NewConnectionCallback callback_;
};

// =============================================================================
// Echo Handler - Echo服务的连接处理器
// =============================================================================

class EchoHandler : public EventHandler,
                    public std::enable_shared_from_this<EchoHandler> {
public:
    EchoHandler(int fd, Reactor& reactor)
        : fd_(fd), reactor_(reactor) {}

    ~EchoHandler() {
        if (fd_ >= 0) {
            close(fd_);
        }
    }

    Handle handle() const override { return fd_; }

    void handle_read() override {
        char buf[4096];

        while (true) {
            ssize_t n = read(fd_, buf, sizeof(buf));

            if (n > 0) {
                // 将数据加入发送缓冲区
                write_buffer_.append(buf, n);

                // 启用写事件
                reactor_.modify_events(fd_, EVENT_READ | EVENT_WRITE | EVENT_ET);

            } else if (n == 0) {
                // 对端关闭
                handle_close();
                return;

            } else {
                if (errno == EAGAIN || errno == EWOULDBLOCK) {
                    break;
                }
                handle_close();
                return;
            }
        }
    }

    void handle_write() override {
        while (!write_buffer_.empty()) {
            ssize_t n = write(fd_, write_buffer_.data(), write_buffer_.size());

            if (n > 0) {
                write_buffer_.erase(0, n);

            } else if (n < 0) {
                if (errno == EAGAIN || errno == EWOULDBLOCK) {
                    break;
                }
                handle_close();
                return;
            }
        }

        // 如果缓冲区空了，禁用写事件
        if (write_buffer_.empty()) {
            reactor_.modify_events(fd_, EVENT_READ | EVENT_ET);
        }
    }

    void handle_close() override {
        std::cout << "[EchoHandler] Closing connection: fd=" << fd_ << std::endl;
        reactor_.remove_handler(fd_);
        // 注意：remove_handler后不要再访问成员变量
        // shared_ptr引用计数可能已经归零
    }

private:
    int fd_;
    Reactor& reactor_;
    std::string write_buffer_;
};

} // namespace reactor
```

---

### Day 5-7：事件多路复用深入（15小时）

#### 3.1 select、poll、epoll对比

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    事件多路复用机制对比                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                          select (1983)                               │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                     │   │
│  │  工作原理：                                                          │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │  1. 用户态准备fd_set位图（读、写、异常各一个）               │   │   │
│  │  │  2. 将fd_set拷贝到内核态                                     │   │   │
│  │  │  3. 内核遍历所有fd，检查就绪状态                             │   │   │
│  │  │  4. 修改fd_set，标记就绪的fd                                 │   │   │
│  │  │  5. 将fd_set拷贝回用户态                                     │   │   │
│  │  │  6. 用户遍历fd_set找出就绪的fd                               │   │   │
│  │  └─────────────────────────────────────────────────────────────┘   │   │
│  │                                                                     │   │
│  │  限制：                                                              │   │
│  │  • fd数量限制：FD_SETSIZE（通常1024）                               │   │
│  │  • 每次调用都要拷贝整个fd_set                                       │   │
│  │  • 内核需要遍历所有fd：O(n)                                         │   │
│  │  • fd_set在select返回后会被修改，需要重新设置                       │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                           poll (1986)                                │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                     │   │
│  │  工作原理：                                                          │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │  1. 用户态准备pollfd数组                                     │   │   │
│  │  │  2. 将pollfd数组拷贝到内核态                                 │   │   │
│  │  │  3. 内核遍历所有pollfd，检查就绪状态                         │   │   │
│  │  │  4. 设置revents字段标记就绪事件                              │   │   │
│  │  │  5. 将pollfd数组拷贝回用户态                                 │   │   │
│  │  │  6. 用户遍历pollfd数组找出就绪的fd                           │   │   │
│  │  └─────────────────────────────────────────────────────────────┘   │   │
│  │                                                                     │   │
│  │  改进：                                                              │   │
│  │  • 无fd数量限制（只受系统资源限制）                                  │   │
│  │  • 使用pollfd结构，events和revents分离                              │   │
│  │                                                                     │   │
│  │  仍有问题：                                                          │   │
│  │  • 每次调用仍需拷贝整个数组                                         │   │
│  │  • 内核仍需遍历所有fd：O(n)                                         │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                          epoll (2002)                                │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                     │   │
│  │  工作原理：                                                          │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │  1. epoll_create：创建epoll实例（内核维护红黑树+就绪队列）   │   │   │
│  │  │  2. epoll_ctl：添加/修改/删除fd（只传一个fd）                │   │   │
│  │  │  3. epoll_wait：等待事件（只返回就绪的fd）                   │   │   │
│  │  └─────────────────────────────────────────────────────────────┘   │   │
│  │                                                                     │   │
│  │  核心优势：                                                          │   │
│  │  • 使用红黑树管理fd：添加/删除O(log n)                              │   │
│  │  • 就绪队列：只返回就绪的fd                                         │   │
│  │  • 无需每次拷贝所有fd                                                │   │
│  │  • 事件通知：内核通过回调将就绪fd加入队列                           │   │
│  │  • 支持边缘触发(ET)模式                                              │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ═══════════════════════════════════════════════════════════════════════   │
│                                                                             │
│  性能对比（n=fd数量，k=就绪fd数量）：                                       │
│                                                                             │
│  │ 操作              │ select     │ poll       │ epoll          │         │
│  │───────────────────┼────────────┼────────────┼────────────────│         │
│  │ 添加fd            │ O(1)       │ O(1)       │ O(log n)       │         │
│  │ 删除fd            │ O(1)       │ O(1)       │ O(log n)       │         │
│  │ 等待事件(内核)    │ O(n)       │ O(n)       │ O(1)           │         │
│  │ 返回就绪(用户)    │ O(n)       │ O(n)       │ O(k)           │         │
│  │ 数据拷贝          │ 每次O(n)   │ 每次O(n)   │ 一次O(1)       │         │
│  │ 最大fd数          │ 1024       │ 无限制     │ 无限制         │         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 3.2 select实现

```cpp
// select_example.cpp - select基本用法
#include <sys/select.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <fcntl.h>
#include <cstring>
#include <iostream>
#include <vector>
#include <algorithm>

/*
select函数原型：
int select(int nfds,
           fd_set *readfds,
           fd_set *writefds,
           fd_set *exceptfds,
           struct timeval *timeout);

fd_set操作宏：
FD_ZERO(fd_set *set)      - 清空集合
FD_SET(int fd, fd_set *set)   - 添加fd到集合
FD_CLR(int fd, fd_set *set)   - 从集合移除fd
FD_ISSET(int fd, fd_set *set) - 检查fd是否在集合中

nfds：最大fd值+1
返回值：就绪fd数量，0超时，-1错误
*/

class SelectServer {
public:
    SelectServer(int port) : port_(port) {}

    bool start() {
        // 创建监听socket
        listen_fd_ = socket(AF_INET, SOCK_STREAM, 0);
        if (listen_fd_ < 0) {
            perror("socket");
            return false;
        }

        // 设置非阻塞
        set_nonblocking(listen_fd_);

        // 设置地址重用
        int opt = 1;
        setsockopt(listen_fd_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

        // 绑定地址
        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = INADDR_ANY;
        addr.sin_port = htons(port_);

        if (bind(listen_fd_, (sockaddr*)&addr, sizeof(addr)) < 0) {
            perror("bind");
            return false;
        }

        if (listen(listen_fd_, SOMAXCONN) < 0) {
            perror("listen");
            return false;
        }

        // 将监听socket加入客户端列表
        client_fds_.push_back(listen_fd_);
        max_fd_ = listen_fd_;

        std::cout << "Select server listening on port " << port_ << std::endl;
        return true;
    }

    void run() {
        while (running_) {
            // 每次调用select前必须重新设置fd_set
            // 这是select的一个主要缺点
            fd_set read_fds;
            FD_ZERO(&read_fds);

            // 将所有客户端fd加入读集合
            for (int fd : client_fds_) {
                FD_SET(fd, &read_fds);
            }

            // 设置超时：1秒
            timeval timeout{};
            timeout.tv_sec = 1;
            timeout.tv_usec = 0;

            // 调用select
            // nfds必须是最大fd值+1
            int ready = select(max_fd_ + 1, &read_fds, nullptr, nullptr, &timeout);

            if (ready < 0) {
                if (errno == EINTR) continue;
                perror("select");
                break;
            }

            if (ready == 0) {
                // 超时，继续循环
                continue;
            }

            // 必须遍历所有fd来找出就绪的
            // 这是select的另一个主要缺点：O(n)
            std::vector<int> fds_to_remove;
            std::vector<int> fds_to_add;

            for (int fd : client_fds_) {
                if (!FD_ISSET(fd, &read_fds)) {
                    continue;
                }

                if (fd == listen_fd_) {
                    // 新连接
                    handle_accept(fds_to_add);
                } else {
                    // 数据到达
                    if (!handle_client(fd)) {
                        fds_to_remove.push_back(fd);
                    }
                }
            }

            // 移除断开的连接
            for (int fd : fds_to_remove) {
                close(fd);
                client_fds_.erase(
                    std::remove(client_fds_.begin(), client_fds_.end(), fd),
                    client_fds_.end()
                );
            }

            // 添加新连接
            for (int fd : fds_to_add) {
                client_fds_.push_back(fd);
                if (fd > max_fd_) max_fd_ = fd;
            }
        }
    }

    void stop() {
        running_ = false;
    }

private:
    void set_nonblocking(int fd) {
        int flags = fcntl(fd, F_GETFL, 0);
        fcntl(fd, F_SETFL, flags | O_NONBLOCK);
    }

    void handle_accept(std::vector<int>& fds_to_add) {
        while (true) {
            sockaddr_in client_addr{};
            socklen_t client_len = sizeof(client_addr);

            int client_fd = accept(listen_fd_,
                                   (sockaddr*)&client_addr,
                                   &client_len);

            if (client_fd < 0) {
                if (errno == EAGAIN || errno == EWOULDBLOCK) {
                    break;
                }
                perror("accept");
                continue;
            }

            // 检查是否超过select的限制
            if (client_fd >= FD_SETSIZE) {
                std::cerr << "Too many connections (fd=" << client_fd
                          << " >= FD_SETSIZE=" << FD_SETSIZE << ")" << std::endl;
                close(client_fd);
                continue;
            }

            set_nonblocking(client_fd);
            fds_to_add.push_back(client_fd);

            std::cout << "New connection: fd=" << client_fd << std::endl;
        }
    }

    bool handle_client(int fd) {
        char buffer[1024];

        ssize_t n = read(fd, buffer, sizeof(buffer));

        if (n > 0) {
            // Echo回去
            write(fd, buffer, n);
            return true;
        } else if (n == 0) {
            std::cout << "Connection closed: fd=" << fd << std::endl;
            return false;
        } else {
            if (errno == EAGAIN || errno == EWOULDBLOCK) {
                return true;
            }
            perror("read");
            return false;
        }
    }

private:
    int port_;
    int listen_fd_ = -1;
    int max_fd_ = 0;
    std::vector<int> client_fds_;
    bool running_ = true;
};

/*
select的限制总结：

1. fd数量限制
   ┌─────────────────────────────────────────────────────────────────┐
   │ FD_SETSIZE通常是1024，编译时确定，难以修改                       │
   │ 虽然可以重新编译内核修改，但不推荐                               │
   └─────────────────────────────────────────────────────────────────┘

2. 每次调用的开销
   ┌─────────────────────────────────────────────────────────────────┐
   │ • 每次调用前要重新设置fd_set                                    │
   │ • 每次调用都要把fd_set从用户态拷贝到内核态                       │
   │ • 内核每次都要遍历所有fd检查状态                                 │
   │ • 返回时又要把fd_set拷贝回用户态                                 │
   └─────────────────────────────────────────────────────────────────┘

3. 查找就绪fd的开销
   ┌─────────────────────────────────────────────────────────────────┐
   │ 返回后，用户代码必须遍历所有fd用FD_ISSET检查                     │
   │ 即使只有1个fd就绪，也要遍历所有n个fd                             │
   └─────────────────────────────────────────────────────────────────┘
*/
```

#### 3.3 poll实现

```cpp
// poll_example.cpp - poll基本用法
#include <poll.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <fcntl.h>
#include <cstring>
#include <iostream>
#include <vector>

/*
poll函数原型：
int poll(struct pollfd *fds, nfds_t nfds, int timeout);

struct pollfd {
    int   fd;         // 文件描述符
    short events;     // 监听的事件
    short revents;    // 返回的事件
};

常用事件：
POLLIN    - 可读
POLLOUT   - 可写
POLLERR   - 错误
POLLHUP   - 挂起
POLLNVAL  - 无效fd

timeout: 毫秒，-1无限等待，0立即返回
返回值：就绪fd数量，0超时，-1错误
*/

class PollServer {
public:
    PollServer(int port) : port_(port) {}

    bool start() {
        // 创建监听socket
        listen_fd_ = socket(AF_INET, SOCK_STREAM, 0);
        if (listen_fd_ < 0) {
            perror("socket");
            return false;
        }

        set_nonblocking(listen_fd_);

        int opt = 1;
        setsockopt(listen_fd_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = INADDR_ANY;
        addr.sin_port = htons(port_);

        if (bind(listen_fd_, (sockaddr*)&addr, sizeof(addr)) < 0) {
            perror("bind");
            return false;
        }

        if (listen(listen_fd_, SOMAXCONN) < 0) {
            perror("listen");
            return false;
        }

        // 添加监听socket到pollfd数组
        pollfd pfd{};
        pfd.fd = listen_fd_;
        pfd.events = POLLIN;
        poll_fds_.push_back(pfd);

        std::cout << "Poll server listening on port " << port_ << std::endl;
        return true;
    }

    void run() {
        while (running_) {
            // poll不会修改events字段，只会修改revents
            // 所以不需要像select那样每次重新设置
            // 但仍然需要将整个数组拷贝到内核

            int ready = poll(poll_fds_.data(), poll_fds_.size(), 1000);

            if (ready < 0) {
                if (errno == EINTR) continue;
                perror("poll");
                break;
            }

            if (ready == 0) {
                continue;
            }

            // 仍然需要遍历所有fd来检查revents
            // 这点和select一样是O(n)
            std::vector<size_t> indices_to_remove;

            for (size_t i = 0; i < poll_fds_.size(); ++i) {
                if (poll_fds_[i].revents == 0) {
                    continue;
                }

                if (poll_fds_[i].fd == listen_fd_) {
                    if (poll_fds_[i].revents & POLLIN) {
                        handle_accept();
                    }
                } else {
                    if (!handle_client(i)) {
                        indices_to_remove.push_back(i);
                    }
                }

                // 清除revents（可选，poll会覆盖）
                poll_fds_[i].revents = 0;
            }

            // 移除断开的连接（从后往前删除，避免索引问题）
            for (auto it = indices_to_remove.rbegin();
                 it != indices_to_remove.rend(); ++it) {
                close(poll_fds_[*it].fd);
                poll_fds_.erase(poll_fds_.begin() + *it);
            }
        }
    }

    void stop() {
        running_ = false;
    }

private:
    void set_nonblocking(int fd) {
        int flags = fcntl(fd, F_GETFL, 0);
        fcntl(fd, F_SETFL, flags | O_NONBLOCK);
    }

    void handle_accept() {
        while (true) {
            sockaddr_in client_addr{};
            socklen_t client_len = sizeof(client_addr);

            int client_fd = accept(listen_fd_,
                                   (sockaddr*)&client_addr,
                                   &client_len);

            if (client_fd < 0) {
                if (errno == EAGAIN || errno == EWOULDBLOCK) {
                    break;
                }
                perror("accept");
                continue;
            }

            set_nonblocking(client_fd);

            // poll没有fd数量限制！
            // 只受系统资源（打开文件数）限制
            pollfd pfd{};
            pfd.fd = client_fd;
            pfd.events = POLLIN;
            poll_fds_.push_back(pfd);

            std::cout << "New connection: fd=" << client_fd
                      << ", total=" << poll_fds_.size() << std::endl;
        }
    }

    bool handle_client(size_t index) {
        auto& pfd = poll_fds_[index];

        // 检查错误或挂起
        if (pfd.revents & (POLLERR | POLLHUP | POLLNVAL)) {
            std::cout << "Connection error: fd=" << pfd.fd << std::endl;
            return false;
        }

        if (pfd.revents & POLLIN) {
            char buffer[1024];
            ssize_t n = read(pfd.fd, buffer, sizeof(buffer));

            if (n > 0) {
                write(pfd.fd, buffer, n);
                return true;
            } else if (n == 0) {
                std::cout << "Connection closed: fd=" << pfd.fd << std::endl;
                return false;
            } else {
                if (errno == EAGAIN || errno == EWOULDBLOCK) {
                    return true;
                }
                perror("read");
                return false;
            }
        }

        return true;
    }

private:
    int port_;
    int listen_fd_ = -1;
    std::vector<pollfd> poll_fds_;
    bool running_ = true;
};

/*
poll相比select的改进：

1. 无fd数量限制
   ┌─────────────────────────────────────────────────────────────────┐
   │ • 使用动态数组而非固定大小的位图                                 │
   │ • 只受系统资源限制（ulimit -n）                                  │
   └─────────────────────────────────────────────────────────────────┘

2. 事件和返回分离
   ┌─────────────────────────────────────────────────────────────────┐
   │ • events：监听的事件，poll不会修改                               │
   │ • revents：返回的事件，由poll设置                                │
   │ • 不需要每次调用前重新设置                                       │
   └─────────────────────────────────────────────────────────────────┘

poll仍然存在的问题：

1. 数据拷贝
   ┌─────────────────────────────────────────────────────────────────┐
   │ • 每次调用仍要把整个pollfd数组拷贝到内核                         │
   │ • 连接数增加时，拷贝开销线性增长                                 │
   └─────────────────────────────────────────────────────────────────┘

2. 内核遍历
   ┌─────────────────────────────────────────────────────────────────┐
   │ • 内核仍需遍历所有pollfd检查状态                                 │
   │ • 时间复杂度O(n)                                                 │
   └─────────────────────────────────────────────────────────────────┘

3. 用户态遍历
   ┌─────────────────────────────────────────────────────────────────┐
   │ • 返回后仍需遍历所有pollfd找出就绪的                             │
   │ • 时间复杂度O(n)                                                 │
   └─────────────────────────────────────────────────────────────────┘
*/
```

#### 3.4 epoll实现

```cpp
// epoll_example.cpp - epoll完整示例
#include <sys/epoll.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <fcntl.h>
#include <cstring>
#include <iostream>
#include <vector>
#include <unordered_map>

/*
epoll API：

1. epoll_create / epoll_create1
   int epoll_create(int size);  // size已废弃，但必须>0
   int epoll_create1(int flags); // flags: EPOLL_CLOEXEC

2. epoll_ctl
   int epoll_ctl(int epfd, int op, int fd, struct epoll_event *event);

   op: EPOLL_CTL_ADD, EPOLL_CTL_MOD, EPOLL_CTL_DEL

3. epoll_wait
   int epoll_wait(int epfd, struct epoll_event *events,
                  int maxevents, int timeout);

struct epoll_event {
    uint32_t events;    // epoll事件
    epoll_data_t data;  // 用户数据
};

typedef union epoll_data {
    void    *ptr;
    int      fd;
    uint32_t u32;
    uint64_t u64;
} epoll_data_t;

常用事件：
EPOLLIN     - 可读
EPOLLOUT    - 可写
EPOLLERR    - 错误
EPOLLHUP    - 挂起
EPOLLRDHUP  - 对端关闭连接或半关闭
EPOLLET     - 边缘触发
EPOLLONESHOT - 一次性事件
*/

class EpollServer {
public:
    EpollServer(int port) : port_(port) {}

    ~EpollServer() {
        if (epoll_fd_ >= 0) close(epoll_fd_);
        if (listen_fd_ >= 0) close(listen_fd_);
        for (auto& [fd, _] : connections_) {
            close(fd);
        }
    }

    bool start() {
        // 创建epoll实例
        // EPOLL_CLOEXEC: exec时自动关闭
        epoll_fd_ = epoll_create1(EPOLL_CLOEXEC);
        if (epoll_fd_ < 0) {
            perror("epoll_create1");
            return false;
        }

        // 创建监听socket
        listen_fd_ = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK, 0);
        if (listen_fd_ < 0) {
            perror("socket");
            return false;
        }

        int opt = 1;
        setsockopt(listen_fd_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = INADDR_ANY;
        addr.sin_port = htons(port_);

        if (bind(listen_fd_, (sockaddr*)&addr, sizeof(addr)) < 0) {
            perror("bind");
            return false;
        }

        if (listen(listen_fd_, SOMAXCONN) < 0) {
            perror("listen");
            return false;
        }

        // 将监听socket加入epoll
        // 使用边缘触发(ET)模式
        epoll_event ev{};
        ev.events = EPOLLIN | EPOLLET;
        ev.data.fd = listen_fd_;

        if (epoll_ctl(epoll_fd_, EPOLL_CTL_ADD, listen_fd_, &ev) < 0) {
            perror("epoll_ctl");
            return false;
        }

        std::cout << "Epoll server listening on port " << port_ << std::endl;
        return true;
    }

    void run() {
        std::vector<epoll_event> events(1024);

        while (running_) {
            // epoll_wait只返回就绪的fd
            // 不需要遍历所有fd！
            int ready = epoll_wait(epoll_fd_, events.data(),
                                   events.size(), 1000);

            if (ready < 0) {
                if (errno == EINTR) continue;
                perror("epoll_wait");
                break;
            }

            // 只需处理就绪的fd，复杂度O(k)，k是就绪数量
            for (int i = 0; i < ready; ++i) {
                int fd = events[i].data.fd;
                uint32_t ev = events[i].events;

                if (fd == listen_fd_) {
                    handle_accept();
                } else {
                    handle_client(fd, ev);
                }
            }
        }
    }

    void stop() {
        running_ = false;
    }

private:
    void handle_accept() {
        // ET模式下必须循环accept直到EAGAIN
        while (true) {
            sockaddr_in client_addr{};
            socklen_t client_len = sizeof(client_addr);

            int client_fd = accept4(listen_fd_,
                                    (sockaddr*)&client_addr,
                                    &client_len,
                                    SOCK_NONBLOCK);

            if (client_fd < 0) {
                if (errno == EAGAIN || errno == EWOULDBLOCK) {
                    break;  // 没有更多连接了
                }
                perror("accept");
                continue;
            }

            // 将新连接加入epoll
            epoll_event ev{};
            ev.events = EPOLLIN | EPOLLET | EPOLLRDHUP;
            ev.data.fd = client_fd;

            if (epoll_ctl(epoll_fd_, EPOLL_CTL_ADD, client_fd, &ev) < 0) {
                perror("epoll_ctl ADD");
                close(client_fd);
                continue;
            }

            connections_[client_fd] = ConnectionState{};

            std::cout << "New connection: fd=" << client_fd
                      << ", total=" << connections_.size() << std::endl;
        }
    }

    void handle_client(int fd, uint32_t events) {
        auto it = connections_.find(fd);
        if (it == connections_.end()) {
            return;
        }

        // 检查连接关闭或错误
        if (events & (EPOLLHUP | EPOLLRDHUP | EPOLLERR)) {
            close_connection(fd);
            return;
        }

        // 可读事件
        if (events & EPOLLIN) {
            handle_read(fd);
        }

        // 可写事件
        if (events & EPOLLOUT) {
            handle_write(fd);
        }
    }

    void handle_read(int fd) {
        auto& conn = connections_[fd];
        char buffer[4096];

        // ET模式下必须读完所有数据
        while (true) {
            ssize_t n = read(fd, buffer, sizeof(buffer));

            if (n > 0) {
                // 将数据加入写缓冲区（echo）
                conn.write_buffer.append(buffer, n);

            } else if (n == 0) {
                // 对端关闭
                close_connection(fd);
                return;

            } else {
                if (errno == EAGAIN || errno == EWOULDBLOCK) {
                    break;  // 数据读完了
                }
                close_connection(fd);
                return;
            }
        }

        // 如果有数据要写，启用写事件
        if (!conn.write_buffer.empty()) {
            epoll_event ev{};
            ev.events = EPOLLIN | EPOLLOUT | EPOLLET | EPOLLRDHUP;
            ev.data.fd = fd;
            epoll_ctl(epoll_fd_, EPOLL_CTL_MOD, fd, &ev);
        }
    }

    void handle_write(int fd) {
        auto& conn = connections_[fd];

        // ET模式下必须写完所有数据或遇到EAGAIN
        while (!conn.write_buffer.empty()) {
            ssize_t n = write(fd, conn.write_buffer.data(),
                             conn.write_buffer.size());

            if (n > 0) {
                conn.write_buffer.erase(0, n);

            } else if (n < 0) {
                if (errno == EAGAIN || errno == EWOULDBLOCK) {
                    break;  // 写缓冲区满了
                }
                close_connection(fd);
                return;
            }
        }

        // 如果写完了，禁用写事件
        if (conn.write_buffer.empty()) {
            epoll_event ev{};
            ev.events = EPOLLIN | EPOLLET | EPOLLRDHUP;
            ev.data.fd = fd;
            epoll_ctl(epoll_fd_, EPOLL_CTL_MOD, fd, &ev);
        }
    }

    void close_connection(int fd) {
        std::cout << "Connection closed: fd=" << fd << std::endl;
        epoll_ctl(epoll_fd_, EPOLL_CTL_DEL, fd, nullptr);
        close(fd);
        connections_.erase(fd);
    }

private:
    struct ConnectionState {
        std::string write_buffer;
    };

    int port_;
    int epoll_fd_ = -1;
    int listen_fd_ = -1;
    std::unordered_map<int, ConnectionState> connections_;
    bool running_ = true;
};

/*
epoll内部实现原理：

┌─────────────────────────────────────────────────────────────────────────────┐
│                        epoll内核数据结构                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  struct eventpoll {                                                         │
│      spinlock_t lock;           // 自旋锁                                   │
│      struct mutex mtx;          // 互斥锁                                   │
│      wait_queue_head_t wq;      // epoll_wait等待队列                       │
│      wait_queue_head_t poll_wait; // file->poll()等待队列                   │
│      struct list_head rdllist;  // 就绪fd链表                               │
│      struct rb_root rbr;        // 红黑树根节点                             │
│      ...                                                                    │
│  };                                                                         │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        epoll实例                                     │   │
│  │                                                                     │   │
│  │    红黑树（存储所有监控的fd）        就绪链表（存储就绪的fd）       │   │
│  │    ┌─────────────────────┐          ┌─────────────────────┐        │   │
│  │    │         5           │          │ fd3 → fd7 → fd12    │        │   │
│  │    │       /   \         │          │                     │        │   │
│  │    │      3     7        │          └─────────────────────┘        │   │
│  │    │     / \   / \       │                    ↑                    │   │
│  │    │    1   4 6   9      │                    │                    │   │
│  │    └─────────────────────┘                    │                    │   │
│  │              │                                │                    │   │
│  │              │ epoll_ctl添加fd时              │ fd就绪时           │   │
│  │              │ 在红黑树中插入节点             │ 回调将其加入链表   │   │
│  │              │ O(log n)                       │                    │   │
│  │              │                                │                    │   │
│  │              └────────────────────────────────┘                    │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  工作流程：                                                                  │
│                                                                             │
│  1. epoll_create：创建eventpoll结构                                         │
│  2. epoll_ctl ADD：在红黑树中插入节点，注册回调函数                         │
│  3. 数据到达：内核调用回调，将fd加入就绪链表                                │
│  4. epoll_wait：检查就绪链表，有就绪fd则返回，否则休眠                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
*/
```

#### 3.5 LT与ET模式对比

```cpp
// lt_vs_et.cpp - 水平触发与边缘触发对比
#include <sys/epoll.h>
#include <unistd.h>
#include <fcntl.h>
#include <cstring>
#include <iostream>

/*
┌─────────────────────────────────────────────────────────────────────────────┐
│                     水平触发(LT) vs 边缘触发(ET)                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  水平触发 (Level-Triggered, LT)：                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                                                                     │   │
│  │  • 默认模式                                                         │   │
│  │  • 只要缓冲区有数据，epoll_wait就会返回                             │   │
│  │  • 如果不读完，下次调用还会返回                                     │   │
│  │                                                                     │   │
│  │  时间 ─────────────────────────────────────────────────────→       │   │
│  │       │                                                             │   │
│  │  数据 │  ████████████████████                                      │   │
│  │  到达 │  ↑                                                          │   │
│  │       │  │                                                          │   │
│  │  通知 │  ↓  ↓  ↓  ↓  ↓  ↓  ← 每次epoll_wait都返回                  │   │
│  │       │  直到数据被读完                                             │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  边缘触发 (Edge-Triggered, ET)：                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                                                                     │   │
│  │  • 需要显式设置EPOLLET                                              │   │
│  │  • 只在状态变化时通知一次（从无数据到有数据）                       │   │
│  │  • 必须一次性读完所有数据                                           │   │
│  │                                                                     │   │
│  │  时间 ─────────────────────────────────────────────────────→       │   │
│  │       │                                                             │   │
│  │  数据 │  ████████████████████                                      │   │
│  │  到达 │  ↑                                                          │   │
│  │       │  │                                                          │   │
│  │  通知 │  ↓                      ← 只在边缘（状态变化）时通知一次    │   │
│  │       │                                                             │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
*/

// 演示LT模式
void demo_level_triggered(int epfd, int fd) {
    epoll_event ev{};
    ev.events = EPOLLIN;  // 默认LT模式
    ev.data.fd = fd;
    epoll_ctl(epfd, EPOLL_CTL_ADD, fd, &ev);

    std::vector<epoll_event> events(10);
    char buf[10];  // 只读10字节

    // 假设fd中有100字节数据
    std::cout << "\n=== Level-Triggered Demo ===" << std::endl;

    for (int i = 0; i < 5; ++i) {
        int n = epoll_wait(epfd, events.data(), events.size(), 100);

        if (n > 0) {
            // LT模式：即使只读一部分，下次还会返回
            ssize_t bytes = read(fd, buf, sizeof(buf));
            std::cout << "epoll_wait returned, read " << bytes << " bytes" << std::endl;
        } else if (n == 0) {
            std::cout << "No more data" << std::endl;
            break;
        }
    }
}

// 演示ET模式
void demo_edge_triggered(int epfd, int fd) {
    epoll_event ev{};
    ev.events = EPOLLIN | EPOLLET;  // 设置ET模式
    ev.data.fd = fd;
    epoll_ctl(epfd, EPOLL_CTL_ADD, fd, &ev);

    std::vector<epoll_event> events(10);

    std::cout << "\n=== Edge-Triggered Demo ===" << std::endl;

    int n = epoll_wait(epfd, events.data(), events.size(), 100);

    if (n > 0) {
        // ET模式：必须循环读完所有数据
        char buf[1024];
        while (true) {
            ssize_t bytes = read(fd, buf, sizeof(buf));

            if (bytes > 0) {
                std::cout << "Read " << bytes << " bytes" << std::endl;
            } else if (bytes < 0) {
                if (errno == EAGAIN || errno == EWOULDBLOCK) {
                    std::cout << "All data read (EAGAIN)" << std::endl;
                    break;
                }
                perror("read error");
                break;
            } else {
                std::cout << "EOF" << std::endl;
                break;
            }
        }
    }

    // 如果没有新数据到达，这次不会返回
    n = epoll_wait(epfd, events.data(), events.size(), 100);
    std::cout << "Second epoll_wait returned: " << n << std::endl;
}

/*
ET模式的编程要求：

┌─────────────────────────────────────────────────────────────────────────────┐
│                        ET模式编程规范                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. 必须使用非阻塞I/O                                                       │
│     ┌─────────────────────────────────────────────────────────────────┐   │
│     │ int flags = fcntl(fd, F_GETFL, 0);                              │   │
│     │ fcntl(fd, F_SETFL, flags | O_NONBLOCK);                         │   │
│     │                                                                 │   │
│     │ 原因：ET模式下必须读完所有数据，阻塞I/O可能导致死锁             │   │
│     └─────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  2. 必须循环读/写直到EAGAIN                                                 │
│     ┌─────────────────────────────────────────────────────────────────┐   │
│     │ while (true) {                                                  │   │
│     │     ssize_t n = read(fd, buf, sizeof(buf));                     │   │
│     │     if (n > 0) {                                                │   │
│     │         // 处理数据                                             │   │
│     │     } else if (n < 0) {                                         │   │
│     │         if (errno == EAGAIN) break;  // 数据读完了              │   │
│     │         // 处理错误                                             │   │
│     │     } else {                                                    │   │
│     │         // EOF                                                  │   │
│     │     }                                                           │   │
│     │ }                                                               │   │
│     └─────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  3. 注意饥饿问题                                                            │
│     ┌─────────────────────────────────────────────────────────────────┐   │
│     │ 如果一个fd持续有大量数据，可能会"饿死"其他fd                    │   │
│     │                                                                 │   │
│     │ 解决方案：                                                      │   │
│     │ • 每次只读固定数量，然后处理其他fd                              │   │
│     │ • 使用时间片轮转                                                │   │
│     └─────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

LT vs ET 选择指南：

┌───────────────────┬──────────────────────┬──────────────────────────────────┐
│ 特性              │ LT                   │ ET                               │
├───────────────────┼──────────────────────┼──────────────────────────────────┤
│ 编程难度          │ 低                   │ 高                               │
│ 系统调用次数      │ 多                   │ 少                               │
│ 性能              │ 略低                 │ 略高                             │
│ 适用场景          │ 一般场景             │ 高性能场景                       │
│ 出错风险          │ 低                   │ 高（可能漏读数据）               │
└───────────────────┴──────────────────────┴──────────────────────────────────┘

建议：
• 初学者或一般应用使用LT模式
• 高性能服务器考虑ET模式
• ET模式一定要配合非阻塞I/O使用
*/
```

#### 3.6 多路复用性能对比测试

```cpp
// multiplexer_benchmark.cpp - 三种多路复用机制性能对比
#include <sys/select.h>
#include <poll.h>
#include <sys/epoll.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <fcntl.h>
#include <chrono>
#include <vector>
#include <iostream>
#include <cstring>

/*
性能测试场景：
1. 创建N个socket pair
2. 随机选择K个socket写入数据
3. 使用select/poll/epoll等待就绪
4. 测量等待和处理时间
*/

class MultiplexerBenchmark {
public:
    MultiplexerBenchmark(int num_fds, int num_active)
        : num_fds_(num_fds), num_active_(num_active) {

        // 创建socket pairs
        socket_pairs_.resize(num_fds_);
        for (int i = 0; i < num_fds_; ++i) {
            int sv[2];
            if (socketpair(AF_UNIX, SOCK_STREAM | SOCK_NONBLOCK, 0, sv) < 0) {
                throw std::runtime_error("socketpair failed");
            }
            socket_pairs_[i] = {sv[0], sv[1]};
        }
    }

    ~MultiplexerBenchmark() {
        for (auto& [fd1, fd2] : socket_pairs_) {
            close(fd1);
            close(fd2);
        }
    }

    // 激活一些socket（写入数据）
    void activate_sockets() {
        char data = 'x';
        for (int i = 0; i < num_active_; ++i) {
            int idx = i * num_fds_ / num_active_;
            write(socket_pairs_[idx].second, &data, 1);
        }
    }

    // 清空所有socket的数据
    void drain_sockets() {
        char buf[256];
        for (auto& [fd1, fd2] : socket_pairs_) {
            while (read(fd1, buf, sizeof(buf)) > 0) {}
        }
    }

    // 测试select
    double benchmark_select(int iterations) {
        auto start = std::chrono::high_resolution_clock::now();

        for (int iter = 0; iter < iterations; ++iter) {
            activate_sockets();

            fd_set read_fds;
            FD_ZERO(&read_fds);

            int max_fd = 0;
            for (auto& [fd1, fd2] : socket_pairs_) {
                if (fd1 < FD_SETSIZE) {
                    FD_SET(fd1, &read_fds);
                    if (fd1 > max_fd) max_fd = fd1;
                }
            }

            timeval tv{0, 0};
            int ready = select(max_fd + 1, &read_fds, nullptr, nullptr, &tv);

            // 处理就绪的fd
            char buf[256];
            for (auto& [fd1, fd2] : socket_pairs_) {
                if (fd1 < FD_SETSIZE && FD_ISSET(fd1, &read_fds)) {
                    read(fd1, buf, sizeof(buf));
                }
            }
        }

        auto end = std::chrono::high_resolution_clock::now();
        return std::chrono::duration<double, std::milli>(end - start).count();
    }

    // 测试poll
    double benchmark_poll(int iterations) {
        std::vector<pollfd> poll_fds(num_fds_);
        for (int i = 0; i < num_fds_; ++i) {
            poll_fds[i].fd = socket_pairs_[i].first;
            poll_fds[i].events = POLLIN;
        }

        auto start = std::chrono::high_resolution_clock::now();

        for (int iter = 0; iter < iterations; ++iter) {
            activate_sockets();

            int ready = poll(poll_fds.data(), poll_fds.size(), 0);

            char buf[256];
            for (auto& pfd : poll_fds) {
                if (pfd.revents & POLLIN) {
                    read(pfd.fd, buf, sizeof(buf));
                }
                pfd.revents = 0;
            }
        }

        auto end = std::chrono::high_resolution_clock::now();
        return std::chrono::duration<double, std::milli>(end - start).count();
    }

    // 测试epoll
    double benchmark_epoll(int iterations) {
        int epfd = epoll_create1(0);

        for (auto& [fd1, fd2] : socket_pairs_) {
            epoll_event ev{};
            ev.events = EPOLLIN;
            ev.data.fd = fd1;
            epoll_ctl(epfd, EPOLL_CTL_ADD, fd1, &ev);
        }

        std::vector<epoll_event> events(num_fds_);

        auto start = std::chrono::high_resolution_clock::now();

        for (int iter = 0; iter < iterations; ++iter) {
            activate_sockets();

            int ready = epoll_wait(epfd, events.data(), events.size(), 0);

            char buf[256];
            for (int i = 0; i < ready; ++i) {
                read(events[i].data.fd, buf, sizeof(buf));
            }
        }

        auto end = std::chrono::high_resolution_clock::now();
        close(epfd);

        return std::chrono::duration<double, std::milli>(end - start).count();
    }

private:
    int num_fds_;
    int num_active_;
    std::vector<std::pair<int, int>> socket_pairs_;
};

void run_benchmark() {
    std::cout << "\n";
    std::cout << "╔═══════════════════════════════════════════════════════════════════════╗\n";
    std::cout << "║                    I/O多路复用性能对比测试                             ║\n";
    std::cout << "╠═══════════════════════════════════════════════════════════════════════╣\n";

    std::vector<int> fd_counts = {100, 500, 1000};
    int iterations = 1000;

    for (int num_fds : fd_counts) {
        // select有FD_SETSIZE限制
        if (num_fds > FD_SETSIZE) {
            std::cout << "║ " << num_fds << " fds: select skipped (FD_SETSIZE limit)";
            std::cout << std::string(30, ' ') << "║\n";
            continue;
        }

        int num_active = num_fds / 10;  // 10%活跃

        MultiplexerBenchmark bench(num_fds, num_active);

        double select_time = bench.benchmark_select(iterations);
        double poll_time = bench.benchmark_poll(iterations);
        double epoll_time = bench.benchmark_epoll(iterations);

        std::cout << "╠═══════════════════════════════════════════════════════════════════════╣\n";
        printf("║ FD数量: %4d  活跃: %4d  迭代: %4d                                   ║\n",
               num_fds, num_active, iterations);
        std::cout << "╠───────────────────────────────────────────────────────────────────────╣\n";
        printf("║ select: %8.2f ms  │  poll: %8.2f ms  │  epoll: %8.2f ms        ║\n",
               select_time, poll_time, epoll_time);

        // 计算相对性能
        double base = epoll_time;
        printf("║ 相对性能: select=%.2fx  poll=%.2fx  epoll=1.00x                       ║\n",
               select_time / base, poll_time / base);
    }

    std::cout << "╚═══════════════════════════════════════════════════════════════════════╝\n";
}

/*
典型测试结果（仅供参考，实际结果取决于系统）：

╔═══════════════════════════════════════════════════════════════════════╗
║                    I/O多路复用性能对比测试                             ║
╠═══════════════════════════════════════════════════════════════════════╣
╠═══════════════════════════════════════════════════════════════════════╣
║ FD数量:  100  活跃:   10  迭代: 1000                                   ║
╠───────────────────────────────────────────────────────────────────────╣
║ select:    15.23 ms  │  poll:    16.45 ms  │  epoll:    12.34 ms      ║
║ 相对性能: select=1.23x  poll=1.33x  epoll=1.00x                       ║
╠═══════════════════════════════════════════════════════════════════════╣
║ FD数量:  500  活跃:   50  迭代: 1000                                   ║
╠───────────────────────────────────────────────────────────────────────╣
║ select:    78.56 ms  │  poll:    82.34 ms  │  epoll:    15.67 ms      ║
║ 相对性能: select=5.01x  poll=5.26x  epoll=1.00x                       ║
╠═══════════════════════════════════════════════════════════════════════╣
║ FD数量: 1000  活跃:  100  迭代: 1000                                   ║
╠───────────────────────────────────────────────────────────────────────╣
║ select: 限制超出     │  poll:   189.23 ms  │  epoll:    18.45 ms      ║
║ 相对性能: N/A        poll=10.26x  epoll=1.00x                         ║
╚═══════════════════════════════════════════════════════════════════════╝

结论：
1. fd数量少时（<100），三者差异不大
2. fd数量增加时，select/poll性能下降明显（O(n)）
3. epoll性能基本稳定（O(1)就绪事件返回）
4. 高并发场景下，epoll是最佳选择
*/

int main() {
    run_benchmark();
    return 0;
}
```

---

### 第一周自测题

#### 概念理解

1. **Reactor模式的核心思想是什么？与传统多线程模型相比有什么优势？**

2. **解释Reactor模式的五个核心组件及其职责。**

3. **select、poll、epoll各有什么特点？在什么场景下选择哪个？**

4. **什么是水平触发(LT)和边缘触发(ET)？各有什么优缺点？**

5. **ET模式下为什么必须使用非阻塞I/O？如果使用阻塞I/O会发生什么？**

#### 编程实践

1. **实现一个简单的select服务器，能够处理多个客户端连接。**

2. **将上述服务器改为使用epoll实现，对比代码复杂度。**

3. **实现一个LT和ET模式的对比实验，验证两者的行为差异。**

---

### 第一周检验标准

| 检验项 | 达标要求 | 自评 |
|--------|----------|------|
| 理解Reactor核心思想 | 能画出架构图并解释 | ☐ |
| 理解事件驱动优势 | 能量化对比资源消耗 | ☐ |
| 掌握select用法 | 能实现基本echo服务器 | ☐ |
| 掌握poll用法 | 能实现基本echo服务器 | ☐ |
| 掌握epoll用法 | 能实现高效echo服务器 | ☐ |
| 理解LT与ET区别 | 能解释并演示差异 | ☐ |
| 完成对比实验 | 能分析性能数据 | ☐ |

---

### 第一周时间分配

| 内容 | 时间 |
|------|------|
| Reactor理论学习 | 8小时 |
| select/poll/epoll原理 | 10小时 |
| 代码实现与实验 | 12小时 |
| 源码阅读与笔记 | 5小时 |

---

## 第二周：单线程Reactor实现（Day 8-14）

> **本周目标**：实现完整的单线程Reactor框架，包括EventLoop、Channel、Acceptor等核心组件
> **学习时长**：35小时
> **核心产出**：单线程Reactor框架代码

---

### Day 8-9：EventLoop设计（10小时）

#### 4.1 EventLoop概念

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          EventLoop核心概念                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  EventLoop是Reactor模式的核心，它实现了"事件循环"：                          │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                                                                     │   │
│  │                     ┌───────────────────┐                           │   │
│  │                     │                   │                           │   │
│  │                     │   EventLoop       │                           │   │
│  │                     │                   │                           │   │
│  │         ┌──────────→│  1. 等待事件      │──────────┐                │   │
│  │         │           │  2. 分发事件      │          │                │   │
│  │         │           │  3. 执行回调      │          │                │   │
│  │         │           │                   │          │                │   │
│  │         │           └───────────────────┘          │                │   │
│  │         │                                          │                │   │
│  │         │                                          ▼                │   │
│  │         │           ┌───────────────────┐          │                │   │
│  │         │           │                   │          │                │   │
│  │         └───────────│  处理完成         │◀─────────┘                │   │
│  │                     │                   │                           │   │
│  │                     └───────────────────┘                           │   │
│  │                                                                     │   │
│  │                        无限循环直到stop()                            │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  EventLoop的职责：                                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 1. 管理事件源（Channel）的注册和注销                                 │   │
│  │ 2. 调用Poller等待I/O事件                                             │   │
│  │ 3. 将就绪事件分发给对应的Channel                                     │   │
│  │ 4. 执行定时器任务（可选）                                            │   │
│  │ 5. 执行其他线程投递的任务（跨线程调用）                              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 4.2 EventLoop实现

```cpp
// event_loop.hpp - EventLoop核心实现
#pragma once

#include <sys/epoll.h>
#include <sys/eventfd.h>
#include <unistd.h>
#include <functional>
#include <vector>
#include <memory>
#include <mutex>
#include <thread>
#include <atomic>
#include <iostream>

namespace reactor {

// 前向声明
class Channel;
class Poller;

// =============================================================================
// Poller - epoll封装
// =============================================================================

class Poller {
public:
    Poller() {
        epoll_fd_ = epoll_create1(EPOLL_CLOEXEC);
        if (epoll_fd_ < 0) {
            throw std::runtime_error("epoll_create1 failed");
        }
    }

    ~Poller() {
        if (epoll_fd_ >= 0) {
            close(epoll_fd_);
        }
    }

    // 更新Channel的监听事件
    void update_channel(Channel* channel);

    // 移除Channel
    void remove_channel(Channel* channel);

    // 等待事件并填充活跃Channel列表
    void poll(int timeout_ms, std::vector<Channel*>& active_channels);

private:
    int epoll_fd_ = -1;
    std::vector<epoll_event> events_{1024};
};

// =============================================================================
// Channel - 事件通道
// =============================================================================

class Channel {
public:
    using EventCallback = std::function<void()>;

    Channel(int fd) : fd_(fd) {}

    ~Channel() = default;

    // 禁止拷贝
    Channel(const Channel&) = delete;
    Channel& operator=(const Channel&) = delete;

    // 获取fd
    int fd() const { return fd_; }

    // 获取/设置监听的事件
    uint32_t events() const { return events_; }
    void set_events(uint32_t events) { events_ = events; }

    // 获取/设置返回的事件
    uint32_t revents() const { return revents_; }
    void set_revents(uint32_t revents) { revents_ = revents; }

    // 设置回调
    void set_read_callback(EventCallback cb) { read_callback_ = std::move(cb); }
    void set_write_callback(EventCallback cb) { write_callback_ = std::move(cb); }
    void set_close_callback(EventCallback cb) { close_callback_ = std::move(cb); }
    void set_error_callback(EventCallback cb) { error_callback_ = std::move(cb); }

    // 启用/禁用事件
    void enable_reading() { events_ |= EPOLLIN; }
    void disable_reading() { events_ &= ~EPOLLIN; }
    void enable_writing() { events_ |= EPOLLOUT; }
    void disable_writing() { events_ &= ~EPOLLOUT; }
    void disable_all() { events_ = 0; }

    // 检查事件状态
    bool is_reading() const { return events_ & EPOLLIN; }
    bool is_writing() const { return events_ & EPOLLOUT; }
    bool is_none_event() const { return events_ == 0; }

    // 处理事件
    void handle_event() {
        // 处理关闭事件
        if ((revents_ & EPOLLHUP) && !(revents_ & EPOLLIN)) {
            if (close_callback_) close_callback_();
            return;
        }

        // 处理错误事件
        if (revents_ & EPOLLERR) {
            if (error_callback_) error_callback_();
            return;
        }

        // 处理可读事件（包括对端关闭）
        if (revents_ & (EPOLLIN | EPOLLPRI | EPOLLRDHUP)) {
            if (read_callback_) read_callback_();
        }

        // 处理可写事件
        if (revents_ & EPOLLOUT) {
            if (write_callback_) write_callback_();
        }
    }

    // 获取/设置索引（用于Poller优化）
    int index() const { return index_; }
    void set_index(int index) { index_ = index; }

private:
    int fd_;
    uint32_t events_ = 0;    // 监听的事件
    uint32_t revents_ = 0;   // 返回的事件
    int index_ = -1;         // Poller中的状态：-1新建，1已添加，2已删除

    EventCallback read_callback_;
    EventCallback write_callback_;
    EventCallback close_callback_;
    EventCallback error_callback_;
};

// =============================================================================
// Poller实现
// =============================================================================

inline void Poller::update_channel(Channel* channel) {
    int fd = channel->fd();
    int index = channel->index();

    epoll_event ev{};
    ev.events = channel->events();
    ev.data.ptr = channel;

    if (index == -1) {
        // 新Channel，添加
        if (epoll_ctl(epoll_fd_, EPOLL_CTL_ADD, fd, &ev) < 0) {
            perror("epoll_ctl ADD");
            return;
        }
        channel->set_index(1);
    } else if (index == 1) {
        // 已存在，修改
        if (channel->is_none_event()) {
            // 没有监听任何事件，删除
            if (epoll_ctl(epoll_fd_, EPOLL_CTL_DEL, fd, nullptr) < 0) {
                perror("epoll_ctl DEL");
            }
            channel->set_index(2);
        } else {
            if (epoll_ctl(epoll_fd_, EPOLL_CTL_MOD, fd, &ev) < 0) {
                perror("epoll_ctl MOD");
            }
        }
    } else {
        // index == 2，之前删除过，重新添加
        if (epoll_ctl(epoll_fd_, EPOLL_CTL_ADD, fd, &ev) < 0) {
            perror("epoll_ctl ADD");
            return;
        }
        channel->set_index(1);
    }
}

inline void Poller::remove_channel(Channel* channel) {
    int fd = channel->fd();
    int index = channel->index();

    if (index == 1) {
        if (epoll_ctl(epoll_fd_, EPOLL_CTL_DEL, fd, nullptr) < 0) {
            perror("epoll_ctl DEL");
        }
    }
    channel->set_index(-1);
}

inline void Poller::poll(int timeout_ms, std::vector<Channel*>& active_channels) {
    int num_events = epoll_wait(epoll_fd_, events_.data(),
                                static_cast<int>(events_.size()), timeout_ms);

    if (num_events < 0) {
        if (errno != EINTR) {
            perror("epoll_wait");
        }
        return;
    }

    for (int i = 0; i < num_events; ++i) {
        Channel* channel = static_cast<Channel*>(events_[i].data.ptr);
        channel->set_revents(events_[i].events);
        active_channels.push_back(channel);
    }

    // 如果所有事件槽都被使用，扩容
    if (num_events == static_cast<int>(events_.size())) {
        events_.resize(events_.size() * 2);
    }
}

// =============================================================================
// EventLoop - 事件循环
// =============================================================================

class EventLoop {
public:
    using Functor = std::function<void()>;

    EventLoop()
        : thread_id_(std::this_thread::get_id()),
          poller_(std::make_unique<Poller>()),
          wakeup_fd_(eventfd(0, EFD_NONBLOCK | EFD_CLOEXEC)),
          wakeup_channel_(std::make_unique<Channel>(wakeup_fd_)) {

        if (wakeup_fd_ < 0) {
            throw std::runtime_error("eventfd failed");
        }

        // 设置wakeup channel
        wakeup_channel_->set_read_callback([this]() { handle_wakeup(); });
        wakeup_channel_->enable_reading();
        update_channel(wakeup_channel_.get());

        std::cout << "[EventLoop] Created in thread " << thread_id_ << std::endl;
    }

    ~EventLoop() {
        wakeup_channel_->disable_all();
        remove_channel(wakeup_channel_.get());
        close(wakeup_fd_);
    }

    // 禁止拷贝
    EventLoop(const EventLoop&) = delete;
    EventLoop& operator=(const EventLoop&) = delete;

    // 运行事件循环
    void loop() {
        looping_ = true;
        quit_ = false;

        std::cout << "[EventLoop] Start looping" << std::endl;

        while (!quit_) {
            active_channels_.clear();

            // 等待事件
            poller_->poll(10000, active_channels_);

            // 处理I/O事件
            for (Channel* channel : active_channels_) {
                channel->handle_event();
            }

            // 执行待处理的函数
            do_pending_functors();
        }

        std::cout << "[EventLoop] Stop looping" << std::endl;
        looping_ = false;
    }

    // 退出事件循环
    void quit() {
        quit_ = true;
        // 如果不在EventLoop线程，需要唤醒
        if (!is_in_loop_thread()) {
            wakeup();
        }
    }

    // 在EventLoop线程中执行函数
    void run_in_loop(Functor cb) {
        if (is_in_loop_thread()) {
            // 已在EventLoop线程，直接执行
            cb();
        } else {
            // 不在EventLoop线程，加入队列
            queue_in_loop(std::move(cb));
        }
    }

    // 将函数加入队列
    void queue_in_loop(Functor cb) {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            pending_functors_.push_back(std::move(cb));
        }
        // 唤醒EventLoop线程
        if (!is_in_loop_thread() || calling_pending_functors_) {
            wakeup();
        }
    }

    // 更新Channel
    void update_channel(Channel* channel) {
        poller_->update_channel(channel);
    }

    // 移除Channel
    void remove_channel(Channel* channel) {
        poller_->remove_channel(channel);
    }

    // 检查是否在EventLoop线程
    bool is_in_loop_thread() const {
        return thread_id_ == std::this_thread::get_id();
    }

    // 断言在EventLoop线程
    void assert_in_loop_thread() {
        if (!is_in_loop_thread()) {
            throw std::runtime_error("EventLoop::assert_in_loop_thread failed");
        }
    }

private:
    // 唤醒EventLoop（向eventfd写入）
    void wakeup() {
        uint64_t one = 1;
        ssize_t n = write(wakeup_fd_, &one, sizeof(one));
        if (n != sizeof(one)) {
            std::cerr << "EventLoop::wakeup() writes " << n << " bytes" << std::endl;
        }
    }

    // 处理wakeup事件
    void handle_wakeup() {
        uint64_t one = 0;
        ssize_t n = read(wakeup_fd_, &one, sizeof(one));
        if (n != sizeof(one)) {
            std::cerr << "EventLoop::handle_wakeup() reads " << n << " bytes" << std::endl;
        }
    }

    // 执行待处理的函数
    void do_pending_functors() {
        std::vector<Functor> functors;

        calling_pending_functors_ = true;

        {
            std::lock_guard<std::mutex> lock(mutex_);
            functors.swap(pending_functors_);
        }

        for (const Functor& functor : functors) {
            functor();
        }

        calling_pending_functors_ = false;
    }

private:
    std::thread::id thread_id_;
    std::atomic<bool> looping_{false};
    std::atomic<bool> quit_{false};

    std::unique_ptr<Poller> poller_;
    std::vector<Channel*> active_channels_;

    // wakeup机制
    int wakeup_fd_;
    std::unique_ptr<Channel> wakeup_channel_;

    // 跨线程调用
    std::mutex mutex_;
    std::vector<Functor> pending_functors_;
    std::atomic<bool> calling_pending_functors_{false};
};

} // namespace reactor
```

#### 4.3 wakeup机制详解

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          wakeup机制详解                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  问题：EventLoop在epoll_wait中阻塞，如何从其他线程唤醒它？                  │
│                                                                             │
│  解决方案：使用eventfd                                                       │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                                                                     │   │
│  │   其他线程                          EventLoop线程                   │   │
│  │   ┌─────────┐                      ┌─────────────────────┐         │   │
│  │   │         │                      │                     │         │   │
│  │   │ queue_  │                      │   epoll_wait()      │         │   │
│  │   │ in_loop │                      │   阻塞等待...       │         │   │
│  │   │         │                      │                     │         │   │
│  │   └────┬────┘                      └──────────┬──────────┘         │   │
│  │        │                                      │                    │   │
│  │        │ 1. 将函数加入队列                    │                    │   │
│  │        │                                      │                    │   │
│  │        │ 2. write(wakeup_fd, 1)              │                    │   │
│  │        │    ─────────────────────────────────→│                    │   │
│  │        │                                      │                    │   │
│  │        │                          3. epoll_wait返回                │   │
│  │        │                             wakeup_fd可读                 │   │
│  │        │                                      │                    │   │
│  │        │                          4. 处理wakeup事件                │   │
│  │        │                             read(wakeup_fd)              │   │
│  │        │                                      │                    │   │
│  │        │                          5. 执行pending_functors         │   │
│  │        │                                      │                    │   │
│  │        │                          6. 继续epoll_wait               │   │
│  │        │                                      │                    │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  eventfd特点：                                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ • 轻量级的进程/线程间通信机制                                        │   │
│  │ • 文件描述符，可被epoll监控                                          │   │
│  │ • write增加计数，read清零并返回计数                                  │   │
│  │ • 比pipe更高效（只需一个fd）                                         │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### Day 10-11：Channel抽象（10小时）

#### 5.1 Channel的职责

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Channel抽象                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Channel是对文件描述符的封装，负责：                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 1. 关联fd和EventLoop                                                 │   │
│  │ 2. 管理fd关心的事件（读/写/错误）                                    │   │
│  │ 3. 保存各种事件的回调函数                                            │   │
│  │ 4. 当事件发生时调用相应回调                                          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Channel与fd的关系：                                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                                                                     │   │
│  │   ┌──────────────────────────────────────────────────────────────┐ │   │
│  │   │                        Channel                                │ │   │
│  │   ├──────────────────────────────────────────────────────────────┤ │   │
│  │   │  fd_          ─────→  文件描述符                              │ │   │
│  │   │  events_      ─────→  关心的事件 (EPOLLIN | EPOLLOUT)        │ │   │
│  │   │  revents_     ─────→  实际发生的事件                          │ │   │
│  │   │                                                               │ │   │
│  │   │  read_callback_   ─→  可读时调用                              │ │   │
│  │   │  write_callback_  ─→  可写时调用                              │ │   │
│  │   │  close_callback_  ─→  关闭时调用                              │ │   │
│  │   │  error_callback_  ─→  错误时调用                              │ │   │
│  │   └──────────────────────────────────────────────────────────────┘ │   │
│  │                                                                     │   │
│  │   注意：                                                            │   │
│  │   • Channel不拥有fd的所有权                                         │   │
│  │   • fd的创建和关闭由其所有者负责                                    │   │
│  │   • Channel只负责事件管理和回调分发                                 │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 5.2 Channel生命周期

```cpp
// channel_lifecycle.cpp - Channel生命周期演示
#include "event_loop.hpp"
#include <sys/timerfd.h>

using namespace reactor;

/*
Channel生命周期管理：

┌─────────────────────────────────────────────────────────────────────────────┐
│                        Channel生命周期                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. 创建阶段                                                                │
│     ┌──────────────────────────────────────────────────────────────────┐   │
│     │ • 创建fd（socket/timerfd/eventfd等）                              │   │
│     │ • 创建Channel对象，关联fd                                         │   │
│     │ • 设置回调函数                                                    │   │
│     │ • 启用感兴趣的事件                                                │   │
│     └──────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  2. 注册阶段                                                                │
│     ┌──────────────────────────────────────────────────────────────────┐   │
│     │ • 调用EventLoop::update_channel()                                 │   │
│     │ • Channel被添加到Poller中                                         │   │
│     │ • 开始监听事件                                                    │   │
│     └──────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  3. 运行阶段                                                                │
│     ┌──────────────────────────────────────────────────────────────────┐   │
│     │ • 事件发生时，Poller返回Channel                                   │   │
│     │ • EventLoop调用Channel::handle_event()                           │   │
│     │ • Channel调用相应的回调函数                                       │   │
│     │ • 可以动态修改监听的事件                                          │   │
│     └──────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  4. 销毁阶段                                                                │
│     ┌──────────────────────────────────────────────────────────────────┐   │
│     │ • 禁用所有事件：channel->disable_all()                            │   │
│     │ • 从EventLoop移除：loop->remove_channel(channel)                  │   │
│     │ • 关闭fd                                                          │   │
│     │ • 销毁Channel对象                                                 │   │
│     └──────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
*/

class TimerExample {
public:
    TimerExample(EventLoop& loop) : loop_(loop) {
        // 1. 创建timerfd
        timer_fd_ = timerfd_create(CLOCK_MONOTONIC, TFD_NONBLOCK | TFD_CLOEXEC);
        if (timer_fd_ < 0) {
            throw std::runtime_error("timerfd_create failed");
        }

        // 2. 创建Channel并设置回调
        timer_channel_ = std::make_unique<Channel>(timer_fd_);
        timer_channel_->set_read_callback([this]() { handle_timeout(); });
        timer_channel_->enable_reading();

        // 3. 注册到EventLoop
        loop_.update_channel(timer_channel_.get());

        std::cout << "[Timer] Created timer, fd=" << timer_fd_ << std::endl;
    }

    ~TimerExample() {
        // 4. 销毁阶段
        if (timer_channel_) {
            timer_channel_->disable_all();
            loop_.remove_channel(timer_channel_.get());
        }
        if (timer_fd_ >= 0) {
            close(timer_fd_);
        }
        std::cout << "[Timer] Destroyed" << std::endl;
    }

    void start(int interval_seconds) {
        itimerspec its{};
        its.it_value.tv_sec = interval_seconds;
        its.it_interval.tv_sec = interval_seconds;

        if (timerfd_settime(timer_fd_, 0, &its, nullptr) < 0) {
            throw std::runtime_error("timerfd_settime failed");
        }

        std::cout << "[Timer] Started with interval " << interval_seconds << "s" << std::endl;
    }

    void stop() {
        itimerspec its{};
        timerfd_settime(timer_fd_, 0, &its, nullptr);
        std::cout << "[Timer] Stopped" << std::endl;
    }

private:
    void handle_timeout() {
        // 必须读取timerfd，否则会一直触发
        uint64_t expirations = 0;
        ssize_t n = read(timer_fd_, &expirations, sizeof(expirations));

        if (n == sizeof(expirations)) {
            std::cout << "[Timer] Timeout! expirations=" << expirations << std::endl;
            ++timeout_count_;

            // 演示：3次后停止
            if (timeout_count_ >= 3) {
                std::cout << "[Timer] Stopping after 3 timeouts" << std::endl;
                loop_.quit();
            }
        }
    }

private:
    EventLoop& loop_;
    int timer_fd_ = -1;
    std::unique_ptr<Channel> timer_channel_;
    int timeout_count_ = 0;
};

void demo_channel_lifecycle() {
    std::cout << "\n=== Channel Lifecycle Demo ===" << std::endl;

    EventLoop loop;

    {
        // 在作用域内创建Timer
        TimerExample timer(loop);
        timer.start(1);  // 1秒间隔

        // 运行事件循环
        loop.loop();

        // 作用域结束，Timer自动销毁
    }

    std::cout << "Demo completed" << std::endl;
}
```

---

### Day 12-14：单线程Reactor整合（15小时）

#### 6.1 Acceptor设计

```cpp
// acceptor.hpp - 连接接受器
#pragma once

#include "event_loop.hpp"
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <fcntl.h>

namespace reactor {

class Acceptor {
public:
    using NewConnectionCallback = std::function<void(int fd, const sockaddr_in& addr)>;

    Acceptor(EventLoop& loop, int port)
        : loop_(loop),
          listen_fd_(create_socket()),
          listen_channel_(listen_fd_) {

        // 设置socket选项
        int opt = 1;
        setsockopt(listen_fd_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
        setsockopt(listen_fd_, SOL_SOCKET, SO_REUSEPORT, &opt, sizeof(opt));

        // 绑定地址
        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = INADDR_ANY;
        addr.sin_port = htons(port);

        if (bind(listen_fd_, (sockaddr*)&addr, sizeof(addr)) < 0) {
            close(listen_fd_);
            throw std::runtime_error("bind failed: " + std::string(strerror(errno)));
        }

        // 设置Channel回调
        listen_channel_.set_read_callback([this]() { handle_accept(); });

        std::cout << "[Acceptor] Bindto port " << port << std::endl;
    }

    ~Acceptor() {
        listen_channel_.disable_all();
        loop_.remove_channel(&listen_channel_);
        close(listen_fd_);
    }

    void set_new_connection_callback(NewConnectionCallback cb) {
        new_connection_callback_ = std::move(cb);
    }

    void listen() {
        if (::listen(listen_fd_, SOMAXCONN) < 0) {
            throw std::runtime_error("listen failed");
        }

        listen_channel_.enable_reading();
        loop_.update_channel(&listen_channel_);

        std::cout << "[Acceptor] Listening..." << std::endl;
    }

private:
    static int create_socket() {
        int fd = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK | SOCK_CLOEXEC, 0);
        if (fd < 0) {
            throw std::runtime_error("socket failed");
        }
        return fd;
    }

    void handle_accept() {
        loop_.assert_in_loop_thread();

        sockaddr_in peer_addr{};
        socklen_t peer_len = sizeof(peer_addr);

        // 循环accept直到EAGAIN（边缘触发模式）
        while (true) {
            int conn_fd = accept4(listen_fd_,
                                  (sockaddr*)&peer_addr,
                                  &peer_len,
                                  SOCK_NONBLOCK | SOCK_CLOEXEC);

            if (conn_fd < 0) {
                if (errno == EAGAIN || errno == EWOULDBLOCK) {
                    break;  // 没有更多连接
                }
                perror("accept4");
                continue;
            }

            char ip[INET_ADDRSTRLEN];
            inet_ntop(AF_INET, &peer_addr.sin_addr, ip, sizeof(ip));
            std::cout << "[Acceptor] New connection from " << ip
                      << ":" << ntohs(peer_addr.sin_port)
                      << ", fd=" << conn_fd << std::endl;

            if (new_connection_callback_) {
                new_connection_callback_(conn_fd, peer_addr);
            } else {
                // 没有回调，关闭连接
                close(conn_fd);
            }
        }
    }

private:
    EventLoop& loop_;
    int listen_fd_;
    Channel listen_channel_;
    NewConnectionCallback new_connection_callback_;
};

} // namespace reactor
```

#### 6.2 TcpConnection设计

```cpp
// tcp_connection.hpp - TCP连接管理
#pragma once

#include "event_loop.hpp"
#include "buffer.hpp"
#include <netinet/in.h>
#include <netinet/tcp.h>

namespace reactor {

class TcpConnection;
using TcpConnectionPtr = std::shared_ptr<TcpConnection>;

class TcpConnection : public std::enable_shared_from_this<TcpConnection> {
public:
    using MessageCallback = std::function<void(const TcpConnectionPtr&, Buffer&)>;
    using CloseCallback = std::function<void(const TcpConnectionPtr&)>;
    using WriteCompleteCallback = std::function<void(const TcpConnectionPtr&)>;

    enum class State {
        kDisconnected,
        kConnecting,
        kConnected,
        kDisconnecting
    };

    TcpConnection(EventLoop& loop, int fd, const sockaddr_in& peer_addr)
        : loop_(loop),
          fd_(fd),
          channel_(fd),
          peer_addr_(peer_addr),
          state_(State::kConnecting) {

        // 设置Channel回调
        channel_.set_read_callback([this]() { handle_read(); });
        channel_.set_write_callback([this]() { handle_write(); });
        channel_.set_close_callback([this]() { handle_close(); });
        channel_.set_error_callback([this]() { handle_error(); });

        // 设置TCP选项
        int opt = 1;
        setsockopt(fd_, IPPROTO_TCP, TCP_NODELAY, &opt, sizeof(opt));

        std::cout << "[TcpConnection] Created, fd=" << fd_ << std::endl;
    }

    ~TcpConnection() {
        std::cout << "[TcpConnection] Destroyed, fd=" << fd_ << std::endl;
    }

    // 获取fd
    int fd() const { return fd_; }

    // 获取状态
    State state() const { return state_; }
    bool connected() const { return state_ == State::kConnected; }

    // 设置回调
    void set_message_callback(MessageCallback cb) {
        message_callback_ = std::move(cb);
    }

    void set_close_callback(CloseCallback cb) {
        close_callback_ = std::move(cb);
    }

    void set_write_complete_callback(WriteCompleteCallback cb) {
        write_complete_callback_ = std::move(cb);
    }

    // 连接建立完成
    void connection_established() {
        loop_.assert_in_loop_thread();

        state_ = State::kConnected;
        channel_.enable_reading();
        loop_.update_channel(&channel_);

        std::cout << "[TcpConnection] Established, fd=" << fd_ << std::endl;
    }

    // 发送数据
    void send(const std::string& message) {
        if (state_ != State::kConnected) {
            return;
        }

        if (loop_.is_in_loop_thread()) {
            send_in_loop(message);
        } else {
            // 跨线程发送，需要投递到EventLoop
            loop_.run_in_loop([this, message]() {
                send_in_loop(message);
            });
        }
    }

    void send(const char* data, size_t len) {
        send(std::string(data, len));
    }

    // 关闭连接（半关闭，等待数据发送完）
    void shutdown() {
        if (state_ == State::kConnected) {
            state_ = State::kDisconnecting;
            loop_.run_in_loop([this]() { shutdown_in_loop(); });
        }
    }

    // 强制关闭
    void force_close() {
        if (state_ == State::kConnected || state_ == State::kDisconnecting) {
            loop_.run_in_loop([this]() { handle_close(); });
        }
    }

private:
    void send_in_loop(const std::string& message) {
        loop_.assert_in_loop_thread();

        if (state_ == State::kDisconnected) {
            return;
        }

        ssize_t nwrote = 0;
        size_t remaining = message.size();

        // 如果输出缓冲区为空，尝试直接写入
        if (output_buffer_.readable_bytes() == 0) {
            nwrote = write(fd_, message.data(), message.size());

            if (nwrote >= 0) {
                remaining = message.size() - nwrote;

                if (remaining == 0 && write_complete_callback_) {
                    // 所有数据都写完了
                    loop_.queue_in_loop([this]() {
                        if (write_complete_callback_) {
                            write_complete_callback_(shared_from_this());
                        }
                    });
                }
            } else {
                nwrote = 0;
                if (errno != EAGAIN && errno != EWOULDBLOCK) {
                    perror("write");
                    if (errno == EPIPE || errno == ECONNRESET) {
                        return;
                    }
                }
            }
        }

        // 如果有剩余数据，放入输出缓冲区
        if (remaining > 0) {
            output_buffer_.append(message.data() + nwrote, remaining);

            // 启用写事件
            if (!channel_.is_writing()) {
                channel_.enable_writing();
                loop_.update_channel(&channel_);
            }
        }
    }

    void shutdown_in_loop() {
        loop_.assert_in_loop_thread();

        if (!channel_.is_writing()) {
            // 输出缓冲区已清空，可以关闭写端
            ::shutdown(fd_, SHUT_WR);
        }
    }

    void handle_read() {
        loop_.assert_in_loop_thread();

        char buf[65536];
        ssize_t n = 0;

        // 循环读取（边缘触发模式）
        while (true) {
            n = read(fd_, buf, sizeof(buf));

            if (n > 0) {
                input_buffer_.append(buf, n);
            } else if (n == 0) {
                // 对端关闭
                handle_close();
                return;
            } else {
                if (errno == EAGAIN || errno == EWOULDBLOCK) {
                    break;  // 数据读完了
                }
                handle_error();
                return;
            }
        }

        // 调用消息回调
        if (input_buffer_.readable_bytes() > 0 && message_callback_) {
            message_callback_(shared_from_this(), input_buffer_);
        }
    }

    void handle_write() {
        loop_.assert_in_loop_thread();

        if (!channel_.is_writing()) {
            return;
        }

        // 写出输出缓冲区的数据
        while (output_buffer_.readable_bytes() > 0) {
            ssize_t n = write(fd_,
                             output_buffer_.peek(),
                             output_buffer_.readable_bytes());

            if (n > 0) {
                output_buffer_.retrieve(n);
            } else {
                if (errno == EAGAIN || errno == EWOULDBLOCK) {
                    break;
                }
                perror("write");
                break;
            }
        }

        // 如果缓冲区空了
        if (output_buffer_.readable_bytes() == 0) {
            // 禁用写事件
            channel_.disable_writing();
            loop_.update_channel(&channel_);

            // 触发写完成回调
            if (write_complete_callback_) {
                loop_.queue_in_loop([this]() {
                    if (write_complete_callback_) {
                        write_complete_callback_(shared_from_this());
                    }
                });
            }

            // 如果正在关闭，继续关闭流程
            if (state_ == State::kDisconnecting) {
                shutdown_in_loop();
            }
        }
    }

    void handle_close() {
        loop_.assert_in_loop_thread();

        state_ = State::kDisconnected;

        channel_.disable_all();
        loop_.remove_channel(&channel_);

        std::cout << "[TcpConnection] Closed, fd=" << fd_ << std::endl;

        if (close_callback_) {
            close_callback_(shared_from_this());
        }
    }

    void handle_error() {
        int err = 0;
        socklen_t len = sizeof(err);
        getsockopt(fd_, SOL_SOCKET, SO_ERROR, &err, &len);

        std::cerr << "[TcpConnection] Error: " << strerror(err) << std::endl;
    }

private:
    EventLoop& loop_;
    int fd_;
    Channel channel_;
    sockaddr_in peer_addr_;
    State state_;

    Buffer input_buffer_;
    Buffer output_buffer_;

    MessageCallback message_callback_;
    CloseCallback close_callback_;
    WriteCompleteCallback write_complete_callback_;
};

} // namespace reactor
```

#### 6.3 Buffer设计

```cpp
// buffer.hpp - 应用层缓冲区
#pragma once

#include <vector>
#include <string>
#include <algorithm>
#include <cstring>

namespace reactor {

/*
Buffer设计思路：

┌─────────────────────────────────────────────────────────────────────────────┐
│                          Buffer结构                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  +-------------------+------------------+------------------+                │
│  | prependable bytes |  readable bytes  |  writable bytes  |               │
│  |                   |     (CONTENT)    |                  |                │
│  +-------------------+------------------+------------------+                │
│  |                   |                  |                  |                │
│  0      <=      readerIndex   <=   writerIndex    <=     size              │
│                                                                             │
│  prependable = readerIndex                                                  │
│  readable = writerIndex - readerIndex                                       │
│  writable = size - writerIndex                                              │
│                                                                             │
│  特点：                                                                      │
│  1. prepend区域可以用于添加消息头（如长度前缀）                              │
│  2. 读写指针分离，避免频繁移动数据                                          │
│  3. 自动扩容                                                                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
*/

class Buffer {
public:
    static const size_t kCheapPrepend = 8;
    static const size_t kInitialSize = 1024;

    explicit Buffer(size_t initial_size = kInitialSize)
        : buffer_(kCheapPrepend + initial_size),
          reader_index_(kCheapPrepend),
          writer_index_(kCheapPrepend) {
    }

    // 可读字节数
    size_t readable_bytes() const {
        return writer_index_ - reader_index_;
    }

    // 可写字节数
    size_t writable_bytes() const {
        return buffer_.size() - writer_index_;
    }

    // prepend区域大小
    size_t prependable_bytes() const {
        return reader_index_;
    }

    // 返回可读数据的起始指针
    const char* peek() const {
        return begin() + reader_index_;
    }

    char* peek() {
        return begin() + reader_index_;
    }

    // 查找CRLF
    const char* find_crlf() const {
        const char* crlf = std::search(peek(), begin_write(), kCRLF, kCRLF + 2);
        return crlf == begin_write() ? nullptr : crlf;
    }

    // 查找EOL
    const char* find_eol() const {
        const void* eol = memchr(peek(), '\n', readable_bytes());
        return static_cast<const char*>(eol);
    }

    // 取回n字节（移动读指针）
    void retrieve(size_t len) {
        if (len < readable_bytes()) {
            reader_index_ += len;
        } else {
            retrieve_all();
        }
    }

    // 取回直到指定位置
    void retrieve_until(const char* end) {
        retrieve(end - peek());
    }

    // 取回所有数据
    void retrieve_all() {
        reader_index_ = kCheapPrepend;
        writer_index_ = kCheapPrepend;
    }

    // 取回为字符串
    std::string retrieve_as_string(size_t len) {
        std::string result(peek(), len);
        retrieve(len);
        return result;
    }

    std::string retrieve_all_as_string() {
        return retrieve_as_string(readable_bytes());
    }

    // 追加数据
    void append(const char* data, size_t len) {
        ensure_writable_bytes(len);
        std::copy(data, data + len, begin_write());
        writer_index_ += len;
    }

    void append(const std::string& str) {
        append(str.data(), str.size());
    }

    void append(const void* data, size_t len) {
        append(static_cast<const char*>(data), len);
    }

    // 确保有足够的写空间
    void ensure_writable_bytes(size_t len) {
        if (writable_bytes() < len) {
            make_space(len);
        }
    }

    // 写指针位置
    char* begin_write() {
        return begin() + writer_index_;
    }

    const char* begin_write() const {
        return begin() + writer_index_;
    }

    // 写入后移动写指针
    void has_written(size_t len) {
        writer_index_ += len;
    }

    // 撤销写入
    void unwrite(size_t len) {
        writer_index_ -= len;
    }

    // prepend数据
    void prepend(const void* data, size_t len) {
        reader_index_ -= len;
        const char* d = static_cast<const char*>(data);
        std::copy(d, d + len, begin() + reader_index_);
    }

    // 收缩到fit
    void shrink(size_t reserve) {
        Buffer other;
        other.ensure_writable_bytes(readable_bytes() + reserve);
        other.append(peek(), readable_bytes());
        swap(other);
    }

    // 获取内部容量
    size_t internal_capacity() const {
        return buffer_.capacity();
    }

    // 从fd读取数据
    ssize_t read_fd(int fd, int* saved_errno);

    void swap(Buffer& rhs) {
        buffer_.swap(rhs.buffer_);
        std::swap(reader_index_, rhs.reader_index_);
        std::swap(writer_index_, rhs.writer_index_);
    }

private:
    char* begin() {
        return buffer_.data();
    }

    const char* begin() const {
        return buffer_.data();
    }

    void make_space(size_t len) {
        if (writable_bytes() + prependable_bytes() < len + kCheapPrepend) {
            // 需要扩容
            buffer_.resize(writer_index_ + len);
        } else {
            // 移动数据到前面
            size_t readable = readable_bytes();
            std::copy(begin() + reader_index_,
                     begin() + writer_index_,
                     begin() + kCheapPrepend);
            reader_index_ = kCheapPrepend;
            writer_index_ = reader_index_ + readable;
        }
    }

private:
    std::vector<char> buffer_;
    size_t reader_index_;
    size_t writer_index_;

    static const char kCRLF[];
};

const char Buffer::kCRLF[] = "\r\n";

// 使用readv从fd读取数据（利用栈上缓冲区减少系统调用）
inline ssize_t Buffer::read_fd(int fd, int* saved_errno) {
    // 栈上缓冲区
    char extrabuf[65536];

    struct iovec vec[2];
    const size_t writable = writable_bytes();

    vec[0].iov_base = begin_write();
    vec[0].iov_len = writable;
    vec[1].iov_base = extrabuf;
    vec[1].iov_len = sizeof(extrabuf);

    // 如果buffer_已经够大，就不使用extrabuf
    const int iovcnt = (writable < sizeof(extrabuf)) ? 2 : 1;
    const ssize_t n = readv(fd, vec, iovcnt);

    if (n < 0) {
        *saved_errno = errno;
    } else if (static_cast<size_t>(n) <= writable) {
        writer_index_ += n;
    } else {
        writer_index_ = buffer_.size();
        append(extrabuf, n - writable);
    }

    return n;
}

} // namespace reactor
```

#### 6.4 单线程Echo服务器

```cpp
// single_thread_echo_server.cpp - 单线程Reactor Echo服务器
#include "event_loop.hpp"
#include "acceptor.hpp"
#include "tcp_connection.hpp"
#include <unordered_map>
#include <signal.h>

using namespace reactor;

class EchoServer {
public:
    EchoServer(int port)
        : loop_(),
          acceptor_(loop_, port) {

        acceptor_.set_new_connection_callback(
            [this](int fd, const sockaddr_in& addr) {
                on_new_connection(fd, addr);
            }
        );
    }

    void start() {
        std::cout << "\n";
        std::cout << "╔═══════════════════════════════════════════════════════════╗\n";
        std::cout << "║           Single-Thread Reactor Echo Server               ║\n";
        std::cout << "╠═══════════════════════════════════════════════════════════╣\n";
        std::cout << "║  Use: telnet/nc to connect                                ║\n";
        std::cout << "║  Ctrl+C to stop                                           ║\n";
        std::cout << "╚═══════════════════════════════════════════════════════════╝\n";
        std::cout << std::endl;

        acceptor_.listen();
        loop_.loop();
    }

    void stop() {
        loop_.quit();
    }

    EventLoop& get_loop() { return loop_; }

private:
    void on_new_connection(int fd, const sockaddr_in& addr) {
        // 创建TcpConnection
        auto conn = std::make_shared<TcpConnection>(loop_, fd, addr);

        // 设置回调
        conn->set_message_callback(
            [this](const TcpConnectionPtr& conn, Buffer& buf) {
                on_message(conn, buf);
            }
        );

        conn->set_close_callback(
            [this](const TcpConnectionPtr& conn) {
                on_close(conn);
            }
        );

        // 保存连接
        connections_[fd] = conn;

        // 连接建立完成
        conn->connection_established();

        std::cout << "[Server] Active connections: " << connections_.size() << std::endl;
    }

    void on_message(const TcpConnectionPtr& conn, Buffer& buf) {
        // Echo: 将收到的数据原样发回
        std::string message = buf.retrieve_all_as_string();
        std::cout << "[Server] Received " << message.size() << " bytes from fd "
                  << conn->fd() << std::endl;

        conn->send(message);
    }

    void on_close(const TcpConnectionPtr& conn) {
        int fd = conn->fd();
        connections_.erase(fd);
        std::cout << "[Server] Connection closed, fd=" << fd
                  << ", remaining=" << connections_.size() << std::endl;
    }

private:
    EventLoop loop_;
    Acceptor acceptor_;
    std::unordered_map<int, TcpConnectionPtr> connections_;
};

// 全局服务器指针，用于信号处理
EchoServer* g_server = nullptr;

void signal_handler(int sig) {
    std::cout << "\nReceived signal " << sig << ", stopping server..." << std::endl;
    if (g_server) {
        g_server->stop();
    }
}

int main(int argc, char* argv[]) {
    int port = 8080;
    if (argc > 1) {
        port = std::stoi(argv[1]);
    }

    // 忽略SIGPIPE
    signal(SIGPIPE, SIG_IGN);

    // 设置Ctrl+C处理
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);

    try {
        EchoServer server(port);
        g_server = &server;

        server.start();

    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return 1;
    }

    return 0;
}

/*
架构图：

┌─────────────────────────────────────────────────────────────────────────────┐
│                    Single-Thread Reactor Architecture                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│                              ┌─────────────────┐                            │
│                              │   EchoServer    │                            │
│                              └────────┬────────┘                            │
│                                       │                                     │
│                          ┌────────────┼────────────┐                        │
│                          │            │            │                        │
│                          ▼            ▼            ▼                        │
│                    ┌──────────┐ ┌──────────┐ ┌─────────────────┐            │
│                    │ EventLoop│ │ Acceptor │ │  connections_   │            │
│                    └────┬─────┘ └────┬─────┘ │  (map)          │            │
│                         │            │       └────────┬────────┘            │
│                         │            │                │                     │
│                         ▼            │                │                     │
│                    ┌──────────┐      │                │                     │
│                    │  Poller  │      │                │                     │
│                    │ (epoll)  │      │                │                     │
│                    └────┬─────┘      │                │                     │
│                         │            │                │                     │
│         ┌───────────────┼────────────┼────────────────┼───────┐             │
│         │               │            │                │       │             │
│         ▼               ▼            ▼                ▼       ▼             │
│    ┌─────────┐    ┌─────────┐  ┌─────────┐     ┌─────────┐ ┌─────────┐     │
│    │ wakeup  │    │ listen  │  │  conn1  │     │  conn2  │ │  conn3  │     │
│    │ Channel │    │ Channel │  │ Channel │     │ Channel │ │ Channel │     │
│    └─────────┘    └─────────┘  └─────────┘     └─────────┘ └─────────┘     │
│         │              │            │               │           │           │
│         ▼              ▼            ▼               ▼           ▼           │
│    ┌─────────┐    ┌─────────┐  ┌─────────┐     ┌─────────┐ ┌─────────┐     │
│    │eventfd  │    │listen_fd│  │socket_fd│     │socket_fd│ │socket_fd│     │
│    └─────────┘    └─────────┘  └─────────┘     └─────────┘ └─────────┘     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

事件处理流程：

1. EventLoop::loop()
   │
   ├──→ Poller::poll()
   │    │
   │    └──→ epoll_wait() 阻塞等待事件
   │
   ├──→ 遍历活跃Channel
   │    │
   │    └──→ Channel::handle_event()
   │         │
   │         ├──→ listen_channel: Acceptor::handle_accept()
   │         │    │
   │         │    └──→ 创建TcpConnection
   │         │
   │         └──→ conn_channel: TcpConnection::handle_read/write()
   │              │
   │              └──→ 调用用户回调 (on_message)
   │
   └──→ do_pending_functors()
        │
        └──→ 执行跨线程投递的任务
*/
```

---

### 第二周自测题

#### 概念理解

1. **EventLoop的核心职责是什么？它与Poller、Channel之间是什么关系？**

2. **为什么需要wakeup机制？它是如何实现的？**

3. **Channel不拥有fd的所有权，这样设计的好处是什么？**

4. **Buffer的prepend区域有什么用途？**

5. **TcpConnection的四种状态分别是什么？状态转换是怎样的？**

#### 编程实践

1. **实现一个定时器类，使用timerfd和Channel。**

2. **为EchoServer添加连接超时功能，超过30秒没有数据则断开。**

3. **实现一个简单的HTTP服务器，能够返回静态字符串响应。**

---

### 第二周检验标准

| 检验项 | 达标要求 | 自评 |
|--------|----------|------|
| 理解EventLoop设计 | 能画出组件关系图 | ☐ |
| 理解wakeup机制 | 能解释实现原理 | ☐ |
| 实现Channel类 | 能正确管理事件和回调 | ☐ |
| 实现Poller类 | 能封装epoll操作 | ☐ |
| 实现Acceptor | 能接受新连接 | ☐ |
| 实现TcpConnection | 能管理连接生命周期 | ☐ |
| 实现Buffer | 能高效管理缓冲区 | ☐ |
| 完成Echo服务器 | 能正确工作 | ☐ |

---

### 第二周时间分配

| 内容 | 时间 |
|------|------|
| EventLoop设计与实现 | 10小时 |
| Channel抽象实现 | 8小时 |
| Acceptor与TcpConnection | 10小时 |
| Echo服务器整合测试 | 7小时 |

---

## 第三周：多线程Reactor（Day 15-21）

> **本周目标**：实现线程池和多线程Reactor，掌握线程安全编程
> **学习时长**：35小时
> **核心产出**：线程池、多线程Reactor框架

---

### Day 15-16：线程池设计（10小时）

#### 7.1 线程池概念

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          线程池核心概念                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  为什么需要线程池？                                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 1. 避免频繁创建/销毁线程的开销                                       │   │
│  │ 2. 控制并发线程数量，防止资源耗尽                                    │   │
│  │ 3. 统一管理工作线程，简化并发编程                                    │   │
│  │ 4. 提供任务队列，实现生产者-消费者模式                               │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  线程池架构：                                                                │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                                                                     │   │
│  │   提交任务                     任务队列                              │   │
│  │   ┌─────┐                     ┌─────────────────────┐               │   │
│  │   │Task1│ ────────────────→   │ Task1 → Task2 → ... │               │   │
│  │   └─────┘                     └──────────┬──────────┘               │   │
│  │   ┌─────┐                                │                          │   │
│  │   │Task2│ ────────────────→              │                          │   │
│  │   └─────┘                                │  取出任务                 │   │
│  │   ┌─────┐                                ▼                          │   │
│  │   │Task3│ ────────────────→   ┌───────────────────────────────┐    │   │
│  │   └─────┘                     │                               │    │   │
│  │                               │  ┌──────┐ ┌──────┐ ┌──────┐  │    │   │
│  │                               │  │Worker│ │Worker│ │Worker│  │    │   │
│  │                               │  │  1   │ │  2   │ │  3   │  │    │   │
│  │                               │  └──────┘ └──────┘ └──────┘  │    │   │
│  │                               │                               │    │   │
│  │                               │        工作线程池             │    │   │
│  │                               └───────────────────────────────┘    │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 7.2 线程池实现

```cpp
// thread_pool.hpp - 高性能线程池实现
#pragma once

#include <vector>
#include <queue>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <functional>
#include <future>
#include <atomic>
#include <stdexcept>
#include <iostream>

namespace reactor {

class ThreadPool {
public:
    using Task = std::function<void()>;

    explicit ThreadPool(size_t num_threads = std::thread::hardware_concurrency())
        : running_(true) {

        if (num_threads == 0) {
            num_threads = 1;
        }

        // 创建工作线程
        workers_.reserve(num_threads);
        for (size_t i = 0; i < num_threads; ++i) {
            workers_.emplace_back([this, i]() {
                worker_thread(i);
            });
        }

        std::cout << "[ThreadPool] Created with " << num_threads << " threads" << std::endl;
    }

    ~ThreadPool() {
        shutdown();
    }

    // 禁止拷贝
    ThreadPool(const ThreadPool&) = delete;
    ThreadPool& operator=(const ThreadPool&) = delete;

    // 提交任务（返回future）
    template<typename F, typename... Args>
    auto submit(F&& f, Args&&... args)
        -> std::future<typename std::invoke_result<F, Args...>::type> {

        using return_type = typename std::invoke_result<F, Args...>::type;

        auto task = std::make_shared<std::packaged_task<return_type()>>(
            std::bind(std::forward<F>(f), std::forward<Args>(args)...)
        );

        std::future<return_type> result = task->get_future();

        {
            std::lock_guard<std::mutex> lock(mutex_);

            if (!running_) {
                throw std::runtime_error("ThreadPool is stopped");
            }

            tasks_.emplace([task]() { (*task)(); });
        }

        cv_.notify_one();
        return result;
    }

    // 提交任务（无返回值）
    void execute(Task task) {
        {
            std::lock_guard<std::mutex> lock(mutex_);

            if (!running_) {
                throw std::runtime_error("ThreadPool is stopped");
            }

            tasks_.emplace(std::move(task));
        }

        cv_.notify_one();
    }

    // 关闭线程池
    void shutdown() {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            if (!running_) return;
            running_ = false;
        }

        cv_.notify_all();

        for (std::thread& worker : workers_) {
            if (worker.joinable()) {
                worker.join();
            }
        }

        std::cout << "[ThreadPool] Shutdown complete" << std::endl;
    }

    // 获取线程数
    size_t size() const {
        return workers_.size();
    }

    // 获取待处理任务数
    size_t pending_tasks() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return tasks_.size();
    }

private:
    void worker_thread(size_t id) {
        std::cout << "[ThreadPool] Worker " << id << " started" << std::endl;

        while (true) {
            Task task;

            {
                std::unique_lock<std::mutex> lock(mutex_);

                // 等待任务或停止信号
                cv_.wait(lock, [this]() {
                    return !running_ || !tasks_.empty();
                });

                // 如果停止且没有任务，退出
                if (!running_ && tasks_.empty()) {
                    break;
                }

                // 取出任务
                task = std::move(tasks_.front());
                tasks_.pop();
            }

            // 执行任务（不持有锁）
            try {
                task();
            } catch (const std::exception& e) {
                std::cerr << "[ThreadPool] Worker " << id
                          << " caught exception: " << e.what() << std::endl;
            }
        }

        std::cout << "[ThreadPool] Worker " << id << " stopped" << std::endl;
    }

private:
    std::vector<std::thread> workers_;
    std::queue<Task> tasks_;

    mutable std::mutex mutex_;
    std::condition_variable cv_;
    std::atomic<bool> running_;
};

} // namespace reactor
```

#### 7.3 线程安全队列

```cpp
// concurrent_queue.hpp - 线程安全队列
#pragma once

#include <queue>
#include <mutex>
#include <condition_variable>
#include <optional>
#include <chrono>

namespace reactor {

template<typename T>
class ConcurrentQueue {
public:
    ConcurrentQueue() = default;

    // 禁止拷贝
    ConcurrentQueue(const ConcurrentQueue&) = delete;
    ConcurrentQueue& operator=(const ConcurrentQueue&) = delete;

    // 入队
    void push(T value) {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            queue_.push(std::move(value));
        }
        cv_.notify_one();
    }

    // 阻塞出队
    T pop() {
        std::unique_lock<std::mutex> lock(mutex_);
        cv_.wait(lock, [this]() { return !queue_.empty() || closed_; });

        if (queue_.empty()) {
            throw std::runtime_error("Queue is closed");
        }

        T value = std::move(queue_.front());
        queue_.pop();
        return value;
    }

    // 非阻塞出队
    std::optional<T> try_pop() {
        std::lock_guard<std::mutex> lock(mutex_);

        if (queue_.empty()) {
            return std::nullopt;
        }

        T value = std::move(queue_.front());
        queue_.pop();
        return value;
    }

    // 带超时的出队
    std::optional<T> pop_timeout(std::chrono::milliseconds timeout) {
        std::unique_lock<std::mutex> lock(mutex_);

        if (!cv_.wait_for(lock, timeout, [this]() {
            return !queue_.empty() || closed_;
        })) {
            return std::nullopt;  // 超时
        }

        if (queue_.empty()) {
            return std::nullopt;  // 队列关闭
        }

        T value = std::move(queue_.front());
        queue_.pop();
        return value;
    }

    // 关闭队列
    void close() {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            closed_ = true;
        }
        cv_.notify_all();
    }

    // 检查是否为空
    bool empty() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return queue_.empty();
    }

    // 获取大小
    size_t size() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return queue_.size();
    }

private:
    std::queue<T> queue_;
    mutable std::mutex mutex_;
    std::condition_variable cv_;
    bool closed_ = false;
};

/*
使用示例：

ConcurrentQueue<int> queue;

// 生产者线程
std::thread producer([&queue]() {
    for (int i = 0; i < 100; ++i) {
        queue.push(i);
    }
    queue.close();
});

// 消费者线程
std::thread consumer([&queue]() {
    while (true) {
        try {
            int value = queue.pop();
            std::cout << "Got: " << value << std::endl;
        } catch (...) {
            break;  // 队列关闭
        }
    }
});
*/

} // namespace reactor
```

---

### Day 17-18：单Reactor多线程模型（10小时）

#### 8.1 模型架构

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    单Reactor + 多线程模型                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         主线程                                       │   │
│  │                                                                     │   │
│  │                      ┌──────────────┐                               │   │
│  │                      │   Reactor    │                               │   │
│  │                      │  (EventLoop) │                               │   │
│  │                      └──────┬───────┘                               │   │
│  │                             │                                       │   │
│  │         ┌───────────────────┼───────────────────┐                   │   │
│  │         │                   │                   │                   │   │
│  │         ▼                   ▼                   ▼                   │   │
│  │    ┌─────────┐        ┌─────────┐        ┌─────────┐               │   │
│  │    │ Accept  │        │  Read   │        │  Read   │               │   │
│  │    │ Event   │        │  Event  │        │  Event  │               │   │
│  │    └────┬────┘        └────┬────┘        └────┬────┘               │   │
│  │         │                  │                  │                     │   │
│  │         │                  │ 投递任务         │                     │   │
│  │         │                  │                  │                     │   │
│  └─────────┼──────────────────┼──────────────────┼─────────────────────┘   │
│            │                  │                  │                         │
│            │                  ▼                  ▼                         │
│  ┌─────────┼─────────────────────────────────────────────────────────┐     │
│  │         │                  工作线程池                              │     │
│  │         │                                                         │     │
│  │         │   ┌──────────┐   ┌──────────┐   ┌──────────┐           │     │
│  │         │   │ Worker 1 │   │ Worker 2 │   │ Worker 3 │           │     │
│  │         │   │          │   │          │   │          │           │     │
│  │         │   │ 处理业务 │   │ 处理业务 │   │ 处理业务 │           │     │
│  │         │   │ 逻辑     │   │ 逻辑     │   │ 逻辑     │           │     │
│  │         │   └──────────┘   └──────────┘   └──────────┘           │     │
│  │         │                                                         │     │
│  └─────────┼─────────────────────────────────────────────────────────┘     │
│            │                                                               │
│            │ 处理新连接                                                    │
│            ▼                                                               │
│    创建TcpConnection                                                       │
│                                                                             │
│  特点：                                                                     │
│  • 主线程负责所有I/O事件的监听和分发                                        │
│  • 工作线程只处理业务逻辑（计算密集型任务）                                  │
│  • I/O操作仍在主线程，避免线程安全问题                                      │
│  • 适合计算密集型业务                                                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 8.2 ThreadPoolReactor实现

```cpp
// thread_pool_reactor.hpp - 单Reactor多线程服务器
#pragma once

#include "event_loop.hpp"
#include "acceptor.hpp"
#include "tcp_connection.hpp"
#include "thread_pool.hpp"
#include <unordered_map>

namespace reactor {

class ThreadPoolReactor {
public:
    using MessageCallback = std::function<void(const TcpConnectionPtr&, Buffer&)>;

    ThreadPoolReactor(int port, size_t thread_num = 4)
        : loop_(),
          acceptor_(loop_, port),
          thread_pool_(thread_num) {

        acceptor_.set_new_connection_callback(
            [this](int fd, const sockaddr_in& addr) {
                on_new_connection(fd, addr);
            }
        );
    }

    void set_message_callback(MessageCallback cb) {
        message_callback_ = std::move(cb);
    }

    void start() {
        std::cout << "\n";
        std::cout << "╔═══════════════════════════════════════════════════════════╗\n";
        std::cout << "║        Single Reactor + ThreadPool Server                 ║\n";
        std::cout << "╠═══════════════════════════════════════════════════════════╣\n";
        std::cout << "║  Reactor thread: handles all I/O events                   ║\n";
        std::cout << "║  Worker threads: handle business logic                    ║\n";
        std::cout << "╚═══════════════════════════════════════════════════════════╝\n";
        std::cout << std::endl;

        acceptor_.listen();
        loop_.loop();
    }

    void stop() {
        loop_.quit();
        thread_pool_.shutdown();
    }

private:
    void on_new_connection(int fd, const sockaddr_in& addr) {
        auto conn = std::make_shared<TcpConnection>(loop_, fd, addr);

        conn->set_message_callback(
            [this](const TcpConnectionPtr& conn, Buffer& buf) {
                on_message(conn, buf);
            }
        );

        conn->set_close_callback(
            [this](const TcpConnectionPtr& conn) {
                on_close(conn);
            }
        );

        connections_[fd] = conn;
        conn->connection_established();
    }

    void on_message(const TcpConnectionPtr& conn, Buffer& buf) {
        // 读取数据
        std::string data = buf.retrieve_all_as_string();

        // 将业务处理投递到线程池
        // 注意：这里需要拷贝数据，因为线程池中的任务可能在主线程之后执行
        auto conn_weak = std::weak_ptr<TcpConnection>(conn);

        thread_pool_.execute([this, conn_weak, data]() {
            // 在工作线程中执行业务逻辑
            std::string response = process_business(data);

            // 检查连接是否还有效
            auto conn = conn_weak.lock();
            if (!conn) return;

            // 发送响应（send内部会投递回EventLoop线程）
            conn->send(response);
        });
    }

    // 业务处理函数（在工作线程中执行）
    std::string process_business(const std::string& data) {
        // 模拟耗时计算
        std::this_thread::sleep_for(std::chrono::milliseconds(10));

        // 调用用户回调（如果设置了）
        // 注意：这里已经在工作线程中了

        // 简单处理：返回原数据（echo）
        return data;
    }

    void on_close(const TcpConnectionPtr& conn) {
        connections_.erase(conn->fd());
    }

private:
    EventLoop loop_;
    Acceptor acceptor_;
    ThreadPool thread_pool_;
    std::unordered_map<int, TcpConnectionPtr> connections_;
    MessageCallback message_callback_;
};

} // namespace reactor
```

---

### Day 19-21：线程安全与同步（15小时）

#### 9.1 runInLoop机制详解

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        runInLoop机制详解                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  问题：工作线程如何安全地操作TcpConnection？                                 │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                                                                     │   │
│  │   工作线程                            EventLoop线程                 │   │
│  │   ┌─────────────────┐                ┌─────────────────────────┐   │   │
│  │   │                 │                │                         │   │   │
│  │   │ 完成业务处理    │                │  epoll_wait()           │   │   │
│  │   │                 │                │  阻塞中...              │   │   │
│  │   │ 需要发送响应    │                │                         │   │   │
│  │   │                 │                │                         │   │   │
│  │   └────────┬────────┘                └────────────┬────────────┘   │   │
│  │            │                                      │                │   │
│  │            │ ✗ 直接调用conn->send()               │                │   │
│  │            │   会导致线程安全问题                 │                │   │
│  │            │                                      │                │   │
│  │            │ ✓ 使用runInLoop                      │                │   │
│  │            │                                      │                │   │
│  │            │ 1. 将任务加入pending_functors_       │                │   │
│  │            │ 2. 写入wakeup_fd唤醒EventLoop        │                │   │
│  │            │    ────────────────────────────────→ │                │   │
│  │            │                                      │                │   │
│  │            │                          3. epoll_wait返回            │   │
│  │            │                          4. 执行pending_functors_     │   │
│  │            │                          5. 在EventLoop线程中         │   │
│  │            │                             调用conn->send()          │   │
│  │            │                                      │                │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  runInLoop保证：                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ • 如果已在EventLoop线程，直接执行                                    │   │
│  │ • 如果在其他线程，投递到EventLoop线程执行                            │   │
│  │ • 所有对TcpConnection的操作都在EventLoop线程中执行                   │   │
│  │ • 避免了锁竞争和线程安全问题                                         │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 9.2 线程安全的连接管理

```cpp
// thread_safe_server.hpp - 线程安全的服务器实现
#pragma once

#include "event_loop.hpp"
#include "acceptor.hpp"
#include "tcp_connection.hpp"
#include "thread_pool.hpp"
#include <unordered_map>
#include <shared_mutex>

namespace reactor {

/*
线程安全考虑：

1. connections_的访问
   - 新连接：只在EventLoop线程中添加
   - 关闭连接：只在EventLoop线程中删除
   - 遍历连接：需要考虑工作线程可能在使用

2. TcpConnection的操作
   - 所有修改操作都通过runInLoop投递到EventLoop线程
   - send()内部已经处理了跨线程问题

3. 共享数据的保护
   - 使用weak_ptr防止悬挂指针
   - 使用原子操作保护简单计数器
*/

class ThreadSafeServer {
public:
    ThreadSafeServer(int port, size_t thread_num = 4)
        : loop_(),
          acceptor_(loop_, port),
          thread_pool_(thread_num) {

        acceptor_.set_new_connection_callback(
            [this](int fd, const sockaddr_in& addr) {
                handle_new_connection(fd, addr);
            }
        );
    }

    void start() {
        std::cout << "[Server] Starting..." << std::endl;
        acceptor_.listen();
        loop_.loop();
    }

    void stop() {
        // 关闭所有连接
        for (auto& [fd, conn] : connections_) {
            conn->force_close();
        }
        loop_.quit();
        thread_pool_.shutdown();
    }

    // 广播消息给所有连接（线程安全）
    void broadcast(const std::string& message) {
        // 在EventLoop线程中执行广播
        loop_.run_in_loop([this, message]() {
            for (auto& [fd, conn] : connections_) {
                if (conn->connected()) {
                    conn->send(message);
                }
            }
        });
    }

    // 获取连接数（线程安全）
    size_t connection_count() const {
        return connection_count_.load();
    }

private:
    void handle_new_connection(int fd, const sockaddr_in& addr) {
        // 已在EventLoop线程中
        loop_.assert_in_loop_thread();

        auto conn = std::make_shared<TcpConnection>(loop_, fd, addr);

        conn->set_message_callback(
            [this](const TcpConnectionPtr& conn, Buffer& buf) {
                handle_message(conn, buf);
            }
        );

        conn->set_close_callback(
            [this](const TcpConnectionPtr& conn) {
                handle_close(conn);
            }
        );

        connections_[fd] = conn;
        connection_count_.fetch_add(1);
        conn->connection_established();

        std::cout << "[Server] New connection, total: "
                  << connection_count_.load() << std::endl;
    }

    void handle_message(const TcpConnectionPtr& conn, Buffer& buf) {
        // 已在EventLoop线程中
        std::string data = buf.retrieve_all_as_string();

        // 使用weak_ptr，避免循环引用和悬挂指针
        std::weak_ptr<TcpConnection> weak_conn = conn;

        // 投递到工作线程处理
        thread_pool_.execute([this, weak_conn, data]() {
            // 模拟业务处理
            std::string response = process_data(data);

            // 获取shared_ptr，检查连接是否还有效
            auto conn = weak_conn.lock();
            if (!conn) {
                std::cout << "[Worker] Connection already closed" << std::endl;
                return;
            }

            // send()内部会自动投递到EventLoop线程
            conn->send(response);
        });
    }

    std::string process_data(const std::string& data) {
        // 模拟耗时处理
        std::this_thread::sleep_for(std::chrono::milliseconds(5));
        return "Processed: " + data;
    }

    void handle_close(const TcpConnectionPtr& conn) {
        // 已在EventLoop线程中
        loop_.assert_in_loop_thread();

        connections_.erase(conn->fd());
        connection_count_.fetch_sub(1);

        std::cout << "[Server] Connection closed, remaining: "
                  << connection_count_.load() << std::endl;
    }

private:
    EventLoop loop_;
    Acceptor acceptor_;
    ThreadPool thread_pool_;

    std::unordered_map<int, TcpConnectionPtr> connections_;  // 只在EventLoop线程中访问
    std::atomic<size_t> connection_count_{0};  // 原子计数器，可跨线程访问
};

} // namespace reactor
```

#### 9.3 无锁技术简介

```cpp
// lock_free_queue.hpp - 简单的无锁队列示例
#pragma once

#include <atomic>
#include <memory>

namespace reactor {

/*
无锁编程简介：

┌─────────────────────────────────────────────────────────────────────────────┐
│                          无锁编程核心概念                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  为什么需要无锁？                                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 1. 避免锁的开销（获取/释放、上下文切换）                             │   │
│  │ 2. 避免死锁风险                                                      │   │
│  │ 3. 更好的可扩展性（高并发场景）                                      │   │
│  │ 4. 避免优先级反转问题                                                │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  核心技术：                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 1. 原子操作（atomic）                                                │   │
│  │    - load/store                                                      │   │
│  │    - compare_exchange_weak/strong (CAS)                              │   │
│  │    - fetch_add/fetch_sub                                             │   │
│  │                                                                     │   │
│  │ 2. 内存序（memory order）                                            │   │
│  │    - relaxed: 最弱，只保证原子性                                     │   │
│  │    - acquire/release: 同步语义                                       │   │
│  │    - seq_cst: 最强，顺序一致性                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  注意事项：                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ • 无锁编程非常复杂，容易出错                                         │   │
│  │ • 大多数场景下，正确使用锁更安全                                     │   │
│  │ • 只有在性能关键路径才考虑无锁                                       │   │
│  │ • 优先使用标准库提供的无锁容器                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
*/

// 简单的无锁SPSC（单生产者单消费者）队列
template<typename T, size_t Capacity>
class SPSCQueue {
public:
    SPSCQueue() : head_(0), tail_(0) {}

    // 入队（只能由生产者调用）
    bool push(const T& value) {
        size_t head = head_.load(std::memory_order_relaxed);
        size_t next_head = (head + 1) % Capacity;

        // 检查是否满
        if (next_head == tail_.load(std::memory_order_acquire)) {
            return false;  // 队列满
        }

        buffer_[head] = value;
        head_.store(next_head, std::memory_order_release);
        return true;
    }

    // 出队（只能由消费者调用）
    bool pop(T& value) {
        size_t tail = tail_.load(std::memory_order_relaxed);

        // 检查是否空
        if (tail == head_.load(std::memory_order_acquire)) {
            return false;  // 队列空
        }

        value = buffer_[tail];
        tail_.store((tail + 1) % Capacity, std::memory_order_release);
        return true;
    }

    bool empty() const {
        return head_.load(std::memory_order_acquire) ==
               tail_.load(std::memory_order_acquire);
    }

private:
    T buffer_[Capacity];
    std::atomic<size_t> head_;  // 写指针
    std::atomic<size_t> tail_;  // 读指针
};

/*
内存序解释：

relaxed：只保证原子性，不保证顺序
┌─────────────────────────────────────────────────────────────────────────────┐
│ 线程A                    │ 线程B                                            │
│ x.store(1, relaxed)      │ y.store(1, relaxed)                              │
│ r1 = y.load(relaxed)     │ r2 = x.load(relaxed)                             │
│                          │                                                  │
│ 可能的结果：r1=0, r2=0（两个store都还没被对方看到）                          │
└─────────────────────────────────────────────────────────────────────────────┘

acquire/release：同步语义
┌─────────────────────────────────────────────────────────────────────────────┐
│ 线程A（生产者）          │ 线程B（消费者）                                   │
│ data = 42                │                                                  │
│ ready.store(1, release)  │ while(!ready.load(acquire));                     │
│                          │ assert(data == 42); // 保证成功                  │
│                          │                                                  │
│ release保证之前的写操作对acquire可见                                         │
└─────────────────────────────────────────────────────────────────────────────┘

seq_cst：顺序一致性（默认）
┌─────────────────────────────────────────────────────────────────────────────┐
│ 最强的保证，所有线程看到的操作顺序一致                                       │
│ 开销最大，但最容易理解和使用                                                 │
└─────────────────────────────────────────────────────────────────────────────┘
*/

} // namespace reactor
```

#### 9.4 多线程Echo服务器完整示例

```cpp
// multi_thread_echo_server.cpp - 完整的多线程Echo服务器
#include "thread_safe_server.hpp"
#include <signal.h>
#include <iostream>

using namespace reactor;

ThreadSafeServer* g_server = nullptr;

void signal_handler(int sig) {
    std::cout << "\nReceived signal " << sig << std::endl;
    if (g_server) {
        g_server->stop();
    }
}

int main(int argc, char* argv[]) {
    int port = 8080;
    int threads = 4;

    if (argc > 1) port = std::stoi(argv[1]);
    if (argc > 2) threads = std::stoi(argv[2]);

    signal(SIGPIPE, SIG_IGN);
    signal(SIGINT, signal_handler);

    std::cout << "\n";
    std::cout << "╔═══════════════════════════════════════════════════════════╗\n";
    std::cout << "║          Multi-Thread Reactor Echo Server                 ║\n";
    std::cout << "╠═══════════════════════════════════════════════════════════╣\n";
    std::cout << "║  Port: " << port << "                                              ║\n";
    std::cout << "║  Worker threads: " << threads << "                                        ║\n";
    std::cout << "║                                                           ║\n";
    std::cout << "║  Architecture:                                            ║\n";
    std::cout << "║  ┌───────────────┐                                        ║\n";
    std::cout << "║  │   Reactor     │  ← Main thread (I/O)                   ║\n";
    std::cout << "║  └───────┬───────┘                                        ║\n";
    std::cout << "║          │                                                ║\n";
    std::cout << "║  ┌───────┴───────┐                                        ║\n";
    std::cout << "║  │  ThreadPool   │  ← Worker threads (business)           ║\n";
    std::cout << "║  └───────────────┘                                        ║\n";
    std::cout << "╚═══════════════════════════════════════════════════════════╝\n";
    std::cout << std::endl;

    try {
        ThreadSafeServer server(port, threads);
        g_server = &server;
        server.start();
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return 1;
    }

    return 0;
}

/*
测试方法：

1. 启动服务器
   ./multi_thread_echo_server 8080 4

2. 使用多个客户端连接
   # 终端1
   nc localhost 8080

   # 终端2
   nc localhost 8080

   # 终端3 - 压力测试
   for i in {1..100}; do
       echo "Message $i" | nc -w 1 localhost 8080 &
   done

3. 观察输出
   - 新连接/断开的日志
   - 消息处理的日志
   - 连接数统计
*/
```

---

### 第三周自测题

#### 概念理解

1. **线程池的核心组件有哪些？各自的作用是什么？**

2. **为什么需要runInLoop机制？它解决了什么问题？**

3. **weak_ptr在多线程服务器中的作用是什么？**

4. **什么是无锁编程？它的优缺点是什么？**

5. **acquire/release内存序的作用是什么？**

#### 编程实践

1. **实现一个支持优先级的线程池。**

2. **为多线程服务器添加统计功能：QPS、平均响应时间等。**

3. **实现一个简单的无锁计数器，并进行多线程测试。**

---

### 第三周检验标准

| 检验项 | 达标要求 | 自评 |
|--------|----------|------|
| 实现线程池 | 能正确管理工作线程 | ☐ |
| 理解任务队列 | 能实现线程安全队列 | ☐ |
| 理解runInLoop | 能解释跨线程调用机制 | ☐ |
| 掌握weak_ptr使用 | 能正确处理连接生命周期 | ☐ |
| 了解无锁技术 | 能解释基本概念 | ☐ |
| 完成多线程服务器 | 能正确处理并发 | ☐ |

---

### 第三周时间分配

| 内容 | 时间 |
|------|------|
| 线程池设计与实现 | 10小时 |
| 多线程Reactor实现 | 10小时 |
| 线程安全编程 | 10小时 |
| 测试与调优 | 5小时 |

---

## 第四周：主从Reactor模式（Day 22-28）

> **本周目标**：实现主从Reactor架构，分析muduo网络库，完成高性能服务器框架
> **学习时长**：35小时
> **核心产出**：完整的主从Reactor框架

---

### Day 22-23：主从Reactor架构（10小时）

#### 10.1 主从Reactor模型

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        主从Reactor模式架构                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         Main Reactor Thread                          │   │
│  │                                                                     │   │
│  │                       ┌──────────────────┐                          │   │
│  │                       │   Main Reactor   │                          │   │
│  │                       │   (EventLoop)    │                          │   │
│  │                       └────────┬─────────┘                          │   │
│  │                                │                                    │   │
│  │                           监听 accept                               │   │
│  │                                │                                    │   │
│  │                       ┌────────┴────────┐                           │   │
│  │                       │    Acceptor     │                           │   │
│  │                       │  (listen_fd)    │                           │   │
│  │                       └────────┬────────┘                           │   │
│  │                                │                                    │   │
│  │                           新连接到达                                │   │
│  │                                │                                    │   │
│  └────────────────────────────────┼────────────────────────────────────┘   │
│                                   │                                        │
│                    ┌──────────────┼──────────────┐                         │
│                    │              │              │                         │
│                    ▼              ▼              ▼                         │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        Sub Reactor Threads                           │   │
│  │                                                                     │   │
│  │   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐           │   │
│  │   │ Sub Reactor 1│   │ Sub Reactor 2│   │ Sub Reactor 3│           │   │
│  │   │ (EventLoop)  │   │ (EventLoop)  │   │ (EventLoop)  │           │   │
│  │   └──────┬───────┘   └──────┬───────┘   └──────┬───────┘           │   │
│  │          │                  │                  │                    │   │
│  │     处理连接           处理连接           处理连接                  │   │
│  │     read/write        read/write        read/write                 │   │
│  │          │                  │                  │                    │   │
│  │   ┌──────┴──────┐    ┌──────┴──────┐    ┌──────┴──────┐            │   │
│  │   │conn1  conn2 │    │conn3  conn4 │    │conn5  conn6 │            │   │
│  │   └─────────────┘    └─────────────┘    └─────────────┘            │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  one loop per thread原则：                                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ • 每个线程只有一个EventLoop                                          │   │
│  │ • 每个连接只属于一个EventLoop                                        │   │
│  │ • 连接的所有操作都在所属EventLoop线程中执行                          │   │
│  │ • 避免了锁竞争，提高了并发性能                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 10.2 EventLoopThread实现

```cpp
// event_loop_thread.hpp - 运行EventLoop的线程
#pragma once

#include "event_loop.hpp"
#include <thread>
#include <mutex>
#include <condition_variable>

namespace reactor {

class EventLoopThread {
public:
    EventLoopThread() = default;

    ~EventLoopThread() {
        if (loop_) {
            loop_->quit();
        }
        if (thread_.joinable()) {
            thread_.join();
        }
    }

    // 禁止拷贝
    EventLoopThread(const EventLoopThread&) = delete;
    EventLoopThread& operator=(const EventLoopThread&) = delete;

    // 启动线程并返回EventLoop指针
    EventLoop* start() {
        thread_ = std::thread([this]() { thread_func(); });

        // 等待EventLoop创建完成
        {
            std::unique_lock<std::mutex> lock(mutex_);
            cv_.wait(lock, [this]() { return loop_ != nullptr; });
        }

        return loop_;
    }

    EventLoop* get_loop() const {
        return loop_;
    }

private:
    void thread_func() {
        EventLoop loop;

        // 通知主线程EventLoop已创建
        {
            std::lock_guard<std::mutex> lock(mutex_);
            loop_ = &loop;
        }
        cv_.notify_one();

        // 运行事件循环
        loop.loop();

        // 循环结束
        std::lock_guard<std::mutex> lock(mutex_);
        loop_ = nullptr;
    }

private:
    EventLoop* loop_ = nullptr;
    std::thread thread_;
    std::mutex mutex_;
    std::condition_variable cv_;
};

} // namespace reactor
```

#### 10.3 EventLoopThreadPool实现

```cpp
// event_loop_thread_pool.hpp - EventLoop线程池
#pragma once

#include "event_loop_thread.hpp"
#include <vector>
#include <memory>

namespace reactor {

class EventLoopThreadPool {
public:
    EventLoopThreadPool(EventLoop* base_loop, size_t num_threads)
        : base_loop_(base_loop),
          num_threads_(num_threads),
          next_(0) {
    }

    // 启动所有线程
    void start() {
        for (size_t i = 0; i < num_threads_; ++i) {
            auto thread = std::make_unique<EventLoopThread>();
            EventLoop* loop = thread->start();
            loops_.push_back(loop);
            threads_.push_back(std::move(thread));
        }

        std::cout << "[EventLoopThreadPool] Started " << num_threads_
                  << " IO threads" << std::endl;
    }

    // 获取下一个EventLoop（轮询）
    EventLoop* get_next_loop() {
        base_loop_->assert_in_loop_thread();

        // 如果没有子线程，返回主EventLoop
        if (loops_.empty()) {
            return base_loop_;
        }

        // 轮询选择
        EventLoop* loop = loops_[next_];
        next_ = (next_ + 1) % loops_.size();

        return loop;
    }

    // 根据hash值获取EventLoop（用于保证同一客户端的请求在同一线程处理）
    EventLoop* get_loop_for_hash(size_t hash_code) {
        base_loop_->assert_in_loop_thread();

        if (loops_.empty()) {
            return base_loop_;
        }

        return loops_[hash_code % loops_.size()];
    }

    // 获取所有EventLoop
    std::vector<EventLoop*> get_all_loops() {
        if (loops_.empty()) {
            return {base_loop_};
        }
        return loops_;
    }

    size_t size() const {
        return loops_.size();
    }

private:
    EventLoop* base_loop_;  // 主EventLoop
    size_t num_threads_;
    size_t next_;           // 轮询索引
    std::vector<std::unique_ptr<EventLoopThread>> threads_;
    std::vector<EventLoop*> loops_;
};

} // namespace reactor
```

#### 10.4 主从Reactor服务器

```cpp
// master_slave_reactor.hpp - 主从Reactor服务器
#pragma once

#include "event_loop.hpp"
#include "event_loop_thread_pool.hpp"
#include "acceptor.hpp"
#include "tcp_connection.hpp"
#include <unordered_map>
#include <shared_mutex>

namespace reactor {

class MasterSlaveReactor {
public:
    using MessageCallback = std::function<void(const TcpConnectionPtr&, Buffer&)>;
    using ConnectionCallback = std::function<void(const TcpConnectionPtr&)>;

    MasterSlaveReactor(int port, size_t io_threads = 4)
        : main_loop_(),
          io_thread_pool_(&main_loop_, io_threads),
          acceptor_(main_loop_, port) {

        acceptor_.set_new_connection_callback(
            [this](int fd, const sockaddr_in& addr) {
                handle_new_connection(fd, addr);
            }
        );
    }

    void set_message_callback(MessageCallback cb) {
        message_callback_ = std::move(cb);
    }

    void set_connection_callback(ConnectionCallback cb) {
        connection_callback_ = std::move(cb);
    }

    void start() {
        // 先启动IO线程池
        io_thread_pool_.start();

        std::cout << "\n";
        std::cout << "╔═══════════════════════════════════════════════════════════════╗\n";
        std::cout << "║              Master-Slave Reactor Server                      ║\n";
        std::cout << "╠═══════════════════════════════════════════════════════════════╣\n";
        std::cout << "║                                                               ║\n";
        std::cout << "║  ┌─────────────┐                                              ║\n";
        std::cout << "║  │Main Reactor │  ← Accept connections                        ║\n";
        std::cout << "║  └──────┬──────┘                                              ║\n";
        std::cout << "║         │                                                     ║\n";
        std::cout << "║    ┌────┴────┬────────┬────────┐                              ║\n";
        std::cout << "║    │         │        │        │                              ║\n";
        std::cout << "║    ▼         ▼        ▼        ▼                              ║\n";
        std::cout << "║  ┌───┐    ┌───┐    ┌───┐    ┌───┐                             ║\n";
        std::cout << "║  │Sub│    │Sub│    │Sub│    │Sub│  ← Handle I/O               ║\n";
        std::cout << "║  │ 1 │    │ 2 │    │ 3 │    │ 4 │                             ║\n";
        std::cout << "║  └───┘    └───┘    └───┘    └───┘                             ║\n";
        std::cout << "║                                                               ║\n";
        std::cout << "╚═══════════════════════════════════════════════════════════════╝\n";
        std::cout << std::endl;

        // 开始监听
        acceptor_.listen();

        // 主EventLoop开始循环
        main_loop_.loop();
    }

    void stop() {
        // 关闭所有连接
        {
            std::shared_lock<std::shared_mutex> lock(conn_mutex_);
            for (auto& [fd, conn] : connections_) {
                conn->get_loop().run_in_loop([conn]() {
                    conn->force_close();
                });
            }
        }

        main_loop_.quit();
    }

    // 获取当前连接数
    size_t connection_count() const {
        std::shared_lock<std::shared_mutex> lock(conn_mutex_);
        return connections_.size();
    }

private:
    void handle_new_connection(int fd, const sockaddr_in& addr) {
        main_loop_.assert_in_loop_thread();

        // 选择一个IO线程
        EventLoop* io_loop = io_thread_pool_.get_next_loop();

        // 在IO线程中创建TcpConnection
        io_loop->run_in_loop([this, fd, addr, io_loop]() {
            create_connection(fd, addr, *io_loop);
        });
    }

    void create_connection(int fd, const sockaddr_in& addr, EventLoop& loop) {
        auto conn = std::make_shared<TcpConnection>(loop, fd, addr);

        // 保存连接的EventLoop引用
        conn->set_loop_reference(&loop);

        conn->set_message_callback(
            [this](const TcpConnectionPtr& conn, Buffer& buf) {
                if (message_callback_) {
                    message_callback_(conn, buf);
                }
            }
        );

        conn->set_close_callback(
            [this](const TcpConnectionPtr& conn) {
                remove_connection(conn);
            }
        );

        // 添加到连接表
        {
            std::unique_lock<std::shared_mutex> lock(conn_mutex_);
            connections_[fd] = conn;
        }

        conn->connection_established();

        if (connection_callback_) {
            connection_callback_(conn);
        }

        std::cout << "[Server] New connection on IO thread, fd=" << fd
                  << ", total=" << connection_count() << std::endl;
    }

    void remove_connection(const TcpConnectionPtr& conn) {
        int fd = conn->fd();

        // 需要在主线程中从连接表移除（如果连接表需要跨线程访问）
        // 这里使用读写锁保护
        {
            std::unique_lock<std::shared_mutex> lock(conn_mutex_);
            connections_.erase(fd);
        }

        std::cout << "[Server] Connection removed, fd=" << fd
                  << ", remaining=" << connection_count() << std::endl;
    }

private:
    EventLoop main_loop_;  // 主EventLoop
    EventLoopThreadPool io_thread_pool_;  // IO线程池
    Acceptor acceptor_;

    mutable std::shared_mutex conn_mutex_;  // 保护connections_
    std::unordered_map<int, TcpConnectionPtr> connections_;

    MessageCallback message_callback_;
    ConnectionCallback connection_callback_;
};

// TcpConnection需要添加的方法
// 在tcp_connection.hpp中添加：
// void set_loop_reference(EventLoop* loop) { loop_ref_ = loop; }
// EventLoop& get_loop() { return loop_ref_ ? *loop_ref_ : loop_; }
// EventLoop* loop_ref_ = nullptr;

} // namespace reactor
```

---

### Day 24-25：muduo网络库分析（10小时）

#### 11.1 muduo整体架构

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        muduo网络库架构                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  muduo是陈硕开发的现代C++网络库，采用one loop per thread + 非阻塞IO模型     │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         核心类                                       │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                     │   │
│  │   EventLoop                    TcpServer                            │   │
│  │   ┌────────────────┐          ┌────────────────┐                   │   │
│  │   │ • Poller       │          │ • Acceptor     │                   │   │
│  │   │ • Channel集合  │          │ • EventLoop*   │                   │   │
│  │   │ • 定时器       │          │ • 连接管理     │                   │   │
│  │   │ • wakeupFd    │          │ • 线程池       │                   │   │
│  │   └────────────────┘          └────────────────┘                   │   │
│  │                                                                     │   │
│  │   Channel                      TcpConnection                        │   │
│  │   ┌────────────────┐          ┌────────────────┐                   │   │
│  │   │ • fd           │          │ • Socket       │                   │   │
│  │   │ • 事件回调     │          │ • Channel      │                   │   │
│  │   │ • EventLoop*   │          │ • Buffer×2     │                   │   │
│  │   └────────────────┘          │ • 状态机       │                   │   │
│  │                               └────────────────┘                   │   │
│  │                                                                     │   │
│  │   Buffer                       TimerQueue                           │   │
│  │   ┌────────────────┐          ┌────────────────┐                   │   │
│  │   │ • 连续内存     │          │ • timerfd      │                   │   │
│  │   │ • 读写指针     │          │ • 定时器集合   │                   │   │
│  │   │ • prepend区域  │          │ • 最小堆       │                   │   │
│  │   └────────────────┘          └────────────────┘                   │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  设计原则：                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 1. one loop per thread                                               │   │
│  │ 2. RAII管理资源                                                      │   │
│  │ 3. 只使用非阻塞IO                                                    │   │
│  │ 4. 通过回调传递业务逻辑                                              │   │
│  │ 5. 使用智能指针管理对象生命周期                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 11.2 muduo关键设计分析

```cpp
// muduo_analysis.cpp - muduo关键设计解析

/*
═══════════════════════════════════════════════════════════════════════════════
1. Channel的设计
═══════════════════════════════════════════════════════════════════════════════

muduo的Channel设计简洁优雅：

class Channel {
    EventLoop* loop_;       // 所属的EventLoop
    const int fd_;          // 文件描述符（不负责关闭）
    int events_;            // 关心的事件
    int revents_;           // 实际发生的事件
    int index_;             // Poller中的状态

    ReadEventCallback readCallback_;
    EventCallback writeCallback_;
    EventCallback closeCallback_;
    EventCallback errorCallback_;

    // tie_是一个weak_ptr，用于防止在handle_event时对象被销毁
    std::weak_ptr<void> tie_;
    bool tied_;
};

关键点：
• Channel不拥有fd，由使用者负责关闭
• 使用tie_机制防止回调时对象已销毁
• index_用于优化Poller的更新操作

═══════════════════════════════════════════════════════════════════════════════
2. Buffer的设计
═══════════════════════════════════════════════════════════════════════════════

muduo的Buffer设计考虑了多种优化：

+-------------------+------------------+------------------+
|     prependable   |    readable      |     writable     |
| (8 bytes default) |    (content)     |                  |
+-------------------+------------------+------------------+
                    |                  |
              readerIndex         writerIndex

特点：
1. prepend区域可用于添加消息长度等前缀
2. 读写索引分离，避免频繁移动数据
3. 使用vector，可自动扩容
4. readFd()使用readv+栈上缓冲区，减少系统调用

═══════════════════════════════════════════════════════════════════════════════
3. TcpConnection的生命周期管理
═══════════════════════════════════════════════════════════════════════════════

muduo使用shared_ptr管理TcpConnection：

TcpServer:
    ConnectionMap connections_;  // std::map<string, TcpConnectionPtr>

生命周期：
1. 新连接到达 → 创建TcpConnection → 加入ConnectionMap → 引用计数=1
2. 用户回调持有 → 引用计数可能>1
3. 连接关闭 → 从ConnectionMap移除
4. 所有回调执行完毕 → 引用计数=0 → 析构

关键点：
• shared_ptr保证了对象不会被过早销毁
• Channel的tie_机制提供额外保护
• 使用weak_ptr打破循环引用

═══════════════════════════════════════════════════════════════════════════════
4. 定时器实现
═══════════════════════════════════════════════════════════════════════════════

muduo使用timerfd + 最小堆实现定时器：

class TimerQueue {
    EventLoop* loop_;
    const int timerfd_;
    Channel timerfdChannel_;
    TimerList timers_;     // std::set<std::pair<Timestamp, Timer*>>
};

优点：
1. timerfd可以被epoll监控，与IO事件统一处理
2. std::set自动排序，取最近定时器O(1)
3. 添加/删除定时器O(log n)
4. 在EventLoop线程中执行回调，无需加锁
*/

// muduo风格的简单HTTP服务器示例
class MuduoStyleHttpServer {
public:
    MuduoStyleHttpServer(EventLoop* loop, int port)
        : server_(loop, port, 4) {

        server_.set_connection_callback(
            [this](const TcpConnectionPtr& conn) {
                on_connection(conn);
            }
        );

        server_.set_message_callback(
            [this](const TcpConnectionPtr& conn, Buffer& buf) {
                on_message(conn, buf);
            }
        );
    }

    void start() {
        server_.start();
    }

private:
    void on_connection(const TcpConnectionPtr& conn) {
        if (conn->connected()) {
            std::cout << "New HTTP connection" << std::endl;
        } else {
            std::cout << "HTTP connection closed" << std::endl;
        }
    }

    void on_message(const TcpConnectionPtr& conn, Buffer& buf) {
        // 简单的HTTP解析
        std::string request = buf.retrieve_all_as_string();

        if (request.find("GET") != std::string::npos) {
            std::string response =
                "HTTP/1.1 200 OK\r\n"
                "Content-Type: text/plain\r\n"
                "Content-Length: 13\r\n"
                "\r\n"
                "Hello, World!";

            conn->send(response);
        }

        // HTTP/1.0默认关闭连接
        conn->shutdown();
    }

private:
    MasterSlaveReactor server_;
};
```

---

### Day 26-27：完整Reactor框架实战（10小时）

#### 12.1 完整框架设计

```cpp
// reactor_framework.hpp - 完整的Reactor框架
#pragma once

#include "event_loop.hpp"
#include "event_loop_thread_pool.hpp"
#include "acceptor.hpp"
#include "tcp_connection.hpp"
#include "timer_queue.hpp"
#include <unordered_map>
#include <shared_mutex>
#include <any>

namespace reactor {

// 定时器ID
using TimerId = uint64_t;

// 定时器回调
using TimerCallback = std::function<void()>;

// =============================================================================
// TcpServer - 完整的TCP服务器
// =============================================================================

class TcpServer {
public:
    using MessageCallback = std::function<void(const TcpConnectionPtr&, Buffer&)>;
    using ConnectionCallback = std::function<void(const TcpConnectionPtr&)>;
    using WriteCompleteCallback = std::function<void(const TcpConnectionPtr&)>;

    struct Options {
        size_t io_threads = 4;
        bool reuse_port = true;
        size_t max_connections = 100000;
        std::chrono::seconds idle_timeout{0};  // 0表示不超时
    };

    TcpServer(int port, const Options& options = Options())
        : options_(options),
          main_loop_(),
          thread_pool_(&main_loop_, options.io_threads),
          acceptor_(main_loop_, port) {

        acceptor_.set_new_connection_callback(
            [this](int fd, const sockaddr_in& addr) {
                handle_new_connection(fd, addr);
            }
        );
    }

    // 设置回调
    void set_connection_callback(ConnectionCallback cb) {
        connection_callback_ = std::move(cb);
    }

    void set_message_callback(MessageCallback cb) {
        message_callback_ = std::move(cb);
    }

    void set_write_complete_callback(WriteCompleteCallback cb) {
        write_complete_callback_ = std::move(cb);
    }

    // 启动服务器
    void start() {
        thread_pool_.start();
        acceptor_.listen();

        print_banner();
        main_loop_.loop();
    }

    // 停止服务器
    void stop() {
        // 关闭所有连接
        std::vector<TcpConnectionPtr> conns;
        {
            std::shared_lock<std::shared_mutex> lock(conn_mutex_);
            for (auto& [fd, conn] : connections_) {
                conns.push_back(conn);
            }
        }

        for (auto& conn : conns) {
            conn->force_close();
        }

        main_loop_.quit();
    }

    // 获取统计信息
    size_t connection_count() const {
        std::shared_lock<std::shared_mutex> lock(conn_mutex_);
        return connections_.size();
    }

    // 广播消息
    void broadcast(const std::string& message) {
        std::shared_lock<std::shared_mutex> lock(conn_mutex_);
        for (auto& [fd, conn] : connections_) {
            conn->send(message);
        }
    }

    // 定时器支持
    TimerId run_at(std::chrono::steady_clock::time_point time, TimerCallback cb) {
        return timer_queue_.add_timer(time, std::move(cb), std::chrono::milliseconds(0));
    }

    TimerId run_after(std::chrono::milliseconds delay, TimerCallback cb) {
        return timer_queue_.add_timer(
            std::chrono::steady_clock::now() + delay,
            std::move(cb),
            std::chrono::milliseconds(0)
        );
    }

    TimerId run_every(std::chrono::milliseconds interval, TimerCallback cb) {
        return timer_queue_.add_timer(
            std::chrono::steady_clock::now() + interval,
            std::move(cb),
            interval
        );
    }

    void cancel_timer(TimerId id) {
        timer_queue_.cancel(id);
    }

private:
    void print_banner() {
        std::cout << R"(
╔═══════════════════════════════════════════════════════════════════════════╗
║                                                                           ║
║   ██████╗ ███████╗ █████╗  ██████╗████████╗ ██████╗ ██████╗              ║
║   ██╔══██╗██╔════╝██╔══██╗██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗             ║
║   ██████╔╝█████╗  ███████║██║        ██║   ██║   ██║██████╔╝             ║
║   ██╔══██╗██╔══╝  ██╔══██║██║        ██║   ██║   ██║██╔══██╗             ║
║   ██║  ██║███████╗██║  ██║╚██████╗   ██║   ╚██████╔╝██║  ██║             ║
║   ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝             ║
║                                                                           ║
║   High-Performance Network Framework                                      ║
║   IO Threads: )" << options_.io_threads << R"(                                                       ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
)" << std::endl;
    }

    void handle_new_connection(int fd, const sockaddr_in& addr) {
        // 检查连接数限制
        if (connection_count() >= options_.max_connections) {
            std::cerr << "[Server] Max connections reached, rejecting" << std::endl;
            close(fd);
            return;
        }

        // 选择IO线程
        EventLoop* io_loop = thread_pool_.get_next_loop();

        // 在IO线程中创建连接
        io_loop->run_in_loop([this, fd, addr, io_loop]() {
            create_connection(fd, addr, *io_loop);
        });
    }

    void create_connection(int fd, const sockaddr_in& addr, EventLoop& loop) {
        auto conn = std::make_shared<TcpConnection>(loop, fd, addr);

        conn->set_message_callback(message_callback_);
        conn->set_write_complete_callback(write_complete_callback_);
        conn->set_close_callback([this](const TcpConnectionPtr& conn) {
            remove_connection(conn);
        });

        // 添加到连接表
        {
            std::unique_lock<std::shared_mutex> lock(conn_mutex_);
            connections_[fd] = conn;
        }

        conn->connection_established();

        // 连接建立回调
        if (connection_callback_) {
            connection_callback_(conn);
        }

        // 设置空闲超时
        if (options_.idle_timeout.count() > 0) {
            setup_idle_timeout(conn);
        }
    }

    void remove_connection(const TcpConnectionPtr& conn) {
        {
            std::unique_lock<std::shared_mutex> lock(conn_mutex_);
            connections_.erase(conn->fd());
        }

        // 连接关闭回调
        if (connection_callback_) {
            connection_callback_(conn);
        }
    }

    void setup_idle_timeout(const TcpConnectionPtr& conn) {
        // 实现连接空闲超时
        // 使用定时器检查最后活跃时间
        // 这里简化处理，实际实现需要更复杂的逻辑
    }

private:
    Options options_;
    EventLoop main_loop_;
    EventLoopThreadPool thread_pool_;
    Acceptor acceptor_;
    TimerQueue timer_queue_{main_loop_};

    mutable std::shared_mutex conn_mutex_;
    std::unordered_map<int, TcpConnectionPtr> connections_;

    ConnectionCallback connection_callback_;
    MessageCallback message_callback_;
    WriteCompleteCallback write_complete_callback_;
};

} // namespace reactor
```

#### 12.2 HTTP服务器示例

```cpp
// http_server.cpp - 简单的HTTP服务器示例
#include "reactor_framework.hpp"
#include <sstream>
#include <ctime>

using namespace reactor;

class HttpServer {
public:
    HttpServer(int port)
        : server_(port, {.io_threads = 4}) {

        server_.set_message_callback(
            [this](const TcpConnectionPtr& conn, Buffer& buf) {
                handle_request(conn, buf);
            }
        );

        server_.set_connection_callback(
            [this](const TcpConnectionPtr& conn) {
                if (conn->connected()) {
                    ++total_connections_;
                }
            }
        );
    }

    void start() {
        // 定时打印统计信息
        server_.run_every(std::chrono::seconds(10), [this]() {
            print_stats();
        });

        server_.start();
    }

private:
    void handle_request(const TcpConnectionPtr& conn, Buffer& buf) {
        std::string request = buf.retrieve_all_as_string();

        // 解析请求行
        std::istringstream iss(request);
        std::string method, path, version;
        iss >> method >> path >> version;

        ++total_requests_;

        // 路由处理
        std::string response;
        if (method == "GET") {
            if (path == "/" || path == "/index.html") {
                response = make_response(200, "text/html", get_index_page());
            } else if (path == "/stats") {
                response = make_response(200, "application/json", get_stats_json());
            } else if (path == "/time") {
                response = make_response(200, "text/plain", get_current_time());
            } else {
                response = make_response(404, "text/plain", "Not Found");
            }
        } else {
            response = make_response(405, "text/plain", "Method Not Allowed");
        }

        conn->send(response);

        // HTTP/1.0默认关闭
        if (version.find("1.0") != std::string::npos) {
            conn->shutdown();
        }
    }

    std::string make_response(int code, const std::string& content_type,
                              const std::string& body) {
        std::ostringstream oss;
        oss << "HTTP/1.1 " << code << " " << get_status_text(code) << "\r\n"
            << "Content-Type: " << content_type << "\r\n"
            << "Content-Length: " << body.size() << "\r\n"
            << "Server: ReactorHTTP/1.0\r\n"
            << "\r\n"
            << body;
        return oss.str();
    }

    std::string get_status_text(int code) {
        switch (code) {
            case 200: return "OK";
            case 404: return "Not Found";
            case 405: return "Method Not Allowed";
            default: return "Unknown";
        }
    }

    std::string get_index_page() {
        return R"(<!DOCTYPE html>
<html>
<head><title>Reactor HTTP Server</title></head>
<body>
    <h1>Welcome to Reactor HTTP Server!</h1>
    <p>This server is built with the Reactor pattern.</p>
    <ul>
        <li><a href="/stats">Server Statistics</a></li>
        <li><a href="/time">Current Time</a></li>
    </ul>
</body>
</html>)";
    }

    std::string get_stats_json() {
        std::ostringstream oss;
        oss << "{"
            << "\"total_connections\":" << total_connections_.load() << ","
            << "\"total_requests\":" << total_requests_.load() << ","
            << "\"current_connections\":" << server_.connection_count()
            << "}";
        return oss.str();
    }

    std::string get_current_time() {
        auto now = std::chrono::system_clock::now();
        auto time = std::chrono::system_clock::to_time_t(now);
        return std::ctime(&time);
    }

    void print_stats() {
        std::cout << "[Stats] Connections: " << server_.connection_count()
                  << ", Total requests: " << total_requests_.load()
                  << std::endl;
    }

private:
    TcpServer server_;
    std::atomic<uint64_t> total_connections_{0};
    std::atomic<uint64_t> total_requests_{0};
};

int main(int argc, char* argv[]) {
    int port = 8080;
    if (argc > 1) {
        port = std::stoi(argv[1]);
    }

    signal(SIGPIPE, SIG_IGN);

    HttpServer server(port);
    server.start();

    return 0;
}
```

---

### Day 28：性能测试与调优（5小时）

#### 13.1 性能基准测试

```cpp
// benchmark.cpp - 性能基准测试
#include <chrono>
#include <thread>
#include <vector>
#include <atomic>
#include <iostream>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>

class Benchmark {
public:
    struct Result {
        uint64_t total_requests;
        uint64_t successful_requests;
        double duration_seconds;
        double qps;
        double avg_latency_us;
    };

    Benchmark(const std::string& host, int port, int num_threads, int duration_sec)
        : host_(host), port_(port),
          num_threads_(num_threads), duration_sec_(duration_sec) {}

    Result run() {
        std::cout << "\n";
        std::cout << "╔═══════════════════════════════════════════════════════════╗\n";
        std::cout << "║              Performance Benchmark                        ║\n";
        std::cout << "╠═══════════════════════════════════════════════════════════╣\n";
        std::cout << "║  Target: " << host_ << ":" << port_ << "                               ║\n";
        std::cout << "║  Threads: " << num_threads_ << "                                             ║\n";
        std::cout << "║  Duration: " << duration_sec_ << "s                                           ║\n";
        std::cout << "╚═══════════════════════════════════════════════════════════╝\n";
        std::cout << std::endl;

        running_ = true;
        total_requests_ = 0;
        successful_requests_ = 0;
        total_latency_us_ = 0;

        auto start = std::chrono::high_resolution_clock::now();

        // 启动工作线程
        std::vector<std::thread> threads;
        for (int i = 0; i < num_threads_; ++i) {
            threads.emplace_back([this]() { worker(); });
        }

        // 等待测试时间
        std::this_thread::sleep_for(std::chrono::seconds(duration_sec_));
        running_ = false;

        // 等待线程结束
        for (auto& t : threads) {
            t.join();
        }

        auto end = std::chrono::high_resolution_clock::now();
        double duration = std::chrono::duration<double>(end - start).count();

        Result result;
        result.total_requests = total_requests_.load();
        result.successful_requests = successful_requests_.load();
        result.duration_seconds = duration;
        result.qps = result.successful_requests / duration;
        result.avg_latency_us = total_latency_us_.load() / (double)result.successful_requests;

        print_result(result);
        return result;
    }

private:
    void worker() {
        while (running_) {
            auto start = std::chrono::high_resolution_clock::now();

            if (send_request()) {
                auto end = std::chrono::high_resolution_clock::now();
                auto latency = std::chrono::duration_cast<std::chrono::microseconds>(
                    end - start).count();

                successful_requests_.fetch_add(1);
                total_latency_us_.fetch_add(latency);
            }

            total_requests_.fetch_add(1);
        }
    }

    bool send_request() {
        int sock = socket(AF_INET, SOCK_STREAM, 0);
        if (sock < 0) return false;

        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_port = htons(port_);
        inet_pton(AF_INET, host_.c_str(), &addr.sin_addr);

        if (connect(sock, (sockaddr*)&addr, sizeof(addr)) < 0) {
            close(sock);
            return false;
        }

        const char* request = "GET / HTTP/1.0\r\n\r\n";
        if (write(sock, request, strlen(request)) < 0) {
            close(sock);
            return false;
        }

        char buf[4096];
        ssize_t n = read(sock, buf, sizeof(buf));
        close(sock);

        return n > 0;
    }

    void print_result(const Result& result) {
        std::cout << "\n";
        std::cout << "╔═══════════════════════════════════════════════════════════╗\n";
        std::cout << "║                    Benchmark Results                      ║\n";
        std::cout << "╠═══════════════════════════════════════════════════════════╣\n";
        printf("║  Total Requests:      %10lu                          ║\n",
               result.total_requests);
        printf("║  Successful Requests: %10lu                          ║\n",
               result.successful_requests);
        printf("║  Duration:            %10.2f seconds                  ║\n",
               result.duration_seconds);
        printf("║  QPS:                 %10.2f req/s                    ║\n",
               result.qps);
        printf("║  Avg Latency:         %10.2f us                       ║\n",
               result.avg_latency_us);
        std::cout << "╚═══════════════════════════════════════════════════════════╝\n";
    }

private:
    std::string host_;
    int port_;
    int num_threads_;
    int duration_sec_;

    std::atomic<bool> running_{false};
    std::atomic<uint64_t> total_requests_{0};
    std::atomic<uint64_t> successful_requests_{0};
    std::atomic<uint64_t> total_latency_us_{0};
};

int main(int argc, char* argv[]) {
    std::string host = "127.0.0.1";
    int port = 8080;
    int threads = 4;
    int duration = 10;

    if (argc > 1) host = argv[1];
    if (argc > 2) port = std::stoi(argv[2]);
    if (argc > 3) threads = std::stoi(argv[3]);
    if (argc > 4) duration = std::stoi(argv[4]);

    Benchmark bench(host, port, threads, duration);
    bench.run();

    return 0;
}
```

#### 13.2 性能调优建议

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Reactor性能调优指南                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. 系统层面调优                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ # 增加文件描述符限制                                                 │   │
│  │ ulimit -n 1000000                                                   │   │
│  │                                                                     │   │
│  │ # 调整内核参数                                                       │   │
│  │ sysctl -w net.core.somaxconn=65535                                  │   │
│  │ sysctl -w net.ipv4.tcp_max_syn_backlog=65535                        │   │
│  │ sysctl -w net.ipv4.tcp_tw_reuse=1                                   │   │
│  │ sysctl -w net.ipv4.tcp_fin_timeout=30                               │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  2. 网络层面调优                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ • 启用TCP_NODELAY减少延迟                                            │   │
│  │ • 使用SO_REUSEPORT实现负载均衡                                       │   │
│  │ • 调整TCP缓冲区大小                                                  │   │
│  │ • 考虑使用TCP_FASTOPEN                                               │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  3. 应用层面调优                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ • IO线程数 = CPU核心数                                               │   │
│  │ • 使用对象池减少内存分配                                             │   │
│  │ • 批量处理减少系统调用                                               │   │
│  │ • 使用无锁数据结构（谨慎）                                           │   │
│  │ • 避免在IO线程中执行耗时操作                                         │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  4. epoll调优                                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ • 使用边缘触发(ET)模式                                               │   │
│  │ • 合理设置epoll_wait的maxevents                                      │   │
│  │ • 避免频繁的epoll_ctl调用                                            │   │
│  │ • 使用EPOLLONESHOT处理特殊场景                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  5. 内存调优                                                                │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ • Buffer预分配适当大小                                               │   │
│  │ • 使用内存池                                                         │   │
│  │ • 避免频繁的内存拷贝                                                 │   │
│  │ • 考虑使用大页内存                                                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### 第四周自测题

#### 概念理解

1. **one loop per thread原则的含义是什么？它有什么好处？**

2. **主从Reactor与单Reactor多线程的区别是什么？各适用什么场景？**

3. **muduo网络库的Channel为什么要有tie_机制？**

4. **为什么HTTP服务器在处理HTTP/1.0请求后要关闭连接？**

5. **如何进行网络服务器的性能调优？从哪些方面入手？**

#### 编程实践

1. **实现一个支持Keep-Alive的HTTP服务器。**

2. **为框架添加连接数限制和空闲超时功能。**

3. **实现一个WebSocket服务器（握手部分）。**

---

### 第四周检验标准

| 检验项 | 达标要求 | 自评 |
|--------|----------|------|
| 实现EventLoopThread | 能正确启动和停止 | ☐ |
| 实现EventLoopThreadPool | 能实现负载均衡 | ☐ |
| 实现主从Reactor | 完整的服务器框架 | ☐ |
| 分析muduo源码 | 理解核心设计 | ☐ |
| 实现HTTP服务器 | 能正确响应请求 | ☐ |
| 进行性能测试 | 能使用benchmark工具 | ☐ |

---

### 第四周时间分配

| 内容 | 时间 |
|------|------|
| 主从Reactor实现 | 10小时 |
| muduo源码分析 | 10小时 |
| 完整框架实现 | 10小时 |
| 性能测试与调优 | 5小时 |

---

## 本月检验标准汇总

### 理论检验（20项）

| 序号 | 检验项 | 达标要求 | 自评 |
|:----:|--------|----------|:----:|
| T1 | Reactor模式核心思想 | 能画出架构图并解释事件驱动原理 | ☐ |
| T2 | Reactor vs 传统模型 | 能量化对比资源消耗和性能差异 | ☐ |
| T3 | Reactor五大组件 | 能解释Handle/Handler/Demux/Reactor/Concrete Handler | ☐ |
| T4 | select原理与限制 | 理解fd_set、FD_SETSIZE限制、每次调用开销 | ☐ |
| T5 | poll原理与改进 | 理解pollfd结构、与select的区别 | ☐ |
| T6 | epoll原理与优势 | 理解红黑树、就绪队列、回调机制 | ☐ |
| T7 | LT vs ET模式 | 能解释区别、各自适用场景、编程要求 | ☐ |
| T8 | EventLoop设计 | 理解事件循环、Poller封装、wakeup机制 | ☐ |
| T9 | Channel抽象 | 理解fd与回调的绑定、生命周期管理 | ☐ |
| T10 | Buffer设计 | 理解prepend区域、读写指针、自动扩容 | ☐ |
| T11 | 线程池原理 | 理解任务队列、工作线程、生产者-消费者模式 | ☐ |
| T12 | runInLoop机制 | 理解跨线程调用、eventfd唤醒 | ☐ |
| T13 | 线程安全编程 | 理解锁、条件变量、原子操作的使用 | ☐ |
| T14 | weak_ptr作用 | 理解防止悬挂指针、打破循环引用 | ☐ |
| T15 | 无锁技术基础 | 了解CAS、内存序、SPSC队列 | ☐ |
| T16 | one loop per thread | 理解每线程一个EventLoop的设计理念 | ☐ |
| T17 | 主从Reactor架构 | 理解MainReactor + SubReactor分工 | ☐ |
| T18 | 连接负载均衡 | 理解轮询、hash等分配策略 | ☐ |
| T19 | muduo核心设计 | 理解Channel、Buffer、TimerQueue等 | ☐ |
| T20 | 性能调优方向 | 了解系统、网络、应用层调优方法 | ☐ |

### 实践检验（20项）

| 序号 | 检验项 | 达标要求 | 自评 |
|:----:|--------|----------|:----:|
| P1 | select服务器 | 实现能处理多连接的select服务器 | ☐ |
| P2 | poll服务器 | 实现能处理多连接的poll服务器 | ☐ |
| P3 | epoll服务器 | 实现高效的epoll服务器（ET模式） | ☐ |
| P4 | LT/ET对比实验 | 验证两种模式的行为差异 | ☐ |
| P5 | 多路复用性能对比 | 完成benchmark测试 | ☐ |
| P6 | EventLoop实现 | 实现完整的事件循环 | ☐ |
| P7 | Channel实现 | 实现事件通道抽象 | ☐ |
| P8 | Poller实现 | 封装epoll操作 | ☐ |
| P9 | Acceptor实现 | 实现连接接受器 | ☐ |
| P10 | TcpConnection实现 | 实现连接管理（含状态机） | ☐ |
| P11 | Buffer实现 | 实现应用层缓冲区 | ☐ |
| P12 | 单线程Echo服务器 | 完成功能测试 | ☐ |
| P13 | ThreadPool实现 | 实现支持future的线程池 | ☐ |
| P14 | ConcurrentQueue实现 | 实现线程安全队列 | ☐ |
| P15 | 多线程Reactor | 单Reactor + 线程池模式 | ☐ |
| P16 | EventLoopThread | 实现运行EventLoop的线程 | ☐ |
| P17 | EventLoopThreadPool | 实现IO线程池 | ☐ |
| P18 | 主从Reactor服务器 | 完整的主从模式实现 | ☐ |
| P19 | HTTP服务器 | 能响应GET请求 | ☐ |
| P20 | 性能测试 | 使用benchmark工具测试QPS | ☐ |

---

## 输出物清单

### 项目目录结构

```
reactor_framework/
├── include/
│   ├── event_loop.hpp          # EventLoop核心
│   ├── channel.hpp             # Channel抽象
│   ├── poller.hpp              # Poller封装
│   ├── acceptor.hpp            # 连接接受器
│   ├── tcp_connection.hpp      # TCP连接管理
│   ├── buffer.hpp              # 应用层缓冲区
│   ├── thread_pool.hpp         # 线程池
│   ├── concurrent_queue.hpp    # 线程安全队列
│   ├── event_loop_thread.hpp   # EventLoop线程
│   ├── event_loop_thread_pool.hpp  # IO线程池
│   ├── timer_queue.hpp         # 定时器队列
│   └── tcp_server.hpp          # 完整服务器
│
├── src/
│   ├── event_loop.cpp
│   ├── channel.cpp
│   ├── poller.cpp
│   ├── acceptor.cpp
│   ├── tcp_connection.cpp
│   ├── buffer.cpp
│   └── timer_queue.cpp
│
├── examples/
│   ├── select_server.cpp       # select示例
│   ├── poll_server.cpp         # poll示例
│   ├── epoll_server.cpp        # epoll示例
│   ├── single_thread_echo.cpp  # 单线程Echo
│   ├── multi_thread_echo.cpp   # 多线程Echo
│   ├── master_slave_echo.cpp   # 主从Reactor Echo
│   └── http_server.cpp         # HTTP服务器
│
├── benchmark/
│   ├── benchmark.cpp           # 性能测试工具
│   └── results/                # 测试结果
│
├── tests/
│   ├── test_buffer.cpp
│   ├── test_thread_pool.cpp
│   └── test_event_loop.cpp
│
├── notes/
│   └── month30_reactor.md      # 学习笔记
│
├── CMakeLists.txt
└── README.md
```

### 输出物完成度检查

| 输出物 | 描述 | 完成 |
|--------|------|:----:|
| `event_loop.hpp` | EventLoop核心实现 | ☐ |
| `channel.hpp` | Channel抽象 | ☐ |
| `poller.hpp` | epoll封装 | ☐ |
| `acceptor.hpp` | 连接接受器 | ☐ |
| `tcp_connection.hpp` | TCP连接管理 | ☐ |
| `buffer.hpp` | 应用层缓冲区 | ☐ |
| `thread_pool.hpp` | 线程池实现 | ☐ |
| `event_loop_thread_pool.hpp` | IO线程池 | ☐ |
| `tcp_server.hpp` | 完整服务器框架 | ☐ |
| `select_server.cpp` | select示例 | ☐ |
| `epoll_server.cpp` | epoll示例 | ☐ |
| `single_thread_echo.cpp` | 单线程服务器 | ☐ |
| `multi_thread_echo.cpp` | 多线程服务器 | ☐ |
| `master_slave_echo.cpp` | 主从Reactor服务器 | ☐ |
| `http_server.cpp` | HTTP服务器 | ☐ |
| `benchmark.cpp` | 性能测试工具 | ☐ |
| `month30_reactor.md` | 学习笔记 | ☐ |

---

## 学习建议

### 学习路径图

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Reactor模式学习路径                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  基础阶段                     进阶阶段                     高级阶段         │
│  ┌─────────────┐            ┌─────────────┐            ┌─────────────┐     │
│  │ 理解事件驱动 │            │ 实现完整框架 │            │ 性能优化    │     │
│  │ 学习多路复用 │     →      │ 掌握线程安全 │     →      │ 源码分析    │     │
│  │ 实现基础服务 │            │ 实现主从模式 │            │ 生产实践    │     │
│  └─────────────┘            └─────────────┘            └─────────────┘     │
│       ↓                          ↓                          ↓              │
│  ┌─────────────┐            ┌─────────────┐            ┌─────────────┐     │
│  │ 第1-2周     │            │ 第3周       │            │ 第4周       │     │
│  │ 35+35小时   │            │ 35小时      │            │ 35小时      │     │
│  └─────────────┘            └─────────────┘            └─────────────┘     │
│                                                                             │
│  推荐阅读：                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 1.《Linux多线程服务端编程》陈硕 - muduo作者的权威著作               │   │
│  │ 2.《UNIX网络编程》Stevens - 网络编程圣经                            │   │
│  │ 3.《POSA Vol.2》- Reactor模式原始论文出处                           │   │
│  │ 4. muduo源码 - github.com/chenshuo/muduo                            │   │
│  │ 5. libevent源码 - 跨平台事件库参考                                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 调试技巧

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Reactor调试技巧                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. 日志调试                                                                │
│     ┌───────────────────────────────────────────────────────────────────┐  │
│     │ • 在关键路径添加日志（连接建立/关闭、事件触发）                   │  │
│     │ • 记录线程ID，便于分析多线程问题                                  │  │
│     │ • 使用不同级别的日志（DEBUG/INFO/WARN/ERROR）                     │  │
│     └───────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  2. 工具使用                                                                │
│     ┌───────────────────────────────────────────────────────────────────┐  │
│     │ • strace -e epoll_wait,read,write ./server  # 跟踪系统调用        │  │
│     │ • netstat -antp                             # 查看连接状态        │  │
│     │ • ss -s                                     # 查看socket统计      │  │
│     │ • perf top                                  # 查看CPU热点         │  │
│     │ • valgrind --tool=memcheck                  # 检查内存泄漏        │  │
│     └───────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  3. 常见问题排查                                                            │
│     ┌───────────────────────────────────────────────────────────────────┐  │
│     │ 问题：连接无法建立                                                │  │
│     │ 排查：检查listen()、accept()返回值，检查防火墙                    │  │
│     │                                                                   │  │
│     │ 问题：数据收发异常                                                │  │
│     │ 排查：检查非阻塞设置、检查EAGAIN处理、检查ET模式是否读完          │  │
│     │                                                                   │  │
│     │ 问题：内存泄漏                                                    │  │
│     │ 排查：检查TcpConnection生命周期、检查shared_ptr循环引用           │  │
│     │                                                                   │  │
│     │ 问题：程序崩溃                                                    │  │
│     │ 排查：检查fd关闭顺序、检查回调中的悬挂指针                        │  │
│     └───────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 常见错误表

| 错误 | 原因 | 解决方案 |
|------|------|----------|
| SIGPIPE | 向已关闭的socket写入 | `signal(SIGPIPE, SIG_IGN)` |
| EBADF | 操作已关闭的fd | 检查fd生命周期，在close后不再使用 |
| EAGAIN | 非阻塞操作无数据 | 正常情况，继续等待下次事件 |
| ECONNRESET | 对端强制关闭 | 正常关闭连接，不视为错误 |
| 死锁 | 回调中再次获取同一把锁 | 使用递归锁或重新设计 |
| 数据丢失 | ET模式未读完所有数据 | 循环读取直到EAGAIN |
| 内存泄漏 | TcpConnection未正确销毁 | 检查shared_ptr引用计数 |

---

## 结语

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║   ████████╗██╗  ██╗███████╗    ███████╗███╗   ██╗██████╗                     ║
║   ╚══██╔══╝██║  ██║██╔════╝    ██╔════╝████╗  ██║██╔══██╗                    ║
║      ██║   ███████║█████╗      █████╗  ██╔██╗ ██║██║  ██║                    ║
║      ██║   ██╔══██║██╔══╝      ██╔══╝  ██║╚██╗██║██║  ██║                    ║
║      ██║   ██║  ██║███████╗    ███████╗██║ ╚████║██████╔╝                    ║
║      ╚═╝   ╚═╝  ╚═╝╚══════╝    ╚══════╝╚═╝  ╚═══╝╚═════╝                     ║
║                                                                               ║
║                     Congratulations on completing Month 30!                   ║
║                                                                               ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                               ║
║   本月你学习了：                                                              ║
║                                                                               ║
║   ✓ Reactor模式的核心思想与组件模型                                          ║
║   ✓ select/poll/epoll三种I/O多路复用机制                                     ║
║   ✓ 水平触发与边缘触发的区别与应用                                           ║
║   ✓ EventLoop、Channel、Buffer等核心组件的设计与实现                         ║
║   ✓ 线程池与多线程Reactor模式                                                ║
║   ✓ 主从Reactor架构与one loop per thread原则                                 ║
║   ✓ muduo网络库的核心设计理念                                                ║
║   ✓ 高性能网络服务器的性能测试与调优                                         ║
║                                                                               ║
║   你已经掌握了构建高性能网络服务器的核心技术！                               ║
║                                                                               ║
║   ┌───────────────────────────────────────────────────────────────────────┐  ║
║   │                         知识图谱更新                                  │  ║
║   │                                                                       │  ║
║   │   Month 29: 零拷贝技术                                                │  ║
║   │       ↓                                                               │  ║
║   │   Month 30: Reactor模式 ← 你在这里！                                  │  ║
║   │       ↓                                                               │  ║
║   │   Month 31: Proactor模式（异步I/O）                                   │  ║
║   │       ↓                                                               │  ║
║   │   Month 32: Envoy架构分析                                             │  ║
║   │                                                                       │  ║
║   │   零拷贝 + Reactor = 高性能网络服务器基石                             │  ║
║   │   Reactor + Proactor = 完整的事件驱动架构知识                         │  ║
║   │                                                                       │  ║
║   └───────────────────────────────────────────────────────────────────────┘  ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

---

## 下月预告

### Month 31: Proactor模式——异步完成通知

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     Month 31 预告：Proactor模式                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Proactor与Reactor的本质区别：                                               │
│                                                                             │
│  Reactor（本月）：                     Proactor（下月）：                    │
│  ┌──────────────────────┐            ┌──────────────────────┐              │
│  │ 内核告知"可以读了"   │            │ 用户发起读请求       │              │
│  │ 用户自己执行读操作   │            │ 内核完成后告知"读完了"│              │
│  │                      │            │                      │              │
│  │ 同步I/O多路复用      │            │ 异步I/O              │              │
│  └──────────────────────┘            └──────────────────────┘              │
│                                                                             │
│  下月学习内容：                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ • Proactor vs Reactor深度对比                                        │   │
│  │ • Windows IOCP原理与实现                                             │   │
│  │ • Linux io_uring实现Proactor                                         │   │
│  │ • 跨平台异步I/O接口设计                                              │   │
│  │ • Boost.Asio源码分析                                                 │   │
│  │ • 基于Proactor的高性能服务器                                         │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  学习完Proactor后，你将完整掌握事件驱动架构的两大模式！                     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 参考资料

1. **论文**
   - Douglas Schmidt, "Reactor: An Object Behavioral Pattern for Demultiplexing and Dispatching Handles for Synchronous Events"
   - POSA Vol.2 Chapter: Reactor Pattern

2. **书籍**
   - 陈硕《Linux多线程服务端编程》
   - W. Richard Stevens《UNIX网络编程》
   - Robert Love《Linux System Programming》

3. **开源项目**
   - muduo: https://github.com/chenshuo/muduo
   - libevent: https://github.com/libevent/libevent
   - libuv: https://github.com/libuv/libuv

4. **在线资源**
   - Linux man pages: epoll(7), select(2), poll(2)
   - The C10K problem: http://www.kegel.com/c10k.html

