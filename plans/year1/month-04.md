# Month 04: 智能指针与RAII模式——所有权语义的工程实现

## 本月主题概述

RAII（资源获取即初始化）是C++最核心的编程范式，智能指针是RAII的最佳实践。本月将深入分析`unique_ptr`、`shared_ptr`、`weak_ptr`的源码实现，理解所有权转移、引用计数、循环引用等核心问题，并亲手实现完整的智能指针库。

---

## 理论学习内容

### 第一周：RAII原理与所有权语义

**学习目标**：深入理解RAII和C++所有权模型

**阅读材料**：
- [ ] 《Effective Modern C++》Item 18-22（智能指针相关）
- [ ] CppCon演讲："Back to Basics: RAII and the Rule of Zero"
- [ ] 博客：Herb Sutter - "GotW #89: Smart Pointers"

**核心概念**：

#### RAII的本质
```cpp
// RAII = 构造函数获取资源，析构函数释放资源
class FileHandle {
    FILE* fp;
public:
    FileHandle(const char* path) : fp(fopen(path, "r")) {
        if (!fp) throw std::runtime_error("Cannot open file");
    }
    ~FileHandle() {
        if (fp) fclose(fp);
    }
    // 禁止拷贝，允许移动
    FileHandle(const FileHandle&) = delete;
    FileHandle& operator=(const FileHandle&) = delete;
    FileHandle(FileHandle&& other) noexcept : fp(other.fp) {
        other.fp = nullptr;
    }
};
```

#### 所有权的三种模式
1. **独占所有权**（Unique Ownership）: `std::unique_ptr`
2. **共享所有权**（Shared Ownership）: `std::shared_ptr`
3. **观察者**（Non-owning Observer）: `std::weak_ptr`, 原始指针

**思考问题**：
- [ ] 为什么说RAII是"异常安全的基石"？
- [ ] Rule of 0/3/5分别是什么？何时使用？

---

#### 第一周详细学习计划

##### Day 1-2: RAII哲学与历史渊源

**学习内容**：
1. **RAII的起源**
   - Bjarne Stroustrup在1984年设计C++时提出
   - 最初称为"Resource Acquisition Is Initialization"
   - 核心洞见：将资源生命周期绑定到对象生命周期

2. **为什么RAII比手动管理更优越**
```cpp
// 错误示例：手动资源管理的脆弱性
void process_file_bad(const char* path) {
    FILE* fp = fopen(path, "r");
    if (!fp) return;

    char* buffer = new char[1024];

    // 如果这里抛出异常，buffer和fp都泄漏！
    do_something_risky();

    delete[] buffer;  // 可能永远执行不到
    fclose(fp);       // 可能永远执行不到
}

// 正确示例：RAII自动管理
void process_file_good(const char* path) {
    std::ifstream file(path);  // RAII: 构造时打开
    if (!file) return;

    std::vector<char> buffer(1024);  // RAII: 自动管理内存

    do_something_risky();  // 即使异常，资源也会释放
}  // 析构时自动关闭文件和释放内存
```

3. **异常安全的三个级别**
```cpp
// 基本保证（Basic Guarantee）：异常后对象处于有效状态
// 强保证（Strong Guarantee）：异常后状态回滚
// 无抛出保证（Nothrow Guarantee）：操作永不抛出异常

class StrongGuarantee {
    std::vector<int> data_;
public:
    // 强保证：要么完全成功，要么完全失败
    void add(int value) {
        std::vector<int> temp = data_;  // 先拷贝
        temp.push_back(value);          // 可能抛出
        data_ = std::move(temp);        // noexcept，不会失败
    }
};
```

**实践练习**：
```cpp
// 练习1：实现一个RAII的互斥锁包装器
template <typename Mutex>
class lock_guard {
    Mutex& mutex_;
public:
    explicit lock_guard(Mutex& m) : mutex_(m) {
        mutex_.lock();
    }
    ~lock_guard() {
        mutex_.unlock();
    }
    lock_guard(const lock_guard&) = delete;
    lock_guard& operator=(const lock_guard&) = delete;
};

// 练习2：实现RAII的作用域退出器（类似Go的defer）
template <typename F>
class scope_exit {
    F func_;
    bool active_ = true;
public:
    explicit scope_exit(F f) : func_(std::move(f)) {}
    ~scope_exit() { if (active_) func_(); }
    void dismiss() { active_ = false; }

    scope_exit(const scope_exit&) = delete;
    scope_exit& operator=(const scope_exit&) = delete;
};

// 使用示例
void example() {
    auto cleanup = scope_exit([]{ std::cout << "Cleanup!\n"; });
    // ... 如果中途return或异常，cleanup仍会执行
}
```

##### Day 3-4: Rule of 0/3/5 深入解析

**学习内容**：

1. **Rule of Three（C++98）**
```cpp
// 如果你定义了以下任一个，通常需要定义全部三个：
// - 析构函数
// - 拷贝构造函数
// - 拷贝赋值运算符

class StringOld {
    char* data_;
    size_t size_;
public:
    // 构造函数
    StringOld(const char* s = "") {
        size_ = strlen(s);
        data_ = new char[size_ + 1];
        strcpy(data_, s);
    }

    // 1. 析构函数
    ~StringOld() { delete[] data_; }

    // 2. 拷贝构造函数（深拷贝）
    StringOld(const StringOld& other)
        : size_(other.size_), data_(new char[other.size_ + 1]) {
        strcpy(data_, other.data_);
    }

    // 3. 拷贝赋值运算符（copy-and-swap idiom）
    StringOld& operator=(StringOld other) {  // 传值！
        swap(other);
        return *this;
    }

    void swap(StringOld& other) noexcept {
        std::swap(data_, other.data_);
        std::swap(size_, other.size_);
    }
};
```

2. **Rule of Five（C++11）**
```cpp
// C++11加入移动语义，扩展为五个：
// - 析构函数
// - 拷贝构造函数
// - 拷贝赋值运算符
// - 移动构造函数
// - 移动赋值运算符

class StringModern {
    char* data_;
    size_t size_;
public:
    StringModern(const char* s = "") {
        size_ = strlen(s);
        data_ = new char[size_ + 1];
        strcpy(data_, s);
    }

    ~StringModern() { delete[] data_; }

    // 拷贝构造
    StringModern(const StringModern& other)
        : size_(other.size_), data_(new char[other.size_ + 1]) {
        strcpy(data_, other.data_);
    }

    // 移动构造 - 窃取资源
    StringModern(StringModern&& other) noexcept
        : data_(other.data_), size_(other.size_) {
        other.data_ = nullptr;
        other.size_ = 0;
    }

    // 统一赋值运算符（处理拷贝和移动）
    StringModern& operator=(StringModern other) noexcept {
        swap(other);
        return *this;
    }

    void swap(StringModern& other) noexcept {
        std::swap(data_, other.data_);
        std::swap(size_, other.size_);
    }
};
```

3. **Rule of Zero（现代C++最佳实践）**
```cpp
// 最佳实践：让编译器生成所有特殊成员函数
// 通过使用RAII成员（智能指针、容器等）实现

class PersonZero {
    std::string name_;                              // RAII成员
    std::vector<std::string> addresses_;           // RAII成员
    std::unique_ptr<BankAccount> account_;         // RAII成员

public:
    PersonZero(std::string name) : name_(std::move(name)) {}

    // 不需要定义任何特殊成员函数！
    // 编译器自动生成的版本会正确处理：
    // - 析构：自动调用成员的析构函数
    // - 拷贝：string和vector可拷贝，unique_ptr删除拷贝
    // - 移动：所有成员都支持移动
};

// 如果需要自定义但又想要默认行为
class PersonExplicit {
    std::string name_;
public:
    PersonExplicit() = default;
    ~PersonExplicit() = default;
    PersonExplicit(const PersonExplicit&) = default;
    PersonExplicit& operator=(const PersonExplicit&) = default;
    PersonExplicit(PersonExplicit&&) = default;
    PersonExplicit& operator=(PersonExplicit&&) = default;
};
```

**决策流程图**：
```
需要管理资源吗？
    |
    +-- 否 --> Rule of Zero（不定义任何特殊成员）
    |
    +-- 是 --> 能否用RAII成员替代？
                  |
                  +-- 是 --> Rule of Zero
                  |
                  +-- 否 --> Rule of Five
```

##### Day 5-6: 所有权语义的工程选择

**学习内容**：

1. **何时选择哪种所有权模式**

```cpp
// 独占所有权（unique_ptr）适用场景：
// - 工厂函数返回值
// - 类的成员变量（独占资源）
// - Pimpl模式
// - 容器中存储多态对象

class Document {
    // Pimpl: 隐藏实现细节
    std::unique_ptr<DocumentImpl> impl_;
public:
    Document();
    ~Document();  // 需要在cpp文件中定义，因为DocumentImpl在那里完整
};

// 工厂模式
std::unique_ptr<Shape> createShape(ShapeType type) {
    switch (type) {
        case Circle: return std::make_unique<Circle>();
        case Square: return std::make_unique<Square>();
        default: return nullptr;
    }
}
```

```cpp
// 共享所有权（shared_ptr）适用场景：
// - 多个对象需要共同拥有同一资源
// - 缓存系统
// - 观察者模式中的共享状态
// - 线程间共享数据

class Cache {
    std::unordered_map<std::string, std::shared_ptr<Data>> cache_;
public:
    std::shared_ptr<Data> get(const std::string& key) {
        auto it = cache_.find(key);
        if (it != cache_.end()) return it->second;

        auto data = std::make_shared<Data>(load_from_disk(key));
        cache_[key] = data;
        return data;  // 调用者和缓存共同持有
    }
};
```

```cpp
// 非拥有观察者（weak_ptr/原始指针）适用场景：
// - 打破循环引用
// - 缓存的弱引用
// - 父子关系中的反向引用

// 原始指针的合法用途
class Widget {
    Observer* observer_;  // 不拥有，只观察
public:
    void setObserver(Observer* obs) { observer_ = obs; }
    void notify() { if (observer_) observer_->onEvent(); }
};
```

2. **函数参数的所有权语义**
```cpp
// 传递所有权：使用unique_ptr by value
void takeOwnership(std::unique_ptr<Widget> widget);

// 共享所有权：使用shared_ptr by value
void shareOwnership(std::shared_ptr<Widget> widget);

// 只读访问：使用const引用或原始指针
void observe(const Widget& widget);      // 推荐
void observe(const Widget* widget);      // 可选null时

// 可能共享也可能不共享：使用shared_ptr const引用
void maybeShare(const std::shared_ptr<Widget>& widget);

// 错误：不应该用shared_ptr引用，如果不打算共享
void wrong(std::shared_ptr<Widget>& widget);  // 坏味道
```

##### Day 7: 本周总结与练习

**综合练习**：

```cpp
// 实现一个简单的对象池，综合运用本周所学

template <typename T>
class ObjectPool {
    struct PoolDeleter {
        ObjectPool* pool_;
        void operator()(T* ptr) const {
            pool_->recycle(ptr);
        }
    };

    std::vector<std::unique_ptr<T>> storage_;
    std::vector<T*> available_;

public:
    using Ptr = std::unique_ptr<T, PoolDeleter>;

    ObjectPool(size_t initial_size = 10) {
        for (size_t i = 0; i < initial_size; ++i) {
            storage_.push_back(std::make_unique<T>());
            available_.push_back(storage_.back().get());
        }
    }

    Ptr acquire() {
        if (available_.empty()) {
            storage_.push_back(std::make_unique<T>());
            available_.push_back(storage_.back().get());
        }
        T* ptr = available_.back();
        available_.pop_back();
        return Ptr(ptr, PoolDeleter{this});
    }

private:
    void recycle(T* ptr) {
        // 重置对象状态
        *ptr = T{};
        available_.push_back(ptr);
    }
};

// 使用示例
void demo() {
    ObjectPool<std::string> pool;

    {
        auto s1 = pool.acquire();
        *s1 = "Hello";
        auto s2 = pool.acquire();
        *s2 = "World";
        // s1, s2超出作用域时自动回收到池中
    }

    auto s3 = pool.acquire();  // 复用之前的对象
}
```

**本周检验清单**：
- [ ] 能够解释RAII如何保证异常安全
- [ ] 理解Rule of 0/3/5并能正确应用
- [ ] 知道何时使用unique_ptr vs shared_ptr vs weak_ptr
- [ ] 完成lock_guard和scope_exit的实现
- [ ] 完成ObjectPool的实现并通过测试

### 第二周：std::unique_ptr源码分析

**学习目标**：理解独占所有权的实现

**阅读路径**（GCC libstdc++）：
- `bits/unique_ptr.h`

**源码分析要点**：

#### unique_ptr的内存布局
```cpp
template<typename _Tp, typename _Dp = default_delete<_Tp>>
class unique_ptr {
    // 使用tuple压缩存储，利用空基类优化
    __uniq_ptr_impl<_Tp, _Dp> _M_t;
};

// _M_t 内部实际是 tuple<pointer, deleter>
// 当deleter是空类（如default_delete）时，利用EBO不占额外空间
```

**关键实现分析**：

```cpp
// 1. 为什么unique_ptr只能移动不能拷贝？
unique_ptr(const unique_ptr&) = delete;
unique_ptr& operator=(const unique_ptr&) = delete;

// 2. 移动构造如何实现？
unique_ptr(unique_ptr&& __u) noexcept
    : _M_t(__u.release(), std::forward<deleter_type>(__u.get_deleter()))
{ }

// 3. release vs reset的区别
pointer release() noexcept {
    pointer __p = get();
    _M_t._M_ptr() = pointer();
    return __p;  // 返回指针，不删除
}

void reset(pointer __p = pointer()) noexcept {
    pointer __old = get();
    _M_t._M_ptr() = __p;
    if (__old) get_deleter()(__old);  // 删除旧指针
}
```

**自定义删除器**：
```cpp
// 文件句柄的unique_ptr
auto file_deleter = [](FILE* f) { if(f) fclose(f); };
std::unique_ptr<FILE, decltype(file_deleter)> fp(fopen("test.txt", "r"), file_deleter);

// Windows HANDLE
struct HandleDeleter {
    void operator()(HANDLE h) const {
        if (h != INVALID_HANDLE_VALUE) CloseHandle(h);
    }
};
std::unique_ptr<void, HandleDeleter> handle(CreateFile(...));
```

---

#### 第二周详细学习计划

##### Day 1-2: unique_ptr内存布局与空基类优化

**学习内容**：

1. **为什么unique_ptr是零开销抽象**
```cpp
// 核心问题：unique_ptr<T>的大小是多少？
static_assert(sizeof(std::unique_ptr<int>) == sizeof(int*));
// 答案：和原始指针一样大！

// 但如果有状态的删除器呢？
struct StatefulDeleter {
    std::string log_file;
    void operator()(int* p) const { delete p; }
};
// sizeof(unique_ptr<int, StatefulDeleter>) == sizeof(int*) + sizeof(string)
```

2. **空基类优化（EBO）的应用**
```cpp
// libstdc++的实现使用__uniq_ptr_impl
template<typename _Tp, typename _Dp>
class __uniq_ptr_impl {
    // 使用tuple实现EBO
    // tuple<pointer, Deleter>在Deleter为空类时不占额外空间
    tuple<pointer, _Dp> _M_t;
};

// 演示EBO
struct EmptyDeleter { void operator()(int* p) { delete p; } };

// 不使用EBO的糟糕实现
template <typename T, typename D>
struct BadUniquePtr {
    T* ptr;      // 8 bytes
    D deleter;   // 至少1 byte（空类也占1字节）
};  // 由于对齐，实际16 bytes!

// 使用EBO的优秀实现
template <typename T, typename D>
struct GoodUniquePtr : private D {  // 空基类不占空间
    T* ptr;  // 只有8 bytes
};
// sizeof(GoodUniquePtr<int, EmptyDeleter>) == 8
```

3. **C++20的[[no_unique_address]]**
```cpp
// C++20提供了更简洁的写法
template <typename T, typename D = std::default_delete<T>>
class modern_unique_ptr {
    T* ptr_;
    [[no_unique_address]] D deleter_;  // 如果D是空类，不占空间
};
```

**源码阅读任务**：
```cpp
// 找到并分析 bits/unique_ptr.h 中的以下部分：

// 1. __uniq_ptr_impl 的定义
// 问题：它如何实现EBO？

// 2. default_delete 的特化
// 问题：为什么要为数组提供特化？

// 3. unique_ptr<T[]> 的特化
// 问题：它和 unique_ptr<T> 有什么不同？
```

##### Day 3-4: 移动语义与所有权转移

**学习内容**：

1. **为什么unique_ptr禁止拷贝**
```cpp
// 如果允许拷贝会发生什么？
std::unique_ptr<int> p1(new int(42));
std::unique_ptr<int> p2 = p1;  // 假设允许

// p1和p2都指向同一块内存
// 当p1销毁时，内存被释放
// 当p2销毁时，double free! 未定义行为！

// 解决方案：删除拷贝操作
unique_ptr(const unique_ptr&) = delete;
unique_ptr& operator=(const unique_ptr&) = delete;
```

2. **移动构造的实现细节**
```cpp
// 标准库的实现
unique_ptr(unique_ptr&& __u) noexcept
    : _M_t(__u.release(),
           std::forward<deleter_type>(__u.get_deleter()))
{ }

// 分解来看：
// 1. __u.release() 释放所有权，返回原始指针，__u变为nullptr
// 2. std::forward保持删除器的值类别（左值或右值）
// 3. noexcept承诺不抛出异常（移动语义的关键）
```

3. **release() vs reset() vs swap()**
```cpp
std::unique_ptr<int> p(new int(42));

// release(): 放弃所有权，返回原始指针
int* raw = p.release();
// p现在是nullptr，调用者负责管理raw

// reset(): 释放当前资源，可选地接管新资源
p.reset(new int(100));  // 释放旧的（如果有），接管新的
p.reset();              // 释放当前资源，变为nullptr

// swap(): 交换两个unique_ptr
std::unique_ptr<int> q(new int(200));
p.swap(q);  // p和q互换内容
```

**陷阱与最佳实践**：
```cpp
// 陷阱1：不要手动delete release()的结果后还使用原指针
auto p = std::make_unique<int>(42);
int* raw = p.release();
delete raw;
// raw现在是悬垂指针！

// 陷阱2：不要对同一指针创建多个unique_ptr
int* raw = new int(42);
std::unique_ptr<int> p1(raw);
std::unique_ptr<int> p2(raw);  // 危险！double free

// 最佳实践：使用make_unique
auto p = std::make_unique<int>(42);  // 安全、清晰、异常安全
```

##### Day 5-6: 自定义删除器深入

**学习内容**：

1. **删除器的各种形式**
```cpp
// 形式1：函数指针
void my_delete(int* p) { std::cout << "Deleting\n"; delete p; }
std::unique_ptr<int, void(*)(int*)> p1(new int(42), my_delete);
// 注意：函数指针会增加unique_ptr的大小！

// 形式2：函数对象（空类，推荐）
struct MyDeleter {
    void operator()(int* p) const { delete p; }
};
std::unique_ptr<int, MyDeleter> p2(new int(42));
// 空类删除器不增加大小

// 形式3：Lambda（C++20前需要decltype）
auto lambda_del = [](int* p) { delete p; };
std::unique_ptr<int, decltype(lambda_del)> p3(new int(42), lambda_del);

// C++20: Lambda可以默认构造
std::unique_ptr<int, decltype([](int* p) { delete p; })> p4(new int(42));
```

2. **实用删除器示例**
```cpp
// POSIX文件描述符
struct FDDeleter {
    void operator()(int* fd) const {
        if (fd && *fd >= 0) {
            ::close(*fd);
        }
        delete fd;
    }
};

// 更好的设计：使用int直接，而非int*
struct FDDeleterDirect {
    void operator()(int fd) const {
        if (fd >= 0) ::close(fd);
    }
};
// 但unique_ptr需要指针类型，所以这种情况用专门的RAII类更好

// 数据库连接
struct DBConnectionDeleter {
    void operator()(DBConnection* conn) const {
        if (conn) {
            conn->commit();  // 或 rollback()
            conn->close();
            delete conn;
        }
    }
};

// 内存映射
struct MMapDeleter {
    size_t size;
    void operator()(void* ptr) const {
        if (ptr && ptr != MAP_FAILED) {
            munmap(ptr, size);
        }
    }
};
```

3. **删除器与多态**
```cpp
// 问题：基类析构函数不是虚函数时
struct Base { ~Base() { std::cout << "~Base\n"; } };
struct Derived : Base { ~Derived() { std::cout << "~Derived\n"; } };

std::unique_ptr<Base> p(new Derived);
// 销毁时只调用 ~Base，~Derived 泄漏！

// 解决方案1：让Base的析构函数为虚
struct Base { virtual ~Base() = default; };

// 解决方案2：自定义删除器（不推荐，但展示可能性）
auto poly_deleter = [](Base* p) {
    // 这里仍然需要知道实际类型...不实用
};
```

##### Day 7: 本周总结与实践

**综合练习：实现完整的mini_unique_ptr**：
```cpp
// 完成以下功能并通过测试：

// 1. 基础版本（已在文档中给出）

// 2. 添加数组支持
template <typename T, typename Deleter>
class mini_unique_ptr<T[], Deleter> {
    // 实现数组特化
    // 支持 operator[]
    // 使用 delete[]
};

// 3. 添加类型转换支持
template <typename U, typename E>
mini_unique_ptr(mini_unique_ptr<U, E>&& other) noexcept
    // 从派生类unique_ptr移动到基类unique_ptr

// 4. 实现比较运算符
template <typename T1, typename D1, typename T2, typename D2>
bool operator==(const mini_unique_ptr<T1, D1>& lhs,
                const mini_unique_ptr<T2, D2>& rhs);

// 5. 支持nullptr比较
bool operator==(const mini_unique_ptr<T, D>& ptr, std::nullptr_t);
```

**测试用例**：
```cpp
void test_mini_unique_ptr() {
    // 基本功能
    {
        auto p = make_mini_unique<int>(42);
        assert(*p == 42);
        assert(p.get() != nullptr);
    }

    // 移动语义
    {
        auto p1 = make_mini_unique<std::string>("Hello");
        auto p2 = std::move(p1);
        assert(p1.get() == nullptr);
        assert(*p2 == "Hello");
    }

    // 自定义删除器
    {
        bool deleted = false;
        {
            auto deleter = [&deleted](int* p) {
                deleted = true;
                delete p;
            };
            mini_unique_ptr<int, decltype(deleter)> p(new int(42), deleter);
        }
        assert(deleted);
    }

    // 数组支持
    {
        mini_unique_ptr<int[]> arr(new int[5]);
        arr[0] = 1;
        arr[4] = 5;
        assert(arr[0] == 1);
    }

    std::cout << "All tests passed!\n";
}
```

**本周检验清单**：
- [ ] 理解unique_ptr如何实现零开销抽象
- [ ] 能够解释EBO和[[no_unique_address]]
- [ ] 掌握release()、reset()、swap()的区别
- [ ] 能够编写各种形式的自定义删除器
- [ ] 完成mini_unique_ptr的实现和测试

### 第三周：std::shared_ptr与控制块

**学习目标**：理解引用计数的工程实现

**阅读路径**（GCC libstdc++）：
- `bits/shared_ptr_base.h`
- `bits/shared_ptr.h`

**源码分析要点**：

#### shared_ptr的内存布局
```cpp
template<typename _Tp>
class shared_ptr : public __shared_ptr<_Tp> {
    // 继承自 __shared_ptr
};

template<typename _Tp, _Lock_policy _Lp>
class __shared_ptr {
    element_type* _M_ptr;         // 指向管理对象的指针
    __shared_count<_Lp> _M_refcount;  // 控制块指针
};
```

#### 控制块结构
```cpp
// 控制块基类
class _Sp_counted_base {
    _Atomic_word _M_use_count;   // strong引用计数
    _Atomic_word _M_weak_count;  // weak引用计数 + 1

    virtual void _M_dispose() noexcept = 0;  // 删除托管对象
    virtual void _M_destroy() noexcept = 0;  // 删除控制块本身
};

// 实际的控制块实现
template<typename _Ptr, typename _Deleter, typename _Alloc>
class _Sp_counted_deleter : public _Sp_counted_base {
    _Ptr _M_ptr;
    _Deleter _M_del;
    _Alloc _M_alloc;
};
```

**关键问题分析**：

```cpp
// 1. 为什么 weak_count 初始值是 1 而不是 0？
// 答：这个额外的1代表"所有strong引用"。当所有strong引用归零时，
// weak_count减1；当weak_count归零时，控制块才被销毁。

// 2. make_shared 如何实现单次分配？
auto sp = std::make_shared<Foo>(args...);
// 等价于分配一块内存同时包含控制块和Foo对象
// struct Combined {
//     _Sp_counted_base control_block;
//     aligned_storage<Foo> object;
// };

// 3. shared_ptr的线程安全性
// - 控制块的引用计数操作是原子的
// - 但对同一个shared_ptr对象的并发读写不是线程安全的
// - 指向的对象本身的线程安全性取决于对象自己
```

---

#### 第三周详细学习计划

##### Day 1-2: 控制块的设计哲学

**学习内容**：

1. **为什么需要控制块（Control Block）**
```cpp
// 问题：多个shared_ptr如何知道引用计数？
std::shared_ptr<int> p1(new int(42));
std::shared_ptr<int> p2 = p1;  // p1和p2如何共享计数？

// 答案：它们都指向同一个控制块

// 如果把计数放在shared_ptr内部会怎样？
struct BadSharedPtr {
    int* ptr;
    int count;  // 每个shared_ptr都有自己的count，无法共享！
};

// 正确设计：控制块独立分配，所有shared_ptr共享
struct ControlBlock {
    std::atomic<long> use_count;
    std::atomic<long> weak_count;
    // ...删除器、分配器等
};

struct GoodSharedPtr {
    int* ptr;
    ControlBlock* ctrl;  // 所有共享的shared_ptr指向同一个ctrl
};
```

2. **控制块的多态设计**
```cpp
// 基类（纯虚）
class _Sp_counted_base {
    _Atomic_word _M_use_count;   // strong count
    _Atomic_word _M_weak_count;  // weak count

public:
    virtual void _M_dispose() noexcept = 0;  // 删除对象
    virtual void _M_destroy() noexcept = 0;  // 删除控制块本身
    virtual void* _M_get_deleter(const std::type_info&) = 0;
};

// 为什么weak_count初始值是1？
// 这个"1"代表所有strong引用的贡献
// 当use_count归零时，weak_count减1
// 当weak_count归零时，控制块才被销毁

// 时间线示例：
// 初始: use_count=1, weak_count=1
// 创建weak_ptr: use_count=1, weak_count=2
// 销毁shared_ptr: use_count=0, 调用dispose()销毁对象, weak_count=1
// 销毁weak_ptr: weak_count=0, 调用destroy()销毁控制块
```

3. **不同类型的控制块**
```cpp
// 类型1：分离分配（shared_ptr<T>(new T)）
template<typename _Ptr, typename _Deleter, typename _Alloc>
class _Sp_counted_deleter : public _Sp_counted_base {
    _Ptr _M_ptr;         // 指向对象
    _Deleter _M_del;     // 删除器
    _Alloc _M_alloc;     // 分配器（用于销毁控制块自己）
};
// 内存布局: [控制块] -> [对象]（两次分配）

// 类型2：单次分配（make_shared）
template<typename _Tp>
class _Sp_counted_ptr_inplace : public _Sp_counted_base {
    alignas(_Tp) char _M_storage[sizeof(_Tp)];
};
// 内存布局: [控制块 + 对象]（一次分配）
```

##### Day 3-4: make_shared的优化原理

**学习内容**：

1. **make_shared vs 直接构造的对比**
```cpp
// 方式1：直接构造（两次分配）
std::shared_ptr<Widget> sp1(new Widget(args));
// 分配1: new Widget
// 分配2: new 控制块

// 方式2：make_shared（一次分配）
auto sp2 = std::make_shared<Widget>(args);
// 分配1: new (控制块 + Widget空间)
```

2. **为什么make_shared更好**
```cpp
// 优点1：性能（一次分配 vs 两次分配）
// - 减少内存分配次数（分配是昂贵的操作）
// - 更好的缓存局部性（控制块和对象相邻）

// 优点2：异常安全
void unsafe(std::shared_ptr<A> a, std::shared_ptr<B> b);

unsafe(std::shared_ptr<A>(new A), std::shared_ptr<B>(new B));
// C++17之前，编译器可能以这个顺序执行：
// 1. new A
// 2. new B          <- 如果这里抛出异常
// 3. shared_ptr<A>() <- 还没执行，A泄漏了！
// 4. shared_ptr<B>()

// make_shared是安全的
unsafe(std::make_shared<A>(), std::make_shared<B>());
// 每个make_shared内部完成分配和构造，要么成功要么失败

// 优点3：代码简洁
auto p = std::make_shared<Widget>(1, 2, 3);  // 类型推导
```

3. **make_shared的缺点**
```cpp
// 缺点1：不能指定自定义删除器
// make_shared总是使用default_delete
auto custom = std::shared_ptr<FILE>(fopen("x", "r"), fclose);  // 只能这样

// 缺点2：对象内存延迟释放
// 单次分配意味着控制块和对象在同一块内存
// 即使所有shared_ptr都销毁了，只要有weak_ptr存在，
// 控制块不能销毁，对象占用的内存也不能释放

class LargeObject {
    char data[1024 * 1024];  // 1MB
};

auto sp = std::make_shared<LargeObject>();
std::weak_ptr<LargeObject> wp = sp;
sp.reset();  // 对象被销毁（析构函数调用）
// 但1MB内存仍然被控制块"锁定"
// 直到wp也销毁，整块内存才释放

// 分离分配的情况：
std::shared_ptr<LargeObject> sp2(new LargeObject);
std::weak_ptr<LargeObject> wp2 = sp2;
sp2.reset();  // 对象销毁，1MB内存立即释放
// 只有小的控制块内存被wp2锁定

// 缺点3：不能用于不可移动/拷贝的类型的列表初始化
struct Widget { Widget(int, double) {} };
// auto p = std::make_shared<Widget>({1, 2.0});  // 编译错误
auto p = std::make_shared<Widget>(1, 2.0);       // OK
```

##### Day 5-6: shared_ptr的线程安全性

**学习内容**：

1. **三个层次的线程安全**
```cpp
// 层次1：控制块的引用计数操作是线程安全的
std::shared_ptr<int> global_ptr = std::make_shared<int>(42);

void thread1() {
    std::shared_ptr<int> local = global_ptr;  // 安全：原子增加引用计数
}

void thread2() {
    std::shared_ptr<int> local = global_ptr;  // 安全
}

// 层次2：不同shared_ptr实例的并发操作是安全的
std::shared_ptr<int> p1 = std::make_shared<int>(1);
std::shared_ptr<int> p2 = std::make_shared<int>(2);

void thread1() { p1.reset(); }  // 安全
void thread2() { p2.reset(); }  // 安全

// 层次3：同一shared_ptr实例的并发读写是不安全的
std::shared_ptr<int> shared;

void thread1() { shared = std::make_shared<int>(1); }  // 危险！
void thread2() { shared = std::make_shared<int>(2); }  // 竞争条件

// 层次4：指向对象本身的线程安全取决于对象
std::shared_ptr<std::vector<int>> vec_ptr;
void thread1() { vec_ptr->push_back(1); }  // 危险！vector非线程安全
void thread2() { vec_ptr->push_back(2); }  // 需要外部同步
```

2. **原子操作的实现**
```cpp
// GCC libstdc++ 使用原子操作实现引用计数
void _M_add_ref_copy() {
    __gnu_cxx::__atomic_add_dispatch(&_M_use_count, 1);
}

void _M_release() noexcept {
    // memory_order_acq_rel 保证：
    // - 所有之前的写操作完成（release语义）
    // - 之后的读操作看到最新值（acquire语义）
    if (__gnu_cxx::__exchange_and_add_dispatch(&_M_use_count, -1) == 1) {
        _M_dispose();  // 删除对象

        if (__gnu_cxx::__exchange_and_add_dispatch(&_M_weak_count, -1) == 1) {
            _M_destroy();  // 删除控制块
        }
    }
}
```

3. **std::atomic<shared_ptr>（C++20）**
```cpp
// C++20之前，保护shared_ptr需要互斥锁
std::shared_ptr<Config> config;
std::mutex config_mutex;

void update_config(std::shared_ptr<Config> new_config) {
    std::lock_guard<std::mutex> lock(config_mutex);
    config = new_config;
}

std::shared_ptr<Config> get_config() {
    std::lock_guard<std::mutex> lock(config_mutex);
    return config;
}

// C++20：atomic<shared_ptr>
std::atomic<std::shared_ptr<Config>> atomic_config;

void update_config(std::shared_ptr<Config> new_config) {
    atomic_config.store(new_config);
}

std::shared_ptr<Config> get_config() {
    return atomic_config.load();
}
```

##### Day 7: 本周总结与实践

**深入源码阅读**：
```cpp
// 阅读并理解以下关键函数：

// 1. shared_ptr的构造函数
template<typename _Yp>
explicit shared_ptr(_Yp* __p)
    : __shared_ptr<_Tp>(__p) { }

// 问题：为什么是模板？（支持派生类指针）

// 2. 别名构造函数（aliasing constructor）
template<typename _Yp>
shared_ptr(const shared_ptr<_Yp>& __r, element_type* __p) noexcept
    : __shared_ptr<_Tp>(__r, __p) { }

// 用途示例：
struct Owner {
    Member member;
};
auto owner = std::make_shared<Owner>();
// 创建指向member的shared_ptr，但共享owner的控制块
std::shared_ptr<Member> member_ptr(owner, &owner->member);

// 3. enable_shared_from_this的秘密
// 在shared_ptr构造时，检查对象是否继承自enable_shared_from_this
// 如果是，自动初始化_M_weak_this成员
```

**综合练习**：
```cpp
// 扩展mini_shared_ptr，添加以下功能：

// 1. 实现别名构造函数
template <typename U>
mini_shared_ptr(const mini_shared_ptr<U>& other, T* ptr);

// 2. 实现get_deleter
template <typename D, typename T>
D* get_deleter(const mini_shared_ptr<T>& p);

// 3. 添加owner_before（用于在关联容器中比较）
template <typename U>
bool owner_before(const mini_shared_ptr<U>& other) const;
bool owner_before(const mini_weak_ptr<T>& other) const;

// 4. 支持自定义分配器
template <typename T, typename Alloc, typename... Args>
mini_shared_ptr<T> allocate_mini_shared(const Alloc& alloc, Args&&... args);
```

**测试用例**：
```cpp
void test_mini_shared_ptr() {
    // 基本引用计数
    {
        auto p1 = make_mini_shared<int>(42);
        assert(p1.use_count() == 1);

        auto p2 = p1;
        assert(p1.use_count() == 2);
        assert(p2.use_count() == 2);
    }

    // 循环引用检测
    {
        struct Node {
            mini_shared_ptr<Node> next;
            mini_weak_ptr<Node> prev;
            ~Node() { std::cout << "~Node\n"; }
        };

        auto n1 = make_mini_shared<Node>();
        auto n2 = make_mini_shared<Node>();
        n1->next = n2;
        n2->prev = n1;
        // 应该正确销毁，输出两次 ~Node
    }

    // 别名构造
    {
        struct Outer { int inner = 42; };
        auto outer = make_mini_shared<Outer>();
        mini_shared_ptr<int> inner(outer, &outer->inner);

        assert(*inner == 42);
        assert(outer.use_count() == 2);
    }

    std::cout << "All shared_ptr tests passed!\n";
}
```

**本周检验清单**：
- [ ] 理解控制块的设计目的和实现
- [ ] 知道weak_count初始值为1的原因
- [ ] 掌握make_shared的优缺点
- [ ] 理解shared_ptr的三个层次线程安全性
- [ ] 完成mini_shared_ptr的扩展功能

### 第四周：weak_ptr与循环引用

**学习目标**：理解weak_ptr的设计目的和实现

**核心概念**：

#### 循环引用问题
```cpp
struct Node {
    std::shared_ptr<Node> next;
    std::shared_ptr<Node> prev;  // 循环引用！
};

void create_cycle() {
    auto n1 = std::make_shared<Node>();
    auto n2 = std::make_shared<Node>();
    n1->next = n2;
    n2->prev = n1;  // 形成环
    // 函数结束时，n1和n2引用计数都是1，永远不会释放
}

// 解决方案：使用weak_ptr打破循环
struct Node {
    std::shared_ptr<Node> next;
    std::weak_ptr<Node> prev;  // weak不增加引用计数
};
```

#### weak_ptr的实现
```cpp
template<typename _Tp>
class weak_ptr : public __weak_ptr<_Tp> {
    // 和shared_ptr类似，但只持有控制块，不增加strong count
};

// 关键操作
shared_ptr<_Tp> lock() const noexcept {
    // 原子地检查use_count并增加（如果>0）
    return __shared_ptr<_Tp>(*this, std::nothrow);
}

bool expired() const noexcept {
    return _M_refcount._M_get_use_count() == 0;
}
```

**enable_shared_from_this的实现**：
```cpp
template<typename _Tp>
class enable_shared_from_this {
    mutable weak_ptr<_Tp> _M_weak_this;

public:
    shared_ptr<_Tp> shared_from_this() {
        return shared_ptr<_Tp>(this->_M_weak_this);
    }
};

// 当shared_ptr<Derived>创建时，会自动初始化_M_weak_this
// 这通过__enable_shared_from_this_base的友元机制实现
```

---

#### 第四周详细学习计划

##### Day 1-2: weak_ptr的设计动机

**学习内容**：

1. **循环引用的本质**
```cpp
// 为什么循环引用会导致内存泄漏？

struct A {
    std::shared_ptr<B> b_ptr;
    ~A() { std::cout << "~A\n"; }
};

struct B {
    std::shared_ptr<A> a_ptr;
    ~B() { std::cout << "~B\n"; }
};

void create_leak() {
    auto a = std::make_shared<A>();  // a.use_count = 1
    auto b = std::make_shared<B>();  // b.use_count = 1

    a->b_ptr = b;  // b.use_count = 2
    b->a_ptr = a;  // a.use_count = 2

    // 函数结束时：
    // a销毁 -> a.use_count = 1（仍被B持有）
    // b销毁 -> b.use_count = 1（仍被A持有）
    // 两者都不会归零，永远不会释放！
}

// 内存状态图：
//  +---+      +---+
//  | A | ---> | B |
//  +---+ <--- +---+
//    ^           ^
//    |           |
//  a (dead)    b (dead)
//
// A和B互相持有，形成"孤岛"，无法释放
```

2. **weak_ptr如何打破循环**
```cpp
struct A {
    std::shared_ptr<B> b_ptr;
    ~A() { std::cout << "~A\n"; }
};

struct B {
    std::weak_ptr<A> a_ptr;  // 使用weak_ptr！
    ~B() { std::cout << "~B\n"; }
};

void no_leak() {
    auto a = std::make_shared<A>();  // a.use_count = 1
    auto b = std::make_shared<B>();  // b.use_count = 1

    a->b_ptr = b;   // b.use_count = 2
    b->a_ptr = a;   // a.use_count 仍是 1（weak不增加strong计数）

    // 函数结束时：
    // a销毁 -> a.use_count = 0 -> A被删除 -> b.use_count = 1
    // b销毁 -> b.use_count = 0 -> B被删除
    // 输出：~A ~B
}
```

3. **何时使用weak_ptr**
```cpp
// 场景1：打破循环引用（父子关系）
class TreeNode {
    std::vector<std::shared_ptr<TreeNode>> children_;  // 拥有子节点
    std::weak_ptr<TreeNode> parent_;                   // 观察父节点
};

// 场景2：缓存（对象可能被其他地方删除）
class TextureCache {
    std::unordered_map<std::string, std::weak_ptr<Texture>> cache_;

    std::shared_ptr<Texture> get(const std::string& name) {
        auto it = cache_.find(name);
        if (it != cache_.end()) {
            if (auto tex = it->second.lock()) {
                return tex;  // 还活着，返回它
            }
            cache_.erase(it);  // 已死亡，清理
        }
        auto tex = load_texture(name);
        cache_[name] = tex;
        return tex;
    }
};

// 场景3：观察者模式
class Subject {
    std::vector<std::weak_ptr<Observer>> observers_;

    void notify() {
        // 移除已死亡的观察者并通知存活的
        observers_.erase(
            std::remove_if(observers_.begin(), observers_.end(),
                [](const std::weak_ptr<Observer>& wp) {
                    return wp.expired();
                }),
            observers_.end()
        );

        for (auto& wp : observers_) {
            if (auto sp = wp.lock()) {
                sp->onNotify();
            }
        }
    }
};
```

##### Day 3-4: weak_ptr的实现细节

**学习内容**：

1. **weak_ptr与控制块的关系**
```cpp
// weak_ptr的内存布局（和shared_ptr相同）
template <typename T>
class weak_ptr {
    T* ptr_;                    // 指向对象（可能已死亡！）
    control_block_base* ctrl_;  // 指向控制块
};

// weak_ptr只增加weak_count，不增加use_count
// 这意味着：
// - 对象可能在weak_ptr存活期间被删除
// - 控制块会存活直到所有weak_ptr也销毁
```

2. **lock()的实现原理**
```cpp
shared_ptr<T> weak_ptr<T>::lock() const noexcept {
    // 关键问题：如何原子地检查对象是否存活并增加引用计数？

    // 错误实现（竞争条件）：
    // if (ctrl_->use_count > 0) {      // 线程1检查
    //     // 线程2可能在这里将use_count减到0
    //     ctrl_->use_count++;           // 线程1增加 -> BUG!
    // }

    // 正确实现：使用CAS（Compare-And-Swap）
    return shared_ptr<T>(*this, std::nothrow);
}

// 内部实现
bool control_block::try_add_strong_ref() noexcept {
    long count = use_count.load(std::memory_order_relaxed);
    while (count != 0) {
        // 原子地：如果count没变，就增加1
        if (use_count.compare_exchange_weak(
                count, count + 1,
                std::memory_order_acq_rel,
                std::memory_order_relaxed)) {
            return true;  // 成功增加引用
        }
        // count被其他线程改变了，重新读取并重试
    }
    return false;  // 对象已死亡
}
```

3. **expired()的语义**
```cpp
bool weak_ptr<T>::expired() const noexcept {
    return use_count() == 0;
}

// 警告：expired()的结果在返回后可能立即过时！
if (!wp.expired()) {
    // 到这里时，对象可能已经被删除了
    auto sp = wp.lock();  // 仍需检查
}

// 正确用法：直接使用lock()
if (auto sp = wp.lock()) {
    // sp保证对象存活
    sp->doSomething();
}
```

##### Day 5-6: enable_shared_from_this详解

**学习内容**：

1. **问题：从this获取shared_ptr**
```cpp
class Widget {
public:
    void process() {
        // 如何获取指向自己的shared_ptr？

        // 错误方式1：直接构造
        auto sp = std::shared_ptr<Widget>(this);
        // 灾难！创建了新的控制块，导致double delete

        // 错误方式2：存储shared_ptr成员
        // 循环引用！对象永远不会释放
    }
};
```

2. **enable_shared_from_this的魔法**
```cpp
class Widget : public std::enable_shared_from_this<Widget> {
public:
    void process() {
        auto sp = shared_from_this();  // 安全！使用同一个控制块
        do_async_work([sp]() {
            sp->on_complete();
        });
    }
};

// 实现原理
template <typename T>
class enable_shared_from_this {
    mutable weak_ptr<T> weak_this_;

    // shared_ptr的构造函数会调用这个
    friend class shared_ptr<T>;
    void _internal_accept_owner(const shared_ptr<T>* owner) const {
        if (weak_this_.expired()) {
            weak_this_ = *owner;
        }
    }

public:
    shared_ptr<T> shared_from_this() {
        return shared_ptr<T>(weak_this_);  // 从weak_ptr构造
    }

    weak_ptr<T> weak_from_this() noexcept {
        return weak_this_;
    }
};
```

3. **使用enable_shared_from_this的注意事项**
```cpp
// 规则1：对象必须由shared_ptr管理
class Bad : public std::enable_shared_from_this<Bad> {
public:
    void foo() {
        auto sp = shared_from_this();  // 如果对象不是由shared_ptr管理，UB!
    }
};

void example() {
    Bad b;              // 栈上对象
    b.foo();            // 未定义行为！

    Bad* p = new Bad;
    p->foo();           // 未定义行为！必须是shared_ptr

    auto sp = std::make_shared<Bad>();
    sp->foo();          // OK
}

// 规则2：不能在构造函数中调用shared_from_this
class AlsoBad : public std::enable_shared_from_this<AlsoBad> {
public:
    AlsoBad() {
        // shared_ptr还没创建完成，weak_this_还未初始化
        auto sp = shared_from_this();  // 未定义行为！
    }
};

// 规则3：CRTP必须使用正确的类型
class Wrong : public std::enable_shared_from_this<Widget> {  // Widget != Wrong
    // shared_from_this()返回shared_ptr<Widget>，不是shared_ptr<Wrong>
};
```

4. **C++17的改进：weak_from_this**
```cpp
class Widget : public std::enable_shared_from_this<Widget> {
public:
    // C++17: 可以直接获取weak_ptr
    void register_observer() {
        observer_system.add(weak_from_this());  // 不会因this未管理而抛异常
    }

    // 安全检查
    bool is_shared() const {
        return !weak_from_this().expired();
    }
};
```

##### Day 7: 本周总结与项目完成

**综合实践：实现mini_enable_shared_from_this**：
```cpp
template <typename T>
class mini_enable_shared_from_this {
    template <typename U> friend class mini_shared_ptr;

    mutable mini_weak_ptr<T> weak_this_;

    // 被mini_shared_ptr调用
    void _M_weak_assign(T* ptr, const control_block_base* ctrl) const {
        if (weak_this_.ctrl_ == nullptr) {
            weak_this_.ptr_ = ptr;
            weak_this_.ctrl_ = const_cast<control_block_base*>(ctrl);
            weak_this_.ctrl_->add_weak_ref();
        }
    }

public:
    mini_shared_ptr<T> shared_from_this() {
        if (weak_this_.expired()) {
            throw std::bad_weak_ptr();
        }
        return mini_shared_ptr<T>(weak_this_);
    }

    mini_shared_ptr<const T> shared_from_this() const {
        if (weak_this_.expired()) {
            throw std::bad_weak_ptr();
        }
        return mini_shared_ptr<const T>(weak_this_);
    }

    mini_weak_ptr<T> weak_from_this() noexcept {
        return weak_this_;
    }

    mini_weak_ptr<const T> weak_from_this() const noexcept {
        return weak_this_;
    }

protected:
    constexpr mini_enable_shared_from_this() noexcept = default;
    ~mini_enable_shared_from_this() = default;

    mini_enable_shared_from_this(const mini_enable_shared_from_this&) noexcept = default;
    mini_enable_shared_from_this& operator=(const mini_enable_shared_from_this&) noexcept = default;
};

// 修改mini_shared_ptr以支持enable_shared_from_this
template <typename T>
class mini_shared_ptr {
    // ... 之前的代码 ...

    // 在构造函数中检测并初始化enable_shared_from_this
    template <typename U>
    void _M_enable_shared_from_this_with(U* ptr, ...) { }

    template <typename U>
    void _M_enable_shared_from_this_with(
            U* ptr,
            const mini_enable_shared_from_this<U>* enable) {
        if (enable) {
            enable->_M_weak_assign(ptr, ctrl_);
        }
    }

    template <typename U>
    explicit mini_shared_ptr(U* p) : ptr_(p) {
        try {
            ctrl_ = new control_block_ptr<U>(p);
            _M_enable_shared_from_this_with(p, p);  // 检测并初始化
        } catch (...) {
            delete p;
            throw;
        }
    }
};
```

**完整测试套件**：
```cpp
#include <cassert>
#include <iostream>
#include <vector>

void test_all_smart_pointers() {
    std::cout << "=== Testing mini_unique_ptr ===\n";

    // unique_ptr基本功能
    {
        auto p = make_mini_unique<int>(42);
        assert(*p == 42);

        auto p2 = std::move(p);
        assert(!p);
        assert(*p2 == 42);
    }

    // unique_ptr自定义删除器
    {
        int delete_count = 0;
        {
            auto deleter = [&](int* p) { ++delete_count; delete p; };
            mini_unique_ptr<int, decltype(deleter)> p(new int(1), deleter);
        }
        assert(delete_count == 1);
    }

    std::cout << "=== Testing mini_shared_ptr ===\n";

    // shared_ptr引用计数
    {
        auto p1 = make_mini_shared<int>(100);
        assert(p1.use_count() == 1);

        {
            auto p2 = p1;
            assert(p1.use_count() == 2);
            assert(p2.use_count() == 2);
        }

        assert(p1.use_count() == 1);
    }

    // shared_ptr与weak_ptr
    {
        mini_weak_ptr<int> weak;

        {
            auto sp = make_mini_shared<int>(200);
            weak = sp;
            assert(!weak.expired());
            assert(weak.use_count() == 1);

            auto locked = weak.lock();
            assert(*locked == 200);
            assert(weak.use_count() == 2);
        }

        assert(weak.expired());
        auto locked = weak.lock();
        assert(!locked);
    }

    std::cout << "=== Testing circular reference ===\n";

    // 循环引用测试
    {
        static int destroyed = 0;

        struct Node : mini_enable_shared_from_this<Node> {
            mini_shared_ptr<Node> next;
            mini_weak_ptr<Node> prev;
            ~Node() { ++destroyed; }
        };

        destroyed = 0;
        {
            auto n1 = make_mini_shared<Node>();
            auto n2 = make_mini_shared<Node>();
            auto n3 = make_mini_shared<Node>();

            n1->next = n2;
            n2->next = n3;

            n2->prev = n1;
            n3->prev = n2;

            // 测试shared_from_this
            auto n1_copy = n1->shared_from_this();
            assert(n1.use_count() == 2);
        }
        assert(destroyed == 3);  // 所有节点都正确销毁
    }

    std::cout << "=== Testing enable_shared_from_this ===\n";

    // enable_shared_from_this测试
    {
        struct Widget : mini_enable_shared_from_this<Widget> {
            mini_shared_ptr<Widget> get_self() {
                return shared_from_this();
            }
        };

        auto w = make_mini_shared<Widget>();
        auto w2 = w->get_self();
        assert(w.use_count() == 2);
        assert(w.get() == w2.get());
    }

    std::cout << "All tests passed!\n";
}

int main() {
    test_all_smart_pointers();
    return 0;
}
```

**本周检验清单**：
- [ ] 能够解释循环引用的形成和解决方法
- [ ] 理解weak_ptr.lock()的原子性实现
- [ ] 掌握enable_shared_from_this的工作原理和使用限制
- [ ] 完成完整的智能指针库实现
- [ ] 所有测试用例通过

---

## 源码阅读任务

### 深度阅读清单

- [ ] `__shared_ptr` 构造函数的所有重载
- [ ] `make_shared` 的实现（单次分配优化）
- [ ] 原子引用计数操作（`_M_add_ref_lock`等）
- [ ] 数组支持（`shared_ptr<T[]>` C++17）
- [ ] aliasing constructor（别名构造函数）

---

## 实践项目

### 项目：实现完整的智能指针库

**目标**：从零实现 `unique_ptr`、`shared_ptr`、`weak_ptr`

#### Part 1: mini_unique_ptr
```cpp
// mini_unique_ptr.hpp
#include <utility>

template <typename T>
struct default_delete {
    constexpr default_delete() noexcept = default;

    void operator()(T* ptr) const {
        static_assert(sizeof(T) > 0, "Cannot delete incomplete type");
        delete ptr;
    }
};

template <typename T>
struct default_delete<T[]> {
    void operator()(T* ptr) const {
        delete[] ptr;
    }
};

template <typename T, typename Deleter = default_delete<T>>
class mini_unique_ptr {
public:
    using element_type = T;
    using pointer = T*;
    using deleter_type = Deleter;

private:
    pointer ptr_ = nullptr;
    [[no_unique_address]] Deleter deleter_;  // C++20 EBO

public:
    // 构造函数
    constexpr mini_unique_ptr() noexcept = default;
    constexpr mini_unique_ptr(std::nullptr_t) noexcept : ptr_(nullptr) {}
    explicit mini_unique_ptr(pointer p) noexcept : ptr_(p) {}
    mini_unique_ptr(pointer p, const Deleter& d) : ptr_(p), deleter_(d) {}
    mini_unique_ptr(pointer p, Deleter&& d) : ptr_(p), deleter_(std::move(d)) {}

    // 移动构造/赋值
    mini_unique_ptr(mini_unique_ptr&& other) noexcept
        : ptr_(other.release()), deleter_(std::move(other.deleter_)) {}

    mini_unique_ptr& operator=(mini_unique_ptr&& other) noexcept {
        if (this != &other) {
            reset(other.release());
            deleter_ = std::move(other.deleter_);
        }
        return *this;
    }

    // 禁止拷贝
    mini_unique_ptr(const mini_unique_ptr&) = delete;
    mini_unique_ptr& operator=(const mini_unique_ptr&) = delete;

    // 析构
    ~mini_unique_ptr() {
        if (ptr_) deleter_(ptr_);
    }

    // 观察者
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

    void reset(pointer p = nullptr) noexcept {
        pointer old = ptr_;
        ptr_ = p;
        if (old) deleter_(old);
    }

    void swap(mini_unique_ptr& other) noexcept {
        std::swap(ptr_, other.ptr_);
        std::swap(deleter_, other.deleter_);
    }
};

// make_unique 实现
template <typename T, typename... Args>
mini_unique_ptr<T> make_mini_unique(Args&&... args) {
    return mini_unique_ptr<T>(new T(std::forward<Args>(args)...));
}
```

#### Part 2: mini_shared_ptr 和 mini_weak_ptr
```cpp
// mini_shared_ptr.hpp
#include <atomic>
#include <utility>

// 控制块基类
class control_block_base {
public:
    std::atomic<long> strong_count{1};
    std::atomic<long> weak_count{1};  // +1 for strong refs

    virtual void destroy_object() noexcept = 0;
    virtual void destroy_self() noexcept = 0;
    virtual ~control_block_base() = default;

    void add_strong_ref() noexcept {
        strong_count.fetch_add(1, std::memory_order_relaxed);
    }

    void release_strong_ref() noexcept {
        if (strong_count.fetch_sub(1, std::memory_order_acq_rel) == 1) {
            destroy_object();
            release_weak_ref();  // release the +1
        }
    }

    void add_weak_ref() noexcept {
        weak_count.fetch_add(1, std::memory_order_relaxed);
    }

    void release_weak_ref() noexcept {
        if (weak_count.fetch_sub(1, std::memory_order_acq_rel) == 1) {
            destroy_self();
        }
    }

    long use_count() const noexcept {
        return strong_count.load(std::memory_order_relaxed);
    }

    bool try_add_strong_ref() noexcept {
        long count = strong_count.load(std::memory_order_relaxed);
        while (count != 0) {
            if (strong_count.compare_exchange_weak(count, count + 1,
                    std::memory_order_acq_rel, std::memory_order_relaxed)) {
                return true;
            }
        }
        return false;
    }
};

// 标准控制块（分离分配）
template <typename T, typename Deleter = std::default_delete<T>>
class control_block_ptr : public control_block_base {
    T* ptr_;
    Deleter deleter_;
public:
    control_block_ptr(T* p, Deleter d = Deleter())
        : ptr_(p), deleter_(std::move(d)) {}

    void destroy_object() noexcept override {
        deleter_(ptr_);
    }

    void destroy_self() noexcept override {
        delete this;
    }
};

// make_shared控制块（单次分配）
template <typename T>
class control_block_inplace : public control_block_base {
    alignas(T) unsigned char storage_[sizeof(T)];
public:
    template <typename... Args>
    control_block_inplace(Args&&... args) {
        new (storage_) T(std::forward<Args>(args)...);
    }

    T* get_ptr() noexcept {
        return reinterpret_cast<T*>(storage_);
    }

    void destroy_object() noexcept override {
        get_ptr()->~T();
    }

    void destroy_self() noexcept override {
        delete this;
    }
};

// 前向声明
template <typename T> class mini_weak_ptr;

template <typename T>
class mini_shared_ptr {
    template <typename U> friend class mini_shared_ptr;
    template <typename U> friend class mini_weak_ptr;

    T* ptr_ = nullptr;
    control_block_base* ctrl_ = nullptr;

public:
    // 构造函数
    constexpr mini_shared_ptr() noexcept = default;
    constexpr mini_shared_ptr(std::nullptr_t) noexcept {}

    template <typename U>
    explicit mini_shared_ptr(U* p) : ptr_(p) {
        try {
            ctrl_ = new control_block_ptr<U>(p);
        } catch (...) {
            delete p;
            throw;
        }
    }

    // 拷贝
    mini_shared_ptr(const mini_shared_ptr& other) noexcept
        : ptr_(other.ptr_), ctrl_(other.ctrl_) {
        if (ctrl_) ctrl_->add_strong_ref();
    }

    // 移动
    mini_shared_ptr(mini_shared_ptr&& other) noexcept
        : ptr_(other.ptr_), ctrl_(other.ctrl_) {
        other.ptr_ = nullptr;
        other.ctrl_ = nullptr;
    }

    // 从weak_ptr构造
    explicit mini_shared_ptr(const mini_weak_ptr<T>& weak);

    ~mini_shared_ptr() {
        if (ctrl_) ctrl_->release_strong_ref();
    }

    // 赋值
    mini_shared_ptr& operator=(const mini_shared_ptr& other) noexcept {
        mini_shared_ptr(other).swap(*this);
        return *this;
    }

    mini_shared_ptr& operator=(mini_shared_ptr&& other) noexcept {
        mini_shared_ptr(std::move(other)).swap(*this);
        return *this;
    }

    // 观察者
    T* get() const noexcept { return ptr_; }
    long use_count() const noexcept { return ctrl_ ? ctrl_->use_count() : 0; }
    explicit operator bool() const noexcept { return ptr_ != nullptr; }

    T& operator*() const { return *ptr_; }
    T* operator->() const noexcept { return ptr_; }

    void reset() noexcept { mini_shared_ptr().swap(*this); }

    void swap(mini_shared_ptr& other) noexcept {
        std::swap(ptr_, other.ptr_);
        std::swap(ctrl_, other.ctrl_);
    }

private:
    // 用于make_shared
    mini_shared_ptr(T* p, control_block_base* c) : ptr_(p), ctrl_(c) {}

    template <typename U, typename... Args>
    friend mini_shared_ptr<U> make_mini_shared(Args&&...);
};

template <typename T>
class mini_weak_ptr {
    template <typename U> friend class mini_shared_ptr;
    template <typename U> friend class mini_weak_ptr;

    T* ptr_ = nullptr;
    control_block_base* ctrl_ = nullptr;

public:
    constexpr mini_weak_ptr() noexcept = default;

    mini_weak_ptr(const mini_shared_ptr<T>& sp) noexcept
        : ptr_(sp.ptr_), ctrl_(sp.ctrl_) {
        if (ctrl_) ctrl_->add_weak_ref();
    }

    mini_weak_ptr(const mini_weak_ptr& other) noexcept
        : ptr_(other.ptr_), ctrl_(other.ctrl_) {
        if (ctrl_) ctrl_->add_weak_ref();
    }

    mini_weak_ptr(mini_weak_ptr&& other) noexcept
        : ptr_(other.ptr_), ctrl_(other.ctrl_) {
        other.ptr_ = nullptr;
        other.ctrl_ = nullptr;
    }

    ~mini_weak_ptr() {
        if (ctrl_) ctrl_->release_weak_ref();
    }

    mini_weak_ptr& operator=(const mini_weak_ptr& other) noexcept {
        mini_weak_ptr(other).swap(*this);
        return *this;
    }

    mini_weak_ptr& operator=(mini_weak_ptr&& other) noexcept {
        mini_weak_ptr(std::move(other)).swap(*this);
        return *this;
    }

    mini_weak_ptr& operator=(const mini_shared_ptr<T>& sp) noexcept {
        mini_weak_ptr(sp).swap(*this);
        return *this;
    }

    long use_count() const noexcept { return ctrl_ ? ctrl_->use_count() : 0; }
    bool expired() const noexcept { return use_count() == 0; }

    mini_shared_ptr<T> lock() const noexcept {
        if (ctrl_ && ctrl_->try_add_strong_ref()) {
            mini_shared_ptr<T> sp;
            sp.ptr_ = ptr_;
            sp.ctrl_ = ctrl_;
            return sp;
        }
        return mini_shared_ptr<T>();
    }

    void reset() noexcept { mini_weak_ptr().swap(*this); }

    void swap(mini_weak_ptr& other) noexcept {
        std::swap(ptr_, other.ptr_);
        std::swap(ctrl_, other.ctrl_);
    }
};

// mini_shared_ptr从weak_ptr构造的实现
template <typename T>
mini_shared_ptr<T>::mini_shared_ptr(const mini_weak_ptr<T>& weak) {
    if (weak.ctrl_ && weak.ctrl_->try_add_strong_ref()) {
        ptr_ = weak.ptr_;
        ctrl_ = weak.ctrl_;
    } else {
        throw std::bad_weak_ptr();
    }
}

// make_shared实现
template <typename T, typename... Args>
mini_shared_ptr<T> make_mini_shared(Args&&... args) {
    auto* ctrl = new control_block_inplace<T>(std::forward<Args>(args)...);
    return mini_shared_ptr<T>(ctrl->get_ptr(), ctrl);
}
```

---

## 检验标准

### 知识检验

#### 第一周：RAII与所有权
- [ ] 解释RAII如何保证异常安全（给出代码示例）
- [ ] Rule of 0/3/5分别是什么？各自适用于什么场景？
- [ ] 独占所有权、共享所有权、观察者模式的区别和选择依据
- [ ] 函数参数应该用智能指针还是原始引用？如何决定？

#### 第二周：unique_ptr
- [ ] unique_ptr如何实现零开销抽象？（EBO/[[no_unique_address]]）
- [ ] release()、reset()、swap()的语义区别
- [ ] 自定义删除器如何影响unique_ptr的大小？
- [ ] 为什么unique_ptr禁止拷贝但允许移动？

#### 第三周：shared_ptr
- [ ] shared_ptr的控制块包含什么？
- [ ] 为什么weak_count初始值是1？
- [ ] make_shared比直接构造shared_ptr有什么优势和劣势？
- [ ] shared_ptr的线程安全性是什么级别？

#### 第四周：weak_ptr与循环引用
- [ ] 循环引用是如何形成的？weak_ptr如何打破？
- [ ] lock()如何保证原子性？
- [ ] enable_shared_from_this的工作原理和使用限制
- [ ] expired()返回false后，对象是否一定存活？

### 实践检验

#### 代码实现要求
- [ ] mini_unique_ptr
  - 基本功能（构造、移动、解引用）
  - 支持自定义删除器
  - 支持数组类型特化
  - 使用[[no_unique_address]]优化（C++20）或EBO

- [ ] mini_shared_ptr
  - 正确处理引用计数
  - 支持自定义删除器
  - 实现make_shared单次分配优化
  - 支持别名构造函数
  - 线程安全的引用计数操作

- [ ] mini_weak_ptr
  - lock()在对象销毁后返回空
  - lock()的原子性实现（使用CAS）
  - expired()正确判断对象存活状态

- [ ] mini_enable_shared_from_this
  - shared_from_this()正确返回指向自己的shared_ptr
  - weak_from_this()支持
  - CRTP模式正确实现

#### 测试要求
- [ ] 所有基本功能测试通过
- [ ] 循环引用场景测试通过
- [ ] 内存泄漏检测（使用valgrind或AddressSanitizer）
- [ ] 线程安全测试（多线程并发读写）

### 输出物
1. `mini_unique_ptr.hpp` - 完整的unique_ptr实现
2. `mini_shared_ptr.hpp` - 完整的shared_ptr和weak_ptr实现
3. `mini_enable_shared_from_this.hpp` - enable_shared_from_this实现
4. `test_smart_pointers.cpp` - 完整测试套件
5. `notes/month04_smart_pointers.md` - 学习笔记，包含：
   - RAII原理总结
   - 源码分析心得
   - 实现中遇到的问题和解决方案
   - 性能测试结果

### 进阶挑战（可选）
- [ ] 实现intrusive_ptr（侵入式引用计数智能指针）
- [ ] 为mini_shared_ptr添加自定义分配器支持
- [ ] 实现共享数组：shared_ptr<T[]>的完整支持
- [ ] 对比不同内存序对性能的影响（relaxed vs acq_rel）

---

## 时间分配（140小时/月）

### 按周分配

| 周次 | 主题 | 理论 | 源码 | 实践 | 总计 |
|------|------|------|------|------|------|
| 第一周 | RAII与所有权语义 | 8h | 6h | 6h | 20h |
| 第二周 | unique_ptr深入 | 6h | 10h | 14h | 30h |
| 第三周 | shared_ptr与控制块 | 8h | 12h | 20h | 40h |
| 第四周 | weak_ptr与循环引用 | 6h | 8h | 16h | 30h |
| 缓冲 | 复习、测试、文档 | 2h | 4h | 14h | 20h |
| **总计** | | **30h** | **40h** | **70h** | **140h** |

### 按活动分配

| 活动类型 | 时间 | 占比 | 说明 |
|----------|------|------|------|
| 理论学习 | 30h | 21% | 书籍、演讲、博客阅读 |
| 源码阅读 | 40h | 29% | GCC libstdc++源码分析 |
| 代码实现 | 50h | 36% | mini智能指针库开发 |
| 测试调试 | 12h | 9% | 单元测试、内存检测 |
| 文档笔记 | 8h | 5% | 学习笔记、代码注释 |

### 每日建议安排（每天5小时学习）

```
周一至周五：
├── 早晨 (1.5h): 理论学习/源码阅读
├── 下午 (2h): 代码实现
└── 晚上 (1.5h): 测试调试/笔记整理

周末：
├── 上午 (3h): 集中实践
├── 下午 (2h): 复习总结
└── 休息调整
```

### 里程碑检查点

| 时间点 | 检查内容 | 验收标准 |
|--------|----------|----------|
| 第7天 | RAII理解 | 能独立实现lock_guard和scope_exit |
| 第14天 | unique_ptr | mini_unique_ptr通过基本测试 |
| 第21天 | shared_ptr | mini_shared_ptr引用计数正确 |
| 第28天 | 完整实现 | 所有测试通过，无内存泄漏 |

---

## 推荐资源

### 书籍
- 《Effective Modern C++》Scott Meyers - Item 18-22
- 《C++ Primer》第5版 - 第12章动态内存
- 《深入理解C++11》- 智能指针章节

### 视频
- CppCon 2019: "Back to Basics: Smart Pointers" - Arthur O'Dwyer
- CppCon 2019: "Back to Basics: RAII and the Rule of Zero" - Arthur O'Dwyer
- CppCon 2017: "Practical C++17" - Jason Turner（智能指针部分）

### 博客和文章
- Herb Sutter's GotW #89, #91: Smart Pointers
- cppreference.com - 智能指针详细文档
- Abseil C++ Tips - Smart Pointers最佳实践

### 源码参考
- GCC libstdc++: `bits/unique_ptr.h`, `bits/shared_ptr_base.h`
- LLVM libc++: `memory` 头文件
- Boost: `boost/smart_ptr/` 目录

---

## 常见问题与解答

### Q1: 什么时候应该使用shared_ptr而不是unique_ptr？

**答**：默认使用unique_ptr，只在以下情况使用shared_ptr：
1. 多个对象确实需要共同拥有同一资源
2. 无法在编译时确定哪个对象最后使用资源
3. 需要从回调或异步操作中延长对象生命周期

### Q2: make_shared和make_unique为什么推荐使用？

**答**：
- 异常安全：单个表达式完成分配和构造
- 代码简洁：避免重复类型名
- 性能优势（仅make_shared）：单次分配控制块和对象

### Q3: 为什么不应该用shared_ptr管理数组？

**答**：C++17之前，shared_ptr<T[]>不被支持。即使C++17支持后：
- make_shared<T[]>(n)语法直到C++20才支持
- std::vector或std::array通常是更好的选择
- 如果确实需要，考虑unique_ptr<T[]>

### Q4: enable_shared_from_this有什么陷阱？

**答**：
1. 对象必须由shared_ptr管理，栈对象或裸指针会UB
2. 不能在构造函数中调用shared_from_this
3. CRTP类型必须正确（class A : enable_shared_from_this<A>）

---

## 下月预告

Month 05将进入**模板元编程基础**，学习SFINAE、type_traits、constexpr等编译期计算技术，为理解现代C++库的实现打下基础。

主要内容预览：
- SFINAE原理与应用
- std::enable_if和std::void_t
- type_traits库的实现
- constexpr函数和编译期计算
- 实践项目：实现type_traits子集
