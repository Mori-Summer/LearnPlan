# Month 08: 函数对象与Lambda深度——可调用对象的本质

## 本月主题概述

Lambda表达式是现代C++最强大的特性之一，它本质上是编译器生成的函数对象。本月将深入理解lambda的底层实现、std::function的类型擦除机制，以及函数式编程在C++中的应用。

**核心学习目标**：
- 深刻理解可调用对象的统一模型
- 掌握Lambda表达式的编译器实现机制
- 理解并实现std::function的类型擦除
- 能够运用函数式编程范式解决实际问题

---

## 第一周：函数对象基础——可调用对象的统一模型

### 学习目标

理解C++中所有可调用对象的本质，掌握std::invoke的统一调用机制，能够设计高效的函数对象。

### 每日学习计划

#### Day 1-2: 可调用对象的五种类型

**学习时间**: 10小时

**阅读材料**：
- [ ] 《Effective Modern C++》Item 31: 避免默认捕获模式
- [ ] cppreference: Callable concept
- [ ] 博客: "Understanding C++ Callables"

**核心概念详解**：

##### 1. 普通函数与函数指针

```cpp
// 普通函数：最基本的可调用对象
int add(int a, int b) { return a + b; }

// 函数指针：存储函数地址
// 类型声明解读：返回int，接受两个int参数的函数指针
int (*fp)(int, int) = add;
// 或使用更清晰的别名
using BinaryOp = int(*)(int, int);
BinaryOp fp2 = add;

// 调用方式
int r1 = add(1, 2);      // 直接调用
int r2 = fp(1, 2);       // 通过指针调用
int r3 = (*fp)(1, 2);    // 显式解引用（等价）

// 函数指针的数组
BinaryOp operations[] = {add, subtract, multiply};
for (auto op : operations) {
    std::cout << op(10, 5) << '\n';
}
```

**深度解析：函数到函数指针的隐式转换**
```cpp
// 函数名在大多数上下文中会衰减（decay）为函数指针
void foo() {}

void (*p1)() = foo;   // 隐式转换：函数 -> 函数指针
void (*p2)() = &foo;  // 显式取地址：效果相同

// 但在某些上下文中不会衰减
void (&ref)() = foo;  // 函数引用
decltype(foo) f;      // 声明一个函数（不能这样定义）
```

##### 2. 成员函数指针

```cpp
struct Calculator {
    int value = 0;

    int add(int x) { return value += x; }
    int multiply(int x) const { return value * x; }
    static int square(int x) { return x * x; }
};

// 非静态成员函数指针
// 语法：返回类型 (类名::*指针名)(参数列表) [const]
int (Calculator::*addPtr)(int) = &Calculator::add;
int (Calculator::*mulPtr)(int) const = &Calculator::multiply;

// 调用成员函数指针：必须通过对象
Calculator calc;
calc.value = 10;

// 方式1：对象 .* 成员指针
int r1 = (calc.*addPtr)(5);     // calc.add(5), value变为15

// 方式2：指针 ->* 成员指针
Calculator* pCalc = &calc;
int r2 = (pCalc->*mulPtr)(3);   // calc.multiply(3), 返回45

// 静态成员函数：普通函数指针即可
int (*sqPtr)(int) = &Calculator::square;
int r3 = sqPtr(4);  // 16
```

**深度解析：为什么成员函数指针这么奇怪？**
```cpp
// 成员函数需要this指针，所以不能用普通函数指针
// 成员函数指针实际上不只是一个地址！

// 在有虚函数或多继承的情况下，成员函数指针可能包含：
// 1. 函数地址或虚表偏移
// 2. this指针调整值
// 这就是为什么sizeof成员函数指针通常 > sizeof普通指针

struct Base1 { virtual void f() {} };
struct Base2 { virtual void g() {} };
struct Derived : Base1, Base2 {};

std::cout << sizeof(void(*)()) << '\n';           // 通常8字节
std::cout << sizeof(void(Derived::*)()) << '\n';  // 可能16字节或更多
```

##### 3. 函数对象（仿函数）

```cpp
// 函数对象：重载了operator()的类
struct Adder {
    int base;  // 可以携带状态

    explicit Adder(int b = 0) : base(b) {}

    // operator()使对象可以像函数一样被调用
    int operator()(int x) const {
        return base + x;
    }

    // 可以有多个重载
    int operator()(int x, int y) const {
        return base + x + y;
    }
};

Adder add5(5);
int r1 = add5(10);     // 15，看起来像函数调用
int r2 = add5(10, 20); // 35，调用不同重载

// 函数对象可以有自己的类型
Adder a1(1), a2(2);
// a1和a2类型相同（都是Adder），但状态不同
```

**深度解析：为什么函数对象优于函数指针？**
```cpp
#include <algorithm>
#include <vector>

// 函数指针版本
bool compare_ptr(int a, int b) { return a < b; }

// 函数对象版本
struct Compare {
    bool operator()(int a, int b) const { return a < b; }
};

// 性能对比
std::vector<int> v = {3, 1, 4, 1, 5, 9, 2, 6};

// 使用函数指针：不能内联，有间接调用开销
std::sort(v.begin(), v.end(), compare_ptr);

// 使用函数对象：编译器可以内联operator()
std::sort(v.begin(), v.end(), Compare{});

// 原因：
// 1. 函数指针是运行时值，编译器不知道它指向哪个函数
// 2. 函数对象的类型决定了operator()的实现，编译器可以直接内联

// 在std::sort这样大量调用比较函数的场景下
// 函数对象版本可能快2-3倍！
```

##### 4. std::invoke 统一调用

```cpp
#include <functional>

int add(int a, int b) { return a + b; }

struct Foo {
    int value = 42;
    int getValue() const { return value; }
    int add(int x) { return value += x; }
};

// std::invoke可以统一调用所有可调用对象
int r1 = std::invoke(add, 1, 2);              // 普通函数

int (*fp)(int, int) = add;
int r2 = std::invoke(fp, 1, 2);               // 函数指针

Foo foo;
int r3 = std::invoke(&Foo::getValue, foo);    // 成员函数+对象
int r4 = std::invoke(&Foo::getValue, &foo);   // 成员函数+指针
int r5 = std::invoke(&Foo::value, foo);       // 数据成员！

auto lambda = [](int x) { return x * 2; };
int r6 = std::invoke(lambda, 21);             // Lambda

struct Callable {
    int operator()(int x) const { return x + 1; }
};
int r7 = std::invoke(Callable{}, 99);         // 函数对象
```

**动手练习1**：
```cpp
// 实现一个简化版的invoke
// 提示：需要处理普通函数、成员函数、成员变量三种情况
namespace my {

// 1. 普通可调用对象（函数、lambda、函数对象）
template <typename F, typename... Args>
auto invoke(F&& f, Args&&... args)
    -> decltype(std::forward<F>(f)(std::forward<Args>(args)...))
{
    return std::forward<F>(f)(std::forward<Args>(args)...);
}

// 2. 成员函数 + 对象引用
template <typename R, typename C, typename T, typename... Args>
auto invoke(R C::*pmf, T&& obj, Args&&... args)
    -> decltype((std::forward<T>(obj).*pmf)(std::forward<Args>(args)...))
{
    return (std::forward<T>(obj).*pmf)(std::forward<Args>(args)...);
}

// 3. 成员函数 + 指针
template <typename R, typename C, typename T, typename... Args>
auto invoke(R C::*pmf, T* ptr, Args&&... args)
    -> decltype((ptr->*pmf)(std::forward<Args>(args)...))
{
    return (ptr->*pmf)(std::forward<Args>(args)...);
}

// 4. 数据成员 + 对象/指针 (类似处理)
// ... 完整实现留作练习

}  // namespace my
```

---

#### Day 3-4: 函数对象的设计模式

**学习时间**: 10小时

**核心概念：透明比较器（Transparent Comparators）**

```cpp
#include <set>
#include <string>
#include <string_view>

// 问题：传统比较器导致不必要的临时对象
std::set<std::string> names = {"Alice", "Bob", "Charlie"};

// 查找时，"Bob"被转换为std::string临时对象！
auto it = names.find("Bob");  // const char* -> std::string

// 解决方案：透明比较器（C++14）
struct TransparentCompare {
    // 关键：定义is_transparent类型别名
    using is_transparent = void;

    // 支持异构比较
    bool operator()(const std::string& a, const std::string& b) const {
        return a < b;
    }
    bool operator()(const std::string& a, std::string_view b) const {
        return a < b;
    }
    bool operator()(std::string_view a, const std::string& b) const {
        return a < b;
    }
};

std::set<std::string, TransparentCompare> names2 = {"Alice", "Bob", "Charlie"};
auto it2 = names2.find(std::string_view("Bob"));  // 无临时对象！

// C++14起，标准库提供std::less<>（无模板参数版本）
std::set<std::string, std::less<>> names3 = {"Alice", "Bob", "Charlie"};
auto it3 = names3.find("Bob");  // 自动使用异构查找
```

**核心概念：有状态的函数对象**

```cpp
#include <algorithm>
#include <vector>
#include <iostream>

// 计数器：统计调用次数
struct Counter {
    mutable int count = 0;  // mutable允许const函数修改

    void operator()(int x) const {
        ++count;
        std::cout << x << ' ';
    }
};

std::vector<int> v = {1, 2, 3, 4, 5};

// 注意：std::for_each返回函数对象的副本！
Counter counter;
Counter result = std::for_each(v.begin(), v.end(), counter);
std::cout << "\nOriginal count: " << counter.count << '\n';  // 0！
std::cout << "Result count: " << result.count << '\n';       // 5

// 如何保持状态？使用std::ref
Counter counter2;
std::for_each(v.begin(), v.end(), std::ref(counter2));
std::cout << "Counter2 count: " << counter2.count << '\n';   // 5
```

**核心概念：可配置的函数对象**

```cpp
// 策略模式：通过模板参数配置行为
template <typename Compare = std::less<>>
struct BinarySearch {
    Compare comp;

    template <typename Container, typename T>
    bool operator()(const Container& c, const T& value) const {
        auto it = std::lower_bound(c.begin(), c.end(), value, comp);
        return it != c.end() && !comp(value, *it);
    }
};

std::vector<int> sorted = {1, 3, 5, 7, 9};

BinarySearch<> search;                        // 默认升序
bool found1 = search(sorted, 5);              // true

BinarySearch<std::greater<>> reverse_search;  // 降序
std::vector<int> reverse_sorted = {9, 7, 5, 3, 1};
bool found2 = reverse_search(reverse_sorted, 5);  // true
```

---

#### Day 5-6: std::invoke原理与实现

**学习时间**: 10小时

**std::invoke的完整实现**

```cpp
#include <type_traits>
#include <utility>

namespace detail {

// 检测是否是成员指针
template <typename T>
struct is_member_pointer_helper : std::false_type {};

template <typename T, typename C>
struct is_member_pointer_helper<T C::*> : std::true_type {};

// 情况1：成员函数指针 + 对象/引用/智能指针
template <typename Base, typename T, typename Derived, typename... Args>
auto invoke_impl(T Base::*pmf, Derived&& ref, Args&&... args)
    -> std::enable_if_t<
        std::is_function_v<T> &&
        std::is_base_of_v<Base, std::decay_t<Derived>>,
        decltype((std::forward<Derived>(ref).*pmf)(std::forward<Args>(args)...))
    >
{
    return (std::forward<Derived>(ref).*pmf)(std::forward<Args>(args)...);
}

// 情况2：成员函数指针 + 引用包装器
template <typename Base, typename T, typename RefWrap, typename... Args>
auto invoke_impl(T Base::*pmf, RefWrap&& ref, Args&&... args)
    -> std::enable_if_t<
        std::is_function_v<T> &&
        !std::is_base_of_v<Base, std::decay_t<RefWrap>>,
        decltype((ref.get().*pmf)(std::forward<Args>(args)...))
    >
{
    return (ref.get().*pmf)(std::forward<Args>(args)...);
}

// 情况3：成员函数指针 + 指针
template <typename Base, typename T, typename Ptr, typename... Args>
auto invoke_impl(T Base::*pmf, Ptr&& ptr, Args&&... args)
    -> std::enable_if_t<
        std::is_function_v<T>,
        decltype(((*std::forward<Ptr>(ptr)).*pmf)(std::forward<Args>(args)...))
    >
{
    return ((*std::forward<Ptr>(ptr)).*pmf)(std::forward<Args>(args)...);
}

// 情况4-6：数据成员指针（类似，省略）

// 情况7：普通可调用对象
template <typename F, typename... Args>
auto invoke_impl(F&& f, Args&&... args)
    -> decltype(std::forward<F>(f)(std::forward<Args>(args)...))
{
    return std::forward<F>(f)(std::forward<Args>(args)...);
}

}  // namespace detail

// 公开接口
template <typename F, typename... Args>
auto invoke(F&& f, Args&&... args)
    -> decltype(detail::invoke_impl(std::forward<F>(f), std::forward<Args>(args)...))
{
    return detail::invoke_impl(std::forward<F>(f), std::forward<Args>(args)...);
}
```

**std::invoke_result和std::is_invocable**

```cpp
#include <type_traits>

// 获取调用结果类型
template <typename F, typename... Args>
using invoke_result_t = typename std::invoke_result<F, Args...>::type;

// 检查是否可调用
template <typename F, typename... Args>
constexpr bool is_invocable_v = std::is_invocable<F, Args...>::value;

// 实际使用
auto lambda = [](int x) { return x * 2.5; };

static_assert(is_invocable_v<decltype(lambda), int>);
static_assert(std::is_same_v<invoke_result_t<decltype(lambda), int>, double>);

// 结合SFINAE使用
template <typename F, typename... Args,
          typename = std::enable_if_t<std::is_invocable_v<F, Args...>>>
auto safe_call(F&& f, Args&&... args) {
    return std::invoke(std::forward<F>(f), std::forward<Args>(args)...);
}
```

---

#### Day 7: 周末总结与练习

**学习时间**: 5小时

**本周核心知识点回顾**：

1. **可调用对象的五种类型**：函数、函数指针、成员函数指针、函数对象、Lambda
2. **std::invoke的统一调用**：处理所有可调用对象的通用接口
3. **函数对象的优势**：可内联、携带状态、类型安全
4. **透明比较器**：支持异构查找，避免不必要的类型转换

**综合练习**：

```cpp
// 练习1：实现一个通用的回调管理器
template <typename Signature>
class CallbackManager;

template <typename R, typename... Args>
class CallbackManager<R(Args...)> {
    // TODO: 实现支持注册、注销、调用所有回调
    // 提示：使用std::vector<std::function<R(Args...)>>
};

// 练习2：实现一个带优先级的函数对象队列
// 要求：支持添加、移除、按优先级执行

// 练习3：实现mem_fn
// 要求：将成员函数/成员变量转换为普通可调用对象
template <typename M>
auto my_mem_fn(M m) {
    // TODO
}
```

**常见陷阱**：

1. **成员函数指针需要对象**：不能单独调用成员函数指针
2. **算法可能复制函数对象**：有状态函数对象要小心
3. **函数指针无法内联**：性能敏感场景用函数对象
4. **忘记成员函数的const**：const成员函数需要匹配const指针

**自测问题**：

1. 为什么`std::sort`使用函数对象比函数指针快？
2. 成员函数指针的大小为什么可能比普通指针大？
3. 什么是透明比较器？它解决什么问题？
4. `std::invoke`如何区分处理不同类型的可调用对象？

---

## 第二周：Lambda表达式深度——编译器实现机制

### 学习目标

深入理解Lambda表达式的编译器转换过程，掌握各种捕获方式的内存模型，能够正确处理Lambda的生命周期问题。

### 每日学习计划

#### Day 1-2: Lambda的本质——编译器转换

**学习时间**: 10小时

**阅读材料**：
- [ ] 《Effective Modern C++》Item 31-34
- [ ] CppCon演讲："Back to Basics: Lambdas" by Barbara Geller & Ansel Sermersheim
- [ ] 博客：Lambda Under the Hood

**Lambda表达式完整解剖**

```cpp
// 一个完整的Lambda表达式
int x = 10;
int y = 20;
auto lambda = [x, &y](int a, int b) mutable noexcept -> int {
    x += a;  // 修改捕获的x副本（因为mutable）
    y += b;  // 修改原始y（引用捕获）
    return x + y;
};

// 编译器生成的等价代码（概念性，非精确）
class __lambda_line42_col15 {
private:
    int __x;      // 值捕获：存储副本
    int& __y;     // 引用捕获：存储引用

public:
    // 构造函数：初始化捕获
    __lambda_line42_col15(int x, int& y)
        : __x(x), __y(y) {}

    // operator()：Lambda体
    // mutable移除const
    // noexcept传递
    // -> int 指定返回类型
    int operator()(int a, int b) noexcept {
        __x += a;
        __y += b;
        return __x + __y;
    }

    // Lambda默认不可复制赋值（有引用成员时）
    __lambda_line42_col15& operator=(const __lambda_line42_col15&) = delete;
};

auto lambda = __lambda_line42_col15(x, y);
```

**深度解析：Lambda的独特类型**

```cpp
// 每个Lambda都有独特的类型，即使结构相同
auto l1 = [](int x) { return x; };
auto l2 = [](int x) { return x; };

// l1和l2类型不同！
static_assert(!std::is_same_v<decltype(l1), decltype(l2)>);

// 这就是为什么不能这样做：
// decltype(l1) l3 = l2;  // 错误：类型不匹配

// 但可以转换为相同的std::function
std::function<int(int)> f1 = l1;
std::function<int(int)> f2 = l2;

// 无捕获Lambda可以转换为函数指针
int (*fp1)(int) = l1;  // OK：无捕获
// int (*fp2)(int) = [x](int y) { return x + y; };  // 错误：有捕获
```

**深度解析：无捕获Lambda到函数指针的转换**

```cpp
// 无捕获Lambda有一个特殊的转换运算符
auto lambda = [](int x) { return x * 2; };

// 等价于：
struct __lambda {
    int operator()(int x) const { return x * 2; }

    // 特殊：转换到函数指针的运算符
    using FuncPtr = int(*)(int);
    operator FuncPtr() const {
        // 返回一个静态函数，行为与Lambda相同
        return [](int x) { return x * 2; };  // 注：这是示意
        // 实际编译器生成一个静态成员函数
    }
};

// 这就是为什么这样可以工作
int (*fp)(int) = lambda;  // 使用转换运算符
int result = fp(21);      // 42
```

---

#### Day 3-4: 捕获方式全解析

**学习时间**: 10小时

**六种捕获方式详解**

```cpp
int a = 1, b = 2, c = 3, d = 4;
std::unique_ptr<int> ptr = std::make_unique<int>(100);

// 1. 值捕获（拷贝）
[a]() {
    // a是外部a的副本
    // 不能修改（operator() 是const）
    return a;  // OK
    // a = 10;  // 错误
};

// 2. 引用捕获
[&a]() {
    a = 10;    // 修改外部a
    return a;
};

// 3. 隐式值捕获（捕获所有使用的变量，按值）
[=]() {
    return a + b + c;  // 捕获a, b, c的副本
};

// 4. 隐式引用捕获
[&]() {
    a = b = c = 0;  // 修改所有
};

// 5. 混合捕获
[=, &a]() {
    // a按引用，其他按值
    a = b + c;  // 修改a，读取b和c的副本
};
[&, a]() {
    // a按值，其他按引用
    b = c = a;  // 修改b和c，读取a的副本
};

// 6. 初始化捕获（C++14）——最灵活
[value = a + b]() {          // 创建新变量
    return value;
};
[p = std::move(ptr)]() {     // 移动捕获
    return *p;
};
[&ref = a]() {               // 引用捕获的别名
    ref = 100;
};
[factor = 2, &sum = a](int x) {  // 混合
    sum += x * factor;
};
```

**深度解析：捕获的内存模型**

```cpp
#include <iostream>

int main() {
    int x = 10;
    int y = 20;

    // 值捕获
    auto by_value = [x, y]() {
        std::cout << "sizeof(lambda) = " << sizeof(*this) << '\n';
        // 存储两个int副本
    };
    std::cout << "by_value size: " << sizeof(by_value) << '\n';  // 8 (两个int)

    // 引用捕获
    auto by_ref = [&x, &y]() {};
    std::cout << "by_ref size: " << sizeof(by_ref) << '\n';  // 16 (两个引用/指针)

    // 无捕获
    auto no_capture = []() {};
    std::cout << "no_capture size: " << sizeof(no_capture) << '\n';  // 1 (空类)

    // 大对象捕获
    std::string str = "Hello, World!";
    auto capture_string = [str]() { return str.size(); };
    std::cout << "capture_string size: " << sizeof(capture_string) << '\n';
    // sizeof(std::string) = 32 (典型实现)
}
```

**深度解析：捕获的生命周期陷阱**

```cpp
#include <functional>
#include <vector>

// 陷阱1：悬垂引用
std::function<int()> dangerous() {
    int local = 42;
    return [&local]() {
        return local;  // 危险！local已销毁
    };
}

// 陷阱2：循环中的引用捕获
std::vector<std::function<int()>> funcs;
for (int i = 0; i < 5; ++i) {
    funcs.push_back([&i]() { return i; });  // 所有lambda引用同一个i！
}
// funcs[0]() == funcs[4]() == 5（循环结束后i的值）

// 正确做法：值捕获或初始化捕获
for (int i = 0; i < 5; ++i) {
    funcs.push_back([i]() { return i; });        // 值捕获：每个Lambda有自己的副本
    // 或
    funcs.push_back([j = i]() { return j; });    // 初始化捕获
}

// 陷阱3：this捕获
class Widget {
    int value = 42;
public:
    auto getLambda() {
        return [this]() { return value; };  // 捕获this指针
        // 如果Widget被销毁，lambda持有悬垂指针！
    }

    auto getSafeLambda() {
        return [*this]() { return value; };  // C++17：拷贝整个对象
        // 或
        return [v = value]() { return v; };  // 只捕获需要的成员
    }
};
```

---

#### Day 5-6: 泛型Lambda与模板Lambda

**学习时间**: 10小时

**泛型Lambda（C++14）**

```cpp
// auto参数 -> 模板化的operator()
auto generic = [](auto x, auto y) {
    return x + y;
};

// 编译器生成：
struct __generic_lambda {
    template <typename T, typename U>
    auto operator()(T x, U y) const {
        return x + y;
    }
};

// 可以用不同类型调用
int i = generic(1, 2);           // T=int, U=int
double d = generic(1.5, 2.5);    // T=double, U=double
std::string s = generic(std::string("Hello"), " World");  // 字符串拼接
```

**泛型Lambda的高级技巧**

```cpp
// 完美转发
auto forward_call = [](auto&& func, auto&&... args) {
    return std::invoke(
        std::forward<decltype(func)>(func),
        std::forward<decltype(args)>(args)...
    );
};

// 递归泛型Lambda（需要一些技巧）
// 方法1：通过参数传递自己
auto factorial = [](auto self, int n) -> int {
    return n <= 1 ? 1 : n * self(self, n - 1);
};
int result = factorial(factorial, 5);  // 120

// 方法2：使用Y组合子（见第四周）

// 方法3：C++23 deducing this
auto factorial_cpp23 = [](this auto self, int n) -> int {
    return n <= 1 ? 1 : n * self(n - 1);  // 直接递归
};
```

**模板Lambda（C++20）**

```cpp
// C++20允许显式模板参数
auto template_lambda = []<typename T>(std::vector<T>& vec) {
    return vec.size();
};

// 编译器生成：
struct __template_lambda {
    template <typename T>
    auto operator()(std::vector<T>& vec) const {
        return vec.size();
    }
};

// 更复杂的约束
auto constrained_lambda = []<typename T>
    requires std::integral<T>
(T x) {
    return x * 2;
};

// 非类型模板参数
auto nttp_lambda = []<int N>() {
    return std::array<int, N>{};
};
auto arr = nttp_lambda.template operator()<5>();  // array<int, 5>

// 实用示例：类型安全的打印
auto print = []<typename T>(const std::vector<T>& v) {
    for (const auto& elem : v) {
        if constexpr (std::is_same_v<T, std::string>) {
            std::cout << '"' << elem << "\" ";
        } else {
            std::cout << elem << ' ';
        }
    }
    std::cout << '\n';
};
```

**Lambda表达式属性（C++20/23）**

```cpp
// constexpr Lambda（C++17默认，C++14需显式）
auto constexpr_lambda = [](int x) constexpr { return x * x; };
constexpr int sq = constexpr_lambda(5);  // 编译期计算

// consteval Lambda（C++20）——只能编译期调用
auto consteval_lambda = [](int x) consteval { return x * x; };
// consteval_lambda(5);  // OK：编译期
// int n = 5; consteval_lambda(n);  // 错误：n不是常量表达式

// noexcept Lambda
auto noexcept_lambda = [](int x) noexcept { return x; };
static_assert(noexcept(noexcept_lambda(1)));

// mutable Lambda
int counter = 0;
auto mutable_lambda = [counter]() mutable {
    return ++counter;  // 可以修改捕获的副本
};
mutable_lambda();  // 返回1
mutable_lambda();  // 返回2
// 原始counter仍然是0
```

---

#### Day 7: 周末总结与练习

**学习时间**: 5小时

**本周核心知识点回顾**：

1. **Lambda本质**：编译器生成的匿名类，重载operator()
2. **捕获机制**：值捕获（拷贝）、引用捕获、初始化捕获
3. **生命周期**：引用捕获可能导致悬垂引用
4. **泛型Lambda**：auto参数生成模板operator()
5. **模板Lambda**：C++20显式模板参数

**综合练习**：

```cpp
// 练习1：实现一个延迟执行器
template <typename F>
class Deferred {
    F func_;
public:
    explicit Deferred(F f) : func_(std::move(f)) {}
    ~Deferred() { func_(); }

    // 禁止复制
    Deferred(const Deferred&) = delete;
    Deferred& operator=(const Deferred&) = delete;
};

// 使用：
{
    auto cleanup = Deferred([&]() {
        std::cout << "Cleaning up...\n";
    });
    // ... 作用域结束时自动执行
}

// 练习2：实现一个简单的观察者模式，使用Lambda作为回调

// 练习3：修复以下代码的生命周期问题
class EventManager {
    std::vector<std::function<void()>> callbacks_;
public:
    void subscribe(std::function<void()> callback) {
        callbacks_.push_back(std::move(callback));
    }
    void notify() {
        for (auto& cb : callbacks_) cb();
    }
};

class Widget {
    int id_;
    EventManager& manager_;
public:
    Widget(int id, EventManager& mgr) : id_(id), manager_(mgr) {
        // 问题：this可能在回调执行前被销毁
        manager_.subscribe([this]() {
            std::cout << "Widget " << id_ << " notified\n";
        });
    }
    // 如何安全地处理这个问题？
};
```

**常见陷阱**：

1. **忘记mutable**：值捕获的变量在非mutable Lambda中不能修改
2. **隐式捕获this**：`[=]`会隐式捕获this指针，不是成员的副本
3. **循环中的引用捕获**：所有Lambda引用同一个循环变量
4. **移动后使用**：`[p = std::move(ptr)]`后，原始ptr为空

**自测问题**：

1. Lambda表达式会被编译器转换成什么？
2. 解释`[=]`和`[&]`的区别，以及各自的风险
3. 为什么无捕获Lambda可以转换为函数指针？
4. `[*this]`和`[this]`有什么区别？
5. 泛型Lambda的auto参数是如何实现的？

---

## 第三周：std::function与类型擦除

### 学习目标

深入理解类型擦除的设计模式，完整实现std::function（含SBO优化），掌握类型擦除的应用场景和性能特点。

### 每日学习计划

#### Day 1-2: 类型擦除概念与动机

**学习时间**: 10小时

**阅读材料**：
- [ ] 《Effective Modern C++》Item 18: 使用unique_ptr管理资源
- [ ] CppCon演讲："Type Erasure" by Klaus Iglberger
- [ ] 博客：Type Erasure in C++

**为什么需要类型擦除？**

```cpp
#include <vector>
#include <memory>

// 问题：不同的可调用对象有不同的类型
auto lambda1 = [](int x) { return x; };
auto lambda2 = [](int x) { return x * 2; };
// decltype(lambda1) != decltype(lambda2)

// 不能直接存储在同一个容器中
// std::vector<???> callbacks;  // 类型是什么？

// 解决方案1：使用模板（编译时多态）
template <typename Callback>
void process(int value, Callback cb) {
    std::cout << cb(value) << '\n';
}
// 问题：不能在容器中存储

// 解决方案2：继承（运行时多态）
struct ICallback {
    virtual int call(int) = 0;
    virtual ~ICallback() = default;
};

template <typename F>
struct CallbackImpl : ICallback {
    F func;
    CallbackImpl(F f) : func(std::move(f)) {}
    int call(int x) override { return func(x); }
};

std::vector<std::unique_ptr<ICallback>> callbacks;
callbacks.push_back(std::make_unique<CallbackImpl<decltype(lambda1)>>(lambda1));
// 问题：需要堆分配，使用不方便

// 解决方案3：类型擦除（std::function）
std::vector<std::function<int(int)>> funcs;
funcs.push_back(lambda1);
funcs.push_back(lambda2);
funcs.push_back([](int x) { return x * 3; });
// 完美！类型统一，使用方便
```

**类型擦除的核心思想**

```cpp
// 类型擦除 = 模板（编译时捕获类型信息）+ 虚函数（运行时多态）

// 模式结构：
// 1. 一个非模板的外部类（如std::function<int(int)>）
// 2. 一个内部的虚基类（定义接口）
// 3. 一个内部的模板派生类（存储具体类型）

// 外部类持有基类指针，通过虚函数调用
// 用户只看到外部类的类型，内部具体类型被"擦除"
```

**简单的类型擦除示例：any_printable**

```cpp
#include <memory>
#include <iostream>

// 可以存储任何可打印对象的容器
class AnyPrintable {
    // 内部接口
    struct Concept {
        virtual void print(std::ostream&) const = 0;
        virtual std::unique_ptr<Concept> clone() const = 0;
        virtual ~Concept() = default;
    };

    // 具体类型的模型
    template <typename T>
    struct Model : Concept {
        T value;
        Model(T v) : value(std::move(v)) {}

        void print(std::ostream& os) const override {
            os << value;
        }

        std::unique_ptr<Concept> clone() const override {
            return std::make_unique<Model>(value);
        }
    };

    std::unique_ptr<Concept> pimpl_;

public:
    template <typename T>
    AnyPrintable(T value)
        : pimpl_(std::make_unique<Model<T>>(std::move(value))) {}

    AnyPrintable(const AnyPrintable& other)
        : pimpl_(other.pimpl_ ? other.pimpl_->clone() : nullptr) {}

    AnyPrintable(AnyPrintable&&) = default;

    friend std::ostream& operator<<(std::ostream& os, const AnyPrintable& ap) {
        if (ap.pimpl_) ap.pimpl_->print(os);
        return os;
    }
};

// 使用
AnyPrintable p1 = 42;
AnyPrintable p2 = "Hello";
AnyPrintable p3 = 3.14;

std::cout << p1 << ", " << p2 << ", " << p3 << '\n';
// 输出: 42, Hello, 3.14
```

---

#### Day 3-4: std::function实现原理

**学习时间**: 10小时

**std::function的完整实现（简化版）**

```cpp
#include <memory>
#include <utility>
#include <stdexcept>
#include <type_traits>

template <typename> class Function;  // 主模板，未定义

// 偏特化：函数类型
template <typename R, typename... Args>
class Function<R(Args...)> {
    // 类型擦除的接口
    struct CallableBase {
        virtual R invoke(Args... args) = 0;
        virtual std::unique_ptr<CallableBase> clone() const = 0;
        virtual ~CallableBase() = default;
    };

    // 实现类：存储具体可调用对象
    template <typename F>
    struct CallableImpl : CallableBase {
        F func_;

        // 使用decay_t确保存储值类型
        template <typename Fn>
        CallableImpl(Fn&& f) : func_(std::forward<Fn>(f)) {}

        R invoke(Args... args) override {
            // 使用std::invoke支持成员函数指针等
            if constexpr (std::is_void_v<R>) {
                std::invoke(func_, std::forward<Args>(args)...);
            } else {
                return std::invoke(func_, std::forward<Args>(args)...);
            }
        }

        std::unique_ptr<CallableBase> clone() const override {
            return std::make_unique<CallableImpl>(func_);
        }
    };

    std::unique_ptr<CallableBase> callable_;

public:
    // 默认构造：空function
    Function() noexcept = default;
    Function(std::nullptr_t) noexcept {}

    // 从可调用对象构造
    template <typename F,
              typename = std::enable_if_t<
                  !std::is_same_v<std::decay_t<F>, Function> &&
                  std::is_invocable_r_v<R, F, Args...>
              >>
    Function(F&& f)
        : callable_(std::make_unique<CallableImpl<std::decay_t<F>>>(
              std::forward<F>(f))) {}

    // 拷贝构造
    Function(const Function& other)
        : callable_(other.callable_ ? other.callable_->clone() : nullptr) {}

    // 移动构造
    Function(Function&& other) noexcept = default;

    // 拷贝赋值
    Function& operator=(const Function& other) {
        if (this != &other) {
            callable_ = other.callable_ ? other.callable_->clone() : nullptr;
        }
        return *this;
    }

    // 移动赋值
    Function& operator=(Function&& other) noexcept = default;

    // nullptr赋值
    Function& operator=(std::nullptr_t) noexcept {
        callable_.reset();
        return *this;
    }

    // 调用运算符
    R operator()(Args... args) {
        if (!callable_) {
            throw std::bad_function_call();
        }
        return callable_->invoke(std::forward<Args>(args)...);
    }

    // bool转换
    explicit operator bool() const noexcept {
        return callable_ != nullptr;
    }

    // 交换
    void swap(Function& other) noexcept {
        callable_.swap(other.callable_);
    }
};

// 非成员swap
template <typename R, typename... Args>
void swap(Function<R(Args...)>& lhs, Function<R(Args...)>& rhs) noexcept {
    lhs.swap(rhs);
}
```

**测试基本功能**：

```cpp
#include <iostream>

int add(int a, int b) { return a + b; }

struct Multiplier {
    int factor;
    int operator()(int x) const { return x * factor; }
};

int main() {
    // 函数
    Function<int(int, int)> f1 = add;
    std::cout << f1(3, 4) << '\n';  // 7

    // Lambda
    Function<int(int)> f2 = [](int x) { return x * 2; };
    std::cout << f2(21) << '\n';    // 42

    // 函数对象
    Function<int(int)> f3 = Multiplier{3};
    std::cout << f3(10) << '\n';    // 30

    // 带捕获的Lambda
    int base = 100;
    Function<int(int)> f4 = [base](int x) { return base + x; };
    std::cout << f4(23) << '\n';    // 123

    // 空检查
    Function<void()> f5;
    if (!f5) {
        std::cout << "f5 is empty\n";
    }

    // 拷贝
    Function<int(int)> f6 = f2;
    std::cout << f6(5) << '\n';     // 10
}
```

---

#### Day 5-6: 小对象优化（SBO）与性能分析

**学习时间**: 10小时

**为什么需要SBO？**

```cpp
// 基本版本的问题：每次创建都要堆分配
Function<int(int)> f = [](int x) { return x; };
// 执行：new CallableImpl<Lambda>(...)

// 对于小的可调用对象，堆分配的开销相对很大
// - 分配器开销
// - 缓存不友好
// - 可能的内存碎片

// SBO（Small Buffer Optimization）：
// 在Function对象内部预留一块缓冲区
// 如果可调用对象足够小，直接存储在缓冲区中
// 避免堆分配
```

**带SBO的完整实现**

```cpp
#include <memory>
#include <cstddef>
#include <utility>
#include <type_traits>
#include <new>  // placement new

template <typename> class Function;

template <typename R, typename... Args>
class Function<R(Args...)> {
    // SBO缓冲区大小：通常2-3个指针大小
    // 足以容纳大多数无捕获或少量捕获的Lambda
    static constexpr std::size_t SBO_SIZE = sizeof(void*) * 3;  // 24字节
    static constexpr std::size_t SBO_ALIGN = alignof(std::max_align_t);

    // 类型擦除接口
    struct CallableBase {
        virtual R invoke(Args...) = 0;
        virtual void clone_to(void* buffer) const = 0;  // 用于SBO的拷贝
        virtual void move_to(void* buffer) noexcept = 0;  // 用于SBO的移动
        virtual ~CallableBase() = default;
        virtual bool is_small() const noexcept = 0;
    };

    // 实现类
    template <typename F, bool IsSmall>
    struct CallableImpl : CallableBase {
        F func_;

        template <typename Fn>
        CallableImpl(Fn&& f) : func_(std::forward<Fn>(f)) {}

        R invoke(Args... args) override {
            return std::invoke(func_, std::forward<Args>(args)...);
        }

        void clone_to(void* buffer) const override {
            if constexpr (IsSmall) {
                new (buffer) CallableImpl(func_);
            } else {
                *static_cast<CallableImpl**>(buffer) = new CallableImpl(func_);
            }
        }

        void move_to(void* buffer) noexcept override {
            if constexpr (IsSmall) {
                new (buffer) CallableImpl(std::move(func_));
            } else {
                *static_cast<CallableImpl**>(buffer) = this;
            }
        }

        bool is_small() const noexcept override {
            return IsSmall;
        }
    };

    // 判断是否可以使用SBO
    template <typename F>
    static constexpr bool fits_sbo =
        sizeof(CallableImpl<F, true>) <= SBO_SIZE &&
        alignof(CallableImpl<F, true>) <= SBO_ALIGN &&
        std::is_nothrow_move_constructible_v<F>;

    // 存储：SBO缓冲区或堆指针
    alignas(SBO_ALIGN) unsigned char storage_[SBO_SIZE];
    bool is_small_ = false;  // 标记是否使用SBO

    // 辅助函数
    CallableBase* get_callable() noexcept {
        if (is_small_) {
            return reinterpret_cast<CallableBase*>(storage_);
        } else {
            return *reinterpret_cast<CallableBase**>(storage_);
        }
    }

    const CallableBase* get_callable() const noexcept {
        if (is_small_) {
            return reinterpret_cast<const CallableBase*>(storage_);
        } else {
            return *reinterpret_cast<CallableBase* const*>(storage_);
        }
    }

    bool has_value() const noexcept {
        if (is_small_) {
            return true;  // 如果is_small_为true，一定有值
        } else {
            return *reinterpret_cast<CallableBase* const*>(storage_) != nullptr;
        }
    }

    void destroy() noexcept {
        if (!has_value()) return;

        if (is_small_) {
            get_callable()->~CallableBase();
        } else {
            delete get_callable();
        }
        is_small_ = false;
        *reinterpret_cast<CallableBase**>(storage_) = nullptr;
    }

public:
    // 默认构造
    Function() noexcept {
        *reinterpret_cast<CallableBase**>(storage_) = nullptr;
    }

    Function(std::nullptr_t) noexcept : Function() {}

    // 从可调用对象构造
    template <typename F,
              typename = std::enable_if_t<
                  !std::is_same_v<std::decay_t<F>, Function> &&
                  std::is_invocable_r_v<R, std::decay_t<F>, Args...>
              >>
    Function(F&& f) {
        using FuncType = std::decay_t<F>;

        if constexpr (fits_sbo<FuncType>) {
            // 使用SBO
            using Impl = CallableImpl<FuncType, true>;
            new (storage_) Impl(std::forward<F>(f));
            is_small_ = true;
        } else {
            // 堆分配
            using Impl = CallableImpl<FuncType, false>;
            *reinterpret_cast<Impl**>(storage_) = new Impl(std::forward<F>(f));
            is_small_ = false;
        }
    }

    // 拷贝构造
    Function(const Function& other) {
        if (other.has_value()) {
            other.get_callable()->clone_to(storage_);
            is_small_ = other.is_small_;
        } else {
            *reinterpret_cast<CallableBase**>(storage_) = nullptr;
            is_small_ = false;
        }
    }

    // 移动构造
    Function(Function&& other) noexcept {
        if (other.has_value()) {
            if (other.is_small_) {
                other.get_callable()->move_to(storage_);
                other.get_callable()->~CallableBase();
            } else {
                *reinterpret_cast<CallableBase**>(storage_) =
                    *reinterpret_cast<CallableBase**>(other.storage_);
            }
            is_small_ = other.is_small_;
        } else {
            *reinterpret_cast<CallableBase**>(storage_) = nullptr;
            is_small_ = false;
        }
        other.is_small_ = false;
        *reinterpret_cast<CallableBase**>(other.storage_) = nullptr;
    }

    ~Function() {
        destroy();
    }

    // 赋值运算符
    Function& operator=(const Function& other) {
        if (this != &other) {
            Function(other).swap(*this);
        }
        return *this;
    }

    Function& operator=(Function&& other) noexcept {
        if (this != &other) {
            destroy();
            if (other.has_value()) {
                if (other.is_small_) {
                    other.get_callable()->move_to(storage_);
                    other.get_callable()->~CallableBase();
                } else {
                    *reinterpret_cast<CallableBase**>(storage_) =
                        *reinterpret_cast<CallableBase**>(other.storage_);
                }
                is_small_ = other.is_small_;
            }
            other.is_small_ = false;
            *reinterpret_cast<CallableBase**>(other.storage_) = nullptr;
        }
        return *this;
    }

    Function& operator=(std::nullptr_t) noexcept {
        destroy();
        return *this;
    }

    // 调用
    R operator()(Args... args) {
        if (!has_value()) {
            throw std::bad_function_call();
        }
        return get_callable()->invoke(std::forward<Args>(args)...);
    }

    // bool转换
    explicit operator bool() const noexcept {
        return has_value();
    }

    // 交换
    void swap(Function& other) noexcept {
        Function temp(std::move(other));
        other = std::move(*this);
        *this = std::move(temp);
    }
};
```

**性能对比测试**

```cpp
#include <chrono>
#include <functional>
#include <iostream>

template <typename Func>
void benchmark(const char* name, Func f, int iterations = 1000000) {
    auto start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < iterations; ++i) {
        f(i);
    }
    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);
    std::cout << name << ": " << duration.count() << " us\n";
}

int main() {
    auto lambda = [](int x) { return x * 2; };

    // 1. 直接调用Lambda
    benchmark("Direct lambda", lambda);

    // 2. 通过std::function调用
    std::function<int(int)> std_func = lambda;
    benchmark("std::function", std_func);

    // 3. 通过我们的Function调用
    Function<int(int)> my_func = lambda;
    benchmark("My Function", my_func);

    // 4. 函数指针（无捕获Lambda）
    int (*fp)(int) = lambda;
    benchmark("Function pointer", fp);

    // 5. 模板（最快，可内联）
    benchmark("Template (auto)", [&](int x) {
        return lambda(x);
    });
}
```

**std::function的性能特点**：

| 操作 | 开销 |
|------|------|
| 创建（小对象） | 几乎无（SBO） |
| 创建（大对象） | 堆分配 |
| 调用 | 虚函数调用 + 无法内联 |
| 拷贝（小对象） | 内存拷贝 |
| 拷贝（大对象） | 堆分配 + 拷贝 |
| 移动（小对象） | 内存移动 |
| 移动（大对象） | 指针交换 |

---

#### Day 7: 周末总结与练习

**学习时间**: 5小时

**本周核心知识点回顾**：

1. **类型擦除**：隐藏具体类型，保留行为
2. **std::function结构**：虚基类 + 模板派生类
3. **SBO优化**：小对象直接存储，避免堆分配
4. **性能权衡**：灵活性 vs 性能

**综合练习**：

```cpp
// 练习1：实现move_only_function（不需要拷贝）
template <typename> class MoveOnlyFunction;

template <typename R, typename... Args>
class MoveOnlyFunction<R(Args...)> {
    // TODO: 只支持移动，不支持拷贝
    // 可以存储只能移动的对象（如持有unique_ptr的Lambda）
};

// 练习2：实现function_ref（非所有权引用）
template <typename> class FunctionRef;

template <typename R, typename... Args>
class FunctionRef<R(Args...)> {
    // TODO: 不拥有被引用对象
    // 轻量级，sizeof == 2 * sizeof(void*)
    // 无堆分配，无拷贝
};

// 练习3：测量不同大小Lambda的性能
// 比较SBO阈值前后的创建和调用性能
```

**常见陷阱**：

1. **空std::function调用**：抛出std::bad_function_call
2. **性能敏感路径**：避免使用std::function，用模板
3. **大对象捕获**：超过SBO阈值会导致堆分配
4. **递归Lambda**：std::function可以实现，但有开销

**自测问题**：

1. 什么是类型擦除？它解决什么问题？
2. std::function的内部结构是什么样的？
3. 什么是SBO？它如何提高性能？
4. 什么情况下应该避免使用std::function？
5. 如何实现一个不需要拷贝的function（move_only_function）？

---

## 第四周：高阶函数与函数式编程

### 学习目标

掌握函数式编程的核心概念，能够在C++中应用高阶函数、函数组合、柯里化等技术，完成综合函数库项目。

### 每日学习计划

#### Day 1-2: 高阶函数基础

**学习时间**: 10小时

**阅读材料**：
- [ ] 《Functional Programming in C++》Chapter 1-3
- [ ] C++20 Ranges库文档
- [ ] 博客：Functional Programming Patterns in C++

**高阶函数定义**

```cpp
// 高阶函数：接受函数作为参数，或返回函数的函数

// 1. 接受函数作为参数
template <typename Container, typename Predicate>
auto filter(const Container& c, Predicate pred) {
    Container result;
    for (const auto& elem : c) {
        if (pred(elem)) {
            result.push_back(elem);
        }
    }
    return result;
}

// 2. 返回函数
auto make_multiplier(int factor) {
    return [factor](int x) { return x * factor; };
}

// 3. 同时接受和返回函数
template <typename F, typename G>
auto compose(F f, G g) {
    return [f, g](auto x) { return f(g(x)); };
}
```

**STL中的高阶函数**

```cpp
#include <algorithm>
#include <numeric>
#include <vector>
#include <iostream>

std::vector<int> nums = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};

// transform（map）：对每个元素应用函数
std::vector<int> doubled;
std::transform(nums.begin(), nums.end(),
               std::back_inserter(doubled),
               [](int x) { return x * 2; });
// doubled = {2, 4, 6, 8, 10, 12, 14, 16, 18, 20}

// copy_if（filter）：保留满足条件的元素
std::vector<int> evens;
std::copy_if(nums.begin(), nums.end(),
             std::back_inserter(evens),
             [](int x) { return x % 2 == 0; });
// evens = {2, 4, 6, 8, 10}

// accumulate（reduce/fold）：归约所有元素
int sum = std::accumulate(nums.begin(), nums.end(), 0,
                          [](int acc, int x) { return acc + x; });
// sum = 55

int product = std::accumulate(nums.begin(), nums.end(), 1,
                              [](int acc, int x) { return acc * x; });
// product = 3628800

// for_each：对每个元素执行操作（有副作用）
std::for_each(nums.begin(), nums.end(),
              [](int x) { std::cout << x << ' '; });

// any_of, all_of, none_of：逻辑判断
bool has_even = std::any_of(nums.begin(), nums.end(),
                            [](int x) { return x % 2 == 0; });
bool all_positive = std::all_of(nums.begin(), nums.end(),
                                [](int x) { return x > 0; });
```

**C++20 Ranges：更优雅的函数式编程**

```cpp
#include <ranges>
#include <vector>
#include <iostream>

std::vector<int> nums = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};

// 链式操作：filter -> transform -> take
auto result = nums
    | std::views::filter([](int x) { return x % 2 == 0; })
    | std::views::transform([](int x) { return x * x; })
    | std::views::take(3);

for (int x : result) {
    std::cout << x << ' ';  // 4 16 36
}

// 懒惰求值：不会创建中间容器
// 只有在迭代时才计算

// 收集到容器（C++23 to）
// auto vec = result | std::ranges::to<std::vector>();

// C++20手动收集
std::vector<int> vec(result.begin(), result.end());
```

---

#### Day 3-4: 函数组合与柯里化

**学习时间**: 10小时

**函数组合（Composition）**

```cpp
#include <functional>
#include <utility>

// 基本compose：f(g(x))
template <typename F, typename G>
auto compose(F&& f, G&& g) {
    return [f = std::forward<F>(f),
            g = std::forward<G>(g)](auto&&... args) {
        return f(g(std::forward<decltype(args)>(args)...));
    };
}

// pipe：g(f(x))，更符合阅读顺序
template <typename F, typename G>
auto pipe(F&& f, G&& g) {
    return compose(std::forward<G>(g), std::forward<F>(f));
}

// 多函数组合
template <typename F>
auto compose_all(F&& f) {
    return std::forward<F>(f);
}

template <typename F, typename... Fs>
auto compose_all(F&& f, Fs&&... fs) {
    return compose(std::forward<F>(f), compose_all(std::forward<Fs>(fs)...));
}

// 使用示例
auto add1 = [](int x) { return x + 1; };
auto mul2 = [](int x) { return x * 2; };
auto square = [](int x) { return x * x; };

auto f = compose_all(square, mul2, add1);  // square(mul2(add1(x)))
// f(3) = square(mul2(add1(3))) = square(mul2(4)) = square(8) = 64

auto g = pipe(add1, mul2, square);  // 同样结果，但阅读顺序更自然
// g(3): 3 -> add1 -> 4 -> mul2 -> 8 -> square -> 64
```

**柯里化（Currying）**

```cpp
// 柯里化：将多参数函数转换为一系列单参数函数

// 手动柯里化
auto add = [](int a) {
    return [a](int b) {
        return [a, b](int c) {
            return a + b + c;
        };
    };
};

int result = add(1)(2)(3);  // 6

// 通用柯里化（简化版，固定参数数量）
template <typename F>
auto curry2(F f) {
    return [f](auto a) {
        return [f, a](auto b) {
            return f(a, b);
        };
    };
}

template <typename F>
auto curry3(F f) {
    return [f](auto a) {
        return [f, a](auto b) {
            return [f, a, b](auto c) {
                return f(a, b, c);
            };
        };
    };
}

// 使用
auto sum3 = [](int a, int b, int c) { return a + b + c; };
auto curried_sum = curry3(sum3);
auto add_to_3 = curried_sum(1)(2);  // 返回一个等待第三个参数的函数
int r = add_to_3(3);  // 6
```

**部分应用（Partial Application）**

```cpp
// 部分应用：固定部分参数，返回新函数

// 使用std::bind
#include <functional>

int multiply(int a, int b, int c) { return a * b * c; }

// 固定第一个参数
auto times2 = std::bind(multiply, 2, std::placeholders::_1, std::placeholders::_2);
int r1 = times2(3, 4);  // 2 * 3 * 4 = 24

// 使用Lambda更清晰
template <typename F, typename... PartialArgs>
auto partial(F&& f, PartialArgs&&... pargs) {
    return [f = std::forward<F>(f),
            ...captured = std::forward<PartialArgs>(pargs)]
           (auto&&... args) mutable {
        return f(captured..., std::forward<decltype(args)>(args)...);
    };
}

// 使用
auto times2_v2 = partial(multiply, 2);
int r2 = times2_v2(3, 4);  // 24

auto times2_times3 = partial(multiply, 2, 3);
int r3 = times2_times3(4);  // 24
```

**记忆化（Memoization）**

```cpp
#include <unordered_map>
#include <tuple>
#include <functional>

// 简单版本：单参数函数
template <typename F>
auto memoize(F f) {
    using ArgType = std::decay_t<
        std::tuple_element_t<0,
            typename function_traits<F>::args_tuple>>;  // 需要traits
    using ResultType = typename function_traits<F>::result_type;

    auto cache = std::make_shared<std::unordered_map<ArgType, ResultType>>();

    return [f, cache](ArgType arg) {
        auto it = cache->find(arg);
        if (it != cache->end()) {
            return it->second;
        }
        auto result = f(arg);
        (*cache)[arg] = result;
        return result;
    };
}

// 实用简化版
template <typename R, typename Arg>
auto memoize_simple(std::function<R(Arg)> f) {
    auto cache = std::make_shared<std::unordered_map<Arg, R>>();

    return [f, cache](Arg arg) -> R {
        if (auto it = cache->find(arg); it != cache->end()) {
            return it->second;
        }
        R result = f(arg);
        (*cache)[arg] = result;
        return result;
    };
}

// 使用示例：斐波那契
std::function<long long(int)> fib = memoize_simple<long long, int>(
    [&fib](int n) -> long long {
        if (n <= 1) return n;
        return fib(n - 1) + fib(n - 2);
    }
);

// fib(50) 现在可以快速计算
```

---

#### Day 5-6: 综合项目——完整函数库

**学习时间**: 10小时

**项目结构**

```
functional_lib/
├── include/
│   ├── function.hpp       // mini::function实现
│   ├── bind.hpp           // mini::bind实现
│   ├── functional.hpp     // 函数式工具
│   └── invoke.hpp         // mini::invoke实现
├── test/
│   ├── test_function.cpp
│   ├── test_bind.cpp
│   └── test_functional.cpp
└── CMakeLists.txt
```

**invoke.hpp**

```cpp
#pragma once
#include <type_traits>
#include <utility>

namespace mini {

// 检测成员指针
template <typename T>
struct is_member_pointer : std::false_type {};

template <typename T, typename C>
struct is_member_pointer<T C::*> : std::true_type {};

// invoke实现
namespace detail {

// 普通可调用对象
template <typename F, typename... Args>
constexpr auto invoke_impl(F&& f, Args&&... args)
    noexcept(noexcept(std::forward<F>(f)(std::forward<Args>(args)...)))
    -> decltype(std::forward<F>(f)(std::forward<Args>(args)...))
{
    return std::forward<F>(f)(std::forward<Args>(args)...);
}

// 成员函数 + 对象引用
template <typename T, typename C, typename Obj, typename... Args>
constexpr auto invoke_impl(T C::*pmf, Obj&& obj, Args&&... args)
    noexcept(noexcept((std::forward<Obj>(obj).*pmf)(std::forward<Args>(args)...)))
    -> std::enable_if_t<
        std::is_function_v<T> &&
        std::is_base_of_v<C, std::decay_t<Obj>>,
        decltype((std::forward<Obj>(obj).*pmf)(std::forward<Args>(args)...))
    >
{
    return (std::forward<Obj>(obj).*pmf)(std::forward<Args>(args)...);
}

// 成员函数 + 指针
template <typename T, typename C, typename Ptr, typename... Args>
constexpr auto invoke_impl(T C::*pmf, Ptr&& ptr, Args&&... args)
    noexcept(noexcept(((*std::forward<Ptr>(ptr)).*pmf)(std::forward<Args>(args)...)))
    -> std::enable_if_t<
        std::is_function_v<T> &&
        !std::is_base_of_v<C, std::decay_t<Ptr>>,
        decltype(((*std::forward<Ptr>(ptr)).*pmf)(std::forward<Args>(args)...))
    >
{
    return ((*std::forward<Ptr>(ptr)).*pmf)(std::forward<Args>(args)...);
}

// 数据成员 + 对象引用
template <typename T, typename C, typename Obj>
constexpr auto invoke_impl(T C::*pm, Obj&& obj)
    noexcept(noexcept(std::forward<Obj>(obj).*pm))
    -> std::enable_if_t<
        !std::is_function_v<T> &&
        std::is_base_of_v<C, std::decay_t<Obj>>,
        decltype(std::forward<Obj>(obj).*pm)
    >
{
    return std::forward<Obj>(obj).*pm;
}

// 数据成员 + 指针
template <typename T, typename C, typename Ptr>
constexpr auto invoke_impl(T C::*pm, Ptr&& ptr)
    noexcept(noexcept((*std::forward<Ptr>(ptr)).*pm))
    -> std::enable_if_t<
        !std::is_function_v<T> &&
        !std::is_base_of_v<C, std::decay_t<Ptr>>,
        decltype((*std::forward<Ptr>(ptr)).*pm)
    >
{
    return (*std::forward<Ptr>(ptr)).*pm;
}

}  // namespace detail

template <typename F, typename... Args>
constexpr auto invoke(F&& f, Args&&... args)
    noexcept(noexcept(detail::invoke_impl(std::forward<F>(f), std::forward<Args>(args)...)))
    -> decltype(detail::invoke_impl(std::forward<F>(f), std::forward<Args>(args)...))
{
    return detail::invoke_impl(std::forward<F>(f), std::forward<Args>(args)...);
}

// invoke_result
template <typename F, typename... Args>
struct invoke_result {
    using type = decltype(invoke(std::declval<F>(), std::declval<Args>()...));
};

template <typename F, typename... Args>
using invoke_result_t = typename invoke_result<F, Args...>::type;

// is_invocable
template <typename F, typename... Args, typename = void>
struct is_invocable : std::false_type {};

template <typename F, typename... Args>
struct is_invocable<F, Args...,
    std::void_t<decltype(invoke(std::declval<F>(), std::declval<Args>()...))>>
    : std::true_type {};

template <typename F, typename... Args>
inline constexpr bool is_invocable_v = is_invocable<F, Args...>::value;

}  // namespace mini
```

**functional.hpp（高级功能）**

```cpp
#pragma once
#include <tuple>
#include <utility>
#include <type_traits>
#include "invoke.hpp"

namespace mini {

// ============== 函数组合 ==============

template <typename F, typename G>
constexpr auto compose(F&& f, G&& g) {
    return [f = std::forward<F>(f),
            g = std::forward<G>(g)]
           (auto&&... args) -> decltype(auto) {
        return mini::invoke(f, mini::invoke(g, std::forward<decltype(args)>(args)...));
    };
}

template <typename F, typename G>
constexpr auto pipe(F&& f, G&& g) {
    return compose(std::forward<G>(g), std::forward<F>(f));
}

template <typename F>
constexpr auto compose_all(F&& f) {
    return std::forward<F>(f);
}

template <typename F, typename G, typename... Fs>
constexpr auto compose_all(F&& f, G&& g, Fs&&... fs) {
    return compose_all(
        compose(std::forward<F>(f), std::forward<G>(g)),
        std::forward<Fs>(fs)...
    );
}

// ============== 部分应用 ==============

template <typename F, typename... CapturedArgs>
constexpr auto partial(F&& f, CapturedArgs&&... captured) {
    return [f = std::forward<F>(f),
            ...caps = std::forward<CapturedArgs>(captured)]
           (auto&&... args) mutable -> decltype(auto) {
        return mini::invoke(f, caps..., std::forward<decltype(args)>(args)...);
    };
}

// ============== 柯里化 ==============

// 辅助：获取函数参数数量
template <typename F>
struct arity;

template <typename R, typename... Args>
struct arity<R(*)(Args...)> : std::integral_constant<std::size_t, sizeof...(Args)> {};

template <typename R, typename C, typename... Args>
struct arity<R(C::*)(Args...)> : std::integral_constant<std::size_t, sizeof...(Args)> {};

template <typename R, typename C, typename... Args>
struct arity<R(C::*)(Args...) const> : std::integral_constant<std::size_t, sizeof...(Args)> {};

// 简化柯里化（固定参数数量）
template <std::size_t N, typename F, typename... Args>
constexpr auto curry_impl(F&& f, Args&&... args) {
    if constexpr (sizeof...(Args) >= N) {
        return mini::invoke(std::forward<F>(f), std::forward<Args>(args)...);
    } else {
        return [f = std::forward<F>(f), ...captured = std::forward<Args>(args)]
               (auto&& arg) mutable {
            return curry_impl<N>(
                std::move(f),
                std::move(captured)...,
                std::forward<decltype(arg)>(arg)
            );
        };
    }
}

template <std::size_t N, typename F>
constexpr auto curry(F&& f) {
    return [f = std::forward<F>(f)](auto&& arg) mutable {
        return curry_impl<N>(std::move(f), std::forward<decltype(arg)>(arg));
    };
}

// ============== 其他实用工具 ==============

// identity：恒等函数
struct identity_t {
    template <typename T>
    constexpr T&& operator()(T&& t) const noexcept {
        return std::forward<T>(t);
    }
};
inline constexpr identity_t identity{};

// constant：常量函数
template <typename T>
constexpr auto constant(T&& value) {
    return [v = std::forward<T>(value)](auto&&...) -> const std::decay_t<T>& {
        return v;
    };
}

// flip：交换二元函数的参数顺序
template <typename F>
constexpr auto flip(F&& f) {
    return [f = std::forward<F>(f)](auto&& a, auto&& b) -> decltype(auto) {
        return mini::invoke(f,
            std::forward<decltype(b)>(b),
            std::forward<decltype(a)>(a));
    };
}

// negate：否定谓词
template <typename Pred>
constexpr auto negate(Pred&& pred) {
    return [pred = std::forward<Pred>(pred)](auto&&... args) {
        return !mini::invoke(pred, std::forward<decltype(args)>(args)...);
    };
}

// Y组合子：匿名递归
template <typename F>
constexpr auto Y(F&& f) {
    return [f = std::forward<F>(f)](auto&&... args) -> decltype(auto) {
        return f(f, std::forward<decltype(args)>(args)...);
    };
}

}  // namespace mini
```

**测试文件示例**

```cpp
// test_functional.cpp
#include "functional.hpp"
#include <cassert>
#include <iostream>
#include <string>
#include <vector>

void test_compose() {
    auto add1 = [](int x) { return x + 1; };
    auto mul2 = [](int x) { return x * 2; };

    auto f = mini::compose(mul2, add1);  // mul2(add1(x))
    assert(f(3) == 8);  // (3 + 1) * 2 = 8

    auto g = mini::pipe(add1, mul2);  // mul2(add1(x))
    assert(g(3) == 8);

    auto h = mini::compose_all(
        [](int x) { return x * x; },
        mul2,
        add1
    );
    assert(h(3) == 64);  // ((3 + 1) * 2)^2 = 64

    std::cout << "test_compose passed\n";
}

void test_partial() {
    auto add3 = [](int a, int b, int c) { return a + b + c; };

    auto add_1_and = mini::partial(add3, 1);
    assert(add_1_and(2, 3) == 6);

    auto add_1_2_and = mini::partial(add3, 1, 2);
    assert(add_1_2_and(3) == 6);

    std::cout << "test_partial passed\n";
}

void test_curry() {
    auto add3 = [](int a, int b, int c) { return a + b + c; };

    auto curried = mini::curry<3>(add3);
    assert(curried(1)(2)(3) == 6);

    auto add_1 = curried(1);
    auto add_1_2 = add_1(2);
    assert(add_1_2(3) == 6);

    std::cout << "test_curry passed\n";
}

void test_y_combinator() {
    auto factorial = mini::Y([](auto self, int n) -> int {
        return n <= 1 ? 1 : n * self(self, n - 1);
    });

    assert(factorial(0) == 1);
    assert(factorial(1) == 1);
    assert(factorial(5) == 120);
    assert(factorial(10) == 3628800);

    auto fibonacci = mini::Y([](auto self, int n) -> int {
        return n <= 1 ? n : self(self, n - 1) + self(self, n - 2);
    });

    assert(fibonacci(0) == 0);
    assert(fibonacci(1) == 1);
    assert(fibonacci(10) == 55);

    std::cout << "test_y_combinator passed\n";
}

void test_utility_functions() {
    // identity
    assert(mini::identity(42) == 42);

    // constant
    auto always_42 = mini::constant(42);
    assert(always_42() == 42);
    assert(always_42(1, 2, 3) == 42);

    // flip
    auto sub = [](int a, int b) { return a - b; };
    auto flipped_sub = mini::flip(sub);
    assert(sub(5, 3) == 2);
    assert(flipped_sub(5, 3) == -2);

    // negate
    auto is_positive = [](int x) { return x > 0; };
    auto is_not_positive = mini::negate(is_positive);
    assert(is_positive(5) == true);
    assert(is_not_positive(5) == false);

    std::cout << "test_utility_functions passed\n";
}

int main() {
    test_compose();
    test_partial();
    test_curry();
    test_y_combinator();
    test_utility_functions();

    std::cout << "\nAll tests passed!\n";
    return 0;
}
```

---

#### Day 7: 月度总结与知识整合

**学习时间**: 5小时

**本月核心知识点回顾**

| 周次 | 主题 | 核心概念 |
|------|------|----------|
| 第一周 | 函数对象基础 | 五种可调用对象、std::invoke、函数对象优势 |
| 第二周 | Lambda深度 | 编译器转换、捕获机制、泛型Lambda |
| 第三周 | std::function | 类型擦除、SBO优化、性能权衡 |
| 第四周 | 函数式编程 | 高阶函数、组合、柯里化、Y组合子 |

**知识体系图**

```
可调用对象
├── 函数/函数指针
├── 成员函数/成员指针
├── 函数对象（仿函数）
└── Lambda表达式
    ├── 编译器转换 → 匿名类
    ├── 捕获机制
    │   ├── 值捕获
    │   ├── 引用捕获
    │   └── 初始化捕获
    └── 泛型Lambda → 模板operator()

类型擦除
├── 动机：统一接口、容器存储
├── 实现：虚基类 + 模板派生类
├── std::function
│   ├── SBO优化
│   └── 性能特点
└── 应用：any、function_ref

函数式编程
├── 高阶函数
│   ├── map (transform)
│   ├── filter (copy_if)
│   └── reduce (accumulate)
├── 函数组合 (compose/pipe)
├── 柯里化 (curry)
├── 部分应用 (partial)
└── Y组合子（匿名递归）
```

**最终检验清单**

### 知识检验
- [ ] Lambda表达式会被编译器转换成什么？
- [ ] 解释值捕获和引用捕获的区别，以及init capture
- [ ] std::function如何实现类型擦除？
- [ ] std::function的性能开销有哪些？
- [ ] 什么时候应该用std::function，什么时候用auto或模板？
- [ ] 什么是函数组合？如何实现？
- [ ] 柯里化和部分应用有什么区别？

### 实践检验
- [ ] mini_function正确实现SBO优化
- [ ] mini_bind支持占位符和部分应用
- [ ] mini_invoke支持所有可调用对象类型
- [ ] 函数式工具库能正确组合函数
- [ ] 所有测试用例通过

### 输出物清单
1. `mini_function.hpp` - 带SBO的function实现
2. `mini_bind.hpp` - bind和占位符实现
3. `mini_invoke.hpp` - 统一调用实现
4. `functional.hpp` - 函数式编程工具库
5. `test_*.cpp` - 完整测试套件
6. `notes/month08_lambda.md` - 学习笔记

---

## 延伸阅读与资源

### 推荐书籍
- 《Effective Modern C++》Scott Meyers - Item 31-34
- 《Functional Programming in C++》Ivan Čukić
- 《C++ Templates: The Complete Guide》Chapter 21-22

### 推荐视频
- CppCon: "Back to Basics: Lambdas"
- CppCon: "Type Erasure" by Klaus Iglberger
- CppCon: "std::function and Beyond" by Stephan T. Lavavej

### 在线资源
- cppreference: Lambda expressions
- cppreference: std::function
- cppreference: std::invoke

---

## 时间分配（140小时/月）

| 内容 | 时间 | 占比 |
|------|------|------|
| 第一周：函数对象基础 | 35小时 | 25% |
| 第二周：Lambda深度 | 35小时 | 25% |
| 第三周：std::function与类型擦除 | 35小时 | 25% |
| 第四周：高阶函数与函数式编程 | 35小时 | 25% |

**每周细分**：
- 理论学习：10小时
- 源码阅读：5小时
- 代码实践：15小时
- 总结复习：5小时

---

## 下月预告

Month 09将学习**迭代器与算法库深度**，深入分析STL算法的实现，理解迭代器分类，并实现自定义迭代器和算法。主要内容包括：

- 迭代器的五种分类及其概念
- STL算法的实现原理
- 自定义迭代器的编写
- C++20 Ranges库深入
