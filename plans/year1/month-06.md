# Month 06: 完美转发与移动语义深度——右值引用的本质

## 本月主题概述

移动语义是C++11最重要的特性之一，它从根本上改变了C++的资源管理方式。本月将深入理解右值引用、移动语义、完美转发的底层原理，分析`std::move`、`std::forward`的实现，并掌握编写移动友好代码的技巧。

---

## 理论学习内容

### 第一周：值类别与右值引用

**学习目标**：彻底理解C++的值类别体系

**阅读材料**：
- [ ] 《Effective Modern C++》Item 23-30
- [ ] CppCon演讲："Understanding Value Categories" by Ben Deane
- [ ] C++标准 [basic.lval] 章节
- [ ] 《C++ Move Semantics - The Complete Guide》第1-3章

**每日学习安排**：

| 天数 | 主题 | 内容 | 练习 |
|------|------|------|------|
| Day 1 | 值类别基础 | lvalue vs rvalue的历史演进 | 判断20个表达式的值类别 |
| Day 2 | 完整值类别体系 | glvalue/rvalue/lvalue/xvalue/prvalue | 绘制值类别决策树 |
| Day 3 | 右值引用基础 | 右值引用的声明和绑定规则 | 编写绑定测试代码 |
| Day 4 | 右值引用深入 | 右值引用变量是左值的理解 | 分析函数参数传递 |
| Day 5 | 临时对象生命周期 | 引用延长生命周期的规则 | 测试各种场景 |
| Day 6 | 值类别与表达式 | 各种表达式的值类别判断 | 完成值类别速查表 |
| Day 7 | 综合复习与练习 | 整合本周知识 | 完成Week1练习项目 |

**核心概念**：

#### 1. 值类别的历史演进

```cpp
// ==================== C++98时代 ====================
// 简单的二分法：左值(lvalue) vs 右值(rvalue)
// 左值：可以取地址，可以出现在赋值左边
// 右值：不能取地址，只能出现在赋值右边

int x = 42;     // x是左值
42;             // 42是右值
x + 1;          // 表达式结果是右值

// ==================== C++11的革命 ====================
// 为了支持移动语义，引入了更精细的分类
// 核心问题：如何区分"可以被移动的"和"不应该被移动的"？

// 两个关键属性：
// 1. 有身份(identity)：可以判断两个表达式是否指向同一实体
// 2. 可移动(movable)：可以安全地窃取其资源

//            expression
//            /        \
//       glvalue      rvalue
//       /     \      /     \
//   lvalue   xvalue      prvalue
//
// glvalue (generalized lvalue): 有身份
// rvalue: 可移动
// lvalue: 有身份，不可移动
// xvalue (expiring value): 有身份，可移动（将亡值）
// prvalue (pure rvalue): 无身份，可移动
```

#### 2. 值类别（Value Categories）完整详解

```cpp
// ==================== lvalue（左值）====================
// 特征：有身份，不可移动（除非显式std::move）
// 判断方法：可以取地址

int x = 42;              // x是lvalue
int& ref = x;            // ref是lvalue
int* ptr = &x;           // ptr是lvalue，*ptr也是lvalue
int arr[10];             // arr是lvalue，arr[0]也是lvalue

// 函数名是lvalue
void func();
auto& f = func;          // OK，函数名可以被引用

// 字符串字面量是lvalue（特例！）
const char* s = "hello"; // "hello"是lvalue，存储在静态区
&"hello";                // OK，可以取地址

// 返回左值引用的函数调用是lvalue
int& getRef();
getRef() = 10;           // OK，getRef()是lvalue

// ==================== prvalue（纯右值）====================
// 特征：无身份，可移动
// 判断方法：不能取地址，是临时的计算结果

42;                      // 整数字面量是prvalue
3.14;                    // 浮点字面量是prvalue
true;                    // 布尔字面量是prvalue
nullptr;                 // nullptr是prvalue

x + 1;                   // 算术表达式结果是prvalue
x > 0;                   // 比较表达式结果是prvalue
&x;                      // 取地址表达式是prvalue（产生一个指针值）

// 返回非引用的函数调用是prvalue
int getValue();
getValue();              // prvalue

// 类型转换产生prvalue
static_cast<double>(x);  // prvalue
(int)3.14;               // prvalue

// lambda表达式是prvalue
auto lambda = [](){};    // lambda本身是prvalue

// this指针是prvalue
class C {
    void f() {
        // this是prvalue
    }
};

// ==================== xvalue（将亡值）====================
// 特征：有身份，可移动
// 是一个已存在对象，但即将被销毁或可以被移动

std::move(x);            // xvalue，x仍存在但表示可以移动它
static_cast<int&&>(x);   // xvalue，强制转换为右值引用

// 返回右值引用的函数调用是xvalue
int&& getRvalueRef();
getRvalueRef();          // xvalue

// 对对象成员的右值引用访问是xvalue
struct S { int m; };
S s;
std::move(s).m;          // xvalue

// 数组下标操作在右值数组上是xvalue
std::move(arr)[0];       // xvalue

// ==================== glvalue和rvalue ====================
// glvalue = lvalue + xvalue（有身份的表达式）
// rvalue = xvalue + prvalue（可移动的表达式）

// 这两个类别主要用于描述行为：
// - glvalue可以多态（通过基类引用/指针访问派生类）
// - rvalue可以绑定到右值引用
```

#### 3. 值类别判断技巧

```cpp
// 快速判断法则：

// 问题1：能取地址吗？
// YES -> 至少是glvalue
// NO  -> 是prvalue

// 问题2：能被移动吗？（能绑定到T&&吗）
// YES -> 是rvalue（xvalue或prvalue）
// NO  -> 是lvalue

// 问题3：有名字吗？
// 有名字 -> lvalue（即使类型是右值引用！）
// 无名字 -> 可能是任何类别

// 常见陷阱
void process(int&& param) {
    // param的类型是int&&（右值引用）
    // 但param这个表达式是lvalue！因为它有名字

    // ❌ 错误理解：param是右值
    // ✓ 正确理解：param是lvalue，它绑定了一个右值

    other(param);              // 传递lvalue
    other(std::move(param));   // 传递xvalue
}

// 值类别决策树
template <typename T>
void classify(T&& x) {
    if constexpr (std::is_lvalue_reference_v<T>) {
        std::cout << "lvalue\n";
    } else {
        std::cout << "rvalue (prvalue or xvalue)\n";
    }
}
```

#### 4. 右值引用详解

```cpp
// ==================== 右值引用的声明 ====================
int&& rref1 = 42;              // OK: 绑定到prvalue
int&& rref2 = std::move(x);    // OK: 绑定到xvalue
// int&& rref3 = x;            // ERROR: 不能绑定到lvalue

// ==================== const左值引用可以绑定任何值 ====================
const int& cref1 = 42;         // OK: 绑定到prvalue
const int& cref2 = x;          // OK: 绑定到lvalue
const int& cref3 = std::move(x); // OK: 绑定到xvalue

// 这就是为什么C++98可以用const&接收临时对象

// ==================== 右值引用变量是左值 ====================
int&& rref = 42;
// rref的类型是int&&
// 但rref作为表达式是lvalue！

int&& another = rref;          // ERROR! rref是lvalue
int&& another = std::move(rref); // OK

// 这是设计上的深思熟虑：
// 一旦给右值一个名字，你可能会多次使用它
// 所以它必须是lvalue，防止意外被移动

// ==================== 右值引用和函数重载 ====================
void foo(int& x)  { std::cout << "lvalue\n"; }
void foo(int&& x) { std::cout << "rvalue\n"; }

int a = 1;
foo(a);              // lvalue
foo(42);             // rvalue
foo(std::move(a));   // rvalue

// 如果只有一个const&版本
void bar(const int& x) { std::cout << "const&\n"; }

bar(a);              // OK
bar(42);             // OK - const&可以绑定临时对象
bar(std::move(a));   // OK - const&可以绑定右值
```

#### 5. 临时对象与生命周期延长

```cpp
// ==================== 引用延长临时对象生命周期 ====================
// 当一个引用绑定到prvalue时，临时对象的生命周期被延长

std::string getString() { return "hello"; }

// 情况1：绑定到const左值引用
const std::string& ref1 = getString();  // 生命周期延长到ref1作用域结束
std::cout << ref1 << '\n';              // OK

// 情况2：绑定到右值引用
std::string&& ref2 = getString();       // 生命周期延长到ref2作用域结束
std::cout << ref2 << '\n';              // OK

// ==================== 生命周期延长不传递 ====================
const std::string& dangerous() {
    return getString();  // ❌ 危险！临时对象在函数返回后销毁
}

// 延长只发生在直接绑定的情况：
struct Wrapper {
    const std::string& ref;
    Wrapper(const std::string& s) : ref(s) {}  // ❌ 不延长
};

Wrapper w(getString());  // 临时对象在语句结束后销毁
std::cout << w.ref;      // 未定义行为！

// ==================== C++17的保证 ====================
// prvalue不会真正创建临时对象直到需要
// 这被称为"保证的复制消除"(guaranteed copy elision)

struct Heavy {
    Heavy() { std::cout << "ctor\n"; }
    Heavy(const Heavy&) { std::cout << "copy\n"; }
    Heavy(Heavy&&) { std::cout << "move\n"; }
};

Heavy makeHeavy() { return Heavy{}; }

// C++17之前：可能调用移动构造
// C++17之后：保证不调用任何构造函数（除了Heavy{}内部的默认构造）
Heavy h = makeHeavy();  // 只输出一次"ctor"

// ==================== 成员访问不延长生命周期 ====================
struct Data {
    std::string name;
};

Data getData() { return {"hello"}; }

// ❌ 危险
const std::string& name = getData().name;  // 临时Data在语句结束后销毁
// name成为悬垂引用

// ✓ 安全
const Data& data = getData();  // Data的生命周期延长
const std::string& name2 = data.name;  // OK
```

#### 6. 值类别与decltype

```cpp
// decltype对于不同值类别返回不同类型

int x = 42;
int& lref = x;
int&& rref = std::move(x);

// 对于变量名（id-expression）：返回声明类型
decltype(x)     // int
decltype(lref)  // int&
decltype(rref)  // int&&

// 对于其他表达式：根据值类别返回
// lvalue  -> T&
// xvalue  -> T&&
// prvalue -> T

decltype((x))           // int& (x加括号变成表达式，是lvalue)
decltype(std::move(x))  // int&& (xvalue)
decltype(42)            // int (prvalue)
decltype(x + 1)         // int (prvalue)

// 实用技巧：判断表达式的值类别
template <typename T>
struct value_category {
    static constexpr const char* value = "prvalue";
};

template <typename T>
struct value_category<T&> {
    static constexpr const char* value = "lvalue";
};

template <typename T>
struct value_category<T&&> {
    static constexpr const char* value = "xvalue";
};

#define VALUE_CAT(expr) value_category<decltype((expr))>::value

// 使用
std::cout << VALUE_CAT(x) << '\n';           // lvalue
std::cout << VALUE_CAT(std::move(x)) << '\n'; // xvalue
std::cout << VALUE_CAT(42) << '\n';          // prvalue
```

**Week 1 练习项目**：

```cpp
// exercises/week1_value_categories.cpp
// 值类别理解验证

#include <iostream>
#include <utility>
#include <string>

// 练习1：实现值类别检测器
template <typename T>
constexpr const char* category_name();

// 练习2：判断以下每个表达式的值类别
void exercise2() {
    int x = 42;
    int& lref = x;
    int&& rref = std::move(x);
    int arr[3] = {1, 2, 3};

    // 判断并验证：
    // x
    // lref
    // rref
    // std::move(x)
    // x + 1
    // ++x
    // x++
    // arr[0]
    // std::move(arr)[0]
    // "hello"
    // std::string("hello")
}

// 练习3：理解右值引用变量是左值
void process(int&& v) {
    // 问题：v是什么值类别？
    // 问题：如何将v以右值形式传递给下一个函数？
}

// 练习4：分析临时对象生命周期
struct Logger {
    std::string name;
    Logger(const char* n) : name(n) { std::cout << name << " created\n"; }
    ~Logger() { std::cout << name << " destroyed\n"; }
};

Logger getLogger() { return Logger("temp"); }

void exercise4() {
    // 分析以下代码的输出顺序
    std::cout << "Before binding\n";
    const Logger& ref = getLogger();
    std::cout << "After binding\n";
    std::cout << "Using: " << ref.name << "\n";
    std::cout << "End of scope\n";
}
```

**本周检验标准**：
- [ ] 能准确判断任意表达式的值类别
- [ ] 理解右值引用变量本身是左值
- [ ] 理解临时对象生命周期延长的规则和限制
- [ ] 能解释为什么需要xvalue这个类别
- [ ] 理解decltype对不同值类别的处理

### 第二周：移动语义的实现

**学习目标**：理解移动构造/赋值的实现原理

**阅读材料**：
- [ ] 《Effective Modern C++》Item 17, 23, 29
- [ ] 《C++ Move Semantics - The Complete Guide》第4-6章
- [ ] CppCon演讲："The Hidden Secrets of Move Semantics" by Nicolai Josuttis

**每日学习安排**：

| 天数 | 主题 | 内容 | 练习 |
|------|------|------|------|
| Day 1 | std::move深度剖析 | move的实现原理、为什么不移动 | 实现mini::move |
| Day 2 | 移动构造函数 | 资源窃取、源对象状态 | 实现String移动构造 |
| Day 3 | 移动赋值运算符 | 自赋值检查、资源释放 | 实现String移动赋值 |
| Day 4 | noexcept详解 | 异常规范、STL要求 | 测试noexcept影响 |
| Day 5 | Rule of Five | 特殊成员函数关系 | 完整实现RAII类 |
| Day 6 | 移动语义陷阱 | 常见错误和最佳实践 | 代码审查练习 |
| Day 7 | 综合项目 | 完成移动友好的Buffer类 | Week2练习项目 |

**核心概念**：

#### 1. std::move的本质——它不移动任何东西！

```cpp
// ==================== std::move的完整实现 ====================
// 位于<utility>头文件中

template <typename T>
constexpr std::remove_reference_t<T>&& move(T&& t) noexcept {
    return static_cast<std::remove_reference_t<T>&&>(t);
}

// 逐步分析：
// 1. T&& t 是转发引用，可以接受任何值类别
// 2. std::remove_reference_t<T> 去掉T的引用
// 3. 最后static_cast转换为右值引用

// 示例推导过程：
int x = 42;

// 调用 std::move(x)
// T 被推导为 int&（因为x是左值）
// T&& = int& && = int&（引用折叠）
// remove_reference_t<int&> = int
// 返回类型：int&&
// 结果：static_cast<int&&>(t)

// ==================== std::move只是一个cast ====================

// 这两行代码完全等价：
std::move(x);
static_cast<int&&>(x);

// std::move的真正作用：
// 告诉编译器"我允许从这个对象移动资源"
// 它只是一个类型转换，不执行任何移动操作
// 真正的移动发生在移动构造/赋值函数中

// ==================== 为什么需要remove_reference？====================

// 如果不去掉引用：
// move(x) 时 T = int&
// T&& = int& && = int&（左值引用！）
// 这样返回的是左值引用，无法触发移动

// 有了remove_reference：
// remove_reference_t<int&> = int
// int&& 是真正的右值引用

// ==================== move后对象的状态 ====================

std::string s = "hello";
std::string s2 = std::move(s);  // s的资源被移动到s2

// s现在处于"有效但未指定"的状态
// - 可以安全销毁
// - 可以赋新值
// - 不应该使用（值是未指定的）

// 标准库的保证：moved-from对象满足类型的不变量
// 对于string：可能是空，可能是任何值，但一定是有效的string

s = "world";  // OK，可以重新赋值
s.clear();    // OK，可以调用任何操作
// std::cout << s.length(); // 可以，但结果未指定
```

#### 2. 移动构造与移动赋值——资源窃取的艺术

```cpp
class String {
    char* data_;
    size_t size_;
    size_t capacity_;

public:
    // ==================== 默认构造 ====================
    String() : data_(nullptr), size_(0), capacity_(0) {}

    // ==================== 拷贝构造：深拷贝 ====================
    String(const String& other)
        : data_(other.size_ ? new char[other.size_ + 1] : nullptr)
        , size_(other.size_)
        , capacity_(other.size_)
    {
        if (data_) {
            std::memcpy(data_, other.data_, size_ + 1);
        }
    }

    // ==================== 移动构造：资源窃取 ====================
    String(String&& other) noexcept
        : data_(other.data_)      // 直接窃取指针
        , size_(other.size_)
        , capacity_(other.capacity_)
    {
        // 将源对象置于有效的空状态
        other.data_ = nullptr;
        other.size_ = 0;
        other.capacity_ = 0;

        // 关键点：
        // 1. 不分配新内存
        // 2. 直接复制指针值
        // 3. 源对象的指针置空，防止double free
    }

    // ==================== 拷贝赋值 ====================
    String& operator=(const String& other) {
        if (this != &other) {
            // 分配新空间
            char* new_data = other.size_ ? new char[other.size_ + 1] : nullptr;
            // 释放旧空间（在新空间分配成功后）
            delete[] data_;
            // 设置新值
            data_ = new_data;
            size_ = other.size_;
            capacity_ = other.size_;
            if (data_) {
                std::memcpy(data_, other.data_, size_ + 1);
            }
        }
        return *this;
    }

    // ==================== 移动赋值 ====================
    String& operator=(String&& other) noexcept {
        if (this != &other) {  // 自赋值检查
            // 释放当前资源
            delete[] data_;

            // 窃取资源
            data_ = other.data_;
            size_ = other.size_;
            capacity_ = other.capacity_;

            // 源对象置于有效空状态
            other.data_ = nullptr;
            other.size_ = 0;
            other.capacity_ = 0;
        }
        return *this;
    }

    // ==================== 析构函数 ====================
    ~String() {
        delete[] data_;  // delete nullptr是安全的
    }
};

// ==================== 移动赋值的优化版本（使用exchange）====================
String& operator=(String&& other) noexcept {
    // std::exchange返回旧值并设置新值
    delete[] std::exchange(data_, std::exchange(other.data_, nullptr));
    size_ = std::exchange(other.size_, 0);
    capacity_ = std::exchange(other.capacity_, 0);
    return *this;
}

// ==================== 移动后源对象的要求 ====================
// 1. 析构函数可以安全调用
// 2. 可以被赋予新值
// 3. 类的不变量仍然成立

// 不良实践：移动后让源对象处于"部分有效"状态
String(String&& other) noexcept {
    data_ = other.data_;
    size_ = other.size_;
    // ❌ 忘记设置other.data_ = nullptr
    // double free风险！
}
```

#### 3. noexcept——性能优化的关键

```cpp
// ==================== 为什么移动操作必须是noexcept？====================

// STL容器需要保证强异常安全（Strong Exception Safety）
// 这意味着：如果操作失败，状态回滚到操作前

// 问题场景：vector扩容
std::vector<String> vec;
vec.reserve(2);
vec.push_back(String("one"));
vec.push_back(String("two"));
vec.push_back(String("three"));  // 触发扩容

// 扩容过程（需要移动所有元素到新空间）：
// 1. 分配新空间
// 2. 移动/拷贝旧元素到新空间
// 3. 销毁旧元素
// 4. 释放旧空间

// 如果步骤2使用移动，并且移动第二个元素时抛异常：
// - 第一个元素已经被移走了（不可恢复）
// - 新空间有一个元素
// - 旧空间有一个moved-from元素和一个完整元素
// → 无法恢复到原始状态！

// ==================== vector的策略 ====================
template <typename T>
void vector<T>::push_back(T&& value) {
    if (size_ == capacity_) {
        // 选择移动还是拷贝
        if constexpr (std::is_nothrow_move_constructible_v<T>) {
            // 移动是noexcept，放心使用移动
            reallocate_with_move();
        } else if constexpr (std::is_copy_constructible_v<T>) {
            // 移动可能抛异常，退回使用拷贝
            reallocate_with_copy();
        } else {
            // 只能移动，承担风险
            reallocate_with_move();
        }
    }
    // ...
}

// ==================== 测试noexcept的影响 ====================
#include <vector>
#include <iostream>

struct NothrowMove {
    NothrowMove() = default;
    NothrowMove(const NothrowMove&) {
        std::cout << "copy\n";
    }
    NothrowMove(NothrowMove&&) noexcept {  // noexcept!
        std::cout << "move\n";
    }
};

struct ThrowMove {
    ThrowMove() = default;
    ThrowMove(const ThrowMove&) {
        std::cout << "copy\n";
    }
    ThrowMove(ThrowMove&&) {  // 没有noexcept
        std::cout << "move\n";
    }
};

void test() {
    std::vector<NothrowMove> v1;
    v1.reserve(2);
    v1.emplace_back();
    v1.emplace_back();
    v1.emplace_back();  // 扩容时会move（输出"move move"）

    std::vector<ThrowMove> v2;
    v2.reserve(2);
    v2.emplace_back();
    v2.emplace_back();
    v2.emplace_back();  // 扩容时会copy（输出"copy copy"）
}

// ==================== noexcept的条件性 ====================
template <typename T>
class Wrapper {
    T value_;
public:
    // 条件noexcept：当且仅当T的移动构造是noexcept时
    Wrapper(Wrapper&& other) noexcept(std::is_nothrow_move_constructible_v<T>)
        : value_(std::move(other.value_)) {}
};

// 使用noexcept运算符检查
static_assert(noexcept(NothrowMove(std::declval<NothrowMove>())));
static_assert(!noexcept(ThrowMove(std::declval<ThrowMove>())));
```

#### 4. Rule of Five（五之法则）

```cpp
// ==================== 特殊成员函数 ====================
// 1. 析构函数
// 2. 拷贝构造函数
// 3. 拷贝赋值运算符
// 4. 移动构造函数
// 5. 移动赋值运算符

// Rule of Five：如果你定义了其中一个，通常需要定义全部五个

// ==================== 编译器自动生成规则 ====================

// 析构函数：
// - 默认生成（除非基类析构是deleted）

// 拷贝构造：
// - 如果没有声明移动操作，会默认生成
// - 如果声明了移动操作，不会默认生成

// 拷贝赋值：
// - 如果没有声明移动操作，会默认生成
// - 如果声明了移动操作，不会默认生成

// 移动构造：
// - 如果没有声明拷贝操作、移动操作、析构函数，会默认生成
// - 否则不会生成

// 移动赋值：
// - 如果没有声明拷贝操作、移动操作、析构函数，会默认生成
// - 否则不会生成

// ==================== 完整的RAII类示例 ====================
class Resource {
    int* data_;
    size_t size_;

public:
    // 构造函数
    explicit Resource(size_t n)
        : data_(n > 0 ? new int[n] : nullptr)
        , size_(n) {}

    // 析构函数
    ~Resource() {
        delete[] data_;
    }

    // 拷贝构造
    Resource(const Resource& other)
        : data_(other.size_ > 0 ? new int[other.size_] : nullptr)
        , size_(other.size_)
    {
        std::copy(other.data_, other.data_ + size_, data_);
    }

    // 拷贝赋值
    Resource& operator=(const Resource& other) {
        if (this != &other) {
            Resource temp(other);  // 拷贝构造临时对象
            swap(*this, temp);     // 交换资源
        }  // temp析构，释放旧资源
        return *this;
    }

    // 移动构造
    Resource(Resource&& other) noexcept
        : data_(std::exchange(other.data_, nullptr))
        , size_(std::exchange(other.size_, 0)) {}

    // 移动赋值
    Resource& operator=(Resource&& other) noexcept {
        if (this != &other) {
            delete[] data_;
            data_ = std::exchange(other.data_, nullptr);
            size_ = std::exchange(other.size_, 0);
        }
        return *this;
    }

    // swap（ADL友元）
    friend void swap(Resource& a, Resource& b) noexcept {
        using std::swap;
        swap(a.data_, b.data_);
        swap(a.size_, b.size_);
    }

    // 访问器
    size_t size() const noexcept { return size_; }
    int* data() noexcept { return data_; }
    const int* data() const noexcept { return data_; }
};

// ==================== Rule of Zero ====================
// 如果你的类只使用RAII成员（如智能指针、容器），
// 则不需要定义任何特殊成员函数

class ModernResource {
    std::unique_ptr<int[]> data_;
    size_t size_;

public:
    explicit ModernResource(size_t n)
        : data_(n > 0 ? std::make_unique<int[]>(n) : nullptr)
        , size_(n) {}

    // 不需要定义任何特殊成员函数！
    // 编译器生成的版本完全正确

    // unique_ptr不可拷贝，所以这个类也不可拷贝
    // unique_ptr可移动，所以这个类也可移动
};
```

#### 5. 移动语义的常见陷阱

```cpp
// ==================== 陷阱1：对const对象调用move ====================
const std::string s = "hello";
std::string s2 = std::move(s);  // 调用拷贝构造，不是移动！

// 原因：std::move(s)返回const std::string&&
// const右值引用不能绑定到非const右值引用参数
// 所以选择了拷贝构造函数

// ==================== 陷阱2：move后继续使用对象 ====================
std::vector<int> v1 = {1, 2, 3};
std::vector<int> v2 = std::move(v1);

// ❌ 危险：v1的状态未指定
for (int x : v1) { }  // 可能崩溃，可能空循环

// ✓ 正确：如果需要继续使用，先重新赋值
v1 = {4, 5, 6};

// ==================== 陷阱3：返回局部变量时使用move ====================
std::string bad_func() {
    std::string s = "hello";
    return std::move(s);  // ❌ 阻止了RVO/NRVO！
}

std::string good_func() {
    std::string s = "hello";
    return s;  // ✓ 编译器会自动应用RVO或移动
}

// ==================== 陷阱4：move成员变量 ====================
class Container {
    std::string name_;
public:
    // ❌ 危险：多次调用会导致name_被清空
    std::string getName() {
        return std::move(name_);
    }

    // ✓ 正确：根据值类别决定
    std::string getName() const & {
        return name_;  // 拷贝
    }
    std::string getName() && {
        return std::move(name_);  // 移动
    }
};

// ==================== 陷阱5：基类的移动 ====================
class Base {
public:
    Base(Base&&) = default;
};

class Derived : public Base {
    std::string data_;
public:
    // ❌ 错误：基类没有被移动
    Derived(Derived&& other)
        : data_(std::move(other.data_)) {}

    // ✓ 正确：显式移动基类
    Derived(Derived&& other)
        : Base(std::move(other))  // 移动基类
        , data_(std::move(other.data_)) {}
};

// ==================== 陷阱6：自移动 ====================
std::string& get_string();

void process() {
    // 可能发生自移动
    get_string() = std::move(get_string());

    // 标准库类型保证自移动安全
    // 但自定义类型需要显式处理
}

class SafeMove {
    int* data_;
public:
    SafeMove& operator=(SafeMove&& other) noexcept {
        // 检查自移动
        if (this != &other) {
            delete[] data_;
            data_ = std::exchange(other.data_, nullptr);
        }
        return *this;
    }
};
```

**Week 2 练习项目**：

```cpp
// exercises/week2_move_semantics.cpp
// 移动语义综合练习

#include <iostream>
#include <utility>
#include <cstring>

// 练习1：实现一个完整的Buffer类，满足Rule of Five
class Buffer {
    char* data_;
    size_t size_;

public:
    // 实现所有特殊成员函数
    // 要求：移动操作必须是noexcept
};

// 练习2：验证noexcept对vector扩容的影响
// 创建两个版本的类，一个移动是noexcept，一个不是
// 观察vector扩容时的行为差异

// 练习3：实现std::exchange
namespace mini {
    template <typename T, typename U = T>
    constexpr T exchange(T& obj, U&& new_value);
}

// 练习4：分析以下代码的问题
class Problematic {
    std::unique_ptr<int> ptr_;
public:
    Problematic(Problematic&& other) {
        ptr_ = std::move(other.ptr_);
    }
    // 问题在哪里？如何修复？
};

// 练习5：实现移动感知的swap
template <typename T>
void smart_swap(T& a, T& b) noexcept(/* 条件 */);
```

**本周检验标准**：
- [ ] 能完整解释std::move的实现原理
- [ ] 能正确实现移动构造和移动赋值
- [ ] 理解noexcept对STL容器的影响
- [ ] 掌握Rule of Five和Rule of Zero
- [ ] 能识别和避免移动语义的常见陷阱

### 第三周：完美转发

**学习目标**：理解完美转发的原理和std::forward的实现

**阅读材料**：
- [ ] 《Effective Modern C++》Item 24-26, 30
- [ ] 《C++ Move Semantics - The Complete Guide》第7-9章
- [ ] CppCon演讲："Back to Basics: Move Semantics" by Klaus Iglberger

**每日学习安排**：

| 天数 | 主题 | 内容 | 练习 |
|------|------|------|------|
| Day 1 | 转发引用识别 | 万能引用的定义和识别规则 | 判断20个函数签名 |
| Day 2 | 引用折叠完整规则 | 四种折叠情况、编译器推导 | 手动推导模板实例化 |
| Day 3 | std::forward剖析 | 两个重载的作用和原理 | 实现mini::forward |
| Day 4 | 完美转发应用 | 工厂函数、emplace实现 | 实现make_unique |
| Day 5 | 完美转发陷阱 | 常见错误和边界情况 | 调试转发问题 |
| Day 6 | 高级转发模式 | 可变参数转发、成员转发 | 实现通用包装器 |
| Day 7 | 综合项目 | 完成转发工具库 | Week3练习项目 |

**核心概念**：

#### 1. 转发引用（万能引用）——精确识别

```cpp
// ==================== 转发引用的定义 ====================
// 必须满足两个条件：
// 1. 形式必须是 T&&（精确的T&&，不能有const/volatile）
// 2. T必须是被推导的类型

// ✓ 转发引用
template <typename T>
void f(T&& param);  // T是推导类型

auto&& x = expr;    // auto是推导类型

template <typename T>
class Container {
public:
    template <typename U>
    void push(U&& value);  // U是推导类型
};

// ✗ 不是转发引用
void g(int&& param);           // int不是推导类型

template <typename T>
void h(std::vector<T>&& v);    // 整体是vector<T>&&，不是T&&

template <typename T>
void k(const T&& param);       // 有const修饰

template <typename T>
class Widget {
public:
    void process(T&& param);   // T在类实例化时确定，不是推导的
};
```

#### 2. 引用折叠规则

```cpp
// 编译器内部的引用折叠（只要有左值引用，结果就是左值引用）
// T& &   -> T&
// T& &&  -> T&
// T&& &  -> T&
// T&& && -> T&&

// ==================== 转发引用的推导过程 ====================
template <typename T>
void forward_func(T&& param);

int x = 42;

// 传入左值：T推导为int&，T&& = int& && = int&
forward_func(x);     // param是int&

// 传入右值：T推导为int，T&& = int&&
forward_func(42);    // param是int&&

// 传入xvalue：T推导为int，T&& = int&&
forward_func(std::move(x));  // param是int&&
```

#### 3. std::forward的完整剖析

```cpp
// ==================== std::forward的两个重载 ====================

// 重载1：接受左值
template <typename T>
constexpr T&& forward(std::remove_reference_t<T>& t) noexcept {
    return static_cast<T&&>(t);
}

// 重载2：接受右值
template <typename T>
constexpr T&& forward(std::remove_reference_t<T>&& t) noexcept {
    static_assert(!std::is_lvalue_reference_v<T>,
                  "Cannot forward an rvalue as an lvalue");
    return static_cast<T&&>(t);
}

// ==================== forward的工作原理 ====================
template <typename T>
void wrapper(T&& arg) {
    inner(std::forward<T>(arg));
}

// 接收左值时：T = int&
// std::forward<int&>(arg) -> static_cast<int& &&>(arg) -> int&
// inner接收左值

// 接收右值时：T = int
// std::forward<int>(arg) -> static_cast<int&&>(arg)
// inner接收右值

// ==================== forward vs move ====================
// std::move：无条件转换为右值引用
// std::forward：条件性转换，保持原始值类别

// move返回 remove_reference_t<T>&& （总是右值引用）
// forward返回 T&& （根据T可能是左值或右值引用）
```

#### 4. 完美转发的实际应用

```cpp
// ==================== 工厂函数 ====================
template <typename T, typename... Args>
std::unique_ptr<T> make_unique(Args&&... args) {
    return std::unique_ptr<T>(new T(std::forward<Args>(args)...));
}

// ==================== emplace系列函数 ====================
template <typename T>
class Vector {
public:
    template <typename... Args>
    T& emplace_back(Args&&... args) {
        new (data_ + size_) T(std::forward<Args>(args)...);
        return data_[size_++];
    }
};

// ==================== 通用包装器 ====================
template <typename Callable>
class CallWrapper {
    Callable func_;
public:
    template <typename F>
    CallWrapper(F&& f) : func_(std::forward<F>(f)) {}

    template <typename... Args>
    decltype(auto) operator()(Args&&... args) {
        return func_(std::forward<Args>(args)...);
    }
};
```

#### 5. 完美转发的陷阱

```cpp
// 陷阱1：0和NULL
forward_to_process(0);       // 调用process(int)，不是process(void*)
forward_to_process(nullptr); // 调用process(void*)

// 陷阱2：花括号初始化
f({1, 2, 3});  // 错误！花括号初始化列表没有类型

// 陷阱3：重载函数
forward_func(overloaded);  // 错误！不知道选哪个重载
// 解决：static_cast<void(*)(int)>(overloaded)

// 陷阱4：位域
process(flags.bit_field);  // 错误！位域不能绑定到引用
```

#### 6. 成员函数的完美转发

```cpp
class Widget {
    std::string data_;
public:
    // 根据*this值类别重载
    std::string getData() const & { return data_; }        // 拷贝
    std::string getData() && { return std::move(data_); }  // 移动
};

Widget w;
auto s1 = w.getData();            // 拷贝
auto s2 = Widget().getData();     // 移动
```

**Week 3 练习项目**：

```cpp
// exercises/week3_perfect_forwarding.cpp

// 练习1：实现mini::forward（两个重载）
namespace mini {
    template <typename T>
    constexpr T&& forward(std::remove_reference_t<T>& t) noexcept;
    template <typename T>
    constexpr T&& forward(std::remove_reference_t<T>&& t) noexcept;
}

// 练习2：实现make_shared
template <typename T, typename... Args>
std::shared_ptr<T> my_make_shared(Args&&... args);

// 练习3：判断以下哪些是转发引用
// a) template<typename T> void f(T&& x);           // ✓
// b) template<typename T> void f(const T&& x);     // ✗
// c) template<typename T> void f(vector<T>&& x);   // ✗
// d) auto&& x = expr;                              // ✓

// 练习4：实现通用的invoke包装器
template <typename F, typename... Args>
decltype(auto) my_invoke(F&& f, Args&&... args);
```

**本周检验标准**：
- [ ] 能准确识别转发引用和普通右值引用
- [ ] 理解引用折叠的四条规则
- [ ] 能完整解释std::forward的两个重载
- [ ] 能实现使用完美转发的工厂函数
- [ ] 知道完美转发的常见陷阱和解决方案

### 第四周：高级移动语义模式

**学习目标**：掌握实际工程中的移动语义应用

**阅读材料**：
- [ ] 《Effective Modern C++》Item 25, 41
- [ ] 《C++ Move Semantics - The Complete Guide》第10-12章
- [ ] CppCon演讲："Nothing is Better than Copy or Move" by Roger Orr

**每日学习安排**：

| 天数 | 主题 | 内容 | 练习 |
|------|------|------|------|
| Day 1 | Copy-and-Swap | 统一赋值运算符、异常安全 | 实现Copy-and-Swap类 |
| Day 2 | RVO/NRVO详解 | 返回值优化原理、C++17保证 | 测试各种返回场景 |
| Day 3 | 移动迭代器 | make_move_iterator、应用场景 | 实现批量移动 |
| Day 4 | 移动语义与容器 | vector/map/set中的移动 | 性能对比测试 |
| Day 5 | 移动语义最佳实践 | 何时用移动、sink参数 | 代码重构练习 |
| Day 6 | 移动语义与多线程 | 线程间资源转移 | 实现线程安全队列 |
| Day 7 | 综合项目 | 完成高性能字符串类 | Week4练习项目 |

**核心概念**：

#### 1. Copy-and-Swap惯用法

```cpp
// ==================== 经典实现 ====================
class Resource {
    int* data_;
    size_t size_;

public:
    Resource(size_t n) : data_(new int[n]), size_(n) {}
    ~Resource() { delete[] data_; }

    // 拷贝构造
    Resource(const Resource& other)
        : data_(new int[other.size_]), size_(other.size_) {
        std::copy(other.data_, other.data_ + size_, data_);
    }

    // 移动构造
    Resource(Resource&& other) noexcept
        : data_(other.data_), size_(other.size_) {
        other.data_ = nullptr;
        other.size_ = 0;
    }

    // 统一赋值运算符（Copy-and-Swap）
    Resource& operator=(Resource other) noexcept {  // 按值传递！
        swap(*this, other);
        return *this;
    }  // other析构，释放旧资源

    friend void swap(Resource& a, Resource& b) noexcept {
        using std::swap;
        swap(a.data_, b.data_);
        swap(a.size_, b.size_);
    }
};

// ==================== 工作原理 ====================
Resource r1(10), r2(20);

// 拷贝赋值：r1 = r2
// 1. other通过拷贝构造从r2创建
// 2. swap交换r1和other的内容
// 3. other析构，释放r1的旧资源

// 移动赋值：r1 = std::move(r2)
// 1. other通过移动构造从r2创建（高效）
// 2. swap交换r1和other的内容
// 3. other析构

// ==================== 优缺点 ====================
// 优点：
// - 代码简洁，一个函数处理拷贝和移动赋值
// - 自动异常安全（如果拷贝构造抛异常，原对象不变）
// - 自动处理自赋值

// 缺点：
// - 移动赋值不是最优的（多一次swap）
// - 总是需要构造临时对象
```

#### 2. 返回值优化（RVO/NRVO）

```cpp
// ==================== RVO (Return Value Optimization) ====================
// 返回临时对象时，直接在调用者的内存中构造

std::string makeString() {
    return std::string("hello");  // RVO：直接在调用者空间构造
}

// ==================== NRVO (Named RVO) ====================
// 返回命名的局部变量时的优化

std::string good() {
    std::string s = "hello";
    // ... 使用s
    return s;  // NRVO：可能省略拷贝/移动
}

// ==================== 不要对返回值使用std::move！====================

std::string bad() {
    std::string s = "hello";
    return std::move(s);  // ❌ 阻止了NRVO！
}

// 原因：
// 1. std::move(s)的类型是std::string&&，不是std::string
// 2. 编译器无法应用NRVO
// 3. 必须调用移动构造

// ==================== C++17的保证 ====================
// C++17保证某些情况下必须省略拷贝/移动（mandatory elision）

struct NonCopyable {
    NonCopyable() = default;
    NonCopyable(const NonCopyable&) = delete;
    NonCopyable(NonCopyable&&) = delete;
};

NonCopyable make() {
    return NonCopyable{};  // C++17: OK，保证不调用拷贝/移动
}
NonCopyable obj = make();  // C++17: OK

// ==================== 何时使用std::move返回 ====================

// 1. 返回成员变量（右值限定的成员函数）
class Container {
    std::string data_;
public:
    std::string getData() && {
        return std::move(data_);  // OK：移动成员
    }
};

// 2. 返回右值引用参数
std::string process(std::string&& s) {
    // ... 处理s
    return std::move(s);  // OK：s不是局部变量
}

// 3. 返回unique_ptr（允许隐式转换为基类指针）
std::unique_ptr<Base> create() {
    auto p = std::make_unique<Derived>();
    return p;  // OK：隐式移动，不需要std::move
}
```

#### 3. 移动迭代器

```cpp
// ==================== std::make_move_iterator ====================

std::vector<std::string> source = {"a", "b", "c"};
std::vector<std::string> dest;

// 使用移动迭代器，元素被移动而不是拷贝
dest.insert(dest.end(),
    std::make_move_iterator(source.begin()),
    std::make_move_iterator(source.end()));

// source中的元素现在处于moved-from状态

// ==================== 移动迭代器的实现原理 ====================

template <typename Iterator>
class move_iterator {
    Iterator current_;
public:
    using reference = std::iter_rvalue_reference_t<Iterator>;

    reference operator*() const {
        return std::move(*current_);  // 解引用时返回右值引用
    }
    // ...
};

// ==================== 应用场景 ====================

// 场景1：合并vector
std::vector<std::string> merge(std::vector<std::string> a,
                                std::vector<std::string> b) {
    a.insert(a.end(),
        std::make_move_iterator(b.begin()),
        std::make_move_iterator(b.end()));
    return a;
}

// 场景2：从一个容器转移到另一个
std::vector<std::unique_ptr<int>> v1;
v1.push_back(std::make_unique<int>(1));
v1.push_back(std::make_unique<int>(2));

std::vector<std::unique_ptr<int>> v2(
    std::make_move_iterator(v1.begin()),
    std::make_move_iterator(v1.end()));
// v1中的指针现在是nullptr

// ==================== 注意事项 ====================
// 移动后source容器的元素处于有效但未指定状态
// 不要对需要保持有效的源使用移动迭代器
```

#### 4. 移动语义与容器

```cpp
// ==================== vector中的移动 ====================

std::vector<std::string> v;

// push_back有两个重载
v.push_back("hello");           // const&版本，拷贝
v.push_back(std::string("hi")); // &&版本，移动

// emplace_back更高效
v.emplace_back("world");  // 原地构造，无拷贝无移动

// ==================== map中的移动 ====================

std::map<int, std::string> m;

// insert的移动版本
m.insert({1, "one"});  // pair被移动

// 更高效：emplace
m.emplace(2, "two");   // 原地构造pair

// C++17: try_emplace（只在key不存在时构造value）
m.try_emplace(3, "three");

// ==================== 移动语义与异常安全 ====================

// vector扩容时的行为
struct MayThrow {
    MayThrow(MayThrow&&) { /* 可能抛异常 */ }
};

std::vector<MayThrow> v;
// 扩容时使用拷贝而非移动（如果有拷贝构造）

struct WontThrow {
    WontThrow(WontThrow&&) noexcept {}
};

std::vector<WontThrow> v2;
// 扩容时使用移动

// ==================== 性能对比 ====================

void benchmark() {
    const int N = 100000;
    std::vector<std::string> source(N, std::string(100, 'x'));

    // 拷贝方式
    auto t1 = now();
    std::vector<std::string> dest1(source);
    auto t2 = now();

    // 移动方式
    std::vector<std::string> source2(N, std::string(100, 'x'));
    auto t3 = now();
    std::vector<std::string> dest2(std::move(source2));
    auto t4 = now();

    // 移动通常快几个数量级
}
```

#### 5. 移动语义最佳实践

```cpp
// ==================== sink参数（消费参数）====================

// 传统方式：const引用 + 内部拷贝
class Widget1 {
    std::string name_;
public:
    void setName(const std::string& name) {
        name_ = name;  // 总是拷贝
    }
};

// C++11方式：两个重载
class Widget2 {
    std::string name_;
public:
    void setName(const std::string& name) { name_ = name; }
    void setName(std::string&& name) { name_ = std::move(name); }
};

// 现代方式：按值传递
class Widget3 {
    std::string name_;
public:
    void setName(std::string name) {  // 按值
        name_ = std::move(name);
    }
};
// 调用者传左值：拷贝+移动
// 调用者传右值：移动+移动

// ==================== 何时按值传递 ====================

// 规则：当函数总是需要拥有参数的副本时，按值传递

void sink_func(std::string s) {  // 按值，调用者决定拷贝或移动
    // 使用s
}

void maybe_use_func(const std::string& s) {  // 引用，可能不需要副本
    if (condition) {
        auto copy = s;  // 只在需要时拷贝
    }
}

// ==================== 返回值策略 ====================

// 返回局部变量：直接return，不用std::move
std::string create() {
    std::string result;
    // ...
    return result;  // RVO或自动移动
}

// 返回成员：根据情况
class Container {
    std::vector<int> data_;
public:
    // 返回引用：调用者可以选择拷贝或绑定
    const std::vector<int>& getData() const & { return data_; }

    // 右值对象：移动返回
    std::vector<int> getData() && { return std::move(data_); }
};
```

**Week 4 练习项目**：

```cpp
// exercises/week4_advanced_move.cpp

// 练习1：实现支持SSO的高性能String类
class OptimizedString {
    static constexpr size_t SSO_SIZE = 15;
    // 小字符串优化实现
};

// 练习2：实现移动感知的对象池
template <typename T>
class ObjectPool {
public:
    T acquire();           // 获取对象（可能移动）
    void release(T obj);   // 归还对象
};

// 练习3：测试RVO/NRVO
// 创建一个计数器类，验证拷贝/移动构造的调用次数

// 练习4：实现线程安全的生产者-消费者队列
template <typename T>
class ThreadSafeQueue {
public:
    void push(T item);     // 移动语义
    T pop();               // 返回值移动
};

// 练习5：性能对比测试
// 比较拷贝vs移动在不同场景下的性能差异
```

**本周检验标准**：
- [ ] 能实现Copy-and-Swap惯用法
- [ ] 理解RVO/NRVO的工作原理和限制
- [ ] 能正确使用移动迭代器
- [ ] 知道何时使用按值传递作为sink参数
- [ ] 能在多线程场景正确使用移动语义

---

## 源码阅读任务

### 深度阅读清单

#### Week 1 源码阅读
- [ ] 值类别相关的类型特征（`<type_traits>`）
  - `std::is_lvalue_reference`
  - `std::is_rvalue_reference`
  - `std::remove_reference`

```cpp
// 阅读重点：理解remove_reference的实现
template <typename T> struct remove_reference { using type = T; };
template <typename T> struct remove_reference<T&> { using type = T; };
template <typename T> struct remove_reference<T&&> { using type = T; };
```

#### Week 2 源码阅读
- [ ] `std::move`实现（GCC: `bits/move.h`）
- [ ] `std::exchange`实现

```cpp
// std::move的完整实现
template <typename T>
constexpr remove_reference_t<T>&& move(T&& t) noexcept {
    return static_cast<remove_reference_t<T>&&>(t);
}

// std::exchange的实现
template <typename T, typename U = T>
constexpr T exchange(T& obj, U&& new_value)
    noexcept(is_nothrow_move_constructible_v<T> &&
             is_nothrow_assignable_v<T&, U>) {
    T old_value = std::move(obj);
    obj = std::forward<U>(new_value);
    return old_value;
}
```

#### Week 3 源码阅读
- [ ] `std::forward`的两个重载实现
- [ ] `std::move_if_noexcept`实现

```cpp
// move_if_noexcept的实现
template <typename T>
constexpr conditional_t<
    !is_nothrow_move_constructible_v<T> && is_copy_constructible_v<T>,
    const T&, T&&>
move_if_noexcept(T& x) noexcept {
    return std::move(x);
}
```

#### Week 4 源码阅读
- [ ] `std::vector`的移动构造和`push_back`中的移动逻辑
- [ ] `std::move_iterator`实现
- [ ] `std::unique_ptr`的移动语义实现

### 源码阅读技巧

```bash
# 使用编译器查看模板实例化
g++ -E -P test.cpp | less

# 使用Compiler Explorer (godbolt.org)
# 可以看到实际生成的汇编代码

# 打印值类别（调试技巧）
template <typename T> void show() {
    std::cout << __PRETTY_FUNCTION__ << std::endl;
}
```

---

## 实践项目

### 项目：实现移动友好的容器和工具

#### Part 1: 实现std::move和std::forward
```cpp
// mini_utility.hpp
#pragma once
#include <type_traits>

namespace mini {

// remove_reference
template <typename T> struct remove_reference { using type = T; };
template <typename T> struct remove_reference<T&> { using type = T; };
template <typename T> struct remove_reference<T&&> { using type = T; };
template <typename T>
using remove_reference_t = typename remove_reference<T>::type;

// move
template <typename T>
constexpr remove_reference_t<T>&& move(T&& t) noexcept {
    return static_cast<remove_reference_t<T>&&>(t);
}

// forward
template <typename T>
constexpr T&& forward(remove_reference_t<T>& t) noexcept {
    return static_cast<T&&>(t);
}

template <typename T>
constexpr T&& forward(remove_reference_t<T>&& t) noexcept {
    static_assert(!std::is_lvalue_reference_v<T>,
                  "Cannot forward an rvalue as an lvalue.");
    return static_cast<T&&>(t);
}

// exchange
template <typename T, typename U = T>
constexpr T exchange(T& obj, U&& new_value)
    noexcept(std::is_nothrow_move_constructible_v<T> &&
             std::is_nothrow_assignable_v<T&, U>) {
    T old_value = mini::move(obj);
    obj = mini::forward<U>(new_value);
    return old_value;
}

// move_if_noexcept
template <typename T>
constexpr std::conditional_t<
    !std::is_nothrow_move_constructible_v<T> &&
     std::is_copy_constructible_v<T>,
    const T&, T&&>
move_if_noexcept(T& x) noexcept {
    return mini::move(x);
}

} // namespace mini
```

#### Part 2: 移动友好的String类
```cpp
// mini_string.hpp
#pragma once
#include <cstring>
#include <utility>
#include <algorithm>

class MiniString {
    char* data_ = nullptr;
    size_t size_ = 0;
    size_t capacity_ = 0;

    static constexpr size_t SSO_CAPACITY = 15;
    char sso_buffer_[SSO_CAPACITY + 1] = {};
    bool using_sso_ = true;

    bool is_sso() const { return using_sso_; }

public:
    // 默认构造
    MiniString() noexcept : using_sso_(true), size_(0) {
        sso_buffer_[0] = '\0';
    }

    // C字符串构造
    MiniString(const char* s) {
        size_t len = std::strlen(s);
        if (len <= SSO_CAPACITY) {
            std::memcpy(sso_buffer_, s, len + 1);
            size_ = len;
            using_sso_ = true;
        } else {
            data_ = new char[len + 1];
            std::memcpy(data_, s, len + 1);
            size_ = len;
            capacity_ = len;
            using_sso_ = false;
        }
    }

    // 拷贝构造
    MiniString(const MiniString& other) {
        if (other.is_sso()) {
            std::memcpy(sso_buffer_, other.sso_buffer_, SSO_CAPACITY + 1);
            size_ = other.size_;
            using_sso_ = true;
        } else {
            data_ = new char[other.capacity_ + 1];
            std::memcpy(data_, other.data_, other.size_ + 1);
            size_ = other.size_;
            capacity_ = other.capacity_;
            using_sso_ = false;
        }
    }

    // 移动构造
    MiniString(MiniString&& other) noexcept {
        if (other.is_sso()) {
            // SSO：必须拷贝（栈上数据无法"窃取"）
            std::memcpy(sso_buffer_, other.sso_buffer_, SSO_CAPACITY + 1);
            size_ = other.size_;
            using_sso_ = true;
        } else {
            // 堆分配：窃取指针
            data_ = other.data_;
            size_ = other.size_;
            capacity_ = other.capacity_;
            using_sso_ = false;

            // 将源对象置于有效的空状态
            other.data_ = nullptr;
            other.size_ = 0;
            other.capacity_ = 0;
            other.using_sso_ = true;
            other.sso_buffer_[0] = '\0';
        }
    }

    // 析构
    ~MiniString() {
        if (!using_sso_) {
            delete[] data_;
        }
    }

    // Copy-and-Swap统一赋值
    MiniString& operator=(MiniString other) noexcept {
        swap(*this, other);
        return *this;
    }

    // swap
    friend void swap(MiniString& a, MiniString& b) noexcept {
        using std::swap;
        swap(a.data_, b.data_);
        swap(a.size_, b.size_);
        swap(a.capacity_, b.capacity_);
        swap(a.using_sso_, b.using_sso_);
        for (size_t i = 0; i <= SSO_CAPACITY; ++i) {
            swap(a.sso_buffer_[i], b.sso_buffer_[i]);
        }
    }

    // 访问
    const char* c_str() const noexcept {
        return using_sso_ ? sso_buffer_ : data_;
    }

    size_t size() const noexcept { return size_; }
    size_t capacity() const noexcept {
        return using_sso_ ? SSO_CAPACITY : capacity_;
    }
    bool empty() const noexcept { return size_ == 0; }

    char& operator[](size_t pos) {
        return using_sso_ ? sso_buffer_[pos] : data_[pos];
    }
    const char& operator[](size_t pos) const {
        return using_sso_ ? sso_buffer_[pos] : data_[pos];
    }

    // 追加
    MiniString& operator+=(const MiniString& other) {
        size_t new_size = size_ + other.size_;
        if (using_sso_ && new_size <= SSO_CAPACITY) {
            std::memcpy(sso_buffer_ + size_, other.c_str(), other.size_ + 1);
            size_ = new_size;
        } else {
            // 需要堆分配
            size_t new_cap = std::max(new_size, capacity_ * 2);
            char* new_data = new char[new_cap + 1];
            std::memcpy(new_data, c_str(), size_);
            std::memcpy(new_data + size_, other.c_str(), other.size_ + 1);

            if (!using_sso_) delete[] data_;

            data_ = new_data;
            size_ = new_size;
            capacity_ = new_cap;
            using_sso_ = false;
        }
        return *this;
    }
};
```

#### Part 3: 完美转发的工厂函数
```cpp
// factory.hpp
#pragma once
#include <memory>
#include <utility>

namespace mini {

// make_unique的实现
template <typename T, typename... Args>
std::unique_ptr<T> make_unique(Args&&... args) {
    return std::unique_ptr<T>(new T(std::forward<Args>(args)...));
}

// 通用工厂函数
template <typename T>
class Factory {
public:
    template <typename... Args>
    static T create(Args&&... args) {
        return T(std::forward<Args>(args)...);
    }

    template <typename... Args>
    static std::unique_ptr<T> create_unique(Args&&... args) {
        return std::make_unique<T>(std::forward<Args>(args)...);
    }

    template <typename... Args>
    static std::shared_ptr<T> create_shared(Args&&... args) {
        return std::make_shared<T>(std::forward<Args>(args)...);
    }
};

// 延迟构造的包装器
template <typename T>
class Lazy {
    alignas(T) unsigned char storage_[sizeof(T)];
    bool initialized_ = false;

public:
    Lazy() = default;

    ~Lazy() {
        if (initialized_) {
            reinterpret_cast<T*>(storage_)->~T();
        }
    }

    template <typename... Args>
    T& emplace(Args&&... args) {
        if (initialized_) {
            reinterpret_cast<T*>(storage_)->~T();
        }
        new (storage_) T(std::forward<Args>(args)...);
        initialized_ = true;
        return *reinterpret_cast<T*>(storage_);
    }

    T& get() {
        if (!initialized_) {
            throw std::runtime_error("Lazy not initialized");
        }
        return *reinterpret_cast<T*>(storage_);
    }

    bool has_value() const { return initialized_; }
};

} // namespace mini
```

---

## 检验标准

### 知识检验
- [ ] 解释lvalue、prvalue、xvalue、glvalue、rvalue的区别
- [ ] std::move做了什么？它真的移动了数据吗？
- [ ] 什么是转发引用？如何识别？
- [ ] 引用折叠规则是什么？
- [ ] 为什么不应该对返回的局部变量使用std::move？

### 实践检验
- [ ] 实现的std::move和std::forward与标准行为一致
- [ ] MiniString正确处理SSO和移动语义
- [ ] 工厂函数能正确转发所有参数类型
- [ ] Lazy类正确实现延迟构造

### 输出物
1. `mini_utility.hpp`
2. `mini_string.hpp`
3. `factory.hpp`
4. `test_move_semantics.cpp`
5. `notes/month06_move_semantics.md`

---

## 时间分配（140小时/月）

| 内容 | 时间 | 占比 |
|------|------|------|
| 理论学习 | 35小时 | 25% |
| 源码阅读 | 25小时 | 18% |
| mini_utility实现 | 20小时 | 14% |
| MiniString实现 | 30小时 | 21% |
| 工厂与测试 | 30小时 | 22% |

---

## 下月预告

Month 07将进入**异常安全与错误处理**，学习异常的底层实现、异常安全等级、std::expected（C++23）等现代错误处理方式。
