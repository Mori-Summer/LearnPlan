# Month 19: 线程池设计与实现——高效任务调度

## 本月主题概述

线程池是管理并发任务的核心组件，也是现代高性能系统的基础设施。本月将从基础架构开始，逐步深入到工作窃取、任务优先级、动态扩缩容等高级特性，最终实现一个生产级的线程池。

**为什么线程池如此重要？**
- 避免频繁创建/销毁线程的开销（线程创建通常需要数十微秒）
- 控制系统资源使用，防止线程爆炸
- 提供统一的任务调度和管理接口
- 是异步编程、并行计算、服务器架构的基础

---

## 学习目标与验收标准

| 目标编号 | 学习目标 | 验收标准 |
|---------|---------|---------|
| W1-G1 | 理解线程池核心组件 | 能独立设计任务队列、工作线程、提交接口 |
| W1-G2 | 掌握任务结果获取 | 正确使用 future/promise/packaged_task |
| W1-G3 | 实现优雅关闭 | 能处理关闭时的任务清理和线程回收 |
| W2-G1 | 理解工作窃取原理 | 能解释为什么工作窃取能提高负载均衡 |
| W2-G2 | 实现无锁工作窃取队列 | 正确实现 Chase-Lev deque |
| W2-G3 | 掌握 Fork/Join 模式 | 能用工作窃取实现递归并行算法 |
| W3-G1 | 实现优先级调度 | 支持多种优先级策略 |
| W3-G2 | 实现任务依赖图 | 正确处理 DAG 形式的任务依赖 |
| W3-G3 | 实现延迟任务 | 支持定时执行和周期执行 |
| W4-G1 | 实现动态扩缩容 | 根据负载自动调整线程数 |
| W4-G2 | 掌握监控与调优 | 能收集和分析线程池性能指标 |
| W4-G3 | 了解生产级实践 | 理解主流线程池实现的设计权衡 |

---

## 理论学习内容

### 第一周：线程池基础架构

**学习目标**：掌握线程池的核心组件设计，实现一个功能完整的基础线程池

**阅读材料**：
- [ ] 《C++ Concurrency in Action》第9章
- [ ] CppCon 2015: "C++ Multithreading" by Fedor Pikus
- [ ] 博客：Anthony Williams "Implementing a Thread-Safe Queue"
- [ ] 论文：Herb Sutter "The Free Lunch Is Over"

---

#### 📅 Day 1-2: 线程池核心组件设计（10小时）

**Day 1 上午（2.5小时）- 架构设计**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 需求分析 | 列出线程池需要支持的功能：提交任务、获取结果、关闭等 |
| 1:00-2:00 | 组件识别 | 理解四大核心组件：任务队列、工作线程、提交接口、生命周期管理 |
| 2:00-2:30 | 接口设计 | 设计 ThreadPool 的公共接口 |

**Day 1 下午（2.5小时）- 任务队列实现**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 线程安全队列 | 实现基于 mutex + condition_variable 的任务队列 |
| 1:30-2:30 | 测试验证 | 编写多线程队列测试 |

**核心概念：线程池架构图**
```
┌─────────────────────────────────────────────────────────────┐
│                        ThreadPool                            │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌─────────────────────────────────────┐ │
│  │   Client    │    │           Task Queue                 │ │
│  │  (submit)   │───▶│  [Task1] [Task2] [Task3] ...        │ │
│  └─────────────┘    └──────────────┬──────────────────────┘ │
│                                    │                         │
│         ┌──────────────────────────┼──────────────────────┐ │
│         ▼                          ▼                      ▼ │
│  ┌────────────┐            ┌────────────┐          ┌────────┐│
│  │  Worker 1  │            │  Worker 2  │   ...    │Worker N││
│  │  (thread)  │            │  (thread)  │          │(thread)││
│  └────────────┘            └────────────┘          └────────┘│
└─────────────────────────────────────────────────────────────┘
```

**动手实验 1-1：线程安全任务队列**
```cpp
// thread_safe_queue.hpp
#pragma once
#include <queue>
#include <mutex>
#include <condition_variable>
#include <optional>

template <typename T>
class ThreadSafeQueue {
    std::queue<T> queue_;
    mutable std::mutex mutex_;
    std::condition_variable cv_;
    bool stopped_ = false;

public:
    // 添加任务
    void push(T item) {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            if (stopped_) {
                throw std::runtime_error("Queue is stopped");
            }
            queue_.push(std::move(item));
        }
        cv_.notify_one();
    }

    // 阻塞获取任务
    std::optional<T> pop() {
        std::unique_lock<std::mutex> lock(mutex_);
        cv_.wait(lock, [this] {
            return !queue_.empty() || stopped_;
        });

        if (queue_.empty()) {
            return std::nullopt;  // 队列已停止且为空
        }

        T item = std::move(queue_.front());
        queue_.pop();
        return item;
    }

    // 非阻塞尝试获取
    std::optional<T> try_pop() {
        std::lock_guard<std::mutex> lock(mutex_);
        if (queue_.empty()) {
            return std::nullopt;
        }
        T item = std::move(queue_.front());
        queue_.pop();
        return item;
    }

    // 停止队列
    void stop() {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            stopped_ = true;
        }
        cv_.notify_all();
    }

    bool empty() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return queue_.empty();
    }

    size_t size() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return queue_.size();
    }
};
```

**Day 2 上午（2.5小时）- 工作线程实现**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 工作线程循环 | 实现从队列取任务并执行的循环 |
| 1:30-2:30 | 异常处理 | 确保任务异常不会终止工作线程 |

**Day 2 下午（2.5小时）- 基础线程池整合**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 完整实现 | 整合队列和工作线程，实现基础线程池 |
| 2:00-2:30 | 基础测试 | 验证基本的任务提交和执行 |

**动手实验 1-2：基础线程池**
```cpp
// basic_thread_pool.hpp
#pragma once
#include <thread>
#include <vector>
#include <functional>
#include <atomic>
#include "thread_safe_queue.hpp"

class BasicThreadPool {
    using Task = std::function<void()>;

    ThreadSafeQueue<Task> task_queue_;
    std::vector<std::thread> workers_;
    std::atomic<bool> running_{true};

    void worker_loop() {
        while (running_) {
            auto task = task_queue_.pop();
            if (task) {
                try {
                    (*task)();
                } catch (const std::exception& e) {
                    // 记录异常但不终止线程
                    // 生产环境应该有更好的错误处理
                }
            }
        }
    }

public:
    explicit BasicThreadPool(size_t num_threads = std::thread::hardware_concurrency()) {
        for (size_t i = 0; i < num_threads; ++i) {
            workers_.emplace_back(&BasicThreadPool::worker_loop, this);
        }
    }

    ~BasicThreadPool() {
        shutdown();
    }

    // 禁止拷贝
    BasicThreadPool(const BasicThreadPool&) = delete;
    BasicThreadPool& operator=(const BasicThreadPool&) = delete;

    void submit(Task task) {
        task_queue_.push(std::move(task));
    }

    void shutdown() {
        if (running_.exchange(false)) {
            task_queue_.stop();
            for (auto& worker : workers_) {
                if (worker.joinable()) {
                    worker.join();
                }
            }
        }
    }

    size_t pending_tasks() const {
        return task_queue_.size();
    }
};
```

**常见错误警示**：
> ⚠️ **错误 1**：在析构函数中忘记 join 工作线程
> ```cpp
> // 错误：线程悬空，程序崩溃
> ~BasicThreadPool() {
>     running_ = false;
>     // 忘记 join！
> }
> ```
>
> ⚠️ **错误 2**：不处理任务中的异常
> ```cpp
> // 错误：异常会终止工作线程
> void worker_loop() {
>     while (running_) {
>         auto task = task_queue_.pop();
>         (*task)();  // 如果抛异常，线程就死了！
>     }
> }
> ```

**Day 1-2 检验标准**：
- [ ] 能解释线程池四大核心组件的职责
- [ ] 实现的队列能正确处理多线程并发访问
- [ ] 基础线程池能正确执行提交的任务
- [ ] 理解为什么需要在析构时 join 线程

**今日输出物**：
- [ ] `thread_safe_queue.hpp`
- [ ] `basic_thread_pool.hpp`
- [ ] `test_basic_pool.cpp`
- [ ] 笔记：`notes/week1/day1-2_core_components.md`

---

#### 📅 Day 3-4: 任务结果获取机制（10小时）

**Day 3 上午（2.5小时）- future/promise 深入理解**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 回顾基础 | 复习 std::future、std::promise、std::shared_future |
| 1:00-2:00 | packaged_task | 深入理解 std::packaged_task 的原理 |
| 2:00-2:30 | 对比分析 | 分析三种异步结果获取方式的适用场景 |

**核心概念：异步结果获取的三种方式**
```cpp
#include <future>
#include <thread>

// 方式1：std::async（最简单，但控制力弱）
auto future1 = std::async(std::launch::async, []{ return 42; });

// 方式2：std::promise（最灵活，完全手动控制）
std::promise<int> promise;
auto future2 = promise.get_future();
std::thread([&promise]{ promise.set_value(42); }).detach();

// 方式3：std::packaged_task（适合线程池场景）
std::packaged_task<int()> task([]{ return 42; });
auto future3 = task.get_future();
std::thread(std::move(task)).detach();
```

**Day 3 下午（2.5小时）- 扩展线程池支持返回值**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 模板submit | 实现返回 future 的 submit 方法 |
| 2:00-2:30 | 测试验证 | 验证各种返回类型的任务 |

**动手实验 1-3：支持返回值的线程池**
```cpp
// thread_pool_with_future.hpp
#pragma once
#include <thread>
#include <vector>
#include <queue>
#include <functional>
#include <future>
#include <mutex>
#include <condition_variable>
#include <type_traits>

class ThreadPoolWithFuture {
    std::queue<std::function<void()>> tasks_;
    std::vector<std::thread> workers_;
    std::mutex mutex_;
    std::condition_variable cv_;
    bool stop_ = false;

    void worker_loop() {
        while (true) {
            std::function<void()> task;
            {
                std::unique_lock<std::mutex> lock(mutex_);
                cv_.wait(lock, [this] {
                    return stop_ || !tasks_.empty();
                });

                if (stop_ && tasks_.empty()) {
                    return;
                }

                task = std::move(tasks_.front());
                tasks_.pop();
            }
            task();
        }
    }

public:
    explicit ThreadPoolWithFuture(size_t threads = std::thread::hardware_concurrency()) {
        for (size_t i = 0; i < threads; ++i) {
            workers_.emplace_back(&ThreadPoolWithFuture::worker_loop, this);
        }
    }

    ~ThreadPoolWithFuture() {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            stop_ = true;
        }
        cv_.notify_all();
        for (auto& worker : workers_) {
            if (worker.joinable()) {
                worker.join();
            }
        }
    }

    // 核心：支持任意可调用对象，返回 future
    template <typename F, typename... Args>
    auto submit(F&& f, Args&&... args)
        -> std::future<std::invoke_result_t<F, Args...>>
    {
        using ReturnType = std::invoke_result_t<F, Args...>;

        // 创建 packaged_task
        auto task = std::make_shared<std::packaged_task<ReturnType()>>(
            std::bind(std::forward<F>(f), std::forward<Args>(args)...)
        );

        std::future<ReturnType> result = task->get_future();

        {
            std::lock_guard<std::mutex> lock(mutex_);
            if (stop_) {
                throw std::runtime_error("ThreadPool is stopped");
            }
            tasks_.emplace([task]() { (*task)(); });
        }
        cv_.notify_one();

        return result;
    }
};
```

**Day 4 上午（2.5小时）- 异常传播机制**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 异常传播原理 | 理解 future 如何捕获和传播异常 |
| 1:00-2:00 | 实验验证 | 测试任务抛出异常时的行为 |
| 2:00-2:30 | 最佳实践 | 整理异常处理的推荐做法 |

**动手实验 1-4：异常传播测试**
```cpp
// test_exception_propagation.cpp
#include "thread_pool_with_future.hpp"
#include <iostream>
#include <stdexcept>

void test_exception_propagation() {
    ThreadPoolWithFuture pool(4);

    // 提交一个会抛异常的任务
    auto future = pool.submit([]() -> int {
        throw std::runtime_error("Task failed!");
        return 42;
    });

    try {
        int result = future.get();  // 这里会重新抛出异常
        std::cout << "Result: " << result << "\n";
    } catch (const std::exception& e) {
        std::cout << "Caught exception: " << e.what() << "\n";
    }

    // 正常任务
    auto future2 = pool.submit([]{ return 100; });
    std::cout << "Normal result: " << future2.get() << "\n";
}

int main() {
    test_exception_propagation();
    return 0;
}
```

**Day 4 下午（2.5小时）- 批量任务与等待**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 批量提交 | 实现 submit_batch 方法 |
| 1:30-2:30 | 等待所有完成 | 实现 wait_all 辅助函数 |

**动手实验 1-5：批量任务处理**
```cpp
// 批量提交与等待的辅助函数
template <typename Container>
auto submit_batch(ThreadPoolWithFuture& pool, Container&& tasks) {
    using TaskType = typename std::decay_t<Container>::value_type;
    using ReturnType = std::invoke_result_t<TaskType>;

    std::vector<std::future<ReturnType>> futures;
    futures.reserve(tasks.size());

    for (auto&& task : tasks) {
        futures.push_back(pool.submit(std::forward<decltype(task)>(task)));
    }

    return futures;
}

// 等待所有 future 完成并收集结果
template <typename T>
std::vector<T> wait_all(std::vector<std::future<T>>& futures) {
    std::vector<T> results;
    results.reserve(futures.size());

    for (auto& f : futures) {
        results.push_back(f.get());
    }

    return results;
}

// 使用示例
void batch_example() {
    ThreadPoolWithFuture pool(4);

    std::vector<std::function<int()>> tasks;
    for (int i = 0; i < 10; ++i) {
        tasks.push_back([i]{ return i * i; });
    }

    auto futures = submit_batch(pool, tasks);
    auto results = wait_all(futures);

    for (int r : results) {
        std::cout << r << " ";  // 0 1 4 9 16 25 36 49 64 81
    }
}
```

**Day 3-4 检验标准**：
- [ ] 理解 future/promise/packaged_task 的区别和联系
- [ ] 能正确实现返回 future 的 submit 方法
- [ ] 理解异常如何通过 future 传播
- [ ] 能实现批量任务提交和结果收集

**今日输出物**：
- [ ] `thread_pool_with_future.hpp`
- [ ] `test_exception_propagation.cpp`
- [ ] 笔记：`notes/week1/day3-4_future_mechanism.md`

---

#### 📅 Day 5-6: 优雅关闭与生命周期管理（10小时）

**Day 5 上午（2.5小时）- 关闭策略分析**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 关闭模式 | 分析不同的关闭策略：立即停止 vs 等待完成 |
| 1:00-2:00 | Java对比 | 学习 Java ExecutorService 的 shutdown/shutdownNow |
| 2:00-2:30 | 设计决策 | 确定我们要支持的关闭模式 |

**核心概念：两种关闭模式**
```cpp
// 模式1：优雅关闭（Graceful Shutdown）
// - 停止接受新任务
// - 等待已提交的任务执行完成
// - 类似 Java 的 shutdown()

// 模式2：立即关闭（Immediate Shutdown）
// - 停止接受新任务
// - 尝试取消正在等待的任务
// - 不等待正在执行的任务（但不强制中断）
// - 类似 Java 的 shutdownNow()
```

**Day 5 下午（2.5小时）- 实现双模式关闭**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 代码实现 | 实现 shutdown 和 shutdown_now 方法 |
| 2:00-2:30 | 测试验证 | 验证两种关闭模式的行为 |

**动手实验 1-6：完善的生命周期管理**
```cpp
// lifecycle_thread_pool.hpp
#pragma once
#include <thread>
#include <vector>
#include <queue>
#include <functional>
#include <future>
#include <mutex>
#include <condition_variable>
#include <atomic>

class LifecycleThreadPool {
public:
    enum class State {
        Running,      // 正常运行
        ShuttingDown, // 优雅关闭中（不接受新任务，等待现有任务完成）
        Stopped       // 已停止
    };

private:
    std::queue<std::function<void()>> tasks_;
    std::vector<std::thread> workers_;
    std::mutex mutex_;
    std::condition_variable cv_;
    std::condition_variable shutdown_cv_;  // 用于等待关闭完成
    std::atomic<State> state_{State::Running};
    std::atomic<size_t> active_tasks_{0};  // 正在执行的任务数

    void worker_loop() {
        while (true) {
            std::function<void()> task;
            {
                std::unique_lock<std::mutex> lock(mutex_);
                cv_.wait(lock, [this] {
                    return state_ != State::Running || !tasks_.empty();
                });

                // 如果正在关闭且队列为空，退出
                if (state_ != State::Running && tasks_.empty()) {
                    return;
                }

                // 如果是立即停止，也退出
                if (state_ == State::Stopped) {
                    return;
                }

                if (!tasks_.empty()) {
                    task = std::move(tasks_.front());
                    tasks_.pop();
                    ++active_tasks_;
                }
            }

            if (task) {
                try {
                    task();
                } catch (...) {
                    // 记录但不传播
                }
                --active_tasks_;
                shutdown_cv_.notify_all();  // 可能有人在等待关闭
            }
        }
    }

public:
    explicit LifecycleThreadPool(size_t threads = std::thread::hardware_concurrency()) {
        for (size_t i = 0; i < threads; ++i) {
            workers_.emplace_back(&LifecycleThreadPool::worker_loop, this);
        }
    }

    ~LifecycleThreadPool() {
        shutdown();
        wait();
    }

    // 获取当前状态
    State state() const { return state_.load(); }

    // 优雅关闭：停止接受新任务，等待现有任务完成
    void shutdown() {
        State expected = State::Running;
        if (state_.compare_exchange_strong(expected, State::ShuttingDown)) {
            cv_.notify_all();
        }
    }

    // 立即关闭：清空队列，不等待
    std::vector<std::function<void()>> shutdown_now() {
        std::vector<std::function<void()>> remaining;
        {
            std::lock_guard<std::mutex> lock(mutex_);
            state_ = State::Stopped;
            while (!tasks_.empty()) {
                remaining.push_back(std::move(tasks_.front()));
                tasks_.pop();
            }
        }
        cv_.notify_all();
        return remaining;
    }

    // 等待所有任务完成
    void wait() {
        {
            std::unique_lock<std::mutex> lock(mutex_);
            shutdown_cv_.wait(lock, [this] {
                return tasks_.empty() && active_tasks_ == 0;
            });
        }
        for (auto& worker : workers_) {
            if (worker.joinable()) {
                worker.join();
            }
        }
    }

    // 带超时的等待
    template <typename Rep, typename Period>
    bool wait_for(const std::chrono::duration<Rep, Period>& timeout) {
        std::unique_lock<std::mutex> lock(mutex_);
        return shutdown_cv_.wait_for(lock, timeout, [this] {
            return tasks_.empty() && active_tasks_ == 0;
        });
    }

    // 提交任务
    template <typename F, typename... Args>
    auto submit(F&& f, Args&&... args)
        -> std::future<std::invoke_result_t<F, Args...>>
    {
        using ReturnType = std::invoke_result_t<F, Args...>;

        if (state_ != State::Running) {
            throw std::runtime_error("ThreadPool is not running");
        }

        auto task = std::make_shared<std::packaged_task<ReturnType()>>(
            std::bind(std::forward<F>(f), std::forward<Args>(args)...)
        );

        std::future<ReturnType> result = task->get_future();

        {
            std::lock_guard<std::mutex> lock(mutex_);
            if (state_ != State::Running) {
                throw std::runtime_error("ThreadPool is not running");
            }
            tasks_.emplace([task]() { (*task)(); });
        }
        cv_.notify_one();

        return result;
    }

    // 查询信息
    size_t pending_tasks() const {
        std::lock_guard<std::mutex> lock(const_cast<std::mutex&>(mutex_));
        return tasks_.size();
    }

    size_t active_tasks() const {
        return active_tasks_.load();
    }

    size_t thread_count() const {
        return workers_.size();
    }
};
```

**Day 6 上午（2.5小时）- 线程池状态机**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 状态机设计 | 绘制完整的状态转换图 |
| 1:30-2:30 | 边界测试 | 测试各种状态转换场景 |

**状态转换图**：
```
                 submit()
    ┌──────────────────────────────┐
    │                              │
    ▼                              │
┌─────────┐  shutdown()   ┌───────────────┐  tasks done   ┌─────────┐
│ Running │──────────────▶│ ShuttingDown  │──────────────▶│ Stopped │
└─────────┘               └───────────────┘               └─────────┘
    │                                                          ▲
    │                    shutdown_now()                        │
    └──────────────────────────────────────────────────────────┘
```

**Day 6 下午（2.5小时）- 综合测试**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 压力测试 | 编写多场景的压力测试 |
| 2:00-2:30 | 问题修复 | 修复发现的问题 |

**动手实验 1-7：生命周期测试**
```cpp
// test_lifecycle.cpp
#include "lifecycle_thread_pool.hpp"
#include <iostream>
#include <chrono>

void test_graceful_shutdown() {
    std::cout << "=== Test Graceful Shutdown ===\n";
    LifecycleThreadPool pool(4);

    std::atomic<int> completed{0};

    // 提交一些耗时任务
    for (int i = 0; i < 10; ++i) {
        pool.submit([&completed, i] {
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
            ++completed;
            std::cout << "Task " << i << " completed\n";
        });
    }

    std::cout << "Initiating shutdown...\n";
    pool.shutdown();

    // 尝试提交新任务应该失败
    try {
        pool.submit([] { std::cout << "This should not run\n"; });
    } catch (const std::exception& e) {
        std::cout << "Expected error: " << e.what() << "\n";
    }

    pool.wait();
    std::cout << "Completed tasks: " << completed << "/10\n";
}

void test_immediate_shutdown() {
    std::cout << "\n=== Test Immediate Shutdown ===\n";
    LifecycleThreadPool pool(2);

    // 提交很多任务
    for (int i = 0; i < 100; ++i) {
        pool.submit([i] {
            std::this_thread::sleep_for(std::chrono::milliseconds(50));
        });
    }

    std::this_thread::sleep_for(std::chrono::milliseconds(100));

    auto remaining = pool.shutdown_now();
    std::cout << "Cancelled " << remaining.size() << " pending tasks\n";
}

int main() {
    test_graceful_shutdown();
    test_immediate_shutdown();
    return 0;
}
```

**Day 5-6 检验标准**：
- [ ] 理解优雅关闭和立即关闭的区别
- [ ] 正确实现状态机转换
- [ ] 能处理关闭过程中的并发提交
- [ ] 实现带超时的等待

**今日输出物**：
- [ ] `lifecycle_thread_pool.hpp`
- [ ] `test_lifecycle.cpp`
- [ ] 笔记：`notes/week1/day5-6_lifecycle.md`

---

#### 📅 Day 7: 第一周总结与扩展阅读（5小时）

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 源码阅读 | 阅读 Boost.Asio 线程池实现 |
| 2:00-3:00 | 对比分析 | 对比我们的实现与 std::async |
| 3:00-4:00 | 笔记整理 | 整理本周学习笔记 |
| 4:00-5:00 | 预习准备 | 预习下周工作窃取主题 |

**扩展阅读**：
- [ ] Boost.Asio thread_pool 源码
- [ ] folly::ThreadPoolExecutor 设计文档
- [ ] Intel TBB task_arena 介绍

**第一周输出物汇总**：
1. `thread_safe_queue.hpp` - 线程安全队列
2. `basic_thread_pool.hpp` - 基础线程池
3. `thread_pool_with_future.hpp` - 支持返回值的线程池
4. `lifecycle_thread_pool.hpp` - 完整生命周期管理
5. `test_*.cpp` - 测试文件
6. `notes/week1/` - 本周笔记

---

### 第二周：工作窃取（Work Stealing）

**学习目标**：深入理解工作窃取算法，实现高效的负载均衡线程池

**阅读材料**：
- [ ] 论文：Blumofe & Leiserson "Scheduling Multithreaded Computations by Work Stealing"
- [ ] 论文：Chase & Lev "Dynamic Circular Work-Stealing Deque"
- [ ] CppCon 2018: "C++ Executors: The Good, The Bad, and Some Examples"
- [ ] Java Fork/Join Framework 文档

---

#### 📅 Day 1-2: 工作窃取原理（10小时）

**Day 1 上午（2.5小时）- 为什么需要工作窃取？**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 传统线程池问题 | 分析单一任务队列的瓶颈：锁竞争、负载不均 |
| 1:00-2:00 | 工作窃取思想 | 理解"每个线程有本地队列，空闲时窃取"的设计 |
| 2:00-2:30 | 图解理解 | 画出工作窃取的数据流图 |

**核心概念：传统线程池 vs 工作窃取**
```
传统线程池（单一队列）：
┌─────────────────────────────────────┐
│         Global Task Queue           │  <-- 所有线程竞争同一把锁
│    [T1] [T2] [T3] [T4] [T5] ...    │
└──────────────┬──────────────────────┘
               │ 高竞争！
    ┌──────────┼──────────┐
    ▼          ▼          ▼
┌────────┐ ┌────────┐ ┌────────┐
│Worker 1│ │Worker 2│ │Worker 3│
└────────┘ └────────┘ └────────┘

工作窃取线程池：
┌────────────────────────────────────────────────────────┐
│  Worker 1          Worker 2          Worker 3          │
│  ┌────────┐        ┌────────┐        ┌────────┐       │
│  │Local Q │        │Local Q │        │Local Q │       │
│  │[T1][T2]│        │[T3]    │        │        │       │
│  └────────┘        └────────┘        └────────┘       │
│      │                                    │           │
│      │              steal ◄───────────────┘           │
│      ▼                                                │
│  执行 T1                                              │
└────────────────────────────────────────────────────────┘
```

**Day 1 下午（2.5小时）- 双端队列的必要性**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 为什么用 Deque | 理解 LIFO 本地访问 + FIFO 窃取的优势 |
| 1:00-2:00 | 缓存局部性 | 分析为什么从队尾窃取能提高缓存命中率 |
| 2:00-2:30 | 数据结构选择 | 对比各种并发队列的适用场景 |

**核心概念：Deque 的访问模式**
```cpp
/*
工作窃取 Deque 的访问模式：

所有者线程（Owner）：
- push: 从 bottom 端添加（新任务）
- pop:  从 bottom 端取出（最近添加的任务，LIFO）

窃取者线程（Thief）：
- steal: 从 top 端取出（最早添加的任务，FIFO）

┌─────────────────────────────────┐
│   top                           │  <-- 窃取者从这里取（FIFO）
│   ↓                             │
│   [Task A] [Task B] [Task C]    │
│                           ↑     │
│                         bottom  │  <-- 所有者在这里操作（LIFO）
└─────────────────────────────────┘

为什么这样设计？
1. 缓存局部性：所有者执行最近添加的任务，数据更可能在缓存中
2. 减少竞争：所有者和窃取者在不同端操作，大多数情况无竞争
3. 任务粒度：窃取的是较早（通常较大）的任务，减少窃取频率
*/
```

**Day 2 上午（2.5小时）- Chase-Lev Deque 论文精读**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 论文阅读 | 精读 "Dynamic Circular Work-Stealing Deque" |
| 1:30-2:30 | 算法理解 | 画出 push/pop/steal 的状态转换图 |

**Day 2 下午（2.5小时）- 简化版工作窃取队列**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 基础实现 | 实现带锁的简化版工作窃取队列 |
| 2:00-2:30 | 测试验证 | 验证正确性 |

**动手实验 2-1：简化版工作窃取队列（带锁）**
```cpp
// simple_ws_deque.hpp
#pragma once
#include <deque>
#include <mutex>
#include <optional>

template <typename T>
class SimpleWSDeque {
    std::deque<T> deque_;
    mutable std::mutex mutex_;

public:
    // 所有者：从 bottom 添加
    void push(T item) {
        std::lock_guard<std::mutex> lock(mutex_);
        deque_.push_back(std::move(item));
    }

    // 所有者：从 bottom 取出（LIFO）
    std::optional<T> pop() {
        std::lock_guard<std::mutex> lock(mutex_);
        if (deque_.empty()) {
            return std::nullopt;
        }
        T item = std::move(deque_.back());
        deque_.pop_back();
        return item;
    }

    // 窃取者：从 top 取出（FIFO）
    std::optional<T> steal() {
        std::lock_guard<std::mutex> lock(mutex_);
        if (deque_.empty()) {
            return std::nullopt;
        }
        T item = std::move(deque_.front());
        deque_.pop_front();
        return item;
    }

    bool empty() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return deque_.empty();
    }

    size_t size() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return deque_.size();
    }
};
```

**Day 1-2 检验标准**：
- [ ] 能解释工作窃取相比传统线程池的优势
- [ ] 理解为什么使用 Deque 而不是普通队列
- [ ] 理解 LIFO 本地访问和 FIFO 窃取的原因
- [ ] 实现简化版工作窃取队列

**今日输出物**：
- [ ] `simple_ws_deque.hpp`
- [ ] 笔记：`notes/week2/day1-2_work_stealing_theory.md`

---

#### 📅 Day 3-4: 无锁工作窃取队列（10小时）

**Day 3 上午（2.5小时）- Chase-Lev Deque 算法详解**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 算法分析 | 逐行理解 Chase-Lev 算法的每个操作 |
| 1:30-2:30 | 内存序分析 | 分析每个原子操作需要的内存序 |

**核心概念：Chase-Lev Deque 算法**
```cpp
/*
Chase-Lev Work-Stealing Deque 核心思想：

数据结构：
- 环形数组 buffer[]
- top: 窃取端索引（原子变量）
- bottom: 所有者端索引（原子变量）

关键不变量：
- top <= bottom（始终成立）
- 有效元素在 [top, bottom) 范围内
- size = bottom - top

操作复杂度：
- push:  O(1)，无竞争
- pop:   O(1)，可能与 steal 竞争
- steal: O(1)，可能与 pop 或其他 steal 竞争

竞争情况分析：
┌──────────────┬──────────────┬──────────────┐
│ 队列状态     │ push         │ pop          │ steal        │
├──────────────┼──────────────┼──────────────┼──────────────┤
│ 多个元素     │ 无竞争       │ 无竞争       │ 可能竞争steal│
│ 单个元素     │ 无竞争       │ 与steal竞争  │ 与pop竞争    │
│ 空           │ 无竞争       │ 无竞争       │ 无竞争       │
└──────────────┴──────────────┴──────────────┴──────────────┘
*/
```

**Day 3 下午（2.5小时）- 实现无锁 Deque**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 核心实现 | 实现 push、pop、steal 操作 |
| 2:00-2:30 | 初步测试 | 单线程正确性测试 |

**动手实验 2-2：Chase-Lev 无锁 Deque**
```cpp
// chase_lev_deque.hpp
#pragma once
#include <atomic>
#include <vector>
#include <memory>
#include <optional>
#include <cassert>

template <typename T>
class ChaseLevDeque {
    struct CircularArray {
        std::vector<T> buffer;
        size_t mask;

        explicit CircularArray(size_t capacity)
            : buffer(capacity), mask(capacity - 1) {
            assert((capacity & (capacity - 1)) == 0);
        }

        size_t capacity() const { return buffer.size(); }

        T& operator[](size_t index) {
            return buffer[index & mask];
        }

        std::unique_ptr<CircularArray> grow(size_t top, size_t bottom) {
            auto new_array = std::make_unique<CircularArray>(capacity() * 2);
            for (size_t i = top; i < bottom; ++i) {
                (*new_array)[i] = std::move((*this)[i]);
            }
            return new_array;
        }
    };

    std::atomic<size_t> top_{0};
    std::atomic<size_t> bottom_{0};
    std::atomic<CircularArray*> array_;
    std::vector<std::unique_ptr<CircularArray>> old_arrays_;
    std::mutex old_arrays_mutex_;

public:
    explicit ChaseLevDeque(size_t initial_capacity = 32) {
        size_t capacity = 1;
        while (capacity < initial_capacity) capacity *= 2;
        array_.store(new CircularArray(capacity));
    }

    ~ChaseLevDeque() { delete array_.load(); }

    void push(T item) {
        size_t b = bottom_.load(std::memory_order_relaxed);
        size_t t = top_.load(std::memory_order_acquire);
        CircularArray* arr = array_.load(std::memory_order_relaxed);

        if (b - t >= arr->capacity() - 1) {
            auto new_arr = arr->grow(t, b);
            {
                std::lock_guard<std::mutex> lock(old_arrays_mutex_);
                old_arrays_.push_back(std::unique_ptr<CircularArray>(arr));
            }
            arr = new_arr.release();
            array_.store(arr, std::memory_order_release);
        }

        (*arr)[b] = std::move(item);
        std::atomic_thread_fence(std::memory_order_release);
        bottom_.store(b + 1, std::memory_order_relaxed);
    }

    std::optional<T> pop() {
        size_t b = bottom_.load(std::memory_order_relaxed) - 1;
        CircularArray* arr = array_.load(std::memory_order_relaxed);
        bottom_.store(b, std::memory_order_relaxed);
        std::atomic_thread_fence(std::memory_order_seq_cst);
        size_t t = top_.load(std::memory_order_relaxed);

        if (t <= b) {
            T item = std::move((*arr)[b]);
            if (t == b) {
                if (!top_.compare_exchange_strong(t, t + 1,
                        std::memory_order_seq_cst, std::memory_order_relaxed)) {
                    bottom_.store(b + 1, std::memory_order_relaxed);
                    return std::nullopt;
                }
                bottom_.store(b + 1, std::memory_order_relaxed);
            }
            return item;
        } else {
            bottom_.store(b + 1, std::memory_order_relaxed);
            return std::nullopt;
        }
    }

    std::optional<T> steal() {
        size_t t = top_.load(std::memory_order_acquire);
        std::atomic_thread_fence(std::memory_order_seq_cst);
        size_t b = bottom_.load(std::memory_order_acquire);

        if (t < b) {
            CircularArray* arr = array_.load(std::memory_order_consume);
            T item = (*arr)[t];
            if (!top_.compare_exchange_strong(t, t + 1,
                    std::memory_order_seq_cst, std::memory_order_relaxed)) {
                return std::nullopt;
            }
            return item;
        }
        return std::nullopt;
    }

    bool empty() const {
        return top_.load(std::memory_order_relaxed) >=
               bottom_.load(std::memory_order_relaxed);
    }
};
```

**Day 4（5小时）- 测试与性能分析**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 多线程测试 | 编写并发测试，验证正确性 |
| 2:00-3:30 | TSan 检测 | 使用 ThreadSanitizer 检测数据竞争 |
| 3:30-5:00 | 性能测试 | 对比有锁和无锁版本 |

**Day 3-4 检验标准**：
- [ ] 理解 Chase-Lev 算法的每个操作
- [ ] 正确分析内存序的选择
- [ ] 实现通过多线程正确性测试

**今日输出物**：
- [ ] `chase_lev_deque.hpp`
- [ ] `test_chase_lev.cpp`
- [ ] 笔记：`notes/week2/day3-4_lock_free_deque.md`

---

#### 📅 Day 5-6: Fork/Join 模式与工作窃取线程池（10小时）

**Day 5（5小时）- 工作窃取线程池实现**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | Fork/Join 概念 | 理解分治并行的核心思想 |
| 1:00-2:30 | 线程池实现 | 整合 Chase-Lev Deque 实现线程池 |
| 2:30-5:00 | 测试验证 | 验证基本功能 |

**动手实验 2-4：工作窃取线程池**
```cpp
// work_stealing_pool.hpp
#pragma once
#include <thread>
#include <vector>
#include <functional>
#include <future>
#include <atomic>
#include <random>
#include "chase_lev_deque.hpp"

class WorkStealingPool {
    using Task = std::function<void()>;

    std::vector<std::unique_ptr<ChaseLevDeque<Task>>> local_queues_;
    std::vector<std::thread> workers_;
    std::atomic<bool> running_{true};
    static thread_local size_t worker_id_;

    void worker_loop(size_t id) {
        worker_id_ = id;
        std::mt19937 rng(id);

        while (running_) {
            Task task;
            auto local_task = local_queues_[id]->pop();
            if (local_task) {
                task = std::move(*local_task);
            } else {
                // 尝试窃取
                size_t n = local_queues_.size();
                size_t start = rng() % n;
                for (size_t i = 0; i < n; ++i) {
                    size_t victim = (start + i) % n;
                    if (victim == id) continue;
                    auto stolen = local_queues_[victim]->steal();
                    if (stolen) {
                        task = std::move(*stolen);
                        break;
                    }
                }
            }

            if (task) {
                try { task(); } catch (...) {}
            } else {
                std::this_thread::yield();
            }
        }
    }

public:
    explicit WorkStealingPool(size_t threads = std::thread::hardware_concurrency()) {
        for (size_t i = 0; i < threads; ++i) {
            local_queues_.push_back(std::make_unique<ChaseLevDeque<Task>>());
        }
        for (size_t i = 0; i < threads; ++i) {
            workers_.emplace_back(&WorkStealingPool::worker_loop, this, i);
        }
    }

    ~WorkStealingPool() {
        running_ = false;
        for (auto& w : workers_) if (w.joinable()) w.join();
    }

    template <typename F, typename... Args>
    auto submit(F&& f, Args&&... args)
        -> std::future<std::invoke_result_t<F, Args...>>
    {
        using R = std::invoke_result_t<F, Args...>;
        auto task = std::make_shared<std::packaged_task<R()>>(
            std::bind(std::forward<F>(f), std::forward<Args>(args)...));
        std::future<R> result = task->get_future();

        size_t target = (worker_id_ < workers_.size()) ? worker_id_ :
            (std::hash<std::thread::id>{}(std::this_thread::get_id()) % workers_.size());
        local_queues_[target]->push([task]() { (*task)(); });
        return result;
    }
};

thread_local size_t WorkStealingPool::worker_id_ = SIZE_MAX;
```

**Day 6（5小时）- Fork/Join 任务与性能对比**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:30 | Fork/Join 实现 | 实现并行求和等递归任务 |
| 2:30-5:00 | 性能对比 | 对比工作窃取与传统线程池 |

**Day 5-6 检验标准**：
- [ ] 理解 Fork/Join 模式的核心思想
- [ ] 实现工作窃取线程池
- [ ] 对比分析工作窃取的性能优势

**今日输出物**：
- [ ] `work_stealing_pool.hpp`
- [ ] `benchmark_work_stealing.cpp`
- [ ] 笔记：`notes/week2/day5-6_fork_join.md`

---

#### 📅 Day 7: 第二周总结（5小时）

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 源码阅读 | 阅读 Intel TBB 的 task_arena 实现 |
| 2:00-4:00 | 对比分析 | 对比 Java ForkJoinPool、Tokio、Go runtime |
| 4:00-5:00 | 笔记整理 | 整理本周学习笔记 |

**第二周输出物汇总**：
1. `simple_ws_deque.hpp` - 简化版工作窃取队列
2. `chase_lev_deque.hpp` - 无锁 Chase-Lev Deque
3. `work_stealing_pool.hpp` - 工作窃取线程池
4. `test_*.cpp` / `benchmark_*.cpp` - 测试和基准文件
5. `notes/week2/` - 本周笔记

---

### 第三周：任务优先级与依赖

**学习目标**：实现支持优先级调度和任务依赖的线程池

**阅读材料**：
- [ ] 《算法导论》图算法章节（拓扑排序）
- [ ] Java ScheduledThreadPoolExecutor 源码分析
- [ ] 博客：Hashed and Hierarchical Timing Wheels

---

#### 📅 Day 1-2: 优先级队列与任务调度（10小时）

**Day 1（5小时）- 优先级调度策略**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 调度策略分析 | 学习 FIFO、优先级、公平调度等策略 |
| 1:30-3:00 | 优先级队列 | 使用 std::priority_queue 实现优先级调度 |
| 3:00-5:00 | 代码实现 | 实现支持优先级的线程池 |

**核心概念：常见调度策略**
```cpp
/*
调度策略对比：

1. FIFO（先进先出）
   - 简单公平
   - 无法处理紧急任务
   - 适用：大多数通用场景

2. 优先级调度
   - 高优先级任务优先执行
   - 可能导致低优先级任务饥饿
   - 适用：实时系统、紧急任务处理

3. 公平调度（Fair Share）
   - 按比例分配执行时间
   - 避免饥饿
   - 适用：多租户系统

4. 工作窃取 + 优先级
   - 本地队列内按优先级
   - 窃取时优先选择高优先级任务
   - 适用：复杂并行计算
*/
```

**动手实验 3-1：优先级线程池**
```cpp
// priority_thread_pool.hpp
#pragma once
#include <thread>
#include <vector>
#include <queue>
#include <functional>
#include <future>
#include <mutex>
#include <condition_variable>

class PriorityThreadPool {
public:
    enum class Priority { Low = 0, Normal = 1, High = 2, Critical = 3 };

private:
    struct PriorityTask {
        Priority priority;
        uint64_t sequence;  // 用于在相同优先级时保持 FIFO
        std::function<void()> task;

        bool operator<(const PriorityTask& other) const {
            // priority_queue 是最大堆，我们想要高优先级先出
            if (priority != other.priority) {
                return priority < other.priority;
            }
            // 相同优先级，先提交的先执行
            return sequence > other.sequence;
        }
    };

    std::priority_queue<PriorityTask> tasks_;
    std::vector<std::thread> workers_;
    std::mutex mutex_;
    std::condition_variable cv_;
    std::atomic<bool> stop_{false};
    std::atomic<uint64_t> sequence_{0};

    void worker_loop() {
        while (true) {
            std::function<void()> task;
            {
                std::unique_lock<std::mutex> lock(mutex_);
                cv_.wait(lock, [this] { return stop_ || !tasks_.empty(); });

                if (stop_ && tasks_.empty()) return;

                task = std::move(const_cast<PriorityTask&>(tasks_.top()).task);
                tasks_.pop();
            }
            if (task) {
                try { task(); } catch (...) {}
            }
        }
    }

public:
    explicit PriorityThreadPool(size_t threads = std::thread::hardware_concurrency()) {
        for (size_t i = 0; i < threads; ++i) {
            workers_.emplace_back(&PriorityThreadPool::worker_loop, this);
        }
    }

    ~PriorityThreadPool() {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            stop_ = true;
        }
        cv_.notify_all();
        for (auto& w : workers_) if (w.joinable()) w.join();
    }

    template <typename F, typename... Args>
    auto submit(Priority priority, F&& f, Args&&... args)
        -> std::future<std::invoke_result_t<F, Args...>>
    {
        using R = std::invoke_result_t<F, Args...>;
        auto task = std::make_shared<std::packaged_task<R()>>(
            std::bind(std::forward<F>(f), std::forward<Args>(args)...));
        std::future<R> result = task->get_future();

        {
            std::lock_guard<std::mutex> lock(mutex_);
            tasks_.push(PriorityTask{
                priority,
                sequence_++,
                [task]() { (*task)(); }
            });
        }
        cv_.notify_one();
        return result;
    }

    // 便捷方法
    template <typename F, typename... Args>
    auto submit(F&& f, Args&&... args) {
        return submit(Priority::Normal,
                      std::forward<F>(f), std::forward<Args>(args)...);
    }
};
```

**Day 2（5小时）- 防止优先级反转与饥饿**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 优先级反转 | 理解优先级反转问题及解决方案 |
| 2:00-3:30 | 老化机制 | 实现任务老化防止饥饿 |
| 3:30-5:00 | 测试验证 | 验证防饥饿机制 |

**动手实验 3-2：带老化机制的优先级队列**
```cpp
// aging_priority_queue.hpp
#pragma once
#include <chrono>
#include <queue>
#include <mutex>

template <typename T>
class AgingPriorityQueue {
    struct Entry {
        T item;
        int base_priority;
        std::chrono::steady_clock::time_point submit_time;

        // 计算有效优先级（考虑老化）
        int effective_priority(std::chrono::steady_clock::time_point now) const {
            auto age = std::chrono::duration_cast<std::chrono::seconds>(
                now - submit_time).count();
            // 每等待10秒，优先级提升1
            return base_priority + static_cast<int>(age / 10);
        }
    };

    std::vector<Entry> heap_;
    mutable std::mutex mutex_;

    void heapify_up(size_t index) {
        auto now = std::chrono::steady_clock::now();
        while (index > 0) {
            size_t parent = (index - 1) / 2;
            if (heap_[index].effective_priority(now) <=
                heap_[parent].effective_priority(now)) {
                break;
            }
            std::swap(heap_[index], heap_[parent]);
            index = parent;
        }
    }

    void heapify_down(size_t index) {
        auto now = std::chrono::steady_clock::now();
        size_t size = heap_.size();
        while (true) {
            size_t largest = index;
            size_t left = 2 * index + 1;
            size_t right = 2 * index + 2;

            if (left < size &&
                heap_[left].effective_priority(now) >
                heap_[largest].effective_priority(now)) {
                largest = left;
            }
            if (right < size &&
                heap_[right].effective_priority(now) >
                heap_[largest].effective_priority(now)) {
                largest = right;
            }

            if (largest == index) break;
            std::swap(heap_[index], heap_[largest]);
            index = largest;
        }
    }

public:
    void push(T item, int priority) {
        std::lock_guard<std::mutex> lock(mutex_);
        heap_.push_back(Entry{
            std::move(item),
            priority,
            std::chrono::steady_clock::now()
        });
        heapify_up(heap_.size() - 1);
    }

    std::optional<T> pop() {
        std::lock_guard<std::mutex> lock(mutex_);
        if (heap_.empty()) return std::nullopt;

        // 重新堆化（考虑老化）
        auto now = std::chrono::steady_clock::now();
        for (size_t i = heap_.size() / 2; i > 0; --i) {
            heapify_down(i - 1);
        }

        T result = std::move(heap_[0].item);
        heap_[0] = std::move(heap_.back());
        heap_.pop_back();
        if (!heap_.empty()) heapify_down(0);
        return result;
    }

    bool empty() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return heap_.empty();
    }
};
```

**Day 1-2 检验标准**：
- [ ] 实现优先级线程池
- [ ] 理解优先级反转和饥饿问题
- [ ] 实现防饥饿的老化机制

**今日输出物**：
- [ ] `priority_thread_pool.hpp`
- [ ] `aging_priority_queue.hpp`
- [ ] 笔记：`notes/week3/day1-2_priority_scheduling.md`

---

#### 📅 Day 3-4: 任务依赖图（DAG）（10小时）

**Day 3（5小时）- 任务依赖图设计**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | DAG 概念 | 理解有向无环图在任务调度中的应用 |
| 1:30-3:00 | 拓扑排序 | 实现 Kahn 算法 |
| 3:00-5:00 | 数据结构设计 | 设计任务依赖图的数据结构 |

**核心概念：任务依赖图**
```
任务依赖示例：编译项目

    ┌─────┐     ┌─────┐
    │ A.o │     │ B.o │
    └──┬──┘     └──┬──┘
       │           │
       └─────┬─────┘
             │
             ▼
        ┌─────────┐
        │  link   │
        └────┬────┘
             │
             ▼
        ┌─────────┐
        │   run   │
        └─────────┘

A.o 和 B.o 可以并行编译
link 依赖于 A.o 和 B.o
run 依赖于 link
```

**动手实验 3-3：任务依赖图**
```cpp
// task_graph.hpp
#pragma once
#include <unordered_map>
#include <unordered_set>
#include <vector>
#include <functional>
#include <future>
#include <mutex>
#include <queue>
#include <atomic>

class TaskGraph {
public:
    using TaskId = size_t;
    using TaskFunc = std::function<void()>;

private:
    struct TaskNode {
        TaskId id;
        TaskFunc func;
        std::vector<TaskId> dependencies;  // 依赖的任务
        std::vector<TaskId> dependents;    // 依赖此任务的任务
        std::atomic<size_t> pending_deps{0};  // 未完成的依赖数
        std::promise<void> completion;
        std::shared_future<void> future;

        TaskNode(TaskId id, TaskFunc func)
            : id(id), func(std::move(func)) {
            future = completion.get_future().share();
        }
    };

    std::unordered_map<TaskId, std::unique_ptr<TaskNode>> nodes_;
    std::mutex mutex_;
    std::atomic<TaskId> next_id_{0};

    // 就绪队列：无依赖或依赖已完成的任务
    std::queue<TaskId> ready_queue_;
    std::mutex ready_mutex_;
    std::condition_variable ready_cv_;

public:
    // 添加任务
    TaskId add_task(TaskFunc func) {
        TaskId id = next_id_++;
        std::lock_guard<std::mutex> lock(mutex_);
        nodes_[id] = std::make_unique<TaskNode>(id, std::move(func));
        return id;
    }

    // 添加依赖关系：task 依赖于 dependency
    void add_dependency(TaskId task, TaskId dependency) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto task_it = nodes_.find(task);
        auto dep_it = nodes_.find(dependency);
        if (task_it == nodes_.end() || dep_it == nodes_.end()) {
            throw std::runtime_error("Invalid task ID");
        }

        task_it->second->dependencies.push_back(dependency);
        dep_it->second->dependents.push_back(task);
    }

    // 执行图中所有任务
    void execute(size_t num_threads = std::thread::hardware_concurrency()) {
        // 1. 计算每个任务的待完成依赖数
        {
            std::lock_guard<std::mutex> lock(mutex_);
            for (auto& [id, node] : nodes_) {
                node->pending_deps = node->dependencies.size();
                if (node->pending_deps == 0) {
                    std::lock_guard<std::mutex> rlock(ready_mutex_);
                    ready_queue_.push(id);
                }
            }
        }

        // 2. 启动工作线程
        std::atomic<bool> done{false};
        std::atomic<size_t> completed{0};
        size_t total = nodes_.size();

        std::vector<std::thread> workers;
        for (size_t i = 0; i < num_threads; ++i) {
            workers.emplace_back([this, &done, &completed, total]() {
                while (!done || completed < total) {
                    TaskId task_id;
                    {
                        std::unique_lock<std::mutex> lock(ready_mutex_);
                        ready_cv_.wait_for(lock, std::chrono::milliseconds(10),
                            [this] { return !ready_queue_.empty(); });

                        if (ready_queue_.empty()) continue;

                        task_id = ready_queue_.front();
                        ready_queue_.pop();
                    }

                    // 执行任务
                    auto& node = nodes_[task_id];
                    try {
                        node->func();
                    } catch (...) {}

                    node->completion.set_value();
                    ++completed;

                    // 更新依赖此任务的任务
                    for (TaskId dep_id : node->dependents) {
                        auto& dep_node = nodes_[dep_id];
                        if (--dep_node->pending_deps == 0) {
                            std::lock_guard<std::mutex> lock(ready_mutex_);
                            ready_queue_.push(dep_id);
                            ready_cv_.notify_one();
                        }
                    }
                }
            });
        }

        done = true;
        ready_cv_.notify_all();

        for (auto& w : workers) {
            if (w.joinable()) w.join();
        }
    }

    // 等待特定任务完成
    void wait(TaskId id) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (nodes_.find(id) != nodes_.end()) {
            nodes_[id]->future.wait();
        }
    }

    // 检测循环依赖
    bool has_cycle() const {
        std::unordered_map<TaskId, int> in_degree;
        for (const auto& [id, node] : nodes_) {
            in_degree[id] = node->dependencies.size();
        }

        std::queue<TaskId> zero_degree;
        for (const auto& [id, degree] : in_degree) {
            if (degree == 0) zero_degree.push(id);
        }

        size_t processed = 0;
        while (!zero_degree.empty()) {
            TaskId id = zero_degree.front();
            zero_degree.pop();
            ++processed;

            for (TaskId dep_id : nodes_.at(id)->dependents) {
                if (--in_degree[dep_id] == 0) {
                    zero_degree.push(dep_id);
                }
            }
        }

        return processed != nodes_.size();
    }
};
```

**Day 4（5小时）- 测试与优化**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 测试用例 | 编写复杂依赖图的测试 |
| 2:00-4:00 | 循环检测 | 确保检测并报告循环依赖 |
| 4:00-5:00 | 性能优化 | 分析并优化调度开销 |

**Day 3-4 检验标准**：
- [ ] 理解 DAG 在任务调度中的应用
- [ ] 实现任务依赖图
- [ ] 正确检测循环依赖

**今日输出物**：
- [ ] `task_graph.hpp`
- [ ] `test_task_graph.cpp`
- [ ] 笔记：`notes/week3/day3-4_task_dag.md`

---

#### 📅 Day 5-6: 延迟任务与定时执行（10小时）

**Day 5（5小时）- 定时任务设计**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 定时器设计 | 分析定时任务的实现方式 |
| 2:00-3:30 | 时间轮算法 | 学习 Timing Wheel 算法 |
| 3:30-5:00 | 基础实现 | 实现简单的延迟队列 |

**核心概念：定时任务实现方式**
```cpp
/*
定时任务实现方式对比：

1. 最小堆（std::priority_queue）
   - 优点：简单，按触发时间排序
   - 缺点：插入 O(log n)，可能有性能问题
   - 适用：任务数量不大时

2. 时间轮（Timing Wheel）
   - 优点：插入删除 O(1)
   - 缺点：精度受限于轮的粒度
   - 适用：高吞吐量定时任务

3. 分层时间轮（Hierarchical Timing Wheel）
   - 优点：兼顾精度和性能
   - 缺点：实现复杂
   - 适用：需要覆盖大时间范围
*/
```

**动手实验 3-4：延迟任务队列**
```cpp
// scheduled_thread_pool.hpp
#pragma once
#include <thread>
#include <queue>
#include <functional>
#include <chrono>
#include <mutex>
#include <condition_variable>
#include <atomic>

class ScheduledThreadPool {
public:
    using Clock = std::chrono::steady_clock;
    using TimePoint = Clock::time_point;
    using Duration = Clock::duration;

private:
    struct ScheduledTask {
        TimePoint execute_at;
        std::function<void()> task;
        std::optional<Duration> period;  // 周期任务
        uint64_t sequence;

        bool operator>(const ScheduledTask& other) const {
            if (execute_at != other.execute_at) {
                return execute_at > other.execute_at;
            }
            return sequence > other.sequence;
        }
    };

    std::priority_queue<ScheduledTask, std::vector<ScheduledTask>,
                        std::greater<ScheduledTask>> tasks_;
    std::vector<std::thread> workers_;
    std::mutex mutex_;
    std::condition_variable cv_;
    std::atomic<bool> stop_{false};
    std::atomic<uint64_t> sequence_{0};

    void scheduler_loop() {
        while (!stop_) {
            std::unique_lock<std::mutex> lock(mutex_);

            if (tasks_.empty()) {
                cv_.wait(lock, [this] { return stop_ || !tasks_.empty(); });
                continue;
            }

            auto& top = tasks_.top();
            auto now = Clock::now();

            if (top.execute_at <= now) {
                // 任务就绪
                ScheduledTask task = std::move(const_cast<ScheduledTask&>(top));
                tasks_.pop();
                lock.unlock();

                // 执行任务
                try { task.task(); } catch (...) {}

                // 如果是周期任务，重新调度
                if (task.period) {
                    lock.lock();
                    task.execute_at = Clock::now() + *task.period;
                    task.sequence = sequence_++;
                    tasks_.push(std::move(task));
                }
            } else {
                // 等待到下一个任务的执行时间
                cv_.wait_until(lock, top.execute_at);
            }
        }
    }

public:
    explicit ScheduledThreadPool(size_t threads = 1) {
        for (size_t i = 0; i < threads; ++i) {
            workers_.emplace_back(&ScheduledThreadPool::scheduler_loop, this);
        }
    }

    ~ScheduledThreadPool() {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            stop_ = true;
        }
        cv_.notify_all();
        for (auto& w : workers_) if (w.joinable()) w.join();
    }

    // 延迟执行
    void schedule(std::function<void()> task, Duration delay) {
        std::lock_guard<std::mutex> lock(mutex_);
        tasks_.push(ScheduledTask{
            Clock::now() + delay,
            std::move(task),
            std::nullopt,
            sequence_++
        });
        cv_.notify_one();
    }

    // 在指定时间执行
    void schedule_at(std::function<void()> task, TimePoint time) {
        std::lock_guard<std::mutex> lock(mutex_);
        tasks_.push(ScheduledTask{
            time,
            std::move(task),
            std::nullopt,
            sequence_++
        });
        cv_.notify_one();
    }

    // 周期执行
    void schedule_periodic(std::function<void()> task,
                          Duration initial_delay, Duration period) {
        std::lock_guard<std::mutex> lock(mutex_);
        tasks_.push(ScheduledTask{
            Clock::now() + initial_delay,
            std::move(task),
            period,
            sequence_++
        });
        cv_.notify_one();
    }
};
```

**Day 6（5小时）- 时间轮实现**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-3:00 | 时间轮实现 | 实现简单时间轮 |
| 3:00-5:00 | 性能对比 | 对比堆实现和时间轮的性能 |

**Day 5-6 检验标准**：
- [ ] 实现延迟任务调度
- [ ] 实现周期任务调度
- [ ] 理解时间轮算法的优势

**今日输出物**：
- [ ] `scheduled_thread_pool.hpp`
- [ ] `test_scheduled_pool.cpp`
- [ ] 笔记：`notes/week3/day5-6_delayed_tasks.md`

---

#### 📅 Day 7: 第三周总结（5小时）

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 源码阅读 | 阅读 Java ScheduledThreadPoolExecutor |
| 2:00-4:00 | 综合实践 | 整合优先级、依赖、定时功能 |
| 4:00-5:00 | 笔记整理 | 整理本周学习笔记 |

**第三周输出物汇总**：
1. `priority_thread_pool.hpp` - 优先级线程池
2. `aging_priority_queue.hpp` - 带老化的优先级队列
3. `task_graph.hpp` - 任务依赖图
4. `scheduled_thread_pool.hpp` - 定时任务线程池
5. `test_*.cpp` - 测试文件
6. `notes/week3/` - 本周笔记

---

### 第四周：动态扩缩容与生产级特性

**学习目标**：实现自适应线程池，掌握监控与调优技术

**阅读材料**：
- [ ] Java ThreadPoolExecutor 源码（动态线程管理部分）
- [ ] folly::CPUThreadPoolExecutor 设计文档
- [ ] CppCon 2019: "Back to Basics: Concurrency" by Arthur O'Dwyer

---

#### 📅 Day 1-2: 动态线程数调整（10小时）

**Day 1（5小时）- 动态扩缩容策略**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 策略分析 | 学习何时扩容、何时缩容的判断标准 |
| 1:30-3:00 | 参数设计 | 设计 core/max 线程数、keepAlive 时间等参数 |
| 3:00-5:00 | 基础实现 | 实现动态线程数调整框架 |

**核心概念：动态线程池参数**
```cpp
/*
Java ThreadPoolExecutor 的核心参数：

1. corePoolSize（核心线程数）
   - 即使空闲也保留的线程数
   - 保证最小响应能力

2. maximumPoolSize（最大线程数）
   - 允许创建的最大线程数
   - 防止资源耗尽

3. keepAliveTime（空闲超时）
   - 超过 core 的线程空闲多久后回收
   - 平衡资源利用和响应能力

4. workQueue（任务队列）
   - 有界 vs 无界
   - 影响扩容时机

扩缩容策略：
┌─────────────────────────────────────────────────────────┐
│  提交任务                                               │
│      │                                                  │
│      ▼                                                  │
│  当前线程 < corePoolSize?  ──Yes──▶  创建核心线程执行   │
│      │No                                                │
│      ▼                                                  │
│  队列未满?  ──Yes──▶  加入队列                          │
│      │No                                                │
│      ▼                                                  │
│  当前线程 < maximumPoolSize?  ──Yes──▶  创建临时线程    │
│      │No                                                │
│      ▼                                                  │
│  执行拒绝策略                                           │
└─────────────────────────────────────────────────────────┘
*/
```

**动手实验 4-1：自适应线程池**
```cpp
// adaptive_thread_pool.hpp
#pragma once
#include <thread>
#include <vector>
#include <queue>
#include <functional>
#include <future>
#include <mutex>
#include <condition_variable>
#include <atomic>
#include <chrono>

class AdaptiveThreadPool {
public:
    struct Config {
        size_t core_threads = 2;        // 核心线程数
        size_t max_threads = 8;         // 最大线程数
        std::chrono::seconds keep_alive{60};  // 空闲超时
        size_t queue_capacity = 1000;   // 队列容量
    };

    enum class RejectionPolicy {
        Abort,      // 抛出异常
        CallerRuns, // 调用者执行
        Discard,    // 丢弃任务
        DiscardOldest  // 丢弃最老任务
    };

private:
    struct Worker {
        std::thread thread;
        std::chrono::steady_clock::time_point last_active;
        bool is_core;
    };

    Config config_;
    RejectionPolicy rejection_policy_ = RejectionPolicy::Abort;

    std::queue<std::function<void()>> tasks_;
    std::vector<std::unique_ptr<Worker>> workers_;
    std::mutex mutex_;
    std::condition_variable cv_;
    std::condition_variable worker_cv_;  // 用于唤醒空闲检查

    std::atomic<bool> stop_{false};
    std::atomic<size_t> active_threads_{0};
    std::atomic<size_t> total_threads_{0};

    void worker_loop(Worker* self) {
        while (!stop_) {
            std::function<void()> task;
            {
                std::unique_lock<std::mutex> lock(mutex_);

                // 非核心线程有超时
                auto timeout = self->is_core ?
                    std::chrono::steady_clock::time_point::max() :
                    self->last_active + config_.keep_alive;

                bool got_task = cv_.wait_until(lock, timeout, [this] {
                    return stop_ || !tasks_.empty();
                });

                if (stop_ && tasks_.empty()) {
                    --total_threads_;
                    return;
                }

                if (!got_task && !self->is_core) {
                    // 超时且是非核心线程，退出
                    --total_threads_;
                    return;
                }

                if (tasks_.empty()) continue;

                task = std::move(tasks_.front());
                tasks_.pop();
                self->last_active = std::chrono::steady_clock::now();
            }

            if (task) {
                ++active_threads_;
                try { task(); } catch (...) {}
                --active_threads_;
            }
        }
        --total_threads_;
    }

    bool try_add_worker(bool is_core) {
        auto worker = std::make_unique<Worker>();
        worker->is_core = is_core;
        worker->last_active = std::chrono::steady_clock::now();

        Worker* ptr = worker.get();
        worker->thread = std::thread(&AdaptiveThreadPool::worker_loop, this, ptr);
        workers_.push_back(std::move(worker));
        ++total_threads_;
        return true;
    }

    void handle_rejection(std::function<void()>& task) {
        switch (rejection_policy_) {
            case RejectionPolicy::Abort:
                throw std::runtime_error("Task rejected: queue full");
            case RejectionPolicy::CallerRuns:
                task();  // 在当前线程执行
                break;
            case RejectionPolicy::Discard:
                break;  // 直接丢弃
            case RejectionPolicy::DiscardOldest:
                if (!tasks_.empty()) {
                    tasks_.pop();
                    tasks_.push(std::move(task));
                }
                break;
        }
    }

public:
    explicit AdaptiveThreadPool(Config config = Config{})
        : config_(config) {
        // 预创建核心线程
        for (size_t i = 0; i < config_.core_threads; ++i) {
            std::lock_guard<std::mutex> lock(mutex_);
            try_add_worker(true);
        }
    }

    ~AdaptiveThreadPool() {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            stop_ = true;
        }
        cv_.notify_all();
        for (auto& worker : workers_) {
            if (worker->thread.joinable()) {
                worker->thread.join();
            }
        }
    }

    void set_rejection_policy(RejectionPolicy policy) {
        rejection_policy_ = policy;
    }

    template <typename F, typename... Args>
    auto submit(F&& f, Args&&... args)
        -> std::future<std::invoke_result_t<F, Args...>>
    {
        using R = std::invoke_result_t<F, Args...>;
        auto task = std::make_shared<std::packaged_task<R()>>(
            std::bind(std::forward<F>(f), std::forward<Args>(args)...));
        std::future<R> result = task->get_future();

        std::function<void()> wrapped = [task]() { (*task)(); };

        {
            std::lock_guard<std::mutex> lock(mutex_);

            // 检查是否需要创建新线程
            size_t current = total_threads_.load();
            size_t queue_size = tasks_.size();

            if (current < config_.core_threads) {
                // 还没达到核心线程数，创建核心线程
                try_add_worker(true);
            } else if (queue_size >= config_.queue_capacity) {
                // 队列满了
                if (current < config_.max_threads) {
                    // 还能创建临时线程
                    try_add_worker(false);
                } else {
                    // 达到最大线程数，执行拒绝策略
                    handle_rejection(wrapped);
                    return result;
                }
            } else if (queue_size > current * 2 && current < config_.max_threads) {
                // 队列积压严重，主动扩容
                try_add_worker(false);
            }

            tasks_.push(std::move(wrapped));
        }
        cv_.notify_one();
        return result;
    }

    // 监控接口
    size_t active_count() const { return active_threads_.load(); }
    size_t pool_size() const { return total_threads_.load(); }
    size_t queue_size() const {
        std::lock_guard<std::mutex> lock(const_cast<std::mutex&>(mutex_));
        return tasks_.size();
    }
};
```

**Day 2（5小时）- 测试与调优**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 负载测试 | 模拟各种负载模式测试扩缩容 |
| 2:00-4:00 | 参数调优 | 分析不同参数组合的效果 |
| 4:00-5:00 | 问题修复 | 修复线程泄漏等问题 |

**Day 1-2 检验标准**：
- [ ] 实现动态扩容和缩容
- [ ] 理解各种拒绝策略的适用场景
- [ ] 能根据负载模式调整参数

**今日输出物**：
- [ ] `adaptive_thread_pool.hpp`
- [ ] `test_adaptive_pool.cpp`
- [ ] 笔记：`notes/week4/day1-2_dynamic_scaling.md`

---

#### 📅 Day 3-4: 监控与性能调优（10小时）

**Day 3（5小时）- 监控指标收集**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 指标设计 | 确定需要收集的性能指标 |
| 2:00-4:00 | 实现监控 | 实现指标收集和统计 |
| 4:00-5:00 | 可视化 | 简单的指标输出 |

**核心概念：线程池关键指标**
```cpp
/*
生产环境需要监控的指标：

1. 吞吐量指标
   - 任务提交速率（tasks/sec）
   - 任务完成速率（tasks/sec）
   - 队列积压量

2. 延迟指标
   - 任务排队时间（从提交到开始执行）
   - 任务执行时间
   - 端到端延迟

3. 资源指标
   - 活跃线程数 / 总线程数
   - 队列使用率
   - 拒绝任务数

4. 异常指标
   - 任务失败数
   - 超时任务数
*/
```

**动手实验 4-2：线程池监控**
```cpp
// thread_pool_metrics.hpp
#pragma once
#include <atomic>
#include <chrono>
#include <mutex>
#include <vector>
#include <cmath>

class ThreadPoolMetrics {
public:
    using Clock = std::chrono::steady_clock;
    using Duration = std::chrono::nanoseconds;

private:
    // 计数器
    std::atomic<uint64_t> submitted_tasks_{0};
    std::atomic<uint64_t> completed_tasks_{0};
    std::atomic<uint64_t> rejected_tasks_{0};
    std::atomic<uint64_t> failed_tasks_{0};

    // 延迟统计（使用滑动窗口）
    struct LatencyStats {
        std::mutex mutex;
        std::vector<Duration> samples;
        size_t window_size = 1000;

        void record(Duration d) {
            std::lock_guard<std::mutex> lock(mutex);
            if (samples.size() >= window_size) {
                samples.erase(samples.begin());
            }
            samples.push_back(d);
        }

        Duration percentile(double p) const {
            std::lock_guard<std::mutex> lock(const_cast<std::mutex&>(mutex));
            if (samples.empty()) return Duration{0};

            std::vector<Duration> sorted = samples;
            std::sort(sorted.begin(), sorted.end());

            size_t idx = static_cast<size_t>(sorted.size() * p);
            if (idx >= sorted.size()) idx = sorted.size() - 1;
            return sorted[idx];
        }

        Duration mean() const {
            std::lock_guard<std::mutex> lock(const_cast<std::mutex&>(mutex));
            if (samples.empty()) return Duration{0};

            Duration sum{0};
            for (const auto& s : samples) sum += s;
            return sum / samples.size();
        }
    };

    LatencyStats queue_latency_;   // 排队延迟
    LatencyStats exec_latency_;    // 执行延迟

    // 吞吐量统计
    Clock::time_point start_time_ = Clock::now();

public:
    // 记录事件
    void task_submitted() { ++submitted_tasks_; }
    void task_completed() { ++completed_tasks_; }
    void task_rejected() { ++rejected_tasks_; }
    void task_failed() { ++failed_tasks_; }

    void record_queue_latency(Duration d) { queue_latency_.record(d); }
    void record_exec_latency(Duration d) { exec_latency_.record(d); }

    // 查询指标
    uint64_t submitted_count() const { return submitted_tasks_.load(); }
    uint64_t completed_count() const { return completed_tasks_.load(); }
    uint64_t rejected_count() const { return rejected_tasks_.load(); }
    uint64_t failed_count() const { return failed_tasks_.load(); }

    double throughput() const {
        auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(
            Clock::now() - start_time_).count();
        return elapsed > 0 ? static_cast<double>(completed_tasks_) / elapsed : 0;
    }

    // 延迟百分位
    Duration queue_latency_p50() const { return queue_latency_.percentile(0.5); }
    Duration queue_latency_p99() const { return queue_latency_.percentile(0.99); }
    Duration exec_latency_p50() const { return exec_latency_.percentile(0.5); }
    Duration exec_latency_p99() const { return exec_latency_.percentile(0.99); }

    // 打印报告
    void print_report() const {
        auto to_ms = [](Duration d) {
            return std::chrono::duration_cast<std::chrono::microseconds>(d).count() / 1000.0;
        };

        std::cout << "=== Thread Pool Metrics ===\n"
                  << "Submitted: " << submitted_tasks_ << "\n"
                  << "Completed: " << completed_tasks_ << "\n"
                  << "Rejected:  " << rejected_tasks_ << "\n"
                  << "Failed:    " << failed_tasks_ << "\n"
                  << "Throughput: " << throughput() << " tasks/sec\n"
                  << "\nQueue Latency:\n"
                  << "  P50: " << to_ms(queue_latency_p50()) << " ms\n"
                  << "  P99: " << to_ms(queue_latency_p99()) << " ms\n"
                  << "\nExec Latency:\n"
                  << "  P50: " << to_ms(exec_latency_p50()) << " ms\n"
                  << "  P99: " << to_ms(exec_latency_p99()) << " ms\n";
    }
};
```

**Day 4（5小时）- 性能调优实践**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 性能分析 | 使用 perf 分析线程池性能 |
| 2:00-4:00 | 优化实践 | 减少锁竞争、优化内存分配 |
| 4:00-5:00 | 基准对比 | 对比优化前后的性能 |

**Day 3-4 检验标准**：
- [ ] 实现完整的监控指标收集
- [ ] 能使用 perf 分析性能瓶颈
- [ ] 理解常见的性能优化技术

**今日输出物**：
- [ ] `thread_pool_metrics.hpp`
- [ ] `monitored_thread_pool.hpp`
- [ ] 笔记：`notes/week4/day3-4_monitoring.md`

---

#### 📅 Day 5-6: 生产级线程池整合（10小时）

**Day 5（5小时）- 整合所有特性**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-3:00 | 代码整合 | 整合工作窃取、优先级、监控等特性 |
| 3:00-5:00 | 接口优化 | 设计易用的 API |

**动手实验 4-3：生产级线程池**
```cpp
// production_thread_pool.hpp
#pragma once
#include <thread>
#include <vector>
#include <queue>
#include <functional>
#include <future>
#include <mutex>
#include <condition_variable>
#include <atomic>
#include <chrono>
#include <optional>
#include "thread_pool_metrics.hpp"

class ProductionThreadPool {
public:
    struct Config {
        size_t core_threads = std::thread::hardware_concurrency();
        size_t max_threads = std::thread::hardware_concurrency() * 2;
        std::chrono::seconds keep_alive{60};
        size_t queue_capacity = 10000;
        bool enable_work_stealing = true;
        bool enable_metrics = true;
    };

    enum class Priority { Low = 0, Normal = 1, High = 2, Critical = 3 };

private:
    struct Task {
        std::function<void()> func;
        Priority priority;
        std::chrono::steady_clock::time_point submit_time;
        uint64_t sequence;

        bool operator<(const Task& other) const {
            if (priority != other.priority) return priority < other.priority;
            return sequence > other.sequence;
        }
    };

    Config config_;
    std::priority_queue<Task> tasks_;
    std::vector<std::thread> workers_;
    mutable std::mutex mutex_;
    std::condition_variable cv_;
    std::atomic<bool> stop_{false};
    std::atomic<uint64_t> sequence_{0};
    std::atomic<size_t> active_count_{0};

    std::unique_ptr<ThreadPoolMetrics> metrics_;

    void worker_loop() {
        while (!stop_) {
            Task task;
            {
                std::unique_lock<std::mutex> lock(mutex_);
                cv_.wait(lock, [this] { return stop_ || !tasks_.empty(); });

                if (stop_ && tasks_.empty()) return;
                if (tasks_.empty()) continue;

                task = std::move(const_cast<Task&>(tasks_.top()));
                tasks_.pop();
            }

            // 记录排队延迟
            if (metrics_) {
                auto queue_time = std::chrono::steady_clock::now() - task.submit_time;
                metrics_->record_queue_latency(
                    std::chrono::duration_cast<std::chrono::nanoseconds>(queue_time));
            }

            ++active_count_;
            auto exec_start = std::chrono::steady_clock::now();

            try {
                task.func();
                if (metrics_) metrics_->task_completed();
            } catch (...) {
                if (metrics_) metrics_->task_failed();
            }

            // 记录执行延迟
            if (metrics_) {
                auto exec_time = std::chrono::steady_clock::now() - exec_start;
                metrics_->record_exec_latency(
                    std::chrono::duration_cast<std::chrono::nanoseconds>(exec_time));
            }

            --active_count_;
        }
    }

public:
    explicit ProductionThreadPool(Config config = Config{})
        : config_(config) {
        if (config_.enable_metrics) {
            metrics_ = std::make_unique<ThreadPoolMetrics>();
        }

        for (size_t i = 0; i < config_.core_threads; ++i) {
            workers_.emplace_back(&ProductionThreadPool::worker_loop, this);
        }
    }

    ~ProductionThreadPool() {
        shutdown();
    }

    void shutdown() {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            stop_ = true;
        }
        cv_.notify_all();
        for (auto& w : workers_) {
            if (w.joinable()) w.join();
        }
    }

    template <typename F, typename... Args>
    auto submit(F&& f, Args&&... args) {
        return submit(Priority::Normal, std::forward<F>(f), std::forward<Args>(args)...);
    }

    template <typename F, typename... Args>
    auto submit(Priority priority, F&& f, Args&&... args)
        -> std::future<std::invoke_result_t<F, Args...>>
    {
        using R = std::invoke_result_t<F, Args...>;
        auto task = std::make_shared<std::packaged_task<R()>>(
            std::bind(std::forward<F>(f), std::forward<Args>(args)...));
        std::future<R> result = task->get_future();

        {
            std::lock_guard<std::mutex> lock(mutex_);
            if (stop_) throw std::runtime_error("Pool is stopped");

            tasks_.push(Task{
                [task]() { (*task)(); },
                priority,
                std::chrono::steady_clock::now(),
                sequence_++
            });
        }

        if (metrics_) metrics_->task_submitted();
        cv_.notify_one();
        return result;
    }

    // 监控接口
    const ThreadPoolMetrics* metrics() const { return metrics_.get(); }

    size_t active_count() const { return active_count_.load(); }
    size_t pool_size() const { return workers_.size(); }
    size_t queue_size() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return tasks_.size();
    }
};
```

**Day 6（5小时）- 综合测试与文档**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 综合测试 | 编写完整的测试套件 |
| 2:00-4:00 | 压力测试 | 长时间高负载测试 |
| 4:00-5:00 | 文档整理 | 编写使用文档 |

**Day 5-6 检验标准**：
- [ ] 整合所有特性到生产级线程池
- [ ] 通过完整的测试套件
- [ ] 通过长时间压力测试

**今日输出物**：
- [ ] `production_thread_pool.hpp`
- [ ] `test_production_pool.cpp`
- [ ] `benchmark_suite.cpp`

---

#### 📅 Day 7: 第四周总结与项目收尾（5小时）

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 对比分析 | 与 Java/Go/Rust 线程池实现对比 |
| 2:00-3:30 | 最佳实践 | 总结线程池使用的最佳实践 |
| 3:30-5:00 | 项目整理 | 整理代码和文档 |

**与主流实现对比**：
```
┌──────────────┬────────────────┬──────────────┬──────────────┐
│ 特性         │ 我们的实现     │ Java FJP     │ Go Runtime   │
├──────────────┼────────────────┼──────────────┼──────────────┤
│ 工作窃取     │ ✓              │ ✓            │ ✓            │
│ 动态扩缩容   │ ✓              │ ✓            │ ✓            │
│ 优先级       │ ✓              │ ✗            │ ✗            │
│ 任务依赖     │ ✓              │ ✗            │ ✗            │
│ 监控指标     │ ✓              │ ✓            │ 内置pprof    │
│ 协程支持     │ ✗              │ ✗            │ ✓            │
└──────────────┴────────────────┴──────────────┴──────────────┘
```

**第四周输出物汇总**：
1. `adaptive_thread_pool.hpp` - 自适应线程池
2. `thread_pool_metrics.hpp` - 监控指标
3. `production_thread_pool.hpp` - 生产级线程池
4. `test_*.cpp` / `benchmark_*.cpp` - 测试文件
5. `notes/week4/` - 本周笔记

---

## 检验标准

### 知识检验

- [ ] 能解释线程池四大核心组件的职责
- [ ] 理解 future/promise/packaged_task 的区别和联系
- [ ] 能解释工作窃取相比传统线程池的优势
- [ ] 理解 Chase-Lev Deque 的每个操作及其内存序
- [ ] 理解 Fork/Join 模式的核心思想
- [ ] 能解释优先级反转和饥饿问题
- [ ] 理解 DAG 在任务调度中的应用
- [ ] 理解时间轮算法的优势
- [ ] 理解动态扩缩容的策略和参数

### 实践检验

- [ ] 实现基础线程池，支持任务提交和关闭
- [ ] 实现返回 future 的 submit 方法
- [ ] 实现优雅关闭和立即关闭
- [ ] 实现 Chase-Lev 无锁 Deque
- [ ] 实现工作窃取线程池
- [ ] 实现优先级线程池
- [ ] 实现任务依赖图
- [ ] 实现延迟任务调度
- [ ] 实现动态扩缩容
- [ ] 实现监控指标收集
- [ ] 所有实现通过 ThreadSanitizer 检测

### 输出物清单

**核心代码**：
1. `thread_safe_queue.hpp` - 线程安全队列
2. `basic_thread_pool.hpp` - 基础线程池
3. `thread_pool_with_future.hpp` - 支持返回值的线程池
4. `lifecycle_thread_pool.hpp` - 完整生命周期管理
5. `simple_ws_deque.hpp` - 简化版工作窃取队列
6. `chase_lev_deque.hpp` - 无锁 Chase-Lev Deque
7. `work_stealing_pool.hpp` - 工作窃取线程池
8. `priority_thread_pool.hpp` - 优先级线程池
9. `task_graph.hpp` - 任务依赖图
10. `scheduled_thread_pool.hpp` - 定时任务线程池
11. `adaptive_thread_pool.hpp` - 自适应线程池
12. `thread_pool_metrics.hpp` - 监控指标
13. `production_thread_pool.hpp` - 生产级线程池

**测试与基准**：
14. `test_*.cpp` - 单元测试
15. `benchmark_*.cpp` - 性能基准测试

**学习笔记**：
16. `notes/week1/` - 第一周笔记
17. `notes/week2/` - 第二周笔记
18. `notes/week3/` - 第三周笔记
19. `notes/week4/` - 第四周笔记
20. `notes/month19_summary.md` - 月度总结

---

## 时间分配（140小时/月）

| 内容 | 时间 | 占比 |
|------|------|------|
| 理论学习 | 35小时 | 25% |
| 代码实现 | 60小时 | 43% |
| 测试调试 | 25小时 | 18% |
| 源码阅读 | 10小时 | 7% |
| 笔记整理 | 10小时 | 7% |

---

## 下月预告

Month 20 将学习 **Actor 模型与消息传递**，探索另一种并发编程范式。Actor 模型通过消息传递而非共享内存来实现并发，避免了锁的复杂性，是 Erlang、Akka 等系统的核心理念。
