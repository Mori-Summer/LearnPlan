# Month 23: 并发模式与最佳实践——设计模式总结

## 本月主题概述

本月是Year 2并发编程学习的**关键总结月**，将系统整合Month 13-22学习的所有并发知识，建立"场景→最佳实践"的决策框架，为Month 24综合项目做准备。

### 为什么需要这个总结月？

```
Year 2 并发编程知识体系：

┌─────────────────────────────────────────────────────────────────┐
│  Month 13-15: 基础层                                            │
│  ┌─────────────┬─────────────┬─────────────┐                   │
│  │ 线程与同步  │ 内存模型    │ 原子操作    │                   │
│  │ mutex/cv    │ memory_order│ CAS         │                   │
│  └─────────────┴─────────────┴─────────────┘                   │
│                         ↓                                       │
│  Month 16-18: 无锁编程层                                        │
│  ┌─────────────┬─────────────┬─────────────┐                   │
│  │ ABA与回收   │ 无锁队列    │ Future      │                   │
│  │ HP/Epoch/RCU│ MPSC/SPSC   │ async/await │                   │
│  └─────────────┴─────────────┴─────────────┘                   │
│                         ↓                                       │
│  Month 19-22: 高级并发层                                        │
│  ┌─────────────┬─────────────┬─────────────┬─────────────┐     │
│  │ 线程池      │ Actor模型   │ 协程基础    │ 异步I/O     │     │
│  │ Work Steal  │ 消息传递    │ Task/Channel│ EventLoop   │     │
│  └─────────────┴─────────────┴─────────────┴─────────────┘     │
│                         ↓                                       │
│  Month 23: 【本月】总结与决策框架                               │
│  ┌─────────────────────────────────────────────────────┐       │
│  │ 模式对比 → 场景分析 → 决策指南 → 最佳实践          │       │
│  └─────────────────────────────────────────────────────┘       │
│                         ↓                                       │
│  Month 24: 综合项目                                             │
└─────────────────────────────────────────────────────────────────┘

问题：面对具体场景，如何选择最合适的并发方案？
- 什么时候用锁？什么时候用无锁？
- 什么时候用线程池？什么时候用Actor？什么时候用协程？
- 如何权衡性能、复杂度、可维护性？

本月目标：建立系统的决策框架，让你能够自信地做出选择！
```

### 学习目标

1. **模式总结**：深入理解生产者-消费者、读写锁等核心并发模式
2. **对比分析**：掌握各种并发方案的优劣和适用场景
3. **决策能力**：建立从场景到方案的系统决策框架
4. **实战技能**：掌握并发调试、性能分析等实战技能

### 学习目标量化

| 周次 | 目标编号 | 具体目标 |
|------|----------|----------|
| W1 | W1-G1 | 掌握PC模式的各种变种和权衡 |
| W1 | W1-G2 | 理解背压机制在不同系统中的应用 |
| W1 | W1-G3 | 能对比线程池/Actor/Channel的PC实现 |
| W2 | W2-G1 | 理解读写锁的性能陷阱和优化 |
| W2 | W2-G2 | 掌握RCU和分段锁的实现原理 |
| W2 | W2-G3 | 能设计性能对比实验 |
| W3 | W3-G1 | 理解双缓冲技术的应用场景 |
| W3 | W3-G2 | 建立完整的并发模式对比框架 |
| W3 | W3-G3 | 制定并发决策指南 |
| W4 | W4-G1 | 掌握并发Bug调试技术 |
| W4 | W4-G2 | 掌握性能分析和优化方法 |
| W4 | W4-G3 | 完成综合项目并生成性能报告 |

### 前置知识

本月需要整合以下月份的知识：

| 月份 | 主题 | 关键内容 | 本月应用 |
|------|------|----------|----------|
| Month 13 | 线程与同步 | mutex、cv、atomic | PC模式基础 |
| Month 14 | 内存模型 | memory_order | 无锁优化分析 |
| Month 15 | 原子操作 | CAS | 双缓冲实现 |
| Month 16 | 内存回收 | HP、Epoch、RCU | 读写优化方案 |
| Month 17 | 无锁队列 | MPSC、SPSC | PC变种对比 |
| Month 18 | Future | async/await | 异步模式对比 |
| Month 19 | 线程池 | Work Stealing | PC实例分析 |
| Month 20 | Actor | 消息传递 | PC实例分析 |
| Month 21 | 协程 | Task、Channel | PC实例分析 |
| Month 22 | 异步I/O | EventLoop | 综合应用 |

---

## 第一周：生产者-消费者模式深度（Day 1-7）

> **本周目标**：系统总结PC模式的各种实现和权衡，理解其在不同系统中的应用

### Day 1-2：基础PC模式回顾

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | PC模式原理回顾 | 2h |
| 下午 | 有界缓冲区实现 | 3h |
| 晚上 | 条件变量深入 | 2h |

#### 1. 生产者-消费者模式本质

```cpp
// ============================================================
// 生产者-消费者模式：并发编程中最基础也最重要的模式
// ============================================================

/*
PC模式解决的核心问题：

┌─────────────────────────────────────────────────────────────┐
│  问题场景：                                                  │
│                                                              │
│  生产者（快）──→ 数据 ──→ 消费者（慢）                       │
│                                                              │
│  如果直接耦合：                                              │
│  • 生产者必须等待消费者处理完                                │
│  • 系统吞吐量受限于最慢的环节                                │
│  • 无法利用多核并行                                          │
├─────────────────────────────────────────────────────────────┤
│  PC模式解决方案：                                            │
│                                                              │
│  生产者 ──→ [缓冲区] ──→ 消费者                              │
│                                                              │
│  优势：                                                      │
│  • 解耦：生产者和消费者独立运行                              │
│  • 削峰：缓冲区平滑流量波动                                  │
│  • 并行：可以有多个生产者和消费者                            │
└─────────────────────────────────────────────────────────────┘

PC模式的四个核心问题：
1. 缓冲区设计：有界 vs 无界
2. 同步机制：锁 vs 无锁
3. 阻塞策略：阻塞 vs 非阻塞 vs 超时
4. 流量控制：背压（Backpressure）
*/

// 基础PC模式：阻塞有界队列
template<typename T>
class BoundedBuffer {
private:
    std::queue<T> buffer_;
    size_t capacity_;
    mutable std::mutex mutex_;
    std::condition_variable not_full_;
    std::condition_variable not_empty_;

public:
    explicit BoundedBuffer(size_t capacity)
        : capacity_(capacity) {}

    // 生产者调用：放入数据
    void put(T item) {
        std::unique_lock<std::mutex> lock(mutex_);

        // 等待缓冲区不满
        not_full_.wait(lock, [this] {
            return buffer_.size() < capacity_;
        });

        buffer_.push(std::move(item));

        // 通知消费者
        not_empty_.notify_one();
    }

    // 消费者调用：取出数据
    T take() {
        std::unique_lock<std::mutex> lock(mutex_);

        // 等待缓冲区不空
        not_empty_.wait(lock, [this] {
            return !buffer_.empty();
        });

        T item = std::move(buffer_.front());
        buffer_.pop();

        // 通知生产者
        not_full_.notify_one();

        return item;
    }

    size_t size() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return buffer_.size();
    }
};
```

#### 2. 条件变量的正确使用（Month 13 回顾）

```cpp
// ============================================================
// 条件变量使用的常见陷阱和最佳实践
// ============================================================

/*
条件变量的三个关键点：

1. 必须在互斥锁保护下使用
2. 必须使用while循环检查条件（虚假唤醒）
3. wait会原子地释放锁并阻塞

常见错误：

错误1：不持有锁就wait
错误2：用if而不是while检查条件
错误3：notify时不持有锁（虽然合法但可能有性能问题）
*/

// 正确的条件变量使用模式
class CorrectConditionVariableUsage {
    std::mutex mutex_;
    std::condition_variable cv_;
    bool condition_ = false;

public:
    void wait_for_condition() {
        std::unique_lock<std::mutex> lock(mutex_);

        // 正确：使用lambda的wait
        cv_.wait(lock, [this] { return condition_; });

        // 等价于：
        // while (!condition_) {
        //     cv_.wait(lock);
        // }

        // 错误示例（不要这样做）：
        // if (!condition_) cv_.wait(lock);  // 虚假唤醒会导致问题
    }

    void set_condition() {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            condition_ = true;
        }
        cv_.notify_all();  // 可以在锁外notify
    }
};

// 虚假唤醒（Spurious Wakeup）解释
/*
┌─────────────────────────────────────────────────────────────┐
│  为什么会有虚假唤醒？                                        │
├─────────────────────────────────────────────────────────────┤
│  1. 系统实现原因：某些操作系统在某些条件下会唤醒等待线程    │
│  2. 多个等待者：notify_one可能唤醒多个线程（实现相关）      │
│  3. 信号处理：被信号中断后可能返回                          │
├─────────────────────────────────────────────────────────────┤
│  解决方案：总是用while循环检查条件                          │
│                                                              │
│  while (!condition) {                                        │
│      cv.wait(lock);                                          │
│  }                                                           │
│                                                              │
│  或使用带谓词的wait：                                        │
│  cv.wait(lock, [] { return condition; });                   │
└─────────────────────────────────────────────────────────────┘
*/
```

#### 3. 多生产者多消费者（MPMC）

```cpp
// ============================================================
// MPMC队列：多生产者多消费者
// ============================================================

template<typename T>
class MPMCBoundedQueue {
private:
    std::vector<T> buffer_;
    size_t capacity_;
    size_t head_ = 0;  // 消费者读取位置
    size_t tail_ = 0;  // 生产者写入位置
    size_t count_ = 0; // 当前元素数量

    mutable std::mutex mutex_;
    std::condition_variable not_full_;
    std::condition_variable not_empty_;

public:
    explicit MPMCBoundedQueue(size_t capacity)
        : buffer_(capacity), capacity_(capacity) {}

    // 阻塞式放入
    void push(T item) {
        std::unique_lock<std::mutex> lock(mutex_);

        not_full_.wait(lock, [this] {
            return count_ < capacity_;
        });

        buffer_[tail_] = std::move(item);
        tail_ = (tail_ + 1) % capacity_;
        ++count_;

        not_empty_.notify_one();
    }

    // 阻塞式取出
    T pop() {
        std::unique_lock<std::mutex> lock(mutex_);

        not_empty_.wait(lock, [this] {
            return count_ > 0;
        });

        T item = std::move(buffer_[head_]);
        head_ = (head_ + 1) % capacity_;
        --count_;

        not_full_.notify_one();

        return item;
    }

    // 非阻塞式放入
    bool try_push(T item) {
        std::lock_guard<std::mutex> lock(mutex_);

        if (count_ >= capacity_) {
            return false;
        }

        buffer_[tail_] = std::move(item);
        tail_ = (tail_ + 1) % capacity_;
        ++count_;

        not_empty_.notify_one();
        return true;
    }

    // 非阻塞式取出
    std::optional<T> try_pop() {
        std::lock_guard<std::mutex> lock(mutex_);

        if (count_ == 0) {
            return std::nullopt;
        }

        T item = std::move(buffer_[head_]);
        head_ = (head_ + 1) % capacity_;
        --count_;

        not_full_.notify_one();
        return item;
    }

    // 带超时的放入
    template<typename Rep, typename Period>
    bool push_for(T item, std::chrono::duration<Rep, Period> timeout) {
        std::unique_lock<std::mutex> lock(mutex_);

        if (!not_full_.wait_for(lock, timeout, [this] {
            return count_ < capacity_;
        })) {
            return false;
        }

        buffer_[tail_] = std::move(item);
        tail_ = (tail_ + 1) % capacity_;
        ++count_;

        not_empty_.notify_one();
        return true;
    }

    // 带超时的取出
    template<typename Rep, typename Period>
    std::optional<T> pop_for(std::chrono::duration<Rep, Period> timeout) {
        std::unique_lock<std::mutex> lock(mutex_);

        if (!not_empty_.wait_for(lock, timeout, [this] {
            return count_ > 0;
        })) {
            return std::nullopt;
        }

        T item = std::move(buffer_[head_]);
        head_ = (head_ + 1) % capacity_;
        --count_;

        not_full_.notify_one();
        return item;
    }

    size_t size() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return count_;
    }

    bool empty() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return count_ == 0;
    }

    bool full() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return count_ >= capacity_;
    }
};
```

#### 4. 背压（Backpressure）机制

```cpp
// ============================================================
// 背压机制：当消费者处理不过来时，如何反向限制生产者
// ============================================================

/*
背压的重要性：

没有背压的系统：
┌─────────────────────────────────────────────────────────────┐
│  生产者(快) ──→ [无限缓冲区] ──→ 消费者(慢)                 │
│                     ↓                                        │
│              内存持续增长                                     │
│                     ↓                                        │
│                 系统崩溃！                                    │
└─────────────────────────────────────────────────────────────┘

有背压的系统：
┌─────────────────────────────────────────────────────────────┐
│  生产者 ←──背压信号──┐                                       │
│     ↓               │                                        │
│  [有界缓冲区] ───────┘                                       │
│     ↓                                                        │
│  消费者                                                      │
│                                                              │
│  缓冲区满 → 阻塞生产者 → 系统稳定                           │
└─────────────────────────────────────────────────────────────┘
*/

// 背压策略枚举
enum class BackpressureStrategy {
    Block,      // 阻塞等待
    Drop,       // 丢弃新数据
    DropOldest, // 丢弃最旧数据
    Error,      // 返回错误
    Timeout     // 超时后返回
};

// 带背压策略的队列
template<typename T>
class BackpressureQueue {
private:
    std::deque<T> buffer_;
    size_t capacity_;
    BackpressureStrategy strategy_;

    mutable std::mutex mutex_;
    std::condition_variable not_full_;
    std::condition_variable not_empty_;

    // 统计信息
    std::atomic<size_t> dropped_count_{0};
    std::atomic<size_t> total_produced_{0};
    std::atomic<size_t> total_consumed_{0};

public:
    BackpressureQueue(size_t capacity,
                      BackpressureStrategy strategy = BackpressureStrategy::Block)
        : capacity_(capacity), strategy_(strategy) {}

    // 根据策略处理背压
    bool push(T item, std::chrono::milliseconds timeout = std::chrono::milliseconds::max()) {
        std::unique_lock<std::mutex> lock(mutex_);

        if (buffer_.size() >= capacity_) {
            switch (strategy_) {
                case BackpressureStrategy::Block:
                    not_full_.wait(lock, [this] {
                        return buffer_.size() < capacity_;
                    });
                    break;

                case BackpressureStrategy::Drop:
                    ++dropped_count_;
                    return false;

                case BackpressureStrategy::DropOldest:
                    buffer_.pop_front();
                    ++dropped_count_;
                    break;

                case BackpressureStrategy::Error:
                    throw std::runtime_error("Queue is full");

                case BackpressureStrategy::Timeout:
                    if (!not_full_.wait_for(lock, timeout, [this] {
                        return buffer_.size() < capacity_;
                    })) {
                        return false;
                    }
                    break;
            }
        }

        buffer_.push_back(std::move(item));
        ++total_produced_;
        not_empty_.notify_one();
        return true;
    }

    std::optional<T> pop() {
        std::unique_lock<std::mutex> lock(mutex_);

        not_empty_.wait(lock, [this] {
            return !buffer_.empty();
        });

        T item = std::move(buffer_.front());
        buffer_.pop_front();
        ++total_consumed_;

        not_full_.notify_one();
        return item;
    }

    // 获取统计信息
    struct Stats {
        size_t current_size;
        size_t capacity;
        size_t dropped;
        size_t produced;
        size_t consumed;
        double drop_rate;
    };

    Stats get_stats() const {
        std::lock_guard<std::mutex> lock(mutex_);
        Stats stats;
        stats.current_size = buffer_.size();
        stats.capacity = capacity_;
        stats.dropped = dropped_count_.load();
        stats.produced = total_produced_.load();
        stats.consumed = total_consumed_.load();
        stats.drop_rate = stats.produced > 0 ?
            static_cast<double>(stats.dropped) / stats.produced : 0.0;
        return stats;
    }
};
```

### Day 3-4：高级PC模式

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | 优先级队列变种 | 2h |
| 下午 | 批量处理优化 | 3h |
| 晚上 | 超时和取消 | 2h |

#### 1. 优先级队列变种

```cpp
// ============================================================
// 优先级生产者-消费者队列
// ============================================================

template<typename T, typename Priority = int>
class PriorityBoundedQueue {
private:
    struct Item {
        T data;
        Priority priority;

        bool operator<(const Item& other) const {
            // 优先级高的排在前面
            return priority < other.priority;
        }
    };

    std::priority_queue<Item> buffer_;
    size_t capacity_;

    mutable std::mutex mutex_;
    std::condition_variable not_full_;
    std::condition_variable not_empty_;

public:
    explicit PriorityBoundedQueue(size_t capacity)
        : capacity_(capacity) {}

    void push(T item, Priority priority) {
        std::unique_lock<std::mutex> lock(mutex_);

        not_full_.wait(lock, [this] {
            return buffer_.size() < capacity_;
        });

        buffer_.push({std::move(item), priority});
        not_empty_.notify_one();
    }

    T pop() {
        std::unique_lock<std::mutex> lock(mutex_);

        not_empty_.wait(lock, [this] {
            return !buffer_.empty();
        });

        T item = std::move(const_cast<Item&>(buffer_.top()).data);
        buffer_.pop();

        not_full_.notify_one();
        return item;
    }

    // 获取最高优先级但不移除
    std::optional<std::pair<T, Priority>> peek() const {
        std::lock_guard<std::mutex> lock(mutex_);
        if (buffer_.empty()) {
            return std::nullopt;
        }
        const auto& top = buffer_.top();
        return std::make_pair(top.data, top.priority);
    }
};

// 多级优先级队列（更高效的实现）
template<typename T, size_t NumLevels = 3>
class MultiLevelQueue {
private:
    std::array<std::queue<T>, NumLevels> queues_;
    std::array<size_t, NumLevels> counts_{};
    size_t total_count_ = 0;
    size_t capacity_;

    mutable std::mutex mutex_;
    std::condition_variable not_full_;
    std::condition_variable not_empty_;

public:
    explicit MultiLevelQueue(size_t capacity)
        : capacity_(capacity) {}

    // level: 0 = 最高优先级
    void push(T item, size_t level) {
        if (level >= NumLevels) {
            level = NumLevels - 1;
        }

        std::unique_lock<std::mutex> lock(mutex_);

        not_full_.wait(lock, [this] {
            return total_count_ < capacity_;
        });

        queues_[level].push(std::move(item));
        ++counts_[level];
        ++total_count_;

        not_empty_.notify_one();
    }

    T pop() {
        std::unique_lock<std::mutex> lock(mutex_);

        not_empty_.wait(lock, [this] {
            return total_count_ > 0;
        });

        // 从最高优先级开始查找
        for (size_t i = 0; i < NumLevels; ++i) {
            if (!queues_[i].empty()) {
                T item = std::move(queues_[i].front());
                queues_[i].pop();
                --counts_[i];
                --total_count_;

                not_full_.notify_one();
                return item;
            }
        }

        // 不应该到这里
        throw std::logic_error("Queue inconsistency");
    }
};
```

#### 2. 批量处理优化

```cpp
// ============================================================
// 批量处理：提高吞吐量的关键优化
// ============================================================

/*
为什么批量处理能提高性能？

单个处理：
┌─────────────────────────────────────────────────────────────┐
│  lock → push → unlock → lock → push → unlock → ...         │
│        每次操作都有锁开销                                    │
└─────────────────────────────────────────────────────────────┘

批量处理：
┌─────────────────────────────────────────────────────────────┐
│  lock → push × N → unlock                                   │
│        一次锁操作处理多个数据                                │
│        减少锁竞争，提高缓存局部性                            │
└─────────────────────────────────────────────────────────────┘
*/

template<typename T>
class BatchQueue {
private:
    std::vector<T> buffer_;
    size_t capacity_;
    size_t head_ = 0;
    size_t tail_ = 0;
    size_t count_ = 0;

    mutable std::mutex mutex_;
    std::condition_variable not_full_;
    std::condition_variable not_empty_;

public:
    explicit BatchQueue(size_t capacity)
        : buffer_(capacity), capacity_(capacity) {}

    // 批量放入
    size_t push_batch(std::vector<T>& items) {
        if (items.empty()) return 0;

        std::unique_lock<std::mutex> lock(mutex_);

        // 等待至少有一个空位
        not_full_.wait(lock, [this] {
            return count_ < capacity_;
        });

        // 计算可以放入的数量
        size_t available = capacity_ - count_;
        size_t to_push = std::min(items.size(), available);

        // 批量复制
        for (size_t i = 0; i < to_push; ++i) {
            buffer_[tail_] = std::move(items[i]);
            tail_ = (tail_ + 1) % capacity_;
        }
        count_ += to_push;

        // 从items中移除已放入的元素
        items.erase(items.begin(), items.begin() + to_push);

        not_empty_.notify_all();  // 通知所有等待的消费者
        return to_push;
    }

    // 批量取出
    std::vector<T> pop_batch(size_t max_count) {
        std::unique_lock<std::mutex> lock(mutex_);

        // 等待至少有一个元素
        not_empty_.wait(lock, [this] {
            return count_ > 0;
        });

        // 计算可以取出的数量
        size_t to_pop = std::min(max_count, count_);
        std::vector<T> result;
        result.reserve(to_pop);

        // 批量取出
        for (size_t i = 0; i < to_pop; ++i) {
            result.push_back(std::move(buffer_[head_]));
            head_ = (head_ + 1) % capacity_;
        }
        count_ -= to_pop;

        not_full_.notify_all();  // 通知所有等待的生产者
        return result;
    }

    // 尝试批量取出（非阻塞）
    std::vector<T> try_pop_batch(size_t max_count) {
        std::lock_guard<std::mutex> lock(mutex_);

        if (count_ == 0) {
            return {};
        }

        size_t to_pop = std::min(max_count, count_);
        std::vector<T> result;
        result.reserve(to_pop);

        for (size_t i = 0; i < to_pop; ++i) {
            result.push_back(std::move(buffer_[head_]));
            head_ = (head_ + 1) % capacity_;
        }
        count_ -= to_pop;

        not_full_.notify_all();
        return result;
    }

    // 等待并一次性取出所有可用元素
    std::vector<T> drain(std::chrono::milliseconds timeout) {
        std::unique_lock<std::mutex> lock(mutex_);

        // 等待超时或有数据
        not_empty_.wait_for(lock, timeout, [this] {
            return count_ > 0;
        });

        std::vector<T> result;
        result.reserve(count_);

        while (count_ > 0) {
            result.push_back(std::move(buffer_[head_]));
            head_ = (head_ + 1) % capacity_;
            --count_;
        }

        not_full_.notify_all();
        return result;
    }
};
```

#### 3. 带关闭功能的队列

```cpp
// ============================================================
// 可关闭的队列：支持优雅关闭
// ============================================================

template<typename T>
class ClosableQueue {
private:
    std::queue<T> buffer_;
    size_t capacity_;
    bool closed_ = false;

    mutable std::mutex mutex_;
    std::condition_variable not_full_;
    std::condition_variable not_empty_;

public:
    explicit ClosableQueue(size_t capacity)
        : capacity_(capacity) {}

    // 关闭队列
    void close() {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            closed_ = true;
        }
        // 唤醒所有等待者
        not_full_.notify_all();
        not_empty_.notify_all();
    }

    bool is_closed() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return closed_;
    }

    // 放入，如果队列已关闭返回false
    bool push(T item) {
        std::unique_lock<std::mutex> lock(mutex_);

        not_full_.wait(lock, [this] {
            return closed_ || buffer_.size() < capacity_;
        });

        if (closed_) {
            return false;
        }

        buffer_.push(std::move(item));
        not_empty_.notify_one();
        return true;
    }

    // 取出，如果队列为空且已关闭返回nullopt
    std::optional<T> pop() {
        std::unique_lock<std::mutex> lock(mutex_);

        not_empty_.wait(lock, [this] {
            return closed_ || !buffer_.empty();
        });

        if (buffer_.empty()) {
            return std::nullopt;  // 队列已关闭且为空
        }

        T item = std::move(buffer_.front());
        buffer_.pop();

        not_full_.notify_one();
        return item;
    }
};

// 使用示例
/*
void producer(ClosableQueue<int>& queue) {
    for (int i = 0; i < 100; ++i) {
        if (!queue.push(i)) {
            break;  // 队列已关闭
        }
    }
}

void consumer(ClosableQueue<int>& queue) {
    while (auto item = queue.pop()) {
        process(*item);
    }
    // 队列已关闭且为空
}

int main() {
    ClosableQueue<int> queue(10);

    std::thread p(producer, std::ref(queue));
    std::thread c(consumer, std::ref(queue));

    // ... 等待一段时间
    queue.close();  // 优雅关闭

    p.join();
    c.join();
}
*/
```

### Day 5-6：PC模式在各月份的应用

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | 线程池任务队列分析 | 2h |
| 下午 | Actor Mailbox分析 | 3h |
| 晚上 | Channel对比分析 | 2h |

#### 1. PC模式对比框架

```cpp
// ============================================================
// PC模式在不同系统中的应用对比
// ============================================================

/*
┌─────────────────────────────────────────────────────────────────┐
│               PC模式在Month 19-22中的应用                        │
├─────────────┬────────────────────────────────────────────────────┤
│   系统      │  实现特点                                          │
├─────────────┼────────────────────────────────────────────────────┤
│ Month 19    │  线程池任务队列                                    │
│ 线程池      │  • 生产者：提交任务的线程                          │
│             │  • 消费者：工作线程                                │
│             │  • 缓冲区：任务队列（通常无界或很大）              │
│             │  • 特点：支持工作窃取，优先级调度                  │
├─────────────┼────────────────────────────────────────────────────┤
│ Month 20    │  Actor Mailbox                                     │
│ Actor模型   │  • 生产者：发送消息的Actor                         │
│             │  • 消费者：接收消息的Actor                         │
│             │  • 缓冲区：Mailbox（可有界/无界）                  │
│             │  • 特点：单消费者，消息按序处理                    │
├─────────────┼────────────────────────────────────────────────────┤
│ Month 21    │  Channel                                           │
│ 协程        │  • 生产者：send端协程                              │
│             │  • 消费者：receive端协程                           │
│             │  • 缓冲区：有界缓冲区                              │
│             │  • 特点：支持select，协程友好                      │
├─────────────┼────────────────────────────────────────────────────┤
│ Month 22    │  事件循环就绪队列                                  │
│ 异步I/O     │  • 生产者：I/O事件回调                             │
│             │  • 消费者：事件循环                                │
│             │  • 缓冲区：就绪队列                                │
│             │  • 特点：单线程，无锁                              │
└─────────────┴────────────────────────────────────────────────────┘
*/
```

#### 2. 线程池任务队列（Month 19 回顾）

```cpp
// ============================================================
// 线程池中的PC模式（Month 19 简化回顾）
// ============================================================

// 基础线程池的任务队列
class ThreadPoolQueue {
    using Task = std::function<void()>;

    std::queue<Task> tasks_;
    std::mutex mutex_;
    std::condition_variable cv_;
    bool stop_ = false;

public:
    void submit(Task task) {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            tasks_.push(std::move(task));
        }
        cv_.notify_one();
    }

    std::optional<Task> get_task() {
        std::unique_lock<std::mutex> lock(mutex_);
        cv_.wait(lock, [this] {
            return stop_ || !tasks_.empty();
        });

        if (stop_ && tasks_.empty()) {
            return std::nullopt;
        }

        Task task = std::move(tasks_.front());
        tasks_.pop();
        return task;
    }

    void shutdown() {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            stop_ = true;
        }
        cv_.notify_all();
    }
};

/*
线程池PC模式的特点：

优点：
• 任务解耦：提交者不关心执行者
• 负载均衡：多个工作线程自动分配任务
• 资源控制：限制并发执行的任务数

挑战：
• 任务窃取：Month 19 使用 Chase-Lev Deque 实现
• 优先级：需要优先级队列支持
• 依赖：DAG调度器处理任务依赖

与其他模式的关系：
• 比Actor更轻量（无消息序列化）
• 比协程更重量（线程开销）
• 适合CPU密集型任务
*/
```

#### 3. Actor Mailbox（Month 20 回顾）

```cpp
// ============================================================
// Actor Mailbox中的PC模式（Month 20 简化回顾）
// ============================================================

// Actor的消息信箱
template<typename Message>
class Mailbox {
    std::queue<Message> messages_;
    std::mutex mutex_;
    std::condition_variable cv_;
    bool closed_ = false;

public:
    // 发送消息（多生产者）
    bool send(Message msg) {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            if (closed_) return false;
            messages_.push(std::move(msg));
        }
        cv_.notify_one();
        return true;
    }

    // 接收消息（单消费者：Actor自身）
    std::optional<Message> receive() {
        std::unique_lock<std::mutex> lock(mutex_);
        cv_.wait(lock, [this] {
            return closed_ || !messages_.empty();
        });

        if (messages_.empty()) return std::nullopt;

        Message msg = std::move(messages_.front());
        messages_.pop();
        return msg;
    }

    void close() {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            closed_ = true;
        }
        cv_.notify_all();
    }
};

/*
Actor Mailbox的特点：

优点：
• 消息隔离：Actor之间无共享状态
• 按序处理：消息FIFO处理
• 容错性："Let it crash" + 监督树

挑战：
• 背压：Mailbox满时如何处理
• 优先级：系统消息 vs 用户消息
• 死锁：循环等待（Ask模式）

与其他模式的关系：
• 比共享内存更安全
• 比线程池更结构化
• 适合分布式系统
*/
```

#### 4. 协程Channel（Month 21 回顾）

```cpp
// ============================================================
// 协程Channel中的PC模式（Month 21 简化回顾）
// ============================================================

// 简化的协程Channel
template<typename T>
class SimpleChannel {
    std::queue<T> buffer_;
    size_t capacity_;
    std::mutex mutex_;

    struct Waiter {
        std::coroutine_handle<> handle;
        T* result_ptr;  // 用于接收
    };

    std::queue<Waiter> send_waiters_;
    std::queue<Waiter> recv_waiters_;
    bool closed_ = false;

public:
    explicit SimpleChannel(size_t capacity = 0) : capacity_(capacity) {}

    // 发送（协程会在此暂停）
    auto send(T value) {
        struct SendAwaiter {
            SimpleChannel* channel;
            T value;

            bool await_ready() {
                std::lock_guard lock(channel->mutex_);
                if (channel->closed_) return true;
                if (channel->buffer_.size() < channel->capacity_) {
                    channel->buffer_.push(std::move(value));
                    // 唤醒等待的接收者
                    if (!channel->recv_waiters_.empty()) {
                        auto waiter = channel->recv_waiters_.front();
                        channel->recv_waiters_.pop();
                        *waiter.result_ptr = std::move(channel->buffer_.front());
                        channel->buffer_.pop();
                        waiter.handle.resume();
                    }
                    return true;
                }
                return false;
            }

            void await_suspend(std::coroutine_handle<> h) {
                std::lock_guard lock(channel->mutex_);
                channel->send_waiters_.push({h, nullptr});
            }

            void await_resume() {}
        };
        return SendAwaiter{this, std::move(value)};
    }

    void close() {
        std::lock_guard lock(mutex_);
        closed_ = true;
        // 唤醒所有等待者...
    }
};

/*
协程Channel的特点：

优点：
• 协程友好：send/receive都可以暂停
• 零开销：无线程上下文切换
• 组合性：支持select多路复用

挑战：
• 单线程限制：通常在同一EventLoop内
• 调试困难：协程栈追踪

与其他模式的关系：
• 比锁更轻量
• 类似Go的Channel
• 适合I/O密集型
*/
```

### Day 7：第一周总结与检验

#### PC模式性能对比实验

```cpp
// ============================================================
// PC模式性能对比测试框架
// ============================================================

#include <chrono>
#include <thread>
#include <vector>
#include <iostream>
#include <iomanip>

// 测试配置
struct BenchConfig {
    size_t num_producers = 4;
    size_t num_consumers = 4;
    size_t items_per_producer = 100000;
    size_t queue_capacity = 1024;
};

// 测试结果
struct BenchResult {
    double total_time_ms;
    double throughput;  // items/s
    size_t total_items;
};

// 测试阻塞队列
template<typename Queue>
BenchResult benchmark_queue(Queue& queue, const BenchConfig& config) {
    std::atomic<size_t> produced{0};
    std::atomic<size_t> consumed{0};

    auto start = std::chrono::high_resolution_clock::now();

    // 启动生产者
    std::vector<std::thread> producers;
    for (size_t i = 0; i < config.num_producers; ++i) {
        producers.emplace_back([&queue, &config, &produced] {
            for (size_t j = 0; j < config.items_per_producer; ++j) {
                queue.push(static_cast<int>(j));
                ++produced;
            }
        });
    }

    // 启动消费者
    std::atomic<bool> done{false};
    std::vector<std::thread> consumers;
    for (size_t i = 0; i < config.num_consumers; ++i) {
        consumers.emplace_back([&queue, &consumed, &done, &config] {
            size_t total = config.num_producers * config.items_per_producer;
            while (consumed.load() < total) {
                if (auto item = queue.try_pop()) {
                    ++consumed;
                }
            }
        });
    }

    // 等待完成
    for (auto& t : producers) t.join();
    for (auto& t : consumers) t.join();

    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

    BenchResult result;
    result.total_time_ms = duration.count();
    result.total_items = config.num_producers * config.items_per_producer;
    result.throughput = result.total_items * 1000.0 / result.total_time_ms;

    return result;
}

// 打印对比结果
void print_comparison(const std::vector<std::pair<std::string, BenchResult>>& results) {
    std::cout << "\n=== PC模式性能对比 ===\n\n";
    std::cout << std::setw(20) << "队列类型"
              << std::setw(15) << "时间(ms)"
              << std::setw(15) << "吞吐量(ops/s)"
              << "\n";
    std::cout << std::string(50, '-') << "\n";

    for (const auto& [name, result] : results) {
        std::cout << std::setw(20) << name
                  << std::setw(15) << std::fixed << std::setprecision(2)
                  << result.total_time_ms
                  << std::setw(15) << std::fixed << std::setprecision(0)
                  << result.throughput
                  << "\n";
    }
}

/*
典型测试结果（参考）：
┌────────────────────────────────────────────────────────────┐
│  队列类型           │  时间(ms)    │  吞吐量(ops/s)        │
├────────────────────────────────────────────────────────────┤
│  mutex+cv队列       │  450         │  888,888              │
│  优先级队列         │  520         │  769,230              │
│  批量队列           │  180         │  2,222,222            │
│  无锁MPMC队列       │  120         │  3,333,333            │
│  SPSC队列           │  45          │  8,888,888            │
└────────────────────────────────────────────────────────────┘

结论：
• 批量处理显著提升吞吐量
• 无锁队列在高竞争下表现更好
• SPSC在单生产者单消费者场景性能最优
*/
```

#### 第一周检验标准

- [ ] 能解释PC模式解决的核心问题
- [ ] 理解条件变量的正确使用方式（虚假唤醒）
- [ ] 能实现多生产者多消费者队列
- [ ] 理解背压机制及其重要性
- [ ] 能实现优先级队列和批量处理
- [ ] 理解PC模式在线程池/Actor/Channel中的应用差异
- [ ] 能设计并执行性能对比实验

---

## 第二周：读写锁与并发优化（Day 8-14）

> **本周目标**：对比读写锁、RCU、分段锁等方案，理解各种优化技术的适用场景

### Day 8-9：读写锁基础

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | shared_mutex基础 | 2h |
| 下午 | 性能陷阱分析 | 3h |
| 晚上 | 公平性设计 | 2h |

#### 1. std::shared_mutex 使用

```cpp
// ============================================================
// 读写锁：允许多读单写的同步原语
// ============================================================

/*
读写锁的基本原理：

┌─────────────────────────────────────────────────────────────┐
│  传统互斥锁：                                                │
│  ┌─────────────────────────────────────────────┐            │
│  │  Reader1 ──┬─ lock ─────────── unlock ───┬─            │
│  │  Reader2 ──┘                              └── lock ...  │
│  │  Reader3 ─────── 等待 ────────────────────── 等待 ...   │
│  └─────────────────────────────────────────────┘            │
│  问题：读操作也互斥，浪费并行机会                            │
├─────────────────────────────────────────────────────────────┤
│  读写锁：                                                    │
│  ┌─────────────────────────────────────────────┐            │
│  │  Reader1 ──── shared_lock ────────────────             │
│  │  Reader2 ──── shared_lock ────────────────             │
│  │  Reader3 ──── shared_lock ────────────────             │
│  │                                                         │
│  │  Writer  ────────── 等待 ───── unique_lock ──          │
│  └─────────────────────────────────────────────┘            │
│  优势：多个读操作可以并行执行                                │
└─────────────────────────────────────────────────────────────┘

适用条件：
• 读操作远多于写操作（读写比 > 10:1）
• 读操作持有锁时间较长
• 读操作之间确实可以并行
*/

#include <shared_mutex>
#include <mutex>
#include <map>
#include <string>

// 使用读写锁的线程安全缓存
template<typename Key, typename Value>
class ThreadSafeCache {
private:
    std::map<Key, Value> cache_;
    mutable std::shared_mutex mutex_;

public:
    // 读操作：使用shared_lock（允许多个同时读）
    std::optional<Value> get(const Key& key) const {
        std::shared_lock<std::shared_mutex> lock(mutex_);
        auto it = cache_.find(key);
        if (it != cache_.end()) {
            return it->second;
        }
        return std::nullopt;
    }

    // 写操作：使用unique_lock（独占访问）
    void put(const Key& key, Value value) {
        std::unique_lock<std::shared_mutex> lock(mutex_);
        cache_[key] = std::move(value);
    }

    // 删除操作：需要独占锁
    bool remove(const Key& key) {
        std::unique_lock<std::shared_mutex> lock(mutex_);
        return cache_.erase(key) > 0;
    }

    // 查找并修改（原子操作）
    bool update_if_exists(const Key& key, std::function<Value(Value)> updater) {
        std::unique_lock<std::shared_mutex> lock(mutex_);
        auto it = cache_.find(key);
        if (it != cache_.end()) {
            it->second = updater(std::move(it->second));
            return true;
        }
        return false;
    }

    // 获取或计算（双检查模式）
    Value get_or_compute(const Key& key, std::function<Value()> compute) {
        // 首先尝试读取
        {
            std::shared_lock<std::shared_mutex> lock(mutex_);
            auto it = cache_.find(key);
            if (it != cache_.end()) {
                return it->second;
            }
        }

        // 需要写入
        std::unique_lock<std::shared_mutex> lock(mutex_);

        // 双检查：可能在等待写锁时其他线程已写入
        auto it = cache_.find(key);
        if (it != cache_.end()) {
            return it->second;
        }

        Value value = compute();
        cache_[key] = value;
        return value;
    }

    size_t size() const {
        std::shared_lock<std::shared_mutex> lock(mutex_);
        return cache_.size();
    }

    void clear() {
        std::unique_lock<std::shared_mutex> lock(mutex_);
        cache_.clear();
    }
};
```

#### 2. 读写锁的性能陷阱

```cpp
// ============================================================
// 读写锁的性能陷阱与注意事项
// ============================================================

/*
陷阱1：写饥饿（Writer Starvation）

┌─────────────────────────────────────────────────────────────┐
│  场景：持续有读请求                                          │
│                                                              │
│  Reader1 ─── shared_lock ───────────────────────            │
│  Reader2 ───────── shared_lock ─────────────────            │
│  Reader3 ─────────────── shared_lock ───────────            │
│  ...                                                         │
│  Writer  ─────────── 永远等待 ───────────────────           │
│                                                              │
│  问题：写操作可能永远无法获得锁！                            │
└─────────────────────────────────────────────────────────────┘

陷阱2：读写锁开销比普通锁大

读写锁需要：
• 维护读者计数
• 原子操作更多
• 缓存一致性流量更大

当读写比不够高时，读写锁反而比普通锁更慢！
*/

// 读写锁开销分析
class RWLockOverheadAnalysis {
public:
    // std::mutex 的开销：
    // • lock: 1次原子操作 + 可能的futex系统调用
    // • unlock: 1次原子操作 + 可能的futex唤醒

    // std::shared_mutex 的开销：
    // • shared_lock: 原子增加读者计数 + 检查写锁状态
    // • shared_unlock: 原子减少读者计数 + 可能唤醒写者
    // • unique_lock: 等待所有读者释放 + 设置写锁标志
    // • unique_unlock: 清除写锁标志 + 唤醒等待者

    /*
    性能对比（典型数据）：

    ┌────────────────────────────────────────────────────┐
    │  读写比     │  mutex    │  shared_mutex  │  胜者   │
    ├────────────────────────────────────────────────────┤
    │  100:0      │  100 ns   │  150 ns        │  mutex  │
    │  95:5       │  105 ns   │  160 ns        │  mutex  │
    │  90:10      │  120 ns   │  180 ns        │  取决   │
    │  80:20      │  200 ns   │  250 ns        │  取决   │
    │  70:30      │  400 ns   │  350 ns        │  shared │
    │  50:50      │  800 ns   │  500 ns        │  shared │
    └────────────────────────────────────────────────────┘

    结论：
    • 读写比 > 70:30 时 shared_mutex 才可能更优
    • 读操作要足够快，否则锁开销占比不明显
    • 竞争程度也影响结果
    */
};

// 实际性能测试
template<typename Lock, typename ReadLock, typename WriteLock>
class LockBenchmark {
public:
    struct Result {
        double avg_read_latency_ns;
        double avg_write_latency_ns;
        double total_throughput;
    };

    static Result benchmark(
        size_t num_readers,
        size_t num_writers,
        size_t iterations,
        std::function<void()> read_work,
        std::function<void()> write_work
    ) {
        Lock lock;
        std::atomic<size_t> read_count{0};
        std::atomic<size_t> write_count{0};
        std::atomic<long long> read_time{0};
        std::atomic<long long> write_time{0};

        auto start = std::chrono::high_resolution_clock::now();

        std::vector<std::thread> threads;

        // 启动读者
        for (size_t i = 0; i < num_readers; ++i) {
            threads.emplace_back([&]() {
                for (size_t j = 0; j < iterations; ++j) {
                    auto t1 = std::chrono::high_resolution_clock::now();
                    {
                        ReadLock rl(lock);
                        read_work();
                    }
                    auto t2 = std::chrono::high_resolution_clock::now();
                    read_time += std::chrono::duration_cast<std::chrono::nanoseconds>(t2 - t1).count();
                    ++read_count;
                }
            });
        }

        // 启动写者
        for (size_t i = 0; i < num_writers; ++i) {
            threads.emplace_back([&]() {
                for (size_t j = 0; j < iterations; ++j) {
                    auto t1 = std::chrono::high_resolution_clock::now();
                    {
                        WriteLock wl(lock);
                        write_work();
                    }
                    auto t2 = std::chrono::high_resolution_clock::now();
                    write_time += std::chrono::duration_cast<std::chrono::nanoseconds>(t2 - t1).count();
                    ++write_count;
                }
            });
        }

        for (auto& t : threads) t.join();

        auto end = std::chrono::high_resolution_clock::now();
        auto duration_ms = std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count();

        Result result;
        result.avg_read_latency_ns = read_count > 0 ?
            static_cast<double>(read_time) / read_count : 0;
        result.avg_write_latency_ns = write_count > 0 ?
            static_cast<double>(write_time) / write_count : 0;
        result.total_throughput = (read_count + write_count) * 1000.0 / duration_ms;

        return result;
    }
};
```

#### 3. 公平读写锁

```cpp
// ============================================================
// 公平读写锁：解决写饥饿问题
// ============================================================

/*
公平性策略：

策略1：写优先（Write-Preferring）
• 当有写者等待时，新的读请求排队
• 防止写饥饿
• 可能导致读延迟增加

策略2：读优先（Read-Preferring）
• 只要没有写者持有锁，读者就可以获取
• 写者可能饥饿
• 读延迟最低

策略3：公平（Fair）
• 按请求顺序排队
• 不会饥饿
• 实现复杂，开销大
*/

// 写优先读写锁
class WritePreferringRWLock {
private:
    std::mutex mutex_;
    std::condition_variable readers_cv_;
    std::condition_variable writers_cv_;

    int readers_ = 0;          // 当前读者数
    int writers_ = 0;          // 当前写者数（0或1）
    int waiting_writers_ = 0;   // 等待的写者数

public:
    void read_lock() {
        std::unique_lock<std::mutex> lock(mutex_);
        // 如果有写者或等待的写者，则等待
        readers_cv_.wait(lock, [this] {
            return writers_ == 0 && waiting_writers_ == 0;
        });
        ++readers_;
    }

    void read_unlock() {
        std::unique_lock<std::mutex> lock(mutex_);
        --readers_;
        if (readers_ == 0 && waiting_writers_ > 0) {
            writers_cv_.notify_one();
        }
    }

    void write_lock() {
        std::unique_lock<std::mutex> lock(mutex_);
        ++waiting_writers_;
        writers_cv_.wait(lock, [this] {
            return readers_ == 0 && writers_ == 0;
        });
        --waiting_writers_;
        ++writers_;
    }

    void write_unlock() {
        std::unique_lock<std::mutex> lock(mutex_);
        --writers_;
        // 优先唤醒写者
        if (waiting_writers_ > 0) {
            writers_cv_.notify_one();
        } else {
            readers_cv_.notify_all();
        }
    }
};

// RAII包装
class ReadGuard {
    WritePreferringRWLock& lock_;
public:
    explicit ReadGuard(WritePreferringRWLock& lock) : lock_(lock) {
        lock_.read_lock();
    }
    ~ReadGuard() {
        lock_.read_unlock();
    }
};

class WriteGuard {
    WritePreferringRWLock& lock_;
public:
    explicit WriteGuard(WritePreferringRWLock& lock) : lock_(lock) {
        lock_.write_lock();
    }
    ~WriteGuard() {
        lock_.write_unlock();
    }
};

// 公平读写锁（使用票号）
class FairRWLock {
private:
    std::mutex mutex_;
    std::condition_variable cv_;

    uint64_t next_ticket_ = 0;      // 下一个发放的票号
    uint64_t serving_ticket_ = 0;   // 当前服务的票号

    int readers_ = 0;
    bool writing_ = false;

    struct Waiter {
        uint64_t ticket;
        bool is_writer;
    };

public:
    void read_lock() {
        std::unique_lock<std::mutex> lock(mutex_);
        uint64_t my_ticket = next_ticket_++;

        cv_.wait(lock, [this, my_ticket] {
            // 可以读取的条件：
            // 1. 轮到我了或者已经过了我的票号
            // 2. 没有写者
            return my_ticket <= serving_ticket_ && !writing_;
        });

        ++readers_;
        // 允许后续读者一起进入
        if (!writing_) {
            cv_.notify_all();
        }
    }

    void read_unlock() {
        std::unique_lock<std::mutex> lock(mutex_);
        --readers_;
        if (readers_ == 0) {
            ++serving_ticket_;
            cv_.notify_all();
        }
    }

    void write_lock() {
        std::unique_lock<std::mutex> lock(mutex_);
        uint64_t my_ticket = next_ticket_++;

        cv_.wait(lock, [this, my_ticket] {
            return my_ticket == serving_ticket_ && readers_ == 0 && !writing_;
        });

        writing_ = true;
    }

    void write_unlock() {
        std::unique_lock<std::mutex> lock(mutex_);
        writing_ = false;
        ++serving_ticket_;
        cv_.notify_all();
    }
};
```

### Day 10-11：高级优化方案

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | RCU原理与实现 | 2h |
| 下午 | 分段锁设计 | 3h |
| 晚上 | 方案对比分析 | 2h |

#### 1. RCU（Read-Copy-Update）原理

```cpp
// ============================================================
// RCU：读操作零开销的并发原语（Month 16 回顾与深化）
// ============================================================

/*
RCU的核心思想：

┌─────────────────────────────────────────────────────────────┐
│  传统方法（读写锁）：                                        │
│  读操作：lock → read → unlock                               │
│  写操作：lock → write → unlock                              │
│                                                              │
│  问题：读操作仍需获取锁，有开销                              │
├─────────────────────────────────────────────────────────────┤
│  RCU方法：                                                   │
│  读操作：直接读（无锁！）                                    │
│  写操作：                                                    │
│    1. 复制旧数据                                             │
│    2. 修改副本                                               │
│    3. 原子替换指针                                           │
│    4. 等待旧读者完成                                         │
│    5. 回收旧数据                                             │
│                                                              │
│  优势：读操作完全无锁，零开销！                              │
└─────────────────────────────────────────────────────────────┘

RCU的工作流程：

时间线：────────────────────────────────────────────────────→
        │                     │
        │  旧数据             │  新数据
        ├─────────────────────┤
        │                     │
Reader1 ├── 读旧数据 ─────────┤
Reader2 │      ├── 读旧数据 ──┤
Reader3 │           │  ├──────┼── 读新数据 ──
        │           │  │      │
Writer  │───────────│──┤      │
        │   复制    │  │ 替换 │ 等待    回收
        │   修改    │  │ 指针 │ grace   旧数据
        │           │  │      │ period
*/

#include <atomic>
#include <memory>
#include <vector>
#include <functional>

// 简化的RCU实现
template<typename T>
class SimpleRCU {
private:
    std::atomic<T*> data_;
    std::atomic<uint64_t> version_{0};

    // 简化的grace period：使用版本号
    std::atomic<uint64_t> reader_version_[64];  // 假设最多64个线程

public:
    SimpleRCU(T* initial = nullptr) : data_(initial) {
        for (auto& v : reader_version_) {
            v.store(0);
        }
    }

    ~SimpleRCU() {
        delete data_.load();
    }

    // 读端临界区开始（获取当前版本）
    class ReadGuard {
        SimpleRCU& rcu_;
        int thread_id_;
        uint64_t version_;

    public:
        ReadGuard(SimpleRCU& rcu, int thread_id)
            : rcu_(rcu), thread_id_(thread_id) {
            version_ = rcu_.version_.load(std::memory_order_acquire);
            rcu_.reader_version_[thread_id_].store(version_,
                std::memory_order_release);
        }

        ~ReadGuard() {
            rcu_.reader_version_[thread_id_].store(0,
                std::memory_order_release);
        }

        const T* get() const {
            return rcu_.data_.load(std::memory_order_acquire);
        }
    };

    // 读操作（几乎零开销）
    ReadGuard read(int thread_id) {
        return ReadGuard(*this, thread_id);
    }

    // 写操作
    void update(std::function<T*(const T*)> updater) {
        // 1. 复制并修改
        T* old_data = data_.load(std::memory_order_acquire);
        T* new_data = updater(old_data);

        // 2. 原子替换
        data_.store(new_data, std::memory_order_release);
        uint64_t new_version = version_.fetch_add(1, std::memory_order_acq_rel) + 1;

        // 3. 等待grace period
        synchronize_rcu(new_version - 1);

        // 4. 回收旧数据
        delete old_data;
    }

private:
    void synchronize_rcu(uint64_t old_version) {
        // 等待所有读者退出旧版本
        for (const auto& v : reader_version_) {
            while (true) {
                uint64_t reader_v = v.load(std::memory_order_acquire);
                // reader_v == 0 表示不在读临界区
                // reader_v > old_version 表示已经在读新版本
                if (reader_v == 0 || reader_v > old_version) {
                    break;
                }
                std::this_thread::yield();
            }
        }
    }
};

// 使用示例
/*
struct Config {
    std::string server;
    int port;
    int timeout;
};

SimpleRCU<Config> config_rcu(new Config{"localhost", 8080, 30});

// 读者（零锁开销）
void reader_thread(int thread_id) {
    auto guard = config_rcu.read(thread_id);
    const Config* cfg = guard.get();
    // 使用cfg...
}

// 写者
void update_config() {
    config_rcu.update([](const Config* old) {
        Config* new_cfg = new Config(*old);
        new_cfg->port = 9090;
        return new_cfg;
    });
}
*/
```

#### 2. 分段锁（Striped Locking）

```cpp
// ============================================================
// 分段锁：通过分散锁竞争提高并发度
// ============================================================

/*
分段锁原理：

传统方案（单锁）：
┌─────────────────────────────────────────────────────────────┐
│  所有操作竞争同一把锁                                        │
│                                                              │
│  Thread1 ─┐                                                  │
│  Thread2 ─┼─→ [单个锁] ─→ [数据结构]                        │
│  Thread3 ─┤                                                  │
│  Thread4 ─┘                                                  │
│                                                              │
│  高竞争 = 低性能                                             │
└─────────────────────────────────────────────────────────────┘

分段锁方案：
┌─────────────────────────────────────────────────────────────┐
│  按key哈希分散到不同锁                                       │
│                                                              │
│  Thread1 ─→ [锁0] ─→ [段0]                                  │
│  Thread2 ─→ [锁1] ─→ [段1]                                  │
│  Thread3 ─→ [锁2] ─→ [段2]                                  │
│  Thread4 ─→ [锁0] ─→ [段0]  // 只有这里有竞争                │
│                                                              │
│  竞争分散 = 高性能                                           │
└─────────────────────────────────────────────────────────────┘
*/

#include <mutex>
#include <shared_mutex>
#include <vector>
#include <unordered_map>

// 分段锁HashMap
template<typename Key, typename Value, size_t NumStripes = 16>
class StripedHashMap {
private:
    struct Stripe {
        mutable std::shared_mutex mutex;
        std::unordered_map<Key, Value> data;
    };

    std::array<Stripe, NumStripes> stripes_;

    // 计算key属于哪个分段
    size_t get_stripe_index(const Key& key) const {
        return std::hash<Key>{}(key) % NumStripes;
    }

public:
    // 读操作
    std::optional<Value> get(const Key& key) const {
        size_t index = get_stripe_index(key);
        std::shared_lock<std::shared_mutex> lock(stripes_[index].mutex);

        auto it = stripes_[index].data.find(key);
        if (it != stripes_[index].data.end()) {
            return it->second;
        }
        return std::nullopt;
    }

    // 写操作
    void put(const Key& key, Value value) {
        size_t index = get_stripe_index(key);
        std::unique_lock<std::shared_mutex> lock(stripes_[index].mutex);
        stripes_[index].data[key] = std::move(value);
    }

    // 删除操作
    bool remove(const Key& key) {
        size_t index = get_stripe_index(key);
        std::unique_lock<std::shared_mutex> lock(stripes_[index].mutex);
        return stripes_[index].data.erase(key) > 0;
    }

    // 更新操作
    bool update(const Key& key, std::function<Value(Value)> updater) {
        size_t index = get_stripe_index(key);
        std::unique_lock<std::shared_mutex> lock(stripes_[index].mutex);

        auto it = stripes_[index].data.find(key);
        if (it != stripes_[index].data.end()) {
            it->second = updater(std::move(it->second));
            return true;
        }
        return false;
    }

    // 获取所有key（需要锁定所有分段）
    std::vector<Key> keys() const {
        std::vector<Key> result;

        // 按顺序锁定所有分段（防止死锁）
        std::vector<std::shared_lock<std::shared_mutex>> locks;
        for (const auto& stripe : stripes_) {
            locks.emplace_back(stripe.mutex);
        }

        for (const auto& stripe : stripes_) {
            for (const auto& [k, v] : stripe.data) {
                result.push_back(k);
            }
        }

        return result;
    }

    // 获取大小（近似值，不加锁）
    size_t approximate_size() const {
        size_t total = 0;
        for (const auto& stripe : stripes_) {
            std::shared_lock<std::shared_mutex> lock(stripe.mutex);
            total += stripe.data.size();
        }
        return total;
    }

    // 精确大小（需要锁定所有分段）
    size_t exact_size() const {
        std::vector<std::shared_lock<std::shared_mutex>> locks;
        for (const auto& stripe : stripes_) {
            locks.emplace_back(stripe.mutex);
        }

        size_t total = 0;
        for (const auto& stripe : stripes_) {
            total += stripe.data.size();
        }
        return total;
    }
};

/*
分段锁的选择：

分段数的选择：
• 太少：竞争仍然高
• 太多：内存开销大，缓存利用率低
• 经验法则：NumStripes = 2 * num_threads，向上取2的幂

分段数 = 16-32 通常是个好的起点

性能对比（8线程，100万操作）：
┌────────────────────────────────────────┐
│  方案          │  时间(ms)  │  加速比  │
├────────────────────────────────────────┤
│  单mutex       │  2500      │  1.0x    │
│  shared_mutex  │  1800      │  1.4x    │
│  分段锁(4)     │  800       │  3.1x    │
│  分段锁(16)    │  350       │  7.1x    │
│  分段锁(64)    │  320       │  7.8x    │
└────────────────────────────────────────┘
*/
```

#### 3. 分段锁 + 读写锁

```cpp
// ============================================================
// 分段锁与读写锁的组合：最大化并发度
// ============================================================

// 缓存行对齐，避免伪共享
struct alignas(64) CacheLineAlignedMutex {
    std::shared_mutex mutex;
    char padding[64 - sizeof(std::shared_mutex)];
};

template<typename Key, typename Value, size_t NumStripes = 16>
class OptimizedStripedMap {
private:
    // 每个分段独立的缓存行，避免伪共享
    std::array<CacheLineAlignedMutex, NumStripes> mutexes_;
    std::array<std::unordered_map<Key, Value>, NumStripes> data_;

    size_t stripe(const Key& key) const {
        // 使用更好的哈希分散
        size_t h = std::hash<Key>{}(key);
        h ^= h >> 16;
        return h % NumStripes;
    }

public:
    // 批量读取（减少锁获取次数）
    std::vector<std::pair<Key, std::optional<Value>>>
    multi_get(const std::vector<Key>& keys) const {
        // 按分段分组
        std::array<std::vector<size_t>, NumStripes> indices_by_stripe;
        for (size_t i = 0; i < keys.size(); ++i) {
            indices_by_stripe[stripe(keys[i])].push_back(i);
        }

        std::vector<std::pair<Key, std::optional<Value>>> results(keys.size());

        // 每个分段只锁一次
        for (size_t s = 0; s < NumStripes; ++s) {
            if (indices_by_stripe[s].empty()) continue;

            std::shared_lock lock(mutexes_[s].mutex);
            for (size_t i : indices_by_stripe[s]) {
                auto it = data_[s].find(keys[i]);
                if (it != data_[s].end()) {
                    results[i] = {keys[i], it->second};
                } else {
                    results[i] = {keys[i], std::nullopt};
                }
            }
        }

        return results;
    }

    // 批量写入
    void multi_put(const std::vector<std::pair<Key, Value>>& entries) {
        // 按分段分组
        std::array<std::vector<size_t>, NumStripes> indices_by_stripe;
        for (size_t i = 0; i < entries.size(); ++i) {
            indices_by_stripe[stripe(entries[i].first)].push_back(i);
        }

        // 每个分段只锁一次
        for (size_t s = 0; s < NumStripes; ++s) {
            if (indices_by_stripe[s].empty()) continue;

            std::unique_lock lock(mutexes_[s].mutex);
            for (size_t i : indices_by_stripe[s]) {
                data_[s][entries[i].first] = entries[i].second;
            }
        }
    }
};
```

### Day 12-13：性能对比实验

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | 基准测试框架 | 2h |
| 下午 | 不同场景测试 | 3h |
| 晚上 | 缓存行分析 | 2h |

#### 1. 全面性能对比框架

```cpp
// ============================================================
// 读写锁vs RCU vs分段锁 性能对比
// ============================================================

#include <chrono>
#include <thread>
#include <random>
#include <iostream>
#include <iomanip>

// 测试配置
struct RWBenchConfig {
    size_t num_threads;
    size_t operations_per_thread;
    double read_ratio;  // 读操作比例 (0.0 - 1.0)
    size_t data_size;   // 数据规模
};

// 测试结果
struct RWBenchResult {
    std::string name;
    double total_time_ms;
    double read_throughput;   // reads/s
    double write_throughput;  // writes/s
    double avg_read_latency_ns;
    double avg_write_latency_ns;
};

// 通用测试框架
template<typename Container>
class RWBenchmark {
public:
    static RWBenchResult run(
        const std::string& name,
        Container& container,
        const RWBenchConfig& config
    ) {
        std::atomic<size_t> total_reads{0};
        std::atomic<size_t> total_writes{0};
        std::atomic<long long> read_latency_sum{0};
        std::atomic<long long> write_latency_sum{0};

        auto start = std::chrono::high_resolution_clock::now();

        std::vector<std::thread> threads;
        for (size_t t = 0; t < config.num_threads; ++t) {
            threads.emplace_back([&, t]() {
                std::mt19937 rng(t);
                std::uniform_real_distribution<> ratio_dist(0.0, 1.0);
                std::uniform_int_distribution<> key_dist(0, config.data_size - 1);

                for (size_t i = 0; i < config.operations_per_thread; ++i) {
                    int key = key_dist(rng);

                    if (ratio_dist(rng) < config.read_ratio) {
                        // 读操作
                        auto t1 = std::chrono::high_resolution_clock::now();
                        auto result = container.get(key);
                        auto t2 = std::chrono::high_resolution_clock::now();

                        (void)result;  // 防止优化掉
                        ++total_reads;
                        read_latency_sum += std::chrono::duration_cast<
                            std::chrono::nanoseconds>(t2 - t1).count();
                    } else {
                        // 写操作
                        auto t1 = std::chrono::high_resolution_clock::now();
                        container.put(key, static_cast<int>(i));
                        auto t2 = std::chrono::high_resolution_clock::now();

                        ++total_writes;
                        write_latency_sum += std::chrono::duration_cast<
                            std::chrono::nanoseconds>(t2 - t1).count();
                    }
                }
            });
        }

        for (auto& t : threads) t.join();

        auto end = std::chrono::high_resolution_clock::now();
        double duration_ms = std::chrono::duration_cast<
            std::chrono::milliseconds>(end - start).count();

        RWBenchResult result;
        result.name = name;
        result.total_time_ms = duration_ms;
        result.read_throughput = total_reads * 1000.0 / duration_ms;
        result.write_throughput = total_writes * 1000.0 / duration_ms;
        result.avg_read_latency_ns = total_reads > 0 ?
            static_cast<double>(read_latency_sum) / total_reads : 0;
        result.avg_write_latency_ns = total_writes > 0 ?
            static_cast<double>(write_latency_sum) / total_writes : 0;

        return result;
    }
};

// 打印对比结果
void print_rw_comparison(const std::vector<RWBenchResult>& results) {
    std::cout << "\n=== 读写方案性能对比 ===\n\n";

    std::cout << std::setw(20) << "方案"
              << std::setw(12) << "时间(ms)"
              << std::setw(15) << "读吞吐(K/s)"
              << std::setw(15) << "写吞吐(K/s)"
              << std::setw(15) << "读延迟(ns)"
              << std::setw(15) << "写延迟(ns)"
              << "\n";
    std::cout << std::string(92, '-') << "\n";

    for (const auto& r : results) {
        std::cout << std::setw(20) << r.name
                  << std::setw(12) << std::fixed << std::setprecision(1)
                  << r.total_time_ms
                  << std::setw(15) << std::fixed << std::setprecision(1)
                  << r.read_throughput / 1000
                  << std::setw(15) << std::fixed << std::setprecision(1)
                  << r.write_throughput / 1000
                  << std::setw(15) << std::fixed << std::setprecision(0)
                  << r.avg_read_latency_ns
                  << std::setw(15) << std::fixed << std::setprecision(0)
                  << r.avg_write_latency_ns
                  << "\n";
    }
}

/*
典型测试结果（8线程，读写比90:10）：

┌─────────────────────────────────────────────────────────────────────────────────┐
│  方案              │ 时间(ms) │ 读吞吐(K/s) │ 写吞吐(K/s) │ 读延迟(ns) │ 写延迟(ns) │
├─────────────────────────────────────────────────────────────────────────────────┤
│  mutex             │   850    │    1058     │     117     │    680     │    720     │
│  shared_mutex      │   620    │    1452     │     161     │    500     │    620     │
│  写优先RWLock      │   700    │    1286     │     143     │    560     │    700     │
│  分段锁(16)        │   180    │    5000     │     555     │    140     │    180     │
│  分段锁+RWLock     │   150    │    6000     │     666     │    120     │    150     │
│  RCU简化版         │   100    │    9000     │     100     │     80     │   8000     │
└─────────────────────────────────────────────────────────────────────────────────┘

结论分析：
• mutex：简单但竞争高
• shared_mutex：读多场景有优势，但开销不小
• 分段锁：显著降低竞争，适合通用场景
• RCU：读性能最优，但写开销大，适合读极端多的场景
*/
```

#### 2. 缓存行与伪共享分析

```cpp
// ============================================================
// 伪共享（False Sharing）分析与优化
// ============================================================

/*
伪共享原理：

CPU缓存以缓存行（通常64字节）为单位
当多个线程访问同一缓存行的不同变量时
会导致缓存行在CPU间频繁失效

┌─────────────────────────────────────────────────────────────┐
│  问题场景：                                                  │
│                                                              │
│  缓存行 [  var_a  |  var_b  |  var_c  |  var_d  ]           │
│           ↑           ↑           ↑           ↑              │
│        Thread1     Thread2    Thread3     Thread4            │
│                                                              │
│  任何一个线程修改，其他线程的缓存行都失效！                  │
│  导致严重的性能下降                                          │
└─────────────────────────────────────────────────────────────┘
*/

#include <atomic>
#include <new>  // std::hardware_destructive_interference_size

// 错误示例：有伪共享的计数器数组
struct BadCounters {
    std::atomic<size_t> counters[8];

    void increment(size_t index) {
        counters[index].fetch_add(1, std::memory_order_relaxed);
    }
};

// 正确示例：缓存行对齐的计数器
struct alignas(64) AlignedCounter {
    std::atomic<size_t> value{0};
    char padding[64 - sizeof(std::atomic<size_t>)];
};

struct GoodCounters {
    AlignedCounter counters[8];

    void increment(size_t index) {
        counters[index].value.fetch_add(1, std::memory_order_relaxed);
    }
};

// C++17方式（如果支持）
#ifdef __cpp_lib_hardware_interference_size
constexpr size_t CACHE_LINE_SIZE = std::hardware_destructive_interference_size;
#else
constexpr size_t CACHE_LINE_SIZE = 64;  // 假设64字节
#endif

template<typename T>
struct alignas(CACHE_LINE_SIZE) CacheLineAligned {
    T value;
    char padding[CACHE_LINE_SIZE - sizeof(T) % CACHE_LINE_SIZE];
};

// 伪共享性能测试
class FalseSharingBenchmark {
public:
    static void compare() {
        constexpr size_t NUM_THREADS = 8;
        constexpr size_t ITERATIONS = 10000000;

        // 测试有伪共享的情况
        {
            BadCounters counters;
            auto start = std::chrono::high_resolution_clock::now();

            std::vector<std::thread> threads;
            for (size_t i = 0; i < NUM_THREADS; ++i) {
                threads.emplace_back([&counters, i]() {
                    for (size_t j = 0; j < ITERATIONS; ++j) {
                        counters.increment(i);
                    }
                });
            }
            for (auto& t : threads) t.join();

            auto end = std::chrono::high_resolution_clock::now();
            auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count();
            std::cout << "有伪共享: " << ms << " ms\n";
        }

        // 测试无伪共享的情况
        {
            GoodCounters counters;
            auto start = std::chrono::high_resolution_clock::now();

            std::vector<std::thread> threads;
            for (size_t i = 0; i < NUM_THREADS; ++i) {
                threads.emplace_back([&counters, i]() {
                    for (size_t j = 0; j < ITERATIONS; ++j) {
                        counters.increment(i);
                    }
                });
            }
            for (auto& t : threads) t.join();

            auto end = std::chrono::high_resolution_clock::now();
            auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count();
            std::cout << "无伪共享: " << ms << " ms\n";
        }
    }
};

/*
典型结果：
有伪共享: 2500 ms
无伪共享: 150 ms

差距可达10-20倍！
*/
```

#### 3. NUMA感知优化

```cpp
// ============================================================
// NUMA感知的数据结构设计
// ============================================================

/*
NUMA (Non-Uniform Memory Access) 架构：

┌─────────────────────────────────────────────────────────────┐
│  传统 SMP:                                                   │
│                                                              │
│  [CPU0] [CPU1] [CPU2] [CPU3]                                │
│           ↓                                                  │
│       [共享内存]                                             │
│                                                              │
│  所有CPU访问内存延迟相同                                     │
├─────────────────────────────────────────────────────────────┤
│  NUMA:                                                       │
│                                                              │
│  Node 0                    Node 1                            │
│  [CPU0] [CPU1]            [CPU2] [CPU3]                     │
│       ↓                         ↓                            │
│    [本地内存]  ←─ 互联 ─→  [本地内存]                       │
│                                                              │
│  本地访问: 80ns                                              │
│  远程访问: 150ns  (慢约2倍！)                               │
└─────────────────────────────────────────────────────────────┘
*/

// NUMA感知的分段锁设计（概念性代码）
template<typename Key, typename Value>
class NUMAStripedMap {
private:
    static constexpr size_t NUM_NODES = 2;  // NUMA节点数
    static constexpr size_t STRIPES_PER_NODE = 8;

    struct NodeData {
        std::array<std::shared_mutex, STRIPES_PER_NODE> mutexes;
        std::array<std::unordered_map<Key, Value>, STRIPES_PER_NODE> data;
    };

    // 每个NUMA节点的数据应该分配在该节点的本地内存
    std::array<NodeData*, NUM_NODES> nodes_;

public:
    NUMAStripedMap() {
        // 实际应用中使用 numa_alloc_onnode 等API
        for (size_t i = 0; i < NUM_NODES; ++i) {
            nodes_[i] = new NodeData();
        }
    }

    ~NUMAStripedMap() {
        for (auto* node : nodes_) {
            delete node;
        }
    }

    // 获取当前线程所在的NUMA节点
    static size_t current_numa_node() {
        // 实际应用中使用 numa_node_of_cpu(sched_getcpu())
        return 0;  // 简化
    }

    // 优先访问本地节点
    std::optional<Value> get(const Key& key) const {
        size_t local_node = current_numa_node();

        // 首先在本地节点查找
        size_t stripe = std::hash<Key>{}(key) % STRIPES_PER_NODE;

        {
            std::shared_lock lock(nodes_[local_node]->mutexes[stripe]);
            auto it = nodes_[local_node]->data[stripe].find(key);
            if (it != nodes_[local_node]->data[stripe].end()) {
                return it->second;
            }
        }

        // 在其他节点查找
        for (size_t node = 0; node < NUM_NODES; ++node) {
            if (node == local_node) continue;

            std::shared_lock lock(nodes_[node]->mutexes[stripe]);
            auto it = nodes_[node]->data[stripe].find(key);
            if (it != nodes_[node]->data[stripe].end()) {
                return it->second;
            }
        }

        return std::nullopt;
    }

    // 写入本地节点
    void put(const Key& key, Value value) {
        size_t local_node = current_numa_node();
        size_t stripe = std::hash<Key>{}(key) % STRIPES_PER_NODE;

        std::unique_lock lock(nodes_[local_node]->mutexes[stripe]);
        nodes_[local_node]->data[stripe][key] = std::move(value);
    }
};
```

### Day 14：第二周总结与检验

#### 方案选择决策表

```cpp
// ============================================================
// 读写优化方案选择指南
// ============================================================

/*
┌────────────────────────────────────────────────────────────────────────────┐
│                        读写优化方案选择决策表                               │
├────────────────────────────────────────────────────────────────────────────┤
│  场景特征                    │  推荐方案           │  原因                  │
├────────────────────────────────────────────────────────────────────────────┤
│  读写比 < 50:50             │  mutex              │  开销低，实现简单       │
│  读写比 50:50 - 80:20       │  分段锁             │  降低竞争               │
│  读写比 80:20 - 95:5        │  分段锁 + RWLock    │  组合优势               │
│  读写比 > 95:5              │  RCU                │  读零开销               │
├────────────────────────────────────────────────────────────────────────────┤
│  高竞争 + 多核              │  分段锁             │  分散竞争               │
│  低竞争 + 简单场景          │  mutex              │  足够好                 │
├────────────────────────────────────────────────────────────────────────────┤
│  配置/元数据（极少写）      │  RCU                │  读极致性能             │
│  缓存系统                   │  分段锁             │  读写都要快             │
│  计数器/统计               │  原子操作           │  无锁最佳               │
└────────────────────────────────────────────────────────────────────────────┘

各方案复杂度对比：

┌──────────────┬──────────┬──────────┬──────────┬──────────┐
│  方案        │ 实现难度 │ 调试难度 │ 维护成本 │ 性能上限 │
├──────────────┼──────────┼──────────┼──────────┼──────────┤
│  mutex       │   低     │   低     │   低     │   中     │
│  shared_mutex│   低     │   中     │   低     │   中高   │
│  分段锁      │   中     │   中     │   中     │   高     │
│  RCU         │   高     │   高     │   高     │   极高   │
│  无锁        │   极高   │   极高   │   极高   │   极高   │
└──────────────┴──────────┴──────────┴──────────┴──────────┘

建议：
• 从简单方案开始
• 先测量，后优化
• 复杂方案只在确实需要时使用
*/
```

#### 第二周检验标准

- [ ] 理解shared_mutex的使用方式和适用场景
- [ ] 能解释读写锁的性能陷阱（写饥饿、开销）
- [ ] 能实现写优先或公平的读写锁
- [ ] 理解RCU的工作原理和grace period概念
- [ ] 能实现简化版RCU
- [ ] 能设计和实现分段锁
- [ ] 理解伪共享问题并能解决
- [ ] 能根据场景选择合适的读写优化方案

---

## 第三周：模式选择与决策指南（Day 15-21）

> **本周目标**：建立从场景到方案的系统决策框架，掌握各种并发模式的权衡

### Day 15-16：双缓冲与无锁交换

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | 双缓冲原理 | 2h |
| 下午 | 原子交换实现 | 3h |
| 晚上 | 应用场景分析 | 2h |

#### 1. 双缓冲技术原理

```cpp
// ============================================================
// 双缓冲：解耦读写的经典技术
// ============================================================

/*
双缓冲原理：

┌─────────────────────────────────────────────────────────────┐
│  传统方法：读写竞争同一数据                                  │
│                                                              │
│  Writer ──┐                                                  │
│           ├──→ [Data] ←──┤                                  │
│  Reader ──┘              │                                  │
│                          ↓                                   │
│                   需要同步！                                 │
├─────────────────────────────────────────────────────────────┤
│  双缓冲：读写分离                                            │
│                                                              │
│  Writer ──→ [Front Buffer]  ←── Reader                      │
│             [Back Buffer]                                    │
│                  ↑                                           │
│            写完后交换                                        │
│                                                              │
│  优势：读写完全并行，无竞争！                                │
└─────────────────────────────────────────────────────────────┘

典型应用场景：
• 游戏渲染：渲染线程读前缓冲，更新线程写后缓冲
• 日志系统：写日志到后缓冲，刷盘线程读前缓冲
• 配置热更新：新配置写后缓冲，服务读前缓冲
• 传感器数据：采集线程写，处理线程读
*/

#include <atomic>
#include <array>
#include <memory>

// 基础双缓冲
template<typename T>
class DoubleBuffer {
private:
    std::array<T, 2> buffers_;
    std::atomic<int> front_index_{0};  // 0 或 1
    std::mutex swap_mutex_;  // 保护交换操作

public:
    DoubleBuffer() = default;

    // 初始化两个缓冲区
    DoubleBuffer(const T& initial) : buffers_{initial, initial} {}

    // 获取前缓冲（读取用）
    const T& front() const {
        return buffers_[front_index_.load(std::memory_order_acquire)];
    }

    // 获取后缓冲（写入用）
    T& back() {
        return buffers_[1 - front_index_.load(std::memory_order_acquire)];
    }

    // 交换前后缓冲（原子操作）
    void swap() {
        std::lock_guard<std::mutex> lock(swap_mutex_);
        front_index_.store(1 - front_index_.load(), std::memory_order_release);
    }

    // 安全交换（等待所有读者完成）
    // 注意：这个简单版本假设读操作很快
    void safe_swap() {
        std::lock_guard<std::mutex> lock(swap_mutex_);
        // 实际应用中可能需要更复杂的同步
        front_index_.store(1 - front_index_.load(), std::memory_order_release);
    }
};

// 使用示例
/*
struct GameState {
    std::vector<Entity> entities;
    std::vector<Particle> particles;
    Camera camera;
};

DoubleBuffer<GameState> game_state;

// 更新线程
void update_thread() {
    while (running) {
        GameState& back = game_state.back();
        update_physics(back);
        update_ai(back);
        game_state.swap();
    }
}

// 渲染线程
void render_thread() {
    while (running) {
        const GameState& front = game_state.front();
        render(front);  // 渲染过程中数据稳定
    }
}
*/
```

#### 2. 原子交换双缓冲

```cpp
// ============================================================
// 无锁双缓冲：使用原子指针交换
// ============================================================

template<typename T>
class AtomicDoubleBuffer {
private:
    std::unique_ptr<T> buffer1_;
    std::unique_ptr<T> buffer2_;
    std::atomic<T*> front_;

public:
    AtomicDoubleBuffer()
        : buffer1_(std::make_unique<T>())
        , buffer2_(std::make_unique<T>())
        , front_(buffer1_.get())
    {}

    AtomicDoubleBuffer(T initial1, T initial2)
        : buffer1_(std::make_unique<T>(std::move(initial1)))
        , buffer2_(std::make_unique<T>(std::move(initial2)))
        , front_(buffer1_.get())
    {}

    // 获取当前前缓冲（无锁读取）
    T* get_front() {
        return front_.load(std::memory_order_acquire);
    }

    const T* get_front() const {
        return front_.load(std::memory_order_acquire);
    }

    // 获取后缓冲进行修改
    T* get_back() {
        T* front = front_.load(std::memory_order_acquire);
        return (front == buffer1_.get()) ? buffer2_.get() : buffer1_.get();
    }

    // 原子交换
    void swap_buffers() {
        T* current_front = front_.load(std::memory_order_acquire);
        T* new_front = (current_front == buffer1_.get())
            ? buffer2_.get() : buffer1_.get();
        front_.store(new_front, std::memory_order_release);
    }

    // CAS交换（更安全）
    bool try_swap() {
        T* expected_front = front_.load(std::memory_order_acquire);
        T* new_front = (expected_front == buffer1_.get())
            ? buffer2_.get() : buffer1_.get();
        return front_.compare_exchange_strong(
            expected_front, new_front,
            std::memory_order_acq_rel
        );
    }
};

// 三缓冲（Triple Buffer）：进一步解耦
template<typename T>
class TripleBuffer {
private:
    std::array<T, 3> buffers_;

    // 状态：front（显示）、back（写入）、ready（就绪）
    std::atomic<int> front_idx_{0};
    std::atomic<int> back_idx_{1};
    std::atomic<int> ready_idx_{2};

    std::atomic<bool> has_new_data_{false};

public:
    TripleBuffer() = default;

    // 写入线程使用
    T& get_write_buffer() {
        return buffers_[back_idx_.load(std::memory_order_acquire)];
    }

    // 写入完成，标记就绪
    void write_done() {
        // 交换back和ready
        int old_ready = ready_idx_.exchange(
            back_idx_.load(std::memory_order_acquire),
            std::memory_order_acq_rel
        );
        back_idx_.store(old_ready, std::memory_order_release);
        has_new_data_.store(true, std::memory_order_release);
    }

    // 读取线程使用
    const T& get_read_buffer() {
        return buffers_[front_idx_.load(std::memory_order_acquire)];
    }

    // 尝试获取最新数据
    bool try_get_newest() {
        if (!has_new_data_.load(std::memory_order_acquire)) {
            return false;
        }

        // 交换front和ready
        int old_front = front_idx_.exchange(
            ready_idx_.load(std::memory_order_acquire),
            std::memory_order_acq_rel
        );
        ready_idx_.store(old_front, std::memory_order_release);
        has_new_data_.store(false, std::memory_order_release);
        return true;
    }
};

/*
三缓冲 vs 双缓冲：

双缓冲：
• 优点：内存占用少
• 缺点：写入必须等读取完成（或丢帧）

三缓冲：
• 优点：写入和读取完全解耦
• 缺点：多用一份内存，可能有一帧延迟

适用场景：
• 双缓冲：帧率稳定，同步要求高
• 三缓冲：生产者消费者速度不匹配，允许丢帧
*/
```

#### 3. 双缓冲在异步I/O中的应用

```cpp
// ============================================================
// 双缓冲在Month 22异步I/O中的应用
// ============================================================

/*
回顾Month 22的EventLoop：

EventLoop需要处理：
1. 就绪的I/O事件（从epoll/kqueue获取）
2. 用户提交的任务（从其他线程）

问题：任务队列的同步开销

解决：使用双缓冲任务队列
*/

#include <vector>
#include <functional>

class DoubleBufferedTaskQueue {
private:
    using Task = std::function<void()>;

    std::vector<Task> buffer1_;
    std::vector<Task> buffer2_;
    std::atomic<std::vector<Task>*> write_buffer_;
    std::vector<Task>* read_buffer_;

    std::mutex submit_mutex_;  // 只保护提交操作

public:
    DoubleBufferedTaskQueue()
        : write_buffer_(&buffer1_)
        , read_buffer_(&buffer2_)
    {
        buffer1_.reserve(256);
        buffer2_.reserve(256);
    }

    // 提交任务（可能从其他线程调用）
    void submit(Task task) {
        std::lock_guard<std::mutex> lock(submit_mutex_);
        write_buffer_.load(std::memory_order_acquire)->push_back(std::move(task));
    }

    // 批量提交
    void submit_batch(std::vector<Task>&& tasks) {
        std::lock_guard<std::mutex> lock(submit_mutex_);
        auto* buffer = write_buffer_.load(std::memory_order_acquire);
        for (auto& task : tasks) {
            buffer->push_back(std::move(task));
        }
    }

    // 交换并获取任务（只在EventLoop线程调用）
    std::vector<Task>& swap_and_get() {
        // 先清空读缓冲
        read_buffer_->clear();

        // 原子交换
        {
            std::lock_guard<std::mutex> lock(submit_mutex_);
            std::swap(read_buffer_, *reinterpret_cast<std::vector<Task>**>(
                &write_buffer_));
        }

        return *read_buffer_;
    }

    // 在EventLoop中使用
    void process_tasks() {
        auto& tasks = swap_and_get();
        for (auto& task : tasks) {
            task();
        }
    }
};

/*
性能对比：

传统队列（每次操作都加锁）：
• submit: lock + push + unlock
• process: lock + pop + unlock × N

双缓冲队列：
• submit: lock + push + unlock（写锁不影响读）
• process: 一次lock + swap，然后无锁处理所有任务

当任务量大时，双缓冲显著减少锁竞争！
*/
```

### Day 17-18：并发模式对比框架

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | 共享内存vs消息传递 | 2h |
| 下午 | 锁vs无锁vs Actor | 3h |
| 晚上 | 线程vs协程vs Future | 2h |

#### 1. 共享内存 vs 消息传递

```cpp
// ============================================================
// 并发模型对比：共享内存 vs 消息传递
// ============================================================

/*
两种并发哲学：

┌─────────────────────────────────────────────────────────────┐
│  共享内存模型（Month 13-17的主要内容）                       │
│                                                              │
│  Thread1 ──┐                                                 │
│            ├──→ [共享数据] ←──同步原语                       │
│  Thread2 ──┘       ↑                                         │
│                    │                                         │
│  特点：                                                      │
│  • 直接访问共享状态                                          │
│  • 需要显式同步（锁、原子操作）                              │
│  • 易出错（死锁、竞态）                                      │
│  • 性能可以很高                                              │
├─────────────────────────────────────────────────────────────┤
│  消息传递模型（Month 20 Actor、Month 21 Channel）            │
│                                                              │
│  Actor1 ──消息──→ [Mailbox] ──→ Actor2                       │
│                                                              │
│  特点：                                                      │
│  • 不共享状态，通过消息通信                                  │
│  • 隐式同步（消息队列处理）                                  │
│  • 更安全，更易理解                                          │
│  • 消息传递有开销                                            │
└─────────────────────────────────────────────────────────────┘

"Do not communicate by sharing memory;
 instead, share memory by communicating."
                    -- Go 语言格言
*/

// 共享内存方式实现的银行转账
class SharedMemoryBank {
    struct Account {
        std::mutex mutex;
        double balance;
    };

    std::unordered_map<int, Account> accounts_;
    std::shared_mutex accounts_mutex_;

public:
    bool transfer(int from, int to, double amount) {
        // 需要小心锁顺序，避免死锁
        int first = std::min(from, to);
        int second = std::max(from, to);

        std::shared_lock<std::shared_mutex> table_lock(accounts_mutex_);

        std::unique_lock<std::mutex> lock1(accounts_[first].mutex);
        std::unique_lock<std::mutex> lock2(accounts_[second].mutex);

        if (accounts_[from].balance >= amount) {
            accounts_[from].balance -= amount;
            accounts_[to].balance += amount;
            return true;
        }
        return false;
    }
};

// 消息传递方式实现的银行转账
namespace MessagePassing {

// 消息类型
struct TransferRequest {
    int from;
    int to;
    double amount;
    std::promise<bool> result;
};

struct BalanceQuery {
    int account_id;
    std::promise<double> result;
};

using BankMessage = std::variant<TransferRequest, BalanceQuery>;

// 银行Actor
class BankActor {
    std::unordered_map<int, double> accounts_;
    std::queue<BankMessage> mailbox_;
    std::mutex mailbox_mutex_;
    std::condition_variable mailbox_cv_;
    std::atomic<bool> running_{true};

public:
    void run() {
        while (running_) {
            std::unique_lock<std::mutex> lock(mailbox_mutex_);
            mailbox_cv_.wait(lock, [this] {
                return !mailbox_.empty() || !running_;
            });

            if (!running_ && mailbox_.empty()) break;

            auto msg = std::move(mailbox_.front());
            mailbox_.pop();
            lock.unlock();

            // 处理消息（单线程，无需同步！）
            std::visit([this](auto&& m) {
                handle_message(std::forward<decltype(m)>(m));
            }, msg);
        }
    }

    void send(BankMessage msg) {
        {
            std::lock_guard<std::mutex> lock(mailbox_mutex_);
            mailbox_.push(std::move(msg));
        }
        mailbox_cv_.notify_one();
    }

    void stop() {
        running_ = false;
        mailbox_cv_.notify_one();
    }

private:
    void handle_message(TransferRequest& req) {
        // 单线程处理，无需锁！
        bool success = false;
        if (accounts_[req.from] >= req.amount) {
            accounts_[req.from] -= req.amount;
            accounts_[req.to] += req.amount;
            success = true;
        }
        req.result.set_value(success);
    }

    void handle_message(BalanceQuery& query) {
        query.result.set_value(accounts_[query.account_id]);
    }
};

} // namespace MessagePassing

/*
对比分析：

┌────────────────┬────────────────────┬────────────────────┐
│  维度          │  共享内存          │  消息传递          │
├────────────────┼────────────────────┼────────────────────┤
│  安全性        │  较低（需手动同步）│  较高（自动隔离）  │
│  性能          │  潜在更高          │  有消息传递开销    │
│  可理解性      │  复杂              │  简单              │
│  调试          │  困难              │  相对容易          │
│  扩展性        │  受限              │  天然支持分布式    │
│  适用场景      │  低延迟、高性能    │  安全性优先        │
└────────────────┴────────────────────┴────────────────────┘
*/
```

#### 2. 锁 vs 无锁 vs Actor

```cpp
// ============================================================
// 同步方案对比：锁 vs 无锁 vs Actor
// ============================================================

/*
三种同步方案的哲学：

锁（Mutex）：
"我先用，你等着"
• 悲观并发控制
• 简单直观
• 可能死锁、优先级反转

无锁（Lock-free）：
"大家都试，失败重来"
• 乐观并发控制
• 高性能
• 实现复杂

Actor：
"各干各的，有事说话"
• 消息驱动
• 天然隔离
• 消息传递开销
*/

// 计数器的三种实现

// 1. 锁实现
class LockCounter {
    std::mutex mutex_;
    int count_ = 0;

public:
    void increment() {
        std::lock_guard<std::mutex> lock(mutex_);
        ++count_;
    }

    int get() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return count_;
    }
};

// 2. 无锁实现
class LockFreeCounter {
    std::atomic<int> count_{0};

public:
    void increment() {
        count_.fetch_add(1, std::memory_order_relaxed);
    }

    int get() const {
        return count_.load(std::memory_order_relaxed);
    }
};

// 3. Actor实现（简化）
class ActorCounter {
    struct Increment {};
    struct GetValue { std::promise<int> result; };

    using Message = std::variant<Increment, GetValue>;

    int count_ = 0;
    std::queue<Message> mailbox_;
    std::mutex mutex_;
    std::condition_variable cv_;
    std::atomic<bool> running_{true};

public:
    void run() {
        while (running_) {
            std::unique_lock<std::mutex> lock(mutex_);
            cv_.wait(lock, [this] { return !mailbox_.empty() || !running_; });

            while (!mailbox_.empty()) {
                auto msg = std::move(mailbox_.front());
                mailbox_.pop();
                lock.unlock();

                std::visit([this](auto&& m) {
                    if constexpr (std::is_same_v<std::decay_t<decltype(m)>, Increment>) {
                        ++count_;  // 单线程，无需同步
                    } else {
                        m.result.set_value(count_);
                    }
                }, msg);

                lock.lock();
            }
        }
    }

    void increment() {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            mailbox_.push(Increment{});
        }
        cv_.notify_one();
    }

    std::future<int> get() {
        GetValue msg;
        auto future = msg.result.get_future();
        {
            std::lock_guard<std::mutex> lock(mutex_);
            mailbox_.push(std::move(msg));
        }
        cv_.notify_one();
        return future;
    }
};

/*
性能对比（10M次increment，8线程）：

┌──────────────────┬────────────┬────────────────┐
│  方案            │  时间(ms)  │  吞吐量(Mops/s)│
├──────────────────┼────────────┼────────────────┤
│  LockCounter     │    850     │     11.8       │
│  LockFreeCounter │     45     │    222.2       │
│  ActorCounter    │   1200     │      8.3       │
└──────────────────┴────────────┴────────────────┘

结论：
• 简单计数器：无锁最优（约20倍于锁）
• Actor开销最大（消息传递）
• 但Actor在复杂场景下更安全、更易维护
*/
```

#### 3. 线程 vs 协程 vs Future

```cpp
// ============================================================
// 执行模型对比：线程 vs 协程 vs Future
// ============================================================

/*
三种执行模型：

线程（Thread）：
• OS调度，真正并行
• 创建开销大（栈、上下文）
• 适合CPU密集型

协程（Coroutine）：
• 用户态调度，协作式
• 轻量级（几KB）
• 适合I/O密集型

Future/Promise：
• 异步结果的抽象
• 可与线程池结合
• 适合组合异步操作
*/

#include <future>
#include <coroutine>

// 假设的协程Task类型（Month 21）
template<typename T>
struct Task;

// 场景：并发获取多个URL的内容

// 1. 线程方式
std::vector<std::string> fetch_with_threads(
    const std::vector<std::string>& urls
) {
    std::vector<std::thread> threads;
    std::vector<std::string> results(urls.size());
    std::mutex mutex;

    for (size_t i = 0; i < urls.size(); ++i) {
        threads.emplace_back([&, i]() {
            // std::string content = http_get(urls[i]);  // 假设的HTTP请求
            std::string content = "content_" + std::to_string(i);
            std::lock_guard<std::mutex> lock(mutex);
            results[i] = content;
        });
    }

    for (auto& t : threads) t.join();
    return results;
}

// 2. Future方式
std::vector<std::string> fetch_with_futures(
    const std::vector<std::string>& urls
) {
    std::vector<std::future<std::string>> futures;

    for (const auto& url : urls) {
        futures.push_back(std::async(std::launch::async, [&url]() {
            // return http_get(url);
            return "content_from_" + url;
        }));
    }

    std::vector<std::string> results;
    for (auto& f : futures) {
        results.push_back(f.get());
    }
    return results;
}

// 3. 协程方式（概念性代码）
/*
Task<std::vector<std::string>> fetch_with_coroutines(
    const std::vector<std::string>& urls
) {
    std::vector<Task<std::string>> tasks;

    for (const auto& url : urls) {
        tasks.push_back(async_http_get(url));
    }

    std::vector<std::string> results;
    for (auto& task : tasks) {
        results.push_back(co_await task);
    }
    co_return results;
}
*/

/*
执行模型对比：

┌────────────────┬────────────────────┬────────────────────┬────────────────────┐
│  特性          │  线程              │  协程              │  Future            │
├────────────────┼────────────────────┼────────────────────┼────────────────────┤
│  调度          │  OS抢占式          │  用户协作式        │  取决于执行器      │
│  创建开销      │  高（~1MB栈）      │  低（~几KB）       │  低               │
│  上下文切换    │  高（系统调用）    │  低（用户态）      │  N/A              │
│  并行度        │  真正并行          │  通常单线程        │  取决于执行器      │
│  适合场景      │  CPU密集          │  I/O密集          │  异步组合          │
│  编程复杂度    │  中                │  低                │  低                │
│  调试难度      │  高                │  中                │  中                │
├────────────────┼────────────────────┼────────────────────┼────────────────────┤
│  1000个并发任务│  占用1GB内存      │  占用几MB          │  取决于线程池大小  │
│  I/O等待      │  线程阻塞浪费      │  协程挂起高效      │  异步非阻塞        │
└────────────────┴────────────────────┴────────────────────┴────────────────────┘
*/
```

### Day 19-20：决策指南制定

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | 场景分类 | 2h |
| 下午 | 选择流程图 | 3h |
| 晚上 | 反模式总结 | 2h |

#### 1. 场景分类与分析

```cpp
// ============================================================
// 并发场景分类
// ============================================================

/*
场景分类矩阵：

┌──────────────────────────────────────────────────────────────────────────┐
│                         并发场景分类                                      │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  按任务性质：                                                            │
│  ┌────────────────┬────────────────┬────────────────┐                   │
│  │  CPU密集型     │  I/O密集型     │  混合型        │                   │
│  │  计算、压缩    │  网络、磁盘    │  Web服务器     │                   │
│  │  →线程池      │  →协程/异步   │  →混合方案    │                   │
│  └────────────────┴────────────────┴────────────────┘                   │
│                                                                          │
│  按并发度：                                                              │
│  ┌────────────────┬────────────────┬────────────────┐                   │
│  │  低（<10）     │  中（10-1000）  │  高（>1000）   │                   │
│  │  →简单锁     │  →线程池      │  →协程/Actor │                   │
│  └────────────────┴────────────────┴────────────────┘                   │
│                                                                          │
│  按数据共享：                                                            │
│  ┌────────────────┬────────────────┬────────────────┐                   │
│  │  无共享        │  少量共享      │  大量共享      │                   │
│  │  →Actor/协程 │  →分段锁      │  →谨慎设计    │                   │
│  └────────────────┴────────────────┴────────────────┘                   │
│                                                                          │
│  按延迟要求：                                                            │
│  ┌────────────────┬────────────────┬────────────────┐                   │
│  │  低延迟(<1ms)  │  中等延迟      │  高延迟容忍    │                   │
│  │  →无锁/轮询  │  →锁/线程池   │  →消息队列    │                   │
│  └────────────────┴────────────────┴────────────────┘                   │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
*/

// 场景枚举
enum class WorkloadType {
    CPUIntensive,
    IOIntensive,
    Mixed
};

enum class ConcurrencyLevel {
    Low,      // < 10
    Medium,   // 10 - 1000
    High      // > 1000
};

enum class DataSharing {
    None,
    Minimal,
    Heavy
};

enum class LatencyRequirement {
    UltraLow,  // < 1ms
    Normal,    // 1ms - 100ms
    Tolerant   // > 100ms
};

// 场景描述
struct ScenarioProfile {
    WorkloadType workload;
    ConcurrencyLevel concurrency;
    DataSharing sharing;
    LatencyRequirement latency;
};

// 推荐方案
struct Recommendation {
    std::string execution_model;  // 线程/协程/Actor
    std::string sync_mechanism;   // 锁/无锁/消息传递
    std::string data_structure;   // 队列/HashMap等
    std::string notes;
};

// 决策引擎
class ConcurrencyAdvisor {
public:
    static Recommendation recommend(const ScenarioProfile& profile) {
        Recommendation rec;

        // 执行模型选择
        if (profile.workload == WorkloadType::CPUIntensive) {
            rec.execution_model = "线程池 (线程数=CPU核数)";
        } else if (profile.workload == WorkloadType::IOIntensive) {
            rec.execution_model = profile.concurrency == ConcurrencyLevel::High
                ? "协程 + EventLoop"
                : "Future + 线程池";
        } else {
            rec.execution_model = "混合：计算用线程池，I/O用协程";
        }

        // 同步机制选择
        if (profile.sharing == DataSharing::None) {
            rec.sync_mechanism = "Actor模式 / Channel";
        } else if (profile.latency == LatencyRequirement::UltraLow) {
            rec.sync_mechanism = "无锁数据结构";
        } else if (profile.sharing == DataSharing::Heavy) {
            rec.sync_mechanism = "分段锁 + 读写锁";
        } else {
            rec.sync_mechanism = "标准互斥锁";
        }

        // 数据结构选择
        if (profile.latency == LatencyRequirement::UltraLow) {
            rec.data_structure = "无锁队列 (SPSC/MPSC)";
        } else if (profile.concurrency == ConcurrencyLevel::High) {
            rec.data_structure = "分段HashMap";
        } else {
            rec.data_structure = "标准容器 + 锁";
        }

        return rec;
    }
};
```

#### 2. 决策流程图

```
// ============================================================
// 并发方案选择流程图
// ============================================================

/*
                    ┌─────────────────────┐
                    │  开始分析场景        │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │  任务性质是什么？    │
                    └──────────┬──────────┘
                               │
          ┌────────────────────┼────────────────────┐
          │                    │                    │
    ┌─────▼─────┐        ┌─────▼─────┐        ┌─────▼─────┐
    │ CPU密集   │        │ I/O密集   │        │  混合     │
    └─────┬─────┘        └─────┬─────┘        └─────┬─────┘
          │                    │                    │
    ┌─────▼─────┐        ┌─────▼─────┐        ┌─────▼─────┐
    │ 线程池    │        │并发数>1K? │        │ 分离计算  │
    │ 线程=核数 │        └─────┬─────┘        │ 和I/O     │
    └─────┬─────┘              │              └─────┬─────┘
          │           ┌────────┴────────┐          │
          │           │是              │否         │
          │     ┌─────▼─────┐    ┌─────▼─────┐    │
          │     │协程+事件循│    │Future     │    │
          │     │环(Month22)│    │+线程池    │    │
          │     └───────────┘    └───────────┘    │
          │                                       │
          └───────────────────┬───────────────────┘
                              │
                    ┌─────────▼─────────┐
                    │  有共享状态吗？    │
                    └─────────┬─────────┘
                              │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
    ┌─────▼─────┐       ┌─────▼─────┐       ┌─────▼─────┐
    │   无      │       │  少量     │       │  大量     │
    └─────┬─────┘       └─────┬─────┘       └─────┬─────┘
          │                   │                   │
    ┌─────▼─────┐       ┌─────▼─────┐       ┌─────▼─────┐
    │Actor/     │       │延迟要求?  │       │重新设计   │
    │Channel    │       └─────┬─────┘       │减少共享   │
    └───────────┘             │             └───────────┘
                              │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
    ┌─────▼─────┐       ┌─────▼─────┐       ┌─────▼─────┐
    │ 超低<1ms  │       │ 正常      │       │ 不敏感    │
    └─────┬─────┘       └─────┬─────┘       └─────┬─────┘
          │                   │                   │
    ┌─────▼─────┐       ┌─────▼─────┐       ┌─────▼─────┐
    │无锁结构   │       │分段锁     │       │简单锁     │
    │原子操作   │       │读写锁     │       │或Actor    │
    └───────────┘       └───────────┘       └───────────┘
*/

// ASCII流程图的代码表示
enum class Decision {
    ThreadPool,
    CoroutineEventLoop,
    FutureThreadPool,
    HybridModel,
    Actor,
    Channel,
    LockFree,
    StripedLock,
    SimpleLock,
    Redesign
};

Decision select_concurrency_model(const ScenarioProfile& profile) {
    // CPU密集型
    if (profile.workload == WorkloadType::CPUIntensive) {
        if (profile.sharing == DataSharing::None) {
            return Decision::Actor;
        } else if (profile.latency == LatencyRequirement::UltraLow) {
            return Decision::LockFree;
        } else {
            return Decision::ThreadPool;
        }
    }

    // I/O密集型
    if (profile.workload == WorkloadType::IOIntensive) {
        if (profile.concurrency == ConcurrencyLevel::High) {
            return Decision::CoroutineEventLoop;
        } else {
            return Decision::FutureThreadPool;
        }
    }

    // 混合型
    if (profile.sharing == DataSharing::None) {
        return Decision::Actor;
    } else if (profile.sharing == DataSharing::Heavy) {
        return Decision::Redesign;
    } else {
        return profile.latency == LatencyRequirement::UltraLow
            ? Decision::LockFree
            : Decision::StripedLock;
    }
}
```

#### 3. 常见反模式

```cpp
// ============================================================
// 并发编程常见反模式
// ============================================================

/*
反模式1：过度同步（Over-Synchronization）

症状：到处都是锁，性能极差
原因：不理解什么需要同步
解决：分析真正的共享状态，最小化同步范围
*/

// 错误示例
class OverSyncCounter {
    std::mutex mutex_;
    int count_ = 0;
    int last_accessed_ = 0;

public:
    void increment() {
        std::lock_guard<std::mutex> lock(mutex_);
        ++count_;
        last_accessed_ = time(nullptr);  // 不需要原子性
    }

    // 更糟：返回时还持有锁
    int get_count() {
        std::lock_guard<std::mutex> lock(mutex_);
        last_accessed_ = time(nullptr);
        return count_;  // 返回后锁才释放
    }
};

// 正确示例
class ProperCounter {
    std::atomic<int> count_{0};
    std::atomic<int> last_accessed_{0};  // 分开处理

public:
    void increment() {
        count_.fetch_add(1, std::memory_order_relaxed);
        last_accessed_.store(time(nullptr), std::memory_order_relaxed);
    }

    int get_count() const {
        last_accessed_.store(time(nullptr), std::memory_order_relaxed);
        return count_.load(std::memory_order_relaxed);
    }
};

/*
反模式2：锁粒度不当（Wrong Lock Granularity）

过粗：一把大锁保护所有数据
过细：每个字段一把锁，死锁风险高
*/

// 过粗粒度
class CoarseGrained {
    std::mutex global_mutex_;
    std::map<int, std::string> users_;
    std::map<int, std::string> orders_;
    std::map<int, std::string> products_;

public:
    void add_user(int id, std::string name) {
        std::lock_guard<std::mutex> lock(global_mutex_);  // 锁住所有！
        users_[id] = name;
    }

    void add_order(int id, std::string order) {
        std::lock_guard<std::mutex> lock(global_mutex_);  // 不相关的操作也等待
        orders_[id] = order;
    }
};

// 适当粒度
class ProperGrained {
    std::mutex users_mutex_;
    std::mutex orders_mutex_;
    std::mutex products_mutex_;
    std::map<int, std::string> users_;
    std::map<int, std::string> orders_;
    std::map<int, std::string> products_;

public:
    void add_user(int id, std::string name) {
        std::lock_guard<std::mutex> lock(users_mutex_);
        users_[id] = name;
    }

    void add_order(int id, std::string order) {
        std::lock_guard<std::mutex> lock(orders_mutex_);
        orders_[id] = order;
    }
};

/*
反模式3：忙等待（Busy Waiting）

症状：CPU占用高，但实际工作少
原因：用while循环代替条件变量
*/

// 错误：忙等待
class BusyWaitQueue {
    std::queue<int> queue_;
    std::mutex mutex_;

public:
    void push(int value) {
        std::lock_guard<std::mutex> lock(mutex_);
        queue_.push(value);
    }

    int pop() {
        while (true) {
            std::lock_guard<std::mutex> lock(mutex_);
            if (!queue_.empty()) {
                int value = queue_.front();
                queue_.pop();
                return value;
            }
            // 没有数据就一直循环！CPU空转
        }
    }
};

// 正确：使用条件变量
class ProperQueue {
    std::queue<int> queue_;
    std::mutex mutex_;
    std::condition_variable cv_;

public:
    void push(int value) {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            queue_.push(value);
        }
        cv_.notify_one();
    }

    int pop() {
        std::unique_lock<std::mutex> lock(mutex_);
        cv_.wait(lock, [this] { return !queue_.empty(); });  // 阻塞等待
        int value = queue_.front();
        queue_.pop();
        return value;
    }
};

/*
反模式4：隐藏的共享状态

症状：看起来没问题，实际有竞态
原因：全局变量、静态变量、单例
*/

// 隐藏的共享
class HiddenSharing {
    static int global_counter;  // 静态变量！

public:
    void process() {
        ++global_counter;  // 多线程不安全！
    }
};

// 更隐蔽的例子
class SubtleSharing {
public:
    std::string format(int value) {
        static char buffer[100];  // 静态缓冲区！
        snprintf(buffer, sizeof(buffer), "%d", value);
        return buffer;  // 多线程会覆盖
    }
};

/*
反模式5：持锁调用未知代码

症状：潜在死锁，难以调试
原因：持有锁时调用回调、虚函数
*/

class DangerousCallback {
    std::mutex mutex_;
    std::function<void()> callback_;

public:
    void set_callback(std::function<void()> cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        callback_ = cb;
    }

    void trigger() {
        std::lock_guard<std::mutex> lock(mutex_);
        if (callback_) {
            callback_();  // 危险！回调可能获取同一把锁
        }
    }
};

// 安全版本
class SafeCallback {
    std::mutex mutex_;
    std::function<void()> callback_;

public:
    void set_callback(std::function<void()> cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        callback_ = cb;
    }

    void trigger() {
        std::function<void()> cb;
        {
            std::lock_guard<std::mutex> lock(mutex_);
            cb = callback_;
        }
        // 锁外调用！
        if (cb) {
            cb();
        }
    }
};

/*
反模式总结：

┌──────────────────┬────────────────────┬────────────────────┐
│  反模式          │  症状              │  解决方案          │
├──────────────────┼────────────────────┼────────────────────┤
│  过度同步        │  性能差            │  最小化同步范围    │
│  粒度不当        │  低并发或死锁      │  按数据分离设计锁  │
│  忙等待          │  CPU空转           │  条件变量          │
│  隐藏共享        │  竞态条件          │  消除全局状态      │
│  持锁调外部代码  │  死锁              │  先复制再调用      │
│  双检查锁        │  数据竞争          │  call_once或atomic │
└──────────────────┴────────────────────┴────────────────────┘
*/
```

### Day 21：第三周总结与检验

#### 综合决策表

```cpp
// ============================================================
// Month 13-23 并发模式综合对比
// ============================================================

/*
┌────────────────────────────────────────────────────────────────────────────────────┐
│                        并发模式综合选择指南                                          │
├────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                    │
│  执行模型选择：                                                                    │
│  ┌──────────────┬─────────────────┬─────────────────┬─────────────────┐           │
│  │  场景        │  首选           │  备选           │  学习月份       │           │
│  ├──────────────┼─────────────────┼─────────────────┼─────────────────┤           │
│  │  CPU密集     │  线程池         │  Fork-Join      │  Month 19       │           │
│  │  I/O密集低并 │  Future         │  线程池         │  Month 18       │           │
│  │  I/O密集高并 │  协程EventLoop  │  Actor          │  Month 21-22    │           │
│  │  分布式      │  Actor          │  消息队列       │  Month 20       │           │
│  └──────────────┴─────────────────┴─────────────────┴─────────────────┘           │
│                                                                                    │
│  同步机制选择：                                                                    │
│  ┌──────────────┬─────────────────┬─────────────────┬─────────────────┐           │
│  │  场景        │  首选           │  备选           │  学习月份       │           │
│  ├──────────────┼─────────────────┼─────────────────┼─────────────────┤           │
│  │  简单共享    │  mutex          │  atomic         │  Month 13       │           │
│  │  读多写少    │  shared_mutex   │  RCU            │  Month 16, 23   │           │
│  │  高竞争      │  分段锁         │  无锁           │  Month 15-17    │           │
│  │  超低延迟    │  无锁CAS        │  SPSC队列       │  Month 15-17    │           │
│  │  无共享      │  Actor/Channel  │  -              │  Month 20-21    │           │
│  └──────────────┴─────────────────┴─────────────────┴─────────────────┘           │
│                                                                                    │
│  数据结构选择：                                                                    │
│  ┌──────────────┬─────────────────┬─────────────────┬─────────────────┐           │
│  │  场景        │  首选           │  备选           │  学习月份       │           │
│  ├──────────────┼─────────────────┼─────────────────┼─────────────────┤           │
│  │  任务队列    │  阻塞队列       │  无锁队列       │  Month 17, 19   │           │
│  │  单生产单消  │  SPSC队列       │  双缓冲         │  Month 17, 23   │           │
│  │  多生产单消  │  MPSC队列       │  Actor Mailbox  │  Month 17, 20   │           │
│  │  多生产多消  │  分段队列       │  Work Stealing  │  Month 17, 19   │           │
│  │  KV缓存      │  分段HashMap    │  concurrent_map │  Month 23       │           │
│  │  配置/元数据 │  RCU            │  双缓冲         │  Month 16, 23   │           │
│  └──────────────┴─────────────────┴─────────────────┴─────────────────┘           │
│                                                                                    │
│  内存回收选择（无锁场景）：                                                        │
│  ┌──────────────┬─────────────────┬─────────────────┬─────────────────┐           │
│  │  场景        │  首选           │  备选           │  学习月份       │           │
│  ├──────────────┼─────────────────┼─────────────────┼─────────────────┤           │
│  │  读多写少    │  RCU            │  Epoch-based    │  Month 16       │           │
│  │  写较多      │  Hazard Pointer │  QSBR           │  Month 16       │           │
│  │  简单场景    │  Epoch-based    │  引用计数       │  Month 16       │           │
│  └──────────────┴─────────────────┴─────────────────┴─────────────────┘           │
│                                                                                    │
└────────────────────────────────────────────────────────────────────────────────────┘
*/
```

#### 第三周检验标准

- [ ] 理解双缓冲技术的原理和应用场景
- [ ] 能实现原子交换双缓冲
- [ ] 能对比共享内存和消息传递的优劣
- [ ] 能对比锁、无锁、Actor三种同步方案
- [ ] 能对比线程、协程、Future三种执行模型
- [ ] 理解各种场景的分类标准
- [ ] 能根据场景选择合适的并发方案
- [ ] 能识别常见的并发反模式
- [ ] 能整合Month 13-22的知识做出决策

---

## 第四周：综合案例与实战总结（Day 22-28）

> **本周目标**：通过实战案例整合知识，掌握调试和性能分析技术，为Month 24做准备

### Day 22-23：并发Bug分析与调试

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | 死锁诊断 | 2h |
| 下午 | 数据竞争检测 | 3h |
| 晚上 | ABA问题回顾 | 2h |

#### 1. 死锁问题诊断

```cpp
// ============================================================
// 死锁的四个必要条件与诊断
// ============================================================

/*
死锁四条件（Coffman条件）：

1. 互斥（Mutual Exclusion）
   资源一次只能被一个线程使用

2. 持有并等待（Hold and Wait）
   线程持有至少一个资源，同时等待其他资源

3. 非抢占（No Preemption）
   资源不能被强制释放

4. 循环等待（Circular Wait）
   存在线程间的循环等待链

打破任一条件即可避免死锁！
*/

#include <mutex>
#include <thread>
#include <iostream>

// 经典死锁示例
class DeadlockDemo {
    std::mutex mutex_a_;
    std::mutex mutex_b_;

public:
    void thread1() {
        std::lock_guard<std::mutex> lock_a(mutex_a_);
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
        std::lock_guard<std::mutex> lock_b(mutex_b_);  // 等待B
        std::cout << "Thread1 完成\n";
    }

    void thread2() {
        std::lock_guard<std::mutex> lock_b(mutex_b_);
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
        std::lock_guard<std::mutex> lock_a(mutex_a_);  // 等待A
        std::cout << "Thread2 完成\n";
    }

    // 这会死锁！
    void run_deadlock() {
        std::thread t1(&DeadlockDemo::thread1, this);
        std::thread t2(&DeadlockDemo::thread2, this);
        t1.join();
        t2.join();
    }
};

// 解决方案1：固定锁顺序
class FixedOrderSolution {
    std::mutex mutex_a_;
    std::mutex mutex_b_;

public:
    void thread1() {
        std::lock_guard<std::mutex> lock_a(mutex_a_);  // 总是先A
        std::lock_guard<std::mutex> lock_b(mutex_b_);  // 后B
        std::cout << "Thread1 完成\n";
    }

    void thread2() {
        std::lock_guard<std::mutex> lock_a(mutex_a_);  // 也是先A
        std::lock_guard<std::mutex> lock_b(mutex_b_);  // 后B
        std::cout << "Thread2 完成\n";
    }
};

// 解决方案2：std::lock同时获取多个锁
class StdLockSolution {
    std::mutex mutex_a_;
    std::mutex mutex_b_;

public:
    void thread1() {
        std::lock(mutex_a_, mutex_b_);  // 原子地获取两个锁
        std::lock_guard<std::mutex> lock_a(mutex_a_, std::adopt_lock);
        std::lock_guard<std::mutex> lock_b(mutex_b_, std::adopt_lock);
        std::cout << "Thread1 完成\n";
    }

    void thread2() {
        std::lock(mutex_a_, mutex_b_);  // 同样原子获取
        std::lock_guard<std::mutex> lock_a(mutex_a_, std::adopt_lock);
        std::lock_guard<std::mutex> lock_b(mutex_b_, std::adopt_lock);
        std::cout << "Thread2 完成\n";
    }
};

// C++17: std::scoped_lock
class ScopedLockSolution {
    std::mutex mutex_a_;
    std::mutex mutex_b_;

public:
    void thread1() {
        std::scoped_lock lock(mutex_a_, mutex_b_);  // C++17最简洁
        std::cout << "Thread1 完成\n";
    }

    void thread2() {
        std::scoped_lock lock(mutex_a_, mutex_b_);
        std::cout << "Thread2 完成\n";
    }
};

// 解决方案3：try_lock + 后退重试
class TryLockSolution {
    std::mutex mutex_a_;
    std::mutex mutex_b_;

public:
    void do_work() {
        while (true) {
            mutex_a_.lock();
            if (mutex_b_.try_lock()) {
                // 成功获取两个锁
                // ... 工作
                mutex_b_.unlock();
                mutex_a_.unlock();
                return;
            }
            // 未能获取B，释放A并重试
            mutex_a_.unlock();
            std::this_thread::yield();
        }
    }
};

// 死锁检测器（简化版）
class DeadlockDetector {
    struct LockInfo {
        std::thread::id holder;
        std::vector<void*> waiting_for;  // 等待的锁
    };

    std::mutex detector_mutex_;
    std::unordered_map<void*, LockInfo> lock_graph_;

public:
    void on_lock_acquired(void* lock_addr) {
        std::lock_guard<std::mutex> guard(detector_mutex_);
        lock_graph_[lock_addr].holder = std::this_thread::get_id();
    }

    void on_lock_released(void* lock_addr) {
        std::lock_guard<std::mutex> guard(detector_mutex_);
        lock_graph_.erase(lock_addr);
    }

    void on_lock_waiting(void* lock_addr) {
        std::lock_guard<std::mutex> guard(detector_mutex_);
        // 检测循环等待...
        // 实际实现需要DFS遍历锁图
    }

    bool detect_cycle() {
        // 遍历lock_graph_寻找环
        // 返回true如果发现死锁
        return false;
    }
};
```

#### 2. 数据竞争检测（ThreadSanitizer）

```cpp
// ============================================================
// ThreadSanitizer (TSan) 使用指南
// ============================================================

/*
编译命令：
g++ -fsanitize=thread -g -O1 program.cpp -o program
clang++ -fsanitize=thread -g -O1 program.cpp -o program

TSan 能检测的问题：
1. 数据竞争（Data Race）
2. 锁顺序违规
3. 死锁（部分）
4. 信号处理问题
*/

// 示例1：简单的数据竞争
class DataRaceExample {
    int counter_ = 0;  // 非原子变量

public:
    void increment() {
        ++counter_;  // 数据竞争！
    }

    int get() const {
        return counter_;  // 可能读到撕裂的值
    }
};

/*
TSan输出示例：

==================
WARNING: ThreadSanitizer: data race (pid=12345)
  Write of size 4 at 0x7f8abc by thread T1:
    #0 DataRaceExample::increment() example.cpp:5
    #1 thread_func() example.cpp:20

  Previous read of size 4 at 0x7f8abc by thread T2:
    #0 DataRaceExample::get() example.cpp:9
    #1 thread_func() example.cpp:25

  Location is heap block of size 8 at 0x7f8abc allocated by main thread
==================
*/

// 修复：使用原子变量
class FixedDataRace {
    std::atomic<int> counter_{0};

public:
    void increment() {
        counter_.fetch_add(1, std::memory_order_relaxed);
    }

    int get() const {
        return counter_.load(std::memory_order_relaxed);
    }
};

// 示例2：不正确的双检查锁
class BadDoubleCheckedLocking {
    std::mutex mutex_;
    bool initialized_ = false;  // 非原子！
    int* resource_ = nullptr;

public:
    int* get_resource() {
        if (!initialized_) {  // 竞争1：读initialized_
            std::lock_guard<std::mutex> lock(mutex_);
            if (!initialized_) {
                resource_ = new int(42);
                initialized_ = true;  // 竞争2：写initialized_
            }
        }
        return resource_;
    }
};

// 正确版本
class CorrectDoubleCheckedLocking {
    std::mutex mutex_;
    std::atomic<bool> initialized_{false};
    int* resource_ = nullptr;

public:
    int* get_resource() {
        if (!initialized_.load(std::memory_order_acquire)) {
            std::lock_guard<std::mutex> lock(mutex_);
            if (!initialized_.load(std::memory_order_relaxed)) {
                resource_ = new int(42);
                initialized_.store(true, std::memory_order_release);
            }
        }
        return resource_;
    }
};

// 更好：使用std::call_once
class BestInitialization {
    std::once_flag flag_;
    int* resource_ = nullptr;

public:
    int* get_resource() {
        std::call_once(flag_, [this]() {
            resource_ = new int(42);
        });
        return resource_;
    }
};

/*
TSan 使用建议：

1. 开发时常开：虽然有2-20倍的性能开销，但能早期发现问题
2. CI集成：在CI中运行TSan测试
3. 全量构建：需要整个程序都用TSan编译
4. 抑制规则：对于已知的良性竞争可以添加抑制

抑制文件示例 (tsan.supp)：
race:ThirdPartyLib::*
race:*known_benign_race*

运行：
TSAN_OPTIONS="suppressions=tsan.supp" ./program
*/
```

#### 3. ABA问题回顾（Month 16）

```cpp
// ============================================================
// ABA问题回顾与解决方案
// ============================================================

/*
ABA问题回顾：

CAS操作检查"值是否改变"，但无法检测"值改变后又变回来"

时间线：
T1: read A ──────────────────────→ CAS(A→A') 成功?!
T2:      └─→ A→B ─→ B→A ─┘

T1的CAS看到值仍是A，但实际数据已经被修改过！
*/

#include <atomic>

// ABA问题示例：无锁栈
template<typename T>
class ABAProblemStack {
    struct Node {
        T data;
        Node* next;
    };

    std::atomic<Node*> head_{nullptr};

public:
    void push(T value) {
        Node* new_node = new Node{value, nullptr};
        Node* old_head = head_.load();
        do {
            new_node->next = old_head;
        } while (!head_.compare_exchange_weak(old_head, new_node));
    }

    std::optional<T> pop() {
        Node* old_head = head_.load();
        Node* new_head;
        do {
            if (!old_head) return std::nullopt;
            new_head = old_head->next;
        } while (!head_.compare_exchange_weak(old_head, new_head));
        // 问题：old_head可能已被另一个线程释放并重用！
        T value = old_head->data;
        delete old_head;
        return value;
    }
};

/*
ABA解决方案回顾（Month 16详细学习）：

1. 带版本号的指针（Tagged Pointer）
2. Hazard Pointers
3. Epoch-based Reclamation
4. RCU（Read-Copy-Update）
*/

// 解决方案1：带版本号的指针
template<typename T>
class TaggedPointerStack {
    struct Node {
        T data;
        Node* next;
    };

    struct TaggedPtr {
        Node* ptr;
        uint64_t tag;  // 版本号

        bool operator==(const TaggedPtr& other) const {
            return ptr == other.ptr && tag == other.tag;
        }
    };

    std::atomic<TaggedPtr> head_{{nullptr, 0}};

public:
    void push(T value) {
        Node* new_node = new Node{value, nullptr};
        TaggedPtr old_head = head_.load();
        TaggedPtr new_head;
        do {
            new_node->next = old_head.ptr;
            new_head = {new_node, old_head.tag + 1};
        } while (!head_.compare_exchange_weak(old_head, new_head));
    }

    std::optional<T> pop() {
        TaggedPtr old_head = head_.load();
        TaggedPtr new_head;
        do {
            if (!old_head.ptr) return std::nullopt;
            new_head = {old_head.ptr->next, old_head.tag + 1};
        } while (!head_.compare_exchange_weak(old_head, new_head));
        // 即使指针值相同，版本号也不同，CAS会失败
        T value = old_head.ptr->data;
        delete old_head.ptr;  // 仍需要安全回收！
        return value;
    }
};

// 注意：完整的ABA解决方案需要Month 16的内存回收技术
```

### Day 24-25：性能分析与优化

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | Profiling工具使用 | 2h |
| 下午 | 锁竞争分析 | 3h |
| 晚上 | 优化实践 | 2h |

#### 1. 性能分析工具

```cpp
// ============================================================
// 并发性能分析工具使用指南
// ============================================================

/*
常用工具：

1. perf (Linux)
   系统级性能分析，可以看CPU使用、缓存命中等

   perf stat ./program          # 基本统计
   perf record ./program        # 记录profile
   perf report                  # 查看报告
   perf top                     # 实时查看热点

2. Valgrind + Helgrind
   检测线程错误

   valgrind --tool=helgrind ./program

3. Intel VTune
   商业工具，功能强大

4. gperftools
   Google的性能分析工具

5. 自定义计时
*/

#include <chrono>
#include <string>
#include <unordered_map>

// 简单的性能计时器
class ScopedTimer {
    std::string name_;
    std::chrono::high_resolution_clock::time_point start_;

public:
    explicit ScopedTimer(std::string name)
        : name_(std::move(name))
        , start_(std::chrono::high_resolution_clock::now())
    {}

    ~ScopedTimer() {
        auto end = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::microseconds>(
            end - start_).count();
        std::cout << name_ << ": " << duration << " us\n";
    }
};

// 统计收集器
class PerfStats {
    struct Stats {
        uint64_t count = 0;
        uint64_t total_ns = 0;
        uint64_t min_ns = UINT64_MAX;
        uint64_t max_ns = 0;
    };

    std::mutex mutex_;
    std::unordered_map<std::string, Stats> stats_;

public:
    static PerfStats& instance() {
        static PerfStats instance;
        return instance;
    }

    void record(const std::string& name, uint64_t duration_ns) {
        std::lock_guard<std::mutex> lock(mutex_);
        auto& s = stats_[name];
        ++s.count;
        s.total_ns += duration_ns;
        s.min_ns = std::min(s.min_ns, duration_ns);
        s.max_ns = std::max(s.max_ns, duration_ns);
    }

    void print_report() {
        std::lock_guard<std::mutex> lock(mutex_);
        std::cout << "\n=== 性能报告 ===\n\n";
        std::cout << std::setw(20) << "操作"
                  << std::setw(10) << "次数"
                  << std::setw(12) << "平均(ns)"
                  << std::setw(12) << "最小(ns)"
                  << std::setw(12) << "最大(ns)"
                  << "\n";
        std::cout << std::string(66, '-') << "\n";

        for (const auto& [name, s] : stats_) {
            std::cout << std::setw(20) << name
                      << std::setw(10) << s.count
                      << std::setw(12) << (s.count ? s.total_ns / s.count : 0)
                      << std::setw(12) << (s.count ? s.min_ns : 0)
                      << std::setw(12) << s.max_ns
                      << "\n";
        }
    }
};

// RAII计时器，自动记录统计
class AutoTimer {
    std::string name_;
    std::chrono::high_resolution_clock::time_point start_;

public:
    explicit AutoTimer(std::string name)
        : name_(std::move(name))
        , start_(std::chrono::high_resolution_clock::now())
    {}

    ~AutoTimer() {
        auto end = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::nanoseconds>(
            end - start_).count();
        PerfStats::instance().record(name_, duration);
    }
};

// 使用示例
/*
void some_function() {
    AutoTimer timer("some_function");
    // ... 工作
}

int main() {
    for (int i = 0; i < 10000; ++i) {
        some_function();
    }
    PerfStats::instance().print_report();
}
*/
```

#### 2. 锁竞争分析

```cpp
// ============================================================
// 锁竞争分析与优化
// ============================================================

/*
锁竞争的指标：

1. 锁获取次数
2. 锁等待时间
3. 锁持有时间
4. 竞争率（等待次数/获取次数）

分析方法：
• 使用带统计的锁包装
• 使用perf lock分析
• Intel VTune的锁分析
*/

// 带统计的互斥锁
class InstrumentedMutex {
    std::mutex mutex_;

    // 统计数据（使用原子变量避免额外同步）
    std::atomic<uint64_t> lock_count_{0};
    std::atomic<uint64_t> contention_count_{0};  // 竞争次数
    std::atomic<uint64_t> total_wait_ns_{0};
    std::atomic<uint64_t> total_hold_ns_{0};

    // 每线程的持有开始时间
    thread_local static std::chrono::high_resolution_clock::time_point hold_start_;

public:
    void lock() {
        auto start = std::chrono::high_resolution_clock::now();

        // 先尝试非阻塞获取
        if (!mutex_.try_lock()) {
            ++contention_count_;
            mutex_.lock();  // 阻塞等待
        }

        auto end = std::chrono::high_resolution_clock::now();
        ++lock_count_;
        total_wait_ns_ += std::chrono::duration_cast<std::chrono::nanoseconds>(
            end - start).count();

        hold_start_ = end;
    }

    void unlock() {
        auto hold_duration = std::chrono::high_resolution_clock::now() - hold_start_;
        total_hold_ns_ += std::chrono::duration_cast<std::chrono::nanoseconds>(
            hold_duration).count();
        mutex_.unlock();
    }

    bool try_lock() {
        if (mutex_.try_lock()) {
            ++lock_count_;
            hold_start_ = std::chrono::high_resolution_clock::now();
            return true;
        }
        return false;
    }

    struct Stats {
        uint64_t lock_count;
        uint64_t contention_count;
        double avg_wait_ns;
        double avg_hold_ns;
        double contention_rate;
    };

    Stats get_stats() const {
        Stats s;
        s.lock_count = lock_count_.load();
        s.contention_count = contention_count_.load();
        s.avg_wait_ns = s.lock_count > 0 ?
            static_cast<double>(total_wait_ns_) / s.lock_count : 0;
        s.avg_hold_ns = s.lock_count > 0 ?
            static_cast<double>(total_hold_ns_) / s.lock_count : 0;
        s.contention_rate = s.lock_count > 0 ?
            static_cast<double>(s.contention_count) / s.lock_count : 0;
        return s;
    }

    void print_stats(const std::string& name) const {
        auto s = get_stats();
        std::cout << "=== 锁统计: " << name << " ===\n"
                  << "获取次数: " << s.lock_count << "\n"
                  << "竞争次数: " << s.contention_count << "\n"
                  << "竞争率: " << std::fixed << std::setprecision(2)
                  << (s.contention_rate * 100) << "%\n"
                  << "平均等待: " << std::fixed << std::setprecision(0)
                  << s.avg_wait_ns << " ns\n"
                  << "平均持有: " << s.avg_hold_ns << " ns\n";
    }
};

thread_local std::chrono::high_resolution_clock::time_point
    InstrumentedMutex::hold_start_;

/*
优化策略（基于分析结果）：

1. 竞争率高 + 持有时间短 → 考虑自旋锁
2. 竞争率高 + 持有时间长 → 减少锁范围或使用分段锁
3. 竞争率低 → 当前方案可能已足够
4. 等待时间长 → 考虑读写锁（如果读多写少）
*/
```

#### 3. 缓存性能分析

```cpp
// ============================================================
// 缓存性能分析与优化
// ============================================================

/*
使用perf分析缓存性能：

perf stat -e cache-references,cache-misses,
          L1-dcache-loads,L1-dcache-load-misses,
          LLC-loads,LLC-load-misses ./program

关键指标：
• L1缓存命中率：应 > 95%
• LLC命中率：应 > 90%
• 缓存行伪共享：不同线程频繁写同一缓存行
*/

// 缓存友好的数据结构设计
template<typename T, size_t N>
class CacheFriendlyArray {
    // 确保数组元素缓存行对齐
    struct alignas(64) AlignedElement {
        T value;
        char padding[64 - sizeof(T) % 64];
    };

    std::array<AlignedElement, N> data_;

public:
    T& operator[](size_t index) {
        return data_[index].value;
    }

    const T& operator[](size_t index) const {
        return data_[index].value;
    }
};

// 缓存行预取优化
class PrefetchOptimization {
public:
    // 顺序访问优化
    static void process_array(int* data, size_t size) {
        for (size_t i = 0; i < size; ++i) {
            // 预取后面的数据
            if (i + 16 < size) {
                __builtin_prefetch(&data[i + 16], 0, 3);
            }
            // 处理当前数据
            data[i] *= 2;
        }
    }

    // 结构体数组 vs 数组结构体
    // 结构体数组（AoS）：缓存不友好
    struct AoS {
        float x, y, z;
        float vx, vy, vz;
    };

    // 数组结构体（SoA）：缓存友好
    struct SoA {
        std::vector<float> x, y, z;
        std::vector<float> vx, vy, vz;
    };

    // SoA访问模式更连续，缓存效率更高
    static void update_positions_soa(SoA& data, float dt) {
        size_t n = data.x.size();
        for (size_t i = 0; i < n; ++i) {
            data.x[i] += data.vx[i] * dt;
        }
        for (size_t i = 0; i < n; ++i) {
            data.y[i] += data.vy[i] * dt;
        }
        for (size_t i = 0; i < n; ++i) {
            data.z[i] += data.vz[i] * dt;
        }
    }
};
```

### Day 26-27：综合项目——高吞吐消息队列

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | 架构设计 | 2h |
| 下午 | 核心实现 | 4h |
| 晚上 | 性能测试 | 2h |

#### 高吞吐消息队列实现

```cpp
// ============================================================
// 综合项目：高吞吐消息队列
// ============================================================

/*
项目目标：整合Month 13-23学习的知识，构建高性能消息队列

设计要求：
1. 支持多生产者多消费者
2. 支持消息优先级
3. 支持背压
4. 支持优雅关闭
5. 提供性能统计

技术选型：
• 分段锁减少竞争
• 批量处理提高吞吐
• 条件变量避免忙等待
• 原子操作实现统计
*/

#include <queue>
#include <vector>
#include <mutex>
#include <condition_variable>
#include <atomic>
#include <optional>
#include <functional>
#include <chrono>

template<typename T>
class HighThroughputQueue {
public:
    // 配置
    struct Config {
        size_t capacity = 10000;          // 总容量
        size_t num_stripes = 16;          // 分段数
        size_t batch_size = 64;           // 批处理大小
        bool enable_priority = false;     // 启用优先级
        size_t num_priority_levels = 3;   // 优先级级别
    };

    // 统计
    struct Stats {
        std::atomic<uint64_t> total_enqueued{0};
        std::atomic<uint64_t> total_dequeued{0};
        std::atomic<uint64_t> total_dropped{0};
        std::atomic<uint64_t> wait_count{0};
        std::atomic<uint64_t> wait_time_ns{0};

        void print() const {
            std::cout << "\n=== 队列统计 ===\n"
                      << "入队总数: " << total_enqueued.load() << "\n"
                      << "出队总数: " << total_dequeued.load() << "\n"
                      << "丢弃数: " << total_dropped.load() << "\n"
                      << "等待次数: " << wait_count.load() << "\n"
                      << "平均等待: " << (wait_count > 0 ?
                         wait_time_ns.load() / wait_count.load() : 0)
                      << " ns\n";
        }
    };

private:
    // 单个分段
    struct Stripe {
        std::mutex mutex;
        std::condition_variable not_empty;
        std::condition_variable not_full;

        // 使用优先级队列或普通队列
        std::vector<std::queue<T>> priority_queues;  // 按优先级
        size_t count = 0;

        explicit Stripe(size_t num_priorities) : priority_queues(num_priorities) {}
    };

    Config config_;
    std::vector<std::unique_ptr<Stripe>> stripes_;
    std::atomic<bool> closed_{false};
    Stats stats_;

    // 分段策略：轮询
    std::atomic<size_t> enqueue_stripe_{0};
    std::atomic<size_t> dequeue_stripe_{0};

public:
    explicit HighThroughputQueue(Config config = {})
        : config_(std::move(config))
    {
        size_t num_priorities = config_.enable_priority ?
            config_.num_priority_levels : 1;

        for (size_t i = 0; i < config_.num_stripes; ++i) {
            stripes_.push_back(std::make_unique<Stripe>(num_priorities));
        }
    }

    // 入队（带优先级）
    bool enqueue(T item, size_t priority = 0) {
        if (closed_.load(std::memory_order_acquire)) {
            return false;
        }

        // 选择分段（轮询）
        size_t stripe_idx = enqueue_stripe_.fetch_add(1, std::memory_order_relaxed)
                          % config_.num_stripes;
        Stripe& stripe = *stripes_[stripe_idx];

        // 限制优先级范围
        priority = std::min(priority, config_.num_priority_levels - 1);

        std::unique_lock<std::mutex> lock(stripe.mutex);

        // 检查容量（背压）
        size_t max_per_stripe = config_.capacity / config_.num_stripes;
        if (stripe.count >= max_per_stripe) {
            auto start = std::chrono::high_resolution_clock::now();
            ++stats_.wait_count;

            if (!stripe.not_full.wait_for(lock, std::chrono::milliseconds(100),
                [&]() {
                    return closed_.load() || stripe.count < max_per_stripe;
                }))
            {
                ++stats_.total_dropped;
                return false;
            }

            auto end = std::chrono::high_resolution_clock::now();
            stats_.wait_time_ns += std::chrono::duration_cast<
                std::chrono::nanoseconds>(end - start).count();
        }

        if (closed_.load(std::memory_order_acquire)) {
            return false;
        }

        // 入队
        stripe.priority_queues[priority].push(std::move(item));
        ++stripe.count;
        ++stats_.total_enqueued;

        lock.unlock();
        stripe.not_empty.notify_one();

        return true;
    }

    // 批量入队
    size_t enqueue_batch(std::vector<T>& items, size_t priority = 0) {
        if (items.empty() || closed_.load()) return 0;

        size_t enqueued = 0;
        size_t stripe_idx = enqueue_stripe_.fetch_add(1, std::memory_order_relaxed)
                          % config_.num_stripes;
        Stripe& stripe = *stripes_[stripe_idx];

        priority = std::min(priority, config_.num_priority_levels - 1);

        std::unique_lock<std::mutex> lock(stripe.mutex);

        size_t max_per_stripe = config_.capacity / config_.num_stripes;
        size_t available = max_per_stripe - stripe.count;
        size_t to_enqueue = std::min(items.size(), available);

        for (size_t i = 0; i < to_enqueue; ++i) {
            stripe.priority_queues[priority].push(std::move(items[i]));
            ++enqueued;
        }

        stripe.count += enqueued;
        stats_.total_enqueued += enqueued;

        lock.unlock();
        stripe.not_empty.notify_all();

        // 移除已入队的
        items.erase(items.begin(), items.begin() + enqueued);

        return enqueued;
    }

    // 出队
    std::optional<T> dequeue() {
        // 尝试所有分段
        for (size_t attempt = 0; attempt < config_.num_stripes; ++attempt) {
            size_t stripe_idx = dequeue_stripe_.fetch_add(1, std::memory_order_relaxed)
                              % config_.num_stripes;
            Stripe& stripe = *stripes_[stripe_idx];

            std::unique_lock<std::mutex> lock(stripe.mutex, std::try_to_lock);
            if (!lock.owns_lock()) continue;

            // 按优先级从高到低查找
            for (auto& queue : stripe.priority_queues) {
                if (!queue.empty()) {
                    T item = std::move(queue.front());
                    queue.pop();
                    --stripe.count;
                    ++stats_.total_dequeued;

                    lock.unlock();
                    stripe.not_full.notify_one();

                    return item;
                }
            }
        }

        return std::nullopt;
    }

    // 阻塞出队
    std::optional<T> dequeue_blocking(std::chrono::milliseconds timeout = std::chrono::milliseconds(100)) {
        auto deadline = std::chrono::steady_clock::now() + timeout;

        while (std::chrono::steady_clock::now() < deadline) {
            // 先尝试非阻塞
            if (auto item = dequeue()) {
                return item;
            }

            if (closed_.load(std::memory_order_acquire)) {
                return std::nullopt;
            }

            // 等待任一分段有数据
            size_t stripe_idx = dequeue_stripe_.load() % config_.num_stripes;
            Stripe& stripe = *stripes_[stripe_idx];

            std::unique_lock<std::mutex> lock(stripe.mutex);
            stripe.not_empty.wait_for(lock, std::chrono::milliseconds(10),
                [&]() {
                    return closed_.load() || stripe.count > 0;
                });
        }

        return std::nullopt;
    }

    // 批量出队
    std::vector<T> dequeue_batch(size_t max_count) {
        std::vector<T> result;
        result.reserve(max_count);

        size_t stripe_idx = dequeue_stripe_.fetch_add(1, std::memory_order_relaxed)
                          % config_.num_stripes;
        Stripe& stripe = *stripes_[stripe_idx];

        std::unique_lock<std::mutex> lock(stripe.mutex);

        for (auto& queue : stripe.priority_queues) {
            while (!queue.empty() && result.size() < max_count) {
                result.push_back(std::move(queue.front()));
                queue.pop();
                --stripe.count;
            }
        }

        stats_.total_dequeued += result.size();

        lock.unlock();
        if (!result.empty()) {
            stripe.not_full.notify_all();
        }

        return result;
    }

    // 关闭队列
    void close() {
        closed_.store(true, std::memory_order_release);
        for (auto& stripe : stripes_) {
            std::lock_guard<std::mutex> lock(stripe->mutex);
            stripe->not_empty.notify_all();
            stripe->not_full.notify_all();
        }
    }

    bool is_closed() const {
        return closed_.load(std::memory_order_acquire);
    }

    // 获取统计
    const Stats& get_stats() const {
        return stats_;
    }

    // 大致大小
    size_t approximate_size() const {
        size_t total = 0;
        for (const auto& stripe : stripes_) {
            std::lock_guard<std::mutex> lock(stripe->mutex);
            total += stripe->count;
        }
        return total;
    }
};

// 性能测试
void benchmark_queue() {
    using Queue = HighThroughputQueue<int>;

    Queue::Config config;
    config.capacity = 100000;
    config.num_stripes = 16;
    config.batch_size = 64;

    Queue queue(config);

    constexpr size_t NUM_PRODUCERS = 4;
    constexpr size_t NUM_CONSUMERS = 4;
    constexpr size_t ITEMS_PER_PRODUCER = 1000000;

    std::atomic<bool> start{false};
    std::atomic<size_t> consumed{0};

    // 生产者
    std::vector<std::thread> producers;
    for (size_t i = 0; i < NUM_PRODUCERS; ++i) {
        producers.emplace_back([&queue, &start, i]() {
            while (!start.load()) std::this_thread::yield();

            for (size_t j = 0; j < ITEMS_PER_PRODUCER; ++j) {
                queue.enqueue(static_cast<int>(i * ITEMS_PER_PRODUCER + j));
            }
        });
    }

    // 消费者
    std::vector<std::thread> consumers;
    for (size_t i = 0; i < NUM_CONSUMERS; ++i) {
        consumers.emplace_back([&queue, &consumed, &start]() {
            while (!start.load()) std::this_thread::yield();

            while (true) {
                if (auto batch = queue.dequeue_batch(64); !batch.empty()) {
                    consumed += batch.size();
                } else if (queue.is_closed() && queue.approximate_size() == 0) {
                    break;
                } else {
                    std::this_thread::yield();
                }
            }
        });
    }

    // 开始测试
    auto t1 = std::chrono::high_resolution_clock::now();
    start.store(true);

    // 等待生产者完成
    for (auto& t : producers) t.join();

    // 等待所有数据被消费
    while (consumed.load() < NUM_PRODUCERS * ITEMS_PER_PRODUCER) {
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }

    queue.close();
    for (auto& t : consumers) t.join();

    auto t2 = std::chrono::high_resolution_clock::now();
    auto duration_ms = std::chrono::duration_cast<std::chrono::milliseconds>(t2 - t1).count();

    std::cout << "\n=== 性能测试结果 ===\n"
              << "总消息数: " << NUM_PRODUCERS * ITEMS_PER_PRODUCER << "\n"
              << "总时间: " << duration_ms << " ms\n"
              << "吞吐量: " << (NUM_PRODUCERS * ITEMS_PER_PRODUCER * 1000 / duration_ms)
              << " msg/s\n";

    queue.get_stats().print();
}
```

### Day 28：月度总结与Year 2复盘

#### 第四周检验标准

- [ ] 能分析和解决死锁问题
- [ ] 会使用ThreadSanitizer检测数据竞争
- [ ] 理解ABA问题及其解决方案
- [ ] 能使用性能分析工具（perf等）
- [ ] 能设计带统计的锁来分析竞争
- [ ] 理解缓存友好的数据结构设计
- [ ] 能实现高吞吐消息队列
- [ ] 能进行性能基准测试

---

## 本月检验标准汇总

### 理论知识（15项）

| 编号 | 检验项 | 对应内容 |
|------|--------|----------|
| T-1 | 能解释PC模式的核心问题和优势 | Week 1 |
| T-2 | 理解条件变量的正确使用（虚假唤醒） | Week 1 |
| T-3 | 能解释各种背压策略的适用场景 | Week 1 |
| T-4 | 理解读写锁的性能陷阱 | Week 2 |
| T-5 | 能解释RCU的工作原理和grace period | Week 2 |
| T-6 | 理解伪共享问题的原因和影响 | Week 2 |
| T-7 | 能对比共享内存和消息传递 | Week 3 |
| T-8 | 能对比锁、无锁、Actor三种方案 | Week 3 |
| T-9 | 能对比线程、协程、Future模型 | Week 3 |
| T-10 | 理解双缓冲技术的适用场景 | Week 3 |
| T-11 | 能说明死锁的四个必要条件 | Week 4 |
| T-12 | 理解ABA问题及解决方案 | Week 4 |
| T-13 | 能解释缓存行对性能的影响 | Week 4 |
| T-14 | 理解Month 13-22各月份的核心知识 | 全月 |
| T-15 | 能建立场景到方案的决策框架 | Week 3-4 |

### 实践能力（18项）

| 编号 | 检验项 | 对应内容 |
|------|--------|----------|
| P-1 | 实现多生产者多消费者队列 | Week 1 |
| P-2 | 实现带背压的队列 | Week 1 |
| P-3 | 实现优先级队列变种 | Week 1 |
| P-4 | 实现批量处理优化 | Week 1 |
| P-5 | 实现线程安全缓存（shared_mutex） | Week 2 |
| P-6 | 实现写优先/公平读写锁 | Week 2 |
| P-7 | 实现简化版RCU | Week 2 |
| P-8 | 实现分段锁HashMap | Week 2 |
| P-9 | 实现原子交换双缓冲 | Week 3 |
| P-10 | 实现消息传递版银行转账 | Week 3 |
| P-11 | 设计并发场景分析函数 | Week 3 |
| P-12 | 编写死锁示例和修复 | Week 4 |
| P-13 | 使用TSan检测数据竞争 | Week 4 |
| P-14 | 实现带统计的锁 | Week 4 |
| P-15 | 实现性能计时器 | Week 4 |
| P-16 | 实现高吞吐消息队列 | Week 4 |
| P-17 | 完成性能基准测试 | Week 4 |
| P-18 | 生成性能分析报告 | Week 4 |

### 综合项目（5项）

| 编号 | 检验项 | 产出物 |
|------|--------|--------|
| C-1 | 完成并发模式决策指南文档 | decision_guide.md |
| C-2 | 完成Month 13-22知识整合表 | patterns_comparison.md |
| C-3 | 完成高吞吐消息队列项目 | high_throughput_queue.hpp |
| C-4 | 生成性能基准报告 | performance_report.md |
| C-5 | 完成Year 2并发知识总结 | year2_summary.md |

---

## 输出物清单

### 核心代码文件

```
month23/
├── producer_consumer/
│   ├── bounded_buffer.hpp          # 基础有界缓冲
│   ├── mpmc_queue.hpp              # 多生产多消费队列
│   ├── backpressure_queue.hpp      # 背压队列
│   ├── priority_queue.hpp          # 优先级队列
│   ├── batch_queue.hpp             # 批量处理队列
│   └── closable_queue.hpp          # 可关闭队列
├── rwlock/
│   ├── thread_safe_cache.hpp       # 读写锁缓存
│   ├── write_preferring_rwlock.hpp # 写优先读写锁
│   ├── fair_rwlock.hpp             # 公平读写锁
│   ├── simple_rcu.hpp              # 简化RCU
│   └── striped_hashmap.hpp         # 分段锁HashMap
├── double_buffer/
│   ├── double_buffer.hpp           # 基础双缓冲
│   ├── atomic_double_buffer.hpp    # 原子双缓冲
│   ├── triple_buffer.hpp           # 三缓冲
│   └── task_queue.hpp              # 双缓冲任务队列
├── debug/
│   ├── deadlock_demo.cpp           # 死锁示例
│   ├── tsan_examples.cpp           # TSan示例
│   ├── instrumented_mutex.hpp      # 带统计的锁
│   └── perf_stats.hpp              # 性能统计
├── project/
│   ├── high_throughput_queue.hpp   # 高吞吐队列
│   └── benchmark.cpp               # 基准测试
└── tests/
    ├── pc_tests.cpp                # PC模式测试
    ├── rwlock_tests.cpp            # 读写锁测试
    └── benchmark_all.cpp           # 完整基准测试
```

### 文档输出

```
docs/
├── decision_guide.md               # 并发模式决策指南
├── patterns_comparison.md          # 模式对比分析
├── performance_report.md           # 性能基准报告
├── antipatterns.md                 # 反模式总结
└── year2_summary.md                # Year 2知识总结
```

### 学习笔记

```
notes/
├── week1_producer_consumer.md      # Week 1笔记
├── week2_rwlock.md                 # Week 2笔记
├── week3_decision_guide.md         # Week 3笔记
└── week4_debugging.md              # Week 4笔记
```

---

## Year 2 并发编程知识总结

### 知识体系回顾

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                          Year 2 并发编程知识体系                                 │
├────────────────────────────────────────────────────────────────────────────────┤
│                                                                                │
│  基础层 (Month 13-15)                                                          │
│  ┌─────────────────────────────────────────────────────────────┐              │
│  │  Month 13: 线程与同步原语                                    │              │
│  │  • std::thread, std::mutex, std::condition_variable          │              │
│  │  • RAII锁管理, 线程安全设计                                  │              │
│  │                                                              │              │
│  │  Month 14: C++内存模型                                       │              │
│  │  • memory_order, happens-before, synchronizes-with           │              │
│  │  • 顺序一致性, 获取-释放语义                                 │              │
│  │                                                              │              │
│  │  Month 15: 原子操作与CAS                                     │              │
│  │  • std::atomic, compare_exchange                             │              │
│  │  • 无锁编程基础                                              │              │
│  └─────────────────────────────────────────────────────────────┘              │
│                                   ↓                                            │
│  无锁编程层 (Month 16-18)                                                      │
│  ┌─────────────────────────────────────────────────────────────┐              │
│  │  Month 16: ABA问题与内存回收                                 │              │
│  │  • Hazard Pointers, Epoch-based, RCU                         │              │
│  │                                                              │              │
│  │  Month 17: 无锁队列                                          │              │
│  │  • SPSC, MPSC, Michael-Scott队列                             │              │
│  │                                                              │              │
│  │  Month 18: Future/Promise                                    │              │
│  │  • std::future, std::promise, std::async                     │              │
│  │  • 异步编程模式                                              │              │
│  └─────────────────────────────────────────────────────────────┘              │
│                                   ↓                                            │
│  高级并发层 (Month 19-22)                                                      │
│  ┌─────────────────────────────────────────────────────────────┐              │
│  │  Month 19: 线程池设计                                        │              │
│  │  • 工作窃取, Fork/Join, DAG调度                              │              │
│  │                                                              │              │
│  │  Month 20: Actor模型                                         │              │
│  │  • 消息传递, Mailbox, 监督树                                 │              │
│  │                                                              │              │
│  │  Month 21: C++20协程基础                                     │              │
│  │  • co_await, co_return, Task, Generator, Channel             │              │
│  │                                                              │              │
│  │  Month 22: 协程异步I/O                                       │              │
│  │  • EventLoop, AsyncSocket, Reactor模式                       │              │
│  └─────────────────────────────────────────────────────────────┘              │
│                                   ↓                                            │
│  总结应用层 (Month 23-24)                                                      │
│  ┌─────────────────────────────────────────────────────────────┐              │
│  │  Month 23: 并发模式与最佳实践 【本月】                        │              │
│  │  • PC模式深度, 读写锁优化, 决策指南, 调试技术                │              │
│  │                                                              │              │
│  │  Month 24: 综合项目                                          │              │
│  │  • 整合应用所有知识                                          │              │
│  └─────────────────────────────────────────────────────────────┘              │
│                                                                                │
└────────────────────────────────────────────────────────────────────────────────┘
```

### 为Month 24准备

Month 24综合项目将综合运用Year 2的所有并发知识：

| Month 23 产出 | Month 24 应用 |
|---------------|---------------|
| 决策指南 | 项目架构选型 |
| 性能数据 | 性能目标制定 |
| 各模式代码 | 组件实现参考 |
| 调试技能 | 问题诊断 |
| 最佳实践 | 代码质量保证 |

---

## 学习建议

### 本月学习节奏

```
Week 1: 生产者-消费者模式
        ↓ 强化基础
Week 2: 读写锁与优化
        ↓ 深入技术
Week 3: 模式选择与决策
        ↓ 建立框架
Week 4: 综合实战与总结
        ↓ 融会贯通
```

### 关键成功因素

1. **动手实践**：每个模式都要自己实现一遍
2. **性能测试**：养成用数据说话的习惯
3. **对比思考**：理解各方案的权衡
4. **回顾整合**：把Month 13-22的知识串联起来
5. **准备项目**：为Month 24积累素材

### 常见困难与解决

| 困难 | 解决方案 |
|------|----------|
| 模式太多记不住 | 制作对比表格，按场景分类 |
| 不知道选哪个 | 遵循决策流程图 |
| 性能测试不会做 | 使用本月的测试框架模板 |
| 调试困难 | 使用TSan，加入统计代码 |

---

**本月是Year 2的关键总结月，好好把握！Month 24综合项目正在等着你！**