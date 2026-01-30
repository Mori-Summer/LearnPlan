# Month 29: 零拷贝技术——消除数据拷贝开销

## 本月主题概述

零拷贝（Zero-Copy）是高性能服务器的核心优化技术。在传统I/O模型中，数据在磁盘、内核缓冲区、用户缓冲区之间多次拷贝，消耗大量CPU和内存带宽。本月将深入学习Linux下的零拷贝技术，包括sendfile、splice、vmsplice和mmap，理解其内核实现原理，并通过实战项目构建高性能静态文件服务器。通过与Month-28学习的io_uring结合，掌握Linux高性能I/O的完整技术栈。

---

## 知识体系总览

```
Month 29 知识体系：零拷贝技术深度解析
=====================================================

                    ┌─────────────────────┐
                    │  零拷贝技术深度解析  │
                    │ 消除数据拷贝开销    │
                    └──────────┬──────────┘
                               │
         ┌─────────────────────┼─────────────────────┐
         │                     │                     │
         ▼                     ▼                     ▼
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│  传统I/O    │      │  零拷贝技术  │      │  高级应用   │
│  问题分析   │      │  核心机制    │      │             │
│             │      │             │      │             │
│ 4次拷贝     │      │ sendfile    │      │ 文件服务器  │
│ 2次切换     │      │ splice      │      │ 代理服务器  │
│ 带宽瓶颈    │      │ vmsplice    │      │ 消息队列    │
│ CPU开销     │      │ mmap        │      │ 性能对比    │
└──────┬──────┘      └──────┬──────┘      └──────┬──────┘
       │                    │                    │
       ▼                    ▼                    ▼
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│  内存管理   │      │  硬件支持   │      │  综合实战   │
│  基础       │      │             │      │             │
│             │      │             │      │             │
│ 虚拟内存    │      │ DMA         │      │ FileServer  │
│ Page Cache  │      │ Scatter/    │      │ Benchmark   │
│ 页表映射    │      │ Gather      │      │ 性能调优    │
│ 内存屏障    │      │ 网卡offload │      │ 生产实践    │
└─────────────┘      └─────────────┘      └─────────────┘

承接关系：
Month-28 (io_uring——新一代异步I/O)
    │
    ▼
Month-29 (零拷贝技术——sendfile/splice/mmap) ← 当前月份
    │
    ▼
Month-30 (Reactor模式——事件驱动架构)
```

---

## 学习目标

### 核心目标

1. **理解传统I/O的数据拷贝开销**：4次拷贝、2次上下文切换、内存带宽消耗
2. **掌握sendfile系统调用**：原理、使用方法、性能优化
3. **掌握splice/vmsplice技术**：管道中转、用户空间映射、组合使用
4. **掌握mmap内存映射**：文件映射、共享内存、缓存系统设计
5. **构建高性能文件服务器**：多种零拷贝方式对比、性能基准测试

### 学习目标量化

| 目标 | 量化标准 | 验证方式 |
|------|---------|---------|
| 传统I/O理解 | 能画出4次拷贝的数据流图 | 白板绘图 |
| sendfile掌握 | 能实现sendfile文件发送 | 代码运行 |
| splice理解 | 能实现splice代理服务器 | 代码运行 |
| vmsplice理解 | 能使用vmsplice发送用户数据 | 代码运行 |
| mmap掌握 | 能实现mmap文件缓存系统 | 代码运行 |
| 性能对比能力 | 完成3种方式的基准测试 | 测试报告 |
| 综合应用 | 实现支持多种方式的文件服务器 | 代码审查 |

---

## 综合项目概述

### 本月最终项目：高性能静态文件服务器

```
项目目标：构建支持多种零拷贝方式的静态文件服务器

功能架构：
┌─────────────────────────────────────────────────┐
│              Application Layer                  │
│  ┌──────────┐ ┌──────────┐ ┌───────────────┐   │
│  │HTTPServer│ │FileServer│ │BenchmarkTool  │   │
│  └────┬─────┘ └────┬─────┘ └───────┬───────┘   │
│       └─────────────┼───────────────┘           │
│                     ▼                           │
│  ┌─────────────────────────────────────────┐    │
│  │         ZeroCopy Framework              │    │
│  │  ┌───────────┐  ┌────────────────────┐  │    │
│  │  │ FileCache │  │ TransferStrategy   │  │    │
│  │  │ mmap缓存  │  │ sendfile/splice/   │  │    │
│  │  │           │  │ mmap/normal        │  │    │
│  │  └───────────┘  └────────────────────┘  │    │
│  └──────────────────┬──────────────────────┘    │
│                     │                           │
└─────────────────────┼───────────────────────────┘
                      │
        ┌─────────────┼─────────────┐
        │             │             │
        ▼             ▼             ▼
   ┌─────────┐   ┌─────────┐   ┌─────────┐
   │sendfile │   │ splice  │   │  mmap   │
   │         │   │vmsplice │   │         │
   └─────────┘   └─────────┘   └─────────┘

代码量估计：~1500行核心代码
```

---

## 参考书目与资料

### 必读材料

1. **《Linux高性能服务器编程》**
   - 第6章：高级I/O函数
   - 零拷贝相关内容

2. **《UNIX网络编程 卷1》**
   - 高级I/O技术章节

3. **Linux内核文档**
   - Documentation/filesystems/splice.txt
   - man sendfile, man splice, man mmap

### 扩展阅读

- IBM developerWorks: Efficient data transfer through zero copy
- Kafka零拷贝实现分析
- Nginx sendfile配置与优化

---

## 前置知识衔接

### 从Month-28到Month-29

```
Month-28 io_uring 知识点              Month-29 零拷贝 应用
─────────────────────────────────────────────────────────────
异步I/O提交/完成模型         ──▶    零拷贝的异步提交
io_uring_prep_read/write    ──▶    对比sendfile/splice
内核缓冲区概念              ──▶    Page Cache深入理解
SQ/CQ环形缓冲区             ──▶    管道缓冲区机制
批量操作优化                ──▶    批量文件传输优化

关键联系：
┌────────────────────────────────────────────────────────┐
│  io_uring减少系统调用开销，零拷贝减少数据拷贝开销      │
│  两者结合可实现最高性能的I/O操作                       │
│                                                        │
│  io_uring + sendfile = 异步零拷贝文件传输             │
│  io_uring + splice   = 异步零拷贝数据转发             │
└────────────────────────────────────────────────────────┘
```

---

## 时间分配表

```
Week 1: 传统I/O与零拷贝原理（35小时）
├── Day 1-2: 传统I/O的数据拷贝开销（10小时）
├── Day 3-4: 零拷贝技术概览（10小时）
└── Day 5-7: Linux内存管理基础（15小时）

Week 2: sendfile系统调用（35小时）
├── Day 8-9: sendfile原理详解（10小时）
├── Day 10-11: sendfile实践（10小时）
└── Day 12-14: sendfile性能优化（15小时）

Week 3: splice与vmsplice（35小时）
├── Day 15-16: splice系统调用（10小时）
├── Day 17-18: splice应用场景（10小时）
└── Day 19-21: vmsplice与高级用法（15小时）

Week 4: mmap与综合实战（35小时）
├── Day 22-23: mmap内存映射（10小时）
├── Day 24-25: mmap网络应用（10小时）
├── Day 26-27: 用户态协议栈概念与综合对比（10小时）
└── Day 28: 项目总结（5小时）

总计：140小时（4周 × 35小时/周）
```

---

## 第一周：传统I/O与零拷贝原理（Day 1-7）

> **本周目标**：深入理解传统I/O的数据拷贝开销，掌握零拷贝的核心概念和Linux实现技术概览。

```
第一周知识图谱：

                    ┌─────────────────────────────────────┐
                    │      传统I/O与零拷贝原理            │
                    └─────────────────┬───────────────────┘
                                      │
          ┌───────────────────────────┼───────────────────────────┐
          │                           │                           │
          ▼                           ▼                           ▼
   ┌──────────────┐          ┌──────────────┐          ┌──────────────┐
   │  传统I/O     │          │  零拷贝      │          │  内存管理    │
   │  问题分析    │          │  技术概览    │          │  基础        │
   └──────┬───────┘          └──────┬───────┘          └──────┬───────┘
          │                         │                         │
    ┌─────┴─────┐             ┌─────┴─────┐             ┌─────┴─────┐
    │           │             │           │             │           │
    ▼           ▼             ▼           ▼             ▼           ▼
┌───────┐  ┌───────┐     ┌───────┐  ┌───────┐     ┌───────┐  ┌───────┐
│4次    │  │上下文 │     │sendfile│ │DMA    │     │虚拟   │  │Page   │
│拷贝   │  │切换   │     │splice │  │Scatter│     │内存   │  │Cache  │
│       │  │开销   │     │mmap   │  │Gather │     │       │  │       │
└───────┘  └───────┘     └───────┘  └───────┘     └───────┘  └───────┘
```

---

### Day 1-2：传统I/O的数据拷贝开销（10小时）

#### 学习目标

```
Day 1-2 学习目标：

核心目标：深入理解传统I/O的开销
├── 1. 理解传统read/write的4次数据拷贝
├── 2. 区分DMA拷贝与CPU拷贝
├── 3. 理解用户态/内核态切换开销
├── 4. 分析内存带宽瓶颈
└── 5. 能量化评估传统I/O的性能损失

时间分配：
├── Day 1上午（2.5h）：传统I/O流程详解
├── Day 1下午（2.5h）：DMA与CPU拷贝
├── Day 2上午（2.5h）：上下文切换分析
└── Day 2下午（2.5h）：性能瓶颈测量
```

#### 传统I/O的数据流程

```cpp
/*
 * 传统文件发送流程（read + write）：
 *
 * 场景：将磁盘上的文件通过socket发送给客户端
 *
 * 代码模式：
 * char buffer[8192];
 * while ((n = read(file_fd, buffer, sizeof(buffer))) > 0) {
 *     write(socket_fd, buffer, n);
 * }
 *
 * 数据流路径（4次拷贝 + 4次上下文切换）：
 *
 * ┌─────────────────────────────────────────────────────────────────┐
 * │                        用户空间                                 │
 * │                                                                 │
 * │                    ┌─────────────────┐                         │
 * │                    │   用户缓冲区     │                         │
 * │                    │   buffer[8192]  │                         │
 * │                    └────────┬────────┘                         │
 * │                             │                                   │
 * │           ┌─────────────────┼─────────────────┐                │
 * │           │ ②CPU拷贝       │ ③CPU拷贝       │                │
 * │           │ (read返回)      │ (write调用)     │                │
 * ├───────────┼─────────────────┼─────────────────┼────────────────┤
 * │           │                 │                 │   内核空间     │
 * │           ▼                 │                 ▼                 │
 * │    ┌─────────────┐          │          ┌─────────────┐         │
 * │    │ Page Cache  │          │          │ Socket缓冲区│         │
 * │    │ (内核缓冲区) │          │          │             │         │
 * │    └──────┬──────┘          │          └──────┬──────┘         │
 * │           │                 │                 │                 │
 * │    ①DMA拷贝               │          ④DMA拷贝              │
 * │           │                 │                 │                 │
 * ├───────────┼─────────────────┼─────────────────┼────────────────┤
 * │           ▼                 │                 ▼   硬件层       │
 * │    ┌─────────────┐                     ┌─────────────┐         │
 * │    │    磁盘     │                     │    网卡     │         │
 * │    └─────────────┘                     └─────────────┘         │
 * └─────────────────────────────────────────────────────────────────┘
 *
 * 详细流程：
 * 1. 应用调用read()，触发系统调用，用户态→内核态（切换1）
 * 2. DMA将数据从磁盘拷贝到Page Cache（拷贝1：DMA）
 * 3. CPU将数据从Page Cache拷贝到用户缓冲区（拷贝2：CPU）
 * 4. read()返回，内核态→用户态（切换2）
 * 5. 应用调用write()，用户态→内核态（切换3）
 * 6. CPU将数据从用户缓冲区拷贝到Socket缓冲区（拷贝3：CPU）
 * 7. write()返回，内核态→用户态（切换4）
 * 8. DMA将数据从Socket缓冲区拷贝到网卡（拷贝4：DMA）
 */
```

#### DMA拷贝 vs CPU拷贝

```cpp
/*
 * DMA（Direct Memory Access）拷贝：
 *
 * 特点：
 * - 由DMA控制器执行，不占用CPU
 * - CPU只需启动DMA，然后可以做其他事
 * - 主要用于设备与内存之间的数据传输
 *
 * DMA工作流程：
 * ┌─────────┐    启动DMA    ┌─────────────┐
 * │   CPU   │──────────────▶│ DMA控制器   │
 * └─────────┘               └──────┬──────┘
 *      │                          │
 *      │ 继续执行                  │ 数据传输
 *      │ 其他任务                  │
 *      ▼                          ▼
 * ┌─────────┐               ┌─────────────┐
 * │其他工作 │               │ 内存 ←→ 设备│
 * └─────────┘               └──────┬──────┘
 *      │                          │
 *      │◀─────── 中断通知 ────────┘
 *      ▼
 * ┌─────────┐
 * │处理完成 │
 * └─────────┘
 *
 * CPU拷贝：
 *
 * 特点：
 * - 由CPU执行memcpy操作
 * - 占用CPU周期
 * - 消耗内存带宽
 * - 可能导致缓存污染
 *
 * CPU拷贝开销分析：
 * ┌────────────────────────────────────────────────────┐
 * │  数据大小    │  CPU拷贝时间（估算）  │  带宽消耗   │
 * ├────────────────────────────────────────────────────┤
 * │  1KB         │  ~0.5μs              │  2KB        │
 * │  64KB        │  ~30μs               │  128KB      │
 * │  1MB         │  ~500μs              │  2MB        │
 * │  100MB       │  ~50ms               │  200MB      │
 * └────────────────────────────────────────────────────┘
 *
 * 注意：CPU拷贝实际消耗2倍带宽（读+写）
 */
```

#### 上下文切换开销

```cpp
/*
 * 用户态/内核态切换开销：
 *
 * 每次系统调用的开销：
 * ┌────────────────────────────────────────────────────┐
 * │  操作                    │  时间（典型值）         │
 * ├────────────────────────────────────────────────────┤
 * │  保存用户态寄存器        │  ~50-100 cycles        │
 * │  切换到内核栈            │  ~20-50 cycles         │
 * │  TLB刷新（如需要）       │  ~100-1000 cycles      │
 * │  执行系统调用            │  varies                │
 * │  恢复用户态上下文        │  ~50-100 cycles        │
 * └────────────────────────────────────────────────────┘
 *
 * 典型系统调用开销：~1-5μs
 *
 * 传统I/O的系统调用模式：
 *
 * 用户态: ────┐    ┌────┐    ┌────┐    ┌────
 *             │    │    │    │    │    │
 * 内核态:     └────┘    └────┘    └────┘
 *           read()    write()  read()
 *
 * 每传输一个buffer需要：
 * - 2次系统调用（read + write）
 * - 4次上下文切换
 * - 开销：~2-10μs
 *
 * 发送1GB文件（8KB buffer）：
 * - 131072次read + 131072次write
 * - 262144次系统调用
 * - 系统调用开销：~0.5-1秒
 */
```

#### 示例1：传统I/O拷贝开销测量

```cpp
// 文件：examples/week1/traditional_io_benchmark.cpp
// 功能：测量传统read/write的性能开销
// 编译：g++ -o traditional_io_benchmark traditional_io_benchmark.cpp -O2

#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

/*
 * 传统I/O性能测试：
 *
 * 测试场景：读取文件并写入socket
 * 测量指标：
 * 1. 总耗时
 * 2. 吞吐量（MB/s）
 * 3. 系统调用次数
 */

// 获取时间（微秒）
long long get_time_us() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec * 1000000LL + tv.tv_usec;
}

// 创建测试文件
void create_test_file(const char *path, size_t size) {
    int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) {
        perror("create file");
        exit(1);
    }

    char *buffer = (char *)malloc(1024 * 1024);  // 1MB buffer
    memset(buffer, 'A', 1024 * 1024);

    size_t written = 0;
    while (written < size) {
        size_t to_write = size - written;
        if (to_write > 1024 * 1024) to_write = 1024 * 1024;
        write(fd, buffer, to_write);
        written += to_write;
    }

    free(buffer);
    close(fd);
    printf("创建测试文件: %s (%zu MB)\n", path, size / (1024 * 1024));
}

// 传统read/write方式
void traditional_copy(int in_fd, int out_fd, size_t file_size, size_t buffer_size) {
    char *buffer = (char *)malloc(buffer_size);
    if (!buffer) {
        perror("malloc");
        return;
    }

    size_t total = 0;
    long long syscalls = 0;
    ssize_t n;

    while ((n = read(in_fd, buffer, buffer_size)) > 0) {
        syscalls++;  // read系统调用

        ssize_t written = 0;
        while (written < n) {
            ssize_t w = write(out_fd, buffer + written, n - written);
            if (w <= 0) {
                if (errno == EINTR) continue;
                break;
            }
            written += w;
            syscalls++;  // write系统调用
        }
        total += n;
    }

    free(buffer);
    printf("  传输字节数: %zu\n", total);
    printf("  系统调用数: %lld\n", syscalls);
}

void run_benchmark(const char *file_path, size_t buffer_size) {
    printf("\n=== 测试 buffer_size=%zu ===\n", buffer_size);

    // 打开文件
    int file_fd = open(file_path, O_RDONLY);
    if (file_fd < 0) {
        perror("open file");
        return;
    }

    struct stat st;
    fstat(file_fd, &st);
    size_t file_size = st.st_size;

    // 创建socketpair（模拟网络传输）
    int sv[2];
    if (socketpair(AF_UNIX, SOCK_STREAM, 0, sv) < 0) {
        perror("socketpair");
        close(file_fd);
        return;
    }

    // 设置大的socket缓冲区
    int buf_size = 1024 * 1024;
    setsockopt(sv[0], SOL_SOCKET, SO_SNDBUF, &buf_size, sizeof(buf_size));
    setsockopt(sv[1], SOL_SOCKET, SO_RCVBUF, &buf_size, sizeof(buf_size));

    // 创建接收线程（简单丢弃数据）
    pid_t pid = fork();
    if (pid == 0) {
        // 子进程：接收数据
        close(sv[0]);
        close(file_fd);
        char buf[65536];
        while (read(sv[1], buf, sizeof(buf)) > 0);
        close(sv[1]);
        exit(0);
    }

    close(sv[1]);

    // 测试传统方式
    long long start = get_time_us();
    traditional_copy(file_fd, sv[0], file_size, buffer_size);
    long long elapsed = get_time_us() - start;

    double seconds = elapsed / 1000000.0;
    double throughput = file_size / (1024.0 * 1024.0) / seconds;

    printf("  耗时: %.3f 秒\n", seconds);
    printf("  吞吐量: %.2f MB/s\n", throughput);

    close(sv[0]);
    close(file_fd);

    // 等待子进程
    int status;
    waitpid(pid, &status, 0);
}

int main(int argc, char *argv[]) {
    printf("=== 传统I/O性能测试 ===\n");
    printf("测试传统read/write的4次拷贝开销\n\n");

    // 创建测试文件（100MB）
    const char *test_file = "/tmp/zero_copy_test.dat";
    size_t file_size = 100 * 1024 * 1024;  // 100MB

    create_test_file(test_file, file_size);

    // 不同buffer大小测试
    size_t buffer_sizes[] = {4096, 8192, 16384, 32768, 65536};
    int num_sizes = sizeof(buffer_sizes) / sizeof(buffer_sizes[0]);

    for (int i = 0; i < num_sizes; i++) {
        run_benchmark(test_file, buffer_sizes[i]);
    }

    // 清理
    unlink(test_file);

    printf("\n测试完成\n");
    return 0;
}

/*
 * 运行示例：
 *
 * $ ./traditional_io_benchmark
 * === 传统I/O性能测试 ===
 * 测试传统read/write的4次拷贝开销
 *
 * 创建测试文件: /tmp/zero_copy_test.dat (100 MB)
 *
 * === 测试 buffer_size=4096 ===
 *   传输字节数: 104857600
 *   系统调用数: 51200
 *   耗时: 0.856 秒
 *   吞吐量: 116.82 MB/s
 *
 * === 测试 buffer_size=8192 ===
 *   传输字节数: 104857600
 *   系统调用数: 25600
 *   耗时: 0.623 秒
 *   吞吐量: 160.51 MB/s
 *
 * === 测试 buffer_size=65536 ===
 *   传输字节数: 104857600
 *   系统调用数: 3200
 *   耗时: 0.412 秒
 *   吞吐量: 242.72 MB/s
 *
 * 观察：
 * - buffer越大，系统调用越少，吞吐量越高
 * - 但CPU拷贝开销始终存在
 */
```

#### Day 1-2 自测问答

```
Day 1-2 自测问答：

Q1: 传统read/write发送文件涉及几次数据拷贝？
A1: 4次拷贝：
    1. DMA：磁盘 → Page Cache
    2. CPU：Page Cache → 用户缓冲区
    3. CPU：用户缓冲区 → Socket缓冲区
    4. DMA：Socket缓冲区 → 网卡

Q2: DMA拷贝和CPU拷贝的主要区别是什么？
A2: DMA拷贝由DMA控制器执行，不占用CPU；
    CPU拷贝由CPU执行memcpy，消耗CPU周期和缓存。
    DMA用于设备与内存间，CPU用于内存与内存间。

Q3: 为什么CPU拷贝会消耗"2倍"内存带宽？
A3: CPU拷贝需要先读取源数据，再写入目标位置。
    拷贝1MB数据实际占用2MB的内存带宽。

Q4: 传统I/O发送1GB文件（8KB buffer）需要多少次系统调用？
A4: 约262144次：
    - read调用：1GB / 8KB = 131072次
    - write调用：131072次
    - 总计：262144次系统调用

Q5: 如何减少传统I/O的系统调用次数？
A5: 增大buffer大小。但这只能减少系统调用，
    不能消除CPU拷贝开销。需要零拷贝技术。
```

---

### Day 3-4：零拷贝技术概览（10小时）

#### 学习目标

```
Day 3-4 学习目标：

核心目标：掌握零拷贝技术概览
├── 1. 理解零拷贝的定义和目标
├── 2. 了解Linux零拷贝技术演进
├── 3. 对比sendfile/splice/mmap
├── 4. 理解DMA scatter-gather
└── 5. 了解网卡零拷贝支持

时间分配：
├── Day 3上午（2.5h）：零拷贝定义与目标
├── Day 3下午（2.5h）：Linux零拷贝技术
├── Day 4上午（2.5h）：硬件支持（DMA）
└── Day 4下午（2.5h）：技术对比与选型
```

#### 零拷贝的定义与目标

```cpp
/*
 * 什么是零拷贝（Zero-Copy）？
 *
 * 狭义定义：
 * 完全消除CPU参与的数据拷贝，只保留DMA拷贝。
 *
 * 广义定义：
 * 减少数据拷贝次数，特别是减少CPU拷贝次数。
 *
 * 零拷贝的目标：
 * ┌────────────────────────────────────────────────────────┐
 * │  目标               │  说明                            │
 * ├────────────────────────────────────────────────────────┤
 * │  减少CPU拷贝        │  从2次降到0次                    │
 * │  减少上下文切换      │  从4次降到2次                    │
 * │  减少内存带宽消耗    │  避免无谓的内存访问              │
 * │  提高吞吐量         │  更高效的数据传输                │
 * │  降低CPU使用率      │  CPU可处理其他任务               │
 * └────────────────────────────────────────────────────────┘
 *
 * 零拷贝的理想数据路径：
 *
 * 传统路径（4次拷贝）：
 * 磁盘 ──DMA──▶ Page Cache ──CPU──▶ 用户缓冲 ──CPU──▶ Socket缓冲 ──DMA──▶ 网卡
 *
 * 零拷贝路径（2次拷贝，无CPU拷贝）：
 * 磁盘 ──DMA──▶ Page Cache ──────────────────────────────DMA gather──▶ 网卡
 *                    │
 *                    └──▶ 只传递描述符给Socket缓冲区
 */
```

#### Linux零拷贝技术演进

```cpp
/*
 * Linux零拷贝技术演进历史：
 *
 * ┌────────────────────────────────────────────────────────────────┐
 * │  年份/版本    │  技术           │  说明                        │
 * ├────────────────────────────────────────────────────────────────┤
 * │  1993        │  mmap           │  内存映射，避免read拷贝      │
 * │  Linux 2.2   │  sendfile       │  文件到socket零拷贝          │
 * │  Linux 2.4   │  sendfile+SG-DMA│  真正零拷贝（scatter-gather）│
 * │  Linux 2.6   │  splice         │  任意fd间零拷贝              │
 * │  Linux 2.6   │  vmsplice       │  用户空间到管道零拷贝        │
 * │  Linux 5.1   │  io_uring       │  异步I/O（可配合零拷贝）     │
 * └────────────────────────────────────────────────────────────────┘
 *
 * 各技术的拷贝次数对比：
 *
 * ┌─────────────────────────────────────────────────────────────────┐
 * │  技术           │ 总拷贝 │ CPU拷贝 │ DMA拷贝 │ 上下文切换    │
 * ├─────────────────────────────────────────────────────────────────┤
 * │  read+write     │   4    │    2    │    2    │      4        │
 * │  mmap+write     │   3    │    1    │    2    │      4        │
 * │  sendfile(old)  │   3    │    1    │    2    │      2        │
 * │  sendfile(SG)   │   2    │    0    │    2    │      2        │
 * │  splice         │   2    │    0    │    2    │      2        │
 * └─────────────────────────────────────────────────────────────────┘
 *
 * 注：SG = Scatter-Gather DMA
 */
```

#### 技术对比图

```cpp
/*
 * 各种零拷贝技术对比：
 *
 * 1. mmap + write:
 * ┌─────────┐  DMA   ┌───────────┐  映射   ┌───────────┐
 * │  磁盘   │──────▶│Page Cache │◀───────│用户虚拟地址│
 * └─────────┘        └─────┬─────┘         └───────────┘
 *                          │ CPU拷贝
 *                     ┌────▼────┐
 *                     │Socket缓冲│
 *                     └────┬────┘
 *                          │ DMA
 *                     ┌────▼────┐
 *                     │  网卡   │
 *                     └─────────┘
 * 优点：可以修改数据
 * 缺点：仍有1次CPU拷贝
 *
 * 2. sendfile:
 * ┌─────────┐  DMA   ┌───────────┐
 * │  磁盘   │──────▶│Page Cache │
 * └─────────┘        └─────┬─────┘
 *                          │ 只传递描述符（指针+长度）
 *                     ┌────▼────┐
 *                     │Socket缓冲│
 *                     └────┬────┘
 *                          │ DMA Scatter-Gather
 *                     ┌────▼────┐
 *                     │  网卡   │（从Page Cache直接读取）
 *                     └─────────┘
 * 优点：真正零CPU拷贝
 * 缺点：只能file→socket，不能修改数据
 *
 * 3. splice:
 * ┌─────────┐        ┌───────────┐        ┌─────────┐
 * │ socket1 │──────▶│   管道    │──────▶│ socket2 │
 * └─────────┘ splice └───────────┘ splice └─────────┘
 *                 （只移动页面引用）
 * 优点：任意fd间转发
 * 缺点：需要管道中转
 */
```

#### DMA Scatter-Gather

```cpp
/*
 * DMA Scatter-Gather（分散-聚集）技术：
 *
 * 传统DMA：
 * ┌────────────────────────────┐
 * │      连续物理内存          │
 * │  [data block............] │
 * └────────────┬───────────────┘
 *              │
 *              ▼ 单次DMA传输
 *         ┌─────────┐
 *         │  设备   │
 *         └─────────┘
 *
 * Scatter-Gather DMA：
 * ┌────────┐  ┌────────┐  ┌────────┐
 * │ 页面1  │  │ 页面2  │  │ 页面3  │  （不连续物理内存）
 * └───┬────┘  └───┬────┘  └───┬────┘
 *     │           │           │
 *     └───────────┼───────────┘
 *                 │
 *          ┌──────▼──────┐
 *          │ SG描述符表  │
 *          │ addr1, len1 │
 *          │ addr2, len2 │
 *          │ addr3, len3 │
 *          └──────┬──────┘
 *                 │ 单次DMA传输
 *                 ▼
 *            ┌─────────┐
 *            │  设备   │
 *            └─────────┘
 *
 * Scatter-Gather的优势：
 * 1. 无需连续物理内存
 * 2. 减少内存拷贝
 * 3. 支持零拷贝sendfile
 *
 * 检查网卡是否支持：
 * $ ethtool -k eth0 | grep scatter-gather
 * scatter-gather: on
 */
```

#### 示例2：零拷贝特性检测

```cpp
// 文件：examples/week1/zero_copy_detect.cpp
// 功能：检测系统的零拷贝支持情况
// 编译：g++ -o zero_copy_detect zero_copy_detect.cpp

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/utsname.h>
#include <fcntl.h>
#include <sys/sendfile.h>

/*
 * 零拷贝特性检测：
 *
 * 检查项目：
 * 1. 内核版本（决定支持哪些系统调用）
 * 2. sendfile支持
 * 3. splice支持
 * 4. vmsplice支持
 * 5. 网卡scatter-gather支持
 */

// 检查内核版本
void check_kernel_version() {
    struct utsname uts;
    if (uname(&uts) == 0) {
        printf("内核版本: %s %s\n", uts.sysname, uts.release);

        int major, minor, patch;
        if (sscanf(uts.release, "%d.%d.%d", &major, &minor, &patch) >= 2) {
            printf("\n零拷贝特性支持情况:\n");

            // sendfile: Linux 2.2+
            printf("  sendfile: %s (Linux 2.2+)\n",
                   (major > 2 || (major == 2 && minor >= 2)) ? "✓ 支持" : "✗ 不支持");

            // sendfile with SG-DMA: Linux 2.4+
            printf("  sendfile + Scatter-Gather: %s (Linux 2.4+)\n",
                   (major > 2 || (major == 2 && minor >= 4)) ? "✓ 支持" : "✗ 不支持");

            // splice: Linux 2.6.17+
            printf("  splice: %s (Linux 2.6.17+)\n",
                   (major > 2 || (major == 2 && minor >= 6)) ? "✓ 支持" : "✗ 不支持");

            // vmsplice: Linux 2.6.17+
            printf("  vmsplice: %s (Linux 2.6.17+)\n",
                   (major > 2 || (major == 2 && minor >= 6)) ? "✓ 支持" : "✗ 不支持");

            // io_uring: Linux 5.1+
            printf("  io_uring: %s (Linux 5.1+)\n",
                   (major > 5 || (major == 5 && minor >= 1)) ? "✓ 支持" : "✗ 不支持");
        }
    }
}

// 检查sendfile是否可用
void check_sendfile() {
    printf("\n检查sendfile...\n");

    // 创建测试文件
    const char *test_file = "/tmp/sendfile_test.txt";
    int file_fd = open(test_file, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (file_fd < 0) {
        printf("  无法创建测试文件\n");
        return;
    }
    write(file_fd, "test", 4);
    close(file_fd);

    // 创建socketpair
    int sv[2];
    if (socketpair(AF_UNIX, SOCK_STREAM, 0, sv) < 0) {
        printf("  无法创建socketpair\n");
        unlink(test_file);
        return;
    }

    // 测试sendfile
    file_fd = open(test_file, O_RDONLY);
    off_t offset = 0;
    ssize_t sent = sendfile(sv[0], file_fd, &offset, 4);

    if (sent == 4) {
        printf("  sendfile: ✓ 工作正常\n");
    } else {
        printf("  sendfile: ✗ 失败\n");
    }

    close(file_fd);
    close(sv[0]);
    close(sv[1]);
    unlink(test_file);
}

// 检查splice是否可用
void check_splice() {
    printf("\n检查splice...\n");

    int pipefd[2];
    if (pipe(pipefd) < 0) {
        printf("  无法创建管道\n");
        return;
    }

    int sv[2];
    if (socketpair(AF_UNIX, SOCK_STREAM, 0, sv) < 0) {
        printf("  无法创建socketpair\n");
        close(pipefd[0]);
        close(pipefd[1]);
        return;
    }

    // 写入测试数据
    write(sv[0], "test", 4);

    // 测试splice: socket → pipe
    ssize_t n = splice(sv[1], NULL, pipefd[1], NULL, 4, SPLICE_F_MOVE);
    if (n == 4) {
        printf("  splice (socket→pipe): ✓ 工作正常\n");
    } else {
        printf("  splice (socket→pipe): ✗ 失败\n");
    }

    close(pipefd[0]);
    close(pipefd[1]);
    close(sv[0]);
    close(sv[1]);
}

// 显示页面大小
void show_page_size() {
    printf("\n内存页面信息:\n");
    long page_size = sysconf(_SC_PAGESIZE);
    printf("  页面大小: %ld 字节 (%ld KB)\n", page_size, page_size / 1024);

    long phys_pages = sysconf(_SC_PHYS_PAGES);
    printf("  物理页面数: %ld\n", phys_pages);
    printf("  总物理内存: %.2f GB\n",
           (double)phys_pages * page_size / (1024.0 * 1024.0 * 1024.0));
}

// 显示管道缓冲区大小
void show_pipe_buffer() {
    printf("\n管道缓冲区信息:\n");

    int pipefd[2];
    if (pipe(pipefd) == 0) {
        int size = fcntl(pipefd[0], F_GETPIPE_SZ);
        printf("  默认管道缓冲区: %d 字节 (%d KB)\n", size, size / 1024);

        // 尝试获取最大值
        FILE *f = fopen("/proc/sys/fs/pipe-max-size", "r");
        if (f) {
            int max_size;
            if (fscanf(f, "%d", &max_size) == 1) {
                printf("  最大管道缓冲区: %d 字节 (%d MB)\n",
                       max_size, max_size / (1024 * 1024));
            }
            fclose(f);
        }

        close(pipefd[0]);
        close(pipefd[1]);
    }
}

int main() {
    printf("=== 零拷贝特性检测工具 ===\n\n");

    check_kernel_version();
    show_page_size();
    show_pipe_buffer();
    check_sendfile();
    check_splice();

    printf("\n检测完成\n");
    return 0;
}

/*
 * 运行示例：
 *
 * $ ./zero_copy_detect
 * === 零拷贝特性检测工具 ===
 *
 * 内核版本: Linux 5.15.0-generic
 *
 * 零拷贝特性支持情况:
 *   sendfile: ✓ 支持 (Linux 2.2+)
 *   sendfile + Scatter-Gather: ✓ 支持 (Linux 2.4+)
 *   splice: ✓ 支持 (Linux 2.6.17+)
 *   vmsplice: ✓ 支持 (Linux 2.6.17+)
 *   io_uring: ✓ 支持 (Linux 5.1+)
 *
 * 内存页面信息:
 *   页面大小: 4096 字节 (4 KB)
 *   物理页面数: 4194304
 *   总物理内存: 16.00 GB
 *
 * 管道缓冲区信息:
 *   默认管道缓冲区: 65536 字节 (64 KB)
 *   最大管道缓冲区: 1048576 字节 (1 MB)
 *
 * 检查sendfile...
 *   sendfile: ✓ 工作正常
 *
 * 检查splice...
 *   splice (socket→pipe): ✓ 工作正常
 *
 * 检测完成
 */
```

#### Day 3-4 自测问答

```
Day 3-4 自测问答：

Q1: 零拷贝的核心目标是什么？
A1: 减少或消除CPU参与的数据拷贝，降低CPU使用率，
    提高数据传输吞吐量。理想情况下只保留DMA拷贝。

Q2: sendfile和splice的主要区别是什么？
A2: sendfile只能从文件fd发送到socket fd；
    splice可以在任意fd之间传输（需要一端是管道）。
    splice更灵活，可用于socket到socket的转发。

Q3: 为什么sendfile需要网卡支持Scatter-Gather DMA？
A3: 没有SG-DMA时，sendfile需要将Page Cache拷贝到
    Socket缓冲区（1次CPU拷贝）。
    有SG-DMA时，网卡可以直接从Page Cache读取数据。

Q4: mmap方式相比传统read/write减少了什么？
A4: 减少了read的CPU拷贝（Page Cache→用户缓冲区）。
    用户直接访问映射的Page Cache。
    但write仍需CPU拷贝到Socket缓冲区。

Q5: Linux 2.4和Linux 2.6在零拷贝方面有什么改进？
A5: Linux 2.4：sendfile支持Scatter-Gather DMA，实现真正零拷贝
    Linux 2.6：引入splice/vmsplice，支持任意fd间零拷贝
```

---

### Day 5-7：Linux内存管理基础（15小时）

#### 学习目标

```
Day 5-7 学习目标：

核心目标：理解零拷贝相关的内存管理
├── 1. 理解虚拟内存与物理内存
├── 2. 理解页表与地址映射
├── 3. 理解Page Cache机制
├── 4. 理解内存映射原理
└── 5. 能分析进程的内存映射

时间分配：
├── Day 5上午（2.5h）：虚拟内存基础
├── Day 5下午（2.5h）：页表与映射
├── Day 6上午（2.5h）：Page Cache
├── Day 6下午（2.5h）：内存映射原理
├── Day 7上午（2.5h）：/proc/pid/maps分析
└── Day 7下午（2.5h）：综合练习
```

#### 虚拟内存与物理内存

```cpp
/*
 * 虚拟内存机制：
 *
 * 每个进程有独立的虚拟地址空间：
 *
 * 进程A虚拟空间          物理内存            进程B虚拟空间
 * ┌─────────────┐                          ┌─────────────┐
 * │    栈       │                          │    栈       │
 * │    ↓        │                          │    ↓        │
 * │             │       ┌─────────┐        │             │
 * │             │ ┌────▶│ 物理页1 │◀────┐  │             │
 * │    ↑        │ │     ├─────────┤     │  │    ↑        │
 * │    堆       │ │     │ 物理页2 │     │  │    堆       │
 * ├─────────────┤ │     ├─────────┤     │  ├─────────────┤
 * │    BSS      │ │     │ 物理页3 │     │  │    BSS      │
 * ├─────────────┤ │     ├─────────┤     │  ├─────────────┤
 * │   数据段    │─┘     │   ...   │     └──│   数据段    │
 * ├─────────────┤       ├─────────┤        ├─────────────┤
 * │   代码段    │──────▶│ 共享库  │◀───────│   代码段    │
 * └─────────────┘       └─────────┘        └─────────────┘
 *   0x00000000            物理地址           0x00000000
 *      ↓                                        ↓
 *   0xFFFFFFFF                              0xFFFFFFFF
 *
 * 关键概念：
 * 1. 每个进程认为自己独占整个地址空间
 * 2. 虚拟地址通过页表映射到物理地址
 * 3. 相同虚拟地址可映射到不同物理地址
 * 4. 共享库可被多个进程共享（同一物理页）
 */
```

#### Page Cache机制

```cpp
/*
 * Page Cache（页面缓存）：
 *
 * Page Cache是内核管理的磁盘缓存：
 *
 * ┌─────────────────────────────────────────────────────┐
 * │                    用户空间                          │
 * │  ┌─────────┐                                        │
 * │  │ 用户程序 │                                        │
 * │  └────┬────┘                                        │
 * │       │ read()/write()                              │
 * ├───────┼─────────────────────────────────────────────┤
 * │       │                     内核空间                 │
 * │       ▼                                             │
 * │  ┌─────────────────────────────────────────────┐   │
 * │  │              Page Cache                      │   │
 * │  │  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐  │   │
 * │  │  │Page1│ │Page2│ │Page3│ │Page4│ │Page5│  │   │
 * │  │  │file1│ │file1│ │file2│ │file2│ │file3│  │   │
 * │  │  └─────┘ └─────┘ └─────┘ └─────┘ └─────┘  │   │
 * │  └──────────────────────┬──────────────────────┘   │
 * │                         │                          │
 * ├─────────────────────────┼──────────────────────────┤
 * │                         │ 磁盘I/O                   │
 * │                         ▼                          │
 * │                    ┌─────────┐                     │
 * │                    │  磁盘   │                     │
 * │                    └─────────┘                     │
 * └─────────────────────────────────────────────────────┘
 *
 * Page Cache的作用：
 * 1. 缓存磁盘数据，减少磁盘I/O
 * 2. 支持零拷贝（sendfile直接从Page Cache发送）
 * 3. 支持mmap（直接映射Page Cache到用户空间）
 *
 * Page Cache与零拷贝的关系：
 * - 传统I/O：Page Cache → 用户缓冲区（CPU拷贝）
 * - sendfile：直接从Page Cache → 网卡（无CPU拷贝）
 * - mmap：用户直接访问Page Cache
 */
```

#### 示例3：查看进程内存映射

```cpp
// 文件：examples/week1/memory_mapping_viewer.cpp
// 功能：查看进程的内存映射和Page Cache使用
// 编译：g++ -o memory_mapping_viewer memory_mapping_viewer.cpp

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>

/*
 * /proc/[pid]/maps 格式：
 * address           perms offset  dev   inode      pathname
 * 00400000-00452000 r-xp 00000000 08:02 173521     /usr/bin/foo
 *
 * perms:
 * r = 读
 * w = 写
 * x = 执行
 * p = 私有(COW) / s = 共享
 */

void show_self_maps() {
    printf("=== 当前进程内存映射 (/proc/self/maps) ===\n\n");

    FILE *f = fopen("/proc/self/maps", "r");
    if (!f) {
        perror("打开/proc/self/maps失败");
        return;
    }

    char line[512];
    printf("%-20s %-5s %-10s %-6s %-10s %s\n",
           "地址范围", "权限", "偏移", "设备", "inode", "路径");
    printf("%-20s %-5s %-10s %-6s %-10s %s\n",
           "----", "----", "----", "----", "----", "----");

    while (fgets(line, sizeof(line), f)) {
        printf("%s", line);
    }

    fclose(f);
}

void demonstrate_mmap() {
    printf("\n=== mmap演示 ===\n\n");

    // 创建测试文件
    const char *test_file = "/tmp/mmap_test.txt";
    const char *content = "Hello, this is mmap test content!\n";

    int fd = open(test_file, O_RDWR | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) {
        perror("创建文件失败");
        return;
    }
    write(fd, content, strlen(content));
    close(fd);

    // 重新打开并mmap
    fd = open(test_file, O_RDONLY);
    struct stat st;
    fstat(fd, &st);

    printf("文件大小: %ld 字节\n", st.st_size);

    // mmap文件
    void *addr = mmap(NULL, st.st_size, PROT_READ, MAP_PRIVATE, fd, 0);
    if (addr == MAP_FAILED) {
        perror("mmap失败");
        close(fd);
        return;
    }

    printf("mmap地址: %p\n", addr);
    printf("映射内容: %s", (char *)addr);

    // 显示映射后的maps
    printf("\n映射后的内存区域:\n");
    char cmd[256];
    snprintf(cmd, sizeof(cmd),
             "grep '%s' /proc/self/maps", test_file);
    system(cmd);

    // 清理
    munmap(addr, st.st_size);
    close(fd);
    unlink(test_file);
}

void show_page_cache_usage() {
    printf("\n=== Page Cache使用情况 ===\n\n");

    FILE *f = fopen("/proc/meminfo", "r");
    if (!f) {
        perror("打开/proc/meminfo失败");
        return;
    }

    char line[256];
    while (fgets(line, sizeof(line), f)) {
        if (strstr(line, "Cached:") ||
            strstr(line, "Buffers:") ||
            strstr(line, "MemTotal:") ||
            strstr(line, "MemFree:") ||
            strstr(line, "MemAvailable:")) {
            printf("%s", line);
        }
    }

    fclose(f);
}

int main() {
    printf("=== 内存映射查看工具 ===\n\n");

    show_self_maps();
    demonstrate_mmap();
    show_page_cache_usage();

    printf("\n完成\n");
    return 0;
}

/*
 * 运行示例：
 *
 * $ ./memory_mapping_viewer
 * === 当前进程内存映射 (/proc/self/maps) ===
 *
 * 地址范围             权限  偏移       设备   inode      路径
 * ----                 ----  ----       ----   ----       ----
 * 559d3b400000-559d3b401000 r--p 00000000 08:02 1234567 /path/to/program
 * 559d3b401000-559d3b402000 r-xp 00001000 08:02 1234567 /path/to/program
 * ...
 * 7f8a12000000-7f8a12021000 r--p 00000000 08:02 7654321 /lib/x86_64-linux-gnu/libc.so.6
 * ...
 *
 * === mmap演示 ===
 *
 * 文件大小: 35 字节
 * mmap地址: 0x7f8a11fff000
 * 映射内容: Hello, this is mmap test content!
 *
 * 映射后的内存区域:
 * 7f8a11fff000-7f8a12000000 r--p 00000000 08:02 9876543 /tmp/mmap_test.txt
 *
 * === Page Cache使用情况 ===
 *
 * MemTotal:       16384000 kB
 * MemFree:         8192000 kB
 * MemAvailable:   12288000 kB
 * Buffers:          256000 kB
 * Cached:          4096000 kB
 */
```

#### 示例4：Page Cache预热与测量

```cpp
// 文件：examples/week1/page_cache_warmup.cpp
// 功能：演示Page Cache预热对读取性能的影响
// 编译：g++ -o page_cache_warmup page_cache_warmup.cpp -O2

#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*
 * Page Cache对读取性能的影响：
 *
 * 冷读取（Cold Read）：数据不在Page Cache中
 * - 需要从磁盘读取
 * - 速度：~100-200 MB/s（HDD）或 ~500-3000 MB/s（SSD）
 *
 * 热读取（Hot Read）：数据已在Page Cache中
 * - 直接从内存读取
 * - 速度：~5000-20000 MB/s（取决于内存带宽）
 */

long long get_time_us() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec * 1000000LL + tv.tv_usec;
}

// 清除Page Cache（需要root）
void drop_caches() {
    printf("尝试清除Page Cache...\n");
    sync();
    int fd = open("/proc/sys/vm/drop_caches", O_WRONLY);
    if (fd >= 0) {
        write(fd, "3", 1);
        close(fd);
        printf("Page Cache已清除\n");
    } else {
        printf("无法清除Page Cache（需要root权限）\n");
    }
}

// 读取文件并测量时间
double read_file_measure(const char *path, bool use_direct) {
    int flags = O_RDONLY;
    if (use_direct) {
        flags |= O_DIRECT;
    }

    int fd = open(path, flags);
    if (fd < 0) {
        perror("open");
        return -1;
    }

    struct stat st;
    fstat(fd, &st);
    size_t file_size = st.st_size;

    // 对齐缓冲区（O_DIRECT需要）
    void *buffer;
    posix_memalign(&buffer, 4096, 1024 * 1024);

    long long start = get_time_us();

    size_t total = 0;
    ssize_t n;
    while ((n = read(fd, buffer, 1024 * 1024)) > 0) {
        total += n;
    }

    long long elapsed = get_time_us() - start;

    free(buffer);
    close(fd);

    double seconds = elapsed / 1000000.0;
    double throughput = total / (1024.0 * 1024.0) / seconds;

    return throughput;
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("用法: %s <文件路径>\n", argv[0]);
        printf("示例: %s /tmp/large_file.dat\n", argv[0]);
        printf("\n建议使用100MB以上的文件进行测试\n");
        return 1;
    }

    const char *file_path = argv[1];

    printf("=== Page Cache性能测试 ===\n");
    printf("测试文件: %s\n\n", file_path);

    // 第一次读取（可能是冷读取）
    printf("第一次读取...\n");
    double throughput1 = read_file_measure(file_path, false);
    printf("吞吐量: %.2f MB/s\n\n", throughput1);

    // 第二次读取（热读取，数据应该在Page Cache中）
    printf("第二次读取（数据应在Page Cache中）...\n");
    double throughput2 = read_file_measure(file_path, false);
    printf("吞吐量: %.2f MB/s\n\n", throughput2);

    // 尝试清除Page Cache并再次读取
    drop_caches();
    printf("\n清除后第一次读取...\n");
    double throughput3 = read_file_measure(file_path, false);
    printf("吞吐量: %.2f MB/s\n\n", throughput3);

    // 总结
    printf("=== 总结 ===\n");
    printf("热读取 vs 冷读取 性能比: %.2fx\n", throughput2 / throughput3);

    return 0;
}

/*
 * 运行示例：
 *
 * # 创建测试文件
 * $ dd if=/dev/zero of=/tmp/large_file.dat bs=1M count=500
 *
 * # 运行测试
 * $ ./page_cache_warmup /tmp/large_file.dat
 * === Page Cache性能测试 ===
 * 测试文件: /tmp/large_file.dat
 *
 * 第一次读取...
 * 吞吐量: 2500.00 MB/s  （可能已在缓存中）
 *
 * 第二次读取（数据应在Page Cache中）...
 * 吞吐量: 8500.00 MB/s  （热读取）
 *
 * 尝试清除Page Cache...
 * Page Cache已清除
 *
 * 清除后第一次读取...
 * 吞吐量: 450.00 MB/s   （冷读取，从SSD）
 *
 * === 总结 ===
 * 热读取 vs 冷读取 性能比: 18.89x
 */
```

#### Day 5-7 自测问答

```
Day 5-7 自测问答：

Q1: 什么是Page Cache？它与零拷贝有什么关系？
A1: Page Cache是内核管理的磁盘缓存，文件数据首先读入Page Cache。
    零拷贝技术（如sendfile）可以直接从Page Cache发送数据到网卡，
    避免拷贝到用户空间。

Q2: mmap如何实现"减少拷贝"？
A2: mmap将文件的Page Cache直接映射到用户虚拟地址空间。
    用户访问映射地址时，直接访问的是Page Cache，
    不需要read()的拷贝操作。

Q3: 如何查看进程的内存映射？
A3: 查看 /proc/[pid]/maps 文件，显示所有内存区域的：
    - 地址范围
    - 权限（r/w/x/p/s）
    - 映射的文件（如果有）

Q4: Page Cache的热读取和冷读取性能差多少？
A4: 热读取（内存）：5000-20000 MB/s
    冷读取（SSD）：500-3000 MB/s
    冷读取（HDD）：100-200 MB/s
    热读取比冷读取快5-100倍。

Q5: 为什么零拷贝需要理解内存管理？
A5: 零拷贝技术的核心是操作内存页面引用，而非复制数据：
    - sendfile：传递Page Cache的页面描述符
    - splice：移动管道缓冲区的页面引用
    - mmap：建立虚拟地址到Page Cache的映射
    理解内存管理才能理解零拷贝的工作原理。
```

---

### 第一周检验标准

```
第一周自我检验清单：

理论理解：
☐ 能画出传统I/O的4次拷贝数据流图
☐ 能区分DMA拷贝和CPU拷贝
☐ 能解释上下文切换的开销
☐ 能说出各种零拷贝技术的拷贝次数
☐ 理解Scatter-Gather DMA的作用
☐ 理解Page Cache在零拷贝中的角色
☐ 能解释mmap如何减少拷贝
☐ 理解虚拟内存与物理内存的关系

实践能力：
☐ 能编写传统I/O性能测试程序
☐ 能检测系统的零拷贝特性支持
☐ 能查看和分析/proc/pid/maps
☐ 能测量Page Cache的性能影响
☐ 能使用dd和sync测试磁盘I/O
☐ 能清除Page Cache进行冷读测试
```

---

## 第二周：sendfile系统调用（Day 8-14）

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     第二周学习路线图                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Day 8-9                    Day 10-11                   Day 12-14          │
│  ┌─────────────────┐       ┌─────────────────┐        ┌─────────────────┐  │
│  │ sendfile原理    │──────▶│ sendfile实践    │───────▶│ sendfile优化    │  │
│  │                 │       │                 │        │                 │  │
│  │ • 系统调用签名  │       │ • 基本使用      │        │ • TCP_CORK      │  │
│  │ • 2次拷贝流程   │       │ • 大文件分块    │        │ • writev组合    │  │
│  │ • DMA gather    │       │ • 非阻塞处理    │        │ • Nginx分析     │  │
│  │ • 版本演进      │       │ • 错误处理      │        │ • 文件服务器    │  │
│  └─────────────────┘       └─────────────────┘        └─────────────────┘  │
│           │                        │                          │             │
│           ▼                        ▼                          ▼             │
│    [示例5: 基本]            [示例6-7: 分块]           [示例8-11: 优化]     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### Day 8-9：sendfile原理详解（10小时）

#### sendfile系统调用概述

sendfile是Linux 2.2引入的零拷贝系统调用，专门用于在两个文件描述符之间传输数据，
无需经过用户空间，可以显著提升文件传输性能。

```
sendfile系统调用签名：

#include <sys/sendfile.h>

ssize_t sendfile(int out_fd,      // 输出文件描述符（通常是socket）
                 int in_fd,        // 输入文件描述符（必须是文件）
                 off_t *offset,    // 输入文件偏移量（可选）
                 size_t count);    // 要传输的字节数

返回值：
- 成功：返回实际传输的字节数
- 失败：返回-1，设置errno

重要限制：
- in_fd 必须支持mmap（必须是普通文件或块设备）
- out_fd 在Linux 2.6.33之前必须是socket
- out_fd 从Linux 2.6.33开始可以是任何文件描述符

offset参数说明：
- 如果offset非NULL：从*offset位置读取，传输后更新*offset
- 如果offset为NULL：从文件当前位置读取，会更新文件偏移量
```

#### sendfile的数据流与拷贝次数

```
传统read/write的4次拷贝：

┌──────────────┐
│   磁盘文件    │
└──────┬───────┘
       │ ① DMA拷贝（磁盘→内核缓冲区）
       ▼
┌──────────────┐
│  内核缓冲区   │ (Page Cache)
└──────┬───────┘
       │ ② CPU拷贝（内核→用户）
       ▼
┌──────────────┐      用户空间
│  用户缓冲区   │ ─────────────
└──────┬───────┘      内核空间
       │ ③ CPU拷贝（用户→内核）
       ▼
┌──────────────┐
│ Socket缓冲区 │
└──────┬───────┘
       │ ④ DMA拷贝（内核缓冲区→网卡）
       ▼
┌──────────────┐
│    网卡       │
└──────────────┘

上下文切换：4次（read进入内核、read返回、write进入内核、write返回）
数据拷贝：4次（2次DMA + 2次CPU）


sendfile的2-3次拷贝（取决于硬件支持）：

不支持DMA Scatter-Gather的情况（3次拷贝）：

┌──────────────┐
│   磁盘文件    │
└──────┬───────┘
       │ ① DMA拷贝（磁盘→内核缓冲区）
       ▼
┌──────────────┐
│  内核缓冲区   │ (Page Cache)
└──────┬───────┘
       │ ② CPU拷贝（内核缓冲区→Socket缓冲区）
       ▼
┌──────────────┐
│ Socket缓冲区 │
└──────┬───────┘
       │ ③ DMA拷贝（Socket缓冲区→网卡）
       ▼
┌──────────────┐
│    网卡       │
└──────────────┘

上下文切换：2次（sendfile进入内核、sendfile返回）
数据拷贝：3次（2次DMA + 1次CPU）


支持DMA Scatter-Gather的情况（2次拷贝，真正的零拷贝）：

┌──────────────┐
│   磁盘文件    │
└──────┬───────┘
       │ ① DMA拷贝（磁盘→内核缓冲区）
       ▼
┌──────────────┐
│  内核缓冲区   │ (Page Cache)
│              │───┐
└──────────────┘   │ 只传递页面描述符（包含位置和长度）
                   │
┌──────────────┐   │
│ Socket缓冲区 │◀──┘ 不存储数据，只存储指针
└──────┬───────┘
       │ ② DMA Scatter-Gather（直接从内核缓冲区到网卡）
       ▼
┌──────────────┐
│    网卡       │
└──────────────┘

上下文切换：2次
数据拷贝：2次（仅DMA，无CPU拷贝）
```

#### DMA Scatter-Gather机制详解

```
DMA Scatter-Gather 原理：

传统DMA：只能操作连续的内存区域
┌────────────────────────────────┐
│          连续内存块             │
│  ┌─────────────────────────┐  │
│  │  数据必须连续存放        │  │
│  └─────────────────────────┘  │
└────────────────────────────────┘
                │
                ▼ DMA传输
┌────────────────────────────────┐
│            网卡                 │
└────────────────────────────────┘


Scatter-Gather DMA：可以操作分散的内存区域

┌────────────────────────────────────────────────────┐
│                 物理内存                            │
│  ┌────────┐    ┌────────┐    ┌────────┐           │
│  │ 页面1  │    │ 页面2  │    │ 页面3  │   ...     │
│  │ (4KB)  │    │ (4KB)  │    │ (4KB)  │           │
│  └───┬────┘    └───┬────┘    └───┬────┘           │
│      │             │             │                 │
│      └─────────────┼─────────────┘                 │
│                    │                               │
│           ┌────────▼────────┐                      │
│           │  Scatter-Gather │                      │
│           │     列表        │                      │
│           │ ┌─────────────┐ │                      │
│           │ │页面1: addr1 │ │                      │
│           │ │len: 4096    │ │                      │
│           │ ├─────────────┤ │                      │
│           │ │页面2: addr2 │ │                      │
│           │ │len: 4096    │ │                      │
│           │ ├─────────────┤ │                      │
│           │ │页面3: addr3 │ │                      │
│           │ │len: 2048    │ │                      │
│           │ └─────────────┘ │                      │
│           └────────┬────────┘                      │
└────────────────────┼───────────────────────────────┘
                     │ DMA一次性读取所有分散的页面
                     ▼
           ┌─────────────────┐
           │      网卡       │
           │  单次DMA传输    │
           │  收集所有数据    │
           └─────────────────┘

优势：
1. 无需将分散的页面复制到连续内存
2. 减少一次CPU拷贝
3. 支持零拷贝sendfile
4. 减少内存带宽占用
```

#### Linux sendfile版本演进

```
Linux sendfile 版本演进历史：

┌─────────────────────────────────────────────────────────────────────────────┐
│ 版本     │ 特性                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│ 2.2      │ sendfile首次引入                                                 │
│          │ - 只能用于socket到文件的传输                                     │
│          │ - 需要CPU将数据从Page Cache复制到Socket缓冲区                    │
├─────────────────────────────────────────────────────────────────────────────┤
│ 2.4      │ 引入DMA Scatter-Gather支持                                       │
│          │ - 真正的零拷贝（如果硬件支持）                                   │
│          │ - 只传递文件描述符和长度，无数据拷贝                             │
│          │ - 需要网卡支持Scatter-Gather DMA                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│ 2.6.33   │ 放宽out_fd限制                                                   │
│          │ - out_fd可以是任何文件描述符                                     │
│          │ - 支持文件到文件的传输                                           │
│          │ - sendfile可用于普通文件复制                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│ 3.0+     │ 性能优化和bug修复                                                │
│          │ - 优化大文件传输                                                 │
│          │ - 修复边界条件                                                   │
└─────────────────────────────────────────────────────────────────────────────┘

检测Scatter-Gather支持：
$ ethtool -k eth0 | grep scatter-gather
scatter-gather: on
    tx-scatter-gather: on
    tx-scatter-gather-fraglist: off

现代网卡基本都支持Scatter-Gather DMA。
```

#### 示例5：sendfile基本使用

```cpp
// sendfile_basic.cpp
// 示例5：sendfile基本文件发送
// 编译：g++ -std=c++17 -O2 -o sendfile_basic sendfile_basic.cpp

#include <sys/sendfile.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <unistd.h>
#include <cstdio>
#include <cstring>
#include <cerrno>
#include <string>

class SendfileDemo {
public:
    // 使用sendfile发送整个文件
    static ssize_t send_entire_file(int socket_fd, const char* filename) {
        // 打开文件
        int file_fd = open(filename, O_RDONLY);
        if (file_fd < 0) {
            perror("open failed");
            return -1;
        }

        // 获取文件大小
        struct stat st;
        if (fstat(file_fd, &st) < 0) {
            perror("fstat failed");
            close(file_fd);
            return -1;
        }

        size_t file_size = st.st_size;
        printf("File size: %zu bytes\n", file_size);

        // 使用sendfile发送
        // offset为NULL表示从当前文件偏移量开始
        off_t offset = 0;
        ssize_t sent = 0;
        ssize_t total_sent = 0;

        while (total_sent < (ssize_t)file_size) {
            // sendfile可能不会一次发送所有数据
            // 特别是在非阻塞模式或发送大文件时
            sent = sendfile(socket_fd, file_fd, &offset, file_size - total_sent);

            if (sent < 0) {
                if (errno == EAGAIN || errno == EWOULDBLOCK) {
                    // 非阻塞模式下，稍后重试
                    printf("Socket buffer full, sent so far: %zd\n", total_sent);
                    usleep(1000);  // 等待1ms
                    continue;
                }
                perror("sendfile failed");
                close(file_fd);
                return -1;
            }

            if (sent == 0) {
                // 到达文件末尾
                break;
            }

            total_sent += sent;
            printf("Sent %zd bytes, total: %zd/%zu\n", sent, total_sent, file_size);
        }

        close(file_fd);
        printf("Total sent: %zd bytes\n", total_sent);
        return total_sent;
    }

    // 发送文件的指定范围（支持HTTP Range请求）
    static ssize_t send_file_range(int socket_fd, const char* filename,
                                   off_t start, size_t length) {
        int file_fd = open(filename, O_RDONLY);
        if (file_fd < 0) {
            perror("open failed");
            return -1;
        }

        // 验证范围
        struct stat st;
        fstat(file_fd, &st);

        if (start >= st.st_size) {
            fprintf(stderr, "Start offset beyond file size\n");
            close(file_fd);
            return -1;
        }

        // 调整长度以不超出文件
        if (start + (off_t)length > st.st_size) {
            length = st.st_size - start;
        }

        printf("Sending range: %ld-%zu (length: %zu)\n",
               start, start + length - 1, length);

        // sendfile从指定偏移量开始
        off_t offset = start;
        ssize_t sent = sendfile(socket_fd, file_fd, &offset, length);

        close(file_fd);

        if (sent < 0) {
            perror("sendfile failed");
            return -1;
        }

        printf("Range sent: %zd bytes\n", sent);
        return sent;
    }

    // 对比sendfile和read/write的性能
    static void compare_performance(const char* filename, int socket_fd) {
        struct stat st;
        if (stat(filename, &st) < 0) {
            perror("stat failed");
            return;
        }

        size_t file_size = st.st_size;
        printf("\n=== Performance Comparison ===\n");
        printf("File size: %zu bytes (%.2f MB)\n",
               file_size, file_size / (1024.0 * 1024.0));

        // 方法1：传统read/write
        {
            int file_fd = open(filename, O_RDONLY);
            if (file_fd < 0) return;

            char* buffer = new char[65536];  // 64KB缓冲区

            auto start_time = std::chrono::high_resolution_clock::now();

            ssize_t bytes_read;
            size_t total = 0;
            while ((bytes_read = read(file_fd, buffer, 65536)) > 0) {
                ssize_t bytes_written = 0;
                while (bytes_written < bytes_read) {
                    ssize_t n = write(socket_fd, buffer + bytes_written,
                                      bytes_read - bytes_written);
                    if (n < 0) break;
                    bytes_written += n;
                }
                total += bytes_written;
            }

            auto end_time = std::chrono::high_resolution_clock::now();
            auto duration = std::chrono::duration_cast<std::chrono::microseconds>(
                end_time - start_time);

            double throughput = (file_size / (1024.0 * 1024.0)) /
                               (duration.count() / 1000000.0);

            printf("read/write: %zu bytes in %ld us (%.2f MB/s)\n",
                   total, duration.count(), throughput);

            delete[] buffer;
            close(file_fd);
            lseek(socket_fd, 0, SEEK_SET);  // 重置（如果支持）
        }

        // 方法2：sendfile
        {
            int file_fd = open(filename, O_RDONLY);
            if (file_fd < 0) return;

            auto start_time = std::chrono::high_resolution_clock::now();

            off_t offset = 0;
            ssize_t total = 0;
            ssize_t sent;

            while ((sent = sendfile(socket_fd, file_fd, &offset,
                                    file_size - total)) > 0) {
                total += sent;
            }

            auto end_time = std::chrono::high_resolution_clock::now();
            auto duration = std::chrono::duration_cast<std::chrono::microseconds>(
                end_time - start_time);

            double throughput = (file_size / (1024.0 * 1024.0)) /
                               (duration.count() / 1000000.0);

            printf("sendfile:   %zd bytes in %ld us (%.2f MB/s)\n",
                   total, duration.count(), throughput);

            close(file_fd);
        }
    }
};

// 创建简单的TCP服务器用于测试
int create_server_socket(int port) {
    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        perror("socket failed");
        return -1;
    }

    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(port);

    if (bind(server_fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("bind failed");
        close(server_fd);
        return -1;
    }

    if (listen(server_fd, 5) < 0) {
        perror("listen failed");
        close(server_fd);
        return -1;
    }

    printf("Server listening on port %d\n", port);
    return server_fd;
}

int main(int argc, char* argv[]) {
    if (argc < 3) {
        printf("Usage: %s <filename> <port>\n", argv[0]);
        printf("Example: %s test.txt 8080\n", argv[0]);
        return 1;
    }

    const char* filename = argv[1];
    int port = atoi(argv[2]);

    // 检查文件是否存在
    struct stat st;
    if (stat(filename, &st) < 0) {
        perror("File not found");
        return 1;
    }

    printf("File: %s (%ld bytes)\n", filename, st.st_size);

    int server_fd = create_server_socket(port);
    if (server_fd < 0) return 1;

    printf("Waiting for connection...\n");

    struct sockaddr_in client_addr;
    socklen_t client_len = sizeof(client_addr);
    int client_fd = accept(server_fd, (struct sockaddr*)&client_addr, &client_len);

    if (client_fd < 0) {
        perror("accept failed");
        close(server_fd);
        return 1;
    }

    printf("Client connected: %s:%d\n",
           inet_ntoa(client_addr.sin_addr), ntohs(client_addr.sin_port));

    // 发送整个文件
    ssize_t sent = SendfileDemo::send_entire_file(client_fd, filename);
    printf("Total bytes sent: %zd\n", sent);

    close(client_fd);
    close(server_fd);

    return 0;
}
```

#### Day 8-9 自测问答

```
Q1: sendfile的两个文件描述符有什么限制？
A1: - in_fd（输入）：必须支持mmap，即必须是普通文件或块设备
    - out_fd（输出）：Linux 2.6.33之前必须是socket
                     Linux 2.6.33之后可以是任何文件描述符
    原因：sendfile的实现依赖于in_fd的Page Cache，需要通过mmap访问文件内容。

Q2: sendfile为什么能减少数据拷贝？
A2: 传统方式需要4次拷贝（磁盘→内核→用户→内核→网卡）
    sendfile绕过用户空间：
    - 不支持SG-DMA：3次拷贝（磁盘→内核缓冲区→Socket缓冲区→网卡）
    - 支持SG-DMA：2次拷贝（磁盘→内核缓冲区→网卡，Socket缓冲区只存指针）

Q3: 什么是DMA Scatter-Gather？它如何实现真正的零拷贝？
A3: Scatter-Gather是DMA的高级特性，允许一次DMA操作读取/写入多个非连续的
    内存区域。实现零拷贝的方式：
    1. 文件数据通过DMA读入Page Cache
    2. Socket缓冲区不复制数据，只存储指向Page Cache的指针和长度
    3. 网卡DMA根据Scatter-Gather列表，直接从Page Cache各个页面收集数据

Q4: sendfile的offset参数有什么作用？
A4: offset参数控制从文件的哪个位置开始发送：
    - 如果offset为NULL：从文件当前偏移量开始，完成后更新文件偏移量
    - 如果offset非NULL：从*offset位置开始，完成后更新*offset值
                       但不改变文件的实际偏移量
    使用非NULL offset的好处是多个线程可以并发发送同一文件的不同部分。

Q5: sendfile返回值需要注意什么？
A5: - 返回正数：实际传输的字节数，可能小于请求的count
    - 返回0：到达文件末尾
    - 返回-1：出错，检查errno
    重要：即使在阻塞模式下，sendfile也可能只发送部分数据（当Socket缓冲区满时），
    因此需要循环调用直到发送完成。
```

---

### Day 10-11：sendfile实践（10小时）

#### 大文件分块发送

对于大文件，一次sendfile可能无法完成所有数据的传输，需要分块处理：

```cpp
// sendfile_chunked.cpp
// 示例6：sendfile大文件分块发送
// 编译：g++ -std=c++17 -O2 -o sendfile_chunked sendfile_chunked.cpp -lpthread

#include <sys/sendfile.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <unistd.h>
#include <poll.h>
#include <cstdio>
#include <cstring>
#include <cerrno>
#include <chrono>
#include <atomic>
#include <thread>
#include <functional>

// 发送进度回调类型
using ProgressCallback = std::function<void(size_t sent, size_t total)>;

class ChunkedSendfile {
public:
    // 配置参数
    struct Config {
        size_t chunk_size = 1024 * 1024;  // 默认1MB分块
        int timeout_ms = 30000;            // 30秒超时
        bool use_tcp_cork = true;          // 使用TCP_CORK优化
        int max_retries = 3;               // 最大重试次数
    };

private:
    Config config_;
    std::atomic<bool> cancelled_{false};

public:
    ChunkedSendfile(const Config& config = Config()) : config_(config) {}

    void cancel() { cancelled_ = true; }

    // 分块发送大文件
    ssize_t send_file(int socket_fd, const char* filename,
                      ProgressCallback progress = nullptr) {
        cancelled_ = false;

        // 打开文件
        int file_fd = open(filename, O_RDONLY);
        if (file_fd < 0) {
            perror("open failed");
            return -1;
        }

        // 获取文件大小
        struct stat st;
        if (fstat(file_fd, &st) < 0) {
            perror("fstat failed");
            close(file_fd);
            return -1;
        }

        size_t file_size = st.st_size;
        printf("Starting chunked sendfile: %zu bytes (%.2f MB)\n",
               file_size, file_size / (1024.0 * 1024.0));
        printf("Chunk size: %zu bytes\n", config_.chunk_size);

        // 启用TCP_CORK以减少小包发送
        if (config_.use_tcp_cork) {
            int cork = 1;
            setsockopt(socket_fd, IPPROTO_TCP, TCP_CORK, &cork, sizeof(cork));
        }

        // 预取文件到Page Cache（可选优化）
        posix_fadvise(file_fd, 0, file_size, POSIX_FADV_SEQUENTIAL);
        posix_fadvise(file_fd, 0, file_size, POSIX_FADV_WILLNEED);

        off_t offset = 0;
        ssize_t total_sent = 0;
        int retry_count = 0;

        auto start_time = std::chrono::steady_clock::now();

        while (total_sent < (ssize_t)file_size && !cancelled_) {
            // 计算本次发送大小
            size_t to_send = std::min(config_.chunk_size,
                                      file_size - total_sent);

            // 等待socket可写
            if (!wait_writable(socket_fd, config_.timeout_ms)) {
                fprintf(stderr, "Socket write timeout\n");
                break;
            }

            // 发送一个chunk
            ssize_t sent = sendfile(socket_fd, file_fd, &offset, to_send);

            if (sent < 0) {
                if (errno == EAGAIN || errno == EWOULDBLOCK) {
                    // Socket缓冲区满，等待后重试
                    if (++retry_count > config_.max_retries) {
                        fprintf(stderr, "Max retries exceeded\n");
                        break;
                    }
                    usleep(10000);  // 10ms
                    continue;
                }
                perror("sendfile failed");
                break;
            }

            if (sent == 0) {
                // 文件读取完成
                break;
            }

            total_sent += sent;
            retry_count = 0;  // 重置重试计数

            // 报告进度
            if (progress) {
                progress(total_sent, file_size);
            }

            // 计算实时速度
            auto now = std::chrono::steady_clock::now();
            auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
                now - start_time);

            if (elapsed.count() > 0) {
                double speed = (total_sent / (1024.0 * 1024.0)) /
                              (elapsed.count() / 1000.0);
                printf("\rProgress: %zd/%zu bytes (%.1f%%) - %.2f MB/s",
                       total_sent, file_size,
                       100.0 * total_sent / file_size, speed);
                fflush(stdout);
            }
        }

        // 关闭TCP_CORK，刷新剩余数据
        if (config_.use_tcp_cork) {
            int cork = 0;
            setsockopt(socket_fd, IPPROTO_TCP, TCP_CORK, &cork, sizeof(cork));
        }

        printf("\n");

        // 报告最终统计
        auto end_time = std::chrono::steady_clock::now();
        auto total_time = std::chrono::duration_cast<std::chrono::milliseconds>(
            end_time - start_time);

        if (total_time.count() > 0) {
            double speed = (total_sent / (1024.0 * 1024.0)) /
                          (total_time.count() / 1000.0);
            printf("Completed: %zd bytes in %ld ms (%.2f MB/s)\n",
                   total_sent, total_time.count(), speed);
        }

        close(file_fd);

        if (cancelled_) {
            printf("Transfer cancelled\n");
            return -1;
        }

        return total_sent;
    }

    // 带断点续传支持的发送
    ssize_t send_file_resume(int socket_fd, const char* filename,
                            off_t start_offset, size_t length,
                            ProgressCallback progress = nullptr) {
        cancelled_ = false;

        int file_fd = open(filename, O_RDONLY);
        if (file_fd < 0) {
            perror("open failed");
            return -1;
        }

        struct stat st;
        fstat(file_fd, &st);

        // 验证范围
        if (start_offset >= st.st_size) {
            fprintf(stderr, "Invalid start offset\n");
            close(file_fd);
            return -1;
        }

        // 调整长度
        size_t actual_length = length;
        if (length == 0 || start_offset + length > (size_t)st.st_size) {
            actual_length = st.st_size - start_offset;
        }

        printf("Resuming from offset %ld, sending %zu bytes\n",
               start_offset, actual_length);

        off_t offset = start_offset;
        ssize_t total_sent = 0;

        while (total_sent < (ssize_t)actual_length && !cancelled_) {
            size_t to_send = std::min(config_.chunk_size,
                                      actual_length - total_sent);

            ssize_t sent = sendfile(socket_fd, file_fd, &offset, to_send);

            if (sent <= 0) {
                if (sent < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
                    usleep(1000);
                    continue;
                }
                break;
            }

            total_sent += sent;

            if (progress) {
                progress(total_sent, actual_length);
            }
        }

        close(file_fd);
        return total_sent;
    }

private:
    // 等待socket可写
    bool wait_writable(int fd, int timeout_ms) {
        struct pollfd pfd;
        pfd.fd = fd;
        pfd.events = POLLOUT;

        int ret = poll(&pfd, 1, timeout_ms);
        return ret > 0 && (pfd.revents & POLLOUT);
    }
};

// 并发分片发送（用于多连接下载加速）
class ParallelSendfile {
public:
    struct Slice {
        off_t offset;
        size_t length;
    };

    // 将文件分成多个切片
    static std::vector<Slice> create_slices(size_t file_size, int num_slices) {
        std::vector<Slice> slices;
        size_t slice_size = file_size / num_slices;

        for (int i = 0; i < num_slices; i++) {
            Slice slice;
            slice.offset = i * slice_size;

            if (i == num_slices - 1) {
                // 最后一个切片包含剩余部分
                slice.length = file_size - slice.offset;
            } else {
                slice.length = slice_size;
            }

            slices.push_back(slice);
        }

        return slices;
    }

    // 发送指定切片
    static ssize_t send_slice(int socket_fd, const char* filename,
                             const Slice& slice) {
        int file_fd = open(filename, O_RDONLY);
        if (file_fd < 0) return -1;

        off_t offset = slice.offset;
        ssize_t total_sent = 0;

        while (total_sent < (ssize_t)slice.length) {
            ssize_t sent = sendfile(socket_fd, file_fd, &offset,
                                    slice.length - total_sent);
            if (sent <= 0) break;
            total_sent += sent;
        }

        close(file_fd);
        return total_sent;
    }
};

int main(int argc, char* argv[]) {
    if (argc < 3) {
        printf("Usage: %s <filename> <port> [chunk_size_kb]\n", argv[0]);
        return 1;
    }

    const char* filename = argv[1];
    int port = atoi(argv[2]);

    ChunkedSendfile::Config config;
    if (argc > 3) {
        config.chunk_size = atoi(argv[3]) * 1024;
    }

    // 创建服务器
    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(port);

    bind(server_fd, (struct sockaddr*)&addr, sizeof(addr));
    listen(server_fd, 5);

    printf("Server listening on port %d\n", port);
    printf("Chunk size: %zu KB\n", config.chunk_size / 1024);

    while (true) {
        printf("\nWaiting for connection...\n");

        int client_fd = accept(server_fd, nullptr, nullptr);
        if (client_fd < 0) continue;

        printf("Client connected\n");

        // 设置socket为非阻塞模式
        int flags = fcntl(client_fd, F_GETFL, 0);
        fcntl(client_fd, F_SETFL, flags | O_NONBLOCK);

        ChunkedSendfile sender(config);

        ssize_t sent = sender.send_file(client_fd, filename,
            [](size_t sent, size_t total) {
                // 进度回调
            });

        printf("Transfer completed: %zd bytes\n", sent);

        close(client_fd);
    }

    close(server_fd);
    return 0;
}
```

#### sendfile与非阻塞Socket

```cpp
// sendfile_nonblock.cpp
// 示例7：sendfile与非阻塞socket结合使用
// 编译：g++ -std=c++17 -O2 -o sendfile_nonblock sendfile_nonblock.cpp

#include <sys/sendfile.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/epoll.h>
#include <netinet/in.h>
#include <fcntl.h>
#include <unistd.h>
#include <cstdio>
#include <cstring>
#include <cerrno>
#include <unordered_map>
#include <memory>

// 连接上下文：追踪每个连接的sendfile进度
struct ConnectionContext {
    int client_fd;
    int file_fd;
    size_t file_size;
    off_t offset;      // 当前发送位置
    size_t sent;       // 已发送字节数
    bool completed;

    ConnectionContext(int cfd, int ffd, size_t fsize)
        : client_fd(cfd), file_fd(ffd), file_size(fsize),
          offset(0), sent(0), completed(false) {}

    ~ConnectionContext() {
        if (file_fd >= 0) close(file_fd);
        if (client_fd >= 0) close(client_fd);
    }
};

class NonBlockingSendfileServer {
public:
    NonBlockingSendfileServer(int port, const char* filename)
        : port_(port), filename_(filename) {
        epfd_ = epoll_create1(EPOLL_CLOEXEC);
    }

    ~NonBlockingSendfileServer() {
        if (epfd_ >= 0) close(epfd_);
        if (listen_fd_ >= 0) close(listen_fd_);
    }

    bool start() {
        // 创建非阻塞监听socket
        listen_fd_ = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK, 0);
        if (listen_fd_ < 0) {
            perror("socket failed");
            return false;
        }

        int opt = 1;
        setsockopt(listen_fd_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

        struct sockaddr_in addr;
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = INADDR_ANY;
        addr.sin_port = htons(port_);

        if (bind(listen_fd_, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
            perror("bind failed");
            return false;
        }

        if (listen(listen_fd_, SOMAXCONN) < 0) {
            perror("listen failed");
            return false;
        }

        // 注册监听socket到epoll
        struct epoll_event ev;
        ev.events = EPOLLIN;
        ev.data.fd = listen_fd_;
        epoll_ctl(epfd_, EPOLL_CTL_ADD, listen_fd_, &ev);

        printf("Server started on port %d\n", port_);
        printf("Serving file: %s\n", filename_);

        return true;
    }

    void run() {
        running_ = true;
        std::vector<epoll_event> events(1024);

        while (running_) {
            int n = epoll_wait(epfd_, events.data(), events.size(), 1000);

            for (int i = 0; i < n; i++) {
                int fd = events[i].data.fd;
                uint32_t revents = events[i].events;

                if (fd == listen_fd_) {
                    // 新连接
                    handle_accept();
                } else if (revents & EPOLLOUT) {
                    // socket可写，继续sendfile
                    handle_write(fd);
                } else if (revents & (EPOLLERR | EPOLLHUP)) {
                    // 连接错误或关闭
                    handle_close(fd);
                }
            }
        }
    }

    void stop() { running_ = false; }

private:
    void handle_accept() {
        while (true) {
            int client_fd = accept4(listen_fd_, nullptr, nullptr,
                                    SOCK_NONBLOCK);
            if (client_fd < 0) {
                if (errno == EAGAIN || errno == EWOULDBLOCK) {
                    break;  // 没有更多连接
                }
                perror("accept failed");
                continue;
            }

            // 打开文件
            int file_fd = open(filename_, O_RDONLY);
            if (file_fd < 0) {
                perror("open failed");
                close(client_fd);
                continue;
            }

            struct stat st;
            fstat(file_fd, &st);

            // 创建连接上下文
            auto ctx = std::make_shared<ConnectionContext>(
                client_fd, file_fd, st.st_size);
            connections_[client_fd] = ctx;

            printf("New connection: fd=%d, file_size=%zu\n",
                   client_fd, st.st_size);

            // 注册可写事件
            struct epoll_event ev;
            ev.events = EPOLLOUT | EPOLLET;  // 边缘触发
            ev.data.fd = client_fd;
            epoll_ctl(epfd_, EPOLL_CTL_ADD, client_fd, &ev);

            // 立即尝试发送
            handle_write(client_fd);
        }
    }

    void handle_write(int fd) {
        auto it = connections_.find(fd);
        if (it == connections_.end()) return;

        auto& ctx = it->second;

        while (ctx->sent < ctx->file_size) {
            size_t remaining = ctx->file_size - ctx->sent;
            size_t to_send = std::min(remaining, (size_t)(1024 * 1024));

            ssize_t sent = sendfile(ctx->client_fd, ctx->file_fd,
                                    &ctx->offset, to_send);

            if (sent < 0) {
                if (errno == EAGAIN || errno == EWOULDBLOCK) {
                    // Socket缓冲区满，等待下次EPOLLOUT
                    return;
                }
                // 其他错误，关闭连接
                perror("sendfile failed");
                handle_close(fd);
                return;
            }

            if (sent == 0) {
                // 文件读取完毕
                break;
            }

            ctx->sent += sent;
        }

        // 检查是否完成
        if (ctx->sent >= ctx->file_size) {
            printf("Transfer completed: fd=%d, sent=%zu bytes\n",
                   fd, ctx->sent);
            ctx->completed = true;
            handle_close(fd);
        }
    }

    void handle_close(int fd) {
        epoll_ctl(epfd_, EPOLL_CTL_DEL, fd, nullptr);
        connections_.erase(fd);
    }

private:
    int port_;
    const char* filename_;
    int epfd_ = -1;
    int listen_fd_ = -1;
    bool running_ = false;
    std::unordered_map<int, std::shared_ptr<ConnectionContext>> connections_;
};

int main(int argc, char* argv[]) {
    if (argc < 3) {
        printf("Usage: %s <filename> <port>\n", argv[0]);
        return 1;
    }

    NonBlockingSendfileServer server(atoi(argv[2]), argv[1]);

    if (!server.start()) {
        return 1;
    }

    server.run();

    return 0;
}
```

#### Day 10-11 自测问答

```
Q1: sendfile发送大文件时为什么需要分块？
A1: 原因：
    1. sendfile单次调用可能只发送部分数据（受Socket缓冲区大小限制）
    2. 非阻塞模式下，Socket缓冲区满时返回EAGAIN
    3. 分块可以实现进度报告和取消功能
    4. 分块便于实现断点续传
    5. 避免长时间阻塞，提高响应性

Q2: TCP_CORK选项在sendfile中有什么作用？
A2: TCP_CORK的作用是告诉内核累积小数据包，等数据量足够大或显式关闭CORK
    后再一起发送：
    - 开启CORK：数据累积在内核，不立即发送
    - 关闭CORK：刷新所有累积的数据
    与sendfile配合使用可以：
    1. 先发送HTTP头（小数据）
    2. 再sendfile发送文件体（大数据）
    3. 减少小包数量，提高传输效率

Q3: 非阻塞sendfile如何处理EAGAIN？
A3: EAGAIN表示Socket发送缓冲区满，无法继续发送：
    1. 保存当前发送进度（offset和已发送字节数）
    2. 等待EPOLLOUT事件（Socket缓冲区有空闲）
    3. 收到EPOLLOUT后，从上次位置继续sendfile
    4. 重复直到文件全部发送完成
    关键是要保持offset的持续性，每次sendfile会自动更新offset。

Q4: 如何实现sendfile的断点续传？
A4: 断点续传需要：
    1. 客户端记录已接收的字节数
    2. 重连时发送Range请求（如HTTP的Range: bytes=12345-）
    3. 服务端使用sendfile的offset参数从指定位置开始
    4. sendfile(socket_fd, file_fd, &offset, remaining_length)
    注意：offset必须是指针类型，sendfile会自动更新其值。

Q5: 边缘触发(EPOLLET)模式下使用sendfile需要注意什么？
A5: 边缘触发模式下：
    1. 必须循环调用sendfile直到返回EAGAIN，否则可能丢失事件
    2. 每次EPOLLOUT事件只触发一次，必须drain所有可写空间
    3. 需要正确处理partial write
    4. 文件描述符必须是非阻塞的
    代码模式：
    while (true) {
        ssize_t n = sendfile(...);
        if (n < 0 && errno == EAGAIN) break;
        if (n <= 0) { close_connection(); break; }
        total_sent += n;
    }
```

---

### Day 12-14：sendfile性能优化（15小时）

#### sendfile与TCP_CORK配合

```cpp
// sendfile_cork.cpp
// 示例8：sendfile与TCP_CORK配合发送HTTP响应
// 编译：g++ -std=c++17 -O2 -o sendfile_cork sendfile_cork.cpp

#include <sys/sendfile.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <unistd.h>
#include <cstdio>
#include <cstring>
#include <string>
#include <chrono>

class HttpFileServer {
public:
    // 使用TCP_CORK优化HTTP响应
    static ssize_t send_http_response(int socket_fd, const char* filename,
                                      const char* content_type) {
        // 获取文件信息
        struct stat st;
        if (stat(filename, &st) < 0) {
            // 发送404响应
            const char* not_found = "HTTP/1.1 404 Not Found\r\n"
                                    "Content-Length: 0\r\n\r\n";
            return write(socket_fd, not_found, strlen(not_found));
        }

        int file_fd = open(filename, O_RDONLY);
        if (file_fd < 0) {
            return -1;
        }

        // 构建HTTP响应头
        char header[1024];
        int header_len = snprintf(header, sizeof(header),
            "HTTP/1.1 200 OK\r\n"
            "Content-Type: %s\r\n"
            "Content-Length: %ld\r\n"
            "Connection: keep-alive\r\n"
            "Accept-Ranges: bytes\r\n"
            "\r\n",
            content_type, st.st_size);

        ssize_t total_sent = 0;

        // 方法1：不使用CORK（可能发送多个小包）
        // write(socket_fd, header, header_len);
        // sendfile(socket_fd, file_fd, nullptr, st.st_size);

        // 方法2：使用TCP_CORK（合并发送）
        int cork = 1;
        if (setsockopt(socket_fd, IPPROTO_TCP, TCP_CORK,
                       &cork, sizeof(cork)) < 0) {
            perror("setsockopt TCP_CORK on");
        }

        // 发送HTTP头
        ssize_t header_sent = write(socket_fd, header, header_len);
        if (header_sent > 0) {
            total_sent += header_sent;
        }

        // 使用sendfile发送文件体
        off_t offset = 0;
        ssize_t file_sent = 0;
        while (file_sent < st.st_size) {
            ssize_t sent = sendfile(socket_fd, file_fd, &offset,
                                    st.st_size - file_sent);
            if (sent <= 0) break;
            file_sent += sent;
        }
        total_sent += file_sent;

        // 关闭CORK，刷新缓冲区
        cork = 0;
        if (setsockopt(socket_fd, IPPROTO_TCP, TCP_CORK,
                       &cork, sizeof(cork)) < 0) {
            perror("setsockopt TCP_CORK off");
        }

        close(file_fd);

        printf("Sent: header=%zd bytes, body=%zd bytes, total=%zd bytes\n",
               header_sent, file_sent, total_sent);

        return total_sent;
    }

    // 支持HTTP Range请求（断点续传）
    static ssize_t send_http_range_response(int socket_fd, const char* filename,
                                           off_t range_start, off_t range_end) {
        struct stat st;
        if (stat(filename, &st) < 0) {
            return -1;
        }

        int file_fd = open(filename, O_RDONLY);
        if (file_fd < 0) {
            return -1;
        }

        // 调整range_end
        if (range_end < 0 || range_end >= st.st_size) {
            range_end = st.st_size - 1;
        }

        size_t content_length = range_end - range_start + 1;

        // 构建206 Partial Content响应
        char header[1024];
        int header_len = snprintf(header, sizeof(header),
            "HTTP/1.1 206 Partial Content\r\n"
            "Content-Type: application/octet-stream\r\n"
            "Content-Length: %zu\r\n"
            "Content-Range: bytes %ld-%ld/%ld\r\n"
            "Accept-Ranges: bytes\r\n"
            "\r\n",
            content_length, range_start, range_end, st.st_size);

        int cork = 1;
        setsockopt(socket_fd, IPPROTO_TCP, TCP_CORK, &cork, sizeof(cork));

        write(socket_fd, header, header_len);

        // 从指定偏移量发送
        off_t offset = range_start;
        ssize_t sent = sendfile(socket_fd, file_fd, &offset, content_length);

        cork = 0;
        setsockopt(socket_fd, IPPROTO_TCP, TCP_CORK, &cork, sizeof(cork));

        close(file_fd);

        printf("Range response: %ld-%ld, sent=%zd bytes\n",
               range_start, range_end, sent);

        return sent;
    }
};

// TCP_CORK vs TCP_NODELAY 对比测试
class TcpOptionTest {
public:
    static void compare_options(int socket_fd, const char* filename) {
        struct stat st;
        stat(filename, &st);

        printf("\n=== TCP Option Comparison ===\n");
        printf("File size: %ld bytes\n", st.st_size);

        // 准备HTTP头
        char header[256];
        int header_len = snprintf(header, sizeof(header),
            "HTTP/1.1 200 OK\r\nContent-Length: %ld\r\n\r\n", st.st_size);

        // 测试1：默认设置（Nagle算法开启）
        {
            auto start = std::chrono::high_resolution_clock::now();

            write(socket_fd, header, header_len);

            int file_fd = open(filename, O_RDONLY);
            off_t offset = 0;
            sendfile(socket_fd, file_fd, &offset, st.st_size);
            close(file_fd);

            auto end = std::chrono::high_resolution_clock::now();
            auto us = std::chrono::duration_cast<std::chrono::microseconds>(
                end - start).count();

            printf("Default (Nagle on): %ld us\n", us);
        }

        // 测试2：TCP_NODELAY（禁用Nagle）
        {
            int nodelay = 1;
            setsockopt(socket_fd, IPPROTO_TCP, TCP_NODELAY,
                       &nodelay, sizeof(nodelay));

            auto start = std::chrono::high_resolution_clock::now();

            write(socket_fd, header, header_len);

            int file_fd = open(filename, O_RDONLY);
            off_t offset = 0;
            sendfile(socket_fd, file_fd, &offset, st.st_size);
            close(file_fd);

            auto end = std::chrono::high_resolution_clock::now();
            auto us = std::chrono::duration_cast<std::chrono::microseconds>(
                end - start).count();

            printf("TCP_NODELAY: %ld us\n", us);

            nodelay = 0;
            setsockopt(socket_fd, IPPROTO_TCP, TCP_NODELAY,
                       &nodelay, sizeof(nodelay));
        }

        // 测试3：TCP_CORK
        {
            int cork = 1;
            setsockopt(socket_fd, IPPROTO_TCP, TCP_CORK, &cork, sizeof(cork));

            auto start = std::chrono::high_resolution_clock::now();

            write(socket_fd, header, header_len);

            int file_fd = open(filename, O_RDONLY);
            off_t offset = 0;
            sendfile(socket_fd, file_fd, &offset, st.st_size);
            close(file_fd);

            cork = 0;
            setsockopt(socket_fd, IPPROTO_TCP, TCP_CORK, &cork, sizeof(cork));

            auto end = std::chrono::high_resolution_clock::now();
            auto us = std::chrono::duration_cast<std::chrono::microseconds>(
                end - start).count();

            printf("TCP_CORK: %ld us\n", us);
        }
    }
};

int main(int argc, char* argv[]) {
    if (argc < 3) {
        printf("Usage: %s <filename> <port>\n", argv[0]);
        return 1;
    }

    const char* filename = argv[1];
    int port = atoi(argv[2]);

    // 创建服务器
    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(port);

    bind(server_fd, (struct sockaddr*)&addr, sizeof(addr));
    listen(server_fd, 5);

    printf("HTTP File Server on port %d\n", port);
    printf("Serving: %s\n", filename);

    while (true) {
        int client_fd = accept(server_fd, nullptr, nullptr);
        if (client_fd < 0) continue;

        // 读取HTTP请求（简化处理）
        char request[4096];
        ssize_t n = read(client_fd, request, sizeof(request) - 1);
        if (n > 0) {
            request[n] = '\0';
            printf("Request:\n%s\n", request);

            // 检查是否有Range头
            char* range = strstr(request, "Range: bytes=");
            if (range) {
                off_t start = 0, end = -1;
                sscanf(range + 13, "%ld-%ld", &start, &end);
                HttpFileServer::send_http_range_response(
                    client_fd, filename, start, end);
            } else {
                HttpFileServer::send_http_response(
                    client_fd, filename, "application/octet-stream");
            }
        }

        close(client_fd);
    }

    close(server_fd);
    return 0;
}
```

#### sendfile与writev组合

```cpp
// sendfile_writev.cpp
// 示例9：sendfile与writev组合实现高效HTTP响应
// 编译：g++ -std=c++17 -O2 -o sendfile_writev sendfile_writev.cpp

#include <sys/sendfile.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/uio.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <fcntl.h>
#include <unistd.h>
#include <cstdio>
#include <cstring>
#include <ctime>
#include <string>
#include <vector>

// 高效的HTTP响应发送器
class EfficientHttpSender {
public:
    // 方法1：多次write（效率最低）
    static ssize_t send_multiple_writes(int socket_fd, const char* filename) {
        struct stat st;
        stat(filename, &st);

        int file_fd = open(filename, O_RDONLY);
        if (file_fd < 0) return -1;

        // 第一次write：状态行
        const char* status = "HTTP/1.1 200 OK\r\n";
        write(socket_fd, status, strlen(status));

        // 第二次write：Content-Type
        const char* content_type = "Content-Type: text/html\r\n";
        write(socket_fd, content_type, strlen(content_type));

        // 第三次write：Content-Length
        char content_length[64];
        snprintf(content_length, sizeof(content_length),
                 "Content-Length: %ld\r\n\r\n", st.st_size);
        write(socket_fd, content_length, strlen(content_length));

        // 第四次：sendfile发送文件
        off_t offset = 0;
        ssize_t sent = sendfile(socket_fd, file_fd, &offset, st.st_size);

        close(file_fd);
        return sent;
    }

    // 方法2：writev + sendfile（高效）
    static ssize_t send_writev_sendfile(int socket_fd, const char* filename) {
        struct stat st;
        stat(filename, &st);

        int file_fd = open(filename, O_RDONLY);
        if (file_fd < 0) return -1;

        // 准备HTTP头的各个部分
        const char* status = "HTTP/1.1 200 OK\r\n";
        const char* content_type = "Content-Type: text/html\r\n";
        char content_length[64];
        snprintf(content_length, sizeof(content_length),
                 "Content-Length: %ld\r\n", st.st_size);
        const char* connection = "Connection: keep-alive\r\n";

        // 生成日期头
        char date[128];
        time_t now = time(nullptr);
        struct tm* tm = gmtime(&now);
        strftime(date, sizeof(date),
                 "Date: %a, %d %b %Y %H:%M:%S GMT\r\n", tm);

        const char* end_header = "\r\n";

        // 使用writev一次系统调用发送所有头部
        struct iovec iov[6];
        iov[0].iov_base = (void*)status;
        iov[0].iov_len = strlen(status);
        iov[1].iov_base = (void*)content_type;
        iov[1].iov_len = strlen(content_type);
        iov[2].iov_base = content_length;
        iov[2].iov_len = strlen(content_length);
        iov[3].iov_base = (void*)connection;
        iov[3].iov_len = strlen(connection);
        iov[4].iov_base = date;
        iov[4].iov_len = strlen(date);
        iov[5].iov_base = (void*)end_header;
        iov[5].iov_len = strlen(end_header);

        // 使用TCP_CORK配合
        int cork = 1;
        setsockopt(socket_fd, IPPROTO_TCP, TCP_CORK, &cork, sizeof(cork));

        // writev发送所有头部（一次系统调用）
        ssize_t header_sent = writev(socket_fd, iov, 6);

        // sendfile发送文件体
        off_t offset = 0;
        ssize_t file_sent = sendfile(socket_fd, file_fd, &offset, st.st_size);

        // 关闭CORK
        cork = 0;
        setsockopt(socket_fd, IPPROTO_TCP, TCP_CORK, &cork, sizeof(cork));

        close(file_fd);

        printf("writev+sendfile: header=%zd, body=%zd\n",
               header_sent, file_sent);
        return header_sent + file_sent;
    }

    // 方法3：构建完整响应类
    struct HttpResponse {
        std::string status_line;
        std::vector<std::pair<std::string, std::string>> headers;
        const char* body_file;  // 文件路径

        ssize_t send(int socket_fd) {
            // 构建头部字符串
            std::string header_str = status_line + "\r\n";
            for (const auto& [name, value] : headers) {
                header_str += name + ": " + value + "\r\n";
            }
            header_str += "\r\n";

            int cork = 1;
            setsockopt(socket_fd, IPPROTO_TCP, TCP_CORK, &cork, sizeof(cork));

            // 发送头部
            ssize_t header_sent = write(socket_fd, header_str.c_str(),
                                        header_str.length());

            // 发送文件体
            ssize_t body_sent = 0;
            if (body_file) {
                int file_fd = open(body_file, O_RDONLY);
                if (file_fd >= 0) {
                    struct stat st;
                    fstat(file_fd, &st);
                    off_t offset = 0;
                    body_sent = sendfile(socket_fd, file_fd, &offset, st.st_size);
                    close(file_fd);
                }
            }

            cork = 0;
            setsockopt(socket_fd, IPPROTO_TCP, TCP_CORK, &cork, sizeof(cork));

            return header_sent + body_sent;
        }
    };
};

// 批量发送多个文件（适用于HTTP/2多路复用场景概念演示）
class BatchSendfile {
public:
    struct FileToSend {
        const char* filename;
        off_t offset;
        size_t length;
    };

    // 批量发送多个文件片段
    static ssize_t send_batch(int socket_fd,
                             const std::vector<FileToSend>& files) {
        ssize_t total_sent = 0;

        int cork = 1;
        setsockopt(socket_fd, IPPROTO_TCP, TCP_CORK, &cork, sizeof(cork));

        for (const auto& file : files) {
            int fd = open(file.filename, O_RDONLY);
            if (fd < 0) continue;

            off_t offset = file.offset;
            ssize_t sent = sendfile(socket_fd, fd, &offset, file.length);
            if (sent > 0) {
                total_sent += sent;
            }

            close(fd);
        }

        cork = 0;
        setsockopt(socket_fd, IPPROTO_TCP, TCP_CORK, &cork, sizeof(cork));

        return total_sent;
    }
};

int main(int argc, char* argv[]) {
    if (argc < 3) {
        printf("Usage: %s <filename> <port>\n", argv[0]);
        return 1;
    }

    const char* filename = argv[1];
    int port = atoi(argv[2]);

    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(port);

    bind(server_fd, (struct sockaddr*)&addr, sizeof(addr));
    listen(server_fd, 5);

    printf("Server on port %d\n", port);

    while (true) {
        int client_fd = accept(server_fd, nullptr, nullptr);
        if (client_fd < 0) continue;

        // 读取请求
        char buf[4096];
        read(client_fd, buf, sizeof(buf));

        // 使用writev + sendfile方式发送
        EfficientHttpSender::send_writev_sendfile(client_fd, filename);

        close(client_fd);
    }

    close(server_fd);
    return 0;
}
```

#### Nginx sendfile实现分析

```
Nginx中的sendfile实现分析：

Nginx是高性能Web服务器的代表，其sendfile使用非常精妙。

┌─────────────────────────────────────────────────────────────────────────────┐
│                    Nginx sendfile 架构                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  配置文件 nginx.conf:                                                       │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ http {                                                               │   │
│  │     sendfile on;              # 启用sendfile                        │   │
│  │     sendfile_max_chunk 512k;  # 每次sendfile最大发送量              │   │
│  │     tcp_nopush on;            # 启用TCP_CORK                        │   │
│  │     tcp_nodelay on;           # 与tcp_nopush配合使用                │   │
│  │     directio 4m;              # 大文件直接I/O阈值                   │   │
│  │     aio on;                   # 异步I/O（与sendfile互斥）           │   │
│  │ }                                                                    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  处理流程：                                                                 │
│                                                                             │
│  ┌─────────────┐      ┌─────────────┐      ┌─────────────┐                │
│  │ 接收请求    │──────▶│ 解析路径    │──────▶│ 判断文件    │                │
│  └─────────────┘      └─────────────┘      └──────┬──────┘                │
│                                                    │                        │
│                       ┌────────────────────────────┴───────────────────┐   │
│                       │                                                 │   │
│                       ▼                                                 ▼   │
│              ┌─────────────────┐                          ┌─────────────┐   │
│              │ 小文件 < 4MB    │                          │ 大文件 >= 4MB│   │
│              │ sendfile + cache│                          │ directio    │   │
│              └────────┬────────┘                          └──────┬──────┘   │
│                       │                                          │          │
│                       ▼                                          ▼          │
│              ┌─────────────────┐                   ┌────────────────────┐  │
│              │ ngx_sendfile()  │                   │ 直接I/O绕过Cache   │  │
│              │ + TCP_CORK      │                   │ 减少内存占用       │  │
│              └─────────────────┘                   └────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

Nginx sendfile关键代码（简化版）：

// src/os/unix/ngx_linux_sendfile_chain.c
ngx_chain_t *
ngx_linux_sendfile_chain(ngx_connection_t *c, ngx_chain_t *in, off_t limit)
{
    // 启用TCP_CORK
    if (c->tcp_nopush == NGX_TCP_NOPUSH_UNSET) {
        tcp_cork = 1;
        setsockopt(c->fd, IPPROTO_TCP, TCP_CORK, &tcp_cork, sizeof(int));
        c->tcp_nopush = NGX_TCP_NOPUSH_SET;
    }

    for ( ;; ) {
        // 遍历输出链表
        for (cl = in; cl; cl = cl->next) {
            buf = cl->buf;

            if (buf->in_file) {
                // 文件缓冲区：使用sendfile
                file_size = buf->file_last - buf->file_pos;

                // 限制单次发送大小
                if (file_size > sendfile_max_chunk) {
                    file_size = sendfile_max_chunk;
                }

                // 调用sendfile
                n = sendfile(c->fd, buf->file->fd, &buf->file_pos, file_size);

            } else {
                // 内存缓冲区：使用writev
                n = writev(c->fd, vec.iovs, vec.count);
            }
        }

        // 处理EAGAIN
        if (n == -1 && errno == EAGAIN) {
            return in;  // 返回未发送的链表
        }
    }
}

tcp_nopush和tcp_nodelay配合使用：
1. tcp_nopush on: 启用TCP_CORK，累积数据
2. 发送完HTTP头和文件后
3. tcp_nodelay on: 确保最后的小数据立即发送
4. Nginx会自动在适当时机切换

sendfile_max_chunk的作用：
- 限制单次sendfile的数据量
- 避免长时间占用CPU
- 让其他连接有机会被处理
- 默认值0表示无限制（适合低并发场景）
- 高并发场景建议设置为512k-2m
```

#### 示例10：完整的sendfile文件服务器

```cpp
// sendfile_file_server.cpp
// 示例10：生产级sendfile文件服务器
// 编译：g++ -std=c++17 -O2 -pthread -o sendfile_server sendfile_file_server.cpp

#include <sys/sendfile.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/epoll.h>
#include <sys/uio.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <unistd.h>
#include <dirent.h>
#include <cstdio>
#include <cstring>
#include <ctime>
#include <string>
#include <unordered_map>
#include <memory>
#include <thread>
#include <atomic>

// 连接状态
enum class ConnState {
    READING_REQUEST,
    SENDING_RESPONSE,
    DONE
};

// 连接上下文
struct Connection {
    int fd;
    ConnState state;

    // 请求解析
    char request_buf[4096];
    size_t request_len;

    // 响应发送
    std::string response_header;
    size_t header_sent;
    int file_fd;
    size_t file_size;
    off_t file_offset;
    size_t file_sent;

    Connection(int fd_) : fd(fd_), state(ConnState::READING_REQUEST),
                          request_len(0), header_sent(0), file_fd(-1),
                          file_size(0), file_offset(0), file_sent(0) {}

    ~Connection() {
        if (file_fd >= 0) close(file_fd);
        if (fd >= 0) close(fd);
    }

    void reset() {
        state = ConnState::READING_REQUEST;
        request_len = 0;
        response_header.clear();
        header_sent = 0;
        if (file_fd >= 0) {
            close(file_fd);
            file_fd = -1;
        }
        file_size = 0;
        file_offset = 0;
        file_sent = 0;
    }
};

class SendfileFileServer {
public:
    SendfileFileServer(int port, const std::string& root_dir)
        : port_(port), root_dir_(root_dir) {
        epfd_ = epoll_create1(EPOLL_CLOEXEC);
    }

    ~SendfileFileServer() {
        stop();
        if (epfd_ >= 0) close(epfd_);
        if (listen_fd_ >= 0) close(listen_fd_);
    }

    bool start() {
        // 创建监听socket
        listen_fd_ = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK, 0);
        if (listen_fd_ < 0) return false;

        int opt = 1;
        setsockopt(listen_fd_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
        setsockopt(listen_fd_, SOL_SOCKET, SO_REUSEPORT, &opt, sizeof(opt));

        struct sockaddr_in addr;
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = INADDR_ANY;
        addr.sin_port = htons(port_);

        if (bind(listen_fd_, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
            perror("bind");
            return false;
        }

        if (listen(listen_fd_, SOMAXCONN) < 0) {
            perror("listen");
            return false;
        }

        // 注册监听socket
        struct epoll_event ev;
        ev.events = EPOLLIN;
        ev.data.fd = listen_fd_;
        epoll_ctl(epfd_, EPOLL_CTL_ADD, listen_fd_, &ev);

        printf("File server started on port %d\n", port_);
        printf("Root directory: %s\n", root_dir_.c_str());

        return true;
    }

    void run() {
        running_ = true;
        std::vector<epoll_event> events(1024);

        while (running_) {
            int n = epoll_wait(epfd_, events.data(), events.size(), 100);

            for (int i = 0; i < n; i++) {
                int fd = events[i].data.fd;
                uint32_t revents = events[i].events;

                if (fd == listen_fd_) {
                    handle_accept();
                } else {
                    auto it = connections_.find(fd);
                    if (it == connections_.end()) continue;

                    auto& conn = it->second;

                    if (revents & EPOLLIN) {
                        handle_read(conn);
                    }
                    if (revents & EPOLLOUT) {
                        handle_write(conn);
                    }
                    if (revents & (EPOLLERR | EPOLLHUP)) {
                        close_connection(fd);
                    }
                }
            }
        }
    }

    void stop() {
        running_ = false;
    }

private:
    void handle_accept() {
        while (true) {
            int client_fd = accept4(listen_fd_, nullptr, nullptr,
                                    SOCK_NONBLOCK);
            if (client_fd < 0) {
                if (errno == EAGAIN) break;
                continue;
            }

            // 设置TCP选项
            int opt = 1;
            setsockopt(client_fd, IPPROTO_TCP, TCP_NODELAY, &opt, sizeof(opt));

            // 创建连接
            auto conn = std::make_shared<Connection>(client_fd);
            connections_[client_fd] = conn;

            // 注册读事件
            struct epoll_event ev;
            ev.events = EPOLLIN | EPOLLET;
            ev.data.fd = client_fd;
            epoll_ctl(epfd_, EPOLL_CTL_ADD, client_fd, &ev);

            total_connections_++;
        }
    }

    void handle_read(std::shared_ptr<Connection>& conn) {
        while (true) {
            ssize_t n = read(conn->fd,
                            conn->request_buf + conn->request_len,
                            sizeof(conn->request_buf) - conn->request_len - 1);

            if (n < 0) {
                if (errno == EAGAIN) break;
                close_connection(conn->fd);
                return;
            }

            if (n == 0) {
                close_connection(conn->fd);
                return;
            }

            conn->request_len += n;
            conn->request_buf[conn->request_len] = '\0';

            // 检查请求是否完整
            if (strstr(conn->request_buf, "\r\n\r\n")) {
                process_request(conn);
                return;
            }
        }
    }

    void process_request(std::shared_ptr<Connection>& conn) {
        // 解析HTTP请求
        char method[16], path[1024], version[16];
        sscanf(conn->request_buf, "%s %s %s", method, path, version);

        // 只支持GET方法
        if (strcmp(method, "GET") != 0) {
            send_error(conn, 405, "Method Not Allowed");
            return;
        }

        // 构建文件路径
        std::string file_path = root_dir_ + path;
        if (file_path.back() == '/') {
            file_path += "index.html";
        }

        // 安全检查：防止路径遍历
        if (file_path.find("..") != std::string::npos) {
            send_error(conn, 403, "Forbidden");
            return;
        }

        // 获取文件信息
        struct stat st;
        if (stat(file_path.c_str(), &st) < 0) {
            send_error(conn, 404, "Not Found");
            return;
        }

        // 如果是目录，列出内容
        if (S_ISDIR(st.st_mode)) {
            send_directory_listing(conn, file_path, path);
            return;
        }

        // 打开文件
        int file_fd = open(file_path.c_str(), O_RDONLY);
        if (file_fd < 0) {
            send_error(conn, 500, "Internal Server Error");
            return;
        }

        // 预取文件到Page Cache
        posix_fadvise(file_fd, 0, st.st_size, POSIX_FADV_SEQUENTIAL);

        conn->file_fd = file_fd;
        conn->file_size = st.st_size;
        conn->file_offset = 0;
        conn->file_sent = 0;

        // 构建响应头
        const char* content_type = get_content_type(file_path);
        char date_buf[128];
        time_t now = time(nullptr);
        strftime(date_buf, sizeof(date_buf),
                 "%a, %d %b %Y %H:%M:%S GMT", gmtime(&now));

        char header[1024];
        snprintf(header, sizeof(header),
            "HTTP/1.1 200 OK\r\n"
            "Content-Type: %s\r\n"
            "Content-Length: %zu\r\n"
            "Date: %s\r\n"
            "Server: SendfileServer/1.0\r\n"
            "Connection: keep-alive\r\n"
            "Accept-Ranges: bytes\r\n"
            "\r\n",
            content_type, st.st_size, date_buf);

        conn->response_header = header;
        conn->header_sent = 0;
        conn->state = ConnState::SENDING_RESPONSE;

        // 启用TCP_CORK
        int cork = 1;
        setsockopt(conn->fd, IPPROTO_TCP, TCP_CORK, &cork, sizeof(cork));

        // 注册写事件
        struct epoll_event ev;
        ev.events = EPOLLOUT | EPOLLET;
        ev.data.fd = conn->fd;
        epoll_ctl(epfd_, EPOLL_CTL_MOD, conn->fd, &ev);

        // 立即尝试发送
        handle_write(conn);
    }

    void handle_write(std::shared_ptr<Connection>& conn) {
        // 发送响应头
        while (conn->header_sent < conn->response_header.length()) {
            ssize_t n = write(conn->fd,
                             conn->response_header.c_str() + conn->header_sent,
                             conn->response_header.length() - conn->header_sent);

            if (n < 0) {
                if (errno == EAGAIN) return;
                close_connection(conn->fd);
                return;
            }

            conn->header_sent += n;
        }

        // 使用sendfile发送文件
        if (conn->file_fd >= 0 && conn->file_sent < conn->file_size) {
            while (conn->file_sent < conn->file_size) {
                size_t to_send = std::min(conn->file_size - conn->file_sent,
                                         (size_t)(1024 * 1024));  // 1MB chunks

                ssize_t sent = sendfile(conn->fd, conn->file_fd,
                                        &conn->file_offset, to_send);

                if (sent < 0) {
                    if (errno == EAGAIN) return;
                    close_connection(conn->fd);
                    return;
                }

                if (sent == 0) break;

                conn->file_sent += sent;
                total_bytes_sent_ += sent;
            }
        }

        // 检查是否完成
        if (conn->header_sent >= conn->response_header.length() &&
            conn->file_sent >= conn->file_size) {

            // 关闭TCP_CORK
            int cork = 0;
            setsockopt(conn->fd, IPPROTO_TCP, TCP_CORK, &cork, sizeof(cork));

            conn->state = ConnState::DONE;
            total_requests_++;

            // Keep-alive：重置连接状态，等待下一个请求
            conn->reset();

            struct epoll_event ev;
            ev.events = EPOLLIN | EPOLLET;
            ev.data.fd = conn->fd;
            epoll_ctl(epfd_, EPOLL_CTL_MOD, conn->fd, &ev);
        }
    }

    void send_error(std::shared_ptr<Connection>& conn, int code,
                   const char* message) {
        char response[512];
        int len = snprintf(response, sizeof(response),
            "HTTP/1.1 %d %s\r\n"
            "Content-Type: text/html\r\n"
            "Content-Length: %zu\r\n"
            "Connection: close\r\n"
            "\r\n"
            "<html><body><h1>%d %s</h1></body></html>",
            code, message, strlen(message) + 40, code, message);

        write(conn->fd, response, len);
        close_connection(conn->fd);
    }

    void send_directory_listing(std::shared_ptr<Connection>& conn,
                               const std::string& dir_path,
                               const char* url_path) {
        std::string html = "<html><head><title>Index of ";
        html += url_path;
        html += "</title></head><body><h1>Index of ";
        html += url_path;
        html += "</h1><hr><pre>";

        DIR* dir = opendir(dir_path.c_str());
        if (dir) {
            struct dirent* entry;
            while ((entry = readdir(dir)) != nullptr) {
                html += "<a href=\"";
                html += entry->d_name;
                if (entry->d_type == DT_DIR) html += "/";
                html += "\">";
                html += entry->d_name;
                if (entry->d_type == DT_DIR) html += "/";
                html += "</a>\n";
            }
            closedir(dir);
        }

        html += "</pre><hr></body></html>";

        char header[512];
        int header_len = snprintf(header, sizeof(header),
            "HTTP/1.1 200 OK\r\n"
            "Content-Type: text/html\r\n"
            "Content-Length: %zu\r\n"
            "\r\n",
            html.length());

        write(conn->fd, header, header_len);
        write(conn->fd, html.c_str(), html.length());

        conn->reset();
    }

    const char* get_content_type(const std::string& path) {
        size_t dot = path.rfind('.');
        if (dot == std::string::npos) return "application/octet-stream";

        std::string ext = path.substr(dot);

        if (ext == ".html" || ext == ".htm") return "text/html";
        if (ext == ".css") return "text/css";
        if (ext == ".js") return "application/javascript";
        if (ext == ".json") return "application/json";
        if (ext == ".png") return "image/png";
        if (ext == ".jpg" || ext == ".jpeg") return "image/jpeg";
        if (ext == ".gif") return "image/gif";
        if (ext == ".svg") return "image/svg+xml";
        if (ext == ".pdf") return "application/pdf";
        if (ext == ".txt") return "text/plain";
        if (ext == ".mp4") return "video/mp4";
        if (ext == ".mp3") return "audio/mpeg";

        return "application/octet-stream";
    }

    void close_connection(int fd) {
        epoll_ctl(epfd_, EPOLL_CTL_DEL, fd, nullptr);
        connections_.erase(fd);
    }

private:
    int port_;
    std::string root_dir_;
    int epfd_ = -1;
    int listen_fd_ = -1;
    std::atomic<bool> running_{false};
    std::unordered_map<int, std::shared_ptr<Connection>> connections_;

    // 统计信息
    std::atomic<uint64_t> total_connections_{0};
    std::atomic<uint64_t> total_requests_{0};
    std::atomic<uint64_t> total_bytes_sent_{0};
};

int main(int argc, char* argv[]) {
    if (argc < 3) {
        printf("Usage: %s <port> <root_dir>\n", argv[0]);
        printf("Example: %s 8080 /var/www/html\n", argv[0]);
        return 1;
    }

    int port = atoi(argv[1]);
    const char* root_dir = argv[2];

    SendfileFileServer server(port, root_dir);

    if (!server.start()) {
        fprintf(stderr, "Failed to start server\n");
        return 1;
    }

    server.run();

    return 0;
}
```

#### 示例11：sendfile性能对比测试

```cpp
// sendfile_benchmark.cpp
// 示例11：sendfile vs read/write 性能对比测试
// 编译：g++ -std=c++17 -O2 -pthread -o sendfile_bench sendfile_benchmark.cpp

#include <sys/sendfile.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <unistd.h>
#include <cstdio>
#include <cstring>
#include <chrono>
#include <vector>
#include <thread>
#include <atomic>
#include <functional>

// 清除Page Cache（需要root权限）
void drop_caches() {
    sync();
    int fd = open("/proc/sys/vm/drop_caches", O_WRONLY);
    if (fd >= 0) {
        write(fd, "3", 1);
        close(fd);
        printf("Page cache dropped\n");
    } else {
        printf("Warning: Cannot drop caches (need root)\n");
    }
}

// 创建测试文件
void create_test_file(const char* filename, size_t size) {
    int fd = open(filename, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) {
        perror("create file");
        return;
    }

    // 使用随机数据填充
    std::vector<char> buffer(1024 * 1024);  // 1MB buffer
    for (size_t i = 0; i < buffer.size(); i++) {
        buffer[i] = rand() % 256;
    }

    size_t written = 0;
    while (written < size) {
        size_t to_write = std::min(buffer.size(), size - written);
        write(fd, buffer.data(), to_write);
        written += to_write;
    }

    fsync(fd);
    close(fd);

    printf("Created test file: %s (%zu MB)\n", filename, size / (1024*1024));
}

// 创建socket pair用于测试
bool create_socket_pair(int& server_fd, int& client_fd, int port) {
    server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) return false;

    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(port);

    if (bind(server_fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        close(server_fd);
        return false;
    }

    listen(server_fd, 1);

    // 创建客户端连接
    std::thread client_thread([&client_fd, port]() {
        client_fd = socket(AF_INET, SOCK_STREAM, 0);
        struct sockaddr_in addr;
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = inet_addr("127.0.0.1");
        addr.sin_port = htons(port);
        connect(client_fd, (struct sockaddr*)&addr, sizeof(addr));
    });

    int accepted_fd = accept(server_fd, nullptr, nullptr);
    client_thread.join();

    close(server_fd);
    server_fd = accepted_fd;

    // 设置大的socket缓冲区
    int buf_size = 16 * 1024 * 1024;  // 16MB
    setsockopt(server_fd, SOL_SOCKET, SO_SNDBUF, &buf_size, sizeof(buf_size));
    setsockopt(client_fd, SOL_SOCKET, SO_RCVBUF, &buf_size, sizeof(buf_size));

    return true;
}

// 基准测试结果
struct BenchmarkResult {
    std::string method;
    double throughput_mbps;
    double cpu_time_ms;
    int context_switches;
};

class SendfileBenchmark {
public:
    // 传统read/write方式
    static BenchmarkResult bench_read_write(int socket_fd, const char* filename,
                                           size_t buffer_size) {
        BenchmarkResult result;
        result.method = "read/write (buf=" + std::to_string(buffer_size/1024) + "KB)";

        int file_fd = open(filename, O_RDONLY);
        if (file_fd < 0) return result;

        struct stat st;
        fstat(file_fd, &st);
        size_t file_size = st.st_size;

        std::vector<char> buffer(buffer_size);

        auto start = std::chrono::high_resolution_clock::now();

        size_t total_sent = 0;
        ssize_t bytes_read;
        while ((bytes_read = read(file_fd, buffer.data(), buffer_size)) > 0) {
            ssize_t bytes_written = 0;
            while (bytes_written < bytes_read) {
                ssize_t n = write(socket_fd, buffer.data() + bytes_written,
                                  bytes_read - bytes_written);
                if (n <= 0) break;
                bytes_written += n;
            }
            total_sent += bytes_written;
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::microseconds>(
            end - start);

        close(file_fd);

        result.throughput_mbps = (file_size / (1024.0 * 1024.0)) /
                                 (duration.count() / 1000000.0);
        result.cpu_time_ms = duration.count() / 1000.0;

        return result;
    }

    // sendfile方式
    static BenchmarkResult bench_sendfile(int socket_fd, const char* filename,
                                         size_t chunk_size = 0) {
        BenchmarkResult result;
        if (chunk_size > 0) {
            result.method = "sendfile (chunk=" +
                           std::to_string(chunk_size/1024) + "KB)";
        } else {
            result.method = "sendfile (unlimited)";
        }

        int file_fd = open(filename, O_RDONLY);
        if (file_fd < 0) return result;

        struct stat st;
        fstat(file_fd, &st);
        size_t file_size = st.st_size;

        auto start = std::chrono::high_resolution_clock::now();

        off_t offset = 0;
        size_t total_sent = 0;

        while (total_sent < file_size) {
            size_t to_send = file_size - total_sent;
            if (chunk_size > 0 && to_send > chunk_size) {
                to_send = chunk_size;
            }

            ssize_t sent = sendfile(socket_fd, file_fd, &offset, to_send);
            if (sent <= 0) break;
            total_sent += sent;
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::microseconds>(
            end - start);

        close(file_fd);

        result.throughput_mbps = (file_size / (1024.0 * 1024.0)) /
                                 (duration.count() / 1000000.0);
        result.cpu_time_ms = duration.count() / 1000.0;

        return result;
    }

    // mmap + write方式
    static BenchmarkResult bench_mmap_write(int socket_fd, const char* filename,
                                           size_t buffer_size) {
        BenchmarkResult result;
        result.method = "mmap+write (buf=" + std::to_string(buffer_size/1024) + "KB)";

        int file_fd = open(filename, O_RDONLY);
        if (file_fd < 0) return result;

        struct stat st;
        fstat(file_fd, &st);
        size_t file_size = st.st_size;

        // mmap整个文件
        void* mapped = mmap(nullptr, file_size, PROT_READ,
                           MAP_PRIVATE, file_fd, 0);
        if (mapped == MAP_FAILED) {
            close(file_fd);
            return result;
        }

        // 预取到内存
        madvise(mapped, file_size, MADV_SEQUENTIAL);
        madvise(mapped, file_size, MADV_WILLNEED);

        auto start = std::chrono::high_resolution_clock::now();

        size_t total_sent = 0;
        while (total_sent < file_size) {
            size_t to_send = std::min(buffer_size, file_size - total_sent);
            ssize_t sent = write(socket_fd, (char*)mapped + total_sent, to_send);
            if (sent <= 0) break;
            total_sent += sent;
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::microseconds>(
            end - start);

        munmap(mapped, file_size);
        close(file_fd);

        result.throughput_mbps = (file_size / (1024.0 * 1024.0)) /
                                 (duration.count() / 1000000.0);
        result.cpu_time_ms = duration.count() / 1000.0;

        return result;
    }
};

// 接收线程：消费发送的数据
void receiver_thread(int socket_fd, std::atomic<bool>& running,
                    std::atomic<size_t>& bytes_received) {
    std::vector<char> buffer(1024 * 1024);  // 1MB buffer

    while (running) {
        ssize_t n = read(socket_fd, buffer.data(), buffer.size());
        if (n <= 0) break;
        bytes_received += n;
    }
}

int main(int argc, char* argv[]) {
    const char* test_file = "/tmp/sendfile_test.dat";
    size_t file_sizes[] = {1*1024*1024, 10*1024*1024, 100*1024*1024,
                           500*1024*1024};

    printf("=== Sendfile Benchmark ===\n\n");

    for (size_t file_size : file_sizes) {
        printf("\n--- File Size: %zu MB ---\n", file_size / (1024*1024));

        // 创建测试文件
        create_test_file(test_file, file_size);

        std::vector<BenchmarkResult> results;

        // 测试不同方法
        struct TestCase {
            std::function<BenchmarkResult(int, const char*)> func;
            std::string name;
        };

        std::vector<TestCase> tests = {
            {[](int fd, const char* f) {
                return SendfileBenchmark::bench_read_write(fd, f, 4096);
            }, "read/write 4KB"},
            {[](int fd, const char* f) {
                return SendfileBenchmark::bench_read_write(fd, f, 65536);
            }, "read/write 64KB"},
            {[](int fd, const char* f) {
                return SendfileBenchmark::bench_read_write(fd, f, 1024*1024);
            }, "read/write 1MB"},
            {[](int fd, const char* f) {
                return SendfileBenchmark::bench_sendfile(fd, f, 0);
            }, "sendfile unlimited"},
            {[](int fd, const char* f) {
                return SendfileBenchmark::bench_sendfile(fd, f, 1024*1024);
            }, "sendfile 1MB chunks"},
            {[](int fd, const char* f) {
                return SendfileBenchmark::bench_mmap_write(fd, f, 65536);
            }, "mmap+write 64KB"},
            {[](int fd, const char* f) {
                return SendfileBenchmark::bench_mmap_write(fd, f, 1024*1024);
            }, "mmap+write 1MB"},
        };

        int port = 12345;
        for (auto& test : tests) {
            // 预热Page Cache
            {
                int fd = open(test_file, O_RDONLY);
                char buf[4096];
                while (read(fd, buf, sizeof(buf)) > 0);
                close(fd);
            }

            // 创建socket对
            int server_fd, client_fd;
            if (!create_socket_pair(server_fd, client_fd, port++)) {
                printf("Failed to create socket pair\n");
                continue;
            }

            // 启动接收线程
            std::atomic<bool> running{true};
            std::atomic<size_t> bytes_received{0};
            std::thread receiver(receiver_thread, client_fd,
                                std::ref(running), std::ref(bytes_received));

            // 运行测试
            auto result = test.func(server_fd, test_file);
            results.push_back(result);

            // 停止接收
            running = false;
            shutdown(server_fd, SHUT_WR);
            receiver.join();

            close(server_fd);
            close(client_fd);

            printf("%-25s: %8.2f MB/s (%.1f ms)\n",
                   result.method.c_str(), result.throughput_mbps,
                   result.cpu_time_ms);
        }

        // 打印比较结果
        printf("\nComparison (relative to read/write 4KB):\n");
        double baseline = results[0].throughput_mbps;
        for (const auto& r : results) {
            printf("  %-25s: %.2fx\n", r.method.c_str(),
                   r.throughput_mbps / baseline);
        }
    }

    // 清理
    unlink(test_file);

    return 0;
}
```

#### Day 12-14 自测问答

```
Q1: TCP_CORK和TCP_NODELAY有什么区别？何时使用？
A1: TCP_CORK：累积数据，等到足够大或关闭CORK后一起发送
             适用场景：发送HTTP响应（头+体需要合并）
    TCP_NODELAY：禁用Nagle算法，数据立即发送
                适用场景：低延迟场景（如游戏、实时通信）

    Nginx的做法：
    - 发送响应体时开启TCP_CORK
    - 发送完毕后开启TCP_NODELAY确保最后的小数据立即发送

Q2: writev相比多次write有什么优势？
A2: writev可以在一次系统调用中发送多个非连续的缓冲区：
    1. 减少系统调用次数（每次系统调用约100-200ns开销）
    2. 减少上下文切换
    3. 内核可以优化数据发送
    4. 与TCP_CORK配合可以将所有数据合并到少量TCP包中

    典型用法：writev发送HTTP头的各个字段 + sendfile发送文件体

Q3: sendfile_max_chunk参数的作用是什么？
A3: 限制单次sendfile调用发送的最大数据量：
    1. 避免单个连接长时间占用CPU
    2. 让其他连接有机会被处理
    3. 在高并发场景下提高公平性
    4. 防止大文件传输阻塞其他请求

    建议值：
    - 低并发/单连接：0（无限制）
    - 中等并发：1MB-2MB
    - 高并发：512KB-1MB

Q4: 为什么Nginx对大文件使用directio而非sendfile？
A4: sendfile依赖Page Cache，对大文件有问题：
    1. 大文件会占用大量Page Cache，挤出其他文件的缓存
    2. 大文件通常只被访问一次，缓存价值低
    3. 大文件的顺序读取可以利用磁盘预读，不需要缓存

    directio绕过Page Cache：
    1. 不污染Page Cache
    2. 直接从磁盘DMA到用户缓冲区
    3. 适合大文件（如视频）的一次性传输

    Nginx的directio阈值默认为4MB-8MB。

Q5: sendfile性能测试需要注意什么？
A5: 正确的性能测试方法：
    1. 区分冷读取和热读取
       - 冷读取：清除Page Cache后测试（sync; echo 3 > /proc/.../drop_caches）
       - 热读取：预先加载文件到Page Cache
    2. 测试足够大的文件（至少100MB）
    3. 使用大的socket缓冲区，避免成为瓶颈
    4. 测试多次取平均值
    5. 接收端要能消费发送的数据
    6. 考虑网卡速度限制（本地测试应使用loopback）
```

---

### 第二周检验标准

```
第二周自我检验清单：

理论理解：
☐ 能解释sendfile的系统调用签名和参数含义
☐ 能画出sendfile的2次/3次拷贝数据流图
☐ 理解DMA Scatter-Gather如何实现真正的零拷贝
☐ 能说出sendfile的in_fd和out_fd限制
☐ 理解TCP_CORK和TCP_NODELAY的区别和用途
☐ 理解writev与sendfile配合的好处
☐ 能解释sendfile_max_chunk的作用

实践能力：
☐ 能编写基本的sendfile文件发送程序
☐ 能实现大文件的分块sendfile发送
☐ 能处理非阻塞socket的sendfile
☐ 能使用TCP_CORK优化HTTP响应
☐ 能使用writev + sendfile发送复合响应
☐ 能实现支持Range请求的文件服务器
☐ 能进行sendfile性能测试和对比
☐ 能使用epoll + sendfile实现高并发服务器

代码完成：
☐ 示例5: sendfile基本文件发送
☐ 示例6: sendfile大文件分块发送
☐ 示例7: sendfile与非阻塞socket
☐ 示例8: sendfile与TCP_CORK
☐ 示例9: sendfile与writev组合
☐ 示例10: 完整的sendfile文件服务器
☐ 示例11: sendfile性能对比测试
```

---

## 第三周：splice与vmsplice（Day 15-21）

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     第三周学习路线图                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Day 15-16                  Day 17-18                   Day 19-21          │
│  ┌─────────────────┐       ┌─────────────────┐        ┌─────────────────┐  │
│  │ splice原理      │──────▶│ splice应用      │───────▶│ vmsplice高级    │  │
│  │                 │       │                 │        │                 │  │
│  │ • 管道中转机制  │       │ • 零拷贝echo    │        │ • 用户空间发送  │  │
│  │ • 系统调用参数  │       │ • 代理服务器    │        │ • SPLICE_F_GIFT │  │
│  │ • 标志位含义    │       │ • socket转发    │        │ • 组合使用      │  │
│  │ • 管道缓冲区    │       │ • tee数据分流   │        │ • 管道调优      │  │
│  └─────────────────┘       └─────────────────┘        └─────────────────┘  │
│           │                        │                          │             │
│           ▼                        ▼                          ▼             │
│    [示例12: 基本]           [示例13-15: 应用]         [示例16-18: 高级]    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### Day 15-16：splice系统调用（10小时）

#### splice系统调用概述

splice是Linux 2.6.17引入的零拷贝系统调用，它通过管道（pipe）作为中介，在两个文件描述符
之间传输数据，无需将数据复制到用户空间。相比sendfile，splice更加通用。

```
splice系统调用签名：

#include <fcntl.h>

ssize_t splice(int fd_in,          // 输入文件描述符
               off64_t *off_in,     // 输入偏移量（可选）
               int fd_out,          // 输出文件描述符
               off64_t *off_out,    // 输出偏移量（可选）
               size_t len,          // 要传输的字节数
               unsigned int flags); // 标志位

返回值：
- 成功：返回实际传输的字节数
- 返回0：没有数据可传输
- 返回-1：出错，设置errno

关键限制：
- fd_in和fd_out中至少有一个必须是管道（pipe）
- 如果fd_in是管道，off_in必须为NULL
- 如果fd_out是管道，off_out必须为NULL
- 如果fd不是管道但off为NULL，则从当前位置读/写

标志位（flags）：
- SPLICE_F_MOVE：提示内核尝试移动页面而非复制（可能被忽略）
- SPLICE_F_NONBLOCK：非阻塞操作
- SPLICE_F_MORE：后续还有更多数据（类似TCP_CORK）
- SPLICE_F_GIFT：页面所有权转移（用于vmsplice）
```

#### splice的数据流与工作原理

```
splice的核心思想：通过管道作为内核缓冲区中转

传统代理服务器的数据流（4次拷贝）：

Client Socket                                      Server Socket
      │                                                  │
      │ ① DMA读取                                       │
      ▼                                                  │
┌─────────────┐                                         │
│ Socket缓冲区│                                         │
└─────┬───────┘                                         │
      │ ② CPU拷贝到用户空间                             │
      ▼                                                  │
┌─────────────┐      用户空间                           │
│ 用户缓冲区  │ ──────────────                          │
└─────┬───────┘      内核空间                           │
      │ ③ CPU拷贝到内核                                 │
      ▼                                                  │
┌─────────────┐                                         │
│ Socket缓冲区│                                         │
└─────┬───────┘                                         │
      │ ④ DMA写入                                       │
      ▼                                                  ▼
      └─────────────────────────────────────────────────┘


splice零拷贝代理（2次拷贝）：

Client Socket                                      Server Socket
      │                                                  │
      │ ① DMA读取到Socket缓冲区                         │
      ▼                                                  │
┌─────────────┐                                         │
│ Socket缓冲区│                                         │
└─────┬───────┘                                         │
      │ splice(client_fd, NULL, pipe[1], NULL, ...)     │
      │ 只传递页面引用，不复制数据                       │
      ▼                                                  │
┌─────────────┐                                         │
│  管道缓冲区  │ <── 内核中的页面引用                    │
└─────┬───────┘                                         │
      │ splice(pipe[0], NULL, server_fd, NULL, ...)     │
      │ 只传递页面引用，不复制数据                       │
      ▼                                                  │
┌─────────────┐                                         │
│ Socket缓冲区│                                         │
└─────┬───────┘                                         │
      │ ② DMA写入到网卡                                 │
      ▼                                                  ▼
      └─────────────────────────────────────────────────┘

上下文切换：4次（2次splice调用）
数据拷贝：2次（仅DMA，无CPU拷贝）


管道缓冲区结构：

┌────────────────────────────────────────────────────────────────┐
│                        Pipe Buffer                              │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  管道由多个pipe_buffer结构组成（默认16个）                      │
│                                                                │
│  ┌──────────────┐ ┌──────────────┐     ┌──────────────┐        │
│  │ pipe_buffer  │ │ pipe_buffer  │ ... │ pipe_buffer  │        │
│  │   [0]        │ │   [1]        │     │   [15]       │        │
│  │              │ │              │     │              │        │
│  │ page: *      │ │ page: *      │     │ page: NULL   │        │
│  │ offset: 0    │ │ offset: 0    │     │              │        │
│  │ len: 4096    │ │ len: 2048    │     │              │        │
│  │ flags: ...   │ │ flags: ...   │     │              │        │
│  └──────┬───────┘ └──────┬───────┘     └──────────────┘        │
│         │                │                                      │
│         ▼                ▼                                      │
│    ┌─────────┐     ┌─────────┐                                 │
│    │ Page 1  │     │ Page 2  │    <── 物理内存页                │
│    │ (4KB)   │     │ (4KB)   │                                 │
│    └─────────┘     └─────────┘                                 │
│                                                                │
│  默认管道容量：65536 bytes (16 * 4KB)                           │
│  可通过 fcntl(F_SETPIPE_SZ) 调整，最大1MB（需要CAP_SYS_RESOURCE）│
│                                                                │
└────────────────────────────────────────────────────────────────┘

splice的零拷贝原理：
1. splice从source读取时，不复制数据，而是将source的页面引用
   添加到管道的pipe_buffer中
2. splice写入dest时，直接将pipe_buffer中的页面引用传递给dest
3. 整个过程只有页面引用的传递，没有实际的数据复制
4. 页面引用计数机制保证页面不会被过早释放
```

#### splice标志位详解

```
splice标志位及其作用：

┌─────────────────────────────────────────────────────────────────────────────┐
│ 标志位              │ 值    │ 作用                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│ SPLICE_F_MOVE      │ 1     │ 提示内核移动页面而不是复制                     │
│                    │       │ 注意：内核可能忽略此标志                       │
│                    │       │ 在某些情况下可提高性能                         │
├─────────────────────────────────────────────────────────────────────────────┤
│ SPLICE_F_NONBLOCK  │ 2     │ 非阻塞操作                                    │
│                    │       │ 如果没有数据可用，立即返回EAGAIN              │
│                    │       │ 注意：只影响splice本身，不影响fd的阻塞属性     │
├─────────────────────────────────────────────────────────────────────────────┤
│ SPLICE_F_MORE      │ 4     │ 后续还有更多数据要发送                        │
│                    │       │ 类似TCP_CORK的效果                            │
│                    │       │ 用于优化网络传输，减少小包                    │
├─────────────────────────────────────────────────────────────────────────────┤
│ SPLICE_F_GIFT      │ 8     │ 页面所有权转移（仅用于vmsplice）              │
│                    │       │ 用户空间承诺不再访问该页面                    │
│                    │       │ 内核可以直接使用该页面而非复制                │
└─────────────────────────────────────────────────────────────────────────────┘

使用建议：
- 网络转发：SPLICE_F_MOVE | SPLICE_F_MORE
- 非阻塞服务器：SPLICE_F_MOVE | SPLICE_F_NONBLOCK
- 最后一块数据：只用SPLICE_F_MOVE（不带MORE）
```

#### 示例12：splice基本用法

```cpp
// splice_basic.cpp
// 示例12：splice基本用法（socket→pipe→socket）
// 编译：g++ -std=c++17 -O2 -o splice_basic splice_basic.cpp

#define _GNU_SOURCE
#include <fcntl.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <cstdio>
#include <cstring>
#include <cerrno>

// 使用splice从文件发送到socket
ssize_t splice_file_to_socket(int file_fd, int socket_fd, size_t count) {
    // 创建管道
    int pipefd[2];
    if (pipe(pipefd) < 0) {
        perror("pipe");
        return -1;
    }

    // 设置管道大小（可选，提高大文件传输性能）
    fcntl(pipefd[0], F_SETPIPE_SZ, 1024 * 1024);  // 1MB

    ssize_t total_sent = 0;

    while (total_sent < (ssize_t)count) {
        size_t to_splice = count - total_sent;

        // 第一步：file → pipe
        ssize_t n = splice(file_fd, nullptr,      // 从文件当前位置读
                          pipefd[1], nullptr,     // 写入管道
                          to_splice,
                          SPLICE_F_MOVE | SPLICE_F_MORE);

        if (n <= 0) {
            if (n < 0 && errno == EAGAIN) continue;
            break;
        }

        printf("splice file→pipe: %zd bytes\n", n);

        // 第二步：pipe → socket
        ssize_t sent = 0;
        while (sent < n) {
            ssize_t m = splice(pipefd[0], nullptr,    // 从管道读
                              socket_fd, nullptr,     // 写入socket
                              n - sent,
                              SPLICE_F_MOVE | SPLICE_F_MORE);

            if (m <= 0) {
                if (m < 0 && errno == EAGAIN) continue;
                break;
            }

            sent += m;
            printf("splice pipe→socket: %zd bytes\n", m);
        }

        total_sent += sent;
    }

    close(pipefd[0]);
    close(pipefd[1]);

    return total_sent;
}

// 使用splice从socket读取到文件
ssize_t splice_socket_to_file(int socket_fd, int file_fd, size_t count) {
    int pipefd[2];
    if (pipe(pipefd) < 0) {
        return -1;
    }

    ssize_t total_received = 0;

    while (total_received < (ssize_t)count) {
        // socket → pipe
        ssize_t n = splice(socket_fd, nullptr,
                          pipefd[1], nullptr,
                          count - total_received,
                          SPLICE_F_MOVE);

        if (n <= 0) {
            if (n < 0 && errno == EAGAIN) continue;
            break;
        }

        // pipe → file
        ssize_t written = 0;
        while (written < n) {
            ssize_t m = splice(pipefd[0], nullptr,
                              file_fd, nullptr,
                              n - written,
                              SPLICE_F_MOVE);

            if (m <= 0) break;
            written += m;
        }

        total_received += written;
    }

    close(pipefd[0]);
    close(pipefd[1]);

    return total_received;
}

// socket到socket的直接转发（最常用场景）
ssize_t splice_socket_to_socket(int in_socket, int out_socket, size_t count) {
    int pipefd[2];
    if (pipe(pipefd) < 0) {
        return -1;
    }

    // 增大管道缓冲区
    int pipe_size = fcntl(pipefd[0], F_GETPIPE_SZ);
    printf("Default pipe size: %d bytes\n", pipe_size);

    // 尝试增大到1MB
    int new_size = fcntl(pipefd[0], F_SETPIPE_SZ, 1024 * 1024);
    if (new_size > 0) {
        printf("New pipe size: %d bytes\n", new_size);
    }

    ssize_t total = 0;
    unsigned int flags = SPLICE_F_MOVE | SPLICE_F_NONBLOCK;

    while (count == 0 || total < (ssize_t)count) {
        // in_socket → pipe
        ssize_t n = splice(in_socket, nullptr,
                          pipefd[1], nullptr,
                          65536,  // 每次最多64KB
                          flags);

        if (n < 0) {
            if (errno == EAGAIN) {
                // 非阻塞模式，没有数据
                usleep(1000);
                continue;
            }
            perror("splice in");
            break;
        }

        if (n == 0) {
            // 连接关闭
            printf("Connection closed by peer\n");
            break;
        }

        // pipe → out_socket
        ssize_t sent = 0;
        while (sent < n) {
            ssize_t m = splice(pipefd[0], nullptr,
                              out_socket, nullptr,
                              n - sent,
                              flags);

            if (m < 0) {
                if (errno == EAGAIN) {
                    usleep(1000);
                    continue;
                }
                perror("splice out");
                break;
            }

            sent += m;
        }

        total += sent;
        printf("\rTransferred: %zd bytes", total);
        fflush(stdout);
    }

    printf("\n");

    close(pipefd[0]);
    close(pipefd[1]);

    return total;
}

// 演示：文件服务器使用splice发送文件
void demo_file_server(int port, const char* filename) {
    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(port);

    bind(server_fd, (struct sockaddr*)&addr, sizeof(addr));
    listen(server_fd, 5);

    printf("Server listening on port %d\n", port);
    printf("Serving file: %s\n", filename);

    while (true) {
        int client_fd = accept(server_fd, nullptr, nullptr);
        if (client_fd < 0) continue;

        printf("Client connected\n");

        int file_fd = open(filename, O_RDONLY);
        if (file_fd < 0) {
            close(client_fd);
            continue;
        }

        struct stat st;
        fstat(file_fd, &st);

        ssize_t sent = splice_file_to_socket(file_fd, client_fd, st.st_size);
        printf("Total sent: %zd bytes\n", sent);

        close(file_fd);
        close(client_fd);
    }

    close(server_fd);
}

int main(int argc, char* argv[]) {
    if (argc < 3) {
        printf("Usage: %s <filename> <port>\n", argv[0]);
        printf("Example: %s test.txt 8080\n", argv[0]);
        return 1;
    }

    demo_file_server(atoi(argv[2]), argv[1]);

    return 0;
}
```

#### Day 15-16 自测问答

```
Q1: splice和sendfile有什么区别？
A1: 主要区别：
    ┌──────────────┬─────────────────────┬─────────────────────┐
    │ 特性          │ sendfile            │ splice              │
    ├──────────────┼─────────────────────┼─────────────────────┤
    │ 引入版本      │ Linux 2.2           │ Linux 2.6.17        │
    │ 输入fd限制    │ 必须是文件          │ 至少一端是管道       │
    │ 输出fd限制    │ 2.6.33前必须是socket│ 至少一端是管道       │
    │ 中介          │ 无（直接传输）      │ 需要管道作为中介     │
    │ 适用场景      │ 文件→socket         │ 任意fd之间          │
    │ 系统调用次数  │ 1次                 │ 通常需要2次         │
    │ 灵活性        │ 较低                │ 较高                │
    └──────────────┴─────────────────────┴─────────────────────┘

Q2: 为什么splice需要管道作为中介？
A2: 管道在splice中的作用：
    1. 提供统一的内核缓冲区抽象
    2. 管道的pipe_buffer可以存储页面引用
    3. 允许不同类型的fd之间传输数据
    4. 支持页面引用的传递而非复制
    没有管道，内核无法在任意两个fd之间建立零拷贝传输路径。

Q3: SPLICE_F_MOVE标志有什么作用？
A3: SPLICE_F_MOVE提示内核：
    1. 尝试移动页面而不是复制
    2. 如果页面只有一个引用，可以直接移动
    3. 如果页面有多个引用，仍然会复制
    注意：这只是一个"提示"，内核可能会忽略。
    实际效果取决于页面的引用计数和内存对齐情况。

Q4: 管道缓冲区大小如何影响splice性能？
A4: 管道缓冲区大小的影响：
    - 默认大小：65536 bytes (16 * 4KB)
    - 缓冲区越大，单次splice可传输的数据越多
    - 减少splice系统调用次数
    - 调整方法：fcntl(pipefd, F_SETPIPE_SZ, new_size)
    - 最大值：通常1MB（需要CAP_SYS_RESOURCE权限可达更大）
    建议：大数据传输时增大管道缓冲区。

Q5: splice在非阻塞模式下需要注意什么？
A5: 非阻塞splice的注意事项：
    1. SPLICE_F_NONBLOCK只影响splice操作本身
    2. 底层fd的阻塞属性不受影响
    3. 返回EAGAIN时需要等待再重试
    4. 需要正确处理partial splice（部分传输）
    5. 通常配合epoll使用，等待fd可读/可写
```

---

### Day 17-18：splice应用场景（10小时）

#### 示例13：splice零拷贝echo服务器

```cpp
// splice_echo_server.cpp
// 示例13：使用splice实现零拷贝echo服务器
// 编译：g++ -std=c++17 -O2 -o splice_echo splice_echo_server.cpp

#define _GNU_SOURCE
#include <fcntl.h>
#include <sys/socket.h>
#include <sys/epoll.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <cstdio>
#include <cstring>
#include <cerrno>
#include <unordered_map>
#include <memory>

// 连接上下文
struct EchoConnection {
    int client_fd;
    int pipe_read;   // pipe[0]
    int pipe_write;  // pipe[1]
    size_t pipe_data;  // 管道中的数据量

    EchoConnection(int fd) : client_fd(fd), pipe_data(0) {
        int pipefd[2];
        if (pipe2(pipefd, O_NONBLOCK) == 0) {
            pipe_read = pipefd[0];
            pipe_write = pipefd[1];
            // 增大管道缓冲区
            fcntl(pipe_read, F_SETPIPE_SZ, 256 * 1024);
        } else {
            pipe_read = pipe_write = -1;
        }
    }

    ~EchoConnection() {
        if (client_fd >= 0) close(client_fd);
        if (pipe_read >= 0) close(pipe_read);
        if (pipe_write >= 0) close(pipe_write);
    }

    // 从socket读取到管道
    ssize_t read_to_pipe() {
        ssize_t n = splice(client_fd, nullptr,
                          pipe_write, nullptr,
                          65536,
                          SPLICE_F_MOVE | SPLICE_F_NONBLOCK);

        if (n > 0) {
            pipe_data += n;
        }
        return n;
    }

    // 从管道写回到socket
    ssize_t write_from_pipe() {
        if (pipe_data == 0) return 0;

        ssize_t n = splice(pipe_read, nullptr,
                          client_fd, nullptr,
                          pipe_data,
                          SPLICE_F_MOVE | SPLICE_F_NONBLOCK);

        if (n > 0) {
            pipe_data -= n;
        }
        return n;
    }

    bool has_pending_data() const {
        return pipe_data > 0;
    }
};

class SpliceEchoServer {
public:
    SpliceEchoServer(int port) : port_(port) {
        epfd_ = epoll_create1(EPOLL_CLOEXEC);
    }

    ~SpliceEchoServer() {
        if (epfd_ >= 0) close(epfd_);
        if (listen_fd_ >= 0) close(listen_fd_);
    }

    bool start() {
        listen_fd_ = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK, 0);
        if (listen_fd_ < 0) return false;

        int opt = 1;
        setsockopt(listen_fd_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

        struct sockaddr_in addr;
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = INADDR_ANY;
        addr.sin_port = htons(port_);

        if (bind(listen_fd_, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
            return false;
        }

        if (listen(listen_fd_, SOMAXCONN) < 0) {
            return false;
        }

        struct epoll_event ev;
        ev.events = EPOLLIN;
        ev.data.fd = listen_fd_;
        epoll_ctl(epfd_, EPOLL_CTL_ADD, listen_fd_, &ev);

        printf("Splice Echo Server started on port %d\n", port_);
        return true;
    }

    void run() {
        running_ = true;
        std::vector<epoll_event> events(1024);

        while (running_) {
            int n = epoll_wait(epfd_, events.data(), events.size(), 100);

            for (int i = 0; i < n; i++) {
                int fd = events[i].data.fd;
                uint32_t revents = events[i].events;

                if (fd == listen_fd_) {
                    handle_accept();
                } else {
                    auto it = connections_.find(fd);
                    if (it == connections_.end()) continue;

                    auto& conn = it->second;

                    if (revents & EPOLLIN) {
                        handle_read(conn);
                    }
                    if (revents & EPOLLOUT) {
                        handle_write(conn);
                    }
                    if (revents & (EPOLLERR | EPOLLHUP)) {
                        close_connection(fd);
                    }
                }
            }
        }
    }

    void stop() { running_ = false; }

private:
    void handle_accept() {
        while (true) {
            int client_fd = accept4(listen_fd_, nullptr, nullptr,
                                    SOCK_NONBLOCK);
            if (client_fd < 0) {
                if (errno == EAGAIN) break;
                continue;
            }

            auto conn = std::make_shared<EchoConnection>(client_fd);
            connections_[client_fd] = conn;

            struct epoll_event ev;
            ev.events = EPOLLIN | EPOLLET;
            ev.data.fd = client_fd;
            epoll_ctl(epfd_, EPOLL_CTL_ADD, client_fd, &ev);

            printf("New connection: fd=%d\n", client_fd);
        }
    }

    void handle_read(std::shared_ptr<EchoConnection>& conn) {
        while (true) {
            ssize_t n = conn->read_to_pipe();

            if (n < 0) {
                if (errno == EAGAIN) break;
                close_connection(conn->client_fd);
                return;
            }

            if (n == 0) {
                // 连接关闭
                close_connection(conn->client_fd);
                return;
            }

            total_bytes_ += n;
        }

        // 如果有数据要发送，注册写事件
        if (conn->has_pending_data()) {
            struct epoll_event ev;
            ev.events = EPOLLIN | EPOLLOUT | EPOLLET;
            ev.data.fd = conn->client_fd;
            epoll_ctl(epfd_, EPOLL_CTL_MOD, conn->client_fd, &ev);

            // 立即尝试写
            handle_write(conn);
        }
    }

    void handle_write(std::shared_ptr<EchoConnection>& conn) {
        while (conn->has_pending_data()) {
            ssize_t n = conn->write_from_pipe();

            if (n < 0) {
                if (errno == EAGAIN) break;
                close_connection(conn->client_fd);
                return;
            }

            if (n == 0) break;
        }

        // 如果数据已全部发送，取消写事件
        if (!conn->has_pending_data()) {
            struct epoll_event ev;
            ev.events = EPOLLIN | EPOLLET;
            ev.data.fd = conn->client_fd;
            epoll_ctl(epfd_, EPOLL_CTL_MOD, conn->client_fd, &ev);
        }
    }

    void close_connection(int fd) {
        epoll_ctl(epfd_, EPOLL_CTL_DEL, fd, nullptr);
        connections_.erase(fd);
        printf("Connection closed: fd=%d, total bytes: %zu\n", fd, total_bytes_);
    }

private:
    int port_;
    int epfd_ = -1;
    int listen_fd_ = -1;
    bool running_ = false;
    std::unordered_map<int, std::shared_ptr<EchoConnection>> connections_;
    size_t total_bytes_ = 0;
};

int main(int argc, char* argv[]) {
    int port = argc > 1 ? atoi(argv[1]) : 8080;

    SpliceEchoServer server(port);
    if (!server.start()) {
        fprintf(stderr, "Failed to start server\n");
        return 1;
    }

    server.run();
    return 0;
}
```

#### 示例14：splice代理服务器

```cpp
// splice_proxy.cpp
// 示例14：使用splice实现零拷贝TCP代理服务器
// 编译：g++ -std=c++17 -O2 -pthread -o splice_proxy splice_proxy.cpp

#define _GNU_SOURCE
#include <fcntl.h>
#include <sys/socket.h>
#include <sys/epoll.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <unistd.h>
#include <cstdio>
#include <cstring>
#include <cerrno>
#include <unordered_map>
#include <memory>
#include <thread>
#include <atomic>

// 双向连接上下文
struct ProxyConnection {
    int client_fd;
    int backend_fd;

    // 客户端→后端的管道
    int c2b_pipe[2];
    size_t c2b_data;

    // 后端→客户端的管道
    int b2c_pipe[2];
    size_t b2c_data;

    bool client_closed;
    bool backend_closed;

    ProxyConnection(int cfd, int bfd)
        : client_fd(cfd), backend_fd(bfd),
          c2b_data(0), b2c_data(0),
          client_closed(false), backend_closed(false) {

        pipe2(c2b_pipe, O_NONBLOCK);
        pipe2(b2c_pipe, O_NONBLOCK);

        // 增大管道缓冲区
        fcntl(c2b_pipe[0], F_SETPIPE_SZ, 256 * 1024);
        fcntl(b2c_pipe[0], F_SETPIPE_SZ, 256 * 1024);
    }

    ~ProxyConnection() {
        if (client_fd >= 0) close(client_fd);
        if (backend_fd >= 0) close(backend_fd);
        close(c2b_pipe[0]); close(c2b_pipe[1]);
        close(b2c_pipe[0]); close(b2c_pipe[1]);
    }

    // 客户端→管道→后端
    ssize_t forward_client_to_backend() {
        // 从客户端读到管道
        ssize_t n = splice(client_fd, nullptr,
                          c2b_pipe[1], nullptr,
                          65536,
                          SPLICE_F_MOVE | SPLICE_F_NONBLOCK);

        if (n > 0) {
            c2b_data += n;
        } else if (n == 0) {
            client_closed = true;
        }

        // 从管道写到后端
        if (c2b_data > 0) {
            ssize_t m = splice(c2b_pipe[0], nullptr,
                              backend_fd, nullptr,
                              c2b_data,
                              SPLICE_F_MOVE | SPLICE_F_NONBLOCK);
            if (m > 0) {
                c2b_data -= m;
            }
        }

        return n;
    }

    // 后端→管道→客户端
    ssize_t forward_backend_to_client() {
        // 从后端读到管道
        ssize_t n = splice(backend_fd, nullptr,
                          b2c_pipe[1], nullptr,
                          65536,
                          SPLICE_F_MOVE | SPLICE_F_NONBLOCK);

        if (n > 0) {
            b2c_data += n;
        } else if (n == 0) {
            backend_closed = true;
        }

        // 从管道写到客户端
        if (b2c_data > 0) {
            ssize_t m = splice(b2c_pipe[0], nullptr,
                              client_fd, nullptr,
                              b2c_data,
                              SPLICE_F_MOVE | SPLICE_F_NONBLOCK);
            if (m > 0) {
                b2c_data -= m;
            }
        }

        return n;
    }

    bool is_closed() const {
        return (client_closed && c2b_data == 0) ||
               (backend_closed && b2c_data == 0);
    }
};

class SpliceProxy {
public:
    SpliceProxy(int listen_port, const char* backend_host, int backend_port)
        : listen_port_(listen_port),
          backend_host_(backend_host),
          backend_port_(backend_port) {
        epfd_ = epoll_create1(EPOLL_CLOEXEC);
    }

    ~SpliceProxy() {
        if (epfd_ >= 0) close(epfd_);
        if (listen_fd_ >= 0) close(listen_fd_);
    }

    bool start() {
        listen_fd_ = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK, 0);
        if (listen_fd_ < 0) return false;

        int opt = 1;
        setsockopt(listen_fd_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

        struct sockaddr_in addr;
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = INADDR_ANY;
        addr.sin_port = htons(listen_port_);

        if (bind(listen_fd_, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
            perror("bind");
            return false;
        }

        if (listen(listen_fd_, SOMAXCONN) < 0) {
            perror("listen");
            return false;
        }

        struct epoll_event ev;
        ev.events = EPOLLIN;
        ev.data.fd = listen_fd_;
        epoll_ctl(epfd_, EPOLL_CTL_ADD, listen_fd_, &ev);

        printf("Splice Proxy started on port %d\n", listen_port_);
        printf("Backend: %s:%d\n", backend_host_.c_str(), backend_port_);

        return true;
    }

    void run() {
        running_ = true;
        std::vector<epoll_event> events(1024);

        while (running_) {
            int n = epoll_wait(epfd_, events.data(), events.size(), 100);

            for (int i = 0; i < n; i++) {
                int fd = events[i].data.fd;
                uint32_t revents = events[i].events;

                if (fd == listen_fd_) {
                    handle_accept();
                    continue;
                }

                // 查找连接
                auto it = fd_to_conn_.find(fd);
                if (it == fd_to_conn_.end()) continue;

                auto& conn = it->second;

                if (revents & EPOLLIN) {
                    if (fd == conn->client_fd) {
                        conn->forward_client_to_backend();
                    } else {
                        conn->forward_backend_to_client();
                    }
                }

                if (revents & EPOLLOUT) {
                    if (fd == conn->client_fd && conn->b2c_data > 0) {
                        conn->forward_backend_to_client();
                    } else if (fd == conn->backend_fd && conn->c2b_data > 0) {
                        conn->forward_client_to_backend();
                    }
                }

                if ((revents & (EPOLLERR | EPOLLHUP)) || conn->is_closed()) {
                    close_connection(conn);
                }
            }
        }
    }

    void stop() { running_ = false; }

private:
    int connect_to_backend() {
        struct hostent* he = gethostbyname(backend_host_.c_str());
        if (!he) return -1;

        int fd = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK, 0);
        if (fd < 0) return -1;

        struct sockaddr_in addr;
        addr.sin_family = AF_INET;
        memcpy(&addr.sin_addr, he->h_addr_list[0], he->h_length);
        addr.sin_port = htons(backend_port_);

        int ret = connect(fd, (struct sockaddr*)&addr, sizeof(addr));
        if (ret < 0 && errno != EINPROGRESS) {
            close(fd);
            return -1;
        }

        return fd;
    }

    void handle_accept() {
        while (true) {
            struct sockaddr_in client_addr;
            socklen_t addr_len = sizeof(client_addr);
            int client_fd = accept4(listen_fd_,
                                   (struct sockaddr*)&client_addr,
                                   &addr_len,
                                   SOCK_NONBLOCK);

            if (client_fd < 0) {
                if (errno == EAGAIN) break;
                continue;
            }

            printf("New connection from %s:%d\n",
                   inet_ntoa(client_addr.sin_addr),
                   ntohs(client_addr.sin_port));

            // 连接后端
            int backend_fd = connect_to_backend();
            if (backend_fd < 0) {
                fprintf(stderr, "Failed to connect to backend\n");
                close(client_fd);
                continue;
            }

            // 创建连接
            auto conn = std::make_shared<ProxyConnection>(client_fd, backend_fd);
            fd_to_conn_[client_fd] = conn;
            fd_to_conn_[backend_fd] = conn;

            // 注册epoll
            struct epoll_event ev;
            ev.events = EPOLLIN | EPOLLOUT | EPOLLET;
            ev.data.fd = client_fd;
            epoll_ctl(epfd_, EPOLL_CTL_ADD, client_fd, &ev);

            ev.data.fd = backend_fd;
            epoll_ctl(epfd_, EPOLL_CTL_ADD, backend_fd, &ev);

            total_connections_++;
        }
    }

    void close_connection(std::shared_ptr<ProxyConnection>& conn) {
        epoll_ctl(epfd_, EPOLL_CTL_DEL, conn->client_fd, nullptr);
        epoll_ctl(epfd_, EPOLL_CTL_DEL, conn->backend_fd, nullptr);
        fd_to_conn_.erase(conn->client_fd);
        fd_to_conn_.erase(conn->backend_fd);
        printf("Connection closed (total: %zu)\n", --total_connections_);
    }

private:
    int listen_port_;
    std::string backend_host_;
    int backend_port_;
    int epfd_ = -1;
    int listen_fd_ = -1;
    bool running_ = false;
    std::unordered_map<int, std::shared_ptr<ProxyConnection>> fd_to_conn_;
    std::atomic<size_t> total_connections_{0};
};

int main(int argc, char* argv[]) {
    if (argc < 4) {
        printf("Usage: %s <listen_port> <backend_host> <backend_port>\n", argv[0]);
        printf("Example: %s 8080 localhost 80\n", argv[0]);
        return 1;
    }

    int listen_port = atoi(argv[1]);
    const char* backend_host = argv[2];
    int backend_port = atoi(argv[3]);

    SpliceProxy proxy(listen_port, backend_host, backend_port);
    if (!proxy.start()) {
        return 1;
    }

    proxy.run();
    return 0;
}
```

#### 示例15：splice + tee数据分流

```cpp
// splice_tee.cpp
// 示例15：使用splice和tee实现数据分流（同时发送到多个目标）
// 编译：g++ -std=c++17 -O2 -o splice_tee splice_tee.cpp

#define _GNU_SOURCE
#include <fcntl.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <cstdio>
#include <cstring>
#include <cerrno>
#include <vector>
#include <array>

/*
tee系统调用：

ssize_t tee(int fd_in, int fd_out, size_t len, unsigned int flags);

功能：在两个管道之间复制数据，但不消费源数据
      （与splice不同，splice会消费数据）

用途：
1. 数据分流：将同一份数据发送到多个目标
2. 数据审计：复制一份到日志文件
3. 流量镜像：网络流量复制

限制：
- fd_in和fd_out都必须是管道
- 不消费源管道中的数据
*/

// 数据分流器：将输入数据同时发送到多个输出
class DataSplitter {
public:
    DataSplitter() {
        // 创建输入管道
        pipe2(input_pipe_, O_NONBLOCK);
        fcntl(input_pipe_[0], F_SETPIPE_SZ, 1024 * 1024);
    }

    ~DataSplitter() {
        close(input_pipe_[0]);
        close(input_pipe_[1]);
        for (auto& p : output_pipes_) {
            close(p[0]);
            close(p[1]);
        }
    }

    // 添加输出目标
    int add_output() {
        int pipefd[2];
        if (pipe2(pipefd, O_NONBLOCK) < 0) {
            return -1;
        }
        fcntl(pipefd[0], F_SETPIPE_SZ, 1024 * 1024);
        output_pipes_.push_back({pipefd[0], pipefd[1]});
        return output_pipes_.size() - 1;
    }

    // 获取输入管道的写端（用于写入数据）
    int get_input_write_fd() const { return input_pipe_[1]; }

    // 获取指定输出管道的读端（用于读取分流后的数据）
    int get_output_read_fd(int index) const {
        if (index < 0 || index >= (int)output_pipes_.size()) return -1;
        return output_pipes_[index][0];
    }

    // 将输入数据分流到所有输出
    ssize_t split() {
        // 检查输入管道是否有数据
        // 注意：我们需要使用tee来复制数据，而不是splice

        ssize_t total = 0;

        for (size_t i = 0; i < output_pipes_.size(); i++) {
            // 使用tee将数据从输入管道复制到输出管道
            // tee不会消费输入管道的数据
            ssize_t n = tee(input_pipe_[0], output_pipes_[i][1],
                           65536, SPLICE_F_NONBLOCK);

            if (n > 0) {
                total += n;
                printf("tee to output %zu: %zd bytes\n", i, n);
            } else if (n < 0 && errno != EAGAIN) {
                perror("tee");
            }
        }

        // 所有输出都复制完成后，消费输入管道的数据
        if (total > 0 && output_pipes_.size() > 0) {
            // 创建一个临时管道来消费数据
            int devnull = open("/dev/null", O_WRONLY);
            if (devnull >= 0) {
                // 使用splice将数据丢弃（或者可以splice到其他地方）
                // 这里我们简单地读取并丢弃
                char buf[65536];
                read(input_pipe_[0], buf, 65536);  // 简化处理
                close(devnull);
            }
        }

        return total;
    }

private:
    int input_pipe_[2];
    std::vector<std::array<int, 2>> output_pipes_;
};

// 演示：简单的tee用法
void demo_simple_tee() {
    printf("\n=== Simple tee Demo ===\n");

    int pipe1[2], pipe2[2];
    pipe(pipe1);
    pipe(pipe2);

    // 写入数据到pipe1
    const char* data = "Data to be tee'd";
    write(pipe1[1], data, strlen(data));

    // 使用tee复制到pipe2
    ssize_t n = tee(pipe1[0], pipe2[1], strlen(data), 0);
    printf("tee copied %zd bytes\n", n);

    // 两个管道都可以读取到数据
    char buf1[64], buf2[64];

    n = read(pipe1[0], buf1, sizeof(buf1) - 1);
    buf1[n] = '\0';
    printf("pipe1 read: %s\n", buf1);

    n = read(pipe2[0], buf2, sizeof(buf2) - 1);
    buf2[n] = '\0';
    printf("pipe2 read: %s\n", buf2);

    close(pipe1[0]); close(pipe1[1]);
    close(pipe2[0]); close(pipe2[1]);
}

int main() {
    demo_simple_tee();
    return 0;
}
```

#### Day 17-18 自测问答

```
Q1: splice零拷贝echo服务器相比传统方式的优势是什么？
A1: 优势：
    1. 零CPU拷贝：数据不经过用户空间，只在内核中传递页面引用
    2. 减少内存带宽占用：不需要复制数据两次（读入+写出）
    3. 减少CPU使用：CPU不参与数据搬运
    4. 更高的吞吐量：特别是大数据量时效果明显

    传统echo：read()→用户缓冲区→write()，2次CPU拷贝
    splice echo：splice(in→pipe)→splice(pipe→out)，0次CPU拷贝

Q2: splice代理服务器需要几个管道？为什么？
A2: 需要2个管道，因为有双向数据流：
    1. 客户端→后端方向：需要一个管道暂存数据
    2. 后端→客户端方向：需要另一个管道暂存数据

    每个方向的数据流：
    socket → pipe → socket
    如果共用一个管道，会造成数据混乱。

Q3: tee和splice有什么区别？
A3: 主要区别：
    ┌──────────────┬─────────────────────┬─────────────────────┐
    │ 特性          │ splice              │ tee                 │
    ├──────────────┼─────────────────────┼─────────────────────┤
    │ 操作          │ 移动数据            │ 复制数据            │
    │ 消费数据      │ 是                  │ 否                  │
    │ fd限制       │ 至少一端是管道      │ 两端都必须是管道    │
    │ 用途          │ 数据传输            │ 数据分流/复制       │
    └──────────────┴─────────────────────┴─────────────────────┘

Q4: 为什么tee只能用于管道之间？
A4: 因为tee的实现依赖于管道的特殊结构：
    1. 管道使用pipe_buffer存储页面引用
    2. tee只是增加页面的引用计数，而不是复制数据
    3. 普通文件和socket没有这种结构
    4. 如果要复制到非管道fd，需要先tee到管道，再splice出去

Q5: 数据分流场景下tee和splice如何配合？
A5: 配合方式：
    1. 数据先写入源管道
    2. 对于前N-1个目标：使用tee复制到各自的管道（不消费源数据）
    3. 对于最后一个目标：使用splice移动数据（消费源数据）
    4. 各个目标管道再splice到最终的fd

    关键点：tee不消费数据，所以可以复制多份；
           最后用splice消费数据，避免数据残留在源管道。
```

---

### Day 19-21：vmsplice与高级用法（15小时）

#### vmsplice系统调用概述

vmsplice是splice家族中最灵活的系统调用，它允许将用户空间内存直接映射到管道，
实现用户空间到内核的零拷贝传输。

```
vmsplice系统调用签名：

#include <fcntl.h>
#include <sys/uio.h>

ssize_t vmsplice(int fd,                    // 管道文件描述符
                 const struct iovec *iov,    // 内存向量数组
                 size_t nr_segs,             // 向量数量
                 unsigned int flags);        // 标志位

返回值：
- 成功：返回映射到管道的字节数
- 失败：返回-1，设置errno

参数说明：
- fd：必须是管道的写端（pipe[1]）
- iov：iovec数组，描述用户空间内存块
- nr_segs：iovec数组的长度
- flags：同splice的标志位

struct iovec {
    void  *iov_base;   // 内存起始地址
    size_t iov_len;    // 内存长度
};

重要限制：
- fd必须是管道
- 内存对齐：最好按页面对齐（4KB）
- 如果使用SPLICE_F_GIFT，用户空间不能再访问该内存
```

#### SPLICE_F_GIFT的含义与使用

```
SPLICE_F_GIFT标志详解：

不使用GIFT（默认）：
┌────────────────────────────────────────────────────────────────┐
│ 用户空间          │           内核空间                         │
│                  │                                            │
│  ┌──────────┐    │    ┌──────────────┐    ┌──────────────┐  │
│  │用户缓冲区│────┼───▶│    复制      │───▶│  管道缓冲区  │  │
│  │  (数据)  │    │    │              │    │   (副本)    │  │
│  └──────────┘    │    └──────────────┘    └──────────────┘  │
│       │          │                                            │
│       ▼          │                                            │
│  用户可以继续    │                                            │
│  使用该内存      │                                            │
└────────────────────────────────────────────────────────────────┘
- 数据会被复制到管道缓冲区
- 用户空间可以继续使用原内存
- 不是真正的零拷贝


使用GIFT：
┌────────────────────────────────────────────────────────────────┐
│ 用户空间          │           内核空间                         │
│                  │                                            │
│  ┌──────────┐    │    ┌──────────────┐                       │
│  │用户缓冲区│────┼───▶│  页面引用    │──▶ 管道缓冲区直接      │
│  │  (数据)  │    │    │ (零拷贝)    │    引用该页面         │
│  └──────────┘    │    └──────────────┘                       │
│       ×          │                                            │
│  用户不能再      │                                            │
│  访问该内存      │                                            │
└────────────────────────────────────────────────────────────────┘
- 页面所有权转移给内核
- 用户空间不能再访问该内存（否则行为未定义）
- 真正的零拷贝
- 通常需要使用posix_memalign分配对齐的内存


GIFT的使用条件：
1. 内存必须是页面对齐的（4096字节对齐）
2. 长度最好是页面大小的整数倍
3. 内存通常需要通过mmap或posix_memalign分配
4. 一旦vmsplice成功，用户空间就不能再使用该内存

典型使用模式：
1. posix_memalign分配对齐内存
2. 填充数据
3. vmsplice with SPLICE_F_GIFT
4. 不再访问该内存
5. 分配新内存用于下一次发送
```

#### 示例16：vmsplice用户空间发送

```cpp
// vmsplice_send.cpp
// 示例16：使用vmsplice从用户空间发送数据
// 编译：g++ -std=c++17 -O2 -o vmsplice_send vmsplice_send.cpp

#define _GNU_SOURCE
#include <fcntl.h>
#include <sys/socket.h>
#include <sys/uio.h>
#include <sys/mman.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <cstdio>
#include <cstring>
#include <cerrno>
#include <cstdlib>
#include <string>

// 页面大小
const size_t PAGE_SIZE = 4096;

// 分配页面对齐的内存
void* aligned_alloc_pages(size_t size) {
    void* ptr = nullptr;
    // 向上取整到页面大小的整数倍
    size = (size + PAGE_SIZE - 1) & ~(PAGE_SIZE - 1);

    if (posix_memalign(&ptr, PAGE_SIZE, size) != 0) {
        return nullptr;
    }

    return ptr;
}

// 不使用GIFT的vmsplice（数据会被复制）
ssize_t vmsplice_send_copy(int socket_fd, const void* data, size_t len) {
    int pipefd[2];
    if (pipe(pipefd) < 0) {
        return -1;
    }

    // 设置管道大小
    fcntl(pipefd[1], F_SETPIPE_SZ, len + PAGE_SIZE);

    struct iovec iov;
    iov.iov_base = const_cast<void*>(data);
    iov.iov_len = len;

    // vmsplice: 用户空间 → 管道（会复制数据）
    ssize_t n = vmsplice(pipefd[1], &iov, 1, SPLICE_F_MORE);

    if (n < 0) {
        perror("vmsplice");
        close(pipefd[0]);
        close(pipefd[1]);
        return -1;
    }

    printf("vmsplice: %zd bytes to pipe\n", n);

    // splice: 管道 → socket
    ssize_t sent = splice(pipefd[0], nullptr,
                         socket_fd, nullptr,
                         n,
                         SPLICE_F_MOVE | SPLICE_F_MORE);

    close(pipefd[0]);
    close(pipefd[1]);

    if (sent < 0) {
        perror("splice");
        return -1;
    }

    printf("splice: %zd bytes to socket\n", sent);
    return sent;
}

// 使用GIFT的vmsplice（真正的零拷贝）
ssize_t vmsplice_send_gift(int socket_fd, void* data, size_t len) {
    int pipefd[2];
    if (pipe(pipefd) < 0) {
        return -1;
    }

    fcntl(pipefd[1], F_SETPIPE_SZ, len + PAGE_SIZE);

    struct iovec iov;
    iov.iov_base = data;
    iov.iov_len = len;

    // 使用SPLICE_F_GIFT：页面所有权转移，不复制
    // 注意：调用后data指向的内存不能再使用！
    ssize_t n = vmsplice(pipefd[1], &iov, 1,
                        SPLICE_F_GIFT | SPLICE_F_MORE);

    if (n < 0) {
        perror("vmsplice with GIFT");
        close(pipefd[0]);
        close(pipefd[1]);
        return -1;
    }

    printf("vmsplice (GIFT): %zd bytes to pipe (zero-copy)\n", n);

    // 此时data的内存已经"送给"内核，不能再访问
    // data = nullptr;  // 防止误用

    // splice: 管道 → socket
    ssize_t sent = splice(pipefd[0], nullptr,
                         socket_fd, nullptr,
                         n,
                         SPLICE_F_MOVE);

    close(pipefd[0]);
    close(pipefd[1]);

    if (sent < 0) {
        perror("splice");
        return -1;
    }

    printf("splice: %zd bytes to socket\n", sent);
    return sent;
}

// HTTP响应发送（header + body使用vmsplice）
class VmspliceHttpSender {
public:
    static ssize_t send_response(int socket_fd,
                                const std::string& header,
                                const void* body,
                                size_t body_len) {
        int pipefd[2];
        if (pipe(pipefd) < 0) return -1;

        fcntl(pipefd[1], F_SETPIPE_SZ, header.size() + body_len + PAGE_SIZE);

        // 准备两个iovec：header和body
        struct iovec iov[2];
        iov[0].iov_base = const_cast<char*>(header.c_str());
        iov[0].iov_len = header.size();
        iov[1].iov_base = const_cast<void*>(body);
        iov[1].iov_len = body_len;

        // vmsplice header和body
        ssize_t n = vmsplice(pipefd[1], iov, 2, SPLICE_F_MORE);

        if (n < 0) {
            close(pipefd[0]);
            close(pipefd[1]);
            return -1;
        }

        // splice到socket
        ssize_t sent = splice(pipefd[0], nullptr,
                             socket_fd, nullptr,
                             n, SPLICE_F_MOVE);

        close(pipefd[0]);
        close(pipefd[1]);

        return sent;
    }
};

// 演示程序
int main(int argc, char* argv[]) {
    if (argc < 2) {
        printf("Usage: %s <port>\n", argv[0]);
        return 1;
    }

    int port = atoi(argv[1]);

    // 创建服务器
    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(port);

    bind(server_fd, (struct sockaddr*)&addr, sizeof(addr));
    listen(server_fd, 5);

    printf("vmsplice demo server on port %d\n", port);

    while (true) {
        int client_fd = accept(server_fd, nullptr, nullptr);
        if (client_fd < 0) continue;

        printf("Client connected\n");

        // 分配页面对齐的内存
        size_t data_size = 64 * 1024;  // 64KB
        void* data = aligned_alloc_pages(data_size);
        if (!data) {
            close(client_fd);
            continue;
        }

        // 填充数据
        memset(data, 'A', data_size);

        // 方式1：不使用GIFT
        printf("\n--- Without GIFT ---\n");
        void* data_copy = aligned_alloc_pages(data_size);
        memset(data_copy, 'B', data_size);
        vmsplice_send_copy(client_fd, data_copy, data_size);
        free(data_copy);  // 可以安全释放

        // 方式2：使用GIFT（真正的零拷贝）
        printf("\n--- With GIFT ---\n");
        void* data_gift = aligned_alloc_pages(data_size);
        memset(data_gift, 'C', data_size);
        vmsplice_send_gift(client_fd, data_gift, data_size);

        // 方式3：HTTP响应
        printf("\n--- HTTP Response ---\n");
        std::string header = "HTTP/1.1 200 OK\r\n"
                            "Content-Length: 1024\r\n"
                            "\r\n";
        char body[1024];
        memset(body, 'D', sizeof(body));

        VmspliceHttpSender::send_response(client_fd, header, body, sizeof(body));

        free(data);
        close(client_fd);
    }

    close(server_fd);
    return 0;
}
```

#### 示例17：管道缓冲区调优

```cpp
// pipe_buffer_tuning.cpp
// 示例17：管道缓冲区大小调优与性能测试
// 编译：g++ -std=c++17 -O2 -o pipe_tuning pipe_buffer_tuning.cpp

#define _GNU_SOURCE
#include <fcntl.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <cstdio>
#include <cstring>
#include <cerrno>
#include <chrono>
#include <vector>
#include <string>

// 获取系统的管道大小限制
void show_pipe_limits() {
    printf("=== System Pipe Limits ===\n");

    // 默认管道大小
    int pipefd[2];
    pipe(pipefd);
    int default_size = fcntl(pipefd[0], F_GETPIPE_SZ);
    printf("Default pipe size: %d bytes (%d KB)\n",
           default_size, default_size / 1024);
    close(pipefd[0]);
    close(pipefd[1]);

    // 最大管道大小（从/proc读取）
    FILE* f = fopen("/proc/sys/fs/pipe-max-size", "r");
    if (f) {
        int max_size;
        fscanf(f, "%d", &max_size);
        fclose(f);
        printf("System max pipe size: %d bytes (%d MB)\n",
               max_size, max_size / (1024 * 1024));
    }
}

// 动态调整管道大小
class DynamicPipe {
public:
    DynamicPipe(int initial_size = 65536) {
        pipe2(pipefd_, O_NONBLOCK);
        current_size_ = fcntl(pipefd_[0], F_SETPIPE_SZ, initial_size);
    }

    ~DynamicPipe() {
        close(pipefd_[0]);
        close(pipefd_[1]);
    }

    // 根据数据量动态调整管道大小
    bool resize_for_data(size_t data_size) {
        // 管道大小应该至少是数据大小的1.5倍
        size_t desired_size = data_size + data_size / 2;

        // 对齐到页面大小
        desired_size = (desired_size + 4095) & ~4095;

        // 限制最大1MB
        if (desired_size > 1024 * 1024) {
            desired_size = 1024 * 1024;
        }

        if (desired_size > (size_t)current_size_) {
            int new_size = fcntl(pipefd_[0], F_SETPIPE_SZ, desired_size);
            if (new_size > 0) {
                current_size_ = new_size;
                return true;
            }
            return false;
        }

        return true;
    }

    int read_fd() const { return pipefd_[0]; }
    int write_fd() const { return pipefd_[1]; }
    int size() const { return current_size_; }

private:
    int pipefd_[2];
    int current_size_;
};

// 最佳实践演示
void best_practices_demo() {
    printf("\n=== Best Practices Demo ===\n");

    // 1. 使用较大的管道减少系统调用
    printf("\n1. Large pipe reduces syscalls:\n");
    {
        int pipefd[2];
        pipe(pipefd);

        // 小管道（默认64KB）
        int small_size = fcntl(pipefd[0], F_GETPIPE_SZ);
        printf("   Default pipe: %d bytes\n", small_size);

        // 大管道（1MB）
        int large_size = fcntl(pipefd[0], F_SETPIPE_SZ, 1024 * 1024);
        printf("   After resize: %d bytes\n", large_size);

        close(pipefd[0]);
        close(pipefd[1]);
    }

    // 2. 使用SPLICE_F_MORE减少网络包
    printf("\n2. SPLICE_F_MORE reduces network packets:\n");
    printf("   Use SPLICE_F_MORE for all but the last splice call\n");

    // 3. 非阻塞管道避免死锁
    printf("\n3. Non-blocking pipe avoids deadlock:\n");
    printf("   Always use O_NONBLOCK with pipes in production\n");

    // 4. 内存对齐提高vmsplice性能
    printf("\n4. Memory alignment for vmsplice:\n");
    printf("   Use page-aligned memory (4096 bytes)\n");
}

int main() {
    show_pipe_limits();
    best_practices_demo();
    return 0;
}
```

#### Day 19-21 自测问答

```
Q1: vmsplice与splice有什么区别？
A1: 主要区别：
    ┌──────────────┬─────────────────────┬─────────────────────┐
    │ 特性          │ splice              │ vmsplice            │
    ├──────────────┼─────────────────────┼─────────────────────┤
    │ 数据来源      │ 文件描述符          │ 用户空间内存        │
    │ 目标          │ 文件描述符（via管道）│ 管道                │
    │ 参数          │ 两个fd + 管道       │ 用户内存iovec + 管道│
    │ 用途          │ fd之间传输          │ 用户空间→管道       │
    │ 零拷贝条件    │ 自动                │ 需要SPLICE_F_GIFT   │
    └──────────────┴─────────────────────┴─────────────────────┘

Q2: SPLICE_F_GIFT的作用是什么？使用时需要注意什么？
A2: SPLICE_F_GIFT的作用：
    - 将内存页面的所有权"赠送"给内核
    - 内核可以直接使用该页面，而不是复制
    - 实现真正的零拷贝

    注意事项：
    1. 内存必须页面对齐（4096字节边界）
    2. 长度最好是页面大小的整数倍
    3. vmsplice后不能再访问该内存（行为未定义）
    4. 通常需要使用内存池来管理对齐的内存

Q3: 如何选择合适的管道缓冲区大小？
A3: 选择原则：
    1. 默认64KB适合小数据量
    2. 大文件传输使用256KB-1MB
    3. 管道大小影响单次splice的数据量
    4. 更大的管道 = 更少的系统调用 = 更高的吞吐量
    5. 但也会占用更多内核内存

    调整方法：
    fcntl(pipefd, F_SETPIPE_SZ, new_size);
    实际大小可能与请求不同，需要检查返回值。

Q4: vmsplice + splice组合的典型使用模式是什么？
A4: 典型模式（用户空间数据发送到网络）：
    1. 分配页面对齐的内存（posix_memalign或mmap）
    2. 填充数据到内存
    3. vmsplice(pipe_write, &iov, 1, flags): 内存→管道
    4. splice(pipe_read, socket_fd, ...): 管道→socket
    5. 重复步骤1-4

Q5: 管道缓冲区耗尽时会发生什么？
A5: 管道缓冲区满时的行为取决于模式：
    阻塞模式：
    - splice/vmsplice会阻塞，直到有空间
    - 可能导致死锁（如果没有消费者）

    非阻塞模式（O_NONBLOCK或SPLICE_F_NONBLOCK）：
    - 返回EAGAIN
    - 需要稍后重试

    最佳实践：
    1. 总是使用非阻塞模式
    2. 配合epoll等待管道可写
    3. 使用足够大的管道减少这种情况
```

---

### 第三周检验标准

```
第三周自我检验清单：

理论理解：
☐ 能解释splice的系统调用签名和参数含义
☐ 理解splice通过管道实现零拷贝的原理
☐ 能说出splice的标志位及其作用
☐ 理解管道缓冲区的结构和工作方式
☐ 能区分splice和sendfile的适用场景
☐ 理解tee与splice的区别
☐ 能解释vmsplice的作用和SPLICE_F_GIFT的含义
☐ 理解内存对齐对vmsplice性能的影响

实践能力：
☐ 能使用splice实现文件到socket的发送
☐ 能使用splice实现socket到socket的转发
☐ 能实现splice零拷贝echo服务器
☐ 能实现splice代理服务器
☐ 能使用tee实现数据分流
☐ 能使用vmsplice从用户空间发送数据
☐ 能正确使用SPLICE_F_GIFT
☐ 能调优管道缓冲区大小

代码完成：
☐ 示例12: splice基本用法
☐ 示例13: splice零拷贝echo服务器
☐ 示例14: splice代理服务器
☐ 示例15: splice + tee数据分流
☐ 示例16: vmsplice用户空间发送
☐ 示例17: 管道缓冲区调优
```

---

## 第四周：mmap与综合实战（Day 22-28）

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     第四周学习路线图                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Day 22-23                  Day 24-25                   Day 26-28          │
│  ┌─────────────────┐       ┌─────────────────┐        ┌─────────────────┐  │
│  │ mmap内存映射    │──────▶│ mmap网络应用    │───────▶│ 综合实战        │  │
│  │                 │       │                 │        │                 │  │
│  │ • 系统调用详解  │       │ • mmap+send     │        │ • 技术对比      │  │
│  │ • PRIVATE/SHARED│       │ • 共享内存      │        │ • 性能基准      │  │
│  │ • madvise优化   │       │ • 文件缓存系统  │        │ • 文件服务器    │  │
│  │ • 与Page Cache  │       │ • 优缺点分析    │        │ • 项目总结      │  │
│  └─────────────────┘       └─────────────────┘        └─────────────────┘  │
│           │                        │                          │             │
│           ▼                        ▼                          ▼             │
│    [示例18-19: 基础]        [示例20-22: 应用]         [示例23-25: 综合]    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### Day 22-23：mmap内存映射（10小时）

#### mmap系统调用概述

mmap（memory map）是将文件或设备映射到进程地址空间的系统调用。
通过mmap，进程可以像访问内存一样访问文件内容，这是另一种实现零拷贝的方式。

```
mmap系统调用签名：

#include <sys/mman.h>

void *mmap(void *addr,        // 建议映射地址（通常为NULL）
           size_t length,     // 映射长度
           int prot,          // 内存保护标志
           int flags,         // 映射类型标志
           int fd,            // 文件描述符
           off_t offset);     // 文件偏移量

返回值：
- 成功：返回映射区域的起始地址
- 失败：返回MAP_FAILED（即(void*)-1）

int munmap(void *addr, size_t length);  // 解除映射


保护标志（prot）：
┌────────────────┬──────────────────────────────────────────┐
│ 标志            │ 含义                                      │
├────────────────┼──────────────────────────────────────────┤
│ PROT_NONE      │ 页面不可访问                              │
│ PROT_READ      │ 页面可读                                  │
│ PROT_WRITE     │ 页面可写                                  │
│ PROT_EXEC      │ 页面可执行                                │
└────────────────┴──────────────────────────────────────────┘


映射标志（flags）：
┌────────────────┬──────────────────────────────────────────┐
│ 标志            │ 含义                                      │
├────────────────┼──────────────────────────────────────────┤
│ MAP_SHARED     │ 共享映射，修改对其他进程可见，写回文件   │
│ MAP_PRIVATE    │ 私有映射，修改使用写时复制，不影响文件   │
│ MAP_ANONYMOUS  │ 匿名映射，不关联文件                      │
│ MAP_FIXED      │ 强制使用指定地址                          │
│ MAP_POPULATE   │ 预先填充页表（预取数据）                  │
│ MAP_HUGETLB    │ 使用大页面                                │
└────────────────┴──────────────────────────────────────────┘
```

#### MAP_PRIVATE vs MAP_SHARED

```
MAP_PRIVATE（写时复制）：

初始状态：
┌────────────────────────────────────────────────────────────┐
│  进程地址空间                        物理内存/Page Cache   │
│                                                            │
│  ┌──────────────┐                    ┌──────────────┐     │
│  │ 虚拟地址页1  │───────────────────▶│ 物理页(原始) │     │
│  └──────────────┘                    └──────────────┘     │
│                                              │             │
│                                              ▼             │
│                                      ┌──────────────┐     │
│                                      │ 磁盘文件     │     │
│                                      └──────────────┘     │
└────────────────────────────────────────────────────────────┘

写入后（Copy-on-Write）：
┌────────────────────────────────────────────────────────────┐
│  进程地址空间                        物理内存              │
│                                                            │
│  ┌──────────────┐                    ┌──────────────┐     │
│  │ 虚拟地址页1  │───────────────────▶│ 物理页(副本) │     │
│  └──────────────┘                    └──────────────┘     │
│                                              ↓ 不写回      │
│                                      ┌──────────────┐     │
│                                      │ 磁盘文件     │     │
│                                      │ (保持原样)   │     │
│                                      └──────────────┘     │
└────────────────────────────────────────────────────────────┘

特点：
- 修改不影响原文件
- 修改不对其他进程可见
- 使用写时复制机制
- 适用于只读访问或临时修改


MAP_SHARED（共享映射）：

┌────────────────────────────────────────────────────────────┐
│  进程A地址空间                       物理内存/Page Cache   │
│                                                            │
│  ┌──────────────┐                    ┌──────────────┐     │
│  │ 虚拟地址页1  │───────┐           │ 物理页      │     │
│  └──────────────┘       │           └──────┬───────┘     │
│                         └──────────────────▶│             │
│  进程B地址空间                              │             │
│                         ┌──────────────────▶│             │
│  ┌──────────────┐       │                   ▼             │
│  │ 虚拟地址页1  │───────┘           ┌──────────────┐     │
│  └──────────────┘                    │ 磁盘文件     │     │
│                                      │ (会被修改)   │     │
│                                      └──────────────┘     │
└────────────────────────────────────────────────────────────┘

特点：
- 修改会写回文件（延迟写或msync）
- 修改对其他映射同一文件的进程可见
- 可用于进程间通信
- 适用于需要持久化修改的场景
```

#### mmap与零拷贝

```
传统read方式（2次拷贝）：

┌─────────────┐    DMA     ┌─────────────┐    CPU     ┌─────────────┐
│  磁盘文件   │──────────▶│ Page Cache  │──────────▶│ 用户缓冲区  │
└─────────────┘   拷贝1    └─────────────┘   拷贝2    └─────────────┘


mmap方式（1次拷贝）：

┌─────────────┐    DMA     ┌─────────────┐
│  磁盘文件   │──────────▶│ Page Cache  │
└─────────────┘   拷贝     └──────┬──────┘
                                  │
                                  │ 直接映射（无拷贝）
                                  ▼
                           ┌─────────────┐
                           │ 用户地址空间│ <── 用户程序直接访问
                           └─────────────┘

mmap的零拷贝原理：
1. mmap只建立虚拟地址到Page Cache的映射
2. 不立即读取数据（除非使用MAP_POPULATE）
3. 访问时触发缺页异常，按需加载
4. 数据直接在Page Cache中，用户程序通过映射访问
5. 省去了从Page Cache到用户缓冲区的拷贝


mmap + write 发送文件（3次拷贝）：

┌─────────────┐    DMA     ┌─────────────┐           ┌─────────────┐
│  磁盘文件   │──────────▶│ Page Cache  │◀─────────│ 用户地址空间│
└─────────────┘   拷贝1    └──────┬──────┘   映射     └──────┬──────┘
                                  │                          │
                                  │ CPU拷贝2                 │ write()
                                  ▼                          │
                           ┌─────────────┐                   │
                           │ Socket缓冲区│◀──────────────────┘
                           └──────┬──────┘
                                  │ DMA拷贝3
                                  ▼
                           ┌─────────────┐
                           │    网卡     │
                           └─────────────┘

拷贝次数：3次（1次DMA读 + 1次CPU拷贝 + 1次DMA写）
比传统read+write的4次少1次
```

#### madvise优化提示

```
madvise系统调用：

int madvise(void *addr, size_t length, int advice);

用于向内核提供关于内存区域使用模式的建议，帮助内核优化。


常用advice值：
┌────────────────────┬───────────────────────────────────────────────┐
│ advice              │ 含义                                           │
├────────────────────┼───────────────────────────────────────────────┤
│ MADV_NORMAL        │ 默认行为                                       │
│ MADV_RANDOM        │ 随机访问，禁用预读                             │
│ MADV_SEQUENTIAL    │ 顺序访问，增强预读                             │
│ MADV_WILLNEED      │ 即将访问，请预取到内存                         │
│ MADV_DONTNEED      │ 不再需要，可以释放物理页面                     │
│ MADV_HUGEPAGE      │ 建议使用大页面（透明大页）                     │
│ MADV_NOHUGEPAGE    │ 禁用大页面                                     │
└────────────────────┴───────────────────────────────────────────────┘

使用示例：

// 顺序读取大文件
void* ptr = mmap(...);
madvise(ptr, file_size, MADV_SEQUENTIAL);  // 顺序访问
madvise(ptr, file_size, MADV_WILLNEED);    // 预取到内存

// 随机访问数据库文件
madvise(ptr, file_size, MADV_RANDOM);      // 禁用预读

// 释放不再需要的页面
madvise(ptr + used_offset, release_size, MADV_DONTNEED);
```

#### 示例18：mmap基本文件操作

```cpp
// mmap_basic.cpp
// 示例18：mmap基本文件操作
// 编译：g++ -std=c++17 -O2 -o mmap_basic mmap_basic.cpp

#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <cstdio>
#include <cstring>
#include <cerrno>
#include <chrono>

class MmapFile {
public:
    MmapFile() = default;

    ~MmapFile() {
        close_file();
    }

    // 打开文件进行读取
    bool open_read(const char* filename) {
        fd_ = open(filename, O_RDONLY);
        if (fd_ < 0) {
            perror("open");
            return false;
        }

        struct stat st;
        if (fstat(fd_, &st) < 0) {
            perror("fstat");
            close(fd_);
            fd_ = -1;
            return false;
        }

        size_ = st.st_size;

        // MAP_PRIVATE用于只读，即使误写也不影响文件
        data_ = mmap(nullptr, size_, PROT_READ, MAP_PRIVATE, fd_, 0);

        if (data_ == MAP_FAILED) {
            perror("mmap");
            close(fd_);
            fd_ = -1;
            return false;
        }

        printf("Mapped file: %s (%zu bytes)\n", filename, size_);
        return true;
    }

    // 打开文件进行读写
    bool open_readwrite(const char* filename) {
        fd_ = open(filename, O_RDWR);
        if (fd_ < 0) {
            perror("open");
            return false;
        }

        struct stat st;
        fstat(fd_, &st);
        size_ = st.st_size;

        // MAP_SHARED用于写入，修改会同步到文件
        data_ = mmap(nullptr, size_, PROT_READ | PROT_WRITE,
                    MAP_SHARED, fd_, 0);

        if (data_ == MAP_FAILED) {
            perror("mmap");
            close(fd_);
            fd_ = -1;
            return false;
        }

        return true;
    }

    // 创建新文件并映射
    bool create(const char* filename, size_t size) {
        fd_ = open(filename, O_RDWR | O_CREAT | O_TRUNC, 0644);
        if (fd_ < 0) {
            perror("open");
            return false;
        }

        // 扩展文件大小
        if (ftruncate(fd_, size) < 0) {
            perror("ftruncate");
            close(fd_);
            fd_ = -1;
            return false;
        }

        size_ = size;

        data_ = mmap(nullptr, size_, PROT_READ | PROT_WRITE,
                    MAP_SHARED, fd_, 0);

        if (data_ == MAP_FAILED) {
            perror("mmap");
            close(fd_);
            fd_ = -1;
            return false;
        }

        return true;
    }

    void close_file() {
        if (data_ && data_ != MAP_FAILED) {
            munmap(data_, size_);
            data_ = nullptr;
        }
        if (fd_ >= 0) {
            close(fd_);
            fd_ = -1;
        }
        size_ = 0;
    }

    // 同步到磁盘
    bool sync() {
        if (!data_) return false;
        return msync(data_, size_, MS_SYNC) == 0;
    }

    // 异步同步
    bool sync_async() {
        if (!data_) return false;
        return msync(data_, size_, MS_ASYNC) == 0;
    }

    // 设置访问模式
    void set_sequential() {
        if (data_) {
            madvise(data_, size_, MADV_SEQUENTIAL);
        }
    }

    void set_random() {
        if (data_) {
            madvise(data_, size_, MADV_RANDOM);
        }
    }

    void prefetch() {
        if (data_) {
            madvise(data_, size_, MADV_WILLNEED);
        }
    }

    void* data() { return data_; }
    const void* data() const { return data_; }
    size_t size() const { return size_; }

private:
    int fd_ = -1;
    void* data_ = nullptr;
    size_t size_ = 0;
};

// 使用mmap读取文件
void demo_mmap_read(const char* filename) {
    printf("\n=== mmap Read Demo ===\n");

    MmapFile file;
    if (!file.open_read(filename)) {
        return;
    }

    // 设置顺序访问模式
    file.set_sequential();

    // 预取数据
    file.prefetch();

    // 访问数据
    const char* data = static_cast<const char*>(file.data());
    size_t size = file.size();

    // 计算简单的校验和
    auto start = std::chrono::high_resolution_clock::now();

    unsigned long checksum = 0;
    for (size_t i = 0; i < size; i++) {
        checksum += (unsigned char)data[i];
    }

    auto end = std::chrono::high_resolution_clock::now();
    auto us = std::chrono::duration_cast<std::chrono::microseconds>(
        end - start).count();

    double mbps = (size / (1024.0 * 1024.0)) / (us / 1000000.0);

    printf("Read %zu bytes, checksum: %lu\n", size, checksum);
    printf("Time: %ld us, Throughput: %.2f MB/s\n", us, mbps);
}

// 使用mmap写入文件
void demo_mmap_write(const char* filename, size_t size) {
    printf("\n=== mmap Write Demo ===\n");

    MmapFile file;
    if (!file.create(filename, size)) {
        return;
    }

    char* data = static_cast<char*>(file.data());

    // 写入数据
    auto start = std::chrono::high_resolution_clock::now();

    for (size_t i = 0; i < size; i++) {
        data[i] = 'A' + (i % 26);
    }

    // 同步到磁盘
    file.sync();

    auto end = std::chrono::high_resolution_clock::now();
    auto us = std::chrono::duration_cast<std::chrono::microseconds>(
        end - start).count();

    double mbps = (size / (1024.0 * 1024.0)) / (us / 1000000.0);

    printf("Wrote %zu bytes\n", size);
    printf("Time: %ld us, Throughput: %.2f MB/s\n", us, mbps);
}

// mmap vs read性能对比
void demo_mmap_vs_read(const char* filename) {
    printf("\n=== mmap vs read Performance ===\n");

    struct stat st;
    if (stat(filename, &st) < 0) {
        printf("File not found\n");
        return;
    }

    size_t size = st.st_size;
    printf("File size: %zu bytes (%.2f MB)\n", size, size / (1024.0 * 1024.0));

    // 方法1：传统read
    {
        int fd = open(filename, O_RDONLY);
        char* buf = new char[size];

        auto start = std::chrono::high_resolution_clock::now();

        size_t total = 0;
        while (total < size) {
            ssize_t n = read(fd, buf + total, size - total);
            if (n <= 0) break;
            total += n;
        }

        // 计算校验和确保数据被访问
        unsigned long checksum = 0;
        for (size_t i = 0; i < size; i++) {
            checksum += (unsigned char)buf[i];
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto us = std::chrono::duration_cast<std::chrono::microseconds>(
            end - start).count();

        printf("read():  %ld us (checksum: %lu)\n", us, checksum);

        delete[] buf;
        close(fd);
    }

    // 清除Page Cache（需要root权限）
    sync();

    // 方法2：mmap
    {
        int fd = open(filename, O_RDONLY);
        void* ptr = mmap(nullptr, size, PROT_READ, MAP_PRIVATE, fd, 0);

        // 预取
        madvise(ptr, size, MADV_SEQUENTIAL);
        madvise(ptr, size, MADV_WILLNEED);

        auto start = std::chrono::high_resolution_clock::now();

        // 计算校验和
        const char* data = static_cast<const char*>(ptr);
        unsigned long checksum = 0;
        for (size_t i = 0; i < size; i++) {
            checksum += (unsigned char)data[i];
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto us = std::chrono::duration_cast<std::chrono::microseconds>(
            end - start).count();

        printf("mmap():  %ld us (checksum: %lu)\n", us, checksum);

        munmap(ptr, size);
        close(fd);
    }
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        printf("Usage: %s <filename>\n", argv[0]);
        printf("       %s --create <filename> <size_mb>\n", argv[0]);
        return 1;
    }

    if (argc == 4 && strcmp(argv[1], "--create") == 0) {
        size_t size_mb = atoi(argv[3]);
        demo_mmap_write(argv[2], size_mb * 1024 * 1024);
    } else {
        demo_mmap_read(argv[1]);
        demo_mmap_vs_read(argv[1]);
    }

    return 0;
}
```

#### 示例19：mmap与Page Cache关系

```cpp
// mmap_page_cache.cpp
// 示例19：mmap与Page Cache的关系演示
// 编译：g++ -std=c++17 -O2 -o mmap_pagecache mmap_page_cache.cpp

#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <cstdio>
#include <cstring>
#include <chrono>
#include <fstream>
#include <string>

// 获取进程的内存映射信息
void show_process_maps(const char* filter = nullptr) {
    std::ifstream maps("/proc/self/maps");
    std::string line;

    printf("\n=== Process Memory Maps ===\n");
    while (std::getline(maps, line)) {
        if (filter == nullptr || line.find(filter) != std::string::npos) {
            printf("%s\n", line.c_str());
        }
    }
}

// 获取Page Cache使用情况
void show_page_cache_status() {
    std::ifstream meminfo("/proc/meminfo");
    std::string line;

    printf("\n=== Page Cache Status ===\n");
    while (std::getline(meminfo, line)) {
        if (line.find("Cached") != std::string::npos ||
            line.find("Buffers") != std::string::npos ||
            line.find("Active(file)") != std::string::npos ||
            line.find("Inactive(file)") != std::string::npos) {
            printf("%s\n", line.c_str());
        }
    }
}

// 演示mmap共享Page Cache
void demo_shared_page_cache(const char* filename) {
    printf("\n=== Shared Page Cache Demo ===\n");

    int fd = open(filename, O_RDONLY);
    if (fd < 0) {
        perror("open");
        return;
    }

    struct stat st;
    fstat(fd, &st);
    size_t size = st.st_size;

    printf("File size: %zu bytes\n", size);

    // 第一次映射
    void* map1 = mmap(nullptr, size, PROT_READ, MAP_SHARED, fd, 0);
    if (map1 == MAP_FAILED) {
        perror("mmap1");
        close(fd);
        return;
    }
    printf("Map1 address: %p\n", map1);

    // 第二次映射（同一文件）
    void* map2 = mmap(nullptr, size, PROT_READ, MAP_SHARED, fd, 0);
    if (map2 == MAP_FAILED) {
        perror("mmap2");
        munmap(map1, size);
        close(fd);
        return;
    }
    printf("Map2 address: %p\n", map2);

    // 虽然虚拟地址不同，但指向同一Page Cache
    printf("\nBoth mappings share the same physical pages (Page Cache)\n");

    // 访问map1，会加载到Page Cache
    printf("\nAccessing through map1...\n");
    volatile char c1 = ((char*)map1)[0];
    (void)c1;

    // 访问map2，直接从Page Cache获取，无需磁盘I/O
    printf("Accessing through map2 (already in Page Cache)...\n");
    volatile char c2 = ((char*)map2)[0];
    (void)c2;

    printf("First char: '%c'\n", ((char*)map1)[0]);

    // 显示内存映射
    show_process_maps(filename);

    munmap(map1, size);
    munmap(map2, size);
    close(fd);
}

// 演示mmap的懒加载（缺页异常）
void demo_lazy_loading(const char* filename) {
    printf("\n=== Lazy Loading (Page Fault) Demo ===\n");

    int fd = open(filename, O_RDONLY);
    if (fd < 0) return;

    struct stat st;
    fstat(fd, &st);
    size_t size = st.st_size;

    // 不使用MAP_POPULATE，采用懒加载
    auto start = std::chrono::high_resolution_clock::now();

    void* ptr = mmap(nullptr, size, PROT_READ, MAP_PRIVATE, fd, 0);

    auto end = std::chrono::high_resolution_clock::now();
    auto mmap_us = std::chrono::duration_cast<std::chrono::microseconds>(
        end - start).count();

    printf("mmap() time (no data loaded): %ld us\n", mmap_us);

    // 首次访问触发缺页异常，加载数据
    start = std::chrono::high_resolution_clock::now();

    volatile unsigned long sum = 0;
    for (size_t i = 0; i < size; i += 4096) {  // 每页访问一次
        sum += ((char*)ptr)[i];
    }
    (void)sum;

    end = std::chrono::high_resolution_clock::now();
    auto access_us = std::chrono::duration_cast<std::chrono::microseconds>(
        end - start).count();

    printf("First access time (page faults): %ld us\n", access_us);

    // 第二次访问（数据已在内存）
    start = std::chrono::high_resolution_clock::now();

    sum = 0;
    for (size_t i = 0; i < size; i += 4096) {
        sum += ((char*)ptr)[i];
    }

    end = std::chrono::high_resolution_clock::now();
    auto second_us = std::chrono::duration_cast<std::chrono::microseconds>(
        end - start).count();

    printf("Second access time (in memory): %ld us\n", second_us);

    munmap(ptr, size);
    close(fd);
}

// 演示MAP_POPULATE预填充
void demo_populate(const char* filename) {
    printf("\n=== MAP_POPULATE Demo ===\n");

    int fd = open(filename, O_RDONLY);
    if (fd < 0) return;

    struct stat st;
    fstat(fd, &st);
    size_t size = st.st_size;

    // 使用MAP_POPULATE预填充
    auto start = std::chrono::high_resolution_clock::now();

    void* ptr = mmap(nullptr, size, PROT_READ,
                    MAP_PRIVATE | MAP_POPULATE, fd, 0);

    auto end = std::chrono::high_resolution_clock::now();
    auto mmap_us = std::chrono::duration_cast<std::chrono::microseconds>(
        end - start).count();

    printf("mmap() with MAP_POPULATE: %ld us\n", mmap_us);
    printf("(Data already loaded during mmap)\n");

    // 访问数据（已在内存）
    start = std::chrono::high_resolution_clock::now();

    volatile unsigned long sum = 0;
    for (size_t i = 0; i < size; i += 4096) {
        sum += ((char*)ptr)[i];
    }
    (void)sum;

    end = std::chrono::high_resolution_clock::now();
    auto access_us = std::chrono::duration_cast<std::chrono::microseconds>(
        end - start).count();

    printf("Access time: %ld us\n", access_us);

    munmap(ptr, size);
    close(fd);
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        printf("Usage: %s <filename>\n", argv[0]);
        return 1;
    }

    const char* filename = argv[1];

    show_page_cache_status();
    demo_shared_page_cache(filename);
    demo_lazy_loading(filename);
    demo_populate(filename);

    return 0;
}
```

#### Day 22-23 自测问答

```
Q1: MAP_PRIVATE和MAP_SHARED有什么区别？
A1: 主要区别：
    MAP_PRIVATE：
    - 使用写时复制（Copy-on-Write）
    - 写入时创建私有副本
    - 修改不影响原文件
    - 修改对其他进程不可见
    - 适用于只读或临时修改

    MAP_SHARED：
    - 共享映射
    - 修改直接反映到文件
    - 修改对其他映射同一文件的进程可见
    - 适用于进程间通信或持久化

Q2: mmap如何实现零拷贝？
A2: mmap的零拷贝机制：
    1. mmap只建立虚拟地址到Page Cache的映射关系
    2. 不实际复制数据到用户缓冲区
    3. 用户程序直接访问Page Cache中的数据
    4. 省去了传统read从Page Cache到用户空间的拷贝
    但注意：mmap + write发送到网络时仍有CPU拷贝到Socket缓冲区

Q3: madvise的MADV_SEQUENTIAL和MADV_RANDOM有什么作用？
A3: 这些是对内核的访问模式提示：
    MADV_SEQUENTIAL：
    - 告诉内核会顺序访问
    - 内核会增强预读（读更多连续页面）
    - 已访问的页面可以更早释放

    MADV_RANDOM：
    - 告诉内核会随机访问
    - 内核禁用预读
    - 避免无用的预读浪费内存

Q4: mmap什么时候触发磁盘I/O？
A4: mmap触发磁盘I/O的时机：
    1. 首次访问未加载的页面（缺页异常）
    2. msync()强制同步时
    3. munmap()时如果有修改
    4. 系统内存压力大，需要回收页面时
    5. 使用MAP_POPULATE时在mmap调用时就加载

Q5: 多个进程mmap同一文件会发生什么？
A5: 多进程映射同一文件的行为：
    1. 所有进程共享同一份Page Cache
    2. 物理内存只有一份（节省内存）
    3. MAP_SHARED：一个进程的修改对其他进程立即可见
    4. MAP_PRIVATE：修改触发COW，各自有私有副本
    5. 这是实现共享内存的一种方式
```

---

### Day 24-25：mmap网络应用（10小时）

#### 示例20：mmap + send文件发送

```cpp
// mmap_send.cpp
// 示例20：使用mmap + send发送文件
// 编译：g++ -std=c++17 -O2 -o mmap_send mmap_send.cpp

#include <sys/mman.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <unistd.h>
#include <cstdio>
#include <cstring>
#include <chrono>

class MmapSender {
public:
    // 使用mmap + write发送文件
    static ssize_t send_file(int socket_fd, const char* filename) {
        int file_fd = open(filename, O_RDONLY);
        if (file_fd < 0) {
            perror("open");
            return -1;
        }

        struct stat st;
        fstat(file_fd, &st);
        size_t file_size = st.st_size;

        // 映射文件
        void* mapped = mmap(nullptr, file_size, PROT_READ,
                           MAP_PRIVATE, file_fd, 0);

        if (mapped == MAP_FAILED) {
            perror("mmap");
            close(file_fd);
            return -1;
        }

        // 优化：设置顺序访问和预取
        madvise(mapped, file_size, MADV_SEQUENTIAL);
        madvise(mapped, file_size, MADV_WILLNEED);

        // 发送数据
        const char* ptr = static_cast<const char*>(mapped);
        ssize_t total_sent = 0;

        while (total_sent < (ssize_t)file_size) {
            ssize_t sent = write(socket_fd, ptr + total_sent,
                                file_size - total_sent);

            if (sent < 0) {
                if (errno == EAGAIN || errno == EWOULDBLOCK) {
                    usleep(1000);
                    continue;
                }
                perror("write");
                break;
            }

            if (sent == 0) break;

            total_sent += sent;
        }

        // 清理
        munmap(mapped, file_size);
        close(file_fd);

        return total_sent;
    }

    // 分块发送大文件（使用滑动窗口）
    static ssize_t send_file_chunked(int socket_fd, const char* filename,
                                    size_t chunk_size = 64 * 1024 * 1024) {
        int file_fd = open(filename, O_RDONLY);
        if (file_fd < 0) return -1;

        struct stat st;
        fstat(file_fd, &st);
        size_t file_size = st.st_size;

        ssize_t total_sent = 0;
        off_t offset = 0;

        while (offset < (off_t)file_size) {
            // 计算本次映射大小
            size_t map_size = std::min(chunk_size, file_size - offset);

            // 映射一个chunk
            void* mapped = mmap(nullptr, map_size, PROT_READ,
                               MAP_PRIVATE, file_fd, offset);

            if (mapped == MAP_FAILED) {
                perror("mmap chunk");
                break;
            }

            madvise(mapped, map_size, MADV_SEQUENTIAL);

            // 发送这个chunk
            const char* ptr = static_cast<const char*>(mapped);
            size_t chunk_sent = 0;

            while (chunk_sent < map_size) {
                ssize_t sent = write(socket_fd, ptr + chunk_sent,
                                    map_size - chunk_sent);

                if (sent < 0) {
                    if (errno == EAGAIN) {
                        usleep(1000);
                        continue;
                    }
                    break;
                }

                if (sent == 0) break;
                chunk_sent += sent;
            }

            total_sent += chunk_sent;
            offset += chunk_sent;

            // 释放这个chunk
            munmap(mapped, map_size);

            printf("\rSent: %zd / %zu bytes (%.1f%%)",
                   total_sent, file_size, 100.0 * total_sent / file_size);
            fflush(stdout);
        }

        printf("\n");
        close(file_fd);
        return total_sent;
    }
};

// mmap + send vs sendfile 性能对比
void benchmark_send_methods(int socket_fd, const char* filename) {
    struct stat st;
    stat(filename, &st);
    size_t file_size = st.st_size;

    printf("\n=== Send Methods Benchmark ===\n");
    printf("File size: %zu bytes (%.2f MB)\n\n",
           file_size, file_size / (1024.0 * 1024.0));

    // 方法1：mmap + write
    {
        auto start = std::chrono::high_resolution_clock::now();

        ssize_t sent = MmapSender::send_file(socket_fd, filename);

        auto end = std::chrono::high_resolution_clock::now();
        auto us = std::chrono::duration_cast<std::chrono::microseconds>(
            end - start).count();

        double mbps = (sent / (1024.0 * 1024.0)) / (us / 1000000.0);
        printf("mmap + write: %zd bytes in %ld us (%.2f MB/s)\n",
               sent, us, mbps);
    }
}

int main(int argc, char* argv[]) {
    if (argc < 3) {
        printf("Usage: %s <filename> <port>\n", argv[0]);
        return 1;
    }

    const char* filename = argv[1];
    int port = atoi(argv[2]);

    // 创建服务器
    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(port);

    bind(server_fd, (struct sockaddr*)&addr, sizeof(addr));
    listen(server_fd, 5);

    printf("mmap send server on port %d\n", port);
    printf("File: %s\n", filename);

    while (true) {
        int client_fd = accept(server_fd, nullptr, nullptr);
        if (client_fd < 0) continue;

        printf("Client connected\n");

        ssize_t sent = MmapSender::send_file(client_fd, filename);
        printf("Sent: %zd bytes\n", sent);

        close(client_fd);
    }

    close(server_fd);
    return 0;
}
```

#### 示例21：共享内存实现

```cpp
// shared_memory.cpp
// 示例21：使用mmap实现共享内存
// 编译：g++ -std=c++17 -O2 -o shared_mem shared_memory.cpp -lpthread

#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <cstdio>
#include <cstring>
#include <atomic>
#include <thread>
#include <chrono>

// 共享内存区域结构
struct SharedBuffer {
    std::atomic<uint64_t> write_pos;   // 写位置
    std::atomic<uint64_t> read_pos;    // 读位置
    std::atomic<bool> writer_done;      // 写入完成标志
    char data[0];                       // 柔性数组

    void init() {
        write_pos = 0;
        read_pos = 0;
        writer_done = false;
    }
};

class SharedMemoryRingBuffer {
public:
    SharedMemoryRingBuffer(const char* name, size_t data_size, bool create)
        : shm_name_(name), data_size_(data_size) {

        total_size_ = sizeof(SharedBuffer) + data_size;

        if (create) {
            // 创建共享内存
            shm_fd_ = shm_open(name, O_CREAT | O_RDWR, 0666);
            if (shm_fd_ < 0) {
                perror("shm_open create");
                return;
            }

            // 设置大小
            if (ftruncate(shm_fd_, total_size_) < 0) {
                perror("ftruncate");
                close(shm_fd_);
                shm_fd_ = -1;
                return;
            }
        } else {
            // 打开已存在的共享内存
            shm_fd_ = shm_open(name, O_RDWR, 0666);
            if (shm_fd_ < 0) {
                perror("shm_open open");
                return;
            }
        }

        // 映射
        buffer_ = static_cast<SharedBuffer*>(
            mmap(nullptr, total_size_, PROT_READ | PROT_WRITE,
                MAP_SHARED, shm_fd_, 0));

        if (buffer_ == MAP_FAILED) {
            perror("mmap");
            close(shm_fd_);
            shm_fd_ = -1;
            buffer_ = nullptr;
            return;
        }

        if (create) {
            buffer_->init();
        }

        printf("Shared memory '%s' %s (size: %zu)\n",
               name, create ? "created" : "opened", data_size_);
    }

    ~SharedMemoryRingBuffer() {
        if (buffer_) {
            munmap(buffer_, total_size_);
        }
        if (shm_fd_ >= 0) {
            close(shm_fd_);
        }
    }

    // 写入数据
    size_t write(const char* data, size_t len) {
        if (!buffer_) return 0;

        uint64_t write_pos = buffer_->write_pos.load(std::memory_order_relaxed);
        uint64_t read_pos = buffer_->read_pos.load(std::memory_order_acquire);

        // 检查可用空间
        size_t available = data_size_ - (write_pos - read_pos);
        if (available == 0) return 0;

        size_t to_write = std::min(len, available);

        // 写入数据（处理环绕）
        size_t pos = write_pos % data_size_;
        size_t first_part = std::min(to_write, data_size_ - pos);

        memcpy(buffer_->data + pos, data, first_part);
        if (to_write > first_part) {
            memcpy(buffer_->data, data + first_part, to_write - first_part);
        }

        buffer_->write_pos.store(write_pos + to_write,
                                std::memory_order_release);

        return to_write;
    }

    // 读取数据
    size_t read(char* data, size_t max_len) {
        if (!buffer_) return 0;

        uint64_t write_pos = buffer_->write_pos.load(std::memory_order_acquire);
        uint64_t read_pos = buffer_->read_pos.load(std::memory_order_relaxed);

        // 检查可读数据
        size_t available = write_pos - read_pos;
        if (available == 0) return 0;

        size_t to_read = std::min(max_len, available);

        // 读取数据（处理环绕）
        size_t pos = read_pos % data_size_;
        size_t first_part = std::min(to_read, data_size_ - pos);

        memcpy(data, buffer_->data + pos, first_part);
        if (to_read > first_part) {
            memcpy(data + first_part, buffer_->data, to_read - first_part);
        }

        buffer_->read_pos.store(read_pos + to_read,
                               std::memory_order_release);

        return to_read;
    }

    void mark_writer_done() {
        if (buffer_) {
            buffer_->writer_done.store(true, std::memory_order_release);
        }
    }

    bool is_writer_done() const {
        return buffer_ && buffer_->writer_done.load(std::memory_order_acquire);
    }

    bool is_empty() const {
        if (!buffer_) return true;
        return buffer_->write_pos.load(std::memory_order_acquire) ==
               buffer_->read_pos.load(std::memory_order_acquire);
    }

    static void unlink(const char* name) {
        shm_unlink(name);
    }

private:
    std::string shm_name_;
    size_t data_size_;
    size_t total_size_;
    int shm_fd_ = -1;
    SharedBuffer* buffer_ = nullptr;
};

// 生产者进程
void producer(const char* shm_name) {
    SharedMemoryRingBuffer shm(shm_name, 1024 * 1024, true);  // 1MB

    printf("Producer: Writing data...\n");

    for (int i = 0; i < 100; i++) {
        char message[128];
        snprintf(message, sizeof(message), "Message %d from producer", i);

        while (shm.write(message, strlen(message) + 1) == 0) {
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
        }

        printf("Producer: Sent '%s'\n", message);
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }

    shm.mark_writer_done();
    printf("Producer: Done\n");
}

// 消费者进程
void consumer(const char* shm_name) {
    // 等待共享内存创建
    std::this_thread::sleep_for(std::chrono::milliseconds(100));

    SharedMemoryRingBuffer shm(shm_name, 1024 * 1024, false);

    printf("Consumer: Reading data...\n");

    char buffer[256];
    int count = 0;

    while (true) {
        size_t n = shm.read(buffer, sizeof(buffer) - 1);

        if (n > 0) {
            buffer[n] = '\0';
            printf("Consumer: Received '%s'\n", buffer);
            count++;
        } else if (shm.is_writer_done() && shm.is_empty()) {
            break;
        } else {
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
        }
    }

    printf("Consumer: Received %d messages\n", count);
}

int main(int argc, char* argv[]) {
    const char* shm_name = "/test_shm";

    if (argc > 1 && strcmp(argv[1], "producer") == 0) {
        producer(shm_name);
    } else if (argc > 1 && strcmp(argv[1], "consumer") == 0) {
        consumer(shm_name);
    } else {
        printf("Usage: %s producer|consumer\n", argv[0]);
        printf("\nDemo: Run in two terminals:\n");
        printf("  Terminal 1: %s producer\n", argv[0]);
        printf("  Terminal 2: %s consumer\n", argv[0]);

        // 单进程演示
        printf("\nRunning single-process demo...\n");

        SharedMemoryRingBuffer shm(shm_name, 4096, true);

        // 写入
        const char* msg = "Hello, shared memory!";
        shm.write(msg, strlen(msg) + 1);
        printf("Wrote: %s\n", msg);

        // 读取
        char buf[128];
        size_t n = shm.read(buf, sizeof(buf));
        if (n > 0) {
            printf("Read: %s\n", buf);
        }

        SharedMemoryRingBuffer::unlink(shm_name);
    }

    return 0;
}
```

#### 示例22：mmap文件缓存系统

```cpp
// mmap_file_cache.cpp
// 示例22：基于mmap的文件缓存系统
// 编译：g++ -std=c++17 -O2 -pthread -o mmap_cache mmap_file_cache.cpp

#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <cstdio>
#include <cstring>
#include <string>
#include <unordered_map>
#include <mutex>
#include <shared_mutex>
#include <memory>
#include <chrono>
#include <list>

// 缓存的文件项
struct CachedFile {
    std::string path;
    void* data;
    size_t size;
    int fd;
    std::chrono::steady_clock::time_point last_access;
    size_t access_count;

    CachedFile(const std::string& p) : path(p), data(nullptr),
                                       size(0), fd(-1), access_count(0) {
        last_access = std::chrono::steady_clock::now();
    }

    ~CachedFile() {
        if (data && data != MAP_FAILED) {
            munmap(data, size);
        }
        if (fd >= 0) {
            close(fd);
        }
    }

    bool load() {
        fd = open(path.c_str(), O_RDONLY);
        if (fd < 0) return false;

        struct stat st;
        if (fstat(fd, &st) < 0) {
            close(fd);
            fd = -1;
            return false;
        }

        size = st.st_size;

        data = mmap(nullptr, size, PROT_READ, MAP_PRIVATE, fd, 0);

        if (data == MAP_FAILED) {
            close(fd);
            fd = -1;
            data = nullptr;
            return false;
        }

        // 优化访问
        madvise(data, size, MADV_SEQUENTIAL);

        return true;
    }

    void touch() {
        last_access = std::chrono::steady_clock::now();
        access_count++;
    }
};

// LRU文件缓存
class MmapFileCache {
public:
    MmapFileCache(size_t max_files = 100, size_t max_memory = 512 * 1024 * 1024)
        : max_files_(max_files), max_memory_(max_memory), current_memory_(0) {}

    // 获取文件数据
    std::pair<const void*, size_t> get(const std::string& path) {
        std::unique_lock<std::shared_mutex> lock(mutex_);

        auto it = cache_.find(path);

        if (it != cache_.end()) {
            // 缓存命中
            auto& cached = it->second;
            cached->touch();

            // 移动到LRU列表末尾
            lru_list_.remove(path);
            lru_list_.push_back(path);

            hits_++;
            return {cached->data, cached->size};
        }

        // 缓存未命中，加载文件
        misses_++;

        auto cached = std::make_shared<CachedFile>(path);
        if (!cached->load()) {
            return {nullptr, 0};
        }

        // 检查是否需要驱逐
        while (cache_.size() >= max_files_ ||
               current_memory_ + cached->size > max_memory_) {
            if (!evict_one()) break;
        }

        // 添加到缓存
        cache_[path] = cached;
        lru_list_.push_back(path);
        current_memory_ += cached->size;

        return {cached->data, cached->size};
    }

    // 获取统计信息
    void stats() const {
        std::shared_lock<std::shared_mutex> lock(mutex_);

        printf("\n=== Cache Statistics ===\n");
        printf("Files cached: %zu / %zu\n", cache_.size(), max_files_);
        printf("Memory used: %zu / %zu bytes (%.1f%%)\n",
               current_memory_, max_memory_,
               100.0 * current_memory_ / max_memory_);
        printf("Hits: %zu, Misses: %zu\n", hits_, misses_);

        if (hits_ + misses_ > 0) {
            printf("Hit rate: %.1f%%\n",
                   100.0 * hits_ / (hits_ + misses_));
        }
    }

    // 清除缓存
    void clear() {
        std::unique_lock<std::shared_mutex> lock(mutex_);
        cache_.clear();
        lru_list_.clear();
        current_memory_ = 0;
    }

    // 预加载文件
    bool preload(const std::string& path) {
        auto result = get(path);
        return result.first != nullptr;
    }

private:
    // 驱逐一个文件
    bool evict_one() {
        if (lru_list_.empty()) return false;

        std::string oldest = lru_list_.front();
        lru_list_.pop_front();

        auto it = cache_.find(oldest);
        if (it != cache_.end()) {
            current_memory_ -= it->second->size;
            cache_.erase(it);
            evictions_++;
        }

        return true;
    }

private:
    size_t max_files_;
    size_t max_memory_;
    size_t current_memory_;

    mutable std::shared_mutex mutex_;
    std::unordered_map<std::string, std::shared_ptr<CachedFile>> cache_;
    std::list<std::string> lru_list_;

    size_t hits_ = 0;
    size_t misses_ = 0;
    size_t evictions_ = 0;
};

// 使用缓存的文件服务器
class CachedFileServer {
public:
    CachedFileServer(int port, const std::string& root_dir)
        : port_(port), root_dir_(root_dir), cache_(100, 256 * 1024 * 1024) {}

    void run() {
        int server_fd = socket(AF_INET, SOCK_STREAM, 0);
        int opt = 1;
        setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

        struct sockaddr_in addr;
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = INADDR_ANY;
        addr.sin_port = htons(port_);

        bind(server_fd, (struct sockaddr*)&addr, sizeof(addr));
        listen(server_fd, SOMAXCONN);

        printf("Cached file server on port %d\n", port_);
        printf("Root: %s\n", root_dir_.c_str());

        while (true) {
            int client_fd = accept(server_fd, nullptr, nullptr);
            if (client_fd < 0) continue;

            handle_request(client_fd);
            close(client_fd);
        }

        close(server_fd);
    }

private:
    void handle_request(int client_fd) {
        char buffer[4096];
        ssize_t n = read(client_fd, buffer, sizeof(buffer) - 1);
        if (n <= 0) return;

        buffer[n] = '\0';

        // 简单解析请求路径
        char method[16], path[1024];
        sscanf(buffer, "%s %s", method, path);

        if (strcmp(method, "GET") != 0) {
            send_error(client_fd, 405, "Method Not Allowed");
            return;
        }

        // 构建文件路径
        std::string file_path = root_dir_ + path;
        if (file_path.back() == '/') {
            file_path += "index.html";
        }

        // 从缓存获取
        auto [data, size] = cache_.get(file_path);

        if (!data) {
            send_error(client_fd, 404, "Not Found");
            return;
        }

        // 发送响应
        char header[256];
        int header_len = snprintf(header, sizeof(header),
            "HTTP/1.1 200 OK\r\n"
            "Content-Length: %zu\r\n"
            "Content-Type: application/octet-stream\r\n"
            "\r\n", size);

        write(client_fd, header, header_len);
        write(client_fd, data, size);

        request_count_++;

        if (request_count_ % 100 == 0) {
            cache_.stats();
        }
    }

    void send_error(int client_fd, int code, const char* message) {
        char response[256];
        int len = snprintf(response, sizeof(response),
            "HTTP/1.1 %d %s\r\n"
            "Content-Length: 0\r\n"
            "\r\n", code, message);

        write(client_fd, response, len);
    }

private:
    int port_;
    std::string root_dir_;
    MmapFileCache cache_;
    size_t request_count_ = 0;
};

int main(int argc, char* argv[]) {
    if (argc < 3) {
        printf("Usage: %s <port> <root_dir>\n", argv[0]);
        return 1;
    }

    int port = atoi(argv[1]);
    const char* root_dir = argv[2];

    CachedFileServer server(port, root_dir);
    server.run();

    return 0;
}
```

#### Day 24-25 自测问答

```
Q1: mmap + write 发送文件有几次数据拷贝？
A1: mmap + write 发送文件共有3次数据拷贝：
    1. DMA拷贝：磁盘 → Page Cache
    2. CPU拷贝：Page Cache → Socket缓冲区（通过用户空间映射）
    3. DMA拷贝：Socket缓冲区 → 网卡
    比传统read+write的4次少1次（省去了Page Cache到用户缓冲区的拷贝）

Q2: 为什么大文件要分块mmap？
A2: 大文件分块mmap的原因：
    1. 避免虚拟地址空间耗尽（32位系统尤其重要）
    2. 减少页表占用
    3. 及时释放不再需要的映射
    4. 更好地控制内存使用
    5. 可以边处理边释放，适合流式处理

Q3: 使用mmap实现共享内存有什么优势？
A3: mmap共享内存的优势：
    1. 零拷贝：多进程共享同一物理内存
    2. 持久化选项：可以映射到文件
    3. 简单的API：像访问普通内存一样
    4. 高性能：直接内存访问，无系统调用开销
    5. 灵活：可以是匿名映射或文件映射

Q4: mmap文件缓存系统的工作原理是什么？
A4: mmap文件缓存系统原理：
    1. 首次访问：mmap文件，建立映射
    2. 后续访问：直接返回映射地址
    3. 数据通过Page Cache缓存在物理内存
    4. 多次访问同一文件无需重复映射
    5. 使用LRU策略驱逐不常用的映射
    6. 内存限制保护系统资源

Q5: mmap相比sendfile在什么场景更适合？
A5: mmap更适合的场景：
    1. 需要多次随机访问同一文件
    2. 需要修改文件内容
    3. 需要在内存中处理数据后再发送
    4. 实现共享内存通信
    5. 文件缓存系统

    sendfile更适合的场景：
    1. 简单的文件传输到socket
    2. 不需要处理文件内容
    3. 追求最少的拷贝次数
```

---

### Day 26-28：综合对比与实战项目（15小时）

#### 各种零拷贝技术综合对比

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     零拷贝技术综合对比                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  技术        │ 拷贝次数 │ 上下文切换 │ 适用场景              │ 复杂度      │
│ ─────────────┼──────────┼────────────┼───────────────────────┼──────────── │
│ read+write   │ 4        │ 4          │ 通用                  │ 低          │
│ mmap+write   │ 3        │ 4          │ 随机访问/修改         │ 中          │
│ sendfile     │ 2-3      │ 2          │ 文件→socket           │ 低          │
│ splice       │ 2        │ 4          │ 任意fd之间            │ 中          │
│ vmsplice     │ 0-2      │ 4          │ 用户内存→socket       │ 高          │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│  数据流路径对比：                                                           │
│                                                                             │
│  read+write:  Disk → Page Cache → User Buffer → Socket Buffer → NIC        │
│               (DMA)    (CPU)       (CPU)        (DMA)                       │
│                                                                             │
│  mmap+write:  Disk → Page Cache ────────────→ Socket Buffer → NIC          │
│               (DMA)    ↑用户映射    (CPU)        (DMA)                      │
│                                                                             │
│  sendfile:    Disk → Page Cache ────────────→ Socket Buffer → NIC          │
│               (DMA)    (描述符传递/CPU)         (DMA)                       │
│                                                                             │
│  sendfile+SG: Disk → Page Cache ─────────────────────────────→ NIC          │
│               (DMA)    (描述符)                  (Scatter-Gather DMA)       │
│                                                                             │
│  splice:      Socket1 → Pipe Buffer → Socket2                               │
│               (页面引用传递，无实际数据拷贝)                                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

选择指南：

┌─────────────────────────────────────────────────────────────────────────────┐
│ 场景                          │ 推荐技术           │ 原因                   │
├─────────────────────────────────────────────────────────────────────────────┤
│ 静态文件服务器                │ sendfile           │ 最简单，拷贝最少       │
│ 代理服务器                    │ splice             │ socket到socket零拷贝   │
│ 需要处理数据的服务器          │ mmap + write       │ 可以访问和处理数据     │
│ 高性能用户态发送              │ vmsplice + splice  │ 真正的零拷贝           │
│ 文件缓存系统                  │ mmap               │ 多次访问共享缓存       │
│ 大文件（>1GB）                │ 分块sendfile/mmap  │ 避免内存压力           │
│ 小文件（<64KB）               │ read+write         │ 简单，开销可忽略       │
│ 数据库/日志                   │ mmap(MAP_SHARED)   │ 直接修改，持久化       │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 示例23：综合性能基准测试

```cpp
// zero_copy_benchmark.cpp
// 示例23：零拷贝技术综合性能基准测试
// 编译：g++ -std=c++17 -O2 -pthread -o zc_bench zero_copy_benchmark.cpp

#define _GNU_SOURCE
#include <sys/sendfile.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/uio.h>
#include <fcntl.h>
#include <unistd.h>
#include <cstdio>
#include <cstring>
#include <chrono>
#include <vector>
#include <thread>
#include <functional>
#include <atomic>

// 基准测试结果
struct BenchResult {
    std::string method;
    size_t bytes_transferred;
    double time_ms;
    double throughput_mbps;
    int syscalls;
};

class ZeroCopyBenchmark {
public:
    ZeroCopyBenchmark(const char* filename) : filename_(filename) {
        struct stat st;
        stat(filename, &st);
        file_size_ = st.st_size;
    }

    // 方法1：传统read + write
    BenchResult bench_read_write(int out_fd, size_t buffer_size = 65536) {
        BenchResult result;
        result.method = "read+write (buf=" + std::to_string(buffer_size/1024) + "KB)";
        result.syscalls = 0;

        int in_fd = open(filename_, O_RDONLY);
        std::vector<char> buffer(buffer_size);

        auto start = std::chrono::high_resolution_clock::now();

        size_t total = 0;
        ssize_t n;
        while ((n = read(in_fd, buffer.data(), buffer_size)) > 0) {
            result.syscalls++;
            ssize_t written = 0;
            while (written < n) {
                ssize_t w = write(out_fd, buffer.data() + written, n - written);
                if (w <= 0) break;
                written += w;
                result.syscalls++;
            }
            total += written;
        }

        auto end = std::chrono::high_resolution_clock::now();

        close(in_fd);

        result.bytes_transferred = total;
        result.time_ms = std::chrono::duration<double, std::milli>(end - start).count();
        result.throughput_mbps = (total / (1024.0 * 1024.0)) / (result.time_ms / 1000.0);

        return result;
    }

    // 方法2：mmap + write
    BenchResult bench_mmap_write(int out_fd, size_t chunk_size = 0) {
        BenchResult result;
        result.method = "mmap+write";
        if (chunk_size > 0) {
            result.method += " (chunk=" + std::to_string(chunk_size/(1024*1024)) + "MB)";
        }
        result.syscalls = 0;

        int in_fd = open(filename_, O_RDONLY);

        auto start = std::chrono::high_resolution_clock::now();

        size_t total = 0;

        if (chunk_size == 0 || chunk_size >= file_size_) {
            // 整个文件映射
            void* mapped = mmap(nullptr, file_size_, PROT_READ, MAP_PRIVATE, in_fd, 0);
            madvise(mapped, file_size_, MADV_SEQUENTIAL);
            result.syscalls += 2;

            size_t written = 0;
            while (written < file_size_) {
                ssize_t n = write(out_fd, (char*)mapped + written, file_size_ - written);
                if (n <= 0) break;
                written += n;
                result.syscalls++;
            }
            total = written;

            munmap(mapped, file_size_);
        } else {
            // 分块映射
            off_t offset = 0;
            while (offset < (off_t)file_size_) {
                size_t map_size = std::min(chunk_size, file_size_ - offset);

                void* mapped = mmap(nullptr, map_size, PROT_READ, MAP_PRIVATE, in_fd, offset);
                madvise(mapped, map_size, MADV_SEQUENTIAL);
                result.syscalls += 2;

                size_t written = 0;
                while (written < map_size) {
                    ssize_t n = write(out_fd, (char*)mapped + written, map_size - written);
                    if (n <= 0) break;
                    written += n;
                    result.syscalls++;
                }

                total += written;
                offset += written;

                munmap(mapped, map_size);
            }
        }

        auto end = std::chrono::high_resolution_clock::now();

        close(in_fd);

        result.bytes_transferred = total;
        result.time_ms = std::chrono::duration<double, std::milli>(end - start).count();
        result.throughput_mbps = (total / (1024.0 * 1024.0)) / (result.time_ms / 1000.0);

        return result;
    }

    // 方法3：sendfile
    BenchResult bench_sendfile(int out_fd, size_t chunk_size = 0) {
        BenchResult result;
        result.method = "sendfile";
        if (chunk_size > 0) {
            result.method += " (chunk=" + std::to_string(chunk_size/(1024*1024)) + "MB)";
        }
        result.syscalls = 0;

        int in_fd = open(filename_, O_RDONLY);

        auto start = std::chrono::high_resolution_clock::now();

        off_t offset = 0;
        size_t total = 0;

        while (total < file_size_) {
            size_t to_send = file_size_ - total;
            if (chunk_size > 0 && to_send > chunk_size) {
                to_send = chunk_size;
            }

            ssize_t n = sendfile(out_fd, in_fd, &offset, to_send);
            result.syscalls++;

            if (n <= 0) break;
            total += n;
        }

        auto end = std::chrono::high_resolution_clock::now();

        close(in_fd);

        result.bytes_transferred = total;
        result.time_ms = std::chrono::duration<double, std::milli>(end - start).count();
        result.throughput_mbps = (total / (1024.0 * 1024.0)) / (result.time_ms / 1000.0);

        return result;
    }

    // 方法4：splice (file → pipe → socket)
    BenchResult bench_splice(int out_fd) {
        BenchResult result;
        result.method = "splice";
        result.syscalls = 0;

        int in_fd = open(filename_, O_RDONLY);
        int pipefd[2];
        pipe(pipefd);
        fcntl(pipefd[0], F_SETPIPE_SZ, 1024 * 1024);

        auto start = std::chrono::high_resolution_clock::now();

        size_t total = 0;

        while (total < file_size_) {
            // file → pipe
            ssize_t n = splice(in_fd, nullptr, pipefd[1], nullptr,
                              file_size_ - total, SPLICE_F_MOVE | SPLICE_F_MORE);
            result.syscalls++;

            if (n <= 0) break;

            // pipe → socket
            ssize_t sent = 0;
            while (sent < n) {
                ssize_t m = splice(pipefd[0], nullptr, out_fd, nullptr,
                                  n - sent, SPLICE_F_MOVE | SPLICE_F_MORE);
                result.syscalls++;
                if (m <= 0) break;
                sent += m;
            }

            total += sent;
        }

        auto end = std::chrono::high_resolution_clock::now();

        close(pipefd[0]);
        close(pipefd[1]);
        close(in_fd);

        result.bytes_transferred = total;
        result.time_ms = std::chrono::duration<double, std::milli>(end - start).count();
        result.throughput_mbps = (total / (1024.0 * 1024.0)) / (result.time_ms / 1000.0);

        return result;
    }

    void run_all_benchmarks() {
        printf("=== Zero-Copy Benchmark ===\n");
        printf("File: %s (%zu bytes, %.2f MB)\n\n",
               filename_, file_size_, file_size_ / (1024.0 * 1024.0));

        // 创建socket对用于测试
        int sv[2];
        socketpair(AF_UNIX, SOCK_STREAM, 0, sv);

        // 设置大缓冲区
        int buf_size = 16 * 1024 * 1024;
        setsockopt(sv[0], SOL_SOCKET, SO_SNDBUF, &buf_size, sizeof(buf_size));
        setsockopt(sv[1], SOL_SOCKET, SO_RCVBUF, &buf_size, sizeof(buf_size));

        std::vector<BenchResult> results;

        // 启动接收线程
        std::atomic<bool> running{true};
        std::thread receiver([&]() {
            char buf[1024 * 1024];
            while (running) {
                read(sv[1], buf, sizeof(buf));
            }
        });

        // 预热Page Cache
        {
            int fd = open(filename_, O_RDONLY);
            char buf[4096];
            while (read(fd, buf, sizeof(buf)) > 0);
            close(fd);
        }

        // 运行基准测试
        printf("%-35s %12s %12s %10s\n",
               "Method", "Time (ms)", "MB/s", "Syscalls");
        printf("%-35s %12s %12s %10s\n",
               "-----------------------------------", "------------",
               "------------", "----------");

        // read+write with different buffer sizes
        for (size_t buf_size : {4096, 65536, 1024*1024}) {
            auto r = bench_read_write(sv[0], buf_size);
            results.push_back(r);
            printf("%-35s %12.2f %12.2f %10d\n",
                   r.method.c_str(), r.time_ms, r.throughput_mbps, r.syscalls);
        }

        // mmap+write
        auto r = bench_mmap_write(sv[0]);
        results.push_back(r);
        printf("%-35s %12.2f %12.2f %10d\n",
               r.method.c_str(), r.time_ms, r.throughput_mbps, r.syscalls);

        // sendfile
        r = bench_sendfile(sv[0]);
        results.push_back(r);
        printf("%-35s %12.2f %12.2f %10d\n",
               r.method.c_str(), r.time_ms, r.throughput_mbps, r.syscalls);

        // splice
        r = bench_splice(sv[0]);
        results.push_back(r);
        printf("%-35s %12.2f %12.2f %10d\n",
               r.method.c_str(), r.time_ms, r.throughput_mbps, r.syscalls);

        // 停止接收线程
        running = false;
        shutdown(sv[0], SHUT_WR);
        receiver.join();

        close(sv[0]);
        close(sv[1]);

        // 打印比较结果
        printf("\nRelative Performance (vs read+write 4KB):\n");
        double baseline = results[0].throughput_mbps;
        for (const auto& res : results) {
            printf("  %-35s %.2fx\n",
                   res.method.c_str(), res.throughput_mbps / baseline);
        }
    }

private:
    const char* filename_;
    size_t file_size_;
};

int main(int argc, char* argv[]) {
    if (argc < 2) {
        printf("Usage: %s <filename>\n", argv[0]);
        printf("\nTo create a test file:\n");
        printf("  dd if=/dev/urandom of=test_100mb.dat bs=1M count=100\n");
        return 1;
    }

    ZeroCopyBenchmark bench(argv[1]);
    bench.run_all_benchmarks();

    return 0;
}
```

#### 示例24：高性能静态文件服务器

```cpp
// high_perf_file_server.cpp
// 示例24：支持多种零拷贝方式的高性能静态文件服务器
// 编译：g++ -std=c++17 -O2 -pthread -o hp_server high_perf_file_server.cpp

#define _GNU_SOURCE
#include <sys/sendfile.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/epoll.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <unistd.h>
#include <dirent.h>
#include <cstdio>
#include <cstring>
#include <ctime>
#include <string>
#include <unordered_map>
#include <memory>
#include <atomic>
#include <thread>
#include <vector>

// 发送方式
enum class SendMethod {
    READ_WRITE,
    MMAP,
    SENDFILE,
    SPLICE
};

// 服务器配置
struct ServerConfig {
    int port = 8080;
    std::string root_dir = ".";
    SendMethod send_method = SendMethod::SENDFILE;
    size_t small_file_threshold = 64 * 1024;  // 64KB
    size_t large_file_chunk = 8 * 1024 * 1024;  // 8MB
    int num_workers = 4;
};

// 连接状态
struct Connection {
    int fd;
    enum { READING, SENDING_HEADER, SENDING_BODY } state;

    // 请求信息
    std::string request_path;

    // 响应信息
    std::string response_header;
    size_t header_sent;

    int file_fd;
    void* file_mmap;
    size_t file_size;
    off_t file_offset;
    size_t body_sent;

    // splice管道
    int pipe_fd[2];
    size_t pipe_data;

    Connection(int f) : fd(f), state(READING), header_sent(0),
                        file_fd(-1), file_mmap(nullptr), file_size(0),
                        file_offset(0), body_sent(0), pipe_data(0) {
        pipe_fd[0] = pipe_fd[1] = -1;
    }

    ~Connection() {
        cleanup();
        if (fd >= 0) close(fd);
    }

    void cleanup() {
        if (file_mmap && file_mmap != MAP_FAILED) {
            munmap(file_mmap, file_size);
            file_mmap = nullptr;
        }
        if (file_fd >= 0) {
            close(file_fd);
            file_fd = -1;
        }
        if (pipe_fd[0] >= 0) {
            close(pipe_fd[0]);
            close(pipe_fd[1]);
            pipe_fd[0] = pipe_fd[1] = -1;
        }
    }
};

class HighPerfFileServer {
public:
    HighPerfFileServer(const ServerConfig& config)
        : config_(config) {
        epfd_ = epoll_create1(EPOLL_CLOEXEC);
    }

    ~HighPerfFileServer() {
        if (epfd_ >= 0) close(epfd_);
        if (listen_fd_ >= 0) close(listen_fd_);
    }

    bool start() {
        listen_fd_ = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK, 0);
        if (listen_fd_ < 0) return false;

        int opt = 1;
        setsockopt(listen_fd_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
        setsockopt(listen_fd_, SOL_SOCKET, SO_REUSEPORT, &opt, sizeof(opt));

        struct sockaddr_in addr;
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = INADDR_ANY;
        addr.sin_port = htons(config_.port);

        if (bind(listen_fd_, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
            perror("bind");
            return false;
        }

        if (listen(listen_fd_, SOMAXCONN) < 0) {
            perror("listen");
            return false;
        }

        struct epoll_event ev;
        ev.events = EPOLLIN;
        ev.data.fd = listen_fd_;
        epoll_ctl(epfd_, EPOLL_CTL_ADD, listen_fd_, &ev);

        printf("High Performance File Server\n");
        printf("Port: %d\n", config_.port);
        printf("Root: %s\n", config_.root_dir.c_str());
        printf("Method: %s\n", get_method_name());

        return true;
    }

    void run() {
        running_ = true;
        std::vector<epoll_event> events(4096);

        while (running_) {
            int n = epoll_wait(epfd_, events.data(), events.size(), 100);

            for (int i = 0; i < n; i++) {
                int fd = events[i].data.fd;
                uint32_t revents = events[i].events;

                if (fd == listen_fd_) {
                    handle_accept();
                } else {
                    auto it = connections_.find(fd);
                    if (it == connections_.end()) continue;

                    auto& conn = it->second;

                    if (revents & EPOLLIN) {
                        handle_read(conn);
                    }
                    if (revents & EPOLLOUT) {
                        handle_write(conn);
                    }
                    if (revents & (EPOLLERR | EPOLLHUP)) {
                        close_connection(fd);
                    }
                }
            }
        }
    }

    void stop() { running_ = false; }

private:
    const char* get_method_name() {
        switch (config_.send_method) {
            case SendMethod::READ_WRITE: return "read+write";
            case SendMethod::MMAP: return "mmap+write";
            case SendMethod::SENDFILE: return "sendfile";
            case SendMethod::SPLICE: return "splice";
        }
        return "unknown";
    }

    void handle_accept() {
        while (true) {
            int client_fd = accept4(listen_fd_, nullptr, nullptr, SOCK_NONBLOCK);
            if (client_fd < 0) {
                if (errno == EAGAIN) break;
                continue;
            }

            int opt = 1;
            setsockopt(client_fd, IPPROTO_TCP, TCP_NODELAY, &opt, sizeof(opt));

            auto conn = std::make_shared<Connection>(client_fd);
            connections_[client_fd] = conn;

            struct epoll_event ev;
            ev.events = EPOLLIN | EPOLLET;
            ev.data.fd = client_fd;
            epoll_ctl(epfd_, EPOLL_CTL_ADD, client_fd, &ev);

            total_connections_++;
        }
    }

    void handle_read(std::shared_ptr<Connection>& conn) {
        char buffer[4096];
        ssize_t n = read(conn->fd, buffer, sizeof(buffer) - 1);

        if (n <= 0) {
            if (n < 0 && errno == EAGAIN) return;
            close_connection(conn->fd);
            return;
        }

        buffer[n] = '\0';

        // 解析请求
        char method[16], path[1024];
        sscanf(buffer, "%s %s", method, path);

        if (strcmp(method, "GET") != 0) {
            send_error(conn, 405, "Method Not Allowed");
            return;
        }

        // 构建文件路径
        std::string file_path = config_.root_dir + path;
        if (file_path.back() == '/') {
            file_path += "index.html";
        }

        // 安全检查
        if (file_path.find("..") != std::string::npos) {
            send_error(conn, 403, "Forbidden");
            return;
        }

        conn->request_path = file_path;
        prepare_response(conn);
    }

    void prepare_response(std::shared_ptr<Connection>& conn) {
        struct stat st;
        if (stat(conn->request_path.c_str(), &st) < 0) {
            send_error(conn, 404, "Not Found");
            return;
        }

        conn->file_fd = open(conn->request_path.c_str(), O_RDONLY);
        if (conn->file_fd < 0) {
            send_error(conn, 500, "Internal Server Error");
            return;
        }

        conn->file_size = st.st_size;

        // 准备响应头
        char header[1024];
        snprintf(header, sizeof(header),
            "HTTP/1.1 200 OK\r\n"
            "Content-Type: %s\r\n"
            "Content-Length: %zu\r\n"
            "Connection: keep-alive\r\n"
            "\r\n",
            get_content_type(conn->request_path), conn->file_size);

        conn->response_header = header;
        conn->header_sent = 0;
        conn->body_sent = 0;
        conn->file_offset = 0;
        conn->state = Connection::SENDING_HEADER;

        // 根据方法准备
        if (config_.send_method == SendMethod::MMAP) {
            conn->file_mmap = mmap(nullptr, conn->file_size, PROT_READ,
                                  MAP_PRIVATE, conn->file_fd, 0);
            madvise(conn->file_mmap, conn->file_size, MADV_SEQUENTIAL);
        } else if (config_.send_method == SendMethod::SPLICE) {
            pipe2(conn->pipe_fd, O_NONBLOCK);
            fcntl(conn->pipe_fd[0], F_SETPIPE_SZ, 1024 * 1024);
        }

        // 启用TCP_CORK
        int cork = 1;
        setsockopt(conn->fd, IPPROTO_TCP, TCP_CORK, &cork, sizeof(cork));

        // 注册写事件
        struct epoll_event ev;
        ev.events = EPOLLOUT | EPOLLET;
        ev.data.fd = conn->fd;
        epoll_ctl(epfd_, EPOLL_CTL_MOD, conn->fd, &ev);

        handle_write(conn);
    }

    void handle_write(std::shared_ptr<Connection>& conn) {
        // 发送响应头
        while (conn->header_sent < conn->response_header.length()) {
            ssize_t n = write(conn->fd,
                             conn->response_header.c_str() + conn->header_sent,
                             conn->response_header.length() - conn->header_sent);

            if (n < 0) {
                if (errno == EAGAIN) return;
                close_connection(conn->fd);
                return;
            }
            conn->header_sent += n;
        }

        conn->state = Connection::SENDING_BODY;

        // 发送文件体
        bool done = false;
        switch (config_.send_method) {
            case SendMethod::READ_WRITE:
                done = send_read_write(conn);
                break;
            case SendMethod::MMAP:
                done = send_mmap(conn);
                break;
            case SendMethod::SENDFILE:
                done = send_sendfile(conn);
                break;
            case SendMethod::SPLICE:
                done = send_splice(conn);
                break;
        }

        if (done) {
            // 关闭TCP_CORK
            int cork = 0;
            setsockopt(conn->fd, IPPROTO_TCP, TCP_CORK, &cork, sizeof(cork));

            total_requests_++;
            total_bytes_ += conn->file_size;

            // Keep-alive: 重置连接
            conn->cleanup();
            conn->state = Connection::READING;

            struct epoll_event ev;
            ev.events = EPOLLIN | EPOLLET;
            ev.data.fd = conn->fd;
            epoll_ctl(epfd_, EPOLL_CTL_MOD, conn->fd, &ev);
        }
    }

    bool send_read_write(std::shared_ptr<Connection>& conn) {
        char buffer[65536];

        while (conn->body_sent < conn->file_size) {
            ssize_t n = pread(conn->file_fd, buffer, sizeof(buffer), conn->body_sent);
            if (n <= 0) break;

            ssize_t written = 0;
            while (written < n) {
                ssize_t w = write(conn->fd, buffer + written, n - written);
                if (w < 0) {
                    if (errno == EAGAIN) return false;
                    return true;
                }
                written += w;
            }
            conn->body_sent += written;
        }

        return conn->body_sent >= conn->file_size;
    }

    bool send_mmap(std::shared_ptr<Connection>& conn) {
        while (conn->body_sent < conn->file_size) {
            ssize_t n = write(conn->fd,
                             (char*)conn->file_mmap + conn->body_sent,
                             conn->file_size - conn->body_sent);

            if (n < 0) {
                if (errno == EAGAIN) return false;
                return true;
            }
            conn->body_sent += n;
        }

        return true;
    }

    bool send_sendfile(std::shared_ptr<Connection>& conn) {
        while (conn->body_sent < conn->file_size) {
            ssize_t n = sendfile(conn->fd, conn->file_fd,
                                &conn->file_offset,
                                conn->file_size - conn->body_sent);

            if (n < 0) {
                if (errno == EAGAIN) return false;
                return true;
            }
            if (n == 0) break;

            conn->body_sent += n;
        }

        return conn->body_sent >= conn->file_size;
    }

    bool send_splice(std::shared_ptr<Connection>& conn) {
        while (conn->body_sent < conn->file_size) {
            // 如果管道为空，从文件读取
            if (conn->pipe_data == 0) {
                ssize_t n = splice(conn->file_fd, &conn->file_offset,
                                  conn->pipe_fd[1], nullptr,
                                  conn->file_size - conn->body_sent,
                                  SPLICE_F_MOVE | SPLICE_F_MORE);

                if (n < 0) {
                    if (errno == EAGAIN) return false;
                    return true;
                }
                if (n == 0) break;

                conn->pipe_data = n;
            }

            // 从管道发送到socket
            while (conn->pipe_data > 0) {
                ssize_t n = splice(conn->pipe_fd[0], nullptr,
                                  conn->fd, nullptr,
                                  conn->pipe_data,
                                  SPLICE_F_MOVE | SPLICE_F_MORE);

                if (n < 0) {
                    if (errno == EAGAIN) return false;
                    return true;
                }
                if (n == 0) break;

                conn->pipe_data -= n;
                conn->body_sent += n;
            }
        }

        return conn->body_sent >= conn->file_size;
    }

    void send_error(std::shared_ptr<Connection>& conn, int code, const char* message) {
        char response[512];
        int len = snprintf(response, sizeof(response),
            "HTTP/1.1 %d %s\r\n"
            "Content-Length: 0\r\n"
            "Connection: close\r\n"
            "\r\n", code, message);

        write(conn->fd, response, len);
        close_connection(conn->fd);
    }

    const char* get_content_type(const std::string& path) {
        size_t dot = path.rfind('.');
        if (dot == std::string::npos) return "application/octet-stream";

        std::string ext = path.substr(dot);
        if (ext == ".html" || ext == ".htm") return "text/html";
        if (ext == ".css") return "text/css";
        if (ext == ".js") return "application/javascript";
        if (ext == ".json") return "application/json";
        if (ext == ".png") return "image/png";
        if (ext == ".jpg" || ext == ".jpeg") return "image/jpeg";
        if (ext == ".gif") return "image/gif";
        if (ext == ".txt") return "text/plain";

        return "application/octet-stream";
    }

    void close_connection(int fd) {
        epoll_ctl(epfd_, EPOLL_CTL_DEL, fd, nullptr);
        connections_.erase(fd);
    }

private:
    ServerConfig config_;
    int epfd_ = -1;
    int listen_fd_ = -1;
    bool running_ = false;
    std::unordered_map<int, std::shared_ptr<Connection>> connections_;

    std::atomic<uint64_t> total_connections_{0};
    std::atomic<uint64_t> total_requests_{0};
    std::atomic<uint64_t> total_bytes_{0};
};

int main(int argc, char* argv[]) {
    ServerConfig config;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-p") == 0 && i + 1 < argc) {
            config.port = atoi(argv[++i]);
        } else if (strcmp(argv[i], "-r") == 0 && i + 1 < argc) {
            config.root_dir = argv[++i];
        } else if (strcmp(argv[i], "-m") == 0 && i + 1 < argc) {
            const char* method = argv[++i];
            if (strcmp(method, "readwrite") == 0) {
                config.send_method = SendMethod::READ_WRITE;
            } else if (strcmp(method, "mmap") == 0) {
                config.send_method = SendMethod::MMAP;
            } else if (strcmp(method, "sendfile") == 0) {
                config.send_method = SendMethod::SENDFILE;
            } else if (strcmp(method, "splice") == 0) {
                config.send_method = SendMethod::SPLICE;
            }
        }
    }

    if (argc == 1) {
        printf("Usage: %s [-p port] [-r root_dir] [-m method]\n", argv[0]);
        printf("Methods: readwrite, mmap, sendfile, splice\n");
        printf("\nDefault: port=8080, root=., method=sendfile\n");
    }

    HighPerfFileServer server(config);
    if (!server.start()) {
        return 1;
    }

    server.run();
    return 0;
}
```

#### Day 26-28 自测问答

```
Q1: 不同零拷贝技术的性能排序是什么？
A1: 一般性能排序（文件传输到网络）：
    1. sendfile + SG-DMA（2次拷贝，最快）
    2. sendfile（2-3次拷贝）
    3. splice（2次拷贝，灵活）
    4. mmap + write（3次拷贝）
    5. read + write（4次拷贝，最慢）

    但实际性能还取决于：
    - 文件大小（小文件差异不大）
    - 系统调用次数
    - 缓冲区大小
    - 硬件支持

Q2: 什么情况下read+write可能比零拷贝更快？
A2: read+write可能更快的情况：
    1. 非常小的文件（<4KB）：系统调用开销占主导
    2. 需要处理数据：零拷贝无法处理数据
    3. 内存充足且数据已在缓存
    4. 网络延迟是瓶颈而非I/O
    5. 某些特殊的硬件配置

Q3: 生产环境的静态文件服务器应该选择哪种技术？
A3: 推荐策略：
    1. 默认使用sendfile（简单，高效）
    2. 小文件（<64KB）可以用read+write（开销可忽略）
    3. 需要处理数据（压缩等）时用mmap
    4. 代理场景用splice
    5. 超大文件分块处理
    6. 参考Nginx的实现策略

Q4: 如何测试零拷贝的实际性能？
A4: 测试方法：
    1. 使用socketpair避免网络干扰
    2. 测试不同大小的文件
    3. 预热Page Cache消除冷读取影响
    4. 多次运行取平均值
    5. 测量吞吐量和CPU使用率
    6. 使用perf工具分析系统调用和缓存命中

Q5: 选择零拷贝技术时需要考虑哪些因素？
A5: 选择因素：
    1. 数据来源和目标（文件/socket/内存）
    2. 是否需要处理数据
    3. 文件大小
    4. 系统调用次数
    5. 代码复杂度
    6. 兼容性要求（内核版本）
    7. 硬件支持（如SG-DMA）
    8. 并发需求
```

---

### 第四周检验标准

```
第四周自我检验清单：

理论理解：
☐ 能解释mmap的系统调用签名和参数含义
☐ 理解MAP_PRIVATE和MAP_SHARED的区别
☐ 能说出mmap实现零拷贝的原理
☐ 理解madvise各个选项的作用
☐ 能解释mmap与Page Cache的关系
☐ 理解各种零拷贝技术的拷贝次数差异
☐ 能分析不同场景下应该选择哪种技术

实践能力：
☐ 能使用mmap读写文件
☐ 能使用mmap实现共享内存
☐ 能实现基于mmap的文件缓存系统
☐ 能编写综合性能基准测试程序
☐ 能实现支持多种发送方式的文件服务器
☐ 能根据场景选择合适的零拷贝技术

代码完成：
☐ 示例18: mmap基本文件操作
☐ 示例19: mmap与Page Cache关系
☐ 示例20: mmap + send文件发送
☐ 示例21: 共享内存实现
☐ 示例22: mmap文件缓存系统
☐ 示例23: 综合性能基准测试
☐ 示例24: 高性能静态文件服务器
```

---

## 本月检验标准汇总

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Month 29 检验标准总表                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  理论知识检验（共20项）                                                      │
│                                                                             │
│  传统I/O与零拷贝原理：                                                       │
│  ☐ 1. 能画出传统read/write的4次拷贝数据流图                                 │
│  ☐ 2. 能区分DMA拷贝和CPU拷贝                                                │
│  ☐ 3. 能解释上下文切换的开销                                                │
│  ☐ 4. 理解Page Cache在零拷贝中的角色                                        │
│  ☐ 5. 理解虚拟内存与物理内存的关系                                          │
│                                                                             │
│  sendfile：                                                                 │
│  ☐ 6. 能解释sendfile的系统调用签名和参数                                    │
│  ☐ 7. 理解DMA Scatter-Gather如何实现真正的零拷贝                           │
│  ☐ 8. 能说出sendfile的in_fd和out_fd限制                                     │
│  ☐ 9. 理解TCP_CORK和TCP_NODELAY的区别                                       │
│                                                                             │
│  splice/vmsplice：                                                          │
│  ☐ 10. 能解释splice的系统调用签名和参数                                     │
│  ☐ 11. 理解splice通过管道实现零拷贝的原理                                   │
│  ☐ 12. 能说出splice的标志位及其作用                                         │
│  ☐ 13. 理解tee与splice的区别                                                │
│  ☐ 14. 能解释vmsplice和SPLICE_F_GIFT的含义                                  │
│                                                                             │
│  mmap：                                                                     │
│  ☐ 15. 能解释mmap的系统调用签名和参数                                       │
│  ☐ 16. 理解MAP_PRIVATE和MAP_SHARED的区别                                    │
│  ☐ 17. 能说出mmap实现零拷贝的原理                                           │
│  ☐ 18. 理解madvise各个选项的作用                                            │
│                                                                             │
│  综合：                                                                     │
│  ☐ 19. 理解各种零拷贝技术的拷贝次数差异                                     │
│  ☐ 20. 能分析不同场景下应该选择哪种技术                                     │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  实践能力检验（共20项）                                                      │
│                                                                             │
│  基础测试与工具：                                                           │
│  ☐ 1. 能编写传统I/O性能测试程序                                             │
│  ☐ 2. 能检测系统的零拷贝特性支持                                            │
│  ☐ 3. 能查看和分析/proc/pid/maps                                            │
│  ☐ 4. 能测量Page Cache的性能影响                                            │
│                                                                             │
│  sendfile实践：                                                             │
│  ☐ 5. 能编写基本的sendfile文件发送程序                                      │
│  ☐ 6. 能实现大文件的分块sendfile发送                                        │
│  ☐ 7. 能处理非阻塞socket的sendfile                                          │
│  ☐ 8. 能使用TCP_CORK + writev + sendfile组合                                │
│  ☐ 9. 能实现支持Range请求的文件服务器                                       │
│                                                                             │
│  splice/vmsplice实践：                                                      │
│  ☐ 10. 能使用splice实现socket到socket的转发                                 │
│  ☐ 11. 能实现splice零拷贝echo服务器                                         │
│  ☐ 12. 能实现splice代理服务器                                               │
│  ☐ 13. 能使用tee实现数据分流                                                │
│  ☐ 14. 能使用vmsplice从用户空间发送数据                                     │
│  ☐ 15. 能调优管道缓冲区大小                                                 │
│                                                                             │
│  mmap实践：                                                                 │
│  ☐ 16. 能使用mmap读写文件                                                   │
│  ☐ 17. 能使用mmap实现共享内存                                               │
│  ☐ 18. 能实现基于mmap的文件缓存系统                                         │
│                                                                             │
│  综合实践：                                                                 │
│  ☐ 19. 能编写综合性能基准测试程序                                           │
│  ☐ 20. 能实现支持多种发送方式的高性能文件服务器                             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

自评得分：理论 ___/20  实践 ___/20  总计 ___/40

评分标准：
- 36-40分：优秀，完全掌握零拷贝技术
- 30-35分：良好，可以进入下一阶段
- 24-29分：及格，需要回顾薄弱环节
- <24分：需要重新学习本月内容
```

---

## 输出物清单

```
项目目录结构：

month29_zero_copy/
├── CMakeLists.txt
├── README.md
├── src/
│   ├── week1_fundamentals/
│   │   ├── traditional_io_benchmark.cpp    # 示例1: 传统I/O性能测试
│   │   ├── zero_copy_detect.cpp            # 示例2: 零拷贝特性检测
│   │   ├── memory_mapping_viewer.cpp       # 示例3: 内存映射查看
│   │   └── page_cache_warmup.cpp           # 示例4: Page Cache性能测试
│   │
│   ├── week2_sendfile/
│   │   ├── sendfile_basic.cpp              # 示例5: sendfile基本使用
│   │   ├── sendfile_chunked.cpp            # 示例6: 大文件分块发送
│   │   ├── sendfile_nonblock.cpp           # 示例7: 非阻塞sendfile
│   │   ├── sendfile_cork.cpp               # 示例8: sendfile与TCP_CORK
│   │   ├── sendfile_writev.cpp             # 示例9: sendfile与writev
│   │   ├── sendfile_file_server.cpp        # 示例10: sendfile文件服务器
│   │   └── sendfile_benchmark.cpp          # 示例11: sendfile性能对比
│   │
│   ├── week3_splice/
│   │   ├── splice_basic.cpp                # 示例12: splice基本用法
│   │   ├── splice_echo_server.cpp          # 示例13: splice echo服务器
│   │   ├── splice_proxy.cpp                # 示例14: splice代理服务器
│   │   ├── splice_tee.cpp                  # 示例15: splice + tee分流
│   │   ├── vmsplice_send.cpp               # 示例16: vmsplice发送
│   │   └── pipe_buffer_tuning.cpp          # 示例17: 管道缓冲区调优
│   │
│   ├── week4_mmap/
│   │   ├── mmap_basic.cpp                  # 示例18: mmap基本操作
│   │   ├── mmap_page_cache.cpp             # 示例19: mmap与Page Cache
│   │   ├── mmap_send.cpp                   # 示例20: mmap + send
│   │   ├── shared_memory.cpp               # 示例21: 共享内存
│   │   ├── mmap_file_cache.cpp             # 示例22: 文件缓存系统
│   │   ├── zero_copy_benchmark.cpp         # 示例23: 综合基准测试
│   │   └── high_perf_file_server.cpp       # 示例24: 高性能文件服务器
│   │
│   └── common/
│       └── utils.hpp                       # 通用工具函数
│
├── tests/
│   ├── test_sendfile.cpp
│   ├── test_splice.cpp
│   ├── test_mmap.cpp
│   └── benchmark_runner.sh
│
├── docs/
│   └── zero_copy_architecture.md
│
└── notes/
    └── month29_zero_copy.md                # 学习笔记


输出物完成度检查：

☐ CMakeLists.txt 构建文件
☐ 24个代码示例全部完成
☐ 所有示例可编译运行
☐ 基准测试可执行
☐ 学习笔记完成
```

---

## 学习建议

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         学习路径建议                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│                        ┌──────────────┐                                    │
│                        │ 传统I/O原理  │                                    │
│                        │ (4次拷贝)    │                                    │
│                        └──────┬───────┘                                    │
│                               │                                             │
│            ┌──────────────────┼──────────────────┐                         │
│            │                  │                  │                         │
│            ▼                  ▼                  ▼                         │
│    ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                   │
│    │   sendfile   │  │   splice     │  │    mmap      │                   │
│    │ (文件→socket)│  │ (任意fd)    │  │ (内存映射)   │                   │
│    └──────┬───────┘  └──────┬───────┘  └──────┬───────┘                   │
│           │                 │                  │                           │
│           │                 │                  │                           │
│           └─────────────────┴──────────────────┘                           │
│                             │                                              │
│                             ▼                                              │
│                    ┌────────────────┐                                      │
│                    │ 综合性能对比   │                                      │
│                    │ 场景选择指南   │                                      │
│                    └────────────────┘                                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

调试技巧：

1. 使用strace跟踪系统调用：
   strace -e trace=read,write,sendfile,splice,mmap ./program

2. 使用perf分析性能：
   perf stat -e cpu-cycles,cache-misses ./program
   perf record -g ./program && perf report

3. 查看Page Cache状态：
   cat /proc/meminfo | grep -E "Cached|Buffers"
   vmstat 1  # 实时监控

4. 清除Page Cache进行冷读测试：
   sync && echo 3 > /proc/sys/vm/drop_caches

5. 检查网卡Scatter-Gather支持：
   ethtool -k eth0 | grep scatter-gather

6. 查看管道缓冲区大小：
   cat /proc/sys/fs/pipe-max-size


常见错误与解决：

┌─────────────────────────────────────────────────────────────────────────────┐
│ 错误                          │ 原因                 │ 解决方案             │
├─────────────────────────────────────────────────────────────────────────────┤
│ sendfile返回EINVAL           │ in_fd不支持mmap      │ 确保in_fd是文件      │
│ splice返回EINVAL             │ 没有管道参与         │ 至少一端必须是管道   │
│ mmap返回MAP_FAILED           │ 内存不足或参数错误   │ 检查size和prot      │
│ vmsplice后数据损坏           │ GIFT后仍访问内存     │ 使用GIFT后不再访问   │
│ splice死锁                   │ 阻塞模式+无消费者    │ 使用非阻塞模式       │
│ sendfile性能不如预期         │ 硬件不支持SG-DMA     │ 检查ethtool -k       │
│ mmap访问越界                 │ 映射大小不对         │ 检查文件大小         │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 结语

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│   ╔═══════════════════════════════════════════════════════════════════╗    │
│   ║                                                                   ║    │
│   ║         恭喜完成 Month 29: 零拷贝技术——消除数据拷贝开销           ║    │
│   ║                                                                   ║    │
│   ╚═══════════════════════════════════════════════════════════════════╝    │
│                                                                             │
│                                                                             │
│   本月核心收获：                                                            │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                                                                     │  │
│   │  1. 理解了传统I/O的性能瓶颈（4次拷贝 + 4次上下文切换）             │  │
│   │                                                                     │  │
│   │  2. 掌握了sendfile：最简单的零拷贝方案                             │  │
│   │     - 文件到socket的直接传输                                       │  │
│   │     - 配合DMA Scatter-Gather可达到2次拷贝                          │  │
│   │                                                                     │  │
│   │  3. 掌握了splice/vmsplice：最灵活的零拷贝方案                      │  │
│   │     - 通过管道实现任意fd之间的零拷贝                               │  │
│   │     - vmsplice + SPLICE_F_GIFT实现用户空间零拷贝                   │  │
│   │                                                                     │  │
│   │  4. 掌握了mmap：内存映射方案                                       │  │
│   │     - 文件直接映射到进程地址空间                                   │  │
│   │     - 适合需要处理数据的场景                                       │  │
│   │                                                                     │  │
│   │  5. 具备了根据场景选择最佳方案的能力                               │  │
│   │                                                                     │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│                                                                             │
│   技术要点总结：                                                            │
│                                                                             │
│   ┌───────────────┬─────────┬──────────────────────────────────────────┐  │
│   │ 技术          │ 拷贝数  │ 最佳场景                                 │  │
│   ├───────────────┼─────────┼──────────────────────────────────────────┤  │
│   │ read+write    │ 4       │ 需要处理数据、小文件                     │  │
│   │ mmap+write    │ 3       │ 随机访问、缓存系统                       │  │
│   │ sendfile      │ 2-3     │ 静态文件服务器                           │  │
│   │ splice        │ 2       │ 代理服务器、socket转发                   │  │
│   │ vmsplice+GIFT │ 0-2     │ 高性能用户态发送                         │  │
│   └───────────────┴─────────┴──────────────────────────────────────────┘  │
│                                                                             │
│                                                                             │
│   与上月衔接（Month 28 io_uring）：                                         │
│   - io_uring提供了异步I/O框架                                              │
│   - 零拷贝技术减少了数据传输开销                                           │
│   - 两者结合可以构建极致性能的网络应用                                     │
│                                                                             │
│                                                                             │
│   继续前进！下个月将学习 Reactor模式——事件驱动架构                         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 下月预告

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│                    Month 30: Reactor模式——事件驱动架构                      │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  学习目标：                                                                 │
│  • 理解Reactor模式的核心思想和组件                                          │
│  • 掌握单线程Reactor的实现                                                  │
│  • 掌握多线程Reactor（线程池）的实现                                        │
│  • 掌握主从Reactor模式的实现                                                │
│  • 能够设计和实现完整的Reactor网络框架                                      │
│                                                                             │
│  核心内容：                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                                                                     │   │
│  │  第一周：Reactor模式概述                                            │   │
│  │  • Handle（句柄）                                                   │   │
│  │  • Event Handler（事件处理器）                                      │   │
│  │  • Synchronous Event Demultiplexer（事件多路分离器）                │   │
│  │  • Reactor（反应器）                                                │   │
│  │                                                                     │   │
│  │  第二周：单线程Reactor                                              │   │
│  │  • 基于epoll的事件循环                                              │   │
│  │  • 事件注册和分发                                                   │   │
│  │  • 连接管理                                                         │   │
│  │                                                                     │   │
│  │  第三周：多线程Reactor                                              │   │
│  │  • 线程池设计                                                       │   │
│  │  • 任务队列                                                         │   │
│  │  • 线程安全处理                                                     │   │
│  │                                                                     │   │
│  │  第四周：主从Reactor                                                │   │
│  │  • MainReactor + SubReactor架构                                    │   │
│  │  • one loop per thread                                             │   │
│  │  • 负载均衡                                                         │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  知识衔接：                                                                 │
│  Month 29（零拷贝）+ Month 30（Reactor） = 高性能网络框架基础              │
│                                                                             │
│  后续展望：                                                                 │
│  Month 31 将学习 Proactor模式——异步完成通知架构                            │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

*Month 29 完成 - 零拷贝技术——消除数据拷贝开销*
