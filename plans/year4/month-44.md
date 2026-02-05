# Month 44: Sanitizers——运行时错误检测利器

## 本月主题概述

本月深入学习编译器内置的Sanitizers工具：AddressSanitizer（ASan）、ThreadSanitizer（TSan）、UndefinedBehaviorSanitizer（UBSan）和MemorySanitizer（MSan）。这些工具能够在运行时检测内存错误、数据竞争和未定义行为。

**学习目标**：
- 掌握各种Sanitizer的使用方法和适用场景
- 理解Sanitizer的工作原理
- 学会在CI/CD中集成Sanitizer测试
- 能够分析和修复Sanitizer报告的问题

---

## 理论学习内容

### 第一周：AddressSanitizer（ASan）

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Week 1: AddressSanitizer（ASan）内存错误检测               │
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │  Day 1-2    │───▶│  Day 3-4    │───▶│  Day 5-6    │───▶│   Day 7     │  │
│  │ Sanitizer   │    │ ASan编译与  │    │ 9大错误类型 │    │ 报告解读    │  │
│  │ 概述与原理  │    │ Shadow内存  │    │ 实战检测    │    │ 源码阅读    │  │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘  │
│                                                                             │
│  核心技能：                                                                  │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │ • Sanitizer家族概览（ASan/TSan/UBSan/MSan的定位与互斥关系）          │ │
│  │ • ASan插桩原理（编译时插桩 + Shadow Memory映射）                     │ │
│  │ • 9大内存错误类型的触发、检测与修复                                  │ │
│  │ • ASan报告解读（错误类型/调用栈/分配信息/Shadow字节）               │ │
│  │ • ASAN_OPTIONS环境变量精细调控                                       │ │
│  │ • LeakSanitizer (LSan) 内存泄漏检测                                 │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
│  输出物：错误示例集 + 报告解读笔记 + ASan架构笔记         学习时间：35小时   │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Week 1 每日任务分解

| 天数 | 时间 | 主题 | 具体任务 | 输出物 |
|------|------|------|----------|--------|
| Day 1 | 5h | Sanitizer概述 | 1. 静态分析vs动态分析vs运行时检测 2. Sanitizer家族定位（ASan/TSan/UBSan/MSan） 3. 互斥关系与组合策略 4. 编译器支持（Clang/GCC差异） | notes/sanitizer_overview.md |
| Day 2 | 5h | ASan工作原理 | 1. 编译时插桩机制（每次内存访问前插入检查） 2. Shadow Memory映射原理（1:8映射） 3. Red Zone（毒化区域）机制 4. 运行时库替换（malloc/free拦截） | notes/asan_internals.md |
| Day 3 | 5h | ASan编译与配置 | 1. Clang/GCC编译选项详解 2. -fno-omit-frame-pointer作用 3. ASAN_OPTIONS完整参数表 4. 与调试器（gdb/lldb）配合 | practice/asan_basic/ |
| Day 4 | 5h | 堆内存错误 | 1. 堆缓冲区溢出（读/写） 2. 释放后使用（Use-after-free） 3. 双重释放（Double-free） 4. 堆-栈缓冲区溢出对比 | practice/heap_errors/ |
| Day 5 | 5h | 栈与全局错误 | 1. 栈缓冲区溢出 2. 全局缓冲区溢出 3. 返回后使用栈（Stack-use-after-return） 4. 作用域外使用（Stack-use-after-scope） | practice/stack_global_errors/ |
| Day 6 | 5h | LSan与高级检测 | 1. LeakSanitizer内存泄漏检测 2. 初始化顺序问题 3. ASan API（手动毒化/解毒） 4. 抑制文件（suppressions）编写 | practice/leak_detection/ |
| Day 7 | 5h | 报告解读与源码 | 1. ASan报告结构详解（5个部分） 2. llvm-symbolizer符号化 3. 阅读compiler-rt/lib/asan源码 4. Week 1总结 | notes/week1_asan.md |

---

**学习目标**：掌握内存错误检测

**阅读材料**：
- [ ] AddressSanitizer官方文档
- [ ] Google Testing Blog: ASan介绍
- [ ] LLVM ASan文档

**核心概念**：

```bash
# ==========================================
# 编译启用ASan
# ==========================================

# Clang
clang++ -fsanitize=address -fno-omit-frame-pointer -g source.cpp -o app

# GCC
g++ -fsanitize=address -fno-omit-frame-pointer -g source.cpp -o app

# CMake
cmake -B build -S . \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_CXX_FLAGS="-fsanitize=address -fno-omit-frame-pointer"

# 运行时选项
ASAN_OPTIONS=detect_leaks=1:halt_on_error=0 ./app

# 常用ASAN_OPTIONS
# detect_leaks=1        - 启用内存泄漏检测
# halt_on_error=0       - 遇到错误继续运行
# abort_on_error=1      - 遇到错误时abort
# print_stats=1         - 打印统计信息
# check_initialization_order=1 - 检测静态初始化顺序问题
# strict_string_checks=1      - 严格字符串检查
# detect_stack_use_after_return=1 - 检测返回后使用栈
```

**ASan能检测的错误类型**：

```cpp
// ==========================================
// 1. 堆缓冲区溢出 (Heap-buffer-overflow)
// ==========================================
void heap_buffer_overflow() {
    int* arr = new int[10];
    arr[10] = 42;  // 越界写入
    delete[] arr;
}

// ==========================================
// 2. 栈缓冲区溢出 (Stack-buffer-overflow)
// ==========================================
void stack_buffer_overflow() {
    int arr[10];
    arr[10] = 42;  // 越界写入
}

// ==========================================
// 3. 全局缓冲区溢出 (Global-buffer-overflow)
// ==========================================
int global_arr[10];
void global_buffer_overflow() {
    global_arr[10] = 42;  // 越界写入
}

// ==========================================
// 4. 释放后使用 (Use-after-free / Heap-use-after-free)
// ==========================================
void use_after_free() {
    int* p = new int(42);
    delete p;
    *p = 100;  // 释放后使用
}

// ==========================================
// 5. 返回后使用栈 (Stack-use-after-return)
// ==========================================
int* get_stack_ptr() {
    int local = 42;
    return &local;  // 返回局部变量地址
}

void stack_use_after_return() {
    int* p = get_stack_ptr();
    *p = 100;  // 使用已失效的栈地址
}

// ==========================================
// 6. 作用域外使用 (Stack-use-after-scope)
// ==========================================
void stack_use_after_scope() {
    int* p;
    {
        int local = 42;
        p = &local;
    }
    *p = 100;  // 局部变量已超出作用域
}

// ==========================================
// 7. 双重释放 (Double-free)
// ==========================================
void double_free() {
    int* p = new int(42);
    delete p;
    delete p;  // 再次释放
}

// ==========================================
// 8. 内存泄漏 (Memory leak) - LeakSanitizer
// ==========================================
void memory_leak() {
    int* p = new int(42);
    // 忘记 delete p;
}

// ==========================================
// 9. 初始化顺序错误 (Initialization order fiasco)
// ==========================================
// file1.cpp
extern int global_b;
int global_a = global_b + 1;  // global_b可能还未初始化

// file2.cpp
int global_b = 10;
```

**理解ASan报告**：

```
==12345==ERROR: AddressSanitizer: heap-buffer-overflow on address 0x602000000028 at pc 0x55555555518d bp 0x7fffffffe0a0 sp 0x7fffffffe098
WRITE of size 4 at 0x602000000028 thread T0
    #0 0x55555555518c in main /path/to/source.cpp:10:14
    #1 0x7ffff7a2d082 in __libc_start_main (/lib/x86_64-linux-gnu/libc.so.6+0x24082)
    #2 0x5555555550cd in _start (/path/to/app+0x10cd)

0x602000000028 is located 0 bytes to the right of 40-byte region [0x602000000000,0x602000000028)
allocated by thread T0 here:
    #0 0x7ffff7f3e587 in operator new[](unsigned long) (/lib/x86_64-linux-gnu/libasan.so.6+0xb2587)
    #1 0x555555555168 in main /path/to/source.cpp:8:18
    #2 0x7ffff7a2d082 in __libc_start_main (/lib/x86_64-linux-gnu/libc.so.6+0x24082)

SUMMARY: AddressSanitizer: heap-buffer-overflow /path/to/source.cpp:10:14 in main
```

#### ASan 工作原理深入

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    AddressSanitizer 内部工作原理                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  编译阶段（Instrumentation）                                                │
│  ┌─────────────────────────────────────────────────────────────────┐       │
│  │  源代码                          插桩后代码                      │       │
│  │  ────────                        ──────────                      │       │
│  │  *p = 42;           ───▶        if (IsPoisoned(p))              │       │
│  │                                    ReportError(p);              │       │
│  │                                  *p = 42;                       │       │
│  │                                                                  │       │
│  │  每次内存访问（load/store）前，编译器插入Shadow Memory检查代码   │       │
│  └─────────────────────────────────────────────────────────────────┘       │
│                                                                             │
│  Shadow Memory 映射（1字节Shadow ↔ 8字节Application）                       │
│  ┌─────────────────────────────────────────────────────────────────┐       │
│  │                                                                  │       │
│  │  Application Memory (用户内存)                                   │       │
│  │  ┌──┬──┬──┬──┬──┬──┬──┬──┐                                     │       │
│  │  │B0│B1│B2│B3│B4│B5│B6│B7│  8字节为一组                        │       │
│  │  └──┴──┴──┴──┴──┴──┴──┴──┘                                     │       │
│  │           │                                                      │       │
│  │           │  Shadow = (Addr >> 3) + Offset                       │       │
│  │           ▼                                                      │       │
│  │  Shadow Memory (影子内存)                                        │       │
│  │  ┌────────────┐                                                  │       │
│  │  │  1字节     │                                                  │       │
│  │  └────────────┘                                                  │       │
│  │                                                                  │       │
│  │  Shadow值含义:                                                   │       │
│  │  ┌──────────────────────────────────────────────────┐           │       │
│  │  │ 0x00:  8字节全部可访问                           │           │       │
│  │  │ 0x01-0x07: 前k字节可访问，后(8-k)字节不可访问   │           │       │
│  │  │ 0xfa:  栈Red Zone左侧                           │           │       │
│  │  │ 0xfb:  栈Red Zone中间                           │           │       │
│  │  │ 0xfc:  栈Red Zone右侧                           │           │       │
│  │  │ 0xfd:  已释放的堆内存 (freed)                   │           │       │
│  │  │ 0xfe:  栈变量作用域外                            │           │       │
│  │  │ 0xf1:  栈Red Zone（局部变量间）                  │           │       │
│  │  │ 0xf2:  栈Red Zone（局部变量后）                  │           │       │
│  │  │ 0xf3:  全局变量Red Zone                         │           │       │
│  │  └──────────────────────────────────────────────────┘           │       │
│  └─────────────────────────────────────────────────────────────────┘       │
│                                                                             │
│  Red Zone 机制（以堆为例）                                                  │
│  ┌─────────────────────────────────────────────────────────────────┐       │
│  │                                                                  │       │
│  │  malloc(10) 实际分配:                                           │       │
│  │  ┌────────────┬──────────────────┬────────────┐                 │       │
│  │  │  Left Red  │   User Memory    │ Right Red  │                 │       │
│  │  │   Zone     │   (10 bytes)     │   Zone     │                 │       │
│  │  │  (poisoned)│   (accessible)   │ (poisoned) │                 │       │
│  │  └────────────┴──────────────────┴────────────┘                 │       │
│  │                                                                  │       │
│  │  free(p) 后:                                                    │       │
│  │  ┌────────────┬──────────────────┬────────────┐                 │       │
│  │  │  Left Red  │  Freed Memory    │ Right Red  │                 │       │
│  │  │   Zone     │  (全部poisoned)  │   Zone     │                 │       │
│  │  │  (poisoned)│  Shadow=0xfd     │ (poisoned) │                 │       │
│  │  └────────────┴──────────────────┴────────────┘                 │       │
│  │  指针放入隔离队列(quarantine)，延迟重新分配                      │       │
│  └─────────────────────────────────────────────────────────────────┘       │
│                                                                             │
│  运行时库替换                                                               │
│  ┌─────────────────────────────────────────────────────────────────┐       │
│  │  malloc()  ──▶  __asan_malloc()   分配时设置Red Zone           │       │
│  │  free()    ──▶  __asan_free()     释放时毒化内存+加入隔离队列   │       │
│  │  memcpy()  ──▶  __asan_memcpy()   检查源和目标区域             │       │
│  │  memset()  ──▶  __asan_memset()   检查目标区域                 │       │
│  │  strlen()  ──▶  __asan_strlen()   检查字符串边界               │       │
│  └─────────────────────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### ASan报告结构详解

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ASan 报告解读指南                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  完整报告包含5个部分:                                                        │
│                                                                             │
│  ① 错误类型和位置                                                           │
│  ┌─────────────────────────────────────────────────────────────────┐       │
│  │ ==PID==ERROR: AddressSanitizer: <error-type>                    │       │
│  │   on address 0x... at pc 0x... bp 0x... sp 0x...               │       │
│  │ READ/WRITE of size N at 0x... thread T0                         │       │
│  └─────────────────────────────────────────────────────────────────┘       │
│                                                                             │
│  ② 错误发生时的调用栈                                                       │
│  ┌─────────────────────────────────────────────────────────────────┐       │
│  │ #0 0x... in function_name file.cpp:line:column                  │       │
│  │ #1 0x... in caller_function file.cpp:line                       │       │
│  │ #2 ...                                                          │       │
│  └─────────────────────────────────────────────────────────────────┘       │
│                                                                             │
│  ③ 相关内存的分配/释放信息                                                  │
│  ┌─────────────────────────────────────────────────────────────────┐       │
│  │ allocated by thread T0 here: (或 freed by thread T0 here:)     │       │
│  │ #0 0x... in operator new/malloc                                 │       │
│  │ #1 0x... in allocating_function                                 │       │
│  └─────────────────────────────────────────────────────────────────┘       │
│                                                                             │
│  ④ Shadow Memory 状态可视化                                                 │
│  ┌─────────────────────────────────────────────────────────────────┐       │
│  │ Shadow bytes around the buggy address:                          │       │
│  │ =>0x0c047fff8000: 00 00 00 00 00[fa]fa fa fa fa                │       │
│  │                                  ^^                             │       │
│  │   [  ] = 访问的Shadow字节   fa = 堆Red Zone                    │       │
│  └─────────────────────────────────────────────────────────────────┘       │
│                                                                             │
│  ⑤ 摘要行                                                                   │
│  ┌─────────────────────────────────────────────────────────────────┐       │
│  │ SUMMARY: AddressSanitizer: error-type file:line in function     │       │
│  └─────────────────────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### ASan抑制文件

```
# asan_suppressions.txt
# 格式: <检测类型>:<函数名或文件路径模式>

# 抑制第三方库的泄漏
leak:libthirdparty.so
leak:ThirdPartyInit

# 抑制已知的误报
interceptor_via_fun:my_custom_allocator

# 使用方式:
# ASAN_OPTIONS=suppressions=asan_suppressions.txt ./app
```

```cpp
// ============================================================
// 使用ASan属性标注（源码级抑制）
// ============================================================

// 方法1：__attribute__((no_sanitize("address")))
// 对整个函数禁用ASan检查
__attribute__((no_sanitize("address")))
void known_safe_function() {
    // 这里的内存操作不会被ASan检查
    // 仅在确认安全时使用！
}

// 方法2：条件编译
#if defined(__SANITIZE_ADDRESS__) || __has_feature(address_sanitizer)
    // ASan下的特殊逻辑
    #define ASAN_ENABLED 1
#else
    #define ASAN_ENABLED 0
#endif

// 方法3：使用ASan API精确控制
#if ASAN_ENABLED
#include <sanitizer/asan_interface.h>
#endif

void custom_memory_pool_alloc(void* pool, size_t offset, size_t size) {
    void* ptr = static_cast<char*>(pool) + offset;
#if ASAN_ENABLED
    // 告诉ASan这块内存现在是可访问的
    ASAN_UNPOISON_MEMORY_REGION(ptr, size);
#endif
    // ... 使用内存 ...
}

void custom_memory_pool_free(void* pool, size_t offset, size_t size) {
    void* ptr = static_cast<char*>(pool) + offset;
#if ASAN_ENABLED
    // 告诉ASan这块内存不再可访问
    ASAN_POISON_MEMORY_REGION(ptr, size);
#endif
}
```

#### Week 1 输出物清单

| # | 输出物 | 说明 | 检验标准 |
|---|--------|------|----------|
| 1 | notes/sanitizer_overview.md | Sanitizer家族概述 | 包含四种Sanitizer定位和互斥关系 |
| 2 | notes/asan_internals.md | ASan内部原理 | 包含Shadow Memory映射和Red Zone机制 |
| 3 | practice/asan_basic/ | ASan基本使用 | 成功编译并运行ASan检测 |
| 4 | practice/heap_errors/ | 堆内存错误示例 | 4种堆错误均可触发检测 |
| 5 | practice/stack_global_errors/ | 栈/全局错误示例 | 4种栈/全局错误均可触发检测 |
| 6 | practice/leak_detection/ | 内存泄漏检测 | LSan正确报告泄漏位置 |
| 7 | notes/week1_asan.md | Week 1学习总结 | 覆盖原理/编译/9大错误/报告解读 |

#### Week 1 检验标准

- [ ] 能够解释ASan的Shadow Memory映射原理（1字节Shadow对应8字节应用内存）
- [ ] 能够解释Red Zone机制如何检测缓冲区溢出
- [ ] 能够列举ASan检测的9种内存错误类型
- [ ] 能够正确使用-fsanitize=address编译选项和相关标志
- [ ] 能够配置ASAN_OPTIONS环境变量（至少5个常用选项）
- [ ] 能够完整解读ASan报告的5个组成部分
- [ ] 能够使用llvm-symbolizer对报告进行符号化
- [ ] 能够编写ASan抑制文件和使用源码级标注
- [ ] 能够使用ASan API（POISON/UNPOISON）控制自定义内存池
- [ ] 理解LeakSanitizer的工作原理和与ASan的关系

### 第二周：ThreadSanitizer（TSan）

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Week 2: ThreadSanitizer（TSan）数据竞争检测               │
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │  Day 8-9    │───▶│  Day 10-11  │───▶│  Day 12-13  │───▶│   Day 14    │  │
│  │ TSan原理    │    │ 数据竞争    │    │ 死锁检测与  │    │ TSan报告    │  │
│  │ Happens-    │    │ 实战检测    │    │ 修复模式    │    │ 源码阅读    │  │
│  │ Before模型  │    │ 与修复      │    │             │    │             │  │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘  │
│                                                                             │
│  核心技能：                                                                  │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │ • TSan插桩原理（Vector Clock + Happens-Before关系推导）              │ │
│  │ • 数据竞争的C++标准定义（两个线程、至少一个写、无同步）             │ │
│  │ • 4类竞争场景检测（写-写/读-写/锁顺序反转/信号竞争）               │ │
│  │ • 常见并发Bug修复模式（mutex/atomic/scoped_lock）                   │ │
│  │ • TSan注解API（标注自定义同步原语）                                 │ │
│  │ • TSan性能开销理解（5-15x CPU，5-10x内存）                         │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
│  输出物：竞争示例集 + 修复模式笔记 + 并发测试代码         学习时间：35小时   │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Week 2 每日任务分解

| 天数 | 时间 | 主题 | 具体任务 | 输出物 |
|------|------|------|----------|--------|
| Day 8 | 5h | TSan工作原理 | 1. Happens-Before关系模型 2. Vector Clock算法 3. TSan插桩机制（编译时+运行时） 4. 与ASan的互斥原因（Shadow Memory冲突） | notes/tsan_internals.md |
| Day 9 | 5h | 数据竞争定义 | 1. C++标准中数据竞争的精确定义 2. 竞争vs竞态条件vs原子性违规区分 3. 顺序一致性与内存序 4. 为什么数据竞争是未定义行为 | notes/data_race_theory.md |
| Day 10 | 5h | 写-写竞争 | 1. 共享变量无保护写入 2. 容器并发修改（vector/map） 3. 全局状态竞争 4. 修复：mutex/atomic | practice/write_write_race/ |
| Day 11 | 5h | 读-写竞争 | 1. 读写竞争（reader-writer问题） 2. TOCTOU竞争 3. shared_mutex使用 4. 修复：shared_lock/unique_lock | practice/read_write_race/ |
| Day 12 | 5h | 锁顺序与死锁 | 1. 锁顺序反转检测 2. 死锁场景构造 3. std::scoped_lock解决方案 4. 锁层级设计 | practice/lock_order/ |
| Day 13 | 5h | 高级竞争场景 | 1. 信号处理竞争（sig_atomic_t） 2. 条件变量虚假唤醒 3. 自定义同步原语的TSan注解 4. TSan抑制文件编写 | practice/advanced_races/ |
| Day 14 | 5h | 报告解读与总结 | 1. TSan报告结构详解（4个部分） 2. 多线程调试技巧 3. 阅读compiler-rt/lib/tsan源码 4. Week 2总结 | notes/week2_tsan.md |

---

**学习目标**：掌握数据竞争检测

**阅读材料**：
- [ ] ThreadSanitizer文档
- [ ] Data Race的定义和后果
- [ ] C++内存模型基础

```bash
# ==========================================
# 编译启用TSan
# ==========================================

# 编译
clang++ -fsanitize=thread -fno-omit-frame-pointer -g source.cpp -o app -pthread

# 注意：TSan与ASan不兼容，不能同时使用

# 运行时选项
TSAN_OPTIONS=halt_on_error=0:second_deadlock_stack=1 ./app

# 常用TSAN_OPTIONS
# halt_on_error=0           - 遇到错误继续运行
# second_deadlock_stack=1   - 显示死锁的第二个栈
# report_signal_unsafe=1    - 报告信号不安全的调用
# history_size=7            - 历史大小（0-7，越大越慢）
```

**TSan能检测的错误类型**：

```cpp
// ==========================================
// 1. 数据竞争 (Data Race)
// ==========================================
#include <thread>

int shared_data = 0;

void data_race_example() {
    std::thread t1([] {
        shared_data = 1;  // 竞争写入
    });

    std::thread t2([] {
        shared_data = 2;  // 竞争写入
    });

    t1.join();
    t2.join();
}

// 修复方法1：使用互斥锁
std::mutex mtx;
void fixed_with_mutex() {
    std::thread t1([&] {
        std::lock_guard<std::mutex> lock(mtx);
        shared_data = 1;
    });

    std::thread t2([&] {
        std::lock_guard<std::mutex> lock(mtx);
        shared_data = 2;
    });

    t1.join();
    t2.join();
}

// 修复方法2：使用原子变量
#include <atomic>
std::atomic<int> atomic_data{0};

void fixed_with_atomic() {
    std::thread t1([] {
        atomic_data.store(1, std::memory_order_release);
    });

    std::thread t2([] {
        atomic_data.store(2, std::memory_order_release);
    });

    t1.join();
    t2.join();
}

// ==========================================
// 2. 读写竞争
// ==========================================
void read_write_race() {
    std::thread writer([] {
        shared_data = 42;  // 写入
    });

    std::thread reader([] {
        int value = shared_data;  // 并发读取
        (void)value;
    });

    writer.join();
    reader.join();
}

// ==========================================
// 3. 锁顺序反转 (可能导致死锁)
// ==========================================
std::mutex mutex_a, mutex_b;

void thread_1() {
    std::lock_guard<std::mutex> lock_a(mutex_a);
    std::this_thread::sleep_for(std::chrono::milliseconds(1));
    std::lock_guard<std::mutex> lock_b(mutex_b);  // 先a后b
}

void thread_2() {
    std::lock_guard<std::mutex> lock_b(mutex_b);
    std::this_thread::sleep_for(std::chrono::milliseconds(1));
    std::lock_guard<std::mutex> lock_a(mutex_a);  // 先b后a - 可能死锁！
}

// 修复：使用std::lock或std::scoped_lock
void thread_1_fixed() {
    std::scoped_lock lock(mutex_a, mutex_b);
    // ...
}

void thread_2_fixed() {
    std::scoped_lock lock(mutex_a, mutex_b);
    // ...
}

// ==========================================
// 4. 信号处理中的竞争
// ==========================================
#include <signal.h>

volatile sig_atomic_t flag = 0;  // 必须使用sig_atomic_t

void signal_handler(int) {
    flag = 1;  // 只能设置sig_atomic_t类型的变量
}

void signal_race_example() {
    signal(SIGINT, signal_handler);

    while (!flag) {
        // 等待信号
    }
}
```

**理解TSan报告**：

```
==================
WARNING: ThreadSanitizer: data race (pid=12345)
  Write of size 4 at 0x5629c6e8f000 by thread T2:
    #0 lambda at /path/to/source.cpp:15:19 (app+0x1234)
    #1 std::thread::_State_impl<...>::_M_run() (/lib/x86_64-linux-gnu/libstdc++.so.6+0xd6de3)

  Previous write of size 4 at 0x5629c6e8f000 by thread T1:
    #0 lambda at /path/to/source.cpp:11:19 (app+0x1200)
    #1 std::thread::_State_impl<...>::_M_run() (/lib/x86_64-linux-gnu/libstdc++.so.6+0xd6de3)

  Location is global 'shared_data' of size 4 at 0x5629c6e8f000 (app+0x5000)

  Thread T2 (tid=12347, running) created by main thread at:
    #0 pthread_create (/lib/x86_64-linux-gnu/libtsan.so.0+0x5ea79)
    #1 std::thread::_M_start_thread(...) (/lib/x86_64-linux-gnu/libstdc++.so.6+0xd70a8)
    #2 main /path/to/source.cpp:18:17 (app+0x1280)

  Thread T1 (tid=12346, finished) created by main thread at:
    ...

SUMMARY: ThreadSanitizer: data race /path/to/source.cpp:15:19 in lambda
==================
```

#### TSan 工作原理深入

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ThreadSanitizer 内部工作原理                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Happens-Before 关系模型                                                    │
│  ┌─────────────────────────────────────────────────────────────────┐       │
│  │                                                                  │       │
│  │  Thread 1              Thread 2                                  │       │
│  │  ────────              ────────                                  │       │
│  │  x = 1;                                                         │       │
│  │  mtx.lock();                                                    │       │
│  │  shared = 42; ──┐                                               │       │
│  │  mtx.unlock();  │ happens-before                                │       │
│  │                 ▼                                                │       │
│  │                 mtx.lock();                                      │       │
│  │                 y = shared; ← 安全：有happens-before关系         │       │
│  │                 mtx.unlock();                                    │       │
│  │                                                                  │       │
│  │  如果没有锁：                                                    │       │
│  │  Thread 1              Thread 2                                  │       │
│  │  shared = 42;          y = shared;  ← 数据竞争！无HB关系        │       │
│  └─────────────────────────────────────────────────────────────────┘       │
│                                                                             │
│  Vector Clock 算法                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐       │
│  │                                                                  │       │
│  │  每个线程维护一个向量时钟 VC[thread_count]:                      │       │
│  │                                                                  │       │
│  │  Thread 1: VC1 = [2, 0, 0]   (自己的epoch=2)                   │       │
│  │  Thread 2: VC2 = [0, 3, 0]   (自己的epoch=3)                   │       │
│  │  Thread 3: VC3 = [0, 0, 1]   (自己的epoch=1)                   │       │
│  │                                                                  │       │
│  │  同步操作（如mutex.unlock→lock）时传递向量时钟:                  │       │
│  │  Thread 1 unlock: mutex_vc = max(mutex_vc, VC1)                 │       │
│  │  Thread 2 lock:   VC2 = max(VC2, mutex_vc)                     │       │
│  │                                                                  │       │
│  │  检测竞争: 如果两个访问的VC互不包含(即不可比较)，则存在竞争      │       │
│  │  VC1=[2,0] vs VC2=[0,3] → 互不包含 → 可能竞争                  │       │
│  │  VC1=[2,1] vs VC2=[1,3] → 互不包含 → 可能竞争                  │       │
│  │  VC1=[2,3] vs VC2=[1,3] → VC1包含VC2 → 有序,无竞争             │       │
│  └─────────────────────────────────────────────────────────────────┘       │
│                                                                             │
│  TSan Shadow Memory（与ASan不同的映射方式）                                  │
│  ┌─────────────────────────────────────────────────────────────────┐       │
│  │  每8字节应用内存 → 4个Shadow Cell（每个16字节）                  │       │
│  │                                                                  │       │
│  │  Shadow Cell结构:                                                │       │
│  │  ┌─────────┬──────┬──────┬───────┬──────────┐                   │       │
│  │  │ TID(16) │Epoch │ Pos  │IsWrite│AccessSize│                   │       │
│  │  │ 线程ID  │(42)  │(0-7) │(1bit) │ (2bit)   │                   │       │
│  │  └─────────┴──────┴──────┴───────┴──────────┘                   │       │
│  │                                                                  │       │
│  │  记录最近4次不同线程的访问                                       │       │
│  │  新访问与已记录的4个访问比较 → 发现竞争                          │       │
│  └─────────────────────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### TSan注解API（标注自定义同步原语）

```cpp
// ============================================================
// TSan注解：当使用自定义同步原语时，需要告知TSan
// ============================================================
#if defined(__SANITIZE_THREAD__) || __has_feature(thread_sanitizer)
#include <sanitizer/tsan_interface.h>
#define TSAN_ENABLED 1
#else
#define TSAN_ENABLED 0
#endif

// 自定义自旋锁示例（需要TSan注解）
class SpinLock {
public:
    void lock() {
        while (flag_.test_and_set(std::memory_order_acquire)) {
            // spin
        }
#if TSAN_ENABLED
        // 告诉TSan：这是一个acquire操作
        __tsan_acquire(&flag_);
#endif
    }

    void unlock() {
#if TSAN_ENABLED
        // 告诉TSan：这是一个release操作
        __tsan_release(&flag_);
#endif
        flag_.clear(std::memory_order_release);
    }

private:
    std::atomic_flag flag_ = ATOMIC_FLAG_INIT;
};

// 自定义事件屏障（如无锁队列中的同步点）
class EventBarrier {
public:
    void signal() {
        ready_.store(true, std::memory_order_release);
#if TSAN_ENABLED
        __tsan_release(&ready_);
#endif
    }

    void wait() {
        while (!ready_.load(std::memory_order_acquire)) {
            std::this_thread::yield();
        }
#if TSAN_ENABLED
        __tsan_acquire(&ready_);
#endif
    }

private:
    std::atomic<bool> ready_{false};
};
```

```
# tsan_suppressions.txt - TSan抑制文件
# 格式: <类型>:<函数名或文件模式>

# 抑制第三方库中的已知竞争
race:third_party::Logger::write
race:libprotobuf.so

# 抑制良性竞争（如统计计数器，即使竞争也不影响正确性）
race:StatisticsCounter::increment

# 死锁抑制
deadlock:OldLegacyModule

# 使用: TSAN_OPTIONS=suppressions=tsan_suppressions.txt ./app
```

#### Week 2 输出物清单

| # | 输出物 | 说明 | 检验标准 |
|---|--------|------|----------|
| 1 | notes/tsan_internals.md | TSan内部原理 | 包含Happens-Before和Vector Clock |
| 2 | notes/data_race_theory.md | 数据竞争理论 | C++标准定义和三种竞争类型区分 |
| 3 | practice/write_write_race/ | 写-写竞争示例 | TSan正确检测+mutex/atomic修复 |
| 4 | practice/read_write_race/ | 读-写竞争示例 | TSan检测+shared_mutex修复 |
| 5 | practice/lock_order/ | 锁顺序反转示例 | TSan检测+scoped_lock修复 |
| 6 | practice/advanced_races/ | 高级竞争场景 | 信号竞争/条件变量/自定义同步注解 |
| 7 | notes/week2_tsan.md | Week 2学习总结 | 覆盖原理/检测/修复/注解 |

#### Week 2 检验标准

- [ ] 能够解释Happens-Before关系模型和数据竞争的精确定义
- [ ] 能够描述Vector Clock算法如何检测并发访问的顺序关系
- [ ] 能够解释TSan的Shadow Memory结构（4个Shadow Cell记录最近4次访问）
- [ ] 能够区分数据竞争（data race）、竞态条件（race condition）和原子性违规
- [ ] 能够使用TSan检测写-写竞争、读-写竞争和锁顺序反转
- [ ] 能够使用mutex/atomic/scoped_lock等正确修复数据竞争
- [ ] 能够使用shared_mutex实现读写锁解决reader-writer问题
- [ ] 能够编写TSan注解API标注自定义同步原语（__tsan_acquire/__tsan_release）
- [ ] 能够编写TSan抑制文件处理第三方库和良性竞争
- [ ] 理解TSan与ASan互斥的根本原因（Shadow Memory映射冲突）

### 第三周：UndefinedBehaviorSanitizer（UBSan）

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Week 3: UBSan 未定义行为检测                              │
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │  Day 15-16  │───▶│  Day 17-18  │───▶│  Day 19-20  │───▶│   Day 21    │  │
│  │ UB概念与    │    │ 14种子检查  │    │ UBSan+ASan  │    │ 防御性编程  │  │
│  │ UBSan原理   │    │ 器实战      │    │ 组合使用    │    │ 源码阅读    │  │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘  │
│                                                                             │
│  核心技能：                                                                  │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │ • 未定义行为的C++标准定义（编译器可做任何事）                        │ │
│  │ • UBSan 14种子检查器详解（整数溢出/空指针/对齐/移位/类型转换等）    │ │
│  │ • -fsanitize=undefined vs 指定子检查器的选择策略                     │ │
│  │ • UBSan与ASan/TSan的组合使用方式                                    │ │
│  │ • 最小运行时模式（-fsanitize-minimal-runtime）                      │ │
│  │ • 从UB检测到防御性C++编程实践                                       │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
│  输出物：14种UB示例集 + 子检查器参考表 + 防御性编程笔记   学习时间：35小时   │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Week 3 每日任务分解

| 天数 | 时间 | 主题 | 具体任务 | 输出物 |
|------|------|------|----------|--------|
| Day 15 | 5h | 未定义行为概论 | 1. C++标准中UB的定义与后果 2. UB的三种严重程度（UB/IDB/Unspecified） 3. 编译器如何利用UB进行优化 4. UB导致的真实安全漏洞案例 | notes/undefined_behavior.md |
| Day 16 | 5h | UBSan原理与配置 | 1. UBSan编译时插桩机制 2. -fsanitize=undefined包含的子检查器列表 3. 指定单个子检查器 vs 全部启用 4. -fsanitize-minimal-runtime轻量模式 | notes/ubsan_internals.md |
| Day 17 | 5h | 整数类UB | 1. signed-integer-overflow 2. unsigned-integer-overflow（非UB但可检测） 3. integer-divide-by-zero 4. shift（移位超出范围/负数移位） | practice/integer_ub/ |
| Day 18 | 5h | 指针/类型UB | 1. null（空指针解引用） 2. alignment（未对齐访问） 3. object-size（越界访问） 4. vptr（虚函数调用已析构对象） | practice/pointer_type_ub/ |
| Day 19 | 5h | 转换/其他UB | 1. float-cast-overflow 2. bool/enum越界值 3. return（非void函数无返回值） 4. unreachable/builtin（不可达代码） | practice/cast_misc_ub/ |
| Day 20 | 5h | 组合使用 | 1. UBSan+ASan组合编译 2. UBSan+覆盖率工具组合 3. -fno-sanitize-recover控制 4. __attribute__((no_sanitize))精细抑制 | practice/ubsan_combined/ |
| Day 21 | 5h | 防御性编程与总结 | 1. 从UB案例总结防御性C++编程规范 2. 安全整数运算库 3. 阅读UBSan实现源码 4. Week 3总结 | notes/week3_ubsan.md |

---

**学习目标**：检测未定义行为

**阅读材料**：
- [ ] UBSan文档
- [ ] C++未定义行为分类
- [ ] 为什么UB很危险

```bash
# ==========================================
# 编译启用UBSan
# ==========================================

# 基本用法
clang++ -fsanitize=undefined -fno-omit-frame-pointer -g source.cpp -o app

# 可以与ASan组合使用
clang++ -fsanitize=address,undefined -g source.cpp -o app

# 指定特定检查
clang++ -fsanitize=signed-integer-overflow,null,alignment source.cpp

# 运行时选项
UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=0 ./app

# 常用UBSAN_OPTIONS
# print_stacktrace=1   - 打印栈追踪
# halt_on_error=0      - 遇到错误继续运行
# report_error_type=1  - 报告错误类型
```

**UBSan检测的错误类型**：

```cpp
// ==========================================
// 1. 有符号整数溢出 (signed-integer-overflow)
// ==========================================
void signed_overflow() {
    int a = INT_MAX;
    int b = a + 1;  // 未定义行为！
}

// ==========================================
// 2. 无符号整数溢出（不是UB，但可以检测）
// ==========================================
// 使用 -fsanitize=unsigned-integer-overflow

// ==========================================
// 3. 除以零 (integer-divide-by-zero)
// ==========================================
void divide_by_zero() {
    int a = 10;
    int b = 0;
    int c = a / b;  // 未定义行为！
}

// ==========================================
// 4. 空指针解引用 (null)
// ==========================================
void null_dereference() {
    int* p = nullptr;
    int x = *p;  // 未定义行为！
}

// ==========================================
// 5. 未对齐访问 (alignment)
// ==========================================
void unaligned_access() {
    char buffer[sizeof(int) + 1];
    int* p = reinterpret_cast<int*>(&buffer[1]);  // 未对齐
    *p = 42;  // 可能是未定义行为
}

// ==========================================
// 6. 数组越界 (bounds)
// ==========================================
void array_bounds() {
    int arr[10];
    int x = arr[100];  // 越界
}

// ==========================================
// 7. 类型转换溢出 (float-cast-overflow)
// ==========================================
void float_cast_overflow() {
    double d = 1e100;
    int i = static_cast<int>(d);  // 溢出
}

// ==========================================
// 8. 移位错误 (shift)
// ==========================================
void shift_errors() {
    int x = 1;
    int a = x << 32;   // 移位超过类型宽度
    int b = x << -1;   // 负数移位
    int c = -1 << 1;   // 负数左移
}

// ==========================================
// 9. 不可达代码 (unreachable)
// ==========================================
void unreachable_code() {
    if (false) {
        __builtin_unreachable();  // 如果到达这里就是UB
    }
}

// ==========================================
// 10. 虚函数调用错误 (vptr)
// ==========================================
class Base {
public:
    virtual void foo() {}
    virtual ~Base() = default;
};

class Derived : public Base {
public:
    void foo() override {}
};

void vptr_error() {
    Base* b = new Derived();
    b->~Base();  // 析构
    b->foo();    // 调用已析构对象的虚函数 - UB
}

// ==========================================
// 11. 对象生命周期错误 (object-size)
// ==========================================
struct Small { int x; };
struct Large { int x, y, z; };

void object_size_error() {
    Small s;
    Large* l = reinterpret_cast<Large*>(&s);
    l->z = 42;  // 访问超出对象边界
}

// ==========================================
// 12. 返回值未初始化 (return)
// ==========================================
int return_uninitialized() {
    int x;  // 未初始化
    return x;  // 返回未初始化的值
}

// ==========================================
// 13. bool类型越界 (bool)
// ==========================================
void bool_error() {
    bool b;
    *reinterpret_cast<char*>(&b) = 2;  // bool只能是0或1
    if (b) {}  // UB
}

// ==========================================
// 14. 枚举越界 (enum)
// ==========================================
enum Color { Red = 0, Green = 1, Blue = 2 };

void enum_error() {
    Color c = static_cast<Color>(100);  // 无效的枚举值
}
```

#### UBSan 子检查器完整参考

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    UBSan 子检查器分类与选择                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  -fsanitize=undefined 默认包含的子检查器:                                    │
│  ┌──────────────────────────┬────────────────────────────────────────┐     │
│  │ 子检查器                 │ 检测内容                               │     │
│  ├──────────────────────────┼────────────────────────────────────────┤     │
│  │ alignment                │ 未对齐的指针访问                       │     │
│  │ bool                     │ bool值不是true/false                   │     │
│  │ builtin                  │ __builtin_unreachable等内置函数误用    │     │
│  │ bounds                   │ 数组下标越界（需要类型信息）           │     │
│  │ enum                     │ 枚举变量包含无效值                     │     │
│  │ float-cast-overflow      │ 浮点→整数转换溢出                     │     │
│  │ float-divide-by-zero     │ 浮点除以零                             │     │
│  │ integer-divide-by-zero   │ 整数除以零                             │     │
│  │ null                     │ 空指针解引用                           │     │
│  │ object-size              │ 对象大小不匹配的访问                   │     │
│  │ return                   │ 非void函数末尾没有return               │     │
│  │ shift                    │ 移位量超出范围或负数                   │     │
│  │ signed-integer-overflow  │ 有符号整数溢出                         │     │
│  │ unreachable              │ 执行到__builtin_unreachable()          │     │
│  │ vptr                     │ 通过错误类型指针调用虚函数             │     │
│  │ pointer-overflow         │ 指针运算溢出                           │     │
│  │ nonnull-attribute        │ 违反__attribute__((nonnull))           │     │
│  │ returns-nonnull-attribute│ nonnull函数返回了null                  │     │
│  └──────────────────────────┴────────────────────────────────────────┘     │
│                                                                             │
│  额外的可选子检查器（不在-fsanitize=undefined中）:                           │
│  ┌──────────────────────────┬────────────────────────────────────────┐     │
│  │ unsigned-integer-overflow│ 无符号整数溢出（非UB，但常是bug）     │     │
│  │ implicit-conversion      │ 隐式类型转换精度丢失                   │     │
│  │ local-bounds             │ 局部数组越界（不需类型信息）           │     │
│  │ nullability-*            │ _Nullable属性违规                      │     │
│  └──────────────────────────┴────────────────────────────────────────┘     │
│                                                                             │
│  推荐组合:                                                                   │
│  ┌─────────────────────────────────────────────────────────────────┐       │
│  │ 基础: -fsanitize=undefined                                      │       │
│  │ 增强: -fsanitize=undefined,unsigned-integer-overflow,           │       │
│  │       implicit-conversion                                       │       │
│  │ 组合: -fsanitize=address,undefined （ASan+UBSan，推荐CI使用）   │       │
│  └─────────────────────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### UBSan与ASan组合使用

```cpp
// ============================================================
// UBSan + ASan 组合编译示例
// ============================================================
// 编译命令:
// clang++ -fsanitize=address,undefined \
//         -fno-omit-frame-pointer -fno-sanitize-recover=all \
//         -g -O1 source.cpp -o app
//
// -fno-sanitize-recover=all: 遇到任何UB立即终止（默认UBSan会继续运行）
// -O1: 推荐至少O1优化，让UBSan能检测更多编译器可见的UB

// 组合检测示例：同时触发ASan和UBSan
#include <cstdlib>
#include <climits>

void combined_bugs() {
    // Bug 1: ASan检测 - 堆缓冲区溢出
    int* arr = new int[10];
    // arr[10] = 42;  // ASan: heap-buffer-overflow

    // Bug 2: UBSan检测 - 有符号整数溢出
    int x = INT_MAX;
    // int y = x + 1;  // UBSan: signed-integer-overflow

    // Bug 3: 两者都能检测的场景
    // int* p = nullptr;
    // *p = 42;  // ASan: null-deref, UBSan: null

    delete[] arr;
}
```

```cpp
// ============================================================
// UBSan 控制选项详解
// ============================================================

// 1. 控制错误恢复行为
//    -fno-sanitize-recover=all       遇到任何错误立即abort
//    -fno-sanitize-recover=undefined 仅UB时abort
//    -fsanitize-recover=all          所有错误仅打印继续运行（默认）

// 2. 最小运行时模式（减小二进制大小和运行时开销）
//    -fsanitize-minimal-runtime
//    在此模式下，UBSan不打印详细错误信息，仅调用abort()
//    适用于生产环境的安全加固

// 3. 精确禁用某个检查
__attribute__((no_sanitize("signed-integer-overflow")))
int intentional_wrap(int a, int b) {
    return a + b;  // 故意允许溢出（如哈希计算）
}

// 4. 使用__builtin_add_overflow等安全运算
bool safe_add(int a, int b, int* result) {
    return !__builtin_add_overflow(a, b, result);
}

bool safe_mul(int a, int b, int* result) {
    return !__builtin_mul_overflow(a, b, result);
}

// 使用示例
void safe_computation() {
    int result;
    if (safe_add(INT_MAX, 1, &result)) {
        // 正常使用result
    } else {
        // 溢出处理
    }
}
```

#### Week 3 输出物清单

| # | 输出物 | 说明 | 检验标准 |
|---|--------|------|----------|
| 1 | notes/undefined_behavior.md | UB概念与案例 | 包含UB/IDB/Unspecified区分和真实漏洞案例 |
| 2 | notes/ubsan_internals.md | UBSan原理与配置 | 包含子检查器列表和选择策略 |
| 3 | practice/integer_ub/ | 整数类UB示例 | 4种整数UB均可触发检测 |
| 4 | practice/pointer_type_ub/ | 指针/类型UB示例 | null/alignment/object-size/vptr |
| 5 | practice/cast_misc_ub/ | 转换与其他UB示例 | float-cast/bool/enum/return/unreachable |
| 6 | practice/ubsan_combined/ | 组合使用示例 | ASan+UBSan组合编译运行成功 |
| 7 | notes/week3_ubsan.md | Week 3学习总结 | 覆盖14种子检查器+组合策略+防御性编程 |

#### Week 3 检验标准

- [ ] 能够解释未定义行为（UB）、实现定义行为（IDB）和未指定行为的区别
- [ ] 能够解释编译器如何利用UB进行优化（以signed overflow为例）
- [ ] 能够列举UBSan的至少14种子检查器及其检测内容
- [ ] 能够区分-fsanitize=undefined默认包含和需额外指定的子检查器
- [ ] 能够使用-fsanitize=address,undefined组合编译和检测
- [ ] 能够使用-fno-sanitize-recover=all控制错误恢复行为
- [ ] 能够使用__attribute__((no_sanitize()))对函数级别精确抑制
- [ ] 能够使用__builtin_add_overflow等进行安全整数运算
- [ ] 能够解释-fsanitize-minimal-runtime的使用场景（生产环境安全加固）
- [ ] 能够从UB检测结果总结防御性C++编程实践

### 第四周：MemorySanitizer与集成实践

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Week 4: MSan + Sanitizer综合集成                          │
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │  Day 22-23  │───▶│  Day 24-25  │───▶│  Day 26-27  │───▶│   Day 28    │  │
│  │ MSan原理    │    │ 性能影响    │    │ CI/CD集成   │    │ 综合项目    │  │
│  │ 与实践      │    │ CMake深化   │    │ 完整方案    │    │ 月度总结    │  │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘  │
│                                                                             │
│  核心技能：                                                                  │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │ • MSan工作原理（Shadow Memory标记未初始化字节）                      │ │
│  │ • MSan特殊要求（需要instrumented libc++，仅Clang支持）              │ │
│  │ • 四种Sanitizer性能影响对比（CPU/内存/磁盘）                        │ │
│  │ • CMake Sanitizer模块设计（互斥检测+CTest集成）                     │ │
│  │ • GitHub Actions多Sanitizer并行CI方案                               │ │
│  │ • Sanitizer选择决策树（按项目类型/Bug类型选择）                     │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
│  输出物：完整Sanitizer框架 + CI配置 + 综合测试套件       学习时间：35小时   │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Week 4 每日任务分解

| 天数 | 时间 | 主题 | 具体任务 | 输出物 |
|------|------|------|----------|--------|
| Day 22 | 5h | MSan原理 | 1. MSan Shadow Memory原理（每位跟踪初始化状态） 2. MSan与ASan/TSan互斥原因 3. 仅Clang支持的原因 4. instrumented libc++编译要求 | notes/msan_internals.md |
| Day 23 | 5h | MSan实践 | 1. 未初始化栈变量检测 2. 未初始化堆内存检测 3. 未初始化值传播追踪 4. MSan API（__msan_poison/__msan_unpoison） | practice/msan_examples/ |
| Day 24 | 5h | 性能影响分析 | 1. 四种Sanitizer CPU/内存开销基准测试 2. 二进制大小影响 3. 编译时间影响 4. 性能开销来源分析 | notes/sanitizer_performance.md |
| Day 25 | 5h | CMake模块深化 | 1. 完善Sanitizers.cmake（互斥检测+友好提示） 2. CTest集成（per-sanitizer测试目标） 3. CMakePresets.json Sanitizer预设 4. FetchContent+Sanitizer配合 | cmake/Sanitizers.cmake |
| Day 26 | 5h | CI/CD完整方案 | 1. GitHub Actions多Sanitizer并行workflow 2. 矩阵策略（ASan/TSan/UBSan分别构建） 3. SARIF格式上报 4. PR状态检查集成 | .github/workflows/sanitizers.yml |
| Day 27 | 5h | 实践项目完善 | 1. 完善sanitizer-framework项目 2. 添加所有Sanitizer测试用例 3. 编写run_all_sanitizers.sh 4. 集成报告生成 | sanitizer-framework/ |
| Day 28 | 5h | 月度总结 | 1. 四种Sanitizer对比总结表 2. 项目Sanitizer最佳实践 3. Sanitizer选择决策树 4. 月度学习笔记 | notes/month44_sanitizers.md |

---

**学习目标**：使用MSan检测未初始化内存，集成到CI

**阅读材料**：
- [ ] MemorySanitizer文档
- [ ] Sanitizer在CI中的使用
- [ ] 性能影响分析

```bash
# ==========================================
# MemorySanitizer（仅Clang支持）
# ==========================================

# 编译（需要使用msan-instrumented的标准库）
clang++ -fsanitize=memory -fno-omit-frame-pointer -g source.cpp -o app

# MSan需要所有代码都被instrumented，包括标准库
# 因此实际使用中通常需要自己编译libc++

# 运行时选项
MSAN_OPTIONS=halt_on_error=0:print_stats=1 ./app

# 注意：MSan与ASan、TSan都不兼容
```

**MSan示例**：

```cpp
// ==========================================
// 未初始化内存使用
// ==========================================
void use_uninitialized() {
    int x;  // 未初始化
    if (x > 0) {  // 使用未初始化的值做条件判断
        printf("positive\n");
    }
}

void use_uninitialized_parameter(int* out) {
    int local;  // 未初始化
    *out = local;  // 传播未初始化的值
}

void use_heap_uninitialized() {
    int* p = (int*)malloc(sizeof(int));
    if (*p > 0) {  // 使用未初始化的堆内存
        printf("positive\n");
    }
    free(p);
}
```

**CMake集成**：

```cmake
# ==========================================
# cmake/Sanitizers.cmake
# ==========================================
option(ENABLE_ASAN "Enable AddressSanitizer" OFF)
option(ENABLE_TSAN "Enable ThreadSanitizer" OFF)
option(ENABLE_UBSAN "Enable UndefinedBehaviorSanitizer" OFF)
option(ENABLE_MSAN "Enable MemorySanitizer" OFF)

function(enable_sanitizers target)
    if(NOT (CMAKE_CXX_COMPILER_ID STREQUAL "GNU" OR
            CMAKE_CXX_COMPILER_ID MATCHES ".*Clang"))
        message(WARNING "Sanitizers only supported with GCC and Clang")
        return()
    endif()

    set(SANITIZERS "")

    if(ENABLE_ASAN)
        list(APPEND SANITIZERS "address")
    endif()

    if(ENABLE_TSAN)
        if(ENABLE_ASAN)
            message(WARNING "TSAN is incompatible with ASAN")
        else()
            list(APPEND SANITIZERS "thread")
        endif()
    endif()

    if(ENABLE_UBSAN)
        list(APPEND SANITIZERS "undefined")
    endif()

    if(ENABLE_MSAN)
        if(ENABLE_ASAN OR ENABLE_TSAN)
            message(WARNING "MSAN is incompatible with ASAN and TSAN")
        elseif(NOT CMAKE_CXX_COMPILER_ID MATCHES ".*Clang")
            message(WARNING "MSAN only supported with Clang")
        else()
            list(APPEND SANITIZERS "memory")
        endif()
    endif()

    if(SANITIZERS)
        list(JOIN SANITIZERS "," SANITIZERS_STR)

        target_compile_options(${target} PRIVATE
            -fsanitize=${SANITIZERS_STR}
            -fno-omit-frame-pointer
            -fno-optimize-sibling-calls
        )

        target_link_options(${target} PRIVATE
            -fsanitize=${SANITIZERS_STR}
        )

        # 设置运行时选项
        if(ENABLE_ASAN)
            set_property(TARGET ${target} APPEND PROPERTY
                ENVIRONMENT "ASAN_OPTIONS=detect_leaks=1:halt_on_error=0"
            )
        endif()

        if(ENABLE_TSAN)
            set_property(TARGET ${target} APPEND PROPERTY
                ENVIRONMENT "TSAN_OPTIONS=halt_on_error=0"
            )
        endif()

        if(ENABLE_UBSAN)
            set_property(TARGET ${target} APPEND PROPERTY
                ENVIRONMENT "UBSAN_OPTIONS=print_stacktrace=1"
            )
        endif()
    endif()
endfunction()

# 使用
# enable_sanitizers(mytarget)
```

**GitHub Actions集成**：

```yaml
# .github/workflows/sanitizers.yml
name: Sanitizer Tests

on:
  push:
    branches: [main]
  pull_request:

jobs:
  asan:
    name: AddressSanitizer
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4

      - name: Configure
        run: |
          cmake -B build -S . \
            -DCMAKE_BUILD_TYPE=Debug \
            -DENABLE_ASAN=ON \
            -DBUILD_TESTS=ON

      - name: Build
        run: cmake --build build

      - name: Test
        run: ctest --test-dir build --output-on-failure
        env:
          ASAN_OPTIONS: detect_leaks=1:halt_on_error=1

  tsan:
    name: ThreadSanitizer
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4

      - name: Configure
        run: |
          cmake -B build -S . \
            -DCMAKE_BUILD_TYPE=Debug \
            -DENABLE_TSAN=ON \
            -DBUILD_TESTS=ON

      - name: Build
        run: cmake --build build

      - name: Test
        run: ctest --test-dir build --output-on-failure
        env:
          TSAN_OPTIONS: halt_on_error=1

  ubsan:
    name: UndefinedBehaviorSanitizer
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4

      - name: Configure
        run: |
          cmake -B build -S . \
            -DCMAKE_BUILD_TYPE=Debug \
            -DENABLE_UBSAN=ON \
            -DBUILD_TESTS=ON

      - name: Build
        run: cmake --build build

      - name: Test
        run: ctest --test-dir build --output-on-failure
        env:
          UBSAN_OPTIONS: print_stacktrace=1:halt_on_error=1
```

#### Sanitizer 性能影响对比

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Sanitizer 性能影响全面对比                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────┬─────────┬─────────┬─────────┬─────────┐                 │
│  │ 维度         │  ASan   │  TSan   │  UBSan  │  MSan   │                 │
│  ├──────────────┼─────────┼─────────┼─────────┼─────────┤                 │
│  │ CPU开销      │  ~2x    │  5-15x  │  ~1.2x  │  ~3x   │                 │
│  │ 内存开销     │  ~3x    │  5-10x  │  ~1x    │  ~2x   │                 │
│  │ 二进制大小   │  ~2x    │  ~2x    │  ~1.5x  │  ~2x   │                 │
│  │ 编译时间     │  +30%   │  +50%   │  +10%   │  +40%   │                 │
│  │ 误报率       │  极低   │  极低   │  零     │  低     │                 │
│  │ 漏报率       │  低     │  中     │  低     │  低     │                 │
│  ├──────────────┼─────────┼─────────┼─────────┼─────────┤                 │
│  │ 编译器支持   │GCC+Clang│GCC+Clang│GCC+Clang│仅Clang  │                 │
│  │ 互斥关系     │TSan,MSan│ASan,MSan│可组合   │ASan,TSan│                 │
│  │ -O级别推荐   │  -O1    │  -O1    │  -O1    │  -O1    │                 │
│  └──────────────┴─────────┴─────────┴─────────┴─────────┘                 │
│                                                                             │
│  开销来源分析:                                                               │
│  ┌─────────────────────────────────────────────────────────────────┐       │
│  │ ASan: Shadow Memory映射(3x内存) + 每次访问前检查(2x CPU)       │       │
│  │ TSan: Vector Clock维护(10x内存) + 每次内存操作记录(5-15x CPU)  │       │
│  │ UBSan: 仅在可能UB点插入检查(开销极小)                           │       │
│  │ MSan: Shadow bit跟踪(2x内存) + 传播分析(3x CPU)               │       │
│  └─────────────────────────────────────────────────────────────────┘       │
│                                                                             │
│  互斥关系图:                                                                 │
│  ┌───────┐         ┌───────┐         ┌───────┐                            │
│  │ ASan  │──互斥──│ TSan  │──互斥──│ MSan  │                            │
│  └───┬───┘         └───────┘         └───────┘                            │
│      │                                                                      │
│      │ 可组合                                                               │
│      │                                                                      │
│  ┌───┴───┐                                                                 │
│  │ UBSan │ ← UBSan是唯一可与ASan或TSan组合使用的                         │
│  └───────┘                                                                 │
│                                                                             │
│  推荐CI策略:                                                                 │
│  ┌─────────────────────────────────────────────────────────────────┐       │
│  │ Job 1: ASan + UBSan  (内存错误 + 未定义行为，最常用组合)        │       │
│  │ Job 2: TSan          (数据竞争，独立运行)                       │       │
│  │ Job 3: MSan          (未初始化内存，仅Clang，独立运行)          │       │
│  └─────────────────────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Sanitizer 选择决策树

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Sanitizer 选择决策树                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  你的程序遇到了什么问题？                                                    │
│  ┌─────────────────────┐                                                   │
│  │  程序崩溃/段错误？   │                                                   │
│  └──────────┬──────────┘                                                   │
│             │                                                               │
│     ┌───是──┴──否───┐                                                      │
│     ▼               ▼                                                      │
│  ┌──────┐     ┌────────────────────┐                                      │
│  │ ASan │     │ 多线程行为异常？    │                                      │
│  │      │     └─────────┬──────────┘                                      │
│  │ 检测:│       ┌───是──┴──否───┐                                         │
│  │ 溢出 │       ▼               ▼                                         │
│  │ UAF  │    ┌──────┐    ┌────────────────────┐                           │
│  │ 泄漏 │    │ TSan │    │ 计算结果不正确？    │                           │
│  │ 双释放│    │      │    └─────────┬──────────┘                           │
│  └──────┘    │ 检测:│      ┌───是──┴──否───┐                              │
│              │ 竞争 │      ▼               ▼                              │
│              │ 死锁 │   ┌──────┐    ┌────────────────┐                    │
│              └──────┘   │UBSan │    │ Valgrind或     │                    │
│                         │      │    │ 代码审查        │                    │
│                         │ 检测:│    └────────────────┘                    │
│                         │ 溢出 │                                          │
│                         │ 移位 │    ┌────────────────────────────┐        │
│                         │ 空指针│    │ 使用了未初始化的变量？      │        │
│                         └──────┘    └─────────────┬──────────────┘        │
│                                           ┌───是──┴──┐                    │
│                                           ▼          │                    │
│                                        ┌──────┐      │                    │
│                                        │ MSan │      │                    │
│                                        │      │      │                    │
│                                        │ 检测:│      │                    │
│                                        │ 未初始│      │                    │
│                                        │ 化读取│      │                    │
│                                        └──────┘      │                    │
│                                                       │                    │
│  预防性全面检测（CI推荐）:                              │                    │
│  ┌────────────────────────────────────────────┐      │                    │
│  │ 1. ASan+UBSan  → 覆盖80%的常见运行时Bug    │      │                    │
│  │ 2. TSan        → 捕捉所有并发Bug            │      │                    │
│  │ 3. MSan (可选) → 严格模式下使用              │      │                    │
│  └────────────────────────────────────────────┘      │                    │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### CMakePresets.json Sanitizer预设

```json
{
    "version": 6,
    "configurePresets": [
        {
            "name": "base",
            "hidden": true,
            "generator": "Ninja",
            "binaryDir": "${sourceDir}/build/${presetName}",
            "cacheVariables": {
                "CMAKE_BUILD_TYPE": "Debug",
                "CMAKE_EXPORT_COMPILE_COMMANDS": "ON",
                "BUILD_TESTS": "ON"
            }
        },
        {
            "name": "asan",
            "displayName": "ASan + UBSan",
            "description": "AddressSanitizer + UndefinedBehaviorSanitizer",
            "inherits": "base",
            "cacheVariables": {
                "ENABLE_ASAN": "ON",
                "ENABLE_UBSAN": "ON"
            }
        },
        {
            "name": "tsan",
            "displayName": "TSan",
            "description": "ThreadSanitizer",
            "inherits": "base",
            "cacheVariables": {
                "ENABLE_TSAN": "ON"
            }
        },
        {
            "name": "msan",
            "displayName": "MSan",
            "description": "MemorySanitizer (Clang only)",
            "inherits": "base",
            "cacheVariables": {
                "ENABLE_MSAN": "ON",
                "CMAKE_CXX_COMPILER": "clang++"
            }
        }
    ],
    "buildPresets": [
        { "name": "asan", "configurePreset": "asan" },
        { "name": "tsan", "configurePreset": "tsan" },
        { "name": "msan", "configurePreset": "msan" }
    ],
    "testPresets": [
        {
            "name": "asan",
            "configurePreset": "asan",
            "output": { "outputOnFailure": true },
            "environment": {
                "ASAN_OPTIONS": "detect_leaks=1:halt_on_error=1",
                "UBSAN_OPTIONS": "print_stacktrace=1:halt_on_error=1"
            }
        },
        {
            "name": "tsan",
            "configurePreset": "tsan",
            "output": { "outputOnFailure": true },
            "environment": {
                "TSAN_OPTIONS": "halt_on_error=1:second_deadlock_stack=1"
            }
        },
        {
            "name": "msan",
            "configurePreset": "msan",
            "output": { "outputOnFailure": true },
            "environment": {
                "MSAN_OPTIONS": "halt_on_error=1"
            }
        }
    ]
}
```

```bash
# 使用CMake Presets运行Sanitizer测试
# 配置 + 构建 + 测试 一条龙

# ASan + UBSan
cmake --preset asan && cmake --build --preset asan && ctest --preset asan

# TSan
cmake --preset tsan && cmake --build --preset tsan && ctest --preset tsan

# MSan (仅Clang)
cmake --preset msan && cmake --build --preset msan && ctest --preset msan
```

#### Week 4 输出物清单

| # | 输出物 | 说明 | 检验标准 |
|---|--------|------|----------|
| 1 | notes/msan_internals.md | MSan原理与限制 | 包含Shadow bit和instrumented libc++要求 |
| 2 | practice/msan_examples/ | MSan检测示例 | 3种未初始化内存场景均可检测 |
| 3 | notes/sanitizer_performance.md | 性能影响分析 | 包含四种Sanitizer基准测试数据 |
| 4 | cmake/Sanitizers.cmake | 完善的CMake模块 | 支持互斥检测和CTest集成 |
| 5 | CMakePresets.json | Sanitizer预设 | asan/tsan/msan三套预设 |
| 6 | .github/workflows/sanitizers.yml | CI工作流 | 三个Sanitizer并行运行 |
| 7 | sanitizer-framework/ | 完整实践项目 | 包含所有测试和脚本 |
| 8 | notes/month44_sanitizers.md | 月度总结 | 覆盖选择决策树和最佳实践 |

#### Week 4 检验标准

- [ ] 能够解释MSan的Shadow Memory原理（每位跟踪初始化状态）
- [ ] 理解MSan需要instrumented libc++的原因和编译方法
- [ ] 能够使用MSan检测栈变量、堆内存和参数传播的未初始化读取
- [ ] 能够列举四种Sanitizer的CPU/内存开销和互斥关系
- [ ] 能够设计CMakePresets.json包含asan/tsan/msan三套预设
- [ ] 能够编写GitHub Actions多Sanitizer并行CI workflow
- [ ] 能够根据Sanitizer选择决策树为项目选择合适的检测方案
- [ ] 能够使用-fno-sanitize-recover和suppressions文件管理已知问题
- [ ] 完成sanitizer-framework实践项目（含测试/脚本/CI配置）
- [ ] 能够解释为什么CI推荐ASan+UBSan/TSan/MSan三组并行策略

---

## 源码阅读任务

### 本月源码阅读

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Sanitizer 源码阅读路线图                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  仓库：https://github.com/llvm/llvm-project                               │
│  核心路径：compiler-rt/lib/                                                 │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────┐       │
│  │ compiler-rt/lib/                                                │       │
│  │ ├── asan/              ← ASan运行时库                           │       │
│  │ │   ├── asan_interceptors.cpp    ← malloc/free拦截实现          │       │
│  │ │   ├── asan_allocator.cpp       ← Red Zone和隔离队列          │       │
│  │ │   ├── asan_poisoning.cpp       ← Shadow Memory毒化逻辑       │       │
│  │ │   ├── asan_mapping.h           ← Shadow Memory地址映射       │       │
│  │ │   └── asan_report.cpp          ← 错误报告生成                │       │
│  │ ├── tsan/              ← TSan运行时库                           │       │
│  │ │   ├── tsan_rtl.cpp             ← 运行时核心                  │       │
│  │ │   ├── tsan_clock.cpp           ← Vector Clock实现            │       │
│  │ │   ├── tsan_mutex.cpp           ← 互斥锁拦截                  │       │
│  │ │   └── tsan_report.cpp          ← 竞争报告生成                │       │
│  │ ├── ubsan/             ← UBSan运行时库                          │       │
│  │ │   ├── ubsan_handlers.cpp       ← 各类UB处理函数              │       │
│  │ │   └── ubsan_diag.cpp           ← 诊断输出                    │       │
│  │ ├── msan/              ← MSan运行时库                           │       │
│  │ │   ├── msan.cpp                 ← MSan核心                    │       │
│  │ │   └── msan_interceptors.cpp    ← 标准库拦截                  │       │
│  │ └── sanitizer_common/  ← 共享基础设施                           │       │
│  │     ├── sanitizer_common.cpp     ← 通用工具函数                │       │
│  │     ├── sanitizer_symbolizer.cpp ← 符号化（地址→文件:行号）    │       │
│  │     ├── sanitizer_stacktrace.cpp ← 栈回溯                      │       │
│  │     └── sanitizer_allocator.cpp  ← 内存分配器                  │       │
│  └─────────────────────────────────────────────────────────────────┘       │
│                                                                             │
│  推荐阅读顺序:                                                              │
│  ┌─────────────────────────────────────────────────────────────────┐       │
│  │ 1. sanitizer_common/sanitizer_common.h  → 理解通用接口          │       │
│  │ 2. asan/asan_mapping.h                  → Shadow Memory映射    │       │
│  │ 3. asan/asan_poisoning.cpp              → 毒化/解毒操作         │       │
│  │ 4. asan/asan_interceptors.cpp           → malloc/free拦截      │       │
│  │ 5. tsan/tsan_clock.cpp                  → Vector Clock算法     │       │
│  │ 6. ubsan/ubsan_handlers.cpp             → UB处理回调            │       │
│  └─────────────────────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────────────────┘
```

1. **ASan运行时库** (Week 1 Day 7)
   - 路径：`compiler-rt/lib/asan/`
   - 重点文件：
     - `asan_mapping.h` — Shadow Memory地址计算公式
     - `asan_interceptors.cpp` — malloc/free/memcpy等函数拦截
     - `asan_allocator.cpp` — Red Zone设置和quarantine队列
     - `asan_report.cpp` — 错误报告格式化输出
   - 学习目标：理解Shadow Memory映射和内存操作拦截的实现细节

2. **TSan运行时库** (Week 2 Day 14)
   - 路径：`compiler-rt/lib/tsan/`
   - 重点文件：
     - `tsan_clock.cpp` — Vector Clock数据结构和比较算法
     - `tsan_rtl.cpp` — 每次内存访问的检查逻辑
     - `tsan_mutex.cpp` — mutex操作的Happens-Before关系建立
   - 学习目标：理解Vector Clock如何追踪线程间的顺序关系

3. **UBSan处理器** (Week 3 Day 21)
   - 路径：`compiler-rt/lib/ubsan/`
   - 重点文件：
     - `ubsan_handlers.cpp` — 每种UB对应的处理回调函数
     - `ubsan_diag.cpp` — 诊断信息格式化和输出
   - 学习目标：理解编译器插入的检查点如何调用运行时处理函数

4. **知名项目的Sanitizer配置**
   - **Chromium**: `testing/sanitizer/` 目录下的抑制文件和配置
   - **LLVM自身**: `.github/workflows/` 中的Sanitizer CI配置
   - **Google Abseil**: `CMakeLists.txt` 中的Sanitizer集成方式
   - 学习目标：理解大型C++项目如何在CI中系统地使用Sanitizers

---

## 实践项目

### 项目：Sanitizer集成测试框架

创建一个自动运行Sanitizer测试并生成报告的框架。

**项目结构**：

```
sanitizer-framework/
├── CMakeLists.txt
├── cmake/
│   └── Sanitizers.cmake
├── include/
│   └── sanitizer_helpers.hpp
├── src/
│   └── sanitizer_helpers.cpp
├── tests/
│   ├── CMakeLists.txt
│   ├── test_memory.cpp
│   ├── test_threading.cpp
│   └── test_undefined.cpp
├── examples/
│   ├── memory_bugs.cpp
│   ├── race_conditions.cpp
│   └── undefined_behavior.cpp
└── scripts/
    ├── run_all_sanitizers.sh
    └── parse_sanitizer_output.py
```

**include/sanitizer_helpers.hpp**：

```cpp
#pragma once

#include <string>
#include <functional>
#include <stdexcept>

namespace sanitizer {

/**
 * @brief 检查是否在特定Sanitizer下运行
 */
bool is_asan_enabled();
bool is_tsan_enabled();
bool is_ubsan_enabled();
bool is_msan_enabled();

/**
 * @brief 抑制特定的Sanitizer检查
 */
class ScopedSanitizerDisable {
public:
    explicit ScopedSanitizerDisable(const std::string& check);
    ~ScopedSanitizerDisable();

private:
    std::string check_;
};

/**
 * @brief 标记预期的Sanitizer错误
 */
void expect_sanitizer_error(const std::string& type);

/**
 * @brief Sanitizer感知的内存分配器
 */
template<typename T>
class SanitizerAwareAllocator {
public:
    using value_type = T;

    T* allocate(std::size_t n);
    void deallocate(T* p, std::size_t n);

    // 标记内存为已初始化（用于MSan）
    static void mark_initialized(void* ptr, std::size_t size);

    // 标记内存为未初始化
    static void mark_uninitialized(void* ptr, std::size_t size);

    // 检查内存是否初始化
    static bool is_initialized(const void* ptr, std::size_t size);
};

/**
 * @brief ASan特定功能
 */
namespace asan {
    // 手动毒化内存区域
    void poison_memory_region(void* addr, std::size_t size);
    void unpoison_memory_region(void* addr, std::size_t size);

    // 检查地址是否可访问
    bool is_accessible(const void* addr, std::size_t size);

    // 描述地址
    std::string describe_address(const void* addr);
}

/**
 * @brief TSan特定功能
 */
namespace tsan {
    // 标记acquire/release语义
    void acquire(void* addr);
    void release(void* addr);

    // 标记happens-before关系
    void happens_before(void* addr);
    void happens_after(void* addr);

    // 忽略特定同步
    class ScopedIgnoreSync {
    public:
        ScopedIgnoreSync();
        ~ScopedIgnoreSync();
    };
}

} // namespace sanitizer
```

**src/sanitizer_helpers.cpp**：

```cpp
#include "sanitizer_helpers.hpp"

// Sanitizer接口头文件
#if __has_feature(address_sanitizer) || defined(__SANITIZE_ADDRESS__)
#include <sanitizer/asan_interface.h>
#define HAS_ASAN 1
#else
#define HAS_ASAN 0
#endif

#if __has_feature(thread_sanitizer) || defined(__SANITIZE_THREAD__)
#include <sanitizer/tsan_interface.h>
#define HAS_TSAN 1
#else
#define HAS_TSAN 0
#endif

#if __has_feature(memory_sanitizer)
#include <sanitizer/msan_interface.h>
#define HAS_MSAN 1
#else
#define HAS_MSAN 0
#endif

namespace sanitizer {

bool is_asan_enabled() {
#if HAS_ASAN
    return true;
#else
    return false;
#endif
}

bool is_tsan_enabled() {
#if HAS_TSAN
    return true;
#else
    return false;
#endif
}

bool is_ubsan_enabled() {
    // UBSan没有运行时检测API
    return false;
}

bool is_msan_enabled() {
#if HAS_MSAN
    return true;
#else
    return false;
#endif
}

// ASan功能
namespace asan {

void poison_memory_region(void* addr, std::size_t size) {
#if HAS_ASAN
    ASAN_POISON_MEMORY_REGION(addr, size);
#else
    (void)addr;
    (void)size;
#endif
}

void unpoison_memory_region(void* addr, std::size_t size) {
#if HAS_ASAN
    ASAN_UNPOISON_MEMORY_REGION(addr, size);
#else
    (void)addr;
    (void)size;
#endif
}

bool is_accessible(const void* addr, std::size_t size) {
#if HAS_ASAN
    return __asan_region_is_poisoned(const_cast<void*>(addr), size) == nullptr;
#else
    (void)addr;
    (void)size;
    return true;
#endif
}

std::string describe_address(const void* addr) {
#if HAS_ASAN
    char buffer[1024];
    __asan_describe_address(const_cast<void*>(addr));
    return "See ASan output";
#else
    (void)addr;
    return "ASan not enabled";
#endif
}

} // namespace asan

// TSan功能
namespace tsan {

void acquire(void* addr) {
#if HAS_TSAN
    __tsan_acquire(addr);
#else
    (void)addr;
#endif
}

void release(void* addr) {
#if HAS_TSAN
    __tsan_release(addr);
#else
    (void)addr;
#endif
}

void happens_before(void* addr) {
    release(addr);
}

void happens_after(void* addr) {
    acquire(addr);
}

ScopedIgnoreSync::ScopedIgnoreSync() {
#if HAS_TSAN
    __tsan_ignore_thread_begin();
#endif
}

ScopedIgnoreSync::~ScopedIgnoreSync() {
#if HAS_TSAN
    __tsan_ignore_thread_end();
#endif
}

} // namespace tsan

// 内存分配器
template<typename T>
T* SanitizerAwareAllocator<T>::allocate(std::size_t n) {
    T* ptr = static_cast<T*>(::operator new(n * sizeof(T)));
#if HAS_MSAN
    __msan_allocated_memory(ptr, n * sizeof(T));
#endif
    return ptr;
}

template<typename T>
void SanitizerAwareAllocator<T>::deallocate(T* p, std::size_t n) {
    ::operator delete(p);
    (void)n;
}

template<typename T>
void SanitizerAwareAllocator<T>::mark_initialized(void* ptr, std::size_t size) {
#if HAS_MSAN
    __msan_unpoison(ptr, size);
#else
    (void)ptr;
    (void)size;
#endif
}

template<typename T>
void SanitizerAwareAllocator<T>::mark_uninitialized(void* ptr, std::size_t size) {
#if HAS_MSAN
    __msan_poison(ptr, size);
#else
    (void)ptr;
    (void)size;
#endif
}

template<typename T>
bool SanitizerAwareAllocator<T>::is_initialized(const void* ptr, std::size_t size) {
#if HAS_MSAN
    return __msan_test_shadow(ptr, size) == -1;
#else
    (void)ptr;
    (void)size;
    return true;
#endif
}

// 显式实例化
template class SanitizerAwareAllocator<char>;
template class SanitizerAwareAllocator<int>;

} // namespace sanitizer
```

**tests/test_memory.cpp**：

```cpp
#include <gtest/gtest.h>
#include "sanitizer_helpers.hpp"
#include <vector>
#include <memory>

class MemorySanitizerTest : public ::testing::Test {
protected:
    void SetUp() override {
        // 记录是否启用了ASan
        asan_enabled_ = sanitizer::is_asan_enabled();
    }

    bool asan_enabled_ = false;
};

// 这些测试故意包含内存错误，用于验证ASan能正确检测

TEST_F(MemorySanitizerTest, HeapBufferOverflow) {
    if (!asan_enabled_) {
        GTEST_SKIP() << "ASan not enabled";
    }

    // 这个测试会被ASan检测到
    // std::vector<int> v(10);
    // v[10] = 42;  // 越界

    // 正确的代码
    std::vector<int> v(10);
    v[9] = 42;
    EXPECT_EQ(v[9], 42);
}

TEST_F(MemorySanitizerTest, StackBufferOverflow) {
    if (!asan_enabled_) {
        GTEST_SKIP() << "ASan not enabled";
    }

    int arr[10];
    for (int i = 0; i < 10; ++i) {
        arr[i] = i;
    }
    EXPECT_EQ(arr[9], 9);
}

TEST_F(MemorySanitizerTest, UseAfterFree) {
    if (!asan_enabled_) {
        GTEST_SKIP() << "ASan not enabled";
    }

    auto ptr = std::make_unique<int>(42);
    int value = *ptr;
    ptr.reset();
    // *ptr = 100;  // 这会被ASan检测到
    EXPECT_EQ(value, 42);
}

TEST_F(MemorySanitizerTest, MemoryLeak) {
    if (!asan_enabled_) {
        GTEST_SKIP() << "ASan not enabled";
    }

    // 故意泄漏（会被LeakSanitizer检测）
    // int* leak = new int(42);

    // 正确的代码
    auto ptr = std::make_unique<int>(42);
    EXPECT_EQ(*ptr, 42);
}

TEST_F(MemorySanitizerTest, DoubleFree) {
    if (!asan_enabled_) {
        GTEST_SKIP() << "ASan not enabled";
    }

    // 双重释放会被检测
    // int* p = new int(42);
    // delete p;
    // delete p;

    // 正确的代码
    auto ptr = std::make_unique<int>(42);
    EXPECT_EQ(*ptr, 42);
}

// 使用ASan API进行自定义检测
TEST_F(MemorySanitizerTest, ManualPoisoning) {
    if (!asan_enabled_) {
        GTEST_SKIP() << "ASan not enabled";
    }

    char buffer[100];

    // 初始状态：可访问
    EXPECT_TRUE(sanitizer::asan::is_accessible(buffer, 100));

    // 毒化一部分
    sanitizer::asan::poison_memory_region(buffer + 50, 50);

    // 前50字节仍可访问
    EXPECT_TRUE(sanitizer::asan::is_accessible(buffer, 50));

    // 后50字节被毒化
    // EXPECT_FALSE(sanitizer::asan::is_accessible(buffer + 50, 50));

    // 解毒
    sanitizer::asan::unpoison_memory_region(buffer + 50, 50);
    EXPECT_TRUE(sanitizer::asan::is_accessible(buffer, 100));
}
```

**tests/test_threading.cpp**：

```cpp
#include <gtest/gtest.h>
#include "sanitizer_helpers.hpp"
#include <thread>
#include <mutex>
#include <shared_mutex>
#include <atomic>
#include <vector>

class ThreadSanitizerTest : public ::testing::Test {
protected:
    void SetUp() override {
        tsan_enabled_ = sanitizer::is_tsan_enabled();
    }
    bool tsan_enabled_ = false;
};

// 正确的互斥锁使用（TSan应该不报错）
TEST_F(ThreadSanitizerTest, MutexProtectedAccess) {
    int shared = 0;
    std::mutex mtx;

    auto writer = [&](int value) {
        std::lock_guard<std::mutex> lock(mtx);
        shared = value;
    };

    std::thread t1(writer, 1);
    std::thread t2(writer, 2);
    t1.join();
    t2.join();

    EXPECT_TRUE(shared == 1 || shared == 2);
}

// 正确的原子变量使用
TEST_F(ThreadSanitizerTest, AtomicAccess) {
    std::atomic<int> counter{0};

    auto increment = [&]() {
        for (int i = 0; i < 1000; ++i) {
            counter.fetch_add(1, std::memory_order_relaxed);
        }
    };

    std::thread t1(increment);
    std::thread t2(increment);
    t1.join();
    t2.join();

    EXPECT_EQ(counter.load(), 2000);
}

// 正确的读写锁使用
TEST_F(ThreadSanitizerTest, SharedMutexAccess) {
    int shared = 42;
    std::shared_mutex rw_mtx;
    std::vector<int> results(4);

    auto reader = [&](int idx) {
        std::shared_lock<std::shared_mutex> lock(rw_mtx);
        results[idx] = shared;
    };

    auto writer = [&](int value) {
        std::unique_lock<std::shared_mutex> lock(rw_mtx);
        shared = value;
    };

    std::thread r1(reader, 0);
    std::thread r2(reader, 1);
    std::thread w1(writer, 100);
    std::thread r3(reader, 2);
    std::thread r4(reader, 3);

    r1.join(); r2.join(); w1.join(); r3.join(); r4.join();
    // 所有读到的值应该是42或100
    for (int val : results) {
        EXPECT_TRUE(val == 42 || val == 100);
    }
}

// 正确的scoped_lock使用（避免死锁）
TEST_F(ThreadSanitizerTest, ScopedLockNonDeadlock) {
    std::mutex mtx_a, mtx_b;
    int resource_a = 0, resource_b = 0;

    auto task1 = [&]() {
        std::scoped_lock lock(mtx_a, mtx_b);
        resource_a = 1;
        resource_b = 1;
    };

    auto task2 = [&]() {
        std::scoped_lock lock(mtx_a, mtx_b);
        resource_a = 2;
        resource_b = 2;
    };

    std::thread t1(task1);
    std::thread t2(task2);
    t1.join();
    t2.join();

    EXPECT_EQ(resource_a, resource_b);
}
```

**tests/test_undefined.cpp**：

```cpp
#include <gtest/gtest.h>
#include <climits>
#include <cstdint>

class UBSanTest : public ::testing::Test {};

// 安全的整数运算（使用__builtin_add_overflow）
TEST_F(UBSanTest, SafeIntegerAdd) {
    int result;
    // INT_MAX + 1 会溢出
    EXPECT_FALSE(!__builtin_add_overflow(INT_MAX, 1, &result));

    // 正常加法
    EXPECT_TRUE(!__builtin_add_overflow(100, 200, &result));
    EXPECT_EQ(result, 300);
}

TEST_F(UBSanTest, SafeIntegerMultiply) {
    int result;
    // INT_MAX * 2 会溢出
    EXPECT_FALSE(!__builtin_mul_overflow(INT_MAX, 2, &result));

    // 正常乘法
    EXPECT_TRUE(!__builtin_mul_overflow(100, 200, &result));
    EXPECT_EQ(result, 20000);
}

// 安全的移位操作
TEST_F(UBSanTest, SafeShift) {
    // 确保移位量在有效范围内
    auto safe_left_shift = [](int value, int shift) -> int {
        if (shift < 0 || shift >= static_cast<int>(sizeof(int) * 8)) {
            return 0;  // 无效移位返回0
        }
        if (value < 0) {
            return 0;  // 负数左移是UB
        }
        return value << shift;
    };

    EXPECT_EQ(safe_left_shift(1, 4), 16);
    EXPECT_EQ(safe_left_shift(1, 31), (1 << 31));  // 最大合法左移
    EXPECT_EQ(safe_left_shift(1, 32), 0);  // 越界，安全返回0
    EXPECT_EQ(safe_left_shift(1, -1), 0);  // 负移位，安全返回0
}

// 安全的除法
TEST_F(UBSanTest, SafeDivision) {
    auto safe_divide = [](int a, int b) -> std::pair<bool, int> {
        if (b == 0) return {false, 0};
        if (a == INT_MIN && b == -1) return {false, 0};  // INT_MIN / -1 溢出
        return {true, a / b};
    };

    auto [ok1, r1] = safe_divide(10, 3);
    EXPECT_TRUE(ok1);
    EXPECT_EQ(r1, 3);

    auto [ok2, r2] = safe_divide(10, 0);
    EXPECT_FALSE(ok2);

    auto [ok3, r3] = safe_divide(INT_MIN, -1);
    EXPECT_FALSE(ok3);
}

// 安全的类型转换
TEST_F(UBSanTest, SafeFloatToInt) {
    auto safe_float_to_int = [](double d) -> std::pair<bool, int> {
        if (d > static_cast<double>(INT_MAX) ||
            d < static_cast<double>(INT_MIN) ||
            std::isnan(d)) {
            return {false, 0};
        }
        return {true, static_cast<int>(d)};
    };

    auto [ok1, r1] = safe_float_to_int(3.14);
    EXPECT_TRUE(ok1);
    EXPECT_EQ(r1, 3);

    auto [ok2, r2] = safe_float_to_int(1e100);
    EXPECT_FALSE(ok2);
}
```

**scripts/run_all_sanitizers.sh**：

```bash
#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Running all sanitizer tests...${NC}"

# ASan测试
echo -e "\n${YELLOW}=== AddressSanitizer ===${NC}"
cmake -B "$BUILD_DIR/asan" -S "$PROJECT_DIR" \
    -DCMAKE_BUILD_TYPE=Debug \
    -DENABLE_ASAN=ON \
    -DBUILD_TESTS=ON
cmake --build "$BUILD_DIR/asan" --parallel
ASAN_OPTIONS=detect_leaks=1:halt_on_error=0 \
    ctest --test-dir "$BUILD_DIR/asan" --output-on-failure || true

# TSan测试
echo -e "\n${YELLOW}=== ThreadSanitizer ===${NC}"
cmake -B "$BUILD_DIR/tsan" -S "$PROJECT_DIR" \
    -DCMAKE_BUILD_TYPE=Debug \
    -DENABLE_TSAN=ON \
    -DBUILD_TESTS=ON
cmake --build "$BUILD_DIR/tsan" --parallel
TSAN_OPTIONS=halt_on_error=0 \
    ctest --test-dir "$BUILD_DIR/tsan" --output-on-failure || true

# UBSan测试
echo -e "\n${YELLOW}=== UndefinedBehaviorSanitizer ===${NC}"
cmake -B "$BUILD_DIR/ubsan" -S "$PROJECT_DIR" \
    -DCMAKE_BUILD_TYPE=Debug \
    -DENABLE_UBSAN=ON \
    -DBUILD_TESTS=ON
cmake --build "$BUILD_DIR/ubsan" --parallel
UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=0 \
    ctest --test-dir "$BUILD_DIR/ubsan" --output-on-failure || true

echo -e "\n${GREEN}All sanitizer tests completed!${NC}"
```

---

## 月度验收标准

### 知识验收（10项）

1. - [ ] 能够解释ASan的Shadow Memory映射原理（1字节Shadow对应8字节应用内存，Shadow值含义表）
2. - [ ] 能够描述ASan的Red Zone机制（堆分配前后添加毒化区域，free后整体毒化+隔离队列延迟重分配）
3. - [ ] 能够解释TSan的Happens-Before关系模型和Vector Clock算法如何推导访问顺序
4. - [ ] 能够说明数据竞争（data race）的C++标准定义：两个线程并发访问同一内存位置，至少一个是写操作，且无同步关系
5. - [ ] 能够区分数据竞争（data race）、竞态条件（race condition）和原子性违规（atomicity violation）
6. - [ ] 能够列举UBSan的至少14种子检查器，说明哪些在-fsanitize=undefined中默认启用
7. - [ ] 能够解释编译器如何利用未定义行为进行优化（以signed-integer-overflow消除边界检查为例）
8. - [ ] 能够说明MSan的特殊性：需要instrumented libc++，仅Clang支持，与ASan/TSan互斥
9. - [ ] 能够画出四种Sanitizer的互斥关系图（ASan↔TSan互斥，ASan↔MSan互斥，TSan↔MSan互斥，UBSan与所有兼容）
10. - [ ] 能够解释为什么CI推荐ASan+UBSan / TSan / MSan三组并行而非合并运行

### 实践验收（10项）

1. - [ ] 编写代码触发ASan检测的9种内存错误（堆溢出/栈溢出/全局溢出/UAF/返回后使用/作用域外/双释放/泄漏/初始化顺序），并能修复
2. - [ ] 编写代码触发TSan检测的4种竞争场景（写-写/读-写/锁顺序反转/信号竞争），并使用mutex/atomic/scoped_lock修复
3. - [ ] 编写代码触发UBSan检测的至少10种未定义行为，理解每种的危害
4. - [ ] 编写代码触发MSan检测的3种未初始化内存使用（栈变量/堆内存/参数传播）
5. - [ ] 完成Sanitizers.cmake模块编写，支持4种Sanitizer互斥检测和CTest集成
6. - [ ] 编写CMakePresets.json包含asan/tsan/msan三套configure+build+test预设
7. - [ ] 编写GitHub Actions workflow实现三种Sanitizer并行CI检测
8. - [ ] 编写ASan/TSan/UBSan的抑制文件（suppressions）和源码级__attribute__标注
9. - [ ] 使用TSan注解API（__tsan_acquire/__tsan_release）标注一个自定义同步原语
10. - [ ] 完成sanitizer-framework实践项目，包含helpers/tests/examples/scripts全套

---

## 知识地图

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                Month 44: Sanitizers运行时检测 知识地图                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│                        ┌───────────────────┐                               │
│                        │   Sanitizers      │                               │
│                        │   运行时检测      │                               │
│                        └─────────┬─────────┘                               │
│                                  │                                          │
│          ┌───────────────┬───────┴───────┬───────────────┐                 │
│          │               │               │               │                 │
│          ▼               ▼               ▼               ▼                 │
│  ┌──────────────┐ ┌────────────┐ ┌────────────┐ ┌──────────────┐         │
│  │   ASan       │ │   TSan     │ │   UBSan    │ │   MSan       │         │
│  │  (Week 1)    │ │  (Week 2)  │ │  (Week 3)  │ │  (Week 4)    │         │
│  └──────┬───────┘ └─────┬──────┘ └─────┬──────┘ └──────┬───────┘         │
│         │               │               │               │                 │
│  ┌──────┴──────┐ ┌──────┴──────┐ ┌─────┴──────┐ ┌──────┴──────┐         │
│  │ Shadow      │ │ Vector     │ │ 14种子     │ │ Shadow bit  │         │
│  │  Memory映射 │ │  Clock算法 │ │  检查器    │ │  跟踪       │         │
│  │ Red Zone    │ │ Happens-   │ │ ASan+UBSan │ │ 需要        │         │
│  │  机制       │ │  Before    │ │  组合使用  │ │  instrument │         │
│  │ 9大内存     │ │ 4类竞争    │ │ -fno-      │ │  ed libc++  │         │
│  │  错误类型   │ │  场景      │ │  sanitize- │ │ 仅Clang     │         │
│  │ LeakSan    │ │ TSan注解   │ │  recover   │ │  支持       │         │
│  │ 抑制文件   │ │  API       │ │ 防御性编程 │ │ MSan API    │         │
│  │ ASan API   │ │ 抑制文件   │ │ 安全运算   │ │             │         │
│  └─────────────┘ └────────────┘ └────────────┘ └─────────────┘         │
│                                                                             │
│  工程集成:                                                                   │
│  ┌─────────────────────────────────────────────────────────────────┐      │
│  │ CMake模块 → Sanitizers.cmake（互斥检测+CTest集成）             │      │
│  │ CMake预设 → CMakePresets.json（asan/tsan/msan三套）            │      │
│  │ CI/CD    → GitHub Actions（三组并行: ASan+UBSan / TSan / MSan）│      │
│  │ 抑制管理 → suppressions文件 + __attribute__ + API标注          │      │
│  └─────────────────────────────────────────────────────────────────┘      │
│                                                                             │
│  关联知识:                                                                   │
│  ┌─────────────────────────────────────────────────────────────────┐      │
│  │ Month 37(CMake) → CMake模块和Presets基础                        │      │
│  │ Month 40(CI/CD) → GitHub Actions workflow编写                   │      │
│  │ Month 42(测试)  → 单元测试驱动Sanitizer检测                     │      │
│  │ Month 43(Clang-Tidy) → 静态分析互补，编译期vs运行期             │      │
│  │ Month 45(Profiling)  → 从正确性检测到性能分析                   │      │
│  └─────────────────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 完整输出物清单

| # | 类别 | 输出物 | 说明 |
|---|------|--------|------|
| 1 | 笔记 | notes/sanitizer_overview.md | Sanitizer家族概述与互斥关系 |
| 2 | 笔记 | notes/asan_internals.md | ASan Shadow Memory与Red Zone原理 |
| 3 | 笔记 | notes/week1_asan.md | Week 1 ASan学习总结 |
| 4 | 笔记 | notes/tsan_internals.md | TSan Happens-Before与Vector Clock |
| 5 | 笔记 | notes/data_race_theory.md | 数据竞争理论与C++内存模型 |
| 6 | 笔记 | notes/week2_tsan.md | Week 2 TSan学习总结 |
| 7 | 笔记 | notes/undefined_behavior.md | UB概念、分类与真实案例 |
| 8 | 笔记 | notes/ubsan_internals.md | UBSan原理与子检查器参考 |
| 9 | 笔记 | notes/week3_ubsan.md | Week 3 UBSan学习总结 |
| 10 | 笔记 | notes/msan_internals.md | MSan原理与特殊要求 |
| 11 | 笔记 | notes/sanitizer_performance.md | 四种Sanitizer性能影响对比 |
| 12 | 笔记 | notes/month44_sanitizers.md | 月度总结与最佳实践 |
| 13 | 实践 | practice/asan_basic/ | ASan基本编译与配置 |
| 14 | 实践 | practice/heap_errors/ | 堆内存错误检测（4种） |
| 15 | 实践 | practice/stack_global_errors/ | 栈/全局错误检测（4种） |
| 16 | 实践 | practice/leak_detection/ | LeakSanitizer内存泄漏检测 |
| 17 | 实践 | practice/write_write_race/ | 写-写竞争检测与修复 |
| 18 | 实践 | practice/read_write_race/ | 读-写竞争检测与修复 |
| 19 | 实践 | practice/lock_order/ | 锁顺序反转检测与修复 |
| 20 | 实践 | practice/advanced_races/ | 高级竞争场景与TSan注解 |
| 21 | 实践 | practice/integer_ub/ | 整数类未定义行为检测 |
| 22 | 实践 | practice/pointer_type_ub/ | 指针/类型未定义行为检测 |
| 23 | 实践 | practice/cast_misc_ub/ | 转换与其他UB检测 |
| 24 | 实践 | practice/ubsan_combined/ | UBSan+ASan组合使用 |
| 25 | 实践 | practice/msan_examples/ | MSan未初始化内存检测 |
| 26 | 配置 | cmake/Sanitizers.cmake | 可复用CMake Sanitizer模块 |
| 27 | 配置 | CMakePresets.json | Sanitizer构建/测试预设 |
| 28 | CI | .github/workflows/sanitizers.yml | 多Sanitizer并行CI工作流 |
| 29 | 脚本 | scripts/run_all_sanitizers.sh | 本地全量Sanitizer测试脚本 |
| 30 | 项目 | sanitizer-framework/ | 完整Sanitizer集成框架项目 |

---

## 详细时间分配表

| 周次 | 主题 | 理论学习 | 实践编码 | 源码阅读 | 小计 |
|------|------|----------|----------|----------|------|
| **Week 1** | **AddressSanitizer** | | | | **35h** |
| Day 1 | Sanitizer概述 | 3h | 1.5h | 0.5h | 5h |
| Day 2 | ASan工作原理 | 3h | 1h | 1h | 5h |
| Day 3 | ASan编译与配置 | 1h | 3.5h | 0.5h | 5h |
| Day 4 | 堆内存错误 | 1h | 3.5h | 0.5h | 5h |
| Day 5 | 栈与全局错误 | 1h | 3.5h | 0.5h | 5h |
| Day 6 | LSan与高级检测 | 1.5h | 3h | 0.5h | 5h |
| Day 7 | 报告解读与源码 | 1.5h | 1h | 2.5h | 5h |
| **Week 2** | **ThreadSanitizer** | | | | **35h** |
| Day 8 | TSan工作原理 | 3h | 1h | 1h | 5h |
| Day 9 | 数据竞争定义 | 3h | 1.5h | 0.5h | 5h |
| Day 10 | 写-写竞争 | 1h | 3.5h | 0.5h | 5h |
| Day 11 | 读-写竞争 | 1h | 3.5h | 0.5h | 5h |
| Day 12 | 锁顺序与死锁 | 1.5h | 3h | 0.5h | 5h |
| Day 13 | 高级竞争场景 | 1.5h | 3h | 0.5h | 5h |
| Day 14 | 报告解读与总结 | 1.5h | 1h | 2.5h | 5h |
| **Week 3** | **UBSan** | | | | **35h** |
| Day 15 | 未定义行为概论 | 3h | 1.5h | 0.5h | 5h |
| Day 16 | UBSan原理与配置 | 2.5h | 2h | 0.5h | 5h |
| Day 17 | 整数类UB | 1h | 3.5h | 0.5h | 5h |
| Day 18 | 指针/类型UB | 1h | 3.5h | 0.5h | 5h |
| Day 19 | 转换/其他UB | 1h | 3.5h | 0.5h | 5h |
| Day 20 | 组合使用 | 1.5h | 3h | 0.5h | 5h |
| Day 21 | 防御性编程与总结 | 2h | 1h | 2h | 5h |
| **Week 4** | **MSan与综合集成** | | | | **35h** |
| Day 22 | MSan原理 | 2.5h | 2h | 0.5h | 5h |
| Day 23 | MSan实践 | 1h | 3.5h | 0.5h | 5h |
| Day 24 | 性能影响分析 | 2h | 2.5h | 0.5h | 5h |
| Day 25 | CMake模块深化 | 1h | 3.5h | 0.5h | 5h |
| Day 26 | CI/CD完整方案 | 1h | 3.5h | 0.5h | 5h |
| Day 27 | 实践项目完善 | 0.5h | 4h | 0.5h | 5h |
| Day 28 | 月度总结 | 2h | 1h | 2h | 5h |
| | | | | | |
| **合计** | | **44h** | **76h** | **20h** | **140h** |

---

## 下月预告

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Month 44 → Month 45 衔接                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Month 44: Sanitizers运行时检测        Month 45: 性能分析与Profiling        │
│  ┌───────────────────────┐             ┌───────────────────────┐           │
│  │ • 检测正确性问题       │             │ • 分析性能问题         │           │
│  │ • 内存错误/数据竞争   │             │ • CPU热点/内存分配    │           │
│  │ • 未定义行为/未初始化 │  从正确性    │ • I/O瓶颈/锁争用     │           │
│  │ • 编译时插桩检测      │ ──────────▶ │ • 采样/插桩/追踪      │           │
│  │ • 零误报/有开销       │  到性能     │ • perf/VTune/gprof    │           │
│  │ • "程序正确吗？"      │             │ • "程序快吗？"         │           │
│  └───────────────────────┘             └───────────────────────┘           │
│                                                                             │
│  衔接知识点：                                                               │
│  ┌─────────────────────────────────────────────────────────────────┐      │
│  │ 1. Sanitizer的性能开销分析 → Profiler量化开销来源              │      │
│  │ 2. TSan检测锁争用 → Profiler分析锁等待时间和热点              │      │
│  │ 3. ASan的内存开销 → 内存Profiler分析分配模式                   │      │
│  │ 4. CMake Sanitizer预设 → CMake Profiling预设                   │      │
│  │ 5. CI中Sanitizer检测 → CI中性能回归检测                        │      │
│  └─────────────────────────────────────────────────────────────────┘      │
│                                                                             │
│  Month 45 预览：                                                            │
│  ┌─────────────────────────────────────────────────────────────────┐      │
│  │ Week 1: CPU Profiling — perf/gprof/callgrind                    │      │
│  │         采样分析/火焰图/调用图/热点函数定位                     │      │
│  │ Week 2: 内存Profiling — Valgrind Massif/heaptrack               │      │
│  │         分配模式/泄漏追踪/碎片分析/峰值分析                     │      │
│  │ Week 3: 系统级分析 — strace/ltrace/perf stat                    │      │
│  │         系统调用/缓存未命中/分支预测/IPC                        │      │
│  │ Week 4: Benchmark框架 — Google Benchmark/综合实践               │      │
│  │         微基准/宏基准/回归检测/CI性能追踪                       │      │
│  └─────────────────────────────────────────────────────────────────┘      │
│                                                                             │
│  完整的C++代码质量保障链（更新版）：                                         │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐     │
│  │编码规范│▶│静态分析│▶│单元测试│▶│运行时  │▶│性能    │▶│持续    │     │
│  │clang-  │ │clang-  │ │GTest/  │ │检测    │ │分析    │ │监控    │     │
│  │format  │ │tidy    │ │Catch2  │ │ASan/   │ │perf/   │ │指标/   │     │
│  │        │ │(M43)   │ │(M42)   │ │TSan/   │ │VTune   │ │报警    │     │
│  │        │ │        │ │        │ │UBSan   │ │(M45)   │ │(未来)  │     │
│  │        │ │        │ │        │ │(M44)   │ │        │ │        │     │
│  └────────┘ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘     │
│   编译前      编译期      测试期      运行期      优化期      生产期      │
└─────────────────────────────────────────────────────────────────────────────┘
```

Month 45将学习**性能分析与Profiling（perf/Valgrind/Google Benchmark）**，从代码正确性保障迈向性能优化，掌握CPU/内存/系统级分析工具，构建完整的C++代码质量保障体系。
