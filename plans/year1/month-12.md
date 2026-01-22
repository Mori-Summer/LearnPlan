# Month 12: 第一年总结与综合项目——知识整合与实战

## 本月主题概述

第一年的学习即将结束。本月将进行全面的知识复盘，完成一个综合性项目来整合所学内容，并为第二年的并发编程学习做准备。

---

## 第一年学习回顾

### 知识体系总结

```
第一年：认知重构与高效学习方法论
│
├── Month 01-02: 基础认知建立
│   ├── 第一性原理思维
│   ├── C++抽象机器模型
│   ├── 调试器精通（GDB/LLDB）
│   └── 内存布局分析
│
├── Month 03-04: 核心数据结构
│   ├── STL容器源码（红黑树、哈希表）
│   ├── 智能指针（unique_ptr, shared_ptr, weak_ptr）
│   └── RAII模式
│
├── Month 05-06: 模板与移动语义
│   ├── SFINAE与type_traits
│   ├── 右值引用与移动语义
│   ├── 完美转发
│   └── 编译期计算
│
├── Month 07-08: 异常与函数对象
│   ├── 异常安全等级
│   ├── std::expected
│   ├── Lambda深度
│   └── std::function类型擦除
│
├── Month 09-10: 算法与字符串
│   ├── 迭代器层次
│   ├── STL算法实现
│   ├── std::string SSO
│   └── std::string_view
│
└── Month 11: 时间处理
    ├── chrono库
    ├── duration/time_point/clock
    └── 高精度计时
```

### 已完成的实践项目

| 月份 | 项目 | 核心技能 |
|------|------|----------|
| 01 | mini_vector | 内存管理、异常安全、移动语义 |
| 02 | 调试工具集 | GDB脚本、内存分析 |
| 03 | mini_map | 红黑树实现 |
| 03 | mini_hash_map | 哈希表、rehash |
| 04 | mini_unique_ptr | 独占所有权、RAII |
| 04 | mini_shared_ptr | 引用计数、控制块 |
| 05 | mini_type_traits | 模板元编程 |
| 06 | MiniString | SSO、移动语义 |
| 07 | mini_expected | 错误处理 |
| 07 | SafeStack | 异常安全 |
| 08 | mini_function | 类型擦除 |
| 09 | mini_algorithms | STL算法 |
| 10 | 字符串工具库 | 文本处理 |
| 11 | mini_chrono | 时间处理 |

---

## 详细四周学习计划

### 第一周：知识复盘与项目架构（35小时）

> **本周核心目标**：系统回顾第一年所学知识，完成自测验证，并搭建MiniSTL项目基础架构。

#### 每日学习安排

| 天数 | 主题 | 内容 | 练习 |
|------|------|------|------|
| Day 1 | 内存管理复盘（上） | RAII原理、资源获取即初始化的设计哲学 | 手写RAII文件句柄类 |
| Day 2 | 内存管理复盘（下） | 智能指针内部结构、控制块设计 | 画出shared_ptr内存布局图 |
| Day 3 | 模板元编程复盘 | SFINAE、enable_if、void_t、constexpr | 实现is_same、is_convertible |
| Day 4 | 移动语义复盘 | 值类别、完美转发、引用折叠 | 实现完美转发的工厂函数 |
| Day 5 | 容器原理复盘 | vector扩容、红黑树平衡、哈希冲突 | 画出红黑树插入旋转图 |
| Day 6 | 算法与迭代器复盘 | 迭代器层次、算法复杂度、异常安全 | 分析sort的实现策略 |
| Day 7 | MiniSTL架构搭建 | 项目结构、allocator、type_traits基础 | 完成项目骨架和基础设施 |

---

#### Day 1-2: 内存与生命周期深度复盘（10小时）

**学习目标**：
- [ ] 深刻理解RAII的设计哲学和工程价值
- [ ] 掌握unique_ptr和shared_ptr的内部实现细节
- [ ] 理解weak_ptr解决循环引用的机制
- [ ] 能够回答所有内存相关的自测问题

**自测问题详解**：

##### 问题1：解释RAII的核心思想

**答案解析**：

```cpp
// RAII = Resource Acquisition Is Initialization
// 核心思想：将资源的生命周期与对象的生命周期绑定

// ❌ 传统C风格：手动管理，容易泄漏
void bad_example() {
    FILE* f = fopen("test.txt", "r");
    // 如果这里抛异常，文件句柄泄漏！
    do_something_risky();
    fclose(f);  // 可能永远执行不到
}

// ✅ RAII风格：自动管理，异常安全
class FileHandle {
    FILE* file_;
public:
    explicit FileHandle(const char* path, const char* mode)
        : file_(fopen(path, mode)) {
        if (!file_) throw std::runtime_error("Cannot open file");
    }

    ~FileHandle() {
        if (file_) fclose(file_);
    }

    // 禁止拷贝
    FileHandle(const FileHandle&) = delete;
    FileHandle& operator=(const FileHandle&) = delete;

    // 允许移动
    FileHandle(FileHandle&& other) noexcept : file_(other.file_) {
        other.file_ = nullptr;
    }

    FILE* get() const { return file_; }
};

void good_example() {
    FileHandle f("test.txt", "r");
    do_something_risky();  // 即使抛异常，析构函数也会被调用
}  // 自动关闭文件
```

**RAII的工程价值**：
| 特性 | 价值 |
|------|------|
| 自动释放 | 防止资源泄漏 |
| 异常安全 | 栈展开时自动清理 |
| 代码简洁 | 无需手动释放代码 |
| 所有权明确 | 谁创建谁负责 |

---

##### 问题2：unique_ptr和shared_ptr的内部结构有什么区别？

**答案解析**：

```cpp
// unique_ptr的内部结构（简化版）
template <typename T, typename Deleter = std::default_delete<T>>
class unique_ptr {
    T* ptr_;           // 唯一的数据成员（EBO优化后）
    // Deleter通过EBO优化，如果是空类则不占空间

    // sizeof(unique_ptr<T>) == sizeof(T*) （使用默认删除器时）
};

// shared_ptr的内部结构（简化版）
template <typename T>
class shared_ptr {
    T* ptr_;                    // 指向管理对象
    control_block* ctrl_;       // 指向控制块

    // sizeof(shared_ptr<T>) == 2 * sizeof(void*)
};

// 控制块结构
struct control_block {
    std::atomic<long> use_count;   // 强引用计数
    std::atomic<long> weak_count;  // 弱引用计数
    // 删除器（类型擦除存储）
    // 分配器（类型擦除存储）
    // 对于make_shared：对象本身也在这里
};
```

**内存布局对比**：

```
unique_ptr<Widget>:
┌─────────────┐
│   ptr_ ─────┼──────► Widget对象
└─────────────┘
   8 bytes

shared_ptr<Widget> (new创建):
┌─────────────┐      ┌──────────────────┐
│   ptr_ ─────┼──────►│  Widget对象      │
├─────────────┤      └──────────────────┘
│  ctrl_ ─────┼──────► ┌────────────────┐
└─────────────┘        │ use_count: 1   │
   16 bytes            │ weak_count: 1  │
                       │ deleter        │
                       └────────────────┘

shared_ptr<Widget> (make_shared创建):
┌─────────────┐      ┌──────────────────────┐
│   ptr_ ─────┼──────►│ use_count: 1        │
├─────────────┤      │ weak_count: 1       │
│  ctrl_ ─────┼──────►│ Widget对象（内嵌）   │
└─────────────┘      └──────────────────────┘
   16 bytes              单次分配！
```

---

##### 问题3：weak_ptr如何解决循环引用？

**答案解析**：

```cpp
// 循环引用问题演示
struct Node {
    std::shared_ptr<Node> next;
    std::shared_ptr<Node> prev;  // 问题所在！
    ~Node() { std::cout << "Node destroyed\n"; }
};

void circular_reference_problem() {
    auto a = std::make_shared<Node>();
    auto b = std::make_shared<Node>();

    a->next = b;  // a引用b，b的use_count = 2
    b->prev = a;  // b引用a，a的use_count = 2

    // 函数结束时：
    // a的use_count: 2->1（b->prev还在引用）
    // b的use_count: 2->1（a->next还在引用）
    // 都不为0，都不会销毁！内存泄漏！
}

// 使用weak_ptr解决
struct NodeFixed {
    std::shared_ptr<NodeFixed> next;
    std::weak_ptr<NodeFixed> prev;  // 弱引用不增加use_count
    ~NodeFixed() { std::cout << "NodeFixed destroyed\n"; }
};

void no_circular_reference() {
    auto a = std::make_shared<NodeFixed>();
    auto b = std::make_shared<NodeFixed>();

    a->next = b;  // b的use_count = 2
    b->prev = a;  // a的use_count仍为1（weak_ptr不增加）

    // 函数结束时：
    // a的use_count: 1->0，a被销毁，a->next释放
    // b的use_count: 2->1->0，b被销毁
    // 正确清理！
}

// weak_ptr的使用方式
void use_weak_ptr() {
    std::shared_ptr<int> sp = std::make_shared<int>(42);
    std::weak_ptr<int> wp = sp;

    // 检查对象是否存活
    if (auto locked = wp.lock()) {
        // locked是shared_ptr，对象存活
        std::cout << *locked << std::endl;
    } else {
        // 对象已销毁
    }

    // 或者使用expired()
    if (!wp.expired()) {
        // 注意：这里有TOCTOU问题，多线程下应使用lock()
    }
}
```

---

##### 问题4：make_shared相比直接构造shared_ptr有什么优势和劣势？

**答案解析**：

```cpp
// 方式1：直接构造
auto sp1 = std::shared_ptr<Widget>(new Widget(args...));

// 方式2：make_shared
auto sp2 = std::make_shared<Widget>(args...);
```

| 对比项 | new + shared_ptr | make_shared |
|--------|------------------|-------------|
| 内存分配次数 | 2次（对象+控制块） | 1次（合并分配） |
| 异常安全 | 可能泄漏（C++17前） | 完全安全 |
| 内存效率 | 较低 | 较高（减少分配开销） |
| 缓存友好 | 较差 | 较好（对象和控制块相邻） |
| 自定义删除器 | ✅ 支持 | ❌ 不支持 |
| weak_ptr延长内存 | ❌ 对象内存可先释放 | ⚠️ 对象内存等控制块一起释放 |

```cpp
// 异常安全问题（C++17前）
void dangerous(std::shared_ptr<A> a, std::shared_ptr<B> b);

// C++17前可能泄漏！
dangerous(
    std::shared_ptr<A>(new A()),  // 1. new A()
    std::shared_ptr<B>(new B())   // 2. new B()
);
// 编译器可能按此顺序执行：
// 1. new A()
// 2. new B()  <-- 如果这里抛异常，A泄漏！
// 3. shared_ptr<A>构造
// 4. shared_ptr<B>构造

// 安全写法
dangerous(
    std::make_shared<A>(),
    std::make_shared<B>()
);

// make_shared的劣势：weak_ptr延长内存
{
    std::weak_ptr<LargeObject> wp;
    {
        auto sp = std::make_shared<LargeObject>();  // 对象和控制块合并
        wp = sp;
    }
    // sp销毁，但wp还在
    // 使用make_shared时：对象内存无法释放（和控制块绑定）
    // 使用new时：对象内存可以先释放，只保留控制块
}
```

---

#### Day 3-4: 模板与移动语义复盘（10小时）

**学习目标**：
- [ ] 熟练掌握SFINAE和enable_if的使用
- [ ] 深入理解值类别（lvalue、rvalue、xvalue、prvalue）
- [ ] 掌握完美转发的原理和应用
- [ ] 能够回答所有模板和移动语义相关的自测问题

**自测问题详解**：

##### 问题5：什么是SFINAE？举一个实际应用例子

**答案解析**：

```cpp
// SFINAE = Substitution Failure Is Not An Error
// 替换失败不是错误

// 当模板参数替换导致无效代码时，编译器不报错，而是将该重载从候选集中移除

// 实际应用：检测类型是否有某个成员函数
template <typename T, typename = void>
struct has_size : std::false_type {};

template <typename T>
struct has_size<T, std::void_t<decltype(std::declval<T>().size())>>
    : std::true_type {};

// 使用示例
static_assert(has_size<std::vector<int>>::value, "vector has size()");
static_assert(!has_size<int>::value, "int doesn't have size()");

// 实际应用：为不同类型提供不同实现
template <typename Container>
auto get_size(const Container& c)
    -> std::enable_if_t<has_size<Container>::value, size_t> {
    return c.size();
}

template <typename T, size_t N>
auto get_size(const T (&arr)[N]) -> size_t {
    return N;
}
```

##### 问题6：enable_if的三种使用方式

**答案解析**：

```cpp
// 方式1：作为返回类型
template <typename T>
std::enable_if_t<std::is_integral_v<T>, T>
double_value(T x) {
    return x * 2;
}

// 方式2：作为模板参数（推荐）
template <typename T,
          std::enable_if_t<std::is_integral_v<T>, int> = 0>
T triple_value(T x) {
    return x * 3;
}

// 方式3：作为函数参数
template <typename T>
T quad_value(T x,
             std::enable_if_t<std::is_integral_v<T>, int>* = nullptr) {
    return x * 4;
}

// C++20 concepts更优雅
template <std::integral T>
T modern_double(T x) {
    return x * 2;
}
```

##### 问题9-12：移动语义深度解析

```cpp
// 问题9：值类别
// lvalue: 有名字、可取地址的表达式
int x = 10;        // x是lvalue
int* p = &x;       // 可以取地址

// prvalue: 纯右值，没有身份的临时对象
int y = 10 + 20;   // "10 + 20"是prvalue
std::string s = std::string("hello");  // std::string("hello")是prvalue

// xvalue: 将亡值，即将被移动的对象
std::string s2 = std::move(s);  // std::move(s)是xvalue

// 问题10：std::move做了什么？
// std::move只是一个类型转换，将左值转为右值引用
// 它本身不移动任何数据！
template <typename T>
constexpr std::remove_reference_t<T>&& move(T&& t) noexcept {
    return static_cast<std::remove_reference_t<T>&&>(t);
}

// 问题11：完美转发
template <typename T>
void wrapper(T&& arg) {
    // arg本身是左值！（有名字）
    // 需要forward来保持原始值类别
    target(std::forward<T>(arg));
}

// forward的实现原理
template <typename T>
constexpr T&& forward(std::remove_reference_t<T>& t) noexcept {
    return static_cast<T&&>(t);
}
// 通过引用折叠：
// T = int&  -> T&& = int& && = int&（左值）
// T = int   -> T&& = int&&（右值）

// 问题12：为什么移动操作应该noexcept？
// 因为vector扩容时，只有noexcept的移动操作才会被使用
// 否则会退回到拷贝（保证强异常安全）
class MyClass {
public:
    MyClass(MyClass&& other) noexcept;  // 关键！
    MyClass& operator=(MyClass&& other) noexcept;
};
```

---

#### Day 5-6: 容器与算法复盘（10小时）

**自测问题详解**：

##### 问题13：std::vector的扩容策略和时间复杂度

```cpp
// 扩容策略：通常是2倍增长（GCC/Clang）或1.5倍（MSVC）
// 时间复杂度分析：
// 单次push_back：O(1)均摊，O(n)最坏
// n次push_back总时间：O(n)

// 为什么是O(n)均摊？
// 假设扩容因子为2，n次插入的总拷贝次数：
// 1 + 2 + 4 + 8 + ... + n/2 = n - 1 < n
// 所以均摊到每次操作是O(1)

// 证明（几何级数求和）：
// 扩容次数 = log2(n)
// 总拷贝次数 = 1 + 2 + 4 + ... + 2^k（k = log2(n)）
//           = 2^(k+1) - 1 ≈ 2n
```

##### 问题14：红黑树如何保证平衡？

```cpp
// 红黑树的五条性质：
// 1. 每个节点是红色或黑色
// 2. 根节点是黑色
// 3. 叶子节点（NIL）是黑色
// 4. 红色节点的子节点必须是黑色（不能有连续红色）
// 5. 从任一节点到叶子的所有路径包含相同数量的黑色节点

// 这些性质保证：最长路径 ≤ 2 * 最短路径
// 因此高度 ≤ 2 * log2(n+1)，保证O(log n)操作

// 插入后的修复：
// Case 1: 叔叔是红色 -> 变色
// Case 2: 叔叔是黑色，当前节点是右孩子 -> 左旋
// Case 3: 叔叔是黑色，当前节点是左孩子 -> 右旋+变色
```

##### 问题16：std::sort使用什么算法？

```cpp
// std::sort使用IntroSort（内省排序）
// = QuickSort + HeapSort + InsertionSort的混合

// 策略：
// 1. 开始使用QuickSort
// 2. 如果递归深度超过2*log2(n)，切换到HeapSort
//    （防止QuickSort在最坏情况下退化到O(n²)）
// 3. 当子数组大小≤16时，使用InsertionSort
//    （小数组时InsertionSort更快）

// 复杂度保证：
// 时间：O(n log n)（最坏情况也是）
// 空间：O(log n)（递归栈）
```

---

#### Day 7: MiniSTL项目架构搭建（5小时）

**实践任务**：创建MiniSTL项目骨架和基础设施

```cpp
// include/ministl/type_traits/type_traits.hpp
#pragma once
#include <cstddef>

namespace ministl {

// 编译期常量
template <typename T, T v>
struct integral_constant {
    static constexpr T value = v;
    using value_type = T;
    using type = integral_constant;
    constexpr operator value_type() const noexcept { return value; }
    constexpr value_type operator()() const noexcept { return value; }
};

using true_type = integral_constant<bool, true>;
using false_type = integral_constant<bool, false>;

// 类型判断
template <typename T, typename U>
struct is_same : false_type {};

template <typename T>
struct is_same<T, T> : true_type {};

template <typename T, typename U>
inline constexpr bool is_same_v = is_same<T, U>::value;

// 移除引用
template <typename T> struct remove_reference { using type = T; };
template <typename T> struct remove_reference<T&> { using type = T; };
template <typename T> struct remove_reference<T&&> { using type = T; };

template <typename T>
using remove_reference_t = typename remove_reference<T>::type;

// enable_if
template <bool B, typename T = void>
struct enable_if {};

template <typename T>
struct enable_if<true, T> { using type = T; };

template <bool B, typename T = void>
using enable_if_t = typename enable_if<B, T>::type;

// void_t
template <typename...>
using void_t = void;

// is_integral
template <typename T> struct is_integral : false_type {};
template <> struct is_integral<bool> : true_type {};
template <> struct is_integral<char> : true_type {};
template <> struct is_integral<short> : true_type {};
template <> struct is_integral<int> : true_type {};
template <> struct is_integral<long> : true_type {};
template <> struct is_integral<long long> : true_type {};
// ... 其他整型

template <typename T>
inline constexpr bool is_integral_v = is_integral<T>::value;

// is_trivially_copyable (简化版，依赖编译器内置)
template <typename T>
struct is_trivially_copyable
    : integral_constant<bool, __is_trivially_copyable(T)> {};

// conditional
template <bool B, typename T, typename F>
struct conditional { using type = T; };

template <typename T, typename F>
struct conditional<false, T, F> { using type = F; };

template <bool B, typename T, typename F>
using conditional_t = typename conditional<B, T, F>::type;

} // namespace ministl
```

```cpp
// include/ministl/iterator/iterator_traits.hpp
#pragma once
#include <cstddef>

namespace ministl {

// 迭代器类别标签
struct input_iterator_tag {};
struct output_iterator_tag {};
struct forward_iterator_tag : input_iterator_tag {};
struct bidirectional_iterator_tag : forward_iterator_tag {};
struct random_access_iterator_tag : bidirectional_iterator_tag {};

// 迭代器traits
template <typename Iterator>
struct iterator_traits {
    using difference_type = typename Iterator::difference_type;
    using value_type = typename Iterator::value_type;
    using pointer = typename Iterator::pointer;
    using reference = typename Iterator::reference;
    using iterator_category = typename Iterator::iterator_category;
};

// 指针特化
template <typename T>
struct iterator_traits<T*> {
    using difference_type = std::ptrdiff_t;
    using value_type = T;
    using pointer = T*;
    using reference = T&;
    using iterator_category = random_access_iterator_tag;
};

template <typename T>
struct iterator_traits<const T*> {
    using difference_type = std::ptrdiff_t;
    using value_type = T;
    using pointer = const T*;
    using reference = const T&;
    using iterator_category = random_access_iterator_tag;
};

// advance和distance的实现
template <typename InputIt, typename Distance>
void advance(InputIt& it, Distance n) {
    using category = typename iterator_traits<InputIt>::iterator_category;
    if constexpr (std::is_base_of_v<random_access_iterator_tag, category>) {
        it += n;
    } else if constexpr (std::is_base_of_v<bidirectional_iterator_tag, category>) {
        if (n > 0) while (n--) ++it;
        else while (n++) --it;
    } else {
        while (n--) ++it;
    }
}

template <typename InputIt>
typename iterator_traits<InputIt>::difference_type
distance(InputIt first, InputIt last) {
    using category = typename iterator_traits<InputIt>::iterator_category;
    if constexpr (std::is_base_of_v<random_access_iterator_tag, category>) {
        return last - first;
    } else {
        typename iterator_traits<InputIt>::difference_type n = 0;
        while (first != last) { ++first; ++n; }
        return n;
    }
}

} // namespace ministl
```

**本周检验标准**：
- [ ] 能够不看资料回答22个自测问题中的18个以上
- [ ] 能够画出shared_ptr的内存布局图
- [ ] 能够解释红黑树的五条性质
- [ ] 完成MiniSTL项目骨架搭建
- [ ] 实现allocator.hpp、type_traits.hpp、iterator_traits.hpp
- [ ] 笔记：`notes/month12_week1_review.md`

---

### 第二周：容器实现整合（35小时）

> **本周核心目标**：整合并优化之前实现的容器，形成统一的MiniSTL容器库。

#### 每日学习安排

| 天数 | 主题 | 内容 | 练习 |
|------|------|------|------|
| Day 1 | vector实现（上） | 内存管理、构造函数、迭代器 | 实现基础vector框架 |
| Day 2 | vector实现（下） | push_back、emplace、异常安全 | 完善vector并测试 |
| Day 3 | list实现（上） | 节点设计、双向链表结构 | 实现list基础框架 |
| Day 4 | list实现（下） | 插入删除、splice、排序 | 完善list并测试 |
| Day 5 | map实现（上） | 红黑树节点、旋转操作 | 实现红黑树基础 |
| Day 6 | map实现（下） | 插入修复、删除修复、迭代器 | 完善map并测试 |
| Day 7 | unordered_map实现 | 哈希表、冲突处理、rehash | 完成unordered_map |

---

#### Day 1-2: ministl::vector 完善版实现（10小时）

**实现要点**：

```cpp
// include/ministl/container/vector.hpp
#pragma once
#include "../memory/allocator.hpp"
#include "../type_traits/type_traits.hpp"
#include <initializer_list>
#include <stdexcept>
#include <algorithm>  // for std::copy, std::move

namespace ministl {

template <typename T, typename Allocator = allocator<T>>
class vector {
public:
    // 类型定义
    using value_type = T;
    using allocator_type = Allocator;
    using size_type = std::size_t;
    using difference_type = std::ptrdiff_t;
    using reference = T&;
    using const_reference = const T&;
    using pointer = T*;
    using const_pointer = const T*;
    using iterator = T*;
    using const_iterator = const T*;

private:
    pointer data_ = nullptr;
    size_type size_ = 0;
    size_type capacity_ = 0;
    [[no_unique_address]] Allocator alloc_;

    // 辅助函数：销毁元素
    void destroy_elements() noexcept {
        for (size_type i = 0; i < size_; ++i) {
            std::destroy_at(data_ + i);
        }
    }

    // 辅助函数：扩容
    void grow(size_type min_capacity) {
        size_type new_cap = capacity_ == 0 ? 1 : capacity_ * 2;
        if (new_cap < min_capacity) new_cap = min_capacity;
        reserve(new_cap);
    }

public:
    // 构造函数
    vector() noexcept(noexcept(Allocator())) = default;

    explicit vector(size_type count, const T& value = T(),
                    const Allocator& alloc = Allocator())
        : alloc_(alloc) {
        if (count > 0) {
            data_ = alloc_.allocate(count);
            capacity_ = count;
            try {
                for (size_type i = 0; i < count; ++i) {
                    std::construct_at(data_ + i, value);
                    ++size_;
                }
            } catch (...) {
                destroy_elements();
                alloc_.deallocate(data_, capacity_);
                throw;
            }
        }
    }

    vector(std::initializer_list<T> init, const Allocator& alloc = Allocator())
        : alloc_(alloc) {
        reserve(init.size());
        for (const auto& elem : init) {
            push_back(elem);
        }
    }

    // 拷贝构造
    vector(const vector& other)
        : alloc_(other.alloc_) {
        reserve(other.size_);
        for (size_type i = 0; i < other.size_; ++i) {
            std::construct_at(data_ + i, other.data_[i]);
            ++size_;
        }
    }

    // 移动构造
    vector(vector&& other) noexcept
        : data_(other.data_)
        , size_(other.size_)
        , capacity_(other.capacity_)
        , alloc_(std::move(other.alloc_)) {
        other.data_ = nullptr;
        other.size_ = 0;
        other.capacity_ = 0;
    }

    // 析构函数
    ~vector() {
        destroy_elements();
        if (data_) {
            alloc_.deallocate(data_, capacity_);
        }
    }

    // 拷贝赋值
    vector& operator=(const vector& other) {
        if (this != &other) {
            vector tmp(other);
            swap(tmp);
        }
        return *this;
    }

    // 移动赋值
    vector& operator=(vector&& other) noexcept {
        if (this != &other) {
            destroy_elements();
            if (data_) alloc_.deallocate(data_, capacity_);
            data_ = other.data_;
            size_ = other.size_;
            capacity_ = other.capacity_;
            alloc_ = std::move(other.alloc_);
            other.data_ = nullptr;
            other.size_ = 0;
            other.capacity_ = 0;
        }
        return *this;
    }

    // 元素访问
    reference operator[](size_type pos) { return data_[pos]; }
    const_reference operator[](size_type pos) const { return data_[pos]; }

    reference at(size_type pos) {
        if (pos >= size_) throw std::out_of_range("vector::at");
        return data_[pos];
    }

    reference front() { return data_[0]; }
    reference back() { return data_[size_ - 1]; }
    pointer data() noexcept { return data_; }

    // 迭代器
    iterator begin() noexcept { return data_; }
    iterator end() noexcept { return data_ + size_; }
    const_iterator begin() const noexcept { return data_; }
    const_iterator end() const noexcept { return data_ + size_; }
    const_iterator cbegin() const noexcept { return data_; }
    const_iterator cend() const noexcept { return data_ + size_; }

    // 容量
    bool empty() const noexcept { return size_ == 0; }
    size_type size() const noexcept { return size_; }
    size_type capacity() const noexcept { return capacity_; }

    void reserve(size_type new_cap) {
        if (new_cap <= capacity_) return;

        pointer new_data = alloc_.allocate(new_cap);
        size_type i = 0;
        try {
            // 优先使用移动（如果是noexcept），否则拷贝
            for (; i < size_; ++i) {
                if constexpr (std::is_nothrow_move_constructible_v<T>) {
                    std::construct_at(new_data + i, std::move(data_[i]));
                } else {
                    std::construct_at(new_data + i, data_[i]);
                }
            }
        } catch (...) {
            // 清理已构造的元素
            for (size_type j = 0; j < i; ++j) {
                std::destroy_at(new_data + j);
            }
            alloc_.deallocate(new_data, new_cap);
            throw;
        }

        destroy_elements();
        if (data_) alloc_.deallocate(data_, capacity_);
        data_ = new_data;
        capacity_ = new_cap;
    }

    // 修改器
    void clear() noexcept {
        destroy_elements();
        size_ = 0;
    }

    void push_back(const T& value) {
        if (size_ == capacity_) grow(size_ + 1);
        std::construct_at(data_ + size_, value);
        ++size_;
    }

    void push_back(T&& value) {
        if (size_ == capacity_) grow(size_ + 1);
        std::construct_at(data_ + size_, std::move(value));
        ++size_;
    }

    template <typename... Args>
    reference emplace_back(Args&&... args) {
        if (size_ == capacity_) grow(size_ + 1);
        std::construct_at(data_ + size_, std::forward<Args>(args)...);
        return data_[size_++];
    }

    void pop_back() {
        --size_;
        std::destroy_at(data_ + size_);
    }

    void resize(size_type count) {
        if (count < size_) {
            for (size_type i = count; i < size_; ++i) {
                std::destroy_at(data_ + i);
            }
        } else if (count > size_) {
            reserve(count);
            for (size_type i = size_; i < count; ++i) {
                std::construct_at(data_ + i);
            }
        }
        size_ = count;
    }

    void swap(vector& other) noexcept {
        std::swap(data_, other.data_);
        std::swap(size_, other.size_);
        std::swap(capacity_, other.capacity_);
        std::swap(alloc_, other.alloc_);
    }
};

} // namespace ministl
```

**关键设计决策**：

| 设计点 | 决策 | 原因 |
|--------|------|------|
| 扩容策略 | 2倍增长 | O(1)均摊时间复杂度 |
| reserve中的移动 | 条件移动 | noexcept移动才用，否则拷贝保证异常安全 |
| 异常安全 | 强保证 | push_back失败时vector不变 |
| [[no_unique_address]] | EBO优化 | 空allocator不占空间 |

---

#### Day 3-4: ministl::list 双向链表实现（10小时）

**实现要点**：

```cpp
// include/ministl/container/list.hpp
#pragma once
#include "../memory/allocator.hpp"
#include <initializer_list>

namespace ministl {

template <typename T, typename Allocator = allocator<T>>
class list {
    struct node {
        T data;
        node* prev;
        node* next;

        template <typename... Args>
        node(Args&&... args) : data(std::forward<Args>(args)...) {}
    };

    // 哨兵节点（不存储数据）
    struct sentinel_node {
        node* prev;
        node* next;
    };

public:
    class iterator {
        node* ptr_;
    public:
        using iterator_category = bidirectional_iterator_tag;
        using value_type = T;
        using difference_type = std::ptrdiff_t;
        using pointer = T*;
        using reference = T&;

        iterator(node* p = nullptr) : ptr_(p) {}

        reference operator*() const { return ptr_->data; }
        pointer operator->() const { return &ptr_->data; }

        iterator& operator++() { ptr_ = ptr_->next; return *this; }
        iterator operator++(int) { iterator tmp = *this; ++(*this); return tmp; }
        iterator& operator--() { ptr_ = ptr_->prev; return *this; }
        iterator operator--(int) { iterator tmp = *this; --(*this); return tmp; }

        bool operator==(const iterator& other) const { return ptr_ == other.ptr_; }
        bool operator!=(const iterator& other) const { return ptr_ != other.ptr_; }

        node* get_node() const { return ptr_; }
    };

private:
    sentinel_node sentinel_;
    std::size_t size_ = 0;

    using node_allocator = typename std::allocator_traits<Allocator>
                           ::template rebind_alloc<node>;
    [[no_unique_address]] node_allocator alloc_;

    node* allocate_node() { return alloc_.allocate(1); }
    void deallocate_node(node* p) { alloc_.deallocate(p, 1); }

    // 获取哨兵节点作为node*（类型双关）
    node* sentinel_as_node() {
        return reinterpret_cast<node*>(&sentinel_);
    }

public:
    list() {
        sentinel_.prev = sentinel_.next = sentinel_as_node();
    }

    ~list() { clear(); }

    // 迭代器
    iterator begin() { return iterator(sentinel_.next); }
    iterator end() { return iterator(sentinel_as_node()); }

    // 容量
    bool empty() const { return size_ == 0; }
    std::size_t size() const { return size_; }

    // 访问
    T& front() { return sentinel_.next->data; }
    T& back() { return sentinel_.prev->data; }

    // 修改器
    void push_back(const T& value) {
        insert(end(), value);
    }

    void push_front(const T& value) {
        insert(begin(), value);
    }

    iterator insert(iterator pos, const T& value) {
        node* new_node = allocate_node();
        try {
            std::construct_at(&new_node->data, value);
        } catch (...) {
            deallocate_node(new_node);
            throw;
        }

        node* pos_node = pos.get_node();
        new_node->next = pos_node;
        new_node->prev = pos_node->prev;
        pos_node->prev->next = new_node;
        pos_node->prev = new_node;

        ++size_;
        return iterator(new_node);
    }

    iterator erase(iterator pos) {
        node* pos_node = pos.get_node();
        node* next_node = pos_node->next;

        pos_node->prev->next = pos_node->next;
        pos_node->next->prev = pos_node->prev;

        std::destroy_at(&pos_node->data);
        deallocate_node(pos_node);
        --size_;

        return iterator(next_node);
    }

    void clear() {
        node* current = sentinel_.next;
        while (current != sentinel_as_node()) {
            node* next = current->next;
            std::destroy_at(&current->data);
            deallocate_node(current);
            current = next;
        }
        sentinel_.prev = sentinel_.next = sentinel_as_node();
        size_ = 0;
    }

    // splice: 将other的元素移动到pos之前
    void splice(iterator pos, list& other) {
        if (other.empty()) return;

        node* pos_node = pos.get_node();
        node* first = other.sentinel_.next;
        node* last = other.sentinel_.prev;

        // 从other中移除
        other.sentinel_.next = other.sentinel_as_node();
        other.sentinel_.prev = other.sentinel_as_node();

        // 插入到this
        first->prev = pos_node->prev;
        last->next = pos_node;
        pos_node->prev->next = first;
        pos_node->prev = last;

        size_ += other.size_;
        other.size_ = 0;
    }
};

} // namespace ministl
```

---

#### Day 5-6: ministl::map 红黑树实现（10小时）

**红黑树核心实现**：

```cpp
// include/ministl/container/map.hpp（简化版核心结构）
#pragma once
#include <functional>

namespace ministl {

enum class rb_color { RED, BLACK };

template <typename Key, typename Value, typename Compare = std::less<Key>>
class map {
    struct node {
        std::pair<const Key, Value> data;
        rb_color color;
        node* parent;
        node* left;
        node* right;

        node(const Key& k, const Value& v)
            : data(k, v), color(rb_color::RED)
            , parent(nullptr), left(nullptr), right(nullptr) {}
    };

    node* root_ = nullptr;
    node* nil_;  // 哨兵节点
    std::size_t size_ = 0;
    [[no_unique_address]] Compare comp_;

    // 左旋
    void rotate_left(node* x) {
        node* y = x->right;
        x->right = y->left;
        if (y->left != nil_) y->left->parent = x;
        y->parent = x->parent;
        if (x->parent == nullptr) root_ = y;
        else if (x == x->parent->left) x->parent->left = y;
        else x->parent->right = y;
        y->left = x;
        x->parent = y;
    }

    // 右旋
    void rotate_right(node* x) {
        node* y = x->left;
        x->left = y->right;
        if (y->right != nil_) y->right->parent = x;
        y->parent = x->parent;
        if (x->parent == nullptr) root_ = y;
        else if (x == x->parent->right) x->parent->right = y;
        else x->parent->left = y;
        y->right = x;
        x->parent = y;
    }

    // 插入修复
    void insert_fixup(node* z) {
        while (z->parent && z->parent->color == rb_color::RED) {
            if (z->parent == z->parent->parent->left) {
                node* y = z->parent->parent->right;  // 叔叔节点
                if (y && y->color == rb_color::RED) {
                    // Case 1: 叔叔是红色
                    z->parent->color = rb_color::BLACK;
                    y->color = rb_color::BLACK;
                    z->parent->parent->color = rb_color::RED;
                    z = z->parent->parent;
                } else {
                    if (z == z->parent->right) {
                        // Case 2: 叔叔是黑色，z是右孩子
                        z = z->parent;
                        rotate_left(z);
                    }
                    // Case 3: 叔叔是黑色，z是左孩子
                    z->parent->color = rb_color::BLACK;
                    z->parent->parent->color = rb_color::RED;
                    rotate_right(z->parent->parent);
                }
            } else {
                // 镜像情况
                node* y = z->parent->parent->left;
                if (y && y->color == rb_color::RED) {
                    z->parent->color = rb_color::BLACK;
                    y->color = rb_color::BLACK;
                    z->parent->parent->color = rb_color::RED;
                    z = z->parent->parent;
                } else {
                    if (z == z->parent->left) {
                        z = z->parent;
                        rotate_right(z);
                    }
                    z->parent->color = rb_color::BLACK;
                    z->parent->parent->color = rb_color::RED;
                    rotate_left(z->parent->parent);
                }
            }
        }
        root_->color = rb_color::BLACK;
    }

public:
    // 插入
    std::pair<node*, bool> insert(const Key& key, const Value& value) {
        node* y = nullptr;
        node* x = root_;

        // BST插入
        while (x != nullptr && x != nil_) {
            y = x;
            if (comp_(key, x->data.first)) x = x->left;
            else if (comp_(x->data.first, key)) x = x->right;
            else return {x, false};  // 键已存在
        }

        node* z = new node(key, value);
        z->parent = y;
        z->left = nil_;
        z->right = nil_;

        if (y == nullptr) root_ = z;
        else if (comp_(key, y->data.first)) y->left = z;
        else y->right = z;

        ++size_;
        insert_fixup(z);
        return {z, true};
    }

    // 查找
    node* find(const Key& key) {
        node* x = root_;
        while (x != nullptr && x != nil_) {
            if (comp_(key, x->data.first)) x = x->left;
            else if (comp_(x->data.first, key)) x = x->right;
            else return x;
        }
        return nullptr;
    }

    Value& operator[](const Key& key) {
        auto [node, inserted] = insert(key, Value{});
        return node->data.second;
    }

    std::size_t size() const { return size_; }
    bool empty() const { return size_ == 0; }
};

} // namespace ministl
```

---

#### Day 7: ministl::unordered_map 哈希表实现（5小时）

```cpp
// include/ministl/container/unordered_map.hpp（核心结构）
#pragma once
#include <functional>
#include <vector>

namespace ministl {

template <typename Key, typename Value,
          typename Hash = std::hash<Key>,
          typename KeyEqual = std::equal_to<Key>>
class unordered_map {
    struct node {
        std::pair<const Key, Value> data;
        node* next;
        node(const Key& k, const Value& v) : data(k, v), next(nullptr) {}
    };

    std::vector<node*> buckets_;
    std::size_t size_ = 0;
    float max_load_factor_ = 1.0f;
    [[no_unique_address]] Hash hash_;
    [[no_unique_address]] KeyEqual equal_;

    std::size_t bucket_index(const Key& key) const {
        return hash_(key) % buckets_.size();
    }

    void rehash(std::size_t new_bucket_count) {
        std::vector<node*> new_buckets(new_bucket_count, nullptr);
        for (node* head : buckets_) {
            while (head) {
                node* next = head->next;
                std::size_t idx = hash_(head->data.first) % new_bucket_count;
                head->next = new_buckets[idx];
                new_buckets[idx] = head;
                head = next;
            }
        }
        buckets_ = std::move(new_buckets);
    }

public:
    unordered_map() : buckets_(16, nullptr) {}

    ~unordered_map() {
        for (node* head : buckets_) {
            while (head) {
                node* next = head->next;
                delete head;
                head = next;
            }
        }
    }

    std::pair<node*, bool> insert(const Key& key, const Value& value) {
        // 检查是否需要rehash
        if (static_cast<float>(size_ + 1) / buckets_.size() > max_load_factor_) {
            rehash(buckets_.size() * 2);
        }

        std::size_t idx = bucket_index(key);
        node* current = buckets_[idx];

        // 检查是否已存在
        while (current) {
            if (equal_(current->data.first, key)) {
                return {current, false};
            }
            current = current->next;
        }

        // 插入新节点
        node* new_node = new node(key, value);
        new_node->next = buckets_[idx];
        buckets_[idx] = new_node;
        ++size_;
        return {new_node, true};
    }

    node* find(const Key& key) {
        std::size_t idx = bucket_index(key);
        node* current = buckets_[idx];
        while (current) {
            if (equal_(current->data.first, key)) return current;
            current = current->next;
        }
        return nullptr;
    }

    Value& operator[](const Key& key) {
        auto [node, inserted] = insert(key, Value{});
        return node->data.second;
    }

    std::size_t size() const { return size_; }
    bool empty() const { return size_ == 0; }
    float load_factor() const {
        return static_cast<float>(size_) / buckets_.size();
    }
};

} // namespace ministl
```

**本周检验标准**：
- [ ] ministl::vector 通过所有基础测试
- [ ] ministl::list 支持双向遍历和splice
- [ ] ministl::map 红黑树插入后能自动平衡
- [ ] ministl::unordered_map 支持自动rehash
- [ ] 所有容器支持移动语义
- [ ] 笔记：`notes/month12_week2_containers.md`

---

### 第三周：算法与工具类整合（35小时）

> **本周核心目标**：实现STL算法库和工具类（智能指针、function、optional、variant）。

#### 每日学习安排

| 天数 | 主题 | 内容 | 练习 |
|------|------|------|------|
| Day 1 | 基础算法实现 | find、count、copy、fill、transform | 实现非修改序列算法 |
| Day 2 | 排序算法实现 | sort（IntroSort）、partition | 实现排序算法 |
| Day 3 | 智能指针整合 | unique_ptr、make_unique | 完善unique_ptr |
| Day 4 | shared_ptr实现 | 控制块、引用计数、make_shared | 完善shared_ptr |
| Day 5 | function实现 | 类型擦除、小对象优化 | 实现ministl::function |
| Day 6 | optional/variant | 就地存储、visit | 实现optional和variant |
| Day 7 | string_view与迭代器适配器 | 零拷贝视图、back_inserter | 完成工具库 |

---

#### Day 1-2: 算法库实现（10小时）

```cpp
// include/ministl/algorithm/algorithm.hpp
#pragma once
#include "../iterator/iterator_traits.hpp"

namespace ministl {

// ========== 非修改序列操作 ==========

template <typename InputIt, typename T>
InputIt find(InputIt first, InputIt last, const T& value) {
    for (; first != last; ++first) {
        if (*first == value) return first;
    }
    return last;
}

template <typename InputIt, typename UnaryPred>
InputIt find_if(InputIt first, InputIt last, UnaryPred pred) {
    for (; first != last; ++first) {
        if (pred(*first)) return first;
    }
    return last;
}

template <typename InputIt, typename T>
typename iterator_traits<InputIt>::difference_type
count(InputIt first, InputIt last, const T& value) {
    typename iterator_traits<InputIt>::difference_type n = 0;
    for (; first != last; ++first) {
        if (*first == value) ++n;
    }
    return n;
}

template <typename InputIt1, typename InputIt2>
bool equal(InputIt1 first1, InputIt1 last1, InputIt2 first2) {
    for (; first1 != last1; ++first1, ++first2) {
        if (!(*first1 == *first2)) return false;
    }
    return true;
}

// ========== 修改序列操作 ==========

template <typename InputIt, typename OutputIt>
OutputIt copy(InputIt first, InputIt last, OutputIt d_first) {
    for (; first != last; ++first, ++d_first) {
        *d_first = *first;
    }
    return d_first;
}

template <typename InputIt, typename OutputIt, typename UnaryOp>
OutputIt transform(InputIt first, InputIt last, OutputIt d_first, UnaryOp op) {
    for (; first != last; ++first, ++d_first) {
        *d_first = op(*first);
    }
    return d_first;
}

template <typename ForwardIt, typename T>
void fill(ForwardIt first, ForwardIt last, const T& value) {
    for (; first != last; ++first) {
        *first = value;
    }
}

template <typename ForwardIt, typename Generator>
void generate(ForwardIt first, ForwardIt last, Generator gen) {
    for (; first != last; ++first) {
        *first = gen();
    }
}

template <typename BidirIt>
void reverse(BidirIt first, BidirIt last) {
    while (first != last && first != --last) {
        std::iter_swap(first++, last);
    }
}

template <typename ForwardIt>
ForwardIt unique(ForwardIt first, ForwardIt last) {
    if (first == last) return last;
    ForwardIt result = first;
    while (++first != last) {
        if (!(*result == *first) && ++result != first) {
            *result = std::move(*first);
        }
    }
    return ++result;
}

// ========== 分区操作 ==========

template <typename ForwardIt, typename UnaryPred>
ForwardIt partition(ForwardIt first, ForwardIt last, UnaryPred pred) {
    first = find_if_not(first, last, pred);
    if (first == last) return first;

    for (ForwardIt i = std::next(first); i != last; ++i) {
        if (pred(*i)) {
            std::iter_swap(i, first);
            ++first;
        }
    }
    return first;
}

// ========== 二分查找 ==========

template <typename ForwardIt, typename T>
ForwardIt lower_bound(ForwardIt first, ForwardIt last, const T& value) {
    typename iterator_traits<ForwardIt>::difference_type count = distance(first, last);

    while (count > 0) {
        auto half = count / 2;
        ForwardIt mid = first;
        advance(mid, half);

        if (*mid < value) {
            first = ++mid;
            count -= half + 1;
        } else {
            count = half;
        }
    }
    return first;
}

template <typename ForwardIt, typename T>
bool binary_search(ForwardIt first, ForwardIt last, const T& value) {
    first = lower_bound(first, last, value);
    return first != last && !(value < *first);
}

// ========== 最值操作 ==========

template <typename ForwardIt>
ForwardIt min_element(ForwardIt first, ForwardIt last) {
    if (first == last) return last;
    ForwardIt smallest = first;
    while (++first != last) {
        if (*first < *smallest) smallest = first;
    }
    return smallest;
}

template <typename ForwardIt>
ForwardIt max_element(ForwardIt first, ForwardIt last) {
    if (first == last) return last;
    ForwardIt largest = first;
    while (++first != last) {
        if (*largest < *first) largest = first;
    }
    return largest;
}

} // namespace ministl
```

```cpp
// include/ministl/algorithm/sorting.hpp
#pragma once
#include <utility>  // for std::swap

namespace ministl {

namespace detail {

// 插入排序（小数组时使用）
template <typename RandomIt, typename Compare>
void insertion_sort(RandomIt first, RandomIt last, Compare comp) {
    if (first == last) return;
    for (RandomIt i = first + 1; i != last; ++i) {
        auto key = std::move(*i);
        RandomIt j = i;
        while (j != first && comp(key, *(j - 1))) {
            *j = std::move(*(j - 1));
            --j;
        }
        *j = std::move(key);
    }
}

// 三数取中
template <typename RandomIt, typename Compare>
RandomIt median_of_three(RandomIt a, RandomIt b, RandomIt c, Compare comp) {
    if (comp(*a, *b)) {
        if (comp(*b, *c)) return b;
        else if (comp(*a, *c)) return c;
        else return a;
    } else {
        if (comp(*a, *c)) return a;
        else if (comp(*b, *c)) return c;
        else return b;
    }
}

// 堆排序（递归深度过大时使用）
template <typename RandomIt, typename Compare>
void heap_sort(RandomIt first, RandomIt last, Compare comp) {
    std::make_heap(first, last, comp);
    std::sort_heap(first, last, comp);
}

// IntroSort核心
template <typename RandomIt, typename Compare>
void introsort_impl(RandomIt first, RandomIt last, int depth_limit, Compare comp) {
    while (last - first > 16) {
        if (depth_limit == 0) {
            // 递归过深，切换到堆排序
            heap_sort(first, last, comp);
            return;
        }
        --depth_limit;

        // 三数取中选择pivot
        RandomIt pivot = median_of_three(
            first, first + (last - first) / 2, last - 1, comp);
        std::swap(*pivot, *(last - 1));

        // 分区
        RandomIt cut = first;
        for (RandomIt i = first; i != last - 1; ++i) {
            if (comp(*i, *(last - 1))) {
                std::swap(*i, *cut);
                ++cut;
            }
        }
        std::swap(*cut, *(last - 1));

        // 递归排序较小的分区，循环处理较大的分区
        if (cut - first < last - cut - 1) {
            introsort_impl(first, cut, depth_limit, comp);
            first = cut + 1;
        } else {
            introsort_impl(cut + 1, last, depth_limit, comp);
            last = cut;
        }
    }
}

} // namespace detail

// IntroSort主函数
template <typename RandomIt, typename Compare>
void sort(RandomIt first, RandomIt last, Compare comp) {
    if (first == last) return;

    // 计算最大递归深度：2 * log2(n)
    auto n = last - first;
    int depth_limit = 0;
    for (auto i = n; i > 0; i >>= 1) ++depth_limit;
    depth_limit *= 2;

    detail::introsort_impl(first, last, depth_limit, comp);
    detail::insertion_sort(first, last, comp);
}

template <typename RandomIt>
void sort(RandomIt first, RandomIt last) {
    sort(first, last, std::less<>{});
}

} // namespace ministl
```

---

#### Day 3-4: 智能指针整合（10小时）

```cpp
// include/ministl/memory/unique_ptr.hpp
#pragma once
#include "../type_traits/type_traits.hpp"
#include <utility>

namespace ministl {

template <typename T>
struct default_delete {
    constexpr default_delete() noexcept = default;

    template <typename U, typename = enable_if_t<std::is_convertible_v<U*, T*>>>
    default_delete(const default_delete<U>&) noexcept {}

    void operator()(T* ptr) const {
        static_assert(sizeof(T) > 0, "Cannot delete incomplete type");
        delete ptr;
    }
};

template <typename T>
struct default_delete<T[]> {
    constexpr default_delete() noexcept = default;

    void operator()(T* ptr) const {
        delete[] ptr;
    }
};

template <typename T, typename Deleter = default_delete<T>>
class unique_ptr {
public:
    using element_type = T;
    using deleter_type = Deleter;
    using pointer = T*;

private:
    pointer ptr_ = nullptr;
    [[no_unique_address]] Deleter deleter_;

public:
    // 构造函数
    constexpr unique_ptr() noexcept = default;
    constexpr unique_ptr(std::nullptr_t) noexcept : unique_ptr() {}

    explicit unique_ptr(pointer p) noexcept : ptr_(p) {}

    unique_ptr(pointer p, const Deleter& d) noexcept
        : ptr_(p), deleter_(d) {}

    unique_ptr(pointer p, Deleter&& d) noexcept
        : ptr_(p), deleter_(std::move(d)) {}

    // 移动构造
    unique_ptr(unique_ptr&& other) noexcept
        : ptr_(other.release()), deleter_(std::move(other.deleter_)) {}

    // 转换构造（支持派生类到基类）
    template <typename U, typename E,
              typename = enable_if_t<std::is_convertible_v<
                  typename unique_ptr<U, E>::pointer, pointer>>>
    unique_ptr(unique_ptr<U, E>&& other) noexcept
        : ptr_(other.release()), deleter_(std::move(other.get_deleter())) {}

    // 析构函数
    ~unique_ptr() {
        if (ptr_) deleter_(ptr_);
    }

    // 移动赋值
    unique_ptr& operator=(unique_ptr&& other) noexcept {
        reset(other.release());
        deleter_ = std::move(other.deleter_);
        return *this;
    }

    unique_ptr& operator=(std::nullptr_t) noexcept {
        reset();
        return *this;
    }

    // 禁止拷贝
    unique_ptr(const unique_ptr&) = delete;
    unique_ptr& operator=(const unique_ptr&) = delete;

    // 观察器
    pointer get() const noexcept { return ptr_; }
    Deleter& get_deleter() noexcept { return deleter_; }
    const Deleter& get_deleter() const noexcept { return deleter_; }
    explicit operator bool() const noexcept { return ptr_ != nullptr; }

    // 解引用
    T& operator*() const { return *ptr_; }
    pointer operator->() const noexcept { return ptr_; }

    // 修改器
    pointer release() noexcept {
        pointer p = ptr_;
        ptr_ = nullptr;
        return p;
    }

    void reset(pointer p = pointer()) noexcept {
        pointer old = ptr_;
        ptr_ = p;
        if (old) deleter_(old);
    }

    void swap(unique_ptr& other) noexcept {
        std::swap(ptr_, other.ptr_);
        std::swap(deleter_, other.deleter_);
    }
};

// make_unique
template <typename T, typename... Args>
enable_if_t<!std::is_array_v<T>, unique_ptr<T>>
make_unique(Args&&... args) {
    return unique_ptr<T>(new T(std::forward<Args>(args)...));
}

template <typename T>
enable_if_t<std::is_array_v<T> && std::extent_v<T> == 0, unique_ptr<T>>
make_unique(std::size_t size) {
    return unique_ptr<T>(new std::remove_extent_t<T>[size]());
}

} // namespace ministl
```

---

#### Day 5-6: function、optional、variant实现（10小时）

```cpp
// include/ministl/utility/function.hpp（简化版）
#pragma once
#include <memory>
#include <stdexcept>

namespace ministl {

template <typename>
class function;

template <typename R, typename... Args>
class function<R(Args...)> {
    // 类型擦除基类
    struct callable_base {
        virtual ~callable_base() = default;
        virtual R invoke(Args...) = 0;
        virtual std::unique_ptr<callable_base> clone() const = 0;
    };

    // 具体类型持有者
    template <typename F>
    struct callable_holder : callable_base {
        F func_;

        callable_holder(F f) : func_(std::move(f)) {}

        R invoke(Args... args) override {
            return func_(std::forward<Args>(args)...);
        }

        std::unique_ptr<callable_base> clone() const override {
            return std::make_unique<callable_holder>(func_);
        }
    };

    std::unique_ptr<callable_base> callable_;

public:
    function() = default;
    function(std::nullptr_t) noexcept {}

    template <typename F>
    function(F f) : callable_(std::make_unique<callable_holder<F>>(std::move(f))) {}

    function(const function& other)
        : callable_(other.callable_ ? other.callable_->clone() : nullptr) {}

    function(function&& other) noexcept = default;

    function& operator=(const function& other) {
        function tmp(other);
        swap(tmp);
        return *this;
    }

    function& operator=(function&& other) noexcept = default;

    function& operator=(std::nullptr_t) noexcept {
        callable_.reset();
        return *this;
    }

    R operator()(Args... args) const {
        if (!callable_) throw std::bad_function_call();
        return callable_->invoke(std::forward<Args>(args)...);
    }

    explicit operator bool() const noexcept {
        return callable_ != nullptr;
    }

    void swap(function& other) noexcept {
        callable_.swap(other.callable_);
    }
};

} // namespace ministl
```

```cpp
// include/ministl/utility/optional.hpp
#pragma once
#include <stdexcept>
#include <utility>

namespace ministl {

struct nullopt_t {
    explicit constexpr nullopt_t(int) {}
};
inline constexpr nullopt_t nullopt{0};

class bad_optional_access : public std::exception {
public:
    const char* what() const noexcept override {
        return "bad optional access";
    }
};

template <typename T>
class optional {
    alignas(T) unsigned char storage_[sizeof(T)];
    bool has_value_ = false;

    T* ptr() { return reinterpret_cast<T*>(storage_); }
    const T* ptr() const { return reinterpret_cast<const T*>(storage_); }

public:
    optional() = default;
    optional(nullopt_t) noexcept {}

    optional(const T& value) : has_value_(true) {
        new (storage_) T(value);
    }

    optional(T&& value) : has_value_(true) {
        new (storage_) T(std::move(value));
    }

    template <typename... Args>
    explicit optional(std::in_place_t, Args&&... args) : has_value_(true) {
        new (storage_) T(std::forward<Args>(args)...);
    }

    optional(const optional& other) : has_value_(other.has_value_) {
        if (has_value_) new (storage_) T(*other.ptr());
    }

    optional(optional&& other) noexcept(std::is_nothrow_move_constructible_v<T>)
        : has_value_(other.has_value_) {
        if (has_value_) new (storage_) T(std::move(*other.ptr()));
    }

    ~optional() { reset(); }

    optional& operator=(nullopt_t) noexcept {
        reset();
        return *this;
    }

    optional& operator=(const optional& other) {
        if (has_value_ && other.has_value_) {
            *ptr() = *other.ptr();
        } else if (other.has_value_) {
            new (storage_) T(*other.ptr());
            has_value_ = true;
        } else {
            reset();
        }
        return *this;
    }

    optional& operator=(optional&& other)
        noexcept(std::is_nothrow_move_assignable_v<T> &&
                 std::is_nothrow_move_constructible_v<T>) {
        if (has_value_ && other.has_value_) {
            *ptr() = std::move(*other.ptr());
        } else if (other.has_value_) {
            new (storage_) T(std::move(*other.ptr()));
            has_value_ = true;
        } else {
            reset();
        }
        return *this;
    }

    // 观察器
    bool has_value() const noexcept { return has_value_; }
    explicit operator bool() const noexcept { return has_value_; }

    T& value() & {
        if (!has_value_) throw bad_optional_access();
        return *ptr();
    }

    const T& value() const& {
        if (!has_value_) throw bad_optional_access();
        return *ptr();
    }

    T&& value() && {
        if (!has_value_) throw bad_optional_access();
        return std::move(*ptr());
    }

    template <typename U>
    T value_or(U&& default_value) const& {
        return has_value_ ? *ptr() : static_cast<T>(std::forward<U>(default_value));
    }

    template <typename U>
    T value_or(U&& default_value) && {
        return has_value_ ? std::move(*ptr()) : static_cast<T>(std::forward<U>(default_value));
    }

    T* operator->() { return ptr(); }
    const T* operator->() const { return ptr(); }
    T& operator*() & { return *ptr(); }
    const T& operator*() const& { return *ptr(); }
    T&& operator*() && { return std::move(*ptr()); }

    // 修改器
    void reset() noexcept {
        if (has_value_) {
            ptr()->~T();
            has_value_ = false;
        }
    }

    template <typename... Args>
    T& emplace(Args&&... args) {
        reset();
        new (storage_) T(std::forward<Args>(args)...);
        has_value_ = true;
        return *ptr();
    }
};

} // namespace ministl
```

---

#### Day 7: string_view与迭代器适配器（5小时）

```cpp
// include/ministl/utility/string_view.hpp
#pragma once
#include <string>
#include <stdexcept>
#include <algorithm>

namespace ministl {

class string_view {
    const char* data_ = nullptr;
    std::size_t size_ = 0;

public:
    using value_type = char;
    using pointer = const char*;
    using const_pointer = const char*;
    using reference = const char&;
    using const_reference = const char&;
    using iterator = const char*;
    using const_iterator = const char*;
    using size_type = std::size_t;

    static constexpr size_type npos = size_type(-1);

    // 构造函数
    constexpr string_view() noexcept = default;
    constexpr string_view(const char* s, size_type count) : data_(s), size_(count) {}
    constexpr string_view(const char* s) : data_(s), size_(std::char_traits<char>::length(s)) {}
    string_view(const std::string& s) noexcept : data_(s.data()), size_(s.size()) {}

    // 迭代器
    constexpr const_iterator begin() const noexcept { return data_; }
    constexpr const_iterator end() const noexcept { return data_ + size_; }
    constexpr const_iterator cbegin() const noexcept { return data_; }
    constexpr const_iterator cend() const noexcept { return data_ + size_; }

    // 容量
    constexpr size_type size() const noexcept { return size_; }
    constexpr size_type length() const noexcept { return size_; }
    constexpr bool empty() const noexcept { return size_ == 0; }

    // 元素访问
    constexpr const_reference operator[](size_type pos) const { return data_[pos]; }
    constexpr const_reference at(size_type pos) const {
        if (pos >= size_) throw std::out_of_range("string_view::at");
        return data_[pos];
    }
    constexpr const_reference front() const { return data_[0]; }
    constexpr const_reference back() const { return data_[size_ - 1]; }
    constexpr const_pointer data() const noexcept { return data_; }

    // 修改器
    constexpr void remove_prefix(size_type n) {
        data_ += n;
        size_ -= n;
    }

    constexpr void remove_suffix(size_type n) {
        size_ -= n;
    }

    // 操作
    constexpr string_view substr(size_type pos = 0, size_type count = npos) const {
        if (pos > size_) throw std::out_of_range("string_view::substr");
        return string_view(data_ + pos, std::min(count, size_ - pos));
    }

    size_type find(string_view sv, size_type pos = 0) const noexcept {
        if (pos > size_ || sv.size() > size_ - pos) return npos;
        auto it = std::search(begin() + pos, end(), sv.begin(), sv.end());
        return it == end() ? npos : static_cast<size_type>(it - begin());
    }

    size_type find(char c, size_type pos = 0) const noexcept {
        for (size_type i = pos; i < size_; ++i) {
            if (data_[i] == c) return i;
        }
        return npos;
    }

    // 比较
    constexpr int compare(string_view sv) const noexcept {
        size_type len = std::min(size_, sv.size_);
        int result = std::char_traits<char>::compare(data_, sv.data_, len);
        if (result != 0) return result;
        return size_ < sv.size_ ? -1 : (size_ > sv.size_ ? 1 : 0);
    }

    friend bool operator==(string_view lhs, string_view rhs) noexcept {
        return lhs.size_ == rhs.size_ && lhs.compare(rhs) == 0;
    }

    friend bool operator!=(string_view lhs, string_view rhs) noexcept {
        return !(lhs == rhs);
    }
};

} // namespace ministl
```

```cpp
// include/ministl/iterator/iterator_adapters.hpp
#pragma once
#include "iterator_traits.hpp"

namespace ministl {

// back_insert_iterator
template <typename Container>
class back_insert_iterator {
    Container* container_;

public:
    using iterator_category = output_iterator_tag;
    using value_type = void;
    using difference_type = void;
    using pointer = void;
    using reference = void;

    explicit back_insert_iterator(Container& c) : container_(&c) {}

    back_insert_iterator& operator=(const typename Container::value_type& value) {
        container_->push_back(value);
        return *this;
    }

    back_insert_iterator& operator=(typename Container::value_type&& value) {
        container_->push_back(std::move(value));
        return *this;
    }

    back_insert_iterator& operator*() { return *this; }
    back_insert_iterator& operator++() { return *this; }
    back_insert_iterator operator++(int) { return *this; }
};

template <typename Container>
back_insert_iterator<Container> back_inserter(Container& c) {
    return back_insert_iterator<Container>(c);
}

// reverse_iterator
template <typename Iterator>
class reverse_iterator {
    Iterator current_;

public:
    using iterator_type = Iterator;
    using iterator_category = typename iterator_traits<Iterator>::iterator_category;
    using value_type = typename iterator_traits<Iterator>::value_type;
    using difference_type = typename iterator_traits<Iterator>::difference_type;
    using pointer = typename iterator_traits<Iterator>::pointer;
    using reference = typename iterator_traits<Iterator>::reference;

    reverse_iterator() = default;
    explicit reverse_iterator(Iterator it) : current_(it) {}

    Iterator base() const { return current_; }

    reference operator*() const {
        Iterator tmp = current_;
        return *--tmp;
    }

    pointer operator->() const { return &(operator*()); }

    reverse_iterator& operator++() { --current_; return *this; }
    reverse_iterator operator++(int) { auto tmp = *this; --current_; return tmp; }
    reverse_iterator& operator--() { ++current_; return *this; }
    reverse_iterator operator--(int) { auto tmp = *this; ++current_; return tmp; }

    reverse_iterator operator+(difference_type n) const {
        return reverse_iterator(current_ - n);
    }

    reverse_iterator operator-(difference_type n) const {
        return reverse_iterator(current_ + n);
    }

    bool operator==(const reverse_iterator& other) const {
        return current_ == other.current_;
    }

    bool operator!=(const reverse_iterator& other) const {
        return current_ != other.current_;
    }
};

} // namespace ministl
```

**本周检验标准**：
- [ ] 算法库通过基本测试（find、sort、copy等）
- [ ] unique_ptr支持自定义删除器
- [ ] function支持lambda和函数指针
- [ ] optional支持就地构造
- [ ] string_view支持substr和find
- [ ] 笔记：`notes/month12_week3_algorithms.md`

---

### 第四周：测试、基准与年度总结（35小时）

> **本周核心目标**：完成MiniSTL测试套件、性能基准、文档和第一年学习总结。

#### 每日学习安排

| 天数 | 主题 | 内容 | 练习 |
|------|------|------|------|
| Day 1 | 测试框架设计 | GTest结构、测试覆盖策略 | 编写vector完整测试 |
| Day 2 | 容器测试 | list、map、unordered_map测试 | 完成所有容器测试 |
| Day 3 | 算法与工具测试 | 算法、智能指针、工具类测试 | 完成所有组件测试 |
| Day 4 | 基准测试 | Google Benchmark、性能对比 | 对比MiniSTL与标准库 |
| Day 5 | 性能优化 | 根据基准结果优化瓶颈 | 优化关键路径 |
| Day 6 | 文档与总结 | API文档、设计文档、年度总结 | 完成文档输出物 |
| Day 7 | 第二年预习 | 并发基础、内存模型入门 | 阅读预习材料 |

---

#### Day 1-3: 测试套件设计与实现（15小时）

**测试策略**：

```cpp
// tests/test_vector.cpp（完整版）
#include <gtest/gtest.h>
#include <ministl/container/vector.hpp>
#include <string>
#include <memory>

// ========== 构造函数测试 ==========

TEST(VectorTest, DefaultConstruction) {
    ministl::vector<int> v;
    EXPECT_TRUE(v.empty());
    EXPECT_EQ(v.size(), 0);
    EXPECT_EQ(v.capacity(), 0);
}

TEST(VectorTest, SizeValueConstruction) {
    ministl::vector<int> v(10, 42);
    EXPECT_EQ(v.size(), 10);
    for (const auto& elem : v) {
        EXPECT_EQ(elem, 42);
    }
}

TEST(VectorTest, InitializerListConstruction) {
    ministl::vector<int> v = {1, 2, 3, 4, 5};
    EXPECT_EQ(v.size(), 5);
    EXPECT_EQ(v[0], 1);
    EXPECT_EQ(v[4], 5);
}

// ========== 拷贝与移动测试 ==========

TEST(VectorTest, CopyConstruction) {
    ministl::vector<int> v1 = {1, 2, 3};
    ministl::vector<int> v2(v1);

    EXPECT_EQ(v1.size(), v2.size());
    EXPECT_EQ(v1[0], v2[0]);
    v2[0] = 100;
    EXPECT_NE(v1[0], v2[0]);  // 深拷贝
}

TEST(VectorTest, MoveConstruction) {
    ministl::vector<std::string> v1;
    v1.push_back("hello");
    v1.push_back("world");

    ministl::vector<std::string> v2(std::move(v1));

    EXPECT_TRUE(v1.empty());  // 移动后源为空
    EXPECT_EQ(v2.size(), 2);
    EXPECT_EQ(v2[0], "hello");
}

// ========== 修改器测试 ==========

TEST(VectorTest, PushBack) {
    ministl::vector<int> v;
    for (int i = 0; i < 1000; ++i) {
        v.push_back(i);
        EXPECT_EQ(v.back(), i);
        EXPECT_EQ(v.size(), static_cast<size_t>(i + 1));
    }
}

TEST(VectorTest, EmplaceBack) {
    ministl::vector<std::pair<int, std::string>> v;
    v.emplace_back(1, "one");
    v.emplace_back(2, "two");

    EXPECT_EQ(v.size(), 2);
    EXPECT_EQ(v[0].first, 1);
    EXPECT_EQ(v[0].second, "one");
}

TEST(VectorTest, PopBack) {
    ministl::vector<int> v = {1, 2, 3};
    v.pop_back();
    EXPECT_EQ(v.size(), 2);
    EXPECT_EQ(v.back(), 2);
}

// ========== 异常安全测试 ==========

TEST(VectorTest, ExceptionSafetyOnPushBack) {
    struct ThrowOnCopy {
        static int throw_after;
        static int copy_count;

        ThrowOnCopy() = default;
        ThrowOnCopy(const ThrowOnCopy&) {
            if (++copy_count >= throw_after) {
                throw std::runtime_error("test exception");
            }
        }
        ThrowOnCopy(ThrowOnCopy&&) noexcept = default;
    };

    ThrowOnCopy::throw_after = 5;
    ThrowOnCopy::copy_count = 0;

    ministl::vector<ThrowOnCopy> v;
    size_t successful_inserts = 0;

    try {
        for (int i = 0; i < 10; ++i) {
            ThrowOnCopy t;
            v.push_back(t);
            ++successful_inserts;
        }
    } catch (const std::runtime_error&) {
        // 验证强异常安全：size应该等于成功插入的数量
        EXPECT_EQ(v.size(), successful_inserts);
    }
}

int ThrowOnCopy::throw_after = 0;
int ThrowOnCopy::copy_count = 0;

// ========== 迭代器测试 ==========

TEST(VectorTest, Iterators) {
    ministl::vector<int> v = {1, 2, 3, 4, 5};

    int sum = 0;
    for (auto it = v.begin(); it != v.end(); ++it) {
        sum += *it;
    }
    EXPECT_EQ(sum, 15);

    // range-based for
    sum = 0;
    for (int x : v) {
        sum += x;
    }
    EXPECT_EQ(sum, 15);
}
```

**测试覆盖清单**：

| 组件 | 测试点 | 状态 |
|------|--------|------|
| vector | 构造、拷贝、移动、迭代、异常安全 | |
| list | 双向遍历、splice、插入删除 | |
| map | 插入、查找、红黑树平衡验证 | |
| unordered_map | 插入、查找、rehash触发 | |
| unique_ptr | 所有权转移、自定义删除器 | |
| shared_ptr | 引用计数、weak_ptr | |
| function | lambda、函数指针、成员函数 | |
| optional | 有值/无值、value_or | |
| 算法 | sort正确性、find、copy | |

---

#### Day 4-5: 性能基准测试（10小时）

```cpp
// benchmarks/bench_all.cpp
#include <benchmark/benchmark.h>
#include <ministl/ministl.hpp>
#include <vector>
#include <map>
#include <unordered_map>
#include <algorithm>

// ========== Vector基准 ==========

static void BM_StdVector_PushBack(benchmark::State& state) {
    for (auto _ : state) {
        std::vector<int> v;
        for (int i = 0; i < state.range(0); ++i) {
            v.push_back(i);
        }
        benchmark::DoNotOptimize(v);
    }
}
BENCHMARK(BM_StdVector_PushBack)->Range(8, 1 << 20);

static void BM_MiniVector_PushBack(benchmark::State& state) {
    for (auto _ : state) {
        ministl::vector<int> v;
        for (int i = 0; i < state.range(0); ++i) {
            v.push_back(i);
        }
        benchmark::DoNotOptimize(v);
    }
}
BENCHMARK(BM_MiniVector_PushBack)->Range(8, 1 << 20);

// ========== Sort基准 ==========

static void BM_StdSort(benchmark::State& state) {
    std::vector<int> data(state.range(0));
    for (auto _ : state) {
        state.PauseTiming();
        std::generate(data.begin(), data.end(), std::rand);
        state.ResumeTiming();

        std::sort(data.begin(), data.end());
        benchmark::DoNotOptimize(data);
    }
}
BENCHMARK(BM_StdSort)->Range(8, 1 << 18);

static void BM_MiniSort(benchmark::State& state) {
    ministl::vector<int> data(state.range(0));
    for (auto _ : state) {
        state.PauseTiming();
        std::generate(data.begin(), data.end(), std::rand);
        state.ResumeTiming();

        ministl::sort(data.begin(), data.end());
        benchmark::DoNotOptimize(data);
    }
}
BENCHMARK(BM_MiniSort)->Range(8, 1 << 18);

// ========== Map基准 ==========

static void BM_StdMap_Insert(benchmark::State& state) {
    for (auto _ : state) {
        std::map<int, int> m;
        for (int i = 0; i < state.range(0); ++i) {
            m[i] = i;
        }
        benchmark::DoNotOptimize(m);
    }
}
BENCHMARK(BM_StdMap_Insert)->Range(8, 1 << 16);

static void BM_MiniMap_Insert(benchmark::State& state) {
    for (auto _ : state) {
        ministl::map<int, int> m;
        for (int i = 0; i < state.range(0); ++i) {
            m[i] = i;
        }
        benchmark::DoNotOptimize(m);
    }
}
BENCHMARK(BM_MiniMap_Insert)->Range(8, 1 << 16);

BENCHMARK_MAIN();
```

**预期性能对比结论**：

| 组件 | 预期与std对比 | 原因分析 |
|------|---------------|----------|
| vector | 接近（90-100%） | 核心逻辑相同 |
| sort | 略慢（80-95%） | IntroSort细节优化差异 |
| map | 略慢（70-90%） | 红黑树优化程度 |
| unordered_map | 接近（85-100%） | 哈希表实现较简单 |

---

#### Day 6: 文档与年度总结（5小时）

**year1_summary.md 模板**：

```markdown
# C++ 第一年学习总结

## 学习时长统计
- 总学习时长：约1680小时（140小时/月 × 12月）
- 项目代码量：约15000行（含测试）

## 核心能力提升

### 1. 底层理解
- [x] 理解C++抽象机器模型
- [x] 掌握内存布局（栈、堆、静态区）
- [x] 精通调试器使用（GDB/LLDB）

### 2. 现代C++
- [x] 移动语义与完美转发
- [x] 模板元编程（SFINAE、type_traits）
- [x] 异常安全等级

### 3. STL深度
- [x] 容器内部实现（红黑树、哈希表、动态数组）
- [x] 算法与迭代器设计
- [x] 智能指针原理

## 完成的项目

| 项目 | 代码行数 | 核心技能 |
|------|----------|----------|
| mini_vector | 500+ | 内存管理、异常安全 |
| mini_map | 800+ | 红黑树 |
| mini_shared_ptr | 400+ | 引用计数、控制块 |
| mini_function | 300+ | 类型擦除 |
| MiniSTL综合项目 | 5000+ | 第一年知识整合 |

## 最大收获

1. **第一性原理**：学会从底层原理理解问题
2. **源码阅读能力**：能够阅读libstdc++/libc++源码
3. **工程思维**：异常安全、性能权衡、接口设计

## 不足与改进

1. 并发编程尚未涉及 → 第二年重点
2. 实际项目经验不足 → 寻找开源项目贡献
3. 某些高级模板技巧不够熟练 → 继续练习

## 第二年展望

- 深入C++内存模型
- 掌握无锁数据结构
- 学习协程（C++20）
```

---

#### Day 7: 第二年预习（5小时）

**预习内容清单**：

1. **阅读材料**（2小时）：
   - 《C++ Concurrency in Action》第1-2章
   - Preshing博客：Memory Ordering at Compile Time

2. **概念预习**（2小时）：
   - 什么是数据竞争？
   - 什么是顺序一致性？
   - 为什么需要memory_order？

3. **实验**（1小时）：
   ```cpp
   // 简单的多线程实验
   #include <thread>
   #include <atomic>
   #include <iostream>

   std::atomic<int> counter{0};

   void increment() {
       for (int i = 0; i < 100000; ++i) {
           ++counter;  // 原子操作
       }
   }

   int main() {
       std::thread t1(increment);
       std::thread t2(increment);
       t1.join();
       t2.join();
       std::cout << "Counter: " << counter << std::endl;  // 应该是200000
   }
   ```

**本周检验标准**：
- [ ] 所有测试用例通过
- [ ] 基准测试完成，结果记录在案
- [ ] `year1_summary.md` 完成
- [ ] `self_assessment.md` 完成
- [ ] 预习材料阅读完成
- [ ] MiniSTL项目可编译运行

---

## 综合项目：MiniSTL

### 项目目标

整合第一年所学，实现一个精简但功能完整的STL子集，包括：

1. **容器**：vector, list, map, unordered_map
2. **内存**：unique_ptr, shared_ptr, weak_ptr, allocator
3. **算法**：sort, find, copy, transform, accumulate等
4. **工具**：function, optional, variant, string_view

### 项目结构

```
ministl/
├── CMakeLists.txt
├── include/
│   └── ministl/
│       ├── memory/
│       │   ├── allocator.hpp
│       │   ├── unique_ptr.hpp
│       │   ├── shared_ptr.hpp
│       │   └── weak_ptr.hpp
│       ├── container/
│       │   ├── vector.hpp
│       │   ├── list.hpp
│       │   ├── map.hpp
│       │   └── unordered_map.hpp
│       ├── algorithm/
│       │   ├── algorithm.hpp
│       │   ├── numeric.hpp
│       │   └── sorting.hpp
│       ├── utility/
│       │   ├── function.hpp
│       │   ├── optional.hpp
│       │   ├── variant.hpp
│       │   └── string_view.hpp
│       ├── iterator/
│       │   ├── iterator_traits.hpp
│       │   └── iterator_adapters.hpp
│       ├── type_traits/
│       │   └── type_traits.hpp
│       └── ministl.hpp  // 统一头文件
├── tests/
│   ├── test_vector.cpp
│   ├── test_map.cpp
│   ├── test_algorithm.cpp
│   └── ...
├── benchmarks/
│   ├── bench_vector.cpp
│   └── bench_sort.cpp
└── examples/
    └── demo.cpp
```

### CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.15)
project(ministl VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# 头文件库
add_library(ministl INTERFACE)
target_include_directories(ministl INTERFACE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

# 编译选项
target_compile_options(ministl INTERFACE
    $<$<CXX_COMPILER_ID:GNU,Clang>:-Wall -Wextra -Wpedantic>
    $<$<CXX_COMPILER_ID:MSVC>:/W4>
)

# 测试
option(MINISTL_BUILD_TESTS "Build tests" ON)
if(MINISTL_BUILD_TESTS)
    enable_testing()
    find_package(GTest QUIET)
    if(GTest_FOUND)
        add_subdirectory(tests)
    else()
        message(STATUS "GTest not found, skipping tests")
    endif()
endif()

# 基准测试
option(MINISTL_BUILD_BENCHMARKS "Build benchmarks" OFF)
if(MINISTL_BUILD_BENCHMARKS)
    find_package(benchmark QUIET)
    if(benchmark_FOUND)
        add_subdirectory(benchmarks)
    endif()
endif()

# 示例
option(MINISTL_BUILD_EXAMPLES "Build examples" ON)
if(MINISTL_BUILD_EXAMPLES)
    add_subdirectory(examples)
endif()
```

### 核心实现要求

#### 1. ministl::allocator
```cpp
// include/ministl/memory/allocator.hpp
#pragma once
#include <cstddef>
#include <new>
#include <limits>

namespace ministl {

template <typename T>
class allocator {
public:
    using value_type = T;
    using size_type = std::size_t;
    using difference_type = std::ptrdiff_t;
    using propagate_on_container_move_assignment = std::true_type;

    constexpr allocator() noexcept = default;
    constexpr allocator(const allocator&) noexcept = default;

    template <typename U>
    constexpr allocator(const allocator<U>&) noexcept {}

    [[nodiscard]] T* allocate(size_type n) {
        if (n > max_size()) {
            throw std::bad_array_new_length();
        }
        return static_cast<T*>(::operator new(n * sizeof(T)));
    }

    void deallocate(T* p, [[maybe_unused]] size_type n) noexcept {
        ::operator delete(p);
    }

    constexpr size_type max_size() const noexcept {
        return std::numeric_limits<size_type>::max() / sizeof(T);
    }

    template <typename U>
    bool operator==(const allocator<U>&) const noexcept { return true; }

    template <typename U>
    bool operator!=(const allocator<U>&) const noexcept { return false; }
};

} // namespace ministl
```

#### 2. 统一头文件
```cpp
// include/ministl/ministl.hpp
#pragma once

// Type traits
#include "type_traits/type_traits.hpp"

// Memory
#include "memory/allocator.hpp"
#include "memory/unique_ptr.hpp"
#include "memory/shared_ptr.hpp"
#include "memory/weak_ptr.hpp"

// Iterators
#include "iterator/iterator_traits.hpp"
#include "iterator/iterator_adapters.hpp"

// Containers
#include "container/vector.hpp"
#include "container/list.hpp"
#include "container/map.hpp"
#include "container/unordered_map.hpp"

// Algorithms
#include "algorithm/algorithm.hpp"
#include "algorithm/numeric.hpp"
#include "algorithm/sorting.hpp"

// Utilities
#include "utility/function.hpp"
#include "utility/optional.hpp"
#include "utility/variant.hpp"
#include "utility/string_view.hpp"
```

### 测试框架

```cpp
// tests/test_vector.cpp
#include <gtest/gtest.h>
#include <ministl/container/vector.hpp>
#include <string>

class VectorTest : public ::testing::Test {
protected:
    ministl::vector<int> v;
};

TEST_F(VectorTest, DefaultConstruction) {
    EXPECT_TRUE(v.empty());
    EXPECT_EQ(v.size(), 0);
}

TEST_F(VectorTest, PushBack) {
    for (int i = 0; i < 100; ++i) {
        v.push_back(i);
    }
    EXPECT_EQ(v.size(), 100);
    EXPECT_EQ(v[50], 50);
}

TEST_F(VectorTest, MoveSemantics) {
    ministl::vector<std::string> vs;
    vs.push_back("hello");
    vs.push_back("world");

    ministl::vector<std::string> vs2 = std::move(vs);
    EXPECT_TRUE(vs.empty());
    EXPECT_EQ(vs2.size(), 2);
    EXPECT_EQ(vs2[0], "hello");
}

TEST_F(VectorTest, ExceptionSafety) {
    // 使用可能抛异常的类型测试异常安全
    struct ThrowOnCopy {
        static int count;
        ThrowOnCopy() = default;
        ThrowOnCopy(const ThrowOnCopy&) {
            if (++count > 5) throw std::runtime_error("test");
        }
    };

    ministl::vector<ThrowOnCopy> v;
    ThrowOnCopy::count = 0;

    try {
        for (int i = 0; i < 10; ++i) {
            v.push_back(ThrowOnCopy{});
        }
    } catch (...) {
        // 验证vector处于有效状态
        EXPECT_TRUE(v.size() <= 10);
    }
}
```

### 基准测试

```cpp
// benchmarks/bench_vector.cpp
#include <benchmark/benchmark.h>
#include <ministl/container/vector.hpp>
#include <vector>

static void BM_StdVectorPushBack(benchmark::State& state) {
    for (auto _ : state) {
        std::vector<int> v;
        for (int i = 0; i < state.range(0); ++i) {
            v.push_back(i);
        }
        benchmark::DoNotOptimize(v);
    }
}
BENCHMARK(BM_StdVectorPushBack)->Range(8, 1<<20);

static void BM_MiniVectorPushBack(benchmark::State& state) {
    for (auto _ : state) {
        ministl::vector<int> v;
        for (int i = 0; i < state.range(0); ++i) {
            v.push_back(i);
        }
        benchmark::DoNotOptimize(v);
    }
}
BENCHMARK(BM_MiniVectorPushBack)->Range(8, 1<<20);

BENCHMARK_MAIN();
```

---

## 知识复盘与自测

### 自测问题清单

#### 内存与生命周期
1. [ ] 解释RAII的核心思想
2. [ ] unique_ptr和shared_ptr的内部结构有什么区别？
3. [ ] weak_ptr如何解决循环引用？
4. [ ] make_shared相比直接构造shared_ptr有什么优势和劣势？

#### 模板元编程
5. [ ] 什么是SFINAE？举一个实际应用例子
6. [ ] enable_if的三种使用方式
7. [ ] void_t如何用于检测类型特征？
8. [ ] constexpr和模板元编程的关系是什么？

#### 移动语义
9. [ ] 左值、右值、xvalue、prvalue的区别
10. [ ] std::move做了什么？它真的移动数据吗？
11. [ ] 什么是完美转发？std::forward如何工作？
12. [ ] 为什么移动构造/赋值应该标记noexcept？

#### 容器与算法
13. [ ] std::vector的扩容策略和时间复杂度
14. [ ] 红黑树如何保证平衡？
15. [ ] 哈希表的负载因子对性能有什么影响？
16. [ ] std::sort使用什么算法？为什么？

#### 异常与错误处理
17. [ ] 四种异常安全等级分别是什么？
18. [ ] 如何实现强异常安全保证？
19. [ ] std::expected相比异常有什么优势？

#### 函数对象
20. [ ] Lambda表达式被编译成什么？
21. [ ] std::function如何实现类型擦除？
22. [ ] std::function的性能开销在哪里？

### 编程练习

完成以下练习以验证掌握程度：

1. **实现std::any**：类型擦除容器，可存储任意类型
2. **实现线程安全的单例模式**：使用call_once或静态局部变量
3. **实现LRU Cache**：使用map和list的组合
4. **实现简单的JSON解析器**：结合variant和recursive_wrapper

---

## 第二年学习预览

### Month 13-24: 内存模型与并发编程

第二年将深入学习C++并发编程，这是成为系统级专家的关键：

```
第二年学习大纲
│
├── Month 13-15: C++内存模型
│   ├── 顺序一致性
│   ├── 内存序（memory_order）
│   ├── 原子操作
│   └── 缓存一致性协议
│
├── Month 16-18: 同步原语
│   ├── mutex, lock_guard, unique_lock
│   ├── condition_variable
│   ├── future/promise
│   └── 读写锁
│
├── Month 19-21: 无锁编程
│   ├── CAS操作
│   ├── ABA问题
│   ├── 无锁队列/栈
│   └── 危险指针
│
└── Month 22-24: 并发模式
    ├── 生产者-消费者
    ├── 线程池
    ├── Actor模型
    └── 协程（C++20）
```

### 推荐预习材料

在进入第二年之前，建议预习：

1. **《C++ Concurrency in Action》**前两章
2. **博客**：Preshing on Programming的并发系列
3. **视频**：CppCon "C++ Memory Model" 系列演讲

---

## 本月时间分配（140小时）

| 内容 | 时间 | 占比 |
|------|------|------|
| 知识复盘与自测 | 20小时 | 14% |
| MiniSTL框架搭建 | 20小时 | 14% |
| 容器实现整合 | 35小时 | 25% |
| 算法与工具整合 | 30小时 | 21% |
| 测试与基准 | 25小时 | 18% |
| 文档与总结 | 10小时 | 8% |

---

## 检验标准

### 项目完成标准
- [ ] MiniSTL项目结构完整
- [ ] 所有容器通过基本测试
- [ ] 所有算法通过基本测试
- [ ] 有基准测试对比标准库
- [ ] 代码有适当的注释和文档

### 知识掌握标准
- [ ] 能回答自测问题清单的80%以上
- [ ] 能独立实现任一容器的简化版本
- [ ] 能解释移动语义和完美转发的原理
- [ ] 理解异常安全的重要性和实现方法

### 输出物
1. `ministl/` 完整项目
2. `year1_summary.md` 第一年学习总结
3. `self_assessment.md` 自我评估报告

---

## 结语

恭喜您完成了C++进阶学习的第一年！在这一年中，您：

- 建立了第一性原理的思维方式
- 掌握了调试器作为代码分析工具
- 深入理解了STL核心容器的实现
- 精通了智能指针和RAII模式
- 掌握了模板元编程基础
- 理解了移动语义和完美转发
- 学会了编写异常安全的代码
- 能够实现类型擦除
- 理解了迭代器和算法的设计

这些知识为第二年的并发编程学习打下了坚实基础。在第二年，您将面对更具挑战性的主题——内存模型、原子操作、无锁编程——这些是区分"熟练开发者"和"系统级专家"的关键技能。

**下一步**：休息一周，然后开始Month 13的学习！
