# Month 24: 第二年总结与综合项目——并发编程大师之路

## 本月主题概述

本月是Year 2并发编程学习的**收官月**。经过Month 13-23共11个月的深度学习，你已经掌握了从基础同步原语到高级协程异步I/O的完整知识体系。本月的核心任务是：

1. **系统复盘**：回顾Month 13-23的所有核心知识点
2. **综合项目**：构建一个高性能并发服务器框架，整合所有所学
3. **Year 2总结**：建立完整的知识图谱和最佳实践文档
4. **Year 3衔接**：为高性能网络编程学习做准备

### Year 2 知识体系全景图

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                     Year 2: 内存模型与并发编程（Month 13-24）                    │
├────────────────────────────────────────────────────────────────────────────────┤
│                                                                                │
│  ┌── 基础层 (Month 13-15) ──────────────────────────────────────────┐         │
│  │                                                                   │         │
│  │  Month 13        Month 14          Month 15                      │         │
│  │  线程与同步      C++内存模型       原子操作与CAS                  │         │
│  │  ┌─────────┐    ┌─────────────┐   ┌───────────────┐              │         │
│  │  │ thread  │    │ memory_order│   │ atomic        │              │         │
│  │  │ mutex   │    │ seq_cst     │   │ CAS           │              │         │
│  │  │ cv      │    │ acquire     │   │ fetch_add     │              │         │
│  │  │ atomic  │    │ release     │   │ compare_swap  │              │         │
│  │  │ RAII    │    │ relaxed     │   │ lock-free     │              │         │
│  │  └─────────┘    │ happens-    │   └───────────────┘              │         │
│  │                  │ before      │                                   │         │
│  │                  └─────────────┘                                   │         │
│  └───────────────────────────────────────────────────────────────────┘         │
│                                   ↓                                            │
│  ┌── 无锁编程层 (Month 16-18) ──────────────────────────────────────┐         │
│  │                                                                   │         │
│  │  Month 16          Month 17          Month 18                    │         │
│  │  ABA与内存回收     无锁队列          Future/Promise              │         │
│  │  ┌────────────┐   ┌────────────┐   ┌────────────┐               │         │
│  │  │ ABA问题    │   │ SPSC队列   │   │ std::future│               │         │
│  │  │ Hazard Ptr │   │ MPSC队列   │   │ std::promise│              │         │
│  │  │ Epoch-based│   │ MPMC队列   │   │ std::async │               │         │
│  │  │ RCU        │   │ M-S Queue  │   │ 组合模式   │               │         │
│  │  └────────────┘   └────────────┘   └────────────┘               │         │
│  └───────────────────────────────────────────────────────────────────┘         │
│                                   ↓                                            │
│  ┌── 高级并发层 (Month 19-22) ──────────────────────────────────────┐         │
│  │                                                                   │         │
│  │  Month 19          Month 20          Month 21        Month 22   │         │
│  │  线程池设计        Actor模型         C++20协程       异步I/O     │         │
│  │  ┌────────────┐   ┌────────────┐   ┌──────────┐   ┌──────────┐ │         │
│  │  │ Work Steal │   │ 消息传递   │   │ co_await │   │ EventLoop│ │         │
│  │  │ Fork/Join  │   │ Mailbox    │   │ Task     │   │ epoll    │ │         │
│  │  │ DAG调度    │   │ 监督树     │   │ Generator│   │ AsyncSock│ │         │
│  │  │ Chase-Lev  │   │ Ask/Tell   │   │ Channel  │   │ Reactor  │ │         │
│  │  └────────────┘   └────────────┘   └──────────┘   └──────────┘ │         │
│  └───────────────────────────────────────────────────────────────────┘         │
│                                   ↓                                            │
│  ┌── 总结应用层 (Month 23-24) ──────────────────────────────────────┐         │
│  │                                                                   │         │
│  │  Month 23                          Month 24 【本月】             │         │
│  │  模式总结与决策指南                综合项目与Year 2总结           │         │
│  │  ┌────────────────────┐           ┌────────────────────┐        │         │
│  │  │ PC模式深度         │           │ 知识复盘           │        │         │
│  │  │ 读写锁优化         │    →      │ 并发服务器框架     │        │         │
│  │  │ 决策框架           │           │ 性能基准测试       │        │         │
│  │  │ 调试技术           │           │ Year 2完整总结     │        │         │
│  │  └────────────────────┘           └────────────────────┘        │         │
│  └───────────────────────────────────────────────────────────────────┘         │
│                                                                                │
└────────────────────────────────────────────────────────────────────────────────┘
```

### 学习目标

1. **知识整合**：能够自如地在各种并发方案间切换和组合
2. **工程能力**：独立完成一个高性能并发服务器框架
3. **调试能力**：能使用工具诊断和解决并发问题
4. **架构思维**：能根据场景做出合理的并发架构决策

### 学习目标量化

| 周次 | 目标编号 | 具体目标 |
|------|----------|----------|
| W1 | W1-G1 | 完成Month 13-23核心知识复盘自测 |
| W1 | W1-G2 | 完成综合项目架构设计文档 |
| W1 | W1-G3 | 搭建项目骨架和构建系统 |
| W2 | W2-G1 | 实现工作窃取线程池 |
| W2 | W2-G2 | 实现无锁任务队列 |
| W2 | W2-G3 | 实现协程调度器 |
| W3 | W3-G1 | 实现异步I/O层 |
| W3 | W3-G2 | 实现TCP服务器框架 |
| W3 | W3-G3 | 实现Echo/HTTP Server |
| W4 | W4-G1 | 完成性能基准测试 |
| W4 | W4-G2 | 完成性能优化 |
| W4 | W4-G3 | 完成Year 2知识总结文档 |

### 综合项目概述

```
综合项目：高性能并发服务器框架 (ConcurrentServer)

┌─────────────────────────────────────────────────────────────────┐
│                      应用层                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ Echo Server  │  │ HTTP Server  │  │ 自定义协议   │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                 │                  │                   │
├─────────┼─────────────────┼──────────────────┼──────────────────┤
│         └─────────────────┼──────────────────┘                   │
│                     ┌─────▼─────┐                                │
│                     │ Server    │ ← 服务器框架层                 │
│                     │ Framework │                                │
│                     └─────┬─────┘                                │
│              ┌────────────┼────────────┐                         │
│              │            │            │                          │
│  ┌───────────▼──┐  ┌─────▼────┐  ┌───▼───────────┐             │
│  │ Async I/O    │  │ Protocol │  │ Connection    │             │
│  │ EventLoop    │  │ Parser   │  │ Manager       │             │
│  └───────────┬──┘  └──────────┘  └───────────────┘             │
│              │                                                   │
├──────────────┼──────────────────────────────────────────────────┤
│              │          核心并发层                                │
│  ┌───────────▼──┐  ┌──────────────┐  ┌──────────────┐          │
│  │ Coroutine    │  │ Thread Pool  │  │ Lock-free    │          │
│  │ Scheduler    │  │ Work Steal   │  │ Queue        │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│                                                                  │
│  技术来源：                                                      │
│  • 线程池 → Month 19 (Work Stealing)                            │
│  • 无锁队列 → Month 17 (MPMC Queue)                            │
│  • 协程 → Month 21-22 (Task/Channel/EventLoop)                 │
│  • 内存回收 → Month 16 (Epoch-based)                           │
│  • 决策框架 → Month 23                                          │
└─────────────────────────────────────────────────────────────────┘
```

### 时间分配（140小时）

| 周次 | 内容 | 时间 | 占比 |
|------|------|------|------|
| W1 | 知识复盘与架构设计 | 30h | 21% |
| W2 | 核心组件实现 | 40h | 29% |
| W3 | 异步I/O与服务器 | 35h | 25% |
| W4 | 测试优化与总结 | 35h | 25% |

---

## 第一周：Year 2知识复盘与架构设计（Day 1-7）

> **本周目标**：系统回顾Month 13-23的核心知识，完成综合项目架构设计

### Day 1-2：Month 13-17 知识复盘（基础层+无锁编程层）

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | Month 13-14 复盘 | 2h |
| 下午 | Month 15-16 复盘 | 3h |
| 晚上 | Month 17 复盘 | 2h |

#### 1. Month 13：线程与同步原语回顾

```cpp
// ============================================================
// Month 13 核心知识复盘：线程与同步原语
// ============================================================

/*
Month 13 学习的核心内容：

┌─────────────────────────────────────────────────────────────┐
│  1. std::thread                                              │
│     • 创建、join、detach                                     │
│     • 线程标识、硬件并发度                                   │
│                                                              │
│  2. std::mutex 系列                                          │
│     • mutex, recursive_mutex, timed_mutex                    │
│     • RAII: lock_guard, unique_lock, scoped_lock             │
│                                                              │
│  3. std::condition_variable                                  │
│     • wait/notify模式                                        │
│     • 虚假唤醒防护                                           │
│                                                              │
│  4. std::atomic                                              │
│     • 基本原子操作                                           │
│     • 标志位、计数器                                         │
└─────────────────────────────────────────────────────────────┘
*/

// 自测代码1：线程安全的单例模式
class Singleton {
    static std::once_flag flag_;
    static Singleton* instance_;

    Singleton() = default;

public:
    static Singleton& instance() {
        std::call_once(flag_, []() {
            instance_ = new Singleton();
        });
        return *instance_;
    }

    // 或使用Meyer's Singleton
    static Singleton& instance_meyers() {
        static Singleton s;
        return s;
    }
};

// 自测代码2：生产者-消费者基本模式
template<typename T>
class SimpleBlockingQueue {
    std::queue<T> queue_;
    std::mutex mutex_;
    std::condition_variable cv_;

public:
    void push(T value) {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            queue_.push(std::move(value));
        }
        cv_.notify_one();
    }

    T pop() {
        std::unique_lock<std::mutex> lock(mutex_);
        cv_.wait(lock, [this] { return !queue_.empty(); });
        T value = std::move(queue_.front());
        queue_.pop();
        return value;
    }
};

/*
自测题：
Q1: lock_guard和unique_lock的区别是什么？
A: lock_guard只能在构造时加锁，析构时解锁，不可移动。
   unique_lock支持延迟加锁、条件变量wait、手动unlock、可移动。

Q2: 为什么条件变量wait必须用while循环？
A: 虚假唤醒（spurious wakeup）——线程可能在条件未满足时被唤醒。
   使用lambda谓词的wait版本内部已处理。

Q3: std::scoped_lock(C++17)的优势？
A: 可以同时锁定多个互斥量，自动避免死锁（类似std::lock）。
*/
```

#### 2. Month 14：C++内存模型回顾

```cpp
// ============================================================
// Month 14 核心知识复盘：C++内存模型
// ============================================================

/*
六种内存序及其关系：

┌─────────────────────────────────────────────────────────────┐
│  最强                                                        │
│  ↑  memory_order_seq_cst  （顺序一致性，默认）               │
│  │   • 全局唯一的操作顺序                                    │
│  │   • 最安全但最慢                                          │
│  │                                                           │
│  │  memory_order_acq_rel  （获取-释放语义）                   │
│  │   • 读是acquire，写是release                              │
│  │   • 用于read-modify-write操作                             │
│  │                                                           │
│  │  memory_order_acquire  （获取语义）                        │
│  │   • 后续读写不会被重排到此操作之前                        │
│  │   • 用于load操作                                          │
│  │                                                           │
│  │  memory_order_release  （释放语义）                        │
│  │   • 之前的读写不会被重排到此操作之后                      │
│  │   • 用于store操作                                         │
│  │                                                           │
│  │  memory_order_consume  （消费语义，实践中少用）            │
│  │                                                           │
│  ↓  memory_order_relaxed  （松散序，只保证原子性）            │
│  最弱                                                        │
└─────────────────────────────────────────────────────────────┘

Happens-Before关系：
A happens-before B 意味着A的效果对B可见。

建立happens-before的方式：
1. 同一线程的顺序执行
2. mutex lock/unlock
3. acquire-release配对
4. seq_cst全序
*/

// 自测代码：acquire-release模式
class AcquireReleaseExample {
    std::atomic<bool> ready{false};
    int data = 0;

public:
    void producer() {
        data = 42;                                          // ①
        ready.store(true, std::memory_order_release);       // ②
        // release保证：①在②之前对其他线程可见
    }

    void consumer() {
        while (!ready.load(std::memory_order_acquire)) {}   // ③
        // acquire保证：③之后的操作能看到②之前的所有写入
        assert(data == 42);                                 // ④ 一定成功
    }
};

/*
自测题：
Q1: 如果producer用relaxed而不是release，consumer能保证看到data=42吗？
A: 不能。relaxed只保证原子性，不建立happens-before关系。

Q2: seq_cst和acq_rel的主要区别？
A: seq_cst保证所有线程看到相同的全局操作顺序；
   acq_rel只在配对的load/store之间建立happens-before。

Q3: 什么时候可以安全使用relaxed？
A: 只需要原子性，不需要排序保证时。如计数器、标志位（不依赖其他数据）。
*/
```

#### 3. Month 15：原子操作与CAS回顾

```cpp
// ============================================================
// Month 15 核心知识复盘：原子操作与CAS
// ============================================================

/*
CAS（Compare-And-Swap）是无锁编程的基石：

expected = 当前值
desired = 新值

CAS(addr, expected, desired):
  if (*addr == expected):
    *addr = desired
    return true
  else:
    expected = *addr  // 更新expected
    return false

C++中的CAS：
• compare_exchange_weak: 可能虚假失败，用在循环中
• compare_exchange_strong: 不会虚假失败
*/

// 自测代码：无锁栈
template<typename T>
class LockFreeStack {
    struct Node {
        T data;
        Node* next;
        Node(T d) : data(std::move(d)), next(nullptr) {}
    };

    std::atomic<Node*> head_{nullptr};

public:
    void push(T value) {
        Node* new_node = new Node(std::move(value));
        new_node->next = head_.load(std::memory_order_relaxed);
        while (!head_.compare_exchange_weak(
            new_node->next, new_node,
            std::memory_order_release,
            std::memory_order_relaxed)) {
            // CAS失败，new_node->next已自动更新
        }
    }

    std::optional<T> pop() {
        Node* old_head = head_.load(std::memory_order_acquire);
        while (old_head &&
               !head_.compare_exchange_weak(
                   old_head, old_head->next,
                   std::memory_order_acq_rel,
                   std::memory_order_acquire)) {
            // 重试
        }
        if (!old_head) return std::nullopt;

        T value = std::move(old_head->data);
        // 注意：这里有内存泄漏！需要Month 16的回收技术
        delete old_head;
        return value;
    }
};

/*
自测题：
Q1: compare_exchange_weak和strong的区别？
A: weak可能虚假失败（在某些架构上），但更快。
   循环中用weak，单次判断用strong。

Q2: 上面的pop有什么问题？
A: 1. ABA问题（Month 16）
   2. 不安全的delete（其他线程可能还在读old_head->next）

Q3: fetch_add和CAS循环实现的加法有何区别？
A: fetch_add是专用原子加法指令，通常更快。
   CAS循环更通用，可以实现任意原子操作。
*/
```

#### 4. Month 16：ABA问题与内存回收回顾

```cpp
// ============================================================
// Month 16 核心知识复盘：ABA问题与内存回收
// ============================================================

/*
ABA问题：

时间线：
T1: load ptr=A ────────────────────→ CAS(A→C) 成功！但A已不是原来的A
T2:              free(A) → alloc(A)

内存回收方案对比：
┌──────────────────┬──────────────┬──────────────┬──────────────┐
│  方案            │  读开销      │  写开销      │  回收时机    │
├──────────────────┼──────────────┼──────────────┼──────────────┤
│  Hazard Pointers │  中          │  低          │  精确        │
│  Epoch-based     │  极低        │  低          │  批量        │
│  RCU             │  零（读）    │  高（写）    │  Grace Period│
│  引用计数        │  高          │  高          │  即时        │
└──────────────────┴──────────────┴──────────────┴──────────────┘

在综合项目中的应用：
• 无锁队列 → Epoch-based回收
• 配置热更新 → RCU
*/

// 简化的Epoch-Based回收
class EpochReclamation {
    static constexpr int NUM_EPOCHS = 3;

    std::atomic<uint64_t> global_epoch_{0};
    struct ThreadState {
        std::atomic<uint64_t> local_epoch{0};
        std::atomic<bool> active{false};
    };

    // 每线程状态
    std::vector<ThreadState> thread_states_;
    // 待回收列表（按epoch分组）
    std::array<std::vector<void*>, NUM_EPOCHS> retire_lists_;

public:
    void enter_critical() {
        int tid = get_thread_id();
        thread_states_[tid].active.store(true, std::memory_order_relaxed);
        thread_states_[tid].local_epoch.store(
            global_epoch_.load(std::memory_order_relaxed),
            std::memory_order_release);
    }

    void exit_critical() {
        int tid = get_thread_id();
        thread_states_[tid].active.store(false, std::memory_order_release);
    }

    void retire(void* ptr) {
        uint64_t epoch = global_epoch_.load(std::memory_order_relaxed);
        retire_lists_[epoch % NUM_EPOCHS].push_back(ptr);
        try_advance_epoch();
    }

private:
    void try_advance_epoch() {
        uint64_t current = global_epoch_.load();
        // 检查所有活跃线程是否都在当前epoch
        for (auto& ts : thread_states_) {
            if (ts.active.load() && ts.local_epoch.load() != current) {
                return;  // 还有线程在旧epoch
            }
        }
        // 推进epoch并回收两个epoch前的数据
        if (global_epoch_.compare_exchange_strong(current, current + 1)) {
            auto& list = retire_lists_[(current + 1) % NUM_EPOCHS];
            for (void* ptr : list) {
                free(ptr);
            }
            list.clear();
        }
    }

    int get_thread_id() { return 0; /* 简化 */ }
};

/*
自测题：
Q1: 为什么需要3个epoch而不是2个？
A: 需要确保回收的对象至少经过了一个完整的epoch，
   所有线程都已退出旧epoch的临界区。3个epoch是最小安全数。

Q2: Hazard Pointers和Epoch-based的主要区别？
A: HP精确跟踪每个被保护的指针，回收更及时但开销更大。
   Epoch-based批量回收，开销更低但可能延迟回收。

Q3: RCU适合什么场景？
A: 读极端多写极端少的场景（如配置、路由表），
   因为读操作零开销，但写需要复制+等待grace period。
*/
```

#### 5. Month 17：无锁队列回顾

```cpp
// ============================================================
// Month 17 核心知识复盘：无锁队列
// ============================================================

/*
无锁队列类型对比：

┌──────────────────┬──────────────┬──────────────┬──────────────┐
│  类型            │  实现复杂度  │  性能        │  适用场景    │
├──────────────────┼──────────────┼──────────────┼──────────────┤
│  SPSC            │  低          │  极高        │  单生单消    │
│  MPSC            │  中          │  高          │  多生单消    │
│  MPMC            │  高          │  中高        │  通用        │
│  M-S Queue       │  高          │  中          │  无界队列    │
└──────────────────┴──────────────┴──────────────┴──────────────┘

综合项目选型：
• 线程池任务队列 → MPMC有界队列
• 协程Channel → SPSC/MPSC队列
• EventLoop任务提交 → MPSC队列
*/

// SPSC无锁队列（最简单最快）
template<typename T, size_t Capacity>
class SPSCQueue {
    static_assert((Capacity & (Capacity - 1)) == 0, "Capacity must be power of 2");

    std::array<T, Capacity> buffer_;
    alignas(64) std::atomic<size_t> head_{0};  // 消费者读
    alignas(64) std::atomic<size_t> tail_{0};  // 生产者写

public:
    bool push(const T& item) {
        size_t tail = tail_.load(std::memory_order_relaxed);
        size_t next = (tail + 1) & (Capacity - 1);

        if (next == head_.load(std::memory_order_acquire)) {
            return false;  // 满
        }

        buffer_[tail] = item;
        tail_.store(next, std::memory_order_release);
        return true;
    }

    bool pop(T& item) {
        size_t head = head_.load(std::memory_order_relaxed);

        if (head == tail_.load(std::memory_order_acquire)) {
            return false;  // 空
        }

        item = buffer_[head];
        head_.store((head + 1) & (Capacity - 1), std::memory_order_release);
        return true;
    }
};

/*
自测题：
Q1: 为什么head和tail要对齐到64字节？
A: 避免伪共享。head和tail分别被消费者和生产者频繁修改，
   如果在同一缓存行会导致缓存行弹跳。

Q2: SPSC为什么不需要CAS？
A: 因为只有一个线程读head，一个线程写tail，
   不存在竞争，只需要正确的内存序。

Q3: Michael-Scott队列的核心思想？
A: 使用CAS操作原子地修改链表头尾指针，
   配合哨兵节点简化空队列处理。
*/
```

### Day 3-4：Month 18-23 知识复盘（高级并发层+总结层）

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | Month 18-19 复盘 | 2h |
| 下午 | Month 20-21 复盘 | 3h |
| 晚上 | Month 22-23 复盘 | 2h |

#### 1. Month 18：Future/Promise 回顾

```cpp
// ============================================================
// Month 18 核心知识复盘：Future/Promise
// ============================================================

/*
Future/Promise模型：

Promise ──写入值──→ [共享状态] ──读取值──→ Future

关键API：
• std::promise<T>::set_value()
• std::future<T>::get()     // 阻塞等待
• std::async()              // 创建异步任务
• std::shared_future<T>     // 多读者
*/

// 自测代码：手动Promise/Future
#include <future>

// 异步组合模式
class AsyncComposition {
public:
    // 串行组合：then
    template<typename T, typename F>
    static auto then(std::future<T> future, F&& func) {
        return std::async(std::launch::async,
            [f = std::move(future), func = std::forward<F>(func)]() mutable {
                return func(f.get());
            });
    }

    // 并行组合：when_all（简化版）
    template<typename... Futures>
    static auto when_all(Futures&&... futures) {
        return std::async(std::launch::async,
            [](auto... fs) mutable {
                return std::make_tuple(fs.get()...);
            },
            std::forward<Futures>(futures)...);
    }
};

/*
自测题：
Q1: std::future::get()可以调用几次？
A: 只能调用一次，之后future变为无效状态。
   使用shared_future可以多次get。

Q2: std::async的launch策略有哪些？
A: async（新线程）、deferred（惰性求值）、async|deferred（由实现决定）。

Q3: Future的局限性？
A: 缺乏原生的then链式组合、no select/when_any、get阻塞。
   C++20协程很大程度上解决了这些问题。
*/
```

#### 2. Month 19：线程池设计回顾

```cpp
// ============================================================
// Month 19 核心知识复盘：线程池设计
// ============================================================

/*
线程池核心组件：

┌─────────────────────────────────────────────────────────────┐
│  线程池架构                                                  │
│                                                              │
│  submit(task) ──→ [全局任务队列]                             │
│                        │                                     │
│              ┌─────────┼─────────┐                           │
│              ↓         ↓         ↓                           │
│          Worker0    Worker1    Worker2                        │
│          [本地队列] [本地队列] [本地队列]                     │
│              │         │         │                           │
│              └─────────┼─────────┘                           │
│                   工作窃取                                    │
└─────────────────────────────────────────────────────────────┘

Chase-Lev Deque:
• 所有者从bottom端push/pop（LIFO，缓存友好）
• 窃取者从top端steal（FIFO）
*/

// 简化的线程池接口（综合项目将完整实现）
class ThreadPool {
public:
    explicit ThreadPool(size_t num_threads);
    ~ThreadPool();

    // 提交任务并返回future
    template<typename F, typename... Args>
    auto submit(F&& f, Args&&... args)
        -> std::future<std::invoke_result_t<F, Args...>>;

    // 关闭
    void shutdown();

    // 等待所有任务完成
    void wait_idle();

    size_t thread_count() const;
    size_t pending_tasks() const;
};

/*
自测题：
Q1: 工作窃取的优势是什么？
A: 自动负载均衡——空闲线程从忙碌线程窃取任务，
   避免任务分配不均导致的性能浪费。

Q2: Chase-Lev Deque为什么owner从bottom操作？
A: LIFO顺序更缓存友好（最近push的数据还在缓存中），
   且只有owner操作bottom端，减少竞争。

Q3: Fork/Join和线程池的关系？
A: Fork/Join在线程池基础上支持任务的递归分解，
   子任务提交到本地队列，利用工作窃取实现并行。
*/
```

#### 3. Month 20：Actor模型回顾

```cpp
// ============================================================
// Month 20 核心知识复盘：Actor模型
// ============================================================

/*
Actor模型核心概念：

Actor = 状态 + 行为 + 消息信箱

┌──────────┐   消息   ┌──────────┐
│ Actor A  │ ───────→ │ Actor B  │
│ ┌──────┐ │          │ ┌──────┐ │
│ │状态  │ │          │ │状态  │ │
│ │行为  │ │          │ │行为  │ │
│ │信箱  │ │          │ │信箱  │ │
│ └──────┘ │          │ └──────┘ │
└──────────┘          └──────────┘

三大原语：
1. send: 发送消息
2. become: 改变行为
3. create: 创建新Actor

特点：
• 无共享状态——通过消息通信
• 单线程处理消息——无需锁
• 容错——"Let it crash" + 监督树
*/

/*
自测题：
Q1: Actor模型如何避免数据竞争？
A: Actor之间不共享状态，只通过消息通信。
   每个Actor单线程处理消息，不需要锁。

Q2: Ask模式和Tell模式的区别？
A: Tell是单向发消息（fire-and-forget）。
   Ask是发消息并等待回复（类似RPC），有死锁风险。

Q3: Actor模型适合什么场景？
A: 状态隔离的场景、分布式系统、需要容错的系统。
   不适合低延迟要求高的计算密集型任务。
*/
```

#### 4. Month 21-22：C++20协程与异步I/O回顾

```cpp
// ============================================================
// Month 21-22 核心知识复盘：协程与异步I/O
// ============================================================

/*
C++20协程核心概念：

协程 = 可暂停/恢复的函数

关键字：
• co_await: 暂停协程，等待结果
• co_return: 返回结果并结束
• co_yield: 产出值并暂停

协程三要素：
1. Promise Type: 控制协程行为
2. Awaitable: 控制暂停/恢复
3. Coroutine Handle: 管理协程生命周期

Month 22在此基础上实现：
• EventLoop: 事件循环驱动协程
• AsyncSocket: 协程化的Socket操作
• Reactor模式: I/O多路复用 + 协程调度
*/

// 简化的Task协程（综合项目将完整实现）
template<typename T>
class Task {
public:
    struct promise_type {
        T value_;
        std::exception_ptr exception_;

        Task get_return_object() {
            return Task{std::coroutine_handle<promise_type>::from_promise(*this)};
        }

        std::suspend_always initial_suspend() { return {}; }
        std::suspend_always final_suspend() noexcept { return {}; }

        void return_value(T value) { value_ = std::move(value); }
        void unhandled_exception() { exception_ = std::current_exception(); }
    };

    // ... handle管理
private:
    std::coroutine_handle<promise_type> handle_;
};

/*
自测题：
Q1: initial_suspend返回suspend_always意味着什么？
A: 协程创建后不会立即执行，需要外部resume()启动（惰性启动）。

Q2: EventLoop如何与协程配合？
A: EventLoop使用epoll/kqueue等待I/O事件，
   事件就绪时resume对应的协程继续执行。

Q3: 协程相比线程的优势？
A: 轻量（几KB vs 1MB栈）、零上下文切换（用户态）、
   适合大量I/O等待的场景。
*/
```

#### 5. Month 23：决策框架回顾

```cpp
// ============================================================
// Month 23 核心知识复盘：并发模式决策框架
// ============================================================

/*
Month 23 建立的决策框架：

场景分析 → 执行模型 → 同步机制 → 数据结构

执行模型选择：
• CPU密集 → 线程池（线程=核数）
• I/O密集低并发 → Future + 线程池
• I/O密集高并发 → 协程 + EventLoop
• 分布式 → Actor模型

同步机制选择：
• 无共享 → Actor/Channel
• 超低延迟 → 无锁CAS
• 读多写少 → RCU / shared_mutex
• 高竞争 → 分段锁
• 简单场景 → mutex

综合项目的技术选型：
┌────────────────────────────────────────────────────┐
│  组件              │  技术选型       │  依据        │
├────────────────────────────────────────────────────┤
│  任务调度          │  线程池+协程    │  混合负载    │
│  任务队列          │  无锁MPMC      │  高竞争      │
│  I/O处理          │  协程EventLoop  │  高并发I/O  │
│  连接管理          │  shared_mutex  │  读多写少    │
│  统计数据          │  原子操作      │  无共享需求  │
└────────────────────────────────────────────────────┘
*/
```

### Day 5-6：综合项目架构设计

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | 需求分析与组件设计 | 2h |
| 下午 | 接口设计与依赖分析 | 3h |
| 晚上 | CMake搭建与骨架 | 2h |

#### 1. 需求分析

```cpp
// ============================================================
// 综合项目需求分析
// ============================================================

/*
项目名称：ConcurrentServer —— 高性能并发服务器框架

功能需求：
1. 支持TCP服务器，能处理大量并发连接
2. 提供Echo Server和简单HTTP Server示例
3. 支持协程化的异步I/O
4. 高效的任务调度

性能需求：
• Echo Server: > 100K QPS（单机）
• HTTP Server: > 50K QPS（简单GET请求）
• 连接数: 支持 > 10K并发连接
• 延迟: P99 < 1ms（Echo），P99 < 5ms（HTTP）

非功能需求：
• 优雅关闭：支持信号处理和安全退出
• 可观测性：内置性能统计
• 可移植性：支持Linux(epoll)和macOS(kqueue)
*/
```

#### 2. 组件架构设计

```cpp
// ============================================================
// 组件架构与依赖关系
// ============================================================

/*
组件依赖图：

                    ┌──────────────┐
                    │  Application │
                    │ Echo/HTTP    │
                    └──────┬───────┘
                           │ 使用
                    ┌──────▼───────┐
                    │   Server     │
                    │  Framework   │
                    └──────┬───────┘
                           │ 依赖
              ┌────────────┼────────────┐
              │            │            │
     ┌────────▼───┐ ┌─────▼─────┐ ┌───▼──────────┐
     │ AsyncIO    │ │ Protocol  │ │ Connection   │
     │ EventLoop  │ │ Parser    │ │ Manager      │
     └────────┬───┘ └───────────┘ └──────────────┘
              │
              │ 依赖
     ┌────────▼────────┐
     │  Coroutine      │
     │  Scheduler      │
     └────────┬────────┘
              │ 依赖
     ┌────────┼────────┐
     │        │        │
┌────▼───┐┌──▼────┐┌──▼──────┐
│ThreadPl││LFQueue││ Task    │
│WorkStea││ MPMC  ││ Channel │
└────────┘└───────┘└─────────┘

编译依赖（CMake Target）：
• concurrent_core: ThreadPool + LFQueue + Task/Channel
• concurrent_io: EventLoop + AsyncSocket (depends on core)
• concurrent_server: Server Framework (depends on io)
• echo_server: Example (depends on server)
• http_server: Example (depends on server)
• benchmarks: Benchmark suite (depends on server)
*/
```

#### 3. 核心接口设计

```cpp
// ============================================================
// 核心接口预设计
// ============================================================

// --- 线程池接口 ---
class WorkStealingThreadPool {
public:
    explicit WorkStealingThreadPool(size_t num_threads = 0);
    ~WorkStealingThreadPool();

    template<typename F, typename... Args>
    auto submit(F&& f, Args&&... args)
        -> std::future<std::invoke_result_t<F, Args...>>;

    void shutdown();
    void wait_idle();

    struct Stats {
        size_t tasks_submitted;
        size_t tasks_completed;
        size_t tasks_stolen;
        double avg_queue_length;
    };
    Stats get_stats() const;
};

// --- 无锁队列接口 ---
template<typename T>
class MPMCQueue {
public:
    explicit MPMCQueue(size_t capacity);

    bool push(const T& item);
    bool push(T&& item);
    bool pop(T& item);

    size_t size() const;
    bool empty() const;
};

// --- 协程Task ---
template<typename T = void>
class Task {
public:
    // co_await support
    bool await_ready() const noexcept;
    void await_suspend(std::coroutine_handle<> caller);
    T await_resume();
};

// --- EventLoop ---
class EventLoop {
public:
    EventLoop();
    ~EventLoop();

    void run();
    void stop();

    // 注册I/O事件
    void add_reader(int fd, std::function<void()> callback);
    void add_writer(int fd, std::function<void()> callback);
    void remove(int fd);

    // 定时器
    void call_later(std::chrono::milliseconds delay, std::function<void()> callback);

    // 从其他线程提交任务
    void post(std::function<void()> task);
};

// --- TCP Server ---
class TcpServer {
public:
    TcpServer(EventLoop& loop, const std::string& host, uint16_t port);

    // 设置连接处理器（协程版本）
    using ConnectionHandler = std::function<Task<void>(TcpConnection&)>;
    void set_handler(ConnectionHandler handler);

    void start();
    void stop();

    struct Stats {
        size_t total_connections;
        size_t active_connections;
        size_t bytes_received;
        size_t bytes_sent;
    };
    Stats get_stats() const;
};

// --- TCP连接 ---
class TcpConnection {
public:
    // 协程化读写
    Task<std::string> read(size_t max_bytes);
    Task<std::string> read_line();
    Task<size_t> write(std::string_view data);

    void close();

    std::string remote_address() const;
    uint16_t remote_port() const;
};
```

#### 4. CMake项目配置

```cmake
# ============================================================
# CMakeLists.txt - 综合项目构建配置
# ============================================================

cmake_minimum_required(VERSION 3.20)
project(ConcurrentServer CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 编译选项
add_compile_options(-Wall -Wextra -Wpedantic)

# 平台检测
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    add_definitions(-DUSE_EPOLL)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    add_definitions(-DUSE_KQUEUE)
endif()

# --- 核心并发库 ---
add_library(concurrent_core STATIC
    src/core/thread_pool.cpp
    src/core/work_stealing_deque.cpp
)
target_include_directories(concurrent_core PUBLIC include)
target_link_libraries(concurrent_core PRIVATE pthread)

# --- 异步I/O库 ---
add_library(concurrent_io STATIC
    src/io/event_loop.cpp
    src/io/async_socket.cpp
    src/io/timer.cpp
)
target_include_directories(concurrent_io PUBLIC include)
target_link_libraries(concurrent_io PUBLIC concurrent_core)

# --- 服务器框架 ---
add_library(concurrent_server STATIC
    src/server/tcp_server.cpp
    src/server/tcp_connection.cpp
    src/server/connection_manager.cpp
)
target_include_directories(concurrent_server PUBLIC include)
target_link_libraries(concurrent_server PUBLIC concurrent_io)

# --- 示例程序 ---
add_executable(echo_server examples/echo_server.cpp)
target_link_libraries(echo_server PRIVATE concurrent_server)

add_executable(http_server examples/http_server.cpp)
target_link_libraries(http_server PRIVATE concurrent_server)

# --- 基准测试 ---
add_executable(benchmark_all benchmarks/benchmark_all.cpp)
target_link_libraries(benchmark_all PRIVATE concurrent_server)

# --- 单元测试 ---
enable_testing()
add_executable(tests
    tests/test_thread_pool.cpp
    tests/test_lockfree_queue.cpp
    tests/test_event_loop.cpp
    tests/test_tcp_server.cpp
)
target_link_libraries(tests PRIVATE concurrent_server)
add_test(NAME unit_tests COMMAND tests)

# --- Sanitizer支持 ---
option(USE_TSAN "Enable ThreadSanitizer" OFF)
if(USE_TSAN)
    add_compile_options(-fsanitize=thread)
    add_link_options(-fsanitize=thread)
endif()
```

#### 5. 项目目录结构

```
concurrent_server/
├── CMakeLists.txt
├── include/
│   ├── core/
│   │   ├── thread_pool.hpp          # 工作窃取线程池
│   │   ├── work_stealing_deque.hpp  # Chase-Lev Deque
│   │   ├── mpmc_queue.hpp           # 无锁MPMC队列
│   │   ├── spsc_queue.hpp           # SPSC队列
│   │   ├── task.hpp                 # 协程Task
│   │   ├── channel.hpp              # 协程Channel
│   │   └── epoch_reclamation.hpp    # Epoch-based内存回收
│   ├── io/
│   │   ├── event_loop.hpp           # 事件循环
│   │   ├── io_backend.hpp           # epoll/kqueue抽象
│   │   ├── async_socket.hpp         # 异步Socket
│   │   └── timer.hpp                # 定时器
│   ├── server/
│   │   ├── tcp_server.hpp           # TCP服务器
│   │   ├── tcp_connection.hpp       # TCP连接
│   │   ├── connection_manager.hpp   # 连接管理
│   │   └── protocol_parser.hpp      # 协议解析基类
│   └── utils/
│       ├── noncopyable.hpp          # 不可复制基类
│       ├── logger.hpp               # 日志
│       └── stats.hpp                # 统计收集
├── src/
│   ├── core/
│   ├── io/
│   └── server/
├── examples/
│   ├── echo_server.cpp              # Echo Server示例
│   └── http_server.cpp              # HTTP Server示例
├── benchmarks/
│   ├── benchmark_all.cpp            # 完整基准测试
│   ├── bench_thread_pool.cpp        # 线程池基准
│   ├── bench_queue.cpp              # 队列基准
│   └── bench_server.cpp             # 服务器基准
├── tests/
│   ├── test_thread_pool.cpp
│   ├── test_lockfree_queue.cpp
│   ├── test_event_loop.cpp
│   └── test_tcp_server.cpp
└── docs/
    ├── architecture.md              # 架构文档
    ├── performance_report.md        # 性能报告
    └── year2_summary.md             # Year 2总结
```

### Day 7：架构评审与设计文档

#### 架构评审清单

```
架构评审要点：

1. 组件职责是否清晰？
   □ 每个组件只负责一件事
   □ 组件间通过明确接口通信
   □ 没有循环依赖

2. 技术选型是否合理？
   □ 线程池用于CPU密集型任务
   □ 协程用于I/O密集型任务
   □ 无锁队列用于高竞争场景
   □ 选择依据来自Month 23决策指南

3. 性能考虑：
   □ 缓存行对齐（避免伪共享）
   □ 内存分配优化
   □ 跨平台I/O后端

4. 安全性：
   □ RAII管理资源
   □ 优雅关闭机制
   □ 错误处理策略

5. 可测试性：
   □ 接口可mock
   □ 每个组件独立测试
   □ 集成测试覆盖
```

#### 第一周检验标准

- [ ] 能回答Month 13-23的核心自测题
- [ ] 理解综合项目的架构和技术选型依据
- [ ] 完成项目骨架和CMake配置
- [ ] 完成架构设计文档
- [ ] 通过架构评审清单检查

---

## 第二周：核心组件实现（Day 8-14）

> **本周目标**：实现服务器框架的三大核心并发组件——线程池、无锁队列、协程调度器

### Day 8-9：工作窃取线程池

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | Chase-Lev Deque实现 | 2h |
| 下午 | 线程池核心实现 | 4h |
| 晚上 | 优雅关闭与测试 | 2h |

#### 1. Chase-Lev Work-Stealing Deque

```cpp
// ============================================================
// Chase-Lev Deque：工作窃取的核心数据结构
// ============================================================

/*
Chase-Lev Deque的特点：

所有者线程（Worker）：
• push(): 从bottom端推入
• pop():  从bottom端弹出（LIFO，缓存友好）
• 只有一个所有者线程

窃取者线程（其他Worker）：
• steal(): 从top端窃取（FIFO）
• 可以有多个窃取者

┌─────────────────────────────────────┐
│  steal ← [top]                       │
│           [...]                      │
│           [...]                      │
│           [bottom] → push/pop        │
└─────────────────────────────────────┘

关键点：
• bottom只被owner修改，无需CAS
• top被多个窃取者竞争，需要CAS
• 可以动态扩容（circular array）
*/

#include <atomic>
#include <vector>
#include <optional>

template<typename T>
class WorkStealingDeque {
private:
    struct CircularArray {
        std::vector<T> data;
        size_t mask;

        explicit CircularArray(size_t capacity)
            : data(capacity), mask(capacity - 1) {
            // capacity必须是2的幂
        }

        T& operator[](size_t index) {
            return data[index & mask];
        }

        size_t capacity() const {
            return data.size();
        }

        CircularArray* grow(size_t bottom, size_t top) {
            auto* new_array = new CircularArray(capacity() * 2);
            for (size_t i = top; i < bottom; ++i) {
                (*new_array)[i] = (*this)[i];
            }
            return new_array;
        }
    };

    alignas(64) std::atomic<int64_t> top_{0};
    alignas(64) std::atomic<int64_t> bottom_{0};
    std::atomic<CircularArray*> array_;

public:
    explicit WorkStealingDeque(size_t capacity = 1024) {
        // 确保capacity是2的幂
        size_t actual = 1;
        while (actual < capacity) actual <<= 1;
        array_.store(new CircularArray(actual));
    }

    ~WorkStealingDeque() {
        delete array_.load();
    }

    // Owner: 推入任务
    void push(T item) {
        int64_t b = bottom_.load(std::memory_order_relaxed);
        int64_t t = top_.load(std::memory_order_acquire);
        CircularArray* arr = array_.load(std::memory_order_relaxed);

        // 检查是否需要扩容
        if (b - t >= static_cast<int64_t>(arr->capacity())) {
            arr = arr->grow(b, t);
            array_.store(arr, std::memory_order_release);
        }

        (*arr)[b] = std::move(item);

        // 确保item写入在bottom更新之前
        std::atomic_thread_fence(std::memory_order_release);
        bottom_.store(b + 1, std::memory_order_relaxed);
    }

    // Owner: 弹出任务
    std::optional<T> pop() {
        int64_t b = bottom_.load(std::memory_order_relaxed) - 1;
        CircularArray* arr = array_.load(std::memory_order_relaxed);
        bottom_.store(b, std::memory_order_relaxed);

        std::atomic_thread_fence(std::memory_order_seq_cst);

        int64_t t = top_.load(std::memory_order_relaxed);

        if (t <= b) {
            // 队列非空
            T item = (*arr)[b];

            if (t == b) {
                // 最后一个元素，需要和窃取者竞争
                if (!top_.compare_exchange_strong(
                    t, t + 1,
                    std::memory_order_seq_cst,
                    std::memory_order_relaxed)) {
                    // 被窃取了
                    bottom_.store(t + 1, std::memory_order_relaxed);
                    return std::nullopt;
                }
                bottom_.store(t + 1, std::memory_order_relaxed);
            }

            return item;
        }

        // 空队列
        bottom_.store(t, std::memory_order_relaxed);
        return std::nullopt;
    }

    // Thief: 窃取任务
    std::optional<T> steal() {
        int64_t t = top_.load(std::memory_order_acquire);

        std::atomic_thread_fence(std::memory_order_seq_cst);

        int64_t b = bottom_.load(std::memory_order_acquire);

        if (t < b) {
            // 有数据可窃取
            CircularArray* arr = array_.load(std::memory_order_relaxed);
            T item = (*arr)[t];

            if (!top_.compare_exchange_strong(
                t, t + 1,
                std::memory_order_seq_cst,
                std::memory_order_relaxed)) {
                // 其他窃取者抢先了
                return std::nullopt;
            }

            return item;
        }

        return std::nullopt;
    }

    bool empty() const {
        int64_t b = bottom_.load(std::memory_order_relaxed);
        int64_t t = top_.load(std::memory_order_relaxed);
        return b <= t;
    }

    size_t size() const {
        int64_t b = bottom_.load(std::memory_order_relaxed);
        int64_t t = top_.load(std::memory_order_relaxed);
        return static_cast<size_t>(std::max(b - t, int64_t(0)));
    }
};
```

#### 2. 工作窃取线程池完整实现

```cpp
// ============================================================
// 工作窃取线程池
// ============================================================

#include <thread>
#include <future>
#include <functional>
#include <random>

class WorkStealingThreadPool {
    using Task = std::function<void()>;

    // 每个工作线程的状态
    struct Worker {
        WorkStealingDeque<Task> local_queue{4096};
        std::thread thread;
        bool active = true;
    };

    std::vector<std::unique_ptr<Worker>> workers_;
    MPMCQueue<Task> global_queue_;  // 全局队列（用于外部提交）

    std::atomic<bool> running_{true};
    std::atomic<size_t> tasks_submitted_{0};
    std::atomic<size_t> tasks_completed_{0};
    std::atomic<size_t> tasks_stolen_{0};

    // 当前线程的worker索引
    static thread_local int current_worker_id_;

public:
    explicit WorkStealingThreadPool(size_t num_threads = 0)
        : global_queue_(65536)
    {
        if (num_threads == 0) {
            num_threads = std::thread::hardware_concurrency();
        }

        for (size_t i = 0; i < num_threads; ++i) {
            auto worker = std::make_unique<Worker>();
            worker->thread = std::thread(&WorkStealingThreadPool::worker_loop,
                                         this, i);
            workers_.push_back(std::move(worker));
        }
    }

    ~WorkStealingThreadPool() {
        shutdown();
    }

    // 提交任务
    template<typename F, typename... Args>
    auto submit(F&& f, Args&&... args)
        -> std::future<std::invoke_result_t<F, Args...>>
    {
        using ReturnType = std::invoke_result_t<F, Args...>;

        auto task = std::make_shared<std::packaged_task<ReturnType()>>(
            std::bind(std::forward<F>(f), std::forward<Args>(args)...));

        auto future = task->get_future();

        auto wrapper = [task]() { (*task)(); };

        ++tasks_submitted_;

        // 如果是从工作线程提交，放入本地队列
        if (current_worker_id_ >= 0 &&
            current_worker_id_ < static_cast<int>(workers_.size())) {
            workers_[current_worker_id_]->local_queue.push(std::move(wrapper));
        } else {
            // 外部线程提交到全局队列
            global_queue_.push(std::move(wrapper));
        }

        return future;
    }

    void shutdown() {
        running_.store(false, std::memory_order_release);
        for (auto& worker : workers_) {
            if (worker->thread.joinable()) {
                worker->thread.join();
            }
        }
    }

    size_t thread_count() const { return workers_.size(); }

    struct Stats {
        size_t tasks_submitted;
        size_t tasks_completed;
        size_t tasks_stolen;
    };

    Stats get_stats() const {
        return {
            tasks_submitted_.load(),
            tasks_completed_.load(),
            tasks_stolen_.load()
        };
    }

private:
    void worker_loop(size_t worker_id) {
        current_worker_id_ = static_cast<int>(worker_id);

        while (running_.load(std::memory_order_acquire)) {
            Task task;

            // 1. 先从本地队列取
            if (auto t = workers_[worker_id]->local_queue.pop()) {
                task = std::move(*t);
            }
            // 2. 从全局队列取
            else if (global_queue_.pop(task)) {
                // got it
            }
            // 3. 从其他工作线程窃取
            else if (auto t = try_steal(worker_id)) {
                task = std::move(*t);
                ++tasks_stolen_;
            }
            else {
                // 没有任务，短暂让出CPU
                std::this_thread::yield();
                continue;
            }

            // 执行任务
            task();
            ++tasks_completed_;
        }

        // 清空剩余任务
        drain_remaining(worker_id);
    }

    std::optional<Task> try_steal(size_t my_id) {
        // 随机选择起始位置，避免所有线程都从同一个线程窃取
        thread_local std::mt19937 rng(std::random_device{}());
        size_t start = rng() % workers_.size();

        for (size_t i = 0; i < workers_.size(); ++i) {
            size_t target = (start + i) % workers_.size();
            if (target == my_id) continue;

            if (auto task = workers_[target]->local_queue.steal()) {
                return task;
            }
        }
        return std::nullopt;
    }

    void drain_remaining(size_t worker_id) {
        while (auto task = workers_[worker_id]->local_queue.pop()) {
            (*task)();
            ++tasks_completed_;
        }
    }
};

thread_local int WorkStealingThreadPool::current_worker_id_ = -1;
```

### Day 10-11：无锁MPMC队列

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | MPMC队列设计 | 2h |
| 下午 | 实现与内存回收 | 4h |
| 晚上 | 性能测试 | 2h |

#### 无锁MPMC有界队列实现

```cpp
// ============================================================
// 无锁MPMC有界队列（基于环形缓冲区）
// ============================================================

/*
设计思路：
• 使用环形缓冲区
• 每个槽位有sequence计数器
• 生产者和消费者通过CAS推进各自的位置
• 无ABA问题（sequence单调递增）

性能特点：
• 无锁，无阻塞
• 缓存友好（连续内存）
• 有界，内置背压
*/

template<typename T>
class MPMCBoundedQueue {
private:
    struct Cell {
        std::atomic<size_t> sequence;
        T data;
    };

    // 缓存行对齐
    alignas(64) std::atomic<size_t> enqueue_pos_{0};
    alignas(64) std::atomic<size_t> dequeue_pos_{0};

    std::vector<Cell> buffer_;
    size_t mask_;

public:
    explicit MPMCBoundedQueue(size_t capacity) {
        // 向上取2的幂
        size_t actual = 1;
        while (actual < capacity) actual <<= 1;

        mask_ = actual - 1;
        buffer_.resize(actual);

        for (size_t i = 0; i < actual; ++i) {
            buffer_[i].sequence.store(i, std::memory_order_relaxed);
        }
    }

    // 非阻塞入队
    bool push(T item) {
        Cell* cell;
        size_t pos = enqueue_pos_.load(std::memory_order_relaxed);

        for (;;) {
            cell = &buffer_[pos & mask_];
            size_t seq = cell->sequence.load(std::memory_order_acquire);
            intptr_t diff = static_cast<intptr_t>(seq) -
                           static_cast<intptr_t>(pos);

            if (diff == 0) {
                // 槽位可用，尝试占据
                if (enqueue_pos_.compare_exchange_weak(
                    pos, pos + 1, std::memory_order_relaxed)) {
                    break;
                }
            } else if (diff < 0) {
                // 队列满
                return false;
            } else {
                // 其他生产者已占据，重新读取位置
                pos = enqueue_pos_.load(std::memory_order_relaxed);
            }
        }

        // 写入数据
        cell->data = std::move(item);
        // 更新sequence，通知消费者
        cell->sequence.store(pos + 1, std::memory_order_release);
        return true;
    }

    // 非阻塞出队
    bool pop(T& item) {
        Cell* cell;
        size_t pos = dequeue_pos_.load(std::memory_order_relaxed);

        for (;;) {
            cell = &buffer_[pos & mask_];
            size_t seq = cell->sequence.load(std::memory_order_acquire);
            intptr_t diff = static_cast<intptr_t>(seq) -
                           static_cast<intptr_t>(pos + 1);

            if (diff == 0) {
                // 数据可用，尝试消费
                if (dequeue_pos_.compare_exchange_weak(
                    pos, pos + 1, std::memory_order_relaxed)) {
                    break;
                }
            } else if (diff < 0) {
                // 队列空
                return false;
            } else {
                pos = dequeue_pos_.load(std::memory_order_relaxed);
            }
        }

        // 读取数据
        item = std::move(cell->data);
        // 更新sequence，通知生产者可以复用
        cell->sequence.store(pos + mask_ + 1, std::memory_order_release);
        return true;
    }

    size_t capacity() const { return mask_ + 1; }

    bool empty() const {
        size_t e = enqueue_pos_.load(std::memory_order_relaxed);
        size_t d = dequeue_pos_.load(std::memory_order_relaxed);
        return e <= d;
    }

    size_t approximate_size() const {
        size_t e = enqueue_pos_.load(std::memory_order_relaxed);
        size_t d = dequeue_pos_.load(std::memory_order_relaxed);
        return e > d ? e - d : 0;
    }
};
```

### Day 12-13：协程调度器

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | Task/Promise实现 | 2h |
| 下午 | 调度器与Channel | 4h |
| 晚上 | 协程与线程池集成 | 2h |

#### 1. 协程Task完整实现

```cpp
// ============================================================
// 协程Task：支持co_await和异常传播
// ============================================================

#include <coroutine>
#include <exception>
#include <variant>

template<typename T>
class Task {
public:
    struct promise_type;
    using handle_type = std::coroutine_handle<promise_type>;

    struct promise_type {
        std::variant<std::monostate, T, std::exception_ptr> result_;
        std::coroutine_handle<> continuation_;

        Task get_return_object() {
            return Task{handle_type::from_promise(*this)};
        }

        std::suspend_always initial_suspend() noexcept { return {}; }

        auto final_suspend() noexcept {
            struct FinalAwaiter {
                bool await_ready() noexcept { return false; }

                std::coroutine_handle<>
                await_suspend(handle_type h) noexcept {
                    if (h.promise().continuation_) {
                        return h.promise().continuation_;
                    }
                    return std::noop_coroutine();
                }

                void await_resume() noexcept {}
            };
            return FinalAwaiter{};
        }

        void return_value(T value) {
            result_.template emplace<1>(std::move(value));
        }

        void unhandled_exception() {
            result_.template emplace<2>(std::current_exception());
        }
    };

    // Awaitable接口
    bool await_ready() const noexcept {
        return handle_.done();
    }

    std::coroutine_handle<>
    await_suspend(std::coroutine_handle<> caller) noexcept {
        handle_.promise().continuation_ = caller;
        return handle_;
    }

    T await_resume() {
        auto& result = handle_.promise().result_;
        if (std::holds_alternative<std::exception_ptr>(result)) {
            std::rethrow_exception(std::get<std::exception_ptr>(result));
        }
        return std::move(std::get<T>(result));
    }

    // 手动启动和获取结果
    void start() {
        handle_.resume();
    }

    bool done() const {
        return handle_.done();
    }

    T get() {
        if (!handle_.done()) {
            handle_.resume();
        }
        return await_resume();
    }

    // Move only
    Task(Task&& other) noexcept : handle_(other.handle_) {
        other.handle_ = nullptr;
    }

    ~Task() {
        if (handle_) handle_.destroy();
    }

    Task(const Task&) = delete;
    Task& operator=(const Task&) = delete;

private:
    explicit Task(handle_type h) : handle_(h) {}
    handle_type handle_;
};

// void特化
template<>
class Task<void> {
public:
    struct promise_type;
    using handle_type = std::coroutine_handle<promise_type>;

    struct promise_type {
        std::exception_ptr exception_;
        std::coroutine_handle<> continuation_;

        Task get_return_object() {
            return Task{handle_type::from_promise(*this)};
        }

        std::suspend_always initial_suspend() noexcept { return {}; }

        auto final_suspend() noexcept {
            struct FinalAwaiter {
                bool await_ready() noexcept { return false; }
                std::coroutine_handle<>
                await_suspend(handle_type h) noexcept {
                    if (h.promise().continuation_)
                        return h.promise().continuation_;
                    return std::noop_coroutine();
                }
                void await_resume() noexcept {}
            };
            return FinalAwaiter{};
        }

        void return_void() {}
        void unhandled_exception() {
            exception_ = std::current_exception();
        }
    };

    bool await_ready() const noexcept { return handle_.done(); }

    std::coroutine_handle<>
    await_suspend(std::coroutine_handle<> caller) noexcept {
        handle_.promise().continuation_ = caller;
        return handle_;
    }

    void await_resume() {
        if (handle_.promise().exception_) {
            std::rethrow_exception(handle_.promise().exception_);
        }
    }

    Task(Task&& other) noexcept : handle_(other.handle_) {
        other.handle_ = nullptr;
    }
    ~Task() { if (handle_) handle_.destroy(); }
    Task(const Task&) = delete;

private:
    explicit Task(handle_type h) : handle_(h) {}
    handle_type handle_;
};
```

#### 2. 协程Channel实现

```cpp
// ============================================================
// 有界Channel：协程间通信
// ============================================================

template<typename T>
class Channel {
private:
    struct State {
        std::queue<T> buffer;
        size_t capacity;
        bool closed = false;

        struct Waiter {
            std::coroutine_handle<> handle;
            T* value_ptr;  // 用于接收
        };
        std::queue<Waiter> senders;
        std::queue<Waiter> receivers;
    };

    std::shared_ptr<State> state_;
    std::mutex mutex_;

public:
    explicit Channel(size_t capacity = 0)
        : state_(std::make_shared<State>()) {
        state_->capacity = capacity;
    }

    // 发送
    auto send(T value) {
        struct SendAwaiter {
            Channel* ch;
            T value;
            bool ready = false;

            bool await_ready() {
                std::lock_guard lock(ch->mutex_);
                if (ch->state_->closed) return true;
                if (ch->state_->buffer.size() < ch->state_->capacity) {
                    ch->state_->buffer.push(std::move(value));
                    // 唤醒等待的接收者
                    if (!ch->state_->receivers.empty()) {
                        auto waiter = std::move(ch->state_->receivers.front());
                        ch->state_->receivers.pop();
                        *waiter.value_ptr = std::move(ch->state_->buffer.front());
                        ch->state_->buffer.pop();
                        waiter.handle.resume();
                    }
                    ready = true;
                    return true;
                }
                return false;
            }

            void await_suspend(std::coroutine_handle<> h) {
                std::lock_guard lock(ch->mutex_);
                ch->state_->senders.push({h, nullptr});
            }

            bool await_resume() {
                return !ch->state_->closed;
            }
        };
        return SendAwaiter{this, std::move(value)};
    }

    // 接收
    auto receive() {
        struct ReceiveAwaiter {
            Channel* ch;
            T value;

            bool await_ready() {
                std::lock_guard lock(ch->mutex_);
                if (!ch->state_->buffer.empty()) {
                    value = std::move(ch->state_->buffer.front());
                    ch->state_->buffer.pop();
                    // 唤醒等待的发送者
                    if (!ch->state_->senders.empty()) {
                        auto waiter = std::move(ch->state_->senders.front());
                        ch->state_->senders.pop();
                        waiter.handle.resume();
                    }
                    return true;
                }
                return ch->state_->closed;
            }

            void await_suspend(std::coroutine_handle<> h) {
                std::lock_guard lock(ch->mutex_);
                ch->state_->receivers.push({h, &value});
            }

            std::optional<T> await_resume() {
                if (ch->state_->closed && ch->state_->buffer.empty()) {
                    return std::nullopt;
                }
                return std::move(value);
            }
        };
        return ReceiveAwaiter{this};
    }

    void close() {
        std::lock_guard lock(mutex_);
        state_->closed = true;
        // 唤醒所有等待者
        while (!state_->receivers.empty()) {
            auto waiter = std::move(state_->receivers.front());
            state_->receivers.pop();
            waiter.handle.resume();
        }
        while (!state_->senders.empty()) {
            auto waiter = std::move(state_->senders.front());
            state_->senders.pop();
            waiter.handle.resume();
        }
    }
};

// 使用示例
/*
Task<void> producer(Channel<int>& ch) {
    for (int i = 0; i < 100; ++i) {
        co_await ch.send(i);
    }
    ch.close();
}

Task<void> consumer(Channel<int>& ch) {
    while (auto item = co_await ch.receive()) {
        std::cout << "Received: " << *item << "\n";
    }
}
*/
```

### Day 14：组件集成测试

#### 集成测试示例

```cpp
// ============================================================
// 核心组件集成测试
// ============================================================

#include <cassert>
#include <iostream>

// 测试1：线程池基本功能
void test_thread_pool_basic() {
    WorkStealingThreadPool pool(4);

    std::atomic<int> counter{0};
    std::vector<std::future<void>> futures;

    for (int i = 0; i < 10000; ++i) {
        futures.push_back(pool.submit([&counter] {
            ++counter;
        }));
    }

    for (auto& f : futures) {
        f.get();
    }

    assert(counter.load() == 10000);
    std::cout << "线程池基本测试通过\n";

    auto stats = pool.get_stats();
    std::cout << "  提交: " << stats.tasks_submitted
              << "  完成: " << stats.tasks_completed
              << "  窃取: " << stats.tasks_stolen << "\n";
}

// 测试2：MPMC队列正确性
void test_mpmc_queue() {
    MPMCBoundedQueue<int> queue(1024);

    constexpr int NUM_PRODUCERS = 4;
    constexpr int NUM_CONSUMERS = 4;
    constexpr int ITEMS_PER_PRODUCER = 10000;

    std::atomic<int> sum_produced{0};
    std::atomic<int> sum_consumed{0};

    std::vector<std::thread> threads;

    // 生产者
    for (int p = 0; p < NUM_PRODUCERS; ++p) {
        threads.emplace_back([&queue, &sum_produced, p]() {
            for (int i = 0; i < ITEMS_PER_PRODUCER; ++i) {
                int value = p * ITEMS_PER_PRODUCER + i;
                while (!queue.push(value)) {
                    std::this_thread::yield();
                }
                sum_produced += value;
            }
        });
    }

    // 消费者
    std::atomic<int> total_consumed{0};
    for (int c = 0; c < NUM_CONSUMERS; ++c) {
        threads.emplace_back([&]() {
            int value;
            while (total_consumed.load() < NUM_PRODUCERS * ITEMS_PER_PRODUCER) {
                if (queue.pop(value)) {
                    sum_consumed += value;
                    ++total_consumed;
                } else {
                    std::this_thread::yield();
                }
            }
        });
    }

    for (auto& t : threads) t.join();

    assert(sum_produced.load() == sum_consumed.load());
    std::cout << "MPMC队列测试通过 (sum=" << sum_consumed.load() << ")\n";
}

// 测试3：协程Task基本功能
void test_coroutine_task() {
    auto task = []() -> Task<int> {
        co_return 42;
    }();

    task.start();
    assert(task.done());
    assert(task.get() == 42);
    std::cout << "协程Task测试通过\n";
}

// 运行所有测试
void run_integration_tests() {
    std::cout << "=== 核心组件集成测试 ===\n\n";
    test_thread_pool_basic();
    test_mpmc_queue();
    test_coroutine_task();
    std::cout << "\n所有集成测试通过！\n";
}
```

#### 第二周检验标准

- [ ] Chase-Lev Deque实现正确，通过并发测试
- [ ] 工作窃取线程池能正确执行和分配任务
- [ ] MPMC无锁队列通过多线程正确性测试
- [ ] 协程Task支持co_await和异常传播
- [ ] Channel支持协程间通信
- [ ] 所有组件通过集成测试

---

## 第三周：异步I/O与服务器实现（Day 15-21）

> **本周目标**：实现异步I/O层和TCP服务器框架，完成Echo和HTTP Server示例

### Day 15-16：异步I/O封装

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | I/O后端抽象 | 2h |
| 下午 | EventLoop实现 | 4h |
| 晚上 | Timer支持 | 2h |

#### 1. 跨平台I/O后端

```cpp
// ============================================================
// I/O后端抽象：支持epoll(Linux)和kqueue(macOS)
// ============================================================

/*
I/O多路复用对比：

┌────────────────┬──────────────┬──────────────┬──────────────┐
│  API           │  平台        │  性能        │  特点        │
├────────────────┼──────────────┼──────────────┼──────────────┤
│  select        │  跨平台      │  O(n)        │  fd数量限制  │
│  poll          │  POSIX       │  O(n)        │  无fd限制    │
│  epoll         │  Linux       │  O(1)        │  边沿/水平   │
│  kqueue        │  BSD/macOS   │  O(1)        │  统一事件    │
│  io_uring      │  Linux 5.1+  │  O(1)        │  零拷贝      │
└────────────────┴──────────────┴──────────────┴──────────────┘
*/

#include <functional>
#include <vector>
#include <cstdint>

// I/O事件类型
enum class IOEvent : uint32_t {
    Read    = 1 << 0,
    Write   = 1 << 1,
    Error   = 1 << 2,
    HangUp  = 1 << 3,
};

inline IOEvent operator|(IOEvent a, IOEvent b) {
    return static_cast<IOEvent>(
        static_cast<uint32_t>(a) | static_cast<uint32_t>(b));
}

inline bool has_event(IOEvent events, IOEvent flag) {
    return (static_cast<uint32_t>(events) & static_cast<uint32_t>(flag)) != 0;
}

// I/O后端接口
class IOBackend {
public:
    struct Event {
        int fd;
        IOEvent events;
    };

    virtual ~IOBackend() = default;

    virtual void add(int fd, IOEvent events) = 0;
    virtual void modify(int fd, IOEvent events) = 0;
    virtual void remove(int fd) = 0;

    // 等待事件，返回就绪事件列表
    virtual std::vector<Event> wait(int timeout_ms) = 0;

    // 工厂方法
    static std::unique_ptr<IOBackend> create();
};

#ifdef USE_EPOLL
// Linux epoll实现
#include <sys/epoll.h>

class EpollBackend : public IOBackend {
    int epfd_;

public:
    EpollBackend() {
        epfd_ = epoll_create1(EPOLL_CLOEXEC);
        if (epfd_ < 0) throw std::runtime_error("epoll_create1 failed");
    }

    ~EpollBackend() override { close(epfd_); }

    void add(int fd, IOEvent events) override {
        struct epoll_event ev{};
        ev.events = to_epoll(events);
        ev.data.fd = fd;
        epoll_ctl(epfd_, EPOLL_CTL_ADD, fd, &ev);
    }

    void modify(int fd, IOEvent events) override {
        struct epoll_event ev{};
        ev.events = to_epoll(events);
        ev.data.fd = fd;
        epoll_ctl(epfd_, EPOLL_CTL_MOD, fd, &ev);
    }

    void remove(int fd) override {
        epoll_ctl(epfd_, EPOLL_CTL_DEL, fd, nullptr);
    }

    std::vector<Event> wait(int timeout_ms) override {
        std::array<struct epoll_event, 256> events;
        int n = epoll_wait(epfd_, events.data(), events.size(), timeout_ms);

        std::vector<Event> result;
        for (int i = 0; i < n; ++i) {
            result.push_back({events[i].data.fd, from_epoll(events[i].events)});
        }
        return result;
    }

private:
    static uint32_t to_epoll(IOEvent e) {
        uint32_t result = 0;
        if (has_event(e, IOEvent::Read)) result |= EPOLLIN;
        if (has_event(e, IOEvent::Write)) result |= EPOLLOUT;
        return result | EPOLLET;  // 使用边沿触发
    }

    static IOEvent from_epoll(uint32_t e) {
        IOEvent result = static_cast<IOEvent>(0);
        if (e & EPOLLIN) result = result | IOEvent::Read;
        if (e & EPOLLOUT) result = result | IOEvent::Write;
        if (e & EPOLLERR) result = result | IOEvent::Error;
        if (e & EPOLLHUP) result = result | IOEvent::HangUp;
        return result;
    }
};
#endif

#ifdef USE_KQUEUE
// macOS kqueue实现
#include <sys/event.h>

class KqueueBackend : public IOBackend {
    int kqfd_;

public:
    KqueueBackend() {
        kqfd_ = kqueue();
        if (kqfd_ < 0) throw std::runtime_error("kqueue failed");
    }

    ~KqueueBackend() override { close(kqfd_); }

    void add(int fd, IOEvent events) override {
        std::vector<struct kevent> changes;
        if (has_event(events, IOEvent::Read)) {
            struct kevent ev;
            EV_SET(&ev, fd, EVFILT_READ, EV_ADD | EV_CLEAR, 0, 0, nullptr);
            changes.push_back(ev);
        }
        if (has_event(events, IOEvent::Write)) {
            struct kevent ev;
            EV_SET(&ev, fd, EVFILT_WRITE, EV_ADD | EV_CLEAR, 0, 0, nullptr);
            changes.push_back(ev);
        }
        kevent(kqfd_, changes.data(), changes.size(), nullptr, 0, nullptr);
    }

    void modify(int fd, IOEvent events) override {
        remove(fd);
        add(fd, events);
    }

    void remove(int fd) override {
        struct kevent changes[2];
        EV_SET(&changes[0], fd, EVFILT_READ, EV_DELETE, 0, 0, nullptr);
        EV_SET(&changes[1], fd, EVFILT_WRITE, EV_DELETE, 0, 0, nullptr);
        kevent(kqfd_, changes, 2, nullptr, 0, nullptr);
    }

    std::vector<Event> wait(int timeout_ms) override {
        struct timespec ts;
        ts.tv_sec = timeout_ms / 1000;
        ts.tv_nsec = (timeout_ms % 1000) * 1000000;

        std::array<struct kevent, 256> events;
        int n = kevent(kqfd_, nullptr, 0, events.data(), events.size(),
                       timeout_ms >= 0 ? &ts : nullptr);

        std::vector<Event> result;
        for (int i = 0; i < n; ++i) {
            IOEvent io_event = static_cast<IOEvent>(0);
            if (events[i].filter == EVFILT_READ) io_event = IOEvent::Read;
            if (events[i].filter == EVFILT_WRITE) io_event = IOEvent::Write;
            if (events[i].flags & EV_EOF) io_event = io_event | IOEvent::HangUp;
            if (events[i].flags & EV_ERROR) io_event = io_event | IOEvent::Error;

            result.push_back({static_cast<int>(events[i].ident), io_event});
        }
        return result;
    }
};
#endif

// 工厂方法
std::unique_ptr<IOBackend> IOBackend::create() {
#ifdef USE_EPOLL
    return std::make_unique<EpollBackend>();
#elif defined(USE_KQUEUE)
    return std::make_unique<KqueueBackend>();
#else
    #error "No supported I/O backend"
#endif
}
```

#### 2. EventLoop实现

```cpp
// ============================================================
// EventLoop：事件循环核心
// ============================================================

#include <map>
#include <queue>
#include <mutex>

class EventLoop {
public:
    using Callback = std::function<void()>;

private:
    std::unique_ptr<IOBackend> backend_;
    bool running_ = false;

    // fd -> callback映射
    struct FDCallbacks {
        Callback on_read;
        Callback on_write;
    };
    std::map<int, FDCallbacks> fd_callbacks_;

    // 定时器
    struct Timer {
        std::chrono::steady_clock::time_point deadline;
        Callback callback;
        bool operator>(const Timer& other) const {
            return deadline > other.deadline;
        }
    };
    std::priority_queue<Timer, std::vector<Timer>, std::greater<>> timers_;

    // 跨线程任务队列（双缓冲）
    std::mutex pending_mutex_;
    std::vector<Callback> pending_tasks_;
    int wakeup_fd_[2] = {-1, -1};  // pipe用于唤醒

public:
    EventLoop() : backend_(IOBackend::create()) {
        // 创建唤醒pipe
        pipe(wakeup_fd_);
        // 设置非阻塞
        set_nonblocking(wakeup_fd_[0]);
        set_nonblocking(wakeup_fd_[1]);
        // 监听pipe读端
        backend_->add(wakeup_fd_[0], IOEvent::Read);
    }

    ~EventLoop() {
        if (wakeup_fd_[0] >= 0) close(wakeup_fd_[0]);
        if (wakeup_fd_[1] >= 0) close(wakeup_fd_[1]);
    }

    // 注册I/O回调
    void add_reader(int fd, Callback callback) {
        fd_callbacks_[fd].on_read = std::move(callback);
        update_fd(fd);
    }

    void add_writer(int fd, Callback callback) {
        fd_callbacks_[fd].on_write = std::move(callback);
        update_fd(fd);
    }

    void remove(int fd) {
        backend_->remove(fd);
        fd_callbacks_.erase(fd);
    }

    // 定时器
    void call_later(std::chrono::milliseconds delay, Callback callback) {
        timers_.push({
            std::chrono::steady_clock::now() + delay,
            std::move(callback)
        });
    }

    // 跨线程提交任务
    void post(Callback task) {
        {
            std::lock_guard<std::mutex> lock(pending_mutex_);
            pending_tasks_.push_back(std::move(task));
        }
        // 唤醒事件循环
        char c = 1;
        ::write(wakeup_fd_[1], &c, 1);
    }

    // 运行事件循环
    void run() {
        running_ = true;
        while (running_) {
            // 计算下一个定时器的超时时间
            int timeout_ms = compute_timeout();

            // 等待I/O事件
            auto events = backend_->wait(timeout_ms);

            // 处理I/O事件
            for (const auto& event : events) {
                if (event.fd == wakeup_fd_[0]) {
                    drain_wakeup();
                    continue;
                }

                auto it = fd_callbacks_.find(event.fd);
                if (it == fd_callbacks_.end()) continue;

                if (has_event(event.events, IOEvent::Read) && it->second.on_read) {
                    it->second.on_read();
                }
                if (has_event(event.events, IOEvent::Write) && it->second.on_write) {
                    it->second.on_write();
                }
            }

            // 处理定时器
            process_timers();

            // 处理跨线程任务
            process_pending_tasks();
        }
    }

    void stop() {
        running_ = false;
        // 唤醒事件循环
        char c = 0;
        ::write(wakeup_fd_[1], &c, 1);
    }

private:
    void update_fd(int fd) {
        IOEvent events = static_cast<IOEvent>(0);
        auto& cbs = fd_callbacks_[fd];
        if (cbs.on_read) events = events | IOEvent::Read;
        if (cbs.on_write) events = events | IOEvent::Write;
        backend_->add(fd, events);
    }

    int compute_timeout() {
        if (timers_.empty()) return 100;  // 默认100ms
        auto now = std::chrono::steady_clock::now();
        auto next = timers_.top().deadline;
        if (next <= now) return 0;
        auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(next - now);
        return std::min(static_cast<int>(ms.count()), 100);
    }

    void process_timers() {
        auto now = std::chrono::steady_clock::now();
        while (!timers_.empty() && timers_.top().deadline <= now) {
            auto timer = std::move(const_cast<Timer&>(timers_.top()));
            timers_.pop();
            timer.callback();
        }
    }

    void process_pending_tasks() {
        std::vector<Callback> tasks;
        {
            std::lock_guard<std::mutex> lock(pending_mutex_);
            tasks.swap(pending_tasks_);
        }
        for (auto& task : tasks) {
            task();
        }
    }

    void drain_wakeup() {
        char buf[256];
        while (::read(wakeup_fd_[0], buf, sizeof(buf)) > 0) {}
    }

    static void set_nonblocking(int fd) {
        int flags = fcntl(fd, F_GETFL, 0);
        fcntl(fd, F_SETFL, flags | O_NONBLOCK);
    }
};
```

### Day 17-18：TCP服务器框架

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | TCP连接抽象 | 2h |
| 下午 | 服务器框架实现 | 4h |
| 晚上 | 连接管理 | 2h |

#### 1. TCP连接

```cpp
// ============================================================
// 异步TCP连接
// ============================================================

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>

class TcpConnection : public std::enable_shared_from_this<TcpConnection> {
    int fd_;
    EventLoop& loop_;
    std::string remote_addr_;
    uint16_t remote_port_;

    // 读写缓冲区
    std::string read_buffer_;
    std::string write_buffer_;

    // 协程等待状态
    std::coroutine_handle<> read_waiter_;
    std::coroutine_handle<> write_waiter_;

public:
    TcpConnection(int fd, EventLoop& loop,
                  std::string addr, uint16_t port)
        : fd_(fd), loop_(loop)
        , remote_addr_(std::move(addr)), remote_port_(port)
    {
        set_nonblocking(fd_);
    }

    ~TcpConnection() {
        if (fd_ >= 0) {
            loop_.remove(fd_);
            ::close(fd_);
        }
    }

    // 协程化读取
    auto read(size_t max_bytes) {
        struct ReadAwaiter {
            TcpConnection* conn;
            size_t max_bytes;
            std::string result;

            bool await_ready() {
                // 尝试立即读取
                result = conn->try_read(max_bytes);
                return !result.empty();
            }

            void await_suspend(std::coroutine_handle<> h) {
                conn->read_waiter_ = h;
                conn->loop_.add_reader(conn->fd_, [conn = conn]() {
                    conn->on_readable();
                });
            }

            std::string await_resume() {
                if (result.empty()) {
                    result = conn->try_read(max_bytes);
                }
                return result;
            }
        };
        return ReadAwaiter{this, max_bytes};
    }

    // 协程化写入
    auto write(std::string_view data) {
        struct WriteAwaiter {
            TcpConnection* conn;
            std::string data;
            size_t written = 0;

            bool await_ready() {
                written = conn->try_write(data);
                return written == data.size();
            }

            void await_suspend(std::coroutine_handle<> h) {
                // 保存剩余数据
                conn->write_buffer_ = data.substr(written);
                conn->write_waiter_ = h;
                conn->loop_.add_writer(conn->fd_, [conn = conn]() {
                    conn->on_writable();
                });
            }

            size_t await_resume() { return data.size(); }
        };
        return WriteAwaiter{this, std::string(data)};
    }

    void close() {
        if (fd_ >= 0) {
            loop_.remove(fd_);
            ::close(fd_);
            fd_ = -1;
        }
    }

    int fd() const { return fd_; }
    const std::string& remote_address() const { return remote_addr_; }
    uint16_t remote_port() const { return remote_port_; }

private:
    std::string try_read(size_t max_bytes) {
        std::string buf(max_bytes, '\0');
        ssize_t n = ::recv(fd_, buf.data(), max_bytes, 0);
        if (n > 0) {
            buf.resize(n);
            return buf;
        }
        return {};
    }

    size_t try_write(std::string_view data) {
        ssize_t n = ::send(fd_, data.data(), data.size(), MSG_NOSIGNAL);
        return n > 0 ? static_cast<size_t>(n) : 0;
    }

    void on_readable() {
        if (read_waiter_) {
            auto h = read_waiter_;
            read_waiter_ = nullptr;
            h.resume();
        }
    }

    void on_writable() {
        if (!write_buffer_.empty()) {
            size_t n = try_write(write_buffer_);
            write_buffer_.erase(0, n);
            if (write_buffer_.empty() && write_waiter_) {
                auto h = write_waiter_;
                write_waiter_ = nullptr;
                h.resume();
            }
        }
    }

    static void set_nonblocking(int fd) {
        int flags = fcntl(fd, F_GETFL, 0);
        fcntl(fd, F_SETFL, flags | O_NONBLOCK);
    }
};
```

#### 2. TCP服务器

```cpp
// ============================================================
// TCP服务器框架
// ============================================================

class TcpServer {
public:
    using ConnectionHandler = std::function<Task<void>(
        std::shared_ptr<TcpConnection>)>;

private:
    EventLoop& loop_;
    int listen_fd_ = -1;
    std::string host_;
    uint16_t port_;

    ConnectionHandler handler_;

    // 连接管理
    std::map<int, std::shared_ptr<TcpConnection>> connections_;
    std::shared_mutex connections_mutex_;

    // 统计
    std::atomic<size_t> total_connections_{0};
    std::atomic<size_t> active_connections_{0};
    std::atomic<size_t> bytes_received_{0};
    std::atomic<size_t> bytes_sent_{0};

public:
    TcpServer(EventLoop& loop, const std::string& host, uint16_t port)
        : loop_(loop), host_(host), port_(port) {}

    ~TcpServer() {
        stop();
    }

    void set_handler(ConnectionHandler handler) {
        handler_ = std::move(handler);
    }

    void start() {
        listen_fd_ = create_listen_socket();

        // 注册accept回调
        loop_.add_reader(listen_fd_, [this]() {
            accept_connections();
        });

        std::cout << "Server listening on " << host_ << ":" << port_ << "\n";
    }

    void stop() {
        if (listen_fd_ >= 0) {
            loop_.remove(listen_fd_);
            ::close(listen_fd_);
            listen_fd_ = -1;
        }

        // 关闭所有连接
        std::unique_lock lock(connections_mutex_);
        for (auto& [fd, conn] : connections_) {
            conn->close();
        }
        connections_.clear();
    }

    struct Stats {
        size_t total_connections;
        size_t active_connections;
        size_t bytes_received;
        size_t bytes_sent;
    };

    Stats get_stats() const {
        return {
            total_connections_.load(),
            active_connections_.load(),
            bytes_received_.load(),
            bytes_sent_.load()
        };
    }

private:
    int create_listen_socket() {
        int fd = socket(AF_INET, SOCK_STREAM, 0);
        if (fd < 0) throw std::runtime_error("socket failed");

        // SO_REUSEADDR
        int opt = 1;
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

        // 非阻塞
        int flags = fcntl(fd, F_GETFL, 0);
        fcntl(fd, F_SETFL, flags | O_NONBLOCK);

        // 绑定
        struct sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = inet_addr(host_.c_str());
        addr.sin_port = htons(port_);

        if (bind(fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
            ::close(fd);
            throw std::runtime_error("bind failed");
        }

        if (listen(fd, SOMAXCONN) < 0) {
            ::close(fd);
            throw std::runtime_error("listen failed");
        }

        return fd;
    }

    void accept_connections() {
        while (true) {
            struct sockaddr_in client_addr{};
            socklen_t addr_len = sizeof(client_addr);

            int client_fd = accept4(listen_fd_,
                (struct sockaddr*)&client_addr, &addr_len,
                SOCK_NONBLOCK | SOCK_CLOEXEC);

            if (client_fd < 0) {
                if (errno == EAGAIN || errno == EWOULDBLOCK) break;
                continue;
            }

            std::string addr = inet_ntoa(client_addr.sin_addr);
            uint16_t port = ntohs(client_addr.sin_port);

            auto conn = std::make_shared<TcpConnection>(
                client_fd, loop_, addr, port);

            {
                std::unique_lock lock(connections_mutex_);
                connections_[client_fd] = conn;
            }

            ++total_connections_;
            ++active_connections_;

            // 启动连接处理协程
            if (handler_) {
                auto task = handler_(conn);
                task.start();
                // task完成后清理连接
            }
        }
    }
};
```

### Day 19-20：Echo Server + HTTP Server

#### 1. Echo Server

```cpp
// ============================================================
// Echo Server示例
// ============================================================

Task<void> echo_handler(std::shared_ptr<TcpConnection> conn) {
    std::cout << "New connection from "
              << conn->remote_address() << ":"
              << conn->remote_port() << "\n";

    while (true) {
        auto data = co_await conn->read(4096);
        if (data.empty()) {
            // 连接关闭
            break;
        }

        co_await conn->write(data);  // Echo回去
    }

    conn->close();
    std::cout << "Connection closed\n";
}

/*
int main() {
    EventLoop loop;
    TcpServer server(loop, "0.0.0.0", 8080);

    server.set_handler(echo_handler);
    server.start();

    loop.run();
    return 0;
}
*/
```

#### 2. 简单HTTP Server

```cpp
// ============================================================
// 简单HTTP/1.1 Server
// ============================================================

// HTTP请求解析
struct HttpRequest {
    std::string method;
    std::string path;
    std::string version;
    std::map<std::string, std::string> headers;
    std::string body;
};

// 简化的HTTP解析器
class HttpParser {
public:
    static std::optional<HttpRequest> parse(const std::string& raw) {
        HttpRequest req;

        // 查找请求行
        size_t line_end = raw.find("\r\n");
        if (line_end == std::string::npos) return std::nullopt;

        std::string request_line = raw.substr(0, line_end);
        auto parts = split(request_line, ' ');
        if (parts.size() < 3) return std::nullopt;

        req.method = parts[0];
        req.path = parts[1];
        req.version = parts[2];

        // 解析headers
        size_t pos = line_end + 2;
        while (pos < raw.size()) {
            size_t next_end = raw.find("\r\n", pos);
            if (next_end == std::string::npos) break;
            if (next_end == pos) break;  // 空行，headers结束

            std::string header_line = raw.substr(pos, next_end - pos);
            size_t colon = header_line.find(':');
            if (colon != std::string::npos) {
                std::string key = header_line.substr(0, colon);
                std::string value = header_line.substr(colon + 2);
                req.headers[key] = value;
            }
            pos = next_end + 2;
        }

        return req;
    }

private:
    static std::vector<std::string> split(const std::string& s, char delim) {
        std::vector<std::string> result;
        std::stringstream ss(s);
        std::string item;
        while (std::getline(ss, item, delim)) {
            result.push_back(item);
        }
        return result;
    }
};

// HTTP响应构建
class HttpResponse {
public:
    int status_code = 200;
    std::string status_text = "OK";
    std::map<std::string, std::string> headers;
    std::string body;

    std::string to_string() const {
        std::string result;
        result += "HTTP/1.1 " + std::to_string(status_code) + " " + status_text + "\r\n";
        for (const auto& [key, value] : headers) {
            result += key + ": " + value + "\r\n";
        }
        result += "Content-Length: " + std::to_string(body.size()) + "\r\n";
        result += "\r\n";
        result += body;
        return result;
    }
};

// HTTP连接处理
Task<void> http_handler(std::shared_ptr<TcpConnection> conn) {
    while (true) {
        // 读取请求
        std::string raw_request;
        while (true) {
            auto data = co_await conn->read(4096);
            if (data.empty()) {
                conn->close();
                co_return;
            }
            raw_request += data;
            if (raw_request.find("\r\n\r\n") != std::string::npos) {
                break;
            }
        }

        // 解析请求
        auto request = HttpParser::parse(raw_request);
        if (!request) {
            HttpResponse resp;
            resp.status_code = 400;
            resp.status_text = "Bad Request";
            resp.body = "Bad Request";
            co_await conn->write(resp.to_string());
            conn->close();
            co_return;
        }

        // 路由处理
        HttpResponse resp;
        if (request->path == "/") {
            resp.body = "<h1>ConcurrentServer</h1><p>High-performance server</p>";
            resp.headers["Content-Type"] = "text/html";
        } else if (request->path == "/stats") {
            resp.body = "{\"status\":\"ok\"}";
            resp.headers["Content-Type"] = "application/json";
        } else {
            resp.status_code = 404;
            resp.status_text = "Not Found";
            resp.body = "Not Found";
        }

        // 发送响应
        co_await conn->write(resp.to_string());

        // 检查Connection头
        auto conn_header = request->headers.find("Connection");
        if (conn_header != request->headers.end() &&
            conn_header->second == "close") {
            conn->close();
            co_return;
        }
    }
}

/*
int main() {
    EventLoop loop;
    TcpServer server(loop, "0.0.0.0", 8080);

    server.set_handler(http_handler);
    server.start();

    std::cout << "HTTP Server running on http://localhost:8080\n";
    loop.run();
    return 0;
}
*/
```

### Day 21：集成测试与Bug修复

#### 第三周检验标准

- [ ] I/O后端抽象支持epoll和kqueue
- [ ] EventLoop正确处理I/O事件、定时器和跨线程任务
- [ ] TCP连接支持协程化读写
- [ ] TCP服务器能接受并管理多个连接
- [ ] Echo Server功能正确
- [ ] HTTP Server能处理GET请求
- [ ] 通过基本的功能测试

---

## 第四周：测试、优化与Year 2总结（Day 22-28）

> **本周目标**：性能基准测试、优化、完成Year 2的知识总结

### Day 22-23：性能基准测试

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | 组件级基准测试 | 2h |
| 下午 | 服务器级基准测试 | 4h |
| 晚上 | 报告整理 | 2h |

#### 1. 线程池基准测试

```cpp
// ============================================================
// 线程池性能基准
// ============================================================

#include <chrono>
#include <iostream>
#include <iomanip>
#include <numeric>

struct BenchResult {
    std::string name;
    double total_time_ms;
    double throughput;  // ops/s
    double avg_latency_ns;
};

// 测试1：吞吐量
BenchResult bench_throughput(WorkStealingThreadPool& pool, size_t num_tasks) {
    std::atomic<size_t> completed{0};

    auto start = std::chrono::high_resolution_clock::now();

    std::vector<std::future<void>> futures;
    for (size_t i = 0; i < num_tasks; ++i) {
        futures.push_back(pool.submit([&completed] {
            ++completed;
        }));
    }

    for (auto& f : futures) f.get();

    auto end = std::chrono::high_resolution_clock::now();
    double ms = std::chrono::duration_cast<std::chrono::microseconds>(
        end - start).count() / 1000.0;

    return {"吞吐量测试", ms, num_tasks * 1000.0 / ms, ms * 1e6 / num_tasks};
}

// 测试2：延迟
BenchResult bench_latency(WorkStealingThreadPool& pool, size_t num_tasks) {
    std::vector<double> latencies;
    latencies.reserve(num_tasks);

    for (size_t i = 0; i < num_tasks; ++i) {
        auto start = std::chrono::high_resolution_clock::now();

        auto future = pool.submit([] {
            // 空任务，测量调度延迟
        });
        future.get();

        auto end = std::chrono::high_resolution_clock::now();
        latencies.push_back(
            std::chrono::duration_cast<std::chrono::nanoseconds>(end - start).count());
    }

    std::sort(latencies.begin(), latencies.end());
    double avg = std::accumulate(latencies.begin(), latencies.end(), 0.0) / num_tasks;
    double p50 = latencies[num_tasks / 2];
    double p99 = latencies[num_tasks * 99 / 100];

    std::cout << "延迟分布: avg=" << avg << "ns"
              << " p50=" << p50 << "ns"
              << " p99=" << p99 << "ns\n";

    return {"延迟测试", 0, 0, avg};
}

// 测试3：工作窃取效果
BenchResult bench_work_stealing(WorkStealingThreadPool& pool) {
    constexpr size_t NUM_TASKS = 100000;
    std::atomic<size_t> completed{0};

    auto start = std::chrono::high_resolution_clock::now();

    // 提交不均匀负载
    for (size_t i = 0; i < NUM_TASKS; ++i) {
        pool.submit([&completed, i] {
            // 模拟不均匀工作量
            volatile int x = 0;
            for (size_t j = 0; j < (i % 100) * 10; ++j) {
                ++x;
            }
            ++completed;
        });
    }

    while (completed.load() < NUM_TASKS) {
        std::this_thread::yield();
    }

    auto end = std::chrono::high_resolution_clock::now();
    double ms = std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count();

    auto stats = pool.get_stats();
    std::cout << "工作窃取次数: " << stats.tasks_stolen << "\n";

    return {"工作窃取测试", ms, NUM_TASKS * 1000.0 / ms, 0};
}
```

#### 2. 队列基准测试

```cpp
// ============================================================
// 无锁队列性能基准
// ============================================================

void bench_mpmc_queue() {
    std::cout << "\n=== MPMC Queue Benchmark ===\n\n";

    constexpr size_t CAPACITY = 65536;
    constexpr size_t OPS = 10000000;

    // 不同生产者/消费者组合
    struct Config {
        int producers, consumers;
    };

    Config configs[] = {
        {1, 1}, {2, 2}, {4, 4}, {8, 8}, {1, 4}, {4, 1}
    };

    for (auto [np, nc] : configs) {
        MPMCBoundedQueue<int> queue(CAPACITY);
        size_t ops_per_producer = OPS / np;

        std::atomic<size_t> consumed{0};

        auto start = std::chrono::high_resolution_clock::now();

        std::vector<std::thread> threads;

        // 生产者
        for (int i = 0; i < np; ++i) {
            threads.emplace_back([&queue, ops_per_producer] {
                for (size_t j = 0; j < ops_per_producer; ++j) {
                    while (!queue.push(static_cast<int>(j))) {
                        std::this_thread::yield();
                    }
                }
            });
        }

        // 消费者
        for (int i = 0; i < nc; ++i) {
            threads.emplace_back([&queue, &consumed, total = OPS] {
                int value;
                while (consumed.load(std::memory_order_relaxed) < total) {
                    if (queue.pop(value)) {
                        consumed.fetch_add(1, std::memory_order_relaxed);
                    } else {
                        std::this_thread::yield();
                    }
                }
            });
        }

        for (auto& t : threads) t.join();

        auto end = std::chrono::high_resolution_clock::now();
        double ms = std::chrono::duration_cast<std::chrono::milliseconds>(
            end - start).count();

        std::cout << np << "P/" << nc << "C: "
                  << std::fixed << std::setprecision(0)
                  << (OPS * 1000.0 / ms) << " ops/s"
                  << " (" << ms << " ms)\n";
    }
}

/*
典型结果：
┌────────────┬────────────────┬──────────┐
│  配置      │  吞吐(ops/s)   │  时间(ms)│
├────────────┼────────────────┼──────────┤
│  1P/1C     │  25,000,000    │  400     │
│  2P/2C     │  18,000,000    │  555     │
│  4P/4C     │  12,000,000    │  833     │
│  8P/8C     │   8,000,000    │  1250    │
│  1P/4C     │  20,000,000    │  500     │
│  4P/1C     │  15,000,000    │  666     │
└────────────┴────────────────┴──────────┘
*/
```

#### 3. 服务器基准测试

```cpp
// ============================================================
// 服务器性能基准（使用外部工具）
// ============================================================

/*
使用wrk进行HTTP压力测试：

# 基本测试
wrk -t4 -c100 -d30s http://localhost:8080/

# 高并发测试
wrk -t8 -c1000 -d30s http://localhost:8080/

# Echo Server使用自定义脚本
# echo_bench.lua:
# wrk.method = "POST"
# wrk.body   = "Hello World"

性能目标：
┌──────────────────────┬───────────────┬──────────────┐
│  测试               │  目标          │  实际        │
├──────────────────────┼───────────────┼──────────────┤
│  Echo QPS (100连接)  │  > 100K       │  TODO        │
│  Echo QPS (1K连接)   │  > 80K        │  TODO        │
│  HTTP QPS (100连接)  │  > 50K        │  TODO        │
│  HTTP QPS (1K连接)   │  > 30K        │  TODO        │
│  Echo P99 延迟       │  < 1ms        │  TODO        │
│  HTTP P99 延迟       │  < 5ms        │  TODO        │
│  最大连接数          │  > 10K        │  TODO        │
└──────────────────────┴───────────────┴──────────────┘
*/

// 内置简单压力测试
void bench_echo_server_internal() {
    // 创建多个客户端连接并发送数据
    constexpr int NUM_CLIENTS = 100;
    constexpr int MESSAGES_PER_CLIENT = 1000;
    constexpr size_t MESSAGE_SIZE = 64;

    std::atomic<size_t> total_messages{0};
    std::string message(MESSAGE_SIZE, 'A');

    auto start = std::chrono::high_resolution_clock::now();

    std::vector<std::thread> clients;
    for (int i = 0; i < NUM_CLIENTS; ++i) {
        clients.emplace_back([&]() {
            int fd = socket(AF_INET, SOCK_STREAM, 0);
            struct sockaddr_in addr{};
            addr.sin_family = AF_INET;
            addr.sin_addr.s_addr = inet_addr("127.0.0.1");
            addr.sin_port = htons(8080);

            if (connect(fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
                close(fd);
                return;
            }

            char recv_buf[256];
            for (int j = 0; j < MESSAGES_PER_CLIENT; ++j) {
                send(fd, message.c_str(), message.size(), 0);
                recv(fd, recv_buf, sizeof(recv_buf), 0);
                ++total_messages;
            }

            close(fd);
        });
    }

    for (auto& t : clients) t.join();

    auto end = std::chrono::high_resolution_clock::now();
    double ms = std::chrono::duration_cast<std::chrono::milliseconds>(
        end - start).count();

    double qps = total_messages.load() * 1000.0 / ms;
    std::cout << "Echo Server: " << std::fixed << std::setprecision(0)
              << qps << " QPS"
              << " (" << total_messages.load() << " messages in " << ms << " ms)\n";
}
```

### Day 24-25：性能优化

#### 优化清单

```cpp
// ============================================================
// 性能优化策略
// ============================================================

/*
优化优先级（从高到低）：

1. 算法优化
   • 减少不必要的内存分配
   • 批量处理I/O事件
   • 使用对象池避免频繁new/delete

2. 系统调用优化
   • 减少系统调用次数（批量writev）
   • 使用accept4代替accept+fcntl
   • TCP_NODELAY减少延迟

3. 内存布局优化
   • 缓存行对齐关键数据
   • 避免伪共享
   • 使用连续内存（SoA vs AoS）

4. 锁优化
   • 减少锁粒度
   • 使用无锁数据结构
   • 线程本地缓存

优化工具：
• perf stat: CPU计数器
• perf record + perf report: 采样分析
• valgrind --tool=cachegrind: 缓存分析
• TSan: 线程安全检查
*/

// 示例：对象池优化
template<typename T>
class ObjectPool {
    struct Block {
        T object;
        Block* next;
    };

    std::mutex mutex_;
    Block* free_list_ = nullptr;
    std::vector<std::unique_ptr<Block[]>> chunks_;
    size_t chunk_size_;

public:
    explicit ObjectPool(size_t chunk_size = 64) : chunk_size_(chunk_size) {
        allocate_chunk();
    }

    T* acquire() {
        std::lock_guard<std::mutex> lock(mutex_);
        if (!free_list_) {
            allocate_chunk();
        }
        Block* block = free_list_;
        free_list_ = block->next;
        return &block->object;
    }

    void release(T* ptr) {
        Block* block = reinterpret_cast<Block*>(
            reinterpret_cast<char*>(ptr) - offsetof(Block, object));
        std::lock_guard<std::mutex> lock(mutex_);
        block->next = free_list_;
        free_list_ = block;
    }

private:
    void allocate_chunk() {
        auto chunk = std::make_unique<Block[]>(chunk_size_);
        for (size_t i = 0; i < chunk_size_ - 1; ++i) {
            chunk[i].next = &chunk[i + 1];
        }
        chunk[chunk_size_ - 1].next = free_list_;
        free_list_ = &chunk[0];
        chunks_.push_back(std::move(chunk));
    }
};

// TCP优化设置
void optimize_tcp_socket(int fd) {
    // 关闭Nagle算法（减少延迟）
    int nodelay = 1;
    setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &nodelay, sizeof(nodelay));

    // 发送缓冲区
    int sndbuf = 65536;
    setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &sndbuf, sizeof(sndbuf));

    // 接收缓冲区
    int rcvbuf = 65536;
    setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &rcvbuf, sizeof(rcvbuf));

    // SO_REUSEPORT（Linux，多线程accept）
    #ifdef SO_REUSEPORT
    int reuseport = 1;
    setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &reuseport, sizeof(reuseport));
    #endif
}
```

### Day 26-27：Year 2 知识总结

#### 1. 并发编程面试题精选（50题）

```cpp
// ============================================================
// 并发编程面试题精选
// ============================================================

/*
--- 基础概念（10题）---

Q1: 进程和线程的区别？
A: 进程是资源分配单位，有独立的地址空间。
   线程是调度单位，共享进程的地址空间。

Q2: 用户态线程和内核态线程的区别？
A: 内核态线程由OS调度，可以利用多核。
   用户态线程由程序调度，切换快但不能利用多核。
   C++20协程是用户态的。

Q3: 什么是数据竞争（Data Race）？
A: 两个线程同时访问同一内存位置，至少一个是写操作，
   且没有同步机制。这是未定义行为。

Q4: 死锁的四个必要条件？
A: 互斥、持有并等待、非抢占、循环等待。

Q5: mutex和spinlock的区别？何时用哪个？
A: mutex在竞争时线程睡眠（系统调用开销）。
   spinlock在竞争时忙等待（消耗CPU）。
   临界区短(<1us)用spinlock，否则用mutex。

Q6: condition_variable为什么必须和mutex配合使用？
A: 避免lost wakeup：如果notify在wait之前发生，
   没有mutex保护的话信号会丢失。

Q7: 什么是虚假唤醒？如何防护？
A: 条件变量可能在条件未满足时唤醒线程。
   使用while循环或带谓词的wait防护。

Q8: std::atomic和volatile的区别？
A: atomic保证原子性和内存序。
   volatile只防止编译器优化，不保证原子性或线程安全。

Q9: 什么是memory order？为什么需要它？
A: 编译器和CPU可能重排指令。memory order限定这种重排，
   保证多线程间的可见性和顺序性。

Q10: acquire和release语义分别是什么？
A: acquire：后续读写不会被重排到此操作之前（读屏障）。
   release：之前的读写不会被重排到此操作之后（写屏障）。

--- 无锁编程（10题）---

Q11: 什么是CAS？它的局限性？
A: Compare-And-Swap，原子地比较并修改。
   局限：ABA问题、只能操作单个字、活锁。

Q12: 什么是ABA问题？如何解决？
A: 值从A变B再变A，CAS无法检测。
   解决：带版本号指针、Hazard Pointers、Epoch-based。

Q13: lock-free和wait-free的区别？
A: lock-free：至少一个线程在有限步内完成（可能有线程饿死）。
   wait-free：每个线程在有限步内完成（更强保证）。

Q14: 无锁栈的push操作是如何工作的？
A: 创建新节点→读取当前head→设置新节点next为head→
   CAS(head, expected, new_node)，失败则重试。

Q15: SPSC队列为什么不需要CAS？
A: 只有一个生产者写tail，一个消费者读head，
   没有竞争，只需正确的内存序保证可见性。

Q16: Hazard Pointers的核心思想？
A: 每个线程声明正在使用的指针（hazard pointer），
   回收前检查没有线程在使用该指针。

Q17: Epoch-based回收如何工作？
A: 全局epoch递增，线程进入临界区时记录当前epoch，
   回收两个epoch之前的对象（确保没有线程还在使用）。

Q18: 为什么无锁编程中内存回收是核心难题？
A: 线程A准备读取数据时，线程B可能已经释放了该数据。
   需要安全的延迟回收机制。

Q19: 伪共享是什么？如何避免？
A: 不同线程修改同一缓存行的不同变量。
   避免：对齐到缓存行大小（64字节）。

Q20: 什么是memory fence？
A: 内存屏障，阻止特定方向的内存操作重排。
   full fence = acquire + release。

--- 高级并发（10题）---

Q21: 线程池的工作窃取如何实现？
A: 每个线程有本地deque，空闲时从其他线程的deque顶端窃取。
   本地操作LIFO（缓存友好），窃取FIFO。

Q22: Actor模型的核心特点？
A: 无共享状态、消息传递通信、单线程处理消息、
   location transparency、"Let it crash"容错。

Q23: Future和协程的区别？
A: Future是结果的占位符，get()阻塞。
   协程可以暂停/恢复，co_await不阻塞线程。

Q24: C++20协程的三要素？
A: Promise Type（控制协程行为）、Awaitable（控制暂停恢复）、
   Coroutine Handle（管理生命周期）。

Q25: co_await的执行流程？
A: 调用await_ready()→如果false→调用await_suspend()暂停→
   将来resume时→调用await_resume()返回结果。

Q26: EventLoop的工作原理？
A: 循环：等待I/O事件→处理就绪事件→处理定时器→处理异步任务。
   底层使用epoll/kqueue实现高效等待。

Q27: Reactor和Proactor模式的区别？
A: Reactor：通知I/O就绪，应用执行I/O。
   Proactor：OS执行I/O，完成后通知应用。

Q28: 如何选择线程数？
A: CPU密集型：线程数 = CPU核数。
   I/O密集型：线程数 = CPU核数 × (1 + 等待时间/计算时间)。

Q29: 读写锁什么时候比mutex更好？
A: 读写比 > 70:30，且读操作持有时间较长。
   读写比低时shared_mutex开销反而更大。

Q30: Channel和消息队列的区别？
A: Channel通常在进程内，类型安全，零拷贝。
   消息队列跨进程/网络，需要序列化。

--- 调试与优化（10题）---

Q31: 如何检测死锁？
A: 使用TSan、GDB info threads、构建锁图检测环。

Q32: ThreadSanitizer能检测什么？
A: 数据竞争、死锁、锁顺序违规。不能检测逻辑错误。

Q33: 如何分析锁竞争？
A: perf lock、Intel VTune、自定义带统计的锁。

Q34: 如何优化缓存性能？
A: 数据局部性（SoA vs AoS）、预取、减少间接寻址、对齐。

Q35: 什么是false sharing？性能影响多大？
A: 不同线程修改同一缓存行。影响可达10-20倍。

Q36: 如何做并发程序的性能测试？
A: 控制变量、多次运行取统计值、考虑预热、使用专用核。

Q37: 什么是lock convoy？
A: 多个线程依次获取同一把锁，导致所有线程串行执行。

Q38: 什么是priority inversion？如何解决？
A: 高优先级线程等待低优先级线程释放锁。
   解决：优先级继承、优先级天花板。

Q39: 如何做graceful shutdown？
A: 设置停止标志→唤醒所有等待线程→等待任务完成→释放资源。

Q40: memory_order_seq_cst的开销为什么大？
A: 需要在所有核之间维护全局操作顺序，
   在x86上store需要MFENCE指令，ARM/POWER更明显。

--- 设计与架构（10题）---

Q41: 如何设计一个线程安全的缓存？
A: 分段锁HashMap + 读写锁 + LRU淘汰。
   高频读用RCU，数据量大用分段锁。

Q42: 如何设计高性能日志系统？
A: 前端无锁写入缓冲区，后端线程异步刷盘。
   使用双缓冲减少竞争。

Q43: 如何处理10K并发连接？
A: 使用epoll/kqueue + 协程/事件驱动。
   避免每连接一线程的模型。

Q44: 数据库连接池如何设计？
A: 有界阻塞队列 + 超时机制 + 健康检查。
   返回RAII包装的连接。

Q45: 如何设计分布式锁？
A: Redis SETNX + 过期时间 + Lua脚本原子操作。
   更可靠：Redlock或ZooKeeper。

Q46: 什么时候用消息传递，什么时候用共享内存？
A: 消息传递：需要解耦、跨网络、安全性优先。
   共享内存：低延迟、高吞吐、进程内通信。

Q47: 如何设计限流器（Rate Limiter）？
A: 令牌桶或漏桶算法。
   分布式用Redis + Lua脚本。

Q48: 如何设计一个任务调度器？
A: DAG依赖图 + 拓扑排序 + 线程池执行。
   支持优先级和取消。

Q49: 微服务间通信应该选什么方案？
A: 同步：gRPC。异步：消息队列（Kafka）。
   内部服务：gRPC双向流。

Q50: Year 2学习给你最大的收获是什么？
A: （开放题）建议从以下角度回答：
   1. 理解了"正确性第一，性能第二"
   2. 学会了系统性地分析并发问题
   3. 掌握了从场景出发选择方案的能力
*/
```

#### 2. Year 3 学习规划

```
// ============================================================
// Year 3: 高性能网络、I/O与异步架构
// ============================================================

/*
┌────────────────────────────────────────────────────────────────────────────┐
│                    Year 3 学习路线图                                        │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  Quarter 1: 网络编程基础 (Month 25-27)                                    │
│  ┌─────────────┬─────────────┬─────────────┐                             │
│  │ Month 25    │ Month 26    │ Month 27    │                             │
│  │ TCP/UDP     │ 非阻塞I/O  │ I/O多路复用 │                             │
│  │ Socket编程  │ select/poll │ epoll深度   │                             │
│  └─────────────┴─────────────┴─────────────┘                             │
│                                                                            │
│  Quarter 2: 现代I/O技术 (Month 28-30)                                    │
│  ┌─────────────┬─────────────┬─────────────┐                             │
│  │ Month 28    │ Month 29    │ Month 30    │                             │
│  │ io_uring    │ 零拷贝技术  │ 用户态网络  │                             │
│  │ 深度学习    │ sendfile    │ DPDK概念    │                             │
│  └─────────────┴─────────────┴─────────────┘                             │
│                                                                            │
│  Quarter 3: 网络架构模式 (Month 31-33)                                   │
│  ┌─────────────┬─────────────┬─────────────┐                             │
│  │ Month 31    │ Month 32    │ Month 33    │                             │
│  │ Reactor模式 │ Proactor    │ 架构分析    │                             │
│  │ 深度实现    │ 模式        │ Envoy/Nginx │                             │
│  └─────────────┴─────────────┴─────────────┘                             │
│                                                                            │
│  Quarter 4: 实战项目 (Month 34-36)                                       │
│  ┌─────────────┬─────────────┬─────────────┐                             │
│  │ Month 34    │ Month 35    │ Month 36    │                             │
│  │ HTTP服务器  │ RPC框架     │ 综合项目    │                             │
│  │ 完整实现    │ 实现        │ & 总结      │                             │
│  └─────────────┴─────────────┴─────────────┘                             │
│                                                                            │
│  Year 2 → Year 3 的知识衔接：                                            │
│  • 线程池 → 网络工作线程                                                  │
│  • 协程 → 协程化网络I/O                                                   │
│  • EventLoop → Reactor/Proactor                                           │
│  • 无锁队列 → 高性能消息传递                                              │
│  • 性能分析 → 网络性能调优                                                │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
*/
```

### Day 28：项目收尾与展望

#### 第四周检验标准

- [ ] 线程池基准测试：吞吐量 > 1M ops/s
- [ ] MPMC队列基准测试通过
- [ ] Echo Server QPS > 100K（目标）
- [ ] 使用perf或其他工具完成性能分析
- [ ] 完成性能优化（至少3项）
- [ ] 完成50道面试题回顾
- [ ] 理解Year 3学习路线
- [ ] 生成完整性能报告

---

## 本月检验标准汇总

### 理论知识（15项）

| 编号 | 检验项 | 对应内容 |
|------|--------|----------|
| T-1 | 能回答Month 13-15基础层自测题 | Week 1 |
| T-2 | 能回答Month 16-17无锁编程自测题 | Week 1 |
| T-3 | 能回答Month 18-20高级并发自测题 | Week 1 |
| T-4 | 能回答Month 21-23协程/决策自测题 | Week 1 |
| T-5 | 能解释综合项目的技术选型依据 | Week 1 |
| T-6 | 理解Chase-Lev Deque的并发正确性 | Week 2 |
| T-7 | 理解MPMC队列的sequence设计 | Week 2 |
| T-8 | 理解协程Task的final_suspend设计 | Week 2 |
| T-9 | 理解epoll边沿触发vs水平触发 | Week 3 |
| T-10 | 理解TCP socket优化选项 | Week 3 |
| T-11 | 能分析性能基准测试结果 | Week 4 |
| T-12 | 能解释各组件的性能瓶颈 | Week 4 |
| T-13 | 能回答50道面试题中的40道 | Week 4 |
| T-14 | 理解Year 2→Year 3的知识衔接 | Week 4 |
| T-15 | 能总结Year 2的核心收获 | Week 4 |

### 实践能力（15项）

| 编号 | 检验项 | 对应内容 |
|------|--------|----------|
| P-1 | 完成项目架构设计文档 | Week 1 |
| P-2 | 搭建CMake项目骨架 | Week 1 |
| P-3 | 实现Chase-Lev Work-Stealing Deque | Week 2 |
| P-4 | 实现工作窃取线程池 | Week 2 |
| P-5 | 实现MPMC无锁有界队列 | Week 2 |
| P-6 | 实现协程Task（含void特化） | Week 2 |
| P-7 | 实现协程Channel | Week 2 |
| P-8 | 实现跨平台I/O后端 | Week 3 |
| P-9 | 实现EventLoop | Week 3 |
| P-10 | 实现异步TCP连接 | Week 3 |
| P-11 | 实现TCP服务器框架 | Week 3 |
| P-12 | 实现Echo Server | Week 3 |
| P-13 | 实现HTTP Server | Week 3 |
| P-14 | 完成性能基准测试套件 | Week 4 |
| P-15 | 完成性能优化并生成报告 | Week 4 |

### 综合项目交付物

| 编号 | 交付物 | 状态 |
|------|--------|------|
| D-1 | 架构设计文档 (architecture.md) | □ |
| D-2 | 核心并发库 (concurrent_core) | □ |
| D-3 | 异步I/O库 (concurrent_io) | □ |
| D-4 | 服务器框架 (concurrent_server) | □ |
| D-5 | Echo Server示例 | □ |
| D-6 | HTTP Server示例 | □ |
| D-7 | 基准测试套件 | □ |
| D-8 | 性能报告 (performance_report.md) | □ |
| D-9 | Year 2总结文档 (year2_summary.md) | □ |
| D-10 | 面试题汇编 | □ |

---

## 输出物清单

### 项目代码

```
concurrent_server/
├── CMakeLists.txt
├── include/
│   ├── core/
│   │   ├── thread_pool.hpp
│   │   ├── work_stealing_deque.hpp
│   │   ├── mpmc_queue.hpp
│   │   ├── spsc_queue.hpp
│   │   ├── task.hpp
│   │   ├── channel.hpp
│   │   └── epoch_reclamation.hpp
│   ├── io/
│   │   ├── event_loop.hpp
│   │   ├── io_backend.hpp
│   │   ├── async_socket.hpp
│   │   └── timer.hpp
│   ├── server/
│   │   ├── tcp_server.hpp
│   │   ├── tcp_connection.hpp
│   │   ├── connection_manager.hpp
│   │   └── http_parser.hpp
│   └── utils/
│       ├── noncopyable.hpp
│       ├── object_pool.hpp
│       └── stats.hpp
├── src/
├── examples/
│   ├── echo_server.cpp
│   └── http_server.cpp
├── benchmarks/
│   ├── bench_thread_pool.cpp
│   ├── bench_queue.cpp
│   └── bench_server.cpp
├── tests/
└── docs/
    ├── architecture.md
    ├── performance_report.md
    └── year2_summary.md
```

### 文档产出

| 文档 | 内容 |
|------|------|
| architecture.md | 架构设计、组件依赖、接口定义 |
| performance_report.md | 基准测试结果、优化记录、对比分析 |
| year2_summary.md | Month 13-24知识图谱、最佳实践、面试题 |

---

## 结语

```
┌────────────────────────────────────────────────────────────────────────────┐
│                                                                            │
│  恭喜你完成了 Year 2: 内存模型与并发编程！                                 │
│                                                                            │
│  这一年你掌握了：                                                          │
│                                                                            │
│  ✓ C++内存模型 —— 理解硬件与语言之间的契约                                │
│  ✓ 原子操作与CAS —— 无锁编程的基石                                       │
│  ✓ 无锁数据结构 —— 高性能并发的核心                                       │
│  ✓ 内存回收技术 —— 安全的无锁编程                                         │
│  ✓ 线程池与工作窃取 —— 任务调度的最佳实践                                  │
│  ✓ Actor模型 —— 消息传递并发                                              │
│  ✓ C++20协程 —— 现代异步编程范式                                          │
│  ✓ 异步I/O —— 高性能服务器基础                                            │
│  ✓ 并发模式决策 —— 从场景到方案的系统方法                                  │
│                                                                            │
│  这些知识让你能够：                                                        │
│  • 编写正确的多线程代码                                                    │
│  • 设计高性能并发系统                                                      │
│  • 分析和解决并发Bug                                                       │
│  • 做出合理的并发架构决策                                                  │
│                                                                            │
│  Year 3 我们将进入网络编程领域，                                           │
│  将并发能力应用于构建高性能网络服务！                                       │
│                                                                            │
│  下一步：休息一周，然后开始 Month 25 的网络编程学习！                       │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```