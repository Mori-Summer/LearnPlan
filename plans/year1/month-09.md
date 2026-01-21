# Month 09: 迭代器与算法库深度——STL的设计哲学

## 本月主题概述

迭代器是STL的灵魂，它将容器和算法解耦，实现了高度的通用性。本月将深入理解迭代器的分类体系、STL算法的实现，并掌握自定义迭代器和算法的技巧。

---

## 理论学习内容

### 第一周：迭代器概念与分类

**学习目标**：理解迭代器层次结构

**阅读材料**：
- [ ] 《STL源码剖析》第3章
- [ ] C++标准 [iterator] 章节
- [ ] CppCon演讲："The Iterator Concept"

**核心概念**：

#### 迭代器类别层次
```cpp
// 迭代器层次（从弱到强）
// Input Iterator        -> 单遍、只读
// Output Iterator       -> 单遍、只写
// Forward Iterator      -> 多遍、读写
// Bidirectional Iterator -> 可双向移动
// Random Access Iterator -> 支持随机访问
// Contiguous Iterator   -> C++20，连续存储

// 各类别支持的操作
// Input:       ++, *, ==, !=, -> (只能前进，只能读)
// Output:      ++, *（只能前进，只能写）
// Forward:     Input + 多遍保证
// Bidirectional: Forward + --
// RandomAccess: Bidirectional + [], +=, -=, +, -, <, >, <=, >=
// Contiguous:  RandomAccess + 元素连续存储（可以用指针算术）
```

#### 迭代器特征（iterator_traits）
```cpp
// iterator_traits提取迭代器信息
template <typename Iterator>
struct iterator_traits {
    using difference_type   = typename Iterator::difference_type;
    using value_type        = typename Iterator::value_type;
    using pointer           = typename Iterator::pointer;
    using reference         = typename Iterator::reference;
    using iterator_category = typename Iterator::iterator_category;
};

// 指针特化
template <typename T>
struct iterator_traits<T*> {
    using difference_type   = std::ptrdiff_t;
    using value_type        = T;
    using pointer           = T*;
    using reference         = T&;
    using iterator_category = std::random_access_iterator_tag;
};

// 使用
template <typename Iterator>
void advance_impl(Iterator& it, int n,
                  std::random_access_iterator_tag) {
    it += n;  // O(1)
}

template <typename Iterator>
void advance_impl(Iterator& it, int n,
                  std::input_iterator_tag) {
    while (n--) ++it;  // O(n)
}

template <typename Iterator>
void advance(Iterator& it, int n) {
    advance_impl(it, n,
        typename std::iterator_traits<Iterator>::iterator_category{});
}
```

---

### 第一周详细学习计划

#### Day 1: 迭代器设计哲学与五大类别（4小时）

**学习目标**：深入理解迭代器作为STL核心抽象的设计思想

**上午：理论学习（2小时）**

迭代器是STL设计的精髓所在。Alexander Stepanov设计STL时，核心思想是**算法与数据结构的解耦**。迭代器就是连接两者的桥梁。

```cpp
// 没有迭代器的世界——每种容器需要专门的算法
void find_in_vector(std::vector<int>& v, int val);
void find_in_list(std::list<int>& l, int val);
void find_in_deque(std::deque<int>& d, int val);

// 有迭代器的世界——一个算法适用于所有容器
template <typename Iterator, typename T>
Iterator find(Iterator first, Iterator last, const T& val);
```

**五种迭代器类别的本质区别**：

| 类别 | 核心能力 | 典型容器 | 算法示例 |
|------|----------|----------|----------|
| Input | 单遍读取 | istream_iterator | find, count |
| Output | 单遍写入 | ostream_iterator | copy输出端 |
| Forward | 多遍读写 | forward_list, unordered_set | replace, unique |
| Bidirectional | 双向移动 | list, set, map | reverse, prev |
| RandomAccess | 随机跳转 | vector, deque, array | sort, binary_search |

**下午：代码实践（2小时）**

```cpp
// 验证不同迭代器的能力
#include <iostream>
#include <vector>
#include <list>
#include <forward_list>
#include <iterator>
#include <type_traits>

// 编译期检查迭代器类别
template <typename Iter>
void check_iterator_category() {
    using category = typename std::iterator_traits<Iter>::iterator_category;

    std::cout << "Iterator category: ";
    if constexpr (std::is_same_v<category, std::random_access_iterator_tag>) {
        std::cout << "RandomAccess";
    } else if constexpr (std::is_same_v<category, std::bidirectional_iterator_tag>) {
        std::cout << "Bidirectional";
    } else if constexpr (std::is_same_v<category, std::forward_iterator_tag>) {
        std::cout << "Forward";
    } else if constexpr (std::is_same_v<category, std::input_iterator_tag>) {
        std::cout << "Input";
    } else if constexpr (std::is_same_v<category, std::output_iterator_tag>) {
        std::cout << "Output";
    }
    std::cout << std::endl;
}

// 验证各容器的迭代器类别
void test_categories() {
    check_iterator_category<std::vector<int>::iterator>();      // RandomAccess
    check_iterator_category<std::list<int>::iterator>();        // Bidirectional
    check_iterator_category<std::forward_list<int>::iterator>();// Forward
    check_iterator_category<std::istream_iterator<int>>();      // Input
    check_iterator_category<std::ostream_iterator<int>>();      // Output
}

// 迭代器类别决定了哪些操作是合法的
void demonstrate_operations() {
    std::vector<int> vec = {1, 2, 3, 4, 5};
    std::list<int> lst = {1, 2, 3, 4, 5};

    auto vi = vec.begin();
    auto li = lst.begin();

    // RandomAccess特有操作
    vi += 3;           // OK: vector迭代器支持
    // li += 3;        // 编译错误！list迭代器不支持

    auto diff_v = vec.end() - vec.begin();  // OK: 返回5
    // auto diff_l = lst.end() - lst.begin(); // 编译错误！

    // 正确的方式：使用std::distance
    auto diff_l = std::distance(lst.begin(), lst.end());  // OK

    // Bidirectional操作
    ++vi; ++li;  // 两者都支持前进
    --vi; --li;  // 两者都支持后退

    // Forward操作（所有非Output迭代器都支持）
    *vi = 10;    // 读写
    *li = 10;    // 读写
}
```

**练习题**：
1. 写一个函数，接受任意迭代器并输出其类别名称
2. 为什么`std::sort`只能用于RandomAccess迭代器？尝试用list的迭代器调用sort看看编译错误
3. 解释为什么Input迭代器只能单遍遍历（提示：考虑istream_iterator）

**思考题**：
- 为什么C++20新增了Contiguous迭代器类别？它与RandomAccess有什么本质区别？

---

#### Day 2: iterator_traits深入理解（4小时）

**学习目标**：掌握traits技术在泛型编程中的核心作用

**核心概念**：
traits是C++泛型编程的基石技术。它的作用是**萃取类型信息**，让算法能够在编译期获取迭代器的特性。

```cpp
// 为什么需要iterator_traits？
// 问题：如何让算法同时支持类类型迭代器和原始指针？

// 类类型迭代器有内嵌类型
class MyIterator {
public:
    using value_type = int;
    using difference_type = std::ptrdiff_t;
    // ...
};

// 但原始指针没有内嵌类型！
// int* 没有 int*::value_type

// 解决方案：通过traits间接获取
template <typename T>
struct iterator_traits {
    // 主模板：假设T是类类型，直接提取内嵌类型
    using value_type = typename T::value_type;
    using difference_type = typename T::difference_type;
    using pointer = typename T::pointer;
    using reference = typename T::reference;
    using iterator_category = typename T::iterator_category;
};

// 指针特化：为原始指针提供类型信息
template <typename T>
struct iterator_traits<T*> {
    using value_type = T;
    using difference_type = std::ptrdiff_t;
    using pointer = T*;
    using reference = T&;
    using iterator_category = std::random_access_iterator_tag;
};

// const指针特化
template <typename T>
struct iterator_traits<const T*> {
    using value_type = T;  // 注意：value_type不带const
    using difference_type = std::ptrdiff_t;
    using pointer = const T*;
    using reference = const T&;
    using iterator_category = std::random_access_iterator_tag;
};
```

**深入理解：为什么value_type不带const？**

```cpp
// 考虑这个场景
template <typename Iterator>
void create_temp(Iterator it) {
    // 我们想创建一个临时变量来存储值
    typename std::iterator_traits<Iterator>::value_type temp = *it;
    // 如果value_type是const int，这个temp就无法修改了
    // 但有时我们需要修改临时变量
    temp += 10;
    std::cout << temp << std::endl;
}

// 如果传入const int*，我们仍然希望temp是可修改的int
const int arr[] = {1, 2, 3};
create_temp(arr);  // temp应该是int，而不是const int
```

**实践代码**：

```cpp
#include <iostream>
#include <vector>
#include <list>
#include <type_traits>

// 自己实现一个简化版的iterator_traits
namespace my {

// 主模板
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
    using value_type = std::remove_cv_t<T>;  // 移除const/volatile
    using pointer = T*;
    using reference = T&;
    using iterator_category = std::random_access_iterator_tag;
};

// 使用traits编写通用算法
template <typename Iterator>
typename iterator_traits<Iterator>::value_type
sum(Iterator first, Iterator last) {
    using value_type = typename iterator_traits<Iterator>::value_type;
    value_type result{};  // 值初始化
    for (; first != last; ++first) {
        result += *first;
    }
    return result;
}

}  // namespace my

// 测试
void test_my_traits() {
    std::vector<int> v = {1, 2, 3, 4, 5};
    int arr[] = {1, 2, 3, 4, 5};

    // 同一个算法，既能用于vector迭代器，也能用于原始指针
    std::cout << "vector sum: " << my::sum(v.begin(), v.end()) << std::endl;
    std::cout << "array sum: " << my::sum(arr, arr + 5) << std::endl;

    // 验证类型萃取
    using VecIter = std::vector<int>::iterator;
    using PtrIter = int*;

    static_assert(std::is_same_v<
        my::iterator_traits<VecIter>::value_type, int>);
    static_assert(std::is_same_v<
        my::iterator_traits<PtrIter>::value_type, int>);
    static_assert(std::is_same_v<
        my::iterator_traits<const int*>::value_type, int>);  // 注意：不是const int
}
```

**练习题**：
1. 实现一个`value_type_of<Iterator>`别名模板，简化traits的使用
2. 为什么标准库要提供`std::iter_value_t<Iterator>`（C++20）这样的简化形式？
3. 如果一个类没有定义所有五个内嵌类型，使用iterator_traits会发生什么？

---

#### Day 3: 标签分发与算法优化（5小时）

**学习目标**：掌握标签分发技术，理解如何根据迭代器类别选择最优算法

**核心概念**：
标签分发（Tag Dispatching）是C++泛型编程中根据类型特性选择不同实现的技术。

```cpp
// 迭代器类别标签——它们是空类，仅用于类型区分
struct input_iterator_tag {};
struct output_iterator_tag {};
struct forward_iterator_tag : input_iterator_tag {};
struct bidirectional_iterator_tag : forward_iterator_tag {};
struct random_access_iterator_tag : bidirectional_iterator_tag {};

// 注意继承关系！这很重要：
// RandomAccess继承自Bidirectional，Bidirectional继承自Forward...
// 这意味着：RandomAccess迭代器可以当作Bidirectional使用
```

**std::advance的完整实现**：

```cpp
namespace my {

// 实现细节：针对不同迭代器类别的优化版本

// InputIterator版本：只能一步一步前进，O(n)
template <typename InputIt, typename Distance>
void advance_impl(InputIt& it, Distance n, std::input_iterator_tag) {
    // 注意：Input迭代器只支持正向移动
    assert(n >= 0 && "Input iterator can only advance forward");
    while (n > 0) {
        ++it;
        --n;
    }
}

// BidirectionalIterator版本：可以前进也可以后退，但仍是O(n)
template <typename BidirIt, typename Distance>
void advance_impl(BidirIt& it, Distance n, std::bidirectional_iterator_tag) {
    if (n > 0) {
        while (n > 0) {
            ++it;
            --n;
        }
    } else {
        while (n < 0) {
            --it;
            ++n;
        }
    }
}

// RandomAccessIterator版本：直接跳转，O(1)
template <typename RandomIt, typename Distance>
void advance_impl(RandomIt& it, Distance n, std::random_access_iterator_tag) {
    it += n;  // 一步到位！
}

// 公开接口：自动选择最优实现
template <typename Iterator, typename Distance>
void advance(Iterator& it, Distance n) {
    // 获取迭代器类别标签，创建临时对象用于重载决议
    advance_impl(it, n,
        typename std::iterator_traits<Iterator>::iterator_category{});
}

}  // namespace my
```

**std::distance的完整实现**：

```cpp
namespace my {

// InputIterator版本：只能逐个计数，O(n)
template <typename InputIt>
typename std::iterator_traits<InputIt>::difference_type
distance_impl(InputIt first, InputIt last, std::input_iterator_tag) {
    typename std::iterator_traits<InputIt>::difference_type n = 0;
    while (first != last) {
        ++first;
        ++n;
    }
    return n;
}

// RandomAccessIterator版本：直接相减，O(1)
template <typename RandomIt>
typename std::iterator_traits<RandomIt>::difference_type
distance_impl(RandomIt first, RandomIt last, std::random_access_iterator_tag) {
    return last - first;  // 一步到位！
}

// 公开接口
template <typename Iterator>
typename std::iterator_traits<Iterator>::difference_type
distance(Iterator first, Iterator last) {
    return distance_impl(first, last,
        typename std::iterator_traits<Iterator>::iterator_category{});
}

}  // namespace my
```

**性能对比实验**：

```cpp
#include <iostream>
#include <vector>
#include <list>
#include <chrono>

template <typename Container>
void benchmark_advance(const std::string& name, int iterations) {
    Container c(10000);

    auto start = std::chrono::high_resolution_clock::now();

    for (int i = 0; i < iterations; ++i) {
        auto it = c.begin();
        std::advance(it, 5000);  // 移动到中间
    }

    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);

    std::cout << name << ": " << duration.count() << " us" << std::endl;
}

void run_benchmark() {
    const int iterations = 10000;

    benchmark_advance<std::vector<int>>("vector (RandomAccess)", iterations);
    benchmark_advance<std::list<int>>("list (Bidirectional)", iterations);

    // 预期结果：
    // vector: 几乎是常数时间，因为直接+=
    // list: 线性时间，因为要遍历5000个节点
}
```

**练习题**：
1. 实现`my::next`和`my::prev`函数，它们返回移动后的迭代器（而不是修改原迭代器）
2. 为什么标签使用继承关系？如果没有继承会带来什么问题？
3. C++17引入了`if constexpr`，用它重写advance，比较两种方式的优劣

**思考题**：
- 如果一个算法只需要Forward迭代器，但传入了RandomAccess迭代器，会发生什么？

---

#### Day 4: 容器迭代器实现分析（5小时）

**学习目标**：通过分析标准容器的迭代器实现，理解迭代器设计的实际细节

**vector迭代器分析**：

```cpp
// vector的迭代器本质上就是指针的包装
// 实际实现可能更复杂（包含调试检查），这里是简化版

template <typename T>
class vector {
public:
    // vector的迭代器就是原始指针
    using iterator = T*;
    using const_iterator = const T*;

    // 或者使用包装类（用于调试版本）
    class iterator_wrapper {
        T* ptr_;
    public:
        // 所有的iterator_traits要求的类型
        using difference_type = std::ptrdiff_t;
        using value_type = T;
        using pointer = T*;
        using reference = T&;
        using iterator_category = std::random_access_iterator_tag;

        iterator_wrapper(T* p = nullptr) : ptr_(p) {}

        // 解引用
        reference operator*() const { return *ptr_; }
        pointer operator->() const { return ptr_; }

        // 递增递减
        iterator_wrapper& operator++() { ++ptr_; return *this; }
        iterator_wrapper& operator--() { --ptr_; return *this; }
        iterator_wrapper operator++(int) { auto tmp = *this; ++ptr_; return tmp; }
        iterator_wrapper operator--(int) { auto tmp = *this; --ptr_; return tmp; }

        // 随机访问
        iterator_wrapper& operator+=(difference_type n) { ptr_ += n; return *this; }
        iterator_wrapper& operator-=(difference_type n) { ptr_ -= n; return *this; }
        iterator_wrapper operator+(difference_type n) const { return iterator_wrapper(ptr_ + n); }
        iterator_wrapper operator-(difference_type n) const { return iterator_wrapper(ptr_ - n); }
        difference_type operator-(const iterator_wrapper& other) const { return ptr_ - other.ptr_; }

        reference operator[](difference_type n) const { return ptr_[n]; }

        // 比较
        bool operator==(const iterator_wrapper& other) const { return ptr_ == other.ptr_; }
        bool operator!=(const iterator_wrapper& other) const { return ptr_ != other.ptr_; }
        bool operator<(const iterator_wrapper& other) const { return ptr_ < other.ptr_; }
        bool operator>(const iterator_wrapper& other) const { return ptr_ > other.ptr_; }
        bool operator<=(const iterator_wrapper& other) const { return ptr_ <= other.ptr_; }
        bool operator>=(const iterator_wrapper& other) const { return ptr_ >= other.ptr_; }
    };
};
```

**list迭代器分析**：

```cpp
// list的迭代器必须包装节点指针
template <typename T>
struct list_node {
    T data;
    list_node* prev;
    list_node* next;
};

template <typename T>
class list_iterator {
    list_node<T>* node_;

public:
    using difference_type = std::ptrdiff_t;
    using value_type = T;
    using pointer = T*;
    using reference = T&;
    using iterator_category = std::bidirectional_iterator_tag;  // 不是RandomAccess！

    list_iterator(list_node<T>* n = nullptr) : node_(n) {}

    reference operator*() const { return node_->data; }
    pointer operator->() const { return &node_->data; }

    // 只支持++和--，不支持+=和-
    list_iterator& operator++() {
        node_ = node_->next;
        return *this;
    }

    list_iterator& operator--() {
        node_ = node_->prev;
        return *this;
    }

    // 注意：没有operator+=、operator-、operator[]
    // 因为list是Bidirectional迭代器，不是RandomAccess

    bool operator==(const list_iterator& other) const { return node_ == other.node_; }
    bool operator!=(const list_iterator& other) const { return node_ != other.node_; }
};
```

**为什么list不支持随机访问？**

```cpp
// 假设list支持operator+=
list_iterator& operator+=(difference_type n) {
    // 必须这样实现：
    while (n > 0) { node_ = node_->next; --n; }
    while (n < 0) { node_ = node_->prev; ++n; }
    return *this;
}
// 这是O(n)操作！
// 如果允许这样写，用户可能会误以为它是O(1)
// 所以list故意不提供这个操作，强迫用户使用std::advance
// std::advance会正确地选择O(n)实现
```

**练习题**：
1. 阅读libstdc++中`__gnu_cxx::__normal_iterator`的实现
2. 为什么`vector<bool>`的迭代器不是原始指针？
3. 实现一个简单的`deque_iterator`（需要处理分段存储）

---

#### Day 5: 迭代器失效问题（4小时）

**学习目标**：深入理解迭代器失效的各种情况，掌握安全使用迭代器的方法

**这是C++中最常见的bug来源之一！**

```cpp
// 经典错误1：遍历时删除元素
void bad_erase() {
    std::vector<int> v = {1, 2, 3, 4, 5};

    for (auto it = v.begin(); it != v.end(); ++it) {
        if (*it % 2 == 0) {
            v.erase(it);  // 错误！erase后it失效
            // 继续++it是未定义行为
        }
    }
}

// 正确方式
void good_erase() {
    std::vector<int> v = {1, 2, 3, 4, 5};

    for (auto it = v.begin(); it != v.end(); ) {  // 注意：没有++it
        if (*it % 2 == 0) {
            it = v.erase(it);  // erase返回下一个有效迭代器
        } else {
            ++it;
        }
    }
}

// 更好的方式：使用erase-remove idiom
void best_erase() {
    std::vector<int> v = {1, 2, 3, 4, 5};
    v.erase(std::remove_if(v.begin(), v.end(),
        [](int x) { return x % 2 == 0; }), v.end());
}

// C++20最佳方式
void cpp20_erase() {
    std::vector<int> v = {1, 2, 3, 4, 5};
    std::erase_if(v, [](int x) { return x % 2 == 0; });
}
```

**各容器的迭代器失效规则**：

| 容器 | 操作 | 失效情况 |
|------|------|----------|
| vector | push_back | 如果重新分配：全部失效；否则：end()失效 |
| vector | insert | 插入点之后的全部失效 |
| vector | erase | 删除点之后的全部失效 |
| deque | push_front/back | 所有迭代器失效，但引用不失效 |
| deque | insert(中间) | 全部失效 |
| list | 任何操作 | 只有被删除元素的迭代器失效 |
| map/set | insert | 不失效 |
| map/set | erase | 只有被删除元素的迭代器失效 |

```cpp
// vector的重新分配问题
void vector_reallocation() {
    std::vector<int> v = {1, 2, 3};
    auto it = v.begin();

    std::cout << "Before: " << *it << std::endl;  // OK: 1

    // 假设当前capacity是3
    v.push_back(4);  // 可能触发重新分配

    // 危险！如果重新分配发生，it现在指向已释放的内存
    // std::cout << *it << std::endl;  // 未定义行为！

    // 安全做法：重新获取迭代器
    it = v.begin();
    std::cout << "After: " << *it << std::endl;  // OK
}

// 使用reserve避免重新分配
void safe_with_reserve() {
    std::vector<int> v;
    v.reserve(100);  // 预分配空间

    auto it = v.begin();

    for (int i = 0; i < 100; ++i) {
        v.push_back(i);
        // 因为预留了空间，迭代器不会失效
        // 但end()仍然会变化
    }
}
```

**练习题**：
1. 写一个安全地从map中删除所有满足条件的元素的函数
2. 解释为什么list的迭代器在insert/erase后（除被删元素外）仍然有效
3. 下面的代码有什么问题？

```cpp
std::vector<int> v = {1, 2, 3};
for (const auto& x : v) {
    if (x == 2) v.push_back(4);  // 有问题吗？
}
```

---

#### Day 6: 自定义迭代器实现（5小时）

**学习目标**：从零实现符合STL规范的迭代器

**实现一个环形缓冲区的迭代器**：

```cpp
// ring_buffer.hpp
#pragma once
#include <iterator>
#include <stdexcept>
#include <memory>

template <typename T>
class ring_buffer {
public:
    // 前向声明迭代器
    class iterator;
    class const_iterator;

private:
    std::unique_ptr<T[]> data_;
    size_t capacity_;
    size_t head_ = 0;  // 下一个写入位置
    size_t size_ = 0;  // 当前元素数量

    size_t index(size_t i) const {
        return (head_ + capacity_ - size_ + i) % capacity_;
    }

public:
    explicit ring_buffer(size_t cap)
        : data_(std::make_unique<T[]>(cap)), capacity_(cap) {}

    void push_back(const T& value) {
        data_[head_] = value;
        head_ = (head_ + 1) % capacity_;
        if (size_ < capacity_) ++size_;
    }

    T& operator[](size_t i) { return data_[index(i)]; }
    const T& operator[](size_t i) const { return data_[index(i)]; }

    size_t size() const { return size_; }
    size_t capacity() const { return capacity_; }
    bool empty() const { return size_ == 0; }
    bool full() const { return size_ == capacity_; }

    // 迭代器接口
    iterator begin() { return iterator(this, 0); }
    iterator end() { return iterator(this, size_); }
    const_iterator begin() const { return const_iterator(this, 0); }
    const_iterator end() const { return const_iterator(this, size_); }
    const_iterator cbegin() const { return const_iterator(this, 0); }
    const_iterator cend() const { return const_iterator(this, size_); }

    // 迭代器实现
    class iterator {
    public:
        // 必须的类型定义
        using iterator_category = std::random_access_iterator_tag;
        using value_type = T;
        using difference_type = std::ptrdiff_t;
        using pointer = T*;
        using reference = T&;

    private:
        ring_buffer* rb_;
        size_t pos_;

    public:
        iterator() : rb_(nullptr), pos_(0) {}
        iterator(ring_buffer* rb, size_t pos) : rb_(rb), pos_(pos) {}

        // 解引用
        reference operator*() const { return (*rb_)[pos_]; }
        pointer operator->() const { return &(*rb_)[pos_]; }
        reference operator[](difference_type n) const { return (*rb_)[pos_ + n]; }

        // 递增递减
        iterator& operator++() { ++pos_; return *this; }
        iterator& operator--() { --pos_; return *this; }
        iterator operator++(int) { iterator tmp = *this; ++pos_; return tmp; }
        iterator operator--(int) { iterator tmp = *this; --pos_; return tmp; }

        // 随机访问
        iterator& operator+=(difference_type n) { pos_ += n; return *this; }
        iterator& operator-=(difference_type n) { pos_ -= n; return *this; }
        iterator operator+(difference_type n) const { return iterator(rb_, pos_ + n); }
        iterator operator-(difference_type n) const { return iterator(rb_, pos_ - n); }
        difference_type operator-(const iterator& other) const {
            return static_cast<difference_type>(pos_) - static_cast<difference_type>(other.pos_);
        }

        // 比较
        bool operator==(const iterator& other) const { return rb_ == other.rb_ && pos_ == other.pos_; }
        bool operator!=(const iterator& other) const { return !(*this == other); }
        bool operator<(const iterator& other) const { return pos_ < other.pos_; }
        bool operator>(const iterator& other) const { return pos_ > other.pos_; }
        bool operator<=(const iterator& other) const { return pos_ <= other.pos_; }
        bool operator>=(const iterator& other) const { return pos_ >= other.pos_; }

        // 允许与const_iterator比较
        friend class const_iterator;
    };

    // const_iterator实现（类似，但返回const引用）
    class const_iterator {
    public:
        using iterator_category = std::random_access_iterator_tag;
        using value_type = T;
        using difference_type = std::ptrdiff_t;
        using pointer = const T*;
        using reference = const T&;

    private:
        const ring_buffer* rb_;
        size_t pos_;

    public:
        const_iterator() : rb_(nullptr), pos_(0) {}
        const_iterator(const ring_buffer* rb, size_t pos) : rb_(rb), pos_(pos) {}
        const_iterator(const iterator& it) : rb_(it.rb_), pos_(it.pos_) {}  // 从iterator转换

        reference operator*() const { return (*rb_)[pos_]; }
        pointer operator->() const { return &(*rb_)[pos_]; }
        reference operator[](difference_type n) const { return (*rb_)[pos_ + n]; }

        const_iterator& operator++() { ++pos_; return *this; }
        const_iterator& operator--() { --pos_; return *this; }
        const_iterator operator++(int) { const_iterator tmp = *this; ++pos_; return tmp; }
        const_iterator operator--(int) { const_iterator tmp = *this; --pos_; return tmp; }

        const_iterator& operator+=(difference_type n) { pos_ += n; return *this; }
        const_iterator& operator-=(difference_type n) { pos_ -= n; return *this; }
        const_iterator operator+(difference_type n) const { return const_iterator(rb_, pos_ + n); }
        const_iterator operator-(difference_type n) const { return const_iterator(rb_, pos_ - n); }
        difference_type operator-(const const_iterator& other) const {
            return static_cast<difference_type>(pos_) - static_cast<difference_type>(other.pos_);
        }

        bool operator==(const const_iterator& other) const { return rb_ == other.rb_ && pos_ == other.pos_; }
        bool operator!=(const const_iterator& other) const { return !(*this == other); }
        bool operator<(const const_iterator& other) const { return pos_ < other.pos_; }
        bool operator>(const const_iterator& other) const { return pos_ > other.pos_; }
        bool operator<=(const const_iterator& other) const { return pos_ <= other.pos_; }
        bool operator>=(const const_iterator& other) const { return pos_ >= other.pos_; }
    };
};

// 非成员operator+（允许 n + iterator 的写法）
template <typename T>
typename ring_buffer<T>::iterator operator+(
    typename ring_buffer<T>::iterator::difference_type n,
    typename ring_buffer<T>::iterator it) {
    return it + n;
}
```

**测试自定义迭代器**：

```cpp
#include <algorithm>
#include <numeric>
#include <iostream>

void test_ring_buffer_iterator() {
    ring_buffer<int> rb(5);

    // 填充数据
    for (int i = 1; i <= 7; ++i) {
        rb.push_back(i);  // 环形覆盖：最终是 3,4,5,6,7
    }

    // 测试range-based for
    std::cout << "Elements: ";
    for (const auto& x : rb) {
        std::cout << x << " ";
    }
    std::cout << std::endl;  // 3 4 5 6 7

    // 测试STL算法
    auto sum = std::accumulate(rb.begin(), rb.end(), 0);
    std::cout << "Sum: " << sum << std::endl;  // 25

    auto it = std::find(rb.begin(), rb.end(), 5);
    std::cout << "Found 5 at position: " << (it - rb.begin()) << std::endl;  // 2

    // 测试排序（需要RandomAccess迭代器）
    ring_buffer<int> rb2(5);
    rb2.push_back(3); rb2.push_back(1); rb2.push_back(4);
    rb2.push_back(1); rb2.push_back(5);

    std::sort(rb2.begin(), rb2.end());
    std::cout << "Sorted: ";
    for (const auto& x : rb2) {
        std::cout << x << " ";
    }
    std::cout << std::endl;  // 1 1 3 4 5
}
```

**练习题**：
1. 为ring_buffer添加reverse_iterator支持
2. 实现一个stride_iterator，每次前进跳过n个元素
3. 检验你的迭代器是否满足所有RandomAccess迭代器的要求

---

#### Day 7: 综合练习与复习（5小时）

**本周知识点总结**：

1. **迭代器分类**：Input < Forward < Bidirectional < RandomAccess
2. **iterator_traits**：萃取迭代器类型信息，统一类和指针的接口
3. **标签分发**：根据迭代器类别在编译期选择最优算法
4. **迭代器失效**：了解各容器的失效规则，避免悬垂迭代器

**综合练习项目**：实现一个支持迭代器的简单`flat_map`

```cpp
// flat_map使用排序的vector存储，支持二分查找
// 实现要点：
// 1. 迭代器需要同时暴露key和value
// 2. 支持const和非const版本
// 3. 提供lower_bound, upper_bound, find等操作

template <typename Key, typename Value>
class flat_map {
    std::vector<std::pair<Key, Value>> data_;

public:
    using iterator = typename std::vector<std::pair<Key, Value>>::iterator;
    using const_iterator = typename std::vector<std::pair<Key, Value>>::const_iterator;

    // 实现insert, find, erase, operator[], begin, end等
    // ...
};
```

**本周检验标准**：
- [ ] 能准确说出五种迭代器类别及其支持的操作
- [ ] 能解释iterator_traits的作用和实现原理
- [ ] 能使用标签分发技术编写针对不同迭代器优化的算法
- [ ] 能识别和避免迭代器失效问题
- [ ] 能实现符合STL规范的自定义迭代器

---

### 第二周：常用算法实现分析

**学习目标**：理解STL算法的实现技巧

#### std::find的实现
```cpp
template <typename InputIt, typename T>
InputIt find(InputIt first, InputIt last, const T& value) {
    for (; first != last; ++first) {
        if (*first == value) {
            return first;
        }
    }
    return last;
}

// 带谓词版本
template <typename InputIt, typename Pred>
InputIt find_if(InputIt first, InputIt last, Pred pred) {
    for (; first != last; ++first) {
        if (pred(*first)) {
            return first;
        }
    }
    return last;
}
```

#### std::sort的实现（简化版）
```cpp
// 实际的std::sort是IntroSort：
// - 小区间用InsertionSort
// - 中等用QuickSort
// - 递归过深切换HeapSort（防止最坏O(n²)）

template <typename RandomIt>
void insertion_sort(RandomIt first, RandomIt last) {
    for (auto it = first + 1; it != last; ++it) {
        auto key = std::move(*it);
        auto j = it;
        while (j != first && *(j - 1) > key) {
            *j = std::move(*(j - 1));
            --j;
        }
        *j = std::move(key);
    }
}

template <typename RandomIt>
RandomIt partition(RandomIt first, RandomIt last) {
    auto pivot = *(first + (last - first) / 2);
    auto left = first;
    auto right = last - 1;

    while (true) {
        while (*left < pivot) ++left;
        while (*right > pivot) --right;
        if (left >= right) return right;
        std::iter_swap(left++, right--);
    }
}

template <typename RandomIt>
void quicksort(RandomIt first, RandomIt last, int depth_limit) {
    while (last - first > 16) {  // 小区间用插入排序
        if (depth_limit == 0) {
            // 递归过深，切换堆排序
            std::make_heap(first, last);
            std::sort_heap(first, last);
            return;
        }
        --depth_limit;

        auto pivot = partition(first, last);
        quicksort(pivot + 1, last, depth_limit);
        last = pivot + 1;  // 尾递归优化
    }
}

template <typename RandomIt>
void introsort(RandomIt first, RandomIt last) {
    if (first == last) return;

    int depth_limit = 2 * static_cast<int>(std::log2(last - first));
    quicksort(first, last, depth_limit);
    insertion_sort(first, last);  // 清理小区间
}
```

---

### 第二周详细学习计划

#### Day 1: 非修改序列算法（4小时）

**学习目标**：深入理解find、count、for_each等算法的设计与实现

**核心算法族**：

```cpp
// 非修改序列算法的共同特点：
// 1. 不改变容器内容
// 2. 只需要InputIterator
// 3. 返回迭代器或布尔值/计数

namespace my {

// for_each：对每个元素执行操作
template <typename InputIt, typename UnaryFunc>
UnaryFunc for_each(InputIt first, InputIt last, UnaryFunc f) {
    for (; first != last; ++first) {
        f(*first);
    }
    return f;  // 返回函数对象，可能带有状态
}

// 使用示例：带状态的函数对象
struct Counter {
    int count = 0;
    void operator()(int x) {
        if (x > 0) ++count;
    }
};

void demo_for_each() {
    std::vector<int> v = {-1, 2, -3, 4, -5};
    Counter c = std::for_each(v.begin(), v.end(), Counter{});
    std::cout << "Positive count: " << c.count << std::endl;  // 2
}

// find系列的完整实现
template <typename InputIt, typename T>
InputIt find(InputIt first, InputIt last, const T& value) {
    for (; first != last; ++first) {
        if (*first == value) {
            return first;
        }
    }
    return last;
}

template <typename InputIt, typename UnaryPred>
InputIt find_if(InputIt first, InputIt last, UnaryPred pred) {
    for (; first != last; ++first) {
        if (pred(*first)) {
            return first;
        }
    }
    return last;
}

template <typename InputIt, typename UnaryPred>
InputIt find_if_not(InputIt first, InputIt last, UnaryPred pred) {
    for (; first != last; ++first) {
        if (!pred(*first)) {
            return first;
        }
    }
    return last;
}

// count系列
template <typename InputIt, typename T>
typename std::iterator_traits<InputIt>::difference_type
count(InputIt first, InputIt last, const T& value) {
    typename std::iterator_traits<InputIt>::difference_type n = 0;
    for (; first != last; ++first) {
        if (*first == value) {
            ++n;
        }
    }
    return n;
}

// all_of, any_of, none_of —— 逻辑量词
template <typename InputIt, typename UnaryPred>
bool all_of(InputIt first, InputIt last, UnaryPred pred) {
    for (; first != last; ++first) {
        if (!pred(*first)) {
            return false;
        }
    }
    return true;  // 空范围返回true（数学上的vacuous truth）
}

template <typename InputIt, typename UnaryPred>
bool any_of(InputIt first, InputIt last, UnaryPred pred) {
    for (; first != last; ++first) {
        if (pred(*first)) {
            return true;
        }
    }
    return false;  // 空范围返回false
}

template <typename InputIt, typename UnaryPred>
bool none_of(InputIt first, InputIt last, UnaryPred pred) {
    return !any_of(first, last, pred);
}

}  // namespace my
```

**mismatch和equal的实现**：

```cpp
namespace my {

// mismatch：找到第一个不匹配的位置
template <typename InputIt1, typename InputIt2>
std::pair<InputIt1, InputIt2>
mismatch(InputIt1 first1, InputIt1 last1, InputIt2 first2) {
    while (first1 != last1 && *first1 == *first2) {
        ++first1;
        ++first2;
    }
    return {first1, first2};
}

// 带谓词版本
template <typename InputIt1, typename InputIt2, typename BinaryPred>
std::pair<InputIt1, InputIt2>
mismatch(InputIt1 first1, InputIt1 last1, InputIt2 first2, BinaryPred pred) {
    while (first1 != last1 && pred(*first1, *first2)) {
        ++first1;
        ++first2;
    }
    return {first1, first2};
}

// equal：判断两个范围是否相等
template <typename InputIt1, typename InputIt2>
bool equal(InputIt1 first1, InputIt1 last1, InputIt2 first2) {
    for (; first1 != last1; ++first1, ++first2) {
        if (!(*first1 == *first2)) {
            return false;
        }
    }
    return true;
}

// C++14的四迭代器版本（更安全）
template <typename InputIt1, typename InputIt2>
bool equal(InputIt1 first1, InputIt1 last1,
           InputIt2 first2, InputIt2 last2) {
    // 先检查长度
    auto len1 = std::distance(first1, last1);
    auto len2 = std::distance(first2, last2);
    if (len1 != len2) return false;

    return equal(first1, last1, first2);
}

}  // namespace my
```

**练习题**：
1. 实现`find_first_of`：在第一个范围中查找第二个范围中任意元素的第一次出现
2. 实现`adjacent_find`：查找第一对相邻的相等元素
3. 为什么`all_of`在空范围上返回true？这在数学上叫什么？

**思考题**：
- `find`和`count`的时间复杂度都是O(n)，但使用场景有何不同？

---

#### Day 2: 修改序列算法（5小时）

**学习目标**：掌握copy、transform、remove等算法的实现细节

**copy家族**：

```cpp
namespace my {

// 基本copy
template <typename InputIt, typename OutputIt>
OutputIt copy(InputIt first, InputIt last, OutputIt result) {
    for (; first != last; ++first, ++result) {
        *result = *first;
    }
    return result;  // 返回目标范围的end
}

// copy_if：条件复制
template <typename InputIt, typename OutputIt, typename UnaryPred>
OutputIt copy_if(InputIt first, InputIt last, OutputIt result, UnaryPred pred) {
    for (; first != last; ++first) {
        if (pred(*first)) {
            *result = *first;
            ++result;
        }
    }
    return result;
}

// copy_n：复制n个元素
template <typename InputIt, typename Size, typename OutputIt>
OutputIt copy_n(InputIt first, Size n, OutputIt result) {
    for (Size i = 0; i < n; ++first, ++result, ++i) {
        *result = *first;
    }
    return result;
}

// copy_backward：从后向前复制（处理重叠情况）
template <typename BidirIt1, typename BidirIt2>
BidirIt2 copy_backward(BidirIt1 first, BidirIt1 last, BidirIt2 result) {
    while (first != last) {
        *(--result) = *(--last);
    }
    return result;
}

}  // namespace my
```

**为什么需要copy_backward？**

```cpp
// 考虑在同一容器内移动元素
void demonstrate_overlap() {
    std::vector<int> v = {1, 2, 3, 4, 5, 0, 0, 0};
    //                    ^     ^     ^
    //                  first  last  result

    // 目标：将[1,2,3,4,5]复制到[3,4,5,0,0]的位置
    // 即：结果应该是 {1, 2, 1, 2, 3, 4, 5, 0}

    // 使用copy会出问题！
    // std::copy(v.begin(), v.begin() + 5, v.begin() + 2);
    // 因为：当复制第3个元素时，v[2]已经被覆盖了

    // 正确方式：使用copy_backward
    std::copy_backward(v.begin(), v.begin() + 5, v.begin() + 7);
    // 从后向前复制：先复制5到位置6，再复制4到位置5...
}
```

**transform的实现**：

```cpp
namespace my {

// 一元transform
template <typename InputIt, typename OutputIt, typename UnaryOp>
OutputIt transform(InputIt first, InputIt last, OutputIt result, UnaryOp op) {
    for (; first != last; ++first, ++result) {
        *result = op(*first);
    }
    return result;
}

// 二元transform
template <typename InputIt1, typename InputIt2, typename OutputIt, typename BinaryOp>
OutputIt transform(InputIt1 first1, InputIt1 last1,
                   InputIt2 first2, OutputIt result, BinaryOp op) {
    for (; first1 != last1; ++first1, ++first2, ++result) {
        *result = op(*first1, *first2);
    }
    return result;
}

}  // namespace my

// 使用示例
void demo_transform() {
    std::vector<int> v = {1, 2, 3, 4, 5};
    std::vector<int> squares(5);

    // 一元：计算平方
    std::transform(v.begin(), v.end(), squares.begin(),
                   [](int x) { return x * x; });

    // 二元：两个向量相加
    std::vector<int> a = {1, 2, 3};
    std::vector<int> b = {4, 5, 6};
    std::vector<int> sum(3);
    std::transform(a.begin(), a.end(), b.begin(), sum.begin(),
                   std::plus<int>{});
    // sum = {5, 7, 9}
}
```

**remove和erase-remove idiom**：

```cpp
namespace my {

// remove不真正删除元素，只是将不删除的元素移到前面
template <typename ForwardIt, typename T>
ForwardIt remove(ForwardIt first, ForwardIt last, const T& value) {
    // 找到第一个要删除的元素
    first = std::find(first, last, value);
    if (first == last) return last;

    // result指向下一个写入位置
    ForwardIt result = first;
    ++first;

    // 将不删除的元素复制到前面
    for (; first != last; ++first) {
        if (!(*first == value)) {
            *result = std::move(*first);
            ++result;
        }
    }
    return result;  // 返回新的逻辑end
}

// remove_if
template <typename ForwardIt, typename UnaryPred>
ForwardIt remove_if(ForwardIt first, ForwardIt last, UnaryPred pred) {
    first = std::find_if(first, last, pred);
    if (first == last) return last;

    ForwardIt result = first;
    ++first;

    for (; first != last; ++first) {
        if (!pred(*first)) {
            *result = std::move(*first);
            ++result;
        }
    }
    return result;
}

}  // namespace my

// erase-remove idiom
void demo_erase_remove() {
    std::vector<int> v = {1, 2, 3, 2, 4, 2, 5};

    // 错误理解：以为remove会删除元素
    // auto it = std::remove(v.begin(), v.end(), 2);
    // 此时v可能是 {1, 3, 4, 5, ?, ?, ?}，size仍然是7

    // 正确使用：配合erase
    v.erase(std::remove(v.begin(), v.end(), 2), v.end());
    // 现在v = {1, 3, 4, 5}，size是4

    // C++20更简洁
    // std::erase(v, 2);
}
```

**练习题**：
1. 实现`replace`和`replace_if`
2. 实现`unique`（移除相邻重复元素）
3. 解释为什么`remove`返回迭代器而不是直接删除元素

---

#### Day 3: 排序算法基础（5小时）

**学习目标**：理解基本排序算法的实现和时间复杂度

**插入排序**：

```cpp
namespace my {

// 插入排序：适合小数组和几乎有序的数组
template <typename RandomIt, typename Compare = std::less<>>
void insertion_sort(RandomIt first, RandomIt last, Compare comp = Compare{}) {
    if (first == last) return;

    for (auto it = first + 1; it != last; ++it) {
        // 将*it插入到[first, it)的正确位置
        auto key = std::move(*it);
        auto j = it;

        // 将比key大的元素向后移动
        while (j != first && comp(key, *(j - 1))) {
            *j = std::move(*(j - 1));
            --j;
        }
        *j = std::move(key);
    }
}

}  // namespace my

// 时间复杂度分析：
// - 最好情况（已排序）：O(n)，每个元素只比较1次
// - 最坏情况（逆序）：O(n²)
// - 平均情况：O(n²)
// - 空间复杂度：O(1)
// - 稳定性：稳定
```

**选择排序**：

```cpp
namespace my {

// 选择排序：简单但低效
template <typename RandomIt, typename Compare = std::less<>>
void selection_sort(RandomIt first, RandomIt last, Compare comp = Compare{}) {
    for (auto it = first; it != last; ++it) {
        // 找到[it, last)中的最小元素
        auto min_it = std::min_element(it, last, comp);
        if (min_it != it) {
            std::iter_swap(it, min_it);
        }
    }
}

}  // namespace my

// 时间复杂度：始终是O(n²)
// 空间复杂度：O(1)
// 稳定性：不稳定（交换可能打乱相等元素的顺序）
```

**归并排序**：

```cpp
namespace my {

// 归并排序：稳定的O(n log n)排序
template <typename RandomIt, typename Compare = std::less<>>
void merge_sort(RandomIt first, RandomIt last, Compare comp = Compare{}) {
    auto size = last - first;
    if (size <= 1) return;

    auto mid = first + size / 2;

    // 递归排序两半
    merge_sort(first, mid, comp);
    merge_sort(mid, last, comp);

    // 合并两个有序序列
    std::inplace_merge(first, mid, last, comp);
}

// 自己实现merge（非原地版本）
template <typename InputIt1, typename InputIt2, typename OutputIt, typename Compare>
OutputIt merge(InputIt1 first1, InputIt1 last1,
               InputIt2 first2, InputIt2 last2,
               OutputIt result, Compare comp) {
    while (first1 != last1 && first2 != last2) {
        if (comp(*first2, *first1)) {
            *result = *first2;
            ++first2;
        } else {
            *result = *first1;
            ++first1;
        }
        ++result;
    }
    // 复制剩余元素
    result = std::copy(first1, last1, result);
    result = std::copy(first2, last2, result);
    return result;
}

}  // namespace my

// 时间复杂度：O(n log n)，始终如此
// 空间复杂度：O(n)（需要临时数组）
// 稳定性：稳定
```

**快速排序基础**：

```cpp
namespace my {

// 快速排序的核心：分区
template <typename RandomIt, typename Compare = std::less<>>
RandomIt partition(RandomIt first, RandomIt last, Compare comp = Compare{}) {
    // 选择最后一个元素作为pivot（简单但不最优）
    auto pivot = last - 1;

    // i指向第一个大于pivot的元素
    auto i = first;

    for (auto j = first; j != pivot; ++j) {
        if (comp(*j, *pivot)) {
            std::iter_swap(i, j);
            ++i;
        }
    }
    std::iter_swap(i, pivot);
    return i;  // 返回pivot的最终位置
}

template <typename RandomIt, typename Compare = std::less<>>
void quicksort_basic(RandomIt first, RandomIt last, Compare comp = Compare{}) {
    if (last - first <= 1) return;

    auto pivot = partition(first, last, comp);
    quicksort_basic(first, pivot, comp);
    quicksort_basic(pivot + 1, last, comp);
}

}  // namespace my

// 时间复杂度：
// - 平均：O(n log n)
// - 最坏（已排序）：O(n²)
// 空间复杂度：O(log n)递归栈
// 稳定性：不稳定
```

**练习题**：
1. 实现冒泡排序并分析其复杂度
2. 修改快速排序使用"三数取中"选择pivot
3. 比较归并排序和快速排序在不同数据分布下的性能

---

#### Day 4: 高级排序——IntroSort深入（5小时）

**学习目标**：理解std::sort的完整实现策略

**IntroSort的设计思想**：

```cpp
// IntroSort = Introspective Sort
// 结合三种排序算法的优点：
// 1. QuickSort：平均O(n log n)，cache友好
// 2. HeapSort：保证最坏O(n log n)
// 3. InsertionSort：小数组高效

// 策略：
// - 正常情况使用QuickSort
// - 当递归深度超过2*log2(n)时，切换到HeapSort（避免最坏情况）
// - 小于16个元素时使用InsertionSort
```

**完整的IntroSort实现**：

```cpp
namespace my {

// 堆操作（用于HeapSort）
template <typename RandomIt, typename Compare>
void sift_down(RandomIt first, typename std::iterator_traits<RandomIt>::difference_type len,
               typename std::iterator_traits<RandomIt>::difference_type hole, Compare comp) {
    auto value = std::move(*(first + hole));
    auto child = 2 * hole + 1;

    while (child < len) {
        // 选择较大的子节点
        if (child + 1 < len && comp(*(first + child), *(first + child + 1))) {
            ++child;
        }
        // 如果子节点更大，下沉
        if (comp(value, *(first + child))) {
            *(first + hole) = std::move(*(first + child));
            hole = child;
            child = 2 * hole + 1;
        } else {
            break;
        }
    }
    *(first + hole) = std::move(value);
}

template <typename RandomIt, typename Compare>
void heap_sort(RandomIt first, RandomIt last, Compare comp) {
    auto len = last - first;
    if (len <= 1) return;

    // 建堆
    for (auto i = len / 2 - 1; i >= 0; --i) {
        sift_down(first, len, i, comp);
    }

    // 排序
    while (len > 1) {
        std::iter_swap(first, first + len - 1);
        --len;
        sift_down(first, len, 0, comp);
    }
}

// 三数取中
template <typename RandomIt, typename Compare>
RandomIt median_of_three(RandomIt a, RandomIt b, RandomIt c, Compare comp) {
    if (comp(*a, *b)) {
        if (comp(*b, *c)) return b;       // a < b < c
        else if (comp(*a, *c)) return c;  // a < c <= b
        else return a;                     // c <= a < b
    } else {
        if (comp(*a, *c)) return a;       // b <= a < c
        else if (comp(*b, *c)) return c;  // b < c <= a
        else return b;                     // c <= b <= a
    }
}

// 分区（Hoare分区方案）
template <typename RandomIt, typename Compare>
RandomIt partition_hoare(RandomIt first, RandomIt last, Compare comp) {
    auto size = last - first;
    auto mid = first + size / 2;

    // 三数取中选pivot
    auto pivot_it = median_of_three(first, mid, last - 1, comp);
    auto pivot = *pivot_it;

    auto left = first;
    auto right = last - 1;

    while (true) {
        while (comp(*left, pivot)) ++left;
        while (comp(pivot, *right)) --right;
        if (left >= right) return right + 1;
        std::iter_swap(left++, right--);
    }
}

// IntroSort主体
template <typename RandomIt, typename Compare>
void introsort_loop(RandomIt first, RandomIt last, int depth_limit, Compare comp) {
    constexpr int threshold = 16;  // 小数组阈值

    while (last - first > threshold) {
        if (depth_limit == 0) {
            // 递归过深，切换到堆排序
            heap_sort(first, last, comp);
            return;
        }
        --depth_limit;

        // 分区
        auto pivot = partition_hoare(first, last, comp);

        // 对较小的部分递归，较大的部分迭代（尾递归优化）
        if (pivot - first < last - pivot) {
            introsort_loop(first, pivot, depth_limit, comp);
            first = pivot;
        } else {
            introsort_loop(pivot, last, depth_limit, comp);
            last = pivot;
        }
    }
}

// 公开接口
template <typename RandomIt, typename Compare = std::less<>>
void sort(RandomIt first, RandomIt last, Compare comp = Compare{}) {
    if (first == last) return;

    auto size = last - first;
    int depth_limit = 2 * static_cast<int>(std::log2(size));

    // 第一阶段：IntroSort（QuickSort + HeapSort）
    introsort_loop(first, last, depth_limit, comp);

    // 第二阶段：InsertionSort清理小区间
    insertion_sort(first, last, comp);
}

}  // namespace my
```

**性能分析**：

```cpp
#include <chrono>
#include <random>
#include <algorithm>

void benchmark_sort() {
    std::vector<int> sizes = {1000, 10000, 100000, 1000000};
    std::mt19937 rng(42);

    for (int size : sizes) {
        std::vector<int> data(size);

        // 测试随机数据
        std::generate(data.begin(), data.end(), rng);
        auto v1 = data;
        auto start = std::chrono::high_resolution_clock::now();
        std::sort(v1.begin(), v1.end());
        auto end = std::chrono::high_resolution_clock::now();
        auto dur = std::chrono::duration_cast<std::chrono::microseconds>(end - start);
        std::cout << "Random " << size << ": " << dur.count() << " us\n";

        // 测试已排序数据
        std::iota(data.begin(), data.end(), 0);
        auto v2 = data;
        start = std::chrono::high_resolution_clock::now();
        std::sort(v2.begin(), v2.end());
        end = std::chrono::high_resolution_clock::now();
        dur = std::chrono::duration_cast<std::chrono::microseconds>(end - start);
        std::cout << "Sorted " << size << ": " << dur.count() << " us\n";

        // 测试逆序数据
        std::reverse(data.begin(), data.end());
        auto v3 = data;
        start = std::chrono::high_resolution_clock::now();
        std::sort(v3.begin(), v3.end());
        end = std::chrono::high_resolution_clock::now();
        dur = std::chrono::duration_cast<std::chrono::microseconds>(end - start);
        std::cout << "Reverse " << size << ": " << dur.count() << " us\n";

        std::cout << "---\n";
    }
}
```

**练习题**：
1. 修改IntroSort的阈值参数，测试对性能的影响
2. 实现`partial_sort`（只排序前k个元素）
3. 解释为什么标准库使用IntroSort而不是纯QuickSort

**思考题**：
- 为什么小数组用插入排序而不是继续用快排？

---

#### Day 5: 二分搜索算法族（4小时）

**学习目标**：掌握lower_bound、upper_bound、binary_search的精确语义

**核心概念**：

```cpp
// 二分搜索算法要求序列已排序！
// 它们的语义是精确定义的：

// lower_bound: 返回第一个 >= value 的位置
// upper_bound: 返回第一个 > value 的位置
// equal_range: 返回 [lower_bound, upper_bound)
// binary_search: 判断value是否存在

// 记忆方法：
// lower_bound: 如果要插入value，这是保持有序的最左位置
// upper_bound: 如果要插入value，这是保持有序的最右位置
```

**完整实现**：

```cpp
namespace my {

template <typename ForwardIt, typename T, typename Compare = std::less<>>
ForwardIt lower_bound(ForwardIt first, ForwardIt last, const T& value,
                      Compare comp = Compare{}) {
    auto count = std::distance(first, last);

    while (count > 0) {
        auto step = count / 2;
        auto mid = first;
        std::advance(mid, step);

        if (comp(*mid, value)) {
            // *mid < value，答案在右半部分
            first = ++mid;
            count -= step + 1;
        } else {
            // *mid >= value，答案可能是mid或在左半部分
            count = step;
        }
    }
    return first;
}

template <typename ForwardIt, typename T, typename Compare = std::less<>>
ForwardIt upper_bound(ForwardIt first, ForwardIt last, const T& value,
                      Compare comp = Compare{}) {
    auto count = std::distance(first, last);

    while (count > 0) {
        auto step = count / 2;
        auto mid = first;
        std::advance(mid, step);

        if (!comp(value, *mid)) {
            // *mid <= value，答案在右半部分
            first = ++mid;
            count -= step + 1;
        } else {
            // *mid > value，答案可能是mid或在左半部分
            count = step;
        }
    }
    return first;
}

template <typename ForwardIt, typename T, typename Compare = std::less<>>
std::pair<ForwardIt, ForwardIt>
equal_range(ForwardIt first, ForwardIt last, const T& value,
            Compare comp = Compare{}) {
    return {
        lower_bound(first, last, value, comp),
        upper_bound(first, last, value, comp)
    };
}

template <typename ForwardIt, typename T, typename Compare = std::less<>>
bool binary_search(ForwardIt first, ForwardIt last, const T& value,
                   Compare comp = Compare{}) {
    auto it = lower_bound(first, last, value, comp);
    return it != last && !comp(value, *it);
    // 注意：不是 *it == value
    // 因为我们只有Compare，没有等价判断
    // !(a < b) && !(b < a) 意味着 a 等价于 b
}

}  // namespace my
```

**使用示例**：

```cpp
void demo_binary_search() {
    std::vector<int> v = {1, 2, 2, 2, 3, 4, 5};
    //                    0  1  2  3  4  5  6

    // lower_bound: 第一个 >= 2 的位置
    auto lb = std::lower_bound(v.begin(), v.end(), 2);
    std::cout << "lower_bound(2): index " << (lb - v.begin()) << std::endl;  // 1

    // upper_bound: 第一个 > 2 的位置
    auto ub = std::upper_bound(v.begin(), v.end(), 2);
    std::cout << "upper_bound(2): index " << (ub - v.begin()) << std::endl;  // 4

    // equal_range: [lower_bound, upper_bound)
    auto [lo, hi] = std::equal_range(v.begin(), v.end(), 2);
    std::cout << "equal_range(2): [" << (lo - v.begin()) << ", "
              << (hi - v.begin()) << ")" << std::endl;  // [1, 4)
    std::cout << "Count of 2: " << (hi - lo) << std::endl;  // 3

    // 查找不存在的元素
    auto it = std::lower_bound(v.begin(), v.end(), 6);
    std::cout << "lower_bound(6): " << (it == v.end() ? "end" : "found") << std::endl;  // end
}
```

**与自定义比较器配合**：

```cpp
struct Person {
    std::string name;
    int age;
};

void demo_custom_compare() {
    std::vector<Person> people = {
        {"Alice", 25},
        {"Bob", 30},
        {"Charlie", 30},
        {"David", 35}
    };

    // 按年龄排序
    std::sort(people.begin(), people.end(),
              [](const Person& a, const Person& b) { return a.age < b.age; });

    // 查找年龄>=30的第一个人
    auto it = std::lower_bound(people.begin(), people.end(), 30,
        [](const Person& p, int age) { return p.age < age; });
    // 注意：谓词签名是 (element, value)

    if (it != people.end()) {
        std::cout << "First person >= 30: " << it->name << std::endl;  // Bob
    }
}
```

**练习题**：
1. 使用binary_search相关函数实现一个`count_in_sorted_range`函数
2. 解释为什么binary_search的判断是`!comp(value, *it)`而不是`*it == value`
3. 实现一个在旋转有序数组中查找元素的函数

---

#### Day 6: 堆操作算法（4小时）

**学习目标**：理解堆结构和相关算法的实现

**堆的基本概念**：

```cpp
// 堆是完全二叉树，用数组表示
// 对于位置i的元素：
// - 父节点：(i - 1) / 2
// - 左子节点：2 * i + 1
// - 右子节点：2 * i + 2

// 最大堆性质：父节点 >= 子节点
// 最小堆性质：父节点 <= 子节点

// STL的堆函数默认创建最大堆
```

**完整的堆操作实现**：

```cpp
namespace my {

// push_heap: 将最后一个元素上浮到正确位置
template <typename RandomIt, typename Compare = std::less<>>
void push_heap(RandomIt first, RandomIt last, Compare comp = Compare{}) {
    if (last - first <= 1) return;

    auto hole = (last - first) - 1;  // 最后一个元素的索引
    auto value = std::move(*(first + hole));

    // 上浮
    while (hole > 0) {
        auto parent = (hole - 1) / 2;
        if (comp(*(first + parent), value)) {
            *(first + hole) = std::move(*(first + parent));
            hole = parent;
        } else {
            break;
        }
    }
    *(first + hole) = std::move(value);
}

// pop_heap: 将根节点移到末尾，然后下沉新根
template <typename RandomIt, typename Compare = std::less<>>
void pop_heap(RandomIt first, RandomIt last, Compare comp = Compare{}) {
    if (last - first <= 1) return;

    // 交换首尾
    std::iter_swap(first, last - 1);

    // 对新的根进行下沉
    auto len = (last - first) - 1;  // 不包括末尾的原根
    auto hole = 0;
    auto value = std::move(*first);

    while (true) {
        auto child = 2 * hole + 1;
        if (child >= len) break;

        // 选择较大的子节点
        if (child + 1 < len && comp(*(first + child), *(first + child + 1))) {
            ++child;
        }

        if (comp(value, *(first + child))) {
            *(first + hole) = std::move(*(first + child));
            hole = child;
        } else {
            break;
        }
    }
    *(first + hole) = std::move(value);
}

// make_heap: 将序列转换为堆
template <typename RandomIt, typename Compare = std::less<>>
void make_heap(RandomIt first, RandomIt last, Compare comp = Compare{}) {
    auto len = last - first;
    if (len <= 1) return;

    // 从最后一个非叶节点开始，逐个下沉
    for (auto i = len / 2 - 1; i >= 0; --i) {
        // 下沉 first + i
        auto hole = i;
        auto value = std::move(*(first + hole));

        while (true) {
            auto child = 2 * hole + 1;
            if (child >= len) break;

            if (child + 1 < len && comp(*(first + child), *(first + child + 1))) {
                ++child;
            }

            if (comp(value, *(first + child))) {
                *(first + hole) = std::move(*(first + child));
                hole = child;
            } else {
                break;
            }
        }
        *(first + hole) = std::move(value);
    }
}

// sort_heap: 将堆排序为有序序列
template <typename RandomIt, typename Compare = std::less<>>
void sort_heap(RandomIt first, RandomIt last, Compare comp = Compare{}) {
    while (last - first > 1) {
        pop_heap(first, last--, comp);
    }
}

// is_heap: 检查是否为堆
template <typename RandomIt, typename Compare = std::less<>>
bool is_heap(RandomIt first, RandomIt last, Compare comp = Compare{}) {
    auto len = last - first;
    for (decltype(len) i = 1; i < len; ++i) {
        auto parent = (i - 1) / 2;
        if (comp(*(first + parent), *(first + i))) {
            return false;
        }
    }
    return true;
}

}  // namespace my
```

**使用堆实现优先队列**：

```cpp
#include <queue>

void demo_priority_queue() {
    // std::priority_queue内部使用堆
    std::priority_queue<int> pq;  // 最大堆

    pq.push(3);
    pq.push(1);
    pq.push(4);
    pq.push(1);
    pq.push(5);

    while (!pq.empty()) {
        std::cout << pq.top() << " ";  // 5 4 3 1 1
        pq.pop();
    }

    // 最小堆
    std::priority_queue<int, std::vector<int>, std::greater<int>> min_pq;
    min_pq.push(3);
    min_pq.push(1);
    min_pq.push(4);

    while (!min_pq.empty()) {
        std::cout << min_pq.top() << " ";  // 1 3 4
        min_pq.pop();
    }
}
```

**练习题**：
1. 实现`is_heap_until`：返回第一个违反堆性质的位置
2. 使用堆实现一个支持动态更新优先级的优先队列
3. 比较堆排序和快速排序的cache性能

---

#### Day 7: 数值算法与综合练习（5小时）

**数值算法**：

```cpp
#include <numeric>

namespace my {

// accumulate: 求和（或通用fold）
template <typename InputIt, typename T>
T accumulate(InputIt first, InputIt last, T init) {
    for (; first != last; ++first) {
        init = std::move(init) + *first;
    }
    return init;
}

template <typename InputIt, typename T, typename BinaryOp>
T accumulate(InputIt first, InputIt last, T init, BinaryOp op) {
    for (; first != last; ++first) {
        init = op(std::move(init), *first);
    }
    return init;
}

// inner_product: 内积
template <typename InputIt1, typename InputIt2, typename T>
T inner_product(InputIt1 first1, InputIt1 last1, InputIt2 first2, T init) {
    for (; first1 != last1; ++first1, ++first2) {
        init = std::move(init) + (*first1 * *first2);
    }
    return init;
}

// partial_sum: 前缀和
template <typename InputIt, typename OutputIt>
OutputIt partial_sum(InputIt first, InputIt last, OutputIt result) {
    if (first == last) return result;

    auto sum = *first;
    *result = sum;
    ++first;
    ++result;

    for (; first != last; ++first, ++result) {
        sum = std::move(sum) + *first;
        *result = sum;
    }
    return result;
}

// adjacent_difference: 相邻差
template <typename InputIt, typename OutputIt>
OutputIt adjacent_difference(InputIt first, InputIt last, OutputIt result) {
    if (first == last) return result;

    auto prev = *first;
    *result = prev;
    ++first;
    ++result;

    for (; first != last; ++first, ++result) {
        auto curr = *first;
        *result = curr - prev;
        prev = std::move(curr);
    }
    return result;
}

// iota: 填充递增序列
template <typename ForwardIt, typename T>
void iota(ForwardIt first, ForwardIt last, T value) {
    for (; first != last; ++first, ++value) {
        *first = value;
    }
}

}  // namespace my
```

**C++17/20新增数值算法**：

```cpp
#include <numeric>

void demo_new_numeric() {
    std::vector<int> v = {1, 2, 3, 4, 5};

    // C++17: reduce（并行友好的accumulate）
    auto sum = std::reduce(v.begin(), v.end());

    // C++17: transform_reduce（并行友好的inner_product）
    auto dot = std::transform_reduce(v.begin(), v.end(), v.begin(), 0);

    // C++17: inclusive_scan / exclusive_scan（并行友好的partial_sum）
    std::vector<int> prefix(5);
    std::inclusive_scan(v.begin(), v.end(), prefix.begin());
    // prefix = {1, 3, 6, 10, 15}

    std::exclusive_scan(v.begin(), v.end(), prefix.begin(), 0);
    // prefix = {0, 1, 3, 6, 10}

    // C++20: midpoint（避免溢出的中点计算）
    int a = 1000000000, b = 2000000000;
    // (a + b) / 2 可能溢出！
    int mid = std::midpoint(a, b);  // 安全
}
```

**本周综合练习**：

```cpp
// 实现一个完整的排序算法库测试框架

#include <algorithm>
#include <chrono>
#include <functional>
#include <iomanip>
#include <iostream>
#include <random>
#include <string>
#include <vector>

class SortBenchmark {
public:
    using SortFunc = std::function<void(std::vector<int>&)>;

    void add_algorithm(const std::string& name, SortFunc func) {
        algorithms_.emplace_back(name, func);
    }

    void run(int size, int iterations) {
        std::mt19937 rng(42);

        std::cout << "Size: " << size << ", Iterations: " << iterations << "\n";
        std::cout << std::setw(20) << "Algorithm"
                  << std::setw(15) << "Time (us)"
                  << std::setw(15) << "Verified" << "\n";
        std::cout << std::string(50, '-') << "\n";

        for (const auto& [name, func] : algorithms_) {
            long long total_time = 0;
            bool verified = true;

            for (int i = 0; i < iterations; ++i) {
                std::vector<int> data(size);
                std::generate(data.begin(), data.end(), rng);

                auto start = std::chrono::high_resolution_clock::now();
                func(data);
                auto end = std::chrono::high_resolution_clock::now();

                total_time += std::chrono::duration_cast<std::chrono::microseconds>(
                    end - start).count();

                if (!std::is_sorted(data.begin(), data.end())) {
                    verified = false;
                }
            }

            std::cout << std::setw(20) << name
                      << std::setw(15) << total_time / iterations
                      << std::setw(15) << (verified ? "Yes" : "No") << "\n";
        }
    }

private:
    std::vector<std::pair<std::string, SortFunc>> algorithms_;
};

void test_sort_algorithms() {
    SortBenchmark bench;

    bench.add_algorithm("std::sort", [](std::vector<int>& v) {
        std::sort(v.begin(), v.end());
    });

    bench.add_algorithm("std::stable_sort", [](std::vector<int>& v) {
        std::stable_sort(v.begin(), v.end());
    });

    bench.add_algorithm("heap_sort", [](std::vector<int>& v) {
        std::make_heap(v.begin(), v.end());
        std::sort_heap(v.begin(), v.end());
    });

    // 添加你自己实现的排序算法
    // bench.add_algorithm("my::sort", ...);

    bench.run(100000, 10);
}
```

**本周检验标准**：
- [ ] 能实现find、copy、transform等常用算法
- [ ] 理解erase-remove idiom的原理
- [ ] 掌握IntroSort的设计思想和实现
- [ ] 精确理解lower_bound和upper_bound的语义
- [ ] 能正确使用堆操作算法
- [ ] 熟悉数值算法的使用场景

---

### 第三周：迭代器适配器

**学习目标**：理解和使用迭代器适配器

#### 常用适配器
```cpp
// reverse_iterator
std::vector<int> v = {1, 2, 3, 4, 5};
for (auto it = v.rbegin(); it != v.rend(); ++it) {
    std::cout << *it << " ";  // 5 4 3 2 1
}

// back_inserter / front_inserter / inserter
std::vector<int> src = {1, 2, 3};
std::vector<int> dst;
std::copy(src.begin(), src.end(), std::back_inserter(dst));

// move_iterator
std::vector<std::string> src2 = {"a", "b", "c"};
std::vector<std::string> dst2;
std::copy(std::make_move_iterator(src2.begin()),
          std::make_move_iterator(src2.end()),
          std::back_inserter(dst2));
// src2中的字符串已被移动

// istream_iterator / ostream_iterator
std::copy(std::istream_iterator<int>(std::cin),
          std::istream_iterator<int>(),
          std::back_inserter(v));

std::copy(v.begin(), v.end(),
          std::ostream_iterator<int>(std::cout, " "));
```

#### reverse_iterator实现
```cpp
template <typename Iterator>
class reverse_iterator {
    Iterator current_;

public:
    using iterator_type = Iterator;
    using difference_type = typename std::iterator_traits<Iterator>::difference_type;
    using value_type = typename std::iterator_traits<Iterator>::value_type;
    using pointer = typename std::iterator_traits<Iterator>::pointer;
    using reference = typename std::iterator_traits<Iterator>::reference;
    using iterator_category = typename std::iterator_traits<Iterator>::iterator_category;

    reverse_iterator() = default;
    explicit reverse_iterator(Iterator it) : current_(it) {}

    Iterator base() const { return current_; }

    reference operator*() const {
        Iterator tmp = current_;
        return *--tmp;  // 指向前一个元素
    }

    reverse_iterator& operator++() {
        --current_;
        return *this;
    }

    reverse_iterator& operator--() {
        ++current_;
        return *this;
    }

    reverse_iterator operator+(difference_type n) const {
        return reverse_iterator(current_ - n);
    }

    // ...其他操作
};
```

---

### 第三周详细学习计划

#### Day 1: reverse_iterator深入（4小时）

**学习目标**：理解反向迭代器的精妙设计

**核心概念**：
reverse_iterator是最重要的迭代器适配器之一。它的设计体现了STL"半开区间"的一致性。

```cpp
// 为什么需要reverse_iterator？
// 考虑：如何用统一的方式反向遍历容器？

std::vector<int> v = {1, 2, 3, 4, 5};

// 方式1：手动反向遍历（容易出错）
for (auto it = v.end() - 1; it >= v.begin(); --it) {
    std::cout << *it << " ";
    if (it == v.begin()) break;  // 必须特殊处理！
}

// 方式2：使用reverse_iterator（优雅）
for (auto it = v.rbegin(); it != v.rend(); ++it) {
    std::cout << *it << " ";
}
```

**reverse_iterator的精妙之处**：

```cpp
// 关键设计：*it 返回的是 *(current - 1)

// 为什么要减1？看图：
//
// 正向:  begin()                           end()
//           ↓                                ↓
//        [ 1 ][ 2 ][ 3 ][ 4 ][ 5 ][   ]
//           ↑                       ↑
// 反向:  rend()                  rbegin()
//
// rbegin() 内部存储的是 end()
// 但 *rbegin() 应该返回最后一个元素(5)
// 所以 *rbegin() = *(end() - 1) = 5

// 同样，rend() 内部存储的是 begin()
// 但 rend() 指向的是"第一个元素之前"的位置
// 这保证了 [rbegin, rend) 是有效的半开区间

template <typename Iterator>
class reverse_iterator {
    Iterator current_;  // 存储的是"下一个"位置

public:
    // operator* 返回前一个位置的元素
    auto operator*() const {
        Iterator tmp = current_;
        return *--tmp;
    }

    // base() 返回底层迭代器
    Iterator base() const { return current_; }
};
```

**完整的reverse_iterator实现**：

```cpp
namespace my {

template <typename Iterator>
class reverse_iterator {
public:
    using iterator_type = Iterator;
    using iterator_category = typename std::iterator_traits<Iterator>::iterator_category;
    using value_type = typename std::iterator_traits<Iterator>::value_type;
    using difference_type = typename std::iterator_traits<Iterator>::difference_type;
    using pointer = typename std::iterator_traits<Iterator>::pointer;
    using reference = typename std::iterator_traits<Iterator>::reference;

private:
    Iterator current_;

public:
    // 构造函数
    reverse_iterator() : current_() {}
    explicit reverse_iterator(Iterator it) : current_(it) {}

    // 从另一个reverse_iterator转换
    template <typename U>
    reverse_iterator(const reverse_iterator<U>& other) : current_(other.base()) {}

    // 获取底层迭代器
    Iterator base() const { return current_; }

    // 解引用——核心：返回前一个位置
    reference operator*() const {
        Iterator tmp = current_;
        return *--tmp;
    }

    pointer operator->() const {
        return std::addressof(operator*());
    }

    // 下标访问
    reference operator[](difference_type n) const {
        return *(*this + n);
    }

    // 递增（实际上是递减底层迭代器）
    reverse_iterator& operator++() {
        --current_;
        return *this;
    }

    reverse_iterator operator++(int) {
        reverse_iterator tmp = *this;
        --current_;
        return tmp;
    }

    // 递减（实际上是递增底层迭代器）
    reverse_iterator& operator--() {
        ++current_;
        return *this;
    }

    reverse_iterator operator--(int) {
        reverse_iterator tmp = *this;
        ++current_;
        return tmp;
    }

    // 随机访问（方向相反）
    reverse_iterator operator+(difference_type n) const {
        return reverse_iterator(current_ - n);
    }

    reverse_iterator operator-(difference_type n) const {
        return reverse_iterator(current_ + n);
    }

    reverse_iterator& operator+=(difference_type n) {
        current_ -= n;
        return *this;
    }

    reverse_iterator& operator-=(difference_type n) {
        current_ += n;
        return *this;
    }
};

// 比较运算符
template <typename Iter1, typename Iter2>
bool operator==(const reverse_iterator<Iter1>& a, const reverse_iterator<Iter2>& b) {
    return a.base() == b.base();
}

template <typename Iter1, typename Iter2>
bool operator<(const reverse_iterator<Iter1>& a, const reverse_iterator<Iter2>& b) {
    return a.base() > b.base();  // 注意：方向相反！
}

// 距离
template <typename Iter1, typename Iter2>
auto operator-(const reverse_iterator<Iter1>& a, const reverse_iterator<Iter2>& b) {
    return b.base() - a.base();  // 注意：方向相反！
}

// 辅助函数
template <typename Iterator>
reverse_iterator<Iterator> make_reverse_iterator(Iterator it) {
    return reverse_iterator<Iterator>(it);
}

}  // namespace my
```

**base()的陷阱**：

```cpp
void demo_base_pitfall() {
    std::vector<int> v = {1, 2, 3, 4, 5};

    auto rit = std::find(v.rbegin(), v.rend(), 3);
    // rit 指向 3

    // 想要删除这个元素？
    // v.erase(rit);  // 错误！erase需要正向迭代器

    // 使用base()？
    auto it = rit.base();
    // 注意：it 指向的是 3 后面的元素（4）！

    // 正确的删除方式
    v.erase(std::prev(rit.base()));  // 或者
    v.erase((++rit).base());         // 先++再取base
}
```

**练习题**：
1. 解释为什么`rit.base()`指向的是`*rit`后面的元素
2. 实现一个函数，正确地删除reverse_iterator指向的元素
3. 如果Iterator只是BidirectionalIterator，reverse_iterator会缺少哪些操作？

---

#### Day 2: insert_iterator系列（4小时）

**学习目标**：掌握三种插入迭代器的使用场景和实现

**三种插入迭代器**：

```cpp
// 1. back_insert_iterator: 调用push_back
// 2. front_insert_iterator: 调用push_front
// 3. insert_iterator: 在指定位置insert

#include <iterator>

void demo_inserters() {
    std::vector<int> src = {1, 2, 3};

    // back_inserter
    std::vector<int> v1;
    std::copy(src.begin(), src.end(), std::back_inserter(v1));
    // v1 = {1, 2, 3}

    // front_inserter (需要支持push_front的容器)
    std::deque<int> d1;
    std::copy(src.begin(), src.end(), std::front_inserter(d1));
    // d1 = {3, 2, 1}  注意顺序！

    // inserter
    std::vector<int> v2 = {10, 20};
    std::copy(src.begin(), src.end(), std::inserter(v2, v2.begin() + 1));
    // v2 = {10, 1, 2, 3, 20}
}
```

**back_insert_iterator实现**：

```cpp
namespace my {

template <typename Container>
class back_insert_iterator {
public:
    using iterator_category = std::output_iterator_tag;
    using value_type = void;
    using difference_type = void;
    using pointer = void;
    using reference = void;
    using container_type = Container;

protected:
    Container* container_;

public:
    explicit back_insert_iterator(Container& c) : container_(&c) {}

    // 赋值操作 = push_back
    back_insert_iterator& operator=(const typename Container::value_type& value) {
        container_->push_back(value);
        return *this;
    }

    back_insert_iterator& operator=(typename Container::value_type&& value) {
        container_->push_back(std::move(value));
        return *this;
    }

    // 这些操作什么都不做，只是为了满足OutputIterator的语法要求
    back_insert_iterator& operator*() { return *this; }
    back_insert_iterator& operator++() { return *this; }
    back_insert_iterator operator++(int) { return *this; }
};

// 辅助函数
template <typename Container>
back_insert_iterator<Container> back_inserter(Container& c) {
    return back_insert_iterator<Container>(c);
}

}  // namespace my
```

**insert_iterator实现**：

```cpp
namespace my {

template <typename Container>
class insert_iterator {
public:
    using iterator_category = std::output_iterator_tag;
    using value_type = void;
    using difference_type = void;
    using pointer = void;
    using reference = void;
    using container_type = Container;

protected:
    Container* container_;
    typename Container::iterator iter_;

public:
    insert_iterator(Container& c, typename Container::iterator it)
        : container_(&c), iter_(it) {}

    insert_iterator& operator=(const typename Container::value_type& value) {
        iter_ = container_->insert(iter_, value);
        ++iter_;  // 移动到插入元素之后
        return *this;
    }

    insert_iterator& operator=(typename Container::value_type&& value) {
        iter_ = container_->insert(iter_, std::move(value));
        ++iter_;
        return *this;
    }

    insert_iterator& operator*() { return *this; }
    insert_iterator& operator++() { return *this; }
    insert_iterator operator++(int) { return *this; }
};

template <typename Container>
insert_iterator<Container> inserter(Container& c, typename Container::iterator it) {
    return insert_iterator<Container>(c, it);
}

}  // namespace my
```

**为什么insert_iterator要++iter_?**

```cpp
// 考虑连续插入
std::vector<int> v = {10, 20};
auto it = std::inserter(v, v.begin() + 1);

*it = 1;  // v = {10, 1, 20}
*it = 2;  // 如果不++，v = {10, 2, 1, 20}（错误！）
          // 正确应该是 v = {10, 1, 2, 20}

// 所以每次insert后要移动iter_，保证下次插入在上次之后
```

**练习题**：
1. 实现`front_insert_iterator`
2. 为什么`back_insert_iterator`的`operator*`返回`*this`而不是返回元素引用？
3. 使用`inserter`和`set`演示自动排序插入

---

#### Day 3: move_iterator与完美转发（5小时）

**学习目标**：理解move_iterator如何实现批量移动语义

**move_iterator的作用**：

```cpp
// 问题：如何将一个容器的元素移动（而非复制）到另一个容器？

std::vector<std::string> src = {"hello", "world", "!"};
std::vector<std::string> dst;

// 复制方式
std::copy(src.begin(), src.end(), std::back_inserter(dst));
// src的字符串仍然有效

// 移动方式
std::copy(std::make_move_iterator(src.begin()),
          std::make_move_iterator(src.end()),
          std::back_inserter(dst));
// src的字符串已被移动，处于有效但未指定状态
```

**move_iterator实现**：

```cpp
namespace my {

template <typename Iterator>
class move_iterator {
public:
    using iterator_type = Iterator;
    using iterator_category = typename std::iterator_traits<Iterator>::iterator_category;
    using value_type = typename std::iterator_traits<Iterator>::value_type;
    using difference_type = typename std::iterator_traits<Iterator>::difference_type;
    using pointer = Iterator;  // 注意：pointer类型是Iterator

    // 核心：reference类型是右值引用！
    using reference = std::conditional_t<
        std::is_reference_v<typename std::iterator_traits<Iterator>::reference>,
        std::remove_reference_t<typename std::iterator_traits<Iterator>::reference>&&,
        typename std::iterator_traits<Iterator>::reference
    >;

private:
    Iterator current_;

public:
    move_iterator() : current_() {}
    explicit move_iterator(Iterator it) : current_(it) {}

    template <typename U>
    move_iterator(const move_iterator<U>& other) : current_(other.base()) {}

    Iterator base() const { return current_; }

    // 核心：解引用返回右值引用
    reference operator*() const {
        return static_cast<reference>(*current_);
    }

    pointer operator->() const {
        return current_;
    }

    reference operator[](difference_type n) const {
        return std::move(current_[n]);
    }

    // 其他操作与普通迭代器相同
    move_iterator& operator++() { ++current_; return *this; }
    move_iterator operator++(int) { auto tmp = *this; ++current_; return tmp; }
    move_iterator& operator--() { --current_; return *this; }
    move_iterator operator--(int) { auto tmp = *this; --current_; return tmp; }
    move_iterator operator+(difference_type n) const { return move_iterator(current_ + n); }
    move_iterator operator-(difference_type n) const { return move_iterator(current_ - n); }
    move_iterator& operator+=(difference_type n) { current_ += n; return *this; }
    move_iterator& operator-=(difference_type n) { current_ -= n; return *this; }
};

template <typename Iterator>
move_iterator<Iterator> make_move_iterator(Iterator it) {
    return move_iterator<Iterator>(it);
}

}  // namespace my
```

**move_iterator的性能优势**：

```cpp
#include <chrono>

void benchmark_move_vs_copy() {
    const int N = 100000;

    // 创建源数据
    std::vector<std::string> src(N, std::string(100, 'x'));

    // 复制方式
    auto src1 = src;  // 先复制一份
    std::vector<std::string> dst1;
    dst1.reserve(N);

    auto start = std::chrono::high_resolution_clock::now();
    std::copy(src1.begin(), src1.end(), std::back_inserter(dst1));
    auto end = std::chrono::high_resolution_clock::now();
    std::cout << "Copy: "
              << std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count()
              << " ms\n";

    // 移动方式
    auto src2 = src;  // 再复制一份
    std::vector<std::string> dst2;
    dst2.reserve(N);

    start = std::chrono::high_resolution_clock::now();
    std::copy(std::make_move_iterator(src2.begin()),
              std::make_move_iterator(src2.end()),
              std::back_inserter(dst2));
    end = std::chrono::high_resolution_clock::now();
    std::cout << "Move: "
              << std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count()
              << " ms\n";

    // 移动版本应该快很多，因为只移动指针，不复制字符数据
}
```

**C++20的std::ranges::move**：

```cpp
// C++20提供了更简洁的方式
std::vector<std::string> src = {"hello", "world"};
std::vector<std::string> dst;

std::ranges::move(src, std::back_inserter(dst));
// 等价于使用move_iterator
```

**练习题**：
1. 解释move_iterator的reference类型为什么是右值引用
2. 如果对已经移动过的元素再次解引用会发生什么？
3. 实现一个`move_if`函数，只移动满足条件的元素

---

#### Day 4: stream_iterator（4小时）

**学习目标**：理解流迭代器如何将I/O操作统一到迭代器接口

**istream_iterator**：

```cpp
#include <iterator>
#include <sstream>

void demo_istream_iterator() {
    std::istringstream iss("1 2 3 4 5");

    // 方式1：传统循环
    int x;
    while (iss >> x) {
        std::cout << x << " ";
    }

    // 方式2：使用istream_iterator
    std::istringstream iss2("1 2 3 4 5");
    std::vector<int> v(std::istream_iterator<int>(iss2),
                       std::istream_iterator<int>());
    // v = {1, 2, 3, 4, 5}

    // 注意：第二个参数是默认构造的istream_iterator
    // 它代表"流结束"
}
```

**istream_iterator实现**：

```cpp
namespace my {

template <typename T, typename CharT = char,
          typename Traits = std::char_traits<CharT>,
          typename Distance = std::ptrdiff_t>
class istream_iterator {
public:
    using iterator_category = std::input_iterator_tag;
    using value_type = T;
    using difference_type = Distance;
    using pointer = const T*;
    using reference = const T&;

    using char_type = CharT;
    using traits_type = Traits;
    using istream_type = std::basic_istream<CharT, Traits>;

private:
    istream_type* stream_;
    T value_;

    void read() {
        if (stream_ && !(*stream_ >> value_)) {
            stream_ = nullptr;  // 读取失败，变为end迭代器
        }
    }

public:
    // 默认构造 = end迭代器
    istream_iterator() : stream_(nullptr), value_() {}

    // 从流构造
    istream_iterator(istream_type& s) : stream_(&s), value_() {
        read();  // 立即读取第一个值
    }

    // 复制构造
    istream_iterator(const istream_iterator&) = default;

    reference operator*() const { return value_; }
    pointer operator->() const { return &value_; }

    // 前置++：读取下一个值
    istream_iterator& operator++() {
        read();
        return *this;
    }

    // 后置++
    istream_iterator operator++(int) {
        istream_iterator tmp = *this;
        read();
        return tmp;
    }

    // 比较
    friend bool operator==(const istream_iterator& a, const istream_iterator& b) {
        return a.stream_ == b.stream_;
    }

    friend bool operator!=(const istream_iterator& a, const istream_iterator& b) {
        return !(a == b);
    }
};

}  // namespace my
```

**ostream_iterator实现**：

```cpp
namespace my {

template <typename T, typename CharT = char,
          typename Traits = std::char_traits<CharT>>
class ostream_iterator {
public:
    using iterator_category = std::output_iterator_tag;
    using value_type = void;
    using difference_type = void;
    using pointer = void;
    using reference = void;

    using char_type = CharT;
    using traits_type = Traits;
    using ostream_type = std::basic_ostream<CharT, Traits>;

private:
    ostream_type* stream_;
    const CharT* delim_;

public:
    ostream_iterator(ostream_type& s) : stream_(&s), delim_(nullptr) {}

    ostream_iterator(ostream_type& s, const CharT* delim)
        : stream_(&s), delim_(delim) {}

    ostream_iterator& operator=(const T& value) {
        *stream_ << value;
        if (delim_) {
            *stream_ << delim_;
        }
        return *this;
    }

    ostream_iterator& operator*() { return *this; }
    ostream_iterator& operator++() { return *this; }
    ostream_iterator operator++(int) { return *this; }
};

}  // namespace my

// 使用示例
void demo_ostream_iterator() {
    std::vector<int> v = {1, 2, 3, 4, 5};

    // 输出到cout，用空格分隔
    std::copy(v.begin(), v.end(),
              std::ostream_iterator<int>(std::cout, " "));
    // 输出: 1 2 3 4 5

    // 输出到stringstream
    std::ostringstream oss;
    std::copy(v.begin(), v.end(),
              std::ostream_iterator<int>(oss, ","));
    std::cout << oss.str();  // "1,2,3,4,5,"
}
```

**实用示例：文件处理**：

```cpp
#include <fstream>

void copy_file_by_lines() {
    std::ifstream input("input.txt");
    std::ofstream output("output.txt");

    // 按行复制
    std::copy(std::istream_iterator<std::string>(input),
              std::istream_iterator<std::string>(),
              std::ostream_iterator<std::string>(output, "\n"));
}

void sum_numbers_from_file() {
    std::ifstream file("numbers.txt");

    int sum = std::accumulate(
        std::istream_iterator<int>(file),
        std::istream_iterator<int>(),
        0);

    std::cout << "Sum: " << sum << std::endl;
}
```

**练习题**：
1. 为什么istream_iterator是InputIterator而不是ForwardIterator？
2. 实现一个line_iterator，按行读取而不是按空白分隔
3. 使用流迭代器实现一个简单的CSV解析器

---

#### Day 5: 自定义迭代器适配器（5小时）

**学习目标**：学会设计和实现自己的迭代器适配器

**实现filter_iterator**：

```cpp
// filter_iterator：只遍历满足条件的元素

namespace my {

template <typename Iterator, typename Predicate>
class filter_iterator {
public:
    using iterator_category = std::forward_iterator_tag;  // 最多是ForwardIterator
    using value_type = typename std::iterator_traits<Iterator>::value_type;
    using difference_type = typename std::iterator_traits<Iterator>::difference_type;
    using pointer = typename std::iterator_traits<Iterator>::pointer;
    using reference = typename std::iterator_traits<Iterator>::reference;

private:
    Iterator current_;
    Iterator end_;
    Predicate pred_;

    void satisfy_predicate() {
        while (current_ != end_ && !pred_(*current_)) {
            ++current_;
        }
    }

public:
    filter_iterator() = default;

    filter_iterator(Iterator it, Iterator end, Predicate pred)
        : current_(it), end_(end), pred_(pred) {
        satisfy_predicate();  // 找到第一个满足条件的元素
    }

    reference operator*() const { return *current_; }
    pointer operator->() const { return &*current_; }

    filter_iterator& operator++() {
        ++current_;
        satisfy_predicate();
        return *this;
    }

    filter_iterator operator++(int) {
        filter_iterator tmp = *this;
        ++(*this);
        return tmp;
    }

    bool operator==(const filter_iterator& other) const {
        return current_ == other.current_;
    }

    bool operator!=(const filter_iterator& other) const {
        return !(*this == other);
    }

    Iterator base() const { return current_; }
};

// 辅助函数
template <typename Iterator, typename Predicate>
auto make_filter_iterator(Iterator it, Iterator end, Predicate pred) {
    return filter_iterator<Iterator, Predicate>(it, end, pred);
}

}  // namespace my

// 使用示例
void demo_filter_iterator() {
    std::vector<int> v = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};

    auto is_even = [](int x) { return x % 2 == 0; };

    auto begin = my::make_filter_iterator(v.begin(), v.end(), is_even);
    auto end = my::make_filter_iterator(v.end(), v.end(), is_even);

    for (auto it = begin; it != end; ++it) {
        std::cout << *it << " ";  // 2 4 6 8 10
    }
}
```

**实现transform_iterator**：

```cpp
namespace my {

template <typename Iterator, typename UnaryFunc>
class transform_iterator {
public:
    using iterator_category = typename std::iterator_traits<Iterator>::iterator_category;
    using value_type = std::invoke_result_t<UnaryFunc&,
        typename std::iterator_traits<Iterator>::reference>;
    using difference_type = typename std::iterator_traits<Iterator>::difference_type;
    using pointer = void;  // 不能返回指针（值是临时的）
    using reference = value_type;  // 返回值（不是引用）

private:
    Iterator current_;
    UnaryFunc func_;

public:
    transform_iterator() = default;

    transform_iterator(Iterator it, UnaryFunc func)
        : current_(it), func_(func) {}

    value_type operator*() const {
        return func_(*current_);
    }

    transform_iterator& operator++() {
        ++current_;
        return *this;
    }

    transform_iterator operator++(int) {
        transform_iterator tmp = *this;
        ++current_;
        return tmp;
    }

    // 如果底层迭代器是Bidirectional
    transform_iterator& operator--() {
        --current_;
        return *this;
    }

    // 如果底层迭代器是RandomAccess
    transform_iterator operator+(difference_type n) const {
        return transform_iterator(current_ + n, func_);
    }

    transform_iterator operator-(difference_type n) const {
        return transform_iterator(current_ - n, func_);
    }

    difference_type operator-(const transform_iterator& other) const {
        return current_ - other.current_;
    }

    bool operator==(const transform_iterator& other) const {
        return current_ == other.current_;
    }

    bool operator!=(const transform_iterator& other) const {
        return !(*this == other);
    }

    Iterator base() const { return current_; }
};

template <typename Iterator, typename UnaryFunc>
auto make_transform_iterator(Iterator it, UnaryFunc func) {
    return transform_iterator<Iterator, UnaryFunc>(it, func);
}

}  // namespace my

// 使用示例
void demo_transform_iterator() {
    std::vector<int> v = {1, 2, 3, 4, 5};

    auto square = [](int x) { return x * x; };

    auto begin = my::make_transform_iterator(v.begin(), square);
    auto end = my::make_transform_iterator(v.end(), square);

    for (auto it = begin; it != end; ++it) {
        std::cout << *it << " ";  // 1 4 9 16 25
    }
}
```

**实现stride_iterator（步进迭代器）**：

```cpp
namespace my {

template <typename Iterator>
class stride_iterator {
public:
    using iterator_category = std::random_access_iterator_tag;
    using value_type = typename std::iterator_traits<Iterator>::value_type;
    using difference_type = typename std::iterator_traits<Iterator>::difference_type;
    using pointer = typename std::iterator_traits<Iterator>::pointer;
    using reference = typename std::iterator_traits<Iterator>::reference;

private:
    Iterator current_;
    difference_type stride_;

public:
    stride_iterator() : current_(), stride_(1) {}

    stride_iterator(Iterator it, difference_type stride)
        : current_(it), stride_(stride) {}

    reference operator*() const { return *current_; }
    pointer operator->() const { return &*current_; }

    stride_iterator& operator++() {
        std::advance(current_, stride_);
        return *this;
    }

    stride_iterator operator++(int) {
        stride_iterator tmp = *this;
        ++(*this);
        return tmp;
    }

    stride_iterator& operator--() {
        std::advance(current_, -stride_);
        return *this;
    }

    stride_iterator operator+(difference_type n) const {
        return stride_iterator(current_ + n * stride_, stride_);
    }

    stride_iterator operator-(difference_type n) const {
        return stride_iterator(current_ - n * stride_, stride_);
    }

    difference_type operator-(const stride_iterator& other) const {
        return (current_ - other.current_) / stride_;
    }

    reference operator[](difference_type n) const {
        return current_[n * stride_];
    }

    bool operator==(const stride_iterator& other) const {
        return current_ == other.current_;
    }

    bool operator!=(const stride_iterator& other) const {
        return !(*this == other);
    }

    bool operator<(const stride_iterator& other) const {
        return current_ < other.current_;
    }
};

}  // namespace my

// 使用示例：遍历每隔一个元素
void demo_stride_iterator() {
    std::vector<int> v = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9};

    my::stride_iterator begin(v.begin(), 2);
    my::stride_iterator end(v.begin() + 10, 2);  // 注意end的计算

    for (auto it = begin; it != end; ++it) {
        std::cout << *it << " ";  // 0 2 4 6 8
    }
}
```

**练习题**：
1. 实现一个`enumerate_iterator`，同时返回索引和值
2. 实现一个`zip_iterator`，同时遍历两个容器
3. 为什么filter_iterator最多只能是ForwardIterator？

---

#### Day 6: 适配器组合使用（4小时）

**学习目标**：学会组合多个迭代器适配器解决复杂问题

**组合示例：过滤后转换**：

```cpp
void demo_combined_iterators() {
    std::vector<int> v = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};

    // 目标：获取偶数的平方
    auto is_even = [](int x) { return x % 2 == 0; };
    auto square = [](int x) { return x * x; };

    // 方式1：使用自定义适配器组合
    auto f_begin = my::make_filter_iterator(v.begin(), v.end(), is_even);
    auto f_end = my::make_filter_iterator(v.end(), v.end(), is_even);

    auto t_begin = my::make_transform_iterator(f_begin, square);
    auto t_end = my::make_transform_iterator(f_end, square);

    std::vector<int> result(t_begin, t_end);
    // result = {4, 16, 36, 64, 100}

    // 方式2：使用STL算法链
    std::vector<int> result2;
    std::copy_if(v.begin(), v.end(), std::back_inserter(result2), is_even);

    std::vector<int> result3;
    std::transform(result2.begin(), result2.end(),
                   std::back_inserter(result3), square);

    // 方式3（C++20）：使用Ranges
    // auto result4 = v | std::views::filter(is_even)
    //                  | std::views::transform(square);
}
```

**实用案例：日志处理**：

```cpp
#include <fstream>
#include <regex>

struct LogEntry {
    std::string timestamp;
    std::string level;
    std::string message;
};

// 解析日志行
LogEntry parse_log_line(const std::string& line) {
    // 假设格式: [2024-01-01 12:00:00] [INFO] Message
    std::regex pattern(R"(\[(.*?)\] \[(.*?)\] (.*))");
    std::smatch match;
    if (std::regex_match(line, match, pattern)) {
        return {match[1], match[2], match[3]};
    }
    return {"", "", line};
}

void analyze_logs() {
    std::ifstream file("app.log");
    std::vector<std::string> lines;

    // 读取所有行
    std::copy(std::istream_iterator<std::string>(file),
              std::istream_iterator<std::string>(),
              std::back_inserter(lines));

    // 解析日志
    std::vector<LogEntry> entries;
    std::transform(lines.begin(), lines.end(),
                   std::back_inserter(entries), parse_log_line);

    // 过滤ERROR级别
    std::vector<LogEntry> errors;
    std::copy_if(entries.begin(), entries.end(),
                 std::back_inserter(errors),
                 [](const LogEntry& e) { return e.level == "ERROR"; });

    // 输出错误消息
    std::transform(errors.begin(), errors.end(),
                   std::ostream_iterator<std::string>(std::cout, "\n"),
                   [](const LogEntry& e) { return e.timestamp + ": " + e.message; });
}
```

**练习题**：
1. 使用迭代器适配器实现一个数据管道：读取文件 -> 过滤空行 -> 转换大写 -> 输出
2. 实现一个`take_while_iterator`，在条件不满足时停止
3. 组合reverse_iterator和filter_iterator，从后向前查找满足条件的元素

---

#### Day 7: 综合项目（5小时）

**本周知识点总结**：

1. **reverse_iterator**：通过存储"下一个"位置实现反向遍历
2. **insert_iterator系列**：将赋值转换为插入操作
3. **move_iterator**：将解引用转换为移动操作
4. **stream_iterator**：将I/O统一到迭代器接口
5. **自定义适配器**：filter、transform、stride等

**综合项目：实现一个数据处理库**：

```cpp
// data_pipeline.hpp
#pragma once
#include <iterator>
#include <functional>

namespace pipeline {

// 管道操作符支持
template <typename Range, typename Op>
auto operator|(Range&& range, Op op) {
    return op(std::forward<Range>(range));
}

// filter操作
template <typename Pred>
auto filter(Pred pred) {
    return [pred](auto& range) {
        using Iter = decltype(std::begin(range));
        return std::pair{
            my::make_filter_iterator(std::begin(range), std::end(range), pred),
            my::make_filter_iterator(std::end(range), std::end(range), pred)
        };
    };
}

// transform操作
template <typename Func>
auto transform(Func func) {
    return [func](auto& range) {
        auto [begin, end] = range;  // 假设range是一对迭代器
        return std::pair{
            my::make_transform_iterator(begin, func),
            my::make_transform_iterator(end, func)
        };
    };
}

// to_vector操作
inline auto to_vector() {
    return [](auto& range) {
        auto [begin, end] = range;
        using T = std::decay_t<decltype(*begin)>;
        return std::vector<T>(begin, end);
    };
}

// for_each操作
template <typename Func>
auto for_each(Func func) {
    return [func](auto& range) {
        auto [begin, end] = range;
        for (auto it = begin; it != end; ++it) {
            func(*it);
        }
    };
}

}  // namespace pipeline

// 使用示例
void demo_pipeline() {
    std::vector<int> v = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};

    // 使用管道语法
    auto result = std::pair{v.begin(), v.end()}
        | pipeline::filter([](int x) { return x % 2 == 0; })
        | pipeline::transform([](int x) { return x * x; })
        | pipeline::to_vector();

    // result = {4, 16, 36, 64, 100}

    // 或者直接输出
    std::pair{v.begin(), v.end()}
        | pipeline::filter([](int x) { return x > 5; })
        | pipeline::for_each([](int x) { std::cout << x << " "; });
    // 输出: 6 7 8 9 10
}
```

**本周检验标准**：
- [ ] 能解释reverse_iterator的*操作为什么要减1
- [ ] 能正确使用三种insert_iterator
- [ ] 理解move_iterator如何实现批量移动
- [ ] 能使用stream_iterator进行I/O操作
- [ ] 能实现自定义迭代器适配器
- [ ] 能组合多个适配器解决实际问题

---

### 第四周：C++20 Ranges

**学习目标**：理解Ranges库的设计

#### Ranges基础
```cpp
#include <ranges>

std::vector<int> v = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};

// 传统方式
std::vector<int> result;
for (int x : v) {
    if (x % 2 == 0) {
        result.push_back(x * x);
    }
}

// Ranges方式
auto result = v
    | std::views::filter([](int x) { return x % 2 == 0; })
    | std::views::transform([](int x) { return x * x; });

// result是一个惰性视图，遍历时才计算
for (int x : result) {
    std::cout << x << " ";  // 4 16 36 64 100
}

// 转换为vector
auto vec = result | std::ranges::to<std::vector>();
```

#### Views是惰性的
```cpp
// Views不存储数据，只是对原数据的视图
// 每次遍历都会重新计算

auto view = v | std::views::filter([](int x) {
    std::cout << "filtering " << x << "\n";
    return x % 2 == 0;
});

// 此时没有任何输出

for (int x : view) {  // 遍历时才执行filter
    std::cout << "got " << x << "\n";
}
```

---

## 源码阅读任务

### 深度阅读清单

- [ ] `std::iterator_traits`实现
- [ ] `std::advance`和`std::distance`实现
- [ ] `std::reverse_iterator`实现
- [ ] `std::back_insert_iterator`实现
- [ ] `std::sort`完整实现（IntroSort）

---

## 实践项目

### 项目：实现自定义迭代器和算法

#### Part 1: 链表迭代器
```cpp
// list_iterator.hpp
#pragma once
#include <iterator>

template <typename T>
struct ListNode {
    T data;
    ListNode* next = nullptr;
    ListNode* prev = nullptr;

    ListNode(const T& d) : data(d) {}
};

template <typename T>
class ListIterator {
public:
    using iterator_category = std::bidirectional_iterator_tag;
    using value_type = T;
    using difference_type = std::ptrdiff_t;
    using pointer = T*;
    using reference = T&;

private:
    ListNode<T>* node_;

public:
    ListIterator() : node_(nullptr) {}
    explicit ListIterator(ListNode<T>* n) : node_(n) {}

    reference operator*() const { return node_->data; }
    pointer operator->() const { return &node_->data; }

    ListIterator& operator++() {
        node_ = node_->next;
        return *this;
    }

    ListIterator operator++(int) {
        ListIterator tmp = *this;
        ++(*this);
        return tmp;
    }

    ListIterator& operator--() {
        node_ = node_->prev;
        return *this;
    }

    ListIterator operator--(int) {
        ListIterator tmp = *this;
        --(*this);
        return tmp;
    }

    bool operator==(const ListIterator& other) const {
        return node_ == other.node_;
    }

    bool operator!=(const ListIterator& other) const {
        return node_ != other.node_;
    }

    ListNode<T>* node() const { return node_; }
};

// const版本
template <typename T>
class ListConstIterator {
public:
    using iterator_category = std::bidirectional_iterator_tag;
    using value_type = T;
    using difference_type = std::ptrdiff_t;
    using pointer = const T*;
    using reference = const T&;

private:
    const ListNode<T>* node_;

public:
    ListConstIterator() : node_(nullptr) {}
    explicit ListConstIterator(const ListNode<T>* n) : node_(n) {}
    ListConstIterator(const ListIterator<T>& it) : node_(it.node()) {}

    reference operator*() const { return node_->data; }
    pointer operator->() const { return &node_->data; }

    ListConstIterator& operator++() {
        node_ = node_->next;
        return *this;
    }

    ListConstIterator& operator--() {
        node_ = node_->prev;
        return *this;
    }

    bool operator==(const ListConstIterator& other) const {
        return node_ == other.node_;
    }

    bool operator!=(const ListConstIterator& other) const {
        return node_ != other.node_;
    }
};
```

#### Part 2: 实现mini_algorithms
```cpp
// mini_algorithms.hpp
#pragma once
#include <iterator>
#include <utility>
#include <functional>

namespace mini {

// ==================== 非修改序列操作 ====================

template <typename InputIt, typename T>
InputIt find(InputIt first, InputIt last, const T& value) {
    for (; first != last; ++first) {
        if (*first == value) return first;
    }
    return last;
}

template <typename InputIt, typename Pred>
InputIt find_if(InputIt first, InputIt last, Pred pred) {
    for (; first != last; ++first) {
        if (pred(*first)) return first;
    }
    return last;
}

template <typename InputIt, typename Pred>
bool all_of(InputIt first, InputIt last, Pred pred) {
    for (; first != last; ++first) {
        if (!pred(*first)) return false;
    }
    return true;
}

template <typename InputIt, typename Pred>
bool any_of(InputIt first, InputIt last, Pred pred) {
    for (; first != last; ++first) {
        if (pred(*first)) return true;
    }
    return false;
}

template <typename InputIt, typename Pred>
bool none_of(InputIt first, InputIt last, Pred pred) {
    return !any_of(first, last, pred);
}

template <typename InputIt, typename T>
typename std::iterator_traits<InputIt>::difference_type
count(InputIt first, InputIt last, const T& value) {
    typename std::iterator_traits<InputIt>::difference_type n = 0;
    for (; first != last; ++first) {
        if (*first == value) ++n;
    }
    return n;
}

// ==================== 修改序列操作 ====================

template <typename InputIt, typename OutputIt>
OutputIt copy(InputIt first, InputIt last, OutputIt result) {
    for (; first != last; ++first, ++result) {
        *result = *first;
    }
    return result;
}

template <typename InputIt, typename OutputIt, typename Pred>
OutputIt copy_if(InputIt first, InputIt last, OutputIt result, Pred pred) {
    for (; first != last; ++first) {
        if (pred(*first)) {
            *result = *first;
            ++result;
        }
    }
    return result;
}

template <typename InputIt, typename OutputIt>
OutputIt move(InputIt first, InputIt last, OutputIt result) {
    for (; first != last; ++first, ++result) {
        *result = std::move(*first);
    }
    return result;
}

template <typename InputIt, typename OutputIt, typename UnaryOp>
OutputIt transform(InputIt first, InputIt last, OutputIt result, UnaryOp op) {
    for (; first != last; ++first, ++result) {
        *result = op(*first);
    }
    return result;
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

template <typename ForwardIt, typename T>
ForwardIt remove(ForwardIt first, ForwardIt last, const T& value) {
    first = mini::find(first, last, value);
    if (first == last) return first;

    ForwardIt result = first;
    ++first;
    for (; first != last; ++first) {
        if (*first != value) {
            *result = std::move(*first);
            ++result;
        }
    }
    return result;
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
        if (!(*result == *first)) {
            ++result;
            if (result != first) {
                *result = std::move(*first);
            }
        }
    }
    return ++result;
}

// ==================== 排序操作 ====================

template <typename RandomIt>
void insertion_sort(RandomIt first, RandomIt last) {
    if (first == last) return;

    for (auto it = first + 1; it != last; ++it) {
        auto key = std::move(*it);
        auto j = it;
        while (j != first && *(j - 1) > key) {
            *j = std::move(*(j - 1));
            --j;
        }
        *j = std::move(key);
    }
}

// 简化版quicksort
template <typename RandomIt, typename Compare = std::less<>>
void sort(RandomIt first, RandomIt last, Compare comp = Compare{}) {
    auto size = last - first;
    if (size <= 1) return;

    if (size <= 16) {
        insertion_sort(first, last);
        return;
    }

    // 三数取中选pivot
    auto mid = first + size / 2;
    if (comp(*mid, *first)) std::iter_swap(first, mid);
    if (comp(*(last - 1), *first)) std::iter_swap(first, last - 1);
    if (comp(*(last - 1), *mid)) std::iter_swap(mid, last - 1);

    auto pivot = *mid;

    auto left = first;
    auto right = last - 1;
    while (true) {
        while (comp(*left, pivot)) ++left;
        while (comp(pivot, *right)) --right;
        if (left >= right) break;
        std::iter_swap(left++, right--);
    }

    sort(first, left, comp);
    sort(right + 1, last, comp);
}

// ==================== 二分搜索 ====================

template <typename ForwardIt, typename T>
ForwardIt lower_bound(ForwardIt first, ForwardIt last, const T& value) {
    auto count = std::distance(first, last);

    while (count > 0) {
        auto step = count / 2;
        auto mid = first;
        std::advance(mid, step);

        if (*mid < value) {
            first = ++mid;
            count -= step + 1;
        } else {
            count = step;
        }
    }
    return first;
}

template <typename ForwardIt, typename T>
ForwardIt upper_bound(ForwardIt first, ForwardIt last, const T& value) {
    auto count = std::distance(first, last);

    while (count > 0) {
        auto step = count / 2;
        auto mid = first;
        std::advance(mid, step);

        if (!(value < *mid)) {
            first = ++mid;
            count -= step + 1;
        } else {
            count = step;
        }
    }
    return first;
}

template <typename ForwardIt, typename T>
bool binary_search(ForwardIt first, ForwardIt last, const T& value) {
    auto it = lower_bound(first, last, value);
    return it != last && !(value < *it);
}

// ==================== 堆操作 ====================

template <typename RandomIt>
void push_heap(RandomIt first, RandomIt last) {
    auto hole = last - first - 1;
    auto value = std::move(*(first + hole));

    while (hole > 0) {
        auto parent = (hole - 1) / 2;
        if (*(first + parent) < value) {
            *(first + hole) = std::move(*(first + parent));
            hole = parent;
        } else {
            break;
        }
    }
    *(first + hole) = std::move(value);
}

template <typename RandomIt>
void pop_heap(RandomIt first, RandomIt last) {
    auto value = std::move(*(last - 1));
    *(last - 1) = std::move(*first);

    auto len = last - first - 1;
    auto hole = 0;
    auto child = 2 * hole + 1;

    while (child < len) {
        if (child + 1 < len && *(first + child) < *(first + child + 1)) {
            ++child;
        }
        if (value < *(first + child)) {
            *(first + hole) = std::move(*(first + child));
            hole = child;
            child = 2 * hole + 1;
        } else {
            break;
        }
    }
    *(first + hole) = std::move(value);
}

template <typename RandomIt>
void make_heap(RandomIt first, RandomIt last) {
    auto len = last - first;
    if (len <= 1) return;

    for (auto i = len / 2; i > 0; --i) {
        // 从后向前调整每个非叶节点
        auto hole = i - 1;
        auto value = std::move(*(first + hole));
        auto child = 2 * hole + 1;

        while (child < len) {
            if (child + 1 < len && *(first + child) < *(first + child + 1)) {
                ++child;
            }
            if (value < *(first + child)) {
                *(first + hole) = std::move(*(first + child));
                hole = child;
                child = 2 * hole + 1;
            } else {
                break;
            }
        }
        *(first + hole) = std::move(value);
    }
}

template <typename RandomIt>
void sort_heap(RandomIt first, RandomIt last) {
    while (last - first > 1) {
        pop_heap(first, last--);
    }
}

// ==================== 数值操作 ====================

template <typename InputIt, typename T>
T accumulate(InputIt first, InputIt last, T init) {
    for (; first != last; ++first) {
        init = std::move(init) + *first;
    }
    return init;
}

template <typename InputIt, typename T, typename BinaryOp>
T accumulate(InputIt first, InputIt last, T init, BinaryOp op) {
    for (; first != last; ++first) {
        init = op(std::move(init), *first);
    }
    return init;
}

} // namespace mini
```

#### Part 3: 简单的Range View
```cpp
// mini_ranges.hpp
#pragma once
#include <iterator>

namespace mini::ranges {

// filter_view
template <typename Range, typename Pred>
class filter_view {
    Range& range_;
    Pred pred_;

public:
    class iterator {
        using base_iter = decltype(std::begin(std::declval<Range&>()));
        base_iter current_;
        base_iter end_;
        Pred* pred_;

        void find_next() {
            while (current_ != end_ && !(*pred_)(*current_)) {
                ++current_;
            }
        }

    public:
        using value_type = typename std::iterator_traits<base_iter>::value_type;
        using reference = typename std::iterator_traits<base_iter>::reference;
        using iterator_category = std::forward_iterator_tag;
        using difference_type = std::ptrdiff_t;

        iterator(base_iter cur, base_iter end, Pred* p)
            : current_(cur), end_(end), pred_(p) {
            find_next();
        }

        reference operator*() const { return *current_; }

        iterator& operator++() {
            ++current_;
            find_next();
            return *this;
        }

        bool operator==(const iterator& other) const {
            return current_ == other.current_;
        }
        bool operator!=(const iterator& other) const {
            return !(*this == other);
        }
    };

    filter_view(Range& r, Pred p) : range_(r), pred_(std::move(p)) {}

    iterator begin() {
        return iterator(std::begin(range_), std::end(range_), &pred_);
    }

    iterator end() {
        return iterator(std::end(range_), std::end(range_), &pred_);
    }
};

// transform_view
template <typename Range, typename Func>
class transform_view {
    Range& range_;
    Func func_;

public:
    class iterator {
        using base_iter = decltype(std::begin(std::declval<Range&>()));
        base_iter current_;
        Func* func_;

    public:
        using value_type = std::invoke_result_t<Func&,
            typename std::iterator_traits<base_iter>::reference>;
        using reference = value_type;
        using iterator_category = std::forward_iterator_tag;
        using difference_type = std::ptrdiff_t;

        iterator(base_iter cur, Func* f) : current_(cur), func_(f) {}

        value_type operator*() const { return (*func_)(*current_); }

        iterator& operator++() { ++current_; return *this; }

        bool operator==(const iterator& other) const {
            return current_ == other.current_;
        }
        bool operator!=(const iterator& other) const {
            return !(*this == other);
        }
    };

    transform_view(Range& r, Func f) : range_(r), func_(std::move(f)) {}

    iterator begin() { return iterator(std::begin(range_), &func_); }
    iterator end() { return iterator(std::end(range_), &func_); }
};

// 管道操作符支持
template <typename Pred>
struct filter_fn {
    Pred pred;
    template <typename Range>
    auto operator()(Range& r) const {
        return filter_view<Range, Pred>(r, pred);
    }
};

template <typename Func>
struct transform_fn {
    Func func;
    template <typename Range>
    auto operator()(Range& r) const {
        return transform_view<Range, Func>(r, func);
    }
};

template <typename Pred>
auto filter(Pred p) { return filter_fn<Pred>{std::move(p)}; }

template <typename Func>
auto transform(Func f) { return transform_fn<Func>{std::move(f)}; }

// 管道操作符
template <typename Range, typename Fn>
auto operator|(Range& r, Fn fn) {
    return fn(r);
}

} // namespace mini::ranges
```

---

### 第四周详细学习计划

#### Day 1: Ranges概念与基础（4小时）

**学习目标**：理解C++20 Ranges库的设计哲学

**为什么需要Ranges？**

```cpp
// 传统STL的问题
std::vector<int> v = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};

// 问题1：算法需要传递两个迭代器
std::sort(v.begin(), v.end());  // 冗余！

// 问题2：多步操作需要中间容器
std::vector<int> evens;
std::copy_if(v.begin(), v.end(), std::back_inserter(evens),
             [](int x) { return x % 2 == 0; });

std::vector<int> squares;
std::transform(evens.begin(), evens.end(), std::back_inserter(squares),
               [](int x) { return x * x; });

// 问题3：代码阅读顺序与数据流相反
// 先看到transform，再看到copy_if
```

**Ranges的解决方案**：

```cpp
#include <ranges>

std::vector<int> v = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};

// 解决方案1：直接传递范围
std::ranges::sort(v);  // 简洁！

// 解决方案2：惰性视图链式操作，无需中间容器
auto squares = v
    | std::views::filter([](int x) { return x % 2 == 0; })
    | std::views::transform([](int x) { return x * x; });

// 解决方案3：代码顺序与数据流一致
// 先filter，再transform

// squares是一个惰性视图，遍历时才计算
for (int x : squares) {
    std::cout << x << " ";  // 4 16 36 64 100
}
```

**Range概念定义**：

```cpp
// Range是什么？
// 任何可以用begin()和end()获取迭代器的东西

// 标准库的range概念定义（简化）
template <typename R>
concept range = requires(R& r) {
    std::ranges::begin(r);
    std::ranges::end(r);
};

// 常见的Range类型：
// - 容器：vector, list, map...
// - 数组：int arr[10]
// - 字符串：string, string_view
// - Views：filter_view, transform_view...

// 检查是否满足range概念
static_assert(std::ranges::range<std::vector<int>>);
static_assert(std::ranges::range<int[10]>);
static_assert(std::ranges::range<std::string>);
```

**Ranges算法**：

```cpp
#include <algorithm>
#include <ranges>

void demo_ranges_algorithms() {
    std::vector<int> v = {3, 1, 4, 1, 5, 9, 2, 6};

    // 传统STL算法
    std::sort(v.begin(), v.end());

    // Ranges版本——直接传递范围
    std::ranges::sort(v);

    // 带投影（projection）
    std::vector<std::pair<int, std::string>> pairs = {
        {3, "three"}, {1, "one"}, {4, "four"}
    };

    // 按first排序（传统方式需要自定义比较器）
    std::ranges::sort(pairs, {}, &std::pair<int, std::string>::first);

    // Ranges算法返回更多信息
    std::vector<int> v2 = {1, 2, 3, 4, 5};
    auto [in, out] = std::ranges::copy(v2, v.begin());
    // in: 源范围的end
    // out: 目标范围的新end

    // 可以使用结构化绑定获取结果
    auto result = std::ranges::find(v, 3);
    if (result != v.end()) {
        std::cout << "Found: " << *result << std::endl;
    }
}
```

**练习题**：
1. 比较`std::sort`和`std::ranges::sort`的使用方式
2. 什么是projection？它如何简化代码？
3. 使用ranges算法重写一段传统STL代码

---

#### Day 2: Views惰性求值原理（5小时）

**学习目标**：深入理解Views的惰性计算机制

**Views是什么？**

```cpp
// View是一种特殊的Range，它：
// 1. 不拥有元素（只是原数据的视图）
// 2. 惰性求值（遍历时才计算）
// 3. O(1)复制和移动

#include <ranges>

std::vector<int> v = {1, 2, 3, 4, 5};

// filter_view不存储过滤结果，只存储：
// - 对原范围的引用
// - 谓词
auto even = v | std::views::filter([](int x) { return x % 2 == 0; });

// 此时没有任何过滤操作发生！

// 遍历时才执行过滤
for (int x : even) {
    std::cout << x << " ";  // 这里才调用谓词
}
```

**惰性求值的可视化**：

```cpp
void demonstrate_laziness() {
    std::vector<int> v = {1, 2, 3, 4, 5};

    auto pipeline = v
        | std::views::filter([](int x) {
            std::cout << "filter: " << x << "\n";
            return x % 2 == 0;
        })
        | std::views::transform([](int x) {
            std::cout << "transform: " << x << "\n";
            return x * x;
        });

    std::cout << "Pipeline created, no output yet.\n";

    // 只有在遍历时才执行
    std::cout << "Starting iteration:\n";
    for (int x : pipeline) {
        std::cout << "Result: " << x << "\n";
    }

    // 输出：
    // Pipeline created, no output yet.
    // Starting iteration:
    // filter: 1
    // filter: 2
    // transform: 2
    // Result: 4
    // filter: 3
    // filter: 4
    // transform: 4
    // Result: 16
    // filter: 5
}
```

**Views vs 传统算法的内存对比**：

```cpp
#include <chrono>

void benchmark_views_vs_traditional() {
    std::vector<int> v(1000000);
    std::iota(v.begin(), v.end(), 0);

    // 传统方式：需要中间容器
    auto start1 = std::chrono::high_resolution_clock::now();
    std::vector<int> filtered;
    std::copy_if(v.begin(), v.end(), std::back_inserter(filtered),
                 [](int x) { return x % 2 == 0; });
    std::vector<int> transformed;
    std::transform(filtered.begin(), filtered.end(),
                   std::back_inserter(transformed),
                   [](int x) { return x * x; });
    long long sum1 = std::accumulate(transformed.begin(), transformed.end(), 0LL);
    auto end1 = std::chrono::high_resolution_clock::now();

    // Views方式：无中间容器
    auto start2 = std::chrono::high_resolution_clock::now();
    auto view = v
        | std::views::filter([](int x) { return x % 2 == 0; })
        | std::views::transform([](int x) { return x * x; });
    long long sum2 = 0;
    for (int x : view) {
        sum2 += x;
    }
    auto end2 = std::chrono::high_resolution_clock::now();

    std::cout << "Traditional: "
              << std::chrono::duration_cast<std::chrono::milliseconds>(end1 - start1).count()
              << " ms\n";
    std::cout << "Views: "
              << std::chrono::duration_cast<std::chrono::milliseconds>(end2 - start2).count()
              << " ms\n";

    // Views方式通常更快，因为：
    // 1. 没有中间容器的内存分配
    // 2. 更好的cache局部性（一次遍历）
}
```

**View的类别约束**：

```cpp
// View的迭代器类别取决于底层范围和操作

std::vector<int> v = {1, 2, 3, 4, 5};

// filter_view降级为bidirectional（因为需要跳过元素）
auto filtered = v | std::views::filter([](int x) { return x % 2 == 0; });
// filtered的迭代器是bidirectional，不是random_access

// transform_view保持类别
auto transformed = v | std::views::transform([](int x) { return x * x; });
// transformed的迭代器仍然是random_access

// take_view可能降级
auto taken = v | std::views::take(3);
// 如果底层是random_access，taken保持random_access
```

**练习题**：
1. 解释为什么filter_view的迭代器不能是RandomAccess
2. 如果对同一个view遍历两次，会发生什么？
3. Views对原容器的修改是否可见？

---

#### Day 3: 常用Views深入（5小时）

**学习目标**：掌握标准库提供的各种View适配器

**基础Views**：

```cpp
#include <ranges>

std::vector<int> v = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};

// filter: 过滤元素
auto evens = v | std::views::filter([](int x) { return x % 2 == 0; });
// 2 4 6 8 10

// transform: 转换元素
auto squares = v | std::views::transform([](int x) { return x * x; });
// 1 4 9 16 25 36 49 64 81 100

// take: 取前n个
auto first3 = v | std::views::take(3);
// 1 2 3

// drop: 跳过前n个
auto after3 = v | std::views::drop(3);
// 4 5 6 7 8 9 10

// take_while: 取满足条件的前缀
auto small = v | std::views::take_while([](int x) { return x < 5; });
// 1 2 3 4

// drop_while: 跳过满足条件的前缀
auto large = v | std::views::drop_while([](int x) { return x < 5; });
// 5 6 7 8 9 10
```

**reverse和常量Views**：

```cpp
// reverse: 反向遍历
auto reversed = v | std::views::reverse;
// 10 9 8 7 6 5 4 3 2 1

// all: 将范围转为view
auto all = std::views::all(v);

// common: 确保begin和end类型相同（某些view的end是sentinel）
auto common = v | std::views::filter([](int x) { return x > 0; })
                | std::views::common;

// 用于需要相同类型迭代器的传统算法
std::vector<int> result(common.begin(), common.end());
```

**生成Views**：

```cpp
// iota: 生成序列
auto numbers = std::views::iota(1, 11);  // 1, 2, ..., 10
auto infinite = std::views::iota(1);      // 1, 2, 3, ... (无限)

// 无限序列必须与take等配合使用
auto first10 = std::views::iota(1) | std::views::take(10);

// repeat (C++23): 重复元素
// auto fives = std::views::repeat(5) | std::views::take(10);

// empty: 空范围
auto empty = std::views::empty<int>;

// single: 单元素范围
auto one = std::views::single(42);
```

**分割和连接Views**：

```cpp
// split: 按分隔符分割
std::string s = "hello,world,cpp";
auto parts = s | std::views::split(',');

for (auto part : parts) {
    std::cout << std::string_view(part.begin(), part.end()) << "\n";
}
// hello
// world
// cpp

// lazy_split: 更惰性的分割（C++23改进）

// join: 连接嵌套范围
std::vector<std::vector<int>> nested = {{1, 2}, {3, 4}, {5, 6}};
auto flat = nested | std::views::join;
// 1 2 3 4 5 6

// join_with (C++23): 带分隔符连接
```

**keys和values（用于关联容器）**：

```cpp
std::map<std::string, int> scores = {
    {"Alice", 90}, {"Bob", 85}, {"Charlie", 95}
};

// keys: 获取所有键
for (auto& name : scores | std::views::keys) {
    std::cout << name << " ";
}
// Alice Bob Charlie

// values: 获取所有值
for (int score : scores | std::views::values) {
    std::cout << score << " ";
}
// 90 85 95

// elements<N>: 获取tuple的第N个元素
std::vector<std::tuple<int, std::string, double>> data = {
    {1, "a", 1.1}, {2, "b", 2.2}
};
auto strings = data | std::views::elements<1>;
// "a" "b"
```

**练习题**：
1. 使用views实现：取数组中所有正数的平方，但最多取5个
2. 实现字符串单词计数（用split）
3. 解释keys和values在map上如何工作

---

#### Day 4: 自定义View实现（5小时）

**学习目标**：学会实现符合标准的自定义View

**实现简单的enumerate_view**：

```cpp
// enumerate_view: 返回(index, value)对

#include <ranges>
#include <tuple>

namespace my_views {

template <std::ranges::input_range R>
class enumerate_view : public std::ranges::view_interface<enumerate_view<R>> {
    R base_;

    class iterator {
        using base_iter = std::ranges::iterator_t<R>;
        base_iter current_;
        std::size_t index_ = 0;

    public:
        using value_type = std::tuple<std::size_t, std::ranges::range_reference_t<R>>;
        using difference_type = std::ranges::range_difference_t<R>;

        iterator() = default;
        iterator(base_iter it, std::size_t idx) : current_(it), index_(idx) {}

        value_type operator*() const {
            return {index_, *current_};
        }

        iterator& operator++() {
            ++current_;
            ++index_;
            return *this;
        }

        iterator operator++(int) {
            auto tmp = *this;
            ++*this;
            return tmp;
        }

        bool operator==(const iterator& other) const {
            return current_ == other.current_;
        }

        bool operator==(std::ranges::sentinel_t<R> s) const {
            return current_ == s;
        }
    };

public:
    enumerate_view() = default;
    enumerate_view(R base) : base_(std::move(base)) {}

    auto begin() { return iterator(std::ranges::begin(base_), 0); }
    auto end() { return std::ranges::end(base_); }
};

// 范围适配器对象
struct enumerate_fn {
    template <std::ranges::viewable_range R>
    auto operator()(R&& r) const {
        return enumerate_view<std::views::all_t<R>>(std::views::all(std::forward<R>(r)));
    }
};

// 管道操作符支持
template <std::ranges::viewable_range R>
auto operator|(R&& r, enumerate_fn) {
    return enumerate_fn{}(std::forward<R>(r));
}

inline constexpr enumerate_fn enumerate{};

}  // namespace my_views

// 使用示例
void demo_enumerate() {
    std::vector<std::string> names = {"Alice", "Bob", "Charlie"};

    for (auto [index, name] : names | my_views::enumerate) {
        std::cout << index << ": " << name << "\n";
    }
    // 0: Alice
    // 1: Bob
    // 2: Charlie
}
```

**实现stride_view（步进视图）**：

```cpp
namespace my_views {

template <std::ranges::input_range R>
class stride_view : public std::ranges::view_interface<stride_view<R>> {
    R base_;
    std::ranges::range_difference_t<R> stride_;

    class iterator {
        using base_iter = std::ranges::iterator_t<R>;
        base_iter current_;
        base_iter end_;
        std::ranges::range_difference_t<R> stride_;

    public:
        using value_type = std::ranges::range_value_t<R>;
        using difference_type = std::ranges::range_difference_t<R>;
        using reference = std::ranges::range_reference_t<R>;

        iterator() = default;
        iterator(base_iter cur, base_iter end, difference_type stride)
            : current_(cur), end_(end), stride_(stride) {}

        reference operator*() const { return *current_; }

        iterator& operator++() {
            for (difference_type i = 0; i < stride_ && current_ != end_; ++i) {
                ++current_;
            }
            return *this;
        }

        iterator operator++(int) {
            auto tmp = *this;
            ++*this;
            return tmp;
        }

        bool operator==(const iterator& other) const {
            return current_ == other.current_;
        }

        bool operator==(std::default_sentinel_t) const {
            return current_ == end_;
        }
    };

public:
    stride_view() = default;
    stride_view(R base, std::ranges::range_difference_t<R> stride)
        : base_(std::move(base)), stride_(stride) {}

    auto begin() {
        return iterator(std::ranges::begin(base_), std::ranges::end(base_), stride_);
    }

    auto end() { return std::default_sentinel; }
};

// 范围适配器闭包
template <typename D>
struct stride_closure {
    D stride;

    template <std::ranges::viewable_range R>
    auto operator()(R&& r) const {
        return stride_view<std::views::all_t<R>>(
            std::views::all(std::forward<R>(r)), stride);
    }
};

struct stride_fn {
    template <std::ranges::viewable_range R>
    auto operator()(R&& r, std::ranges::range_difference_t<R> stride) const {
        return stride_view<std::views::all_t<R>>(
            std::views::all(std::forward<R>(r)), stride);
    }

    auto operator()(auto stride) const {
        return stride_closure<decltype(stride)>{stride};
    }
};

template <std::ranges::viewable_range R, typename T>
auto operator|(R&& r, stride_closure<T> c) {
    return c(std::forward<R>(r));
}

inline constexpr stride_fn stride{};

}  // namespace my_views

// 使用示例
void demo_stride() {
    std::vector<int> v = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9};

    // 每隔2个元素取一个
    for (int x : v | my_views::stride(2)) {
        std::cout << x << " ";
    }
    // 0 2 4 6 8

    // 每隔3个
    for (int x : v | my_views::stride(3)) {
        std::cout << x << " ";
    }
    // 0 3 6 9
}
```

**view_interface的作用**：

```cpp
// view_interface提供默认实现：
// - empty()
// - operator bool()
// - data() (如果是contiguous_range)
// - size() (如果是sized_range)
// - front(), back()
// - operator[]

// 继承view_interface可以自动获得这些成员
template <std::ranges::input_range R>
class my_view : public std::ranges::view_interface<my_view<R>> {
    // 只需要实现begin()和end()
    // 其他成员由view_interface提供
};
```

**练习题**：
1. 实现一个`chunk_view`，将范围分成固定大小的块
2. 实现一个`adjacent_view`，返回相邻元素对
3. 为什么自定义view需要继承view_interface？

---

#### Day 5: Ranges算法（4小时）

**学习目标**：深入了解std::ranges中的算法

**ranges算法的优势**：

```cpp
#include <algorithm>
#include <ranges>

// 1. 直接接受范围
std::vector<int> v = {3, 1, 4, 1, 5, 9};
std::ranges::sort(v);  // 不需要begin/end

// 2. 投影（Projection）
struct Person {
    std::string name;
    int age;
};

std::vector<Person> people = {
    {"Alice", 30}, {"Bob", 25}, {"Charlie", 35}
};

// 按年龄排序——使用投影
std::ranges::sort(people, {}, &Person::age);
// 等价于
std::ranges::sort(people, std::less{}, [](const Person& p) { return p.age; });

// 3. 返回更多信息
auto [found, last] = std::ranges::find(v, 4);
// found: 指向找到的元素（或end）
// last: 范围的end迭代器

// 4. 约束更严格——编译期错误更清晰
// std::ranges::sort需要random_access_range和sortable约束
```

**常用ranges算法对比**：

```cpp
// find系列
auto it1 = std::find(v.begin(), v.end(), 4);
auto it2 = std::ranges::find(v, 4);

// sort系列
std::sort(v.begin(), v.end());
std::ranges::sort(v);
std::ranges::sort(v, std::greater{});  // 降序
std::ranges::sort(v, {}, std::negate{});  // 按负值排序

// copy系列
std::vector<int> dst(v.size());
std::copy(v.begin(), v.end(), dst.begin());
std::ranges::copy(v, dst.begin());

auto result = std::ranges::copy(v, dst.begin());
// result.in: 源范围的end
// result.out: 目标范围的新位置

// for_each
std::for_each(v.begin(), v.end(), [](int& x) { x *= 2; });
std::ranges::for_each(v, [](int& x) { x *= 2; });

// transform
std::transform(v.begin(), v.end(), dst.begin(), [](int x) { return x * 2; });
std::ranges::transform(v, dst.begin(), [](int x) { return x * 2; });
```

**ranges专属算法**：

```cpp
// contains (C++23)
bool has_three = std::ranges::contains(v, 3);

// starts_with / ends_with (C++23)
std::vector<int> prefix = {1, 2, 3};
bool starts = std::ranges::starts_with(v, prefix);

// fold_left / fold_right (C++23)
int sum = std::ranges::fold_left(v, 0, std::plus{});

// iota (C++23 algorithm, different from views::iota)
std::vector<int> seq(10);
std::ranges::iota(seq, 0);  // 0, 1, 2, ..., 9
```

**Ranges算法与Views配合**：

```cpp
std::vector<int> v = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};

// 对过滤后的视图排序？
// 不行！filter_view是bidirectional，sort需要random_access

// 正确方式：先转换为容器
auto evens = v
    | std::views::filter([](int x) { return x % 2 == 0; })
    | std::ranges::to<std::vector>();  // C++23
// 或者
std::vector<int> evens_vec(evens_view.begin(), evens_view.end());
std::ranges::sort(evens_vec);

// 对transform后的视图查找
auto squares = v | std::views::transform([](int x) { return x * x; });
auto found = std::ranges::find(squares, 16);
if (found != squares.end()) {
    std::cout << "Found 16 in squares\n";
}
```

**练习题**：
1. 使用投影实现：按字符串长度排序
2. 比较std::find和std::ranges::find的返回值
3. 为什么不能对filter_view调用std::ranges::sort？

---

#### Day 6: Ranges与传统STL互操作（4小时）

**学习目标**：掌握Ranges与传统代码的兼容性

**Views转换为容器**：

```cpp
// C++23: std::ranges::to
auto view = std::views::iota(1, 11)
    | std::views::filter([](int x) { return x % 2 == 0; });

auto vec = view | std::ranges::to<std::vector>();
auto list = view | std::ranges::to<std::list>();
auto set = view | std::ranges::to<std::set>();

// C++20替代方案
std::vector<int> vec2(view.begin(), view.end());

// 或者使用copy
std::vector<int> vec3;
std::ranges::copy(view, std::back_inserter(vec3));
```

**传统迭代器与Ranges**：

```cpp
// 传统算法可以用于Views的迭代器
auto view = std::views::iota(1, 11);

// 但需要注意类型
auto it = view.begin();
auto end = view.end();

// 某些views的begin和end类型不同（sentinel）
// 这时需要views::common
auto common_view = view | std::views::common;
// 现在begin和end类型相同

// 传递给需要相同类型的函数
legacy_function(common_view.begin(), common_view.end());
```

**借用范围（Borrowed Ranges）**：

```cpp
// 问题：dangling引用
auto get_view() {
    std::vector<int> v = {1, 2, 3};
    return v | std::views::filter([](int x) { return x > 0; });
    // 危险！v在函数返回后销毁，但view引用它
}

// 解决方案：borrowed_range概念
// 某些范围即使临时对象销毁，迭代器仍然有效

// std::span是borrowed_range
std::span<int> get_span(std::vector<int>& v) {
    return std::span(v);  // 安全，因为不拥有数据
}

// ranges算法在临时borrowed_range上返回有效迭代器
std::vector<int> v = {1, 2, 3};
auto it = std::ranges::find(std::span(v), 2);  // 安全
// auto it = std::ranges::find(std::vector{1,2,3}, 2);  // 返回dangling

// 检查返回类型
// 如果范围不是borrowed，返回std::ranges::dangling
```

**subrange的使用**：

```cpp
// subrange包装一对迭代器
std::vector<int> v = {1, 2, 3, 4, 5};

// 从迭代器对创建subrange
auto sub = std::ranges::subrange(v.begin() + 1, v.end() - 1);
// sub: {2, 3, 4}

// subrange可以像范围一样使用
for (int x : sub) {
    std::cout << x << " ";
}

// 用于传递迭代器对给ranges函数
std::ranges::sort(std::ranges::subrange(v.begin(), v.end()));

// 分解迭代器
auto [begin, end] = std::ranges::subrange(v.begin(), v.end());
```

**owning_view (C++20)**：

```cpp
// owning_view拥有一个范围
auto make_view() {
    return std::views::owning(std::vector{1, 2, 3});
    // owning_view拥有vector，不会悬垂
}

auto view = make_view();  // 安全
```

**练习题**：
1. 解释borrowed_range和dangling的作用
2. 何时需要使用views::common？
3. 实现一个函数，接受传统迭代器对并返回ranges view

---

#### Day 7: 综合项目与性能对比（5小时）

**本周知识点总结**：

1. **Ranges基础**：统一的范围接口，简化算法调用
2. **Views**：惰性视图，链式操作，无中间容器
3. **常用Views**：filter, transform, take, drop, split, join等
4. **自定义View**：继承view_interface，实现迭代器
5. **Ranges算法**：投影支持，更好的返回值
6. **互操作**：to<>转换，common, borrowed_range

**综合项目：使用Ranges实现数据处理流水线**：

```cpp
// data_processor.hpp
#pragma once
#include <ranges>
#include <string>
#include <vector>
#include <fstream>
#include <sstream>
#include <algorithm>

struct Record {
    int id;
    std::string name;
    double value;
    bool active;
};

// 解析CSV行
Record parse_record(std::string_view line) {
    Record r;
    std::istringstream iss(std::string(line));
    char comma;
    iss >> r.id >> comma;
    std::getline(iss, r.name, ',');
    iss >> r.value >> comma >> std::boolalpha >> r.active;
    return r;
}

// 使用Ranges处理数据
class DataProcessor {
    std::vector<Record> records_;

public:
    void load_from_csv(const std::string& filename) {
        std::ifstream file(filename);
        std::string line;

        // 跳过标题行
        std::getline(file, line);

        while (std::getline(file, line)) {
            records_.push_back(parse_record(line));
        }
    }

    // 获取活跃记录的值总和
    double sum_active_values() const {
        auto active_values = records_
            | std::views::filter(&Record::active)
            | std::views::transform(&Record::value);

        return std::accumulate(active_values.begin(), active_values.end(), 0.0);
    }

    // 获取前N个最大值记录
    std::vector<Record> top_n_by_value(int n) const {
        auto sorted = records_;
        std::ranges::sort(sorted, std::greater{}, &Record::value);
        return sorted
            | std::views::take(n)
            | std::ranges::to<std::vector>();  // C++23
    }

    // 按条件筛选并转换
    auto get_names_of_active() const {
        return records_
            | std::views::filter(&Record::active)
            | std::views::transform(&Record::name);
    }

    // 分组统计
    std::map<bool, double> group_sum_by_active() const {
        std::map<bool, double> result;
        for (const auto& r : records_) {
            result[r.active] += r.value;
        }
        return result;
    }

    // 复杂查询：活跃且值大于阈值的记录名称
    auto query(double threshold) const {
        return records_
            | std::views::filter([threshold](const Record& r) {
                return r.active && r.value > threshold;
            })
            | std::views::transform(&Record::name);
    }
};

// 使用示例
void demo_data_processor() {
    DataProcessor dp;
    dp.load_from_csv("data.csv");

    std::cout << "Sum of active values: " << dp.sum_active_values() << "\n";

    std::cout << "Names of active records:\n";
    for (const auto& name : dp.get_names_of_active()) {
        std::cout << "  " << name << "\n";
    }

    std::cout << "High value active records (>100):\n";
    for (const auto& name : dp.query(100.0)) {
        std::cout << "  " << name << "\n";
    }
}
```

**性能对比实验**：

```cpp
#include <chrono>
#include <random>

void performance_comparison() {
    const int N = 10000000;
    std::vector<int> data(N);

    std::mt19937 rng(42);
    std::generate(data.begin(), data.end(), rng);

    // 任务：计算所有偶数的平方和

    // 方法1：传统STL（多次遍历，中间容器）
    auto start1 = std::chrono::high_resolution_clock::now();
    std::vector<int> evens;
    std::copy_if(data.begin(), data.end(), std::back_inserter(evens),
                 [](int x) { return x % 2 == 0; });
    std::vector<long long> squares;
    squares.reserve(evens.size());
    std::transform(evens.begin(), evens.end(), std::back_inserter(squares),
                   [](int x) { return static_cast<long long>(x) * x; });
    long long sum1 = std::accumulate(squares.begin(), squares.end(), 0LL);
    auto end1 = std::chrono::high_resolution_clock::now();

    // 方法2：手写循环（单次遍历）
    auto start2 = std::chrono::high_resolution_clock::now();
    long long sum2 = 0;
    for (int x : data) {
        if (x % 2 == 0) {
            sum2 += static_cast<long long>(x) * x;
        }
    }
    auto end2 = std::chrono::high_resolution_clock::now();

    // 方法3：Ranges（惰性，单次遍历）
    auto start3 = std::chrono::high_resolution_clock::now();
    long long sum3 = 0;
    for (auto x : data
            | std::views::filter([](int x) { return x % 2 == 0; })
            | std::views::transform([](int x) { return static_cast<long long>(x) * x; })) {
        sum3 += x;
    }
    auto end3 = std::chrono::high_resolution_clock::now();

    auto ms = [](auto d) {
        return std::chrono::duration_cast<std::chrono::milliseconds>(d).count();
    };

    std::cout << "Traditional STL: " << ms(end1 - start1) << " ms\n";
    std::cout << "Hand-written loop: " << ms(end2 - start2) << " ms\n";
    std::cout << "Ranges: " << ms(end3 - start3) << " ms\n";

    // 验证结果一致
    assert(sum1 == sum2 && sum2 == sum3);
}
```

**本周检验标准**：
- [ ] 理解Ranges相对于传统STL的优势
- [ ] 掌握Views的惰性求值原理
- [ ] 熟练使用常用的Views适配器
- [ ] 能实现自定义View
- [ ] 理解Ranges算法与投影
- [ ] 掌握Ranges与传统代码的互操作

---

## 检验标准

### 知识检验
- [ ] 解释五种迭代器类别的区别
- [ ] iterator_traits的作用是什么？
- [ ] std::sort使用什么算法？为什么？
- [ ] reverse_iterator的*操作为什么要减1？
- [ ] Ranges的Views为什么是惰性的？

### 实践检验
- [ ] 自定义迭代器能与STL算法配合使用
- [ ] mini_algorithms通过测试
- [ ] mini_ranges能实现基本的管道操作

### 输出物
1. `list_iterator.hpp`
2. `mini_algorithms.hpp`
3. `mini_ranges.hpp`
4. `test_iterators.cpp`
5. `notes/month09_iterators.md`

---

## 时间分配（140小时/月）

| 内容 | 时间 | 占比 |
|------|------|------|
| 理论学习 | 30小时 | 21% |
| 源码阅读 | 30小时 | 21% |
| 迭代器实现 | 30小时 | 22% |
| 算法实现 | 35小时 | 25% |
| Ranges与测试 | 15小时 | 11% |

---

## 下月预告

Month 10将学习**字符串处理与正则表达式**，深入string/string_view的实现，SSO优化，以及std::regex的使用和性能考量。
