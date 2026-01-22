# Month 16: ABA问题与内存回收——无锁编程的隐秘陷阱

## 本月主题概述

ABA问题是无锁编程中最微妙的Bug来源之一。本月将深入理解ABA问题的本质，学习危险指针（Hazard Pointers）、Epoch-based回收等解决方案，以及它们在实际系统中的应用。

---

## 理论学习内容

### 第一周：ABA问题深度分析

**学习目标**：彻底理解ABA问题的本质

**阅读材料**：
- [ ] 论文："Hazard Pointers: Safe Memory Reclamation for Lock-Free Objects"
- [ ] 博客：Preshing "An Introduction to Lock-Free Programming"
- [ ] 《C++ Concurrency in Action》无锁数据结构章节

**核心概念**：

#### ABA问题示例
```cpp
// 无锁栈的pop操作
template <typename T>
class BuggyStack {
    struct Node {
        T data;
        Node* next;
    };
    std::atomic<Node*> head_;

    std::optional<T> pop() {
        Node* old_head = head_.load();
        while (old_head != nullptr) {
            Node* new_head = old_head->next;  // (1) 读取next
            if (head_.compare_exchange_weak(old_head, new_head)) {
                T result = old_head->data;
                delete old_head;
                return result;
            }
        }
        return std::nullopt;
    }
};

// ABA问题场景：
// 初始状态：head -> A -> B -> C
//
// Thread 1: pop()
//   old_head = A
//   new_head = B (A->next)
//   --- 被中断 ---
//
// Thread 2: pop() 成功，删除A
// Thread 2: pop() 成功，删除B
// Thread 2: push(D)，其中D恰好被分配到A的地址！
// Thread 2: push(A)，重用原来的A地址
//
// 现在：head -> A(new) -> D -> C
// 但A(new)->next = D，不是B！
//
// Thread 1: 恢复执行
//   CAS成功！因为head仍然是A（地址相同）
//   head变成B，但B已经被删除了！
//   --- 内存腐败 ---
```

#### 为什么CAS无法检测ABA？
```cpp
// CAS只比较值，不比较"身份"
// 当一个指针被释放并重新分配到相同地址时
// CAS无法区分这是"同一个对象"还是"不同对象恰好在同一地址"

// 问题的根源：
// 1. CAS是基于值的比较
// 2. 内存分配器可能重用地址
// 3. 没有机制追踪"对象版本"
```

---

### 第一周扩展内容

#### 每日学习安排

**Day 1: ABA问题概念建立（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 阅读《C++ Concurrency in Action》无锁章节 | 2h |
| 理论 | 学习CAS操作的本质和局限性 | 1h |
| 实践 | 手写BuggyStack代码，理解其结构 | 1.5h |
| 复习 | 整理笔记，画出无锁栈的状态转换图 | 0.5h |

**Day 2: ABA触发条件深度分析（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 分析ABA问题的三个必要条件 | 1h |
| 理论 | 学习内存分配器的地址重用机制 | 1.5h |
| 实践 | 编写能复现ABA的测试用例 | 2h |
| 复习 | 总结ABA触发的时序图 | 0.5h |

**Day 3: 内存分配器与ABA的关系（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 学习glibc malloc/tcmalloc/jemalloc的地址重用策略 | 2h |
| 实践 | 编写程序观察地址重用行为 | 2h |
| 实践 | 使用Valgrind/ASan分析内存行为 | 0.5h |
| 复习 | 整理不同分配器的特点 | 0.5h |

**Day 4: 论文精读（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 精读"Hazard Pointers"论文前半部分（ABA描述） | 2.5h |
| 理论 | 阅读Preshing博客"An Introduction to Lock-Free Programming" | 1.5h |
| 复习 | 整理论文中的关键结论和证明思路 | 1h |

**Day 5: 无锁数据结构中的ABA案例（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 分析无锁栈、无锁队列中的ABA场景 | 1.5h |
| 实践 | 实现一个会出现ABA的无锁队列 | 2.5h |
| 实践 | 使用ThreadSanitizer检测问题 | 0.5h |
| 复习 | 对比栈和队列中ABA的异同 | 0.5h |

**Day 6: 真实案例研究（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 研究开源项目中的ABA相关bug报告 | 2h |
| 实践 | 复现并分析一个真实的ABA bug | 2h |
| 复习 | 总结避免ABA的设计原则 | 1h |

**Day 7: 周总结与实战（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 复习 | 回顾本周所有概念，查漏补缺 | 1h |
| 实践 | 完成本周编程练习 | 2.5h |
| 测试 | 完成知识检验题 | 1h |
| 总结 | 撰写学习笔记 | 0.5h |

---

#### 扩展阅读资源

**必读（优先级：高）**
- [ ] 论文：[Hazard Pointers: Safe Memory Reclamation for Lock-Free Objects](https://www.cs.otago.ac.nz/cosc440/readings/hazard-pointers.pdf) - Maged M. Michael (IEEE 2004)
- [ ] 博客：[Preshing - An Introduction to Lock-Free Programming](https://preshing.com/20120612/an-introduction-to-lock-free-programming/)
- [ ] 博客：[Preshing - The ABA Problem](https://preshing.com/20140709/the-purpose-of-memory_order_consume-in-cpp11/)

**推荐阅读（优先级：中）**
- [ ] CppCon 2014：[Herb Sutter - Lock-Free Programming](https://www.youtube.com/watch?v=c1gO9aB9nbs)
- [ ] CppCon 2017：[Fedor Pikus - Read, Copy, Update, then what?](https://www.youtube.com/watch?v=rxQ5K9lo034)
- [ ] 博客：[1024cores - ABA Problem](http://www.1024cores.net/home/lock-free-algorithms/aba-problem)

**深入研究（优先级：低）**
- [ ] 论文：[A Practical Multi-Word Compare-and-Swap Operation](https://www.cl.cam.ac.uk/research/srg/netos/papers/2002-casn.pdf)
- [ ] Intel文档：[Intel 64 and IA-32 Architectures Software Developer's Manual](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html) - CMPXCHG16B指令

---

#### 工程实践深度解析

**调试ABA问题的技巧**

```cpp
// 技巧1: 添加调试标记追踪对象生命周期
template <typename T>
class DebugNode {
    static std::atomic<uint64_t> global_id_counter;
    uint64_t creation_id_;  // 创建时的唯一ID
    uint64_t reuse_count_;  // 地址被重用的次数

public:
    T data;
    DebugNode* next;

    DebugNode(T d) : data(std::move(d)), next(nullptr) {
        creation_id_ = global_id_counter.fetch_add(1);
        reuse_count_ = 0;
        std::cout << "Node created: id=" << creation_id_
                  << " addr=" << this << std::endl;
    }

    ~DebugNode() {
        std::cout << "Node destroyed: id=" << creation_id_
                  << " addr=" << this << std::endl;
    }

    uint64_t id() const { return creation_id_; }
};

// 技巧2: 使用自定义分配器强制地址重用
class ReuseForcingAllocator {
    std::vector<void*> free_list_;
    std::mutex mutex_;

public:
    void* allocate(size_t size) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (!free_list_.empty()) {
            void* ptr = free_list_.back();
            free_list_.pop_back();
            std::cout << "Reusing address: " << ptr << std::endl;
            return ptr;
        }
        return ::operator new(size);
    }

    void deallocate(void* ptr) {
        std::lock_guard<std::mutex> lock(mutex_);
        free_list_.push_back(ptr);  // 不真正释放，保存以便重用
    }
};

// 技巧3: 使用延迟和随机化来增加ABA触发概率
void pop_with_delay() {
    Node* old_head = head_.load();

    // 故意增加延迟，模拟被抢占
    std::this_thread::sleep_for(std::chrono::microseconds(
        rand() % 100));

    // ... 继续CAS操作
}
```

**常见陷阱**

```cpp
// 陷阱1: 以为引用计数能解决ABA
// 错误！引用计数和ABA是两个不同的问题
template <typename T>
class WrongSolution {
    struct Node {
        std::atomic<int> ref_count{1};
        T data;
        Node* next;
    };

    // 即使有引用计数，CAS仍然比较的是指针值
    // 如果指针值相同（地址被重用），CAS仍会成功
    // 引用计数只能防止过早释放，不能防止ABA
};

// 陷阱2: 以为单线程测试通过就没问题
// ABA是纯粹的并发问题，单线程永远不会触发

// 陷阱3: 以为加锁就能解决
// 加锁确实能解决ABA，但这违背了无锁编程的初衷
```

**性能考量**

```cpp
// ABA问题的各种解决方案性能对比因素：

// 1. 版本计数
//    - 额外存储：每指针8字节（64位计数器）
//    - 需要128位CAS：某些平台性能较差
//    - 计数器溢出：理论上存在，实际几乎不可能

// 2. 危险指针
//    - 每线程额外存储：K个危险指针槽 × 8字节
//    - 每次访问额外操作：写入危险指针 + fence
//    - 批量回收时需要扫描所有线程

// 3. EBR
//    - 每线程额外存储：本地epoch + 待回收列表
//    - 进入/退出临界区的开销
//    - 依赖所有线程的协作
```

---

#### 真实案例分析

**案例1: folly库的ABA修复**

```cpp
// Facebook folly库在AtomicHashMap中曾遇到ABA问题
// 问题描述：在删除和重新插入元素时，由于地址重用导致数据损坏

// 修复方法：使用AtomicStruct<PackedPtr>存储指针+版本号
// https://github.com/facebook/folly/blob/main/folly/AtomicHashMap.h

// 关键代码模式：
template <class T>
struct PackedPtr {
    T* ptr;
    uint32_t tag;  // 版本号

    bool cas(PackedPtr& expected, PackedPtr desired) {
        // 使用128位CAS（如果可用）或者double-width CAS
    }
};
```

**案例2: Java ConcurrentLinkedQueue的解决方案**

```java
// Java的ConcurrentLinkedQueue使用了一种巧妙的方法：
// 不删除节点，而是将节点标记为"逻辑删除"
// 这样指针永远有效，避免了ABA问题

// 关键思想：
// 1. 节点一旦加入队列，其next指针永远不会变成null
// 2. 删除时只是将节点的item设为null
// 3. 物理删除延迟进行

// 这种方法的代价是内存可能暂时无法回收
```

**案例3: 一个真实的生产环境ABA Bug**

```cpp
// 场景：高并发消息队列
// 现象：偶发的消息丢失，难以复现

// 根因分析：
// 1. 消息队列使用无锁链表实现
// 2. 消费者pop消息后，消息节点被释放
// 3. 新消息push时，分配器返回了刚释放的地址
// 4. 另一个消费者的CAS操作意外成功
// 5. 链表结构被破坏，部分消息"消失"

// 复现方法：
// 1. 使用自定义分配器强制地址重用
// 2. 增加线程数量和消息频率
// 3. 在关键位置插入随机延迟

// 修复：改用带版本号的指针或hazard pointer
```

---

#### 对比实验

**实验：观察不同分配器的地址重用行为**

```cpp
// experiment_allocator_reuse.cpp
#include <iostream>
#include <vector>
#include <thread>
#include <atomic>
#include <set>

struct TestNode {
    int data;
    TestNode* next;
};

void test_address_reuse(int iterations) {
    std::set<void*> seen_addresses;
    int reuse_count = 0;

    for (int i = 0; i < iterations; ++i) {
        TestNode* node = new TestNode{i, nullptr};

        if (seen_addresses.count(node) > 0) {
            ++reuse_count;
            std::cout << "Address reused: " << node
                      << " at iteration " << i << std::endl;
        }
        seen_addresses.insert(node);

        delete node;
        // 注意：删除后地址可能被立即重用
    }

    std::cout << "Total allocations: " << iterations << std::endl;
    std::cout << "Address reuses detected: " << reuse_count << std::endl;
    std::cout << "Reuse rate: " << (100.0 * reuse_count / iterations) << "%" << std::endl;
}

// 使用不同分配器运行：
// 默认: ./test
// tcmalloc: LD_PRELOAD=/usr/lib/libtcmalloc.so ./test
// jemalloc: LD_PRELOAD=/usr/lib/libjemalloc.so ./test
```

**实验结果分析方法**

```cpp
// 预期结果：
// 1. 默认glibc malloc：小对象快速重用（通常>50%重用率）
// 2. tcmalloc：线程本地缓存，重用率高
// 3. jemalloc：分桶策略，相同大小对象重用率高

// 关键观察点：
// 1. 多线程情况下重用行为会改变
// 2. 不同大小的对象重用模式不同
// 3. 压力测试下重用更频繁
```

---

#### 面试高频题

**题目1：什么是ABA问题？请举例说明**

**参考答案：**
```
ABA问题是CAS操作中的一个经典问题。当一个线程读取某个值A，准备用CAS
将其更新为B时，另一个线程可能已经将该值从A改为B，再改回A。此时第一
个线程的CAS操作会成功，但它无法察觉中间发生的变化。

举例：无锁栈的pop操作
1. 初始状态：head -> A -> B -> C
2. 线程1执行pop，读取old_head=A，准备将head改为B
3. 线程1被抢占
4. 线程2执行两次pop，删除A和B
5. 线程2执行push，分配的新节点恰好在A的地址
6. 现在：head -> A'(新) -> D
7. 线程1恢复，CAS(head, A, B)成功！
8. 但B已经被删除，导致内存错误
```

**延伸问题：**
- ABA问题只存在于无锁编程中吗？
- 为什么引用计数不能解决ABA问题？

---

**题目2：如何解决ABA问题？各方案的优缺点？**

**参考答案：**
```
主要解决方案：

1. 版本计数/标签指针
   优点：简单直接，开销可预测
   缺点：需要double-width CAS，某些平台不支持

2. 危险指针（Hazard Pointers）
   优点：内存开销固定，适合长时间持有
   缺点：每次访问有额外开销，实现复杂

3. Epoch-Based Reclamation
   优点：批量回收效率高，读操作开销低
   缺点：如果线程阻塞会阻止回收

4. 垃圾回收（GC语言）
   优点：程序员无需关心
   缺点：只适用于有GC的语言/环境
```

---

**题目3：实现一个简单的Tagged Pointer**

**参考答案：**
```cpp
// 利用指针对齐的低位存储标签
template <typename T, size_t TagBits = 3>
class TaggedPtr {
    static_assert(alignof(T) >= (1 << TagBits),
                  "Type alignment insufficient for tag bits");

    uintptr_t data_;
    static constexpr uintptr_t TAG_MASK = (1 << TagBits) - 1;
    static constexpr uintptr_t PTR_MASK = ~TAG_MASK;

public:
    TaggedPtr(T* ptr = nullptr, uintptr_t tag = 0)
        : data_(reinterpret_cast<uintptr_t>(ptr) | (tag & TAG_MASK)) {}

    T* ptr() const { return reinterpret_cast<T*>(data_ & PTR_MASK); }
    uintptr_t tag() const { return data_ & TAG_MASK; }

    TaggedPtr with_tag(uintptr_t new_tag) const {
        return TaggedPtr(ptr(), new_tag);
    }

    bool operator==(const TaggedPtr& other) const {
        return data_ == other.data_;
    }
};
```

---

#### 练习与作业

**编程练习1：复现ABA问题**
```cpp
// 任务：编写一个程序，能够可靠地触发ABA问题
// 要求：
// 1. 实现一个简单的无锁栈（不带ABA防护）
// 2. 使用自定义分配器确保地址重用
// 3. 多线程并发操作，观察ABA现象
// 4. 记录每次ABA的发生时机

// 提示：
// - 使用原子计数器记录每个地址的使用次数
// - 在CAS前后打印调试信息
// - 可以使用sleep增加窗口期
```

**编程练习2：检测ABA的工具**
```cpp
// 任务：实现一个ABA检测器
// 要求：
// 1. 包装std::atomic<T*>，记录所有CAS操作
// 2. 检测潜在的ABA场景（地址重用）
// 3. 生成警告报告

// 接口：
template <typename T>
class ABADetector {
public:
    T* load();
    void store(T* ptr);
    bool compare_exchange(T*& expected, T* desired);
    void report_potential_aba();  // 打印检测报告
};
```

**思考题：**

1. 如果内存永远不释放（只增长），ABA问题还会存在吗？这种方法实际可行吗？

2. 在哪些场景下，ABA问题不需要特别处理？（提示：考虑数据的语义）

3. C++20的`std::atomic<std::shared_ptr<T>>`能解决ABA问题吗？为什么？

---

#### 本周检验点

**知识检验（口头回答或书面）**
- [ ] 能清晰解释ABA问题的定义和触发条件
- [ ] 能画出ABA问题的时序图
- [ ] 能解释为什么CAS无法检测ABA
- [ ] 能列举至少3种解决ABA的方法
- [ ] 能解释内存分配器地址重用的机制

**代码检验**
- [ ] 完成BuggyStack的实现和分析
- [ ] 成功复现ABA问题（通过测试程序）
- [ ] 完成ABA检测器的基本实现
- [ ] 代码通过编译，无警告

---

### 第二周：版本计数解决方案

**学习目标**：使用版本号/计数器解决ABA

#### Tagged Pointer（标签指针）
```cpp
// 在指针中嵌入版本号
// 64位系统上，高16位通常不用于地址（取决于架构）
// 或者使用对齐保证的低位

template <typename T>
class TaggedPtr {
    // 使用union或位操作
    // 假设T*是8字节对齐，低3位可用
    uintptr_t data_;

    static constexpr uintptr_t TAG_MASK = 0x7;  // 低3位
    static constexpr uintptr_t PTR_MASK = ~TAG_MASK;

public:
    TaggedPtr() : data_(0) {}
    TaggedPtr(T* ptr, unsigned tag)
        : data_(reinterpret_cast<uintptr_t>(ptr) | (tag & TAG_MASK)) {}

    T* ptr() const {
        return reinterpret_cast<T*>(data_ & PTR_MASK);
    }

    unsigned tag() const {
        return data_ & TAG_MASK;
    }

    bool operator==(const TaggedPtr& other) const {
        return data_ == other.data_;
    }
};

// 使用128位CAS可以存更大的计数器
struct alignas(16) PtrWithCounter {
    void* ptr;
    uint64_t counter;
};
```

#### 使用版本号的无锁栈
```cpp
template <typename T>
class ABASafeStack {
    struct Node {
        T data;
        Node* next;
    };

    struct alignas(16) Head {
        Node* ptr;
        uint64_t counter;  // 版本号，每次修改递增
    };

    std::atomic<Head> head_{{nullptr, 0}};

public:
    void push(T value) {
        Node* new_node = new Node{std::move(value), nullptr};
        Head old_head = head_.load(std::memory_order_relaxed);
        Head new_head;
        do {
            new_node->next = old_head.ptr;
            new_head = {new_node, old_head.counter + 1};
        } while (!head_.compare_exchange_weak(old_head, new_head,
                    std::memory_order_release,
                    std::memory_order_relaxed));
    }

    std::optional<T> pop() {
        Head old_head = head_.load(std::memory_order_relaxed);
        Head new_head;
        do {
            if (old_head.ptr == nullptr) {
                return std::nullopt;
            }
            new_head = {old_head.ptr->next, old_head.counter + 1};
        } while (!head_.compare_exchange_weak(old_head, new_head,
                    std::memory_order_acquire,
                    std::memory_order_relaxed));

        T result = std::move(old_head.ptr->data);
        delete old_head.ptr;  // 仍然有问题！
        return result;
    }
};

// 版本号解决了ABA，但内存回收问题仍然存在
// 在delete之前，其他线程可能正在读取old_head.ptr->next
```

---

### 第二周扩展内容

#### 每日学习安排

**Day 1: Tagged Pointer原理（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 学习指针对齐和低位利用原理 | 1.5h |
| 理论 | 研究x86-64地址空间布局和可用位 | 1h |
| 实践 | 实现基本的TaggedPtr类 | 2h |
| 复习 | 整理不同平台的对齐要求 | 0.5h |

**Day 2: 128位CAS深入研究（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 学习CMPXCHG16B指令原理 | 1.5h |
| 理论 | 研究std::atomic对128位类型的支持 | 1h |
| 实践 | 编写跨平台的double-width CAS封装 | 2h |
| 复习 | 对比不同平台的支持情况 | 0.5h |

**Day 3: ABASafeStack实现（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 分析示例代码的设计思路 | 1h |
| 实践 | 从零实现ABASafeStack | 3h |
| 测试 | 编写单元测试和并发测试 | 0.5h |
| 复习 | 分析实现中的内存序选择 | 0.5h |

**Day 4: 版本计数的变体（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 学习Split Reference Count技术 | 1.5h |
| 理论 | 研究部分版本号（Partial Tagging）策略 | 1.5h |
| 实践 | 实现一种变体方案 | 1.5h |
| 复习 | 对比各变体的适用场景 | 0.5h |

**Day 5: 性能测试与分析（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 实践 | 搭建性能测试框架 | 1.5h |
| 实践 | 对比有/无版本计数的性能差异 | 2h |
| 实践 | 分析128位CAS的开销 | 1h |
| 复习 | 整理性能数据和结论 | 0.5h |

**Day 6: 源码阅读（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 阅读 | 研究folly的AtomicStruct实现 | 2h |
| 阅读 | 研究Boost.Lockfree的tagged pointer实现 | 2h |
| 复习 | 总结工业级实现的技巧 | 1h |

**Day 7: 周总结与实战（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 复习 | 回顾本周所有概念 | 1h |
| 实践 | 完成编程练习 | 2.5h |
| 测试 | 完成知识检验题 | 1h |
| 总结 | 撰写学习笔记 | 0.5h |

---

#### 扩展阅读资源

**必读（优先级：高）**
- [ ] Intel手册：CMPXCHG8B/CMPXCHG16B指令详解
- [ ] cppreference：[std::atomic](https://en.cppreference.com/w/cpp/atomic/atomic) 特别是is_always_lock_free
- [ ] 博客：[Preshing - Double-Checked Locking is Fixed In C++11](https://preshing.com/20130930/double-checked-locking-is-fixed-in-cpp11/)

**推荐阅读（优先级：中）**
- [ ] CppCon 2016：[Hans Boehm - Using weakly ordered C++ atomics correctly](https://www.youtube.com/watch?v=M15UKpNlpeM)
- [ ] Boost.Lockfree文档：[Tagged Pointer](https://www.boost.org/doc/libs/release/doc/html/lockfree.html)
- [ ] 论文：[Split-Ordered Lists: Lock-Free Extensible Hash Tables](https://www.cs.ucf.edu/~dcm/Teaching/COT4810-Spring2011/Literature/SplitOrderedLists.pdf)

**深入研究（优先级：低）**
- [ ] ARM文档：LDXP/STXP指令（ARM的128位原子操作）
- [ ] RISC-V原子扩展规范

---

#### 工程实践深度解析

**跨平台128位原子操作**

```cpp
// 不同平台的128位CAS支持情况

// x86-64: CMPXCHG16B（需要16字节对齐）
// 编译器标志：-mcx16（GCC/Clang）
#if defined(__x86_64__) || defined(_M_X64)
    #ifdef __GNUC__
        // GCC/Clang内置支持
        __atomic_compare_exchange_16(ptr, expected, desired, ...);
    #elif defined(_MSC_VER)
        // MSVC使用intrinsic
        _InterlockedCompareExchange128(ptr, high, low, result);
    #endif
#endif

// ARM64: LDXP/STXP指令对
#if defined(__aarch64__)
    // 通常由编译器自动生成
    // 注意：需要LL/SC循环
#endif

// 通用实现（带锁的fallback）
template <typename T>
class Atomic128 {
    alignas(16) T value_;
    mutable std::mutex mtx_;  // fallback锁

public:
    bool compare_exchange_strong(T& expected, T desired) {
        #if HAS_NATIVE_128BIT_CAS
            return __atomic_compare_exchange_n(&value_, &expected, desired,
                                               false, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST);
        #else
            std::lock_guard<std::mutex> lock(mtx_);
            if (value_ == expected) {
                value_ = desired;
                return true;
            }
            expected = value_;
            return false;
        #endif
    }
};
```

**版本号溢出问题分析**

```cpp
// 版本号溢出的实际风险评估

// 假设：
// - 64位计数器
// - 每秒100万次CAS操作（极端高频）
// - 7x24小时运行

// 计算：
// 每年操作次数 = 1,000,000 * 3600 * 24 * 365 ≈ 3.15 × 10^13
// 64位上限 = 1.84 × 10^19
// 溢出需要时间 = 1.84 × 10^19 / 3.15 × 10^13 ≈ 584,000年

// 结论：64位计数器在实际应用中不可能溢出
// 但如果使用Tagged Pointer的低3位（只有8个值），则很快就会溢出！

// 32位计数器的风险
// 32位上限 = 4.29 × 10^9
// 溢出时间 = 4.29 × 10^9 / 10^6 ≈ 4290秒 ≈ 1.2小时
// 结论：32位计数器在高负载下可能溢出！

// 安全实践：
// 1. 优先使用64位计数器
// 2. 如果使用低位标签，确保溢出是安全的（tag只用于区分，不用于计数）
// 3. 如果必须使用小计数器，考虑其他解决方案
```

**常见陷阱**

```cpp
// 陷阱1: 对齐问题
struct alignas(16) BadAlignment {
    void* ptr;        // 8字节
    uint64_t counter; // 8字节
    // 总共16字节，但可能没有正确对齐！
};

// 正确做法：
struct alignas(16) GoodAlignment {
    void* ptr;
    uint64_t counter;

    // 确保编译器支持
    static_assert(sizeof(GoodAlignment) == 16);
    static_assert(alignof(GoodAlignment) == 16);
};

// 陷阱2: 假设所有平台都支持128位CAS
template <typename T>
class UnsafeStack {
    std::atomic<Head> head_;  // Head是16字节

    void push(T value) {
        // 如果128位CAS不是无锁的，性能会很差！
        static_assert(std::atomic<Head>::is_always_lock_free,
                      "128-bit CAS not supported");
        // ...
    }
};

// 陷阱3: 忘记版本号也需要原子更新
// 错误示例：
void wrong_update() {
    Head h = head_.load();
    h.ptr = new_ptr;
    h.counter++;  // 这不是原子的！
    head_.store(h);  // 可能丢失其他线程的更新
}

// 正确做法：使用CAS
void correct_update() {
    Head old_head = head_.load();
    Head new_head;
    do {
        new_head.ptr = compute_new_ptr(old_head);
        new_head.counter = old_head.counter + 1;
    } while (!head_.compare_exchange_weak(old_head, new_head));
}
```

---

#### 真实案例分析

**案例1: Linux内核的指针标签使用**

```c
// Linux内核在多处使用低位标签
// 例如：radix tree节点类型标识

// include/linux/radix-tree.h
#define RADIX_TREE_ENTRY_MASK     3UL
#define RADIX_TREE_INTERNAL_NODE  1UL
#define RADIX_TREE_EXCEPTIONAL_ENTRY  2UL

// 利用指针低2位标识节点类型
// 因为所有节点都是4字节对齐的

static inline bool radix_tree_is_internal_node(void *ptr) {
    return ((unsigned long)ptr & RADIX_TREE_ENTRY_MASK) ==
            RADIX_TREE_INTERNAL_NODE;
}

// 优点：无需额外存储空间
// 缺点：指针操作时必须清除标签位
```

**案例2: WebKit的MarkedBlock指针压缩**

```cpp
// WebKit的JavaScript引擎使用了类似技术
// 将对象类型信息编码在指针中

// 关键思想：
// 1. 堆分配的对象都在特定对齐的块中
// 2. 块大小是2^N，所以低N位总是0
// 3. 利用这些位存储元数据

// 这种技术广泛用于：
// - JavaScript引擎（V8, SpiderMonkey, JavaScriptCore）
// - JVM实现（压缩指针）
// - Python解释器（小整数缓存）
```

**案例3: 一个版本计数溢出的真实Bug**

```cpp
// 场景：使用16位版本计数器的无锁队列
// 环境：高频交易系统，每秒数百万操作

// Bug表现：
// 运行约18小时后，偶发队列损坏
// 18小时 * 3600秒 * 100万 ≈ 6.5 × 10^10 > 2^16 = 65536

// 根因：
// 开发者使用了Tagged Pointer，只有16位用于版本号
// 高频操作导致版本号溢出回绕

// 溢出后的问题：
// 版本号从65535变成0，恰好和某个历史状态匹配
// CAS操作意外成功，导致ABA问题

// 修复方案：
// 1. 改用64位独立计数器
// 2. 或者使用hazard pointer方案
```

---

#### 对比实验

**实验1：128位CAS性能基准测试**

```cpp
// benchmark_128bit_cas.cpp
#include <atomic>
#include <chrono>
#include <thread>
#include <vector>
#include <iostream>

struct alignas(16) DoubleWord {
    uint64_t lo;
    uint64_t hi;
};

struct SingleWord {
    uint64_t value;
};

std::atomic<DoubleWord> dw_atomic{{0, 0}};
std::atomic<SingleWord> sw_atomic{{0}};

template <typename AtomicType, typename ValueType>
void benchmark_cas(AtomicType& atomic, const char* name, int iterations) {
    auto start = std::chrono::high_resolution_clock::now();

    ValueType expected = atomic.load();
    for (int i = 0; i < iterations; ++i) {
        ValueType desired;
        if constexpr (sizeof(ValueType) == 16) {
            desired = {expected.lo + 1, expected.hi};
        } else {
            desired = {expected.value + 1};
        }
        while (!atomic.compare_exchange_weak(expected, desired)) {
            if constexpr (sizeof(ValueType) == 16) {
                desired = {expected.lo + 1, expected.hi};
            } else {
                desired = {expected.value + 1};
            }
        }
        expected = desired;
    }

    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::nanoseconds>(end - start);

    std::cout << name << ": " << duration.count() / iterations << " ns/op\n";
}

int main() {
    constexpr int ITERATIONS = 10000000;

    std::cout << "Single-threaded benchmark:\n";
    benchmark_cas<std::atomic<SingleWord>, SingleWord>(sw_atomic, "64-bit CAS", ITERATIONS);
    benchmark_cas<std::atomic<DoubleWord>, DoubleWord>(dw_atomic, "128-bit CAS", ITERATIONS);

    // 预期结果：128位CAS约为64位CAS的1.5-3倍时间
    return 0;
}
```

**实验2：不同版本号宽度的空间/时间权衡**

```cpp
// 对比不同方案的内存使用和性能

// 方案A: 使用指针低3位作为标签
// - 额外空间：0字节
// - 标签范围：0-7（很快溢出）
// - 适用：低频操作，或溢出无害的场景

// 方案B: 使用32位计数器（需要对齐填充）
// - 额外空间：4字节（可能更多因为对齐）
// - 标签范围：0-4G
// - 适用：中等频率操作

// 方案C: 使用64位计数器（128位CAS）
// - 额外空间：8字节
// - 标签范围：理论上无限
// - 适用：高频操作，需要最强保证

// 测试代码框架
struct TestResult {
    size_t memory_per_node;
    double ops_per_second;
    bool overflow_possible;
};

TestResult benchmark_scheme_a();  // 低位标签
TestResult benchmark_scheme_b();  // 32位计数器
TestResult benchmark_scheme_c();  // 64位计数器
```

---

#### 面试高频题

**题目1：解释Tagged Pointer的工作原理**

**参考答案：**
```
Tagged Pointer利用了内存对齐的特性。在大多数系统中，堆分配的对象
至少是4或8字节对齐的，这意味着指针的低2-3位总是0。我们可以利用
这些"空闲"位存储额外信息（标签）。

实现要点：
1. 存储时：将标签OR到指针值中
2. 取指针时：将标签位AND掉
3. 取标签时：AND出低位

示例（8字节对齐，低3位可用）：
原始指针: 0x7fff5fbff8a0 (二进制末尾是000)
标签值:   5 (二进制101)
组合后:   0x7fff5fbff8a5

取出指针: 0x7fff5fbff8a5 & ~0x7 = 0x7fff5fbff8a0
取出标签: 0x7fff5fbff8a5 & 0x7 = 5

优点：零额外内存开销
缺点：标签位数有限，必须了解对齐要求
```

---

**题目2：为什么需要16字节对齐才能使用CMPXCHG16B？**

**参考答案：**
```
CMPXCHG16B指令的对齐要求源于x86-64架构的设计：

1. 原子性保证
   - CPU只能原子地操作对齐的数据
   - 16字节数据跨缓存行边界会导致非原子行为
   - 缓存行通常是64字节，起始地址是64的倍数

2. 性能考虑
   - 对齐访问是单次内存事务
   - 非对齐访问需要多次事务并加锁总线

3. 硬件实现
   - CMPXCHG16B在微架构层面需要对齐
   - 非对齐访问会触发#GP（General Protection）异常

如果尝试对非16字节对齐的地址执行CMPXCHG16B：
- 程序会崩溃（SIGBUS或SIGSEGV）
- 在某些CPU上可能是未定义行为

确保对齐的方法：
- 使用alignas(16)属性
- 使用posix_memalign或aligned_alloc分配
- 编译器通常会自动处理std::atomic<T>的对齐
```

---

**题目3：比较版本计数和危险指针的适用场景**

**参考答案：**
```
版本计数（Tagged Pointer/Counter）：
适用场景：
- 数据结构简单（栈、队列头部）
- 需要最简单的实现
- 平台支持128位CAS
- 可以接受double-width指针的空间开销

不适用：
- 平台不支持128位原子操作
- 空间极度敏感
- 需要保护多个指针

危险指针（Hazard Pointers）：
适用场景：
- 需要保护复杂数据结构中的多个指针
- 平台不支持宽原子操作
- 需要精确控制内存回收时机
- 读操作远多于写操作

不适用：
- 线程数量极大（危险指针数组变大）
- 追求最低的读取开销
- 实现复杂度受限

实际工程选择：
- 简单场景优先考虑版本计数
- 复杂场景或库设计考虑危险指针
- 追求性能的读密集场景考虑EBR
```

---

#### 练习与作业

**编程练习1：实现跨平台的128位原子类型**

```cpp
// 任务：实现一个跨平台的Atomic128类
// 要求：
// 1. 在支持的平台上使用原生128位CAS
// 2. 不支持的平台上使用mutex fallback
// 3. 提供is_lock_free()方法
// 4. 支持自定义的16字节类型

template <typename T>
class Atomic128 {
    static_assert(sizeof(T) == 16, "T must be 16 bytes");
    static_assert(alignof(T) == 16, "T must be 16-byte aligned");

public:
    T load(std::memory_order order = std::memory_order_seq_cst);
    void store(T desired, std::memory_order order = std::memory_order_seq_cst);
    bool compare_exchange_strong(T& expected, T desired,
                                 std::memory_order order = std::memory_order_seq_cst);
    bool compare_exchange_weak(T& expected, T desired,
                               std::memory_order order = std::memory_order_seq_cst);
    static constexpr bool is_always_lock_free = /* 平台相关 */;
    bool is_lock_free() const;
};
```

**编程练习2：使用版本计数实现无锁队列**

```cpp
// 任务：实现带版本计数的Michael-Scott无锁队列
// 要求：
// 1. 使用alignas(16)的Head/Tail结构
// 2. 正确处理空队列边界情况
// 3. 编写并发测试证明无ABA问题

template <typename T>
class MSQueue {
    struct Node;
    struct alignas(16) Ptr {
        Node* ptr;
        uint64_t tag;
    };

    std::atomic<Ptr> head_;
    std::atomic<Ptr> tail_;

public:
    void enqueue(T value);
    std::optional<T> dequeue();
};
```

**思考题：**

1. 如果128位CAS不是lock-free的，使用它相比直接用mutex有什么优缺点？

2. 在ARM平台上，LL/SC指令可能会"伪失败"。这对基于版本计数的方案有什么影响？

3. 如果两个指针（如队列的head和tail）都需要原子更新，版本计数方案如何扩展？

---

#### 本周检验点

**知识检验**
- [ ] 能解释Tagged Pointer的原理和限制
- [ ] 能描述128位CAS的平台支持情况
- [ ] 能分析版本计数器溢出的风险
- [ ] 能比较版本计数和其他方案的优缺点

**代码检验**
- [ ] 实现并测试ABASafeStack
- [ ] 完成128位原子类型的封装
- [ ] 性能测试显示合理的结果
- [ ] 代码通过ThreadSanitizer检测

---

### 第三周：危险指针（Hazard Pointers）

**学习目标**：掌握危险指针的原理和实现

#### 危险指针概念
```cpp
// 核心思想：
// 每个线程声明它正在访问的指针
// 释放内存前，检查是否有线程正在使用

// 每个线程有若干个"危险指针槽"
// 访问共享内存前，将地址放入危险指针
// 完成访问后，清除危险指针
// 释放内存前，检查所有线程的危险指针

class HazardPointer {
    static constexpr int MAX_THREADS = 64;
    static constexpr int HAZARDS_PER_THREAD = 2;

    struct HazardRecord {
        std::atomic<void*> hazards[HAZARDS_PER_THREAD];
        std::atomic<bool> active{false};
    };

    static HazardRecord records_[MAX_THREADS];
    static thread_local int my_index_;

public:
    // 获取一个危险指针槽
    template <typename T>
    class Guard {
        std::atomic<void*>* slot_;
    public:
        Guard() : slot_(nullptr) {}

        T* protect(std::atomic<T*>& src) {
            // 分配槽位
            if (!slot_) {
                for (int i = 0; i < HAZARDS_PER_THREAD; ++i) {
                    void* expected = nullptr;
                    if (records_[my_index_].hazards[i]
                            .compare_exchange_strong(expected, reinterpret_cast<void*>(1))) {
                        slot_ = &records_[my_index_].hazards[i];
                        break;
                    }
                }
            }

            T* ptr;
            do {
                ptr = src.load(std::memory_order_relaxed);
                slot_->store(ptr, std::memory_order_release);
                // 需要重新检查，因为在store之前src可能已经改变
            } while (ptr != src.load(std::memory_order_acquire));

            return ptr;
        }

        void reset() {
            if (slot_) {
                slot_->store(nullptr, std::memory_order_release);
            }
        }

        ~Guard() {
            reset();
        }
    };

    // 检查指针是否被任何线程保护
    static bool is_hazardous(void* ptr) {
        for (int i = 0; i < MAX_THREADS; ++i) {
            if (!records_[i].active.load(std::memory_order_relaxed)) continue;
            for (int j = 0; j < HAZARDS_PER_THREAD; ++j) {
                if (records_[i].hazards[j].load(std::memory_order_acquire) == ptr) {
                    return true;
                }
            }
        }
        return false;
    }

    // 延迟释放
    static void retire(void* ptr, void (*deleter)(void*)) {
        // 添加到待释放列表
        // 定期扫描并释放安全的指针
    }
};
```

#### 使用危险指针的无锁栈
```cpp
template <typename T>
class HazardPointerStack {
    struct Node {
        T data;
        std::atomic<Node*> next;
    };

    std::atomic<Node*> head_{nullptr};

public:
    void push(T value) {
        Node* new_node = new Node{std::move(value)};
        Node* old_head = head_.load(std::memory_order_relaxed);
        do {
            new_node->next.store(old_head, std::memory_order_relaxed);
        } while (!head_.compare_exchange_weak(old_head, new_node,
                    std::memory_order_release,
                    std::memory_order_relaxed));
    }

    std::optional<T> pop() {
        HazardPointer::Guard<Node> guard;
        Node* old_head;

        do {
            old_head = guard.protect(head_);  // 保护当前head
            if (old_head == nullptr) {
                return std::nullopt;
            }
        } while (!head_.compare_exchange_weak(old_head, old_head->next,
                    std::memory_order_acquire,
                    std::memory_order_relaxed));

        guard.reset();  // 不再需要保护

        T result = std::move(old_head->data);
        // 安全地延迟释放
        HazardPointer::retire(old_head, [](void* p) { delete static_cast<Node*>(p); });

        return result;
    }
};
```

---

### 第三周扩展内容

#### 每日学习安排

**Day 1: 危险指针核心概念（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 精读Hazard Pointers原论文（Maged Michael） | 2.5h |
| 理论 | 理解HP的数学正确性证明 | 1h |
| 实践 | 画出HP的工作流程图 | 1h |
| 复习 | 整理论文中的关键定理 | 0.5h |

**Day 2: 危险指针API设计（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 分析示例代码中的Guard模式 | 1h |
| 理论 | 学习RAII在HP中的应用 | 1h |
| 实践 | 设计自己的HP API | 2h |
| 复习 | 对比不同库的API设计 | 1h |

**Day 3: 危险指针实现（上）（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 实践 | 实现HazardPointerRecord结构 | 1.5h |
| 实践 | 实现线程注册/注销机制 | 2h |
| 实践 | 实现protect()函数 | 1h |
| 测试 | 编写基本单元测试 | 0.5h |

**Day 4: 危险指针实现（下）（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 实践 | 实现retire()和延迟释放列表 | 2h |
| 实践 | 实现scan()批量回收函数 | 2h |
| 测试 | 验证回收的正确性 | 0.5h |
| 复习 | 分析实现中的内存序选择 | 0.5h |

**Day 5: 性能优化与测试（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 实践 | 优化scan()的效率（排序+二分查找） | 1.5h |
| 实践 | 添加批量处理优化 | 1.5h |
| 测试 | 多线程压力测试 | 1.5h |
| 分析 | 分析性能瓶颈 | 0.5h |

**Day 6: 源码阅读与对比（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 阅读 | 研究folly的HazardPointer实现 | 2.5h |
| 阅读 | 研究libcds的HP实现 | 1.5h |
| 复习 | 总结工业级优化技巧 | 1h |

**Day 7: 周总结与集成测试（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 实践 | 使用HP改造之前的无锁栈 | 2h |
| 测试 | 完整的并发正确性测试 | 1.5h |
| 复习 | 完成知识检验 | 1h |
| 总结 | 撰写学习笔记 | 0.5h |

---

#### 扩展阅读资源

**必读（优先级：高）**
- [ ] 论文：[Hazard Pointers: Safe Memory Reclamation for Lock-Free Objects](https://www.cs.otago.ac.nz/cosc440/readings/hazard-pointers.pdf) - Maged M. Michael
- [ ] C++提案：[P2530 - Hazard Pointers for C++26](https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2023/p2530r3.pdf)
- [ ] folly文档：[HazardPointer.h](https://github.com/facebook/folly/blob/main/folly/synchronization/HazardPointer.h)

**推荐阅读（优先级：中）**
- [ ] CppCon 2017：[P2530 Hazard Pointers](https://www.youtube.com/watch?v=lLBRLvs7D5Q)
- [ ] 博客：[1024cores - Safe Memory Reclamation](http://www.1024cores.net/home/lock-free-algorithms/safe-memory-reclamation)
- [ ] 论文：[Practical lock-freedom](https://www.cl.cam.ac.uk/techreports/UCAM-CL-TR-579.pdf) - Keir Fraser

**深入研究（优先级：低）**
- [ ] 论文：[Hazard Eras - Non-Blocking Memory Reclamation](https://arxiv.org/abs/1712.01044)
- [ ] libcds源码：[Hazard Pointer实现](https://github.com/khizmax/libcds)

---

#### 工程实践深度解析

**危险指针的完整生命周期**

```cpp
// 完整的危险指针使用流程图解

// 步骤1: 线程获取危险指针槽
// ┌─────────────────────────────────────────┐
// │ Thread 1 requests HP slot              │
// │ HP Record: [slot0: null, slot1: null]  │
// └─────────────────────────────────────────┘

// 步骤2: 保护指针
// ┌─────────────────────────────────────────┐
// │ Thread 1 wants to access node A        │
// │ 1. Load A's address from shared ptr    │
// │ 2. Store A in HP slot0                 │
// │ 3. Re-check shared ptr still points A  │
// │ 4. If changed, retry from step 1       │
// │                                        │
// │ HP Record: [slot0: &A, slot1: null]    │
// └─────────────────────────────────────────┘

// 为什么需要重新检查？
void protect_with_explanation() {
    Node* ptr;
    do {
        ptr = shared_.load();           // (1) 读取共享指针
        hp_slot_.store(ptr);            // (2) 存入危险指针
        std::atomic_thread_fence(std::memory_order_seq_cst);
        // 在(1)和(2)之间，其他线程可能已经删除了ptr指向的节点
        // 所以需要重新检查
    } while (ptr != shared_.load());    // (3) 确认还是同一个
    // 现在可以安全访问ptr
}

// 步骤3: 延迟删除
// ┌─────────────────────────────────────────┐
// │ Thread 2 wants to delete node A        │
// │ Instead of: delete A                   │
// │ Do: retire_list.push(A)                │
// └─────────────────────────────────────────┘

// 步骤4: 扫描并回收
// ┌─────────────────────────────────────────┐
// │ When retire_list is large enough:      │
// │ 1. Collect all HP values from threads  │
// │ 2. Sort HP values                      │
// │ 3. For each retired ptr:               │
// │    - If NOT in HP set: safe to delete  │
// │    - If in HP set: keep for later      │
// └─────────────────────────────────────────┘
```

**危险指针数量的选择**

```cpp
// 危险指针数量 K 的选择策略

// 规则：K >= 最大同时需要保护的指针数

// 示例1: 无锁栈的pop
// 需要保护: 当前head节点
// K = 1 足够

// 示例2: 无锁队列的dequeue
// 需要保护: head节点 + head->next节点
// K = 2 足够

// 示例3: 无锁链表的查找+删除
// 需要保护: 前驱节点 + 当前节点 + 后继节点
// K = 3 足够

// 示例4: 无锁跳表的插入
// 需要保护: 每层的前驱和后继
// K = 2 * 最大层数 (可能需要20-40个)

// 内存开销分析：
// 每线程: K * sizeof(void*) = K * 8字节
// 全局: N * K * 8字节 (N = 线程数)
// 对于64线程 × 4个HP: 64 * 4 * 8 = 2KB

// 性能开销：
// scan()需要检查 N * K 个指针
// 使用排序+二分可以优化到 O(R * log(NK))
// R = 待回收指针数
```

**常见陷阱**

```cpp
// 陷阱1: 忘记重新验证
Node* buggy_protect(std::atomic<Node*>& shared) {
    Node* ptr = shared.load();
    hp_slot_.store(ptr);
    return ptr;  // 错误！没有重新验证
}

// 陷阱2: 过早释放危险指针
void buggy_use() {
    Node* ptr = protect(shared_);
    hp_slot_.store(nullptr);  // 错误！还在使用ptr
    int value = ptr->data;    // 可能访问已释放内存
}

// 陷阱3: 危险指针槽不足
void buggy_multi_protect() {
    // 假设只有2个槽
    Node* a = protect(shared_a_, 0);
    Node* b = protect(shared_b_, 1);
    Node* c = protect(shared_c_, ???);  // 槽不够了！
}

// 陷阱4: scan中的ABA
void buggy_scan() {
    std::vector<void*> hazards;
    for (auto& record : all_records_) {
        // 收集时，HP值可能正在变化！
        hazards.push_back(record.hp.load());
    }
    // 在收集过程中，某个线程可能已经:
    // 1. 释放了旧指针
    // 2. 设置了新指针
    // 但我们收集的是旧指针值
    // 这是安全的！因为旧指针在retire列表中，不会被误删
}

// 陷阱5: 线程退出时的清理
class ThreadState {
    ~ThreadState() {
        // 必须确保所有HP都已清除
        for (auto& hp : hazard_ptrs_) {
            hp.store(nullptr);
        }
        // 必须处理本线程的retire列表
        // 可以转移给其他线程或强制等待回收
    }
};
```

---

#### 真实案例分析

**案例1: folly HazardPointer的优化技巧**

```cpp
// folly的实现包含多项优化：

// 优化1: 线程本地缓存HP记录
// 避免每次都从全局数组中查找
thread_local HazardPointerRecord* cached_record_ = nullptr;

// 优化2: 分片的retire列表
// 减少全局锁竞争
struct ShardedRetireList {
    static constexpr int SHARDS = 8;
    std::vector<RetiredPtr> shards_[SHARDS];
    std::mutex mutexes_[SHARDS];

    void retire(void* ptr, int shard = random()) {
        std::lock_guard lock(mutexes_[shard % SHARDS]);
        shards_[shard % SHARDS].push_back(ptr);
    }
};

// 优化3: 惰性扫描
// 只在retire列表达到阈值时才扫描
constexpr size_t SCAN_THRESHOLD = 1000;

// 优化4: 自适应域
// 不同数据结构使用不同的HP域，减少扫描范围
```

**案例2: libcds的HP实现细节**

```cpp
// libcds使用了一些有趣的设计：

// 1. HP记录使用侵入式链表
// 便于遍历，避免额外内存分配
struct HPRecord {
    std::atomic<void*> hazard_[MAX_HP];
    std::atomic<HPRecord*> next_;
    std::atomic<bool> free_;  // 是否可被重用
};

// 2. 使用位图加速扫描
// 快速判断HP是否被使用
struct HPBitmap {
    std::atomic<uint64_t> bits_;  // 每位表示一个HP槽

    bool any_set() {
        return bits_.load() != 0;
    }
};

// 3. 支持异步回收
// retire可以指定回调函数，而不是直接delete
void retire(void* ptr, std::function<void(void*)> deleter);
```

**案例3: 一个真实的HP使用错误**

```cpp
// 场景：无锁哈希表的lookup操作
// 错误：HP保护范围不足

class BuggyHashTable {
    Node* lookup(Key key) {
        HPGuard guard;
        Node* bucket = guard.protect(buckets_[hash(key)]);

        // 遍历bucket链表
        while (bucket) {
            if (bucket->key == key) {
                return bucket;  // Bug! 返回后HP失效
            }
            bucket = bucket->next;  // Bug! next没有被保护
        }
        return nullptr;
    }
};

// 修复版本
class CorrectHashTable {
    std::optional<Value> lookup(Key key) {
        HPGuard guard1, guard2;
        Node* bucket = guard1.protect(buckets_[hash(key)]);

        while (bucket) {
            if (bucket->key == key) {
                // 在HP保护下复制值
                Value result = bucket->value;
                return result;  // 返回副本，不是指针
            }
            // 保护next指针
            Node* next = guard2.protect(bucket->next);
            guard1.reset();
            std::swap(guard1, guard2);
            bucket = next;
        }
        return std::nullopt;
    }
};
```

---

#### 对比实验

**实验1：危险指针vs引用计数性能对比**

```cpp
// benchmark_hp_vs_refcount.cpp
#include <atomic>
#include <chrono>
#include <thread>
#include <vector>
#include <memory>

// 方案A: 使用shared_ptr（引用计数）
template <typename T>
class RefCountStack {
    struct Node {
        T data;
        std::shared_ptr<Node> next;
    };
    std::atomic<std::shared_ptr<Node>> head_;

public:
    void push(T value);
    std::optional<T> pop();
};

// 方案B: 使用危险指针
template <typename T>
class HPStack {
    struct Node {
        T data;
        Node* next;
    };
    std::atomic<Node*> head_;
    HazardPointerDomain hp_;

public:
    void push(T value);
    std::optional<T> pop();
};

// 测试场景
void benchmark_scenario(const char* name, auto& stack, int threads, int ops) {
    auto start = std::chrono::high_resolution_clock::now();

    std::vector<std::thread> workers;
    for (int t = 0; t < threads; ++t) {
        workers.emplace_back([&, ops]() {
            for (int i = 0; i < ops; ++i) {
                if (i % 2 == 0) {
                    stack.push(i);
                } else {
                    stack.pop();
                }
            }
        });
    }

    for (auto& w : workers) w.join();

    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

    std::cout << name << ": " << duration.count() << "ms\n";
}

// 预期结果：
// - 低竞争时：shared_ptr可能略快（原子引用计数已高度优化）
// - 高竞争时：HP可能更快（避免引用计数的缓存行乒乓）
// - 内存使用：HP更低（无需存储引用计数）
```

**实验2：不同HP数量的性能影响**

```cpp
// 测试HP槽数量对性能的影响

// 假设：无锁链表遍历，需要保护多个节点
void benchmark_hp_count() {
    // 配置1: 只有1个HP槽
    // - 每次只能保护1个节点
    // - 遍历时需要频繁更换保护

    // 配置2: 有2个HP槽
    // - 可以同时保护当前和下一个节点
    // - 乒乓式使用

    // 配置3: 有4个HP槽
    // - 可以批量保护多个节点
    // - 更少的保护操作

    // 测试不同遍历长度下的性能差异
    for (int list_length : {10, 100, 1000, 10000}) {
        test_traversal(1, list_length);  // 1个HP
        test_traversal(2, list_length);  // 2个HP
        test_traversal(4, list_length);  // 4个HP
    }

    // 预期结论：
    // - HP数量增加可以提高遍历性能
    // - 但scan()开销也会增加
    // - 需要根据实际使用模式选择最优配置
}
```

---

#### 面试高频题

**题目1：解释危险指针的工作原理**

**参考答案：**
```
危险指针（Hazard Pointers）是一种安全的内存回收机制。

核心思想：
每个线程在访问共享内存前，先将该地址"发布"到一个全局可见的位置。
删除内存前，检查是否有任何线程正在使用它。

工作流程：
1. 保护阶段（读取端）：
   - 读取共享指针到本地
   - 将地址存入本线程的HP槽
   - 重新检查共享指针是否变化（避免保护过期指针）
   - 如果变化，重试；否则可以安全访问

2. 退役阶段（删除端）：
   - 不直接删除，而是加入retire列表
   - 当retire列表达到阈值时触发扫描

3. 扫描阶段（回收）：
   - 收集所有线程的HP值
   - 对于retire列表中的每个指针：
     - 如果不在HP集合中，可以安全删除
     - 如果在HP集合中，保留待后续处理

正确性保证：
如果指针P在retire列表中且不被任何HP保护，说明：
- 所有当前访问P的线程已经完成访问（否则P会在某个HP中）
- 新的访问者无法获取P（P已从数据结构中移除）
```

---

**题目2：危险指针的protect()为什么需要循环重试？**

**参考答案：**
```cpp
// 问题场景演示：
Node* buggy_protect(std::atomic<Node*>& shared) {
    Node* ptr = shared.load();  // 时刻T1: ptr = A
    // ---- 其他线程在此删除A ----
    hp_.store(ptr);             // 时刻T2: 保护了已删除的A！
    return ptr;                  // 危险：A可能已被释放
}

// 为什么会出问题？
// 在T1到T2之间存在窗口期，其他线程可能：
// 1. 将shared从A改为B
// 2. 将A加入retire列表
// 3. 执行scan()并删除A（因为此时没有HP保护A）

// 正确做法：
Node* correct_protect(std::atomic<Node*>& shared) {
    Node* ptr;
    do {
        ptr = shared.load();    // 读取当前值
        hp_.store(ptr);         // 声明保护
        std::atomic_thread_fence(std::memory_order_seq_cst);
        // 重新检查：如果shared仍然是ptr，说明：
        // 1. ptr还没有被从数据结构中移除
        // 2. 或者即使被移除，我们的HP已经生效，不会被回收
    } while (ptr != shared.load());
    return ptr;
}

// 关键洞察：
// 重试循环保证了"HP发布"发生在"指针被移除"之前
// 这是一个 happens-before 关系的建立过程
```

---

**题目3：如何选择危险指针和EBR？**

**参考答案：**
```
危险指针 vs EBR 的选择取决于使用场景：

危险指针更适合：
1. 读操作可能长时间持有指针（如复杂遍历）
2. 线程数量较少（<100）
3. 需要确定性的内存回收时机
4. 不能容忍unbounded内存增长

EBR更适合：
1. 读操作快速完成（不会长时间阻塞epoch推进）
2. 读密集型工作负载（读操作开销低）
3. 可以容忍一定的内存延迟回收
4. 所有线程都活跃且频繁执行操作

性能特征对比：
                    HP          EBR
进入临界区开销      较高        很低
退出临界区开销      低          低
内存回收延迟        短          可能长
最坏情况内存        可控        可能失控
实现复杂度          中          中

实际建议：
- 通用库：优先考虑HP（更安全可控）
- 特定优化场景：考虑EBR（如读为主的并发容器）
- 混合方案：某些系统两者结合使用
```

---

#### 练习与作业

**编程练习1：实现完整的危险指针库**

```cpp
// 任务：实现一个生产级的危险指针库
// 要求：
// 1. 支持可配置的HP数量
// 2. 线程安全的注册/注销
// 3. 高效的scan实现（使用排序+二分）
// 4. 支持自定义deleter
// 5. 提供性能统计接口

class HazardPointerDomain {
public:
    // 配置
    struct Config {
        size_t max_threads = 64;
        size_t hp_per_thread = 4;
        size_t scan_threshold = 1000;
    };

    explicit HazardPointerDomain(Config config = {});

    // 获取HP守卫
    class Guard {
    public:
        template <typename T>
        T* protect(std::atomic<T*>& src);
        void reset();
    };

    Guard get_guard();

    // 延迟删除
    template <typename T>
    void retire(T* ptr);

    template <typename T, typename Deleter>
    void retire(T* ptr, Deleter deleter);

    // 统计信息
    struct Stats {
        size_t active_threads;
        size_t total_retired;
        size_t total_reclaimed;
        size_t pending_reclaim;
    };
    Stats get_stats() const;
};
```

**编程练习2：使用危险指针实现无锁链表**

```cpp
// 任务：实现支持并发查找、插入、删除的有序链表
// 要求：
// 1. 使用危险指针保护遍历过程
// 2. 正确处理并发删除
// 3. 编写全面的并发测试

template <typename K, typename V>
class ConcurrentSortedList {
public:
    bool insert(K key, V value);
    bool remove(K key);
    std::optional<V> find(K key);
    void for_each(std::function<void(K, V)> fn);

private:
    struct Node {
        K key;
        V value;
        std::atomic<Node*> next;
        std::atomic<bool> marked;  // 逻辑删除标记
    };

    std::atomic<Node*> head_;
    HazardPointerDomain hp_;

    // 查找key的位置，返回前驱和当前节点
    std::pair<Node*, Node*> find_position(K key,
        HPGuard& guard1, HPGuard& guard2);
};
```

**思考题：**

1. 危险指针的scan()操作需要遍历所有线程。在1000个线程的系统中，这会成为瓶颈吗？如何优化？

2. 如果一个线程在设置HP后立即崩溃，会发生什么？如何处理这种情况？

3. 能否将危险指针和引用计数结合使用？这样做有什么好处？

---

#### 本周检验点

**知识检验**
- [ ] 能解释危险指针的完整工作流程
- [ ] 能说明protect()需要循环重试的原因
- [ ] 能分析HP的内存和性能开销
- [ ] 能比较HP与其他方案的优劣

**代码检验**
- [ ] 完成HazardPointerDomain的基本实现
- [ ] 所有单元测试通过
- [ ] 通过多线程压力测试
- [ ] 使用ThreadSanitizer无报错

---

### 第四周：Epoch-Based Reclamation（EBR）

**学习目标**：理解EBR的原理和实现

#### EBR概念
```cpp
// 核心思想：
// 将时间分为"epoch"（纪元）
// 当所有线程都经历过一个epoch后，该epoch之前的内存可以安全回收

// 优点：
// - 比危险指针更高效（不需要每次访问都设置）
// - 适合读多写少的场景

// 缺点：
// - 如果某个线程长时间不推进epoch，内存无法回收
// - 需要线程协作

class EpochBasedReclamation {
    static constexpr int MAX_THREADS = 64;

    // 全局epoch
    std::atomic<uint64_t> global_epoch_{0};

    // 每个线程的状态
    struct ThreadState {
        std::atomic<uint64_t> local_epoch{0};
        std::atomic<bool> active{false};
        std::vector<void*> retire_lists[3];  // 三个epoch的待回收列表
    };

    static thread_local ThreadState* my_state_;
    ThreadState states_[MAX_THREADS];

public:
    // 进入临界区
    class Guard {
        EpochBasedReclamation& ebr_;
    public:
        Guard(EpochBasedReclamation& ebr) : ebr_(ebr) {
            ebr_.enter();
        }
        ~Guard() {
            ebr_.leave();
        }
    };

    void enter() {
        if (!my_state_) {
            // 分配线程状态
            for (int i = 0; i < MAX_THREADS; ++i) {
                if (!states_[i].active.exchange(true)) {
                    my_state_ = &states_[i];
                    break;
                }
            }
        }

        uint64_t epoch = global_epoch_.load(std::memory_order_relaxed);
        my_state_->local_epoch.store(epoch, std::memory_order_release);
    }

    void leave() {
        my_state_->local_epoch.store(UINT64_MAX, std::memory_order_release);
        try_reclaim();
    }

    void retire(void* ptr) {
        uint64_t epoch = global_epoch_.load(std::memory_order_relaxed);
        my_state_->retire_lists[epoch % 3].push_back(ptr);
    }

private:
    void try_reclaim() {
        uint64_t current = global_epoch_.load(std::memory_order_relaxed);

        // 检查是否可以推进epoch
        bool can_advance = true;
        for (int i = 0; i < MAX_THREADS; ++i) {
            if (!states_[i].active.load(std::memory_order_relaxed)) continue;
            uint64_t local = states_[i].local_epoch.load(std::memory_order_acquire);
            if (local != UINT64_MAX && local != current) {
                can_advance = false;
                break;
            }
        }

        if (can_advance) {
            global_epoch_.compare_exchange_strong(current, current + 1,
                std::memory_order_acq_rel);

            // 回收两个epoch前的内存
            uint64_t safe_epoch = (current + 1) % 3;
            for (void* ptr : my_state_->retire_lists[safe_epoch]) {
                delete ptr;  // 实际使用时需要类型信息
            }
            my_state_->retire_lists[safe_epoch].clear();
        }
    }
};
```

---

## 源码阅读任务

### 深度阅读清单

- [ ] folly的HazardPointer实现
- [ ] crossbeam（Rust）的epoch-based回收
- [ ] libcds的各种回收方案
- [ ] Linux内核的RCU实现

---

## 实践项目

### 项目：实现完整的内存回收方案

#### Part 1: 简化的危险指针
```cpp
// hazard_pointer.hpp
#pragma once
#include <atomic>
#include <vector>
#include <functional>
#include <thread>
#include <algorithm>

class HazardPointerDomain {
    static constexpr size_t MAX_HAZARD_POINTERS = 100;
    static constexpr size_t SCAN_THRESHOLD = 100;

    struct HazardPointerRecord {
        std::atomic<std::thread::id> owner{std::thread::id{}};
        std::atomic<void*> ptr{nullptr};
    };

    HazardPointerRecord hazard_pointers_[MAX_HAZARD_POINTERS];

    struct RetiredNode {
        void* ptr;
        std::function<void(void*)> deleter;
    };

    static thread_local std::vector<RetiredNode> retired_;

public:
    class HazardPointerHolder {
        HazardPointerRecord* record_;

    public:
        HazardPointerHolder() : record_(nullptr) {}

        ~HazardPointerHolder() {
            if (record_) {
                record_->ptr.store(nullptr, std::memory_order_release);
                record_->owner.store(std::thread::id{}, std::memory_order_release);
            }
        }

        HazardPointerHolder(const HazardPointerHolder&) = delete;
        HazardPointerHolder& operator=(const HazardPointerHolder&) = delete;

        HazardPointerHolder(HazardPointerHolder&& other) noexcept
            : record_(other.record_) {
            other.record_ = nullptr;
        }

        template <typename T>
        T* protect(std::atomic<T*>& src, HazardPointerDomain& domain) {
            if (!record_) {
                record_ = domain.acquire_record();
            }

            T* ptr;
            do {
                ptr = src.load(std::memory_order_relaxed);
                record_->ptr.store(ptr, std::memory_order_release);
            } while (ptr != src.load(std::memory_order_acquire));

            return ptr;
        }

        void reset() {
            if (record_) {
                record_->ptr.store(nullptr, std::memory_order_release);
            }
        }
    };

    HazardPointerRecord* acquire_record() {
        auto this_id = std::this_thread::get_id();

        // 尝试获取已有记录
        for (size_t i = 0; i < MAX_HAZARD_POINTERS; ++i) {
            std::thread::id expected{};
            if (hazard_pointers_[i].owner.compare_exchange_strong(
                    expected, this_id, std::memory_order_acq_rel)) {
                return &hazard_pointers_[i];
            }
        }

        throw std::runtime_error("No hazard pointer available");
    }

    template <typename T>
    void retire(T* ptr) {
        retired_.push_back({ptr, [](void* p) { delete static_cast<T*>(p); }});

        if (retired_.size() >= SCAN_THRESHOLD) {
            scan();
        }
    }

    void scan() {
        // 收集所有危险指针
        std::vector<void*> hazardous;
        for (size_t i = 0; i < MAX_HAZARD_POINTERS; ++i) {
            void* p = hazard_pointers_[i].ptr.load(std::memory_order_acquire);
            if (p) {
                hazardous.push_back(p);
            }
        }

        std::sort(hazardous.begin(), hazardous.end());

        // 回收安全的节点
        auto it = std::remove_if(retired_.begin(), retired_.end(),
            [&hazardous](const RetiredNode& node) {
                if (!std::binary_search(hazardous.begin(), hazardous.end(), node.ptr)) {
                    node.deleter(node.ptr);
                    return true;
                }
                return false;
            });

        retired_.erase(it, retired_.end());
    }
};

thread_local std::vector<HazardPointerDomain::RetiredNode>
    HazardPointerDomain::retired_;
```

#### Part 2: 简化的EBR
```cpp
// epoch_reclamation.hpp
#pragma once
#include <atomic>
#include <vector>
#include <functional>
#include <array>

class EpochReclamation {
    static constexpr size_t MAX_THREADS = 64;
    static constexpr uint64_t INACTIVE = UINT64_MAX;

    std::atomic<uint64_t> global_epoch_{0};

    struct ThreadData {
        std::atomic<uint64_t> local_epoch{INACTIVE};
        std::array<std::vector<std::pair<void*, std::function<void(void*)>>>, 3> garbage;
    };

    std::array<ThreadData, MAX_THREADS> thread_data_;
    static thread_local size_t thread_index_;
    static thread_local bool registered_;

    size_t register_thread() {
        for (size_t i = 0; i < MAX_THREADS; ++i) {
            uint64_t expected = INACTIVE;
            if (thread_data_[i].local_epoch.compare_exchange_strong(
                    expected, global_epoch_.load(std::memory_order_relaxed),
                    std::memory_order_acq_rel)) {
                return i;
            }
        }
        throw std::runtime_error("Too many threads");
    }

public:
    class Guard {
        EpochReclamation& er_;
        size_t index_;

    public:
        Guard(EpochReclamation& er) : er_(er) {
            if (!registered_) {
                thread_index_ = er_.register_thread();
                registered_ = true;
            }
            index_ = thread_index_;
            er_.enter(index_);
        }

        ~Guard() {
            er_.leave(index_);
        }

        Guard(const Guard&) = delete;
        Guard& operator=(const Guard&) = delete;
    };

    void enter(size_t index) {
        thread_data_[index].local_epoch.store(
            global_epoch_.load(std::memory_order_relaxed),
            std::memory_order_release);
    }

    void leave(size_t index) {
        thread_data_[index].local_epoch.store(INACTIVE, std::memory_order_release);
        try_advance();
    }

    template <typename T>
    void retire(T* ptr) {
        size_t epoch = global_epoch_.load(std::memory_order_relaxed) % 3;
        thread_data_[thread_index_].garbage[epoch].emplace_back(
            ptr, [](void* p) { delete static_cast<T*>(p); });
    }

private:
    void try_advance() {
        uint64_t current = global_epoch_.load(std::memory_order_relaxed);

        // 检查所有线程是否都在当前epoch或非活跃
        for (size_t i = 0; i < MAX_THREADS; ++i) {
            uint64_t local = thread_data_[i].local_epoch.load(std::memory_order_acquire);
            if (local != INACTIVE && local != current) {
                return;  // 有线程落后
            }
        }

        // 尝试推进epoch
        if (global_epoch_.compare_exchange_strong(current, current + 1,
                std::memory_order_acq_rel)) {
            // 回收安全的内存（两个epoch前的）
            size_t safe_epoch = (current + 2) % 3;
            auto& garbage = thread_data_[thread_index_].garbage[safe_epoch];
            for (auto& [ptr, deleter] : garbage) {
                deleter(ptr);
            }
            garbage.clear();
        }
    }
};

thread_local size_t EpochReclamation::thread_index_ = 0;
thread_local bool EpochReclamation::registered_ = false;
```

---

### 第四周扩展内容

#### 每日学习安排

**Day 1: EBR核心概念（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 理解Epoch/Grace Period/Quiescent State概念 | 1.5h |
| 理论 | 学习EBR与RCU的关系 | 1.5h |
| 实践 | 画出EBR的状态转换图 | 1.5h |
| 复习 | 对比EBR与HP的设计哲学 | 0.5h |

**Day 2: EBR实现原理（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 分析示例代码的设计 | 1h |
| 理论 | 理解epoch推进的条件和正确性 | 1.5h |
| 实践 | 实现基本的EpochReclamation类 | 2h |
| 复习 | 分析内存序的选择 | 0.5h |

**Day 3: 三epoch设计深入（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 理论 | 理解为什么需要3个epoch而不是2个 | 1.5h |
| 实践 | 实现完整的retire和回收逻辑 | 2.5h |
| 测试 | 编写基本正确性测试 | 0.5h |
| 复习 | 分析边界情况 | 0.5h |

**Day 4: 性能优化（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 实践 | 优化enter/leave的开销 | 1.5h |
| 实践 | 实现批量retire和惰性回收 | 2h |
| 测试 | 性能基准测试 | 1h |
| 复习 | 分析优化效果 | 0.5h |

**Day 5: 源码阅读（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 阅读 | 研究crossbeam-epoch的实现 | 2.5h |
| 阅读 | 研究Linux RCU的基本原理 | 1.5h |
| 复习 | 总结工业级实现的技巧 | 1h |

**Day 6: EBR集成与应用（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 实践 | 使用EBR实现无锁链表 | 2.5h |
| 测试 | 多线程并发测试 | 1.5h |
| 分析 | 与HP版本对比性能 | 0.5h |
| 复习 | 整理最佳实践 | 0.5h |

**Day 7: 月度总结（5小时）**
| 时段 | 内容 | 时长 |
|------|------|------|
| 复习 | 回顾本月所有概念 | 1h |
| 实践 | 完成综合项目 | 2h |
| 测试 | 完成所有检验题 | 1.5h |
| 总结 | 撰写月度学习报告 | 0.5h |

---

#### 扩展阅读资源

**必读（优先级：高）**
- [ ] 论文：[Practical lock-freedom](https://www.cl.cam.ac.uk/techreports/UCAM-CL-TR-579.pdf) - Keir Fraser（EBR的原始论文之一）
- [ ] Rust crossbeam文档：[Epoch-based memory reclamation](https://docs.rs/crossbeam-epoch/latest/crossbeam_epoch/)
- [ ] 论文：[Read-Copy Update: A Scalable Lock-Free Memory Management Mechanism](https://www.cs.columbia.edu/~junfeng/17sp-w4118/readings/rcu-sigops.pdf)

**推荐阅读（优先级：中）**
- [ ] Linux文档：[What is RCU, Fundamentally?](https://www.kernel.org/doc/html/latest/RCU/whatisRCU.html)
- [ ] 博客：[1024cores - Epoch-Based Reclamation](http://www.1024cores.net/home/lock-free-algorithms/epoch-based-reclamation)
- [ ] CppCon 2016：[Hans Boehm - C++ Concurrency](https://www.youtube.com/watch?v=ZrNQKpOypqU)

**深入研究（优先级：低）**
- [ ] 论文：[Reclaiming Memory for Lock-Free Data Structures](https://arxiv.org/pdf/1712.01044.pdf) - Interval-Based Reclamation
- [ ] 论文：[Brief Announcement: Hazard Eras](https://drops.dagstuhl.de/opus/volltexte/2016/6087/pdf/LIPIcs-DISC-2016-44.pdf)
- [ ] Linux内核源码：[include/linux/rcupdate.h](https://github.com/torvalds/linux/blob/master/include/linux/rcupdate.h)

---

#### 工程实践深度解析

**EBR的时间线图解**

```cpp
// EBR工作原理的时间线图解

// 假设有3个线程和3个epoch (0, 1, 2)
// 初始状态：global_epoch = 0

// 时刻 T1:
// ┌─────────────────────────────────────────────────────┐
// │ Global Epoch: 0                                    │
// │                                                     │
// │ Thread 1: enter() → local_epoch = 0               │
// │           [开始读取共享数据]                         │
// │                                                     │
// │ Thread 2: retire(ptr_A) → 加入 garbage[0]          │
// │                                                     │
// │ Thread 3: inactive                                  │
// └─────────────────────────────────────────────────────┘

// 时刻 T2:
// ┌─────────────────────────────────────────────────────┐
// │ Global Epoch: 0                                    │
// │                                                     │
// │ Thread 1: 仍在读取 (local_epoch = 0)               │
// │                                                     │
// │ Thread 2: leave()                                   │
// │           尝试推进 epoch...                         │
// │           检查: Thread 1 的 local_epoch != INACTIVE │
// │                 且 local_epoch (0) == global (0)   │
// │           → 可以推进!                               │
// │           Global Epoch: 0 → 1                      │
// └─────────────────────────────────────────────────────┘

// 时刻 T3:
// ┌─────────────────────────────────────────────────────┐
// │ Global Epoch: 1                                    │
// │                                                     │
// │ Thread 1: leave() → local_epoch = INACTIVE         │
// │           enter() → local_epoch = 1                │
// │           [开始新的读取]                            │
// │                                                     │
// │ Thread 2: retire(ptr_B) → 加入 garbage[1]          │
// │           leave()                                   │
// │           检查: Thread 1 的 local_epoch == 1       │
// │           → 可以推进到 epoch 2                      │
// │           Global Epoch: 1 → 2                      │
// │           此时 epoch 0 的垃圾可以回收！             │
// │           → delete ptr_A ✓                         │
// └─────────────────────────────────────────────────────┘

// 关键洞察：
// 1. retire在epoch E的指针，在epoch E+2时才能安全删除
// 2. 因为需要确保所有在epoch E时活跃的线程都已经离开
// 3. 这就是为什么需要3个epoch桶而不是2个
```

**为什么需要3个Epoch？**

```cpp
// 详细解释3-epoch设计

// 假设只有2个epoch：
// 时刻T1: epoch=0, Thread1读取ptr_A
// 时刻T2: epoch=0, Thread2 retire(ptr_A)到bucket[0]
// 时刻T3: Thread2推进到epoch=1
// 时刻T4: epoch=1, Thread2尝试回收bucket[0]...
//         问题！Thread1可能还在读取ptr_A！

// 使用3个epoch：
// 时刻T1: epoch=0, Thread1读取ptr_A (local=0)
// 时刻T2: epoch=0, Thread2 retire(ptr_A)到bucket[0]
// 时刻T3: Thread2推进到epoch=1
//         Thread1必须离开并重新进入（local变成1或INACTIVE）
// 时刻T4: epoch=1, 继续操作...
// 时刻T5: Thread2推进到epoch=2
//         此时确定：所有在epoch=0时活跃的线程
//         要么已经离开，要么local_epoch >= 1
// 时刻T6: epoch=2, 安全回收bucket[0]

// 数学证明：
// 在epoch E retire的指针P
// 在epoch推进到E+2时，所有满足以下条件的线程都已"见证"了epoch E+1：
//   - 线程在epoch E时是活跃的
// 这意味着它们不可能还持有指向P的引用
// 因为它们在离开epoch E时，P还没有被从数据结构中移除
// （retire发生在移除之后）
```

**常见陷阱**

```cpp
// 陷阱1: 忘记进入epoch就访问数据
void buggy_read() {
    // 没有 enter()！
    Node* node = shared_.load();
    int value = node->data;  // 危险！可能访问已删除内存
}

// 陷阱2: 长时间持有epoch
void buggy_long_operation() {
    EpochGuard guard(ebr_);  // 进入epoch

    for (int i = 0; i < 1000000; ++i) {
        process(data_[i]);  // 长时间操作
    }

    // 在此期间，没有任何内存可以被回收！
    // 其他线程的retire列表会无限增长
}

// 正确做法：定期释放
void correct_long_operation() {
    for (int i = 0; i < 1000000; ++i) {
        {
            EpochGuard guard(ebr_);  // 短暂进入
            process(data_[i]);
        }  // 离开，允许回收
    }
}

// 陷阱3: 线程饥饿导致内存泄漏
// 如果一个线程长时间不执行（被阻塞/低优先级）
// 它的local_epoch会一直停留在旧值
// 导致epoch无法推进，内存无法回收

// 解决方案：
// 1. 设计时避免长时间阻塞
// 2. 使用"离线"状态让阻塞线程不参与epoch检查
// 3. 设置超时强制回收（需要额外保护）

// 陷阱4: epoch推进的原子性
void buggy_try_advance() {
    uint64_t current = global_epoch_.load();

    // 检查所有线程...
    bool can_advance = check_all_threads(current);

    if (can_advance) {
        // Bug! 在检查和CAS之间，其他线程可能已经推进了
        global_epoch_.store(current + 1);  // 错误！应该用CAS
    }
}
```

---

#### 真实案例分析

**案例1: Rust crossbeam-epoch的设计**

```rust
// crossbeam-epoch的核心设计思想

// 1. Guard作为epoch的RAII包装
// let guard = epoch::pin();  // 进入当前epoch
// // 使用guard访问共享数据
// drop(guard);  // 离开epoch

// 2. 使用pin计数而不是简单的active标志
// 允许嵌套的pin调用
struct Local {
    pin_count: Cell<usize>,
    epoch: AtomicUsize,
}

impl Local {
    fn pin(&self) -> Guard {
        let count = self.pin_count.get();
        self.pin_count.set(count + 1);

        if count == 0 {
            // 首次pin，更新local epoch
            let global = EPOCH.load(Ordering::Relaxed);
            self.epoch.store(global, Ordering::SeqCst);
        }

        Guard { local: self }
    }
}

// 3. 延迟删除使用闭包
// 可以删除任意类型，不需要运行时类型信息
guard.defer(move || drop(Box::from_raw(ptr)));

// 4. 垃圾收集是分布式的
// 每个线程有自己的garbage bag
// 定期合并到全局列表并尝试回收
```

**案例2: Linux RCU的grace period**

```c
// Linux RCU的核心概念

// 1. Grace Period (宽限期)
// 相当于等待所有当前读者离开
// 在grace period之后，可以安全释放内存

// 2. 实现原理
// 经典RCU使用"静默状态"(quiescent state)检测
// 在内核中，以下情况表示线程经历了静默状态：
// - 上下文切换
// - 进入idle
// - 执行用户态代码

// 3. synchronize_rcu()
// 等待一个完整的grace period
void synchronize_rcu(void) {
    // 等待所有CPU都经历至少一次静默状态
    // 保证所有之前的读者都已完成
}

// 4. call_rcu()
// 异步延迟回调
void call_rcu(struct rcu_head *head,
              rcu_callback_t func) {
    // 注册回调，在grace period后执行
}

// 5. 使用示例
struct my_data {
    int value;
    struct rcu_head rcu;
};

void reader(void) {
    rcu_read_lock();
    struct my_data *p = rcu_dereference(global_ptr);
    int v = p->value;
    rcu_read_unlock();
}

void update(struct my_data *new) {
    struct my_data *old = global_ptr;
    rcu_assign_pointer(global_ptr, new);
    call_rcu(&old->rcu, my_free_callback);
}
```

**案例3: EBR导致的内存暴涨问题**

```cpp
// 场景：高并发数据库系统
// 问题：内存使用量突然暴涨

// 根因分析：
// 1. 系统有128个工作线程
// 2. 每个线程都使用EBR进行内存回收
// 3. 某个线程因为等待磁盘I/O被阻塞了5秒

// 问题发生过程：
// T=0s: 线程42进入epoch=0，开始等待I/O
// T=1s: 其他127个线程正常工作
//       每秒产生100MB待回收内存
//       但因为线程42还在epoch=0，无法推进
// T=5s: 累积500MB待回收内存！
// T=5.1s: 线程42完成I/O，离开epoch
// T=5.2s: epoch开始推进，大量内存被回收

// 解决方案：
// 方案1: 使用quiescent-state-based设计
// 阻塞时主动声明"离线"状态

void thread_blocking() {
    ebr_.go_offline();  // 声明不参与epoch检查
    wait_for_io();
    ebr_.go_online();   // 重新参与
}

// 方案2: 混合回收策略
// 对时间敏感的内存使用HP
// 对批量数据使用EBR

// 方案3: 设置内存上限和强制回收
if (pending_garbage_size() > MAX_PENDING) {
    force_synchronize();  // 强制等待所有线程离开
}
```

---

#### 对比实验

**实验1：EBR vs HP性能对比**

```cpp
// benchmark_ebr_vs_hp.cpp
#include <atomic>
#include <chrono>
#include <thread>
#include <vector>

// 测试场景：读密集型工作负载
// 90%读，10%写

template <typename Reclamation>
void benchmark_read_heavy(Reclamation& recl, int threads, int ops) {
    std::atomic<int> read_count{0};
    std::atomic<int> write_count{0};

    auto start = std::chrono::high_resolution_clock::now();

    std::vector<std::thread> workers;
    for (int t = 0; t < threads; ++t) {
        workers.emplace_back([&]() {
            for (int i = 0; i < ops; ++i) {
                if (rand() % 10 < 9) {
                    // 读操作
                    auto guard = recl.enter();
                    volatile auto ptr = shared_.load();
                    (void)ptr->data;
                    read_count.fetch_add(1);
                } else {
                    // 写操作（替换）
                    auto* old = shared_.exchange(new Node{rand()});
                    recl.retire(old);
                    write_count.fetch_add(1);
                }
            }
        });
    }

    for (auto& w : workers) w.join();

    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

    std::cout << "Time: " << duration.count() << "ms, "
              << "Reads: " << read_count << ", Writes: " << write_count << "\n";
}

// 预期结果：
// - 读密集型：EBR显著快于HP（enter/leave比protect便宜）
// - 写密集型：差距缩小（retire开销相近）
// - 混合负载：EBR通常更快
// - 内存使用：HP更可控，EBR可能有波动
```

**实验2：不同epoch推进策略的影响**

```cpp
// 比较不同的epoch推进时机

// 策略A: 每次leave时都尝试推进
void leave_with_immediate_advance() {
    local_epoch_.store(INACTIVE);
    try_advance();  // 总是尝试
}

// 策略B: 惰性推进（只在retire达到阈值时）
void leave_with_lazy_advance() {
    local_epoch_.store(INACTIVE);
    if (pending_garbage_count() > THRESHOLD) {
        try_advance();
    }
}

// 策略C: 定时推进（后台线程）
void background_advancer() {
    while (running_) {
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
        try_advance();
    }
}

// 预期结果：
// 策略A:
//   - 优点：内存回收最及时
//   - 缺点：leave开销较高
//
// 策略B:
//   - 优点：leave开销低
//   - 缺点：可能积累较多垃圾
//
// 策略C:
//   - 优点：工作线程开销最低
//   - 缺点：需要额外线程，回收有延迟
```

---

#### 面试高频题

**题目1：解释EBR的工作原理**

**参考答案：**
```
Epoch-Based Reclamation (EBR) 是一种基于时间片的内存回收方案。

核心概念：
1. Epoch（纪元）：全局时间戳，分为多个epoch（通常3个轮换）
2. Grace Period：一个完整的epoch周期，保证所有旧读者已离开
3. Quiescent State：线程不持有任何共享引用的状态

工作流程：
1. 进入临界区：线程记录当前epoch到local_epoch
2. 退出临界区：线程将local_epoch设为INACTIVE
3. retire：将待删除指针加入当前epoch的垃圾桶
4. 推进epoch：当所有活跃线程都在当前epoch时可以推进
5. 回收：epoch推进到E+2时，回收epoch E的垃圾

为什么是3个epoch：
- epoch E: 当前
- epoch E-1: 可能有线程刚从这里退出
- epoch E-2: 确保所有线程都已离开，可以安全回收

优点：
- 进入/退出临界区开销极低（只需更新本地变量）
- 批量回收效率高

缺点：
- 如果线程长时间阻塞在临界区内，会阻止内存回收
- 可能导致内存使用不可预测
```

---

**题目2：EBR和RCU的关系是什么？**

**参考答案：**
```
RCU (Read-Copy-Update) 和 EBR 密切相关，可以认为EBR是RCU思想的一种通用实现。

相同点：
1. 都是为了解决读密集型场景的内存回收问题
2. 都使用"宽限期"概念确保读者安全
3. 读操作都是wait-free的
4. 写操作都需要等待读者

不同点：
1. 起源不同：
   - RCU起源于Linux内核，针对内核场景优化
   - EBR是学术界提出的通用用户态方案

2. 静默状态检测：
   - RCU利用内核机制（上下文切换、idle）检测
   - EBR依赖显式的enter/leave调用

3. 适用环境：
   - RCU主要用于内核，有特殊的抢占处理
   - EBR用于用户态程序，更通用

4. API风格：
   - RCU: rcu_read_lock/unlock, synchronize_rcu
   - EBR: pin/unpin, retire

实际应用：
- Linux内核：使用RCU
- 用户态C++：使用EBR（如crossbeam-epoch的C++移植）
- Java/C#：JVM/CLR提供的GC本质上也有类似机制
```

---

**题目3：如何处理EBR中的线程阻塞问题？**

**参考答案：**
```
问题描述：
如果一个线程在epoch临界区内长时间阻塞，会导致：
1. epoch无法推进
2. 所有线程的垃圾无法回收
3. 内存使用量持续增长

解决方案：

方案1: Offline机制
- 线程在阻塞前主动声明"离线"
- 离线线程不参与epoch检查
- 缺点：需要修改代码，容易忘记

方案2: 超时强制推进
- 设置最大等待时间
- 超时后强制推进epoch
- 缺点：需要额外机制确保安全

方案3: 分离epoch域
- 不同数据结构使用独立的epoch系统
- 一个域的阻塞不影响其他域
- 缺点：增加复杂度

方案4: 混合方案（HP + EBR）
- 短期访问使用EBR（高效）
- 长期持有使用HP（不阻塞回收）
- 这是folly等库采用的策略

方案5: Quiescent-State-Based Reclamation (QSBR)
- 变体EBR，要求线程周期性报告静默状态
- 阻塞的线程自然不会报告，被视为离开
- 缺点：需要周期性协作

最佳实践：
1. 设计时避免在临界区内进行可能阻塞的操作
2. 使用RAII确保异常时正确离开临界区
3. 监控内存使用，设置告警阈值
```

---

#### 练习与作业

**编程练习1：实现完整的EBR系统**

```cpp
// 任务：实现一个完善的EBR系统
// 要求：
// 1. 支持线程动态注册/注销
// 2. 实现高效的epoch推进
// 3. 支持自定义deleter
// 4. 添加离线模式支持
// 5. 提供调试和统计接口

class EpochBasedReclamation {
public:
    // 配置
    struct Config {
        size_t max_threads = 128;
        size_t retire_threshold = 1000;  // 触发回收的阈值
        bool enable_background_reclaim = false;
    };

    explicit EpochBasedReclamation(Config config = {});

    // RAII守卫
    class Guard {
    public:
        ~Guard();
        Guard(Guard&&) noexcept;
        // 不可复制
    private:
        friend class EpochBasedReclamation;
        Guard(EpochBasedReclamation&, size_t thread_idx);
        EpochBasedReclamation& ebr_;
        size_t thread_idx_;
    };

    Guard pin();

    // 延迟删除
    template <typename T>
    void retire(T* ptr);

    template <typename T, typename Deleter>
    void retire(T* ptr, Deleter deleter);

    // 离线模式（用于长时间阻塞）
    void go_offline();
    void go_online();

    // 强制同步（等待grace period）
    void synchronize();

    // 统计
    struct Stats {
        uint64_t current_epoch;
        size_t active_threads;
        size_t pending_garbage[3];
        size_t total_retired;
        size_t total_reclaimed;
    };
    Stats get_stats() const;
};
```

**编程练习2：使用EBR实现无锁哈希表**

```cpp
// 任务：实现一个使用EBR的无锁哈希表
// 要求：
// 1. 支持并发的insert/lookup/remove
// 2. 使用链地址法处理冲突
// 3. 支持动态扩容
// 4. 正确的内存回收

template <typename K, typename V>
class ConcurrentHashMap {
public:
    explicit ConcurrentHashMap(size_t initial_buckets = 16);

    bool insert(K key, V value);
    std::optional<V> lookup(K key);
    bool remove(K key);

    size_t size() const;

private:
    struct Node {
        K key;
        V value;
        std::atomic<Node*> next;
    };

    struct Bucket {
        std::atomic<Node*> head;
    };

    std::atomic<Bucket*> buckets_;
    std::atomic<size_t> bucket_count_;
    std::atomic<size_t> size_;
    EpochBasedReclamation ebr_;

    void resize();
};
```

**思考题：**

1. 如果一个系统同时需要EBR（用于读密集数据结构）和HP（用于需要及时回收的场景），如何设计统一的接口？

2. EBR的epoch推进可以由专门的后台线程完成吗？这样做有什么优缺点？

3. 在分布式系统中，如何实现跨节点的epoch同步？有哪些挑战？

---

#### 本周检验点

**知识检验**
- [ ] 能解释EBR的三epoch设计原理
- [ ] 能比较EBR与HP的优缺点
- [ ] 能说明EBR与RCU的关系
- [ ] 能分析EBR的内存使用特性

**代码检验**
- [ ] 完成EpochBasedReclamation的完整实现
- [ ] 实现的无锁链表通过并发测试
- [ ] 性能测试显示合理的结果
- [ ] 代码通过ThreadSanitizer检测

---

#### Part 3: 使用EBR的无锁链表
```cpp
// lockfree_list.hpp
#pragma once
#include "epoch_reclamation.hpp"
#include <atomic>
#include <optional>

template <typename T>
class LockFreeList {
    struct Node {
        T data;
        std::atomic<Node*> next;

        Node(T d) : data(std::move(d)), next(nullptr) {}
    };

    std::atomic<Node*> head_{nullptr};
    EpochReclamation& er_;

public:
    explicit LockFreeList(EpochReclamation& er) : er_(er) {}

    ~LockFreeList() {
        Node* current = head_.load();
        while (current) {
            Node* next = current->next.load();
            delete current;
            current = next;
        }
    }

    void push_front(T value) {
        EpochReclamation::Guard guard(er_);
        Node* new_node = new Node(std::move(value));
        Node* old_head = head_.load(std::memory_order_relaxed);
        do {
            new_node->next.store(old_head, std::memory_order_relaxed);
        } while (!head_.compare_exchange_weak(old_head, new_node,
                    std::memory_order_release,
                    std::memory_order_relaxed));
    }

    std::optional<T> pop_front() {
        EpochReclamation::Guard guard(er_);
        Node* old_head = head_.load(std::memory_order_relaxed);

        while (old_head) {
            Node* next = old_head->next.load(std::memory_order_relaxed);
            if (head_.compare_exchange_weak(old_head, next,
                    std::memory_order_acquire,
                    std::memory_order_relaxed)) {
                T result = std::move(old_head->data);
                er_.retire(old_head);
                return result;
            }
        }

        return std::nullopt;
    }

    bool contains(const T& value) {
        EpochReclamation::Guard guard(er_);
        Node* current = head_.load(std::memory_order_acquire);
        while (current) {
            if (current->data == value) {
                return true;
            }
            current = current->next.load(std::memory_order_acquire);
        }
        return false;
    }
};
```

---

## 检验标准

### 知识检验

#### 基础概念（必须掌握）
- [ ] 什么是ABA问题？能画出完整的时序图
- [ ] ABA问题的三个必要条件是什么？
- [ ] 为什么CAS操作无法检测ABA？
- [ ] 版本计数如何解决ABA？有什么限制？
- [ ] 危险指针的工作原理是什么？为什么protect需要重试？
- [ ] EBR的三epoch设计是什么？为什么需要3个而不是2个？
- [ ] RCU与EBR有什么关系和区别？

#### 进阶理解（建议掌握）
- [ ] 不同内存回收方案的性能特点对比
- [ ] 128位CAS的平台支持和性能影响
- [ ] HP和EBR各自的适用场景
- [ ] 如何处理EBR中的线程阻塞问题
- [ ] 无锁数据结构中HP数量的选择策略

#### 工程实践（能够应用）
- [ ] 能分析开源项目中的内存回收实现
- [ ] 能选择合适的方案解决特定问题
- [ ] 能识别和避免常见的内存回收陷阱
- [ ] 能设计和执行并发正确性测试

### 实践检验

#### 代码实现
- [ ] 实现能复现ABA问题的测试程序
- [ ] 实现带版本计数的ABASafeStack
- [ ] 实现完整的HazardPointerDomain库
- [ ] 实现完整的EpochBasedReclamation库
- [ ] 使用HP/EBR实现无锁链表

#### 测试验证
- [ ] 所有代码通过编译，无警告
- [ ] 单元测试覆盖核心功能
- [ ] 多线程压力测试通过
- [ ] ThreadSanitizer无报错
- [ ] 性能基准测试有合理结果

### 输出物

#### 核心代码文件
1. `aba_reproduction.cpp` - ABA问题复现测试
2. `tagged_pointer.hpp` - Tagged Pointer实现
3. `aba_safe_stack.hpp` - 带版本计数的无锁栈
4. `hazard_pointer.hpp` - 危险指针完整实现
5. `epoch_reclamation.hpp` - EBR完整实现
6. `lockfree_list.hpp` - 使用内存回收的无锁链表

#### 测试文件
7. `test_aba_detection.cpp` - ABA检测测试
8. `test_hazard_pointer.cpp` - HP单元测试和压力测试
9. `test_epoch_reclamation.cpp` - EBR单元测试和压力测试
10. `benchmark_comparison.cpp` - HP vs EBR性能对比

#### 文档
11. `notes/month16_aba_reclamation.md` - 学习笔记
12. `notes/interview_qa.md` - 面试题整理

---

## 时间分配（140小时/月，每天约5小时）

### 总体分配

| 内容 | 时间 | 占比 |
|------|------|------|
| 理论学习与论文阅读 | 35小时 | 25% |
| 源码阅读（folly, crossbeam, libcds） | 20小时 | 14% |
| 核心代码实现 | 45小时 | 32% |
| 测试与调试 | 20小时 | 14% |
| 性能实验与分析 | 12小时 | 9% |
| 文档与笔记整理 | 8小时 | 6% |

### 每周详细分配

#### 第一周：ABA问题（35小时）
| 活动 | 时间 |
|------|------|
| 理论学习（ABA概念、论文） | 12h |
| 内存分配器研究 | 5h |
| ABA复现程序开发 | 8h |
| 真实案例分析 | 5h |
| 面试题练习 | 3h |
| 笔记整理 | 2h |

#### 第二周：版本计数（35小时）
| 活动 | 时间 |
|------|------|
| 理论学习（Tagged Pointer, 128位CAS） | 10h |
| ABASafeStack实现 | 10h |
| 跨平台原子操作封装 | 6h |
| 源码阅读（folly AtomicStruct） | 4h |
| 性能测试 | 3h |
| 笔记整理 | 2h |

#### 第三周：危险指针（35小时）
| 活动 | 时间 |
|------|------|
| 理论学习（HP论文精读） | 8h |
| HazardPointerDomain实现 | 12h |
| 源码阅读（folly HP, libcds） | 5h |
| 单元测试和压力测试 | 6h |
| 性能优化 | 2h |
| 笔记整理 | 2h |

#### 第四周：EBR与综合（35小时）
| 活动 | 时间 |
|------|------|
| 理论学习（EBR, RCU） | 8h |
| EpochReclamation实现 | 10h |
| 源码阅读（crossbeam-epoch） | 4h |
| 无锁链表集成 | 5h |
| HP vs EBR对比实验 | 4h |
| 月度总结与复习 | 4h |

---

## 月度学习路线图

```
Week 1: ABA问题深度分析
├── Day 1-2: 概念建立 + 触发条件
├── Day 3-4: 内存分配器 + 论文精读
├── Day 5-6: 实践案例 + 复现测试
└── Day 7: 周总结 + 检验

Week 2: 版本计数解决方案
├── Day 1-2: Tagged Pointer + 128位CAS
├── Day 3-4: ABASafeStack实现
├── Day 5-6: 性能测试 + 源码阅读
└── Day 7: 周总结 + 检验

Week 3: 危险指针（Hazard Pointers）
├── Day 1-2: 核心概念 + API设计
├── Day 3-4: 完整实现
├── Day 5-6: 优化 + 源码阅读
└── Day 7: 集成测试 + 检验

Week 4: Epoch-Based Reclamation
├── Day 1-2: EBR原理 + 三epoch设计
├── Day 3-4: 完整实现 + 优化
├── Day 5-6: 源码阅读 + 集成应用
└── Day 7: 月度总结 + 综合检验
```

## 核心概念速查

| 方案 | 原理 | 优点 | 缺点 | 适用场景 |
|------|------|------|------|----------|
| **版本计数** | 指针+计数器原子更新 | 简单直接 | 需要128位CAS | 简单数据结构 |
| **危险指针** | 发布正在访问的地址 | 内存可控 | 每次访问有开销 | 复杂遍历 |
| **EBR** | 基于epoch的批量回收 | 读开销低 | 可能阻塞回收 | 读密集场景 |

## 下月预告

Month 17将学习**无锁队列**，这是最实用的无锁数据结构之一。我们将学习Michael-Scott队列、MPSC队列等经典算法，并应用本月学到的内存回收技术。
