# Month 36: 第三年总结与综合项目

## 本月概览

```
┌─────────────────────────────────────────────────────────────────┐
│                    Month 36: 综合网络库项目                       │
├─────────────────────────────────────────────────────────────────┤
│  第三年学习的收官之作，整合所有网络编程知识                          │
│                                                                 │
│  Month 25-33          Month 34           Month 35               │
│  ┌─────────┐      ┌───────────┐      ┌───────────┐             │
│  │ 网络基础 │  +   │ RPC框架   │  +   │ 序列化协议 │              │
│  │ IO模型  │      │ 客户端/服务端│     │ Protobuf  │             │
│  │ epoll   │      │ 连接管理   │      │ FlatBuffers│            │
│  └────┬────┘      └─────┬─────┘      └─────┬─────┘             │
│       │                 │                  │                    │
│       └────────────────┴──────────────────┘                    │
│                         │                                       │
│                         ▼                                       │
│              ┌─────────────────────┐                           │
│              │   NetLib 网络库      │                           │
│              │  ┌───────────────┐  │                           │
│              │  │  Service Layer │  │  ← RPC服务、负载均衡        │
│              │  ├───────────────┤  │                           │
│              │  │ Protocol Layer │  │  ← 编解码、序列化           │
│              │  ├───────────────┤  │                           │
│              │  │ Network Layer  │  │  ← 事件循环、连接管理        │
│              │  └───────────────┘  │                           │
│              └─────────────────────┘                           │
│                                                                 │
│  学习时间: 140小时 (4周 × 35小时)                                 │
│  输出物: 15个核心文件 + 完整测试套件                               │
└─────────────────────────────────────────────────────────────────┘
```

## 学习目标

### 知识整合目标
- [ ] 系统复盘第三年网络编程核心知识
- [ ] 理解工业级网络库的设计理念
- [ ] 掌握分层架构的设计与实现

### 技术实践目标
- [ ] 实现完整的事件驱动网络库
- [ ] 支持多种序列化协议
- [ ] 实现高性能RPC框架

### 工程能力目标
- [ ] 编写完整的单元测试和集成测试
- [ ] 进行性能基准测试和优化
- [ ] 撰写专业的技术文档

---

## Week 1: 第三年知识复盘与架构设计（35小时）

### 本周目标
```
┌─────────────────────────────────────────────────────────────┐
│  Week 1: 知识复盘 + 架构设计                                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Day 1-2: 网络编程核心知识回顾                                │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐        │
│  │ Socket  │→ │ IO复用  │→ │ 非阻塞IO │→ │ 事件驱动 │        │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘        │
│                                                             │
│  Day 3-4: RPC与序列化知识整合                                 │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │   RPC协议设计    │ ←→ │   序列化方案     │                │
│  │ 请求/响应模型    │    │ Protobuf/FlatBuf │               │
│  └─────────────────┘    └─────────────────┘                │
│                                                             │
│  Day 5-7: 综合网络库架构设计                                  │
│  ┌─────────────────────────────────────────┐               │
│  │              NetLib 架构                 │               │
│  │  ┌─────────┬─────────┬─────────┐        │               │
│  │  │ Service │ Protocol│ Network │        │               │
│  │  └─────────┴─────────┴─────────┘        │               │
│  └─────────────────────────────────────────┘               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 每日任务分解

| Day | 时间 | 上午任务(2.5h) | 下午任务(2.5h) | 输出物 |
|-----|------|---------------|---------------|--------|
| 1 | 5h | Socket API复习、TCP状态机 | IO多路复用对比(select/poll/epoll) | review_notes.md |
| 2 | 5h | 非阻塞IO实现原理 | 事件驱动模型分析 | io_model_summary.md |
| 3 | 5h | RPC协议设计回顾 | 服务治理模式总结 | rpc_review.md |
| 4 | 5h | 序列化方案对比分析 | 性能优化策略总结 | serialization_review.md |
| 5 | 5h | 网络库需求分析 | 分层架构设计 | architecture_design.md |
| 6 | 5h | 模块接口定义 | 依赖关系梳理 | interface_design.md |
| 7 | 5h | 插件机制设计 | 架构评审与完善 | plugin_design.md |

---

### Day 1-2: 网络编程核心知识回顾

#### Socket API 复习

```cpp
/**
 * socket_review.hpp
 * 第三年网络编程知识复盘 - Socket API核心概念
 */

#pragma once

#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <string>
#include <cstring>
#include <stdexcept>

namespace netlib {
namespace review {

/**
 * TCP状态机复习
 *
 *                              ┌─────────────┐
 *                              │   CLOSED    │
 *                              └──────┬──────┘
 *                    ┌────────────────┼────────────────┐
 *                    │ 主动打开        │                │ 被动打开
 *                    │ send SYN       │                │
 *                    ▼                │                ▼
 *              ┌───────────┐         │         ┌───────────┐
 *              │ SYN_SENT  │         │         │  LISTEN   │
 *              └─────┬─────┘         │         └─────┬─────┘
 *                    │ recv SYN+ACK  │               │ recv SYN
 *                    │ send ACK      │               │ send SYN+ACK
 *                    ▼               │               ▼
 *              ┌───────────┐         │         ┌───────────┐
 *              │ESTABLISHED│◄────────┴────────►│ SYN_RCVD  │
 *              └─────┬─────┘   recv ACK        └───────────┘
 *                    │
 *         ┌──────────┴──────────┐
 *         │ 主动关闭             │ 被动关闭
 *         │ send FIN            │ recv FIN
 *         ▼                     ▼
 *   ┌───────────┐         ┌───────────┐
 *   │ FIN_WAIT_1│         │CLOSE_WAIT │
 *   └─────┬─────┘         └─────┬─────┘
 *         │ recv ACK            │ send FIN
 *         ▼                     ▼
 *   ┌───────────┐         ┌───────────┐
 *   │ FIN_WAIT_2│         │ LAST_ACK  │
 *   └─────┬─────┘         └─────┬─────┘
 *         │ recv FIN            │ recv ACK
 *         │ send ACK            │
 *         ▼                     ▼
 *   ┌───────────┐         ┌───────────┐
 *   │ TIME_WAIT │         │  CLOSED   │
 *   └─────┬─────┘         └───────────┘
 *         │ 2MSL timeout
 *         ▼
 *   ┌───────────┐
 *   │  CLOSED   │
 *   └───────────┘
 */

// Socket选项配置总结
struct SocketOptions {
    // TCP_NODELAY: 禁用Nagle算法，减少小包延迟
    static void setTcpNoDelay(int fd, bool on) {
        int optval = on ? 1 : 0;
        ::setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &optval, sizeof(optval));
    }

    // SO_REUSEADDR: 允许地址重用，快速重启服务
    static void setReuseAddr(int fd, bool on) {
        int optval = on ? 1 : 0;
        ::setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &optval, sizeof(optval));
    }

    // SO_REUSEPORT: 允许端口重用，多进程监听同一端口
    static void setReusePort(int fd, bool on) {
        int optval = on ? 1 : 0;
        ::setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &optval, sizeof(optval));
    }

    // SO_KEEPALIVE: TCP保活机制
    static void setKeepAlive(int fd, bool on) {
        int optval = on ? 1 : 0;
        ::setsockopt(fd, SOL_SOCKET, SO_KEEPALIVE, &optval, sizeof(optval));
    }

    // 设置发送/接收缓冲区大小
    static void setBufferSize(int fd, int sendSize, int recvSize) {
        ::setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &sendSize, sizeof(sendSize));
        ::setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &recvSize, sizeof(recvSize));
    }

    // 设置非阻塞模式
    static void setNonBlocking(int fd, bool on) {
        int flags = ::fcntl(fd, F_GETFL, 0);
        if (on) {
            flags |= O_NONBLOCK;
        } else {
            flags &= ~O_NONBLOCK;
        }
        ::fcntl(fd, F_SETFL, flags);
    }
};

/**
 * IO多路复用对比
 *
 * ┌────────────┬─────────────┬─────────────┬─────────────────┐
 * │   特性      │   select    │    poll     │     epoll       │
 * ├────────────┼─────────────┼─────────────┼─────────────────┤
 * │ 数据结构    │ fd_set位图   │ pollfd数组  │ 红黑树+就绪链表  │
 * │ 最大连接数  │ 1024(FD限制) │ 无限制      │ 无限制          │
 * │ 复杂度      │ O(n)        │ O(n)        │ O(1)            │
 * │ 内核拷贝    │ 每次全量拷贝 │ 每次全量拷贝 │ 共享内存mmap    │
 * │ 触发模式    │ 水平触发     │ 水平触发    │ LT/ET           │
 * │ 适用场景    │ 跨平台      │ 跨平台      │ Linux高并发     │
 * └────────────┴─────────────┴─────────────┴─────────────────┘
 */

/**
 * epoll使用模式复习
 *
 * 水平触发(LT - Level Triggered):
 * - 只要fd可读/可写就会触发通知
 * - 可以分多次读取数据
 * - 编程简单，不容易丢数据
 *
 * 边缘触发(ET - Edge Triggered):
 * - 只有状态变化时才触发通知
 * - 必须一次性读完所有数据
 * - 效率高，但编程复杂
 * - 必须配合非阻塞IO使用
 */

// epoll事件处理示例
class EpollDemo {
public:
    /**
     * ET模式下的正确读取方式
     * 必须循环读取直到EAGAIN
     */
    static ssize_t readAllET(int fd, std::string& buffer) {
        char buf[4096];
        ssize_t total = 0;

        while (true) {
            ssize_t n = ::read(fd, buf, sizeof(buf));
            if (n > 0) {
                buffer.append(buf, n);
                total += n;
            } else if (n == 0) {
                // 对端关闭
                return total;
            } else {
                if (errno == EAGAIN || errno == EWOULDBLOCK) {
                    // 没有更多数据了
                    break;
                } else if (errno == EINTR) {
                    // 被信号中断，继续读
                    continue;
                } else {
                    // 发生错误
                    return -1;
                }
            }
        }
        return total;
    }

    /**
     * LT模式下的读取方式
     * 可以只读一次，下次还会通知
     */
    static ssize_t readOnceLT(int fd, char* buf, size_t len) {
        ssize_t n = ::read(fd, buf, len);
        if (n < 0) {
            if (errno == EINTR) {
                return 0;  // 下次再读
            }
        }
        return n;
    }
};

} // namespace review
} // namespace netlib
```

#### 事件驱动模型复习

```cpp
/**
 * event_model_review.hpp
 * 事件驱动模型核心概念复习
 */

#pragma once

#include <functional>
#include <memory>
#include <map>

namespace netlib {
namespace review {

/**
 * Reactor模式复习
 *
 * ┌──────────────────────────────────────────────────────────────┐
 * │                      Reactor 模式                            │
 * ├──────────────────────────────────────────────────────────────┤
 * │                                                              │
 * │   ┌─────────────┐     事件注册      ┌─────────────────┐     │
 * │   │  事件处理器  │ ──────────────► │   同步事件分离器   │     │
 * │   │  (Handler)  │                  │  (epoll_wait)   │     │
 * │   └──────┬──────┘                  └────────┬────────┘     │
 * │          │                                   │              │
 * │          │ 回调                              │ 就绪事件     │
 * │          │                                   ▼              │
 * │          │                          ┌────────────────┐     │
 * │          └─────────────────────────│    Reactor     │     │
 * │                                     │   (事件循环)    │     │
 * │                                     └────────────────┘     │
 * │                                                              │
 * │   特点:                                                      │
 * │   - 单线程处理多个IO事件                                      │
 * │   - 同步非阻塞                                               │
 * │   - 事件驱动，高效利用CPU                                     │
 * └──────────────────────────────────────────────────────────────┘
 *
 *
 * ┌──────────────────────────────────────────────────────────────┐
 * │                     Proactor 模式                            │
 * ├──────────────────────────────────────────────────────────────┤
 * │                                                              │
 * │   ┌─────────────┐     发起异步IO    ┌─────────────────┐     │
 * │   │  事件处理器  │ ──────────────► │   异步操作处理器  │     │
 * │   │  (Handler)  │                  │  (Async Proc)   │     │
 * │   └──────┬──────┘                  └────────┬────────┘     │
 * │          │                                   │              │
 * │          │ 完成回调                          │ 完成通知     │
 * │          │                                   ▼              │
 * │          │                          ┌────────────────┐     │
 * │          └─────────────────────────│   Proactor     │     │
 * │                                     │   (完成分发)    │     │
 * │                                     └────────────────┘     │
 * │                                                              │
 * │   特点:                                                      │
 * │   - 真正的异步IO                                             │
 * │   - IO操作由内核完成                                         │
 * │   - Windows IOCP实现                                        │
 * └──────────────────────────────────────────────────────────────┘
 */

/**
 * 多Reactor多线程模型
 *
 * ┌────────────────────────────────────────────────────────────────┐
 * │                  Multi-Reactor Multi-Thread                    │
 * ├────────────────────────────────────────────────────────────────┤
 * │                                                                │
 * │                    ┌─────────────────┐                        │
 * │                    │  Main Reactor   │                        │
 * │                    │  (Acceptor)     │                        │
 * │                    └────────┬────────┘                        │
 * │                             │ 分发新连接                       │
 * │              ┌──────────────┼──────────────┐                  │
 * │              ▼              ▼              ▼                  │
 * │      ┌────────────┐ ┌────────────┐ ┌────────────┐            │
 * │      │Sub Reactor1│ │Sub Reactor2│ │Sub Reactor3│            │
 * │      │ (IO线程1)  │ │ (IO线程2)  │ │ (IO线程3)  │            │
 * │      └─────┬──────┘ └─────┬──────┘ └─────┬──────┘            │
 * │            │              │              │                    │
 * │      ┌─────┴─────┐  ┌─────┴─────┐  ┌─────┴─────┐            │
 * │      │conn1 conn2│  │conn3 conn4│  │conn5 conn6│            │
 * │      └───────────┘  └───────────┘  └───────────┘            │
 * │                                                                │
 * │   特点:                                                        │
 * │   - Main Reactor只负责accept                                   │
 * │   - Sub Reactors处理已连接socket的IO                           │
 * │   - 充分利用多核CPU                                            │
 * └────────────────────────────────────────────────────────────────┘
 */

// 简化的Reactor示意
class ReactorConcept {
public:
    using EventCallback = std::function<void()>;

    // 注册事件处理器
    void registerHandler(int fd, uint32_t events, EventCallback cb) {
        handlers_[fd] = std::move(cb);
        // 实际需要调用epoll_ctl注册
    }

    // 事件循环
    void loop() {
        while (running_) {
            // epoll_wait等待事件
            // 分发事件到对应handler
            for (auto& [fd, cb] : handlers_) {
                // 如果fd就绪，调用回调
                cb();
            }
        }
    }

private:
    bool running_ = true;
    std::map<int, EventCallback> handlers_;
};

} // namespace review
} // namespace netlib
```

---

### Day 3-4: RPC与序列化知识整合

#### RPC协议设计回顾

```cpp
/**
 * rpc_review.hpp
 * RPC协议设计核心要点复盘
 */

#pragma once

#include <cstdint>
#include <string>
#include <vector>
#include <functional>

namespace netlib {
namespace review {

/**
 * RPC调用流程回顾
 *
 * ┌────────────────────────────────────────────────────────────────┐
 * │                        RPC 调用流程                            │
 * ├────────────────────────────────────────────────────────────────┤
 * │                                                                │
 * │   Client                                    Server             │
 * │   ┌─────────────┐                    ┌─────────────┐          │
 * │   │ Application │                    │ Application │          │
 * │   └──────┬──────┘                    └──────▲──────┘          │
 * │          │ 1.调用                           │ 6.返回          │
 * │          ▼                                  │                 │
 * │   ┌─────────────┐                    ┌──────┴──────┐          │
 * │   │  Client     │                    │   Server    │          │
 * │   │   Stub      │                    │   Skeleton  │          │
 * │   └──────┬──────┘                    └──────▲──────┘          │
 * │          │ 2.序列化                         │ 5.反序列化       │
 * │          ▼                                  │                 │
 * │   ┌─────────────┐                    ┌──────┴──────┐          │
 * │   │  Codec      │                    │   Codec     │          │
 * │   │ (编码器)    │                    │  (解码器)    │          │
 * │   └──────┬──────┘                    └──────▲──────┘          │
 * │          │ 3.发送                           │ 4.接收          │
 * │          ▼                                  │                 │
 * │   ┌─────────────┐                    ┌──────┴──────┐          │
 * │   │  Network    │ ══════════════════│   Network   │          │
 * │   │  Transport  │    TCP/UDP        │  Transport  │          │
 * │   └─────────────┘                    └─────────────┘          │
 * │                                                                │
 * └────────────────────────────────────────────────────────────────┘
 */

/**
 * RPC协议头设计要点
 */
struct RpcHeader {
    uint32_t magic;        // 魔数，用于识别协议
    uint8_t  version;      // 协议版本
    uint8_t  type;         // 消息类型(请求/响应/心跳)
    uint8_t  codec;        // 序列化方式
    uint8_t  compress;     // 压缩方式
    uint32_t requestId;    // 请求ID，用于匹配请求响应
    uint32_t bodyLength;   // 消息体长度
    uint16_t timeout;      // 超时时间(秒)
    uint16_t reserved;     // 保留字段

    static constexpr uint32_t MAGIC = 0x4E455442; // "NETB"
    static constexpr size_t HEADER_SIZE = 20;
};

/**
 * 服务治理要点回顾
 *
 * ┌─────────────────────────────────────────────────────────────┐
 * │                      服务治理核心模式                        │
 * ├─────────────────────────────────────────────────────────────┤
 * │                                                             │
 * │  1. 服务注册与发现                                           │
 * │  ┌─────────────────────────────────────────┐               │
 * │  │           注册中心 (Registry)            │               │
 * │  │  ┌─────────────────────────────────┐    │               │
 * │  │  │ service: UserService            │    │               │
 * │  │  │ instances:                      │    │               │
 * │  │  │   - 192.168.1.10:8080          │    │               │
 * │  │  │   - 192.168.1.11:8080          │    │               │
 * │  │  │   - 192.168.1.12:8080          │    │               │
 * │  │  └─────────────────────────────────┘    │               │
 * │  └─────────────────────────────────────────┘               │
 * │                                                             │
 * │  2. 负载均衡策略                                             │
 * │  ┌─────────────┬─────────────┬─────────────┐               │
 * │  │  Round Robin│   Random    │  Weighted   │               │
 * │  │   轮询       │   随机      │   加权       │               │
 * │  └─────────────┴─────────────┴─────────────┘               │
 * │  ┌─────────────┬─────────────┬─────────────┐               │
 * │  │  Least Conn │   IP Hash   │ Consistent  │               │
 * │  │   最少连接   │   IP哈希    │   一致性哈希  │               │
 * │  └─────────────┴─────────────┴─────────────┘               │
 * │                                                             │
 * │  3. 容错机制                                                 │
 * │  - 超时重试: 请求超时后自动重试                               │
 * │  - 熔断降级: 错误率过高时熔断                                 │
 * │  - 限流保护: 保护服务不被过载                                 │
 * │                                                             │
 * └─────────────────────────────────────────────────────────────┘
 */

// 负载均衡策略接口
class LoadBalancer {
public:
    virtual ~LoadBalancer() = default;
    virtual std::string select(const std::vector<std::string>& endpoints) = 0;
};

// 轮询策略
class RoundRobinBalancer : public LoadBalancer {
public:
    std::string select(const std::vector<std::string>& endpoints) override {
        if (endpoints.empty()) return "";
        size_t idx = counter_++ % endpoints.size();
        return endpoints[idx];
    }
private:
    std::atomic<size_t> counter_{0};
};

} // namespace review
} // namespace netlib
```

#### 序列化方案对比

```cpp
/**
 * serialization_review.hpp
 * 序列化方案对比分析
 */

#pragma once

#include <string>
#include <vector>
#include <chrono>

namespace netlib {
namespace review {

/**
 * 序列化方案对比
 *
 * ┌────────────────────────────────────────────────────────────────┐
 * │                      序列化方案对比表                          │
 * ├────────────┬──────────┬──────────┬──────────┬────────────────┤
 * │   方案      │  体积    │  速度    │ 跨语言   │    特点         │
 * ├────────────┼──────────┼──────────┼──────────┼────────────────┤
 * │ JSON       │   大     │   慢     │   好     │ 可读性好        │
 * │ XML        │   很大   │   很慢   │   好     │ 配置文件常用    │
 * │ Protobuf   │   小     │   快     │   好     │ 工业标准        │
 * │ FlatBuffers│   中     │   极快   │   好     │ 零拷贝          │
 * │ MessagePack│   小     │   快     │   好     │ 二进制JSON      │
 * │ 自定义      │   最小   │   极快   │   差     │ 灵活控制        │
 * └────────────┴──────────┴──────────┴──────────┴────────────────┘
 *
 *
 * Protobuf Wire Format 回顾:
 *
 * ┌─────────────────────────────────────────────────────────────┐
 * │  Field = (field_number << 3) | wire_type                   │
 * ├─────────────────────────────────────────────────────────────┤
 * │  Wire Type │ 含义                    │ 类型                │
 * │     0      │ Varint                 │ int32, int64, bool  │
 * │     1      │ 64-bit                 │ fixed64, double     │
 * │     2      │ Length-delimited       │ string, bytes, msg  │
 * │     5      │ 32-bit                 │ fixed32, float      │
 * └─────────────────────────────────────────────────────────────┘
 *
 * Varint 编码示例:
 *   数字 300 的编码过程:
 *   300 = 0b100101100
 *   分成7位一组: 0000010 0101100
 *   从低位开始，除最后一组外设置MSB=1:
 *   结果: 0xAC 0x02
 *
 *
 * FlatBuffers 内存布局:
 *
 * ┌─────────────────────────────────────────────────────────────┐
 * │              FlatBuffer 内存结构                            │
 * ├─────────────────────────────────────────────────────────────┤
 * │                                                             │
 * │   Buffer Start                                              │
 * │   ▼                                                         │
 * │   ┌──────────┬──────────┬──────────┬──────────────────────┐│
 * │   │root_offset│ VTable   │  Table   │      Strings/Vectors ││
 * │   │ (4 bytes)│(variable)│(variable)│      (variable)       ││
 * │   └──────────┴──────────┴──────────┴──────────────────────┘│
 * │                                                             │
 * │   VTable结构:                                               │
 * │   ┌──────────┬──────────┬──────────┬──────────┐            │
 * │   │vtable_size│table_size│field0_off│field1_off│...        │
 * │   │ (2 bytes)│ (2 bytes)│ (2 bytes)│ (2 bytes)│            │
 * │   └──────────┴──────────┴──────────┴──────────┘            │
 * │                                                             │
 * │   零拷贝访问: 直接通过偏移量访问数据，无需反序列化             │
 * └─────────────────────────────────────────────────────────────┘
 */

// 序列化性能测试框架
class SerializationBenchmark {
public:
    struct Result {
        std::string name;
        size_t dataSize;          // 序列化后大小(bytes)
        double serializeTimeUs;    // 序列化时间(微秒)
        double deserializeTimeUs;  // 反序列化时间(微秒)
        double throughputMBps;     // 吞吐量(MB/s)
    };

    template<typename Serializer, typename Data>
    static Result benchmark(const std::string& name,
                           const Data& data,
                           int iterations = 10000) {
        Result result;
        result.name = name;

        // 预热
        auto serialized = Serializer::serialize(data);
        Serializer::deserialize(serialized);

        // 序列化测试
        auto start = std::chrono::high_resolution_clock::now();
        for (int i = 0; i < iterations; ++i) {
            serialized = Serializer::serialize(data);
        }
        auto end = std::chrono::high_resolution_clock::now();
        result.serializeTimeUs = std::chrono::duration<double, std::micro>(end - start).count() / iterations;
        result.dataSize = serialized.size();

        // 反序列化测试
        start = std::chrono::high_resolution_clock::now();
        for (int i = 0; i < iterations; ++i) {
            Serializer::deserialize(serialized);
        }
        end = std::chrono::high_resolution_clock::now();
        result.deserializeTimeUs = std::chrono::duration<double, std::micro>(end - start).count() / iterations;

        // 计算吞吐量
        result.throughputMBps = (result.dataSize * 1000000.0) /
                                (result.serializeTimeUs * 1024 * 1024);

        return result;
    }
};

} // namespace review
} // namespace netlib
```

---

### Day 5-7: 综合网络库架构设计

#### 整体架构设计

```cpp
/**
 * architecture_design.hpp
 * NetLib 网络库整体架构设计
 */

#pragma once

/**
 * NetLib 分层架构设计
 *
 * ┌─────────────────────────────────────────────────────────────────┐
 * │                       Application Layer                         │
 * │                      (用户应用代码)                              │
 * └─────────────────────────────────────────────────────────────────┘
 *                              │
 *                              ▼
 * ┌─────────────────────────────────────────────────────────────────┐
 * │                       Service Layer                             │
 * ├─────────────────────────────────────────────────────────────────┤
 * │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
 * │  │ RpcService  │  │LoadBalancer │  │ ServiceReg  │             │
 * │  │  RPC服务    │  │  负载均衡   │  │  服务注册   │             │
 * │  └─────────────┘  └─────────────┘  └─────────────┘             │
 * └─────────────────────────────────────────────────────────────────┘
 *                              │
 *                              ▼
 * ┌─────────────────────────────────────────────────────────────────┐
 * │                      Protocol Layer                             │
 * ├─────────────────────────────────────────────────────────────────┤
 * │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
 * │  │   Codec     │  │ Serializer  │  │  Compress   │             │
 * │  │  编解码器   │  │   序列化    │  │    压缩     │             │
 * │  └─────────────┘  └─────────────┘  └─────────────┘             │
 * │  ┌─────────────────────────────────────────────────┐           │
 * │  │              MessageFraming                      │           │
 * │  │               消息分帧                           │           │
 * │  └─────────────────────────────────────────────────┘           │
 * └─────────────────────────────────────────────────────────────────┘
 *                              │
 *                              ▼
 * ┌─────────────────────────────────────────────────────────────────┐
 * │                       Network Layer                             │
 * ├─────────────────────────────────────────────────────────────────┤
 * │  ┌─────────────────────────────────────────────────┐           │
 * │  │                   EventLoop                      │           │
 * │  │                   事件循环                       │           │
 * │  └─────────────────────────────────────────────────┘           │
 * │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
 * │  │  Channel    │  │TcpConnection│  │   Buffer    │             │
 * │  │  事件通道   │  │  TCP连接    │  │   缓冲区    │             │
 * │  └─────────────┘  └─────────────┘  └─────────────┘             │
 * │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
 * │  │  Acceptor   │  │  Connector  │  │ TimerQueue  │             │
 * │  │  接收器     │  │  连接器     │  │  定时器队列 │             │
 * │  └─────────────┘  └─────────────┘  └─────────────┘             │
 * └─────────────────────────────────────────────────────────────────┘
 *                              │
 *                              ▼
 * ┌─────────────────────────────────────────────────────────────────┐
 * │                    Platform Abstraction                         │
 * ├─────────────────────────────────────────────────────────────────┤
 * │  ┌─────────────────────┐  ┌─────────────────────┐              │
 * │  │   Linux (epoll)     │  │   macOS (kqueue)    │              │
 * │  └─────────────────────┘  └─────────────────────┘              │
 * └─────────────────────────────────────────────────────────────────┘
 */

namespace netlib {

// 前向声明
class EventLoop;
class Channel;
class Buffer;
class TcpConnection;
class TcpServer;
class TcpClient;
class Codec;
class RpcService;

/**
 * 核心接口定义
 */

// 连接回调类型
using ConnectionCallback = std::function<void(const std::shared_ptr<TcpConnection>&)>;
using MessageCallback = std::function<void(const std::shared_ptr<TcpConnection>&, Buffer*)>;
using WriteCompleteCallback = std::function<void(const std::shared_ptr<TcpConnection>&)>;
using CloseCallback = std::function<void(const std::shared_ptr<TcpConnection>&)>;

// 定时器回调
using TimerCallback = std::function<void()>;

// 编解码器接口
class CodecInterface {
public:
    virtual ~CodecInterface() = default;
    virtual void encode(const Message& msg, Buffer* output) = 0;
    virtual bool decode(Buffer* input, Message* msg) = 0;
};

// 序列化器接口
class SerializerInterface {
public:
    virtual ~SerializerInterface() = default;
    virtual std::string serialize(const void* data, size_t size) = 0;
    virtual bool deserialize(const std::string& data, void* output) = 0;
};

/**
 * 模块依赖关系
 *
 * ┌─────────────────────────────────────────────────────────────┐
 * │                      模块依赖图                             │
 * ├─────────────────────────────────────────────────────────────┤
 * │                                                             │
 * │   TcpServer ─────────────────────────────────┐             │
 * │       │                                       │             │
 * │       │ 使用                                  │ 使用       │
 * │       ▼                                       ▼             │
 * │   Acceptor ──────────► EventLoop ◄────── TimerQueue       │
 * │       │                    │                               │
 * │       │ 创建               │ 管理                          │
 * │       ▼                    ▼                               │
 * │   TcpConnection ◄────── Channel                            │
 * │       │                    │                               │
 * │       │ 使用               │ 使用                          │
 * │       ▼                    ▼                               │
 * │    Buffer            Poller(epoll/kqueue)                  │
 * │                                                             │
 * └─────────────────────────────────────────────────────────────┘
 */

/**
 * 线程模型设计
 *
 * ┌─────────────────────────────────────────────────────────────────┐
 * │                   多Reactor线程模型                             │
 * ├─────────────────────────────────────────────────────────────────┤
 * │                                                                 │
 * │        Main Thread                                              │
 * │   ┌─────────────────────┐                                      │
 * │   │    Main Reactor     │                                      │
 * │   │   ┌───────────────┐ │                                      │
 * │   │   │   Acceptor    │ │  ← 只负责accept新连接                │
 * │   │   └───────────────┘ │                                      │
 * │   └──────────┬──────────┘                                      │
 * │              │                                                  │
 * │              │ 分发连接 (Round-Robin)                          │
 * │              │                                                  │
 * │   ┌──────────┼──────────┬──────────────┐                      │
 * │   │          │          │              │                        │
 * │   ▼          ▼          ▼              ▼                        │
 * │ ┌──────┐  ┌──────┐  ┌──────┐     ┌──────┐                     │
 * │ │Sub   │  │Sub   │  │Sub   │     │Sub   │   IO Threads        │
 * │ │Loop 1│  │Loop 2│  │Loop 3│ ... │Loop N│                     │
 * │ └──┬───┘  └──┬───┘  └──┬───┘     └──┬───┘                     │
 * │    │         │         │            │                          │
 * │ ┌──┴──┐   ┌──┴──┐   ┌──┴──┐     ┌──┴──┐                       │
 * │ │conns│   │conns│   │conns│     │conns│                       │
 * │ └─────┘   └─────┘   └─────┘     └─────┘                       │
 * │                                                                 │
 * │ 每个Sub EventLoop运行在独立线程中                              │
 * │ 处理已分配连接的所有IO事件                                      │
 * └─────────────────────────────────────────────────────────────────┘
 */

} // namespace netlib
```

#### 插件机制设计

```cpp
/**
 * plugin_design.hpp
 * 可扩展插件机制设计
 */

#pragma once

#include <string>
#include <memory>
#include <unordered_map>
#include <functional>

namespace netlib {

/**
 * 插件系统设计
 *
 * ┌─────────────────────────────────────────────────────────────┐
 * │                      插件系统架构                           │
 * ├─────────────────────────────────────────────────────────────┤
 * │                                                             │
 * │   ┌─────────────────────────────────────────────────┐      │
 * │   │              Plugin Registry                     │      │
 * │   │               (插件注册中心)                     │      │
 * │   └───────────────────────┬─────────────────────────┘      │
 * │                           │                                 │
 * │         ┌─────────────────┼─────────────────┐              │
 * │         ▼                 ▼                 ▼              │
 * │   ┌───────────┐    ┌───────────┐    ┌───────────┐         │
 * │   │ Serializer │    │   Codec   │    │ Compress  │         │
 * │   │  Plugin    │    │  Plugin   │    │  Plugin   │         │
 * │   └─────┬─────┘    └─────┬─────┘    └─────┬─────┘         │
 * │         │                │                │                 │
 * │   ┌─────┴─────┐    ┌─────┴─────┐    ┌─────┴─────┐         │
 * │   │ Protobuf  │    │   RPC     │    │   LZ4     │         │
 * │   │ FlatBuf   │    │   HTTP    │    │   ZSTD    │         │
 * │   │ JSON      │    │ WebSocket │    │   GZIP    │         │
 * │   └───────────┘    └───────────┘    └───────────┘         │
 * │                                                             │
 * └─────────────────────────────────────────────────────────────┘
 */

// 插件接口基类
class Plugin {
public:
    virtual ~Plugin() = default;
    virtual std::string name() const = 0;
    virtual std::string version() const = 0;
    virtual bool initialize() = 0;
    virtual void shutdown() = 0;
};

// 序列化插件接口
class SerializerPlugin : public Plugin {
public:
    virtual std::string serialize(const void* data, const std::string& typeName) = 0;
    virtual bool deserialize(const std::string& data, void* output, const std::string& typeName) = 0;
};

// 编解码插件接口
class CodecPlugin : public Plugin {
public:
    virtual void encode(const void* msg, Buffer* output) = 0;
    virtual bool decode(Buffer* input, void* msg) = 0;
};

// 压缩插件接口
class CompressPlugin : public Plugin {
public:
    virtual std::string compress(const std::string& data) = 0;
    virtual std::string decompress(const std::string& data) = 0;
};

// 插件注册中心
template<typename PluginType>
class PluginRegistry {
public:
    static PluginRegistry& instance() {
        static PluginRegistry registry;
        return registry;
    }

    // 注册插件
    void registerPlugin(const std::string& name,
                       std::shared_ptr<PluginType> plugin) {
        plugins_[name] = std::move(plugin);
    }

    // 获取插件
    std::shared_ptr<PluginType> getPlugin(const std::string& name) {
        auto it = plugins_.find(name);
        if (it != plugins_.end()) {
            return it->second;
        }
        return nullptr;
    }

    // 获取所有插件名
    std::vector<std::string> getPluginNames() const {
        std::vector<std::string> names;
        for (const auto& [name, _] : plugins_) {
            names.push_back(name);
        }
        return names;
    }

private:
    PluginRegistry() = default;
    std::unordered_map<std::string, std::shared_ptr<PluginType>> plugins_;
};

// 便捷类型定义
using SerializerRegistry = PluginRegistry<SerializerPlugin>;
using CodecRegistry = PluginRegistry<CodecPlugin>;
using CompressRegistry = PluginRegistry<CompressPlugin>;

// 插件自动注册宏
#define REGISTER_SERIALIZER(name, PluginClass) \
    static bool _registered_##PluginClass = []() { \
        SerializerRegistry::instance().registerPlugin( \
            name, std::make_shared<PluginClass>()); \
        return true; \
    }()

#define REGISTER_CODEC(name, PluginClass) \
    static bool _registered_##PluginClass = []() { \
        CodecRegistry::instance().registerPlugin( \
            name, std::make_shared<PluginClass>()); \
        return true; \
    }()

} // namespace netlib
```

---

### Week 1 输出物清单

| 文件 | 说明 | 完成状态 |
|------|------|---------|
| `review/socket_review.hpp` | Socket API与TCP状态机复习 | [ ] |
| `review/event_model_review.hpp` | 事件驱动模型分析 | [ ] |
| `review/rpc_review.hpp` | RPC协议设计回顾 | [ ] |
| `review/serialization_review.hpp` | 序列化方案对比 | [ ] |
| `design/architecture_design.hpp` | 整体架构设计 | [ ] |
| `design/plugin_design.hpp` | 插件机制设计 | [ ] |
| `notes/week1_review.md` | 本周学习笔记 | [ ] |

### Week 1 验收标准

- [ ] 能够清晰讲解TCP三次握手四次挥手
- [ ] 能够对比select/poll/epoll的优劣
- [ ] 能够解释Reactor与Proactor模式的区别
- [ ] 能够设计RPC协议头格式
- [ ] 能够对比各序列化方案的适用场景
- [ ] 完成网络库的分层架构设计
- [ ] 设计清晰的模块接口
- [ ] 设计可扩展的插件机制

---

## Week 2: 网络库核心层实现（35小时）

### 本周目标
```
┌─────────────────────────────────────────────────────────────────┐
│  Week 2: Network Layer 核心实现                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Day 8-10: 事件循环与IO层                                        │
│  ┌───────────────────────────────────────────────────────┐     │
│  │  EventLoop ──► Poller ──► Channel ──► Handler        │     │
│  └───────────────────────────────────────────────────────┘     │
│                                                                 │
│  Day 11-12: 连接管理层                                           │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐        │
│  │  Acceptor   │    │TcpConnection│    │  Connector  │        │
│  │  被动连接    │    │   连接封装   │    │  主动连接   │        │
│  └─────────────┘    └─────────────┘    └─────────────┘        │
│                                                                 │
│  Day 13-14: 定时器与线程模型                                      │
│  ┌─────────────────────────────────────────────────────┐       │
│  │  TimerQueue + EventLoopThreadPool                    │       │
│  │  定时任务     多Reactor线程池                         │       │
│  └─────────────────────────────────────────────────────┘       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 每日任务分解

| Day | 时间 | 上午任务(2.5h) | 下午任务(2.5h) | 输出物 |
|-----|------|---------------|---------------|--------|
| 8 | 5h | Poller抽象层(epoll/kqueue) | EventLoop核心循环 | poller.hpp, event_loop.hpp |
| 9 | 5h | Channel事件分发 | 跨线程任务唤醒 | channel.hpp |
| 10 | 5h | Buffer读写缓冲区 | 高水位回调机制 | buffer.hpp |
| 11 | 5h | TcpConnection实现 | 连接状态管理 | tcp_connection.hpp |
| 12 | 5h | Acceptor新连接接入 | Connector主动连接 | acceptor.hpp, connector.hpp |
| 13 | 5h | TimerQueue定时器 | 定时任务调度 | timer_queue.hpp |
| 14 | 5h | EventLoopThread | EventLoopThreadPool | event_loop_thread_pool.hpp |

---

### Day 8-10: 事件循环与IO层

#### Poller抽象层

```cpp
/**
 * poller.hpp
 * IO多路复用抽象层 - 支持epoll(Linux)和kqueue(macOS/BSD)
 */

#pragma once

#include <vector>
#include <map>
#include <memory>
#include <chrono>

#ifdef __linux__
#include <sys/epoll.h>
#elif defined(__APPLE__) || defined(__FreeBSD__)
#include <sys/event.h>
#endif

namespace netlib {

class Channel;
class EventLoop;

/**
 * Poller架构
 *
 * ┌─────────────────────────────────────────────────────────────┐
 * │                        Poller                               │
 * │                      (抽象基类)                              │
 * └───────────────────────────┬─────────────────────────────────┘
 *                             │
 *              ┌──────────────┴──────────────┐
 *              ▼                             ▼
 * ┌─────────────────────────┐  ┌─────────────────────────┐
 * │      EpollPoller        │  │      KqueuePoller       │
 * │       (Linux)           │  │     (macOS/BSD)         │
 * └─────────────────────────┘  └─────────────────────────┘
 */

// 抽象Poller基类
class Poller {
public:
    using ChannelList = std::vector<Channel*>;

    explicit Poller(EventLoop* loop) : ownerLoop_(loop) {}
    virtual ~Poller() = default;

    // 核心接口
    virtual void poll(int timeoutMs, ChannelList* activeChannels) = 0;
    virtual void updateChannel(Channel* channel) = 0;
    virtual void removeChannel(Channel* channel) = 0;

    // 工厂方法 - 根据平台创建对应实现
    static std::unique_ptr<Poller> createDefaultPoller(EventLoop* loop);

    // 检查channel是否在当前poller中
    bool hasChannel(Channel* channel) const {
        auto it = channels_.find(channel->fd());
        return it != channels_.end() && it->second == channel;
    }

protected:
    EventLoop* ownerLoop_;
    std::map<int, Channel*> channels_;
};

#ifdef __linux__
/**
 * EpollPoller - Linux epoll实现
 */
class EpollPoller : public Poller {
public:
    explicit EpollPoller(EventLoop* loop);
    ~EpollPoller() override;

    void poll(int timeoutMs, ChannelList* activeChannels) override;
    void updateChannel(Channel* channel) override;
    void removeChannel(Channel* channel) override;

private:
    void fillActiveChannels(int numEvents, ChannelList* activeChannels) const;
    void update(int operation, Channel* channel);

    static const int kInitEventListSize = 16;

    int epollfd_;
    std::vector<struct epoll_event> events_;
};

// EpollPoller实现
EpollPoller::EpollPoller(EventLoop* loop)
    : Poller(loop)
    , epollfd_(::epoll_create1(EPOLL_CLOEXEC))
    , events_(kInitEventListSize) {
    if (epollfd_ < 0) {
        throw std::runtime_error("epoll_create1 failed");
    }
}

EpollPoller::~EpollPoller() {
    ::close(epollfd_);
}

void EpollPoller::poll(int timeoutMs, ChannelList* activeChannels) {
    int numEvents = ::epoll_wait(epollfd_,
                                  events_.data(),
                                  static_cast<int>(events_.size()),
                                  timeoutMs);

    if (numEvents > 0) {
        fillActiveChannels(numEvents, activeChannels);
        // 动态扩容
        if (static_cast<size_t>(numEvents) == events_.size()) {
            events_.resize(events_.size() * 2);
        }
    } else if (numEvents < 0 && errno != EINTR) {
        // 错误处理
        perror("epoll_wait");
    }
}

void EpollPoller::fillActiveChannels(int numEvents,
                                      ChannelList* activeChannels) const {
    for (int i = 0; i < numEvents; ++i) {
        Channel* channel = static_cast<Channel*>(events_[i].data.ptr);
        channel->setRevents(events_[i].events);
        activeChannels->push_back(channel);
    }
}

void EpollPoller::updateChannel(Channel* channel) {
    const int index = channel->index();
    if (index == kNew || index == kDeleted) {
        // 新channel或已删除的channel，需要添加
        int fd = channel->fd();
        if (index == kNew) {
            channels_[fd] = channel;
        }
        channel->setIndex(kAdded);
        update(EPOLL_CTL_ADD, channel);
    } else {
        // 已存在的channel，修改或删除
        if (channel->isNoneEvent()) {
            update(EPOLL_CTL_DEL, channel);
            channel->setIndex(kDeleted);
        } else {
            update(EPOLL_CTL_MOD, channel);
        }
    }
}

void EpollPoller::update(int operation, Channel* channel) {
    struct epoll_event event;
    memset(&event, 0, sizeof(event));
    event.events = channel->events();
    event.data.ptr = channel;

    if (::epoll_ctl(epollfd_, operation, channel->fd(), &event) < 0) {
        // 错误处理
        perror("epoll_ctl");
    }
}

void EpollPoller::removeChannel(Channel* channel) {
    int fd = channel->fd();
    channels_.erase(fd);
    if (channel->index() == kAdded) {
        update(EPOLL_CTL_DEL, channel);
    }
    channel->setIndex(kNew);
}

// 索引常量
static const int kNew = -1;
static const int kAdded = 1;
static const int kDeleted = 2;

#endif // __linux__

#ifdef __APPLE__
/**
 * KqueuePoller - macOS/BSD kqueue实现
 */
class KqueuePoller : public Poller {
public:
    explicit KqueuePoller(EventLoop* loop);
    ~KqueuePoller() override;

    void poll(int timeoutMs, ChannelList* activeChannels) override;
    void updateChannel(Channel* channel) override;
    void removeChannel(Channel* channel) override;

private:
    static const int kInitEventListSize = 16;

    int kqfd_;
    std::vector<struct kevent> events_;
};

KqueuePoller::KqueuePoller(EventLoop* loop)
    : Poller(loop)
    , kqfd_(::kqueue())
    , events_(kInitEventListSize) {
    if (kqfd_ < 0) {
        throw std::runtime_error("kqueue failed");
    }
}

KqueuePoller::~KqueuePoller() {
    ::close(kqfd_);
}

void KqueuePoller::poll(int timeoutMs, ChannelList* activeChannels) {
    struct timespec timeout;
    timeout.tv_sec = timeoutMs / 1000;
    timeout.tv_nsec = (timeoutMs % 1000) * 1000000;

    int numEvents = ::kevent(kqfd_, nullptr, 0,
                             events_.data(),
                             static_cast<int>(events_.size()),
                             &timeout);

    if (numEvents > 0) {
        for (int i = 0; i < numEvents; ++i) {
            Channel* channel = static_cast<Channel*>(events_[i].udata);
            uint32_t revents = 0;
            if (events_[i].filter == EVFILT_READ) {
                revents |= POLLIN;
            }
            if (events_[i].filter == EVFILT_WRITE) {
                revents |= POLLOUT;
            }
            if (events_[i].flags & EV_ERROR) {
                revents |= POLLERR;
            }
            channel->setRevents(revents);
            activeChannels->push_back(channel);
        }
        if (static_cast<size_t>(numEvents) == events_.size()) {
            events_.resize(events_.size() * 2);
        }
    }
}

void KqueuePoller::updateChannel(Channel* channel) {
    std::vector<struct kevent> changes;
    struct kevent ev;

    if (channel->isReading()) {
        EV_SET(&ev, channel->fd(), EVFILT_READ, EV_ADD | EV_ENABLE,
               0, 0, channel);
        changes.push_back(ev);
    }
    if (channel->isWriting()) {
        EV_SET(&ev, channel->fd(), EVFILT_WRITE, EV_ADD | EV_ENABLE,
               0, 0, channel);
        changes.push_back(ev);
    }

    if (!changes.empty()) {
        ::kevent(kqfd_, changes.data(), changes.size(), nullptr, 0, nullptr);
    }

    channels_[channel->fd()] = channel;
}

void KqueuePoller::removeChannel(Channel* channel) {
    struct kevent changes[2];
    EV_SET(&changes[0], channel->fd(), EVFILT_READ, EV_DELETE, 0, 0, nullptr);
    EV_SET(&changes[1], channel->fd(), EVFILT_WRITE, EV_DELETE, 0, 0, nullptr);
    ::kevent(kqfd_, changes, 2, nullptr, 0, nullptr);
    channels_.erase(channel->fd());
}
#endif // __APPLE__

// 工厂方法实现
std::unique_ptr<Poller> Poller::createDefaultPoller(EventLoop* loop) {
#ifdef __linux__
    return std::make_unique<EpollPoller>(loop);
#elif defined(__APPLE__) || defined(__FreeBSD__)
    return std::make_unique<KqueuePoller>(loop);
#else
    #error "Unsupported platform"
#endif
}

} // namespace netlib
```

#### EventLoop事件循环

```cpp
/**
 * event_loop.hpp
 * 事件循环核心实现 - Reactor模式的核心
 */

#pragma once

#include <functional>
#include <vector>
#include <memory>
#include <mutex>
#include <atomic>
#include <thread>
#include <sys/eventfd.h>

namespace netlib {

class Channel;
class Poller;

/**
 * EventLoop 事件循环
 *
 * ┌─────────────────────────────────────────────────────────────┐
 * │                       EventLoop                             │
 * ├─────────────────────────────────────────────────────────────┤
 * │                                                             │
 * │   ┌─────────────┐                                          │
 * │   │   loop()    │◄──────────────────────────────┐          │
 * │   └──────┬──────┘                               │          │
 * │          │                                       │          │
 * │          ▼                                       │          │
 * │   ┌─────────────┐     就绪事件     ┌───────────┐│          │
 * │   │   Poller    │────────────────►│ Channels  ││          │
 * │   │ (epoll/kq)  │                 └─────┬─────┘│          │
 * │   └─────────────┘                       │      │          │
 * │                                         ▼      │          │
 * │                                  ┌───────────┐ │          │
 * │                                  │handleEvent│ │          │
 * │                                  │   回调    │ │          │
 * │                                  └─────┬─────┘ │          │
 * │                                        │       │          │
 * │          ┌─────────────────────────────┘       │          │
 * │          ▼                                     │          │
 * │   ┌─────────────┐                              │          │
 * │   │doPendingFunc│ 执行跨线程投递的任务          │          │
 * │   └──────┬──────┘                              │          │
 * │          └─────────────────────────────────────┘          │
 * │                                                             │
 * └─────────────────────────────────────────────────────────────┘
 */

class EventLoop {
public:
    using Functor = std::function<void()>;

    EventLoop();
    ~EventLoop();

    // 禁止拷贝
    EventLoop(const EventLoop&) = delete;
    EventLoop& operator=(const EventLoop&) = delete;

    // 核心事件循环
    void loop();
    void quit();

    // 跨线程任务投递
    void runInLoop(Functor cb);
    void queueInLoop(Functor cb);

    // 定时器接口
    void runAt(Timestamp when, Functor cb);
    void runAfter(double delay, Functor cb);
    void runEvery(double interval, Functor cb);

    // Channel管理
    void updateChannel(Channel* channel);
    void removeChannel(Channel* channel);
    bool hasChannel(Channel* channel) const;

    // 线程断言
    void assertInLoopThread() const {
        if (!isInLoopThread()) {
            abortNotInLoopThread();
        }
    }

    bool isInLoopThread() const {
        return threadId_ == std::this_thread::get_id();
    }

    // 获取当前线程的EventLoop
    static EventLoop* getEventLoopOfCurrentThread();

private:
    void abortNotInLoopThread() const;
    void handleWakeup();       // 处理唤醒事件
    void wakeup();             // 唤醒阻塞的loop
    void doPendingFunctors();  // 执行待处理任务

    std::atomic<bool> looping_;
    std::atomic<bool> quit_;
    std::atomic<bool> eventHandling_;
    std::atomic<bool> callingPendingFunctors_;

    const std::thread::id threadId_;
    std::unique_ptr<Poller> poller_;
    std::unique_ptr<TimerQueue> timerQueue_;

    int wakeupFd_;
    std::unique_ptr<Channel> wakeupChannel_;

    std::vector<Channel*> activeChannels_;
    Channel* currentActiveChannel_;

    mutable std::mutex mutex_;
    std::vector<Functor> pendingFunctors_;
};

// 实现
EventLoop::EventLoop()
    : looping_(false)
    , quit_(false)
    , eventHandling_(false)
    , callingPendingFunctors_(false)
    , threadId_(std::this_thread::get_id())
    , poller_(Poller::createDefaultPoller(this))
    , wakeupFd_(::eventfd(0, EFD_NONBLOCK | EFD_CLOEXEC))
    , wakeupChannel_(std::make_unique<Channel>(this, wakeupFd_)) {

    if (wakeupFd_ < 0) {
        throw std::runtime_error("eventfd failed");
    }

    // 设置唤醒回调
    wakeupChannel_->setReadCallback([this]() { handleWakeup(); });
    wakeupChannel_->enableReading();
}

EventLoop::~EventLoop() {
    wakeupChannel_->disableAll();
    wakeupChannel_->remove();
    ::close(wakeupFd_);
}

void EventLoop::loop() {
    assertInLoopThread();
    looping_ = true;
    quit_ = false;

    while (!quit_) {
        activeChannels_.clear();

        // 等待IO事件
        poller_->poll(10000, &activeChannels_);

        // 处理活跃事件
        eventHandling_ = true;
        for (Channel* channel : activeChannels_) {
            currentActiveChannel_ = channel;
            channel->handleEvent();
        }
        currentActiveChannel_ = nullptr;
        eventHandling_ = false;

        // 处理待处理的任务
        doPendingFunctors();
    }

    looping_ = false;
}

void EventLoop::quit() {
    quit_ = true;
    if (!isInLoopThread()) {
        wakeup();
    }
}

void EventLoop::runInLoop(Functor cb) {
    if (isInLoopThread()) {
        cb();
    } else {
        queueInLoop(std::move(cb));
    }
}

void EventLoop::queueInLoop(Functor cb) {
    {
        std::lock_guard<std::mutex> lock(mutex_);
        pendingFunctors_.push_back(std::move(cb));
    }

    // 如果不在loop线程，或者正在执行pending functors，需要唤醒
    if (!isInLoopThread() || callingPendingFunctors_) {
        wakeup();
    }
}

void EventLoop::wakeup() {
    uint64_t one = 1;
    ssize_t n = ::write(wakeupFd_, &one, sizeof(one));
    if (n != sizeof(one)) {
        // 错误处理
    }
}

void EventLoop::handleWakeup() {
    uint64_t one = 1;
    ssize_t n = ::read(wakeupFd_, &one, sizeof(one));
    if (n != sizeof(one)) {
        // 错误处理
    }
}

void EventLoop::doPendingFunctors() {
    std::vector<Functor> functors;
    callingPendingFunctors_ = true;

    {
        std::lock_guard<std::mutex> lock(mutex_);
        functors.swap(pendingFunctors_);
    }

    for (const Functor& functor : functors) {
        functor();
    }

    callingPendingFunctors_ = false;
}

void EventLoop::updateChannel(Channel* channel) {
    assertInLoopThread();
    poller_->updateChannel(channel);
}

void EventLoop::removeChannel(Channel* channel) {
    assertInLoopThread();
    poller_->removeChannel(channel);
}

} // namespace netlib
```

#### Channel事件通道

```cpp
/**
 * channel.hpp
 * 事件通道 - 封装fd的事件处理
 */

#pragma once

#include <functional>
#include <memory>

namespace netlib {

class EventLoop;

/**
 * Channel 事件分发机制
 *
 * ┌─────────────────────────────────────────────────────────────┐
 * │                        Channel                              │
 * ├─────────────────────────────────────────────────────────────┤
 * │                                                             │
 * │   fd ────────────────────────────────────────────┐         │
 * │                                                   │         │
 * │   events (关注的事件)                             │         │
 * │   ┌─────────┬─────────┬─────────┐                │         │
 * │   │ POLLIN  │ POLLOUT │ POLLERR │                │         │
 * │   └────┬────┴────┬────┴────┬────┘                │         │
 * │        │         │         │                      │         │
 * │        ▼         ▼         ▼                      │         │
 * │   ┌─────────┬─────────┬─────────┐                │         │
 * │   │readCb   │writeCb  │errorCb  │                │         │
 * │   └─────────┴─────────┴─────────┘                │         │
 * │                                                   │         │
 * │   handleEvent() ◄────────────────────────────────┘         │
 * │        │                                                    │
 * │        ▼                                                    │
 * │   根据revents调用对应callback                               │
 * │                                                             │
 * └─────────────────────────────────────────────────────────────┘
 */

class Channel {
public:
    using EventCallback = std::function<void()>;
    using ReadEventCallback = std::function<void()>;

    Channel(EventLoop* loop, int fd);
    ~Channel();

    // 禁止拷贝
    Channel(const Channel&) = delete;
    Channel& operator=(const Channel&) = delete;

    // 事件处理
    void handleEvent();

    // 设置回调
    void setReadCallback(ReadEventCallback cb) {
        readCallback_ = std::move(cb);
    }
    void setWriteCallback(EventCallback cb) {
        writeCallback_ = std::move(cb);
    }
    void setCloseCallback(EventCallback cb) {
        closeCallback_ = std::move(cb);
    }
    void setErrorCallback(EventCallback cb) {
        errorCallback_ = std::move(cb);
    }

    // 绑定tie对象（防止连接被销毁时channel仍在处理事件）
    void tie(const std::shared_ptr<void>&);

    // 获取fd
    int fd() const { return fd_; }

    // 事件管理
    uint32_t events() const { return events_; }
    void setRevents(uint32_t revt) { revents_ = revt; }

    // 是否无事件
    bool isNoneEvent() const { return events_ == kNoneEvent; }

    // 启用/禁用读写
    void enableReading() {
        events_ |= kReadEvent;
        update();
    }
    void disableReading() {
        events_ &= ~kReadEvent;
        update();
    }
    void enableWriting() {
        events_ |= kWriteEvent;
        update();
    }
    void disableWriting() {
        events_ &= ~kWriteEvent;
        update();
    }
    void disableAll() {
        events_ = kNoneEvent;
        update();
    }

    // 状态查询
    bool isReading() const { return events_ & kReadEvent; }
    bool isWriting() const { return events_ & kWriteEvent; }

    // for Poller
    int index() const { return index_; }
    void setIndex(int idx) { index_ = idx; }

    // 移除
    void remove();

    EventLoop* ownerLoop() { return loop_; }

private:
    void update();
    void handleEventWithGuard();

    static const uint32_t kNoneEvent = 0;
    static const uint32_t kReadEvent = POLLIN | POLLPRI;
    static const uint32_t kWriteEvent = POLLOUT;

    EventLoop* loop_;
    const int fd_;
    uint32_t events_;    // 关注的事件
    uint32_t revents_;   // 实际发生的事件
    int index_;          // Poller中的状态

    std::weak_ptr<void> tie_;
    bool tied_;
    bool eventHandling_;
    bool addedToLoop_;

    ReadEventCallback readCallback_;
    EventCallback writeCallback_;
    EventCallback closeCallback_;
    EventCallback errorCallback_;
};

// 实现
Channel::Channel(EventLoop* loop, int fd)
    : loop_(loop)
    , fd_(fd)
    , events_(0)
    , revents_(0)
    , index_(-1)
    , tied_(false)
    , eventHandling_(false)
    , addedToLoop_(false) {
}

Channel::~Channel() {
    // 确保不在事件处理中销毁
    assert(!eventHandling_);
    assert(!addedToLoop_);
}

void Channel::tie(const std::shared_ptr<void>& obj) {
    tie_ = obj;
    tied_ = true;
}

void Channel::update() {
    addedToLoop_ = true;
    loop_->updateChannel(this);
}

void Channel::remove() {
    addedToLoop_ = false;
    loop_->removeChannel(this);
}

void Channel::handleEvent() {
    if (tied_) {
        std::shared_ptr<void> guard = tie_.lock();
        if (guard) {
            handleEventWithGuard();
        }
    } else {
        handleEventWithGuard();
    }
}

void Channel::handleEventWithGuard() {
    eventHandling_ = true;

    // 对端关闭
    if ((revents_ & POLLHUP) && !(revents_ & POLLIN)) {
        if (closeCallback_) closeCallback_();
    }

    // 错误
    if (revents_ & (POLLERR | POLLNVAL)) {
        if (errorCallback_) errorCallback_();
    }

    // 可读
    if (revents_ & (POLLIN | POLLPRI | POLLRDHUP)) {
        if (readCallback_) readCallback_();
    }

    // 可写
    if (revents_ & POLLOUT) {
        if (writeCallback_) writeCallback_();
    }

    eventHandling_ = false;
}

} // namespace netlib
```

#### Buffer缓冲区

```cpp
/**
 * buffer.hpp
 * 高效读写缓冲区实现
 */

#pragma once

#include <vector>
#include <string>
#include <algorithm>
#include <cassert>
#include <cstring>
#include <sys/uio.h>

namespace netlib {

/**
 * Buffer 内存布局
 *
 * ┌────────────────────────────────────────────────────────────────┐
 * │                         Buffer                                 │
 * ├────────────────────────────────────────────────────────────────┤
 * │                                                                │
 * │  +-------------------+------------------+------------------+   │
 * │  |   prependable     |     readable     |     writable     |   │
 * │  |                   |     (CONTENT)    |                  |   │
 * │  +-------------------+------------------+------------------+   │
 * │  |                   |                  |                  |   │
 * │  0      <=      readerIndex   <=   writerIndex    <=    size   │
 * │                                                                │
 * │  prependable = readerIndex                                     │
 * │  readable    = writerIndex - readerIndex                       │
 * │  writable    = size - writerIndex                              │
 * │                                                                │
 * │  prepend区域用于高效添加协议头                                   │
 * │  例如：添加4字节长度前缀，无需移动数据                            │
 * │                                                                │
 * └────────────────────────────────────────────────────────────────┘
 */

class Buffer {
public:
    static const size_t kCheapPrepend = 8;
    static const size_t kInitialSize = 1024;

    explicit Buffer(size_t initialSize = kInitialSize)
        : buffer_(kCheapPrepend + initialSize)
        , readerIndex_(kCheapPrepend)
        , writerIndex_(kCheapPrepend) {
    }

    // 可读/可写字节数
    size_t readableBytes() const { return writerIndex_ - readerIndex_; }
    size_t writableBytes() const { return buffer_.size() - writerIndex_; }
    size_t prependableBytes() const { return readerIndex_; }

    // 获取读指针
    const char* peek() const { return begin() + readerIndex_; }

    // 查找CRLF
    const char* findCRLF() const {
        const char* crlf = std::search(peek(), beginWrite(),
                                       kCRLF, kCRLF + 2);
        return crlf == beginWrite() ? nullptr : crlf;
    }

    // 查找EOL
    const char* findEOL() const {
        const void* eol = memchr(peek(), '\n', readableBytes());
        return static_cast<const char*>(eol);
    }

    // 取走数据
    void retrieve(size_t len) {
        assert(len <= readableBytes());
        if (len < readableBytes()) {
            readerIndex_ += len;
        } else {
            retrieveAll();
        }
    }

    void retrieveUntil(const char* end) {
        assert(peek() <= end);
        assert(end <= beginWrite());
        retrieve(end - peek());
    }

    void retrieveAll() {
        readerIndex_ = kCheapPrepend;
        writerIndex_ = kCheapPrepend;
    }

    std::string retrieveAsString(size_t len) {
        assert(len <= readableBytes());
        std::string result(peek(), len);
        retrieve(len);
        return result;
    }

    std::string retrieveAllAsString() {
        return retrieveAsString(readableBytes());
    }

    // 添加数据
    void append(const char* data, size_t len) {
        ensureWritableBytes(len);
        std::copy(data, data + len, beginWrite());
        writerIndex_ += len;
    }

    void append(const std::string& str) {
        append(str.data(), str.size());
    }

    void append(const void* data, size_t len) {
        append(static_cast<const char*>(data), len);
    }

    void ensureWritableBytes(size_t len) {
        if (writableBytes() < len) {
            makeSpace(len);
        }
        assert(writableBytes() >= len);
    }

    char* beginWrite() { return begin() + writerIndex_; }
    const char* beginWrite() const { return begin() + writerIndex_; }

    void hasWritten(size_t len) {
        assert(len <= writableBytes());
        writerIndex_ += len;
    }

    void unwrite(size_t len) {
        assert(len <= readableBytes());
        writerIndex_ -= len;
    }

    // 在prepend区域添加数据
    void prepend(const void* data, size_t len) {
        assert(len <= prependableBytes());
        readerIndex_ -= len;
        const char* d = static_cast<const char*>(data);
        std::copy(d, d + len, begin() + readerIndex_);
    }

    // 收缩到合适大小
    void shrink(size_t reserve) {
        Buffer other;
        other.ensureWritableBytes(readableBytes() + reserve);
        other.append(peek(), readableBytes());
        swap(other);
    }

    // 内部容量
    size_t internalCapacity() const { return buffer_.capacity(); }

    // 从fd读取数据（使用readv实现高效读取）
    ssize_t readFd(int fd, int* savedErrno);

    void swap(Buffer& rhs) {
        buffer_.swap(rhs.buffer_);
        std::swap(readerIndex_, rhs.readerIndex_);
        std::swap(writerIndex_, rhs.writerIndex_);
    }

    // 整数读写（网络字节序）
    void appendInt32(int32_t x) {
        int32_t be32 = htobe32(x);
        append(&be32, sizeof(be32));
    }

    void appendInt16(int16_t x) {
        int16_t be16 = htobe16(x);
        append(&be16, sizeof(be16));
    }

    int32_t readInt32() {
        int32_t result = peekInt32();
        retrieve(sizeof(int32_t));
        return result;
    }

    int16_t readInt16() {
        int16_t result = peekInt16();
        retrieve(sizeof(int16_t));
        return result;
    }

    int32_t peekInt32() const {
        assert(readableBytes() >= sizeof(int32_t));
        int32_t be32 = 0;
        ::memcpy(&be32, peek(), sizeof(be32));
        return be32toh(be32);
    }

    int16_t peekInt16() const {
        assert(readableBytes() >= sizeof(int16_t));
        int16_t be16 = 0;
        ::memcpy(&be16, peek(), sizeof(be16));
        return be16toh(be16);
    }

private:
    char* begin() { return buffer_.data(); }
    const char* begin() const { return buffer_.data(); }

    void makeSpace(size_t len) {
        if (writableBytes() + prependableBytes() < len + kCheapPrepend) {
            // 需要扩容
            buffer_.resize(writerIndex_ + len);
        } else {
            // 移动数据到前面
            size_t readable = readableBytes();
            std::copy(begin() + readerIndex_,
                     begin() + writerIndex_,
                     begin() + kCheapPrepend);
            readerIndex_ = kCheapPrepend;
            writerIndex_ = readerIndex_ + readable;
        }
    }

    std::vector<char> buffer_;
    size_t readerIndex_;
    size_t writerIndex_;

    static const char kCRLF[];
};

const char Buffer::kCRLF[] = "\r\n";

// 使用readv实现高效读取
ssize_t Buffer::readFd(int fd, int* savedErrno) {
    // 栈上额外缓冲区，避免频繁扩容
    char extrabuf[65536];
    struct iovec vec[2];

    const size_t writable = writableBytes();
    vec[0].iov_base = beginWrite();
    vec[0].iov_len = writable;
    vec[1].iov_base = extrabuf;
    vec[1].iov_len = sizeof(extrabuf);

    // 如果buffer足够大，不使用额外缓冲区
    const int iovcnt = (writable < sizeof(extrabuf)) ? 2 : 1;
    const ssize_t n = ::readv(fd, vec, iovcnt);

    if (n < 0) {
        *savedErrno = errno;
    } else if (static_cast<size_t>(n) <= writable) {
        writerIndex_ += n;
    } else {
        writerIndex_ = buffer_.size();
        append(extrabuf, n - writable);
    }

    return n;
}

} // namespace netlib
```

---

### Day 11-12: 连接管理层

#### TcpConnection连接封装

```cpp
/**
 * tcp_connection.hpp
 * TCP连接封装 - 管理已建立连接的生命周期
 */

#pragma once

#include <memory>
#include <string>
#include <functional>
#include <any>

namespace netlib {

class EventLoop;
class Channel;
class Socket;
class Buffer;

/**
 * TcpConnection 状态机
 *
 * ┌─────────────────────────────────────────────────────────────┐
 * │                  TcpConnection 状态转换                      │
 * ├─────────────────────────────────────────────────────────────┤
 * │                                                             │
 * │       ┌──────────────┐                                     │
 * │       │ kConnecting  │  创建连接对象                        │
 * │       └──────┬───────┘                                     │
 * │              │ connectEstablished()                        │
 * │              ▼                                              │
 * │       ┌──────────────┐                                     │
 * │       │ kConnected   │  连接已建立，可以收发数据             │
 * │       └──────┬───────┘                                     │
 * │              │ shutdown() 或 对端关闭                       │
 * │              ▼                                              │
 * │       ┌──────────────┐                                     │
 * │       │kDisconnecting│  正在关闭                            │
 * │       └──────┬───────┘                                     │
 * │              │ connectDestroyed()                          │
 * │              ▼                                              │
 * │       ┌──────────────┐                                     │
 * │       │kDisconnected │  已关闭                              │
 * │       └──────────────┘                                     │
 * │                                                             │
 * └─────────────────────────────────────────────────────────────┘
 */

class TcpConnection : public std::enable_shared_from_this<TcpConnection> {
public:
    using TcpConnectionPtr = std::shared_ptr<TcpConnection>;
    using ConnectionCallback = std::function<void(const TcpConnectionPtr&)>;
    using MessageCallback = std::function<void(const TcpConnectionPtr&, Buffer*)>;
    using WriteCompleteCallback = std::function<void(const TcpConnectionPtr&)>;
    using HighWaterMarkCallback = std::function<void(const TcpConnectionPtr&, size_t)>;
    using CloseCallback = std::function<void(const TcpConnectionPtr&)>;

    TcpConnection(EventLoop* loop,
                  const std::string& name,
                  int sockfd,
                  const InetAddress& localAddr,
                  const InetAddress& peerAddr);
    ~TcpConnection();

    // 禁止拷贝
    TcpConnection(const TcpConnection&) = delete;
    TcpConnection& operator=(const TcpConnection&) = delete;

    // Getters
    EventLoop* getLoop() const { return loop_; }
    const std::string& name() const { return name_; }
    const InetAddress& localAddress() const { return localAddr_; }
    const InetAddress& peerAddress() const { return peerAddr_; }
    bool connected() const { return state_ == kConnected; }
    bool disconnected() const { return state_ == kDisconnected; }

    // 发送数据
    void send(const void* data, size_t len);
    void send(const std::string& message);
    void send(Buffer* buf);

    // 关闭连接
    void shutdown();
    void forceClose();
    void forceCloseWithDelay(double seconds);

    // 禁用/启用Nagle算法
    void setTcpNoDelay(bool on);

    // 设置回调
    void setConnectionCallback(const ConnectionCallback& cb) {
        connectionCallback_ = cb;
    }
    void setMessageCallback(const MessageCallback& cb) {
        messageCallback_ = cb;
    }
    void setWriteCompleteCallback(const WriteCompleteCallback& cb) {
        writeCompleteCallback_ = cb;
    }
    void setHighWaterMarkCallback(const HighWaterMarkCallback& cb,
                                   size_t highWaterMark) {
        highWaterMarkCallback_ = cb;
        highWaterMark_ = highWaterMark;
    }
    void setCloseCallback(const CloseCallback& cb) {
        closeCallback_ = cb;
    }

    // 连接建立和销毁（由TcpServer调用）
    void connectEstablished();
    void connectDestroyed();

    // 上下文（用于存储应用层数据）
    void setContext(const std::any& context) { context_ = context; }
    const std::any& getContext() const { return context_; }
    std::any* getMutableContext() { return &context_; }

    // 获取Buffer
    Buffer* inputBuffer() { return &inputBuffer_; }
    Buffer* outputBuffer() { return &outputBuffer_; }

private:
    enum StateE { kDisconnected, kConnecting, kConnected, kDisconnecting };

    void handleRead();
    void handleWrite();
    void handleClose();
    void handleError();

    void sendInLoop(const void* data, size_t len);
    void shutdownInLoop();
    void forceCloseInLoop();

    void setState(StateE s) { state_ = s; }

    EventLoop* loop_;
    const std::string name_;
    StateE state_;

    std::unique_ptr<Socket> socket_;
    std::unique_ptr<Channel> channel_;

    const InetAddress localAddr_;
    const InetAddress peerAddr_;

    ConnectionCallback connectionCallback_;
    MessageCallback messageCallback_;
    WriteCompleteCallback writeCompleteCallback_;
    HighWaterMarkCallback highWaterMarkCallback_;
    CloseCallback closeCallback_;

    size_t highWaterMark_;
    Buffer inputBuffer_;
    Buffer outputBuffer_;
    std::any context_;
};

// 部分实现
void TcpConnection::send(const std::string& message) {
    if (state_ == kConnected) {
        if (loop_->isInLoopThread()) {
            sendInLoop(message.data(), message.size());
        } else {
            // 跨线程发送
            loop_->runInLoop([this, message]() {
                sendInLoop(message.data(), message.size());
            });
        }
    }
}

void TcpConnection::sendInLoop(const void* data, size_t len) {
    loop_->assertInLoopThread();

    ssize_t nwrote = 0;
    size_t remaining = len;
    bool faultError = false;

    if (state_ == kDisconnected) {
        return;
    }

    // 如果输出缓冲区没有数据，尝试直接写
    if (!channel_->isWriting() && outputBuffer_.readableBytes() == 0) {
        nwrote = ::write(channel_->fd(), data, len);
        if (nwrote >= 0) {
            remaining = len - nwrote;
            if (remaining == 0 && writeCompleteCallback_) {
                loop_->queueInLoop([this]() {
                    writeCompleteCallback_(shared_from_this());
                });
            }
        } else {
            nwrote = 0;
            if (errno != EWOULDBLOCK) {
                if (errno == EPIPE || errno == ECONNRESET) {
                    faultError = true;
                }
            }
        }
    }

    // 还有剩余数据，放入输出缓冲区
    if (!faultError && remaining > 0) {
        size_t oldLen = outputBuffer_.readableBytes();

        // 高水位回调
        if (oldLen + remaining >= highWaterMark_ &&
            oldLen < highWaterMark_ &&
            highWaterMarkCallback_) {
            loop_->queueInLoop([this, total = oldLen + remaining]() {
                highWaterMarkCallback_(shared_from_this(), total);
            });
        }

        outputBuffer_.append(static_cast<const char*>(data) + nwrote, remaining);

        if (!channel_->isWriting()) {
            channel_->enableWriting();
        }
    }
}

void TcpConnection::handleRead() {
    loop_->assertInLoopThread();
    int savedErrno = 0;
    ssize_t n = inputBuffer_.readFd(channel_->fd(), &savedErrno);

    if (n > 0) {
        messageCallback_(shared_from_this(), &inputBuffer_);
    } else if (n == 0) {
        handleClose();
    } else {
        errno = savedErrno;
        handleError();
    }
}

void TcpConnection::handleWrite() {
    loop_->assertInLoopThread();

    if (channel_->isWriting()) {
        ssize_t n = ::write(channel_->fd(),
                            outputBuffer_.peek(),
                            outputBuffer_.readableBytes());
        if (n > 0) {
            outputBuffer_.retrieve(n);
            if (outputBuffer_.readableBytes() == 0) {
                channel_->disableWriting();
                if (writeCompleteCallback_) {
                    loop_->queueInLoop([this]() {
                        writeCompleteCallback_(shared_from_this());
                    });
                }
                if (state_ == kDisconnecting) {
                    shutdownInLoop();
                }
            }
        }
    }
}

void TcpConnection::handleClose() {
    loop_->assertInLoopThread();
    setState(kDisconnected);
    channel_->disableAll();

    TcpConnectionPtr guardThis(shared_from_this());
    connectionCallback_(guardThis);
    closeCallback_(guardThis);
}

} // namespace netlib
```

---

### Day 13-14: 定时器与线程模型

#### TimerQueue定时器队列

```cpp
/**
 * timer_queue.hpp
 * 定时器队列 - 基于最小堆实现
 */

#pragma once

#include <set>
#include <vector>
#include <memory>
#include <functional>
#include <chrono>
#include <atomic>

namespace netlib {

using Timestamp = std::chrono::time_point<std::chrono::system_clock>;
using TimerCallback = std::function<void()>;

/**
 * 定时器系统架构
 *
 * ┌─────────────────────────────────────────────────────────────┐
 * │                      TimerQueue                             │
 * ├─────────────────────────────────────────────────────────────┤
 * │                                                             │
 * │   ┌─────────────────────────────────────────────────┐      │
 * │   │              std::set<Timer>                     │      │
 * │   │            (按到期时间排序)                       │      │
 * │   │                                                  │      │
 * │   │  ┌───┐  ┌───┐  ┌───┐  ┌───┐  ┌───┐            │      │
 * │   │  │T1 │─►│T2 │─►│T3 │─►│T4 │─►│T5 │            │      │
 * │   │  │1ms│  │5ms│  │10ms│ │20ms│ │50ms│           │      │
 * │   │  └───┘  └───┘  └───┘  └───┘  └───┘            │      │
 * │   └─────────────────────────────────────────────────┘      │
 * │                                                             │
 * │   timerfd ────► EventLoop                                  │
 * │      │                                                      │
 * │      └──► 当最早定时器到期时唤醒EventLoop                    │
 * │                                                             │
 * └─────────────────────────────────────────────────────────────┘
 */

class Timer {
public:
    Timer(TimerCallback cb, Timestamp when, double interval)
        : callback_(std::move(cb))
        , expiration_(when)
        , interval_(interval)
        , repeat_(interval > 0.0)
        , sequence_(++s_numCreated_) {
    }

    void run() const { callback_(); }

    Timestamp expiration() const { return expiration_; }
    bool repeat() const { return repeat_; }
    int64_t sequence() const { return sequence_; }

    void restart(Timestamp now) {
        if (repeat_) {
            expiration_ = now + std::chrono::microseconds(
                static_cast<int64_t>(interval_ * 1000000));
        } else {
            expiration_ = Timestamp{};
        }
    }

    static int64_t numCreated() { return s_numCreated_; }

private:
    const TimerCallback callback_;
    Timestamp expiration_;
    const double interval_;
    const bool repeat_;
    const int64_t sequence_;

    static std::atomic<int64_t> s_numCreated_;
};

std::atomic<int64_t> Timer::s_numCreated_{0};

// TimerId用于取消定时器
class TimerId {
public:
    TimerId() : timer_(nullptr), sequence_(0) {}
    TimerId(Timer* timer, int64_t seq)
        : timer_(timer), sequence_(seq) {}

    Timer* timer() const { return timer_; }
    int64_t sequence() const { return sequence_; }

private:
    Timer* timer_;
    int64_t sequence_;
};

class TimerQueue {
public:
    explicit TimerQueue(EventLoop* loop);
    ~TimerQueue();

    // 添加定时器
    TimerId addTimer(TimerCallback cb, Timestamp when, double interval);

    // 取消定时器
    void cancel(TimerId timerId);

private:
    using Entry = std::pair<Timestamp, Timer*>;
    using TimerList = std::set<Entry>;
    using ActiveTimer = std::pair<Timer*, int64_t>;
    using ActiveTimerSet = std::set<ActiveTimer>;

    void addTimerInLoop(Timer* timer);
    void cancelInLoop(TimerId timerId);
    void handleRead();
    std::vector<Entry> getExpired(Timestamp now);
    void reset(const std::vector<Entry>& expired, Timestamp now);
    bool insert(Timer* timer);

    EventLoop* loop_;
    const int timerfd_;
    Channel timerfdChannel_;

    TimerList timers_;
    ActiveTimerSet activeTimers_;
    bool callingExpiredTimers_;
    ActiveTimerSet cancelingTimers_;
};

// 创建timerfd
int createTimerfd() {
    int timerfd = ::timerfd_create(CLOCK_MONOTONIC,
                                    TFD_NONBLOCK | TFD_CLOEXEC);
    if (timerfd < 0) {
        throw std::runtime_error("timerfd_create failed");
    }
    return timerfd;
}

// 重置timerfd的超时时间
void resetTimerfd(int timerfd, Timestamp expiration) {
    struct itimerspec newValue;
    struct itimerspec oldValue;
    memset(&newValue, 0, sizeof(newValue));
    memset(&oldValue, 0, sizeof(oldValue));

    auto duration = expiration - std::chrono::system_clock::now();
    auto microseconds = std::chrono::duration_cast<
        std::chrono::microseconds>(duration).count();

    if (microseconds < 100) {
        microseconds = 100;
    }

    newValue.it_value.tv_sec = microseconds / 1000000;
    newValue.it_value.tv_nsec = (microseconds % 1000000) * 1000;

    ::timerfd_settime(timerfd, 0, &newValue, &oldValue);
}

TimerQueue::TimerQueue(EventLoop* loop)
    : loop_(loop)
    , timerfd_(createTimerfd())
    , timerfdChannel_(loop, timerfd_)
    , callingExpiredTimers_(false) {

    timerfdChannel_.setReadCallback([this]() { handleRead(); });
    timerfdChannel_.enableReading();
}

TimerQueue::~TimerQueue() {
    timerfdChannel_.disableAll();
    timerfdChannel_.remove();
    ::close(timerfd_);

    for (const Entry& timer : timers_) {
        delete timer.second;
    }
}

TimerId TimerQueue::addTimer(TimerCallback cb,
                              Timestamp when,
                              double interval) {
    Timer* timer = new Timer(std::move(cb), when, interval);
    loop_->runInLoop([this, timer]() { addTimerInLoop(timer); });
    return TimerId(timer, timer->sequence());
}

void TimerQueue::addTimerInLoop(Timer* timer) {
    loop_->assertInLoopThread();
    bool earliestChanged = insert(timer);

    if (earliestChanged) {
        resetTimerfd(timerfd_, timer->expiration());
    }
}

void TimerQueue::handleRead() {
    loop_->assertInLoopThread();

    // 读取timerfd（必须读取，否则会一直触发）
    uint64_t howmany;
    ::read(timerfd_, &howmany, sizeof(howmany));

    Timestamp now = std::chrono::system_clock::now();
    std::vector<Entry> expired = getExpired(now);

    callingExpiredTimers_ = true;
    cancelingTimers_.clear();

    // 执行回调
    for (const Entry& it : expired) {
        it.second->run();
    }

    callingExpiredTimers_ = false;

    // 重置周期性定时器
    reset(expired, now);
}

std::vector<TimerQueue::Entry> TimerQueue::getExpired(Timestamp now) {
    std::vector<Entry> expired;
    Entry sentry(now, reinterpret_cast<Timer*>(UINTPTR_MAX));

    auto end = timers_.lower_bound(sentry);
    std::copy(timers_.begin(), end, std::back_inserter(expired));
    timers_.erase(timers_.begin(), end);

    for (const Entry& it : expired) {
        ActiveTimer timer(it.second, it.second->sequence());
        activeTimers_.erase(timer);
    }

    return expired;
}

void TimerQueue::reset(const std::vector<Entry>& expired, Timestamp now) {
    for (const Entry& it : expired) {
        ActiveTimer timer(it.second, it.second->sequence());
        if (it.second->repeat() &&
            cancelingTimers_.find(timer) == cancelingTimers_.end()) {
            it.second->restart(now);
            insert(it.second);
        } else {
            delete it.second;
        }
    }

    if (!timers_.empty()) {
        Timestamp nextExpire = timers_.begin()->second->expiration();
        resetTimerfd(timerfd_, nextExpire);
    }
}

bool TimerQueue::insert(Timer* timer) {
    bool earliestChanged = false;
    Timestamp when = timer->expiration();

    auto it = timers_.begin();
    if (it == timers_.end() || when < it->first) {
        earliestChanged = true;
    }

    timers_.insert(Entry(when, timer));
    activeTimers_.insert(ActiveTimer(timer, timer->sequence()));

    return earliestChanged;
}

} // namespace netlib
```

#### EventLoopThreadPool线程池

```cpp
/**
 * event_loop_thread_pool.hpp
 * 事件循环线程池 - 多Reactor模型核心
 */

#pragma once

#include <vector>
#include <memory>
#include <functional>
#include <string>
#include <thread>
#include <mutex>
#include <condition_variable>

namespace netlib {

/**
 * EventLoopThreadPool 架构
 *
 * ┌─────────────────────────────────────────────────────────────────┐
 * │                    EventLoopThreadPool                          │
 * ├─────────────────────────────────────────────────────────────────┤
 * │                                                                 │
 * │   baseLoop_ (Main Reactor)                                      │
 * │        │                                                        │
 * │        │ getNextLoop() - Round-Robin分配                        │
 * │        │                                                        │
 * │        ▼                                                        │
 * │   ┌─────────────────────────────────────────────────────┐      │
 * │   │                    loops_                            │      │
 * │   │  ┌──────────┐  ┌──────────┐  ┌──────────┐          │      │
 * │   │  │EventLoop1│  │EventLoop2│  │EventLoop3│  ...      │      │
 * │   │  │ (Thread1)│  │ (Thread2)│  │ (Thread3)│          │      │
 * │   │  └──────────┘  └──────────┘  └──────────┘          │      │
 * │   └─────────────────────────────────────────────────────┘      │
 * │                                                                 │
 * │   每个EventLoop运行在独立线程中                                  │
 * │   处理分配给它的所有连接                                         │
 * │                                                                 │
 * └─────────────────────────────────────────────────────────────────┘
 */

// 单个EventLoop线程
class EventLoopThread {
public:
    using ThreadInitCallback = std::function<void(EventLoop*)>;

    EventLoopThread(const ThreadInitCallback& cb = ThreadInitCallback(),
                    const std::string& name = std::string());
    ~EventLoopThread();

    EventLoop* startLoop();

private:
    void threadFunc();

    EventLoop* loop_;
    bool exiting_;
    std::thread thread_;
    std::mutex mutex_;
    std::condition_variable cond_;
    ThreadInitCallback callback_;
};

EventLoopThread::EventLoopThread(const ThreadInitCallback& cb,
                                  const std::string& name)
    : loop_(nullptr)
    , exiting_(false)
    , callback_(cb) {
}

EventLoopThread::~EventLoopThread() {
    exiting_ = true;
    if (loop_ != nullptr) {
        loop_->quit();
        thread_.join();
    }
}

EventLoop* EventLoopThread::startLoop() {
    thread_ = std::thread([this]() { threadFunc(); });

    EventLoop* loop = nullptr;
    {
        std::unique_lock<std::mutex> lock(mutex_);
        while (loop_ == nullptr) {
            cond_.wait(lock);
        }
        loop = loop_;
    }

    return loop;
}

void EventLoopThread::threadFunc() {
    EventLoop loop;

    if (callback_) {
        callback_(&loop);
    }

    {
        std::lock_guard<std::mutex> lock(mutex_);
        loop_ = &loop;
        cond_.notify_one();
    }

    loop.loop();

    std::lock_guard<std::mutex> lock(mutex_);
    loop_ = nullptr;
}

// EventLoop线程池
class EventLoopThreadPool {
public:
    using ThreadInitCallback = std::function<void(EventLoop*)>;

    EventLoopThreadPool(EventLoop* baseLoop, const std::string& name);
    ~EventLoopThreadPool();

    // 设置线程数
    void setThreadNum(int numThreads) { numThreads_ = numThreads; }

    // 启动线程池
    void start(const ThreadInitCallback& cb = ThreadInitCallback());

    // 获取下一个EventLoop（Round-Robin）
    EventLoop* getNextLoop();

    // 根据hash值获取EventLoop
    EventLoop* getLoopForHash(size_t hashCode);

    // 获取所有EventLoop
    std::vector<EventLoop*> getAllLoops();

    bool started() const { return started_; }
    const std::string& name() const { return name_; }

private:
    EventLoop* baseLoop_;
    std::string name_;
    bool started_;
    int numThreads_;
    int next_;
    std::vector<std::unique_ptr<EventLoopThread>> threads_;
    std::vector<EventLoop*> loops_;
};

EventLoopThreadPool::EventLoopThreadPool(EventLoop* baseLoop,
                                          const std::string& name)
    : baseLoop_(baseLoop)
    , name_(name)
    , started_(false)
    , numThreads_(0)
    , next_(0) {
}

EventLoopThreadPool::~EventLoopThreadPool() {
    // EventLoopThread会在析构时自动清理
}

void EventLoopThreadPool::start(const ThreadInitCallback& cb) {
    started_ = true;

    for (int i = 0; i < numThreads_; ++i) {
        std::string threadName = name_ + std::to_string(i);
        auto t = std::make_unique<EventLoopThread>(cb, threadName);
        loops_.push_back(t->startLoop());
        threads_.push_back(std::move(t));
    }

    // 如果没有创建额外线程，则使用baseLoop
    if (numThreads_ == 0 && cb) {
        cb(baseLoop_);
    }
}

EventLoop* EventLoopThreadPool::getNextLoop() {
    baseLoop_->assertInLoopThread();
    EventLoop* loop = baseLoop_;

    if (!loops_.empty()) {
        // Round-Robin
        loop = loops_[next_];
        ++next_;
        if (static_cast<size_t>(next_) >= loops_.size()) {
            next_ = 0;
        }
    }

    return loop;
}

EventLoop* EventLoopThreadPool::getLoopForHash(size_t hashCode) {
    baseLoop_->assertInLoopThread();
    EventLoop* loop = baseLoop_;

    if (!loops_.empty()) {
        loop = loops_[hashCode % loops_.size()];
    }

    return loop;
}

std::vector<EventLoop*> EventLoopThreadPool::getAllLoops() {
    baseLoop_->assertInLoopThread();

    if (loops_.empty()) {
        return {baseLoop_};
    }
    return loops_;
}

} // namespace netlib
```

---

### Week 2 输出物清单

| 文件 | 说明 | 完成状态 |
|------|------|---------|
| `netlib/poller.hpp` | IO多路复用抽象层 | [ ] |
| `netlib/event_loop.hpp` | 事件循环核心 | [ ] |
| `netlib/channel.hpp` | 事件通道 | [ ] |
| `netlib/buffer.hpp` | 读写缓冲区 | [ ] |
| `netlib/tcp_connection.hpp` | TCP连接封装 | [ ] |
| `netlib/acceptor.hpp` | 连接接入器 | [ ] |
| `netlib/connector.hpp` | 主动连接器 | [ ] |
| `netlib/timer_queue.hpp` | 定时器队列 | [ ] |
| `netlib/event_loop_thread_pool.hpp` | 事件循环线程池 | [ ] |
| `notes/week2_network_layer.md` | 本周学习笔记 | [ ] |

### Week 2 验收标准

- [ ] 理解epoll/kqueue的工作原理
- [ ] 能够实现跨平台的Poller抽象
- [ ] 掌握EventLoop的事件循环机制
- [ ] 理解Channel的事件分发设计
- [ ] 掌握Buffer的高效读写技巧
- [ ] 理解TcpConnection的状态管理
- [ ] 能够实现定时器队列
- [ ] 掌握多Reactor线程模型

---

## Week 3: 协议层与服务层实现（35小时）

### 本周目标
```
┌─────────────────────────────────────────────────────────────────┐
│  Week 3: Protocol Layer + Service Layer                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Day 15-17: 协议层                                              │
│  ┌───────────────────────────────────────────────────────┐     │
│  │   Codec ──► MessageFraming ──► Serializer Plugin      │     │
│  │   编解码      消息分帧           序列化插件             │     │
│  └───────────────────────────────────────────────────────┘     │
│                                                                 │
│  Day 18-19: RPC服务层                                           │
│  ┌───────────────────────────────────────────────────────┐     │
│  │  ServiceRegistry ──► Router ──► AsyncCallManager      │     │
│  │  服务注册            路由分发      异步调用管理          │     │
│  └───────────────────────────────────────────────────────┘     │
│                                                                 │
│  Day 20-21: 高级特性                                            │
│  ┌───────────────────────────────────────────────────────┐     │
│  │  ConnectionPool + LoadBalancer + RateLimiter           │     │
│  │  连接池            负载均衡        限流器               │     │
│  └───────────────────────────────────────────────────────┘     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 每日任务分解

| Day | 时间 | 上午任务(2.5h) | 下午任务(2.5h) | 输出物 |
|-----|------|---------------|---------------|--------|
| 15 | 5h | Codec编解码框架 | 消息分帧实现 | codec.hpp |
| 16 | 5h | RPC协议编解码 | HTTP协议编解码 | rpc_codec.hpp, http_codec.hpp |
| 17 | 5h | 序列化插件集成 | 压缩插件集成 | serializer_plugin.hpp |
| 18 | 5h | 服务注册表实现 | 请求路由与分发 | service_registry.hpp |
| 19 | 5h | RPC服务端实现 | RPC客户端实现 | rpc_server.hpp, rpc_client.hpp |
| 20 | 5h | 连接池实现 | 负载均衡策略 | connection_pool.hpp |
| 21 | 5h | 超时与重试机制 | 限流器实现 | rate_limiter.hpp |

---

### Day 15-17: 协议层实现

#### Codec编解码框架

```cpp
/**
 * codec.hpp
 * 编解码器框架 - 协议层核心组件
 */

#pragma once

#include <memory>
#include <string>
#include <functional>

namespace netlib {

class TcpConnection;
class Buffer;

/**
 * Codec编解码管道
 *
 * ┌─────────────────────────────────────────────────────────────────┐
 * │                       编解码管道                                │
 * ├─────────────────────────────────────────────────────────────────┤
 * │                                                                 │
 * │   发送方向 (Encode):                                            │
 * │   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
 * │   │ 应用数据  │→│ 序列化   │→│  压缩    │→│ 分帧添加  │→ 发送 │
 * │   │ (object) │  │(protobuf)│  │ (lz4)   │  │ (header) │      │
 * │   └──────────┘  └──────────┘  └──────────┘  └──────────┘      │
 * │                                                                 │
 * │   接收方向 (Decode):                                            │
 * │   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
 * │   │ 应用数据  │←│ 反序列化  │←│  解压    │←│ 分帧解析  │← 接收│
 * │   │ (object) │  │(protobuf)│  │ (lz4)   │  │ (header) │      │
 * │   └──────────┘  └──────────┘  └──────────┘  └──────────┘      │
 * │                                                                 │
 * └─────────────────────────────────────────────────────────────────┘
 */

// 消息结构
struct RpcMessage {
    uint32_t requestId;
    uint8_t  type;       // 0=请求, 1=响应, 2=心跳
    uint8_t  codecType;  // 序列化类型
    uint8_t  compressType;
    std::string serviceName;
    std::string methodName;
    std::string payload;
    int32_t  errorCode;
    std::string errorMessage;
};

// 编解码器抽象基类
class Codec {
public:
    using MessageCallback = std::function<void(
        const std::shared_ptr<TcpConnection>&,
        const RpcMessage&)>;

    virtual ~Codec() = default;

    // 编码：消息 → 字节流
    virtual void encode(const std::shared_ptr<TcpConnection>& conn,
                       const RpcMessage& msg) = 0;

    // 解码入口（由TcpConnection的消息回调触发）
    virtual void onMessage(const std::shared_ptr<TcpConnection>& conn,
                           Buffer* buf) = 0;

    void setMessageCallback(MessageCallback cb) {
        messageCallback_ = std::move(cb);
    }

protected:
    MessageCallback messageCallback_;
};

/**
 * RPC协议编解码器
 *
 * 协议格式:
 * ┌────────────────────────────────────────────────────────┐
 * │                    RPC Protocol Frame                   │
 * ├────────┬────────┬────────┬────────┬────────────────────┤
 * │ Magic  │Version │ Type   │Codec   │Compress            │
 * │4 bytes │1 byte  │1 byte  │1 byte  │1 byte              │
 * ├────────┴────────┴────────┴────────┴────────────────────┤
 * │ RequestId              │BodyLength                     │
 * │ 4 bytes                │ 4 bytes                       │
 * ├────────────────────────┴───────────────────────────────┤
 * │ ServiceName (length-prefixed string)                   │
 * ├────────────────────────────────────────────────────────┤
 * │ MethodName  (length-prefixed string)                   │
 * ├────────────────────────────────────────────────────────┤
 * │ Payload     (serialized data)                          │
 * └────────────────────────────────────────────────────────┘
 */

class RpcCodec : public Codec {
public:
    static constexpr uint32_t MAGIC = 0x4E455442; // "NETB"
    static constexpr size_t MIN_HEADER_SIZE = 16;

    void encode(const std::shared_ptr<TcpConnection>& conn,
               const RpcMessage& msg) override {
        Buffer buf;

        // 写入协议头(先跳过，最后填入body长度)
        buf.appendInt32(static_cast<int32_t>(MAGIC));

        uint8_t version = 1;
        buf.append(&version, 1);
        buf.append(&msg.type, 1);
        buf.append(&msg.codecType, 1);
        buf.append(&msg.compressType, 1);
        buf.appendInt32(static_cast<int32_t>(msg.requestId));

        // body长度占位
        size_t bodyLenIndex = buf.readableBytes();
        buf.appendInt32(0);

        size_t bodyStart = buf.readableBytes();

        // 写入service name
        buf.appendInt16(static_cast<int16_t>(msg.serviceName.size()));
        buf.append(msg.serviceName);

        // 写入method name
        buf.appendInt16(static_cast<int16_t>(msg.methodName.size()));
        buf.append(msg.methodName);

        // 写入错误信息（仅响应包）
        if (msg.type == 1) {
            buf.appendInt32(msg.errorCode);
            buf.appendInt16(static_cast<int16_t>(msg.errorMessage.size()));
            buf.append(msg.errorMessage);
        }

        // 写入payload
        buf.append(msg.payload);

        // 回填body长度
        size_t bodyLen = buf.readableBytes() - bodyStart;
        const char* bodyLenPtr = buf.peek() + bodyLenIndex;
        int32_t be32 = htobe32(static_cast<int32_t>(bodyLen));
        // 直接修改buffer中的数据（此处简化处理）

        conn->send(&buf);
    }

    void onMessage(const std::shared_ptr<TcpConnection>& conn,
                   Buffer* buf) override {
        while (buf->readableBytes() >= MIN_HEADER_SIZE) {
            // 检查magic
            int32_t magic = buf->peekInt32();
            if (static_cast<uint32_t>(magic) != MAGIC) {
                // 协议错误
                conn->shutdown();
                return;
            }

            // 读取body长度
            const char* data = buf->peek();
            int32_t bodyLen = 0;
            memcpy(&bodyLen, data + 12, sizeof(int32_t));
            bodyLen = be32toh(bodyLen);

            if (bodyLen < 0) {
                conn->shutdown();
                return;
            }

            size_t totalLen = MIN_HEADER_SIZE + bodyLen;
            if (buf->readableBytes() < totalLen) {
                // 数据不够，等待更多数据
                break;
            }

            // 解析完整消息
            RpcMessage msg;
            parseMessage(buf, totalLen, &msg);

            if (messageCallback_) {
                messageCallback_(conn, msg);
            }
        }
    }

private:
    void parseMessage(Buffer* buf, size_t totalLen, RpcMessage* msg) {
        // 跳过magic
        buf->retrieve(4);

        // 读取header
        uint8_t version, type, codec, compress;
        memcpy(&version, buf->peek(), 1); buf->retrieve(1);
        memcpy(&type, buf->peek(), 1); buf->retrieve(1);
        memcpy(&codec, buf->peek(), 1); buf->retrieve(1);
        memcpy(&compress, buf->peek(), 1); buf->retrieve(1);

        msg->type = type;
        msg->codecType = codec;
        msg->compressType = compress;
        msg->requestId = static_cast<uint32_t>(buf->readInt32());

        int32_t bodyLen = buf->readInt32();

        // 读取service name
        int16_t serviceLen = buf->readInt16();
        msg->serviceName = buf->retrieveAsString(serviceLen);

        // 读取method name
        int16_t methodLen = buf->readInt16();
        msg->methodName = buf->retrieveAsString(methodLen);

        // 读取错误信息（仅响应）
        if (type == 1) {
            msg->errorCode = buf->readInt32();
            int16_t errLen = buf->readInt16();
            msg->errorMessage = buf->retrieveAsString(errLen);
        }

        // 剩余为payload
        size_t consumed = 4 + serviceLen + 4 + methodLen;
        if (type == 1) consumed += 6; // errorCode + errLen
        size_t payloadLen = bodyLen - consumed;
        msg->payload = buf->retrieveAsString(payloadLen);
    }
};

} // namespace netlib
```

#### TcpServer服务器

```cpp
/**
 * tcp_server.hpp
 * TCP服务器 - 管理所有连接的生命周期
 */

#pragma once

#include <memory>
#include <string>
#include <map>
#include <functional>
#include <atomic>

namespace netlib {

/**
 * TcpServer 架构
 *
 * ┌─────────────────────────────────────────────────────────────────┐
 * │                         TcpServer                               │
 * ├─────────────────────────────────────────────────────────────────┤
 * │                                                                 │
 * │   ┌─────────────┐     新连接     ┌─────────────────────┐       │
 * │   │  Acceptor   │───────────────►│EventLoopThreadPool  │       │
 * │   │  (主loop)   │               │  (IO线程池)          │       │
 * │   └─────────────┘               └──────────┬──────────┘       │
 * │                                             │                  │
 * │                                    分发到SubLoop               │
 * │                                             │                  │
 * │                              ┌──────────────┼──────────┐      │
 * │                              ▼              ▼          ▼      │
 * │                        ┌──────────┐  ┌──────────┐ ┌────────┐  │
 * │                        │TcpConn 1 │  │TcpConn 2 │ │  ...   │  │
 * │                        └──────────┘  └──────────┘ └────────┘  │
 * │                                                                 │
 * │   connections_ (std::map管理所有连接)                           │
 * │                                                                 │
 * └─────────────────────────────────────────────────────────────────┘
 */

class TcpServer {
public:
    using ConnectionCallback = std::function<void(
        const std::shared_ptr<TcpConnection>&)>;
    using MessageCallback = std::function<void(
        const std::shared_ptr<TcpConnection>&, Buffer*)>;
    using WriteCompleteCallback = std::function<void(
        const std::shared_ptr<TcpConnection>&)>;
    using ThreadInitCallback = std::function<void(EventLoop*)>;

    TcpServer(EventLoop* loop,
              const InetAddress& listenAddr,
              const std::string& name,
              bool reusePort = false);
    ~TcpServer();

    // 禁止拷贝
    TcpServer(const TcpServer&) = delete;
    TcpServer& operator=(const TcpServer&) = delete;

    // 配置
    void setThreadNum(int numThreads);
    void setThreadInitCallback(const ThreadInitCallback& cb) {
        threadInitCallback_ = cb;
    }

    // 启动服务器
    void start();

    // 设置回调
    void setConnectionCallback(const ConnectionCallback& cb) {
        connectionCallback_ = cb;
    }
    void setMessageCallback(const MessageCallback& cb) {
        messageCallback_ = cb;
    }
    void setWriteCompleteCallback(const WriteCompleteCallback& cb) {
        writeCompleteCallback_ = cb;
    }

    // 获取信息
    const std::string& name() const { return name_; }
    EventLoop* getLoop() const { return loop_; }
    const std::string& ipPort() const { return ipPort_; }

private:
    void newConnection(int sockfd, const InetAddress& peerAddr);
    void removeConnection(const std::shared_ptr<TcpConnection>& conn);
    void removeConnectionInLoop(const std::shared_ptr<TcpConnection>& conn);

    EventLoop* loop_;  // Main Reactor
    const std::string ipPort_;
    const std::string name_;

    std::unique_ptr<Acceptor> acceptor_;
    std::shared_ptr<EventLoopThreadPool> threadPool_;

    ConnectionCallback connectionCallback_;
    MessageCallback messageCallback_;
    WriteCompleteCallback writeCompleteCallback_;
    ThreadInitCallback threadInitCallback_;

    std::atomic<bool> started_;
    int nextConnId_;

    using ConnectionMap = std::map<std::string,
                                    std::shared_ptr<TcpConnection>>;
    ConnectionMap connections_;
};

// 实现
TcpServer::TcpServer(EventLoop* loop,
                      const InetAddress& listenAddr,
                      const std::string& name,
                      bool reusePort)
    : loop_(loop)
    , ipPort_(listenAddr.toIpPort())
    , name_(name)
    , acceptor_(std::make_unique<Acceptor>(loop, listenAddr, reusePort))
    , threadPool_(std::make_shared<EventLoopThreadPool>(loop, name))
    , started_(false)
    , nextConnId_(1) {

    acceptor_->setNewConnectionCallback(
        [this](int sockfd, const InetAddress& peerAddr) {
            newConnection(sockfd, peerAddr);
        });
}

TcpServer::~TcpServer() {
    loop_->assertInLoopThread();
    for (auto& [name, conn] : connections_) {
        auto c = conn;
        conn.reset();
        c->getLoop()->runInLoop([c]() {
            c->connectDestroyed();
        });
    }
}

void TcpServer::setThreadNum(int numThreads) {
    threadPool_->setThreadNum(numThreads);
}

void TcpServer::start() {
    if (!started_.exchange(true)) {
        threadPool_->start(threadInitCallback_);

        loop_->runInLoop([this]() {
            acceptor_->listen();
        });
    }
}

void TcpServer::newConnection(int sockfd, const InetAddress& peerAddr) {
    loop_->assertInLoopThread();

    // 选择一个IO线程
    EventLoop* ioLoop = threadPool_->getNextLoop();

    std::string connName = name_ + "-" +
                           ipPort_ + "#" +
                           std::to_string(nextConnId_++);

    InetAddress localAddr(Socket::getLocalAddr(sockfd));

    auto conn = std::make_shared<TcpConnection>(
        ioLoop, connName, sockfd, localAddr, peerAddr);

    connections_[connName] = conn;

    conn->setConnectionCallback(connectionCallback_);
    conn->setMessageCallback(messageCallback_);
    conn->setWriteCompleteCallback(writeCompleteCallback_);
    conn->setCloseCallback(
        [this](const std::shared_ptr<TcpConnection>& c) {
            removeConnection(c);
        });

    // 在IO线程中建立连接
    ioLoop->runInLoop([conn]() {
        conn->connectEstablished();
    });
}

void TcpServer::removeConnection(
    const std::shared_ptr<TcpConnection>& conn) {
    loop_->runInLoop([this, conn]() {
        removeConnectionInLoop(conn);
    });
}

void TcpServer::removeConnectionInLoop(
    const std::shared_ptr<TcpConnection>& conn) {
    loop_->assertInLoopThread();
    connections_.erase(conn->name());

    EventLoop* ioLoop = conn->getLoop();
    ioLoop->queueInLoop([conn]() {
        conn->connectDestroyed();
    });
}

} // namespace netlib
```

---

### Day 18-19: RPC服务层

#### RPC服务注册与调用

```cpp
/**
 * rpc_service.hpp
 * RPC服务框架 - 服务注册、路由、调用管理
 */

#pragma once

#include <string>
#include <memory>
#include <unordered_map>
#include <functional>
#include <future>
#include <mutex>
#include <atomic>
#include <chrono>

namespace netlib {

/**
 * RPC服务层架构
 *
 * ┌─────────────────────────────────────────────────────────────────┐
 * │                        RPC Service Layer                        │
 * ├─────────────────────────────────────────────────────────────────┤
 * │                                                                 │
 * │   ┌─────────────────────────────────────────────────┐          │
 * │   │              ServiceRegistry                     │          │
 * │   │  ┌─────────────┬─────────────┬──────────────┐   │          │
 * │   │  │ UserService │OrderService │ PayService   │   │          │
 * │   │  │ - getUser  │ - create   │ - pay        │   │          │
 * │   │  │ - addUser  │ - query    │ - refund     │   │          │
 * │   │  └─────────────┴─────────────┴──────────────┘   │          │
 * │   └──────────────────────┬──────────────────────────┘          │
 * │                          │                                      │
 * │                          ▼                                      │
 * │   ┌─────────────────────────────────────────────────┐          │
 * │   │                RpcRouter                         │          │
 * │   │  serviceName.methodName ──► handler              │          │
 * │   └──────────────────────┬──────────────────────────┘          │
 * │                          │                                      │
 * │              ┌───────────┴───────────┐                         │
 * │              ▼                       ▼                         │
 * │   ┌──────────────────┐   ┌──────────────────┐                 │
 * │   │    RpcServer     │   │    RpcClient     │                 │
 * │   │  接收请求→处理    │   │  发送请求→等待   │                 │
 * │   └──────────────────┘   └──────────────────┘                 │
 * │                                                                 │
 * └─────────────────────────────────────────────────────────────────┘
 */

// RPC方法处理函数类型
using RpcMethodHandler = std::function<std::string(const std::string& request)>;

// 服务描述
class ServiceDescriptor {
public:
    ServiceDescriptor(const std::string& name) : name_(name) {}

    // 注册方法
    void addMethod(const std::string& methodName, RpcMethodHandler handler) {
        methods_[methodName] = std::move(handler);
    }

    // 调用方法
    bool callMethod(const std::string& methodName,
                    const std::string& request,
                    std::string* response) {
        auto it = methods_.find(methodName);
        if (it == methods_.end()) {
            return false;
        }
        *response = it->second(request);
        return true;
    }

    const std::string& name() const { return name_; }

    bool hasMethod(const std::string& methodName) const {
        return methods_.count(methodName) > 0;
    }

private:
    std::string name_;
    std::unordered_map<std::string, RpcMethodHandler> methods_;
};

// 服务注册中心
class ServiceRegistry {
public:
    static ServiceRegistry& instance() {
        static ServiceRegistry registry;
        return registry;
    }

    // 注册服务
    void registerService(std::shared_ptr<ServiceDescriptor> service) {
        std::lock_guard<std::mutex> lock(mutex_);
        services_[service->name()] = std::move(service);
    }

    // 查找服务
    std::shared_ptr<ServiceDescriptor> findService(const std::string& name) {
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = services_.find(name);
        if (it != services_.end()) {
            return it->second;
        }
        return nullptr;
    }

    // 列出所有服务
    std::vector<std::string> listServices() const {
        std::lock_guard<std::mutex> lock(mutex_);
        std::vector<std::string> names;
        for (const auto& [name, _] : services_) {
            names.push_back(name);
        }
        return names;
    }

private:
    ServiceRegistry() = default;
    mutable std::mutex mutex_;
    std::unordered_map<std::string, std::shared_ptr<ServiceDescriptor>> services_;
};

// RPC服务端
class RpcServer {
public:
    RpcServer(EventLoop* loop, const InetAddress& addr)
        : server_(loop, addr, "RpcServer")
        , codec_(std::make_unique<RpcCodec>()) {

        server_.setConnectionCallback(
            [this](const std::shared_ptr<TcpConnection>& conn) {
                onConnection(conn);
            });

        server_.setMessageCallback(
            [this](const std::shared_ptr<TcpConnection>& conn, Buffer* buf) {
                codec_->onMessage(conn, buf);
            });

        codec_->setMessageCallback(
            [this](const std::shared_ptr<TcpConnection>& conn,
                   const RpcMessage& msg) {
                onRpcMessage(conn, msg);
            });
    }

    void setThreadNum(int n) { server_.setThreadNum(n); }

    void start() { server_.start(); }

    // 注册服务
    void registerService(std::shared_ptr<ServiceDescriptor> service) {
        ServiceRegistry::instance().registerService(std::move(service));
    }

private:
    void onConnection(const std::shared_ptr<TcpConnection>& conn) {
        if (conn->connected()) {
            // 连接建立
        } else {
            // 连接断开
        }
    }

    void onRpcMessage(const std::shared_ptr<TcpConnection>& conn,
                      const RpcMessage& request) {
        RpcMessage response;
        response.requestId = request.requestId;
        response.type = 1; // 响应
        response.codecType = request.codecType;
        response.compressType = request.compressType;
        response.serviceName = request.serviceName;
        response.methodName = request.methodName;

        // 查找服务
        auto service = ServiceRegistry::instance()
                       .findService(request.serviceName);
        if (!service) {
            response.errorCode = -1;
            response.errorMessage = "Service not found: " +
                                     request.serviceName;
            codec_->encode(conn, response);
            return;
        }

        // 调用方法
        std::string result;
        if (!service->callMethod(request.methodName,
                                  request.payload, &result)) {
            response.errorCode = -2;
            response.errorMessage = "Method not found: " +
                                     request.methodName;
            codec_->encode(conn, response);
            return;
        }

        response.errorCode = 0;
        response.payload = result;
        codec_->encode(conn, response);
    }

    TcpServer server_;
    std::unique_ptr<RpcCodec> codec_;
};

// RPC客户端
class RpcClient {
public:
    using RpcCallback = std::function<void(const RpcMessage& response)>;

    RpcClient(EventLoop* loop, const InetAddress& serverAddr)
        : loop_(loop)
        , client_(loop, serverAddr, "RpcClient")
        , codec_(std::make_unique<RpcCodec>())
        , nextRequestId_(0) {

        client_.setConnectionCallback(
            [this](const std::shared_ptr<TcpConnection>& conn) {
                onConnection(conn);
            });

        client_.setMessageCallback(
            [this](const std::shared_ptr<TcpConnection>& conn, Buffer* buf) {
                codec_->onMessage(conn, buf);
            });

        codec_->setMessageCallback(
            [this](const std::shared_ptr<TcpConnection>& conn,
                   const RpcMessage& msg) {
                onRpcResponse(conn, msg);
            });
    }

    void connect() { client_.connect(); }

    // 异步调用
    void callAsync(const std::string& service,
                   const std::string& method,
                   const std::string& request,
                   RpcCallback callback,
                   double timeoutSec = 5.0) {
        uint32_t reqId = nextRequestId_++;

        RpcMessage msg;
        msg.requestId = reqId;
        msg.type = 0; // 请求
        msg.codecType = 0;
        msg.compressType = 0;
        msg.serviceName = service;
        msg.methodName = method;
        msg.payload = request;

        {
            std::lock_guard<std::mutex> lock(mutex_);
            pendingCalls_[reqId] = std::move(callback);
        }

        if (connection_) {
            codec_->encode(connection_, msg);
        }

        // 超时处理
        loop_->runAfter(timeoutSec, [this, reqId]() {
            RpcCallback cb;
            {
                std::lock_guard<std::mutex> lock(mutex_);
                auto it = pendingCalls_.find(reqId);
                if (it != pendingCalls_.end()) {
                    cb = std::move(it->second);
                    pendingCalls_.erase(it);
                }
            }
            if (cb) {
                RpcMessage timeout;
                timeout.requestId = reqId;
                timeout.errorCode = -3;
                timeout.errorMessage = "RPC call timeout";
                cb(timeout);
            }
        });
    }

    // 同步调用（带Future）
    std::future<RpcMessage> callSync(const std::string& service,
                                      const std::string& method,
                                      const std::string& request,
                                      double timeoutSec = 5.0) {
        auto promise = std::make_shared<std::promise<RpcMessage>>();
        auto future = promise->get_future();

        callAsync(service, method, request,
                 [promise](const RpcMessage& response) {
                     promise->set_value(response);
                 }, timeoutSec);

        return future;
    }

private:
    void onConnection(const std::shared_ptr<TcpConnection>& conn) {
        if (conn->connected()) {
            connection_ = conn;
        } else {
            connection_.reset();
        }
    }

    void onRpcResponse(const std::shared_ptr<TcpConnection>& conn,
                       const RpcMessage& response) {
        RpcCallback cb;
        {
            std::lock_guard<std::mutex> lock(mutex_);
            auto it = pendingCalls_.find(response.requestId);
            if (it != pendingCalls_.end()) {
                cb = std::move(it->second);
                pendingCalls_.erase(it);
            }
        }

        if (cb) {
            cb(response);
        }
    }

    EventLoop* loop_;
    TcpClient client_;
    std::unique_ptr<RpcCodec> codec_;
    std::shared_ptr<TcpConnection> connection_;

    std::atomic<uint32_t> nextRequestId_;
    std::mutex mutex_;
    std::unordered_map<uint32_t, RpcCallback> pendingCalls_;
};

} // namespace netlib
```

---

### Day 20-21: 高级特性

#### 连接池与负载均衡

```cpp
/**
 * connection_pool.hpp
 * 连接池 - 复用TCP连接，避免频繁创建销毁
 */

#pragma once

#include <queue>
#include <mutex>
#include <condition_variable>
#include <chrono>
#include <memory>

namespace netlib {

/**
 * 连接池架构
 *
 * ┌──────────────────────────────────────────────────────────────┐
 * │                      ConnectionPool                          │
 * ├──────────────────────────────────────────────────────────────┤
 * │                                                              │
 * │   ┌────────────────────────────────────────────┐            │
 * │   │              idle connections               │            │
 * │   │  ┌────┐  ┌────┐  ┌────┐  ┌────┐  ┌────┐  │            │
 * │   │  │conn│  │conn│  │conn│  │conn│  │conn│  │            │
 * │   │  │ 1  │  │ 2  │  │ 3  │  │ 4  │  │ 5  │  │            │
 * │   │  └────┘  └────┘  └────┘  └────┘  └────┘  │            │
 * │   └────────────────────────────────────────────┘            │
 * │                                                              │
 * │   acquire() ──► 取出空闲连接                                 │
 * │   release() ──► 归还连接到池中                               │
 * │                                                              │
 * │   配置:                                                      │
 * │   - maxSize: 最大连接数                                      │
 * │   - minIdle: 最小空闲数                                      │
 * │   - maxIdleTime: 空闲超时                                    │
 * │   - healthCheck: 健康检查间隔                                │
 * │                                                              │
 * └──────────────────────────────────────────────────────────────┘
 */

struct ConnectionPoolConfig {
    std::string host;
    uint16_t port;
    size_t maxSize = 20;
    size_t minIdle = 5;
    int maxIdleTimeSec = 300;
    int connectTimeoutMs = 3000;
    int healthCheckIntervalSec = 30;
};

class ConnectionPool {
public:
    using ConnectionPtr = std::shared_ptr<TcpConnection>;

    explicit ConnectionPool(EventLoop* loop, const ConnectionPoolConfig& config)
        : loop_(loop)
        , config_(config)
        , totalCount_(0)
        , activeCount_(0) {
    }

    ~ConnectionPool() { shutdown(); }

    // 初始化连接池
    void init() {
        // 创建最小空闲连接
        for (size_t i = 0; i < config_.minIdle; ++i) {
            createConnection();
        }

        // 启动健康检查定时器
        loop_->runEvery(config_.healthCheckIntervalSec, [this]() {
            healthCheck();
        });
    }

    // 获取连接
    ConnectionPtr acquire(int timeoutMs = -1) {
        std::unique_lock<std::mutex> lock(mutex_);

        if (timeoutMs < 0) {
            // 无限等待
            cond_.wait(lock, [this]() {
                return !idleConnections_.empty() ||
                       totalCount_ < config_.maxSize;
            });
        } else {
            // 超时等待
            bool ok = cond_.wait_for(lock,
                std::chrono::milliseconds(timeoutMs),
                [this]() {
                    return !idleConnections_.empty() ||
                           totalCount_ < config_.maxSize;
                });
            if (!ok) return nullptr; // 超时
        }

        ConnectionPtr conn;
        if (!idleConnections_.empty()) {
            conn = idleConnections_.front();
            idleConnections_.pop();
        } else {
            // 创建新连接
            lock.unlock();
            conn = createConnection();
            lock.lock();
        }

        ++activeCount_;
        return conn;
    }

    // 归还连接
    void release(ConnectionPtr conn) {
        std::lock_guard<std::mutex> lock(mutex_);
        --activeCount_;

        if (conn && conn->connected()) {
            idleConnections_.push(std::move(conn));
            cond_.notify_one();
        } else {
            --totalCount_;
        }
    }

    // 关闭连接池
    void shutdown() {
        std::lock_guard<std::mutex> lock(mutex_);
        while (!idleConnections_.empty()) {
            auto conn = idleConnections_.front();
            idleConnections_.pop();
            conn->forceClose();
        }
        totalCount_ = 0;
        activeCount_ = 0;
    }

    // 统计信息
    size_t totalConnections() const { return totalCount_; }
    size_t activeConnections() const { return activeCount_; }
    size_t idleConnections() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return idleConnections_.size();
    }

private:
    ConnectionPtr createConnection() {
        // 创建TCP连接（简化实现）
        ++totalCount_;
        return nullptr; // 实际需要通过Connector创建
    }

    void healthCheck() {
        std::lock_guard<std::mutex> lock(mutex_);
        size_t count = idleConnections_.size();
        std::queue<ConnectionPtr> healthy;

        for (size_t i = 0; i < count; ++i) {
            auto conn = idleConnections_.front();
            idleConnections_.pop();

            if (conn && conn->connected()) {
                healthy.push(std::move(conn));
            } else {
                --totalCount_;
            }
        }

        idleConnections_ = std::move(healthy);
    }

    EventLoop* loop_;
    ConnectionPoolConfig config_;

    mutable std::mutex mutex_;
    std::condition_variable cond_;
    std::queue<ConnectionPtr> idleConnections_;
    std::atomic<size_t> totalCount_;
    std::atomic<size_t> activeCount_;
};

} // namespace netlib
```

#### 限流器

```cpp
/**
 * rate_limiter.hpp
 * 限流器实现 - 令牌桶和滑动窗口算法
 */

#pragma once

#include <atomic>
#include <chrono>
#include <mutex>
#include <deque>

namespace netlib {

/**
 * 限流算法对比
 *
 * ┌────────────────────────────────────────────────────────────────┐
 * │                      限流策略对比                              │
 * ├────────────┬─────────────────┬────────────────────────────────┤
 * │   算法      │     特点         │     适用场景                  │
 * ├────────────┼─────────────────┼────────────────────────────────┤
 * │ 固定窗口   │ 简单，有窗口切换  │ 精度要求不高                  │
 * │            │ 突发问题          │                               │
 * │ 滑动窗口   │ 平滑，较精确      │ API限流                      │
 * │ 令牌桶     │ 允许突发，匀速    │ 网络流量整形                  │
 * │ 漏桶       │ 严格匀速          │ 消息队列消费                  │
 * └────────────┴─────────────────┴────────────────────────────────┘
 */

/**
 * 令牌桶限流器
 *
 * ┌────────────────────────────────────────────────────┐
 * │              Token Bucket                          │
 * ├────────────────────────────────────────────────────┤
 * │                                                    │
 * │   以固定速率添加令牌 ──► ┌──────────────────┐      │
 * │   (rate tokens/sec)     │   Token Bucket   │      │
 * │                          │  ┌──┬──┬──┬──┐  │      │
 * │                          │  │● │● │● │  │  │      │
 * │                          │  └──┴──┴──┴──┘  │      │
 * │                          │  capacity=4     │      │
 * │                          └───────┬──────────┘      │
 * │                                  │                 │
 * │   请求到达 ──────────────────────┘                 │
 * │   有令牌 ──► 允许通过，消耗一个令牌                 │
 * │   无令牌 ──► 拒绝或等待                            │
 * │                                                    │
 * └────────────────────────────────────────────────────┘
 */

class TokenBucketLimiter {
public:
    TokenBucketLimiter(double rate, double burst)
        : rate_(rate)
        , burst_(burst)
        , tokens_(burst)
        , lastTime_(std::chrono::steady_clock::now()) {
    }

    // 尝试获取令牌
    bool tryAcquire(double tokens = 1.0) {
        std::lock_guard<std::mutex> lock(mutex_);
        refill();

        if (tokens_ >= tokens) {
            tokens_ -= tokens;
            return true;
        }
        return false;
    }

    // 获取可用令牌数
    double availableTokens() {
        std::lock_guard<std::mutex> lock(mutex_);
        refill();
        return tokens_;
    }

private:
    void refill() {
        auto now = std::chrono::steady_clock::now();
        double elapsed = std::chrono::duration<double>(
            now - lastTime_).count();
        lastTime_ = now;

        tokens_ = std::min(burst_, tokens_ + elapsed * rate_);
    }

    double rate_;     // 令牌产生速率 (tokens/秒)
    double burst_;    // 桶容量
    double tokens_;   // 当前令牌数
    std::chrono::steady_clock::time_point lastTime_;
    std::mutex mutex_;
};

/**
 * 滑动窗口限流器
 *
 * ┌────────────────────────────────────────────────────┐
 * │           Sliding Window                           │
 * ├────────────────────────────────────────────────────┤
 * │                                                    │
 * │   时间轴:                                          │
 * │   ├──┤──┤──┤──┤──┤──┤──┤──┤──┤──┤                │
 * │        ↑                       ↑                   │
 * │   now - window              now                    │
 * │                                                    │
 * │   统计窗口内的请求数                                │
 * │   count <= maxRequests ──► 允许                    │
 * │   count >  maxRequests ──► 拒绝                    │
 * │                                                    │
 * └────────────────────────────────────────────────────┘
 */

class SlidingWindowLimiter {
public:
    SlidingWindowLimiter(size_t maxRequests, double windowSec)
        : maxRequests_(maxRequests)
        , windowDuration_(std::chrono::duration<double>(windowSec)) {
    }

    bool tryAcquire() {
        std::lock_guard<std::mutex> lock(mutex_);
        auto now = std::chrono::steady_clock::now();

        // 清除过期记录
        while (!timestamps_.empty() &&
               now - timestamps_.front() > windowDuration_) {
            timestamps_.pop_front();
        }

        if (timestamps_.size() < maxRequests_) {
            timestamps_.push_back(now);
            return true;
        }
        return false;
    }

    size_t currentCount() {
        std::lock_guard<std::mutex> lock(mutex_);
        auto now = std::chrono::steady_clock::now();
        while (!timestamps_.empty() &&
               now - timestamps_.front() > windowDuration_) {
            timestamps_.pop_front();
        }
        return timestamps_.size();
    }

private:
    size_t maxRequests_;
    std::chrono::duration<double> windowDuration_;
    std::deque<std::chrono::steady_clock::time_point> timestamps_;
    std::mutex mutex_;
};

/**
 * 熔断器 - Circuit Breaker
 *
 * ┌────────────────────────────────────────────────────┐
 * │              Circuit Breaker                       │
 * ├────────────────────────────────────────────────────┤
 * │                                                    │
 * │   ┌──────────┐  失败率过高   ┌──────────┐         │
 * │   │  CLOSED  │──────────────►│   OPEN   │         │
 * │   │ (正常)   │              │  (熔断)  │         │
 * │   └────▲─────┘              └────┬─────┘         │
 * │        │                         │                │
 * │        │ 成功              超时后│                │
 * │        │                         ▼                │
 * │        │                   ┌──────────┐          │
 * │        └───────────────────│HALF-OPEN │          │
 * │            测试请求成功    │ (半开)   │          │
 * │                            └──────────┘          │
 * │                                                    │
 * └────────────────────────────────────────────────────┘
 */

class CircuitBreaker {
public:
    enum State { CLOSED, OPEN, HALF_OPEN };

    struct Config {
        size_t failureThreshold = 5;     // 触发熔断的失败次数
        double openTimeoutSec = 30.0;    // 熔断持续时间
        size_t halfOpenMaxCalls = 3;     // 半开状态最大测试次数
    };

    explicit CircuitBreaker(const Config& config = Config())
        : config_(config)
        , state_(CLOSED)
        , failureCount_(0)
        , successCount_(0)
        , halfOpenCalls_(0) {
    }

    // 判断是否允许调用
    bool allowRequest() {
        std::lock_guard<std::mutex> lock(mutex_);

        switch (state_) {
            case CLOSED:
                return true;
            case OPEN: {
                auto now = std::chrono::steady_clock::now();
                if (now - openTime_ > std::chrono::duration<double>(
                        config_.openTimeoutSec)) {
                    state_ = HALF_OPEN;
                    halfOpenCalls_ = 0;
                    return true;
                }
                return false;
            }
            case HALF_OPEN:
                return halfOpenCalls_ < config_.halfOpenMaxCalls;
        }
        return false;
    }

    // 记录成功
    void recordSuccess() {
        std::lock_guard<std::mutex> lock(mutex_);

        switch (state_) {
            case CLOSED:
                failureCount_ = 0;
                break;
            case HALF_OPEN:
                ++successCount_;
                if (successCount_ >= config_.halfOpenMaxCalls) {
                    state_ = CLOSED;
                    failureCount_ = 0;
                    successCount_ = 0;
                }
                break;
            default:
                break;
        }
    }

    // 记录失败
    void recordFailure() {
        std::lock_guard<std::mutex> lock(mutex_);

        switch (state_) {
            case CLOSED:
                ++failureCount_;
                if (failureCount_ >= config_.failureThreshold) {
                    state_ = OPEN;
                    openTime_ = std::chrono::steady_clock::now();
                }
                break;
            case HALF_OPEN:
                state_ = OPEN;
                openTime_ = std::chrono::steady_clock::now();
                break;
            default:
                break;
        }
    }

    State state() const { return state_; }

private:
    Config config_;
    State state_;
    size_t failureCount_;
    size_t successCount_;
    size_t halfOpenCalls_;
    std::chrono::steady_clock::time_point openTime_;
    std::mutex mutex_;
};

} // namespace netlib
```

---

### Week 3 输出物清单

| 文件 | 说明 | 完成状态 |
|------|------|---------|
| `netlib/codec.hpp` | 编解码器框架 | [ ] |
| `netlib/rpc_codec.hpp` | RPC协议编解码 | [ ] |
| `netlib/tcp_server.hpp` | TCP服务器 | [ ] |
| `netlib/rpc_service.hpp` | RPC服务注册与调用 | [ ] |
| `netlib/rpc_server.hpp` | RPC服务端 | [ ] |
| `netlib/rpc_client.hpp` | RPC客户端 | [ ] |
| `netlib/connection_pool.hpp` | 连接池 | [ ] |
| `netlib/rate_limiter.hpp` | 限流器 | [ ] |
| `netlib/circuit_breaker.hpp` | 熔断器 | [ ] |
| `notes/week3_protocol_service.md` | 本周学习笔记 | [ ] |

### Week 3 验收标准

- [ ] 理解编解码管道的处理流程
- [ ] 能够实现RPC协议的编解码
- [ ] 掌握TcpServer的连接管理机制
- [ ] 理解服务注册与路由分发
- [ ] 能够实现异步和同步RPC调用
- [ ] 掌握连接池的设计与实现
- [ ] 理解令牌桶和滑动窗口限流
- [ ] 能够实现熔断器模式

---

## Week 4: 测试、优化与文档（35小时）

### 本周目标
```
┌─────────────────────────────────────────────────────────────────┐
│  Week 4: 测试 + 优化 + 文档                                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Day 22-23: 测试                                                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │  单元测试    │  │  集成测试    │  │  压力测试    │            │
│  │  Buffer     │  │  RPC端到端  │  │  并发连接    │            │
│  │  Channel    │  │  消息收发    │  │  吞吐量     │            │
│  │  Timer      │  │  服务治理    │  │  延迟分布    │            │
│  └─────────────┘  └─────────────┘  └─────────────┘            │
│                                                                 │
│  Day 24-25: 性能优化                                            │
│  ┌───────────────────────────────────────────────────────┐     │
│  │  性能分析 → 瓶颈定位 → 优化实施 → 回归验证           │     │
│  └───────────────────────────────────────────────────────┘     │
│                                                                 │
│  Day 26-28: 文档与总结                                          │
│  ┌───────────────────────────────────────────────────────┐     │
│  │  API文档 + 架构文档 + 第三年学习总结                   │     │
│  └───────────────────────────────────────────────────────┘     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 每日任务分解

| Day | 时间 | 上午任务(2.5h) | 下午任务(2.5h) | 输出物 |
|-----|------|---------------|---------------|--------|
| 22 | 5h | Buffer/Channel单元测试 | Timer/EventLoop单元测试 | unit_tests.cpp |
| 23 | 5h | RPC端到端集成测试 | 服务治理集成测试 | integration_tests.cpp |
| 24 | 5h | Benchmark框架搭建 | 吞吐量和延迟测试 | benchmark.cpp |
| 25 | 5h | 性能瓶颈分析 | 优化实施与验证 | optimization_notes.md |
| 26 | 5h | API文档编写 | 架构设计文档 | api_reference.md |
| 27 | 5h | 使用示例编写 | 架构文档完善 | examples.cpp |
| 28 | 5h | 第三年学习总结 | 第四年规划预览 | year3_summary.md |

---

### Day 22-23: 测试

#### 单元测试框架

```cpp
/**
 * unit_tests.cpp
 * NetLib 单元测试
 */

#include <cassert>
#include <iostream>
#include <string>
#include <functional>
#include <vector>

namespace netlib {
namespace test {

/**
 * 测试框架设计
 *
 * ┌─────────────────────────────────────────────────────────────┐
 * │                     测试金字塔                              │
 * ├─────────────────────────────────────────────────────────────┤
 * │                                                             │
 * │                    ┌───────┐                               │
 * │                    │  E2E  │  ← 端到端测试(少)              │
 * │                   ─┤       ├─                               │
 * │                 ┌──┤       ├──┐                             │
 * │                 │  Integration │ ← 集成测试(中)             │
 * │               ──┤             ├──                           │
 * │             ┌───┤             ├───┐                         │
 * │             │   │ Unit Tests  │   │ ← 单元测试(多)          │
 * │           ──┴───┴─────────────┴───┴──                       │
 * │                                                             │
 * │   单元测试: 每个类/函数的独立测试                            │
 * │   集成测试: 模块间交互测试                                   │
 * │   端到端测试: 完整RPC调用流程测试                            │
 * │                                                             │
 * └─────────────────────────────────────────────────────────────┘
 */

// 简单测试框架
class TestRunner {
public:
    using TestFunc = std::function<void()>;

    struct TestCase {
        std::string name;
        TestFunc func;
    };

    static TestRunner& instance() {
        static TestRunner runner;
        return runner;
    }

    void addTest(const std::string& name, TestFunc func) {
        tests_.push_back({name, std::move(func)});
    }

    int runAll() {
        int passed = 0, failed = 0;
        std::cout << "Running " << tests_.size() << " tests...\n";
        std::cout << "========================================\n";

        for (const auto& test : tests_) {
            std::cout << "[ RUN  ] " << test.name << std::endl;
            try {
                test.func();
                std::cout << "[ PASS ] " << test.name << std::endl;
                ++passed;
            } catch (const std::exception& e) {
                std::cout << "[ FAIL ] " << test.name
                         << ": " << e.what() << std::endl;
                ++failed;
            }
        }

        std::cout << "========================================\n";
        std::cout << "Total: " << tests_.size()
                 << ", Passed: " << passed
                 << ", Failed: " << failed << std::endl;

        return failed;
    }

private:
    std::vector<TestCase> tests_;
};

#define TEST(name) \
    void test_##name(); \
    static bool _reg_##name = []() { \
        TestRunner::instance().addTest(#name, test_##name); \
        return true; \
    }(); \
    void test_##name()

#define ASSERT_EQ(a, b) \
    if ((a) != (b)) throw std::runtime_error( \
        std::string("ASSERT_EQ failed: ") + #a + " != " + #b)

#define ASSERT_TRUE(expr) \
    if (!(expr)) throw std::runtime_error( \
        std::string("ASSERT_TRUE failed: ") + #expr)

#define ASSERT_FALSE(expr) \
    if (expr) throw std::runtime_error( \
        std::string("ASSERT_FALSE failed: ") + #expr)

// ==================== Buffer 测试 ====================

TEST(Buffer_AppendAndRead) {
    Buffer buf;
    ASSERT_EQ(buf.readableBytes(), 0u);
    ASSERT_EQ(buf.writableBytes(), Buffer::kInitialSize);
    ASSERT_EQ(buf.prependableBytes(), Buffer::kCheapPrepend);

    const std::string str(200, 'x');
    buf.append(str);
    ASSERT_EQ(buf.readableBytes(), str.size());
    ASSERT_EQ(buf.writableBytes(), Buffer::kInitialSize - str.size());

    const std::string str2 = buf.retrieveAsString(50);
    ASSERT_EQ(str2.size(), 50u);
    ASSERT_EQ(buf.readableBytes(), str.size() - 50);
    ASSERT_EQ(buf.prependableBytes(), Buffer::kCheapPrepend + 50);
}

TEST(Buffer_Grow) {
    Buffer buf;
    buf.append(std::string(400, 'y'));
    ASSERT_EQ(buf.readableBytes(), 400u);

    buf.retrieve(50);
    ASSERT_EQ(buf.readableBytes(), 350u);

    buf.append(std::string(1000, 'z'));
    ASSERT_EQ(buf.readableBytes(), 1350u);
}

TEST(Buffer_Prepend) {
    Buffer buf;
    buf.append("hello");
    ASSERT_EQ(buf.readableBytes(), 5u);

    int32_t len = buf.readableBytes();
    buf.prepend(&len, sizeof(len));
    ASSERT_EQ(buf.readableBytes(), 9u);
}

TEST(Buffer_ReadInt) {
    Buffer buf;
    buf.appendInt32(42);
    buf.appendInt16(100);

    ASSERT_EQ(buf.readableBytes(), 6u);
    ASSERT_EQ(buf.readInt32(), 42);
    ASSERT_EQ(buf.readInt16(), 100);
    ASSERT_EQ(buf.readableBytes(), 0u);
}

TEST(Buffer_FindCRLF) {
    Buffer buf;
    buf.append("hello\r\nworld");
    const char* crlf = buf.findCRLF();
    ASSERT_TRUE(crlf != nullptr);
    ASSERT_EQ(static_cast<size_t>(crlf - buf.peek()), 5u);
}

// ==================== Channel 测试 ====================

TEST(Channel_BasicEvents) {
    // 测试Channel的事件标志设置
    // 注: 完整测试需要EventLoop，这里测试基本属性
    // 模拟测试
    ASSERT_TRUE(true); // placeholder
}

// ==================== Timer 测试 ====================

TEST(Timer_Creation) {
    bool called = false;
    auto now = std::chrono::system_clock::now();
    Timer timer([&called]() { called = true; },
                now + std::chrono::seconds(1),
                0.0);

    ASSERT_FALSE(timer.repeat());
    ASSERT_TRUE(timer.expiration() > now);

    timer.run();
    ASSERT_TRUE(called);
}

TEST(Timer_Repeat) {
    auto now = std::chrono::system_clock::now();
    Timer timer([]() {}, now, 1.0);  // 1秒间隔

    ASSERT_TRUE(timer.repeat());

    timer.restart(now);
    ASSERT_TRUE(timer.expiration() > now);
}

// ==================== TokenBucketLimiter 测试 ====================

TEST(TokenBucket_BasicLimit) {
    TokenBucketLimiter limiter(10.0, 10.0); // 10 tokens/sec, burst 10

    // 应该能获取10个令牌
    for (int i = 0; i < 10; ++i) {
        ASSERT_TRUE(limiter.tryAcquire());
    }
    // 第11个应该失败
    ASSERT_FALSE(limiter.tryAcquire());
}

TEST(SlidingWindow_BasicLimit) {
    SlidingWindowLimiter limiter(5, 1.0); // 每秒5个

    for (int i = 0; i < 5; ++i) {
        ASSERT_TRUE(limiter.tryAcquire());
    }
    ASSERT_FALSE(limiter.tryAcquire());
}

// ==================== CircuitBreaker 测试 ====================

TEST(CircuitBreaker_NormalFlow) {
    CircuitBreaker::Config config;
    config.failureThreshold = 3;
    config.openTimeoutSec = 1.0;
    CircuitBreaker cb(config);

    ASSERT_TRUE(cb.allowRequest());
    ASSERT_EQ(cb.state(), CircuitBreaker::CLOSED);

    // 3次失败触发熔断
    cb.recordFailure();
    cb.recordFailure();
    ASSERT_TRUE(cb.allowRequest()); // 还没到阈值
    cb.recordFailure();
    ASSERT_EQ(cb.state(), CircuitBreaker::OPEN);
    ASSERT_FALSE(cb.allowRequest());
}

} // namespace test
} // namespace netlib

// 运行所有测试
// int main() {
//     return netlib::test::TestRunner::instance().runAll();
// }
```

#### 集成测试

```cpp
/**
 * integration_tests.cpp
 * NetLib 集成测试 - 端到端测试RPC调用流程
 */

#include <thread>
#include <chrono>

namespace netlib {
namespace test {

/**
 * 集成测试场景
 *
 * ┌─────────────────────────────────────────────────────────────────┐
 * │                     集成测试场景                                │
 * ├─────────────────────────────────────────────────────────────────┤
 * │                                                                 │
 * │  场景1: 基本RPC调用                                            │
 * │  Client ──request──► Server ──response──► Client               │
 * │                                                                 │
 * │  场景2: 并发调用                                                │
 * │  Client1 ──►│                                                  │
 * │  Client2 ──►├──► Server ──► 响应所有                           │
 * │  Client3 ──►│                                                  │
 * │                                                                 │
 * │  场景3: 超时处理                                                │
 * │  Client ──request──► Server (慢处理) ──► Client timeout        │
 * │                                                                 │
 * │  场景4: 服务治理                                                │
 * │  Client ──► LoadBalancer ──► Server1/Server2/Server3           │
 * │                                                                 │
 * │  场景5: 熔断降级                                                │
 * │  Client ──► CircuitBreaker ──► 故障Server ──► 触发熔断         │
 * │                                                                 │
 * └─────────────────────────────────────────────────────────────────┘
 */

// 示例服务
class EchoServiceImpl {
public:
    static std::shared_ptr<ServiceDescriptor> createService() {
        auto service = std::make_shared<ServiceDescriptor>("EchoService");

        service->addMethod("echo", [](const std::string& request) {
            return "echo:" + request;
        });

        service->addMethod("reverse", [](const std::string& request) {
            std::string result = request;
            std::reverse(result.begin(), result.end());
            return result;
        });

        service->addMethod("upper", [](const std::string& request) {
            std::string result = request;
            for (auto& c : result) c = toupper(c);
            return result;
        });

        return service;
    }
};

// 计算服务
class CalcServiceImpl {
public:
    static std::shared_ptr<ServiceDescriptor> createService() {
        auto service = std::make_shared<ServiceDescriptor>("CalcService");

        service->addMethod("add", [](const std::string& request) {
            // 简化：假设请求格式为 "a,b"
            auto pos = request.find(',');
            int a = std::stoi(request.substr(0, pos));
            int b = std::stoi(request.substr(pos + 1));
            return std::to_string(a + b);
        });

        service->addMethod("multiply", [](const std::string& request) {
            auto pos = request.find(',');
            int a = std::stoi(request.substr(0, pos));
            int b = std::stoi(request.substr(pos + 1));
            return std::to_string(a * b);
        });

        return service;
    }
};

/**
 * 集成测试示例代码
 *
 * void testBasicRpc() {
 *     EventLoop loop;
 *     InetAddress addr(9900);
 *
 *     // 启动服务端
 *     RpcServer server(&loop, addr);
 *     server.registerService(EchoServiceImpl::createService());
 *     server.registerService(CalcServiceImpl::createService());
 *     server.setThreadNum(4);
 *     server.start();
 *
 *     // 在另一个线程启动客户端
 *     std::thread clientThread([&]() {
 *         EventLoop clientLoop;
 *         RpcClient client(&clientLoop, addr);
 *         client.connect();
 *
 *         // 同步调用
 *         auto future = client.callSync("EchoService", "echo", "hello");
 *         auto response = future.get();
 *         assert(response.errorCode == 0);
 *         assert(response.payload == "echo:hello");
 *
 *         // 异步调用
 *         client.callAsync("CalcService", "add", "3,4",
 *             [](const RpcMessage& resp) {
 *                 assert(resp.payload == "7");
 *             });
 *
 *         clientLoop.loop();
 *     });
 *
 *     loop.loop();
 *     clientThread.join();
 * }
 */

} // namespace test
} // namespace netlib
```

---

### Day 24-25: 性能测试与优化

#### 性能基准测试

```cpp
/**
 * benchmark.cpp
 * NetLib 性能基准测试
 */

#include <chrono>
#include <iostream>
#include <vector>
#include <numeric>
#include <algorithm>
#include <cmath>
#include <iomanip>

namespace netlib {
namespace bench {

/**
 * 性能测试指标
 *
 * ┌─────────────────────────────────────────────────────────────────┐
 * │                      性能测试指标                               │
 * ├─────────────────────────────────────────────────────────────────┤
 * │                                                                 │
 * │  吞吐量 (Throughput)                                           │
 * │  ├── QPS: 每秒请求数                                           │
 * │  ├── TPS: 每秒事务数                                           │
 * │  └── Bandwidth: 每秒数据传输量                                  │
 * │                                                                 │
 * │  延迟 (Latency)                                                │
 * │  ├── 平均延迟 (Mean)                                           │
 * │  ├── P50 (中位数)                                               │
 * │  ├── P95 (95分位)                                               │
 * │  ├── P99 (99分位)                                               │
 * │  └── P99.9 (99.9分位)                                          │
 * │                                                                 │
 * │  资源使用                                                       │
 * │  ├── CPU 使用率                                                 │
 * │  ├── 内存占用                                                   │
 * │  └── 文件描述符数量                                             │
 * │                                                                 │
 * └─────────────────────────────────────────────────────────────────┘
 */

struct BenchmarkResult {
    std::string name;
    size_t totalRequests;
    double totalTimeSec;
    double qps;
    double meanLatencyUs;
    double p50LatencyUs;
    double p95LatencyUs;
    double p99LatencyUs;
    double p999LatencyUs;
    double maxLatencyUs;
    double minLatencyUs;
    double stddevLatencyUs;
    size_t errorCount;
};

class BenchmarkRunner {
public:
    // 收集延迟数据
    void recordLatency(double latencyUs) {
        latencies_.push_back(latencyUs);
    }

    void recordError() {
        ++errorCount_;
    }

    // 计算统计数据
    BenchmarkResult calculate(const std::string& name,
                               double totalTimeSec) {
        BenchmarkResult result;
        result.name = name;
        result.totalRequests = latencies_.size() + errorCount_;
        result.totalTimeSec = totalTimeSec;
        result.errorCount = errorCount_;

        if (latencies_.empty()) return result;

        // 排序用于计算百分位
        std::sort(latencies_.begin(), latencies_.end());

        result.qps = latencies_.size() / totalTimeSec;
        result.minLatencyUs = latencies_.front();
        result.maxLatencyUs = latencies_.back();

        // 平均值
        double sum = std::accumulate(latencies_.begin(),
                                      latencies_.end(), 0.0);
        result.meanLatencyUs = sum / latencies_.size();

        // 标准差
        double sqSum = 0;
        for (double v : latencies_) {
            sqSum += (v - result.meanLatencyUs) *
                     (v - result.meanLatencyUs);
        }
        result.stddevLatencyUs = std::sqrt(sqSum / latencies_.size());

        // 百分位数
        result.p50LatencyUs = percentile(50);
        result.p95LatencyUs = percentile(95);
        result.p99LatencyUs = percentile(99);
        result.p999LatencyUs = percentile(99.9);

        return result;
    }

    // 打印报告
    static void printReport(const BenchmarkResult& r) {
        std::cout << "\n";
        std::cout << "============================================\n";
        std::cout << " Benchmark: " << r.name << "\n";
        std::cout << "============================================\n";
        std::cout << std::fixed << std::setprecision(2);
        std::cout << " Total Requests : " << r.totalRequests << "\n";
        std::cout << " Total Time     : " << r.totalTimeSec << " sec\n";
        std::cout << " QPS            : " << r.qps << "\n";
        std::cout << " Errors         : " << r.errorCount << "\n";
        std::cout << "--------------------------------------------\n";
        std::cout << " Latency Distribution:\n";
        std::cout << "   Mean   : " << r.meanLatencyUs << " us\n";
        std::cout << "   StdDev : " << r.stddevLatencyUs << " us\n";
        std::cout << "   Min    : " << r.minLatencyUs << " us\n";
        std::cout << "   P50    : " << r.p50LatencyUs << " us\n";
        std::cout << "   P95    : " << r.p95LatencyUs << " us\n";
        std::cout << "   P99    : " << r.p99LatencyUs << " us\n";
        std::cout << "   P99.9  : " << r.p999LatencyUs << " us\n";
        std::cout << "   Max    : " << r.maxLatencyUs << " us\n";
        std::cout << "============================================\n";
    }

    // 对比打印
    static void printComparison(const std::vector<BenchmarkResult>& results) {
        std::cout << "\n";
        std::cout << "======================= Comparison =======================\n";
        std::cout << std::setw(20) << "Benchmark"
                 << std::setw(12) << "QPS"
                 << std::setw(12) << "Mean(us)"
                 << std::setw(12) << "P99(us)"
                 << std::setw(12) << "Max(us)" << "\n";
        std::cout << "-----------------------------------------------------------\n";

        for (const auto& r : results) {
            std::cout << std::setw(20) << r.name
                     << std::setw(12) << static_cast<int>(r.qps)
                     << std::setw(12) << std::fixed << std::setprecision(1)
                     << r.meanLatencyUs
                     << std::setw(12) << r.p99LatencyUs
                     << std::setw(12) << r.maxLatencyUs << "\n";
        }
        std::cout << "===========================================================\n";
    }

private:
    double percentile(double p) const {
        if (latencies_.empty()) return 0;
        double index = (p / 100.0) * (latencies_.size() - 1);
        size_t lower = static_cast<size_t>(std::floor(index));
        size_t upper = static_cast<size_t>(std::ceil(index));
        if (lower == upper) return latencies_[lower];
        double frac = index - lower;
        return latencies_[lower] * (1 - frac) + latencies_[upper] * frac;
    }

    std::vector<double> latencies_;
    size_t errorCount_ = 0;
};

/**
 * 性能优化清单
 *
 * ┌─────────────────────────────────────────────────────────────────┐
 * │                     性能优化策略                                │
 * ├─────────────────────────────────────────────────────────────────┤
 * │                                                                 │
 * │  1. 减少内存分配                                                │
 * │  ├── 使用内存池(对象池)                                         │
 * │  ├── 预分配Buffer                                               │
 * │  ├── 避免不必要的string拷贝(std::string_view)                  │
 * │  └── 使用move语义                                              │
 * │                                                                 │
 * │  2. 减少系统调用                                                │
 * │  ├── 使用writev/readv批量读写                                  │
 * │  ├── 批量epoll_wait                                            │
 * │  ├── TCP_CORK合并小包                                          │
 * │  └── 减少锁竞争                                                │
 * │                                                                 │
 * │  3. 数据结构优化                                                │
 * │  ├── 使用无锁队列(lock-free)                                   │
 * │  ├── cache-friendly数据布局                                    │
 * │  ├── 避免false sharing                                         │
 * │  └── 使用预排序数据结构                                        │
 * │                                                                 │
 * │  4. 编译器优化                                                  │
 * │  ├── -O2 / -O3 编译优化                                       │
 * │  ├── LTO (Link Time Optimization)                              │
 * │  ├── PGO (Profile Guided Optimization)                         │
 * │  └── likely/unlikely分支预测提示                               │
 * │                                                                 │
 * │  5. 系统调优                                                    │
 * │  ├── 调整TCP缓冲区大小                                         │
 * │  ├── 调整文件描述符限制                                        │
 * │  ├── CPU亲和性设置                                             │
 * │  └── NUMA感知内存分配                                          │
 * │                                                                 │
 * └─────────────────────────────────────────────────────────────────┘
 */

// Buffer性能测试示例
void benchBuffer() {
    BenchmarkRunner runner;
    const int iterations = 1000000;

    auto start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < iterations; ++i) {
        Buffer buf;
        auto t1 = std::chrono::high_resolution_clock::now();

        buf.append("hello world, this is a test message for benchmark");
        buf.appendInt32(42);
        buf.appendInt16(100);

        std::string data = buf.retrieveAllAsString();

        auto t2 = std::chrono::high_resolution_clock::now();
        double us = std::chrono::duration<double, std::micro>(t2 - t1).count();
        runner.recordLatency(us);
    }
    auto end = std::chrono::high_resolution_clock::now();
    double totalSec = std::chrono::duration<double>(end - start).count();

    auto result = runner.calculate("Buffer Operations", totalSec);
    BenchmarkRunner::printReport(result);
}

// 序列化性能对比测试
void benchSerialization() {
    // 自定义序列化 vs Protobuf vs FlatBuffers
    std::vector<BenchmarkResult> results;

    // ... 各序列化方案的benchmark代码 ...
    // 将结果收集到results中

    // BenchmarkRunner::printComparison(results);
}

} // namespace bench
} // namespace netlib
```

---

### Day 26-28: 文档与总结

#### 综合使用示例

```cpp
/**
 * example_service.cpp
 * NetLib 综合使用示例 - 构建一个完整的RPC微服务
 */

#include <iostream>
#include <string>
#include <thread>

namespace netlib {
namespace example {

/**
 * 完整RPC微服务示例
 *
 * ┌─────────────────────────────────────────────────────────────────┐
 * │                    微服务架构示例                                │
 * ├─────────────────────────────────────────────────────────────────┤
 * │                                                                 │
 * │                  ┌─────────────────┐                           │
 * │                  │   API Gateway   │                           │
 * │                  └────────┬────────┘                           │
 * │                           │                                     │
 * │              ┌────────────┼────────────┐                       │
 * │              ▼            ▼            ▼                       │
 * │       ┌────────────┐┌────────────┐┌────────────┐              │
 * │       │UserService ││OrderService││PayService  │              │
 * │       │  :8001    ││  :8002    ││  :8003    │              │
 * │       └────────────┘└────────────┘└────────────┘              │
 * │              │            │            │                       │
 * │              └────────────┼────────────┘                       │
 * │                           ▼                                     │
 * │                  ┌─────────────────┐                           │
 * │                  │ Service Registry│                           │
 * │                  │   (注册中心)    │                           │
 * │                  └─────────────────┘                           │
 * │                                                                 │
 * └─────────────────────────────────────────────────────────────────┘
 */

// 用户服务实现
class UserServiceImpl {
public:
    static std::shared_ptr<ServiceDescriptor> create() {
        auto svc = std::make_shared<ServiceDescriptor>("UserService");

        svc->addMethod("getUser", [](const std::string& userId) {
            // 模拟从数据库查询
            return R"({"id":")" + userId +
                   R"(","name":"Alice","age":25})";
        });

        svc->addMethod("createUser", [](const std::string& userData) {
            // 模拟创建用户
            return R"({"status":"ok","id":"new-user-001"})";
        });

        return svc;
    }
};

/**
 * 服务端启动示例
 *
 * int main() {
 *     EventLoop loop;
 *     InetAddress addr(8001);
 *
 *     RpcServer server(&loop, addr);
 *
 *     // 注册服务
 *     server.registerService(UserServiceImpl::create());
 *
 *     // 配置
 *     server.setThreadNum(4);  // 4个IO线程
 *
 *     // 启动
 *     server.start();
 *     std::cout << "UserService started on port 8001\n";
 *
 *     loop.loop();
 *     return 0;
 * }
 */

/**
 * 客户端调用示例
 *
 * int main() {
 *     EventLoop loop;
 *     InetAddress serverAddr("127.0.0.1", 8001);
 *
 *     RpcClient client(&loop, serverAddr);
 *     client.connect();
 *
 *     // 同步调用
 *     auto future = client.callSync("UserService", "getUser", "user-001");
 *     auto response = future.get();
 *     if (response.errorCode == 0) {
 *         std::cout << "User: " << response.payload << "\n";
 *     }
 *
 *     // 异步调用
 *     client.callAsync("UserService", "createUser",
 *         R"({"name":"Bob","age":30})",
 *         [](const RpcMessage& resp) {
 *             std::cout << "Create result: " << resp.payload << "\n";
 *         });
 *
 *     loop.loop();
 *     return 0;
 * }
 */

} // namespace example
} // namespace netlib
```

#### 第三年学习总结模板

```markdown
# 第三年学习总结

## 一、学习概览

### 时间投入
- 总学时: 12个月 × 140小时 = 1680小时
- 核心模块: 网络编程 → IO多路复用 → RPC框架 → 序列化协议 → 综合项目

### 技术栈
- 语言: C++17/20
- 网络: TCP/UDP, Socket API, epoll/kqueue
- 协议: 自定义二进制协议, Protobuf, FlatBuffers
- 架构: Reactor模式, 多线程模型, 分层架构

## 二、核心知识体系

### 网络编程基础 (Month 25-27)
```
Socket API → IO模型 → TCP协议深入
   │             │           │
   ├─ 地址绑定   ├─ 阻塞IO   ├─ 三次握手/四次挥手
   ├─ 监听连接   ├─ 非阻塞IO ├─ 流量控制/拥塞控制
   └─ 数据收发   └─ 多路复用  └─ Nagle/Cork算法
```

### 高性能服务器 (Month 28-30)
```
epoll → 事件驱动 → 多线程模型
  │         │            │
  ├─ LT/ET  ├─ Reactor   ├─ 线程池
  ├─ 红黑树  ├─ Proactor  ├─ one loop per thread
  └─ 回调    └─ 非阻塞    └─ 任务队列
```

### 网络库实战 (Month 31-33)
```
muduo分析 → 组件设计 → 性能调优
   │            │           │
   ├─ EventLoop ├─ Buffer   ├─ 内存池
   ├─ Channel   ├─ Codec    ├─ 零拷贝
   └─ Acceptor  └─ Timer    └─ lock-free
```

### RPC与序列化 (Month 34-36)
```
RPC框架 → 序列化 → 综合项目
   │          │         │
   ├─ Stub    ├─ Varint  ├─ 分层架构
   ├─ 连接池  ├─ Protobuf├─ 插件系统
   └─ 服务治理└─ FlatBuf └─ 完整测试
```

## 三、核心能力评估

### 知识深度 (1-5分)
- [ ] Socket编程: ___/5
- [ ] IO多路复用: ___/5
- [ ] TCP协议: ___/5
- [ ] 网络库设计: ___/5
- [ ] RPC框架: ___/5
- [ ] 序列化协议: ___/5

### 工程能力
- [ ] 代码量: ___行
- [ ] 测试覆盖率: ___%
- [ ] 文档完整度: ___/5
- [ ] 性能优化: ___/5

## 四、困难与突破

### 遇到的主要困难
1. ___
2. ___
3. ___

### 解决方法与突破
1. ___
2. ___
3. ___

## 五、第四年展望

### 学习方向预览
```
Month 37-38: 分布式系统基础
Month 39-40: 一致性协议 (Raft/Paxos)
Month 41-42: 分布式存储
Month 43-44: 分布式计算
Month 45-46: 微服务架构
Month 47-48: 综合项目(分布式KV存储)
```

### 第三年到第四年的桥梁
```
第三年(网络编程)              第四年(分布式系统)
┌─────────────────┐          ┌─────────────────┐
│ 单机网络库      │    →     │ 分布式框架      │
│ RPC框架        │    →     │ 共识协议        │
│ 序列化协议      │    →     │ 分布式存储      │
│ 服务治理        │    →     │ 微服务架构      │
└─────────────────┘          └─────────────────┘
```
```

---

### Week 4 输出物清单

| 文件 | 说明 | 完成状态 |
|------|------|---------|
| `tests/unit_tests.cpp` | 单元测试 | [ ] |
| `tests/integration_tests.cpp` | 集成测试 | [ ] |
| `benchmarks/benchmark.cpp` | 性能基准测试 | [ ] |
| `docs/optimization_notes.md` | 性能优化笔记 | [ ] |
| `docs/api_reference.md` | API参考文档 | [ ] |
| `examples/example_service.cpp` | 综合示例 | [ ] |
| `notes/year3_summary.md` | 第三年学习总结 | [ ] |

### Week 4 验收标准

- [ ] Buffer/Channel/Timer单元测试全部通过
- [ ] RPC端到端调用集成测试通过
- [ ] 完成性能基准测试并输出报告
- [ ] 识别并优化至少3个性能瓶颈
- [ ] 完成API参考文档
- [ ] 完成综合使用示例
- [ ] 撰写第三年学习总结

---

## 本月总结

### Month 36 完整输出物

```
netlib/
├── core/
│   ├── poller.hpp              # IO多路复用抽象
│   ├── event_loop.hpp          # 事件循环
│   ├── channel.hpp             # 事件通道
│   ├── buffer.hpp              # 读写缓冲区
│   ├── timer_queue.hpp         # 定时器队列
│   └── event_loop_thread_pool.hpp  # 线程池
├── net/
│   ├── tcp_connection.hpp      # TCP连接
│   ├── tcp_server.hpp          # TCP服务器
│   ├── acceptor.hpp            # 连接接入
│   └── connector.hpp           # 主动连接
├── protocol/
│   ├── codec.hpp               # 编解码框架
│   └── rpc_codec.hpp           # RPC编解码
├── service/
│   ├── rpc_service.hpp         # RPC服务
│   ├── service_registry.hpp    # 服务注册
│   ├── connection_pool.hpp     # 连接池
│   ├── rate_limiter.hpp        # 限流器
│   └── circuit_breaker.hpp     # 熔断器
├── design/
│   ├── architecture_design.hpp # 架构设计
│   └── plugin_design.hpp       # 插件系统
├── tests/
│   ├── unit_tests.cpp          # 单元测试
│   └── integration_tests.cpp   # 集成测试
├── benchmarks/
│   └── benchmark.cpp           # 性能测试
├── examples/
│   └── example_service.cpp     # 使用示例
└── notes/
    └── year3_summary.md        # 第三年总结
```

### 第三年知识图谱

```
┌─────────────────────────────────────────────────────────────────────┐
│                       第三年: 网络编程体系                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   基础层                                                            │
│   ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐                │
│   │ Socket  │ │ TCP/UDP │ │ IO模型  │ │ 多路复用│                │
│   └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘                │
│        └───────────┴───────────┴───────────┘                      │
│                           │                                         │
│   核心层                  ▼                                         │
│   ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐                │
│   │EventLoop│ │ Channel │ │ Buffer  │ │ Timer   │                │
│   └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘                │
│        └───────────┴───────────┴───────────┘                      │
│                           │                                         │
│   协议层                  ▼                                         │
│   ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐                │
│   │  Codec  │ │Protobuf │ │FlatBuf  │ │ 压缩    │                │
│   └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘                │
│        └───────────┴───────────┴───────────┘                      │
│                           │                                         │
│   服务层                  ▼                                         │
│   ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐                │
│   │  RPC    │ │负载均衡  │ │ 熔断    │ │ 限流    │                │
│   └─────────┘ └─────────┘ └─────────┘ └─────────┘                │
│                                                                     │
│   ═══════════════════════════════════════════════                  │
│                    ▼                                                │
│              完整的 NetLib 网络库                                    │
│              (第三年毕业项目)                                        │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 月度验收标准

- [ ] 完成知识复盘，能够系统讲解第三年所学内容
- [ ] 实现完整的分层网络库(Network/Protocol/Service)
- [ ] 网络库支持多Reactor多线程模型
- [ ] 实现RPC服务端和客户端
- [ ] 实现连接池、限流器、熔断器等服务治理组件
- [ ] 单元测试覆盖核心模块
- [ ] 完成性能基准测试
- [ ] 撰写完整的API文档和架构文档
- [ ] 完成第三年学习总结报告

