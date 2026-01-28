# Month 22: 协程应用——异步I/O与事件循环

## 本月主题概述

本月将Month-21学习的C++20协程基础与真实的异步I/O结合，构建生产级的协程网络库。通过将系统调用封装为Awaitable，实现高性能、易用的异步网络编程。这是从"理解协程原理"到"实战协程应用"的关键跨越。

### 为什么需要协程+异步I/O？

```
传统多线程模型的问题：
┌─────────────────────────────────────────────────────────────┐
│  Client 1  ──→  Thread 1  ──→  阻塞等待I/O                  │
│  Client 2  ──→  Thread 2  ──→  阻塞等待I/O                  │
│  Client 3  ──→  Thread 3  ──→  阻塞等待I/O                  │
│     ...           ...              ...                       │
│  Client N  ──→  Thread N  ──→  阻塞等待I/O                  │
├─────────────────────────────────────────────────────────────┤
│  问题：                                                      │
│  • 每个连接需要一个线程，内存开销大（~1MB/线程）              │
│  • 线程切换开销高（~1-10μs）                                 │
│  • 10000连接 = 10000线程 = 10GB内存                         │
└─────────────────────────────────────────────────────────────┘

协程+异步I/O模型：
┌─────────────────────────────────────────────────────────────┐
│  Client 1  ──┐                                               │
│  Client 2  ──┼──→  EventLoop  ──→  单线程处理所有连接        │
│  Client 3  ──┤      (epoll/     协程在I/O等待时暂停          │
│     ...      │       kqueue)    其他协程继续执行              │
│  Client N  ──┘                                               │
├─────────────────────────────────────────────────────────────┤
│  优势：                                                      │
│  • 单线程可处理数万连接                                      │
│  • 协程切换开销极低（~10-30ns）                              │
│  • 10000连接 ≈ 10000协程 ≈ 几十MB内存                       │
│  • 代码风格同步，易于理解和维护                              │
└─────────────────────────────────────────────────────────────┘
```

### 学习目标

1. **事件循环设计**：理解并实现跨平台I/O多路复用事件循环
2. **异步I/O封装**：将系统调用(read/write/accept/connect)封装为Awaitable
3. **Socket抽象**：实现协程化的AsyncTcpSocket、AsyncTcpListener
4. **实战应用**：完成协程HTTP客户端和高并发Echo服务器

### 学习目标量化

| 周次 | 目标编号 | 具体目标 |
|------|----------|----------|
| W1 | W1-G1 | 理解epoll/kqueue工作原理 |
| W1 | W1-G2 | 实现跨平台I/O多路复用抽象 |
| W1 | W1-G3 | 完成EventLoop核心实现 |
| W2 | W2-G1 | 掌握将系统调用封装为Awaitable的方法 |
| W2 | W2-G2 | 实现AsyncRead/AsyncWrite |
| W2 | W2-G3 | 实现超时和取消机制 |
| W3 | W3-G1 | 实现AsyncTcpSocket类 |
| W3 | W3-G2 | 实现AsyncTcpListener类 |
| W3 | W3-G3 | 实现缓冲I/O |
| W4 | W4-G1 | 完成高并发Echo服务器 |
| W4 | W4-G2 | 完成HTTP/1.1客户端 |
| W4 | W4-G3 | 理解性能调优基础 |

### 前置知识

- **Month 21 C++20协程基础**（必需）
  - Task<T> 异步任务封装
  - Awaitable三件套：await_ready/await_suspend/await_resume
  - 对称转移避免栈溢出
  - Generator 和 AsyncGenerator
  - Channel 并发原语

- **Month 19 线程池设计**（推荐）
  - 理解异步执行模型
  - 任务调度基础

- **系统编程基础**（必需）
  - POSIX Socket API（socket/bind/listen/accept/connect）
  - 文件描述符概念
  - 阻塞与非阻塞I/O

### 与Month-21的衔接

```cpp
// Month-21 我们实现了这些核心组件：
#include "task.hpp"       // Task<T> 异步任务
#include "generator.hpp"  // Generator<T> 同步生成器
#include "awaitable.hpp"  // Awaitable 工具

// Month-22 我们将扩展这些组件：
#include "event_loop.hpp"     // 事件循环（扩展Month-21的简单调度器）
#include "io_awaitable.hpp"   // I/O Awaitable（新增）
#include "async_socket.hpp"   // 异步Socket（新增）

// Month-21的Task将与真实I/O结合：
Task<std::string> fetch_data(const std::string& url) {
    // Month-21: 模拟异步
    co_await some_delay();
    co_return "mock data";
}

// Month-22: 真实网络I/O
Task<std::string> fetch_data(const std::string& host, const std::string& path) {
    AsyncTcpSocket socket;
    co_await socket.connect(host, 80);
    co_await socket.write("GET " + path + " HTTP/1.1\r\n\r\n");
    auto response = co_await socket.read_all();
    co_return response;
}
```

---

## 第一周：事件循环设计（Day 1-7）

> **本周目标**：深入理解I/O多路复用机制，实现跨平台事件循环

### Day 1-2：I/O多路复用基础

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | I/O模型对比分析 | 2h |
| 下午 | epoll/kqueue原理详解 | 3h |
| 晚上 | 平台差异与抽象设计 | 2h |

#### 1. I/O模型演进

```cpp
// ============================================================
// I/O模型对比
// ============================================================

/*
┌─────────────────────────────────────────────────────────────────┐
│                       I/O模型演进                                │
├─────────────┬───────────────┬───────────────┬───────────────────┤
│   阻塞I/O   │   非阻塞I/O   │  I/O多路复用  │    异步I/O        │
│  Blocking   │ Non-blocking  │  Multiplexing │   Async I/O       │
├─────────────┼───────────────┼───────────────┼───────────────────┤
│             │               │               │                   │
│ 应用程序    │ 应用程序      │ 应用程序      │ 应用程序          │
│    ↓        │    ↓          │    ↓          │    ↓              │
│ read()      │ read()        │ epoll_wait()  │ io_uring_submit() │
│    ↓        │    ↓          │    ↓          │    ↓              │
│ [阻塞等待]  │ [立即返回     │ [阻塞等待    │ [立即返回]        │
│             │  EAGAIN]      │  任一fd就绪]  │                   │
│    ↓        │    ↓          │    ↓          │    ↓              │
│ 数据就绪    │ 轮询检查      │ 处理就绪fd   │ [内核异步处理]    │
│ 返回数据    │ 直到成功      │ read()/write()│    ↓              │
│             │               │               │ 通知完成          │
├─────────────┼───────────────┼───────────────┼───────────────────┤
│ 简单但低效  │ CPU浪费在轮询 │ 高效可扩展   │ 最高效但复杂      │
│ 1线程:1连接│ 需要sleep     │ 1线程:N连接  │ 零拷贝可能        │
└─────────────┴───────────────┴───────────────┴───────────────────┘
*/

// 阻塞I/O示例
void blocking_io_example(int fd) {
    char buffer[1024];
    // 线程在此阻塞，直到有数据可读
    ssize_t n = read(fd, buffer, sizeof(buffer));
    // 问题：如果没有数据，线程完全阻塞，无法做其他事
}

// 非阻塞I/O示例
void nonblocking_io_example(int fd) {
    // 设置非阻塞
    int flags = fcntl(fd, F_GETFL, 0);
    fcntl(fd, F_SETFL, flags | O_NONBLOCK);

    char buffer[1024];
    while (true) {
        ssize_t n = read(fd, buffer, sizeof(buffer));
        if (n > 0) {
            // 处理数据
            break;
        } else if (n < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK) {
                // 没有数据，稍后重试
                std::this_thread::sleep_for(std::chrono::milliseconds(1));
                continue;
            }
            // 真正的错误
            break;
        } else {
            // EOF
            break;
        }
    }
    // 问题：轮询浪费CPU，sleep又增加延迟
}

// I/O多路复用示例（本月重点）
void multiplexing_io_example(std::vector<int>& fds) {
    int epfd = epoll_create1(0);

    // 注册所有fd
    for (int fd : fds) {
        epoll_event ev{};
        ev.events = EPOLLIN;
        ev.data.fd = fd;
        epoll_ctl(epfd, EPOLL_CTL_ADD, fd, &ev);
    }

    std::vector<epoll_event> events(fds.size());

    while (true) {
        // 阻塞等待任意fd就绪
        int n = epoll_wait(epfd, events.data(), events.size(), -1);

        for (int i = 0; i < n; ++i) {
            int fd = events[i].data.fd;
            // 只处理就绪的fd
            char buffer[1024];
            read(fd, buffer, sizeof(buffer));
        }
    }
    // 优势：单线程高效处理多个连接
}
```

#### 2. epoll详解（Linux）

```cpp
// ============================================================
// Linux epoll API详解
// ============================================================

#include <sys/epoll.h>
#include <unistd.h>
#include <fcntl.h>

/*
epoll是Linux特有的I/O多路复用机制，相比select/poll有以下优势：
1. O(1)的事件通知（不需要遍历所有fd）
2. 支持边缘触发（Edge Triggered）
3. 没有fd数量限制
4. 使用mmap共享内核空间，减少拷贝

核心数据结构：
┌─────────────────────────────────────────────────────────────┐
│                    epoll实例（内核）                         │
├─────────────────────────────────────────────────────────────┤
│  红黑树（存储所有注册的fd）                                  │
│  ┌─────┐    ┌─────┐    ┌─────┐                             │
│  │fd=3 │────│fd=5 │────│fd=7 │                             │
│  └─────┘    └─────┘    └─────┘                             │
├─────────────────────────────────────────────────────────────┤
│  就绪链表（存储就绪的fd）                                    │
│  [fd=5] → [fd=7] → NULL                                     │
└─────────────────────────────────────────────────────────────┘
*/

// epoll_event结构
struct epoll_event {
    uint32_t events;    // 事件掩码
    epoll_data_t data;  // 用户数据
};

union epoll_data {
    void* ptr;      // 用户指针（常用）
    int fd;         // 文件描述符
    uint32_t u32;
    uint64_t u64;
};

// 事件类型
/*
EPOLLIN      - 可读（包括对端关闭连接）
EPOLLOUT     - 可写
EPOLLRDHUP   - 对端关闭连接或关闭写端（Linux 2.6.17+）
EPOLLPRI     - 紧急数据可读
EPOLLERR     - 错误（总是被监控，无需显式设置）
EPOLLHUP     - 挂起（总是被监控）
EPOLLET      - 边缘触发模式
EPOLLONESHOT - 单次触发，触发后需要重新注册
*/

class EpollExample {
    int epfd_ = -1;

public:
    EpollExample() {
        // 创建epoll实例
        // EPOLL_CLOEXEC: exec时自动关闭
        epfd_ = epoll_create1(EPOLL_CLOEXEC);
        if (epfd_ < 0) {
            throw std::runtime_error("epoll_create1 failed");
        }
    }

    ~EpollExample() {
        if (epfd_ >= 0) {
            close(epfd_);
        }
    }

    // 添加fd到epoll
    void add(int fd, uint32_t events, void* user_data) {
        epoll_event ev{};
        ev.events = events;
        ev.data.ptr = user_data;  // 存储用户数据

        if (epoll_ctl(epfd_, EPOLL_CTL_ADD, fd, &ev) < 0) {
            throw std::runtime_error("epoll_ctl ADD failed");
        }
    }

    // 修改fd的事件
    void modify(int fd, uint32_t events, void* user_data) {
        epoll_event ev{};
        ev.events = events;
        ev.data.ptr = user_data;

        if (epoll_ctl(epfd_, EPOLL_CTL_MOD, fd, &ev) < 0) {
            throw std::runtime_error("epoll_ctl MOD failed");
        }
    }

    // 从epoll移除fd
    void remove(int fd) {
        // Linux 2.6.9之后，ev参数可以为nullptr
        if (epoll_ctl(epfd_, EPOLL_CTL_DEL, fd, nullptr) < 0) {
            // ENOENT表示fd不在epoll中，通常可以忽略
            if (errno != ENOENT) {
                throw std::runtime_error("epoll_ctl DEL failed");
            }
        }
    }

    // 等待事件
    // timeout: -1=无限等待, 0=立即返回, >0=毫秒超时
    int wait(epoll_event* events, int max_events, int timeout_ms) {
        int n = epoll_wait(epfd_, events, max_events, timeout_ms);
        if (n < 0) {
            if (errno == EINTR) {
                return 0;  // 被信号中断，返回0个事件
            }
            throw std::runtime_error("epoll_wait failed");
        }
        return n;
    }
};

// 边缘触发(ET) vs 水平触发(LT)
/*
水平触发（Level Triggered）- 默认模式：
┌─────────────────────────────────────────────────────────────┐
│ 缓冲区状态：[████████░░░░] (有数据)                          │
│                                                              │
│ epoll_wait() → 返回EPOLLIN                                  │
│ read(100字节)                                                │
│ 缓冲区状态：[████░░░░░░░░] (还有数据)                        │
│                                                              │
│ epoll_wait() → 返回EPOLLIN  ← 只要有数据就一直通知           │
│ read(剩余)                                                   │
│ 缓冲区状态：[░░░░░░░░░░░░] (空)                              │
│                                                              │
│ epoll_wait() → 阻塞等待                                     │
└─────────────────────────────────────────────────────────────┘

边缘触发（Edge Triggered）- EPOLLET：
┌─────────────────────────────────────────────────────────────┐
│ 缓冲区状态：[░░░░░░░░░░░░] (空)                              │
│ 新数据到达                                                   │
│ 缓冲区状态：[████████░░░░] (有数据)                          │
│                                                              │
│ epoll_wait() → 返回EPOLLIN  ← 只在状态变化时通知一次         │
│ read(100字节)                                                │
│ 缓冲区状态：[████░░░░░░░░] (还有数据)                        │
│                                                              │
│ epoll_wait() → 阻塞！       ← 不会再通知！必须读完所有数据   │
│                                                              │
│ 正确做法：循环read直到EAGAIN                                 │
└─────────────────────────────────────────────────────────────┘

协程场景下的选择：
- LT模式更安全，不会丢失事件
- ET模式更高效，减少系统调用
- 本课程使用LT模式，因为协程天然会在EAGAIN时暂停
*/
```

#### 3. kqueue详解（macOS/BSD）

```cpp
// ============================================================
// macOS/BSD kqueue API详解
// ============================================================

#include <sys/event.h>
#include <sys/time.h>

/*
kqueue是BSD系统（包括macOS）的I/O多路复用机制
相比epoll，kqueue有一些不同的设计哲学：

1. 统一的事件模型：不仅支持I/O，还支持信号、定时器、进程等
2. 原子性的注册和等待：kevent()同时完成注册和等待
3. 更灵活的过滤器系统

核心数据结构：
┌─────────────────────────────────────────────────────────────┐
│                    kqueue实例（内核）                        │
├─────────────────────────────────────────────────────────────┤
│  过滤器类型：                                                │
│  EVFILT_READ   - 可读事件                                   │
│  EVFILT_WRITE  - 可写事件                                   │
│  EVFILT_TIMER  - 定时器事件                                 │
│  EVFILT_SIGNAL - 信号事件                                   │
│  EVFILT_PROC   - 进程事件                                   │
│  EVFILT_VNODE  - 文件系统事件                               │
└─────────────────────────────────────────────────────────────┘
*/

// kevent结构
struct kevent {
    uintptr_t ident;     // 标识符（fd、信号编号等）
    int16_t   filter;    // 过滤器类型
    uint16_t  flags;     // 操作标志
    uint32_t  fflags;    // 过滤器特定标志
    intptr_t  data;      // 过滤器特定数据
    void*     udata;     // 用户数据
};

// 操作标志
/*
EV_ADD     - 添加事件（如果存在则修改）
EV_DELETE  - 删除事件
EV_ENABLE  - 启用事件
EV_DISABLE - 禁用事件
EV_ONESHOT - 单次触发后自动删除
EV_CLEAR   - 类似边缘触发，返回后清除状态
EV_EOF     - EOF状态（由内核设置）
EV_ERROR   - 错误状态（由内核设置）
*/

class KqueueExample {
    int kq_ = -1;

public:
    KqueueExample() {
        kq_ = kqueue();
        if (kq_ < 0) {
            throw std::runtime_error("kqueue failed");
        }
    }

    ~KqueueExample() {
        if (kq_ >= 0) {
            close(kq_);
        }
    }

    // 添加读事件监控
    void add_read(int fd, void* user_data) {
        struct kevent ev;
        EV_SET(&ev, fd, EVFILT_READ, EV_ADD | EV_CLEAR, 0, 0, user_data);

        if (kevent(kq_, &ev, 1, nullptr, 0, nullptr) < 0) {
            throw std::runtime_error("kevent add read failed");
        }
    }

    // 添加写事件监控
    void add_write(int fd, void* user_data) {
        struct kevent ev;
        EV_SET(&ev, fd, EVFILT_WRITE, EV_ADD | EV_CLEAR, 0, 0, user_data);

        if (kevent(kq_, &ev, 1, nullptr, 0, nullptr) < 0) {
            throw std::runtime_error("kevent add write failed");
        }
    }

    // 删除事件监控
    void remove(int fd, int16_t filter) {
        struct kevent ev;
        EV_SET(&ev, fd, filter, EV_DELETE, 0, 0, nullptr);

        // 删除可能失败（如果已经被删除），通常忽略错误
        kevent(kq_, &ev, 1, nullptr, 0, nullptr);
    }

    // 等待事件
    int wait(struct kevent* events, int max_events,
             const struct timespec* timeout) {
        int n = kevent(kq_, nullptr, 0, events, max_events, timeout);
        if (n < 0) {
            if (errno == EINTR) {
                return 0;
            }
            throw std::runtime_error("kevent wait failed");
        }
        return n;
    }

    // 批量操作（kqueue的优势）
    void batch_modify(struct kevent* changes, int nchanges,
                      struct kevent* events, int nevents,
                      const struct timespec* timeout) {
        // 可以同时注册多个事件并等待
        int n = kevent(kq_, changes, nchanges, events, nevents, timeout);
        // ...
    }
};

// EV_SET宏的使用
/*
EV_SET(kev, ident, filter, flags, fflags, data, udata)

示例：
struct kevent ev;

// 添加可读事件
EV_SET(&ev, fd, EVFILT_READ, EV_ADD, 0, 0, user_data);

// 添加可写事件，单次触发
EV_SET(&ev, fd, EVFILT_WRITE, EV_ADD | EV_ONESHOT, 0, 0, user_data);

// 添加定时器（1000毫秒）
EV_SET(&ev, timer_id, EVFILT_TIMER, EV_ADD, 0, 1000, user_data);

// 删除事件
EV_SET(&ev, fd, EVFILT_READ, EV_DELETE, 0, 0, nullptr);
*/
```

#### 4. 跨平台抽象接口设计

```cpp
// ============================================================
// io_multiplexer.hpp - 跨平台I/O多路复用抽象
// ============================================================

#pragma once

#include <chrono>
#include <cstdint>
#include <vector>
#include <functional>

// I/O事件类型
enum class IoEvent : uint32_t {
    None  = 0,
    Read  = 1 << 0,  // 可读
    Write = 1 << 1,  // 可写
    Error = 1 << 2,  // 错误
    Hangup = 1 << 3, // 挂起
};

// 支持位运算
inline IoEvent operator|(IoEvent a, IoEvent b) {
    return static_cast<IoEvent>(
        static_cast<uint32_t>(a) | static_cast<uint32_t>(b));
}

inline IoEvent operator&(IoEvent a, IoEvent b) {
    return static_cast<IoEvent>(
        static_cast<uint32_t>(a) & static_cast<uint32_t>(b));
}

inline bool has_event(IoEvent events, IoEvent check) {
    return (events & check) != IoEvent::None;
}

// I/O事件结果
struct IoEventResult {
    int fd;              // 文件描述符
    IoEvent events;      // 触发的事件
    void* user_data;     // 用户数据
};

// I/O多路复用器抽象接口
class IoMultiplexer {
public:
    virtual ~IoMultiplexer() = default;

    // 添加fd监控
    virtual void add(int fd, IoEvent events, void* user_data) = 0;

    // 修改fd监控的事件
    virtual void modify(int fd, IoEvent events, void* user_data) = 0;

    // 移除fd监控
    virtual void remove(int fd) = 0;

    // 等待事件
    // 返回：就绪事件数量
    virtual int wait(std::vector<IoEventResult>& results,
                     std::chrono::milliseconds timeout) = 0;

    // 工厂方法：创建平台相关的实现
    static std::unique_ptr<IoMultiplexer> create();
};

// 平台检测和条件编译
#if defined(__linux__)
    #define CORO_USE_EPOLL 1
#elif defined(__APPLE__) || defined(__FreeBSD__) || defined(__OpenBSD__)
    #define CORO_USE_KQUEUE 1
#elif defined(_WIN32)
    #define CORO_USE_IOCP 1
    #error "Windows IOCP not implemented in this course"
#else
    #error "Unsupported platform"
#endif
```

### Day 3-4：事件循环核心实现

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | EventLoop架构设计 | 2h |
| 下午 | 协程调度集成 | 3h |
| 晚上 | 定时器队列实现 | 2h |

#### 1. 事件循环架构

```cpp
// ============================================================
// event_loop.hpp - 事件循环核心
// ============================================================

#pragma once

#include "io_multiplexer.hpp"
#include <coroutine>
#include <queue>
#include <chrono>
#include <optional>
#include <functional>
#include <memory>
#include <atomic>

// 定时器条目
struct TimerEntry {
    using TimePoint = std::chrono::steady_clock::time_point;

    TimePoint deadline;              // 触发时间
    std::coroutine_handle<> handle;  // 协程句柄
    uint64_t id;                     // 定时器ID（用于取消）
    bool cancelled = false;          // 是否已取消

    // 最小堆比较：最早的在顶部
    bool operator>(const TimerEntry& other) const {
        return deadline > other.deadline;
    }
};

// 定时器队列
class TimerQueue {
public:
    using TimePoint = std::chrono::steady_clock::time_point;
    using Duration = std::chrono::steady_clock::duration;

private:
    std::priority_queue<TimerEntry,
                        std::vector<TimerEntry>,
                        std::greater<TimerEntry>> heap_;
    uint64_t next_id_ = 1;

public:
    // 添加定时器
    uint64_t add(TimePoint deadline, std::coroutine_handle<> handle) {
        uint64_t id = next_id_++;
        heap_.push({deadline, handle, id, false});
        return id;
    }

    // 添加延迟定时器
    uint64_t add_delay(Duration delay, std::coroutine_handle<> handle) {
        return add(std::chrono::steady_clock::now() + delay, handle);
    }

    // 取消定时器（懒删除）
    void cancel(uint64_t id) {
        // 注意：实际实现需要一个id->entry的映射
        // 这里简化为在pop时检查cancelled标志
    }

    // 获取最近的截止时间
    std::optional<TimePoint> next_deadline() const {
        while (!heap_.empty()) {
            const auto& top = heap_.top();
            if (!top.cancelled) {
                return top.deadline;
            }
            // 跳过已取消的
        }
        return std::nullopt;
    }

    // 弹出所有已到期的定时器
    std::vector<std::coroutine_handle<>> pop_ready() {
        std::vector<std::coroutine_handle<>> ready;
        auto now = std::chrono::steady_clock::now();

        while (!heap_.empty()) {
            const auto& top = heap_.top();

            if (top.deadline > now) {
                break;  // 还没到时间
            }

            if (!top.cancelled) {
                ready.push_back(top.handle);
            }

            heap_.pop();
        }

        return ready;
    }

    bool empty() const { return heap_.empty(); }
};

// I/O等待条目
struct IoWaitEntry {
    int fd;
    IoEvent events;
    std::coroutine_handle<> handle;
};

// 事件循环
class EventLoop {
public:
    using Duration = std::chrono::steady_clock::duration;
    using TimePoint = std::chrono::steady_clock::time_point;

private:
    // I/O多路复用器
    std::unique_ptr<IoMultiplexer> multiplexer_;

    // 就绪协程队列
    std::queue<std::coroutine_handle<>> ready_queue_;

    // 定时器队列
    TimerQueue timer_queue_;

    // I/O等待映射：fd -> 等待条目
    std::unordered_map<int, IoWaitEntry> io_waiters_;

    // 运行状态
    std::atomic<bool> running_{false};
    std::atomic<bool> stop_requested_{false};

    // 线程局部当前EventLoop
    static thread_local EventLoop* current_;

public:
    EventLoop() : multiplexer_(IoMultiplexer::create()) {}

    ~EventLoop() {
        if (current_ == this) {
            current_ = nullptr;
        }
    }

    // 禁止拷贝和移动
    EventLoop(const EventLoop&) = delete;
    EventLoop& operator=(const EventLoop&) = delete;

    // 获取当前线程的EventLoop
    static EventLoop* current() { return current_; }

    // ========== 调度接口 ==========

    // 调度协程立即执行
    void schedule(std::coroutine_handle<> handle) {
        ready_queue_.push(handle);
    }

    // 调度协程在I/O就绪时执行
    void schedule_io(int fd, IoEvent events, std::coroutine_handle<> handle) {
        io_waiters_[fd] = {fd, events, handle};
        multiplexer_->add(fd, events, &io_waiters_[fd]);
    }

    // 移除I/O等待
    void cancel_io(int fd) {
        multiplexer_->remove(fd);
        io_waiters_.erase(fd);
    }

    // 调度协程在指定延迟后执行
    uint64_t schedule_timer(Duration delay, std::coroutine_handle<> handle) {
        return timer_queue_.add_delay(delay, handle);
    }

    // 调度协程在指定时间点执行
    uint64_t schedule_at(TimePoint time, std::coroutine_handle<> handle) {
        return timer_queue_.add(time, handle);
    }

    // 取消定时器
    void cancel_timer(uint64_t id) {
        timer_queue_.cancel(id);
    }

    // ========== 运行控制 ==========

    // 运行事件循环
    void run();

    // 运行一次循环迭代
    bool run_once();

    // 请求停止
    void stop() {
        stop_requested_ = true;
    }

    // 是否正在运行
    bool is_running() const { return running_; }

private:
    // 计算等待超时
    std::chrono::milliseconds calculate_timeout();

    // 处理I/O事件
    void process_io_events();

    // 处理定时器
    void process_timers();

    // 处理就绪队列
    void process_ready_queue();
};

// 静态成员定义
thread_local EventLoop* EventLoop::current_ = nullptr;
```

#### 2. 事件循环主循环实现

```cpp
// ============================================================
// event_loop.cpp - 事件循环实现
// ============================================================

#include "event_loop.hpp"
#include <algorithm>

void EventLoop::run() {
    if (running_.exchange(true)) {
        throw std::runtime_error("EventLoop already running");
    }

    current_ = this;
    stop_requested_ = false;

    while (!stop_requested_) {
        run_once();
    }

    running_ = false;
}

bool EventLoop::run_once() {
    // 1. 处理就绪队列中的所有协程
    process_ready_queue();

    // 2. 检查是否还有待处理的任务
    bool has_pending = !ready_queue_.empty() ||
                       !io_waiters_.empty() ||
                       !timer_queue_.empty();

    if (!has_pending) {
        return false;  // 没有任务了
    }

    // 3. 计算等待超时
    auto timeout = calculate_timeout();

    // 4. 等待I/O事件
    process_io_events();

    // 5. 处理到期的定时器
    process_timers();

    return true;
}

std::chrono::milliseconds EventLoop::calculate_timeout() {
    // 如果就绪队列非空，不等待
    if (!ready_queue_.empty()) {
        return std::chrono::milliseconds(0);
    }

    // 获取最近的定时器截止时间
    auto next = timer_queue_.next_deadline();
    if (!next) {
        // 没有定时器，无限等待I/O
        return std::chrono::milliseconds(-1);
    }

    auto now = std::chrono::steady_clock::now();
    if (*next <= now) {
        // 定时器已到期
        return std::chrono::milliseconds(0);
    }

    // 计算剩余时间
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(
        *next - now);

    return duration;
}

void EventLoop::process_io_events() {
    if (io_waiters_.empty()) {
        return;
    }

    std::vector<IoEventResult> events;
    events.reserve(io_waiters_.size());

    auto timeout = calculate_timeout();
    int n = multiplexer_->wait(events, timeout);

    for (int i = 0; i < n; ++i) {
        const auto& event = events[i];
        auto* entry = static_cast<IoWaitEntry*>(event.user_data);

        // 从多路复用器中移除（一次性触发）
        multiplexer_->remove(entry->fd);

        // 加入就绪队列
        ready_queue_.push(entry->handle);

        // 从等待映射中移除
        io_waiters_.erase(entry->fd);
    }
}

void EventLoop::process_timers() {
    auto ready = timer_queue_.pop_ready();
    for (auto handle : ready) {
        ready_queue_.push(handle);
    }
}

void EventLoop::process_ready_queue() {
    // 处理当前队列中的所有协程
    // 注意：处理过程中可能会有新协程入队
    size_t count = ready_queue_.size();

    for (size_t i = 0; i < count; ++i) {
        auto handle = ready_queue_.front();
        ready_queue_.pop();

        if (handle && !handle.done()) {
            handle.resume();
        }
    }
}
```

#### 3. EventLoop辅助Awaitable

```cpp
// ============================================================
// 事件循环辅助Awaitable
// ============================================================

// 暂停当前协程，让其他协程运行
struct YieldAwaiter {
    bool await_ready() const noexcept { return false; }

    void await_suspend(std::coroutine_handle<> h) const {
        // 重新调度自己
        EventLoop::current()->schedule(h);
    }

    void await_resume() const noexcept {}
};

inline YieldAwaiter yield() { return {}; }

// 延迟执行
struct SleepAwaiter {
    std::chrono::milliseconds duration;

    bool await_ready() const noexcept {
        return duration.count() <= 0;
    }

    void await_suspend(std::coroutine_handle<> h) const {
        EventLoop::current()->schedule_timer(duration, h);
    }

    void await_resume() const noexcept {}
};

inline SleepAwaiter sleep_for(std::chrono::milliseconds ms) {
    return SleepAwaiter{ms};
}

template<typename Rep, typename Period>
inline SleepAwaiter sleep_for(std::chrono::duration<Rep, Period> duration) {
    return SleepAwaiter{
        std::chrono::duration_cast<std::chrono::milliseconds>(duration)
    };
}

// 在指定时间点执行
struct SleepUntilAwaiter {
    std::chrono::steady_clock::time_point time_point;

    bool await_ready() const noexcept {
        return std::chrono::steady_clock::now() >= time_point;
    }

    void await_suspend(std::coroutine_handle<> h) const {
        EventLoop::current()->schedule_at(time_point, h);
    }

    void await_resume() const noexcept {}
};

inline SleepUntilAwaiter sleep_until(
    std::chrono::steady_clock::time_point tp) {
    return SleepUntilAwaiter{tp};
}

// 使用示例
/*
Task<void> example() {
    std::cout << "Start\n";

    co_await sleep_for(std::chrono::seconds(1));
    std::cout << "After 1 second\n";

    co_await yield();  // 让其他协程运行
    std::cout << "After yield\n";
}
*/
```

### Day 5-6：跨平台实现

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | epoll实现 | 2h |
| 下午 | kqueue实现 | 3h |
| 晚上 | 测试与调试 | 2h |

#### 1. EpollMultiplexer实现

```cpp
// ============================================================
// epoll_multiplexer.hpp - Linux epoll实现
// ============================================================

#pragma once

#ifdef CORO_USE_EPOLL

#include "io_multiplexer.hpp"
#include <sys/epoll.h>
#include <unistd.h>
#include <stdexcept>

class EpollMultiplexer : public IoMultiplexer {
private:
    int epfd_ = -1;
    std::vector<epoll_event> events_;

public:
    explicit EpollMultiplexer(size_t max_events = 1024)
        : events_(max_events) {
        epfd_ = epoll_create1(EPOLL_CLOEXEC);
        if (epfd_ < 0) {
            throw std::runtime_error("epoll_create1 failed: " +
                                     std::string(strerror(errno)));
        }
    }

    ~EpollMultiplexer() override {
        if (epfd_ >= 0) {
            close(epfd_);
        }
    }

    // 禁止拷贝
    EpollMultiplexer(const EpollMultiplexer&) = delete;
    EpollMultiplexer& operator=(const EpollMultiplexer&) = delete;

    void add(int fd, IoEvent events, void* user_data) override {
        epoll_event ev{};
        ev.events = to_epoll_events(events);
        ev.data.ptr = user_data;

        if (epoll_ctl(epfd_, EPOLL_CTL_ADD, fd, &ev) < 0) {
            if (errno == EEXIST) {
                // 已存在，尝试修改
                modify(fd, events, user_data);
                return;
            }
            throw std::runtime_error("epoll_ctl ADD failed: " +
                                     std::string(strerror(errno)));
        }
    }

    void modify(int fd, IoEvent events, void* user_data) override {
        epoll_event ev{};
        ev.events = to_epoll_events(events);
        ev.data.ptr = user_data;

        if (epoll_ctl(epfd_, EPOLL_CTL_MOD, fd, &ev) < 0) {
            throw std::runtime_error("epoll_ctl MOD failed: " +
                                     std::string(strerror(errno)));
        }
    }

    void remove(int fd) override {
        if (epoll_ctl(epfd_, EPOLL_CTL_DEL, fd, nullptr) < 0) {
            if (errno != ENOENT && errno != EBADF) {
                throw std::runtime_error("epoll_ctl DEL failed: " +
                                         std::string(strerror(errno)));
            }
        }
    }

    int wait(std::vector<IoEventResult>& results,
             std::chrono::milliseconds timeout) override {
        int timeout_ms = timeout.count() < 0 ? -1 :
                         static_cast<int>(timeout.count());

        int n = epoll_wait(epfd_, events_.data(),
                           static_cast<int>(events_.size()),
                           timeout_ms);

        if (n < 0) {
            if (errno == EINTR) {
                return 0;
            }
            throw std::runtime_error("epoll_wait failed: " +
                                     std::string(strerror(errno)));
        }

        results.clear();
        results.reserve(n);

        for (int i = 0; i < n; ++i) {
            results.push_back({
                -1,  // fd不重要，我们用user_data
                from_epoll_events(events_[i].events),
                events_[i].data.ptr
            });
        }

        return n;
    }

private:
    static uint32_t to_epoll_events(IoEvent events) {
        uint32_t result = 0;
        if (has_event(events, IoEvent::Read)) {
            result |= EPOLLIN;
        }
        if (has_event(events, IoEvent::Write)) {
            result |= EPOLLOUT;
        }
        return result;
    }

    static IoEvent from_epoll_events(uint32_t events) {
        IoEvent result = IoEvent::None;
        if (events & EPOLLIN) {
            result = result | IoEvent::Read;
        }
        if (events & EPOLLOUT) {
            result = result | IoEvent::Write;
        }
        if (events & EPOLLERR) {
            result = result | IoEvent::Error;
        }
        if (events & EPOLLHUP) {
            result = result | IoEvent::Hangup;
        }
        return result;
    }
};

#endif // CORO_USE_EPOLL
```

#### 2. KqueueMultiplexer实现

```cpp
// ============================================================
// kqueue_multiplexer.hpp - macOS/BSD kqueue实现
// ============================================================

#pragma once

#ifdef CORO_USE_KQUEUE

#include "io_multiplexer.hpp"
#include <sys/event.h>
#include <sys/time.h>
#include <unistd.h>
#include <stdexcept>

class KqueueMultiplexer : public IoMultiplexer {
private:
    int kq_ = -1;
    std::vector<struct kevent> events_;
    std::vector<struct kevent> changes_;

public:
    explicit KqueueMultiplexer(size_t max_events = 1024)
        : events_(max_events) {
        kq_ = kqueue();
        if (kq_ < 0) {
            throw std::runtime_error("kqueue failed: " +
                                     std::string(strerror(errno)));
        }
    }

    ~KqueueMultiplexer() override {
        if (kq_ >= 0) {
            close(kq_);
        }
    }

    // 禁止拷贝
    KqueueMultiplexer(const KqueueMultiplexer&) = delete;
    KqueueMultiplexer& operator=(const KqueueMultiplexer&) = delete;

    void add(int fd, IoEvent events, void* user_data) override {
        if (has_event(events, IoEvent::Read)) {
            struct kevent ev;
            EV_SET(&ev, fd, EVFILT_READ, EV_ADD | EV_CLEAR, 0, 0, user_data);
            apply_change(ev);
        }
        if (has_event(events, IoEvent::Write)) {
            struct kevent ev;
            EV_SET(&ev, fd, EVFILT_WRITE, EV_ADD | EV_CLEAR, 0, 0, user_data);
            apply_change(ev);
        }
    }

    void modify(int fd, IoEvent events, void* user_data) override {
        // kqueue中，EV_ADD会自动更新已存在的事件
        add(fd, events, user_data);
    }

    void remove(int fd) override {
        struct kevent ev;

        // 删除读事件
        EV_SET(&ev, fd, EVFILT_READ, EV_DELETE, 0, 0, nullptr);
        kevent(kq_, &ev, 1, nullptr, 0, nullptr);  // 忽略错误

        // 删除写事件
        EV_SET(&ev, fd, EVFILT_WRITE, EV_DELETE, 0, 0, nullptr);
        kevent(kq_, &ev, 1, nullptr, 0, nullptr);  // 忽略错误
    }

    int wait(std::vector<IoEventResult>& results,
             std::chrono::milliseconds timeout) override {
        struct timespec ts;
        struct timespec* ts_ptr = nullptr;

        if (timeout.count() >= 0) {
            ts.tv_sec = timeout.count() / 1000;
            ts.tv_nsec = (timeout.count() % 1000) * 1000000;
            ts_ptr = &ts;
        }

        int n = kevent(kq_, nullptr, 0, events_.data(),
                       static_cast<int>(events_.size()), ts_ptr);

        if (n < 0) {
            if (errno == EINTR) {
                return 0;
            }
            throw std::runtime_error("kevent wait failed: " +
                                     std::string(strerror(errno)));
        }

        results.clear();
        results.reserve(n);

        for (int i = 0; i < n; ++i) {
            const auto& ev = events_[i];

            IoEvent io_events = IoEvent::None;
            if (ev.filter == EVFILT_READ) {
                io_events = io_events | IoEvent::Read;
            }
            if (ev.filter == EVFILT_WRITE) {
                io_events = io_events | IoEvent::Write;
            }
            if (ev.flags & EV_EOF) {
                io_events = io_events | IoEvent::Hangup;
            }
            if (ev.flags & EV_ERROR) {
                io_events = io_events | IoEvent::Error;
            }

            results.push_back({
                static_cast<int>(ev.ident),
                io_events,
                ev.udata
            });
        }

        return n;
    }

private:
    void apply_change(struct kevent& ev) {
        if (kevent(kq_, &ev, 1, nullptr, 0, nullptr) < 0) {
            throw std::runtime_error("kevent change failed: " +
                                     std::string(strerror(errno)));
        }
    }
};

#endif // CORO_USE_KQUEUE
```

#### 3. 工厂方法实现

```cpp
// ============================================================
// io_multiplexer.cpp - 工厂方法
// ============================================================

#include "io_multiplexer.hpp"

#ifdef CORO_USE_EPOLL
#include "epoll_multiplexer.hpp"
#endif

#ifdef CORO_USE_KQUEUE
#include "kqueue_multiplexer.hpp"
#endif

std::unique_ptr<IoMultiplexer> IoMultiplexer::create() {
#ifdef CORO_USE_EPOLL
    return std::make_unique<EpollMultiplexer>();
#elif defined(CORO_USE_KQUEUE)
    return std::make_unique<KqueueMultiplexer>();
#else
    #error "No I/O multiplexer implementation available"
#endif
}
```

### Day 7：第一周总结与测试

#### 测试代码

```cpp
// ============================================================
// test_event_loop.cpp - 事件循环测试
// ============================================================

#include "event_loop.hpp"
#include "task.hpp"
#include <iostream>
#include <cassert>

// 测试1：基本定时器
Task<void> test_timer() {
    std::cout << "Timer test start\n";

    auto start = std::chrono::steady_clock::now();
    co_await sleep_for(std::chrono::milliseconds(100));
    auto end = std::chrono::steady_clock::now();

    auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
        end - start).count();

    std::cout << "Elapsed: " << elapsed << "ms\n";
    assert(elapsed >= 100 && elapsed < 150);

    std::cout << "Timer test passed\n";
}

// 测试2：多个协程并发
Task<void> delay_print(int id, int ms) {
    co_await sleep_for(std::chrono::milliseconds(ms));
    std::cout << "Task " << id << " completed after " << ms << "ms\n";
}

Task<void> test_concurrent() {
    std::cout << "Concurrent test start\n";

    // 启动多个协程
    auto t1 = delay_print(1, 100);
    auto t2 = delay_print(2, 50);
    auto t3 = delay_print(3, 150);

    // 等待所有完成
    co_await t1;
    co_await t2;
    co_await t3;

    std::cout << "Concurrent test passed\n";
}

// 测试3：yield
Task<void> test_yield() {
    std::cout << "Yield test start\n";

    for (int i = 0; i < 3; ++i) {
        std::cout << "Iteration " << i << "\n";
        co_await yield();
    }

    std::cout << "Yield test passed\n";
}

// 运行测试
void run_tests() {
    EventLoop loop;

    // 启动测试协程
    loop.schedule([&]() -> DetachedTask {
        co_await test_timer();
        co_await test_concurrent();
        co_await test_yield();

        loop.stop();
    }().handle);

    loop.run();

    std::cout << "All tests passed!\n";
}

int main() {
    run_tests();
    return 0;
}
```

#### 第一周检验标准

- [ ] 理解阻塞I/O、非阻塞I/O、I/O多路复用的区别
- [ ] 能解释epoll的工作原理（红黑树+就绪链表）
- [ ] 能解释kqueue的工作原理（过滤器系统）
- [ ] 理解ET与LT模式的区别及适用场景
- [ ] 实现跨平台I/O多路复用抽象（IoMultiplexer）
- [ ] 实现完整的EventLoop（定时器+I/O+协程调度）
- [ ] 通过所有单元测试

---

## 第二周：异步I/O封装（Day 8-14）

> **本周目标**：将系统I/O调用封装为Awaitable，实现超时和取消机制

### Day 8-9：基础Awaitable设计

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | I/O Awaitable接口设计 | 2h |
| 下午 | 与EventLoop集成 | 3h |
| 晚上 | 错误处理设计 | 2h |

#### 1. I/O Awaitable基础

```cpp
// ============================================================
// io_awaitable.hpp - I/O Awaitable基础
// ============================================================

#pragma once

#include "event_loop.hpp"
#include <coroutine>
#include <cerrno>
#include <cstring>
#include <unistd.h>
#include <fcntl.h>

// 设置文件描述符为非阻塞
inline void set_nonblocking(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags < 0) {
        throw std::runtime_error("fcntl F_GETFL failed");
    }
    if (fcntl(fd, F_SETFL, flags | O_NONBLOCK) < 0) {
        throw std::runtime_error("fcntl F_SETFL failed");
    }
}

// I/O错误类
class IoError : public std::exception {
private:
    int errno_;
    std::string message_;

public:
    explicit IoError(int err) : errno_(err) {
        message_ = "I/O error: " + std::string(strerror(err)) +
                   " (errno=" + std::to_string(err) + ")";
    }

    const char* what() const noexcept override {
        return message_.c_str();
    }

    int error_code() const noexcept { return errno_; }

    bool is_would_block() const noexcept {
        return errno_ == EAGAIN || errno_ == EWOULDBLOCK;
    }

    bool is_connection_reset() const noexcept {
        return errno_ == ECONNRESET;
    }

    bool is_connection_refused() const noexcept {
        return errno_ == ECONNREFUSED;
    }

    bool is_broken_pipe() const noexcept {
        return errno_ == EPIPE;
    }
};

// I/O结果类型（类似Rust的Result）
template<typename T>
class IoResult {
private:
    std::variant<T, IoError> data_;

public:
    // 成功构造
    IoResult(T value) : data_(std::move(value)) {}

    // 错误构造
    IoResult(IoError error) : data_(std::move(error)) {}

    // 从errno构造错误
    static IoResult from_errno() {
        return IoResult(IoError(errno));
    }

    bool is_ok() const { return std::holds_alternative<T>(data_); }
    bool is_err() const { return std::holds_alternative<IoError>(data_); }

    T& value() & {
        if (is_err()) throw error();
        return std::get<T>(data_);
    }

    T&& value() && {
        if (is_err()) throw error();
        return std::move(std::get<T>(data_));
    }

    const T& value() const& {
        if (is_err()) throw error();
        return std::get<T>(data_);
    }

    IoError& error() & {
        return std::get<IoError>(data_);
    }

    const IoError& error() const& {
        return std::get<IoError>(data_);
    }

    // 解包：成功返回值，失败抛出异常
    T unwrap() && {
        if (is_err()) {
            throw std::move(error());
        }
        return std::move(std::get<T>(data_));
    }

    // 带默认值解包
    T unwrap_or(T default_value) && {
        if (is_err()) {
            return std::move(default_value);
        }
        return std::move(std::get<T>(data_));
    }

    // map操作
    template<typename F>
    auto map(F&& f) && -> IoResult<decltype(f(std::declval<T>()))> {
        using U = decltype(f(std::declval<T>()));
        if (is_err()) {
            return IoResult<U>(std::move(error()));
        }
        return IoResult<U>(f(std::move(value())));
    }
};

// void特化
template<>
class IoResult<void> {
private:
    std::optional<IoError> error_;

public:
    IoResult() = default;
    IoResult(IoError error) : error_(std::move(error)) {}

    static IoResult from_errno() {
        return IoResult(IoError(errno));
    }

    bool is_ok() const { return !error_.has_value(); }
    bool is_err() const { return error_.has_value(); }

    IoError& error() { return *error_; }
    const IoError& error() const { return *error_; }

    void unwrap() {
        if (is_err()) {
            throw *error_;
        }
    }
};
```

#### 2. AsyncRead Awaitable

```cpp
// ============================================================
// AsyncRead - 异步读取Awaitable
// ============================================================

class AsyncRead {
private:
    int fd_;
    char* buffer_;
    size_t size_;
    ssize_t result_ = -1;
    int saved_errno_ = 0;

public:
    AsyncRead(int fd, char* buffer, size_t size)
        : fd_(fd), buffer_(buffer), size_(size) {}

    bool await_ready() noexcept {
        // 先尝试非阻塞读取
        result_ = ::read(fd_, buffer_, size_);
        if (result_ >= 0) {
            return true;  // 立即成功
        }
        if (errno != EAGAIN && errno != EWOULDBLOCK) {
            saved_errno_ = errno;
            return true;  // 立即失败（非EAGAIN错误）
        }
        // EAGAIN：需要等待
        return false;
    }

    void await_suspend(std::coroutine_handle<> h) {
        // 注册到事件循环，等待可读
        EventLoop::current()->schedule_io(fd_, IoEvent::Read, h);
    }

    IoResult<ssize_t> await_resume() {
        if (result_ >= 0) {
            return IoResult<ssize_t>(result_);
        }

        if (saved_errno_ != 0) {
            return IoResult<ssize_t>::from_errno();
        }

        // 在await_suspend之后被唤醒，执行实际读取
        result_ = ::read(fd_, buffer_, size_);
        if (result_ < 0) {
            return IoResult<ssize_t>(IoError(errno));
        }
        return IoResult<ssize_t>(result_);
    }
};

// 便捷函数
inline AsyncRead async_read(int fd, char* buffer, size_t size) {
    return AsyncRead(fd, buffer, size);
}

inline AsyncRead async_read(int fd, std::span<char> buffer) {
    return AsyncRead(fd, buffer.data(), buffer.size());
}
```

#### 3. AsyncWrite Awaitable

```cpp
// ============================================================
// AsyncWrite - 异步写入Awaitable
// ============================================================

class AsyncWrite {
private:
    int fd_;
    const char* buffer_;
    size_t size_;
    ssize_t result_ = -1;
    int saved_errno_ = 0;

public:
    AsyncWrite(int fd, const char* buffer, size_t size)
        : fd_(fd), buffer_(buffer), size_(size) {}

    bool await_ready() noexcept {
        // 先尝试非阻塞写入
        result_ = ::write(fd_, buffer_, size_);
        if (result_ >= 0) {
            return true;
        }
        if (errno != EAGAIN && errno != EWOULDBLOCK) {
            saved_errno_ = errno;
            return true;
        }
        return false;
    }

    void await_suspend(std::coroutine_handle<> h) {
        EventLoop::current()->schedule_io(fd_, IoEvent::Write, h);
    }

    IoResult<ssize_t> await_resume() {
        if (result_ >= 0) {
            return IoResult<ssize_t>(result_);
        }

        if (saved_errno_ != 0) {
            return IoResult<ssize_t>(IoError(saved_errno_));
        }

        result_ = ::write(fd_, buffer_, size_);
        if (result_ < 0) {
            return IoResult<ssize_t>(IoError(errno));
        }
        return IoResult<ssize_t>(result_);
    }
};

// 便捷函数
inline AsyncWrite async_write(int fd, const char* buffer, size_t size) {
    return AsyncWrite(fd, buffer, size);
}

inline AsyncWrite async_write(int fd, std::span<const char> buffer) {
    return AsyncWrite(fd, buffer.data(), buffer.size());
}

inline AsyncWrite async_write(int fd, std::string_view str) {
    return AsyncWrite(fd, str.data(), str.size());
}
```

### Day 10-11：完整读写操作

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | 完整读取实现 | 2h |
| 下午 | 完整写入实现 | 3h |
| 晚上 | 边界情况处理 | 2h |

#### 1. 完整读取（处理部分读取）

```cpp
// ============================================================
// 完整读取操作
// ============================================================

// 读取精确字节数
Task<IoResult<size_t>> async_read_exact(int fd, char* buffer, size_t size) {
    size_t total = 0;

    while (total < size) {
        auto result = co_await async_read(fd, buffer + total, size - total);

        if (result.is_err()) {
            // EAGAIN在async_read内部已处理，这里是真正的错误
            co_return IoResult<size_t>(result.error());
        }

        ssize_t n = result.value();
        if (n == 0) {
            // EOF：连接关闭
            if (total == 0) {
                co_return IoResult<size_t>(0);  // 没读到任何数据
            }
            // 部分读取后遇到EOF
            co_return IoResult<size_t>(IoError(EIO));
        }

        total += static_cast<size_t>(n);
    }

    co_return IoResult<size_t>(total);
}

// 读取所有可用数据（直到EOF或错误）
Task<IoResult<std::vector<char>>> async_read_all(int fd) {
    std::vector<char> result;
    char buffer[4096];

    while (true) {
        auto read_result = co_await async_read(fd, buffer, sizeof(buffer));

        if (read_result.is_err()) {
            co_return IoResult<std::vector<char>>(read_result.error());
        }

        ssize_t n = read_result.value();
        if (n == 0) {
            break;  // EOF
        }

        result.insert(result.end(), buffer, buffer + n);
    }

    co_return IoResult<std::vector<char>>(std::move(result));
}

// 读取到指定分隔符（如读取一行）
Task<IoResult<std::string>> async_read_until(int fd, char delimiter,
                                              size_t max_size = 65536) {
    std::string result;
    char ch;

    while (result.size() < max_size) {
        auto read_result = co_await async_read(fd, &ch, 1);

        if (read_result.is_err()) {
            co_return IoResult<std::string>(read_result.error());
        }

        if (read_result.value() == 0) {
            // EOF
            if (result.empty()) {
                co_return IoResult<std::string>(std::string{});
            }
            break;
        }

        result += ch;

        if (ch == delimiter) {
            break;
        }
    }

    co_return IoResult<std::string>(std::move(result));
}

// 读取一行（以\n结尾）
Task<IoResult<std::string>> async_read_line(int fd, size_t max_size = 65536) {
    return async_read_until(fd, '\n', max_size);
}
```

#### 2. 完整写入（处理部分写入）

```cpp
// ============================================================
// 完整写入操作
// ============================================================

// 写入所有数据
Task<IoResult<void>> async_write_all(int fd, const char* buffer, size_t size) {
    size_t total = 0;

    while (total < size) {
        auto result = co_await async_write(fd, buffer + total, size - total);

        if (result.is_err()) {
            co_return IoResult<void>(result.error());
        }

        ssize_t n = result.value();
        if (n == 0) {
            // 写入返回0通常表示问题
            co_return IoResult<void>(IoError(EIO));
        }

        total += static_cast<size_t>(n);
    }

    co_return IoResult<void>();
}

// 便捷重载
Task<IoResult<void>> async_write_all(int fd, std::span<const char> buffer) {
    return async_write_all(fd, buffer.data(), buffer.size());
}

Task<IoResult<void>> async_write_all(int fd, std::string_view str) {
    return async_write_all(fd, str.data(), str.size());
}

// 写入带换行
Task<IoResult<void>> async_write_line(int fd, std::string_view line) {
    auto result = co_await async_write_all(fd, line);
    if (result.is_err()) {
        co_return result;
    }
    co_return co_await async_write_all(fd, "\n");
}

// 格式化写入
template<typename... Args>
Task<IoResult<void>> async_printf(int fd, const char* fmt, Args&&... args) {
    char buffer[4096];
    int n = std::snprintf(buffer, sizeof(buffer), fmt,
                          std::forward<Args>(args)...);
    if (n < 0) {
        co_return IoResult<void>(IoError(errno));
    }
    co_return co_await async_write_all(fd, buffer, static_cast<size_t>(n));
}
```

### Day 12-13：超时与取消机制

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | 超时Awaitable设计 | 2h |
| 下午 | 取消令牌实现 | 3h |
| 晚上 | 组合使用测试 | 2h |

#### 1. 超时Awaitable

```cpp
// ============================================================
// timeout.hpp - 超时机制
// ============================================================

#pragma once

#include "event_loop.hpp"
#include <optional>
#include <chrono>

// 超时结果
template<typename T>
struct TimeoutResult {
    std::optional<T> value;
    bool timed_out;

    explicit operator bool() const { return !timed_out; }

    T& operator*() { return *value; }
    const T& operator*() const { return *value; }

    T* operator->() { return &*value; }
    const T* operator->() const { return &*value; }
};

// 带超时的Awaitable包装器
template<typename Awaitable>
class WithTimeout {
public:
    using ResultType = decltype(std::declval<Awaitable>().await_resume());
    using ValueType = TimeoutResult<ResultType>;

private:
    Awaitable awaitable_;
    std::chrono::milliseconds timeout_;
    bool timed_out_ = false;
    uint64_t timer_id_ = 0;
    std::coroutine_handle<> waiting_handle_;

public:
    WithTimeout(Awaitable awaitable, std::chrono::milliseconds timeout)
        : awaitable_(std::move(awaitable)), timeout_(timeout) {}

    bool await_ready() {
        // 先检查内部awaitable是否ready
        if (awaitable_.await_ready()) {
            return true;
        }
        // 如果超时为0，立即超时
        if (timeout_.count() <= 0) {
            timed_out_ = true;
            return true;
        }
        return false;
    }

    void await_suspend(std::coroutine_handle<> h) {
        waiting_handle_ = h;

        // 设置超时定时器
        timer_id_ = EventLoop::current()->schedule_timer(
            timeout_,
            [this]() {
                timed_out_ = true;
                if (waiting_handle_) {
                    waiting_handle_.resume();
                }
            }
        );

        // 挂起内部awaitable
        // 注意：这里需要特殊处理，因为我们需要在
        // 内部awaitable完成或超时时都能恢复
        awaitable_.await_suspend(h);
    }

    ValueType await_resume() {
        // 取消定时器
        EventLoop::current()->cancel_timer(timer_id_);

        if (timed_out_) {
            return ValueType{std::nullopt, true};
        }

        return ValueType{awaitable_.await_resume(), false};
    }
};

// 便捷函数
template<typename Awaitable>
auto with_timeout(Awaitable&& awaitable, std::chrono::milliseconds timeout) {
    return WithTimeout<std::decay_t<Awaitable>>(
        std::forward<Awaitable>(awaitable), timeout);
}

// 使用示例
/*
Task<void> example() {
    auto result = co_await with_timeout(
        async_read(fd, buffer, size),
        std::chrono::seconds(5)
    );

    if (result.timed_out) {
        std::cout << "Read timed out\n";
    } else {
        std::cout << "Read " << result.value->value() << " bytes\n";
    }
}
*/
```

#### 2. 取消令牌

```cpp
// ============================================================
// cancellation.hpp - 取消机制
// ============================================================

#pragma once

#include <atomic>
#include <memory>
#include <functional>
#include <vector>
#include <mutex>

// 取消异常
class CancelledException : public std::exception {
public:
    const char* what() const noexcept override {
        return "Operation was cancelled";
    }
};

// 取消令牌
class CancellationToken {
public:
    class Source;

private:
    struct State {
        std::atomic<bool> cancelled{false};
        std::mutex mutex;
        std::vector<std::function<void()>> callbacks;
    };

    std::shared_ptr<State> state_;

    explicit CancellationToken(std::shared_ptr<State> state)
        : state_(std::move(state)) {}

    friend class Source;

public:
    CancellationToken() : state_(std::make_shared<State>()) {}

    // 检查是否已取消
    bool is_cancelled() const noexcept {
        return state_->cancelled.load(std::memory_order_acquire);
    }

    // 注册取消回调
    void on_cancel(std::function<void()> callback) {
        std::lock_guard lock(state_->mutex);
        if (state_->cancelled) {
            callback();  // 已经取消，立即调用
        } else {
            state_->callbacks.push_back(std::move(callback));
        }
    }

    // 可await的取消检查点
    auto check() const {
        struct CancelCheckAwaiter {
            const CancellationToken& token;

            bool await_ready() const noexcept {
                return token.is_cancelled();
            }

            void await_suspend(std::coroutine_handle<> h) const noexcept {
                // 不挂起，立即恢复
                h.resume();
            }

            void await_resume() const {
                if (token.is_cancelled()) {
                    throw CancelledException{};
                }
            }
        };
        return CancelCheckAwaiter{*this};
    }

    // 如果已取消则抛出异常
    void throw_if_cancelled() const {
        if (is_cancelled()) {
            throw CancelledException{};
        }
    }

    // 取消源（用于触发取消）
    class Source {
        std::shared_ptr<State> state_;

    public:
        Source() : state_(std::make_shared<State>()) {}

        // 获取令牌
        CancellationToken token() const {
            return CancellationToken(state_);
        }

        // 触发取消
        void cancel() {
            bool expected = false;
            if (state_->cancelled.compare_exchange_strong(
                    expected, true, std::memory_order_release)) {
                // 调用所有回调
                std::lock_guard lock(state_->mutex);
                for (auto& callback : state_->callbacks) {
                    callback();
                }
                state_->callbacks.clear();
            }
        }

        // 是否已取消
        bool is_cancelled() const noexcept {
            return state_->cancelled.load(std::memory_order_acquire);
        }
    };
};

// 可取消的读取
Task<IoResult<ssize_t>> async_read_cancellable(
    int fd, char* buffer, size_t size,
    const CancellationToken& token) {

    // 检查是否已取消
    if (token.is_cancelled()) {
        throw CancelledException{};
    }

    // 使用短超时循环，定期检查取消状态
    while (true) {
        auto result = co_await with_timeout(
            async_read(fd, buffer, size),
            std::chrono::milliseconds(100)
        );

        if (!result.timed_out) {
            co_return std::move(*result);
        }

        // 超时后检查取消
        if (token.is_cancelled()) {
            throw CancelledException{};
        }
    }
}

// 可取消的写入
Task<IoResult<void>> async_write_all_cancellable(
    int fd, const char* buffer, size_t size,
    const CancellationToken& token) {

    size_t total = 0;

    while (total < size) {
        token.throw_if_cancelled();

        auto result = co_await with_timeout(
            async_write(fd, buffer + total, size - total),
            std::chrono::milliseconds(100)
        );

        if (result.timed_out) {
            continue;  // 重试
        }

        if (result->is_err()) {
            co_return IoResult<void>(result->error());
        }

        total += static_cast<size_t>(result->value());
    }

    co_return IoResult<void>();
}
```

#### 3. 组合使用示例

```cpp
// ============================================================
// 超时和取消组合使用示例
// ============================================================

// 带超时的完整读取
Task<IoResult<size_t>> async_read_exact_timeout(
    int fd, char* buffer, size_t size,
    std::chrono::milliseconds timeout) {

    auto deadline = std::chrono::steady_clock::now() + timeout;
    size_t total = 0;

    while (total < size) {
        auto remaining = std::chrono::duration_cast<std::chrono::milliseconds>(
            deadline - std::chrono::steady_clock::now());

        if (remaining.count() <= 0) {
            co_return IoResult<size_t>(IoError(ETIMEDOUT));
        }

        auto result = co_await with_timeout(
            async_read(fd, buffer + total, size - total),
            remaining
        );

        if (result.timed_out) {
            co_return IoResult<size_t>(IoError(ETIMEDOUT));
        }

        if (result->is_err()) {
            co_return IoResult<size_t>(result->error());
        }

        ssize_t n = result->value();
        if (n == 0) {
            co_return IoResult<size_t>(IoError(EIO));  // Unexpected EOF
        }

        total += static_cast<size_t>(n);
    }

    co_return IoResult<size_t>(total);
}

// 带取消和超时的数据传输
Task<IoResult<size_t>> transfer_data(
    int src_fd, int dst_fd,
    const CancellationToken& token,
    std::chrono::milliseconds timeout = std::chrono::seconds(30)) {

    char buffer[4096];
    size_t total = 0;
    auto deadline = std::chrono::steady_clock::now() + timeout;

    while (true) {
        token.throw_if_cancelled();

        auto remaining = std::chrono::duration_cast<std::chrono::milliseconds>(
            deadline - std::chrono::steady_clock::now());

        if (remaining.count() <= 0) {
            co_return IoResult<size_t>(IoError(ETIMEDOUT));
        }

        // 读取
        auto read_result = co_await with_timeout(
            async_read(src_fd, buffer, sizeof(buffer)),
            remaining
        );

        if (read_result.timed_out) {
            co_return IoResult<size_t>(IoError(ETIMEDOUT));
        }

        if (read_result->is_err()) {
            co_return IoResult<size_t>(read_result->error());
        }

        ssize_t n = read_result->value();
        if (n == 0) {
            break;  // EOF
        }

        // 写入
        auto write_result = co_await async_write_all(dst_fd, buffer,
                                                      static_cast<size_t>(n));
        if (write_result.is_err()) {
            co_return IoResult<size_t>(write_result.error());
        }

        total += static_cast<size_t>(n);
    }

    co_return IoResult<size_t>(total);
}
```

### Day 14：第二周总结与测试

#### 测试代码

```cpp
// ============================================================
// test_io_awaitable.cpp - I/O Awaitable测试
// ============================================================

#include "io_awaitable.hpp"
#include "timeout.hpp"
#include "cancellation.hpp"
#include <iostream>
#include <sys/socket.h>
#include <netinet/in.h>

// 测试1：基本读写
Task<void> test_basic_io() {
    std::cout << "Basic I/O test\n";

    // 创建管道测试
    int pipefd[2];
    if (pipe(pipefd) < 0) {
        throw std::runtime_error("pipe failed");
    }

    set_nonblocking(pipefd[0]);
    set_nonblocking(pipefd[1]);

    // 写入
    const char* message = "Hello, Coroutine!";
    auto write_result = co_await async_write_all(pipefd[1],
                                                  message, strlen(message));
    assert(write_result.is_ok());

    // 读取
    char buffer[64] = {0};
    auto read_result = co_await async_read(pipefd[0], buffer, sizeof(buffer));
    assert(read_result.is_ok());

    std::cout << "Read: " << buffer << "\n";
    assert(strcmp(buffer, message) == 0);

    close(pipefd[0]);
    close(pipefd[1]);

    std::cout << "Basic I/O test passed\n";
}

// 测试2：超时
Task<void> test_timeout() {
    std::cout << "Timeout test\n";

    int pipefd[2];
    pipe(pipefd);
    set_nonblocking(pipefd[0]);

    char buffer[64];
    auto result = co_await with_timeout(
        async_read(pipefd[0], buffer, sizeof(buffer)),
        std::chrono::milliseconds(100)
    );

    assert(result.timed_out);
    std::cout << "Read timed out as expected\n";

    close(pipefd[0]);
    close(pipefd[1]);

    std::cout << "Timeout test passed\n";
}

// 测试3：取消
Task<void> test_cancellation() {
    std::cout << "Cancellation test\n";

    CancellationToken::Source source;
    auto token = source.token();

    // 在另一个协程中取消
    auto canceller = [&source]() -> Task<void> {
        co_await sleep_for(std::chrono::milliseconds(50));
        source.cancel();
    }();

    int pipefd[2];
    pipe(pipefd);
    set_nonblocking(pipefd[0]);

    char buffer[64];
    bool cancelled = false;

    try {
        co_await async_read_cancellable(pipefd[0], buffer, sizeof(buffer), token);
    } catch (const CancelledException&) {
        cancelled = true;
    }

    assert(cancelled);
    std::cout << "Operation cancelled as expected\n";

    close(pipefd[0]);
    close(pipefd[1]);

    std::cout << "Cancellation test passed\n";
}

// 运行测试
void run_io_tests() {
    EventLoop loop;

    loop.schedule([&]() -> DetachedTask {
        co_await test_basic_io();
        co_await test_timeout();
        co_await test_cancellation();

        loop.stop();
    }().handle);

    loop.run();

    std::cout << "All I/O tests passed!\n";
}
```

#### 第二周检验标准

- [ ] 理解如何将系统调用封装为Awaitable
- [ ] 实现AsyncRead和AsyncWrite
- [ ] 理解EAGAIN/EWOULDBLOCK的处理
- [ ] 实现IoResult类型和IoError类
- [ ] 实现async_read_exact和async_write_all
- [ ] 实现超时机制（WithTimeout）
- [ ] 实现取消机制（CancellationToken）
- [ ] 通过所有I/O测试

---

## 第三周：协程Socket封装（Day 15-21）

> **本周目标**：实现完整的AsyncTcpSocket和AsyncTcpListener，支持缓冲I/O

### Day 15-16：AsyncTcpSocket实现

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | Socket基础封装 | 2h |
| 下午 | 连接与断开 | 3h |
| 晚上 | 读写缓冲区 | 2h |

#### 1. 文件描述符RAII包装

```cpp
// ============================================================
// fd.hpp - 文件描述符RAII包装
// ============================================================

#pragma once

#include <unistd.h>
#include <utility>

class FileDescriptor {
private:
    int fd_ = -1;

public:
    FileDescriptor() = default;
    explicit FileDescriptor(int fd) : fd_(fd) {}

    // 移动构造
    FileDescriptor(FileDescriptor&& other) noexcept
        : fd_(std::exchange(other.fd_, -1)) {}

    // 移动赋值
    FileDescriptor& operator=(FileDescriptor&& other) noexcept {
        if (this != &other) {
            close();
            fd_ = std::exchange(other.fd_, -1);
        }
        return *this;
    }

    // 禁止拷贝
    FileDescriptor(const FileDescriptor&) = delete;
    FileDescriptor& operator=(const FileDescriptor&) = delete;

    ~FileDescriptor() { close(); }

    void close() {
        if (fd_ >= 0) {
            ::close(fd_);
            fd_ = -1;
        }
    }

    int get() const noexcept { return fd_; }
    int release() noexcept { return std::exchange(fd_, -1); }

    explicit operator bool() const noexcept { return fd_ >= 0; }
    bool valid() const noexcept { return fd_ >= 0; }

    // 隐式转换为int（方便使用）
    operator int() const noexcept { return fd_; }
};
```

#### 2. 网络地址封装

```cpp
// ============================================================
// socket_address.hpp - 网络地址封装
// ============================================================

#pragma once

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <string>
#include <cstring>
#include <stdexcept>

class SocketAddress {
private:
    sockaddr_storage storage_{};
    socklen_t len_ = 0;

public:
    SocketAddress() = default;

    // 从IPv4地址构造
    static SocketAddress from_ipv4(const std::string& ip, uint16_t port) {
        SocketAddress addr;
        auto* sin = reinterpret_cast<sockaddr_in*>(&addr.storage_);

        sin->sin_family = AF_INET;
        sin->sin_port = htons(port);

        if (ip == "0.0.0.0" || ip.empty()) {
            sin->sin_addr.s_addr = INADDR_ANY;
        } else {
            if (inet_pton(AF_INET, ip.c_str(), &sin->sin_addr) != 1) {
                throw std::runtime_error("Invalid IPv4 address: " + ip);
            }
        }

        addr.len_ = sizeof(sockaddr_in);
        return addr;
    }

    // 从IPv6地址构造
    static SocketAddress from_ipv6(const std::string& ip, uint16_t port) {
        SocketAddress addr;
        auto* sin6 = reinterpret_cast<sockaddr_in6*>(&addr.storage_);

        sin6->sin6_family = AF_INET6;
        sin6->sin6_port = htons(port);

        if (ip == "::" || ip.empty()) {
            sin6->sin6_addr = in6addr_any;
        } else {
            if (inet_pton(AF_INET6, ip.c_str(), &sin6->sin6_addr) != 1) {
                throw std::runtime_error("Invalid IPv6 address: " + ip);
            }
        }

        addr.len_ = sizeof(sockaddr_in6);
        return addr;
    }

    // 从主机名和端口构造（DNS解析）
    static SocketAddress from_host(const std::string& host, uint16_t port) {
        addrinfo hints{};
        hints.ai_family = AF_UNSPEC;
        hints.ai_socktype = SOCK_STREAM;

        addrinfo* result = nullptr;
        std::string port_str = std::to_string(port);

        int err = getaddrinfo(host.c_str(), port_str.c_str(), &hints, &result);
        if (err != 0) {
            throw std::runtime_error("DNS resolution failed: " +
                                     std::string(gai_strerror(err)));
        }

        SocketAddress addr;
        std::memcpy(&addr.storage_, result->ai_addr, result->ai_addrlen);
        addr.len_ = result->ai_addrlen;

        freeaddrinfo(result);
        return addr;
    }

    // 获取原始指针
    sockaddr* data() {
        return reinterpret_cast<sockaddr*>(&storage_);
    }

    const sockaddr* data() const {
        return reinterpret_cast<const sockaddr*>(&storage_);
    }

    socklen_t size() const { return len_; }
    socklen_t* size_ptr() { return &len_; }

    int family() const {
        return storage_.ss_family;
    }

    uint16_t port() const {
        if (storage_.ss_family == AF_INET) {
            auto* sin = reinterpret_cast<const sockaddr_in*>(&storage_);
            return ntohs(sin->sin_port);
        } else if (storage_.ss_family == AF_INET6) {
            auto* sin6 = reinterpret_cast<const sockaddr_in6*>(&storage_);
            return ntohs(sin6->sin6_port);
        }
        return 0;
    }

    std::string ip() const {
        char buf[INET6_ADDRSTRLEN];

        if (storage_.ss_family == AF_INET) {
            auto* sin = reinterpret_cast<const sockaddr_in*>(&storage_);
            inet_ntop(AF_INET, &sin->sin_addr, buf, sizeof(buf));
        } else if (storage_.ss_family == AF_INET6) {
            auto* sin6 = reinterpret_cast<const sockaddr_in6*>(&storage_);
            inet_ntop(AF_INET6, &sin6->sin6_addr, buf, sizeof(buf));
        } else {
            return "unknown";
        }

        return buf;
    }

    std::string to_string() const {
        return ip() + ":" + std::to_string(port());
    }
};
```

#### 3. AsyncTcpSocket主类

```cpp
// ============================================================
// async_tcp_socket.hpp - 异步TCP Socket
// ============================================================

#pragma once

#include "fd.hpp"
#include "socket_address.hpp"
#include "io_awaitable.hpp"
#include "task.hpp"
#include <sys/socket.h>
#include <netinet/tcp.h>

class AsyncTcpSocket {
private:
    FileDescriptor fd_;

public:
    AsyncTcpSocket() = default;

    explicit AsyncTcpSocket(int fd) : fd_(fd) {
        set_nonblocking(fd_.get());
    }

    explicit AsyncTcpSocket(FileDescriptor fd) : fd_(std::move(fd)) {
        set_nonblocking(fd_.get());
    }

    // 移动语义
    AsyncTcpSocket(AsyncTcpSocket&&) = default;
    AsyncTcpSocket& operator=(AsyncTcpSocket&&) = default;

    // 禁止拷贝
    AsyncTcpSocket(const AsyncTcpSocket&) = delete;
    AsyncTcpSocket& operator=(const AsyncTcpSocket&) = delete;

    // 创建新socket
    static IoResult<AsyncTcpSocket> create(int domain = AF_INET) {
        int fd = socket(domain, SOCK_STREAM | SOCK_NONBLOCK | SOCK_CLOEXEC, 0);
        if (fd < 0) {
            return IoResult<AsyncTcpSocket>::from_errno();
        }
        return IoResult<AsyncTcpSocket>(AsyncTcpSocket(fd));
    }

    // 异步连接
    Task<IoResult<void>> connect(const SocketAddress& addr) {
        int ret = ::connect(fd_.get(), addr.data(), addr.size());

        if (ret == 0) {
            // 立即连接成功（本地连接可能发生）
            co_return IoResult<void>();
        }

        if (errno != EINPROGRESS) {
            // 立即失败
            co_return IoResult<void>::from_errno();
        }

        // 等待连接完成
        co_await IoAwaitable(fd_.get(), IoEvent::Write);

        // 检查连接结果
        int error = 0;
        socklen_t len = sizeof(error);
        if (getsockopt(fd_.get(), SOL_SOCKET, SO_ERROR, &error, &len) < 0) {
            co_return IoResult<void>::from_errno();
        }

        if (error != 0) {
            co_return IoResult<void>(IoError(error));
        }

        co_return IoResult<void>();
    }

    // 异步读取
    Task<IoResult<ssize_t>> read(char* buffer, size_t size) {
        co_return co_await async_read(fd_.get(), buffer, size);
    }

    Task<IoResult<ssize_t>> read(std::span<char> buffer) {
        co_return co_await async_read(fd_.get(), buffer.data(), buffer.size());
    }

    // 异步写入
    Task<IoResult<ssize_t>> write(const char* buffer, size_t size) {
        co_return co_await async_write(fd_.get(), buffer, size);
    }

    Task<IoResult<ssize_t>> write(std::span<const char> buffer) {
        co_return co_await async_write(fd_.get(), buffer.data(), buffer.size());
    }

    // 完整写入
    Task<IoResult<void>> write_all(const char* buffer, size_t size) {
        co_return co_await async_write_all(fd_.get(), buffer, size);
    }

    Task<IoResult<void>> write_all(std::string_view str) {
        co_return co_await async_write_all(fd_.get(), str.data(), str.size());
    }

    // 读取精确字节数
    Task<IoResult<size_t>> read_exact(char* buffer, size_t size) {
        co_return co_await async_read_exact(fd_.get(), buffer, size);
    }

    // 关闭操作
    void shutdown_read() {
        ::shutdown(fd_.get(), SHUT_RD);
    }

    void shutdown_write() {
        ::shutdown(fd_.get(), SHUT_WR);
    }

    void shutdown_both() {
        ::shutdown(fd_.get(), SHUT_RDWR);
    }

    void close() {
        fd_.close();
    }

    // Socket选项
    void set_nodelay(bool enable) {
        int flag = enable ? 1 : 0;
        setsockopt(fd_.get(), IPPROTO_TCP, TCP_NODELAY, &flag, sizeof(flag));
    }

    void set_keepalive(bool enable) {
        int flag = enable ? 1 : 0;
        setsockopt(fd_.get(), SOL_SOCKET, SO_KEEPALIVE, &flag, sizeof(flag));
    }

    // 获取本地/远程地址
    SocketAddress local_addr() const {
        SocketAddress addr;
        getsockname(fd_.get(), addr.data(), addr.size_ptr());
        return addr;
    }

    SocketAddress peer_addr() const {
        SocketAddress addr;
        getpeername(fd_.get(), addr.data(), addr.size_ptr());
        return addr;
    }

    int native_handle() const { return fd_.get(); }
    bool valid() const { return fd_.valid(); }
};

// I/O Awaitable（用于socket的等待）
class IoAwaitable {
private:
    int fd_;
    IoEvent events_;

public:
    IoAwaitable(int fd, IoEvent events) : fd_(fd), events_(events) {}

    bool await_ready() const noexcept { return false; }

    void await_suspend(std::coroutine_handle<> h) {
        EventLoop::current()->schedule_io(fd_, events_, h);
    }

    void await_resume() const noexcept {}
};
```

### Day 17-18：AsyncTcpListener实现

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | bind和listen封装 | 2h |
| 下午 | 异步accept实现 | 3h |
| 晚上 | 连接生成器 | 2h |

#### 1. AsyncTcpListener实现

```cpp
// ============================================================
// async_tcp_listener.hpp - 异步TCP监听器
// ============================================================

#pragma once

#include "async_tcp_socket.hpp"

class AsyncTcpListener {
private:
    FileDescriptor fd_;

public:
    AsyncTcpListener() = default;

    explicit AsyncTcpListener(FileDescriptor fd) : fd_(std::move(fd)) {}

    // 移动语义
    AsyncTcpListener(AsyncTcpListener&&) = default;
    AsyncTcpListener& operator=(AsyncTcpListener&&) = default;

    // 绑定并监听
    static Task<IoResult<AsyncTcpListener>> bind(
        const SocketAddress& addr,
        int backlog = 128) {

        // 创建socket
        int fd = socket(addr.family(),
                        SOCK_STREAM | SOCK_NONBLOCK | SOCK_CLOEXEC, 0);
        if (fd < 0) {
            co_return IoResult<AsyncTcpListener>::from_errno();
        }

        FileDescriptor sock_fd(fd);

        // 设置SO_REUSEADDR
        int optval = 1;
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &optval, sizeof(optval));

        // 设置SO_REUSEPORT（可选，用于多进程）
        #ifdef SO_REUSEPORT
        setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &optval, sizeof(optval));
        #endif

        // 绑定
        if (::bind(fd, addr.data(), addr.size()) < 0) {
            co_return IoResult<AsyncTcpListener>::from_errno();
        }

        // 监听
        if (::listen(fd, backlog) < 0) {
            co_return IoResult<AsyncTcpListener>::from_errno();
        }

        co_return IoResult<AsyncTcpListener>(
            AsyncTcpListener(std::move(sock_fd)));
    }

    // 异步接受连接
    Task<IoResult<std::pair<AsyncTcpSocket, SocketAddress>>> accept() {
        while (true) {
            SocketAddress client_addr;

            // 尝试accept
            #ifdef __linux__
            int client_fd = accept4(fd_.get(),
                                    client_addr.data(),
                                    client_addr.size_ptr(),
                                    SOCK_NONBLOCK | SOCK_CLOEXEC);
            #else
            int client_fd = ::accept(fd_.get(),
                                     client_addr.data(),
                                     client_addr.size_ptr());
            if (client_fd >= 0) {
                // macOS没有accept4，手动设置
                set_nonblocking(client_fd);
                fcntl(client_fd, F_SETFD, FD_CLOEXEC);
            }
            #endif

            if (client_fd >= 0) {
                co_return IoResult<std::pair<AsyncTcpSocket, SocketAddress>>(
                    std::make_pair(AsyncTcpSocket(client_fd), client_addr));
            }

            if (errno == EAGAIN || errno == EWOULDBLOCK) {
                // 等待新连接
                co_await IoAwaitable(fd_.get(), IoEvent::Read);
                continue;
            }

            // 真正的错误
            co_return IoResult<std::pair<AsyncTcpSocket, SocketAddress>>::from_errno();
        }
    }

    // 本地地址
    SocketAddress local_addr() const {
        SocketAddress addr;
        getsockname(fd_.get(), addr.data(), addr.size_ptr());
        return addr;
    }

    int native_handle() const { return fd_.get(); }

    void close() { fd_.close(); }
};
```

#### 2. 连接生成器

```cpp
// ============================================================
// 连接生成器 - 使用AsyncGenerator
// ============================================================

// 无限生成新连接
AsyncGenerator<std::pair<AsyncTcpSocket, SocketAddress>>
incoming_connections(AsyncTcpListener& listener) {
    while (true) {
        auto result = co_await listener.accept();

        if (result.is_err()) {
            // 某些错误可以忽略继续
            if (result.error().error_code() == EMFILE ||
                result.error().error_code() == ENFILE) {
                // 文件描述符耗尽，等待一下重试
                co_await sleep_for(std::chrono::milliseconds(100));
                continue;
            }
            // 其他错误停止
            break;
        }

        co_yield std::move(result.value());
    }
}

// 使用示例
/*
Task<void> server() {
    auto listener = (co_await AsyncTcpListener::bind(
        SocketAddress::from_ipv4("0.0.0.0", 8080))).unwrap();

    for co_await (auto [socket, addr] : incoming_connections(listener)) {
        std::cout << "New connection from " << addr.to_string() << "\n";
        // 处理连接...
    }
}
*/
```

### Day 19-20：缓冲I/O与流操作

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | 读缓冲区设计 | 2h |
| 下午 | 写缓冲区设计 | 3h |
| 晚上 | BufferedSocket | 2h |

#### 1. 读缓冲区

```cpp
// ============================================================
// buffer.hpp - 缓冲区实现
// ============================================================

#pragma once

#include <vector>
#include <span>
#include <cstring>
#include <algorithm>

class ReadBuffer {
private:
    std::vector<char> buffer_;
    size_t read_pos_ = 0;   // 读取位置
    size_t write_pos_ = 0;  // 写入位置

public:
    explicit ReadBuffer(size_t capacity = 8192)
        : buffer_(capacity) {}

    // 可读数据
    std::span<const char> readable() const {
        return {buffer_.data() + read_pos_, write_pos_ - read_pos_};
    }

    size_t readable_size() const {
        return write_pos_ - read_pos_;
    }

    // 可写空间
    std::span<char> writable() {
        return {buffer_.data() + write_pos_, buffer_.size() - write_pos_};
    }

    size_t writable_size() const {
        return buffer_.size() - write_pos_;
    }

    // 消费已读数据
    void consume(size_t n) {
        read_pos_ += std::min(n, readable_size());
        if (read_pos_ == write_pos_) {
            // 缓冲区空了，重置位置
            read_pos_ = write_pos_ = 0;
        }
    }

    // 提交写入的数据
    void commit(size_t n) {
        write_pos_ += std::min(n, writable_size());
    }

    // 紧凑缓冲区（移动数据到开头）
    void compact() {
        if (read_pos_ > 0) {
            size_t len = readable_size();
            std::memmove(buffer_.data(), buffer_.data() + read_pos_, len);
            read_pos_ = 0;
            write_pos_ = len;
        }
    }

    // 确保有足够的可写空间
    void reserve(size_t n) {
        if (writable_size() < n) {
            compact();
            if (writable_size() < n) {
                buffer_.resize(buffer_.size() + n - writable_size());
            }
        }
    }

    // 查找字符
    const char* find(char c) const {
        auto data = readable();
        auto it = std::find(data.begin(), data.end(), c);
        if (it != data.end()) {
            return &*it;
        }
        return nullptr;
    }

    // 查找字符串
    const char* find(std::string_view str) const {
        auto data = readable();
        auto it = std::search(data.begin(), data.end(),
                              str.begin(), str.end());
        if (it != data.end()) {
            return &*it;
        }
        return nullptr;
    }

    bool empty() const { return readable_size() == 0; }
    void clear() { read_pos_ = write_pos_ = 0; }
};

class WriteBuffer {
private:
    std::vector<char> buffer_;

public:
    explicit WriteBuffer(size_t initial_capacity = 4096) {
        buffer_.reserve(initial_capacity);
    }

    // 追加数据
    void append(const char* data, size_t len) {
        buffer_.insert(buffer_.end(), data, data + len);
    }

    void append(std::string_view str) {
        append(str.data(), str.size());
    }

    void append(std::span<const char> data) {
        append(data.data(), data.size());
    }

    // 获取数据
    std::span<const char> data() const {
        return {buffer_.data(), buffer_.size()};
    }

    size_t size() const { return buffer_.size(); }
    bool empty() const { return buffer_.empty(); }

    // 消费已发送的数据
    void consume(size_t n) {
        if (n >= buffer_.size()) {
            buffer_.clear();
        } else {
            buffer_.erase(buffer_.begin(), buffer_.begin() + n);
        }
    }

    void clear() { buffer_.clear(); }
};
```

#### 2. BufferedSocket

```cpp
// ============================================================
// buffered_socket.hpp - 带缓冲的Socket
// ============================================================

#pragma once

#include "async_tcp_socket.hpp"
#include "buffer.hpp"

class BufferedSocket {
private:
    AsyncTcpSocket socket_;
    ReadBuffer read_buffer_;
    WriteBuffer write_buffer_;

public:
    explicit BufferedSocket(AsyncTcpSocket socket,
                            size_t read_buffer_size = 8192)
        : socket_(std::move(socket))
        , read_buffer_(read_buffer_size) {}

    // 读取一行（以\n结尾）
    Task<IoResult<std::string>> read_line(size_t max_length = 65536) {
        while (true) {
            // 检查缓冲区中是否有完整行
            auto data = read_buffer_.readable();
            auto newline = read_buffer_.find('\n');

            if (newline != nullptr) {
                size_t line_len = newline - data.data() + 1;
                std::string line(data.data(), line_len);
                read_buffer_.consume(line_len);
                co_return IoResult<std::string>(std::move(line));
            }

            // 检查是否超过最大长度
            if (data.size() >= max_length) {
                co_return IoResult<std::string>(IoError(ENOBUFS));
            }

            // 需要从socket读取更多数据
            read_buffer_.compact();
            auto writable = read_buffer_.writable();

            if (writable.empty()) {
                read_buffer_.reserve(4096);
                writable = read_buffer_.writable();
            }

            auto result = co_await socket_.read(writable.data(),
                                                 writable.size());
            if (result.is_err()) {
                co_return IoResult<std::string>(result.error());
            }

            ssize_t n = result.value();
            if (n == 0) {
                // EOF：返回剩余数据（如果有）
                if (!read_buffer_.empty()) {
                    auto remaining = read_buffer_.readable();
                    std::string line(remaining.data(), remaining.size());
                    read_buffer_.clear();
                    co_return IoResult<std::string>(std::move(line));
                }
                co_return IoResult<std::string>(std::string{});  // 空字符串表示EOF
            }

            read_buffer_.commit(static_cast<size_t>(n));
        }
    }

    // 读取精确字节数
    Task<IoResult<std::vector<char>>> read_exact(size_t n) {
        std::vector<char> result;
        result.reserve(n);

        // 先从缓冲区取
        auto buffered = read_buffer_.readable();
        size_t from_buffer = std::min(buffered.size(), n);
        result.insert(result.end(),
                      buffered.data(),
                      buffered.data() + from_buffer);
        read_buffer_.consume(from_buffer);

        // 剩余从socket读
        while (result.size() < n) {
            size_t remaining = n - result.size();
            std::vector<char> temp(remaining);

            auto read_result = co_await socket_.read(temp.data(), remaining);
            if (read_result.is_err()) {
                co_return IoResult<std::vector<char>>(read_result.error());
            }

            ssize_t bytes = read_result.value();
            if (bytes == 0) {
                co_return IoResult<std::vector<char>>(IoError(EIO));
            }

            result.insert(result.end(), temp.data(), temp.data() + bytes);
        }

        co_return IoResult<std::vector<char>>(std::move(result));
    }

    // 写入数据（带缓冲）
    void buffer_write(std::string_view data) {
        write_buffer_.append(data);
    }

    void buffer_write(std::span<const char> data) {
        write_buffer_.append(data);
    }

    // 刷新写缓冲区
    Task<IoResult<void>> flush() {
        while (!write_buffer_.empty()) {
            auto data = write_buffer_.data();
            auto result = co_await socket_.write(data.data(), data.size());

            if (result.is_err()) {
                co_return IoResult<void>(result.error());
            }

            write_buffer_.consume(static_cast<size_t>(result.value()));
        }
        co_return IoResult<void>();
    }

    // 直接写入（不经过缓冲）
    Task<IoResult<void>> write(std::string_view data) {
        co_return co_await socket_.write_all(data);
    }

    // 写入并刷新
    Task<IoResult<void>> write_and_flush(std::string_view data) {
        buffer_write(data);
        co_return co_await flush();
    }

    // 获取底层socket
    AsyncTcpSocket& socket() { return socket_; }
    const AsyncTcpSocket& socket() const { return socket_; }

    void close() { socket_.close(); }
};

// 行流生成器
AsyncGenerator<std::string> read_lines(BufferedSocket& socket) {
    while (true) {
        auto result = co_await socket.read_line();

        if (result.is_err()) {
            break;
        }

        if (result.value().empty()) {
            break;  // EOF
        }

        co_yield std::move(result.value());
    }
}
```

### Day 21：第三周总结与测试

#### 测试代码

```cpp
// ============================================================
// test_socket.cpp - Socket测试
// ============================================================

#include "async_tcp_socket.hpp"
#include "async_tcp_listener.hpp"
#include "buffered_socket.hpp"
#include <iostream>

// 简单Echo服务器（用于测试）
Task<void> echo_handler(AsyncTcpSocket socket) {
    BufferedSocket buffered(std::move(socket));

    while (true) {
        auto result = co_await buffered.read_line();
        if (result.is_err() || result.value().empty()) {
            break;
        }

        auto write_result = co_await buffered.write(result.value());
        if (write_result.is_err()) {
            break;
        }
    }
}

Task<void> test_echo_server() {
    std::cout << "Starting echo server test\n";

    // 启动服务器
    auto listener_result = co_await AsyncTcpListener::bind(
        SocketAddress::from_ipv4("127.0.0.1", 0));  // 随机端口

    if (listener_result.is_err()) {
        std::cerr << "Failed to bind: " << listener_result.error().what() << "\n";
        co_return;
    }

    auto& listener = listener_result.value();
    auto addr = listener.local_addr();
    std::cout << "Server listening on " << addr.to_string() << "\n";

    // 启动客户端测试协程
    auto client_test = [&addr]() -> Task<void> {
        // 等待服务器启动
        co_await sleep_for(std::chrono::milliseconds(10));

        // 连接服务器
        auto socket_result = AsyncTcpSocket::create();
        if (socket_result.is_err()) {
            std::cerr << "Failed to create socket\n";
            co_return;
        }

        auto& socket = socket_result.value();
        auto connect_result = co_await socket.connect(addr);
        if (connect_result.is_err()) {
            std::cerr << "Failed to connect\n";
            co_return;
        }

        std::cout << "Client connected\n";

        // 发送数据
        co_await socket.write_all("Hello, Server!\n");

        // 接收回显
        char buffer[64];
        auto read_result = co_await socket.read(buffer, sizeof(buffer));
        if (read_result.is_ok()) {
            std::cout << "Received: " << std::string(buffer, read_result.value());
        }

        socket.close();
    }();

    // 接受一个连接
    auto accept_result = co_await listener.accept();
    if (accept_result.is_ok()) {
        auto [socket, client_addr] = std::move(accept_result.value());
        std::cout << "Accepted connection from " << client_addr.to_string() << "\n";

        // 处理
        co_await echo_handler(std::move(socket));
    }

    co_await client_test;

    std::cout << "Echo server test passed\n";
}

void run_socket_tests() {
    EventLoop loop;

    loop.schedule([&]() -> DetachedTask {
        co_await test_echo_server();
        loop.stop();
    }().handle);

    loop.run();

    std::cout << "All socket tests passed!\n";
}
```

#### 第三周检验标准

- [ ] 实现FileDescriptor RAII包装
- [ ] 实现SocketAddress网络地址类
- [ ] 实现AsyncTcpSocket（connect/read/write）
- [ ] 实现AsyncTcpListener（bind/accept）
- [ ] 理解非阻塞connect的处理
- [ ] 实现ReadBuffer和WriteBuffer
- [ ] 实现BufferedSocket
- [ ] 通过Echo服务器测试

---

## 第四周：实际应用（Day 22-28）

> **本周目标**：完成Echo服务器和HTTP客户端，进行性能测试

### Day 22-23：协程Echo服务器

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | Echo服务器设计 | 2h |
| 下午 | 并发处理实现 | 3h |
| 晚上 | 超时和限流 | 2h |

#### 1. 简单Echo服务器

```cpp
// ============================================================
// echo_server.cpp - 协程Echo服务器
// ============================================================

#include "async_tcp_listener.hpp"
#include "buffered_socket.hpp"
#include <iostream>
#include <atomic>

// 全局统计
struct ServerStats {
    std::atomic<size_t> connections{0};
    std::atomic<size_t> bytes_received{0};
    std::atomic<size_t> bytes_sent{0};
};

ServerStats g_stats;

// Echo处理协程
Task<void> handle_client(AsyncTcpSocket socket, SocketAddress addr) {
    ++g_stats.connections;
    std::cout << "[" << addr.to_string() << "] Connected\n";

    char buffer[4096];

    while (true) {
        // 读取数据
        auto read_result = co_await socket.read(buffer, sizeof(buffer));

        if (read_result.is_err()) {
            std::cerr << "[" << addr.to_string() << "] Read error: "
                      << read_result.error().what() << "\n";
            break;
        }

        ssize_t n = read_result.value();
        if (n == 0) {
            // 客户端关闭连接
            break;
        }

        g_stats.bytes_received += n;

        // 回显数据
        auto write_result = co_await socket.write_all(buffer,
                                                       static_cast<size_t>(n));
        if (write_result.is_err()) {
            std::cerr << "[" << addr.to_string() << "] Write error: "
                      << write_result.error().what() << "\n";
            break;
        }

        g_stats.bytes_sent += n;
    }

    --g_stats.connections;
    std::cout << "[" << addr.to_string() << "] Disconnected\n";
}

// 启动无返回值协程（Fire and Forget）
template<typename T>
void spawn_detached(Task<T> task) {
    // 创建一个detached协程来运行task
    [](Task<T> t) -> DetachedTask {
        co_await std::move(t);
    }(std::move(task));
}

// Echo服务器主函数
Task<void> run_echo_server(uint16_t port) {
    auto listener_result = co_await AsyncTcpListener::bind(
        SocketAddress::from_ipv4("0.0.0.0", port));

    if (listener_result.is_err()) {
        std::cerr << "Failed to bind: " << listener_result.error().what() << "\n";
        co_return;
    }

    auto& listener = listener_result.value();
    std::cout << "Echo server listening on port " << port << "\n";

    while (true) {
        auto accept_result = co_await listener.accept();

        if (accept_result.is_err()) {
            std::cerr << "Accept error: " << accept_result.error().what() << "\n";
            co_await sleep_for(std::chrono::milliseconds(100));
            continue;
        }

        auto [socket, addr] = std::move(accept_result.value());

        // 启动处理协程（非阻塞）
        spawn_detached(handle_client(std::move(socket), addr));
    }
}

// 主函数
int main(int argc, char* argv[]) {
    uint16_t port = 8080;
    if (argc > 1) {
        port = static_cast<uint16_t>(std::stoi(argv[1]));
    }

    EventLoop loop;

    loop.schedule([&]() -> DetachedTask {
        co_await run_echo_server(port);
    }().handle);

    loop.run();

    return 0;
}
```

#### 2. 带超时的Echo服务器

```cpp
// ============================================================
// 带超时和限流的Echo服务器
// ============================================================

// 连接限制器
class ConnectionLimiter {
private:
    std::atomic<size_t> current_{0};
    size_t max_;

public:
    explicit ConnectionLimiter(size_t max) : max_(max) {}

    bool try_acquire() {
        size_t current = current_.load();
        while (current < max_) {
            if (current_.compare_exchange_weak(current, current + 1)) {
                return true;
            }
        }
        return false;
    }

    void release() {
        --current_;
    }

    size_t current() const { return current_.load(); }
    size_t max() const { return max_; }

    // RAII守卫
    class Guard {
        ConnectionLimiter* limiter_;
    public:
        explicit Guard(ConnectionLimiter* limiter) : limiter_(limiter) {}
        ~Guard() { if (limiter_) limiter_->release(); }

        Guard(Guard&& other) noexcept
            : limiter_(std::exchange(other.limiter_, nullptr)) {}

        Guard(const Guard&) = delete;
        Guard& operator=(const Guard&) = delete;
    };

    std::optional<Guard> acquire() {
        if (try_acquire()) {
            return Guard(this);
        }
        return std::nullopt;
    }
};

// 带超时的Echo处理
Task<void> handle_client_timeout(
    AsyncTcpSocket socket,
    SocketAddress addr,
    ConnectionLimiter::Guard guard,
    std::chrono::seconds idle_timeout = std::chrono::seconds(30)) {

    std::cout << "[" << addr.to_string() << "] Connected\n";

    char buffer[4096];
    auto deadline = std::chrono::steady_clock::now() + idle_timeout;

    while (true) {
        auto remaining = std::chrono::duration_cast<std::chrono::milliseconds>(
            deadline - std::chrono::steady_clock::now());

        if (remaining.count() <= 0) {
            std::cout << "[" << addr.to_string() << "] Idle timeout\n";
            break;
        }

        // 带超时读取
        auto read_result = co_await with_timeout(
            socket.read(buffer, sizeof(buffer)),
            remaining
        );

        if (read_result.timed_out) {
            std::cout << "[" << addr.to_string() << "] Idle timeout\n";
            break;
        }

        if (read_result->is_err()) {
            break;
        }

        ssize_t n = read_result->value();
        if (n == 0) {
            break;
        }

        // 重置超时
        deadline = std::chrono::steady_clock::now() + idle_timeout;

        // 回显
        auto write_result = co_await socket.write_all(buffer,
                                                       static_cast<size_t>(n));
        if (write_result.is_err()) {
            break;
        }
    }

    std::cout << "[" << addr.to_string() << "] Disconnected\n";
}

// 带限流的服务器
Task<void> run_echo_server_limited(uint16_t port, size_t max_connections) {
    ConnectionLimiter limiter(max_connections);

    auto listener_result = co_await AsyncTcpListener::bind(
        SocketAddress::from_ipv4("0.0.0.0", port));

    if (listener_result.is_err()) {
        std::cerr << "Failed to bind\n";
        co_return;
    }

    auto& listener = listener_result.value();
    std::cout << "Echo server (max " << max_connections
              << " connections) on port " << port << "\n";

    while (true) {
        auto accept_result = co_await listener.accept();

        if (accept_result.is_err()) {
            continue;
        }

        auto [socket, addr] = std::move(accept_result.value());

        // 检查连接限制
        auto guard = limiter.acquire();
        if (!guard) {
            std::cout << "[" << addr.to_string()
                      << "] Rejected (too many connections)\n";
            // socket会自动关闭
            continue;
        }

        spawn_detached(handle_client_timeout(
            std::move(socket), addr, std::move(*guard)));
    }
}
```

### Day 24-25：协程HTTP客户端

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | HTTP协议解析 | 2h |
| 下午 | HTTP客户端实现 | 3h |
| 晚上 | 测试与调试 | 2h |

#### 1. HTTP请求/响应类

```cpp
// ============================================================
// http.hpp - HTTP协议支持
// ============================================================

#pragma once

#include <string>
#include <unordered_map>
#include <sstream>
#include <algorithm>

// HTTP请求
struct HttpRequest {
    std::string method = "GET";
    std::string path = "/";
    std::string version = "HTTP/1.1";
    std::unordered_map<std::string, std::string> headers;
    std::string body;

    // 序列化为HTTP请求
    std::string serialize() const {
        std::ostringstream ss;

        // 请求行
        ss << method << " " << path << " " << version << "\r\n";

        // 头部
        for (const auto& [key, value] : headers) {
            ss << key << ": " << value << "\r\n";
        }

        // 空行
        ss << "\r\n";

        // 请求体
        ss << body;

        return ss.str();
    }

    // 设置常用头部
    void set_host(const std::string& host) {
        headers["Host"] = host;
    }

    void set_content_type(const std::string& type) {
        headers["Content-Type"] = type;
    }

    void set_content_length() {
        headers["Content-Length"] = std::to_string(body.size());
    }

    void set_connection_close() {
        headers["Connection"] = "close";
    }

    void set_user_agent(const std::string& ua = "CoroHttp/1.0") {
        headers["User-Agent"] = ua;
    }
};

// HTTP响应
struct HttpResponse {
    std::string version;
    int status_code = 0;
    std::string reason;
    std::unordered_map<std::string, std::string> headers;
    std::string body;

    bool is_ok() const {
        return status_code >= 200 && status_code < 300;
    }

    bool is_redirect() const {
        return status_code >= 300 && status_code < 400;
    }

    std::string get_header(const std::string& name,
                           const std::string& default_value = "") const {
        // 不区分大小写查找
        for (const auto& [key, value] : headers) {
            if (strcasecmp(key.c_str(), name.c_str()) == 0) {
                return value;
            }
        }
        return default_value;
    }

    size_t content_length() const {
        auto len = get_header("Content-Length");
        if (len.empty()) return 0;
        return std::stoull(len);
    }
};
```

#### 2. HTTP客户端实现

```cpp
// ============================================================
// http_client.hpp - HTTP客户端
// ============================================================

#pragma once

#include "async_tcp_socket.hpp"
#include "buffered_socket.hpp"
#include "http.hpp"

class HttpClient {
private:
    std::string host_;
    uint16_t port_;

public:
    HttpClient(std::string host, uint16_t port = 80)
        : host_(std::move(host)), port_(port) {}

    // 发送请求
    Task<IoResult<HttpResponse>> request(HttpRequest req) {
        // 创建socket
        auto socket_result = AsyncTcpSocket::create();
        if (socket_result.is_err()) {
            co_return IoResult<HttpResponse>(socket_result.error());
        }

        auto& socket = socket_result.value();

        // 连接
        auto addr = SocketAddress::from_host(host_, port_);
        auto connect_result = co_await socket.connect(addr);
        if (connect_result.is_err()) {
            co_return IoResult<HttpResponse>(connect_result.error());
        }

        // 设置必需头部
        if (req.headers.find("Host") == req.headers.end()) {
            req.set_host(host_);
        }
        if (req.headers.find("Connection") == req.headers.end()) {
            req.set_connection_close();
        }
        if (!req.body.empty() &&
            req.headers.find("Content-Length") == req.headers.end()) {
            req.set_content_length();
        }

        // 发送请求
        std::string raw = req.serialize();
        auto write_result = co_await socket.write_all(raw);
        if (write_result.is_err()) {
            co_return IoResult<HttpResponse>(write_result.error());
        }

        // 读取响应
        BufferedSocket buffered(std::move(socket));
        HttpResponse response;

        // 解析状态行
        auto status_result = co_await buffered.read_line();
        if (status_result.is_err()) {
            co_return IoResult<HttpResponse>(status_result.error());
        }

        if (!parse_status_line(status_result.value(), response)) {
            co_return IoResult<HttpResponse>(IoError(EBADMSG));
        }

        // 解析头部
        while (true) {
            auto header_result = co_await buffered.read_line();
            if (header_result.is_err()) {
                co_return IoResult<HttpResponse>(header_result.error());
            }

            std::string line = header_result.value();

            // 去除\r\n
            while (!line.empty() &&
                   (line.back() == '\r' || line.back() == '\n')) {
                line.pop_back();
            }

            if (line.empty()) {
                break;  // 头部结束
            }

            auto colon = line.find(':');
            if (colon != std::string::npos) {
                std::string key = line.substr(0, colon);
                std::string value = line.substr(colon + 1);
                // 去除前导空格
                while (!value.empty() && value.front() == ' ') {
                    value.erase(0, 1);
                }
                response.headers[key] = value;
            }
        }

        // 读取body
        size_t content_length = response.content_length();
        if (content_length > 0) {
            auto body_result = co_await buffered.read_exact(content_length);
            if (body_result.is_err()) {
                co_return IoResult<HttpResponse>(body_result.error());
            }
            auto& data = body_result.value();
            response.body = std::string(data.begin(), data.end());
        }

        co_return IoResult<HttpResponse>(std::move(response));
    }

    // GET请求
    Task<IoResult<HttpResponse>> get(const std::string& path) {
        HttpRequest req;
        req.method = "GET";
        req.path = path;
        return request(std::move(req));
    }

    // POST请求
    Task<IoResult<HttpResponse>> post(const std::string& path,
                                       std::string body,
                                       std::string content_type = "text/plain") {
        HttpRequest req;
        req.method = "POST";
        req.path = path;
        req.body = std::move(body);
        req.set_content_type(content_type);
        return request(std::move(req));
    }

private:
    static bool parse_status_line(const std::string& line,
                                   HttpResponse& response) {
        std::istringstream ss(line);
        ss >> response.version >> response.status_code;
        std::getline(ss, response.reason);

        // 去除前导空格
        while (!response.reason.empty() && response.reason.front() == ' ') {
            response.reason.erase(0, 1);
        }
        // 去除\r\n
        while (!response.reason.empty() &&
               (response.reason.back() == '\r' ||
                response.reason.back() == '\n')) {
            response.reason.pop_back();
        }

        return response.status_code > 0;
    }
};

// 使用示例
/*
Task<void> http_example() {
    HttpClient client("httpbin.org", 80);

    auto response = co_await client.get("/get");
    if (response.is_ok()) {
        std::cout << "Status: " << response.value().status_code << "\n";
        std::cout << "Body: " << response.value().body << "\n";
    }

    auto post_response = co_await client.post("/post", "{\"hello\":\"world\"}",
                                               "application/json");
    if (post_response.is_ok()) {
        std::cout << "POST Status: " << post_response.value().status_code << "\n";
    }
}
*/
```

### Day 26-27：综合项目

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | 项目整合 | 2h |
| 下午 | 性能测试 | 3h |
| 晚上 | 优化改进 | 2h |

#### 简易聊天服务器

```cpp
// ============================================================
// chat_server.cpp - 简易聊天服务器
// ============================================================

#include "async_tcp_listener.hpp"
#include "buffered_socket.hpp"
#include "channel.hpp"
#include <set>
#include <mutex>

// 聊天消息
struct ChatMessage {
    std::string sender;
    std::string content;
    std::chrono::system_clock::time_point timestamp;
};

// 聊天室
class ChatRoom {
private:
    std::mutex mutex_;
    std::set<Channel<ChatMessage>*> subscribers_;

public:
    // 订阅
    void subscribe(Channel<ChatMessage>* ch) {
        std::lock_guard lock(mutex_);
        subscribers_.insert(ch);
    }

    // 取消订阅
    void unsubscribe(Channel<ChatMessage>* ch) {
        std::lock_guard lock(mutex_);
        subscribers_.erase(ch);
    }

    // 广播消息
    void broadcast(ChatMessage msg) {
        std::lock_guard lock(mutex_);
        for (auto* ch : subscribers_) {
            ch->try_send(msg);  // 非阻塞发送
        }
    }

    size_t subscriber_count() const {
        std::lock_guard lock(mutex_);
        return subscribers_.size();
    }
};

// 聊天客户端处理
Task<void> chat_client(AsyncTcpSocket socket,
                       SocketAddress addr,
                       ChatRoom& room) {
    BufferedSocket buffered(std::move(socket));
    Channel<ChatMessage> inbox(16);

    // 获取用户名
    co_await buffered.write("Enter your name: ");
    auto name_result = co_await buffered.read_line();
    if (name_result.is_err() || name_result.value().empty()) {
        co_return;
    }

    std::string username = name_result.value();
    // 去除换行
    while (!username.empty() &&
           (username.back() == '\r' || username.back() == '\n')) {
        username.pop_back();
    }

    // 订阅聊天室
    room.subscribe(&inbox);
    room.broadcast({username, " joined the chat", std::chrono::system_clock::now()});

    // 并发处理：发送和接收
    auto sender = [&]() -> Task<void> {
        while (true) {
            auto msg = co_await inbox.receive();
            if (!msg) break;

            std::string line = "[" + msg->sender + "] " + msg->content + "\n";
            auto result = co_await buffered.write(line);
            if (result.is_err()) break;
        }
    }();

    auto receiver = [&]() -> Task<void> {
        while (true) {
            auto line_result = co_await buffered.read_line();
            if (line_result.is_err()) break;

            std::string content = line_result.value();
            if (content.empty()) break;

            // 去除换行
            while (!content.empty() &&
                   (content.back() == '\r' || content.back() == '\n')) {
                content.pop_back();
            }

            if (content == "/quit") break;

            room.broadcast({username, content, std::chrono::system_clock::now()});
        }

        inbox.close();
    }();

    co_await receiver;
    co_await sender;

    room.unsubscribe(&inbox);
    room.broadcast({username, " left the chat", std::chrono::system_clock::now()});
}

// 聊天服务器主函数
Task<void> run_chat_server(uint16_t port) {
    ChatRoom room;

    auto listener_result = co_await AsyncTcpListener::bind(
        SocketAddress::from_ipv4("0.0.0.0", port));

    if (listener_result.is_err()) {
        std::cerr << "Failed to bind\n";
        co_return;
    }

    auto& listener = listener_result.value();
    std::cout << "Chat server listening on port " << port << "\n";

    while (true) {
        auto accept_result = co_await listener.accept();
        if (accept_result.is_err()) continue;

        auto [socket, addr] = std::move(accept_result.value());
        spawn_detached(chat_client(std::move(socket), addr, room));
    }
}
```

### Day 28：月度总结与性能测试

#### 性能基准测试

```cpp
// ============================================================
// 性能测试
// ============================================================

#include <chrono>
#include <iostream>

// Echo服务器性能测试
Task<void> benchmark_echo(const std::string& host, uint16_t port,
                          int num_requests, size_t message_size) {
    std::vector<char> message(message_size, 'X');
    std::vector<char> buffer(message_size);

    auto start = std::chrono::high_resolution_clock::now();

    auto socket_result = AsyncTcpSocket::create();
    if (socket_result.is_err()) {
        std::cerr << "Failed to create socket\n";
        co_return;
    }

    auto& socket = socket_result.value();
    auto connect_result = co_await socket.connect(
        SocketAddress::from_host(host, port));
    if (connect_result.is_err()) {
        std::cerr << "Failed to connect\n";
        co_return;
    }

    for (int i = 0; i < num_requests; ++i) {
        // 发送
        auto write_result = co_await socket.write_all(
            message.data(), message.size());
        if (write_result.is_err()) break;

        // 接收
        auto read_result = co_await socket.read_exact(
            buffer.data(), buffer.size());
        if (read_result.is_err()) break;
    }

    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(
        end - start);

    double rps = num_requests * 1000.0 / duration.count();
    double mbps = num_requests * message_size * 2.0 / duration.count() / 1024;

    std::cout << "=== Echo Benchmark Results ===\n";
    std::cout << "Requests: " << num_requests << "\n";
    std::cout << "Message size: " << message_size << " bytes\n";
    std::cout << "Duration: " << duration.count() << " ms\n";
    std::cout << "RPS: " << rps << "\n";
    std::cout << "Throughput: " << mbps << " MB/s\n";
}

// 协程创建性能
void benchmark_coroutine_creation() {
    constexpr int N = 1000000;

    auto start = std::chrono::high_resolution_clock::now();

    for (int i = 0; i < N; ++i) {
        auto task = []() -> Task<int> {
            co_return 42;
        }();
    }

    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::microseconds>(
        end - start);

    std::cout << "=== Coroutine Creation Benchmark ===\n";
    std::cout << "Created " << N << " coroutines in "
              << duration.count() << " us\n";
    std::cout << "Average: " << (duration.count() * 1000.0 / N)
              << " ns per coroutine\n";
}

/*
典型性能指标（参考）：
┌─────────────────────────────────────────────────────────────┐
│              协程网络库性能基准                              │
├─────────────────┬───────────────────────────────────────────┤
│ 测试项目        │ 典型结果                                   │
├─────────────────┼───────────────────────────────────────────┤
│ 协程创建        │ 50-100 ns/个                              │
│ 协程切换        │ 10-30 ns/次                               │
│ Echo延迟        │ < 0.1 ms (本地)                           │
│ Echo吞吐        │ 100+ MB/s (单连接)                        │
│ 并发连接        │ 10000+ (ulimit允许的情况下)               │
│ 内存占用        │ ~200-500 bytes/协程帧                     │
└─────────────────┴───────────────────────────────────────────┘
*/
```

#### 第四周检验标准

- [ ] 实现完整的Echo服务器
- [ ] 实现连接限制和超时机制
- [ ] 实现HTTP/1.1客户端（GET/POST）
- [ ] 理解HTTP协议解析
- [ ] 完成性能基准测试
- [ ] 理解协程网络编程的优势和限制

---

## 本月检验标准总览

### 理论知识

- [ ] 理解epoll/kqueue的工作原理和差异
- [ ] 能解释事件循环的核心机制
- [ ] 理解如何将阻塞I/O封装为Awaitable
- [ ] 掌握超时和取消机制的实现
- [ ] 能对比协程与线程/回调/Future的优劣

### 实践能力

- [ ] 实现跨平台I/O多路复用抽象（IoMultiplexer）
- [ ] 实现完整的EventLoop（定时器+I/O+协程调度）
- [ ] 实现AsyncRead/AsyncWrite Awaitable
- [ ] 实现超时（WithTimeout）和取消（CancellationToken）
- [ ] 实现AsyncTcpSocket和AsyncTcpListener
- [ ] 实现缓冲I/O（ReadBuffer/WriteBuffer/BufferedSocket）

### 综合项目

- [ ] 完成高并发Echo服务器
- [ ] 完成HTTP/1.1客户端
- [ ] 理解性能调优基础
- [ ] 代码能在Linux和macOS上编译运行

---

## 输出物清单

### 核心代码文件

1. **io_multiplexer.hpp** - I/O多路复用抽象接口
   - IoEvent枚举
   - IoEventResult结构
   - IoMultiplexer基类

2. **epoll_multiplexer.hpp** - Linux epoll实现

3. **kqueue_multiplexer.hpp** - macOS kqueue实现

4. **event_loop.hpp** - 事件循环核心
   - TimerQueue定时器队列
   - EventLoop主类
   - yield/sleep_for辅助函数

5. **io_awaitable.hpp** - I/O Awaitable
   - IoError错误类
   - IoResult<T>结果类型
   - AsyncRead/AsyncWrite

6. **timeout.hpp** - 超时机制
   - TimeoutResult
   - WithTimeout Awaitable

7. **cancellation.hpp** - 取消机制
   - CancellationToken
   - CancelledException

8. **fd.hpp** - 文件描述符RAII

9. **socket_address.hpp** - 网络地址封装

10. **async_tcp_socket.hpp** - 异步TCP Socket

11. **async_tcp_listener.hpp** - 异步TCP监听器

12. **buffer.hpp** - 缓冲区
    - ReadBuffer
    - WriteBuffer

13. **buffered_socket.hpp** - 带缓冲的Socket

14. **http.hpp** - HTTP协议支持
    - HttpRequest
    - HttpResponse
    - HttpClient

### 示例程序

15. **examples/**
    - `echo_server.cpp` - 简单Echo服务器
    - `echo_server_limited.cpp` - 带限流的Echo服务器
    - `http_client_example.cpp` - HTTP客户端示例
    - `chat_server.cpp` - 简易聊天室

### 测试与基准

16. **tests/**
    - `test_event_loop.cpp` - 事件循环测试
    - `test_io_awaitable.cpp` - I/O Awaitable测试
    - `test_socket.cpp` - Socket测试

17. **benchmark/**
    - `echo_bench.cpp` - Echo吞吐量测试
    - `coroutine_bench.cpp` - 协程创建性能测试

### 学习笔记

18. **notes/**
    - `month22_week1_event_loop.md` - 事件循环设计
    - `month22_week2_io_awaitable.md` - 异步I/O封装
    - `month22_week3_socket.md` - Socket封装
    - `month22_week4_applications.md` - 实际应用

---

## 下月预告

Month 23将学习**并发模式与最佳实践**，总结常见的并发设计模式：

- 生产者-消费者模式
- 读写锁模式
- 工作窃取模式
- 无锁数据结构应用场景
- 并发调试与测试技巧
- 性能分析与优化

掌握本月协程异步I/O后，下月将对所有并发知识进行系统总结！
