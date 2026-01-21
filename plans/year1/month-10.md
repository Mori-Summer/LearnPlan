# Month 10: 字符串处理与正则表达式——文本处理的艺术

## 本月主题概述

字符串是最常用的数据类型之一，但C++的字符串处理有许多深层细节。本月将深入std::string的SSO优化、std::string_view的设计哲学、字符编码处理，以及正则表达式的使用。

---

## 理论学习内容

### 第一周：std::string内部实现

**学习目标**：理解string的内存布局和优化策略

**阅读材料**：
- [ ] 《STL源码剖析》string章节
- [ ] CppCon演讲："std::string - The Complete Story"
- [ ] 博客：SSO实现对比分析

**核心概念**：

#### 小字符串优化（SSO）
```cpp
// std::string的典型布局（简化）
// 方案1：libstdc++（GCC）
class string {
    // 当字符串短时，直接存储在这里
    // 当字符串长时，这是指向堆的指针
    union {
        char local_buffer[16];  // SSO缓冲区
        struct {
            char* ptr;
            size_t size;
            size_t capacity;
        } heap;
    };
    // 使用某种标志位区分
};

// 方案2：libc++（LLVM）
// 使用capacity的最低位作为标志
// short string: capacity最低位为1
// long string: capacity最低位为0（对齐保证）
```

**验证SSO大小**：
```cpp
#include <string>
#include <iostream>

int main() {
    std::string s;
    // 找到SSO阈值
    for (int i = 0; i < 32; ++i) {
        s.push_back('a');
        // data()地址在栈上还是堆上
        bool is_sso = (s.data() >= reinterpret_cast<const char*>(&s) &&
                       s.data() < reinterpret_cast<const char*>(&s) + sizeof(s));
        std::cout << "size=" << i + 1 << " SSO=" << is_sso << "\n";
    }
}
// 典型结果：libstdc++ SSO上限15字节，libc++ SSO上限22字节
```

#### Copy-on-Write（已废弃）
```cpp
// C++11之前，一些实现使用COW
// std::string a = "hello";
// std::string b = a;  // b和a共享同一块内存
// b[0] = 'H';  // 此时才真正拷贝

// C++11要求string是move-safe，COW被禁止
// 因为COW需要引用计数，与move语义和多线程不兼容
```

#### 每日学习计划

| 天数 | 主题 | 学习内容 | 实践任务 | 预计时间 |
|------|------|----------|----------|----------|
| Day 1 | SSO基础 | 理解SSO概念、为何需要SSO、基本原理 | 运行SSO阈值探测代码，记录你的编译器结果 | 5h |
| Day 2 | SSO实现对比 | 深入学习libstdc++、libc++、MSVC三种实现 | 阅读libstdc++源码中basic_string的SSO部分 | 5h |
| Day 3 | 内存布局分析 | 学习string的内存布局、union技巧、标志位设计 | 用gdb/lldb观察string对象的内存布局 | 5h |
| Day 4 | 内存分配策略 | reserve、shrink_to_fit、增长因子、allocator | 编写测试程序验证增长因子 | 5h |
| Day 5 | COW历史 | 理解COW原理、为何C++11废弃、线程安全问题 | 实现一个简单的COW字符串 | 5h |
| Day 6 | 迭代器失效 | string操作的迭代器失效规则、安全使用方法 | 编写迭代器失效的测试用例 | 5h |
| Day 7 | 综合实践 | 复习本周内容，完成MiniString的SSO部分 | 开始实现MiniString | 5h |

#### 深度扩展：三大标准库SSO实现对比

**libstdc++（GCC）的实现**：
```cpp
// GCC的实现使用一个union来区分短字符串和长字符串
// 短字符串阈值：15字节（64位系统）

// 简化的内部结构
struct _Alloc_hider {
    pointer _M_p;  // 指向实际数据（无论是本地还是堆）
};

union {
    char _M_local_buf[16];  // 本地缓冲区
    size_type _M_allocated_capacity;  // 堆分配的容量
};

// 关键洞察：
// - _M_p 总是指向有效数据
// - 短字符串时，_M_p 指向 _M_local_buf
// - 长字符串时，_M_p 指向堆内存
// - 通过比较 _M_p 和 _M_local_buf 的地址判断是否SSO
```

**libc++（LLVM/Clang）的实现**：
```cpp
// Clang的实现更加紧凑，短字符串阈值：22字节（64位系统）

// 使用capacity的最低位作为标志
// 短字符串：capacity最低位为1
// 长字符串：capacity最低位为0（因为capacity是对齐的）

struct __long {
    pointer __data_;
    size_type __size_;
    size_type __cap_;  // 最低位为0
};

struct __short {
    char __data_[23];
    unsigned char __size_;  // 最高位为1表示短字符串
};

// 关键洞察：
// - 利用了小端字节序
// - __size_的最高位和__cap_的最低位在同一字节位置
// - 短字符串可以存储22个字符 + 1个null终止符
```

**MSVC STL的实现**：
```cpp
// MSVC的实现，短字符串阈值：15字节

union _Bxty {
    char _Buf[16];  // 短字符串缓冲区
    pointer _Ptr;   // 长字符串指针
};

size_type _Mysize;  // 当前大小
size_type _Myres;   // 当前容量

// 关键洞察：
// - 通过 _Myres < 16 判断是否为短字符串
// - 结构相对简单直观
// - 短字符串可以存储15个字符
```

**SSO阈值对比实验**：
```cpp
#include <string>
#include <iostream>
#include <cstdint>

void analyze_string_layout() {
    std::cout << "sizeof(std::string) = " << sizeof(std::string) << "\n";

    std::string s;
    const char* base = reinterpret_cast<const char*>(&s);

    std::cout << "\n=== SSO Threshold Detection ===\n";
    for (size_t i = 0; i <= 30; ++i) {
        s = std::string(i, 'x');
        const char* data = s.data();

        // 检查data是否在string对象内部
        bool is_internal = (data >= base && data < base + sizeof(std::string));

        std::cout << "Length " << i << ": "
                  << (is_internal ? "SSO (internal)" : "HEAP (external)")
                  << " capacity=" << s.capacity() << "\n";
    }
}

// 典型输出（libstdc++）：
// sizeof(std::string) = 32
// Length 0-15: SSO (internal)
// Length 16+: HEAP (external)

// 典型输出（libc++）：
// sizeof(std::string) = 24
// Length 0-22: SSO (internal)
// Length 23+: HEAP (external)
```

#### 深度扩展：内存分配策略与增长因子

```cpp
#include <string>
#include <iostream>
#include <vector>

void analyze_growth_factor() {
    std::string s;
    size_t prev_cap = 0;

    std::cout << "=== String Growth Analysis ===\n";
    std::cout << "Size\tCapacity\tGrowth Ratio\n";

    for (int i = 0; i < 1000; ++i) {
        s.push_back('x');
        if (s.capacity() != prev_cap) {
            double ratio = prev_cap > 0 ?
                static_cast<double>(s.capacity()) / prev_cap : 0;
            std::cout << s.size() << "\t" << s.capacity()
                      << "\t\t" << ratio << "\n";
            prev_cap = s.capacity();
        }
    }
}

// 典型增长因子：
// - libstdc++: 2x
// - libc++: 2x
// - MSVC: 1.5x

// reserve的行为
void demonstrate_reserve() {
    std::string s;

    // reserve只会增加容量，不会减少
    s.reserve(100);
    std::cout << "After reserve(100): capacity = " << s.capacity() << "\n";

    s.reserve(50);  // 可能被忽略
    std::cout << "After reserve(50): capacity = " << s.capacity() << "\n";

    // shrink_to_fit可以减少容量（但不保证）
    s = "hello";
    s.shrink_to_fit();
    std::cout << "After shrink_to_fit: capacity = " << s.capacity() << "\n";
}
```

#### 深度扩展：迭代器失效规则

```cpp
#include <string>
#include <iostream>

void iterator_invalidation_rules() {
    std::string s = "hello world";

    // 1. 任何可能重新分配内存的操作都会使迭代器失效
    auto it = s.begin();

    // 危险操作示例：
    // s.push_back('!');     // 可能失效
    // s.append("more");     // 可能失效
    // s.insert(s.end(), 'x'); // 可能失效
    // s.reserve(1000);      // 可能失效（如果增加容量）
    // s += "more text";     // 可能失效

    // 2. 不会使迭代器失效的操作（前提是不重新分配）
    s[0] = 'H';           // 安全
    s.front() = 'h';      // 安全

    // 3. erase会使被删除位置及之后的迭代器失效
    s = "hello world";
    it = s.begin() + 5;
    s.erase(s.begin(), s.begin() + 3);  // it现在失效

    // 4. insert会使插入位置及之后的迭代器失效
    s = "hello";
    it = s.begin() + 2;
    s.insert(s.begin() + 1, 'X');  // it可能失效

    // 5. clear会使所有迭代器失效
    s.clear();  // 所有迭代器失效
}

// 安全的遍历并修改
void safe_iteration_example() {
    std::string s = "hello world";

    // 错误方式（可能导致迭代器失效）
    // for (auto it = s.begin(); it != s.end(); ++it) {
    //     if (*it == 'o') {
    //         s.insert(it + 1, 'O');  // 危险！
    //     }
    // }

    // 正确方式1：使用索引
    for (size_t i = 0; i < s.size(); ++i) {
        if (s[i] == 'o') {
            s.insert(i + 1, 'O');
            ++i;  // 跳过刚插入的字符
        }
    }

    // 正确方式2：先收集位置，再批量处理
    std::vector<size_t> positions;
    for (size_t i = 0; i < s.size(); ++i) {
        if (s[i] == 'l') positions.push_back(i);
    }
    // 从后往前处理，避免位置偏移
    for (auto it = positions.rbegin(); it != positions.rend(); ++it) {
        s.insert(*it + 1, 'L');
    }
}
```

#### 深度扩展：COW实现示例（理解历史）

```cpp
// 这是一个教学用的COW字符串实现
// 注意：现代C++不应使用COW，仅供理解历史
#include <atomic>
#include <cstring>
#include <algorithm>

class COWString {
    struct Buffer {
        std::atomic<int> ref_count{1};
        size_t size;
        size_t capacity;
        char data[1];  // 柔性数组成员（C++中不标准，仅演示）

        static Buffer* create(size_t cap) {
            void* mem = ::operator new(sizeof(Buffer) + cap);
            Buffer* buf = new(mem) Buffer();
            buf->capacity = cap;
            buf->size = 0;
            buf->data[0] = '\0';
            return buf;
        }

        void release() {
            if (--ref_count == 0) {
                ::operator delete(this);
            }
        }

        Buffer* clone() const {
            Buffer* buf = create(capacity);
            std::memcpy(buf->data, data, size + 1);
            buf->size = size;
            return buf;
        }
    };

    Buffer* buf_;

    // 确保唯一所有权（写时复制的核心）
    void make_unique() {
        if (buf_->ref_count > 1) {
            Buffer* new_buf = buf_->clone();
            buf_->release();
            buf_ = new_buf;
        }
    }

public:
    COWString() : buf_(Buffer::create(15)) {}

    COWString(const char* s) {
        size_t len = std::strlen(s);
        buf_ = Buffer::create(len);
        std::memcpy(buf_->data, s, len + 1);
        buf_->size = len;
    }

    // 拷贝构造：只增加引用计数
    COWString(const COWString& other) : buf_(other.buf_) {
        ++buf_->ref_count;
    }

    ~COWString() {
        buf_->release();
    }

    // 赋值
    COWString& operator=(COWString other) {
        std::swap(buf_, other.buf_);
        return *this;
    }

    // 只读访问：不需要复制
    const char* c_str() const { return buf_->data; }
    size_t size() const { return buf_->size; }
    char operator[](size_t i) const { return buf_->data[i]; }

    // 写访问：可能需要复制
    char& operator[](size_t i) {
        make_unique();  // 写时复制！
        return buf_->data[i];
    }

    // 为什么COW在C++11中被禁止？
    // 1. 多线程问题：ref_count需要原子操作，开销大
    // 2. 迭代器问题：begin()返回的迭代器可能在另一个线程修改
    // 3. 与move语义冲突：move后原对象应该为空，但COW共享数据
};

// COW的线程安全问题演示
void cow_thread_safety_issue() {
    // 想象这段代码在多线程环境下
    // COWString s1 = "hello";
    // COWString s2 = s1;  // s1和s2共享同一个Buffer

    // 线程1                线程2
    // char c = s1[0];      s2[0] = 'H';  // 触发COW
    //
    // 问题：线程1可能在线程2复制期间访问被释放的内存
}
```

#### 本周练习

1. **SSO探测器**：编写程序检测你的标准库的SSO阈值
2. **增长因子分析**：分析string的容量增长模式
3. **内存追踪器**：使用自定义allocator追踪string的内存分配
4. **迭代器安全检查**：编写测试用例验证各种操作的迭代器失效情况

#### 延伸阅读

- CppCon 2016: "std::string: The Complete Story" by Marshal Clow
- libstdc++ 源码: `bits/basic_string.h`
- libc++ 源码: `string`
- 博客: "Exploring std::string" by Howard Hinnant
- C++ Core Guidelines: SL.str.1-12

#### 周末自测

**理论题**：
1. 解释SSO的含义及其优化原理
2. 为什么libc++的SSO阈值（22字节）比libstdc++（15字节）高？
3. C++11为何禁止COW实现？举例说明线程安全问题
4. 列出三种会使string迭代器失效的操作
5. reserve(n)和resize(n)的区别是什么？

**代码题**：
1. 实现一个函数，判断给定的string当前是否使用SSO
2. 编写测试验证你的编译器的string增长因子
3. 实现一个简单的引用计数字符串类（理解COW概念）

---

### 第二周：std::string_view

**学习目标**：理解非拥有字符串视图

**核心概念**：
```cpp
// string_view = 指针 + 长度，不拥有数据
class string_view {
    const char* data_;
    size_t size_;
public:
    // 从各种来源构造
    string_view(const char* s);
    string_view(const char* s, size_t len);
    string_view(const std::string& s);

    // 不能修改
    const char* data() const;
    size_t size() const;
    char operator[](size_t pos) const;

    // 子串视图（不分配内存！）
    string_view substr(size_t pos, size_t len) const;

    // 查找
    size_t find(char c) const;
};
```

**使用场景和注意事项**：
```cpp
// 好的使用
void process(std::string_view sv);  // 函数参数
process("literal");      // 无拷贝
process(some_string);    // 无拷贝
process(sv.substr(0, 5)); // 无分配

// 危险！悬空引用
std::string_view dangerous() {
    std::string s = "hello";
    return s;  // s被销毁，返回悬空view
}

std::string_view also_dangerous(std::string s) {
    return s;  // s是按值传递，函数返回时销毁
}

// 注意：string_view没有null终止保证
void print_cstr(const char* s);  // 需要null终止
std::string_view sv = "hello";
// print_cstr(sv.data());  // 危险！sv可能不是null终止的

// 安全的做法
std::string temp(sv);
print_cstr(temp.c_str());
```

#### 每日学习计划

| 天数 | 主题 | 学习内容 | 实践任务 | 预计时间 |
|------|------|----------|----------|----------|
| Day 1 | string_view基础 | 理解string_view的设计目的、内部结构 | 实现基本的MiniStringView | 5h |
| Day 2 | 零拷贝哲学 | 深入理解借用语义、与所有权的关系 | 对比string和string_view的性能 | 5h |
| Day 3 | 生命周期陷阱 | 学习常见的悬空引用场景 | 编写陷阱场景的测试代码 | 5h |
| Day 4 | 最佳实践 | 函数参数选择、返回值处理 | 重构代码使用string_view | 5h |
| Day 5 | span与ranges | 对比string_view、span、ranges的设计 | 实现简单的span | 5h |
| Day 6 | 实践项目 | 实现零拷贝CSV解析器 | 完成CSV解析器 | 5h |
| Day 7 | 综合复习 | 复习本周内容，完善MiniStringView | 添加完整测试用例 | 5h |

#### 深度扩展：零拷贝设计哲学

```cpp
// 零拷贝（Zero-Copy）是高性能编程的核心思想之一
// string_view体现了"借用而非拥有"的设计哲学

// 传统方式：每次传递都可能拷贝
void process_old(std::string s);           // 拷贝
void process_ref(const std::string& s);    // 引用，但只接受string
void process_ptr(const char* s);           // 指针，但失去长度信息

// 现代方式：零拷贝且类型统一
void process_view(std::string_view sv);    // 零拷贝，接受多种来源

// string_view的本质
// - 仅存储指针和长度（通常16字节）
// - 不管理内存，不拷贝数据
// - 提供只读访问

// 性能对比示例
#include <string>
#include <string_view>
#include <chrono>
#include <iostream>

void benchmark_string_passing() {
    const std::string long_str(10000, 'x');
    const int iterations = 1000000;

    // 测试1：传值
    auto start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < iterations; ++i) {
        [](std::string s) { (void)s.size(); }(long_str);
    }
    auto end = std::chrono::high_resolution_clock::now();
    std::cout << "By value: "
              << std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count()
              << "ms\n";

    // 测试2：const引用
    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < iterations; ++i) {
        [](const std::string& s) { (void)s.size(); }(long_str);
    }
    end = std::chrono::high_resolution_clock::now();
    std::cout << "By const ref: "
              << std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count()
              << "ms\n";

    // 测试3：string_view
    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < iterations; ++i) {
        [](std::string_view sv) { (void)sv.size(); }(long_str);
    }
    end = std::chrono::high_resolution_clock::now();
    std::cout << "By string_view: "
              << std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count()
              << "ms\n";
}
```

#### 深度扩展：13种生命周期陷阱场景

```cpp
#include <string>
#include <string_view>
#include <vector>
#include <map>
#include <optional>

// ========== 陷阱1：返回局部string的view ==========
std::string_view trap1_return_local() {
    std::string local = "hello";
    return local;  // 危险！local被销毁后view悬空
}

// 修复方案：返回string而非string_view
std::string fix1_return_local() {
    std::string local = "hello";
    return local;  // 正确：返回拷贝或移动
}

// ========== 陷阱2：参数按值传递后返回view ==========
std::string_view trap2_param_by_value(std::string s) {
    return s;  // 危险！s在函数返回时销毁
}

// 修复方案：参数用const引用
std::string_view fix2_param_by_ref(const std::string& s) {
    return s;  // 安全：调用者负责s的生命周期
}

// ========== 陷阱3：临时对象的view ==========
void trap3_temporary() {
    std::string_view sv = std::string("temp");  // 危险！临时对象立即销毁
    // sv现在是悬空的
}

// 修复方案：确保源对象存活
void fix3_temporary() {
    std::string str = "temp";
    std::string_view sv = str;  // 安全
    // 使用sv...
}

// ========== 陷阱4：容器中存储string_view ==========
std::vector<std::string_view> trap4_container() {
    std::vector<std::string_view> views;
    for (int i = 0; i < 3; ++i) {
        std::string temp = "item" + std::to_string(i);
        views.push_back(temp);  // 危险！temp在循环结束时销毁
    }
    return views;  // 所有view都悬空
}

// 修复方案：存储string而非string_view
std::vector<std::string> fix4_container() {
    std::vector<std::string> strings;
    for (int i = 0; i < 3; ++i) {
        strings.push_back("item" + std::to_string(i));
    }
    return strings;
}

// ========== 陷阱5：substr返回的view ==========
void trap5_substr() {
    std::string_view sv = std::string("hello world").substr(0, 5);
    // 危险！临时string已销毁，sv悬空
}

// 注意：string_view::substr返回的是view，不是新string
void clarify_substr() {
    std::string str = "hello world";
    std::string_view sv = str;
    std::string_view sub = sv.substr(0, 5);  // 安全：sub指向str的一部分
    // 只要str存活，sub就有效
}

// ========== 陷阱6：map的key使用string_view ==========
void trap6_map_key() {
    std::map<std::string_view, int> m;
    {
        std::string key = "hello";
        m[key] = 42;  // 危险！
    }
    // key已销毁，map中的key悬空
    // auto it = m.find("hello");  // 未定义行为
}

// ========== 陷阱7：optional中的string_view ==========
std::optional<std::string_view> trap7_optional() {
    std::string temp = "hello";
    return temp;  // 危险！temp销毁后optional中的view悬空
}

// ========== 陷阱8：成员变量存储string_view ==========
class trap8_member {
    std::string_view sv_;  // 危险的设计
public:
    trap8_member(std::string s) : sv_(s) {}  // s销毁后sv_悬空
};

// 修复方案：存储string
class fix8_member {
    std::string str_;
public:
    fix8_member(std::string s) : str_(std::move(s)) {}
    std::string_view view() const { return str_; }
};

// ========== 陷阱9：字符串连接 ==========
void trap9_concatenation() {
    std::string a = "hello";
    std::string b = "world";
    std::string_view sv = a + b;  // 危险！a+b是临时对象
}

// ========== 陷阱10：resize后的view ==========
void trap10_resize() {
    std::string str = "hello";
    std::string_view sv = str;
    str.reserve(1000);  // 可能重新分配内存
    // sv可能悬空！
}

// ========== 陷阱11：clear后的view ==========
void trap11_clear() {
    std::string str = "hello";
    std::string_view sv = str;
    str.clear();  // str现在为空
    // sv仍然指向原内存，但访问是未定义行为
    // （实际上SSO时可能仍然有效，但不应依赖）
}

// ========== 陷阱12：多线程中的view ==========
void trap12_multithreading() {
    // 线程1持有string_view
    // 线程2修改原string
    // 即使原string存活，修改也可能使view失效
}

// ========== 陷阱13：null终止假设 ==========
void trap13_null_termination() {
    std::string str = "hello\0world";  // 包含嵌入的null
    std::string_view sv = str;
    // sv.data() 返回的不一定是null终止的
    // printf("%s", sv.data());  // 可能打印意外内容
}

// 安全使用string_view的总结规则
/*
1. 永远不要存储string_view（除非你能保证源对象的生命周期）
2. 永远不要返回指向局部变量的string_view
3. 永远不要用string_view作为成员变量（除非有明确的生命周期保证）
4. 永远不要假设string_view是null终止的
5. 修改源string后，假设所有相关的string_view都失效
*/
```

#### 深度扩展：函数签名决策树

```cpp
// 如何选择函数参数类型？遵循以下决策树：

/*
┌─────────────────────────────────────────────────────────────┐
│                    函数需要字符串输入？                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
         ┌────────────────────┴────────────────────┐
         │           函数需要修改字符串？             │
         └────────────────────┬────────────────────┘
                 │                        │
                YES                      NO
                 │                        │
                 ▼                        ▼
    ┌────────────────────┐    ┌────────────────────────────┐
    │   std::string&     │    │    函数需要保存字符串？      │
    │   （可修改引用）     │    └────────────────────────────┘
    └────────────────────┘              │           │
                                       YES         NO
                                        │           │
                                        ▼           ▼
                          ┌──────────────────┐  ┌──────────────────────┐
                          │   std::string    │  │  字符串通常很短？      │
                          │   （按值，会移动） │  └──────────────────────┘
                          └──────────────────┘        │           │
                                                     YES         NO
                                                      │           │
                                                      ▼           ▼
                                        ┌──────────────────┐  ┌──────────────────┐
                                        │  std::string_view│  │  std::string_view│
                                        │  （或const string&）│  │  （推荐）        │
                                        └──────────────────┘  └──────────────────┘
*/

// 具体示例

// 1. 需要修改
void modify_string(std::string& s) {
    s += "!";
}

// 2. 需要保存（作为成员、返回等）
class Document {
    std::string title_;
public:
    // 方案A：接受string，支持移动
    void set_title(std::string title) {
        title_ = std::move(title);
    }

    // 方案B：接受string_view，但需要拷贝
    // void set_title(std::string_view title) {
    //     title_ = title;  // 总是拷贝
    // }
};

// 3. 只需要读取，字符串可能很长
void process_text(std::string_view text) {
    // 处理文本...
}

// 4. 只需要读取，短字符串为主
// 这种情况 const string& 和 string_view 都可以
void log_message(std::string_view msg) {
    std::cout << msg << "\n";
}

// 特殊情况：需要与C API交互
void call_c_api(const std::string& s) {
    // C API通常需要null终止的字符串
    c_function(s.c_str());  // 安全
}

// 错误：不要这样做
void call_c_api_wrong(std::string_view sv) {
    // c_function(sv.data());  // 危险！可能不是null终止的
    std::string temp(sv);
    c_function(temp.c_str());  // 安全但有额外拷贝
}
```

#### 深度扩展：string_view vs span vs ranges

```cpp
#include <string_view>
#include <span>        // C++20
#include <ranges>      // C++20
#include <vector>

// string_view: 专门用于字符数据的视图
// - 只适用于字符类型
// - 提供字符串特有的操作（find, substr等）
// - 隐式转换自string和const char*

// span: 通用连续内存视图
// - 适用于任何类型的数组
// - 提供通用容器操作
// - 可以是mutable的

// ranges: 更通用的范围抽象
// - 不要求连续内存
// - 支持惰性求值
// - 可组合的操作

void compare_views() {
    // string_view示例
    std::string str = "hello";
    std::string_view sv = str;
    auto sub = sv.substr(1, 3);  // "ell"
    auto pos = sv.find('l');     // 2

    // span示例
    int arr[] = {1, 2, 3, 4, 5};
    std::span<int> sp(arr);
    std::span<int> sub_sp = sp.subspan(1, 3);  // {2, 3, 4}

    // mutable span
    std::span<int> mutable_sp(arr);
    mutable_sp[0] = 100;  // 可以修改

    // const span（类似string_view）
    std::span<const int> const_sp(arr);
    // const_sp[0] = 100;  // 编译错误

    // 字符的span vs string_view
    char chars[] = "hello";
    std::span<char> char_span(chars, 5);
    std::string_view sv2(chars, 5);

    // span没有字符串操作
    // char_span.find('l');  // 编译错误

    // string_view有
    sv2.find('l');  // OK
}

// 实现一个简单的span（理解原理）
template<typename T>
class SimpleSpan {
    T* data_;
    size_t size_;
public:
    constexpr SimpleSpan() noexcept : data_(nullptr), size_(0) {}
    constexpr SimpleSpan(T* data, size_t size) : data_(data), size_(size) {}

    template<size_t N>
    constexpr SimpleSpan(T (&arr)[N]) : data_(arr), size_(N) {}

    constexpr T* data() const noexcept { return data_; }
    constexpr size_t size() const noexcept { return size_; }
    constexpr bool empty() const noexcept { return size_ == 0; }

    constexpr T& operator[](size_t idx) const { return data_[idx]; }
    constexpr T* begin() const noexcept { return data_; }
    constexpr T* end() const noexcept { return data_ + size_; }

    constexpr SimpleSpan subspan(size_t offset, size_t count) const {
        return SimpleSpan(data_ + offset, count);
    }
};
```

#### 项目：零拷贝CSV解析器

```cpp
// csv_parser.hpp
#pragma once
#include <string_view>
#include <vector>
#include <stdexcept>

class CSVParser {
public:
    struct Row {
        std::vector<std::string_view> fields;
    };

private:
    std::string_view data_;
    char delimiter_;
    char quote_;
    std::vector<Row> rows_;

    // 解析单个字段
    std::string_view parse_field(std::string_view& line) {
        if (line.empty()) return {};

        // 处理带引号的字段
        if (line.front() == quote_) {
            size_t end = 1;
            while (end < line.size()) {
                if (line[end] == quote_) {
                    if (end + 1 < line.size() && line[end + 1] == quote_) {
                        // 转义的引号
                        end += 2;
                    } else {
                        // 字段结束
                        auto field = line.substr(1, end - 1);
                        if (end + 1 < line.size() && line[end + 1] == delimiter_) {
                            line.remove_prefix(end + 2);
                        } else {
                            line.remove_prefix(end + 1);
                        }
                        return field;
                    }
                } else {
                    ++end;
                }
            }
            throw std::runtime_error("Unclosed quote in CSV");
        }

        // 不带引号的字段
        size_t end = line.find(delimiter_);
        if (end == std::string_view::npos) {
            auto field = line;
            line = {};
            return field;
        }
        auto field = line.substr(0, end);
        line.remove_prefix(end + 1);
        return field;
    }

    // 解析单行
    Row parse_row(std::string_view line) {
        Row row;
        while (!line.empty()) {
            row.fields.push_back(parse_field(line));
        }
        return row;
    }

public:
    CSVParser(std::string_view data, char delimiter = ',', char quote = '"')
        : data_(data), delimiter_(delimiter), quote_(quote) {}

    void parse() {
        rows_.clear();
        std::string_view remaining = data_;

        while (!remaining.empty()) {
            size_t line_end = remaining.find('\n');
            std::string_view line;

            if (line_end == std::string_view::npos) {
                line = remaining;
                remaining = {};
            } else {
                line = remaining.substr(0, line_end);
                remaining.remove_prefix(line_end + 1);
            }

            // 处理\r\n
            if (!line.empty() && line.back() == '\r') {
                line.remove_suffix(1);
            }

            if (!line.empty()) {
                rows_.push_back(parse_row(line));
            }
        }
    }

    const std::vector<Row>& rows() const { return rows_; }

    // 获取特定单元格
    std::string_view get(size_t row, size_t col) const {
        if (row >= rows_.size()) {
            throw std::out_of_range("Row index out of range");
        }
        if (col >= rows_[row].fields.size()) {
            throw std::out_of_range("Column index out of range");
        }
        return rows_[row].fields[col];
    }

    size_t row_count() const { return rows_.size(); }

    size_t column_count(size_t row = 0) const {
        return row < rows_.size() ? rows_[row].fields.size() : 0;
    }
};

// 使用示例
void csv_parser_example() {
    // 注意：csv_data必须在CSVParser的整个生命周期内存活
    std::string csv_data = R"(name,age,city
Alice,30,New York
Bob,25,Los Angeles
Charlie,35,"San Francisco")";

    CSVParser parser(csv_data);
    parser.parse();

    std::cout << "Rows: " << parser.row_count() << "\n";
    for (size_t i = 0; i < parser.row_count(); ++i) {
        std::cout << "Row " << i << ": ";
        for (size_t j = 0; j < parser.column_count(i); ++j) {
            std::cout << "[" << parser.get(i, j) << "] ";
        }
        std::cout << "\n";
    }
}
```

#### 本周练习

1. **生命周期分析器**：编写代码演示每种生命周期陷阱
2. **性能对比**：对比`const string&`和`string_view`在不同场景下的性能
3. **CSV解析器扩展**：为CSV解析器添加迭代器支持
4. **SimpleSpan实现**：实现一个完整的span类

#### 延伸阅读

- CppCon 2018: "string_view" by Marshall Clow
- P0254R2: std::string_view提案
- C++ Core Guidelines: SL.str.3 (使用string_view传递字符序列)
- 博客: "How to Use C++17's string_view" by Bartlomiej Filipek
- libc++ string_view源码

#### 周末自测

**理论题**：
1. string_view的内部结构是什么？占用多少字节？
2. 列举5种会导致string_view悬空的场景
3. 何时应该用`const string&`而不是`string_view`？
4. string_view::substr和string::substr的区别是什么？
5. 为什么不应该用string_view作为类的成员变量？

**代码题**：
1. 实现一个安全的`split`函数，返回`vector<string_view>`
2. 重构一段使用`const string&`的代码，改用`string_view`
3. 实现一个零拷贝的行分割器

---

### 第三周：字符编码与Unicode

**学习目标**：理解C++的字符编码支持

**核心概念**：
```cpp
// 基本字符类型
char      // 至少8位，通常用于ASCII或UTF-8
wchar_t   // 宽字符，Windows上16位，Linux上32位
char8_t   // C++20，专用于UTF-8
char16_t  // UTF-16
char32_t  // UTF-32

// 字符串字面量前缀
"hello"     // const char[]
L"hello"    // const wchar_t[]
u8"hello"   // const char8_t[] (C++20)
u"hello"    // const char16_t[]
U"hello"    // const char32_t[]

// 原始字符串（避免转义）
R"(raw string with \n literal backslash)"
```

**UTF-8处理**：
```cpp
#include <string>
#include <codecvt>  // C++17废弃
#include <locale>

// UTF-8字符串长度（码点数，不是字节数）
size_t utf8_length(const std::string& s) {
    size_t len = 0;
    for (size_t i = 0; i < s.size(); ) {
        unsigned char c = s[i];
        if ((c & 0x80) == 0) i += 1;        // ASCII
        else if ((c & 0xE0) == 0xC0) i += 2; // 2字节
        else if ((c & 0xF0) == 0xE0) i += 3; // 3字节
        else if ((c & 0xF8) == 0xF0) i += 4; // 4字节
        else ++i;  // 无效，跳过
        ++len;
    }
    return len;
}

// UTF-8迭代器（简化版）
class Utf8Iterator {
    const char* ptr_;
public:
    explicit Utf8Iterator(const char* p) : ptr_(p) {}

    char32_t operator*() const {
        unsigned char c = *ptr_;
        if ((c & 0x80) == 0) return c;
        if ((c & 0xE0) == 0xC0) {
            return ((c & 0x1F) << 6) | (ptr_[1] & 0x3F);
        }
        // ...处理3字节和4字节
        return 0;
    }

    Utf8Iterator& operator++() {
        unsigned char c = *ptr_;
        if ((c & 0x80) == 0) ptr_ += 1;
        else if ((c & 0xE0) == 0xC0) ptr_ += 2;
        else if ((c & 0xF0) == 0xE0) ptr_ += 3;
        else if ((c & 0xF8) == 0xF0) ptr_ += 4;
        else ++ptr_;
        return *this;
    }
};
```

#### 每日学习计划

| 天数 | 主题 | 学习内容 | 实践任务 | 预计时间 |
|------|------|----------|----------|----------|
| Day 1 | 编码历史 | ASCII、Latin-1、各国编码的演进 | 研究不同编码的特点 | 5h |
| Day 2 | Unicode基础 | 码点、码元、字形簇概念 | 编写码点计数程序 | 5h |
| Day 3 | UTF-8详解 | UTF-8编码规则、变长编码原理 | 实现UTF-8编解码器 | 5h |
| Day 4 | UTF-16/32 | UTF-16代理对、UTF-32特点、BOM | 实现编码转换函数 | 5h |
| Day 5 | C++编码支持 | char8_t、char16_t、char32_t、codecvt | 测试各种字符类型 | 5h |
| Day 6 | 实践项目 | 实现编码检测器和转换器 | 完成编码检测器 | 5h |
| Day 7 | 综合复习 | ICU库简介、本周总结 | 尝试使用ICU库 | 5h |

#### 深度扩展：字符编码历史演进

```cpp
/*
字符编码的演进历史：

1. ASCII (1963)
   - 7位编码，128个字符
   - 只能表示英文字母、数字、标点和控制字符
   - 问题：无法表示其他语言

2. 扩展ASCII / Code Pages (1980s)
   - 8位编码，256个字符
   - 不同地区使用不同的代码页：
     - CP437: IBM PC原始编码
     - CP1252: Windows西欧
     - ISO-8859-1 (Latin-1): 西欧标准
     - GB2312/GBK: 中文
     - Shift_JIS: 日文
     - EUC-KR: 韩文
   - 问题：不同代码页互不兼容，"乱码"

3. Unicode (1991)
   - 统一字符集，每个字符有唯一码点
   - 当前包含超过14万字符
   - 码点范围：U+0000 到 U+10FFFF

4. Unicode编码形式
   - UTF-8: 变长编码（1-4字节），兼容ASCII
   - UTF-16: 变长编码（2或4字节），Windows内部使用
   - UTF-32: 定长编码（4字节），处理简单但占空间
*/

// 演示不同编码
void encoding_examples() {
    // ASCII
    char ascii[] = "Hello";  // 每个字符1字节

    // UTF-8 (C++默认，如果源文件是UTF-8)
    const char* utf8 = u8"你好世界";  // "你"=3字节，每个汉字3字节

    // UTF-16
    const char16_t* utf16 = u"你好世界";  // 每个汉字2字节

    // UTF-32
    const char32_t* utf32 = U"你好世界";  // 每个字符4字节

    // 字节长度比较
    std::cout << "UTF-8 bytes: " << strlen(utf8) << "\n";      // 12
    std::cout << "UTF-16 units: " << std::char_traits<char16_t>::length(utf16) << "\n";  // 4
    std::cout << "UTF-32 units: " << std::char_traits<char32_t>::length(utf32) << "\n";  // 4
}
```

#### 深度扩展：Unicode核心概念

```cpp
/*
Unicode核心概念：

1. 码点 (Code Point)
   - 字符的唯一编号，如 U+4E2D 代表 '中'
   - 范围：U+0000 到 U+10FFFF
   - 共有 1,114,112 个可能的码点

2. 码元 (Code Unit)
   - 编码的最小单位
   - UTF-8: 1字节
   - UTF-16: 2字节
   - UTF-32: 4字节

3. 字形簇 (Grapheme Cluster)
   - 用户感知的"字符"
   - 一个字形簇可能由多个码点组成
   - 例如：é = e + ´（组合字符）
   - 例如：👨‍👩‍👧 = 👨 + ZWJ + 👩 + ZWJ + 👧

4. 平面 (Plane)
   - BMP (Basic Multilingual Plane): U+0000 到 U+FFFF
   - SMP (Supplementary Multilingual Plane): U+10000 到 U+1FFFF (emoji等)
   - 其他辅助平面...

5. 规范化 (Normalization)
   - NFC: 组合形式 (é 作为单个码点)
   - NFD: 分解形式 (e + ´ 作为两个码点)
*/

#include <string>
#include <iostream>
#include <vector>

// 从UTF-8字符串提取码点
std::vector<char32_t> utf8_to_codepoints(const std::string& utf8) {
    std::vector<char32_t> result;
    const unsigned char* p = reinterpret_cast<const unsigned char*>(utf8.data());
    const unsigned char* end = p + utf8.size();

    while (p < end) {
        char32_t cp;
        if ((*p & 0x80) == 0) {
            // 1字节 (ASCII)
            cp = *p++;
        } else if ((*p & 0xE0) == 0xC0) {
            // 2字节
            cp = (*p++ & 0x1F) << 6;
            cp |= (*p++ & 0x3F);
        } else if ((*p & 0xF0) == 0xE0) {
            // 3字节
            cp = (*p++ & 0x0F) << 12;
            cp |= (*p++ & 0x3F) << 6;
            cp |= (*p++ & 0x3F);
        } else if ((*p & 0xF8) == 0xF0) {
            // 4字节
            cp = (*p++ & 0x07) << 18;
            cp |= (*p++ & 0x3F) << 12;
            cp |= (*p++ & 0x3F) << 6;
            cp |= (*p++ & 0x3F);
        } else {
            // 无效，跳过
            ++p;
            continue;
        }
        result.push_back(cp);
    }
    return result;
}

// 码点转UTF-8
std::string codepoint_to_utf8(char32_t cp) {
    std::string result;
    if (cp < 0x80) {
        result += static_cast<char>(cp);
    } else if (cp < 0x800) {
        result += static_cast<char>(0xC0 | (cp >> 6));
        result += static_cast<char>(0x80 | (cp & 0x3F));
    } else if (cp < 0x10000) {
        result += static_cast<char>(0xE0 | (cp >> 12));
        result += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
        result += static_cast<char>(0x80 | (cp & 0x3F));
    } else {
        result += static_cast<char>(0xF0 | (cp >> 18));
        result += static_cast<char>(0x80 | ((cp >> 12) & 0x3F));
        result += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
        result += static_cast<char>(0x80 | (cp & 0x3F));
    }
    return result;
}

// 演示字形簇的复杂性
void grapheme_cluster_demo() {
    // 看起来是一个字符，实际上是多个码点
    std::string flag = "🇨🇳";  // 中国国旗 = U+1F1E8 + U+1F1F3
    std::string family = "👨‍👩‍👧";  // 家庭emoji = 多个码点通过ZWJ连接

    auto flag_cps = utf8_to_codepoints(flag);
    auto family_cps = utf8_to_codepoints(family);

    std::cout << "Flag codepoints: " << flag_cps.size() << "\n";     // 2
    std::cout << "Family codepoints: " << family_cps.size() << "\n"; // 5

    // 打印每个码点
    std::cout << "Flag codepoints: ";
    for (auto cp : flag_cps) {
        std::cout << "U+" << std::hex << cp << " ";
    }
    std::cout << "\n";
}
```

#### 深度扩展：UTF-8编码算法详解

```cpp
/*
UTF-8编码规则：

码点范围              字节数   字节1      字节2      字节3      字节4
U+0000   - U+007F    1       0xxxxxxx
U+0080   - U+07FF    2       110xxxxx   10xxxxxx
U+0800   - U+FFFF    3       1110xxxx   10xxxxxx   10xxxxxx
U+10000  - U+10FFFF  4       11110xxx   10xxxxxx   10xxxxxx   10xxxxxx

特点：
1. 兼容ASCII（ASCII字符保持单字节）
2. 自同步：可以从任意位置开始解析
3. 无字节序问题（不需要BOM）
4. 多数西方文本比UTF-16更紧凑
5. 中文等CJK字符需要3字节
*/

#include <cstdint>
#include <string>
#include <stdexcept>
#include <optional>

class UTF8Codec {
public:
    // 编码单个码点
    static std::string encode(char32_t cp) {
        if (cp > 0x10FFFF) {
            throw std::invalid_argument("Code point out of range");
        }
        if (cp >= 0xD800 && cp <= 0xDFFF) {
            throw std::invalid_argument("Surrogate code points are invalid");
        }

        std::string result;
        if (cp < 0x80) {
            result += static_cast<char>(cp);
        } else if (cp < 0x800) {
            result += static_cast<char>(0xC0 | (cp >> 6));
            result += static_cast<char>(0x80 | (cp & 0x3F));
        } else if (cp < 0x10000) {
            result += static_cast<char>(0xE0 | (cp >> 12));
            result += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
            result += static_cast<char>(0x80 | (cp & 0x3F));
        } else {
            result += static_cast<char>(0xF0 | (cp >> 18));
            result += static_cast<char>(0x80 | ((cp >> 12) & 0x3F));
            result += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
            result += static_cast<char>(0x80 | (cp & 0x3F));
        }
        return result;
    }

    // 解码，返回码点和消耗的字节数
    struct DecodeResult {
        char32_t codepoint;
        size_t bytes_consumed;
    };

    static std::optional<DecodeResult> decode(const char* data, size_t len) {
        if (len == 0 || data == nullptr) return std::nullopt;

        unsigned char first = static_cast<unsigned char>(data[0]);
        char32_t cp;
        size_t expected_len;

        if ((first & 0x80) == 0) {
            // 1字节
            return DecodeResult{first, 1};
        } else if ((first & 0xE0) == 0xC0) {
            // 2字节
            if (len < 2) return std::nullopt;
            cp = (first & 0x1F) << 6;
            expected_len = 2;
        } else if ((first & 0xF0) == 0xE0) {
            // 3字节
            if (len < 3) return std::nullopt;
            cp = (first & 0x0F) << 12;
            expected_len = 3;
        } else if ((first & 0xF8) == 0xF0) {
            // 4字节
            if (len < 4) return std::nullopt;
            cp = (first & 0x07) << 18;
            expected_len = 4;
        } else {
            // 无效的首字节
            return std::nullopt;
        }

        // 验证并读取后续字节
        for (size_t i = 1; i < expected_len; ++i) {
            unsigned char byte = static_cast<unsigned char>(data[i]);
            if ((byte & 0xC0) != 0x80) {
                return std::nullopt;  // 无效的后续字节
            }
            cp |= (byte & 0x3F) << (6 * (expected_len - 1 - i));
        }

        // 验证码点的有效性
        if (cp >= 0xD800 && cp <= 0xDFFF) return std::nullopt;  // 代理对
        if (cp > 0x10FFFF) return std::nullopt;  // 超出范围

        // 验证最小编码（防止overlong encoding）
        if (cp < 0x80 && expected_len != 1) return std::nullopt;
        if (cp < 0x800 && expected_len != 2 && cp >= 0x80) return std::nullopt;
        if (cp < 0x10000 && expected_len != 3 && cp >= 0x800) return std::nullopt;

        return DecodeResult{cp, expected_len};
    }

    // 验证UTF-8字符串
    static bool validate(const std::string& str) {
        const char* p = str.data();
        const char* end = p + str.size();

        while (p < end) {
            auto result = decode(p, end - p);
            if (!result) return false;
            p += result->bytes_consumed;
        }
        return true;
    }

    // 计算码点数量
    static size_t count_codepoints(const std::string& str) {
        size_t count = 0;
        const char* p = str.data();
        const char* end = p + str.size();

        while (p < end) {
            auto result = decode(p, end - p);
            if (!result) break;
            p += result->bytes_consumed;
            ++count;
        }
        return count;
    }
};

// UTF-8迭代器
class UTF8Iterator {
    const char* ptr_;
    const char* end_;

public:
    UTF8Iterator(const std::string& str)
        : ptr_(str.data()), end_(str.data() + str.size()) {}

    UTF8Iterator(const char* begin, const char* end)
        : ptr_(begin), end_(end) {}

    bool has_next() const { return ptr_ < end_; }

    char32_t next() {
        if (!has_next()) return 0;
        auto result = UTF8Codec::decode(ptr_, end_ - ptr_);
        if (!result) {
            ++ptr_;  // 跳过无效字节
            return 0xFFFD;  // 替换字符
        }
        ptr_ += result->bytes_consumed;
        return result->codepoint;
    }

    // 支持range-based for
    class Iterator {
        const char* ptr_;
        const char* end_;
        char32_t current_;

        void advance() {
            if (ptr_ >= end_) {
                current_ = 0;
                return;
            }
            auto result = UTF8Codec::decode(ptr_, end_ - ptr_);
            if (result) {
                current_ = result->codepoint;
                ptr_ += result->bytes_consumed;
            } else {
                current_ = 0xFFFD;
                ++ptr_;
            }
        }

    public:
        Iterator(const char* ptr, const char* end) : ptr_(ptr), end_(end) {
            if (ptr_ < end_) advance();
        }

        char32_t operator*() const { return current_; }
        Iterator& operator++() { advance(); return *this; }
        bool operator!=(const Iterator& other) const {
            return ptr_ != other.ptr_ || current_ != other.current_;
        }
    };

    Iterator begin() const { return Iterator(ptr_, end_); }
    Iterator end() const { return Iterator(end_, end_); }
};
```

#### 深度扩展：BOM检测与多编码处理

```cpp
#include <string>
#include <string_view>
#include <fstream>
#include <vector>

enum class Encoding {
    ASCII,
    UTF8,
    UTF8_BOM,
    UTF16_LE,
    UTF16_BE,
    UTF32_LE,
    UTF32_BE,
    UNKNOWN
};

class EncodingDetector {
public:
    // 检测BOM
    static Encoding detect_bom(const std::string_view data) {
        if (data.size() >= 4) {
            // UTF-32 BOM
            if (data[0] == '\x00' && data[1] == '\x00' &&
                data[2] == '\xFE' && data[3] == '\xFF') {
                return Encoding::UTF32_BE;
            }
            if (data[0] == '\xFF' && data[1] == '\xFE' &&
                data[2] == '\x00' && data[3] == '\x00') {
                return Encoding::UTF32_LE;
            }
        }

        if (data.size() >= 3) {
            // UTF-8 BOM
            if (data[0] == '\xEF' && data[1] == '\xBB' && data[2] == '\xBF') {
                return Encoding::UTF8_BOM;
            }
        }

        if (data.size() >= 2) {
            // UTF-16 BOM
            if (data[0] == '\xFE' && data[1] == '\xFF') {
                return Encoding::UTF16_BE;
            }
            if (data[0] == '\xFF' && data[1] == '\xFE') {
                return Encoding::UTF16_LE;
            }
        }

        return Encoding::UNKNOWN;
    }

    // 启发式检测（无BOM时）
    static Encoding detect_heuristic(const std::string_view data) {
        // 检查是否是有效的UTF-8
        if (is_valid_utf8(data)) {
            // 检查是否只有ASCII
            bool has_high_bit = false;
            for (unsigned char c : data) {
                if (c >= 0x80) {
                    has_high_bit = true;
                    break;
                }
            }
            return has_high_bit ? Encoding::UTF8 : Encoding::ASCII;
        }

        // 检查是否可能是UTF-16
        if (data.size() >= 2 && data.size() % 2 == 0) {
            size_t null_count = 0;
            for (size_t i = 0; i < data.size(); i += 2) {
                if (data[i] == '\0' || data[i + 1] == '\0') {
                    ++null_count;
                }
            }
            // 如果有很多空字节，可能是UTF-16
            if (null_count > data.size() / 4) {
                // 猜测字节序
                size_t le_nulls = 0, be_nulls = 0;
                for (size_t i = 0; i < data.size(); i += 2) {
                    if (data[i + 1] == '\0') ++le_nulls;
                    if (data[i] == '\0') ++be_nulls;
                }
                return le_nulls > be_nulls ? Encoding::UTF16_LE : Encoding::UTF16_BE;
            }
        }

        return Encoding::UNKNOWN;
    }

    // 完整检测
    static Encoding detect(const std::string_view data) {
        auto bom_result = detect_bom(data);
        if (bom_result != Encoding::UNKNOWN) {
            return bom_result;
        }
        return detect_heuristic(data);
    }

private:
    static bool is_valid_utf8(const std::string_view data) {
        const unsigned char* p = reinterpret_cast<const unsigned char*>(data.data());
        const unsigned char* end = p + data.size();

        while (p < end) {
            if (*p < 0x80) {
                ++p;
            } else if ((*p & 0xE0) == 0xC0) {
                if (p + 1 >= end || (p[1] & 0xC0) != 0x80) return false;
                p += 2;
            } else if ((*p & 0xF0) == 0xE0) {
                if (p + 2 >= end || (p[1] & 0xC0) != 0x80 || (p[2] & 0xC0) != 0x80) return false;
                p += 3;
            } else if ((*p & 0xF8) == 0xF0) {
                if (p + 3 >= end || (p[1] & 0xC0) != 0x80 ||
                    (p[2] & 0xC0) != 0x80 || (p[3] & 0xC0) != 0x80) return false;
                p += 4;
            } else {
                return false;
            }
        }
        return true;
    }
};

// 编码转换
class EncodingConverter {
public:
    // UTF-16LE 转 UTF-8
    static std::string utf16le_to_utf8(const std::string_view data) {
        std::string result;
        const uint16_t* p = reinterpret_cast<const uint16_t*>(data.data());
        const uint16_t* end = p + data.size() / 2;

        while (p < end) {
            char32_t cp;

            // 处理代理对
            if (*p >= 0xD800 && *p <= 0xDBFF) {
                // 高代理
                if (p + 1 >= end) break;
                uint16_t high = *p++;
                uint16_t low = *p++;
                if (low >= 0xDC00 && low <= 0xDFFF) {
                    cp = 0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00);
                } else {
                    cp = 0xFFFD;  // 无效
                }
            } else if (*p >= 0xDC00 && *p <= 0xDFFF) {
                // 孤立的低代理
                cp = 0xFFFD;
                ++p;
            } else {
                cp = *p++;
            }

            result += UTF8Codec::encode(cp);
        }
        return result;
    }

    // UTF-8 转 UTF-16LE
    static std::string utf8_to_utf16le(const std::string& utf8) {
        std::string result;
        UTF8Iterator iter(utf8);

        while (iter.has_next()) {
            char32_t cp = iter.next();

            if (cp < 0x10000) {
                result += static_cast<char>(cp & 0xFF);
                result += static_cast<char>((cp >> 8) & 0xFF);
            } else {
                // 代理对
                cp -= 0x10000;
                uint16_t high = 0xD800 + (cp >> 10);
                uint16_t low = 0xDC00 + (cp & 0x3FF);
                result += static_cast<char>(high & 0xFF);
                result += static_cast<char>((high >> 8) & 0xFF);
                result += static_cast<char>(low & 0xFF);
                result += static_cast<char>((low >> 8) & 0xFF);
            }
        }
        return result;
    }
};

// 使用示例
void encoding_demo() {
    // 检测文件编码
    std::ifstream file("test.txt", std::ios::binary);
    std::string content((std::istreambuf_iterator<char>(file)),
                         std::istreambuf_iterator<char>());

    auto encoding = EncodingDetector::detect(content);

    switch (encoding) {
        case Encoding::UTF8:
            std::cout << "Detected: UTF-8 (no BOM)\n";
            break;
        case Encoding::UTF8_BOM:
            std::cout << "Detected: UTF-8 with BOM\n";
            // 跳过BOM
            content = content.substr(3);
            break;
        case Encoding::UTF16_LE:
            std::cout << "Detected: UTF-16 LE\n";
            content = EncodingConverter::utf16le_to_utf8(content.substr(2));
            break;
        default:
            std::cout << "Unknown encoding\n";
    }
}
```

#### 深度扩展：ICU库简介

```cpp
/*
ICU (International Components for Unicode) 是处理Unicode的工业标准库

功能：
1. 完整的Unicode支持
2. 字符串排序（collation）
3. 日期/时间格式化
4. 数字格式化
5. 消息格式化
6. 文本边界分析（字形簇、单词、句子）
7. 字符属性查询
8. 规范化
9. 双向文本处理

安装：
- macOS: brew install icu4c
- Ubuntu: apt-get install libicu-dev
- Windows: 从 https://icu.unicode.org/ 下载
*/

// 示例：使用ICU进行文本边界分析
#ifdef USE_ICU
#include <unicode/unistr.h>
#include <unicode/brkiter.h>
#include <unicode/ucnv.h>

void icu_grapheme_demo() {
    UErrorCode status = U_ZERO_ERROR;

    // 创建字形簇边界迭代器
    icu::UnicodeString str = icu::UnicodeString::fromUTF8("👨‍👩‍👧 Hello 世界");

    std::unique_ptr<icu::BreakIterator> iter(
        icu::BreakIterator::createCharacterInstance(icu::Locale::getDefault(), status)
    );

    if (U_FAILURE(status)) {
        std::cerr << "Failed to create BreakIterator\n";
        return;
    }

    iter->setText(str);

    int32_t start = iter->first();
    int32_t end = iter->next();
    int count = 0;

    while (end != icu::BreakIterator::DONE) {
        ++count;
        start = end;
        end = iter->next();
    }

    std::cout << "Grapheme clusters: " << count << "\n";
    // 输出: 3 (family emoji作为1个, "Hello "作为6个空格和字母, "世界"作为2个)
    // 实际输出取决于ICU版本和Unicode版本
}
#endif

// 不使用ICU的简化字形簇检测（仅处理常见情况）
bool is_continuation_codepoint(char32_t cp) {
    // 组合字符范围（简化版，实际Unicode更复杂）
    // Combining Diacritical Marks: U+0300 - U+036F
    if (cp >= 0x0300 && cp <= 0x036F) return true;
    // Zero Width Joiner: U+200D
    if (cp == 0x200D) return true;
    // Variation Selectors: U+FE00 - U+FE0F
    if (cp >= 0xFE00 && cp <= 0xFE0F) return true;
    // Regional Indicator Symbols (flags): U+1F1E6 - U+1F1FF
    // 这些成对出现形成国旗emoji
    return false;
}

size_t count_grapheme_clusters_simple(const std::string& utf8) {
    size_t count = 0;
    char32_t prev = 0;

    UTF8Iterator iter(utf8);
    while (iter.has_next()) {
        char32_t cp = iter.next();
        if (!is_continuation_codepoint(cp)) {
            ++count;
        }
        prev = cp;
    }
    return count;
}
```

#### 本周练习

1. **UTF-8编解码器**：实现完整的UTF-8编解码器，包含错误处理
2. **编码检测器**：实现能检测多种编码的检测器
3. **码点计数器**：编写函数正确计算字符串中的码点数
4. **字形簇计数器**：尝试实现简化版的字形簇计数

#### 延伸阅读

- Unicode官方网站: https://unicode.org/
- UTF-8 Everywhere: https://utf8everywhere.org/
- Joel on Software: "The Absolute Minimum Every Software Developer Absolutely, Positively Must Know About Unicode and Character Sets"
- ICU文档: https://unicode-org.github.io/icu/
- RFC 3629: UTF-8, a transformation format of ISO 10646

#### 周末自测

**理论题**：
1. 解释码点、码元、字形簇的区别
2. UTF-8如何实现自同步？为什么这很重要？
3. 什么是代理对？为什么UTF-16需要它？
4. 为什么现代C++推荐使用UTF-8而不是wchar_t？
5. BOM的作用是什么？UTF-8是否需要BOM？

**代码题**：
1. 实现一个函数，将UTF-32码点编码为UTF-8
2. 实现一个函数，验证字符串是否是有效的UTF-8
3. 编写程序检测文件的编码类型

---

### 第四周：正则表达式

**学习目标**：掌握std::regex的使用

**基本使用**：
```cpp
#include <regex>
#include <string>
#include <iostream>

// 匹配
std::string text = "Hello, World!";
std::regex pattern(R"(\w+)");

if (std::regex_search(text, pattern)) {
    std::cout << "Found match\n";
}

// 提取匹配
std::smatch matches;
if (std::regex_search(text, matches, pattern)) {
    std::cout << "Match: " << matches[0] << "\n";
}

// 遍历所有匹配
std::sregex_iterator begin(text.begin(), text.end(), pattern);
std::sregex_iterator end;
for (auto it = begin; it != end; ++it) {
    std::cout << "Found: " << (*it)[0] << "\n";
}

// 替换
std::string result = std::regex_replace(text, pattern, "[$&]");
// result = "[Hello], [World]!"

// 验证
std::regex email_pattern(R"([\w.]+@[\w.]+\.\w+)");
bool valid = std::regex_match("user@example.com", email_pattern);
```

**性能注意**：
```cpp
// std::regex编译开销大，应该重用
// 错误做法
for (const auto& line : lines) {
    std::regex pat(R"(\d+)");  // 每次循环都编译正则
    std::regex_search(line, pat);
}

// 正确做法
std::regex pat(R"(\d+)");  // 编译一次
for (const auto& line : lines) {
    std::regex_search(line, pat);
}

// std::regex性能较差，考虑替代方案
// - RE2（Google，线性时间保证）
// - PCRE2
// - Boost.Regex
// - 手写状态机（性能关键时）
```

#### 每日学习计划

| 天数 | 主题 | 学习内容 | 实践任务 | 预计时间 |
|------|------|----------|----------|----------|
| Day 1 | 正则理论基础 | 有限自动机、NFA、DFA概念 | 画出简单正则的NFA/DFA | 5h |
| Day 2 | std::regex基础 | 基本语法、匹配、搜索、替换 | 编写基本的正则匹配程序 | 5h |
| Day 3 | 高级用法 | 捕获组、回溯引用、迭代器 | 实现日志解析器 | 5h |
| Day 4 | 性能问题 | 灾难性回溯、编译开销 | 测试不同正则的性能 | 5h |
| Day 5 | 替代方案 | RE2、手写解析器 | 对比std::regex和手写的性能 | 5h |
| Day 6 | 实践项目 | 实现日志分析器 | 完成日志分析器 | 5h |
| Day 7 | 综合复习 | 复习本周内容、总结最佳实践 | 编写正则使用指南 | 5h |

#### 深度扩展：有限自动机理论

```cpp
/*
正则表达式的理论基础是有限自动机（Finite Automata）

1. DFA (Deterministic Finite Automaton) - 确定性有限自动机
   - 每个状态对每个输入字符只有一个转移
   - 匹配时间与输入长度成线性关系 O(n)
   - 但构建DFA可能产生指数级状态数

2. NFA (Nondeterministic Finite Automaton) - 非确定性有限自动机
   - 每个状态可以有多个转移（包括ε转移）
   - 匹配可能需要回溯
   - 最坏情况下时间复杂度可达 O(2^n)

3. Thompson构造法
   - Ken Thompson发明的从正则表达式构造NFA的方法
   - 每个正则操作对应一个NFA片段
   - 片段通过ε转移连接

4. std::regex的实现
   - 大多数实现使用回溯算法（基于NFA）
   - 存在灾难性回溯问题
   - RE2使用DFA模拟，保证线性时间
*/

// 简单的NFA实现（教学用）
#include <vector>
#include <set>
#include <map>
#include <string>
#include <queue>
#include <optional>

class SimpleNFA {
public:
    struct State {
        int id;
        bool is_accept = false;
        std::map<char, std::set<int>> transitions;  // 字符 -> 目标状态集
        std::set<int> epsilon_transitions;          // ε转移
    };

private:
    std::vector<State> states_;
    int start_state_ = 0;

    // 获取ε闭包（从给定状态集出发，通过ε转移能到达的所有状态）
    std::set<int> epsilon_closure(const std::set<int>& states) const {
        std::set<int> closure = states;
        std::queue<int> to_process;

        for (int s : states) {
            to_process.push(s);
        }

        while (!to_process.empty()) {
            int current = to_process.front();
            to_process.pop();

            for (int next : states_[current].epsilon_transitions) {
                if (closure.find(next) == closure.end()) {
                    closure.insert(next);
                    to_process.push(next);
                }
            }
        }
        return closure;
    }

    // 从状态集出发，经过字符c能到达的状态集
    std::set<int> move(const std::set<int>& states, char c) const {
        std::set<int> result;
        for (int s : states) {
            auto it = states_[s].transitions.find(c);
            if (it != states_[s].transitions.end()) {
                result.insert(it->second.begin(), it->second.end());
            }
        }
        return result;
    }

public:
    int add_state(bool is_accept = false) {
        int id = states_.size();
        states_.push_back({id, is_accept, {}, {}});
        return id;
    }

    void add_transition(int from, int to, char c) {
        states_[from].transitions[c].insert(to);
    }

    void add_epsilon(int from, int to) {
        states_[from].epsilon_transitions.insert(to);
    }

    void set_start(int state) { start_state_ = state; }

    bool match(const std::string& input) const {
        std::set<int> current = epsilon_closure({start_state_});

        for (char c : input) {
            current = epsilon_closure(move(current, c));
            if (current.empty()) return false;
        }

        // 检查是否有接受状态
        for (int s : current) {
            if (states_[s].is_accept) return true;
        }
        return false;
    }
};

// 从简单正则表达式构造NFA（只支持连接、| 和 *）
class RegexToNFA {
    struct NFAFragment {
        int start;
        int end;
    };

    SimpleNFA& nfa_;
    const std::string& pattern_;
    size_t pos_ = 0;

    char peek() const { return pos_ < pattern_.size() ? pattern_[pos_] : '\0'; }
    char get() { return pos_ < pattern_.size() ? pattern_[pos_++] : '\0'; }

    NFAFragment parse_atom() {
        if (peek() == '(') {
            get(); // consume '('
            auto result = parse_alternation();
            get(); // consume ')'
            return result;
        }

        // 普通字符
        char c = get();
        int start = nfa_.add_state();
        int end = nfa_.add_state();
        nfa_.add_transition(start, end, c);
        return {start, end};
    }

    NFAFragment parse_factor() {
        auto base = parse_atom();

        while (peek() == '*') {
            get(); // consume '*'
            int start = nfa_.add_state();
            int end = nfa_.add_state();

            nfa_.add_epsilon(start, base.start);
            nfa_.add_epsilon(start, end);
            nfa_.add_epsilon(base.end, base.start);
            nfa_.add_epsilon(base.end, end);

            base = {start, end};
        }
        return base;
    }

    NFAFragment parse_term() {
        auto result = parse_factor();

        while (peek() != '\0' && peek() != '|' && peek() != ')') {
            auto next = parse_factor();
            nfa_.add_epsilon(result.end, next.start);
            result.end = next.end;
        }
        return result;
    }

    NFAFragment parse_alternation() {
        auto result = parse_term();

        while (peek() == '|') {
            get(); // consume '|'
            auto alt = parse_term();

            int start = nfa_.add_state();
            int end = nfa_.add_state();

            nfa_.add_epsilon(start, result.start);
            nfa_.add_epsilon(start, alt.start);
            nfa_.add_epsilon(result.end, end);
            nfa_.add_epsilon(alt.end, end);

            result = {start, end};
        }
        return result;
    }

public:
    RegexToNFA(SimpleNFA& nfa, const std::string& pattern)
        : nfa_(nfa), pattern_(pattern) {}

    void build() {
        auto fragment = parse_alternation();
        nfa_.set_start(fragment.start);
        // 将结束状态设为接受状态
        // 注意：这里需要修改SimpleNFA来支持
    }
};
```

#### 深度扩展：灾难性回溯与防御

```cpp
#include <regex>
#include <chrono>
#include <iostream>

/*
灾难性回溯（Catastrophic Backtracking）

当正则表达式中有多个量词可以匹配同一段文本时，
引擎可能尝试大量的组合，导致指数级时间复杂度。

典型的灾难性模式：
1. (a+)+ 匹配 "aaaaaaaaaaaaaaaaX"
2. (a|aa)+ 匹配 "aaaaaaaaaaaaaaaaX"
3. (\w+)* 匹配很长的字符串
4. (.*a){x} 嵌套量词
*/

void demonstrate_catastrophic_backtracking() {
    // 危险模式：嵌套量词
    std::regex dangerous_pattern(R"((a+)+b)");

    // 测试不同长度的不匹配字符串
    for (int len = 10; len <= 30; len += 5) {
        std::string input(len, 'a');  // 全是'a'，没有'b'

        auto start = std::chrono::high_resolution_clock::now();
        bool matched = std::regex_match(input, dangerous_pattern);
        auto end = std::chrono::high_resolution_clock::now();

        auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
        std::cout << "Length " << len << ": " << duration.count() << "ms"
                  << (matched ? " (matched)" : " (not matched)") << "\n";
    }
    // 输出会显示时间指数增长！
}

// 如何避免灾难性回溯

// 1. 使用原子组（std::regex不支持，但概念重要）
// (?>a+) 匹配后不回溯

// 2. 使用占有量词（std::regex不支持）
// a++ 占有量词，不回溯

// 3. 重写模式避免嵌套量词
void safe_patterns() {
    // 危险: (a+)+b
    // 安全: a+b

    // 危险: (a|aa)+
    // 安全: a+

    // 危险: (\w+)*
    // 安全: \w*

    // 危险: (.*?)(.*)
    // 安全: 具体化第一部分
}

// 4. 限制输入长度
bool safe_regex_match(const std::string& input,
                      const std::regex& pattern,
                      size_t max_length = 10000) {
    if (input.length() > max_length) {
        throw std::length_error("Input too long for regex matching");
    }
    return std::regex_match(input, pattern);
}

// 5. 使用超时（需要额外机制实现）
// std::regex本身不支持超时，需要在线程中运行并计时

// 6. 使用更安全的库
// RE2保证线性时间复杂度
```

#### 深度扩展：std::regex语法完整参考

```cpp
#include <regex>
#include <iostream>
#include <string>

void regex_syntax_reference() {
    /*
    === 字符类 ===
    .       任意字符（除换行符）
    \d      数字 [0-9]
    \D      非数字 [^0-9]
    \w      单词字符 [a-zA-Z0-9_]
    \W      非单词字符
    \s      空白字符 [ \t\n\r\f\v]
    \S      非空白字符

    === 量词 ===
    *       0次或多次
    +       1次或多次
    ?       0次或1次
    {n}     恰好n次
    {n,}    至少n次
    {n,m}   n到m次

    === 量词修饰符 ===
    *?      非贪婪版本
    +?      非贪婪版本
    ??      非贪婪版本

    === 锚点 ===
    ^       行首
    $       行尾
    \b      单词边界
    \B      非单词边界

    === 分组 ===
    (...)       捕获组
    (?:...)     非捕获组
    \1, \2      回溯引用

    === 字符集 ===
    [abc]       a、b或c
    [^abc]      非a、b、c
    [a-z]       a到z
    [a-zA-Z]    所有字母

    === 选择 ===
    a|b         a或b
    */

    // 示例演示
    std::string text = "Hello World 123 test@email.com 2024-01-15";

    // 匹配数字
    std::regex digits(R"(\d+)");

    // 匹配email
    std::regex email(R"(\w+@\w+\.\w+)");

    // 匹配日期
    std::regex date(R"((\d{4})-(\d{2})-(\d{2}))");

    // 遍历所有数字
    std::cout << "Numbers found:\n";
    std::sregex_iterator it(text.begin(), text.end(), digits);
    std::sregex_iterator end;
    for (; it != end; ++it) {
        std::cout << "  " << it->str() << "\n";
    }

    // 提取日期各部分
    std::smatch date_match;
    if (std::regex_search(text, date_match, date)) {
        std::cout << "Date: " << date_match[0] << "\n";
        std::cout << "Year: " << date_match[1] << "\n";
        std::cout << "Month: " << date_match[2] << "\n";
        std::cout << "Day: " << date_match[3] << "\n";
    }
}

// regex_constants选项
void regex_flags_demo() {
    std::string text = "HELLO hello HeLLo";

    // 默认：区分大小写
    std::regex pattern1("hello");

    // 不区分大小写
    std::regex pattern2("hello", std::regex_constants::icase);

    std::cout << "Case sensitive matches:\n";
    std::sregex_iterator it1(text.begin(), text.end(), pattern1);
    for (; it1 != std::sregex_iterator(); ++it1) {
        std::cout << "  " << it1->str() << "\n";
    }

    std::cout << "Case insensitive matches:\n";
    std::sregex_iterator it2(text.begin(), text.end(), pattern2);
    for (; it2 != std::sregex_iterator(); ++it2) {
        std::cout << "  " << it2->str() << "\n";
    }
}

// 不同语法类型
void regex_grammar_types() {
    /*
    std::regex支持多种语法：
    - ECMAScript (默认): JavaScript风格
    - basic: 基本POSIX
    - extended: 扩展POSIX
    - awk: AWK风格
    - grep: grep风格
    - egrep: egrep风格
    */

    // ECMAScript (默认)
    std::regex ecma(R"(\d+)");

    // POSIX extended
    std::regex posix(R"([0-9]+)", std::regex_constants::extended);

    // 注意：不同语法的元字符含义可能不同
}
```

#### 深度扩展：性能对比与最佳实践

```cpp
#include <regex>
#include <chrono>
#include <iostream>
#include <string>
#include <functional>

// 性能测试框架
template<typename Func>
double measure_time(Func&& f, int iterations = 1000) {
    auto start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < iterations; ++i) {
        f();
    }
    auto end = std::chrono::high_resolution_clock::now();
    return std::chrono::duration<double, std::milli>(end - start).count() / iterations;
}

void compare_regex_vs_manual() {
    std::string log_line = "[2024-01-15 10:30:45] INFO: User login successful - user_id=12345";

    // 方法1：使用std::regex
    // 注意：正则应该预编译
    static std::regex log_pattern(R"(\[(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2})\] (\w+): (.+))");

    auto regex_parse = [&]() {
        std::smatch match;
        if (std::regex_match(log_line, match, log_pattern)) {
            volatile auto date = match[1].str();
            volatile auto time = match[2].str();
            volatile auto level = match[3].str();
            volatile auto message = match[4].str();
        }
    };

    // 方法2：手写解析器
    auto manual_parse = [&]() {
        if (log_line.empty() || log_line[0] != '[') return;

        size_t date_start = 1;
        size_t date_end = log_line.find(' ', date_start);
        size_t time_end = log_line.find(']', date_end);
        size_t level_start = time_end + 2;
        size_t level_end = log_line.find(':', level_start);
        size_t message_start = level_end + 2;

        volatile auto date = log_line.substr(date_start, date_end - date_start);
        volatile auto time = log_line.substr(date_end + 1, time_end - date_end - 1);
        volatile auto level = log_line.substr(level_start, level_end - level_start);
        volatile auto message = log_line.substr(message_start);
    };

    // 方法3：使用string_view（零拷贝）
    auto sv_parse = [&]() {
        std::string_view sv(log_line);
        if (sv.empty() || sv[0] != '[') return;

        size_t date_start = 1;
        size_t date_end = sv.find(' ', date_start);
        size_t time_end = sv.find(']', date_end);
        size_t level_start = time_end + 2;
        size_t level_end = sv.find(':', level_start);
        size_t message_start = level_end + 2;

        volatile auto date = sv.substr(date_start, date_end - date_start);
        volatile auto time = sv.substr(date_end + 1, time_end - date_end - 1);
        volatile auto level = sv.substr(level_start, level_end - level_start);
        volatile auto message = sv.substr(message_start);
    };

    std::cout << "Performance comparison (avg ms per call):\n";
    std::cout << "  std::regex:    " << measure_time(regex_parse, 10000) << "\n";
    std::cout << "  Manual string: " << measure_time(manual_parse, 10000) << "\n";
    std::cout << "  string_view:   " << measure_time(sv_parse, 10000) << "\n";
}

// 最佳实践
void regex_best_practices() {
    /*
    1. 预编译正则表达式
       - 正则编译开销很大
       - 使用static或成员变量存储编译后的regex
    */
    // 错误
    // for (const auto& line : lines) {
    //     std::regex pat(R"(\d+)");  // 每次都编译！
    //     std::regex_search(line, pat);
    // }

    // 正确
    static std::regex pat(R"(\d+)");
    // for (const auto& line : lines) {
    //     std::regex_search(line, pat);
    // }

    /*
    2. 选择合适的函数
       - regex_match: 完全匹配
       - regex_search: 搜索子串
       - regex_replace: 替换
       - sregex_iterator: 遍历所有匹配
    */

    /*
    3. 避免灾难性回溯
       - 不使用嵌套量词 (a+)+
       - 使用具体的字符集而非 .*
       - 限制输入长度
    */

    /*
    4. 考虑替代方案
       - 简单模式：手写解析器
       - 性能关键：RE2库
       - 复杂文本处理：专门的解析库
    */

    /*
    5. 使用原始字符串
       - 使用 R"(...)" 避免双重转义
    */
    std::regex good(R"(\d+\.\d+)");  // 原始字符串
    std::regex bad("\\d+\\.\\d+");   // 需要双重转义
}
```

#### 项目：日志分析器

```cpp
// log_analyzer.hpp
#pragma once
#include <string>
#include <string_view>
#include <vector>
#include <map>
#include <regex>
#include <fstream>
#include <iostream>
#include <chrono>
#include <optional>

struct LogEntry {
    std::string timestamp;
    std::string level;
    std::string source;
    std::string message;
    std::map<std::string, std::string> fields;

    static std::optional<LogEntry> parse(std::string_view line);
};

class LogAnalyzer {
public:
    struct Statistics {
        size_t total_lines = 0;
        std::map<std::string, size_t> level_counts;
        std::map<std::string, size_t> source_counts;
        std::map<std::string, size_t> error_types;
        double parse_time_ms = 0;
    };

private:
    std::vector<LogEntry> entries_;
    Statistics stats_;

    // 预编译的正则表达式
    static const std::regex& get_log_pattern() {
        // 匹配格式: [YYYY-MM-DD HH:MM:SS] LEVEL [SOURCE] Message key=value ...
        static std::regex pattern(
            R"(\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\] )"
            R"((\w+) )"
            R"(\[([^\]]+)\] )"
            R"((.+))"
        );
        return pattern;
    }

    static const std::regex& get_field_pattern() {
        // 匹配 key=value 或 key="value with spaces"
        static std::regex pattern(R"((\w+)=(?:"([^"]*)"|(\S+)))");
        return pattern;
    }

public:
    void load_file(const std::string& filename) {
        auto start = std::chrono::high_resolution_clock::now();

        std::ifstream file(filename);
        std::string line;

        while (std::getline(file, line)) {
            ++stats_.total_lines;
            if (auto entry = LogEntry::parse(line)) {
                // 更新统计
                stats_.level_counts[entry->level]++;
                stats_.source_counts[entry->source]++;

                if (entry->level == "ERROR") {
                    // 提取错误类型
                    auto it = entry->fields.find("error_type");
                    if (it != entry->fields.end()) {
                        stats_.error_types[it->second]++;
                    }
                }

                entries_.push_back(std::move(*entry));
            }
        }

        auto end = std::chrono::high_resolution_clock::now();
        stats_.parse_time_ms =
            std::chrono::duration<double, std::milli>(end - start).count();
    }

    // 按条件搜索
    std::vector<const LogEntry*> search(
        const std::string& level_filter = "",
        const std::string& source_filter = "",
        const std::string& message_pattern = ""
    ) const {
        std::vector<const LogEntry*> results;
        std::optional<std::regex> msg_regex;

        if (!message_pattern.empty()) {
            msg_regex = std::regex(message_pattern);
        }

        for (const auto& entry : entries_) {
            if (!level_filter.empty() && entry.level != level_filter) continue;
            if (!source_filter.empty() && entry.source != source_filter) continue;
            if (msg_regex && !std::regex_search(entry.message, *msg_regex)) continue;

            results.push_back(&entry);
        }
        return results;
    }

    // 聚合分析
    std::map<std::string, size_t> aggregate_by_field(const std::string& field_name) const {
        std::map<std::string, size_t> result;
        for (const auto& entry : entries_) {
            auto it = entry.fields.find(field_name);
            if (it != entry.fields.end()) {
                result[it->second]++;
            }
        }
        return result;
    }

    const Statistics& statistics() const { return stats_; }
    const std::vector<LogEntry>& entries() const { return entries_; }

    void print_summary() const {
        std::cout << "=== Log Analysis Summary ===\n";
        std::cout << "Total lines: " << stats_.total_lines << "\n";
        std::cout << "Parse time: " << stats_.parse_time_ms << " ms\n";
        std::cout << "\nBy Level:\n";
        for (const auto& [level, count] : stats_.level_counts) {
            std::cout << "  " << level << ": " << count << "\n";
        }
        std::cout << "\nBy Source:\n";
        for (const auto& [source, count] : stats_.source_counts) {
            std::cout << "  " << source << ": " << count << "\n";
        }
        if (!stats_.error_types.empty()) {
            std::cout << "\nError Types:\n";
            for (const auto& [type, count] : stats_.error_types) {
                std::cout << "  " << type << ": " << count << "\n";
            }
        }
    }
};

// 实现LogEntry::parse
std::optional<LogEntry> LogEntry::parse(std::string_view line) {
    // 使用高性能的手写解析器替代regex
    // 格式: [YYYY-MM-DD HH:MM:SS] LEVEL [SOURCE] Message

    if (line.size() < 25 || line[0] != '[') return std::nullopt;

    LogEntry entry;

    // 解析时间戳 [YYYY-MM-DD HH:MM:SS]
    size_t ts_end = line.find(']');
    if (ts_end == std::string_view::npos) return std::nullopt;
    entry.timestamp = std::string(line.substr(1, ts_end - 1));

    // 跳过 "] "
    size_t pos = ts_end + 2;
    if (pos >= line.size()) return std::nullopt;

    // 解析级别
    size_t level_end = line.find(' ', pos);
    if (level_end == std::string_view::npos) return std::nullopt;
    entry.level = std::string(line.substr(pos, level_end - pos));
    pos = level_end + 1;

    // 解析源 [SOURCE]
    if (pos >= line.size() || line[pos] != '[') return std::nullopt;
    size_t source_end = line.find(']', pos);
    if (source_end == std::string_view::npos) return std::nullopt;
    entry.source = std::string(line.substr(pos + 1, source_end - pos - 1));
    pos = source_end + 2;

    // 剩余为消息
    if (pos < line.size()) {
        entry.message = std::string(line.substr(pos));

        // 提取key=value字段
        static std::regex field_pattern(R"((\w+)=(?:"([^"]*)"|(\S+)))");
        std::string msg = entry.message;
        std::sregex_iterator it(msg.begin(), msg.end(), field_pattern);
        std::sregex_iterator end;

        for (; it != end; ++it) {
            std::string key = (*it)[1].str();
            std::string value = (*it)[2].matched ? (*it)[2].str() : (*it)[3].str();
            entry.fields[key] = value;
        }
    }

    return entry;
}

// 使用示例
void log_analyzer_example() {
    // 创建测试日志文件
    std::ofstream log_file("test.log");
    log_file << "[2024-01-15 10:30:45] INFO [AuthService] User login successful user_id=12345\n";
    log_file << "[2024-01-15 10:30:46] ERROR [Database] Connection failed error_type=timeout host=db.example.com\n";
    log_file << "[2024-01-15 10:30:47] WARN [Cache] Cache miss key=\"user:12345\"\n";
    log_file << "[2024-01-15 10:30:48] DEBUG [HttpServer] Request received path=\"/api/users\" method=GET\n";
    log_file.close();

    // 分析日志
    LogAnalyzer analyzer;
    analyzer.load_file("test.log");
    analyzer.print_summary();

    // 搜索错误
    std::cout << "\n=== Error Entries ===\n";
    for (const auto* entry : analyzer.search("ERROR")) {
        std::cout << entry->timestamp << " " << entry->source << ": " << entry->message << "\n";
    }

    // 按字段聚合
    std::cout << "\n=== By Host ===\n";
    for (const auto& [host, count] : analyzer.aggregate_by_field("host")) {
        std::cout << "  " << host << ": " << count << "\n";
    }
}
```

#### 本周练习

1. **NFA可视化**：为给定的正则表达式绘制NFA状态图
2. **灾难性回溯测试**：编写测试代码演示灾难性回溯
3. **性能对比**：对比std::regex和手写解析器的性能
4. **日志分析器扩展**：为日志分析器添加更多功能（时间范围过滤、导出等）

#### 延伸阅读

- 《精通正则表达式》(Mastering Regular Expressions) by Jeffrey Friedl
- RE2 Wiki: https://github.com/google/re2/wiki
- CppCon 2018: "Regular Expressions in C++" by Tim Shen
- Russ Cox's regex articles: https://swtch.com/~rsc/regexp/
- C++ Reference: std::regex

#### 周末自测

**理论题**：
1. 解释NFA和DFA的区别
2. 什么是灾难性回溯？如何避免？
3. std::regex_match和std::regex_search的区别是什么？
4. 为什么正则表达式应该预编译？
5. RE2相比std::regex有什么优势？

**代码题**：
1. 编写正则表达式匹配有效的IPv4地址
2. 实现一个函数，使用正则提取URL中的各部分（协议、域名、路径等）
3. 比较正则和手写解析器解析CSV的性能

---

## 源码阅读任务

### 深度阅读清单

- [ ] `std::string`的SSO实现（libstdc++或libc++）
- [ ] `std::string_view`实现
- [ ] `std::char_traits`特化
- [ ] `std::basic_regex`基本结构

---

## 实践项目

### 项目：实现字符串处理库

#### Part 1: mini_string（带SSO）
```cpp
// mini_string.hpp
#pragma once
#include <cstring>
#include <algorithm>
#include <stdexcept>

class MiniString {
    static constexpr size_t SSO_CAPACITY = 15;  // 不含null终止符

    union {
        struct {
            char* ptr;
            size_t size;
            size_t capacity;
        } heap_;

        struct {
            char data[SSO_CAPACITY + 1];
        } sso_;
    };

    // 使用最高字节的最高位作为标志
    // 短字符串：sso_.data[SSO_CAPACITY] 的最高位为0
    // 长字符串：设置标志

    bool is_short() const {
        return (sso_.data[SSO_CAPACITY] & 0x80) == 0;
    }

    void set_short_size(size_t n) {
        sso_.data[SSO_CAPACITY] = static_cast<char>(SSO_CAPACITY - n);
    }

    size_t short_size() const {
        return SSO_CAPACITY - static_cast<unsigned char>(sso_.data[SSO_CAPACITY]);
    }

    void set_long() {
        sso_.data[SSO_CAPACITY] |= 0x80;
    }

public:
    // 默认构造
    MiniString() noexcept {
        sso_.data[0] = '\0';
        set_short_size(0);
    }

    // C字符串构造
    MiniString(const char* s) : MiniString(s, std::strlen(s)) {}

    MiniString(const char* s, size_t len) {
        if (len <= SSO_CAPACITY) {
            std::memcpy(sso_.data, s, len);
            sso_.data[len] = '\0';
            set_short_size(len);
        } else {
            heap_.ptr = new char[len + 1];
            std::memcpy(heap_.ptr, s, len + 1);
            heap_.size = len;
            heap_.capacity = len;
            set_long();
        }
    }

    // 拷贝构造
    MiniString(const MiniString& other) {
        if (other.is_short()) {
            std::memcpy(&sso_, &other.sso_, sizeof(sso_));
        } else {
            heap_.ptr = new char[other.heap_.capacity + 1];
            std::memcpy(heap_.ptr, other.heap_.ptr, other.heap_.size + 1);
            heap_.size = other.heap_.size;
            heap_.capacity = other.heap_.capacity;
            set_long();
        }
    }

    // 移动构造
    MiniString(MiniString&& other) noexcept {
        if (other.is_short()) {
            std::memcpy(&sso_, &other.sso_, sizeof(sso_));
        } else {
            heap_ = other.heap_;
            set_long();
            // 将other置于有效的短字符串状态
            other.sso_.data[0] = '\0';
            other.set_short_size(0);
        }
    }

    // 析构
    ~MiniString() {
        if (!is_short()) {
            delete[] heap_.ptr;
        }
    }

    // 赋值
    MiniString& operator=(MiniString other) noexcept {
        swap(*this, other);
        return *this;
    }

    friend void swap(MiniString& a, MiniString& b) noexcept {
        char temp[sizeof(MiniString)];
        std::memcpy(temp, &a, sizeof(MiniString));
        std::memcpy(&a, &b, sizeof(MiniString));
        std::memcpy(&b, temp, sizeof(MiniString));
    }

    // 访问
    const char* c_str() const noexcept {
        return is_short() ? sso_.data : heap_.ptr;
    }

    const char* data() const noexcept { return c_str(); }

    size_t size() const noexcept {
        return is_short() ? short_size() : heap_.size;
    }

    size_t length() const noexcept { return size(); }

    size_t capacity() const noexcept {
        return is_short() ? SSO_CAPACITY : heap_.capacity;
    }

    bool empty() const noexcept { return size() == 0; }

    char& operator[](size_t pos) {
        return is_short() ? sso_.data[pos] : heap_.ptr[pos];
    }

    const char& operator[](size_t pos) const {
        return is_short() ? sso_.data[pos] : heap_.ptr[pos];
    }

    // 修改
    void reserve(size_t new_cap) {
        if (new_cap <= capacity()) return;

        char* new_ptr = new char[new_cap + 1];
        std::memcpy(new_ptr, c_str(), size() + 1);

        if (!is_short()) {
            delete[] heap_.ptr;
        }

        heap_.ptr = new_ptr;
        heap_.size = size();  // 保存size（在修改前）
        heap_.capacity = new_cap;
        set_long();
    }

    MiniString& operator+=(const MiniString& other) {
        return append(other.c_str(), other.size());
    }

    MiniString& operator+=(const char* s) {
        return append(s, std::strlen(s));
    }

    MiniString& operator+=(char c) {
        push_back(c);
        return *this;
    }

    void push_back(char c) {
        size_t sz = size();
        if (sz >= capacity()) {
            reserve(std::max(capacity() * 2, size_t(16)));
        }

        if (is_short()) {
            sso_.data[sz] = c;
            sso_.data[sz + 1] = '\0';
            set_short_size(sz + 1);
        } else {
            heap_.ptr[sz] = c;
            heap_.ptr[sz + 1] = '\0';
            heap_.size = sz + 1;
        }
    }

    MiniString& append(const char* s, size_t len) {
        size_t sz = size();
        size_t new_size = sz + len;

        if (new_size > capacity()) {
            reserve(std::max(new_size, capacity() * 2));
        }

        char* dst = is_short() ? sso_.data : heap_.ptr;
        std::memcpy(dst + sz, s, len);
        dst[new_size] = '\0';

        if (is_short()) {
            set_short_size(new_size);
        } else {
            heap_.size = new_size;
        }

        return *this;
    }

    void clear() noexcept {
        if (is_short()) {
            sso_.data[0] = '\0';
            set_short_size(0);
        } else {
            heap_.ptr[0] = '\0';
            heap_.size = 0;
        }
    }

    // 比较
    friend bool operator==(const MiniString& a, const MiniString& b) {
        return a.size() == b.size() &&
               std::memcmp(a.c_str(), b.c_str(), a.size()) == 0;
    }

    friend bool operator!=(const MiniString& a, const MiniString& b) {
        return !(a == b);
    }

    friend bool operator<(const MiniString& a, const MiniString& b) {
        return std::lexicographical_compare(
            a.c_str(), a.c_str() + a.size(),
            b.c_str(), b.c_str() + b.size());
    }
};

MiniString operator+(const MiniString& a, const MiniString& b) {
    MiniString result;
    result.reserve(a.size() + b.size());
    result += a;
    result += b;
    return result;
}
```

#### MiniString测试用例

```cpp
// test_mini_string.cpp
#include "mini_string.hpp"
#include <cassert>
#include <iostream>
#include <vector>

void test_construction() {
    std::cout << "Testing construction...\n";

    // 默认构造
    MiniString s1;
    assert(s1.empty());
    assert(s1.size() == 0);
    assert(s1.capacity() >= 0);

    // C字符串构造（短字符串，使用SSO）
    MiniString s2("hello");
    assert(s2.size() == 5);
    assert(s2 == MiniString("hello"));

    // C字符串构造（长字符串，堆分配）
    MiniString s3("this is a very long string that exceeds SSO capacity");
    assert(s3.size() == 52);
    assert(!s3.empty());

    // 带长度构造
    MiniString s4("hello world", 5);
    assert(s4.size() == 5);
    assert(s4 == MiniString("hello"));

    std::cout << "  Construction tests passed!\n";
}

void test_copy_move() {
    std::cout << "Testing copy and move...\n";

    // 短字符串拷贝
    MiniString s1("short");
    MiniString s2(s1);
    assert(s1 == s2);
    assert(s1.c_str() != s2.c_str());  // 不同内存

    // 长字符串拷贝
    MiniString s3("this is a long string for testing copy operations");
    MiniString s4(s3);
    assert(s3 == s4);

    // 移动构造
    MiniString s5("movable");
    const char* ptr = s5.data();
    MiniString s6(std::move(s5));
    assert(s6 == MiniString("movable"));
    // s5应该为空或有效状态

    // 拷贝赋值
    MiniString s7("first");
    MiniString s8("second");
    s7 = s8;
    assert(s7 == s8);

    // 移动赋值
    MiniString s9("target");
    MiniString s10("source string that is long enough");
    s9 = std::move(s10);
    assert(s9 == MiniString("source string that is long enough"));

    std::cout << "  Copy/move tests passed!\n";
}

void test_sso() {
    std::cout << "Testing SSO...\n";

    MiniString s;
    const char* base = reinterpret_cast<const char*>(&s);

    // 测试SSO边界
    for (int i = 1; i <= 20; ++i) {
        s = MiniString(std::string(i, 'x').c_str());
        const char* data = s.data();

        bool is_internal = (data >= base && data < base + sizeof(MiniString));
        bool expected_sso = (i <= 15);  // SSO_CAPACITY = 15

        if (is_internal != expected_sso) {
            std::cout << "  Length " << i << ": expected SSO="
                      << expected_sso << ", got " << is_internal << "\n";
        }
        assert(is_internal == expected_sso);
    }

    std::cout << "  SSO tests passed!\n";
}

void test_modification() {
    std::cout << "Testing modification...\n";

    // push_back
    MiniString s1;
    for (int i = 0; i < 100; ++i) {
        s1.push_back('a');
    }
    assert(s1.size() == 100);

    // append
    MiniString s2("hello");
    s2 += " world";
    assert(s2 == MiniString("hello world"));

    // operator+=
    MiniString s3("prefix");
    s3 += MiniString("_suffix");
    assert(s3 == MiniString("prefix_suffix"));

    // clear
    MiniString s4("to be cleared");
    s4.clear();
    assert(s4.empty());
    assert(s4.size() == 0);

    // reserve
    MiniString s5;
    s5.reserve(100);
    assert(s5.capacity() >= 100);
    assert(s5.empty());

    std::cout << "  Modification tests passed!\n";
}

void test_access() {
    std::cout << "Testing access...\n";

    MiniString s("hello world");

    // operator[]
    assert(s[0] == 'h');
    assert(s[6] == 'w');
    s[0] = 'H';
    assert(s[0] == 'H');

    // c_str
    assert(strcmp(s.c_str(), "Hello world") == 0);

    // data
    assert(s.data() == s.c_str());

    std::cout << "  Access tests passed!\n";
}

void test_comparison() {
    std::cout << "Testing comparison...\n";

    MiniString s1("abc");
    MiniString s2("abc");
    MiniString s3("abd");
    MiniString s4("ab");

    assert(s1 == s2);
    assert(!(s1 == s3));
    assert(s1 != s3);
    assert(s1 < s3);
    assert(s4 < s1);

    std::cout << "  Comparison tests passed!\n";
}

void test_concatenation() {
    std::cout << "Testing concatenation...\n";

    MiniString s1("hello");
    MiniString s2(" world");
    MiniString s3 = s1 + s2;

    assert(s3 == MiniString("hello world"));

    // 多次连接
    MiniString result;
    for (int i = 0; i < 10; ++i) {
        result = result + MiniString("x");
    }
    assert(result.size() == 10);

    std::cout << "  Concatenation tests passed!\n";
}

void test_edge_cases() {
    std::cout << "Testing edge cases...\n";

    // 空字符串
    MiniString empty1;
    MiniString empty2("");
    assert(empty1 == empty2);
    assert(empty1.empty());

    // 自赋值
    MiniString s("self");
    s = s;
    assert(s == MiniString("self"));

    // SSO边界
    MiniString boundary(std::string(15, 'x').c_str());  // 恰好SSO
    assert(boundary.size() == 15);

    MiniString over_boundary(std::string(16, 'x').c_str());  // 超过SSO
    assert(over_boundary.size() == 16);

    std::cout << "  Edge case tests passed!\n";
}

int main() {
    std::cout << "=== MiniString Test Suite ===\n\n";

    test_construction();
    test_copy_move();
    test_sso();
    test_modification();
    test_access();
    test_comparison();
    test_concatenation();
    test_edge_cases();

    std::cout << "\n=== All tests passed! ===\n";
    return 0;
}
```

#### Part 2: mini_string_view
```cpp
// mini_string_view.hpp
#pragma once
#include <cstring>
#include <stdexcept>
#include <algorithm>

class MiniStringView {
    const char* data_ = nullptr;
    size_t size_ = 0;

public:
    static constexpr size_t npos = static_cast<size_t>(-1);

    constexpr MiniStringView() noexcept = default;

    constexpr MiniStringView(const char* s)
        : data_(s), size_(s ? std::char_traits<char>::length(s) : 0) {}

    constexpr MiniStringView(const char* s, size_t len)
        : data_(s), size_(len) {}

    // 从MiniString隐式转换
    MiniStringView(const MiniString& s) : data_(s.c_str()), size_(s.size()) {}

    // 迭代器
    constexpr const char* begin() const noexcept { return data_; }
    constexpr const char* end() const noexcept { return data_ + size_; }
    constexpr const char* cbegin() const noexcept { return begin(); }
    constexpr const char* cend() const noexcept { return end(); }

    // 访问
    constexpr const char* data() const noexcept { return data_; }
    constexpr size_t size() const noexcept { return size_; }
    constexpr size_t length() const noexcept { return size_; }
    constexpr bool empty() const noexcept { return size_ == 0; }

    constexpr const char& operator[](size_t pos) const { return data_[pos]; }

    constexpr const char& at(size_t pos) const {
        if (pos >= size_) {
            throw std::out_of_range("MiniStringView::at");
        }
        return data_[pos];
    }

    constexpr const char& front() const { return data_[0]; }
    constexpr const char& back() const { return data_[size_ - 1]; }

    // 修改器（只修改视图，不修改原数据）
    constexpr void remove_prefix(size_t n) {
        data_ += n;
        size_ -= n;
    }

    constexpr void remove_suffix(size_t n) {
        size_ -= n;
    }

    // 子串
    constexpr MiniStringView substr(size_t pos = 0, size_t count = npos) const {
        if (pos > size_) {
            throw std::out_of_range("MiniStringView::substr");
        }
        return MiniStringView(data_ + pos, std::min(count, size_ - pos));
    }

    // 查找
    constexpr size_t find(char c, size_t pos = 0) const noexcept {
        for (size_t i = pos; i < size_; ++i) {
            if (data_[i] == c) return i;
        }
        return npos;
    }

    constexpr size_t find(MiniStringView sv, size_t pos = 0) const noexcept {
        if (sv.empty()) return pos <= size_ ? pos : npos;
        if (sv.size_ > size_) return npos;

        for (size_t i = pos; i <= size_ - sv.size_; ++i) {
            bool match = true;
            for (size_t j = 0; j < sv.size_; ++j) {
                if (data_[i + j] != sv[j]) {
                    match = false;
                    break;
                }
            }
            if (match) return i;
        }
        return npos;
    }

    constexpr size_t rfind(char c, size_t pos = npos) const noexcept {
        if (empty()) return npos;
        size_t start = std::min(pos, size_ - 1);
        for (size_t i = start + 1; i > 0; --i) {
            if (data_[i - 1] == c) return i - 1;
        }
        return npos;
    }

    constexpr bool starts_with(MiniStringView sv) const noexcept {
        return size_ >= sv.size_ &&
               std::char_traits<char>::compare(data_, sv.data_, sv.size_) == 0;
    }

    constexpr bool ends_with(MiniStringView sv) const noexcept {
        return size_ >= sv.size_ &&
               std::char_traits<char>::compare(
                   data_ + size_ - sv.size_, sv.data_, sv.size_) == 0;
    }

    constexpr bool contains(MiniStringView sv) const noexcept {
        return find(sv) != npos;
    }

    // 比较
    constexpr int compare(MiniStringView sv) const noexcept {
        size_t len = std::min(size_, sv.size_);
        int result = std::char_traits<char>::compare(data_, sv.data_, len);
        if (result != 0) return result;
        if (size_ < sv.size_) return -1;
        if (size_ > sv.size_) return 1;
        return 0;
    }

    friend constexpr bool operator==(MiniStringView a, MiniStringView b) noexcept {
        return a.size_ == b.size_ &&
               std::char_traits<char>::compare(a.data_, b.data_, a.size_) == 0;
    }

    friend constexpr bool operator!=(MiniStringView a, MiniStringView b) noexcept {
        return !(a == b);
    }

    friend constexpr bool operator<(MiniStringView a, MiniStringView b) noexcept {
        return a.compare(b) < 0;
    }
};
```

#### MiniStringView测试用例

```cpp
// test_mini_string_view.cpp
#include "mini_string_view.hpp"
#include "mini_string.hpp"
#include <cassert>
#include <iostream>
#include <string>

void test_sv_construction() {
    std::cout << "Testing string_view construction...\n";

    // 默认构造
    MiniStringView sv1;
    assert(sv1.empty());
    assert(sv1.size() == 0);
    assert(sv1.data() == nullptr);

    // 从C字符串构造
    MiniStringView sv2("hello");
    assert(sv2.size() == 5);
    assert(!sv2.empty());

    // 从指针和长度构造
    const char* str = "hello world";
    MiniStringView sv3(str, 5);
    assert(sv3.size() == 5);

    // 从MiniString构造
    MiniString ms("test string");
    MiniStringView sv4(ms);
    assert(sv4.size() == ms.size());

    std::cout << "  Construction tests passed!\n";
}

void test_sv_access() {
    std::cout << "Testing string_view access...\n";

    MiniStringView sv("hello world");

    // operator[]
    assert(sv[0] == 'h');
    assert(sv[6] == 'w');

    // at
    assert(sv.at(0) == 'h');
    try {
        sv.at(100);
        assert(false);  // 应该抛出异常
    } catch (const std::out_of_range&) {
        // 期望的行为
    }

    // front/back
    assert(sv.front() == 'h');
    assert(sv.back() == 'd');

    // data
    assert(sv.data() != nullptr);

    std::cout << "  Access tests passed!\n";
}

void test_sv_modifiers() {
    std::cout << "Testing string_view modifiers...\n";

    MiniStringView sv("hello world");

    // remove_prefix
    sv.remove_prefix(6);
    assert(sv.size() == 5);
    assert(sv == MiniStringView("world"));

    // remove_suffix
    sv = MiniStringView("hello world");
    sv.remove_suffix(6);
    assert(sv.size() == 5);
    assert(sv == MiniStringView("hello"));

    std::cout << "  Modifier tests passed!\n";
}

void test_sv_substr() {
    std::cout << "Testing string_view substr...\n";

    MiniStringView sv("hello world");

    // 基本substr
    auto sub1 = sv.substr(0, 5);
    assert(sub1 == MiniStringView("hello"));

    auto sub2 = sv.substr(6);
    assert(sub2 == MiniStringView("world"));

    // 越界检查
    try {
        sv.substr(100);
        assert(false);
    } catch (const std::out_of_range&) {
        // 期望的行为
    }

    // 确保substr返回view而非拷贝
    const char* orig_data = sv.data();
    auto sub3 = sv.substr(0, 5);
    assert(sub3.data() == orig_data);  // 指向同一内存

    std::cout << "  Substr tests passed!\n";
}

void test_sv_find() {
    std::cout << "Testing string_view find...\n";

    MiniStringView sv("hello world hello");

    // find char
    assert(sv.find('o') == 4);
    assert(sv.find('o', 5) == 7);
    assert(sv.find('x') == MiniStringView::npos);

    // find string_view
    assert(sv.find(MiniStringView("world")) == 6);
    assert(sv.find(MiniStringView("hello")) == 0);
    assert(sv.find(MiniStringView("hello"), 1) == 12);
    assert(sv.find(MiniStringView("xyz")) == MiniStringView::npos);

    // rfind
    assert(sv.rfind('o') == 13);
    assert(sv.rfind('h') == 12);

    std::cout << "  Find tests passed!\n";
}

void test_sv_starts_ends() {
    std::cout << "Testing starts_with/ends_with...\n";

    MiniStringView sv("hello world");

    assert(sv.starts_with(MiniStringView("hello")));
    assert(sv.starts_with(MiniStringView("h")));
    assert(sv.starts_with(MiniStringView("")));
    assert(!sv.starts_with(MiniStringView("world")));

    assert(sv.ends_with(MiniStringView("world")));
    assert(sv.ends_with(MiniStringView("d")));
    assert(sv.ends_with(MiniStringView("")));
    assert(!sv.ends_with(MiniStringView("hello")));

    assert(sv.contains(MiniStringView("lo wo")));
    assert(!sv.contains(MiniStringView("xyz")));

    std::cout << "  starts_with/ends_with tests passed!\n";
}

void test_sv_comparison() {
    std::cout << "Testing string_view comparison...\n";

    MiniStringView sv1("abc");
    MiniStringView sv2("abc");
    MiniStringView sv3("abd");
    MiniStringView sv4("ab");

    assert(sv1 == sv2);
    assert(sv1 != sv3);
    assert(sv1 < sv3);
    assert(sv4 < sv1);

    assert(sv1.compare(sv2) == 0);
    assert(sv1.compare(sv3) < 0);
    assert(sv3.compare(sv1) > 0);

    std::cout << "  Comparison tests passed!\n";
}

void test_sv_iterator() {
    std::cout << "Testing string_view iterators...\n";

    MiniStringView sv("hello");

    // 范围for
    std::string result;
    for (char c : sv) {
        result += c;
    }
    assert(result == "hello");

    // begin/end
    assert(*sv.begin() == 'h');
    assert(*(sv.end() - 1) == 'o');
    assert(sv.end() - sv.begin() == 5);

    std::cout << "  Iterator tests passed!\n";
}

int main() {
    std::cout << "=== MiniStringView Test Suite ===\n\n";

    test_sv_construction();
    test_sv_access();
    test_sv_modifiers();
    test_sv_substr();
    test_sv_find();
    test_sv_starts_ends();
    test_sv_comparison();
    test_sv_iterator();

    std::cout << "\n=== All tests passed! ===\n";
    return 0;
}
```

#### Part 3: 字符串工具函数
```cpp
// string_utils.hpp
#pragma once
#include <vector>
#include <string>
#include <string_view>
#include <algorithm>

namespace string_utils {

// 分割字符串
std::vector<std::string_view> split(std::string_view str,
                                    std::string_view delim) {
    std::vector<std::string_view> result;
    size_t start = 0;

    while (start < str.size()) {
        size_t end = str.find(delim, start);
        if (end == std::string_view::npos) {
            result.push_back(str.substr(start));
            break;
        }
        result.push_back(str.substr(start, end - start));
        start = end + delim.size();
    }

    return result;
}

// 去除前后空白
std::string_view trim(std::string_view str) {
    auto is_space = [](char c) {
        return c == ' ' || c == '\t' || c == '\n' || c == '\r';
    };

    size_t start = 0;
    while (start < str.size() && is_space(str[start])) ++start;

    size_t end = str.size();
    while (end > start && is_space(str[end - 1])) --end;

    return str.substr(start, end - start);
}

// 连接字符串
template <typename Container>
std::string join(const Container& parts, std::string_view delim) {
    if (parts.empty()) return "";

    std::string result;
    auto it = parts.begin();
    result = *it++;

    for (; it != parts.end(); ++it) {
        result += delim;
        result += *it;
    }

    return result;
}

// 大小写转换
std::string to_lower(std::string_view str) {
    std::string result(str);
    std::transform(result.begin(), result.end(), result.begin(),
                   [](unsigned char c) { return std::tolower(c); });
    return result;
}

std::string to_upper(std::string_view str) {
    std::string result(str);
    std::transform(result.begin(), result.end(), result.begin(),
                   [](unsigned char c) { return std::toupper(c); });
    return result;
}

// 替换所有
std::string replace_all(std::string_view str,
                        std::string_view from,
                        std::string_view to) {
    std::string result;
    result.reserve(str.size());

    size_t pos = 0;
    while (pos < str.size()) {
        size_t found = str.find(from, pos);
        if (found == std::string_view::npos) {
            result += str.substr(pos);
            break;
        }
        result += str.substr(pos, found - pos);
        result += to;
        pos = found + from.size();
    }

    return result;
}

// 格式化（简单版本）
template <typename... Args>
std::string format(std::string_view fmt, Args&&... args) {
    // 简化实现，使用snprintf
    char buffer[1024];
    int len = std::snprintf(buffer, sizeof(buffer), fmt.data(),
                            std::forward<Args>(args)...);
    return std::string(buffer, len > 0 ? len : 0);
}

} // namespace string_utils
```

#### string_utils测试用例

```cpp
// test_string_utils.cpp
#include "string_utils.hpp"
#include <cassert>
#include <iostream>

void test_split() {
    std::cout << "Testing split...\n";

    // 基本分割
    auto parts = string_utils::split("a,b,c", ",");
    assert(parts.size() == 3);
    assert(parts[0] == "a");
    assert(parts[1] == "b");
    assert(parts[2] == "c");

    // 多字符分隔符
    parts = string_utils::split("a::b::c", "::");
    assert(parts.size() == 3);

    // 空字符串
    parts = string_utils::split("", ",");
    assert(parts.size() == 0 || (parts.size() == 1 && parts[0].empty()));

    // 没有分隔符
    parts = string_utils::split("hello", ",");
    assert(parts.size() == 1);
    assert(parts[0] == "hello");

    // 连续分隔符
    parts = string_utils::split("a,,b", ",");
    assert(parts.size() == 3);
    assert(parts[1].empty());

    std::cout << "  Split tests passed!\n";
}

void test_trim() {
    std::cout << "Testing trim...\n";

    // 基本trim
    assert(string_utils::trim("  hello  ") == "hello");
    assert(string_utils::trim("\t\nhello\r\n") == "hello");

    // 只有空白
    assert(string_utils::trim("   ").empty());

    // 没有空白
    assert(string_utils::trim("hello") == "hello");

    // 空字符串
    assert(string_utils::trim("").empty());

    // 只有前导空白
    assert(string_utils::trim("  hello") == "hello");

    // 只有尾随空白
    assert(string_utils::trim("hello  ") == "hello");

    std::cout << "  Trim tests passed!\n";
}

void test_join() {
    std::cout << "Testing join...\n";

    // 基本join
    std::vector<std::string> v1 = {"a", "b", "c"};
    assert(string_utils::join(v1, ",") == "a,b,c");

    // 空容器
    std::vector<std::string> v2;
    assert(string_utils::join(v2, ",").empty());

    // 单个元素
    std::vector<std::string> v3 = {"hello"};
    assert(string_utils::join(v3, ",") == "hello");

    // 多字符分隔符
    assert(string_utils::join(v1, " - ") == "a - b - c");

    std::cout << "  Join tests passed!\n";
}

void test_case_conversion() {
    std::cout << "Testing case conversion...\n";

    // to_lower
    assert(string_utils::to_lower("HELLO") == "hello");
    assert(string_utils::to_lower("Hello World") == "hello world");
    assert(string_utils::to_lower("123") == "123");
    assert(string_utils::to_lower("").empty());

    // to_upper
    assert(string_utils::to_upper("hello") == "HELLO");
    assert(string_utils::to_upper("Hello World") == "HELLO WORLD");
    assert(string_utils::to_upper("123") == "123");

    std::cout << "  Case conversion tests passed!\n";
}

void test_replace_all() {
    std::cout << "Testing replace_all...\n";

    // 基本替换
    assert(string_utils::replace_all("hello world", "o", "0") == "hell0 w0rld");

    // 多字符替换
    assert(string_utils::replace_all("aaa", "aa", "b") == "ba");

    // 没有匹配
    assert(string_utils::replace_all("hello", "x", "y") == "hello");

    // 空from（边界情况）
    // 取决于实现，可能返回原字符串或无限循环

    // 替换为更长的字符串
    assert(string_utils::replace_all("a-b-c", "-", "---") == "a---b---c");

    // 替换为空
    assert(string_utils::replace_all("hello", "l", "") == "heo");

    std::cout << "  Replace_all tests passed!\n";
}

void test_format() {
    std::cout << "Testing format...\n";

    // 基本格式化（注意：这是简化实现，使用snprintf）
    auto result = string_utils::format("Hello %s!", "World");
    assert(result == "Hello World!");

    auto result2 = string_utils::format("Number: %d", 42);
    assert(result2 == "Number: 42");

    std::cout << "  Format tests passed!\n";
}

// 性能测试
void benchmark_string_utils() {
    std::cout << "Running benchmarks...\n";

    const int iterations = 100000;

    // split性能
    auto start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < iterations; ++i) {
        auto parts = string_utils::split("a,b,c,d,e,f,g,h,i,j", ",");
    }
    auto end = std::chrono::high_resolution_clock::now();
    auto split_time = std::chrono::duration<double, std::milli>(end - start).count();
    std::cout << "  split: " << split_time << " ms for " << iterations << " calls\n";

    // trim性能
    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < iterations; ++i) {
        auto trimmed = string_utils::trim("   hello world   ");
    }
    end = std::chrono::high_resolution_clock::now();
    auto trim_time = std::chrono::duration<double, std::milli>(end - start).count();
    std::cout << "  trim: " << trim_time << " ms for " << iterations << " calls\n";

    // join性能
    std::vector<std::string> parts = {"a", "b", "c", "d", "e", "f", "g", "h", "i", "j"};
    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < iterations; ++i) {
        auto joined = string_utils::join(parts, ",");
    }
    end = std::chrono::high_resolution_clock::now();
    auto join_time = std::chrono::duration<double, std::milli>(end - start).count();
    std::cout << "  join: " << join_time << " ms for " << iterations << " calls\n";
}

int main() {
    std::cout << "=== string_utils Test Suite ===\n\n";

    test_split();
    test_trim();
    test_join();
    test_case_conversion();
    test_replace_all();
    test_format();

    std::cout << "\n";
    benchmark_string_utils();

    std::cout << "\n=== All tests passed! ===\n";
    return 0;
}
```

#### 综合性能基准测试

```cpp
// benchmark_strings.cpp
#include <string>
#include <string_view>
#include <chrono>
#include <iostream>
#include <vector>
#include "mini_string.hpp"

template<typename Func>
double benchmark(const std::string& name, Func&& f, int iterations = 100000) {
    auto start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < iterations; ++i) {
        f();
    }
    auto end = std::chrono::high_resolution_clock::now();
    double ms = std::chrono::duration<double, std::milli>(end - start).count();
    std::cout << name << ": " << ms << " ms (" << iterations << " iterations)\n";
    return ms;
}

int main() {
    std::cout << "=== String Performance Benchmarks ===\n\n";

    // 1. SSO vs 堆分配
    std::cout << "--- SSO vs Heap Allocation ---\n";
    benchmark("std::string short (SSO)", []() {
        std::string s("hello");
        volatile auto sz = s.size();
    });
    benchmark("std::string long (heap)", []() {
        std::string s("this is a very long string that exceeds SSO");
        volatile auto sz = s.size();
    });
    benchmark("MiniString short (SSO)", []() {
        MiniString s("hello");
        volatile auto sz = s.size();
    });
    benchmark("MiniString long (heap)", []() {
        MiniString s("this is a very long string that exceeds SSO");
        volatile auto sz = s.size();
    });

    std::cout << "\n--- String Copy ---\n";
    std::string long_str(1000, 'x');
    MiniString long_mini(long_str.c_str());

    benchmark("std::string copy", [&]() {
        std::string copy = long_str;
        volatile auto sz = copy.size();
    });
    benchmark("MiniString copy", [&]() {
        MiniString copy = long_mini;
        volatile auto sz = copy.size();
    });

    std::cout << "\n--- String View vs Copy ---\n";
    benchmark("Pass by value", [&]() {
        [](std::string s) { volatile auto sz = s.size(); }(long_str);
    });
    benchmark("Pass by const ref", [&]() {
        [](const std::string& s) { volatile auto sz = s.size(); }(long_str);
    });
    benchmark("Pass by string_view", [&]() {
        [](std::string_view sv) { volatile auto sz = sv.size(); }(long_str);
    });

    std::cout << "\n--- Substring Operations ---\n";
    benchmark("std::string substr", [&]() {
        auto sub = long_str.substr(100, 500);
        volatile auto sz = sub.size();
    });
    benchmark("string_view substr", [&]() {
        std::string_view sv(long_str);
        auto sub = sv.substr(100, 500);
        volatile auto sz = sub.size();
    });

    std::cout << "\n--- Concatenation ---\n";
    benchmark("std::string concat", []() {
        std::string result;
        for (int i = 0; i < 10; ++i) {
            result += "hello";
        }
        volatile auto sz = result.size();
    });
    benchmark("std::string reserve+concat", []() {
        std::string result;
        result.reserve(50);
        for (int i = 0; i < 10; ++i) {
            result += "hello";
        }
        volatile auto sz = result.size();
    });

    std::cout << "\n=== Benchmark Complete ===\n";
    return 0;
}
```

---

## 检验标准

### 知识检验
- [ ] 解释SSO的原理和好处
- [ ] std::string_view的生命周期陷阱有哪些？
- [ ] UTF-8编码的规则是什么？如何计算字符数？
- [ ] std::regex的性能问题是什么？有什么替代方案？

### 实践检验
- [ ] MiniString正确实现SSO
- [ ] MiniStringView安全且功能完整
- [ ] 字符串工具函数正确处理边界情况

### 输出物
1. `mini_string.hpp`（带SSO）
2. `mini_string_view.hpp`
3. `string_utils.hpp`
4. `test_strings.cpp`
5. `notes/month10_strings.md`

---

## 时间分配（140小时/月）

### 总体分配

| 内容 | 时间 | 占比 |
|------|------|------|
| 理论学习与阅读 | 35小时 | 25% |
| 源码阅读与分析 | 20小时 | 14% |
| MiniString实现 | 30小时 | 21% |
| MiniStringView实现 | 20小时 | 14% |
| 工具函数与测试 | 20小时 | 14% |
| 扩展项目（CSV/编码/日志） | 15小时 | 11% |

### 每周详细分配

#### 第一周：std::string内部实现（35小时）

| 天数 | 理论 | 实践 | 内容 |
|------|------|------|------|
| Day 1 | 3h | 2h | SSO概念、阅读材料 |
| Day 2 | 2h | 3h | SSO三大实现对比、源码阅读 |
| Day 3 | 2h | 3h | 内存布局分析、调试器实验 |
| Day 4 | 2h | 3h | 内存分配策略、增长因子测试 |
| Day 5 | 3h | 2h | COW历史、实现简单COW |
| Day 6 | 2h | 3h | 迭代器失效规则、测试用例 |
| Day 7 | 2h | 3h | 开始MiniString实现 |

#### 第二周：std::string_view（35小时）

| 天数 | 理论 | 实践 | 内容 |
|------|------|------|------|
| Day 1 | 3h | 2h | string_view设计目的、内部结构 |
| Day 2 | 2h | 3h | 零拷贝哲学、性能基准测试 |
| Day 3 | 3h | 2h | 13种生命周期陷阱 |
| Day 4 | 2h | 3h | 函数签名决策树、代码重构 |
| Day 5 | 2h | 3h | span与ranges对比、SimpleSpan |
| Day 6 | 1h | 4h | CSV解析器实现 |
| Day 7 | 2h | 3h | MiniStringView完善、测试 |

#### 第三周：字符编码与Unicode（35小时）

| 天数 | 理论 | 实践 | 内容 |
|------|------|------|------|
| Day 1 | 4h | 1h | 编码历史演进 |
| Day 2 | 3h | 2h | Unicode核心概念、码点计数 |
| Day 3 | 2h | 3h | UTF-8编码规则、编解码器 |
| Day 4 | 2h | 3h | UTF-16/32、代理对、BOM |
| Day 5 | 2h | 3h | C++编码支持、char8_t等 |
| Day 6 | 1h | 4h | 编码检测器实现 |
| Day 7 | 2h | 3h | ICU库简介、周总结 |

#### 第四周：正则表达式（35小时）

| 天数 | 理论 | 实践 | 内容 |
|------|------|------|------|
| Day 1 | 4h | 1h | NFA/DFA理论、状态图 |
| Day 2 | 2h | 3h | std::regex基础用法 |
| Day 3 | 2h | 3h | 高级用法、捕获组 |
| Day 4 | 3h | 2h | 灾难性回溯、性能问题 |
| Day 5 | 2h | 3h | 替代方案、手写解析器 |
| Day 6 | 1h | 4h | 日志分析器实现 |
| Day 7 | 2h | 3h | 综合复习、最佳实践总结 |

### 学习节奏建议

1. **工作日**：每天投入4-5小时
   - 上午：理论学习（1-2小时）
   - 下午/晚上：实践编码（2-3小时）

2. **周末**：每天投入5-6小时
   - 项目实现和综合练习

3. **弹性时间**：每周预留2-3小时
   - 处理遇到的问题
   - 深入感兴趣的主题

---

## 下月预告

Month 11将学习**时间库与chrono**，深入理解C++的时间表示、duration、time_point，以及时钟类型和时间计算。
