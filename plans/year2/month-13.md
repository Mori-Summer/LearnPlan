# Month 13: 并发编程基础——线程与同步原语

## 本月主题概述

欢迎进入第二年的学习！并发编程是现代C++最具挑战性的领域之一。本月将从基础开始，理解线程的创建与管理、基本的同步原语，为后续的内存模型和无锁编程打下基础。

---

## 理论学习内容

### 第一周：并发与并行的基础概念

**学习目标**：建立并发编程的基本认知模型

**阅读材料**：
- [ ] 《C++ Concurrency in Action》第1-2章
- [ ] CppCon演讲："Back to Basics: Concurrency"
- [ ] 博客：Preshing on Programming - "A Introduction to Lock-Free Programming"

#### 详细学习目标（可衡量）

| 目标编号 | 学习目标 | 验收标准 |
|---------|---------|---------|
| W1-G1 | 区分并发与并行 | 能用自己的语言解释两者差异并举例 |
| W1-G2 | 理解竞态条件 | 能识别代码中的竞态条件并修复 |
| W1-G3 | 理解数据竞争 | 能解释为何数据竞争是UB |
| W1-G4 | 识别死锁四要素 | 能从代码中识别潜在死锁 |
| W1-G5 | 理解Amdahl定律 | 能计算并行加速比上限 |

---

#### Day 1: 并发模型与硬件基础（7小时）

**上午（3小时）：并发基础理论**

**核心概念**：

##### 并发 vs 并行
```cpp
// 并发（Concurrency）：多个任务在时间上重叠执行
// - 单核CPU通过时间片轮转实现
// - 关注的是程序结构

// 并行（Parallelism）：多个任务真正同时执行
// - 需要多核CPU
// - 关注的是执行方式

// 并发是并行的超集
// 你可以写并发程序而不并行执行（单核）
// 但并行执行必然是并发的
```

##### 硬件层面的并发支持
```cpp
// ============ CPU缓存与缓存一致性 ============
// 现代CPU架构：
// CPU Core 1 -> L1 Cache -> L2 Cache -> L3 Cache (共享) -> Main Memory
// CPU Core 2 -> L1 Cache -> L2 Cache /

// 缓存一致性协议（MESI）：
// M (Modified)  - 本地修改，其他核无效
// E (Exclusive) - 独占，未修改
// S (Shared)    - 多核共享，只读
// I (Invalid)   - 无效

// 理解这个对于理解false sharing很重要
struct BadLayout {
    int counter1;  // 可能与counter2在同一缓存行
    int counter2;  // 两个线程分别修改，导致缓存行乒乓
};

struct GoodLayout {
    alignas(64) int counter1;  // 64字节对齐（典型缓存行大小）
    alignas(64) int counter2;  // 各自独占缓存行
};
```

**下午（4小时）：硬件模型与性能分析**

##### Amdahl定律
```cpp
// Amdahl's Law: 并行化的理论加速比上限
// Speedup = 1 / (S + P/N)
// S = 串行部分比例
// P = 并行部分比例 (P = 1 - S)
// N = 处理器数量

// 示例：如果程序有20%必须串行执行
// S = 0.2, P = 0.8
// N = 4核: Speedup = 1 / (0.2 + 0.8/4) = 2.5x
// N = ∞:  Speedup = 1 / (0.2 + 0) = 5x (理论上限!)

// 实际代码分析
void analyze_parallelism() {
    // 串行部分：初始化
    auto data = load_data();  // 10%

    // 可并行部分：处理
    parallel_process(data);    // 80%

    // 串行部分：聚合
    auto result = aggregate(data);  // 10%

    // 理论最大加速比: 1 / 0.2 = 5x
}
```

**Day 1 练习任务**：
1. 计算：如果串行部分占30%，使用8核处理器的理论加速比是多少？
2. 实验：编写程序测量`std::thread::hardware_concurrency()`
3. 思考：为什么实际加速比通常低于Amdahl定律预测值？

---

#### Day 2: 竞态条件与数据竞争深入（7小时）

**上午（3小时）：竞态条件详解**

#### 为什么并发编程困难？
```cpp
// 1. 竞态条件（Race Condition）
int counter = 0;
void increment() {
    for (int i = 0; i < 1000000; ++i) {
        ++counter;  // 非原子操作！
        // 实际是: tmp = counter; tmp = tmp + 1; counter = tmp;
    }
}
// 两个线程同时执行，最终counter可能小于2000000

// 2. 数据竞争（Data Race）
// 多个线程同时访问同一内存位置，至少一个是写操作，没有同步
// 这是未定义行为！

// 3. 死锁（Deadlock）
std::mutex m1, m2;
// Thread 1: lock(m1), lock(m2)
// Thread 2: lock(m2), lock(m1)
// 如果交错执行，可能永久阻塞

// 4. 活锁（Livelock）
// 线程不断改变状态以响应对方，但都无法前进

// 5. 饥饿（Starvation）
// 某个线程永远无法获得所需资源
```

**下午（4小时）：数据竞争深入分析**

##### 数据竞争的精确定义
```cpp
// 数据竞争（Data Race）的C++标准定义：
// 当以下条件同时满足时，发生数据竞争：
// 1. 两个或多个线程并发访问同一内存位置
// 2. 至少一个访问是写操作
// 3. 访问之间没有同步（happens-before关系）

// 数据竞争 vs 竞态条件
// 数据竞争：未定义行为！程序可能崩溃、产生垃圾值
// 竞态条件：逻辑错误，程序行为取决于时序，但每次访问都是合法的

// 示例：有数据竞争
int shared = 0;
void writer() { shared = 42; }      // 写
void reader() { int x = shared; }   // 读
// 并发执行 -> 数据竞争 -> UB!

// 示例：有竞态条件但无数据竞争
std::atomic<int> atomic_shared{0};
void atomic_writer() { atomic_shared = 42; }
void atomic_reader() { int x = atomic_shared.load(); }
// 并发执行 -> 无数据竞争（原子操作）
// 但可能有竞态条件（读取顺序不确定）
```

##### TOCTOU（Time-of-check to time-of-use）
```cpp
// 经典的竞态条件模式
bool file_exists(const char* path);
void remove_file(const char* path);
void create_file(const char* path);

void vulnerable_code() {
    if (file_exists("/tmp/myfile")) {  // 检查
        // 窗口期：其他线程可能删除文件
        remove_file("/tmp/myfile");    // 使用
    }
}

// 更安全的做法：使用原子操作或锁
std::mutex file_mutex;
void safer_code() {
    std::lock_guard<std::mutex> lock(file_mutex);
    if (file_exists("/tmp/myfile")) {
        remove_file("/tmp/myfile");
    }
}
```

**Day 2 练习任务**：
```cpp
// 练习1：识别以下代码中的竞态条件/数据竞争
class BankAccount {
    int balance = 1000;
public:
    void withdraw(int amount) {
        if (balance >= amount) {
            balance -= amount;
        }
    }
    void deposit(int amount) {
        balance += amount;
    }
};
// 问题：两个线程同时操作会发生什么？

// 练习2：修复上述代码，消除数据竞争
```

---

#### Day 3: 死锁、活锁与饥饿（7小时）

**上午（3小时）：死锁深入分析**

##### 死锁的四个必要条件（Coffman条件）
```cpp
// 1. 互斥（Mutual Exclusion）：资源不能共享
// 2. 持有并等待（Hold and Wait）：持有资源的同时等待其他资源
// 3. 不可抢占（No Preemption）：资源不能被强制释放
// 4. 循环等待（Circular Wait）：存在等待环

// 经典死锁示例
std::mutex m1, m2;

void thread1() {
    std::lock_guard<std::mutex> lock1(m1);  // 获得m1
    std::this_thread::sleep_for(std::chrono::milliseconds(1));
    std::lock_guard<std::mutex> lock2(m2);  // 等待m2
}

void thread2() {
    std::lock_guard<std::mutex> lock2(m2);  // 获得m2
    std::this_thread::sleep_for(std::chrono::milliseconds(1));
    std::lock_guard<std::mutex> lock1(m1);  // 等待m1
}
// 循环等待：thread1等m2，thread2等m1 -> 死锁！
```

##### 死锁预防策略
```cpp
// 策略1：锁排序（破坏循环等待）
void ordered_locking() {
    // 总是按照地址顺序获取锁
    std::mutex* first = &m1 < &m2 ? &m1 : &m2;
    std::mutex* second = &m1 < &m2 ? &m2 : &m1;

    std::lock_guard<std::mutex> lock1(*first);
    std::lock_guard<std::mutex> lock2(*second);
}

// 策略2：一次性获取所有锁（破坏持有并等待）
void simultaneous_locking() {
    std::scoped_lock lock(m1, m2);  // C++17：原子地获取多个锁
}

// 策略3：尝试锁（破坏不可抢占）
void try_lock_approach() {
    while (true) {
        std::unique_lock<std::mutex> lock1(m1);
        if (m2.try_lock()) {
            std::lock_guard<std::mutex> lock2(m2, std::adopt_lock);
            // 成功获得两个锁
            break;
        }
        // m2获取失败，释放m1，稍后重试
    }
}
```

**下午（4小时）：活锁与饥饿**

##### 活锁
```cpp
// 活锁：线程在忙碌，但没有实际进展
// 比喻：两人在走廊相遇，都想让对方先过，结果同步左右移动

std::atomic<bool> flag1{false}, flag2{false};

void thread1_livelock() {
    while (true) {
        flag1 = true;
        while (flag2) {
            flag1 = false;  // 礼让
            std::this_thread::yield();
            flag1 = true;
        }
        // 临界区
        flag1 = false;
    }
}

void thread2_livelock() {
    while (true) {
        flag2 = true;
        while (flag1) {
            flag2 = false;  // 礼让
            std::this_thread::yield();
            flag2 = true;
        }
        // 临界区
        flag2 = false;
    }
}
// 两个线程可能同步礼让，永远无法进入临界区

// 解决：引入随机退避
void thread_with_backoff() {
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> dis(1, 100);

    while (true) {
        flag1 = true;
        while (flag2) {
            flag1 = false;
            std::this_thread::sleep_for(
                std::chrono::microseconds(dis(gen)));  // 随机等待
            flag1 = true;
        }
        // 临界区
        flag1 = false;
    }
}
```

##### 饥饿
```cpp
// 饥饿：某个线程长期无法获得资源

// 场景1：读写锁中写者饥饿
// 如果读者源源不断，写者可能永远等不到

// 场景2：优先级反转
// 低优先级线程持有锁，高优先级线程等待
// 中优先级线程抢占低优先级线程的CPU时间
// 结果：高优先级线程被中优先级线程间接阻塞

// 解决：优先级继承
// 当高优先级线程等待低优先级线程时，
// 临时提升低优先级线程的优先级
```

**Day 3 练习任务**：
1. 识别以下代码是否会死锁？如果会，请修复
2. 设计一个场景演示活锁
3. 解释Mars Pathfinder任务中的优先级反转问题

---

#### Day 4: 并发设计模式与分析工具（7小时）

**上午（3小时）：并发设计原则**

##### 设计原则
```cpp
// 原则1：最小化共享状态
// 每个线程尽量使用本地数据

void good_design() {
    std::vector<int> data = get_large_data();
    std::vector<int> results(data.size());

    // 每个线程处理独立的数据分片
    auto worker = [&](size_t start, size_t end) {
        for (size_t i = start; i < end; ++i) {
            results[i] = process(data[i]);  // 无共享！
        }
    };

    // 划分任务
    std::thread t1(worker, 0, data.size()/2);
    std::thread t2(worker, data.size()/2, data.size());
    t1.join();
    t2.join();
}

// 原则2：不可变数据天然线程安全
class ImmutableConfig {
    const std::string server_;
    const int port_;
public:
    ImmutableConfig(std::string s, int p)
        : server_(std::move(s)), port_(p) {}

    // 只有const getter，无setter
    const std::string& server() const { return server_; }
    int port() const { return port_; }
};

// 原则3：消息传递优于共享内存
// Actor模型：每个actor有自己的状态，通过消息通信
```

**下午（4小时）：调试与分析工具**

##### 使用ThreadSanitizer
```bash
# 编译时启用TSan
g++ -fsanitize=thread -g -O1 program.cpp -o program

# 运行后会报告数据竞争
# WARNING: ThreadSanitizer: data race
#   Write of size 4 at 0x... by thread T1:
#     #0 increment() program.cpp:42
#   Previous read of size 4 at 0x... by thread T2:
#     #0 increment() program.cpp:42
```

##### 使用Helgrind（Valgrind工具）
```bash
# 检测锁使用问题
valgrind --tool=helgrind ./program

# 可以检测：
# - 锁顺序错误（潜在死锁）
# - 数据竞争
# - 锁的误用
```

**Day 4 练习任务**：
1. 使用ThreadSanitizer编译并运行本周的竞态条件示例
2. 分析TSan输出，定位问题
3. 修复问题后重新验证

---

#### Day 5: 综合练习与案例分析（7小时）

**上午（3小时）：经典并发bug案例分析**

##### 案例1：Therac-25事故
```cpp
// 简化的竞态条件模型
class TherapyMachine {
    int beam_type;        // 0=低能, 1=高能
    bool spreader_in;     // 扩散器是否就位

    void set_beam(int type) {
        beam_type = type;
    }

    void set_spreader(bool in) {
        spreader_in = in;
    }

    void fire() {
        // 竞态条件：检查时扩散器就位，发射时可能已移除
        if (beam_type == 1 && !spreader_in) {
            // 高能束直接照射病人！
        }
    }
};
// 教训：安全关键系统必须有硬件互锁
```

**下午（4小时）：综合项目**

##### 项目：生产者-消费者缓冲区
```cpp
// 任务：实现一个有界缓冲区
// 要求：
// 1. 支持多生产者多消费者
// 2. 无数据竞争
// 3. 无死锁
// 4. 性能可接受

template <typename T, size_t N>
class BoundedBuffer {
    std::array<T, N> buffer_;
    size_t head_ = 0;
    size_t tail_ = 0;
    size_t count_ = 0;

    std::mutex mutex_;
    std::condition_variable not_full_;
    std::condition_variable not_empty_;

public:
    void push(T item);  // 实现
    T pop();            // 实现
};
```

#### 调试技巧和常见错误分析（第一周）

| 错误类型 | 症状 | 检测方法 | 修复建议 |
|---------|------|---------|---------|
| 数据竞争 | 随机崩溃/错误值 | TSan | 添加同步原语 |
| 竞态条件 | 结果不确定 | 代码审查 | 原子操作/锁 |
| 死锁 | 程序挂起 | Helgrind | 锁排序/scoped_lock |
| 活锁 | CPU 100%无进展 | 日志/调试 | 随机退避 |
| False Sharing | 性能差 | perf工具 | 缓存行对齐 |

#### 面试常见问题（第一周）

1. **Q: 什么是数据竞争？为什么是未定义行为？**
   - A: 多线程无同步地并发访问同一内存位置且至少一个是写。UB因为编译器和CPU可能重排序、缓存不一致等。

2. **Q: 死锁的四个必要条件是什么？如何避免？**
   - A: 互斥、持有并等待、不可抢占、循环等待。破坏任一条件即可，常用锁排序或scoped_lock。

3. **Q: 并发和并行的区别？**
   - A: 并发是程序结构（可交错执行），并行是执行方式（同时执行）。并发不一定并行。

4. **Q: 什么是False Sharing？如何解决？**
   - A: 不同线程修改同一缓存行的不同变量，导致缓存行乒乓。解决：alignas(64)对齐。

5. **Q: Amdahl定律是什么？有什么局限性？**
   - A: 加速比=1/(S+P/N)，预测并行化收益上限。局限：忽略通信开销、缓存效应等。

#### 第一周检验清单

- [ ] 能区分并发与并行，并举出实例
- [ ] 能识别代码中的数据竞争和竞态条件
- [ ] 能解释死锁四要素并设计预防策略
- [ ] 能使用ThreadSanitizer检测问题
- [ ] 完成BoundedBuffer实现
- [ ] 笔记：`notes/week01_concurrency_fundamentals.md`

---

### 第二周：std::thread详解

**学习目标**：掌握线程的创建、管理和生命周期

#### 详细学习目标（可衡量）

| 目标编号 | 学习目标 | 验收标准 |
|---------|---------|---------|
| W2-G1 | 掌握线程创建方式 | 能用函数、lambda、成员函数创建线程 |
| W2-G2 | 理解参数传递机制 | 能正确处理值传递、引用传递、移动语义 |
| W2-G3 | 管理线程生命周期 | 能正确使用join/detach，处理异常情况 |
| W2-G4 | 使用线程本地存储 | 能正确使用thread_local |
| W2-G5 | 实现RAII线程包装 | 能实现ScopedThread/JoiningThread |

---

#### Day 1: 线程创建与参数传递（7小时）

**上午（3小时）：线程创建基础**

```cpp
#include <thread>
#include <iostream>

// 1. 基本创建
void task() {
    std::cout << "Running in thread " << std::this_thread::get_id() << "\n";
}

int main() {
    std::thread t(task);
    t.join();  // 等待线程结束
}

// 2. 传递参数
void task_with_args(int x, const std::string& s) {
    std::cout << x << " " << s << "\n";
}

std::thread t1(task_with_args, 42, "hello");

// 注意：参数默认被拷贝！
std::string str = "world";
std::thread t2(task_with_args, 1, str);  // str被拷贝

// 传引用需要std::ref
void modify(int& x) { x = 100; }
int value = 0;
std::thread t3(modify, std::ref(value));  // 必须用std::ref
```

**下午（4小时）：高级创建方式**

```cpp
// ============ 使用Lambda创建线程 ============
int main() {
    int local_var = 42;

    // 值捕获
    std::thread t1([local_var]() {
        std::cout << local_var << "\n";  // 安全：拷贝
    });

    // 引用捕获（危险！）
    std::thread t2([&local_var]() {
        // 如果main退出，local_var可能已销毁
        std::cout << local_var << "\n";  // 可能悬垂引用
    });

    t1.join();
    t2.join();  // 必须在local_var生命周期内
}

// ============ 使用成员函数 ============
class Worker {
public:
    void do_work(int x) {
        std::cout << "Working on " << x << "\n";
    }
};

void use_member_function() {
    Worker w;
    // 成员函数指针 + 对象指针 + 参数
    std::thread t(&Worker::do_work, &w, 42);
    t.join();
}

// ============ 使用可调用对象 ============
class Task {
public:
    void operator()(int x) const {
        std::cout << "Task: " << x << "\n";
    }
};

void use_callable_object() {
    // 注意：额外的括号避免"最令人困惑的解析"
    std::thread t1((Task()), 42);       // OK
    // std::thread t1(Task(), 42);      // 可能被解析为函数声明！

    std::thread t2{Task{}, 42};         // C++11统一初始化，更清晰
    t1.join();
    t2.join();
}
```

##### 参数传递的陷阱
```cpp
// ============ 陷阱1：隐式转换和悬垂引用 ============
void process(const std::string& s) {
    std::cout << s << "\n";
}

void dangerous() {
    char buffer[] = "hello";
    std::thread t(process, buffer);  // 危险！
    t.detach();
    // buffer -> const char* -> std::string 的转换
    // 可能在detach后才发生，此时buffer已销毁
}

void safe() {
    char buffer[] = "hello";
    std::thread t(process, std::string(buffer));  // 安全
    t.detach();
    // 显式构造string，在当前线程完成
}

// ============ 陷阱2：忘记std::ref ============
void increment(int& x) { ++x; }

void wrong_ref() {
    int n = 0;
    std::thread t(increment, n);  // 编译错误或传递拷贝！
    t.join();
    // n 仍然是 0
}

void correct_ref() {
    int n = 0;
    std::thread t(increment, std::ref(n));
    t.join();
    // n 现在是 1
}

// ============ 陷阱3：unique_ptr的移动 ============
void process_ptr(std::unique_ptr<int> p) {
    std::cout << *p << "\n";
}

void move_unique_ptr() {
    auto ptr = std::make_unique<int>(42);
    // std::thread t(process_ptr, ptr);  // 错误：不能拷贝
    std::thread t(process_ptr, std::move(ptr));  // OK
    t.join();
    // ptr 现在为空
}
```

**Day 1 练习任务**：
```cpp
// 练习1：用三种方式创建线程（函数、lambda、成员函数）
// 练习2：实现一个计数器，多线程安全地累加到1000000
// 练习3：找出以下代码的bug
void buggy() {
    std::vector<int> data = {1, 2, 3, 4, 5};
    std::thread t([&data]() {
        for (int x : data) std::cout << x;
    });
    t.detach();
}
```

---

#### Day 2: 线程生命周期管理（7小时）

**上午（3小时）：join与detach**

```cpp
// ============ join vs detach 详解 ============

// join: 阻塞等待线程完成
void join_example() {
    std::thread t([]() {
        std::this_thread::sleep_for(std::chrono::seconds(2));
        std::cout << "Thread finished\n";
    });

    std::cout << "Before join\n";
    t.join();  // 阻塞，直到t完成
    std::cout << "After join\n";
    // 输出顺序：Before join -> Thread finished -> After join
}

// detach: 分离线程，后台运行
void detach_example() {
    std::thread t([]() {
        std::this_thread::sleep_for(std::chrono::seconds(2));
        std::cout << "Thread finished\n";  // 可能不输出！
    });

    t.detach();
    std::cout << "Thread detached\n";
    // 如果main立即退出，分离的线程会被强制终止
}

// ============ 线程对象销毁时的行为 ============
void destruction_behavior() {
    std::thread t(some_task);

    // 如果t销毁时仍然joinable，调用std::terminate()！
    // 必须在销毁前调用join()或detach()
}

// ============ 移动语义 ============
std::thread create_thread() {
    return std::thread([]() { /* work */ });  // 可以返回
}

void transfer_ownership() {
    std::thread t1(some_task);
    std::thread t2 = std::move(t1);  // t1变空，t2接管线程

    // t1.joinable() == false
    // t2.joinable() == true

    std::thread t3;
    t3 = std::move(t2);  // 移动赋值

    // 如果t3之前已经有线程且joinable，会调用terminate!
}
```

**下午（4小时）：异常安全与RAII**

```cpp
// ============ 异常安全问题 ============
void exception_unsafe() {
    std::thread t(some_task);
    // 如果这里抛出异常...
    do_something_that_might_throw();
    // ...join永远不会被调用，程序terminate!
    t.join();
}

// ============ RAII解决方案1：ThreadGuard ============
class ThreadGuard {
    std::thread& t_;
public:
    explicit ThreadGuard(std::thread& t) : t_(t) {}
    ~ThreadGuard() {
        if (t_.joinable()) {
            t_.join();
        }
    }
    ThreadGuard(const ThreadGuard&) = delete;
    ThreadGuard& operator=(const ThreadGuard&) = delete;
};

void exception_safe_v1() {
    std::thread t(some_task);
    ThreadGuard guard(t);  // 即使异常也会join
    do_something_that_might_throw();
}

// ============ RAII解决方案2：ScopedThread（拥有线程）============
class ScopedThread {
    std::thread t_;
public:
    explicit ScopedThread(std::thread t) : t_(std::move(t)) {
        if (!t_.joinable()) {
            throw std::logic_error("No thread");
        }
    }

    ~ScopedThread() {
        t_.join();  // 一定会join
    }

    ScopedThread(const ScopedThread&) = delete;
    ScopedThread& operator=(const ScopedThread&) = delete;

    // 可选：支持移动
    ScopedThread(ScopedThread&&) = default;
    ScopedThread& operator=(ScopedThread&&) = default;
};

// ============ C++20: std::jthread ============
#include <stop_token>

void jthread_example() {
    std::jthread t([]() {
        std::cout << "Working...\n";
    });
    // 不需要手动join！
    // jthread析构时自动join
}

// jthread还支持协作式取消
void jthread_with_stop() {
    std::jthread t([](std::stop_token token) {
        while (!token.stop_requested()) {
            std::cout << "Working...\n";
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
        }
        std::cout << "Stopped!\n";
    });

    std::this_thread::sleep_for(std::chrono::seconds(1));
    t.request_stop();  // 请求停止
    // 析构时自动join
}
```

**Day 2 练习任务**：
```cpp
// 练习1：实现一个JoiningThread类，类似ScopedThread但支持配置join或detach
enum class ThreadAction { join, detach };

class JoiningThread {
public:
    JoiningThread(std::thread t, ThreadAction action = ThreadAction::join);
    // 实现...
};

// 练习2：用jthread重写第一周的多线程计数器
```

---

#### Day 3: 线程本地存储与线程标识（7小时）

**上午（3小时）：线程本地存储**

```cpp
// thread_local: 每个线程有独立的变量副本
thread_local int tls_counter = 0;

void increment_tls() {
    ++tls_counter;  // 每个线程修改自己的副本
    std::cout << "Thread " << std::this_thread::get_id()
              << " counter = " << tls_counter << "\n";
}

int main() {
    std::thread t1([]{ for(int i=0; i<5; ++i) increment_tls(); });
    std::thread t2([]{ for(int i=0; i<5; ++i) increment_tls(); });
    t1.join();
    t2.join();
    // 每个线程的counter独立增长到5
}
```

##### thread_local的高级用法
```cpp
// ============ thread_local与类成员 ============
class ThreadLogger {
    static thread_local std::string thread_name_;
    static thread_local int log_count_;

public:
    static void set_thread_name(const std::string& name) {
        thread_name_ = name;
    }

    static void log(const std::string& msg) {
        ++log_count_;
        std::cout << "[" << thread_name_ << "#" << log_count_ << "] "
                  << msg << "\n";
    }
};

// 定义（在cpp文件中）
thread_local std::string ThreadLogger::thread_name_ = "unnamed";
thread_local int ThreadLogger::log_count_ = 0;

// ============ thread_local与初始化 ============
thread_local std::unique_ptr<ExpensiveResource> tls_resource;

ExpensiveResource& get_resource() {
    if (!tls_resource) {
        tls_resource = std::make_unique<ExpensiveResource>();
    }
    return *tls_resource;
}

// ============ thread_local的生命周期 ============
// 1. 首次访问时初始化（延迟初始化）
// 2. 线程结束时销毁（在thread_local析构函数中）

class ThreadData {
public:
    ThreadData() { std::cout << "ThreadData created\n"; }
    ~ThreadData() { std::cout << "ThreadData destroyed\n"; }
};

thread_local ThreadData data;  // 每个使用它的线程会创建自己的实例
```

**下午（4小时）：线程标识与硬件信息**

##### 线程标识
```cpp
// ============ std::this_thread命名空间 ============
void thread_info() {
    // 获取当前线程ID
    std::thread::id this_id = std::this_thread::get_id();
    std::cout << "Thread ID: " << this_id << "\n";

    // 让出CPU时间片
    std::this_thread::yield();

    // 休眠
    std::this_thread::sleep_for(std::chrono::milliseconds(100));
    std::this_thread::sleep_until(
        std::chrono::steady_clock::now() + std::chrono::seconds(1));
}

// ============ 使用线程ID进行调试 ============
std::map<std::thread::id, std::string> thread_names;
std::mutex names_mutex;

void register_thread(const std::string& name) {
    std::lock_guard<std::mutex> lock(names_mutex);
    thread_names[std::this_thread::get_id()] = name;
}

std::string get_thread_name() {
    std::lock_guard<std::mutex> lock(names_mutex);
    auto it = thread_names.find(std::this_thread::get_id());
    return (it != thread_names.end()) ? it->second : "unknown";
}

// ============ 硬件并发度 ============
void hardware_info() {
    unsigned int n = std::thread::hardware_concurrency();
    std::cout << "Hardware threads: " << n << "\n";

    // 如果返回0，表示无法确定
    // 通常用于决定线程池大小
    unsigned int pool_size = (n > 0) ? n : 2;
}
```

**Day 3 练习任务**：
```cpp
// 练习1：使用thread_local实现每线程的性能计数器
class PerThreadStats {
public:
    void record_operation(const std::string& name, double duration);
    void print_stats();  // 打印当前线程的统计
    static void print_all_stats();  // 打印所有线程的统计
};

// 练习2：实现一个线程命名工具
```

---

#### Day 4: 并发算法初探（7小时）

**上午（3小时）：并行STL算法**

```cpp
#include <execution>
#include <algorithm>
#include <numeric>
#include <vector>

void parallel_algorithms() {
    std::vector<int> data(10000000);
    std::iota(data.begin(), data.end(), 0);

    // 顺序执行
    std::sort(std::execution::seq, data.begin(), data.end());

    // 并行执行
    std::sort(std::execution::par, data.begin(), data.end());

    // 并行且允许向量化
    std::sort(std::execution::par_unseq, data.begin(), data.end());

    // C++20: 无序执行
    // std::sort(std::execution::unseq, data.begin(), data.end());

    // 并行reduce
    auto sum = std::reduce(std::execution::par,
                           data.begin(), data.end(), 0LL);

    // 并行transform_reduce
    auto sum_squares = std::transform_reduce(
        std::execution::par,
        data.begin(), data.end(),
        0LL,
        std::plus<>(),
        [](int x) { return (long long)x * x; }
    );
}
```

**下午（4小时）：手动任务划分**

```cpp
// ============ 数据并行模式 ============
template <typename Iterator, typename Func>
void parallel_for_each(Iterator begin, Iterator end, Func f) {
    auto len = std::distance(begin, end);
    if (len == 0) return;

    unsigned int num_threads = std::thread::hardware_concurrency();
    auto chunk_size = (len + num_threads - 1) / num_threads;

    std::vector<std::thread> threads;
    Iterator chunk_begin = begin;

    for (unsigned int i = 0; i < num_threads && chunk_begin != end; ++i) {
        Iterator chunk_end = chunk_begin;
        std::advance(chunk_end, std::min<long>(chunk_size,
                     std::distance(chunk_begin, end)));

        threads.emplace_back([=]() {
            std::for_each(chunk_begin, chunk_end, f);
        });

        chunk_begin = chunk_end;
    }

    for (auto& t : threads) {
        t.join();
    }
}

// 使用示例
void use_parallel_for_each() {
    std::vector<int> data(1000000, 1);
    parallel_for_each(data.begin(), data.end(), [](int& x) {
        x *= 2;
    });
}
```

**Day 4 练习任务**：
```cpp
// 练习1：实现parallel_transform
template <typename InputIt, typename OutputIt, typename Func>
OutputIt parallel_transform(InputIt first, InputIt last,
                           OutputIt d_first, Func f);

// 练习2：比较seq/par/par_unseq三种策略的性能
```

---

#### Day 5: 综合项目——简单线程池（7小时）

**上午（3小时）：设计简单线程池**

```cpp
// ============ 简单线程池 V1 ============
class SimpleThreadPool {
    std::vector<std::thread> workers_;
    std::queue<std::function<void()>> tasks_;
    std::mutex mutex_;
    std::condition_variable cv_;
    bool stop_ = false;

public:
    explicit SimpleThreadPool(size_t num_threads) {
        for (size_t i = 0; i < num_threads; ++i) {
            workers_.emplace_back([this]() {
                while (true) {
                    std::function<void()> task;
                    {
                        std::unique_lock<std::mutex> lock(mutex_);
                        cv_.wait(lock, [this]() {
                            return stop_ || !tasks_.empty();
                        });

                        if (stop_ && tasks_.empty()) return;

                        task = std::move(tasks_.front());
                        tasks_.pop();
                    }
                    task();
                }
            });
        }
    }

    ~SimpleThreadPool() {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            stop_ = true;
        }
        cv_.notify_all();
        for (auto& worker : workers_) {
            worker.join();
        }
    }

    void submit(std::function<void()> task) {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            if (stop_) throw std::runtime_error("Pool stopped");
            tasks_.push(std::move(task));
        }
        cv_.notify_one();
    }
};
```

**下午（4小时）：扩展功能**

```cpp
// ============ 线程池 V2：支持返回值 ============
class ThreadPoolV2 {
    // ... 成员变量同上 ...

public:
    template <typename F, typename... Args>
    auto submit(F&& f, Args&&... args)
        -> std::future<std::invoke_result_t<F, Args...>>
    {
        using return_type = std::invoke_result_t<F, Args...>;

        auto task = std::make_shared<std::packaged_task<return_type()>>(
            std::bind(std::forward<F>(f), std::forward<Args>(args)...)
        );

        std::future<return_type> result = task->get_future();

        {
            std::lock_guard<std::mutex> lock(mutex_);
            if (stop_) {
                throw std::runtime_error("Pool stopped");
            }
            tasks_.emplace([task]() { (*task)(); });
        }
        cv_.notify_one();

        return result;
    }
};

// 使用示例
void use_thread_pool() {
    ThreadPoolV2 pool(4);

    auto future1 = pool.submit([](int x) { return x * 2; }, 21);
    auto future2 = pool.submit([]() { return std::string("hello"); });

    std::cout << future1.get() << "\n";  // 42
    std::cout << future2.get() << "\n";  // hello
}
```

#### 调试技巧和常见错误分析（第二周）

| 错误类型 | 症状 | 检测方法 | 修复建议 |
|---------|------|---------|---------|
| 忘记join/detach | 程序terminate | 运行时崩溃 | 使用RAII包装器 |
| 悬垂引用 | 随机崩溃 | ASan/TSan | 值捕获或确保生命周期 |
| 参数转换时机 | 数据错误 | 代码审查 | 显式构造参数 |
| 线程泄漏 | 资源耗尽 | 监控工具 | 使用线程池 |
| 过多线程 | 性能下降 | 性能分析 | 控制线程数量 |

#### 面试常见问题（第二周）

1. **Q: join和detach的区别？什么时候用哪个？**
   - A: join阻塞等待，detach分离后台运行。需要结果或确保完成用join，不关心结果用detach。

2. **Q: 为什么std::thread的析构函数不自动join？**
   - A: 设计选择：避免隐藏的阻塞。显式管理更清晰，也可以用jthread自动join。

3. **Q: thread_local变量什么时候初始化和销毁？**
   - A: 首次访问时初始化（延迟），线程结束时销毁。

4. **Q: std::ref的作用是什么？**
   - A: 创建reference_wrapper，使参数以引用方式传递给线程函数。

5. **Q: 如何实现一个基本的线程池？**
   - A: 工作线程队列+任务队列+互斥锁+条件变量。工作线程循环等待任务。

#### 第二周检验清单

- [ ] 能用多种方式创建线程
- [ ] 理解参数传递的陷阱
- [ ] 能实现ThreadGuard/ScopedThread
- [ ] 理解并能使用thread_local
- [ ] 实现SimpleThreadPool
- [ ] 笔记：`notes/week02_thread_management.md`

---

### 第三周：互斥锁（Mutex）

**学习目标**：掌握互斥锁的正确使用

#### 详细学习目标（可衡量）

| 目标编号 | 学习目标 | 验收标准 |
|---------|---------|---------|
| W3-G1 | 掌握基本mutex使用 | 能正确使用lock/unlock |
| W3-G2 | 掌握RAII锁管理 | 能选择合适的lock_guard/unique_lock/scoped_lock |
| W3-G3 | 理解死锁预防 | 能用std::lock或scoped_lock安全获取多锁 |
| W3-G4 | 掌握读写锁 | 能使用shared_mutex优化读多写少场景 |
| W3-G5 | 实现线程安全容器 | 能实现ConcurrentHashMap |

---

#### Day 1: 基本mutex与RAII锁（7小时）

**上午（3小时）：mutex基础**

```cpp
#include <mutex>

// 1. 基本mutex
std::mutex mtx;
int shared_data = 0;

void safe_increment() {
    mtx.lock();
    ++shared_data;
    mtx.unlock();
}

// 问题：如果中间抛异常，unlock不会执行 -> 死锁！

// 2. RAII锁管理器
void better_increment() {
    std::lock_guard<std::mutex> lock(mtx);  // 构造时lock
    ++shared_data;
    // 析构时自动unlock，即使异常也能正确释放
}

// C++17: 类模板参数推导
void even_better() {
    std::lock_guard lock(mtx);  // 自动推导类型
    ++shared_data;
}
```

**下午（4小时）：锁管理器详解**

---

#### Day 2: lock_guard vs unique_lock（7小时）

**上午（3小时）：unique_lock详解**

```cpp
// 3. unique_lock: 更灵活
void flexible_locking() {
    std::unique_lock<std::mutex> lock(mtx);

    // 可以手动unlock/lock
    ++shared_data;
    lock.unlock();
    // ... 做一些不需要锁的工作
    lock.lock();
    ++shared_data;

    // 可以移动
    std::unique_lock<std::mutex> lock2 = std::move(lock);

    // 可以延迟锁定
    std::unique_lock<std::mutex> lock3(mtx, std::defer_lock);
    // ... 稍后
    lock3.lock();
}
```

##### lock_guard vs unique_lock 对比
```cpp
// ============ 选择指南 ============
// lock_guard: 简单场景，整个作用域持有锁
// unique_lock: 需要以下特性时
//   - 延迟锁定（defer_lock）
//   - 提前解锁
//   - 移动语义
//   - 配合条件变量
//   - 尝试锁定（try_lock）

// ============ unique_lock构造选项 ============
std::mutex m;

// 默认：构造时锁定
std::unique_lock<std::mutex> l1(m);

// defer_lock：不锁定，稍后手动锁定
std::unique_lock<std::mutex> l2(m, std::defer_lock);
l2.lock();  // 手动锁定

// try_to_lock：尝试锁定，不阻塞
std::unique_lock<std::mutex> l3(m, std::try_to_lock);
if (l3.owns_lock()) {
    // 获得锁
}

// adopt_lock：接管已锁定的mutex
m.lock();
std::unique_lock<std::mutex> l4(m, std::adopt_lock);
// l4接管m的锁，析构时会unlock

// ============ unique_lock的移动 ============
std::unique_lock<std::mutex> get_lock() {
    std::mutex& m = get_mutex();
    std::unique_lock<std::mutex> lock(m);
    return lock;  // 移动返回
}
```

**下午（4小时）：锁的粒度与范围**

```cpp
// ============ 锁粒度权衡 ============

// 粗粒度锁：简单但可能成为瓶颈
class CoarseGrainedList {
    std::mutex mutex_;
    std::list<int> data_;
public:
    void add(int value) {
        std::lock_guard<std::mutex> lock(mutex_);  // 整个list一把锁
        data_.push_back(value);
    }

    bool contains(int value) {
        std::lock_guard<std::mutex> lock(mutex_);
        return std::find(data_.begin(), data_.end(), value) != data_.end();
    }
};

// 细粒度锁：更高并发但更复杂
class FineGrainedList {
    struct Node {
        int value;
        std::unique_ptr<Node> next;
        std::mutex mutex;
    };
    Node head_;
public:
    void add(int value);  // 需要手拉手锁定
};

// ============ 最小化临界区 ============
void minimize_critical_section() {
    // 不好：在锁内做所有工作
    std::lock_guard<std::mutex> lock(mutex_);
    auto data = expensive_computation();  // 耗时！
    shared_data_ = data;

    // 好：只在必要时持有锁
    auto data = expensive_computation();  // 锁外计算
    {
        std::lock_guard<std::mutex> lock(mutex_);
        shared_data_ = data;  // 快速赋值
    }
}
```

**Day 2 练习任务**：
```cpp
// 练习1：用unique_lock实现一个可中断的等待
class InterruptibleWait {
    std::mutex mutex_;
    bool interrupted_ = false;
public:
    void interrupt();
    bool wait_for(std::chrono::milliseconds timeout);
};

// 练习2：分析以下代码的锁粒度问题
class BadCache {
    std::mutex mutex_;
    std::map<std::string, std::string> cache_;
public:
    std::string get(const std::string& key) {
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = cache_.find(key);
        if (it == cache_.end()) {
            auto value = expensive_fetch(key);  // 问题！
            cache_[key] = value;
            return value;
        }
        return it->second;
    }
};
```

---

#### Day 3: 死锁避免与多锁获取（7小时）

**上午（3小时）：多锁场景**

```cpp
// 4. 避免死锁：同时锁定多个mutex
std::mutex m1, m2;

void deadlock_prone() {
    // 线程1: lock(m1), lock(m2)
    // 线程2: lock(m2), lock(m1)
    // 可能死锁！
}

void deadlock_free() {
    // 方法1: std::lock同时锁定
    std::lock(m1, m2);
    std::lock_guard<std::mutex> lg1(m1, std::adopt_lock);
    std::lock_guard<std::mutex> lg2(m2, std::adopt_lock);

    // 方法2: C++17 scoped_lock
    std::scoped_lock lock(m1, m2);  // 同时锁定，内部避免死锁
}
```

##### std::lock的工作原理
```cpp
// std::lock使用死锁避免算法（通常是try-and-back-off）
// 内部类似：
template <typename L1, typename L2>
void lock_impl(L1& l1, L2& l2) {
    while (true) {
        // 尝试锁定第一个
        std::unique_lock<L1> first(l1);
        // 尝试锁定第二个（不阻塞）
        if (l2.try_lock()) {
            first.release();  // 成功，释放unique_lock的管理权
            return;
        }
        // 失败，释放第一个，重试
    }
}

// ============ scoped_lock是最佳选择 ============
void transfer(Account& from, Account& to, int amount) {
    // 一行代码，安全获取两个锁
    std::scoped_lock lock(from.mutex_, to.mutex_);
    from.balance_ -= amount;
    to.balance_ += amount;
}
```

**下午（4小时）：层次锁与锁排序**

```cpp
// ============ 层次锁：强制锁顺序 ============
class HierarchicalMutex {
    std::mutex internal_mutex_;
    unsigned long const hierarchy_value_;
    unsigned long previous_hierarchy_value_ = 0;
    static thread_local unsigned long this_thread_hierarchy_value_;

    void check_for_hierarchy_violation() {
        if (this_thread_hierarchy_value_ <= hierarchy_value_) {
            throw std::logic_error("mutex hierarchy violated");
        }
    }

    void update_hierarchy_value() {
        previous_hierarchy_value_ = this_thread_hierarchy_value_;
        this_thread_hierarchy_value_ = hierarchy_value_;
    }

public:
    explicit HierarchicalMutex(unsigned long value)
        : hierarchy_value_(value) {}

    void lock() {
        check_for_hierarchy_violation();
        internal_mutex_.lock();
        update_hierarchy_value();
    }

    void unlock() {
        if (this_thread_hierarchy_value_ != hierarchy_value_) {
            throw std::logic_error("mutex hierarchy violated");
        }
        this_thread_hierarchy_value_ = previous_hierarchy_value_;
        internal_mutex_.unlock();
    }

    bool try_lock() {
        check_for_hierarchy_violation();
        if (!internal_mutex_.try_lock()) return false;
        update_hierarchy_value();
        return true;
    }
};

thread_local unsigned long
    HierarchicalMutex::this_thread_hierarchy_value_ = ULONG_MAX;

// 使用示例
HierarchicalMutex high_level(10000);
HierarchicalMutex medium_level(5000);
HierarchicalMutex low_level(1000);

void correct_order() {
    std::lock_guard<HierarchicalMutex> h(high_level);
    std::lock_guard<HierarchicalMutex> m(medium_level);  // OK
    std::lock_guard<HierarchicalMutex> l(low_level);     // OK
}

void wrong_order() {
    std::lock_guard<HierarchicalMutex> l(low_level);
    std::lock_guard<HierarchicalMutex> h(high_level);  // 抛出异常！
}
```

**Day 3 练习任务**：
```cpp
// 练习1：实现银行转账，避免死锁
class BankAccount {
    mutable std::mutex mutex_;
    double balance_;
public:
    void transfer(BankAccount& to, double amount);
    // 实现安全的转账
};

// 练习2：完善HierarchicalMutex，使其满足Lockable概念
```

---

#### Day 4: 读写锁与特殊mutex（7小时）

**上午（3小时）：shared_mutex**

```cpp
// ============ shared_mutex (C++17) ============
#include <shared_mutex>

class ThreadSafeCache {
    mutable std::shared_mutex mutex_;
    std::map<std::string, std::string> cache_;

public:
    // 读操作：共享锁，多个读者可同时访问
    std::optional<std::string> get(const std::string& key) const {
        std::shared_lock<std::shared_mutex> lock(mutex_);
        auto it = cache_.find(key);
        if (it != cache_.end()) {
            return it->second;
        }
        return std::nullopt;
    }

    // 写操作：独占锁
    void put(const std::string& key, const std::string& value) {
        std::unique_lock<std::shared_mutex> lock(mutex_);
        cache_[key] = value;
    }

    // 删除操作：独占锁
    void remove(const std::string& key) {
        std::unique_lock<std::shared_mutex> lock(mutex_);
        cache_.erase(key);
    }

    size_t size() const {
        std::shared_lock<std::shared_mutex> lock(mutex_);
        return cache_.size();
    }
};

// ============ 读写锁的注意事项 ============
// 1. 写者饥饿：如果读者源源不断，写者可能永远等待
// 2. 升级锁：不能直接从shared_lock升级到unique_lock
// 3. 性能：如果读写比例接近，可能不比普通mutex好

// 不能这样做：
void bad_upgrade() {
    std::shared_lock<std::shared_mutex> shared(mutex_);
    // 读取...
    // shared.unlock();  // 必须先释放
    // std::unique_lock<std::shared_mutex> unique(mutex_);  // 再获取
    // 这期间可能有其他写者插入！
}
```

**下午（4小时）：递归锁与定时锁**

```cpp
// 5. 递归锁
std::recursive_mutex rmtx;

void recursive_func(int depth) {
    std::lock_guard<std::recursive_mutex> lock(rmtx);
    if (depth > 0) {
        recursive_func(depth - 1);  // 同一线程可以多次锁定
    }
}
// 注意：递归锁通常是设计问题的标志，尽量避免

// ============ 为什么避免递归锁？ ============
// 1. 隐藏设计问题：可能是代码结构混乱的信号
// 2. 性能开销：需要维护计数器和线程ID
// 3. 更难推理：不清楚锁被持有多少次

// 重构示例：
class BadDesign {
    std::recursive_mutex mutex_;
    void a() {
        std::lock_guard<std::recursive_mutex> lock(mutex_);
        // ...
        b();  // 递归锁定
    }
    void b() {
        std::lock_guard<std::recursive_mutex> lock(mutex_);
        // ...
    }
};

class BetterDesign {
    std::mutex mutex_;
    void a() {
        std::lock_guard<std::mutex> lock(mutex_);
        a_impl();  // 内部方法不加锁
    }
    void b() {
        std::lock_guard<std::mutex> lock(mutex_);
        b_impl();
    }
private:
    void a_impl() {
        // ...
        b_impl();  // 调用不加锁版本
    }
    void b_impl() {
        // ...
    }
};

// 6. 定时锁
std::timed_mutex tmtx;

void try_lock_example() {
    // 尝试锁定，立即返回
    if (tmtx.try_lock()) {
        // 获得锁
        tmtx.unlock();
    }

    // 尝试锁定，最多等待100ms
    if (tmtx.try_lock_for(std::chrono::milliseconds(100))) {
        // 获得锁
        tmtx.unlock();
    }

    // 尝试锁定，直到某个时间点
    auto deadline = std::chrono::steady_clock::now() +
                    std::chrono::seconds(1);
    if (tmtx.try_lock_until(deadline)) {
        // 获得锁
        tmtx.unlock();
    }
}

// ============ std::once_flag与call_once ============
std::once_flag init_flag;
std::shared_ptr<Resource> resource;

void init_resource() {
    resource = std::make_shared<Resource>();
}

Resource& get_resource() {
    std::call_once(init_flag, init_resource);
    return *resource;
}

// 比double-checked locking更安全，更简单
```

**Day 4 练习任务**：
```cpp
// 练习1：实现一个线程安全的单例
template <typename T>
class Singleton {
public:
    template <typename... Args>
    static T& instance(Args&&... args);
    // 使用call_once实现
};

// 练习2：比较mutex、shared_mutex、atomic在不同读写比例下的性能
```

---

#### Day 5: 综合项目——并发HashMap（7小时）

**上午（3小时）：设计并发HashMap**

```cpp
// ============ 分桶锁策略 ============
template <typename K, typename V, typename Hash = std::hash<K>>
class ConcurrentHashMap {
    static constexpr size_t NUM_BUCKETS = 16;

    struct Node {
        K key;
        V value;
        std::unique_ptr<Node> next;

        Node(K k, V v) : key(std::move(k)), value(std::move(v)) {}
    };

    struct Bucket {
        mutable std::shared_mutex mutex;
        std::unique_ptr<Node> head;

        // 查找
        Node* find(const K& key) const {
            for (Node* curr = head.get(); curr; curr = curr->next.get()) {
                if (curr->key == key) return curr;
            }
            return nullptr;
        }
    };

    std::array<Bucket, NUM_BUCKETS> buckets_;
    Hash hasher_;

    size_t bucket_index(const K& key) const {
        return hasher_(key) % NUM_BUCKETS;
    }

public:
    void put(const K& key, V value) {
        auto& bucket = buckets_[bucket_index(key)];
        std::unique_lock<std::shared_mutex> lock(bucket.mutex);

        if (Node* node = bucket.find(key)) {
            node->value = std::move(value);
            return;
        }

        auto new_node = std::make_unique<Node>(key, std::move(value));
        new_node->next = std::move(bucket.head);
        bucket.head = std::move(new_node);
    }

    std::optional<V> get(const K& key) const {
        auto& bucket = buckets_[bucket_index(key)];
        std::shared_lock<std::shared_mutex> lock(bucket.mutex);

        if (Node* node = bucket.find(key)) {
            return node->value;
        }
        return std::nullopt;
    }

    bool remove(const K& key) {
        auto& bucket = buckets_[bucket_index(key)];
        std::unique_lock<std::shared_mutex> lock(bucket.mutex);

        Node** curr = &bucket.head;
        while (*curr) {
            if ((*curr)->key == key) {
                *curr = std::move((*curr)->next);
                return true;
            }
            curr = &((*curr)->next);
        }
        return false;
    }

    bool contains(const K& key) const {
        return get(key).has_value();
    }
};
```

**下午（4小时）：测试与性能分析**

```cpp
// ============ 并发测试 ============
void test_concurrent_hashmap() {
    ConcurrentHashMap<int, std::string> map;
    std::vector<std::thread> threads;

    // 并发写入
    for (int i = 0; i < 10; ++i) {
        threads.emplace_back([&map, i]() {
            for (int j = 0; j < 1000; ++j) {
                map.put(i * 1000 + j, std::to_string(i * 1000 + j));
            }
        });
    }

    for (auto& t : threads) t.join();
    threads.clear();

    // 并发读取
    std::atomic<int> found{0};
    for (int i = 0; i < 10; ++i) {
        threads.emplace_back([&map, &found, i]() {
            for (int j = 0; j < 1000; ++j) {
                if (map.get(i * 1000 + j)) {
                    ++found;
                }
            }
        });
    }

    for (auto& t : threads) t.join();
    std::cout << "Found: " << found << " / 10000\n";
}

// ============ 性能基准测试 ============
void benchmark_hashmap() {
    ConcurrentHashMap<int, int> concurrent_map;
    std::map<int, int> std_map;
    std::mutex std_map_mutex;

    auto benchmark = [](auto& map, auto lock_fn, const char* name) {
        auto start = std::chrono::high_resolution_clock::now();
        std::vector<std::thread> threads;

        for (int i = 0; i < 4; ++i) {
            threads.emplace_back([&, i]() {
                for (int j = 0; j < 100000; ++j) {
                    lock_fn([&]() {
                        map[i * 100000 + j] = j;
                    });
                }
            });
        }

        for (auto& t : threads) t.join();

        auto end = std::chrono::high_resolution_clock::now();
        auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
            end - start).count();
        std::cout << name << ": " << ms << " ms\n";
    };

    // 测试...
}
```

#### 调试技巧和常见错误分析（第三周）

| 错误类型 | 症状 | 检测方法 | 修复建议 |
|---------|------|---------|---------|
| 忘记解锁 | 程序挂起 | 代码审查 | 使用RAII锁管理器 |
| 死锁 | 程序挂起 | Helgrind | 锁排序/scoped_lock |
| 锁粒度过粗 | 性能差 | 性能分析 | 细粒度锁/读写锁 |
| 锁粒度过细 | 复杂度高 | 代码复杂度 | 合理权衡 |
| 递归锁定普通mutex | 死锁 | 运行时检测 | 重构代码结构 |
| 锁顺序不一致 | 随机死锁 | Helgrind | 固定锁顺序 |

#### 面试常见问题（第三周）

1. **Q: mutex和recursive_mutex的区别？**
   - A: mutex不允许同一线程重复锁定，recursive_mutex允许。recursive_mutex通常是设计问题的信号。

2. **Q: lock_guard和unique_lock的区别？**
   - A: lock_guard轻量但只能整个作用域持有锁；unique_lock支持延迟锁定、提前解锁、移动、配合条件变量。

3. **Q: 如何避免死锁？**
   - A: 锁排序、std::lock/scoped_lock同时获取、try_lock超时、减少锁范围、层次锁。

4. **Q: 什么是读写锁？适用场景？**
   - A: shared_mutex允许多读单写。适用于读多写少场景如缓存、配置。注意写者饥饿问题。

5. **Q: call_once的作用？**
   - A: 保证函数只执行一次，线程安全的懒初始化。比double-checked locking更安全简洁。

#### 第三周检验清单

- [ ] 能选择合适的锁类型
- [ ] 能正确使用lock_guard、unique_lock、scoped_lock
- [ ] 能识别和预防死锁
- [ ] 理解锁粒度权衡
- [ ] 实现ConcurrentHashMap
- [ ] 笔记：`notes/week03_mutex.md`

---

### 第四周：条件变量

**学习目标**：掌握线程间的等待/通知机制

#### 详细学习目标（可衡量）

| 目标编号 | 学习目标 | 验收标准 |
|---------|---------|---------|
| W4-G1 | 理解条件变量工作原理 | 能解释wait/notify的内部机制 |
| W4-G2 | 掌握正确使用模式 | 能避免虚假唤醒和丢失唤醒 |
| W4-G3 | 实现经典同步模式 | 能实现生产者-消费者、屏障等 |
| W4-G4 | 理解超时等待 | 能实现带超时的同步操作 |
| W4-G5 | 实现完整线程池 | 能实现带future返回值的线程池 |

---

#### Day 1: 条件变量基础（7小时）

**上午（3小时）：核心概念**

```cpp
#include <condition_variable>
#include <queue>

// ============ 条件变量的作用 ============
// 让线程等待某个条件成立，而不是忙等待（busy-waiting）

std::mutex mtx;
std::condition_variable cv;
std::queue<int> data_queue;
bool finished = false;

// 生产者
void producer() {
    for (int i = 0; i < 10; ++i) {
        {
            std::lock_guard<std::mutex> lock(mtx);
            data_queue.push(i);
        }
        cv.notify_one();  // 通知一个等待的线程
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }

    {
        std::lock_guard<std::mutex> lock(mtx);
        finished = true;
    }
    cv.notify_all();  // 通知所有等待的线程
}
```

##### wait的工作原理
```cpp
// cv.wait(lock, predicate) 内部等价于：
// while (!predicate()) {
//     cv.wait(lock);
// }

// cv.wait(lock) 的三个步骤（原子执行）：
// 1. 释放锁
// 2. 阻塞等待通知
// 3. 被唤醒后重新获取锁

// 这就是为什么必须用unique_lock而不是lock_guard
// lock_guard不支持unlock/lock操作
```

**下午（4小时）：虚假唤醒与丢失唤醒**

##### 虚假唤醒（Spurious Wakeup）
```cpp
// 线程可能在没有notify的情况下被唤醒！
// 这是底层实现（如pthread）的特性

void vulnerable_consumer() {
    std::unique_lock<std::mutex> lock(mtx);
    cv.wait(lock);  // 危险！
    // 此时data_queue可能仍为空
    int data = data_queue.front();  // 可能崩溃！
}

void safe_consumer() {
    std::unique_lock<std::mutex> lock(mtx);
    // 使用谓词版本，内部循环检查条件
    cv.wait(lock, []{ return !data_queue.empty(); });
    // 条件一定满足
    int data = data_queue.front();
}
```

##### 丢失唤醒（Lost Wakeup）
```cpp
// 如果notify发生在wait之前，信号会丢失

// 错误的时序：
// 1. 消费者检查条件（队列为空）
// 2. 生产者获取锁，放入数据，notify
// 3. 消费者进入wait（notify已丢失，永久阻塞）

// 解决：检查条件和wait必须是原子的（持有锁时进行）

void correct_consumer() {
    std::unique_lock<std::mutex> lock(mtx);  // 先获取锁
    cv.wait(lock, []{ return !data_queue.empty(); });  // 原子检查+等待
}
```

**Day 1 练习任务**：
```cpp
// 练习1：实现一个信号量
class Semaphore {
    std::mutex mutex_;
    std::condition_variable cv_;
    int count_;
public:
    explicit Semaphore(int initial = 0);
    void acquire();  // P操作
    void release();  // V操作
    bool try_acquire();
};

// 练习2：实现一个一次性事件（类似std::latch）
class Event {
public:
    void signal();  // 触发事件
    void wait();    // 等待事件
    bool is_set() const;
};
```

---

#### Day 2: 生产者-消费者模式（7小时）

**上午（3小时）：有界缓冲区**

```cpp
// ============ 有界缓冲区（Bounded Buffer）============
template <typename T>
class BoundedQueue {
    std::mutex mutex_;
    std::condition_variable not_full_;
    std::condition_variable not_empty_;
    std::queue<T> queue_;
    size_t capacity_;
    bool closed_ = false;

public:
    explicit BoundedQueue(size_t capacity) : capacity_(capacity) {}

    // 阻塞入队
    bool push(T value) {
        std::unique_lock<std::mutex> lock(mutex_);
        not_full_.wait(lock, [this] {
            return queue_.size() < capacity_ || closed_;
        });

        if (closed_) return false;

        queue_.push(std::move(value));
        not_empty_.notify_one();
        return true;
    }

    // 阻塞出队
    std::optional<T> pop() {
        std::unique_lock<std::mutex> lock(mutex_);
        not_empty_.wait(lock, [this] {
            return !queue_.empty() || closed_;
        });

        if (queue_.empty()) return std::nullopt;

        T value = std::move(queue_.front());
        queue_.pop();
        not_full_.notify_one();
        return value;
    }

    void close() {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            closed_ = true;
        }
        not_full_.notify_all();
        not_empty_.notify_all();
    }
};
```

**下午（4小时）：其他同步模式**

##### 屏障（Barrier）
```cpp
// C++20之前的手动实现
class Barrier {
    std::mutex mutex_;
    std::condition_variable cv_;
    size_t const count_;
    size_t waiting_ = 0;
    size_t generation_ = 0;

public:
    explicit Barrier(size_t count) : count_(count) {}

    void wait() {
        std::unique_lock<std::mutex> lock(mutex_);
        size_t gen = generation_;
        if (++waiting_ == count_) {
            ++generation_;
            waiting_ = 0;
            cv_.notify_all();
        } else {
            cv_.wait(lock, [this, gen] { return gen != generation_; });
        }
    }
};

// C++20: std::barrier
#include <barrier>

void use_cpp20_barrier() {
    std::barrier sync_point(3, []() noexcept {
        std::cout << "All threads reached barrier\n";
    });

    auto worker = [&](int id) {
        std::cout << "Thread " << id << " before barrier\n";
        sync_point.arrive_and_wait();
        std::cout << "Thread " << id << " after barrier\n";
    };

    std::thread t1(worker, 1);
    std::thread t2(worker, 2);
    std::thread t3(worker, 3);
    t1.join(); t2.join(); t3.join();
}
```

**Day 2 练习任务**：
```cpp
// 练习1：实现一个CountDownLatch
class CountDownLatch {
public:
    explicit CountDownLatch(size_t count);
    void count_down();
    void wait();
};

// 练习2：用BoundedQueue实现多生产者多消费者
```

---

#### Day 3: 超时等待与高级用法（7小时）

**上午（3小时）：超时机制**

```cpp
// ============ wait_for: 相对时间超时 ============
template <typename T>
class TimeoutQueue {
    std::mutex mutex_;
    std::condition_variable cv_;
    std::queue<T> queue_;

public:
    void push(T value) {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            queue_.push(std::move(value));
        }
        cv_.notify_one();
    }

    // 带超时的pop
    template <typename Rep, typename Period>
    std::optional<T> pop_for(std::chrono::duration<Rep, Period> timeout) {
        std::unique_lock<std::mutex> lock(mutex_);

        // wait_for返回bool：true=条件满足，false=超时
        if (!cv_.wait_for(lock, timeout, [this]{ return !queue_.empty(); })) {
            return std::nullopt;  // 超时
        }

        T value = std::move(queue_.front());
        queue_.pop();
        return value;
    }
};

// ============ wait_until: 绝对时间超时 ============
void wait_until_example() {
    auto deadline = std::chrono::steady_clock::now() +
                    std::chrono::seconds(5);

    std::unique_lock<std::mutex> lock(mtx);

    if (cv.wait_until(lock, deadline, []{ return ready; })) {
        // 条件满足
    } else {
        // 超时
    }
}

// ============ 不带谓词的超时 ============
void timeout_without_predicate() {
    std::unique_lock<std::mutex> lock(mtx);

    // 返回cv_status枚举
    auto status = cv.wait_for(lock, std::chrono::milliseconds(100));

    if (status == std::cv_status::timeout) {
        // 超时（但可能是虚假唤醒后超时）
    } else {
        // 被通知（或虚假唤醒）
        // 仍需检查条件！
    }
}
```

**下午（4小时）：condition_variable_any**

```cpp
// ============ condition_variable_any ============
// 可以与任何BasicLockable类型配合使用

#include <shared_mutex>

std::shared_mutex rw_mutex;
std::condition_variable_any cv_any;
bool data_ready = false;

// 可以与shared_lock配合
void reader_with_cv() {
    std::shared_lock<std::shared_mutex> lock(rw_mutex);
    cv_any.wait(lock, []{ return data_ready; });
    // 读取数据...
}

// ============ cv vs cv_any 性能对比 ============
// condition_variable:
// - 只能与std::mutex + unique_lock配合
// - 更高效（专门优化）
// - 推荐首选

// condition_variable_any:
// - 可与任意锁类型配合
// - 额外开销（内部需要适配）
// - 需要时才使用
```

**Day 3 练习任务**：
```cpp
// 练习1：实现带超时的任务执行器
class TimeoutExecutor {
public:
    template <typename F>
    std::optional<std::invoke_result_t<F>>
    execute_for(F&& f, std::chrono::milliseconds timeout);
};

// 练习2：实现一个可取消的任务
class CancellableTask {
public:
    void run(std::function<void()> task);
    void cancel();
    bool wait_for_completion(std::chrono::milliseconds timeout);
};
```

---

#### Day 4: 常见陷阱与调试技巧（7小时）

**上午（3小时）：条件变量陷阱**

#### 条件变量的常见陷阱
```cpp
// 陷阱1: 忘记在修改共享状态后通知
void bad_producer() {
    std::lock_guard<std::mutex> lock(mtx);
    data_queue.push(42);
    // 忘记 cv.notify_one()!
    // 消费者可能永远等待
}

// 陷阱2: 在锁外通知（不是错误，但可能影响性能）
void questionable_producer() {
    {
        std::lock_guard<std::mutex> lock(mtx);
        data_queue.push(42);
    }
    cv.notify_one();  // 可以工作，但消费者可能立即被唤醒又阻塞
}

// 陷阱3: 没有使用谓词，可能遭遇虚假唤醒
void vulnerable_consumer() {
    std::unique_lock<std::mutex> lock(mtx);
    cv.wait(lock);  // 危险！可能虚假唤醒
    // data_queue.front();  // 可能队列为空
}

// 陷阱4: 使用notify_one时消费者数量不匹配
// 如果有多个消费者，notify_one可能唤醒"错误"的那个

// 陷阱5: 在锁外检查条件
void bad_check() {
    if (data_queue.empty()) {  // 无锁检查！
        std::unique_lock<std::mutex> lock(mtx);
        cv.wait(lock);  // 条件可能在检查后、加锁前改变
    }
}
```

**下午（4小时）：调试技巧**

```cpp
// ============ 调试条件变量问题 ============

// 1. 添加日志
class DebugConditionVariable {
    std::condition_variable cv_;
    std::string name_;

public:
    explicit DebugConditionVariable(std::string name)
        : name_(std::move(name)) {}

    template <typename Lock, typename Pred>
    void wait(Lock& lock, Pred pred) {
        std::cerr << "[" << std::this_thread::get_id() << "] "
                  << "Waiting on " << name_ << "\n";

        cv_.wait(lock, [&]() {
            bool result = pred();
            std::cerr << "[" << std::this_thread::get_id() << "] "
                      << "Predicate check: " << result << "\n";
            return result;
        });

        std::cerr << "[" << std::this_thread::get_id() << "] "
                  << "Wait complete on " << name_ << "\n";
    }

    void notify_one() {
        std::cerr << "[" << std::this_thread::get_id() << "] "
                  << "notify_one on " << name_ << "\n";
        cv_.notify_one();
    }

    void notify_all() {
        std::cerr << "[" << std::this_thread::get_id() << "] "
                  << "notify_all on " << name_ << "\n";
        cv_.notify_all();
    }
};

// 2. 超时检测卡住的等待
void detect_stuck_wait() {
    std::unique_lock<std::mutex> lock(mtx);

    auto start = std::chrono::steady_clock::now();
    while (!cv.wait_for(lock, std::chrono::seconds(5),
                        []{ return condition; })) {
        auto elapsed = std::chrono::steady_clock::now() - start;
        std::cerr << "Warning: waiting for "
                  << std::chrono::duration_cast<std::chrono::seconds>(
                         elapsed).count()
                  << " seconds\n";

        if (elapsed > std::chrono::minutes(1)) {
            throw std::runtime_error("Wait timeout - possible deadlock");
        }
    }
}
```

**Day 4 练习任务**：
```cpp
// 练习：找出并修复以下代码的所有问题
class BuggyWorkerPool {
    std::mutex mtx_;
    std::condition_variable cv_;
    std::queue<std::function<void()>> tasks_;
    std::vector<std::thread> workers_;
    bool stop_ = false;

public:
    BuggyWorkerPool(size_t n) {
        for (size_t i = 0; i < n; ++i) {
            workers_.emplace_back([this] {
                while (true) {
                    std::unique_lock<std::mutex> lock(mtx_);
                    cv_.wait(lock);  // 问题1: 无谓词

                    if (stop_) return;  // 问题2: 应该检查任务是否为空

                    auto task = tasks_.front();  // 问题3: 可能队列为空
                    tasks_.pop();
                    lock.unlock();

                    task();
                }
            });
        }
    }

    void submit(std::function<void()> task) {
        tasks_.push(task);  // 问题4: 无锁访问
        cv_.notify_one();
    }

    ~BuggyWorkerPool() {
        stop_ = true;  // 问题5: 无锁修改
        cv_.notify_all();
        for (auto& w : workers_) {
            w.join();
        }
    }
};
```

---

#### Day 5: 综合项目——完整线程池（7小时）

**上午（3小时）：线程池设计**

```cpp
// ============ 完整的线程池实现 ============
class ThreadPool {
    std::vector<std::thread> workers_;
    std::queue<std::function<void()>> tasks_;

    mutable std::mutex mutex_;
    std::condition_variable cv_;
    std::condition_variable all_done_cv_;

    bool stop_ = false;
    size_t active_count_ = 0;

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
                ++active_count_;
            }

            task();

            {
                std::lock_guard<std::mutex> lock(mutex_);
                --active_count_;
                if (tasks_.empty() && active_count_ == 0) {
                    all_done_cv_.notify_all();
                }
            }
        }
    }

public:
    explicit ThreadPool(size_t num_threads =
                        std::thread::hardware_concurrency()) {
        for (size_t i = 0; i < num_threads; ++i) {
            workers_.emplace_back(&ThreadPool::worker_loop, this);
        }
    }

    ~ThreadPool() {
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

    // 禁止拷贝
    ThreadPool(const ThreadPool&) = delete;
    ThreadPool& operator=(const ThreadPool&) = delete;

    // 提交任务，返回future
    template <typename F, typename... Args>
    auto submit(F&& f, Args&&... args)
        -> std::future<std::invoke_result_t<F, Args...>>
    {
        using return_type = std::invoke_result_t<F, Args...>;

        auto task = std::make_shared<std::packaged_task<return_type()>>(
            std::bind(std::forward<F>(f), std::forward<Args>(args)...)
        );

        std::future<return_type> result = task->get_future();

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

    // 等待所有任务完成
    void wait_all() {
        std::unique_lock<std::mutex> lock(mutex_);
        all_done_cv_.wait(lock, [this] {
            return tasks_.empty() && active_count_ == 0;
        });
    }

    // 查询
    size_t pending_tasks() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return tasks_.size();
    }

    size_t active_workers() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return active_count_;
    }
};
```

**下午（4小时）：测试与使用示例**

```cpp
// ============ 使用示例 ============
void thread_pool_demo() {
    ThreadPool pool(4);

    // 提交带返回值的任务
    auto future1 = pool.submit([](int x) { return x * 2; }, 21);
    auto future2 = pool.submit([]() { return std::string("hello"); });

    std::cout << future1.get() << "\n";  // 42
    std::cout << future2.get() << "\n";  // hello

    // 批量提交
    std::vector<std::future<int>> futures;
    for (int i = 0; i < 100; ++i) {
        futures.push_back(pool.submit([i]() {
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
            return i * i;
        }));
    }

    // 收集结果
    int sum = 0;
    for (auto& f : futures) {
        sum += f.get();
    }
    std::cout << "Sum of squares: " << sum << "\n";

    // 等待所有任务完成
    pool.wait_all();
    std::cout << "All tasks completed\n";
}
```

#### 调试技巧和常见错误分析（第四周）

| 错误类型 | 症状 | 检测方法 | 修复建议 |
|---------|------|---------|---------|
| 虚假唤醒未处理 | 数据错误/崩溃 | 代码审查 | 使用谓词版wait |
| 丢失唤醒 | 线程永久阻塞 | 日志/超时 | 持锁时检查+wait |
| notify_one不当 | 部分线程卡住 | 测试 | 使用notify_all |
| 临界区过长 | 性能差 | 性能分析 | 最小化锁范围 |
| 条件判断错误 | 逻辑错误 | 单元测试 | 仔细检查谓词 |
| 错误的锁类型 | 编译错误/死锁 | 编译器 | 使用unique_lock |

#### 面试常见问题（第四周）

1. **Q: 什么是虚假唤醒？如何处理？**
   - A: 线程可能在无notify的情况下被唤醒。使用wait的谓词版本，内部循环检查条件。

2. **Q: notify_one和notify_all的区别？**
   - A: notify_one唤醒一个等待者，notify_all唤醒所有。单一条件用one，多种条件或广播用all。

3. **Q: 为什么wait需要unique_lock而不是lock_guard？**
   - A: wait内部需要释放锁再阻塞，被唤醒后重新获取锁。lock_guard不支持unlock/lock操作。

4. **Q: condition_variable和condition_variable_any的区别？**
   - A: 前者只能与mutex配合，更高效；后者可与任意锁配合，更灵活但可能更慢。

5. **Q: 如何实现线程池的优雅关闭？**
   - A: 设置stop标志，notify_all唤醒所有工作线程，等待现有任务完成后join所有线程。

#### 第四周检验清单

- [ ] 理解条件变量的工作原理
- [ ] 能正确处理虚假唤醒和丢失唤醒
- [ ] 实现BoundedQueue
- [ ] 实现完整的ThreadPool
- [ ] 能调试条件变量相关问题
- [ ] 笔记：`notes/week04_condition_variable.md`

---

## 源码阅读任务

### 深度阅读清单

- [ ] `std::thread`构造函数实现
- [ ] `std::mutex`的平台实现（pthread_mutex / CRITICAL_SECTION）
- [ ] `std::lock_guard`和`std::unique_lock`
- [ ] `std::condition_variable::wait`实现

---

## 实践项目

### 项目：线程安全的数据结构

#### Part 1: 线程安全的队列
```cpp
// thread_safe_queue.hpp
#pragma once
#include <mutex>
#include <condition_variable>
#include <queue>
#include <optional>
#include <chrono>

template <typename T>
class ThreadSafeQueue {
    mutable std::mutex mtx_;
    std::condition_variable cv_;
    std::queue<T> queue_;
    bool closed_ = false;

public:
    ThreadSafeQueue() = default;

    // 禁止拷贝
    ThreadSafeQueue(const ThreadSafeQueue&) = delete;
    ThreadSafeQueue& operator=(const ThreadSafeQueue&) = delete;

    // 入队
    void push(T value) {
        {
            std::lock_guard<std::mutex> lock(mtx_);
            if (closed_) {
                throw std::runtime_error("Queue is closed");
            }
            queue_.push(std::move(value));
        }
        cv_.notify_one();
    }

    // 尝试入队（队列关闭时返回false）
    bool try_push(T value) {
        {
            std::lock_guard<std::mutex> lock(mtx_);
            if (closed_) {
                return false;
            }
            queue_.push(std::move(value));
        }
        cv_.notify_one();
        return true;
    }

    // 阻塞出队
    std::optional<T> pop() {
        std::unique_lock<std::mutex> lock(mtx_);
        cv_.wait(lock, [this] { return !queue_.empty() || closed_; });

        if (queue_.empty()) {
            return std::nullopt;  // 队列关闭且为空
        }

        T value = std::move(queue_.front());
        queue_.pop();
        return value;
    }

    // 非阻塞出队
    std::optional<T> try_pop() {
        std::lock_guard<std::mutex> lock(mtx_);
        if (queue_.empty()) {
            return std::nullopt;
        }
        T value = std::move(queue_.front());
        queue_.pop();
        return value;
    }

    // 带超时的出队
    template <typename Rep, typename Period>
    std::optional<T> pop_for(std::chrono::duration<Rep, Period> timeout) {
        std::unique_lock<std::mutex> lock(mtx_);
        if (!cv_.wait_for(lock, timeout,
                          [this] { return !queue_.empty() || closed_; })) {
            return std::nullopt;  // 超时
        }

        if (queue_.empty()) {
            return std::nullopt;  // 关闭
        }

        T value = std::move(queue_.front());
        queue_.pop();
        return value;
    }

    // 关闭队列（不再接受新元素）
    void close() {
        {
            std::lock_guard<std::mutex> lock(mtx_);
            closed_ = true;
        }
        cv_.notify_all();
    }

    // 查询
    bool empty() const {
        std::lock_guard<std::mutex> lock(mtx_);
        return queue_.empty();
    }

    size_t size() const {
        std::lock_guard<std::mutex> lock(mtx_);
        return queue_.size();
    }

    bool is_closed() const {
        std::lock_guard<std::mutex> lock(mtx_);
        return closed_;
    }
};
```

#### Part 2: 线程安全的栈
```cpp
// thread_safe_stack.hpp
#pragma once
#include <mutex>
#include <stack>
#include <optional>
#include <memory>
#include <stdexcept>

template <typename T>
class ThreadSafeStack {
    mutable std::mutex mtx_;
    std::stack<T> stack_;

public:
    ThreadSafeStack() = default;

    ThreadSafeStack(const ThreadSafeStack& other) {
        std::lock_guard<std::mutex> lock(other.mtx_);
        stack_ = other.stack_;
    }

    ThreadSafeStack& operator=(const ThreadSafeStack&) = delete;

    void push(T value) {
        std::lock_guard<std::mutex> lock(mtx_);
        stack_.push(std::move(value));
    }

    // 方案1: 返回shared_ptr（避免pop时拷贝构造抛异常的问题）
    std::shared_ptr<T> pop() {
        std::lock_guard<std::mutex> lock(mtx_);
        if (stack_.empty()) {
            throw std::runtime_error("Stack is empty");
        }
        auto result = std::make_shared<T>(std::move(stack_.top()));
        stack_.pop();
        return result;
    }

    // 方案2: 通过引用参数返回
    bool pop(T& value) {
        std::lock_guard<std::mutex> lock(mtx_);
        if (stack_.empty()) {
            return false;
        }
        value = std::move(stack_.top());
        stack_.pop();
        return true;
    }

    // 方案3: 返回optional
    std::optional<T> try_pop() {
        std::lock_guard<std::mutex> lock(mtx_);
        if (stack_.empty()) {
            return std::nullopt;
        }
        T value = std::move(stack_.top());
        stack_.pop();
        return value;
    }

    bool empty() const {
        std::lock_guard<std::mutex> lock(mtx_);
        return stack_.empty();
    }

    size_t size() const {
        std::lock_guard<std::mutex> lock(mtx_);
        return stack_.size();
    }
};
```

#### Part 3: 简单的线程池
```cpp
// thread_pool.hpp
#pragma once
#include "thread_safe_queue.hpp"
#include <thread>
#include <vector>
#include <functional>
#include <future>
#include <atomic>

class ThreadPool {
    std::vector<std::thread> workers_;
    ThreadSafeQueue<std::function<void()>> tasks_;
    std::atomic<bool> stop_{false};

    void worker_thread() {
        while (true) {
            auto task = tasks_.pop();
            if (!task) {
                break;  // 队列关闭
            }
            (*task)();
        }
    }

public:
    explicit ThreadPool(size_t num_threads = std::thread::hardware_concurrency()) {
        for (size_t i = 0; i < num_threads; ++i) {
            workers_.emplace_back([this] { worker_thread(); });
        }
    }

    ~ThreadPool() {
        tasks_.close();
        for (auto& worker : workers_) {
            if (worker.joinable()) {
                worker.join();
            }
        }
    }

    // 禁止拷贝和移动
    ThreadPool(const ThreadPool&) = delete;
    ThreadPool& operator=(const ThreadPool&) = delete;

    // 提交任务
    template <typename F, typename... Args>
    auto submit(F&& f, Args&&... args)
        -> std::future<std::invoke_result_t<F, Args...>> {

        using return_type = std::invoke_result_t<F, Args...>;

        auto task = std::make_shared<std::packaged_task<return_type()>>(
            std::bind(std::forward<F>(f), std::forward<Args>(args)...)
        );

        std::future<return_type> result = task->get_future();

        tasks_.push([task]() { (*task)(); });

        return result;
    }

    // 等待所有任务完成
    void wait_all() {
        tasks_.close();
        for (auto& worker : workers_) {
            if (worker.joinable()) {
                worker.join();
            }
        }
    }

    size_t size() const {
        return workers_.size();
    }
};
```

#### Part 4: 并发计数器对比
```cpp
// counter_benchmark.cpp
#include <thread>
#include <vector>
#include <mutex>
#include <atomic>
#include <chrono>
#include <iostream>

// 方案1: 无保护（错误！）
int unsafe_counter = 0;

void unsafe_increment(int n) {
    for (int i = 0; i < n; ++i) {
        ++unsafe_counter;
    }
}

// 方案2: 互斥锁
std::mutex counter_mutex;
int mutex_counter = 0;

void mutex_increment(int n) {
    for (int i = 0; i < n; ++i) {
        std::lock_guard<std::mutex> lock(counter_mutex);
        ++mutex_counter;
    }
}

// 方案3: 原子变量
std::atomic<int> atomic_counter{0};

void atomic_increment(int n) {
    for (int i = 0; i < n; ++i) {
        ++atomic_counter;
    }
}

// 方案4: 本地累加后合并
std::atomic<int> local_atomic_counter{0};

void local_increment(int n) {
    int local = 0;
    for (int i = 0; i < n; ++i) {
        ++local;
    }
    local_atomic_counter += local;
}

template <typename Func>
void benchmark(const char* name, Func f, int threads, int iterations) {
    auto start = std::chrono::high_resolution_clock::now();

    std::vector<std::thread> workers;
    for (int i = 0; i < threads; ++i) {
        workers.emplace_back(f, iterations);
    }
    for (auto& w : workers) {
        w.join();
    }

    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

    std::cout << name << ": " << duration.count() << " ms\n";
}

int main() {
    const int threads = 4;
    const int iterations = 1000000;

    benchmark("Unsafe", unsafe_increment, threads, iterations);
    std::cout << "  Result: " << unsafe_counter
              << " (expected: " << threads * iterations << ")\n";

    benchmark("Mutex", mutex_increment, threads, iterations);
    std::cout << "  Result: " << mutex_counter << "\n";

    benchmark("Atomic", atomic_increment, threads, iterations);
    std::cout << "  Result: " << atomic_counter.load() << "\n";

    benchmark("Local", local_increment, threads, iterations);
    std::cout << "  Result: " << local_atomic_counter.load() << "\n";

    return 0;
}
```

---

## 检验标准

### 知识检验
- [ ] 并发与并行的区别是什么？
- [ ] 什么是数据竞争？为什么是未定义行为？
- [ ] std::thread的join和detach有什么区别？
- [ ] 为什么不应该直接使用mutex.lock()/unlock()？
- [ ] 条件变量为什么需要配合谓词使用？

### 实践检验
- [ ] ThreadSafeQueue支持多生产者多消费者
- [ ] ThreadSafeStack的三种pop方式都能正确工作
- [ ] ThreadPool能正确执行任务并返回结果
- [ ] 理解不同计数器实现的性能差异

### 输出物
1. `thread_safe_queue.hpp`
2. `thread_safe_stack.hpp`
3. `thread_pool.hpp`
4. `counter_benchmark.cpp`
5. `notes/month13_concurrency_basics.md`

---

## 时间分配（140小时/月）

| 内容 | 时间 | 占比 |
|------|------|------|
| 理论学习 | 35小时 | 25% |
| 源码阅读 | 25小时 | 18% |
| ThreadSafeQueue实现 | 25小时 | 18% |
| ThreadPool实现 | 30小时 | 21% |
| 基准测试与文档 | 25小时 | 18% |

---

---

## 总结与现代C++扩展

### 四周学习输出物总览

| 周次 | 主要输出物 | 描述 |
|------|-----------|------|
| Week 1 | `BoundedBuffer` | 生产者-消费者有界缓冲区 |
| Week 2 | `ScopedThread`, `SimpleThreadPool` | RAII线程管理与简单线程池 |
| Week 3 | `ConcurrentHashMap` | 分桶锁线程安全哈希表 |
| Week 4 | `ThreadPool` | 完整线程池（支持future返回值） |
| 全月 | `notes/month13_concurrency.md` | 综合学习笔记 |

### C++20/23 并发新特性预览

```cpp
// ============ C++20 新增同步原语 ============

// 1. std::jthread - 自动join的线程
#include <thread>
#include <stop_token>

void jthread_demo() {
    std::jthread worker([](std::stop_token token) {
        while (!token.stop_requested()) {
            // 工作...
        }
    });
    // 析构时自动request_stop()并join()
}

// 2. std::latch - 一次性倒计时门闩
#include <latch>

void latch_demo() {
    std::latch done(3);  // 计数器初始为3

    auto work = [&]() {
        // 工作...
        done.count_down();  // 减1
    };

    std::thread t1(work), t2(work), t3(work);
    done.wait();  // 等待计数器变为0
    t1.join(); t2.join(); t3.join();
}

// 3. std::barrier - 可重用屏障
#include <barrier>

void barrier_demo() {
    auto on_completion = []() noexcept {
        std::cout << "Phase complete\n";
    };

    std::barrier sync_point(3, on_completion);

    auto work = [&]() {
        for (int i = 0; i < 3; ++i) {
            // 阶段i的工作
            sync_point.arrive_and_wait();
        }
    };

    std::thread t1(work), t2(work), t3(work);
    t1.join(); t2.join(); t3.join();
}

// 4. std::counting_semaphore - 信号量
#include <semaphore>

void semaphore_demo() {
    std::counting_semaphore<10> sem(3);  // 最大10，初始3

    sem.acquire();  // P操作，计数-1
    // 临界区，最多3个线程
    sem.release();  // V操作，计数+1

    // binary_semaphore是max=1的特化
    std::binary_semaphore bin_sem(1);
}

// 5. std::atomic的wait/notify
void atomic_wait_demo() {
    std::atomic<int> value{0};

    std::thread waiter([&]() {
        value.wait(0);  // 等待直到value != 0
        std::cout << "Value changed to " << value.load() << "\n";
    });

    std::this_thread::sleep_for(std::chrono::seconds(1));
    value.store(42);
    value.notify_one();

    waiter.join();
}

// ============ C++23 预览 ============
// std::expected - 错误处理（间接相关）
// 更多并发相关提案正在讨论中
```

### 与Month 14（内存模型）的衔接

本月学习的是**高层并发原语**，它们内部使用了C++内存模型保证正确性。下月将深入底层：

| 本月（Month 13） | 下月（Month 14） |
|-----------------|-----------------|
| mutex、condition_variable | std::atomic、memory_order |
| 高层API | 底层实现原理 |
| "如何使用" | "为什么这样工作" |
| 自动保证顺序 | 手动控制顺序 |

**预习建议**：
- 了解CPU缓存一致性协议（MESI）
- 了解指令重排序
- 阅读 Preshing on Programming 博客

### 学习路线图位置

```
Month 13: 并发基础 ──────────────────────────┐
  │ std::thread, mutex, condition_variable   │
  │                                          │
  ▼                                          │ 第二年
Month 14: 内存模型                            │ 并发
  │ std::atomic, memory_order                │ 专题
  │                                          │
  ▼                                          │
Month 15: 无锁编程 ─────────────────────────┘
    lock-free数据结构, ABA问题
```

### 推荐阅读与资源

**书籍**：
- 《C++ Concurrency in Action》 - Anthony Williams
- 《The Art of Multiprocessor Programming》 - Herlihy & Shavit

**视频**：
- CppCon: "Back to Basics: Concurrency" 系列
- CppCon: "The Nightmare of Move Semantics for Trivial Classes" (相关)

**工具**：
- ThreadSanitizer (TSan)
- Helgrind (Valgrind)
- Intel Inspector

**在线资源**：
- Preshing on Programming (preshing.com)
- cppreference.com 并发部分
- Herb Sutter's "Effective Concurrency" 系列文章

---

## 下月预告

Month 14将深入**C++内存模型**，这是理解并发编程的核心。我们将学习顺序一致性、acquire-release语义、relaxed原子操作，以及它们在不同硬件上的映射。

**预习要点**：
- 理解"happens-before"关系
- 了解std::atomic的基本用法
- 思考：为什么编译器和CPU会重排序指令？
