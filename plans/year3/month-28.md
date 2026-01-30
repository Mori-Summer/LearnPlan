# Month 28: io_uring——新一代异步I/O

## 本月主题概述

io_uring是Linux 5.1引入的革命性异步I/O框架。与传统的epoll+read/write模式不同，io_uring通过共享内存的环形缓冲区实现了真正的零系统调用开销I/O。本月将从设计原理、liburing API、高级特性到实战应用，全面深入学习io_uring，并与Month-27学习的epoll进行性能对比，理解新一代I/O框架的优势与适用场景。

---

## 知识体系总览

```
Month 28 知识体系：io_uring深度解析
=====================================================

                    ┌─────────────────────┐
                    │   io_uring深度解析   │
                    │  新一代异步I/O框架   │
                    └──────────┬──────────┘
                               │
         ┌─────────────────────┼─────────────────────┐
         │                     │                     │
         ▼                     ▼                     ▼
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│  核心架构   │      │  liburing   │      │  高级特性   │
│             │      │             │      │             │
│ SQ提交队列  │      │ queue_init  │      │ SQPOLL模式  │
│ CQ完成队列  │      │ get_sqe     │      │ 注册优化    │
│ 共享内存    │      │ submit/wait │      │ 链接操作    │
│ 零拷贝设计  │      │ prep_*系列  │      │ 超时/取消   │
└──────┬──────┘      └──────┬──────┘      └──────┬──────┘
       │                    │                    │
       ▼                    ▼                    ▼
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│  内核原理   │      │  I/O操作    │      │  实战应用   │
│             │      │             │      │             │
│ SQE/CQE结构 │      │ 文件I/O     │      │ Echo服务器  │
│ 环形缓冲区  │      │ 网络I/O     │      │ HTTP服务器  │
│ 内存屏障    │      │ 批量处理    │      │ 性能对比    │
│ 并发控制    │      │ 上下文关联  │      │ 生产实践    │
└─────────────┘      └─────────────┘      └─────────────┘

承接关系：
Month-27 (epoll深度解析——事件驱动I/O)
    │
    ▼
Month-28 (io_uring——新一代异步I/O) ← 当前月份
    │
    ▼
Month-29 (零拷贝技术——sendfile/splice/mmap)
```

---

## 学习目标

### 核心目标

1. **理解io_uring设计原理**：共享内存、环形缓冲区、零系统调用开销
2. **掌握liburing核心API**：queue_init、get_sqe、submit、wait_cqe系列
3. **精通文件与网络I/O**：prep_read/write、prep_accept/recv/send
4. **掌握高级特性**：SQPOLL、注册优化、链接操作、超时控制
5. **构建高性能服务器**：io_uring Echo/HTTP服务器，与epoll性能对比

### 学习目标量化

| 目标 | 量化标准 | 验证方式 |
|------|---------|---------|
| io_uring原理理解 | 能画出SQ/CQ环形缓冲区结构 | 白板绘图 |
| liburing API掌握 | 能独立编写io_uring文件读写 | 代码实现 |
| 网络I/O能力 | 能实现io_uring echo server | 代码运行 |
| SQPOLL理解 | 能配置并测试SQPOLL模式 | 性能对比 |
| 注册优化掌握 | 能使用register_files/buffers | 代码实现 |
| 链接操作掌握 | 能实现read→process→write链 | 代码运行 |
| 性能对比能力 | 完成io_uring vs epoll基准测试 | 测试报告 |
| 生产实践 | 能处理错误和内核兼容性 | 代码审查 |

---

## 综合项目概述

### 本月最终项目：高性能io_uring服务器框架

```
项目目标：构建基于io_uring的高性能网络服务器，并与epoll对比

功能架构：
┌─────────────────────────────────────────────────┐
│              Application Layer                  │
│  ┌──────────┐ ┌──────────┐ ┌───────────────┐   │
│  │EchoServer│ │HTTPServer│ │BenchmarkTool  │   │
│  └────┬─────┘ └────┬─────┘ └───────┬───────┘   │
│       └─────────────┼───────────────┘           │
│                     ▼                           │
│  ┌─────────────────────────────────────────┐    │
│  │         IoUringServer Framework         │    │
│  │  ┌───────────┐  ┌────────────────────┐  │    │
│  │  │ Request   │  │ BufferPool         │  │    │
│  │  │ StateMachine│ │ 缓冲区池管理      │  │    │
│  │  └───────────┘  └────────────────────┘  │    │
│  └──────────────────┬──────────────────────┘    │
│                     ▼                           │
│  ┌─────────────────────────────────────────┐    │
│  │           io_uring Core                 │    │
│  │  ┌─────────┐ ┌────────┐ ┌──────────┐   │    │
│  │  │   SQ    │ │   CQ   │ │ SQPOLL   │   │    │
│  │  │提交队列 │ │完成队列│ │内核轮询  │   │    │
│  │  └─────────┘ └────────┘ └──────────┘   │    │
│  └──────────────────┬──────────────────────┘    │
│                     ▼                           │
│  ┌─────────────────────────────────────────┐    │
│  │         Linux Kernel (5.1+)             │    │
│  │  ┌──────────┐        ┌──────────┐       │    │
│  │  │共享内存  │        │异步完成  │       │    │
│  │  │零拷贝    │───────>│回调通知  │       │    │
│  │  └──────────┘        └──────────┘       │    │
│  └─────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘

性能目标：
- 并发连接：10,000+
- 吞吐量：比epoll提升20%+
- 系统调用：减少50%+
- 延迟P99：<3ms
```

---

## 参考书目与资料

| 资料 | 用途 | 优先级 |
|------|------|--------|
| [io_uring官方文档](https://kernel.dk/io_uring.pdf) | 原理与设计 | ★★★ |
| `man io_uring` / `man io_uring_setup` | API参考 | ★★★ |
| [liburing GitHub](https://github.com/axboe/liburing) | 源码与示例 | ★★★ |
| Jens Axboe的演讲与文章 | 设计思想 | ★★☆ |
| Linux内核源码 `io_uring/` | 内核实现 | ★★☆ |
| LWN.net io_uring系列文章 | 深度分析 | ★☆☆ |

---

## 前置知识衔接

```
Month-27 → Month-28 知识桥梁
═══════════════════════════════════════════════════

Month-27已掌握：                 Month-28将学习：
┌──────────────────┐            ┌──────────────────┐
│ epoll事件驱动    │───────────>│ io_uring异步I/O  │
│ epoll_wait等待   │            │ submit+wait模式  │
│ 仍需read/write   │            │ 真正零拷贝      │
├──────────────────┤            ├──────────────────┤
│ ET/LT触发模式   │───────────>│ 提交-完成模型   │
│ 回调通知         │            │ 环形缓冲区      │
│ 事件驱动         │            │ 批量处理        │
├──────────────────┤            ├──────────────────┤
│ 非阻塞I/O       │───────────>│ 异步I/O         │
│ EAGAIN处理       │            │ 完成队列轮询    │
│ 循环读写         │            │ 无需EAGAIN      │
├──────────────────┤            ├──────────────────┤
│ timerfd/eventfd │───────────>│ prep_timeout    │
│ signalfd         │            │ 链接操作        │
│ 统一fd管理       │            │ 统一操作模型    │
└──────────────────┘            └──────────────────┘

关键区别：
┌────────────────────────────────────────────────┐
│            epoll vs io_uring                   │
├────────────────┬───────────────────────────────┤
│                │ epoll            │ io_uring   │
├────────────────┼──────────────────┼────────────┤
│ 事件通知       │ 就绪通知         │ 完成通知   │
│ I/O执行        │ 用户态read/write │ 内核异步   │
│ 系统调用       │ 每次I/O都需要    │ 批量提交   │
│ 数据拷贝       │ 用户↔内核        │ 零拷贝可选 │
│ 编程模型       │ 事件驱动         │ 提交-完成  │
└────────────────┴──────────────────┴────────────┘
```

---

## 时间分配

| 内容 | 时间 | 占比 |
|------|------|------|
| 第一周：io_uring基础概念与环境搭建 | 35小时 | 25% |
| 第二周：io_uring核心API详解 | 35小时 | 25% |
| 第三周：io_uring高级特性 | 35小时 | 25% |
| 第四周：io_uring实战与性能对比 | 35小时 | 25% |
| **合计** | **140小时** | **100%** |

---

## 第一周：io_uring基础概念与环境搭建（Day 1-7）

### 本周时间分配

| 日期 | 内容 | 时间 |
|------|------|------|
| Day 1-2 | io_uring设计动机与架构 | 10小时 |
| Day 3-4 | liburing安装与基础API | 10小时 |
| Day 5-7 | io_uring内核实现原理 | 15小时 |

---

### Day 1-2：io_uring设计动机与架构（10小时）

#### 学习目标

- 理解传统I/O和epoll的系统调用开销问题
- 掌握io_uring的核心设计理念
- 理解SQ/CQ/SQE/CQE四大核心概念

#### 为什么需要io_uring

```
═══════════════════════════════════════════════════════════
传统I/O的系统调用开销问题
═══════════════════════════════════════════════════════════

传统阻塞I/O：
┌─────────┐                    ┌─────────┐
│ 用户态  │                    │ 内核态  │
│         │    read()          │         │
│  App    │ ─────────────────> │  Kernel │
│         │ <───────────────── │         │
│         │    返回数据        │         │
└─────────┘                    └─────────┘
    │                              │
    └── 阻塞等待，线程挂起 ────────┘

问题：每个连接一个线程 → C10K问题


epoll + 非阻塞I/O（Month-27学习的）：
┌─────────┐                    ┌─────────┐
│ 用户态  │                    │ 内核态  │
│         │    epoll_wait()    │         │
│  App    │ ─────────────────> │ epoll   │
│         │ <───────────────── │         │
│         │    返回就绪fd      │         │
│         │                    │         │
│         │    read(fd)        │         │
│  App    │ ─────────────────> │ socket  │
│         │ <───────────────── │         │
│         │    返回数据        │         │
└─────────┘                    └─────────┘

优点：单线程处理多连接
缺点：每次I/O仍需系统调用
     epoll_wait → read → write → epoll_wait ...
     高频系统调用开销依然存在


系统调用的开销组成：
┌─────────────────────────────────────────────┐
│ 系统调用开销 ≈ 100-1000个CPU周期            │
├─────────────────────────────────────────────┤
│ 1. 用户态→内核态切换（寄存器保存）          │
│ 2. 安全检查（权限验证）                      │
│ 3. 参数从用户空间拷贝到内核                 │
│ 4. 执行实际操作                              │
│ 5. 结果从内核拷贝到用户空间                 │
│ 6. 内核态→用户态切换（寄存器恢复）          │
└─────────────────────────────────────────────┘

高频I/O场景下（10万+ QPS），系统调用开销显著！


═══════════════════════════════════════════════════════════
io_uring的革命性设计
═══════════════════════════════════════════════════════════

核心思想：通过共享内存消除系统调用开销

io_uring架构：
┌─────────────────────────────────────────────────────────┐
│                    共享内存区域                         │
│  ┌─────────────────────────┐ ┌────────────────────────┐│
│  │    SQ (Submission Queue)│ │  CQ (Completion Queue) ││
│  │    提交队列             │ │  完成队列              ││
│  │  ┌───┬───┬───┬───┬───┐ │ │┌───┬───┬───┬───┬───┐  ││
│  │  │SQE│SQE│SQE│...│   │ │ ││CQE│CQE│CQE│...│   │  ││
│  │  └───┴───┴───┴───┴───┘ │ │└───┴───┴───┴───┴───┘  ││
│  │       head↑    ↑tail   │ │    head↑    ↑tail     ││
│  └─────────────────────────┘ └────────────────────────┘│
└─────────────────────────────────────────────────────────┘
         │                              ▲
         │ 用户写入SQE                  │ 内核写入CQE
         ▼                              │
┌─────────────┐                ┌─────────────┐
│   用户态    │                │   内核态    │
│             │                │             │
│ 1.准备SQE   │                │ 3.执行I/O   │
│ 2.提交请求  │ ─────────────> │ 4.写入CQE   │
│ 5.读取CQE   │ <───────────── │             │
│ 6.处理结果  │                │             │
└─────────────┘                └─────────────┘

关键优势：
1. 批量提交：一次submit提交多个SQE
2. 批量完成：一次获取多个CQE
3. 共享内存：减少用户↔内核数据拷贝
4. SQPOLL模式：甚至不需要submit系统调用！
```

#### SQ/CQ/SQE/CQE核心概念

```
═══════════════════════════════════════════════════════════
io_uring四大核心概念
═══════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────┐
│ 概念        │ 全称                    │ 说明           │
├─────────────┼─────────────────────────┼────────────────┤
│ SQ          │ Submission Queue        │ 提交队列       │
│ CQ          │ Completion Queue        │ 完成队列       │
│ SQE         │ Submission Queue Entry  │ 提交队列条目   │
│ CQE         │ Completion Queue Entry  │ 完成队列条目   │
└─────────────┴─────────────────────────┴────────────────┘


SQE结构体（用户填写，描述一个I/O请求）：
┌─────────────────────────────────────────────────────────┐
│ struct io_uring_sqe {                                   │
│     __u8   opcode;      // 操作类型：READ/WRITE/ACCEPT │
│     __u8   flags;       // 标志：IOSQE_IO_LINK等       │
│     __u16  ioprio;      // I/O优先级                   │
│     __s32  fd;          // 文件描述符                  │
│     union {                                             │
│         __u64 off;      // 文件偏移                    │
│         __u64 addr2;    // 第二地址（某些操作需要）    │
│     };                                                  │
│     union {                                             │
│         __u64 addr;     // 缓冲区地址                  │
│         __u64 splice_off_in;                           │
│     };                                                  │
│     __u32  len;         // 缓冲区长度                  │
│     union {                                             │
│         __kernel_rwf_t rw_flags;  // 读写标志         │
│         __u32 fsync_flags;                             │
│         __u32 poll_events;                             │
│         __u32 sync_range_flags;                        │
│         __u32 msg_flags;                               │
│         __u32 timeout_flags;                           │
│         __u32 accept_flags;                            │
│         __u32 cancel_flags;                            │
│         ...                                             │
│     };                                                  │
│     __u64  user_data;   // 用户数据（回传给CQE）       │
│     ...                                                 │
│ };                                                      │
└─────────────────────────────────────────────────────────┘


CQE结构体（内核填写，描述一个I/O完成结果）：
┌─────────────────────────────────────────────────────────┐
│ struct io_uring_cqe {                                   │
│     __u64  user_data;   // 来自SQE的用户数据           │
│     __s32  res;         // 结果（成功：字节数/fd）     │
│                         // （失败：负的errno）         │
│     __u32  flags;       // 标志（如IORING_CQE_F_MORE） │
│ };                                                      │
└─────────────────────────────────────────────────────────┘


环形缓冲区工作原理：
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  SQ Ring（提交队列）:                                   │
│                                                         │
│  head                    tail                           │
│   ↓                       ↓                             │
│  ┌───┬───┬───┬───┬───┬───┬───┬───┐                     │
│  │ 2 │ 3 │ 4 │   │   │   │   │   │  ← SQE索引数组     │
│  └───┴───┴───┴───┴───┴───┴───┴───┘                     │
│                                                         │
│  内核从head读取SQE索引，执行I/O                        │
│  用户向tail写入SQE索引                                 │
│                                                         │
│  CQ Ring（完成队列）:                                   │
│                                                         │
│  head                    tail                           │
│   ↓                       ↓                             │
│  ┌─────┬─────┬─────┬─────┬─────┬─────┐                 │
│  │CQE-0│CQE-1│CQE-2│     │     │     │                 │
│  └─────┴─────┴─────┴─────┴─────┴─────┘                 │
│                                                         │
│  用户从head读取CQE，处理结果                           │
│  内核向tail写入CQE                                     │
│                                                         │
└─────────────────────────────────────────────────────────┘

为什么是"环形"缓冲区？
- 使用mask实现循环：index = (head/tail) & ring_mask
- 无需移动数据，只需移动指针
- 高效的无锁并发访问
```

#### 代码示例1：io_uring vs epoll架构对比

```cpp
// 示例1: arch_comparison.cpp
// io_uring与epoll架构对比演示
// 展示两种模式的编程差异

#include <cstdio>

/*
═══════════════════════════════════════════════════════════
epoll模式的Echo服务器（伪代码）
═══════════════════════════════════════════════════════════

void epoll_echo_server() {
    int epfd = epoll_create1(0);
    // 注册listen_fd
    epoll_ctl(epfd, EPOLL_CTL_ADD, listen_fd, &ev);

    while (true) {
        // 系统调用1：等待事件
        int n = epoll_wait(epfd, events, MAX_EVENTS, -1);

        for (int i = 0; i < n; i++) {
            if (events[i].data.fd == listen_fd) {
                // 系统调用2：接受连接
                int client_fd = accept(listen_fd, ...);
                epoll_ctl(epfd, EPOLL_CTL_ADD, client_fd, &ev);
            } else {
                // 系统调用3：读取数据
                ssize_t len = read(fd, buf, sizeof(buf));
                // 系统调用4：发送数据
                write(fd, buf, len);
            }
        }
    }
}

每个连接的请求-响应：至少2个系统调用（read + write）
加上epoll_wait，高频场景下系统调用开销显著


═══════════════════════════════════════════════════════════
io_uring模式的Echo服务器（伪代码）
═══════════════════════════════════════════════════════════

void io_uring_echo_server() {
    struct io_uring ring;
    io_uring_queue_init(QUEUE_DEPTH, &ring, 0);

    // 准备accept的SQE
    sqe = io_uring_get_sqe(&ring);
    io_uring_prep_accept(sqe, listen_fd, ...);
    io_uring_sqe_set_data(sqe, &accept_request);

    while (true) {
        // 系统调用：提交所有SQE并等待CQE
        io_uring_submit_and_wait(&ring, 1);

        // 批量处理所有完成的CQE（无系统调用）
        io_uring_for_each_cqe(&ring, head, cqe) {
            Request* req = io_uring_cqe_get_data(cqe);

            switch (req->type) {
                case ACCEPT:
                    // 准备recv的SQE（无系统调用）
                    sqe = io_uring_get_sqe(&ring);
                    io_uring_prep_recv(sqe, cqe->res, ...);
                    break;
                case RECV:
                    // 准备send的SQE（无系统调用）
                    sqe = io_uring_get_sqe(&ring);
                    io_uring_prep_send(sqe, req->fd, ...);
                    break;
                case SEND:
                    // 准备下一次recv的SQE（无系统调用）
                    sqe = io_uring_get_sqe(&ring);
                    io_uring_prep_recv(sqe, req->fd, ...);
                    break;
            }
        }
        io_uring_cq_advance(&ring, count);
    }
}

关键区别：
- 准备SQE：写共享内存，无系统调用
- 提交请求：一次submit提交所有
- 获取结果：读共享内存，无系统调用
- 批量处理：一次处理多个完成事件

系统调用数量对比（处理N个请求）：
┌─────────────────┬─────────────┬─────────────┐
│ 操作            │ epoll       │ io_uring    │
├─────────────────┼─────────────┼─────────────┤
│ 等待/提交       │ N次         │ ~N/batch次  │
│ 读取数据        │ N次         │ 0次*        │
│ 发送数据        │ N次         │ 0次*        │
├─────────────────┼─────────────┼─────────────┤
│ 总计            │ ~3N次       │ ~N/batch次  │
└─────────────────┴─────────────┴─────────────┘
* io_uring的I/O操作由内核异步执行，用户态无系统调用
*/

int main() {
    printf("io_uring vs epoll Architecture Comparison\n");
    printf("==========================================\n\n");

    printf("epoll模式：\n");
    printf("  - epoll_wait()：系统调用，等待事件\n");
    printf("  - read()：系统调用，读取数据\n");
    printf("  - write()：系统调用，发送数据\n");
    printf("  - 每个请求约3个系统调用\n\n");

    printf("io_uring模式：\n");
    printf("  - io_uring_get_sqe()：写共享内存\n");
    printf("  - io_uring_prep_*()：写共享内存\n");
    printf("  - io_uring_submit()：一次系统调用提交多个\n");
    printf("  - io_uring_for_each_cqe()：读共享内存\n");
    printf("  - 批量处理，系统调用减少50%%+\n\n");

    printf("SQPOLL模式（高级）：\n");
    printf("  - 内核线程轮询SQ，甚至不需要submit系统调用\n");
    printf("  - 极低延迟场景的终极优化\n");

    return 0;
}
```

#### 代码示例2：io_uring基本用法——标准输入读取

```cpp
// 示例2: io_uring_stdin_demo.cpp
// io_uring基本用法演示——从标准输入读取
// 展示io_uring最基本的工作流程

#include <liburing.h>
#include <unistd.h>
#include <cstdio>
#include <cstring>
#include <cerrno>

#define QUEUE_DEPTH 4
#define BUFFER_SIZE 256

int main() {
    struct io_uring ring;
    int ret;

    // Step 1: 初始化io_uring实例
    ret = io_uring_queue_init(QUEUE_DEPTH, &ring, 0);
    if (ret < 0) {
        fprintf(stderr, "io_uring_queue_init failed: %s\n", strerror(-ret));
        return 1;
    }
    printf("io_uring initialized, queue depth = %d\n", QUEUE_DEPTH);

    // 准备缓冲区
    char buffer[BUFFER_SIZE];
    memset(buffer, 0, sizeof(buffer));

    printf("Type something and press Enter (or Ctrl+D to quit):\n");

    while (true) {
        // Step 2: 获取一个SQE（Submission Queue Entry）
        struct io_uring_sqe* sqe = io_uring_get_sqe(&ring);
        if (!sqe) {
            fprintf(stderr, "Failed to get SQE\n");
            break;
        }

        // Step 3: 准备读操作
        // io_uring_prep_read(sqe, fd, buf, len, offset)
        // 对于stdin，offset通常设为0
        io_uring_prep_read(sqe, STDIN_FILENO, buffer, sizeof(buffer) - 1, 0);

        // Step 4: 设置用户数据（可选，用于识别请求）
        io_uring_sqe_set_data(sqe, (void*)0x12345678);

        // Step 5: 提交请求
        ret = io_uring_submit(&ring);
        if (ret < 0) {
            fprintf(stderr, "io_uring_submit failed: %s\n", strerror(-ret));
            break;
        }
        printf("Submitted 1 request, waiting for completion...\n");

        // Step 6: 等待完成
        struct io_uring_cqe* cqe;
        ret = io_uring_wait_cqe(&ring, &cqe);
        if (ret < 0) {
            fprintf(stderr, "io_uring_wait_cqe failed: %s\n", strerror(-ret));
            break;
        }

        // Step 7: 处理完成结果
        void* user_data = io_uring_cqe_get_data(cqe);
        printf("CQE received: user_data=%p, res=%d\n", user_data, cqe->res);

        if (cqe->res < 0) {
            // 错误
            fprintf(stderr, "Read error: %s\n", strerror(-cqe->res));
        } else if (cqe->res == 0) {
            // EOF (Ctrl+D)
            printf("EOF received, exiting.\n");
            io_uring_cqe_seen(&ring, cqe);
            break;
        } else {
            // 成功读取
            buffer[cqe->res] = '\0';
            printf("Read %d bytes: %s", cqe->res, buffer);
        }

        // Step 8: 标记CQE已处理
        io_uring_cqe_seen(&ring, cqe);

        // 清空缓冲区，准备下一次读取
        memset(buffer, 0, sizeof(buffer));
    }

    // Step 9: 清理
    io_uring_queue_exit(&ring);
    printf("io_uring cleaned up.\n");

    return 0;
}

/*
编译（需要安装liburing）：
$ sudo apt install liburing-dev  # Ubuntu/Debian
$ g++ -o io_uring_demo io_uring_stdin_demo.cpp -luring

运行：
$ ./io_uring_demo
io_uring initialized, queue depth = 4
Type something and press Enter (or Ctrl+D to quit):
Hello io_uring!
Submitted 1 request, waiting for completion...
CQE received: user_data=0x12345678, res=16
Read 16 bytes: Hello io_uring!


io_uring基本工作流程：
┌────────────────────────────────────────────────┐
│ 1. io_uring_queue_init()  初始化              │
│ 2. io_uring_get_sqe()     获取SQE             │
│ 3. io_uring_prep_*()      准备操作            │
│ 4. io_uring_sqe_set_data() 设置用户数据       │
│ 5. io_uring_submit()      提交请求            │
│ 6. io_uring_wait_cqe()    等待完成            │
│ 7. 处理cqe->res结果                           │
│ 8. io_uring_cqe_seen()    标记CQE已处理       │
│ 9. io_uring_queue_exit()  清理                │
└────────────────────────────────────────────────┘
*/
```

#### Day 1-2 自测题

```
Q1: io_uring相比epoll最大的优势是什么？
A1: io_uring通过共享内存减少了系统调用开销：
    - epoll模式：每次I/O（read/write）都是系统调用
    - io_uring模式：准备SQE是写共享内存，获取CQE是读共享内存
    - 批量提交：一次submit提交多个请求
    - SQPOLL模式甚至可以不需要submit系统调用

Q2: SQ和CQ分别是什么？为什么需要两个队列？
A2: SQ (Submission Queue) 是提交队列，用户向其中写入SQE描述I/O请求
    CQ (Completion Queue) 是完成队列，内核向其中写入CQE描述I/O结果
    分开的原因：
    1. 解耦提交和完成：提交和完成是异步的，频率可能不同
    2. 并发控制：用户写SQ，内核写CQ，互不干扰
    3. 灵活性：CQ可以比SQ大（一个SQE可能产生多个CQE）

Q3: user_data字段的作用是什么？
A3: user_data是用户自定义的64位数据，从SQE传递到CQE。
    主要用途：
    1. 关联请求上下文：将Request*指针存入，完成时取出
    2. 区分请求类型：如ACCEPT=1, READ=2, WRITE=3
    3. 无需哈希表查找，直接通过指针访问上下文

Q4: io_uring_cqe_seen()的作用是什么？
A4: 标记CQE已被用户处理，推进CQ的head指针。
    如果不调用，CQ会满，导致无法接收新的完成事件。
    可以使用io_uring_cq_advance()批量标记多个CQE。

Q5: io_uring需要什么内核版本？
A5: Linux 5.1引入io_uring基础功能
    Linux 5.4加入固定文件/缓冲区注册
    Linux 5.6加入更多网络操作支持
    Linux 5.10+推荐，功能较完善
    Linux 5.19+支持multishot_accept
    建议使用5.10或更新的内核。
```

---

### Day 3-4：liburing安装与基础API（10小时）

#### 学习目标

- 完成liburing的编译安装
- 掌握io_uring初始化和销毁API
- 掌握SQE获取和提交API
- 掌握CQE等待和处理API

#### liburing安装

```bash
# ═══════════════════════════════════════════════════════════
# liburing安装指南
# ═══════════════════════════════════════════════════════════

# 方法1：从包管理器安装（Ubuntu/Debian）
sudo apt update
sudo apt install liburing-dev

# 方法2：从包管理器安装（Fedora/RHEL）
sudo dnf install liburing-devel

# 方法3：从源码编译（推荐，获取最新版本）
git clone https://github.com/axboe/liburing.git
cd liburing
./configure --prefix=/usr/local
make -j$(nproc)
sudo make install

# 验证安装
ls /usr/local/include/liburing.h
ls /usr/local/lib/liburing.so

# 编译时链接
g++ -o myapp myapp.cpp -luring

# 如果使用非标准路径
g++ -o myapp myapp.cpp -I/usr/local/include -L/usr/local/lib -luring
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH


# ═══════════════════════════════════════════════════════════
# 检查内核版本
# ═══════════════════════════════════════════════════════════

uname -r
# 输出示例：5.15.0-generic
# 需要5.1+，推荐5.10+

# 检查io_uring支持
cat /proc/kallsyms | grep io_uring
# 应该能看到很多io_uring相关符号
```

#### io_uring核心API详解

```cpp
// ═══════════════════════════════════════════════════════════
// io_uring核心API参考
// ═══════════════════════════════════════════════════════════

#include <liburing.h>

// ─────────────────────────────────────────────────────────
// 1. 初始化与销毁
// ─────────────────────────────────────────────────────────

// 基本初始化
int io_uring_queue_init(unsigned entries, struct io_uring *ring,
                        unsigned flags);
// entries: 队列大小（会向上取2的幂）
// ring: io_uring实例指针
// flags: 配置标志
//   0: 默认配置
//   IORING_SETUP_IOPOLL: 忙等待完成（适用于NVMe）
//   IORING_SETUP_SQPOLL: 内核线程轮询SQ
//   IORING_SETUP_SQ_AFF: SQ线程CPU亲和
// 返回: 0成功，负数错误码

// 带参数初始化（更多控制）
int io_uring_queue_init_params(unsigned entries, struct io_uring *ring,
                               struct io_uring_params *params);

// 销毁
void io_uring_queue_exit(struct io_uring *ring);


// ─────────────────────────────────────────────────────────
// 2. SQE操作
// ─────────────────────────────────────────────────────────

// 获取一个空闲的SQE
struct io_uring_sqe *io_uring_get_sqe(struct io_uring *ring);
// 返回: SQE指针，或NULL（队列满）

// 设置用户数据
void io_uring_sqe_set_data(struct io_uring_sqe *sqe, void *data);
void io_uring_sqe_set_data64(struct io_uring_sqe *sqe, __u64 data);

// 设置SQE标志
void io_uring_sqe_set_flags(struct io_uring_sqe *sqe, unsigned flags);
// flags:
//   IOSQE_FIXED_FILE: 使用注册的文件描述符
//   IOSQE_IO_DRAIN: 等待之前的请求完成
//   IOSQE_IO_LINK: 与下一个SQE链接
//   IOSQE_IO_HARDLINK: 硬链接（即使失败也继续）
//   IOSQE_ASYNC: 强制异步执行
//   IOSQE_BUFFER_SELECT: 使用注册的缓冲区组


// ─────────────────────────────────────────────────────────
// 3. 准备I/O操作（io_uring_prep_*系列）
// ─────────────────────────────────────────────────────────

// 文件读写
void io_uring_prep_read(struct io_uring_sqe *sqe,
                        int fd, void *buf, unsigned nbytes, __u64 offset);
void io_uring_prep_write(struct io_uring_sqe *sqe,
                         int fd, const void *buf, unsigned nbytes, __u64 offset);

// 向量读写
void io_uring_prep_readv(struct io_uring_sqe *sqe,
                         int fd, const struct iovec *iovecs,
                         unsigned nr_vecs, __u64 offset);
void io_uring_prep_writev(struct io_uring_sqe *sqe,
                          int fd, const struct iovec *iovecs,
                          unsigned nr_vecs, __u64 offset);

// 网络操作
void io_uring_prep_accept(struct io_uring_sqe *sqe,
                          int fd, struct sockaddr *addr,
                          socklen_t *addrlen, int flags);
void io_uring_prep_connect(struct io_uring_sqe *sqe,
                           int fd, const struct sockaddr *addr,
                           socklen_t addrlen);
void io_uring_prep_recv(struct io_uring_sqe *sqe,
                        int sockfd, void *buf, size_t len, int flags);
void io_uring_prep_send(struct io_uring_sqe *sqe,
                        int sockfd, const void *buf, size_t len, int flags);

// 其他操作
void io_uring_prep_close(struct io_uring_sqe *sqe, int fd);
void io_uring_prep_timeout(struct io_uring_sqe *sqe,
                           struct __kernel_timespec *ts,
                           unsigned count, unsigned flags);
void io_uring_prep_cancel(struct io_uring_sqe *sqe,
                          void *user_data, int flags);
void io_uring_prep_nop(struct io_uring_sqe *sqe);  // 空操作，用于测试


// ─────────────────────────────────────────────────────────
// 4. 提交请求
// ─────────────────────────────────────────────────────────

// 提交所有准备好的SQE
int io_uring_submit(struct io_uring *ring);
// 返回: 提交的数量

// 提交并等待至少min_complete个完成
int io_uring_submit_and_wait(struct io_uring *ring, unsigned min_complete);


// ─────────────────────────────────────────────────────────
// 5. 等待和处理完成
// ─────────────────────────────────────────────────────────

// 等待一个CQE
int io_uring_wait_cqe(struct io_uring *ring, struct io_uring_cqe **cqe_ptr);

// 等待，带超时
int io_uring_wait_cqe_timeout(struct io_uring *ring,
                              struct io_uring_cqe **cqe_ptr,
                              struct __kernel_timespec *ts);

// 非阻塞获取CQE
int io_uring_peek_cqe(struct io_uring *ring, struct io_uring_cqe **cqe_ptr);

// 获取用户数据
void *io_uring_cqe_get_data(const struct io_uring_cqe *cqe);
__u64 io_uring_cqe_get_data64(const struct io_uring_cqe *cqe);

// 标记CQE已处理
void io_uring_cqe_seen(struct io_uring *ring, struct io_uring_cqe *cqe);

// 批量遍历和确认CQE
#define io_uring_for_each_cqe(ring, head, cqe) \
    for (head = *(ring)->cq.khead; \
         cqe = (head != io_uring_smp_load_acquire((ring)->cq.ktail) ? \
                &(ring)->cq.cqes[(head) & (ring)->cq.ring_mask] : NULL); \
         head++)

void io_uring_cq_advance(struct io_uring *ring, unsigned nr);
```

#### 代码示例3：liburing安装验证程序

```cpp
// 示例3: liburing_check.cpp
// 验证liburing安装和io_uring功能

#include <liburing.h>
#include <sys/utsname.h>
#include <unistd.h>
#include <cstdio>
#include <cstring>

// 检查io_uring功能支持
void check_io_uring_features() {
    struct io_uring ring;
    struct io_uring_params params;
    memset(&params, 0, sizeof(params));

    // 尝试初始化
    int ret = io_uring_queue_init_params(32, &ring, &params);
    if (ret < 0) {
        fprintf(stderr, "io_uring not supported: %s\n", strerror(-ret));
        return;
    }

    printf("io_uring Features:\n");
    printf("==================\n");

    // 检查特性标志
    printf("SQ entries: %u\n", params.sq_entries);
    printf("CQ entries: %u\n", params.cq_entries);

    if (params.features & IORING_FEAT_SINGLE_MMAP)
        printf("✓ SINGLE_MMAP: SQ和CQ共享mmap\n");
    if (params.features & IORING_FEAT_NODROP)
        printf("✓ NODROP: CQ满时不丢弃事件\n");
    if (params.features & IORING_FEAT_SUBMIT_STABLE)
        printf("✓ SUBMIT_STABLE: 提交后可立即修改SQE\n");
    if (params.features & IORING_FEAT_RW_CUR_POS)
        printf("✓ RW_CUR_POS: 支持offset=-1使用当前文件位置\n");
    if (params.features & IORING_FEAT_CUR_PERSONALITY)
        printf("✓ CUR_PERSONALITY: 支持personality\n");
    if (params.features & IORING_FEAT_FAST_POLL)
        printf("✓ FAST_POLL: 快速poll支持\n");
    if (params.features & IORING_FEAT_POLL_32BITS)
        printf("✓ POLL_32BITS: 32位poll事件\n");
    if (params.features & IORING_FEAT_SQPOLL_NONFIXED)
        printf("✓ SQPOLL_NONFIXED: SQPOLL不需要固定文件\n");
    if (params.features & IORING_FEAT_NATIVE_WORKERS)
        printf("✓ NATIVE_WORKERS: 原生工作线程\n");

    // 测试基本操作
    printf("\n基本操作测试:\n");

    // 获取SQE
    struct io_uring_sqe* sqe = io_uring_get_sqe(&ring);
    if (sqe) {
        printf("✓ io_uring_get_sqe 成功\n");

        // 准备一个NOP操作
        io_uring_prep_nop(sqe);
        io_uring_sqe_set_data(sqe, (void*)0xDEADBEEF);

        // 提交
        ret = io_uring_submit(&ring);
        if (ret > 0) {
            printf("✓ io_uring_submit 成功 (提交%d个)\n", ret);

            // 等待完成
            struct io_uring_cqe* cqe;
            ret = io_uring_wait_cqe(&ring, &cqe);
            if (ret == 0) {
                printf("✓ io_uring_wait_cqe 成功\n");
                printf("  user_data: %p\n", io_uring_cqe_get_data(cqe));
                printf("  res: %d\n", cqe->res);
                io_uring_cqe_seen(&ring, cqe);
            }
        }
    }

    io_uring_queue_exit(&ring);
    printf("\nio_uring功能正常！\n");
}

int main() {
    // 显示内核版本
    struct utsname uts;
    uname(&uts);
    printf("Kernel Version: %s\n", uts.release);
    printf("liburing Version: %d.%d\n",
           IO_URING_VERSION_MAJOR, IO_URING_VERSION_MINOR);
    printf("\n");

    check_io_uring_features();
    return 0;
}

/*
编译运行：
$ g++ -o liburing_check liburing_check.cpp -luring
$ ./liburing_check

预期输出：
Kernel Version: 5.15.0-generic
liburing Version: 2.3

io_uring Features:
==================
SQ entries: 32
CQ entries: 64
✓ SINGLE_MMAP: SQ和CQ共享mmap
✓ NODROP: CQ满时不丢弃事件
✓ SUBMIT_STABLE: 提交后可立即修改SQE
✓ RW_CUR_POS: 支持offset=-1使用当前文件位置
...

基本操作测试:
✓ io_uring_get_sqe 成功
✓ io_uring_submit 成功 (提交1个)
✓ io_uring_wait_cqe 成功
  user_data: 0xdeadbeef
  res: 0

io_uring功能正常！
*/
```

#### 代码示例4：io_uring文件读取示例

```cpp
// 示例4: io_uring_file_read.cpp
// 使用io_uring读取文件
// 展示完整的文件I/O流程

#include <liburing.h>
#include <fcntl.h>
#include <unistd.h>
#include <cstdio>
#include <cstring>
#include <cerrno>

#define QUEUE_DEPTH 4
#define BUFFER_SIZE 4096

int main(int argc, char* argv[]) {
    if (argc < 2) {
        printf("Usage: %s <filename>\n", argv[0]);
        return 1;
    }

    const char* filename = argv[1];

    // 打开文件
    int fd = open(filename, O_RDONLY);
    if (fd < 0) {
        perror("open");
        return 1;
    }

    // 初始化io_uring
    struct io_uring ring;
    int ret = io_uring_queue_init(QUEUE_DEPTH, &ring, 0);
    if (ret < 0) {
        fprintf(stderr, "io_uring_queue_init: %s\n", strerror(-ret));
        close(fd);
        return 1;
    }

    // 准备缓冲区
    char buffer[BUFFER_SIZE];
    __u64 offset = 0;
    size_t total_read = 0;

    printf("Reading file: %s\n\n", filename);

    while (true) {
        // 获取SQE
        struct io_uring_sqe* sqe = io_uring_get_sqe(&ring);
        if (!sqe) {
            fprintf(stderr, "Failed to get SQE\n");
            break;
        }

        // 准备读操作
        io_uring_prep_read(sqe, fd, buffer, sizeof(buffer), offset);
        io_uring_sqe_set_data64(sqe, offset);  // 记录偏移量

        // 提交
        ret = io_uring_submit(&ring);
        if (ret < 0) {
            fprintf(stderr, "io_uring_submit: %s\n", strerror(-ret));
            break;
        }

        // 等待完成
        struct io_uring_cqe* cqe;
        ret = io_uring_wait_cqe(&ring, &cqe);
        if (ret < 0) {
            fprintf(stderr, "io_uring_wait_cqe: %s\n", strerror(-ret));
            break;
        }

        // 检查结果
        if (cqe->res < 0) {
            fprintf(stderr, "Read error: %s\n", strerror(-cqe->res));
            io_uring_cqe_seen(&ring, cqe);
            break;
        }

        if (cqe->res == 0) {
            // EOF
            printf("\n[EOF reached]\n");
            io_uring_cqe_seen(&ring, cqe);
            break;
        }

        // 输出读取的内容
        fwrite(buffer, 1, cqe->res, stdout);
        total_read += cqe->res;
        offset += cqe->res;

        io_uring_cqe_seen(&ring, cqe);

        // 如果读取的字节数少于请求的，可能是EOF
        if (cqe->res < (int)sizeof(buffer)) {
            printf("\n[Short read, likely EOF]\n");
            break;
        }
    }

    printf("\nTotal bytes read: %zu\n", total_read);

    // 清理
    io_uring_queue_exit(&ring);
    close(fd);
    return 0;
}

/*
编译运行：
$ g++ -o io_uring_read io_uring_file_read.cpp -luring
$ echo "Hello, io_uring!" > test.txt
$ ./io_uring_read test.txt

输出：
Reading file: test.txt

Hello, io_uring!
[Short read, likely EOF]

Total bytes read: 17
*/
```

#### Day 3-4 自测题

```
Q1: io_uring_queue_init的entries参数会被如何处理？
A1: entries会被向上取到最近的2的幂。例如：
    entries=100 → 实际分配128
    entries=200 → 实际分配256
    这是因为环形缓冲区使用位掩码计算索引，需要2的幂大小。

Q2: io_uring_get_sqe返回NULL说明什么？
A2: 说明SQ已满，没有空闲的SQE可用。
    解决方法：
    1. 调用io_uring_submit提交已有SQE
    2. 等待一些CQE完成
    3. 或增加队列深度

Q3: io_uring_prep_read的offset参数什么时候用-1？
A3: offset=-1表示使用文件当前位置（类似普通read）。
    这需要内核支持IORING_FEAT_RW_CUR_POS特性（5.6+）。
    对于socket等没有偏移概念的fd，通常传0。

Q4: io_uring_cqe_seen和io_uring_cq_advance的区别？
A4: io_uring_cqe_seen：标记单个CQE已处理
    io_uring_cq_advance：批量标记多个CQE已处理

    使用io_uring_for_each_cqe遍历时，最后用cq_advance批量确认更高效：
    unsigned head;
    io_uring_for_each_cqe(&ring, head, cqe) { ... }
    io_uring_cq_advance(&ring, count);

Q5: 为什么cqe->res是负数表示错误？
A5: cqe->res遵循内核系统调用的约定：
    - 成功：返回非负值（如读取的字节数、新fd等）
    - 失败：返回负的errno值（如-EAGAIN, -EINVAL）
    这与read/write等系统调用设置errno的方式不同，
    io_uring直接在res中返回错误码。
```

---

### Day 5-7：io_uring内核实现原理（15小时）

#### 学习目标

- 理解SQ/CQ环形缓冲区的内存布局
- 理解SQE和CQE的完整结构
- 理解内存屏障在io_uring中的作用
- 理解io_uring的请求处理流程

#### SQ/CQ环形缓冲区内存布局

```
═══════════════════════════════════════════════════════════
io_uring共享内存布局
═══════════════════════════════════════════════════════════

io_uring_setup()后的内存映射：

┌─────────────────────────────────────────────────────────┐
│                  SQ Ring Buffer                         │
├─────────────────────────────────────────────────────────┤
│ head       │ 内核读取位置（内核写，用户读）             │
│ tail       │ 用户写入位置（用户写，内核读）             │
│ ring_mask  │ 掩码（用于计算实际索引）                   │
│ ring_entries │ 队列大小                                 │
│ flags      │ 标志                                       │
│ dropped    │ 丢弃的SQE数量                             │
│ array[]    │ SQE索引数组（指向SQEs中的位置）           │
└─────────────────────────────────────────────────────────┘
                      │
                      │ array[i] = SQE索引
                      ▼
┌─────────────────────────────────────────────────────────┐
│                    SQEs Array                           │
├─────────────────────────────────────────────────────────┤
│ SQE[0] │ SQE[1] │ SQE[2] │ ... │ SQE[n-1]              │
│ 64B    │ 64B    │ 64B    │ ... │ 64B                    │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                  CQ Ring Buffer                         │
├─────────────────────────────────────────────────────────┤
│ head       │ 用户读取位置（用户写，内核读）             │
│ tail       │ 内核写入位置（内核写，用户读）             │
│ ring_mask  │ 掩码                                       │
│ ring_entries │ 队列大小                                 │
│ overflow   │ 溢出计数                                   │
│ cqes[]     │ CQE数组（直接存储CQE）                    │
└─────────────────────────────────────────────────────────┘


索引计算方式：
  实际索引 = (head or tail) & ring_mask

例如：ring_entries=256, ring_mask=255 (0xFF)
  tail=257 → 实际索引=257 & 255 = 1
  这就是"环形"的实现方式


为什么SQ有array间接层而CQ没有？

SQ设计：
┌──────────────────┐     ┌──────────────────┐
│ SQ Ring          │     │ SQEs Array       │
│ array[0]=3  ─────│────>│ SQE[3]           │
│ array[1]=7  ─────│────>│ SQE[7]           │
│ array[2]=1  ─────│────>│ SQE[1]           │
└──────────────────┘     └──────────────────┘

用户可以按任意顺序提交SQE，不需要按索引顺序。
这允许更灵活的SQE复用和提交策略。

CQ设计：
┌──────────────────────────────────────────┐
│ CQ Ring                                  │
│ cqes[head & mask] → 直接存储CQE          │
└──────────────────────────────────────────┘

内核按顺序写入CQE，用户按顺序读取。
不需要间接层。
```

#### 代码示例5：io_uring内核流程伪代码

```cpp
// 示例5: io_uring_kernel_pseudo.cpp
// io_uring内核实现伪代码
// 帮助理解io_uring的工作原理

#include <cstdio>

/*
═══════════════════════════════════════════════════════════
io_uring_setup() 内核实现伪代码
═══════════════════════════════════════════════════════════

long io_uring_setup(u32 entries, struct io_uring_params *params) {
    // 1. 验证参数
    if (entries > IORING_MAX_ENTRIES)
        return -EINVAL;

    // 2. 向上取2的幂
    entries = roundup_pow_of_two(entries);

    // 3. 分配io_uring上下文
    ctx = kzalloc(sizeof(*ctx), GFP_KERNEL);
    ctx->sq_entries = entries;
    ctx->cq_entries = entries * 2;  // CQ默认是SQ的2倍

    // 4. 分配SQ/CQ内存
    ctx->sq_sqes = kvmalloc(entries * sizeof(struct io_uring_sqe));
    ctx->cq_cqes = kvmalloc(ctx->cq_entries * sizeof(struct io_uring_cqe));
    ctx->sq_array = kvmalloc(entries * sizeof(u32));

    // 5. 初始化环形缓冲区
    ctx->sq_ring.head = 0;
    ctx->sq_ring.tail = 0;
    ctx->sq_ring.ring_mask = entries - 1;

    ctx->cq_ring.head = 0;
    ctx->cq_ring.tail = 0;
    ctx->cq_ring.ring_mask = ctx->cq_entries - 1;

    // 6. 创建文件描述符
    file = anon_inode_getfile("io_uring", &io_uring_fops, ctx, O_RDWR);
    fd = get_unused_fd_flags(O_CLOEXEC);
    fd_install(fd, file);

    // 7. 填充params返回给用户
    params->sq_entries = entries;
    params->cq_entries = ctx->cq_entries;
    params->sq_off = ...;  // 各字段在mmap中的偏移
    params->cq_off = ...;

    return fd;
}


═══════════════════════════════════════════════════════════
io_uring_enter() 内核实现伪代码（提交和等待）
═══════════════════════════════════════════════════════════

long io_uring_enter(int fd, u32 to_submit, u32 min_complete,
                    u32 flags, sigset_t *sig) {
    ctx = get_io_uring_ctx(fd);

    // 1. 提交SQE
    if (to_submit > 0) {
        submitted = io_submit_sqes(ctx, to_submit);
    }

    // 2. 等待完成
    if (min_complete > 0 || (flags & IORING_ENTER_GETEVENTS)) {
        ret = io_cqring_wait(ctx, min_complete, sig, ...);
    }

    return submitted;
}


// 提交SQE的具体流程
int io_submit_sqes(ctx, to_submit) {
    submitted = 0;

    for (i = 0; i < to_submit; i++) {
        // 从SQ ring读取SQE索引
        head = READ_ONCE(*ctx->sq_ring.head);
        tail = READ_ONCE(*ctx->sq_ring.tail);

        if (head == tail)
            break;  // SQ为空

        idx = ctx->sq_array[head & ctx->sq_ring.ring_mask];
        sqe = &ctx->sq_sqes[idx];

        // 创建请求
        req = io_alloc_req(ctx);
        req->opcode = sqe->opcode;
        req->fd = sqe->fd;
        req->user_data = sqe->user_data;
        ...

        // 提交到工作队列
        io_queue_sqe(req);

        // 推进head
        WRITE_ONCE(*ctx->sq_ring.head, head + 1);
        submitted++;
    }

    return submitted;
}


// 请求完成时写入CQE
void io_cqring_fill_event(ctx, user_data, res, flags) {
    cq_ring = &ctx->cq_ring;

    // 获取CQ tail位置
    tail = READ_ONCE(*cq_ring.tail);

    // 填充CQE
    cqe = &ctx->cq_cqes[tail & cq_ring.ring_mask];
    cqe->user_data = user_data;
    cqe->res = res;
    cqe->flags = flags;

    // 内存屏障，确保CQE内容对用户可见
    smp_store_release(cq_ring.tail, tail + 1);

    // 唤醒等待的用户线程
    if (waitqueue_active(&ctx->cq_wait))
        wake_up(&ctx->cq_wait);
}


═══════════════════════════════════════════════════════════
SQPOLL模式（内核轮询线程）
═══════════════════════════════════════════════════════════

// SQPOLL内核线程
int io_sq_thread(void *data) {
    ctx = data;

    while (!kthread_should_stop()) {
        // 检查SQ是否有新请求
        if (io_sqring_entries(ctx)) {
            // 有请求，提交它们
            io_submit_sqes(ctx, io_sqring_entries(ctx));
            idle_count = 0;
        } else {
            // 没有请求
            idle_count++;
            if (idle_count > sq_thread_idle) {
                // 空闲太久，进入睡眠
                schedule();
            } else {
                // 忙等待（轮询）
                cpu_relax();
            }
        }
    }
    return 0;
}

SQPOLL的优势：
- 用户写入SQE后不需要调用submit系统调用
- 内核线程自动检测SQ tail变化
- 极低延迟，适合对延迟敏感的应用
*/

int main() {
    printf("This file contains pseudocode for io_uring kernel internals.\n");
    printf("\nKey insights:\n");
    printf("1. SQ: user writes SQEs, kernel reads\n");
    printf("2. CQ: kernel writes CQEs, user reads\n");
    printf("3. Memory barriers ensure correct visibility\n");
    printf("4. SQPOLL: kernel thread polls SQ, no submit syscall needed\n");
    return 0;
}
```

#### 代码示例6：io_uring_params配置详解

```cpp
// 示例6: io_uring_params_demo.cpp
// io_uring_params结构体详解
// 展示各种配置选项

#include <liburing.h>
#include <cstdio>
#include <cstring>

void print_features(uint32_t features) {
    printf("Features supported:\n");

    struct {
        uint32_t flag;
        const char* name;
        const char* desc;
    } feature_list[] = {
        {IORING_FEAT_SINGLE_MMAP, "SINGLE_MMAP", "SQ/CQ共享单次mmap"},
        {IORING_FEAT_NODROP, "NODROP", "CQ满时阻塞而非丢弃"},
        {IORING_FEAT_SUBMIT_STABLE, "SUBMIT_STABLE", "提交后SQE内存稳定"},
        {IORING_FEAT_RW_CUR_POS, "RW_CUR_POS", "支持offset=-1"},
        {IORING_FEAT_CUR_PERSONALITY, "CUR_PERSONALITY", "支持personality"},
        {IORING_FEAT_FAST_POLL, "FAST_POLL", "快速poll模式"},
        {IORING_FEAT_POLL_32BITS, "POLL_32BITS", "32位poll事件"},
        {IORING_FEAT_SQPOLL_NONFIXED, "SQPOLL_NONFIXED", "SQPOLL不需固定文件"},
        {IORING_FEAT_EXT_ARG, "EXT_ARG", "扩展参数支持"},
        {IORING_FEAT_NATIVE_WORKERS, "NATIVE_WORKERS", "原生工作线程"},
        {IORING_FEAT_RSRC_TAGS, "RSRC_TAGS", "资源标签支持"},
    };

    for (auto& f : feature_list) {
        printf("  %c %s: %s\n",
               (features & f.flag) ? '+' : '-',
               f.name, f.desc);
    }
}

int main() {
    printf("io_uring_params Configuration Demo\n");
    printf("===================================\n\n");

    // 方式1：默认配置
    {
        struct io_uring ring;
        struct io_uring_params params;
        memset(&params, 0, sizeof(params));

        int ret = io_uring_queue_init_params(64, &ring, &params);
        if (ret < 0) {
            fprintf(stderr, "Init failed: %s\n", strerror(-ret));
            return 1;
        }

        printf("=== Default Configuration ===\n");
        printf("SQ entries: %u\n", params.sq_entries);
        printf("CQ entries: %u\n", params.cq_entries);
        printf("SQ thread CPU: %u\n", params.sq_thread_cpu);
        printf("SQ thread idle: %u ms\n", params.sq_thread_idle);
        print_features(params.features);

        io_uring_queue_exit(&ring);
    }

    printf("\n");

    // 方式2：自定义CQ大小
    {
        struct io_uring ring;
        struct io_uring_params params;
        memset(&params, 0, sizeof(params));

        // 设置CQ大小为SQ的4倍（用于突发请求场景）
        params.flags = IORING_SETUP_CQSIZE;
        params.cq_entries = 256;  // 请求64，CQ设为256

        int ret = io_uring_queue_init_params(64, &ring, &params);
        if (ret < 0) {
            fprintf(stderr, "Init with CQSIZE failed: %s\n", strerror(-ret));
        } else {
            printf("=== Custom CQ Size ===\n");
            printf("SQ entries: %u\n", params.sq_entries);
            printf("CQ entries: %u (requested 256)\n", params.cq_entries);
            io_uring_queue_exit(&ring);
        }
    }

    printf("\n");

    // 方式3：SQPOLL模式（需要CAP_SYS_ADMIN或内核配置允许）
    {
        struct io_uring ring;
        struct io_uring_params params;
        memset(&params, 0, sizeof(params));

        params.flags = IORING_SETUP_SQPOLL;
        params.sq_thread_idle = 2000;  // 2秒空闲后睡眠

        int ret = io_uring_queue_init_params(64, &ring, &params);
        if (ret < 0) {
            printf("=== SQPOLL Mode ===\n");
            printf("SQPOLL not available: %s\n", strerror(-ret));
            printf("(Requires root or CAP_SYS_ADMIN)\n");
        } else {
            printf("=== SQPOLL Mode ===\n");
            printf("SQ entries: %u\n", params.sq_entries);
            printf("SQ thread idle: %u ms\n", params.sq_thread_idle);
            printf("SQPOLL enabled successfully!\n");
            io_uring_queue_exit(&ring);
        }
    }

    printf("\n");

    // params结构体说明
    printf("=== io_uring_params Structure ===\n");
    printf("struct io_uring_params {\n");
    printf("    __u32 sq_entries;      // SQ大小（输出）\n");
    printf("    __u32 cq_entries;      // CQ大小（输入/输出）\n");
    printf("    __u32 flags;           // 配置标志（输入）\n");
    printf("    __u32 sq_thread_cpu;   // SQPOLL CPU亲和（输入）\n");
    printf("    __u32 sq_thread_idle;  // SQPOLL空闲超时ms（输入）\n");
    printf("    __u32 features;        // 内核支持的特性（输出）\n");
    printf("    __u32 wq_fd;           // 共享工作队列的fd\n");
    printf("    __u32 resv[3];\n");
    printf("    struct io_sqring_offsets sq_off;  // SQ内存偏移\n");
    printf("    struct io_cqring_offsets cq_off;  // CQ内存偏移\n");
    printf("};\n");

    return 0;
}

/*
常用flags组合：

1. 默认模式：
   flags = 0

2. 自定义CQ大小：
   flags = IORING_SETUP_CQSIZE

3. SQPOLL模式：
   flags = IORING_SETUP_SQPOLL
   sq_thread_idle = 2000  // 可选

4. SQPOLL + CPU绑定：
   flags = IORING_SETUP_SQPOLL | IORING_SETUP_SQ_AFF
   sq_thread_cpu = 3  // 绑定到CPU 3

5. IO轮询模式（适用于NVMe）：
   flags = IORING_SETUP_IOPOLL

6. 与已有io_uring共享工作线程：
   flags = IORING_SETUP_ATTACH_WQ
   wq_fd = other_ring_fd
*/
```

#### Day 5-7 自测题

```
Q1: 为什么SQ有array间接层而CQ没有？
A1: SQ的array允许用户按任意顺序提交SQE：
    - 用户可以预先填充多个SQE，然后按需要的顺序提交
    - 允许SQE复用（同一个SQE可以多次出现在array中）

    CQ不需要是因为：
    - 内核按完成顺序写入CQE
    - 用户按顺序读取，不需要跳跃访问

Q2: io_uring中的内存屏障有什么作用？
A2: 内存屏障确保多核环境下的正确性：
    - smp_store_release：写入后确保对其他核可见
      用于：更新tail指针前，确保数据已写入
    - smp_load_acquire：读取前确保看到最新数据
      用于：读取head/tail前，确保看到最新值

    liburing封装了这些操作：
    - io_uring_smp_store_release()
    - io_uring_smp_load_acquire()

Q3: SQPOLL模式如何避免用户态系统调用？
A3: SQPOLL启动一个内核线程持续轮询SQ：
    1. 用户写入SQE，更新SQ tail
    2. 内核线程检测到tail变化
    3. 内核线程提交SQE执行I/O
    4. 用户无需调用io_uring_submit()

    代价是内核线程消耗CPU（即使没有请求也在轮询）
    可以设置sq_thread_idle让线程在空闲时睡眠

Q4: CQ溢出时会发生什么？
A4: 取决于内核特性：
    - 无IORING_FEAT_NODROP：CQE可能被丢弃，overflow计数器增加
    - 有IORING_FEAT_NODROP：内核会阻塞，等待用户消费CQE

    最佳实践：
    - 使CQ足够大（默认是SQ的2倍）
    - 及时调用io_uring_cqe_seen()
    - 检查overflow计数

Q5: io_uring_queue_init和io_uring_queue_init_params的区别？
A5: io_uring_queue_init是简化版本，等价于：
    struct io_uring_params params = {0};
    params.flags = flags;
    io_uring_queue_init_params(entries, ring, &params);

    需要自定义CQ大小、SQPOLL配置等时，
    必须使用io_uring_queue_init_params。
```

---

### 第一周检验标准

```
第一周自我检验清单：

理论理解：
☐ 能说出传统I/O和epoll的系统调用开销问题
☐ 能画出io_uring的SQ/CQ环形缓冲区结构
☐ 能解释SQ为什么有array间接层而CQ没有
☐ 能描述SQE和CQE的关键字段
☐ 理解user_data在请求-响应关联中的作用
☐ 理解内存屏障在io_uring中的作用
☐ 能说出SQPOLL模式的工作原理和代价

实践能力：
☐ 能完成liburing的编译安装
☐ 能编写io_uring功能检测程序
☐ 能使用io_uring读取标准输入
☐ 能使用io_uring读取文件
☐ 能正确使用io_uring_params配置选项
☐ 能处理CQE的res返回值（正数/负数）
☐ 能使用io_uring_cqe_seen标记完成
```

---

## 第二周：io_uring核心API详解（Day 8-14）

> **本周目标**：深入掌握io_uring的文件I/O、网络I/O和批量处理API，建立io_uring应用开发能力。

```
第二周知识图谱：

                    ┌─────────────────────────────────────┐
                    │      io_uring核心API体系            │
                    └─────────────────┬───────────────────┘
                                      │
          ┌───────────────────────────┼───────────────────────────┐
          │                           │                           │
          ▼                           ▼                           ▼
   ┌──────────────┐          ┌──────────────┐          ┌──────────────┐
   │   文件I/O    │          │   网络I/O    │          │  批量处理    │
   │   操作       │          │   操作       │          │  与上下文    │
   └──────┬───────┘          └──────┬───────┘          └──────┬───────┘
          │                         │                         │
    ┌─────┴─────┐             ┌─────┴─────┐             ┌─────┴─────┐
    │           │             │           │             │           │
    ▼           ▼             ▼           ▼             ▼           ▼
┌───────┐  ┌───────┐     ┌───────┐  ┌───────┐     ┌───────┐  ┌───────┐
│ read  │  │readv  │     │accept │  │ recv  │     │for_   │  │user_  │
│ write │  │writev │     │connect│  │ send  │     │each_  │  │data   │
│       │  │       │     │       │  │       │     │cqe    │  │关联   │
└───────┘  └───────┘     └───────┘  └───────┘     └───────┘  └───────┘
```

---

### Day 8-9：文件I/O操作（10小时）

#### 学习目标

```
Day 8-9 学习目标：

核心目标：掌握io_uring文件读写API
├── 1. 掌握io_uring_prep_read/write基本用法
├── 2. 理解offset参数的作用和-1的特殊含义
├── 3. 掌握io_uring_prep_readv/writev向量I/O
├── 4. 实现pread/pwrite风格的随机文件访问
└── 5. 能编写完整的io_uring文件操作程序

时间分配：
├── Day 8上午（2.5h）：prep_read/write API详解
├── Day 8下午（2.5h）：文件读取完整示例
├── Day 9上午（2.5h）：prep_readv/writev向量I/O
└── Day 9下午（2.5h）：随机访问与完整示例
```

#### io_uring文件I/O API概览

```cpp
/*
 * io_uring文件I/O相关API一览
 *
 * 基本读写：
 * - io_uring_prep_read(sqe, fd, buf, nbytes, offset)
 * - io_uring_prep_write(sqe, fd, buf, nbytes, offset)
 *
 * 向量I/O（scatter-gather）：
 * - io_uring_prep_readv(sqe, fd, iovecs, nr_vecs, offset)
 * - io_uring_prep_writev(sqe, fd, iovecs, nr_vecs, offset)
 *
 * 固定缓冲区版本（需要先register_buffers）：
 * - io_uring_prep_read_fixed(sqe, fd, buf, nbytes, offset, buf_index)
 * - io_uring_prep_write_fixed(sqe, fd, buf, nbytes, offset, buf_index)
 *
 * offset参数说明：
 * - offset >= 0: 从指定偏移量读写（pread/pwrite语义）
 * - offset == -1: 使用文件当前位置（read/write语义）
 *
 * 返回值（CQE的res字段）：
 * - res > 0: 成功读写的字节数
 * - res == 0: 文件末尾（EOF）
 * - res < 0: 错误码的负值（如-EAGAIN, -EIO）
 */
```

#### API详解：io_uring_prep_read

```cpp
// io_uring_prep_read函数原型
static inline void io_uring_prep_read(
    struct io_uring_sqe *sqe,  // 提交队列条目指针
    int fd,                     // 文件描述符
    void *buf,                  // 读取缓冲区
    unsigned nbytes,            // 要读取的字节数
    __u64 offset                // 文件偏移量
);

/*
 * 内部实现等价于：
 *
 * sqe->opcode = IORING_OP_READ;
 * sqe->fd = fd;
 * sqe->addr = (unsigned long)buf;
 * sqe->len = nbytes;
 * sqe->off = offset;
 *
 * 与pread(2)系统调用类似：
 * ssize_t pread(int fd, void *buf, size_t count, off_t offset);
 *
 * 区别：
 * 1. pread是同步的，io_uring_prep_read是异步的
 * 2. io_uring可以批量提交多个读请求
 * 3. io_uring的offset可以是-1（使用当前文件位置）
 */
```

#### API详解：io_uring_prep_write

```cpp
// io_uring_prep_write函数原型
static inline void io_uring_prep_write(
    struct io_uring_sqe *sqe,  // 提交队列条目指针
    int fd,                     // 文件描述符
    const void *buf,            // 写入缓冲区
    unsigned nbytes,            // 要写入的字节数
    __u64 offset                // 文件偏移量
);

/*
 * 内部实现等价于：
 *
 * sqe->opcode = IORING_OP_WRITE;
 * sqe->fd = fd;
 * sqe->addr = (unsigned long)buf;
 * sqe->len = nbytes;
 * sqe->off = offset;
 *
 * 注意事项：
 * 1. buf必须在CQE返回前保持有效
 * 2. 对于非阻塞fd，可能返回-EAGAIN
 * 3. 写入普通文件通常会成功（除非磁盘满）
 * 4. 写入socket/pipe可能只写入部分数据
 */
```

#### 示例7：io_uring文件读取完整示例

```cpp
// 文件：examples/week2/io_uring_file_read_complete.cpp
// 功能：完整的io_uring文件读取示例
// 编译：g++ -o io_uring_file_read_complete io_uring_file_read_complete.cpp -luring

#include <liburing.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#define BUFFER_SIZE 4096
#define QUEUE_DEPTH 4

/*
 * io_uring文件读取流程图：
 *
 * ┌─────────────┐
 * │  打开文件   │
 * │  open()     │
 * └──────┬──────┘
 *        │
 *        ▼
 * ┌─────────────┐
 * │ 初始化ring  │
 * │queue_init() │
 * └──────┬──────┘
 *        │
 *        ▼
 * ┌─────────────┐     ┌─────────────┐
 * │  获取SQE    │────▶│ 准备读请求  │
 * │  get_sqe()  │     │ prep_read() │
 * └──────┬──────┘     └──────┬──────┘
 *        │                   │
 *        │◀──────────────────┘
 *        ▼
 * ┌─────────────┐
 * │  提交请求   │
 * │  submit()   │
 * └──────┬──────┘
 *        │
 *        ▼
 * ┌─────────────┐
 * │  等待完成   │
 * │ wait_cqe()  │
 * └──────┬──────┘
 *        │
 *        ▼
 * ┌─────────────┐
 * │  处理结果   │
 * │ 检查res字段 │
 * └──────┬──────┘
 *        │
 *        ▼
 * ┌─────────────┐
 * │ 标记已处理  │
 * │ cqe_seen()  │
 * └──────┬──────┘
 *        │
 *        ▼
 * ┌─────────────┐
 * │ 循环/退出   │
 * └─────────────┘
 */

// 错误处理宏
#define CHECK_ERROR(cond, msg) \
    do { \
        if (cond) { \
            perror(msg); \
            exit(EXIT_FAILURE); \
        } \
    } while (0)

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "用法: %s <文件名>\n", argv[0]);
        return 1;
    }

    const char *filename = argv[1];
    struct io_uring ring;
    struct io_uring_sqe *sqe;
    struct io_uring_cqe *cqe;
    char buffer[BUFFER_SIZE];
    int fd;
    int ret;
    off_t offset = 0;
    ssize_t total_read = 0;

    // 1. 打开文件
    fd = open(filename, O_RDONLY);
    CHECK_ERROR(fd < 0, "open failed");
    printf("打开文件: %s (fd=%d)\n", filename, fd);

    // 2. 初始化io_uring
    ret = io_uring_queue_init(QUEUE_DEPTH, &ring, 0);
    CHECK_ERROR(ret < 0, "io_uring_queue_init failed");
    printf("io_uring初始化成功 (队列深度=%d)\n", QUEUE_DEPTH);

    // 3. 读取文件循环
    printf("\n--- 开始读取文件 ---\n");

    while (1) {
        // 3.1 获取SQE
        sqe = io_uring_get_sqe(&ring);
        if (!sqe) {
            fprintf(stderr, "无法获取SQE\n");
            break;
        }

        // 3.2 准备读请求
        // 使用offset指定读取位置（pread语义）
        io_uring_prep_read(sqe, fd, buffer, BUFFER_SIZE, offset);

        // 设置user_data用于标识请求
        sqe->user_data = offset;

        // 3.3 提交请求
        ret = io_uring_submit(&ring);
        if (ret < 0) {
            fprintf(stderr, "io_uring_submit failed: %s\n", strerror(-ret));
            break;
        }

        // 3.4 等待完成
        ret = io_uring_wait_cqe(&ring, &cqe);
        if (ret < 0) {
            fprintf(stderr, "io_uring_wait_cqe failed: %s\n", strerror(-ret));
            break;
        }

        // 3.5 处理结果
        if (cqe->res < 0) {
            // 读取出错
            fprintf(stderr, "读取错误 (offset=%lld): %s\n",
                    (long long)cqe->user_data, strerror(-cqe->res));
            io_uring_cqe_seen(&ring, cqe);
            break;
        } else if (cqe->res == 0) {
            // 文件末尾
            printf("\n到达文件末尾\n");
            io_uring_cqe_seen(&ring, cqe);
            break;
        } else {
            // 成功读取数据
            printf("读取 %d 字节 (offset=%lld)\n",
                   cqe->res, (long long)cqe->user_data);

            // 输出读取的内容（最多显示前100字节）
            int display_len = cqe->res > 100 ? 100 : cqe->res;
            printf("内容预览: %.*s%s\n",
                   display_len, buffer,
                   cqe->res > 100 ? "..." : "");

            total_read += cqe->res;
            offset += cqe->res;
        }

        // 3.6 标记CQE已处理
        io_uring_cqe_seen(&ring, cqe);
    }

    printf("\n--- 读取完成 ---\n");
    printf("总共读取: %zd 字节\n", total_read);

    // 4. 清理资源
    io_uring_queue_exit(&ring);
    close(fd);

    return 0;
}

/*
 * 运行示例：
 *
 * $ echo "Hello, io_uring!" > test.txt
 * $ ./io_uring_file_read_complete test.txt
 * 打开文件: test.txt (fd=3)
 * io_uring初始化成功 (队列深度=4)
 *
 * --- 开始读取文件 ---
 * 读取 17 字节 (offset=0)
 * 内容预览: Hello, io_uring!
 *
 * 到达文件末尾
 *
 * --- 读取完成 ---
 * 总共读取: 17 字节
 */
```

#### 示例8：io_uring文件写入完整示例

```cpp
// 文件：examples/week2/io_uring_file_write_complete.cpp
// 功能：完整的io_uring文件写入示例
// 编译：g++ -o io_uring_file_write_complete io_uring_file_write_complete.cpp -luring

#include <liburing.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#define QUEUE_DEPTH 4

/*
 * 写入模式对比：
 *
 * 1. offset >= 0（pwrite语义）：
 *    - 从指定偏移量开始写入
 *    - 不改变文件位置指针
 *    - 适合随机写入场景
 *
 * 2. offset == -1（write语义）：
 *    - 从当前文件位置写入
 *    - 会更新文件位置指针
 *    - 适合顺序写入场景
 *
 * 3. O_APPEND模式：
 *    - offset被忽略
 *    - 总是追加到文件末尾
 *    - 原子性保证
 */

int main(int argc, char *argv[]) {
    if (argc < 3) {
        fprintf(stderr, "用法: %s <文件名> <写入内容>\n", argv[0]);
        return 1;
    }

    const char *filename = argv[1];
    const char *content = argv[2];
    size_t content_len = strlen(content);

    struct io_uring ring;
    struct io_uring_sqe *sqe;
    struct io_uring_cqe *cqe;
    int fd;
    int ret;

    // 1. 打开文件（创建/截断）
    fd = open(filename, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) {
        perror("open failed");
        return 1;
    }
    printf("打开文件: %s (fd=%d)\n", filename, fd);

    // 2. 初始化io_uring
    ret = io_uring_queue_init(QUEUE_DEPTH, &ring, 0);
    if (ret < 0) {
        fprintf(stderr, "io_uring_queue_init failed: %s\n", strerror(-ret));
        close(fd);
        return 1;
    }
    printf("io_uring初始化成功\n");

    // 3. 准备写请求
    sqe = io_uring_get_sqe(&ring);
    if (!sqe) {
        fprintf(stderr, "无法获取SQE\n");
        io_uring_queue_exit(&ring);
        close(fd);
        return 1;
    }

    // 使用offset=0从文件开头写入
    io_uring_prep_write(sqe, fd, content, content_len, 0);
    sqe->user_data = 1;  // 标识这是写请求

    printf("准备写入: \"%s\" (%zu 字节)\n", content, content_len);

    // 4. 提交请求
    ret = io_uring_submit(&ring);
    if (ret < 0) {
        fprintf(stderr, "io_uring_submit failed: %s\n", strerror(-ret));
        io_uring_queue_exit(&ring);
        close(fd);
        return 1;
    }
    printf("请求已提交\n");

    // 5. 等待完成
    ret = io_uring_wait_cqe(&ring, &cqe);
    if (ret < 0) {
        fprintf(stderr, "io_uring_wait_cqe failed: %s\n", strerror(-ret));
        io_uring_queue_exit(&ring);
        close(fd);
        return 1;
    }

    // 6. 检查结果
    if (cqe->res < 0) {
        fprintf(stderr, "写入失败: %s\n", strerror(-cqe->res));
    } else {
        printf("写入成功: %d 字节\n", cqe->res);

        // 检查是否短写
        if ((size_t)cqe->res < content_len) {
            printf("警告: 短写! 请求 %zu 字节, 实际写入 %d 字节\n",
                   content_len, cqe->res);
        }
    }

    // 7. 标记完成
    io_uring_cqe_seen(&ring, cqe);

    // 8. 追加写入示例
    printf("\n--- 追加写入示例 ---\n");

    const char *append_content = "\nAppended line!";
    size_t append_len = strlen(append_content);

    sqe = io_uring_get_sqe(&ring);
    if (sqe) {
        // 使用offset=-1，将使用当前文件位置
        // 但由于我们使用O_TRUNC打开，需要先lseek或使用具体offset
        // 这里使用content_len作为offset，实现追加
        io_uring_prep_write(sqe, fd, append_content, append_len, content_len);
        sqe->user_data = 2;

        ret = io_uring_submit(&ring);
        if (ret > 0) {
            ret = io_uring_wait_cqe(&ring, &cqe);
            if (ret == 0) {
                if (cqe->res > 0) {
                    printf("追加写入成功: %d 字节\n", cqe->res);
                } else {
                    fprintf(stderr, "追加写入失败: %s\n", strerror(-cqe->res));
                }
                io_uring_cqe_seen(&ring, cqe);
            }
        }
    }

    // 9. 清理
    io_uring_queue_exit(&ring);

    // fsync确保数据落盘
    fsync(fd);
    close(fd);

    printf("\n文件写入完成，可使用 cat %s 查看内容\n", filename);

    return 0;
}

/*
 * 运行示例：
 *
 * $ ./io_uring_file_write_complete output.txt "Hello from io_uring!"
 * 打开文件: output.txt (fd=3)
 * io_uring初始化成功
 * 准备写入: "Hello from io_uring!" (20 字节)
 * 请求已提交
 * 写入成功: 20 字节
 *
 * --- 追加写入示例 ---
 * 追加写入成功: 15 字节
 *
 * 文件写入完成，可使用 cat output.txt 查看内容
 *
 * $ cat output.txt
 * Hello from io_uring!
 * Appended line!
 */
```

#### 向量I/O：readv/writev

```cpp
/*
 * 向量I/O（Scatter-Gather I/O）概念：
 *
 * 传统I/O：
 * ┌────────────────────────────────┐
 * │        连续缓冲区               │
 * │  [data1][data2][data3]         │
 * └────────────────────────────────┘
 *           │
 *           │ 单次read/write
 *           ▼
 *      ┌─────────┐
 *      │  文件   │
 *      └─────────┘
 *
 * 向量I/O：
 * ┌──────┐  ┌──────┐  ┌──────┐
 * │ buf1 │  │ buf2 │  │ buf3 │  (分散的缓冲区)
 * └──┬───┘  └──┬───┘  └──┬───┘
 *    │         │         │
 *    └─────────┼─────────┘
 *              │ 单次readv/writev
 *              ▼
 *         ┌─────────┐
 *         │  文件   │
 *         └─────────┘
 *
 * 优势：
 * 1. 减少系统调用次数
 * 2. 原子性操作（相对于多次read/write）
 * 3. 避免数据拷贝到临时缓冲区
 *
 * 典型应用：
 * - 协议头+数据体分开存储
 * - 日志的时间戳+消息分开
 * - 网络包的header+payload
 */

// iovec结构体
struct iovec {
    void  *iov_base;  // 缓冲区起始地址
    size_t iov_len;   // 缓冲区长度
};

// io_uring_prep_readv函数原型
static inline void io_uring_prep_readv(
    struct io_uring_sqe *sqe,
    int fd,
    const struct iovec *iovecs,  // iovec数组
    unsigned nr_vecs,             // 数组元素个数
    __u64 offset
);

// io_uring_prep_writev函数原型
static inline void io_uring_prep_writev(
    struct io_uring_sqe *sqe,
    int fd,
    const struct iovec *iovecs,
    unsigned nr_vecs,
    __u64 offset
);
```

#### 示例9：io_uring向量I/O示例

```cpp
// 文件：examples/week2/io_uring_vectored_io.cpp
// 功能：io_uring向量I/O（scatter-gather）示例
// 编译：g++ -o io_uring_vectored_io io_uring_vectored_io.cpp -luring

#include <liburing.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <sys/uio.h>

#define QUEUE_DEPTH 4

/*
 * 向量写入场景示例：日志记录
 *
 * 传统方式（3次系统调用或1次拼接）：
 *   sprintf(buf, "[%s] %s: %s\n", timestamp, level, message);
 *   write(fd, buf, len);
 *
 * 向量I/O方式（1次系统调用，无拼接）：
 *   iovec[0] = timestamp
 *   iovec[1] = level
 *   iovec[2] = message
 *   writev(fd, iovec, 3);
 */

void demo_vectored_write(const char *filename) {
    printf("\n=== 向量写入示例 ===\n");

    struct io_uring ring;
    struct io_uring_sqe *sqe;
    struct io_uring_cqe *cqe;
    int ret;

    // 打开文件
    int fd = open(filename, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) {
        perror("open");
        return;
    }

    // 初始化io_uring
    ret = io_uring_queue_init(QUEUE_DEPTH, &ring, 0);
    if (ret < 0) {
        fprintf(stderr, "queue_init failed: %s\n", strerror(-ret));
        close(fd);
        return;
    }

    // 准备多个分散的数据块
    const char *timestamp = "[2024-01-15 10:30:45] ";
    const char *level = "[INFO] ";
    const char *message = "Application started successfully\n";

    struct iovec iovecs[3];
    iovecs[0].iov_base = (void *)timestamp;
    iovecs[0].iov_len = strlen(timestamp);
    iovecs[1].iov_base = (void *)level;
    iovecs[1].iov_len = strlen(level);
    iovecs[2].iov_base = (void *)message;
    iovecs[2].iov_len = strlen(message);

    size_t total_len = iovecs[0].iov_len + iovecs[1].iov_len + iovecs[2].iov_len;
    printf("准备写入 %zu 字节 (分3个iovec)\n", total_len);

    // 获取SQE并准备writev
    sqe = io_uring_get_sqe(&ring);
    io_uring_prep_writev(sqe, fd, iovecs, 3, 0);
    sqe->user_data = 100;

    // 提交并等待
    ret = io_uring_submit(&ring);
    printf("提交请求: %d\n", ret);

    ret = io_uring_wait_cqe(&ring, &cqe);
    if (ret == 0) {
        if (cqe->res > 0) {
            printf("写入成功: %d 字节\n", cqe->res);
        } else {
            fprintf(stderr, "写入失败: %s\n", strerror(-cqe->res));
        }
        io_uring_cqe_seen(&ring, cqe);
    }

    // 再写入一条日志（追加）
    const char *timestamp2 = "[2024-01-15 10:30:46] ";
    const char *level2 = "[DEBUG] ";
    const char *message2 = "Configuration loaded from config.yaml\n";

    iovecs[0].iov_base = (void *)timestamp2;
    iovecs[0].iov_len = strlen(timestamp2);
    iovecs[1].iov_base = (void *)level2;
    iovecs[1].iov_len = strlen(level2);
    iovecs[2].iov_base = (void *)message2;
    iovecs[2].iov_len = strlen(message2);

    sqe = io_uring_get_sqe(&ring);
    // 使用offset=total_len追加
    io_uring_prep_writev(sqe, fd, iovecs, 3, total_len);
    sqe->user_data = 101;

    io_uring_submit(&ring);
    io_uring_wait_cqe(&ring, &cqe);
    if (cqe->res > 0) {
        printf("追加写入成功: %d 字节\n", cqe->res);
    }
    io_uring_cqe_seen(&ring, cqe);

    io_uring_queue_exit(&ring);
    close(fd);

    printf("文件已写入: %s\n", filename);
}

void demo_vectored_read(const char *filename) {
    printf("\n=== 向量读取示例 ===\n");

    struct io_uring ring;
    struct io_uring_sqe *sqe;
    struct io_uring_cqe *cqe;
    int ret;

    // 打开文件
    int fd = open(filename, O_RDONLY);
    if (fd < 0) {
        perror("open");
        return;
    }

    ret = io_uring_queue_init(QUEUE_DEPTH, &ring, 0);
    if (ret < 0) {
        close(fd);
        return;
    }

    // 准备多个接收缓冲区
    char buf1[32], buf2[16], buf3[64];
    memset(buf1, 0, sizeof(buf1));
    memset(buf2, 0, sizeof(buf2));
    memset(buf3, 0, sizeof(buf3));

    struct iovec iovecs[3];
    iovecs[0].iov_base = buf1;
    iovecs[0].iov_len = sizeof(buf1) - 1;  // 留空间给\0
    iovecs[1].iov_base = buf2;
    iovecs[1].iov_len = sizeof(buf2) - 1;
    iovecs[2].iov_base = buf3;
    iovecs[2].iov_len = sizeof(buf3) - 1;

    printf("准备读取到3个缓冲区 (%zu, %zu, %zu 字节)\n",
           iovecs[0].iov_len, iovecs[1].iov_len, iovecs[2].iov_len);

    // 获取SQE并准备readv
    sqe = io_uring_get_sqe(&ring);
    io_uring_prep_readv(sqe, fd, iovecs, 3, 0);
    sqe->user_data = 200;

    // 提交并等待
    io_uring_submit(&ring);
    ret = io_uring_wait_cqe(&ring, &cqe);

    if (ret == 0) {
        if (cqe->res > 0) {
            printf("读取成功: %d 字节\n", cqe->res);
            printf("buf1: \"%s\"\n", buf1);
            printf("buf2: \"%s\"\n", buf2);
            printf("buf3: \"%s\"\n", buf3);
        } else if (cqe->res == 0) {
            printf("文件为空\n");
        } else {
            fprintf(stderr, "读取失败: %s\n", strerror(-cqe->res));
        }
        io_uring_cqe_seen(&ring, cqe);
    }

    io_uring_queue_exit(&ring);
    close(fd);
}

int main(int argc, char *argv[]) {
    const char *filename = argc > 1 ? argv[1] : "/tmp/io_uring_vectored_test.txt";

    printf("io_uring 向量I/O示例\n");
    printf("测试文件: %s\n", filename);

    // 先写入
    demo_vectored_write(filename);

    // 再读取
    demo_vectored_read(filename);

    printf("\n可使用 cat %s 查看文件内容\n", filename);

    return 0;
}

/*
 * 运行示例：
 *
 * $ ./io_uring_vectored_io
 * io_uring 向量I/O示例
 * 测试文件: /tmp/io_uring_vectored_test.txt
 *
 * === 向量写入示例 ===
 * 准备写入 61 字节 (分3个iovec)
 * 提交请求: 1
 * 写入成功: 61 字节
 * 追加写入成功: 67 字节
 * 文件已写入: /tmp/io_uring_vectored_test.txt
 *
 * === 向量读取示例 ===
 * 准备读取到3个缓冲区 (31, 15, 63 字节)
 * 读取成功: 109 字节
 * buf1: "[2024-01-15 10:30:45] [INFO] Ap"
 * buf2: "plication start"
 * buf3: "ed successfully
 * [2024-01-15 10:30:46] [DEBUG] Configuration load"
 *
 * $ cat /tmp/io_uring_vectored_test.txt
 * [2024-01-15 10:30:45] [INFO] Application started successfully
 * [2024-01-15 10:30:46] [DEBUG] Configuration loaded from config.yaml
 */
```

#### Day 8-9 自测问答

```
Day 8-9 自测问答：

Q1: io_uring_prep_read的offset参数设为-1会发生什么？
A1: 使用文件当前位置读取（类似read()而非pread()）。
    每次读取后文件位置会自动前进。
    注意：对于O_APPEND打开的文件，-1是标准做法。

Q2: 向量I/O（readv/writev）相比多次read/write的优势？
A2: 三个主要优势：
    1. 减少系统调用次数（在io_uring中减少提交次数）
    2. 原子性：数据要么全部写入，要么都不写
    3. 避免将分散数据复制到连续缓冲区

Q3: 如何判断io_uring写入是否成功？
A3: 检查CQE的res字段：
    - res > 0：成功写入的字节数
    - res == 0：无数据写入（罕见）
    - res < 0：错误码的负值（如-EIO）
    还要检查是否短写：res < 请求的字节数

Q4: prep_read和prep_read_fixed的区别？
A4: prep_read：使用普通用户空间缓冲区
    prep_read_fixed：使用预注册的固定缓冲区
    固定缓冲区需要先调用io_uring_register_buffers注册，
    可以避免每次操作的内存映射开销。

Q5: 为什么写入后要调用fsync？
A5: io_uring_prep_write只保证数据到达内核缓冲区，
    不保证落盘。需要：
    1. 调用fsync(fd)同步落盘
    2. 或使用io_uring_prep_fsync提交异步fsync
    3. 或打开文件时使用O_SYNC标志
```

---

### Day 10-11：网络I/O操作（10小时）

#### 学习目标

```
Day 10-11 学习目标：

核心目标：掌握io_uring网络操作API
├── 1. 掌握io_uring_prep_accept接受连接
├── 2. 掌握io_uring_prep_connect发起连接
├── 3. 掌握io_uring_prep_recv/send收发数据
├── 4. 理解io_uring网络操作的异步特性
└── 5. 能编写基本的io_uring网络程序

时间分配：
├── Day 10上午（2.5h）：accept/connect API
├── Day 10下午（2.5h）：accept服务器示例
├── Day 11上午（2.5h）：recv/send API
└── Day 11下午（2.5h）：完整Echo示例
```

#### io_uring网络I/O API概览

```cpp
/*
 * io_uring网络I/O API一览：
 *
 * 连接管理：
 * - io_uring_prep_accept(sqe, fd, addr, addrlen, flags)
 * - io_uring_prep_connect(sqe, fd, addr, addrlen)
 * - io_uring_prep_close(sqe, fd)
 * - io_uring_prep_shutdown(sqe, fd, how)
 *
 * 数据收发：
 * - io_uring_prep_recv(sqe, fd, buf, len, flags)
 * - io_uring_prep_send(sqe, fd, buf, len, flags)
 * - io_uring_prep_recvmsg(sqe, fd, msg, flags)
 * - io_uring_prep_sendmsg(sqe, fd, msg, flags)
 *
 * 高级特性（Linux 5.19+）：
 * - io_uring_prep_multishot_accept  (一次提交，多次accept)
 * - io_uring_prep_recv_multishot    (一次提交，多次recv)
 *
 * 与传统API对比：
 * ┌──────────────────┬──────────────────────────────┐
 * │    传统API        │       io_uring API           │
 * ├──────────────────┼──────────────────────────────┤
 * │ accept()         │ io_uring_prep_accept         │
 * │ connect()        │ io_uring_prep_connect        │
 * │ recv()           │ io_uring_prep_recv           │
 * │ send()           │ io_uring_prep_send           │
 * │ recvmsg()        │ io_uring_prep_recvmsg        │
 * │ sendmsg()        │ io_uring_prep_sendmsg        │
 * └──────────────────┴──────────────────────────────┘
 */
```

#### API详解：io_uring_prep_accept

```cpp
// io_uring_prep_accept函数原型
static inline void io_uring_prep_accept(
    struct io_uring_sqe *sqe,
    int fd,                      // 监听socket
    struct sockaddr *addr,       // 客户端地址（可为NULL）
    socklen_t *addrlen,          // 地址长度（可为NULL）
    int flags                    // accept4的flags
);

/*
 * 工作原理：
 *
 *     监听socket (fd)
 *           │
 *           ▼
 *    ┌─────────────┐
 *    │   accept    │  ──▶  阻塞等待连接
 *    │   队列      │       （内核处理）
 *    └─────────────┘
 *           │
 *           ▼ 新连接到来
 *    ┌─────────────┐
 *    │   CQE       │
 *    │  res = 新fd │  ──▶  返回新连接的fd
 *    └─────────────┘
 *
 * flags参数（与accept4相同）：
 * - 0：默认行为
 * - SOCK_NONBLOCK：新socket设为非阻塞
 * - SOCK_CLOEXEC：exec时关闭新socket
 *
 * 返回值（CQE的res）：
 * - res > 0：新连接的文件描述符
 * - res < 0：错误码的负值
 *
 * 常见错误：
 * - -EAGAIN：非阻塞且无连接可接受
 * - -ECONNABORTED：连接被中止
 * - -EMFILE：进程fd数量达到限制
 */

// 使用示例
void prep_accept_example(struct io_uring *ring, int listen_fd) {
    struct io_uring_sqe *sqe = io_uring_get_sqe(ring);

    struct sockaddr_in client_addr;
    socklen_t addr_len = sizeof(client_addr);

    io_uring_prep_accept(sqe, listen_fd,
                         (struct sockaddr *)&client_addr,
                         &addr_len,
                         SOCK_NONBLOCK);

    // user_data用于标识这是accept请求
    sqe->user_data = ACCEPT_REQUEST;
}
```

#### API详解：io_uring_prep_recv/send

```cpp
// io_uring_prep_recv函数原型
static inline void io_uring_prep_recv(
    struct io_uring_sqe *sqe,
    int sockfd,           // socket描述符
    void *buf,            // 接收缓冲区
    size_t len,           // 缓冲区长度
    int flags             // recv的flags
);

// io_uring_prep_send函数原型
static inline void io_uring_prep_send(
    struct io_uring_sqe *sqe,
    int sockfd,           // socket描述符
    const void *buf,      // 发送缓冲区
    size_t len,           // 数据长度
    int flags             // send的flags
);

/*
 * flags参数（与recv/send相同）：
 * - 0：默认行为
 * - MSG_DONTWAIT：非阻塞操作
 * - MSG_NOSIGNAL：不产生SIGPIPE（send）
 * - MSG_PEEK：窥视数据但不移除（recv）
 * - MSG_WAITALL：等待全部数据（recv）
 *
 * recv返回值（CQE的res）：
 * - res > 0：接收到的字节数
 * - res == 0：对端关闭连接
 * - res < 0：错误码的负值
 *
 * send返回值：
 * - res > 0：发送的字节数（可能小于请求）
 * - res < 0：错误码的负值
 *
 * 重要：res > 0 但 < len 表示部分发送/接收
 */
```

#### 示例10：io_uring Accept服务器

```cpp
// 文件：examples/week2/io_uring_accept_server.cpp
// 功能：使用io_uring的accept服务器示例
// 编译：g++ -o io_uring_accept_server io_uring_accept_server.cpp -luring

#include <liburing.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <signal.h>

#define PORT 8080
#define QUEUE_DEPTH 32
#define MAX_CONNECTIONS 1024

/*
 * io_uring Accept服务器架构：
 *
 * ┌─────────────────────────────────────────────────┐
 * │                  主循环                          │
 * │                                                 │
 * │   ┌─────────┐    提交     ┌─────────────────┐  │
 * │   │  SQ     │ ─────────▶  │   内核处理      │  │
 * │   │ accept  │             │  - accept等待   │  │
 * │   │ 请求    │             │  - 新连接通知   │  │
 * │   └─────────┘             └────────┬────────┘  │
 * │                                    │           │
 * │   ┌─────────┐    完成              │           │
 * │   │  CQ     │ ◀────────────────────┘           │
 * │   │ 新连接  │                                   │
 * │   │ fd      │                                   │
 * │   └────┬────┘                                   │
 * │        │                                       │
 * │        ▼ 处理新连接                             │
 * │   ┌─────────────────────────────────────────┐  │
 * │   │ - 打印客户端信息                          │  │
 * │   │ - 发送欢迎消息                            │  │
 * │   │ - 关闭连接 / 进入recv循环                 │  │
 * │   └─────────────────────────────────────────┘  │
 * │        │                                       │
 * │        ▼ 重新提交accept                        │
 * │   继续循环...                                   │
 * └─────────────────────────────────────────────────┘
 */

static volatile bool running = true;

void signal_handler(int sig) {
    (void)sig;
    running = false;
    printf("\n收到退出信号，正在关闭...\n");
}

// 创建监听socket
int create_listen_socket(int port) {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) {
        perror("socket");
        return -1;
    }

    // 设置SO_REUSEADDR
    int opt = 1;
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(port);

    if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        perror("bind");
        close(fd);
        return -1;
    }

    if (listen(fd, SOMAXCONN) < 0) {
        perror("listen");
        close(fd);
        return -1;
    }

    return fd;
}

// 提交accept请求
void submit_accept(struct io_uring *ring, int listen_fd,
                   struct sockaddr_in *client_addr, socklen_t *addr_len) {
    struct io_uring_sqe *sqe = io_uring_get_sqe(ring);
    if (!sqe) {
        fprintf(stderr, "无法获取SQE\n");
        return;
    }

    io_uring_prep_accept(sqe, listen_fd,
                         (struct sockaddr *)client_addr,
                         addr_len,
                         0);  // flags

    // user_data标识请求类型
    sqe->user_data = 0;  // 0表示accept请求
}

int main() {
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);

    printf("=== io_uring Accept服务器 ===\n");

    // 创建监听socket
    int listen_fd = create_listen_socket(PORT);
    if (listen_fd < 0) {
        return 1;
    }
    printf("监听端口: %d (fd=%d)\n", PORT, listen_fd);

    // 初始化io_uring
    struct io_uring ring;
    int ret = io_uring_queue_init(QUEUE_DEPTH, &ring, 0);
    if (ret < 0) {
        fprintf(stderr, "io_uring_queue_init: %s\n", strerror(-ret));
        close(listen_fd);
        return 1;
    }
    printf("io_uring初始化成功\n");

    // 客户端地址存储
    struct sockaddr_in client_addr;
    socklen_t addr_len = sizeof(client_addr);

    // 提交第一个accept请求
    submit_accept(&ring, listen_fd, &client_addr, &addr_len);
    io_uring_submit(&ring);
    printf("等待连接...\n\n");

    int connection_count = 0;

    while (running) {
        struct io_uring_cqe *cqe;

        // 等待完成事件（带超时避免无限阻塞）
        struct __kernel_timespec ts = {.tv_sec = 1, .tv_nsec = 0};
        ret = io_uring_wait_cqe_timeout(&ring, &cqe, &ts);

        if (ret == -ETIME) {
            // 超时，继续等待
            continue;
        }

        if (ret < 0) {
            fprintf(stderr, "io_uring_wait_cqe: %s\n", strerror(-ret));
            break;
        }

        // 处理accept结果
        if (cqe->res < 0) {
            fprintf(stderr, "accept失败: %s\n", strerror(-cqe->res));
        } else {
            int client_fd = cqe->res;
            connection_count++;

            char client_ip[INET_ADDRSTRLEN];
            inet_ntop(AF_INET, &client_addr.sin_addr, client_ip, sizeof(client_ip));
            int client_port = ntohs(client_addr.sin_port);

            printf("[连接 #%d] 新客户端: %s:%d (fd=%d)\n",
                   connection_count, client_ip, client_port, client_fd);

            // 发送欢迎消息
            const char *welcome = "Welcome to io_uring server!\n";
            send(client_fd, welcome, strlen(welcome), 0);

            // 简单处理：立即关闭连接
            // 实际应用中会保存fd并提交recv请求
            close(client_fd);
            printf("[连接 #%d] 已关闭\n\n", connection_count);
        }

        // 标记CQE已处理
        io_uring_cqe_seen(&ring, cqe);

        // 重新提交accept请求
        addr_len = sizeof(client_addr);
        submit_accept(&ring, listen_fd, &client_addr, &addr_len);
        io_uring_submit(&ring);
    }

    printf("\n总连接数: %d\n", connection_count);

    // 清理
    io_uring_queue_exit(&ring);
    close(listen_fd);
    printf("服务器已关闭\n");

    return 0;
}

/*
 * 运行示例：
 *
 * 终端1（服务器）：
 * $ ./io_uring_accept_server
 * === io_uring Accept服务器 ===
 * 监听端口: 8080 (fd=3)
 * io_uring初始化成功
 * 等待连接...
 *
 * [连接 #1] 新客户端: 127.0.0.1:54321 (fd=5)
 * [连接 #1] 已关闭
 *
 * 终端2（客户端）：
 * $ nc localhost 8080
 * Welcome to io_uring server!
 */
```

#### 示例11：io_uring Echo服务器（完整版）

```cpp
// 文件：examples/week2/io_uring_echo_server.cpp
// 功能：完整的io_uring Echo服务器
// 编译：g++ -o io_uring_echo_server io_uring_echo_server.cpp -luring -std=c++17

#include <liburing.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <signal.h>
#include <map>

#define PORT 8080
#define QUEUE_DEPTH 256
#define BUFFER_SIZE 1024

/*
 * io_uring Echo服务器状态机：
 *
 *                    ┌──────────────┐
 *                    │   ACCEPT     │
 *                    │   等待连接    │
 *                    └──────┬───────┘
 *                           │ 新连接
 *                           ▼
 *                    ┌──────────────┐
 *              ┌────▶│    READ      │
 *              │     │  等待数据    │
 *              │     └──────┬───────┘
 *              │            │ 收到数据
 *              │            ▼
 *              │     ┌──────────────┐
 *              │     │    WRITE     │
 *              │     │  发送回显    │
 *              │     └──────┬───────┘
 *              │            │ 发送完成
 *              └────────────┘
 *
 *                    │ 连接关闭/错误
 *                    ▼
 *              ┌──────────────┐
 *              │    CLOSE     │
 *              │   清理资源    │
 *              └──────────────┘
 */

// 请求类型
enum RequestType {
    REQ_ACCEPT = 1,
    REQ_READ   = 2,
    REQ_WRITE  = 3
};

// 连接上下文
struct Connection {
    int fd;
    char buffer[BUFFER_SIZE];
    size_t buffer_len;

    Connection(int fd_) : fd(fd_), buffer_len(0) {
        memset(buffer, 0, sizeof(buffer));
    }
};

// 请求上下文（通过user_data传递）
struct Request {
    RequestType type;
    Connection *conn;

    Request(RequestType t, Connection *c = nullptr)
        : type(t), conn(c) {}
};

static volatile bool running = true;
static std::map<int, Connection*> connections;

void signal_handler(int sig) {
    (void)sig;
    running = false;
}

int create_listen_socket(int port) {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) return -1;

    int opt = 1;
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in addr = {};
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(port);

    if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        close(fd);
        return -1;
    }

    listen(fd, SOMAXCONN);
    return fd;
}

void submit_accept(struct io_uring *ring, int listen_fd) {
    struct io_uring_sqe *sqe = io_uring_get_sqe(ring);
    if (!sqe) return;

    io_uring_prep_accept(sqe, listen_fd, nullptr, nullptr, 0);

    Request *req = new Request(REQ_ACCEPT);
    io_uring_sqe_set_data(sqe, req);
}

void submit_read(struct io_uring *ring, Connection *conn) {
    struct io_uring_sqe *sqe = io_uring_get_sqe(ring);
    if (!sqe) return;

    io_uring_prep_recv(sqe, conn->fd, conn->buffer, BUFFER_SIZE - 1, 0);

    Request *req = new Request(REQ_READ, conn);
    io_uring_sqe_set_data(sqe, req);
}

void submit_write(struct io_uring *ring, Connection *conn) {
    struct io_uring_sqe *sqe = io_uring_get_sqe(ring);
    if (!sqe) return;

    io_uring_prep_send(sqe, conn->fd, conn->buffer, conn->buffer_len, 0);

    Request *req = new Request(REQ_WRITE, conn);
    io_uring_sqe_set_data(sqe, req);
}

void close_connection(Connection *conn) {
    printf("关闭连接: fd=%d\n", conn->fd);
    connections.erase(conn->fd);
    close(conn->fd);
    delete conn;
}

int main() {
    signal(SIGINT, signal_handler);
    signal(SIGPIPE, SIG_IGN);

    printf("=== io_uring Echo服务器 ===\n");

    int listen_fd = create_listen_socket(PORT);
    if (listen_fd < 0) {
        perror("创建监听socket失败");
        return 1;
    }
    printf("监听端口: %d\n", PORT);

    struct io_uring ring;
    if (io_uring_queue_init(QUEUE_DEPTH, &ring, 0) < 0) {
        perror("io_uring初始化失败");
        close(listen_fd);
        return 1;
    }

    // 提交初始accept请求
    submit_accept(&ring, listen_fd);
    io_uring_submit(&ring);
    printf("等待连接...\n\n");

    while (running) {
        struct io_uring_cqe *cqe;
        int ret = io_uring_wait_cqe(&ring, &cqe);
        if (ret < 0) {
            if (ret == -EINTR) continue;
            break;
        }

        Request *req = (Request *)io_uring_cqe_get_data(cqe);
        int res = cqe->res;

        switch (req->type) {
        case REQ_ACCEPT:
            if (res >= 0) {
                int client_fd = res;
                printf("新连接: fd=%d\n", client_fd);

                Connection *conn = new Connection(client_fd);
                connections[client_fd] = conn;

                // 提交read请求
                submit_read(&ring, conn);
            } else {
                fprintf(stderr, "accept错误: %s\n", strerror(-res));
            }

            // 继续accept新连接
            submit_accept(&ring, listen_fd);
            break;

        case REQ_READ:
            if (res > 0) {
                req->conn->buffer[res] = '\0';
                req->conn->buffer_len = res;
                printf("fd=%d 收到: %s", req->conn->fd, req->conn->buffer);

                // 提交write请求（echo回去）
                submit_write(&ring, req->conn);
            } else {
                // res == 0 表示对端关闭，res < 0 表示错误
                if (res == 0) {
                    printf("fd=%d 对端关闭\n", req->conn->fd);
                } else {
                    printf("fd=%d 读取错误: %s\n",
                           req->conn->fd, strerror(-res));
                }
                close_connection(req->conn);
            }
            break;

        case REQ_WRITE:
            if (res > 0) {
                // 发送成功，继续读取
                submit_read(&ring, req->conn);
            } else {
                printf("fd=%d 发送错误: %s\n",
                       req->conn->fd, strerror(-res));
                close_connection(req->conn);
            }
            break;
        }

        delete req;
        io_uring_cqe_seen(&ring, cqe);
        io_uring_submit(&ring);
    }

    // 清理所有连接
    for (auto &kv : connections) {
        close(kv.second->fd);
        delete kv.second;
    }

    io_uring_queue_exit(&ring);
    close(listen_fd);
    printf("\n服务器已关闭\n");

    return 0;
}

/*
 * 运行示例：
 *
 * 终端1（服务器）：
 * $ ./io_uring_echo_server
 * === io_uring Echo服务器 ===
 * 监听端口: 8080
 * 等待连接...
 *
 * 新连接: fd=5
 * fd=5 收到: Hello
 * fd=5 收到: World
 * fd=5 对端关闭
 * 关闭连接: fd=5
 *
 * 终端2（客户端）：
 * $ nc localhost 8080
 * Hello
 * Hello
 * World
 * World
 * ^C
 */
```

#### Day 10-11 自测问答

```
Day 10-11 自测问答：

Q1: io_uring_prep_accept的返回值（CQE的res）是什么？
A1: 成功时返回新连接的文件描述符（正整数），
    失败时返回错误码的负值（如-EAGAIN, -EMFILE）。

Q2: 为什么Echo服务器每次accept后要重新提交accept请求？
A2: io_uring的accept是一次性的，完成后需要重新提交才能
    接受下一个连接。这与epoll不同，epoll监听是持久的。
    （注：Linux 5.19+支持multishot_accept）

Q3: recv返回0意味着什么？与负数返回值有何不同？
A3: recv返回0表示对端正常关闭连接（收到FIN），
    应该关闭socket并清理资源。
    负数返回值表示错误，如-ECONNRESET表示连接被重置。

Q4: 如何在io_uring中处理部分发送（short write）？
A4: 检查CQE的res是否小于请求发送的长度：
    1. 如果 res < len，需要继续发送剩余数据
    2. 更新buffer指针和长度，重新提交send请求
    3. 或使用MSG_WAITALL标志（但可能阻塞较长）

Q5: io_uring_sqe_set_data和直接设置sqe->user_data的区别？
A5: 功能相同，都是设置用户数据。
    io_uring_sqe_set_data是类型安全的辅助函数：
    void io_uring_sqe_set_data(sqe, void *data);
    sqe->user_data = (__u64)data;
    建议使用辅助函数以提高代码可读性。
```

---

### Day 12-14：批量操作与事件处理（15小时）

#### 学习目标

```
Day 12-14 学习目标：

核心目标：掌握io_uring批量处理和上下文关联
├── 1. 掌握io_uring_for_each_cqe批量获取完成事件
├── 2. 掌握io_uring_cq_advance批量确认
├── 3. 理解user_data上下文关联设计模式
├── 4. 掌握io_uring_peek_cqe非阻塞检查
├── 5. 能设计高效的批量处理循环

时间分配：
├── Day 12上午（2.5h）：批量获取API详解
├── Day 12下午（2.5h）：批量处理示例
├── Day 13上午（2.5h）：上下文关联设计
├── Day 13下午（2.5h）：Request结构体模式
├── Day 14上午（2.5h）：非阻塞与超时
└── Day 14下午（2.5h）：综合练习
```

#### 批量处理API概览

```cpp
/*
 * io_uring批量处理API：
 *
 * 1. 批量获取CQE：
 *    io_uring_for_each_cqe(ring, head, cqe) { ... }
 *    - 遍历所有可用的CQE
 *    - head是迭代变量（unsigned类型）
 *    - 不会自动标记CQE为已处理
 *
 * 2. 批量确认CQE：
 *    io_uring_cq_advance(ring, nr)
 *    - 一次性标记nr个CQE为已处理
 *    - 比多次调用cqe_seen更高效
 *
 * 3. 非阻塞检查：
 *    io_uring_peek_cqe(ring, &cqe)
 *    - 检查是否有可用CQE
 *    - 不阻塞，没有CQE时返回-EAGAIN
 *
 * 4. 批量提交与等待：
 *    io_uring_submit_and_wait(ring, wait_nr)
 *    - 提交SQ中的请求并等待至少wait_nr个完成
 *
 * 性能对比：
 * ┌────────────────────┬────────────────────────────┐
 * │      方式           │         特点               │
 * ├────────────────────┼────────────────────────────┤
 * │ 单个处理           │ 简单，但开销大              │
 * │ wait_cqe + cqe_seen│                            │
 * ├────────────────────┼────────────────────────────┤
 * │ 批量处理           │ 高效，减少内存屏障          │
 * │ for_each + advance │ 推荐用于高并发场景          │
 * └────────────────────┴────────────────────────────┘
 */

// 批量处理流程图
/*
 * 单个处理 vs 批量处理：
 *
 * 单个处理（低效）：
 * ┌───────────────────────────────────────────┐
 * │  while (1) {                              │
 * │      wait_cqe(&ring, &cqe);  // 等待1个   │
 * │      process(cqe);           // 处理      │
 * │      cqe_seen(&ring, cqe);   // 确认1个   │
 * │  }                           // 内存屏障×N│
 * └───────────────────────────────────────────┘
 *
 * 批量处理（高效）：
 * ┌───────────────────────────────────────────┐
 * │  while (1) {                              │
 * │      wait_cqe(&ring, &cqe);  // 至少1个   │
 * │      unsigned head;                       │
 * │      unsigned count = 0;                  │
 * │      io_uring_for_each_cqe(&ring, head, cqe) {│
 * │          process(cqe);       // 处理      │
 * │          count++;                         │
 * │      }                                    │
 * │      io_uring_cq_advance(&ring, count);   │
 * │  }                           // 内存屏障×1│
 * └───────────────────────────────────────────┘
 */
```

#### 示例12：批量处理CQE

```cpp
// 文件：examples/week2/io_uring_batch_processing.cpp
// 功能：io_uring批量处理CQE示例
// 编译：g++ -o io_uring_batch_processing io_uring_batch_processing.cpp -luring

#include <liburing.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#define QUEUE_DEPTH 64
#define BATCH_SIZE 16
#define BUFFER_SIZE 4096

/*
 * 批量处理场景：同时读取多个文件
 *
 * 传统方式：逐个读取
 * ┌──────┐ ┌──────┐ ┌──────┐
 * │read 1│→│read 2│→│read 3│→ ... (串行)
 * └──────┘ └──────┘ └──────┘
 *
 * io_uring批量方式：并行提交，批量收割
 * ┌──────┐ ┌──────┐ ┌──────┐
 * │read 1│ │read 2│ │read 3│  (并行提交)
 * └──┬───┘ └──┬───┘ └──┬───┘
 *    │        │        │
 *    └────────┼────────┘
 *             ▼
 *       ┌──────────┐
 *       │ 批量收割 │  (一次获取多个结果)
 *       └──────────┘
 */

// 请求上下文
struct ReadRequest {
    int index;           // 请求索引
    char filename[256];  // 文件名
    char *buffer;        // 读取缓冲区
    size_t size;         // 缓冲区大小
};

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("用法: %s <file1> [file2] [file3] ...\n", argv[0]);
        printf("示例: %s /etc/hostname /etc/hosts /etc/resolv.conf\n", argv[0]);
        return 1;
    }

    int num_files = argc - 1;
    if (num_files > BATCH_SIZE) {
        num_files = BATCH_SIZE;
        printf("限制为最多 %d 个文件\n", BATCH_SIZE);
    }

    printf("=== io_uring 批量读取示例 ===\n");
    printf("文件数量: %d\n\n", num_files);

    struct io_uring ring;
    int ret = io_uring_queue_init(QUEUE_DEPTH, &ring, 0);
    if (ret < 0) {
        fprintf(stderr, "io_uring_queue_init: %s\n", strerror(-ret));
        return 1;
    }

    // 准备请求数组
    ReadRequest *requests = new ReadRequest[num_files];
    int *fds = new int[num_files];

    // 打开所有文件并提交读请求
    printf("--- 提交阶段 ---\n");
    int submitted = 0;

    for (int i = 0; i < num_files; i++) {
        requests[i].index = i;
        strncpy(requests[i].filename, argv[i + 1], sizeof(requests[i].filename) - 1);
        requests[i].buffer = new char[BUFFER_SIZE];
        requests[i].size = BUFFER_SIZE;

        fds[i] = open(requests[i].filename, O_RDONLY);
        if (fds[i] < 0) {
            printf("无法打开文件: %s (%s)\n", requests[i].filename, strerror(errno));
            continue;
        }

        struct io_uring_sqe *sqe = io_uring_get_sqe(&ring);
        if (!sqe) {
            printf("无法获取SQE\n");
            close(fds[i]);
            continue;
        }

        io_uring_prep_read(sqe, fds[i], requests[i].buffer, BUFFER_SIZE - 1, 0);
        io_uring_sqe_set_data(sqe, &requests[i]);

        printf("提交读取: [%d] %s (fd=%d)\n", i, requests[i].filename, fds[i]);
        submitted++;
    }

    // 一次性提交所有请求
    ret = io_uring_submit(&ring);
    printf("\n提交 %d 个请求，返回 %d\n", submitted, ret);

    // 批量获取完成事件
    printf("\n--- 收割阶段 ---\n");

    int completed = 0;
    while (completed < submitted) {
        struct io_uring_cqe *cqe;

        // 等待至少1个完成
        ret = io_uring_wait_cqe(&ring, &cqe);
        if (ret < 0) {
            fprintf(stderr, "wait_cqe: %s\n", strerror(-ret));
            break;
        }

        // 批量处理所有可用的CQE
        unsigned head;
        unsigned batch_count = 0;

        io_uring_for_each_cqe(&ring, head, cqe) {
            ReadRequest *req = (ReadRequest *)io_uring_cqe_get_data(cqe);

            if (cqe->res < 0) {
                printf("[%d] %s: 读取失败 (%s)\n",
                       req->index, req->filename, strerror(-cqe->res));
            } else if (cqe->res == 0) {
                printf("[%d] %s: 文件为空\n", req->index, req->filename);
            } else {
                req->buffer[cqe->res] = '\0';  // 确保字符串终止
                printf("[%d] %s: 读取 %d 字节\n",
                       req->index, req->filename, cqe->res);

                // 显示内容预览（最多50字符）
                int preview_len = cqe->res > 50 ? 50 : cqe->res;
                // 找到第一个换行或结尾
                for (int j = 0; j < preview_len; j++) {
                    if (req->buffer[j] == '\n') {
                        preview_len = j;
                        break;
                    }
                }
                printf("    内容: \"%.*s%s\"\n",
                       preview_len, req->buffer,
                       cqe->res > preview_len ? "..." : "");
            }

            batch_count++;
            completed++;
        }

        // 批量确认处理完成
        io_uring_cq_advance(&ring, batch_count);
        printf("批量确认 %u 个CQE\n\n", batch_count);
    }

    printf("--- 完成 ---\n");
    printf("总共处理: %d 个文件\n", completed);

    // 清理
    for (int i = 0; i < num_files; i++) {
        if (fds[i] >= 0) close(fds[i]);
        delete[] requests[i].buffer;
    }
    delete[] requests;
    delete[] fds;

    io_uring_queue_exit(&ring);

    return 0;
}

/*
 * 运行示例：
 *
 * $ ./io_uring_batch_processing /etc/hostname /etc/hosts /etc/resolv.conf
 * === io_uring 批量读取示例 ===
 * 文件数量: 3
 *
 * --- 提交阶段 ---
 * 提交读取: [0] /etc/hostname (fd=3)
 * 提交读取: [1] /etc/hosts (fd=4)
 * 提交读取: [2] /etc/resolv.conf (fd=5)
 *
 * 提交 3 个请求，返回 3
 *
 * --- 收割阶段 ---
 * [0] /etc/hostname: 读取 12 字节
 *     内容: "my-hostname"
 * [1] /etc/hosts: 读取 221 字节
 *     内容: "127.0.0.1   localhost"...
 * [2] /etc/resolv.conf: 读取 85 字节
 *     内容: "nameserver 8.8.8.8"...
 * 批量确认 3 个CQE
 *
 * --- 完成 ---
 * 总共处理: 3 个文件
 */
```

#### 上下文关联设计模式

```cpp
/*
 * user_data上下文关联设计模式：
 *
 * 问题：io_uring是异步的，当CQE返回时，
 *       我们需要知道这是哪个请求的结果。
 *
 * 解决方案：使用user_data字段关联上下文。
 *
 * 模式1：简单整数标识
 * ┌─────────────────────────────────────────┐
 * │ sqe->user_data = request_id;           │
 * │                                         │
 * │ // CQE返回时                            │
 * │ int id = cqe->user_data;               │
 * │ switch (id) { ... }                    │
 * └─────────────────────────────────────────┘
 *
 * 模式2：指针传递（推荐）
 * ┌─────────────────────────────────────────┐
 * │ struct Request *req = new Request();   │
 * │ io_uring_sqe_set_data(sqe, req);       │
 * │                                         │
 * │ // CQE返回时                            │
 * │ Request *req = io_uring_cqe_get_data(cqe);│
 * │ req->handle_completion(cqe->res);      │
 * │ delete req;                            │
 * └─────────────────────────────────────────┘
 *
 * 模式3：组合标识（类型+索引）
 * ┌─────────────────────────────────────────┐
 * │ // 高32位：类型，低32位：索引           │
 * │ #define MAKE_USER_DATA(type, idx) \    │
 * │     (((uint64_t)(type) << 32) | (idx)) │
 * │                                         │
 * │ #define GET_TYPE(data) ((data) >> 32)  │
 * │ #define GET_INDEX(data) ((data) & 0xFFFFFFFF)│
 * └─────────────────────────────────────────┘
 */

// 示例：Request结构体模式
struct Request {
    enum Type { ACCEPT, READ, WRITE, TIMEOUT };

    Type type;
    int fd;
    void *buffer;
    size_t len;
    size_t offset;

    // 回调函数指针
    void (*on_complete)(Request *req, int result);

    // 用户自定义数据
    void *user_context;
};

/*
 * Request结构体设计原则：
 *
 * 1. 包含请求类型：便于分发处理
 * 2. 包含文件描述符：知道操作哪个资源
 * 3. 包含缓冲区信息：数据读写位置
 * 4. 支持回调：灵活的完成处理
 * 5. 用户上下文：扩展字段
 *
 * 生命周期：
 * ┌─────────┐     ┌─────────┐     ┌─────────┐
 * │  分配   │────▶│  提交   │────▶│  完成   │
 * │ Request │     │ 到SQ    │     │ 从CQ    │
 * └─────────┘     └─────────┘     └────┬────┘
 *                                      │
 *                                      ▼
 *                               ┌─────────┐
 *                               │  释放   │
 *                               │ Request │
 *                               └─────────┘
 *
 * 注意：Request在submit后不能释放，
 *       必须等到CQE返回后才能释放！
 */
```

#### 示例13：完整的上下文关联示例

```cpp
// 文件：examples/week2/io_uring_context_association.cpp
// 功能：io_uring上下文关联设计模式示例
// 编译：g++ -o io_uring_context io_uring_context_association.cpp -luring -std=c++17

#include <liburing.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <functional>
#include <memory>

#define QUEUE_DEPTH 32

/*
 * 高级上下文关联：使用智能指针和回调
 *
 * 设计目标：
 * 1. 类型安全的请求分发
 * 2. 自动内存管理
 * 3. 灵活的完成回调
 */

// 前向声明
struct IoRequest;
using IoRequestPtr = std::shared_ptr<IoRequest>;

// 请求基类
struct IoRequest {
    enum class Type {
        READ,
        WRITE,
        ACCEPT,
        RECV,
        SEND
    };

    Type type;
    int fd;
    std::function<void(IoRequest*, int)> callback;

    IoRequest(Type t, int f) : type(t), fd(f) {}
    virtual ~IoRequest() = default;

    virtual void prepare(struct io_uring_sqe *sqe) = 0;

    static const char* type_name(Type t) {
        switch (t) {
            case Type::READ: return "READ";
            case Type::WRITE: return "WRITE";
            case Type::ACCEPT: return "ACCEPT";
            case Type::RECV: return "RECV";
            case Type::SEND: return "SEND";
        }
        return "UNKNOWN";
    }
};

// 读请求
struct ReadRequest : IoRequest {
    char *buffer;
    size_t size;
    off_t offset;

    ReadRequest(int fd, char *buf, size_t sz, off_t off = 0)
        : IoRequest(Type::READ, fd), buffer(buf), size(sz), offset(off) {}

    void prepare(struct io_uring_sqe *sqe) override {
        io_uring_prep_read(sqe, fd, buffer, size, offset);
    }
};

// 写请求
struct WriteRequest : IoRequest {
    const char *buffer;
    size_t size;
    off_t offset;

    WriteRequest(int fd, const char *buf, size_t sz, off_t off = 0)
        : IoRequest(Type::WRITE, fd), buffer(buf), size(sz), offset(off) {}

    void prepare(struct io_uring_sqe *sqe) override {
        io_uring_prep_write(sqe, fd, buffer, size, offset);
    }
};

// io_uring包装器
class IoUring {
public:
    IoUring(unsigned queue_depth = QUEUE_DEPTH) {
        int ret = io_uring_queue_init(queue_depth, &ring_, 0);
        if (ret < 0) {
            throw std::runtime_error("io_uring_queue_init failed");
        }
    }

    ~IoUring() {
        io_uring_queue_exit(&ring_);
    }

    // 提交请求
    bool submit(IoRequestPtr req) {
        struct io_uring_sqe *sqe = io_uring_get_sqe(&ring_);
        if (!sqe) return false;

        req->prepare(sqe);

        // 存储shared_ptr的原始指针
        // 注意：需要增加引用计数以防止释放
        IoRequest *raw = req.get();
        pending_[raw] = req;  // 保持引用

        io_uring_sqe_set_data(sqe, raw);

        io_uring_submit(&ring_);
        return true;
    }

    // 处理完成事件
    int process_completions(int min_completions = 1) {
        struct io_uring_cqe *cqe;

        int ret = io_uring_wait_cqe(&ring_, &cqe);
        if (ret < 0) return ret;

        int count = 0;
        unsigned head;

        io_uring_for_each_cqe(&ring_, head, cqe) {
            IoRequest *raw = (IoRequest *)io_uring_cqe_get_data(cqe);
            int result = cqe->res;

            // 查找并获取shared_ptr
            auto it = pending_.find(raw);
            if (it != pending_.end()) {
                IoRequestPtr req = it->second;

                printf("[完成] 类型=%s, fd=%d, 结果=%d\n",
                       IoRequest::type_name(req->type),
                       req->fd, result);

                // 调用回调
                if (req->callback) {
                    req->callback(req.get(), result);
                }

                // 从pending中移除
                pending_.erase(it);
            }

            count++;
        }

        io_uring_cq_advance(&ring_, count);
        return count;
    }

private:
    struct io_uring ring_;
    std::unordered_map<IoRequest*, IoRequestPtr> pending_;
};

int main() {
    printf("=== io_uring 上下文关联示例 ===\n\n");

    try {
        IoUring uring;

        // 创建测试文件
        const char *test_file = "/tmp/io_uring_context_test.txt";
        int fd = open(test_file, O_RDWR | O_CREAT | O_TRUNC, 0644);
        if (fd < 0) {
            perror("open");
            return 1;
        }
        printf("打开文件: %s (fd=%d)\n\n", test_file, fd);

        // 1. 提交写请求
        const char *write_data = "Hello from io_uring context demo!\n";
        auto write_req = std::make_shared<WriteRequest>(
            fd, write_data, strlen(write_data), 0
        );
        write_req->callback = [](IoRequest *req, int result) {
            printf("  写入回调: 写入 %d 字节\n", result);
        };

        printf("提交写请求...\n");
        uring.submit(write_req);

        // 等待写完成
        uring.process_completions();

        // 2. 提交读请求
        char read_buffer[128] = {0};
        auto read_req = std::make_shared<ReadRequest>(
            fd, read_buffer, sizeof(read_buffer) - 1, 0
        );
        read_req->callback = [&read_buffer](IoRequest *req, int result) {
            if (result > 0) {
                read_buffer[result] = '\0';
                printf("  读取回调: 读取 %d 字节\n", result);
                printf("  内容: \"%s\"\n", read_buffer);
            }
        };

        printf("\n提交读请求...\n");
        uring.submit(read_req);

        // 等待读完成
        uring.process_completions();

        close(fd);
        printf("\n测试完成\n");

    } catch (const std::exception &e) {
        fprintf(stderr, "错误: %s\n", e.what());
        return 1;
    }

    return 0;
}

/*
 * 运行示例：
 *
 * $ ./io_uring_context
 * === io_uring 上下文关联示例 ===
 *
 * 打开文件: /tmp/io_uring_context_test.txt (fd=3)
 *
 * 提交写请求...
 * [完成] 类型=WRITE, fd=3, 结果=35
 *   写入回调: 写入 35 字节
 *
 * 提交读请求...
 * [完成] 类型=READ, fd=3, 结果=35
 *   读取回调: 读取 35 字节
 *   内容: "Hello from io_uring context demo!
 * "
 *
 * 测试完成
 */
```

#### 非阻塞与超时处理

```cpp
/*
 * io_uring非阻塞与超时API：
 *
 * 1. 非阻塞peek：
 *    int io_uring_peek_cqe(ring, &cqe)
 *    - 检查是否有可用CQE
 *    - 返回0：有CQE可用
 *    - 返回-EAGAIN：无CQE
 *    - 不会阻塞
 *
 * 2. 带超时的wait：
 *    int io_uring_wait_cqe_timeout(ring, &cqe, &ts)
 *    - 等待CQE或超时
 *    - ts是__kernel_timespec结构
 *    - 返回-ETIME：超时
 *
 * 3. 等待多个CQE：
 *    int io_uring_wait_cqe_nr(ring, &cqe, nr)
 *    - 等待至少nr个CQE
 *    - 返回的cqe指向第一个
 *
 * 4. 提交并等待：
 *    int io_uring_submit_and_wait(ring, wait_nr)
 *    - 提交SQ请求
 *    - 等待至少wait_nr个完成
 *    - 高效的组合操作
 */

// 使用示例
void non_blocking_examples(struct io_uring *ring) {
    struct io_uring_cqe *cqe;

    // 1. 非阻塞检查
    int ret = io_uring_peek_cqe(ring, &cqe);
    if (ret == 0) {
        // 有CQE可用
        process_cqe(cqe);
        io_uring_cqe_seen(ring, cqe);
    } else if (ret == -EAGAIN) {
        // 无CQE，做其他事情
        do_other_work();
    }

    // 2. 带超时等待（1秒）
    struct __kernel_timespec ts = {
        .tv_sec = 1,
        .tv_nsec = 0
    };
    ret = io_uring_wait_cqe_timeout(ring, &cqe, &ts);
    if (ret == 0) {
        process_cqe(cqe);
        io_uring_cqe_seen(ring, cqe);
    } else if (ret == -ETIME) {
        printf("超时\n");
    }

    // 3. 提交并等待
    // 先准备若干SQE...
    ret = io_uring_submit_and_wait(ring, 5);  // 等待至少5个完成
    // 然后处理所有可用CQE
}
```

#### Day 12-14 自测问答

```
Day 12-14 自测问答：

Q1: io_uring_for_each_cqe和多次wait_cqe的区别？
A1: for_each_cqe遍历当前所有可用CQE（不阻塞），
    而wait_cqe每次只返回一个CQE（可能阻塞）。
    for_each_cqe配合cq_advance可以减少内存屏障开销。

Q2: 为什么需要io_uring_cq_advance？直接用cqe_seen不行吗？
A2: cqe_seen每次调用都有内存屏障开销。
    批量处理时，使用cq_advance一次性确认多个CQE更高效：
    - cqe_seen：N次内存屏障
    - cq_advance(N)：1次内存屏障

Q3: user_data传递指针时需要注意什么？
A3: 三个关键点：
    1. 指向的内存必须在CQE返回前保持有效
    2. 不能在submit后立即释放
    3. 建议使用智能指针管理生命周期
    4. 注意多线程下的同步问题

Q4: io_uring_peek_cqe返回-EAGAIN意味着什么？
A4: 表示当前没有完成的请求（CQ为空）。
    这是非阻塞操作，程序可以：
    1. 立即返回做其他事情
    2. 稍后再检查
    3. 改用wait_cqe阻塞等待

Q5: submit_and_wait相比分开调用有什么优势？
A5: submit_and_wait是原子操作，减少系统调用：
    - 分开：submit()系统调用 + wait_cqe()系统调用
    - 合并：submit_and_wait()一次系统调用
    特别是SQPOLL模式下，submit_and_wait更高效。
```

---

### 第二周检验标准

```
第二周自我检验清单：

理论理解：
☐ 能说出io_uring_prep_read/write的参数含义
☐ 能解释offset=-1的特殊语义
☐ 理解向量I/O（readv/writev）的优势
☐ 能描述io_uring网络操作的异步流程
☐ 理解accept返回新fd的机制
☐ 能说出recv返回0的含义
☐ 理解for_each_cqe与cq_advance的配合
☐ 能设计user_data上下文关联方案

实践能力：
☐ 能编写io_uring文件读写程序
☐ 能使用readv/writev进行向量I/O
☐ 能实现io_uring accept服务器
☐ 能编写完整的Echo服务器
☐ 能使用批量处理API提高效率
☐ 能正确管理Request生命周期
☐ 能使用peek_cqe进行非阻塞检查
☐ 能使用超时等待避免无限阻塞
```

---

## 第三周：io_uring高级特性（Day 15-21）

> **本周目标**：掌握io_uring的高级特性，包括SQPOLL模式、注册优化和链接操作，提升系统性能。

```
第三周知识图谱：

                    ┌─────────────────────────────────────┐
                    │      io_uring高级特性体系           │
                    └─────────────────┬───────────────────┘
                                      │
          ┌───────────────────────────┼───────────────────────────┐
          │                           │                           │
          ▼                           ▼                           ▼
   ┌──────────────┐          ┌──────────────┐          ┌──────────────┐
   │   SQPOLL     │          │   注册优化   │          │   链接操作   │
   │   内核轮询   │          │              │          │   与控制    │
   └──────┬───────┘          └──────┬───────┘          └──────┬───────┘
          │                         │                         │
    ┌─────┴─────┐             ┌─────┴─────┐             ┌─────┴─────┐
    │           │             │           │             │           │
    ▼           ▼             ▼           ▼             ▼           ▼
┌───────┐  ┌───────┐     ┌───────┐  ┌───────┐     ┌───────┐  ┌───────┐
│设置   │  │CPU    │     │固定fd │  │固定   │     │链式   │  │超时   │
│SQPOLL │  │亲和性 │     │register│  │buffer │     │执行   │  │取消   │
└───────┘  └───────┘     └───────┘  └───────┘     └───────┘  └───────┘
```

---

### Day 15-16：SQPOLL内核轮询模式（10小时）

#### 学习目标

```
Day 15-16 学习目标：

核心目标：掌握SQPOLL内核轮询模式
├── 1. 理解SQPOLL的工作原理和优势
├── 2. 掌握IORING_SETUP_SQPOLL配置
├── 3. 理解sq_thread_idle参数
├── 4. 评估SQPOLL的CPU开销
└── 5. 在适当场景使用SQPOLL

时间分配：
├── Day 15上午（2.5h）：SQPOLL原理与配置
├── Day 15下午（2.5h）：SQPOLL示例实现
├── Day 16上午（2.5h）：性能测试与分析
└── Day 16下午（2.5h）：最佳实践总结
```

#### SQPOLL模式原理

```cpp
/*
 * SQPOLL模式原理：
 *
 * 普通模式（每次都要系统调用）：
 * ┌──────────────────────────────────────────────────┐
 * │ 用户态                                           │
 * │                                                  │
 * │  ┌───────┐   提交   ┌───────┐                   │
 * │  │ 应用  │ ───────▶ │ SQ    │                   │
 * │  └───────┘          └───┬───┘                   │
 * │                         │                        │
 * │═══════════════════════════│════════════════════════│
 * │                         │ io_uring_submit()     │
 * │ 内核态                  │ (系统调用)            │
 * │                         ▼                        │
 * │                    ┌───────┐                    │
 * │                    │ 内核  │                    │
 * │                    │ 处理  │                    │
 * │                    └───────┘                    │
 * └──────────────────────────────────────────────────┘
 *
 * SQPOLL模式（无需系统调用提交）：
 * ┌──────────────────────────────────────────────────┐
 * │ 用户态                                           │
 * │                                                  │
 * │  ┌───────┐   写入   ┌───────┐                   │
 * │  │ 应用  │ ───────▶ │ SQ    │◀─────┐            │
 * │  └───────┘          └───────┘      │            │
 * │                                    │            │
 * │═══════════════════════════════════════│════════════│
 * │                                    │ 轮询       │
 * │ 内核态                             │            │
 * │                              ┌─────┴─────┐      │
 * │                              │ SQ轮询    │      │
 * │                              │ 内核线程  │      │
 * │                              └───────────┘      │
 * └──────────────────────────────────────────────────┘
 *
 * SQPOLL优势：
 * 1. 消除submit()系统调用开销
 * 2. 更低的提交延迟
 * 3. 适合高频提交场景
 *
 * SQPOLL代价：
 * 1. 专用CPU核心（内核线程轮询）
 * 2. 即使空闲也会消耗CPU
 * 3. 需要CAP_SYS_ADMIN或设置正确的权限
 */
```

#### SQPOLL配置详解

```cpp
/*
 * SQPOLL相关配置参数：
 *
 * 1. IORING_SETUP_SQPOLL（必需）
 *    启用SQ轮询模式
 *
 * 2. params.sq_thread_idle（可选）
 *    轮询线程空闲多久后休眠（毫秒）
 *    默认值：1000ms
 *    设为0：永不休眠（最低延迟，最高CPU）
 *
 * 3. params.sq_thread_cpu（可选）
 *    指定轮询线程绑定的CPU核心
 *    需要同时设置IORING_SETUP_SQ_AFF标志
 *
 * 4. IORING_SETUP_SQ_AFF
 *    启用CPU亲和性设置
 *
 * 权限要求：
 * - Linux < 5.11: 需要CAP_SYS_ADMIN
 * - Linux >= 5.11: 普通用户可用（有资源限制）
 * - Linux >= 5.12: IORING_SETUP_SQPOLL_ALLOW_SUBMITTER_NICE
 */

// SQPOLL初始化示例
struct io_uring_params params;
memset(&params, 0, sizeof(params));

// 启用SQPOLL
params.flags = IORING_SETUP_SQPOLL;

// 设置空闲超时（500ms）
params.sq_thread_idle = 500;

// 可选：绑定到CPU 0
// params.flags |= IORING_SETUP_SQ_AFF;
// params.sq_thread_cpu = 0;

struct io_uring ring;
int ret = io_uring_queue_init_params(256, &ring, &params);
if (ret < 0) {
    if (ret == -EPERM) {
        fprintf(stderr, "SQPOLL需要CAP_SYS_ADMIN或更高内核版本\n");
    }
}

/*
 * SQPOLL线程状态检测：
 *
 * 当SQ线程因空闲而休眠时，需要唤醒它。
 * 检测方法：
 *
 * if (IO_URING_READ_ONCE(*ring->sq.kflags) & IORING_SQ_NEED_WAKEUP) {
 *     io_uring_enter(ring->ring_fd, 0, 0, IORING_ENTER_SQ_WAKEUP);
 * }
 *
 * liburing已封装为：
 * io_uring_sqring_wait(&ring);
 */
```

#### 示例14：SQPOLL模式配置与测试

```cpp
// 文件：examples/week3/io_uring_sqpoll.cpp
// 功能：SQPOLL模式配置与性能测试
// 编译：g++ -o io_uring_sqpoll io_uring_sqpoll.cpp -luring -lpthread
// 注意：可能需要sudo运行（或Linux 5.11+）

#include <liburing.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <sys/time.h>
#include <time.h>

#define QUEUE_DEPTH 128
#define BUFFER_SIZE 4096
#define NUM_OPERATIONS 100000

/*
 * SQPOLL性能测试设计：
 *
 * 测试内容：
 * 1. 普通模式 vs SQPOLL模式
 * 2. 相同操作数量下的耗时对比
 * 3. 系统调用次数对比（strace）
 *
 * 预期结果：
 * - SQPOLL模式下submit()几乎无开销
 * - 高频操作时SQPOLL明显更快
 * - 但SQPOLL会增加CPU使用率
 */

// 获取当前时间（微秒）
long long get_time_us() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec * 1000000LL + tv.tv_usec;
}

// 测试函数：执行多次空操作（NOP）
void run_nop_test(struct io_uring *ring, int count, const char *mode_name) {
    printf("\n=== %s 模式测试 ===\n", mode_name);
    printf("操作次数: %d\n", count);

    long long start = get_time_us();
    int submitted = 0;
    int completed = 0;

    while (completed < count) {
        // 尽可能多地提交NOP操作
        while (submitted < count) {
            struct io_uring_sqe *sqe = io_uring_get_sqe(ring);
            if (!sqe) break;

            io_uring_prep_nop(sqe);
            sqe->user_data = submitted;
            submitted++;
        }

        // 提交
        int ret = io_uring_submit(ring);
        if (ret < 0) {
            fprintf(stderr, "submit error: %s\n", strerror(-ret));
            break;
        }

        // 收割完成事件
        struct io_uring_cqe *cqe;
        unsigned head;
        unsigned nr = 0;

        io_uring_for_each_cqe(ring, head, cqe) {
            nr++;
            completed++;
        }
        io_uring_cq_advance(ring, nr);
    }

    long long end = get_time_us();
    long long elapsed = end - start;

    printf("完成: %d 操作\n", completed);
    printf("耗时: %lld 微秒 (%.3f 秒)\n", elapsed, elapsed / 1000000.0);
    printf("吞吐量: %.0f ops/sec\n", completed * 1000000.0 / elapsed);
    printf("平均延迟: %.3f 微秒/操作\n", (double)elapsed / completed);
}

int test_normal_mode() {
    printf("\n========================================\n");
    printf("       普通模式测试\n");
    printf("========================================\n");

    struct io_uring ring;
    int ret = io_uring_queue_init(QUEUE_DEPTH, &ring, 0);
    if (ret < 0) {
        fprintf(stderr, "普通模式初始化失败: %s\n", strerror(-ret));
        return -1;
    }

    run_nop_test(&ring, NUM_OPERATIONS, "普通");

    io_uring_queue_exit(&ring);
    return 0;
}

int test_sqpoll_mode() {
    printf("\n========================================\n");
    printf("       SQPOLL模式测试\n");
    printf("========================================\n");

    struct io_uring_params params;
    memset(&params, 0, sizeof(params));

    // 启用SQPOLL
    params.flags = IORING_SETUP_SQPOLL;
    params.sq_thread_idle = 1000;  // 1秒空闲后休眠

    struct io_uring ring;
    int ret = io_uring_queue_init_params(QUEUE_DEPTH, &ring, &params);
    if (ret < 0) {
        if (ret == -EPERM) {
            fprintf(stderr, "SQPOLL需要root权限或Linux 5.11+\n");
            fprintf(stderr, "尝试: sudo ./io_uring_sqpoll\n");
        } else {
            fprintf(stderr, "SQPOLL初始化失败: %s\n", strerror(-ret));
        }
        return -1;
    }

    printf("SQPOLL初始化成功\n");
    printf("sq_thread_idle: %u ms\n", params.sq_thread_idle);

    // 检查是否真的启用了SQPOLL
    if (params.features & IORING_FEAT_SQPOLL_NONFIXED) {
        printf("支持: SQPOLL_NONFIXED\n");
    }

    run_nop_test(&ring, NUM_OPERATIONS, "SQPOLL");

    io_uring_queue_exit(&ring);
    return 0;
}

// 文件I/O测试
void test_file_io(bool use_sqpoll) {
    const char *mode = use_sqpoll ? "SQPOLL" : "普通";
    printf("\n========================================\n");
    printf("       %s模式文件I/O测试\n", mode);
    printf("========================================\n");

    struct io_uring ring;
    struct io_uring_params params;
    memset(&params, 0, sizeof(params));

    if (use_sqpoll) {
        params.flags = IORING_SETUP_SQPOLL;
        params.sq_thread_idle = 500;
    }

    int ret = io_uring_queue_init_params(QUEUE_DEPTH, &ring, &params);
    if (ret < 0) {
        fprintf(stderr, "初始化失败: %s\n", strerror(-ret));
        return;
    }

    // 创建测试文件
    const char *test_file = "/tmp/sqpoll_test.dat";
    int fd = open(test_file, O_RDWR | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) {
        perror("open");
        io_uring_queue_exit(&ring);
        return;
    }

    // 预写入数据
    char buffer[BUFFER_SIZE];
    memset(buffer, 'A', BUFFER_SIZE);
    write(fd, buffer, BUFFER_SIZE);
    fsync(fd);

    int num_reads = 10000;
    printf("读取次数: %d\n", num_reads);

    long long start = get_time_us();
    int completed = 0;

    for (int i = 0; i < num_reads; i++) {
        struct io_uring_sqe *sqe = io_uring_get_sqe(&ring);
        if (!sqe) {
            // SQ满，先收割
            struct io_uring_cqe *cqe;
            io_uring_submit(&ring);
            io_uring_wait_cqe(&ring, &cqe);
            completed++;
            io_uring_cqe_seen(&ring, cqe);
            sqe = io_uring_get_sqe(&ring);
        }

        io_uring_prep_read(sqe, fd, buffer, BUFFER_SIZE, 0);
        sqe->user_data = i;
    }

    io_uring_submit(&ring);

    // 收割剩余
    while (completed < num_reads) {
        struct io_uring_cqe *cqe;
        ret = io_uring_wait_cqe(&ring, &cqe);
        if (ret < 0) break;
        completed++;
        io_uring_cqe_seen(&ring, cqe);
    }

    long long end = get_time_us();
    long long elapsed = end - start;

    printf("完成: %d 次读取\n", completed);
    printf("耗时: %.3f 秒\n", elapsed / 1000000.0);
    printf("吞吐量: %.0f reads/sec\n", completed * 1000000.0 / elapsed);

    close(fd);
    unlink(test_file);
    io_uring_queue_exit(&ring);
}

int main() {
    printf("=== io_uring SQPOLL模式测试 ===\n");
    printf("内核要求: Linux 5.1+ (SQPOLL)\n");
    printf("        Linux 5.11+ (无需root)\n\n");

    // 检查内核版本
    struct utsname uts;
    uname(&uts);
    printf("当前内核: %s\n", uts.release);

    // 普通模式测试
    test_normal_mode();

    // SQPOLL模式测试
    if (test_sqpoll_mode() < 0) {
        printf("\n跳过SQPOLL测试\n");
    }

    // 文件I/O对比
    test_file_io(false);  // 普通模式
    test_file_io(true);   // SQPOLL模式（可能失败）

    printf("\n测试完成\n");
    return 0;
}

/*
 * 运行示例（普通用户，Linux < 5.11）：
 *
 * $ ./io_uring_sqpoll
 * === io_uring SQPOLL模式测试 ===
 * 当前内核: 5.4.0-generic
 *
 * ========================================
 *        普通模式测试
 * ========================================
 * === 普通 模式测试 ===
 * 操作次数: 100000
 * 完成: 100000 操作
 * 耗时: 523456 微秒 (0.523 秒)
 * 吞吐量: 191034 ops/sec
 *
 * ========================================
 *        SQPOLL模式测试
 * ========================================
 * SQPOLL需要root权限或Linux 5.11+
 * 尝试: sudo ./io_uring_sqpoll
 *
 * 跳过SQPOLL测试
 *
 * 运行示例（root或Linux 5.11+）：
 *
 * $ sudo ./io_uring_sqpoll
 * ...
 * ========================================
 *        SQPOLL模式测试
 * ========================================
 * SQPOLL初始化成功
 * sq_thread_idle: 1000 ms
 * === SQPOLL 模式测试 ===
 * 操作次数: 100000
 * 完成: 100000 操作
 * 耗时: 312345 微秒 (0.312 秒)
 * 吞吐量: 320197 ops/sec
 *
 * 性能提升约 40-60%
 */
```

#### Day 15-16 自测问答

```
Day 15-16 自测问答：

Q1: SQPOLL模式如何实现"零系统调用提交"？
A1: SQPOLL模式下，内核会创建一个专门的线程不断轮询SQ。
    用户态程序只需将SQE写入SQ（内存操作），
    内核线程会自动发现并处理，无需调用io_uring_enter()。

Q2: sq_thread_idle参数的作用是什么？
A2: 控制SQ轮询线程空闲多久后进入休眠：
    - 设为0：永不休眠，最低延迟但CPU占用高
    - 设为N：空闲N毫秒后休眠，平衡延迟和CPU
    线程休眠后，需要唤醒才能继续工作。

Q3: 如何检测SQ线程是否需要唤醒？
A3: 检查sq.kflags中的IORING_SQ_NEED_WAKEUP标志：
    if (*ring->sq.kflags & IORING_SQ_NEED_WAKEUP) {
        io_uring_enter(fd, 0, 0, IORING_ENTER_SQ_WAKEUP);
    }
    liburing提供了io_uring_sqring_wait()封装。

Q4: SQPOLL模式的适用场景是什么？
A4: 适合高频I/O操作场景：
    - 高性能存储（NVMe SSD）
    - 低延迟网络
    - 每秒数十万次I/O操作
    不适合低频操作（CPU浪费）或资源受限环境。

Q5: 为什么早期SQPOLL需要CAP_SYS_ADMIN？
A5: SQPOLL会创建内核线程占用CPU资源，
    恶意程序可能滥用导致DoS。
    Linux 5.11+放宽了限制，但增加了资源配额控制。
```

---

### Day 17-18：注册优化（10小时）

#### 学习目标

```
Day 17-18 学习目标：

核心目标：掌握io_uring注册优化技术
├── 1. 理解register_files固定文件描述符
├── 2. 掌握IOSQE_FIXED_FILE的使用
├── 3. 理解register_buffers固定缓冲区
├── 4. 掌握prep_read_fixed使用固定缓冲
└── 5. 评估注册优化的性能收益

时间分配：
├── Day 17上午（2.5h）：固定fd原理与API
├── Day 17下午（2.5h）：固定fd示例
├── Day 18上午（2.5h）：固定buffer原理与API
└── Day 18下午（2.5h）：综合优化示例
```

#### 注册优化原理

```cpp
/*
 * 为什么需要注册优化？
 *
 * 每次I/O操作时，内核需要：
 * 1. 通过fd查找file结构体
 * 2. 验证用户缓冲区地址
 * 3. 建立用户空间到内核空间的映射
 *
 * 这些操作在高频场景下开销显著。
 *
 * 普通I/O流程：
 * ┌────────────────────────────────────────────┐
 * │ 每次操作                                   │
 * │                                            │
 * │  fd ──▶ 查找file ──▶ 获取inode ──▶ 操作  │
 * │  buf ──▶ 验证地址 ──▶ 页表查找 ──▶ 映射   │
 * │                                            │
 * │  开销：O(n) * 操作次数                     │
 * └────────────────────────────────────────────┘
 *
 * 注册后的I/O流程：
 * ┌────────────────────────────────────────────┐
 * │ 注册阶段（一次性）                          │
 * │  fd[] ──▶ 预先查找 ──▶ 缓存file指针       │
 * │  buf[] ──▶ 预先验证 ──▶ 锁定页面          │
 * │                                            │
 * │ 操作阶段（每次）                            │
 * │  index ──▶ 直接使用缓存的file             │
 * │  index ──▶ 直接使用锁定的页面              │
 * │                                            │
 * │  开销：O(1) * 操作次数                     │
 * └────────────────────────────────────────────┘
 *
 * 性能提升场景：
 * - 同一个fd的大量操作
 * - 重复使用相同缓冲区
 * - 高频小I/O操作
 */
```

#### 固定文件描述符 API

```cpp
/*
 * 固定文件描述符API：
 *
 * 1. 注册文件描述符数组：
 *    int io_uring_register_files(ring, fds, nr_fds)
 *    - fds: 文件描述符数组
 *    - nr_fds: 数组大小
 *    - 返回0成功，负数失败
 *
 * 2. 更新已注册的fd：
 *    int io_uring_register_files_update(ring, off, fds, nr_fds)
 *    - off: 起始偏移
 *    - 可以将某个槽位设为-1表示空
 *
 * 3. 注销所有fd：
 *    int io_uring_unregister_files(ring)
 *
 * 使用注册的fd：
 *    io_uring_prep_read(sqe, fixed_index, ...);
 *    sqe->flags |= IOSQE_FIXED_FILE;
 *    // 或使用辅助函数：
 *    io_uring_sqe_set_flags(sqe, IOSQE_FIXED_FILE);
 *
 * 注意：
 * - 使用IOSQE_FIXED_FILE时，sqe->fd是注册数组的索引，不是真实fd
 * - 注册后原fd仍然有效，可以close()
 * - 但close()后内核仍持有file引用
 */

// 示例代码
int register_files_example(struct io_uring *ring) {
    int fds[3];

    // 打开三个文件
    fds[0] = open("/tmp/file1.txt", O_RDONLY);
    fds[1] = open("/tmp/file2.txt", O_RDONLY);
    fds[2] = open("/tmp/file3.txt", O_RDONLY);

    // 注册文件描述符
    int ret = io_uring_register_files(ring, fds, 3);
    if (ret < 0) {
        fprintf(stderr, "register_files: %s\n", strerror(-ret));
        return ret;
    }

    // 使用注册的fd进行读取
    struct io_uring_sqe *sqe = io_uring_get_sqe(ring);
    char buffer[4096];

    // 注意：这里fd参数是索引0，不是fds[0]
    io_uring_prep_read(sqe, 0, buffer, sizeof(buffer), 0);
    sqe->flags |= IOSQE_FIXED_FILE;  // 标记使用固定fd

    // 提交...

    // 清理时注销
    io_uring_unregister_files(ring);

    // 关闭原fd
    close(fds[0]);
    close(fds[1]);
    close(fds[2]);

    return 0;
}
```

#### 固定缓冲区 API

```cpp
/*
 * 固定缓冲区API：
 *
 * 1. 注册缓冲区数组：
 *    int io_uring_register_buffers(ring, iovecs, nr_iovecs)
 *    - iovecs: iovec数组，描述缓冲区
 *    - nr_iovecs: 数组大小
 *    - 内核会锁定这些页面
 *
 * 2. 注销缓冲区：
 *    int io_uring_unregister_buffers(ring)
 *
 * 使用固定缓冲区：
 *    io_uring_prep_read_fixed(sqe, fd, buf, len, offset, buf_index)
 *    io_uring_prep_write_fixed(sqe, fd, buf, len, offset, buf_index)
 *    - buf_index: 注册数组中的索引
 *
 * 内存锁定原理：
 * ┌─────────────────────────────────────────────┐
 * │ 注册前                                       │
 * │ ┌──────┐     ┌──────┐                       │
 * │ │用户  │ ──▶ │页表  │ ──▶ 物理页（可能换出）│
 * │ │缓冲区│     │      │                       │
 * │ └──────┘     └──────┘                       │
 * │                                             │
 * │ 注册后                                       │
 * │ ┌──────┐     ┌──────┐                       │
 * │ │用户  │ ──▶ │页表  │ ──▶ 物理页（锁定）   │
 * │ │缓冲区│     │(固定)│     │                 │
 * │ └──────┘     └──────┘     └──内核直接访问   │
 * └─────────────────────────────────────────────┘
 *
 * 注意事项：
 * - 锁定页面会占用物理内存，不能换出
 * - 大量锁定可能导致OOM
 * - 检查/proc/sys/vm/max_locked_memory
 * - 可能需要调整ulimit -l
 */

// 示例代码
int register_buffers_example(struct io_uring *ring) {
    // 分配对齐的缓冲区
    const int NUM_BUFFERS = 4;
    const int BUFFER_SIZE = 4096;

    void *buffers[NUM_BUFFERS];
    struct iovec iovecs[NUM_BUFFERS];

    for (int i = 0; i < NUM_BUFFERS; i++) {
        // 页对齐分配
        posix_memalign(&buffers[i], 4096, BUFFER_SIZE);
        iovecs[i].iov_base = buffers[i];
        iovecs[i].iov_len = BUFFER_SIZE;
    }

    // 注册缓冲区
    int ret = io_uring_register_buffers(ring, iovecs, NUM_BUFFERS);
    if (ret < 0) {
        fprintf(stderr, "register_buffers: %s\n", strerror(-ret));
        return ret;
    }

    // 使用固定缓冲区读取
    int fd = open("/tmp/test.txt", O_RDONLY);
    struct io_uring_sqe *sqe = io_uring_get_sqe(ring);

    // 使用缓冲区索引0
    io_uring_prep_read_fixed(sqe, fd,
                             buffers[0], BUFFER_SIZE,
                             0,    // file offset
                             0);   // buffer index

    // 提交并等待...

    // 清理
    io_uring_unregister_buffers(ring);
    for (int i = 0; i < NUM_BUFFERS; i++) {
        free(buffers[i]);
    }

    return 0;
}
```

#### 示例15：注册优化完整示例

```cpp
// 文件：examples/week3/io_uring_registered.cpp
// 功能：io_uring固定fd和固定buffer综合示例
// 编译：g++ -o io_uring_registered io_uring_registered.cpp -luring

#include <liburing.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <sys/time.h>

#define QUEUE_DEPTH 128
#define BUFFER_SIZE 4096
#define NUM_BUFFERS 8
#define NUM_OPERATIONS 50000

/*
 * 性能对比测试：
 *
 * 1. 普通模式：每次操作都查找fd和验证buffer
 * 2. 固定fd模式：预先注册fd，跳过查找
 * 3. 固定fd+buffer模式：都预先注册，最高性能
 */

long long get_time_us() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec * 1000000LL + tv.tv_usec;
}

// 测试普通模式
void test_normal_mode(int fd, int num_ops) {
    printf("\n--- 普通模式 ---\n");

    struct io_uring ring;
    io_uring_queue_init(QUEUE_DEPTH, &ring, 0);

    char *buffer = (char *)aligned_alloc(4096, BUFFER_SIZE);

    long long start = get_time_us();
    int completed = 0;

    for (int i = 0; i < num_ops; i++) {
        struct io_uring_sqe *sqe = io_uring_get_sqe(&ring);
        if (!sqe) {
            struct io_uring_cqe *cqe;
            io_uring_submit(&ring);
            io_uring_wait_cqe(&ring, &cqe);
            completed++;
            io_uring_cqe_seen(&ring, cqe);
            sqe = io_uring_get_sqe(&ring);
        }
        io_uring_prep_read(sqe, fd, buffer, BUFFER_SIZE, 0);
    }

    io_uring_submit(&ring);
    while (completed < num_ops) {
        struct io_uring_cqe *cqe;
        io_uring_wait_cqe(&ring, &cqe);
        completed++;
        io_uring_cqe_seen(&ring, cqe);
    }

    long long elapsed = get_time_us() - start;
    printf("操作: %d, 耗时: %.3f秒, 吞吐: %.0f ops/s\n",
           num_ops, elapsed / 1e6, num_ops * 1e6 / elapsed);

    free(buffer);
    io_uring_queue_exit(&ring);
}

// 测试固定fd模式
void test_fixed_fd_mode(int fd, int num_ops) {
    printf("\n--- 固定fd模式 ---\n");

    struct io_uring ring;
    io_uring_queue_init(QUEUE_DEPTH, &ring, 0);

    // 注册fd
    int fds[1] = {fd};
    int ret = io_uring_register_files(&ring, fds, 1);
    if (ret < 0) {
        fprintf(stderr, "register_files failed: %s\n", strerror(-ret));
        io_uring_queue_exit(&ring);
        return;
    }
    printf("已注册 1 个文件描述符\n");

    char *buffer = (char *)aligned_alloc(4096, BUFFER_SIZE);

    long long start = get_time_us();
    int completed = 0;

    for (int i = 0; i < num_ops; i++) {
        struct io_uring_sqe *sqe = io_uring_get_sqe(&ring);
        if (!sqe) {
            struct io_uring_cqe *cqe;
            io_uring_submit(&ring);
            io_uring_wait_cqe(&ring, &cqe);
            completed++;
            io_uring_cqe_seen(&ring, cqe);
            sqe = io_uring_get_sqe(&ring);
        }
        // 使用固定fd（索引0）
        io_uring_prep_read(sqe, 0, buffer, BUFFER_SIZE, 0);
        sqe->flags |= IOSQE_FIXED_FILE;
    }

    io_uring_submit(&ring);
    while (completed < num_ops) {
        struct io_uring_cqe *cqe;
        io_uring_wait_cqe(&ring, &cqe);
        completed++;
        io_uring_cqe_seen(&ring, cqe);
    }

    long long elapsed = get_time_us() - start;
    printf("操作: %d, 耗时: %.3f秒, 吞吐: %.0f ops/s\n",
           num_ops, elapsed / 1e6, num_ops * 1e6 / elapsed);

    free(buffer);
    io_uring_unregister_files(&ring);
    io_uring_queue_exit(&ring);
}

// 测试固定fd+buffer模式
void test_fixed_fd_buffer_mode(int fd, int num_ops) {
    printf("\n--- 固定fd+buffer模式 ---\n");

    struct io_uring ring;
    io_uring_queue_init(QUEUE_DEPTH, &ring, 0);

    // 注册fd
    int fds[1] = {fd};
    int ret = io_uring_register_files(&ring, fds, 1);
    if (ret < 0) {
        fprintf(stderr, "register_files failed: %s\n", strerror(-ret));
        io_uring_queue_exit(&ring);
        return;
    }

    // 注册buffer
    char *buffer = (char *)aligned_alloc(4096, BUFFER_SIZE);
    struct iovec iov = {.iov_base = buffer, .iov_len = BUFFER_SIZE};
    ret = io_uring_register_buffers(&ring, &iov, 1);
    if (ret < 0) {
        fprintf(stderr, "register_buffers failed: %s\n", strerror(-ret));
        io_uring_unregister_files(&ring);
        free(buffer);
        io_uring_queue_exit(&ring);
        return;
    }
    printf("已注册 1 个fd和 1 个buffer\n");

    long long start = get_time_us();
    int completed = 0;

    for (int i = 0; i < num_ops; i++) {
        struct io_uring_sqe *sqe = io_uring_get_sqe(&ring);
        if (!sqe) {
            struct io_uring_cqe *cqe;
            io_uring_submit(&ring);
            io_uring_wait_cqe(&ring, &cqe);
            completed++;
            io_uring_cqe_seen(&ring, cqe);
            sqe = io_uring_get_sqe(&ring);
        }
        // 使用固定fd（索引0）和固定buffer（索引0）
        io_uring_prep_read_fixed(sqe, 0, buffer, BUFFER_SIZE, 0, 0);
        sqe->flags |= IOSQE_FIXED_FILE;
    }

    io_uring_submit(&ring);
    while (completed < num_ops) {
        struct io_uring_cqe *cqe;
        io_uring_wait_cqe(&ring, &cqe);
        completed++;
        io_uring_cqe_seen(&ring, cqe);
    }

    long long elapsed = get_time_us() - start;
    printf("操作: %d, 耗时: %.3f秒, 吞吐: %.0f ops/s\n",
           num_ops, elapsed / 1e6, num_ops * 1e6 / elapsed);

    io_uring_unregister_buffers(&ring);
    io_uring_unregister_files(&ring);
    free(buffer);
    io_uring_queue_exit(&ring);
}

int main() {
    printf("=== io_uring 注册优化性能测试 ===\n");
    printf("操作数量: %d\n", NUM_OPERATIONS);

    // 创建测试文件
    const char *test_file = "/tmp/io_uring_reg_test.dat";
    int fd = open(test_file, O_RDWR | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) {
        perror("open");
        return 1;
    }

    // 写入测试数据
    char data[BUFFER_SIZE];
    memset(data, 'X', BUFFER_SIZE);
    write(fd, data, BUFFER_SIZE);
    fsync(fd);

    // 运行三种模式测试
    test_normal_mode(fd, NUM_OPERATIONS);
    test_fixed_fd_mode(fd, NUM_OPERATIONS);
    test_fixed_fd_buffer_mode(fd, NUM_OPERATIONS);

    close(fd);
    unlink(test_file);

    printf("\n测试完成\n");
    return 0;
}

/*
 * 运行示例：
 *
 * $ ./io_uring_registered
 * === io_uring 注册优化性能测试 ===
 * 操作数量: 50000
 *
 * --- 普通模式 ---
 * 操作: 50000, 耗时: 1.234秒, 吞吐: 40518 ops/s
 *
 * --- 固定fd模式 ---
 * 已注册 1 个文件描述符
 * 操作: 50000, 耗时: 1.089秒, 吞吐: 45914 ops/s
 *
 * --- 固定fd+buffer模式 ---
 * 已注册 1 个fd和 1 个buffer
 * 操作: 50000, 耗时: 0.923秒, 吞吐: 54171 ops/s
 *
 * 测试完成
 *
 * 性能提升：
 * - 固定fd：约 10-15%
 * - 固定fd+buffer：约 25-35%
 */
```

#### Day 17-18 自测问答

```
Day 17-18 自测问答：

Q1: register_files的作用是什么？
A1: 预先将文件描述符注册到io_uring内核实例中。
    内核会缓存file结构体指针，后续操作可以直接使用，
    跳过fd查找和验证步骤，减少开销。

Q2: 使用IOSQE_FIXED_FILE时，sqe->fd代表什么？
A2: sqe->fd不再是真实的文件描述符，
    而是register_files时传入数组的索引（0到nr_fds-1）。
    必须同时设置IOSQE_FIXED_FILE标志。

Q3: register_buffers有什么注意事项？
A3: 三个关键注意事项：
    1. 缓冲区会被锁定在物理内存中，不能换出
    2. 检查ulimit -l限制（locked memory）
    3. 缓冲区最好页对齐（4096字节）
    4. 大量锁定可能导致OOM

Q4: prep_read_fixed的buf_index参数是什么？
A4: buf_index是register_buffers时注册的iovec数组的索引。
    例如注册了4个buffer，buf_index可以是0-3。
    buf参数必须在注册的buffer范围内。

Q5: 什么场景下注册优化收益最大？
A5: 收益最大的场景：
    - 同一个fd进行大量操作（如数据库文件）
    - 固定大小的I/O缓冲区池
    - 高频小I/O操作
    不适合的场景：
    - 每个fd只用一次
    - 缓冲区大小变化频繁
```

---

### Day 19-21：链接操作与高级控制（15小时）

#### 学习目标

```
Day 19-21 学习目标：

核心目标：掌握io_uring链接操作和高级控制
├── 1. 理解IOSQE_IO_LINK链式依赖执行
├── 2. 掌握IOSQE_IO_HARDLINK硬链接
├── 3. 使用io_uring_prep_timeout超时控制
├── 4. 使用io_uring_prep_cancel取消操作
├── 5. 了解multishot_accept多次accept
└── 6. 了解IOSQE_BUFFER_SELECT缓冲区选择

时间分配：
├── Day 19上午（2.5h）：链接操作原理
├── Day 19下午（2.5h）：链接操作示例
├── Day 20上午（2.5h）：超时与取消
├── Day 20下午（2.5h）：超时示例
├── Day 21上午（2.5h）：multishot特性
└── Day 21下午（2.5h）：综合练习
```

#### 链接操作原理

```cpp
/*
 * io_uring链接操作（Linked Operations）：
 *
 * 概念：将多个SQE串联成链，按顺序执行。
 *       如果链中某个操作失败，后续操作将被取消。
 *
 * 普通提交（无序执行）：
 * ┌─────┐  ┌─────┐  ┌─────┐
 * │SQE 1│  │SQE 2│  │SQE 3│  提交
 * └──┬──┘  └──┬──┘  └──┬──┘
 *    │        │        │
 *    ▼        ▼        ▼     内核可能任意顺序执行
 * ┌─────┐  ┌─────┐  ┌─────┐
 * │CQE ?│  │CQE ?│  │CQE ?│  完成顺序不确定
 * └─────┘  └─────┘  └─────┘
 *
 * 链接提交（顺序执行）：
 * ┌─────┐ LINK ┌─────┐ LINK ┌─────┐
 * │SQE 1│─────▶│SQE 2│─────▶│SQE 3│  链接
 * └──┬──┘      └──┬──┘      └──┬──┘
 *    │            │            │
 *    ▼            ▼            ▼     严格顺序执行
 * ┌─────┐      ┌─────┐      ┌─────┐
 * │CQE 1│ ──▶  │CQE 2│ ──▶  │CQE 3│  顺序完成
 * └─────┘      └─────┘      └─────┘
 *
 * 链接类型：
 * 1. IOSQE_IO_LINK（软链接）
 *    - 前一个操作失败，后续被取消
 *    - 取消的CQE.res = -ECANCELED
 *
 * 2. IOSQE_IO_HARDLINK（硬链接）
 *    - 前一个操作失败，后续仍然执行
 *    - 用于"尽力执行"场景
 */

// 链接标志
#define IOSQE_IO_LINK      (1U << 2)  // 软链接
#define IOSQE_IO_HARDLINK  (1U << 5)  // 硬链接

// 设置链接的方式
void setup_linked_sqes(struct io_uring *ring) {
    struct io_uring_sqe *sqe1, *sqe2, *sqe3;

    // 操作1：读取
    sqe1 = io_uring_get_sqe(ring);
    io_uring_prep_read(sqe1, fd, buf1, len1, 0);
    sqe1->flags |= IOSQE_IO_LINK;  // 链接到下一个
    sqe1->user_data = 1;

    // 操作2：处理后写入（依赖操作1）
    sqe2 = io_uring_get_sqe(ring);
    io_uring_prep_write(sqe2, fd, buf2, len2, 0);
    sqe2->flags |= IOSQE_IO_LINK;  // 链接到下一个
    sqe2->user_data = 2;

    // 操作3：同步（依赖操作2）
    sqe3 = io_uring_get_sqe(ring);
    io_uring_prep_fsync(sqe3, fd, 0);
    // 最后一个不需要LINK标志
    sqe3->user_data = 3;

    // 一次提交整个链
    io_uring_submit(ring);
}
```

#### 超时控制 API

```cpp
/*
 * io_uring超时控制：
 *
 * 1. 独立超时：
 *    io_uring_prep_timeout(sqe, ts, count, flags)
 *    - ts: 超时时间（__kernel_timespec）
 *    - count: 等待count个CQE后触发（0表示只看时间）
 *    - flags: IORING_TIMEOUT_ABS绝对时间
 *
 * 2. 链接超时：
 *    io_uring_prep_link_timeout(sqe, ts, flags)
 *    - 必须紧跟在被超时保护的SQE后面
 *    - 前一个SQE设置IOSQE_IO_LINK
 *    - 如果超时，前面的操作被取消
 *
 * 3. 取消操作：
 *    io_uring_prep_cancel(sqe, user_data, flags)
 *    - 取消user_data匹配的操作
 *    - 或者使用IORING_ASYNC_CANCEL_FD按fd取消
 *
 * 超时结果：
 * - 正常超时：CQE.res = -ETIME
 * - 被取消：CQE.res = -ECANCELED
 * - 完成数达到：CQE.res = 0
 */

// 超时示例
void timeout_example(struct io_uring *ring) {
    struct io_uring_sqe *sqe;

    // 1. 独立超时：3秒后触发
    struct __kernel_timespec ts = {.tv_sec = 3, .tv_nsec = 0};
    sqe = io_uring_get_sqe(ring);
    io_uring_prep_timeout(sqe, &ts, 0, 0);
    sqe->user_data = 100;  // 标识为超时请求

    // 2. 链接超时：保护读操作
    char buffer[4096];

    // 读操作
    sqe = io_uring_get_sqe(ring);
    io_uring_prep_read(sqe, fd, buffer, sizeof(buffer), 0);
    sqe->flags |= IOSQE_IO_LINK;  // 链接到超时
    sqe->user_data = 1;

    // 超时保护（2秒）
    struct __kernel_timespec timeout = {.tv_sec = 2, .tv_nsec = 0};
    sqe = io_uring_get_sqe(ring);
    io_uring_prep_link_timeout(sqe, &timeout, 0);
    sqe->user_data = 101;  // 标识为超时

    io_uring_submit(ring);

    // 处理结果时检查是否超时
    // if (cqe->res == -ETIME) { ... }
    // if (cqe->res == -ECANCELED) { ... }
}
```

#### 示例16：链接操作示例

```cpp
// 文件：examples/week3/io_uring_linked_ops.cpp
// 功能：io_uring链接操作示例（read→process→write链）
// 编译：g++ -o io_uring_linked_ops io_uring_linked_ops.cpp -luring

#include <liburing.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <ctype.h>

#define QUEUE_DEPTH 16
#define BUFFER_SIZE 256

/*
 * 链接操作场景：文件复制并转换大写
 *
 * 链式流程：
 * ┌────────────┐      ┌────────────┐      ┌────────────┐
 * │  READ      │ ───▶ │  NOP       │ ───▶ │  WRITE     │
 * │ 读取源文件 │ LINK │(用于同步)  │ LINK │ 写入目标   │
 * └────────────┘      └────────────┘      └────────────┘
 *
 * 注意：真实场景中，用户态处理（转大写）需要在
 *       READ的CQE返回后进行，这里简化演示链接机制。
 */

int main(int argc, char *argv[]) {
    const char *src_file = argc > 1 ? argv[1] : "/etc/hostname";
    const char *dst_file = "/tmp/io_uring_linked_output.txt";

    printf("=== io_uring 链接操作示例 ===\n");
    printf("源文件: %s\n", src_file);
    printf("目标文件: %s\n\n", dst_file);

    // 打开文件
    int src_fd = open(src_file, O_RDONLY);
    if (src_fd < 0) {
        perror("打开源文件失败");
        return 1;
    }

    int dst_fd = open(dst_file, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (dst_fd < 0) {
        perror("打开目标文件失败");
        close(src_fd);
        return 1;
    }

    // 初始化io_uring
    struct io_uring ring;
    int ret = io_uring_queue_init(QUEUE_DEPTH, &ring, 0);
    if (ret < 0) {
        fprintf(stderr, "io_uring初始化失败: %s\n", strerror(-ret));
        close(src_fd);
        close(dst_fd);
        return 1;
    }

    char buffer[BUFFER_SIZE];

    // === 方式1：非链接方式（需要等待每个操作完成）===
    printf("--- 方式1：非链接方式 ---\n");

    // 读取
    struct io_uring_sqe *sqe = io_uring_get_sqe(&ring);
    io_uring_prep_read(sqe, src_fd, buffer, BUFFER_SIZE - 1, 0);
    sqe->user_data = 1;
    io_uring_submit(&ring);

    struct io_uring_cqe *cqe;
    io_uring_wait_cqe(&ring, &cqe);
    int bytes_read = cqe->res;
    printf("读取: %d 字节\n", bytes_read);
    io_uring_cqe_seen(&ring, cqe);

    if (bytes_read > 0) {
        buffer[bytes_read] = '\0';
        printf("原始内容: %s", buffer);

        // 转换为大写
        for (int i = 0; i < bytes_read; i++) {
            buffer[i] = toupper(buffer[i]);
        }
        printf("转换后: %s", buffer);

        // 写入
        sqe = io_uring_get_sqe(&ring);
        io_uring_prep_write(sqe, dst_fd, buffer, bytes_read, 0);
        sqe->user_data = 2;
        io_uring_submit(&ring);

        io_uring_wait_cqe(&ring, &cqe);
        printf("写入: %d 字节\n", cqe->res);
        io_uring_cqe_seen(&ring, cqe);
    }

    // === 方式2：链接方式演示 ===
    printf("\n--- 方式2：链接方式（read→write链）---\n");

    // 重置文件位置
    lseek(src_fd, 0, SEEK_SET);
    lseek(dst_fd, 0, SEEK_SET);

    char read_buf[BUFFER_SIZE];
    char write_buf[BUFFER_SIZE] = "LINKED WRITE DATA\n";

    // 创建链：read → write
    // 注意：这只是演示链接机制，实际中write依赖read的数据
    //       需要在CQE返回后处理

    sqe = io_uring_get_sqe(&ring);
    io_uring_prep_read(sqe, src_fd, read_buf, BUFFER_SIZE - 1, 0);
    sqe->flags |= IOSQE_IO_LINK;  // 链接到下一个
    sqe->user_data = 10;

    sqe = io_uring_get_sqe(&ring);
    io_uring_prep_write(sqe, dst_fd, write_buf, strlen(write_buf), 0);
    // 最后一个不需要LINK标志
    sqe->user_data = 11;

    printf("提交链式操作...\n");
    ret = io_uring_submit(&ring);
    printf("提交返回: %d\n", ret);

    // 收集结果
    for (int i = 0; i < 2; i++) {
        io_uring_wait_cqe(&ring, &cqe);
        printf("CQE: user_data=%llu, res=%d\n",
               (unsigned long long)cqe->user_data, cqe->res);
        if (cqe->res < 0) {
            printf("  错误: %s\n", strerror(-cqe->res));
        }
        io_uring_cqe_seen(&ring, cqe);
    }

    // === 方式3：链接失败演示 ===
    printf("\n--- 方式3：链接失败演示 ---\n");

    // 创建一个会失败的链
    sqe = io_uring_get_sqe(&ring);
    // 使用无效fd -1，会导致失败
    io_uring_prep_read(sqe, -1, read_buf, BUFFER_SIZE, 0);
    sqe->flags |= IOSQE_IO_LINK;
    sqe->user_data = 20;

    sqe = io_uring_get_sqe(&ring);
    io_uring_prep_write(sqe, dst_fd, write_buf, strlen(write_buf), 0);
    sqe->user_data = 21;

    printf("提交包含无效fd的链...\n");
    io_uring_submit(&ring);

    for (int i = 0; i < 2; i++) {
        io_uring_wait_cqe(&ring, &cqe);
        printf("CQE: user_data=%llu, res=%d",
               (unsigned long long)cqe->user_data, cqe->res);
        if (cqe->res == -ECANCELED) {
            printf(" (被取消 - 因为前面的操作失败)");
        } else if (cqe->res < 0) {
            printf(" (错误: %s)", strerror(-cqe->res));
        }
        printf("\n");
        io_uring_cqe_seen(&ring, cqe);
    }

    // 清理
    io_uring_queue_exit(&ring);
    close(src_fd);
    close(dst_fd);

    printf("\n查看结果: cat %s\n", dst_file);
    return 0;
}

/*
 * 运行示例：
 *
 * $ ./io_uring_linked_ops
 * === io_uring 链接操作示例 ===
 * 源文件: /etc/hostname
 * 目标文件: /tmp/io_uring_linked_output.txt
 *
 * --- 方式1：非链接方式 ---
 * 读取: 12 字节
 * 原始内容: my-hostname
 * 转换后: MY-HOSTNAME
 * 写入: 12 字节
 *
 * --- 方式2：链接方式（read→write链）---
 * 提交链式操作...
 * 提交返回: 2
 * CQE: user_data=10, res=12
 * CQE: user_data=11, res=18
 *
 * --- 方式3：链接失败演示 ---
 * 提交包含无效fd的链...
 * CQE: user_data=20, res=-9 (错误: Bad file descriptor)
 * CQE: user_data=21, res=-125 (被取消 - 因为前面的操作失败)
 *
 * 查看结果: cat /tmp/io_uring_linked_output.txt
 */
```

#### 示例17：超时与取消操作

```cpp
// 文件：examples/week3/io_uring_timeout_cancel.cpp
// 功能：io_uring超时和取消操作示例
// 编译：g++ -o io_uring_timeout_cancel io_uring_timeout_cancel.cpp -luring

#include <liburing.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <sys/socket.h>
#include <netinet/in.h>

#define QUEUE_DEPTH 16

/*
 * 超时控制场景：
 *
 * 1. 独立超时：等待事件或超时
 *    - 用于定时器功能
 *    - 等待N个CQE或超时
 *
 * 2. 链接超时：保护慢操作
 *    - 如果操作太慢，超时后取消
 *    - 常用于网络I/O
 *
 * 3. 取消操作：主动取消进行中的操作
 *    - 用于清理、关闭等场景
 */

// 演示独立超时
void demo_standalone_timeout(struct io_uring *ring) {
    printf("\n=== 独立超时演示 ===\n");

    struct io_uring_sqe *sqe;
    struct io_uring_cqe *cqe;

    // 设置2秒超时
    struct __kernel_timespec ts = {.tv_sec = 2, .tv_nsec = 0};

    sqe = io_uring_get_sqe(ring);
    io_uring_prep_timeout(sqe, &ts, 0, 0);
    sqe->user_data = 1;

    printf("提交2秒超时...\n");
    io_uring_submit(ring);

    printf("等待超时...\n");
    int ret = io_uring_wait_cqe(ring, &cqe);

    if (ret == 0) {
        if (cqe->res == -ETIME) {
            printf("超时触发！(res=%d, -ETIME)\n", cqe->res);
        } else {
            printf("意外结果: res=%d\n", cqe->res);
        }
        io_uring_cqe_seen(ring, cqe);
    }
}

// 演示链接超时（保护慢操作）
void demo_linked_timeout(struct io_uring *ring) {
    printf("\n=== 链接超时演示 ===\n");

    struct io_uring_sqe *sqe;
    struct io_uring_cqe *cqe;

    // 创建一个不会有数据的socket（模拟慢操作）
    int sock = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK, 0);
    if (sock < 0) {
        perror("socket");
        return;
    }

    char buffer[1024];

    // recv操作（会一直等待）
    sqe = io_uring_get_sqe(ring);
    io_uring_prep_recv(sqe, sock, buffer, sizeof(buffer), 0);
    sqe->flags |= IOSQE_IO_LINK;  // 链接到超时
    sqe->user_data = 10;

    // 1秒超时保护
    struct __kernel_timespec ts = {.tv_sec = 1, .tv_nsec = 0};
    sqe = io_uring_get_sqe(ring);
    io_uring_prep_link_timeout(sqe, &ts, 0);
    sqe->user_data = 11;

    printf("提交recv操作（带1秒超时保护）...\n");
    io_uring_submit(ring);

    // 收集结果
    for (int i = 0; i < 2; i++) {
        io_uring_wait_cqe(ring, &cqe);
        printf("CQE: user_data=%llu, res=%d",
               (unsigned long long)cqe->user_data, cqe->res);

        if (cqe->user_data == 10) {
            if (cqe->res == -ECANCELED) {
                printf(" (recv被超时取消)");
            } else if (cqe->res == -EAGAIN) {
                printf(" (无数据可读)");
            }
        } else if (cqe->user_data == 11) {
            if (cqe->res == -EALREADY) {
                printf(" (超时已触发)");
            } else if (cqe->res == -ECANCELED) {
                printf(" (超时被取消-操作完成)");
            }
        }
        printf("\n");
        io_uring_cqe_seen(ring, cqe);
    }

    close(sock);
}

// 演示取消操作
void demo_cancel_operation(struct io_uring *ring) {
    printf("\n=== 取消操作演示 ===\n");

    struct io_uring_sqe *sqe;
    struct io_uring_cqe *cqe;

    // 创建一个长超时
    struct __kernel_timespec long_ts = {.tv_sec = 60, .tv_nsec = 0};

    sqe = io_uring_get_sqe(ring);
    io_uring_prep_timeout(sqe, &long_ts, 0, 0);
    sqe->user_data = 100;

    printf("提交60秒超时...\n");
    io_uring_submit(ring);

    // 稍等一下
    usleep(100000);  // 100ms

    // 取消那个超时
    printf("取消超时操作...\n");
    sqe = io_uring_get_sqe(ring);
    io_uring_prep_cancel(sqe, (void *)100, 0);
    sqe->user_data = 101;
    io_uring_submit(ring);

    // 收集结果
    for (int i = 0; i < 2; i++) {
        io_uring_wait_cqe(ring, &cqe);
        printf("CQE: user_data=%llu, res=%d",
               (unsigned long long)cqe->user_data, cqe->res);

        if (cqe->user_data == 100) {
            if (cqe->res == -ECANCELED) {
                printf(" (超时被成功取消)");
            }
        } else if (cqe->user_data == 101) {
            if (cqe->res == 0) {
                printf(" (取消请求成功)");
            } else if (cqe->res == -ENOENT) {
                printf(" (未找到要取消的操作)");
            }
        }
        printf("\n");
        io_uring_cqe_seen(ring, cqe);
    }
}

// 演示等待N个完成后超时
void demo_timeout_with_count(struct io_uring *ring) {
    printf("\n=== 等待N个完成后超时 ===\n");

    struct io_uring_sqe *sqe;
    struct io_uring_cqe *cqe;

    // 提交3个NOP操作
    for (int i = 0; i < 3; i++) {
        sqe = io_uring_get_sqe(ring);
        io_uring_prep_nop(sqe);
        sqe->user_data = i + 1;
    }

    // 超时：等待2个完成或5秒
    struct __kernel_timespec ts = {.tv_sec = 5, .tv_nsec = 0};
    sqe = io_uring_get_sqe(ring);
    io_uring_prep_timeout(sqe, &ts, 2, 0);  // count=2
    sqe->user_data = 200;

    printf("提交3个NOP + 超时(等待2个完成或5秒)...\n");
    io_uring_submit(ring);

    // 收集结果
    int count = 0;
    while (count < 4) {
        io_uring_wait_cqe(ring, &cqe);
        printf("CQE: user_data=%llu, res=%d",
               (unsigned long long)cqe->user_data, cqe->res);

        if (cqe->user_data == 200) {
            if (cqe->res == 0) {
                printf(" (已有2个完成，超时触发)");
            } else if (cqe->res == -ETIME) {
                printf(" (时间到，不足2个完成)");
            }
        }
        printf("\n");
        io_uring_cqe_seen(ring, cqe);
        count++;
    }
}

int main() {
    printf("=== io_uring 超时与取消示例 ===\n");

    struct io_uring ring;
    int ret = io_uring_queue_init(QUEUE_DEPTH, &ring, 0);
    if (ret < 0) {
        fprintf(stderr, "io_uring_queue_init: %s\n", strerror(-ret));
        return 1;
    }

    demo_standalone_timeout(&ring);
    demo_linked_timeout(&ring);
    demo_cancel_operation(&ring);
    demo_timeout_with_count(&ring);

    io_uring_queue_exit(&ring);
    printf("\n示例完成\n");
    return 0;
}

/*
 * 运行示例：
 *
 * $ ./io_uring_timeout_cancel
 * === io_uring 超时与取消示例 ===
 *
 * === 独立超时演示 ===
 * 提交2秒超时...
 * 等待超时...
 * 超时触发！(res=-62, -ETIME)
 *
 * === 链接超时演示 ===
 * 提交recv操作（带1秒超时保护）...
 * CQE: user_data=10, res=-125 (recv被超时取消)
 * CQE: user_data=11, res=-114 (超时已触发)
 *
 * === 取消操作演示 ===
 * 提交60秒超时...
 * 取消超时操作...
 * CQE: user_data=101, res=0 (取消请求成功)
 * CQE: user_data=100, res=-125 (超时被成功取消)
 *
 * === 等待N个完成后超时 ===
 * 提交3个NOP + 超时(等待2个完成或5秒)...
 * CQE: user_data=1, res=0
 * CQE: user_data=2, res=0
 * CQE: user_data=200, res=0 (已有2个完成，超时触发)
 * CQE: user_data=3, res=0
 *
 * 示例完成
 */
```

#### Multishot Accept（Linux 5.19+）

```cpp
/*
 * Multishot特性（Linux 5.19+）：
 *
 * 传统accept：
 * ┌──────────┐     ┌──────────┐     ┌──────────┐
 * │ submit   │ ──▶ │ complete │ ──▶ │ submit   │ ──▶ ...
 * │ accept   │     │ 1个连接  │     │ accept   │
 * └──────────┘     └──────────┘     └──────────┘
 * (每个连接需要重新提交)
 *
 * Multishot accept：
 * ┌──────────┐     ┌──────────┐
 * │ submit   │ ──▶ │ complete │ ──▶ 继续等待
 * │ multishot│     │ 1个连接  │ ──┐
 * │ accept   │     └──────────┘   │
 * └──────────┘                    │
 *      ▲                          │
 *      └──────────────────────────┘
 * (一次提交，多次完成)
 *
 * API：
 * io_uring_prep_multishot_accept(sqe, fd, addr, addrlen, flags)
 *
 * CQE标志：
 * - IORING_CQE_F_MORE: 还会有更多CQE
 *
 * 结束条件：
 * - 显式取消
 * - 监听socket关闭
 * - 错误发生
 */

// Multishot accept示例（需要Linux 5.19+）
void multishot_accept_example(struct io_uring *ring, int listen_fd) {
    struct io_uring_sqe *sqe = io_uring_get_sqe(ring);

    // 检查内核是否支持multishot
    #ifdef IORING_ACCEPT_MULTISHOT
    io_uring_prep_multishot_accept(sqe, listen_fd, NULL, NULL, 0);
    sqe->user_data = 1;
    io_uring_submit(ring);

    while (running) {
        struct io_uring_cqe *cqe;
        io_uring_wait_cqe(ring, &cqe);

        if (cqe->res >= 0) {
            int client_fd = cqe->res;
            handle_new_connection(client_fd);

            // 检查是否还有更多
            if (cqe->flags & IORING_CQE_F_MORE) {
                // 还会有更多连接，不需要重新提交
            } else {
                // multishot结束，可能需要重新提交
                break;
            }
        } else {
            fprintf(stderr, "accept error: %s\n", strerror(-cqe->res));
            break;
        }

        io_uring_cqe_seen(ring, cqe);
    }
    #else
    fprintf(stderr, "Multishot accept requires Linux 5.19+\n");
    #endif
}
```

#### Day 19-21 自测问答

```
Day 19-21 自测问答：

Q1: IOSQE_IO_LINK和IOSQE_IO_HARDLINK的区别？
A1: 软链接(LINK)：前面失败，后面取消(-ECANCELED)
    硬链接(HARDLINK)：前面失败，后面仍然执行
    软链接用于依赖关系，硬链接用于"尽力执行"。

Q2: io_uring_prep_timeout的count参数是什么？
A2: 等待count个CQE完成后触发超时。
    - count=0：只看时间
    - count=N：等待N个完成或时间到（先到者触发）
    常用于"等待一批操作或超时"场景。

Q3: 链接超时如何工作？
A3: 链接超时紧跟被保护的操作，通过LINK连接。
    如果操作在超时前完成：超时被取消(-ECANCELED)
    如果超时先到：操作被取消(-ECANCELED)
    两个CQE的结果互斥。

Q4: 如何取消特定的操作？
A4: 使用io_uring_prep_cancel：
    - 按user_data取消：io_uring_prep_cancel(sqe, user_data, 0)
    - 按fd取消：设置IORING_ASYNC_CANCEL_FD标志
    取消成功返回0，未找到返回-ENOENT。

Q5: Multishot accept的优势是什么？
A5: 一次提交，多次完成，减少：
    1. SQE分配开销
    2. submit系统调用次数
    3. 竞争条件窗口
    CQE的IORING_CQE_F_MORE标志表示还有更多。
```

---

### 第三周检验标准

```
第三周自我检验清单：

理论理解：
☐ 能解释SQPOLL模式的工作原理
☐ 理解sq_thread_idle参数的作用
☐ 能说出SQPOLL的适用场景和代价
☐ 理解register_files的性能优势
☐ 理解register_buffers的内存锁定机制
☐ 能解释IOSQE_IO_LINK的语义
☐ 理解链接超时的工作机制
☐ 知道Multishot特性的版本要求

实践能力：
☐ 能配置SQPOLL模式
☐ 能检测SQ线程是否需要唤醒
☐ 能使用固定fd进行I/O操作
☐ 能使用固定buffer进行I/O操作
☐ 能创建操作链（read→write）
☐ 能使用链接超时保护慢操作
☐ 能使用cancel取消操作
☐ 能评估注册优化的性能收益
```

---

## 第四周：io_uring实战与性能对比（Day 22-28）

> **本周目标**：将io_uring知识综合应用，实现高性能服务器，并与epoll进行性能对比分析。

```
第四周知识图谱：

                    ┌─────────────────────────────────────┐
                    │      io_uring实战与对比             │
                    └─────────────────┬───────────────────┘
                                      │
          ┌───────────────────────────┼───────────────────────────┐
          │                           │                           │
          ▼                           ▼                           ▼
   ┌──────────────┐          ┌──────────────┐          ┌──────────────┐
   │  Echo服务器  │          │  性能对比    │          │  生产实践    │
   │  完整实现    │          │  io_uring    │          │  与总结      │
   │              │          │  vs epoll    │          │              │
   └──────┬───────┘          └──────┬───────┘          └──────┬───────┘
          │                         │                         │
    ┌─────┴─────┐             ┌─────┴─────┐             ┌─────┴─────┐
    │           │             │           │             │           │
    ▼           ▼             ▼           ▼             ▼           ▼
┌───────┐  ┌───────┐     ┌───────┐  ┌───────┐     ┌───────┐  ┌───────┐
│状态机 │  │缓冲区 │     │QPS    │  │延迟   │     │错误   │  │兼容性 │
│设计   │  │池管理 │     │对比   │  │对比   │     │处理   │  │检测   │
└───────┘  └───────┘     └───────┘  └───────┘     └───────┘  └───────┘
```

---

### Day 22-23：高性能Echo服务器（10小时）

#### 学习目标

```
Day 22-23 学习目标：

核心目标：实现完整的io_uring Echo服务器
├── 1. 设计Request状态机（ACCEPT→READ→WRITE）
├── 2. 实现缓冲区池管理器
├── 3. 处理连接生命周期管理
├── 4. 实现优雅的错误处理
└── 5. 支持高并发连接

时间分配：
├── Day 22上午（2.5h）：架构设计与状态机
├── Day 22下午（2.5h）：缓冲区池实现
├── Day 23上午（2.5h）：完整服务器实现
└── Day 23下午（2.5h）：测试与调优
```

#### 服务器架构设计

```cpp
/*
 * io_uring Echo服务器架构：
 *
 * ┌─────────────────────────────────────────────────────────────┐
 * │                    IoUringServer                            │
 * │                                                             │
 * │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
 * │  │ BufferPool  │    │ ConnectionMgr│    │ io_uring    │     │
 * │  │ 缓冲区池    │    │ 连接管理器   │    │ 核心        │     │
 * │  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘     │
 * │         │                  │                  │             │
 * │         └──────────────────┼──────────────────┘             │
 * │                            │                                │
 * │                   ┌────────▼────────┐                       │
 * │                   │   Event Loop    │                       │
 * │                   │   主事件循环    │                       │
 * │                   └─────────────────┘                       │
 * └─────────────────────────────────────────────────────────────┘
 *
 * 状态机设计：
 *
 *     ┌─────────────────────────────────────────┐
 *     │                                         │
 *     ▼                                         │
 * ┌───────┐     新连接     ┌───────┐           │
 * │ACCEPT │ ─────────────▶ │ READ  │           │
 * └───────┘                └───┬───┘           │
 *     │                        │               │
 *     │ 继续accept             │ 收到数据      │
 *     │                        ▼               │
 *     │                   ┌───────┐            │
 *     │                   │ WRITE │            │
 *     │                   └───┬───┘            │
 *     │                       │                │
 *     │                       │ 发送完成       │
 *     │                       │                │
 *     │                       └────────────────┘
 *     │                              继续读取
 *     │
 *     │         错误/关闭
 *     │              │
 *     │              ▼
 *     │        ┌───────┐
 *     │        │ CLOSE │
 *     │        └───────┘
 *     │
 *     └──▶ 重新提交accept
 */
```

#### 示例18：缓冲区池管理器

```cpp
// 文件：examples/week4/buffer_pool.hpp
// 功能：高效的缓冲区池实现
// 用途：避免频繁的内存分配

#pragma once
#include <vector>
#include <queue>
#include <cstdlib>
#include <cstring>
#include <stdexcept>

/*
 * 缓冲区池设计：
 *
 * 问题：每次I/O都分配/释放内存效率低
 *
 * 解决：预分配缓冲区池，循环使用
 *
 * ┌─────────────────────────────────────┐
 * │           BufferPool                │
 * │                                     │
 * │  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐  │
 * │  │buf 0│ │buf 1│ │buf 2│ │buf 3│  │  预分配的缓冲区
 * │  └──┬──┘ └──┬──┘ └──┬──┘ └──┬──┘  │
 * │     │       │       │       │      │
 * │  ┌──▼───────▼───────▼───────▼──┐   │
 * │  │       free_list             │   │  空闲列表
 * │  │    [0, 1, 2, 3, ...]       │   │
 * │  └─────────────────────────────┘   │
 * └─────────────────────────────────────┘
 *
 * 操作：
 * - acquire(): 从池中获取一个缓冲区
 * - release(idx): 归还缓冲区到池中
 */

class BufferPool {
public:
    struct Buffer {
        char *data;
        size_t size;
        size_t used;
        int index;  // 在池中的索引
    };

    BufferPool(size_t buffer_size, size_t pool_size)
        : buffer_size_(buffer_size), pool_size_(pool_size) {

        buffers_.resize(pool_size);

        for (size_t i = 0; i < pool_size; i++) {
            void *ptr = nullptr;
            if (posix_memalign(&ptr, 4096, buffer_size) != 0) {
                throw std::runtime_error("Failed to allocate buffer");
            }
            buffers_[i].data = static_cast<char*>(ptr);
            buffers_[i].size = buffer_size;
            buffers_[i].used = 0;
            buffers_[i].index = static_cast<int>(i);
            free_list_.push(i);
        }
    }

    ~BufferPool() {
        for (auto &buf : buffers_) {
            free(buf.data);
        }
    }

    Buffer* acquire() {
        if (free_list_.empty()) return nullptr;
        int idx = free_list_.front();
        free_list_.pop();
        Buffer *buf = &buffers_[idx];
        buf->used = 0;
        return buf;
    }

    void release(Buffer *buf) {
        if (buf && buf->index >= 0 && buf->index < (int)pool_size_) {
            free_list_.push(buf->index);
        }
    }

    void release(int index) {
        if (index >= 0 && index < (int)pool_size_) {
            free_list_.push(index);
        }
    }

    Buffer* get(int index) {
        if (index >= 0 && index < (int)pool_size_) {
            return &buffers_[index];
        }
        return nullptr;
    }

    size_t available() const { return free_list_.size(); }
    size_t capacity() const { return pool_size_; }

private:
    size_t buffer_size_;
    size_t pool_size_;
    std::vector<Buffer> buffers_;
    std::queue<int> free_list_;
};
```

#### 示例19：完整的IoUringServer

```cpp
// 文件：examples/week4/io_uring_server.cpp
// 功能：完整的高性能io_uring Echo服务器
// 编译：g++ -o io_uring_server io_uring_server.cpp -luring -std=c++17 -O2

#include <liburing.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <map>
#include <memory>

#define PORT 8080
#define QUEUE_DEPTH 256
#define BUFFER_SIZE 4096
#define MAX_CONNECTIONS 10000

// 请求类型编码
enum RequestType : uint8_t {
    REQ_ACCEPT = 1,
    REQ_READ   = 2,
    REQ_WRITE  = 3
};

inline uint64_t make_user_data(RequestType type, int fd) {
    return ((uint64_t)type << 56) | (fd & 0xFFFFFFFF);
}

inline RequestType get_type(uint64_t data) {
    return static_cast<RequestType>(data >> 56);
}

inline int get_fd(uint64_t data) {
    return data & 0xFFFFFFFF;
}

struct Connection {
    int fd;
    char buffer[BUFFER_SIZE];
    size_t buffer_len;
    bool active;
    Connection() : fd(-1), buffer_len(0), active(false) {}
};

static volatile bool g_running = true;
static struct io_uring g_ring;
static int g_listen_fd = -1;
static std::map<int, std::unique_ptr<Connection>> g_connections;
static uint64_t g_total_requests = 0;

void signal_handler(int sig) {
    (void)sig;
    g_running = false;
}

int create_listen_socket(int port) {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) return -1;

    int opt = 1;
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in addr = {};
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(port);

    if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        close(fd);
        return -1;
    }
    listen(fd, SOMAXCONN);
    return fd;
}

void submit_accept() {
    struct io_uring_sqe *sqe = io_uring_get_sqe(&g_ring);
    if (!sqe) return;
    io_uring_prep_accept(sqe, g_listen_fd, nullptr, nullptr, 0);
    sqe->user_data = make_user_data(REQ_ACCEPT, g_listen_fd);
}

void submit_read(Connection *conn) {
    struct io_uring_sqe *sqe = io_uring_get_sqe(&g_ring);
    if (!sqe) return;
    io_uring_prep_recv(sqe, conn->fd, conn->buffer, BUFFER_SIZE - 1, 0);
    sqe->user_data = make_user_data(REQ_READ, conn->fd);
}

void submit_write(Connection *conn) {
    struct io_uring_sqe *sqe = io_uring_get_sqe(&g_ring);
    if (!sqe) return;
    io_uring_prep_send(sqe, conn->fd, conn->buffer, conn->buffer_len, 0);
    sqe->user_data = make_user_data(REQ_WRITE, conn->fd);
}

void close_connection(int fd) {
    auto it = g_connections.find(fd);
    if (it != g_connections.end()) {
        close(fd);
        g_connections.erase(it);
    }
}

void handle_accept(int res) {
    if (res < 0) {
        submit_accept();
        return;
    }
    int client_fd = res;
    fcntl(client_fd, F_SETFL, fcntl(client_fd, F_GETFL) | O_NONBLOCK);

    auto conn = std::make_unique<Connection>();
    conn->fd = client_fd;
    conn->active = true;
    Connection *conn_ptr = conn.get();
    g_connections[client_fd] = std::move(conn);

    submit_read(conn_ptr);
    submit_accept();
}

void handle_read(int fd, int res) {
    auto it = g_connections.find(fd);
    if (it == g_connections.end()) return;
    Connection *conn = it->second.get();

    if (res <= 0) {
        close_connection(fd);
        return;
    }

    conn->buffer[res] = '\0';
    conn->buffer_len = res;
    g_total_requests++;
    submit_write(conn);
}

void handle_write(int fd, int res) {
    auto it = g_connections.find(fd);
    if (it == g_connections.end()) return;
    Connection *conn = it->second.get();

    if (res <= 0) {
        close_connection(fd);
        return;
    }
    submit_read(conn);
}

void event_loop() {
    while (g_running) {
        io_uring_submit(&g_ring);
        struct io_uring_cqe *cqe;
        int ret = io_uring_wait_cqe(&g_ring, &cqe);
        if (ret < 0) {
            if (ret == -EINTR) continue;
            break;
        }

        unsigned head;
        unsigned count = 0;
        io_uring_for_each_cqe(&g_ring, head, cqe) {
            RequestType type = get_type(cqe->user_data);
            int fd = get_fd(cqe->user_data);
            int res = cqe->res;

            switch (type) {
            case REQ_ACCEPT: handle_accept(res); break;
            case REQ_READ:   handle_read(fd, res); break;
            case REQ_WRITE:  handle_write(fd, res); break;
            }
            count++;
        }
        io_uring_cq_advance(&g_ring, count);
    }
}

int main(int argc, char *argv[]) {
    int port = argc > 1 ? atoi(argv[1]) : PORT;
    signal(SIGINT, signal_handler);
    signal(SIGPIPE, SIG_IGN);

    printf("=== io_uring Echo服务器 ===\n");

    g_listen_fd = create_listen_socket(port);
    if (g_listen_fd < 0) {
        perror("创建监听socket失败");
        return 1;
    }
    printf("监听端口: %d\n", port);

    if (io_uring_queue_init(QUEUE_DEPTH, &g_ring, 0) < 0) {
        perror("io_uring初始化失败");
        return 1;
    }

    submit_accept();
    printf("等待连接...\n");

    event_loop();

    printf("\n总请求数: %lu\n", g_total_requests);
    for (auto &kv : g_connections) close(kv.first);
    io_uring_queue_exit(&g_ring);
    close(g_listen_fd);
    return 0;
}

/*
 * 测试方法：
 * 终端1: ./io_uring_server
 * 终端2: nc localhost 8080
 *        输入任意内容，服务器会回显
 */
```

#### Day 22-23 自测问答

```
Day 22-23 自测问答：

Q1: 为什么Echo服务器使用状态机设计？
A1: 异步I/O需要追踪每个连接的当前状态：
    - ACCEPT等待新连接
    - READ等待数据到来
    - WRITE等待发送完成
    状态机确保操作按正确顺序进行。

Q2: user_data的编码方式有什么好处？
A2: 将多个信息打包到64位user_data中：
    - 请求类型（区分accept/read/write）
    - 文件描述符（定位连接）
    避免了额外的查找开销。

Q3: 为什么需要缓冲区池？
A3: 频繁的malloc/free开销大，缓冲区池：
    1. 预分配，避免运行时分配
    2. 重用，减少内存碎片
    3. 对齐，提高I/O性能

Q4: handle_read中res==0意味着什么？
A4: 对端关闭连接（收到FIN）。
    应该关闭本端socket并清理连接资源。

Q5: 为什么在accept后设置O_NONBLOCK？
A5: io_uring本身是异步的，但配合非阻塞socket：
    1. 避免意外阻塞
    2. 与EAGAIN正确交互
    3. 防止单个慢操作阻塞整个服务
```

---

### Day 24-25：io_uring vs epoll性能对比（10小时）

#### 学习目标

```
Day 24-25 学习目标：

核心目标：进行io_uring与epoll的性能对比
├── 1. 设计公平的基准测试
├── 2. 对比QPS（每秒请求数）
├── 3. 对比延迟P50/P99
├── 4. 对比系统调用次数
└── 5. 分析不同场景的适用性

时间分配：
├── Day 24上午（2.5h）：基准测试设计
├── Day 24下午（2.5h）：epoll服务器实现
├── Day 25上午（2.5h）：性能测试执行
└── Day 25下午（2.5h）：结果分析总结
```

#### 性能对比框架

```cpp
/*
 * io_uring vs epoll 性能对比：
 *
 * 测试维度：
 * ┌────────────────────────────────────────────────────────┐
 * │  维度            │  io_uring优势      │  epoll优势     │
 * ├────────────────────────────────────────────────────────┤
 * │  系统调用次数    │  ✓ 批量提交        │               │
 * │  延迟（低并发）  │                    │  ✓ 简单直接   │
 * │  延迟（高并发）  │  ✓ 批量收割        │               │
 * │  CPU使用率      │  ✓ 减少上下文切换   │               │
 * │  内存使用       │                    │  ✓ 更少开销   │
 * │  兼容性         │                    │  ✓ 老内核支持 │
 * │  复杂度         │                    │  ✓ API简单    │
 * └────────────────────────────────────────────────────────┘
 *
 * 测试场景：
 * 1. Echo服务器（短连接、小消息）
 * 2. 文件服务器（大文件传输）
 * 3. 混合负载（不同消息大小）
 *
 * 测试指标：
 * - QPS: 每秒请求数
 * - Latency: P50, P90, P99, P99.9
 * - CPU: 用户态/内核态时间
 * - Syscalls: strace统计
 */
```

#### 示例20：epoll Echo服务器（对比用）

```cpp
// 文件：examples/week4/epoll_echo_server.cpp
// 功能：epoll Echo服务器（用于与io_uring对比）
// 编译：g++ -o epoll_echo_server epoll_echo_server.cpp -std=c++17 -O2

#include <sys/epoll.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <map>

#define PORT 8081
#define MAX_EVENTS 256
#define BUFFER_SIZE 4096

static volatile bool g_running = true;
static uint64_t g_total_requests = 0;

void signal_handler(int sig) {
    (void)sig;
    g_running = false;
}

int set_nonblocking(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    return fcntl(fd, F_SETFL, flags | O_NONBLOCK);
}

int create_listen_socket(int port) {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) return -1;

    int opt = 1;
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in addr = {};
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(port);

    if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        close(fd);
        return -1;
    }

    listen(fd, SOMAXCONN);
    set_nonblocking(fd);
    return fd;
}

int main(int argc, char *argv[]) {
    int port = argc > 1 ? atoi(argv[1]) : PORT;
    signal(SIGINT, signal_handler);
    signal(SIGPIPE, SIG_IGN);

    printf("=== epoll Echo服务器 ===\n");

    int listen_fd = create_listen_socket(port);
    if (listen_fd < 0) {
        perror("创建监听socket失败");
        return 1;
    }
    printf("监听端口: %d\n", port);

    int epfd = epoll_create1(0);
    if (epfd < 0) {
        perror("epoll_create1失败");
        return 1;
    }

    struct epoll_event ev;
    ev.events = EPOLLIN;
    ev.data.fd = listen_fd;
    epoll_ctl(epfd, EPOLL_CTL_ADD, listen_fd, &ev);

    std::map<int, char*> buffers;
    struct epoll_event events[MAX_EVENTS];

    printf("等待连接...\n");

    while (g_running) {
        int nfds = epoll_wait(epfd, events, MAX_EVENTS, 1000);
        if (nfds < 0) {
            if (errno == EINTR) continue;
            break;
        }

        for (int i = 0; i < nfds; i++) {
            int fd = events[i].data.fd;

            if (fd == listen_fd) {
                // Accept新连接
                while (true) {
                    int client_fd = accept(listen_fd, nullptr, nullptr);
                    if (client_fd < 0) break;

                    set_nonblocking(client_fd);
                    ev.events = EPOLLIN | EPOLLET;
                    ev.data.fd = client_fd;
                    epoll_ctl(epfd, EPOLL_CTL_ADD, client_fd, &ev);

                    buffers[client_fd] = new char[BUFFER_SIZE];
                }
            } else {
                // 读写数据
                char *buf = buffers[fd];
                if (!buf) continue;

                ssize_t n = recv(fd, buf, BUFFER_SIZE - 1, 0);
                if (n <= 0) {
                    epoll_ctl(epfd, EPOLL_CTL_DEL, fd, nullptr);
                    close(fd);
                    delete[] buf;
                    buffers.erase(fd);
                    continue;
                }

                buf[n] = '\0';
                g_total_requests++;

                // Echo回去
                send(fd, buf, n, 0);
            }
        }
    }

    printf("\n总请求数: %lu\n", g_total_requests);

    for (auto &kv : buffers) {
        close(kv.first);
        delete[] kv.second;
    }
    close(epfd);
    close(listen_fd);
    return 0;
}
```

#### 示例21：性能测试脚本

```bash
#!/bin/bash
# 文件：examples/week4/benchmark.sh
# 功能：io_uring vs epoll 性能对比测试

echo "=== io_uring vs epoll 性能对比 ==="
echo ""

# 配置
DURATION=10
CONNECTIONS=100
THREADS=4

# 检查依赖
check_deps() {
    for cmd in nc time strace; do
        if ! command -v $cmd &> /dev/null; then
            echo "缺少依赖: $cmd"
            exit 1
        fi
    done
}

# 简单压力测试
stress_test() {
    local port=$1
    local name=$2
    local count=10000

    echo "--- $name 测试 (端口 $port) ---"

    # 记录开始时间
    start=$(date +%s.%N)

    # 发送请求
    for i in $(seq 1 $count); do
        echo "test$i" | nc -q 0 localhost $port > /dev/null 2>&1 &
        if [ $((i % 100)) -eq 0 ]; then
            wait
        fi
    done
    wait

    # 计算耗时
    end=$(date +%s.%N)
    elapsed=$(echo "$end - $start" | bc)
    qps=$(echo "scale=2; $count / $elapsed" | bc)

    echo "请求数: $count"
    echo "耗时: ${elapsed}s"
    echo "QPS: $qps"
    echo ""
}

# 系统调用统计
syscall_test() {
    local port=$1
    local name=$2
    local pid=$3

    echo "--- $name 系统调用统计 ---"

    # 使用strace统计5秒
    timeout 5 strace -c -p $pid 2>&1 | grep -E "^(io_uring|epoll|read|write|recv|send)" || true
    echo ""
}

# 主测试流程
main() {
    check_deps

    echo "请确保以下服务器正在运行："
    echo "  1. io_uring服务器: ./io_uring_server 8080"
    echo "  2. epoll服务器: ./epoll_echo_server 8081"
    echo ""
    read -p "按回车继续..."

    # 测试io_uring
    stress_test 8080 "io_uring"

    # 测试epoll
    stress_test 8081 "epoll"

    echo "=== 测试完成 ==="
}

main "$@"
```

#### 性能对比结果分析

```
io_uring vs epoll 典型测试结果：

┌──────────────────────────────────────────────────────────────┐
│                    Echo服务器对比                             │
├──────────────────────────────────────────────────────────────┤
│  指标              │  io_uring      │  epoll        │  差异  │
├──────────────────────────────────────────────────────────────┤
│  QPS (100连接)     │  ~150,000      │  ~120,000     │ +25%   │
│  QPS (1000连接)    │  ~180,000      │  ~130,000     │ +38%   │
│  QPS (10000连接)   │  ~200,000      │  ~140,000     │ +43%   │
├──────────────────────────────────────────────────────────────┤
│  P50延迟          │  0.8ms         │  1.0ms        │ -20%   │
│  P99延迟          │  2.5ms         │  4.0ms        │ -37%   │
│  P99.9延迟        │  5.0ms         │  12.0ms       │ -58%   │
├──────────────────────────────────────────────────────────────┤
│  系统调用/请求     │  ~0.5          │  ~3           │ -83%   │
│  CPU用户态占比     │  65%           │  55%          │ +18%   │
└──────────────────────────────────────────────────────────────┘

分析：
1. io_uring在高并发场景优势明显（批量提交/收割）
2. 延迟尾部（P99.9）改善显著（减少系统调用阻塞）
3. 系统调用减少带来CPU效率提升

注意：实际结果受硬件、内核版本、负载特征影响
```

#### Day 24-25 自测问答

```
Day 24-25 自测问答：

Q1: io_uring在什么场景下优势最明显？
A1: 高并发、小I/O场景优势最明显：
    - 大量短连接
    - 频繁的小消息收发
    - 需要批量处理的场景
    原因：系统调用开销占比高时，减少系统调用收益大。

Q2: epoll在什么场景下仍然适用？
A2: 以下场景epoll仍是好选择：
    - 老内核系统（< 5.1）
    - 简单应用，不需要极致性能
    - 已有成熟epoll代码库
    - 需要最广泛兼容性

Q3: 如何设计公平的对比测试？
A3: 公平测试要点：
    1. 相同硬件环境
    2. 相同网络配置
    3. 相同应用逻辑
    4. 充分预热
    5. 多次测试取平均
    6. 控制其他变量

Q4: 为什么io_uring的P99.9延迟改善最明显？
A4: P99.9代表最慢的0.1%请求：
    - epoll：偶尔遇到大量系统调用排队
    - io_uring：批量处理，减少排队
    尾部延迟对用户体验影响大。

Q5: 系统调用减少83%是如何实现的？
A5: io_uring减少系统调用的机制：
    - 批量submit：多个请求一次提交
    - 批量收割：多个完成一次获取
    - SQPOLL：甚至0系统调用提交
    epoll每次read/write都是独立系统调用。
```

---

### Day 26-27：生产环境实践（10小时）

#### 学习目标

```
Day 26-27 学习目标：

核心目标：掌握io_uring生产环境最佳实践
├── 1. 实现健壮的错误处理
├── 2. 进行内核版本兼容性检测
├── 3. 设计与现有框架的集成策略
├── 4. 了解io_uring的适用与不适用场景
└── 5. 掌握调试和问题排查技巧

时间分配：
├── Day 26上午（2.5h）：错误处理最佳实践
├── Day 26下午（2.5h）：兼容性检测
├── Day 27上午（2.5h）：框架集成策略
└── Day 27下午（2.5h）：调试技巧总结
```

#### 错误处理最佳实践

```cpp
/*
 * io_uring错误处理策略：
 *
 * CQE.res值解释：
 * ┌────────────────────────────────────────────────┐
 * │  res值        │  含义                          │
 * ├────────────────────────────────────────────────┤
 * │  > 0          │  成功，返回字节数/fd           │
 * │  == 0         │  EOF（recv）或无数据           │
 * │  < 0          │  错误码的负值                  │
 * └────────────────────────────────────────────────┘
 *
 * 常见错误码：
 * -EAGAIN/-EWOULDBLOCK: 非阻塞操作无数据
 * -ECONNRESET: 连接被对端重置
 * -EPIPE: 写入已关闭的连接
 * -ECANCELED: 操作被取消
 * -ETIME: 超时
 * -ENOBUFS: 缓冲区不足
 */

// 错误处理示例
void handle_cqe_result(int res, int fd, const char* op_name) {
    if (res >= 0) {
        // 成功
        return;
    }

    int err = -res;

    switch (err) {
    case EAGAIN:
        // 非阻塞，稍后重试
        printf("[%s] fd=%d: 暂无数据，稍后重试\n", op_name, fd);
        break;

    case ECONNRESET:
        // 连接重置，关闭并清理
        printf("[%s] fd=%d: 连接被重置\n", op_name, fd);
        close_and_cleanup(fd);
        break;

    case EPIPE:
        // 管道/连接已关闭
        printf("[%s] fd=%d: 连接已关闭\n", op_name, fd);
        close_and_cleanup(fd);
        break;

    case ECANCELED:
        // 操作被取消（如超时）
        printf("[%s] fd=%d: 操作被取消\n", op_name, fd);
        break;

    case ETIME:
        // 超时
        printf("[%s] fd=%d: 操作超时\n", op_name, fd);
        break;

    default:
        // 其他错误
        printf("[%s] fd=%d: 错误 %d (%s)\n",
               op_name, fd, err, strerror(err));
        break;
    }
}
```

#### 示例22：内核版本兼容性检测

```cpp
// 文件：examples/week4/io_uring_compat.cpp
// 功能：io_uring特性兼容性检测
// 编译：g++ -o io_uring_compat io_uring_compat.cpp -luring

#include <liburing.h>
#include <sys/utsname.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*
 * io_uring特性与内核版本对应：
 *
 * Linux 5.1:  io_uring首次引入
 * Linux 5.4:  IORING_OP_TIMEOUT
 * Linux 5.5:  IORING_OP_ACCEPT
 * Linux 5.6:  IORING_OP_SPLICE, 更多网络操作
 * Linux 5.7:  IORING_OP_PROVIDE_BUFFERS
 * Linux 5.10: 稳定性改进（LTS）
 * Linux 5.11: SQPOLL无需CAP_SYS_ADMIN
 * Linux 5.19: Multishot accept/recv
 * Linux 6.0:  更多优化
 */

struct FeatureCheck {
    const char *name;
    unsigned feature_flag;
    const char *min_kernel;
};

FeatureCheck features[] = {
    {"IORING_FEAT_SINGLE_MMAP",     IORING_FEAT_SINGLE_MMAP,     "5.4"},
    {"IORING_FEAT_NODROP",          IORING_FEAT_NODROP,          "5.5"},
    {"IORING_FEAT_SUBMIT_STABLE",   IORING_FEAT_SUBMIT_STABLE,   "5.5"},
    {"IORING_FEAT_RW_CUR_POS",      IORING_FEAT_RW_CUR_POS,      "5.6"},
    {"IORING_FEAT_CUR_PERSONALITY", IORING_FEAT_CUR_PERSONALITY, "5.6"},
    {"IORING_FEAT_FAST_POLL",       IORING_FEAT_FAST_POLL,       "5.7"},
    {"IORING_FEAT_POLL_32BITS",     IORING_FEAT_POLL_32BITS,     "5.9"},
    {"IORING_FEAT_SQPOLL_NONFIXED", IORING_FEAT_SQPOLL_NONFIXED, "5.11"},
    {"IORING_FEAT_NATIVE_WORKERS",  IORING_FEAT_NATIVE_WORKERS,  "5.12"},
};

void print_kernel_version() {
    struct utsname uts;
    if (uname(&uts) == 0) {
        printf("当前内核: %s %s\n", uts.sysname, uts.release);
    }
}

void check_io_uring_support() {
    printf("\n=== io_uring支持检测 ===\n\n");

    struct io_uring ring;
    struct io_uring_params params = {};

    int ret = io_uring_queue_init_params(8, &ring, &params);
    if (ret < 0) {
        printf("io_uring不可用: %s\n", strerror(-ret));
        printf("需要Linux 5.1+内核\n");
        return;
    }

    printf("io_uring初始化成功\n\n");

    // 检查特性
    printf("特性支持情况:\n");
    printf("%-30s %-10s %s\n", "特性", "支持", "最低内核");
    printf("%-30s %-10s %s\n", "---", "---", "---");

    for (const auto &f : features) {
        bool supported = (params.features & f.feature_flag) != 0;
        printf("%-30s %-10s %s\n",
               f.name,
               supported ? "✓" : "✗",
               f.min_kernel);
    }

    // 检查操作码支持
    printf("\n操作码支持检测:\n");

    struct {
        const char *name;
        int opcode;
    } opcodes[] = {
        {"IORING_OP_NOP",        IORING_OP_NOP},
        {"IORING_OP_READV",      IORING_OP_READV},
        {"IORING_OP_WRITEV",     IORING_OP_WRITEV},
        {"IORING_OP_READ",       IORING_OP_READ},
        {"IORING_OP_WRITE",      IORING_OP_WRITE},
        {"IORING_OP_ACCEPT",     IORING_OP_ACCEPT},
        {"IORING_OP_CONNECT",    IORING_OP_CONNECT},
        {"IORING_OP_SEND",       IORING_OP_SEND},
        {"IORING_OP_RECV",       IORING_OP_RECV},
        {"IORING_OP_TIMEOUT",    IORING_OP_TIMEOUT},
        {"IORING_OP_CANCEL",     IORING_OP_ASYNC_CANCEL},
    };

    for (const auto &op : opcodes) {
        // 通过probe检测
        struct io_uring_probe *probe = io_uring_get_probe_ring(&ring);
        if (probe) {
            bool supported = io_uring_opcode_supported(probe, op.opcode);
            printf("  %-25s %s\n", op.name, supported ? "✓" : "✗");
            io_uring_free_probe(probe);
        }
    }

    io_uring_queue_exit(&ring);
}

void check_sqpoll_support() {
    printf("\n=== SQPOLL支持检测 ===\n\n");

    struct io_uring ring;
    struct io_uring_params params = {};
    params.flags = IORING_SETUP_SQPOLL;
    params.sq_thread_idle = 1000;

    int ret = io_uring_queue_init_params(8, &ring, &params);
    if (ret == 0) {
        printf("SQPOLL: ✓ 支持\n");
        io_uring_queue_exit(&ring);
    } else if (ret == -EPERM) {
        printf("SQPOLL: ✗ 需要root权限或Linux 5.11+\n");
    } else {
        printf("SQPOLL: ✗ 错误: %s\n", strerror(-ret));
    }
}

int main() {
    print_kernel_version();
    check_io_uring_support();
    check_sqpoll_support();

    printf("\n检测完成\n");
    return 0;
}

/*
 * 运行示例：
 *
 * $ ./io_uring_compat
 * 当前内核: Linux 5.15.0-generic
 *
 * === io_uring支持检测 ===
 *
 * io_uring初始化成功
 *
 * 特性支持情况:
 * 特性                          支持       最低内核
 * ---                           ---        ---
 * IORING_FEAT_SINGLE_MMAP       ✓          5.4
 * IORING_FEAT_NODROP            ✓          5.5
 * ...
 *
 * === SQPOLL支持检测 ===
 *
 * SQPOLL: ✓ 支持
 *
 * 检测完成
 */
```

#### io_uring适用场景总结

```
io_uring适用与不适用场景：

适用场景：
┌─────────────────────────────────────────────────────────────┐
│ 场景                     │ 原因                             │
├─────────────────────────────────────────────────────────────┤
│ 高性能网络服务器          │ 批量I/O，减少系统调用            │
│ 数据库存储引擎           │ 大量随机I/O，异步提交            │
│ 消息队列                 │ 高吞吐，低延迟要求               │
│ 代理/网关服务            │ 大量连接，需要高并发             │
│ 实时数据处理             │ 延迟敏感，需要确定性             │
└─────────────────────────────────────────────────────────────┘

不适用场景：
┌─────────────────────────────────────────────────────────────┐
│ 场景                     │ 原因                             │
├─────────────────────────────────────────────────────────────┤
│ 简单命令行工具           │ 复杂度不值得                     │
│ 低频I/O应用             │ 系统调用开销不是瓶颈              │
│ 需要老内核兼容           │ 需要Linux 5.1+                   │
│ CPU密集型应用           │ I/O不是瓶颈                      │
│ 单线程简单服务           │ epoll足够                       │
└─────────────────────────────────────────────────────────────┘

决策流程：
            ┌─────────────────┐
            │ 需要高性能I/O？  │
            └────────┬────────┘
                     │
            ┌────────▼────────┐
            │ 内核 >= 5.1？   │──否──▶ 使用epoll
            └────────┬────────┘
                     │是
            ┌────────▼────────┐
            │ 高并发/大吞吐？  │──否──▶ epoll可能足够
            └────────┬────────┘
                     │是
            ┌────────▼────────┐
            │ 团队熟悉io_uring？│──否──▶ 先学习，评估收益
            └────────┬────────┘
                     │是
                     ▼
              使用io_uring
```

#### Day 26-27 自测问答

```
Day 26-27 自测问答：

Q1: CQE.res为负数时如何处理？
A1: res是错误码的负值，需要取反获取errno：
    int err = -cqe->res;
    根据具体错误码决定：重试、关闭连接、或记录日志。

Q2: 如何检测内核是否支持特定io_uring特性？
A2: 两种方法：
    1. 检查params.features标志位
    2. 使用io_uring_get_probe检测操作码
    建议在初始化时检测，提供降级方案。

Q3: io_uring与libuv/libevent如何集成？
A3: 集成策略：
    1. 替换底层I/O：修改库的backend
    2. 并行使用：特定操作用io_uring
    3. 逐步迁移：关键路径先切换
    已有库：liburing、io_uring-go等。

Q4: 如何调试io_uring问题？
A4: 调试方法：
    1. strace跟踪系统调用
    2. perf分析性能瓶颈
    3. 检查CQE.res错误码
    4. 使用io_uring_peek_cqe检查队列状态
    5. 日志记录user_data用于追踪

Q5: 生产环境使用io_uring需要注意什么？
A5: 关键注意事项：
    1. 内核版本检测和降级方案
    2. 充分的错误处理
    3. 资源限制（max_entries、locked memory）
    4. 监控（队列深度、延迟统计）
    5. 渐进式上线
```

---

### Day 28：项目总结与构建（5小时）

#### 项目目录结构

```
io_uring_learning/
├── CMakeLists.txt           # 构建配置
├── README.md                # 项目说明
├── src/
│   ├── buffer_pool.hpp      # 缓冲区池
│   ├── io_uring_server.cpp  # io_uring服务器
│   └── epoll_server.cpp     # epoll服务器（对比）
├── examples/
│   ├── week1/
│   │   ├── io_uring_stdin.cpp
│   │   ├── io_uring_file_read.cpp
│   │   └── io_uring_params.cpp
│   ├── week2/
│   │   ├── io_uring_file_complete.cpp
│   │   ├── io_uring_vectored.cpp
│   │   ├── io_uring_accept.cpp
│   │   ├── io_uring_echo.cpp
│   │   └── io_uring_batch.cpp
│   ├── week3/
│   │   ├── io_uring_sqpoll.cpp
│   │   ├── io_uring_registered.cpp
│   │   ├── io_uring_linked.cpp
│   │   └── io_uring_timeout.cpp
│   └── week4/
│       ├── io_uring_server.cpp
│       ├── epoll_echo_server.cpp
│       ├── io_uring_compat.cpp
│       └── benchmark.sh
├── tests/
│   └── test_buffer_pool.cpp
└── notes/
    └── month28_io_uring.md
```

#### 示例23：CMakeLists.txt

```cmake
# 文件：CMakeLists.txt
cmake_minimum_required(VERSION 3.10)
project(io_uring_learning)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra -O2")

# 查找liburing
find_library(URING_LIB uring)
if(NOT URING_LIB)
    message(FATAL_ERROR "liburing not found. Install with: apt install liburing-dev")
endif()

# 主服务器
add_executable(io_uring_server src/io_uring_server.cpp)
target_link_libraries(io_uring_server ${URING_LIB})

add_executable(epoll_server src/epoll_server.cpp)

# Week1 示例
add_executable(io_uring_stdin examples/week1/io_uring_stdin.cpp)
target_link_libraries(io_uring_stdin ${URING_LIB})

# Week2 示例
add_executable(io_uring_echo examples/week2/io_uring_echo.cpp)
target_link_libraries(io_uring_echo ${URING_LIB})

# Week3 示例
add_executable(io_uring_sqpoll examples/week3/io_uring_sqpoll.cpp)
target_link_libraries(io_uring_sqpoll ${URING_LIB} pthread)

# Week4 示例
add_executable(io_uring_compat examples/week4/io_uring_compat.cpp)
target_link_libraries(io_uring_compat ${URING_LIB})

# 安装
install(TARGETS io_uring_server DESTINATION bin)
```

#### 第四周检验标准

```
第四周自我检验清单：

理论理解：
☐ 能设计异步服务器的状态机
☐ 理解缓冲区池的设计原理
☐ 能分析io_uring vs epoll的性能差异
☐ 理解各种CQE错误码的含义
☐ 知道io_uring的适用场景
☐ 能进行内核版本兼容性检测

实践能力：
☐ 能实现完整的io_uring Echo服务器
☐ 能实现高效的缓冲区池
☐ 能设计和执行性能对比测试
☐ 能正确处理各种错误情况
☐ 能使用CMake构建项目
☐ 能将io_uring集成到现有代码
```

---

## 本月检验标准汇总

```
Month-28 综合检验清单（io_uring新一代异步I/O）：

=== 理论理解（20项）===

基础概念：
☐ 能解释传统I/O的系统调用开销问题
☐ 能画出io_uring的SQ/CQ环形缓冲区结构
☐ 理解SQE和CQE的关键字段
☐ 理解user_data在请求-响应关联中的作用

核心API：
☐ 能说出io_uring_prep_read/write的参数含义
☐ 理解向量I/O的优势
☐ 能描述io_uring网络操作的异步流程
☐ 理解for_each_cqe与cq_advance的配合

高级特性：
☐ 能解释SQPOLL模式的工作原理
☐ 理解register_files/buffers的性能优势
☐ 能解释IOSQE_IO_LINK的语义
☐ 理解链接超时的工作机制

实战应用：
☐ 能设计异步服务器的状态机
☐ 能分析io_uring vs epoll的性能差异
☐ 理解各种CQE错误码的含义
☐ 知道io_uring的适用场景

=== 实践能力（20项）===

基础实践：
☐ 能完成liburing的编译安装
☐ 能使用io_uring读取标准输入
☐ 能使用io_uring读写文件
☐ 能正确使用io_uring_params配置

网络编程：
☐ 能实现io_uring accept服务器
☐ 能编写完整的Echo服务器
☐ 能使用批量处理API
☐ 能正确管理Request生命周期

高级特性：
☐ 能配置SQPOLL模式
☐ 能使用固定fd和buffer进行I/O
☐ 能创建操作链
☐ 能使用超时和取消操作

生产实践：
☐ 能实现缓冲区池管理器
☐ 能设计和执行性能测试
☐ 能正确处理各种错误
☐ 能进行内核版本兼容性检测

完成度自评：_____ / 40
```

---

## 输出物清单

```
Month-28 输出物检查表：

代码文件：
☐ buffer_pool.hpp          - 缓冲区池实现
☐ io_uring_server.cpp      - 完整Echo服务器
☐ epoll_server.cpp         - 对比用epoll服务器
☐ io_uring_compat.cpp      - 兼容性检测工具
☐ CMakeLists.txt           - 构建配置

示例代码（23个）：
☐ 示例1-6: Week1基础示例
☐ 示例7-13: Week2核心API示例
☐ 示例14-17: Week3高级特性示例
☐ 示例18-23: Week4实战示例

文档：
☐ notes/month28_io_uring.md - 学习笔记
☐ README.md                  - 项目说明

测试：
☐ benchmark.sh              - 性能测试脚本
☐ test_buffer_pool.cpp      - 单元测试
```

---

## 学习建议

```
io_uring学习路径建议：

          ┌─────────────────────────────────────────┐
          │           学习路径图                     │
          └─────────────────────────────────────────┘

     Week 1                Week 2               Week 3              Week 4
   ┌─────────┐          ┌─────────┐          ┌─────────┐         ┌─────────┐
   │ 基础    │    ──▶   │ 核心    │    ──▶   │ 高级    │   ──▶   │ 实战    │
   │ 概念    │          │  API    │          │ 特性    │         │ 对比    │
   └─────────┘          └─────────┘          └─────────┘         └─────────┘
       │                    │                    │                   │
       ▼                    ▼                    ▼                   ▼
   理解原理            文件/网络I/O          SQPOLL/注册         服务器实现
   环境搭建            批量处理              链接/超时           性能测试

调试技巧：
┌─────────────────────────────────────────────────────────────────┐
│ 问题              │ 调试方法                                    │
├─────────────────────────────────────────────────────────────────┤
│ CQE未返回         │ 检查是否调用了submit                        │
│ res返回负值       │ 打印strerror(-res)查看错误                  │
│ 性能不如预期      │ strace统计系统调用，perf分析热点            │
│ SQPOLL不工作      │ 检查权限和内核版本                          │
│ 内存泄漏          │ 确保CQE处理后释放对应资源                   │
└─────────────────────────────────────────────────────────────────┘

常见错误与解决：
┌─────────────────────────────────────────────────────────────────┐
│ 错误                      │ 解决方案                            │
├─────────────────────────────────────────────────────────────────┤
│ 忘记io_uring_cqe_seen     │ 每个CQE处理后必须调用               │
│ submit后立即释放buffer    │ 等CQE返回后再释放                   │
│ SQ满导致get_sqe返回NULL  │ 先submit或使用更大队列              │
│ 混淆fd和fixed_fd索引      │ 使用IOSQE_FIXED_FILE时fd是索引      │
│ 忽略短读/短写             │ 检查res与请求长度是否相等           │
└─────────────────────────────────────────────────────────────────┘
```

---

## 结语

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│            🎉 恭喜完成 Month-28 学习！ 🎉                       │
│                                                                 │
│    io_uring——Linux新一代异步I/O的核心知识已掌握！              │
│                                                                 │
│    本月收获：                                                   │
│    ✓ 理解io_uring的革命性设计                                  │
│    ✓ 掌握SQ/CQ环形缓冲区机制                                   │
│    ✓ 熟练使用文件和网络I/O API                                 │
│    ✓ 掌握SQPOLL、注册优化等高级特性                            │
│    ✓ 能实现高性能异步服务器                                    │
│    ✓ 能进行io_uring vs epoll性能对比                          │
│                                                                 │
│    io_uring代表了Linux I/O的未来方向：                         │
│    - 批量提交减少系统调用                                       │
│    - 共享内存避免数据拷贝                                       │
│    - 统一接口支持多种I/O类型                                   │
│                                                                 │
│    下月预告：Month-29 零拷贝技术                               │
│    - sendfile/splice/mmap                                      │
│    - 用户态协议栈概念                                          │
│    - 构建超高性能文件服务器                                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 下月预告

**Month 29：零拷贝技术——消除数据拷贝开销**

```
Month-29 学习预览：

核心主题：零拷贝技术

第一周：传统I/O与零拷贝原理
├── 传统I/O的4次数据拷贝
├── 零拷贝的设计目标
└── Linux零拷贝技术概览

第二周：sendfile系统调用
├── sendfile工作原理
├── DMA gather操作
└── 大文件传输优化

第三周：splice与vmsplice
├── splice管道中转
├── vmsplice用户空间映射
└── 零拷贝代理服务器

第四周：mmap与用户态协议栈
├── mmap文件映射
├── DPDK概念介绍
└── 高性能文件服务器

io_uring + 零拷贝 = 极致性能！
```

---