# Month 20: Actor模型与消息传递——另一种并发范式

## 本月主题概述

Actor模型是一种与共享内存截然不同的并发编程范式。每个Actor有自己的状态，只通过消息与其他Actor通信，从根本上避免了数据竞争。本月将深入学习Actor模型的理论基础，实现一个功能完整的Actor框架，并掌握常用的消息传递模式。

**为什么学习Actor模型？**
- 天然避免数据竞争：无共享状态意味着无需锁
- 高度可扩展：Actor可以分布在多台机器上
- 容错性强：监督树机制支持优雅的错误恢复
- 概念简洁：Actor + 消息 = 并发系统

**Actor模型 vs 共享内存**：
```
共享内存模型：                     Actor模型：
┌─────────────────────┐            ┌─────────────────────┐
│    Shared State     │            │  Actor A            │
│    ┌─────────┐      │            │  ┌─────────┐        │
│    │  Data   │      │            │  │ State A │        │
│    └────┬────┘      │            │  └─────────┘        │
│         │ Lock      │            │       │ msg         │
│    ┌────┴────┐      │            │       ▼             │
│   T1   T2   T3      │            │  ┌─────────┐        │
└─────────────────────┘            │  │ Mailbox │        │
                                   │  └─────────┘        │
竞态条件、死锁风险                 └─────────────────────┘
                                           │
                                   ┌───────┴───────┐
                                   ▼               ▼
                               Actor B         Actor C
                               无共享，无锁
```

---

## 学习目标与验收标准

| 目标编号 | 学习目标 | 验收标准 |
|---------|---------|---------|
| W1-G1 | 理解Actor模型核心概念 | 能解释Actor、Mailbox、消息传递的关系 |
| W1-G2 | 对比Actor与CSP模型 | 能说明两种模型的异同 |
| W1-G3 | 实现基础Actor框架 | 完成消息发送和接收功能 |
| W2-G1 | 理解Actor引用机制 | 实现位置透明的Actor寻址 |
| W2-G2 | 掌握监督树设计 | 实现基本的监督策略 |
| W2-G3 | 管理Actor生命周期 | 正确处理创建、停止、重启 |
| W3-G1 | 实现Ask模式 | 支持请求-响应的同步调用 |
| W3-G2 | 实现消息路由 | 支持多种路由策略 |
| W3-G3 | 实现FSM Actor | 使用Actor实现有限状态机 |
| W4-G1 | 设计Actor调度器 | 实现高效的任务调度 |
| W4-G2 | 实现背压机制 | 防止Mailbox溢出 |
| W4-G3 | 完成实战项目 | 实现分布式计算示例 |

---

## 理论学习内容

### 第一周：Actor模型基础

**学习目标**：深入理解Actor模型的理论基础，实现基础Actor框架

**阅读材料**：
- [ ] 论文：Carl Hewitt "A Universal Modular Actor Formalism for Artificial Intelligence" (1973)
- [ ] 《Programming Erlang》第1-5章
- [ ] Akka官方文档：Actor模型概念
- [ ] 博客：Joe Armstrong "A History of Erlang"

---

#### 📅 Day 1-2: Actor模型理论基础（10小时）

**Day 1 上午（2.5小时）- Actor模型历史与哲学**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 历史背景 | 学习Actor模型的起源（1973年MIT） |
| 1:00-2:00 | 核心公理 | 理解Actor的三个基本能力 |
| 2:00-2:30 | 设计哲学 | 理解"一切皆Actor"的思想 |

**核心概念：Actor的三个基本能力**
```cpp
/*
Actor模型的三条公理（Carl Hewitt, 1973）

当Actor收到消息时，它可以：

1. 发送有限数量的消息给其他Actor
   - 异步、非阻塞
   - 消息传递是唯一的通信方式

2. 创建有限数量的新Actor
   - Actor可以动态创建子Actor
   - 形成层次结构

3. 指定下一条消息到来时的行为
   - Actor可以改变自己的状态
   - 行为切换是状态机的基础

关键特性：
- 封装性：状态完全私有
- 异步性：消息发送不等待响应
- 位置透明：不关心Actor在哪里运行
*/
```

**Day 1 下午（2.5小时）- Actor vs 其他并发模型**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | vs 线程+锁 | 对比传统共享内存模型 |
| 1:00-2:00 | vs CSP | 对比Go语言的Channel模型 |
| 2:00-2:30 | 适用场景 | 分析各模型的最佳应用场景 |

**核心概念：Actor vs CSP**
```cpp
/*
Actor模型 vs CSP（Communicating Sequential Processes）

┌─────────────────┬─────────────────┬─────────────────┐
│                 │ Actor模型       │ CSP模型         │
├─────────────────┼─────────────────┼─────────────────┤
│ 代表语言        │ Erlang, Akka    │ Go, Rust        │
│ 通信对象        │ Actor（进程）   │ Channel（管道） │
│ 消息发送        │ 异步（fire&forget）│ 可同步可异步   │
│ 身份标识        │ 有（Actor地址） │ 无（匿名端点）  │
│ 消息路由        │ 点对点          │ 任意对任意      │
│ 缓冲            │ Mailbox有缓冲   │ Channel可配置   │
│ 错误处理        │ 监督树          │ 需手动处理      │
└─────────────────┴─────────────────┴─────────────────┘

Actor模型：
┌────────┐  msg   ┌────────┐
│ Actor1 │───────▶│ Actor2 │
└────────┘        └────────┘
消息发送到目标Actor的Mailbox

CSP模型：
┌────────┐        ┌─────────┐        ┌────────┐
│ Proc1  │───────▶│ Channel │◀───────│ Proc2  │
└────────┘        └─────────┘        └────────┘
进程通过共享的Channel通信
*/
```

**Day 2 上午（2.5小时）- Erlang的Actor实现研究**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | Erlang进程模型 | 学习Erlang轻量级进程的设计 |
| 1:30-2:30 | OTP框架 | 了解gen_server、supervisor等行为模式 |

**Erlang示例**：
```erlang
%% Erlang Actor（进程）示例
-module(counter).
-export([start/0, increment/1, get/1]).

%% 启动Actor
start() ->
    spawn(fun() -> loop(0) end).

%% 消息处理循环
loop(Count) ->
    receive
        {increment, From} ->
            From ! {ok, Count + 1},
            loop(Count + 1);
        {get, From} ->
            From ! {ok, Count},
            loop(Count);
        stop ->
            ok
    end.

%% 客户端API
increment(Pid) ->
    Pid ! {increment, self()},
    receive {ok, NewCount} -> NewCount end.

get(Pid) ->
    Pid ! {get, self()},
    receive {ok, Count} -> Count end.
```

**Day 2 下午（2.5小时）- Akka设计研究**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | Akka Actor系统 | 学习Akka的Actor层次结构 |
| 1:30-2:30 | 消息协议 | 理解Akka的消息传递机制 |

**Akka设计亮点**：
```
Akka Actor层次结构：

                    /user（用户守护者）
                        │
            ┌───────────┼───────────┐
            │           │           │
        /myActor1   /myActor2   /myActor3
            │
    ┌───────┴───────┐
    │               │
/child1         /child2

特点：
1. 层次化监督：父Actor监督子Actor
2. 位置透明：ActorRef可指向本地或远程
3. 至少一次/至多一次/精确一次投递语义
```

**Day 1-2 检验标准**：
- [ ] 能解释Actor模型的三条公理
- [ ] 能对比Actor模型与CSP模型的差异
- [ ] 理解Erlang和Akka的设计理念
- [ ] 能画出Actor系统的层次结构图

**今日输出物**：
- [ ] 笔记：`notes/week1/day1-2_actor_theory.md`

---

#### 📅 Day 3-4: 消息传递与Mailbox设计（10小时）

**Day 3 上午（2.5小时）- 消息设计**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:00 | 消息类型 | 设计类型安全的消息系统 |
| 1:00-2:00 | 消息序列化 | 考虑消息的可序列化性 |
| 2:00-2:30 | 消息不可变性 | 理解为什么消息应该不可变 |

**核心概念：消息设计原则**
```cpp
/*
消息设计的关键原则：

1. 不可变性（Immutability）
   - 消息一旦创建就不能修改
   - 避免发送后被意外修改

2. 自包含性（Self-contained）
   - 消息包含处理所需的所有信息
   - 不依赖共享状态

3. 可序列化（Serializable）
   - 支持跨进程/网络传输
   - 为分布式做准备

4. 类型安全（Type-safe）
   - 编译期检查消息类型
   - 减少运行时错误
*/
```

**动手实验 1-1：消息类型设计**
```cpp
// message.hpp
#pragma once
#include <variant>
#include <string>
#include <memory>
#include <any>

// 方式1：使用std::any（灵活但不安全）
using DynamicMessage = std::any;

// 方式2：使用std::variant（类型安全）
namespace msg {
    // 定义消息类型
    struct Ping { int seq; };
    struct Pong { int seq; };
    struct Stop {};
    struct GetCount {};
    struct CountResult { int count; };

    // 消息变体
    using Message = std::variant<Ping, Pong, Stop, GetCount, CountResult>;
}

// 方式3：使用继承（面向对象风格）
class MessageBase {
public:
    virtual ~MessageBase() = default;
    virtual std::unique_ptr<MessageBase> clone() const = 0;
};

template <typename T>
class TypedMessage : public MessageBase {
    T data_;
public:
    explicit TypedMessage(T data) : data_(std::move(data)) {}
    const T& data() const { return data_; }
    std::unique_ptr<MessageBase> clone() const override {
        return std::make_unique<TypedMessage<T>>(data_);
    }
};
```

**Day 3 下午（2.5小时）- Mailbox实现**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 基础Mailbox | 实现线程安全的消息队列 |
| 1:30-2:30 | 优先级Mailbox | 支持系统消息优先处理 |

**动手实验 1-2：Mailbox实现**
```cpp
// mailbox.hpp
#pragma once
#include <queue>
#include <mutex>
#include <condition_variable>
#include <optional>
#include <chrono>

template <typename Message>
class Mailbox {
    std::queue<Message> queue_;
    mutable std::mutex mutex_;
    std::condition_variable cv_;
    bool closed_ = false;

public:
    // 发送消息（非阻塞）
    bool enqueue(Message msg) {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            if (closed_) return false;
            queue_.push(std::move(msg));
        }
        cv_.notify_one();
        return true;
    }

    // 接收消息（阻塞）
    std::optional<Message> dequeue() {
        std::unique_lock<std::mutex> lock(mutex_);
        cv_.wait(lock, [this] {
            return !queue_.empty() || closed_;
        });

        if (queue_.empty()) return std::nullopt;

        Message msg = std::move(queue_.front());
        queue_.pop();
        return msg;
    }

    // 带超时的接收
    template <typename Rep, typename Period>
    std::optional<Message> dequeue_for(
        const std::chrono::duration<Rep, Period>& timeout)
    {
        std::unique_lock<std::mutex> lock(mutex_);
        bool got_msg = cv_.wait_for(lock, timeout, [this] {
            return !queue_.empty() || closed_;
        });

        if (!got_msg || queue_.empty()) return std::nullopt;

        Message msg = std::move(queue_.front());
        queue_.pop();
        return msg;
    }

    // 非阻塞尝试接收
    std::optional<Message> try_dequeue() {
        std::lock_guard<std::mutex> lock(mutex_);
        if (queue_.empty()) return std::nullopt;

        Message msg = std::move(queue_.front());
        queue_.pop();
        return msg;
    }

    void close() {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            closed_ = true;
        }
        cv_.notify_all();
    }

    bool is_closed() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return closed_;
    }

    size_t size() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return queue_.size();
    }
};
```

**Day 4 上午（2.5小时）- 优先级Mailbox**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 系统消息优先 | 实现系统消息优先处理 |
| 1:30-2:30 | 多优先级支持 | 支持用户定义的优先级 |

**动手实验 1-3：优先级Mailbox**
```cpp
// priority_mailbox.hpp
#pragma once
#include <queue>
#include <mutex>
#include <condition_variable>
#include <functional>

template <typename Message>
class PriorityMailbox {
public:
    enum class Priority { System = 0, High = 1, Normal = 2, Low = 3 };

private:
    struct PriorityMessage {
        Priority priority;
        uint64_t sequence;
        Message message;

        bool operator>(const PriorityMessage& other) const {
            if (priority != other.priority) {
                return static_cast<int>(priority) >
                       static_cast<int>(other.priority);
            }
            return sequence > other.sequence;
        }
    };

    std::priority_queue<PriorityMessage,
                        std::vector<PriorityMessage>,
                        std::greater<PriorityMessage>> queue_;
    mutable std::mutex mutex_;
    std::condition_variable cv_;
    bool closed_ = false;
    uint64_t sequence_ = 0;

public:
    bool enqueue(Message msg, Priority priority = Priority::Normal) {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            if (closed_) return false;
            queue_.push(PriorityMessage{priority, sequence_++, std::move(msg)});
        }
        cv_.notify_one();
        return true;
    }

    std::optional<Message> dequeue() {
        std::unique_lock<std::mutex> lock(mutex_);
        cv_.wait(lock, [this] { return !queue_.empty() || closed_; });

        if (queue_.empty()) return std::nullopt;

        Message msg = std::move(const_cast<PriorityMessage&>(queue_.top()).message);
        queue_.pop();
        return msg;
    }

    void close() {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            closed_ = true;
        }
        cv_.notify_all();
    }
};
```

**Day 4 下午（2.5小时）- 有界Mailbox与背压**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 有界队列 | 实现容量限制的Mailbox |
| 1:30-2:30 | 溢出策略 | 实现丢弃旧消息/拒绝新消息等策略 |

**动手实验 1-4：有界Mailbox**
```cpp
// bounded_mailbox.hpp
#pragma once
#include <deque>
#include <mutex>
#include <condition_variable>

template <typename Message>
class BoundedMailbox {
public:
    enum class OverflowStrategy {
        DropNewest,    // 丢弃新消息
        DropOldest,    // 丢弃最老消息
        Block          // 阻塞发送者
    };

private:
    std::deque<Message> queue_;
    mutable std::mutex mutex_;
    std::condition_variable not_full_cv_;
    std::condition_variable not_empty_cv_;
    size_t capacity_;
    OverflowStrategy strategy_;
    bool closed_ = false;
    size_t dropped_count_ = 0;

public:
    explicit BoundedMailbox(size_t capacity,
                           OverflowStrategy strategy = OverflowStrategy::DropOldest)
        : capacity_(capacity), strategy_(strategy) {}

    bool enqueue(Message msg) {
        std::unique_lock<std::mutex> lock(mutex_);

        if (closed_) return false;

        if (queue_.size() >= capacity_) {
            switch (strategy_) {
                case OverflowStrategy::DropNewest:
                    ++dropped_count_;
                    return false;

                case OverflowStrategy::DropOldest:
                    queue_.pop_front();
                    ++dropped_count_;
                    break;

                case OverflowStrategy::Block:
                    not_full_cv_.wait(lock, [this] {
                        return queue_.size() < capacity_ || closed_;
                    });
                    if (closed_) return false;
                    break;
            }
        }

        queue_.push_back(std::move(msg));
        not_empty_cv_.notify_one();
        return true;
    }

    std::optional<Message> dequeue() {
        std::unique_lock<std::mutex> lock(mutex_);
        not_empty_cv_.wait(lock, [this] {
            return !queue_.empty() || closed_;
        });

        if (queue_.empty()) return std::nullopt;

        Message msg = std::move(queue_.front());
        queue_.pop_front();
        not_full_cv_.notify_one();
        return msg;
    }

    void close() {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            closed_ = true;
        }
        not_full_cv_.notify_all();
        not_empty_cv_.notify_all();
    }

    size_t dropped_count() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return dropped_count_;
    }
};
```

**Day 3-4 检验标准**：
- [ ] 理解消息设计的关键原则
- [ ] 实现基础Mailbox
- [ ] 实现优先级Mailbox
- [ ] 实现有界Mailbox及溢出策略

**今日输出物**：
- [ ] `message.hpp`
- [ ] `mailbox.hpp`
- [ ] `priority_mailbox.hpp`
- [ ] `bounded_mailbox.hpp`
- [ ] 笔记：`notes/week1/day3-4_mailbox.md`

---

#### 📅 Day 5-6: 基础Actor框架实现（10小时）

**Day 5 上午（2.5小时）- Actor基类设计**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | Actor接口 | 设计Actor的核心接口 |
| 1:30-2:30 | 消息处理 | 设计消息接收和处理机制 |

**动手实验 1-5：基础Actor实现**
```cpp
// actor.hpp
#pragma once
#include <memory>
#include <thread>
#include <atomic>
#include <functional>
#include <any>
#include "mailbox.hpp"

class Actor;
using ActorRef = std::shared_ptr<Actor>;

// 消息封装：包含发送者信息
struct Envelope {
    ActorRef sender;
    std::any message;

    template <typename T>
    Envelope(ActorRef s, T&& msg)
        : sender(std::move(s)), message(std::forward<T>(msg)) {}
};

class Actor : public std::enable_shared_from_this<Actor> {
    Mailbox<Envelope> mailbox_;
    std::thread thread_;
    std::atomic<bool> running_{false};
    std::atomic<bool> started_{false};

protected:
    // 子类实现：处理消息
    virtual void on_receive(ActorRef sender, const std::any& message) = 0;

    // 可选：生命周期钩子
    virtual void pre_start() {}
    virtual void post_stop() {}
    virtual void pre_restart(const std::exception& reason) {}
    virtual void post_restart() {}

    // 获取自身引用
    ActorRef self() { return shared_from_this(); }

    // 消息处理循环
    void run() {
        pre_start();

        while (running_) {
            auto envelope = mailbox_.dequeue();
            if (!envelope) break;

            try {
                on_receive(envelope->sender, envelope->message);
            } catch (const std::exception& e) {
                // 错误处理（后续会加入监督机制）
                handle_error(e);
            }
        }

        post_stop();
    }

    virtual void handle_error(const std::exception& e) {
        // 默认：记录错误并继续
    }

public:
    Actor() = default;

    virtual ~Actor() {
        stop();
    }

    // 禁止拷贝
    Actor(const Actor&) = delete;
    Actor& operator=(const Actor&) = delete;

    // 启动Actor
    void start() {
        if (started_.exchange(true)) return;  // 防止重复启动
        running_ = true;
        thread_ = std::thread(&Actor::run, this);
    }

    // 停止Actor
    void stop() {
        if (!running_.exchange(false)) return;
        mailbox_.close();
        if (thread_.joinable()) {
            thread_.join();
        }
    }

    bool is_running() const { return running_; }

    // 发送消息
    template <typename T>
    void tell(T&& message, ActorRef sender = nullptr) {
        mailbox_.enqueue(Envelope{sender, std::forward<T>(message)});
    }

    // 操作符重载：actor << message
    template <typename T>
    Actor& operator<<(T&& message) {
        tell(std::forward<T>(message));
        return *this;
    }

    // 静态工厂方法
    template <typename T, typename... Args>
    static ActorRef create(Args&&... args) {
        auto actor = std::make_shared<T>(std::forward<Args>(args)...);
        actor->start();
        return actor;
    }
};
```

**Day 5 下午（2.5小时）- 类型安全的消息处理**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 消息匹配 | 实现类型安全的消息匹配机制 |
| 1:30-2:30 | 行为切换 | 实现become/unbecome机制 |

**动手实验 1-6：类型安全Actor**
```cpp
// typed_actor.hpp
#pragma once
#include "actor.hpp"
#include <functional>
#include <unordered_map>
#include <typeindex>
#include <stack>

// 消息处理器类型
template <typename T>
using MessageHandler = std::function<void(ActorRef sender, const T& msg)>;

class TypedActor : public Actor {
    // 消息处理器映射
    std::unordered_map<std::type_index, std::function<void(ActorRef, const std::any&)>>
        handlers_;

    // 行为栈（用于become/unbecome）
    std::stack<decltype(handlers_)> behavior_stack_;

protected:
    // 注册消息处理器
    template <typename T>
    void on(MessageHandler<T> handler) {
        handlers_[std::type_index(typeid(T))] =
            [handler](ActorRef sender, const std::any& msg) {
                handler(sender, std::any_cast<const T&>(msg));
            };
    }

    // 切换行为
    void become(std::function<void()> behavior_setup) {
        behavior_stack_.push(handlers_);
        handlers_.clear();
        behavior_setup();
    }

    // 恢复之前的行为
    void unbecome() {
        if (!behavior_stack_.empty()) {
            handlers_ = std::move(behavior_stack_.top());
            behavior_stack_.pop();
        }
    }

    void on_receive(ActorRef sender, const std::any& message) override {
        auto it = handlers_.find(std::type_index(message.type()));
        if (it != handlers_.end()) {
            it->second(sender, message);
        } else {
            on_unhandled(sender, message);
        }
    }

    // 未处理消息的默认行为
    virtual void on_unhandled(ActorRef sender, const std::any& message) {
        // 默认忽略
    }

public:
    // 子类在构造函数中使用 on<T>() 注册处理器
};

// 使用示例
class CounterActor : public TypedActor {
    int count_ = 0;

public:
    // 消息类型
    struct Increment { int delta = 1; };
    struct Decrement { int delta = 1; };
    struct GetCount {};
    struct CountResult { int count; };

    CounterActor() {
        // 注册消息处理器
        on<Increment>([this](ActorRef sender, const Increment& msg) {
            count_ += msg.delta;
        });

        on<Decrement>([this](ActorRef sender, const Decrement& msg) {
            count_ -= msg.delta;
        });

        on<GetCount>([this](ActorRef sender, const GetCount&) {
            if (sender) {
                sender->tell(CountResult{count_}, self());
            }
        });
    }
};
```

**Day 6 上午（2.5小时）- Behavior切换示例**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 状态切换 | 实现Actor的状态切换示例 |
| 1:30-2:30 | 测试验证 | 编写单元测试 |

**动手实验 1-7：带状态切换的Actor**
```cpp
// light_switch_actor.hpp
#pragma once
#include "typed_actor.hpp"
#include <iostream>

// 灯开关Actor示例
class LightSwitchActor : public TypedActor {
public:
    struct TurnOn {};
    struct TurnOff {};
    struct Toggle {};
    struct GetState {};
    struct State { bool is_on; };

private:
    void setup_off_behavior() {
        on<TurnOn>([this](ActorRef sender, const TurnOn&) {
            std::cout << "Light turned ON\n";
            become([this] { setup_on_behavior(); });
        });

        on<TurnOff>([](ActorRef, const TurnOff&) {
            std::cout << "Light is already OFF\n";
        });

        on<Toggle>([this](ActorRef sender, const Toggle&) {
            tell(TurnOn{}, sender);
        });

        on<GetState>([this](ActorRef sender, const GetState&) {
            if (sender) sender->tell(State{false}, self());
        });
    }

    void setup_on_behavior() {
        on<TurnOn>([](ActorRef, const TurnOn&) {
            std::cout << "Light is already ON\n";
        });

        on<TurnOff>([this](ActorRef sender, const TurnOff&) {
            std::cout << "Light turned OFF\n";
            become([this] { setup_off_behavior(); });
        });

        on<Toggle>([this](ActorRef sender, const Toggle&) {
            tell(TurnOff{}, sender);
        });

        on<GetState>([this](ActorRef sender, const GetState&) {
            if (sender) sender->tell(State{true}, self());
        });
    }

public:
    LightSwitchActor() {
        // 初始状态：关闭
        setup_off_behavior();
    }
};
```

**Day 6 下午（2.5小时）- Ping-Pong示例**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-1:30 | 双Actor通信 | 实现经典的Ping-Pong示例 |
| 1:30-2:30 | 综合测试 | 测试各种消息模式 |

**动手实验 1-8：Ping-Pong示例**
```cpp
// ping_pong.cpp
#include "typed_actor.hpp"
#include <iostream>
#include <chrono>
#include <thread>

struct Ping { int count; };
struct Pong { int count; };
struct Start { int total_rounds; };

class PingActor : public TypedActor {
    ActorRef pong_actor_;
    int total_rounds_ = 0;

public:
    explicit PingActor(ActorRef pong) : pong_actor_(std::move(pong)) {
        on<Start>([this](ActorRef sender, const Start& msg) {
            total_rounds_ = msg.total_rounds;
            std::cout << "Starting " << total_rounds_ << " rounds\n";
            pong_actor_->tell(Ping{1}, self());
        });

        on<Pong>([this](ActorRef sender, const Pong& msg) {
            std::cout << "Ping received Pong #" << msg.count << "\n";
            if (msg.count < total_rounds_) {
                std::this_thread::sleep_for(std::chrono::milliseconds(100));
                sender->tell(Ping{msg.count + 1}, self());
            } else {
                std::cout << "Ping-Pong completed!\n";
            }
        });
    }
};

class PongActor : public TypedActor {
public:
    PongActor() {
        on<Ping>([this](ActorRef sender, const Ping& msg) {
            std::cout << "Pong received Ping #" << msg.count << "\n";
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
            sender->tell(Pong{msg.count}, self());
        });
    }
};

void test_ping_pong() {
    auto pong = Actor::create<PongActor>();
    auto ping = Actor::create<PingActor>(pong);

    ping->tell(Start{5}, nullptr);

    std::this_thread::sleep_for(std::chrono::seconds(2));

    ping->stop();
    pong->stop();
}
```

**Day 5-6 检验标准**：
- [ ] 实现基础Actor类
- [ ] 实现类型安全的消息处理
- [ ] 实现behavior切换（become/unbecome）
- [ ] 完成Ping-Pong示例

**今日输出物**：
- [ ] `actor.hpp`
- [ ] `typed_actor.hpp`
- [ ] `test_actor.cpp`
- [ ] `ping_pong.cpp`
- [ ] 笔记：`notes/week1/day5-6_actor_impl.md`

---

#### 📅 Day 7: 第一周总结与论文阅读（5小时）

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 论文阅读 | 精读Carl Hewitt的Actor模型论文 |
| 2:00-3:30 | 对比分析 | 对比我们的实现与Erlang/Akka |
| 3:30-5:00 | 笔记整理 | 整理本周学习笔记 |

**第一周输出物汇总**：
1. `message.hpp` - 消息类型设计
2. `mailbox.hpp` - 基础Mailbox
3. `priority_mailbox.hpp` - 优先级Mailbox
4. `bounded_mailbox.hpp` - 有界Mailbox
5. `actor.hpp` - 基础Actor
6. `typed_actor.hpp` - 类型安全Actor
7. `test_*.cpp` - 测试文件
8. `notes/week1/` - 本周笔记

---

### 第二周：Actor系统架构

**学习目标**：构建完整的Actor系统，包括监督机制和生命周期管理

**阅读材料**：
- [ ] Akka文档：Actor Systems & Supervision
- [ ] 《Programming Erlang》第12章：Error Handling
- [ ] Joe Armstrong博士论文：Making reliable distributed systems

---

#### 📅 Day 1-2: Actor引用与地址系统（10小时）

**Day 1（5小时）- ActorRef设计**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 引用设计 | 设计位置透明的ActorRef |
| 2:00-3:30 | 地址系统 | 实现Actor路径和地址解析 |
| 3:30-5:00 | 死信处理 | 处理发送给已停止Actor的消息 |

**核心概念：Actor地址系统**
```
Actor地址层次结构：

akka://system-name/user/parent/child

├── akka://     协议前缀
├── system-name Actor系统名称
├── /user       用户Actor根路径
├── /parent     父Actor名称
└── /child      子Actor名称

本地地址：  akka://my-system/user/worker
远程地址：  akka://my-system@host:port/user/worker
```

**动手实验 2-1：ActorPath与ActorRef**
```cpp
// actor_path.hpp
#pragma once
#include <string>
#include <vector>
#include <sstream>

class ActorPath {
    std::string system_name_;
    std::vector<std::string> elements_;

public:
    ActorPath(std::string system, std::vector<std::string> elements)
        : system_name_(std::move(system)), elements_(std::move(elements)) {}

    // 从字符串解析
    static ActorPath parse(const std::string& path) {
        // 格式: /system/user/parent/child
        std::vector<std::string> elements;
        std::istringstream iss(path);
        std::string segment;

        while (std::getline(iss, segment, '/')) {
            if (!segment.empty()) {
                elements.push_back(segment);
            }
        }

        std::string system = elements.empty() ? "default" : elements[0];
        elements.erase(elements.begin());

        return ActorPath(system, elements);
    }

    // 获取子路径
    ActorPath child(const std::string& name) const {
        auto new_elements = elements_;
        new_elements.push_back(name);
        return ActorPath(system_name_, new_elements);
    }

    // 获取父路径
    ActorPath parent() const {
        if (elements_.empty()) return *this;
        auto new_elements = elements_;
        new_elements.pop_back();
        return ActorPath(system_name_, new_elements);
    }

    std::string name() const {
        return elements_.empty() ? "/" : elements_.back();
    }

    std::string to_string() const {
        std::string result = "/" + system_name_;
        for (const auto& e : elements_) {
            result += "/" + e;
        }
        return result;
    }

    bool operator==(const ActorPath& other) const {
        return system_name_ == other.system_name_ &&
               elements_ == other.elements_;
    }
};

// ActorRef增强版
class ActorRefImpl {
    std::weak_ptr<Actor> actor_;
    ActorPath path_;
    std::function<void(Envelope)> dead_letter_handler_;

public:
    ActorRefImpl(std::shared_ptr<Actor> actor, ActorPath path)
        : actor_(actor), path_(std::move(path)) {}

    template <typename T>
    void tell(T&& message, ActorRef sender = nullptr) {
        if (auto actor = actor_.lock()) {
            actor->tell(std::forward<T>(message), sender);
        } else {
            // 发送到死信
            if (dead_letter_handler_) {
                dead_letter_handler_(Envelope{sender, std::forward<T>(message)});
            }
        }
    }

    const ActorPath& path() const { return path_; }
    bool is_terminated() const { return actor_.expired(); }

    void set_dead_letter_handler(std::function<void(Envelope)> handler) {
        dead_letter_handler_ = std::move(handler);
    }
};
```

**Day 2（5小时）- Actor注册表**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:30 | 注册表实现 | 实现Actor的注册和查找 |
| 2:30-5:00 | 死信Actor | 实现DeadLetter处理 |

**动手实验 2-2：Actor注册表**
```cpp
// actor_registry.hpp
#pragma once
#include <unordered_map>
#include <shared_mutex>
#include "actor_path.hpp"

class ActorRegistry {
    std::unordered_map<std::string, std::weak_ptr<Actor>> actors_;
    mutable std::shared_mutex mutex_;

public:
    void register_actor(const ActorPath& path, std::shared_ptr<Actor> actor) {
        std::unique_lock lock(mutex_);
        actors_[path.to_string()] = actor;
    }

    void unregister_actor(const ActorPath& path) {
        std::unique_lock lock(mutex_);
        actors_.erase(path.to_string());
    }

    std::shared_ptr<Actor> lookup(const ActorPath& path) const {
        std::shared_lock lock(mutex_);
        auto it = actors_.find(path.to_string());
        if (it != actors_.end()) {
            return it->second.lock();
        }
        return nullptr;
    }

    std::shared_ptr<Actor> lookup(const std::string& path_str) const {
        return lookup(ActorPath::parse(path_str));
    }

    // 清理已终止的Actor
    void cleanup() {
        std::unique_lock lock(mutex_);
        for (auto it = actors_.begin(); it != actors_.end();) {
            if (it->second.expired()) {
                it = actors_.erase(it);
            } else {
                ++it;
            }
        }
    }
};
```

**Day 1-2 检验标准**：
- [ ] 实现ActorPath地址系统
- [ ] 实现Actor注册表
- [ ] 实现死信处理

**今日输出物**：
- [ ] `actor_path.hpp`
- [ ] `actor_registry.hpp`
- [ ] 笔记：`notes/week2/day1-2_addressing.md`

---

#### 📅 Day 3-4: 监督树与容错机制（10小时）

**Day 3（5小时）- 监督策略设计**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | "Let it crash" | 理解Erlang的容错哲学 |
| 2:00-3:30 | 监督策略 | 设计Resume/Restart/Stop/Escalate策略 |
| 3:30-5:00 | 策略实现 | 实现基本的监督策略 |

**核心概念：监督策略**
```cpp
/*
Erlang/Akka的监督策略：

┌─────────────────────────────────────────────────────────┐
│                     Supervisor                          │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 监督策略（Supervision Strategy）                │   │
│  │                                                  │   │
│  │ 1. Resume   - 忽略错误，继续处理下一条消息      │   │
│  │ 2. Restart  - 重启Actor，恢复初始状态          │   │
│  │ 3. Stop     - 永久停止Actor                    │   │
│  │ 4. Escalate - 将错误上报给父监督者             │   │
│  └─────────────────────────────────────────────────┘   │
│                         │                               │
│         ┌───────────────┼───────────────┐               │
│         │               │               │               │
│     ┌───┴───┐       ┌───┴───┐       ┌───┴───┐          │
│     │Child 1│       │Child 2│       │Child 3│          │
│     └───────┘       └───────┘       └───────┘          │
└─────────────────────────────────────────────────────────┘

监督模式：
- OneForOne: 只处理失败的子Actor
- AllForOne: 一个失败，全部处理（用于紧耦合的Actor组）
*/
```

**动手实验 2-3：监督策略**
```cpp
// supervision.hpp
#pragma once
#include <functional>
#include <chrono>
#include <stdexcept>

enum class Directive {
    Resume,    // 继续处理
    Restart,   // 重启Actor
    Stop,      // 停止Actor
    Escalate   // 上报给父监督者
};

// 监督策略接口
class SupervisionStrategy {
public:
    virtual ~SupervisionStrategy() = default;
    virtual Directive handle(const std::exception& error) = 0;
};

// 一对一策略
class OneForOneStrategy : public SupervisionStrategy {
    std::function<Directive(const std::exception&)> decider_;
    int max_restarts_;
    std::chrono::seconds within_time_;

    int restart_count_ = 0;
    std::chrono::steady_clock::time_point window_start_;

public:
    OneForOneStrategy(
        std::function<Directive(const std::exception&)> decider,
        int max_restarts = 3,
        std::chrono::seconds within = std::chrono::seconds(60))
        : decider_(std::move(decider))
        , max_restarts_(max_restarts)
        , within_time_(within)
        , window_start_(std::chrono::steady_clock::now()) {}

    Directive handle(const std::exception& error) override {
        auto now = std::chrono::steady_clock::now();

        // 检查是否超出时间窗口
        if (now - window_start_ > within_time_) {
            restart_count_ = 0;
            window_start_ = now;
        }

        Directive directive = decider_(error);

        if (directive == Directive::Restart) {
            ++restart_count_;
            if (restart_count_ > max_restarts_) {
                return Directive::Stop;  // 超过重启次数，停止
            }
        }

        return directive;
    }
};

// 默认决策器
inline Directive default_decider(const std::exception& e) {
    // 根据异常类型决定策略
    if (dynamic_cast<const std::runtime_error*>(&e)) {
        return Directive::Restart;
    }
    if (dynamic_cast<const std::logic_error*>(&e)) {
        return Directive::Stop;
    }
    return Directive::Escalate;
}
```

**Day 4（5小时）- 监督Actor实现**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:30 | 监督Actor | 实现支持监督的Actor基类 |
| 2:30-5:00 | 测试验证 | 测试各种失败场景 |

**动手实验 2-4：监督Actor**
```cpp
// supervisor_actor.hpp
#pragma once
#include "typed_actor.hpp"
#include "supervision.hpp"
#include <unordered_map>

class SupervisorActor : public TypedActor {
public:
    // 子Actor失败通知
    struct ChildFailed {
        ActorRef child;
        std::exception_ptr error;
    };

    // 子Actor终止通知
    struct ChildTerminated {
        ActorRef child;
    };

protected:
    std::unique_ptr<SupervisionStrategy> strategy_;
    std::unordered_map<ActorRef, std::function<ActorRef()>> children_;
    std::unordered_map<ActorRef, ActorRef> child_to_self_;

    void setup_supervision() {
        on<ChildFailed>([this](ActorRef sender, const ChildFailed& msg) {
            handle_child_failure(msg.child, msg.error);
        });

        on<ChildTerminated>([this](ActorRef sender, const ChildTerminated& msg) {
            handle_child_terminated(msg.child);
        });
    }

    void handle_child_failure(ActorRef child, std::exception_ptr eptr) {
        try {
            std::rethrow_exception(eptr);
        } catch (const std::exception& e) {
            Directive directive = strategy_->handle(e);

            switch (directive) {
                case Directive::Resume:
                    // 子Actor继续处理下一条消息
                    break;

                case Directive::Restart:
                    restart_child(child);
                    break;

                case Directive::Stop:
                    stop_child(child);
                    break;

                case Directive::Escalate:
                    // 上报给自己的监督者
                    throw;
            }
        }
    }

    void handle_child_terminated(ActorRef child) {
        children_.erase(child);
    }

    void restart_child(ActorRef child) {
        auto it = children_.find(child);
        if (it == children_.end()) return;

        auto factory = it->second;
        child->stop();

        // 使用工厂函数创建新实例
        auto new_child = factory();
        children_.erase(it);
        children_[new_child] = factory;
    }

    void stop_child(ActorRef child) {
        child->stop();
        children_.erase(child);
    }

public:
    explicit SupervisorActor(std::unique_ptr<SupervisionStrategy> strategy = nullptr)
        : strategy_(strategy ? std::move(strategy)
                             : std::make_unique<OneForOneStrategy>(default_decider)) {
        setup_supervision();
    }

    // 创建子Actor
    template <typename T, typename... Args>
    ActorRef spawn(Args&&... args) {
        auto factory = [args...]() mutable {
            return Actor::create<T>(std::forward<Args>(args)...);
        };

        auto child = factory();
        children_[child] = factory;
        return child;
    }

    // 停止所有子Actor
    void stop_all_children() {
        for (auto& [child, factory] : children_) {
            child->stop();
        }
        children_.clear();
    }
};
```

**Day 3-4 检验标准**：
- [ ] 理解"Let it crash"哲学
- [ ] 实现各种监督策略
- [ ] 实现监督Actor
- [ ] 测试错误处理和重启机制

**今日输出物**：
- [ ] `supervision.hpp`
- [ ] `supervisor_actor.hpp`
- [ ] `test_supervision.cpp`
- [ ] 笔记：`notes/week2/day3-4_supervision.md`

---

#### 📅 Day 5-6: Actor生命周期管理（10小时）

**Day 5（5小时）- 生命周期钩子**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 生命周期状态 | 设计Actor的完整生命周期 |
| 2:00-5:00 | 钩子实现 | 实现preStart/postStop/preRestart/postRestart |

**核心概念：Actor生命周期**
```
Actor生命周期状态图：

                 create()
                    │
                    ▼
              ┌───────────┐
              │  Created  │
              └─────┬─────┘
                    │ start()
                    ▼
              ┌───────────┐    error    ┌───────────┐
              │  Running  │────────────▶│  Failed   │
              └─────┬─────┘             └─────┬─────┘
                    │                         │
                    │ stop()           restart/stop
                    │                         │
                    ▼                         ▼
              ┌───────────┐             ┌───────────┐
              │ Stopping  │             │Restarting │
              └─────┬─────┘             └─────┬─────┘
                    │                         │
                    ▼                         │
              ┌───────────┐                   │
              │ Terminated│◀──────────────────┘
              └───────────┘

生命周期钩子调用顺序：
1. 首次启动: preStart() → 处理消息
2. 重启时: preRestart() → postStop() → 创建新实例 → postRestart() → preStart()
3. 停止时: postStop()
```

**动手实验 2-5：完整生命周期Actor**
```cpp
// lifecycle_actor.hpp
#pragma once
#include "typed_actor.hpp"
#include <atomic>

class LifecycleActor : public TypedActor {
public:
    enum class State {
        Created,
        Starting,
        Running,
        Restarting,
        Stopping,
        Terminated
    };

protected:
    std::atomic<State> state_{State::Created};

    // 生命周期钩子 - 子类可重写
    virtual void pre_start() {
        // 首次启动前调用
    }

    virtual void post_stop() {
        // 停止后调用
    }

    virtual void pre_restart(const std::exception& reason) {
        // 重启前调用（旧实例）
        // 默认：停止所有子Actor
    }

    virtual void post_restart() {
        // 重启后调用（新实例）
        // 默认：调用preStart
        pre_start();
    }

    void handle_error(const std::exception& e) override {
        // 通知监督者
        // 这里简化处理，实际应该发送消息给监督者
        state_ = State::Restarting;
        pre_restart(e);
        // 监督者决定后续操作
    }

public:
    void start() override {
        if (state_ != State::Created && state_ != State::Restarting) return;

        state_ = State::Starting;
        pre_start();
        state_ = State::Running;

        TypedActor::start();
    }

    void stop() override {
        if (state_ == State::Terminated || state_ == State::Stopping) return;

        state_ = State::Stopping;
        TypedActor::stop();
        post_stop();
        state_ = State::Terminated;
    }

    State state() const { return state_.load(); }
    bool is_terminated() const { return state_ == State::Terminated; }
};
```

**Day 6（5小时）- Actor系统整合**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-3:00 | Actor系统 | 实现ActorSystem类 |
| 3:00-5:00 | 测试集成 | 完整的生命周期测试 |

**动手实验 2-6：Actor系统**
```cpp
// actor_system.hpp
#pragma once
#include "lifecycle_actor.hpp"
#include "supervisor_actor.hpp"
#include "actor_registry.hpp"
#include <memory>
#include <string>

class ActorSystem {
    std::string name_;
    ActorRegistry registry_;
    std::shared_ptr<SupervisorActor> guardian_;  // 顶级监督者
    std::atomic<bool> running_{false};

public:
    explicit ActorSystem(std::string name)
        : name_(std::move(name)) {
        // 创建顶级守护Actor
        guardian_ = std::make_shared<SupervisorActor>();
        guardian_->start();
        running_ = true;
    }

    ~ActorSystem() {
        shutdown();
    }

    const std::string& name() const { return name_; }

    // 创建顶级Actor
    template <typename T, typename... Args>
    ActorRef spawn(const std::string& name, Args&&... args) {
        auto actor = guardian_->spawn<T>(std::forward<Args>(args)...);
        auto path = ActorPath(name_, {"user", name});
        registry_.register_actor(path, actor);
        return actor;
    }

    // 查找Actor
    ActorRef lookup(const std::string& path) {
        return registry_.lookup(path);
    }

    // 关闭系统
    void shutdown() {
        if (!running_.exchange(false)) return;

        guardian_->stop_all_children();
        guardian_->stop();
        registry_.cleanup();
    }

    bool is_running() const { return running_; }

    // 等待系统终止
    void await_termination() {
        while (running_) {
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
        }
    }
};

// 使用示例
void actor_system_example() {
    ActorSystem system("my-system");

    // 创建Actor
    auto counter = system.spawn<CounterActor>("counter");
    auto printer = system.spawn<PrinterActor>("printer");

    // 发送消息
    counter->tell(CounterActor::Increment{5}, nullptr);
    counter->tell(CounterActor::GetCount{}, printer);

    // 查找Actor
    auto found = system.lookup("/my-system/user/counter");

    std::this_thread::sleep_for(std::chrono::seconds(1));
    system.shutdown();
}
```

**Day 5-6 检验标准**：
- [ ] 实现完整的Actor生命周期
- [ ] 实现ActorSystem
- [ ] 正确处理启动、停止、重启

**今日输出物**：
- [ ] `lifecycle_actor.hpp`
- [ ] `actor_system.hpp`
- [ ] `test_lifecycle.cpp`
- [ ] 笔记：`notes/week2/day5-6_lifecycle.md`

---

#### 📅 Day 7: 第二周总结（5小时）

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 源码阅读 | 阅读CAF(C++ Actor Framework)源码 |
| 2:00-4:00 | 对比分析 | 对比Erlang OTP和Akka的设计 |
| 4:00-5:00 | 笔记整理 | 整理本周学习笔记 |

**第二周输出物汇总**：
1. `actor_path.hpp` - Actor地址系统
2. `actor_registry.hpp` - Actor注册表
3. `supervision.hpp` - 监督策略
4. `supervisor_actor.hpp` - 监督Actor
5. `lifecycle_actor.hpp` - 生命周期Actor
6. `actor_system.hpp` - Actor系统
7. `test_*.cpp` - 测试文件
8. `notes/week2/` - 本周笔记

---

### 第三周：高级消息模式

**学习目标**：掌握常用的Actor消息模式，实现实用的通信机制

**阅读材料**：
- [ ] Akka文档：Interaction Patterns
- [ ] 《Reactive Messaging Patterns with the Actor Model》
- [ ] 博客：Enterprise Integration Patterns with Actors

---

#### 📅 Day 1-2: 请求-响应模式（Ask Pattern）（10小时）

**Day 1（5小时）- Ask模式设计**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 模式分析 | 理解同步调用在Actor模型中的挑战 |
| 2:00-5:00 | Ask实现 | 实现带超时的请求-响应 |

**核心概念：Ask模式**
```cpp
/*
Ask模式：将异步消息传递转换为类似同步调用的形式

问题：Actor模型是纯异步的，如何实现"发请求等响应"？

解决方案：
1. 创建临时Actor接收响应
2. 返回Future，调用者可等待结果
3. 设置超时，防止无限等待

┌────────┐  ask(Request)  ┌────────┐
│ Caller │───────────────▶│ Target │
└────────┘                └────┬───┘
     │                         │
     │ ┌─────────────────────┐ │
     │ │ Temporary Actor     │ │
     │ │ (holds Promise)     │◀┘
     │ └─────────┬───────────┘
     │           │ response
     ▼           ▼
   Future ◀───────────
*/
```

**动手实验 3-1：Ask模式实现**
```cpp
// ask_pattern.hpp
#pragma once
#include "typed_actor.hpp"
#include <future>
#include <chrono>

template <typename Response>
class AskActor : public TypedActor {
    std::promise<Response> promise_;

public:
    AskActor() {
        on<Response>([this](ActorRef sender, const Response& msg) {
            promise_.set_value(msg);
            stop();  // 收到响应后自动停止
        });
    }

    std::future<Response> get_future() {
        return promise_.get_future();
    }
};

// Ask辅助函数
template <typename Request, typename Response>
std::future<Response> ask(ActorRef target, Request&& request,
                          std::chrono::milliseconds timeout = std::chrono::seconds(5))
{
    auto ask_actor = Actor::create<AskActor<Response>>();
    auto future = static_cast<AskActor<Response>*>(ask_actor.get())->get_future();

    target->tell(std::forward<Request>(request), ask_actor);

    // 启动超时检测
    std::thread([ask_actor, timeout]() {
        std::this_thread::sleep_for(timeout);
        if (ask_actor->is_running()) {
            ask_actor->stop();
        }
    }).detach();

    return future;
}

// 使用示例
void ask_example() {
    auto counter = Actor::create<CounterActor>();

    // 同步方式获取计数
    counter->tell(CounterActor::Increment{10}, nullptr);

    auto future = ask<CounterActor::GetCount, CounterActor::CountResult>(
        counter,
        CounterActor::GetCount{}
    );

    try {
        auto result = future.get();  // 阻塞等待
        std::cout << "Count: " << result.count << "\n";
    } catch (const std::future_error& e) {
        std::cout << "Timeout or error\n";
    }
}
```

**Day 2（5小时）- 管道模式（Pipe Pattern）**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:30 | 管道实现 | 将Future结果发送给另一个Actor |
| 2:30-5:00 | 组合模式 | 实现消息转换和聚合 |

**动手实验 3-2：Pipe模式**
```cpp
// pipe_pattern.hpp
#pragma once
#include "ask_pattern.hpp"

// 将Future结果管道到另一个Actor
template <typename T>
void pipe_to(std::future<T>&& future, ActorRef target, ActorRef sender = nullptr) {
    std::thread([future = std::move(future), target, sender]() mutable {
        try {
            T result = future.get();
            target->tell(std::move(result), sender);
        } catch (const std::exception& e) {
            // 可以发送错误消息
            target->tell(std::string("Error: ") + e.what(), sender);
        }
    }).detach();
}

// 消息转换
template <typename In, typename Out>
class TransformActor : public TypedActor {
    std::function<Out(const In&)> transform_;
    ActorRef target_;

public:
    TransformActor(std::function<Out(const In&)> transform, ActorRef target)
        : transform_(std::move(transform)), target_(std::move(target)) {
        on<In>([this](ActorRef sender, const In& msg) {
            target_->tell(transform_(msg), sender);
        });
    }
};

// 消息聚合
template <typename T, typename Result>
class AggregatorActor : public TypedActor {
    std::vector<T> collected_;
    size_t expected_count_;
    std::function<Result(std::vector<T>)> aggregator_;
    ActorRef reply_to_;

public:
    AggregatorActor(size_t count,
                    std::function<Result(std::vector<T>)> aggregator,
                    ActorRef reply_to)
        : expected_count_(count)
        , aggregator_(std::move(aggregator))
        , reply_to_(std::move(reply_to)) {
        on<T>([this](ActorRef sender, const T& msg) {
            collected_.push_back(msg);
            if (collected_.size() >= expected_count_) {
                reply_to_->tell(aggregator_(collected_), self());
                stop();
            }
        });
    }
};
```

**Day 1-2 检验标准**：
- [ ] 实现Ask模式
- [ ] 实现Pipe模式
- [ ] 实现消息聚合

**今日输出物**：
- [ ] `ask_pattern.hpp`
- [ ] `pipe_pattern.hpp`
- [ ] `test_patterns.cpp`
- [ ] 笔记：`notes/week3/day1-2_ask_pattern.md`

---

#### 📅 Day 3-4: 消息路由与负载均衡（10小时）

**Day 3（5小时）- 路由器设计**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 路由策略 | 设计多种路由策略 |
| 2:00-5:00 | 路由器实现 | 实现Router Actor |

**核心概念：消息路由策略**
```cpp
/*
常见路由策略：

1. RoundRobin（轮询）
   - 依次将消息发送给每个目标
   - 均匀分布负载

2. Random（随机）
   - 随机选择目标
   - 统计上均匀

3. SmallestMailbox（最小邮箱）
   - 发送给队列最短的Actor
   - 需要获取队列状态

4. Broadcast（广播）
   - 发送给所有目标
   - 用于通知场景

5. ConsistentHashing（一致性哈希）
   - 根据消息内容选择目标
   - 保证相同key到同一目标
*/
```

**动手实验 3-3：路由器实现**
```cpp
// router.hpp
#pragma once
#include "typed_actor.hpp"
#include <vector>
#include <random>
#include <functional>

// 路由策略接口
class RoutingStrategy {
public:
    virtual ~RoutingStrategy() = default;
    virtual size_t select(size_t routee_count, const std::any& message) = 0;
};

// 轮询策略
class RoundRobinStrategy : public RoutingStrategy {
    std::atomic<size_t> current_{0};
public:
    size_t select(size_t routee_count, const std::any&) override {
        return current_.fetch_add(1) % routee_count;
    }
};

// 随机策略
class RandomStrategy : public RoutingStrategy {
    std::mt19937 rng_{std::random_device{}()};
public:
    size_t select(size_t routee_count, const std::any&) override {
        std::uniform_int_distribution<size_t> dist(0, routee_count - 1);
        return dist(rng_);
    }
};

// 一致性哈希策略
class ConsistentHashStrategy : public RoutingStrategy {
    std::function<size_t(const std::any&)> hasher_;
public:
    explicit ConsistentHashStrategy(std::function<size_t(const std::any&)> hasher)
        : hasher_(std::move(hasher)) {}

    size_t select(size_t routee_count, const std::any& message) override {
        return hasher_(message) % routee_count;
    }
};

// 路由器Actor
class RouterActor : public TypedActor {
    std::vector<ActorRef> routees_;
    std::unique_ptr<RoutingStrategy> strategy_;

public:
    // 添加/移除路由
    struct AddRoutee { ActorRef routee; };
    struct RemoveRoutee { ActorRef routee; };

    // 广播消息
    template <typename T>
    struct Broadcast { T message; };

    RouterActor(std::vector<ActorRef> routees,
                std::unique_ptr<RoutingStrategy> strategy)
        : routees_(std::move(routees))
        , strategy_(std::move(strategy)) {

        on<AddRoutee>([this](ActorRef, const AddRoutee& msg) {
            routees_.push_back(msg.routee);
        });

        on<RemoveRoutee>([this](ActorRef, const RemoveRoutee& msg) {
            routees_.erase(
                std::remove(routees_.begin(), routees_.end(), msg.routee),
                routees_.end());
        });
    }

    // 路由消息
    template <typename T>
    void route(T&& message, ActorRef sender) {
        if (routees_.empty()) return;

        std::any any_msg = message;
        size_t idx = strategy_->select(routees_.size(), any_msg);
        routees_[idx]->tell(std::forward<T>(message), sender);
    }

    // 广播消息
    template <typename T>
    void broadcast(T&& message, ActorRef sender) {
        for (auto& routee : routees_) {
            routee->tell(message, sender);
        }
    }
};

// 工厂函数
template <typename T, typename... Args>
ActorRef create_pool(size_t size, std::unique_ptr<RoutingStrategy> strategy,
                     Args&&... args) {
    std::vector<ActorRef> routees;
    for (size_t i = 0; i < size; ++i) {
        routees.push_back(Actor::create<T>(std::forward<Args>(args)...));
    }
    return Actor::create<RouterActor>(std::move(routees), std::move(strategy));
}
```

**Day 4（5小时）- 负载均衡与池化**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:30 | 工作池 | 实现Worker Pool模式 |
| 2:30-5:00 | 动态调整 | 支持动态增减Worker |

**Day 3-4 检验标准**：
- [ ] 实现多种路由策略
- [ ] 实现Router Actor
- [ ] 实现Worker Pool

**今日输出物**：
- [ ] `router.hpp`
- [ ] `worker_pool.hpp`
- [ ] `test_router.cpp`
- [ ] 笔记：`notes/week3/day3-4_routing.md`

---

#### 📅 Day 5-6: 有限状态机Actor（10小时）

**Day 5（5小时）- FSM设计**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | FSM概念 | 学习状态机与Actor的结合 |
| 2:00-5:00 | FSM实现 | 实现FSM Actor基类 |

**动手实验 3-4：FSM Actor**
```cpp
// fsm_actor.hpp
#pragma once
#include "typed_actor.hpp"
#include <unordered_map>
#include <functional>
#include <optional>

template <typename State, typename Data>
class FSMActor : public TypedActor {
protected:
    State current_state_;
    Data state_data_;

    // 状态处理器类型
    using StateHandler = std::function<void(const std::any&, ActorRef)>;
    std::unordered_map<State, StateHandler> state_handlers_;

    // 状态转换
    void goto_state(State new_state) {
        on_exit(current_state_);
        State old_state = current_state_;
        current_state_ = new_state;
        on_enter(new_state, old_state);
    }

    // 转换并更新数据
    void goto_state(State new_state, Data new_data) {
        state_data_ = std::move(new_data);
        goto_state(new_state);
    }

    // 生命周期钩子
    virtual void on_enter(State state, State from_state) {}
    virtual void on_exit(State state) {}

    // 注册状态处理器
    void when(State state, StateHandler handler) {
        state_handlers_[state] = std::move(handler);
    }

    void on_receive(ActorRef sender, const std::any& message) override {
        auto it = state_handlers_.find(current_state_);
        if (it != state_handlers_.end()) {
            it->second(message, sender);
        }
    }

public:
    FSMActor(State initial_state, Data initial_data = {})
        : current_state_(initial_state), state_data_(std::move(initial_data)) {}

    State current_state() const { return current_state_; }
    const Data& state_data() const { return state_data_; }
};

// 示例：门禁状态机
class DoorActor : public FSMActor<std::string, int> {
public:
    struct Open {};
    struct Close {};
    struct Lock { int code; };
    struct Unlock { int code; };

    DoorActor() : FSMActor("closed", 0) {
        // 关闭状态
        when("closed", [this](const std::any& msg, ActorRef sender) {
            if (std::any_cast<Open>(&msg)) {
                std::cout << "Door opened\n";
                goto_state("open");
            } else if (auto* lock = std::any_cast<Lock>(&msg)) {
                std::cout << "Door locked with code " << lock->code << "\n";
                goto_state("locked", lock->code);
            }
        });

        // 打开状态
        when("open", [this](const std::any& msg, ActorRef sender) {
            if (std::any_cast<Close>(&msg)) {
                std::cout << "Door closed\n";
                goto_state("closed");
            }
        });

        // 锁定状态
        when("locked", [this](const std::any& msg, ActorRef sender) {
            if (auto* unlock = std::any_cast<Unlock>(&msg)) {
                if (unlock->code == state_data_) {
                    std::cout << "Door unlocked\n";
                    goto_state("closed", 0);
                } else {
                    std::cout << "Wrong code!\n";
                }
            }
        });
    }
};
```

**Day 6（5小时）- FSM实战示例**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-3:00 | 订单状态机 | 实现电商订单状态机 |
| 3:00-5:00 | 测试验证 | 完整的状态转换测试 |

**Day 5-6 检验标准**：
- [ ] 实现FSM Actor基类
- [ ] 实现状态转换机制
- [ ] 完成订单状态机示例

**今日输出物**：
- [ ] `fsm_actor.hpp`
- [ ] `order_fsm.hpp`
- [ ] `test_fsm.cpp`
- [ ] 笔记：`notes/week3/day5-6_fsm.md`

---

#### 📅 Day 7: 第三周总结（5小时）

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 模式总结 | 整理所有消息模式 |
| 2:00-4:00 | 最佳实践 | 总结Actor使用的最佳实践 |
| 4:00-5:00 | 笔记整理 | 整理本周学习笔记 |

**第三周输出物汇总**：
1. `ask_pattern.hpp` - Ask模式
2. `pipe_pattern.hpp` - Pipe模式
3. `router.hpp` - 路由器
4. `worker_pool.hpp` - 工作池
5. `fsm_actor.hpp` - FSM Actor
6. `test_*.cpp` - 测试文件
7. `notes/week3/` - 本周笔记

---

### 第四周：性能优化与实战

**学习目标**：优化Actor系统性能，完成实战项目

**阅读材料**：
- [ ] Akka文档：Dispatchers & Mailboxes
- [ ] CAF性能优化指南
- [ ] 论文：Actors Make Shared-State Concurrency Simple

---

#### 📅 Day 1-2: Actor调度器设计（10小时）

**Day 1（5小时）- 调度器架构**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 调度模型 | 分析不同的调度策略 |
| 2:00-5:00 | 调度器实现 | 实现基于线程池的调度器 |

**动手实验 4-1：Actor调度器**
```cpp
// scheduler.hpp
#pragma once
#include <thread>
#include <vector>
#include <queue>
#include <mutex>
#include <condition_variable>
#include <functional>
#include <atomic>

class Scheduler {
public:
    using Task = std::function<void()>;

private:
    std::vector<std::thread> workers_;
    std::queue<Task> tasks_;
    std::mutex mutex_;
    std::condition_variable cv_;
    std::atomic<bool> stop_{false};
    std::atomic<size_t> pending_tasks_{0};

    void worker_loop() {
        while (!stop_) {
            Task task;
            {
                std::unique_lock<std::mutex> lock(mutex_);
                cv_.wait(lock, [this] { return stop_ || !tasks_.empty(); });

                if (stop_ && tasks_.empty()) return;
                if (tasks_.empty()) continue;

                task = std::move(tasks_.front());
                tasks_.pop();
            }

            if (task) {
                task();
                --pending_tasks_;
            }
        }
    }

public:
    explicit Scheduler(size_t num_threads = std::thread::hardware_concurrency()) {
        for (size_t i = 0; i < num_threads; ++i) {
            workers_.emplace_back(&Scheduler::worker_loop, this);
        }
    }

    ~Scheduler() {
        stop_ = true;
        cv_.notify_all();
        for (auto& w : workers_) {
            if (w.joinable()) w.join();
        }
    }

    void schedule(Task task) {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            tasks_.push(std::move(task));
            ++pending_tasks_;
        }
        cv_.notify_one();
    }

    size_t pending_tasks() const { return pending_tasks_.load(); }
    size_t worker_count() const { return workers_.size(); }
};

// 基于调度器的轻量级Actor
class LightweightActor : public std::enable_shared_from_this<LightweightActor> {
    Scheduler& scheduler_;
    Mailbox<Envelope> mailbox_;
    std::atomic<bool> scheduled_{false};
    std::atomic<bool> running_{true};

protected:
    virtual void on_receive(ActorRef sender, const std::any& message) = 0;

    void process_batch(int max_messages = 10) {
        for (int i = 0; i < max_messages && running_; ++i) {
            auto envelope = mailbox_.try_dequeue();
            if (!envelope) break;

            try {
                on_receive(envelope->sender, envelope->message);
            } catch (...) {}
        }

        // 如果还有消息，重新调度
        if (!mailbox_.is_closed() && mailbox_.size() > 0) {
            schedule_self();
        } else {
            scheduled_ = false;
        }
    }

    void schedule_self() {
        if (scheduled_.exchange(true)) return;  // 已经在队列中

        scheduler_.schedule([self = shared_from_this()]() {
            self->process_batch();
        });
    }

public:
    explicit LightweightActor(Scheduler& scheduler) : scheduler_(scheduler) {}

    template <typename T>
    void tell(T&& message, ActorRef sender = nullptr) {
        mailbox_.enqueue(Envelope{sender, std::forward<T>(message)});
        schedule_self();
    }

    void stop() {
        running_ = false;
        mailbox_.close();
    }
};
```

**Day 2（5小时）- 调度优化**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:30 | 批处理优化 | 优化消息批处理 |
| 2:30-5:00 | 亲和性调度 | 实现线程亲和性 |

**Day 1-2 检验标准**：
- [ ] 实现Actor调度器
- [ ] 实现轻量级Actor
- [ ] 优化消息处理性能

**今日输出物**：
- [ ] `scheduler.hpp`
- [ ] `lightweight_actor.hpp`
- [ ] 笔记：`notes/week4/day1-2_scheduler.md`

---

#### 📅 Day 3-4: 背压与流量控制（10小时）

**Day 3（5小时）- 背压设计**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 背压概念 | 理解响应式流中的背压 |
| 2:00-5:00 | 背压实现 | 实现带背压的Actor |

**Day 4（5小时）- 流量控制**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:30 | 速率限制 | 实现消息速率限制 |
| 2:30-5:00 | 熔断器 | 实现熔断器模式 |

**动手实验 4-2：熔断器**
```cpp
// circuit_breaker.hpp
#pragma once
#include <chrono>
#include <atomic>
#include <mutex>

class CircuitBreaker {
public:
    enum class State { Closed, Open, HalfOpen };

private:
    std::atomic<State> state_{State::Closed};
    std::atomic<int> failure_count_{0};
    int failure_threshold_;
    std::chrono::milliseconds reset_timeout_;
    std::chrono::steady_clock::time_point last_failure_time_;
    std::mutex mutex_;

public:
    CircuitBreaker(int threshold = 5,
                   std::chrono::milliseconds timeout = std::chrono::seconds(30))
        : failure_threshold_(threshold), reset_timeout_(timeout) {}

    bool allow_request() {
        switch (state_.load()) {
            case State::Closed:
                return true;

            case State::Open: {
                auto now = std::chrono::steady_clock::now();
                std::lock_guard<std::mutex> lock(mutex_);
                if (now - last_failure_time_ > reset_timeout_) {
                    state_ = State::HalfOpen;
                    return true;
                }
                return false;
            }

            case State::HalfOpen:
                return true;
        }
        return false;
    }

    void record_success() {
        if (state_ == State::HalfOpen) {
            state_ = State::Closed;
            failure_count_ = 0;
        }
    }

    void record_failure() {
        std::lock_guard<std::mutex> lock(mutex_);
        last_failure_time_ = std::chrono::steady_clock::now();

        if (state_ == State::HalfOpen) {
            state_ = State::Open;
        } else if (++failure_count_ >= failure_threshold_) {
            state_ = State::Open;
        }
    }

    State state() const { return state_.load(); }
};
```

**Day 3-4 检验标准**：
- [ ] 理解背压机制
- [ ] 实现速率限制
- [ ] 实现熔断器模式

**今日输出物**：
- [ ] `backpressure.hpp`
- [ ] `circuit_breaker.hpp`
- [ ] `test_flow_control.cpp`
- [ ] 笔记：`notes/week4/day3-4_flow_control.md`

---

#### 📅 Day 5-6: 实战项目（10小时）

**Day 5（5小时）- 分布式计算框架**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 架构设计 | 设计简单的MapReduce框架 |
| 2:00-5:00 | 核心实现 | 实现Master和Worker |

**动手实验 4-3：简单MapReduce**
```cpp
// map_reduce.hpp
#pragma once
#include "typed_actor.hpp"
#include "router.hpp"
#include <map>
#include <vector>
#include <functional>

// MapReduce消息类型
template <typename K, typename V>
struct MapTask {
    std::vector<std::pair<K, V>> data;
};

template <typename K, typename V>
struct MapResult {
    std::vector<std::pair<K, V>> results;
};

template <typename K, typename V>
struct ReduceTask {
    K key;
    std::vector<V> values;
};

template <typename K, typename V>
struct ReduceResult {
    K key;
    V result;
};

// Mapper Actor
template <typename K1, typename V1, typename K2, typename V2>
class MapperActor : public TypedActor {
    std::function<std::vector<std::pair<K2, V2>>(const K1&, const V1&)> map_func_;

public:
    explicit MapperActor(decltype(map_func_) func) : map_func_(std::move(func)) {
        this->template on<MapTask<K1, V1>>([this](ActorRef sender, const MapTask<K1, V1>& task) {
            MapResult<K2, V2> result;
            for (const auto& [k, v] : task.data) {
                auto mapped = map_func_(k, v);
                result.results.insert(result.results.end(),
                                     mapped.begin(), mapped.end());
            }
            if (sender) sender->tell(result, this->self());
        });
    }
};

// Reducer Actor
template <typename K, typename V>
class ReducerActor : public TypedActor {
    std::function<V(const V&, const V&)> reduce_func_;

public:
    explicit ReducerActor(decltype(reduce_func_) func) : reduce_func_(std::move(func)) {
        this->template on<ReduceTask<K, V>>([this](ActorRef sender, const ReduceTask<K, V>& task) {
            if (task.values.empty()) return;

            V result = task.values[0];
            for (size_t i = 1; i < task.values.size(); ++i) {
                result = reduce_func_(result, task.values[i]);
            }

            if (sender) sender->tell(ReduceResult<K, V>{task.key, result}, this->self());
        });
    }
};

// Master Actor
template <typename K1, typename V1, typename K2, typename V2>
class MasterActor : public TypedActor {
    std::vector<ActorRef> mappers_;
    std::vector<ActorRef> reducers_;
    std::map<K2, std::vector<V2>> shuffle_buffer_;
    std::map<K2, V2> final_results_;
    size_t pending_maps_ = 0;
    size_t pending_reduces_ = 0;
    ActorRef client_;

public:
    struct StartJob {
        std::vector<std::pair<K1, V1>> data;
        size_t num_mappers;
        size_t num_reducers;
    };

    struct JobComplete {
        std::map<K2, V2> results;
    };

    MasterActor(
        std::function<std::vector<std::pair<K2, V2>>(const K1&, const V1&)> map_func,
        std::function<V2(const V2&, const V2&)> reduce_func)
    {
        this->template on<StartJob>([this, map_func, reduce_func](ActorRef sender, const StartJob& job) {
            client_ = sender;

            // 创建Mapper
            for (size_t i = 0; i < job.num_mappers; ++i) {
                mappers_.push_back(Actor::create<MapperActor<K1, V1, K2, V2>>(map_func));
            }

            // 创建Reducer
            for (size_t i = 0; i < job.num_reducers; ++i) {
                reducers_.push_back(Actor::create<ReducerActor<K2, V2>>(reduce_func));
            }

            // 分发Map任务
            size_t chunk_size = (job.data.size() + job.num_mappers - 1) / job.num_mappers;
            for (size_t i = 0; i < job.num_mappers; ++i) {
                size_t start = i * chunk_size;
                size_t end = std::min(start + chunk_size, job.data.size());
                if (start >= job.data.size()) break;

                MapTask<K1, V1> task;
                task.data.assign(job.data.begin() + start, job.data.begin() + end);
                mappers_[i]->tell(task, this->self());
                ++pending_maps_;
            }
        });

        this->template on<MapResult<K2, V2>>([this](ActorRef sender, const MapResult<K2, V2>& result) {
            // Shuffle: 按key分组
            for (const auto& [k, v] : result.results) {
                shuffle_buffer_[k].push_back(v);
            }

            if (--pending_maps_ == 0) {
                // 所有Map完成，开始Reduce
                size_t reducer_idx = 0;
                for (const auto& [k, values] : shuffle_buffer_) {
                    ReduceTask<K2, V2> task{k, values};
                    reducers_[reducer_idx % reducers_.size()]->tell(task, this->self());
                    ++pending_reduces_;
                    ++reducer_idx;
                }
            }
        });

        this->template on<ReduceResult<K2, V2>>([this](ActorRef sender, const ReduceResult<K2, V2>& result) {
            final_results_[result.key] = result.result;

            if (--pending_reduces_ == 0) {
                // 所有Reduce完成
                if (client_) {
                    client_->tell(JobComplete{final_results_}, this->self());
                }

                // 清理
                for (auto& m : mappers_) m->stop();
                for (auto& r : reducers_) r->stop();
            }
        });
    }
};

// 使用示例：词频统计
void word_count_example() {
    // Map函数：将文本行拆分为单词
    auto map_func = [](const int& line_num, const std::string& line) {
        std::vector<std::pair<std::string, int>> result;
        std::istringstream iss(line);
        std::string word;
        while (iss >> word) {
            result.push_back({word, 1});
        }
        return result;
    };

    // Reduce函数：累加计数
    auto reduce_func = [](const int& a, const int& b) { return a + b; };

    auto master = Actor::create<MasterActor<int, std::string, std::string, int>>(
        map_func, reduce_func);

    // 准备数据
    std::vector<std::pair<int, std::string>> data = {
        {1, "hello world"},
        {2, "hello actor"},
        {3, "world of actors"},
    };

    MasterActor<int, std::string, std::string, int>::StartJob job{data, 2, 2};
    master->tell(job, nullptr);
}
```

**Day 6（5小时）- 完善与测试**

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 功能完善 | 添加错误处理和重试 |
| 2:00-4:00 | 性能测试 | 基准测试 |
| 4:00-5:00 | 文档整理 | 编写使用文档 |

**Day 5-6 检验标准**：
- [ ] 实现简单的MapReduce框架
- [ ] 完成词频统计示例
- [ ] 通过性能测试

**今日输出物**：
- [ ] `map_reduce.hpp`
- [ ] `examples/word_count.cpp`
- [ ] `benchmark/map_reduce_bench.cpp`

---

#### 📅 Day 7: 第四周总结与项目收尾（5小时）

| 时间 | 内容 | 具体任务 |
|------|------|----------|
| 0:00-2:00 | 对比分析 | 与Erlang、Akka、CAF对比 |
| 2:00-3:30 | 最佳实践 | 总结Actor模型使用的最佳实践 |
| 3:30-5:00 | 项目整理 | 整理代码和文档 |

**与主流实现对比**：
```
┌──────────────┬────────────────┬──────────────┬──────────────┬──────────────┐
│ 特性         │ 我们的实现     │ Erlang/OTP   │ Akka         │ CAF          │
├──────────────┼────────────────┼──────────────┼──────────────┼──────────────┤
│ 类型安全     │ 部分           │ 动态类型     │ 强类型       │ 强类型       │
│ 监督机制     │ ✓              │ ✓✓           │ ✓✓           │ ✓            │
│ 分布式       │ ✗              │ ✓✓           │ ✓✓           │ ✓            │
│ 持久化       │ ✗              │ ✗            │ ✓            │ ✗            │
│ 流处理       │ ✗              │ ✗            │ ✓            │ ✓            │
│ 性能         │ 中             │ 高           │ 高           │ 极高         │
└──────────────┴────────────────┴──────────────┴──────────────┴──────────────┘
```

**第四周输出物汇总**：
1. `scheduler.hpp` - Actor调度器
2. `lightweight_actor.hpp` - 轻量级Actor
3. `backpressure.hpp` - 背压机制
4. `circuit_breaker.hpp` - 熔断器
5. `map_reduce.hpp` - MapReduce框架
6. `examples/` - 示例项目
7. `benchmark/` - 性能测试
8. `notes/week4/` - 本周笔记

---

## 检验标准

### 知识检验

- [ ] 能解释Actor模型的三条公理
- [ ] 能对比Actor模型与CSP模型的差异
- [ ] 理解"Let it crash"哲学
- [ ] 能解释监督策略的作用和类型
- [ ] 理解Ask模式的实现原理
- [ ] 能设计消息路由策略
- [ ] 理解FSM与Actor的结合
- [ ] 理解背压和熔断器的作用

### 实践检验

- [ ] 实现基础Actor和TypedActor
- [ ] 实现各种Mailbox变体
- [ ] 实现监督机制
- [ ] 实现Actor系统
- [ ] 实现Ask/Pipe模式
- [ ] 实现路由器和Worker Pool
- [ ] 实现FSM Actor
- [ ] 实现Actor调度器
- [ ] 完成MapReduce示例

### 输出物清单

**核心代码**：
1. `message.hpp` - 消息类型
2. `mailbox.hpp` - Mailbox实现
3. `actor.hpp` - 基础Actor
4. `typed_actor.hpp` - 类型安全Actor
5. `actor_path.hpp` - Actor地址
6. `actor_registry.hpp` - Actor注册表
7. `supervision.hpp` - 监督策略
8. `supervisor_actor.hpp` - 监督Actor
9. `lifecycle_actor.hpp` - 生命周期Actor
10. `actor_system.hpp` - Actor系统
11. `ask_pattern.hpp` - Ask模式
12. `router.hpp` - 消息路由
13. `fsm_actor.hpp` - FSM Actor
14. `scheduler.hpp` - 调度器
15. `circuit_breaker.hpp` - 熔断器
16. `map_reduce.hpp` - MapReduce框架

**测试与示例**：
17. `test_*.cpp` - 单元测试
18. `examples/` - 示例项目
19. `benchmark/` - 性能基准测试

**学习笔记**：
20. `notes/week1/` - 第一周笔记
21. `notes/week2/` - 第二周笔记
22. `notes/week3/` - 第三周笔记
23. `notes/week4/` - 第四周笔记
24. `notes/month20_summary.md` - 月度总结

---

## 时间分配（140小时/月）

| 内容 | 时间 | 占比 |
|------|------|------|
| 理论学习 | 30小时 | 21% |
| 代码实现 | 65小时 | 46% |
| 测试调试 | 25小时 | 18% |
| 源码阅读 | 10小时 | 7% |
| 笔记整理 | 10小时 | 7% |

---

## 下月预告

Month 21 将学习 **协程基础（C++20）**，探索无栈协程的原理和使用。协程提供了一种更轻量的并发抽象，可以与Actor模型结合使用，实现更高效的异步编程。
