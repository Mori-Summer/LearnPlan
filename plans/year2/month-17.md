# Month 17: 无锁队列——并发数据结构的核心

## 本月主题概述

无锁队列是最实用的无锁数据结构，广泛应用于生产者-消费者模式、消息传递系统和任务调度。本月将深入学习Michael-Scott队列、MPSC/SPSC队列等经典实现。

---

## 理论学习内容

### 第一周：队列的并发问题

**学习目标**：理解并发队列的设计挑战

**阅读材料**：
- [ ] 论文："Simple, Fast, and Practical Non-Blocking and Blocking Concurrent Queue Algorithms"
- [ ] 《The Art of Multiprocessor Programming》队列章节
- [ ] folly::ProducerConsumerQueue源码

**核心概念**：

#### 队列操作的原子性挑战
```cpp
// 单链表队列的问题
template <typename T>
class NaiveQueue {
    struct Node {
        T data;
        Node* next;
    };
    Node* head_;  // 出队端
    Node* tail_;  // 入队端

    void enqueue(T value) {
        Node* new_node = new Node{value, nullptr};
        tail_->next = new_node;  // (1)
        tail_ = new_node;        // (2)
        // (1)和(2)不是原子的！
    }

    T dequeue() {
        Node* old_head = head_;
        head_ = head_->next;  // (3)
        T result = head_->data;
        delete old_head;
        return result;
        // 多个线程可能同时执行(3)
    }
};
```

---

### 第一周扩展内容

#### 每日学习安排

**Day 1: 队列并发问题概念建立（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 阅读《The Art of Multiprocessor Programming》队列章节 | 2h |
| 理论 | 理解队列FIFO语义在并发环境下的挑战 | 1h |
| 实践 | 手写NaiveQueue代码，分析竞态条件 | 1.5h |
| 复习 | 绘制并发队列的状态转换图 | 0.5h |

**Day 2: 两阶段操作问题深度分析（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 分析enqueue的"链接-更新"两阶段问题 | 1.5h |
| 理论 | 分析dequeue的"读取-移除"两阶段问题 | 1.5h |
| 实践 | 编写能复现竞态条件的测试用例 | 1.5h |
| 复习 | 总结并发队列的四种竞态场景 | 0.5h |

**Day 3: 线性化点分析（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 学习线性化（Linearizability）概念 | 1.5h |
| 理论 | 分析队列操作的线性化点定义 | 1.5h |
| 实践 | 为NaiveQueue添加锁实现正确性 | 1.5h |
| 复习 | 对比锁实现与无锁实现的权衡 | 0.5h |

**Day 4: 论文精读（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 精读MS队列论文第1-3节（问题背景） | 2.5h |
| 理论 | 理解论文中的形式化证明方法 | 1.5h |
| 复习 | 整理论文核心观点和算法框架 | 1h |

**Day 5: 生产者-消费者模式分析（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 学习生产者-消费者模式的变体 | 1h |
| 理论 | 分析SPSC/MPSC/SPMC/MPMC场景 | 1.5h |
| 实践 | 实现基于条件变量的阻塞队列 | 2h |
| 复习 | 总结不同场景的最优队列选择 | 0.5h |

**Day 6: folly::ProducerConsumerQueue源码阅读（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 实践 | 下载并阅读folly::ProducerConsumerQueue | 2.5h |
| 理论 | 分析Facebook的设计决策和优化技巧 | 1.5h |
| 复习 | 整理源码中的关键技术点 | 1h |

**Day 7: 周总结与实战（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 复习 | 回顾本周所有概念，查漏补缺 | 1h |
| 实践 | 实现带有详细注释的LockedQueue | 2.5h |
| 测试 | 完成知识检验题 | 1h |
| 总结 | 撰写学习笔记 | 0.5h |

---

#### 扩展阅读资源

**必读（优先级：高）**
- [ ] 论文：[Simple, Fast, and Practical Non-Blocking and Blocking Concurrent Queue Algorithms](https://www.cs.rochester.edu/~scott/papers/1996_PODC_queues.pdf) - Michael & Scott (PODC 1996)
- [ ] 书籍：《The Art of Multiprocessor Programming》Chapter 10: Concurrent Queues
- [ ] 源码：[folly::ProducerConsumerQueue](https://github.com/facebook/folly/blob/main/folly/ProducerConsumerQueue.h)

**推荐阅读（优先级：中）**
- [ ] CppCon 2017：[Fedor Pikus - C++ atomics, from basic to advanced](https://www.youtube.com/watch?v=ZQFzMfHIxng)
- [ ] 博客：[1024cores - Lock-Free Multi-Producer Multi-Consumer Queue on Ring Buffer](http://www.1024cores.net/home/lock-free-algorithms/queues/bounded-mpmc-queue)
- [ ] 论文：[Nonblocking Algorithms and Scalable Multicore Programming](https://queue.acm.org/detail.cfm?id=2492433)

**深入研究（优先级：低）**
- [ ] 论文：[Fast Concurrent Queues for x86 Processors](https://www.cs.tau.ac.il/~mad/publications/ppopp2013-x86queues.pdf)
- [ ] Linux内核：[kfifo实现](https://github.com/torvalds/linux/blob/master/include/linux/kfifo.h)

---

#### 工程实践深度解析

**并发队列问题的诊断技巧**

```cpp
// 技巧1: 添加序列号追踪元素顺序
template <typename T>
class DiagnosticQueue {
    struct Node {
        T data;
        uint64_t sequence_num;  // 入队序列号
        std::atomic<Node*> next{nullptr};

        Node(T d, uint64_t seq) : data(std::move(d)), sequence_num(seq) {}
    };

    std::atomic<uint64_t> enqueue_counter_{0};
    std::atomic<uint64_t> dequeue_counter_{0};

public:
    void enqueue(T value) {
        uint64_t seq = enqueue_counter_.fetch_add(1, std::memory_order_relaxed);
        Node* node = new Node(std::move(value), seq);
        // ... 入队逻辑
        std::cout << "[ENQ] seq=" << seq << " thread="
                  << std::this_thread::get_id() << std::endl;
    }

    std::optional<T> dequeue() {
        // ... 出队逻辑
        if (success) {
            uint64_t expected_seq = dequeue_counter_.fetch_add(1);
            if (node->sequence_num != expected_seq) {
                std::cerr << "[ERROR] FIFO violation! expected=" << expected_seq
                          << " got=" << node->sequence_num << std::endl;
            }
        }
        return result;
    }
};

// 技巧2: 使用延迟注入暴露竞态条件
template <typename T>
class RaceDetectionQueue {
    void enqueue_with_delay(T value) {
        Node* new_node = new Node(std::move(value));
        Node* tail = tail_.load();

        // 在关键操作间注入随机延迟
        if (rand() % 100 < 10) {  // 10%概率
            std::this_thread::sleep_for(std::chrono::microseconds(rand() % 100));
        }

        tail->next.store(new_node);

        // 再次注入延迟
        if (rand() % 100 < 10) {
            std::this_thread::sleep_for(std::chrono::microseconds(rand() % 100));
        }

        tail_.store(new_node);
    }
};
```

**队列正确性验证框架**

```cpp
// FIFO正确性验证
template <typename Queue>
class QueueValidator {
    Queue& queue_;
    std::vector<std::vector<int>> produced_;  // 每个生产者产生的值
    std::vector<std::vector<int>> consumed_;  // 每个消费者消费的值
    std::atomic<bool> running_{true};

public:
    void producer(int id, int count) {
        for (int i = 0; i < count; ++i) {
            int value = id * 1000000 + i;  // 编码生产者ID和序号
            while (!queue_.try_push(value)) {
                std::this_thread::yield();
            }
            produced_[id].push_back(value);
        }
    }

    void consumer(int id) {
        while (running_ || !queue_.empty()) {
            auto value = queue_.try_pop();
            if (value) {
                consumed_[id].push_back(*value);
            }
        }
    }

    bool verify_fifo() {
        // 对于每个生产者，验证其元素被消费的相对顺序
        for (int p = 0; p < produced_.size(); ++p) {
            std::vector<int> consumed_from_p;
            for (auto& consumer_values : consumed_) {
                for (int v : consumer_values) {
                    if (v / 1000000 == p) {
                        consumed_from_p.push_back(v);
                    }
                }
            }
            // 验证顺序
            if (!std::is_sorted(consumed_from_p.begin(), consumed_from_p.end())) {
                std::cerr << "FIFO violation for producer " << p << std::endl;
                return false;
            }
        }
        return true;
    }
};
```

---

#### 知识检验题

1. **概念理解**：解释为什么简单的双指针队列（head和tail）在多线程环境下会失败？列举至少三种可能的竞态条件。

2. **线性化分析**：对于一个并发队列，enqueue操作的线性化点应该在哪里？dequeue呢？为什么？

3. **场景选择**：在以下场景中，你会选择什么类型的队列？说明理由：
   - 日志收集系统（多个线程写日志，单个线程flush到磁盘）
   - 线程池任务分发（单个调度器，多个工作线程）
   - 高频交易订单簿（多个交易引擎，多个撮合引擎）

4. **代码分析**：分析folly::ProducerConsumerQueue中`alignas(hardware_destructive_interference_size)`的作用，它解决什么问题？

---

### 第二周：Michael-Scott Queue

**学习目标**：掌握经典的无锁队列算法

```cpp
// michael_scott_queue.hpp
#pragma once
#include <atomic>
#include <optional>
#include "hazard_pointer.hpp"

template <typename T>
class MSQueue {
    struct Node {
        T data;
        std::atomic<Node*> next{nullptr};

        Node() = default;
        Node(T d) : data(std::move(d)) {}
    };

    std::atomic<Node*> head_;
    std::atomic<Node*> tail_;
    HazardPointerDomain hp_domain_;

public:
    MSQueue() {
        Node* dummy = new Node();
        head_.store(dummy);
        tail_.store(dummy);
    }

    ~MSQueue() {
        while (dequeue()) {}
        delete head_.load();
    }

    void enqueue(T value) {
        Node* new_node = new Node(std::move(value));
        HazardPointerDomain::HazardPointerHolder hp;

        while (true) {
            Node* tail = hp.protect(tail_, hp_domain_);
            Node* next = tail->next.load(std::memory_order_acquire);

            if (tail == tail_.load(std::memory_order_acquire)) {
                if (next == nullptr) {
                    // tail确实是最后一个节点，尝试添加新节点
                    if (tail->next.compare_exchange_weak(next, new_node,
                            std::memory_order_release,
                            std::memory_order_relaxed)) {
                        // 成功添加，尝试更新tail（失败也没关系）
                        tail_.compare_exchange_strong(tail, new_node,
                            std::memory_order_release,
                            std::memory_order_relaxed);
                        return;
                    }
                } else {
                    // tail落后了，帮助推进
                    tail_.compare_exchange_strong(tail, next,
                        std::memory_order_release,
                        std::memory_order_relaxed);
                }
            }
        }
    }

    std::optional<T> dequeue() {
        HazardPointerDomain::HazardPointerHolder hp1, hp2;

        while (true) {
            Node* head = hp1.protect(head_, hp_domain_);
            Node* tail = tail_.load(std::memory_order_acquire);
            Node* next = hp2.protect(head->next, hp_domain_);

            if (head == head_.load(std::memory_order_acquire)) {
                if (head == tail) {
                    if (next == nullptr) {
                        return std::nullopt;  // 队列为空
                    }
                    // tail落后了，帮助推进
                    tail_.compare_exchange_strong(tail, next,
                        std::memory_order_release,
                        std::memory_order_relaxed);
                } else {
                    // 读取数据并尝试移动head
                    T result = next->data;
                    if (head_.compare_exchange_weak(head, next,
                            std::memory_order_release,
                            std::memory_order_relaxed)) {
                        hp_domain_.retire(head);
                        return result;
                    }
                }
            }
        }
    }
};
```

---

### 第二周扩展内容

#### 每日学习安排

**Day 1: MS队列算法原理（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 精读MS队列论文算法描述部分 | 2h |
| 理论 | 理解dummy node的作用 | 1h |
| 实践 | 手绘MS队列状态转换图 | 1.5h |
| 复习 | 整理算法的关键不变式 | 0.5h |

**Day 2: 帮助机制深度分析（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 分析enqueue中的"帮助推进tail"机制 | 1.5h |
| 理论 | 分析dequeue中的"帮助推进tail"机制 | 1.5h |
| 实践 | 编写测试验证帮助机制的触发 | 1.5h |
| 复习 | 总结无锁帮助机制的设计原则 | 0.5h |

**Day 3: CAS操作顺序分析（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 分析enqueue的两次CAS为什么必须按特定顺序 | 1.5h |
| 理论 | 分析memory_order的选择依据 | 1.5h |
| 实践 | 尝试错误的memory_order，观察问题 | 1.5h |
| 复习 | 整理MS队列的内存序要求 | 0.5h |

**Day 4: 内存回收问题（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 复习Month 16的Hazard Pointer知识 | 1h |
| 理论 | 分析MS队列中HP的使用位置 | 1.5h |
| 实践 | 实现无HP保护版本，用ASan验证问题 | 2h |
| 复习 | 总结何时需要HP保护 | 0.5h |

**Day 5: 正确性证明学习（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 学习论文中的正确性证明方法 | 2.5h |
| 理论 | 理解线性化证明的关键步骤 | 1.5h |
| 复习 | 尝试自己证明简化版本的正确性 | 1h |

**Day 6: 性能优化技术（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 学习MS队列的性能瓶颈分析 | 1.5h |
| 实践 | 实现并测试基础版MS队列 | 2.5h |
| 实践 | 使用perf分析热点 | 0.5h |
| 复习 | 记录性能基准数据 | 0.5h |

**Day 7: 周总结与实战（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 复习 | 回顾MS队列所有细节 | 1h |
| 实践 | 完成完整的MS队列实现和测试 | 2.5h |
| 测试 | 完成知识检验题 | 1h |
| 总结 | 撰写学习笔记 | 0.5h |

---

#### 扩展阅读资源

**必读（优先级：高）**
- [ ] 论文原文：[Simple, Fast, and Practical Non-Blocking and Blocking Concurrent Queue Algorithms](https://www.cs.rochester.edu/~scott/papers/1996_PODC_queues.pdf) - 完整阅读
- [ ] 视频：[CppCon 2017: Fedor Pikus "C++ atomics, from basic to advanced"](https://www.youtube.com/watch?v=ZQFzMfHIxng) - 关于无锁队列的部分
- [ ] libcds源码：[MSQueue实现](https://github.com/khizmax/libcds/blob/master/cds/intrusive/msqueue.h)

**推荐阅读（优先级：中）**
- [ ] 博客：[Preshing - A Lock-Free Multi-Producer Multi-Consumer Queue](https://moodycamel.com/blog/2014/a-fast-general-purpose-lock-free-queue-for-c++)
- [ ] 论文：[An Optimistic Approach to Lock-Free FIFO Queues](https://people.csail.mit.edu/shanir/publications/Lock_Free.pdf)
- [ ] Boost.Lockfree：[queue实现](https://www.boost.org/doc/libs/1_82_0/doc/html/lockfree.html)

**深入研究（优先级：低）**
- [ ] 论文：[A Scalable Lock-free Stack Algorithm](https://people.csail.mit.edu/shanir/publications/Lock_Free.pdf)
- [ ] 论文：[Obstruction-Free Synchronization: Double-Ended Queues](https://www.cs.tau.ac.il/~shanir/nir-pubs-web/Papers/Lock_Free.pdf)

---

#### 工程实践深度解析

**MS队列的关键状态分析**

```cpp
// MS队列的五种关键状态
// 状态1: 初始状态（只有dummy node）
//        head -> [dummy] <- tail
//                  |
//                nullptr

// 状态2: 正常状态（有多个元素）
//        head -> [dummy] -> [A] -> [B] -> [C] <- tail
//                                          |
//                                       nullptr

// 状态3: enqueue中间状态（next已更新，tail未更新）
//        head -> [dummy] -> [A] -> [B] -> [C] -> [D]
//                                   ^              |
//                                  tail         nullptr
//        此时tail落后了！

// 状态4: dequeue中间状态（head和tail指向同一个非空节点）
//        head -> [dummy] -> [A] <- tail
//        当另一个线程正在enqueue时可能出现

// 状态5: 空队列（只剩dummy）
//        head -> [dummy] <- tail
//                  |
//                nullptr

// 状态转换验证器
template <typename T>
class MSQueueStateValidator {
    std::atomic<Node*>& head_;
    std::atomic<Node*>& tail_;

public:
    enum class State {
        INITIAL,
        NORMAL,
        ENQUEUE_IN_PROGRESS,
        DEQUEUE_IN_PROGRESS,
        EMPTY,
        INVALID
    };

    State analyze_state() {
        Node* h = head_.load(std::memory_order_acquire);
        Node* t = tail_.load(std::memory_order_acquire);
        Node* h_next = h->next.load(std::memory_order_acquire);
        Node* t_next = t->next.load(std::memory_order_acquire);

        if (h == t && h_next == nullptr) {
            return State::EMPTY;  // 状态1或5
        }

        if (h == t && h_next != nullptr) {
            return State::ENQUEUE_IN_PROGRESS;  // 状态4
        }

        if (t_next != nullptr) {
            return State::ENQUEUE_IN_PROGRESS;  // 状态3，tail落后
        }

        if (h != t && t_next == nullptr) {
            return State::NORMAL;  // 状态2
        }

        return State::INVALID;
    }
};
```

**帮助机制的详细实现**

```cpp
// 带详细注释的帮助机制
template <typename T>
class MSQueueWithHelping {
    void enqueue(T value) {
        Node* new_node = new Node(std::move(value));

        while (true) {
            Node* tail = tail_.load(std::memory_order_acquire);
            Node* next = tail->next.load(std::memory_order_acquire);

            // 一致性检查：确保读取的tail是当前的tail
            if (tail != tail_.load(std::memory_order_acquire)) {
                continue;  // tail已变化，重试
            }

            if (next == nullptr) {
                // 情况A：tail是真正的尾节点
                // 尝试将新节点链接到tail之后
                if (tail->next.compare_exchange_weak(
                        next, new_node,
                        std::memory_order_release,
                        std::memory_order_relaxed)) {

                    // 链接成功，尝试更新tail
                    // 注意：即使这个CAS失败也没关系
                    // 因为其他线程会帮助完成
                    tail_.compare_exchange_strong(
                        tail, new_node,
                        std::memory_order_release,
                        std::memory_order_relaxed);
                    return;
                }
                // CAS失败，说明有其他线程同时在enqueue，重试
            } else {
                // 情况B：tail落后了（next != nullptr）
                // 这意味着另一个enqueue只完成了第一步（链接）
                // 但还没完成第二步（更新tail）
                // 我们帮助它完成第二步
                tail_.compare_exchange_strong(
                    tail, next,
                    std::memory_order_release,
                    std::memory_order_relaxed);
                // 无论成功与否，继续循环重试自己的enqueue
            }
        }
    }
};
```

**内存序选择的理由**

```cpp
// 详细解释每个memory_order的选择
template <typename T>
class MSQueueMemoryOrderAnalysis {
    void enqueue_annotated(T value) {
        Node* new_node = new Node(std::move(value));

        while (true) {
            // acquire: 需要看到tail指向的节点的完整状态
            // 包括其next指针的最新值
            Node* tail = tail_.load(std::memory_order_acquire);

            // acquire: 需要确保读取到的next是最新的
            // 如果next != nullptr，需要看到next节点的完整状态
            Node* next = tail->next.load(std::memory_order_acquire);

            // acquire: 双重检查，确保tail没有改变
            if (tail == tail_.load(std::memory_order_acquire)) {
                if (next == nullptr) {
                    // release: 确保new_node的构造对其他线程可见
                    // relaxed on failure: 失败时不需要同步
                    if (tail->next.compare_exchange_weak(next, new_node,
                            std::memory_order_release,
                            std::memory_order_relaxed)) {

                        // release: 确保链接操作对读取tail的线程可见
                        // relaxed on failure: 失败不影响正确性
                        tail_.compare_exchange_strong(tail, new_node,
                            std::memory_order_release,
                            std::memory_order_relaxed);
                        return;
                    }
                } else {
                    // release: 帮助操作，确保其他线程能看到更新
                    tail_.compare_exchange_strong(tail, next,
                        std::memory_order_release,
                        std::memory_order_relaxed);
                }
            }
        }
    }
};
```

---

#### 知识检验题

1. **帮助机制理解**：为什么MS队列在enqueue成功链接新节点后，即使更新tail的CAS失败也能返回？这不会导致问题吗？

2. **Dummy Node作用**：解释dummy node在MS队列中的作用。如果没有dummy node会有什么问题？

3. **ABA问题**：MS队列使用Hazard Pointer防止ABA问题。请解释在dequeue操作中，哪个步骤如果没有HP保护会触发ABA？

4. **代码分析**：在enqueue中，为什么要在CAS之前检查`tail == tail_.load()`？删除这个检查会有什么后果？

5. **性能分析**：MS队列在高竞争场景下的性能瓶颈是什么？如何优化？

---

### 第三周：SPSC队列（单生产者单消费者）

**学习目标**：实现高性能的SPSC队列

```cpp
// spsc_queue.hpp
#pragma once
#include <atomic>
#include <array>
#include <optional>

template <typename T, size_t Capacity>
class SPSCQueue {
    static_assert((Capacity & (Capacity - 1)) == 0, "Capacity must be power of 2");

    alignas(64) std::atomic<size_t> head_{0};  // 消费者读取位置
    alignas(64) std::atomic<size_t> tail_{0};  // 生产者写入位置
    alignas(64) std::array<T, Capacity> buffer_;

    size_t mask() const { return Capacity - 1; }

public:
    bool try_push(const T& value) {
        size_t tail = tail_.load(std::memory_order_relaxed);
        size_t next_tail = (tail + 1) & mask();

        if (next_tail == head_.load(std::memory_order_acquire)) {
            return false;  // 队列满
        }

        buffer_[tail] = value;
        tail_.store(next_tail, std::memory_order_release);
        return true;
    }

    bool try_push(T&& value) {
        size_t tail = tail_.load(std::memory_order_relaxed);
        size_t next_tail = (tail + 1) & mask();

        if (next_tail == head_.load(std::memory_order_acquire)) {
            return false;
        }

        buffer_[tail] = std::move(value);
        tail_.store(next_tail, std::memory_order_release);
        return true;
    }

    std::optional<T> try_pop() {
        size_t head = head_.load(std::memory_order_relaxed);

        if (head == tail_.load(std::memory_order_acquire)) {
            return std::nullopt;  // 队列空
        }

        T result = std::move(buffer_[head]);
        head_.store((head + 1) & mask(), std::memory_order_release);
        return result;
    }

    bool empty() const {
        return head_.load(std::memory_order_acquire) ==
               tail_.load(std::memory_order_acquire);
    }

    size_t size() const {
        size_t head = head_.load(std::memory_order_acquire);
        size_t tail = tail_.load(std::memory_order_acquire);
        return (tail - head) & mask();
    }
};
```

---

### 第三周扩展内容

#### 每日学习安排

**Day 1: SPSC队列原理（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 理解单生产者单消费者的简化特性 | 1.5h |
| 理论 | 学习环形缓冲区的基本原理 | 1.5h |
| 实践 | 实现基础版SPSC队列 | 1.5h |
| 复习 | 对比SPSC与MS队列的复杂度 | 0.5h |

**Day 2: 为什么SPSC不需要CAS（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 分析SPSC中为什么只用load/store | 1.5h |
| 理论 | 理解"单一写者"保证的强大作用 | 1.5h |
| 实践 | 证明SPSC的正确性（不变式方法） | 1.5h |
| 复习 | 整理SPSC简化的关键洞察 | 0.5h |

**Day 3: Cache Line优化（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 学习False Sharing问题 | 1.5h |
| 理论 | 理解alignas(64)的作用 | 1h |
| 实践 | 测量有无padding的性能差异 | 2h |
| 复习 | 记录False Sharing的影响数据 | 0.5h |

**Day 4: 批量操作优化（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 学习批量push/pop的优势 | 1h |
| 实践 | 实现push_batch和pop_batch | 2.5h |
| 实践 | 性能对比单个操作vs批量操作 | 1h |
| 复习 | 分析批量操作的适用场景 | 0.5h |

**Day 5: 等待策略（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 学习busy-wait vs blocking的权衡 | 1.5h |
| 实践 | 实现带blocking的版本（条件变量） | 2h |
| 实践 | 实现指数退避等待策略 | 1h |
| 复习 | 总结不同等待策略的适用场景 | 0.5h |

**Day 6: 源码分析与对比（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 实践 | 阅读folly::ProducerConsumerQueue完整源码 | 2h |
| 实践 | 阅读boost::lockfree::spsc_queue源码 | 2h |
| 复习 | 对比两者的设计差异和优化技巧 | 1h |

**Day 7: 周总结与实战（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 复习 | 回顾SPSC队列所有优化点 | 1h |
| 实践 | 实现生产级SPSC队列 | 2.5h |
| 测试 | 完成知识检验题和性能测试 | 1h |
| 总结 | 撰写学习笔记 | 0.5h |

---

#### 扩展阅读资源

**必读（优先级：高）**
- [ ] 源码：[folly::ProducerConsumerQueue](https://github.com/facebook/folly/blob/main/folly/ProducerConsumerQueue.h) - Facebook的SPSC实现
- [ ] 源码：[boost::lockfree::spsc_queue](https://www.boost.org/doc/libs/1_82_0/boost/lockfree/spsc_queue.hpp)
- [ ] 博客：[1024cores - Lock-Free Single Producer Single Consumer Queue](http://www.1024cores.net/home/lock-free-algorithms/queues/single-producer-single-consumer-queue)

**推荐阅读（优先级：中）**
- [ ] 论文：[MCRingBuffer: A Lock-Free Ring Buffer for Multi-core Architectures](https://www.cse.cuhk.edu.hk/~pclee/www/pubs/icdcs09.pdf)
- [ ] 博客：[Rigtorp - A fast single-producer, single-consumer lock-free queue](https://rigtorp.se/ringbuffer/)
- [ ] Linux内核：[kfifo实现分析](https://www.kernel.org/doc/html/latest/core-api/kernel-api.html)

**深入研究（优先级：低）**
- [ ] 论文：[Fast Concurrent Queues for x86 Processors](https://www.cs.tau.ac.il/~mad/publications/ppopp2013-x86queues.pdf)
- [ ] DPDK：[rte_ring实现](https://doc.dpdk.org/guides/prog_guide/ring_lib.html)

---

#### 工程实践深度解析

**SPSC队列的性能优化技术**

```cpp
// 优化1: 缓存head/tail的本地副本减少原子操作
template <typename T, size_t Capacity>
class OptimizedSPSCQueue {
    static_assert((Capacity & (Capacity - 1)) == 0, "Capacity must be power of 2");

    // 生产者私有数据
    struct alignas(64) ProducerData {
        size_t tail;
        size_t cached_head;  // 缓存的head值
    } producer_;

    // 消费者私有数据
    struct alignas(64) ConsumerData {
        size_t head;
        size_t cached_tail;  // 缓存的tail值
    } consumer_;

    // 共享的原子变量（只用于跨线程通信）
    alignas(64) std::atomic<size_t> head_{0};
    alignas(64) std::atomic<size_t> tail_{0};
    alignas(64) std::array<T, Capacity> buffer_;

    size_t mask() const { return Capacity - 1; }

public:
    OptimizedSPSCQueue() : producer_{0, 0}, consumer_{0, 0} {}

    bool try_push(const T& value) {
        size_t next_tail = (producer_.tail + 1) & mask();

        // 先检查缓存的head
        if (next_tail == producer_.cached_head) {
            // 缓存过期，重新读取
            producer_.cached_head = head_.load(std::memory_order_acquire);
            if (next_tail == producer_.cached_head) {
                return false;  // 确实满了
            }
        }

        buffer_[producer_.tail] = value;
        tail_.store(next_tail, std::memory_order_release);
        producer_.tail = next_tail;
        return true;
    }

    std::optional<T> try_pop() {
        // 先检查缓存的tail
        if (consumer_.head == consumer_.cached_tail) {
            // 缓存过期，重新读取
            consumer_.cached_tail = tail_.load(std::memory_order_acquire);
            if (consumer_.head == consumer_.cached_tail) {
                return std::nullopt;  // 确实空了
            }
        }

        T result = std::move(buffer_[consumer_.head]);
        size_t next_head = (consumer_.head + 1) & mask();
        head_.store(next_head, std::memory_order_release);
        consumer_.head = next_head;
        return result;
    }
};

// 优化2: 批量操作减少同步开销
template <typename T, size_t Capacity>
class BatchSPSCQueue {
    // ... 基本结构同上 ...

    // 批量推送，返回实际推送数量
    template <typename Iterator>
    size_t push_batch(Iterator begin, Iterator end) {
        size_t tail = producer_.tail;
        size_t available = available_push_slots();
        size_t to_push = std::min(static_cast<size_t>(std::distance(begin, end)), available);

        for (size_t i = 0; i < to_push; ++i) {
            buffer_[tail & mask()] = *begin++;
            ++tail;
        }

        // 只做一次原子store
        tail_.store(tail & mask(), std::memory_order_release);
        producer_.tail = tail & mask();
        return to_push;
    }

    // 批量弹出
    template <typename OutputIterator>
    size_t pop_batch(OutputIterator out, size_t max_count) {
        size_t head = consumer_.head;
        size_t available = available_pop_count();
        size_t to_pop = std::min(max_count, available);

        for (size_t i = 0; i < to_pop; ++i) {
            *out++ = std::move(buffer_[head & mask()]);
            ++head;
        }

        // 只做一次原子store
        head_.store(head & mask(), std::memory_order_release);
        consumer_.head = head & mask();
        return to_pop;
    }

private:
    size_t available_push_slots() {
        size_t head = producer_.cached_head;
        if ((producer_.tail + 1) & mask() == head) {
            head = producer_.cached_head = head_.load(std::memory_order_acquire);
        }
        return (head - producer_.tail - 1) & mask();
    }

    size_t available_pop_count() {
        size_t tail = consumer_.cached_tail;
        if (consumer_.head == tail) {
            tail = consumer_.cached_tail = tail_.load(std::memory_order_acquire);
        }
        return (tail - consumer_.head) & mask();
    }
};

// 优化3: 使用2的幂容量实现高效的模运算
// (index & mask) 比 (index % capacity) 快得多
// 这也是为什么我们要求容量是2的幂

// 优化4: 预取提示
template <typename T, size_t Capacity>
class PrefetchSPSCQueue {
    std::optional<T> try_pop() {
        if (consumer_.head == consumer_.cached_tail) {
            consumer_.cached_tail = tail_.load(std::memory_order_acquire);
            if (consumer_.head == consumer_.cached_tail) {
                return std::nullopt;
            }
        }

        // 预取下一个元素
        size_t next = (consumer_.head + 1) & mask();
        __builtin_prefetch(&buffer_[next], 0, 3);  // 读预取，高时间局部性

        T result = std::move(buffer_[consumer_.head]);
        head_.store(next, std::memory_order_release);
        consumer_.head = next;
        return result;
    }
};
```

**False Sharing问题详解**

```cpp
// False Sharing问题演示
struct BadLayout {
    std::atomic<size_t> head;  // 消费者频繁修改
    std::atomic<size_t> tail;  // 生产者频繁修改
    // head和tail在同一缓存行！
    // 当生产者修改tail时，消费者的缓存行失效
    // 当消费者修改head时，生产者的缓存行失效
    // 导致大量缓存行乒乓（cache line ping-pong）
};

// 正确布局
struct GoodLayout {
    alignas(64) std::atomic<size_t> head;  // 独占一个缓存行
    alignas(64) std::atomic<size_t> tail;  // 独占另一个缓存行
    // 现在生产者和消费者互不干扰
};

// 性能测试框架
void benchmark_false_sharing() {
    const int iterations = 10000000;

    // 测试BadLayout
    {
        struct alignas(64) BadQueue {
            std::atomic<size_t> head{0};
            std::atomic<size_t> tail{0};  // 同一缓存行
        } queue;

        auto start = std::chrono::high_resolution_clock::now();

        std::thread producer([&] {
            for (int i = 0; i < iterations; ++i) {
                queue.tail.fetch_add(1, std::memory_order_relaxed);
            }
        });

        std::thread consumer([&] {
            for (int i = 0; i < iterations; ++i) {
                queue.head.fetch_add(1, std::memory_order_relaxed);
            }
        });

        producer.join();
        consumer.join();

        auto end = std::chrono::high_resolution_clock::now();
        std::cout << "Bad layout: "
                  << std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count()
                  << " ms\n";
    }

    // 测试GoodLayout
    {
        struct GoodQueue {
            alignas(64) std::atomic<size_t> head{0};
            alignas(64) std::atomic<size_t> tail{0};  // 不同缓存行
        } queue;

        // 同样的测试...
        // 预期性能提升2-10倍
    }
}
```

---

#### 知识检验题

1. **内存序分析**：为什么SPSC队列可以用relaxed order读取自己拥有的变量（生产者读tail，消费者读head），但读取对方的变量需要acquire？

2. **容量限制**：为什么要求容量是2的幂？如果容量是100会有什么问题？如何支持非2的幂容量？

3. **满/空判断**：当前实现中，满队列实际存储Capacity-1个元素。如何修改实现以支持存储Capacity个元素？有什么额外开销？

4. **等待策略**：在高吞吐量场景下，busy-wait和blocking wait各自的优缺点是什么？如何设计自适应等待策略？

5. **性能优化**：解释本地缓存技术（cached_head/cached_tail）如何减少原子操作的开销。在什么情况下这种优化最有效？

---

### 第四周：MPSC队列（多生产者单消费者）

**学习目标**：实现MPSC队列

```cpp
// mpsc_queue.hpp
#pragma once
#include <atomic>
#include <optional>

template <typename T>
class MPSCQueue {
    struct Node {
        T data;
        std::atomic<Node*> next{nullptr};

        Node() = default;
        Node(T d) : data(std::move(d)) {}
    };

    std::atomic<Node*> head_;  // 消费者访问
    alignas(64) std::atomic<Node*> tail_;  // 生产者访问

public:
    MPSCQueue() {
        Node* dummy = new Node();
        head_.store(dummy, std::memory_order_relaxed);
        tail_.store(dummy, std::memory_order_relaxed);
    }

    ~MPSCQueue() {
        while (try_pop()) {}
        delete head_.load(std::memory_order_relaxed);
    }

    // 多个生产者可以并发调用
    void push(T value) {
        Node* new_node = new Node(std::move(value));
        Node* prev = tail_.exchange(new_node, std::memory_order_acq_rel);
        prev->next.store(new_node, std::memory_order_release);
    }

    // 只有单个消费者调用
    std::optional<T> try_pop() {
        Node* head = head_.load(std::memory_order_relaxed);
        Node* next = head->next.load(std::memory_order_acquire);

        if (next == nullptr) {
            return std::nullopt;
        }

        T result = std::move(next->data);
        head_.store(next, std::memory_order_release);
        delete head;
        return result;
    }

    bool empty() const {
        Node* head = head_.load(std::memory_order_acquire);
        return head->next.load(std::memory_order_acquire) == nullptr;
    }
};
```

---

### 第四周扩展内容

#### 每日学习安排

**Day 1: MPSC队列原理（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 理解MPSC的应用场景（日志、事件分发） | 1h |
| 理论 | 分析为什么单消费者简化了设计 | 1.5h |
| 实践 | 实现基础MPSC队列 | 2h |
| 复习 | 对比MPSC与MPMC的复杂度差异 | 0.5h |

**Day 2: exchange操作的妙用（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 深入理解atomic::exchange的语义 | 1.5h |
| 理论 | 分析MPSC中exchange为何能保证正确性 | 1.5h |
| 实践 | 对比exchange实现vs CAS循环实现 | 1.5h |
| 复习 | 总结exchange的适用场景 | 0.5h |

**Day 3: 中间状态处理（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 分析push的两阶段过程 | 1.5h |
| 理论 | 理解消费者如何处理"next为空但队列非空" | 1.5h |
| 实践 | 编写测试验证中间状态处理 | 1.5h |
| 复习 | 设计中间状态的调试方法 | 0.5h |

**Day 4: 无界vs有界MPSC（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 分析无界队列的内存增长问题 | 1.5h |
| 实践 | 实现有界MPSC队列（基于环形缓冲区） | 2.5h |
| 实践 | 性能对比无界vs有界实现 | 0.5h |
| 复习 | 总结选择依据 | 0.5h |

**Day 5: 内存回收简化（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 分析为什么MPSC不需要Hazard Pointer | 1.5h |
| 理论 | 单消费者如何安全回收内存 | 1.5h |
| 实践 | 使用ASan验证无内存问题 | 1.5h |
| 复习 | 对比MPSC与MS队列的回收机制 | 0.5h |

**Day 6: 实际应用案例研究（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 实践 | 研究Tokio的MPSC channel实现 | 2h |
| 实践 | 研究Go channel的MPSC模式 | 2h |
| 复习 | 总结不同语言/框架的设计选择 | 1h |

**Day 7: 周总结与综合实战（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 复习 | 回顾本月所有队列类型 | 1h |
| 实践 | 完成MPMC队列实现 | 2.5h |
| 测试 | 完成性能基准测试 | 1h |
| 总结 | 撰写本月学习笔记 | 0.5h |

---

#### 扩展阅读资源

**必读（优先级：高）**
- [ ] 博客：[1024cores - Intrusive MPSC node-based queue](http://www.1024cores.net/home/lock-free-algorithms/queues/intrusive-mpsc-node-based-queue)
- [ ] 源码：[Tokio MPSC channel](https://github.com/tokio-rs/tokio/tree/master/tokio/src/sync/mpsc)
- [ ] 论文：[Fast and Scalable Queues for Multi-core Processors](https://www.cs.tau.ac.il/~shanir/nir-pubs-web/Papers/Lock_Free.pdf)

**推荐阅读（优先级：中）**
- [ ] 博客：[Dmitry Vyukov - Intrusive MPSC Queue](http://www.1024cores.net/home/lock-free-algorithms/queues/intrusive-mpsc-node-based-queue)
- [ ] Go源码：[Go runtime mcache/mcentral](https://github.com/golang/go/blob/master/src/runtime/mcache.go)
- [ ] Crossbeam：[Rust MPSC实现](https://github.com/crossbeam-rs/crossbeam/tree/master/crossbeam-channel)

**深入研究（优先级：低）**
- [ ] 论文：[Non-Blocking Concurrent Data Structures with Condition Synchronization](https://www.cs.tau.ac.il/~shanir/nir-pubs-web/Papers/Lock_Free.pdf)
- [ ] LMAX Disruptor：[Ring Buffer设计](https://lmax-exchange.github.io/disruptor/)

---

#### 工程实践深度解析

**MPSC队列的关键状态分析**

```cpp
// MPSC的中间状态问题
// push操作分两步：
// 1. exchange获取prev，将tail指向new_node
// 2. 将prev->next指向new_node

// 如果线程在step 1和step 2之间被抢占：
// 线程A: prev_a = exchange(tail, node_a)  // 成功
// 线程A: --- 被抢占 ---
// 线程B: prev_b = exchange(tail, node_b)  // prev_b = node_a
// 线程B: prev_b->next = node_b            // node_a->next = node_b
// 此时队列链表断开！prev_a->next仍然是nullptr

// 消费者看到的状态：
// head -> dummy -> ... -> prev_a -> nullptr (断开!)
//                         node_a -> node_b <- tail

// 解决方案：消费者需要等待next变为非空
template <typename T>
class RobustMPSCQueue {
    std::optional<T> try_pop() {
        Node* head = head_.load(std::memory_order_relaxed);
        Node* next = head->next.load(std::memory_order_acquire);

        if (next == nullptr) {
            // 可能是真的空，也可能是生产者正在push
            // 在try_pop语义下，直接返回nullopt
            return std::nullopt;
        }

        T result = std::move(next->data);
        head_.store(next, std::memory_order_release);
        delete head;
        return result;
    }

    // 阻塞版本：等待直到有数据
    T pop_blocking() {
        Node* head = head_.load(std::memory_order_relaxed);
        Node* next;

        // 自旋等待next变为非空
        while ((next = head->next.load(std::memory_order_acquire)) == nullptr) {
            // 可以添加退避策略
            std::this_thread::yield();
        }

        T result = std::move(next->data);
        head_.store(next, std::memory_order_release);
        delete head;
        return result;
    }
};
```

**有界MPSC队列实现**

```cpp
// 基于环形缓冲区的有界MPSC队列
template <typename T, size_t Capacity>
class BoundedMPSCQueue {
    static_assert((Capacity & (Capacity - 1)) == 0, "Capacity must be power of 2");

    struct Cell {
        std::atomic<size_t> sequence;
        T data;
    };

    alignas(64) std::array<Cell, Capacity> buffer_;
    alignas(64) std::atomic<size_t> enqueue_pos_{0};
    alignas(64) size_t dequeue_pos_{0};  // 只有消费者访问，不需要原子

    size_t mask() const { return Capacity - 1; }

public:
    BoundedMPSCQueue() {
        for (size_t i = 0; i < Capacity; ++i) {
            buffer_[i].sequence.store(i, std::memory_order_relaxed);
        }
    }

    bool try_push(const T& value) {
        Cell* cell;
        size_t pos = enqueue_pos_.load(std::memory_order_relaxed);

        while (true) {
            cell = &buffer_[pos & mask()];
            size_t seq = cell->sequence.load(std::memory_order_acquire);
            intptr_t diff = static_cast<intptr_t>(seq) - static_cast<intptr_t>(pos);

            if (diff == 0) {
                // 槽位可用，尝试占用
                if (enqueue_pos_.compare_exchange_weak(pos, pos + 1,
                        std::memory_order_relaxed)) {
                    break;
                }
            } else if (diff < 0) {
                return false;  // 队列满
            } else {
                pos = enqueue_pos_.load(std::memory_order_relaxed);
            }
        }

        cell->data = value;
        cell->sequence.store(pos + 1, std::memory_order_release);
        return true;
    }

    std::optional<T> try_pop() {
        Cell* cell = &buffer_[dequeue_pos_ & mask()];
        size_t seq = cell->sequence.load(std::memory_order_acquire);
        intptr_t diff = static_cast<intptr_t>(seq) - static_cast<intptr_t>(dequeue_pos_ + 1);

        if (diff < 0) {
            return std::nullopt;  // 队列空
        }

        // 单消费者，不需要CAS
        T result = std::move(cell->data);
        cell->sequence.store(dequeue_pos_ + Capacity, std::memory_order_release);
        ++dequeue_pos_;
        return result;
    }
};
```

**侵入式MPSC队列**

```cpp
// 侵入式设计：节点内嵌到数据中，避免额外分配
struct IntrusiveNode {
    std::atomic<IntrusiveNode*> next{nullptr};
};

template <typename T, IntrusiveNode T::*NodeMember>
class IntrusiveMPSCQueue {
    std::atomic<IntrusiveNode*> head_;
    std::atomic<IntrusiveNode*> tail_;
    IntrusiveNode stub_;  // 哨兵节点

public:
    IntrusiveMPSCQueue() {
        stub_.next.store(nullptr, std::memory_order_relaxed);
        head_.store(&stub_, std::memory_order_relaxed);
        tail_.store(&stub_, std::memory_order_relaxed);
    }

    void push(T* item) {
        IntrusiveNode* node = &(item->*NodeMember);
        node->next.store(nullptr, std::memory_order_relaxed);

        IntrusiveNode* prev = tail_.exchange(node, std::memory_order_acq_rel);
        prev->next.store(node, std::memory_order_release);
    }

    T* try_pop() {
        IntrusiveNode* head = head_.load(std::memory_order_relaxed);
        IntrusiveNode* next = head->next.load(std::memory_order_acquire);

        if (head == &stub_) {
            if (next == nullptr) {
                return nullptr;  // 空队列
            }
            // 跳过哨兵
            head_.store(next, std::memory_order_relaxed);
            head = next;
            next = next->next.load(std::memory_order_acquire);
        }

        if (next != nullptr) {
            head_.store(next, std::memory_order_release);
            // 通过偏移计算获取原始对象
            return container_of(head, NodeMember);
        }

        IntrusiveNode* tail = tail_.load(std::memory_order_acquire);
        if (head != tail) {
            return nullptr;  // 有生产者正在push
        }

        // 队列将要变空，重新插入哨兵
        stub_.next.store(nullptr, std::memory_order_relaxed);
        IntrusiveNode* prev = tail_.exchange(&stub_, std::memory_order_acq_rel);
        prev->next.store(&stub_, std::memory_order_release);

        next = head->next.load(std::memory_order_acquire);
        if (next != nullptr) {
            head_.store(next, std::memory_order_release);
            return container_of(head, NodeMember);
        }

        return nullptr;
    }

private:
    static T* container_of(IntrusiveNode* node, IntrusiveNode T::*member) {
        return reinterpret_cast<T*>(
            reinterpret_cast<char*>(node) -
            reinterpret_cast<size_t>(&(static_cast<T*>(nullptr)->*member))
        );
    }
};

// 使用示例
struct Task {
    int id;
    std::function<void()> work;
    IntrusiveNode queue_node;  // 内嵌节点
};

IntrusiveMPSCQueue<Task, &Task::queue_node> task_queue;
```

---

#### 知识检验题

1. **exchange vs CAS**：在MPSC的push实现中，为什么使用`tail_.exchange()`而不是CAS循环？exchange有什么保证？

2. **中间状态**：解释MPSC push的中间状态问题。消费者在try_pop时看到`next == nullptr`意味着什么？可能有几种情况？

3. **内存回收**：为什么MPSC队列的消费者可以直接delete节点，而不需要Hazard Pointer？

4. **有界vs无界**：在实现有界MPSC队列时，生产者如何处理队列满的情况？有哪些策略？

5. **侵入式设计**：解释侵入式队列的优缺点。在什么场景下应该使用侵入式设计？

---

## 实践项目

### 项目：完整的无锁队列库

#### Part 1: 带批量操作的MPMC队列
```cpp
// mpmc_queue.hpp
#pragma once
#include <atomic>
#include <array>
#include <optional>
#include <vector>

template <typename T, size_t Capacity>
class MPMCQueue {
    static_assert((Capacity & (Capacity - 1)) == 0, "Capacity must be power of 2");

    struct Cell {
        std::atomic<size_t> sequence;
        T data;
    };

    alignas(64) std::array<Cell, Capacity> buffer_;
    alignas(64) std::atomic<size_t> enqueue_pos_{0};
    alignas(64) std::atomic<size_t> dequeue_pos_{0};

    size_t mask() const { return Capacity - 1; }

public:
    MPMCQueue() {
        for (size_t i = 0; i < Capacity; ++i) {
            buffer_[i].sequence.store(i, std::memory_order_relaxed);
        }
    }

    bool try_push(const T& value) {
        Cell* cell;
        size_t pos = enqueue_pos_.load(std::memory_order_relaxed);

        while (true) {
            cell = &buffer_[pos & mask()];
            size_t seq = cell->sequence.load(std::memory_order_acquire);
            intptr_t diff = static_cast<intptr_t>(seq) - static_cast<intptr_t>(pos);

            if (diff == 0) {
                if (enqueue_pos_.compare_exchange_weak(pos, pos + 1,
                        std::memory_order_relaxed)) {
                    break;
                }
            } else if (diff < 0) {
                return false;  // 队列满
            } else {
                pos = enqueue_pos_.load(std::memory_order_relaxed);
            }
        }

        cell->data = value;
        cell->sequence.store(pos + 1, std::memory_order_release);
        return true;
    }

    std::optional<T> try_pop() {
        Cell* cell;
        size_t pos = dequeue_pos_.load(std::memory_order_relaxed);

        while (true) {
            cell = &buffer_[pos & mask()];
            size_t seq = cell->sequence.load(std::memory_order_acquire);
            intptr_t diff = static_cast<intptr_t>(seq) - static_cast<intptr_t>(pos + 1);

            if (diff == 0) {
                if (dequeue_pos_.compare_exchange_weak(pos, pos + 1,
                        std::memory_order_relaxed)) {
                    break;
                }
            } else if (diff < 0) {
                return std::nullopt;  // 队列空
            } else {
                pos = dequeue_pos_.load(std::memory_order_relaxed);
            }
        }

        T result = std::move(cell->data);
        cell->sequence.store(pos + Capacity, std::memory_order_release);
        return result;
    }

    // 批量入队
    size_t push_batch(const std::vector<T>& items) {
        size_t pushed = 0;
        for (const auto& item : items) {
            if (!try_push(item)) break;
            ++pushed;
        }
        return pushed;
    }

    // 批量出队
    std::vector<T> pop_batch(size_t max_count) {
        std::vector<T> result;
        result.reserve(max_count);
        for (size_t i = 0; i < max_count; ++i) {
            auto item = try_pop();
            if (!item) break;
            result.push_back(std::move(*item));
        }
        return result;
    }
};
```

#### Part 2: 性能基准测试
```cpp
// queue_benchmark.cpp
#include "spsc_queue.hpp"
#include "mpsc_queue.hpp"
#include "mpmc_queue.hpp"
#include <thread>
#include <chrono>
#include <iostream>
#include <vector>

template <typename Queue>
void bench_spsc(const char* name, int iterations) {
    Queue queue;
    auto start = std::chrono::high_resolution_clock::now();

    std::thread producer([&] {
        for (int i = 0; i < iterations; ++i) {
            while (!queue.try_push(i)) {}
        }
    });

    std::thread consumer([&] {
        for (int i = 0; i < iterations; ++i) {
            while (!queue.try_pop()) {}
        }
    });

    producer.join();
    consumer.join();

    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

    std::cout << name << ": " << duration.count() << " ms, "
              << (iterations * 1000.0 / duration.count()) / 1000000 << " M ops/sec\n";
}

template <typename Queue>
void bench_mpmc(const char* name, int producers, int consumers, int iterations) {
    Queue queue;
    std::atomic<int> produced{0};
    std::atomic<int> consumed{0};

    auto start = std::chrono::high_resolution_clock::now();

    std::vector<std::thread> threads;

    for (int i = 0; i < producers; ++i) {
        threads.emplace_back([&] {
            while (true) {
                int val = produced.fetch_add(1, std::memory_order_relaxed);
                if (val >= iterations) break;
                while (!queue.try_push(val)) {
                    std::this_thread::yield();
                }
            }
        });
    }

    for (int i = 0; i < consumers; ++i) {
        threads.emplace_back([&] {
            while (consumed.load(std::memory_order_relaxed) < iterations) {
                if (queue.try_pop()) {
                    consumed.fetch_add(1, std::memory_order_relaxed);
                } else {
                    std::this_thread::yield();
                }
            }
        });
    }

    for (auto& t : threads) {
        t.join();
    }

    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

    std::cout << name << " (" << producers << "P/" << consumers << "C): "
              << duration.count() << " ms, "
              << (iterations * 1000.0 / duration.count()) / 1000000 << " M ops/sec\n";
}

int main() {
    const int iterations = 10000000;

    std::cout << "=== SPSC Queue ===\n";
    bench_spsc<SPSCQueue<int, 1024>>("SPSCQueue", iterations);

    std::cout << "\n=== MPMC Queue ===\n";
    bench_mpmc<MPMCQueue<int, 1024>>("MPMCQueue", 1, 1, iterations);
    bench_mpmc<MPMCQueue<int, 1024>>("MPMCQueue", 2, 2, iterations);
    bench_mpmc<MPMCQueue<int, 1024>>("MPMCQueue", 4, 4, iterations);

    return 0;
}
```

---

## 检验标准

### 知识检验
- [ ] Michael-Scott队列的"帮助"机制是什么？
- [ ] SPSC队列为什么能比MPMC更简单高效？
- [ ] 有界队列和无界队列的权衡是什么？
- [ ] 如何选择合适的队列类型？

### 实践检验
- [ ] MS队列在多线程环境下正确工作
- [ ] SPSC队列达到高吞吐量
- [ ] MPMC队列正确处理并发

### 输出物
1. `michael_scott_queue.hpp`
2. `spsc_queue.hpp`
3. `mpsc_queue.hpp`
4. `mpmc_queue.hpp`
5. `queue_benchmark.cpp`
6. `notes/month17_lockfree_queue.md`

---

## 时间分配（140小时/月）

| 内容 | 时间 | 占比 |
|------|------|------|
| 理论学习 | 30小时 | 21% |
| 源码阅读 | 25小时 | 18% |
| 队列实现 | 50小时 | 36% |
| 基准测试 | 20小时 | 14% |
| 笔记与文档 | 15小时 | 11% |

---

## 队列类型选择指南

| 场景 | 推荐队列 | 理由 |
|------|----------|------|
| 日志收集 | MPSC | 多线程写日志，单线程flush |
| 线程池任务分发 | MPMC | 多个提交者，多个工作者 |
| 音视频流处理 | SPSC | 解码线程→渲染线程 |
| 高频交易 | 有界SPSC/MPMC | 低延迟，背压控制 |
| Actor消息传递 | MPSC | 多发送者，单actor处理 |
| 事件循环 | MPSC | 多源事件，单循环处理 |

---

## 下月预告

Month 18将学习**Future/Promise与异步编程**，探索C++的异步编程模型，为后续的协程学习做准备。
