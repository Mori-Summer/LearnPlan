# Month 21: C++20协程基础——无栈协程的革命

## 本月主题概述

C++20引入的协程是一种可以暂停和恢复执行的函数。与传统线程相比，协程更轻量，非常适合异步I/O和生成器模式。本月将深入学习协程的底层原理、Promise/Awaitable机制、异步Task系统，以及Channel等高级并发原语。

### 学习目标

1. **理解协程本质**：掌握编译器如何将协程转换为状态机
2. **Promise机制**：完整理解promise_type的每个接口
3. **Awaitable设计**：掌握对称转移等高级技术
4. **实战应用**：实现生产级的Task、Generator、Channel

### 前置知识

- Month 19 线程池设计（理解异步执行模型）
- Month 20 Actor模型（理解消息传递思想）
- C++模板元编程基础
- 移动语义和完美转发

---

## 第一周：协程核心原理（Day 1-7）

> **本周目标**：深入理解C++20协程的底层机制，掌握编译器转换原理和Promise接口

### Day 1-2：协程概念与编译器转换

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | 协程历史与分类 | 2h |
| 下午 | 编译器转换原理 | 3h |
| 晚上 | 协程帧分析实验 | 2h |

#### 1. 协程的历史与分类

**什么是协程？**

协程（Coroutine）是一种可以暂停执行并在稍后恢复的函数。与普通函数不同，协程可以在执行过程中"让出"控制权，保存当前状态，稍后从暂停点继续执行。

```
普通函数调用：
    main() --调用--> func() --返回--> main()
                      ↓
                    一次性执行完毕

协程调用：
    main() --调用--> coro() --暂停--> main()
              ↑                         |
              |                         |
              +-------恢复--------------+
                      ↓
                    继续执行
```

**有栈协程 vs 无栈协程**

```cpp
// ============================================================
// 协程分类对比
// ============================================================

/*
┌─────────────────────────────────────────────────────────────┐
│                    协程分类                                  │
├─────────────────────┬───────────────────────────────────────┤
│     有栈协程         │           无栈协程                    │
│   (Stackful)        │         (Stackless)                   │
├─────────────────────┼───────────────────────────────────────┤
│ • 每个协程有独立栈    │ • 不需要独立栈                        │
│ • 可在任意位置暂停    │ • 只能在特定点暂停                    │
│ • 内存开销大(KB级)   │ • 内存开销小(字节级)                  │
│ • 实现：Boost.Context│ • 实现：C++20协程、Python生成器       │
│ • 切换：保存/恢复栈  │ • 切换：状态机跳转                    │
├─────────────────────┼───────────────────────────────────────┤
│ 代表：              │ 代表：                                │
│ • Go goroutine      │ • C++20 coroutines                   │
│ • Lua coroutine     │ • Rust async/await                   │
│ • Boost.Fiber       │ • JavaScript generators              │
└─────────────────────┴───────────────────────────────────────┘
*/

// C++20选择无栈协程的原因：
// 1. 零开销抽象：不用时不付出代价
// 2. 确定性内存：编译期可知协程帧大小
// 3. 优化友好：编译器可进行更多优化
```

#### 2. C++20协程的三个关键字

```cpp
#include <coroutine>
#include <iostream>

// ============================================================
// C++20协程的三个关键字
// ============================================================

// co_await: 暂停协程，等待某个操作完成
// co_yield: 产出一个值并暂停
// co_return: 返回值并结束协程

// 任何包含这三个关键字之一的函数都是协程
// 编译器会自动将其转换为状态机

// 示例：包含co_yield的函数自动成为协程
struct SimpleGenerator {
    struct promise_type {
        int value;

        SimpleGenerator get_return_object() {
            return SimpleGenerator{
                std::coroutine_handle<promise_type>::from_promise(*this)
            };
        }
        std::suspend_always initial_suspend() { return {}; }
        std::suspend_always final_suspend() noexcept { return {}; }
        std::suspend_always yield_value(int v) {
            value = v;
            return {};
        }
        void return_void() {}
        void unhandled_exception() { std::terminate(); }
    };

    std::coroutine_handle<promise_type> handle;

    explicit SimpleGenerator(std::coroutine_handle<promise_type> h) : handle(h) {}
    ~SimpleGenerator() { if (handle) handle.destroy(); }

    // 禁止拷贝
    SimpleGenerator(const SimpleGenerator&) = delete;
    SimpleGenerator& operator=(const SimpleGenerator&) = delete;

    // 允许移动
    SimpleGenerator(SimpleGenerator&& other) noexcept
        : handle(other.handle) { other.handle = nullptr; }
};

// 这是一个协程（包含co_yield）
SimpleGenerator count_up_to(int n) {
    for (int i = 1; i <= n; ++i) {
        co_yield i;  // 产出值并暂停
    }
    // 隐式 co_return;
}
```

#### 3. 编译器转换原理

```cpp
// ============================================================
// 编译器如何转换协程
// ============================================================

// 原始协程代码：
SimpleGenerator count_up_to(int n) {
    for (int i = 1; i <= n; ++i) {
        co_yield i;
    }
}

// 编译器转换后的伪代码（概念性展示）：
/*
struct __count_up_to_frame {
    // Promise对象
    SimpleGenerator::promise_type __promise;

    // 参数副本
    int n;

    // 局部变量
    int i;

    // 状态机状态
    int __suspend_index;

    // 恢复点（用于跳转）
    void* __resume_address;
};

SimpleGenerator count_up_to(int n) {
    // 1. 分配协程帧
    __count_up_to_frame* __frame =
        new __count_up_to_frame{};

    // 2. 复制参数到帧中
    __frame->n = n;

    // 3. 构造promise
    new (&__frame->__promise) promise_type{};

    // 4. 获取返回对象
    SimpleGenerator __return =
        __frame->__promise.get_return_object();

    // 5. 执行initial_suspend
    co_await __frame->__promise.initial_suspend();

    // 6. 协程体（转换为状态机）
    try {
        for (__frame->i = 1; __frame->i <= __frame->n; ++__frame->i) {
            co_await __frame->__promise.yield_value(__frame->i);
        }
        __frame->__promise.return_void();
    } catch (...) {
        __frame->__promise.unhandled_exception();
    }

    // 7. 执行final_suspend
    co_await __frame->__promise.final_suspend();

    return __return;
}
*/
```

#### 4. 协程帧（Coroutine Frame）详解

```cpp
// ============================================================
// 协程帧结构分析
// ============================================================

/*
协程帧内存布局（概念性）：

┌─────────────────────────────────────────────┐
│              Coroutine Frame                │
├─────────────────────────────────────────────┤
│  Resume Function Pointer (恢复函数指针)      │  8 bytes
├─────────────────────────────────────────────┤
│  Destroy Function Pointer (销毁函数指针)     │  8 bytes
├─────────────────────────────────────────────┤
│  Promise Object (promise对象)               │  varies
├─────────────────────────────────────────────┤
│  Parameters (参数副本)                       │  varies
├─────────────────────────────────────────────┤
│  Local Variables (局部变量)                  │  varies
├─────────────────────────────────────────────┤
│  Suspend Point Index (暂停点索引)            │  4 bytes
├─────────────────────────────────────────────┤
│  Temporaries (临时对象)                      │  varies
└─────────────────────────────────────────────┘
*/

// 协程句柄操作
void demonstrate_coroutine_handle() {
    auto gen = count_up_to(5);

    // coroutine_handle 是一个轻量级指针
    auto& handle = gen.handle;

    // 检查协程是否完成
    bool done = handle.done();

    // 恢复协程执行
    if (!done) {
        handle.resume();  // 或 handle()
    }

    // 访问promise
    auto& promise = handle.promise();
    std::cout << "Current value: " << promise.value << "\n";

    // 获取地址（用于调试）
    void* addr = handle.address();

    // 从地址重建句柄
    auto reconstructed =
        std::coroutine_handle<SimpleGenerator::promise_type>::from_address(addr);

    // 销毁协程（释放帧）
    // handle.destroy();  // 在析构函数中调用
}
```

#### 5. 协程与普通函数的对比

```cpp
// ============================================================
// 协程 vs 普通函数 vs 线程
// ============================================================

#include <thread>
#include <vector>
#include <chrono>

// 普通函数：一次性执行完毕
std::vector<int> generate_numbers_func(int n) {
    std::vector<int> result;
    for (int i = 1; i <= n; ++i) {
        result.push_back(i);
    }
    return result;  // 必须生成所有数据后才能返回
}

// 协程：按需生成，惰性求值
SimpleGenerator generate_numbers_coro(int n) {
    for (int i = 1; i <= n; ++i) {
        co_yield i;  // 每次只生成一个，按需获取
    }
}

// 线程：并发执行，需要同步
void generate_numbers_thread(int n, std::vector<int>& result, std::mutex& mtx) {
    for (int i = 1; i <= n; ++i) {
        std::lock_guard<std::mutex> lock(mtx);
        result.push_back(i);
    }
}

/*
对比总结：

┌──────────┬────────────┬────────────┬────────────┐
│          │  普通函数   │    协程    │    线程    │
├──────────┼────────────┼────────────┼────────────┤
│ 内存     │ 栈上分配    │ 堆上协程帧  │ 独立栈     │
│ 开销     │ 最小       │ 较小       │ 最大(KB+)  │
├──────────┼────────────┼────────────┼────────────┤
│ 切换成本 │ 无         │ 状态机跳转  │ 上下文切换  │
│          │            │ (纳秒级)   │ (微秒级)   │
├──────────┼────────────┼────────────┼────────────┤
│ 数据流   │ 一次性返回  │ 按需产出    │ 需要同步   │
├──────────┼────────────┼────────────┼────────────┤
│ 适用场景 │ 简单计算    │ 生成器/异步 │ 并行计算   │
└──────────┴────────────┴────────────┴────────────┘
*/
```

### Day 3-4：Promise Type 完整接口

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | Promise必需接口 | 2h |
| 下午 | Promise可选接口 | 3h |
| 晚上 | 自定义Promise实验 | 2h |

#### 1. Promise Type 概述

```cpp
// ============================================================
// Promise Type：协程的控制中心
// ============================================================

/*
Promise Type 是协程的"大脑"，它控制：
1. 协程如何创建返回对象
2. 协程何时暂停（开始/结束时）
3. 如何处理 co_yield 和 co_return
4. 如何处理异常
5. 如何自定义 co_await 行为

Promise Type 必需成员：
- get_return_object()
- initial_suspend()
- final_suspend()
- unhandled_exception()
- return_void() 或 return_value()

Promise Type 可选成员：
- yield_value()
- await_transform()
- get_return_object_on_allocation_failure()
*/

// 完整的Promise Type模板
template<typename T>
struct FullPromise {
    // ========== 必需成员 ==========

    // 1. 创建返回给调用者的对象
    T get_return_object();

    // 2. 协程开始时是否暂停
    std::suspend_always initial_suspend();  // 或 suspend_never

    // 3. 协程结束时是否暂停
    std::suspend_always final_suspend() noexcept;  // 必须noexcept

    // 4. 处理未捕获的异常
    void unhandled_exception();

    // 5. 处理co_return（二选一）
    void return_void();                    // 用于 co_return;
    // void return_value(SomeType value); // 用于 co_return value;

    // ========== 可选成员 ==========

    // 6. 处理co_yield
    std::suspend_always yield_value(int value);

    // 7. 自定义co_await行为
    template<typename U>
    auto await_transform(U&& value);

    // 8. 分配失败时的处理
    static T get_return_object_on_allocation_failure();

    // 9. 自定义内存分配
    void* operator new(std::size_t size);
    void operator delete(void* ptr);
};
```

#### 2. 详解每个Promise接口

```cpp
// ============================================================
// get_return_object()：创建协程返回对象
// ============================================================

struct MyCoroutine {
    struct promise_type {
        // 在协程开始执行前调用
        // 返回值会作为协程函数的返回值
        MyCoroutine get_return_object() {
            // 从promise创建coroutine_handle
            auto handle = std::coroutine_handle<promise_type>::from_promise(*this);
            return MyCoroutine{handle};
        }
        // ...
    };

    std::coroutine_handle<promise_type> handle_;
    explicit MyCoroutine(std::coroutine_handle<promise_type> h) : handle_(h) {}
};

// ============================================================
// initial_suspend()：控制协程启动行为
// ============================================================

struct EagerPromise {
    // 立即开始执行（不暂停）
    std::suspend_never initial_suspend() { return {}; }
};

struct LazyPromise {
    // 延迟执行（先暂停，等待resume）
    std::suspend_always initial_suspend() { return {}; }
};

// 自定义启动行为
struct ConditionalStartPromise {
    bool should_start_immediately = false;

    auto initial_suspend() {
        struct ConditionalAwaiter {
            bool start_now;
            bool await_ready() { return start_now; }
            void await_suspend(std::coroutine_handle<>) {}
            void await_resume() {}
        };
        return ConditionalAwaiter{should_start_immediately};
    }
};

// ============================================================
// final_suspend()：控制协程结束行为
// ============================================================

struct BasicPromise {
    // 结束时暂停（需要手动destroy）
    std::suspend_always final_suspend() noexcept { return {}; }

    // 或者：结束时不暂停（自动销毁）
    // std::suspend_never final_suspend() noexcept { return {}; }
    // 注意：suspend_never会导致协程帧自动释放
    //       此时不能再访问promise或handle！
};

// 带continuation的final_suspend（对称转移）
struct ContinuationPromise {
    std::coroutine_handle<> continuation;

    auto final_suspend() noexcept {
        struct FinalAwaiter {
            std::coroutine_handle<> cont;

            bool await_ready() noexcept { return false; }

            // 返回要恢复的协程句柄
            std::coroutine_handle<> await_suspend(
                std::coroutine_handle<ContinuationPromise> h) noexcept {
                if (cont) return cont;
                return std::noop_coroutine();  // 无continuation则结束
            }

            void await_resume() noexcept {}
        };
        return FinalAwaiter{continuation};
    }
};

// ============================================================
// yield_value()：处理co_yield
// ============================================================

struct GeneratorPromise {
    int current_value;
    std::exception_ptr exception;

    // co_yield value; 会调用此方法
    std::suspend_always yield_value(int value) {
        current_value = value;
        return {};  // 暂停，让调用者获取值
    }

    // 也可以返回自定义Awaiter
    auto yield_value(std::string value) {
        struct YieldAwaiter {
            std::string& storage;
            std::string val;

            bool await_ready() { return false; }
            void await_suspend(std::coroutine_handle<>) {
                storage = std::move(val);
            }
            void await_resume() {}
        };
        // ...
    }
};

// ============================================================
// return_void() / return_value()：处理co_return
// ============================================================

// 用于不返回值的协程
struct VoidPromise {
    void return_void() {
        // co_return; 或协程自然结束时调用
    }
};

// 用于返回值的协程
struct ValuePromise {
    std::optional<int> result;

    void return_value(int value) {
        result = value;
    }
};

// 注意：不能同时定义return_void和return_value！

// ============================================================
// unhandled_exception()：异常处理
// ============================================================

struct ExceptionHandlingPromise {
    std::exception_ptr exception;

    void unhandled_exception() {
        // 方式1：保存异常，稍后重新抛出
        exception = std::current_exception();

        // 方式2：立即终止
        // std::terminate();

        // 方式3：记录日志后继续
        // try {
        //     throw;
        // } catch (const std::exception& e) {
        //     log_error(e.what());
        // }
    }
};

// ============================================================
// await_transform()：自定义co_await行为
// ============================================================

struct TransformingPromise {
    // 所有co_await表达式都会经过此转换
    template<typename T>
    auto await_transform(T&& value) {
        // 可以包装、修改或拒绝某些类型
        return std::forward<T>(value);
    }

    // 禁止await某些类型
    template<typename T>
    auto await_transform(std::future<T>&) = delete;  // 禁止await std::future

    // 为特定类型提供特殊处理
    auto await_transform(std::chrono::milliseconds duration) {
        return SleepAwaiter{duration};  // 自动将duration转为SleepAwaiter
    }
};
```

#### 3. 自定义内存分配

```cpp
// ============================================================
// Promise的自定义内存分配
// ============================================================

#include <memory_resource>

struct CustomAllocPromise {
    // 自定义operator new
    void* operator new(std::size_t size) {
        std::cout << "Allocating coroutine frame: " << size << " bytes\n";
        return ::operator new(size);
    }

    void operator delete(void* ptr) {
        std::cout << "Deallocating coroutine frame\n";
        ::operator delete(ptr);
    }

    // 带分配器参数的new（用于状态ful分配器）
    template<typename... Args>
    void* operator new(std::size_t size,
                       std::allocator_arg_t,
                       std::pmr::memory_resource* mr,
                       Args&&...) {
        return mr->allocate(size);
    }

    // 对应的delete
    template<typename... Args>
    void operator delete(void* ptr, std::size_t size,
                        std::allocator_arg_t,
                        std::pmr::memory_resource* mr,
                        Args&&...) {
        mr->deallocate(ptr, size);
    }

    // 分配失败时的处理
    static auto get_return_object_on_allocation_failure() {
        return MyCoroutine{nullptr};  // 返回空对象
    }

    // ... 其他必需成员 ...
};

// 使用自定义分配器的协程
MyCoroutine coro_with_allocator(std::allocator_arg_t,
                                 std::pmr::memory_resource* mr,
                                 int param) {
    co_return;
}
```

### Day 5-6：基础 Generator 实现

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | Generator设计 | 2h |
| 下午 | 迭代器支持 | 3h |
| 晚上 | 嵌套Generator | 2h |

#### 1. 完整的Generator实现

```cpp
// ============================================================
// generator.hpp - 生产级Generator实现
// ============================================================

#pragma once
#include <coroutine>
#include <exception>
#include <iterator>
#include <utility>

template<typename T>
class Generator {
public:
    struct promise_type {
        T current_value;
        std::exception_ptr exception;

        Generator get_return_object() {
            return Generator{
                std::coroutine_handle<promise_type>::from_promise(*this)
            };
        }

        // 惰性启动：创建后不立即执行
        std::suspend_always initial_suspend() noexcept { return {}; }

        // 结束时暂停：允许最后一次访问值
        std::suspend_always final_suspend() noexcept { return {}; }

        // 处理 co_yield value
        std::suspend_always yield_value(T value) noexcept(
            std::is_nothrow_move_constructible_v<T>) {
            current_value = std::move(value);
            return {};
        }

        // Generator不使用co_return value
        void return_void() noexcept {}

        void unhandled_exception() {
            exception = std::current_exception();
        }

        // 禁止在Generator中co_await
        template<typename U>
        std::suspend_never await_transform(U&&) = delete;
    };

    // RAII句柄管理
    using handle_type = std::coroutine_handle<promise_type>;

private:
    handle_type handle_;

public:
    explicit Generator(handle_type h) : handle_(h) {}

    ~Generator() {
        if (handle_) {
            handle_.destroy();
        }
    }

    // 禁止拷贝
    Generator(const Generator&) = delete;
    Generator& operator=(const Generator&) = delete;

    // 允许移动
    Generator(Generator&& other) noexcept
        : handle_(std::exchange(other.handle_, nullptr)) {}

    Generator& operator=(Generator&& other) noexcept {
        if (this != &other) {
            if (handle_) handle_.destroy();
            handle_ = std::exchange(other.handle_, nullptr);
        }
        return *this;
    }

    // ========== 迭代器支持 ==========

    class iterator {
    public:
        using iterator_category = std::input_iterator_tag;
        using difference_type = std::ptrdiff_t;
        using value_type = T;
        using reference = T&;
        using pointer = T*;

    private:
        handle_type handle_;

    public:
        iterator() noexcept : handle_(nullptr) {}
        explicit iterator(handle_type h) noexcept : handle_(h) {}

        // 前进到下一个值
        iterator& operator++() {
            handle_.resume();
            if (handle_.done()) {
                // 检查是否有异常
                if (handle_.promise().exception) {
                    std::rethrow_exception(handle_.promise().exception);
                }
                handle_ = nullptr;
            }
            return *this;
        }

        iterator operator++(int) {
            auto tmp = *this;
            ++(*this);
            return tmp;
        }

        // 获取当前值
        reference operator*() const {
            return handle_.promise().current_value;
        }

        pointer operator->() const {
            return std::addressof(handle_.promise().current_value);
        }

        // 比较
        bool operator==(const iterator& other) const noexcept {
            return handle_ == other.handle_;
        }

        bool operator!=(const iterator& other) const noexcept {
            return !(*this == other);
        }
    };

    // begin：恢复协程获取第一个值
    iterator begin() {
        if (handle_) {
            handle_.resume();
            if (handle_.done()) {
                if (handle_.promise().exception) {
                    std::rethrow_exception(handle_.promise().exception);
                }
                return end();
            }
        }
        return iterator{handle_};
    }

    // end：空迭代器
    iterator end() noexcept {
        return iterator{};
    }

    // ========== 手动迭代接口 ==========

    bool next() {
        if (handle_ && !handle_.done()) {
            handle_.resume();
            if (handle_.promise().exception) {
                std::rethrow_exception(handle_.promise().exception);
            }
            return !handle_.done();
        }
        return false;
    }

    T& value() {
        return handle_.promise().current_value;
    }

    const T& value() const {
        return handle_.promise().current_value;
    }

    bool done() const noexcept {
        return !handle_ || handle_.done();
    }
};
```

#### 2. Generator使用示例

```cpp
// ============================================================
// Generator使用示例
// ============================================================

#include "generator.hpp"
#include <iostream>
#include <string>
#include <vector>

// 简单的数字生成器
Generator<int> range(int start, int end) {
    for (int i = start; i < end; ++i) {
        co_yield i;
    }
}

// 斐波那契数列
Generator<long long> fibonacci(int count) {
    long long a = 0, b = 1;
    for (int i = 0; i < count; ++i) {
        co_yield a;
        auto next = a + b;
        a = b;
        b = next;
    }
}

// 字符串分割
Generator<std::string_view> split(std::string_view str, char delimiter) {
    size_t start = 0;
    size_t end = str.find(delimiter);

    while (end != std::string_view::npos) {
        co_yield str.substr(start, end - start);
        start = end + 1;
        end = str.find(delimiter, start);
    }

    co_yield str.substr(start);
}

// 文件行读取（模拟）
Generator<std::string> read_lines(const std::vector<std::string>& lines) {
    for (const auto& line : lines) {
        co_yield line;
    }
}

// 使用示例
void generator_examples() {
    std::cout << "=== Range ===" << std::endl;
    for (int n : range(1, 6)) {
        std::cout << n << " ";  // 1 2 3 4 5
    }
    std::cout << "\n";

    std::cout << "=== Fibonacci ===" << std::endl;
    for (auto fib : fibonacci(10)) {
        std::cout << fib << " ";  // 0 1 1 2 3 5 8 13 21 34
    }
    std::cout << "\n";

    std::cout << "=== Split ===" << std::endl;
    for (auto part : split("hello,world,foo,bar", ',')) {
        std::cout << "[" << part << "] ";
    }
    std::cout << "\n";

    std::cout << "=== Manual iteration ===" << std::endl;
    auto gen = range(10, 15);
    while (gen.next()) {
        std::cout << gen.value() << " ";
    }
    std::cout << "\n";
}
```

#### 3. 递归Generator（元素展平）

```cpp
// ============================================================
// 递归Generator：展平嵌套容器
// ============================================================

#include <variant>
#include <vector>

// 递归展平嵌套vector
template<typename T>
Generator<T> flatten(const std::vector<T>& vec) {
    for (const auto& item : vec) {
        co_yield item;
    }
}

template<typename T>
Generator<T> flatten(const std::vector<std::vector<T>>& nested) {
    for (const auto& inner : nested) {
        // 手动展开内部generator
        for (auto& item : flatten(inner)) {
            co_yield item;
        }
    }
}

// 使用示例
void flatten_example() {
    std::vector<std::vector<int>> nested = {
        {1, 2, 3},
        {4, 5},
        {6, 7, 8, 9}
    };

    std::cout << "Flattened: ";
    for (int n : flatten(nested)) {
        std::cout << n << " ";  // 1 2 3 4 5 6 7 8 9
    }
    std::cout << "\n";
}

// ============================================================
// 树遍历Generator
// ============================================================

struct TreeNode {
    int value;
    TreeNode* left = nullptr;
    TreeNode* right = nullptr;
};

// 中序遍历
Generator<int> inorder(TreeNode* node) {
    if (!node) co_return;

    // 遍历左子树
    for (int val : inorder(node->left)) {
        co_yield val;
    }

    // 当前节点
    co_yield node->value;

    // 遍历右子树
    for (int val : inorder(node->right)) {
        co_yield val;
    }
}

// 前序遍历
Generator<int> preorder(TreeNode* node) {
    if (!node) co_return;

    co_yield node->value;

    for (int val : preorder(node->left)) {
        co_yield val;
    }

    for (int val : preorder(node->right)) {
        co_yield val;
    }
}

// 层序遍历
Generator<int> levelorder(TreeNode* root) {
    if (!root) co_return;

    std::queue<TreeNode*> queue;
    queue.push(root);

    while (!queue.empty()) {
        TreeNode* node = queue.front();
        queue.pop();

        co_yield node->value;

        if (node->left) queue.push(node->left);
        if (node->right) queue.push(node->right);
    }
}
```

### Day 7：论文精读与周总结

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | N4680提案阅读 | 2h |
| 下午 | 多语言协程对比 | 2h |
| 晚上 | 周总结与练习 | 2h |

#### 1. C++协程提案要点

```cpp
// ============================================================
// N4680 协程提案关键点
// ============================================================

/*
C++20协程的设计原则：

1. 零开销抽象
   - 协程帧大小在编译期确定
   - 可以被优化器内联和优化
   - 不使用时不产生任何开销

2. 库作者友好
   - 协程机制是"半成品"，需要库来完善
   - Promise Type 给予库作者完全控制
   - 可以实现各种协程模式

3. 灵活性
   - 支持生成器、任务、异步流等多种模式
   - 可以自定义内存分配
   - 可以与现有代码无缝集成

核心概念回顾：

┌─────────────────────────────────────────────────────┐
│                    协程架构                          │
├─────────────────────────────────────────────────────┤
│                                                     │
│   Coroutine Function                                │
│   (包含 co_await/co_yield/co_return 的函数)          │
│          │                                          │
│          ▼                                          │
│   ┌─────────────────┐                               │
│   │ Coroutine Frame │ ◄── 编译器生成的状态机         │
│   │  - Promise      │                               │
│   │  - Parameters   │                               │
│   │  - Locals       │                               │
│   │  - State        │                               │
│   └────────┬────────┘                               │
│            │                                        │
│            ▼                                        │
│   ┌─────────────────┐                               │
│   │ coroutine_handle│ ◄── 轻量级句柄（指针）         │
│   └────────┬────────┘                               │
│            │                                        │
│            ▼                                        │
│   ┌─────────────────┐                               │
│   │  Return Object  │ ◄── 用户看到的协程对象         │
│   │  (Generator等)  │     (封装了handle)             │
│   └─────────────────┘                               │
│                                                     │
└─────────────────────────────────────────────────────┘
*/
```

#### 2. 与其他语言协程对比

```cpp
// ============================================================
// 多语言协程对比
// ============================================================

/*
┌─────────────┬─────────────┬─────────────┬─────────────┐
│   特性       │   C++20     │   Python    │    Rust     │
├─────────────┼─────────────┼─────────────┼─────────────┤
│ 协程类型     │ 无栈        │ 无栈        │ 无栈        │
├─────────────┼─────────────┼─────────────┼─────────────┤
│ 关键字       │ co_await    │ await       │ .await      │
│             │ co_yield    │ yield       │ yield       │
│             │ co_return   │ return      │ return      │
├─────────────┼─────────────┼─────────────┼─────────────┤
│ 运行时       │ 无（库实现） │ asyncio    │ tokio等     │
├─────────────┼─────────────┼─────────────┼─────────────┤
│ Promise等价  │ promise_type│ __aiter__等 │ Future trait│
├─────────────┼─────────────┼─────────────┼─────────────┤
│ 内存分配     │ 可定制      │ 固定        │ 编译器优化  │
├─────────────┼─────────────┼─────────────┼─────────────┤
│ 类型安全     │ 模板       │ 动态类型    │ 静态类型    │
├─────────────┼─────────────┼─────────────┼─────────────┤
│ 生态成熟度   │ 发展中      │ 成熟        │ 成熟        │
└─────────────┴─────────────┴─────────────┴─────────────┘

Python协程示例（对比参考）：

async def fetch_data():
    await asyncio.sleep(1)
    return "data"

def generator():
    yield 1
    yield 2
    yield 3

C++等价实现需要更多代码，但提供：
1. 编译期类型安全
2. 零开销抽象
3. 完全的定制能力
*/
```

#### 第一周检验标准

- [ ] 能解释有栈协程和无栈协程的区别
- [ ] 理解编译器如何将协程转换为状态机
- [ ] 能说出Promise Type的所有必需和可选成员
- [ ] 能实现一个功能完整的Generator
- [ ] 能使用Generator实现树遍历等递归算法

---

## 第二周：Awaitable 深入（Day 8-14）

> **本周目标**：掌握Awaitable机制，理解对称转移技术，能实现各种自定义Awaitable

### Day 1-2（第8-9天）：Awaitable 三件套

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | Awaitable接口详解 | 2h |
| 下午 | await_suspend三种返回值 | 3h |
| 晚上 | 标准库Awaitable分析 | 2h |

#### 1. Awaitable 概念

```cpp
// ============================================================
// Awaitable：可被co_await的对象
// ============================================================

/*
当编译器遇到 co_await expr 时：

1. 首先检查promise是否有await_transform
   - 有：将expr转换为 promise.await_transform(expr)
   - 无：使用原始expr

2. 获取Awaiter对象
   - 如果expr有operator co_await()，调用它获取Awaiter
   - 否则expr本身就是Awaiter

3. 调用Awaiter的三个方法：
   - await_ready() -> bool
   - await_suspend(handle) -> void/bool/coroutine_handle
   - await_resume() -> T

执行流程：
┌─────────────────────────────────────────────────┐
│              co_await expr                      │
│                    │                            │
│                    ▼                            │
│         ┌─────────────────────┐                 │
│         │  await_ready()?     │                 │
│         └──────────┬──────────┘                 │
│                    │                            │
│         ┌─────────┴─────────┐                   │
│         │                   │                   │
│      true                false                  │
│         │                   │                   │
│         │         ┌─────────▼─────────┐         │
│         │         │  await_suspend()  │         │
│         │         └─────────┬─────────┘         │
│         │                   │                   │
│         │         协程暂停，控制权返回调用者       │
│         │                   │                   │
│         │         （等待恢复...）                │
│         │                   │                   │
│         └─────────┬─────────┘                   │
│                   │                             │
│         ┌─────────▼─────────┐                   │
│         │  await_resume()   │                   │
│         └─────────┬─────────┘                   │
│                   │                             │
│              返回结果                            │
└─────────────────────────────────────────────────┘
*/
```

#### 2. Awaitable 三件套详解

```cpp
// ============================================================
// awaitable.hpp - Awaitable工具集
// ============================================================

#pragma once
#include <coroutine>
#include <chrono>
#include <thread>
#include <optional>

// ============ await_ready() ============
// 返回true：操作已就绪，不需要暂停
// 返回false：需要暂停协程

struct AlwaysReady {
    bool await_ready() const noexcept { return true; }  // 从不暂停
    void await_suspend(std::coroutine_handle<>) noexcept {}
    void await_resume() noexcept {}
};

struct NeverReady {
    bool await_ready() const noexcept { return false; }  // 总是暂停
    void await_suspend(std::coroutine_handle<>) noexcept {}
    void await_resume() noexcept {}
};

// 条件就绪
template<typename T>
struct ConditionalAwaiter {
    std::optional<T>& result;

    bool await_ready() const noexcept {
        return result.has_value();  // 有值则就绪
    }

    void await_suspend(std::coroutine_handle<>) noexcept {
        // 等待result被填充
    }

    T await_resume() {
        return std::move(*result);
    }
};

// ============ await_suspend() 的三种返回值 ============

// 1. 返回void：无条件暂停
struct VoidSuspend {
    bool await_ready() { return false; }

    void await_suspend(std::coroutine_handle<> h) {
        // 协程将暂停
        // 可以在这里安排稍后恢复h
        // 例如：scheduler.schedule(h);
    }

    void await_resume() {}
};

// 2. 返回bool：条件暂停
struct BoolSuspend {
    bool should_suspend = true;

    bool await_ready() { return false; }

    bool await_suspend(std::coroutine_handle<> h) {
        // 返回true：暂停协程
        // 返回false：不暂停，立即继续执行
        if (should_suspend) {
            // 安排恢复
            return true;   // 暂停
        }
        return false;      // 不暂停，继续执行
    }

    void await_resume() {}
};

// 3. 返回coroutine_handle：对称转移
struct HandleSuspend {
    std::coroutine_handle<> next_coro;

    bool await_ready() { return false; }

    std::coroutine_handle<> await_suspend(std::coroutine_handle<> h) {
        // 返回要恢复的下一个协程
        // 这是对称转移的关键！
        if (next_coro) {
            return next_coro;  // 转移到next_coro
        }
        return std::noop_coroutine();  // 返回到调用者
    }

    void await_resume() {}
};

// ============ await_resume() ============
// 返回co_await表达式的值

template<typename T>
struct ValueAwaiter {
    T value;

    bool await_ready() { return true; }
    void await_suspend(std::coroutine_handle<>) {}

    T await_resume() {
        return std::move(value);  // co_await的结果
    }
};

// 返回引用
struct RefAwaiter {
    int& ref;

    bool await_ready() { return true; }
    void await_suspend(std::coroutine_handle<>) {}

    int& await_resume() {
        return ref;  // 返回引用
    }
};
```

#### 3. 标准库 Awaitable

```cpp
// ============================================================
// 标准库提供的两个Awaitable
// ============================================================

// std::suspend_always - 总是暂停
// 等价于：
struct suspend_always {
    constexpr bool await_ready() const noexcept { return false; }
    constexpr void await_suspend(std::coroutine_handle<>) const noexcept {}
    constexpr void await_resume() const noexcept {}
};

// std::suspend_never - 从不暂停
// 等价于：
struct suspend_never {
    constexpr bool await_ready() const noexcept { return true; }
    constexpr void await_suspend(std::coroutine_handle<>) const noexcept {}
    constexpr void await_resume() const noexcept {}
};

// 使用场景
struct MyPromise {
    // 立即执行
    std::suspend_never initial_suspend() { return {}; }

    // 结束时暂停（允许访问结果）
    std::suspend_always final_suspend() noexcept { return {}; }
};
```

### Day 3-4（第10-11天）：对称转移（Symmetric Transfer）

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | 对称转移原理 | 2h |
| 下午 | 避免栈溢出 | 3h |
| 晚上 | noop_coroutine详解 | 2h |

#### 1. 为什么需要对称转移？

```cpp
// ============================================================
// 问题：没有对称转移时的栈溢出
// ============================================================

// 假设我们有一个协程链：A -> B -> C -> D -> ...
// 每个协程完成后需要恢复前一个

// 不使用对称转移的实现
struct BadTask {
    struct promise_type {
        std::coroutine_handle<> continuation;

        auto final_suspend() noexcept {
            struct FinalAwaiter {
                promise_type* promise;

                bool await_ready() noexcept { return false; }

                // 问题：这会导致递归调用！
                void await_suspend(std::coroutine_handle<>) noexcept {
                    if (promise->continuation) {
                        promise->continuation.resume();  // 递归调用！
                    }
                }

                void await_resume() noexcept {}
            };
            return FinalAwaiter{this};
        }
        // ...
    };
};

/*
调用栈会不断增长：
main()
  └─ A.resume()
       └─ B.resume()
            └─ C.resume()
                 └─ D.resume()
                      └─ E.resume()
                           └─ ...
                                └─ 栈溢出！
*/
```

#### 2. 对称转移解决方案

```cpp
// ============================================================
// 对称转移：通过尾调用优化避免栈增长
// ============================================================

struct GoodTask {
    struct promise_type {
        std::coroutine_handle<> continuation;

        auto final_suspend() noexcept {
            struct FinalAwaiter {
                promise_type* promise;

                bool await_ready() noexcept { return false; }

                // 关键：返回coroutine_handle实现对称转移
                std::coroutine_handle<> await_suspend(
                    std::coroutine_handle<> h) noexcept {
                    if (promise->continuation) {
                        return promise->continuation;  // 转移，不是调用！
                    }
                    return std::noop_coroutine();  // 结束链
                }

                void await_resume() noexcept {}
            };
            return FinalAwaiter{this};
        }
        // ...
    };
};

/*
对称转移的执行模式：

不是：
main() -> A.resume() -> B.resume() -> C.resume() -> ...

而是：
main() -> A.resume()
main() -> B.resume()  (A结束，对称转移到B)
main() -> C.resume()  (B结束，对称转移到C)
main() -> D.resume()  (C结束，对称转移到D)

栈深度保持恒定！
*/

// 编译器会将对称转移优化为尾调用（tail call）
// 类似于：
// return continuation.resume();
// 而不是：
// continuation.resume();
// return;
```

#### 3. noop_coroutine 详解

```cpp
// ============================================================
// std::noop_coroutine：空操作协程
// ============================================================

/*
noop_coroutine是一个特殊的协程句柄：
- 调用resume()什么都不做
- 调用done()返回true
- 用于终止协程链

使用场景：
1. 对称转移的终止条件
2. 作为默认/空的continuation
*/

void demonstrate_noop_coroutine() {
    // 获取noop_coroutine
    std::coroutine_handle<> noop = std::noop_coroutine();

    // 调用resume()是安全的，什么都不做
    noop.resume();  // No-op

    // done()返回true
    assert(noop.done() == true);

    // 不需要destroy
    // noop.destroy();  // 不需要，也不应该调用
}

// 在对称转移中使用
struct ContinuationAwaiter {
    std::coroutine_handle<> continuation;

    bool await_ready() noexcept { return false; }

    std::coroutine_handle<> await_suspend(
        std::coroutine_handle<> current) noexcept {
        // 如果有continuation，转移到它
        // 否则返回noop_coroutine结束链
        return continuation ? continuation : std::noop_coroutine();
    }

    void await_resume() noexcept {}
};
```

#### 4. 完整的对称转移示例

```cpp
// ============================================================
// 支持对称转移的Task实现
// ============================================================

template<typename T>
class SymmetricTask {
public:
    struct promise_type {
        std::optional<T> result;
        std::exception_ptr exception;
        std::coroutine_handle<> continuation;

        SymmetricTask get_return_object() {
            return SymmetricTask{
                std::coroutine_handle<promise_type>::from_promise(*this)
            };
        }

        std::suspend_always initial_suspend() noexcept { return {}; }

        // 对称转移的关键
        auto final_suspend() noexcept {
            struct FinalAwaiter {
                bool await_ready() noexcept { return false; }

                std::coroutine_handle<> await_suspend(
                    std::coroutine_handle<promise_type> h) noexcept {
                    auto& promise = h.promise();
                    if (promise.continuation) {
                        return promise.continuation;
                    }
                    return std::noop_coroutine();
                }

                void await_resume() noexcept {}
            };
            return FinalAwaiter{};
        }

        void return_value(T value) {
            result = std::move(value);
        }

        void unhandled_exception() {
            exception = std::current_exception();
        }
    };

private:
    std::coroutine_handle<promise_type> handle_;

public:
    explicit SymmetricTask(std::coroutine_handle<promise_type> h)
        : handle_(h) {}

    SymmetricTask(SymmetricTask&& other) noexcept
        : handle_(std::exchange(other.handle_, nullptr)) {}

    ~SymmetricTask() {
        if (handle_) handle_.destroy();
    }

    // 使Task可以被co_await
    bool await_ready() const noexcept {
        return handle_.done();
    }

    // 对称转移：返回要恢复的协程
    std::coroutine_handle<> await_suspend(
        std::coroutine_handle<> awaiting) noexcept {
        handle_.promise().continuation = awaiting;
        return handle_;  // 转移到此Task
    }

    T await_resume() {
        if (handle_.promise().exception) {
            std::rethrow_exception(handle_.promise().exception);
        }
        return std::move(*handle_.promise().result);
    }
};

// 使用示例：深度协程链
SymmetricTask<int> level(int n) {
    if (n == 0) {
        co_return 42;
    }
    // 递归调用不会导致栈溢出
    int result = co_await level(n - 1);
    co_return result + 1;
}

// 即使n=10000也不会栈溢出
// auto task = level(10000);
```

### Day 5-6（第12-13天）：自定义 Awaitable 实战

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | 定时器Awaitable | 2h |
| 下午 | 组合Awaitable | 3h |
| 晚上 | Awaitable适配器 | 2h |

#### 1. 定时器 Awaitable

```cpp
// ============================================================
// timer_awaitable.hpp - 异步定时器
// ============================================================

#pragma once
#include <coroutine>
#include <chrono>
#include <thread>
#include <queue>
#include <mutex>
#include <condition_variable>

// 简单的Sleep Awaitable（使用线程）
struct SleepAwaiter {
    std::chrono::milliseconds duration;

    bool await_ready() const noexcept {
        return duration.count() <= 0;
    }

    void await_suspend(std::coroutine_handle<> h) const {
        std::thread([h, d = duration]() {
            std::this_thread::sleep_for(d);
            h.resume();
        }).detach();
    }

    void await_resume() const noexcept {}
};

// 便捷函数
inline auto sleep_for(std::chrono::milliseconds ms) {
    return SleepAwaiter{ms};
}

// 更高效的定时器（共享定时器线程）
class TimerService {
public:
    struct TimerEntry {
        std::chrono::steady_clock::time_point deadline;
        std::coroutine_handle<> handle;

        bool operator>(const TimerEntry& other) const {
            return deadline > other.deadline;
        }
    };

private:
    std::priority_queue<TimerEntry,
                        std::vector<TimerEntry>,
                        std::greater<>> queue_;
    std::mutex mutex_;
    std::condition_variable cv_;
    std::thread worker_;
    bool stop_ = false;

public:
    TimerService() : worker_([this] { run(); }) {}

    ~TimerService() {
        {
            std::lock_guard lock(mutex_);
            stop_ = true;
        }
        cv_.notify_one();
        worker_.join();
    }

    void schedule(std::chrono::milliseconds delay,
                  std::coroutine_handle<> handle) {
        auto deadline = std::chrono::steady_clock::now() + delay;
        {
            std::lock_guard lock(mutex_);
            queue_.push({deadline, handle});
        }
        cv_.notify_one();
    }

private:
    void run() {
        while (true) {
            std::unique_lock lock(mutex_);

            if (queue_.empty()) {
                cv_.wait(lock, [this] {
                    return stop_ || !queue_.empty();
                });
            }

            if (stop_ && queue_.empty()) break;

            auto now = std::chrono::steady_clock::now();
            if (queue_.top().deadline <= now) {
                auto entry = queue_.top();
                queue_.pop();
                lock.unlock();
                entry.handle.resume();
            } else {
                cv_.wait_until(lock, queue_.top().deadline);
            }
        }
    }
};

// 全局定时器服务
inline TimerService& get_timer_service() {
    static TimerService service;
    return service;
}

// 高效的Sleep Awaitable
struct EfficientSleepAwaiter {
    std::chrono::milliseconds duration;

    bool await_ready() const noexcept {
        return duration.count() <= 0;
    }

    void await_suspend(std::coroutine_handle<> h) const {
        get_timer_service().schedule(duration, h);
    }

    void await_resume() const noexcept {}
};
```

#### 2. 组合 Awaitable：WhenAll

```cpp
// ============================================================
// when_all.hpp - 并发执行多个Task
// ============================================================

#pragma once
#include <coroutine>
#include <tuple>
#include <atomic>
#include <vector>

// WhenAll：等待所有Task完成
template<typename... Tasks>
class WhenAllAwaiter {
public:
    using ResultTuple = std::tuple<
        typename std::decay_t<Tasks>::value_type...>;

private:
    std::tuple<Tasks...> tasks_;
    std::atomic<size_t> remaining_;
    std::coroutine_handle<> continuation_;
    ResultTuple results_;
    std::exception_ptr exception_;

public:
    explicit WhenAllAwaiter(Tasks&&... tasks)
        : tasks_(std::forward<Tasks>(tasks)...)
        , remaining_(sizeof...(Tasks)) {}

    bool await_ready() const noexcept {
        return sizeof...(Tasks) == 0;
    }

    void await_suspend(std::coroutine_handle<> h) {
        continuation_ = h;
        start_all(std::index_sequence_for<Tasks...>{});
    }

    ResultTuple await_resume() {
        if (exception_) {
            std::rethrow_exception(exception_);
        }
        return std::move(results_);
    }

private:
    template<size_t... Is>
    void start_all(std::index_sequence<Is...>) {
        (start_one<Is>(), ...);
    }

    template<size_t I>
    void start_one() {
        auto& task = std::get<I>(tasks_);

        // 为每个task创建一个wrapper协程
        [](auto& self, auto& task, auto& result) -> DetachedTask {
            try {
                result = co_await task;
            } catch (...) {
                self.exception_ = std::current_exception();
            }
            if (self.remaining_.fetch_sub(1) == 1) {
                self.continuation_.resume();
            }
        }(*this, task, std::get<I>(results_));
    }
};

// 便捷函数
template<typename... Tasks>
auto when_all(Tasks&&... tasks) {
    return WhenAllAwaiter<Tasks...>(std::forward<Tasks>(tasks)...);
}

// 使用示例
/*
Task<void> example() {
    auto [a, b, c] = co_await when_all(
        fetch_data_a(),
        fetch_data_b(),
        fetch_data_c()
    );
    // a, b, c 包含三个task的结果
}
*/
```

#### 3. 组合 Awaitable：WhenAny

```cpp
// ============================================================
// when_any.hpp - 等待任意一个Task完成
// ============================================================

#pragma once
#include <coroutine>
#include <variant>
#include <atomic>
#include <optional>

// WhenAny结果：包含完成的索引和值
template<typename... Ts>
struct WhenAnyResult {
    size_t index;
    std::variant<Ts...> value;
};

template<typename... Tasks>
class WhenAnyAwaiter {
public:
    using ResultType = WhenAnyResult<
        typename std::decay_t<Tasks>::value_type...>;

private:
    std::tuple<Tasks...> tasks_;
    std::atomic<bool> completed_{false};
    std::coroutine_handle<> continuation_;
    std::optional<ResultType> result_;
    std::exception_ptr exception_;

public:
    explicit WhenAnyAwaiter(Tasks&&... tasks)
        : tasks_(std::forward<Tasks>(tasks)...) {}

    bool await_ready() const noexcept {
        return false;
    }

    void await_suspend(std::coroutine_handle<> h) {
        continuation_ = h;
        start_all(std::index_sequence_for<Tasks...>{});
    }

    ResultType await_resume() {
        if (exception_) {
            std::rethrow_exception(exception_);
        }
        return std::move(*result_);
    }

private:
    template<size_t... Is>
    void start_all(std::index_sequence<Is...>) {
        (start_one<Is>(), ...);
    }

    template<size_t I>
    void start_one() {
        auto& task = std::get<I>(tasks_);

        [](auto& self, auto& task) -> DetachedTask {
            try {
                auto value = co_await task;

                // 原子地检查是否第一个完成
                bool expected = false;
                if (self.completed_.compare_exchange_strong(
                        expected, true)) {
                    self.result_ = ResultType{
                        I,
                        std::variant<typename std::decay_t<Tasks>::value_type...>(
                            std::in_place_index<I>, std::move(value))
                    };
                    self.continuation_.resume();
                }
            } catch (...) {
                bool expected = false;
                if (self.completed_.compare_exchange_strong(
                        expected, true)) {
                    self.exception_ = std::current_exception();
                    self.continuation_.resume();
                }
            }
        }(*this, task);
    }
};

template<typename... Tasks>
auto when_any(Tasks&&... tasks) {
    return WhenAnyAwaiter<Tasks...>(std::forward<Tasks>(tasks)...);
}

// 使用示例
/*
Task<void> example() {
    auto result = co_await when_any(
        slow_operation(),
        fast_operation(),
        medium_operation()
    );

    std::cout << "First completed: " << result.index << "\n";
}
*/
```

#### 4. 超时控制

```cpp
// ============================================================
// timeout.hpp - 超时控制
// ============================================================

#pragma once
#include <chrono>
#include <optional>

template<typename T>
struct TimeoutResult {
    std::optional<T> value;
    bool timed_out;

    explicit operator bool() const { return !timed_out; }
};

// 带超时的Task包装
template<typename Task>
class WithTimeoutAwaiter {
    Task task_;
    std::chrono::milliseconds timeout_;

public:
    WithTimeoutAwaiter(Task&& task, std::chrono::milliseconds timeout)
        : task_(std::forward<Task>(task))
        , timeout_(timeout) {}

    using value_type = TimeoutResult<typename Task::value_type>;

    bool await_ready() const noexcept { return false; }

    void await_suspend(std::coroutine_handle<> h);
    value_type await_resume();
};

template<typename Task>
auto with_timeout(Task&& task, std::chrono::milliseconds timeout) {
    return WithTimeoutAwaiter<Task>(
        std::forward<Task>(task), timeout);
}

// 使用示例
/*
Task<void> example() {
    auto result = co_await with_timeout(
        slow_operation(),
        std::chrono::seconds(5)
    );

    if (result) {
        std::cout << "Got result: " << *result.value << "\n";
    } else {
        std::cout << "Operation timed out\n";
    }
}
*/
```

### Day 7（第14天）：cppcoro 源码研读与周总结

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | cppcoro库概览 | 2h |
| 下午 | 关键实现分析 | 2h |
| 晚上 | 周总结与练习 | 2h |

#### cppcoro 关键设计分析

```cpp
// ============================================================
// cppcoro设计要点（Lewis Baker的参考实现）
// ============================================================

/*
cppcoro库的核心设计原则：

1. 惰性求值（Lazy Evaluation）
   - Task默认不立即执行
   - 只有被co_await时才开始

2. 对称转移优先
   - 所有协程链使用对称转移
   - 避免深度协程调用的栈溢出

3. RAII资源管理
   - 协程帧由Task对象管理
   - 自动清理，无内存泄漏

4. 异常安全
   - 异常通过promise传播
   - 支持在co_await时重新抛出

关键类型：
- task<T>: 惰性执行的异步任务
- generator<T>: 同步生成器
- async_generator<T>: 异步生成器
- single_consumer_event: 单次事件
- async_mutex: 异步互斥锁
*/

// cppcoro风格的task实现要点
template<typename T>
class CppcoroStyleTask {
    // 1. 使用final_suspend实现对称转移
    // 2. 惰性启动（initial_suspend返回suspend_always）
    // 3. 支持void特化
    // 4. 移动语义，禁止拷贝
};
```

#### 第二周检验标准

- [ ] 能解释Awaitable三件套的作用
- [ ] 理解await_suspend三种返回值的区别
- [ ] 能解释对称转移如何避免栈溢出
- [ ] 能实现WhenAll/WhenAny组合器
- [ ] 能设计带超时控制的Awaitable

---

## 第三周：异步 Task 系统（Day 15-21）

> **本周目标**：实现生产级的异步Task系统，包括调度器和组合器

### Day 1-2（第15-16天）：Task<T> 完整实现

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | Task设计考量 | 2h |
| 下午 | 完整实现 | 3h |
| 晚上 | void特化与测试 | 2h |

#### 1. 生产级 Task 实现

```cpp
// ============================================================
// task.hpp - 生产级异步Task实现
// ============================================================

#pragma once
#include <coroutine>
#include <exception>
#include <optional>
#include <type_traits>
#include <utility>

// 前向声明
template<typename T = void>
class Task;

namespace detail {

// Task Promise基类（通用逻辑）
class TaskPromiseBase {
public:
    std::coroutine_handle<> continuation_ = nullptr;

    struct FinalAwaiter {
        bool await_ready() const noexcept { return false; }

        template<typename Promise>
        std::coroutine_handle<> await_suspend(
            std::coroutine_handle<Promise> h) noexcept {
            auto& promise = h.promise();
            if (promise.continuation_) {
                return promise.continuation_;
            }
            return std::noop_coroutine();
        }

        void await_resume() noexcept {}
    };

    std::suspend_always initial_suspend() noexcept { return {}; }
    FinalAwaiter final_suspend() noexcept { return {}; }
};

// 带返回值的Promise
template<typename T>
class TaskPromise : public TaskPromiseBase {
public:
    using value_type = T;

private:
    enum class State { Empty, Value, Exception };

    State state_ = State::Empty;
    union {
        T value_;
        std::exception_ptr exception_;
    };

public:
    TaskPromise() noexcept {}

    ~TaskPromise() {
        switch (state_) {
            case State::Value:
                value_.~T();
                break;
            case State::Exception:
                exception_.~exception_ptr();
                break;
            default:
                break;
        }
    }

    Task<T> get_return_object() noexcept;

    void return_value(T value)
        noexcept(std::is_nothrow_move_constructible_v<T>) {
        ::new (std::addressof(value_)) T(std::move(value));
        state_ = State::Value;
    }

    void unhandled_exception() noexcept {
        ::new (std::addressof(exception_))
            std::exception_ptr(std::current_exception());
        state_ = State::Exception;
    }

    T& result() & {
        if (state_ == State::Exception) {
            std::rethrow_exception(exception_);
        }
        return value_;
    }

    T&& result() && {
        if (state_ == State::Exception) {
            std::rethrow_exception(exception_);
        }
        return std::move(value_);
    }
};

// void特化
template<>
class TaskPromise<void> : public TaskPromiseBase {
public:
    using value_type = void;

private:
    std::exception_ptr exception_;

public:
    Task<void> get_return_object() noexcept;

    void return_void() noexcept {}

    void unhandled_exception() noexcept {
        exception_ = std::current_exception();
    }

    void result() {
        if (exception_) {
            std::rethrow_exception(exception_);
        }
    }
};

} // namespace detail

// ============================================================
// Task<T> 主类
// ============================================================

template<typename T>
class [[nodiscard]] Task {
public:
    using promise_type = detail::TaskPromise<T>;
    using value_type = T;

private:
    std::coroutine_handle<promise_type> handle_;

public:
    Task() noexcept : handle_(nullptr) {}

    explicit Task(std::coroutine_handle<promise_type> h) noexcept
        : handle_(h) {}

    Task(Task&& other) noexcept
        : handle_(std::exchange(other.handle_, nullptr)) {}

    Task& operator=(Task&& other) noexcept {
        if (this != &other) {
            if (handle_) {
                handle_.destroy();
            }
            handle_ = std::exchange(other.handle_, nullptr);
        }
        return *this;
    }

    ~Task() {
        if (handle_) {
            handle_.destroy();
        }
    }

    // 禁止拷贝
    Task(const Task&) = delete;
    Task& operator=(const Task&) = delete;

    // 检查是否有效
    explicit operator bool() const noexcept {
        return handle_ != nullptr;
    }

    bool done() const noexcept {
        return handle_.done();
    }

    // ========== Awaitable接口 ==========

    bool await_ready() const noexcept {
        return false;  // 惰性求值，总是暂停
    }

    std::coroutine_handle<> await_suspend(
        std::coroutine_handle<> awaiting) noexcept {
        handle_.promise().continuation_ = awaiting;
        return handle_;  // 对称转移
    }

    decltype(auto) await_resume() {
        return std::move(handle_.promise()).result();
    }

    // ========== 同步等待 ==========

    // 阻塞当前线程等待完成
    decltype(auto) get() {
        // 简单实现：循环恢复直到完成
        while (!handle_.done()) {
            handle_.resume();
        }
        return std::move(handle_.promise()).result();
    }
};

// Promise的get_return_object实现
namespace detail {

template<typename T>
Task<T> TaskPromise<T>::get_return_object() noexcept {
    return Task<T>{
        std::coroutine_handle<TaskPromise<T>>::from_promise(*this)
    };
}

inline Task<void> TaskPromise<void>::get_return_object() noexcept {
    return Task<void>{
        std::coroutine_handle<TaskPromise<void>>::from_promise(*this)
    };
}

} // namespace detail
```

#### 2. Task 使用示例

```cpp
// ============================================================
// Task使用示例
// ============================================================

#include "task.hpp"
#include <iostream>
#include <string>

// 返回值的Task
Task<int> compute_value(int x) {
    co_return x * 2;
}

// 调用其他Task的Task
Task<int> compute_sum(int a, int b) {
    int va = co_await compute_value(a);
    int vb = co_await compute_value(b);
    co_return va + vb;
}

// void Task
Task<void> print_result(int value) {
    std::cout << "Result: " << value << "\n";
    co_return;
}

// 异常传播
Task<int> may_throw(bool should_throw) {
    if (should_throw) {
        throw std::runtime_error("Something went wrong");
    }
    co_return 42;
}

Task<void> handle_exception() {
    try {
        int result = co_await may_throw(true);
        std::cout << "Result: " << result << "\n";
    } catch (const std::exception& e) {
        std::cout << "Caught: " << e.what() << "\n";
    }
}

// 组合多个Task
Task<std::string> fetch_greeting() {
    co_return "Hello";
}

Task<std::string> fetch_name() {
    co_return "World";
}

Task<std::string> compose_message() {
    auto greeting = co_await fetch_greeting();
    auto name = co_await fetch_name();
    co_return greeting + ", " + name + "!";
}

// 主函数示例
void task_examples() {
    // 同步获取结果
    auto task1 = compute_sum(10, 20);
    std::cout << "Sum: " << task1.get() << "\n";  // 60

    // 组合任务
    auto task2 = compose_message();
    std::cout << task2.get() << "\n";  // Hello, World!

    // 异常处理
    auto task3 = handle_exception();
    task3.get();  // Caught: Something went wrong
}
```

### Day 3-4（第17-18天）：协程调度器

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | 调度器设计 | 2h |
| 下午 | 单线程事件循环 | 3h |
| 晚上 | 多线程调度器 | 2h |

#### 1. 单线程事件循环

```cpp
// ============================================================
// scheduler.hpp - 协程调度器
// ============================================================

#pragma once
#include <coroutine>
#include <queue>
#include <functional>
#include <chrono>
#include <optional>

// 单线程事件循环
class EventLoop {
public:
    using Clock = std::chrono::steady_clock;
    using TimePoint = Clock::time_point;
    using Duration = Clock::duration;

private:
    // 立即执行队列
    std::queue<std::coroutine_handle<>> ready_queue_;

    // 定时任务
    struct TimerEntry {
        TimePoint deadline;
        std::coroutine_handle<> handle;

        bool operator>(const TimerEntry& other) const {
            return deadline > other.deadline;
        }
    };
    std::priority_queue<TimerEntry,
                        std::vector<TimerEntry>,
                        std::greater<>> timer_queue_;

    bool running_ = false;

public:
    // 调度立即执行
    void schedule(std::coroutine_handle<> handle) {
        ready_queue_.push(handle);
    }

    // 调度延迟执行
    void schedule_after(Duration delay, std::coroutine_handle<> handle) {
        timer_queue_.push({Clock::now() + delay, handle});
    }

    // 调度在指定时间执行
    void schedule_at(TimePoint time, std::coroutine_handle<> handle) {
        timer_queue_.push({time, handle});
    }

    // 运行事件循环
    void run() {
        running_ = true;

        while (running_) {
            // 处理到期的定时器
            auto now = Clock::now();
            while (!timer_queue_.empty() &&
                   timer_queue_.top().deadline <= now) {
                auto handle = timer_queue_.top().handle;
                timer_queue_.pop();
                ready_queue_.push(handle);
            }

            // 处理就绪队列
            if (!ready_queue_.empty()) {
                auto handle = ready_queue_.front();
                ready_queue_.pop();

                if (!handle.done()) {
                    handle.resume();
                }
            } else if (!timer_queue_.empty()) {
                // 等待下一个定时器
                std::this_thread::sleep_until(
                    timer_queue_.top().deadline);
            } else {
                // 没有任务，退出
                break;
            }
        }
    }

    void stop() {
        running_ = false;
    }

    bool has_pending_tasks() const {
        return !ready_queue_.empty() || !timer_queue_.empty();
    }
};

// 全局事件循环
inline EventLoop& get_event_loop() {
    static EventLoop loop;
    return loop;
}

// ============================================================
// 调度相关的Awaitable
// ============================================================

// 让出执行权（重新排队）
struct YieldAwaiter {
    bool await_ready() const noexcept { return false; }

    void await_suspend(std::coroutine_handle<> h) const {
        get_event_loop().schedule(h);
    }

    void await_resume() const noexcept {}
};

inline auto yield() {
    return YieldAwaiter{};
}

// 延迟执行
struct DelayAwaiter {
    std::chrono::milliseconds duration;

    bool await_ready() const noexcept {
        return duration.count() <= 0;
    }

    void await_suspend(std::coroutine_handle<> h) const {
        get_event_loop().schedule_after(duration, h);
    }

    void await_resume() const noexcept {}
};

inline auto delay(std::chrono::milliseconds ms) {
    return DelayAwaiter{ms};
}
```

#### 2. 多线程调度器

```cpp
// ============================================================
// thread_pool_scheduler.hpp - 多线程协程调度器
// ============================================================

#pragma once
#include <coroutine>
#include <thread>
#include <vector>
#include <queue>
#include <mutex>
#include <condition_variable>
#include <atomic>
#include <functional>

class ThreadPoolScheduler {
private:
    std::vector<std::thread> workers_;
    std::queue<std::coroutine_handle<>> task_queue_;
    std::mutex mutex_;
    std::condition_variable cv_;
    std::atomic<bool> stop_{false};

public:
    explicit ThreadPoolScheduler(
        size_t num_threads = std::thread::hardware_concurrency()) {
        for (size_t i = 0; i < num_threads; ++i) {
            workers_.emplace_back([this] { worker_thread(); });
        }
    }

    ~ThreadPoolScheduler() {
        stop();
    }

    void stop() {
        {
            std::lock_guard lock(mutex_);
            stop_ = true;
        }
        cv_.notify_all();

        for (auto& worker : workers_) {
            if (worker.joinable()) {
                worker.join();
            }
        }
    }

    void schedule(std::coroutine_handle<> handle) {
        {
            std::lock_guard lock(mutex_);
            task_queue_.push(handle);
        }
        cv_.notify_one();
    }

    // Awaitable：在线程池中恢复
    struct ScheduleAwaiter {
        ThreadPoolScheduler& scheduler;

        bool await_ready() const noexcept { return false; }

        void await_suspend(std::coroutine_handle<> h) const {
            scheduler.schedule(h);
        }

        void await_resume() const noexcept {}
    };

    auto schedule_on_pool() {
        return ScheduleAwaiter{*this};
    }

private:
    void worker_thread() {
        while (true) {
            std::coroutine_handle<> handle;

            {
                std::unique_lock lock(mutex_);
                cv_.wait(lock, [this] {
                    return stop_ || !task_queue_.empty();
                });

                if (stop_ && task_queue_.empty()) {
                    return;
                }

                handle = task_queue_.front();
                task_queue_.pop();
            }

            if (!handle.done()) {
                handle.resume();
            }
        }
    }
};

// 使用示例
/*
ThreadPoolScheduler scheduler(4);

Task<int> compute_on_thread_pool() {
    // 切换到线程池执行
    co_await scheduler.schedule_on_pool();

    // 这里的代码在线程池中执行
    int result = heavy_computation();

    co_return result;
}
*/
```

#### 3. 与 Month 19 线程池集成

```cpp
// ============================================================
// 协程 + 线程池集成
// ============================================================

#include "thread_pool.hpp"  // Month 19的线程池

// 线程池调度Awaitable
template<typename ThreadPool>
class ThreadPoolAwaiter {
    ThreadPool& pool_;

public:
    explicit ThreadPoolAwaiter(ThreadPool& pool) : pool_(pool) {}

    bool await_ready() const noexcept { return false; }

    void await_suspend(std::coroutine_handle<> h) const {
        pool_.submit([h]() mutable {
            h.resume();
        });
    }

    void await_resume() const noexcept {}
};

template<typename ThreadPool>
auto resume_on(ThreadPool& pool) {
    return ThreadPoolAwaiter<ThreadPool>(pool);
}

// 在特定执行器上运行Task
template<typename Executor, typename T>
Task<T> run_on(Executor& executor, Task<T> task) {
    co_await resume_on(executor);
    co_return co_await std::move(task);
}

// 使用示例
/*
ThreadPool pool(4);

Task<void> example() {
    std::cout << "Starting on: " << std::this_thread::get_id() << "\n";

    // 切换到线程池
    co_await resume_on(pool);

    std::cout << "Running on pool: " << std::this_thread::get_id() << "\n";

    // 执行CPU密集型任务
    auto result = heavy_computation();

    co_return;
}
*/
```

### Day 5-6（第19-20天）：任务组合器进阶

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | 完善WhenAll | 2h |
| 下午 | Sequence和Pipeline | 3h |
| 晚上 | 错误处理策略 | 2h |

#### 1. 完善的 WhenAll 实现

```cpp
// ============================================================
// when_all_complete.hpp - 完整的WhenAll实现
// ============================================================

#pragma once
#include "task.hpp"
#include <tuple>
#include <atomic>
#include <vector>

// 用于启动但不等待的Task
class DetachedTask {
public:
    struct promise_type {
        DetachedTask get_return_object() { return {}; }
        std::suspend_never initial_suspend() { return {}; }
        std::suspend_never final_suspend() noexcept { return {}; }
        void return_void() {}
        void unhandled_exception() { std::terminate(); }
    };
};

// WhenAll状态
template<typename... Ts>
class WhenAllState {
public:
    std::tuple<std::optional<Ts>...> results;
    std::atomic<size_t> remaining{sizeof...(Ts)};
    std::coroutine_handle<> continuation;
    std::exception_ptr first_exception;
    std::mutex exception_mutex;

    void set_exception(std::exception_ptr e) {
        std::lock_guard lock(exception_mutex);
        if (!first_exception) {
            first_exception = e;
        }
    }
};

template<size_t I, typename State, typename Task>
DetachedTask run_one_task(std::shared_ptr<State> state, Task task) {
    try {
        if constexpr (std::is_void_v<typename Task::value_type>) {
            co_await std::move(task);
        } else {
            std::get<I>(state->results) = co_await std::move(task);
        }
    } catch (...) {
        state->set_exception(std::current_exception());
    }

    if (state->remaining.fetch_sub(1) == 1) {
        if (state->continuation) {
            state->continuation.resume();
        }
    }
}

template<typename... Tasks>
class WhenAllAwaiter {
    using State = WhenAllState<typename Tasks::value_type...>;
    std::shared_ptr<State> state_;
    std::tuple<Tasks...> tasks_;

public:
    explicit WhenAllAwaiter(Tasks... tasks)
        : state_(std::make_shared<State>())
        , tasks_(std::move(tasks)...) {}

    bool await_ready() const noexcept {
        return sizeof...(Tasks) == 0;
    }

    void await_suspend(std::coroutine_handle<> h) {
        state_->continuation = h;
        start_tasks(std::index_sequence_for<Tasks...>{});
    }

    auto await_resume() {
        if (state_->first_exception) {
            std::rethrow_exception(state_->first_exception);
        }
        return get_results(std::index_sequence_for<Tasks...>{});
    }

private:
    template<size_t... Is>
    void start_tasks(std::index_sequence<Is...>) {
        (run_one_task<Is>(state_, std::move(std::get<Is>(tasks_))), ...);
    }

    template<size_t... Is>
    auto get_results(std::index_sequence<Is...>) {
        return std::make_tuple(
            std::move(*std::get<Is>(state_->results))...);
    }
};

template<typename... Tasks>
auto when_all(Tasks... tasks) {
    return WhenAllAwaiter<Tasks...>(std::move(tasks)...);
}

// 向量版本
template<typename T>
class WhenAllVectorAwaiter {
    std::vector<Task<T>> tasks_;
    std::shared_ptr<std::vector<std::optional<T>>> results_;
    std::shared_ptr<std::atomic<size_t>> remaining_;
    std::shared_ptr<std::exception_ptr> exception_;
    std::coroutine_handle<> continuation_;

public:
    explicit WhenAllVectorAwaiter(std::vector<Task<T>> tasks)
        : tasks_(std::move(tasks))
        , results_(std::make_shared<std::vector<std::optional<T>>>(
              tasks_.size()))
        , remaining_(std::make_shared<std::atomic<size_t>>(tasks_.size()))
        , exception_(std::make_shared<std::exception_ptr>()) {}

    bool await_ready() const noexcept {
        return tasks_.empty();
    }

    void await_suspend(std::coroutine_handle<> h) {
        continuation_ = h;

        for (size_t i = 0; i < tasks_.size(); ++i) {
            start_one(i);
        }
    }

    std::vector<T> await_resume() {
        if (*exception_) {
            std::rethrow_exception(*exception_);
        }

        std::vector<T> result;
        result.reserve(results_->size());
        for (auto& opt : *results_) {
            result.push_back(std::move(*opt));
        }
        return result;
    }

private:
    void start_one(size_t index) {
        [](auto results, auto remaining, auto exception,
           auto continuation, Task<T> task, size_t idx) -> DetachedTask {
            try {
                (*results)[idx] = co_await std::move(task);
            } catch (...) {
                if (!*exception) {
                    *exception = std::current_exception();
                }
            }

            if (remaining->fetch_sub(1) == 1) {
                continuation.resume();
            }
        }(results_, remaining_, exception_, continuation_,
          std::move(tasks_[index]), index);
    }
};

template<typename T>
auto when_all(std::vector<Task<T>> tasks) {
    return WhenAllVectorAwaiter<T>(std::move(tasks));
}
```

#### 2. Sequence 串行执行

```cpp
// ============================================================
// sequence.hpp - 串行执行多个Task
// ============================================================

#pragma once
#include "task.hpp"
#include <vector>

// 串行执行，收集所有结果
template<typename T>
Task<std::vector<T>> sequence(std::vector<Task<T>> tasks) {
    std::vector<T> results;
    results.reserve(tasks.size());

    for (auto& task : tasks) {
        results.push_back(co_await std::move(task));
    }

    co_return results;
}

// 串行执行，只返回最后一个结果
template<typename T>
Task<T> sequence_last(std::vector<Task<T>> tasks) {
    T result;

    for (auto& task : tasks) {
        result = co_await std::move(task);
    }

    co_return result;
}

// 串行执行void任务
Task<void> sequence(std::vector<Task<void>> tasks) {
    for (auto& task : tasks) {
        co_await std::move(task);
    }
}

// 条件执行：执行直到某个条件满足
template<typename T, typename Predicate>
Task<std::optional<T>> sequence_until(
    std::vector<Task<T>> tasks, Predicate pred) {

    for (auto& task : tasks) {
        T result = co_await std::move(task);
        if (pred(result)) {
            co_return result;
        }
    }

    co_return std::nullopt;
}
```

#### 3. Pipeline 模式

```cpp
// ============================================================
// pipeline.hpp - 协程管道
// ============================================================

#pragma once
#include "task.hpp"
#include <functional>

// 管道：将一个Task的结果传递给下一个函数
template<typename T, typename F>
auto operator|(Task<T> task, F&& func)
    -> Task<std::invoke_result_t<F, T>> {
    auto value = co_await std::move(task);
    co_return std::invoke(std::forward<F>(func), std::move(value));
}

// void Task的管道
template<typename F>
auto operator|(Task<void> task, F&& func)
    -> Task<std::invoke_result_t<F>> {
    co_await std::move(task);
    co_return std::invoke(std::forward<F>(func));
}

// 使用示例
/*
Task<int> get_value() { co_return 42; }

Task<void> pipeline_example() {
    auto result = co_await (
        get_value()
        | [](int x) { return x * 2; }
        | [](int x) { return std::to_string(x); }
        | [](std::string s) { return "Result: " + s; }
    );

    std::cout << result << "\n";  // Result: 84
}
*/

// 异步管道：每个阶段都是协程
template<typename T, typename F>
auto async_pipe(Task<T> task, F&& func)
    -> Task<typename std::invoke_result_t<F, T>::value_type>
    requires requires { { func(std::declval<T>()) } -> std::same_as<Task<typename std::invoke_result_t<F, T>::value_type>>; }
{
    auto value = co_await std::move(task);
    co_return co_await std::invoke(std::forward<F>(func), std::move(value));
}
```

### Day 7（第21天）：综合实践与周总结

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | 异步运行时整合 | 2h |
| 下午 | 综合示例 | 2h |
| 晚上 | 周总结 | 2h |

#### 综合示例：简单的异步运行时

```cpp
// ============================================================
// async_runtime.hpp - 简单的异步运行时
// ============================================================

#pragma once
#include "task.hpp"
#include "scheduler.hpp"

class AsyncRuntime {
private:
    EventLoop event_loop_;
    ThreadPoolScheduler thread_pool_;

public:
    AsyncRuntime(size_t num_threads = 4)
        : thread_pool_(num_threads) {}

    // 在事件循环中运行Task
    template<typename T>
    T block_on(Task<T> task) {
        std::optional<T> result;
        std::exception_ptr exception;
        bool done = false;

        // 创建包装协程
        [&]() -> DetachedTask {
            try {
                result = co_await std::move(task);
            } catch (...) {
                exception = std::current_exception();
            }
            done = true;
            event_loop_.stop();
        }();

        // 运行事件循环直到完成
        event_loop_.run();

        if (exception) {
            std::rethrow_exception(exception);
        }
        return std::move(*result);
    }

    // void特化
    void block_on(Task<void> task) {
        std::exception_ptr exception;
        bool done = false;

        [&]() -> DetachedTask {
            try {
                co_await std::move(task);
            } catch (...) {
                exception = std::current_exception();
            }
            done = true;
            event_loop_.stop();
        }();

        event_loop_.run();

        if (exception) {
            std::rethrow_exception(exception);
        }
    }

    // 切换到线程池
    auto on_thread_pool() {
        return thread_pool_.schedule_on_pool();
    }

    // 延迟
    auto sleep(std::chrono::milliseconds ms) {
        return delay(ms);
    }
};

// 使用示例
/*
int main() {
    AsyncRuntime runtime;

    auto result = runtime.block_on([]() -> Task<int> {
        std::cout << "Starting...\n";

        co_await delay(std::chrono::seconds(1));

        auto [a, b] = co_await when_all(
            compute_a(),
            compute_b()
        );

        co_return a + b;
    }());

    std::cout << "Result: " << result << "\n";
}
*/
```

#### 第三周检验标准

- [ ] 能实现完整的Task<T>类型
- [ ] 理解惰性启动和立即启动的区别
- [ ] 能实现单线程和多线程调度器
- [ ] 能实现WhenAll/Sequence等组合器
- [ ] 能将协程与线程池集成使用

---

## 第四周：实战应用与高级模式（Day 22-28）

> **本周目标**：实现高级协程原语（AsyncGenerator、Channel），完成实战项目

### Day 1-2（第22-23天）：异步生成器

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | AsyncGenerator设计 | 2h |
| 下午 | 完整实现 | 3h |
| 晚上 | 异步迭代 | 2h |

#### 1. AsyncGenerator 实现

```cpp
// ============================================================
// async_generator.hpp - 异步生成器
// ============================================================

#pragma once
#include <coroutine>
#include <exception>
#include <optional>
#include <utility>

template<typename T>
class AsyncGenerator {
public:
    struct promise_type {
        std::optional<T> current_value;
        std::exception_ptr exception;
        std::coroutine_handle<> consumer_handle;

        AsyncGenerator get_return_object() {
            return AsyncGenerator{
                std::coroutine_handle<promise_type>::from_promise(*this)
            };
        }

        std::suspend_always initial_suspend() noexcept { return {}; }

        auto final_suspend() noexcept {
            struct FinalAwaiter {
                bool await_ready() noexcept { return false; }
                std::coroutine_handle<> await_suspend(
                    std::coroutine_handle<promise_type> h) noexcept {
                    auto consumer = h.promise().consumer_handle;
                    return consumer ? consumer : std::noop_coroutine();
                }
                void await_resume() noexcept {}
            };
            return FinalAwaiter{};
        }

        // co_yield处理
        auto yield_value(T value) {
            current_value = std::move(value);

            struct YieldAwaiter {
                promise_type& promise;

                bool await_ready() noexcept { return false; }

                std::coroutine_handle<> await_suspend(
                    std::coroutine_handle<>) noexcept {
                    return promise.consumer_handle;
                }

                void await_resume() noexcept {}
            };

            return YieldAwaiter{*this};
        }

        void return_void() noexcept {}

        void unhandled_exception() {
            exception = std::current_exception();
        }

        // 禁用co_await（只允许co_yield）
        template<typename U>
        auto await_transform(U&&) = delete;
    };

    using handle_type = std::coroutine_handle<promise_type>;

private:
    handle_type handle_;

public:
    explicit AsyncGenerator(handle_type h) : handle_(h) {}

    AsyncGenerator(AsyncGenerator&& other) noexcept
        : handle_(std::exchange(other.handle_, nullptr)) {}

    ~AsyncGenerator() {
        if (handle_) handle_.destroy();
    }

    AsyncGenerator(const AsyncGenerator&) = delete;
    AsyncGenerator& operator=(const AsyncGenerator&) = delete;

    // ========== 异步迭代器 ==========

    class iterator {
    public:
        using value_type = T;
        using difference_type = std::ptrdiff_t;

    private:
        handle_type handle_;

    public:
        iterator() noexcept : handle_(nullptr) {}
        explicit iterator(handle_type h) noexcept : handle_(h) {}

        // 异步推进
        auto operator++() {
            struct AdvanceAwaiter {
                handle_type handle;

                bool await_ready() noexcept { return false; }

                std::coroutine_handle<> await_suspend(
                    std::coroutine_handle<> consumer) noexcept {
                    handle.promise().consumer_handle = consumer;
                    return handle;
                }

                iterator await_resume() {
                    if (handle.done()) {
                        if (handle.promise().exception) {
                            std::rethrow_exception(
                                handle.promise().exception);
                        }
                        return iterator{};
                    }
                    return iterator{handle};
                }
            };
            return AdvanceAwaiter{handle_};
        }

        T& operator*() const {
            return *handle_.promise().current_value;
        }

        T* operator->() const {
            return &*handle_.promise().current_value;
        }

        bool operator==(const iterator& other) const noexcept {
            return handle_ == other.handle_;
        }

        bool operator!=(const iterator& other) const noexcept {
            return !(*this == other);
        }
    };

    // 异步begin
    auto begin() {
        struct BeginAwaiter {
            handle_type handle;

            bool await_ready() noexcept { return false; }

            std::coroutine_handle<> await_suspend(
                std::coroutine_handle<> consumer) noexcept {
                handle.promise().consumer_handle = consumer;
                return handle;
            }

            iterator await_resume() {
                if (handle.done()) {
                    if (handle.promise().exception) {
                        std::rethrow_exception(
                            handle.promise().exception);
                    }
                    return iterator{};
                }
                return iterator{handle};
            }
        };
        return BeginAwaiter{handle_};
    }

    iterator end() noexcept {
        return iterator{};
    }
};
```

#### 2. AsyncGenerator 使用示例

```cpp
// ============================================================
// 异步生成器使用示例
// ============================================================

#include "async_generator.hpp"
#include "task.hpp"

// 异步范围生成
AsyncGenerator<int> async_range(int start, int end) {
    for (int i = start; i < end; ++i) {
        // 可以在每次yield前进行异步操作
        // co_await some_async_operation();
        co_yield i;
    }
}

// 异步读取数据块（模拟）
AsyncGenerator<std::string> async_read_chunks() {
    std::vector<std::string> data = {
        "chunk1", "chunk2", "chunk3", "chunk4"
    };

    for (const auto& chunk : data) {
        // 模拟异步I/O
        // co_await async_read();
        co_yield chunk;
    }
}

// 使用异步for循环
Task<void> consume_async_generator() {
    auto gen = async_range(1, 10);

    for (auto it = co_await gen.begin(); it != gen.end(); it = co_await ++it) {
        std::cout << *it << " ";
    }
    std::cout << "\n";
}

// 异步管道：转换生成器
template<typename T, typename F>
AsyncGenerator<std::invoke_result_t<F, T>> transform(
    AsyncGenerator<T> gen, F func) {

    for (auto it = co_await gen.begin(); it != gen.end(); it = co_await ++it) {
        co_yield func(*it);
    }
}

// 异步过滤
template<typename T, typename Pred>
AsyncGenerator<T> filter(AsyncGenerator<T> gen, Pred pred) {
    for (auto it = co_await gen.begin(); it != gen.end(); it = co_await ++it) {
        if (pred(*it)) {
            co_yield *it;
        }
    }
}
```

### Day 3-4（第24-25天）：Channel 通道

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | Channel设计 | 2h |
| 下午 | 有界Channel实现 | 3h |
| 晚上 | 多生产者多消费者 | 2h |

#### 1. Channel 实现

```cpp
// ============================================================
// channel.hpp - Go风格的协程通道
// ============================================================

#pragma once
#include <coroutine>
#include <queue>
#include <optional>
#include <mutex>
#include <memory>

template<typename T>
class Channel {
public:
    struct SendAwaiter;
    struct ReceiveAwaiter;

private:
    struct State {
        std::queue<T> buffer;
        std::queue<std::coroutine_handle<>> send_waiters;
        std::queue<std::pair<std::coroutine_handle<>, T*>> receive_waiters;
        size_t capacity;
        bool closed = false;
        std::mutex mutex;

        explicit State(size_t cap) : capacity(cap) {}
    };

    std::shared_ptr<State> state_;

public:
    // capacity=0表示无缓冲通道
    explicit Channel(size_t capacity = 0)
        : state_(std::make_shared<State>(capacity)) {}

    // 发送
    SendAwaiter send(T value) {
        return SendAwaiter{state_, std::move(value)};
    }

    // 接收
    ReceiveAwaiter receive() {
        return ReceiveAwaiter{state_};
    }

    // 关闭通道
    void close() {
        std::lock_guard lock(state_->mutex);
        state_->closed = true;

        // 唤醒所有等待的接收者
        while (!state_->receive_waiters.empty()) {
            auto [handle, ptr] = state_->receive_waiters.front();
            state_->receive_waiters.pop();
            handle.resume();
        }
    }

    bool is_closed() const {
        std::lock_guard lock(state_->mutex);
        return state_->closed;
    }

    // ========== Awaiters ==========

    struct SendAwaiter {
        std::shared_ptr<State> state;
        T value;
        bool sent = false;

        bool await_ready() {
            std::lock_guard lock(state->mutex);

            if (state->closed) {
                throw std::runtime_error("send on closed channel");
            }

            // 如果有等待的接收者，直接传递
            if (!state->receive_waiters.empty()) {
                auto [handle, ptr] = state->receive_waiters.front();
                state->receive_waiters.pop();
                *ptr = std::move(value);
                sent = true;
                // 稍后恢复接收者
                handle.resume();
                return true;
            }

            // 如果缓冲区未满，放入缓冲
            if (state->buffer.size() < state->capacity) {
                state->buffer.push(std::move(value));
                return true;
            }

            return false;  // 需要等待
        }

        void await_suspend(std::coroutine_handle<> h) {
            std::lock_guard lock(state->mutex);
            state->send_waiters.push(h);
        }

        void await_resume() {
            if (!sent) {
                std::lock_guard lock(state->mutex);
                state->buffer.push(std::move(value));
            }
        }
    };

    struct ReceiveAwaiter {
        std::shared_ptr<State> state;
        std::optional<T> result;

        bool await_ready() {
            std::lock_guard lock(state->mutex);

            // 如果缓冲区有数据
            if (!state->buffer.empty()) {
                result = std::move(state->buffer.front());
                state->buffer.pop();

                // 唤醒一个等待的发送者
                if (!state->send_waiters.empty()) {
                    auto sender = state->send_waiters.front();
                    state->send_waiters.pop();
                    sender.resume();
                }
                return true;
            }

            // 通道已关闭
            if (state->closed) {
                return true;
            }

            return false;  // 需要等待
        }

        void await_suspend(std::coroutine_handle<> h) {
            std::lock_guard lock(state->mutex);
            T* ptr = &result.emplace();
            state->receive_waiters.push({h, ptr});
        }

        std::optional<T> await_resume() {
            return std::move(result);
        }
    };
};

// 便捷函数
template<typename T>
Channel<T> make_channel(size_t capacity = 0) {
    return Channel<T>(capacity);
}
```

#### 2. Channel 使用示例

```cpp
// ============================================================
// Channel使用示例
// ============================================================

#include "channel.hpp"
#include "task.hpp"

// 生产者
Task<void> producer(Channel<int>& ch, int count) {
    for (int i = 0; i < count; ++i) {
        co_await ch.send(i);
        std::cout << "Sent: " << i << "\n";
    }
    ch.close();
}

// 消费者
Task<void> consumer(Channel<int>& ch) {
    while (true) {
        auto value = co_await ch.receive();
        if (!value) {
            std::cout << "Channel closed\n";
            break;
        }
        std::cout << "Received: " << *value << "\n";
    }
}

// 扇出：一个生产者，多个消费者
Task<void> fan_out_example() {
    auto ch = make_channel<int>(5);

    // 启动生产者
    auto prod = producer(ch, 10);

    // 启动多个消费者
    auto cons1 = consumer(ch);
    auto cons2 = consumer(ch);
    auto cons3 = consumer(ch);

    co_await when_all(
        std::move(prod),
        std::move(cons1),
        std::move(cons2),
        std::move(cons3)
    );
}

// 扇入：多个生产者，一个消费者
Task<void> fan_in_example() {
    auto ch = make_channel<int>(10);

    // 多个生产者
    auto prod1 = [](Channel<int>& ch) -> Task<void> {
        for (int i = 0; i < 5; ++i) {
            co_await ch.send(i * 10);
        }
    }(ch);

    auto prod2 = [](Channel<int>& ch) -> Task<void> {
        for (int i = 0; i < 5; ++i) {
            co_await ch.send(i * 100);
        }
    }(ch);

    // 消费者协程
    auto cons = [](Channel<int>& ch) -> Task<void> {
        for (int i = 0; i < 10; ++i) {
            auto val = co_await ch.receive();
            if (val) {
                std::cout << "Got: " << *val << "\n";
            }
        }
    }(ch);

    co_await when_all(
        std::move(prod1),
        std::move(prod2),
        std::move(cons)
    );
}

// 管道模式：channel连接多个处理阶段
Task<void> pipeline_with_channels() {
    auto input = make_channel<int>(5);
    auto squared = make_channel<int>(5);
    auto output = make_channel<std::string>(5);

    // 阶段1：生成数字
    auto stage1 = [](Channel<int>& out) -> Task<void> {
        for (int i = 1; i <= 5; ++i) {
            co_await out.send(i);
        }
        out.close();
    }(input);

    // 阶段2：平方
    auto stage2 = [](Channel<int>& in,
                     Channel<int>& out) -> Task<void> {
        while (auto val = co_await in.receive()) {
            co_await out.send((*val) * (*val));
        }
        out.close();
    }(input, squared);

    // 阶段3：转字符串
    auto stage3 = [](Channel<int>& in,
                     Channel<std::string>& out) -> Task<void> {
        while (auto val = co_await in.receive()) {
            co_await out.send(std::to_string(*val));
        }
        out.close();
    }(squared, output);

    // 最终消费
    auto consumer = [](Channel<std::string>& in) -> Task<void> {
        while (auto val = co_await in.receive()) {
            std::cout << "Final: " << *val << "\n";
        }
    }(output);

    co_await when_all(
        std::move(stage1),
        std::move(stage2),
        std::move(stage3),
        std::move(consumer)
    );
}
```

### Day 5-6（第26-27天）：实战项目

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | 项目设计 | 2h |
| 下午 | 核心实现 | 3h |
| 晚上 | 测试与优化 | 2h |

#### 实战项目：协程化任务执行器

```cpp
// ============================================================
// task_executor.hpp - 协程化任务执行器
// ============================================================

#pragma once
#include "task.hpp"
#include "channel.hpp"
#include "scheduler.hpp"
#include <functional>
#include <future>

// 任务执行器：支持优先级、依赖、取消
class TaskExecutor {
public:
    enum class Priority { Low, Normal, High, Critical };

    struct TaskConfig {
        Priority priority = Priority::Normal;
        std::chrono::milliseconds timeout{0};  // 0表示无超时
        bool cancellable = true;
    };

private:
    struct TaskEntry {
        std::function<Task<void>()> task;
        TaskConfig config;
        std::promise<void> completion;

        bool operator<(const TaskEntry& other) const {
            return config.priority < other.config.priority;
        }
    };

    ThreadPoolScheduler scheduler_;
    std::priority_queue<TaskEntry> task_queue_;
    std::mutex queue_mutex_;
    std::atomic<bool> running_{true};
    std::atomic<size_t> active_tasks_{0};

public:
    explicit TaskExecutor(size_t num_threads = 4)
        : scheduler_(num_threads) {}

    ~TaskExecutor() {
        shutdown();
    }

    // 提交任务
    template<typename F>
    std::future<void> submit(F&& func, TaskConfig config = {}) {
        auto entry = TaskEntry{
            [f = std::forward<F>(func)]() -> Task<void> {
                co_await f();
            },
            config,
            {}
        };

        auto future = entry.completion.get_future();

        {
            std::lock_guard lock(queue_mutex_);
            task_queue_.push(std::move(entry));
        }

        schedule_next();
        return future;
    }

    // 提交带返回值的任务
    template<typename F>
    auto submit_with_result(F&& func, TaskConfig config = {})
        -> std::future<std::invoke_result_t<F>> {

        using ResultType = std::invoke_result_t<F>;
        auto promise = std::make_shared<std::promise<ResultType>>();
        auto future = promise->get_future();

        submit([func = std::forward<F>(func), promise]() -> Task<void> {
            try {
                if constexpr (std::is_void_v<ResultType>) {
                    co_await func();
                    promise->set_value();
                } else {
                    auto result = co_await func();
                    promise->set_value(std::move(result));
                }
            } catch (...) {
                promise->set_exception(std::current_exception());
            }
        }, config);

        return future;
    }

    void shutdown() {
        running_ = false;
        // 等待所有任务完成
        while (active_tasks_ > 0) {
            std::this_thread::yield();
        }
    }

    size_t pending_tasks() const {
        std::lock_guard lock(queue_mutex_);
        return task_queue_.size();
    }

private:
    void schedule_next() {
        std::lock_guard lock(queue_mutex_);

        if (task_queue_.empty() || !running_) return;

        auto entry = std::move(const_cast<TaskEntry&>(task_queue_.top()));
        task_queue_.pop();

        ++active_tasks_;

        // 在调度器上执行
        [this](TaskEntry e) -> DetachedTask {
            co_await scheduler_.schedule_on_pool();

            try {
                co_await e.task();
                e.completion.set_value();
            } catch (...) {
                e.completion.set_exception(std::current_exception());
            }

            --active_tasks_;
            schedule_next();  // 调度下一个
        }(std::move(entry));
    }
};

// 使用示例
/*
TaskExecutor executor(4);

// 提交普通任务
executor.submit([]() -> Task<void> {
    std::cout << "Task running\n";
    co_return;
});

// 提交高优先级任务
executor.submit(
    []() -> Task<void> {
        std::cout << "Critical task\n";
        co_return;
    },
    {.priority = TaskExecutor::Priority::Critical}
);

// 提交带返回值的任务
auto future = executor.submit_with_result(
    []() -> Task<int> {
        co_return 42;
    }
);
std::cout << "Result: " << future.get() << "\n";
*/
```

#### 与 Month 20 Actor 模型集成

```cpp
// ============================================================
// 协程化Actor（与Month 20集成）
// ============================================================

#include "actor.hpp"  // Month 20的Actor
#include "task.hpp"

// 协程版本的Actor消息处理
template<typename Message>
class CoroutineActor {
public:
    using Handler = std::function<Task<void>(Message)>;

private:
    Channel<Message> mailbox_;
    Handler handler_;
    Task<void> run_task_;

public:
    explicit CoroutineActor(Handler handler, size_t mailbox_size = 100)
        : mailbox_(mailbox_size)
        , handler_(std::move(handler)) {}

    // 发送消息
    Task<void> send(Message msg) {
        co_await mailbox_.send(std::move(msg));
    }

    // 启动Actor
    Task<void> start() {
        while (true) {
            auto msg = co_await mailbox_.receive();
            if (!msg) break;

            try {
                co_await handler_(std::move(*msg));
            } catch (const std::exception& e) {
                // 错误处理
                std::cerr << "Actor error: " << e.what() << "\n";
            }
        }
    }

    void stop() {
        mailbox_.close();
    }
};

// 使用示例
/*
// 创建Echo Actor
CoroutineActor<std::string> echo_actor(
    [](std::string msg) -> Task<void> {
        std::cout << "Echo: " << msg << "\n";
        co_return;
    }
);

// 在运行时中启动
runtime.spawn(echo_actor.start());

// 发送消息
co_await echo_actor.send("Hello");
co_await echo_actor.send("World");

echo_actor.stop();
*/
```

### Day 7（第28天）：对比分析与总结

#### 学习时间分配

| 时段 | 内容 | 时长 |
|------|------|------|
| 上午 | 性能对比测试 | 2h |
| 下午 | 异步模式对比 | 2h |
| 晚上 | 月度总结 | 2h |

#### 协程 vs 回调 vs Future 对比

```cpp
// ============================================================
// 异步编程模式对比
// ============================================================

/*
┌─────────────────────────────────────────────────────────────────┐
│                    异步编程模式对比                               │
├───────────┬─────────────────┬────────────────┬─────────────────┤
│   特性    │     回调        │    Future      │     协程        │
├───────────┼─────────────────┼────────────────┼─────────────────┤
│ 代码风格  │ 嵌套/链式       │ 链式/组合      │ 同步风格        │
├───────────┼─────────────────┼────────────────┼─────────────────┤
│ 错误处理  │ 每层需要处理    │ 统一catch      │ try/catch      │
├───────────┼─────────────────┼────────────────┼─────────────────┤
│ 可读性    │ 回调地狱风险    │ 较好           │ 最佳           │
├───────────┼─────────────────┼────────────────┼─────────────────┤
│ 组合性    │ 差             │ 良好           │ 优秀           │
├───────────┼─────────────────┼────────────────┼─────────────────┤
│ 性能     │ 最轻量          │ 有开销         │ 轻量           │
├───────────┼─────────────────┼────────────────┼─────────────────┤
│ 取消支持  │ 手动实现        │ 部分支持       │ 可实现         │
├───────────┼─────────────────┼────────────────┼─────────────────┤
│ 调试     │ 困难            │ 中等           │ 相对容易       │
└───────────┴─────────────────┴────────────────┴─────────────────┘
*/

// 回调风格
void callback_style(std::function<void(int)> callback) {
    async_operation1([callback](int a) {
        async_operation2(a, [callback](int b) {
            async_operation3(b, [callback](int c) {
                callback(c);  // 回调地狱
            });
        });
    });
}

// Future风格
std::future<int> future_style() {
    return async_operation1()
        .then([](int a) { return async_operation2(a); })
        .then([](int b) { return async_operation3(b); });
}

// 协程风格
Task<int> coroutine_style() {
    int a = co_await async_operation1();
    int b = co_await async_operation2(a);
    int c = co_await async_operation3(b);
    co_return c;  // 清晰的同步风格
}
```

#### 性能基准测试

```cpp
// ============================================================
// 性能测试
// ============================================================

#include <chrono>
#include <iostream>

void benchmark_coroutine_creation() {
    constexpr int N = 1000000;

    auto start = std::chrono::high_resolution_clock::now();

    for (int i = 0; i < N; ++i) {
        auto task = []() -> Task<int> {
            co_return 42;
        }();
        // task被销毁
    }

    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::microseconds>(
        end - start);

    std::cout << "Created " << N << " coroutines in "
              << duration.count() << " us\n";
    std::cout << "Average: " << (duration.count() * 1000.0 / N)
              << " ns per coroutine\n";
}

void benchmark_coroutine_switching() {
    constexpr int N = 1000000;

    auto ping_pong = [](int count) -> Generator<int> {
        for (int i = 0; i < count; ++i) {
            co_yield i;
        }
    };

    auto start = std::chrono::high_resolution_clock::now();

    auto gen = ping_pong(N);
    int sum = 0;
    for (int val : gen) {
        sum += val;
    }

    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::microseconds>(
        end - start);

    std::cout << "Switched " << N << " times in "
              << duration.count() << " us\n";
    std::cout << "Average: " << (duration.count() * 1000.0 / N)
              << " ns per switch\n";
}

/*
典型结果（参考）：
- 协程创建：约 50-100 ns
- 协程切换：约 10-30 ns
- 线程创建：约 10-50 us（慢100-1000倍）
- 线程切换：约 1-10 us（慢100倍）
*/
```

#### 第四周检验标准

- [ ] 能实现AsyncGenerator异步生成器
- [ ] 能实现Channel并理解其同步语义
- [ ] 能将协程与Actor模型结合使用
- [ ] 能进行协程性能分析和优化
- [ ] 理解协程与其他异步模式的取舍

---

## 本月检验标准总览

### 理论知识
- [ ] 能解释C++20协程的编译器转换过程
- [ ] 能说出Promise Type的所有接口及其作用
- [ ] 理解对称转移如何避免栈溢出
- [ ] 能对比协程与线程、回调、Future的优劣

### 实践能力
- [ ] 能从零实现一个完整的Generator
- [ ] 能从零实现一个完整的Task<T>
- [ ] 能实现协程调度器（单线程和多线程）
- [ ] 能实现WhenAll/WhenAny等组合器
- [ ] 能实现Channel等并发原语

### 综合项目
- [ ] 完成一个异步运行时框架
- [ ] 能将协程与Month 19线程池集成
- [ ] 能将协程与Month 20 Actor模型集成

---

## 输出物清单

### 核心代码文件

1. **generator.hpp** - 同步生成器实现
   - 迭代器支持
   - 异常处理
   - RAII资源管理

2. **task.hpp** - 异步Task实现
   - 惰性启动
   - 对称转移
   - void特化

3. **awaitable.hpp** - Awaitable工具集
   - 标准Awaiter
   - 定时器
   - 组合器

4. **scheduler.hpp** - 调度器实现
   - 单线程事件循环
   - 多线程调度器
   - 与线程池集成

5. **async_generator.hpp** - 异步生成器
   - 异步迭代
   - 背压支持

6. **channel.hpp** - Go风格通道
   - 有界/无界缓冲
   - 关闭语义

7. **when_all.hpp** / **when_any.hpp** - 组合器

### 示例和测试

8. **examples/**
   - `basic_coroutine.cpp` - 基础示例
   - `generator_examples.cpp` - 生成器示例
   - `async_io.cpp` - 异步I/O示例
   - `producer_consumer.cpp` - 生产者消费者
   - `pipeline.cpp` - 管道模式

9. **benchmark/**
   - `creation_bench.cpp` - 创建性能
   - `switching_bench.cpp` - 切换性能
   - `compare_async.cpp` - 异步模式对比

### 学习笔记

10. **notes/**
    - `month21_week1_coroutine_basics.md`
    - `month21_week2_awaitable.md`
    - `month21_week3_task_system.md`
    - `month21_week4_advanced.md`

---

## 下月预告

Month 22将学习**协程应用：异步I/O**，将协程与io_uring/IOCP结合：

- io_uring异步I/O框架
- 协程化网络编程
- 协程化文件I/O
- 高性能服务器实现

掌握本月C++20协程基础后，下月将进入真正的异步I/O实战！
