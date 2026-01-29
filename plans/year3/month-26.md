# Month 26: 阻塞与非阻塞I/O——I/O模型演进

## 本月主题概述

经过 Month-25 的 Socket 编程基础学习，你已经掌握了 TCP/UDP 通信的完整编程范式。但在实际的高性能服务器开发中，一个核心问题始终困扰着开发者：**如何高效地处理大量并发连接？**

Month-25 中我们使用的 thread-per-connection 模型存在严重的扩展性瓶颈——每个连接需要一个线程，而线程的创建开销、栈内存占用和上下文切换成本使得这种模型在数千连接时就会崩溃。这就是著名的 **C10K 问题**。

本月我们将深入学习 I/O 模型的演进历程，从阻塞 I/O 的本质问题出发，逐步掌握非阻塞 I/O 编程技巧，然后学习 `select` 和 `poll` 两种经典的 I/O 多路复用机制。最终，我们将构建一个**统一事件循环框架**，为 Month-27 的 epoll 深度解析和后续的 Reactor 模式实现打下坚实基础。

```
┌─────────────────────────────────────────────────────────────────────┐
│                Month-26 知识体系图                                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  I/O模型演进路线：                                                  │
│                                                                     │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐     │
│  │ 阻塞I/O  │───>│非阻塞I/O │───>│  select  │───>│   poll   │     │
│  │(Blocking)│    │(Non-blk) │    │(复用)    │    │(改进)    │     │
│  └──────────┘    └──────────┘    └──────────┘    └──────────┘     │
│       │               │               │               │            │
│       ▼               ▼               ▼               ▼            │
│  单线程阻塞     忙等轮询        fd_set位图      pollfd数组        │
│  thread-per-   EAGAIN处理      FD_SETSIZE      无fd上限          │
│  connection    应用层缓冲      O(n)扫描        事件类型丰富       │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    统一事件循环框架                          │   │
│  │  EventLoop (抽象基类)                                       │   │
│  │  ├── SelectLoop (select实现)                                │   │
│  │  ├── PollLoop (poll实现)                                    │   │
│  │  ├── Timer / TimerManager (定时器)                          │   │
│  │  └── SignalHandler (信号处理)                                │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                          │                                          │
│                          ▼                                          │
│             Month-27: epoll → EpollLoop                            │
│             Month-28: io_uring → UringLoop                         │
│             Month-29: Reactor模式 → 完整框架                       │
│                                                                     │
│  前置依赖：                                                         │
│  ├── Month-25: Socket API, TCP/UDP编程, 跨平台封装                │
│  ├── Year 2 Month-13: std::thread, mutex                          │
│  └── Year 2 Month-22: 基础EventLoop概念                           │
│                                                                     │
│  核心能力：                                                         │
│  • 理解五种I/O模型的本质区别                                       │
│  • 掌握非阻塞I/O编程范式                                          │
│  • 熟练使用select/poll进行I/O多路复用                              │
│  • 设计和实现可扩展的事件循环框架                                  │
│  • 理解C10K问题及其解决思路                                        │
└─────────────────────────────────────────────────────────────────────┘
```

### 学习目标

1. **深入理解五种I/O模型**：阻塞、非阻塞、多路复用、信号驱动、异步I/O，明确同步/异步与阻塞/非阻塞的区别
2. **掌握非阻塞I/O编程**：fcntl设置非阻塞、EAGAIN处理、非阻塞connect、应用层缓冲区设计
3. **熟练使用select**：fd_set操作、超时处理、多客户端服务器、性能局限分析
4. **熟练使用poll**：pollfd管理、事件标志、与select对比优势
5. **构建事件循环框架**：抽象EventLoop、select/poll后端、定时器和信号集成

### 学习目标量化

| 目标 | 量化指标 | 达标线 |
|------|----------|--------|
| I/O模型理论 | 能完整画出五种模型的用户/内核交互图 | 5/5 |
| 非阻塞编程 | 独立实现非阻塞connect + Buffer类 | 100% |
| select编程 | 独立编写select多客户端服务器 | 100% |
| poll编程 | 独立编写poll多客户端服务器 | 100% |
| 事件循环框架 | 框架通过功能测试和性能测试 | 100% |
| 代码示例 | 完成全部30个代码示例 | ≥25/30 |

### 综合项目概述

```
┌─────────────────────────────────────────────────────────────┐
│              统一事件循环框架 (Unified Event Loop)            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  应用层                                               │ │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────────────┐ │ │
│  │  │EchoServer │  │ChatServer │  │ HTTP Server       │ │ │
│  │  └─────┬─────┘  └─────┬─────┘  └────────┬──────────┘ │ │
│  └────────┼──────────────┼──────────────────┼────────────┘ │
│           └──────────────┼──────────────────┘              │
│                          ▼                                  │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  EventLoop 抽象层                                     │ │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐             │ │
│  │  │ add_fd() │ │modify_fd │ │remove_fd │             │ │
│  │  └──────────┘ └──────────┘ └──────────┘             │ │
│  │  ┌────────────────┐ ┌────────────────┐               │ │
│  │  │  TimerManager  │ │ SignalHandler  │               │ │
│  │  └────────────────┘ └────────────────┘               │ │
│  └───────────────────────────────────────────────────────┘ │
│                          │                                  │
│           ┌──────────────┼──────────────┐                  │
│           ▼              ▼              ▼                   │
│  ┌──────────────┐ ┌───────────┐ ┌────────────┐            │
│  │  SelectLoop  │ │ PollLoop  │ │ (EpollLoop)│            │
│  │  (Week 3)    │ │ (Week 4)  │ │ (Month-27) │            │
│  └──────────────┘ └───────────┘ └────────────┘            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 参考书目

| 书名 | 章节 | 相关性 |
|------|------|--------|
| 《UNIX网络编程》卷1 (Stevens) | 第6章 I/O复用 | select/poll核心参考 |
| 《UNIX网络编程》卷1 (Stevens) | 第16章 非阻塞I/O | 非阻塞编程范式 |
| 《Linux高性能服务器编程》(游双) | 第8-9章 | I/O模型与事件处理 |
| 《TCP/IP详解》卷2 (Stevens) | 第16章 | select实现内部原理 |

### 前置知识（Month-25 → Month-26 衔接）

| Month-25 知识 | Month-26 应用 |
|---------------|---------------|
| TCP/UDP Socket编程 | 阻塞/非阻塞服务器基础 |
| socket()/bind()/listen()/accept() | select/poll监控的对象 |
| read()/write()/send()/recv() | 非阻塞模式下的行为变化 |
| SO_RCVTIMEO/SO_SNDTIMEO | 超时控制机制之一 |
| 跨平台Socket封装 | 事件循环框架的底层支撑 |
| SIGCHLD信号处理 | self-pipe trick的前置知识 |
| errno错误处理 | EAGAIN/EWOULDBLOCK/EINPROGRESS处理 |

### 时间分配（120小时）

| 周次 | 内容 | 时间 | 占比 |
|------|------|------|------|
| W1 | I/O模型理论与阻塞I/O深入 | 25h | 21% |
| W2 | 非阻塞I/O编程 | 30h | 25% |
| W3 | select系统调用 | 35h | 29% |
| W4 | poll与事件循环框架 | 30h | 25% |

---

## 第一周：I/O模型理论与阻塞I/O深入（Day 1-7）

> **本周目标**：深入理解五种I/O模型的本质区别，认识阻塞I/O的扩展性问题，
> 掌握超时机制与阻塞控制方法，理解C10K问题的由来

### Day 1-2：五种I/O模型详解

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | 五种I/O模型逐一分析 | 3h |
| 下午 | 同步/异步 vs 阻塞/非阻塞辨析 | 3h |
| 晚上 | 模型对比与性能基准测试 | 2h |

#### 1. 五种I/O模型全景

```cpp
// ============================================================
// 五种I/O模型详解 —— Stevens经典论述
// ============================================================

/*
Unix/Linux 下的五种I/O模型（以 recvfrom/read 为例）：

一个I/O操作通常包含两个阶段：
  Phase 1: 等待数据准备好（等待网络数据到达内核缓冲区）
  Phase 2: 将数据从内核拷贝到用户空间

┌─────────────────────────────────────────────────────────────────────┐
│               模型1: 阻塞I/O (Blocking I/O)                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  用户进程                              内核                         │
│  ────────                              ────                         │
│     │                                    │                          │
│     │   recvfrom() ──────────────────>   │                          │
│     │                                    │  Phase 1: 等待数据       │
│     │   ◀── 进程阻塞（睡眠） ──▶       │  （数据未到达）          │
│     │                                    │  .....                   │
│     │                                    │  数据到达！              │
│     │                                    │  Phase 2: 拷贝数据       │
│     │   <────── 返回数据 ───────────    │  内核→用户空间           │
│     │                                    │                          │
│     ▼  继续处理                          │                          │
│                                                                     │
│  特点：                                                             │
│  - 两个阶段都阻塞（进程完全挂起）                                  │
│  - 最简单的I/O模型                                                  │
│  - 编程简单，但无法处理并发                                        │
│  - 适合：单连接客户端、简单工具                                    │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│               模型2: 非阻塞I/O (Non-blocking I/O)                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  用户进程                              内核                         │
│  ────────                              ────                         │
│     │                                    │                          │
│     │   recvfrom() ──────────────────>   │                          │
│     │   <──── EAGAIN（无数据）────────   │  Phase 1: 数据未就绪     │
│     │                                    │                          │
│     │   recvfrom() ──────────────────>   │                          │
│     │   <──── EAGAIN（无数据）────────   │  （轮询 polling）        │
│     │                                    │                          │
│     │   recvfrom() ──────────────────>   │                          │
│     │   <──── EAGAIN（无数据）────────   │  数据到达！              │
│     │                                    │                          │
│     │   recvfrom() ──────────────────>   │                          │
│     │                                    │  Phase 2: 拷贝数据       │
│     │   <────── 返回数据 ───────────    │  内核→用户空间           │
│     │                                    │                          │
│     ▼  继续处理                          │                          │
│                                                                     │
│  特点：                                                             │
│  - Phase 1 不阻塞（立即返回EAGAIN）                                │
│  - Phase 2 仍然阻塞（但通常很快）                                  │
│  - 需要用户进程反复轮询 → CPU空转浪费                              │
│  - 适合：需要同时做其他工作的场景                                  │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│               模型3: I/O多路复用 (I/O Multiplexing)                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  用户进程                              内核                         │
│  ────────                              ────                         │
│     │                                    │                          │
│     │   select()/poll() ─────────────>   │                          │
│     │                                    │  Phase 1: 监控多个fd     │
│     │   ◀── 进程阻塞在select ──▶       │  等待任一fd就绪          │
│     │                                    │  .....                   │
│     │   <──── select返回就绪fd ──────   │  fd可读！                │
│     │                                    │                          │
│     │   recvfrom() ──────────────────>   │                          │
│     │                                    │  Phase 2: 拷贝数据       │
│     │   <────── 返回数据 ───────────    │  内核→用户空间           │
│     │                                    │                          │
│     ▼  继续处理                          │                          │
│                                                                     │
│  特点：                                                             │
│  - 一个线程同时监控多个fd                                          │
│  - 阻塞在select/poll而非read/write                                 │
│  - 两次系统调用（select + recvfrom）                                │
│  - 单个连接时比阻塞I/O还慢（多了select开销）                      │
│  - 优势在于可以同时等待多个fd                                      │
│  - 适合：多连接服务器（select/poll/epoll）                         │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│               模型4: 信号驱动I/O (Signal-driven I/O)                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  用户进程                              内核                         │
│  ────────                              ────                         │
│     │                                    │                          │
│     │   sigaction(SIGIO) ────────────>   │  注册信号处理函数        │
│     │   <──── 立即返回 ─────────────    │                          │
│     │                                    │                          │
│     │   （进程继续工作）                 │  Phase 1: 等待数据       │
│     │   做其他事情...                    │  .....                   │
│     │                                    │  数据到达！              │
│     │   <════ SIGIO信号 ════════════    │  内核发送信号通知        │
│     │                                    │                          │
│     │   recvfrom() ──────────────────>   │                          │
│     │                                    │  Phase 2: 拷贝数据       │
│     │   <────── 返回数据 ───────────    │  内核→用户空间           │
│     │                                    │                          │
│     ▼  继续处理                          │                          │
│                                                                     │
│  特点：                                                             │
│  - Phase 1 完全不阻塞（内核通过信号通知）                          │
│  - Phase 2 仍然阻塞                                                │
│  - 避免了轮询的CPU浪费                                             │
│  - 信号处理的局限性（信号队列、可重入性）                          │
│  - 适合：UDP较适用，TCP不太适用（信号产生过于频繁）                │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│               模型5: 异步I/O (Asynchronous I/O)                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  用户进程                              内核                         │
│  ────────                              ────                         │
│     │                                    │                          │
│     │   aio_read() ─────────────────>    │  提交异步读请求          │
│     │   <──── 立即返回 ─────────────    │                          │
│     │                                    │                          │
│     │   （进程继续工作）                 │  Phase 1: 等待数据       │
│     │   做其他事情...                    │  .....                   │
│     │                                    │  数据到达！              │
│     │   （进程继续工作）                 │  Phase 2: 拷贝数据       │
│     │   做其他事情...                    │  内核自动拷贝到用户缓冲  │
│     │                                    │  .....                   │
│     │   <════ 信号/回调通知 ════════    │  全部完成！              │
│     │                                    │                          │
│     ▼  处理已读数据                      │                          │
│                                                                     │
│  特点：                                                             │
│  - 两个阶段都不阻塞（真正的异步）                                  │
│  - 数据拷贝由内核完成                                              │
│  - POSIX: aio_read/aio_write（实际用途有限）                       │
│  - Linux: io_uring（现代异步I/O，Month-28学习）                    │
│  - Windows: IOCP（完成端口，真正的异步I/O）                        │
│  - 适合：高性能场景（io_uring/IOCP）                               │
└─────────────────────────────────────────────────────────────────────┘
*/

#include <iostream>
#include <cstring>

// 演示：同步 vs 异步、阻塞 vs 非阻塞的区别
namespace io_model_concepts {

/*
┌──────────────────────────────────────────────────────────┐
│           同步/异步 vs 阻塞/非阻塞 四象限                │
├──────────────────────────────────────────────────────────┤
│                                                          │
│              阻塞                    非阻塞              │
│         ┌─────────────────┬─────────────────────┐       │
│         │                 │                     │       │
│   同步  │  阻塞I/O        │  非阻塞I/O          │       │
│         │  (read阻塞等待) │  (read返回EAGAIN    │       │
│         │                 │   需要轮询)         │       │
│         │  select/poll    │                     │       │
│         │  (阻塞在select) │                     │       │
│         ├─────────────────┼─────────────────────┤       │
│         │                 │                     │       │
│   异步  │  （不存在）     │  异步I/O            │       │
│         │                 │  (aio/io_uring/     │       │
│         │                 │   IOCP)             │       │
│         │                 │  内核完成后通知     │       │
│         └─────────────────┴─────────────────────┘       │
│                                                          │
│  关键区别：                                              │
│  - 同步：I/O操作（至少Phase 2）由用户进程触发并等待      │
│  - 异步：I/O操作全部由内核完成，完成后通知用户进程       │
│  - 阻塞：调用后进程挂起，直到操作完成                    │
│  - 非阻塞：调用后立即返回（可能返回错误码）              │
│                                                          │
│  注意：前四种模型都是同步的！                            │
│  因为Phase 2（数据从内核拷贝到用户空间）                 │
│  都需要用户进程参与（调用recvfrom）                      │
│  只有真正的异步I/O，两个阶段都不需要用户进程参与         │
└──────────────────────────────────────────────────────────┘
*/

} // namespace io_model_concepts

/*
┌────────────────────────────────────────────────────────────────────┐
│                    五种I/O模型对比总表                              │
├──────────┬───────────┬───────────┬───────────┬────────────────────┤
│ 模型     │ Phase 1   │ Phase 2   │ 并发能力  │ 典型应用           │
│          │ (等数据)  │ (拷数据)  │           │                    │
├──────────┼───────────┼───────────┼───────────┼────────────────────┤
│ 阻塞     │ 阻塞      │ 阻塞      │ 差（1:1） │ 简单客户端         │
│ 非阻塞   │ 非阻塞    │ 阻塞      │ 一般      │ 配合多路复用       │
│ 多路复用 │ 阻塞select│ 阻塞      │ 好        │ 多连接服务器       │
│ 信号驱动 │ 非阻塞    │ 阻塞      │ 一般      │ UDP服务器          │
│ 异步I/O  │ 非阻塞    │ 非阻塞    │ 最好      │ 高性能服务器       │
├──────────┴───────────┴───────────┴───────────┴────────────────────┤
│ select: 最多1024个fd, O(n)扫描, 跨平台                           │
│ poll:   无fd限制, O(n)扫描, POSIX标准                            │
│ epoll:  无fd限制, O(1)就绪通知, Linux专用 (Month-27)             │
│ io_uring: 真正异步, 零拷贝, Linux 5.1+ (Month-28)               │
└────────────────────────────────────────────────────────────────────┘
*/
```

#### 2. I/O模型性能基准概念

```cpp
// ============================================================
// I/O模型性能基准概念演示
// ============================================================

#include <iostream>
#include <chrono>
#include <vector>
#include <thread>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <fcntl.h>
#include <cerrno>
#include <cstring>

namespace io_benchmark {

// 辅助：获取当前时间（微秒）
inline int64_t now_us() {
    auto tp = std::chrono::steady_clock::now();
    return std::chrono::duration_cast<std::chrono::microseconds>(
        tp.time_since_epoch()
    ).count();
}

// 创建已连接的socket对（用于测试）
bool create_socket_pair(int& fd1, int& fd2) {
    int sv[2];
    if (socketpair(AF_UNIX, SOCK_STREAM, 0, sv) < 0) {
        return false;
    }
    fd1 = sv[0];
    fd2 = sv[1];
    return true;
}

// 测试1：阻塞读取延迟
void benchmark_blocking_read() {
    int fd1, fd2;
    if (!create_socket_pair(fd1, fd2)) return;

    const int iterations = 10000;
    int64_t total_us = 0;
    char buf[64];

    for (int i = 0; i < iterations; ++i) {
        // 先写入数据（确保read不会真正等待）
        write(fd2, "hello", 5);

        int64_t start = now_us();
        ssize_t n = read(fd1, buf, sizeof(buf));
        int64_t end = now_us();

        if (n > 0) {
            total_us += (end - start);
        }
    }

    std::cout << "[阻塞读取] " << iterations << "次平均延迟: "
              << (total_us / iterations) << " us" << std::endl;

    close(fd1);
    close(fd2);
}

// 测试2：非阻塞读取延迟（数据已就绪时）
void benchmark_nonblocking_read() {
    int fd1, fd2;
    if (!create_socket_pair(fd1, fd2)) return;

    // 设置非阻塞
    int flags = fcntl(fd1, F_GETFL, 0);
    fcntl(fd1, F_SETFL, flags | O_NONBLOCK);

    const int iterations = 10000;
    int64_t total_us = 0;
    char buf[64];

    for (int i = 0; i < iterations; ++i) {
        write(fd2, "hello", 5);

        int64_t start = now_us();
        ssize_t n = read(fd1, buf, sizeof(buf));
        int64_t end = now_us();

        if (n > 0) {
            total_us += (end - start);
        }
    }

    std::cout << "[非阻塞读取] " << iterations << "次平均延迟: "
              << (total_us / iterations) << " us" << std::endl;

    close(fd1);
    close(fd2);
}

// 测试3：非阻塞读取延迟（数据未就绪时的EAGAIN开销）
void benchmark_nonblocking_eagain() {
    int fd1, fd2;
    if (!create_socket_pair(fd1, fd2)) return;

    int flags = fcntl(fd1, F_GETFL, 0);
    fcntl(fd1, F_SETFL, flags | O_NONBLOCK);

    const int iterations = 100000;
    int64_t total_us = 0;
    char buf[64];
    int eagain_count = 0;

    for (int i = 0; i < iterations; ++i) {
        // 不写入数据，让read返回EAGAIN
        int64_t start = now_us();
        ssize_t n = read(fd1, buf, sizeof(buf));
        int64_t end = now_us();

        if (n < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
            ++eagain_count;
            total_us += (end - start);
        }
    }

    std::cout << "[EAGAIN开销] " << eagain_count << "次平均延迟: "
              << (total_us / eagain_count) << " us" << std::endl;

    close(fd1);
    close(fd2);
}

void run_all_benchmarks() {
    std::cout << "=== I/O模型性能基准测试 ===" << std::endl;
    std::cout << std::endl;

    benchmark_blocking_read();
    benchmark_nonblocking_read();
    benchmark_nonblocking_eagain();

    std::cout << std::endl;
    std::cout << "结论：" << std::endl;
    std::cout << "1. 数据就绪时，阻塞/非阻塞读取延迟接近" << std::endl;
    std::cout << "2. EAGAIN返回非常快（纯用户态检查）" << std::endl;
    std::cout << "3. 非阻塞的价值在于：不必等待，可以做其他事" << std::endl;
    std::cout << "4. 但忙等轮询会浪费CPU → 需要多路复用" << std::endl;
}

} // namespace io_benchmark

/*
自测题：

Q1: 五种I/O模型中，哪些是同步的，哪些是异步的？
A1: 前四种（阻塞、非阻塞、多路复用、信号驱动）都是同步的，
    因为Phase 2（数据从内核拷贝到用户空间）都需要用户进程主动调用recvfrom完成。
    只有第五种（异步I/O）是真正异步的，内核自动完成数据拷贝并通知进程。

Q2: select/poll属于阻塞还是非阻塞？
A2: select/poll本身是阻塞调用（进程阻塞在select/poll上等待fd就绪），
    但它属于I/O多路复用模型，核心价值是用一次阻塞等待替代多个fd的阻塞等待。
    配合非阻塞fd使用效果最佳。

Q3: 非阻塞I/O的主要缺点是什么？
A3: 需要用户进程不断轮询（polling），在数据未就绪时反复调用read返回EAGAIN，
    导致CPU空转浪费。这就是为什么通常将非阻塞I/O与select/poll/epoll配合使用，
    只在fd就绪时才调用read/write。

Q4: 信号驱动I/O为什么不适合TCP？
A4: TCP socket上产生SIGIO信号的条件太多（连接建立、断开、数据到达、
    发送缓冲区可用、错误等），无法区分是什么事件导致的信号。
    UDP比较适合，因为信号只在数据到达或错误时产生。
*/
```

#### Day 3-4：阻塞I/O的本质与问题

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | 阻塞时线程状态分析与单线程服务器瓶颈 | 3h |
| 下午 | Thread-per-connection模型与资源限制 | 3h |
| 晚上 | C10K问题分析 | 2h |

#### 3. 阻塞I/O的本质——线程状态分析

```cpp
// ============================================================
// 阻塞I/O时线程状态分析
// ============================================================

/*
当线程调用阻塞I/O（如read()）时，发生了什么？

┌──────────────────────────────────────────────────────────────┐
│                    线程状态转换                               │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  调用 read(fd, buf, len)                                     │
│       │                                                      │
│       ▼                                                      │
│  ┌─────────┐   内核检查：                                    │
│  │ Running │   fd的接收缓冲区有数据吗？                      │
│  └────┬────┘                                                 │
│       │                                                      │
│       ├── 有数据 ──> 拷贝到buf ──> 返回（继续Running）       │
│       │                                                      │
│       └── 无数据 ──> 线程被挂起                              │
│                        │                                     │
│                        ▼                                     │
│                   ┌──────────┐                               │
│                   │ Sleeping │  进程进入睡眠队列              │
│                   │ (TASK_   │  不占用CPU时间片               │
│                   │ INTERR.) │  等待事件唤醒                  │
│                   └────┬─────┘                               │
│                        │                                     │
│                        │  数据到达 / 信号中断 / 超时         │
│                        ▼                                     │
│                   ┌──────────┐                               │
│                   │ Runnable │  进入就绪队列                  │
│                   │          │  等待CPU调度                   │
│                   └────┬─────┘                               │
│                        │                                     │
│                        │  获得CPU时间片                       │
│                        ▼                                     │
│                   ┌──────────┐                               │
│                   │ Running  │  拷贝数据 / 返回错误          │
│                   └──────────┘                               │
│                                                              │
│  注意：                                                      │
│  - Sleeping状态不消耗CPU，但占用内存（线程栈、内核数据结构） │
│  - 大量阻塞线程 = 大量内存消耗 + 调度开销                   │
│  - 默认线程栈大小：8MB（可用ulimit -s查看）                  │
│  - 1000个线程 ≈ 8GB栈空间（虚拟内存）                       │
└──────────────────────────────────────────────────────────────┘
*/

#include <iostream>
#include <thread>
#include <vector>
#include <atomic>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <cstring>
#include <cerrno>

namespace blocking_problem {

// ============================================================
// 问题演示：单线程阻塞服务器
// ============================================================
// 这个服务器一次只能处理一个客户端！
// 当client_A连接后，client_B必须等client_A断开才能被服务

void single_thread_blocking_server(uint16_t port) {
    int listen_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (listen_fd < 0) {
        perror("socket");
        return;
    }

    int opt = 1;
    setsockopt(listen_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    addr.sin_port = htons(port);

    if (bind(listen_fd, (sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("bind");
        close(listen_fd);
        return;
    }

    if (listen(listen_fd, 5) < 0) {
        perror("listen");
        close(listen_fd);
        return;
    }

    std::cout << "[单线程服务器] 监听端口 " << port << std::endl;

    while (true) {
        // *** 阻塞点1：accept() ***
        // 如果没有新连接，线程在这里睡眠
        sockaddr_in client_addr{};
        socklen_t client_len = sizeof(client_addr);
        int client_fd = accept(listen_fd, (sockaddr*)&client_addr, &client_len);

        if (client_fd < 0) {
            perror("accept");
            continue;
        }

        char client_ip[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &client_addr.sin_addr, client_ip, sizeof(client_ip));
        std::cout << "客户端连接: " << client_ip << ":"
                  << ntohs(client_addr.sin_port) << std::endl;

        // 处理这个客户端（其他客户端无法连接！）
        char buf[1024];
        while (true) {
            // *** 阻塞点2：read() ***
            // 如果客户端不发数据，线程在这里睡眠
            ssize_t n = read(client_fd, buf, sizeof(buf));
            if (n <= 0) {
                if (n == 0) {
                    std::cout << "客户端断开" << std::endl;
                } else {
                    perror("read");
                }
                break;
            }

            // *** 潜在阻塞点3：write() ***
            // 如果发送缓冲区满，write可能阻塞
            write(client_fd, buf, n);  // echo
        }

        close(client_fd);
        // 只有断开后，才能accept下一个客户端
    }

    close(listen_fd);
}

/*
问题分析：

时间线：
  t=0   Client_A 连接 → accept返回 → 处理Client_A
  t=1   Client_B 连接 → 被放入listen backlog队列
  t=2   Client_C 连接 → 被放入listen backlog队列
  ...
  t=10  Client_A 断开 → accept返回Client_B → 处理Client_B
  t=11  Client_B 断开 → accept返回Client_C → 处理Client_C

如果backlog队列满了，新连接直接被拒绝（Connection refused）！
*/

} // namespace blocking_problem
```

#### 4. Thread-per-connection模型

```cpp
// ============================================================
// Thread-per-connection模型：解决并发，但引入新问题
// ============================================================

#include <iostream>
#include <thread>
#include <vector>
#include <mutex>
#include <atomic>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <cstring>

namespace thread_per_connection {

// 连接计数器
std::atomic<int> active_connections{0};
std::atomic<int> total_connections{0};
constexpr int MAX_CONNECTIONS = 100;  // 限制最大连接数

void handle_client(int client_fd, sockaddr_in client_addr) {
    ++active_connections;
    ++total_connections;

    char client_ip[INET_ADDRSTRLEN];
    inet_ntop(AF_INET, &client_addr.sin_addr, client_ip, sizeof(client_ip));

    std::cout << "[线程 " << std::this_thread::get_id() << "] "
              << "处理客户端: " << client_ip << ":"
              << ntohs(client_addr.sin_port)
              << " (活跃: " << active_connections.load()
              << ", 总计: " << total_connections.load() << ")" << std::endl;

    char buf[1024];
    while (true) {
        ssize_t n = read(client_fd, buf, sizeof(buf));
        if (n <= 0) break;
        write(client_fd, buf, n);
    }

    close(client_fd);
    --active_connections;
}

void thread_per_connection_server(uint16_t port) {
    int listen_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (listen_fd < 0) {
        perror("socket");
        return;
    }

    int opt = 1;
    setsockopt(listen_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    addr.sin_port = htons(port);

    bind(listen_fd, (sockaddr*)&addr, sizeof(addr));
    listen(listen_fd, 128);

    std::cout << "[Thread-per-Connection] 监听端口 " << port
              << " (最大连接: " << MAX_CONNECTIONS << ")" << std::endl;

    while (true) {
        sockaddr_in client_addr{};
        socklen_t client_len = sizeof(client_addr);
        int client_fd = accept(listen_fd, (sockaddr*)&client_addr, &client_len);

        if (client_fd < 0) {
            perror("accept");
            continue;
        }

        // 检查连接数限制
        if (active_connections.load() >= MAX_CONNECTIONS) {
            std::cerr << "连接数已满，拒绝新连接" << std::endl;
            const char* msg = "Server busy, try later\n";
            write(client_fd, msg, strlen(msg));
            close(client_fd);
            continue;
        }

        // 每个连接创建一个新线程
        std::thread t(handle_client, client_fd, client_addr);
        t.detach();  // 分离线程，让它自行结束
    }

    close(listen_fd);
}

/*
Thread-per-Connection 模型资源分析：

┌──────────────────────────────────────────────────────────────┐
│                资源消耗分析                                   │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  每个线程的开销：                                            │
│  ┌────────────────────────────────────────────┐             │
│  │ 栈空间：   8MB（默认，可通过ulimit调整）   │             │
│  │ 内核对象： ~8KB（task_struct等）            │             │
│  │ 调度开销： 上下文切换 ~1-10μs              │             │
│  └────────────────────────────────────────────┘             │
│                                                              │
│  连接数 vs 资源消耗：                                        │
│  ┌──────────┬──────────┬──────────┬──────────────┐          │
│  │ 连接数   │ 栈内存   │ 内核对象 │ 上下文切换/s │          │
│  ├──────────┼──────────┼──────────┼──────────────┤          │
│  │ 100      │ 800MB    │ 800KB    │ ~10K         │          │
│  │ 1,000    │ 8GB      │ 8MB      │ ~100K        │          │
│  │ 10,000   │ 80GB !!  │ 80MB     │ ~1M !!       │          │
│  │ 100,000  │ 不可能   │ 不可能   │ 不可能       │          │
│  └──────────┴──────────┴──────────┴──────────────┘          │
│                                                              │
│  结论：thread-per-connection 在 ~1000 连接时就到极限         │
│  这就是 C10K 问题的核心                                      │
│                                                              │
│  C10K = 如何用一台服务器同时处理10,000个并发连接？           │
│                                                              │
│  解决方案演进：                                              │
│  1. I/O多路复用（select/poll/epoll）─ 一个线程管多个fd      │
│  2. 事件驱动（Reactor模式）─ 基于epoll的事件循环            │
│  3. 协程（coroutine）─ 用户态调度，极低开销                 │
│  4. 异步I/O（io_uring）─ 内核态异步                         │
│                                                              │
│  Year 3 的学习路径正是沿着这条演进路线展开！                │
└──────────────────────────────────────────────────────────────┘
*/

} // namespace thread_per_connection

/*
自测题：

Q1: 单线程阻塞服务器最大的问题是什么？
A1: 一次只能处理一个客户端。当正在处理client_A时，其他客户端必须等待。
    accept()和read()都是阻塞点，线程在等待一个客户端时无法服务其他客户端。

Q2: thread-per-connection模型为什么不能支持10000个连接？
A2: 每个线程需要约8MB栈空间（默认），10000线程需要80GB内存。
    此外，10000线程的上下文切换开销极大（每次切换需要保存/恢复寄存器、
    刷新TLB等），会导致大量CPU时间浪费在调度上而非实际工作。

Q3: C10K问题的本质是什么？
A3: C10K问题的本质是操作系统线程模型的局限性。传统的"一个连接一个线程"模型
    消耗过多资源。解决方案是I/O多路复用，让一个线程同时管理多个连接，
    只在fd就绪时才处理，避免创建大量线程。
*/
```

#### Day 5-7：超时机制与阻塞控制

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | SO_RCVTIMEO/SO_SNDTIMEO与alarm超时 | 3h |
| 下午 | select作为超时机制、connect超时 | 3h |
| 晚上 | 综合超时方案对比与实现 | 2h |

#### 5. 超时设置方式总览

```cpp
// ============================================================
// 三种超时设置方式对比
// ============================================================

/*
┌─────────────────────────────────────────────────────────────────┐
│                    三种超时方式对比                               │
├──────────────┬──────────────────────────────────────────────────┤
│ 方式         │ 特点                                            │
├──────────────┼──────────────────────────────────────────────────┤
│ SO_RCVTIMEO  │ 简单直接；socket选项；作用于recv/read           │
│ SO_SNDTIMEO  │ 简单直接；socket选项；作用于send/write          │
│              │ 超时返回-1, errno=EAGAIN/EWOULDBLOCK             │
├──────────────┼──────────────────────────────────────────────────┤
│ alarm+SIGALRM│ 全局性；精度为秒；打断任何阻塞系统调用          │
│              │ 返回-1, errno=EINTR                              │
│              │ 不适合多线程（信号发送给整个进程）               │
├──────────────┼──────────────────────────────────────────────────┤
│ select超时   │ 最灵活；精度为微秒；可同时监控多个fd            │
│              │ 可用于实现connect超时                            │
│              │ 适合需要精确超时控制的场景                       │
└──────────────┴──────────────────────────────────────────────────┘
*/

#include <iostream>
#include <sys/socket.h>
#include <sys/select.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <cerrno>
#include <cstring>

namespace timeout_methods {

// ============================================================
// 方式1: SO_RCVTIMEO / SO_SNDTIMEO
// ============================================================

ssize_t timed_read_sockopt(int fd, void* buf, size_t len, int timeout_sec) {
    // 设置接收超时
    timeval tv;
    tv.tv_sec = timeout_sec;
    tv.tv_usec = 0;

    if (setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv)) < 0) {
        perror("setsockopt SO_RCVTIMEO");
        return -1;
    }

    ssize_t n = read(fd, buf, len);

    if (n < 0) {
        if (errno == EAGAIN || errno == EWOULDBLOCK) {
            std::cerr << "读取超时（" << timeout_sec << "秒）" << std::endl;
            return -2;  // 超时
        }
        return -1;  // 其他错误
    }

    // 恢复（取消超时）
    tv.tv_sec = 0;
    tv.tv_usec = 0;
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));

    return n;
}

ssize_t timed_write_sockopt(int fd, const void* buf, size_t len, int timeout_sec) {
    timeval tv;
    tv.tv_sec = timeout_sec;
    tv.tv_usec = 0;

    if (setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv)) < 0) {
        perror("setsockopt SO_SNDTIMEO");
        return -1;
    }

    ssize_t n = write(fd, buf, len);

    if (n < 0) {
        if (errno == EAGAIN || errno == EWOULDBLOCK) {
            std::cerr << "写入超时（" << timeout_sec << "秒）" << std::endl;
            return -2;
        }
        return -1;
    }

    tv.tv_sec = 0;
    tv.tv_usec = 0;
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));

    return n;
}

// ============================================================
// 方式2: alarm() + SIGALRM
// ============================================================

// 信号处理函数（空函数，仅用于打断阻塞调用）
void alarm_handler(int /*signo*/) {
    // 什么都不做，仅让阻塞的系统调用返回EINTR
}

ssize_t timed_read_alarm(int fd, void* buf, size_t len, int timeout_sec) {
    // 注册信号处理
    struct sigaction sa{};
    sa.sa_handler = alarm_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;  // 不设置SA_RESTART，允许EINTR
    sigaction(SIGALRM, &sa, nullptr);

    // 设置定时器
    alarm(timeout_sec);

    ssize_t n = read(fd, buf, len);
    int saved_errno = errno;

    // 取消定时器
    alarm(0);

    if (n < 0 && saved_errno == EINTR) {
        std::cerr << "读取超时（alarm " << timeout_sec << "秒）" << std::endl;
        return -2;  // 超时
    }

    errno = saved_errno;
    return n;
}

/*
alarm方式的问题：
1. 精度只有秒级
2. 信号是进程级的，多线程环境下信号可能发送给任意线程
3. 如果程序其他地方也在用alarm，会冲突
4. 不能同时对多个操作设置不同超时
结论：尽量避免使用alarm方式
*/

// ============================================================
// 方式3: select() 作为超时机制（推荐）
// ============================================================

ssize_t timed_read_select(int fd, void* buf, size_t len,
                          int timeout_sec, int timeout_usec = 0) {
    fd_set rset;
    FD_ZERO(&rset);
    FD_SET(fd, &rset);

    timeval tv;
    tv.tv_sec = timeout_sec;
    tv.tv_usec = timeout_usec;

    int ready = select(fd + 1, &rset, nullptr, nullptr, &tv);

    if (ready < 0) {
        if (errno == EINTR) {
            return -3;  // 被信号中断
        }
        return -1;  // 错误
    }

    if (ready == 0) {
        std::cerr << "读取超时（select " << timeout_sec << "."
                  << timeout_usec << "秒）" << std::endl;
        return -2;  // 超时
    }

    // fd就绪，读取数据（此时不会阻塞）
    return read(fd, buf, len);
}

ssize_t timed_write_select(int fd, const void* buf, size_t len,
                           int timeout_sec, int timeout_usec = 0) {
    fd_set wset;
    FD_ZERO(&wset);
    FD_SET(fd, &wset);

    timeval tv;
    tv.tv_sec = timeout_sec;
    tv.tv_usec = timeout_usec;

    int ready = select(fd + 1, nullptr, &wset, nullptr, &tv);

    if (ready < 0) {
        if (errno == EINTR) return -3;
        return -1;
    }

    if (ready == 0) {
        return -2;  // 超时
    }

    return write(fd, buf, len);
}

} // namespace timeout_methods
```

#### 6. connect超时——非阻塞connect + select

```cpp
// ============================================================
// connect_with_timeout：非阻塞connect + select 实现
// ============================================================
// 这是一个非常经典且重要的技术，很多网络库都使用这种方式

#include <iostream>
#include <sys/socket.h>
#include <sys/select.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <cerrno>
#include <cstring>

namespace connect_timeout {

/*
┌────────────────────────────────────────────────────────────────┐
│              非阻塞connect流程                                  │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  1. 设置socket为非阻塞                                        │
│       │                                                        │
│  2. 调用connect()                                              │
│       │                                                        │
│       ├── 返回0 → 连接立即完成（本地连接）                    │
│       │                                                        │
│       └── 返回-1                                               │
│            │                                                   │
│            ├── errno == EINPROGRESS → 连接进行中（正常）       │
│            │    │                                               │
│            │    └── 用select等待可写                            │
│            │         │                                          │
│            │         ├── 超时 → 连接超时                       │
│            │         │                                          │
│            │         └── 可写 → 检查SO_ERROR                   │
│            │              │                                     │
│            │              ├── SO_ERROR == 0 → 连接成功          │
│            │              └── SO_ERROR != 0 → 连接失败          │
│            │                                                   │
│            └── 其他errno → 连接失败                            │
│                                                                │
│  3. 恢复socket为阻塞模式（如果需要）                          │
│                                                                │
└────────────────────────────────────────────────────────────────┘
*/

// 设置/取消非阻塞
bool set_nonblocking(int fd, bool nonblocking) {
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags < 0) return false;

    if (nonblocking) {
        flags |= O_NONBLOCK;
    } else {
        flags &= ~O_NONBLOCK;
    }

    return fcntl(fd, F_SETFL, flags) >= 0;
}

// connect_with_timeout: 带超时的连接
// 返回值：
//   0  连接成功
//  -1  连接失败（errno被设置）
//  -2  连接超时
int connect_with_timeout(int sockfd, const sockaddr* addr, socklen_t addrlen,
                         int timeout_sec) {
    // Step 1: 保存原始flags并设置非阻塞
    int old_flags = fcntl(sockfd, F_GETFL, 0);
    if (old_flags < 0) return -1;

    if (!set_nonblocking(sockfd, true)) return -1;

    // Step 2: 发起非阻塞connect
    int ret = connect(sockfd, addr, addrlen);

    if (ret == 0) {
        // 连接立即完成（通常是本地连接）
        fcntl(sockfd, F_SETFL, old_flags);  // 恢复flags
        return 0;
    }

    if (errno != EINPROGRESS) {
        // 真正的错误
        fcntl(sockfd, F_SETFL, old_flags);
        return -1;
    }

    // Step 3: 连接进行中，用select等待
    fd_set wset, eset;
    FD_ZERO(&wset);
    FD_ZERO(&eset);
    FD_SET(sockfd, &wset);
    FD_SET(sockfd, &eset);  // 也监控异常

    timeval tv;
    tv.tv_sec = timeout_sec;
    tv.tv_usec = 0;

    ret = select(sockfd + 1, nullptr, &wset, &eset, &tv);

    if (ret < 0) {
        // select出错
        fcntl(sockfd, F_SETFL, old_flags);
        return -1;
    }

    if (ret == 0) {
        // 超时
        fcntl(sockfd, F_SETFL, old_flags);
        errno = ETIMEDOUT;
        return -2;
    }

    // Step 4: select返回，检查连接结果
    int error = 0;
    socklen_t errlen = sizeof(error);

    if (getsockopt(sockfd, SOL_SOCKET, SO_ERROR, &error, &errlen) < 0) {
        fcntl(sockfd, F_SETFL, old_flags);
        return -1;
    }

    // Step 5: 恢复阻塞模式
    fcntl(sockfd, F_SETFL, old_flags);

    if (error != 0) {
        // 连接失败
        errno = error;
        return -1;
    }

    return 0;  // 连接成功
}

// 使用示例
void connect_example() {
    int sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd < 0) {
        perror("socket");
        return;
    }

    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(8080);
    inet_pton(AF_INET, "93.184.216.34", &addr.sin_addr);

    std::cout << "连接中（超时3秒）..." << std::endl;

    int ret = connect_with_timeout(sockfd, (sockaddr*)&addr, sizeof(addr), 3);

    switch (ret) {
        case 0:
            std::cout << "连接成功！" << std::endl;
            break;
        case -2:
            std::cout << "连接超时" << std::endl;
            break;
        default:
            std::cout << "连接失败: " << strerror(errno) << std::endl;
            break;
    }

    close(sockfd);
}

} // namespace connect_timeout

/*
自测题：

Q1: 为什么非阻塞connect返回-1时errno是EINPROGRESS而不是EAGAIN？
A1: EINPROGRESS专门用于非阻塞connect，表示"连接正在进行中"。
    EAGAIN用于read/write等操作表示"当前没有数据/缓冲区满"。
    这是两种不同的"暂时性"状态，语义不同。

Q2: 为什么connect完成后要用getsockopt(SO_ERROR)检查？
A2: select返回socket可写只说明connect过程完成了（不管成功还是失败）。
    如果连接被拒绝（对方没有监听），socket也会变为可写。
    必须用getsockopt(SO_ERROR)获取实际结果：0=成功，非0=错误码。

Q3: connect_with_timeout为什么最后要恢复阻塞模式？
A3: 因为调用者可能期望socket是阻塞的（后续的read/write以阻塞方式工作）。
    超时连接只是connect阶段的需求，不应该改变socket的长期行为。
    如果调用者需要非阻塞socket，应该自己设置。
*/
```

#### 7. 综合超时工具函数

```cpp
// ============================================================
// 综合超时工具函数集
// ============================================================

#include <iostream>
#include <sys/socket.h>
#include <sys/select.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <unistd.h>
#include <fcntl.h>
#include <cerrno>
#include <cstring>
#include <chrono>

namespace timeout_utils {

// 超时错误码
enum class TimeoutResult {
    Success,        // 操作成功
    Timeout,        // 超时
    Error,          // 系统错误
    Interrupted,    // 被信号中断
    PeerClosed      // 对端关闭
};

// 带超时的read（使用select）
std::pair<TimeoutResult, ssize_t>
read_with_timeout(int fd, void* buf, size_t len, int timeout_ms) {
    if (timeout_ms > 0) {
        fd_set rset;
        FD_ZERO(&rset);
        FD_SET(fd, &rset);

        timeval tv;
        tv.tv_sec = timeout_ms / 1000;
        tv.tv_usec = (timeout_ms % 1000) * 1000;

        int ret = select(fd + 1, &rset, nullptr, nullptr, &tv);
        if (ret < 0) {
            if (errno == EINTR) return {TimeoutResult::Interrupted, -1};
            return {TimeoutResult::Error, -1};
        }
        if (ret == 0) {
            return {TimeoutResult::Timeout, 0};
        }
    }

    ssize_t n = read(fd, buf, len);
    if (n > 0) return {TimeoutResult::Success, n};
    if (n == 0) return {TimeoutResult::PeerClosed, 0};
    if (errno == EINTR) return {TimeoutResult::Interrupted, -1};
    return {TimeoutResult::Error, -1};
}

// 带超时的readn（读取确切n字节）
std::pair<TimeoutResult, ssize_t>
readn_with_timeout(int fd, void* buf, size_t total, int timeout_ms) {
    char* ptr = static_cast<char*>(buf);
    size_t remaining = total;

    auto deadline = std::chrono::steady_clock::now()
                  + std::chrono::milliseconds(timeout_ms);

    while (remaining > 0) {
        // 计算剩余超时
        auto now = std::chrono::steady_clock::now();
        auto left = std::chrono::duration_cast<std::chrono::milliseconds>(
            deadline - now
        ).count();

        if (left <= 0) {
            return {TimeoutResult::Timeout, total - remaining};
        }

        auto [result, n] = read_with_timeout(fd, ptr, remaining, left);

        if (result == TimeoutResult::Success && n > 0) {
            ptr += n;
            remaining -= n;
        } else if (result == TimeoutResult::Interrupted) {
            continue;  // 被信号中断，重试
        } else {
            return {result, total - remaining};
        }
    }

    return {TimeoutResult::Success, total};
}

// 带超时的connect（封装版）
TimeoutResult connect_with_timeout(int sockfd, const sockaddr* addr,
                                   socklen_t addrlen, int timeout_ms) {
    // 设置非阻塞
    int flags = fcntl(sockfd, F_GETFL, 0);
    fcntl(sockfd, F_SETFL, flags | O_NONBLOCK);

    int ret = connect(sockfd, addr, addrlen);

    if (ret == 0) {
        fcntl(sockfd, F_SETFL, flags);
        return TimeoutResult::Success;
    }

    if (errno != EINPROGRESS) {
        fcntl(sockfd, F_SETFL, flags);
        return TimeoutResult::Error;
    }

    fd_set wset;
    FD_ZERO(&wset);
    FD_SET(sockfd, &wset);

    timeval tv;
    tv.tv_sec = timeout_ms / 1000;
    tv.tv_usec = (timeout_ms % 1000) * 1000;

    ret = select(sockfd + 1, nullptr, &wset, nullptr, &tv);

    // 恢复阻塞模式
    fcntl(sockfd, F_SETFL, flags);

    if (ret < 0) return TimeoutResult::Error;
    if (ret == 0) return TimeoutResult::Timeout;

    int error = 0;
    socklen_t errlen = sizeof(error);
    getsockopt(sockfd, SOL_SOCKET, SO_ERROR, &error, &errlen);

    if (error != 0) {
        errno = error;
        return TimeoutResult::Error;
    }

    return TimeoutResult::Success;
}

// 超时结果转字符串
const char* to_string(TimeoutResult r) {
    switch (r) {
        case TimeoutResult::Success:     return "Success";
        case TimeoutResult::Timeout:     return "Timeout";
        case TimeoutResult::Error:       return "Error";
        case TimeoutResult::Interrupted: return "Interrupted";
        case TimeoutResult::PeerClosed:  return "PeerClosed";
    }
    return "Unknown";
}

// 使用示例
void example_usage() {
    // 带超时连接
    int sockfd = socket(AF_INET, SOCK_STREAM, 0);

    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(80);
    inet_pton(AF_INET, "93.184.216.34", &addr.sin_addr);

    auto result = connect_with_timeout(sockfd,
        (sockaddr*)&addr, sizeof(addr), 3000);  // 3秒超时

    std::cout << "connect结果: " << to_string(result) << std::endl;

    if (result == TimeoutResult::Success) {
        // 带超时读取
        char buf[1024];
        auto [read_result, n] = read_with_timeout(sockfd, buf, sizeof(buf), 5000);
        std::cout << "read结果: " << to_string(read_result)
                  << ", bytes=" << n << std::endl;
    }

    close(sockfd);
}

} // namespace timeout_utils

/*
自测题：

Q1: readn_with_timeout中为什么需要计算"剩余超时"？
A1: 因为readn需要多次调用read来凑齐n个字节。如果总超时是5秒，
    第一次read用了2秒，那第二次read只能等3秒。
    如果不计算剩余超时，每次read都等5秒，总时间可能远超预期。

Q2: 三种超时方式各适合什么场景？
A2: - SO_RCVTIMEO: 简单场景，单个socket设置一次即可
    - alarm: 尽量避免（全局影响，精度差，多线程不安全）
    - select超时: 最灵活，适合需要精确超时或多fd场景（推荐）

Q3: connect超时时，为什么要先设非阻塞再恢复？
A3: 因为阻塞的connect不支持超时设置（除非用alarm打断）。
    非阻塞connect+select是实现connect超时的标准方法。
    操作完成后恢复阻塞模式是因为后续读写可能需要阻塞行为。
*/
```

#### 第一周检验标准

- [ ] 能画出五种I/O模型的用户空间/内核空间交互图
- [ ] 理解同步vs异步、阻塞vs非阻塞的区别
- [ ] 能解释为什么select/poll是同步阻塞的
- [ ] 理解单线程阻塞服务器的瓶颈
- [ ] 理解thread-per-connection的资源限制
- [ ] 能解释C10K问题的本质和解决思路
- [ ] 掌握SO_RCVTIMEO/SO_SNDTIMEO设置方法
- [ ] 理解alarm超时的局限性
- [ ] 掌握select作为超时机制的使用
- [ ] 能实现connect_with_timeout（非阻塞connect + select）
- [ ] 能实现带超时的read/readn封装

---

## 第二周：非阻塞I/O编程（Day 8-14）

> **本周目标**：掌握fcntl设置非阻塞模式，理解EAGAIN/EWOULDBLOCK处理，
> 实现非阻塞connect，设计应用层缓冲区，构建非阻塞服务器

### Day 8-9：fcntl与非阻塞模式

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | fcntl系统调用与O_NONBLOCK | 3h |
| 下午 | EAGAIN/EWOULDBLOCK处理与非阻塞读写 | 3h |
| 晚上 | 非阻塞模式下各系统调用行为变化 | 2h |

#### 1. fcntl系统调用详解

```cpp
// ============================================================
// fcntl系统调用与非阻塞模式
// ============================================================

/*
┌─────────────────────────────────────────────────────────────────┐
│                    fcntl 常用操作                                 │
├──────────────┬──────────────────────────────────────────────────┤
│ 命令         │ 说明                                            │
├──────────────┼──────────────────────────────────────────────────┤
│ F_GETFL      │ 获取文件状态标志（O_NONBLOCK, O_APPEND等）      │
│ F_SETFL      │ 设置文件状态标志                                │
│ F_GETFD      │ 获取文件描述符标志（FD_CLOEXEC）                │
│ F_SETFD      │ 设置文件描述符标志                              │
│ F_DUPFD      │ 复制文件描述符                                  │
│ F_GETLK      │ 获取文件锁                                     │
│ F_SETLK      │ 设置文件锁（非阻塞）                           │
│ F_SETLKW     │ 设置文件锁（阻塞等待）                         │
├──────────────┴──────────────────────────────────────────────────┤
│                                                                 │
│  注意区分：                                                     │
│  - 文件状态标志（F_GETFL/F_SETFL）：O_NONBLOCK, O_APPEND等    │
│    → 影响所有引用该文件描述的fd（fork/dup共享）                │
│  - 文件描述符标志（F_GETFD/F_SETFD）：FD_CLOEXEC              │
│    → 每个fd独立，不共享                                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
*/

#include <iostream>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <cerrno>
#include <cstring>

namespace nonblocking_basics {

// ============================================================
// 方式1: fcntl设置非阻塞（推荐）
// ============================================================

bool set_nonblocking_fcntl(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags < 0) {
        perror("fcntl F_GETFL");
        return false;
    }

    // 添加O_NONBLOCK标志（保留其他标志不变）
    if (fcntl(fd, F_SETFL, flags | O_NONBLOCK) < 0) {
        perror("fcntl F_SETFL");
        return false;
    }

    return true;
}

bool set_blocking_fcntl(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags < 0) return false;

    // 清除O_NONBLOCK标志
    if (fcntl(fd, F_SETFL, flags & ~O_NONBLOCK) < 0) return false;

    return true;
}

// ============================================================
// 方式2: ioctl设置非阻塞
// ============================================================

bool set_nonblocking_ioctl(int fd) {
    int on = 1;
    if (ioctl(fd, FIONBIO, &on) < 0) {
        perror("ioctl FIONBIO");
        return false;
    }
    return true;
}

bool set_blocking_ioctl(int fd) {
    int off = 0;
    if (ioctl(fd, FIONBIO, &off) < 0) return false;
    return true;
}

// ============================================================
// 方式3: socket创建时指定SOCK_NONBLOCK（Linux 2.6.27+）
// ============================================================

int create_nonblocking_socket() {
#ifdef SOCK_NONBLOCK
    // Linux特有：创建时就是非阻塞的
    int fd = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK, 0);
    // 还可以同时设置SOCK_CLOEXEC
    // int fd = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK | SOCK_CLOEXEC, 0);
    return fd;
#else
    // 其他平台：先创建再设置
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd >= 0) {
        set_nonblocking_fcntl(fd);
    }
    return fd;
#endif
}

/*
┌────────────────────────────────────────────────────────────────────┐
│          非阻塞模式下各系统调用行为变化                            │
├──────────────┬────────────────────┬────────────────────────────────┤
│ 系统调用     │ 阻塞模式           │ 非阻塞模式                     │
├──────────────┼────────────────────┼────────────────────────────────┤
│ read()       │ 无数据时阻塞等待   │ 返回-1, errno=EAGAIN           │
│ write()      │ 缓冲区满时阻塞     │ 返回-1, errno=EAGAIN           │
│              │                    │ 或返回部分写入的字节数         │
│ accept()     │ 无连接时阻塞等待   │ 返回-1, errno=EAGAIN           │
│ connect()    │ 阻塞直到连接完成   │ 返回-1, errno=EINPROGRESS      │
│ recv()       │ 无数据时阻塞       │ 返回-1, errno=EAGAIN           │
│ send()       │ 缓冲区满时阻塞     │ 返回-1, errno=EAGAIN           │
│              │                    │ 或返回部分发送的字节数         │
│ recvfrom()   │ 无数据时阻塞       │ 返回-1, errno=EAGAIN           │
│ sendto()     │ 缓冲区满时阻塞     │ 返回-1, errno=EAGAIN           │
├──────────────┴────────────────────┴────────────────────────────────┤
│ 注意：                                                             │
│ - Linux上 EAGAIN == EWOULDBLOCK（值都是11）                       │
│ - 其他系统可能不同，代码中应同时检查两者                          │
│ - connect的非阻塞错误码是EINPROGRESS，不是EAGAIN                  │
└────────────────────────────────────────────────────────────────────┘
*/

} // namespace nonblocking_basics
```

#### 2. 非阻塞读写——完整错误处理

```cpp
// ============================================================
// 非阻塞读写的完整错误处理
// ============================================================

#include <iostream>
#include <sys/socket.h>
#include <unistd.h>
#include <fcntl.h>
#include <cerrno>
#include <cstring>
#include <vector>

namespace nonblocking_io {

// 非阻塞read结果
enum class ReadResult {
    GotData,      // 读到了数据
    WouldBlock,   // 当前没有数据（EAGAIN）
    PeerClosed,   // 对端关闭连接
    Error         // 发生错误
};

// 非阻塞read：读取可用数据
std::pair<ReadResult, ssize_t>
nb_read(int fd, void* buf, size_t len) {
    ssize_t n = read(fd, buf, len);

    if (n > 0) {
        return {ReadResult::GotData, n};
    }

    if (n == 0) {
        return {ReadResult::PeerClosed, 0};
    }

    // n < 0
    if (errno == EAGAIN || errno == EWOULDBLOCK) {
        return {ReadResult::WouldBlock, 0};
    }

    if (errno == EINTR) {
        // 被信号中断，重试
        return nb_read(fd, buf, len);
    }

    return {ReadResult::Error, -1};
}

// 非阻塞write结果
enum class WriteResult {
    Complete,     // 全部写入
    Partial,      // 部分写入
    WouldBlock,   // 缓冲区满（EAGAIN）
    Error         // 发生错误
};

// 非阻塞write：尽可能多地写入
std::pair<WriteResult, ssize_t>
nb_write(int fd, const void* buf, size_t len) {
    ssize_t n = write(fd, buf, len);

    if (n > 0) {
        if (static_cast<size_t>(n) == len) {
            return {WriteResult::Complete, n};
        }
        return {WriteResult::Partial, n};
    }

    if (n == 0) {
        return {WriteResult::WouldBlock, 0};
    }

    // n < 0
    if (errno == EAGAIN || errno == EWOULDBLOCK) {
        return {WriteResult::WouldBlock, 0};
    }

    if (errno == EINTR) {
        return nb_write(fd, buf, len);
    }

    return {WriteResult::Error, -1};
}

// 非阻塞write_all：尝试写入所有数据
// 返回：已写入的字节数（可能小于total，需要后续继续写）
ssize_t nb_write_all(int fd, const char* data, size_t total) {
    size_t written = 0;

    while (written < total) {
        auto [result, n] = nb_write(fd, data + written, total - written);

        switch (result) {
            case WriteResult::Complete:
            case WriteResult::Partial:
                written += n;
                break;
            case WriteResult::WouldBlock:
                // 缓冲区满，返回已写入的量
                return written;
            case WriteResult::Error:
                return -1;
        }
    }

    return written;
}

} // namespace nonblocking_io

/*
自测题：

Q1: EAGAIN和EWOULDBLOCK有什么区别？
A1: 在Linux上它们是同一个错误码（都是11），可以互换使用。
    但POSIX标准允许它们不同，所以为了可移植性，
    代码中应该同时检查两者：if (errno == EAGAIN || errno == EWOULDBLOCK)。

Q2: 非阻塞write返回的字节数可能小于请求的len，这意味着什么？
A2: 意味着发送缓冲区空间不足以容纳所有数据，只写入了部分数据。
    剩余的数据需要缓存起来，等socket变为可写时继续发送。
    这就是应用层发送缓冲区的必要性。

Q3: 为什么非阻塞I/O需要应用层缓冲区？
A3: 因为write可能返回EAGAIN（缓冲区满），或只写入部分数据。
    未发送的数据必须保存在应用层缓冲区中，等待socket可写时继续发送。
    同理，read可能一次读不到完整消息，也需要应用层读缓冲区拼接。
*/
```

### Day 10-11：非阻塞connect

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | 非阻塞connect流程与EINPROGRESS处理 | 3h |
| 下午 | 并行连接多台服务器实现 | 3h |
| 晚上 | 测试与调试 | 2h |

#### 3. 并行连接多台服务器

```cpp
// ============================================================
// parallel_connect: 并行连接多台服务器
// ============================================================
// 使用非阻塞connect + select同时连接多个目标
// 应用场景：健康检查、负载均衡探测、最快连接选择

#include <iostream>
#include <vector>
#include <string>
#include <sys/socket.h>
#include <sys/select.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <unistd.h>
#include <fcntl.h>
#include <cerrno>
#include <cstring>
#include <chrono>

namespace parallel_connect {

struct ConnectTarget {
    std::string host;
    uint16_t    port;
    int         fd = -1;
    bool        connected = false;
    bool        failed = false;
    int         error_code = 0;
    int64_t     connect_time_us = 0;  // 连接耗时（微秒）
};

bool set_nonblocking(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    return fcntl(fd, F_SETFL, flags | O_NONBLOCK) >= 0;
}

// 解析地址
bool resolve_address(const std::string& host, uint16_t port, sockaddr_in& addr) {
    addrinfo hints{};
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;

    addrinfo* result = nullptr;
    std::string port_str = std::to_string(port);

    if (getaddrinfo(host.c_str(), port_str.c_str(), &hints, &result) != 0) {
        return false;
    }

    memcpy(&addr, result->ai_addr, sizeof(sockaddr_in));
    freeaddrinfo(result);
    return true;
}

// 并行连接多个目标
// 返回：首个成功连接的目标索引，-1表示全部失败
int connect_parallel(std::vector<ConnectTarget>& targets, int timeout_ms) {
    auto start_time = std::chrono::steady_clock::now();

    // Step 1: 为每个目标创建非阻塞socket并发起connect
    for (auto& t : targets) {
        t.fd = socket(AF_INET, SOCK_STREAM, 0);
        if (t.fd < 0) {
            t.failed = true;
            t.error_code = errno;
            continue;
        }

        set_nonblocking(t.fd);

        sockaddr_in addr{};
        if (!resolve_address(t.host, t.port, addr)) {
            t.failed = true;
            close(t.fd);
            t.fd = -1;
            continue;
        }

        int ret = connect(t.fd, (sockaddr*)&addr, sizeof(addr));
        if (ret == 0) {
            // 立即连接成功（本地连接）
            auto elapsed = std::chrono::steady_clock::now() - start_time;
            t.connect_time_us = std::chrono::duration_cast<
                std::chrono::microseconds>(elapsed).count();
            t.connected = true;
        } else if (errno != EINPROGRESS) {
            t.failed = true;
            t.error_code = errno;
            close(t.fd);
            t.fd = -1;
        }
        // errno == EINPROGRESS: 正常，等待select
    }

    // Step 2: 用select等待连接完成
    int first_connected = -1;

    while (true) {
        auto now = std::chrono::steady_clock::now();
        auto elapsed_ms = std::chrono::duration_cast<std::chrono::milliseconds>(
            now - start_time
        ).count();

        if (elapsed_ms >= timeout_ms) break;  // 总超时

        // 检查是否有已完成的连接
        for (size_t i = 0; i < targets.size(); ++i) {
            if (targets[i].connected && first_connected < 0) {
                first_connected = i;
            }
        }
        if (first_connected >= 0) break;

        // 构建fd_set
        fd_set wset;
        FD_ZERO(&wset);
        int max_fd = -1;
        bool has_pending = false;

        for (auto& t : targets) {
            if (t.fd >= 0 && !t.connected && !t.failed) {
                FD_SET(t.fd, &wset);
                if (t.fd > max_fd) max_fd = t.fd;
                has_pending = true;
            }
        }

        if (!has_pending) break;  // 没有待处理的连接

        int remaining_ms = timeout_ms - elapsed_ms;
        timeval tv;
        tv.tv_sec = remaining_ms / 1000;
        tv.tv_usec = (remaining_ms % 1000) * 1000;

        int ready = select(max_fd + 1, nullptr, &wset, nullptr, &tv);

        if (ready <= 0) continue;

        // 检查哪些连接完成了
        for (auto& t : targets) {
            if (t.fd >= 0 && !t.connected && !t.failed && FD_ISSET(t.fd, &wset)) {
                int error = 0;
                socklen_t errlen = sizeof(error);
                getsockopt(t.fd, SOL_SOCKET, SO_ERROR, &error, &errlen);

                auto elapsed = std::chrono::steady_clock::now() - start_time;
                t.connect_time_us = std::chrono::duration_cast<
                    std::chrono::microseconds>(elapsed).count();

                if (error == 0) {
                    t.connected = true;
                } else {
                    t.failed = true;
                    t.error_code = error;
                }
            }
        }
    }

    // 找到第一个成功的
    for (size_t i = 0; i < targets.size(); ++i) {
        if (targets[i].connected) {
            // 关闭其他fd
            for (size_t j = 0; j < targets.size(); ++j) {
                if (j != i && targets[j].fd >= 0) {
                    close(targets[j].fd);
                    targets[j].fd = -1;
                }
            }
            // 恢复为阻塞模式
            int flags = fcntl(targets[i].fd, F_GETFL, 0);
            fcntl(targets[i].fd, F_SETFL, flags & ~O_NONBLOCK);
            return i;
        }
    }

    // 全部失败，关闭所有fd
    for (auto& t : targets) {
        if (t.fd >= 0) {
            close(t.fd);
            t.fd = -1;
        }
    }

    return -1;
}

// 使用示例
void example() {
    std::vector<ConnectTarget> targets = {
        {"127.0.0.1", 8080},
        {"127.0.0.1", 8081},
        {"127.0.0.1", 8082},
    };

    std::cout << "并行连接 " << targets.size() << " 个目标..." << std::endl;

    int winner = connect_parallel(targets, 3000);

    for (size_t i = 0; i < targets.size(); ++i) {
        auto& t = targets[i];
        std::cout << "  " << t.host << ":" << t.port << " → ";
        if (t.connected) {
            std::cout << "成功 (" << t.connect_time_us << " μs)";
            if (static_cast<int>(i) == winner) std::cout << " [WINNER]";
        } else if (t.failed) {
            std::cout << "失败: " << strerror(t.error_code);
        } else {
            std::cout << "超时";
        }
        std::cout << std::endl;
    }

    if (winner >= 0) {
        std::cout << "使用连接: " << targets[winner].host
                  << ":" << targets[winner].port << std::endl;
        // 使用 targets[winner].fd 进行通信...
        close(targets[winner].fd);
    }
}

} // namespace parallel_connect

/*
自测题：

Q1: 并行连接的主要优势是什么？
A1: 可以同时发起多个连接请求，选择最先成功的那个（fastest-first策略）。
    总耗时等于最快的那个连接的时间，而非顺序连接时所有连接时间之和。
    常用于多副本服务的健康检查和负载均衡。

Q2: 为什么并行连接成功后要关闭其他fd？
A2: 已发起的connect即使不再需要也会消耗网络资源（SYN包已发出）。
    关闭fd会让内核发送RST或完成四次挥手，释放资源。
    不关闭会导致fd泄漏和对方服务器积累无用连接。
*/
```

### Day 12-14：非阻塞服务器设计

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | Buffer类与Connection状态机设计 | 3h |
| 下午 | 非阻塞echo server实现 | 3h |
| 晚上 | 测试与性能分析 | 2h |

#### 4. Buffer类——应用层缓冲区

```cpp
// ============================================================
// Buffer类：非阻塞I/O的核心数据结构
// ============================================================

/*
为什么需要应用层缓冲区？

┌─────────────────────────────────────────────────────────────┐
│               非阻塞I/O需要缓冲区的原因                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  读缓冲区（Read Buffer）：                                  │
│  ┌──────────────────────────────────────┐                  │
│  │ 应用协议消息可能跨越多次read调用     │                  │
│  │ 例如：HTTP请求头需要读到"\r\n\r\n"    │                  │
│  │ 每次read只能获取当前可用数据         │                  │
│  │ 需要缓冲区累积数据直到消息完整       │                  │
│  └──────────────────────────────────────┘                  │
│                                                             │
│  写缓冲区（Write Buffer）：                                 │
│  ┌──────────────────────────────────────┐                  │
│  │ write可能返回EAGAIN或只写入部分数据  │                  │
│  │ 未发送的数据必须保存在缓冲区中       │                  │
│  │ 当socket可写时继续发送               │                  │
│  └──────────────────────────────────────┘                  │
│                                                             │
│  缓冲区设计：                                               │
│  ┌──────────────────────────────────────┐                  │
│  │    prependable    readable   writable │                  │
│  │  ← read_idx → ← data → ← space →   │                  │
│  │  [  已读空间  | 可读数据 | 可写空间 ]│                  │
│  │  0        read_idx    write_idx    cap│                  │
│  └──────────────────────────────────────┘                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
*/

#include <vector>
#include <string>
#include <cstring>
#include <algorithm>
#include <cassert>
#include <sys/uio.h>  // readv
#include <unistd.h>

namespace nonblocking_server {

class Buffer {
public:
    static constexpr size_t kInitialSize = 1024;
    static constexpr size_t kPrependSize = 8;  // 预留空间（可用于添加长度前缀）

    explicit Buffer(size_t initial_size = kInitialSize)
        : buffer_(kPrependSize + initial_size)
        , read_index_(kPrependSize)
        , write_index_(kPrependSize)
    {}

    // 可读字节数
    size_t readable_bytes() const { return write_index_ - read_index_; }

    // 可写字节数
    size_t writable_bytes() const { return buffer_.size() - write_index_; }

    // 已读空间（可用于prepend）
    size_t prependable_bytes() const { return read_index_; }

    // 可读数据起始指针
    const char* peek() const { return begin() + read_index_; }

    // 可写位置指针
    char* begin_write() { return begin() + write_index_; }
    const char* begin_write() const { return begin() + write_index_; }

    // 消费n个字节（移动读指针）
    void retrieve(size_t n) {
        assert(n <= readable_bytes());
        if (n < readable_bytes()) {
            read_index_ += n;
        } else {
            retrieve_all();
        }
    }

    // 消费所有数据
    void retrieve_all() {
        read_index_ = kPrependSize;
        write_index_ = kPrependSize;
    }

    // 读取为string并消费
    std::string retrieve_as_string(size_t n) {
        assert(n <= readable_bytes());
        std::string result(peek(), n);
        retrieve(n);
        return result;
    }

    std::string retrieve_all_as_string() {
        return retrieve_as_string(readable_bytes());
    }

    // 追加数据
    void append(const char* data, size_t len) {
        ensure_writable(len);
        std::copy(data, data + len, begin_write());
        write_index_ += len;
    }

    void append(const std::string& str) {
        append(str.data(), str.size());
    }

    // 确保有足够的可写空间
    void ensure_writable(size_t len) {
        if (writable_bytes() < len) {
            make_space(len);
        }
        assert(writable_bytes() >= len);
    }

    // 在数据前面添加（用于添加长度前缀等）
    void prepend(const void* data, size_t len) {
        assert(len <= prependable_bytes());
        read_index_ -= len;
        memcpy(begin() + read_index_, data, len);
    }

    // 从fd读取数据（使用readv优化）
    ssize_t read_fd(int fd) {
        // 使用readv：栈上额外缓冲区 + buffer内部空间
        // 避免buffer过大造成浪费
        char extra_buf[65536];

        iovec vec[2];
        vec[0].iov_base = begin_write();
        vec[0].iov_len  = writable_bytes();
        vec[1].iov_base = extra_buf;
        vec[1].iov_len  = sizeof(extra_buf);

        // 如果buffer空间足够，只用一块
        const int iovcnt = (writable_bytes() < sizeof(extra_buf)) ? 2 : 1;

        ssize_t n = readv(fd, vec, iovcnt);

        if (n > 0) {
            if (static_cast<size_t>(n) <= writable_bytes()) {
                // 全部读入buffer
                write_index_ += n;
            } else {
                // 一部分在buffer，一部分在extra_buf
                size_t in_buffer = writable_bytes();
                write_index_ = buffer_.size();
                append(extra_buf, n - in_buffer);
            }
        }

        return n;
    }

    // 向fd写出数据
    ssize_t write_fd(int fd) {
        ssize_t n = write(fd, peek(), readable_bytes());
        if (n > 0) {
            retrieve(n);
        }
        return n;
    }

    // 查找换行符（用于行协议）
    const char* find_crlf() const {
        const char* crlf = std::search(peek(), begin_write(),
                                       "\r\n", (const char*)"\r\n" + 2);
        return crlf == begin_write() ? nullptr : crlf;
    }

    const char* find_eol() const {
        const void* eol = memchr(peek(), '\n', readable_bytes());
        return static_cast<const char*>(eol);
    }

private:
    char* begin() { return buffer_.data(); }
    const char* begin() const { return buffer_.data(); }

    void make_space(size_t len) {
        if (writable_bytes() + prependable_bytes() < len + kPrependSize) {
            // 空间不够，扩容
            buffer_.resize(write_index_ + len);
        } else {
            // 已读空间足够，整理数据到前面
            size_t readable = readable_bytes();
            std::copy(begin() + read_index_,
                      begin() + write_index_,
                      begin() + kPrependSize);
            read_index_ = kPrependSize;
            write_index_ = read_index_ + readable;
        }
    }

    std::vector<char> buffer_;
    size_t read_index_;
    size_t write_index_;
};

} // namespace nonblocking_server
```

#### 5. Connection类——连接生命周期状态机

```cpp
// ============================================================
// Connection类：非阻塞连接的状态机管理
// ============================================================

/*
┌─────────────────────────────────────────────────────────────┐
│                连接生命周期状态机                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   ┌───────────┐   accept()   ┌───────────┐                │
│   │  Pending  │ ────────────> │Connected  │                │
│   └───────────┘              └─────┬─────┘                │
│                                    │                        │
│                          ┌─────────┼─────────┐             │
│                          ▼         ▼         ▼              │
│                     ┌────────┐ ┌────────┐ ┌────────┐       │
│                     │Reading │ │Writing │ │ReadWrite│       │
│                     └───┬────┘ └───┬────┘ └───┬────┘       │
│                         │          │          │             │
│                         └──────────┼──────────┘             │
│                                    │                        │
│                                    ▼                        │
│                             ┌────────────┐                  │
│                             │Disconnecting│                 │
│                             └──────┬─────┘                  │
│                                    │ close()                │
│                                    ▼                        │
│                             ┌────────────┐                  │
│                             │  Closed    │                  │
│                             └────────────┘                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
*/

#include <functional>
#include <memory>
#include <iostream>
#include <sys/socket.h>
#include <unistd.h>
#include <cerrno>

namespace nonblocking_server {

// 前面已定义的Buffer类
// class Buffer { ... };

class Connection {
public:
    enum class State {
        Connected,
        Disconnecting,
        Closed
    };

    using MessageCallback = std::function<void(Connection&)>;
    using CloseCallback = std::function<void(Connection&)>;

    Connection(int fd) : fd_(fd), state_(State::Connected) {}

    ~Connection() {
        if (fd_ >= 0) {
            close(fd_);
        }
    }

    // 禁止拷贝
    Connection(const Connection&) = delete;
    Connection& operator=(const Connection&) = delete;

    int fd() const { return fd_; }
    State state() const { return state_; }
    bool is_connected() const { return state_ == State::Connected; }

    Buffer& input_buffer() { return input_buffer_; }
    Buffer& output_buffer() { return output_buffer_; }

    // 设置回调
    void set_message_callback(MessageCallback cb) { message_cb_ = std::move(cb); }
    void set_close_callback(CloseCallback cb) { close_cb_ = std::move(cb); }

    // 发送数据（添加到输出缓冲区）
    void send(const std::string& data) {
        if (state_ != State::Connected) return;
        output_buffer_.append(data);
    }

    void send(const char* data, size_t len) {
        if (state_ != State::Connected) return;
        output_buffer_.append(data, len);
    }

    // 处理可读事件
    void handle_read() {
        ssize_t n = input_buffer_.read_fd(fd_);

        if (n > 0) {
            if (message_cb_) {
                message_cb_(*this);
            }
        } else if (n == 0) {
            // 对端关闭
            handle_close();
        } else {
            if (errno != EAGAIN && errno != EWOULDBLOCK) {
                handle_error();
            }
        }
    }

    // 处理可写事件
    void handle_write() {
        if (output_buffer_.readable_bytes() == 0) return;

        ssize_t n = output_buffer_.write_fd(fd_);

        if (n < 0) {
            if (errno != EAGAIN && errno != EWOULDBLOCK) {
                handle_error();
            }
            return;
        }

        // 如果正在断开连接且输出缓冲区已空
        if (output_buffer_.readable_bytes() == 0 &&
            state_ == State::Disconnecting) {
            handle_close();
        }
    }

    // 关闭写端（半关闭）
    void shutdown_write() {
        if (state_ == State::Connected) {
            if (output_buffer_.readable_bytes() > 0) {
                // 还有数据要发，延迟关闭
                state_ = State::Disconnecting;
            } else {
                ::shutdown(fd_, SHUT_WR);
                state_ = State::Disconnecting;
            }
        }
    }

    // 是否有数据待发送
    bool has_pending_write() const {
        return output_buffer_.readable_bytes() > 0;
    }

private:
    void handle_close() {
        state_ = State::Closed;
        if (close_cb_) {
            close_cb_(*this);
        }
    }

    void handle_error() {
        int error = 0;
        socklen_t errlen = sizeof(error);
        getsockopt(fd_, SOL_SOCKET, SO_ERROR, &error, &errlen);
        std::cerr << "Connection error on fd " << fd_
                  << ": " << strerror(error) << std::endl;
        handle_close();
    }

    int fd_;
    State state_;
    Buffer input_buffer_;
    Buffer output_buffer_;
    MessageCallback message_cb_;
    CloseCallback close_cb_;
};

} // namespace nonblocking_server
```

#### 6. 非阻塞Echo Server（忙等版）

```cpp
// ============================================================
// 非阻塞Echo Server（忙等轮询版）
// ============================================================
// 展示纯非阻塞I/O的问题：CPU 100%占用
// 这就是为什么需要select/poll/epoll！

#include <iostream>
#include <vector>
#include <memory>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <cerrno>
#include <cstring>

namespace busy_wait_server {

// 简单的连接结构
struct ClientConn {
    int fd;
    Buffer read_buf;
    Buffer write_buf;
    bool closed = false;
};

bool set_nonblocking(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    return fcntl(fd, F_SETFL, flags | O_NONBLOCK) >= 0;
}

void run_busy_wait_server(uint16_t port) {
    int listen_fd = socket(AF_INET, SOCK_STREAM, 0);
    int opt = 1;
    setsockopt(listen_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    addr.sin_port = htons(port);

    bind(listen_fd, (sockaddr*)&addr, sizeof(addr));
    listen(listen_fd, 128);
    set_nonblocking(listen_fd);  // listen socket也设为非阻塞

    std::cout << "[非阻塞忙等服务器] 端口 " << port << std::endl;
    std::cout << "警告：CPU使用率将接近100%！" << std::endl;

    std::vector<std::unique_ptr<ClientConn>> clients;

    while (true) {
        // 1. 尝试接受新连接（非阻塞accept）
        while (true) {
            sockaddr_in client_addr{};
            socklen_t client_len = sizeof(client_addr);
            int client_fd = accept(listen_fd,
                                   (sockaddr*)&client_addr, &client_len);

            if (client_fd < 0) {
                if (errno == EAGAIN || errno == EWOULDBLOCK) {
                    break;  // 没有新连接
                }
                perror("accept");
                break;
            }

            set_nonblocking(client_fd);
            auto conn = std::make_unique<ClientConn>();
            conn->fd = client_fd;
            clients.push_back(std::move(conn));

            char ip[INET_ADDRSTRLEN];
            inet_ntop(AF_INET, &client_addr.sin_addr, ip, sizeof(ip));
            std::cout << "新连接: " << ip << ":"
                      << ntohs(client_addr.sin_port) << std::endl;
        }

        // 2. 处理每个客户端
        for (auto& conn : clients) {
            if (conn->closed) continue;

            // 尝试读取
            ssize_t n = conn->read_buf.read_fd(conn->fd);
            if (n < 0 && errno != EAGAIN && errno != EWOULDBLOCK) {
                conn->closed = true;
                close(conn->fd);
                continue;
            }
            if (n == 0) {
                conn->closed = true;
                close(conn->fd);
                continue;
            }

            // Echo: 把读缓冲区的数据移到写缓冲区
            if (conn->read_buf.readable_bytes() > 0) {
                conn->write_buf.append(conn->read_buf.peek(),
                                       conn->read_buf.readable_bytes());
                conn->read_buf.retrieve_all();
            }

            // 尝试写入
            if (conn->write_buf.readable_bytes() > 0) {
                ssize_t w = conn->write_buf.write_fd(conn->fd);
                if (w < 0 && errno != EAGAIN && errno != EWOULDBLOCK) {
                    conn->closed = true;
                    close(conn->fd);
                    continue;
                }
            }
        }

        // 3. 清理已关闭的连接
        clients.erase(
            std::remove_if(clients.begin(), clients.end(),
                [](const auto& c) { return c->closed; }),
            clients.end()
        );

        // *** 这里没有任何等待机制！***
        // 循环不断执行，即使所有fd都没有数据
        // CPU使用率接近100%
        // 这就是忙等（busy-wait）的问题

        // 如果加一个sleep可以降低CPU，但增加延迟：
        // usleep(1000);  // 1ms — 不优雅的解决方案
    }

    close(listen_fd);
}

/*
忙等服务器的问题分析：

┌─────────────────────────────────────────────────────────────┐
│  优点：                                                     │
│  - 单线程处理多个连接（不需要thread-per-connection）        │
│  - 代码逻辑简单直观                                        │
│                                                             │
│  缺点：                                                     │
│  - CPU 100% 占用（即使没有任何数据交换）                   │
│  - 加sleep降低CPU，但增加延迟和降低吞吐                    │
│  - 无法准确知道哪个fd就绪，必须全部遍历                    │
│                                                             │
│  解决方案 → select/poll/epoll：                             │
│  - 阻塞等待直到有fd就绪                                    │
│  - 不占用CPU（线程处于Sleeping状态）                       │
│  - select/poll返回后精确知道哪些fd就绪                     │
│  - 这就是I/O多路复用的核心价值！                           │
└─────────────────────────────────────────────────────────────┘
*/

} // namespace busy_wait_server

/*
自测题：

Q1: 为什么忙等服务器的CPU使用率接近100%？
A1: 因为主循环不断地对所有fd调用非阻塞read/write，即使没有数据。
    每次read返回EAGAIN不消耗太多CPU，但循环速度极快（微秒级），
    每秒可能执行数百万次无用的系统调用，导致CPU空转。

Q2: 在忙等循环中加usleep(1000)为什么不是好的解决方案？
A2: 虽然降低了CPU使用率，但：
    1. 如果数据在sleep期间到达，要等sleep结束才能处理 → 增加延迟
    2. sleep时间太长 → 延迟大；太短 → CPU仍然高
    3. 无法找到延迟和CPU之间的最优平衡
    select/poll则能在数据到达的瞬间立即返回，既不浪费CPU也不增加延迟。

Q3: 这个忙等服务器相比thread-per-connection有什么优势？
A3: 单线程管理所有连接，不需要创建大量线程，没有栈内存开销和上下文切换。
    但CPU浪费的问题使它在实际中不可用。加上select/poll后就变成了
    高效的单线程多连接服务器。
*/
```

#### 第二周检验标准

- [ ] 掌握fcntl设置非阻塞模式（F_GETFL/F_SETFL/O_NONBLOCK）
- [ ] 了解ioctl(FIONBIO)和SOCK_NONBLOCK替代方式
- [ ] 理解EAGAIN/EWOULDBLOCK的含义和处理方式
- [ ] 掌握非阻塞模式下各系统调用的行为变化
- [ ] 能实现非阻塞read/write的完整错误处理
- [ ] 掌握非阻塞connect流程（EINPROGRESS + select）
- [ ] 能实现并行连接多台服务器
- [ ] 理解应用层缓冲区的必要性
- [ ] 能实现Buffer类（读写指针、自动扩容、readv优化）
- [ ] 能实现Connection类（状态机、读写缓冲区管理）
- [ ] 能编写非阻塞echo server（忙等版）
- [ ] 理解忙等轮询的CPU浪费问题

---

## 第三周：select系统调用（Day 15-21）

> **本周目标**：深入理解select的内部机制和API细节，能使用select编写多客户端服务器，
> 掌握pselect的信号安全特性，理解select的性能局限

### Day 15-16：select API深入

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | fd_set内部结构与FD_SETSIZE限制 | 3h |
| 下午 | select参数详解与Socket可读/可写条件 | 3h |
| 晚上 | select echo server完整实现 | 2h |

#### 1. fd_set内部机制与select原理

```cpp
// ============================================================
// fd_set 内部机制与select工作原理
// ============================================================

/*
┌─────────────────────────────────────────────────────────────────┐
│                    fd_set 内部结构                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  fd_set本质是一个位图（bitmap）:                                │
│                                                                 │
│  typedef struct {                                               │
│      long fds_bits[FD_SETSIZE / (8 * sizeof(long))];           │
│  } fd_set;                                                      │
│                                                                 │
│  FD_SETSIZE = 1024（默认，编译时确定，不可运行时更改）         │
│                                                                 │
│  位图示意（以FD_SETSIZE=16为例）：                              │
│  ┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
│  │ 0 │ 1 │ 0 │ 1 │ 0 │ 0 │ 1 │ 0 │ 0 │ 0 │ 0 │ 0 │ 0 │ 0 │ 0 │ 0 │
│  └───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘
│  fd: 0   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15
│  → 监控 fd=1, fd=3, fd=6                                        │
│                                                                 │
│  宏操作：                                                       │
│  FD_ZERO(&set)     → 清零所有位                                 │
│  FD_SET(fd, &set)  → 将第fd位设为1                              │
│  FD_CLR(fd, &set)  → 将第fd位设为0                              │
│  FD_ISSET(fd, &set)→ 检查第fd位是否为1                          │
│                                                                 │
│  select工作流程：                                               │
│  ┌──────────┐     ┌──────────────┐     ┌──────────┐           │
│  │ 用户空间 │     │    内核      │     │ 用户空间 │           │
│  │ fd_set   │──>  │ 拷贝fd_set  │  >──│ 修改后的 │           │
│  │ (输入)   │     │ 遍历每个fd  │     │ fd_set   │           │
│  │          │     │ 检查是否就绪│     │ (输出)   │           │
│  └──────────┘     └──────────────┘     └──────────┘           │
│                                                                 │
│  性能问题：                                                     │
│  1. 每次调用select都要拷贝fd_set到内核（O(n)）                 │
│  2. 内核遍历所有fd检查状态（O(n)）                              │
│  3. select返回后用户遍历fd_set检查结果（O(n)）                 │
│  4. FD_SETSIZE=1024固定限制                                     │
│  5. select修改fd_set，下次调用前必须重新设置                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
*/

#include <iostream>
#include <sys/select.h>

namespace select_internals {

void show_fd_set_info() {
    std::cout << "=== fd_set 信息 ===" << std::endl;
    std::cout << "FD_SETSIZE: " << FD_SETSIZE << std::endl;
    std::cout << "sizeof(fd_set): " << sizeof(fd_set) << " bytes" << std::endl;
    std::cout << "fd_set位数: " << sizeof(fd_set) * 8 << std::endl;
    std::cout << std::endl;
}

/*
┌────────────────────────────────────────────────────────────────────┐
│               Socket 可读/可写条件                                  │
├──────────────┬─────────────────────────────────────────────────────┤
│ 可读条件     │ 说明                                                │
├──────────────┼─────────────────────────────────────────────────────┤
│ 数据可读     │ 接收缓冲区中有数据（≥ SO_RCVLOWAT字节，默认1）    │
│ 读半关闭     │ 对端关闭了写方向（收到FIN），read返回0              │
│ 监听socket   │ 已完成连接队列非空（可以accept）                    │
│ socket错误   │ 有错误待处理（read返回-1）                          │
│ 带外数据     │ 收到TCP带外数据（MSG_OOB）                         │
├──────────────┼─────────────────────────────────────────────────────┤
│ 可写条件     │ 说明                                                │
├──────────────┼─────────────────────────────────────────────────────┤
│ 缓冲区可写   │ 发送缓冲区有空间（≥ SO_SNDLOWAT字节，默认2048）   │
│ 写半关闭     │ 本端已关闭写（写会产生SIGPIPE）                    │
│ connect完成  │ 非阻塞connect完成（成功或失败）                    │
│ socket错误   │ 有错误待处理（write返回-1）                        │
├──────────────┴─────────────────────────────────────────────────────┤
│ 异常条件                                                           │
├────────────────────────────────────────────────────────────────────┤
│ 带外数据到达（TCP URG标志）                                       │
└────────────────────────────────────────────────────────────────────┘
*/

} // namespace select_internals
```

#### 2. select Echo Server 完整实现

```cpp
// ============================================================
// select Echo Server —— 完整实现
// ============================================================

#include <iostream>
#include <sys/select.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <cerrno>
#include <cstring>
#include <vector>
#include <algorithm>

namespace select_echo {

struct ClientInfo {
    int fd;
    char ip[INET_ADDRSTRLEN];
    uint16_t port;
};

void run_select_echo_server(uint16_t port) {
    // 1. 创建监听socket
    int listen_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (listen_fd < 0) {
        perror("socket");
        return;
    }

    int opt = 1;
    setsockopt(listen_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    addr.sin_port = htons(port);

    if (bind(listen_fd, (sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("bind");
        close(listen_fd);
        return;
    }

    if (listen(listen_fd, 128) < 0) {
        perror("listen");
        close(listen_fd);
        return;
    }

    std::cout << "[Select Echo Server] 监听端口 " << port << std::endl;

    // 2. 初始化fd_set
    fd_set master_read_set;   // 主集合（持久保存）
    fd_set working_read_set;  // 工作集合（传给select）
    FD_ZERO(&master_read_set);
    FD_SET(listen_fd, &master_read_set);

    int max_fd = listen_fd;
    std::vector<ClientInfo> clients;

    // 3. 主循环
    while (true) {
        // select会修改fd_set，所以每次都用副本
        working_read_set = master_read_set;

        // 超时设置（可选）
        timeval timeout;
        timeout.tv_sec = 30;
        timeout.tv_usec = 0;

        int ready = select(max_fd + 1, &working_read_set,
                          nullptr, nullptr, &timeout);

        if (ready < 0) {
            if (errno == EINTR) continue;  // 被信号中断
            perror("select");
            break;
        }

        if (ready == 0) {
            std::cout << "30秒无活动..." << std::endl;
            continue;
        }

        // 4. 检查监听socket
        if (FD_ISSET(listen_fd, &working_read_set)) {
            sockaddr_in client_addr{};
            socklen_t client_len = sizeof(client_addr);
            int client_fd = accept(listen_fd,
                                   (sockaddr*)&client_addr, &client_len);

            if (client_fd >= 0) {
                if (client_fd >= FD_SETSIZE) {
                    // 超过FD_SETSIZE限制！
                    std::cerr << "fd " << client_fd
                              << " >= FD_SETSIZE(" << FD_SETSIZE
                              << ")，拒绝连接" << std::endl;
                    close(client_fd);
                } else {
                    FD_SET(client_fd, &master_read_set);
                    if (client_fd > max_fd) {
                        max_fd = client_fd;
                    }

                    ClientInfo info;
                    info.fd = client_fd;
                    inet_ntop(AF_INET, &client_addr.sin_addr,
                              info.ip, sizeof(info.ip));
                    info.port = ntohs(client_addr.sin_port);
                    clients.push_back(info);

                    std::cout << "新连接: " << info.ip << ":"
                              << info.port << " (fd=" << client_fd
                              << ", 当前连接数: " << clients.size()
                              << ")" << std::endl;
                }
            }
            --ready;
        }

        // 5. 检查客户端socket
        for (auto it = clients.begin(); it != clients.end() && ready > 0; ) {
            int fd = it->fd;

            if (FD_ISSET(fd, &working_read_set)) {
                --ready;

                char buf[4096];
                ssize_t n = read(fd, buf, sizeof(buf));

                if (n > 0) {
                    // Echo回去
                    ssize_t written = 0;
                    while (written < n) {
                        ssize_t w = write(fd, buf + written, n - written);
                        if (w <= 0) break;
                        written += w;
                    }
                    ++it;
                } else {
                    // 连接关闭或错误
                    if (n == 0) {
                        std::cout << "客户端断开: " << it->ip << ":"
                                  << it->port << std::endl;
                    } else {
                        std::cerr << "读取错误 fd=" << fd << ": "
                                  << strerror(errno) << std::endl;
                    }

                    close(fd);
                    FD_CLR(fd, &master_read_set);

                    // 更新max_fd
                    if (fd == max_fd) {
                        while (max_fd > listen_fd &&
                               !FD_ISSET(max_fd, &master_read_set)) {
                            --max_fd;
                        }
                    }

                    it = clients.erase(it);
                    std::cout << "当前连接数: " << clients.size() << std::endl;
                }
            } else {
                ++it;
            }
        }
    }

    // 清理
    for (auto& c : clients) {
        close(c.fd);
    }
    close(listen_fd);
}

} // namespace select_echo

/*
自测题：

Q1: 为什么select需要传入max_fd+1而不是max_fd？
A1: select的第一个参数nfds是"文件描述符数量"，表示要检查fd 0到nfds-1。
    如果max_fd=5，则nfds=6，表示检查fd 0,1,2,3,4,5。
    这是因为fd是从0开始的，所以数量=最大值+1。

Q2: 为什么需要master_set和working_set两个fd_set？
A2: select会修改传入的fd_set——只保留就绪的fd，清除未就绪的fd。
    如果直接传master_set，下次循环时那些未就绪的fd就丢失了。
    所以每次循环都从master_set复制到working_set。

Q3: 如果client_fd >= FD_SETSIZE会怎样？
A3: FD_SET/FD_ISSET等宏不会检查边界，直接操作会导致内存越界（buffer overflow）。
    这是select的一个安全问题——必须在应用层检查fd < FD_SETSIZE。
    这也是select的主要局限之一。

Q4: 为什么关闭连接后需要更新max_fd？
A4: select遍历0到max_fd的所有fd。如果max_fd对应的连接关闭了但不更新，
    select会多检查不必要的fd范围，浪费性能。
    虽然对正确性没影响（因为已从fd_set中清除），但影响效率。
*/
```

### Day 17-18：select高级应用

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | 读写同时监控与pselect信号安全 | 3h |
| 下午 | select聊天服务器实现 | 3h |
| 晚上 | select TCP中继实现 | 2h |

#### 3. pselect与信号安全

```cpp
// ============================================================
// pselect: 信号安全的select
// ============================================================

/*
select的信号竞争问题：

┌──────────────────────────────────────────────────────────────┐
│  问题场景（SIGCHLD示例）：                                    │
│                                                              │
│  // 信号处理函数设置标志
│  volatile sig_atomic_t got_sigchld = 0;                      │
│  void sigchld_handler(int) { got_sigchld = 1; }             │
│                                                              │
│  // 主循环                                                   │
│  while (true) {                                              │
│      if (got_sigchld) {       // (1) 检查标志               │
│          got_sigchld = 0;                                    │
│          wait_children();                                    │
│      }                                                       │
│      // *** 信号可能在这里到达！***                          │
│      // 如果信号在(1)之后、(2)之前到达，                     │
│      // select会阻塞，信号被错过！                           │
│      select(...);             // (2) 阻塞等待               │
│  }                                                           │
│                                                              │
│  解决方案：pselect原子地设置信号掩码+等待                    │
│                                                              │
│  pselect相当于原子执行：                                     │
│      sigprocmask(SIG_SETMASK, &new_mask, &old_mask);        │
│      select(nfds, ...);                                      │
│      sigprocmask(SIG_SETMASK, &old_mask, NULL);             │
└──────────────────────────────────────────────────────────────┘
*/

#include <iostream>
#include <sys/select.h>
#include <signal.h>
#include <unistd.h>
#include <cerrno>

namespace pselect_demo {

volatile sig_atomic_t got_signal = 0;

void signal_handler(int signo) {
    got_signal = signo;
}

void safe_select_loop(int listen_fd) {
    // 1. 注册信号处理
    struct sigaction sa{};
    sa.sa_handler = signal_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    sigaction(SIGCHLD, &sa, nullptr);

    // 2. 阻塞SIGCHLD（主循环中不响应）
    sigset_t block_mask, empty_mask;
    sigemptyset(&empty_mask);
    sigemptyset(&block_mask);
    sigaddset(&block_mask, SIGCHLD);
    sigprocmask(SIG_BLOCK, &block_mask, nullptr);

    while (true) {
        // 处理已收到的信号
        if (got_signal) {
            got_signal = 0;
            // 处理SIGCHLD...
            std::cout << "处理SIGCHLD" << std::endl;
        }

        fd_set rset;
        FD_ZERO(&rset);
        FD_SET(listen_fd, &rset);

        timespec timeout;
        timeout.tv_sec = 5;
        timeout.tv_nsec = 0;

        // pselect原子地：
        // 1. 设置信号掩码为empty_mask（解除SIGCHLD阻塞）
        // 2. 执行select等待
        // 3. 如果SIGCHLD到达，pselect被中断返回EINTR
        // 4. 恢复之前的信号掩码
        int ready = pselect(listen_fd + 1, &rset, nullptr, nullptr,
                           &timeout, &empty_mask);

        if (ready < 0) {
            if (errno == EINTR) {
                // 被信号中断，回到循环顶部处理
                continue;
            }
            perror("pselect");
            break;
        }

        if (ready > 0) {
            // 处理就绪的fd...
        }
    }
}

/*
select vs pselect对比：

┌────────────────────────────────────────────────────────────────┐
│                  select vs pselect                              │
├──────────────┬──────────────────┬──────────────────────────────┤
│ 特性         │ select           │ pselect                      │
├──────────────┼──────────────────┼──────────────────────────────┤
│ 超时类型     │ timeval (秒+微秒)│ timespec (秒+纳秒)           │
│ 超时精度     │ 微秒             │ 纳秒                         │
│ 超时修改     │ Linux下会修改    │ 不修改                       │
│ 信号掩码     │ 不支持           │ 原子设置信号掩码             │
│ 信号安全     │ 有竞争条件       │ 无竞争条件                   │
│ 标准         │ POSIX, Windows   │ POSIX only                   │
└──────────────┴──────────────────┴──────────────────────────────┘
*/

} // namespace pselect_demo
```

#### 4. select聊天服务器

```cpp
// ============================================================
// select聊天服务器（多客户端消息广播）
// ============================================================

#include <iostream>
#include <string>
#include <vector>
#include <sstream>
#include <sys/select.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <cerrno>
#include <cstring>

namespace select_chat {

struct ChatClient {
    int fd;
    std::string name;
    std::string ip;
    uint16_t port;
    std::string recv_buffer;  // 接收缓冲区（用于处理不完整行）
};

class ChatServer {
public:
    void run(uint16_t port) {
        listen_fd_ = socket(AF_INET, SOCK_STREAM, 0);
        int opt = 1;
        setsockopt(listen_fd_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = htonl(INADDR_ANY);
        addr.sin_port = htons(port);

        bind(listen_fd_, (sockaddr*)&addr, sizeof(addr));
        listen(listen_fd_, 64);

        FD_ZERO(&master_set_);
        FD_SET(listen_fd_, &master_set_);
        max_fd_ = listen_fd_;

        std::cout << "[ChatServer] 启动在端口 " << port << std::endl;

        while (true) {
            fd_set read_set = master_set_;

            int ready = select(max_fd_ + 1, &read_set, nullptr, nullptr, nullptr);
            if (ready < 0) {
                if (errno == EINTR) continue;
                break;
            }

            if (FD_ISSET(listen_fd_, &read_set)) {
                handle_new_connection();
            }

            for (auto it = clients_.begin(); it != clients_.end(); ) {
                if (it->fd != listen_fd_ && FD_ISSET(it->fd, &read_set)) {
                    if (!handle_client_data(*it)) {
                        // 客户端断开
                        broadcast("[系统] " + it->name + " 离开了聊天室\n", it->fd);
                        std::cout << it->name << " 断开连接" << std::endl;

                        close(it->fd);
                        FD_CLR(it->fd, &master_set_);
                        update_max_fd();
                        it = clients_.erase(it);
                        continue;
                    }
                }
                ++it;
            }
        }

        cleanup();
    }

private:
    void handle_new_connection() {
        sockaddr_in client_addr{};
        socklen_t client_len = sizeof(client_addr);
        int client_fd = accept(listen_fd_, (sockaddr*)&client_addr, &client_len);

        if (client_fd < 0) return;

        if (client_fd >= FD_SETSIZE) {
            close(client_fd);
            return;
        }

        ChatClient client;
        client.fd = client_fd;
        char ip[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &client_addr.sin_addr, ip, sizeof(ip));
        client.ip = ip;
        client.port = ntohs(client_addr.sin_port);
        client.name = "User_" + std::to_string(client_fd);

        FD_SET(client_fd, &master_set_);
        if (client_fd > max_fd_) max_fd_ = client_fd;

        // 欢迎消息
        std::string welcome = "欢迎来到聊天室! 你是 " + client.name +
                              "\n输入消息按回车发送\n";
        write(client_fd, welcome.c_str(), welcome.size());

        broadcast("[系统] " + client.name + " 加入了聊天室\n", client_fd);

        clients_.push_back(std::move(client));
        std::cout << "新客户端: " << client.name
                  << " (在线: " << clients_.size() << ")" << std::endl;
    }

    bool handle_client_data(ChatClient& client) {
        char buf[1024];
        ssize_t n = read(client.fd, buf, sizeof(buf));

        if (n <= 0) return false;

        // 累积到接收缓冲区
        client.recv_buffer.append(buf, n);

        // 按行处理（以\n分隔）
        size_t pos;
        while ((pos = client.recv_buffer.find('\n')) != std::string::npos) {
            std::string line = client.recv_buffer.substr(0, pos);
            client.recv_buffer.erase(0, pos + 1);

            // 去除\r
            if (!line.empty() && line.back() == '\r') {
                line.pop_back();
            }

            if (line.empty()) continue;

            // 处理命令
            if (line[0] == '/') {
                handle_command(client, line);
            } else {
                // 广播消息
                std::string msg = "[" + client.name + "] " + line + "\n";
                broadcast(msg, client.fd);
            }
        }

        return true;
    }

    void handle_command(ChatClient& client, const std::string& cmd) {
        if (cmd.substr(0, 5) == "/name") {
            if (cmd.size() > 6) {
                std::string old_name = client.name;
                client.name = cmd.substr(6);
                broadcast("[系统] " + old_name + " 改名为 " +
                          client.name + "\n", -1);
            }
        } else if (cmd == "/list") {
            std::string list = "在线用户 (" +
                std::to_string(clients_.size()) + "):\n";
            for (auto& c : clients_) {
                list += "  " + c.name + " (" + c.ip + ":" +
                        std::to_string(c.port) + ")\n";
            }
            write(client.fd, list.c_str(), list.size());
        } else if (cmd == "/help") {
            std::string help = "命令列表:\n"
                "/name <新名字> - 修改昵称\n"
                "/list          - 查看在线用户\n"
                "/help          - 显示此帮助\n"
                "/quit          - 退出\n";
            write(client.fd, help.c_str(), help.size());
        }
    }

    // 广播消息给所有客户端（除了exclude_fd）
    void broadcast(const std::string& msg, int exclude_fd) {
        for (auto& c : clients_) {
            if (c.fd != exclude_fd) {
                // 简单写入（实际应用应处理部分写入）
                write(c.fd, msg.c_str(), msg.size());
            }
        }
    }

    void update_max_fd() {
        max_fd_ = listen_fd_;
        for (auto& c : clients_) {
            if (c.fd > max_fd_) max_fd_ = c.fd;
        }
    }

    void cleanup() {
        for (auto& c : clients_) {
            close(c.fd);
        }
        close(listen_fd_);
    }

    int listen_fd_ = -1;
    int max_fd_ = -1;
    fd_set master_set_;
    std::vector<ChatClient> clients_;
};

} // namespace select_chat

/*
自测题：

Q1: 聊天服务器中为什么需要recv_buffer？
A1: TCP是流式协议，一次read可能读到半行或多行数据。
    recv_buffer用于累积数据，按\n分隔处理完整的消息行。
    没有这个缓冲区，可能处理不完整的消息。

Q2: broadcast中对每个fd调用write有什么潜在问题？
A2: 如果某个client的发送缓冲区满了，write可能阻塞（因为是阻塞socket）。
    这会导致整个服务器停顿，影响其他客户端。
    改进方案：使用非阻塞socket + 写缓冲区 + 监控可写事件。
*/
```

### Day 19-21：select的局限与性能分析

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | select性能分析与FD_SETSIZE问题 | 3h |
| 下午 | select性能测试程序 | 3h |
| 晚上 | 基于select的简易HTTP服务器 | 3h |

#### 5. select性能分析

```cpp
// ============================================================
// select性能分析与局限性
// ============================================================

/*
┌─────────────────────────────────────────────────────────────────┐
│              select 性能问题详细分析                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  问题1: O(n) 复杂度                                            │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ 每次调用select：                                          │ │
│  │ 1. 用户空间→内核：拷贝fd_set（128字节=1024位）           │ │
│  │ 2. 内核遍历0到nfds-1的每个fd                             │ │
│  │ 3. 对每个fd调用该fd的poll方法检查状态                    │ │
│  │ 4. 修改fd_set只保留就绪的fd                              │ │
│  │ 5. 内核→用户空间：拷贝修改后的fd_set                     │ │
│  │ 6. 用户遍历fd_set检查哪些fd就绪                          │ │
│  │                                                           │ │
│  │ 即使只有1个fd就绪，也要遍历所有n个fd                     │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  问题2: FD_SETSIZE 限制                                        │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ - FD_SETSIZE默认1024（编译时宏定义）                      │ │
│  │ - fd值必须 < FD_SETSIZE，否则内存越界                     │ │
│  │ - 修改FD_SETSIZE需要重新编译所有依赖库                    │ │
│  │ - 即使修改了，性能也会因O(n)而下降                       │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  问题3: fd_set每次需要重置                                     │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ select修改传入的fd_set                                    │ │
│  │ 每次调用前必须从master_set复制                            │ │
│  │ 对于大的fd_set，拷贝开销不可忽略                          │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  性能对比（示意）：                                             │
│  ┌──────────┬──────────┬──────────┬──────────┐                 │
│  │ 连接数   │ select   │ poll     │ epoll    │                 │
│  ├──────────┼──────────┼──────────┼──────────┤                 │
│  │ 10       │ 快       │ 快       │ 快       │                 │
│  │ 100      │ 较快     │ 较快     │ 快       │                 │
│  │ 1000     │ 慢       │ 较慢     │ 快       │                 │
│  │ 10000    │ 不可用   │ 很慢     │ 快       │                 │
│  └──────────┴──────────┴──────────┴──────────┘                 │
│                                                                 │
│  select适合的场景：                                             │
│  - 连接数少（< 几百）                                          │
│  - 需要跨平台（Windows也支持select）                           │
│  - 简单的超时等待                                               │
│  - 作为可移植的定时器                                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
*/

#include <iostream>
#include <chrono>
#include <vector>
#include <sys/select.h>
#include <sys/socket.h>
#include <unistd.h>

namespace select_benchmark {

// 测试select在不同fd数量下的调用延迟
void benchmark_select_overhead() {
    std::cout << "=== select 开销测试 ===" << std::endl;

    // 创建大量socketpair
    std::vector<int> fds;
    const int max_pairs = 500;  // 最多500对（1000个fd）

    for (int i = 0; i < max_pairs; ++i) {
        int sv[2];
        if (socketpair(AF_UNIX, SOCK_STREAM, 0, sv) < 0) {
            break;
        }
        fds.push_back(sv[0]);
        fds.push_back(sv[1]);
    }

    std::cout << "创建了 " << fds.size() << " 个fd" << std::endl;

    // 测试不同规模下的select延迟
    int test_sizes[] = {10, 50, 100, 200, 500, 1000};

    for (int size : test_sizes) {
        if (size > static_cast<int>(fds.size())) break;

        // 向第一个fd写入数据（确保有一个就绪）
        write(fds[1], "x", 1);

        fd_set rset;
        FD_ZERO(&rset);
        int max_fd = 0;

        for (int i = 0; i < size && i < static_cast<int>(fds.size()); i += 2) {
            FD_SET(fds[i], &rset);
            if (fds[i] > max_fd) max_fd = fds[i];
        }

        // 计时
        const int iterations = 10000;
        auto start = std::chrono::steady_clock::now();

        for (int i = 0; i < iterations; ++i) {
            fd_set tmp = rset;
            timeval tv{0, 0};  // 立即返回
            select(max_fd + 1, &tmp, nullptr, nullptr, &tv);
        }

        auto end = std::chrono::steady_clock::now();
        auto us = std::chrono::duration_cast<std::chrono::microseconds>(
            end - start
        ).count();

        std::cout << "  fd数=" << (size / 2) << "\t"
                  << iterations << "次平均: "
                  << (us / iterations) << " us/次" << std::endl;

        // 读取之前写入的数据
        char buf[1];
        read(fds[0], buf, 1);
    }

    // 清理
    for (int fd : fds) {
        close(fd);
    }
}

} // namespace select_benchmark
```

#### 6. 基于select的简易HTTP服务器

```cpp
// ============================================================
// 基于select的简易HTTP服务器
// ============================================================
// 支持静态响应，演示select处理HTTP请求

#include <iostream>
#include <string>
#include <sstream>
#include <vector>
#include <sys/select.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <cerrno>
#include <cstring>
#include <ctime>

namespace select_http {

struct HttpConnection {
    int fd;
    std::string request_buf;  // 请求累积缓冲区
    std::string response_buf; // 响应待发送缓冲区
    bool headers_complete = false;
    bool response_ready = false;
    bool keep_alive = false;
};

class SimpleHttpServer {
public:
    void run(uint16_t port) {
        int listen_fd = socket(AF_INET, SOCK_STREAM, 0);
        int opt = 1;
        setsockopt(listen_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = htonl(INADDR_ANY);
        addr.sin_port = htons(port);
        bind(listen_fd, (sockaddr*)&addr, sizeof(addr));
        listen(listen_fd, 128);

        std::cout << "[HTTP Server] http://localhost:" << port << std::endl;

        fd_set read_master, write_master;
        FD_ZERO(&read_master);
        FD_ZERO(&write_master);
        FD_SET(listen_fd, &read_master);
        int max_fd = listen_fd;

        std::vector<HttpConnection> conns;

        while (true) {
            fd_set rset = read_master;
            fd_set wset = write_master;

            int ready = select(max_fd + 1, &rset, &wset, nullptr, nullptr);
            if (ready < 0) {
                if (errno == EINTR) continue;
                break;
            }

            // 新连接
            if (FD_ISSET(listen_fd, &rset)) {
                int client_fd = accept(listen_fd, nullptr, nullptr);
                if (client_fd >= 0 && client_fd < FD_SETSIZE) {
                    FD_SET(client_fd, &read_master);
                    if (client_fd > max_fd) max_fd = client_fd;
                    conns.push_back({client_fd});
                } else if (client_fd >= 0) {
                    close(client_fd);
                }
            }

            // 处理读事件
            for (auto& conn : conns) {
                if (FD_ISSET(conn.fd, &rset)) {
                    char buf[4096];
                    ssize_t n = read(conn.fd, buf, sizeof(buf));
                    if (n <= 0) {
                        conn.fd = -1;  // 标记删除
                        continue;
                    }
                    conn.request_buf.append(buf, n);

                    // 检查HTTP头是否完整（以\r\n\r\n结尾）
                    if (!conn.headers_complete &&
                        conn.request_buf.find("\r\n\r\n") != std::string::npos) {
                        conn.headers_complete = true;
                        process_request(conn);

                        // 有响应需要发送，监控可写
                        FD_CLR(conn.fd, &read_master);
                        FD_SET(conn.fd, &write_master);
                    }
                }
            }

            // 处理写事件
            for (auto& conn : conns) {
                if (conn.fd >= 0 && FD_ISSET(conn.fd, &wset)) {
                    if (!conn.response_buf.empty()) {
                        ssize_t n = write(conn.fd, conn.response_buf.c_str(),
                                         conn.response_buf.size());
                        if (n > 0) {
                            conn.response_buf.erase(0, n);
                        }
                        if (conn.response_buf.empty()) {
                            // 响应发送完毕
                            FD_CLR(conn.fd, &write_master);
                            if (conn.keep_alive) {
                                // 重置状态，继续监听
                                conn.request_buf.clear();
                                conn.headers_complete = false;
                                conn.response_ready = false;
                                FD_SET(conn.fd, &read_master);
                            } else {
                                conn.fd = -1;  // 标记关闭
                            }
                        }
                    }
                }
            }

            // 清理关闭的连接
            for (auto it = conns.begin(); it != conns.end(); ) {
                if (it->fd < 0) {
                    int fd = it->fd;
                    // fd可能已经是-1，需要正确关闭
                    it = conns.erase(it);
                } else {
                    ++it;
                }
            }
        }

        close(listen_fd);
    }

private:
    void process_request(HttpConnection& conn) {
        // 解析请求行
        std::string method, path, version;
        std::istringstream iss(conn.request_buf);
        iss >> method >> path >> version;

        // 生成时间字符串
        time_t now = time(nullptr);
        char time_buf[64];
        strftime(time_buf, sizeof(time_buf), "%Y-%m-%d %H:%M:%S", localtime(&now));

        // 构造HTML响应体
        std::string body =
            "<!DOCTYPE html><html><head>"
            "<title>Select HTTP Server</title></head><body>"
            "<h1>Hello from Select HTTP Server!</h1>"
            "<p>Method: " + method + "</p>"
            "<p>Path: " + path + "</p>"
            "<p>Time: " + std::string(time_buf) + "</p>"
            "<p>This server uses select() for I/O multiplexing.</p>"
            "</body></html>";

        // 构造HTTP响应
        std::ostringstream response;
        response << "HTTP/1.1 200 OK\r\n"
                 << "Content-Type: text/html\r\n"
                 << "Content-Length: " << body.size() << "\r\n"
                 << "Connection: close\r\n"
                 << "\r\n"
                 << body;

        conn.response_buf = response.str();
        conn.response_ready = true;
        conn.keep_alive = false;
    }
};

} // namespace select_http
```

#### 第三周检验标准

- [ ] 理解fd_set内部是位图结构
- [ ] 理解FD_SETSIZE限制（默认1024）及其安全隐患
- [ ] 掌握FD_ZERO/FD_SET/FD_CLR/FD_ISSET的使用
- [ ] 掌握select参数含义（nfds, readfds, writefds, exceptfds, timeout）
- [ ] 理解Socket可读/可写条件
- [ ] 能编写完整的select echo server
- [ ] 掌握pselect的信号安全特性
- [ ] 能实现select聊天服务器（消息广播）
- [ ] 理解select的O(n)性能问题
- [ ] 理解select每次需重置fd_set的开销
- [ ] 能编写select性能基准测试
- [ ] 能用select实现简易HTTP服务器

---

## 第四周：poll系统调用与事件循环框架（Day 22-28）

> **本周目标**：掌握poll的API和优势，实现poll服务器，设计和实现统一事件循环框架，
> 集成定时器和信号处理，完成性能对比测试

### Day 22-23：poll API深入

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | pollfd结构体与事件标志 | 3h |
| 下午 | poll echo server完整实现 | 3h |
| 晚上 | poll vs select对比分析 | 2h |

#### 1. pollfd结构与事件标志

```cpp
// ============================================================
// poll API 详解
// ============================================================

/*
┌─────────────────────────────────────────────────────────────────┐
│                    poll API 核心                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  #include <poll.h>                                              │
│                                                                 │
│  int poll(struct pollfd* fds, nfds_t nfds, int timeout);       │
│                                                                 │
│  struct pollfd {                                                │
│      int   fd;       // 文件描述符                              │
│      short events;   // 请求监控的事件（输入）                  │
│      short revents;  // 实际发生的事件（输出）                  │
│  };                                                             │
│                                                                 │
│  参数：                                                         │
│  - fds:     pollfd数组指针                                      │
│  - nfds:    数组大小                                            │
│  - timeout: 超时（毫秒），-1=永久等待，0=立即返回              │
│                                                                 │
│  返回值：                                                       │
│  - >0: 就绪的fd数量                                            │
│  - 0:  超时                                                     │
│  - -1: 错误（errno被设置）                                     │
│                                                                 │
│  事件标志：                                                     │
│  ┌──────────┬─────────────┬─────────────────────────────────┐  │
│  │ 标志     │ events可用  │ 说明                            │  │
│  ├──────────┼─────────────┼─────────────────────────────────┤  │
│  │ POLLIN   │ ✓           │ 有数据可读/有新连接可accept     │  │
│  │ POLLPRI  │ ✓           │ 有紧急数据（带外数据）          │  │
│  │ POLLOUT  │ ✓           │ 可以写入数据                    │  │
│  │ POLLRDHUP│ ✓           │ 对端关闭连接（Linux 2.6.17+）   │  │
│  │ POLLERR  │ 仅revents   │ 发生错误                        │  │
│  │ POLLHUP  │ 仅revents   │ 挂起（连接断开）                │  │
│  │ POLLNVAL │ 仅revents   │ fd未打开/无效                   │  │
│  └──────────┴─────────────┴─────────────────────────────────┘  │
│                                                                 │
│  注意：POLLERR/POLLHUP/POLLNVAL不能设置在events中，            │
│  但总会在revents中报告（即使不请求）                            │
│                                                                 │
│  poll vs select 对比：                                          │
│  ┌──────────────┬──────────────────┬──────────────────────┐    │
│  │ 特性         │ select           │ poll                 │    │
│  ├──────────────┼──────────────────┼──────────────────────┤    │
│  │ fd上限       │ FD_SETSIZE(1024) │ 无限制（数组大小）   │    │
│  │ 数据结构     │ bitmap(fd_set)   │ pollfd数组           │    │
│  │ 每次是否重置 │ 是               │ 否（revents自动清零）│    │
│  │ 事件类型     │ 读/写/异常       │ 更丰富（POLLHUP等）  │    │
│  │ 性能         │ O(n)             │ O(n)                 │    │
│  │ 跨平台       │ Windows/POSIX    │ POSIX only           │    │
│  │ 超时精度     │ 微秒(timeval)    │ 毫秒(int)            │    │
│  └──────────────┴──────────────────┴──────────────────────┘    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
*/

#include <poll.h>
#include <iostream>

namespace poll_basics {

// 将poll事件标志转为可读字符串
std::string events_to_string(short events) {
    std::string result;
    if (events & POLLIN)    result += "POLLIN ";
    if (events & POLLPRI)   result += "POLLPRI ";
    if (events & POLLOUT)   result += "POLLOUT ";
#ifdef POLLRDHUP
    if (events & POLLRDHUP) result += "POLLRDHUP ";
#endif
    if (events & POLLERR)   result += "POLLERR ";
    if (events & POLLHUP)   result += "POLLHUP ";
    if (events & POLLNVAL)  result += "POLLNVAL ";
    if (result.empty()) result = "(none)";
    return result;
}

} // namespace poll_basics

/*
自测题：

Q1: poll相比select最大的改进是什么？
A1: 1. 没有FD_SETSIZE限制（使用动态数组，大小由用户决定）
    2. 不需要每次重新设置事件集（events是输入，revents是输出，分离的）
    3. 事件类型更丰富（POLLHUP, POLLNVAL等）

Q2: POLLERR, POLLHUP, POLLNVAL的区别是什么？
A2: - POLLERR: socket上有错误（可通过getsockopt(SO_ERROR)获取具体错误）
    - POLLHUP: socket挂起，通常是连接断开（TCP对端关闭）
    - POLLNVAL: fd无效（未打开或已关闭），说明程序有bug

Q3: 为什么POLLERR等不能设置在events中？
A3: 因为这些是"总是被报告"的条件，不需要用户请求。
    内核会自动检查这些异常情况并在revents中报告。
    这样设计简化了API使用——用户只需关心POLLIN/POLLOUT。
*/
```

#### 2. poll Echo Server 完整实现

```cpp
// ============================================================
// poll Echo Server —— 完整实现
// ============================================================

#include <iostream>
#include <vector>
#include <string>
#include <poll.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <cerrno>
#include <cstring>

namespace poll_echo {

void run_poll_echo_server(uint16_t port) {
    // 1. 创建监听socket
    int listen_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (listen_fd < 0) {
        perror("socket");
        return;
    }

    int opt = 1;
    setsockopt(listen_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    addr.sin_port = htons(port);

    if (bind(listen_fd, (sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("bind");
        close(listen_fd);
        return;
    }
    listen(listen_fd, 128);

    std::cout << "[Poll Echo Server] 监听端口 " << port << std::endl;

    // 2. 初始化pollfd数组
    std::vector<pollfd> fds;
    fds.push_back({listen_fd, POLLIN, 0});

    // 客户端信息
    struct ClientInfo {
        std::string ip;
        uint16_t port;
    };
    std::vector<ClientInfo> client_info;  // 索引对应fds[i+1]

    // 3. 主循环
    while (true) {
        int ready = poll(fds.data(), fds.size(), 30000);  // 30秒超时

        if (ready < 0) {
            if (errno == EINTR) continue;
            perror("poll");
            break;
        }

        if (ready == 0) {
            std::cout << "30秒无活动..." << std::endl;
            continue;
        }

        // 4. 检查监听socket
        if (fds[0].revents & POLLIN) {
            sockaddr_in client_addr{};
            socklen_t client_len = sizeof(client_addr);
            int client_fd = accept(listen_fd,
                                   (sockaddr*)&client_addr, &client_len);

            if (client_fd >= 0) {
                // poll没有FD_SETSIZE限制！
                fds.push_back({client_fd, POLLIN, 0});

                char ip[INET_ADDRSTRLEN];
                inet_ntop(AF_INET, &client_addr.sin_addr, ip, sizeof(ip));
                uint16_t p = ntohs(client_addr.sin_port);
                client_info.push_back({ip, p});

                std::cout << "新连接: " << ip << ":" << p
                          << " (fd=" << client_fd
                          << ", 当前: " << client_info.size() << ")"
                          << std::endl;
            }
        }

        // 5. 检查客户端socket（从后往前遍历，方便删除）
        for (int i = fds.size() - 1; i >= 1; --i) {
            if (fds[i].revents == 0) continue;

            int fd = fds[i].fd;

            if (fds[i].revents & (POLLIN | POLLHUP | POLLERR)) {
                char buf[4096];
                ssize_t n = read(fd, buf, sizeof(buf));

                if (n > 0) {
                    // Echo
                    ssize_t written = 0;
                    while (written < n) {
                        ssize_t w = write(fd, buf + written, n - written);
                        if (w <= 0) break;
                        written += w;
                    }
                } else {
                    // 断开或错误
                    int ci = i - 1;  // client_info索引
                    if (n == 0) {
                        std::cout << "客户端断开: "
                                  << client_info[ci].ip << ":"
                                  << client_info[ci].port << std::endl;
                    } else {
                        std::cerr << "读取错误 fd=" << fd << std::endl;
                    }

                    close(fd);
                    fds.erase(fds.begin() + i);
                    client_info.erase(client_info.begin() + ci);
                    std::cout << "当前连接数: " << client_info.size()
                              << std::endl;
                }
            }
        }
    }

    // 清理
    for (auto& pfd : fds) {
        close(pfd.fd);
    }
}

} // namespace poll_echo
```

### Day 24-25：poll高级应用

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | poll聊天服务器与写缓冲区管理 | 3h |
| 下午 | 基于poll的简易HTTP服务器 | 3h |
| 晚上 | ppoll信号安全特性 | 2h |

#### 3. poll聊天服务器

```cpp
// ============================================================
// poll聊天服务器（带写缓冲区管理）
// ============================================================
// 改进版：使用非阻塞I/O + 写缓冲区，不会因广播阻塞

#include <iostream>
#include <string>
#include <vector>
#include <poll.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <cerrno>
#include <cstring>

namespace poll_chat {

bool set_nonblocking(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    return fcntl(fd, F_SETFL, flags | O_NONBLOCK) >= 0;
}

struct ChatClient {
    int fd;
    std::string name;
    std::string read_buf;
    std::string write_buf;
};

class PollChatServer {
public:
    void run(uint16_t port) {
        listen_fd_ = socket(AF_INET, SOCK_STREAM, 0);
        int opt = 1;
        setsockopt(listen_fd_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = htonl(INADDR_ANY);
        addr.sin_port = htons(port);
        bind(listen_fd_, (sockaddr*)&addr, sizeof(addr));
        listen(listen_fd_, 128);
        set_nonblocking(listen_fd_);

        fds_.push_back({listen_fd_, POLLIN, 0});

        std::cout << "[Poll Chat Server] 端口 " << port << std::endl;

        while (true) {
            int ready = poll(fds_.data(), fds_.size(), -1);
            if (ready < 0) {
                if (errno == EINTR) continue;
                break;
            }

            // 处理监听socket
            if (fds_[0].revents & POLLIN) {
                accept_clients();
            }

            // 处理客户端
            for (size_t i = 0; i < clients_.size(); ) {
                size_t fi = i + 1;  // fds_索引（跳过listen_fd）

                if (fi >= fds_.size()) break;

                bool should_remove = false;

                // 可读
                if (fds_[fi].revents & POLLIN) {
                    if (!handle_read(i)) {
                        should_remove = true;
                    }
                }

                // 可写
                if (!should_remove && (fds_[fi].revents & POLLOUT)) {
                    handle_write(i);
                }

                // 错误
                if (fds_[fi].revents & (POLLERR | POLLHUP | POLLNVAL)) {
                    should_remove = true;
                }

                if (should_remove) {
                    remove_client(i);
                } else {
                    // 更新事件：如果有数据待发送，监控POLLOUT
                    fds_[fi].events = POLLIN;
                    if (!clients_[i].write_buf.empty()) {
                        fds_[fi].events |= POLLOUT;
                    }
                    ++i;
                }
            }
        }
    }

private:
    void accept_clients() {
        while (true) {
            sockaddr_in addr{};
            socklen_t len = sizeof(addr);
            int fd = accept(listen_fd_, (sockaddr*)&addr, &len);
            if (fd < 0) break;

            set_nonblocking(fd);

            ChatClient client;
            client.fd = fd;
            client.name = "User_" + std::to_string(fd);

            fds_.push_back({fd, POLLIN, 0});
            clients_.push_back(std::move(client));

            // 欢迎消息
            std::string welcome = "欢迎 " + clients_.back().name + "!\n";
            clients_.back().write_buf += welcome;
            fds_.back().events |= POLLOUT;

            broadcast("[" + clients_.back().name + "] 加入聊天室\n",
                     clients_.size() - 1);
        }
    }

    bool handle_read(size_t idx) {
        char buf[4096];
        ssize_t n = read(clients_[idx].fd, buf, sizeof(buf));

        if (n <= 0) {
            if (n < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
                return true;
            }
            broadcast("[" + clients_[idx].name + "] 离开\n", idx);
            return false;
        }

        clients_[idx].read_buf.append(buf, n);

        // 按行处理
        size_t pos;
        while ((pos = clients_[idx].read_buf.find('\n')) != std::string::npos) {
            std::string line = clients_[idx].read_buf.substr(0, pos);
            clients_[idx].read_buf.erase(0, pos + 1);
            if (!line.empty() && line.back() == '\r') line.pop_back();
            if (line.empty()) continue;

            std::string msg = "[" + clients_[idx].name + "] " + line + "\n";
            broadcast(msg, idx);
        }

        return true;
    }

    void handle_write(size_t idx) {
        auto& buf = clients_[idx].write_buf;
        if (buf.empty()) return;

        ssize_t n = write(clients_[idx].fd, buf.c_str(), buf.size());
        if (n > 0) {
            buf.erase(0, n);
        }
    }

    void broadcast(const std::string& msg, size_t exclude_idx) {
        for (size_t i = 0; i < clients_.size(); ++i) {
            if (i != exclude_idx) {
                clients_[i].write_buf += msg;
                // 标记需要监控POLLOUT
                fds_[i + 1].events |= POLLOUT;
            }
        }
    }

    void remove_client(size_t idx) {
        close(clients_[idx].fd);
        fds_.erase(fds_.begin() + idx + 1);
        clients_.erase(clients_.begin() + idx);
    }

    int listen_fd_ = -1;
    std::vector<pollfd> fds_;
    std::vector<ChatClient> clients_;
};

} // namespace poll_chat
```

### Day 26-27：统一事件循环框架设计

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | EventLoop抽象设计与Timer类 | 3h |
| 下午 | SelectLoop与PollLoop实现 | 3h |
| 晚上 | SignalHandler与集成测试 | 2h |

#### 4. EventLoop 抽象基类

```cpp
// ============================================================
// EventLoop 统一事件循环框架
// ============================================================

/*
┌─────────────────────────────────────────────────────────────────┐
│              事件循环框架架构                                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                     EventLoop                           │   │
│  │  ┌───────────────────────────────────────────────────┐  │   │
│  │  │ add_fd(fd, events, callback)                      │  │   │
│  │  │ modify_fd(fd, events)                             │  │   │
│  │  │ remove_fd(fd)                                     │  │   │
│  │  │ run_after(delay, callback) → timer_id             │  │   │
│  │  │ cancel_timer(timer_id)                            │  │   │
│  │  │ run()  / stop()                                   │  │   │
│  │  └───────────────────────────────────────────────────┘  │   │
│  │                         │                                │   │
│  │           ┌─────────────┼─────────────┐                  │   │
│  │           ▼             ▼             ▼                   │   │
│  │  ┌──────────────┐ ┌──────────┐ ┌────────────┐           │   │
│  │  │  SelectLoop  │ │ PollLoop │ │ (EpollLoop)│           │   │
│  │  └──────────────┘ └──────────┘ └────────────┘           │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  支持组件：                                                     │
│  ┌────────────────┐  ┌────────────────┐                        │
│  │ TimerManager   │  │ SignalHandler  │                        │
│  │ (排序定时器)   │  │ (self-pipe)   │                        │
│  └────────────────┘  └────────────────┘                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
*/

#pragma once
#include <functional>
#include <unordered_map>
#include <vector>
#include <queue>
#include <chrono>
#include <cstdint>

namespace event_framework {

// 事件类型
enum EventType : uint32_t {
    EV_NONE  = 0,
    EV_READ  = 1 << 0,
    EV_WRITE = 1 << 1,
    EV_ERROR = 1 << 2,
};

// 事件回调
using EventCallback = std::function<void(int fd, uint32_t events)>;

// 定时器ID
using TimerId = uint64_t;

// 定时器回调
using TimerCallback = std::function<void()>;

// 时间点类型
using TimePoint = std::chrono::steady_clock::time_point;
using Duration = std::chrono::milliseconds;

// ============================================================
// Timer: 单个定时器
// ============================================================
struct Timer {
    TimerId id;
    TimePoint expiry;       // 到期时间
    Duration interval;      // 重复间隔（0=一次性）
    TimerCallback callback;
    bool cancelled = false;

    bool operator>(const Timer& other) const {
        return expiry > other.expiry;  // 小顶堆
    }
};

// ============================================================
// TimerManager: 定时器管理
// ============================================================
class TimerManager {
public:
    // 添加一次性定时器
    TimerId run_after(Duration delay, TimerCallback cb) {
        Timer timer;
        timer.id = next_id_++;
        timer.expiry = std::chrono::steady_clock::now() + delay;
        timer.interval = Duration::zero();
        timer.callback = std::move(cb);

        timers_.push(timer);
        return timer.id;
    }

    // 添加重复定时器
    TimerId run_every(Duration interval, TimerCallback cb) {
        Timer timer;
        timer.id = next_id_++;
        timer.expiry = std::chrono::steady_clock::now() + interval;
        timer.interval = interval;
        timer.callback = std::move(cb);

        timers_.push(timer);
        return timer.id;
    }

    // 取消定时器
    void cancel(TimerId id) {
        cancelled_ids_.insert(id);
    }

    // 获取到最近定时器的剩余时间（毫秒），-1表示无定时器
    int next_timeout_ms() const {
        while (!timers_.empty()) {
            if (cancelled_ids_.count(timers_.top().id)) {
                // 跳过已取消的（延迟删除）
                const_cast<TimerManager*>(this)->timers_.pop();
                continue;
            }

            auto now = std::chrono::steady_clock::now();
            auto diff = std::chrono::duration_cast<Duration>(
                timers_.top().expiry - now
            );

            if (diff.count() <= 0) return 0;
            return diff.count();
        }
        return -1;  // 无定时器
    }

    // 处理到期的定时器
    void process_expired() {
        auto now = std::chrono::steady_clock::now();

        while (!timers_.empty()) {
            if (cancelled_ids_.count(timers_.top().id)) {
                cancelled_ids_.erase(timers_.top().id);
                timers_.pop();
                continue;
            }

            if (timers_.top().expiry > now) break;

            Timer timer = timers_.top();
            timers_.pop();

            timer.callback();

            // 重复定时器重新入队
            if (timer.interval.count() > 0 && !timer.cancelled) {
                timer.expiry = now + timer.interval;
                timers_.push(timer);
            }
        }
    }

private:
    std::priority_queue<Timer, std::vector<Timer>, std::greater<Timer>> timers_;
    std::set<TimerId> cancelled_ids_;
    TimerId next_id_ = 1;
};

// ============================================================
// EventLoop: 抽象基类
// ============================================================
class EventLoop {
public:
    virtual ~EventLoop() = default;

    // fd管理
    virtual void add_fd(int fd, uint32_t events, EventCallback cb) = 0;
    virtual void modify_fd(int fd, uint32_t events) = 0;
    virtual void remove_fd(int fd) = 0;

    // 定时器
    TimerId run_after(Duration delay, TimerCallback cb) {
        return timer_mgr_.run_after(delay, std::move(cb));
    }

    TimerId run_every(Duration interval, TimerCallback cb) {
        return timer_mgr_.run_every(interval, std::move(cb));
    }

    void cancel_timer(TimerId id) {
        timer_mgr_.cancel(id);
    }

    // 运行事件循环
    void run() {
        running_ = true;
        while (running_) {
            // 计算poll超时（考虑定时器）
            int timeout = timer_mgr_.next_timeout_ms();
            if (timeout < 0) timeout = 10000;  // 默认10秒

            // 调用子类的poll实现
            poll_once(timeout);

            // 处理到期的定时器
            timer_mgr_.process_expired();
        }
    }

    void stop() { running_ = false; }

protected:
    // 子类实现：执行一次I/O多路复用等待
    virtual void poll_once(int timeout_ms) = 0;

    // 子类使用：触发fd回调
    void dispatch_event(int fd, uint32_t events) {
        auto it = callbacks_.find(fd);
        if (it != callbacks_.end()) {
            it->second(fd, events);
        }
    }

    bool running_ = false;
    std::unordered_map<int, EventCallback> callbacks_;
    TimerManager timer_mgr_;
};

} // namespace event_framework
```

#### 5. SelectLoop 实现

```cpp
// ============================================================
// SelectLoop: 基于select的EventLoop实现
// ============================================================

#include <sys/select.h>
#include <algorithm>
#include <set>

namespace event_framework {

class SelectLoop : public EventLoop {
public:
    void add_fd(int fd, uint32_t events, EventCallback cb) override {
        if (fd >= FD_SETSIZE) {
            std::cerr << "SelectLoop: fd " << fd
                      << " >= FD_SETSIZE " << FD_SETSIZE << std::endl;
            return;
        }

        callbacks_[fd] = std::move(cb);
        fd_events_[fd] = events;
        monitored_fds_.insert(fd);
        update_max_fd();
    }

    void modify_fd(int fd, uint32_t events) override {
        fd_events_[fd] = events;
    }

    void remove_fd(int fd) override {
        callbacks_.erase(fd);
        fd_events_.erase(fd);
        monitored_fds_.erase(fd);
        update_max_fd();
    }

protected:
    void poll_once(int timeout_ms) override {
        fd_set read_set, write_set;
        FD_ZERO(&read_set);
        FD_ZERO(&write_set);

        for (auto& [fd, events] : fd_events_) {
            if (events & EV_READ)  FD_SET(fd, &read_set);
            if (events & EV_WRITE) FD_SET(fd, &write_set);
        }

        timeval tv;
        tv.tv_sec = timeout_ms / 1000;
        tv.tv_usec = (timeout_ms % 1000) * 1000;

        int n = select(max_fd_ + 1, &read_set, &write_set, nullptr, &tv);

        if (n > 0) {
            // 收集就绪的fd（避免在回调中修改容器）
            std::vector<std::pair<int, uint32_t>> ready_fds;

            for (int fd : monitored_fds_) {
                uint32_t revents = EV_NONE;
                if (FD_ISSET(fd, &read_set))  revents |= EV_READ;
                if (FD_ISSET(fd, &write_set)) revents |= EV_WRITE;
                if (revents != EV_NONE) {
                    ready_fds.emplace_back(fd, revents);
                }
            }

            for (auto& [fd, revents] : ready_fds) {
                dispatch_event(fd, revents);
            }
        }
    }

private:
    void update_max_fd() {
        max_fd_ = monitored_fds_.empty() ? -1 : *monitored_fds_.rbegin();
    }

    std::unordered_map<int, uint32_t> fd_events_;
    std::set<int> monitored_fds_;
    int max_fd_ = -1;
};

} // namespace event_framework
```

#### 6. PollLoop 实现

```cpp
// ============================================================
// PollLoop: 基于poll的EventLoop实现
// ============================================================

#include <poll.h>
#include <unordered_map>

namespace event_framework {

class PollLoop : public EventLoop {
public:
    void add_fd(int fd, uint32_t events, EventCallback cb) override {
        callbacks_[fd] = std::move(cb);

        pollfd pfd;
        pfd.fd = fd;
        pfd.events = to_poll_events(events);
        pfd.revents = 0;

        fd_index_[fd] = pollfds_.size();
        pollfds_.push_back(pfd);
    }

    void modify_fd(int fd, uint32_t events) override {
        auto it = fd_index_.find(fd);
        if (it != fd_index_.end()) {
            pollfds_[it->second].events = to_poll_events(events);
        }
    }

    void remove_fd(int fd) override {
        auto it = fd_index_.find(fd);
        if (it == fd_index_.end()) return;

        size_t idx = it->second;
        size_t last = pollfds_.size() - 1;

        if (idx != last) {
            // 将最后一个元素移到被删除的位置
            pollfds_[idx] = pollfds_[last];
            fd_index_[pollfds_[idx].fd] = idx;
        }

        pollfds_.pop_back();
        fd_index_.erase(fd);
        callbacks_.erase(fd);
    }

protected:
    void poll_once(int timeout_ms) override {
        int n = ::poll(pollfds_.data(), pollfds_.size(), timeout_ms);

        if (n > 0) {
            // 收集就绪的fd
            std::vector<std::pair<int, uint32_t>> ready_fds;

            for (auto& pfd : pollfds_) {
                if (pfd.revents != 0) {
                    uint32_t events = from_poll_events(pfd.revents);
                    ready_fds.emplace_back(pfd.fd, events);
                    pfd.revents = 0;
                }
            }

            for (auto& [fd, events] : ready_fds) {
                dispatch_event(fd, events);
            }
        }
    }

private:
    static short to_poll_events(uint32_t events) {
        short pe = 0;
        if (events & EV_READ)  pe |= POLLIN;
        if (events & EV_WRITE) pe |= POLLOUT;
        return pe;
    }

    static uint32_t from_poll_events(short pe) {
        uint32_t events = EV_NONE;
        if (pe & POLLIN)                  events |= EV_READ;
        if (pe & POLLOUT)                 events |= EV_WRITE;
        if (pe & (POLLERR | POLLHUP))     events |= EV_ERROR;
        return events;
    }

    std::vector<pollfd> pollfds_;
    std::unordered_map<int, size_t> fd_index_;  // fd → pollfds_索引
};

} // namespace event_framework
```

#### 7. SignalHandler（self-pipe方式）

```cpp
// ============================================================
// SignalHandler: 将信号转换为fd事件（self-pipe trick）
// ============================================================

#include <signal.h>
#include <unistd.h>
#include <fcntl.h>
#include <cerrno>
#include <cstring>
#include <functional>
#include <map>

namespace event_framework {

class SignalHandler {
public:
    using SignalCallback = std::function<void(int signo)>;

    SignalHandler() {
        // 创建self-pipe
        if (pipe(pipe_fds_) < 0) {
            perror("pipe");
            return;
        }

        // 设置非阻塞
        for (int i = 0; i < 2; ++i) {
            int flags = fcntl(pipe_fds_[i], F_GETFL, 0);
            fcntl(pipe_fds_[i], F_SETFL, flags | O_NONBLOCK);
        }

        instance_ = this;
    }

    ~SignalHandler() {
        if (pipe_fds_[0] >= 0) close(pipe_fds_[0]);
        if (pipe_fds_[1] >= 0) close(pipe_fds_[1]);
        instance_ = nullptr;
    }

    // 获取读端fd（注册到EventLoop）
    int read_fd() const { return pipe_fds_[0]; }

    // 注册信号处理
    void add_signal(int signo, SignalCallback cb) {
        signal_callbacks_[signo] = std::move(cb);

        struct sigaction sa{};
        sa.sa_handler = signal_handler_func;
        sigemptyset(&sa.sa_mask);
        sa.sa_flags = SA_RESTART;
        sigaction(signo, &sa, nullptr);
    }

    // 处理管道中的信号（在EventLoop回调中调用）
    void handle_signals() {
        char signals[64];
        ssize_t n = read(pipe_fds_[0], signals, sizeof(signals));

        if (n > 0) {
            for (ssize_t i = 0; i < n; ++i) {
                int signo = static_cast<int>(signals[i]);
                auto it = signal_callbacks_.find(signo);
                if (it != signal_callbacks_.end()) {
                    it->second(signo);
                }
            }
        }
    }

private:
    // 信号处理函数（async-signal-safe: 只调用write）
    static void signal_handler_func(int signo) {
        if (instance_ && instance_->pipe_fds_[1] >= 0) {
            char s = static_cast<char>(signo);
            // write是async-signal-safe的
            ssize_t n = write(instance_->pipe_fds_[1], &s, 1);
            (void)n;
        }
    }

    int pipe_fds_[2] = {-1, -1};
    std::map<int, SignalCallback> signal_callbacks_;
    static SignalHandler* instance_;
};

SignalHandler* SignalHandler::instance_ = nullptr;

} // namespace event_framework
```

### Day 28：项目集成与性能测试

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | 框架Echo Server + 性能对比 | 3h |
| 下午 | CMakeLists.txt与集成测试 | 3h |
| 晚上 | 总结与文档 | 2h |

#### 8. 框架Echo Server

```cpp
// ============================================================
// 使用事件循环框架的Echo Server
// ============================================================

#include <iostream>
#include <memory>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <cstring>
#include <csignal>

// 包含前面定义的头文件
// #include "event_loop.hpp"
// #include "select_loop.hpp"
// #include "poll_loop.hpp"
// #include "signal_handler.hpp"

namespace framework_demo {

using namespace event_framework;

bool set_nonblocking(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    return fcntl(fd, F_SETFL, flags | O_NONBLOCK) >= 0;
}

class EchoServer {
public:
    EchoServer(std::unique_ptr<EventLoop> loop, uint16_t port)
        : loop_(std::move(loop)), port_(port) {}

    void start() {
        // 创建监听socket
        listen_fd_ = socket(AF_INET, SOCK_STREAM, 0);
        int opt = 1;
        setsockopt(listen_fd_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = htonl(INADDR_ANY);
        addr.sin_port = htons(port_);
        bind(listen_fd_, (sockaddr*)&addr, sizeof(addr));
        listen(listen_fd_, 128);
        set_nonblocking(listen_fd_);

        // 注册监听socket
        loop_->add_fd(listen_fd_, EV_READ,
            [this](int fd, uint32_t events) {
                on_accept();
            });

        // 注册信号处理
        signal_handler_ = std::make_unique<SignalHandler>();
        signal_handler_->add_signal(SIGINT, [this](int) {
            std::cout << "\n收到SIGINT，停止服务器" << std::endl;
            loop_->stop();
        });

        loop_->add_fd(signal_handler_->read_fd(), EV_READ,
            [this](int fd, uint32_t events) {
                signal_handler_->handle_signals();
            });

        // 添加定时器：每10秒输出状态
        loop_->run_every(std::chrono::seconds(10), [this]() {
            std::cout << "[状态] 活跃连接: " << connection_count_
                      << std::endl;
        });

        std::cout << "[Framework Echo Server] 端口 " << port_ << std::endl;
        loop_->run();

        // 清理
        close(listen_fd_);
    }

private:
    void on_accept() {
        while (true) {
            sockaddr_in addr{};
            socklen_t len = sizeof(addr);
            int fd = accept(listen_fd_, (sockaddr*)&addr, &len);
            if (fd < 0) break;

            set_nonblocking(fd);
            ++connection_count_;

            loop_->add_fd(fd, EV_READ,
                [this](int fd, uint32_t events) {
                    on_client_event(fd, events);
                });

            char ip[INET_ADDRSTRLEN];
            inet_ntop(AF_INET, &addr.sin_addr, ip, sizeof(ip));
            std::cout << "连接: " << ip << ":"
                      << ntohs(addr.sin_port) << std::endl;
        }
    }

    void on_client_event(int fd, uint32_t events) {
        if (events & EV_READ) {
            char buf[4096];
            ssize_t n = read(fd, buf, sizeof(buf));
            if (n > 0) {
                write(fd, buf, n);
            } else {
                close_connection(fd);
            }
        }
        if (events & EV_ERROR) {
            close_connection(fd);
        }
    }

    void close_connection(int fd) {
        loop_->remove_fd(fd);
        close(fd);
        --connection_count_;
    }

    std::unique_ptr<EventLoop> loop_;
    std::unique_ptr<SignalHandler> signal_handler_;
    int listen_fd_ = -1;
    uint16_t port_;
    int connection_count_ = 0;
};

// 使用示例
void run_with_select(uint16_t port) {
    auto loop = std::make_unique<SelectLoop>();
    EchoServer server(std::move(loop), port);
    server.start();
}

void run_with_poll(uint16_t port) {
    auto loop = std::make_unique<PollLoop>();
    EchoServer server(std::move(loop), port);
    server.start();
}

} // namespace framework_demo
```

#### 9. CMakeLists.txt

```cmake
# ============================================================
# 事件循环框架 CMakeLists.txt
# ============================================================

cmake_minimum_required(VERSION 3.14)
project(EventLoopFramework VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 头文件库（header-only）
add_library(event_framework INTERFACE)
target_include_directories(event_framework INTERFACE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

# 示例程序
add_executable(select_echo_server examples/select_echo_server.cpp)
target_link_libraries(select_echo_server PRIVATE event_framework)

add_executable(poll_echo_server examples/poll_echo_server.cpp)
target_link_libraries(poll_echo_server PRIVATE event_framework)

add_executable(select_chat_server examples/select_chat_server.cpp)
target_link_libraries(select_chat_server PRIVATE event_framework)

add_executable(poll_chat_server examples/poll_chat_server.cpp)
target_link_libraries(poll_chat_server PRIVATE event_framework)

add_executable(framework_echo examples/framework_echo.cpp)
target_link_libraries(framework_echo PRIVATE event_framework)

add_executable(http_server examples/http_server.cpp)
target_link_libraries(http_server PRIVATE event_framework)

# 基准测试
add_executable(benchmark tests/benchmark.cpp)
target_link_libraries(benchmark PRIVATE event_framework)

# 单元测试
enable_testing()

add_executable(test_buffer tests/test_buffer.cpp)
target_link_libraries(test_buffer PRIVATE event_framework)
add_test(NAME BufferTests COMMAND test_buffer)

add_executable(test_timer tests/test_timer.cpp)
target_link_libraries(test_timer PRIVATE event_framework)
add_test(NAME TimerTests COMMAND test_timer)

add_executable(test_event_loop tests/test_event_loop.cpp)
target_link_libraries(test_event_loop PRIVATE event_framework)
add_test(NAME EventLoopTests COMMAND test_event_loop)
```

#### 第四周检验标准

- [ ] 掌握pollfd结构体和事件标志
- [ ] 理解POLLIN/POLLOUT/POLLERR/POLLHUP/POLLNVAL的区别
- [ ] 能编写完整的poll echo server
- [ ] 掌握poll动态fd管理（增删改）
- [ ] 理解poll vs select的对比优势
- [ ] 能实现poll聊天服务器（含写缓冲区管理）
- [ ] 掌握EventLoop抽象设计（策略模式）
- [ ] 能实现TimerManager（优先队列、一次性/重复定时器）
- [ ] 能实现SelectLoop和PollLoop
- [ ] 能实现SignalHandler（self-pipe trick）
- [ ] 能使用框架编写echo server
- [ ] 理解框架的可扩展性（为epoll预留接口）

---

## 本月检验标准汇总

### 理论知识检验（笔试/口述）

| 序号 | 检验项目 | 达标要求 | 自评 |
|:----:|:---------|:---------|:----:|
| 1 | 五种I/O模型 | 能画出每种模型的用户/内核交互图 | ☐ |
| 2 | 同步vs异步 | 能解释两者区别及判断标准（Phase 2由谁完成） | ☐ |
| 3 | 阻塞vs非阻塞 | 能解释两者区别及对应系统调用行为 | ☐ |
| 4 | C10K问题 | 能解释问题本质和解决思路 | ☐ |
| 5 | 线程资源消耗 | 能说出每个线程的栈内存和上下文切换开销 | ☐ |
| 6 | EAGAIN含义 | 能解释EAGAIN/EWOULDBLOCK的含义和处理方式 | ☐ |
| 7 | EINPROGRESS | 能解释非阻塞connect的EINPROGRESS流程 | ☐ |
| 8 | fd_set结构 | 能说明fd_set是位图及FD_SETSIZE限制 | ☐ |
| 9 | select参数 | 能说明nfds, readfds, writefds, exceptfds, timeout的含义 | ☐ |
| 10 | Socket可读条件 | 能列出至少4种Socket可读条件 | ☐ |
| 11 | Socket可写条件 | 能列出至少3种Socket可写条件 | ☐ |
| 12 | select局限 | 能说出至少3个select的性能问题 | ☐ |
| 13 | pselect特性 | 能解释pselect的信号安全机制 | ☐ |
| 14 | pollfd结构 | 能说明fd/events/revents三个字段的作用 | ☐ |
| 15 | poll事件标志 | 能区分POLLIN/POLLOUT/POLLERR/POLLHUP/POLLNVAL | ☐ |
| 16 | poll vs select | 能从5个维度对比两者差异 | ☐ |
| 17 | 应用层缓冲区 | 能解释非阻塞I/O为什么需要应用层缓冲区 | ☐ |
| 18 | self-pipe trick | 能解释self-pipe trick的原理和用途 | ☐ |
| 19 | 事件循环 | 能描述EventLoop的核心工作流程 | ☐ |
| 20 | 超时方式对比 | 能对比SO_RCVTIMEO/alarm/select三种超时方式 | ☐ |

### 实践技能检验（上机）

| 序号 | 检验项目 | 达标要求 | 自评 |
|:----:|:---------|:---------|:----:|
| 1 | 设置非阻塞 | 能用fcntl设置/取消O_NONBLOCK | ☐ |
| 2 | 非阻塞读 | 能正确处理EAGAIN/EWOULDBLOCK/EINTR | ☐ |
| 3 | 非阻塞写 | 能处理部分写入和EAGAIN | ☐ |
| 4 | connect超时 | 能实现非阻塞connect + select超时 | ☐ |
| 5 | 并行连接 | 能实现parallel_connect | ☐ |
| 6 | Buffer类 | 能实现自动扩容的读写缓冲区 | ☐ |
| 7 | Connection类 | 能实现连接状态机管理 | ☐ |
| 8 | select服务器 | 能从零编写select echo server | ☐ |
| 9 | select聊天 | 能实现select多客户端消息广播 | ☐ |
| 10 | select HTTP | 能实现基于select的简易HTTP服务器 | ☐ |
| 11 | pselect使用 | 能使用pselect处理信号安全问题 | ☐ |
| 12 | poll服务器 | 能从零编写poll echo server | ☐ |
| 13 | poll聊天 | 能实现poll聊天服务器（含写缓冲区） | ☐ |
| 14 | EventLoop | 能实现EventLoop抽象基类 | ☐ |
| 15 | SelectLoop | 能实现基于select的EventLoop | ☐ |
| 16 | PollLoop | 能实现基于poll的EventLoop | ☐ |
| 17 | TimerManager | 能实现优先队列定时器管理 | ☐ |
| 18 | SignalHandler | 能实现self-pipe方式的信号处理 | ☐ |
| 19 | 框架集成 | 能使用框架编写echo server | ☐ |
| 20 | 性能测试 | 能编写select/poll性能对比基准 | ☐ |

### 达标标准

```
+--------------------------------------------------+
|              Month-26 达标标准                    |
+--------------------------------------------------+
| 理论知识：20项中至少掌握16项（80%）               |
| 实践技能：20项中至少完成16项（80%）               |
| 代码质量：所有代码能编译通过并正确运行            |
| 项目完成：事件循环框架实现并通过基本测试          |
+--------------------------------------------------+
```

---

## 输出物清单

### 项目目录结构

```
month-26-event-loop/
├── include/                          # 头文件
│   ├── event_types.hpp               # 事件类型定义
│   ├── buffer.hpp                    # Buffer缓冲区类
│   ├── connection.hpp                # Connection连接管理
│   ├── event_loop.hpp                # EventLoop抽象基类
│   ├── select_loop.hpp               # SelectLoop实现
│   ├── poll_loop.hpp                 # PollLoop实现
│   ├── timer.hpp                     # Timer + TimerManager
│   └── signal_handler.hpp            # SignalHandler (self-pipe)
├── examples/                         # 示例程序
│   ├── blocking_echo_server.cpp      # 单线程阻塞服务器（问题演示）
│   ├── thread_per_conn_server.cpp    # Thread-per-connection服务器
│   ├── nonblocking_echo_server.cpp   # 非阻塞忙等服务器
│   ├── select_echo_server.cpp        # select echo服务器
│   ├── select_chat_server.cpp        # select聊天服务器
│   ├── select_http_server.cpp        # select HTTP服务器
│   ├── poll_echo_server.cpp          # poll echo服务器
│   ├── poll_chat_server.cpp          # poll聊天服务器
│   ├── framework_echo.cpp            # 框架echo服务器
│   ├── connect_timeout.cpp           # connect超时演示
│   └── parallel_connect.cpp          # 并行连接演示
├── tests/                            # 测试
│   ├── test_buffer.cpp               # Buffer类测试
│   ├── test_timer.cpp                # TimerManager测试
│   ├── test_event_loop.cpp           # EventLoop测试
│   └── benchmark.cpp                 # select/poll性能对比
├── CMakeLists.txt                    # 构建配置
└── README.md                         # 项目说明
```

### 输出物完成度检查表

| 类别 | 输出物 | 说明 | 完成 |
|:----:|:-------|:-----|:----:|
| **头文件** | event_types.hpp | 事件类型、回调定义 | ☐ |
| | buffer.hpp | 自动扩容Buffer类 | ☐ |
| | connection.hpp | 连接状态机管理 | ☐ |
| | event_loop.hpp | EventLoop抽象基类 | ☐ |
| | select_loop.hpp | select后端实现 | ☐ |
| | poll_loop.hpp | poll后端实现 | ☐ |
| | timer.hpp | 定时器管理 | ☐ |
| | signal_handler.hpp | 信号处理（self-pipe） | ☐ |
| **示例** | blocking_echo_server.cpp | 阻塞服务器问题演示 | ☐ |
| | select_echo_server.cpp | select echo服务器 | ☐ |
| | select_chat_server.cpp | select聊天服务器 | ☐ |
| | poll_echo_server.cpp | poll echo服务器 | ☐ |
| | poll_chat_server.cpp | poll聊天服务器 | ☐ |
| | framework_echo.cpp | 框架echo服务器 | ☐ |
| | connect_timeout.cpp | 连接超时演示 | ☐ |
| **测试** | test_buffer.cpp | Buffer功能测试 | ☐ |
| | test_timer.cpp | 定时器测试 | ☐ |
| | benchmark.cpp | 性能对比基准 | ☐ |
| **构建** | CMakeLists.txt | CMake配置 | ☐ |

---

## 学习建议

### 学习顺序建议

```
推荐学习路径：

Week 1: 理论先行
    │
    ├── 1. 画出五种I/O模型图（Day 1-2）
    │      └── 每种模型用户/内核交互手画
    │      └── 理解同步/异步的本质区别
    │
    ├── 2. 体验阻塞服务器的问题（Day 3-4）
    │      └── 运行单线程服务器，用两个nc连接
    │      └── 观察thread-per-connection的资源消耗
    │
    └── 3. 实现超时工具（Day 5-7）
           └── 三种超时方式都试一遍
           └── 重点掌握connect_with_timeout

Week 2: 非阻塞编程实战
    │
    ├── 1. 先理解EAGAIN（Day 8-9）
    │      └── 写测试程序观察非阻塞read行为
    │      └── 对比阻塞/非阻塞下各系统调用
    │
    ├── 2. 实现Buffer类（Day 10-11）
    │      └── 理解readv优化
    │      └── 测试自动扩容
    │
    └── 3. 构建非阻塞服务器（Day 12-14）
           └── 体验忙等的CPU问题
           └── 理解为什么需要select/poll

Week 3: select深入
    │
    ├── 1. 从echo server开始（Day 15-16）
    │      └── 用nc/telnet测试多客户端
    │      └── 理解master_set和working_set
    │
    ├── 2. 实现聊天服务器（Day 17-18）
    │      └── 理解消息广播
    │      └── 用多个终端测试
    │
    └── 3. 性能测试与HTTP（Day 19-21）
           └── 跑benchmark感受O(n)开销
           └── 用浏览器测试HTTP服务器

Week 4: poll与框架
    │
    ├── 1. poll服务器（Day 22-23）
    │      └── 对比select代码的差异
    │      └── 测试超过1024个连接
    │
    ├── 2. 设计EventLoop（Day 24-25）
    │      └── 先设计接口，再实现
    │      └── 定时器和信号处理
    │
    └── 3. 集成测试（Day 26-28）
           └── 用框架重写echo server
           └── 运行benchmark对比
```

### 调试技巧

```
+--------------------------------------------------+
|          I/O多路复用调试技巧                      |
+--------------------------------------------------+
| 1. 使用nc/telnet测试服务器                       |
|    $ nc localhost 8080                          |
|    $ echo "hello" | nc localhost 8080           |
|                                                  |
| 2. 多终端同时连接测试并发                        |
|    $ for i in $(seq 1 10); do                   |
|        nc localhost 8080 &                      |
|    done                                          |
|                                                  |
| 3. 用strace追踪select/poll调用                  |
|    $ strace -e select,poll ./server             |
|                                                  |
| 4. 查看进程的fd列表                             |
|    $ ls -la /proc/<pid>/fd                      |
|    $ lsof -p <pid>                              |
|                                                  |
| 5. 查看socket缓冲区状态                         |
|    $ ss -tnm                                    |
|                                                  |
| 6. CPU使用率监控（忙等检测）                     |
|    $ top -p <pid>                               |
+--------------------------------------------------+
```

### 常见错误与解决

| 错误现象 | 可能原因 | 解决方法 |
|:---------|:---------|:---------|
| select返回EBADF | fd_set中有已关闭的fd | 关闭fd后立即FD_CLR |
| fd >= FD_SETSIZE崩溃 | 连接数超过1024 | 检查fd值或改用poll |
| CPU 100%占用 | 忙等轮询/无效fd循环 | 确保使用select/poll阻塞等待 |
| select总是立即返回 | fd_set未正确设置 | 确保FD_ZERO后再FD_SET |
| poll POLLNVAL | pollfd中有已关闭的fd | 关闭fd后从数组中移除 |
| 写入阻塞导致服务器停顿 | 使用阻塞socket广播 | 改用非阻塞socket+写缓冲区 |
| 信号丢失 | select/信号竞争 | 使用pselect或self-pipe trick |
| 定时器不触发 | poll超时与定时器不协调 | 使用TimerManager计算超时 |
| 消息粘连 | 未处理TCP流特性 | 使用recv_buffer按行/长度分包 |

---

## 结语

```
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║         恭喜完成 Month-26：阻塞与非阻塞I/O 学习！             ║
║                                                                ║
║    ┌──────────────────────────────────────────────────────┐   ║
║    │  本月你已掌握：                                      │   ║
║    │                                                      │   ║
║    │  ✓ 五种I/O模型的原理与区别                          │   ║
║    │  ✓ 阻塞I/O的问题与C10K挑战                         │   ║
║    │  ✓ 超时机制（SO_RCVTIMEO/alarm/select）             │   ║
║    │  ✓ 非阻塞I/O编程（fcntl/EAGAIN/connect）           │   ║
║    │  ✓ 应用层缓冲区（Buffer类）                         │   ║
║    │  ✓ Connection连接状态机管理                         │   ║
║    │  ✓ select系统调用（API/聊天/HTTP服务器）            │   ║
║    │  ✓ pselect信号安全特性                              │   ║
║    │  ✓ poll系统调用（API/聊天/写缓冲）                  │   ║
║    │  ✓ 统一事件循环框架（EventLoop）                    │   ║
║    │  ✓ 定时器管理（TimerManager）                       │   ║
║    │  ✓ 信号处理集成（self-pipe trick）                  │   ║
║    └──────────────────────────────────────────────────────┘   ║
║                                                                ║
║    这是I/O模型演进的关键一步！                                 ║
║    你已经理解了：                                              ║
║    - 为什么需要I/O多路复用（阻塞和忙等都不行）                ║
║    - select/poll如何用一个线程管理多个连接                     ║
║    - 如何设计可扩展的事件循环框架                              ║
║                                                                ║
║    但select/poll仍然有O(n)的性能瓶颈...                       ║
║    Month-27将学习epoll——Linux高性能I/O的核心！                ║
║    epoll用O(1)的就绪通知解决了O(n)扫描的问题                  ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
```

---

## 下月预告：Month-27 epoll深度解析

```
Month-27 学习主题预览：

┌─────────────────────────────────────────────────────────┐
│              epoll深度解析——Linux高性能I/O              │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Week 1: epoll基础                                      │
│  ├── epoll_create / epoll_ctl / epoll_wait API         │
│  ├── epoll_event结构与事件类型                         │
│  ├── epoll内部实现原理（红黑树+就绪链表）              │
│  └── epoll echo server                                 │
│                                                         │
│  Week 2: 触发模式                                      │
│  ├── Level-Triggered (LT) vs Edge-Triggered (ET)       │
│  ├── ET模式的编程要求（循环读/写直到EAGAIN）           │
│  ├── EPOLLONESHOT一次性触发                            │
│  └── LT/ET模式性能对比                                 │
│                                                         │
│  Week 3: epoll高级应用                                 │
│  ├── epoll + 非阻塞I/O最佳实践                        │
│  ├── epoll + 线程池                                    │
│  ├── EpollLoop集成到事件循环框架                       │
│  └── 高并发HTTP服务器                                  │
│                                                         │
│  Week 4: 性能优化与实战                                │
│  ├── epoll性能调优（ET vs LT, EPOLLEXCLUSIVE）         │
│  ├── 10K+连接压力测试                                  │
│  ├── 与select/poll性能对比基准                         │
│  └── 生产级epoll服务器设计                             │
│                                                         │
└─────────────────────────────────────────────────────────┘

     Month-25               Month-26               Month-27
   Socket基础    ──────►  阻塞/非阻塞I/O  ──────►   epoll
   (已完成)           select/poll            (下月主题)
                     事件循环框架
                     (本月完成)
```

---

**Month-26 阻塞与非阻塞I/O —— 学习计划完成！**

*从阻塞到非阻塞，从忙等到多路复用——I/O模型演进之路正在展开！*
