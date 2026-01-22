# Month 14: C++内存模型——穿透硬件迷雾

## 本月主题概述

C++内存模型是并发编程最难理解的部分，也是区分"使用多线程"和"理解多线程"的关键。本月将深入学习顺序一致性、内存序的六种模式，以及它们如何映射到实际硬件。

---

## 理论学习内容

### 第一周：为什么需要内存模型？

**学习目标**：理解内存模型存在的根本原因

**阅读材料**：
- [ ] 《C++ Concurrency in Action》第5章
- [ ] 博客：Preshing "Memory Barriers Are Like Source Control Operations"
- [ ] 论文：Boehm & Adve "Foundations of the C++ Concurrency Memory Model"

---

#### 📅 第一周每日详细计划

##### Day 1: 走进内存模型的世界（5小时）

**上午（2.5小时）- 理论奠基**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 概念引入 | 阅读《C++ Concurrency in Action》5.1节，理解什么是内存模型 |
| 1:00-2:00 | 历史背景 | 了解C++11之前的内存模型问题（POSIX线程的局限性） |
| 2:00-2:30 | 笔记整理 | 用自己的话总结"为什么C++需要定义内存模型" |

**下午（2.5小时）- 观察重排序**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 动手实验 | 编写并运行下方的重排序观察程序 |
| 1:30-2:30 | 结果分析 | 多次运行，记录异常结果出现的频率 |

**动手实验 1-1：观察编译器重排序**
```cpp
// day1_reorder_test.cpp
// 编译命令：g++ -O2 -S -o day1_reorder_test.s day1_reorder_test.cpp
// 然后查看生成的汇编代码

int a = 0, b = 0;

void foo() {
    a = 1;
    b = 2;
}

// 问题：查看 -O0 和 -O2 生成的汇编有何不同？
// 提示：使用 https://godbolt.org/ 在线查看
```

**今日输出物**：
- [ ] 笔记：`notes/week1/day1_why_memory_model.md`
- [ ] 截图：Godbolt 上不同优化级别的汇编对比

**思考问题**：
1. 如果编译器保证"程序按源码顺序执行"，会损失多少性能？
2. 单线程程序为什么不需要担心重排序？

---

##### Day 2: 编译器优化与指令重排（5小时）

**上午（2.5小时）- 深入编译器优化**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 优化类型 | 学习常见编译器优化：常量折叠、死代码消除、指令调度 |
| 1:00-2:00 | 重排规则 | 理解"as-if规则"——编译器只需保证单线程可观察行为不变 |
| 2:00-2:30 | 案例分析 | 分析经典的Peterson锁失败案例 |

**下午（2.5小时）- volatile的误区**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | volatile详解 | 理解volatile只阻止编译器优化，不阻止CPU重排 |
| 1:00-2:00 | 对比实验 | 编写volatile vs atomic的对比测试 |
| 2:00-2:30 | 总结归纳 | 整理"volatile不是线程安全的原因" |

**动手实验 1-2：volatile 的局限性**
```cpp
// day2_volatile_test.cpp
#include <thread>
#include <iostream>

volatile bool ready = false;
volatile int data = 0;

void producer() {
    data = 42;
    ready = true;  // 编译器不会重排，但CPU可能！
}

void consumer() {
    while (!ready);
    std::cout << "data = " << data << std::endl;
    // 在某些架构上可能输出 0！
}

int main() {
    std::thread t1(producer);
    std::thread t2(consumer);
    t1.join();
    t2.join();
    return 0;
}
```

**扩展阅读**：
- Andrei Alexandrescu: "volatile - Multithreaded Programmer's Best Friend" (反面教材，了解历史误解)

**今日输出物**：
- [ ] 笔记：`notes/week1/day2_compiler_reorder.md`
- [ ] 代码：volatile vs atomic 对比实验

**常见误区警示**：
> ⚠️ **误区**：很多人认为 volatile 可以保证线程安全
>
> **真相**：volatile 只告诉编译器"每次都从内存读取"，但：
> 1. 不阻止CPU重排序
> 2. 不保证原子性
> 3. 不建立任何同步关系
>
> **正确做法**：使用 std::atomic

---

##### Day 3: CPU流水线与乱序执行（5小时）

**上午（2.5小时）- 现代CPU架构基础**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 流水线原理 | 学习5级流水线：取指、译码、执行、访存、写回 |
| 1:00-2:00 | 乱序执行 | 理解Tomasulo算法、保留站、重排序缓冲区(ROB) |
| 2:00-2:30 | 图解理解 | 画出乱序执行的数据流图 |

**下午（2.5小时）- 推测执行与分支预测**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 推测执行 | 理解分支预测、推测加载 |
| 1:30-2:30 | Spectre漏洞 | 了解推测执行如何导致安全问题（扩展知识） |

**扩展阅读**：
- "Computer Architecture: A Quantitative Approach" Chapter 3
- CppCon 2017: "C++ atomics, from basic to advanced" by Fedor Pikus

**视频资源**：
- YouTube: "CPU Pipeline and Out-of-Order Execution Explained"

**今日输出物**：
- [ ] 笔记：`notes/week1/day3_cpu_architecture.md`
- [ ] 图解：CPU流水线与乱序执行示意图

**思考问题**：
1. 为什么CPU要乱序执行？带来多少性能提升？
2. 如果禁止乱序执行，现代程序会慢多少？

---

##### Day 4: Store Buffer与缓存一致性（5小时）

**上午（2.5小时）- Store Buffer详解**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | Store Buffer原理 | 理解写缓冲区存在的原因和工作机制 |
| 1:00-2:00 | 写操作延迟可见 | 分析Store Buffer如何导致"写后读"问题 |
| 2:00-2:30 | 案例分析 | 分析经典的IRIW(Independent Reads of Independent Writes)问题 |

**下午（2.5小时）- 缓存一致性协议**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | MESI协议 | 学习Modified、Exclusive、Shared、Invalid四种状态 |
| 1:00-1:30 | 协议动画 | 使用在线MESI模拟器理解状态转换 |
| 1:30-2:30 | 伪共享问题 | 理解False Sharing及其性能影响 |

**动手实验 1-3：伪共享性能测试**
```cpp
// day4_false_sharing.cpp
#include <thread>
#include <chrono>
#include <iostream>

struct NoPadding {
    int a;
    int b;
};

struct WithPadding {
    alignas(64) int a;
    alignas(64) int b;
};

template<typename T>
void test() {
    T data{0, 0};
    auto start = std::chrono::high_resolution_clock::now();

    std::thread t1([&] {
        for (int i = 0; i < 100000000; ++i) ++data.a;
    });
    std::thread t2([&] {
        for (int i = 0; i < 100000000; ++i) ++data.b;
    });

    t1.join();
    t2.join();

    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
    std::cout << "Time: " << duration.count() << "ms\n";
}

int main() {
    std::cout << "Without padding: ";
    test<NoPadding>();
    std::cout << "With padding: ";
    test<WithPadding>();
    return 0;
}
```

**扩展阅读**：
- Preshing: "Memory Reordering Caught in the Act"
- MESI Protocol 在线模拟器

**今日输出物**：
- [ ] 笔记：`notes/week1/day4_store_buffer_cache.md`
- [ ] 代码：伪共享测试程序及结果分析

---

##### Day 5: 内存模型强度对比（5小时）

**上午（2.5小时）- x86 TSO模型**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | TSO定义 | 理解Total Store Order的语义 |
| 1:00-2:00 | x86保证 | 学习x86提供的天然保证：只有StoreLoad可能重排 |
| 2:00-2:30 | litmus测试 | 使用herd7工具验证x86行为 |

**下午（2.5小时）- ARM弱内存模型**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | ARM特点 | 理解ARM允许的所有重排类型 |
| 1:00-2:00 | 对比分析 | 制作x86 vs ARM内存模型对比表 |
| 2:00-2:30 | 移植问题 | 分析"x86上正确，ARM上错误"的代码案例 |

**工具推荐**：
- herd7: 内存模型形式化验证工具
- cppmem: C++内存模型可视化工具

**今日输出物**：
- [ ] 笔记：`notes/week1/day5_memory_model_comparison.md`
- [ ] 表格：x86 vs ARM vs POWER 内存模型对比

**架构对比速查表**：
```
| 重排类型      | x86/64 | ARM  | POWER | Alpha |
|--------------|--------|------|-------|-------|
| LoadLoad     | ❌     | ✅   | ✅    | ✅    |
| LoadStore    | ❌     | ✅   | ✅    | ✅    |
| StoreStore   | ❌     | ✅   | ✅    | ✅    |
| StoreLoad    | ✅     | ✅   | ✅    | ✅    |
| Dependent LD | ❌     | ❌   | ❌    | ✅    |

❌ = 不允许重排  ✅ = 可能重排
```

---

##### Day 6: 论文精读日（5小时）

**全天任务：精读 Boehm & Adve 论文**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 第一遍略读 | 了解论文结构、主要观点 |
| 2:00-4:00 | 第二遍精读 | 逐段理解，标注不懂的术语 |
| 4:00-5:00 | 笔记总结 | 提取关键结论，记录疑问 |

**论文阅读指南**：

论文全名：*"Foundations of the C++ Concurrency Memory Model"*

重点关注：
1. Section 2: 为什么需要语言级内存模型
2. Section 3: Data Race的定义
3. Section 4: 顺序一致性的代价
4. Section 5: 低级原子操作的需求

**阅读技巧**：
- 第一遍：只看Abstract、Introduction、Conclusion
- 第二遍：关注每节的第一段和最后一段
- 第三遍：深入例子和公式

**今日输出物**：
- [ ] 论文笔记：`notes/week1/day6_paper_notes.md`
- [ ] 疑问清单：记录3-5个不理解的问题

---

##### Day 7: 周复习与综合实验（5小时）

**上午（2.5小时）- 知识复盘**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 回顾笔记 | 复习本周所有笔记 |
| 1:00-2:00 | 知识图谱 | 绘制本周知识关系图 |
| 2:00-2:30 | 查漏补缺 | 解决Day 6论文中的疑问 |

**下午（2.5小时）- 综合实验**

**实验 1-4：经典Store Buffer问题复现**
```cpp
// day7_store_buffer_test.cpp
#include <atomic>
#include <thread>
#include <iostream>

// 使用relaxed来模拟无内存屏障的情况
std::atomic<int> x{0}, y{0};
std::atomic<int> r1{0}, r2{0};

void thread1() {
    x.store(1, std::memory_order_relaxed);
    r1.store(y.load(std::memory_order_relaxed), std::memory_order_relaxed);
}

void thread2() {
    y.store(1, std::memory_order_relaxed);
    r2.store(x.load(std::memory_order_relaxed), std::memory_order_relaxed);
}

int main() {
    int both_zero = 0;

    for (int i = 0; i < 1000000; ++i) {
        x = 0; y = 0; r1 = 0; r2 = 0;

        std::thread t1(thread1);
        std::thread t2(thread2);
        t1.join();
        t2.join();

        if (r1 == 0 && r2 == 0) {
            ++both_zero;
        }
    }

    std::cout << "Both zero count: " << both_zero << " / 1000000\n";
    std::cout << "Ratio: " << (100.0 * both_zero / 1000000) << "%\n";

    // 如果出现 both_zero > 0，说明观察到了重排序！
    return 0;
}
```

**周末检验题**：

1. **概念题**：用自己的话解释为什么需要内存模型（不超过100字）
2. **分析题**：给定一段双线程代码，分析可能的执行结果
3. **实践题**：修改上述实验，使用seq_cst验证其能消除异常结果

**今日输出物**：
- [ ] 知识图谱：`notes/week1/week1_mindmap.png`
- [ ] 周总结：`notes/week1/week1_summary.md`
- [ ] 实验报告：包含运行结果和分析

---

**核心概念**：

#### 编译器和CPU的重排序
```cpp
// 源代码
int x = 0, y = 0;

void thread1() {
    x = 1;  // (1)
    y = 2;  // (2)
}

// 编译器可能重排为：
void thread1_reordered() {
    y = 2;  // (2) 先执行
    x = 1;  // (1) 后执行
}

// 为什么？因为编译器只保证单线程语义
// 在单线程中，(1)(2)的顺序不影响结果
// 但在多线程中，另一个线程可能观察到y=2但x=0
```

#### CPU乱序执行
```cpp
// 即使编译器不重排，CPU也可能乱序执行

// CPU优化：
// 1. 指令流水线
// 2. 乱序执行（Out-of-Order Execution）
// 3. 推测执行（Speculative Execution）
// 4. Store Buffer（写缓冲区）
// 5. 缓存一致性延迟

// 经典例子：Dekker算法失败
int flag1 = 0, flag2 = 0;
int turn = 0;

// Thread 1
void thread1() {
    flag1 = 1;           // 写入可能在store buffer中
    if (flag2 == 0) {    // 读取可能先执行
        // 临界区
    }
}

// Thread 2
void thread2() {
    flag2 = 1;
    if (flag1 == 0) {
        // 临界区
    }
}

// 在x86上可能两个线程都进入临界区！
// 因为store buffer导致写操作延迟可见
```

#### 不同架构的内存模型强度
```
强内存模型 ←──────────────────────→ 弱内存模型

x86/x64          ARM/POWER           DEC Alpha
(TSO)            (弱序)              (最弱)

- 只有StoreLoad    - 所有重排都可能      - 甚至有dependent
  重排可能发生      发生                  load重排
```

### 第二周：C++内存序（Memory Order）

**学习目标**：掌握六种内存序的语义

```cpp
#include <atomic>

// C++定义了6种内存序
enum memory_order {
    memory_order_relaxed,    // 最弱
    memory_order_consume,    // 弱（不推荐使用）
    memory_order_acquire,    // 获取
    memory_order_release,    // 释放
    memory_order_acq_rel,    // 获取+释放
    memory_order_seq_cst     // 最强（默认）
};
```

---

#### 📅 第二周每日详细计划

##### Day 8: 顺序一致性（seq_cst）深度剖析（5小时）

**上午（2.5小时）- 理论理解**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | seq_cst定义 | 阅读《C++ Concurrency in Action》5.3节，理解顺序一致性 |
| 1:00-2:00 | 全局顺序 | 理解"所有线程看到一致的操作顺序"的含义 |
| 2:00-2:30 | Lamport定义 | 学习Leslie Lamport对顺序一致性的原始定义 |

**下午（2.5小时）- 实践验证**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 经典测试 | 编写并分析Store Buffering测试（见下方） |
| 1:30-2:30 | 性能测量 | 对比seq_cst与relaxed的性能差异 |

**动手实验 2-1：Store Buffering测试**
```cpp
// day8_seq_cst_test.cpp
#include <atomic>
#include <thread>
#include <iostream>

std::atomic<int> x{0}, y{0};
int r1 = 0, r2 = 0;

void thread1() {
    x.store(1, std::memory_order_seq_cst);
    r1 = y.load(std::memory_order_seq_cst);
}

void thread2() {
    y.store(1, std::memory_order_seq_cst);
    r2 = x.load(std::memory_order_seq_cst);
}

int main() {
    int count_00 = 0, count_01 = 0, count_10 = 0, count_11 = 0;

    for (int i = 0; i < 1000000; ++i) {
        x = 0; y = 0; r1 = 0; r2 = 0;

        std::thread t1(thread1);
        std::thread t2(thread2);
        t1.join();
        t2.join();

        if (r1 == 0 && r2 == 0) ++count_00;
        else if (r1 == 0 && r2 == 1) ++count_01;
        else if (r1 == 1 && r2 == 0) ++count_10;
        else ++count_11;
    }

    std::cout << "(0,0): " << count_00 << "\n";  // seq_cst保证这个为0！
    std::cout << "(0,1): " << count_01 << "\n";
    std::cout << "(1,0): " << count_10 << "\n";
    std::cout << "(1,1): " << count_11 << "\n";
    return 0;
}
```

**seq_cst的代价分析**：
```
平台        | seq_cst store 实现         | 额外开销
-----------|---------------------------|----------
x86/64     | MFENCE; MOV 或 XCHG       | 几十到上百周期
ARM        | DMB ISH; STR; DMB ISH     | 显著
POWER      | sync; store; sync         | 非常显著
```

**今日输出物**：
- [ ] 笔记：`notes/week2/day8_seq_cst.md`
- [ ] 代码：Store Buffering测试程序
- [ ] 性能数据：seq_cst vs relaxed 对比表

**思考问题**：
1. 为什么seq_cst是默认内存序？
2. 在什么场景下必须使用seq_cst？

---

##### Day 9: acquire-release语义（上）（5小时）

**上午（2.5小时）- 核心概念**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 单向屏障 | 理解acquire阻止后续操作前移，release阻止之前操作后移 |
| 1:00-2:00 | 同步关系 | 学习synchronizes-with和happens-before关系 |
| 2:00-2:30 | 配对使用 | 理解为什么acquire和release必须配对 |

**下午（2.5小时）- 经典模式**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 发布者-消费者 | 实现经典的produce-consume模式 |
| 1:30-2:30 | 对比测试 | 将seq_cst改为acquire-release，验证正确性 |

**动手实验 2-2：发布者-消费者模式**
```cpp
// day9_producer_consumer.cpp
#include <atomic>
#include <thread>
#include <iostream>
#include <cassert>

struct Data {
    int a, b, c;
};

Data data;
std::atomic<bool> ready{false};

void producer() {
    // 准备数据（这些写操作在release之前）
    data.a = 1;
    data.b = 2;
    data.c = 3;

    // Release: 确保上面的写在ready=true之前完成
    ready.store(true, std::memory_order_release);
}

void consumer() {
    // Acquire: 等待并获取数据
    while (!ready.load(std::memory_order_acquire)) {
        // 自旋等待
    }

    // 这些读操作保证在acquire之后
    // 由于synchronizes-with关系，保证看到producer的写入
    assert(data.a == 1);
    assert(data.b == 2);
    assert(data.c == 3);

    std::cout << "Data received: " << data.a << ", "
              << data.b << ", " << data.c << std::endl;
}

int main() {
    for (int i = 0; i < 100000; ++i) {
        data = {0, 0, 0};
        ready = false;

        std::thread t1(producer);
        std::thread t2(consumer);
        t1.join();
        t2.join();
    }
    std::cout << "All iterations passed!\n";
    return 0;
}
```

**图解：acquire-release同步**
```
Thread 1 (Producer)         Thread 2 (Consumer)
==================         ==================
data.a = 1                        |
data.b = 2                        |
data.c = 3                        |
    |                             |
    ↓                             |
ready.store(true, release) ----→ ready.load(acquire)
    |                             |
    |                         assert(data.a == 1)
    |                         assert(data.b == 2)
    |                         assert(data.c == 3)

箭头表示 synchronizes-with 关系
```

**今日输出物**：
- [ ] 笔记：`notes/week2/day9_acquire_release_1.md`
- [ ] 代码：发布者-消费者模式实现
- [ ] 图解：绘制synchronizes-with关系图

---

##### Day 10: acquire-release语义（下）（5小时）

**上午（2.5小时）- 传递性与链式同步**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | happens-before传递性 | 理解A→B且B→C则A→C |
| 1:00-2:00 | Release Sequence | 学习释放序列的概念和作用 |
| 2:00-2:30 | 多线程链式同步 | 分析三个或更多线程的同步场景 |

**下午（2.5小时）- acq_rel组合使用**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | memory_order_acq_rel | 理解读-修改-写操作的双向语义 |
| 1:30-2:30 | 实践案例 | 实现一个简单的自旋锁 |

**动手实验 2-3：Release Sequence示例**
```cpp
// day10_release_sequence.cpp
#include <atomic>
#include <thread>
#include <vector>
#include <iostream>

std::atomic<int> count{0};
int data = 0;

void producer() {
    data = 42;
    count.store(1, std::memory_order_release);
}

void relay() {
    int expected = 1;
    // fetch_add 是 read-modify-write，参与 release sequence
    while (count.load(std::memory_order_relaxed) < 1);
    count.fetch_add(1, std::memory_order_relaxed);
}

void consumer() {
    // acquire 与 producer 的 release 同步（通过 release sequence）
    while (count.load(std::memory_order_acquire) < 2);
    std::cout << "data = " << data << std::endl;  // 保证输出 42
}

int main() {
    std::thread t1(producer);
    std::thread t2(relay);
    std::thread t3(consumer);
    t1.join();
    t2.join();
    t3.join();
    return 0;
}
```

**动手实验 2-4：使用acq_rel实现自旋锁**
```cpp
// day10_spinlock_acq_rel.cpp
#include <atomic>
#include <thread>
#include <iostream>

class SpinLock {
    std::atomic<bool> locked_{false};

public:
    void lock() {
        while (locked_.exchange(true, std::memory_order_acquire)) {
            // 自旋
            while (locked_.load(std::memory_order_relaxed)) {
                // TTAS: Test-and-Test-and-Set
                #if defined(__x86_64__)
                __builtin_ia32_pause();
                #endif
            }
        }
    }

    void unlock() {
        locked_.store(false, std::memory_order_release);
    }
};

SpinLock spinlock;
int shared_data = 0;

void worker(int id) {
    for (int i = 0; i < 100000; ++i) {
        spinlock.lock();
        ++shared_data;
        spinlock.unlock();
    }
}

int main() {
    std::thread t1(worker, 1);
    std::thread t2(worker, 2);
    t1.join();
    t2.join();
    std::cout << "shared_data = " << shared_data << std::endl;
    // 应该输出 200000
    return 0;
}
```

**今日输出物**：
- [ ] 笔记：`notes/week2/day10_acquire_release_2.md`
- [ ] 代码：Release Sequence 示例 + 自旋锁实现

---

##### Day 11: relaxed内存序（5小时）

**上午（2.5小时）- relaxed语义详解**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 只保证原子性 | 理解relaxed不建立任何同步关系 |
| 1:00-2:00 | 合法用例 | 学习统计计数器、引用计数增加等场景 |
| 2:00-2:30 | 危险用例 | 分析错误使用relaxed导致的bug |

**下午（2.5小时）- 实践对比**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 性能测试 | 对比relaxed与seq_cst计数器性能 |
| 1:30-2:30 | 混合使用 | 实现引用计数（增加用relaxed，减少用acq_rel） |

**动手实验 2-5：relaxed计数器性能测试**
```cpp
// day11_relaxed_counter.cpp
#include <atomic>
#include <thread>
#include <chrono>
#include <iostream>
#include <vector>

template<std::memory_order MO>
void benchmark(const char* name) {
    std::atomic<long long> counter{0};
    const int num_threads = 4;
    const int iterations = 10000000;

    auto start = std::chrono::high_resolution_clock::now();

    std::vector<std::thread> threads;
    for (int i = 0; i < num_threads; ++i) {
        threads.emplace_back([&] {
            for (int j = 0; j < iterations; ++j) {
                counter.fetch_add(1, MO);
            }
        });
    }

    for (auto& t : threads) t.join();

    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

    std::cout << name << ": " << duration.count() << "ms, "
              << "counter = " << counter << std::endl;
}

int main() {
    benchmark<std::memory_order_seq_cst>("seq_cst");
    benchmark<std::memory_order_relaxed>("relaxed");
    return 0;
}
```

**动手实验 2-6：引用计数实现**
```cpp
// day11_refcount.cpp
#include <atomic>
#include <iostream>

class RefCounted {
    mutable std::atomic<int> ref_count_{1};

public:
    void add_ref() const {
        // 增加：relaxed足够，因为不需要与其他操作同步
        // 只要对象存在，增加引用计数总是安全的
        ref_count_.fetch_add(1, std::memory_order_relaxed);
    }

    bool release() const {
        // 减少：需要acq_rel
        // - acquire: 确保看到其他线程对对象的所有修改
        // - release: 确保本线程的修改在删除前对其他线程可见
        int prev = ref_count_.fetch_sub(1, std::memory_order_acq_rel);

        if (prev == 1) {
            // 最后一个引用
            // 需要一个acquire fence确保看到所有修改
            // 注意：fetch_sub的acquire语义已经提供了这个保证
            return true;  // 调用者应该删除对象
        }
        return false;
    }

    int count() const {
        return ref_count_.load(std::memory_order_relaxed);
    }
};

// 使用示例
int main() {
    RefCounted obj;
    std::cout << "Initial count: " << obj.count() << std::endl;

    obj.add_ref();
    std::cout << "After add_ref: " << obj.count() << std::endl;

    obj.release();
    std::cout << "After release: " << obj.count() << std::endl;

    bool should_delete = obj.release();
    std::cout << "Should delete: " << (should_delete ? "yes" : "no") << std::endl;

    return 0;
}
```

**relaxed使用决策树**：
```
是否需要与其他操作同步？
    ├── 是 → 不要使用relaxed
    └── 否 → 这个原子变量是否...
              ├── 纯计数器（只关心最终值）→ 可以使用relaxed
              ├── 引用计数增加 → 可以使用relaxed
              ├── 统计数据收集 → 可以使用relaxed
              └── 其他 → 仔细分析，可能需要更强的序
```

**今日输出物**：
- [ ] 笔记：`notes/week2/day11_relaxed.md`
- [ ] 代码：性能测试 + 引用计数实现
- [ ] 决策图：何时使用relaxed

---

##### Day 12: consume语义与为何避免（5小时）

**上午（2.5小时）- consume的设计初衷**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | consume定义 | 理解consume只传播数据依赖 |
| 1:00-2:00 | 与acquire对比 | 分析consume比acquire更弱的原因 |
| 2:00-2:30 | 理论优势 | 理解consume在弱内存模型上的性能优势 |

**下午（2.5小时）- 为什么不推荐**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 编译器困境 | 理解编译器难以正确实现consume的原因 |
| 1:00-2:00 | 标准现状 | 了解C++17对consume的"降级"处理 |
| 2:00-2:30 | 替代方案 | 学习用acquire替代consume |

**consume的理论模型**：
```cpp
// consume理论上只传播"依赖"
std::atomic<int*> ptr{nullptr};
int data = 0;

void producer() {
    data = 42;
    int* p = new int(100);
    ptr.store(p, std::memory_order_release);
}

void consumer() {
    int* p = ptr.load(std::memory_order_consume);  // 理论上
    if (p) {
        // 只有通过p访问的数据才保证同步
        int x = *p;     // 保证正确：依赖于p
        int y = data;   // 不保证！没有依赖关系
    }
}

// 实际上，所有编译器都将consume实现为acquire
// 因为追踪依赖链太复杂
```

**为什么consume难以实现**：
```cpp
// 编译器需要追踪所有可能的依赖

int* p = ptr.load(std::memory_order_consume);
int a = *p;          // 明显依赖
int b = *(p + 0);    // 依赖？(p + 0 == p)
int c = arr[p - q];  // 依赖？(取决于运行时值)
int d = func(p);     // 依赖？(取决于func内部)

// 追踪这些太复杂，编译器选择直接用acquire
```

**扩展阅读**：
- P0371R1: "Temporarily discourage memory_order_consume"
- Paul McKenney 关于 RCU 和 consume 的讨论

**今日输出物**：
- [ ] 笔记：`notes/week2/day12_consume.md`
- [ ] 理解总结：为什么consume被"废弃"

**常见误区警示**：
> ⚠️ **误区**：consume比acquire性能更好，应该尽量使用
>
> **真相**：
> 1. 所有主流编译器都将consume实现为acquire
> 2. C++17开始"强烈不推荐"使用consume
> 3. 未来可能会有新的机制替代consume
>
> **正确做法**：始终使用acquire，等待标准演进

---

##### Day 13: 内存序综合对比（5小时）

**上午（2.5小时）- 六种内存序总结**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 制作对比表 | 整理六种内存序的语义、开销、用例 |
| 1:30-2:30 | 决策流程 | 设计"选择内存序"的决策树 |

**下午（2.5小时）- 综合实验**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 混合使用 | 编写使用多种内存序的程序 |
| 1:30-2:30 | 正确性验证 | 用压力测试验证程序正确性 |

**内存序完整对比表**：
```
| 内存序     | 原子性 | 顺序保证              | 典型用例             | 性能 |
|-----------|--------|---------------------|---------------------|------|
| relaxed   | ✅     | 无                   | 计数器、统计         | 最好 |
| consume   | ✅     | 数据依赖（已废弃）     | 不推荐使用           | -    |
| acquire   | ✅     | 后续操作不前移        | 读端同步             | 好   |
| release   | ✅     | 之前操作不后移        | 写端同步             | 好   |
| acq_rel   | ✅     | acquire + release   | RMW操作              | 中   |
| seq_cst   | ✅     | 全局顺序一致          | 需要全序时           | 最差 |
```

**动手实验 2-7：综合使用示例**
```cpp
// day13_comprehensive.cpp
#include <atomic>
#include <thread>
#include <vector>
#include <iostream>
#include <cassert>

// 一个简单的无锁栈（展示多种内存序的使用）
template<typename T>
class LockFreeStack {
    struct Node {
        T data;
        Node* next;
    };

    std::atomic<Node*> head_{nullptr};
    std::atomic<int> size_{0};  // 仅用于统计，relaxed即可

public:
    void push(T value) {
        Node* new_node = new Node{value, nullptr};

        // 先更新size（relaxed，因为只是统计）
        size_.fetch_add(1, std::memory_order_relaxed);

        // CAS循环
        new_node->next = head_.load(std::memory_order_relaxed);
        while (!head_.compare_exchange_weak(
            new_node->next, new_node,
            std::memory_order_release,  // 成功时release
            std::memory_order_relaxed   // 失败时relaxed重试
        ));
    }

    bool pop(T& result) {
        Node* old_head = head_.load(std::memory_order_acquire);

        while (old_head) {
            if (head_.compare_exchange_weak(
                old_head, old_head->next,
                std::memory_order_acquire,  // 成功时acquire
                std::memory_order_relaxed   // 失败时relaxed重试
            )) {
                result = old_head->data;
                size_.fetch_sub(1, std::memory_order_relaxed);
                delete old_head;
                return true;
            }
        }
        return false;
    }

    int size() const {
        return size_.load(std::memory_order_relaxed);
    }
};

int main() {
    LockFreeStack<int> stack;

    std::vector<std::thread> threads;

    // 生产者线程
    for (int i = 0; i < 4; ++i) {
        threads.emplace_back([&, i] {
            for (int j = 0; j < 10000; ++j) {
                stack.push(i * 10000 + j);
            }
        });
    }

    // 消费者线程
    std::atomic<int> pop_count{0};
    for (int i = 0; i < 4; ++i) {
        threads.emplace_back([&] {
            int value;
            while (pop_count.load(std::memory_order_relaxed) < 40000) {
                if (stack.pop(value)) {
                    pop_count.fetch_add(1, std::memory_order_relaxed);
                }
            }
        });
    }

    for (auto& t : threads) t.join();

    std::cout << "Final size: " << stack.size() << std::endl;
    std::cout << "Total popped: " << pop_count << std::endl;

    return 0;
}
```

**内存序选择决策树**：
```
需要原子操作吗？
├── 否 → 使用普通变量
└── 是 → 需要与其他线程同步吗？
          ├── 否 → memory_order_relaxed
          └── 是 → 是读操作还是写操作？
                    ├── 读 → memory_order_acquire
                    ├── 写 → memory_order_release
                    ├── 读-修改-写 → memory_order_acq_rel
                    └── 需要全局顺序？→ memory_order_seq_cst
```

**今日输出物**：
- [ ] 笔记：`notes/week2/day13_comparison.md`
- [ ] 代码：无锁栈实现
- [ ] 决策树：内存序选择指南

---

##### Day 14: 周复习与压力测试（5小时）

**上午（2.5小时）- 知识整合**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 复习笔记 | 回顾本周所有内存序的学习 |
| 1:00-2:00 | 制作速查卡 | 制作内存序选择速查表 |
| 2:00-2:30 | 疑难解答 | 解决学习中遇到的问题 |

**下午（2.5小时）- 压力测试实验**

**实验 2-8：并发压力测试框架**
```cpp
// day14_stress_test.cpp
#include <atomic>
#include <thread>
#include <vector>
#include <iostream>
#include <functional>
#include <chrono>

// 通用压力测试框架
template<typename Setup, typename Thread1, typename Thread2, typename Check>
void stress_test(
    const char* name,
    int iterations,
    Setup setup,
    Thread1 thread1,
    Thread2 thread2,
    Check check
) {
    int failures = 0;

    for (int i = 0; i < iterations; ++i) {
        setup();

        std::thread t1(thread1);
        std::thread t2(thread2);
        t1.join();
        t2.join();

        if (!check()) {
            ++failures;
        }
    }

    std::cout << name << ": "
              << (failures == 0 ? "PASSED" : "FAILED")
              << " (" << failures << "/" << iterations << " failures)"
              << std::endl;
}

// 测试1: Store Buffering with seq_cst (应该通过)
void test_store_buffering_seq_cst() {
    std::atomic<int> x{0}, y{0};
    int r1 = 0, r2 = 0;

    stress_test(
        "Store Buffering (seq_cst)",
        100000,
        [&] { x = 0; y = 0; r1 = 0; r2 = 0; },
        [&] {
            x.store(1, std::memory_order_seq_cst);
            r1 = y.load(std::memory_order_seq_cst);
        },
        [&] {
            y.store(1, std::memory_order_seq_cst);
            r2 = x.load(std::memory_order_seq_cst);
        },
        [&] { return !(r1 == 0 && r2 == 0); }  // 不应该同时为0
    );
}

// 测试2: Message Passing with acquire-release (应该通过)
void test_message_passing() {
    int data = 0;
    std::atomic<bool> ready{false};
    int observed = 0;

    stress_test(
        "Message Passing (acq-rel)",
        100000,
        [&] { data = 0; ready = false; observed = 0; },
        [&] {
            data = 42;
            ready.store(true, std::memory_order_release);
        },
        [&] {
            while (!ready.load(std::memory_order_acquire));
            observed = data;
        },
        [&] { return observed == 42; }
    );
}

// 测试3: Message Passing with relaxed (可能失败)
void test_message_passing_relaxed() {
    int data = 0;
    std::atomic<bool> ready{false};
    int observed = 0;

    stress_test(
        "Message Passing (relaxed - may fail)",
        100000,
        [&] { data = 0; ready = false; observed = 0; },
        [&] {
            data = 42;
            ready.store(true, std::memory_order_relaxed);
        },
        [&] {
            while (!ready.load(std::memory_order_relaxed));
            observed = data;
        },
        [&] { return observed == 42; }
    );
}

int main() {
    test_store_buffering_seq_cst();
    test_message_passing();
    test_message_passing_relaxed();
    return 0;
}
```

**周末检验题**：

1. **概念题**：解释acquire和release如何建立synchronizes-with关系

2. **分析题**：以下代码是否正确？为什么？
```cpp
std::atomic<bool> flag{false};
int data = 0;

void thread1() {
    data = 42;
    flag.store(true, std::memory_order_relaxed);  // 正确吗？
}

void thread2() {
    while (!flag.load(std::memory_order_acquire));
    assert(data == 42);  // 能保证成功吗？
}
```

3. **设计题**：设计一个三线程程序，展示release sequence的作用

**今日输出物**：
- [ ] 压力测试框架及结果
- [ ] 周总结：`notes/week2/week2_summary.md`
- [ ] 速查卡：内存序选择指南

---

#### memory_order_seq_cst（顺序一致性）
```cpp
// 最强保证：
// 1. 所有线程看到的原子操作顺序一致
// 2. 存在一个全局总顺序

std::atomic<bool> x{false}, y{false};
std::atomic<int> z{0};

void write_x() { x.store(true); }  // 默认seq_cst
void write_y() { y.store(true); }

void read_x_then_y() {
    while (!x.load());  // 等待x为true
    if (y.load()) ++z;
}

void read_y_then_x() {
    while (!y.load());  // 等待y为true
    if (x.load()) ++z;
}

// 四个线程分别执行上述四个函数
// 最终z至少为1

// 但seq_cst有性能开销：
// 在x86上，store需要MFENCE或使用XCHG
// 在ARM上，需要DMB（数据内存屏障）
```

#### memory_order_acquire / memory_order_release
```cpp
// Release-Acquire语义：建立同步关系

std::atomic<int> data{0};
std::atomic<bool> ready{false};

void producer() {
    data.store(42, std::memory_order_relaxed);  // (1)
    ready.store(true, std::memory_order_release);  // (2) release
}

void consumer() {
    while (!ready.load(std::memory_order_acquire));  // (3) acquire
    int value = data.load(std::memory_order_relaxed);  // (4)
    assert(value == 42);  // 保证成功！
}

// 原理：
// - release保证：(1)在(2)之前完成（不会重排到后面）
// - acquire保证：(4)在(3)之后执行（不会重排到前面）
// - (2)和(3)建立"同步"关系：release的写对acquire的读可见
// - 因此(1)的结果对(4)可见
```

#### Synchronizes-With关系
```cpp
// 当一个线程的release操作被另一个线程的acquire操作读取时
// 建立synchronizes-with关系

// Release操作之前的所有写入
// 对Acquire操作之后的所有读取可见

// 这称为"单向栅栏"：
// - Release阻止之前的操作重排到后面
// - Acquire阻止之后的操作重排到前面
```

#### memory_order_relaxed
```cpp
// 最弱保证：只保证原子性，不保证顺序

std::atomic<int> counter{0};

void increment() {
    // 用于简单计数，不需要与其他操作同步
    counter.fetch_add(1, std::memory_order_relaxed);
}

// 适用场景：
// - 纯计数器，只关心最终结果
// - 引用计数（减少时需要更强的序）
// - 统计数据收集
```

### 第三周：内存屏障与硬件映射

**学习目标**：理解内存序如何映射到硬件指令

---

#### 📅 第三周每日详细计划

##### Day 15: 内存屏障概念与分类（5小时）

**上午（2.5小时）- 屏障类型理论**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 屏障定义 | 理解内存屏障的本质：控制可见性和顺序 |
| 1:00-2:00 | 四种屏障 | 学习LoadLoad、LoadStore、StoreLoad、StoreStore |
| 2:00-2:30 | 屏障组合 | 理解完全屏障(Full Barrier)是四种的组合 |

**下午（2.5小时）- 与C++内存序对应**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 映射关系 | 分析每种C++内存序对应哪些屏障 |
| 1:30-2:30 | 代码分析 | 使用atomic_thread_fence验证屏障效果 |

**屏障语义详解**：
```
LoadLoad屏障：
  之前的Load ──→ [LoadLoad] ──→ 之后的Load
  保证：之前的Load在之后的Load之前完成

StoreStore屏障：
  之前的Store ──→ [StoreStore] ──→ 之后的Store
  保证：之前的Store对其他处理器可见后，才执行之后的Store

LoadStore屏障：
  之前的Load ──→ [LoadStore] ──→ 之后的Store
  保证：之前的Load完成后，才执行之后的Store

StoreLoad屏障：（最重量级）
  之前的Store ──→ [StoreLoad] ──→ 之后的Load
  保证：之前的Store对其他处理器可见后，才执行之后的Load
  这是唯一需要刷新Store Buffer的屏障
```

**C++内存序与屏障对应**：
```
内存序          | 等效屏障
----------------|------------------------
relaxed         | 无屏障
acquire         | LoadLoad + LoadStore
release         | LoadStore + StoreStore
acq_rel         | LoadLoad + LoadStore + StoreStore
seq_cst load    | LoadLoad + LoadStore + acquire fence
seq_cst store   | 全部四种（特别是StoreLoad）
```

**动手实验 3-1：atomic_thread_fence使用**
```cpp
// day15_fence_test.cpp
#include <atomic>
#include <thread>
#include <iostream>
#include <cassert>

int data = 0;
std::atomic<bool> ready{false};

void producer() {
    data = 42;
    // 显式fence，等效于release语义
    std::atomic_thread_fence(std::memory_order_release);
    ready.store(true, std::memory_order_relaxed);
}

void consumer() {
    while (!ready.load(std::memory_order_relaxed));
    // 显式fence，等效于acquire语义
    std::atomic_thread_fence(std::memory_order_acquire);
    assert(data == 42);
    std::cout << "data = " << data << std::endl;
}

int main() {
    for (int i = 0; i < 100000; ++i) {
        data = 0;
        ready = false;

        std::thread t1(producer);
        std::thread t2(consumer);
        t1.join();
        t2.join();
    }
    std::cout << "All tests passed!\n";
    return 0;
}
```

**今日输出物**：
- [ ] 笔记：`notes/week3/day15_barriers.md`
- [ ] 图表：四种屏障的作用示意图

**思考问题**：
1. 为什么StoreLoad是最重量级的屏障？
2. 显式fence与原子操作内置语义有什么区别？

---

##### Day 16: x86/x64内存模型详解（5小时）

**上午（2.5小时）- TSO模型深入**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | TSO定义 | 深入理解Total Store Order的精确语义 |
| 1:00-2:00 | Store Buffer | 分析x86的Store Buffer如何导致StoreLoad重排 |
| 2:00-2:30 | Intel文档 | 阅读Intel SDM相关章节 |

**下午（2.5小时）- 汇编分析**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | Godbolt实践 | 使用Compiler Explorer分析不同内存序生成的汇编 |
| 1:30-2:30 | MFENCE分析 | 理解MFENCE、LOCK前缀、XCHG的作用 |

**x86内存序实现**：
```asm
; relaxed load
mov eax, [x]          ; 普通load，无屏障

; relaxed store
mov [x], eax          ; 普通store，无屏障

; acquire load
mov eax, [x]          ; x86天然保证LoadLoad和LoadStore
                      ; 所以acquire不需要额外指令！

; release store
mov [x], eax          ; x86天然保证StoreStore
                      ; 所以release也不需要额外指令！

; seq_cst load
mov eax, [x]          ; 普通load足够
; 或
mfence
mov eax, [x]          ; 某些编译器的实现

; seq_cst store (关键！)
; 方案1:
xchg [x], eax         ; XCHG自带lock语义，有full barrier效果
; 方案2:
mov [x], eax
mfence                ; 显式full barrier
```

**动手实验 3-2：查看x86汇编**
```cpp
// day16_x86_asm.cpp
// 使用 g++ -O2 -S day16_x86_asm.cpp 查看汇编
// 或在 https://godbolt.org/ 在线查看

#include <atomic>

std::atomic<int> x{0};
int y = 0;

void test_relaxed() {
    y = x.load(std::memory_order_relaxed);
    x.store(42, std::memory_order_relaxed);
}

void test_acquire_release() {
    y = x.load(std::memory_order_acquire);
    x.store(42, std::memory_order_release);
}

void test_seq_cst() {
    y = x.load(std::memory_order_seq_cst);
    x.store(42, std::memory_order_seq_cst);
}

// 观察：
// 1. relaxed和acquire/release在x86上生成相同的mov指令
// 2. seq_cst store会生成xchg或mov+mfence
```

**x86内存保证速查表**：
```
操作组合           | x86保证           | 需要屏障？
------------------|------------------|----------
Load → Load       | ✅ 保证顺序       | ❌
Load → Store      | ✅ 保证顺序       | ❌
Store → Store     | ✅ 保证顺序       | ❌
Store → Load      | ❌ 可能重排       | ✅ 需要MFENCE
```

**今日输出物**：
- [ ] 笔记：`notes/week3/day16_x86_model.md`
- [ ] 截图：Godbolt汇编分析对比
- [ ] 总结：x86内存序开销分析

---

##### Day 17: ARM内存模型详解（5小时）

**上午（2.5小时）- ARM弱内存模型**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 弱序特点 | 理解ARM允许几乎所有类型的重排 |
| 1:00-2:00 | DMB指令 | 学习Data Memory Barrier的变体(ISH, OSH, SY) |
| 2:00-2:30 | DSB/ISB | 了解其他同步指令 |

**下午（2.5小时）- ARMv8原子指令**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | LDAR/STLR | 学习ARMv8的Load-Acquire/Store-Release指令 |
| 1:30-2:30 | 汇编分析 | 使用Godbolt查看ARM平台的atomic实现 |

**ARM内存序实现**：
```asm
; ARMv8之前需要显式DMB

; acquire load (ARMv7)
ldr r0, [x]
dmb ish              ; Inner Shareable domain barrier

; release store (ARMv7)
dmb ish
str r0, [x]

; ARMv8有专门的指令

; acquire load (ARMv8)
ldar r0, [x]         ; Load-Acquire，自带acquire语义

; release store (ARMv8)
stlr r0, [x]         ; Store-Release，自带release语义

; seq_cst (ARMv8)
; load:
ldar r0, [x]
; store:
stlr r0, [x]
; 注意：seq_cst可能需要额外屏障来保证全局顺序
```

**ARM DMB变体详解**：
```
DMB ISH  - Inner Shareable：同一cluster内的处理器可见
DMB OSH  - Outer Shareable：所有共享内存的处理器可见
DMB SY   - System：整个系统可见

大多数情况使用ISH即可
```

**动手实验 3-3：ARM汇编分析**
```cpp
// day17_arm_asm.cpp
// 在Godbolt选择ARM GCC或Clang查看

#include <atomic>

std::atomic<int> flag{0};
int data = 0;

void producer() {
    data = 42;
    flag.store(1, std::memory_order_release);
}

void consumer() {
    while (flag.load(std::memory_order_acquire) == 0);
    int x = data;
}

// 观察ARMv7 vs ARMv8的差异：
// ARMv7: 使用dmb
// ARMv8: 使用ldar/stlr
```

**今日输出物**：
- [ ] 笔记：`notes/week3/day17_arm_model.md`
- [ ] 对比表：x86 vs ARM 汇编指令对比

---

##### Day 18: 查看和分析生成的汇编（5小时）

**上午（2.5小时）- 工具使用**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | Godbolt技巧 | 深入学习Compiler Explorer的高级功能 |
| 1:00-2:00 | objdump使用 | 学习使用objdump分析本地编译结果 |
| 2:00-2:30 | GCC选项 | 掌握-S, -fverbose-asm等选项 |

**下午（2.5小时）- 实战分析**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 案例分析 | 分析实际项目中的原子操作汇编 |
| 1:30-2:30 | 优化对比 | 对比不同优化级别的汇编差异 |

**工具使用指南**：

**Godbolt (godbolt.org)**：
```
1. 选择编译器（GCC, Clang）和架构（x86-64, ARM, ARM64）
2. 添加编译选项：-std=c++17 -O2
3. 点击"Add new..."添加对比窗口
4. 使用颜色对应功能追踪代码行

快捷技巧：
- 选中源码行会高亮对应汇编
- 可以同时对比多个编译器
- 可以分享链接保存结果
```

**本地分析命令**：
```bash
# 生成汇编
g++ -std=c++17 -O2 -S -fverbose-asm -o output.s input.cpp

# 从目标文件反汇编
g++ -std=c++17 -O2 -c input.cpp -o output.o
objdump -d output.o

# 带源码的反汇编
g++ -std=c++17 -O2 -g -c input.cpp -o output.o
objdump -d -S output.o

# 查看特定函数
objdump -d output.o | grep -A 50 "<_Z4testv>:"
```

**动手实验 3-4：完整分析流程**
```cpp
// day18_asm_analysis.cpp
#include <atomic>

std::atomic<int> counter{0};

// 1. 分析fetch_add的实现
void increment_relaxed() {
    counter.fetch_add(1, std::memory_order_relaxed);
}

void increment_seq_cst() {
    counter.fetch_add(1, std::memory_order_seq_cst);
}

// 2. 分析compare_exchange的实现
bool try_set(int expected, int desired) {
    return counter.compare_exchange_strong(
        expected, desired,
        std::memory_order_acq_rel,
        std::memory_order_acquire
    );
}

// 3. 分析显式fence
void with_fence() {
    int x = counter.load(std::memory_order_relaxed);
    std::atomic_thread_fence(std::memory_order_seq_cst);
    counter.store(x + 1, std::memory_order_relaxed);
}
```

**预期汇编分析（x86-64）**：
```asm
; increment_relaxed:
lock add DWORD PTR counter[rip], 1
ret

; increment_seq_cst:
lock add DWORD PTR counter[rip], 1   ; lock前缀本身就有full barrier效果
ret

; try_set (compare_exchange):
mov eax, edi
lock cmpxchg DWORD PTR counter[rip], esi
sete al
ret

; with_fence:
mov eax, DWORD PTR counter[rip]
mfence                              ; seq_cst fence
add eax, 1
mov DWORD PTR counter[rip], eax
ret
```

**今日输出物**：
- [ ] 笔记：`notes/week3/day18_asm_tools.md`
- [ ] 实验报告：不同内存序的汇编对比分析

---

##### Day 19: 性能测量与分析（5小时）

**上午（2.5小时）- 性能测试方法**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 微基准测试 | 学习编写正确的微基准测试 |
| 1:00-2:00 | 避免陷阱 | 理解编译器优化对测试的影响 |
| 2:00-2:30 | 工具使用 | 学习perf, cachegrind等工具 |

**下午（2.5小时）- 实际测量**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 性能对比 | 测量不同内存序的性能差异 |
| 1:30-2:30 | 争用分析 | 分析高争用场景下的性能 |

**动手实验 3-5：内存序性能基准测试**
```cpp
// day19_benchmark.cpp
#include <atomic>
#include <thread>
#include <chrono>
#include <iostream>
#include <vector>
#include <iomanip>

// 防止编译器优化掉结果
template<typename T>
void do_not_optimize(T&& value) {
    asm volatile("" : "+r"(value));
}

// 单线程性能测试
template<std::memory_order MO>
double single_thread_bench(int iterations) {
    std::atomic<long long> counter{0};

    auto start = std::chrono::high_resolution_clock::now();

    for (int i = 0; i < iterations; ++i) {
        counter.fetch_add(1, MO);
        do_not_optimize(counter);
    }

    auto end = std::chrono::high_resolution_clock::now();
    auto ns = std::chrono::duration_cast<std::chrono::nanoseconds>(end - start).count();

    return static_cast<double>(ns) / iterations;
}

// 多线程争用测试
template<std::memory_order MO>
double contended_bench(int threads, int iterations_per_thread) {
    std::atomic<long long> counter{0};

    auto start = std::chrono::high_resolution_clock::now();

    std::vector<std::thread> workers;
    for (int t = 0; t < threads; ++t) {
        workers.emplace_back([&] {
            for (int i = 0; i < iterations_per_thread; ++i) {
                counter.fetch_add(1, MO);
            }
        });
    }

    for (auto& w : workers) w.join();

    auto end = std::chrono::high_resolution_clock::now();
    auto ns = std::chrono::duration_cast<std::chrono::nanoseconds>(end - start).count();

    return static_cast<double>(ns) / (threads * iterations_per_thread);
}

int main() {
    const int iterations = 10000000;
    const int threads = 4;
    const int per_thread = 2500000;

    std::cout << std::fixed << std::setprecision(2);

    std::cout << "=== Single Thread Performance ===\n";
    std::cout << "relaxed: " << single_thread_bench<std::memory_order_relaxed>(iterations) << " ns/op\n";
    std::cout << "seq_cst: " << single_thread_bench<std::memory_order_seq_cst>(iterations) << " ns/op\n";

    std::cout << "\n=== Contended Performance (" << threads << " threads) ===\n";
    std::cout << "relaxed: " << contended_bench<std::memory_order_relaxed>(threads, per_thread) << " ns/op\n";
    std::cout << "seq_cst: " << contended_bench<std::memory_order_seq_cst>(threads, per_thread) << " ns/op\n";

    return 0;
}
```

**使用perf分析**：
```bash
# 编译
g++ -std=c++17 -O2 -g day19_benchmark.cpp -o bench -lpthread

# 运行perf统计
perf stat -e cycles,instructions,cache-references,cache-misses ./bench

# 运行perf采样
perf record -g ./bench
perf report

# 查看缓存行为
valgrind --tool=cachegrind ./bench
```

**预期结果分析**：
```
平台: x86-64

单线程:
- relaxed 和 seq_cst 差异很小（因为lock前缀本身就是full barrier）

多线程高争用:
- 主要开销在缓存一致性协议
- 争用导致的缓存行弹跳(cache line bouncing)
- 不同内存序差异可能被争用开销掩盖

ARM平台:
- 差异更明显
- relaxed明显快于seq_cst
```

**今日输出物**：
- [ ] 笔记：`notes/week3/day19_performance.md`
- [ ] 性能报告：不同平台、不同争用度的测试数据

---

##### Day 20: Linux内核内存屏障分析（5小时）

**上午（2.5小时）- 内核屏障宏**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 屏障API | 学习mb(), rmb(), wmb(), smp_mb()等 |
| 1:00-2:00 | 源码阅读 | 阅读arch/x86/include/asm/barrier.h |
| 2:00-2:30 | 对比C++ | 对比内核屏障与C++内存序 |

**下午（2.5小时）- RCU分析**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | RCU基础 | 理解Read-Copy-Update的核心思想 |
| 1:30-2:30 | 屏障使用 | 分析RCU中的内存屏障使用 |

**Linux内核屏障宏**：
```c
// arch/x86/include/asm/barrier.h

// 通用内存屏障
#define mb()    asm volatile("mfence" ::: "memory")
#define rmb()   asm volatile("lfence" ::: "memory")
#define wmb()   asm volatile("sfence" ::: "memory")

// SMP屏障（仅在SMP系统有效）
#ifdef CONFIG_SMP
#define smp_mb()    mb()
#define smp_rmb()   rmb()
#define smp_wmb()   wmb()
#else
#define smp_mb()    barrier()
#define smp_rmb()   barrier()
#define smp_wmb()   barrier()
#endif

// 编译器屏障（不生成CPU指令，只阻止编译器重排）
#define barrier()   asm volatile("" ::: "memory")

// 单向屏障（类似acquire/release）
#define smp_store_release(p, v)  \
    do { barrier(); WRITE_ONCE(*(p), (v)); } while (0)

#define smp_load_acquire(p)  \
    ({ typeof(*(p)) ___p = READ_ONCE(*(p)); barrier(); ___p; })
```

**Linux vs C++ 对应关系**：
```
Linux内核              | C++
----------------------|------------------------
barrier()             | std::atomic_signal_fence
smp_mb()              | std::atomic_thread_fence(seq_cst)
smp_wmb()             | std::atomic_thread_fence(release) (部分)
smp_rmb()             | std::atomic_thread_fence(acquire) (部分)
smp_store_release     | store(release)
smp_load_acquire      | load(acquire)
READ_ONCE/WRITE_ONCE  | volatile + 可能的atomic
```

**扩展阅读**：
- Linux内核文档：Documentation/memory-barriers.txt
- Paul McKenney: "Is Parallel Programming Hard?"

**今日输出物**：
- [ ] 笔记：`notes/week3/day20_kernel_barriers.md`
- [ ] 对比表：Linux内核屏障 vs C++内存序

---

##### Day 21: 周复习与跨平台实验（5小时）

**上午（2.5小时）- 知识整合**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 复习笔记 | 回顾本周所有硬件映射内容 |
| 1:00-2:00 | 制作对照表 | 完成x86/ARM/内核的完整对照表 |
| 2:00-2:30 | 疑难解答 | 解决学习中的疑问 |

**下午（2.5小时）- 跨平台验证**

**实验 3-6：跨平台可移植代码测试**
```cpp
// day21_portable_test.cpp
// 这段代码应该在所有平台上都正确工作

#include <atomic>
#include <thread>
#include <iostream>
#include <cassert>

// 平台无关的生产者-消费者实现
class PortableQueue {
    static constexpr int SIZE = 1024;
    int buffer_[SIZE];
    std::atomic<int> head_{0};
    std::atomic<int> tail_{0};

public:
    bool push(int value) {
        int tail = tail_.load(std::memory_order_relaxed);
        int next_tail = (tail + 1) % SIZE;

        if (next_tail == head_.load(std::memory_order_acquire)) {
            return false;  // 队列满
        }

        buffer_[tail] = value;
        tail_.store(next_tail, std::memory_order_release);
        return true;
    }

    bool pop(int& value) {
        int head = head_.load(std::memory_order_relaxed);

        if (head == tail_.load(std::memory_order_acquire)) {
            return false;  // 队列空
        }

        value = buffer_[head];
        head_.store((head + 1) % SIZE, std::memory_order_release);
        return true;
    }
};

void stress_test() {
    PortableQueue queue;
    std::atomic<long long> push_count{0}, pop_count{0};
    std::atomic<bool> stop{false};

    // 生产者
    std::thread producer([&] {
        for (int i = 0; i < 1000000; ++i) {
            while (!queue.push(i) && !stop) {
                std::this_thread::yield();
            }
            push_count.fetch_add(1, std::memory_order_relaxed);
        }
    });

    // 消费者
    std::thread consumer([&] {
        int value;
        while (pop_count.load(std::memory_order_relaxed) < 1000000) {
            if (queue.pop(value)) {
                pop_count.fetch_add(1, std::memory_order_relaxed);
            } else {
                std::this_thread::yield();
            }
        }
    });

    producer.join();
    consumer.join();

    std::cout << "Pushed: " << push_count << ", Popped: " << pop_count << std::endl;
    assert(push_count == pop_count);
}

int main() {
    for (int i = 0; i < 10; ++i) {
        stress_test();
    }
    std::cout << "All tests passed!\n";
    return 0;
}
```

**周末检验题**：

1. **汇编题**：写出以下C++代码在x86和ARM上可能生成的汇编
```cpp
std::atomic<int> x{0};
x.store(1, std::memory_order_release);
int y = x.load(std::memory_order_acquire);
```

2. **分析题**：为什么x86上acquire/release几乎免费，而ARM上需要额外指令？

3. **设计题**：如何验证一段代码在弱内存模型上是否正确？

**硬件映射完整对照表**：
```
操作                  | x86-64            | ARMv8              | POWER
---------------------|-------------------|--------------------|---------
relaxed load         | MOV               | LDR                | ld
relaxed store        | MOV               | STR                | st
acquire load         | MOV               | LDAR               | ld; cmp; bc; isync
release store        | MOV               | STLR               | lwsync; st
seq_cst load         | MOV               | LDAR               | sync; ld
seq_cst store        | XCHG or MOV+MFENCE| STLR               | sync; st
seq_cst fence        | MFENCE            | DMB ISH            | sync
acq fence            | (不需要)          | DMB ISHLD          | isync
rel fence            | (不需要)          | DMB ISH            | lwsync
```

**今日输出物**：
- [ ] 完整对照表：硬件映射速查表
- [ ] 周总结：`notes/week3/week3_summary.md`
- [ ] 代码：跨平台可移植测试程序

---

#### 内存屏障类型
```cpp
// 概念上的四种屏障：
// LoadLoad:   阻止Load重排到后面的Load之后
// LoadStore:  阻止Load重排到后面的Store之后
// StoreLoad:  阻止Store重排到后面的Load之后（最强）
// StoreStore: 阻止Store重排到后面的Store之后

// C++内存序映射：
// acquire = LoadLoad + LoadStore
// release = LoadStore + StoreStore
// seq_cst = 全部四种
```

#### x86/x64上的映射
```cpp
// x86是强内存模型（TSO: Total Store Order）
// 只有StoreLoad重排可能发生

// acquire: 不需要额外指令（硬件保证）
// release: 不需要额外指令（硬件保证）
// seq_cst load: 普通load
// seq_cst store: MFENCE; MOV 或 XCHG

// 因此在x86上，acquire/release几乎免费
// 只有seq_cst store有额外开销
```

#### ARM上的映射
```cpp
// ARM是弱内存模型，所有重排都可能发生

// acquire:
//   LDR r0, [address]
//   DMB ISH  ; 数据内存屏障

// release:
//   DMB ISH
//   STR r0, [address]

// seq_cst:
//   DMB ISH
//   LDR/STR
//   DMB ISH

// ARMv8有专门的acquire/release指令：
// LDAR (Load-Acquire)
// STLR (Store-Release)
```

### 第四周：实际应用与常见模式

**学习目标**：学会在实际代码中正确使用内存序

---

#### 📅 第四周每日详细计划

##### Day 22: 自旋锁变体实现（5小时）

**上午（2.5小时）- 基础自旋锁**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 基本实现 | 使用atomic_flag实现最简单的自旋锁 |
| 1:00-2:00 | TTAS优化 | 实现Test-and-Test-and-Set减少总线流量 |
| 2:00-2:30 | 内存序分析 | 分析为什么用acquire/release而非seq_cst |

**下午（2.5小时）- 高级变体**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 退避策略 | 实现指数退避自旋锁 |
| 1:00-2:00 | 票据锁 | 实现公平的票据自旋锁(Ticket Lock) |
| 2:00-2:30 | 性能对比 | 测试不同变体的性能 |

**自旋锁演进路线**：
```
基础TAS → TTAS → 退避TTAS → 票据锁 → MCS锁 → CLH锁
  ↓        ↓       ↓          ↓        ↓       ↓
简单    减少争用   降低功耗    公平性   可扩展   可扩展
```

**动手实验 4-1：自旋锁变体对比**
```cpp
// day22_spinlock_variants.cpp
#include <atomic>
#include <thread>
#include <chrono>
#include <iostream>
#include <vector>

// 1. 最基础的TAS锁
class TASLock {
    std::atomic_flag flag_ = ATOMIC_FLAG_INIT;

public:
    void lock() {
        while (flag_.test_and_set(std::memory_order_acquire)) {
            // 忙等
        }
    }

    void unlock() {
        flag_.clear(std::memory_order_release);
    }
};

// 2. TTAS锁（减少总线流量）
class TTASLock {
    std::atomic<bool> locked_{false};

public:
    void lock() {
        while (true) {
            // 先测试（只读，不会触发缓存一致性）
            while (locked_.load(std::memory_order_relaxed)) {
                // 可以加pause指令降低功耗
                #if defined(__x86_64__)
                __builtin_ia32_pause();
                #endif
            }
            // 再尝试获取
            if (!locked_.exchange(true, std::memory_order_acquire)) {
                return;
            }
        }
    }

    void unlock() {
        locked_.store(false, std::memory_order_release);
    }
};

// 3. 退避TTAS锁
class BackoffTTASLock {
    std::atomic<bool> locked_{false};
    static constexpr int MIN_DELAY = 1;
    static constexpr int MAX_DELAY = 1000;

public:
    void lock() {
        int delay = MIN_DELAY;
        while (true) {
            while (locked_.load(std::memory_order_relaxed)) {
                // 退避等待
                for (int i = 0; i < delay; ++i) {
                    #if defined(__x86_64__)
                    __builtin_ia32_pause();
                    #endif
                }
                delay = std::min(delay * 2, MAX_DELAY);
            }
            if (!locked_.exchange(true, std::memory_order_acquire)) {
                return;
            }
        }
    }

    void unlock() {
        locked_.store(false, std::memory_order_release);
    }
};

// 4. 票据锁（公平）
class TicketLock {
    std::atomic<unsigned> next_ticket_{0};
    std::atomic<unsigned> now_serving_{0};

public:
    void lock() {
        unsigned my_ticket = next_ticket_.fetch_add(1, std::memory_order_relaxed);
        while (now_serving_.load(std::memory_order_acquire) != my_ticket) {
            #if defined(__x86_64__)
            __builtin_ia32_pause();
            #endif
        }
    }

    void unlock() {
        // 使用release确保临界区的写操作可见
        now_serving_.fetch_add(1, std::memory_order_release);
    }
};

// 性能测试框架
template<typename Lock>
double benchmark(const char* name, int threads, int iterations) {
    Lock lock;
    volatile long long counter = 0;

    auto start = std::chrono::high_resolution_clock::now();

    std::vector<std::thread> workers;
    for (int t = 0; t < threads; ++t) {
        workers.emplace_back([&] {
            for (int i = 0; i < iterations; ++i) {
                lock.lock();
                ++counter;
                lock.unlock();
            }
        });
    }

    for (auto& w : workers) w.join();

    auto end = std::chrono::high_resolution_clock::now();
    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count();

    std::cout << name << ": " << ms << "ms, counter = " << counter << std::endl;
    return ms;
}

int main() {
    const int threads = 4;
    const int iterations = 100000;

    std::cout << "=== Spinlock Comparison (" << threads << " threads) ===\n";
    benchmark<TASLock>("TAS Lock", threads, iterations);
    benchmark<TTASLock>("TTAS Lock", threads, iterations);
    benchmark<BackoffTTASLock>("Backoff TTAS", threads, iterations);
    benchmark<TicketLock>("Ticket Lock", threads, iterations);

    return 0;
}
```

**内存序选择分析**：
```cpp
// 为什么自旋锁用 acquire/release 而不是 seq_cst？

// lock() 使用 acquire:
// - 保证临界区的读写不会重排到lock之前
// - 保证看到上一个unlock()之前的所有写入

// unlock() 使用 release:
// - 保证临界区的读写不会重排到unlock之后
// - 保证本次的写入对下一个lock()可见

// 不需要seq_cst:
// - 我们不关心多个锁操作之间的全局顺序
// - acquire/release足以建立正确的同步
// - seq_cst会引入不必要的StoreLoad屏障
```

**今日输出物**：
- [ ] 代码：`spinlock_variants.cpp`
- [ ] 笔记：`notes/week4/day22_spinlock.md`
- [ ] 性能报告：不同变体的对比数据

---

##### Day 23: 读写锁实现（5小时）

**上午（2.5小时）- 基本读写锁**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 需求分析 | 理解读多写少场景的需求 |
| 1:00-2:00 | 状态编码 | 设计读者计数和写者标志的编码方案 |
| 2:00-2:30 | 基本实现 | 实现简单的读写自旋锁 |

**下午（2.5小时）- 优化与变体**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 写者优先 | 实现写者优先的读写锁 |
| 1:00-2:00 | 读者优先 | 实现读者优先的读写锁 |
| 2:00-2:30 | 正确性验证 | 编写测试验证读写锁 |

**动手实验 4-2：读写锁实现**
```cpp
// day23_rwlock.cpp
#include <atomic>
#include <thread>
#include <chrono>
#include <iostream>
#include <vector>
#include <cassert>

// 基本读写锁
class RWSpinLock {
    // 状态编码：
    // 正数N: 有N个读者
    // 0: 空闲
    // -1: 有一个写者
    std::atomic<int> state_{0};

public:
    void lock_read() {
        while (true) {
            int state = state_.load(std::memory_order_relaxed);
            // 只有没有写者时才能获取读锁
            if (state >= 0) {
                if (state_.compare_exchange_weak(state, state + 1,
                        std::memory_order_acquire,
                        std::memory_order_relaxed)) {
                    return;
                }
            } else {
                // 有写者，等待
                std::this_thread::yield();
            }
        }
    }

    void unlock_read() {
        state_.fetch_sub(1, std::memory_order_release);
    }

    void lock_write() {
        while (true) {
            int expected = 0;
            // 只有空闲时才能获取写锁
            if (state_.compare_exchange_weak(expected, -1,
                    std::memory_order_acquire,
                    std::memory_order_relaxed)) {
                return;
            }
            std::this_thread::yield();
        }
    }

    void unlock_write() {
        state_.store(0, std::memory_order_release);
    }
};

// 写者优先读写锁（防止写者饥饿）
class WriterPreferRWLock {
    std::atomic<int> readers_{0};
    std::atomic<int> writers_waiting_{0};
    std::atomic<bool> writer_active_{false};

public:
    void lock_read() {
        while (true) {
            // 如果有写者等待或活跃，则等待
            while (writers_waiting_.load(std::memory_order_relaxed) > 0 ||
                   writer_active_.load(std::memory_order_relaxed)) {
                std::this_thread::yield();
            }

            readers_.fetch_add(1, std::memory_order_acquire);

            // 双重检查：如果写者在我们之后变为活跃
            if (!writer_active_.load(std::memory_order_acquire)) {
                return;  // 成功获取读锁
            }

            // 回退
            readers_.fetch_sub(1, std::memory_order_release);
        }
    }

    void unlock_read() {
        readers_.fetch_sub(1, std::memory_order_release);
    }

    void lock_write() {
        writers_waiting_.fetch_add(1, std::memory_order_relaxed);

        while (true) {
            bool expected = false;
            if (writer_active_.compare_exchange_weak(expected, true,
                    std::memory_order_acquire,
                    std::memory_order_relaxed)) {
                // 等待所有读者退出
                while (readers_.load(std::memory_order_acquire) > 0) {
                    std::this_thread::yield();
                }
                writers_waiting_.fetch_sub(1, std::memory_order_relaxed);
                return;
            }
            std::this_thread::yield();
        }
    }

    void unlock_write() {
        writer_active_.store(false, std::memory_order_release);
    }
};

// 测试代码
void test_rwlock() {
    RWSpinLock rwlock;
    std::atomic<int> shared_data{0};
    std::atomic<int> read_count{0};

    std::vector<std::thread> threads;

    // 读者线程
    for (int i = 0; i < 8; ++i) {
        threads.emplace_back([&] {
            for (int j = 0; j < 10000; ++j) {
                rwlock.lock_read();
                int value = shared_data.load(std::memory_order_relaxed);
                (void)value;  // 使用value防止优化
                read_count.fetch_add(1, std::memory_order_relaxed);
                rwlock.unlock_read();
            }
        });
    }

    // 写者线程
    for (int i = 0; i < 2; ++i) {
        threads.emplace_back([&] {
            for (int j = 0; j < 1000; ++j) {
                rwlock.lock_write();
                shared_data.fetch_add(1, std::memory_order_relaxed);
                rwlock.unlock_write();
            }
        });
    }

    for (auto& t : threads) t.join();

    std::cout << "Final value: " << shared_data << std::endl;
    std::cout << "Total reads: " << read_count << std::endl;
    assert(shared_data == 2000);
}

int main() {
    test_rwlock();
    std::cout << "All tests passed!\n";
    return 0;
}
```

**今日输出物**：
- [ ] 代码：`rwlock.cpp`
- [ ] 笔记：`notes/week4/day23_rwlock.md`

---

##### Day 24: 序列锁与双重检查锁定（5小时）

**上午（2.5小时）- 序列锁**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 序列锁原理 | 理解读多写少场景的乐观锁 |
| 1:00-2:00 | 实现细节 | 注意序列号的奇偶性语义 |
| 2:00-2:30 | 适用场景 | 分析何时使用序列锁 |

**下午（2.5小时）- DCLP**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | DCLP问题 | 理解传统DCLP为何失败 |
| 1:00-2:00 | 正确实现 | 使用acquire/release正确实现DCLP |
| 2:00-2:30 | 更好的方案 | 学习C++11静态局部变量的优势 |

**动手实验 4-3：序列锁实现**
```cpp
// day24_seqlock.cpp
#include <atomic>
#include <thread>
#include <iostream>
#include <chrono>

template<typename T>
class SeqLock {
    std::atomic<unsigned> seq_{0};  // 序列号
    T data_;

public:
    SeqLock(T init = T{}) : data_(init) {}

    // 写者独占调用
    void write(const T& value) {
        unsigned seq = seq_.load(std::memory_order_relaxed);

        // 开始写入：序列号变为奇数
        seq_.store(seq + 1, std::memory_order_relaxed);
        std::atomic_thread_fence(std::memory_order_release);

        data_ = value;

        // 完成写入：序列号变为偶数
        std::atomic_thread_fence(std::memory_order_release);
        seq_.store(seq + 2, std::memory_order_release);
    }

    // 读者可以并发调用
    T read() const {
        T result;
        unsigned seq1, seq2;

        do {
            // 读取序列号
            seq1 = seq_.load(std::memory_order_acquire);

            // 如果正在写入（奇数），等待
            while (seq1 & 1) {
                std::this_thread::yield();
                seq1 = seq_.load(std::memory_order_acquire);
            }

            // 读取数据
            std::atomic_thread_fence(std::memory_order_acquire);
            result = data_;
            std::atomic_thread_fence(std::memory_order_acquire);

            // 再次读取序列号
            seq2 = seq_.load(std::memory_order_acquire);

        } while (seq1 != seq2);  // 如果不同，说明读取期间有写入

        return result;
    }
};

// 测试
struct LargeData {
    long long a, b, c, d;
};

void test_seqlock() {
    SeqLock<LargeData> lock({1, 2, 3, 4});
    std::atomic<bool> stop{false};
    std::atomic<int> inconsistent{0};

    // 读者线程
    std::vector<std::thread> readers;
    for (int i = 0; i < 4; ++i) {
        readers.emplace_back([&] {
            while (!stop.load(std::memory_order_relaxed)) {
                LargeData data = lock.read();
                // 检查一致性：a + b + c + d 应该等于某个特定值
                if ((data.a + data.b) != (data.c + data.d)) {
                    inconsistent.fetch_add(1, std::memory_order_relaxed);
                }
            }
        });
    }

    // 写者线程
    std::thread writer([&] {
        for (long long i = 0; i < 100000; ++i) {
            lock.write({i, 100 - i, i + 50, 50 - i});
        }
        stop = true;
    });

    writer.join();
    for (auto& r : readers) r.join();

    std::cout << "Inconsistent reads: " << inconsistent << std::endl;
}

int main() {
    test_seqlock();
    return 0;
}
```

**动手实验 4-4：正确的DCLP**
```cpp
// day24_dclp.cpp
#include <atomic>
#include <mutex>
#include <iostream>

// 错误的DCLP（C++11之前常见）
class BadSingleton {
    static BadSingleton* instance_;
    static std::mutex mutex_;

public:
    // 这个实现是错误的！
    static BadSingleton* getInstance_WRONG() {
        if (instance_ == nullptr) {  // 第一次检查（无同步）
            std::lock_guard<std::mutex> lock(mutex_);
            if (instance_ == nullptr) {  // 第二次检查
                instance_ = new BadSingleton();
                // 问题：new的赋值可能在构造完成前对其他线程可见
            }
        }
        return instance_;
    }
};

// 正确的DCLP（使用atomic）
class GoodSingleton {
    static std::atomic<GoodSingleton*> instance_;
    static std::mutex mutex_;

public:
    static GoodSingleton* getInstance() {
        GoodSingleton* tmp = instance_.load(std::memory_order_acquire);
        if (tmp == nullptr) {
            std::lock_guard<std::mutex> lock(mutex_);
            tmp = instance_.load(std::memory_order_relaxed);
            if (tmp == nullptr) {
                tmp = new GoodSingleton();
                instance_.store(tmp, std::memory_order_release);
            }
        }
        return tmp;
    }
};

std::atomic<GoodSingleton*> GoodSingleton::instance_{nullptr};
std::mutex GoodSingleton::mutex_;

// 最佳方案：C++11静态局部变量
class BestSingleton {
public:
    static BestSingleton& getInstance() {
        static BestSingleton instance;  // C++11保证线程安全
        return instance;
    }

private:
    BestSingleton() {
        std::cout << "BestSingleton constructed\n";
    }
};

int main() {
    // 使用最佳方案
    auto& s1 = BestSingleton::getInstance();
    auto& s2 = BestSingleton::getInstance();
    std::cout << "Same instance: " << (&s1 == &s2) << std::endl;
    return 0;
}
```

**今日输出物**：
- [ ] 代码：`seqlock.cpp` + `dclp.cpp`
- [ ] 笔记：`notes/week4/day24_seqlock_dclp.md`

---

##### Day 25: 引用计数与智能指针（5小时）

**上午（2.5小时）- 引用计数原理**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 内存序选择 | 分析add_ref用relaxed、release用acq_rel的原因 |
| 1:00-2:00 | shared_ptr分析 | 阅读libstdc++或libc++的shared_ptr实现 |
| 2:00-2:30 | weak_ptr配合 | 理解weak_ptr如何避免循环引用 |

**下午（2.5小时）- 实现与验证**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 实现引用计数 | 实现线程安全的侵入式引用计数 |
| 1:30-2:30 | 压力测试 | 多线程测试引用计数正确性 |

**动手实验 4-5：引用计数实现详解**
```cpp
// day25_refcount.cpp
#include <atomic>
#include <thread>
#include <iostream>
#include <vector>
#include <cassert>

// 侵入式引用计数基类
class RefCounted {
    mutable std::atomic<int> ref_count_{1};

public:
    RefCounted() = default;
    virtual ~RefCounted() = default;

    // 禁止拷贝
    RefCounted(const RefCounted&) = delete;
    RefCounted& operator=(const RefCounted&) = delete;

    void add_ref() const {
        // relaxed足够：
        // 1. 增加引用计数不需要与其他操作同步
        // 2. 只要对象存在，add_ref总是安全的
        // 3. 原子性保证了计数的正确性
        int old = ref_count_.fetch_add(1, std::memory_order_relaxed);
        assert(old > 0);  // 确保不是在已销毁的对象上调用
    }

    void release() const {
        // acq_rel是必需的：
        // - release：确保本线程对对象的所有修改
        //           在引用计数减少前对其他线程可见
        // - acquire：当计数变为0时，确保看到其他线程
        //           对对象的所有修改
        int old = ref_count_.fetch_sub(1, std::memory_order_acq_rel);
        assert(old > 0);

        if (old == 1) {
            // 这是最后一个引用
            // acq_rel已经提供了必要的同步
            delete this;
        }
    }

    int use_count() const {
        return ref_count_.load(std::memory_order_relaxed);
    }
};

// 智能指针模板
template<typename T>
class IntrusivePtr {
    T* ptr_;

public:
    IntrusivePtr() : ptr_(nullptr) {}

    explicit IntrusivePtr(T* p) : ptr_(p) {}

    IntrusivePtr(const IntrusivePtr& other) : ptr_(other.ptr_) {
        if (ptr_) ptr_->add_ref();
    }

    IntrusivePtr(IntrusivePtr&& other) noexcept : ptr_(other.ptr_) {
        other.ptr_ = nullptr;
    }

    ~IntrusivePtr() {
        if (ptr_) ptr_->release();
    }

    IntrusivePtr& operator=(const IntrusivePtr& other) {
        if (this != &other) {
            if (ptr_) ptr_->release();
            ptr_ = other.ptr_;
            if (ptr_) ptr_->add_ref();
        }
        return *this;
    }

    IntrusivePtr& operator=(IntrusivePtr&& other) noexcept {
        if (this != &other) {
            if (ptr_) ptr_->release();
            ptr_ = other.ptr_;
            other.ptr_ = nullptr;
        }
        return *this;
    }

    T* get() const { return ptr_; }
    T* operator->() const { return ptr_; }
    T& operator*() const { return *ptr_; }
    explicit operator bool() const { return ptr_ != nullptr; }
};

// 测试类
class TestObject : public RefCounted {
public:
    int value;

    TestObject(int v) : value(v) {
        std::cout << "TestObject(" << v << ") created\n";
    }

    ~TestObject() override {
        std::cout << "TestObject(" << value << ") destroyed\n";
    }
};

// 多线程压力测试
void stress_test() {
    auto obj = new TestObject(42);
    IntrusivePtr<TestObject> shared(obj);

    std::atomic<int> active_refs{0};
    std::vector<std::thread> threads;

    for (int i = 0; i < 8; ++i) {
        threads.emplace_back([&shared, &active_refs] {
            for (int j = 0; j < 10000; ++j) {
                {
                    IntrusivePtr<TestObject> local = shared;
                    active_refs.fetch_add(1, std::memory_order_relaxed);

                    // 使用对象
                    int v = local->value;
                    (void)v;

                    active_refs.fetch_sub(1, std::memory_order_relaxed);
                }
            }
        });
    }

    for (auto& t : threads) t.join();

    std::cout << "Final use_count: " << shared.get()->use_count() << std::endl;
}

int main() {
    stress_test();
    std::cout << "Stress test passed!\n";
    return 0;
}
```

**内存序选择深度分析**：
```cpp
// 为什么add_ref用relaxed？

// 场景分析：
// Thread 1: 持有ptr，调用add_ref
// Thread 2: 也持有ptr，同时调用add_ref

// 两个add_ref之间不需要排序：
// - 它们都是增加计数
// - 无论哪个先执行，结果都一样
// - 只需要原子性，不需要顺序

// 为什么release用acq_rel？

// 场景分析：
// Thread 1: obj->data = 42; obj->release();
// Thread 2: obj->data = 100; obj->release();

// 假设Thread 2的release使计数变为0：
// - release语义：确保data=100在计数减少前可见
// - acquire语义：确保Thread 2在delete前能看到Thread 1的data=42

// 完整的happens-before链：
// T1: data=42 → release(count--)
//                    ↓ synchronizes-with
// T2: acquire(count--) → 看到data=42 → delete
```

**今日输出物**：
- [ ] 代码：`refcount.cpp`
- [ ] 笔记：`notes/week4/day25_refcount.md`

---

##### Day 26: 代码审查练习（5小时）

**上午（2.5小时）- Bug分析**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 常见错误 | 学习内存序使用的常见错误模式 |
| 1:00-2:00 | 案例分析 | 分析真实项目中的并发bug |
| 2:00-2:30 | 修复练习 | 尝试修复有问题的代码 |

**下午（2.5小时）- 代码审查**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 审查练习 | 对提供的代码进行内存模型审查 |
| 1:30-2:30 | 总结规则 | 总结代码审查检查清单 |

**代码审查练习**：
```cpp
// day26_code_review.cpp
// 以下代码有问题吗？如果有，怎么修复？

// 问题1：发布-订阅
std::atomic<int*> published{nullptr};
int data = 0;

void publisher() {
    int* p = new int(42);
    data = 100;
    published.store(p, std::memory_order_relaxed);  // 正确吗？
}

void subscriber() {
    int* p;
    while ((p = published.load(std::memory_order_relaxed)) == nullptr);  // 正确吗？
    int x = *p;
    int y = data;  // y一定是100吗？
}

// 问题2：标志位同步
std::atomic<bool> flag{false};
int shared_data = 0;

void writer() {
    shared_data = 42;
    flag.store(true, std::memory_order_release);
}

void reader() {
    if (flag.load(std::memory_order_relaxed)) {  // 正确吗？
        int x = shared_data;  // x一定是42吗？
    }
}

// 问题3：双缓冲切换
struct Buffer { int data[1024]; };
Buffer buffers[2];
std::atomic<int> current_index{0};

void producer() {
    int next = 1 - current_index.load(std::memory_order_relaxed);
    // 填充buffers[next]...
    buffers[next].data[0] = 42;
    current_index.store(next, std::memory_order_relaxed);  // 正确吗？
}

void consumer() {
    int idx = current_index.load(std::memory_order_relaxed);
    int x = buffers[idx].data[0];  // 能看到正确的数据吗？
}

// 问题4：计数器初始化检查
std::atomic<int> counter{0};
bool initialized = false;  // 非原子！

void init() {
    if (!initialized) {
        counter.store(100, std::memory_order_relaxed);
        initialized = true;  // 正确吗？
    }
}

void use() {
    if (initialized) {  // 正确吗？
        int c = counter.load(std::memory_order_relaxed);
    }
}
```

**参考答案**：
```cpp
// 问题1修复：
void publisher_fixed() {
    int* p = new int(42);
    data = 100;
    published.store(p, std::memory_order_release);  // 使用release
}

void subscriber_fixed() {
    int* p;
    while ((p = published.load(std::memory_order_acquire)) == nullptr);  // 使用acquire
    int x = *p;   // 正确
    int y = data; // 现在保证是100
}

// 问题2修复：
void reader_fixed() {
    if (flag.load(std::memory_order_acquire)) {  // 必须用acquire
        int x = shared_data;  // 现在保证是42
    }
}

// 问题3修复：
void producer_fixed() {
    int next = 1 - current_index.load(std::memory_order_relaxed);
    buffers[next].data[0] = 42;
    current_index.store(next, std::memory_order_release);  // 使用release
}

void consumer_fixed() {
    int idx = current_index.load(std::memory_order_acquire);  // 使用acquire
    int x = buffers[idx].data[0];  // 正确
}

// 问题4修复：使用原子变量
std::atomic<bool> initialized{false};

void init_fixed() {
    bool expected = false;
    if (initialized.compare_exchange_strong(expected, true,
            std::memory_order_release,
            std::memory_order_relaxed)) {
        counter.store(100, std::memory_order_relaxed);
    }
}

void use_fixed() {
    if (initialized.load(std::memory_order_acquire)) {
        int c = counter.load(std::memory_order_relaxed);
    }
}
```

**代码审查检查清单**：
```markdown
## 内存模型代码审查清单

### 1. 原子性检查
- [ ] 共享可变状态是否使用atomic？
- [ ] 是否存在非原子的读-修改-写操作？
- [ ] 复合操作是否正确使用CAS或锁？

### 2. 内存序检查
- [ ] 发布数据是否使用release？
- [ ] 获取数据是否使用acquire？
- [ ] 纯计数器是否可以使用relaxed？
- [ ] 是否过度使用seq_cst？

### 3. 同步关系检查
- [ ] 每个release是否有对应的acquire？
- [ ] 是否存在依赖非原子变量的同步？
- [ ] 是否存在TOCTOU竞争？

### 4. 常见模式检查
- [ ] DCLP是否正确实现？
- [ ] 引用计数的内存序是否正确？
- [ ] 自旋锁是否使用正确的内存序？
```

**今日输出物**：
- [ ] 练习答案：代码审查练习解答
- [ ] 笔记：`notes/week4/day26_code_review.md`
- [ ] 清单：内存模型审查检查清单

---

##### Day 27: 综合项目实战（5小时）

**上午（2.5小时）- 实现无锁队列**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | SPSC队列 | 实现单生产者单消费者无锁队列 |
| 1:30-2:30 | 内存序优化 | 分析并优化内存序使用 |

**下午（2.5小时）- 测试与验证**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 压力测试 | 编写全面的并发测试 |
| 1:30-2:30 | 性能分析 | 分析队列性能瓶颈 |

**动手实验 4-6：SPSC无锁队列**
```cpp
// day27_spsc_queue.cpp
#include <atomic>
#include <cstddef>
#include <optional>
#include <thread>
#include <iostream>
#include <chrono>

template<typename T, size_t Capacity>
class SPSCQueue {
    static_assert((Capacity & (Capacity - 1)) == 0, "Capacity must be power of 2");

    alignas(64) T buffer_[Capacity];
    alignas(64) std::atomic<size_t> head_{0};  // 消费者读写
    alignas(64) std::atomic<size_t> tail_{0};  // 生产者读写

    // 分离到不同缓存行，避免false sharing

public:
    bool push(const T& value) {
        size_t tail = tail_.load(std::memory_order_relaxed);
        size_t next_tail = (tail + 1) & (Capacity - 1);

        // 检查是否满
        if (next_tail == head_.load(std::memory_order_acquire)) {
            return false;
        }

        buffer_[tail] = value;

        // 发布新数据
        tail_.store(next_tail, std::memory_order_release);
        return true;
    }

    std::optional<T> pop() {
        size_t head = head_.load(std::memory_order_relaxed);

        // 检查是否空
        if (head == tail_.load(std::memory_order_acquire)) {
            return std::nullopt;
        }

        T value = buffer_[head];

        // 消费完成
        head_.store((head + 1) & (Capacity - 1), std::memory_order_release);
        return value;
    }

    bool empty() const {
        return head_.load(std::memory_order_relaxed) ==
               tail_.load(std::memory_order_relaxed);
    }

    size_t size() const {
        size_t tail = tail_.load(std::memory_order_relaxed);
        size_t head = head_.load(std::memory_order_relaxed);
        return (tail - head) & (Capacity - 1);
    }
};

// 性能测试
void benchmark() {
    SPSCQueue<int, 1024> queue;
    const int count = 10000000;

    auto start = std::chrono::high_resolution_clock::now();

    std::thread producer([&] {
        for (int i = 0; i < count; ++i) {
            while (!queue.push(i)) {
                // 队列满，重试
            }
        }
    });

    std::thread consumer([&] {
        int expected = 0;
        while (expected < count) {
            if (auto value = queue.pop()) {
                if (*value != expected) {
                    std::cerr << "Error: expected " << expected
                              << ", got " << *value << std::endl;
                }
                ++expected;
            }
        }
    });

    producer.join();
    consumer.join();

    auto end = std::chrono::high_resolution_clock::now();
    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count();

    std::cout << "Transferred " << count << " items in " << ms << "ms\n";
    std::cout << "Throughput: " << (count * 1000.0 / ms) << " items/sec\n";
    std::cout << "Latency: " << (ms * 1000000.0 / count) << " ns/item\n";
}

int main() {
    for (int i = 0; i < 5; ++i) {
        benchmark();
    }
    return 0;
}
```

**内存序优化分析**：
```cpp
// push()中的内存序分析：

// tail_.load(relaxed) - 只有生产者修改tail，relaxed足够
// head_.load(acquire) - 需要看到消费者对buffer_的修改？
//                       不需要！消费者只是读取buffer_
//                       但是需要acquire来确保看到最新的head
// tail_.store(release) - 必须！确保buffer_写入在tail更新前可见

// pop()中的内存序分析：

// head_.load(relaxed) - 只有消费者修改head
// tail_.load(acquire) - 需要看到生产者对buffer_的写入
// head_.store(release) - 告诉生产者这个槽位可以重用

// 优化版本：
// 如果我们只关心正确性而不是最新性，某些acquire可以放松
// 但这可能导致更多的自旋等待
```

**今日输出物**：
- [ ] 代码：`spsc_queue.cpp`
- [ ] 笔记：`notes/week4/day27_lockfree_queue.md`
- [ ] 性能报告：队列吞吐量和延迟数据

---

##### Day 28: 月度总结与知识图谱（5小时）

**上午（2.5小时）- 知识整合**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 复习全月内容 | 回顾四周的学习笔记 |
| 1:00-2:00 | 绘制知识图谱 | 制作C++内存模型完整知识图谱 |
| 2:00-2:30 | 查漏补缺 | 解决遗留问题 |

**下午（2.5小时）- 总结输出**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 速查表 | 制作内存序使用速查表 |
| 1:00-2:00 | 最佳实践 | 总结内存模型最佳实践 |
| 2:00-2:30 | 下月预习 | 预习Month 15内容 |

**月度知识图谱**：
```
                        C++ 内存模型
                             |
        +--------------------+--------------------+
        |                    |                    |
   为什么需要？           六种内存序            硬件映射
        |                    |                    |
   +----+----+         +-----+-----+         +----+----+
   |         |         |     |     |         |         |
编译器重排  CPU重排    relaxed acquire  x86-TSO  ARM弱序
                       release seq_cst
                          |
                    +-----+-----+
                    |           |
               synchronizes-with  happens-before
                          |
                    +-----+-----+-----+
                    |     |     |     |
                自旋锁 读写锁 引用计数 无锁队列
```

**内存序使用速查表**：
```
场景                          | 推荐内存序
------------------------------|---------------------------
纯计数器（只关心最终值）        | relaxed
统计收集                      | relaxed
引用计数增加                   | relaxed
引用计数减少                   | acq_rel
发布数据（写端）               | release
获取数据（读端）               | acquire
自旋锁lock                    | acquire
自旋锁unlock                  | release
需要全局顺序                   | seq_cst
默认（不确定时）               | seq_cst
```

**最佳实践总结**：
```markdown
## C++ 内存模型最佳实践

### 1. 默认策略
- 不确定时使用seq_cst
- 优化时先证明正确性，再降级内存序
- 使用工具（TSan、herd7）验证

### 2. 常见模式
- 发布-订阅：release + acquire
- 锁：acquire获取，release释放
- 引用计数：add用relaxed，sub用acq_rel
- 标志位同步：store release + load acquire

### 3. 避免的错误
- 不要对非原子变量进行跨线程访问
- 不要假设relaxed提供任何顺序保证
- 不要忘记acquire/release必须配对
- 不要混淆原子性和内存序

### 4. 性能考虑
- x86上acquire/release几乎免费
- ARM上需要额外指令
- 过度同步比竞争条件更好
- 先正确，后优化
```

**月度检验清单**：
- [ ] 能解释为什么需要内存模型
- [ ] 能区分六种内存序的语义
- [ ] 能分析代码在不同架构上的行为
- [ ] 能正确实现常见同步原语
- [ ] 能进行内存模型相关的代码审查
- [ ] 理解acquire/release与seq_cst的性能差异

**今日输出物**：
- [ ] 知识图谱：`notes/month14_mindmap.png`
- [ ] 速查表：`notes/month14_cheatsheet.md`
- [ ] 月度总结：`notes/month14_summary.md`
- [ ] 所有项目代码打包

---

#### 自旋锁实现
```cpp
class SpinLock {
    std::atomic<bool> locked_{false};

public:
    void lock() {
        while (locked_.exchange(true, std::memory_order_acquire)) {
            // 自旋等待
            // 可以加入退避策略
            while (locked_.load(std::memory_order_relaxed)) {
                // 减少缓存行争用
            }
        }
    }

    void unlock() {
        locked_.store(false, std::memory_order_release);
    }
};

// 为什么用acquire/release而不是seq_cst？
// - 性能更好
// - 语义足够：lock获取(acquire)，unlock释放(release)
```

#### 双重检查锁定（DCLP）
```cpp
class Singleton {
    static std::atomic<Singleton*> instance_;
    static std::mutex mutex_;

public:
    static Singleton* getInstance() {
        Singleton* tmp = instance_.load(std::memory_order_acquire);
        if (tmp == nullptr) {
            std::lock_guard<std::mutex> lock(mutex_);
            tmp = instance_.load(std::memory_order_relaxed);
            if (tmp == nullptr) {
                tmp = new Singleton();
                instance_.store(tmp, std::memory_order_release);
            }
        }
        return tmp;
    }
};

// 更简单的方式：C++11静态局部变量保证线程安全
Singleton& getInstance() {
    static Singleton instance;
    return instance;
}
```

#### 引用计数（shared_ptr风格）
```cpp
class RefCounted {
    mutable std::atomic<int> ref_count_{1};

public:
    void add_ref() const {
        // 增加引用计数：relaxed足够
        ref_count_.fetch_add(1, std::memory_order_relaxed);
    }

    void release() const {
        // 减少引用计数：需要更强的序
        if (ref_count_.fetch_sub(1, std::memory_order_acq_rel) == 1) {
            // 最后一个引用，删除对象
            // acq_rel确保：
            // - acquire: 看到其他线程对对象的所有修改
            // - release: 确保本线程的修改对清理代码可见
            delete this;
        }
    }
};
```

---

## 源码阅读任务

### 深度阅读清单

- [ ] `std::atomic`的实现（GCC/Clang）
- [ ] `__atomic_*` 内置函数
- [ ] `std::atomic_thread_fence`实现
- [ ] Linux内核的内存屏障宏

---

## 实践项目

### 项目：实现各种同步原语

#### Part 1: 自旋锁变体
```cpp
// spinlock.hpp
#pragma once
#include <atomic>
#include <thread>

// 基本自旋锁
class SpinLock {
    std::atomic_flag flag_ = ATOMIC_FLAG_INIT;

public:
    void lock() {
        while (flag_.test_and_set(std::memory_order_acquire)) {
            // 自旋
        }
    }

    void unlock() {
        flag_.clear(std::memory_order_release);
    }

    bool try_lock() {
        return !flag_.test_and_set(std::memory_order_acquire);
    }
};

// 带退避的自旋锁
class BackoffSpinLock {
    std::atomic<bool> locked_{false};

public:
    void lock() {
        int backoff = 1;
        while (true) {
            // 先尝试快速获取
            if (!locked_.exchange(true, std::memory_order_acquire)) {
                return;
            }

            // 自旋等待，使用relaxed减少总线流量
            while (locked_.load(std::memory_order_relaxed)) {
                for (int i = 0; i < backoff; ++i) {
                    // 暂停指令，降低功耗
                    #if defined(__x86_64__) || defined(_M_X64)
                    __builtin_ia32_pause();
                    #elif defined(__aarch64__)
                    asm volatile("yield");
                    #endif
                }
                // 指数退避
                backoff = std::min(backoff * 2, 1024);
            }
        }
    }

    void unlock() {
        locked_.store(false, std::memory_order_release);
    }
};

// 票据自旋锁（公平）
class TicketSpinLock {
    std::atomic<size_t> next_ticket_{0};
    std::atomic<size_t> now_serving_{0};

public:
    void lock() {
        size_t my_ticket = next_ticket_.fetch_add(1, std::memory_order_relaxed);
        while (now_serving_.load(std::memory_order_acquire) != my_ticket) {
            // 自旋
        }
    }

    void unlock() {
        now_serving_.fetch_add(1, std::memory_order_release);
    }
};
```

#### Part 2: 读写锁
```cpp
// rwlock.hpp
#pragma once
#include <atomic>
#include <thread>

class RWSpinLock {
    // 状态编码：
    // 正数: 读者数量
    // -1: 有写者
    // 0: 空闲
    std::atomic<int> state_{0};

public:
    void lock_read() {
        while (true) {
            int expected = state_.load(std::memory_order_relaxed);
            // 只有非负（没有写者）时才能获取读锁
            if (expected >= 0) {
                if (state_.compare_exchange_weak(expected, expected + 1,
                        std::memory_order_acquire,
                        std::memory_order_relaxed)) {
                    return;
                }
            } else {
                // 有写者，自旋等待
                std::this_thread::yield();
            }
        }
    }

    void unlock_read() {
        state_.fetch_sub(1, std::memory_order_release);
    }

    void lock_write() {
        while (true) {
            int expected = 0;
            // 只有空闲时才能获取写锁
            if (state_.compare_exchange_weak(expected, -1,
                    std::memory_order_acquire,
                    std::memory_order_relaxed)) {
                return;
            }
            std::this_thread::yield();
        }
    }

    void unlock_write() {
        state_.store(0, std::memory_order_release);
    }

    bool try_lock_read() {
        int expected = state_.load(std::memory_order_relaxed);
        if (expected >= 0) {
            return state_.compare_exchange_strong(expected, expected + 1,
                std::memory_order_acquire,
                std::memory_order_relaxed);
        }
        return false;
    }

    bool try_lock_write() {
        int expected = 0;
        return state_.compare_exchange_strong(expected, -1,
            std::memory_order_acquire,
            std::memory_order_relaxed);
    }
};
```

#### Part 3: 序列锁（适合读多写少）
```cpp
// seqlock.hpp
#pragma once
#include <atomic>

template <typename T>
class SeqLock {
    std::atomic<unsigned> seq_{0};
    T data_;

public:
    // 写者（独占）
    void write(const T& value) {
        unsigned seq = seq_.load(std::memory_order_relaxed);
        seq_.store(seq + 1, std::memory_order_relaxed);  // 奇数表示写入中
        std::atomic_thread_fence(std::memory_order_release);

        data_ = value;

        std::atomic_thread_fence(std::memory_order_release);
        seq_.store(seq + 2, std::memory_order_release);  // 偶数表示完成
    }

    // 读者（可以并发）
    T read() const {
        T result;
        unsigned seq1, seq2;
        do {
            seq1 = seq_.load(std::memory_order_acquire);
            while (seq1 & 1) {  // 奇数表示有写者
                seq1 = seq_.load(std::memory_order_acquire);
            }

            std::atomic_thread_fence(std::memory_order_acquire);
            result = data_;
            std::atomic_thread_fence(std::memory_order_acquire);

            seq2 = seq_.load(std::memory_order_acquire);
        } while (seq1 != seq2);  // 如果不相等，说明读取期间有写入

        return result;
    }
};
```

#### Part 4: 内存序测试
```cpp
// memory_order_test.cpp
#include <atomic>
#include <thread>
#include <cassert>
#include <iostream>

// 测试acquire-release语义
void test_acquire_release() {
    std::atomic<int> data{0};
    std::atomic<bool> ready{false};
    int observed = -1;

    std::thread writer([&] {
        data.store(42, std::memory_order_relaxed);
        ready.store(true, std::memory_order_release);
    });

    std::thread reader([&] {
        while (!ready.load(std::memory_order_acquire)) {
            // 自旋
        }
        observed = data.load(std::memory_order_relaxed);
    });

    writer.join();
    reader.join();

    assert(observed == 42);
    std::cout << "Acquire-Release test passed!\n";
}

// 测试seq_cst（经典的存储缓冲区测试）
void test_seq_cst() {
    std::atomic<int> x{0}, y{0};
    int r1 = 0, r2 = 0;

    auto thread1 = [&] {
        x.store(1, std::memory_order_seq_cst);
        r1 = y.load(std::memory_order_seq_cst);
    };

    auto thread2 = [&] {
        y.store(1, std::memory_order_seq_cst);
        r2 = x.load(std::memory_order_seq_cst);
    };

    // 运行多次，检查是否出现r1==0 && r2==0
    int both_zero = 0;
    for (int i = 0; i < 100000; ++i) {
        x = 0; y = 0; r1 = 0; r2 = 0;

        std::thread t1(thread1);
        std::thread t2(thread2);
        t1.join();
        t2.join();

        if (r1 == 0 && r2 == 0) {
            ++both_zero;
        }
    }

    // seq_cst保证不会出现both_zero
    std::cout << "Seq_cst test: both_zero = " << both_zero
              << " (should be 0)\n";
}

// 测试relaxed的无序性
void test_relaxed() {
    std::atomic<int> x{0}, y{0};
    int r1 = 0, r2 = 0;

    auto thread1 = [&] {
        x.store(1, std::memory_order_relaxed);
        r1 = y.load(std::memory_order_relaxed);
    };

    auto thread2 = [&] {
        y.store(1, std::memory_order_relaxed);
        r2 = x.load(std::memory_order_relaxed);
    };

    int both_zero = 0;
    for (int i = 0; i < 100000; ++i) {
        x = 0; y = 0; r1 = 0; r2 = 0;

        std::thread t1(thread1);
        std::thread t2(thread2);
        t1.join();
        t2.join();

        if (r1 == 0 && r2 == 0) {
            ++both_zero;
        }
    }

    // relaxed可能出现both_zero（在弱内存模型架构上）
    std::cout << "Relaxed test: both_zero = " << both_zero
              << " (may be non-zero on weak memory models)\n";
}

int main() {
    test_acquire_release();
    test_seq_cst();
    test_relaxed();
    return 0;
}
```

---

## 检验标准

### 知识检验
- [ ] 为什么编译器和CPU会重排指令？
- [ ] x86和ARM内存模型有什么区别？
- [ ] acquire和release语义各自阻止什么重排？
- [ ] 什么时候可以安全使用relaxed？
- [ ] seq_cst的开销在哪里？

### 实践检验
- [ ] 实现的自旋锁在多线程环境下正确工作
- [ ] 读写锁能正确处理并发读和独占写
- [ ] 序列锁在写入期间读者能正确重试
- [ ] 内存序测试展示不同内存序的行为差异

### 输出物
1. `spinlock.hpp`（含多种变体）
2. `rwlock.hpp`
3. `seqlock.hpp`
4. `memory_order_test.cpp`
5. `notes/month14_memory_model.md`

---

## 时间分配（140小时/月）

| 内容 | 时间 | 占比 |
|------|------|------|
| 理论学习 | 45小时 | 32% |
| 源码阅读 | 25小时 | 18% |
| 同步原语实现 | 40小时 | 29% |
| 测试与验证 | 20小时 | 14% |
| 笔记与文档 | 10小时 | 7% |

---

## 下月预告

Month 15将学习**原子操作与CAS**，深入理解compare_exchange的实现，以及它在无锁算法中的核心作用。
