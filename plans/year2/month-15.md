# Month 15: 原子操作与CAS——无锁编程的基石

## 本月主题概述

原子操作是并发编程的基本构建块，而Compare-And-Swap（CAS）是实现无锁算法的核心原语。本月将深入理解各种原子操作的语义、实现和应用，为无锁数据结构的学习打下基础。

---

## 理论学习内容

### 第一周：原子操作基础

**学习目标**：掌握std::atomic的完整API，理解原子操作的硬件基础

**阅读材料**：
- [ ] 《C++ Concurrency in Action》第5章原子操作部分
- [ ] cppreference std::atomic完整文档
- [ ] Intel/ARM手册中的原子指令部分
- [ ] 扩展阅读：Intel 64 and IA-32 Architectures Software Developer's Manual Vol.3 Chapter 8

---

#### 📅 Day 1-2: std::atomic API深度学习

**学习目标**：
- [ ] 理解std::atomic的模板结构和特化版本
- [ ] 掌握所有基本操作：load、store、exchange
- [ ] 理解不同类型特化的差异

**核心概念**：

#### std::atomic的特化
```cpp
#include <atomic>

// 通用模板
template <typename T>
struct atomic;

// 整数类型特化：提供算术操作
std::atomic<int> ai;
ai.fetch_add(1);  // 原子加
ai.fetch_sub(1);  // 原子减
ai.fetch_and(mask);  // 原子与
ai.fetch_or(mask);   // 原子或
ai.fetch_xor(mask);  // 原子异或

// 指针特化：提供指针算术
std::atomic<int*> ap;
ap.fetch_add(1);  // 指针+1（即+sizeof(int)字节）
ap.fetch_sub(1);

// 布尔特化
std::atomic<bool> ab;
// 没有算术操作

// atomic_flag：最简单的原子类型
std::atomic_flag flag = ATOMIC_FLAG_INIT;
flag.test_and_set();  // 设置并返回旧值
flag.clear();         // 清除
// 保证无锁！
```

#### 🔬 深入理解：std::atomic的完整API
```cpp
#include <atomic>
#include <iostream>

// ==================== 基础操作 ====================

void basic_operations() {
    std::atomic<int> atom{42};

    // 1. load() - 原子读取
    int value = atom.load();                              // 默认seq_cst
    int value2 = atom.load(std::memory_order_acquire);    // 指定内存序
    int value3 = atom;                                    // 隐式转换，等价于load()

    // 2. store() - 原子写入
    atom.store(100);                                      // 默认seq_cst
    atom.store(200, std::memory_order_release);           // 指定内存序
    atom = 300;                                           // 赋值运算符，等价于store()

    // 3. exchange() - 原子交换，返回旧值
    int old = atom.exchange(400);                         // old = 300, atom = 400

    // 注意：load/store/exchange 都是原子的，但组合使用不是！
    // 错误示例：
    // atom.store(atom.load() + 1);  // 这不是原子操作！
}

// ==================== 算术操作（仅整数和指针类型）====================

void arithmetic_operations() {
    std::atomic<int> counter{0};

    // fetch_* 系列：执行操作并返回旧值
    int old1 = counter.fetch_add(5);    // old1=0, counter=5
    int old2 = counter.fetch_sub(2);    // old2=5, counter=3
    int old3 = counter.fetch_and(0xFF); // old3=3, counter=3&0xFF=3
    int old4 = counter.fetch_or(0x10);  // old4=3, counter=3|0x10=19
    int old5 = counter.fetch_xor(0x10); // old5=19, counter=19^0x10=3

    // 运算符重载（C++11）
    counter++;      // 返回旧值（通常被忽略）
    ++counter;      // 返回新值
    counter += 10;  // 返回新值
    counter -= 5;   // 返回新值

    // C++20 新增
    // counter.fetch_max(100);  // 原子地取较大值
    // counter.fetch_min(0);    // 原子地取较小值
}

// ==================== 指针类型特化 ====================

void pointer_operations() {
    int arr[10] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9};
    std::atomic<int*> ptr{arr};

    // 指针算术
    int* old_ptr = ptr.fetch_add(2);  // 移动2个int的距离
    // old_ptr 指向 arr[0]
    // ptr 现在指向 arr[2]

    ptr.fetch_sub(1);  // ptr 指向 arr[1]

    // 注意：指针移动是按元素大小，不是字节！
    std::cout << "ptr points to: " << *ptr << "\n";  // 输出1
}

// ==================== atomic_flag：最底层的原子类型 ====================

void atomic_flag_demo() {
    // atomic_flag 是唯一保证无锁的原子类型
    std::atomic_flag spinlock = ATOMIC_FLAG_INIT;  // 初始化为false

    // test_and_set(): 设置为true，返回旧值
    bool was_locked = spinlock.test_and_set();
    // 如果was_locked为false，说明我们获得了锁

    // clear(): 设置为false
    spinlock.clear();

    // C++20新增：test() 仅读取，不修改
    // bool current = spinlock.test();

    // 使用atomic_flag实现自旋锁
    class SpinLock {
        std::atomic_flag flag_ = ATOMIC_FLAG_INIT;
    public:
        void lock() {
            while (flag_.test_and_set(std::memory_order_acquire)) {
                // 自旋等待
                // C++20可以用flag_.wait(true)来避免忙等
            }
        }
        void unlock() {
            flag_.clear(std::memory_order_release);
        }
    };
}
```

**Day 1-2 检验标准**：
- [ ] 能够解释load/store/exchange的语义区别
- [ ] 能够正确使用fetch_*系列操作
- [ ] 理解运算符重载返回新值还是旧值
- [ ] 能够用atomic_flag实现简单自旋锁

---

#### 📅 Day 3-4: 原子性保证与硬件支持

**学习目标**：
- [ ] 理解lock-free的三个层次
- [ ] 了解不同平台的原子指令支持
- [ ] 掌握is_lock_free的使用场景

#### 原子性保证
```cpp
// 原子操作的三个层次：

// 1. 无锁（Lock-free）
// 操作直接映射到硬件原子指令
std::atomic<int> a;
static_assert(a.is_lock_free());  // 通常为true

// 2. 地址无锁（Address-free）
// 同一地址的操作是无锁的

// 3. 有锁实现
// 对于大对象或不支持的类型，可能使用内部锁
struct BigStruct { int data[100]; };
std::atomic<BigStruct> big;
// 可能不是lock-free

// 检查是否无锁
std::cout << std::atomic<int>::is_always_lock_free << "\n";  // 编译期
std::cout << a.is_lock_free() << "\n";  // 运行时
```

#### 🔬 深入理解：硬件层面的原子操作
```cpp
#include <atomic>
#include <iostream>
#include <type_traits>

// ==================== Lock-free检测 ====================

template <typename T>
void check_lock_free() {
    std::atomic<T> atom;

    // 编译期检测（C++17）
    constexpr bool always_lock_free = std::atomic<T>::is_always_lock_free;

    // 运行时检测
    bool runtime_lock_free = atom.is_lock_free();

    std::cout << "Type size: " << sizeof(T) << " bytes\n";
    std::cout << "Always lock-free: " << std::boolalpha << always_lock_free << "\n";
    std::cout << "Runtime lock-free: " << runtime_lock_free << "\n";
}

// ==================== 不同大小类型的lock-free状态 ====================

void lock_free_survey() {
    // 通常lock-free的类型
    std::cout << "=== Typically Lock-Free ===\n";
    check_lock_free<bool>();          // 1 byte
    check_lock_free<char>();          // 1 byte
    check_lock_free<short>();         // 2 bytes
    check_lock_free<int>();           // 4 bytes
    check_lock_free<long>();          // 4/8 bytes
    check_lock_free<long long>();     // 8 bytes
    check_lock_free<void*>();         // 4/8 bytes

    // 可能不是lock-free的类型
    std::cout << "\n=== May Not Be Lock-Free ===\n";
    struct Small { char data[8]; };
    struct Medium { char data[16]; };
    struct Large { char data[32]; };

    check_lock_free<Small>();   // 8 bytes - 可能lock-free
    check_lock_free<Medium>();  // 16 bytes - 可能lock-free（需要CMPXCHG16B）
    check_lock_free<Large>();   // 32 bytes - 通常不是lock-free
}

// ==================== 硬件原子指令映射 ====================

/*
x86/x64架构的原子指令：
┌─────────────────────┬────────────────────────────────────┐
│ C++操作             │ x86指令                             │
├─────────────────────┼────────────────────────────────────┤
│ load()              │ MOV (带MFENCE或使用原子MOV)         │
│ store()             │ MOV (带MFENCE或XCHG)                │
│ exchange()          │ XCHG (自带LOCK前缀)                 │
│ fetch_add()         │ LOCK XADD                           │
│ fetch_sub()         │ LOCK XADD (负数)                    │
│ fetch_and()         │ LOCK AND                            │
│ fetch_or()          │ LOCK OR                             │
│ fetch_xor()         │ LOCK XOR                            │
│ compare_exchange()  │ LOCK CMPXCHG / LOCK CMPXCHG16B      │
└─────────────────────┴────────────────────────────────────┘

ARM架构的原子指令：
┌─────────────────────┬────────────────────────────────────┐
│ C++操作             │ ARM指令                             │
├─────────────────────┼────────────────────────────────────┤
│ load()              │ LDAR (Load-Acquire)                 │
│ store()             │ STLR (Store-Release)                │
│ exchange()          │ LDAXR + STLXR 循环                  │
│ fetch_add()         │ LDADD (ARMv8.1+) 或 LL/SC循环       │
│ compare_exchange()  │ LDAXR + STLXR 或 CAS (ARMv8.1+)     │
└─────────────────────┴────────────────────────────────────┘

关键概念：
1. LOCK前缀（x86）：锁定总线或缓存行，保证原子性
2. LL/SC（ARM/POWER）：Load-Linked/Store-Conditional
   - LDAXR: 读取并设置独占监视器
   - STLXR: 只有监视器未被清除时才写入成功
*/

// ==================== 为什么有些类型不是lock-free？====================

/*
决定因素：
1. 硬件支持的最大原子宽度
   - x86-64: 最大128位（CMPXCHG16B，需要16字节对齐）
   - ARM64: 最大128位（LDAXP/STLXP）
   - 32位系统: 通常最大64位

2. 对齐要求
   - 未对齐的访问可能跨缓存行，无法原子完成
   - std::atomic会自动添加正确的对齐

3. 超过硬件支持的类型
   - 使用内部互斥锁实现
   - 多个std::atomic可能共享同一把锁（哈希到锁表）
*/

void demonstrate_alignment() {
    struct alignas(16) Aligned16 {
        long long a, b;
    };

    struct NotAligned {
        long long a, b;
    };

    std::cout << "Aligned16 lock-free: "
              << std::atomic<Aligned16>::is_always_lock_free << "\n";
    std::cout << "NotAligned lock-free: "
              << std::atomic<NotAligned>::is_always_lock_free << "\n";
}
```

**Day 3-4 检验标准**：
- [ ] 能够解释lock-free的三个层次
- [ ] 能够判断一个类型是否可能是lock-free
- [ ] 理解x86 LOCK前缀和ARM LL/SC的工作原理
- [ ] 理解对齐对原子操作的影响

---

#### 📅 Day 5-6: 原子操作的汇编层面分析

**学习目标**：
- [ ] 能够阅读原子操作生成的汇编代码
- [ ] 理解不同内存序的汇编差异
- [ ] 掌握使用Compiler Explorer分析代码

#### 🔬 汇编代码分析实战
```cpp
// 使用 https://godbolt.org/ (Compiler Explorer) 查看汇编
// 编译选项：-O2 -std=c++17

#include <atomic>

std::atomic<int> counter{0};

// ==================== 分析1：简单的fetch_add ====================
void increment_relaxed() {
    counter.fetch_add(1, std::memory_order_relaxed);
}
/*
x86-64汇编（GCC -O2）：
    lock add DWORD PTR counter[rip], 1
    ret

分析：
- lock前缀确保原子性
- 单条指令，非常高效
- relaxed不需要额外的栅栏指令
*/

void increment_seq_cst() {
    counter.fetch_add(1, std::memory_order_seq_cst);
}
/*
x86-64汇编（GCC -O2）：
    lock add DWORD PTR counter[rip], 1
    ret

注意：x86上seq_cst的fetch_add和relaxed生成相同代码！
因为x86的lock指令本身就提供了强内存序保证。
*/

// ==================== 分析2：load和store的差异 ====================
int load_relaxed() {
    return counter.load(std::memory_order_relaxed);
}
/*
x86-64汇编：
    mov eax, DWORD PTR counter[rip]
    ret

分析：普通MOV就够了，因为x86保证对齐的加载是原子的
*/

int load_seq_cst() {
    return counter.load(std::memory_order_seq_cst);
}
/*
x86-64汇编：
    mov eax, DWORD PTR counter[rip]
    ret

x86上load的所有内存序都生成相同代码！
*/

void store_relaxed(int value) {
    counter.store(value, std::memory_order_relaxed);
}
/*
x86-64汇编：
    mov DWORD PTR counter[rip], edi
    ret
*/

void store_seq_cst(int value) {
    counter.store(value, std::memory_order_seq_cst);
}
/*
x86-64汇编（GCC）：
    xchg DWORD PTR counter[rip], edi
    ret

或者（某些编译器）：
    mov DWORD PTR counter[rip], edi
    mfence
    ret

分析：seq_cst的store需要额外开销来保证全局顺序
*/

// ==================== 分析3：CAS操作 ====================
bool cas_example(int expected, int desired) {
    return counter.compare_exchange_strong(expected, desired,
            std::memory_order_seq_cst);
}
/*
x86-64汇编：
    mov eax, edi                              ; eax = expected
    lock cmpxchg DWORD PTR counter[rip], esi  ; 比较并交换
    sete al                                   ; 设置返回值
    ret

分析：
- cmpxchg: 如果[counter] == eax，则[counter] = esi
- 否则eax = [counter]（expected被更新）
- lock前缀保证原子性
*/

// ==================== 分析4：ARM64的差异 ====================
/*
ARM64上的fetch_add（使用LDADD，ARMv8.1+）：
    ldaddal w1, w0, [x0]
    ret

ARM64上的fetch_add（使用LL/SC，较老的ARM）：
.L1:
    ldaxr   w2, [x0]          ; Load-Acquire Exclusive
    add     w3, w2, w1        ; 计算新值
    stlxr   w4, w3, [x0]      ; Store-Release Exclusive
    cbnz    w4, .L1           ; 如果失败则重试
    mov     w0, w2            ; 返回旧值
    ret

分析：
- LL/SC可能虚假失败，需要循环
- 这就是compare_exchange_weak可能虚假失败的原因
*/
```

#### 实践练习：编写测试程序验证
```cpp
// atomic_asm_test.cpp
// 编译：g++ -O2 -std=c++17 -S -o atomic_asm.s atomic_asm_test.cpp
// 或使用 objdump -d 查看

#include <atomic>
#include <thread>
#include <vector>
#include <iostream>
#include <chrono>

std::atomic<long> global_counter{0};

// 测试不同内存序的性能差异
template <std::memory_order Order>
void increment_n_times(long n) {
    for (long i = 0; i < n; ++i) {
        global_counter.fetch_add(1, Order);
    }
}

void benchmark() {
    const long iterations = 10'000'000;
    const int num_threads = 4;

    auto test = [&](const char* name, auto func) {
        global_counter = 0;
        auto start = std::chrono::high_resolution_clock::now();

        std::vector<std::thread> threads;
        for (int i = 0; i < num_threads; ++i) {
            threads.emplace_back(func, iterations);
        }
        for (auto& t : threads) {
            t.join();
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count();

        std::cout << name << ": " << ms << " ms, counter = " << global_counter
                  << " (expected: " << num_threads * iterations << ")\n";
    };

    test("relaxed", increment_n_times<std::memory_order_relaxed>);
    test("acquire", increment_n_times<std::memory_order_acquire>);
    test("release", increment_n_times<std::memory_order_release>);
    test("acq_rel", increment_n_times<std::memory_order_acq_rel>);
    test("seq_cst", increment_n_times<std::memory_order_seq_cst>);
}

int main() {
    benchmark();
    return 0;
}
```

**Day 5-6 检验标准**：
- [ ] 能够使用Compiler Explorer查看原子操作的汇编
- [ ] 理解x86上不同内存序可能生成相同代码的原因
- [ ] 理解ARM LL/SC循环的结构
- [ ] 完成性能基准测试程序

---

#### 📅 Day 7: 第一周总结与综合实践

**本周知识图谱**：
```
std::atomic
├── 基础操作
│   ├── load() / store() / exchange()
│   └── 隐式转换和赋值运算符
├── 算术操作（整数/指针特化）
│   ├── fetch_add() / fetch_sub()
│   ├── fetch_and() / fetch_or() / fetch_xor()
│   └── 运算符重载 ++/--/+=/-=
├── atomic_flag
│   ├── test_and_set() / clear()
│   └── 实现自旋锁
└── Lock-free属性
    ├── is_always_lock_free（编译期）
    ├── is_lock_free()（运行时）
    └── 硬件支持分析
```

**综合练习：实现一个线程安全的ID生成器**
```cpp
// thread_safe_id_generator.hpp
#pragma once
#include <atomic>
#include <cstdint>

class ThreadSafeIdGenerator {
    std::atomic<uint64_t> next_id_{1};  // 从1开始

public:
    // 获取下一个唯一ID
    uint64_t next() {
        return next_id_.fetch_add(1, std::memory_order_relaxed);
    }

    // 获取当前值（不增加）
    uint64_t current() const {
        return next_id_.load(std::memory_order_relaxed);
    }

    // 重置（仅用于测试）
    void reset(uint64_t value = 1) {
        next_id_.store(value, std::memory_order_relaxed);
    }

    // 尝试预留一段ID（返回起始ID）
    uint64_t reserve(uint64_t count) {
        return next_id_.fetch_add(count, std::memory_order_relaxed);
    }
};

// 测试代码
#include <thread>
#include <vector>
#include <set>
#include <iostream>

void test_id_generator() {
    ThreadSafeIdGenerator gen;
    const int num_threads = 8;
    const int ids_per_thread = 10000;

    std::vector<std::vector<uint64_t>> results(num_threads);
    std::vector<std::thread> threads;

    for (int i = 0; i < num_threads; ++i) {
        threads.emplace_back([&, i]() {
            for (int j = 0; j < ids_per_thread; ++j) {
                results[i].push_back(gen.next());
            }
        });
    }

    for (auto& t : threads) {
        t.join();
    }

    // 验证所有ID都是唯一的
    std::set<uint64_t> all_ids;
    for (const auto& vec : results) {
        for (uint64_t id : vec) {
            if (!all_ids.insert(id).second) {
                std::cout << "ERROR: Duplicate ID found: " << id << "\n";
                return;
            }
        }
    }

    std::cout << "SUCCESS: All " << all_ids.size() << " IDs are unique\n";
    std::cout << "Expected: " << num_threads * ids_per_thread << "\n";
}
```

**第一周检验清单**：
- [ ] 完成《C++ Concurrency in Action》第5章阅读
- [ ] 能够熟练使用std::atomic的所有基础API
- [ ] 理解原子操作的硬件映射
- [ ] 完成ID生成器实现和测试
- [ ] 能够解释以下问题：
  - atomic_flag为什么保证无锁？
  - fetch_add(1)和++运算符有什么区别？
  - 为什么大结构体的atomic可能不是lock-free？

### 第二周：Compare-And-Swap深度

**学习目标**：彻底理解CAS的语义和用法

**阅读材料**：
- [ ] 《C++ Concurrency in Action》第5章CAS部分
- [ ] 论文：Maurice Herlihy - "Wait-Free Synchronization"
- [ ] 扩展阅读：Lock-Free Programming的经典博客文章

---

#### 📅 Day 1-2: CAS基本原理与语义

**学习目标**：
- [ ] 理解CAS操作的原子语义
- [ ] 掌握compare_exchange_strong的使用
- [ ] 理解expected参数的更新机制

#### CAS基本原理
```cpp
// CAS的语义（伪代码）：
bool compare_and_swap(T* ptr, T expected, T desired) {
    if (*ptr == expected) {
        *ptr = desired;
        return true;
    }
    return false;
}
// 整个操作是原子的！

// C++中的两个版本
std::atomic<int> value{5};

// compare_exchange_strong
int expected = 5;
bool success = value.compare_exchange_strong(expected, 10);
// 如果value==5，则设为10，返回true
// 如果value!=5，则expected被更新为当前value，返回false

// compare_exchange_weak
// 可能虚假失败（spurious failure）
// 即使value==expected也可能返回false
// 但在某些架构上更高效
// 通常在循环中使用
```

#### 🔬 深入理解：CAS的完整语义
```cpp
#include <atomic>
#include <iostream>
#include <thread>
#include <vector>

// ==================== CAS的关键细节 ====================

void cas_details() {
    std::atomic<int> value{100};

    // 1. expected是引用，会被修改！
    int expected = 50;  // 故意设置一个错误的期望值
    bool success = value.compare_exchange_strong(expected, 200);

    std::cout << "Success: " << std::boolalpha << success << "\n";
    std::cout << "Expected after CAS: " << expected << "\n";  // 100，被更新了！
    std::cout << "Value: " << value.load() << "\n";            // 100，未被修改

    // 2. 这个特性允许我们获取当前值并重试
    expected = 100;  // 使用刚才获取的值
    success = value.compare_exchange_strong(expected, 200);
    std::cout << "Second try success: " << success << "\n";  // true
    std::cout << "Value now: " << value.load() << "\n";       // 200
}

// ==================== CAS的内存序参数 ====================

void cas_memory_orders() {
    std::atomic<int> value{0};
    int expected = 0;

    // 单一内存序版本（成功和失败使用相同内存序）
    value.compare_exchange_strong(expected, 1, std::memory_order_seq_cst);

    // 双内存序版本（成功和失败可以使用不同内存序）
    expected = 1;
    value.compare_exchange_strong(expected, 2,
        std::memory_order_acq_rel,    // 成功时的内存序
        std::memory_order_acquire);   // 失败时的内存序

    // 为什么需要两个内存序？
    // - 成功：需要release语义（发布新值）
    // - 失败：只需要acquire语义（读取当前值）
    // - 失败时不需要release，因为没有写入

    // 常见模式
    expected = 2;
    value.compare_exchange_weak(expected, 3,
        std::memory_order_release,
        std::memory_order_relaxed);
}

// ==================== CAS vs 其他原子操作 ====================

/*
compare_exchange vs fetch_add 的选择：

fetch_add适用于：
- 简单的加减操作
- 不需要知道旧值就能计算新值
- 例如：counter++

CAS适用于：
- 需要基于旧值计算新值
- 复杂的原子更新
- 条件性更新
- 例如：if (x < 10) x = x * 2

性能比较：
- fetch_add: 硬件直接支持，一次成功
- CAS循环: 可能需要多次重试，尤其在高竞争下
*/

// ==================== CAS实现非平凡操作 ====================

// 原子地计算最大值
void atomic_max(std::atomic<int>& atom, int value) {
    int current = atom.load(std::memory_order_relaxed);
    while (current < value) {
        if (atom.compare_exchange_weak(current, value,
                std::memory_order_relaxed)) {
            return;
        }
        // current已被更新，继续比较
    }
}

// 原子地追加字符到字符串（假设string长度足够）
// 注意：这只是演示，实际中atomic<string>可能不是lock-free
struct ShortString {
    char data[16];
    int length;
};

void atomic_append(std::atomic<ShortString>& str, char c) {
    ShortString expected = str.load();
    ShortString desired;
    do {
        desired = expected;
        if (desired.length < 15) {
            desired.data[desired.length++] = c;
            desired.data[desired.length] = '\0';
        }
    } while (!str.compare_exchange_weak(expected, desired));
}
```

**Day 1-2 检验标准**：
- [ ] 能够解释CAS的原子语义
- [ ] 理解expected参数为什么必须是引用
- [ ] 知道CAS的两个内存序参数的作用
- [ ] 能够用CAS实现atomic_max

---

#### 📅 Day 3-4: strong vs weak 深度对比

**学习目标**：
- [ ] 深入理解spurious failure的原因
- [ ] 掌握选择strong/weak的决策标准
- [ ] 理解LL/SC架构对CAS实现的影响

#### strong vs weak
```cpp
// compare_exchange_strong:
// - 只有value != expected时才失败
// - 适合单次尝试场景

// compare_exchange_weak:
// - 可能虚假失败
// - 在LL/SC架构（ARM/POWER）上更高效
// - 适合循环中使用

// 何时用weak？
// - 在循环中（反正要重试）
// - 性能关键路径

// 何时用strong？
// - 单次尝试
// - 失败后有复杂逻辑（不想虚假执行）

// LL/SC架构原理：
// Load-Linked: 读取值并设置监视
// Store-Conditional: 只有监视未被破坏时才写入
// 任何对该地址的其他写入都会破坏监视
// 因此可能"虚假失败"
```

#### 🔬 深入理解：Spurious Failure的根本原因
```cpp
#include <atomic>
#include <iostream>

// ==================== LL/SC架构详解 ====================

/*
在ARM/POWER架构上，没有直接的CAS指令。
CAS通过LL/SC（Load-Linked/Store-Conditional）实现：

compare_exchange_weak的实现伪代码（ARM）：
    LDAXR  r1, [addr]       ; Load-Linked：读取并设置独占监视器
    CMP    r1, expected     ; 比较
    BNE    fail             ; 不相等则跳转
    STLXR  r2, desired, [addr]  ; Store-Conditional：尝试写入
    CBNZ   r2, spurious_fail    ; 如果r2!=0，说明写入失败
    ; 成功
    ...

spurious_fail:
    ; 即使r1==expected，STLXR也可能失败
    ; 这发生在：
    ; 1. 另一个CPU访问了同一缓存行
    ; 2. 发生了中断
    ; 3. 缓存行被evict
    ; 这就是"虚假失败"

compare_exchange_strong的实现：
    在weak的基础上加一个外层循环
    只有当值真的不相等时才返回false

    do {
        result = compare_exchange_weak(...)
    } while (!result && *ptr == expected);
    return result;
*/

// ==================== x86 vs ARM的差异 ====================

/*
x86架构：
- 有原生CMPXCHG指令
- weak和strong生成相同代码
- 不存在真正的spurious failure
- 但标准仍允许weak虚假失败，为了可移植性

ARM架构：
- 使用LL/SC实现
- weak直接映射到LL/SC
- strong在LL/SC外加循环
- weak确实可能虚假失败

x86上的compare_exchange_weak：
    mov eax, expected
    lock cmpxchg [addr], desired
    ; 单条指令，不会虚假失败

ARM上的compare_exchange_weak：
    ldaxr x0, [addr]
    cmp x0, expected
    bne fail
    stlxr w1, desired, [addr]
    cbnz w1, spurious  ; 可能虚假失败！
*/

// ==================== 性能对比实验 ====================

#include <thread>
#include <vector>
#include <chrono>

std::atomic<int> counter{0};

void bench_cas_weak(int iterations) {
    for (int i = 0; i < iterations; ++i) {
        int expected = counter.load(std::memory_order_relaxed);
        while (!counter.compare_exchange_weak(expected, expected + 1,
                std::memory_order_relaxed)) {
            // weak可能虚假失败，但在循环中没问题
        }
    }
}

void bench_cas_strong(int iterations) {
    for (int i = 0; i < iterations; ++i) {
        int expected = counter.load(std::memory_order_relaxed);
        while (!counter.compare_exchange_strong(expected, expected + 1,
                std::memory_order_relaxed)) {
            // strong不会虚假失败
        }
    }
}

void compare_weak_strong() {
    const int iterations = 1000000;
    const int num_threads = 4;

    auto benchmark = [&](const char* name, auto func) {
        counter = 0;
        auto start = std::chrono::high_resolution_clock::now();

        std::vector<std::thread> threads;
        for (int i = 0; i < num_threads; ++i) {
            threads.emplace_back(func, iterations);
        }
        for (auto& t : threads) {
            t.join();
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

        std::cout << name << ": " << ms.count() << " ms\n";
    };

    std::cout << "=== Weak vs Strong CAS Performance ===\n";
    benchmark("CAS weak  ", bench_cas_weak);
    benchmark("CAS strong", bench_cas_strong);

    // 在x86上，两者性能应该相近
    // 在ARM上，weak可能更快（尤其是低竞争场景）
}

// ==================== 选择决策树 ====================

/*
选择 compare_exchange_weak 还是 strong？

┌─────────────────────────────────────────────────────┐
│                  是否在循环中？                      │
└─────────────────────────────────────────────────────┘
            │                           │
           是                          否
            │                           │
            v                           v
   ┌────────────────┐         ┌────────────────────┐
   │  使用 weak     │         │ 失败后有复杂逻辑？  │
   │  （虚假失败    │         └────────────────────┘
   │   无所谓）     │                 │        │
   └────────────────┘                是       否
                                      │        │
                                      v        v
                             ┌──────────┐  ┌──────────┐
                             │  strong  │  │   weak   │
                             │（避免虚假│  │ （更高效）│
                             │  执行）  │  └──────────┘
                             └──────────┘

具体例子：

1. 使用weak（在循环中）：
   while (!atom.compare_exchange_weak(exp, desired)) {}

2. 使用strong（单次尝试，失败有副作用）：
   if (atom.compare_exchange_strong(exp, desired)) {
       // 成功，执行复杂操作
       allocate_resources();
       update_state();
   } else {
       // 失败，不想因虚假失败而跳过成功分支
   }

3. 使用weak（单次尝试，失败无副作用）：
   bool acquired = lock.compare_exchange_weak(false, true);
   if (acquired) {
       // 获得锁
   } else {
       // 没获得，做其他事情
       // 即使虚假失败也无所谓，下次再试
   }
*/
```

**Day 3-4 检验标准**：
- [ ] 能够解释LL/SC架构如何导致spurious failure
- [ ] 理解为什么x86上weak和strong性能相近
- [ ] 能够根据场景正确选择weak或strong
- [ ] 完成性能对比实验

---

#### 📅 Day 5-6: CAS循环模式与优化

**学习目标**：
- [ ] 掌握标准CAS循环模式
- [ ] 学习退避策略减少竞争
- [ ] 理解CAS循环的性能优化技巧

#### CAS循环模式
```cpp
// 原子地将value翻倍
std::atomic<int> value{5};

void double_value() {
    int expected = value.load();
    while (!value.compare_exchange_weak(expected, expected * 2)) {
        // expected已被更新为当前值，继续尝试
    }
}

// 通用的Read-Modify-Write模式
template <typename T, typename F>
T atomic_update(std::atomic<T>& atom, F&& f) {
    T expected = atom.load(std::memory_order_relaxed);
    T desired;
    do {
        desired = f(expected);
    } while (!atom.compare_exchange_weak(expected, desired,
                std::memory_order_release,
                std::memory_order_relaxed));
    return desired;
}

// 使用
atomic_update(value, [](int x) { return x * 2; });
```

#### 🔬 深入理解：CAS循环的高级模式
```cpp
#include <atomic>
#include <thread>
#include <chrono>
#include <random>
#include <iostream>

// ==================== 标准CAS循环模板 ====================

template <typename T, typename UpdateFunc>
T cas_loop(std::atomic<T>& atom, UpdateFunc update,
           std::memory_order success_order = std::memory_order_seq_cst,
           std::memory_order failure_order = std::memory_order_relaxed) {

    T expected = atom.load(std::memory_order_relaxed);
    T desired;

    do {
        desired = update(expected);
        // 如果计算出的新值等于旧值，不需要CAS
        if (desired == expected) {
            return expected;
        }
    } while (!atom.compare_exchange_weak(expected, desired,
                                          success_order, failure_order));

    return expected;  // 返回旧值
}

// 使用示例
void example_usage() {
    std::atomic<int> value{10};

    // 原子地翻倍
    int old = cas_loop(value, [](int x) { return x * 2; });
    std::cout << "Old: " << old << ", New: " << value.load() << "\n";

    // 原子地取最大值
    cas_loop(value, [](int x) { return std::max(x, 100); });
}

// ==================== 带退避的CAS循环 ====================

template <typename T, typename UpdateFunc>
T cas_loop_with_backoff(std::atomic<T>& atom, UpdateFunc update) {
    T expected = atom.load(std::memory_order_relaxed);
    T desired;

    int backoff = 1;
    const int max_backoff = 1024;

    while (true) {
        desired = update(expected);

        if (atom.compare_exchange_weak(expected, desired,
                std::memory_order_release,
                std::memory_order_relaxed)) {
            return expected;
        }

        // 指数退避
        for (int i = 0; i < backoff; ++i) {
            // 可以使用pause指令（x86）或yield（ARM）
            #if defined(__x86_64__) || defined(_M_X64)
            __builtin_ia32_pause();  // 或 _mm_pause()
            #elif defined(__aarch64__)
            __asm__ volatile("yield");
            #endif
        }

        backoff = std::min(backoff * 2, max_backoff);
    }
}

// ==================== 自适应退避策略 ====================

class AdaptiveBackoff {
    int current_backoff_ = 1;
    int success_count_ = 0;
    static constexpr int min_backoff = 1;
    static constexpr int max_backoff = 1024;

public:
    void on_failure() {
        // 失败时增加退避
        for (int i = 0; i < current_backoff_; ++i) {
            #if defined(__x86_64__)
            __builtin_ia32_pause();
            #endif
        }
        current_backoff_ = std::min(current_backoff_ * 2, max_backoff);
        success_count_ = 0;
    }

    void on_success() {
        // 连续成功时减少退避
        if (++success_count_ > 3) {
            current_backoff_ = std::max(current_backoff_ / 2, min_backoff);
            success_count_ = 0;
        }
    }
};

// ==================== 避免不必要的CAS ====================

// 反模式：每次都CAS
void bad_increment(std::atomic<int>& counter) {
    int expected = counter.load();
    while (!counter.compare_exchange_weak(expected, expected + 1)) {
        // 这个循环可能在高竞争下自旋很久
    }
}

// 优化1：使用fetch_add（如果可能）
void good_increment(std::atomic<int>& counter) {
    counter.fetch_add(1, std::memory_order_relaxed);
    // 硬件原生支持，不需要循环
}

// 优化2：先检查再CAS（适用于条件更新）
void conditional_update(std::atomic<int>& value, int threshold, int new_val) {
    int current = value.load(std::memory_order_relaxed);

    // 先检查条件，避免不必要的CAS
    while (current < threshold) {
        if (value.compare_exchange_weak(current, new_val,
                std::memory_order_release,
                std::memory_order_relaxed)) {
            return;  // 成功
        }
        // current已更新，继续检查条件
    }
    // current >= threshold，不需要更新
}

// ==================== CAS循环的正确性陷阱 ====================

// 陷阱1：忘记更新expected
void bug_example() {
    std::atomic<int> value{0};
    int expected = 0;

    // 错误：expected没有在循环中更新
    while (!value.compare_exchange_weak(expected, expected + 1)) {
        // expected被CAS更新了，下一次计算基于新的expected
        // 但如果你在这里重置expected，就错了：
        // expected = 0;  // 错误！
    }
}

// 陷阱2：无限循环的可能
void potential_infinite_loop(std::atomic<int>& value, int target) {
    int expected = value.load();

    // 如果其他线程不断修改value，这可能永远不成功
    while (!value.compare_exchange_weak(expected, target)) {
        // 需要考虑添加最大重试次数或退避策略
    }
}

// 更健壮的版本
bool safe_update(std::atomic<int>& value, int target, int max_retries = 1000) {
    int expected = value.load(std::memory_order_relaxed);
    int retries = 0;

    while (!value.compare_exchange_weak(expected, target,
            std::memory_order_release,
            std::memory_order_relaxed)) {
        if (++retries > max_retries) {
            return false;  // 放弃
        }

        // 可选：添加退避
        std::this_thread::yield();
    }
    return true;
}
```

**Day 5-6 检验标准**：
- [ ] 能够编写标准的CAS循环模板
- [ ] 理解退避策略的作用和实现
- [ ] 能够识别CAS循环的常见陷阱
- [ ] 知道何时应该用fetch_*替代CAS循环

---

#### 📅 Day 7: ABA问题初探与第二周总结

**学习目标**：
- [ ] 理解ABA问题的本质
- [ ] 了解ABA问题的危害
- [ ] 预习下个月将学习的解决方案

#### 🔬 ABA问题详解
```cpp
#include <atomic>
#include <thread>
#include <iostream>

// ==================== 什么是ABA问题？====================

/*
ABA问题场景：

时间线：
T1: 读取值A
    |
    |  T2: 将A改为B
    |
    |  T2: 将B改回A
    |
T1: CAS(expected=A, desired=C) 成功！

问题：T1的CAS成功了，但它不知道值曾经变成过B。
这在某些场景下是致命的。
*/

// ==================== 无锁栈中的ABA问题 ====================

template <typename T>
class BrokenLockFreeStack {
    struct Node {
        T data;
        Node* next;
    };

    std::atomic<Node*> head_{nullptr};

public:
    void push(T value) {
        Node* new_node = new Node{std::move(value), nullptr};
        new_node->next = head_.load(std::memory_order_relaxed);
        while (!head_.compare_exchange_weak(new_node->next, new_node,
                std::memory_order_release,
                std::memory_order_relaxed)) {}
    }

    T* pop() {
        Node* old_head = head_.load(std::memory_order_relaxed);

        // ABA问题场景：
        // 假设栈是: A -> B -> C
        // T1执行到这里，old_head = A, old_head->next = B

        // ---- T1被挂起 ----

        // T2执行: pop() 得到A，delete A
        // T2执行: pop() 得到B，delete B
        // T2执行: push(D)，D的地址恰好是之前A的地址（内存重用）
        // 栈现在是: D(地址=A) -> C

        // ---- T1恢复 ----

        // T1的CAS: head_.compare_exchange(A, B)
        // head_ == D，但D的地址等于A
        // CAS成功！head_ = B
        // 但B已经被释放了！

        while (old_head != nullptr &&
               !head_.compare_exchange_weak(old_head, old_head->next,
                   std::memory_order_acquire,
                   std::memory_order_relaxed)) {}

        if (old_head == nullptr) {
            return nullptr;
        }

        T* result = &old_head->data;
        delete old_head;  // 这里可能会导致问题
        return result;
    }
};

// ==================== ABA问题的本质 ====================

/*
ABA问题的核心：
CAS只比较值，不关心"这个值是否曾经改变过"。

危险场景：
1. 无锁数据结构（栈、队列、链表）
2. 涉及指针的CAS
3. 内存可能被重用

不危险的场景：
1. 单调递增的计数器（值不会回到之前的状态）
2. 不涉及指针的简单值
3. 值域足够大，重复概率极低
*/

// ==================== 解决方案预览（下月详细学习）====================

/*
1. Tagged Pointer（标记指针）
   - 在指针低位或高位存储计数器
   - 每次修改时计数器+1
   - 需要双字CAS（128位CAS）

2. Hazard Pointer（危险指针）
   - 标记正在使用的节点
   - 延迟回收被标记的节点

3. Epoch-Based Reclamation（基于纪元的回收）
   - 全局纪元计数器
   - 延迟到安全纪元再回收

4. Reference Counting（引用计数）
   - 原子引用计数
   - 引用为0时才真正释放

这些技术将在Month-16详细学习！
*/

// ==================== 简单的ABA缓解：版本号 ====================

// 使用128位CAS（如果硬件支持）
struct VersionedPointer {
    void* ptr;
    uint64_t version;
};

class VersionedAtomicPointer {
    std::atomic<VersionedPointer> data_{{nullptr, 0}};

public:
    void* load() const {
        return data_.load(std::memory_order_acquire).ptr;
    }

    bool compare_exchange(void* expected, void* desired) {
        VersionedPointer current = data_.load(std::memory_order_relaxed);

        if (current.ptr != expected) {
            return false;
        }

        VersionedPointer new_value{desired, current.version + 1};
        return data_.compare_exchange_strong(current, new_value,
            std::memory_order_release,
            std::memory_order_relaxed);
    }
};
```

**第二周知识图谱**：
```
Compare-And-Swap (CAS)
├── 基本语义
│   ├── 原子比较和交换
│   ├── expected参数的更新
│   └── 双内存序参数
├── strong vs weak
│   ├── spurious failure原因（LL/SC）
│   ├── 性能差异（ARM vs x86）
│   └── 选择决策树
├── CAS循环模式
│   ├── 标准模板
│   ├── 退避策略（指数退避/自适应）
│   └── 常见陷阱
└── ABA问题
    ├── 问题本质
    ├── 危险场景
    └── 解决方案预览
```

**第二周检验清单**：
- [ ] 能够解释CAS的完整语义
- [ ] 能够根据场景选择weak或strong
- [ ] 能够编写带退避的CAS循环
- [ ] 理解ABA问题及其危害
- [ ] 能够回答：
  - 为什么CAS的expected参数是引用？
  - LL/SC如何导致spurious failure？
  - 什么场景下ABA问题是危险的？

### 第三周：高级原子操作

**学习目标**：掌握fetch_*操作和内存栅栏

**阅读材料**：
- [ ] 《C++ Concurrency in Action》第5章内存栅栏部分
- [ ] cppreference atomic_thread_fence文档
- [ ] Intel Memory Ordering White Paper

---

#### 📅 Day 1-2: Fetch操作家族详解

**学习目标**：
- [ ] 掌握所有fetch_*操作的语义
- [ ] 理解fetch_*与CAS循环的性能差异
- [ ] 学习实际应用场景

#### Fetch操作家族
```cpp
std::atomic<int> counter{0};

// 所有fetch_*操作返回旧值
int old = counter.fetch_add(1);  // old=0, counter=1
old = counter.fetch_sub(1);       // old=1, counter=0

// 位操作
std::atomic<unsigned> flags{0};
flags.fetch_or(0x01);   // 设置bit 0
flags.fetch_and(~0x01); // 清除bit 0
flags.fetch_xor(0x01);  // 翻转bit 0

// 与++/--的区别
counter++;        // 返回旧值（但通常被丢弃）
++counter;        // 返回新值
counter.fetch_add(1);  // 返回旧值

// 指定内存序
counter.fetch_add(1, std::memory_order_relaxed);
counter.fetch_add(1, std::memory_order_acq_rel);
```

#### 🔬 深入理解：Fetch操作的高级用法
```cpp
#include <atomic>
#include <iostream>
#include <thread>
#include <vector>
#include <bitset>

// ==================== Fetch操作 vs CAS循环 ====================

/*
关键区别：
- fetch_*: 硬件原生支持，一次成功（无竞争时）
- CAS循环: 可能需要多次重试

性能影响：
高竞争场景下：
- fetch_add: 每个操作都会成功，只是等待硬件
- CAS循环: 可能大量重试，浪费CPU周期
*/

// 性能对比
void compare_fetch_vs_cas() {
    std::atomic<long> counter1{0};
    std::atomic<long> counter2{0};

    const int num_threads = 8;
    const int iterations = 1000000;

    auto fetch_add_worker = [&]() {
        for (int i = 0; i < iterations; ++i) {
            counter1.fetch_add(1, std::memory_order_relaxed);
        }
    };

    auto cas_loop_worker = [&]() {
        for (int i = 0; i < iterations; ++i) {
            long expected = counter2.load(std::memory_order_relaxed);
            while (!counter2.compare_exchange_weak(expected, expected + 1,
                    std::memory_order_relaxed)) {}
        }
    };

    // 运行并计时...
}

// ==================== 位操作的实际应用 ====================

class AtomicBitSet {
    std::atomic<uint64_t> bits_{0};

public:
    // 设置位，返回之前是否未设置
    bool set(int index) {
        uint64_t mask = 1ULL << index;
        uint64_t old = bits_.fetch_or(mask, std::memory_order_acq_rel);
        return !(old & mask);
    }

    // 清除位，返回之前是否已设置
    bool clear(int index) {
        uint64_t mask = 1ULL << index;
        uint64_t old = bits_.fetch_and(~mask, std::memory_order_acq_rel);
        return old & mask;
    }

    // 翻转位，返回之前的值
    bool toggle(int index) {
        uint64_t mask = 1ULL << index;
        uint64_t old = bits_.fetch_xor(mask, std::memory_order_acq_rel);
        return old & mask;
    }

    // 测试位
    bool test(int index) const {
        return bits_.load(std::memory_order_acquire) & (1ULL << index);
    }

    // 原子地设置第一个未设置的位，返回位索引（-1表示全满）
    int set_first_unset() {
        uint64_t current = bits_.load(std::memory_order_relaxed);
        while (current != ~0ULL) {  // 不是全1
            // 找到第一个0位
            int index = __builtin_ctzll(~current);  // count trailing zeros
            uint64_t mask = 1ULL << index;

            // 尝试设置
            if (bits_.compare_exchange_weak(current, current | mask,
                    std::memory_order_acq_rel,
                    std::memory_order_relaxed)) {
                return index;
            }
            // current已更新，继续尝试
        }
        return -1;  // 全满
    }
};

// ==================== fetch_add的返回值用途 ====================

// 1. 分配唯一序号
class SequenceGenerator {
    std::atomic<uint64_t> next_{0};

public:
    uint64_t next() {
        return next_.fetch_add(1, std::memory_order_relaxed);
    }
};

// 2. 实现信号量
class Semaphore {
    std::atomic<int> count_;

public:
    explicit Semaphore(int initial) : count_(initial) {}

    void acquire() {
        while (true) {
            int current = count_.load(std::memory_order_relaxed);
            if (current <= 0) {
                std::this_thread::yield();
                continue;
            }
            if (count_.compare_exchange_weak(current, current - 1,
                    std::memory_order_acquire,
                    std::memory_order_relaxed)) {
                return;
            }
        }
    }

    void release() {
        count_.fetch_add(1, std::memory_order_release);
    }

    // 非阻塞版本
    bool try_acquire() {
        int current = count_.load(std::memory_order_relaxed);
        while (current > 0) {
            if (count_.compare_exchange_weak(current, current - 1,
                    std::memory_order_acquire,
                    std::memory_order_relaxed)) {
                return true;
            }
        }
        return false;
    }
};

// 3. 引用计数
class RefCounted {
    mutable std::atomic<int> ref_count_{1};

public:
    void add_ref() const {
        ref_count_.fetch_add(1, std::memory_order_relaxed);
    }

    void release() const {
        // fetch_sub返回旧值，所以旧值为1时说明减后为0
        if (ref_count_.fetch_sub(1, std::memory_order_acq_rel) == 1) {
            delete this;
        }
    }

    int use_count() const {
        return ref_count_.load(std::memory_order_relaxed);
    }

protected:
    virtual ~RefCounted() = default;
};

// ==================== C++20新增的fetch_max/fetch_min ====================

#if __cplusplus >= 202002L
void cpp20_fetch_operations() {
    std::atomic<int> value{50};

    // 原子地取最大值
    int old_max = value.fetch_max(100);  // value变为100
    // 等价于CAS循环实现的atomic_max

    // 原子地取最小值
    int old_min = value.fetch_min(30);   // value变为30

    // 对于无符号类型，有无符号版本
    std::atomic<unsigned> uvalue{50};
    uvalue.fetch_max(100u);
}
#endif

// 在C++17中手动实现
template <typename T>
T atomic_fetch_max(std::atomic<T>& atom, T value,
                   std::memory_order order = std::memory_order_seq_cst) {
    T current = atom.load(std::memory_order_relaxed);
    while (current < value) {
        if (atom.compare_exchange_weak(current, value, order,
                std::memory_order_relaxed)) {
            return current;  // 返回旧值
        }
    }
    return current;  // 当前值已经>=value
}
```

**Day 1-2 检验标准**：
- [ ] 理解fetch_*与CAS循环的性能差异
- [ ] 能够用fetch_or/and/xor实现位操作
- [ ] 能够实现引用计数类
- [ ] 知道fetch_add返回旧值的用途

---

#### 📅 Day 3-4: 原子交换与自旋锁实现

**学习目标**：
- [ ] 掌握exchange操作的语义
- [ ] 学习多种自旋锁实现方式
- [ ] 理解自旋锁的性能优化技巧

#### 原子交换
```cpp
std::atomic<int> value{5};

// exchange: 设置新值，返回旧值
int old = value.exchange(10);  // old=5, value=10

// 常用于实现自旋锁
std::atomic<bool> locked{false};

void lock() {
    while (locked.exchange(true, std::memory_order_acquire)) {
        // 自旋
    }
}

void unlock() {
    locked.store(false, std::memory_order_release);
}
```

#### 🔬 深入理解：自旋锁的多种实现
```cpp
#include <atomic>
#include <thread>
#include <iostream>

// ==================== 1. 基础TAS（Test-And-Set）自旋锁 ====================

class TASSpinLock {
    std::atomic<bool> locked_{false};

public:
    void lock() {
        while (locked_.exchange(true, std::memory_order_acquire)) {
            // 自旋
        }
    }

    void unlock() {
        locked_.store(false, std::memory_order_release);
    }
};

/*
问题：每次自旋都执行exchange（写操作）
这会导致缓存行在核心间不断弹跳（cache line bouncing）
*/

// ==================== 2. TTAS（Test-and-Test-And-Set）自旋锁 ====================

class TTASSpinLock {
    std::atomic<bool> locked_{false};

public:
    void lock() {
        while (true) {
            // 第一个Test：只读，不会造成缓存失效
            while (locked_.load(std::memory_order_relaxed)) {
                // 自旋在本地缓存上
            }

            // 第二个Test-And-Set：尝试获取锁
            if (!locked_.exchange(true, std::memory_order_acquire)) {
                return;  // 成功获取锁
            }
            // 失败，继续外层循环
        }
    }

    void unlock() {
        locked_.store(false, std::memory_order_release);
    }
};

/*
改进：
- 内层循环只做读取，在本地缓存上自旋
- 只有看到锁可能可用时才尝试exchange
- 大大减少了缓存行弹跳
*/

// ==================== 3. 带退避的自旋锁 ====================

class BackoffSpinLock {
    std::atomic<bool> locked_{false};

public:
    void lock() {
        int backoff = 1;
        const int max_backoff = 1024;

        while (true) {
            // TTAS模式
            while (locked_.load(std::memory_order_relaxed)) {
                for (int i = 0; i < backoff; ++i) {
                    #if defined(__x86_64__)
                    __builtin_ia32_pause();
                    #endif
                }
            }

            if (!locked_.exchange(true, std::memory_order_acquire)) {
                return;
            }

            // 失败，增加退避
            backoff = std::min(backoff * 2, max_backoff);
        }
    }

    void unlock() {
        locked_.store(false, std::memory_order_release);
    }
};

// ==================== 4. Ticket Lock（公平自旋锁）====================

class TicketLock {
    std::atomic<unsigned> next_ticket_{0};
    std::atomic<unsigned> now_serving_{0};

public:
    void lock() {
        // 取号
        unsigned my_ticket = next_ticket_.fetch_add(1, std::memory_order_relaxed);

        // 等待叫号
        while (now_serving_.load(std::memory_order_acquire) != my_ticket) {
            #if defined(__x86_64__)
            __builtin_ia32_pause();
            #endif
        }
    }

    void unlock() {
        // 叫下一个号
        now_serving_.fetch_add(1, std::memory_order_release);
    }
};

/*
Ticket Lock特点：
- 公平：FIFO顺序
- 无饥饿：每个线程都会获得锁
- 问题：所有等待线程自旋在同一个变量上
*/

// ==================== 5. MCS Lock（可扩展公平锁）====================

struct MCSNode {
    std::atomic<MCSNode*> next{nullptr};
    std::atomic<bool> locked{false};
};

class MCSLock {
    std::atomic<MCSNode*> tail_{nullptr};

public:
    void lock(MCSNode* node) {
        node->next.store(nullptr, std::memory_order_relaxed);
        node->locked.store(true, std::memory_order_relaxed);

        // 将自己加入队列尾部
        MCSNode* prev = tail_.exchange(node, std::memory_order_acq_rel);

        if (prev != nullptr) {
            // 有前驱，链接并等待
            prev->next.store(node, std::memory_order_release);

            // 在自己的节点上自旋（本地自旋）
            while (node->locked.load(std::memory_order_acquire)) {
                #if defined(__x86_64__)
                __builtin_ia32_pause();
                #endif
            }
        }
    }

    void unlock(MCSNode* node) {
        MCSNode* next = node->next.load(std::memory_order_relaxed);

        if (next == nullptr) {
            // 没有后继，尝试清除tail
            MCSNode* expected = node;
            if (tail_.compare_exchange_strong(expected, nullptr,
                    std::memory_order_release,
                    std::memory_order_relaxed)) {
                return;  // 成功，没有等待者
            }

            // 有新的等待者正在加入，等待其完成链接
            while ((next = node->next.load(std::memory_order_relaxed)) == nullptr) {
                #if defined(__x86_64__)
                __builtin_ia32_pause();
                #endif
            }
        }

        // 通知后继
        next->locked.store(false, std::memory_order_release);
    }
};

/*
MCS Lock特点：
- 公平：FIFO顺序
- 可扩展：每个线程自旋在自己的节点上
- 缓存友好：避免了缓存行弹跳
- 缺点：需要传递节点指针，API更复杂
*/

// ==================== 自旋锁性能比较 ====================

void compare_spinlocks() {
    const int num_threads = 8;
    const int iterations = 100000;

    auto benchmark = [&](const char* name, auto& lock) {
        std::atomic<long> counter{0};
        auto start = std::chrono::high_resolution_clock::now();

        std::vector<std::thread> threads;
        for (int i = 0; i < num_threads; ++i) {
            threads.emplace_back([&]() {
                for (int j = 0; j < iterations; ++j) {
                    // lock.lock();
                    counter++;
                    // lock.unlock();
                }
            });
        }

        for (auto& t : threads) {
            t.join();
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

        std::cout << name << ": " << ms.count() << " ms\n";
    };

    // 运行各种锁的基准测试...
}
```

**Day 3-4 检验标准**：
- [ ] 理解TAS和TTAS的区别
- [ ] 能够解释Ticket Lock的公平性
- [ ] 理解MCS Lock的可扩展性原理
- [ ] 知道何时应该使用自旋锁vs互斥锁

---

#### 📅 Day 5-6: 内存栅栏深度理解

**学习目标**：
- [ ] 理解独立内存栅栏的作用
- [ ] 掌握栅栏与原子操作的关系
- [ ] 学习信号处理中的栅栏使用

#### 原子栅栏（Fence）
```cpp
// 独立于原子变量的内存栅栏

std::atomic_thread_fence(std::memory_order_acquire);
// 等价于在所有之前的relaxed load后加acquire

std::atomic_thread_fence(std::memory_order_release);
// 等价于在所有之后的relaxed store前加release

std::atomic_thread_fence(std::memory_order_seq_cst);
// 完整栅栏

// 信号栅栏（用于信号处理器和主线程通信）
std::atomic_signal_fence(std::memory_order_seq_cst);
// 只阻止编译器重排，不发出硬件栅栏
```

#### 🔬 深入理解：内存栅栏的原理与应用
```cpp
#include <atomic>
#include <thread>
#include <cassert>

// ==================== 栅栏的基本原理 ====================

/*
内存栅栏的作用：
1. 阻止编译器重排序
2. 发出硬件内存屏障指令

栅栏与原子操作的区别：
- 原子操作的内存序：作用于该特定原子变量
- 栅栏：作用于所有内存操作

acquire fence：之前的load不能被移到fence之后
release fence：之后的store不能被移到fence之前
seq_cst fence：完整屏障，阻止所有重排
*/

// ==================== 使用栅栏替代原子操作的内存序 ====================

std::atomic<int> data{0};
std::atomic<bool> ready{false};

// 方式1：使用原子操作的内存序
void producer_v1() {
    data.store(42, std::memory_order_relaxed);
    ready.store(true, std::memory_order_release);  // release语义
}

void consumer_v1() {
    while (!ready.load(std::memory_order_acquire)) {}  // acquire语义
    assert(data.load(std::memory_order_relaxed) == 42);
}

// 方式2：使用独立栅栏
void producer_v2() {
    data.store(42, std::memory_order_relaxed);
    std::atomic_thread_fence(std::memory_order_release);  // release栅栏
    ready.store(true, std::memory_order_relaxed);
}

void consumer_v2() {
    while (!ready.load(std::memory_order_relaxed)) {}
    std::atomic_thread_fence(std::memory_order_acquire);  // acquire栅栏
    assert(data.load(std::memory_order_relaxed) == 42);
}

/*
两种方式的区别：
- v1：内存序直接附加在原子操作上
- v2：栅栏影响所有相邻的内存操作

栅栏的优势：
- 可以批量保护多个操作
- 某些场景下更灵活

栅栏的劣势：
- 可能过度同步（影响更多操作）
- 代码可读性可能更差
*/

// ==================== 栅栏的实际应用场景 ====================

// 场景1：批量发布多个变量
std::atomic<int> var1{0}, var2{0}, var3{0};
std::atomic<bool> published{false};

void publish_multiple() {
    var1.store(1, std::memory_order_relaxed);
    var2.store(2, std::memory_order_relaxed);
    var3.store(3, std::memory_order_relaxed);

    // 一个release栅栏保护上面所有store
    std::atomic_thread_fence(std::memory_order_release);

    published.store(true, std::memory_order_relaxed);
}

void consume_multiple() {
    while (!published.load(std::memory_order_relaxed)) {}

    // 一个acquire栅栏保护下面所有load
    std::atomic_thread_fence(std::memory_order_acquire);

    assert(var1.load(std::memory_order_relaxed) == 1);
    assert(var2.load(std::memory_order_relaxed) == 2);
    assert(var3.load(std::memory_order_relaxed) == 3);
}

// 场景2：与非原子变量配合使用
int regular_data = 0;  // 非原子变量
std::atomic<bool> flag{false};

void writer() {
    regular_data = 42;  // 非原子写
    std::atomic_thread_fence(std::memory_order_release);
    flag.store(true, std::memory_order_relaxed);
}

void reader() {
    while (!flag.load(std::memory_order_relaxed)) {}
    std::atomic_thread_fence(std::memory_order_acquire);
    assert(regular_data == 42);  // 安全读取非原子变量
}

// ==================== 信号栅栏：atomic_signal_fence ====================

/*
atomic_signal_fence vs atomic_thread_fence：
- thread_fence：阻止编译器重排 + 发出硬件栅栏
- signal_fence：只阻止编译器重排，不发出硬件栅栏

用途：同一线程内的信号处理器与主代码通信
（因为是同一个CPU核心，不需要硬件同步）
*/

volatile sig_atomic_t signal_flag = 0;
int signal_data = 0;

void signal_handler(int) {
    signal_data = 42;
    // 只需要编译器屏障，因为是同一线程
    std::atomic_signal_fence(std::memory_order_release);
    signal_flag = 1;
}

void wait_for_signal() {
    while (!signal_flag) {}
    std::atomic_signal_fence(std::memory_order_acquire);
    // signal_data保证是42
}

// ==================== 硬件层面的栅栏指令 ====================

/*
x86/x64:
- MFENCE: 完整内存屏障
- SFENCE: Store fence (通常用于非临时写)
- LFENCE: Load fence (通常用于序列化)

ARM:
- DMB (Data Memory Barrier): 数据内存屏障
- DSB (Data Synchronization Barrier): 数据同步屏障
- ISB (Instruction Synchronization Barrier): 指令同步屏障

C++到x86的映射（常见情况）：
- seq_cst store: MOV + MFENCE 或 XCHG
- seq_cst load: MOV (x86有强内存模型)
- acquire fence: 通常不需要指令（编译器屏障足够）
- release fence: 通常不需要指令（编译器屏障足够）
- seq_cst fence: MFENCE

C++到ARM的映射：
- acquire fence: DMB ISHLD
- release fence: DMB ISHST
- seq_cst fence: DMB ISH
*/

// ==================== 栅栏使用的常见错误 ====================

// 错误1：栅栏位置不对
void wrong_fence_position() {
    std::atomic<int> a{0}, b{0};

    // 错误：栅栏在两个store之间，不能保护第一个
    a.store(1, std::memory_order_relaxed);
    std::atomic_thread_fence(std::memory_order_release);
    b.store(2, std::memory_order_relaxed);

    // 正确：栅栏在所有需要保护的store之后
    // a.store(1, std::memory_order_relaxed);
    // b.store(2, std::memory_order_relaxed);
    // std::atomic_thread_fence(std::memory_order_release);
    // ready.store(true, std::memory_order_relaxed);
}

// 错误2：用栅栏替代原子性
void wrong_atomicity() {
    int x = 0;  // 非原子

    // 错误理解：栅栏不能使非原子操作变成原子！
    std::atomic_thread_fence(std::memory_order_seq_cst);
    x++;  // 这仍然不是原子操作！
    std::atomic_thread_fence(std::memory_order_seq_cst);

    // 栅栏只影响内存可见性顺序，不提供原子性
}
```

**Day 5-6 检验标准**：
- [ ] 理解栅栏与原子操作内存序的区别
- [ ] 能够用栅栏批量保护多个操作
- [ ] 理解signal_fence的用途
- [ ] 知道栅栏不能提供原子性

---

#### 📅 Day 7: 第三周总结与综合实践

**本周知识图谱**：
```
高级原子操作
├── Fetch操作家族
│   ├── fetch_add/sub（算术）
│   ├── fetch_and/or/xor（位操作）
│   ├── 返回旧值的用途
│   └── C++20: fetch_max/fetch_min
├── 原子交换
│   ├── exchange语义
│   └── 自旋锁实现
│       ├── TAS / TTAS
│       ├── Backoff
│       ├── Ticket Lock
│       └── MCS Lock
└── 内存栅栏
    ├── atomic_thread_fence
    │   ├── acquire/release/seq_cst
    │   └── 与原子操作的关系
    ├── atomic_signal_fence
    │   └── 信号处理应用
    └── 硬件指令映射
```

**综合练习：实现一个高性能计数器组**
```cpp
// high_perf_counters.hpp
#pragma once
#include <atomic>
#include <array>
#include <thread>
#include <numeric>

// 分片计数器：减少竞争
template <size_t NumShards = 16>
class ShardedCounter {
    struct alignas(64) Shard {  // 缓存行对齐
        std::atomic<long> count{0};
    };

    std::array<Shard, NumShards> shards_;

    static size_t shard_index() {
        // 使用线程ID选择分片
        static thread_local size_t index =
            std::hash<std::thread::id>{}(std::this_thread::get_id()) % NumShards;
        return index;
    }

public:
    void increment() {
        shards_[shard_index()].count.fetch_add(1, std::memory_order_relaxed);
    }

    void decrement() {
        shards_[shard_index()].count.fetch_sub(1, std::memory_order_relaxed);
    }

    void add(long value) {
        shards_[shard_index()].count.fetch_add(value, std::memory_order_relaxed);
    }

    // 读取总和（可能不精确，因为没有同步）
    long approximate_count() const {
        long sum = 0;
        for (const auto& shard : shards_) {
            sum += shard.count.load(std::memory_order_relaxed);
        }
        return sum;
    }

    // 精确读取（使用栅栏）
    long exact_count() const {
        std::atomic_thread_fence(std::memory_order_seq_cst);
        long sum = 0;
        for (const auto& shard : shards_) {
            sum += shard.count.load(std::memory_order_relaxed);
        }
        std::atomic_thread_fence(std::memory_order_seq_cst);
        return sum;
    }
};

// 带最大值追踪的计数器
class MaxTrackingCounter {
    std::atomic<long> current_{0};
    std::atomic<long> max_{0};

public:
    void increment() {
        long new_val = current_.fetch_add(1, std::memory_order_relaxed) + 1;
        update_max(new_val);
    }

    void decrement() {
        current_.fetch_sub(1, std::memory_order_relaxed);
    }

    long current() const {
        return current_.load(std::memory_order_relaxed);
    }

    long max() const {
        return max_.load(std::memory_order_relaxed);
    }

private:
    void update_max(long value) {
        long current_max = max_.load(std::memory_order_relaxed);
        while (value > current_max) {
            if (max_.compare_exchange_weak(current_max, value,
                    std::memory_order_relaxed)) {
                return;
            }
        }
    }
};

// 测试代码
#include <vector>
#include <iostream>
#include <chrono>

void test_sharded_counter() {
    ShardedCounter<16> counter;
    const int num_threads = 8;
    const int iterations = 1000000;

    auto start = std::chrono::high_resolution_clock::now();

    std::vector<std::thread> threads;
    for (int i = 0; i < num_threads; ++i) {
        threads.emplace_back([&]() {
            for (int j = 0; j < iterations; ++j) {
                counter.increment();
            }
        });
    }

    for (auto& t : threads) {
        t.join();
    }

    auto end = std::chrono::high_resolution_clock::now();
    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

    std::cout << "Final count: " << counter.exact_count()
              << " (expected: " << num_threads * iterations << ")\n";
    std::cout << "Time: " << ms.count() << " ms\n";
}
```

**第三周检验清单**：
- [ ] 理解fetch_*操作的性能优势
- [ ] 能够实现多种自旋锁
- [ ] 理解内存栅栏的作用和限制
- [ ] 完成分片计数器实现
- [ ] 能够回答：
  - fetch_add和CAS循环哪个更快？为什么？
  - TTAS比TAS好在哪里？
  - 栅栏能否使非原子操作变成原子？

### 第四周：CAS应用模式

**学习目标**：学习CAS的常见应用模式，实现无锁数据结构

**阅读材料**：
- [ ] 《C++ Concurrency in Action》第7章无锁数据结构
- [ ] 论文：Treiber Stack
- [ ] folly库中的无锁数据结构源码

---

#### 📅 Day 1-2: 无锁计数器与标志位

**学习目标**：
- [ ] 掌握条件原子更新模式
- [ ] 学习位操作的原子实现
- [ ] 理解组合原子操作的实现

#### 无锁计数器
```cpp
class LockFreeCounter {
    std::atomic<int64_t> count_{0};

public:
    void increment() {
        count_.fetch_add(1, std::memory_order_relaxed);
    }

    void decrement() {
        count_.fetch_sub(1, std::memory_order_relaxed);
    }

    int64_t get() const {
        return count_.load(std::memory_order_relaxed);
    }

    // 条件增加
    bool try_increment_if_below(int64_t limit) {
        int64_t current = count_.load(std::memory_order_relaxed);
        while (current < limit) {
            if (count_.compare_exchange_weak(current, current + 1,
                    std::memory_order_relaxed)) {
                return true;
            }
        }
        return false;
    }
};
```

#### 无锁标志位
```cpp
class AtomicFlags {
    std::atomic<uint32_t> flags_{0};

public:
    bool set_flag(int bit) {
        uint32_t old = flags_.fetch_or(1u << bit, std::memory_order_acq_rel);
        return !(old & (1u << bit));  // 返回之前是否未设置
    }

    bool clear_flag(int bit) {
        uint32_t old = flags_.fetch_and(~(1u << bit), std::memory_order_acq_rel);
        return old & (1u << bit);  // 返回之前是否已设置
    }

    bool test_flag(int bit) const {
        return flags_.load(std::memory_order_acquire) & (1u << bit);
    }

    // 原子地设置一个标志，清除另一个
    void set_and_clear(int set_bit, int clear_bit) {
        uint32_t expected = flags_.load(std::memory_order_relaxed);
        uint32_t desired;
        do {
            desired = (expected | (1u << set_bit)) & ~(1u << clear_bit);
        } while (!flags_.compare_exchange_weak(expected, desired,
                    std::memory_order_acq_rel,
                    std::memory_order_relaxed));
    }
};
```

#### 🔬 深入理解：实用无锁模式
```cpp
#include <atomic>
#include <limits>
#include <optional>
#include <functional>

// ==================== 1. 有界计数器 ====================

class BoundedCounter {
    std::atomic<int64_t> count_{0};
    const int64_t min_;
    const int64_t max_;

public:
    BoundedCounter(int64_t min_val, int64_t max_val)
        : min_(min_val), max_(max_val) {}

    // 尝试增加，如果超过上限则失败
    bool try_increment() {
        int64_t current = count_.load(std::memory_order_relaxed);
        while (current < max_) {
            if (count_.compare_exchange_weak(current, current + 1,
                    std::memory_order_relaxed)) {
                return true;
            }
        }
        return false;
    }

    // 尝试减少，如果低于下限则失败
    bool try_decrement() {
        int64_t current = count_.load(std::memory_order_relaxed);
        while (current > min_) {
            if (count_.compare_exchange_weak(current, current - 1,
                    std::memory_order_relaxed)) {
                return true;
            }
        }
        return false;
    }

    // 尝试增加指定数量
    bool try_add(int64_t delta) {
        int64_t current = count_.load(std::memory_order_relaxed);
        while (current + delta <= max_ && current + delta >= min_) {
            if (count_.compare_exchange_weak(current, current + delta,
                    std::memory_order_relaxed)) {
                return true;
            }
        }
        return false;
    }

    int64_t get() const {
        return count_.load(std::memory_order_relaxed);
    }
};

// ==================== 2. 原子最小/最大值追踪器 ====================

class MinMaxTracker {
    std::atomic<int64_t> min_{std::numeric_limits<int64_t>::max()};
    std::atomic<int64_t> max_{std::numeric_limits<int64_t>::min()};

public:
    void observe(int64_t value) {
        // 更新最小值
        int64_t current_min = min_.load(std::memory_order_relaxed);
        while (value < current_min) {
            if (min_.compare_exchange_weak(current_min, value,
                    std::memory_order_relaxed)) {
                break;
            }
        }

        // 更新最大值
        int64_t current_max = max_.load(std::memory_order_relaxed);
        while (value > current_max) {
            if (max_.compare_exchange_weak(current_max, value,
                    std::memory_order_relaxed)) {
                break;
            }
        }
    }

    std::pair<int64_t, int64_t> get() const {
        return {min_.load(std::memory_order_relaxed),
                max_.load(std::memory_order_relaxed)};
    }

    void reset() {
        min_.store(std::numeric_limits<int64_t>::max(), std::memory_order_relaxed);
        max_.store(std::numeric_limits<int64_t>::min(), std::memory_order_relaxed);
    }
};

// ==================== 3. 状态机（原子状态转换）====================

enum class State { IDLE, STARTING, RUNNING, STOPPING, STOPPED };

class AtomicStateMachine {
    std::atomic<State> state_{State::IDLE};

public:
    // 尝试从某个状态转换到另一个状态
    bool transition(State from, State to) {
        return state_.compare_exchange_strong(from, to,
            std::memory_order_acq_rel,
            std::memory_order_acquire);
    }

    // 尝试从多个可能的状态转换
    bool transition_from_any_of(std::initializer_list<State> from_states, State to) {
        for (State from : from_states) {
            State expected = from;
            if (state_.compare_exchange_strong(expected, to,
                    std::memory_order_acq_rel,
                    std::memory_order_acquire)) {
                return true;
            }
        }
        return false;
    }

    State get() const {
        return state_.load(std::memory_order_acquire);
    }

    // 等待特定状态
    void wait_for(State target) const {
        while (state_.load(std::memory_order_acquire) != target) {
            std::this_thread::yield();
        }
    }
};

// ==================== 4. 乐观锁（版本号）====================

template <typename T>
class OptimisticLock {
    struct VersionedData {
        T data;
        uint64_t version;
    };

    std::atomic<uint64_t> version_{0};
    T data_;
    mutable std::atomic<bool> locked_{false};

public:
    explicit OptimisticLock(T initial) : data_(std::move(initial)) {}

    // 读取数据和版本号
    std::pair<T, uint64_t> read() const {
        uint64_t v1, v2;
        T result;

        do {
            // 等待写锁释放
            while (locked_.load(std::memory_order_acquire)) {
                std::this_thread::yield();
            }

            v1 = version_.load(std::memory_order_acquire);
            result = data_;  // 复制数据
            std::atomic_thread_fence(std::memory_order_acquire);
            v2 = version_.load(std::memory_order_relaxed);

            // 如果版本号变化或写锁被持有，重试
        } while (v1 != v2 || (v1 & 1));  // 奇数版本号表示正在写

        return {result, v1};
    }

    // 验证版本号是否仍然有效
    bool validate(uint64_t version) const {
        std::atomic_thread_fence(std::memory_order_acquire);
        return version_.load(std::memory_order_relaxed) == version
               && !locked_.load(std::memory_order_relaxed);
    }

    // 尝试更新（需要先读取获得版本号）
    bool try_update(const T& new_data, uint64_t expected_version) {
        // 获取写锁
        bool expected_locked = false;
        if (!locked_.compare_exchange_strong(expected_locked, true,
                std::memory_order_acquire)) {
            return false;
        }

        // 检查版本号
        if (version_.load(std::memory_order_relaxed) != expected_version) {
            locked_.store(false, std::memory_order_release);
            return false;
        }

        // 增加版本号（变为奇数，表示正在写）
        version_.fetch_add(1, std::memory_order_relaxed);

        // 更新数据
        data_ = new_data;

        // 增加版本号（变为偶数，写入完成）
        version_.fetch_add(1, std::memory_order_release);

        // 释放写锁
        locked_.store(false, std::memory_order_release);

        return true;
    }
};

// ==================== 5. 一次性初始化（call_once替代）====================

template <typename T>
class OnceInit {
    std::atomic<T*> ptr_{nullptr};
    std::atomic<bool> initializing_{false};

public:
    template <typename Factory>
    T* get_or_init(Factory&& factory) {
        // 快速路径：已经初始化
        T* p = ptr_.load(std::memory_order_acquire);
        if (p != nullptr) {
            return p;
        }

        // 慢速路径：尝试初始化
        bool expected = false;
        if (initializing_.compare_exchange_strong(expected, true,
                std::memory_order_acquire)) {
            // 我们负责初始化
            T* new_ptr = factory();
            ptr_.store(new_ptr, std::memory_order_release);
            return new_ptr;
        }

        // 其他线程正在初始化，等待
        while ((p = ptr_.load(std::memory_order_acquire)) == nullptr) {
            std::this_thread::yield();
        }
        return p;
    }

    ~OnceInit() {
        delete ptr_.load(std::memory_order_relaxed);
    }
};
```

**Day 1-2 检验标准**：
- [ ] 能够实现有界计数器
- [ ] 理解原子状态机的转换模式
- [ ] 能够实现乐观锁
- [ ] 理解一次性初始化的无锁实现

---

#### 📅 Day 3-4: 无锁栈（Treiber Stack）实现

**学习目标**：
- [ ] 理解Treiber Stack的原理
- [ ] 实现基本的无锁栈
- [ ] 认识ABA问题在无锁栈中的表现

#### 无锁单例
```cpp
template <typename T>
class LockFreeSingleton {
    static std::atomic<T*> instance_;

public:
    static T* get() {
        T* ptr = instance_.load(std::memory_order_acquire);
        if (ptr == nullptr) {
            T* new_instance = new T();
            if (!instance_.compare_exchange_strong(ptr, new_instance,
                    std::memory_order_release,
                    std::memory_order_acquire)) {
                // 其他线程先创建了，删除我们的
                delete new_instance;
                // ptr已被更新为其他线程创建的实例
            } else {
                ptr = new_instance;
            }
        }
        return ptr;
    }
};

template <typename T>
std::atomic<T*> LockFreeSingleton<T>::instance_{nullptr};
```

#### 🔬 深入理解：Treiber Stack完整实现
```cpp
#include <atomic>
#include <memory>
#include <optional>
#include <iostream>

// ==================== 基础Treiber Stack ====================

template <typename T>
class TreiberStack {
    struct Node {
        T data;
        Node* next;

        template <typename... Args>
        explicit Node(Args&&... args)
            : data(std::forward<Args>(args)...), next(nullptr) {}
    };

    std::atomic<Node*> head_{nullptr};

public:
    ~TreiberStack() {
        while (pop()) {}
    }

    // 禁止拷贝
    TreiberStack(const TreiberStack&) = delete;
    TreiberStack& operator=(const TreiberStack&) = delete;
    TreiberStack() = default;

    // 入栈
    void push(T value) {
        Node* new_node = new Node(std::move(value));

        // CAS循环：将new_node设为新的head
        new_node->next = head_.load(std::memory_order_relaxed);
        while (!head_.compare_exchange_weak(
                new_node->next,  // expected：当前head
                new_node,        // desired：新head
                std::memory_order_release,
                std::memory_order_relaxed)) {
            // new_node->next已被更新为当前head，重试
        }
    }

    // 出栈（有ABA问题！）
    std::optional<T> pop() {
        Node* old_head = head_.load(std::memory_order_relaxed);

        while (old_head != nullptr) {
            // 危险：在这里可能发生ABA问题
            // 1. 读取old_head->next
            // 2. 其他线程pop了old_head和下一个节点
            // 3. 其他线程push了一个新节点，恰好使用了old_head的地址
            // 4. CAS成功，但head变成了被释放的节点

            Node* new_head = old_head->next;

            if (head_.compare_exchange_weak(
                    old_head,   // expected
                    new_head,   // desired
                    std::memory_order_acquire,
                    std::memory_order_relaxed)) {
                T result = std::move(old_head->data);
                delete old_head;  // 这里可能删除正在被其他线程使用的节点！
                return result;
            }
            // old_head已被更新，重试
        }
        return std::nullopt;  // 栈空
    }

    bool empty() const {
        return head_.load(std::memory_order_relaxed) == nullptr;
    }
};

// ==================== 演示ABA问题 ====================

/*
ABA问题场景（时间线）：

初始状态：head -> A -> B -> C

Thread 1:
  1. old_head = A
  2. new_head = A->next = B
  3. [被挂起]

Thread 2:
  4. pop() -> 得到A，delete A
  5. pop() -> 得到B，delete B
  6. push(D) -> D恰好分配在A的原地址
  7. 现在 head -> D -> C

Thread 1 恢复:
  8. CAS(&head, A, B) -> 成功！（因为D的地址==A的旧地址）
  9. 现在 head -> B，但B已经被delete了！

结果：程序崩溃或未定义行为
*/

// ==================== 简单的缓解方案：延迟删除 ====================

template <typename T>
class TreiberStackWithRetiredList {
    struct Node {
        T data;
        std::atomic<Node*> next;

        template <typename... Args>
        explicit Node(Args&&... args)
            : data(std::forward<Args>(args)...), next(nullptr) {}
    };

    std::atomic<Node*> head_{nullptr};

    // 退役节点列表（简单但不完美的方案）
    std::atomic<Node*> retired_head_{nullptr};
    std::atomic<int> active_threads_{0};

public:
    class Guard {
        TreiberStackWithRetiredList& stack_;
    public:
        explicit Guard(TreiberStackWithRetiredList& s) : stack_(s) {
            stack_.active_threads_.fetch_add(1, std::memory_order_relaxed);
        }
        ~Guard() {
            if (stack_.active_threads_.fetch_sub(1, std::memory_order_acq_rel) == 1) {
                // 最后一个活跃线程，尝试清理退役列表
                stack_.try_cleanup();
            }
        }
    };

    void push(T value) {
        Node* new_node = new Node(std::move(value));
        new_node->next.store(head_.load(std::memory_order_relaxed),
                             std::memory_order_relaxed);
        while (!head_.compare_exchange_weak(
                new_node->next,
                new_node,
                std::memory_order_release,
                std::memory_order_relaxed)) {}
    }

    std::optional<T> pop() {
        Guard guard(*this);  // RAII保护

        Node* old_head = head_.load(std::memory_order_relaxed);

        while (old_head != nullptr) {
            Node* new_head = old_head->next.load(std::memory_order_relaxed);

            if (head_.compare_exchange_weak(old_head, new_head,
                    std::memory_order_acquire,
                    std::memory_order_relaxed)) {
                T result = std::move(old_head->data);
                retire(old_head);  // 不直接delete，而是加入退役列表
                return result;
            }
        }
        return std::nullopt;
    }

private:
    void retire(Node* node) {
        // 将节点加入退役列表
        node->next.store(retired_head_.load(std::memory_order_relaxed),
                        std::memory_order_relaxed);
        while (!retired_head_.compare_exchange_weak(
                node->next,
                node,
                std::memory_order_release,
                std::memory_order_relaxed)) {}
    }

    void try_cleanup() {
        // 只有当没有活跃线程时才清理
        if (active_threads_.load(std::memory_order_acquire) != 0) {
            return;
        }

        Node* list = retired_head_.exchange(nullptr, std::memory_order_acquire);
        while (list != nullptr) {
            Node* next = list->next.load(std::memory_order_relaxed);
            delete list;
            list = next;
        }
    }
};

// ==================== 使用示例 ====================

void test_treiber_stack() {
    TreiberStack<int> stack;
    const int num_threads = 4;
    const int ops_per_thread = 10000;

    std::vector<std::thread> threads;

    // 生产者线程
    for (int i = 0; i < num_threads / 2; ++i) {
        threads.emplace_back([&stack, i, ops_per_thread]() {
            for (int j = 0; j < ops_per_thread; ++j) {
                stack.push(i * ops_per_thread + j);
            }
        });
    }

    // 消费者线程
    std::atomic<int> pop_count{0};
    for (int i = 0; i < num_threads / 2; ++i) {
        threads.emplace_back([&stack, &pop_count, ops_per_thread]() {
            for (int j = 0; j < ops_per_thread; ++j) {
                while (!stack.pop()) {
                    std::this_thread::yield();
                }
                pop_count.fetch_add(1, std::memory_order_relaxed);
            }
        });
    }

    for (auto& t : threads) {
        t.join();
    }

    std::cout << "Popped " << pop_count.load() << " items\n";
}
```

**Day 3-4 检验标准**：
- [ ] 理解Treiber Stack的push/pop实现
- [ ] 能够解释ABA问题在栈中的具体表现
- [ ] 理解延迟删除的基本思想
- [ ] 完成无锁栈的测试

---

#### 📅 Day 5-6: 性能基准测试与优化

**学习目标**：
- [ ] 学习如何对原子操作进行基准测试
- [ ] 理解各种实现的性能特征
- [ ] 掌握性能优化技巧

#### 🔬 综合性能基准测试
```cpp
// cas_benchmark.cpp
#include <atomic>
#include <thread>
#include <vector>
#include <chrono>
#include <iostream>
#include <iomanip>
#include <functional>
#include <mutex>

// ==================== 基准测试框架 ====================

class Benchmark {
public:
    struct Result {
        std::string name;
        double ops_per_second;
        double avg_latency_ns;
        long long total_ops;
        long long duration_ms;
    };

    template <typename Func>
    static Result run(const std::string& name, Func&& func,
                      int num_threads, int ops_per_thread) {
        auto start = std::chrono::high_resolution_clock::now();

        std::vector<std::thread> threads;
        for (int i = 0; i < num_threads; ++i) {
            threads.emplace_back([&func, ops_per_thread]() {
                for (int j = 0; j < ops_per_thread; ++j) {
                    func();
                }
            });
        }

        for (auto& t : threads) {
            t.join();
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto duration_ns = std::chrono::duration_cast<std::chrono::nanoseconds>(end - start).count();

        long long total_ops = static_cast<long long>(num_threads) * ops_per_thread;
        double duration_sec = duration_ns / 1e9;
        double ops_per_sec = total_ops / duration_sec;
        double avg_latency = static_cast<double>(duration_ns) / total_ops;

        return {name, ops_per_sec, avg_latency, total_ops,
                static_cast<long long>(duration_ns / 1e6)};
    }

    static void print_results(const std::vector<Result>& results) {
        std::cout << "\n";
        std::cout << std::setw(30) << "Benchmark"
                  << std::setw(15) << "Ops/sec"
                  << std::setw(15) << "Latency(ns)"
                  << std::setw(12) << "Total Ops"
                  << std::setw(10) << "Time(ms)" << "\n";
        std::cout << std::string(82, '-') << "\n";

        for (const auto& r : results) {
            std::cout << std::setw(30) << r.name
                      << std::setw(15) << std::fixed << std::setprecision(0) << r.ops_per_second
                      << std::setw(15) << std::fixed << std::setprecision(1) << r.avg_latency_ns
                      << std::setw(12) << r.total_ops
                      << std::setw(10) << r.duration_ms << "\n";
        }
    }
};

// ==================== 测试不同的计数器实现 ====================

// 1. 互斥锁保护的计数器
class MutexCounter {
    int64_t count_{0};
    mutable std::mutex mutex_;
public:
    void increment() {
        std::lock_guard<std::mutex> lock(mutex_);
        ++count_;
    }
    int64_t get() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return count_;
    }
};

// 2. 原子计数器（fetch_add）
class AtomicCounter {
    std::atomic<int64_t> count_{0};
public:
    void increment() {
        count_.fetch_add(1, std::memory_order_relaxed);
    }
    int64_t get() const {
        return count_.load(std::memory_order_relaxed);
    }
};

// 3. CAS循环计数器
class CASCounter {
    std::atomic<int64_t> count_{0};
public:
    void increment() {
        int64_t expected = count_.load(std::memory_order_relaxed);
        while (!count_.compare_exchange_weak(expected, expected + 1,
                std::memory_order_relaxed)) {}
    }
    int64_t get() const {
        return count_.load(std::memory_order_relaxed);
    }
};

// 4. 分片计数器
template <size_t NumShards = 16>
class ShardedCounter {
    struct alignas(64) Shard {
        std::atomic<int64_t> count{0};
    };
    std::array<Shard, NumShards> shards_;

public:
    void increment() {
        static thread_local size_t shard =
            std::hash<std::thread::id>{}(std::this_thread::get_id()) % NumShards;
        shards_[shard].count.fetch_add(1, std::memory_order_relaxed);
    }
    int64_t get() const {
        int64_t sum = 0;
        for (const auto& s : shards_) {
            sum += s.count.load(std::memory_order_relaxed);
        }
        return sum;
    }
};

// ==================== 运行基准测试 ====================

void run_counter_benchmarks() {
    const int num_threads = 8;
    const int ops_per_thread = 1000000;

    std::vector<Benchmark::Result> results;

    // 测试互斥锁
    {
        MutexCounter counter;
        results.push_back(Benchmark::run("Mutex Counter",
            [&counter]() { counter.increment(); },
            num_threads, ops_per_thread));
    }

    // 测试原子计数器
    {
        AtomicCounter counter;
        results.push_back(Benchmark::run("Atomic (fetch_add)",
            [&counter]() { counter.increment(); },
            num_threads, ops_per_thread));
    }

    // 测试CAS循环
    {
        CASCounter counter;
        results.push_back(Benchmark::run("CAS Loop",
            [&counter]() { counter.increment(); },
            num_threads, ops_per_thread));
    }

    // 测试分片计数器
    {
        ShardedCounter<16> counter;
        results.push_back(Benchmark::run("Sharded (16)",
            [&counter]() { counter.increment(); },
            num_threads, ops_per_thread));
    }

    std::cout << "=== Counter Benchmarks (" << num_threads << " threads) ===" << std::endl;
    Benchmark::print_results(results);
}

// ==================== 测试不同内存序的性能 ====================

void run_memory_order_benchmarks() {
    const int num_threads = 4;
    const int ops_per_thread = 5000000;

    std::vector<Benchmark::Result> results;

    // Relaxed
    {
        std::atomic<int64_t> counter{0};
        results.push_back(Benchmark::run("fetch_add relaxed",
            [&counter]() { counter.fetch_add(1, std::memory_order_relaxed); },
            num_threads, ops_per_thread));
    }

    // Acquire-Release
    {
        std::atomic<int64_t> counter{0};
        results.push_back(Benchmark::run("fetch_add acq_rel",
            [&counter]() { counter.fetch_add(1, std::memory_order_acq_rel); },
            num_threads, ops_per_thread));
    }

    // Sequential Consistency
    {
        std::atomic<int64_t> counter{0};
        results.push_back(Benchmark::run("fetch_add seq_cst",
            [&counter]() { counter.fetch_add(1, std::memory_order_seq_cst); },
            num_threads, ops_per_thread));
    }

    std::cout << "\n=== Memory Order Benchmarks ===" << std::endl;
    Benchmark::print_results(results);
}

// ==================== 测试CAS weak vs strong ====================

void run_cas_benchmarks() {
    const int num_threads = 4;
    const int ops_per_thread = 1000000;

    std::vector<Benchmark::Result> results;

    // CAS weak
    {
        std::atomic<int64_t> counter{0};
        results.push_back(Benchmark::run("CAS weak",
            [&counter]() {
                int64_t expected = counter.load(std::memory_order_relaxed);
                while (!counter.compare_exchange_weak(expected, expected + 1,
                        std::memory_order_relaxed)) {}
            },
            num_threads, ops_per_thread));
    }

    // CAS strong
    {
        std::atomic<int64_t> counter{0};
        results.push_back(Benchmark::run("CAS strong",
            [&counter]() {
                int64_t expected = counter.load(std::memory_order_relaxed);
                while (!counter.compare_exchange_strong(expected, expected + 1,
                        std::memory_order_relaxed)) {}
            },
            num_threads, ops_per_thread));
    }

    std::cout << "\n=== CAS Weak vs Strong ===" << std::endl;
    Benchmark::print_results(results);
}

// ==================== 测试自旋锁 ====================

void run_spinlock_benchmarks() {
    const int num_threads = 4;
    const int ops_per_thread = 100000;

    std::vector<Benchmark::Result> results;

    // TAS自旋锁
    {
        std::atomic<bool> lock{false};
        int64_t counter = 0;

        results.push_back(Benchmark::run("TAS SpinLock",
            [&lock, &counter]() {
                while (lock.exchange(true, std::memory_order_acquire)) {}
                ++counter;
                lock.store(false, std::memory_order_release);
            },
            num_threads, ops_per_thread));
    }

    // TTAS自旋锁
    {
        std::atomic<bool> lock{false};
        int64_t counter = 0;

        results.push_back(Benchmark::run("TTAS SpinLock",
            [&lock, &counter]() {
                while (true) {
                    while (lock.load(std::memory_order_relaxed)) {}
                    if (!lock.exchange(true, std::memory_order_acquire)) break;
                }
                ++counter;
                lock.store(false, std::memory_order_release);
            },
            num_threads, ops_per_thread));
    }

    // std::mutex
    {
        std::mutex mtx;
        int64_t counter = 0;

        results.push_back(Benchmark::run("std::mutex",
            [&mtx, &counter]() {
                std::lock_guard<std::mutex> guard(mtx);
                ++counter;
            },
            num_threads, ops_per_thread));
    }

    std::cout << "\n=== SpinLock Benchmarks ===" << std::endl;
    Benchmark::print_results(results);
}

// ==================== 主函数 ====================

int main() {
    std::cout << "Hardware concurrency: " << std::thread::hardware_concurrency() << "\n";

    run_counter_benchmarks();
    run_memory_order_benchmarks();
    run_cas_benchmarks();
    run_spinlock_benchmarks();

    return 0;
}

/*
预期结果分析：

1. Counter Benchmarks:
   - Sharded Counter 应该最快（无竞争）
   - Atomic (fetch_add) 次之
   - CAS Loop 因竞争重试会更慢
   - Mutex Counter 最慢（系统调用开销）

2. Memory Order:
   - 在x86上，三种内存序性能可能相近
   - 在ARM上，seq_cst可能明显更慢

3. CAS Weak vs Strong:
   - 在x86上性能相同
   - 在ARM上weak可能更快

4. SpinLock:
   - TTAS通常比TAS好
   - std::mutex在低竞争时可能最好（能休眠）
*/
```

**Day 5-6 检验标准**：
- [ ] 能够设计和实现基准测试框架
- [ ] 理解不同实现的性能特征
- [ ] 能够分析基准测试结果
- [ ] 知道性能优化的方向

---

#### 📅 Day 7: 月度总结与项目整合

**本月完整知识图谱**：
```
Month 15: 原子操作与CAS
│
├── Week 1: 原子操作基础
│   ├── std::atomic API
│   │   ├── load/store/exchange
│   │   ├── fetch_add/sub/and/or/xor
│   │   └── 运算符重载
│   ├── atomic_flag
│   │   └── 自旋锁实现
│   └── Lock-free属性
│       ├── is_always_lock_free
│       └── 硬件支持分析
│
├── Week 2: CAS深度
│   ├── 基本语义
│   │   ├── compare_exchange_strong/weak
│   │   └── expected参数更新机制
│   ├── Spurious Failure
│   │   ├── LL/SC架构原理
│   │   └── 选择决策树
│   ├── CAS循环模式
│   │   ├── 标准模板
│   │   └── 退避策略
│   └── ABA问题初探
│
├── Week 3: 高级操作
│   ├── Fetch操作详解
│   │   ├── 性能优势
│   │   └── 实际应用
│   ├── 自旋锁变体
│   │   ├── TAS / TTAS
│   │   ├── Ticket Lock
│   │   └── MCS Lock
│   └── 内存栅栏
│       ├── atomic_thread_fence
│       └── atomic_signal_fence
│
└── Week 4: 应用模式
    ├── 无锁模式
    │   ├── 有界计数器
    │   ├── 状态机
    │   ├── 乐观锁
    │   └── 一次性初始化
    ├── Treiber Stack
    │   ├── 实现原理
    │   └── ABA问题演示
    └── 性能基准测试
        └── 对比分析
```

**月度综合检验**：

知识检验问题：
- [ ] compare_exchange_weak和strong的区别是什么？
- [ ] 为什么CAS循环中通常使用weak？
- [ ] fetch_add和CAS循环实现加法有什么区别？
- [ ] LL/SC架构是什么？为什么会有虚假失败？
- [ ] 双字CAS的用途是什么？
- [ ] 什么是ABA问题？如何缓解？
- [ ] 内存栅栏和原子操作的内存序有什么区别？

实践检验：
- [ ] 无锁栈的push和pop正确工作
- [ ] 原子操作的内存序选择正确
- [ ] 基准测试展示不同方法的性能差异
- [ ] 各种自旋锁实现能够正确工作

**输出物清单**：
1. `lockfree_stack.hpp` - 无锁栈实现
2. `atomic_shared_ptr.hpp` - 原子shared_ptr包装
3. `dcas.hpp` - 双字CAS实现
4. `cas_benchmark.cpp` - 综合性能基准测试
5. `spinlocks.hpp` - 各种自旋锁实现
6. `atomic_patterns.hpp` - 常用原子模式（计数器、状态机等）
7. `notes/month15_atomic_cas.md` - 学习笔记

**第四周检验清单**：
- [ ] 能够实现各种无锁模式
- [ ] 理解Treiber Stack的原理和问题
- [ ] 能够设计和运行性能基准测试
- [ ] 完成所有输出物
- [ ] 能够回答：
  - 无锁单例如何处理竞态条件？
  - Treiber Stack中ABA问题如何产生？
  - 分片计数器为什么能提升性能？

---

## 源码阅读任务

### 深度阅读清单

- [ ] GCC/Clang的`__atomic_*`内置函数
- [ ] x86的`LOCK`前缀指令
- [ ] ARM的`LDREX/STREX`和`LDADD`等指令
- [ ] folly/AtomicHashMap的CAS使用

---

## 实践项目

### 项目：无锁数据结构基础

#### Part 1: 无锁栈（Treiber Stack）
```cpp
// lockfree_stack.hpp
#pragma once
#include <atomic>
#include <memory>
#include <optional>

template <typename T>
class LockFreeStack {
    struct Node {
        T data;
        Node* next;

        template <typename... Args>
        Node(Args&&... args) : data(std::forward<Args>(args)...), next(nullptr) {}
    };

    std::atomic<Node*> head_{nullptr};

public:
    ~LockFreeStack() {
        while (pop()) {}
    }

    void push(T value) {
        Node* new_node = new Node(std::move(value));
        new_node->next = head_.load(std::memory_order_relaxed);
        while (!head_.compare_exchange_weak(new_node->next, new_node,
                std::memory_order_release,
                std::memory_order_relaxed)) {
            // new_node->next已被更新为当前head
        }
    }

    std::optional<T> pop() {
        Node* old_head = head_.load(std::memory_order_relaxed);
        while (old_head != nullptr) {
            if (head_.compare_exchange_weak(old_head, old_head->next,
                    std::memory_order_acquire,
                    std::memory_order_relaxed)) {
                T value = std::move(old_head->data);
                delete old_head;  // 危险！其他线程可能正在读取
                return value;
            }
        }
        return std::nullopt;
    }

    bool empty() const {
        return head_.load(std::memory_order_relaxed) == nullptr;
    }
};

// 注意：上面的实现有ABA问题和内存回收问题
// 下个月会学习如何解决
```

#### Part 2: 原子指针包装器
```cpp
// atomic_shared_ptr.hpp
#pragma once
#include <atomic>
#include <memory>

// 简化版原子shared_ptr（C++20有std::atomic<std::shared_ptr<T>>）
template <typename T>
class AtomicSharedPtr {
    // 使用tagged pointer或分离计数方案
    // 这里使用简化的自旋锁方案

    std::atomic<std::shared_ptr<T>*> ptr_{nullptr};
    mutable std::atomic_flag lock_ = ATOMIC_FLAG_INIT;

    void acquire_lock() const {
        while (lock_.test_and_set(std::memory_order_acquire)) {
            // 自旋
        }
    }

    void release_lock() const {
        lock_.clear(std::memory_order_release);
    }

public:
    AtomicSharedPtr() = default;

    explicit AtomicSharedPtr(std::shared_ptr<T> ptr) {
        store(std::move(ptr));
    }

    ~AtomicSharedPtr() {
        auto p = ptr_.load(std::memory_order_relaxed);
        if (p) delete p;
    }

    std::shared_ptr<T> load() const {
        acquire_lock();
        auto p = ptr_.load(std::memory_order_relaxed);
        std::shared_ptr<T> result = p ? *p : nullptr;
        release_lock();
        return result;
    }

    void store(std::shared_ptr<T> desired) {
        auto new_ptr = new std::shared_ptr<T>(std::move(desired));
        acquire_lock();
        auto old = ptr_.exchange(new_ptr, std::memory_order_relaxed);
        release_lock();
        if (old) delete old;
    }

    std::shared_ptr<T> exchange(std::shared_ptr<T> desired) {
        auto new_ptr = new std::shared_ptr<T>(std::move(desired));
        acquire_lock();
        auto old = ptr_.exchange(new_ptr, std::memory_order_relaxed);
        std::shared_ptr<T> result = old ? std::move(*old) : nullptr;
        release_lock();
        if (old) delete old;
        return result;
    }

    bool compare_exchange_strong(std::shared_ptr<T>& expected,
                                  std::shared_ptr<T> desired) {
        acquire_lock();
        auto p = ptr_.load(std::memory_order_relaxed);
        std::shared_ptr<T> current = p ? *p : nullptr;

        if (current == expected) {
            auto new_ptr = new std::shared_ptr<T>(std::move(desired));
            ptr_.store(new_ptr, std::memory_order_relaxed);
            release_lock();
            if (p) delete p;
            return true;
        } else {
            expected = current;
            release_lock();
            return false;
        }
    }
};
```

#### Part 3: 双字CAS（DCAS）模拟
```cpp
// dcas.hpp
#pragma once
#include <atomic>
#include <cstdint>

// 在64位系统上，可以用128位CAS
// 在32位系统上，可以用64位CAS
// 这里演示64位系统的实现

struct alignas(16) DoubleWord {
    void* ptr;
    uint64_t counter;

    bool operator==(const DoubleWord& other) const {
        return ptr == other.ptr && counter == other.counter;
    }
};

// 检查平台是否支持
static_assert(sizeof(DoubleWord) == 16, "DoubleWord must be 16 bytes");

class AtomicDoubleWord {
    // 注意：需要16字节对齐
    alignas(16) DoubleWord data_{nullptr, 0};

public:
    DoubleWord load() const {
        DoubleWord result;
        #if defined(__x86_64__) || defined(_M_X64)
        // x86-64: 使用CMPXCHG16B
        __atomic_load(&data_, &result, __ATOMIC_SEQ_CST);
        #elif defined(__aarch64__)
        // ARM64: 使用LDAXP/STLXP
        __atomic_load(&data_, &result, __ATOMIC_SEQ_CST);
        #else
        #error "Platform not supported"
        #endif
        return result;
    }

    void store(DoubleWord desired) {
        #if defined(__x86_64__) || defined(_M_X64)
        __atomic_store(&data_, &desired, __ATOMIC_SEQ_CST);
        #elif defined(__aarch64__)
        __atomic_store(&data_, &desired, __ATOMIC_SEQ_CST);
        #endif
    }

    bool compare_exchange_strong(DoubleWord& expected, DoubleWord desired) {
        #if defined(__x86_64__) || defined(_M_X64)
        return __atomic_compare_exchange(&data_, &expected, &desired,
                                         false, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST);
        #elif defined(__aarch64__)
        return __atomic_compare_exchange(&data_, &expected, &desired,
                                         false, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST);
        #endif
    }
};
```

#### Part 4: CAS性能基准测试
```cpp
// cas_benchmark.cpp
#include <atomic>
#include <thread>
#include <vector>
#include <chrono>
#include <iostream>

std::atomic<int> counter{0};

void bench_fetch_add(int iterations) {
    for (int i = 0; i < iterations; ++i) {
        counter.fetch_add(1, std::memory_order_relaxed);
    }
}

void bench_cas_loop(int iterations) {
    for (int i = 0; i < iterations; ++i) {
        int expected = counter.load(std::memory_order_relaxed);
        while (!counter.compare_exchange_weak(expected, expected + 1,
                std::memory_order_relaxed)) {
        }
    }
}

void bench_cas_strong(int iterations) {
    for (int i = 0; i < iterations; ++i) {
        int expected = counter.load(std::memory_order_relaxed);
        while (!counter.compare_exchange_strong(expected, expected + 1,
                std::memory_order_relaxed)) {
        }
    }
}

template <typename Func>
void run_benchmark(const char* name, Func f, int threads, int iterations) {
    counter = 0;
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

    std::cout << name << ": " << duration.count() << " ms"
              << ", counter = " << counter
              << " (expected: " << threads * iterations << ")\n";
}

int main() {
    const int threads = 4;
    const int iterations = 1000000;

    std::cout << "Running with " << threads << " threads, "
              << iterations << " iterations each\n\n";

    run_benchmark("fetch_add", bench_fetch_add, threads, iterations);
    run_benchmark("CAS weak", bench_cas_loop, threads, iterations);
    run_benchmark("CAS strong", bench_cas_strong, threads, iterations);

    return 0;
}
```

---

## 检验标准

### 知识检验
- [ ] compare_exchange_weak和strong的区别是什么？
- [ ] 为什么CAS循环中通常使用weak？
- [ ] fetch_add和CAS循环实现加法有什么区别？
- [ ] LL/SC架构是什么？为什么会有虚假失败？
- [ ] 双字CAS的用途是什么？

### 实践检验
- [ ] 无锁栈的push和pop正确工作
- [ ] 原子操作的内存序选择正确
- [ ] 基准测试展示不同方法的性能差异

### 输出物
1. `lockfree_stack.hpp`
2. `atomic_shared_ptr.hpp`
3. `dcas.hpp`
4. `cas_benchmark.cpp`
5. `notes/month15_atomic_cas.md`

---

## 时间分配（140小时/月）

| 内容 | 时间 | 占比 |
|------|------|------|
| 理论学习 | 35小时 | 25% |
| 源码阅读 | 25小时 | 18% |
| 无锁数据结构实现 | 45小时 | 32% |
| 基准测试 | 20小时 | 14% |
| 笔记与文档 | 15小时 | 11% |

---

## 下月预告

Month 16将学习**ABA问题与内存回收**，这是无锁编程中最棘手的问题。我们将学习危险指针、Epoch-based回收和引用计数等解决方案。
