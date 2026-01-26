# Month 18: Future/Promise与异步编程——并发任务管理

## 本月主题概述

Future/Promise是管理异步操作的重要抽象，它将"计算的发起"与"结果的获取"解耦，是现代并发编程的核心范式。本月将深入学习std::future、std::promise、std::packaged_task、std::async的完整API和内部实现原理，探索与协程的关系，学习组合器模式（then、when_all、when_any），并与其他语言（Rust、JavaScript）的实现进行对比。

**前置知识**：Month 13-17的并发基础、内存模型、原子操作、ABA问题、无锁队列

**后续衔接**：Month 19线程池设计将大量使用Future/Promise进行任务调度

---

## 理论学习内容

### 第一周：Future/Promise基础与内部实现

**学习目标**：
- 掌握std::promise和std::future的完整API
- 理解Future/Promise的内部实现原理（共享状态）
- 分析一次性同步的设计哲学
- 能够从零实现一个mini_future

**阅读材料**：
- [ ] 《C++ Concurrency in Action》第4章：同步并发操作
- [ ] CppCon 2015：[Gor Nishanov - C++ Coroutines: Understanding the Compiler](https://www.youtube.com/watch?v=8C8NnE1Dg4A)
- [ ] CppCon 2017：[Sean Parent - Better Code: Concurrency](https://www.youtube.com/watch?v=zULU6Hhp42w)
- [ ] cppreference: std::promise, std::future 完整文档

---

#### 核心概念：Future/Promise模型

```cpp
#include <future>
#include <thread>
#include <iostream>
#include <chrono>

// ==================== 基础概念 ====================
// Promise: 生产端，负责设置值或异常
// Future: 消费端，负责获取值或等待
// SharedState: 连接两者的共享状态（内部实现）

// ==================== 生命周期图示 ====================
/*
                    ┌─────────────────────────────────────────────┐
                    │              SharedState                     │
                    │  ┌─────────────────────────────────────┐    │
                    │  │ - mutex                              │    │
    Promise ───────►│  │ - condition_variable                 │◄─── Future
    (生产者)        │  │ - value/exception (optional)         │    (消费者)
                    │  │ - ready_flag                         │
                    │  │ - reference_count                    │
                    │  └─────────────────────────────────────┘    │
                    └─────────────────────────────────────────────┘

    时序：
    1. 创建promise
    2. 从promise获取future (get_future())
    3. 将promise/future传递给不同线程
    4. producer调用set_value/set_exception
    5. consumer调用get()获取结果
*/

// ==================== 基本使用模式 ====================

void basic_promise_future() {
    std::promise<int> prom;
    std::future<int> fut = prom.get_future();  // 只能调用一次！

    // 生产者线程
    std::thread producer([&prom]() {
        std::this_thread::sleep_for(std::chrono::seconds(1));
        prom.set_value(42);  // 设置值，唤醒等待者
    });

    // 消费者线程
    std::thread consumer([&fut]() {
        std::cout << "Waiting for result...\n";
        int value = fut.get();  // 阻塞直到值可用，只能调用一次！
        std::cout << "Got: " << value << "\n";
    });

    producer.join();
    consumer.join();
}

// ==================== Promise的完整API ====================

void promise_api_demo() {
    // 1. 默认构造
    std::promise<int> p1;

    // 2. 移动构造（promise不可复制）
    std::promise<int> p2 = std::move(p1);
    // p1 现在为空

    // 3. 获取关联的future
    std::future<int> f = p2.get_future();
    // 再次调用get_future()会抛出std::future_error

    // 4. 设置值
    p2.set_value(100);

    // 5. 延迟设置（在promise销毁时自动设置）
    std::promise<int> p3;
    auto f3 = p3.get_future();
    p3.set_value_at_thread_exit(200);
    // 值在线程退出时才对future可见

    // 6. 设置异常
    std::promise<int> p4;
    auto f4 = p4.get_future();
    p4.set_exception(std::make_exception_ptr(std::runtime_error("Error!")));

    // 7. void特化
    std::promise<void> p_void;
    auto f_void = p_void.get_future();
    p_void.set_value();  // 仅作为同步信号
}

// ==================== Future的完整API ====================

void future_api_demo() {
    auto fut = std::async(std::launch::async, []() {
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
        return 42;
    });

    // 1. valid(): 检查future是否有关联的共享状态
    std::cout << "valid: " << fut.valid() << "\n";  // true

    // 2. wait(): 阻塞等待结果就绪（不获取结果）
    fut.wait();

    // 3. wait_for(): 带超时的等待
    auto status = fut.wait_for(std::chrono::milliseconds(100));
    switch (status) {
        case std::future_status::ready:
            std::cout << "Result is ready\n";
            break;
        case std::future_status::timeout:
            std::cout << "Timeout\n";
            break;
        case std::future_status::deferred:
            std::cout << "Deferred (lazy evaluation)\n";
            break;
    }

    // 4. wait_until(): 等待到指定时间点
    auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(1);
    fut.wait_until(deadline);

    // 5. get(): 获取结果（阻塞，只能调用一次）
    int result = fut.get();
    std::cout << "Result: " << result << "\n";

    // fut.valid() 现在为 false
    // 再次调用get()会抛出异常

    // 6. share(): 转换为shared_future（详见第三周）
}

// ==================== 常见错误和陷阱 ====================

void common_pitfalls() {
    // 陷阱1: 忘记设置promise值
    {
        std::promise<int> p;
        auto f = p.get_future();
        // p 析构时，如果没有设置值，会设置broken_promise异常
        // f.get() 会抛出 std::future_error
    }

    // 陷阱2: 多次调用get_future()
    {
        std::promise<int> p;
        auto f1 = p.get_future();
        // auto f2 = p.get_future();  // 抛出 std::future_error
    }

    // 陷阱3: 多次调用get()
    {
        auto f = std::async([]{ return 42; });
        int v1 = f.get();
        // int v2 = f.get();  // 抛出 std::future_error
    }

    // 陷阱4: 忘记移动promise到线程
    {
        std::promise<int> p;
        auto f = p.get_future();
        // std::thread t([p](){ ... });  // 错误！promise不可复制
        std::thread t([p = std::move(p)]() mutable {
            p.set_value(42);
        });
        t.detach();
    }

    // 陷阱5: std::async返回值未保存
    {
        // 危险！future析构会阻塞等待任务完成
        // std::async(std::launch::async, expensive_task);
        // 看起来是异步，实际是同步！

        // 正确做法：保存future
        auto f = std::async(std::launch::async, []{ /* ... */ });
        // 或使用detach模式
    }
}
```

---

#### 📅 第一周每日详细计划

##### Day 1: Future/Promise概念建立（5小时）

**上午（2.5小时）- 理论奠基**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 概念引入 | 阅读《C++ Concurrency in Action》第4章前半部分 |
| 1:30-2:00 | 设计哲学 | 理解"一次性同步"的设计意图和应用场景 |
| 2:00-2:30 | API学习 | 熟悉promise/future的完整API |

**下午（2.5小时）- 实践编码**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 动手实验 | 编写基本的promise-future通信程序 |
| 1:30-2:00 | 边界测试 | 测试各种边界情况（空promise、多次get等） |
| 2:00-2:30 | 笔记整理 | 绘制生命周期图，总结API |

**今日输出物**：
- [ ] 代码：`day1_basic_future.cpp` - 基本使用示例
- [ ] 笔记：Future/Promise基本概念和API总结

**思考问题**：
1. 为什么Promise只能set一次值？这种设计有什么好处？
2. 如果Promise在设置值之前就析构了，会发生什么？

---

##### Day 2: SharedState内部结构分析（5小时）

**上午（2.5小时）- 源码阅读**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | libstdc++分析 | 阅读GCC的`<future>`实现源码 |
| 1:30-2:30 | libc++对比 | 对比LLVM libc++的实现差异 |

**下午（2.5小时）- 设计分析**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 引用计数 | 理解SharedState的生命周期管理机制 |
| 1:00-2:00 | 骨架设计 | 设计mini_future的共享状态结构 |
| 2:00-2:30 | 代码初稿 | 编写SharedState的基础框架 |

**深入解析：SharedState内部结构**

```cpp
// ==================== 标准库实现的简化视图 ====================

// SharedState的核心职责：
// 1. 存储计算结果或异常
// 2. 同步生产者和消费者
// 3. 管理生命周期（引用计数）

template <typename T>
struct SharedState {
    // 同步原语
    std::mutex mutex_;
    std::condition_variable cv_;

    // 状态标志
    enum class State { NotReady, Ready, Consumed };
    State state_ = State::NotReady;

    // 存储
    union Storage {
        T value_;
        std::exception_ptr exception_;

        Storage() {}
        ~Storage() {}
    } storage_;
    bool has_exception_ = false;

    // 引用计数（promise和future各持有一个）
    std::atomic<int> ref_count_{2};

    // 设置值
    void set_value(T value) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (state_ != State::NotReady) {
            throw std::future_error(std::future_errc::promise_already_satisfied);
        }
        new (&storage_.value_) T(std::move(value));
        state_ = State::Ready;
        cv_.notify_all();
    }

    // 获取值
    T get_value() {
        std::unique_lock<std::mutex> lock(mutex_);
        cv_.wait(lock, [this] { return state_ == State::Ready; });

        if (state_ == State::Consumed) {
            throw std::future_error(std::future_errc::future_already_retrieved);
        }
        state_ = State::Consumed;

        if (has_exception_) {
            std::rethrow_exception(storage_.exception_);
        }
        return std::move(storage_.value_);
    }

    // 引用计数管理
    void add_ref() {
        ref_count_.fetch_add(1, std::memory_order_relaxed);
    }

    void release() {
        if (ref_count_.fetch_sub(1, std::memory_order_acq_rel) == 1) {
            delete this;
        }
    }
};
```

**今日输出物**：
- [ ] 笔记：SharedState结构分析
- [ ] 代码：`mini_shared_state.hpp` - 共享状态的骨架代码

**思考问题**：
1. 为什么需要引用计数？单纯使用shared_ptr不行吗？
2. SharedState中的union有什么作用？为什么不直接用optional？

---

##### Day 3: void特化与异常处理机制（5小时）

**上午（2.5小时）- 理论学习**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | void特化 | 学习promise<void>的特殊语义和用途 |
| 1:00-2:30 | 异常传播 | 深入理解异常在future中的传播机制 |

**下午（2.5小时）- 实践编码**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | void实现 | 实现mini_future的void特化 |
| 1:30-2:00 | 异常测试 | 编写异常传播的测试用例 |
| 2:00-2:30 | 总结整理 | 总结void特化的设计考量 |

**核心代码：void特化与异常传播**

```cpp
// ==================== void特化的独特用途 ====================

// void特化用于纯同步信号，不传递数据
// 常见场景：
// 1. 任务完成通知
// 2. 资源初始化就绪信号
// 3. 多阶段流水线的同步点

class ResourceManager {
    std::promise<void> init_promise_;
    std::shared_future<void> init_future_;

public:
    ResourceManager() : init_future_(init_promise_.get_future()) {}

    void initialize() {
        // 耗时初始化...
        std::this_thread::sleep_for(std::chrono::seconds(2));
        init_promise_.set_value();  // 通知初始化完成
    }

    void wait_for_init() {
        init_future_.wait();  // 等待初始化完成
    }
};

// ==================== 异常传播机制详解 ====================

void exception_propagation_example() {
    std::promise<int> prom;
    std::future<int> fut = prom.get_future();

    std::thread t([&prom]() {
        try {
            // 模拟可能失败的计算
            throw std::runtime_error("Computation failed!");
        } catch (...) {
            // 捕获异常并传播给future
            prom.set_exception(std::current_exception());
        }
    });

    try {
        int result = fut.get();  // 会重新抛出异常
    } catch (const std::runtime_error& e) {
        std::cout << "Caught exception: " << e.what() << "\n";
    }

    t.join();
}

// ==================== 异常传播的内部机制 ====================

/*
    异常传播流程：
    1. 生产者捕获异常 -> std::current_exception()获取exception_ptr
    2. promise.set_exception(ptr) 存储到SharedState
    3. future.get() 检测到has_exception标志
    4. std::rethrow_exception(ptr) 重新抛出

    关键点：
    - exception_ptr是异常的"智能指针"
    - 异常对象本身存储在动态内存中
    - 可以跨线程传播，不会切片（slicing）
*/
```

**今日输出物**：
- [ ] 代码：`day3_void_specialization.cpp` - void特化示例
- [ ] 代码：`day3_exception_propagation.cpp` - 异常传播测试

**思考问题**：
1. exception_ptr是什么？为什么不能直接存储异常对象？
2. void特化的promise和普通promise在实现上有什么不同？

---

##### Day 4: 引用计数与生命周期管理（5小时）

**上午（2.5小时）- 理论分析**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 引用计数策略 | 分析promise/future的引用计数策略 |
| 1:30-2:30 | 边界条件 | 理解broken_promise的产生条件 |

**下午（2.5小时）- 实现编码**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 代码实现 | 实现mini_future的引用计数机制 |
| 2:00-2:30 | 总结整理 | 总结资源管理的边界条件 |

**核心代码：生命周期边界条件**

```cpp
// ==================== 生命周期边界条件分析 ====================

/*
    四种销毁顺序场景：

    场景1: Promise先销毁，未设值
    - SharedState设置broken_promise异常
    - future.get()抛出std::future_error

    场景2: Promise先销毁，已设值
    - 正常，future仍可获取值
    - SharedState引用计数减1

    场景3: Future先销毁
    - SharedState引用计数减1
    - Promise仍可设值（虽然没人接收）

    场景4: 双方都销毁
    - 引用计数归零，释放SharedState
*/

void lifetime_demo() {
    // 场景1: broken_promise
    {
        std::future<int> fut;
        {
            std::promise<int> prom;
            fut = prom.get_future();
            // prom析构，未设值
        }
        try {
            fut.get();  // 抛出broken_promise
        } catch (const std::future_error& e) {
            std::cout << "Error: " << e.what() << "\n";
            // "The associated promise has been destructed prior to the
            //  associated state becoming ready."
        }
    }

    // 场景2: 正常获取
    {
        std::future<int> fut;
        {
            std::promise<int> prom;
            fut = prom.get_future();
            prom.set_value(42);
            // prom析构，已设值
        }
        std::cout << fut.get() << "\n";  // 正常输出42
    }
}
```

**今日输出物**：
- [ ] 代码：`mini_future_v1.hpp` - 带引用计数的初版实现

**思考问题**：
1. 如果Future先销毁，Promise后设值，这个值去哪了？
2. 为什么broken_promise是一种特殊的异常而不是普通的运行时错误？

---

##### Day 5: mini_future完整实现（5小时）

**上午（2小时）- Promise实现**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 代码编写 | 实现完整的mini_promise类 |

**下午（3小时）- Future实现与测试**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 代码编写 | 实现完整的mini_future类 |
| 2:00-2:30 | 单元测试 | 编写单元测试验证正确性 |
| 2:30-3:00 | 代码Review | 优化实现，检查边界条件 |

**完整实现：mini_future.hpp**

```cpp
// mini_future.hpp - 完整实现
#pragma once
#include <mutex>
#include <condition_variable>
#include <memory>
#include <exception>
#include <optional>
#include <functional>
#include <stdexcept>
#include <atomic>

namespace mini {

// 前向声明
template <typename T> class promise;
template <typename T> class future;

// ==================== 共享状态 ====================
template <typename T>
class shared_state {
    friend class promise<T>;
    friend class future<T>;

    mutable std::mutex mutex_;
    std::condition_variable cv_;

    enum class status { not_ready, value_set, exception_set };
    status status_ = status::not_ready;

    std::optional<T> value_;
    std::exception_ptr exception_;

    std::atomic<bool> future_retrieved_{false};

public:
    void set_value(T val) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (status_ != status::not_ready) {
            throw std::runtime_error("Promise already satisfied");
        }
        value_ = std::move(val);
        status_ = status::value_set;
        cv_.notify_all();
    }

    void set_exception(std::exception_ptr e) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (status_ != status::not_ready) {
            throw std::runtime_error("Promise already satisfied");
        }
        exception_ = e;
        status_ = status::exception_set;
        cv_.notify_all();
    }

    T get() {
        std::unique_lock<std::mutex> lock(mutex_);
        cv_.wait(lock, [this] { return status_ != status::not_ready; });

        if (status_ == status::exception_set) {
            std::rethrow_exception(exception_);
        }
        return std::move(*value_);
    }

    void wait() const {
        std::unique_lock<std::mutex> lock(mutex_);
        cv_.wait(lock, [this] { return status_ != status::not_ready; });
    }

    template <typename Rep, typename Period>
    bool wait_for(const std::chrono::duration<Rep, Period>& timeout) const {
        std::unique_lock<std::mutex> lock(mutex_);
        return cv_.wait_for(lock, timeout,
            [this] { return status_ != status::not_ready; });
    }

    bool is_ready() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return status_ != status::not_ready;
    }

    void mark_broken() {
        std::lock_guard<std::mutex> lock(mutex_);
        if (status_ == status::not_ready) {
            exception_ = std::make_exception_ptr(
                std::runtime_error("Broken promise"));
            status_ = status::exception_set;
            cv_.notify_all();
        }
    }
};

// ==================== Promise ====================
template <typename T>
class promise {
    std::shared_ptr<shared_state<T>> state_;

public:
    promise() : state_(std::make_shared<shared_state<T>>()) {}

    promise(promise&& other) noexcept : state_(std::move(other.state_)) {}

    promise& operator=(promise&& other) noexcept {
        if (this != &other) {
            abandon_state();
            state_ = std::move(other.state_);
        }
        return *this;
    }

    promise(const promise&) = delete;
    promise& operator=(const promise&) = delete;

    ~promise() {
        abandon_state();
    }

    future<T> get_future() {
        if (!state_) {
            throw std::runtime_error("No state");
        }
        if (state_->future_retrieved_.exchange(true)) {
            throw std::runtime_error("Future already retrieved");
        }
        return future<T>(state_);
    }

    void set_value(T value) {
        if (!state_) {
            throw std::runtime_error("No state");
        }
        state_->set_value(std::move(value));
    }

    void set_exception(std::exception_ptr e) {
        if (!state_) {
            throw std::runtime_error("No state");
        }
        state_->set_exception(e);
    }

private:
    void abandon_state() {
        if (state_) {
            state_->mark_broken();
            state_.reset();
        }
    }
};

// ==================== Future ====================
template <typename T>
class future {
    friend class promise<T>;
    std::shared_ptr<shared_state<T>> state_;

    explicit future(std::shared_ptr<shared_state<T>> state)
        : state_(std::move(state)) {}

public:
    future() = default;
    future(future&& other) noexcept : state_(std::move(other.state_)) {}

    future& operator=(future&& other) noexcept {
        state_ = std::move(other.state_);
        return *this;
    }

    future(const future&) = delete;
    future& operator=(const future&) = delete;

    bool valid() const noexcept {
        return state_ != nullptr;
    }

    T get() {
        if (!state_) {
            throw std::runtime_error("No state");
        }
        auto state = std::move(state_);  // 转移所有权
        return state->get();
    }

    void wait() const {
        if (!state_) {
            throw std::runtime_error("No state");
        }
        state_->wait();
    }

    template <typename Rep, typename Period>
    bool wait_for(const std::chrono::duration<Rep, Period>& timeout) const {
        if (!state_) {
            throw std::runtime_error("No state");
        }
        return state_->wait_for(timeout);
    }

    bool is_ready() const {
        return state_ && state_->is_ready();
    }
};

// ==================== void特化 ====================
template <>
class shared_state<void> {
    friend class promise<void>;
    friend class future<void>;

    mutable std::mutex mutex_;
    std::condition_variable cv_;
    enum class status { not_ready, ready, exception_set };
    status status_ = status::not_ready;
    std::exception_ptr exception_;
    std::atomic<bool> future_retrieved_{false};

public:
    void set_value() {
        std::lock_guard<std::mutex> lock(mutex_);
        if (status_ != status::not_ready) {
            throw std::runtime_error("Promise already satisfied");
        }
        status_ = status::ready;
        cv_.notify_all();
    }

    void set_exception(std::exception_ptr e) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (status_ != status::not_ready) {
            throw std::runtime_error("Promise already satisfied");
        }
        exception_ = e;
        status_ = status::exception_set;
        cv_.notify_all();
    }

    void get() {
        std::unique_lock<std::mutex> lock(mutex_);
        cv_.wait(lock, [this] { return status_ != status::not_ready; });
        if (status_ == status::exception_set) {
            std::rethrow_exception(exception_);
        }
    }

    void wait() const {
        std::unique_lock<std::mutex> lock(mutex_);
        cv_.wait(lock, [this] { return status_ != status::not_ready; });
    }

    template <typename Rep, typename Period>
    bool wait_for(const std::chrono::duration<Rep, Period>& timeout) const {
        std::unique_lock<std::mutex> lock(mutex_);
        return cv_.wait_for(lock, timeout,
            [this] { return status_ != status::not_ready; });
    }

    bool is_ready() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return status_ != status::not_ready;
    }

    void mark_broken() {
        std::lock_guard<std::mutex> lock(mutex_);
        if (status_ == status::not_ready) {
            exception_ = std::make_exception_ptr(
                std::runtime_error("Broken promise"));
            status_ = status::exception_set;
            cv_.notify_all();
        }
    }
};

template <>
class promise<void> {
    std::shared_ptr<shared_state<void>> state_;

public:
    promise() : state_(std::make_shared<shared_state<void>>()) {}

    promise(promise&& other) noexcept : state_(std::move(other.state_)) {}

    promise& operator=(promise&& other) noexcept {
        if (this != &other) {
            abandon_state();
            state_ = std::move(other.state_);
        }
        return *this;
    }

    promise(const promise&) = delete;
    promise& operator=(const promise&) = delete;

    ~promise() {
        abandon_state();
    }

    future<void> get_future();

    void set_value() {
        if (!state_) {
            throw std::runtime_error("No state");
        }
        state_->set_value();
    }

    void set_exception(std::exception_ptr e) {
        if (!state_) {
            throw std::runtime_error("No state");
        }
        state_->set_exception(e);
    }

private:
    void abandon_state() {
        if (state_) {
            state_->mark_broken();
            state_.reset();
        }
    }
};

template <>
class future<void> {
    friend class promise<void>;
    std::shared_ptr<shared_state<void>> state_;

    explicit future(std::shared_ptr<shared_state<void>> state)
        : state_(std::move(state)) {}

public:
    future() = default;
    future(future&& other) noexcept : state_(std::move(other.state_)) {}

    future& operator=(future&& other) noexcept {
        state_ = std::move(other.state_);
        return *this;
    }

    future(const future&) = delete;
    future& operator=(const future&) = delete;

    bool valid() const noexcept {
        return state_ != nullptr;
    }

    void get() {
        if (!state_) {
            throw std::runtime_error("No state");
        }
        auto state = std::move(state_);
        state->get();
    }

    void wait() const {
        if (!state_) {
            throw std::runtime_error("No state");
        }
        state_->wait();
    }

    template <typename Rep, typename Period>
    bool wait_for(const std::chrono::duration<Rep, Period>& timeout) const {
        if (!state_) {
            throw std::runtime_error("No state");
        }
        return state_->wait_for(timeout);
    }

    bool is_ready() const {
        return state_ && state_->is_ready();
    }
};

inline future<void> promise<void>::get_future() {
    if (!state_) {
        throw std::runtime_error("No state");
    }
    if (state_->future_retrieved_.exchange(true)) {
        throw std::runtime_error("Future already retrieved");
    }
    return future<void>(state_);
}

} // namespace mini
```

**今日输出物**：
- [ ] 代码：`mini_future.hpp` - 完整实现
- [ ] 代码：`test_mini_future.cpp` - 测试用例

---

##### Day 6: 与其他语言的对比分析（5小时）

**上午（3小时）- 跨语言学习**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | JavaScript | 分析JavaScript Promise的设计（then/catch/finally） |
| 1:30-3:00 | Rust | 分析Rust的Future trait和async/await |

**下午（2小时）- 对比总结**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 设计对比 | 对比三种语言的设计哲学差异 |
| 1:00-2:00 | 笔记总结 | 总结各语言的优缺点 |

**核心内容：跨语言对比**

```cpp
// ==================== 跨语言对比 ====================

/*
┌─────────────────┬──────────────────────┬──────────────────────┬──────────────────────┐
│ 特性            │ C++ std::future      │ JavaScript Promise   │ Rust Future          │
├─────────────────┼──────────────────────┼──────────────────────┼──────────────────────┤
│ 执行模型        │ 立即执行(eager)      │ 立即执行(eager)      │ 惰性执行(lazy)       │
│ 链式调用        │ 不支持(.then仅实验性)│ 内置(.then/.catch)   │ 内置(.await)         │
│ 结果获取        │ get()阻塞，一次性    │ then回调，可多次     │ .await，需executor   │
│ 错误处理        │ 异常传播             │ reject + catch       │ Result<T, E>         │
│ 多消费者        │ shared_future        │ 默认支持             │ Clone trait          │
│ 取消支持        │ 无原生支持           │ AbortController      │ Drop trait           │
│ 内存管理        │ 共享状态引用计数     │ GC                   │ 所有权系统           │
│ 零开销          │ 否（动态分配）       │ 否（GC）             │ 是（编译期状态机）   │
└─────────────────┴──────────────────────┴──────────────────────┴──────────────────────┘

C++的设计哲学：
- 与线程紧密集成（std::async）
- 一次性消费保证线程安全
- 向后兼容，不破坏现有代码

JavaScript的设计哲学：
- 单线程事件循环模型
- 链式调用支持组合
- Promise/A+规范保证互操作

Rust的设计哲学：
- 零成本抽象
- 惰性求值（不poll就不执行）
- 所有权系统保证内存安全
*/

// ==================== JavaScript风格的链式调用（模拟） ====================

// C++标准库不支持.then()，但可以模拟：
template <typename T>
class ChainableFuture {
    std::future<T> inner_;

public:
    explicit ChainableFuture(std::future<T>&& f) : inner_(std::move(f)) {}

    template <typename F>
    auto then(F&& func) -> ChainableFuture<decltype(func(std::declval<T>()))> {
        using R = decltype(func(std::declval<T>()));

        // 创建新的promise/future对
        std::promise<R> prom;
        auto fut = prom.get_future();

        // 启动后台线程等待并转换
        std::thread([inner = std::move(inner_),
                     func = std::forward<F>(func),
                     prom = std::move(prom)]() mutable {
            try {
                if constexpr (std::is_void_v<T>) {
                    inner.get();
                    if constexpr (std::is_void_v<R>) {
                        func();
                        prom.set_value();
                    } else {
                        prom.set_value(func());
                    }
                } else {
                    if constexpr (std::is_void_v<R>) {
                        func(inner.get());
                        prom.set_value();
                    } else {
                        prom.set_value(func(inner.get()));
                    }
                }
            } catch (...) {
                prom.set_exception(std::current_exception());
            }
        }).detach();

        return ChainableFuture<R>(std::move(fut));
    }

    T get() { return inner_.get(); }
};

// 使用示例
void chainable_demo() {
    auto result = ChainableFuture<int>(std::async([]{ return 10; }))
        .then([](int x) { return x * 2; })      // 20
        .then([](int x) { return x + 5; })      // 25
        .then([](int x) { return std::to_string(x); })  // "25"
        .get();

    std::cout << result << "\n";  // "25"
}
```

**今日输出物**：
- [ ] 笔记：跨语言Future/Promise对比分析

**思考问题**：
1. 为什么Rust选择惰性执行而C++选择立即执行？各有什么优缺点？
2. JavaScript的Promise可以多次then，而C++的future只能get一次，这种差异的原因是什么？

---

##### Day 7: 周总结与实战（5小时）

**上午（2小时）- 复习与测试**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 复习 | 回顾本周所有概念，查漏补缺 |
| 1:00-2:00 | 检验 | 完成知识检验题 |

**下午（3小时）- 完善与总结**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 完善测试 | 完成mini_future的完整测试套件 |
| 2:00-3:00 | 笔记整理 | 撰写本周学习笔记 |

**今日输出物**：
- [ ] 代码：`test_mini_future_complete.cpp` - 完整测试
- [ ] 笔记：`notes/week1_future_promise_basics.md` - 周总结

---

#### 扩展阅读资源

**必读（优先级：高）**
- [ ] 论文：[N3558 - A proposal to add a utility class to represent expected monad](https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2013/n3558.pdf)
- [ ] CppCon 2015：[Gor Nishanov - C++ Coroutines: Understanding the Compiler](https://www.youtube.com/watch?v=8C8NnE1Dg4A)
- [ ] 博客：[Preshing - A Minimal Lock-Free Concurrent Queue for C++](https://preshing.com/20120612/an-introduction-to-lock-free-programming/)

**推荐阅读（优先级：中）**
- [ ] libstdc++ future源码：[bits/future.h](https://github.com/gcc-mirror/gcc/blob/master/libstdc%2B%2B-v3/include/std/future)
- [ ] libc++ future源码：[future](https://github.com/llvm/llvm-project/blob/main/libcxx/include/future)
- [ ] 博客：[cppcoro - Understanding C++ Coroutines](https://lewissbaker.github.io/)

**深入研究（优先级：低）**
- [ ] 论文：[Futures and Promises](http://dist-prog-book.com/chapter/2/futures.html) - 分布式编程视角
- [ ] Rust async book：[Async Programming in Rust](https://rust-lang.github.io/async-book/)

---

#### 知识检验题

1. **概念理解**：解释Promise和Future之间的关系。为什么标准库设计成Promise只能set一次值，Future只能get一次？这种设计有什么好处？

2. **实现分析**：SharedState中为什么需要引用计数？如果Promise和Future在不同线程，且销毁顺序不确定，会发生什么？

3. **异常处理**：描述异常从Promise传播到Future的完整流程。exception_ptr是什么？为什么需要它？

4. **设计权衡**：C++的future是eager执行的，而Rust的Future是lazy执行的。这两种设计各有什么优缺点？

5. **代码分析**：以下代码有什么问题？
```cpp
std::future<int> compute() {
    std::promise<int> p;
    auto f = p.get_future();
    std::thread([p = std::move(p)]() mutable {
        p.set_value(42);
    }).detach();
    return f;
}
```

---

### 第二周：std::async与任务启动策略

**学习目标**：
- 掌握std::async的完整语义和启动策略
- 理解std::packaged_task的设计和用途
- 分析async的内部实现和性能特征
- 学习任务取消的模式

**阅读材料**：
- [ ] 《C++ Concurrency in Action》第4章async部分
- [ ] CppCon 2017：[Sean Parent - Better Code: Concurrency](https://www.youtube.com/watch?v=zULU6Hhp42w)
- [ ] Scott Meyers - "Effective Modern C++" Item 35, 36

---

#### 核心概念：std::async深度解析

```cpp
#include <future>
#include <thread>
#include <iostream>
#include <chrono>
#include <vector>

// ==================== std::async 完整语义 ====================

void async_policies() {
    // 三种启动策略：

    // 1. std::launch::async - 必须在新线程执行
    auto f1 = std::async(std::launch::async, []() {
        std::cout << "Running in thread: "
                  << std::this_thread::get_id() << "\n";
        return 42;
    });
    // 保证：任务在独立线程执行
    // 特性：future析构会阻塞等待

    // 2. std::launch::deferred - 延迟到get()/wait()时执行
    auto f2 = std::async(std::launch::deferred, []() {
        std::cout << "Deferred execution in thread: "
                  << std::this_thread::get_id() << "\n";
        return 100;
    });
    // 特性：不创建新线程，在调用者线程执行
    // 用途：惰性求值

    // 3. std::launch::async | std::launch::deferred - 默认策略
    auto f3 = std::async([]() {  // 未指定策略等同于 async|deferred
        return 200;
    });
    // 由实现决定：可能新线程，可能延迟
    // 危险：行为不确定！
}

// ==================== 默认策略的陷阱 ====================

void default_policy_pitfalls() {
    // 陷阱1: wait_for可能永远返回deferred
    auto fut = std::async([]{ return 42; });  // 默认策略

    // 如果实现选择了deferred，这个循环会无限执行！
    while (fut.wait_for(std::chrono::seconds(0)) != std::future_status::ready) {
        std::cout << "Still waiting...\n";
        // 永远不会ready，因为deferred只在get()时执行
    }

    // 正确做法：显式检查deferred状态
    auto fut2 = std::async([]{ return 42; });
    if (fut2.wait_for(std::chrono::seconds(0)) == std::future_status::deferred) {
        // 处理deferred情况
        fut2.get();  // 触发执行
    } else {
        // 正常等待
        fut2.wait();
    }

    // 陷阱2: thread_local变量
    auto fut3 = std::async([]() {
        // 如果是deferred，thread_local在调用者线程
        // 如果是async，thread_local在新线程
        thread_local int tls = 0;
        return ++tls;
    });
    // 行为取决于实现！

    // 最佳实践：始终显式指定策略
    auto fut4 = std::async(std::launch::async, []{ return 42; });
}

// ==================== async返回的future的特殊行为 ====================

void async_future_destruction() {
    // std::async返回的future在析构时会阻塞等待任务完成！
    // 这与普通future不同

    {
        std::async(std::launch::async, []() {
            std::this_thread::sleep_for(std::chrono::seconds(5));
            std::cout << "Task done\n";
        });
        // future立即析构，但会阻塞5秒等待任务完成！
        std::cout << "After async call\n";  // 5秒后才打印
    }

    // 这个"特性"经常导致意外的同步行为
    // 解决方法1：保存future
    auto fut = std::async(std::launch::async, []() {
        std::this_thread::sleep_for(std::chrono::seconds(5));
    });
    std::cout << "Continuing immediately\n";
    // fut在作用域结束时才阻塞

    // 解决方法2：使用packaged_task + thread
}

// ==================== std::packaged_task ====================

void packaged_task_demo() {
    // packaged_task: 包装可调用对象，关联一个future
    // 与async的区别：不自动启动，需要手动调用

    std::packaged_task<int(int, int)> task([](int a, int b) {
        return a + b;
    });

    std::future<int> result = task.get_future();

    // 方式1：直接调用（同步）
    // task(10, 20);

    // 方式2：在新线程中调用
    std::thread t(std::move(task), 10, 20);

    std::cout << "Result: " << result.get() << "\n";
    t.join();

    // packaged_task的用途：
    // 1. 更精细地控制任务的启动时机
    // 2. 可以存储在容器中，稍后执行
    // 3. 实现任务队列、线程池
}

// ==================== 实现简单的任务队列 ====================

#include <queue>

class TaskQueue {
    std::queue<std::packaged_task<void()>> tasks_;
    std::mutex mutex_;
    std::condition_variable cv_;
    std::atomic<bool> stop_{false};
    std::thread worker_;

public:
    TaskQueue() : worker_([this]{ worker_loop(); }) {}

    ~TaskQueue() {
        stop_ = true;
        cv_.notify_all();
        if (worker_.joinable()) worker_.join();
    }

    template <typename F>
    std::future<void> submit(F&& f) {
        std::packaged_task<void()> task(std::forward<F>(f));
        auto fut = task.get_future();

        {
            std::lock_guard<std::mutex> lock(mutex_);
            tasks_.push(std::move(task));
        }
        cv_.notify_one();

        return fut;
    }

private:
    void worker_loop() {
        while (!stop_) {
            std::packaged_task<void()> task;
            {
                std::unique_lock<std::mutex> lock(mutex_);
                cv_.wait(lock, [this] {
                    return stop_ || !tasks_.empty();
                });
                if (stop_ && tasks_.empty()) return;
                task = std::move(tasks_.front());
                tasks_.pop();
            }
            task();
        }
    }
};
```

---

#### 📅 第二周每日详细计划

##### Day 1: std::async启动策略深度分析（5小时）

**上午（2小时）- 理论学习**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 文档阅读 | 阅读《C++ Concurrency in Action》async部分 |

**下午（3小时）- 实践与分析**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 策略对比 | 分析三种启动策略的实现差异 |
| 1:00-2:30 | 编码测试 | 编写测试程序验证各策略行为 |
| 2:30-3:00 | 总结 | 总结策略选择的最佳实践 |

**今日输出物**：
- [ ] 代码：`day1_async_policies.cpp`
- [ ] 笔记：三种启动策略对比分析

---

##### Day 2: async的陷阱与最佳实践（5小时）

**上午（2.5小时）- 陷阱分析**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 析构行为 | 学习async返回的future的特殊析构行为 |
| 1:30-2:30 | 默认策略 | 分析默认策略的不确定性问题 |

**下午（2.5小时）- 实践编码**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 示例代码 | 编写展示各种陷阱的示例代码 |
| 2:00-2:30 | 清单整理 | 整理避免陷阱的清单 |

**今日输出物**：
- [ ] 代码：`day2_async_pitfalls.cpp`
- [ ] 笔记：async陷阱与规避清单

---

##### Day 3: std::packaged_task详解（5小时）

**上午（2小时）- 理论学习**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 设计目的 | 理解packaged_task的设计目的 |
| 1:00-2:00 | 对比分析 | 分析packaged_task与async的区别 |

**下午（3小时）- 实践项目**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:30 | 任务队列 | 使用packaged_task实现任务队列 |
| 2:30-3:00 | 场景总结 | 总结packaged_task的适用场景 |

**今日输出物**：
- [ ] 代码：`task_queue.hpp` - 简单任务队列实现

---

##### Day 4: 异步任务的取消模式（5小时）

**上午（2.5小时）- 理论学习**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 取消模式 | 学习协作式取消的设计模式 |
| 1:30-2:30 | C++20特性 | 分析std::stop_token(C++20)的设计 |

**下午（2.5小时）- 实践编码**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 实现 | 实现支持取消的异步任务 |
| 2:00-2:30 | 权衡分析 | 对比不同取消策略的权衡 |

**核心代码：协作式取消模式**

```cpp
// ==================== 协作式取消模式 ====================

// 方法1：使用atomic<bool>标志
class CancellableTask {
    std::atomic<bool> cancelled_{false};
    std::thread worker_;
    std::future<int> result_;

public:
    void start() {
        std::promise<int> prom;
        result_ = prom.get_future();

        worker_ = std::thread([this, prom = std::move(prom)]() mutable {
            int sum = 0;
            for (int i = 0; i < 1000000; ++i) {
                if (cancelled_.load(std::memory_order_relaxed)) {
                    prom.set_exception(std::make_exception_ptr(
                        std::runtime_error("Task cancelled")));
                    return;
                }
                sum += i;
                // 模拟工作
                std::this_thread::sleep_for(std::chrono::microseconds(1));
            }
            prom.set_value(sum);
        });
    }

    void cancel() {
        cancelled_.store(true, std::memory_order_relaxed);
    }

    std::future<int>& get_future() { return result_; }

    ~CancellableTask() {
        cancel();
        if (worker_.joinable()) worker_.join();
    }
};

// 方法2：使用std::stop_token (C++20)
#if __cplusplus >= 202002L
#include <stop_token>

void stop_token_example() {
    std::jthread worker([](std::stop_token stoken) {
        while (!stoken.stop_requested()) {
            // 工作...
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
        }
        std::cout << "Stopped gracefully\n";
    });

    std::this_thread::sleep_for(std::chrono::seconds(1));
    worker.request_stop();  // 请求停止
    // jthread析构时自动join
}
#endif
```

**今日输出物**：
- [ ] 代码：`cancellable_task.hpp` - 支持取消的任务实现

---

##### Day 5: async内部实现分析（5小时）

**上午（2.5小时）- 源码阅读**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:30 | libstdc++分析 | 阅读libstdc++的async实现源码 |

**下午（2.5小时）- 分析与实现**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 策略分析 | 分析不同实现的线程创建策略 |
| 1:30-2:00 | 简化实现 | 实现简化版的my_async |
| 2:00-2:30 | 总结 | 总结实现细节 |

**今日输出物**：
- [ ] 代码：`my_async.hpp` - 简化版async实现
- [ ] 笔记：async内部实现分析

---

##### Day 6: 性能分析与基准测试（5小时）

**上午（2.5小时）- 基准测试**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:30 | 编写测试 | async vs thread vs packaged_task基准测试 |

**下午（2.5小时）- 分析与建议**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 开销分析 | 分析线程创建开销 |
| 1:30-2:00 | 粒度测试 | 测试不同任务粒度的最佳选择 |
| 2:00-2:30 | 整理数据 | 整理性能数据和建议 |

**核心代码：性能基准测试**

```cpp
// ==================== 性能基准测试 ====================

#include <chrono>
#include <numeric>

template <typename F>
auto benchmark(const char* name, int iterations, F&& f) {
    auto start = std::chrono::high_resolution_clock::now();

    for (int i = 0; i < iterations; ++i) {
        f();
    }

    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::microseconds>(
        end - start).count();

    std::cout << name << ": " << duration << " us total, "
              << duration / iterations << " us/op\n";
    return duration;
}

void performance_comparison() {
    const int iterations = 1000;
    auto task = []{ return 42; };

    // 测试1: std::async
    benchmark("std::async(async)", iterations, [&]() {
        auto f = std::async(std::launch::async, task);
        f.get();
    });

    // 测试2: std::async deferred
    benchmark("std::async(deferred)", iterations, [&]() {
        auto f = std::async(std::launch::deferred, task);
        f.get();
    });

    // 测试3: packaged_task + thread
    benchmark("packaged_task + thread", iterations, [&]() {
        std::packaged_task<int()> pt(task);
        auto f = pt.get_future();
        std::thread t(std::move(pt));
        f.get();
        t.join();
    });

    // 测试4: 直接调用（基准）
    benchmark("direct call", iterations, [&]() {
        volatile int result = task();
        (void)result;
    });
}

/*
典型结果（取决于系统）：
std::async(async):     50000 us total, 50 us/op
std::async(deferred):   1000 us total,  1 us/op
packaged_task+thread:  55000 us total, 55 us/op
direct call:             100 us total,  0 us/op

结论：
1. 线程创建开销约50微秒
2. deferred几乎没有额外开销
3. 对于微小任务，同步执行更好
4. 任务执行时间 >> 50us 时，async才有意义
*/
```

**今日输出物**：
- [ ] 代码：`benchmark_async.cpp` - 性能测试代码
- [ ] 笔记：性能分析报告

---

##### Day 7: 周总结与实战（5小时）

**上午（2.5小时）- 复习与实战**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 复习 | 回顾本周所有概念 |
| 1:00-2:30 | 实现 | 实现一个完整的异步任务调度器 |

**下午（2.5小时）- 测试与总结**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 测试 | 完成知识检验题 |
| 1:30-2:30 | 总结 | 撰写学习笔记 |

**今日输出物**：
- [ ] 代码：`async_scheduler.hpp` - 异步任务调度器
- [ ] 笔记：`notes/week2_async.md`

---

#### 扩展阅读资源

**必读（优先级：高）**
- [ ] Scott Meyers "Effective Modern C++" Item 35: Prefer task-based programming to thread-based
- [ ] Scott Meyers "Effective Modern C++" Item 36: Specify std::launch::async if asynchronicity is essential
- [ ] CppCon 2017：[Sean Parent - Better Code: Concurrency](https://www.youtube.com/watch?v=zULU6Hhp42w)

**推荐阅读（优先级：中）**
- [ ] 博客：[Anthony Williams - Prefer Futures to Bald Threads](https://www.justsoftwaresolutions.co.uk/threading/prefer-futures-to-bald-threads.html)
- [ ] 博客：[Herb Sutter - The Trouble with Future's Destructor](https://herbsutter.com/2012/06/06/futures-shared-futures-and-the-trouble-with-futures-destructor/)

**深入研究（优先级：低）**
- [ ] 论文：[N4107 - Technical Specification for C++ Extensions for Concurrency](https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2014/n4107.html)
- [ ] C++20 stop_token：[P0660R10](https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2019/p0660r10.pdf)

---

#### 知识检验题

1. **策略分析**：详细解释std::launch::async、std::launch::deferred和默认策略的区别。为什么默认策略可能导致问题？

2. **析构行为**：为什么std::async返回的future在析构时会阻塞？这与普通future有什么不同？这个设计决策的理由是什么？

3. **选择题**：在以下场景中，你会选择async、packaged_task还是直接thread？说明理由：
   - 火后即忘（fire-and-forget）任务
   - 需要精确控制执行时机的任务
   - 需要存储待执行任务的队列

4. **代码分析**：以下代码的输出是什么？为什么？
```cpp
void mystery() {
    for (int i = 0; i < 5; ++i) {
        std::async(std::launch::async, [i]() {
            std::cout << i << " ";
        });
    }
    std::cout << "done\n";
}
```

5. **实现题**：设计一个"真正的"fire-and-forget异步函数，不会因为future析构而阻塞。

---

### 第三周：shared_future与多消费者模式

**学习目标**：
- 掌握shared_future的语义和使用场景
- 理解多消费者等待同一结果的模式
- 学习广播机制的实现
- 分析共享状态的线程安全性

**阅读材料**：
- [ ] 《C++ Concurrency in Action》shared_future部分
- [ ] cppreference: std::shared_future完整文档
- [ ] CppCon 2018：[Gor Nishanov - Nano-coroutines to the Rescue!](https://www.youtube.com/watch?v=j9tlJAqMV7U)

---

#### 核心概念：shared_future详解

```cpp
#include <future>
#include <thread>
#include <vector>
#include <iostream>

// ==================== shared_future vs future ====================

/*
┌──────────────────────────┬──────────────────────────────────────┐
│ std::future              │ std::shared_future                   │
├──────────────────────────┼──────────────────────────────────────┤
│ move-only                │ copyable                             │
│ get()只能调用一次        │ get()可以多次调用                   │
│ 单一消费者              │ 多消费者                             │
│ get()移动或复制结果     │ get()返回const引用                  │
└──────────────────────────┴──────────────────────────────────────┘
*/

void shared_future_basics() {
    // 方法1：从future转换
    std::promise<int> prom;
    std::future<int> fut = prom.get_future();
    std::shared_future<int> sfut = fut.share();
    // fut现在invalid

    // 方法2：直接从async获取
    std::shared_future<int> sfut2 = std::async([]{ return 42; }).share();

    // 可以复制
    std::shared_future<int> sfut3 = sfut2;
    std::shared_future<int> sfut4 = sfut2;

    // 多次get
    prom.set_value(100);
    std::cout << sfut.get() << "\n";  // 100
    std::cout << sfut.get() << "\n";  // 100，再次获取
    std::cout << sfut3.get() << "\n"; // 100，从副本获取
}

// ==================== 多消费者模式 ====================

void multiple_consumers() {
    // 场景：多个线程等待同一个初始化结果
    std::promise<std::string> init_promise;
    std::shared_future<std::string> init_future = init_promise.get_future().share();

    // 启动多个消费者
    std::vector<std::thread> consumers;
    for (int i = 0; i < 5; ++i) {
        consumers.emplace_back([i, init_future]() {
            std::cout << "Worker " << i << " waiting...\n";
            const std::string& config = init_future.get();
            std::cout << "Worker " << i << " got config: " << config << "\n";
            // 使用config...
        });
    }

    // 模拟初始化
    std::this_thread::sleep_for(std::chrono::seconds(1));
    init_promise.set_value("Production Config v1.0");

    for (auto& t : consumers) {
        t.join();
    }
}

// ==================== 广播模式实现 ====================

template <typename T>
class Broadcaster {
    std::promise<T> promise_;
    std::shared_future<T> future_;

public:
    Broadcaster() : future_(promise_.get_future().share()) {}

    std::shared_future<T> get_listener() {
        return future_;  // 返回副本
    }

    void broadcast(T value) {
        promise_.set_value(std::move(value));
    }

    void broadcast_error(std::exception_ptr e) {
        promise_.set_exception(e);
    }
};

void broadcaster_demo() {
    Broadcaster<int> bc;

    // 创建多个监听者
    std::vector<std::thread> listeners;
    for (int i = 0; i < 3; ++i) {
        auto listener = bc.get_listener();
        listeners.emplace_back([i, listener]() {
            try {
                int value = listener.get();
                std::cout << "Listener " << i << " received: " << value << "\n";
            } catch (const std::exception& e) {
                std::cout << "Listener " << i << " error: " << e.what() << "\n";
            }
        });
    }

    // 广播值
    std::this_thread::sleep_for(std::chrono::milliseconds(100));
    bc.broadcast(42);

    for (auto& t : listeners) {
        t.join();
    }
}

// ==================== 线程安全性分析 ====================

/*
shared_future的线程安全保证：
1. 不同shared_future副本可以在不同线程并发访问
2. 同一个shared_future实例的并发访问需要外部同步
   （除了get()和valid()，它们是const成员函数）
3. SharedState内部是线程安全的

安全：
    std::shared_future<int> sf1 = ...;
    std::shared_future<int> sf2 = sf1;  // 复制
    // 线程1使用sf1，线程2使用sf2 - 安全

不安全：
    std::shared_future<int> sf = ...;
    // 线程1和线程2同时调用sf的非const方法 - 不安全
*/

// ==================== 引用语义注意事项 ====================

struct LargeData {
    std::array<int, 1000> data;
};

void reference_semantics() {
    std::promise<LargeData> prom;
    std::shared_future<LargeData> sfut = prom.get_future().share();

    LargeData large_data;
    std::fill(large_data.data.begin(), large_data.data.end(), 42);
    prom.set_value(large_data);

    // get()返回const引用，避免复制
    const LargeData& ref1 = sfut.get();  // 不复制
    const LargeData& ref2 = sfut.get();  // 同一个引用

    // 如果需要修改，必须复制
    LargeData copy = sfut.get();  // 复制
    copy.data[0] = 100;  // 可以修改副本

    // 对于void特化
    std::promise<void> void_prom;
    std::shared_future<void> void_sfut = void_prom.get_future().share();
    void_prom.set_value();
    void_sfut.get();  // 返回void
    void_sfut.get();  // 可以多次调用
}
```

---

#### 📅 第三周每日详细计划

##### Day 1: shared_future基础与转换（5小时）

**上午（2.5小时）**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 文档阅读 | 阅读cppreference shared_future文档 |
| 1:30-2:30 | 语义理解 | 理解share()操作的语义 |

**下午（2.5小时）**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 编码实践 | 编写shared_future基本用法示例 |
| 2:00-2:30 | 对比分析 | 对比future和shared_future |

**今日输出物**：
- [ ] 代码：`day1_shared_future_basics.cpp`
- [ ] 笔记：future vs shared_future对比表

---

##### Day 2: 多消费者等待模式（5小时）

**上午（1小时）**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 场景分析 | 分析多消费者场景的需求 |

**下午（4小时）**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:30 | 实现 | 实现Broadcaster类 |
| 2:30-3:30 | 测试 | 测试并发安全性 |
| 3:30-4:00 | 总结 | 整理多消费者模式的最佳实践 |

**今日输出物**：
- [ ] 代码：`broadcaster.hpp` - 广播器实现

---

##### Day 3: 线程安全性深度分析（5小时）

**上午（2.5小时）**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 安全保证 | 分析shared_future的线程安全保证 |
| 1:30-2:30 | 实例vs副本 | 理解"同一实例"vs"不同副本"的区别 |

**下午（2.5小时）**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 并发测试 | 编写并发测试验证安全性 |
| 2:00-2:30 | 模式总结 | 总结正确使用模式 |

**今日输出物**：
- [ ] 代码：`thread_safety_test.cpp`
- [ ] 笔记：shared_future线程安全性分析

---

##### Day 4: 引用语义与性能考量（5小时）

**上午（2小时）**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | const引用 | 分析get()返回const引用的设计 |
| 1:00-2:00 | 性能影响 | 理解大对象传递的性能影响 |

**下午（3小时）**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 基准测试 | 基准测试shared_future的开销 |
| 2:00-3:00 | 最佳实践 | 总结性能最佳实践 |

**今日输出物**：
- [ ] 代码：`benchmark_shared_future.cpp`
- [ ] 笔记：shared_future性能分析

---

##### Day 5: 一次性初始化模式（5小时）

**上午（2.5小时）**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 模式学习 | 学习call_once + shared_future的组合 |
| 1:30-2:30 | 单例实现 | 实现线程安全的单例初始化 |

**下午（2.5小时）**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 惰性初始化 | 实现配置加载的惰性初始化 |
| 1:30-2:30 | 策略对比 | 对比不同初始化策略 |

**核心代码：惰性初始化模式**

```cpp
// ==================== 惰性初始化模式 ====================

class LazyConfig {
    mutable std::once_flag init_flag_;
    mutable std::shared_future<std::string> config_future_;

    static std::string load_config() {
        // 模拟耗时的配置加载
        std::this_thread::sleep_for(std::chrono::seconds(1));
        return "Loaded Configuration";
    }

public:
    const std::string& get_config() const {
        std::call_once(init_flag_, [this]() {
            std::promise<std::string> prom;
            config_future_ = prom.get_future().share();
            // 异步加载
            std::thread([prom = std::move(prom)]() mutable {
                try {
                    prom.set_value(load_config());
                } catch (...) {
                    prom.set_exception(std::current_exception());
                }
            }).detach();
        });
        return config_future_.get();
    }
};

// ==================== 资源池初始化 ====================

template <typename T>
class ResourcePool {
    std::shared_future<std::vector<T>> pool_future_;

public:
    template <typename Factory>
    ResourcePool(size_t size, Factory factory) {
        std::promise<std::vector<T>> prom;
        pool_future_ = prom.get_future().share();

        std::thread([size, factory, prom = std::move(prom)]() mutable {
            std::vector<T> pool;
            pool.reserve(size);
            for (size_t i = 0; i < size; ++i) {
                pool.push_back(factory(i));
            }
            prom.set_value(std::move(pool));
        }).detach();
    }

    const T& get(size_t index) const {
        const auto& pool = pool_future_.get();
        return pool[index % pool.size()];
    }
};
```

**今日输出物**：
- [ ] 代码：`lazy_init.hpp` - 惰性初始化实现

---

##### Day 6: 实际应用案例研究（5小时）

**上午（2小时）**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 源码研究 | 研究folly/Facebook的SharedPromise实现 |

**下午（3小时）**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 增强实现 | 实现增强版SharedPromise |
| 2:00-2:30 | 应用示例 | 编写真实场景的应用示例 |
| 2:30-3:00 | 特点总结 | 总结工业级实现的特点 |

**今日输出物**：
- [ ] 代码：`shared_promise.hpp` - 增强版SharedPromise

---

##### Day 7: 周总结与实战（5小时）

**上午（2小时）**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 复习 | 回顾本周所有概念 |
| 1:00-2:00 | 检验 | 完成知识检验题 |

**下午（3小时）**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:30 | 完善 | 完成Broadcaster的完整实现和测试 |
| 2:30-3:00 | 总结 | 撰写学习笔记 |

**今日输出物**：
- [ ] 代码：完整的Broadcaster测试套件
- [ ] 笔记：`notes/week3_shared_future.md`

---

#### 扩展阅读资源

**必读（优先级：高）**
- [ ] folly源码：[SharedPromise](https://github.com/facebook/folly/blob/main/folly/futures/SharedPromise.h)
- [ ] cppreference：[std::shared_future](https://en.cppreference.com/w/cpp/thread/shared_future)

**推荐阅读（优先级：中）**
- [ ] 博客：[Bartosz Milewski - Promise, Future, and Threads](https://bartoszmilewski.com/2014/08/05/promise-future-threads/)
- [ ] CppCon 2015：[David Schwartz - Designing Lock-Free Data Structures](https://www.youtube.com/watch?v=CmxkPChOcvw)

---

#### 知识检验题

1. **概念辨析**：future::get()和shared_future::get()在语义上有什么根本区别？为什么shared_future::get()返回const引用？

2. **线程安全**：以下代码是否线程安全？为什么？
```cpp
std::shared_future<int> sf = get_shared_future();
std::thread t1([&sf]{ sf.get(); });
std::thread t2([&sf]{ sf.get(); });
```

3. **设计题**：设计一个支持多个生产者通知同一批消费者的系统。（提示：考虑如何处理多次set_value）

4. **性能分析**：在高频访问场景下，使用shared_future缓存计算结果与每次重新计算相比，需要考虑哪些因素？

---

### 第四周：组合器模式与高级应用

**学习目标**：
- 实现then、when_all、when_any组合器
- 学习Continuation-Passing Style (CPS)
- 探索与C++20协程的关系
- 完成综合实践项目

**阅读材料**：
- [ ] 论文：[N4538 - A Unified Executors Proposal for C++](https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2016/n4538.pdf)
- [ ] CppCon 2019：[Eric Niebler - Structured Concurrency](https://www.youtube.com/watch?v=1Wy5sq3s2rg)
- [ ] folly::Future源码

---

#### 核心概念：组合器模式实现

```cpp
#include <future>
#include <tuple>
#include <vector>
#include <variant>
#include <algorithm>

// ==================== then组合器 ====================

template <typename T>
class ExtendedFuture {
    std::future<T> inner_;

public:
    explicit ExtendedFuture(std::future<T>&& f) : inner_(std::move(f)) {}

    // then: 在结果就绪后执行回调
    template <typename F>
    auto then(F&& func) -> ExtendedFuture<std::invoke_result_t<F, T>> {
        using R = std::invoke_result_t<F, T>;

        std::promise<R> prom;
        auto fut = prom.get_future();

        std::thread([inner = std::move(inner_),
                     func = std::forward<F>(func),
                     prom = std::move(prom)]() mutable {
            try {
                if constexpr (std::is_void_v<T>) {
                    inner.get();
                    if constexpr (std::is_void_v<R>) {
                        func();
                        prom.set_value();
                    } else {
                        prom.set_value(func());
                    }
                } else {
                    if constexpr (std::is_void_v<R>) {
                        func(inner.get());
                        prom.set_value();
                    } else {
                        prom.set_value(func(inner.get()));
                    }
                }
            } catch (...) {
                prom.set_exception(std::current_exception());
            }
        }).detach();

        return ExtendedFuture<R>(std::move(fut));
    }

    T get() { return inner_.get(); }
    bool valid() const { return inner_.valid(); }
};

// ==================== when_all组合器 ====================

template <typename... Futures>
auto when_all(Futures&&... futures)
    -> std::future<std::tuple<typename std::decay_t<Futures>::value_type...>> {

    using ResultTuple = std::tuple<typename std::decay_t<Futures>::value_type...>;

    std::promise<ResultTuple> prom;
    auto result_future = prom.get_future();

    std::thread([prom = std::move(prom),
                 futures = std::make_tuple(std::forward<Futures>(futures)...)]() mutable {
        try {
            auto results = std::apply([](auto&&... fs) {
                return std::make_tuple(fs.get()...);
            }, std::move(futures));
            prom.set_value(std::move(results));
        } catch (...) {
            prom.set_exception(std::current_exception());
        }
    }).detach();

    return result_future;
}

// vector版本的when_all
template <typename T>
std::future<std::vector<T>> when_all_vec(std::vector<std::future<T>>& futures) {
    std::promise<std::vector<T>> prom;
    auto result_future = prom.get_future();

    std::thread([prom = std::move(prom),
                 futures = std::move(futures)]() mutable {
        std::vector<T> results;
        results.reserve(futures.size());
        try {
            for (auto& f : futures) {
                results.push_back(f.get());
            }
            prom.set_value(std::move(results));
        } catch (...) {
            prom.set_exception(std::current_exception());
        }
    }).detach();

    return result_future;
}

// ==================== when_any组合器 ====================

template <typename T>
struct WhenAnyResult {
    size_t index;
    T value;
};

template <typename T>
std::future<WhenAnyResult<T>> when_any(std::vector<std::future<T>>& futures) {
    std::promise<WhenAnyResult<T>> prom;
    auto result_future = prom.get_future();

    // 使用shared_ptr管理promise，因为多个线程可能竞争
    auto shared_prom = std::make_shared<std::promise<WhenAnyResult<T>>>(std::move(prom));
    auto done = std::make_shared<std::atomic<bool>>(false);

    for (size_t i = 0; i < futures.size(); ++i) {
        std::thread([shared_prom, done, i,
                     f = std::move(futures[i])]() mutable {
            try {
                T result = f.get();
                bool expected = false;
                if (done->compare_exchange_strong(expected, true)) {
                    shared_prom->set_value(WhenAnyResult<T>{i, std::move(result)});
                }
            } catch (...) {
                // 忽略非首个完成的异常
                // 实际实现可能需要更复杂的错误处理
            }
        }).detach();
    }

    return result_future;
}

// ==================== 使用示例 ====================

void combinator_demo() {
    // then链式调用
    auto result = ExtendedFuture<int>(std::async([]{ return 10; }))
        .then([](int x) { return x * 2; })
        .then([](int x) { return x + 5; })
        .then([](int x) { return std::to_string(x); })
        .get();
    std::cout << "then result: " << result << "\n";

    // when_all
    auto f1 = std::async([]{ return 1; });
    auto f2 = std::async([]{ return 2; });
    auto f3 = std::async([]{ return 3; });
    auto [a, b, c] = when_all(std::move(f1), std::move(f2), std::move(f3)).get();
    std::cout << "when_all: " << a << ", " << b << ", " << c << "\n";

    // when_any
    std::vector<std::future<int>> futures;
    for (int i = 0; i < 5; ++i) {
        futures.push_back(std::async([i]() {
            std::this_thread::sleep_for(std::chrono::milliseconds(100 * (5 - i)));
            return i;
        }));
    }
    auto any_result = when_any(futures).get();
    std::cout << "when_any: index=" << any_result.index
              << ", value=" << any_result.value << "\n";
}
```

---

#### 📅 第四周每日详细计划

##### Day 1: then组合器实现（5小时）

**上午（2.5小时）**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | CPS学习 | 学习Continuation-Passing Style概念 |
| 1:30-2:30 | 设计分析 | 分析then的设计目标和实现策略 |

**下午（2.5小时）**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 实现 | 实现基础版then组合器 |
| 2:00-2:30 | 特化处理 | 处理void特化和异常传播 |

**今日输出物**：
- [ ] 代码：`then_combinator.hpp`
- [ ] 笔记：CPS概念总结

---

##### Day 2: when_all组合器实现（5小时）

**上午（1小时）**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 语义分析 | 分析when_all的语义和实现策略 |

**下午（4小时）**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | tuple版本 | 实现tuple版本的when_all |
| 2:00-3:30 | vector版本 | 实现vector版本的when_all |
| 3:30-4:00 | 安全测试 | 测试并发安全性 |

**今日输出物**：
- [ ] 代码：`when_all.hpp`

---

##### Day 3: when_any组合器实现（5小时）

**上午（1.5小时）**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 竞争条件 | 分析when_any的竞争条件处理 |

**下午（3.5小时）**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:30 | 实现 | 实现线程安全的when_any |
| 2:30-3:00 | 异常处理 | 处理异常和取消逻辑 |
| 3:00-3:30 | 策略对比 | 对比不同实现策略 |

**今日输出物**：
- [ ] 代码：`when_any.hpp`

---

##### Day 4: 与协程的关系（5小时）

**上午（3.5小时）**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 协程基础 | 学习C++20协程基础概念 |
| 2:00-3:30 | 对应关系 | 理解Future与协程的对应关系 |

**下午（1.5小时）**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 适配实现 | 编写简单的协程future适配 |
| 1:00-1:30 | 范式对比 | 对比回调、Future、协程三种范式 |

**核心代码：Future与协程的关系**

```cpp
// ==================== Future与协程的关系 ====================

/*
三种异步范式的演进：

1. 回调地狱 (Callback Hell)
   asyncOp1([](Result1 r1) {
       asyncOp2(r1, [](Result2 r2) {
           asyncOp3(r2, [](Result3 r3) {
               // 嵌套越来越深...
           });
       });
   });

2. Future/Promise + then
   asyncOp1()
       .then([](Result1 r1) { return asyncOp2(r1); })
       .then([](Result2 r2) { return asyncOp3(r2); })
       .then([](Result3 r3) { /* ... */ });

3. 协程 (async/await)
   auto r1 = co_await asyncOp1();
   auto r2 = co_await asyncOp2(r1);
   auto r3 = co_await asyncOp3(r2);
   // 看起来像同步代码！

演进的核心：控制流反转 -> 正常控制流
*/

// C++20协程与future的简单适配
#if __cplusplus >= 202002L
#include <coroutine>

template <typename T>
struct FutureAwaiter {
    std::future<T>& fut;

    bool await_ready() {
        return fut.wait_for(std::chrono::seconds(0)) == std::future_status::ready;
    }

    void await_suspend(std::coroutine_handle<> h) {
        // 在新线程中等待，完成后恢复协程
        std::thread([this, h]() {
            fut.wait();
            h.resume();
        }).detach();
    }

    T await_resume() {
        return fut.get();
    }
};

// 使协程可以 co_await std::future
template <typename T>
FutureAwaiter<T> operator co_await(std::future<T>&& f) {
    return FutureAwaiter<T>{f};
}
#endif
```

**今日输出物**：
- [ ] 代码：`coroutine_adapter.hpp`
- [ ] 笔记：异步范式演进对比

---

##### Day 5: 超时与异常处理（5小时）

**上午（1小时）**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 超时设计 | 学习超时模式的设计 |

**下午（4小时）**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 超时实现 | 实现带超时的when_any |
| 2:00-3:30 | 异常收集 | 实现异常收集的when_all |
| 3:30-4:00 | 最佳实践 | 总结错误处理最佳实践 |

**核心代码：超时与异常处理**

```cpp
// ==================== 超时处理 ====================

template <typename T>
std::future<std::optional<T>> with_timeout(std::future<T>&& fut,
                                           std::chrono::milliseconds timeout) {
    std::promise<std::optional<T>> prom;
    auto result = prom.get_future();

    std::thread([fut = std::move(fut),
                 prom = std::move(prom),
                 timeout]() mutable {
        if (fut.wait_for(timeout) == std::future_status::ready) {
            try {
                prom.set_value(fut.get());
            } catch (...) {
                prom.set_exception(std::current_exception());
            }
        } else {
            prom.set_value(std::nullopt);  // 超时
        }
    }).detach();

    return result;
}

// ==================== 异常收集的when_all ====================

template <typename T>
struct AllSettledResult {
    std::vector<std::variant<T, std::exception_ptr>> results;
};

template <typename T>
std::future<AllSettledResult<T>> when_all_settled(std::vector<std::future<T>>& futures) {
    std::promise<AllSettledResult<T>> prom;
    auto result_future = prom.get_future();

    std::thread([prom = std::move(prom),
                 futures = std::move(futures)]() mutable {
        AllSettledResult<T> result;
        result.results.reserve(futures.size());

        for (auto& f : futures) {
            try {
                result.results.push_back(f.get());
            } catch (...) {
                result.results.push_back(std::current_exception());
            }
        }
        prom.set_value(std::move(result));
    }).detach();

    return result_future;
}
```

**今日输出物**：
- [ ] 代码：`timeout.hpp`
- [ ] 代码：`when_all_settled.hpp`

---

##### Day 6: folly::Future源码研究（5小时）

**上午（3.5小时）**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 整体架构 | 阅读folly::Future的整体架构 |
| 2:00-3:00 | then分析 | 分析folly的then实现 |
| 3:00-3:30 | executor | 学习folly的executor集成 |

**下午（1.5小时）**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 特点总结 | 总结工业级实现的特点 |

**核心内容：folly::Future概念**

```cpp
// ==================== folly::Future核心概念 ====================

/*
folly::Future的设计特点：

1. Executor支持
   - 可以指定回调在哪个executor执行
   - 支持线程池、IO线程等

2. 丰富的组合器
   - then/thenValue/thenTry
   - onError/onTimeout
   - via (切换executor)

3. 值语义改进
   - Try<T> 封装值或异常
   - SemiFuture (没有executor的future)

4. 性能优化
   - inline executor避免线程切换
   - 小对象优化

示例（folly风格）：
    folly::makeFuture(42)
        .via(&executor)
        .thenValue([](int x) { return x * 2; })
        .thenTry([](folly::Try<int> t) {
            if (t.hasException()) {
                return 0;
            }
            return t.value();
        })
        .get();
*/
```

**今日输出物**：
- [ ] 笔记：folly::Future源码分析

---

##### Day 7: 综合项目与总结（5小时）

**上午（3小时）**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-3:00 | 项目完成 | 实现完整的增强Future库 |

**下午（2小时）**
| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 测试 | 编写综合测试套件 |
| 1:00-2:00 | 总结 | 撰写本月学习总结 |

**今日输出物**：
- [ ] 代码：`combinators.hpp` - 完整组合器库
- [ ] 笔记：`notes/week4_combinators.md`
- [ ] 笔记：`notes/month18_futures.md` - 月度总结

---

#### 扩展阅读资源

**必读（优先级：高）**
- [ ] folly源码：[folly/futures](https://github.com/facebook/folly/tree/main/folly/futures)
- [ ] boost::future源码：[boost/thread/future.hpp](https://www.boost.org/doc/libs/1_82_0/doc/html/thread/synchronization.html#thread.synchronization.futures)
- [ ] CppCon 2019：[Eric Niebler - Structured Concurrency](https://www.youtube.com/watch?v=1Wy5sq3s2rg)

**推荐阅读（优先级：中）**
- [ ] 论文：[N4538 - A Unified Executors Proposal](https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2016/n4538.pdf)
- [ ] 博客：[Lewis Baker - Understanding the C++ coroutines](https://lewissbaker.github.io/)
- [ ] JavaScript Promise/A+ 规范

**深入研究（优先级：低）**
- [ ] Rust tokio源码：[tokio](https://github.com/tokio-rs/tokio)
- [ ] 论文：[Structured Asynchrony with Algebraic Effects](https://www.microsoft.com/en-us/research/publication/structured-asynchrony-with-algebraic-effects/)

---

#### 知识检验题

1. **CPS理解**：解释什么是Continuation-Passing Style。then组合器如何体现CPS？

2. **实现分析**：when_any的实现需要处理哪些并发问题？如何保证只有第一个完成的结果被设置？

3. **设计权衡**：when_all失败时应该如何处理？立即失败还是等所有完成？各有什么优缺点？

4. **协程对比**：相比Future+then链，协程（co_await）有什么优势？有什么劣势？

5. **架构设计**：如果要实现一个支持取消的when_all，应该如何设计？

---

## 实践项目

### 项目：完整的增强Future库

#### Part 1: mini_future核心实现

（见第一周Day 5的完整代码）

#### Part 2: 组合器实现

```cpp
// combinators.hpp
#pragma once
#include "mini_future.hpp"
#include <tuple>
#include <vector>
#include <variant>

namespace mini {

// ==================== then 组合器 ====================
template <typename T>
class extended_future {
    future<T> inner_;

public:
    explicit extended_future(future<T>&& f) : inner_(std::move(f)) {}

    template <typename F>
    auto then(F&& func) -> extended_future<std::invoke_result_t<F, T>> {
        using R = std::invoke_result_t<F, T>;

        promise<R> prom;
        auto fut = prom.get_future();

        std::thread([inner = std::move(inner_),
                     func = std::forward<F>(func),
                     prom = std::move(prom)]() mutable {
            try {
                if constexpr (std::is_void_v<T>) {
                    inner.get();
                    if constexpr (std::is_void_v<R>) {
                        func();
                        prom.set_value();
                    } else {
                        prom.set_value(func());
                    }
                } else {
                    if constexpr (std::is_void_v<R>) {
                        func(inner.get());
                        prom.set_value();
                    } else {
                        prom.set_value(func(inner.get()));
                    }
                }
            } catch (...) {
                prom.set_exception(std::current_exception());
            }
        }).detach();

        return extended_future<R>(std::move(fut));
    }

    // 错误处理
    template <typename F>
    extended_future<T> on_error(F&& handler) {
        promise<T> prom;
        auto fut = prom.get_future();

        std::thread([inner = std::move(inner_),
                     handler = std::forward<F>(handler),
                     prom = std::move(prom)]() mutable {
            try {
                prom.set_value(inner.get());
            } catch (...) {
                try {
                    if constexpr (std::is_invocable_r_v<T, F, std::exception_ptr>) {
                        prom.set_value(handler(std::current_exception()));
                    } else {
                        handler(std::current_exception());
                        prom.set_exception(std::current_exception());
                    }
                } catch (...) {
                    prom.set_exception(std::current_exception());
                }
            }
        }).detach();

        return extended_future<T>(std::move(fut));
    }

    T get() { return inner_.get(); }
    bool valid() const { return inner_.valid(); }
};

// ==================== make_ready_future ====================
template <typename T>
future<std::decay_t<T>> make_ready_future(T&& value) {
    promise<std::decay_t<T>> prom;
    prom.set_value(std::forward<T>(value));
    return prom.get_future();
}

inline future<void> make_ready_future() {
    promise<void> prom;
    prom.set_value();
    return prom.get_future();
}

// ==================== make_exceptional_future ====================
template <typename T>
future<T> make_exceptional_future(std::exception_ptr e) {
    promise<T> prom;
    prom.set_exception(e);
    return prom.get_future();
}

template <typename T, typename E>
future<T> make_exceptional_future(E&& exception) {
    return make_exceptional_future<T>(
        std::make_exception_ptr(std::forward<E>(exception)));
}

} // namespace mini
```

#### Part 3: 并行算法工具库

```cpp
// parallel.hpp
#pragma once
#include <future>
#include <vector>
#include <algorithm>
#include <numeric>
#include <thread>

namespace parallel {

// ==================== 并行map ====================
template <typename InputIt, typename OutputIt, typename F>
void transform(InputIt first, InputIt last, OutputIt out, F func,
               size_t num_threads = std::thread::hardware_concurrency()) {
    size_t size = std::distance(first, last);
    if (size == 0) return;

    size_t chunk_size = (size + num_threads - 1) / num_threads;
    std::vector<std::future<void>> futures;

    for (size_t i = 0; i < num_threads && i * chunk_size < size; ++i) {
        size_t start = i * chunk_size;
        size_t end = std::min(start + chunk_size, size);

        futures.push_back(std::async(std::launch::async,
            [=, &func] {
                std::transform(first + start, first + end, out + start, func);
            }));
    }

    for (auto& f : futures) {
        f.get();
    }
}

// ==================== 并行reduce ====================
template <typename InputIt, typename T, typename BinaryOp>
T reduce(InputIt first, InputIt last, T init, BinaryOp op,
         size_t num_threads = std::thread::hardware_concurrency()) {
    size_t size = std::distance(first, last);
    if (size == 0) return init;

    size_t chunk_size = (size + num_threads - 1) / num_threads;
    std::vector<std::future<T>> futures;

    for (size_t i = 0; i < num_threads && i * chunk_size < size; ++i) {
        size_t start = i * chunk_size;
        size_t end = std::min(start + chunk_size, size);

        futures.push_back(std::async(std::launch::async,
            [=, &op] {
                return std::accumulate(first + start, first + end, T{}, op);
            }));
    }

    T result = init;
    for (auto& f : futures) {
        result = op(result, f.get());
    }
    return result;
}

// ==================== 并行for_each ====================
template <typename InputIt, typename F>
void for_each(InputIt first, InputIt last, F func,
              size_t num_threads = std::thread::hardware_concurrency()) {
    size_t size = std::distance(first, last);
    if (size == 0) return;

    size_t chunk_size = (size + num_threads - 1) / num_threads;
    std::vector<std::future<void>> futures;

    for (size_t i = 0; i < num_threads && i * chunk_size < size; ++i) {
        size_t start = i * chunk_size;
        size_t end = std::min(start + chunk_size, size);

        futures.push_back(std::async(std::launch::async,
            [=, &func] {
                std::for_each(first + start, first + end, func);
            }));
    }

    for (auto& f : futures) {
        f.get();
    }
}

// ==================== 并行find_if ====================
template <typename InputIt, typename Predicate>
InputIt find_if(InputIt first, InputIt last, Predicate pred,
                size_t num_threads = std::thread::hardware_concurrency()) {
    size_t size = std::distance(first, last);
    if (size == 0) return last;

    std::atomic<bool> found{false};

    size_t chunk_size = (size + num_threads - 1) / num_threads;
    std::vector<std::future<InputIt>> futures;

    for (size_t i = 0; i < num_threads && i * chunk_size < size; ++i) {
        size_t start = i * chunk_size;
        size_t end = std::min(start + chunk_size, size);

        futures.push_back(std::async(std::launch::async,
            [=, &found, &pred]() -> InputIt {
                for (auto it = first + start; it != first + end && !found.load(); ++it) {
                    if (pred(*it)) {
                        found.store(true);
                        return it;
                    }
                }
                return last;
            }));
    }

    // 找到最早的结果
    InputIt earliest = last;
    for (auto& f : futures) {
        InputIt result = f.get();
        if (result != last && (earliest == last || result < earliest)) {
            earliest = result;
        }
    }
    return earliest;
}

// ==================== when_all: 等待所有future完成 ====================
template <typename... Futures>
auto when_all(Futures&&... futures) {
    return std::make_tuple(std::forward<Futures>(futures).get()...);
}

// ==================== when_any: 等待任一future完成 ====================
template <typename T>
std::pair<size_t, T> when_any(std::vector<std::future<T>>& futures) {
    while (true) {
        for (size_t i = 0; i < futures.size(); ++i) {
            if (futures[i].wait_for(std::chrono::milliseconds(1))
                    == std::future_status::ready) {
                return {i, futures[i].get()};
            }
        }
    }
}

} // namespace parallel
```

---

## 检验标准

### 知识检验
- [ ] future和promise的关系是什么？共享状态如何管理生命周期？
- [ ] std::async的启动策略有哪些？默认策略有什么陷阱？
- [ ] shared_future的用途是什么？与future有什么区别？
- [ ] 如何在future中传播异常？exception_ptr的作用是什么？
- [ ] then/when_all/when_any的语义是什么？如何实现？

### 实践检验
- [ ] mini_future正确实现了阻塞等待和异常传播
- [ ] then方法实现了链式调用
- [ ] when_all/when_any正确处理并发
- [ ] 并行算法能正确利用多核

### 输出物
1. `mini_future.hpp` - 完整的Future/Promise实现
2. `combinators.hpp` - then/when_all/when_any组合器
3. `parallel.hpp` - 并行算法工具库
4. `test_futures.cpp` - 完整测试套件
5. `benchmark_futures.cpp` - 性能基准测试
6. `notes/month18_futures.md` - 学习笔记

---

## 时间分配（140小时/月）

| 内容 | 时间 | 占比 |
|------|------|------|
| 理论学习 | 35小时 | 25% |
| 源码阅读 | 25小时 | 18% |
| mini_future实现 | 30小时 | 21% |
| 组合器实现 | 25小时 | 18% |
| 并行算法实现 | 15小时 | 11% |
| 测试与文档 | 10小时 | 7% |

---

## 本月核心收获

1. **深入理解Future/Promise模型**：掌握共享状态、引用计数、异常传播的内部机制
2. **掌握std::async**：理解启动策略、陷阱和最佳实践
3. **学会shared_future**：多消费者模式、广播机制
4. **实现组合器**：then/when_all/when_any，理解CPS风格
5. **跨语言视野**：对比JavaScript Promise、Rust Future的设计
6. **为线程池做准备**：理解任务抽象，为Month 19的线程池设计打下基础

---

## 下月预告

Month 19将学习**线程池设计与实现**，探索工作窃取、任务优先级、动态扩缩容等高级特性。本月学习的Future/Promise将作为线程池任务提交的返回类型被大量使用。
