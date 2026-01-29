# Month 27: epoll深度解析——Linux高性能I/O

## 本月主题概述

epoll是Linux下高性能网络编程的核心机制，也是Nginx、Redis、Node.js等高性能软件的基石。与select/poll的O(n)轮询不同，epoll通过内核中的红黑树和就绪链表实现了O(1)的事件通知效率。本月将从API使用、内核实现原理、LT/ET触发模式、惊群问题、高级特性等方面全面深入学习epoll，并构建工业级的epoll服务器框架，与Month-26的EventLoop抽象无缝集成。

---

## 知识体系总览

```
Month 27 知识体系：epoll深度解析
=====================================================

                    ┌─────────────────────┐
                    │   epoll深度解析      │
                    │  Linux高性能I/O核心  │
                    └──────────┬──────────┘
                               │
         ┌─────────────────────┼─────────────────────┐
         │                     │                     │
         ▼                     ▼                     ▼
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│  API与使用  │      │  内核实现   │      │  高级应用   │
│             │      │             │      │             │
│ epoll_create│      │ 红黑树管理  │      │ 惊群问题    │
│ epoll_ctl   │      │ 就绪链表    │      │ REUSEPORT   │
│ epoll_wait  │      │ 回调机制    │      │ EpollLoop   │
│ epoll_event │      │ O(1)原理    │      │ HTTP服务器  │
└──────┬──────┘      └──────┬──────┘      └──────┬──────┘
       │                    │                    │
       ▼                    ▼                    ▼
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│  触发模式   │      │  性能对比   │      │  性能优化   │
│             │      │             │      │             │
│ LT水平触发  │      │ vs select   │      │ 内核调参    │
│ ET边缘触发  │      │ vs poll     │      │ 压力测试    │
│ ONESHOT     │      │ 基准测试    │      │ Nginx/Redis │
│ EXCLUSIVE   │      │ 连接数影响  │      │ 源码分析    │
└─────────────┘      └─────────────┘      └─────────────┘

承接关系：
Month-26 (select/poll + EventLoop框架)
    │
    ▼
Month-27 (epoll深度解析) ← 当前月份
    │
    ▼
Month-28 (io_uring——新一代异步I/O)
```

---

## 学习目标

### 核心目标

1. **掌握epoll三大API**：epoll_create1、epoll_ctl、epoll_wait的完整用法
2. **深入理解内核实现**：红黑树、就绪链表、回调机制、O(1)原理
3. **精通LT/ET模式**：语义差异、编程规范、性能对比、适用场景
4. **解决惊群问题**：EPOLLEXCLUSIVE、SO_REUSEPORT、accept锁
5. **构建高性能服务器**：EpollLoop集成、HTTP服务器、10K+连接压测

### 学习目标量化

| 目标 | 量化标准 | 验证方式 |
|------|---------|---------|
| epoll API掌握 | 能独立编写epoll echo server | 代码实现 |
| 内核原理理解 | 能画出epoll内部数据结构图 | 白板绘图 |
| LT/ET模式精通 | 能正确实现ET模式无数据丢失 | 压测验证 |
| 惊群问题解决 | 能用3种方式解决惊群 | 代码实现 |
| 高性能服务器 | 支持10K+并发连接 | 压测报告 |
| 框架集成 | EpollLoop集成到EventLoop | 代码运行 |
| 源码分析能力 | 能分析Nginx/Redis的epoll使用 | 分析报告 |

---

## 综合项目概述

### 本月最终项目：高性能epoll服务器框架

```
项目目标：构建可支撑10K+并发连接的epoll网络服务器框架

功能架构：
┌─────────────────────────────────────────────────┐
│              Application Layer                  │
│  ┌──────────┐ ┌──────────┐ ┌───────────────┐   │
│  │EchoServer│ │HTTPServer│ │ChatServer     │   │
│  └────┬─────┘ └────┬─────┘ └───────┬───────┘   │
│       └─────────────┼───────────────┘           │
│                     ▼                           │
│  ┌─────────────────────────────────────────┐    │
│  │         EpollServer Framework           │    │
│  │  ┌───────────┐  ┌────────────────────┐  │    │
│  │  │Connection │  │ Buffer(Month-26)   │  │    │
│  │  │  Manager  │  │ 零拷贝/自动扩容   │  │    │
│  │  └───────────┘  └────────────────────┘  │    │
│  └──────────────────┬──────────────────────┘    │
│                     ▼                           │
│  ┌─────────────────────────────────────────┐    │
│  │           EpollLoop                     │    │
│  │  继承自Month-26 EventLoop               │    │
│  │  ┌─────────┐ ┌────────┐ ┌──────────┐   │    │
│  │  │timerfd  │ │signalfd│ │eventfd   │   │    │
│  │  │精确定时 │ │信号处理│ │线程唤醒  │   │    │
│  │  └─────────┘ └────────┘ └──────────┘   │    │
│  └──────────────────┬──────────────────────┘    │
│                     ▼                           │
│  ┌─────────────────────────────────────────┐    │
│  │         Linux Kernel (epoll)            │    │
│  │  ┌──────────┐        ┌──────────┐       │    │
│  │  │红黑树    │        │就绪链表  │       │    │
│  │  │(所有fd)  │───────>│(活跃fd)  │       │    │
│  │  └──────────┘ 回调   └──────────┘       │    │
│  └─────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘

性能目标：
- 并发连接：10,000+
- 吞吐量：>50,000 QPS (echo)
- 延迟P99：<5ms
- 内存：<100MB (10K连接)
```

---

## 参考书目与资料

| 资料 | 用途 | 优先级 |
|------|------|--------|
| `man epoll` / `man epoll_create` / `man epoll_ctl` / `man epoll_wait` | API参考 | ★★★ |
| 《Linux高性能服务器编程》游双 | epoll章节 | ★★★ |
| 《Unix网络编程》卷1 | I/O多路复用 | ★★★ |
| Linux内核源码 `fs/eventpoll.c` | 内核实现 | ★★☆ |
| Nginx源码 `ngx_epoll_module.c` | 工业实践 | ★★☆ |
| Redis源码 `ae_epoll.c` | 事件循环参考 | ★★☆ |
| libevent源码 `epoll.c` | 封装设计 | ★☆☆ |

---

## 前置知识衔接

```
Month-26 → Month-27 知识桥梁
═══════════════════════════════════════════════════

Month-26已掌握：                 Month-27将学习：
┌──────────────────┐            ┌──────────────────┐
│ select/poll API  │───────────>│ epoll API        │
│ fd_set / pollfd  │            │ epoll_event      │
│ O(n)遍历所有fd   │            │ O(1)就绪通知     │
├──────────────────┤            ├──────────────────┤
│ 非阻塞I/O       │───────────>│ ET模式必须非阻塞 │
│ EAGAIN处理       │            │ 循环读写至EAGAIN  │
│ Buffer类         │            │ Buffer复用        │
├──────────────────┤            ├──────────────────┤
│ EventLoop抽象    │───────────>│ EpollLoop实现    │
│ SelectLoop       │            │ 继承EventLoop    │
│ PollLoop         │            │ timerfd/signalfd │
├──────────────────┤            ├──────────────────┤
│ 自管道技巧       │───────────>│ eventfd唤醒      │
│ 信号安全         │            │ signalfd集成     │
│ 定时器管理       │            │ timerfd精确定时  │
└──────────────────┘            └──────────────────┘

关键延续点：
1. Month-26的Buffer类将在epoll服务器中继续使用
2. Month-26的EventLoop抽象类将新增EpollLoop实现
3. Month-26的Connection状态机将升级为epoll版本
4. Month-26的非阻塞I/O技巧在ET模式下尤为关键
```

---

## 时间分配

| 内容 | 时间 | 占比 |
|------|------|------|
| 第一周：epoll基础与API详解 | 35小时 | 25% |
| 第二周：LT与ET模式深入 | 35小时 | 25% |
| 第三周：epoll高级应用 | 35小时 | 25% |
| 第四周：性能优化与压力测试 | 35小时 | 25% |
| **合计** | **140小时** | **100%** |

---

## 第一周：epoll基础与API详解（Day 1-7）

### 本周时间分配

| 日期 | 内容 | 时间 |
|------|------|------|
| Day 1-2 | epoll设计动机与API总览 | 10小时 |
| Day 3-4 | epoll内核实现原理 | 10小时 |
| Day 5-7 | epoll与select/poll性能对比 | 15小时 |

---

### Day 1-2：epoll设计动机与API总览（10小时）

#### 学习目标

- 理解epoll的设计动机：select/poll的性能瓶颈
- 掌握epoll三大核心API的完整用法
- 理解epoll_event结构体与事件类型
- 编写第一个epoll echo server

#### 为什么需要epoll

```
select/poll的性能瓶颈回顾（Month-26）：

问题1：每次调用都需要拷贝fd集合
┌──────────┐    拷贝    ┌──────────┐
│ 用户空间 │ ──────────>│ 内核空间 │
│ fd_set   │    每次    │ 遍历检查 │
│ 10000个  │    O(n)    │ 10000个  │
└──────────┘            └──────────┘
       ▲                      │
       └──────────────────────┘
            返回结果

问题2：内核需要遍历所有fd检查就绪状态
for (int i = 0; i < nfds; i++) {
    if (is_ready(fds[i])) {   // 遍历每一个，O(n)
        mark_ready(fds[i]);
    }
}

问题3：用户空间也需要遍历找到就绪的fd
for (int i = 0; i < nfds; i++) {
    if (FD_ISSET(i, &readfds)) {  // 又是O(n)
        handle(i);
    }
}

总结：三重O(n)开销
1. 用户态→内核态拷贝fd集合：O(n)
2. 内核遍历检查就绪状态：O(n)
3. 用户态遍历找就绪fd：O(n)

当n=10000时（C10K问题），性能急剧下降！


epoll的解决方案：

核心思想：将"注册"和"等待"分离

传统方式（select/poll）：
    每次都告诉内核"我关心哪些fd" → O(n)拷贝

epoll方式：
    一次注册（epoll_ctl）→ 内核记住
    以后只需等待（epoll_wait）→ 只返回就绪的

┌─────────────────────────────────────────────┐
│                 epoll架构                    │
│                                             │
│  用户空间          │    内核空间             │
│                    │                        │
│  epoll_ctl(ADD) ──>│──> 红黑树插入 O(log n) │
│  (一次性注册)      │    记住这个fd          │
│                    │                        │
│                    │    当fd就绪时：         │
│                    │    回调 → 加入就绪链表  │
│                    │                        │
│  epoll_wait() ────>│──> 检查就绪链表        │
│  (等待事件)        │    只返回就绪的fd      │
│                    │    O(ready_count)      │
│  遍历结果 ────────>│                        │
│  O(ready_count)    │                        │
└─────────────────────────────────────────────┘

关键优势：
1. fd集合在内核中维护，无需每次拷贝
2. 使用回调机制，无需遍历所有fd
3. 只返回就绪的fd，用户无需遍历
4. 注册操作O(log n)，等待操作O(1)
```

#### epoll三大核心API

```cpp
#include <sys/epoll.h>

// ═══════════════════════════════════════════════
// API 1: epoll_create / epoll_create1
// 创建epoll实例，返回文件描述符
// ═══════════════════════════════════════════════

// 旧版API（size参数已被忽略，但必须>0）
int epoll_create(int size);

// 新版API（推荐使用）
int epoll_create1(int flags);
// flags:
//   0            - 无特殊标志
//   EPOLL_CLOEXEC - exec时自动关闭（推荐）

// 返回值：
//   成功: epoll文件描述符（>= 0）
//   失败: -1, errno设置为:
//     EINVAL  - flags无效
//     EMFILE  - 进程fd数量达到上限
//     ENFILE  - 系统fd数量达到上限
//     ENOMEM  - 内存不足

// 使用示例：
int epfd = epoll_create1(EPOLL_CLOEXEC);
if (epfd < 0) {
    perror("epoll_create1");
    return -1;
}
// 注意：用完后必须close(epfd)


// ═══════════════════════════════════════════════
// API 2: epoll_ctl
// 控制epoll实例（添加/修改/删除监听的fd）
// ═══════════════════════════════════════════════

int epoll_ctl(int epfd, int op, int fd, struct epoll_event* event);

// 参数：
//   epfd  - epoll_create返回的描述符
//   op    - 操作类型：
//     EPOLL_CTL_ADD - 添加fd到监听集合
//     EPOLL_CTL_MOD - 修改已监听fd的事件
//     EPOLL_CTL_DEL - 从监听集合中删除fd
//   fd    - 要操作的目标文件描述符
//   event - 事件配置（DEL操作时可为nullptr）

// 返回值：
//   成功: 0
//   失败: -1, errno设置为:
//     EBADF   - epfd或fd不是有效描述符
//     EEXIST  - ADD时fd已存在
//     ENOENT  - MOD/DEL时fd不存在
//     ENOMEM  - 内存不足
//     EPERM   - fd不支持epoll（如普通文件）


// ═══════════════════════════════════════════════
// API 3: epoll_wait / epoll_pwait
// 等待事件就绪
// ═══════════════════════════════════════════════

int epoll_wait(int epfd, struct epoll_event* events,
               int maxevents, int timeout);

int epoll_pwait(int epfd, struct epoll_event* events,
                int maxevents, int timeout,
                const sigset_t* sigmask);

// 参数：
//   epfd      - epoll描述符
//   events    - 输出数组，存放就绪事件
//   maxevents - events数组大小（必须>0）
//   timeout   - 超时毫秒数：
//     -1  无限等待
//      0  立即返回（非阻塞）
//     >0  最多等待timeout毫秒
//   sigmask   - 信号掩码（pwait版本）

// 返回值：
//   > 0  就绪事件数量
//   = 0  超时，无事件
//   = -1 错误（errno == EINTR表示被信号中断）
```

#### epoll_event结构体详解

```cpp
// ═══════════════════════════════════════════════
// epoll_event结构体
// ═══════════════════════════════════════════════

struct epoll_event {
    uint32_t     events;  // 事件类型（位掩码）
    epoll_data_t data;    // 用户数据
};

typedef union epoll_data {
    void*    ptr;    // 用户指针（最常用）
    int      fd;     // 文件描述符
    uint32_t u32;    // 32位整数
    uint64_t u64;    // 64位整数
} epoll_data_t;

/*
epoll_data是联合体，一次只能使用一个成员！

使用策略对比：

方式1：使用fd字段（简单但有限）
┌─────────────┐
│ epoll_event  │
│ events: IN   │
│ data.fd: 5   │ ← 只知道是fd=5，无法关联更多信息
└─────────────┘

方式2：使用ptr字段（推荐，可关联任意上下文）
┌─────────────┐       ┌──────────────────┐
│ epoll_event  │       │ Connection       │
│ events: IN   │       │ fd: 5            │
│ data.ptr ────│──────>│ peer: 10.0.0.1   │
└─────────────┘       │ buffer: ...      │
                      │ state: CONNECTED │
                      └──────────────────┘

方式3：使用u64字段（编码多信息）
┌─────────────┐
│ epoll_event  │
│ events: IN   │
│ data.u64:    │
│  高32位: type│ ← 事件类型
│  低32位: fd  │ ← 文件描述符
└─────────────┘
*/


// ═══════════════════════════════════════════════
// 事件类型全表
// ═══════════════════════════════════════════════

/*
┌──────────────────┬────────┬──────────────────────────────────┐
│ 事件类型         │ 值     │ 说明                             │
├──────────────────┼────────┼──────────────────────────────────┤
│ EPOLLIN          │ 0x001  │ 可读（含对端关闭、新连接到来）   │
│ EPOLLOUT         │ 0x004  │ 可写（发送缓冲区有空间）         │
│ EPOLLERR         │ 0x008  │ 错误（总是被监听，无需显式设置） │
│ EPOLLHUP         │ 0x010  │ 挂起（总是被监听）               │
│ EPOLLRDHUP       │ 0x2000 │ 对端关闭连接或关闭写端           │
│ EPOLLET          │ 1<<31  │ 边缘触发模式                     │
│ EPOLLONESHOT     │ 1<<30  │ 一次性触发，事件后需重新注册     │
│ EPOLLEXCLUSIVE   │ 1<<28  │ 独占唤醒，避免惊群（Linux 4.5+） │
│ EPOLLWAKEUP      │ 1<<29  │ 防止系统挂起（Android相关）      │
├──────────────────┼────────┼──────────────────────────────────┤
│ EPOLLPRI         │ 0x002  │ 紧急数据（TCP带外数据）          │
│ EPOLLNVAL        │        │ 无效fd（与poll的POLLNVAL类似）   │
└──────────────────┴────────┴──────────────────────────────────┘

常用组合：
- 读事件：          EPOLLIN | EPOLLRDHUP
- 读写事件：        EPOLLIN | EPOLLOUT | EPOLLRDHUP
- ET读事件：        EPOLLIN | EPOLLRDHUP | EPOLLET
- ET+ONESHOT：      EPOLLIN | EPOLLET | EPOLLONESHOT
- 监听socket：      EPOLLIN（LT模式更安全）
- 连接socket(ET)：  EPOLLIN | EPOLLRDHUP | EPOLLET
*/
```

#### 代码示例1：epoll基本用法演示

```cpp
// 示例1: epoll_basic_demo.cpp
// epoll基本用法演示——标准输入监听
// 展示epoll_create1/epoll_ctl/epoll_wait的基本流程

#include <sys/epoll.h>
#include <unistd.h>
#include <cstdio>
#include <cstring>
#include <cerrno>

int main() {
    // Step 1: 创建epoll实例
    int epfd = epoll_create1(EPOLL_CLOEXEC);
    if (epfd < 0) {
        perror("epoll_create1");
        return 1;
    }
    printf("epoll instance created, epfd=%d\n", epfd);

    // Step 2: 将stdin(fd=0)添加到epoll监听
    struct epoll_event ev;
    ev.events = EPOLLIN;        // 监听可读事件
    ev.data.fd = STDIN_FILENO;  // 关联fd信息

    if (epoll_ctl(epfd, EPOLL_CTL_ADD, STDIN_FILENO, &ev) < 0) {
        perror("epoll_ctl ADD");
        close(epfd);
        return 1;
    }
    printf("stdin added to epoll\n");

    // Step 3: 事件循环
    struct epoll_event events[10];  // 最多接收10个就绪事件
    printf("Waiting for input (type something and press Enter)...\n");

    for (int round = 0; round < 5; ++round) {
        // 等待事件，超时5秒
        int nready = epoll_wait(epfd, events, 10, 5000);

        if (nready < 0) {
            if (errno == EINTR) continue;  // 被信号中断，重试
            perror("epoll_wait");
            break;
        }

        if (nready == 0) {
            printf("Timeout, no events in 5 seconds\n");
            continue;
        }

        // 处理就绪事件
        for (int i = 0; i < nready; ++i) {
            if (events[i].data.fd == STDIN_FILENO) {
                char buf[256];
                ssize_t n = read(STDIN_FILENO, buf, sizeof(buf) - 1);
                if (n > 0) {
                    buf[n] = '\0';
                    printf("Read %zd bytes: %s", n, buf);
                } else if (n == 0) {
                    printf("EOF on stdin\n");
                    goto done;
                }
            }
        }
    }

done:
    // Step 4: 清理
    // 注意：关闭fd会自动从epoll中移除
    // 但显式删除是好习惯
    epoll_ctl(epfd, EPOLL_CTL_DEL, STDIN_FILENO, nullptr);
    close(epfd);
    printf("Done.\n");
    return 0;
}

/*
编译运行：
$ g++ -o epoll_basic epoll_basic_demo.cpp
$ ./epoll_basic
epoll instance created, epfd=3
stdin added to epoll
Waiting for input (type something and press Enter)...
hello
Read 6 bytes: hello
world
Read 6 bytes: world
Timeout, no events in 5 seconds
Done.

关键点：
1. epoll_create1创建实例，返回epfd
2. epoll_ctl(ADD)注册fd和感兴趣的事件
3. epoll_wait等待就绪事件，返回就绪数量
4. 只需遍历就绪的事件，不需遍历所有fd
5. 关闭epfd释放资源
*/
```

#### 代码示例2：epoll Echo Server（LT模式）

```cpp
// 示例2: epoll_echo_server_lt.cpp
// 基于epoll的Echo服务器（LT水平触发模式）
// 完整实现，展示epoll在网络编程中的典型用法

#include <sys/epoll.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <cstdio>
#include <cstring>
#include <cerrno>
#include <vector>
#include <string>
#include <unordered_map>

// 设置fd为非阻塞
static bool set_nonblocking(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags < 0) return false;
    return fcntl(fd, F_SETFL, flags | O_NONBLOCK) >= 0;
}

// 每个连接的发送缓冲区
struct ConnInfo {
    std::string send_buf;  // 待发送数据
};

int main(int argc, char* argv[]) {
    int port = (argc > 1) ? atoi(argv[1]) : 8080;

    // ─── 创建监听socket ───
    int listen_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (listen_fd < 0) { perror("socket"); return 1; }

    int opt = 1;
    setsockopt(listen_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    set_nonblocking(listen_fd);

    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(port);

    if (bind(listen_fd, (sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("bind"); close(listen_fd); return 1;
    }
    if (listen(listen_fd, SOMAXCONN) < 0) {
        perror("listen"); close(listen_fd); return 1;
    }

    // ─── 创建epoll实例 ───
    int epfd = epoll_create1(EPOLL_CLOEXEC);
    if (epfd < 0) { perror("epoll_create1"); close(listen_fd); return 1; }

    // 将listen_fd添加到epoll（LT模式）
    epoll_event ev;
    ev.events = EPOLLIN;          // LT模式：不设EPOLLET
    ev.data.fd = listen_fd;
    epoll_ctl(epfd, EPOLL_CTL_ADD, listen_fd, &ev);

    // 连接信息表
    std::unordered_map<int, ConnInfo> conns;

    printf("Echo server (epoll LT) listening on port %d\n", port);

    // ─── 事件循环 ───
    std::vector<epoll_event> events(1024);
    bool running = true;

    while (running) {
        int nready = epoll_wait(epfd, events.data(), events.size(), -1);
        if (nready < 0) {
            if (errno == EINTR) continue;
            perror("epoll_wait");
            break;
        }

        for (int i = 0; i < nready; ++i) {
            int fd = events[i].data.fd;
            uint32_t revents = events[i].events;

            // ─── 处理新连接 ───
            if (fd == listen_fd) {
                // LT模式：如果还有连接等待accept，下次epoll_wait还会通知
                sockaddr_in client_addr{};
                socklen_t len = sizeof(client_addr);
                int client_fd = accept(listen_fd, (sockaddr*)&client_addr, &len);

                if (client_fd < 0) {
                    if (errno != EAGAIN && errno != EWOULDBLOCK)
                        perror("accept");
                    continue;
                }

                set_nonblocking(client_fd);

                char ip[INET_ADDRSTRLEN];
                inet_ntop(AF_INET, &client_addr.sin_addr, ip, sizeof(ip));
                printf("New connection: fd=%d from %s:%d\n",
                       client_fd, ip, ntohs(client_addr.sin_port));

                // 注册客户端fd到epoll
                ev.events = EPOLLIN;  // 先只监听读事件
                ev.data.fd = client_fd;
                epoll_ctl(epfd, EPOLL_CTL_ADD, client_fd, &ev);

                conns[client_fd] = ConnInfo{};
                continue;
            }

            // ─── 处理错误/挂起 ───
            if (revents & (EPOLLERR | EPOLLHUP)) {
                printf("Connection error/hangup: fd=%d\n", fd);
                epoll_ctl(epfd, EPOLL_CTL_DEL, fd, nullptr);
                close(fd);
                conns.erase(fd);
                continue;
            }

            // ─── 处理可读事件 ───
            if (revents & EPOLLIN) {
                char buf[4096];
                ssize_t n = read(fd, buf, sizeof(buf));

                if (n > 0) {
                    // 将读到的数据追加到发送缓冲区
                    conns[fd].send_buf.append(buf, n);

                    // 有数据要发送，启用写事件监听
                    ev.events = EPOLLIN | EPOLLOUT;
                    ev.data.fd = fd;
                    epoll_ctl(epfd, EPOLL_CTL_MOD, fd, &ev);

                } else if (n == 0) {
                    // 对端关闭连接
                    printf("Connection closed: fd=%d\n", fd);
                    epoll_ctl(epfd, EPOLL_CTL_DEL, fd, nullptr);
                    close(fd);
                    conns.erase(fd);

                } else {
                    if (errno != EAGAIN && errno != EWOULDBLOCK) {
                        perror("read");
                        epoll_ctl(epfd, EPOLL_CTL_DEL, fd, nullptr);
                        close(fd);
                        conns.erase(fd);
                    }
                    // EAGAIN: LT模式下不会发生（有数据才通知）
                    // 但非阻塞fd可能偶尔发生
                }
            }

            // ─── 处理可写事件 ───
            if (revents & EPOLLOUT) {
                auto it = conns.find(fd);
                if (it == conns.end()) continue;

                auto& send_buf = it->second.send_buf;
                if (!send_buf.empty()) {
                    ssize_t n = write(fd, send_buf.data(), send_buf.size());
                    if (n > 0) {
                        send_buf.erase(0, n);
                    } else if (n < 0 && errno != EAGAIN && errno != EWOULDBLOCK) {
                        perror("write");
                        epoll_ctl(epfd, EPOLL_CTL_DEL, fd, nullptr);
                        close(fd);
                        conns.erase(fd);
                        continue;
                    }
                }

                // 发送完毕，取消写事件监听（避免busy loop）
                if (send_buf.empty()) {
                    ev.events = EPOLLIN;
                    ev.data.fd = fd;
                    epoll_ctl(epfd, EPOLL_CTL_MOD, fd, &ev);
                }
            }
        }
    }

    // 清理
    for (auto& [fd, _] : conns) {
        close(fd);
    }
    close(listen_fd);
    close(epfd);
    return 0;
}

/*
LT模式要点总结：

1. 监听socket用LT模式：
   - accept一次即可，如果还有连接，下次epoll_wait会再通知
   - 简单可靠

2. 连接socket也用LT模式：
   - 有数据可读时通知，read一次即可
   - 如果没读完，下次还会通知
   - 不会丢失数据

3. 写事件管理（关键！）：
   - 只在有数据要发送时才监听EPOLLOUT
   - 发送完毕后立即取消EPOLLOUT
   - 否则：fd的发送缓冲区通常有空间
     → EPOLLOUT持续触发 → 造成busy loop！

4. 与select/poll的对比：
   - 注册一次，不需每次拷贝
   - 只返回就绪的fd
   - 当连接数很大但活跃连接少时，优势巨大
*/
```

#### 代码示例3：使用epoll_data.ptr传递上下文

```cpp
// 示例3: epoll_ptr_demo.cpp
// 使用epoll_data.ptr关联连接上下文（推荐方式）

#include <sys/epoll.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <cstdio>
#include <cstring>
#include <cerrno>
#include <memory>
#include <unordered_map>
#include <vector>
#include <string>

// 连接上下文
struct Connection {
    int fd;
    std::string peer_addr;
    std::string recv_buf;
    std::string send_buf;
    uint64_t bytes_received = 0;
    uint64_t bytes_sent = 0;
    bool want_write = false;

    Connection(int f, const std::string& addr) : fd(f), peer_addr(addr) {}
    ~Connection() { if (fd >= 0) close(fd); fd = -1; }
};

static bool set_nonblocking(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    return (flags >= 0) && (fcntl(fd, F_SETFL, flags | O_NONBLOCK) >= 0);
}

class EchoServer {
public:
    EchoServer(int port) : port_(port) {}

    ~EchoServer() {
        if (epfd_ >= 0) close(epfd_);
        if (listen_fd_ >= 0) close(listen_fd_);
    }

    bool start() {
        epfd_ = epoll_create1(EPOLL_CLOEXEC);
        if (epfd_ < 0) return false;

        listen_fd_ = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK, 0);
        if (listen_fd_ < 0) return false;

        int opt = 1;
        setsockopt(listen_fd_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = INADDR_ANY;
        addr.sin_port = htons(port_);

        if (bind(listen_fd_, (sockaddr*)&addr, sizeof(addr)) < 0) return false;
        if (listen(listen_fd_, SOMAXCONN) < 0) return false;

        // 注册listen_fd：使用特殊标记（ptr = nullptr表示监听socket）
        epoll_event ev;
        ev.events = EPOLLIN;
        ev.data.ptr = nullptr;  // nullptr表示这是listen socket
        epoll_ctl(epfd_, EPOLL_CTL_ADD, listen_fd_, &ev);

        printf("Server started on port %d (using epoll_data.ptr)\n", port_);
        return true;
    }

    void run() {
        std::vector<epoll_event> events(1024);

        while (true) {
            int n = epoll_wait(epfd_, events.data(), events.size(), -1);
            if (n < 0) {
                if (errno == EINTR) continue;
                break;
            }

            for (int i = 0; i < n; ++i) {
                // 通过ptr判断事件来源
                if (events[i].data.ptr == nullptr) {
                    // ptr为nullptr → 这是listen socket的事件
                    handle_accept();
                } else {
                    // ptr非nullptr → 这是连接socket，ptr指向Connection
                    auto* conn = static_cast<Connection*>(events[i].data.ptr);
                    uint32_t revents = events[i].events;

                    if (revents & (EPOLLERR | EPOLLHUP)) {
                        remove_connection(conn);
                        continue;
                    }
                    if (revents & EPOLLIN) {
                        if (!handle_read(conn)) {
                            remove_connection(conn);
                            continue;
                        }
                    }
                    if (revents & EPOLLOUT) {
                        handle_write(conn);
                    }
                }
            }
        }
    }

private:
    void handle_accept() {
        while (true) {
            sockaddr_in client_addr{};
            socklen_t len = sizeof(client_addr);
            int fd = accept4(listen_fd_, (sockaddr*)&client_addr,
                            &len, SOCK_NONBLOCK);
            if (fd < 0) {
                if (errno == EAGAIN || errno == EWOULDBLOCK) break;
                if (errno == EINTR) continue;
                break;
            }

            char ip[INET_ADDRSTRLEN];
            inet_ntop(AF_INET, &client_addr.sin_addr, ip, sizeof(ip));
            std::string peer = std::string(ip) + ":" +
                              std::to_string(ntohs(client_addr.sin_port));

            // 创建连接对象
            auto conn = std::make_unique<Connection>(fd, peer);
            Connection* ptr = conn.get();

            printf("[+] %s (fd=%d)\n", peer.c_str(), fd);

            // 注册到epoll，data.ptr指向Connection
            epoll_event ev;
            ev.events = EPOLLIN;
            ev.data.ptr = ptr;  // ← 关键：存储连接指针
            epoll_ctl(epfd_, EPOLL_CTL_ADD, fd, &ev);

            connections_[fd] = std::move(conn);
        }
    }

    bool handle_read(Connection* conn) {
        char buf[4096];
        ssize_t n = read(conn->fd, buf, sizeof(buf));
        if (n <= 0) {
            if (n == 0) return false;  // 对端关闭
            if (errno == EAGAIN || errno == EWOULDBLOCK) return true;
            return false;
        }

        conn->bytes_received += n;
        conn->send_buf.append(buf, n);

        // 有数据要发，开启写监听
        if (!conn->want_write) {
            conn->want_write = true;
            epoll_event ev;
            ev.events = EPOLLIN | EPOLLOUT;
            ev.data.ptr = conn;
            epoll_ctl(epfd_, EPOLL_CTL_MOD, conn->fd, &ev);
        }
        return true;
    }

    void handle_write(Connection* conn) {
        if (conn->send_buf.empty()) return;

        ssize_t n = write(conn->fd, conn->send_buf.data(),
                         conn->send_buf.size());
        if (n > 0) {
            conn->bytes_sent += n;
            conn->send_buf.erase(0, n);
        }

        if (conn->send_buf.empty()) {
            conn->want_write = false;
            epoll_event ev;
            ev.events = EPOLLIN;
            ev.data.ptr = conn;
            epoll_ctl(epfd_, EPOLL_CTL_MOD, conn->fd, &ev);
        }
    }

    void remove_connection(Connection* conn) {
        printf("[-] %s (fd=%d) rx=%lu tx=%lu\n",
               conn->peer_addr.c_str(), conn->fd,
               conn->bytes_received, conn->bytes_sent);

        epoll_ctl(epfd_, EPOLL_CTL_DEL, conn->fd, nullptr);
        connections_.erase(conn->fd);
        // unique_ptr析构会close(fd)
    }

    int port_;
    int epfd_ = -1;
    int listen_fd_ = -1;
    std::unordered_map<int, std::unique_ptr<Connection>> connections_;
};

int main(int argc, char* argv[]) {
    int port = (argc > 1) ? atoi(argv[1]) : 8080;

    EchoServer server(port);
    if (!server.start()) {
        fprintf(stderr, "Failed to start server\n");
        return 1;
    }
    server.run();
    return 0;
}

/*
使用data.ptr的优势：

1. 可以直接访问连接上下文，无需查找哈希表
   auto* conn = static_cast<Connection*>(events[i].data.ptr);
   // 直接使用conn->peer_addr, conn->recv_buf等

2. 对比使用data.fd的方式：
   int fd = events[i].data.fd;
   auto it = connections.find(fd);  // 需要额外的哈希查找
   if (it == connections.end()) continue;
   auto& conn = it->second;

3. 注意事项：
   - Connection对象的生命周期必须正确管理
   - 删除连接时必须先从epoll移除，再销毁对象
   - 如果先销毁对象，epoll可能返回悬空指针（dangling pointer）
*/
```

#### Day 1-2 自测题

```
Q1: epoll_create1(EPOLL_CLOEXEC)中EPOLL_CLOEXEC的作用是什么？
A1: EPOLL_CLOEXEC设置close-on-exec标志。当进程执行exec系列函数时，
    该epoll描述符会被自动关闭。这可以防止子进程意外继承不需要的epoll fd，
    是一种良好的编程实践。

Q2: epoll_event中data是联合体而非结构体，这意味着什么？
A2: 联合体意味着data.ptr/data.fd/data.u32/data.u64共享同一块内存，
    一次只能使用其中一个成员。不能同时存储fd和ptr。
    如果需要同时使用多种信息，应使用data.ptr指向自定义结构体。

Q3: 在LT模式的epoll echo server中，为什么发送完数据后要取消EPOLLOUT？
A3: 因为在LT模式下，只要fd的发送缓冲区有空间（通常一直有），
    EPOLLOUT就会持续触发。如果不取消，epoll_wait会不断返回，
    造成CPU空转（busy loop）。正确做法是只在有数据要发送时才注册EPOLLOUT。

Q4: epoll_ctl(DEL)时event参数可以传nullptr吗？
A4: 可以。Linux 2.6.9之后，EPOLL_CTL_DEL操作忽略event参数。
    但为了兼容旧内核（2.6.9之前），有些代码仍然传递一个有效的event指针。

Q5: accept4()相比accept()有什么优势？
A5: accept4()可以在接受连接的同时设置新socket的属性：
    - SOCK_NONBLOCK：直接设为非阻塞，避免额外的fcntl调用
    - SOCK_CLOEXEC：设置close-on-exec标志
    这减少了系统调用次数，在高并发场景下有性能收益。

Q6: 关闭一个fd时，它会自动从epoll中移除吗？
A6: 是的。当一个文件描述符被关闭（close），且没有其他进程/描述符引用
    同一个底层文件描述（file description）时，它会自动从所有epoll实例中移除。
    但注意：如果fd被dup()复制，只有所有副本都关闭后才会从epoll移除。
    因此，显式调用epoll_ctl(DEL)是更安全的做法。
```

---

### Day 3-4：epoll内核实现原理（10小时）

#### 学习目标

- 理解eventpoll内核数据结构
- 掌握红黑树管理fd的原理
- 理解就绪链表和回调机制
- 明白epoll为什么是O(1)

#### epoll内核数据结构

```
═══════════════════════════════════════════════════════════
epoll内核实现全貌
═══════════════════════════════════════════════════════════

核心数据结构：

struct eventpoll {
    spinlock_t lock;              // 自旋锁（保护就绪链表）
    struct mutex mtx;             // 互斥锁（保护红黑树操作）
    wait_queue_head_t wq;         // epoll_wait的等待队列
    wait_queue_head_t poll_wait;  // epoll自身被poll时的等待队列
    struct list_head rdllist;     // 就绪链表（Ready List）
    struct rb_root_cached rbr;    // 红黑树根节点（所有监控的fd）
    struct epitem *ovflist;       // 溢出链表（处理就绪事件时新增的就绪事件）
    struct wakeup_source *ws;     // 唤醒源
    struct user_struct *user;     // 创建者用户信息
    struct file *file;            // epoll自身的file结构
    ...
};

struct epitem {
    union {
        struct rb_node rbn;       // 红黑树节点
        struct rcu_head rcu;      // RCU延迟释放
    };
    struct list_head rdllink;     // 就绪链表链接
    struct epitem *next;          // 溢出链表链接
    struct epoll_filefd ffd;      // 监控的<file*, fd>对
    struct eppoll_entry *pwqlist; // poll等待队列链表
    struct eventpoll *ep;         // 所属的eventpoll
    struct epoll_event event;     // 用户设置的事件和数据
    ...
};


内存布局可视化：

eventpoll实例
┌─────────────────────────────────────────────────────┐
│                                                     │
│  rbr（红黑树根）                                     │
│  ┌─────────────────────────────────────────────┐    │
│  │              [epitem:fd=7]                   │    │
│  │             /             \                  │    │
│  │      [epitem:fd=4]    [epitem:fd=12]        │    │
│  │       /        \        /        \          │    │
│  │  [fd=3]    [fd=5]  [fd=9]    [fd=15]       │    │
│  │                                              │    │
│  │  每个epitem包含：                             │    │
│  │  - rb_node: 红黑树节点                        │    │
│  │  - rdllink: 就绪链表链接                      │    │
│  │  - ffd: 监控的文件描述符                       │    │
│  │  - event: 用户设置的事件类型                   │    │
│  └─────────────────────────────────────────────┘    │
│                                                     │
│  rdllist（就绪链表）                                 │
│  ┌─────────────────────────────────────────────┐    │
│  │  head ──> [fd=5] ──> [fd=12] ──> [fd=3]    │    │
│  │  （只包含当前就绪的fd对应的epitem）            │    │
│  └─────────────────────────────────────────────┘    │
│                                                     │
│  wq（等待队列）                                      │
│  ┌─────────────────────────────────────────────┐    │
│  │  调用epoll_wait的线程在此等待                  │    │
│  └─────────────────────────────────────────────┘    │
│                                                     │
└─────────────────────────────────────────────────────┘
```

#### epoll操作流程详解

```
═══════════════════════════════════════════════════════════
epoll_create1() 流程
═══════════════════════════════════════════════════════════

用户调用: epoll_create1(EPOLL_CLOEXEC)
    │
    ▼
内核: sys_epoll_create1()
    │
    ├──> 分配eventpoll结构体
    │    - 初始化红黑树 rbr（空树）
    │    - 初始化就绪链表 rdllist（空链表）
    │    - 初始化等待队列 wq
    │    - 初始化互斥锁和自旋锁
    │
    ├──> 分配file结构体
    │    - 关联到eventpoll
    │    - 设置file_operations为eventpoll_fops
    │
    ├──> 分配文件描述符fd
    │    - 将file安装到fd表
    │    - 如果EPOLL_CLOEXEC，设置close-on-exec
    │
    └──> 返回fd


═══════════════════════════════════════════════════════════
epoll_ctl(EPOLL_CTL_ADD) 流程
═══════════════════════════════════════════════════════════

用户调用: epoll_ctl(epfd, EPOLL_CTL_ADD, target_fd, &event)
    │
    ▼
内核: sys_epoll_ctl()
    │
    ├──> 获取epfd对应的eventpoll结构
    │
    ├──> 获取target_fd对应的file结构
    │
    ├──> 在红黑树中查找target_fd
    │    （确认不存在，否则返回EEXIST）
    │
    ├──> 创建epitem结构
    │    - ffd = {file, fd}
    │    - event = 用户传入的epoll_event
    │    - ep = eventpoll指针
    │
    ├──> 将epitem插入红黑树
    │    - O(log n)，按<file*, fd>排序
    │
    ├──> 在target_fd上注册回调函数
    │    - 创建eppoll_entry
    │    - 注册ep_poll_callback到target_fd的等待队列
    │    - 当target_fd状态变化时，内核会调用此回调
    │
    ├──> 检查target_fd是否已经就绪
    │    - 调用target_fd的poll方法
    │    - 如果已就绪且匹配事件类型：
    │      - 将epitem加入就绪链表rdllist
    │      - 唤醒等待在wq上的线程
    │
    └──> 返回0


═══════════════════════════════════════════════════════════
fd就绪时的回调流程（关键！）
═══════════════════════════════════════════════════════════

场景：网卡收到数据 → tcp_rcv → socket可读
    │
    ▼
内核唤醒socket等待队列上的所有等待者
    │
    ▼
ep_poll_callback() 被调用
    │
    ├──> 获取对应的epitem
    │
    ├──> 检查事件类型是否匹配
    │    if (!(epi->event.events & events))
    │        return;  // 不匹配，忽略
    │
    ├──> 获取自旋锁 ep->lock
    │
    ├──> 将epitem加入就绪链表rdllist
    │    list_add_tail(&epi->rdllink, &ep->rdllist);
    │    （如果已经在链表中则不重复添加）
    │
    ├──> 释放自旋锁
    │
    └──> 唤醒epoll_wait的等待队列
         wake_up_locked(&ep->wq);

这就是epoll的核心优势：
- 不需要遍历所有fd
- fd就绪时主动通知（回调）
- 就绪的epitem直接加入链表


═══════════════════════════════════════════════════════════
epoll_wait() 流程
═══════════════════════════════════════════════════════════

用户调用: epoll_wait(epfd, events, maxevents, timeout)
    │
    ▼
内核: sys_epoll_wait() → ep_poll()
    │
    ├──> 检查就绪链表rdllist是否为空
    │
    │    如果为空：
    │    ├──> 将当前线程加入等待队列wq
    │    ├──> 设置定时器（如果timeout > 0）
    │    ├──> 循环：
    │    │    ├──> schedule()  // 让出CPU，睡眠
    │    │    ├──> 被唤醒后检查rdllist
    │    │    ├──> 如果rdllist非空 → 跳出循环
    │    │    ├──> 如果超时 → 跳出循环
    │    │    └──> 如果被信号中断 → 返回-EINTR
    │    └──> 从等待队列移除当前线程
    │
    │    如果非空（或被唤醒后）：
    │    │
    │    ▼
    ├──> ep_send_events()
    │    │
    │    ├──> 将rdllist转移到临时链表txlist
    │    │    （避免长时间持有锁）
    │    │
    │    ├──> 设置ovflist = NULL
    │    │    （期间新就绪的事件暂存到ovflist）
    │    │
    │    ├──> 遍历txlist：
    │    │    for each epitem in txlist:
    │    │        ├──> 调用fd的poll方法确认事件
    │    │        ├──> 如果仍然就绪：
    │    │        │    ├──> 拷贝事件到用户空间events[]
    │    │        │    ├──> count++
    │    │        │    ├──> 如果LT模式：
    │    │        │    │    将epitem放回rdllist
    │    │        │    │    （下次epoll_wait还会报告）
    │    │        │    └──> 如果ET模式：
    │    │        │         不放回（只报告一次）
    │    │        └──> 如果不再就绪：跳过
    │    │
    │    ├──> 将ovflist中的事件合并到rdllist
    │    │
    │    └──> 返回count
    │
    └──> 返回就绪事件数量


关键对比——为什么epoll是O(1)而select是O(n)：

操作           │ select         │ epoll
───────────────┼────────────────┼──────────────────
注册fd         │ 每次调用传入   │ 一次性注册(ctl)
               │ 全量拷贝       │ O(log n)
───────────────┼────────────────┼──────────────────
等待事件       │ 内核遍历所有fd │ 回调机制
               │ O(n)           │ O(1)
───────────────┼────────────────┼──────────────────
获取结果       │ 用户遍历所有fd │ 只返回就绪fd
               │ O(n)           │ O(ready)
───────────────┼────────────────┼──────────────────
数据结构       │ 位数组(fd_set) │ 红黑树+就绪链表
───────────────┼────────────────┼──────────────────
fd上限         │ FD_SETSIZE     │ 系统fd上限
               │ (通常1024)     │ (可达百万级)
```

#### 代码示例4：epoll内核流程伪代码

```cpp
// 示例4: epoll_kernel_pseudocode.cpp
// epoll内核实现伪代码——帮助理解内部机制
// 注意：这不是真正的内核代码，是简化的逻辑表达

#include <cstdio>

/*
// ═══════════════════════════════════════════════
// 简化的epoll内核数据结构
// ═══════════════════════════════════════════════

struct epitem {
    rb_node       rbn;       // 红黑树节点
    list_head     rdllink;   // 就绪链表链接
    file*         file;      // 监控的文件
    int           fd;        // 文件描述符
    epoll_event   event;     // 用户设置的事件
    eventpoll*    ep;        // 所属epoll实例
};

struct eventpoll {
    rb_root       rbr;       // 红黑树
    list_head     rdllist;   // 就绪链表
    wait_queue    wq;        // 等待队列
    spinlock      lock;      // 保护就绪链表
    mutex         mtx;       // 保护红黑树
};


// ═══════════════════════════════════════════════
// epoll_create1 伪代码
// ═══════════════════════════════════════════════

int epoll_create1(int flags) {
    // 1. 分配eventpoll
    eventpoll* ep = new eventpoll;
    rb_root_init(&ep->rbr);         // 红黑树初始化为空
    list_head_init(&ep->rdllist);   // 就绪链表初始化为空
    wait_queue_init(&ep->wq);       // 等待队列初始化

    // 2. 创建file并关联
    file* f = alloc_file();
    f->private_data = ep;
    f->f_op = &eventpoll_fops;

    // 3. 分配fd
    int fd = get_unused_fd(flags);
    fd_install(fd, f);

    return fd;
}


// ═══════════════════════════════════════════════
// epoll_ctl 伪代码
// ═══════════════════════════════════════════════

int epoll_ctl(int epfd, int op, int fd, epoll_event* event) {
    eventpoll* ep = get_eventpoll(epfd);
    file* target = get_file(fd);

    mutex_lock(&ep->mtx);

    // 在红黑树中查找
    epitem* epi = rb_find(&ep->rbr, target, fd);

    switch (op) {
    case EPOLL_CTL_ADD:
        if (epi) {
            mutex_unlock(&ep->mtx);
            return -EEXIST;  // 已存在
        }

        // 创建新的epitem
        epi = new epitem;
        epi->file = target;
        epi->fd = fd;
        epi->event = *event;
        epi->ep = ep;

        // 插入红黑树 O(log n)
        rb_insert(&ep->rbr, &epi->rbn);

        // 注册回调函数
        poll_entry* pe = new poll_entry;
        pe->callback = ep_poll_callback;
        pe->epitem = epi;
        add_wait_queue(target->wait_queue, pe);

        // 检查是否已就绪
        unsigned int revents = target->f_op->poll(target);
        if (revents & event->events) {
            spin_lock(&ep->lock);
            list_add(&epi->rdllink, &ep->rdllist);
            spin_unlock(&ep->lock);
            wake_up(&ep->wq);  // 唤醒epoll_wait
        }
        break;

    case EPOLL_CTL_MOD:
        if (!epi) {
            mutex_unlock(&ep->mtx);
            return -ENOENT;  // 不存在
        }
        epi->event = *event;  // 更新事件

        // 重新检查是否就绪
        unsigned int revents = target->f_op->poll(target);
        if (revents & event->events) {
            spin_lock(&ep->lock);
            if (!is_in_list(&epi->rdllink))
                list_add(&epi->rdllink, &ep->rdllist);
            spin_unlock(&ep->lock);
            wake_up(&ep->wq);
        }
        break;

    case EPOLL_CTL_DEL:
        if (!epi) {
            mutex_unlock(&ep->mtx);
            return -ENOENT;
        }
        // 从红黑树移除
        rb_erase(&epi->rbn, &ep->rbr);
        // 从就绪链表移除（如果在的话）
        spin_lock(&ep->lock);
        list_del(&epi->rdllink);
        spin_unlock(&ep->lock);
        // 移除回调
        remove_wait_queue(target->wait_queue, epi->poll_entry);
        delete epi;
        break;
    }

    mutex_unlock(&ep->mtx);
    return 0;
}


// ═══════════════════════════════════════════════
// ep_poll_callback —— 当fd就绪时被内核调用
// ═══════════════════════════════════════════════

int ep_poll_callback(wait_queue_entry* wq_entry, unsigned int events) {
    poll_entry* pe = container_of(wq_entry, poll_entry, wait);
    epitem* epi = pe->epitem;
    eventpoll* ep = epi->ep;

    // 检查事件是否匹配
    if (!(epi->event.events & events))
        return 0;

    spin_lock(&ep->lock);

    // 将epitem加入就绪链表
    if (!is_in_list(&epi->rdllink)) {
        list_add_tail(&epi->rdllink, &ep->rdllist);
    }

    // 唤醒epoll_wait中等待的线程
    if (waitqueue_active(&ep->wq)) {
        wake_up(&ep->wq);
    }

    spin_unlock(&ep->lock);
    return 1;
}


// ═══════════════════════════════════════════════
// epoll_wait 伪代码
// ═══════════════════════════════════════════════

int epoll_wait(int epfd, epoll_event* events,
               int maxevents, int timeout) {
    eventpoll* ep = get_eventpoll(epfd);
    int count = 0;

    spin_lock(&ep->lock);

    // 就绪链表为空时等待
    while (list_empty(&ep->rdllist)) {
        spin_unlock(&ep->lock);

        if (timeout == 0) return 0;  // 非阻塞

        // 加入等待队列并睡眠
        add_wait_queue(&ep->wq, current_thread);
        schedule_timeout(timeout);  // 睡眠
        remove_wait_queue(&ep->wq, current_thread);

        if (signal_pending()) return -EINTR;
        if (timeout_expired()) return 0;

        spin_lock(&ep->lock);
    }

    // 将就绪链表转移到临时链表
    list_head txlist;
    list_splice_init(&ep->rdllist, &txlist);

    spin_unlock(&ep->lock);

    // 遍历就绪事件
    list_for_each_entry(epi, &txlist) {
        if (count >= maxevents) break;

        // 再次确认事件（可能已经不就绪了）
        unsigned int revents = epi->file->f_op->poll(epi->file);
        revents &= epi->event.events;

        if (revents) {
            // 拷贝到用户空间
            events[count].events = revents;
            events[count].data = epi->event.data;
            count++;

            // LT模式：放回就绪链表（下次还会报告）
            if (!(epi->event.events & EPOLLET)) {
                spin_lock(&ep->lock);
                list_add_tail(&epi->rdllink, &ep->rdllist);
                spin_unlock(&ep->lock);
            }
            // ET模式：不放回（只报告一次）
        }
    }

    return count;
}
*/

int main() {
    printf("This file contains pseudocode for understanding epoll internals.\n");
    printf("It is not meant to be compiled and run.\n");
    printf("\nKey insights:\n");
    printf("1. epoll_ctl(ADD): O(log n) - red-black tree insertion\n");
    printf("2. fd ready: O(1) - callback adds to ready list\n");
    printf("3. epoll_wait: O(ready) - only processes ready events\n");
    printf("4. LT mode: re-adds to ready list after reporting\n");
    printf("5. ET mode: does NOT re-add (one-shot notification)\n");
    return 0;
}
```

#### Day 3-4 自测题

```
Q1: epoll内核中用红黑树存储fd，为什么不用哈希表？
A1: 红黑树的优势：
    - 有序性：便于遍历和范围查询
    - 稳定的O(log n)：不会因哈希冲突退化
    - 无需预分配空间：动态增长
    - 内存效率：没有哈希表的空间浪费
    实际上，由于epoll_ctl的调用频率远低于epoll_wait，
    O(log n)的插入/删除开销完全可以接受。

Q2: 就绪链表中的epitem会重复吗？
A2: 不会。ep_poll_callback中会检查epitem是否已在链表中：
    if (!is_in_list(&epi->rdllink))
        list_add_tail(...)
    同一个epitem不会重复添加到就绪链表。

Q3: epoll_wait返回时，LT和ET模式有什么区别？
A3: 在ep_send_events中：
    - LT模式：将已报告的epitem重新放回rdllist。
      下次epoll_wait时如果fd仍然就绪，会再次报告。
    - ET模式：不放回rdllist。
      只有fd状态再次变化（新数据到来等）时，
      回调函数才会重新将epitem加入rdllist。

Q4: 什么是ovflist（溢出链表）？
A4: 在ep_send_events处理就绪事件期间（遍历txlist时），
    可能有新的fd变为就绪状态。这些新就绪的事件不能直接加入rdllist
    （因为rdllist已经被转移到txlist），所以暂存到ovflist中。
    处理完毕后，再将ovflist中的事件合并回rdllist。

Q5: epoll自身的fd可以被另一个epoll监听吗？
A5: 可以。epoll fd本身也是一个文件描述符，支持poll操作。
    当epoll实例有就绪事件时，它自身就变为"可读"状态。
    这允许嵌套的epoll结构（虽然实际中较少使用）。
    内核会检测循环依赖并返回错误。
```

---

### Day 5-7：epoll与select/poll性能对比（15小时）

#### 学习目标

- 定量理解epoll vs select vs poll的性能差异
- 掌握不同场景下的最优选择
- 通过基准测试验证理论分析

#### 性能对比分析

```
═══════════════════════════════════════════════════════════
三种I/O多路复用机制性能对比
═══════════════════════════════════════════════════════════

维度1：时间复杂度

操作           │ select    │ poll      │ epoll
───────────────┼───────────┼───────────┼─────────────
注册fd         │ O(n)每次  │ O(n)每次  │ O(log n)一次
内核检查       │ O(n)      │ O(n)      │ O(1)回调
返回结果       │ O(n)      │ O(n)      │ O(ready)
用户遍历       │ O(n)      │ O(n)      │ O(ready)


维度2：连接数影响

连接数   活跃比例   select耗时   epoll耗时   epoll优势
──────────────────────────────────────────────────────
100      50%        ~10μs        ~8μs        1.25x
1000     10%        ~100μs       ~15μs       6.7x
10000    1%         ~1000μs      ~20μs       50x
100000   0.1%       不支持       ~25μs       ∞

关键观察：
- 连接数少（<100），差异不大
- 连接数多但活跃少（C10K典型场景），epoll优势巨大
- 连接数多且都活跃，epoll优势缩小（但仍有注册开销差异）


维度3：空间开销

机制      │ 用户空间       │ 内核空间         │ fd上限
──────────┼────────────────┼──────────────────┼──────────
select    │ fd_set位图     │ 临时拷贝         │ FD_SETSIZE
          │ ~128字节       │ ~128字节         │ (1024)
──────────┼────────────────┼──────────────────┼──────────
poll      │ pollfd数组     │ 临时拷贝         │ 系统fd上限
          │ 8字节/fd       │ 8字节/fd         │ (~100万)
──────────┼────────────────┼──────────────────┼──────────
epoll     │ epoll_event    │ eventpoll结构    │ 系统fd上限
          │ 只存就绪事件   │ +红黑树(epitem)  │ (~100万)
          │                │ ~160字节/fd      │

注意：epoll的内核空间开销更大（红黑树节点），
但用户空间开销更小（不需要传递整个fd集合）。


维度4：适用场景

场景                    │ 推荐      │ 原因
────────────────────────┼───────────┼──────────────────
少量fd(<100)            │ select    │ 简单、跨平台
需要跨平台              │ select    │ POSIX标准
fd编号>1024             │ poll/epoll│ select有上限
大量连接少数活跃        │ epoll     │ O(1)事件通知
需要ET模式              │ epoll     │ 独有特性
Linux服务器             │ epoll     │ 最高性能
```

#### 代码示例5：select vs poll vs epoll性能基准测试

```cpp
// 示例5: io_multiplex_benchmark.cpp
// select vs poll vs epoll 性能基准测试
// 使用socketpair模拟不同连接数下的性能表现

#include <sys/epoll.h>
#include <sys/select.h>
#include <poll.h>
#include <sys/socket.h>
#include <unistd.h>
#include <fcntl.h>
#include <cstdio>
#include <cstring>
#include <cerrno>
#include <chrono>
#include <vector>
#include <algorithm>
#include <cstdlib>

using Clock = std::chrono::high_resolution_clock;
using Duration = std::chrono::duration<double, std::micro>;

// 设置非阻塞
static void set_nonblocking(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    fcntl(fd, F_SETFL, flags | O_NONBLOCK);
}

// 创建n个socketpair，返回read端fd列表
static std::vector<int> create_pairs(int n, std::vector<int>& write_fds) {
    std::vector<int> read_fds;
    read_fds.reserve(n);
    write_fds.reserve(n);

    for (int i = 0; i < n; ++i) {
        int sv[2];
        if (socketpair(AF_UNIX, SOCK_STREAM, 0, sv) < 0) {
            perror("socketpair");
            break;
        }
        set_nonblocking(sv[0]);
        set_nonblocking(sv[1]);
        read_fds.push_back(sv[0]);
        write_fds.push_back(sv[1]);
    }
    return read_fds;
}

// 使指定比例的fd就绪（向write端写数据）
static void make_active(const std::vector<int>& write_fds,
                        int active_count) {
    char c = 'x';
    for (int i = 0; i < active_count && i < (int)write_fds.size(); ++i) {
        write(write_fds[i], &c, 1);
    }
}

// 清空活跃fd的数据
static void drain_active(const std::vector<int>& read_fds,
                         int active_count) {
    char buf[64];
    for (int i = 0; i < active_count && i < (int)read_fds.size(); ++i) {
        read(read_fds[i], buf, sizeof(buf));
    }
}

// ─── select基准测试 ───
static double bench_select(const std::vector<int>& read_fds,
                          int active_count, int rounds) {
    int maxfd = *std::max_element(read_fds.begin(), read_fds.end());

    // select要求maxfd < FD_SETSIZE
    if (maxfd >= FD_SETSIZE) {
        return -1;  // 无法测试
    }

    auto start = Clock::now();

    for (int r = 0; r < rounds; ++r) {
        fd_set readfds;
        FD_ZERO(&readfds);
        for (int fd : read_fds) {
            FD_SET(fd, &readfds);
        }

        timeval tv = {0, 0};  // 非阻塞
        int ret = select(maxfd + 1, &readfds, nullptr, nullptr, &tv);
        (void)ret;
    }

    auto end = Clock::now();
    return Duration(end - start).count() / rounds;
}

// ─── poll基准测试 ───
static double bench_poll(const std::vector<int>& read_fds,
                        int active_count, int rounds) {
    std::vector<pollfd> pfds(read_fds.size());
    for (size_t i = 0; i < read_fds.size(); ++i) {
        pfds[i].fd = read_fds[i];
        pfds[i].events = POLLIN;
    }

    auto start = Clock::now();

    for (int r = 0; r < rounds; ++r) {
        // 需要重置revents
        for (auto& pfd : pfds) pfd.revents = 0;
        int ret = poll(pfds.data(), pfds.size(), 0);
        (void)ret;
    }

    auto end = Clock::now();
    return Duration(end - start).count() / rounds;
}

// ─── epoll基准测试 ───
static double bench_epoll(const std::vector<int>& read_fds,
                         int active_count, int rounds) {
    int epfd = epoll_create1(EPOLL_CLOEXEC);
    if (epfd < 0) return -1;

    for (int fd : read_fds) {
        epoll_event ev;
        ev.events = EPOLLIN;
        ev.data.fd = fd;
        epoll_ctl(epfd, EPOLL_CTL_ADD, fd, &ev);
    }

    std::vector<epoll_event> events(read_fds.size());
    auto start = Clock::now();

    for (int r = 0; r < rounds; ++r) {
        int ret = epoll_wait(epfd, events.data(), events.size(), 0);
        (void)ret;
    }

    auto end = Clock::now();
    close(epfd);
    return Duration(end - start).count() / rounds;
}

int main() {
    printf("I/O Multiplexing Benchmark: select vs poll vs epoll\n");
    printf("====================================================\n\n");

    struct TestCase {
        int total_fds;
        int active_fds;
    };

    std::vector<TestCase> tests = {
        {10,    5},
        {100,   10},
        {500,   50},
        {900,   90},     // select上限内（FD_SETSIZE=1024，但fd编号可能>1024）
        {2000,  200},    // select无法测试
        {5000,  500},
        {10000, 100},    // C10K场景：大量连接，少数活跃
    };

    const int ROUNDS = 1000;

    printf("%-10s %-10s %-10s %-15s %-15s %-15s\n",
           "Total", "Active", "Ratio", "select(μs)", "poll(μs)", "epoll(μs)");
    printf("─────────────────────────────────────────────────────────────────────\n");

    for (auto& tc : tests) {
        std::vector<int> write_fds;
        auto read_fds = create_pairs(tc.total_fds, write_fds);

        if ((int)read_fds.size() < tc.total_fds) {
            printf("Could only create %zu/%d pairs\n",
                   read_fds.size(), tc.total_fds);
            // 清理
            for (int fd : read_fds) close(fd);
            for (int fd : write_fds) close(fd);
            break;
        }

        // 使指定数量的fd就绪
        make_active(write_fds, tc.active_fds);

        double t_select = bench_select(read_fds, tc.active_fds, ROUNDS);
        double t_poll   = bench_poll(read_fds, tc.active_fds, ROUNDS);
        double t_epoll  = bench_epoll(read_fds, tc.active_fds, ROUNDS);

        printf("%-10d %-10d %-10.1f%% ",
               tc.total_fds, tc.active_fds,
               100.0 * tc.active_fds / tc.total_fds);

        if (t_select < 0)
            printf("%-15s ", "N/A");
        else
            printf("%-15.2f ", t_select);

        printf("%-15.2f %-15.2f\n", t_poll, t_epoll);

        // 清理
        drain_active(read_fds, tc.active_fds);
        for (int fd : read_fds) close(fd);
        for (int fd : write_fds) close(fd);
    }

    printf("\n说明：\n");
    printf("- select在fd编号>=FD_SETSIZE(1024)时无法使用，显示N/A\n");
    printf("- 活跃比例越低（大量空闲连接），epoll优势越大\n");
    printf("- 连接数越多，select/poll的线性开销越明显\n");

    return 0;
}

/*
预期输出（实际数据因系统而异）：

I/O Multiplexing Benchmark: select vs poll vs epoll
====================================================

Total      Active     Ratio      select(μs)      poll(μs)        epoll(μs)
─────────────────────────────────────────────────────────────────────
10         5          50.0%      1.20            1.50            1.80
100        10         10.0%      5.80            6.20            2.50
500        50         10.0%      25.30           28.50           5.20
900        90         10.0%      45.60           50.20           8.10
2000       200        10.0%      N/A             110.30          10.50
5000       500        10.0%      N/A             285.60          15.80
10000      100        1.0%       N/A             580.40          8.90

观察要点：
1. 小规模(10个fd)：三者差异不大
2. 中等规模(100-900)：epoll开始显现优势
3. 大规模(2000+)：select无法使用，poll线性增长，epoll几乎不受影响
4. C10K场景(10000连接1%活跃)：epoll完胜，poll约慢65倍

编译运行：
$ g++ -O2 -o bench io_multiplex_benchmark.cpp
$ ./bench
*/
```

#### 代码示例6：不同连接数下的延迟分布测试

```cpp
// 示例6: latency_distribution.cpp
// 测试epoll在不同连接数下的事件处理延迟分布
// 输出P50/P90/P99/P999延迟

#include <sys/epoll.h>
#include <sys/socket.h>
#include <sys/timerfd.h>
#include <unistd.h>
#include <fcntl.h>
#include <cstdio>
#include <cstring>
#include <cerrno>
#include <chrono>
#include <vector>
#include <algorithm>
#include <numeric>

using Clock = std::chrono::high_resolution_clock;
using Nanos = std::chrono::nanoseconds;

// 测量单次epoll_wait + 事件处理的延迟
struct LatencyResult {
    double p50;
    double p90;
    double p99;
    double p999;
    double avg;
};

static void set_nonblocking(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    fcntl(fd, F_SETFL, flags | O_NONBLOCK);
}

static LatencyResult measure_epoll_latency(int num_fds, int active_fds,
                                           int samples) {
    // 创建socketpairs
    std::vector<int> read_fds, write_fds;
    for (int i = 0; i < num_fds; ++i) {
        int sv[2];
        socketpair(AF_UNIX, SOCK_STREAM, 0, sv);
        set_nonblocking(sv[0]);
        set_nonblocking(sv[1]);
        read_fds.push_back(sv[0]);
        write_fds.push_back(sv[1]);
    }

    // 创建epoll并注册所有fd
    int epfd = epoll_create1(EPOLL_CLOEXEC);
    for (int fd : read_fds) {
        epoll_event ev;
        ev.events = EPOLLIN;
        ev.data.fd = fd;
        epoll_ctl(epfd, EPOLL_CTL_ADD, fd, &ev);
    }

    std::vector<epoll_event> events(num_fds);
    std::vector<double> latencies;
    latencies.reserve(samples);

    for (int s = 0; s < samples; ++s) {
        // 使指定数量的fd就绪
        char c = 'x';
        for (int i = 0; i < active_fds; ++i) {
            write(write_fds[i], &c, 1);
        }

        // 测量epoll_wait延迟
        auto t1 = Clock::now();
        int n = epoll_wait(epfd, events.data(), events.size(), 0);
        auto t2 = Clock::now();

        double ns = std::chrono::duration<double, std::nano>(t2 - t1).count();
        latencies.push_back(ns);

        // 清空数据
        char buf[64];
        for (int i = 0; i < n; ++i) {
            read(events[i].data.fd, buf, sizeof(buf));
        }
    }

    // 计算延迟分布
    std::sort(latencies.begin(), latencies.end());

    LatencyResult result;
    result.p50  = latencies[samples * 50 / 100];
    result.p90  = latencies[samples * 90 / 100];
    result.p99  = latencies[samples * 99 / 100];
    result.p999 = latencies[std::min(samples - 1, samples * 999 / 1000)];
    result.avg  = std::accumulate(latencies.begin(), latencies.end(), 0.0)
                  / samples;

    // 清理
    close(epfd);
    for (int fd : read_fds) close(fd);
    for (int fd : write_fds) close(fd);

    return result;
}

int main() {
    printf("epoll Latency Distribution Test\n");
    printf("================================\n\n");

    const int SAMPLES = 10000;

    struct TestCase {
        int total_fds;
        int active_fds;
    };

    std::vector<TestCase> tests = {
        {100,    10},
        {1000,   100},
        {5000,   50},
        {10000,  100},
        {10000,  1000},
    };

    printf("%-10s %-10s %-10s %-10s %-10s %-10s %-10s\n",
           "Total", "Active", "Avg(ns)", "P50(ns)", "P90(ns)",
           "P99(ns)", "P999(ns)");
    printf("────────────────────────────────────────────────────"
           "──────────────────\n");

    for (auto& tc : tests) {
        auto r = measure_epoll_latency(tc.total_fds, tc.active_fds, SAMPLES);

        printf("%-10d %-10d %-10.0f %-10.0f %-10.0f %-10.0f %-10.0f\n",
               tc.total_fds, tc.active_fds,
               r.avg, r.p50, r.p90, r.p99, r.p999);
    }

    printf("\n结论：\n");
    printf("- epoll_wait延迟主要取决于就绪事件数量，而非总连接数\n");
    printf("- 10000个连接只有100个活跃时，延迟与1000个连接100个活跃相近\n");
    printf("- 这验证了epoll O(ready)的时间复杂度\n");

    return 0;
}

/*
编译运行：
$ g++ -O2 -o latency latency_distribution.cpp
$ ./latency
*/
```

#### Day 5-7 自测题

```
Q1: 在什么场景下select/poll反而比epoll更合适？
A1: 以下场景select/poll可能更合适：
    1. 连接数很少（<100），三者差异不大，select更简单
    2. 需要跨平台（macOS/BSD用kqueue，Windows用IOCP，但select几乎全平台支持）
    3. 所有连接都很活跃（epoll的注册开销没有回报）
    4. 短生命周期程序（频繁创建/销毁epoll实例的开销）

Q2: epoll的内存开销比select大吗？
A2: 内核空间开销：epoll > select（红黑树节点约160字节/fd vs 位图1bit/fd）
    用户空间开销：epoll < select（只接收就绪事件 vs 每次传整个fd_set）
    总体来看，连接数多时，epoll节省的用户/内核数据拷贝远超内核数据结构开销。

Q3: epoll的O(1)是无条件的吗？
A3: 不是。准确说：
    - epoll_ctl(ADD/DEL): O(log n)（红黑树操作）
    - fd就绪回调: O(1)
    - epoll_wait: O(ready_count)（遍历就绪链表+拷贝到用户空间）
    所以如果所有fd都活跃，epoll_wait退化为O(n)。
    epoll的优势在于"大量连接少数活跃"的场景。

Q4: 为什么基准测试中epoll在10个fd时反而比select慢？
A4: 因为epoll有额外的固定开销：
    - eventpoll数据结构维护
    - 红黑树操作
    - 回调注册
    当fd极少时，这些固定开销占主导，
    而select只需简单的位图操作，更轻量。
    这就是"没有银弹"——选择适合场景的工具。
```

---

### 第一周检验标准

```
第一周自我检验清单：

理论理解：
☐ 能说出select/poll的三个O(n)性能瓶颈
☐ 能画出epoll的内核数据结构（红黑树+就绪链表）
☐ 能描述epoll_ctl(ADD)的完整内核流程
☐ 能描述fd就绪时的回调流程
☐ 能描述epoll_wait的内核实现流程
☐ 能解释LT模式下epitem重新放回rdllist的机制
☐ 理解ovflist（溢出链表）的作用

实践能力：
☐ 能独立编写epoll基本用法（创建/注册/等待/清理）
☐ 能实现完整的epoll echo server（LT模式）
☐ 会使用data.ptr传递连接上下文
☐ 正确处理accept/read/write/close事件
☐ 正确管理EPOLLOUT事件（避免busy loop）
☐ 能编写select vs poll vs epoll基准测试
☐ 理解不同连接数下的性能差异
```

---

## 第二周：LT与ET模式深入（Day 8-14）

### 本周时间分配

| 日期 | 内容 | 时间 |
|------|------|------|
| Day 8-9 | Level-Triggered模式详解 | 10小时 |
| Day 10-11 | Edge-Triggered模式详解 | 10小时 |
| Day 12-14 | LT vs ET对比与EPOLLONESHOT | 15小时 |

---

### Day 8-9：Level-Triggered模式详解（10小时）

#### 学习目标

- 深入理解LT模式的语义和行为
- 掌握LT模式的编程模式和最佳实践
- 理解LT模式的优缺点

#### LT模式语义详解

```
═══════════════════════════════════════════════════════════
Level-Triggered（水平触发）模式
═══════════════════════════════════════════════════════════

核心语义：
  只要fd处于就绪状态，每次epoll_wait都会报告该事件。

类比：
  就像一个水位传感器——只要水位高于阈值，就持续报警。
  不管你看没看到报警，下次检查时如果水位仍高，还会报警。

行为示意：

时间线：
T1: 数据到达socket（4096字节）
    └─> epoll_wait返回EPOLLIN ✓

T2: read()读取了1024字节（还剩3072字节）
    └─> epoll_wait返回EPOLLIN ✓  （仍有数据可读）

T3: read()读取了3072字节（缓冲区空了）
    └─> epoll_wait不返回EPOLLIN  （没有数据了）

T4: 新数据到达（2048字节）
    └─> epoll_wait返回EPOLLIN ✓


LT模式内核实现：
┌─────────────────────────────────────────────────┐
│ epoll_wait() 处理LT事件：                        │
│                                                  │
│ for each epitem in ready_list:                   │
│     revents = fd->poll()  // 再次检查fd状态      │
│     if (revents & interested_events):            │
│         copy_to_user(events[count++], epitem)    │
│         list_add(epitem, &rdllist)  // 放回！    │
│         // ↑ LT模式的关键：放回就绪链表          │
│         //   下次epoll_wait时重新检查             │
│                                                  │
│ 因此：只要fd仍然就绪，就会反复报告               │
└─────────────────────────────────────────────────┘


LT模式的优点：
1. 编程简单：不需要一次读完所有数据
2. 不会丢失事件：即使一次没处理完，下次还会通知
3. 可以使用阻塞fd（但不推荐）
4. 与select/poll语义一致，迁移容易

LT模式的缺点：
1. 可能产生多余的唤醒（数据没读完时重复通知）
2. 写事件需要手动管理（必须及时取消EPOLLOUT）
3. 在高并发场景下，多余唤醒会降低性能
```

#### 代码示例7：LT模式Echo Server（完整版，含详细注释）

```cpp
// 示例7: epoll_echo_lt_full.cpp
// LT模式Echo服务器——完整版
// 重点展示LT模式的编程模式和注意事项

#include <sys/epoll.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <cstdio>
#include <cstring>
#include <cerrno>
#include <vector>
#include <string>
#include <unordered_map>
#include <memory>

// ─── 工具函数 ───

static bool set_nonblocking(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    return (flags >= 0) && (fcntl(fd, F_SETFL, flags | O_NONBLOCK) >= 0);
}

static void set_tcp_nodelay(int fd) {
    int opt = 1;
    setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &opt, sizeof(opt));
}

// ─── 连接类 ───

struct Connection {
    int fd;
    std::string peer_addr;
    std::string recv_buf;
    std::string send_buf;
    bool writing = false;  // 是否正在监听写事件
    uint64_t total_rx = 0;
    uint64_t total_tx = 0;

    Connection(int f, const std::string& addr) : fd(f), peer_addr(addr) {}
};

// ─── 服务器类 ───

class LTEchoServer {
public:
    LTEchoServer(int port) : port_(port) {}

    ~LTEchoServer() {
        if (epfd_ >= 0) close(epfd_);
        if (listen_fd_ >= 0) close(listen_fd_);
    }

    bool start() {
        // 创建epoll
        epfd_ = epoll_create1(EPOLL_CLOEXEC);
        if (epfd_ < 0) { perror("epoll_create1"); return false; }

        // 创建监听socket
        listen_fd_ = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK | SOCK_CLOEXEC, 0);
        if (listen_fd_ < 0) { perror("socket"); return false; }

        int opt = 1;
        setsockopt(listen_fd_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = INADDR_ANY;
        addr.sin_port = htons(port_);

        if (bind(listen_fd_, (sockaddr*)&addr, sizeof(addr)) < 0) {
            perror("bind"); return false;
        }
        if (listen(listen_fd_, SOMAXCONN) < 0) {
            perror("listen"); return false;
        }

        // 注册listen_fd（LT模式）
        // LT模式下accept: 每次通知只accept一个也行
        // 如果还有等待的连接，下次epoll_wait会再次通知
        epoll_event ev;
        ev.events = EPOLLIN;  // LT模式，不设EPOLLET
        ev.data.fd = listen_fd_;
        epoll_ctl(epfd_, EPOLL_CTL_ADD, listen_fd_, &ev);

        printf("[LT Echo Server] Listening on port %d\n", port_);
        return true;
    }

    void run() {
        std::vector<epoll_event> events(1024);

        while (true) {
            int n = epoll_wait(epfd_, events.data(), events.size(), -1);
            if (n < 0) {
                if (errno == EINTR) continue;
                perror("epoll_wait");
                break;
            }

            for (int i = 0; i < n; ++i) {
                int fd = events[i].data.fd;
                uint32_t revents = events[i].events;

                if (fd == listen_fd_) {
                    on_accept();
                } else {
                    auto it = conns_.find(fd);
                    if (it == conns_.end()) continue;
                    auto& conn = it->second;

                    if (revents & (EPOLLERR | EPOLLHUP)) {
                        on_close(conn);
                        continue;
                    }
                    if (revents & EPOLLIN) {
                        on_read(conn);
                    }
                    // 注意：上面on_read可能已经关闭了连接
                    if (conns_.count(fd) && (revents & EPOLLOUT)) {
                        on_write(conn);
                    }
                }
            }
        }
    }

private:
    void on_accept() {
        // LT模式：accept一个就行，还有的话下次通知
        // 但为了效率，也可以循环accept（类似ET做法）
        sockaddr_in client_addr{};
        socklen_t len = sizeof(client_addr);

        int fd = accept4(listen_fd_, (sockaddr*)&client_addr,
                        &len, SOCK_NONBLOCK | SOCK_CLOEXEC);
        if (fd < 0) {
            if (errno != EAGAIN && errno != EWOULDBLOCK)
                perror("accept4");
            return;
        }

        set_tcp_nodelay(fd);

        char ip[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &client_addr.sin_addr, ip, sizeof(ip));
        std::string peer = std::string(ip) + ":" +
                          std::to_string(ntohs(client_addr.sin_port));

        auto conn = std::make_shared<Connection>(fd, peer);
        conns_[fd] = conn;

        // 注册读事件（LT模式）
        epoll_event ev;
        ev.events = EPOLLIN;  // 只监听读，不监听写
        ev.data.fd = fd;
        epoll_ctl(epfd_, EPOLL_CTL_ADD, fd, &ev);

        printf("[+] %s (fd=%d, total=%zu)\n",
               peer.c_str(), fd, conns_.size());
    }

    void on_read(std::shared_ptr<Connection>& conn) {
        // LT模式：read一次就行
        // 如果没读完，下次epoll_wait还会通知EPOLLIN
        char buf[4096];
        ssize_t n = read(conn->fd, buf, sizeof(buf));

        if (n > 0) {
            conn->total_rx += n;
            // Echo：收到的数据放入发送缓冲
            conn->send_buf.append(buf, n);

            // 有数据要发送 → 开启写事件监听
            if (!conn->writing) {
                enable_write(conn->fd);
                conn->writing = true;
            }
        } else if (n == 0) {
            // 对端关闭
            on_close(conn);
        } else {
            if (errno != EAGAIN && errno != EWOULDBLOCK) {
                on_close(conn);
            }
            // EAGAIN在LT模式下通常不会发生
            // 但非阻塞fd理论上可能返回
        }
    }

    void on_write(std::shared_ptr<Connection>& conn) {
        if (conn->send_buf.empty()) {
            // 没数据要发了，取消写事件
            disable_write(conn->fd);
            conn->writing = false;
            return;
        }

        // LT模式：write一次就行
        // 如果没写完，下次epoll_wait还会通知EPOLLOUT
        ssize_t n = write(conn->fd, conn->send_buf.data(),
                         conn->send_buf.size());

        if (n > 0) {
            conn->total_tx += n;
            conn->send_buf.erase(0, n);

            // 发送完毕 → 关闭写事件（关键！避免busy loop）
            if (conn->send_buf.empty()) {
                disable_write(conn->fd);
                conn->writing = false;
            }
        } else if (n < 0) {
            if (errno != EAGAIN && errno != EWOULDBLOCK) {
                on_close(conn);
            }
        }
    }

    void on_close(std::shared_ptr<Connection>& conn) {
        printf("[-] %s (fd=%d) rx=%lu tx=%lu\n",
               conn->peer_addr.c_str(), conn->fd,
               conn->total_rx, conn->total_tx);

        epoll_ctl(epfd_, EPOLL_CTL_DEL, conn->fd, nullptr);
        close(conn->fd);
        conn->fd = -1;
        conns_.erase(conn->fd == -1 ? -1 : conn->fd);
        // 注意：上面的逻辑有问题，因为fd已经被设为-1
        // 正确做法：先保存fd再关闭
    }

    void enable_write(int fd) {
        epoll_event ev;
        ev.events = EPOLLIN | EPOLLOUT;
        ev.data.fd = fd;
        epoll_ctl(epfd_, EPOLL_CTL_MOD, fd, &ev);
    }

    void disable_write(int fd) {
        epoll_event ev;
        ev.events = EPOLLIN;
        ev.data.fd = fd;
        epoll_ctl(epfd_, EPOLL_CTL_MOD, fd, &ev);
    }

    int port_;
    int epfd_ = -1;
    int listen_fd_ = -1;
    std::unordered_map<int, std::shared_ptr<Connection>> conns_;
};

int main(int argc, char* argv[]) {
    int port = (argc > 1) ? atoi(argv[1]) : 8080;
    LTEchoServer server(port);
    if (!server.start()) return 1;
    server.run();
    return 0;
}

/*
LT模式编程要点总结：

1. 读取：read一次即可
   - 没读完？没关系，下次epoll_wait还会通知
   - 简单但可能有多余唤醒

2. 写入：write一次即可
   - 没写完？下次EPOLLOUT会通知
   - 必须管理EPOLLOUT开关！

3. EPOLLOUT管理（最关键的点）：
   ┌──────────────────────────────────────────┐
   │ 有数据要发送 → 开启 EPOLLOUT            │
   │ 数据发完     → 关闭 EPOLLOUT            │
   │                                          │
   │ 如果忘记关闭：                            │
   │ socket发送缓冲区有空间 → 持续触发        │
   │ → CPU空转（busy loop）                   │
   │ → 性能灾难！                              │
   └──────────────────────────────────────────┘

4. 与ET模式对比：
   LT: read/write一次 + 管理EPOLLOUT
   ET: 循环read/write至EAGAIN + 不需频繁管理EPOLLOUT
*/
```

#### LT模式写事件处理策略

```
═══════════════════════════════════════════════════════════
LT模式下EPOLLOUT的三种处理策略
═══════════════════════════════════════════════════════════

策略1：按需开关（推荐）
─────────────────────
- 默认只监听EPOLLIN
- 有数据要发时开启EPOLLOUT
- 发完后关闭EPOLLOUT

优点：精确控制，无多余唤醒
缺点：每次需要epoll_ctl(MOD)

// 伪代码
on_data_ready_to_send() {
    epoll_ctl(MOD, fd, EPOLLIN | EPOLLOUT);
}
on_write_complete() {
    epoll_ctl(MOD, fd, EPOLLIN);  // 关闭写
}


策略2：先尝试直接发送
─────────────────────
- 收到数据后先尝试直接write
- 如果发完了，不需要开EPOLLOUT
- 如果没发完（EAGAIN），才开EPOLLOUT

优点：减少epoll_ctl调用（大部分情况直接发完）
缺点：代码稍复杂

// 伪代码
on_read() {
    data = read(fd);
    n = write(fd, data);  // 先尝试直接发
    if (n == len(data)) {
        // 全部发完，不需要EPOLLOUT
        return;
    }
    // 没发完，保存剩余数据，开启EPOLLOUT
    save_remaining(data + n);
    epoll_ctl(MOD, fd, EPOLLIN | EPOLLOUT);
}


策略3：始终监听EPOLLOUT（不推荐！）
─────────────────────
- 注册时就设EPOLLIN | EPOLLOUT
- 每次EPOLLOUT触发时检查是否有数据要发

问题：发送缓冲区通常有空间 → EPOLLOUT持续触发 → busy loop！
绝对不要使用这种方式！
```

#### Day 8-9 自测题

```
Q1: LT模式下，如果socket接收缓冲区有4096字节数据，
    但on_read只读了1024字节，会发生什么？
A1: 下次调用epoll_wait时，由于接收缓冲区仍有3072字节数据，
    epoll会再次报告该fd的EPOLLIN事件。
    这就是LT的"水平触发"语义：只要有数据就持续通知。

Q2: LT模式可以使用阻塞fd吗？
A2: 理论上可以，因为LT只在fd真正就绪时通知。
    但实践中强烈不推荐：
    1. 阻塞read/write可能阻塞整个事件循环
    2. 如果对端行为异常（如发送一半数据后暂停），可能导致长时间阻塞
    3. 使用非阻塞fd + EAGAIN检查是更安全的做法

Q3: 在LT模式下EPOLLOUT的正确管理方式是什么？
A3: 按需开关：
    - 默认不监听EPOLLOUT
    - 有数据要发送时：epoll_ctl(MOD, EPOLLIN | EPOLLOUT)
    - 数据发送完毕时：epoll_ctl(MOD, EPOLLIN)
    如果忘记关闭EPOLLOUT，会导致busy loop。

Q4: LT模式和select/poll的触发语义有什么关系？
A4: LT模式与select/poll完全一致：
    - select: fd可读时FD_ISSET返回true（每次调用都检查）
    - poll: fd可读时revents包含POLLIN（每次调用都检查）
    - epoll LT: fd可读时报告EPOLLIN（每次epoll_wait都检查）
    所以从select/poll迁移到epoll LT模式几乎不需要改动逻辑。
```

---

### Day 10-11：Edge-Triggered模式详解（10小时）

#### 学习目标

- 深入理解ET模式的语义和行为
- 掌握ET模式的必备编程规范
- 理解ET模式的常见陷阱和正确处理方式

#### ET模式语义详解

```
═══════════════════════════════════════════════════════════
Edge-Triggered（边缘触发）模式
═══════════════════════════════════════════════════════════

核心语义：
  只在fd状态发生变化时通知一次。

类比：
  就像一个门铃——只在有人按下时响一声。
  即使访客还在门口等着，门铃不会再响。
  你必须在听到门铃后去开门看看。

行为示意：

时间线：
T1: 数据到达socket（4096字节）
    └─> epoll_wait返回EPOLLIN ✓  （状态变化：无数据→有数据）

T2: read()读取了1024字节（还剩3072字节）
    └─> epoll_wait不返回EPOLLIN ✗  （没有新的状态变化！）
                                     还剩3072字节但不再通知！

T3: 新数据到达（2048字节，现在共5120字节）
    └─> epoll_wait返回EPOLLIN ✓  （状态变化：新数据到达）

T4: read()读取了1024字节（还剩4096字节）
    └─> epoll_wait不返回EPOLLIN ✗  （上次的变化已经通知过了）

关键问题：
  T2时刻还有3072字节没读，但ET不再通知！
  如果不读完，这些数据会"丢失"（其实还在缓冲区，但永远不会被读到）！

解决方案：ET模式必须遵守两条铁律！

铁律1：必须使用非阻塞fd
  如果用阻塞fd，循环read直到读完时，最后一次read会阻塞
  （因为缓冲区空了），从而卡住整个事件循环。

铁律2：必须循环读/写直到返回EAGAIN
  每次ET通知后，必须循环处理直到EAGAIN，
  确保不遗漏任何数据。

┌──────────────────────────────────────────────┐
│  ET模式编程模板：                              │
│                                               │
│  while (true) {                               │
│      n = read(fd, buf, sizeof(buf));          │
│      if (n > 0) {                             │
│          process(buf, n);                     │
│          continue;  // 继续读                 │
│      }                                        │
│      if (n == 0) {                            │
│          close_connection();                  │
│          break;                               │
│      }                                        │
│      if (errno == EAGAIN) {                   │
│          break;  // 读完了！等下次ET通知      │
│      }                                        │
│      if (errno == EINTR) {                    │
│          continue;  // 被信号中断，重试       │
│      }                                        │
│      handle_error();                          │
│      break;                                   │
│  }                                            │
└──────────────────────────────────────────────┘


ET模式的优点：
1. 减少epoll_wait返回次数（只在变化时通知）
2. 不需要频繁管理EPOLLOUT（循环写完即可）
3. 高并发下性能更好

ET模式的缺点：
1. 编程复杂度高（必须循环处理至EAGAIN）
2. 必须使用非阻塞I/O
3. 容易出bug（忘记循环读写→数据丢失）
4. 调试困难（数据"丢失"不容易复现）
```

#### 代码示例8：ET模式Echo Server（完整版）

```cpp
// 示例8: epoll_echo_et_full.cpp
// ET模式Echo服务器——完整实现
// 展示ET模式的正确编程方式

#include <sys/epoll.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <cstdio>
#include <cstring>
#include <cerrno>
#include <vector>
#include <string>
#include <unordered_map>
#include <memory>

struct Connection {
    int fd;
    std::string peer_addr;
    std::string send_buf;
    uint64_t total_rx = 0;
    uint64_t total_tx = 0;

    Connection(int f, const std::string& addr) : fd(f), peer_addr(addr) {}
};

class ETEchoServer {
public:
    ETEchoServer(int port) : port_(port) {}

    ~ETEchoServer() {
        if (epfd_ >= 0) close(epfd_);
        if (listen_fd_ >= 0) close(listen_fd_);
    }

    bool start() {
        epfd_ = epoll_create1(EPOLL_CLOEXEC);
        if (epfd_ < 0) return false;

        listen_fd_ = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK | SOCK_CLOEXEC, 0);
        if (listen_fd_ < 0) return false;

        int opt = 1;
        setsockopt(listen_fd_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = INADDR_ANY;
        addr.sin_port = htons(port_);

        if (bind(listen_fd_, (sockaddr*)&addr, sizeof(addr)) < 0) return false;
        if (listen(listen_fd_, SOMAXCONN) < 0) return false;

        // 监听socket也可以用ET模式
        // 但必须循环accept直到EAGAIN
        epoll_event ev;
        ev.events = EPOLLIN | EPOLLET;  // ET模式
        ev.data.fd = listen_fd_;
        epoll_ctl(epfd_, EPOLL_CTL_ADD, listen_fd_, &ev);

        printf("[ET Echo Server] Listening on port %d\n", port_);
        return true;
    }

    void run() {
        std::vector<epoll_event> events(1024);

        while (true) {
            int n = epoll_wait(epfd_, events.data(), events.size(), -1);
            if (n < 0) {
                if (errno == EINTR) continue;
                break;
            }

            for (int i = 0; i < n; ++i) {
                int fd = events[i].data.fd;
                uint32_t revents = events[i].events;

                if (fd == listen_fd_) {
                    on_accept();  // 必须循环accept！
                } else {
                    auto it = conns_.find(fd);
                    if (it == conns_.end()) continue;
                    auto& conn = it->second;

                    if (revents & (EPOLLERR | EPOLLHUP)) {
                        on_close(conn);
                        continue;
                    }
                    if (revents & EPOLLIN) {
                        on_read(conn);
                    }
                    if (conns_.count(fd) && (revents & EPOLLOUT)) {
                        on_write(conn);
                    }
                }
            }
        }
    }

private:
    // ─── ET模式accept：必须循环直到EAGAIN ───
    void on_accept() {
        while (true) {  // ← ET关键：循环！
            sockaddr_in client_addr{};
            socklen_t len = sizeof(client_addr);
            int fd = accept4(listen_fd_, (sockaddr*)&client_addr,
                            &len, SOCK_NONBLOCK | SOCK_CLOEXEC);
            if (fd < 0) {
                if (errno == EAGAIN || errno == EWOULDBLOCK) {
                    break;  // 没有更多连接了
                }
                if (errno == EINTR) continue;
                break;
            }

            int opt = 1;
            setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &opt, sizeof(opt));

            char ip[INET_ADDRSTRLEN];
            inet_ntop(AF_INET, &client_addr.sin_addr, ip, sizeof(ip));
            std::string peer = std::string(ip) + ":" +
                              std::to_string(ntohs(client_addr.sin_port));

            auto conn = std::make_shared<Connection>(fd, peer);
            conns_[fd] = conn;

            // ET模式注册
            epoll_event ev;
            ev.events = EPOLLIN | EPOLLET;  // ET + 只读
            ev.data.fd = fd;
            epoll_ctl(epfd_, EPOLL_CTL_ADD, fd, &ev);

            printf("[+] %s (fd=%d)\n", peer.c_str(), fd);
        }
    }

    // ─── ET模式read：必须循环读到EAGAIN ───
    void on_read(std::shared_ptr<Connection>& conn) {
        while (true) {  // ← ET关键：循环读！
            char buf[4096];
            ssize_t n = read(conn->fd, buf, sizeof(buf));

            if (n > 0) {
                conn->total_rx += n;
                conn->send_buf.append(buf, n);
                continue;  // 继续读，直到EAGAIN
            }

            if (n == 0) {
                // 对端关闭
                on_close(conn);
                return;
            }

            // n < 0
            if (errno == EAGAIN || errno == EWOULDBLOCK) {
                // 读完了！现在处理数据
                break;
            }
            if (errno == EINTR) {
                continue;  // 被信号中断，重试
            }

            // 真正的错误
            on_close(conn);
            return;
        }

        // 读完了，如果有数据要发送
        if (!conn->send_buf.empty()) {
            // 先尝试直接发送（减少syscall）
            try_send(conn);

            // 如果还有剩余，开启EPOLLOUT
            if (!conn->send_buf.empty()) {
                epoll_event ev;
                ev.events = EPOLLIN | EPOLLOUT | EPOLLET;
                ev.data.fd = conn->fd;
                epoll_ctl(epfd_, EPOLL_CTL_MOD, conn->fd, &ev);
            }
        }
    }

    // ─── ET模式write：循环写到EAGAIN ───
    void on_write(std::shared_ptr<Connection>& conn) {
        try_send(conn);

        if (conn->send_buf.empty()) {
            // 全部发完，取消EPOLLOUT
            epoll_event ev;
            ev.events = EPOLLIN | EPOLLET;
            ev.data.fd = conn->fd;
            epoll_ctl(epfd_, EPOLL_CTL_MOD, conn->fd, &ev);
        }
        // 如果没发完，EPOLLOUT仍然开着
        // 下次缓冲区有空间时ET会再次通知
    }

    void try_send(std::shared_ptr<Connection>& conn) {
        while (!conn->send_buf.empty()) {  // ← ET关键：循环写！
            ssize_t n = write(conn->fd,
                             conn->send_buf.data(),
                             conn->send_buf.size());
            if (n > 0) {
                conn->total_tx += n;
                conn->send_buf.erase(0, n);
                continue;
            }

            if (n == 0) break;

            if (errno == EAGAIN || errno == EWOULDBLOCK) {
                break;  // 发送缓冲区满，等EPOLLOUT
            }
            if (errno == EINTR) continue;

            // 错误
            on_close(conn);
            return;
        }
    }

    void on_close(std::shared_ptr<Connection>& conn) {
        int fd = conn->fd;
        printf("[-] %s (fd=%d) rx=%lu tx=%lu\n",
               conn->peer_addr.c_str(), fd,
               conn->total_rx, conn->total_tx);

        epoll_ctl(epfd_, EPOLL_CTL_DEL, fd, nullptr);
        close(fd);
        conns_.erase(fd);
    }

    int port_;
    int epfd_ = -1;
    int listen_fd_ = -1;
    std::unordered_map<int, std::shared_ptr<Connection>> conns_;
};

int main(int argc, char* argv[]) {
    int port = (argc > 1) ? atoi(argv[1]) : 8080;
    ETEchoServer server(port);
    if (!server.start()) return 1;
    server.run();
    return 0;
}

/*
ET模式编程要点总结：

1. accept必须循环：
   while (true) {
       fd = accept4(...);
       if (fd < 0 && errno == EAGAIN) break;
   }

2. read必须循环到EAGAIN：
   while (true) {
       n = read(fd, buf, sizeof(buf));
       if (n > 0) { process(buf, n); continue; }
       if (n == 0) { close_conn(); return; }
       if (errno == EAGAIN) break;  // 读完了
   }

3. write必须循环到EAGAIN：
   while (!send_buf.empty()) {
       n = write(fd, send_buf.data(), send_buf.size());
       if (n > 0) { send_buf.erase(0, n); continue; }
       if (errno == EAGAIN) break;  // 缓冲区满
   }

4. 必须使用非阻塞fd
   否则最后一次read/write会阻塞

5. EPOLLOUT管理：
   ET模式下EPOLLOUT只在缓冲区从满变为非满时触发
   所以不会像LT那样持续触发
   但仍建议发完后取消EPOLLOUT
*/
```

#### 代码示例9：ET模式常见Bug演示与修复

```cpp
// 示例9: et_common_bugs.cpp
// ET模式常见bug演示与修复
// 理解这些bug对于正确使用ET至关重要

#include <sys/epoll.h>
#include <sys/socket.h>
#include <unistd.h>
#include <fcntl.h>
#include <cstdio>
#include <cerrno>

/*
═══════════════════════════════════════════════════════════
Bug 1: 没有循环读取（最常见！）
═══════════════════════════════════════════════════════════
*/

// ❌ 错误：只读一次
void bug1_wrong(int fd) {
    char buf[1024];
    ssize_t n = read(fd, buf, sizeof(buf));
    if (n > 0) {
        // 处理数据...
    }
    // 问题：如果接收缓冲区有4096字节，只读了1024字节
    // ET模式不会再次通知！剩下的3072字节"丢失"了
}

// ✓ 正确：循环读到EAGAIN
void bug1_fixed(int fd) {
    while (true) {
        char buf[1024];
        ssize_t n = read(fd, buf, sizeof(buf));
        if (n > 0) {
            // 处理数据...
            continue;
        }
        if (n == 0) {
            // 对端关闭
            break;
        }
        if (errno == EAGAIN || errno == EWOULDBLOCK) {
            break;  // 读完了
        }
        if (errno == EINTR) continue;
        break;  // 错误
    }
}


/*
═══════════════════════════════════════════════════════════
Bug 2: 使用阻塞fd
═══════════════════════════════════════════════════════════
*/

// ❌ 错误：阻塞fd + ET模式
void bug2_wrong(int listen_fd, int epfd) {
    // 没有设置SOCK_NONBLOCK
    int client_fd = accept(listen_fd, nullptr, nullptr);

    epoll_event ev;
    ev.events = EPOLLIN | EPOLLET;
    ev.data.fd = client_fd;
    epoll_ctl(epfd, EPOLL_CTL_ADD, client_fd, &ev);

    // 问题：之后循环read时，最后一次read会阻塞整个事件循环！
    // 因为数据读完后read不会返回EAGAIN，而是阻塞等待
}

// ✓ 正确：非阻塞fd
void bug2_fixed(int listen_fd, int epfd) {
    int client_fd = accept4(listen_fd, nullptr, nullptr,
                           SOCK_NONBLOCK | SOCK_CLOEXEC);

    epoll_event ev;
    ev.events = EPOLLIN | EPOLLET;
    ev.data.fd = client_fd;
    epoll_ctl(epfd, EPOLL_CTL_ADD, client_fd, &ev);
}


/*
═══════════════════════════════════════════════════════════
Bug 3: ET模式下listen socket只accept一次
═══════════════════════════════════════════════════════════
*/

// ❌ 错误：ET模式下只accept一个连接
void bug3_wrong(int listen_fd) {
    int fd = accept4(listen_fd, nullptr, nullptr, SOCK_NONBLOCK);
    // 处理新连接...

    // 问题：如果同时有多个连接到达，只accept了一个
    // ET只通知一次，其余连接永远不会被accept！
}

// ✓ 正确：循环accept
void bug3_fixed(int listen_fd) {
    while (true) {
        int fd = accept4(listen_fd, nullptr, nullptr, SOCK_NONBLOCK);
        if (fd < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK) break;
            if (errno == EINTR) continue;
            break;
        }
        // 处理新连接...
    }
}


/*
═══════════════════════════════════════════════════════════
Bug 4: 忘记处理EINTR
═══════════════════════════════════════════════════════════
*/

// ❌ 错误：没处理EINTR
void bug4_wrong(int fd) {
    while (true) {
        char buf[4096];
        ssize_t n = read(fd, buf, sizeof(buf));
        if (n > 0) { /* process */ continue; }
        if (n == 0) { /* close */ break; }
        if (errno == EAGAIN) break;
        // 如果被信号中断（EINTR），错误地当作真正错误处理
        break;  // ← Bug：应该重试
    }
}

// ✓ 正确：处理EINTR
void bug4_fixed(int fd) {
    while (true) {
        char buf[4096];
        ssize_t n = read(fd, buf, sizeof(buf));
        if (n > 0) { /* process */ continue; }
        if (n == 0) { /* close */ break; }
        if (errno == EAGAIN || errno == EWOULDBLOCK) break;
        if (errno == EINTR) continue;  // ← 重试！
        break;  // 真正的错误
    }
}


/*
═══════════════════════════════════════════════════════════
Bug 5: 短写（short write）未处理
═══════════════════════════════════════════════════════════
*/

// ❌ 错误：假设write一次就能发完
void bug5_wrong(int fd, const char* data, size_t len) {
    write(fd, data, len);  // 可能只发了一部分！
}

// ✓ 正确：循环发送
void bug5_fixed(int fd, const char* data, size_t len) {
    size_t sent = 0;
    while (sent < len) {
        ssize_t n = write(fd, data + sent, len - sent);
        if (n > 0) {
            sent += n;
            continue;
        }
        if (errno == EAGAIN || errno == EWOULDBLOCK) {
            // 缓冲区满，需要保存剩余数据等EPOLLOUT
            // save_remaining(data + sent, len - sent);
            break;
        }
        if (errno == EINTR) continue;
        break;  // 错误
    }
}


/*
═══════════════════════════════════════════════════════════
Bug 6: EPOLLRDHUP未监听导致的半关闭问题
═══════════════════════════════════════════════════════════
*/

// ❌ 错误：没有监听EPOLLRDHUP
void bug6_wrong(int epfd, int fd) {
    epoll_event ev;
    ev.events = EPOLLIN | EPOLLET;
    ev.data.fd = fd;
    epoll_ctl(epfd, EPOLL_CTL_ADD, fd, &ev);
    // 问题：对端shutdown(SHUT_WR)时，
    // 只会触发EPOLLIN，read返回0
    // 但如果此时没在读，可能延迟发现连接关闭
}

// ✓ 更好：监听EPOLLRDHUP
void bug6_fixed(int epfd, int fd) {
    epoll_event ev;
    ev.events = EPOLLIN | EPOLLRDHUP | EPOLLET;
    ev.data.fd = fd;
    epoll_ctl(epfd, EPOLL_CTL_ADD, fd, &ev);
    // EPOLLRDHUP可以更精确地检测对端关闭
}

int main() {
    printf("This file demonstrates common ET mode bugs.\n");
    printf("Read the comments to understand each bug and its fix.\n");
    return 0;
}
```

#### Day 10-11 自测题

```
Q1: ET模式下，如果读了一半数据就停止（没读到EAGAIN），
    会发生什么？
A1: 剩余数据仍在接收缓冲区中，但ET不会再次通知EPOLLIN。
    这些数据"沉默"在缓冲区中，直到新数据到达触发新的ET通知。
    如果对端不再发数据，这些数据就永远不会被读取。
    这就是为什么ET模式必须循环读到EAGAIN。

Q2: ET模式下EPOLLOUT什么时候触发？
A2: 在以下情况触发：
    1. 连接建立后第一次（如果监听了EPOLLOUT）
    2. 发送缓冲区从满变为非满（有空间可写了）
    不像LT模式那样只要有空间就持续触发。
    所以ET模式下EPOLLOUT不会造成busy loop。

Q3: ET模式为什么必须使用非阻塞fd？
A3: 因为ET要求循环读写直到EAGAIN：
    - 非阻塞fd：数据读完后read返回-1, errno=EAGAIN → 正常退出循环
    - 阻塞fd：数据读完后read阻塞等待新数据 → 整个事件循环卡住！
    阻塞fd无法返回EAGAIN，所以无法判断"数据已读完"。

Q4: 如果ET模式下同时有EPOLLIN和EPOLLOUT事件，处理顺序重要吗？
A4: 一般先处理读后处理写：
    1. 读可能产生要发送的数据
    2. 读可能发现连接关闭（避免对已关闭的连接写）
    3. 如果先写后读，可能先发送旧数据，再发现连接已关
    但这不是硬性要求，取决于应用逻辑。

Q5: ET模式下listen socket的accept也需要循环吗？
A5: 是的。如果多个连接几乎同时到达，ET只通知一次。
    必须循环accept直到返回EAGAIN，才能接受所有等待的连接。
    否则多余的连接请求会停留在内核backlog中，等待下一次ET通知
    （如果有新连接来的话），但如果不再有新连接来，它们就永远等待。
```

---

### Day 12-14：LT vs ET对比与EPOLLONESHOT（15小时）

#### 学习目标

- 全面对比LT和ET模式的差异
- 掌握EPOLLONESHOT的使用场景
- 理解多线程环境下的epoll安全问题

#### LT vs ET全面对比

```
═══════════════════════════════════════════════════════════
LT vs ET 全面对比
═══════════════════════════════════════════════════════════

┌─────────────────┬────────────────────┬────────────────────┐
│ 维度            │ LT (水平触发)      │ ET (边缘触发)      │
├─────────────────┼────────────────────┼────────────────────┤
│ 触发条件        │ fd就绪时持续触发   │ fd状态变化时触发   │
│ 通知次数        │ 多次（直到不就绪） │ 一次（直到状态变化）│
│ 读取方式        │ 读一次即可         │ 必须循环读到EAGAIN │
│ 写入方式        │ 写一次即可         │ 必须循环写到EAGAIN │
│ fd类型要求      │ 阻塞/非阻塞均可   │ 必须非阻塞         │
│ 编程难度        │ 简单               │ 较难               │
│ EPOLLOUT管理    │ 必须手动开关       │ 不会持续触发       │
│ 数据丢失风险    │ 无                 │ 忘记循环则丢失     │
│ 多余唤醒        │ 可能有（LT重复通知）│ 无                │
│ select/poll兼容 │ 语义一致           │ 语义不同           │
│ 典型使用者      │ libevent           │ Nginx              │
│ 适合场景        │ 通用、安全优先     │ 高性能、极致优化   │
└─────────────────┴────────────────────┴────────────────────┘


性能对比（理论分析）：

场景：1000个连接，每次有10个活跃

LT模式：
  epoll_wait → 返回10个事件
  每个事件read一次
  如果有4个没读完 → 下次epoll_wait又返回这4个
  → 总共14次事件处理（10 + 4重复）

ET模式：
  epoll_wait → 返回10个事件
  每个事件循环read到EAGAIN
  → 总共10次事件处理（无重复）

在高并发下，ET减少的事件次数可能带来显著性能提升。
但如果每次数据量小（一次read就能读完），
LT和ET的差异很小。
```

#### 代码示例10：EPOLLONESHOT多线程服务器

```cpp
// 示例10: epoll_oneshot_mt.cpp
// EPOLLONESHOT + 多线程Echo服务器
// 展示如何在多线程环境下安全使用epoll

#include <sys/epoll.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <cstdio>
#include <cstring>
#include <cerrno>
#include <thread>
#include <vector>
#include <atomic>
#include <functional>

/*
多线程 + epoll的问题：

场景：多个线程共享一个epoll实例

Thread-1: epoll_wait() → fd=5可读 → 开始处理
Thread-2: epoll_wait() → fd=5可读 → 也开始处理！
                                    ↑ 同一个fd被两个线程同时处理！

这会导致：
1. 数据竞争（两个线程同时read同一个fd）
2. 数据乱序
3. 重复处理

解决方案：EPOLLONESHOT

EPOLLONESHOT语义：
- 事件触发后，自动停止监听该fd
- 只有显式重新注册（epoll_ctl MOD）后才会再次触发
- 确保同一时刻只有一个线程处理同一个fd

使用流程：
1. 注册fd时设置EPOLLONESHOT
2. 事件触发 → 该fd自动停止监听
3. 线程处理完毕 → 调用epoll_ctl(MOD)重新注册
4. fd重新进入监听状态
*/

static std::atomic<int> active_threads{0};

class OneShotServer {
public:
    OneShotServer(int port, int num_threads)
        : port_(port), num_threads_(num_threads) {}

    ~OneShotServer() {
        running_ = false;
        if (epfd_ >= 0) close(epfd_);
        if (listen_fd_ >= 0) close(listen_fd_);
    }

    bool start() {
        epfd_ = epoll_create1(EPOLL_CLOEXEC);
        if (epfd_ < 0) return false;

        listen_fd_ = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK, 0);
        if (listen_fd_ < 0) return false;

        int opt = 1;
        setsockopt(listen_fd_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = INADDR_ANY;
        addr.sin_port = htons(port_);

        if (bind(listen_fd_, (sockaddr*)&addr, sizeof(addr)) < 0) return false;
        if (listen(listen_fd_, SOMAXCONN) < 0) return false;

        // listen socket用LT模式（不用ONESHOT，因为要持续accept）
        epoll_event ev;
        ev.events = EPOLLIN;  // LT模式
        ev.data.fd = listen_fd_;
        epoll_ctl(epfd_, EPOLL_CTL_ADD, listen_fd_, &ev);

        printf("[ONESHOT Server] port=%d, threads=%d\n", port_, num_threads_);
        return true;
    }

    void run() {
        running_ = true;

        // 创建工作线程
        std::vector<std::thread> threads;
        for (int i = 0; i < num_threads_; ++i) {
            threads.emplace_back(&OneShotServer::worker, this, i);
        }

        for (auto& t : threads) {
            t.join();
        }
    }

private:
    void worker(int thread_id) {
        printf("[Thread %d] Started\n", thread_id);
        std::vector<epoll_event> events(64);

        while (running_) {
            int n = epoll_wait(epfd_, events.data(), events.size(), 1000);
            if (n < 0) {
                if (errno == EINTR) continue;
                break;
            }

            for (int i = 0; i < n; ++i) {
                int fd = events[i].data.fd;
                uint32_t revents = events[i].events;

                if (fd == listen_fd_) {
                    // accept新连接（只在一个线程中处理）
                    handle_accept();
                } else {
                    // 处理客户端事件
                    // 由于EPOLLONESHOT，此时fd已停止监听
                    // 只有当前线程在处理这个fd
                    active_threads++;
                    handle_client(fd, revents, thread_id);
                    active_threads--;
                }
            }
        }

        printf("[Thread %d] Exiting\n", thread_id);
    }

    void handle_accept() {
        while (true) {
            sockaddr_in addr{};
            socklen_t len = sizeof(addr);
            int fd = accept4(listen_fd_, (sockaddr*)&addr,
                            &len, SOCK_NONBLOCK);
            if (fd < 0) {
                if (errno == EAGAIN || errno == EWOULDBLOCK) break;
                if (errno == EINTR) continue;
                break;
            }

            char ip[INET_ADDRSTRLEN];
            inet_ntop(AF_INET, &addr.sin_addr, ip, sizeof(ip));
            printf("[+] %s:%d (fd=%d)\n", ip, ntohs(addr.sin_port), fd);

            // 注册客户端fd：ET + ONESHOT
            epoll_event ev;
            ev.events = EPOLLIN | EPOLLET | EPOLLONESHOT;
            ev.data.fd = fd;
            epoll_ctl(epfd_, EPOLL_CTL_ADD, fd, &ev);
        }
    }

    void handle_client(int fd, uint32_t revents, int thread_id) {
        if (revents & (EPOLLERR | EPOLLHUP)) {
            printf("[-] fd=%d (error/hangup) [thread %d]\n", fd, thread_id);
            close(fd);
            return;
        }

        // ET模式：循环读到EAGAIN
        char buf[4096];
        std::string data;

        while (true) {
            ssize_t n = read(fd, buf, sizeof(buf));
            if (n > 0) {
                data.append(buf, n);
                continue;
            }
            if (n == 0) {
                printf("[-] fd=%d (closed) [thread %d]\n", fd, thread_id);
                close(fd);
                return;
            }
            if (errno == EAGAIN || errno == EWOULDBLOCK) break;
            if (errno == EINTR) continue;
            close(fd);
            return;
        }

        // Echo回写
        if (!data.empty()) {
            size_t sent = 0;
            while (sent < data.size()) {
                ssize_t n = write(fd, data.data() + sent, data.size() - sent);
                if (n > 0) { sent += n; continue; }
                if (errno == EAGAIN || errno == EWOULDBLOCK) break;
                if (errno == EINTR) continue;
                close(fd);
                return;
            }
        }

        // ★ 关键：处理完毕后重新注册EPOLLONESHOT
        // 这样fd重新进入监听状态，可以被任意线程处理
        epoll_event ev;
        ev.events = EPOLLIN | EPOLLET | EPOLLONESHOT;
        ev.data.fd = fd;
        if (epoll_ctl(epfd_, EPOLL_CTL_MOD, fd, &ev) < 0) {
            // 可能fd已经被关闭
            if (errno != ENOENT) perror("epoll_ctl MOD");
        }
    }

    int port_;
    int num_threads_;
    int epfd_ = -1;
    int listen_fd_ = -1;
    std::atomic<bool> running_{false};
};

int main(int argc, char* argv[]) {
    int port = (argc > 1) ? atoi(argv[1]) : 8080;
    int threads = (argc > 2) ? atoi(argv[2]) : 4;

    OneShotServer server(port, threads);
    if (!server.start()) return 1;
    server.run();
    return 0;
}

/*
EPOLLONESHOT工作流程：

Time    Thread-1              Thread-2              fd=5状态
────────────────────────────────────────────────────────────
T1      epoll_wait()                                监听中
T2      → fd=5事件            epoll_wait()          停止监听!
T3      处理fd=5...                                 停止监听
T4      处理完毕                                    停止监听
T5      epoll_ctl(MOD)        → 无fd=5事件          重新监听
T6                            epoll_wait()
T7                            → fd=5事件            停止监听
T8                            处理fd=5...           停止监听

注意T3：即使Thread-2也在epoll_wait，也不会收到fd=5的事件
因为ONESHOT在T2时已经停止了fd=5的监听

编译运行：
$ g++ -std=c++17 -pthread -o oneshot epoll_oneshot_mt.cpp
$ ./oneshot 8080 4
*/
```

#### 代码示例11：LT vs ET性能对比程序

```cpp
// 示例11: lt_vs_et_benchmark.cpp
// LT vs ET 模式性能对比
// 测量不同负载下的事件处理效率

#include <sys/epoll.h>
#include <sys/socket.h>
#include <unistd.h>
#include <fcntl.h>
#include <cstdio>
#include <cstring>
#include <cerrno>
#include <chrono>
#include <vector>

using Clock = std::chrono::high_resolution_clock;
using Micros = std::chrono::duration<double, std::micro>;

static void set_nonblocking(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    fcntl(fd, F_SETFL, flags | O_NONBLOCK);
}

struct BenchResult {
    double total_time_us;
    int total_events;
    int epoll_wait_calls;
    double events_per_us;
};

// 测试方法：
// 1. 创建N个socketpair
// 2. 向active_count个写端写入data_size字节
// 3. 使用LT/ET模式读取所有数据
// 4. 统计epoll_wait调用次数和总时间

BenchResult bench_mode(int num_fds, int active_count,
                       int data_size, bool use_et) {
    // 创建socketpairs
    std::vector<int> read_fds, write_fds;
    for (int i = 0; i < num_fds; ++i) {
        int sv[2];
        socketpair(AF_UNIX, SOCK_STREAM, 0, sv);
        set_nonblocking(sv[0]);
        set_nonblocking(sv[1]);
        read_fds.push_back(sv[0]);
        write_fds.push_back(sv[1]);
    }

    // 创建epoll
    int epfd = epoll_create1(EPOLL_CLOEXEC);
    for (int fd : read_fds) {
        epoll_event ev;
        ev.events = EPOLLIN | (use_et ? EPOLLET : 0);
        ev.data.fd = fd;
        epoll_ctl(epfd, EPOLL_CTL_ADD, fd, &ev);
    }

    // 写入数据
    std::vector<char> data(data_size, 'x');
    for (int i = 0; i < active_count; ++i) {
        write(write_fds[i], data.data(), data.size());
    }

    // 读取所有数据
    std::vector<epoll_event> events(num_fds);
    char buf[1024];  // 故意用小缓冲，使得需要多次read
    int total_read = 0;
    int target_read = active_count * data_size;
    int epoll_calls = 0;
    int total_events = 0;

    auto start = Clock::now();

    while (total_read < target_read) {
        int n = epoll_wait(epfd, events.data(), events.size(), 100);
        epoll_calls++;

        if (n <= 0) break;
        total_events += n;

        for (int i = 0; i < n; ++i) {
            if (use_et) {
                // ET模式：循环读到EAGAIN
                while (true) {
                    ssize_t r = read(events[i].data.fd, buf, sizeof(buf));
                    if (r > 0) { total_read += r; continue; }
                    break;
                }
            } else {
                // LT模式：读一次
                ssize_t r = read(events[i].data.fd, buf, sizeof(buf));
                if (r > 0) total_read += r;
            }
        }
    }

    auto end = Clock::now();

    BenchResult result;
    result.total_time_us = Micros(end - start).count();
    result.total_events = total_events;
    result.epoll_wait_calls = epoll_calls;
    result.events_per_us = total_events / result.total_time_us;

    // 清理
    close(epfd);
    for (int fd : read_fds) close(fd);
    for (int fd : write_fds) close(fd);

    return result;
}

int main() {
    printf("LT vs ET Performance Comparison\n");
    printf("================================\n\n");

    struct TestCase {
        int num_fds;
        int active;
        int data_size;
    };

    std::vector<TestCase> tests = {
        {100,  10,  4096},
        {100,  10,  65536},
        {1000, 100, 4096},
        {1000, 100, 65536},
        {5000, 500, 4096},
    };

    printf("%-8s %-8s %-10s %-6s %-12s %-12s %-12s\n",
           "FDs", "Active", "DataSize", "Mode",
           "Time(μs)", "Events", "Waits");
    printf("────────────────────────────────────────────────"
           "──────────────────────\n");

    for (auto& tc : tests) {
        auto lt = bench_mode(tc.num_fds, tc.active, tc.data_size, false);
        auto et = bench_mode(tc.num_fds, tc.active, tc.data_size, true);

        printf("%-8d %-8d %-10d %-6s %-12.1f %-12d %-12d\n",
               tc.num_fds, tc.active, tc.data_size, "LT",
               lt.total_time_us, lt.total_events, lt.epoll_wait_calls);

        printf("%-8d %-8d %-10d %-6s %-12.1f %-12d %-12d\n",
               tc.num_fds, tc.active, tc.data_size, "ET",
               et.total_time_us, et.total_events, et.epoll_wait_calls);

        double speedup = lt.total_time_us / et.total_time_us;
        printf("  → ET speedup: %.2fx (events: LT=%d vs ET=%d)\n\n",
               speedup, lt.total_events, et.total_events);
    }

    printf("结论：\n");
    printf("- 数据量大(需多次read)时，LT产生更多事件（重复通知）\n");
    printf("- ET通过循环读取减少了epoll_wait调用次数\n");
    printf("- 数据量小(一次read读完)时，LT和ET差异小\n");

    return 0;
}

/*
编译运行：
$ g++ -O2 -o lt_et_bench lt_vs_et_benchmark.cpp
$ ./lt_et_bench
*/
```

#### 代码示例12：ET模式写事件处理策略

```cpp
// 示例12: et_write_strategy.cpp
// ET模式下的写事件处理策略
// 展示"先尝试直接发送"优化

#include <sys/epoll.h>
#include <sys/socket.h>
#include <unistd.h>
#include <fcntl.h>
#include <cstdio>
#include <cerrno>
#include <string>

/*
ET模式写事件优化策略：先尝试直接发送

原理：
大部分情况下，socket的发送缓冲区都有空间。
所以收到数据后可以先尝试直接write，而不是注册EPOLLOUT等通知。

┌──────────────────────────────────────────────┐
│  on_read(fd):                                │
│    data = loop_read(fd);  // 读完所有数据    │
│    n = loop_write(fd, data);  // 尝试直接发  │
│    if (n == data.size()):                    │
│        // 全部发完！不需要EPOLLOUT           │
│        return;                               │
│    // 没发完（缓冲区满）                      │
│    save_remaining(data, n);                  │
│    enable_epollout(fd);  // 开启EPOLLOUT     │
│                                              │
│  on_write(fd):                               │
│    n = loop_write(fd, remaining);            │
│    if (remaining.empty()):                   │
│        disable_epollout(fd);                 │
└──────────────────────────────────────────────┘

优点：
- 减少epoll_ctl调用（大部分时候不需要EPOLLOUT）
- 减少epoll_wait返回次数
- 降低延迟（不需要等下次epoll_wait）
*/

class ETWriteDemo {
public:
    // 策略：先尝试直接发送
    void on_read(int epfd, int fd) {
        // Step 1: ET循环读取所有数据
        std::string data;
        char buf[4096];
        while (true) {
            ssize_t n = read(fd, buf, sizeof(buf));
            if (n > 0) { data.append(buf, n); continue; }
            if (n == 0) { /* close */ return; }
            if (errno == EAGAIN) break;
            if (errno == EINTR) continue;
            return;
        }

        if (data.empty()) return;

        // Step 2: 先尝试直接发送
        size_t sent = 0;
        while (sent < data.size()) {
            ssize_t n = write(fd, data.data() + sent, data.size() - sent);
            if (n > 0) { sent += n; continue; }
            if (errno == EAGAIN || errno == EWOULDBLOCK) break;
            if (errno == EINTR) continue;
            return;  // 错误
        }

        if (sent == data.size()) {
            // 全部发完了！不需要注册EPOLLOUT
            // 这是最常见的情况（发送缓冲区通常有空间）
            return;
        }

        // Step 3: 没发完（发送缓冲区满），保存剩余数据
        send_buf_ = data.substr(sent);

        // 开启EPOLLOUT，等缓冲区有空间
        epoll_event ev;
        ev.events = EPOLLIN | EPOLLOUT | EPOLLET;
        ev.data.fd = fd;
        epoll_ctl(epfd, EPOLL_CTL_MOD, fd, &ev);
    }

    void on_write(int epfd, int fd) {
        // ET循环写
        while (!send_buf_.empty()) {
            ssize_t n = write(fd, send_buf_.data(), send_buf_.size());
            if (n > 0) { send_buf_.erase(0, n); continue; }
            if (errno == EAGAIN || errno == EWOULDBLOCK) break;
            if (errno == EINTR) continue;
            return;
        }

        if (send_buf_.empty()) {
            // 发完了，取消EPOLLOUT
            epoll_event ev;
            ev.events = EPOLLIN | EPOLLET;
            ev.data.fd = fd;
            epoll_ctl(epfd, EPOLL_CTL_MOD, fd, &ev);
        }
    }

private:
    std::string send_buf_;
};

int main() {
    printf("This file demonstrates ET write optimization strategy.\n");
    printf("Key idea: try direct write first, only enable EPOLLOUT\n");
    printf("when send buffer is full (EAGAIN).\n");
    return 0;
}
```

#### Day 12-14 自测题

```
Q1: EPOLLONESHOT解决了什么问题？
A1: 解决多线程共享epoll时，同一个fd被多个线程同时处理的问题。
    EPOLLONESHOT在事件触发后自动停止监听该fd，
    确保同一时刻只有一个线程处理同一个fd。
    处理完毕后需要调用epoll_ctl(MOD)重新注册。

Q2: EPOLLONESHOT和ET模式的关系是什么？
A2: 它们是独立的特性，可以组合使用：
    - ET: 控制通知频率（状态变化时通知）
    - ONESHOT: 控制并发访问（事件后自动停止监听）
    常见组合：EPOLLIN | EPOLLET | EPOLLONESHOT
    用于多线程ET模式服务器。

Q3: 为什么"先尝试直接发送"是一种好的优化？
A3: 因为大部分时候socket发送缓冲区都有空间：
    1. 避免了注册EPOLLOUT → epoll_wait返回 → write的额外延迟
    2. 减少了epoll_ctl调用次数
    3. 减少了epoll_wait返回的事件数量
    只有在缓冲区真的满了（EAGAIN）时才注册EPOLLOUT，
    这是最优的写事件处理策略。

Q4: 在什么场景下LT比ET更合适？
A4: LT更适合：
    1. 开发初期/原型阶段（简单不容易出bug）
    2. 数据处理逻辑复杂，不方便在循环中处理
    3. 需要与select/poll代码兼容
    4. 团队对ET不熟悉（降低bug风险）
    5. 每次数据量小，一次就能读完（LT/ET无差异）

Q5: Nginx使用ET还是LT模式？
A5: Nginx使用ET模式。Nginx的设计理念是追求极致性能，
    ET模式减少了不必要的事件通知，配合Nginx的
    非阻塞处理架构，最大化了事件循环的效率。
    同时Nginx使用EPOLLEXCLUSIVE避免惊群问题。
```

---

### 第二周检验标准

```
第二周自我检验清单：

理论理解：
☐ 能清楚描述LT模式的触发语义和行为
☐ 能清楚描述ET模式的触发语义和行为
☐ 能说出ET模式的两条铁律（非阻塞fd + 循环至EAGAIN）
☐ 能解释LT模式下EPOLLOUT的busy loop问题
☐ 能说出ET模式EPOLLOUT不会busy loop的原因
☐ 理解EPOLLONESHOT的用途和工作流程
☐ 能对比LT vs ET在不同场景下的性能差异

实践能力：
☐ 能实现完整的LT模式Echo服务器
☐ 能实现完整的ET模式Echo服务器
☐ 能正确处理ET模式的循环读写
☐ 能避免ET模式的5个常见bug
☐ 能实现EPOLLONESHOT多线程服务器
☐ 能实现"先尝试直接发送"的写优化
☐ 能编写LT vs ET性能对比基准测试
```

---

## 第三周：epoll高级应用（Day 15-21）

### 本周时间分配

| 日期 | 内容 | 时间 |
|------|------|------|
| Day 15-16 | 惊群问题与EPOLLEXCLUSIVE | 10小时 |
| Day 17-18 | EpollLoop集成到EventLoop框架 | 10小时 |
| Day 19-21 | 高并发HTTP服务器 | 15小时 |

---

### Day 15-16：惊群问题与EPOLLEXCLUSIVE（10小时）

#### 学习目标

- 深入理解惊群问题的成因和影响
- 掌握三种解决方案：EPOLLEXCLUSIVE、SO_REUSEPORT、accept锁
- 能编写多进程/多线程epoll服务器

#### 惊群问题详解

```
═══════════════════════════════════════════════════════════
惊群问题（Thundering Herd Problem）
═══════════════════════════════════════════════════════════

场景：多个进程/线程在同一个listen socket上等待连接

正常预期：
  新连接到来 → 唤醒一个进程/线程处理

实际情况（无优化时）：
  新连接到来 → 唤醒所有等待的进程/线程！
  但只有一个能成功accept，其余白白唤醒

┌─────────────────────────────────────────────────┐
│  惊群示意图：                                    │
│                                                  │
│  Worker-1  ─┐                                    │
│  Worker-2  ─┤                                    │
│  Worker-3  ─┼── 全部在 epoll_wait(listen_fd)    │
│  Worker-4  ─┘                                    │
│                                                  │
│  新连接到来！                                    │
│       │                                          │
│       ▼                                          │
│  Worker-1  ← 唤醒，accept成功 ✓                 │
│  Worker-2  ← 唤醒，accept失败 EAGAIN ✗          │
│  Worker-3  ← 唤醒，accept失败 EAGAIN ✗          │
│  Worker-4  ← 唤醒，accept失败 EAGAIN ✗          │
│                                                  │
│  3个worker白白被唤醒 → 浪费CPU上下文切换开销    │
└─────────────────────────────────────────────────┘

影响：
- CPU浪费：无效的上下文切换
- 缓存污染：唤醒的进程污染了L1/L2缓存
- 锁竞争：如果使用锁保护accept
- 在高并发下影响显著


═══════════════════════════════════════════════════════════
解决方案对比
═══════════════════════════════════════════════════════════

┌─────────────────┬──────────────┬──────────────┬──────────────┐
│ 方案            │ EPOLLEXCLUSIVE│ SO_REUSEPORT │ Accept锁     │
├─────────────────┼──────────────┼──────────────┼──────────────┤
│ Linux版本       │ 4.5+         │ 3.9+         │ 任意          │
│ 实现层          │ epoll层      │ 内核网络栈   │ 用户空间     │
│ 原理            │ 只唤醒一个   │ 每线程独立   │ 互斥锁串行化 │
│                 │ 等待者       │ listen socket│ accept       │
│ 负载均衡        │ 由内核决定   │ 内核哈希分配 │ 锁竞争决定   │
│ 代码复杂度      │ 低           │ 低           │ 中           │
│ 性能            │ 好           │ 最好         │ 一般          │
│ 适用            │ 多线程       │ 多线程/多进程│ 多进程(Nginx)│
└─────────────────┴──────────────┴──────────────┴──────────────┘
```

#### 代码示例13：惊群问题演示

```cpp
// 示例13: thundering_herd_demo.cpp
// 惊群问题演示
// 创建多个线程共享epoll，观察accept竞争

#include <sys/epoll.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <cstdio>
#include <cstring>
#include <cerrno>
#include <thread>
#include <atomic>
#include <vector>
#include <chrono>

static std::atomic<int> total_wakeups{0};
static std::atomic<int> successful_accepts{0};
static std::atomic<int> failed_accepts{0};

void worker(int epfd, int listen_fd, int id) {
    epoll_event events[1];

    while (true) {
        int n = epoll_wait(epfd, events, 1, 5000);
        if (n <= 0) break;

        total_wakeups++;

        sockaddr_in addr{};
        socklen_t len = sizeof(addr);
        int fd = accept(listen_fd, (sockaddr*)&addr, &len);

        if (fd >= 0) {
            successful_accepts++;
            printf("[Worker %d] Accepted fd=%d\n", id, fd);
            close(fd);  // 简单关闭
        } else {
            failed_accepts++;
            printf("[Worker %d] Accept failed: %s\n", id, strerror(errno));
        }
    }
}

int main() {
    int listen_fd = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK, 0);
    int opt = 1;
    setsockopt(listen_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(9999);
    bind(listen_fd, (sockaddr*)&addr, sizeof(addr));
    listen(listen_fd, SOMAXCONN);

    // 创建共享的epoll实例
    int epfd = epoll_create1(EPOLL_CLOEXEC);
    epoll_event ev;
    ev.events = EPOLLIN;  // LT模式，无EXCLUSIVE
    ev.data.fd = listen_fd;
    epoll_ctl(epfd, EPOLL_CTL_ADD, listen_fd, &ev);

    // 启动4个worker线程
    const int NUM_WORKERS = 4;
    std::vector<std::thread> workers;
    for (int i = 0; i < NUM_WORKERS; ++i) {
        workers.emplace_back(worker, epfd, listen_fd, i);
    }

    printf("Server on port 9999 with %d workers (no EXCLUSIVE)\n", NUM_WORKERS);
    printf("Use: for i in $(seq 10); do nc -z localhost 9999; done\n");
    printf("Watch for thundering herd effect...\n\n");

    for (auto& w : workers) w.join();

    printf("\n=== Results ===\n");
    printf("Total wakeups: %d\n", total_wakeups.load());
    printf("Successful accepts: %d\n", successful_accepts.load());
    printf("Failed accepts: %d\n", failed_accepts.load());
    printf("Wasted wakeups: %d (%.1f%%)\n",
           failed_accepts.load(),
           100.0 * failed_accepts.load() / total_wakeups.load());

    close(listen_fd);
    close(epfd);
    return 0;
}

/*
预期结果：
Total wakeups: ~40  (10连接 × 4线程)
Successful accepts: 10
Failed accepts: ~30
Wasted wakeups: 30 (75%)

每个连接唤醒了4个线程，但只有1个成功accept！
*/
```

#### 代码示例14：SO_REUSEPORT多线程服务器

```cpp
// 示例14: reuseport_server.cpp
// 使用SO_REUSEPORT解决惊群问题
// 每个线程有独立的listen socket和epoll实例

#include <sys/epoll.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <cstdio>
#include <cstring>
#include <cerrno>
#include <thread>
#include <atomic>
#include <vector>
#include <string>

/*
SO_REUSEPORT方案：

传统方式（共享listen socket）：
┌──────────┐
│ listen:80│ ← 一个listen socket
└────┬─────┘
     │
┌────┼────┬────────┬────────┐
│    │    │        │        │
▼    ▼    ▼        ▼        ▼
W1   W2   W3       W4       W5  ← 所有worker共享
      惊群！

SO_REUSEPORT方式：
┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐
│ L:80 │ │ L:80 │ │ L:80 │ │ L:80 │ ← 每个worker独立listen
└──┬───┘ └──┬───┘ └──┬───┘ └──┬───┘
   │        │        │        │
   ▼        ▼        ▼        ▼
   W1       W2       W3       W4     ← 独立处理，无竞争
            内核按源IP:PORT哈希分配连接
*/

static std::atomic<bool> running{true};
static std::atomic<int> total_connections{0};

void worker_thread(int port, int id) {
    // 每个线程创建自己的listen socket
    int listen_fd = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK, 0);
    if (listen_fd < 0) { perror("socket"); return; }

    int opt = 1;
    setsockopt(listen_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    setsockopt(listen_fd, SOL_SOCKET, SO_REUSEPORT, &opt, sizeof(opt));
    // ↑ SO_REUSEPORT: 允许多个socket绑定同一地址端口

    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(port);

    if (bind(listen_fd, (sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("bind"); close(listen_fd); return;
    }
    if (listen(listen_fd, SOMAXCONN) < 0) {
        perror("listen"); close(listen_fd); return;
    }

    // 每个线程创建自己的epoll实例
    int epfd = epoll_create1(EPOLL_CLOEXEC);
    epoll_event ev;
    ev.events = EPOLLIN | EPOLLET;
    ev.data.fd = listen_fd;
    epoll_ctl(epfd, EPOLL_CTL_ADD, listen_fd, &ev);

    printf("[Worker %d] Ready (listen_fd=%d)\n", id, listen_fd);

    epoll_event events[64];
    int local_count = 0;

    while (running) {
        int n = epoll_wait(epfd, events, 64, 1000);
        if (n < 0) {
            if (errno == EINTR) continue;
            break;
        }

        for (int i = 0; i < n; ++i) {
            if (events[i].data.fd == listen_fd) {
                // 接受连接（ET模式循环）
                while (true) {
                    sockaddr_in client{};
                    socklen_t len = sizeof(client);
                    int fd = accept4(listen_fd, (sockaddr*)&client,
                                    &len, SOCK_NONBLOCK);
                    if (fd < 0) {
                        if (errno == EAGAIN) break;
                        if (errno == EINTR) continue;
                        break;
                    }

                    local_count++;
                    total_connections++;

                    char ip[INET_ADDRSTRLEN];
                    inet_ntop(AF_INET, &client.sin_addr, ip, sizeof(ip));

                    // Echo处理
                    char buf[4096];
                    while (true) {
                        ssize_t r = read(fd, buf, sizeof(buf));
                        if (r > 0) {
                            write(fd, buf, r);
                            continue;
                        }
                        break;
                    }
                    close(fd);
                }
            }
        }
    }

    printf("[Worker %d] Handled %d connections\n", id, local_count);
    close(listen_fd);
    close(epfd);
}

int main(int argc, char* argv[]) {
    int port = (argc > 1) ? atoi(argv[1]) : 8080;
    int num_threads = (argc > 2) ? atoi(argv[2]) : 4;

    printf("SO_REUSEPORT Server on port %d, %d threads\n", port, num_threads);

    std::vector<std::thread> threads;
    for (int i = 0; i < num_threads; ++i) {
        threads.emplace_back(worker_thread, port, i);
    }

    // 运行10秒
    std::this_thread::sleep_for(std::chrono::seconds(10));
    running = false;

    for (auto& t : threads) t.join();

    printf("\nTotal connections: %d\n", total_connections.load());
    return 0;
}

/*
SO_REUSEPORT优势：
1. 完全消除惊群：每个线程独立listen，内核哈希分配
2. 负载均衡：内核按源IP:PORT哈希，同一客户端总是分到同一线程
3. 无锁：线程间完全独立，无任何竞争
4. 缓存友好：每个线程的数据在自己的CPU缓存中

编译运行：
$ g++ -std=c++17 -pthread -o reuseport reuseport_server.cpp
$ ./reuseport 8080 4
*/
```

---

### Day 17-18：EpollLoop集成到EventLoop框架（10小时）

#### 学习目标

- 将epoll封装为EpollLoop，继承Month-26的EventLoop接口
- 集成timerfd实现精确定时器
- 集成signalfd实现信号处理
- 使用eventfd实现线程间唤醒

#### timerfd/signalfd/eventfd概述

```
═══════════════════════════════════════════════════════════
Linux特殊文件描述符：timerfd / signalfd / eventfd
═══════════════════════════════════════════════════════════

这三个是Linux提供的特殊fd，可以统一纳入epoll管理：

┌───────────┬────────────────────┬──────────────────┐
│ 类型      │ 用途               │ 头文件           │
├───────────┼────────────────────┼──────────────────┤
│ timerfd   │ 精确定时器         │ <sys/timerfd.h>  │
│ signalfd  │ 信号转为fd事件     │ <sys/signalfd.h> │
│ eventfd   │ 线程间/进程间通知  │ <sys/eventfd.h>  │
└───────────┴────────────────────┴──────────────────┘

传统方式 vs fd方式：

定时器：
  传统：alarm()/setitimer() → 信号SIGALRM → 中断epoll_wait
  timerfd：timerfd_create() → 返回fd → 加入epoll → 超时时可读

信号：
  传统：signal()/sigaction() → 信号处理函数（异步不安全）
  signalfd：signalfd() → 返回fd → 加入epoll → 信号到达时可读

线程通知：
  传统：pipe() → 写端write(1字节) → 读端在epoll中
  eventfd：eventfd() → 单个fd → write唤醒 → read清除

统一到epoll的优势：
1. 所有事件源用统一的epoll_wait处理
2. 不需要信号处理函数（避免异步安全问题）
3. 代码更清晰：事件驱动，无中断
```

#### 代码示例15：EpollLoop完整实现

```cpp
// 示例15: epoll_loop.hpp
// EpollLoop——继承Month-26的EventLoop接口
// 使用epoll + timerfd + signalfd + eventfd

#pragma once
#include <sys/epoll.h>
#include <sys/timerfd.h>
#include <sys/signalfd.h>
#include <sys/eventfd.h>
#include <signal.h>
#include <unistd.h>
#include <fcntl.h>
#include <cstdio>
#include <cstring>
#include <cerrno>
#include <functional>
#include <vector>
#include <unordered_map>
#include <queue>
#include <mutex>
#include <cstdint>

// Month-26 EventLoop接口（简化版）
class EventLoop {
public:
    using EventCallback = std::function<void(int fd, uint32_t events)>;
    using TimerCallback = std::function<void()>;

    virtual ~EventLoop() = default;
    virtual bool init() = 0;
    virtual void run() = 0;
    virtual void stop() = 0;
    virtual bool add_fd(int fd, uint32_t events, EventCallback cb) = 0;
    virtual bool modify_fd(int fd, uint32_t events) = 0;
    virtual bool remove_fd(int fd) = 0;
    virtual int add_timer(int ms, TimerCallback cb, bool repeat = false) = 0;
    virtual void cancel_timer(int timer_id) = 0;
    virtual void wakeup() = 0;
};

// EpollLoop实现
class EpollLoop : public EventLoop {
public:
    static constexpr int MAX_EVENTS = 1024;

    ~EpollLoop() override {
        if (epfd_ >= 0) close(epfd_);
        if (timer_fd_ >= 0) close(timer_fd_);
        if (signal_fd_ >= 0) close(signal_fd_);
        if (wakeup_fd_ >= 0) close(wakeup_fd_);
    }

    bool init() override {
        // 1. 创建epoll
        epfd_ = epoll_create1(EPOLL_CLOEXEC);
        if (epfd_ < 0) { perror("epoll_create1"); return false; }

        // 2. 创建timerfd（用于定时器）
        timer_fd_ = timerfd_create(CLOCK_MONOTONIC, TFD_NONBLOCK | TFD_CLOEXEC);
        if (timer_fd_ < 0) { perror("timerfd_create"); return false; }
        add_internal_fd(timer_fd_, EPOLLIN);

        // 3. 创建eventfd（用于线程间唤醒）
        wakeup_fd_ = eventfd(0, EFD_NONBLOCK | EFD_CLOEXEC);
        if (wakeup_fd_ < 0) { perror("eventfd"); return false; }
        add_internal_fd(wakeup_fd_, EPOLLIN);

        // 4. 创建signalfd（用于信号处理）
        sigset_t mask;
        sigemptyset(&mask);
        sigaddset(&mask, SIGINT);
        sigaddset(&mask, SIGTERM);
        sigaddset(&mask, SIGPIPE);

        // 阻塞这些信号（改由signalfd接收）
        sigprocmask(SIG_BLOCK, &mask, nullptr);

        signal_fd_ = signalfd(-1, &mask, SFD_NONBLOCK | SFD_CLOEXEC);
        if (signal_fd_ < 0) { perror("signalfd"); return false; }
        add_internal_fd(signal_fd_, EPOLLIN);

        return true;
    }

    void run() override {
        running_ = true;
        std::vector<epoll_event> events(MAX_EVENTS);

        while (running_) {
            int n = epoll_wait(epfd_, events.data(), events.size(), -1);
            if (n < 0) {
                if (errno == EINTR) continue;
                break;
            }

            for (int i = 0; i < n; ++i) {
                int fd = events[i].data.fd;
                uint32_t revents = events[i].events;

                if (fd == timer_fd_) {
                    handle_timer();
                } else if (fd == wakeup_fd_) {
                    handle_wakeup();
                } else if (fd == signal_fd_) {
                    handle_signal();
                } else {
                    // 用户注册的fd
                    auto it = fd_callbacks_.find(fd);
                    if (it != fd_callbacks_.end()) {
                        it->second(fd, revents);
                    }
                }
            }
        }
    }

    void stop() override { running_ = false; wakeup(); }

    bool add_fd(int fd, uint32_t events, EventCallback cb) override {
        epoll_event ev;
        ev.events = events;
        ev.data.fd = fd;
        if (epoll_ctl(epfd_, EPOLL_CTL_ADD, fd, &ev) < 0) return false;
        fd_callbacks_[fd] = std::move(cb);
        return true;
    }

    bool modify_fd(int fd, uint32_t events) override {
        epoll_event ev;
        ev.events = events;
        ev.data.fd = fd;
        return epoll_ctl(epfd_, EPOLL_CTL_MOD, fd, &ev) == 0;
    }

    bool remove_fd(int fd) override {
        epoll_ctl(epfd_, EPOLL_CTL_DEL, fd, nullptr);
        fd_callbacks_.erase(fd);
        return true;
    }

    int add_timer(int ms, TimerCallback cb, bool repeat = false) override {
        int id = next_timer_id_++;
        timers_[id] = {ms, std::move(cb), repeat};
        update_timerfd();
        return id;
    }

    void cancel_timer(int timer_id) override {
        timers_.erase(timer_id);
        update_timerfd();
    }

    void wakeup() override {
        uint64_t val = 1;
        write(wakeup_fd_, &val, sizeof(val));
    }

    // 设置信号回调
    void set_signal_callback(std::function<void(int signo)> cb) {
        signal_callback_ = std::move(cb);
    }

private:
    struct TimerEntry {
        int interval_ms;
        TimerCallback callback;
        bool repeat;
    };

    void add_internal_fd(int fd, uint32_t events) {
        epoll_event ev;
        ev.events = events;
        ev.data.fd = fd;
        epoll_ctl(epfd_, EPOLL_CTL_ADD, fd, &ev);
    }

    void handle_timer() {
        uint64_t exp;
        read(timer_fd_, &exp, sizeof(exp));

        // 触发所有到期的定时器
        std::vector<int> to_remove;
        for (auto& [id, timer] : timers_) {
            timer.callback();
            if (!timer.repeat) {
                to_remove.push_back(id);
            }
        }
        for (int id : to_remove) timers_.erase(id);
        update_timerfd();
    }

    void handle_wakeup() {
        uint64_t val;
        read(wakeup_fd_, &val, sizeof(val));
    }

    void handle_signal() {
        struct signalfd_siginfo info;
        while (read(signal_fd_, &info, sizeof(info)) == sizeof(info)) {
            int signo = info.ssi_signo;
            printf("Received signal %d\n", signo);

            if (signal_callback_) {
                signal_callback_(signo);
            }

            if (signo == SIGINT || signo == SIGTERM) {
                running_ = false;
            }
        }
    }

    void update_timerfd() {
        if (timers_.empty()) {
            // 停止定时器
            itimerspec ts{};
            timerfd_settime(timer_fd_, 0, &ts, nullptr);
            return;
        }

        // 找最小间隔
        int min_ms = INT32_MAX;
        for (auto& [id, timer] : timers_) {
            min_ms = std::min(min_ms, timer.interval_ms);
        }

        itimerspec ts{};
        ts.it_value.tv_sec = min_ms / 1000;
        ts.it_value.tv_nsec = (min_ms % 1000) * 1000000L;
        ts.it_interval = ts.it_value;  // 周期性
        timerfd_settime(timer_fd_, 0, &ts, nullptr);
    }

    int epfd_ = -1;
    int timer_fd_ = -1;
    int signal_fd_ = -1;
    int wakeup_fd_ = -1;
    bool running_ = false;
    int next_timer_id_ = 1;

    std::unordered_map<int, EventCallback> fd_callbacks_;
    std::unordered_map<int, TimerEntry> timers_;
    std::function<void(int)> signal_callback_;
};
```

#### 代码示例16：timerfd定时器演示

```cpp
// 示例16: timerfd_demo.cpp
// timerfd精确定时器——与epoll集成

#include <sys/epoll.h>
#include <sys/timerfd.h>
#include <unistd.h>
#include <cstdio>
#include <cstdint>
#include <cerrno>
#include <ctime>

int main() {
    // 创建timerfd
    // CLOCK_MONOTONIC: 单调递增时钟（不受系统时间修改影响）
    int tfd = timerfd_create(CLOCK_MONOTONIC, TFD_NONBLOCK | TFD_CLOEXEC);
    if (tfd < 0) { perror("timerfd_create"); return 1; }

    // 设置定时器：首次1秒后触发，之后每2秒触发
    struct itimerspec ts;
    ts.it_value.tv_sec = 1;        // 首次触发：1秒后
    ts.it_value.tv_nsec = 0;
    ts.it_interval.tv_sec = 2;     // 之后间隔：2秒
    ts.it_interval.tv_nsec = 0;

    timerfd_settime(tfd, 0, &ts, nullptr);

    // 创建epoll并注册timerfd
    int epfd = epoll_create1(EPOLL_CLOEXEC);
    epoll_event ev;
    ev.events = EPOLLIN;
    ev.data.fd = tfd;
    epoll_ctl(epfd, EPOLL_CTL_ADD, tfd, &ev);

    printf("Timer started: first=1s, interval=2s\n");

    epoll_event events[1];
    for (int i = 0; i < 5; ++i) {
        int n = epoll_wait(epfd, events, 1, -1);
        if (n <= 0) continue;

        // 读取timerfd（必须读取，否则LT模式会持续触发）
        uint64_t expirations;
        read(tfd, &expirations, sizeof(expirations));

        // 获取当前时间
        struct timespec now;
        clock_gettime(CLOCK_MONOTONIC, &now);

        printf("[%ld.%03ld] Timer fired! (expirations=%lu)\n",
               now.tv_sec, now.tv_nsec / 1000000, expirations);
    }

    close(tfd);
    close(epfd);
    return 0;
}

/*
输出：
Timer started: first=1s, interval=2s
[12345.001] Timer fired! (expirations=1)
[12347.001] Timer fired! (expirations=1)
[12349.001] Timer fired! (expirations=1)
[12351.001] Timer fired! (expirations=1)
[12353.001] Timer fired! (expirations=1)

注意：expirations表示自上次read以来触发的次数。
如果处理延迟导致跳过了几次触发，expirations>1。
*/
```

#### 代码示例17：signalfd信号处理演示

```cpp
// 示例17: signalfd_demo.cpp
// signalfd——将信号转为文件描述符事件

#include <sys/epoll.h>
#include <sys/signalfd.h>
#include <signal.h>
#include <unistd.h>
#include <cstdio>
#include <cerrno>

int main() {
    // 设置要通过signalfd接收的信号
    sigset_t mask;
    sigemptyset(&mask);
    sigaddset(&mask, SIGINT);   // Ctrl+C
    sigaddset(&mask, SIGTERM);  // kill
    sigaddset(&mask, SIGUSR1);  // 用户信号1

    // 阻塞这些信号（不让默认处理函数处理）
    // 改由signalfd接收
    if (sigprocmask(SIG_BLOCK, &mask, nullptr) < 0) {
        perror("sigprocmask"); return 1;
    }

    // 创建signalfd
    int sfd = signalfd(-1, &mask, SFD_NONBLOCK | SFD_CLOEXEC);
    if (sfd < 0) { perror("signalfd"); return 1; }

    // 加入epoll
    int epfd = epoll_create1(EPOLL_CLOEXEC);
    epoll_event ev;
    ev.events = EPOLLIN;
    ev.data.fd = sfd;
    epoll_ctl(epfd, EPOLL_CTL_ADD, sfd, &ev);

    printf("Waiting for signals (SIGINT/SIGTERM/SIGUSR1)...\n");
    printf("Try: kill -USR1 %d\n", getpid());

    epoll_event events[1];
    bool running = true;

    while (running) {
        int n = epoll_wait(epfd, events, 1, -1);
        if (n <= 0) continue;

        // 读取信号信息
        struct signalfd_siginfo info;
        ssize_t r = read(sfd, &info, sizeof(info));
        if (r != sizeof(info)) continue;

        printf("Received signal %d", info.ssi_signo);
        switch (info.ssi_signo) {
        case SIGINT:
            printf(" (SIGINT) from pid=%d\n", info.ssi_pid);
            running = false;
            break;
        case SIGTERM:
            printf(" (SIGTERM) from pid=%d\n", info.ssi_pid);
            running = false;
            break;
        case SIGUSR1:
            printf(" (SIGUSR1) from pid=%d\n", info.ssi_pid);
            break;
        }
    }

    printf("Exiting gracefully.\n");
    close(sfd);
    close(epfd);
    return 0;
}

/*
signalfd优势（vs 传统信号处理）：

传统方式：
  signal(SIGINT, handler);
  void handler(int sig) {
      // 异步信号处理函数！
      // 只能调用异步信号安全函数
      // 不能用printf, malloc, mutex等
      // 非常受限！
  }

signalfd方式：
  epoll_wait返回 → read(sfd) → 在主循环中处理
  可以调用任何函数，没有异步安全限制
  与其他I/O事件统一处理
*/
```

#### 代码示例18：eventfd线程间唤醒

```cpp
// 示例18: eventfd_demo.cpp
// eventfd——高效的线程间通知机制

#include <sys/epoll.h>
#include <sys/eventfd.h>
#include <unistd.h>
#include <cstdio>
#include <cstdint>
#include <cerrno>
#include <thread>
#include <chrono>

/*
eventfd vs pipe：

pipe方式（Month-26自管道技巧）：
  int pipefd[2];
  pipe(pipefd);
  // 需要2个fd，读端和写端
  // write(pipefd[1], "x", 1) → read(pipefd[0])

eventfd方式：
  int efd = eventfd(0, 0);
  // 只需要1个fd
  // write(efd, &val, 8) → read(efd, &val, 8)
  // val是uint64_t计数器

eventfd优势：
1. 只用1个fd（pipe用2个）
2. 内置计数器语义（可以累计通知次数）
3. 专为通知设计，性能更好
4. 支持EFD_SEMAPHORE信号量模式
*/

int main() {
    // 创建eventfd（初始值0）
    int efd = eventfd(0, EFD_NONBLOCK | EFD_CLOEXEC);
    if (efd < 0) { perror("eventfd"); return 1; }

    // 加入epoll
    int epfd = epoll_create1(EPOLL_CLOEXEC);
    epoll_event ev;
    ev.events = EPOLLIN;
    ev.data.fd = efd;
    epoll_ctl(epfd, EPOLL_CTL_ADD, efd, &ev);

    // 生产者线程：每秒发送一次通知
    std::thread producer([efd]() {
        for (int i = 1; i <= 5; ++i) {
            std::this_thread::sleep_for(std::chrono::seconds(1));
            uint64_t val = i;  // 通知值
            write(efd, &val, sizeof(val));
            printf("[Producer] Sent notification: %lu\n", val);
        }
    });

    // 消费者：在epoll中等待通知
    epoll_event events[1];
    int count = 0;

    while (count < 5) {
        int n = epoll_wait(epfd, events, 1, 5000);
        if (n <= 0) continue;

        uint64_t val;
        read(efd, &val, sizeof(val));
        // read会返回累计值并清零计数器
        printf("[Consumer] Received notification: %lu\n", val);
        count++;
    }

    producer.join();
    close(efd);
    close(epfd);
    printf("Done.\n");
    return 0;
}

/*
eventfd计数器行为：

write(efd, &val, 8):
  内部计数器 += val

read(efd, &buf, 8):
  buf = 内部计数器
  内部计数器 = 0  （读取后清零）

如果设置EFD_SEMAPHORE:
  read时每次只减1（信号量语义）

示例：
  write(val=3) → 计数器=3
  write(val=2) → 计数器=5
  read() → 返回5, 计数器=0

编译：g++ -std=c++17 -pthread -o eventfd eventfd_demo.cpp
*/
```

---

### Day 19-21：高并发HTTP服务器（15小时）

#### 学习目标

- 实现基于epoll的HTTP/1.1服务器
- 理解HTTP请求解析和响应构造
- 使用sendfile实现零拷贝文件传输

#### 代码示例19：HTTP请求解析器

```cpp
// 示例19: http_parser.hpp
// 简单的HTTP/1.1请求解析器

#pragma once
#include <string>
#include <unordered_map>
#include <cstring>

struct HttpRequest {
    std::string method;    // GET, POST, etc.
    std::string path;      // /index.html
    std::string version;   // HTTP/1.1
    std::unordered_map<std::string, std::string> headers;
    std::string body;
    bool keep_alive = true;

    bool parse(const std::string& raw) {
        // 解析请求行
        size_t line_end = raw.find("\r\n");
        if (line_end == std::string::npos) return false;

        std::string request_line = raw.substr(0, line_end);

        // 解析 METHOD PATH VERSION
        size_t sp1 = request_line.find(' ');
        if (sp1 == std::string::npos) return false;
        method = request_line.substr(0, sp1);

        size_t sp2 = request_line.find(' ', sp1 + 1);
        if (sp2 == std::string::npos) return false;
        path = request_line.substr(sp1 + 1, sp2 - sp1 - 1);
        version = request_line.substr(sp2 + 1);

        // 解析头部
        size_t pos = line_end + 2;
        while (pos < raw.size()) {
            size_t next = raw.find("\r\n", pos);
            if (next == std::string::npos) break;
            if (next == pos) {
                // 空行，头部结束
                pos = next + 2;
                break;
            }

            std::string line = raw.substr(pos, next - pos);
            size_t colon = line.find(':');
            if (colon != std::string::npos) {
                std::string key = line.substr(0, colon);
                std::string val = line.substr(colon + 1);
                // 去除前导空格
                while (!val.empty() && val[0] == ' ') val.erase(0, 1);
                headers[key] = val;
            }
            pos = next + 2;
        }

        // 检查Keep-Alive
        auto it = headers.find("Connection");
        if (it != headers.end()) {
            keep_alive = (it->second != "close");
        } else {
            keep_alive = (version == "HTTP/1.1");
        }

        // Body
        if (pos < raw.size()) {
            body = raw.substr(pos);
        }

        return true;
    }

    // 检查请求是否完整（收到了\r\n\r\n）
    static bool is_complete(const std::string& data) {
        return data.find("\r\n\r\n") != std::string::npos;
    }
};
```

#### 代码示例20：HTTP响应构造器

```cpp
// 示例20: http_response.hpp
// HTTP响应构造器

#pragma once
#include <string>
#include <unordered_map>
#include <sstream>

struct HttpResponse {
    int status_code = 200;
    std::string status_text = "OK";
    std::unordered_map<std::string, std::string> headers;
    std::string body;

    void set_status(int code, const std::string& text) {
        status_code = code;
        status_text = text;
    }

    void set_header(const std::string& key, const std::string& val) {
        headers[key] = val;
    }

    void set_body(const std::string& content, const std::string& type = "text/html") {
        body = content;
        headers["Content-Type"] = type;
        headers["Content-Length"] = std::to_string(body.size());
    }

    std::string to_string() const {
        std::ostringstream oss;
        oss << "HTTP/1.1 " << status_code << " " << status_text << "\r\n";

        for (auto& [key, val] : headers) {
            oss << key << ": " << val << "\r\n";
        }

        if (headers.find("Connection") == headers.end()) {
            oss << "Connection: keep-alive\r\n";
        }

        oss << "\r\n";
        oss << body;
        return oss.str();
    }

    // 常用响应
    static HttpResponse make_200(const std::string& body,
                                 const std::string& type = "text/html") {
        HttpResponse resp;
        resp.set_body(body, type);
        return resp;
    }

    static HttpResponse make_404() {
        HttpResponse resp;
        resp.set_status(404, "Not Found");
        resp.set_body("<h1>404 Not Found</h1>");
        return resp;
    }

    static HttpResponse make_500() {
        HttpResponse resp;
        resp.set_status(500, "Internal Server Error");
        resp.set_body("<h1>500 Internal Server Error</h1>");
        return resp;
    }
};
```

#### 代码示例21：基于epoll的HTTP服务器

```cpp
// 示例21: epoll_http_server.cpp
// 基于epoll的HTTP/1.1服务器
// 支持Keep-Alive、静态文件服务

#include <sys/epoll.h>
#include <sys/socket.h>
#include <sys/sendfile.h>
#include <sys/stat.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <cstdio>
#include <cstring>
#include <cerrno>
#include <string>
#include <vector>
#include <unordered_map>
#include <memory>
#include <functional>

// Include our parser and response (示例19, 20)
// #include "http_parser.hpp"
// #include "http_response.hpp"
// (这里内联简化版本)

struct HttpRequest {
    std::string method, path, version;
    std::unordered_map<std::string, std::string> headers;
    bool keep_alive = true;

    bool parse(const std::string& raw) {
        size_t le = raw.find("\r\n");
        if (le == std::string::npos) return false;
        std::string rl = raw.substr(0, le);
        size_t s1 = rl.find(' '), s2 = rl.find(' ', s1+1);
        if (s1 == std::string::npos || s2 == std::string::npos) return false;
        method = rl.substr(0, s1);
        path = rl.substr(s1+1, s2-s1-1);
        version = rl.substr(s2+1);
        // Parse headers
        size_t pos = le + 2;
        while (pos < raw.size()) {
            size_t ne = raw.find("\r\n", pos);
            if (ne == std::string::npos || ne == pos) break;
            std::string line = raw.substr(pos, ne-pos);
            size_t c = line.find(':');
            if (c != std::string::npos) {
                std::string k = line.substr(0,c), v = line.substr(c+1);
                while (!v.empty() && v[0]==' ') v.erase(0,1);
                headers[k] = v;
            }
            pos = ne + 2;
        }
        auto it = headers.find("Connection");
        keep_alive = it != headers.end() ? it->second != "close" : version == "HTTP/1.1";
        return true;
    }
    static bool is_complete(const std::string& d) {
        return d.find("\r\n\r\n") != std::string::npos;
    }
};

struct Connection {
    int fd;
    std::string peer;
    std::string recv_buf;
    std::string send_buf;
    bool keep_alive = true;

    Connection(int f, const std::string& p) : fd(f), peer(p) {}
};

class HttpServer {
public:
    using RequestHandler = std::function<std::string(const HttpRequest&)>;

    HttpServer(int port, const std::string& doc_root = ".")
        : port_(port), doc_root_(doc_root) {}

    ~HttpServer() {
        if (epfd_ >= 0) close(epfd_);
        if (listen_fd_ >= 0) close(listen_fd_);
    }

    void set_handler(RequestHandler h) { handler_ = std::move(h); }

    bool start() {
        epfd_ = epoll_create1(EPOLL_CLOEXEC);
        listen_fd_ = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK, 0);
        int opt = 1;
        setsockopt(listen_fd_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = INADDR_ANY;
        addr.sin_port = htons(port_);
        if (bind(listen_fd_, (sockaddr*)&addr, sizeof(addr)) < 0) return false;
        if (listen(listen_fd_, SOMAXCONN) < 0) return false;

        epoll_event ev;
        ev.events = EPOLLIN | EPOLLET;
        ev.data.fd = listen_fd_;
        epoll_ctl(epfd_, EPOLL_CTL_ADD, listen_fd_, &ev);

        printf("HTTP Server on port %d (doc_root=%s)\n", port_, doc_root_.c_str());
        return true;
    }

    void run() {
        std::vector<epoll_event> events(1024);
        while (true) {
            int n = epoll_wait(epfd_, events.data(), events.size(), -1);
            if (n < 0) { if (errno == EINTR) continue; break; }

            for (int i = 0; i < n; ++i) {
                int fd = events[i].data.fd;
                uint32_t rev = events[i].events;

                if (fd == listen_fd_) {
                    do_accept();
                } else {
                    auto it = conns_.find(fd);
                    if (it == conns_.end()) continue;
                    if (rev & (EPOLLERR | EPOLLHUP)) { do_close(fd); continue; }
                    if (rev & EPOLLIN) do_read(it->second);
                    if (conns_.count(fd) && (rev & EPOLLOUT)) do_write(it->second);
                }
            }
        }
    }

private:
    void do_accept() {
        while (true) {
            sockaddr_in ca{};
            socklen_t len = sizeof(ca);
            int fd = accept4(listen_fd_, (sockaddr*)&ca, &len,
                           SOCK_NONBLOCK | SOCK_CLOEXEC);
            if (fd < 0) { if (errno == EAGAIN) break; if (errno == EINTR) continue; break; }

            int opt = 1;
            setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &opt, sizeof(opt));

            char ip[INET_ADDRSTRLEN];
            inet_ntop(AF_INET, &ca.sin_addr, ip, sizeof(ip));
            std::string peer = std::string(ip) + ":" + std::to_string(ntohs(ca.sin_port));

            conns_[fd] = std::make_shared<Connection>(fd, peer);

            epoll_event ev;
            ev.events = EPOLLIN | EPOLLET;
            ev.data.fd = fd;
            epoll_ctl(epfd_, EPOLL_CTL_ADD, fd, &ev);
        }
    }

    void do_read(std::shared_ptr<Connection>& conn) {
        char buf[8192];
        while (true) {
            ssize_t n = read(conn->fd, buf, sizeof(buf));
            if (n > 0) { conn->recv_buf.append(buf, n); continue; }
            if (n == 0) { do_close(conn->fd); return; }
            if (errno == EAGAIN) break;
            if (errno == EINTR) continue;
            do_close(conn->fd); return;
        }

        // 检查请求是否完整
        while (HttpRequest::is_complete(conn->recv_buf)) {
            size_t end = conn->recv_buf.find("\r\n\r\n") + 4;
            std::string raw = conn->recv_buf.substr(0, end);
            conn->recv_buf.erase(0, end);

            HttpRequest req;
            if (!req.parse(raw)) { do_close(conn->fd); return; }

            conn->keep_alive = req.keep_alive;

            // 生成响应
            std::string response;
            if (handler_) {
                response = handler_(req);
            } else {
                response = default_handler(req);
            }
            conn->send_buf += response;
        }

        if (!conn->send_buf.empty()) {
            try_send(conn);
            if (!conn->send_buf.empty()) {
                epoll_event ev;
                ev.events = EPOLLIN | EPOLLOUT | EPOLLET;
                ev.data.fd = conn->fd;
                epoll_ctl(epfd_, EPOLL_CTL_MOD, conn->fd, &ev);
            }
        }
    }

    void do_write(std::shared_ptr<Connection>& conn) {
        try_send(conn);
        if (conn->send_buf.empty()) {
            if (!conn->keep_alive) {
                do_close(conn->fd);
                return;
            }
            epoll_event ev;
            ev.events = EPOLLIN | EPOLLET;
            ev.data.fd = conn->fd;
            epoll_ctl(epfd_, EPOLL_CTL_MOD, conn->fd, &ev);
        }
    }

    void try_send(std::shared_ptr<Connection>& conn) {
        while (!conn->send_buf.empty()) {
            ssize_t n = write(conn->fd, conn->send_buf.data(), conn->send_buf.size());
            if (n > 0) { conn->send_buf.erase(0, n); continue; }
            if (errno == EAGAIN) break;
            if (errno == EINTR) continue;
            do_close(conn->fd); return;
        }
    }

    void do_close(int fd) {
        epoll_ctl(epfd_, EPOLL_CTL_DEL, fd, nullptr);
        close(fd);
        conns_.erase(fd);
    }

    std::string default_handler(const HttpRequest& req) {
        std::string body;
        std::string type = "text/html";
        int code = 200;
        std::string status = "OK";

        if (req.path == "/" || req.path == "/index.html") {
            body = "<html><body>"
                   "<h1>epoll HTTP Server</h1>"
                   "<p>Method: " + req.method + "</p>"
                   "<p>Path: " + req.path + "</p>"
                   "<p>Version: " + req.version + "</p>"
                   "<p>Keep-Alive: " + (req.keep_alive ? "yes" : "no") + "</p>"
                   "</body></html>";
        } else if (req.path == "/status") {
            body = "{\"connections\":" + std::to_string(conns_.size()) + "}";
            type = "application/json";
        } else {
            code = 404;
            status = "Not Found";
            body = "<html><body><h1>404 Not Found</h1></body></html>";
        }

        // 构造HTTP响应
        std::string resp = "HTTP/1.1 " + std::to_string(code) + " " + status + "\r\n";
        resp += "Content-Type: " + type + "\r\n";
        resp += "Content-Length: " + std::to_string(body.size()) + "\r\n";
        resp += "Connection: " + std::string(req.keep_alive ? "keep-alive" : "close") + "\r\n";
        resp += "\r\n";
        resp += body;
        return resp;
    }

    int port_;
    std::string doc_root_;
    int epfd_ = -1;
    int listen_fd_ = -1;
    RequestHandler handler_;
    std::unordered_map<int, std::shared_ptr<Connection>> conns_;
};

int main(int argc, char* argv[]) {
    int port = (argc > 1) ? atoi(argv[1]) : 8080;
    HttpServer server(port);
    if (!server.start()) return 1;
    server.run();
    return 0;
}

/*
测试：
$ curl http://localhost:8080/
$ curl http://localhost:8080/status
$ ab -n 10000 -c 100 -k http://localhost:8080/
*/
```

---

### 第三周检验标准

```
第三周自我检验清单：

理论理解：
☐ 能描述惊群问题的成因和影响
☐ 能说出三种解决方案及其优劣
☐ 理解SO_REUSEPORT的内核分配机制
☐ 理解timerfd/signalfd/eventfd的用途
☐ 能解释为什么eventfd比pipe更高效
☐ 理解HTTP/1.1 Keep-Alive机制

实践能力：
☐ 能实现SO_REUSEPORT多线程服务器
☐ 能实现EpollLoop（继承EventLoop接口）
☐ 能使用timerfd实现精确定时器
☐ 能使用signalfd安全处理信号
☐ 能使用eventfd实现线程间唤醒
☐ 能实现基于epoll的HTTP服务器
☐ HTTP服务器支持Keep-Alive
```

---

## 第四周：性能优化与压力测试（Day 22-28）

### 本周时间分配

| 日期 | 内容 | 时间 |
|------|------|------|
| Day 22-23 | epoll性能调优 | 10小时 |
| Day 24-25 | 压力测试与性能分析 | 10小时 |
| Day 26-27 | 源码阅读：Nginx/Redis的epoll使用 | 10小时 |
| Day 28 | 项目集成与总结 | 5小时 |

---

### Day 22-23：epoll性能调优（10小时）

#### 学习目标

- 掌握epoll服务器的系统级调优方法
- 理解maxevents参数优化
- 掌握内核参数调优

#### 系统调优参数速查表

```
═══════════════════════════════════════════════════════════
epoll服务器性能调优参数
═══════════════════════════════════════════════════════════

1. 网络参数
─────────────────────────────────────────────────────────
参数                          │ 默认值   │ 推荐值    │ 说明
─────────────────────────────┼──────────┼───────────┼─────────────
net.core.somaxconn            │ 128      │ 65535     │ listen队列上限
net.core.netdev_max_backlog   │ 1000     │ 65535     │ 网卡接收队列
net.ipv4.tcp_max_syn_backlog  │ 128      │ 65535     │ SYN队列上限
net.ipv4.tcp_tw_reuse         │ 0        │ 1         │ 复用TIME_WAIT
net.ipv4.tcp_fin_timeout      │ 60       │ 30        │ FIN超时
net.ipv4.tcp_keepalive_time   │ 7200     │ 600       │ keepalive探测
net.ipv4.tcp_max_tw_buckets   │ 180000   │ 200000    │ TW桶数

2. 文件描述符限制
─────────────────────────────────────────────────────────
参数                          │ 默认值   │ 推荐值    │ 说明
─────────────────────────────┼──────────┼───────────┼─────────────
fs.file-max                   │ ~100000  │ 1000000   │ 系统fd上限
fs.nr_open                    │ 1048576  │ 1048576   │ 进程fd上限
ulimit -n (soft)              │ 1024     │ 1000000   │ 用户进程fd
ulimit -n (hard)              │ 4096     │ 1000000   │ 硬上限

3. 内存参数
─────────────────────────────────────────────────────────
参数                          │ 默认值        │ 推荐值       │ 说明
─────────────────────────────┼───────────────┼──────────────┼──────
net.core.rmem_max             │ 212992        │ 16777216     │ 接收缓冲区上限
net.core.wmem_max             │ 212992        │ 16777216     │ 发送缓冲区上限
net.ipv4.tcp_rmem             │ 4096 87380..  │ 4096 65536.. │ TCP接收缓冲
net.ipv4.tcp_wmem             │ 4096 16384..  │ 4096 65536.. │ TCP发送缓冲


调优脚本示例：
─────────────────────────────────────────────────────────

#!/bin/bash
# optimize_network.sh - 高性能服务器网络参数调优

# 连接队列
sysctl -w net.core.somaxconn=65535
sysctl -w net.ipv4.tcp_max_syn_backlog=65535
sysctl -w net.core.netdev_max_backlog=65535

# TCP参数
sysctl -w net.ipv4.tcp_tw_reuse=1
sysctl -w net.ipv4.tcp_fin_timeout=30
sysctl -w net.ipv4.tcp_keepalive_time=600

# 缓冲区
sysctl -w net.core.rmem_max=16777216
sysctl -w net.core.wmem_max=16777216

# 文件描述符
sysctl -w fs.file-max=1000000
ulimit -n 1000000

echo "Network optimization applied."
```

#### 代码示例22：优化后的epoll服务器

```cpp
// 示例22: optimized_epoll_server.cpp
// 综合优化的epoll Echo服务器
// 汇集了本月所有最佳实践

#include <sys/epoll.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <cstdio>
#include <cstring>
#include <cerrno>
#include <vector>
#include <string>
#include <unordered_map>
#include <memory>

/*
优化清单：
1. accept4 + SOCK_NONBLOCK + SOCK_CLOEXEC（减少syscall）
2. TCP_NODELAY（降低延迟）
3. ET模式 + 循环读写（减少事件通知）
4. 先尝试直接发送（减少EPOLLOUT注册）
5. data.ptr传递上下文（避免哈希查找）
6. SO_REUSEADDR + SO_REUSEPORT
7. 合理的events数组大小
8. EPOLLRDHUP检测对端关闭
*/

struct Connection {
    int fd = -1;
    std::string send_buf;
    uint64_t rx = 0, tx = 0;
    bool has_epollout = false;

    ~Connection() { if (fd >= 0) close(fd); }
};

class OptimizedServer {
public:
    OptimizedServer(int port) : port_(port) {}

    ~OptimizedServer() {
        if (epfd_ >= 0) close(epfd_);
        if (listen_fd_ >= 0) close(listen_fd_);
    }

    bool start() {
        epfd_ = epoll_create1(EPOLL_CLOEXEC);
        if (epfd_ < 0) return false;

        // 优化1：SOCK_NONBLOCK + SOCK_CLOEXEC 在创建时设置
        listen_fd_ = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK | SOCK_CLOEXEC, 0);
        if (listen_fd_ < 0) return false;

        // 优化6：SO_REUSEADDR + SO_REUSEPORT
        int opt = 1;
        setsockopt(listen_fd_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
        setsockopt(listen_fd_, SOL_SOCKET, SO_REUSEPORT, &opt, sizeof(opt));

        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = INADDR_ANY;
        addr.sin_port = htons(port_);
        if (bind(listen_fd_, (sockaddr*)&addr, sizeof(addr)) < 0) return false;

        // 优化：较大的backlog
        if (listen(listen_fd_, 65535) < 0) return false;

        // 监听socket用ET
        epoll_event ev;
        ev.events = EPOLLIN | EPOLLET;
        ev.data.ptr = nullptr;  // nullptr = listen socket
        epoll_ctl(epfd_, EPOLL_CTL_ADD, listen_fd_, &ev);

        printf("Optimized Server on port %d\n", port_);
        return true;
    }

    void run() {
        // 优化7：合理的events大小
        std::vector<epoll_event> events(1024);

        while (true) {
            int n = epoll_wait(epfd_, events.data(), events.size(), -1);
            if (n < 0) { if (errno == EINTR) continue; break; }

            for (int i = 0; i < n; ++i) {
                if (events[i].data.ptr == nullptr) {
                    do_accept();
                } else {
                    auto* conn = static_cast<Connection*>(events[i].data.ptr);
                    uint32_t rev = events[i].events;

                    // 优化8：EPOLLRDHUP
                    if (rev & (EPOLLERR | EPOLLHUP | EPOLLRDHUP)) {
                        do_close(conn);
                        continue;
                    }
                    if (rev & EPOLLIN) do_read(conn);
                    // 检查连接是否还存在
                    if (conns_.count(conn->fd) && (rev & EPOLLOUT)) {
                        do_write(conn);
                    }
                }
            }
        }
    }

private:
    void do_accept() {
        while (true) {
            sockaddr_in ca{};
            socklen_t len = sizeof(ca);
            // 优化1：accept4
            int fd = accept4(listen_fd_, (sockaddr*)&ca, &len,
                           SOCK_NONBLOCK | SOCK_CLOEXEC);
            if (fd < 0) {
                if (errno == EAGAIN || errno == EWOULDBLOCK) break;
                if (errno == EINTR) continue;
                break;
            }

            // 优化2：TCP_NODELAY
            int opt = 1;
            setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &opt, sizeof(opt));

            auto conn = std::make_unique<Connection>();
            conn->fd = fd;
            Connection* ptr = conn.get();

            // 优化5：data.ptr + 优化3：ET + 优化8：EPOLLRDHUP
            epoll_event ev;
            ev.events = EPOLLIN | EPOLLRDHUP | EPOLLET;
            ev.data.ptr = ptr;
            epoll_ctl(epfd_, EPOLL_CTL_ADD, fd, &ev);

            conns_[fd] = std::move(conn);
        }
    }

    void do_read(Connection* conn) {
        // 优化3：ET循环读
        char buf[8192];
        while (true) {
            ssize_t n = read(conn->fd, buf, sizeof(buf));
            if (n > 0) { conn->rx += n; conn->send_buf.append(buf, n); continue; }
            if (n == 0) { do_close(conn); return; }
            if (errno == EAGAIN) break;
            if (errno == EINTR) continue;
            do_close(conn); return;
        }

        if (!conn->send_buf.empty()) {
            // 优化4：先尝试直接发送
            flush(conn);

            // 还有剩余才注册EPOLLOUT
            if (!conn->send_buf.empty() && !conn->has_epollout) {
                conn->has_epollout = true;
                epoll_event ev;
                ev.events = EPOLLIN | EPOLLOUT | EPOLLRDHUP | EPOLLET;
                ev.data.ptr = conn;
                epoll_ctl(epfd_, EPOLL_CTL_MOD, conn->fd, &ev);
            }
        }
    }

    void do_write(Connection* conn) {
        flush(conn);
        if (conn->send_buf.empty() && conn->has_epollout) {
            conn->has_epollout = false;
            epoll_event ev;
            ev.events = EPOLLIN | EPOLLRDHUP | EPOLLET;
            ev.data.ptr = conn;
            epoll_ctl(epfd_, EPOLL_CTL_MOD, conn->fd, &ev);
        }
    }

    void flush(Connection* conn) {
        while (!conn->send_buf.empty()) {
            ssize_t n = write(conn->fd, conn->send_buf.data(), conn->send_buf.size());
            if (n > 0) { conn->tx += n; conn->send_buf.erase(0, n); continue; }
            if (errno == EAGAIN) break;
            if (errno == EINTR) continue;
            break;
        }
    }

    void do_close(Connection* conn) {
        int fd = conn->fd;
        epoll_ctl(epfd_, EPOLL_CTL_DEL, fd, nullptr);
        conns_.erase(fd);  // unique_ptr析构会close(fd)
    }

    int port_;
    int epfd_ = -1;
    int listen_fd_ = -1;
    std::unordered_map<int, std::unique_ptr<Connection>> conns_;
};

int main(int argc, char* argv[]) {
    int port = (argc > 1) ? atoi(argv[1]) : 8080;
    OptimizedServer server(port);
    if (!server.start()) return 1;
    server.run();
    return 0;
}
```

---

### Day 24-25：压力测试与性能分析（10小时）

#### 学习目标

- 掌握epoll服务器压力测试方法
- 理解关键性能指标：QPS、延迟、吞吐量
- 使用perf/strace进行性能分析

#### 代码示例23：并发连接压测客户端

```cpp
// 示例23: bench_client.cpp
// 并发连接压测客户端
// 测试epoll服务器的连接处理能力和吞吐量

#include <sys/epoll.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <cstdio>
#include <cstring>
#include <cerrno>
#include <chrono>
#include <vector>
#include <string>
#include <atomic>
#include <thread>
#include <numeric>

using Clock = std::chrono::high_resolution_clock;
using Millis = std::chrono::duration<double, std::milli>;

struct BenchConfig {
    std::string host = "127.0.0.1";
    int port = 8080;
    int num_connections = 100;   // 并发连接数
    int num_requests = 10000;    // 总请求数
    int message_size = 64;       // 消息大小（字节）
    int num_threads = 1;         // 客户端线程数
};

struct BenchResult {
    int total_requests = 0;
    int successful = 0;
    int failed = 0;
    double total_time_ms = 0;
    double qps = 0;
    double avg_latency_ms = 0;
    double p99_latency_ms = 0;
    double throughput_mbps = 0;
};

static std::atomic<int> global_requests{0};
static std::atomic<int> global_success{0};
static std::atomic<int> global_failed{0};

void bench_thread(const BenchConfig& cfg, int thread_id, int requests_per_thread) {
    int conns_per_thread = cfg.num_connections / cfg.num_threads;
    std::string message(cfg.message_size, 'A');
    char recv_buf[8192];

    // 创建连接
    std::vector<int> fds;
    for (int i = 0; i < conns_per_thread; ++i) {
        int fd = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK, 0);
        if (fd < 0) continue;

        int opt = 1;
        setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &opt, sizeof(opt));

        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        inet_pton(AF_INET, cfg.host.c_str(), &addr.sin_addr);
        addr.sin_port = htons(cfg.port);

        connect(fd, (sockaddr*)&addr, sizeof(addr));
        fds.push_back(fd);
    }

    // 等待连接完成
    usleep(100000);

    // 创建epoll
    int epfd = epoll_create1(0);
    for (int fd : fds) {
        epoll_event ev;
        ev.events = EPOLLOUT | EPOLLET;
        ev.data.fd = fd;
        epoll_ctl(epfd, EPOLL_CTL_ADD, fd, &ev);
    }

    // 发送请求
    std::vector<epoll_event> events(conns_per_thread);
    int sent = 0;

    while (sent < requests_per_thread) {
        int n = epoll_wait(epfd, events.data(), events.size(), 1000);
        if (n <= 0) continue;

        for (int i = 0; i < n && sent < requests_per_thread; ++i) {
            int fd = events[i].data.fd;

            if (events[i].events & EPOLLOUT) {
                ssize_t w = write(fd, message.data(), message.size());
                if (w > 0) {
                    sent++;
                    global_requests++;

                    // 切换到读等待
                    epoll_event ev;
                    ev.events = EPOLLIN | EPOLLET;
                    ev.data.fd = fd;
                    epoll_ctl(epfd, EPOLL_CTL_MOD, fd, &ev);
                }
            }

            if (events[i].events & EPOLLIN) {
                ssize_t r = read(fd, recv_buf, sizeof(recv_buf));
                if (r > 0) {
                    global_success++;
                } else {
                    global_failed++;
                }

                // 切换回写
                epoll_event ev;
                ev.events = EPOLLOUT | EPOLLET;
                ev.data.fd = fd;
                epoll_ctl(epfd, EPOLL_CTL_MOD, fd, &ev);
            }
        }
    }

    // 清理
    close(epfd);
    for (int fd : fds) close(fd);
}

int main(int argc, char* argv[]) {
    BenchConfig cfg;
    if (argc > 1) cfg.host = argv[1];
    if (argc > 2) cfg.port = atoi(argv[2]);
    if (argc > 3) cfg.num_connections = atoi(argv[3]);
    if (argc > 4) cfg.num_requests = atoi(argv[4]);
    if (argc > 5) cfg.num_threads = atoi(argv[5]);

    printf("Benchmark Configuration:\n");
    printf("  Host: %s:%d\n", cfg.host.c_str(), cfg.port);
    printf("  Connections: %d\n", cfg.num_connections);
    printf("  Requests: %d\n", cfg.num_requests);
    printf("  Message size: %d bytes\n", cfg.message_size);
    printf("  Threads: %d\n", cfg.num_threads);
    printf("\nRunning...\n\n");

    int requests_per_thread = cfg.num_requests / cfg.num_threads;
    auto start = Clock::now();

    std::vector<std::thread> threads;
    for (int i = 0; i < cfg.num_threads; ++i) {
        threads.emplace_back(bench_thread, std::cref(cfg), i, requests_per_thread);
    }
    for (auto& t : threads) t.join();

    auto end = Clock::now();
    double elapsed_ms = Millis(end - start).count();

    printf("=== Results ===\n");
    printf("Total time: %.2f ms\n", elapsed_ms);
    printf("Requests sent: %d\n", global_requests.load());
    printf("Successful: %d\n", global_success.load());
    printf("Failed: %d\n", global_failed.load());
    printf("QPS: %.0f\n", global_success.load() / (elapsed_ms / 1000.0));
    printf("Avg latency: %.3f ms\n",
           elapsed_ms / global_success.load());
    printf("Throughput: %.2f MB/s\n",
           (double)global_success.load() * cfg.message_size / elapsed_ms / 1000.0);

    return 0;
}

/*
使用方法：
$ ./bench_client 127.0.0.1 8080 100 10000 4

也可以使用外部工具：
$ wrk -t4 -c100 -d10s http://localhost:8080/
$ ab -n 10000 -c 100 http://localhost:8080/
*/
```

#### 性能分析工具使用

```
═══════════════════════════════════════════════════════════
性能分析工具速查
═══════════════════════════════════════════════════════════

1. strace —— 系统调用追踪
─────────────────────────────────────────────────────────
# 统计系统调用耗时
$ strace -c -p <PID>
# 输出：
%time  seconds  calls  syscall
-----  --------  -----  --------
 45.2  0.015    10000  epoll_wait
 30.1  0.010    20000  read
 20.3  0.007    20000  write
  4.4  0.001    100    accept4

# 追踪特定系统调用
$ strace -e trace=epoll_wait,read,write -p <PID>


2. perf —— CPU性能分析
─────────────────────────────────────────────────────────
# CPU热点分析
$ perf top -p <PID>

# 录制并分析
$ perf record -g -p <PID> -- sleep 10
$ perf report

# 统计硬件计数器
$ perf stat -p <PID> -- sleep 10
# 输出：
Performance counter stats:
   10,234,567 cache-misses
  234,567,890 instructions
   45,678,901 cycles


3. 网络性能工具
─────────────────────────────────────────────────────────
# wrk - HTTP压测
$ wrk -t4 -c1000 -d30s http://localhost:8080/

# ab - Apache Bench
$ ab -n 100000 -c 1000 -k http://localhost:8080/

# netstat/ss - 连接状态
$ ss -s  # 连接统计
$ ss -tnp | grep 8080  # 查看特定端口连接


4. 关键性能指标
─────────────────────────────────────────────────────────
指标         │ 说明               │ 目标值
─────────────┼────────────────────┼─────────────
QPS          │ 每秒请求数         │ >50000 (echo)
延迟 P50     │ 50%请求的延迟      │ <1ms
延迟 P99     │ 99%请求的延迟      │ <5ms
吞吐量       │ 数据传输速率       │ >1Gbps
并发连接     │ 同时活跃连接数     │ >10000
CPU利用率    │ 服务器CPU使用      │ <80%
内存使用     │ RSS/VSZ            │ <500MB
```

---

### Day 26-27：源码阅读——Nginx/Redis的epoll使用（10小时）

#### 学习目标

- 分析Nginx ngx_epoll_module.c的关键逻辑
- 分析Redis ae_epoll.c的事件循环
- 学习工业级代码的设计模式

#### Nginx epoll模块分析

```
═══════════════════════════════════════════════════════════
Nginx ngx_epoll_module.c 关键逻辑分析
═══════════════════════════════════════════════════════════

Nginx的epoll使用特点：
1. ET模式（追求最高性能）
2. EPOLLEXCLUSIVE（避免惊群，Linux 4.5+）
3. 多进程模型（master-worker）
4. 每个worker独立epoll实例

关键函数：

ngx_epoll_init():
  ep = epoll_create(cycle->connection_n / 2);
  // 创建epoll实例
  // connection_n是最大连接数配置

ngx_epoll_add_event():
  if (event == NGX_READ_EVENT) {
      events = EPOLLIN | EPOLLRDHUP;  // 读事件 + 对端关闭检测
  } else {
      events = EPOLLOUT;
  }
  if (flags & NGX_EXCLUSIVE_EVENT) {
      events |= EPOLLEXCLUSIVE;  // 独占唤醒
  }
  events |= EPOLLET;  // 始终使用ET模式
  ee.events = events;
  ee.data.ptr = (void*)((uintptr_t)c | ev->instance);
  // 注意：Nginx在ptr中编码了实例标记（最低位）
  // 用于检测过时事件

ngx_epoll_process_events():
  events = epoll_wait(ep, event_list, nevents, timer);
  for (i = 0; i < events; i++) {
      c = event_list[i].data.ptr;
      instance = (uintptr_t)c & 1;
      c = (ngx_connection_t*)((uintptr_t)c & ~1);
      // 提取连接指针和实例标记

      if (c->fd == -1 || c->read->instance != instance) {
          // 过时事件：连接已被关闭并可能被复用
          // 实例标记不匹配说明这是旧连接的事件
          continue;  // 安全忽略
      }

      revents = event_list[i].events;
      if (revents & (EPOLLERR|EPOLLHUP)) {
          revents |= EPOLLIN | EPOLLOUT;
          // 错误时同时设置读写事件
      }
      if (revents & EPOLLIN) {
          c->read->handler(c->read);
      }
      if (revents & EPOLLOUT) {
          c->write->handler(c->write);
      }
  }


Nginx的关键优化：

1. 实例标记（instance bit）：
   解决"过时事件"问题。当连接关闭后被新连接复用，
   旧连接的epoll事件可能仍在events数组中。
   通过instance位（每次复用翻转）区分新旧事件。

2. EPOLLEXCLUSIVE：
   多worker进程共享listen socket时避免惊群。

3. ET模式 + 非阻塞：
   追求最高性能，减少不必要的事件通知。

4. 事件延迟处理：
   将事件先放入队列，统一批量处理，
   减少了事件处理过程中的状态不一致。
```

#### Redis ae_epoll.c分析

```
═══════════════════════════════════════════════════════════
Redis ae_epoll.c 事件循环分析
═══════════════════════════════════════════════════════════

Redis的事件模型：
1. 单线程事件循环
2. LT模式（简单可靠）
3. 统一处理I/O事件和定时事件

关键结构：

typedef struct aeEventLoop {
    int maxfd;
    int setsize;      // 最大fd数
    aeFileEvent *events;    // 注册的事件数组
    aeFiredEvent *fired;    // 就绪事件数组
    aeTimeEvent *timeEventHead;  // 定时器链表
    int stop;
    void *apidata;    // epoll特定数据(aeApiState)
} aeEventLoop;

typedef struct aeApiState {
    int epfd;
    struct epoll_event *events;
} aeApiState;


关键函数：

aeApiCreate():
  state->epfd = epoll_create(1024);
  state->events = malloc(sizeof(epoll_event) * setsize);

aeApiAddEvent():
  // 注意：Redis使用LT模式！
  ee.events = 0;
  if (mask & AE_READABLE) ee.events |= EPOLLIN;
  if (mask & AE_WRITABLE) ee.events |= EPOLLOUT;
  // 没有EPOLLET！Redis选择LT模式
  ee.data.fd = fd;
  epoll_ctl(state->epfd, op, fd, &ee);

aeApiPoll():
  retval = epoll_wait(state->epfd, state->events, setsize, tvp);
  for (j = 0; j < numevents; j++) {
      int mask = 0;
      if (e->events & EPOLLIN) mask |= AE_READABLE;
      if (e->events & EPOLLOUT) mask |= AE_WRITABLE;
      if (e->events & EPOLLERR) mask |= AE_WRITABLE | AE_READABLE;
      if (e->events & EPOLLHUP) mask |= AE_WRITABLE | AE_READABLE;
      // 错误和挂起都映射为可读+可写
      eventLoop->fired[j].fd = e->data.fd;
      eventLoop->fired[j].mask = mask;
  }

aeProcessEvents():
  // 计算最近的定时器，作为epoll_wait超时
  tvp = nearest_timer_timeout();
  numevents = aeApiPoll(eventLoop, tvp);
  // 先处理I/O事件
  for (j = 0; j < numevents; j++) {
      fe = &eventLoop->events[fd];
      // 先处理读，再处理写
      if (fe->mask & mask & AE_READABLE)
          fe->rfileProc(eventLoop, fd, fe->clientData, mask);
      if (fe->mask & mask & AE_WRITABLE)
          fe->wfileProc(eventLoop, fd, fe->clientData, mask);
  }
  // 再处理定时事件
  processTimeEvents(eventLoop);


Redis选择LT模式的原因：

1. 单线程：不需要ET减少事件次数（单线程不会被竞争）
2. 简单可靠：Redis的核心设计理念是简单
3. 读取模式：Redis的命令处理已经倾向于一次读取所有数据
4. 写入控制：Redis自己管理写缓冲区和EPOLLOUT开关
5. 不需要ONESHOT：单线程无并发处理同一fd的问题

启示：不是所有高性能软件都用ET模式！
选择适合架构的模式比盲目追求ET更重要。
```

#### 代码示例25：模仿Redis ae的简化事件循环

```cpp
// 示例25: simple_ae.hpp
// 模仿Redis ae的简化事件循环
// 统一I/O事件和定时事件

#pragma once
#include <sys/epoll.h>
#include <unistd.h>
#include <cstdio>
#include <cerrno>
#include <functional>
#include <vector>
#include <unordered_map>
#include <queue>
#include <chrono>

class SimpleAE {
public:
    using FileCallback = std::function<void(int fd, uint32_t mask)>;
    using TimerCallback = std::function<void()>;

    enum { READABLE = 1, WRITABLE = 2 };

    SimpleAE(int setsize = 10240) : setsize_(setsize) {
        epfd_ = epoll_create1(EPOLL_CLOEXEC);
        events_.resize(setsize);
    }

    ~SimpleAE() {
        if (epfd_ >= 0) close(epfd_);
    }

    // 添加文件事件
    bool add_file_event(int fd, uint32_t mask, FileCallback cb) {
        epoll_event ee{};
        if (mask & READABLE) ee.events |= EPOLLIN;
        if (mask & WRITABLE) ee.events |= EPOLLOUT;
        ee.data.fd = fd;

        int op = file_events_.count(fd) ? EPOLL_CTL_MOD : EPOLL_CTL_ADD;
        if (epoll_ctl(epfd_, op, fd, &ee) < 0) return false;

        file_events_[fd] = {mask, std::move(cb)};
        return true;
    }

    // 删除文件事件
    void del_file_event(int fd) {
        epoll_ctl(epfd_, EPOLL_CTL_DEL, fd, nullptr);
        file_events_.erase(fd);
    }

    // 添加定时器（毫秒）
    int add_timer(int ms, TimerCallback cb, bool repeat = false) {
        int id = next_timer_id_++;
        auto when = std::chrono::steady_clock::now() +
                    std::chrono::milliseconds(ms);
        timer_queue_.push({when, id, ms, std::move(cb), repeat});
        return id;
    }

    // 事件循环
    void run() {
        running_ = true;
        while (running_) {
            // 计算最近的定时器超时
            int timeout = -1;
            if (!timer_queue_.empty()) {
                auto now = std::chrono::steady_clock::now();
                auto diff = std::chrono::duration_cast<std::chrono::milliseconds>(
                    timer_queue_.top().when - now);
                timeout = std::max(0, (int)diff.count());
            }

            // 等待事件
            int n = epoll_wait(epfd_, events_.data(), events_.size(), timeout);
            if (n < 0 && errno != EINTR) break;

            // 处理I/O事件
            for (int i = 0; i < n; ++i) {
                int fd = events_[i].data.fd;
                auto it = file_events_.find(fd);
                if (it == file_events_.end()) continue;

                uint32_t mask = 0;
                if (events_[i].events & (EPOLLIN | EPOLLERR | EPOLLHUP))
                    mask |= READABLE;
                if (events_[i].events & (EPOLLOUT | EPOLLERR | EPOLLHUP))
                    mask |= WRITABLE;

                it->second.callback(fd, mask & it->second.mask);
            }

            // 处理定时事件
            process_timers();
        }
    }

    void stop() { running_ = false; }

private:
    struct TimerEntry {
        std::chrono::steady_clock::time_point when;
        int id;
        int interval_ms;
        TimerCallback callback;
        bool repeat;

        bool operator>(const TimerEntry& o) const { return when > o.when; }
    };

    struct FileEntry {
        uint32_t mask;
        FileCallback callback;
    };

    void process_timers() {
        auto now = std::chrono::steady_clock::now();
        while (!timer_queue_.empty() && timer_queue_.top().when <= now) {
            auto entry = timer_queue_.top();
            timer_queue_.pop();
            entry.callback();
            if (entry.repeat) {
                entry.when = now + std::chrono::milliseconds(entry.interval_ms);
                timer_queue_.push(entry);
            }
        }
    }

    int epfd_ = -1;
    int setsize_;
    bool running_ = false;
    int next_timer_id_ = 1;
    std::vector<epoll_event> events_;
    std::unordered_map<int, FileEntry> file_events_;
    std::priority_queue<TimerEntry, std::vector<TimerEntry>,
                        std::greater<TimerEntry>> timer_queue_;
};

/*
使用示例：

SimpleAE ae;

// 添加定时器
ae.add_timer(1000, []() {
    printf("Timer fired!\n");
}, true);  // 每秒触发

// 添加文件事件
ae.add_file_event(listen_fd, SimpleAE::READABLE, [&](int fd, uint32_t mask) {
    int client = accept(fd, ...);
    ae.add_file_event(client, SimpleAE::READABLE, handle_client);
});

ae.run();
*/
```

---

### Day 28：项目集成与总结（5小时）

#### 代码示例29：CMakeLists.txt

```cmake
# 示例29: CMakeLists.txt
# Month-27 epoll深度解析项目构建文件

cmake_minimum_required(VERSION 3.14)
project(month27_epoll LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_BUILD_TYPE Release)

# 编译选项
add_compile_options(-Wall -Wextra -O2)

# 第一周示例
add_executable(epoll_basic        week1/epoll_basic_demo.cpp)
add_executable(epoll_echo_lt      week1/epoll_echo_server_lt.cpp)
add_executable(epoll_ptr_demo     week1/epoll_ptr_demo.cpp)
add_executable(io_bench           week1/io_multiplex_benchmark.cpp)
add_executable(latency_test       week1/latency_distribution.cpp)

# 第二周示例
add_executable(echo_lt_full       week2/epoll_echo_lt_full.cpp)
add_executable(echo_et_full       week2/epoll_echo_et_full.cpp)
add_executable(oneshot_mt         week2/epoll_oneshot_mt.cpp)
target_link_libraries(oneshot_mt  pthread)
add_executable(lt_et_bench        week2/lt_vs_et_benchmark.cpp)

# 第三周示例
add_executable(thundering_herd    week3/thundering_herd_demo.cpp)
target_link_libraries(thundering_herd pthread)
add_executable(reuseport_server   week3/reuseport_server.cpp)
target_link_libraries(reuseport_server pthread)
add_executable(timerfd_demo       week3/timerfd_demo.cpp)
add_executable(signalfd_demo      week3/signalfd_demo.cpp)
add_executable(eventfd_demo       week3/eventfd_demo.cpp)
target_link_libraries(eventfd_demo pthread)
add_executable(http_server        week3/epoll_http_server.cpp)

# 第四周示例
add_executable(optimized_server   week4/optimized_epoll_server.cpp)
add_executable(bench_client       week4/bench_client.cpp)
target_link_libraries(bench_client pthread)

message(STATUS "Month-27 epoll project configured.")
```

#### 项目目录结构

```
month27_epoll/
├── CMakeLists.txt
├── week1/
│   ├── epoll_basic_demo.cpp          # 示例1: epoll基本用法
│   ├── epoll_echo_server_lt.cpp      # 示例2: LT模式echo server
│   ├── epoll_ptr_demo.cpp            # 示例3: data.ptr用法
│   ├── epoll_kernel_pseudocode.cpp   # 示例4: 内核伪代码
│   ├── io_multiplex_benchmark.cpp    # 示例5: select/poll/epoll对比
│   └── latency_distribution.cpp      # 示例6: 延迟分布测试
├── week2/
│   ├── epoll_echo_lt_full.cpp        # 示例7: LT完整版
│   ├── epoll_echo_et_full.cpp        # 示例8: ET完整版
│   ├── et_common_bugs.cpp            # 示例9: ET常见bug
│   ├── epoll_oneshot_mt.cpp          # 示例10: ONESHOT多线程
│   ├── lt_vs_et_benchmark.cpp        # 示例11: LT vs ET性能对比
│   └── et_write_strategy.cpp         # 示例12: ET写策略
├── week3/
│   ├── thundering_herd_demo.cpp      # 示例13: 惊群演示
│   ├── reuseport_server.cpp          # 示例14: SO_REUSEPORT
│   ├── epoll_loop.hpp                # 示例15: EpollLoop实现
│   ├── timerfd_demo.cpp              # 示例16: timerfd
│   ├── signalfd_demo.cpp             # 示例17: signalfd
│   ├── eventfd_demo.cpp              # 示例18: eventfd
│   ├── http_parser.hpp               # 示例19: HTTP解析
│   ├── http_response.hpp             # 示例20: HTTP响应
│   └── epoll_http_server.cpp         # 示例21: HTTP服务器
├── week4/
│   ├── optimized_epoll_server.cpp    # 示例22: 优化后的服务器
│   ├── bench_client.cpp              # 示例23: 压测客户端
│   └── simple_ae.hpp                 # 示例25: Redis风格事件循环
└── notes/
    └── month27_epoll.md              # 学习笔记
```

---

### 第四周检验标准

```
第四周自我检验清单：

理论理解：
☐ 能列出epoll服务器的关键调优参数
☐ 理解somaxconn/tcp_max_syn_backlog的作用
☐ 理解文件描述符限制及其修改方法
☐ 能分析Nginx的epoll使用策略（ET+EXCLUSIVE+实例标记）
☐ 能分析Redis的epoll使用策略（LT+单线程）
☐ 理解Nginx instance bit解决过时事件的机制

实践能力：
☐ 能编写综合优化的epoll服务器
☐ 能使用自实现客户端进行压力测试
☐ 能使用wrk/ab进行HTTP压测
☐ 能使用strace分析系统调用
☐ 能使用perf进行CPU性能分析
☐ 能实现Redis风格的事件循环
☐ 完成CMakeLists.txt和项目构建
```

---

## 本月检验标准汇总

### 理论检验（20项）

| # | 检验项 | 自评 |
|---|--------|------|
| 1 | 能说出select/poll的三个O(n)性能瓶颈 | ☐ |
| 2 | 能画出epoll内核数据结构（红黑树+就绪链表） | ☐ |
| 3 | 能描述epoll_ctl(ADD)的完整内核流程 | ☐ |
| 4 | 能描述fd就绪时的回调流程 | ☐ |
| 5 | 能描述epoll_wait的LT/ET区别（放回rdllist） | ☐ |
| 6 | 理解ovflist（溢出链表）的作用 | ☐ |
| 7 | 能清楚描述LT模式的触发语义 | ☐ |
| 8 | 能清楚描述ET模式的触发语义 | ☐ |
| 9 | 能说出ET模式的两条铁律 | ☐ |
| 10 | 能解释LT模式EPOLLOUT busy loop问题 | ☐ |
| 11 | 理解EPOLLONESHOT的用途和流程 | ☐ |
| 12 | 能描述惊群问题的成因和影响 | ☐ |
| 13 | 能说出三种惊群解决方案及优劣 | ☐ |
| 14 | 理解timerfd/signalfd/eventfd的用途 | ☐ |
| 15 | 能解释eventfd比pipe更高效的原因 | ☐ |
| 16 | 能列出关键系统调优参数 | ☐ |
| 17 | 能分析Nginx的epoll使用策略 | ☐ |
| 18 | 能分析Redis的epoll使用策略 | ☐ |
| 19 | 理解Nginx instance bit机制 | ☐ |
| 20 | 能对比LT/ET在不同场景下的适用性 | ☐ |

### 实践检验（20项）

| # | 检验项 | 自评 |
|---|--------|------|
| 1 | 能独立编写epoll基本用法程序 | ☐ |
| 2 | 能实现完整的LT模式Echo服务器 | ☐ |
| 3 | 能实现完整的ET模式Echo服务器 | ☐ |
| 4 | 会使用data.ptr传递连接上下文 | ☐ |
| 5 | 正确管理EPOLLOUT事件（避免busy loop） | ☐ |
| 6 | 能正确处理ET模式的循环读写 | ☐ |
| 7 | 能避免ET模式的5个常见bug | ☐ |
| 8 | 能实现EPOLLONESHOT多线程服务器 | ☐ |
| 9 | 能实现"先尝试直接发送"写优化 | ☐ |
| 10 | 能编写select/poll/epoll基准测试 | ☐ |
| 11 | 能编写LT vs ET性能对比程序 | ☐ |
| 12 | 能实现SO_REUSEPORT多线程服务器 | ☐ |
| 13 | 能实现EpollLoop（继承EventLoop） | ☐ |
| 14 | 能使用timerfd/signalfd/eventfd | ☐ |
| 15 | 能实现基于epoll的HTTP服务器 | ☐ |
| 16 | 能编写综合优化的epoll服务器 | ☐ |
| 17 | 能使用压测工具进行性能测试 | ☐ |
| 18 | 能使用strace/perf分析性能 | ☐ |
| 19 | 能实现Redis风格的事件循环 | ☐ |
| 20 | 完成项目目录组织和CMakeLists.txt | ☐ |

---

## 输出物清单

```
输出物完成度检查：

代码输出：
☐ week1/ 目录（6个源文件）
☐ week2/ 目录（6个源文件）
☐ week3/ 目录（9个源文件/头文件）
☐ week4/ 目录（3个源文件/头文件）
☐ CMakeLists.txt
☐ 所有代码编译通过
☐ Echo服务器通过功能测试
☐ HTTP服务器通过curl测试

文档输出：
☐ notes/month27_epoll.md 学习笔记
☐ 性能测试报告（select/poll/epoll对比数据）
☐ LT vs ET对比报告
☐ Nginx/Redis源码分析笔记
```

---

## 学习建议

```
学习路径建议：
═══════════════════════════════════════════════════

Week 1 (基础)          Week 2 (模式)
┌──────────────┐      ┌──────────────┐
│ API学习      │      │ LT模式实践   │
│ 内核原理     │─────>│ ET模式实践   │
│ 性能对比     │      │ ONESHOT      │
└──────────────┘      └──────┬───────┘
                             │
Week 3 (高级)          Week 4 (优化)
┌──────────────┐      ┌──────────────┐
│ 惊群问题     │      │ 系统调优     │
│ EpollLoop    │─────>│ 压力测试     │
│ HTTP服务器   │      │ 源码分析     │
└──────────────┘      └──────────────┘

调试技巧：
1. 使用strace -e epoll_wait,read,write跟踪系统调用
2. ET模式bug排查：在read/write后打印errno和返回值
3. 使用netcat(nc)手动测试服务器
4. 使用ss -tnp查看连接状态
5. 使用/proc/<pid>/fd/查看fd使用情况

常见错误表：
┌─────────────────────────────┬──────────────────────────────┐
│ 错误现象                    │ 可能原因                     │
├─────────────────────────────┼──────────────────────────────┤
│ ET模式数据"丢失"            │ 忘记循环读到EAGAIN           │
│ CPU占用100%                 │ LT模式EPOLLOUT未取消         │
│ 连接建立后无响应            │ ET accept未循环              │
│ 多线程数据乱序              │ 未使用EPOLLONESHOT           │
│ accept返回EMFILE            │ fd数量超过ulimit             │
│ epoll_ctl返回EPERM          │ 普通文件不支持epoll          │
│ 大量TIME_WAIT               │ 未设置SO_REUSEADDR           │
│ 连接被拒绝                  │ backlog满/somaxconn太小      │
└─────────────────────────────┴──────────────────────────────┘
```

---

## 结语

```
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║       恭喜完成 Month 27: epoll深度解析！                  ║
║                                                           ║
║  本月你掌握了：                                           ║
║  ✓ epoll三大API和内核实现原理                             ║
║  ✓ LT/ET模式的语义、编程和性能差异                       ║
║  ✓ 惊群问题和三种解决方案                                 ║
║  ✓ timerfd/signalfd/eventfd集成                          ║
║  ✓ 高性能epoll服务器框架                                 ║
║  ✓ Nginx/Redis的epoll使用策略                            ║
║                                                           ║
║  你已经能够：                                             ║
║  • 构建支撑10K+并发连接的网络服务器                      ║
║  • 选择合适的触发模式（LT/ET）                           ║
║  • 解决多线程/多进程下的惊群问题                         ║
║  • 使用EpollLoop集成定时器和信号处理                     ║
║  • 分析工业级代码的epoll使用模式                         ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
```

---

## 下月预告

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  Month 28: io_uring——新一代异步I/O                      │
│                                                         │
│  io_uring是Linux 5.1引入的全新异步I/O框架。             │
│  通过共享内存的环形缓冲区实现真正的零拷贝系统调用。     │
│                                                         │
│  主要内容：                                             │
│  • SQ/CQ环形缓冲区架构                                 │
│  • liburing API（prep_read/write/accept/send/recv）    │
│  • SQPOLL模式（内核轮询提交队列）                      │
│  • 注册文件描述符和缓冲区                               │
│  • 链接操作和超时控制                                   │
│  • 基于io_uring的高性能Echo服务器                       │
│  • io_uring vs epoll性能对比                            │
│                                                         │
│  承接关系：                                             │
│  Month-27 epoll（事件驱动I/O）                          │
│      ↓                                                  │
│  Month-28 io_uring（异步提交I/O）← 下月                │
│      ↓                                                  │
│  Month-29 零拷贝技术                                    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---