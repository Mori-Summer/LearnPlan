# Month 07: 异常安全与错误处理——构建健壮的C++代码

## 本月主题概述

异常是C++错误处理的核心机制，但也是最容易被误用的特性之一。本月将深入理解异常的底层实现、异常安全等级，掌握编写异常安全代码的技术，并探索现代C++的错误处理替代方案。

**核心哲学**：异常安全不是一种技术，而是一种思维方式。它要求我们在编写每一行代码时都思考："如果这里抛出异常，会发生什么？"

---

## 第一周：异常的底层实现（35小时）

> **本周核心问题**：为什么说异常是"零成本"的？这个"零"究竟指什么？

### 学习目标
- [ ] 理解零成本异常模型的完整工作原理
- [ ] 掌握栈展开（Stack Unwinding）的详细过程
- [ ] 了解不同平台的异常实现差异
- [ ] 能够使用工具观察和分析异常表

### 每日学习安排

#### Day 1-2: 异常处理的历史演进（6小时）

**学习内容**：

```
异常处理模型的演进：
┌─────────────────────────────────────────────────────────────┐
│  1. setjmp/longjmp 时代                                      │
│     - 手动保存/恢复寄存器状态                                  │
│     - 不调用析构函数，资源泄漏                                 │
│     - 性能：正常路径有开销                                     │
├─────────────────────────────────────────────────────────────┤
│  2. SJLJ (SetJmp/LongJmp) 异常模型                           │
│     - 编译器自动插入setjmp调用                                 │
│     - 正确调用析构函数                                         │
│     - 性能：每个try块都有开销（约5%）                          │
├─────────────────────────────────────────────────────────────┤
│  3. 零成本异常模型（Table-Based）                             │
│     - 编译时生成异常处理表                                     │
│     - 正常路径零开销                                           │
│     - 抛出时查表处理（开销大但罕见）                           │
└─────────────────────────────────────────────────────────────┘
```

**代码示例**：理解setjmp/longjmp的问题
```cpp
#include <csetjmp>
#include <iostream>

std::jmp_buf jump_buffer;

class Resource {
public:
    Resource() { std::cout << "Resource acquired\n"; }
    ~Resource() { std::cout << "Resource released\n"; }  // 不会被调用！
};

void dangerous_function() {
    Resource r;
    std::longjmp(jump_buffer, 1);  // 直接跳转，不调用析构函数
}

void demo_longjmp_problem() {
    if (setjmp(jump_buffer) == 0) {
        dangerous_function();
    } else {
        std::cout << "Jumped back, but Resource leaked!\n";
    }
}

// 对比：C++异常正确处理析构
void proper_exception() {
    try {
        Resource r;
        throw std::runtime_error("error");
        // r的析构函数会被正确调用
    } catch (...) {
        std::cout << "Exception caught, Resource properly released\n";
    }
}
```

**阅读材料**：
- [ ] "The Design and Evolution of C++" - Stroustrup关于异常设计的章节
- [ ] GCC Wiki: Exception Handling

---

#### Day 3-4: 零成本异常模型详解（8小时）

**学习内容**：

```
零成本异常模型的"成本"分析：
┌──────────────────────────────────────────────────────────────┐
│                    "零成本"的真正含义                          │
├──────────────────────────────────────────────────────────────┤
│  ✓ 正常执行路径：无运行时开销（无额外指令）                      │
│  ✓ 不需要每个函数入口保存状态                                   │
│  ✓ 不需要每个try块执行特殊代码                                  │
├──────────────────────────────────────────────────────────────┤
│  ✗ 代码体积：增加（异常表占用空间）                             │
│  ✗ 抛出异常：开销很大（查表 + 栈展开）                          │
│  ✗ 编译时间：增加（需要生成异常表）                             │
└──────────────────────────────────────────────────────────────┘
```

**核心概念深入**：

```cpp
// 零成本异常模型的核心思想
// 编译器为每个函数生成两部分信息：

// 1. 正常代码（完全不涉及异常处理）
void normal_function() {
    std::string s = "hello";
    process(s);
}

// 2. 异常处理表（存储在只读数据段）
// 伪代码表示：
/*
.gcc_except_table:
  normal_function:
    try_range: [0x1000, 0x1050]      // try块的代码范围
    landing_pad: 0x1100               // catch块入口
    type_info: std::exception*        // 捕获的类型
    cleanup_actions:
      - call ~string() at offset 0x20 // 需要析构的对象
*/
```

**异常处理表的详细结构**：
```cpp
// LSDA (Language Specific Data Area) 结构
struct LSDA {
    // 头部
    uint8_t landing_pad_base_encoding;
    uint8_t type_table_encoding;

    // Call Site Table（调用点表）
    // 记录每个可能抛异常的调用点
    struct CallSite {
        uintptr_t start;       // 代码起始位置
        uintptr_t length;      // 代码长度
        uintptr_t landing_pad; // 异常处理入口（0表示无处理）
        uintptr_t action;      // 动作索引
    };

    // Action Table（动作表）
    // 记录每个catch块的类型过滤器
    struct Action {
        int type_filter;    // 正数：catch类型索引
                            // 0：cleanup（只需析构）
                            // 负数：异常规范过滤
        int next_action;    // 链表，指向下一个动作
    };

    // Type Table（类型表）
    // 存储std::type_info指针
    const std::type_info* types[];
};
```

**实验：观察异常表**：
```bash
# 编译带异常处理的代码
g++ -c exception_demo.cpp -o exception_demo.o

# 查看异常表
readelf --debug-dump=frames exception_demo.o

# 查看LSDA
objdump -s -j .gcc_except_table exception_demo.o

# 使用c++filt解析符号
nm exception_demo.o | c++filt
```

---

#### Day 5-6: 栈展开（Stack Unwinding）详解（8小时）

**学习内容**：

```
栈展开的完整流程：
┌─────────────────────────────────────────────────────────────────┐
│  throw std::runtime_error("error")                              │
│      │                                                          │
│      ▼                                                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 1. __cxa_allocate_exception()                            │   │
│  │    分配异常对象内存（通常从异常缓冲区）                     │   │
│  └─────────────────────────────────────────────────────────┘   │
│      │                                                          │
│      ▼                                                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 2. 构造异常对象                                          │   │
│  │    在分配的内存中构造runtime_error                        │   │
│  └─────────────────────────────────────────────────────────┘   │
│      │                                                          │
│      ▼                                                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 3. __cxa_throw()                                         │   │
│  │    - 保存异常对象指针                                     │   │
│  │    - 保存类型信息                                         │   │
│  │    - 调用_Unwind_RaiseException()                        │   │
│  └─────────────────────────────────────────────────────────┘   │
│      │                                                          │
│      ▼                                                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 4. _Unwind_RaiseException() - 第一阶段：搜索              │   │
│  │    遍历调用栈，查找匹配的catch块                          │   │
│  │    不执行任何cleanup，只是查找                            │   │
│  └─────────────────────────────────────────────────────────┘   │
│      │                                                          │
│      ▼                                                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 5. _Unwind_RaiseException() - 第二阶段：清理              │   │
│  │    从throw点到catch点，逐帧执行cleanup                    │   │
│  │    调用所有局部对象的析构函数                             │   │
│  └─────────────────────────────────────────────────────────┘   │
│      │                                                          │
│      ▼                                                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 6. 跳转到Landing Pad（catch块入口）                      │   │
│  │    执行catch块代码                                        │   │
│  └─────────────────────────────────────────────────────────┘   │
│      │                                                          │
│      ▼                                                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 7. __cxa_end_catch()                                     │   │
│  │    - 减少异常引用计数                                     │   │
│  │    - 必要时析构异常对象                                   │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

**代码示例**：栈展开过程可视化
```cpp
#include <iostream>
#include <stdexcept>

class Tracer {
    const char* name_;
public:
    Tracer(const char* name) : name_(name) {
        std::cout << "  [构造] " << name_ << "\n";
    }
    ~Tracer() {
        std::cout << "  [析构] " << name_ << "\n";
    }
};

void level3() {
    Tracer t("level3_object");
    std::cout << "level3: 即将抛出异常\n";
    throw std::runtime_error("error from level3");
}

void level2() {
    Tracer t("level2_object");
    std::cout << "level2: 调用level3\n";
    level3();
    std::cout << "level2: level3返回（不会执行）\n";
}

void level1() {
    Tracer t("level1_object");
    std::cout << "level1: 调用level2\n";
    try {
        level2();
    } catch (const std::exception& e) {
        std::cout << "level1: 捕获异常: " << e.what() << "\n";
    }
    std::cout << "level1: 继续执行\n";
}

int main() {
    std::cout << "main: 开始\n";
    level1();
    std::cout << "main: 结束\n";
    return 0;
}

/* 输出：
main: 开始
  [构造] level1_object
level1: 调用level2
  [构造] level2_object
level2: 调用level3
  [构造] level3_object
level3: 即将抛出异常
  [析构] level3_object    // 栈展开开始
  [析构] level2_object    // 逐层析构
level1: 捕获异常: error from level3
level1: 继续执行
  [析构] level1_object
main: 结束
*/
```

**两阶段栈展开的原因**：
```cpp
// 为什么需要两阶段？

// 考虑这种情况：
void outer() {
    try {
        middle();
    } catch (const SpecificException& e) {
        // 处理特定异常
    }
    // 注意：没有catch(...)
}

void middle() {
    Resource r;  // 有析构函数
    inner();     // 可能抛异常
}

void inner() {
    throw SomeOtherException();  // 抛出不同类型的异常
}

// 如果只有一阶段（边析构边查找）：
// 1. inner抛出SomeOtherException
// 2. middle的Resource被析构
// 3. outer的catch不匹配
// 4. 继续向上...
// 问题：如果最终没人捕获，Resource已经被析构了！

// 两阶段解决这个问题：
// 第一阶段：只查找，不析构
// - 如果找到匹配的catch，记住位置
// - 如果找不到，调用std::terminate()，此时对象仍完整
// 第二阶段：只有确认有catch时才析构
```

---

#### Day 7: 平台实现对比与性能分析（7小时）

**各平台实现对比**：

```
┌────────────────┬─────────────────┬─────────────────┬─────────────────┐
│     特性        │  Itanium ABI    │  Windows SEH    │  SJLJ           │
│                │  (Linux/macOS)  │  (Windows x64)  │  (老平台/嵌入式) │
├────────────────┼─────────────────┼─────────────────┼─────────────────┤
│ 正常路径开销    │  零              │  零             │  有（~5%）       │
├────────────────┼─────────────────┼─────────────────┼─────────────────┤
│ 异常抛出开销    │  高              │  中等           │  低             │
├────────────────┼─────────────────┼─────────────────┼─────────────────┤
│ 代码大小        │  增加15-30%     │  增加10-20%     │  增加5-10%      │
├────────────────┼─────────────────┼─────────────────┼─────────────────┤
│ 兼容性          │  需ABI兼容      │  Windows原生    │  最好           │
├────────────────┼─────────────────┼─────────────────┼─────────────────┤
│ 调试支持        │  好              │  很好           │  一般           │
└────────────────┴─────────────────┴─────────────────┴─────────────────┘
```

**性能基准测试**：
```cpp
#include <chrono>
#include <iostream>
#include <stdexcept>

// 测试1：正常路径（不抛异常）
void no_throw_function(int x) {
    if (x < 0) {
        throw std::runtime_error("negative");
    }
}

// 测试2：使用返回值
bool return_code_function(int x) {
    return x >= 0;
}

// 基准测试框架
template <typename Func>
double benchmark(Func f, int iterations) {
    auto start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < iterations; ++i) {
        f();
    }
    auto end = std::chrono::high_resolution_clock::now();
    return std::chrono::duration<double, std::milli>(end - start).count();
}

void run_benchmarks() {
    constexpr int ITERATIONS = 10'000'000;

    // 测试正常路径（不抛异常）
    double time_exception = benchmark([]{
        try {
            no_throw_function(42);
        } catch (...) {}
    }, ITERATIONS);

    double time_return = benchmark([]{
        return_code_function(42);
    }, ITERATIONS);

    std::cout << "正常路径 - 异常版本: " << time_exception << " ms\n";
    std::cout << "正常路径 - 返回值版本: " << time_return << " ms\n";

    // 测试异常路径
    constexpr int THROW_ITERATIONS = 100'000;

    double time_throwing = benchmark([]{
        try {
            no_throw_function(-1);
        } catch (...) {}
    }, THROW_ITERATIONS);

    std::cout << "抛出异常: " << time_throwing << " ms "
              << "(" << THROW_ITERATIONS << " 次)\n";
    std::cout << "平均每次抛出: " << (time_throwing / THROW_ITERATIONS * 1000)
              << " μs\n";
}
```

**实验结果参考**（实际数值因平台而异）：
```
典型结果（x86-64 Linux, GCC -O2）：
正常路径 - 异常版本: 15 ms (10M次)
正常路径 - 返回值版本: 15 ms (10M次)
→ 正常路径确实"零成本"

抛出异常: 850 ms (100K次)
平均每次抛出: 8.5 μs
→ 抛出异常开销约为普通函数调用的1000倍
```

### 第一周源码阅读

**阅读清单**：
- [ ] `libstdc++-v3/libsupc++/eh_throw.cc` - `__cxa_throw`实现
- [ ] `libstdc++-v3/libsupc++/eh_catch.cc` - `__cxa_begin_catch`/`__cxa_end_catch`
- [ ] `libstdc++-v3/libsupc++/unwind-cxx.h` - 异常对象结构

**关键数据结构**：
```cpp
// libsupc++/unwind-cxx.h 中的异常头
struct __cxa_exception {
    std::type_info* exceptionType;      // 异常类型
    void (*exceptionDestructor)(void*); // 析构函数
    std::unexpected_handler unexpectedHandler;
    std::terminate_handler terminateHandler;
    __cxa_exception* nextException;     // 链表（嵌套异常）
    int handlerCount;                    // 引用计数
    int handlerSwitchValue;
    const char* actionRecord;
    const char* languageSpecificData;
    void* catchTemp;
    void* adjustedPtr;
    _Unwind_Exception unwindHeader;     // libunwind头
};

// 异常对象紧跟在这个头之后
// actual_exception = (char*)header + sizeof(__cxa_exception)
```

### 第一周思考题

1. **基础理解**
   - 为什么"零成本异常"仍然会增加可执行文件大小？
   - 如果一个函数标记为`noexcept`但内部抛出了异常，会发生什么？

2. **深入思考**
   - 在什么场景下SJLJ模型比零成本模型更合适？
   - 为什么栈展开需要两个阶段？如果只有一个阶段会有什么问题？

3. **实践问题**
   - 如何测量你的项目中异常处理表占用了多少空间？
   - 异常对象存储在哪里？为什么不能存储在栈上？

### 第一周实践练习

**练习1**：编写程序观察异常表
```cpp
// exception_table_demo.cpp
// 编译后用readelf分析
```

**练习2**：实现简化版的栈展开追踪器
```cpp
// 提示：利用__cxa_throw可以被替换的特性
extern "C" void __cxa_throw(void* thrown_exception,
                            std::type_info* tinfo,
                            void (*dest)(void*));
```

---

## 第二周：异常安全等级（35小时）

> **本周核心问题**：如何系统性地分析和保证代码的异常安全性？

### 学习目标
- [ ] 深入理解四种异常安全等级的精确定义
- [ ] 掌握分析代码异常安全等级的方法论
- [ ] 理解STL容器的异常安全保证
- [ ] 正确使用`noexcept`说明符

### 每日学习安排

#### Day 1-2: 四种异常安全等级深入（8小时）

**精确定义**：

```
异常安全等级的形式化定义：
┌─────────────────────────────────────────────────────────────────┐
│ 设 S₀ 为调用前的程序状态，S₁ 为调用后的程序状态                  │
│ 设 R 为资源集合（内存、文件句柄、锁等）                          │
├─────────────────────────────────────────────────────────────────┤
│ 1. 无保证 (No Guarantee)                                        │
│    - 抛出异常后，S₁ 可能是任意状态                               │
│    - 可能存在 r ∈ R 未被正确释放                                 │
│    - 程序行为未定义                                              │
├─────────────────────────────────────────────────────────────────┤
│ 2. 基本保证 (Basic Guarantee)                                   │
│    - S₁ 是某个有效状态（可能 ≠ S₀）                              │
│    - ∀r ∈ R: r 被正确管理（无泄漏）                              │
│    - 所有对象的不变式保持                                        │
├─────────────────────────────────────────────────────────────────┤
│ 3. 强保证 (Strong Guarantee)                                    │
│    - 要么 S₁ = 期望的新状态（成功）                              │
│    - 要么 S₁ = S₀（失败，完全回滚）                              │
│    - 事务语义：all-or-nothing                                    │
├─────────────────────────────────────────────────────────────────┤
│ 4. 不抛保证 (No-throw Guarantee)                                │
│    - 函数永远不抛出异常                                          │
│    - 必须成功完成                                                │
│    - 通常用于：析构函数、swap、移动操作                          │
└─────────────────────────────────────────────────────────────────┘
```

**完整案例分析**：

```cpp
// ========== 案例1：无保证的代码 ==========
class BadVector {
    int* data_;
    size_t size_;
    size_t capacity_;

public:
    void push_back(int value) {
        if (size_ == capacity_) {
            // 危险：如果new失败，data_指向已delete的内存
            delete[] data_;                    // ❌ 先删除旧数据
            capacity_ *= 2;
            data_ = new int[capacity_];        // ❌ 可能抛异常
            // 更严重：旧数据已丢失，无法恢复！
        }
        data_[size_++] = value;
    }
};

// ========== 案例2：基本保证的代码 ==========
class BasicVector {
    int* data_;
    size_t size_;
    size_t capacity_;

public:
    void push_back(int value) {
        if (size_ == capacity_) {
            size_t new_cap = capacity_ * 2;
            int* new_data = new int[new_cap];  // ✓ 先分配新内存

            // 复制旧数据（如果int改成复杂类型，这里可能抛异常）
            for (size_t i = 0; i < size_; ++i) {
                new_data[i] = data_[i];
            }

            delete[] data_;                     // ✓ 后删除旧数据
            data_ = new_data;
            capacity_ = new_cap;
        }
        data_[size_++] = value;
        // 基本保证：如果中途失败，对象仍有效，但size_可能已变
    }
};

// ========== 案例3：强保证的代码 ==========
class StrongVector {
    int* data_;
    size_t size_;
    size_t capacity_;

public:
    void push_back(int value) {
        if (size_ == capacity_) {
            size_t new_cap = capacity_ * 2;
            int* new_data = new int[new_cap];  // 可能抛异常

            try {
                for (size_t i = 0; i < size_; ++i) {
                    new_data[i] = data_[i];     // 对于复杂类型可能抛异常
                }
            } catch (...) {
                delete[] new_data;              // 清理
                throw;                          // 重新抛出，状态未改变
            }

            delete[] data_;
            data_ = new_data;
            capacity_ = new_cap;
        }

        // 到这里扩容已成功，下面的赋值对int不会失败
        data_[size_++] = value;
    }

    // 更优雅的强保证实现：copy-and-swap
    void push_back_strong(int value) {
        StrongVector temp(*this);    // 复制（可能抛异常）
        temp.data_[temp.size_++] = value;
        if (temp.size_ > temp.capacity_) {
            // ... 扩容逻辑 ...
        }
        swap(*this, temp);           // noexcept，不会失败
    }
};

// ========== 案例4：不抛保证的代码 ==========
class NoThrowVector {
    int* data_;
    size_t size_;
    size_t capacity_;

public:
    // 析构函数必须是noexcept（默认就是）
    ~NoThrowVector() noexcept {
        delete[] data_;  // delete不抛异常
    }

    // swap必须是noexcept
    friend void swap(NoThrowVector& a, NoThrowVector& b) noexcept {
        using std::swap;
        swap(a.data_, b.data_);         // 指针交换，不抛异常
        swap(a.size_, b.size_);         // size_t交换，不抛异常
        swap(a.capacity_, b.capacity_);
    }

    // 移动操作应该是noexcept
    NoThrowVector(NoThrowVector&& other) noexcept
        : data_(other.data_)
        , size_(other.size_)
        , capacity_(other.capacity_)
    {
        other.data_ = nullptr;
        other.size_ = 0;
        other.capacity_ = 0;
    }

    // 返回大小是noexcept
    size_t size() const noexcept { return size_; }
    bool empty() const noexcept { return size_ == 0; }
};
```

---

#### Day 3-4: STL容器异常安全性详解（8小时）

**STL容器异常安全保证速查表**：

```
┌──────────────────┬────────────────────────────────────────────────────┐
│     操作          │                    异常安全保证                     │
├──────────────────┼────────────────────────────────────────────────────┤
│                  │              std::vector<T>                         │
├──────────────────┼────────────────────────────────────────────────────┤
│ push_back        │ 强保证（如果T的移动是noexcept）                      │
│                  │ 基本保证（如果T的移动可能抛异常）                     │
├──────────────────┼────────────────────────────────────────────────────┤
│ emplace_back     │ 同push_back                                        │
├──────────────────┼────────────────────────────────────────────────────┤
│ insert           │ 基本保证                                            │
├──────────────────┼────────────────────────────────────────────────────┤
│ erase            │ 不抛保证（如果T的移动/析构是noexcept）               │
│                  │ 基本保证（否则）                                     │
├──────────────────┼────────────────────────────────────────────────────┤
│ clear            │ 不抛保证（析构函数必须noexcept）                     │
├──────────────────┼────────────────────────────────────────────────────┤
│ swap             │ 不抛保证                                            │
├──────────────────┴────────────────────────────────────────────────────┤
│                  │              std::list<T>                           │
├──────────────────┼────────────────────────────────────────────────────┤
│ push_back/front  │ 强保证                                              │
├──────────────────┼────────────────────────────────────────────────────┤
│ insert           │ 强保证                                              │
├──────────────────┼────────────────────────────────────────────────────┤
│ erase            │ 不抛保证                                            │
├──────────────────┴────────────────────────────────────────────────────┤
│                  │              std::map<K,V>                          │
├──────────────────┼────────────────────────────────────────────────────┤
│ insert           │ 强保证                                              │
├──────────────────┼────────────────────────────────────────────────────┤
│ operator[]       │ 强保证                                              │
├──────────────────┼────────────────────────────────────────────────────┤
│ erase            │ 不抛保证                                            │
└──────────────────┴────────────────────────────────────────────────────┘
```

**为什么vector的push_back保证取决于移动操作**：

```cpp
#include <vector>
#include <iostream>

class Widget {
    int* data_;
public:
    Widget() : data_(new int(42)) {
        std::cout << "Default construct\n";
    }

    ~Widget() {
        delete data_;
        std::cout << "Destruct\n";
    }

    // 拷贝构造（可能抛异常）
    Widget(const Widget& other) : data_(new int(*other.data_)) {
        std::cout << "Copy construct\n";
    }

    // 移动构造：版本1 - 可能抛异常
    // Widget(Widget&& other) : data_(other.data_) {
    //     other.data_ = nullptr;
    //     std::cout << "Move construct (may throw)\n";
    //     // 这里如果有任何可能抛异常的操作...
    // }

    // 移动构造：版本2 - noexcept
    Widget(Widget&& other) noexcept : data_(other.data_) {
        other.data_ = nullptr;
        std::cout << "Move construct (noexcept)\n";
    }
};

void demo_vector_reallocation() {
    std::vector<Widget> vec;
    vec.reserve(2);  // 容量为2

    std::cout << "=== 添加第1个元素 ===\n";
    vec.emplace_back();

    std::cout << "\n=== 添加第2个元素 ===\n";
    vec.emplace_back();

    std::cout << "\n=== 添加第3个元素（触发重新分配）===\n";
    vec.emplace_back();

    // 如果Widget的移动构造是noexcept：
    // - vector会用移动来转移旧元素（高效）

    // 如果Widget的移动构造可能抛异常：
    // - vector会用拷贝来转移旧元素（安全但低效）
    // - 这样即使拷贝中途失败，原vector仍完整

    std::cout << "\n=== 清理 ===\n";
}
```

---

#### Day 5-6: noexcept说明符（8小时）

**noexcept的完整指南**：

```cpp
// ========== noexcept的基本用法 ==========

// 1. 简单声明（函数保证不抛异常）
void simple() noexcept;

// 2. 条件noexcept
template <typename T>
void swap(T& a, T& b) noexcept(noexcept(a.swap(b)));
// 含义：如果a.swap(b)是noexcept的，那么这个函数也是noexcept的

// 3. noexcept作为运算符（编译时求值）
static_assert(noexcept(1 + 1));           // true：整数加法不抛异常
static_assert(!noexcept(new int));        // false：new可能抛std::bad_alloc
static_assert(noexcept(std::declval<int&>() = 1)); // true

// ========== 什么时候应该使用noexcept ==========

// 1. 移动构造和移动赋值（强烈推荐）
class Resource {
public:
    Resource(Resource&& other) noexcept;
    Resource& operator=(Resource&& other) noexcept;
};

// 2. 析构函数（默认就是noexcept，通常不需要显式写）
// 但如果你想强调，可以写
~Resource() noexcept;

// 3. swap函数（必须）
friend void swap(Resource& a, Resource& b) noexcept;

// 4. 简单的访问器（推荐）
size_t size() const noexcept;
bool empty() const noexcept;
T* data() noexcept;

// 5. 比较运算符（C++20起，推荐）
bool operator==(const Resource& other) const noexcept;

// ========== 什么时候不应该使用noexcept ==========

// 1. 可能分配内存的函数
void grow() noexcept;  // ❌ 内部可能new，会抛bad_alloc

// 2. 调用虚函数的函数（除非你能保证所有派生类都是noexcept）
void process() noexcept;  // ❌ 如果调用了virtual函数

// 3. 调用外部库的函数（除非文档保证不抛异常）
void callExternal() noexcept;  // ❌ 外部库可能抛异常

// 4. 复杂的业务逻辑
void complexOperation() noexcept;  // ❌ 可能有各种错误情况
```

**noexcept与性能**：

```cpp
#include <vector>
#include <chrono>
#include <iostream>

// 版本1：移动可能抛异常
class MayThrow {
    int* data_;
public:
    MayThrow() : data_(new int(42)) {}
    ~MayThrow() { delete data_; }
    MayThrow(const MayThrow& other) : data_(new int(*other.data_)) {}

    // 注意：没有noexcept
    MayThrow(MayThrow&& other) : data_(other.data_) {
        other.data_ = nullptr;
    }
};

// 版本2：移动保证不抛异常
class NoThrow {
    int* data_;
public:
    NoThrow() : data_(new int(42)) {}
    ~NoThrow() { delete data_; }
    NoThrow(const NoThrow& other) : data_(new int(*other.data_)) {}

    // 有noexcept
    NoThrow(NoThrow&& other) noexcept : data_(other.data_) {
        other.data_ = nullptr;
    }
};

template <typename T>
void benchmark_vector_growth(const char* name) {
    auto start = std::chrono::high_resolution_clock::now();

    for (int trial = 0; trial < 100; ++trial) {
        std::vector<T> vec;
        for (int i = 0; i < 10000; ++i) {
            vec.emplace_back();
        }
    }

    auto end = std::chrono::high_resolution_clock::now();
    auto ms = std::chrono::duration<double, std::milli>(end - start).count();
    std::cout << name << ": " << ms << " ms\n";
}

// 运行结果示例：
// MayThrow: 450 ms （使用拷贝）
// NoThrow:  150 ms （使用移动）
// 差距约3倍！
```

**noexcept违反时的行为**：

```cpp
void promised_noexcept() noexcept {
    throw std::runtime_error("Oops!");  // 违反noexcept承诺
}

int main() {
    try {
        promised_noexcept();
    } catch (...) {
        // 这里永远不会执行！
        std::cout << "Caught!\n";
    }
    return 0;
}

// 程序直接调用std::terminate()
// 输出类似：
// terminate called after throwing an instance of 'std::runtime_error'
// what(): Oops!
// Aborted (core dumped)
```

---

#### Day 7: 异常安全性分析方法论（6小时）

**系统化分析步骤**：

```
分析函数异常安全性的步骤：
┌─────────────────────────────────────────────────────────────────┐
│ Step 1: 识别所有可能抛异常的操作                                 │
│   - new/new[]                                                   │
│   - 容器操作（insert, push_back等）                             │
│   - 字符串操作                                                   │
│   - 用户自定义类型的构造/拷贝/赋值                               │
│   - 文件/网络操作                                                │
├─────────────────────────────────────────────────────────────────┤
│ Step 2: 识别所有资源获取点                                       │
│   - 内存分配                                                     │
│   - 文件打开                                                     │
│   - 锁获取                                                       │
│   - 数据库连接                                                   │
├─────────────────────────────────────────────────────────────────┤
│ Step 3: 对每个抛异常点，追踪程序状态                             │
│   - 哪些资源已获取？是否有RAII保护？                             │
│   - 哪些对象状态已修改？                                         │
│   - 是否有部分完成的操作？                                       │
├─────────────────────────────────────────────────────────────────┤
│ Step 4: 确定安全等级                                             │
│   - 有资源泄漏？→ 无保证                                         │
│   - 对象状态可能不一致？→ 无保证                                 │
│   - 对象有效但状态改变？→ 基本保证                               │
│   - 完全回滚？→ 强保证                                           │
│   - 绝不抛异常？→ 不抛保证                                       │
└─────────────────────────────────────────────────────────────────┘
```

**实战分析练习**：

```cpp
// 分析以下函数的异常安全等级

class Database {
    std::vector<Record> records_;
    std::map<int, size_t> index_;  // id -> records_中的索引

public:
    // 练习1：分析这个函数
    void addRecord(const Record& r) {
        size_t pos = records_.size();      // (a) 不抛异常
        records_.push_back(r);              // (b) 可能抛异常
        index_[r.id()] = pos;               // (c) 可能抛异常
    }

    // 分析：
    // 如果(b)抛异常：records_不变，index_不变 → 强保证
    // 如果(c)抛异常：records_多了一条，但index_没更新
    //   → 对象状态不一致！→ 这是基本保证还是无保证？
    //   → 取决于类的不变式：如果要求records_和index_同步，则是无保证
    //   → 如果允许records_有多余记录，则是基本保证

    // 练习2：改进为强保证
    void addRecordStrong(const Record& r) {
        // 方法1：先做可能失败的操作
        auto [it, inserted] = index_.try_emplace(r.id(), records_.size());
        if (!inserted) {
            throw std::runtime_error("Duplicate ID");
        }
        try {
            records_.push_back(r);
        } catch (...) {
            index_.erase(it);  // 回滚
            throw;
        }
    }
};
```

### 第二周思考题

1. **概念理解**
   - 基本保证和强保证的本质区别是什么？
   - 为什么析构函数必须是noexcept？

2. **设计思考**
   - 为什么std::list的insert是强保证，而std::vector的insert是基本保证？
   - 设计一个场景，说明为什么强保证不总是最好的选择

3. **实践问题**
   - 如何测试一个函数是否满足基本保证？
   - 给定一个只有基本保证的函数，如何将其改造为强保证？

---

## 第三周：编写异常安全代码（35小时）

> **本周核心问题**：有哪些通用的技术和模式可以帮助我们编写异常安全的代码？

### 学习目标
- [ ] 深入掌握RAII的各种变体
- [ ] 熟练使用Copy-and-Swap惯用法
- [ ] 理解并实现ScopeGuard模式
- [ ] 完成SafeStack实践项目

### 每日学习安排

#### Day 1-2: RAII高级模式（8小时）

**RAII的本质**：

```
RAII（Resource Acquisition Is Initialization）的核心思想：
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   资源的生命周期 = 对象的生命周期                                │
│                                                                 │
│   构造函数 → 获取资源                                           │
│   析构函数 → 释放资源（无论正常退出还是异常退出）                │
│                                                                 │
│   关键洞见：C++保证局部对象的析构函数在作用域退出时被调用        │
│            即使是因为异常退出                                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**各种RAII包装器**：

```cpp
// ========== 1. 基础RAII：unique_ptr自定义删除器 ==========

// 文件句柄
auto file = std::unique_ptr<FILE, decltype(&fclose)>(
    fopen("data.txt", "r"),
    fclose
);

// Windows句柄
#ifdef _WIN32
auto handle = std::unique_ptr<std::remove_pointer_t<HANDLE>, decltype(&CloseHandle)>(
    CreateFile(...),
    CloseHandle
);
#endif

// C库资源
auto memory = std::unique_ptr<void, decltype(&free)>(
    malloc(1024),
    free
);

// ========== 2. 通用RAII包装器 ==========

template <typename Resource, typename Deleter>
class RAIIWrapper {
    Resource resource_;
    Deleter deleter_;
    bool owns_ = true;

public:
    RAIIWrapper(Resource res, Deleter del)
        : resource_(res), deleter_(del) {}

    ~RAIIWrapper() {
        if (owns_) {
            deleter_(resource_);
        }
    }

    // 禁止拷贝
    RAIIWrapper(const RAIIWrapper&) = delete;
    RAIIWrapper& operator=(const RAIIWrapper&) = delete;

    // 允许移动
    RAIIWrapper(RAIIWrapper&& other) noexcept
        : resource_(other.resource_)
        , deleter_(std::move(other.deleter_))
        , owns_(other.owns_)
    {
        other.owns_ = false;
    }

    Resource get() const noexcept { return resource_; }
    Resource release() noexcept {
        owns_ = false;
        return resource_;
    }
};

// ========== 3. 锁的RAII ==========

class SpinLock {
    std::atomic_flag flag_ = ATOMIC_FLAG_INIT;
public:
    void lock() {
        while (flag_.test_and_set(std::memory_order_acquire)) {
            // 自旋等待
        }
    }
    void unlock() {
        flag_.clear(std::memory_order_release);
    }
};

// 使用std::lock_guard（推荐）
void safe_operation(SpinLock& lock) {
    std::lock_guard<SpinLock> guard(lock);
    // ... 临界区代码 ...
    // 即使抛异常，锁也会被释放
}

// 使用std::unique_lock（更灵活）
void flexible_operation(SpinLock& lock) {
    std::unique_lock<SpinLock> guard(lock);

    // 可以手动解锁
    guard.unlock();

    // 做一些不需要锁的操作

    // 重新加锁
    guard.lock();

    // 作用域结束自动解锁
}

// ========== 4. 延迟初始化的RAII ==========

template <typename T>
class LazyInit {
    alignas(T) unsigned char storage_[sizeof(T)];
    bool initialized_ = false;

public:
    ~LazyInit() {
        if (initialized_) {
            reinterpret_cast<T*>(storage_)->~T();
        }
    }

    template <typename... Args>
    T& init(Args&&... args) {
        if (initialized_) {
            throw std::logic_error("Already initialized");
        }
        T* ptr = new (storage_) T(std::forward<Args>(args)...);
        initialized_ = true;
        return *ptr;
    }

    T& get() {
        if (!initialized_) {
            throw std::logic_error("Not initialized");
        }
        return *reinterpret_cast<T*>(storage_);
    }

    bool has_value() const noexcept { return initialized_; }
};
```

---

#### Day 3-4: ScopeGuard模式（8小时）

**ScopeGuard：通用的回滚机制**：

```cpp
// ========== 基础版ScopeGuard ==========

template <typename Func>
class ScopeGuard {
    Func func_;
    bool active_ = true;

public:
    explicit ScopeGuard(Func f) : func_(std::move(f)) {}

    ~ScopeGuard() {
        if (active_) {
            try {
                func_();
            } catch (...) {
                // 忽略析构时的异常
            }
        }
    }

    // 禁止拷贝和移动（简化版本）
    ScopeGuard(const ScopeGuard&) = delete;
    ScopeGuard& operator=(const ScopeGuard&) = delete;

    void dismiss() noexcept { active_ = false; }
};

// 辅助函数
template <typename Func>
ScopeGuard<Func> makeScopeGuard(Func f) {
    return ScopeGuard<Func>(std::move(f));
}

// 使用宏简化
#define SCOPE_EXIT_CAT2(x, y) x##y
#define SCOPE_EXIT_CAT(x, y) SCOPE_EXIT_CAT2(x, y)
#define SCOPE_EXIT auto SCOPE_EXIT_CAT(scope_exit_, __LINE__) = makeScopeGuard

// ========== 使用示例 ==========

void complex_operation() {
    // 分配资源1
    Resource* r1 = acquireResource1();
    SCOPE_EXIT([&]{ releaseResource1(r1); });

    // 分配资源2
    Resource* r2 = acquireResource2();
    SCOPE_EXIT([&]{ releaseResource2(r2); });

    // 分配资源3
    Resource* r3 = acquireResource3();  // 如果这里失败，r1和r2会被正确释放
    SCOPE_EXIT([&]{ releaseResource3(r3); });

    // 做一些可能抛异常的操作
    process(r1, r2, r3);

    // 无论如何退出，所有资源都会被释放
}

// ========== 高级版：区分成功和失败 ==========

template <typename Func>
class ScopeGuardOnFail {
    Func func_;
    int exceptions_on_enter_;

public:
    explicit ScopeGuardOnFail(Func f)
        : func_(std::move(f))
        , exceptions_on_enter_(std::uncaught_exceptions())
    {}

    ~ScopeGuardOnFail() {
        // 只在有新异常时执行
        if (std::uncaught_exceptions() > exceptions_on_enter_) {
            try {
                func_();
            } catch (...) {}
        }
    }
};

template <typename Func>
class ScopeGuardOnSuccess {
    Func func_;
    int exceptions_on_enter_;

public:
    explicit ScopeGuardOnSuccess(Func f)
        : func_(std::move(f))
        , exceptions_on_enter_(std::uncaught_exceptions())
    {}

    ~ScopeGuardOnSuccess() {
        // 只在没有新异常时执行
        if (std::uncaught_exceptions() == exceptions_on_enter_) {
            func_();
        }
    }
};

// 使用宏
#define SCOPE_FAIL auto SCOPE_EXIT_CAT(scope_fail_, __LINE__) = \
    ScopeGuardOnFail([&]()
#define SCOPE_SUCCESS auto SCOPE_EXIT_CAT(scope_success_, __LINE__) = \
    ScopeGuardOnSuccess([&]()

// ========== 使用示例 ==========

void transaction_example() {
    begin_transaction();

    SCOPE_FAIL {
        rollback_transaction();
    });

    SCOPE_SUCCESS {
        commit_transaction();
    });

    // 做各种可能失败的操作
    step1();  // 如果失败，自动rollback
    step2();  // 如果失败，自动rollback
    step3();  // 如果失败，自动rollback

    // 正常完成，自动commit
}
```

---

#### Day 5-6: Copy-and-Swap深入（8小时）

**Copy-and-Swap完整实现**：

```cpp
#include <algorithm>  // std::swap
#include <utility>    // std::move

class String {
    char* data_;
    size_t size_;
    size_t capacity_;

public:
    // ========== 构造函数 ==========

    // 默认构造
    String() : data_(new char[1]{'\0'}), size_(0), capacity_(1) {}

    // 从C字符串构造
    explicit String(const char* s) {
        size_ = std::strlen(s);
        capacity_ = size_ + 1;
        data_ = new char[capacity_];
        std::memcpy(data_, s, capacity_);
    }

    // 拷贝构造
    String(const String& other)
        : data_(new char[other.capacity_])
        , size_(other.size_)
        , capacity_(other.capacity_)
    {
        std::memcpy(data_, other.data_, capacity_);
    }

    // 移动构造
    String(String&& other) noexcept
        : data_(other.data_)
        , size_(other.size_)
        , capacity_(other.capacity_)
    {
        other.data_ = nullptr;
        other.size_ = 0;
        other.capacity_ = 0;
    }

    // ========== 析构函数 ==========
    ~String() {
        delete[] data_;
    }

    // ========== Copy-and-Swap赋值 ==========

    // 统一赋值运算符（处理拷贝和移动）
    String& operator=(String other) noexcept {
        // other是按值传递的：
        // - 如果传入左值：调用拷贝构造，可能抛异常
        // - 如果传入右值：调用移动构造，noexcept
        //
        // 关键点：如果拷贝失败（抛异常），
        // 我们还没进入函数体，*this未被修改

        swap(*this, other);
        return *this;

        // other在这里析构，释放旧的data_
    }

    // ========== swap函数 ==========

    friend void swap(String& a, String& b) noexcept {
        using std::swap;
        swap(a.data_, b.data_);
        swap(a.size_, b.size_);
        swap(a.capacity_, b.capacity_);
    }

    // ========== 其他成员函数 ==========

    const char* c_str() const noexcept { return data_; }
    size_t size() const noexcept { return size_; }
    size_t capacity() const noexcept { return capacity_; }
    bool empty() const noexcept { return size_ == 0; }
};

// ========== Copy-and-Swap的优缺点分析 ==========

/*
优点：
1. 异常安全：拷贝在进入函数体前完成，失败不影响原对象
2. 代码复用：利用拷贝构造和析构函数
3. 自赋值安全：自动处理 a = a 的情况
4. 简洁：一个operator=处理所有情况

缺点：
1. 性能开销：即使可以原地修改，也会创建临时对象
2. 移动语义的效率损失：需要一次额外的swap

优化版本（分离拷贝和移动赋值）：
*/

class OptimizedString {
    char* data_;
    size_t size_;
    size_t capacity_;

public:
    // ... 构造函数同上 ...

    // 拷贝赋值：使用Copy-and-Swap
    OptimizedString& operator=(const OptimizedString& other) {
        OptimizedString temp(other);  // 可能抛异常
        swap(*this, temp);            // noexcept
        return *this;
    }

    // 移动赋值：直接交换（更高效）
    OptimizedString& operator=(OptimizedString&& other) noexcept {
        // 方法1：直接交换
        swap(*this, other);
        return *this;

        // 或者方法2：移动后清空
        // delete[] data_;
        // data_ = other.data_;
        // size_ = other.size_;
        // capacity_ = other.capacity_;
        // other.data_ = nullptr;
        // other.size_ = 0;
        // other.capacity_ = 0;
        // return *this;
    }
};
```

---

#### Day 7: 实践项目——SafeStack实现（6小时）

**完整的异常安全栈实现**：

```cpp
// safe_stack.hpp
#pragma once

#include <memory>
#include <optional>
#include <stdexcept>
#include <mutex>

template <typename T>
class SafeStack {
public:
    // ========== 公开类型 ==========
    using value_type = T;
    using size_type = std::size_t;

private:
    // ========== 内部节点 ==========
    struct Node {
        T data;
        std::unique_ptr<Node> next;

        template <typename... Args>
        explicit Node(Args&&... args)
            : data(std::forward<Args>(args)...)
            , next(nullptr)
        {}
    };

    std::unique_ptr<Node> head_;
    size_type size_ = 0;

public:
    // ========== 构造与析构 ==========

    SafeStack() = default;

    ~SafeStack() = default;  // unique_ptr自动处理链表

    // 拷贝构造：强保证
    SafeStack(const SafeStack& other) {
        if (other.empty()) return;

        // 收集所有元素（反向）
        std::vector<const T*> elements;
        for (Node* p = other.head_.get(); p; p = p->next.get()) {
            elements.push_back(&p->data);
        }

        // 反向插入以保持顺序
        for (auto it = elements.rbegin(); it != elements.rend(); ++it) {
            push(**it);  // 如果中途失败，已构造的节点会被析构
        }
    }

    // 移动构造：noexcept
    SafeStack(SafeStack&& other) noexcept
        : head_(std::move(other.head_))
        , size_(other.size_)
    {
        other.size_ = 0;
    }

    // 赋值：Copy-and-Swap
    SafeStack& operator=(SafeStack other) noexcept {
        swap(*this, other);
        return *this;
    }

    friend void swap(SafeStack& a, SafeStack& b) noexcept {
        using std::swap;
        swap(a.head_, b.head_);
        swap(a.size_, b.size_);
    }

    // ========== 元素访问 ==========

    // top()：返回引用，允许修改
    // 异常安全：抛出异常时不修改状态
    T& top() {
        if (empty()) {
            throw std::runtime_error("SafeStack::top(): stack is empty");
        }
        return head_->data;
    }

    const T& top() const {
        if (empty()) {
            throw std::runtime_error("SafeStack::top(): stack is empty");
        }
        return head_->data;
    }

    // ========== 修改器 ==========

    // push：强保证
    void push(const T& value) {
        auto new_node = std::make_unique<Node>(value);  // 可能抛异常
        // 如果上面成功，下面都是noexcept操作
        new_node->next = std::move(head_);
        head_ = std::move(new_node);
        ++size_;
    }

    void push(T&& value) {
        auto new_node = std::make_unique<Node>(std::move(value));
        new_node->next = std::move(head_);
        head_ = std::move(new_node);
        ++size_;
    }

    // emplace：强保证
    template <typename... Args>
    void emplace(Args&&... args) {
        auto new_node = std::make_unique<Node>(std::forward<Args>(args)...);
        new_node->next = std::move(head_);
        head_ = std::move(new_node);
        ++size_;
    }

    // pop()：noexcept（不返回值）
    void pop() noexcept {
        if (head_) {
            head_ = std::move(head_->next);
            --size_;
        }
    }

    // ========== 异常安全的弹出方案 ==========

    // 方案1：返回shared_ptr（强保证）
    std::shared_ptr<T> pop_shared() {
        if (empty()) {
            throw std::runtime_error("SafeStack::pop_shared(): stack is empty");
        }

        // 先创建shared_ptr（可能因为拷贝T而抛异常）
        auto result = std::make_shared<T>(std::move(head_->data));

        // 成功后再修改栈（noexcept）
        head_ = std::move(head_->next);
        --size_;

        return result;
    }

    // 方案2：返回optional（不抛异常版本）
    std::optional<T> try_pop() noexcept(std::is_nothrow_move_constructible_v<T>) {
        if (empty()) {
            return std::nullopt;
        }

        std::optional<T> result(std::move(head_->data));
        head_ = std::move(head_->next);
        --size_;

        return result;
    }

    // 方案3：通过输出参数返回（强保证）
    bool pop_into(T& out) {
        if (empty()) {
            return false;
        }

        out = std::move(head_->data);  // 可能抛异常
        // 只有移动成功后才修改栈
        head_ = std::move(head_->next);
        --size_;

        return true;
    }

    // ========== 容量 ==========

    bool empty() const noexcept { return size_ == 0; }
    size_type size() const noexcept { return size_; }

    // ========== 清空 ==========

    void clear() noexcept {
        head_.reset();
        size_ = 0;
    }
};

// ========== 线程安全版本 ==========

template <typename T>
class ThreadSafeStack {
    SafeStack<T> stack_;
    mutable std::mutex mutex_;

public:
    void push(T value) {
        std::lock_guard<std::mutex> lock(mutex_);
        stack_.push(std::move(value));
    }

    std::optional<T> try_pop() {
        std::lock_guard<std::mutex> lock(mutex_);
        return stack_.try_pop();
    }

    std::shared_ptr<T> pop_shared() {
        std::lock_guard<std::mutex> lock(mutex_);
        return stack_.pop_shared();
    }

    bool empty() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return stack_.empty();
    }
};
```

### 第三周思考题

1. **RAII相关**
   - 为什么RAII是异常安全的基石？
   - RAII模式有什么局限性？

2. **ScopeGuard相关**
   - ScopeGuard和RAII有什么区别和联系？
   - 为什么需要SCOPE_FAIL和SCOPE_SUCCESS？

3. **Copy-and-Swap相关**
   - Copy-and-Swap如何实现强异常保证？
   - 什么情况下不应该使用Copy-and-Swap？

---

## 第四周：现代错误处理替代方案（35小时）

> **本周核心问题**：除了异常，还有哪些错误处理方式？它们各有什么优缺点？

### 学习目标
- [ ] 深入理解std::optional和std::expected
- [ ] 掌握函数式错误处理方法
- [ ] 能够根据场景选择合适的错误处理策略
- [ ] 完成mini_expected和Transaction实践项目

### 每日学习安排

#### Day 1-2: 错误处理策略对比（8小时）

**错误处理方式全景图**：

```
┌─────────────────────────────────────────────────────────────────┐
│                     C++ 错误处理方式对比                         │
├─────────────┬─────────────┬──────────────┬─────────────────────┤
│    方式      │    优点      │     缺点      │      适用场景       │
├─────────────┼─────────────┼──────────────┼─────────────────────┤
│   异常       │ 分离正常/   │ 运行时开销    │ 真正异常的情况      │
│  Exception  │ 错误路径     │ 隐式控制流    │ 构造函数错误        │
│             │ 不可忽略     │ 二进制膨胀    │ 跨层错误传播        │
├─────────────┼─────────────┼──────────────┼─────────────────────┤
│   错误码     │ 无运行时    │ 容易被忽略    │ C API               │
│ Error Code  │ 开销        │ 污染返回值    │ 性能关键路径        │
│             │ 显式控制流   │ 繁琐的检查    │ 嵌入式/实时系统     │
├─────────────┼─────────────┼──────────────┼─────────────────────┤
│  optional   │ 简洁        │ 无错误信息    │ "可能无值"          │
│             │ 无开销      │ 仅表示有/无   │ 查找、解析          │
├─────────────┼─────────────┼──────────────┼─────────────────────┤
│  expected   │ 类型安全    │ C++23才标准化 │ 需要错误信息        │
│             │ 错误信息    │ 链式调用复杂  │ 替代轻量异常        │
├─────────────┼─────────────┼──────────────┼─────────────────────┤
│   断言      │ 开发期检查   │ 生产环境禁用  │ 程序员错误          │
│  Assert    │ 文档化假设   │ 不是错误处理  │ 不变式检查          │
└─────────────┴─────────────┴──────────────┴─────────────────────┘
```

**决策树：如何选择错误处理方式**：

```
                    发生了什么？
                        │
          ┌─────────────┼─────────────┐
          │             │             │
      程序员错误    可恢复错误      不可恢复错误
     (Bug/不变式)   (正常业务)     (系统崩溃)
          │             │             │
          ▼             │             ▼
       assert()         │         std::terminate()
       static_assert    │         或 std::abort()
                        │
            ┌───────────┼───────────┐
            │           │           │
        是否常见？   错误是否需要   是否跨层传播？
            │        详细信息？         │
    ┌───────┼───────┐       │           │
    │       │       │       │           │
   是      否      是       否          是
    │       │       │       │           │
    ▼       ▼       ▼       ▼           ▼
 返回值  optional expected  optional   异常
 错误码
```

**实际代码对比**：

```cpp
// ========== 场景：解析整数 ==========

// 方式1：异常
int parse_int_exception(const std::string& s) {
    try {
        return std::stoi(s);
    } catch (const std::invalid_argument&) {
        throw ParseError("Invalid integer: " + s);
    } catch (const std::out_of_range&) {
        throw ParseError("Integer out of range: " + s);
    }
}

// 方式2：optional（适合"可能没有"的语义）
std::optional<int> parse_int_optional(const std::string& s) {
    try {
        return std::stoi(s);
    } catch (...) {
        return std::nullopt;
    }
}

// 方式3：expected（适合需要错误信息）
std::expected<int, std::string> parse_int_expected(const std::string& s) {
    try {
        return std::stoi(s);
    } catch (const std::invalid_argument&) {
        return std::unexpected("Invalid integer: " + s);
    } catch (const std::out_of_range&) {
        return std::unexpected("Integer out of range: " + s);
    }
}

// 方式4：错误码
enum class ParseError { None, InvalidFormat, OutOfRange };
struct ParseResult {
    int value;
    ParseError error;
};

ParseResult parse_int_errorcode(const std::string& s) {
    try {
        return {std::stoi(s), ParseError::None};
    } catch (const std::invalid_argument&) {
        return {0, ParseError::InvalidFormat};
    } catch (const std::out_of_range&) {
        return {0, ParseError::OutOfRange};
    }
}

// ========== 使用对比 ==========

void demo_usage() {
    std::string input = "42abc";

    // 异常：需要try-catch
    try {
        int v = parse_int_exception(input);
        use(v);
    } catch (const ParseError& e) {
        handle_error(e);
    }

    // optional：需要检查
    if (auto v = parse_int_optional(input)) {
        use(*v);
    } else {
        handle_missing_value();
    }

    // expected：可以链式调用
    parse_int_expected(input)
        .transform([](int v) { return v * 2; })
        .and_then([](int v) -> std::expected<std::string, std::string> {
            return std::to_string(v);
        })
        .or_else([](const std::string& e) {
            log_error(e);
            return std::expected<std::string, std::string>("default");
        });
}
```

---

#### Day 3-4: std::expected深入（8小时）

**std::expected (C++23) 完整API**：

```cpp
#include <expected>
#include <string>
#include <iostream>

// ========== 基本用法 ==========

std::expected<int, std::string> divide(int a, int b) {
    if (b == 0) {
        return std::unexpected("Division by zero");
    }
    return a / b;
}

void basic_usage() {
    auto result = divide(10, 2);

    // 检查是否有值
    if (result.has_value()) {  // 或 if (result)
        std::cout << "Result: " << result.value() << "\n";
        std::cout << "Result: " << *result << "\n";  // 同上
    } else {
        std::cout << "Error: " << result.error() << "\n";
    }

    // value_or：提供默认值
    int v = result.value_or(-1);

    // value()：无值时抛异常
    try {
        int v = divide(1, 0).value();
    } catch (const std::bad_expected_access<std::string>& e) {
        // e.error() 返回存储的错误
    }
}

// ========== Monadic操作（函数式风格）==========

std::expected<int, std::string> safe_sqrt(int x) {
    if (x < 0) return std::unexpected("Negative input");
    return static_cast<int>(std::sqrt(x));
}

std::expected<int, std::string> safe_log(int x) {
    if (x <= 0) return std::unexpected("Non-positive input");
    return static_cast<int>(std::log(x));
}

void monadic_operations() {
    // transform: 对值应用函数，错误直接传播
    auto doubled = divide(10, 2).transform([](int v) {
        return v * 2;
    });  // expected<int, string>，值为10

    // and_then: 链接可能失败的操作
    auto result = divide(100, 10)
        .and_then(safe_sqrt)     // 100/10=10, sqrt(10)=3
        .and_then(safe_log);     // log(3)=1

    // or_else: 处理错误
    auto handled = divide(10, 0)
        .or_else([](const std::string& e) -> std::expected<int, std::string> {
            std::cerr << "Error: " << e << ", using default\n";
            return 0;  // 恢复为默认值
        });

    // transform_error: 转换错误类型
    auto with_code = divide(10, 0)
        .transform_error([](const std::string& e) {
            return ErrorCode::DivisionByZero;
        });  // expected<int, ErrorCode>
}

// ========== 复杂链式调用示例 ==========

struct User { int id; std::string name; };
struct Order { int id; int user_id; double amount; };

std::expected<User, std::string> find_user(int id);
std::expected<std::vector<Order>, std::string> get_orders(const User& user);
std::expected<double, std::string> calculate_total(const std::vector<Order>& orders);

std::expected<double, std::string> get_user_total(int user_id) {
    return find_user(user_id)
        .and_then(get_orders)
        .and_then(calculate_total);
}

// 等价的异常版本
double get_user_total_exception(int user_id) {
    User user = find_user_throwing(user_id);
    auto orders = get_orders_throwing(user);
    return calculate_total_throwing(orders);
}
```

---

#### Day 5-6: 实践项目——mini_expected实现（10小时）

**完整的mini_expected实现**：

```cpp
// mini_expected.hpp
#pragma once

#include <variant>
#include <utility>
#include <stdexcept>
#include <type_traits>
#include <functional>

namespace mini {

// ========== unexpected：表示错误 ==========

template <typename E>
class unexpected {
    E error_;

public:
    // 构造函数
    constexpr explicit unexpected(const E& e) : error_(e) {}
    constexpr explicit unexpected(E&& e) : error_(std::move(e)) {}

    template <typename... Args>
    constexpr explicit unexpected(std::in_place_t, Args&&... args)
        : error_(std::forward<Args>(args)...) {}

    // 访问错误
    constexpr const E& error() const& noexcept { return error_; }
    constexpr E& error() & noexcept { return error_; }
    constexpr const E&& error() const&& noexcept { return std::move(error_); }
    constexpr E&& error() && noexcept { return std::move(error_); }

    // 交换
    constexpr void swap(unexpected& other) noexcept(std::is_nothrow_swappable_v<E>) {
        using std::swap;
        swap(error_, other.error_);
    }

    // 比较
    template <typename E2>
    friend constexpr bool operator==(const unexpected& x, const unexpected<E2>& y) {
        return x.error() == y.error();
    }
};

// 推导指引
template <typename E>
unexpected(E) -> unexpected<E>;

// ========== bad_expected_access：访问无值时的异常 ==========

template <typename E>
class bad_expected_access : public std::exception {
    E error_;

public:
    explicit bad_expected_access(E e) : error_(std::move(e)) {}

    const char* what() const noexcept override {
        return "bad expected access";
    }

    const E& error() const& noexcept { return error_; }
    E& error() & noexcept { return error_; }
    const E&& error() const&& noexcept { return std::move(error_); }
    E&& error() && noexcept { return std::move(error_); }
};

// ========== expected：主模板 ==========

template <typename T, typename E>
class expected {
    std::variant<T, unexpected<E>> storage_;

public:
    using value_type = T;
    using error_type = E;
    using unexpected_type = unexpected<E>;

    // ========== 构造函数 ==========

    // 默认构造：值初始化
    constexpr expected()
        requires std::is_default_constructible_v<T>
        : storage_(std::in_place_index<0>) {}

    // 拷贝构造
    constexpr expected(const expected&) = default;

    // 移动构造
    constexpr expected(expected&&) = default;

    // 从值构造
    template <typename U = T>
        requires (!std::is_same_v<std::remove_cvref_t<U>, expected> &&
                  !std::is_same_v<std::remove_cvref_t<U>, unexpected<E>> &&
                  std::is_constructible_v<T, U>)
    constexpr expected(U&& v)
        : storage_(std::in_place_index<0>, std::forward<U>(v)) {}

    // 从unexpected构造
    template <typename G>
        requires std::is_constructible_v<E, const G&>
    constexpr expected(const unexpected<G>& e)
        : storage_(std::in_place_index<1>, unexpected<E>(e.error())) {}

    template <typename G>
        requires std::is_constructible_v<E, G>
    constexpr expected(unexpected<G>&& e)
        : storage_(std::in_place_index<1>, unexpected<E>(std::move(e).error())) {}

    // in_place构造
    template <typename... Args>
        requires std::is_constructible_v<T, Args...>
    constexpr explicit expected(std::in_place_t, Args&&... args)
        : storage_(std::in_place_index<0>, std::forward<Args>(args)...) {}

    // ========== 赋值 ==========

    constexpr expected& operator=(const expected&) = default;
    constexpr expected& operator=(expected&&) = default;

    template <typename U = T>
    constexpr expected& operator=(U&& v) {
        storage_.template emplace<0>(std::forward<U>(v));
        return *this;
    }

    template <typename G>
    constexpr expected& operator=(const unexpected<G>& e) {
        storage_.template emplace<1>(unexpected<E>(e.error()));
        return *this;
    }

    template <typename G>
    constexpr expected& operator=(unexpected<G>&& e) {
        storage_.template emplace<1>(unexpected<E>(std::move(e).error()));
        return *this;
    }

    // ========== 观察器 ==========

    constexpr bool has_value() const noexcept {
        return storage_.index() == 0;
    }

    constexpr explicit operator bool() const noexcept {
        return has_value();
    }

    // 值访问
    constexpr T& value() & {
        if (!has_value()) {
            throw bad_expected_access(std::get<1>(storage_).error());
        }
        return std::get<0>(storage_);
    }

    constexpr const T& value() const& {
        if (!has_value()) {
            throw bad_expected_access(std::get<1>(storage_).error());
        }
        return std::get<0>(storage_);
    }

    constexpr T&& value() && {
        if (!has_value()) {
            throw bad_expected_access(std::move(std::get<1>(storage_)).error());
        }
        return std::get<0>(std::move(storage_));
    }

    constexpr const T&& value() const&& {
        if (!has_value()) {
            throw bad_expected_access(std::move(std::get<1>(storage_)).error());
        }
        return std::get<0>(std::move(storage_));
    }

    // 错误访问
    constexpr E& error() & noexcept {
        return std::get<1>(storage_).error();
    }

    constexpr const E& error() const& noexcept {
        return std::get<1>(storage_).error();
    }

    constexpr E&& error() && noexcept {
        return std::move(std::get<1>(storage_)).error();
    }

    constexpr const E&& error() const&& noexcept {
        return std::move(std::get<1>(storage_)).error();
    }

    // 解引用
    constexpr T& operator*() & noexcept { return std::get<0>(storage_); }
    constexpr const T& operator*() const& noexcept { return std::get<0>(storage_); }
    constexpr T&& operator*() && noexcept { return std::get<0>(std::move(storage_)); }
    constexpr const T&& operator*() const&& noexcept { return std::get<0>(std::move(storage_)); }

    constexpr T* operator->() noexcept { return &std::get<0>(storage_); }
    constexpr const T* operator->() const noexcept { return &std::get<0>(storage_); }

    // value_or
    template <typename U>
    constexpr T value_or(U&& default_value) const& {
        return has_value() ? value()
                           : static_cast<T>(std::forward<U>(default_value));
    }

    template <typename U>
    constexpr T value_or(U&& default_value) && {
        return has_value() ? std::move(*this).value()
                           : static_cast<T>(std::forward<U>(default_value));
    }

    // error_or
    template <typename G>
    constexpr E error_or(G&& default_error) const& {
        return has_value() ? static_cast<E>(std::forward<G>(default_error))
                           : error();
    }

    // ========== Monadic操作 ==========

    // and_then：链接可能失败的操作
    template <typename F>
    constexpr auto and_then(F&& f) & {
        using Result = std::invoke_result_t<F, T&>;
        if (has_value()) {
            return std::invoke(std::forward<F>(f), value());
        }
        return Result(unexpected(error()));
    }

    template <typename F>
    constexpr auto and_then(F&& f) const& {
        using Result = std::invoke_result_t<F, const T&>;
        if (has_value()) {
            return std::invoke(std::forward<F>(f), value());
        }
        return Result(unexpected(error()));
    }

    template <typename F>
    constexpr auto and_then(F&& f) && {
        using Result = std::invoke_result_t<F, T&&>;
        if (has_value()) {
            return std::invoke(std::forward<F>(f), std::move(*this).value());
        }
        return Result(unexpected(std::move(*this).error()));
    }

    // transform：对值应用函数
    template <typename F>
    constexpr auto transform(F&& f) & {
        using U = std::invoke_result_t<F, T&>;
        if (has_value()) {
            return expected<U, E>(std::invoke(std::forward<F>(f), value()));
        }
        return expected<U, E>(unexpected(error()));
    }

    template <typename F>
    constexpr auto transform(F&& f) const& {
        using U = std::invoke_result_t<F, const T&>;
        if (has_value()) {
            return expected<U, E>(std::invoke(std::forward<F>(f), value()));
        }
        return expected<U, E>(unexpected(error()));
    }

    template <typename F>
    constexpr auto transform(F&& f) && {
        using U = std::invoke_result_t<F, T&&>;
        if (has_value()) {
            return expected<U, E>(std::invoke(std::forward<F>(f), std::move(*this).value()));
        }
        return expected<U, E>(unexpected(std::move(*this).error()));
    }

    // or_else：处理错误
    template <typename F>
    constexpr auto or_else(F&& f) & {
        using Result = std::invoke_result_t<F, E&>;
        if (has_value()) {
            return Result(value());
        }
        return std::invoke(std::forward<F>(f), error());
    }

    template <typename F>
    constexpr auto or_else(F&& f) const& {
        using Result = std::invoke_result_t<F, const E&>;
        if (has_value()) {
            return Result(value());
        }
        return std::invoke(std::forward<F>(f), error());
    }

    template <typename F>
    constexpr auto or_else(F&& f) && {
        using Result = std::invoke_result_t<F, E&&>;
        if (has_value()) {
            return Result(std::move(*this).value());
        }
        return std::invoke(std::forward<F>(f), std::move(*this).error());
    }

    // transform_error：转换错误
    template <typename F>
    constexpr auto transform_error(F&& f) & {
        using G = std::invoke_result_t<F, E&>;
        if (has_value()) {
            return expected<T, G>(value());
        }
        return expected<T, G>(unexpected(std::invoke(std::forward<F>(f), error())));
    }

    // ========== 比较 ==========

    template <typename T2, typename E2>
    friend constexpr bool operator==(const expected& x, const expected<T2, E2>& y) {
        if (x.has_value() != y.has_value()) return false;
        if (x.has_value()) return *x == *y;
        return x.error() == y.error();
    }

    template <typename T2>
    friend constexpr bool operator==(const expected& x, const T2& v) {
        return x.has_value() && *x == v;
    }

    template <typename E2>
    friend constexpr bool operator==(const expected& x, const unexpected<E2>& e) {
        return !x.has_value() && x.error() == e.error();
    }
};

// ========== void特化 ==========

template <typename E>
class expected<void, E> {
    std::variant<std::monostate, unexpected<E>> storage_;

public:
    using value_type = void;
    using error_type = E;
    using unexpected_type = unexpected<E>;

    // 构造函数
    constexpr expected() noexcept : storage_(std::monostate{}) {}

    constexpr expected(const expected&) = default;
    constexpr expected(expected&&) = default;

    template <typename G>
    constexpr expected(const unexpected<G>& e)
        : storage_(unexpected<E>(e.error())) {}

    template <typename G>
    constexpr expected(unexpected<G>&& e)
        : storage_(unexpected<E>(std::move(e).error())) {}

    // 观察器
    constexpr bool has_value() const noexcept {
        return storage_.index() == 0;
    }

    constexpr explicit operator bool() const noexcept {
        return has_value();
    }

    constexpr void value() const {
        if (!has_value()) {
            throw bad_expected_access(std::get<1>(storage_).error());
        }
    }

    constexpr E& error() & noexcept {
        return std::get<1>(storage_).error();
    }

    constexpr const E& error() const& noexcept {
        return std::get<1>(storage_).error();
    }

    // Monadic操作
    template <typename F>
    constexpr auto and_then(F&& f) & {
        using Result = std::invoke_result_t<F>;
        if (has_value()) {
            return std::invoke(std::forward<F>(f));
        }
        return Result(unexpected(error()));
    }

    template <typename F>
    constexpr auto transform(F&& f) & {
        using U = std::invoke_result_t<F>;
        if (has_value()) {
            if constexpr (std::is_void_v<U>) {
                std::invoke(std::forward<F>(f));
                return expected<void, E>();
            } else {
                return expected<U, E>(std::invoke(std::forward<F>(f)));
            }
        }
        return expected<U, E>(unexpected(error()));
    }
};

} // namespace mini
```

---

#### Day 7: Transaction类与测试（6小时）

**完整的Transaction实现**：

```cpp
// transaction.hpp
#pragma once

#include <functional>
#include <vector>
#include <exception>
#include <utility>

namespace mini {

// ========== 基础Transaction ==========

class Transaction {
public:
    using Action = std::function<void()>;
    using Rollback = std::function<void()>;

private:
    std::vector<Rollback> rollback_actions_;
    bool committed_ = false;

public:
    Transaction() = default;

    ~Transaction() {
        if (!committed_) {
            rollback();
        }
    }

    // 禁止拷贝
    Transaction(const Transaction&) = delete;
    Transaction& operator=(const Transaction&) = delete;

    // 允许移动
    Transaction(Transaction&& other) noexcept
        : rollback_actions_(std::move(other.rollback_actions_))
        , committed_(other.committed_)
    {
        other.committed_ = true;  // 防止other析构时回滚
    }

    Transaction& operator=(Transaction&& other) noexcept {
        if (this != &other) {
            if (!committed_) {
                rollback();
            }
            rollback_actions_ = std::move(other.rollback_actions_);
            committed_ = other.committed_;
            other.committed_ = true;
        }
        return *this;
    }

    // 添加操作
    template <typename A, typename R>
    void add(A&& action, R&& rollback) {
        // 先记录回滚操作
        rollback_actions_.push_back(std::forward<R>(rollback));

        try {
            // 执行操作
            std::forward<A>(action)();
        } catch (...) {
            // 操作失败，移除回滚（因为操作没成功）
            rollback_actions_.pop_back();
            throw;
        }
    }

    // 添加只需要回滚的操作
    template <typename R>
    void add_rollback(R&& rollback) {
        rollback_actions_.push_back(std::forward<R>(rollback));
    }

    // 提交事务
    void commit() noexcept {
        committed_ = true;
        rollback_actions_.clear();
    }

    // 回滚事务
    void rollback() noexcept {
        // 逆序执行回滚
        for (auto it = rollback_actions_.rbegin();
             it != rollback_actions_.rend(); ++it) {
            try {
                (*it)();
            } catch (...) {
                // 忽略回滚时的异常
            }
        }
        rollback_actions_.clear();
    }

    // 查询状态
    bool is_committed() const noexcept { return committed_; }
    size_t pending_rollbacks() const noexcept { return rollback_actions_.size(); }
};

// ========== 嵌套事务支持 ==========

class NestedTransaction {
    Transaction& parent_;
    std::vector<std::function<void()>> local_rollbacks_;
    bool committed_ = false;

public:
    explicit NestedTransaction(Transaction& parent) : parent_(parent) {}

    ~NestedTransaction() {
        if (!committed_) {
            // 回滚本地操作
            for (auto it = local_rollbacks_.rbegin();
                 it != local_rollbacks_.rend(); ++it) {
                try { (*it)(); } catch (...) {}
            }
        }
    }

    template <typename A, typename R>
    void add(A&& action, R&& rollback) {
        local_rollbacks_.push_back(rollback);
        try {
            std::forward<A>(action)();
        } catch (...) {
            local_rollbacks_.pop_back();
            throw;
        }
    }

    void commit() {
        // 将本地回滚合并到父事务
        for (auto& r : local_rollbacks_) {
            parent_.add_rollback(std::move(r));
        }
        local_rollbacks_.clear();
        committed_ = true;
    }
};

// ========== 使用示例 ==========

/*
// 银行转账示例
void transfer(Account& from, Account& to, Money amount) {
    Transaction tx;

    Money from_balance = from.balance();
    tx.add(
        [&]() { from.withdraw(amount); },
        [&]() { from.deposit(amount); }
    );

    Money to_balance = to.balance();
    tx.add(
        [&]() { to.deposit(amount); },
        [&]() { to.withdraw(amount); }
    );

    // 验证
    if (from.balance() < 0) {
        throw InsufficientFunds();
    }

    tx.commit();
}

// 数据库操作示例
void complex_update(Database& db) {
    Transaction tx;

    auto user = db.get_user(user_id);
    tx.add(
        [&]() { db.update_user(user_id, new_data); },
        [&]() { db.update_user(user_id, user); }
    );

    for (auto& order : orders) {
        auto old_order = db.get_order(order.id);
        tx.add(
            [&]() { db.update_order(order); },
            [&, old_order]() { db.update_order(old_order); }
        );
    }

    tx.commit();
}
*/

} // namespace mini
```

### 第四周思考题

1. **错误处理策略**
   - 什么情况下应该使用异常？什么情况下应该使用expected？
   - 如何在大型项目中统一错误处理策略？

2. **std::expected相关**
   - and_then和transform有什么区别？
   - 为什么expected需要void特化？

3. **Transaction相关**
   - Transaction类如何实现强异常保证？
   - 嵌套事务有什么用？

---

## 检验标准

### 知识检验
- [ ] 解释零成本异常模型的含义及其实现原理
- [ ] 四种异常安全等级分别是什么？各举一例
- [ ] 为什么RAII是异常安全的关键？
- [ ] Copy-and-Swap如何实现强保证？
- [ ] std::expected相比异常有什么优势和劣势？
- [ ] 什么时候应该使用noexcept？

### 实践检验
- [ ] mini_expected支持基本的值/错误处理和monadic操作
- [ ] SafeStack的所有操作都有明确的异常安全保证
- [ ] Transaction类能正确处理多步操作的回滚
- [ ] 所有代码都有对应的测试用例

### 输出物
1. `mini_expected.hpp` - 完整的expected实现
2. `safe_stack.hpp` - 异常安全的栈实现
3. `transaction.hpp` - 事务类实现
4. `test_exception_safety.cpp` - 测试代码
5. `notes/month07_exceptions.md` - 学习笔记

---

## 源码阅读任务

### 深度阅读清单

#### 异常处理底层
- [ ] `libstdc++-v3/libsupc++/eh_throw.cc` - __cxa_throw实现
- [ ] `libstdc++-v3/libsupc++/eh_catch.cc` - catch相关函数
- [ ] `libstdc++-v3/libsupc++/eh_personality.cc` - personality routine
- [ ] `libstdc++-v3/libsupc++/unwind-cxx.h` - 异常对象结构

#### 标准库异常安全
- [ ] `std::vector`的push_back实现（关注扩容逻辑）
- [ ] `std::optional`实现
- [ ] `std::variant`的异常安全实现

#### 现代错误处理
- [ ] Boost.Outcome源码
- [ ] std::expected（C++23）提案和参考实现

### 阅读指南

```cpp
// 阅读libstdc++源码的关键入口点：

// 1. eh_throw.cc 中的 __cxa_throw
extern "C" void
__cxa_throw(void* obj, std::type_info* tinfo, void (*dest)(void*))
{
    // 分配异常对象头
    __cxa_exception* header = __cxa_allocate_exception(sizeof(...));

    // 填充头信息
    header->exceptionType = tinfo;
    header->exceptionDestructor = dest;

    // 开始栈展开
    _Unwind_RaiseException(&header->unwindHeader);

    // 如果返回，说明没找到handler
    std::terminate();
}

// 2. vector的push_back关键逻辑
template<typename T>
void vector<T>::push_back(const T& value) {
    if (size_ == capacity_) {
        // 重新分配
        // 关键：如果T的移动是noexcept，用移动
        // 否则用拷贝，以保证强异常保证
        if constexpr (std::is_nothrow_move_constructible_v<T>) {
            // 使用移动
        } else {
            // 使用拷贝
        }
    }
    // ...
}
```

---

## 时间分配（140小时/月）

| 内容 | 时间 | 占比 |
|------|------|------|
| 第一周：异常底层实现 | 35小时 | 25% |
| 第二周：异常安全等级 | 35小时 | 25% |
| 第三周：编写异常安全代码 | 35小时 | 25% |
| 第四周：现代错误处理替代方案 | 35小时 | 25% |

### 每周时间细分

| 活动 | 每周时间 |
|------|----------|
| 理论学习 | 8小时 |
| 源码阅读 | 6小时 |
| 代码实践 | 15小时 |
| 思考与总结 | 6小时 |

---

## 面试常见问题

1. **什么是RAII？为什么它对异常安全很重要？**

2. **解释C++的四种异常安全等级**

3. **什么时候应该将函数标记为noexcept？**

4. **Copy-and-Swap惯用法如何工作？它有什么优缺点？**

5. **std::vector的push_back是什么异常安全等级？为什么？**

6. **为什么析构函数不应该抛出异常？**

7. **std::expected相比异常有什么优势？**

8. **如何测试一个函数是否异常安全？**

---

## 下月预告

Month 08将学习**函数对象与Lambda深度**，深入理解lambda的底层实现、std::function的类型擦除机制，以及高阶函数的应用。

### 预习建议
- 回顾函数指针的使用
- 了解std::function的基本用法
- 思考：lambda表达式在编译后会变成什么？
