# Month 05: 模板元编程基础——编译期计算与类型推导

## 本月主题概述

模板元编程（Template Metaprogramming, TMP）是C++区别于其他语言的独特能力。本月将系统学习SFINAE、type_traits、constexpr等技术，理解编译期计算的原理，为理解STL和现代C++库的实现奠定基础。

---

## 理论学习内容

### 第一周：模板基础与类型推导

**学习目标**：深入理解模板实例化和类型推导规则

**阅读材料**：
- [ ] 《C++ Templates: The Complete Guide》第1-4章
- [ ] 《Effective Modern C++》Item 1-4（类型推导）
- [ ] CppCon演讲："Template Metaprogramming: Type Traits"

**每日学习安排**：

| 天数 | 主题 | 内容 | 练习 |
|------|------|------|------|
| Day 1 | 函数模板基础 | 模板声明、实例化、特化 | 实现泛型swap、max、min |
| Day 2 | 类模板基础 | 类模板定义、成员函数、静态成员 | 实现简单的Stack<T> |
| Day 3 | 模板参数推导(上) | 按值传递、引用传递的推导规则 | 编写测试验证推导结果 |
| Day 4 | 模板参数推导(下) | 转发引用、引用折叠 | 实现print_type工具 |
| Day 5 | auto类型推导 | auto的各种形式、推导规则 | 对比auto与模板推导差异 |
| Day 6 | decltype深入 | decltype规则、decltype(auto) | 实现返回引用的函数 |
| Day 7 | 综合复习与练习 | 整合本周知识 | 完成Week1练习项目 |

**核心概念**：

#### 1. 模板的本质：代码生成器

模板不是类型，而是编译器用来生成代码的"蓝图"。理解这一点至关重要：

```cpp
// 模板定义（不生成任何代码）
template <typename T>
T add(T a, T b) { return a + b; }

// 实例化点（编译器生成实际代码）
int result = add(1, 2);      // 生成 int add(int, int)
double d = add(1.5, 2.5);    // 生成 double add(double, double)

// 查看实例化：可以使用 __PRETTY_FUNCTION__ 或编译器选项
template <typename T>
void show_type() {
    std::cout << __PRETTY_FUNCTION__ << std::endl;
}
// show_type<int>() 输出: void show_type() [T = int]
```

#### 2. 模板参数推导规则（完整版）

```cpp
template <typename T>
void f(T param);           // 按值传递

template <typename T>
void f(T& param);          // 左值引用

template <typename T>
void f(T&& param);         // 转发引用（万能引用）

// ========== 规则1: 按值传递 ==========
// 推导时忽略：引用、顶层const、顶层volatile
int x = 42;
const int cx = x;
const int& rx = x;
volatile int vx = x;

f(x);   // T = int, param = int
f(cx);  // T = int, param = int (顶层const被忽略)
f(rx);  // T = int, param = int (引用和const都被忽略)
f(vx);  // T = int, param = int (volatile被忽略)

// 但底层const会保留
const int* px = &cx;
f(px);  // T = const int*, param = const int* (底层const保留)

// ========== 规则2: 左值引用 ==========
// 保留cv限定符，T推导为去引用后的类型
template <typename T>
void g(T& param);

g(x);   // T = int,       param = int&
g(cx);  // T = const int, param = const int&
g(rx);  // T = const int, param = const int& (rx的引用被忽略)

// ========== 规则3: 转发引用（万能引用）==========
// 关键：参数形式必须是 T&& 且 T 是推导出来的
template <typename T>
void h(T&& param);

h(x);           // x是左值, T = int&,  param = int& (引用折叠)
h(cx);          // 左值,    T = const int&, param = const int&
h(42);          // 42是右值, T = int,   param = int&&
h(std::move(x)); // 右值,   T = int,   param = int&&

// 引用折叠规则（只在模板中发生）：
// T& &   -> T&
// T& &&  -> T&
// T&& &  -> T&
// T&& && -> T&&
// 记忆：只要有左值引用参与，结果就是左值引用
```

#### 3. 数组和函数的特殊推导

```cpp
// 数组推导
const char name[] = "Hello";  // name的类型是 const char[6]

template <typename T> void byValue(T param);
template <typename T> void byRef(T& param);

byValue(name);  // T = const char*, param退化为指针
byRef(name);    // T = const char[6], param = const char(&)[6]

// 利用这个特性获取数组长度
template <typename T, std::size_t N>
constexpr std::size_t arraySize(T (&)[N]) noexcept {
    return N;
}

int arr[] = {1, 2, 3, 4, 5};
static_assert(arraySize(arr) == 5);

// 函数推导（类似数组）
void func(int);
byValue(func);  // T = void(*)(int), 函数退化为函数指针
byRef(func);    // T = void(int), param = void(&)(int)
```

#### 4. auto类型推导

```cpp
// auto基本遵循模板推导规则，但有一个例外

auto x = 42;          // int
const auto cx = x;    // const int
auto& rx = x;         // int&
auto&& ux = x;        // int& (x是左值，引用折叠)
auto&& uy = 42;       // int&& (42是右值)

// ⚠️ 例外：花括号初始化
auto a = {1, 2, 3};   // std::initializer_list<int>
auto b{42};           // C++17起是int，C++11/14是initializer_list<int>

// 模板不能推导initializer_list
template <typename T>
void f(T param);
f({1, 2, 3});  // 错误！模板无法推导

// C++14: auto用于返回类型和lambda参数
auto createMultiplier(int factor) {
    return [factor](auto x) { return x * factor; };
}
```

#### 5. decltype深入解析

```cpp
// decltype的两条规则：
// 1. 如果表达式是标识符（变量名），返回该变量的声明类型
// 2. 如果表达式不是标识符，返回表达式的值类别对应的类型

int x = 0;
int* p = &x;
int& r = x;

// 规则1：标识符
decltype(x)   // int (变量声明类型)
decltype(r)   // int& (引用声明类型)
decltype(p)   // int*

// 规则2：表达式
decltype((x))   // int& (x加括号变成表达式，x是左值)
decltype(*p)    // int& (*p是左值表达式)
decltype(x + 1) // int (x+1是右值/纯右值)
decltype(++x)   // int& (++x返回左值)
decltype(x++)   // int (x++返回右值)

// 值类别与decltype的对应：
// 左值表达式 -> T&
// 将亡值表达式 -> T&&
// 纯右值表达式 -> T

// decltype(auto)：精确保持表达式类型（C++14）
decltype(auto) foo() {
    int x = 42;
    return x;      // 返回 int
}

decltype(auto) bar() {
    int x = 42;
    return (x);    // ⚠️ 返回 int&，悬垂引用！
}

// 正确使用场景：完美返回
template <typename Container, typename Index>
decltype(auto) access(Container&& c, Index i) {
    return std::forward<Container>(c)[i];  // 完美保持[]的返回类型
}
```

#### 6. 实用调试技巧：类型打印

```cpp
// 方法1：编译错误显示类型
template <typename T>
struct TypeDisplayer;  // 只声明不定义

template <typename T>
void showType(T&& param) {
    TypeDisplayer<T> td;               // 编译错误会显示T的类型
    TypeDisplayer<decltype(param)> td2; // 显示param的类型
}

// 方法2：运行时打印（不完全准确但有用）
#include <typeinfo>
#include <cxxabi.h>  // GCC/Clang

template <typename T>
std::string demangle() {
    int status;
    char* name = abi::__cxa_demangle(typeid(T).name(), 0, 0, &status);
    std::string result(name);
    free(name);
    return result;
}

// 方法3：使用 Boost.TypeIndex（最准确）
#include <boost/type_index.hpp>
template <typename T>
void printType(T&& param) {
    using boost::typeindex::type_id_with_cvr;
    std::cout << "T = " << type_id_with_cvr<T>().pretty_name() << '\n';
    std::cout << "param = " << type_id_with_cvr<decltype(param)>().pretty_name() << '\n';
}
```

**Week 1 练习项目**：

```cpp
// exercises/week1_type_deduction.cpp
// 实现一个完整的类型推导验证工具

#include <iostream>
#include <type_traits>

// 练习1：实现 type_name<T>() 返回类型名称字符串
// 提示：使用模板特化处理各种情况

// 练习2：实现 deduce_check 验证你对推导规则的理解
template <typename Expected, typename T>
void deduce_check(T&&) {
    static_assert(std::is_same_v<Expected, T>,
                  "Type deduction mismatch!");
}

// 练习3：解释以下每个调用的推导结果
void week1_exercises() {
    int x = 42;
    const int cx = x;
    const int& rx = cx;
    int arr[3] = {1, 2, 3};

    // 在注释中写出每个T的推导结果，然后用deduce_check验证
    // deduce_check<???>(x);
    // deduce_check<???>(cx);
    // deduce_check<???>(rx);
    // deduce_check<???>(arr);
    // deduce_check<???>(std::move(x));
}
```

**本周检验标准**：
- [ ] 能准确说出给定函数调用的T推导结果
- [ ] 理解引用折叠的四条规则
- [ ] 知道数组/函数在模板推导中的退化行为
- [ ] 能区分decltype对标识符和表达式的不同处理
- [ ] 理解decltype(auto)的使用场景和陷阱

### 第二周：SFINAE原理与应用

**学习目标**：掌握SFINAE（替换失败即非错误）机制

**阅读材料**：
- [ ] 《C++ Templates: The Complete Guide》第15章（模板参数推导）
- [ ] 《C++ Templates: The Complete Guide》第19章（SFINAE）
- [ ] CppCon演讲："C++ Weekly - SFINAE" by Jason Turner
- [ ] 博客：https://en.cppreference.com/w/cpp/language/sfinae

**每日学习安排**：

| 天数 | 主题 | 内容 | 练习 |
|------|------|------|------|
| Day 1 | SFINAE原理 | 替换失败机制、重载决议 | 分析SFINAE失败案例 |
| Day 2 | enable_if基础 | 三种使用方式 | 实现条件函数重载 |
| Day 3 | enable_if进阶 | 组合条件、常见陷阱 | 实现多条件约束函数 |
| Day 4 | void_t技术 | 检测惯用法、成员检测 | 实现has_xxx检测器 |
| Day 5 | 检测惯用法 | 方法检测、表达式检测 | 实现is_callable |
| Day 6 | C++20 concepts预览 | requires表达式、概念 | 用concepts重写enable_if |
| Day 7 | 综合项目 | 实现类型特征检测库 | 完成Week2练习项目 |

**核心概念**：

#### 1. SFINAE的本质：重载决议的安全阀

SFINAE = Substitution Failure Is Not An Error

```cpp
// SFINAE发生在模板参数替换阶段
// 重载决议流程：
// 1. 名字查找 -> 找到所有候选函数
// 2. 模板参数推导 -> 确定模板参数
// 3. 模板参数替换 -> SFINAE在此发生！
// 4. 重载决议 -> 选择最佳匹配
// 5. 访问检查

template <typename T>
typename T::value_type get_value(T container) {  // 候选1
    return container.front();
}

template <typename T>
T get_value(T value) {  // 候选2
    return value;
}

std::vector<int> v{1, 2, 3};
int x = 42;

get_value(v);  // 候选1: T=vector<int>, T::value_type=int ✓
               // 候选2: T=vector<int> ✓
               // 候选1更特化，选择候选1

get_value(x);  // 候选1: T=int, int::value_type 不存在 -> SFINAE失败，移除
               // 候选2: T=int ✓
               // 只剩候选2，选择候选2
```

#### 2. SFINAE发生的位置（重要！）

```cpp
// SFINAE只在"直接上下文"中生效
// 直接上下文包括：
// - 函数参数类型
// - 函数返回类型
// - 模板参数默认值
// - 模板参数的约束表达式

// ✓ SFINAE友好的位置
template <typename T>
auto foo(T t) -> decltype(t.bar()) {  // 返回类型
    return t.bar();
}

template <typename T, typename = decltype(std::declval<T>().bar())>
void foo(T t) {  // 默认模板参数
    t.bar();
}

// ✗ 不是SFINAE，而是硬错误
template <typename T>
void foo(T t) {
    typename T::value_type x;  // 函数体内的错误不是SFINAE！
}

// 示例：区分直接上下文和非直接上下文
template <typename T>
struct Helper {
    using type = typename T::nested;  // 如果T没有nested，这是硬错误
};

template <typename T>
typename Helper<T>::type foo(T);  // Helper<T>的实例化失败不是SFINAE
                                  // 因为错误发生在Helper内部，不是直接上下文
```

#### 3. enable_if的三种经典用法

```cpp
// enable_if的实现原理
template <bool B, typename T = void>
struct enable_if {};

template <typename T>
struct enable_if<true, T> {
    using type = T;
};
// 当B为false时，enable_if<B,T>::type不存在，触发SFINAE

// ========== 方式1：返回类型 ==========
template <typename T>
typename std::enable_if<std::is_integral_v<T>, T>::type
double_value(T value) {
    return value * 2;
}

template <typename T>
typename std::enable_if<std::is_floating_point_v<T>, T>::type
double_value(T value) {
    return value * 2.0;
}

// ========== 方式2：默认模板参数（类型） ==========
// ⚠️ 有重定义问题！
template <typename T, typename = std::enable_if_t<std::is_integral_v<T>>>
void process(T value) { /*整数版本*/ }

template <typename T, typename = std::enable_if_t<std::is_floating_point_v<T>>>
void process(T value) { /*浮点版本*/ }  // 错误：与上面是同一个签名！

// 原因：默认参数不参与签名，两个模板签名都是 template<typename, typename> void process(T)

// ========== 方式3：非类型模板参数（推荐！）==========
template <typename T, std::enable_if_t<std::is_integral_v<T>, int> = 0>
void process(T value) {
    std::cout << "integral: " << value << '\n';
}

template <typename T, std::enable_if_t<std::is_floating_point_v<T>, int> = 0>
void process(T value) {
    std::cout << "floating: " << value << '\n';
}
// ✓ 签名不同：template<typename, int> 和 template<typename, int>
// 因为enable_if_t展开后类型不同，第二个模板参数是不同的SFINAE条件

// C++14简化写法
template <typename T>
std::enable_if_t<std::is_integral_v<T>, T>
double_value_14(T value) {
    return value * 2;
}
```

#### 4. void_t：检测惯用法的基石

```cpp
// void_t的魔力：将任意类型序列映射到void
template <typename...>
using void_t = void;

// 基本检测模式
template <typename, typename = void>
struct has_value_type : std::false_type {};

template <typename T>
struct has_value_type<T, std::void_t<typename T::value_type>> : std::true_type {};

// 工作原理：
// 1. has_value_type<int>
//    -> 匹配主模板 has_value_type<int, void>
//    -> 尝试特化 has_value_type<int, void_t<int::value_type>>
//    -> int::value_type不存在，SFINAE失败
//    -> 使用主模板，继承false_type

// 2. has_value_type<vector<int>>
//    -> 匹配主模板 has_value_type<vector<int>, void>
//    -> 尝试特化 has_value_type<vector<int>, void_t<vector<int>::value_type>>
//    -> void_t<int> = void
//    -> 特化匹配成功，继承true_type

// 检测成员类型
template <typename T, typename = void>
struct has_iterator : std::false_type {};
template <typename T>
struct has_iterator<T, std::void_t<typename T::iterator>> : std::true_type {};

// 检测成员变量
template <typename T, typename = void>
struct has_size_member : std::false_type {};
template <typename T>
struct has_size_member<T, std::void_t<decltype(T::size)>> : std::true_type {};

// 检测成员函数
template <typename T, typename = void>
struct has_size_method : std::false_type {};
template <typename T>
struct has_size_method<T, std::void_t<decltype(std::declval<T>().size())>>
    : std::true_type {};

// 检测特定签名的成员函数
template <typename T, typename = void>
struct has_push_back : std::false_type {};
template <typename T>
struct has_push_back<T,
    std::void_t<decltype(std::declval<T>().push_back(std::declval<typename T::value_type>()))>>
    : std::true_type {};
```

#### 5. 检测惯用法进阶：is_detected

```cpp
// C++17 Library Fundamentals TS v2 的检测惯用法
namespace detail {
    template <typename Default, typename AlwaysVoid,
              template<typename...> class Op, typename... Args>
    struct detector {
        using value_t = std::false_type;
        using type = Default;
    };

    template <typename Default, template<typename...> class Op, typename... Args>
    struct detector<Default, std::void_t<Op<Args...>>, Op, Args...> {
        using value_t = std::true_type;
        using type = Op<Args...>;
    };
}

struct nonesuch {
    nonesuch() = delete;
    ~nonesuch() = delete;
    nonesuch(const nonesuch&) = delete;
    void operator=(const nonesuch&) = delete;
};

template <template<typename...> class Op, typename... Args>
using is_detected = typename detail::detector<nonesuch, void, Op, Args...>::value_t;

template <template<typename...> class Op, typename... Args>
using detected_t = typename detail::detector<nonesuch, void, Op, Args...>::type;

template <typename Default, template<typename...> class Op, typename... Args>
using detected_or = detail::detector<Default, void, Op, Args...>;

// 使用示例
template <typename T>
using has_reserve = decltype(std::declval<T>().reserve(std::declval<size_t>()));

template <typename T>
using value_type_t = typename T::value_type;

// 检测
static_assert(is_detected<has_reserve, std::vector<int>>::value);
static_assert(!is_detected<has_reserve, std::list<int>>::value);
static_assert(is_detected<value_type_t, std::vector<int>>::value);
```

#### 6. 表达式SFINAE（C++11）

```cpp
// 使用尾返回类型和decltype进行表达式检测
template <typename T, typename U>
auto add(T t, U u) -> decltype(t + u) {
    return t + u;
}

// 检测是否可以调用
template <typename F, typename... Args>
auto invoke_check(F&& f, Args&&... args)
    -> decltype(std::forward<F>(f)(std::forward<Args>(args)...)) {
    return std::forward<F>(f)(std::forward<Args>(args)...);
}

// 逗号技巧：执行表达式但返回特定类型
template <typename T>
auto check_dereference(T t) -> decltype(*t, void()) {
    // *t 必须合法，但返回void
}

// 组合多个条件
template <typename Container>
auto smart_insert(Container& c, typename Container::value_type v)
    -> decltype(c.push_back(v), c.reserve(1), void()) {
    c.reserve(c.size() + 1);
    c.push_back(std::move(v));
}
```

#### 7. C++20 Concepts预览

```cpp
// concepts是SFINAE的高级替代品
// 提供更清晰的语法和更好的错误信息

// 定义concept
template <typename T>
concept Integral = std::is_integral_v<T>;

template <typename T>
concept Addable = requires(T a, T b) {
    { a + b } -> std::same_as<T>;
};

template <typename T>
concept Container = requires(T c) {
    typename T::value_type;
    typename T::iterator;
    { c.begin() } -> std::same_as<typename T::iterator>;
    { c.end() } -> std::same_as<typename T::iterator>;
    { c.size() } -> std::convertible_to<std::size_t>;
};

// 使用concept约束模板
template <Integral T>
T double_value(T x) { return x * 2; }

// 或者使用requires子句
template <typename T>
    requires Integral<T>
T triple_value(T x) { return x * 3; }

// 或者使用简写形式
void process(Integral auto x) {
    std::cout << x * 2 << '\n';
}

// concepts的好处：
// 1. 更清晰的语法
// 2. 更好的错误信息
// 3. 可以用于约束auto
// 4. 支持concept的与/或/非运算
```

**Week 2 练习项目**：

```cpp
// exercises/week2_sfinae.cpp
// 实现一个完整的类型检测库

#include <type_traits>
#include <iostream>
#include <vector>
#include <list>
#include <string>

namespace detect {

// 练习1：实现has_type检测器（检测嵌套类型）
// has_type<T, value_type>::value 检测T是否有value_type

// 练习2：实现has_method检测器（检测成员函数）
// has_method<T, void(int)>::push_back 检测T是否有push_back(int)

// 练习3：实现is_iterable
// 检测类型是否有begin()和end()

// 练习4：实现is_equality_comparable
// 检测类型是否支持==运算符

// 练习5：实现一个print函数
// - 如果类型有.str()方法，调用str()打印
// - 如果类型可以直接<<输出，直接输出
// - 否则输出"<unprintable>"

}

// 测试代码
void test_detection() {
    static_assert(detect::has_value_type<std::vector<int>>::value);
    static_assert(!detect::has_value_type<int>::value);

    static_assert(detect::is_iterable<std::vector<int>>::value);
    static_assert(detect::is_iterable<std::string>::value);
    static_assert(!detect::is_iterable<int>::value);

    static_assert(detect::is_equality_comparable<int>::value);
    static_assert(detect::is_equality_comparable<std::string>::value);
}
```

**本周检验标准**：
- [ ] 能解释SFINAE发生的时机和位置
- [ ] 理解enable_if三种用法的优缺点
- [ ] 能使用void_t实现自定义类型检测
- [ ] 理解is_detected检测惯用法
- [ ] 了解C++20 concepts的基本语法
- [ ] 能区分硬错误和SFINAE错误

### 第三周：type_traits深度分析

**学习目标**：理解标准库type_traits的实现原理

**阅读材料**：
- [ ] 《C++ Templates: The Complete Guide》第19章（Traits实现）
- [ ] GCC libstdc++ 源码：`bits/type_traits.h`, `type_traits`
- [ ] LLVM libc++ 源码：`type_traits`
- [ ] CppCon演讲："Modern Template Metaprogramming: A Compendium"

**阅读路径**（GCC libstdc++）：
- `bits/type_traits.h`
- `type_traits`

**每日学习安排**：

| 天数 | 主题 | 内容 | 练习 |
|------|------|------|------|
| Day 1 | integral_constant | 基础设施、true/false_type | 实现完整的integral_constant |
| Day 2 | 基本类型特征 | is_void, is_integral等 | 实现is_xxx系列 |
| Day 3 | 复合类型特征 | is_pointer, is_reference等 | 实现指针/引用检测 |
| Day 4 | 类型关系 | is_same, is_base_of等 | 实现类型关系检测 |
| Day 5 | 类型变换 | remove_cv, add_pointer等 | 实现类型变换系列 |
| Day 6 | 高级traits | decay, common_type等 | 实现decay完整版 |
| Day 7 | 综合项目 | 整合mini_type_traits | 完成Week3练习项目 |

**核心type_traits分类**：

#### 1. 基础设施：integral_constant

```cpp
// integral_constant是所有type_traits的基石
// 它将编译期常量包装成类型

template <typename T, T v>
struct integral_constant {
    static constexpr T value = v;
    using value_type = T;
    using type = integral_constant;  // 嵌套type指向自己

    // 隐式转换到value_type
    constexpr operator value_type() const noexcept { return value; }

    // 函数调用运算符（C++14）
    constexpr value_type operator()() const noexcept { return value; }
};

// 常用特化
using true_type = integral_constant<bool, true>;
using false_type = integral_constant<bool, false>;

// 使用示例
static_assert(true_type::value == true);
static_assert(true_type{}() == true);  // 可调用
static_assert(true_type{});            // 可隐式转换

// 为什么需要integral_constant？
// 1. 类型可以作为模板参数传递，值不能（C++17前）
// 2. 支持继承，方便组合多个traits
// 3. 提供统一的接口（::value, ::type）
```

#### 2. 基本类型分类（Primary Type Categories）

```cpp
// ========== is_void ==========
// 使用完整特化处理所有cv变体
template <typename T> struct is_void : false_type {};
template <> struct is_void<void> : true_type {};
template <> struct is_void<const void> : true_type {};
template <> struct is_void<volatile void> : true_type {};
template <> struct is_void<const volatile void> : true_type {};

// 更优雅的实现：使用remove_cv
template <typename T>
struct is_void : is_same<void, typename remove_cv<T>::type> {};

// ========== is_null_pointer（C++14）==========
template <typename T> struct is_null_pointer : false_type {};
template <> struct is_null_pointer<std::nullptr_t> : true_type {};
template <> struct is_null_pointer<const std::nullptr_t> : true_type {};
template <> struct is_null_pointer<volatile std::nullptr_t> : true_type {};
template <> struct is_null_pointer<const volatile std::nullptr_t> : true_type {};

// ========== is_integral ==========
// 需要枚举所有整数类型
template <typename T> struct is_integral_impl : false_type {};
template <> struct is_integral_impl<bool> : true_type {};
template <> struct is_integral_impl<char> : true_type {};
template <> struct is_integral_impl<signed char> : true_type {};
template <> struct is_integral_impl<unsigned char> : true_type {};
template <> struct is_integral_impl<wchar_t> : true_type {};
template <> struct is_integral_impl<char16_t> : true_type {};
template <> struct is_integral_impl<char32_t> : true_type {};
template <> struct is_integral_impl<short> : true_type {};
template <> struct is_integral_impl<unsigned short> : true_type {};
template <> struct is_integral_impl<int> : true_type {};
template <> struct is_integral_impl<unsigned int> : true_type {};
template <> struct is_integral_impl<long> : true_type {};
template <> struct is_integral_impl<unsigned long> : true_type {};
template <> struct is_integral_impl<long long> : true_type {};
template <> struct is_integral_impl<unsigned long long> : true_type {};
// C++20: char8_t

template <typename T>
struct is_integral : is_integral_impl<remove_cv_t<T>> {};

// ========== is_floating_point ==========
template <typename T> struct is_floating_point_impl : false_type {};
template <> struct is_floating_point_impl<float> : true_type {};
template <> struct is_floating_point_impl<double> : true_type {};
template <> struct is_floating_point_impl<long double> : true_type {};

template <typename T>
struct is_floating_point : is_floating_point_impl<remove_cv_t<T>> {};

// ========== 编译器内置traits ==========
// 某些traits无法用纯C++实现，必须使用编译器内置
template <typename T>
struct is_enum : integral_constant<bool, __is_enum(T)> {};

template <typename T>
struct is_union : integral_constant<bool, __is_union(T)> {};

template <typename T>
struct is_class : integral_constant<bool, __is_class(T)> {};

// 常见编译器内置（GCC/Clang）：
// __is_class, __is_enum, __is_union, __is_empty, __is_polymorphic
// __is_abstract, __is_final, __is_aggregate, __is_trivially_xxx
// __has_virtual_destructor, __is_base_of, __is_convertible_to
```

#### 3. 复合类型特征（Composite Type Categories）

```cpp
// ========== is_pointer ==========
// 部分特化匹配指针类型
template <typename T> struct is_pointer_impl : false_type {};
template <typename T> struct is_pointer_impl<T*> : true_type {};

template <typename T>
struct is_pointer : is_pointer_impl<remove_cv_t<T>> {};

// ⚠️ 注意：指向成员的指针不是is_pointer
// int C::* 是成员指针，不匹配 T*

// ========== is_member_pointer ==========
template <typename T> struct is_member_pointer_impl : false_type {};
template <typename T, typename C>
struct is_member_pointer_impl<T C::*> : true_type {};

template <typename T>
struct is_member_pointer : is_member_pointer_impl<remove_cv_t<T>> {};

// 细分：成员对象指针 vs 成员函数指针
template <typename T> struct is_member_object_pointer : false_type {};
template <typename T, typename C>
struct is_member_object_pointer<T C::*>
    : integral_constant<bool, !is_function<T>::value> {};

template <typename T> struct is_member_function_pointer : false_type {};
template <typename T, typename C>
struct is_member_function_pointer<T C::*>
    : integral_constant<bool, is_function<T>::value> {};

// ========== is_reference ==========
template <typename T> struct is_lvalue_reference : false_type {};
template <typename T> struct is_lvalue_reference<T&> : true_type {};

template <typename T> struct is_rvalue_reference : false_type {};
template <typename T> struct is_rvalue_reference<T&&> : true_type {};

template <typename T>
struct is_reference : integral_constant<bool,
    is_lvalue_reference<T>::value || is_rvalue_reference<T>::value> {};

// ========== is_array ==========
template <typename T> struct is_array : false_type {};
template <typename T> struct is_array<T[]> : true_type {};      // 未知边界
template <typename T, size_t N> struct is_array<T[N]> : true_type {}; // 已知边界

// ========== is_function（复杂！）==========
// 函数类型有多种形式：返回类型 + 参数列表 + cv限定 + ref限定 + noexcept + ...
// 最简单的实现：排除法
template <typename T>
struct is_function : integral_constant<bool,
    !is_const<const T>::value && !is_reference<T>::value> {};
// 原理：只有函数和引用类型不能加const

// 或者穷举所有函数签名（非常繁琐）
template <typename R, typename... Args>
struct is_function<R(Args...)> : true_type {};
template <typename R, typename... Args>
struct is_function<R(Args..., ...)> : true_type {};  // C variadic
template <typename R, typename... Args>
struct is_function<R(Args...) const> : true_type {};
template <typename R, typename... Args>
struct is_function<R(Args...) volatile> : true_type {};
template <typename R, typename... Args>
struct is_function<R(Args...) const volatile> : true_type {};
// ... 还有 &, &&, noexcept 等组合，C++17后有48种！
```

#### 4. 类型关系（Type Relationships）

```cpp
// ========== is_same ==========
template <typename T, typename U>
struct is_same : false_type {};

template <typename T>
struct is_same<T, T> : true_type {};

// ========== is_base_of ==========
// 纯C++实现（利用指针转换）
namespace detail {
    template <typename B>
    true_type test_ptr_conv(const volatile B*);
    template <typename>
    false_type test_ptr_conv(const volatile void*);

    template <typename B, typename D>
    auto test_is_base_of(int) -> decltype(test_ptr_conv<B>(static_cast<D*>(nullptr)));
    template <typename, typename>
    auto test_is_base_of(...) -> true_type;  // 不可访问的基类也返回true
}

template <typename Base, typename Derived>
struct is_base_of : integral_constant<bool,
    is_class<Base>::value &&
    is_class<Derived>::value &&
    decltype(detail::test_is_base_of<Base, Derived>(0))::value> {};

// 实际实现通常使用编译器内置
template <typename Base, typename Derived>
struct is_base_of : integral_constant<bool, __is_base_of(Base, Derived)> {};

// ========== is_convertible ==========
namespace detail {
    template <typename To>
    void test_convertible(To);  // 只声明

    template <typename From, typename To, typename = void>
    struct is_convertible_impl : false_type {};

    template <typename From, typename To>
    struct is_convertible_impl<From, To,
        void_t<decltype(test_convertible<To>(std::declval<From>()))>>
        : true_type {};
}

template <typename From, typename To>
struct is_convertible : detail::is_convertible_impl<From, To> {};

// 特殊情况处理
template <typename From>
struct is_convertible<From, void> : is_void<From> {};
```

#### 5. 类型变换（Type Modifications）

```cpp
// ========== remove_const / remove_volatile / remove_cv ==========
template <typename T> struct remove_const { using type = T; };
template <typename T> struct remove_const<const T> { using type = T; };

template <typename T> struct remove_volatile { using type = T; };
template <typename T> struct remove_volatile<volatile T> { using type = T; };

template <typename T> struct remove_cv {
    using type = typename remove_volatile<typename remove_const<T>::type>::type;
};

// ========== add_const / add_volatile / add_cv ==========
template <typename T> struct add_const { using type = const T; };
template <typename T> struct add_volatile { using type = volatile T; };
template <typename T> struct add_cv { using type = const volatile T; };

// ========== remove_reference ==========
template <typename T> struct remove_reference { using type = T; };
template <typename T> struct remove_reference<T&> { using type = T; };
template <typename T> struct remove_reference<T&&> { using type = T; };

// ========== add_lvalue_reference / add_rvalue_reference ==========
// 需要特殊处理void等不能引用的类型
namespace detail {
    template <typename T, typename = void>
    struct add_lvalue_reference { using type = T; };
    template <typename T>
    struct add_lvalue_reference<T, void_t<T&>> { using type = T&; };

    template <typename T, typename = void>
    struct add_rvalue_reference { using type = T; };
    template <typename T>
    struct add_rvalue_reference<T, void_t<T&&>> { using type = T&&; };
}

// ========== remove_pointer ==========
template <typename T> struct remove_pointer { using type = T; };
template <typename T> struct remove_pointer<T*> { using type = T; };
template <typename T> struct remove_pointer<T* const> { using type = T; };
template <typename T> struct remove_pointer<T* volatile> { using type = T; };
template <typename T> struct remove_pointer<T* const volatile> { using type = T; };

// ========== add_pointer ==========
template <typename T>
struct add_pointer {
    using type = typename remove_reference<T>::type*;
};

// ========== remove_extent（数组降维）==========
template <typename T> struct remove_extent { using type = T; };
template <typename T> struct remove_extent<T[]> { using type = T; };
template <typename T, size_t N> struct remove_extent<T[N]> { using type = T; };

// remove_all_extents 移除所有数组维度
template <typename T> struct remove_all_extents { using type = T; };
template <typename T> struct remove_all_extents<T[]>
    { using type = typename remove_all_extents<T>::type; };
template <typename T, size_t N> struct remove_all_extents<T[N]>
    { using type = typename remove_all_extents<T>::type; };
```

#### 6. 高级类型变换

```cpp
// ========== decay（模拟按值传递的类型退化）==========
template <typename T>
struct decay {
private:
    using U = typename remove_reference<T>::type;
public:
    using type = typename conditional<
        is_array<U>::value,
        typename remove_extent<U>::type*,  // 数组退化为指针
        typename conditional<
            is_function<U>::value,
            typename add_pointer<U>::type,  // 函数退化为函数指针
            typename remove_cv<U>::type     // 普通类型移除cv
        >::type
    >::type;
};

// 示例
// decay<int&>::type = int
// decay<const int>::type = int
// decay<int[10]>::type = int*
// decay<int(int)>::type = int(*)(int)

// ========== conditional ==========
template <bool B, typename T, typename F>
struct conditional { using type = T; };

template <typename T, typename F>
struct conditional<false, T, F> { using type = F; };

// ========== common_type ==========
// 计算多个类型的公共类型（类似三元运算符的类型推导）
template <typename... T>
struct common_type;

// 零参数
template <>
struct common_type<> {};

// 单参数
template <typename T>
struct common_type<T> {
    using type = typename decay<T>::type;
};

// 双参数（核心）
template <typename T1, typename T2>
struct common_type<T1, T2> {
    using type = typename decay<
        decltype(true ? std::declval<T1>() : std::declval<T2>())
    >::type;
};

// 多参数（递归）
template <typename T1, typename T2, typename... Rest>
struct common_type<T1, T2, Rest...> {
    using type = typename common_type<
        typename common_type<T1, T2>::type,
        Rest...
    >::type;
};

// ========== make_signed / make_unsigned ==========
// 将整数类型转换为有符号/无符号版本
template <typename T> struct make_signed;
template <> struct make_signed<char> { using type = signed char; };
template <> struct make_signed<unsigned char> { using type = signed char; };
template <> struct make_signed<unsigned short> { using type = short; };
template <> struct make_signed<unsigned int> { using type = int; };
template <> struct make_signed<unsigned long> { using type = long; };
template <> struct make_signed<unsigned long long> { using type = long long; };
// ... 有符号类型保持不变
```

**Week 3 练习项目**：

```cpp
// exercises/week3_type_traits.cpp
// 实现mini_type_traits库并测试

#include <iostream>
#include <type_traits>

namespace mini {

// 练习1：完整实现integral_constant和bool_constant

// 练习2：实现is_array，支持已知和未知边界

// 练习3：实现remove_all_extents
// remove_all_extents<int[2][3][4]>::type = int

// 练习4：实现is_function（使用排除法）

// 练习5：实现decay的完整版本

// 练习6：实现common_type（至少支持2个参数）

}

// 测试代码
void test_mini_traits() {
    // is_array测试
    static_assert(mini::is_array<int[10]>::value);
    static_assert(mini::is_array<int[]>::value);
    static_assert(!mini::is_array<int*>::value);

    // remove_all_extents测试
    static_assert(std::is_same_v<
        mini::remove_all_extents<int[2][3][4]>::type, int>);

    // decay测试
    static_assert(std::is_same_v<mini::decay<int&>::type, int>);
    static_assert(std::is_same_v<mini::decay<int[10]>::type, int*>);

    std::cout << "All tests passed!\n";
}
```

**本周检验标准**：
- [ ] 理解integral_constant的设计目的
- [ ] 能实现基本的类型分类traits
- [ ] 理解哪些traits需要编译器内置支持
- [ ] 能实现类型变换traits
- [ ] 理解decay的完整行为
- [ ] 能实现conditional和common_type

### 第四周：constexpr与编译期计算

**学习目标**：掌握constexpr的能力和限制，理解编译期计算的边界

**阅读材料**：
- [ ] 《C++ Templates: The Complete Guide》第23章（编译期编程）
- [ ] 《Effective Modern C++》Item 15（尽可能使用constexpr）
- [ ] CppCon演讲："constexpr ALL the Things!" by Jason Turner
- [ ] CppCon演讲："C++20 Constexpr" by Klaus Iglberger

**每日学习安排**：

| 天数 | 主题 | 内容 | 练习 |
|------|------|------|------|
| Day 1 | constexpr基础 | 变量、函数的constexpr规则 | 实现编译期阶乘、斐波那契 |
| Day 2 | C++14 constexpr | 循环、局部变量支持 | 实现编译期排序 |
| Day 3 | if constexpr | 编译期分支、模板特化替代 | 重写Week2的SFINAE代码 |
| Day 4 | constexpr容器 | std::array、编译期字符串 | 实现ConstString类 |
| Day 5 | consteval/constinit | C++20新特性、立即函数 | 体验C++20编译期特性 |
| Day 6 | 编译期算法 | 编译期查找、哈希、解析 | 实现编译期JSON解析器 |
| Day 7 | 综合项目 | 完成constexpr_string.hpp | 完成Week4练习项目 |

**核心概念**：

#### 1. constexpr的演进历史

```cpp
// ==================== C++11 constexpr ====================
// 限制非常严格：
// - 函数体只能有单条return语句
// - 不能有循环、局部变量、if语句
// - 不能有静态变量、线程局部变量

constexpr int factorial_11(int n) {
    return n <= 1 ? 1 : n * factorial_11(n - 1);  // 只能用递归
}

// ==================== C++14 constexpr ====================
// 大幅放宽：
// - 允许多条语句
// - 允许局部变量（非static）
// - 允许循环（for, while, do-while）
// - 允许条件语句（if, switch）
// - 允许修改局部变量

constexpr int factorial_14(int n) {
    int result = 1;
    for (int i = 2; i <= n; ++i) {
        result *= i;
    }
    return result;
}

// ==================== C++17 constexpr ====================
// - if constexpr 编译期分支
// - constexpr lambda
// - 更多标准库函数变为constexpr

constexpr auto lambda = [](int x) { return x * 2; };
static_assert(lambda(21) == 42);

// ==================== C++20 constexpr ====================
// 接近完整的运行时能力：
// - try-catch（但不能真正抛出）
// - 虚函数调用
// - dynamic_cast, typeid
// - new/delete（受限的动态内存）
// - std::vector, std::string 变为constexpr
// - consteval（立即函数）
// - constinit（强制静态初始化）

constexpr int cpp20_example() {
    std::vector<int> v{1, 2, 3};  // C++20: constexpr vector
    v.push_back(4);
    int sum = 0;
    for (int x : v) sum += x;
    return sum;
}
static_assert(cpp20_example() == 10);
```

#### 2. constexpr变量的规则

```cpp
// constexpr变量必须在编译期初始化
constexpr int a = 42;           // OK
constexpr int b = a + 1;        // OK，a是constexpr
constexpr int c = factorial(5); // OK，factorial是constexpr函数

int runtime_value = get_value();
// constexpr int d = runtime_value;  // 错误！不是编译期常量

// const vs constexpr
const int x = 42;      // 可能是编译期，也可能是运行期
constexpr int y = 42;  // 保证是编译期

// 指针和constexpr
constexpr int* p1 = nullptr;  // OK，p1是constexpr指针
int value = 42;
// constexpr int* p2 = &value;  // 错误！运行期地址

// constexpr指向的是指针本身，不是指向的值
static int static_val = 100;
constexpr int* p3 = &static_val;  // OK，静态存储期对象的地址是常量
// *p3 = 200;  // 可以修改！p3是constexpr但指向的不是const

// 注意区分
constexpr const int* p4 = &static_val;  // 指向const int的constexpr指针
// *p4 = 200;  // 错误！不能修改
```

#### 3. constexpr函数的约束与技巧

```cpp
// constexpr函数可以在编译期或运行期调用
constexpr int square(int n) { return n * n; }

constexpr int a = square(5);  // 编译期
int b = square(rand());       // 运行期

// 如何强制编译期求值？
// 方法1：赋值给constexpr变量
constexpr int result1 = square(5);

// 方法2：用于模板参数
std::array<int, square(5)> arr;

// 方法3：用于static_assert
static_assert(square(5) == 25);

// 方法4：使用std::integral_constant
using Result = std::integral_constant<int, square(5)>;

// constexpr函数中的限制（C++14/17）
constexpr int bad_example(int n) {
    // static int counter = 0;  // 错误！不能有static变量
    // thread_local int x;      // 错误！不能有thread_local
    // asm("...");              // 错误！不能有内联汇编
    // goto label;              // 错误！不能有goto

    // 以下在C++17前也是错误的：
    // try { } catch(...) { }   // C++20才支持（受限）
    return n;
}

// 递归深度限制
// 编译器对constexpr递归深度有限制（通常512或更多）
constexpr int fib(int n) {
    if (n <= 1) return n;
    return fib(n - 1) + fib(n - 2);
}
// constexpr int big = fib(1000);  // 可能超过递归深度限制

// 优化：使用循环代替递归
constexpr int fib_loop(int n) {
    if (n <= 1) return n;
    int a = 0, b = 1;
    for (int i = 2; i <= n; ++i) {
        int tmp = a + b;
        a = b;
        b = tmp;
    }
    return b;
}
```

#### 4. if constexpr：编译期条件分支

```cpp
// if constexpr的条件必须是编译期布尔表达式
// 不满足条件的分支不会被实例化（重要！）

template <typename T>
auto get_value(T t) {
    if constexpr (std::is_pointer_v<T>) {
        return *t;  // 只有T是指针时才编译这行
    } else {
        return t;
    }
}

int x = 42;
int* p = &x;
auto a = get_value(x);  // 返回 int
auto b = get_value(p);  // 返回 int（解引用）

// 与普通if的区别
template <typename T>
auto bad_get_value(T t) {
    if (std::is_pointer_v<T>) {
        return *t;  // 错误！即使T不是指针，这行也会尝试编译
    } else {
        return t;
    }
}

// if constexpr的典型应用

// 1. 替代SFINAE
template <typename T>
void print(const T& value) {
    if constexpr (std::is_integral_v<T>) {
        std::cout << "Integer: " << value << '\n';
    } else if constexpr (std::is_floating_point_v<T>) {
        std::cout << "Float: " << std::fixed << value << '\n';
    } else if constexpr (requires { value.c_str(); }) {  // C++20 requires
        std::cout << "String: " << value.c_str() << '\n';
    } else {
        std::cout << "Unknown type\n";
    }
}

// 2. 编译期展开递归
template <size_t N, typename T, typename... Ts>
auto sum_tuple(const std::tuple<T, Ts...>& t) {
    if constexpr (N == 0) {
        return std::get<0>(t);
    } else {
        return std::get<N>(t) + sum_tuple<N - 1>(t);
    }
}

// 3. 条件性地定义成员
template <typename T>
struct OptionalRef {
    T* ptr;

    decltype(auto) operator*() {
        if constexpr (std::is_const_v<T>) {
            return std::as_const(*ptr);
        } else {
            return *ptr;
        }
    }
};
```

#### 5. consteval与constinit（C++20）

```cpp
// ==================== consteval（立即函数）====================
// consteval函数必须在编译期求值，否则编译错误

consteval int square_immediate(int n) {
    return n * n;
}

constexpr int a = square_immediate(5);  // OK，编译期
// int b = square_immediate(rand());    // 错误！必须编译期

// consteval的应用：强制编译期计算
consteval auto make_constant(auto value) {
    return value;
}

// 确保复杂计算在编译期完成
constexpr auto pi = make_constant(3.14159265358979323846);

// consteval可以调用constexpr，但反过来不行
constexpr int foo(int x) { return x + 1; }
consteval int bar(int x) { return foo(x) + 1; }  // OK
// constexpr int baz(int x) { return bar(x) + 1; }  // 错误！

// ==================== constinit（静态初始化保证）====================
// constinit确保变量在静态初始化阶段初始化（避免SIOF问题）

constinit int global_a = 42;           // OK
constinit int global_b = square(5);    // OK，square是constexpr

int get_value_runtime() { return 42; }
// constinit int global_c = get_value_runtime();  // 错误！

// constinit vs constexpr
// constexpr: 变量是const，值在编译期确定
// constinit: 只保证静态初始化，变量不一定是const

constinit int mutable_global = 100;
void modify() {
    mutable_global = 200;  // OK，constinit不是const
}

// constinit解决的问题：静态初始化顺序灾难（SIOF）
// file1.cpp
constinit int x = 42;

// file2.cpp
// 如果没有constinit，y的初始化可能在x之前
// extern int x;
// int y = x + 1;  // 可能是1（如果x还未初始化）

// constinit保证x在程序启动前就已初始化
```

#### 6. 编译期数据结构

```cpp
// ==================== std::array的constexpr用法 ====================
constexpr std::array<int, 5> arr = {1, 2, 3, 4, 5};
static_assert(arr[2] == 3);
static_assert(arr.size() == 5);

// 编译期构建数组
template <size_t N>
constexpr std::array<int, N> make_sequence() {
    std::array<int, N> result{};
    for (size_t i = 0; i < N; ++i) {
        result[i] = i * i;
    }
    return result;
}

constexpr auto squares = make_sequence<10>();
static_assert(squares[3] == 9);
static_assert(squares[5] == 25);

// ==================== 编译期字符串 ====================
template <size_t N>
struct ConstString {
    char data[N]{};
    size_t len = N - 1;

    constexpr ConstString(const char (&str)[N]) {
        for (size_t i = 0; i < N; ++i) {
            data[i] = str[i];
        }
    }

    constexpr size_t size() const { return len; }
    constexpr char operator[](size_t i) const { return data[i]; }

    constexpr bool operator==(const ConstString& other) const {
        if (len != other.len) return false;
        for (size_t i = 0; i < len; ++i) {
            if (data[i] != other.data[i]) return false;
        }
        return true;
    }

    // 用作非类型模板参数（C++20）
    constexpr operator const char*() const { return data; }
};

// 推导指引
template <size_t N>
ConstString(const char (&)[N]) -> ConstString<N>;

// 使用
constexpr ConstString hello = "Hello";
constexpr ConstString world = "World";
static_assert(hello.size() == 5);
static_assert(hello[0] == 'H');

// 编译期字符串拼接
template <size_t N1, size_t N2>
constexpr auto concat(const ConstString<N1>& s1, const ConstString<N2>& s2) {
    char result[N1 + N2 - 1]{};
    for (size_t i = 0; i < N1 - 1; ++i) result[i] = s1[i];
    for (size_t i = 0; i < N2; ++i) result[N1 - 1 + i] = s2[i];
    return ConstString<N1 + N2 - 1>(result);
}
```

#### 7. 编译期算法

```cpp
// 编译期查找
template <typename T, size_t N>
constexpr int find(const std::array<T, N>& arr, const T& value) {
    for (size_t i = 0; i < N; ++i) {
        if (arr[i] == value) return static_cast<int>(i);
    }
    return -1;
}

constexpr std::array<int, 5> nums = {10, 20, 30, 40, 50};
static_assert(find(nums, 30) == 2);
static_assert(find(nums, 99) == -1);

// 编译期排序（插入排序）
template <typename T, size_t N>
constexpr std::array<T, N> sort(std::array<T, N> arr) {
    for (size_t i = 1; i < N; ++i) {
        T key = arr[i];
        size_t j = i;
        while (j > 0 && arr[j - 1] > key) {
            arr[j] = arr[j - 1];
            --j;
        }
        arr[j] = key;
    }
    return arr;
}

constexpr auto unsorted = std::array{5, 2, 8, 1, 9};
constexpr auto sorted = sort(unsorted);
static_assert(sorted[0] == 1);
static_assert(sorted[4] == 9);

// 编译期哈希（FNV-1a）
constexpr size_t fnv1a_hash(const char* str, size_t len) {
    size_t hash = 14695981039346656037ULL;
    for (size_t i = 0; i < len; ++i) {
        hash ^= static_cast<size_t>(str[i]);
        hash *= 1099511628211ULL;
    }
    return hash;
}

template <size_t N>
constexpr size_t hash(const ConstString<N>& s) {
    return fnv1a_hash(s.data, s.size());
}

// 编译期字符串哈希用于switch
constexpr size_t operator""_hash(const char* str, size_t len) {
    return fnv1a_hash(str, len);
}

void handle_command(const std::string& cmd) {
    switch (fnv1a_hash(cmd.c_str(), cmd.size())) {
        case "help"_hash:    std::cout << "Help!\n"; break;
        case "version"_hash: std::cout << "1.0.0\n"; break;
        case "exit"_hash:    std::cout << "Bye!\n"; break;
        default:             std::cout << "Unknown\n";
    }
}
```

**Week 4 练习项目**：

```cpp
// exercises/week4_constexpr.cpp
// 编译期计算综合练习

#include <array>
#include <iostream>

// 练习1：实现编译期素数判断
constexpr bool is_prime(int n);

// 练习2：实现编译期生成素数表
template <size_t N>
constexpr auto generate_primes();
// generate_primes<100>() 返回100以内的所有素数

// 练习3：实现编译期字符串反转
template <size_t N>
constexpr ConstString<N> reverse(const ConstString<N>& s);

// 练习4：实现编译期二分查找
template <typename T, size_t N>
constexpr int binary_search(const std::array<T, N>& arr, const T& value);

// 练习5：实现编译期解析整数字符串
// parse_int("12345") -> 12345
constexpr int parse_int(const char* str);

// 练习6：实现编译期格式化（简化版）
// format<"Hello {}">("World") -> "Hello World"

// 测试
void test_constexpr() {
    static_assert(is_prime(17));
    static_assert(!is_prime(18));

    constexpr auto primes = generate_primes<50>();
    // primes应该是 {2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47}

    constexpr ConstString original = "Hello";
    constexpr auto reversed = reverse(original);
    static_assert(reversed == ConstString("olleH"));

    static_assert(parse_int("12345") == 12345);
    static_assert(parse_int("-42") == -42);

    std::cout << "All constexpr tests passed!\n";
}
```

**本周检验标准**：
- [ ] 理解constexpr在C++11/14/17/20的演进
- [ ] 能正确使用if constexpr替代SFINAE
- [ ] 理解consteval和constinit的区别
- [ ] 能实现编译期数据结构（字符串、数组）
- [ ] 能实现基本的编译期算法
- [ ] 理解编译期计算的性能和限制

---

## 源码阅读任务

### 深度阅读清单

#### Week 1 源码阅读
- [ ] `std::decay` 实现（GCC: `type_traits`, line ~2000）
  - 理解数组退化、函数退化的实现
  - 注意如何处理引用和cv限定符

- [ ] `std::declval` 实现（GCC: `type_traits`）
  - 为什么不需要定义，只需要声明？
  - 如何避免默认构造函数的要求？

```cpp
// declval的典型实现
template <typename T>
typename add_rvalue_reference<T>::type declval() noexcept;
// 只声明不定义，只能在不求值上下文使用
```

#### Week 2 源码阅读
- [ ] `std::enable_if` 实现
- [ ] `std::void_t` 实现及其在检测惯用法中的应用
- [ ] `std::is_invocable` / `std::invoke_result` 实现

```cpp
// 阅读重点：is_invocable如何处理各种可调用对象
// - 普通函数
// - 函数指针
// - 成员函数指针
// - 函数对象
// - lambda
```

#### Week 3 源码阅读
- [ ] `std::conditional` 实现
- [ ] `std::conjunction` / `std::disjunction` 短路实现

```cpp
// conjunction的短路实现（重点理解）
template <typename...> struct conjunction : true_type {};
template <typename B1> struct conjunction<B1> : B1 {};
template <typename B1, typename... Bn>
struct conjunction<B1, Bn...>
    : conditional_t<bool(B1::value), conjunction<Bn...>, B1> {};
// 为什么这样实现可以短路？
// 当B1::value为false时，不会实例化conjunction<Bn...>
```

- [ ] `std::invoke` 实现（处理各种可调用对象）

```cpp
// invoke需要处理的情况：
// 1. f(args...) - 普通函数/函数对象
// 2. (obj.*f)(args...) - 成员函数+对象
// 3. (ptr->*f)(args...) - 成员函数+指针
// 4. obj.*pm - 成员数据+对象
// 5. ptr->*pm - 成员数据+指针
```

#### Week 4 源码阅读
- [ ] `std::function` 类型擦除实现
  - 理解类型擦除的设计模式
  - 小对象优化（SBO）如何实现
  - 理解callable的存储和调用机制

- [ ] `std::tuple` 的实现
  - 递归继承 vs 多重继承
  - `std::get<N>` 如何工作
  - `std::tuple_element` 的实现

### 源码阅读技巧

```bash
# 查找GCC标准库源码
# macOS: /usr/local/include/c++/版本号/
# Linux: /usr/include/c++/版本号/

# 使用grep查找实现
grep -r "struct decay" /usr/include/c++/

# 使用clang查看模板实例化
clang++ -Xclang -ast-dump -fsyntax-only test.cpp

# 使用GCC查看预处理后的结果
g++ -E -P test.cpp | less
```

---

## 实践项目

### 项目：实现mini_type_traits库

**目标**：实现一套基本的类型特征库

```cpp
// mini_type_traits.hpp
#pragma once

namespace mini {

// ==================== 基础设施 ====================

// integral_constant
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

// ==================== 基本类型特征 ====================

// is_void
template <typename T> struct is_void : false_type {};
template <> struct is_void<void> : true_type {};
template <> struct is_void<const void> : true_type {};
template <> struct is_void<volatile void> : true_type {};
template <> struct is_void<const volatile void> : true_type {};

template <typename T>
inline constexpr bool is_void_v = is_void<T>::value;

// is_null_pointer
template <typename T> struct is_null_pointer : false_type {};
template <> struct is_null_pointer<std::nullptr_t> : true_type {};
template <> struct is_null_pointer<const std::nullptr_t> : true_type {};

// is_integral
template <typename T> struct is_integral : false_type {};
template <> struct is_integral<bool> : true_type {};
template <> struct is_integral<char> : true_type {};
template <> struct is_integral<signed char> : true_type {};
template <> struct is_integral<unsigned char> : true_type {};
template <> struct is_integral<short> : true_type {};
template <> struct is_integral<unsigned short> : true_type {};
template <> struct is_integral<int> : true_type {};
template <> struct is_integral<unsigned int> : true_type {};
template <> struct is_integral<long> : true_type {};
template <> struct is_integral<unsigned long> : true_type {};
template <> struct is_integral<long long> : true_type {};
template <> struct is_integral<unsigned long long> : true_type {};
// 需要处理cv限定版本...

template <typename T>
inline constexpr bool is_integral_v = is_integral<std::remove_cv_t<T>>::value;

// is_floating_point
template <typename T> struct is_floating_point : false_type {};
template <> struct is_floating_point<float> : true_type {};
template <> struct is_floating_point<double> : true_type {};
template <> struct is_floating_point<long double> : true_type {};

template <typename T>
inline constexpr bool is_floating_point_v = is_floating_point<std::remove_cv_t<T>>::value;

// is_arithmetic
template <typename T>
struct is_arithmetic : integral_constant<bool,
    is_integral_v<T> || is_floating_point_v<T>> {};

// is_pointer
template <typename T> struct is_pointer : false_type {};
template <typename T> struct is_pointer<T*> : true_type {};
template <typename T> struct is_pointer<T* const> : true_type {};
template <typename T> struct is_pointer<T* volatile> : true_type {};
template <typename T> struct is_pointer<T* const volatile> : true_type {};

// is_reference
template <typename T> struct is_lvalue_reference : false_type {};
template <typename T> struct is_lvalue_reference<T&> : true_type {};

template <typename T> struct is_rvalue_reference : false_type {};
template <typename T> struct is_rvalue_reference<T&&> : true_type {};

template <typename T>
struct is_reference : integral_constant<bool,
    is_lvalue_reference<T>::value || is_rvalue_reference<T>::value> {};

// ==================== 类型关系 ====================

// is_same
template <typename T, typename U> struct is_same : false_type {};
template <typename T> struct is_same<T, T> : true_type {};

template <typename T, typename U>
inline constexpr bool is_same_v = is_same<T, U>::value;

// ==================== 类型变换 ====================

// remove_const
template <typename T> struct remove_const { using type = T; };
template <typename T> struct remove_const<const T> { using type = T; };
template <typename T> using remove_const_t = typename remove_const<T>::type;

// remove_volatile
template <typename T> struct remove_volatile { using type = T; };
template <typename T> struct remove_volatile<volatile T> { using type = T; };
template <typename T> using remove_volatile_t = typename remove_volatile<T>::type;

// remove_cv
template <typename T> struct remove_cv {
    using type = remove_volatile_t<remove_const_t<T>>;
};
template <typename T> using remove_cv_t = typename remove_cv<T>::type;

// remove_reference
template <typename T> struct remove_reference { using type = T; };
template <typename T> struct remove_reference<T&> { using type = T; };
template <typename T> struct remove_reference<T&&> { using type = T; };
template <typename T> using remove_reference_t = typename remove_reference<T>::type;

// remove_cvref (C++20)
template <typename T> struct remove_cvref {
    using type = remove_cv_t<remove_reference_t<T>>;
};
template <typename T> using remove_cvref_t = typename remove_cvref<T>::type;

// add_const, add_volatile, add_cv
template <typename T> struct add_const { using type = const T; };
template <typename T> struct add_volatile { using type = volatile T; };
template <typename T> struct add_cv { using type = const volatile T; };

// add_lvalue_reference, add_rvalue_reference
// 需要处理void等特殊情况
template <typename T, typename = void>
struct add_lvalue_reference { using type = T; };
template <typename T>
struct add_lvalue_reference<T, std::void_t<T&>> { using type = T&; };

template <typename T, typename = void>
struct add_rvalue_reference { using type = T; };
template <typename T>
struct add_rvalue_reference<T, std::void_t<T&&>> { using type = T&&; };

// add_pointer
template <typename T>
struct add_pointer {
    using type = remove_reference_t<T>*;
};
template <typename T> using add_pointer_t = typename add_pointer<T>::type;

// ==================== conditional ====================

template <bool B, typename T, typename F>
struct conditional { using type = T; };

template <typename T, typename F>
struct conditional<false, T, F> { using type = F; };

template <bool B, typename T, typename F>
using conditional_t = typename conditional<B, T, F>::type;

// ==================== enable_if ====================

template <bool B, typename T = void>
struct enable_if {};

template <typename T>
struct enable_if<true, T> { using type = T; };

template <bool B, typename T = void>
using enable_if_t = typename enable_if<B, T>::type;

// ==================== void_t ====================

template <typename...>
using void_t = void;

// ==================== 检测惯用法 ====================

// 检测是否有size_type成员
template <typename, typename = void>
struct has_size_type : false_type {};

template <typename T>
struct has_size_type<T, void_t<typename T::size_type>> : true_type {};

// 检测是否有特定成员函数
template <typename T, typename = void>
struct has_size_method : false_type {};

template <typename T>
struct has_size_method<T, void_t<decltype(std::declval<T>().size())>> : true_type {};

// ==================== conjunction/disjunction ====================

template <typename...> struct conjunction : true_type {};
template <typename B1> struct conjunction<B1> : B1 {};
template <typename B1, typename... Bn>
struct conjunction<B1, Bn...>
    : conditional_t<bool(B1::value), conjunction<Bn...>, B1> {};

template <typename...> struct disjunction : false_type {};
template <typename B1> struct disjunction<B1> : B1 {};
template <typename B1, typename... Bn>
struct disjunction<B1, Bn...>
    : conditional_t<bool(B1::value), B1, disjunction<Bn...>> {};

template <typename B>
struct negation : integral_constant<bool, !bool(B::value)> {};

} // namespace mini
```

### 项目：编译期字符串处理

```cpp
// constexpr_string.hpp
#pragma once
#include <array>
#include <cstddef>
#include <string_view>

namespace cstr {

// ==================== 基础ConstString ====================
template <size_t N>
struct ConstString {
    char data[N]{};

    constexpr ConstString() = default;

    constexpr ConstString(const char (&str)[N]) {
        for (size_t i = 0; i < N; ++i) {
            data[i] = str[i];
        }
    }

    constexpr size_t size() const noexcept { return N - 1; }
    constexpr size_t length() const noexcept { return N - 1; }
    constexpr bool empty() const noexcept { return N == 1; }

    constexpr char operator[](size_t i) const { return data[i]; }
    constexpr char at(size_t i) const {
        return i < size() ? data[i] : throw std::out_of_range("Index out of range");
    }

    constexpr char front() const { return data[0]; }
    constexpr char back() const { return data[N - 2]; }

    constexpr const char* c_str() const noexcept { return data; }
    constexpr const char* begin() const noexcept { return data; }
    constexpr const char* end() const noexcept { return data + size(); }

    constexpr operator std::string_view() const noexcept {
        return std::string_view(data, size());
    }

    // 比较操作
    template <size_t M>
    constexpr bool operator==(const ConstString<M>& other) const {
        if constexpr (N != M) return false;
        for (size_t i = 0; i < N; ++i) {
            if (data[i] != other.data[i]) return false;
        }
        return true;
    }

    template <size_t M>
    constexpr bool operator!=(const ConstString<M>& other) const {
        return !(*this == other);
    }

    template <size_t M>
    constexpr bool operator<(const ConstString<M>& other) const {
        size_t min_len = (size() < other.size()) ? size() : other.size();
        for (size_t i = 0; i < min_len; ++i) {
            if (data[i] < other.data[i]) return true;
            if (data[i] > other.data[i]) return false;
        }
        return size() < other.size();
    }

    // 子串操作
    template <size_t Start, size_t Len>
    constexpr auto substr() const {
        static_assert(Start <= N - 1, "Start position out of range");
        constexpr size_t actual_len = (Start + Len > N - 1) ? (N - 1 - Start) : Len;
        ConstString<actual_len + 1> result;
        for (size_t i = 0; i < actual_len; ++i) {
            result.data[i] = data[Start + i];
        }
        result.data[actual_len] = '\0';
        return result;
    }

    // 查找
    constexpr size_t find(char c, size_t pos = 0) const {
        for (size_t i = pos; i < size(); ++i) {
            if (data[i] == c) return i;
        }
        return static_cast<size_t>(-1);  // npos
    }

    constexpr bool contains(char c) const {
        return find(c) != static_cast<size_t>(-1);
    }

    constexpr bool starts_with(char c) const {
        return size() > 0 && data[0] == c;
    }

    constexpr bool ends_with(char c) const {
        return size() > 0 && data[size() - 1] == c;
    }
};

// 推导指引
template <size_t N>
ConstString(const char (&)[N]) -> ConstString<N>;

// ==================== 字符串操作函数 ====================

// 拼接两个字符串
template <size_t N1, size_t N2>
constexpr auto concat(const ConstString<N1>& s1, const ConstString<N2>& s2) {
    ConstString<N1 + N2 - 1> result;
    for (size_t i = 0; i < N1 - 1; ++i) result.data[i] = s1[i];
    for (size_t i = 0; i < N2; ++i) result.data[N1 - 1 + i] = s2[i];
    return result;
}

// 操作符重载
template <size_t N1, size_t N2>
constexpr auto operator+(const ConstString<N1>& s1, const ConstString<N2>& s2) {
    return concat(s1, s2);
}

// 反转字符串
template <size_t N>
constexpr ConstString<N> reverse(const ConstString<N>& s) {
    ConstString<N> result;
    for (size_t i = 0; i < s.size(); ++i) {
        result.data[i] = s.data[s.size() - 1 - i];
    }
    result.data[s.size()] = '\0';
    return result;
}

// 转大写
template <size_t N>
constexpr ConstString<N> to_upper(const ConstString<N>& s) {
    ConstString<N> result;
    for (size_t i = 0; i < N; ++i) {
        char c = s.data[i];
        result.data[i] = (c >= 'a' && c <= 'z') ? (c - 32) : c;
    }
    return result;
}

// 转小写
template <size_t N>
constexpr ConstString<N> to_lower(const ConstString<N>& s) {
    ConstString<N> result;
    for (size_t i = 0; i < N; ++i) {
        char c = s.data[i];
        result.data[i] = (c >= 'A' && c <= 'Z') ? (c + 32) : c;
    }
    return result;
}

// ==================== 哈希函数 ====================

// FNV-1a 哈希
constexpr size_t fnv1a_hash(const char* str, size_t len) {
    size_t hash = 14695981039346656037ULL;
    for (size_t i = 0; i < len; ++i) {
        hash ^= static_cast<size_t>(str[i]);
        hash *= 1099511628211ULL;
    }
    return hash;
}

template <size_t N>
constexpr size_t hash(const ConstString<N>& s) {
    return fnv1a_hash(s.data, s.size());
}

// 用户定义字面量
constexpr size_t operator""_hash(const char* str, size_t len) {
    return fnv1a_hash(str, len);
}

// ==================== 编译期字符串解析 ====================

// 解析整数
constexpr int parse_int(const char* str, size_t len) {
    if (len == 0) return 0;

    int sign = 1;
    size_t start = 0;

    if (str[0] == '-') {
        sign = -1;
        start = 1;
    } else if (str[0] == '+') {
        start = 1;
    }

    int result = 0;
    for (size_t i = start; i < len; ++i) {
        if (str[i] < '0' || str[i] > '9') break;
        result = result * 10 + (str[i] - '0');
    }
    return sign * result;
}

template <size_t N>
constexpr int parse_int(const ConstString<N>& s) {
    return parse_int(s.data, s.size());
}

// 整数转字符串（编译期）
template <int Value>
constexpr auto to_string() {
    constexpr auto abs_value = Value < 0 ? -Value : Value;
    constexpr auto digits = []() {
        int v = abs_value;
        int count = (v == 0) ? 1 : 0;
        while (v > 0) { ++count; v /= 10; }
        return count;
    }();
    constexpr auto len = digits + (Value < 0 ? 1 : 0) + 1;

    ConstString<len> result;
    int v = abs_value;
    size_t pos = len - 2;
    do {
        result.data[pos--] = '0' + (v % 10);
        v /= 10;
    } while (v > 0);
    if (Value < 0) result.data[pos] = '-';
    result.data[len - 1] = '\0';
    return result;
}

} // namespace cstr
```

### 项目：类型检测综合库

```cpp
// type_detection.hpp
#pragma once
#include <type_traits>
#include <utility>

namespace detect {

// ==================== 通用检测框架 ====================

// nonesuch: 表示检测失败的类型
struct nonesuch {
    nonesuch() = delete;
    ~nonesuch() = delete;
    nonesuch(const nonesuch&) = delete;
    void operator=(const nonesuch&) = delete;
};

// detector实现
namespace detail {
    template <typename Default, typename AlwaysVoid,
              template<typename...> class Op, typename... Args>
    struct detector {
        using value_t = std::false_type;
        using type = Default;
    };

    template <typename Default, template<typename...> class Op, typename... Args>
    struct detector<Default, std::void_t<Op<Args...>>, Op, Args...> {
        using value_t = std::true_type;
        using type = Op<Args...>;
    };
}

// 公共接口
template <template<typename...> class Op, typename... Args>
using is_detected = typename detail::detector<nonesuch, void, Op, Args...>::value_t;

template <template<typename...> class Op, typename... Args>
using detected_t = typename detail::detector<nonesuch, void, Op, Args...>::type;

template <typename Default, template<typename...> class Op, typename... Args>
using detected_or = detail::detector<Default, void, Op, Args...>;

template <typename Default, template<typename...> class Op, typename... Args>
using detected_or_t = typename detected_or<Default, Op, Args...>::type;

template <template<typename...> class Op, typename... Args>
inline constexpr bool is_detected_v = is_detected<Op, Args...>::value;

// ==================== 常用检测器 ====================

// 检测嵌套类型
template <typename T> using value_type_t = typename T::value_type;
template <typename T> using iterator_t = typename T::iterator;
template <typename T> using const_iterator_t = typename T::const_iterator;
template <typename T> using size_type_t = typename T::size_type;
template <typename T> using difference_type_t = typename T::difference_type;
template <typename T> using pointer_t = typename T::pointer;
template <typename T> using reference_t = typename T::reference;

// 检测成员函数
template <typename T>
using has_begin = decltype(std::declval<T>().begin());

template <typename T>
using has_end = decltype(std::declval<T>().end());

template <typename T>
using has_size = decltype(std::declval<T>().size());

template <typename T>
using has_empty = decltype(std::declval<T>().empty());

template <typename T, typename V = typename T::value_type>
using has_push_back = decltype(std::declval<T>().push_back(std::declval<V>()));

template <typename T>
using has_reserve = decltype(std::declval<T>().reserve(std::declval<size_t>()));

template <typename T>
using has_clear = decltype(std::declval<T>().clear());

// ==================== 复合检测 ====================

// 是否是可迭代类型
template <typename T>
struct is_iterable : std::conjunction<
    is_detected<has_begin, T>,
    is_detected<has_end, T>
> {};

template <typename T>
inline constexpr bool is_iterable_v = is_iterable<T>::value;

// 是否是容器类型
template <typename T>
struct is_container : std::conjunction<
    is_detected<value_type_t, T>,
    is_detected<iterator_t, T>,
    is_detected<has_begin, T>,
    is_detected<has_end, T>,
    is_detected<has_size, T>
> {};

template <typename T>
inline constexpr bool is_container_v = is_container<T>::value;

// 是否可以==比较
template <typename T, typename U = T>
using equality_comparable = decltype(std::declval<T>() == std::declval<U>());

template <typename T, typename U = T>
inline constexpr bool is_equality_comparable_v = is_detected_v<equality_comparable, T, U>;

// 是否可调用
template <typename F, typename... Args>
using is_callable = decltype(std::declval<F>()(std::declval<Args>()...));

template <typename F, typename... Args>
inline constexpr bool is_callable_v = is_detected_v<is_callable, F, Args...>;

// ==================== 智能打印函数 ====================

template <typename T>
void smart_print(const T& value) {
    if constexpr (is_detected_v<has_str, T>) {
        // 如果有str()方法
        std::cout << value.str();
    } else if constexpr (std::is_arithmetic_v<T>) {
        // 算术类型
        std::cout << value;
    } else if constexpr (is_iterable_v<T>) {
        // 可迭代类型
        std::cout << "[";
        bool first = true;
        for (const auto& item : value) {
            if (!first) std::cout << ", ";
            smart_print(item);
            first = false;
        }
        std::cout << "]";
    } else {
        std::cout << "<unknown type>";
    }
}

} // namespace detect
```

---

## 检验标准

### 知识检验

#### 第一周检验题目
1. 解释以下代码中T的推导结果：
```cpp
template <typename T> void f(T&& param);
int x = 42;
const int cx = x;
f(x);       // T = ?
f(cx);      // T = ?
f(42);      // T = ?
f(std::move(x));  // T = ?
```

2. `decltype(x)` 和 `decltype((x))` 有什么区别？为什么？

3. 什么是引用折叠？写出四条引用折叠规则。

#### 第二周检验题目
1. SFINAE是什么的缩写？它发生在编译的哪个阶段？

2. 为什么下面的代码会导致重定义错误？
```cpp
template <typename T, typename = std::enable_if_t<std::is_integral_v<T>>>
void foo(T) { }
template <typename T, typename = std::enable_if_t<std::is_floating_point_v<T>>>
void foo(T) { }
```

3. 实现一个`has_to_string`类型特征，检测类型T是否有`to_string()`成员函数。

#### 第三周检验题目
1. 为什么`is_class`等traits需要编译器内置支持？

2. 实现`remove_all_pointers`：
```cpp
remove_all_pointers<int***>::type  // 应该是 int
```

3. 解释`common_type<int, double, float>::type`的推导过程。

#### 第四周检验题目
1. `constexpr`函数和`consteval`函数的区别是什么？

2. 下面的代码有什么问题？
```cpp
decltype(auto) foo() {
    int x = 42;
    return (x);
}
```

3. 实现编译期判断一个数是否是2的幂。

### 实践检验
- [ ] mini_type_traits库通过所有单元测试
- [ ] 能实现自定义的类型特征检测器
- [ ] 能使用if constexpr简化模板代码
- [ ] 能使用constexpr编写编译期算法
- [ ] 能阅读并理解STL中的type_traits实现

### 输出物清单

#### 代码文件
1. `src/mini_type_traits.hpp` - 类型特征库
2. `src/constexpr_string.hpp` - 编译期字符串库
3. `src/type_detection.hpp` - 类型检测库
4. `tests/test_type_traits.cpp` - 单元测试
5. `tests/test_constexpr.cpp` - constexpr测试
6. `examples/sfinae_examples.cpp` - SFINAE示例

#### 文档
7. `notes/week1_type_deduction.md` - 类型推导笔记
8. `notes/week2_sfinae.md` - SFINAE笔记
9. `notes/week3_type_traits.md` - type_traits笔记
10. `notes/week4_constexpr.md` - constexpr笔记
11. `notes/month05_summary.md` - 月度总结

---

## 时间分配（140小时/月）

### 总体分配

| 内容 | 时间 | 占比 | 说明 |
|------|------|------|------|
| 理论学习 | 40小时 | 29% | 阅读书籍、观看视频、理解概念 |
| 源码阅读 | 30小时 | 21% | 阅读STL实现、分析设计模式 |
| type_traits实现 | 35小时 | 25% | 实现mini_type_traits库 |
| constexpr项目 | 25小时 | 18% | 实现编译期字符串和算法 |
| 测试与文档 | 10小时 | 7% | 编写测试、整理笔记 |

### 每周详细分配

#### Week 1: 模板基础与类型推导（35小时）
| 活动 | 时间 | 说明 |
|------|------|------|
| 阅读《C++ Templates》1-4章 | 10小时 | 理论基础 |
| 阅读《Effective Modern C++》Item 1-4 | 5小时 | 类型推导精讲 |
| 观看CppCon视频 | 3小时 | 实战理解 |
| 编写类型推导测试 | 8小时 | 验证理解 |
| 实现type_printer工具 | 5小时 | 实用工具 |
| 笔记整理 | 4小时 | 知识沉淀 |

#### Week 2: SFINAE原理与应用（35小时）
| 活动 | 时间 | 说明 |
|------|------|------|
| 学习SFINAE理论 | 8小时 | 概念理解 |
| 阅读enable_if/void_t源码 | 8小时 | 源码学习 |
| 实现检测惯用法 | 10小时 | 实践应用 |
| 学习C++20 concepts | 5小时 | 预习新特性 |
| 练习与测试 | 4小时 | 巩固知识 |

#### Week 3: type_traits深度分析（35小时）
| 活动 | 时间 | 说明 |
|------|------|------|
| 阅读type_traits源码 | 12小时 | 深度学习 |
| 实现基本traits | 10小时 | 动手实践 |
| 实现高级traits | 8小时 | 进阶实现 |
| 整合mini_type_traits | 5小时 | 完善库 |

#### Week 4: constexpr与编译期计算（35小时）
| 活动 | 时间 | 说明 |
|------|------|------|
| 学习constexpr演进 | 6小时 | 理论学习 |
| 实现ConstString | 10小时 | 核心项目 |
| 实现编译期算法 | 10小时 | 算法实践 |
| 学习consteval/constinit | 4小时 | C++20特性 |
| 综合测试与文档 | 5小时 | 收尾工作 |

---

## 常见问题与陷阱

### Q1: 为什么模板错误信息这么难读？

模板错误信息难读的原因：
1. 模板实例化是递归的，错误可能在多层嵌套中
2. 类型名被完全展开，变得冗长
3. SFINAE可能产生多个候选失败

**解决方案**：
```cpp
// 使用static_assert提供更好的错误信息
template <typename T>
void process(T value) {
    static_assert(std::is_integral_v<T>,
                  "process() requires an integral type");
    // ...
}

// 使用C++20 concepts
template <typename T>
    requires std::integral<T>
void process(T value) {
    // 错误信息会明确说明约束未满足
}
```

### Q2: enable_if应该放在哪里？

推荐优先级：
1. **非类型模板参数**（最推荐）：签名不同，避免重定义
2. **返回类型**：适合单个函数
3. **默认类型模板参数**：容易导致重定义，不推荐

```cpp
// 最推荐的方式
template <typename T, std::enable_if_t<condition, int> = 0>
void foo(T);
```

### Q3: void_t为什么能检测类型？

```cpp
// void_t的魔力在于SFINAE
template <typename, typename = void>
struct has_type : false_type {};

template <typename T>
struct has_type<T, void_t<typename T::type>> : true_type {};

// 关键理解：
// 1. 主模板默认第二参数是void
// 2. 特化也产生void（如果T::type存在）
// 3. void_t<有效类型> = void，匹配特化
// 4. void_t<无效类型> = SFINAE失败，使用主模板
```

### Q4: constexpr和const的区别？

| 特性 | const | constexpr |
|------|-------|-----------|
| 修改性 | 不能修改 | 不能修改 |
| 初始化时机 | 编译期或运行期 | 必须编译期 |
| 用于函数 | 成员函数不修改this | 函数可在编译期求值 |
| 用作数组大小 | 有时可以 | 总是可以 |

### Q5: if constexpr vs 普通if？

```cpp
template <typename T>
void foo(T t) {
    if constexpr (std::is_pointer_v<T>) {
        *t;  // 普通if下，非指针类型也会尝试编译这行
    }
}
```

`if constexpr`的核心特性：**不满足条件的分支不会被实例化**。

### Q6: decltype(auto)什么时候用？

主要用于**完美返回**，保持表达式的精确类型：

```cpp
// 场景：包装器函数需要返回被包装函数的精确返回类型
template <typename F, typename... Args>
decltype(auto) wrapper(F&& f, Args&&... args) {
    // 如果f返回引用，我们也返回引用
    // 如果f返回值，我们也返回值
    return std::forward<F>(f)(std::forward<Args>(args)...);
}
```

⚠️ 陷阱：`return (x);` 会返回引用！

---

## 扩展阅读资源

### 书籍
- 《C++ Templates: The Complete Guide》 2nd Edition - 模板圣经
- 《Effective Modern C++》 - 现代C++最佳实践
- 《Modern C++ Design》 - 模板元编程经典

### 在线资源
- [cppreference.com/type_traits](https://en.cppreference.com/w/cpp/header/type_traits)
- [Compiler Explorer (godbolt.org)](https://godbolt.org/) - 查看模板实例化
- [C++ Insights](https://cppinsights.io/) - 查看编译器如何处理代码

### CppCon演讲推荐
- "Template Metaprogramming: Type Traits" - 入门
- "constexpr ALL the Things!" - constexpr实战
- "The C++20 Concepts" - 未来的模板约束
- "Modern Template Metaprogramming: A Compendium" - 高级技术

### 练习平台
- [Exercism C++ Track](https://exercism.org/tracks/cpp) - 包含模板题目
- LeetCode/力扣 - 使用模板解题

---

## 下月预告

**Month 06: 完美转发与移动语义深度**

将深入理解：
- 右值引用的本质
- std::move 和 std::forward 的实现
- 移动构造函数和移动赋值运算符
- 完美转发的工作原理
- 引用折叠在实际中的应用
- 实现一个支持移动语义的容器
