# DTO、防腐层与编译防火墙：从三个维度构建“隔离”

在 C++ 工程里，系统失控通常不是因为“功能太多”，而是因为“边界被打穿”。  
当外部协议频繁变化、第三方语义与内部模型冲突、构建时间越来越长时，团队需要的不只是重构代码，而是重建边界。

本文围绕一个统一场景展开：**接入第三方行情服务**。  
输入是外部 JSON，内部需要稳定领域模型，同时还要把 SDK 依赖隔离在模块内部，避免项目级联重编译。

这时会同时用到三种技术：

- `DTO`：隔离传输数据与领域对象，处理数据边界。
- `ACL`（Anti-Corruption Layer，防腐层）：隔离外部语义对内部模型的污染，处理语义边界。
- `Compilation Firewall / Pimpl`：隔离实现细节与依赖传播，处理编译边界。

这三者是互补关系，不是替代关系。  
可以把它们看作系统边界上的三层过滤器：**数据过滤、语义过滤、依赖过滤**。

---

## 一、DTO（Data Transfer Object）模式

### 1. 是什么

DTO（Data Transfer Object）是专用于“跨边界传输”的数据结构。  
它的关键特征是：

- 字段直观，通常与报文结构一一对应。
- 不承载业务规则和复杂行为。
- 可序列化/反序列化，便于网络与存储传输。

简单说，DTO 的核心职责是“把数据送到边界内”，而不是“在边界内完成业务决策”。

### 2. 解决什么问题

如果没有 DTO，常见问题有：

1. 领域对象被迫迎合外部协议  
外部字段名、可空语义、默认值策略会直接侵入领域模型。

2. 协议变更扩散到核心业务  
第三方新增字段或改类型时，领域层和应用层都要跟着改。

3. 边界语义不清  
同一个结构既当 API 入参、又当领域实体、还当存储模型，导致职责混杂。

DTO 的价值在于：把变化高频的“输入输出格式”固定在边界，内部模型保持稳定。

### 3. 典型应用场景

- Web 层请求/响应对象（REST/gRPC）。
- 消息队列 payload。
- 跨模块、跨进程的数据交换结构。
- 文件导入导出（CSV/JSON/Protobuf）中间结构。

### 4. 设计要点与边界约束

实践中可遵循以下约束：

- DTO 保持“平面化”优先，减少复杂行为。
- DTO 不直接引用数据库连接、缓存句柄等基础设施对象。
- DTO 不写领域决策逻辑（如风控规则、计费规则）。
- 边界转换函数要显式命名，如 `toDomain()`、`toDTO()`。

### 5. 为什么能解决这些问题

DTO 的本质是“把传输耦合限定在转换点”。  
一旦传输协议变化，只需要调整：

- DTO 字段；
- DTO 与领域模型之间的映射函数；

而领域对象和核心业务规则可以不受影响。这种“变化收敛”是 DTO 的主要收益。

### 6. C++ 示例：DTO 与领域对象解耦

```cpp
#include <string>
#include <optional>
#include <stdexcept>

// 边界输入：来自网络层或第三方协议
struct QuoteDTO {
    std::string symbol;                // 可能是 "AAPL.US"
    std::optional<double> last_price;  // 外部字段可能可空
    std::optional<long long> ts_ms;    // 毫秒时间戳
};

// 内部领域对象：语义稳定、可承载业务行为
struct Quote {
    std::string instrument;
    double price = 0.0;
    long long timestamp_ms = 0;
};

Quote toDomain(const QuoteDTO& dto) {
    if (!dto.last_price.has_value()) {
        throw std::invalid_argument("last_price is required");
    }

    Quote q;
    q.instrument = dto.symbol; // 真正项目中通常还会配合 ACL 进一步规范化
    q.price = *dto.last_price;
    q.timestamp_ms = dto.ts_ms.value_or(0);
    return q;
}
```

### 7. 常见误区

- 把 DTO 当成领域实体长期在核心层传递。
- 在 DTO 内部写复杂业务方法。
- DTO 与数据库 ORM 实体复用同一结构，导致边界职责冲突。

---

## 二、防腐层（Anti-Corruption Layer, ACL）

### 1. 是什么

ACL 是 DDD 里用于系统集成的关键模式。  
它的目标是：**把外部系统语言翻译为内部统一语言（Ubiquitous Language）**。

ACL 不只是“格式转换”，而是有明确语义职责的边界层，常见职责包括：

- 字段语义映射；
- 单位换算；
- 枚举/状态码映射；
- 错误码归一化；
- 缺省值与容错策略收敛。

### 2. 解决什么问题

没有 ACL 时，系统常见退化如下：

1. 外部术语直接进入内部代码  
例如 `ticker`, `halted`, `err_code` 等概念散落在领域服务中。

2. 多外部源接入后领域模型畸形  
内部对象为兼容多个供应商，被迫加入大量“兼容字段”。

3. 外部变化导致内部逻辑大量改动  
第三方状态码变更时，业务代码中出现全局排查和条件分支爆炸。

ACL 的核心就是把这些不稳定性挡在边界上。

### 3. 典型应用场景

- 支付网关接入（多渠道状态码与错误码统一）。
- 行情或交易系统对接（符号、单位、交易状态映射）。
- ERP/CRM 对接（外部主数据模型与内部领域模型不一致）。
- 新老系统并行迁移（Legacy 到 New Core 的翻译层）。

### 4. 为什么能解决这些问题

ACL 的价值不是“少写代码”，而是“控制污染半径”。  
当外部系统变化时：

- 改动优先落在 ACL；
- 内部领域模型仍可保持稳定命名与行为；
- 测试也可以聚焦在 ACL 翻译正确性，而不是全链路回归。

### 5. C++ 示例：语义翻译而非透传

```cpp
#include <string>
#include <stdexcept>

// 外部系统模型（不可控）
struct ExternalQuote {
    std::string ticker;   // "AAPL.US"
    long price_cents = 0; // 单位：分
    int status = 0;       // 0=ok, 1=halted, 2=closed
};

enum class QuoteStatus {
    Tradable,
    Halted,
    Closed
};

// 内部领域模型（可控）
struct Quote {
    std::string instrument; // 统一内部命名
    double price = 0.0;     // 单位：元
    QuoteStatus status = QuoteStatus::Tradable;
};

class QuoteAclTranslator {
public:
    Quote translate(const ExternalQuote& ext) const {
        Quote q;
        q.instrument = normalizeSymbol(ext.ticker);
        q.price = centsToYuan(ext.price_cents);
        q.status = mapStatus(ext.status);
        return q;
    }

private:
    static std::string normalizeSymbol(const std::string& ticker) {
        auto pos = ticker.find('.');
        return pos == std::string::npos ? ticker : ticker.substr(0, pos);
    }

    static double centsToYuan(long cents) {
        if (cents < 0) {
            throw std::runtime_error("invalid external price");
        }
        return static_cast<double>(cents) / 100.0;
    }

    static QuoteStatus mapStatus(int code) {
        switch (code) {
            case 0: return QuoteStatus::Tradable;
            case 1: return QuoteStatus::Halted;
            case 2: return QuoteStatus::Closed;
            default: throw std::runtime_error("unknown external status");
        }
    }
};
```

### 6. ACL 的工程化建议

- 以“外部系统”为维度组织 ACL，而不是按业务模块分散。
- 对映射规则做单元测试，尤其是边界值和未知状态。
- 把“无法翻译”的异常显式抛出或转换为统一错误对象，避免静默吞错。
- ACL 不直接承载领域决策，领域决策仍在领域服务中完成。

### 7. 常见误区

- ACL 退化成 `return external_obj;` 的透传层。
- ACL 中混入持久化、副作用调用，导致边界职责不清。
- 把 ACL 和 DTO 合并为单层，最后外部术语仍渗透到领域层。

---

## 三、编译防火墙（Compilation Firewall）/ Pimpl 惯用法

### 1. 是什么

编译防火墙的目标是：让“实现变化”不要通过头文件传播到整个项目。  
Pimpl（Pointer to Implementation）是常用手段：在头文件中只保留接口和前置声明，把具体成员和重依赖放入 `.cpp` 的 `Impl` 结构中。

### 2. 解决什么问题

1. 头文件依赖膨胀  
公共头暴露了 STL 容器、三方 SDK 类型、数据库对象等，导致被包含者过多。

2. 修改实现触发级联重编译  
头文件的私有成员改动也会引发全量或大面积增量编译。

3. ABI 稳定性差  
库导出的类布局变化会影响二进制兼容，给跨团队发布带来风险。

### 3. 经典 Pimpl 实现与关键细节

`QuoteService.h`：

```cpp
#pragma once
#include <memory>
#include <string>

class QuoteService {
public:
    QuoteService();
    ~QuoteService(); // 必须在 .cpp 定义，确保 Impl 为完整类型

    QuoteService(QuoteService&&) noexcept;
    QuoteService& operator=(QuoteService&&) noexcept;

    QuoteService(const QuoteService&) = delete;
    QuoteService& operator=(const QuoteService&) = delete;

    double queryLastPrice(const std::string& symbol) const;
    void refreshFromProvider();

private:
    struct Impl;                  // 前置声明
    std::unique_ptr<Impl> impl_;  // 不透明实现
};
```

`QuoteService.cpp`：

```cpp
#include "QuoteService.h"
#include <unordered_map>
#include <string>

// 假设这里还会 include 重型三方 SDK 头文件
// #include <third_party_market_sdk.h>

struct QuoteService::Impl {
    std::unordered_map<std::string, double> cache{
        {"AAPL", 188.12}, {"MSFT", 412.33}
    };

    void pullFromProvider() {
        // 调用三方 SDK 并更新 cache
    }
};

QuoteService::QuoteService() : impl_(std::make_unique<Impl>()) {}
QuoteService::~QuoteService() = default;
QuoteService::QuoteService(QuoteService&&) noexcept = default;
QuoteService& QuoteService::operator=(QuoteService&&) noexcept = default;

double QuoteService::queryLastPrice(const std::string& symbol) const {
    auto it = impl_->cache.find(symbol);
    return it == impl_->cache.end() ? 0.0 : it->second;
}

void QuoteService::refreshFromProvider() {
    impl_->pullFromProvider();
}
```

关键点：

- 析构函数放在 `.cpp`，避免在头文件处需要完整 `Impl` 类型。
- 通过 move 语义管理唯一所有权，避免无意拷贝。
- 把三方依赖 include 限定在 `.cpp`，降低传播半径。

### 4. 变体：内部镜像结构体 + 转换函数

在一些模块中，除了 `Impl` 隔离，还需要“对外配置稳定、对内配置可演化”。  
这时可采用“公共结构 + 内部镜像 + 映射函数”：

```cpp
struct PublicConfig {
    int timeout_ms = 500;
    bool enable_cache = true;
};

struct InternalConfig {
    int timeout_ms = 0;
    int retry_count = 0;
    bool use_lru_cache = false;
    int shard_count = 1; // 后续新增内部字段，不影响 public API
};

InternalConfig toInternal(const PublicConfig& in) {
    InternalConfig out;
    out.timeout_ms = in.timeout_ms;
    out.retry_count = in.enable_cache ? 2 : 0;
    out.use_lru_cache = in.enable_cache;
    out.shard_count = in.enable_cache ? 8 : 1;
    return out;
}
```

这种方式的收益是：  
公共配置结构尽量稳定，内部实现参数可以快速演进，不强迫调用方跟随变化。

### 5. 为什么能解决这些问题

Pimpl 本质上是“控制头文件可见性”。  
一旦可见性被收敛：

- 依赖传播路径被截断；
- 构建系统的无效重编译减少；
- 对外 ABI 风险下降；
- 内部实现重构成本更低。

### 6. 成本与适用边界

Pimpl 也有成本：

- 一次额外间接访问（指针解引用）；
- 需要额外管理 move/析构语义；
- 代码跳转增多，调试路径更长。

因此它更适用于：

- 公共库接口；
- 依赖重、变化频繁的模块；
- 需要关注 ABI 稳定性的组件。

对于简单值对象或极轻量工具类，不必机械套用。

---

## 四、三者关系与对比

### 1. 总体关系

三者分别针对不同层面的“耦合”：

- DTO 处理“表示耦合”（外部报文格式）。
- ACL 处理“语义耦合”（外部概念体系）。
- Pimpl 处理“编译耦合”（头文件与实现依赖）。

如果把系统边界看成一条流水线，推荐顺序通常是：

`外部数据 -> DTO -> ACL -> 领域模型 -> 领域服务(Pimpl隐藏实现)`

### 2. 对比表（详细版）

| 维度 | DTO | ACL | 编译防火墙 / Pimpl |
|---|---|---|---|
| 核心目标 | 数据可传输、边界可控 | 外部语义隔离与翻译 | 依赖收敛、编译与 ABI 稳定 |
| 主要位置 | 接口层/传输层 | 系统集成边界层 | 公共库接口层/模块边界 |
| 输入输出 | 报文结构与边界对象 | 外部模型与内部模型 | 头文件接口与实现文件 |
| 典型手法 | 纯数据结构、映射函数 | Translator/Adapter/Facade | 前置声明、不透明指针、实现下沉 |
| 最常解决的问题 | 协议变更扩散 | 外部污染内部领域 | 级联重编译、私有实现泄漏 |
| 常见误用 | DTO 承载领域行为 | ACL 透传不翻译 | 只改写法不降依赖 |
| 主要收益 | 变化收敛到边界 | 统一语言稳定 | 编译成本与演进成本可控 |

### 3. 一个完整案例如何同时体现三者

以行情接入为例，完整流程可以是：

1. 网络层接收第三方 JSON，反序列化为 `QuoteDTO`。  
2. `QuoteAclTranslator` 将 `QuoteDTO` 或 `ExternalQuote` 翻译成内部 `Quote`。  
3. 领域服务 `QuoteService` 只接受内部 `Quote` 语义。  
4. `QuoteService` 使用 Pimpl，把 SDK、缓存、连接池等重依赖藏在 `.cpp`。  
5. 对外调用方只看到稳定头文件，不感知内部实现变化。

这一组合带来的直接效果是：

- 协议变化优先改 DTO 映射；
- 外部供应商语义变化优先改 ACL；
- 内部实现重构优先改 Pimpl 的 `.cpp`；
- 三类变化互不放大。

---

## 五、工程实践建议与反模式

### 1. 落地建议

1. 先画边界，再写代码  
先定义哪些是“外部模型”、哪些是“领域模型”、哪些是“公共接口”。

2. 映射函数显式化  
统一命名 `toDomain`、`toDTO`、`translateFromXxx`，不要隐式散落在业务代码里。

3. ACL 做强测试  
重点测试未知枚举值、非法单位、缺失字段、兼容字段。

4. Pimpl 配合 include 审计  
如果引入 Pimpl 后头文件仍包含大量三方头，说明收益没有真正落地。

### 2. 反模式清单

- 反模式 A：DTO 到处传，最终替代领域模型。  
- 反模式 B：ACL 只转字段名，不做语义收敛和错误统一。  
- 反模式 C：Pimpl 只是形式上拆出 Impl，实际依赖仍暴露在头文件。  
- 反模式 D：每个类都上 Pimpl，导致过度抽象与性能/维护成本上升。  

---

## 六、结语

DTO、防腐层、编译防火墙分别针对三种不同的耦合源：

- DTO 解决“数据表示边界”；
- ACL 解决“业务语义边界”；
- Pimpl 解决“编译与实现边界”。

当你把它们按职责组合使用时，系统会形成一条清晰的隔离链路：  
外部变化不再轻易污染核心，内部重构也不再轻易影响全局。  
这正是中大型 C++ 工程长期可维护性的关键。
