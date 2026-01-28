# Month 25: Socket编程基础——网络通信的基石

## 本月主题概述

进入第三年的**高性能网络编程**学习。经过Year 1的C++语言基础和Year 2的并发编程深度修炼，你已经具备了扎实的系统编程能力。从本月开始，我们将把这些能力应用到网络编程领域——这是现代服务端开发最核心的技能之一。

本月从**Socket API**开始，这是所有网络编程的基础。无论是后续要学习的epoll、io_uring，还是Reactor/Proactor模式，亦或是HTTP Server和RPC框架，它们的底层都建立在Socket之上。本月的核心任务是：

1. **协议理解**：深入理解OSI/TCP/IP模型，掌握TCP和UDP协议的工作原理
2. **API掌握**：熟练使用POSIX Socket API进行TCP/UDP网络编程
3. **模式认知**：掌握多客户端并发处理、广播/组播等网络编程模式
4. **工程能力**：实现一个跨平台的Socket封装库，为后续月份的学习打下基础

### Year 3 网络编程知识体系全景图

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                   Year 3: 高性能网络编程（Month 25-36）                         │
├────────────────────────────────────────────────────────────────────────────────┤
│                                                                                │
│  ┌── 基础层 (Month 25-27) ────────────────────────────────────────┐           │
│  │                                                                  │           │
│  │  Month 25 【本月】    Month 26           Month 27               │           │
│  │  Socket编程基础       阻塞与非阻塞I/O    epoll深度解析          │           │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │           │
│  │  │ TCP/UDP     │    │ 五种I/O模型 │    │ epoll API   │         │           │
│  │  │ Socket API  │    │ select/poll │    │ LT/ET模式   │         │           │
│  │  │ 地址结构    │ →  │ 非阻塞编程  │ →  │ 内核实现    │         │           │
│  │  │ 字节序      │    │ 事件循环    │    │ 惊群问题    │         │           │
│  │  │ 跨平台封装  │    │ 统一框架    │    │ 高性能框架  │         │           │
│  │  └─────────────┘    └─────────────┘    └─────────────┘         │           │
│  └──────────────────────────────────────────────────────────────────┘           │
│                                    ↓                                            │
│  ┌── I/O优化层 (Month 28-30) ─────────────────────────────────────┐           │
│  │                                                                  │           │
│  │  Month 28            Month 29           Month 30                │           │
│  │  io_uring            零拷贝技术         Reactor模式             │           │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │           │
│  │  │ SQ/CQ机制   │    │ sendfile    │    │ 单线程Reactor│         │           │
│  │  │ SQPOLL模式  │    │ splice      │    │ 多线程Reactor│         │           │
│  │  │ 异步I/O     │    │ mmap        │    │ 主从Reactor  │         │           │
│  │  └─────────────┘    └─────────────┘    └─────────────┘         │           │
│  └──────────────────────────────────────────────────────────────────┘           │
│                                    ↓                                            │
│  ┌── 架构层 (Month 31-33) ────────────────────────────────────────┐           │
│  │                                                                  │           │
│  │  Month 31            Month 32           Month 33                │           │
│  │  Proactor模式        Envoy架构分析      高性能HTTP服务器        │           │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │           │
│  │  │ IOCP        │    │ Filter Chain│    │ HTTP解析    │         │           │
│  │  │ io_uring    │    │ xDS协议     │    │ Keep-Alive  │         │           │
│  │  │ 跨平台      │    │ 热更新      │    │ 静态文件    │         │           │
│  │  └─────────────┘    └─────────────┘    └─────────────┘         │           │
│  └──────────────────────────────────────────────────────────────────┘           │
│                                    ↓                                            │
│  ┌── 应用层 (Month 34-36) ────────────────────────────────────────┐           │
│  │                                                                  │           │
│  │  Month 34            Month 35           Month 36                │           │
│  │  RPC框架基础         协议设计与序列化   Year 3综合项目          │           │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │           │
│  │  │ Stub/Skeleton│    │ Protobuf   │    │ 完整网络库  │         │           │
│  │  │ 服务发现     │    │ FlatBuffers│    │ 知识整合    │         │           │
│  │  │ 负载均衡     │    │ 协议设计   │    │ 性能调优    │         │           │
│  │  └─────────────┘    └─────────────┘    └─────────────┘         │           │
│  └──────────────────────────────────────────────────────────────────┘           │
│                                                                                │
│  Year 2 → Year 3 知识桥梁：                                                   │
│  • 线程/同步 → 多线程服务器                                                   │
│  • 协程/Task → 协程化网络I/O                                                  │
│  • EventLoop → epoll/io_uring事件循环                                         │
│  • 无锁队列 → 高性能消息传递                                                  │
│  • Actor模型 → 网络服务架构                                                   │
└────────────────────────────────────────────────────────────────────────────────┘
```

### 学习目标

1. **协议理解**：深入理解TCP/IP协议栈，能画出TCP三次握手/四次挥手的完整状态图
2. **API掌握**：能独立使用POSIX Socket API编写TCP/UDP服务器和客户端
3. **模式认知**：掌握多进程、多线程并发服务器模型，理解广播/组播通信
4. **工程能力**：完成跨平台Socket封装库，包含TCP/UDP/地址解析/错误处理

### 学习目标量化

| 周次 | 目标编号 | 具体目标 |
|------|----------|----------|
| W1 | W1-G1 | 画出OSI/TCP/IP模型对照图及各层协议 |
| W1 | W1-G2 | 理解TCP三次握手/四次挥手及完整状态机 |
| W1 | W1-G3 | 掌握sockaddr结构族、字节序转换、地址转换函数 |
| W2 | W2-G1 | 实现完整的TCP Echo Server（迭代版） |
| W2 | W2-G2 | 实现fork()/thread多客户端并发服务器 |
| W2 | W2-G3 | 掌握TCP流式数据处理（readn/writen/粘包处理） |
| W3 | W3-G1 | 实现完整的UDP Echo Server/Client |
| W3 | W3-G2 | 实现UDP广播和组播通信 |
| W3 | W3-G3 | 掌握DNS解析（getaddrinfo）和地址工具函数 |
| W4 | W4-G1 | 掌握常用Socket选项的配置和效果 |
| W4 | W4-G2 | 实现错误处理框架（Stevens风格包装函数） |
| W4 | W4-G3 | 完成跨平台Socket封装库（TCP/UDP/Server/AddressInfo） |

### 综合项目概述

```
综合项目：跨平台Socket封装库 (SocketWrapper)

┌─────────────────────────────────────────────────────────────────┐
│                        应用层示例                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ Echo Server  │  │ Echo Client  │  │ DNS Resolver │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         └─────────────────┼─────────────────┘                   │
│                     ┌─────▼─────┐                                │
│                     │ TcpServer │  ← 服务器管理层                │
│                     └─────┬─────┘                                │
│              ┌────────────┼────────────┐                         │
│              │            │            │                          │
│  ┌───────────▼──┐  ┌─────▼────┐  ┌───▼───────────┐             │
│  │  TcpSocket   │  │UdpSocket │  │ AddressInfo   │             │
│  │  send_all    │  │send_to   │  │ resolve       │             │
│  │  recv_all    │  │recv_from │  │ to_string     │             │
│  │  connect_to  │  │broadcast │  │ iterate       │             │
│  │  shutdown    │  │multicast │  │               │             │
│  └───────┬──────┘  └────┬─────┘  └───────────────┘             │
│          └──────────────┤                                        │
│                   ┌─────▼─────┐                                  │
│                   │  Socket   │  ← 基类（RAII、移动语义）        │
│                   │  close    │                                   │
│                   │  valid    │                                   │
│                   │  native   │                                   │
│                   │  nonblock │                                   │
│                   └─────┬─────┘                                  │
│              ┌──────────┼──────────┐                              │
│         ┌────▼────┐ ┌───▼────┐ ┌──▼───────┐                     │
│         │Platform │ │ Error  │ │ByteOrder │                     │
│         │Abstract │ │Handler │ │ Utility  │                     │
│         └─────────┘ └────────┘ └──────────┘                     │
│                                                                   │
│  技术来源：                                                      │
│  • RAII/移动语义 → Year 1 (智能指针、资源管理)                  │
│  • 多线程 → Year 2 Month 13 (std::thread)                       │
│  • 模板/泛型 → Year 1 (模板编程)                                │
│  • 异常处理 → Year 1 (错误处理)                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 参考书目

| 书名 | 章节 | 相关性 |
|------|------|--------|
| 《UNIX网络编程》卷1 (Stevens) | 第1-11章 | Socket API核心参考 |
| 《TCP/IP详解》卷1 (Stevens) | 第1-4, 17-18章 | 协议原理深入理解 |
| 《Linux高性能服务器编程》(游双) | 第1-5章 | Linux网络编程实践 |
| Beej's Guide to Network Programming | 全文 | 入门友好的在线教程 |

### 前置知识（Year 2 → Year 3 衔接）

| Year 2 知识 | Month-25 应用 |
|-------------|---------------|
| Month 13: std::thread | 多线程TCP服务器 |
| Month 13: mutex/cv | 连接管理中的同步 |
| Month 19: 线程池 | 后续月份线程池服务器的基础 |
| Month 21: 协程 | 后续月份协程化Socket的基础 |
| Month 22: EventLoop | 后续月份epoll事件循环的基础 |
| Year 1: RAII | Socket封装的资源管理 |
| Year 1: 模板 | 泛型Socket工具函数 |

### 时间分配（120小时）

| 周次 | 内容 | 时间 | 占比 |
|------|------|------|------|
| W1 | 网络基础与协议栈 | 25h | 21% |
| W2 | TCP Socket编程 | 35h | 29% |
| W3 | UDP编程与高级主题 | 30h | 25% |
| W4 | Socket选项与跨平台封装 | 30h | 25% |

---

## 第一周：网络基础与协议栈（Day 1-7）

> **本周目标**：深入理解OSI/TCP/IP模型，掌握Socket地址结构和字节序转换，
> 能使用基础Socket API创建和配置套接字

### Day 1-2：OSI模型与TCP/IP协议栈

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | OSI七层模型与TCP/IP四层模型 | 3h |
| 下午 | TCP协议深入（握手、挥手、状态机） | 3h |
| 晚上 | UDP协议与TCP/UDP对比 | 2h |

#### 1. OSI七层模型与TCP/IP四层模型

```cpp
// ============================================================
// 网络协议栈模型详解
// ============================================================

/*
┌─────────────────────────────────────────────────────────────────────────┐
│                    OSI 七层模型 vs TCP/IP 四层模型                       │
├──────────────────────────────┬──────────────────────────────────────────┤
│       OSI 模型               │       TCP/IP 模型                        │
├──────────────────────────────┼──────────────────────────────────────────┤
│                              │                                          │
│  ┌────────────────────────┐  │  ┌────────────────────────────────────┐  │
│  │ 第7层：应用层          │  │  │                                    │  │
│  │ HTTP, FTP, DNS, SMTP   │  │  │                                    │  │
│  ├────────────────────────┤  │  │  应用层                            │  │
│  │ 第6层：表示层          │  │  │  HTTP, FTP, DNS, SMTP, SSH         │  │
│  │ 加密, 压缩, 编码      │  │  │  (合并OSI 5-7层)                   │  │
│  ├────────────────────────┤  │  │                                    │  │
│  │ 第5层：会话层          │  │  │                                    │  │
│  │ 会话管理, 同步         │  │  └────────────────────────────────────┘  │
│  ├────────────────────────┤  │  ┌────────────────────────────────────┐  │
│  │ 第4层：传输层          │  │  │  传输层                            │  │
│  │ TCP, UDP               │  │  │  TCP, UDP                          │  │
│  │ 端到端通信             │  │  │  端到端可靠/不可靠传输              │  │
│  ├────────────────────────┤  │  └────────────────────────────────────┘  │
│  │ 第3层：网络层          │  │  ┌────────────────────────────────────┐  │
│  │ IP, ICMP, ARP          │  │  │  网际层                            │  │
│  │ 路由, 寻址             │  │  │  IP, ICMP, IGMP                    │  │
│  ├────────────────────────┤  │  └────────────────────────────────────┘  │
│  │ 第2层：数据链路层      │  │  ┌────────────────────────────────────┐  │
│  │ Ethernet, WiFi         │  │  │  网络接口层                        │  │
│  │ MAC地址, 帧            │  │  │  Ethernet, WiFi, PPP              │  │
│  ├────────────────────────┤  │  │  (合并OSI 1-2层)                   │  │
│  │ 第1层：物理层          │  │  │                                    │  │
│  │ 电信号, 光信号         │  │  └────────────────────────────────────┘  │
│  └────────────────────────┘  │                                          │
├──────────────────────────────┴──────────────────────────────────────────┤
│                                                                          │
│  数据封装过程（发送端）：                                                │
│                                                                          │
│  应用层      [         数据          ]                                   │
│              ↓                                                           │
│  传输层      [TCP头][     数据       ]    ← 段（Segment）                │
│              ↓                                                           │
│  网络层      [IP头][TCP头][  数据    ]    ← 包（Packet）                 │
│              ↓                                                           │
│  链路层   [帧头][IP头][TCP头][数据][帧尾] ← 帧（Frame）                  │
│                                                                          │
│  Socket API 工作在传输层与应用层之间，为应用程序提供网络通信接口          │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
*/

#include <iostream>
#include <cstdint>

// 模拟数据封装过程
namespace protocol_stack {

// 以太网帧头（简化）
struct EthernetHeader {
    uint8_t  dst_mac[6];     // 目的MAC地址
    uint8_t  src_mac[6];     // 源MAC地址
    uint16_t ether_type;     // 协议类型 (0x0800 = IPv4)
};

// IP头（简化，仅展示关键字段）
struct IPv4Header {
    uint8_t  version_ihl;    // 版本(4bit) + 首部长度(4bit)
    uint8_t  tos;            // 服务类型
    uint16_t total_length;   // 总长度
    uint16_t identification; // 标识
    uint16_t flags_fragment; // 标志(3bit) + 片偏移(13bit)
    uint8_t  ttl;            // 生存时间
    uint8_t  protocol;       // 上层协议 (6=TCP, 17=UDP)
    uint16_t checksum;       // 首部校验和
    uint32_t src_addr;       // 源IP地址
    uint32_t dst_addr;       // 目的IP地址
};

// TCP头（简化）
struct TcpHeader {
    uint16_t src_port;       // 源端口
    uint16_t dst_port;       // 目的端口
    uint32_t seq_num;        // 序列号
    uint32_t ack_num;        // 确认号
    uint16_t flags;          // 数据偏移(4bit) + 保留(6bit) + 标志位(6bit)
    uint16_t window;         // 窗口大小
    uint16_t checksum;       // 校验和
    uint16_t urgent_ptr;     // 紧急指针
};

// UDP头
struct UdpHeader {
    uint16_t src_port;       // 源端口
    uint16_t dst_port;       // 目的端口
    uint16_t length;         // 长度（头+数据）
    uint16_t checksum;       // 校验和
};

void print_header_sizes() {
    std::cout << "=== 协议头大小 ===" << std::endl;
    std::cout << "Ethernet Header: " << sizeof(EthernetHeader) << " bytes" << std::endl;
    std::cout << "IPv4 Header:     " << sizeof(IPv4Header) << " bytes (最小20)" << std::endl;
    std::cout << "TCP Header:      " << sizeof(TcpHeader) << " bytes (最小20)" << std::endl;
    std::cout << "UDP Header:      " << sizeof(UdpHeader) << " bytes (固定8)" << std::endl;
    std::cout << std::endl;
    std::cout << "TCP/IP最大开销: 20(IP) + 20(TCP) = 40 bytes" << std::endl;
    std::cout << "UDP/IP最大开销: 20(IP) + 8(UDP) = 28 bytes" << std::endl;
}

} // namespace protocol_stack

/*
自测题：

Q1: Socket API工作在OSI模型的哪一层？
A1: Socket API工作在传输层和应用层之间，为应用层提供访问传输层（TCP/UDP）的接口。
    严格来说，Socket不属于OSI任何一层，它是操作系统提供的一组系统调用接口。

Q2: 为什么TCP/IP模型只有四层而不是七层？
A2: TCP/IP模型是先有实现再有模型（实践驱动），它将OSI的上三层合并为应用层，
    下两层合并为网络接口层，因为在实际实现中这些层的界限并不明显。
    OSI模型更偏理论（理论驱动），划分更细致但在实践中很少严格遵循。

Q3: 数据从应用层到网络接口层，每经过一层会发生什么？
A3: 每经过一层会添加该层的协议头（封装）：
    - 传输层：添加TCP头或UDP头 → 形成段（Segment）
    - 网络层：添加IP头 → 形成包（Packet）
    - 链路层：添加帧头和帧尾 → 形成帧（Frame）
    接收端则相反，逐层剥离头部（解封装）。
*/
```

#### 2. TCP协议深入

```cpp
// ============================================================
// TCP协议核心机制详解
// ============================================================

/*
┌─────────────────────────────────────────────────────────────────────┐
│                     TCP 三次握手 (Three-Way Handshake)               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│    客户端(Client)                          服务器(Server)            │
│    状态: CLOSED                            状态: LISTEN              │
│         │                                      │                     │
│         │  ① SYN, seq=x                       │                     │
│         │ ──────────────────────────────────→  │                     │
│         │                                      │                     │
│    状态: SYN_SENT                          状态: SYN_RCVD            │
│         │                                      │                     │
│         │  ② SYN+ACK, seq=y, ack=x+1         │                     │
│         │ ←──────────────────────────────────  │                     │
│         │                                      │                     │
│         │  ③ ACK, seq=x+1, ack=y+1            │                     │
│         │ ──────────────────────────────────→  │                     │
│         │                                      │                     │
│    状态: ESTABLISHED                       状态: ESTABLISHED         │
│         │         ← 可以双向传输数据 →         │                     │
│                                                                      │
│  为什么需要三次握手？                                                │
│  1. 确认双方的发送和接收能力                                         │
│  2. 协商初始序列号（ISN），防止旧连接的数据包干扰                    │
│  3. 两次握手无法确认客户端的接收能力（可能导致半开连接浪费资源）      │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                     TCP 四次挥手 (Four-Way Teardown)                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│    主动关闭方(Active)                     被动关闭方(Passive)        │
│    状态: ESTABLISHED                      状态: ESTABLISHED          │
│         │                                      │                     │
│         │  ① FIN, seq=u                       │                     │
│         │ ──────────────────────────────────→  │                     │
│         │                                      │                     │
│    状态: FIN_WAIT_1                        状态: CLOSE_WAIT          │
│         │                                      │                     │
│         │  ② ACK, ack=u+1                     │                     │
│         │ ←──────────────────────────────────  │                     │
│         │                                      │                     │
│    状态: FIN_WAIT_2        被动方仍可发送数据  │                     │
│         │                  （半关闭状态）       │                     │
│         │  ③ FIN, seq=v                       │                     │
│         │ ←──────────────────────────────────  │                     │
│         │                                      │                     │
│         │  ④ ACK, ack=v+1                 状态: LAST_ACK             │
│         │ ──────────────────────────────────→  │                     │
│         │                                      │                     │
│    状态: TIME_WAIT                         状态: CLOSED              │
│         │                                                            │
│         │  等待 2×MSL (Maximum Segment Lifetime)                     │
│         │  Linux默认 MSL=60s, 即 TIME_WAIT持续120s                   │
│         │                                                            │
│    状态: CLOSED                                                      │
│                                                                      │
│  为什么需要四次挥手？                                                │
│  TCP是全双工通信，每个方向需要独立关闭（FIN+ACK各一次 = 四次）       │
│                                                                      │
│  为什么需要TIME_WAIT？                                               │
│  1. 确保最后一个ACK能到达对方（如果丢失，对方会重发FIN）             │
│  2. 让网络中残留的该连接的数据包完全消失，避免影响新连接              │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                     TCP 完整状态机                                    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│                        ┌──────────┐                                  │
│               ┌────────│  CLOSED  │────────┐                         │
│               │        └──────────┘        │                         │
│         被动打开                       主动打开                       │
│         (listen)                       (connect)                     │
│               │                            │                         │
│               ▼                            ▼                         │
│        ┌──────────┐                 ┌────────────┐                   │
│        │  LISTEN  │                 │  SYN_SENT  │                   │
│        └────┬─────┘                 └──────┬─────┘                   │
│          收到SYN                         收到SYN+ACK                 │
│          发送SYN+ACK                     发送ACK                     │
│             │                              │                         │
│             ▼                              ▼                         │
│       ┌──────────┐                  ┌─────────────┐                  │
│       │ SYN_RCVD │──── 收到ACK ───→│ ESTABLISHED │                  │
│       └──────────┘                  └──────┬──────┘                  │
│                                         主动关闭                      │
│                                         发送FIN                      │
│                                            │                         │
│                                            ▼                         │
│   ┌────────────┐  收到ACK          ┌─────────────┐                  │
│   │ FIN_WAIT_2 │←─────────────────│ FIN_WAIT_1  │                  │
│   └─────┬──────┘                   └─────────────┘                  │
│       收到FIN                                                        │
│       发送ACK                                                        │
│         │                                                            │
│         ▼              被动关闭方:                                    │
│   ┌────────────┐       ESTABLISHED → CLOSE_WAIT → LAST_ACK → CLOSED │
│   │ TIME_WAIT  │       (收到FIN)     (发送FIN)    (收到ACK)          │
│   └─────┬──────┘                                                     │
│       2MSL超时                                                       │
│         │                                                            │
│         ▼                                                            │
│   ┌──────────┐                                                       │
│   │  CLOSED  │                                                       │
│   └──────────┘                                                       │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
*/

#include <iostream>
#include <cstring>

// TCP头部标志位定义
namespace tcp_flags {
    constexpr uint8_t FIN = 0x01;  // 结束
    constexpr uint8_t SYN = 0x02;  // 同步（建立连接）
    constexpr uint8_t RST = 0x04;  // 重置
    constexpr uint8_t PSH = 0x08;  // 推送（立即交付）
    constexpr uint8_t ACK = 0x10;  // 确认
    constexpr uint8_t URG = 0x20;  // 紧急

    const char* to_string(uint8_t flags) {
        static char buf[64];
        buf[0] = '\0';
        if (flags & SYN) strcat(buf, "SYN ");
        if (flags & ACK) strcat(buf, "ACK ");
        if (flags & FIN) strcat(buf, "FIN ");
        if (flags & RST) strcat(buf, "RST ");
        if (flags & PSH) strcat(buf, "PSH ");
        if (flags & URG) strcat(buf, "URG ");
        return buf;
    }
}

// 模拟TCP状态机
enum class TcpState {
    CLOSED, LISTEN, SYN_SENT, SYN_RCVD,
    ESTABLISHED,
    FIN_WAIT_1, FIN_WAIT_2, TIME_WAIT,
    CLOSE_WAIT, LAST_ACK
};

const char* state_name(TcpState s) {
    switch (s) {
        case TcpState::CLOSED:      return "CLOSED";
        case TcpState::LISTEN:      return "LISTEN";
        case TcpState::SYN_SENT:    return "SYN_SENT";
        case TcpState::SYN_RCVD:    return "SYN_RCVD";
        case TcpState::ESTABLISHED: return "ESTABLISHED";
        case TcpState::FIN_WAIT_1:  return "FIN_WAIT_1";
        case TcpState::FIN_WAIT_2:  return "FIN_WAIT_2";
        case TcpState::TIME_WAIT:   return "TIME_WAIT";
        case TcpState::CLOSE_WAIT:  return "CLOSE_WAIT";
        case TcpState::LAST_ACK:    return "LAST_ACK";
    }
    return "UNKNOWN";
}

/*
自测题：

Q1: 为什么TCP握手是三次而不是两次？
A1: 两次握手无法确认客户端的接收能力。假设客户端发送了一个延迟的SYN（旧的连接请求），
    服务器收到后回复SYN+ACK并进入ESTABLISHED状态。但客户端知道这是旧请求会忽略，
    导致服务器白白分配资源（半开连接问题）。三次握手中，服务器要等到收到客户端的ACK
    才进入ESTABLISHED，避免了这个问题。

Q2: TIME_WAIT状态持续2MSL的原因？
A2: MSL(Maximum Segment Lifetime)是报文在网络中的最大生存时间。
    等待2MSL可以确保：
    1. 如果最后的ACK丢失，对方重发FIN，此时仍可响应（1MSL用于ACK到达+1MSL用于FIN重传）
    2. 该连接上所有数据包在网络中完全消失，不会干扰后续使用相同四元组的新连接

Q3: 大量TIME_WAIT对服务器有什么影响？如何解决？
A3: 大量TIME_WAIT会占用端口和内存资源（每个约占4KB内核内存）。解决方案：
    1. 设置SO_REUSEADDR允许重用TIME_WAIT状态的地址
    2. 调小tcp_fin_timeout（缩短TIME_WAIT时间，但有风险）
    3. 开启tcp_tw_reuse（允许复用TIME_WAIT连接，需要tcp_timestamps支持）
    4. 让客户端主动关闭（将TIME_WAIT转移到客户端）
*/
```

#### 3. UDP协议特点

```cpp
// ============================================================
// UDP协议特点与TCP对比
// ============================================================

/*
┌─────────────────────────────────────────────────────────────┐
│                     UDP 数据报格式                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  0                   1                   2                   │
│  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7  │
│  ├─────────────────┼─────────────────┤                      │
│  │    源端口 (16)   │   目的端口 (16)  │                      │
│  ├─────────────────┼─────────────────┤                      │
│  │   长度 (16)      │   校验和 (16)    │                      │
│  ├─────────────────┴─────────────────┤                      │
│  │             数据 ...               │                      │
│  └───────────────────────────────────┘                      │
│                                                              │
│  UDP头部固定8字节，比TCP头部（20-60字节）小得多               │
│  最大数据报大小: 65535 - 20(IP头) - 8(UDP头) = 65507 bytes   │
│                                                              │
└─────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│                 TCP vs UDP 详细对比                            │
├────────────┬──────────────────┬───────────────────────────────┤
│   特性     │       TCP        │          UDP                  │
├────────────┼──────────────────┼───────────────────────────────┤
│ 连接方式   │ 面向连接         │ 无连接                        │
│ 可靠性     │ 可靠传输         │ 不可靠（尽最大努力交付）      │
│ 有序性     │ 保证顺序         │ 不保证顺序                    │
│ 数据边界   │ 字节流（无边界） │ 数据报（保留边界）            │
│ 流量控制   │ 滑动窗口         │ 无                            │
│ 拥塞控制   │ 有               │ 无                            │
│ 头部大小   │ 20-60 bytes      │ 8 bytes                       │
│ 传输效率   │ 较低             │ 较高                          │
│ 通信模式   │ 一对一           │ 一对一/一对多/多对多          │
│ 适用场景   │ 文件传输、HTTP   │ DNS、视频流、游戏、VoIP      │
│ API调用    │ send/recv        │ sendto/recvfrom               │
│ 服务器模型 │ listen+accept    │ bind后直接收发                │
└────────────┴──────────────────┴───────────────────────────────┘
*/

/*
TCP适用场景：
1. 文件传输（FTP）—— 数据完整性是第一要求
2. Web浏览（HTTP/HTTPS）—— 需要可靠传输HTML/CSS/JS
3. 邮件（SMTP/IMAP）—— 邮件内容不能丢失
4. 数据库连接 —— 查询和响应必须完整

UDP适用场景：
1. DNS查询 —— 请求小且需要快速响应，丢了可以重查
2. 视频/音频流 —— 允许丢帧，低延迟更重要
3. 在线游戏 —— 位置更新需要低延迟，旧数据无用
4. IoT传感器 —— 周期性数据，丢一两个无所谓
5. 广播/组播 —— TCP不支持，只能用UDP
*/

/*
自测题：

Q1: TCP是字节流协议，这意味着什么？对编程有何影响？
A1: TCP不保留消息边界。发送方连续send("Hello")和send("World")，
    接收方一次recv可能收到"HelloWorld"（粘包），也可能收到"Hel"（半包）。
    编程时必须自己定义消息边界：定长消息、长度前缀、特殊分隔符等。

Q2: UDP数据报的最大大小是多少？超过会怎样？
A2: UDP数据报理论最大65507字节(65535-20-8)。但实际上应限制在MTU以内
    （以太网MTU=1500，减去IP头和UDP头后约1472字节）。
    超过MTU会在IP层分片，增加丢失概率（任一分片丢失则整个数据报丢失）。
*/
```

### Day 3-4：Socket地址与字节序

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | 字节序原理与转换函数 | 2h |
| 下午 | sockaddr结构族详解 | 3h |
| 晚上 | IP地址转换与DNS解析基础 | 3h |

#### 1. 网络字节序与主机字节序

```cpp
// ============================================================
// 字节序原理与转换工具
// ============================================================

/*
┌─────────────────────────────────────────────────────────────────┐
│                    字节序（Byte Order）详解                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  以 32位整数 0x12345678 为例：                                   │
│                                                                  │
│  大端序 (Big-Endian) = 网络字节序 (Network Byte Order)           │
│  内存地址:  0x00    0x01    0x02    0x03                         │
│  存储值:    0x12    0x34    0x56    0x78                         │
│            ↑高位字节在低地址（人类阅读顺序）                     │
│  使用者: 网络传输、Motorola 68k、SPARC                           │
│                                                                  │
│  小端序 (Little-Endian) = 常见主机字节序 (Host Byte Order)       │
│  内存地址:  0x00    0x01    0x02    0x03                         │
│  存储值:    0x78    0x56    0x34    0x12                         │
│            ↑低位字节在低地址                                     │
│  使用者: x86/x64、ARM（默认）                                    │
│                                                                  │
│  为什么网络用大端序？                                            │
│  RFC 1700 规定网络传输使用大端序，这是历史约定。                  │
│  大端序的优势是高位字节先传输，便于路由器快速判断地址前缀。       │
│                                                                  │
│  关键规则：                                                      │
│  发送数据前：主机字节序 → 网络字节序 (htons/htonl)               │
│  接收数据后：网络字节序 → 主机字节序 (ntohs/ntohl)               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
*/

#include <arpa/inet.h>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <iomanip>

// 检测当前系统的字节序
bool is_little_endian() {
    uint16_t value = 0x0102;
    uint8_t* ptr = reinterpret_cast<uint8_t*>(&value);
    return ptr[0] == 0x02;  // 低地址存储低位字节 → 小端
}

// 打印内存中的字节（十六进制）
void hex_dump(const void* data, size_t size, const char* label) {
    const uint8_t* bytes = static_cast<const uint8_t*>(data);
    std::cout << label << ": ";
    for (size_t i = 0; i < size; ++i) {
        std::cout << std::hex << std::setw(2) << std::setfill('0')
                  << static_cast<int>(bytes[i]) << " ";
    }
    std::cout << std::dec << std::endl;
}

void byte_order_demo() {
    std::cout << "=== 字节序演示 ===" << std::endl;
    std::cout << "当前系统: " << (is_little_endian() ? "小端序" : "大端序")
              << std::endl << std::endl;

    // 16位端口号转换
    uint16_t host_port = 8080;   // 0x1F90
    uint16_t net_port = htons(host_port);
    hex_dump(&host_port, sizeof(host_port), "主机序 port=8080");
    hex_dump(&net_port, sizeof(net_port),   "网络序 port=8080");
    std::cout << "ntohs还原: " << ntohs(net_port) << std::endl;
    std::cout << std::endl;

    // 32位IP地址转换
    uint32_t host_addr = 0xC0A80001;  // 192.168.0.1
    uint32_t net_addr = htonl(host_addr);
    hex_dump(&host_addr, sizeof(host_addr), "主机序 IP=192.168.0.1");
    hex_dump(&net_addr, sizeof(net_addr),   "网络序 IP=192.168.0.1");
    std::cout << "ntohl还原: 0x" << std::hex << ntohl(net_addr)
              << std::dec << std::endl;
}

/*
输出示例（x86_64系统）：
=== 字节序演示 ===
当前系统: 小端序

主机序 port=8080: 90 1f
网络序 port=8080: 1f 90
ntohs还原: 8080

主机序 IP=192.168.0.1: 01 00 a8 c0
网络序 IP=192.168.0.1: c0 a8 00 01
ntohl还原: 0xc0a80001
*/

/*
自测题：

Q1: 在填写sockaddr_in结构体时，哪些字段需要字节序转换？
A1: sin_port需要htons()转换，sin_addr.s_addr需要htonl()转换（或通过inet_pton自动转换）。
    sin_family (AF_INET) 不需要转换，因为它只在本机使用，不会发送到网络上。

Q2: 如果忘记调用htons()直接将端口号赋给sin_port，会出什么问题？
A2: 在小端序机器上，端口号会被错误解释。例如端口8080(0x1F90)会被解释为
    0x901F = 36895。服务器绑定到错误的端口，客户端连接会失败。

Q3: htonl(INADDR_ANY) 结果是什么？为什么很多代码直接写 addr.s_addr = INADDR_ANY？
A3: INADDR_ANY的值是0x00000000，转换后仍然是0。所以htonl(INADDR_ANY) = 0，
    直接赋值结果相同。但写htonl(INADDR_ANY)是好习惯，表明开发者理解字节序。
*/
```

#### 2. sockaddr结构族详解

```cpp
// ============================================================
// Socket地址结构族详解
// ============================================================

/*
┌─────────────────────────────────────────────────────────────────────┐
│                    Socket 地址结构族关系图                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  通用地址结构（用于函数参数类型）                                     │
│  ┌──────────────────────────┐                                        │
│  │ struct sockaddr          │  ← bind/connect/accept等函数的参数类型 │
│  │   sa_family_t sa_family; │     16 bytes                           │
│  │   char sa_data[14];      │                                        │
│  └──────────────────────────┘                                        │
│              ↑ 强制转换                                              │
│   ┌──────────┼──────────┬──────────────────┐                         │
│   │          │          │                  │                         │
│   ▼          ▼          ▼                  ▼                         │
│  ┌────────┐ ┌────────┐ ┌──────────┐ ┌──────────────────┐            │
│  │IPv4    │ │IPv6    │ │Unix域    │ │通用存储           │            │
│  │sockaddr│ │sockaddr│ │sockaddr  │ │sockaddr_storage  │            │
│  │_in     │ │_in6    │ │_un       │ │(足够大，可存储   │            │
│  │16 bytes│ │28 bytes│ │110 bytes │ │ 任何地址类型)     │            │
│  └────────┘ └────────┘ └──────────┘ │128 bytes          │            │
│                                      └──────────────────┘            │
│                                                                      │
│  sockaddr_in 内存布局（IPv4）：                                      │
│  ┌───────────────┬───────────────┬───────────────────────────────┐   │
│  │ sin_family    │ sin_port      │ sin_addr (struct in_addr)    │   │
│  │ AF_INET       │ 网络字节序    │ 网络字节序                    │   │
│  │ 2 bytes       │ 2 bytes       │ 4 bytes                      │   │
│  ├───────────────┴───────────────┴───────────────────────────────┤   │
│  │ sin_zero[8]  (填充，使大小与sockaddr相同，必须置零)            │   │
│  │ 8 bytes                                                       │   │
│  └───────────────────────────────────────────────────────────────┘   │
│  总计: 16 bytes                                                      │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
*/

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <cstring>
#include <iostream>
#include <cassert>

void sockaddr_demo() {
    // ---- 方法1: 传统方式构建 sockaddr_in ----
    struct sockaddr_in addr1;
    memset(&addr1, 0, sizeof(addr1));       // 清零（包括sin_zero）
    addr1.sin_family = AF_INET;             // IPv4
    addr1.sin_port = htons(8080);           // 端口号（网络字节序）
    addr1.sin_addr.s_addr = htonl(INADDR_ANY);  // 任意地址

    // ---- 方法2: C++11 值初始化（推荐）----
    sockaddr_in addr2{};                     // 所有字段自动置零
    addr2.sin_family = AF_INET;
    addr2.sin_port = htons(9090);
    inet_pton(AF_INET, "192.168.1.100", &addr2.sin_addr);

    // ---- 使用时需要强制转换为 sockaddr* ----
    // bind(fd, (struct sockaddr*)&addr2, sizeof(addr2));
    // 或使用C++风格:
    // bind(fd, reinterpret_cast<sockaddr*>(&addr2), sizeof(addr2));

    // ---- sockaddr_in6 (IPv6) ----
    sockaddr_in6 addr6{};
    addr6.sin6_family = AF_INET6;
    addr6.sin6_port = htons(8080);
    inet_pton(AF_INET6, "::1", &addr6.sin6_addr);  // IPv6 loopback

    // ---- sockaddr_storage (通用存储) ----
    // 当不确定是IPv4还是IPv6时使用
    sockaddr_storage storage{};
    // 可以安全地存储任何类型的sockaddr
    memcpy(&storage, &addr2, sizeof(addr2));
    // 通过ss_family判断实际类型
    if (storage.ss_family == AF_INET) {
        auto* v4 = reinterpret_cast<sockaddr_in*>(&storage);
        std::cout << "IPv4 port: " << ntohs(v4->sin_port) << std::endl;
    }

    // 打印结构体大小
    std::cout << "sizeof(sockaddr):         " << sizeof(sockaddr) << std::endl;
    std::cout << "sizeof(sockaddr_in):      " << sizeof(sockaddr_in) << std::endl;
    std::cout << "sizeof(sockaddr_in6):     " << sizeof(sockaddr_in6) << std::endl;
    std::cout << "sizeof(sockaddr_storage): " << sizeof(sockaddr_storage) << std::endl;
}

/*
自测题：

Q1: 为什么sockaddr_in有sin_zero字段？
A1: 为了使sockaddr_in(16字节)与通用的sockaddr(16字节)大小相同，
    这样可以安全地在它们之间进行强制类型转换。sin_zero必须置零。

Q2: 什么时候应该使用sockaddr_storage而不是sockaddr_in？
A2: 当编写需要同时支持IPv4和IPv6的代码时。sockaddr_storage足够大（128字节），
    可以存储任何类型的socket地址。典型场景：accept()返回的客户端地址、
    getaddrinfo()返回的结果处理。
*/
```

#### 3. IP地址转换函数

```cpp
// ============================================================
// IP地址转换函数详解
// ============================================================

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <cstring>
#include <iostream>
#include <string>

/*
┌────────────────────────────────────────────────────────────────┐
│                   地址转换函数对比                               │
├──────────────┬─────────────┬───────────────────────────────────┤
│    函数      │  支持协议    │  说明                              │
├──────────────┼─────────────┼───────────────────────────────────┤
│ inet_addr    │ IPv4 only   │ 已废弃，不能表示255.255.255.255   │
│ inet_aton    │ IPv4 only   │ 比inet_addr好，但仍仅限IPv4       │
│ inet_ntoa    │ IPv4 only   │ 返回静态缓冲区，非线程安全        │
│ inet_pton ★ │ IPv4 + IPv6 │ 推荐！字符串→二进制                │
│ inet_ntop ★ │ IPv4 + IPv6 │ 推荐！二进制→字符串                │
│ getaddrinfo★│ IPv4 + IPv6 │ 推荐！支持DNS解析+服务名           │
└──────────────┴─────────────┴───────────────────────────────────┘
*/

// ---- inet_pton / inet_ntop 使用 ----
void address_conversion_demo() {
    // 字符串 → 二进制 (Presentation to Numeric)
    struct in_addr ipv4_addr;
    int ret = inet_pton(AF_INET, "192.168.1.100", &ipv4_addr);
    if (ret == 1) {
        std::cout << "IPv4转换成功, 网络序值: 0x"
                  << std::hex << ipv4_addr.s_addr << std::dec << std::endl;
    } else if (ret == 0) {
        std::cerr << "无效的IP地址格式" << std::endl;
    } else {
        std::cerr << "不支持的地址族" << std::endl;
    }

    // 二进制 → 字符串 (Numeric to Presentation)
    char str_buf[INET_ADDRSTRLEN];  // IPv4: 16字节足够
    const char* result = inet_ntop(AF_INET, &ipv4_addr, str_buf, sizeof(str_buf));
    if (result) {
        std::cout << "还原: " << str_buf << std::endl;
    }

    // IPv6 示例
    struct in6_addr ipv6_addr;
    inet_pton(AF_INET6, "2001:db8::1", &ipv6_addr);
    char str6_buf[INET6_ADDRSTRLEN];  // IPv6: 46字节足够
    inet_ntop(AF_INET6, &ipv6_addr, str6_buf, sizeof(str6_buf));
    std::cout << "IPv6: " << str6_buf << std::endl;
}

// ---- getaddrinfo 完整用法 ----
void getaddrinfo_demo(const char* host, const char* service) {
    struct addrinfo hints{};
    hints.ai_family = AF_UNSPEC;      // IPv4 或 IPv6 都可以
    hints.ai_socktype = SOCK_STREAM;  // TCP
    hints.ai_flags = AI_PASSIVE;      // 用于服务器bind (host=nullptr时返回INADDR_ANY)

    struct addrinfo* result = nullptr;
    int err = getaddrinfo(host, service, &hints, &result);
    if (err != 0) {
        std::cerr << "getaddrinfo失败: " << gai_strerror(err) << std::endl;
        return;
    }

    // 遍历结果链表（可能有多个地址）
    int count = 0;
    for (struct addrinfo* p = result; p != nullptr; p = p->ai_next) {
        char addr_str[INET6_ADDRSTRLEN];
        void* addr_ptr = nullptr;
        const char* ip_ver = nullptr;
        int port = 0;

        if (p->ai_family == AF_INET) {
            auto* ipv4 = reinterpret_cast<sockaddr_in*>(p->ai_addr);
            addr_ptr = &(ipv4->sin_addr);
            port = ntohs(ipv4->sin_port);
            ip_ver = "IPv4";
        } else if (p->ai_family == AF_INET6) {
            auto* ipv6 = reinterpret_cast<sockaddr_in6*>(p->ai_addr);
            addr_ptr = &(ipv6->sin6_addr);
            port = ntohs(ipv6->sin6_port);
            ip_ver = "IPv6";
        }

        inet_ntop(p->ai_family, addr_ptr, addr_str, sizeof(addr_str));
        std::cout << "[" << ++count << "] " << ip_ver
                  << ": " << addr_str << ":" << port << std::endl;
    }

    freeaddrinfo(result);  // 必须释放！
}

// 使用示例:
// getaddrinfo_demo("www.google.com", "443");
// getaddrinfo_demo(nullptr, "8080");  // 服务器模式

/*
自测题：

Q1: inet_pton的返回值有哪些情况？各代表什么？
A1: 返回1：转换成功
    返回0：输入的地址字符串格式无效（不是合法的IP地址）
    返回-1：af参数不支持（不是AF_INET或AF_INET6），errno被设置

Q2: getaddrinfo为什么可能返回多个结果？
A2: 一个域名可能对应多个IP地址（负载均衡），同时可能有IPv4和IPv6地址。
    getaddrinfo会返回一个链表，包含所有可能的地址。客户端应该依次尝试，
    直到连接成功（Happy Eyeballs算法就是这种思路）。

Q3: 为什么推荐用getaddrinfo而不是直接用inet_pton？
A3: getaddrinfo的优势：
    1. 支持DNS解析（域名→IP），inet_pton只能处理数字IP
    2. 同时支持IPv4和IPv6，自动处理协议差异
    3. 支持服务名到端口号的转换（如"http"→80）
    4. 返回完整的sockaddr结构，可直接用于connect/bind
    5. 是POSIX标准推荐的地址解析方式
*/
```

### Day 5-6：Socket创建与基本配置

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | socket()系统调用详解 | 2h |
| 下午 | 基础Socket配置与信息获取 | 3h |
| 晚上 | 综合练习 | 2h |

#### 1. socket()系统调用详解

```cpp
// ============================================================
// socket() 系统调用与基础配置
// ============================================================

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <cerrno>
#include <cstring>
#include <iostream>
#include <string>

/*
socket() 函数原型:
    int socket(int domain, int type, int protocol);

┌──────────────────────────────────────────────────────────────┐
│  参数说明                                                     │
├──────────┬───────────────────────────────────────────────────┤
│  domain  │ AF_INET    - IPv4                                 │
│          │ AF_INET6   - IPv6                                 │
│          │ AF_UNIX    - Unix域套接字（本机进程间通信）        │
│          │ AF_UNSPEC  - 未指定（用于getaddrinfo）            │
├──────────┼───────────────────────────────────────────────────┤
│  type    │ SOCK_STREAM - 字节流（TCP）                       │
│          │ SOCK_DGRAM  - 数据报（UDP）                       │
│          │ SOCK_RAW    - 原始套接字                           │
│          │ 可与 SOCK_NONBLOCK | SOCK_CLOEXEC 按位或组合      │
├──────────┼───────────────────────────────────────────────────┤
│ protocol │ 0           - 自动选择（通常正确）                │
│          │ IPPROTO_TCP - 明确指定TCP                          │
│          │ IPPROTO_UDP - 明确指定UDP                          │
├──────────┼───────────────────────────────────────────────────┤
│  返回值  │ 成功: 文件描述符 (>= 0)                           │
│          │ 失败: -1, errno 被设置                             │
└──────────┴───────────────────────────────────────────────────┘
*/

// 创建不同类型的Socket
void socket_creation_demo() {
    // TCP Socket (IPv4)
    int tcp_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (tcp_fd < 0) {
        std::cerr << "创建TCP socket失败: " << strerror(errno) << std::endl;
        return;
    }
    std::cout << "TCP Socket fd: " << tcp_fd << std::endl;

    // UDP Socket (IPv4)
    int udp_fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (udp_fd < 0) {
        std::cerr << "创建UDP socket失败: " << strerror(errno) << std::endl;
        close(tcp_fd);
        return;
    }
    std::cout << "UDP Socket fd: " << udp_fd << std::endl;

    // TCP Socket (IPv6)
    int tcp6_fd = socket(AF_INET6, SOCK_STREAM, 0);
    if (tcp6_fd >= 0) {
        std::cout << "TCP6 Socket fd: " << tcp6_fd << std::endl;
        close(tcp6_fd);
    }

    // 非阻塞 TCP Socket（Linux 2.6.27+）
    int nb_fd = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK | SOCK_CLOEXEC, 0);
    if (nb_fd >= 0) {
        std::cout << "Non-blocking Socket fd: " << nb_fd << std::endl;
        close(nb_fd);
    }

    close(udp_fd);
    close(tcp_fd);
}

// 完整的Socket配置示例：创建→设置选项→绑定→获取信息
void socket_setup_demo() {
    // 1. 创建Socket
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) {
        std::cerr << "socket() 失败: " << strerror(errno) << std::endl;
        return;
    }

    // 2. 设置 SO_REUSEADDR（服务器必备）
    int opt = 1;
    if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) < 0) {
        std::cerr << "setsockopt(SO_REUSEADDR) 失败" << std::endl;
        close(fd);
        return;
    }

    // 3. 绑定地址
    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    addr.sin_port = htons(0);  // 端口0：由系统分配可用端口

    if (bind(fd, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) < 0) {
        std::cerr << "bind() 失败: " << strerror(errno) << std::endl;
        close(fd);
        return;
    }

    // 4. 获取系统分配的端口号
    sockaddr_in bound_addr{};
    socklen_t addr_len = sizeof(bound_addr);
    if (getsockname(fd, reinterpret_cast<sockaddr*>(&bound_addr), &addr_len) == 0) {
        char ip_str[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &bound_addr.sin_addr, ip_str, sizeof(ip_str));
        std::cout << "绑定到: " << ip_str << ":" << ntohs(bound_addr.sin_port)
                  << std::endl;
    }

    // 5. 读取缓冲区大小
    int recv_buf = 0;
    socklen_t buf_len = sizeof(recv_buf);
    getsockopt(fd, SOL_SOCKET, SO_RCVBUF, &recv_buf, &buf_len);
    std::cout << "接收缓冲区大小: " << recv_buf << " bytes" << std::endl;

    int send_buf = 0;
    getsockopt(fd, SOL_SOCKET, SO_SNDBUF, &send_buf, &buf_len);
    std::cout << "发送缓冲区大小: " << send_buf << " bytes" << std::endl;

    close(fd);
}

/*
自测题：

Q1: SOCK_NONBLOCK和SOCK_CLOEXEC有什么作用？为什么推荐使用？
A1: SOCK_NONBLOCK: 创建非阻塞socket，等效于后续调用fcntl(fd, F_SETFL, O_NONBLOCK)
    SOCK_CLOEXEC: exec时自动关闭fd，防止子进程继承不需要的socket
    推荐使用是因为它们是原子操作，避免了socket创建后到设置选项之间的竞态条件。

Q2: 为什么绑定端口0？
A2: 端口0让操作系统自动分配一个可用的临时端口。常用于客户端（不需要固定端口）
    或测试场景。可通过getsockname()获取实际分配的端口号。
*/
```

### Day 7：第一周总结与检验

#### 网络基础知识综合自测

```cpp
// ============================================================
// 第一周综合知识自测（15题）
// ============================================================

/*
Q1: OSI模型和TCP/IP模型分别有几层？Socket工作在哪里？
A1: OSI有7层，TCP/IP有4层。Socket工作在传输层与应用层之间的接口位置。

Q2: TCP三次握手每一步的作用？
A2: 第一步(SYN): 客户端告知服务器初始序列号，请求建立连接
    第二步(SYN+ACK): 服务器确认客户端的SYN，同时告知自己的初始序列号
    第三步(ACK): 客户端确认服务器的SYN，握手完成，双方进入ESTABLISHED

Q3: TCP四次挥手为什么不能合并为三次？
A3: 可以合并！如果被动方没有数据要发送，可以将ACK和FIN合并发送（延迟确认机制），
    变成三次挥手。但通常被动方收到FIN后可能还有数据未发完，所以分开发送更安全。

Q4: CLOSE_WAIT状态出现在哪一方？大量CLOSE_WAIT说明什么？
A4: 出现在被动关闭方（收到FIN后进入）。大量CLOSE_WAIT说明程序收到对方关闭
    请求后，没有及时调用close()——通常是代码bug（忘记关闭连接或异常未处理）。

Q5: htons(1)在大端和小端机器上的结果分别是什么？
A5: 大端机器: htons(1) = 1（无需转换）
    小端机器: htons(1) = 256（0x0001 → 0x0100）

Q6: sockaddr_in中的sin_zero字段有什么用？
A6: 填充字段，使sockaddr_in大小等于sockaddr(16字节)。必须置零。

Q7: inet_pton和inet_addr的区别？
A7: inet_pton支持IPv4和IPv6，inet_addr仅支持IPv4且无法表示255.255.255.255
    （因为它用-1表示错误，而255.255.255.255也是-1）。应使用inet_pton。

Q8: getaddrinfo相比inet_pton的优势？
A8: 支持DNS解析、同时处理IPv4/IPv6、支持服务名→端口转换、返回完整sockaddr。

Q9: socket()的type参数为什么可以用 SOCK_STREAM | SOCK_NONBLOCK？
A9: Linux 2.6.27+支持在type中通过位或设置附加标志，这是原子操作，
    避免了socket创建后再设置属性的竞态条件。

Q10: AF_INET和PF_INET有什么区别？
A10: 在实际实现中完全相同（值都是2）。AF=Address Family，PF=Protocol Family，
     POSIX规范建议socket()用PF_，sockaddr用AF_，但在Linux中可互换使用。

Q11: 一个进程最多能打开多少个Socket？如何查看和修改？
A11: 受文件描述符限制。ulimit -n查看（默认通常1024），ulimit -n 65535修改。
     /proc/sys/fs/file-max是系统级上限。

Q12: TCP的MSS(Maximum Segment Size)和MTU的关系？
A12: MTU是链路层的最大传输单元（以太网1500字节），
     MSS = MTU - IP头(20) - TCP头(20) = 1460字节。
     TCP握手时双方协商MSS，取较小值。

Q13: 什么是SYN Flood攻击？和三次握手有什么关系？
A13: 攻击者发送大量SYN但不回复ACK，导致服务器维护大量SYN_RCVD状态的半开连接，
     耗尽资源。防御：SYN Cookie、限制半开连接数、缩短SYN_RCVD超时。

Q14: sockaddr_storage的作用？
A14: 足够大（128字节）的通用地址存储结构，可以安全存储任何类型的sockaddr。
     用于编写协议无关的代码，通过ss_family判断实际地址类型。

Q15: UDP可以调用connect()吗？效果是什么？
A15: 可以。connect()在UDP上不建立连接，只是记录对端地址。之后可以用
     send/recv代替sendto/recvfrom（省去每次指定地址），内核也会过滤
     非对端地址的数据报。此外，connected UDP socket可以接收ICMP错误。
*/
```

#### 第一周检验标准

- [ ] 能画出OSI七层模型和TCP/IP四层模型的对照图
- [ ] 能解释TCP三次握手每一步的作用和状态变迁
- [ ] 能解释TCP四次挥手的过程及TIME_WAIT的作用
- [ ] 能画出TCP完整状态机图
- [ ] 理解大端序和小端序的区别，会使用htons/htonl/ntohs/ntohl
- [ ] 理解sockaddr/sockaddr_in/sockaddr_in6/sockaddr_storage的关系
- [ ] 会使用inet_pton/inet_ntop进行地址转换
- [ ] 会使用getaddrinfo进行DNS解析和地址查询
- [ ] 理解socket()的domain/type/protocol参数含义
- [ ] 能创建TCP和UDP Socket并设置基本选项

---

## 第二周：TCP Socket编程（Day 8-14）

> **本周目标**：掌握完整的TCP服务器/客户端开发，实现多客户端并发处理，
> 理解TCP流式数据的正确处理方式

### Day 8-9：TCP服务器与客户端基础

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | TCP服务器生命周期与API | 3h |
| 下午 | 完整Echo Server/Client实现 | 4h |
| 晚上 | TCP连接过程分析 | 2h |

#### 1. TCP服务器生命周期

```cpp
// ============================================================
// TCP服务器生命周期详解
// ============================================================

/*
┌─────────────────────────────────────────────────────────────────────┐
│                    TCP 服务器生命周期                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   服务器                                        客户端               │
│      │                                            │                  │
│  socket()  ← 创建套接字                           │                  │
│      │                                            │                  │
│  setsockopt() ← 设置选项(SO_REUSEADDR等)         │                  │
│      │                                            │                  │
│   bind()  ← 绑定地址和端口                        │                  │
│      │                                            │                  │
│  listen() ← 开始监听，设置backlog                 │                  │
│      │                                            │                  │
│      │                                        socket()               │
│      │                                            │                  │
│      │         ← SYN ─────────────────────    connect()              │
│      │         ── SYN+ACK ───────────────→        │                  │
│      │         ← ACK ─────────────────────        │                  │
│      │                                            │                  │
│  accept() ← 接受连接，返回新的socket fd           │                  │
│      │                                            │                  │
│   read()  ←───────── 数据 ───────────────   write()                 │
│      │                                            │                  │
│  write()  ─────────── 数据 ──────────────→  read()                  │
│      │                                            │                  │
│      │         ← FIN ─────────────────────   close()                │
│      │         ── ACK ───────────────────→        │                  │
│      │         ── FIN ───────────────────→        │                  │
│      │         ← ACK ─────────────────────        │                  │
│      │                                            │                  │
│   close() ← 关闭连接                              │                  │
│                                                                      │
│  关键点：                                                            │
│  1. listen()的backlog参数指定已完成连接队列的最大长度                 │
│  2. accept()从已完成连接队列取出一个连接，返回新的fd                  │
│  3. 服务器的监听socket和每个客户端连接socket是不同的fd                │
│  4. 并发服务器需要同时处理多个客户端，需要fork/thread/select等         │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘

listen()的backlog参数详解：

  内核为每个监听socket维护两个队列：
  ┌──────────────────────────────────────────────────────┐
  │  未完成连接队列 (SYN Queue)                          │
  │  - 收到SYN，已发送SYN+ACK，等待客户端ACK             │
  │  - 处于SYN_RCVD状态                                  │
  └──────────────────────────────────────────────────────┘
                        ↓ 收到ACK
  ┌──────────────────────────────────────────────────────┐
  │  已完成连接队列 (Accept Queue)                        │
  │  - 三次握手完成，等待accept()取走                    │
  │  - 处于ESTABLISHED状态                               │
  │  - 大小由backlog参数控制（实际值可能与系统设置有关）  │
  └──────────────────────────────────────────────────────┘
                        ↓ accept()
  ┌──────────────────────────────────────────────────────┐
  │  应用程序处理连接                                     │
  └──────────────────────────────────────────────────────┘

  如果Accept Queue满了，新的连接会被拒绝或SYN被丢弃。
  Linux中可通过 /proc/sys/net/core/somaxconn 调整系统最大值（默认128）。
*/
```

#### 2. 完整TCP Echo服务器（迭代版）

```cpp
// ============================================================
// TCP Echo Server - 迭代版（一次只处理一个客户端）
// ============================================================

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <signal.h>
#include <cerrno>
#include <cstring>
#include <iostream>
#include <string>

// 全局变量用于信号处理
volatile sig_atomic_t g_running = 1;

void signal_handler(int sig) {
    if (sig == SIGINT || sig == SIGTERM) {
        g_running = 0;
    }
}

// 处理单个客户端连接
void handle_client(int client_fd, const sockaddr_in& client_addr) {
    char client_ip[INET_ADDRSTRLEN];
    inet_ntop(AF_INET, &client_addr.sin_addr, client_ip, sizeof(client_ip));
    std::cout << "[连接] 客户端 " << client_ip << ":"
              << ntohs(client_addr.sin_port) << std::endl;

    char buffer[1024];
    while (true) {
        // 读取数据
        ssize_t n = read(client_fd, buffer, sizeof(buffer));

        if (n < 0) {
            if (errno == EINTR) continue;  // 被信号中断，重试
            std::cerr << "[错误] read失败: " << strerror(errno) << std::endl;
            break;
        }

        if (n == 0) {
            // 客户端关闭连接
            std::cout << "[断开] 客户端 " << client_ip << ":"
                      << ntohs(client_addr.sin_port) << std::endl;
            break;
        }

        // 回显数据
        ssize_t written = 0;
        while (written < n) {
            ssize_t w = write(client_fd, buffer + written, n - written);
            if (w < 0) {
                if (errno == EINTR) continue;
                std::cerr << "[错误] write失败: " << strerror(errno) << std::endl;
                goto cleanup;
            }
            written += w;
        }
    }

cleanup:
    close(client_fd);
}

int main(int argc, char* argv[]) {
    int port = (argc > 1) ? std::stoi(argv[1]) : 8080;

    // 设置信号处理
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    signal(SIGPIPE, SIG_IGN);  // 忽略SIGPIPE，避免写入已关闭的连接时进程退出

    // 1. 创建socket
    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        std::cerr << "socket()失败: " << strerror(errno) << std::endl;
        return 1;
    }

    // 2. 设置SO_REUSEADDR（允许重用TIME_WAIT状态的地址）
    int opt = 1;
    if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) < 0) {
        std::cerr << "setsockopt()失败: " << strerror(errno) << std::endl;
        close(server_fd);
        return 1;
    }

    // 3. 绑定地址
    sockaddr_in server_addr{};
    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = htonl(INADDR_ANY);
    server_addr.sin_port = htons(port);

    if (bind(server_fd, reinterpret_cast<sockaddr*>(&server_addr),
             sizeof(server_addr)) < 0) {
        std::cerr << "bind()失败: " << strerror(errno) << std::endl;
        close(server_fd);
        return 1;
    }

    // 4. 开始监听
    if (listen(server_fd, SOMAXCONN) < 0) {
        std::cerr << "listen()失败: " << strerror(errno) << std::endl;
        close(server_fd);
        return 1;
    }

    std::cout << "=== TCP Echo Server 启动 ===" << std::endl;
    std::cout << "监听端口: " << port << std::endl;
    std::cout << "按 Ctrl+C 退出" << std::endl;

    // 5. 主循环：接受连接并处理
    while (g_running) {
        sockaddr_in client_addr{};
        socklen_t client_len = sizeof(client_addr);

        int client_fd = accept(server_fd,
                               reinterpret_cast<sockaddr*>(&client_addr),
                               &client_len);

        if (client_fd < 0) {
            if (errno == EINTR) continue;  // 被信号中断
            std::cerr << "accept()失败: " << strerror(errno) << std::endl;
            continue;
        }

        handle_client(client_fd, client_addr);
    }

    // 6. 清理
    std::cout << "\n服务器关闭中..." << std::endl;
    close(server_fd);
    return 0;
}

/*
编译与运行：
$ g++ -o echo_server echo_server.cpp
$ ./echo_server 8080

测试：
$ nc localhost 8080
Hello World  # 输入
Hello World  # 回显

或使用 telnet:
$ telnet localhost 8080
*/
```

#### 3. 完整TCP Echo客户端

```cpp
// ============================================================
// TCP Echo Client - 使用getaddrinfo支持域名解析
// ============================================================

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <unistd.h>
#include <cerrno>
#include <cstring>
#include <iostream>
#include <string>

int connect_to_server(const char* host, const char* port) {
    struct addrinfo hints{};
    hints.ai_family = AF_UNSPEC;      // IPv4 或 IPv6
    hints.ai_socktype = SOCK_STREAM;  // TCP

    struct addrinfo* result = nullptr;
    int err = getaddrinfo(host, port, &hints, &result);
    if (err != 0) {
        std::cerr << "getaddrinfo失败: " << gai_strerror(err) << std::endl;
        return -1;
    }

    int sock_fd = -1;

    // 尝试连接每个地址，直到成功
    for (struct addrinfo* p = result; p != nullptr; p = p->ai_next) {
        sock_fd = socket(p->ai_family, p->ai_socktype, p->ai_protocol);
        if (sock_fd < 0) continue;

        // 显示正在连接的地址
        char addr_str[INET6_ADDRSTRLEN];
        void* addr_ptr = nullptr;
        if (p->ai_family == AF_INET) {
            addr_ptr = &(reinterpret_cast<sockaddr_in*>(p->ai_addr)->sin_addr);
        } else {
            addr_ptr = &(reinterpret_cast<sockaddr_in6*>(p->ai_addr)->sin6_addr);
        }
        inet_ntop(p->ai_family, addr_ptr, addr_str, sizeof(addr_str));
        std::cout << "尝试连接 " << addr_str << "..." << std::endl;

        if (connect(sock_fd, p->ai_addr, p->ai_addrlen) == 0) {
            std::cout << "连接成功!" << std::endl;
            break;  // 连接成功
        }

        std::cerr << "连接失败: " << strerror(errno) << std::endl;
        close(sock_fd);
        sock_fd = -1;
    }

    freeaddrinfo(result);
    return sock_fd;
}

int main(int argc, char* argv[]) {
    if (argc != 3) {
        std::cerr << "用法: " << argv[0] << " <host> <port>" << std::endl;
        std::cerr << "例如: " << argv[0] << " localhost 8080" << std::endl;
        return 1;
    }

    const char* host = argv[1];
    const char* port = argv[2];

    int sock_fd = connect_to_server(host, port);
    if (sock_fd < 0) {
        std::cerr << "无法连接到服务器" << std::endl;
        return 1;
    }

    std::cout << "=== TCP Echo Client ===" << std::endl;
    std::cout << "输入消息，按回车发送，输入 quit 退出" << std::endl;

    std::string line;
    char buffer[1024];

    while (std::getline(std::cin, line)) {
        if (line == "quit") break;
        if (line.empty()) continue;

        // 发送数据（加上换行符）
        line += '\n';
        ssize_t sent = 0;
        while (sent < static_cast<ssize_t>(line.size())) {
            ssize_t n = write(sock_fd, line.data() + sent, line.size() - sent);
            if (n < 0) {
                if (errno == EINTR) continue;
                std::cerr << "write失败: " << strerror(errno) << std::endl;
                goto cleanup;
            }
            sent += n;
        }

        // 接收回显（简化处理：一次read）
        ssize_t received = read(sock_fd, buffer, sizeof(buffer) - 1);
        if (received < 0) {
            std::cerr << "read失败: " << strerror(errno) << std::endl;
            break;
        }
        if (received == 0) {
            std::cout << "服务器关闭了连接" << std::endl;
            break;
        }

        buffer[received] = '\0';
        std::cout << "回显: " << buffer;
    }

cleanup:
    close(sock_fd);
    std::cout << "客户端退出" << std::endl;
    return 0;
}

/*
编译与运行：
$ g++ -o echo_client echo_client.cpp
$ ./echo_client localhost 8080
*/
```

#### 4. TCP连接过程详解

```cpp
// ============================================================
// TCP连接过程分析（Wireshark式报文跟踪）
// ============================================================

/*
假设客户端(192.168.1.100:54321)连接服务器(192.168.1.1:8080)

┌──────────────────────────────────────────────────────────────────────┐
│                    TCP连接建立过程（三次握手）                         │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│ No.  Time     Source          Dest            Protocol  Info          │
│ ───────────────────────────────────────────────────────────────────── │
│  1   0.0000   192.168.1.100   192.168.1.1     TCP       54321→8080    │
│               [SYN] Seq=0 Win=65535 Len=0 MSS=1460                    │
│                                                                       │
│  2   0.0001   192.168.1.1     192.168.1.100   TCP       8080→54321    │
│               [SYN,ACK] Seq=0 Ack=1 Win=65535 Len=0 MSS=1460          │
│                                                                       │
│  3   0.0002   192.168.1.100   192.168.1.1     TCP       54321→8080    │
│               [ACK] Seq=1 Ack=1 Win=65535 Len=0                       │
│                                                                       │
├──────────────────────────────────────────────────────────────────────┤
│                    数据传输过程                                        │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  4   0.0100   192.168.1.100   192.168.1.1     TCP       54321→8080    │
│               [PSH,ACK] Seq=1 Ack=1 Win=65535 Len=12                  │
│               Data: "Hello World\n"                                   │
│                                                                       │
│  5   0.0101   192.168.1.1     192.168.1.100   TCP       8080→54321    │
│               [ACK] Seq=1 Ack=13 Win=65535 Len=0                      │
│                                                                       │
│  6   0.0102   192.168.1.1     192.168.1.100   TCP       8080→54321    │
│               [PSH,ACK] Seq=1 Ack=13 Win=65535 Len=12                 │
│               Data: "Hello World\n" (Echo)                            │
│                                                                       │
│  7   0.0103   192.168.1.100   192.168.1.1     TCP       54321→8080    │
│               [ACK] Seq=13 Ack=13 Win=65535 Len=0                     │
│                                                                       │
├──────────────────────────────────────────────────────────────────────┤
│                    连接关闭过程（四次挥手）                            │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  8   0.0200   192.168.1.100   192.168.1.1     TCP       54321→8080    │
│               [FIN,ACK] Seq=13 Ack=13 Win=65535 Len=0                 │
│                                                                       │
│  9   0.0201   192.168.1.1     192.168.1.100   TCP       8080→54321    │
│               [ACK] Seq=13 Ack=14 Win=65535 Len=0                     │
│                                                                       │
│ 10   0.0202   192.168.1.1     192.168.1.100   TCP       8080→54321    │
│               [FIN,ACK] Seq=13 Ack=14 Win=65535 Len=0                 │
│                                                                       │
│ 11   0.0203   192.168.1.100   192.168.1.1     TCP       54321→8080    │
│               [ACK] Seq=14 Ack=14 Win=65535 Len=0                     │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘

查看TCP连接状态的命令：

# 查看所有TCP连接
$ netstat -ant

# 查看特定端口的连接
$ netstat -ant | grep 8080

# 使用ss命令（更现代）
$ ss -ant

# 查看TIME_WAIT连接数量
$ netstat -ant | grep TIME_WAIT | wc -l

# 使用tcpdump抓包
$ sudo tcpdump -i any -nn port 8080

# 使用tshark（Wireshark命令行版）
$ sudo tshark -i any -f "port 8080"
*/

/*
自测题：

Q1: 为什么服务器需要调用listen()，而客户端不需要？
A1: listen()将socket从主动模式转为被动模式，告诉内核这个socket要用于接受
    连接请求。客户端是主动发起连接的一方，不需要等待别人连接，所以不需要listen。

Q2: accept()返回的新socket和listen的socket有什么区别？
A2: listen socket是监听socket，用于接收连接请求（三次握手）。
    accept返回的是已连接socket（connected socket），用于与特定客户端通信。
    监听socket只有一个，而已连接socket每个客户端一个。

Q3: 如果服务器不调用accept()会怎样？
A3: 客户端仍然可以完成三次握手（由内核处理），连接会进入Accept Queue。
    但如果队列满了，新的连接会被拒绝。已经在队列中的连接会一直等待，
    直到accept()取走或超时。
*/
```

### Day 10-11：多客户端并发处理

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | fork()多进程服务器 | 3h |
| 下午 | 多线程TCP服务器 | 3h |
| 晚上 | TCP流式数据处理 | 3h |

#### 1. fork()多进程服务器

```cpp
// ============================================================
// TCP Echo Server - 多进程版（fork per connection）
// ============================================================

#include <sys/socket.h>
#include <sys/wait.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <signal.h>
#include <cerrno>
#include <cstring>
#include <iostream>

volatile sig_atomic_t g_running = 1;

// SIGCHLD信号处理：回收子进程，防止僵尸进程
void sigchld_handler(int sig) {
    (void)sig;
    int saved_errno = errno;  // 保存errno

    // 非阻塞地回收所有已终止的子进程
    while (waitpid(-1, nullptr, WNOHANG) > 0) {
        // 继续回收
    }

    errno = saved_errno;  // 恢复errno
}

void sigterm_handler(int sig) {
    (void)sig;
    g_running = 0;
}

// 子进程处理函数
void handle_client(int client_fd) {
    char buffer[1024];

    while (true) {
        ssize_t n = read(client_fd, buffer, sizeof(buffer));
        if (n <= 0) break;

        ssize_t written = 0;
        while (written < n) {
            ssize_t w = write(client_fd, buffer + written, n - written);
            if (w <= 0) goto done;
            written += w;
        }
    }

done:
    close(client_fd);
    _exit(0);  // 子进程使用_exit()，不刷新父进程的IO缓冲区
}

int main(int argc, char* argv[]) {
    int port = (argc > 1) ? std::stoi(argv[1]) : 8080;

    // 设置信号处理
    struct sigaction sa_chld{};
    sa_chld.sa_handler = sigchld_handler;
    sigemptyset(&sa_chld.sa_mask);
    sa_chld.sa_flags = SA_RESTART | SA_NOCLDSTOP;  // 自动重启被中断的系统调用
    sigaction(SIGCHLD, &sa_chld, nullptr);

    signal(SIGINT, sigterm_handler);
    signal(SIGTERM, sigterm_handler);
    signal(SIGPIPE, SIG_IGN);

    // 创建监听socket
    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        std::cerr << "socket()失败: " << strerror(errno) << std::endl;
        return 1;
    }

    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    sockaddr_in server_addr{};
    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = htonl(INADDR_ANY);
    server_addr.sin_port = htons(port);

    if (bind(server_fd, reinterpret_cast<sockaddr*>(&server_addr),
             sizeof(server_addr)) < 0) {
        std::cerr << "bind()失败" << std::endl;
        return 1;
    }

    if (listen(server_fd, SOMAXCONN) < 0) {
        std::cerr << "listen()失败" << std::endl;
        return 1;
    }

    std::cout << "=== Fork Echo Server 启动 ===" << std::endl;
    std::cout << "监听端口: " << port << std::endl;

    while (g_running) {
        sockaddr_in client_addr{};
        socklen_t client_len = sizeof(client_addr);

        int client_fd = accept(server_fd,
                               reinterpret_cast<sockaddr*>(&client_addr),
                               &client_len);
        if (client_fd < 0) {
            if (errno == EINTR) continue;
            std::cerr << "accept()失败" << std::endl;
            continue;
        }

        char client_ip[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &client_addr.sin_addr, client_ip, sizeof(client_ip));
        std::cout << "[连接] " << client_ip << ":" << ntohs(client_addr.sin_port)
                  << std::endl;

        pid_t pid = fork();
        if (pid < 0) {
            std::cerr << "fork()失败" << std::endl;
            close(client_fd);
            continue;
        }

        if (pid == 0) {
            // 子进程
            close(server_fd);  // 子进程不需要监听socket
            handle_client(client_fd);
            // handle_client调用_exit()，不会到达这里
        } else {
            // 父进程
            close(client_fd);  // 父进程不需要这个客户端socket
            std::cout << "[子进程] PID=" << pid << std::endl;
        }
    }

    close(server_fd);
    return 0;
}

/*
┌──────────────────────────────────────────────────────────────┐
│  fork()多进程服务器工作原理                                   │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  父进程                  子进程1        子进程2     子进程N   │
│  (监听socket)           (client_fd1)  (client_fd2) ...       │
│       │                      │             │                  │
│   listen()                   │             │                  │
│       │                      │             │                  │
│   accept() ─────────→ fork() │             │                  │
│       │                 │    │             │                  │
│   close(client_fd1)     │    │             │                  │
│       │                 │    │             │                  │
│   accept() ─────────────│───fork()         │                  │
│       │                 │    │    │        │                  │
│   close(client_fd2)     │    │    │        │                  │
│       │                 │    │    │        │                  │
│       ↓                 ↓    ↓    ↓        ↓                  │
│   等待更多连接      处理client1  处理client2  ...             │
│                                                               │
│  优点：                                                       │
│  - 进程隔离，一个客户端的崩溃不影响其他                       │
│  - 编程模型简单                                               │
│                                                               │
│  缺点：                                                       │
│  - fork()开销大（复制进程空间）                               │
│  - 进程间通信复杂                                             │
│  - 难以实现连接间的共享状态                                   │
│                                                               │
└──────────────────────────────────────────────────────────────┘
*/
```

#### 2. 多线程TCP服务器

```cpp
// ============================================================
// TCP Echo Server - 多线程版（thread per connection）
// ============================================================

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <signal.h>
#include <cerrno>
#include <cstring>
#include <iostream>
#include <thread>
#include <atomic>
#include <vector>
#include <mutex>

std::atomic<bool> g_running{true};
std::atomic<int> g_connection_count{0};
constexpr int MAX_CONNECTIONS = 100;

std::mutex g_cout_mutex;  // 保护std::cout

void log(const std::string& msg) {
    std::lock_guard<std::mutex> lock(g_cout_mutex);
    std::cout << msg << std::endl;
}

// 线程函数：处理单个客户端
void handle_client(int client_fd, sockaddr_in client_addr) {
    char client_ip[INET_ADDRSTRLEN];
    inet_ntop(AF_INET, &client_addr.sin_addr, client_ip, sizeof(client_ip));
    int client_port = ntohs(client_addr.sin_port);

    log("[连接] " + std::string(client_ip) + ":" + std::to_string(client_port) +
        " (当前连接数: " + std::to_string(g_connection_count.load()) + ")");

    char buffer[1024];

    while (g_running) {
        ssize_t n = read(client_fd, buffer, sizeof(buffer));

        if (n < 0) {
            if (errno == EINTR) continue;
            break;
        }
        if (n == 0) break;  // 客户端关闭

        // 回显
        ssize_t written = 0;
        while (written < n) {
            ssize_t w = write(client_fd, buffer + written, n - written);
            if (w <= 0) goto cleanup;
            written += w;
        }
    }

cleanup:
    close(client_fd);
    g_connection_count--;
    log("[断开] " + std::string(client_ip) + ":" + std::to_string(client_port) +
        " (剩余连接: " + std::to_string(g_connection_count.load()) + ")");
}

int main(int argc, char* argv[]) {
    int port = (argc > 1) ? std::stoi(argv[1]) : 8080;

    signal(SIGINT, [](int) { g_running = false; });
    signal(SIGPIPE, SIG_IGN);

    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        std::cerr << "socket()失败" << std::endl;
        return 1;
    }

    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    sockaddr_in server_addr{};
    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = htonl(INADDR_ANY);
    server_addr.sin_port = htons(port);

    if (bind(server_fd, reinterpret_cast<sockaddr*>(&server_addr),
             sizeof(server_addr)) < 0) {
        std::cerr << "bind()失败" << std::endl;
        return 1;
    }

    if (listen(server_fd, SOMAXCONN) < 0) {
        std::cerr << "listen()失败" << std::endl;
        return 1;
    }

    std::cout << "=== Multi-Thread Echo Server 启动 ===" << std::endl;
    std::cout << "监听端口: " << port << std::endl;
    std::cout << "最大连接数: " << MAX_CONNECTIONS << std::endl;

    std::vector<std::thread> threads;

    while (g_running) {
        sockaddr_in client_addr{};
        socklen_t client_len = sizeof(client_addr);

        int client_fd = accept(server_fd,
                               reinterpret_cast<sockaddr*>(&client_addr),
                               &client_len);
        if (client_fd < 0) {
            if (errno == EINTR) continue;
            continue;
        }

        // 检查连接数限制
        if (g_connection_count >= MAX_CONNECTIONS) {
            log("[拒绝] 连接数已达上限");
            close(client_fd);
            continue;
        }

        g_connection_count++;

        // 创建线程处理客户端
        threads.emplace_back(handle_client, client_fd, client_addr);
        threads.back().detach();  // 分离线程，自动清理
    }

    std::cout << "\n服务器关闭中..." << std::endl;
    close(server_fd);

    // 给线程一点时间清理
    std::this_thread::sleep_for(std::chrono::milliseconds(100));
    return 0;
}

/*
多线程 vs 多进程对比：

┌──────────────┬────────────────────────┬────────────────────────┐
│     特性     │      多进程(fork)       │     多线程(thread)     │
├──────────────┼────────────────────────┼────────────────────────┤
│ 创建开销     │ 大（复制进程空间）      │ 小（共享进程空间）     │
│ 内存使用     │ 高（每个进程独立空间）  │ 低（共享堆、全局变量） │
│ 通信方式     │ IPC（管道、共享内存等）│ 直接共享内存           │
│ 安全性       │ 高（进程隔离）          │ 低（需要同步）         │
│ 调试难度     │ 较简单                  │ 较复杂（竞态条件）     │
│ 适用场景     │ CPU密集型、需要隔离     │ I/O密集型、需要共享状态│
└──────────────┴────────────────────────┴────────────────────────┘

注意：实际生产环境中，"每连接一线程"模型也有问题：
- 线程数量受限于系统资源
- 大量连接时线程切换开销大
- 更好的方案是使用I/O多路复用（select/poll/epoll）+ 线程池

这些将在Month 26-27详细学习。
*/
```

#### 3. TCP流式数据处理

```cpp
// ============================================================
// TCP流式数据处理：readn/writen/readline
// ============================================================

#include <sys/socket.h>
#include <unistd.h>
#include <cerrno>
#include <cstring>
#include <cstdint>
#include <vector>
#include <string>

/*
TCP是字节流协议，存在以下问题：

问题1: 粘包（Multiple messages received as one）
  发送: send("Hello") + send("World")
  接收: recv() → "HelloWorld"

问题2: 半包（Partial message received）
  发送: send("Hello World")
  接收: recv() → "Hello " (第一次)
        recv() → "World"  (第二次)

解决方案：
1. 定长消息 —— 每条消息固定长度
2. 分隔符 —— 用特殊字符（如\n）分隔消息
3. 长度前缀 —— 消息头包含长度字段
*/

// ---- readn: 读取恰好n个字节 ----
ssize_t readn(int fd, void* buf, size_t n) {
    size_t nleft = n;
    ssize_t nread;
    char* ptr = static_cast<char*>(buf);

    while (nleft > 0) {
        nread = read(fd, ptr, nleft);

        if (nread < 0) {
            if (errno == EINTR) continue;  // 被信号中断，重试
            return -1;                      // 其他错误
        }

        if (nread == 0) break;  // EOF（对端关闭）

        nleft -= nread;
        ptr += nread;
    }

    return n - nleft;  // 返回实际读取的字节数
}

// ---- writen: 写入恰好n个字节 ----
ssize_t writen(int fd, const void* buf, size_t n) {
    size_t nleft = n;
    ssize_t nwritten;
    const char* ptr = static_cast<const char*>(buf);

    while (nleft > 0) {
        nwritten = write(fd, ptr, nleft);

        if (nwritten < 0) {
            if (errno == EINTR) continue;
            return -1;
        }

        // write不会返回0（除非n=0）
        nleft -= nwritten;
        ptr += nwritten;
    }

    return n;
}

// ---- readline: 读取一行（以\n结尾）----
// 注意：这个实现每次读一个字节，效率较低
// 生产代码应该使用缓冲区
ssize_t readline(int fd, void* buf, size_t maxlen) {
    char* ptr = static_cast<char*>(buf);
    size_t n;

    for (n = 0; n < maxlen - 1; n++) {
        char c;
        ssize_t rc = read(fd, &c, 1);

        if (rc < 0) {
            if (errno == EINTR) {
                n--;  // 重试当前位置
                continue;
            }
            return -1;
        }

        if (rc == 0) {
            break;  // EOF
        }

        *ptr++ = c;
        if (c == '\n') {
            n++;
            break;  // 读到换行符
        }
    }

    *ptr = '\0';
    return n;
}

// ============================================================
// 长度前缀协议实现
// ============================================================

/*
消息格式:
┌────────────────┬────────────────────────────────┐
│  长度 (4字节)   │         消息体                 │
│  网络字节序     │       (可变长度)               │
└────────────────┴────────────────────────────────┘
*/

// 发送带长度前缀的消息
bool send_message(int fd, const void* data, uint32_t len) {
    // 发送长度（网络字节序）
    uint32_t net_len = htonl(len);
    if (writen(fd, &net_len, sizeof(net_len)) != sizeof(net_len)) {
        return false;
    }

    // 发送数据
    if (len > 0 && writen(fd, data, len) != static_cast<ssize_t>(len)) {
        return false;
    }

    return true;
}

// 接收带长度前缀的消息
// 返回消息体，失败返回空vector
std::vector<char> recv_message(int fd) {
    // 读取长度
    uint32_t net_len;
    if (readn(fd, &net_len, sizeof(net_len)) != sizeof(net_len)) {
        return {};
    }

    uint32_t len = ntohl(net_len);

    // 防止恶意大长度
    constexpr uint32_t MAX_MESSAGE_SIZE = 10 * 1024 * 1024;  // 10MB
    if (len > MAX_MESSAGE_SIZE) {
        return {};
    }

    // 读取消息体
    std::vector<char> buffer(len);
    if (len > 0 && readn(fd, buffer.data(), len) != static_cast<ssize_t>(len)) {
        return {};
    }

    return buffer;
}

/*
自测题：

Q1: 为什么readn/writen要用循环？
A1: 因为read/write可能返回比请求少的字节数：
    - read: 内核缓冲区数据不足、被信号中断
    - write: 内核缓冲区空间不足、被信号中断
    循环确保读写完整的数据。

Q2: readline为什么每次只读一个字节？有什么问题？
A2: 为了精确找到\n的位置。问题是效率低——每个字节一次系统调用。
    改进方案：使用带缓冲的读取，一次读多个字节到用户空间缓冲区，
    然后在缓冲区中查找\n。这需要维护缓冲区状态。

Q3: 长度前缀协议中，为什么要限制最大消息长度？
A3: 防止恶意客户端发送超大长度值，导致服务器分配过多内存（DoS攻击）。
    应该根据实际需求设置合理的上限。
*/
```

### Day 12-13：TCP高级特性

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | TCP Keep-Alive配置 | 2h |
| 下午 | 优雅关闭与半关闭 | 3h |
| 晚上 | 信号处理与中断恢复 | 3h |

#### 1. TCP Keep-Alive配置

```cpp
// ============================================================
// TCP Keep-Alive 配置
// ============================================================

#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <unistd.h>
#include <iostream>

/*
TCP Keep-Alive 机制：

当连接空闲一段时间后，发送探测包确认对端是否存活。

┌────────────────────────────────────────────────────────────────┐
│  Keep-Alive 参数                                               │
├────────────────────────────────────────────────────────────────┤
│  TCP_KEEPIDLE  : 连接空闲多久后开始发送探测包（默认7200秒=2小时）│
│  TCP_KEEPINTVL : 探测包发送间隔（默认75秒）                      │
│  TCP_KEEPCNT   : 最多发送几个探测包（默认9次）                   │
├────────────────────────────────────────────────────────────────┤
│  默认行为：                                                     │
│  空闲2小时后，每75秒发一个探测包，发9次无响应则认为连接断开       │
│  总计: 2小时 + 75秒 × 9 ≈ 2小时11分钟 才能检测到死连接          │
│                                                                 │
│  对于需要快速检测断连的应用（如实时通信），默认值太慢            │
└────────────────────────────────────────────────────────────────┘
*/

bool configure_keepalive(int fd, int idle_sec, int interval_sec, int count) {
    // 1. 开启Keep-Alive
    int keepalive = 1;
    if (setsockopt(fd, SOL_SOCKET, SO_KEEPALIVE, &keepalive, sizeof(keepalive)) < 0) {
        return false;
    }

    // 2. 设置空闲时间（多久无数据后开始探测）
    if (setsockopt(fd, IPPROTO_TCP, TCP_KEEPIDLE, &idle_sec, sizeof(idle_sec)) < 0) {
        return false;
    }

    // 3. 设置探测间隔
    if (setsockopt(fd, IPPROTO_TCP, TCP_KEEPINTVL, &interval_sec, sizeof(interval_sec)) < 0) {
        return false;
    }

    // 4. 设置探测次数
    if (setsockopt(fd, IPPROTO_TCP, TCP_KEEPCNT, &count, sizeof(count)) < 0) {
        return false;
    }

    return true;
}

void print_keepalive_settings(int fd) {
    int keepalive, idle, interval, count;
    socklen_t len = sizeof(int);

    getsockopt(fd, SOL_SOCKET, SO_KEEPALIVE, &keepalive, &len);
    getsockopt(fd, IPPROTO_TCP, TCP_KEEPIDLE, &idle, &len);
    getsockopt(fd, IPPROTO_TCP, TCP_KEEPINTVL, &interval, &len);
    getsockopt(fd, IPPROTO_TCP, TCP_KEEPCNT, &count, &len);

    std::cout << "=== Keep-Alive 设置 ===" << std::endl;
    std::cout << "SO_KEEPALIVE:  " << (keepalive ? "开启" : "关闭") << std::endl;
    std::cout << "TCP_KEEPIDLE:  " << idle << " 秒" << std::endl;
    std::cout << "TCP_KEEPINTVL: " << interval << " 秒" << std::endl;
    std::cout << "TCP_KEEPCNT:   " << count << " 次" << std::endl;

    int total_time = idle + interval * count;
    std::cout << "最长检测时间: " << total_time << " 秒" << std::endl;
}

// 使用示例
void setup_connection(int fd) {
    // 空闲60秒后开始探测，每10秒一次，最多5次
    // 总计: 60 + 10*5 = 110秒检测到死连接
    configure_keepalive(fd, 60, 10, 5);
    print_keepalive_settings(fd);
}

/*
Keep-Alive vs 应用层心跳：

┌──────────────────┬──────────────────────┬──────────────────────┐
│       特性       │    TCP Keep-Alive    │     应用层心跳       │
├──────────────────┼──────────────────────┼──────────────────────┤
│ 实现位置         │ 内核TCP协议栈        │ 应用程序             │
│ 配置粒度         │ 系统级或socket级     │ 完全自定义           │
│ 探测内容         │ 空ACK包              │ 自定义数据           │
│ 穿透代理         │ 可能被代理过滤       │ 通常可以穿透         │
│ 检测应用层挂死   │ 不能                 │ 能                   │
│ 资源消耗         │ 低                   │ 稍高（需要定时器）   │
└──────────────────┴──────────────────────┴──────────────────────┘

建议：
- 简单场景用TCP Keep-Alive
- 需要检测应用层响应能力时用应用层心跳
- 可以两者结合使用
*/
```

#### 2. 优雅关闭与半关闭

```cpp
// ============================================================
// TCP优雅关闭与半关闭
// ============================================================

#include <sys/socket.h>
#include <unistd.h>
#include <iostream>

/*
close() vs shutdown()：

close(fd):
  - 关闭文件描述符，减少引用计数
  - 引用计数为0时，发送FIN关闭连接
  - 双向关闭：之后不能读也不能写
  - 如果有未发送的数据，可能会丢失

shutdown(fd, how):
  - 直接关闭连接的某个方向（不管引用计数）
  - 可以只关闭读或写，实现半关闭
  - how 参数:
    SHUT_RD   (0) - 关闭读端，之后read返回0
    SHUT_WR   (1) - 关闭写端，发送FIN
    SHUT_RDWR (2) - 同时关闭读写

半关闭的应用场景：
  客户端发送完所有数据后，调用 shutdown(SHUT_WR) 告诉服务器"我发完了"，
  但仍然可以接收服务器的响应。服务器收到FIN后知道客户端数据发送完毕，
  处理完后再关闭连接。
*/

/*
┌─────────────────────────────────────────────────────────────────┐
│               优雅关闭示例：文件传输                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   客户端                                      服务器             │
│      │                                          │                │
│      │  ──── 文件数据块1 ────────────────→      │                │
│      │  ──── 文件数据块2 ────────────────→      │                │
│      │  ──── 文件数据块N ────────────────→      │                │
│      │                                          │                │
│  shutdown(SHUT_WR)  ← 客户端数据发送完毕        │                │
│      │  ──── FIN ────────────────────────→      │                │
│      │                                          │                │
│      │                               read()返回0，知道数据接收完  │
│      │                               处理数据...                 │
│      │                                          │                │
│      │  ←─── 处理结果/ACK ────────────────      │                │
│      │                                          │                │
│      │  ←─── FIN ────────────────────────   close()              │
│      │                                          │                │
│   close()                                       │                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
*/

// 客户端优雅关闭示例
void client_graceful_close(int sock_fd, const char* data, size_t len) {
    // 1. 发送所有数据
    size_t sent = 0;
    while (sent < len) {
        ssize_t n = write(sock_fd, data + sent, len - sent);
        if (n <= 0) return;
        sent += n;
    }

    // 2. 关闭写端，通知服务器我发完了
    shutdown(sock_fd, SHUT_WR);
    std::cout << "客户端: 数据发送完毕，关闭写端" << std::endl;

    // 3. 继续接收服务器的响应
    char buffer[1024];
    while (true) {
        ssize_t n = read(sock_fd, buffer, sizeof(buffer) - 1);
        if (n <= 0) break;
        buffer[n] = '\0';
        std::cout << "服务器响应: " << buffer << std::endl;
    }

    // 4. 完全关闭
    close(sock_fd);
}

// SO_LINGER选项：控制close()的行为
void configure_linger(int fd, bool enable, int timeout_sec) {
    struct linger lg;
    lg.l_onoff = enable ? 1 : 0;
    lg.l_linger = timeout_sec;

    setsockopt(fd, SOL_SOCKET, SO_LINGER, &lg, sizeof(lg));
}

/*
SO_LINGER 的三种行为：

1. l_onoff = 0（默认）
   close()立即返回，内核继续尝试发送缓冲区数据，然后正常四次挥手

2. l_onoff = 1, l_linger = 0
   close()立即返回，丢弃发送缓冲区数据，发送RST强制关闭
   用于异常关闭，避免TIME_WAIT

3. l_onoff = 1, l_linger > 0
   close()阻塞，等待数据发送完成或超时
   超时后发送RST
   阻塞时间最长l_linger秒
*/
```

#### 3. 信号处理与中断恢复

```cpp
// ============================================================
// 信号安全的TCP服务器
// ============================================================

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <signal.h>
#include <fcntl.h>
#include <cerrno>
#include <cstring>
#include <iostream>

/*
信号处理的挑战：

1. 慢系统调用可能被信号中断
   - read/write/accept/connect 等可能返回 -1，errno = EINTR
   - 需要检查EINTR并重试

2. 信号处理函数只能调用异步信号安全函数
   - 不能使用 printf, malloc, 大多数标准库函数
   - 可以使用：read, write, close, _exit, signal 等

3. 信号可能在任何时刻到来
   - 主逻辑和信号处理函数之间存在竞态条件
   - 共享变量必须是 volatile sig_atomic_t 类型
*/

// 信号安全的写函数（用于信号处理函数中）
void safe_write(int fd, const char* msg) {
    size_t len = strlen(msg);
    while (len > 0) {
        ssize_t n = write(fd, msg, len);
        if (n <= 0) return;
        msg += n;
        len -= n;
    }
}

// ============================================================
// Self-pipe trick：将信号转换为I/O事件
// ============================================================

/*
Self-pipe trick 原理：

问题：如何在select/poll/epoll循环中安全地处理信号？
     信号可能在select返回后、处理新事件前到达，导致遗漏。

解决：创建一个管道，信号处理函数向管道写入，主循环通过select监控管道。

  ┌─────────────────────────────────────────────────────────┐
  │                                                          │
  │   signal_handler()  ────→  pipe[1]  ────→  主循环select  │
  │         │                    写端          监控pipe[0]   │
  │         │                                                │
  │   设置 volatile flag                                     │
  │   write(pipe[1], "x", 1)                                 │
  │                                                          │
  └─────────────────────────────────────────────────────────┘
*/

int g_signal_pipe[2] = {-1, -1};
volatile sig_atomic_t g_shutdown_flag = 0;

void signal_to_pipe_handler(int sig) {
    int saved_errno = errno;
    g_shutdown_flag = 1;

    // 向管道写入一个字节，通知主循环
    char c = static_cast<char>(sig);
    write(g_signal_pipe[1], &c, 1);  // 异步信号安全

    errno = saved_errno;
}

bool setup_signal_pipe() {
    // 创建管道
    if (pipe(g_signal_pipe) < 0) {
        return false;
    }

    // 设置为非阻塞
    for (int i = 0; i < 2; i++) {
        int flags = fcntl(g_signal_pipe[i], F_GETFL);
        fcntl(g_signal_pipe[i], F_SETFL, flags | O_NONBLOCK);
    }

    // 设置信号处理
    struct sigaction sa{};
    sa.sa_handler = signal_to_pipe_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;  // 不使用SA_RESTART，让系统调用返回EINTR

    sigaction(SIGINT, &sa, nullptr);
    sigaction(SIGTERM, &sa, nullptr);

    return true;
}

// 使用self-pipe的服务器主循环框架
void server_main_loop_with_self_pipe(int server_fd) {
    fd_set read_fds;
    int max_fd = std::max(server_fd, g_signal_pipe[0]);

    while (!g_shutdown_flag) {
        FD_ZERO(&read_fds);
        FD_SET(server_fd, &read_fds);
        FD_SET(g_signal_pipe[0], &read_fds);  // 监控信号管道

        int ret = select(max_fd + 1, &read_fds, nullptr, nullptr, nullptr);

        if (ret < 0) {
            if (errno == EINTR) continue;
            break;
        }

        // 检查信号管道
        if (FD_ISSET(g_signal_pipe[0], &read_fds)) {
            char buf[16];
            read(g_signal_pipe[0], buf, sizeof(buf));  // 清空管道
            std::cout << "\n收到退出信号" << std::endl;
            break;
        }

        // 检查新连接
        if (FD_ISSET(server_fd, &read_fds)) {
            sockaddr_in client_addr{};
            socklen_t client_len = sizeof(client_addr);
            int client_fd = accept(server_fd,
                                   reinterpret_cast<sockaddr*>(&client_addr),
                                   &client_len);
            if (client_fd >= 0) {
                // 处理新连接...
                std::cout << "新连接" << std::endl;
                close(client_fd);
            }
        }
    }
}

/*
自测题：

Q1: 为什么read/write可能返回EINTR？
A1: 当进程在这些系统调用中阻塞时，如果收到一个信号且信号处理函数返回了，
    系统调用会被中断并返回-1，errno设为EINTR。这是为了让进程有机会
    响应信号后决定是否继续操作。

Q2: SA_RESTART标志的作用？
A2: 设置SA_RESTART后，被信号中断的系统调用会自动重启，不返回EINTR。
    但不是所有系统调用都支持，且可能导致信号响应延迟。
    对于需要快速响应信号的场景，不建议使用。

Q3: 为什么signal handler中不能使用printf？
A3: printf不是异步信号安全函数——它内部使用了锁和缓冲区。
    如果主程序正在调用printf时收到信号，信号处理函数中再调用printf
    可能导致死锁或数据损坏。只能使用write等异步信号安全函数。
*/
```

### Day 14：第二周总结与检验

#### TCP编程模式总结

```cpp
// ============================================================
// 第二周：TCP编程模式对比总结
// ============================================================

/*
┌────────────────────────────────────────────────────────────────────┐
│                    TCP服务器模型对比                                │
├──────────────┬──────────────┬──────────────┬──────────────────────┤
│    模型      │    迭代式    │    多进程    │       多线程         │
├──────────────┼──────────────┼──────────────┼──────────────────────┤
│ 并发能力     │ 无(串行)     │ 高           │ 高                   │
│ 实现复杂度   │ 低           │ 中           │ 中                   │
│ 资源消耗     │ 最低         │ 高(进程开销) │ 中(线程开销)         │
│ 隔离性       │ N/A          │ 好(进程隔离) │ 差(需要同步)         │
│ 状态共享     │ N/A          │ 难(IPC)      │ 易(共享内存)         │
│ 适用场景     │ 调试/简单    │ CPU密集型    │ I/O密集型            │
│ 最大连接数   │ 1            │ ~数千        │ ~数千                │
├──────────────┴──────────────┴──────────────┴──────────────────────┤
│                                                                    │
│  后续学习的更好方案（Month 26-27）：                               │
│  - I/O多路复用 (select/poll/epoll) + 非阻塞I/O                    │
│  - 事件驱动模型                                                    │
│  - 线程池                                                          │
│  - 协程                                                            │
│  这些方案可以处理数万甚至数十万并发连接                            │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘

TCP编程关键API总结：

服务器端：
  socket()      - 创建socket
  setsockopt()  - 设置选项（SO_REUSEADDR等）
  bind()        - 绑定地址
  listen()      - 开始监听
  accept()      - 接受连接，返回新socket
  read/recv()   - 接收数据
  write/send()  - 发送数据
  shutdown()    - 半关闭
  close()       - 关闭socket

客户端：
  socket()      - 创建socket
  connect()     - 连接服务器
  read/recv()   - 接收数据
  write/send()  - 发送数据
  close()       - 关闭socket

关键技巧：
  - 服务器必须设置 SO_REUSEADDR
  - 忽略 SIGPIPE，避免写入已关闭连接时进程退出
  - 处理 EINTR，正确处理信号中断
  - 使用 readn/writen 确保完整读写
  - 实现消息边界（长度前缀/分隔符）
  - Keep-Alive 或应用层心跳检测死连接
*/
```

#### 第二周检验标准

- [ ] 能画出TCP服务器生命周期图（socket→bind→listen→accept→read/write→close）
- [ ] 能解释listen()的backlog参数和两个队列的作用
- [ ] 实现完整的TCP Echo Server（含错误处理、信号处理）
- [ ] 实现完整的TCP Echo Client（含getaddrinfo地址解析）
- [ ] 理解fork()多进程服务器的工作原理，能正确处理SIGCHLD
- [ ] 理解多线程服务器的工作原理，能正确处理线程安全问题
- [ ] 掌握TCP流式数据处理，能实现readn/writen/长度前缀协议
- [ ] 理解shutdown()与close()的区别，能实现优雅关闭
- [ ] 掌握TCP Keep-Alive的配置
- [ ] 理解信号处理与EINTR，了解self-pipe trick

---

## 第三周：UDP Socket编程与高级主题（Day 15-21）

> **本周目标**：掌握UDP编程范式，理解广播/组播通信，
> 掌握DNS解析和地址转换工具函数

### Day 15-16：UDP基础编程

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | UDP编程模型与API | 2h |
| 下午 | 完整UDP Echo Server/Client | 3h |
| 晚上 | UDP数据报特性分析 | 2h |

#### 1. UDP编程模型

```cpp
// ============================================================
// UDP编程模型详解
// ============================================================

/*
┌─────────────────────────────────────────────────────────────────────┐
│            UDP vs TCP 服务器生命周期对比                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   TCP 服务器                              UDP 服务器                 │
│      │                                        │                      │
│  socket(SOCK_STREAM)                    socket(SOCK_DGRAM)          │
│      │                                        │                      │
│   bind()                                   bind()                    │
│      │                                        │                      │
│  listen()  ← UDP不需要！                      │                      │
│      │                                        │                      │
│  accept()  ← UDP不需要！                      │                      │
│      │                                        │                      │
│  read()/write()                        recvfrom()/sendto()          │
│      │                                        │                      │
│   close()                                  close()                   │
│                                                                      │
│  关键区别：                                                          │
│  1. UDP没有listen/accept，因为它是无连接的                           │
│  2. UDP用recvfrom/sendto，每次收发都要指定/获取对端地址              │
│  3. UDP服务器只需要一个socket就能服务所有客户端                      │
│  4. TCP需要为每个客户端创建一个新socket（accept返回）                │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘

UDP编程的特点：

┌─────────────────────────────────────────────────────────────────────┐
│  UDP特性                                                             │
├─────────────────────────────────────────────────────────────────────┤
│  ✓ 消息边界保留 - sendto发N字节，recvfrom收N字节（不会粘包）         │
│  ✓ 无连接开销 - 没有三次握手/四次挥手                                │
│  ✓ 支持广播/组播 - TCP只能一对一                                    │
│  ✓ 低延迟 - 没有确认/重传/拥塞控制                                   │
│                                                                      │
│  ✗ 不可靠 - 数据可能丢失、重复、乱序                                │
│  ✗ 无流量控制 - 发送过快可能导致接收方丢包                          │
│  ✗ 报文大小受限 - 超过MTU会分片，增加丢失概率                       │
└─────────────────────────────────────────────────────────────────────┘
*/

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <cerrno>
#include <cstring>
#include <iostream>

/*
UDP关键API：

ssize_t sendto(int sockfd, const void *buf, size_t len, int flags,
               const struct sockaddr *dest_addr, socklen_t addrlen);

ssize_t recvfrom(int sockfd, void *buf, size_t len, int flags,
                 struct sockaddr *src_addr, socklen_t *addrlen);

参数说明：
- sockfd: UDP socket文件描述符
- buf/len: 数据缓冲区和长度
- flags: 通常为0，可用MSG_DONTWAIT等
- dest_addr/src_addr: 目的/源地址
- addrlen: 地址结构长度（recvfrom是值-结果参数）
*/
```

#### 2. 完整UDP Echo服务器

```cpp
// ============================================================
// UDP Echo Server - 完整实现
// ============================================================

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <signal.h>
#include <cerrno>
#include <cstring>
#include <iostream>

volatile sig_atomic_t g_running = 1;

void signal_handler(int sig) {
    (void)sig;
    g_running = 0;
}

int main(int argc, char* argv[]) {
    int port = (argc > 1) ? std::stoi(argv[1]) : 8080;

    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);

    // 1. 创建UDP socket
    int sock_fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock_fd < 0) {
        std::cerr << "socket()失败: " << strerror(errno) << std::endl;
        return 1;
    }

    // 2. 设置SO_REUSEADDR（可选，但推荐）
    int opt = 1;
    setsockopt(sock_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    // 3. 绑定地址
    sockaddr_in server_addr{};
    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = htonl(INADDR_ANY);
    server_addr.sin_port = htons(port);

    if (bind(sock_fd, reinterpret_cast<sockaddr*>(&server_addr),
             sizeof(server_addr)) < 0) {
        std::cerr << "bind()失败: " << strerror(errno) << std::endl;
        close(sock_fd);
        return 1;
    }

    std::cout << "=== UDP Echo Server 启动 ===" << std::endl;
    std::cout << "监听端口: " << port << std::endl;
    std::cout << "按 Ctrl+C 退出" << std::endl;

    // 4. 主循环：接收并回显
    char buffer[65535];  // UDP最大报文大小
    sockaddr_in client_addr{};
    socklen_t client_len;

    while (g_running) {
        client_len = sizeof(client_addr);

        // 接收数据报
        ssize_t n = recvfrom(sock_fd, buffer, sizeof(buffer), 0,
                             reinterpret_cast<sockaddr*>(&client_addr),
                             &client_len);

        if (n < 0) {
            if (errno == EINTR) continue;
            std::cerr << "recvfrom()失败: " << strerror(errno) << std::endl;
            continue;
        }

        // 显示客户端信息
        char client_ip[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &client_addr.sin_addr, client_ip, sizeof(client_ip));
        std::cout << "[收到] " << client_ip << ":" << ntohs(client_addr.sin_port)
                  << " - " << n << " bytes" << std::endl;

        // 回显数据
        ssize_t sent = sendto(sock_fd, buffer, n, 0,
                              reinterpret_cast<sockaddr*>(&client_addr),
                              client_len);
        if (sent < 0) {
            std::cerr << "sendto()失败: " << strerror(errno) << std::endl;
        }
    }

    std::cout << "\n服务器关闭" << std::endl;
    close(sock_fd);
    return 0;
}

/*
编译与运行：
$ g++ -o udp_echo_server udp_echo_server.cpp
$ ./udp_echo_server 8080

测试：
$ nc -u localhost 8080
Hello UDP    # 输入
Hello UDP    # 回显
*/
```

#### 3. 完整UDP Echo客户端

```cpp
// ============================================================
// UDP Echo Client - 带超时和重试
// ============================================================

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <unistd.h>
#include <cerrno>
#include <cstring>
#include <iostream>
#include <string>

// 设置接收超时
bool set_recv_timeout(int fd, int timeout_sec) {
    struct timeval tv;
    tv.tv_sec = timeout_sec;
    tv.tv_usec = 0;
    return setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv)) == 0;
}

int main(int argc, char* argv[]) {
    if (argc != 3) {
        std::cerr << "用法: " << argv[0] << " <host> <port>" << std::endl;
        return 1;
    }

    const char* host = argv[1];
    const char* port = argv[2];

    // 1. 解析服务器地址
    struct addrinfo hints{};
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_DGRAM;

    struct addrinfo* result = nullptr;
    int err = getaddrinfo(host, port, &hints, &result);
    if (err != 0) {
        std::cerr << "getaddrinfo失败: " << gai_strerror(err) << std::endl;
        return 1;
    }

    // 2. 创建UDP socket
    int sock_fd = socket(result->ai_family, result->ai_socktype,
                         result->ai_protocol);
    if (sock_fd < 0) {
        std::cerr << "socket()失败" << std::endl;
        freeaddrinfo(result);
        return 1;
    }

    // 3. 可选：对UDP socket调用connect()
    // 这样可以使用send/recv代替sendto/recvfrom，并且能接收ICMP错误
    if (connect(sock_fd, result->ai_addr, result->ai_addrlen) < 0) {
        std::cerr << "connect()失败" << std::endl;
        close(sock_fd);
        freeaddrinfo(result);
        return 1;
    }
    freeaddrinfo(result);

    // 4. 设置接收超时
    set_recv_timeout(sock_fd, 3);  // 3秒超时

    std::cout << "=== UDP Echo Client ===" << std::endl;
    std::cout << "输入消息，按回车发送，输入 quit 退出" << std::endl;
    std::cout << "接收超时: 3秒，最多重试3次" << std::endl;

    std::string line;
    char buffer[1024];

    while (std::getline(std::cin, line)) {
        if (line == "quit") break;
        if (line.empty()) continue;

        // 发送数据
        if (send(sock_fd, line.c_str(), line.size(), 0) < 0) {
            std::cerr << "send()失败: " << strerror(errno) << std::endl;
            continue;
        }

        // 接收回显（带重试）
        constexpr int MAX_RETRIES = 3;
        bool received = false;

        for (int retry = 0; retry < MAX_RETRIES; retry++) {
            ssize_t n = recv(sock_fd, buffer, sizeof(buffer) - 1, 0);

            if (n > 0) {
                buffer[n] = '\0';
                std::cout << "回显: " << buffer << std::endl;
                received = true;
                break;
            }

            if (errno == EAGAIN || errno == EWOULDBLOCK) {
                std::cout << "超时，重试 " << (retry + 1) << "/" << MAX_RETRIES
                          << std::endl;
                // 重发
                send(sock_fd, line.c_str(), line.size(), 0);
            } else {
                std::cerr << "recv()失败: " << strerror(errno) << std::endl;
                break;
            }
        }

        if (!received) {
            std::cout << "无法收到回显，可能数据丢失" << std::endl;
        }
    }

    close(sock_fd);
    return 0;
}

/*
UDP socket调用connect()的作用：

1. 记录对端地址，之后可以用send/recv代替sendto/recvfrom
2. 内核会过滤非对端地址的数据报
3. 可以接收ICMP错误（如端口不可达）—— 未connect的UDP不会收到
4. 效率稍高（不需要每次指定地址）

注意：UDP的connect()不会发送任何数据包，只是在内核中记录对端地址
*/
```

#### 4. UDP数据报特性分析

```cpp
// ============================================================
// UDP数据报特性详解
// ============================================================

/*
┌─────────────────────────────────────────────────────────────────────┐
│                    UDP 消息边界演示                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  TCP（字节流）：                                                    │
│    send("Hello")  ──→  可能收到 "Hel" + "lo"                       │
│    send("World")  ──→  可能收到 "HelloWorld"                        │
│                                                                      │
│  UDP（数据报）：                                                    │
│    sendto("Hello")  ──→  recvfrom一定收到完整 "Hello"               │
│    sendto("World")  ──→  recvfrom一定收到完整 "World"               │
│                                                                      │
│  但是UDP可能：                                                       │
│    - 丢失（收不到）                                                  │
│    - 乱序（先发的后到）                                              │
│    - 重复（同一个包收到多次，罕见但可能）                            │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘

UDP报文大小限制：

┌─────────────────────────────────────────────────────────────────────┐
│  理论最大值：65535 - 20(IP头) - 8(UDP头) = 65507 bytes              │
│                                                                      │
│  实际限制（以太网）：                                                │
│    MTU = 1500 bytes (以太网最大传输单元)                            │
│    MSS = 1500 - 20(IP) - 8(UDP) = 1472 bytes                       │
│                                                                      │
│  建议：                                                              │
│    - 如果数据 <= 1472 bytes，不会分片                               │
│    - 如果数据 > 1472 bytes，IP层会分片                             │
│    - 分片增加丢失概率（任一分片丢失 → 整个报文丢失）                 │
│    - 实际应用通常限制在 512 bytes 以内（DNS的默认限制）              │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
*/

#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <iostream>

// 演示UDP消息边界
void udp_message_boundary_demo() {
    int sv[2];  // socket pair

    // 创建UDP socket pair（用于本地演示）
    if (socketpair(AF_UNIX, SOCK_DGRAM, 0, sv) < 0) {
        std::cerr << "socketpair失败" << std::endl;
        return;
    }

    // 发送两条消息
    const char* msg1 = "Hello";
    const char* msg2 = "World";
    send(sv[0], msg1, strlen(msg1), 0);
    send(sv[0], msg2, strlen(msg2), 0);

    // 接收
    char buf[100];
    ssize_t n1 = recv(sv[1], buf, sizeof(buf), 0);
    buf[n1] = '\0';
    std::cout << "第一次recv: \"" << buf << "\" (" << n1 << " bytes)" << std::endl;

    ssize_t n2 = recv(sv[1], buf, sizeof(buf), 0);
    buf[n2] = '\0';
    std::cout << "第二次recv: \"" << buf << "\" (" << n2 << " bytes)" << std::endl;

    close(sv[0]);
    close(sv[1]);
}

// 输出：
// 第一次recv: "Hello" (5 bytes)
// 第二次recv: "World" (5 bytes)
// 注意：每次recv恰好收到一个完整的数据报

/*
自测题：

Q1: UDP recvfrom的buffer太小会怎样？
A1: 如果buffer比数据报小，超出部分会被丢弃（不像TCP那样留在缓冲区等下次读）。
    例如发送100字节，recv只给50字节buffer，只收到前50字节，后50字节丢失。
    这种情况下recv返回-1，errno=EMSGSIZE（某些系统）或返回50截断数据。

Q2: UDP server如何区分不同客户端？
A2: 通过recvfrom返回的客户端地址（sockaddr_in）区分。
    服务器通常维护一个 <地址, 状态> 的映射表来跟踪不同客户端。

Q3: 为什么DNS查询用UDP而不是TCP？
A3: DNS查询通常很小（<512字节），用UDP一个往返就能完成。
    TCP需要三次握手+四次挥手，延迟更高。
    如果UDP响应被截断（TC标志），客户端才会用TCP重试。
*/
```

### Day 17-18：广播与组播

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | UDP广播通信 | 3h |
| 下午 | UDP组播通信 | 3h |
| 晚上 | TCP vs UDP性能对比 | 2h |

#### 1. UDP广播

```cpp
// ============================================================
// UDP广播通信
// ============================================================

/*
┌─────────────────────────────────────────────────────────────────────┐
│                    UDP 广播原理                                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  广播地址类型：                                                      │
│  1. 受限广播: 255.255.255.255                                       │
│     - 不会被路由器转发                                               │
│     - 只在本地网络有效                                               │
│                                                                      │
│  2. 定向广播: 网络地址 + 全1主机部分                                │
│     - 例如 192.168.1.255 (对于 192.168.1.0/24 网络)                 │
│     - 可以被路由器转发（通常禁用）                                   │
│                                                                      │
│                   发送者                                             │
│                     │                                                │
│                     │ 广播消息                                       │
│                     ▼                                                │
│  ┌─────────────────────────────────────────────────┐                │
│  │                  交换机/路由器                    │                │
│  └─────────────────────────────────────────────────┘                │
│     │           │           │           │                           │
│     ▼           ▼           ▼           ▼                           │
│  ┌─────┐    ┌─────┐    ┌─────┐    ┌─────┐                          │
│  │接收1│    │接收2│    │接收3│    │发送者│                          │
│  └─────┘    └─────┘    └─────┘    └─────┘                          │
│                                                                      │
│  用途：                                                              │
│  - 服务发现（"谁是DHCP服务器？"）                                   │
│  - 局域网游戏大厅                                                   │
│  - 网络唤醒（Wake-on-LAN）                                          │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
*/

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <cerrno>
#include <cstring>
#include <iostream>
#include <thread>
#include <chrono>

// ---- 广播发送者 ----
void broadcast_sender(int port, const char* message) {
    int sock_fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock_fd < 0) {
        std::cerr << "socket()失败" << std::endl;
        return;
    }

    // 必须设置 SO_BROADCAST 选项
    int broadcast = 1;
    if (setsockopt(sock_fd, SOL_SOCKET, SO_BROADCAST,
                   &broadcast, sizeof(broadcast)) < 0) {
        std::cerr << "setsockopt(SO_BROADCAST)失败" << std::endl;
        close(sock_fd);
        return;
    }

    // 广播地址
    sockaddr_in broadcast_addr{};
    broadcast_addr.sin_family = AF_INET;
    broadcast_addr.sin_port = htons(port);
    broadcast_addr.sin_addr.s_addr = inet_addr("255.255.255.255");

    // 发送广播
    ssize_t sent = sendto(sock_fd, message, strlen(message), 0,
                          reinterpret_cast<sockaddr*>(&broadcast_addr),
                          sizeof(broadcast_addr));
    if (sent < 0) {
        std::cerr << "sendto()失败: " << strerror(errno) << std::endl;
    } else {
        std::cout << "[广播发送] " << sent << " bytes: " << message << std::endl;
    }

    close(sock_fd);
}

// ---- 广播接收者 ----
void broadcast_receiver(int port) {
    int sock_fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock_fd < 0) {
        std::cerr << "socket()失败" << std::endl;
        return;
    }

    // 允许多个进程绑定同一端口（用于测试多个接收者）
    int reuse = 1;
    setsockopt(sock_fd, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));
    setsockopt(sock_fd, SOL_SOCKET, SO_REUSEPORT, &reuse, sizeof(reuse));

    // 绑定到所有接口
    sockaddr_in local_addr{};
    local_addr.sin_family = AF_INET;
    local_addr.sin_port = htons(port);
    local_addr.sin_addr.s_addr = htonl(INADDR_ANY);

    if (bind(sock_fd, reinterpret_cast<sockaddr*>(&local_addr),
             sizeof(local_addr)) < 0) {
        std::cerr << "bind()失败: " << strerror(errno) << std::endl;
        close(sock_fd);
        return;
    }

    std::cout << "[广播接收] 监听端口 " << port << std::endl;

    // 设置超时
    struct timeval tv;
    tv.tv_sec = 10;
    tv.tv_usec = 0;
    setsockopt(sock_fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));

    char buffer[1024];
    sockaddr_in sender_addr{};
    socklen_t sender_len = sizeof(sender_addr);

    ssize_t n = recvfrom(sock_fd, buffer, sizeof(buffer) - 1, 0,
                         reinterpret_cast<sockaddr*>(&sender_addr),
                         &sender_len);
    if (n > 0) {
        buffer[n] = '\0';
        char sender_ip[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &sender_addr.sin_addr, sender_ip, sizeof(sender_ip));
        std::cout << "[广播收到] 来自 " << sender_ip << ": " << buffer << std::endl;
    } else if (errno == EAGAIN) {
        std::cout << "[广播接收] 超时" << std::endl;
    }

    close(sock_fd);
}

/*
使用示例：
// 终端1（接收者）
broadcast_receiver(9999);

// 终端2（发送者）
broadcast_sender(9999, "Hello, everyone!");
*/
```

#### 2. UDP组播

```cpp
// ============================================================
// UDP组播（Multicast）通信
// ============================================================

/*
┌─────────────────────────────────────────────────────────────────────┐
│                    UDP 组播原理                                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  组播地址范围：224.0.0.0 - 239.255.255.255                          │
│    224.0.0.0 - 224.0.0.255    : 本地链路（不被路由器转发）          │
│    224.0.1.0 - 238.255.255.255: 全球范围（可被路由）                │
│    239.0.0.0 - 239.255.255.255: 管理范围（组织内部）                │
│                                                                      │
│  常用组播地址：                                                      │
│    224.0.0.1 : 所有主机                                             │
│    224.0.0.2 : 所有路由器                                           │
│    224.0.0.251: mDNS                                                │
│                                                                      │
│                    发送者                                            │
│                      │                                               │
│                      │ 发送到组播地址 224.1.1.1                      │
│                      ▼                                               │
│  ┌──────────────────────────────────────────────────┐               │
│  │                    路由器                          │               │
│  │          (只转发给加入组的网络)                    │               │
│  └──────────────────────────────────────────────────┘               │
│      │                              │                                │
│      ▼                              ▼                                │
│  ┌─────┐                        ┌─────┐                             │
│  │子网A│                        │子网B│                             │
│  │有成员│                       │无成员│                             │
│  └─────┘                        └─────┘                             │
│   │   │                           ✗ 不转发                          │
│   ▼   ▼                                                              │
│ 成员1 成员2                                                          │
│                                                                      │
│  组播 vs 广播：                                                      │
│  - 广播：网络中所有主机都收到（浪费带宽）                            │
│  - 组播：只有加入组的主机收到（按需分发）                            │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
*/

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <cerrno>
#include <cstring>
#include <iostream>

// 组播地址（使用管理范围内的地址用于测试）
constexpr const char* MULTICAST_GROUP = "239.255.1.1";
constexpr int MULTICAST_PORT = 9999;

// ---- 组播发送者 ----
void multicast_sender(const char* message, int ttl = 1) {
    int sock_fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock_fd < 0) {
        std::cerr << "socket()失败" << std::endl;
        return;
    }

    // 设置TTL（Time To Live）- 控制组播报文能跨越的路由器数量
    // TTL=1: 只在本地网络
    // TTL>1: 可以跨越路由器
    if (setsockopt(sock_fd, IPPROTO_IP, IP_MULTICAST_TTL,
                   &ttl, sizeof(ttl)) < 0) {
        std::cerr << "设置TTL失败" << std::endl;
    }

    // 可选：禁用组播回环（发送者不收到自己发的消息）
    int loop = 0;
    setsockopt(sock_fd, IPPROTO_IP, IP_MULTICAST_LOOP, &loop, sizeof(loop));

    // 组播地址
    sockaddr_in mcast_addr{};
    mcast_addr.sin_family = AF_INET;
    mcast_addr.sin_port = htons(MULTICAST_PORT);
    inet_pton(AF_INET, MULTICAST_GROUP, &mcast_addr.sin_addr);

    // 发送
    ssize_t sent = sendto(sock_fd, message, strlen(message), 0,
                          reinterpret_cast<sockaddr*>(&mcast_addr),
                          sizeof(mcast_addr));
    if (sent < 0) {
        std::cerr << "sendto()失败: " << strerror(errno) << std::endl;
    } else {
        std::cout << "[组播发送] 到 " << MULTICAST_GROUP << ":" << MULTICAST_PORT
                  << " - " << message << std::endl;
    }

    close(sock_fd);
}

// ---- 组播接收者 ----
void multicast_receiver() {
    int sock_fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock_fd < 0) {
        std::cerr << "socket()失败" << std::endl;
        return;
    }

    // 允许多个进程加入同一组
    int reuse = 1;
    setsockopt(sock_fd, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));
    setsockopt(sock_fd, SOL_SOCKET, SO_REUSEPORT, &reuse, sizeof(reuse));

    // 绑定到组播端口
    sockaddr_in local_addr{};
    local_addr.sin_family = AF_INET;
    local_addr.sin_port = htons(MULTICAST_PORT);
    local_addr.sin_addr.s_addr = htonl(INADDR_ANY);

    if (bind(sock_fd, reinterpret_cast<sockaddr*>(&local_addr),
             sizeof(local_addr)) < 0) {
        std::cerr << "bind()失败: " << strerror(errno) << std::endl;
        close(sock_fd);
        return;
    }

    // 加入组播组
    struct ip_mreq mreq{};
    inet_pton(AF_INET, MULTICAST_GROUP, &mreq.imr_multiaddr);
    mreq.imr_interface.s_addr = htonl(INADDR_ANY);  // 使用默认网络接口

    if (setsockopt(sock_fd, IPPROTO_IP, IP_ADD_MEMBERSHIP,
                   &mreq, sizeof(mreq)) < 0) {
        std::cerr << "加入组播组失败: " << strerror(errno) << std::endl;
        close(sock_fd);
        return;
    }

    std::cout << "[组播接收] 已加入组 " << MULTICAST_GROUP << std::endl;

    // 设置超时
    struct timeval tv;
    tv.tv_sec = 30;
    tv.tv_usec = 0;
    setsockopt(sock_fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));

    // 接收消息
    char buffer[1024];
    sockaddr_in sender_addr{};
    socklen_t sender_len;

    while (true) {
        sender_len = sizeof(sender_addr);
        ssize_t n = recvfrom(sock_fd, buffer, sizeof(buffer) - 1, 0,
                             reinterpret_cast<sockaddr*>(&sender_addr),
                             &sender_len);
        if (n > 0) {
            buffer[n] = '\0';
            char sender_ip[INET_ADDRSTRLEN];
            inet_ntop(AF_INET, &sender_addr.sin_addr, sender_ip, sizeof(sender_ip));
            std::cout << "[组播收到] 来自 " << sender_ip << ": " << buffer << std::endl;
        } else if (errno == EAGAIN) {
            std::cout << "[组播接收] 超时，退出" << std::endl;
            break;
        } else {
            break;
        }
    }

    // 离开组播组（可选，close时会自动离开）
    setsockopt(sock_fd, IPPROTO_IP, IP_DROP_MEMBERSHIP, &mreq, sizeof(mreq));

    close(sock_fd);
}

/*
组播相关socket选项总结：

发送端：
  IP_MULTICAST_TTL     - 设置TTL，控制报文能传多远
  IP_MULTICAST_LOOP    - 是否收到自己发送的组播（默认1）
  IP_MULTICAST_IF      - 指定发送组播的网络接口

接收端：
  IP_ADD_MEMBERSHIP    - 加入组播组（struct ip_mreq）
  IP_DROP_MEMBERSHIP   - 离开组播组
  IP_ADD_SOURCE_MEMBERSHIP - SSM：只接收特定源的组播

自测题：

Q1: 广播和组播的主要区别？
A1: 广播发送给网络中所有主机，组播只发送给加入特定组的主机。
    广播局限于本地网络，组播可以跨路由器。
    组播更节省带宽，因为不关心的主机不会收到。

Q2: 为什么组播发送者不需要加入组？
A2: 组播发送类似于向邮件列表发信，不需要自己订阅。
    但如果发送者也想收到消息，需要加入组。
*/
```

#### 3. TCP vs UDP性能对比

```cpp
// ============================================================
// TCP vs UDP 简单性能对比
// ============================================================

/*
┌────────────────────────────────────────────────────────────────────┐
│                 TCP vs UDP 性能特征对比                             │
├────────────────┬───────────────────┬───────────────────────────────┤
│     指标       │       TCP         │          UDP                  │
├────────────────┼───────────────────┼───────────────────────────────┤
│ 连接建立延迟   │ 1.5 RTT (3次握手) │ 0 (无连接)                   │
│ 连接关闭延迟   │ 2 RTT (4次挥手)   │ 0                            │
│ 首字节延迟     │ 2 RTT             │ 0.5 RTT                      │
│ 头部开销       │ 20-60 bytes       │ 8 bytes                      │
│ 可靠性开销     │ ACK, 重传, 排序   │ 无                           │
│ 吞吐量         │ 受拥塞控制影响    │ 只受带宽限制                  │
│ 延迟抖动       │ 较大（重传导致）  │ 较小                          │
├────────────────┴───────────────────┴───────────────────────────────┤
│                                                                     │
│  适用场景建议：                                                     │
│                                                                     │
│  选择TCP：                                                          │
│  - 数据完整性最重要（文件传输、数据库）                             │
│  - 长连接（Web、数据库连接池）                                     │
│  - 需要流量控制（避免压垮接收方）                                  │
│                                                                     │
│  选择UDP：                                                          │
│  - 低延迟最重要（游戏、实时通信）                                  │
│  - 允许丢失（视频流、音频流）                                     │
│  - 广播/组播需求                                                   │
│  - 简单请求-响应（DNS、NTP）                                       │
│                                                                     │
│  混合方案：                                                         │
│  - QUIC: UDP上实现可靠传输（HTTP/3）                               │
│  - WebRTC: UDP用于媒体，可选TCP用于信令                            │
│  - 游戏: TCP用于登录/状态同步，UDP用于位置更新                    │
│                                                                     │
└────────────────────────────────────────────────────────────────────┘
*/
```

### Day 19-20：DNS解析与地址工具

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | getaddrinfo深入使用 | 2h |
| 下午 | getnameinfo与反向解析 | 2h |
| 晚上 | 地址工具函数集实现 | 3h |

#### 1. getaddrinfo深入使用

```cpp
// ============================================================
// DNS解析: getaddrinfo 深入使用
// ============================================================

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <unistd.h>
#include <cstring>
#include <iostream>
#include <string>
#include <vector>

/*
getaddrinfo() 是现代网络编程中推荐的地址解析函数。

int getaddrinfo(const char *node,       // 主机名或IP字符串
                const char *service,    // 服务名或端口字符串
                const struct addrinfo *hints,  // 过滤条件
                struct addrinfo **res);  // 结果链表

hints 结构体的关键字段：
  ai_family:   AF_INET / AF_INET6 / AF_UNSPEC（都可以）
  ai_socktype: SOCK_STREAM / SOCK_DGRAM / 0（都可以）
  ai_protocol: IPPROTO_TCP / IPPROTO_UDP / 0（自动选择）
  ai_flags:    AI_PASSIVE / AI_CANONNAME / AI_NUMERICHOST / ...
*/

// 完整的DNS解析工具
class DnsResolver {
public:
    struct ResolveResult {
        int family;             // AF_INET or AF_INET6
        int socktype;           // SOCK_STREAM or SOCK_DGRAM
        std::string ip;         // IP地址字符串
        int port;               // 端口号
        std::string canonical;  // 规范主机名
    };

    // 解析主机名+服务名
    static std::vector<ResolveResult> resolve(const std::string& host,
                                               const std::string& service,
                                               int family = AF_UNSPEC,
                                               int socktype = 0) {
        std::vector<ResolveResult> results;

        struct addrinfo hints{};
        hints.ai_family = family;
        hints.ai_socktype = socktype;
        hints.ai_flags = AI_CANONNAME;  // 请求规范名称

        struct addrinfo* res = nullptr;
        int err = getaddrinfo(host.c_str(),
                              service.empty() ? nullptr : service.c_str(),
                              &hints, &res);
        if (err != 0) {
            std::cerr << "解析失败: " << gai_strerror(err) << std::endl;
            return results;
        }

        for (struct addrinfo* p = res; p != nullptr; p = p->ai_next) {
            ResolveResult r;
            r.family = p->ai_family;
            r.socktype = p->ai_socktype;
            r.canonical = p->ai_canonname ? p->ai_canonname : "";

            char ip_str[INET6_ADDRSTRLEN];
            if (p->ai_family == AF_INET) {
                auto* addr4 = reinterpret_cast<sockaddr_in*>(p->ai_addr);
                inet_ntop(AF_INET, &addr4->sin_addr, ip_str, sizeof(ip_str));
                r.port = ntohs(addr4->sin_port);
            } else if (p->ai_family == AF_INET6) {
                auto* addr6 = reinterpret_cast<sockaddr_in6*>(p->ai_addr);
                inet_ntop(AF_INET6, &addr6->sin6_addr, ip_str, sizeof(ip_str));
                r.port = ntohs(addr6->sin6_port);
            }
            r.ip = ip_str;

            results.push_back(r);
        }

        freeaddrinfo(res);
        return results;
    }

    // 打印解析结果
    static void print_results(const std::vector<ResolveResult>& results) {
        std::cout << "解析结果 (" << results.size() << " 条):" << std::endl;
        for (size_t i = 0; i < results.size(); i++) {
            const auto& r = results[i];
            std::cout << "  [" << i + 1 << "] "
                      << (r.family == AF_INET ? "IPv4" : "IPv6") << " "
                      << (r.socktype == SOCK_STREAM ? "TCP" : "UDP") << " "
                      << r.ip;
            if (r.port > 0) std::cout << ":" << r.port;
            if (!r.canonical.empty()) std::cout << " (" << r.canonical << ")";
            std::cout << std::endl;
        }
    }
};

// DNS解析工具程序示例
void dns_tool_demo() {
    // 解析域名
    std::cout << "=== 解析 www.google.com ===" << std::endl;
    auto results = DnsResolver::resolve("www.google.com", "https");
    DnsResolver::print_results(results);

    std::cout << "\n=== 解析 localhost (仅IPv4 TCP) ===" << std::endl;
    results = DnsResolver::resolve("localhost", "http", AF_INET, SOCK_STREAM);
    DnsResolver::print_results(results);

    std::cout << "\n=== 服务名解析 ===" << std::endl;
    results = DnsResolver::resolve("", "ssh");  // 只解析服务名→端口
    DnsResolver::print_results(results);
}
```

#### 2. getnameinfo与反向解析

```cpp
// ============================================================
// getnameinfo: 反向DNS解析与地址格式化
// ============================================================

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <cstring>
#include <iostream>

/*
getnameinfo() - getaddrinfo()的逆操作

int getnameinfo(const struct sockaddr *sa, socklen_t salen,
                char *host, socklen_t hostlen,
                char *serv, socklen_t servlen,
                int flags);

flags常用值：
  NI_NUMERICHOST - 不进行DNS反向查询，直接返回数字IP
  NI_NUMERICSERV - 不查询服务名，直接返回数字端口
  NI_NAMEREQD    - 如果无法解析主机名则返回错误
  NI_DGRAM       - 服务是UDP（影响服务名查询）
*/

// sockaddr转字符串（支持IPv4和IPv6）
std::string sockaddr_to_string(const sockaddr* addr, socklen_t len,
                                bool resolve_hostname = false) {
    char host[NI_MAXHOST];
    char serv[NI_MAXSERV];

    int flags = NI_NUMERICSERV;  // 端口总是数字
    if (!resolve_hostname) {
        flags |= NI_NUMERICHOST;  // 不解析主机名
    }

    int err = getnameinfo(addr, len, host, sizeof(host),
                          serv, sizeof(serv), flags);
    if (err != 0) {
        return "getnameinfo failed: " + std::string(gai_strerror(err));
    }

    return std::string(host) + ":" + serv;
}

// 反向DNS查询（IP → 主机名）
std::string reverse_dns(const char* ip_str) {
    sockaddr_storage addr{};
    socklen_t addr_len;

    // 尝试解析为IPv4
    auto* addr4 = reinterpret_cast<sockaddr_in*>(&addr);
    if (inet_pton(AF_INET, ip_str, &addr4->sin_addr) == 1) {
        addr4->sin_family = AF_INET;
        addr_len = sizeof(sockaddr_in);
    } else {
        // 尝试IPv6
        auto* addr6 = reinterpret_cast<sockaddr_in6*>(&addr);
        if (inet_pton(AF_INET6, ip_str, &addr6->sin6_addr) == 1) {
            addr6->sin6_family = AF_INET6;
            addr_len = sizeof(sockaddr_in6);
        } else {
            return "Invalid IP address";
        }
    }

    char hostname[NI_MAXHOST];
    int err = getnameinfo(reinterpret_cast<sockaddr*>(&addr), addr_len,
                          hostname, sizeof(hostname),
                          nullptr, 0,  // 不需要服务名
                          0);          // 尝试解析主机名

    if (err != 0) {
        return "Reverse DNS failed: " + std::string(gai_strerror(err));
    }

    return hostname;
}

void reverse_dns_demo() {
    std::cout << "=== 反向DNS查询 ===" << std::endl;

    // 本地回环
    std::cout << "127.0.0.1 → " << reverse_dns("127.0.0.1") << std::endl;

    // Google DNS
    std::cout << "8.8.8.8 → " << reverse_dns("8.8.8.8") << std::endl;

    // IPv6回环
    std::cout << "::1 → " << reverse_dns("::1") << std::endl;
}
```

#### 3. 地址工具函数集

```cpp
// ============================================================
// 网络地址工具函数集
// ============================================================

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <cstring>
#include <iostream>
#include <vector>
#include <string>

namespace net_utils {

// 判断是否为私有地址
bool is_private_address(const char* ip_str) {
    in_addr addr;
    if (inet_pton(AF_INET, ip_str, &addr) != 1) {
        return false;
    }

    uint32_t ip = ntohl(addr.s_addr);

    // 10.0.0.0/8
    if ((ip & 0xFF000000) == 0x0A000000) return true;

    // 172.16.0.0/12
    if ((ip & 0xFFF00000) == 0xAC100000) return true;

    // 192.168.0.0/16
    if ((ip & 0xFFFF0000) == 0xC0A80000) return true;

    return false;
}

// 判断是否为回环地址
bool is_loopback_address(const char* ip_str) {
    in_addr addr;
    if (inet_pton(AF_INET, ip_str, &addr) != 1) {
        // 尝试IPv6
        in6_addr addr6;
        if (inet_pton(AF_INET6, ip_str, &addr6) == 1) {
            return IN6_IS_ADDR_LOOPBACK(&addr6);
        }
        return false;
    }

    uint32_t ip = ntohl(addr.s_addr);
    // 127.0.0.0/8
    return (ip & 0xFF000000) == 0x7F000000;
}

// 获取本机所有网络接口地址
struct InterfaceInfo {
    std::string name;       // 接口名 (eth0, en0, ...)
    std::string ip;         // IP地址
    int family;             // AF_INET or AF_INET6
    bool is_up;             // 接口是否启用
    bool is_loopback;       // 是否回环接口
};

std::vector<InterfaceInfo> get_local_addresses() {
    std::vector<InterfaceInfo> result;

    struct ifaddrs* ifaddr = nullptr;
    if (getifaddrs(&ifaddr) < 0) {
        return result;
    }

    for (struct ifaddrs* ifa = ifaddr; ifa != nullptr; ifa = ifa->ifa_next) {
        if (ifa->ifa_addr == nullptr) continue;

        int family = ifa->ifa_addr->sa_family;
        if (family != AF_INET && family != AF_INET6) continue;

        InterfaceInfo info;
        info.name = ifa->ifa_name;
        info.family = family;
        info.is_up = (ifa->ifa_flags & IFF_UP) != 0;
        info.is_loopback = (ifa->ifa_flags & IFF_LOOPBACK) != 0;

        char ip_str[INET6_ADDRSTRLEN];
        if (family == AF_INET) {
            auto* addr = reinterpret_cast<sockaddr_in*>(ifa->ifa_addr);
            inet_ntop(AF_INET, &addr->sin_addr, ip_str, sizeof(ip_str));
        } else {
            auto* addr = reinterpret_cast<sockaddr_in6*>(ifa->ifa_addr);
            inet_ntop(AF_INET6, &addr->sin6_addr, ip_str, sizeof(ip_str));
        }
        info.ip = ip_str;

        result.push_back(info);
    }

    freeifaddrs(ifaddr);
    return result;
}

// 打印本机网络接口
void print_local_interfaces() {
    auto interfaces = get_local_addresses();

    std::cout << "=== 本机网络接口 ===" << std::endl;
    for (const auto& iface : interfaces) {
        std::cout << iface.name << ": "
                  << (iface.family == AF_INET ? "IPv4" : "IPv6") << " "
                  << iface.ip;
        if (iface.is_loopback) std::cout << " [loopback]";
        if (!iface.is_up) std::cout << " [down]";
        std::cout << std::endl;
    }
}

// 获取默认出口IP（连接外网时使用的IP）
std::string get_default_ip() {
    int sock = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock < 0) return "";

    // 连接到外部地址（不会真正发包，只是让内核选择出口）
    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(80);
    inet_pton(AF_INET, "8.8.8.8", &addr.sin_addr);

    if (connect(sock, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) < 0) {
        close(sock);
        return "";
    }

    sockaddr_in local_addr{};
    socklen_t local_len = sizeof(local_addr);
    getsockname(sock, reinterpret_cast<sockaddr*>(&local_addr), &local_len);

    char ip_str[INET_ADDRSTRLEN];
    inet_ntop(AF_INET, &local_addr.sin_addr, ip_str, sizeof(ip_str));

    close(sock);
    return ip_str;
}

} // namespace net_utils

void net_utils_demo() {
    using namespace net_utils;

    std::cout << "=== 地址类型判断 ===" << std::endl;
    std::cout << "192.168.1.1 is private: " << is_private_address("192.168.1.1") << std::endl;
    std::cout << "8.8.8.8 is private: " << is_private_address("8.8.8.8") << std::endl;
    std::cout << "127.0.0.1 is loopback: " << is_loopback_address("127.0.0.1") << std::endl;

    std::cout << std::endl;
    print_local_interfaces();

    std::cout << "\n=== 默认出口IP ===" << std::endl;
    std::cout << "Default IP: " << get_default_ip() << std::endl;
}

/*
自测题：

Q1: getaddrinfo返回多个结果时，应该如何选择？
A1: 推荐的做法是按顺序尝试连接，第一个成功的就用（Happy Eyeballs算法）。
    如果需要特定协议，可以通过hints过滤。一般优先尝试IPv6。

Q2: 什么情况下反向DNS查询会失败？
A2: 1. IP地址没有配置PTR记录
    2. DNS服务器不可达
    3. 查询超时
    反向DNS在Internet上并不总是可用，不应依赖它做安全验证。

Q3: 获取本机IP为什么要用connect UDP socket的方法？
A3: 这个方法让内核根据路由表选择出口接口，返回该接口的IP。
    直接枚举接口可能返回多个IP，不知道哪个是对外的。
    connect UDP不会发包，只是触发内核路由选择。
*/
```

### Day 21：第三周总结与检验

#### UDP与高级主题总结

```cpp
// ============================================================
// 第三周：UDP与高级主题总结
// ============================================================

/*
┌────────────────────────────────────────────────────────────────────┐
│               UDP / 广播 / 组播 特性对比                            │
├────────────┬──────────────┬──────────────┬────────────────────────┤
│   特性     │    UDP单播   │    广播       │       组播             │
├────────────┼──────────────┼──────────────┼────────────────────────┤
│ 目标地址   │ 单一主机     │ 255.255.255.255│ 224.x.x.x-239.x.x.x  │
│ 接收者     │ 1个          │ 网络中所有主机│ 只有组成员             │
│ 路由       │ 可跨网络     │ 不可跨网络    │ 可跨网络（需支持）    │
│ 效率       │ 高           │ 浪费带宽      │ 按需分发               │
│ 使用场景   │ 点对点通信   │ 局域网发现    │ 视频直播、股票行情    │
│ socket选项 │ 无           │ SO_BROADCAST  │ IP_ADD_MEMBERSHIP     │
└────────────┴──────────────┴──────────────┴────────────────────────┘

UDP编程关键API总结：

基础API：
  socket(AF_INET, SOCK_DGRAM, 0)  - 创建UDP socket
  bind()                          - 绑定本地地址（服务器必须）
  sendto()                        - 发送数据报到指定地址
  recvfrom()                      - 接收数据报，获取发送者地址
  close()                         - 关闭socket

可选API：
  connect()                       - 记录对端地址，之后可用send/recv
  send() / recv()                 - 用于connected UDP socket

广播相关：
  setsockopt(SO_BROADCAST)        - 允许发送广播

组播相关：
  setsockopt(IP_ADD_MEMBERSHIP)   - 加入组播组
  setsockopt(IP_DROP_MEMBERSHIP)  - 离开组播组
  setsockopt(IP_MULTICAST_TTL)    - 设置组播TTL
  setsockopt(IP_MULTICAST_LOOP)   - 是否收到自己发送的组播

DNS解析：
  getaddrinfo()                   - 主机名/服务名 → 地址
  getnameinfo()                   - 地址 → 主机名/服务名
  freeaddrinfo()                  - 释放getaddrinfo结果
*/
```

#### 第三周检验标准

- [ ] 理解UDP与TCP的核心区别（无连接、消息边界、不可靠）
- [ ] 实现完整的UDP Echo Server/Client
- [ ] 理解UDP数据报大小限制和分片问题
- [ ] 实现UDP广播发送和接收
- [ ] 实现UDP组播发送和接收，理解组播地址范围
- [ ] 熟练使用getaddrinfo进行DNS解析和地址转换
- [ ] 能使用getnameinfo进行反向DNS查询
- [ ] 实现地址工具函数（私有地址判断、本机接口枚举）
- [ ] 理解TCP vs UDP的性能特点和适用场景
- [ ] 能根据需求选择合适的传输协议

---

## 第四周：Socket选项、错误处理与跨平台封装（Day 22-28）

> **本周目标**：掌握常用Socket选项的配置，实现健壮的错误处理机制，
> 完成跨平台Socket封装库的完整实现

### Day 22-23：Socket选项大全

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | SOL_SOCKET级别选项 | 3h |
| 下午 | IPPROTO_TCP级别选项 | 2h |
| 晚上 | 通用Socket信息获取 | 2h |

#### 1. SOL_SOCKET级别选项

```cpp
// ============================================================
// Socket选项大全：SOL_SOCKET级别
// ============================================================

#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <cerrno>
#include <cstring>
#include <iostream>

/*
┌────────────────────────────────────────────────────────────────────┐
│                  SOL_SOCKET 级别选项详解                            │
├────────────────┬───────────────────────────────────────────────────┤
│ 选项名         │ 说明                                              │
├────────────────┼───────────────────────────────────────────────────┤
│ SO_REUSEADDR   │ 允许重用处于TIME_WAIT状态的地址                   │
│ SO_REUSEPORT   │ 允许多个socket绑定同一端口（Linux 3.9+）          │
│ SO_RCVBUF      │ 设置接收缓冲区大小                                │
│ SO_SNDBUF      │ 设置发送缓冲区大小                                │
│ SO_RCVTIMEO    │ 设置接收超时                                      │
│ SO_SNDTIMEO    │ 设置发送超时                                      │
│ SO_KEEPALIVE   │ 启用TCP保活探测                                   │
│ SO_LINGER      │ 控制close()的行为                                 │
│ SO_ERROR       │ 获取并清除socket错误                              │
│ SO_BROADCAST   │ 允许发送广播（UDP）                               │
│ SO_OOBINLINE   │ 将带外数据放入普通数据流                          │
│ SO_RCVLOWAT    │ 接收低水位标记                                    │
│ SO_SNDLOWAT    │ 发送低水位标记                                    │
└────────────────┴───────────────────────────────────────────────────┘
*/

// ---- SO_REUSEADDR: 服务器必备 ----
void demo_reuseaddr(int fd) {
    int opt = 1;
    if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) < 0) {
        std::cerr << "SO_REUSEADDR失败" << std::endl;
    }
    /*
    作用：
    1. 允许绑定处于TIME_WAIT状态的地址
    2. 允许同一端口被多个socket绑定（需要不同的本地IP）

    典型场景：
    服务器重启时，旧连接可能还在TIME_WAIT状态，没有这个选项会bind失败。
    */
}

// ---- SO_REUSEPORT: 负载均衡 ----
void demo_reuseport(int fd) {
    int opt = 1;
    if (setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &opt, sizeof(opt)) < 0) {
        std::cerr << "SO_REUSEPORT失败: " << strerror(errno) << std::endl;
    }
    /*
    作用：
    允许多个socket绑定完全相同的地址和端口。
    内核会将incoming连接/数据报均匀分配给这些socket。

    典型场景：
    多进程/多线程服务器，每个worker绑定同一端口，避免惊群问题。
    */
}

// ---- SO_RCVBUF / SO_SNDBUF: 缓冲区调优 ----
void demo_buffer_size(int fd) {
    // 读取当前值
    int recv_buf = 0, send_buf = 0;
    socklen_t len = sizeof(int);
    getsockopt(fd, SOL_SOCKET, SO_RCVBUF, &recv_buf, &len);
    getsockopt(fd, SOL_SOCKET, SO_SNDBUF, &send_buf, &len);
    std::cout << "默认缓冲区: recv=" << recv_buf << ", send=" << send_buf << std::endl;

    // 设置新值（注意：Linux会将设置值翻倍）
    int new_size = 256 * 1024;  // 256KB
    setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &new_size, sizeof(new_size));
    setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &new_size, sizeof(new_size));

    // 验证实际值
    getsockopt(fd, SOL_SOCKET, SO_RCVBUF, &recv_buf, &len);
    getsockopt(fd, SOL_SOCKET, SO_SNDBUF, &send_buf, &len);
    std::cout << "设置后缓冲区: recv=" << recv_buf << ", send=" << send_buf << std::endl;

    /*
    注意：
    1. Linux会将设置值翻倍（为了容纳控制信息）
    2. 有系统上限：/proc/sys/net/core/rmem_max 和 wmem_max
    3. 设置过大会浪费内存，过小可能影响吞吐量
    4. TCP会根据拥塞情况动态调整，UDP需要手动设置
    */
}

// ---- SO_RCVTIMEO / SO_SNDTIMEO: 超时设置 ----
void demo_timeout(int fd) {
    struct timeval tv;
    tv.tv_sec = 5;   // 5秒
    tv.tv_usec = 0;

    // 设置接收超时
    if (setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv)) < 0) {
        std::cerr << "SO_RCVTIMEO失败" << std::endl;
    }

    // 设置发送超时
    if (setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv)) < 0) {
        std::cerr << "SO_SNDTIMEO失败" << std::endl;
    }

    /*
    效果：
    - recv/read 超时返回 -1，errno = EAGAIN 或 EWOULDBLOCK
    - send/write 超时返回 -1，errno = EAGAIN 或 EWOULDBLOCK

    注意：
    - 超时不是精确的，可能有几十ms的误差
    - 对于connect()超时，这个选项不一定生效，需要用非阻塞+select
    */
}

// ---- SO_LINGER: 控制close行为 ----
void demo_linger(int fd, bool enable, int timeout_sec) {
    struct linger lg;
    lg.l_onoff = enable ? 1 : 0;
    lg.l_linger = timeout_sec;

    setsockopt(fd, SOL_SOCKET, SO_LINGER, &lg, sizeof(lg));

    /*
    三种行为：
    1. l_onoff=0（默认）: close()立即返回，内核继续发送缓冲区数据
    2. l_onoff=1, l_linger=0: close()立即返回，发送RST，不进入TIME_WAIT
    3. l_onoff=1, l_linger>0: close()阻塞最多l_linger秒等待数据发送完成

    使用场景：
    - 需要立即释放资源：l_linger=0（但会发RST，可能导致数据丢失）
    - 确保数据发送完成：l_linger>0
    */
}

// ---- SO_ERROR: 获取异步错误 ----
int get_socket_error(int fd) {
    int error = 0;
    socklen_t len = sizeof(error);
    getsockopt(fd, SOL_SOCKET, SO_ERROR, &error, &len);
    return error;

    /*
    用途：
    - 非阻塞connect完成后检查是否成功
    - 获取TCP连接的错误状态

    注意：
    getsockopt(SO_ERROR)会清除错误状态（读后清零）
    */
}
```

#### 2. IPPROTO_TCP级别选项

```cpp
// ============================================================
// Socket选项：IPPROTO_TCP级别（TCP专用）
// ============================================================

#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <iostream>

/*
┌────────────────────────────────────────────────────────────────────┐
│                  TCP 专用选项详解                                   │
├────────────────┬───────────────────────────────────────────────────┤
│ TCP_NODELAY    │ 禁用Nagle算法，减少小包延迟                       │
│ TCP_CORK       │ 阻塞发送直到缓冲区满或显式解除（Linux）           │
│ TCP_KEEPIDLE   │ 空闲多久后开始发送Keep-Alive探测                  │
│ TCP_KEEPINTVL  │ Keep-Alive探测包的发送间隔                        │
│ TCP_KEEPCNT    │ Keep-Alive探测失败多少次后断开                    │
│ TCP_MAXSEG     │ 设置MSS（最大段大小）                             │
│ TCP_QUICKACK   │ 禁用延迟ACK（Linux）                              │
└────────────────┴───────────────────────────────────────────────────┘
*/

// ---- TCP_NODELAY: 禁用Nagle算法 ----
void demo_nodelay(int fd) {
    int opt = 1;
    setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &opt, sizeof(opt));
}

/*
┌─────────────────────────────────────────────────────────────────────┐
│                    Nagle算法详解                                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Nagle算法的目的：减少网络中的小包数量                               │
│                                                                      │
│  规则：                                                              │
│  - 如果有未确认的数据在途中，则缓冲小数据包                         │
│  - 直到：之前的数据被确认，或者缓冲区积累到MSS大小                  │
│                                                                      │
│  示例（开启Nagle）：                                                 │
│    send("H") → 立即发送（无在途数据）                               │
│    send("e") → 缓冲（等待ACK或更多数据）                            │
│    send("l") → 继续缓冲                                             │
│    收到ACK  → 发送"el"                                              │
│    send("lo") → 缓冲                                                │
│    ...                                                               │
│                                                                      │
│  问题（延迟叠加）：                                                  │
│  - Nagle + 延迟ACK = 严重延迟                                       │
│  - 对交互式应用（ssh、游戏）影响大                                   │
│                                                                      │
│  何时禁用（TCP_NODELAY=1）：                                        │
│  - 实时性要求高的应用                                               │
│  - 发送完整消息后立即flush的应用                                    │
│  - 通常：游戏、SSH、数据库协议、HTTP/2                              │
│                                                                      │
│  何时保持（TCP_NODELAY=0，默认）：                                  │
│  - 大量小数据包的批量传输                                           │
│  - 带宽利用比延迟更重要                                             │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
*/

// ---- TCP_CORK: 聚合发送（Linux专用）----
void demo_cork(int fd, bool enable) {
#ifdef TCP_CORK
    int opt = enable ? 1 : 0;
    setsockopt(fd, IPPROTO_TCP, TCP_CORK, &opt, sizeof(opt));
#else
    (void)fd;
    (void)enable;
#endif

    /*
    TCP_CORK与TCP_NODELAY的区别：
    - TCP_NODELAY: 禁止缓冲，立即发送
    - TCP_CORK: 强制缓冲，直到解除或200ms超时

    使用模式：
    1. 设置TCP_CORK = 1
    2. 发送多个小数据（HTTP头、响应体）
    3. 设置TCP_CORK = 0 → 一次性发送所有数据

    效果：减少发送的包数量，提高效率
    */
}

// ---- TCP Keep-Alive 详细配置 ----
void configure_tcp_keepalive(int fd) {
    // 开启Keep-Alive
    int keepalive = 1;
    setsockopt(fd, SOL_SOCKET, SO_KEEPALIVE, &keepalive, sizeof(keepalive));

    // 空闲60秒后开始探测
    int idle = 60;
    setsockopt(fd, IPPROTO_TCP, TCP_KEEPIDLE, &idle, sizeof(idle));

    // 每10秒发送一次探测包
    int interval = 10;
    setsockopt(fd, IPPROTO_TCP, TCP_KEEPINTVL, &interval, sizeof(interval));

    // 探测5次失败后断开
    int count = 5;
    setsockopt(fd, IPPROTO_TCP, TCP_KEEPCNT, &count, sizeof(count));

    // 总超时时间: 60 + 10*5 = 110秒
}

/*
自测题：

Q1: TCP_NODELAY和TCP_CORK能同时设置吗？效果是什么？
A1: 可以同时设置，但行为取决于设置顺序和内核版本。
    一般来说TCP_NODELAY优先级更高，设置了NODELAY后CORK可能无效。
    实践中通常只用其中一个。

Q2: 为什么实时游戏通常禁用Nagle算法？
A2: 游戏需要低延迟传输位置更新等小数据包。Nagle算法会缓冲小包，
    导致几十到几百毫秒的额外延迟。对游戏体验影响很大。

Q3: TCP_QUICKACK有什么作用？
A3: 禁用延迟ACK，收到数据后立即发送ACK。
    默认情况下TCP会等待最多40ms希望能捎带ACK，这会增加延迟。
    与TCP_NODELAY配合使用可以最大程度减少延迟。
*/
```

#### 3. 通用Socket信息获取

```cpp
// ============================================================
// Socket信息获取函数
// ============================================================

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <iostream>
#include <string>

// 获取本地地址
std::string get_local_address(int fd) {
    sockaddr_storage addr{};
    socklen_t len = sizeof(addr);

    if (getsockname(fd, reinterpret_cast<sockaddr*>(&addr), &len) < 0) {
        return "getsockname failed";
    }

    char ip_str[INET6_ADDRSTRLEN];
    int port = 0;

    if (addr.ss_family == AF_INET) {
        auto* addr4 = reinterpret_cast<sockaddr_in*>(&addr);
        inet_ntop(AF_INET, &addr4->sin_addr, ip_str, sizeof(ip_str));
        port = ntohs(addr4->sin_port);
    } else if (addr.ss_family == AF_INET6) {
        auto* addr6 = reinterpret_cast<sockaddr_in6*>(&addr);
        inet_ntop(AF_INET6, &addr6->sin6_addr, ip_str, sizeof(ip_str));
        port = ntohs(addr6->sin6_port);
    }

    return std::string(ip_str) + ":" + std::to_string(port);
}

// 获取对端地址
std::string get_peer_address(int fd) {
    sockaddr_storage addr{};
    socklen_t len = sizeof(addr);

    if (getpeername(fd, reinterpret_cast<sockaddr*>(&addr), &len) < 0) {
        return "getpeername failed";
    }

    char ip_str[INET6_ADDRSTRLEN];
    int port = 0;

    if (addr.ss_family == AF_INET) {
        auto* addr4 = reinterpret_cast<sockaddr_in*>(&addr);
        inet_ntop(AF_INET, &addr4->sin_addr, ip_str, sizeof(ip_str));
        port = ntohs(addr4->sin_port);
    } else if (addr.ss_family == AF_INET6) {
        auto* addr6 = reinterpret_cast<sockaddr_in6*>(&addr);
        inet_ntop(AF_INET6, &addr6->sin6_addr, ip_str, sizeof(ip_str));
        port = ntohs(addr6->sin6_port);
    }

    return std::string(ip_str) + ":" + std::to_string(port);
}

// 设置/获取非阻塞模式
bool set_nonblocking(int fd, bool nonblock) {
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags < 0) return false;

    if (nonblock) {
        flags |= O_NONBLOCK;
    } else {
        flags &= ~O_NONBLOCK;
    }

    return fcntl(fd, F_SETFL, flags) >= 0;
}

bool is_nonblocking(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    return (flags >= 0) && (flags & O_NONBLOCK);
}

// 获取可读数据量
int get_readable_bytes(int fd) {
    int bytes = 0;
    if (ioctl(fd, FIONREAD, &bytes) < 0) {
        return -1;
    }
    return bytes;
}

// 打印Socket详细信息
void print_socket_info(int fd) {
    std::cout << "=== Socket 信息 ===" << std::endl;
    std::cout << "本地地址: " << get_local_address(fd) << std::endl;
    std::cout << "对端地址: " << get_peer_address(fd) << std::endl;
    std::cout << "非阻塞:   " << (is_nonblocking(fd) ? "是" : "否") << std::endl;

    int recv_buf = 0, send_buf = 0;
    socklen_t len = sizeof(int);
    getsockopt(fd, SOL_SOCKET, SO_RCVBUF, &recv_buf, &len);
    getsockopt(fd, SOL_SOCKET, SO_SNDBUF, &send_buf, &len);
    std::cout << "接收缓冲: " << recv_buf << " bytes" << std::endl;
    std::cout << "发送缓冲: " << send_buf << " bytes" << std::endl;

    int readable = get_readable_bytes(fd);
    if (readable >= 0) {
        std::cout << "待读数据: " << readable << " bytes" << std::endl;
    }
}
```

### Day 24-25：错误处理框架

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | Socket错误码分类 | 2h |
| 下午 | Stevens风格包装函数 | 3h |
| 晚上 | 跨平台错误处理 | 2h |

#### 1. Socket错误码分类

```cpp
// ============================================================
// Socket错误码分类与处理策略
// ============================================================

#include <cerrno>
#include <cstring>
#include <iostream>

/*
┌──────────────────────────────────────────────────────────────────────┐
│                    Socket 错误码分类                                  │
├──────────────┬───────────────────────────────────────────────────────┤
│   分类       │ 错误码及说明                                          │
├──────────────┼───────────────────────────────────────────────────────┤
│ 可重试错误   │ EINTR       - 被信号中断，应重试                      │
│              │ EAGAIN      - 资源暂时不可用（非阻塞）                │
│              │ EWOULDBLOCK - 同EAGAIN（大多数系统相同值）            │
│              │ EINPROGRESS - 非阻塞connect进行中                     │
├──────────────┼───────────────────────────────────────────────────────┤
│ 连接错误     │ ECONNREFUSED - 连接被拒绝（端口未监听）              │
│              │ ECONNRESET   - 连接被对端重置（收到RST）             │
│              │ ECONNABORTED - 连接被中止                             │
│              │ ENOTCONN     - 未连接（TCP）                          │
│              │ EISCONN      - 已连接（重复connect）                  │
├──────────────┼───────────────────────────────────────────────────────┤
│ 网络错误     │ ENETUNREACH  - 网络不可达                             │
│              │ EHOSTUNREACH - 主机不可达                             │
│              │ ETIMEDOUT    - 连接超时                               │
│              │ ENETDOWN     - 网络关闭                               │
├──────────────┼───────────────────────────────────────────────────────┤
│ 资源错误     │ EMFILE       - 进程fd数达到上限                       │
│              │ ENFILE       - 系统fd数达到上限                       │
│              │ ENOMEM       - 内存不足                               │
│              │ ENOBUFS      - 缓冲区空间不足                         │
├──────────────┼───────────────────────────────────────────────────────┤
│ 地址错误     │ EADDRINUSE   - 地址已被使用                           │
│              │ EADDRNOTAVAIL- 地址不可用                             │
├──────────────┼───────────────────────────────────────────────────────┤
│ 协议错误     │ EPIPE        - 写入已关闭的连接                       │
│              │ EMSGSIZE     - 消息太大（UDP）                        │
└──────────────┴───────────────────────────────────────────────────────┘
*/

// 错误分类检查函数
namespace sock_error {

// 是否应该重试
bool should_retry(int err) {
    return err == EINTR || err == EAGAIN || err == EWOULDBLOCK;
}

// 是否是连接相关错误
bool is_connection_error(int err) {
    return err == ECONNREFUSED || err == ECONNRESET ||
           err == ECONNABORTED || err == ENOTCONN;
}

// 是否是网络相关错误
bool is_network_error(int err) {
    return err == ENETUNREACH || err == EHOSTUNREACH ||
           err == ETIMEDOUT || err == ENETDOWN;
}

// 是否是资源相关错误
bool is_resource_error(int err) {
    return err == EMFILE || err == ENFILE ||
           err == ENOMEM || err == ENOBUFS;
}

// 是否是致命错误（不可恢复）
bool is_fatal_error(int err) {
    return is_resource_error(err);
}

// 获取错误描述
const char* error_string(int err) {
    return strerror(err);
}

// 打印错误信息
void print_error(const char* context, int err = errno) {
    std::cerr << context << ": " << error_string(err)
              << " (errno=" << err << ")" << std::endl;
}

} // namespace sock_error
```

#### 2. Stevens风格包装函数

```cpp
// ============================================================
// Stevens风格错误处理包装函数
// ============================================================

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <cerrno>
#include <cstring>
#include <cstdlib>
#include <stdexcept>
#include <string>

// 自定义Socket异常
class SocketException : public std::runtime_error {
public:
    SocketException(const std::string& msg, int err = errno)
        : std::runtime_error(msg + ": " + strerror(err)), error_code(err) {}

    int code() const { return error_code; }

private:
    int error_code;
};

namespace net {

// Socket - 创建socket
int Socket(int domain, int type, int protocol) {
    int fd = socket(domain, type, protocol);
    if (fd < 0) {
        throw SocketException("socket()");
    }
    return fd;
}

// Bind - 绑定地址
void Bind(int fd, const sockaddr* addr, socklen_t len) {
    if (bind(fd, addr, len) < 0) {
        throw SocketException("bind()");
    }
}

// Listen - 监听
void Listen(int fd, int backlog) {
    if (listen(fd, backlog) < 0) {
        throw SocketException("listen()");
    }
}

// Accept - 接受连接（处理EINTR）
int Accept(int fd, sockaddr* addr, socklen_t* len) {
    int client_fd;
    while ((client_fd = accept(fd, addr, len)) < 0) {
        if (errno == EINTR) continue;  // 被信号中断，重试
        throw SocketException("accept()");
    }
    return client_fd;
}

// Connect - 连接（处理EINTR）
void Connect(int fd, const sockaddr* addr, socklen_t len) {
    while (connect(fd, addr, len) < 0) {
        if (errno == EINTR) continue;
        throw SocketException("connect()");
    }
}

// Read_n - 读取恰好n字节
ssize_t Read_n(int fd, void* buf, size_t n) {
    size_t nleft = n;
    char* ptr = static_cast<char*>(buf);

    while (nleft > 0) {
        ssize_t nread = read(fd, ptr, nleft);
        if (nread < 0) {
            if (errno == EINTR) continue;
            throw SocketException("read()");
        }
        if (nread == 0) break;  // EOF
        nleft -= nread;
        ptr += nread;
    }
    return n - nleft;
}

// Write_n - 写入恰好n字节
void Write_n(int fd, const void* buf, size_t n) {
    size_t nleft = n;
    const char* ptr = static_cast<const char*>(buf);

    while (nleft > 0) {
        ssize_t nwritten = write(fd, ptr, nleft);
        if (nwritten < 0) {
            if (errno == EINTR) continue;
            throw SocketException("write()");
        }
        nleft -= nwritten;
        ptr += nwritten;
    }
}

// Close - 关闭（处理EINTR，虽然Linux不会对close返回EINTR）
void Close(int fd) {
    if (close(fd) < 0) {
        throw SocketException("close()");
    }
}

// Setsockopt - 设置选项
void Setsockopt(int fd, int level, int optname,
                const void* optval, socklen_t optlen) {
    if (setsockopt(fd, level, optname, optval, optlen) < 0) {
        throw SocketException("setsockopt()");
    }
}

} // namespace net

// 使用示例
void server_with_wrapper() {
    try {
        int server_fd = net::Socket(AF_INET, SOCK_STREAM, 0);

        int opt = 1;
        net::Setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = htonl(INADDR_ANY);
        addr.sin_port = htons(8080);

        net::Bind(server_fd, reinterpret_cast<sockaddr*>(&addr), sizeof(addr));
        net::Listen(server_fd, SOMAXCONN);

        std::cout << "服务器启动成功" << std::endl;

        while (true) {
            int client_fd = net::Accept(server_fd, nullptr, nullptr);
            // 处理客户端...
            net::Close(client_fd);
        }

    } catch (const SocketException& e) {
        std::cerr << "Socket错误: " << e.what() << std::endl;
        std::cerr << "错误码: " << e.code() << std::endl;
    }
}
```

#### 3. 跨平台错误处理

```cpp
// ============================================================
// 跨平台错误处理
// ============================================================

#ifdef _WIN32
#include <winsock2.h>
#include <ws2tcpip.h>
#pragma comment(lib, "ws2_32.lib")
#else
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <cerrno>
#endif

#include <string>

namespace platform {

// 获取最后的socket错误
int get_last_error() {
#ifdef _WIN32
    return WSAGetLastError();
#else
    return errno;
#endif
}

// 设置错误码
void set_last_error(int err) {
#ifdef _WIN32
    WSASetLastError(err);
#else
    errno = err;
#endif
}

// 错误码转字符串
std::string error_to_string(int err) {
#ifdef _WIN32
    char buf[256];
    FormatMessageA(FORMAT_MESSAGE_FROM_SYSTEM,
                   nullptr, err, 0, buf, sizeof(buf), nullptr);
    return buf;
#else
    return strerror(err);
#endif
}

// 跨平台错误码映射
enum class SocketError {
    Success = 0,
    WouldBlock,
    InProgress,
    Interrupted,
    ConnectionRefused,
    ConnectionReset,
    ConnectionAborted,
    NotConnected,
    TimedOut,
    AddressInUse,
    NetworkUnreachable,
    HostUnreachable,
    Unknown
};

SocketError translate_error(int err) {
#ifdef _WIN32
    switch (err) {
        case 0: return SocketError::Success;
        case WSAEWOULDBLOCK: return SocketError::WouldBlock;
        case WSAEINPROGRESS: return SocketError::InProgress;
        case WSAEINTR: return SocketError::Interrupted;
        case WSAECONNREFUSED: return SocketError::ConnectionRefused;
        case WSAECONNRESET: return SocketError::ConnectionReset;
        case WSAECONNABORTED: return SocketError::ConnectionAborted;
        case WSAENOTCONN: return SocketError::NotConnected;
        case WSAETIMEDOUT: return SocketError::TimedOut;
        case WSAEADDRINUSE: return SocketError::AddressInUse;
        case WSAENETUNREACH: return SocketError::NetworkUnreachable;
        case WSAEHOSTUNREACH: return SocketError::HostUnreachable;
        default: return SocketError::Unknown;
    }
#else
    switch (err) {
        case 0: return SocketError::Success;
        case EAGAIN:
        case EWOULDBLOCK: return SocketError::WouldBlock;
        case EINPROGRESS: return SocketError::InProgress;
        case EINTR: return SocketError::Interrupted;
        case ECONNREFUSED: return SocketError::ConnectionRefused;
        case ECONNRESET: return SocketError::ConnectionReset;
        case ECONNABORTED: return SocketError::ConnectionAborted;
        case ENOTCONN: return SocketError::NotConnected;
        case ETIMEDOUT: return SocketError::TimedOut;
        case EADDRINUSE: return SocketError::AddressInUse;
        case ENETUNREACH: return SocketError::NetworkUnreachable;
        case EHOSTUNREACH: return SocketError::HostUnreachable;
        default: return SocketError::Unknown;
    }
#endif
}

// 判断是否应该重试
bool should_retry(SocketError err) {
    return err == SocketError::WouldBlock ||
           err == SocketError::Interrupted;
}

} // namespace platform
```

### Day 26-27：跨平台Socket封装库

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | 平台抽象层与Socket基类 | 3h |
| 下午 | TcpSocket和UdpSocket实现 | 3h |
| 晚上 | TcpServer和AddressInfo实现 | 3h |

#### 1. 平台抽象层与Socket基类

```cpp
// ============================================================
// 跨平台Socket封装库 - platform.hpp
// ============================================================

#pragma once

#ifdef _WIN32
    #include <winsock2.h>
    #include <ws2tcpip.h>
    #pragma comment(lib, "ws2_32.lib")
    using socket_t = SOCKET;
    constexpr socket_t INVALID_SOCKET_VALUE = INVALID_SOCKET;
    #define SOCKET_ERROR_VALUE SOCKET_ERROR
#else
    #include <sys/socket.h>
    #include <netinet/in.h>
    #include <netinet/tcp.h>
    #include <arpa/inet.h>
    #include <netdb.h>
    #include <unistd.h>
    #include <fcntl.h>
    #include <cerrno>
    using socket_t = int;
    constexpr socket_t INVALID_SOCKET_VALUE = -1;
    #define SOCKET_ERROR_VALUE -1
#endif

#include <string>
#include <stdexcept>
#include <cstring>

// Windows socket初始化（RAII）
#ifdef _WIN32
class WinsockInitializer {
public:
    WinsockInitializer() {
        WSADATA wsaData;
        int result = WSAStartup(MAKEWORD(2, 2), &wsaData);
        if (result != 0) {
            throw std::runtime_error("WSAStartup failed");
        }
    }
    ~WinsockInitializer() {
        WSACleanup();
    }
    // 禁止拷贝
    WinsockInitializer(const WinsockInitializer&) = delete;
    WinsockInitializer& operator=(const WinsockInitializer&) = delete;
};

// 全局初始化器（在main之前初始化）
inline WinsockInitializer& get_winsock_initializer() {
    static WinsockInitializer init;
    return init;
}
#endif

// 跨平台关闭socket
inline void close_socket(socket_t fd) {
#ifdef _WIN32
    closesocket(fd);
#else
    close(fd);
#endif
}

// 跨平台获取错误码
inline int get_socket_errno() {
#ifdef _WIN32
    return WSAGetLastError();
#else
    return errno;
#endif
}

// 跨平台错误字符串
inline std::string socket_strerror(int err) {
#ifdef _WIN32
    char buf[256];
    FormatMessageA(FORMAT_MESSAGE_FROM_SYSTEM,
                   nullptr, err, 0, buf, sizeof(buf), nullptr);
    return buf;
#else
    return strerror(err);
#endif
}
```

```cpp
// ============================================================
// 跨平台Socket封装库 - socket.hpp (Socket基类)
// ============================================================

#pragma once

#include "platform.hpp"
#include <string>
#include <stdexcept>

class SocketError : public std::runtime_error {
public:
    explicit SocketError(const std::string& msg, int err = get_socket_errno())
        : std::runtime_error(msg + ": " + socket_strerror(err))
        , error_code_(err) {}

    int code() const { return error_code_; }

private:
    int error_code_;
};

class Socket {
protected:
    socket_t fd_ = INVALID_SOCKET_VALUE;

    explicit Socket(socket_t fd) : fd_(fd) {}

public:
    Socket() = default;

    ~Socket() {
        close();
    }

    // 禁止拷贝
    Socket(const Socket&) = delete;
    Socket& operator=(const Socket&) = delete;

    // 允许移动
    Socket(Socket&& other) noexcept : fd_(other.fd_) {
        other.fd_ = INVALID_SOCKET_VALUE;
    }

    Socket& operator=(Socket&& other) noexcept {
        if (this != &other) {
            close();
            fd_ = other.fd_;
            other.fd_ = INVALID_SOCKET_VALUE;
        }
        return *this;
    }

    // 关闭socket
    void close() {
        if (fd_ != INVALID_SOCKET_VALUE) {
            close_socket(fd_);
            fd_ = INVALID_SOCKET_VALUE;
        }
    }

    // 检查是否有效
    bool valid() const { return fd_ != INVALID_SOCKET_VALUE; }

    // 获取原生句柄
    socket_t native() const { return fd_; }

    // 释放所有权
    socket_t release() {
        socket_t fd = fd_;
        fd_ = INVALID_SOCKET_VALUE;
        return fd;
    }

    // 设置非阻塞模式
    void set_nonblocking(bool nonblock) {
#ifdef _WIN32
        u_long mode = nonblock ? 1 : 0;
        ioctlsocket(fd_, FIONBIO, &mode);
#else
        int flags = fcntl(fd_, F_GETFL, 0);
        if (nonblock) {
            fcntl(fd_, F_SETFL, flags | O_NONBLOCK);
        } else {
            fcntl(fd_, F_SETFL, flags & ~O_NONBLOCK);
        }
#endif
    }

    // 设置接收/发送超时
    void set_timeout(int recv_ms, int send_ms) {
#ifdef _WIN32
        setsockopt(fd_, SOL_SOCKET, SO_RCVTIMEO,
                   reinterpret_cast<const char*>(&recv_ms), sizeof(recv_ms));
        setsockopt(fd_, SOL_SOCKET, SO_SNDTIMEO,
                   reinterpret_cast<const char*>(&send_ms), sizeof(send_ms));
#else
        struct timeval tv;
        tv.tv_sec = recv_ms / 1000;
        tv.tv_usec = (recv_ms % 1000) * 1000;
        setsockopt(fd_, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));

        tv.tv_sec = send_ms / 1000;
        tv.tv_usec = (send_ms % 1000) * 1000;
        setsockopt(fd_, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));
#endif
    }

    // 获取本地地址
    std::string get_local_address() const;

    // 获取对端地址
    std::string get_peer_address() const;
};
```

#### 2. TcpSocket实现

```cpp
// ============================================================
// TcpSocket 实现
// ============================================================

#pragma once

#include "socket.hpp"
#include <vector>
#include <optional>

class TcpSocket : public Socket {
public:
    // 创建TCP socket
    static TcpSocket create(int family = AF_INET) {
        socket_t fd = socket(family, SOCK_STREAM, 0);
        if (fd == INVALID_SOCKET_VALUE) {
            throw SocketError("socket()");
        }
        return TcpSocket(fd);
    }

    // 从已有fd创建
    static TcpSocket from_fd(socket_t fd) {
        return TcpSocket(fd);
    }

    // 连接到服务器
    void connect(const std::string& host, int port) {
        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_port = htons(port);

        if (inet_pton(AF_INET, host.c_str(), &addr.sin_addr) != 1) {
            throw SocketError("Invalid address: " + host, 0);
        }

        if (::connect(fd_, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) < 0) {
            throw SocketError("connect()");
        }
    }

    // 带超时的连接
    bool connect_with_timeout(const std::string& host, int port, int timeout_ms);

    // 绑定地址
    void bind(const std::string& host, int port) {
        int opt = 1;
        setsockopt(fd_, SOL_SOCKET, SO_REUSEADDR,
                   reinterpret_cast<const char*>(&opt), sizeof(opt));

        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_port = htons(port);

        if (host.empty() || host == "0.0.0.0") {
            addr.sin_addr.s_addr = htonl(INADDR_ANY);
        } else {
            inet_pton(AF_INET, host.c_str(), &addr.sin_addr);
        }

        if (::bind(fd_, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) < 0) {
            throw SocketError("bind()");
        }
    }

    // 监听
    void listen(int backlog = SOMAXCONN) {
        if (::listen(fd_, backlog) < 0) {
            throw SocketError("listen()");
        }
    }

    // 接受连接
    std::optional<TcpSocket> accept() {
        socket_t client = ::accept(fd_, nullptr, nullptr);
        if (client == INVALID_SOCKET_VALUE) {
            if (get_socket_errno() == EAGAIN || get_socket_errno() == EWOULDBLOCK) {
                return std::nullopt;
            }
            throw SocketError("accept()");
        }
        return TcpSocket(client);
    }

    // 发送数据
    ssize_t send(const void* data, size_t len) {
        return ::send(fd_, static_cast<const char*>(data), len, 0);
    }

    // 发送全部数据
    void send_all(const void* data, size_t len) {
        const char* ptr = static_cast<const char*>(data);
        size_t remaining = len;

        while (remaining > 0) {
            ssize_t n = ::send(fd_, ptr, remaining, 0);
            if (n < 0) {
#ifndef _WIN32
                if (errno == EINTR) continue;
#endif
                throw SocketError("send()");
            }
            ptr += n;
            remaining -= n;
        }
    }

    // 接收数据
    ssize_t recv(void* buffer, size_t len) {
        return ::recv(fd_, static_cast<char*>(buffer), len, 0);
    }

    // 接收全部数据
    size_t recv_all(void* buffer, size_t len) {
        char* ptr = static_cast<char*>(buffer);
        size_t remaining = len;

        while (remaining > 0) {
            ssize_t n = ::recv(fd_, ptr, remaining, 0);
            if (n < 0) {
#ifndef _WIN32
                if (errno == EINTR) continue;
#endif
                throw SocketError("recv()");
            }
            if (n == 0) break;  // 连接关闭
            ptr += n;
            remaining -= n;
        }
        return len - remaining;
    }

    // 关闭发送/接收
    void shutdown_send() {
        ::shutdown(fd_, SHUT_WR);
    }

    void shutdown_recv() {
        ::shutdown(fd_, SHUT_RD);
    }

    // 禁用Nagle算法
    void set_nodelay(bool enable) {
        int opt = enable ? 1 : 0;
        setsockopt(fd_, IPPROTO_TCP, TCP_NODELAY,
                   reinterpret_cast<const char*>(&opt), sizeof(opt));
    }

private:
    explicit TcpSocket(socket_t fd) : Socket(fd) {}
};
```

#### 3. UdpSocket实现

```cpp
// ============================================================
// UdpSocket 实现
// ============================================================

#pragma once

#include "socket.hpp"

class UdpSocket : public Socket {
public:
    // 创建UDP socket
    static UdpSocket create(int family = AF_INET) {
        socket_t fd = socket(family, SOCK_DGRAM, 0);
        if (fd == INVALID_SOCKET_VALUE) {
            throw SocketError("socket()");
        }
        return UdpSocket(fd);
    }

    // 绑定地址
    void bind(const std::string& host, int port) {
        int opt = 1;
        setsockopt(fd_, SOL_SOCKET, SO_REUSEADDR,
                   reinterpret_cast<const char*>(&opt), sizeof(opt));

        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_port = htons(port);

        if (host.empty() || host == "0.0.0.0") {
            addr.sin_addr.s_addr = htonl(INADDR_ANY);
        } else {
            inet_pton(AF_INET, host.c_str(), &addr.sin_addr);
        }

        if (::bind(fd_, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) < 0) {
            throw SocketError("bind()");
        }
    }

    // 发送到指定地址
    ssize_t send_to(const void* data, size_t len,
                    const std::string& host, int port) {
        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_port = htons(port);
        inet_pton(AF_INET, host.c_str(), &addr.sin_addr);

        return sendto(fd_, static_cast<const char*>(data), len, 0,
                      reinterpret_cast<sockaddr*>(&addr), sizeof(addr));
    }

    // 接收数据和发送者地址
    ssize_t recv_from(void* buffer, size_t len,
                      std::string& sender_ip, int& sender_port) {
        sockaddr_in sender_addr{};
        socklen_t sender_len = sizeof(sender_addr);

        ssize_t n = recvfrom(fd_, static_cast<char*>(buffer), len, 0,
                             reinterpret_cast<sockaddr*>(&sender_addr),
                             &sender_len);

        if (n > 0) {
            char ip_str[INET_ADDRSTRLEN];
            inet_ntop(AF_INET, &sender_addr.sin_addr, ip_str, sizeof(ip_str));
            sender_ip = ip_str;
            sender_port = ntohs(sender_addr.sin_port);
        }

        return n;
    }

    // 设置广播
    void set_broadcast(bool enable) {
        int opt = enable ? 1 : 0;
        setsockopt(fd_, SOL_SOCKET, SO_BROADCAST,
                   reinterpret_cast<const char*>(&opt), sizeof(opt));
    }

    // 加入组播组
    void join_multicast_group(const std::string& group_ip,
                               const std::string& local_ip = "") {
        struct ip_mreq mreq{};
        inet_pton(AF_INET, group_ip.c_str(), &mreq.imr_multiaddr);

        if (local_ip.empty()) {
            mreq.imr_interface.s_addr = htonl(INADDR_ANY);
        } else {
            inet_pton(AF_INET, local_ip.c_str(), &mreq.imr_interface);
        }

        if (setsockopt(fd_, IPPROTO_IP, IP_ADD_MEMBERSHIP,
                       reinterpret_cast<const char*>(&mreq), sizeof(mreq)) < 0) {
            throw SocketError("IP_ADD_MEMBERSHIP");
        }
    }

    // 离开组播组
    void leave_multicast_group(const std::string& group_ip) {
        struct ip_mreq mreq{};
        inet_pton(AF_INET, group_ip.c_str(), &mreq.imr_multiaddr);
        mreq.imr_interface.s_addr = htonl(INADDR_ANY);

        setsockopt(fd_, IPPROTO_IP, IP_DROP_MEMBERSHIP,
                   reinterpret_cast<const char*>(&mreq), sizeof(mreq));
    }

    // 设置组播TTL
    void set_multicast_ttl(int ttl) {
        setsockopt(fd_, IPPROTO_IP, IP_MULTICAST_TTL,
                   reinterpret_cast<const char*>(&ttl), sizeof(ttl));
    }

private:
    explicit UdpSocket(socket_t fd) : Socket(fd) {}
};
```

#### 4. TcpServer和AddressInfo实现

```cpp
// ============================================================
// TcpServer - 服务器管理类
// ============================================================

#pragma once

#include "tcp_socket.hpp"
#include <functional>
#include <atomic>

class TcpServer {
public:
    using ConnectionHandler = std::function<void(TcpSocket client,
                                                   const std::string& client_addr)>;

    TcpServer() = default;

    // 启动服务器
    void start(const std::string& host, int port,
               ConnectionHandler handler,
               int backlog = SOMAXCONN) {
        socket_ = TcpSocket::create();
        socket_.bind(host, port);
        socket_.listen(backlog);
        handler_ = handler;
        running_ = true;

        accept_loop();
    }

    // 停止服务器
    void stop() {
        running_ = false;
        socket_.close();
    }

    // 获取连接数
    int connection_count() const { return connection_count_; }

private:
    void accept_loop() {
        while (running_) {
            auto client = socket_.accept();
            if (!client) continue;

            connection_count_++;
            std::string client_addr = client->get_peer_address();

            try {
                handler_(std::move(*client), client_addr);
            } catch (const std::exception& e) {
                // 处理异常
            }

            connection_count_--;
        }
    }

    TcpSocket socket_;
    ConnectionHandler handler_;
    std::atomic<bool> running_{false};
    std::atomic<int> connection_count_{0};
};
```

```cpp
// ============================================================
// AddressInfo - getaddrinfo RAII封装
// ============================================================

#pragma once

#include "platform.hpp"
#include <string>
#include <vector>
#include <stdexcept>

class AddressInfo {
public:
    struct Result {
        int family;
        int socktype;
        int protocol;
        std::string ip;
        int port;
        sockaddr_storage addr;
        socklen_t addr_len;
    };

    // 解析地址
    static std::vector<Result> resolve(const std::string& host,
                                        const std::string& service,
                                        int family = AF_UNSPEC,
                                        int socktype = 0) {
        struct addrinfo hints{};
        hints.ai_family = family;
        hints.ai_socktype = socktype;
        hints.ai_flags = AI_PASSIVE;

        struct addrinfo* res = nullptr;
        int err = getaddrinfo(host.empty() ? nullptr : host.c_str(),
                              service.empty() ? nullptr : service.c_str(),
                              &hints, &res);
        if (err != 0) {
            throw std::runtime_error("getaddrinfo: " + std::string(gai_strerror(err)));
        }

        std::vector<Result> results;
        for (struct addrinfo* p = res; p != nullptr; p = p->ai_next) {
            Result r;
            r.family = p->ai_family;
            r.socktype = p->ai_socktype;
            r.protocol = p->ai_protocol;
            r.addr_len = p->ai_addrlen;
            std::memcpy(&r.addr, p->ai_addr, p->ai_addrlen);

            char ip_str[INET6_ADDRSTRLEN];
            if (p->ai_family == AF_INET) {
                auto* addr4 = reinterpret_cast<sockaddr_in*>(p->ai_addr);
                inet_ntop(AF_INET, &addr4->sin_addr, ip_str, sizeof(ip_str));
                r.port = ntohs(addr4->sin_port);
            } else if (p->ai_family == AF_INET6) {
                auto* addr6 = reinterpret_cast<sockaddr_in6*>(p->ai_addr);
                inet_ntop(AF_INET6, &addr6->sin6_addr, ip_str, sizeof(ip_str));
                r.port = ntohs(addr6->sin6_port);
            }
            r.ip = ip_str;

            results.push_back(r);
        }

        freeaddrinfo(res);
        return results;
    }
};
```

### Day 28：项目集成与测试

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | 使用封装库实现Echo Server | 2h |
| 下午 | 单元测试 | 3h |
| 晚上 | CMakeLists.txt与项目总结 | 2h |

#### 1. 使用封装库实现Echo Server

```cpp
// ============================================================
// 使用封装库的Echo Server示例
// ============================================================

#include "tcp_socket.hpp"
#include <iostream>
#include <thread>

// 对比：使用封装库 vs 原始API

// 使用封装库的版本 - 简洁易读
void echo_server_with_wrapper(int port) {
    try {
        auto server = TcpSocket::create();
        server.bind("", port);
        server.listen();

        std::cout << "Echo Server listening on port " << port << std::endl;

        while (true) {
            auto client = server.accept();
            if (!client) continue;

            std::cout << "Client connected: " << client->get_peer_address() << std::endl;

            // 在新线程中处理客户端
            std::thread([c = std::move(*client)]() mutable {
                char buffer[1024];
                while (true) {
                    ssize_t n = c.recv(buffer, sizeof(buffer));
                    if (n <= 0) break;
                    c.send_all(buffer, n);
                }
            }).detach();
        }
    } catch (const SocketError& e) {
        std::cerr << "Error: " << e.what() << std::endl;
    }
}

// 客户端示例
void echo_client_with_wrapper(const std::string& host, int port) {
    try {
        auto client = TcpSocket::create();
        client.connect(host, port);
        client.set_nodelay(true);

        std::cout << "Connected to " << host << ":" << port << std::endl;

        std::string message = "Hello, Server!";
        client.send_all(message.data(), message.size());

        char buffer[1024];
        ssize_t n = client.recv(buffer, sizeof(buffer));
        if (n > 0) {
            buffer[n] = '\0';
            std::cout << "Received: " << buffer << std::endl;
        }
    } catch (const SocketError& e) {
        std::cerr << "Error: " << e.what() << std::endl;
    }
}
```

#### 2. CMakeLists.txt

```cmake
# ============================================================
# Socket封装库 CMakeLists.txt
# ============================================================

cmake_minimum_required(VERSION 3.14)
project(SocketWrapper VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 头文件库（header-only）
add_library(socket_wrapper INTERFACE)
target_include_directories(socket_wrapper INTERFACE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

# Windows需要链接ws2_32
if(WIN32)
    target_link_libraries(socket_wrapper INTERFACE ws2_32)
endif()

# 示例程序
add_executable(echo_server examples/echo_server.cpp)
target_link_libraries(echo_server PRIVATE socket_wrapper)

add_executable(echo_client examples/echo_client.cpp)
target_link_libraries(echo_client PRIVATE socket_wrapper)

add_executable(udp_echo examples/udp_echo.cpp)
target_link_libraries(udp_echo PRIVATE socket_wrapper)

add_executable(dns_resolver examples/dns_resolver.cpp)
target_link_libraries(dns_resolver PRIVATE socket_wrapper)

# 测试
enable_testing()

add_executable(test_socket tests/test_socket.cpp)
target_link_libraries(test_socket PRIVATE socket_wrapper)
add_test(NAME SocketTests COMMAND test_socket)

add_executable(test_tcp tests/test_tcp.cpp)
target_link_libraries(test_tcp PRIVATE socket_wrapper)
add_test(NAME TcpTests COMMAND test_tcp)
```

#### 第四周检验标准

- [ ] 掌握SO_REUSEADDR/SO_REUSEPORT/SO_RCVBUF/SO_SNDBUF等选项
- [ ] 掌握TCP_NODELAY选项，理解Nagle算法
- [ ] 能使用getsockname/getpeername获取地址信息
- [ ] 理解Socket错误码分类和处理策略
- [ ] 实现Stevens风格的错误处理包装函数
- [ ] 理解跨平台Socket编程的差异（POSIX vs Winsock）
- [ ] 实现Socket基类（RAII、移动语义）
- [ ] 实现TcpSocket类（连接、发送、接收、选项设置）
- [ ] 实现UdpSocket类（收发、广播、组播）
- [ ] 实现AddressInfo辅助类（DNS解析封装）

---

## 本月检验标准汇总

### 理论知识检验（笔试/口述）

| 序号 | 检验项目 | 达标要求 | 自评 |
|:----:|:---------|:---------|:----:|
| 1 | OSI七层模型 | 能说出每层名称、功能和典型协议 | ☐ |
| 2 | TCP/IP四层模型 | 能说明与OSI的对应关系 | ☐ |
| 3 | TCP三次握手 | 能画出序列图，说明每步作用和状态转换 | ☐ |
| 4 | TCP四次挥手 | 能画出序列图，解释TIME_WAIT存在意义 | ☐ |
| 5 | TCP状态机 | 能画出完整状态转换图（至少11个状态） | ☐ |
| 6 | TCP首部结构 | 能说出关键字段（端口、序号、确认号、标志位、窗口） | ☐ |
| 7 | UDP首部结构 | 能说出四个字段及其作用 | ☐ |
| 8 | TCP vs UDP | 能从5个维度对比两者差异 | ☐ |
| 9 | 字节序 | 能解释大端/小端区别，说明网络字节序 | ☐ |
| 10 | sockaddr结构族 | 能说明sockaddr/sockaddr_in/sockaddr_in6/sockaddr_storage关系 | ☐ |
| 11 | TCP服务器流程 | 能说出socket→bind→listen→accept→read/write→close完整流程 | ☐ |
| 12 | listen() backlog | 能解释全连接队列和半连接队列 | ☐ |
| 13 | TCP流特性 | 能解释粘包/半包问题及解决方案 | ☐ |
| 14 | Nagle算法 | 能解释算法原理及TCP_NODELAY的作用 | ☐ |
| 15 | SO_REUSEADDR | 能解释该选项的作用和使用场景 | ☐ |
| 16 | TIME_WAIT | 能解释产生原因、持续时间、处理方法 | ☐ |
| 17 | shutdown vs close | 能说明两者区别和半关闭的含义 | ☐ |
| 18 | UDP消息边界 | 能解释UDP保持消息边界的特性 | ☐ |
| 19 | 广播vs组播 | 能从范围、效率、配置等方面对比 | ☐ |
| 20 | Socket错误分类 | 能说出可重试/连接/网络/资源四类错误的代表 | ☐ |

### 实践技能检验（上机）

| 序号 | 检验项目 | 达标要求 | 自评 |
|:----:|:---------|:---------|:----:|
| 1 | 字节序转换 | 能正确使用htons/htonl/ntohs/ntohl | ☐ |
| 2 | 地址转换 | 能正确使用inet_pton/inet_ntop处理IPv4/IPv6 | ☐ |
| 3 | DNS解析 | 能使用getaddrinfo解析域名，正确处理结果链表 | ☐ |
| 4 | TCP服务器 | 能从零编写完整TCP Echo Server（含错误处理） | ☐ |
| 5 | TCP客户端 | 能从零编写完整TCP Echo Client | ☐ |
| 6 | 多进程服务器 | 能用fork实现并发服务器，正确处理SIGCHLD | ☐ |
| 7 | 多线程服务器 | 能用std::thread实现并发服务器 | ☐ |
| 8 | 流式数据处理 | 能实现readn/writen，处理TCP粘包问题 | ☐ |
| 9 | 长度前缀协议 | 能实现send_message/recv_message | ☐ |
| 10 | TCP Keep-Alive | 能配置Keep-Alive参数 | ☐ |
| 11 | 优雅关闭 | 能使用shutdown实现半关闭 | ☐ |
| 12 | 信号安全 | 能处理EINTR，了解self-pipe trick | ☐ |
| 13 | UDP服务器 | 能编写完整UDP Echo Server | ☐ |
| 14 | UDP客户端 | 能编写完整UDP Echo Client | ☐ |
| 15 | UDP广播 | 能实现广播发送和接收 | ☐ |
| 16 | UDP组播 | 能实现组播发送和接收（IP_ADD_MEMBERSHIP） | ☐ |
| 17 | Socket选项 | 能使用setsockopt/getsockopt设置和查询选项 | ☐ |
| 18 | 错误处理 | 能实现Stevens风格的错误包装函数 | ☐ |
| 19 | 跨平台编程 | 能处理POSIX和Windows的Socket差异 | ☐ |
| 20 | Socket封装 | 能实现RAII风格的Socket类 | ☐ |

### 达标标准

```
+--------------------------------------------------+
|              Month-25 达标标准                    |
+--------------------------------------------------+
| 理论知识：20项中至少掌握16项（80%）               |
| 实践技能：20项中至少完成16项（80%）               |
| 代码质量：所有代码能编译通过并正确运行            |
| 项目完成：Socket封装库实现并通过基本测试          |
+--------------------------------------------------+
```

---

## 输出物清单

### 项目目录结构

```
month-25-socket/
├── include/                      # 头文件
│   ├── platform.hpp              # 平台抽象层
│   ├── socket.hpp                # Socket基类
│   ├── tcp_socket.hpp            # TCP Socket封装
│   ├── udp_socket.hpp            # UDP Socket封装
│   ├── tcp_server.hpp            # TCP服务器封装
│   └── address_info.hpp          # 地址信息封装
├── examples/                     # 示例程序
│   ├── tcp_echo_server.cpp       # TCP Echo服务器
│   ├── tcp_echo_client.cpp       # TCP Echo客户端
│   ├── udp_echo_server.cpp       # UDP Echo服务器
│   ├── udp_echo_client.cpp       # UDP Echo客户端
│   ├── broadcast_sender.cpp      # UDP广播发送
│   ├── broadcast_receiver.cpp    # UDP广播接收
│   ├── multicast_sender.cpp      # UDP组播发送
│   ├── multicast_receiver.cpp    # UDP组播接收
│   └── dns_resolver.cpp          # DNS解析工具
├── tests/                        # 测试代码
│   ├── test_socket.cpp           # Socket基础测试
│   ├── test_tcp.cpp              # TCP功能测试
│   └── test_udp.cpp              # UDP功能测试
├── docs/                         # 文档
│   └── socket_options.md         # Socket选项参考
├── CMakeLists.txt                # 构建配置
└── README.md                     # 项目说明
```

### 输出物完成度检查表

| 类别 | 输出物 | 说明 | 完成 |
|:----:|:-------|:-----|:----:|
| **头文件** | platform.hpp | 平台检测、类型定义、初始化 | ☐ |
| | socket.hpp | Socket基类（RAII、移动语义） | ☐ |
| | tcp_socket.hpp | TCP连接、发送、接收、选项 | ☐ |
| | udp_socket.hpp | UDP收发、广播、组播 | ☐ |
| | tcp_server.hpp | TCP服务器（accept循环、回调） | ☐ |
| | address_info.hpp | getaddrinfo RAII封装 | ☐ |
| **示例** | tcp_echo_server.cpp | 使用封装库的TCP服务器 | ☐ |
| | tcp_echo_client.cpp | 使用封装库的TCP客户端 | ☐ |
| | udp_echo_server.cpp | 使用封装库的UDP服务器 | ☐ |
| | udp_echo_client.cpp | 使用封装库的UDP客户端 | ☐ |
| | broadcast_*.cpp | 广播收发示例 | ☐ |
| | multicast_*.cpp | 组播收发示例 | ☐ |
| | dns_resolver.cpp | DNS解析工具 | ☐ |
| **测试** | test_socket.cpp | Socket创建、选项测试 | ☐ |
| | test_tcp.cpp | TCP连接、收发测试 | ☐ |
| | test_udp.cpp | UDP收发测试 | ☐ |
| **构建** | CMakeLists.txt | CMake配置（跨平台） | ☐ |
| **文档** | socket_options.md | Socket选项速查表 | ☐ |

---

## 学习建议

### 学习顺序建议

```
推荐学习路径：

Week 1: 打好理论基础
    │
    ├── 1. 先理解OSI/TCP-IP模型（Day 1-2）
    │      └── 画出协议栈图，标注每层协议
    │
    ├── 2. 深入TCP协议（Day 3-4）
    │      └── 手画三次握手/四次挥手序列图
    │      └── 背诵TCP状态转换关键路径
    │
    └── 3. 掌握地址结构（Day 5-7）
           └── 编写字节序测试程序
           └── 熟练使用inet_pton/inet_ntop

Week 2: TCP编程实战
    │
    ├── 1. 先写迭代版Echo Server（Day 8-9）
    │      └── 理解每个系统调用的作用
    │
    ├── 2. 再写并发版本（Day 10-11）
    │      └── 对比fork/thread两种方式
    │
    └── 3. 处理实际问题（Day 12-14）
           └── 粘包处理、Keep-Alive、优雅关闭

Week 3: UDP与高级主题
    │
    ├── 1. 先写基础UDP程序（Day 15-16）
    │      └── 对比UDP/TCP编程差异
    │
    ├── 2. 实现广播和组播（Day 17-18）
    │      └── 在本地网络测试
    │
    └── 3. DNS解析深入（Day 19-21）
           └── 封装好用的解析函数

Week 4: 封装与完善
    │
    ├── 1. 熟悉Socket选项（Day 22-23）
    │      └── 每个选项都写测试代码
    │
    ├── 2. 建立错误处理体系（Day 24-25）
    │      └── 分类处理不同错误
    │
    └── 3. 完成封装库（Day 26-28）
           └── 用封装库重写所有示例
```

### 调试技巧

```
+--------------------------------------------------+
|              Socket编程调试技巧                   |
+--------------------------------------------------+
| 1. 使用netstat/ss查看连接状态                    |
|    $ ss -tlnp        # 查看TCP监听端口           |
|    $ ss -tunp        # 查看所有TCP/UDP连接       |
|                                                  |
| 2. 使用tcpdump/Wireshark抓包                     |
|    $ sudo tcpdump -i lo port 8080               |
|                                                  |
| 3. 使用nc/telnet测试服务器                       |
|    $ nc localhost 8080                          |
|    $ telnet localhost 8080                      |
|                                                  |
| 4. 使用strace追踪系统调用                        |
|    $ strace -e trace=network ./server           |
|                                                  |
| 5. 打印Socket选项值验证配置                      |
|    getsockopt() 后打印查看                       |
+--------------------------------------------------+
```

### 常见错误与解决

| 错误现象 | 可能原因 | 解决方法 |
|:---------|:---------|:---------|
| bind: Address already in use | TIME_WAIT状态残留 | 设置SO_REUSEADDR |
| connect: Connection refused | 服务器未启动或端口错误 | 检查服务器状态和端口 |
| send: Broken pipe | 对端已关闭连接 | 检查连接状态，处理SIGPIPE |
| recv返回0 | 对端正常关闭 | 正常情况，清理资源 |
| recv返回-1 | 多种原因 | 检查errno确定具体错误 |
| 粘包/半包 | TCP流式传输特性 | 使用长度前缀或分隔符 |
| 乱码输出 | 字节序问题 | 检查htons/ntohs使用 |
| 僵尸进程 | 未处理SIGCHLD | 注册信号处理函数 |
| 客户端阻塞 | 服务器未响应 | 设置超时或使用非阻塞 |

---

## 结语

```
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║         恭喜完成 Month-25：Socket编程基础 学习！               ║
║                                                                ║
║    ┌──────────────────────────────────────────────────────┐   ║
║    │  本月你已掌握：                                      │   ║
║    │                                                      │   ║
║    │  ✓ OSI/TCP-IP协议栈理论                             │   ║
║    │  ✓ TCP三次握手/四次挥手与状态机                     │   ║
║    │  ✓ Socket地址结构与字节序转换                       │   ║
║    │  ✓ TCP服务器/客户端完整编程                         │   ║
║    │  ✓ 多进程/多线程并发服务器                          │   ║
║    │  ✓ TCP流式数据处理与粘包解决                        │   ║
║    │  ✓ UDP服务器/客户端编程                             │   ║
║    │  ✓ UDP广播与组播通信                                │   ║
║    │  ✓ DNS解析与地址工具                                │   ║
║    │  ✓ Socket选项配置与错误处理                         │   ║
║    │  ✓ 跨平台Socket封装库设计                           │   ║
║    └──────────────────────────────────────────────────────┘   ║
║                                                                ║
║    这是Year 3高性能网络编程之旅的第一站！                      ║
║    你已经建立了坚实的Socket编程基础，掌握了：                  ║
║    - 网络通信的底层原理                                        ║
║    - TCP/UDP编程的完整范式                                     ║
║    - 生产级代码的错误处理                                      ║
║    - 可复用的跨平台封装                                        ║
║                                                                ║
║    接下来的Month-26将学习阻塞与非阻塞I/O，                     ║
║    为后续的epoll/io_uring高性能模型做准备！                    ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
```

---

## 下月预告：Month-26 阻塞与非阻塞I/O

```
Month-26 学习主题预览：

┌─────────────────────────────────────────────────────────┐
│                    阻塞与非阻塞I/O                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Week 1: 阻塞I/O深入                                   │
│  ├── 阻塞的本质与线程状态                              │
│  ├── 超时设置与轮询检查                                │
│  └── select()多路复用入门                              │
│                                                         │
│  Week 2: 非阻塞I/O基础                                 │
│  ├── fcntl设置非阻塞模式                               │
│  ├── 非阻塞connect/accept/read/write                   │
│  └── EAGAIN/EWOULDBLOCK处理                            │
│                                                         │
│  Week 3: poll与多路复用                                │
│  ├── poll() vs select()                                │
│  ├── 事件驱动编程模型                                  │
│  └── Level-Triggered vs Edge-Triggered                 │
│                                                         │
│  Week 4: 高并发服务器设计                              │
│  ├── C10K问题与解决思路                                │
│  ├── 基于poll的并发服务器                              │
│  └── 为epoll/io_uring做准备                            │
│                                                         │
└─────────────────────────────────────────────────────────┘

     Month-25               Month-26               Month-27
   Socket基础    ──────►  阻塞/非阻塞I/O  ──────►   epoll
   (本月完成)              (下月主题)            (进阶主题)
```

---

**Month-25 Socket编程基础 —— 学习计划完成！**

*继续前进，Year 3 的网络编程大门已经向你敞开！*
