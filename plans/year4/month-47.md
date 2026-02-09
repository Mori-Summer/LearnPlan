# Month 47: 指标收集与监控——构建可观测性系统

## 本月主题概述

本月学习应用指标收集和监控系统的设计与实现。掌握Prometheus指标格式、时序数据库概念、告警规则配置，以及如何在C++应用中集成指标暴露。

**学习目标**：
- 理解可观测性三大支柱（日志、指标、追踪）
- 掌握Prometheus指标类型和格式
- 学会在C++中实现指标收集
- 能够配置Grafana可视化和告警

**进阶目标**：
- 深入理解时序数据库存储原理
- 掌握PromQL高级查询技巧
- 能够设计大规模监控架构
- 理解OpenTelemetry统一可观测性标准

---

## 理论学习内容

### 第一周：可观测性基础与核心概念

**学习目标**：
- 深入理解可观测性三大支柱及其关系
- 掌握监控系统的演进历史与设计哲学
- 理解时序数据库的存储原理
- 熟悉Prometheus生态系统架构
- 掌握RED/USE/Four Golden Signals方法论

**阅读材料**：
- [ ] Prometheus官方文档（重点：Data Model、Metric Types）
- [ ] 《Site Reliability Engineering》第6章：监控分布式系统
- [ ] 《Designing Data-Intensive Applications》时序数据库章节
- [ ] Google SRE Workbook：Implementing SLOs
- [ ] Brendan Gregg的USE方法论文章

---

#### 1.1 监控系统演进史

```cpp
// ==========================================
// 监控系统发展历程
// ==========================================
//
// 第一代：基于轮询的监控（1990s-2000s）
// ├── 代表：Nagios、Zabbix
// ├── 特点：主动检查、状态为主
// ├── 问题：扩展性差、配置复杂
// └── 架构：中心化轮询
//
// 第二代：时序数据库监控（2010s）
// ├── 代表：Graphite、InfluxDB
// ├── 特点：指标收集、时序存储
// ├── 改进：支持高维度数据
// └── 问题：查询语言不统一
//
// 第三代：云原生监控（2015s至今）
// ├── 代表：Prometheus、OpenTelemetry
// ├── 特点：Pull模型、服务发现、标签化
// ├── 优势：容器友好、生态丰富
// └── 趋势：可观测性统一标准
//
// ==========================================
// 为什么Prometheus胜出？
// ==========================================
//
// 1. 简单性
//    - 单二进制部署
//    - 无外部依赖
//    - 本地存储
//
// 2. 可靠性
//    - 每个Prometheus独立运行
//    - 监控系统不应依赖被监控系统
//    - 在网络分区时仍能工作
//
// 3. 灵活性
//    - 强大的PromQL查询语言
//    - 多维度标签模型
//    - 服务发现机制
//
// 4. 生态系统
//    - 丰富的Exporter
//    - Grafana原生支持
//    - CNCF毕业项目
```

---

#### 1.2 可观测性三大支柱深入理解

```cpp
// ==========================================
// 可观测性（Observability）vs 监控（Monitoring）
// ==========================================
//
// 监控：回答已知问题
//   "系统是否健康？"
//   "CPU使用率是多少？"
//   "请求延迟是否超标？"
//
// 可观测性：回答未知问题
//   "为什么系统不健康？"
//   "用户投诉的请求发生了什么？"
//   "新版本性能下降的原因是什么？"
//
// 可观测性 = 日志 + 指标 + 追踪 + 上下文关联
//
// ==========================================
// 三大支柱详解
// ==========================================

#include <string>
#include <map>
#include <vector>
#include <chrono>
#include <optional>

namespace observability {

// ==========================================
// 支柱一：日志（Logs）
// ==========================================
//
// 特性：
// - 离散事件：每条日志记录一个独立事件
// - 高基数：可包含任意详细信息（用户ID、请求ID等）
// - 全量存储：通常保留所有数据
// - 查询成本高：需要全文搜索
//
// 适用场景：
// - 调试特定问题
// - 审计和合规
// - 异常事件分析
// - 安全事件调查

// 结构化日志事件定义
struct LogEvent {
    // 时间戳：事件发生的精确时间
    std::chrono::system_clock::time_point timestamp;

    // 日志级别：DEBUG, INFO, WARN, ERROR, FATAL
    enum class Level { DEBUG, INFO, WARN, ERROR, FATAL };
    Level level;

    // 日志消息：人类可读的描述
    std::string message;

    // 结构化字段：机器可解析的键值对
    std::map<std::string, std::string> fields;

    // 追踪上下文：关联到分布式追踪
    std::optional<std::string> trace_id;
    std::optional<std::string> span_id;

    // 资源信息：标识日志来源
    std::string service_name;
    std::string instance_id;
};

// 示例：如何记录一条高质量的日志
/*
{
    "timestamp": "2024-01-15T10:23:45.123456Z",
    "level": "ERROR",
    "message": "Failed to process payment",
    "service": "payment-service",
    "instance": "payment-service-pod-abc123",
    "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
    "span_id": "00f067aa0ba902b7",
    "user_id": "user_12345",
    "order_id": "order_67890",
    "amount": 99.99,
    "currency": "USD",
    "error_code": "CARD_DECLINED",
    "error_message": "Insufficient funds"
}
*/

// ==========================================
// 支柱二：指标（Metrics）
// ==========================================
//
// 特性：
// - 数值型：可进行数学运算
// - 时序性：随时间变化的数据点
// - 聚合存储：预聚合降低存储成本
// - 查询高效：索引优化的时序查询
//
// 适用场景：
// - 系统健康监控
// - 容量规划
// - 告警触发
// - SLO跟踪
// - 趋势分析

// 指标数据点定义
struct MetricSample {
    // 指标名称：描述测量什么
    std::string name;

    // 标签集：多维度标识
    std::map<std::string, std::string> labels;

    // 数值：测量值
    double value;

    // 时间戳：采集时间
    int64_t timestamp_ms;
};

// 四种指标类型的内存表示
enum class MetricType {
    COUNTER,    // 只增不减的计数器
    GAUGE,      // 可增可减的仪表盘
    HISTOGRAM,  // 分布统计直方图
    SUMMARY     // 客户端分位数摘要
};

// ==========================================
// 支柱三：追踪（Traces）
// ==========================================
//
// 特性：
// - 请求级别：跟踪单个请求的完整路径
// - 分布式：跨服务边界传播上下文
// - 因果关系：展示服务间调用关系
// - 采样存储：通常只保留部分数据
//
// 适用场景：
// - 性能瓶颈分析
// - 服务依赖可视化
// - 根因定位
// - 延迟分布分析

// Span定义：追踪的基本单元
struct Span {
    // 追踪ID：整个请求链的唯一标识
    std::string trace_id;

    // Span ID：当前操作的唯一标识
    std::string span_id;

    // 父Span ID：调用者的Span ID（根Span为空）
    std::optional<std::string> parent_span_id;

    // 操作名称：描述这个Span做什么
    std::string operation_name;

    // 服务名称：产生这个Span的服务
    std::string service_name;

    // 时间范围：开始和结束时间
    std::chrono::system_clock::time_point start_time;
    std::chrono::system_clock::time_point end_time;

    // 标签：键值对属性
    std::map<std::string, std::string> tags;

    // 日志：Span内的事件记录
    std::vector<LogEvent> logs;

    // 状态：成功或错误
    enum class Status { OK, ERROR };
    Status status;
};

// 示例：一个HTTP请求的追踪链
/*
Trace ID: abc123

[Frontend] ─────────────────────────────────────────────────────────────
    │ Span: HTTP GET /checkout (200ms)
    │
    ├──[API Gateway] ──────────────────────────────────────────────────
    │      │ Span: Route to checkout-service (5ms)
    │      │
    │      ├──[Checkout Service] ─────────────────────────────────────
    │      │      │ Span: Process checkout (180ms)
    │      │      │
    │      │      ├──[User Service] ──────────────────────────────────
    │      │      │      Span: Get user info (20ms)
    │      │      │
    │      │      ├──[Inventory Service] ─────────────────────────────
    │      │      │      Span: Check inventory (30ms)
    │      │      │
    │      │      ├──[Payment Service] ───────────────────────────────
    │      │      │      │ Span: Process payment (100ms)
    │      │      │      │
    │      │      │      └──[External Payment Gateway] ───────────────
    │      │      │             Span: Charge card (80ms)
    │      │      │
    │      │      └──[Notification Service] ──────────────────────────
    │      │             Span: Send confirmation (10ms)
*/

// ==========================================
// 三大支柱的关联
// ==========================================
//
// 理想的可观测性系统应该能够：
//
// 1. 从告警（指标）出发
//    "错误率超过5%"
//       ↓
// 2. 关联到具体追踪
//    "查看错误请求的追踪链"
//       ↓
// 3. 深入到日志细节
//    "查看失败Span的详细日志"
//
// 实现方式：
// - 统一的Trace ID贯穿三者
// - Exemplars：指标样本关联到追踪
// - 结构化日志包含追踪上下文

// 关联上下文的数据结构
struct ObservabilityContext {
    // 追踪上下文
    std::string trace_id;
    std::string span_id;

    // 资源标识
    std::string service_name;
    std::string service_version;
    std::string instance_id;

    // 传播这个上下文到下游服务
    std::map<std::string, std::string> propagate() const {
        return {
            {"traceparent", "00-" + trace_id + "-" + span_id + "-01"},
            {"tracestate", ""}
        };
    }
};

} // namespace observability
```

---

#### 1.3 Prometheus指标类型深度解析

```cpp
// ==========================================
// Prometheus 数据模型
// ==========================================
//
// 核心概念：时间序列 (Time Series)
//
// 时间序列 = 指标名 + 标签集 + 时间戳序列 + 数值序列
//
// 表示形式：
// metric_name{label1="value1", label2="value2"} value @timestamp
//
// 示例：
// http_requests_total{method="GET", path="/api", status="200"} 12345 1642234567000
//
// 唯一标识：
// 每个时间序列由 指标名 + 所有标签的键值对 唯一确定
// 改变任何标签值都会创建新的时间序列

#include <atomic>
#include <mutex>
#include <map>
#include <vector>
#include <cmath>
#include <algorithm>
#include <numeric>
#include <sstream>

namespace prometheus {

// ==========================================
// Counter（计数器）详解
// ==========================================
//
// 语义：
// - 单调递增的累计值
// - 只能增加，不能减少
// - 进程重启时重置为0
//
// 使用场景：
// - 请求总数
// - 错误总数
// - 任务完成数
// - 传输的字节数
//
// 查询示例：
// - rate(http_requests_total[5m])  # 每秒请求速率
// - increase(http_requests_total[1h])  # 过去1小时的增量
//
// 为什么用Counter而不是Gauge记录请求数？
// - Counter重启后重置，rate()函数能正确处理
// - Gauge无法区分"数值变化"和"重置"
// - Counter配合rate()能计算准确的速率

class Counter {
public:
    // 构造函数：初始化为0
    Counter() : value_(0.0) {}

    // 增加计数（必须为正数）
    void inc(double delta = 1.0) {
        if (delta < 0) {
            // Counter不允许减少！
            throw std::invalid_argument("Counter不能减少，delta必须>=0");
        }

        // 使用CAS操作保证线程安全
        double current = value_.load(std::memory_order_relaxed);
        while (!value_.compare_exchange_weak(
            current,
            current + delta,
            std::memory_order_relaxed,
            std::memory_order_relaxed
        ));
    }

    // 获取当前值
    double value() const {
        return value_.load(std::memory_order_relaxed);
    }

    // 重置（仅在进程重启时调用）
    // 注意：不要在正常运行时调用reset()！
    void reset() {
        value_.store(0.0, std::memory_order_relaxed);
    }

private:
    std::atomic<double> value_;
};

// ==========================================
// Gauge（仪表盘）详解
// ==========================================
//
// 语义：
// - 表示可以任意上下波动的瞬时值
// - 可以增加、减少、直接设置
//
// 使用场景：
// - 当前温度
// - 内存使用量
// - 活跃连接数
// - 队列长度
// - 磁盘使用率
//
// 查询示例：
// - memory_usage_bytes  # 当前内存使用
// - max_over_time(cpu_usage[1h])  # 过去1小时的最大值
// - delta(queue_length[5m])  # 队列长度变化

class Gauge {
public:
    Gauge() : value_(0.0) {}

    // 直接设置值
    void set(double value) {
        value_.store(value, std::memory_order_relaxed);
    }

    // 增加
    void inc(double delta = 1.0) {
        add(delta);
    }

    // 减少
    void dec(double delta = 1.0) {
        add(-delta);
    }

    // 获取当前值
    double value() const {
        return value_.load(std::memory_order_relaxed);
    }

    // 设置为当前时间戳（用于记录最后更新时间）
    void set_to_current_time() {
        auto now = std::chrono::system_clock::now();
        auto epoch = now.time_since_epoch();
        auto seconds = std::chrono::duration_cast<std::chrono::seconds>(epoch);
        set(static_cast<double>(seconds.count()));
    }

private:
    void add(double delta) {
        double current = value_.load(std::memory_order_relaxed);
        while (!value_.compare_exchange_weak(
            current,
            current + delta,
            std::memory_order_relaxed,
            std::memory_order_relaxed
        ));
    }

    std::atomic<double> value_;
};

// ==========================================
// Histogram（直方图）详解
// ==========================================
//
// 语义：
// - 将观测值按照预定义的桶边界进行分布统计
// - 每个桶累计计数所有小于等于该边界的观测值
// - 同时记录总和(sum)和总数(count)
//
// 使用场景：
// - 请求延迟分布
// - 响应大小分布
// - 任何需要计算分位数的场景
//
// 暴露的指标：
// - metric_bucket{le="0.01"} 100    # <=10ms的请求数
// - metric_bucket{le="0.05"} 200    # <=50ms的请求数
// - metric_bucket{le="+Inf"} 250    # 所有请求数
// - metric_sum 45.67                 # 所有观测值的总和
// - metric_count 250                 # 观测总次数
//
// 查询示例：
// - histogram_quantile(0.95, rate(http_duration_bucket[5m]))  # P95延迟
// - rate(http_duration_sum[5m]) / rate(http_duration_count[5m])  # 平均延迟
//
// 桶边界选择建议：
// - 对于延迟：0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10
// - 桶边界应该覆盖预期值范围
// - 桶数量一般在10-20个
// - 过多的桶会增加存储和查询开销

class Histogram {
public:
    // 默认桶边界（适用于延迟，单位：秒）
    static std::vector<double> default_buckets() {
        return {0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0};
    }

    // 线性桶边界生成器
    // start: 起始值, width: 每个桶的宽度, count: 桶的数量
    static std::vector<double> linear_buckets(double start, double width, int count) {
        std::vector<double> buckets;
        buckets.reserve(count);
        for (int i = 0; i < count; ++i) {
            buckets.push_back(start + width * i);
        }
        return buckets;
    }

    // 指数桶边界生成器
    // start: 起始值, factor: 增长因子, count: 桶的数量
    static std::vector<double> exponential_buckets(double start, double factor, int count) {
        std::vector<double> buckets;
        buckets.reserve(count);
        double current = start;
        for (int i = 0; i < count; ++i) {
            buckets.push_back(current);
            current *= factor;
        }
        return buckets;
    }

    explicit Histogram(const std::vector<double>& buckets = default_buckets())
        : bucket_bounds_(buckets)
        , bucket_counts_(buckets.size() + 1, 0)  // +1 是为了 +Inf 桶
        , sum_(0.0)
        , count_(0)
    {
        // 确保桶边界是排序的
        if (!std::is_sorted(bucket_bounds_.begin(), bucket_bounds_.end())) {
            throw std::invalid_argument("桶边界必须是升序排列的");
        }
    }

    // 记录一个观测值
    void observe(double value) {
        std::lock_guard<std::mutex> lock(mutex_);

        // 更新sum和count
        sum_ += value;
        count_++;

        // 找到对应的桶并增加计数
        // 注意：Histogram的桶是累积的！
        // 每个桶记录的是"小于等于该边界的所有值的数量"
        for (size_t i = 0; i < bucket_bounds_.size(); ++i) {
            if (value <= bucket_bounds_[i]) {
                bucket_counts_[i]++;
            }
        }
        // +Inf 桶始终增加
        bucket_counts_.back()++;
    }

    // 获取所有数据（用于导出）
    struct HistogramData {
        std::vector<double> bucket_bounds;
        std::vector<uint64_t> bucket_counts;  // 累积计数
        double sum;
        uint64_t count;
    };

    HistogramData collect() const {
        std::lock_guard<std::mutex> lock(mutex_);

        // 计算累积计数
        std::vector<uint64_t> cumulative(bucket_counts_.size());
        uint64_t running_total = 0;
        for (size_t i = 0; i < bucket_counts_.size(); ++i) {
            running_total += bucket_counts_[i];
            cumulative[i] = running_total;
        }

        return {bucket_bounds_, cumulative, sum_, count_};
    }

    // 格式化为Prometheus文本格式
    std::string format(const std::string& name,
                       const std::map<std::string, std::string>& labels = {}) const {
        std::ostringstream oss;
        auto data = collect();

        // 构建标签字符串
        auto format_labels = [&labels](const std::string& extra = "") -> std::string {
            if (labels.empty() && extra.empty()) return "";
            std::ostringstream label_oss;
            label_oss << "{";
            bool first = true;
            for (const auto& [k, v] : labels) {
                if (!first) label_oss << ",";
                label_oss << k << "=\"" << v << "\"";
                first = false;
            }
            if (!extra.empty()) {
                if (!first) label_oss << ",";
                label_oss << extra;
            }
            label_oss << "}";
            return label_oss.str();
        };

        // 输出桶
        for (size_t i = 0; i < data.bucket_bounds.size(); ++i) {
            oss << name << "_bucket"
                << format_labels("le=\"" + std::to_string(data.bucket_bounds[i]) + "\"")
                << " " << data.bucket_counts[i] << "\n";
        }
        // +Inf 桶
        oss << name << "_bucket" << format_labels("le=\"+Inf\"")
            << " " << data.bucket_counts.back() << "\n";
        // sum
        oss << name << "_sum" << format_labels() << " " << data.sum << "\n";
        // count
        oss << name << "_count" << format_labels() << " " << data.count << "\n";

        return oss.str();
    }

private:
    std::vector<double> bucket_bounds_;      // 桶边界
    std::vector<uint64_t> bucket_counts_;    // 每个桶的计数（非累积）
    double sum_;                              // 观测值总和
    uint64_t count_;                          // 观测次数
    mutable std::mutex mutex_;                // 线程安全锁
};

// ==========================================
// Summary（摘要）详解
// ==========================================
//
// 语义：
// - 在客户端计算分位数
// - 暴露预定义的分位数（如P50, P90, P99）
//
// 与Histogram对比：
// ┌─────────────────┬────────────────────┬────────────────────┐
// │     特性        │     Histogram      │      Summary       │
// ├─────────────────┼────────────────────┼────────────────────┤
// │ 分位数计算位置  │ 服务端（PromQL）   │ 客户端             │
// │ 可聚合性        │ 可以聚合           │ 不可聚合           │
// │ 精确度          │ 近似（依赖桶划分） │ 精确（滑动窗口内） │
// │ 配置复杂度      │ 需选择桶边界       │ 需选择分位数       │
// │ 资源开销        │ 较低               │ 较高（内存）       │
// │ 适用场景        │ 请求延迟等         │ 精确分位数需求     │
// └─────────────────┴────────────────────┴────────────────────┘
//
// 推荐：
// - 大多数场景使用Histogram
// - 只有在需要精确分位数且不需要聚合时使用Summary

class Summary {
public:
    // 分位数定义：{分位数值, 允许误差}
    using Quantile = std::pair<double, double>;

    // 默认分位数配置
    static std::vector<Quantile> default_quantiles() {
        return {
            {0.5, 0.05},   // P50，误差±5%
            {0.9, 0.01},   // P90，误差±1%
            {0.99, 0.001}  // P99，误差±0.1%
        };
    }

    Summary(const std::vector<Quantile>& quantiles = default_quantiles(),
            std::chrono::seconds max_age = std::chrono::seconds(60),
            int age_buckets = 5)
        : quantiles_(quantiles)
        , max_age_(max_age)
        , age_buckets_(age_buckets)
        , sum_(0.0)
        , count_(0)
    {
        // 初始化时间桶
        rotate_buckets_.resize(age_buckets);
    }

    // 记录观测值
    void observe(double value) {
        std::lock_guard<std::mutex> lock(mutex_);

        sum_ += value;
        count_++;

        // 添加到当前时间桶
        // 注意：这里简化了实现，实际需要定期轮转桶
        if (!rotate_buckets_.empty()) {
            rotate_buckets_[0].push_back(value);
        }
    }

    // 获取分位数值
    std::map<double, double> get_quantiles() const {
        std::lock_guard<std::mutex> lock(mutex_);

        // 收集所有桶中的数据
        std::vector<double> all_values;
        for (const auto& bucket : rotate_buckets_) {
            all_values.insert(all_values.end(), bucket.begin(), bucket.end());
        }

        if (all_values.empty()) {
            return {};
        }

        // 排序以计算分位数
        std::sort(all_values.begin(), all_values.end());

        std::map<double, double> result;
        for (const auto& [quantile, _] : quantiles_) {
            size_t index = static_cast<size_t>(quantile * (all_values.size() - 1));
            result[quantile] = all_values[index];
        }

        return result;
    }

private:
    std::vector<Quantile> quantiles_;
    std::chrono::seconds max_age_;
    int age_buckets_;
    std::vector<std::vector<double>> rotate_buckets_;
    double sum_;
    uint64_t count_;
    mutable std::mutex mutex_;
};

} // namespace prometheus
```

---

#### 1.4 时序数据库原理

```cpp
// ==========================================
// 时序数据库（TSDB）核心概念
// ==========================================
//
// 时序数据特点：
// 1. 写入密集：持续产生大量数据点
// 2. 批量写入：通常按时间批量写入
// 3. 很少更新：历史数据几乎不修改
// 4. 时间范围查询：查询某段时间内的数据
// 5. 数据降采样：旧数据可降低精度存储
//
// ==========================================
// Prometheus TSDB 架构
// ==========================================
//
//                    ┌─────────────────────────────────────────────┐
//                    │              Prometheus TSDB                │
//                    ├─────────────────────────────────────────────┤
//     写入 ───────▶  │  Head Block (内存)                         │
//                    │  ├── 最近2小时的数据                        │
//                    │  ├── WAL (Write-Ahead Log)                 │
//                    │  └── 索引 (倒排索引)                        │
//                    ├─────────────────────────────────────────────┤
//                    │  Persistent Blocks (磁盘)                   │
//                    │  ├── Block 1 (2h数据, 已压缩)               │
//                    │  ├── Block 2 (2h数据, 已压缩)               │
//                    │  ├── ...                                    │
//                    │  └── 定期合并 (Compaction)                  │
//                    └─────────────────────────────────────────────┘
//
// ==========================================
// 数据压缩算法
// ==========================================
//
// 1. 时间戳压缩（Delta-of-Delta）
//    原始: 1000, 1015, 1030, 1045
//    Delta: 1000, 15, 15, 15
//    Delta-of-Delta: 1000, 15, 0, 0
//    存储位数大幅减少
//
// 2. 数值压缩（XOR编码）
//    利用相邻值相似性
//    存储与前值的XOR结果
//    对于缓慢变化的指标非常高效
//
// 3. 块压缩
//    整个块可以进一步使用通用压缩
//    如 Snappy, LZ4, ZSTD

#include <cstdint>
#include <vector>
#include <memory>
#include <fstream>

namespace tsdb {

// ==========================================
// 简易时序数据存储引擎实现
// ==========================================

// 数据点
struct Sample {
    int64_t timestamp_ms;  // 毫秒时间戳
    double value;          // 数值
};

// 时间序列
class Series {
public:
    Series(uint64_t id, const std::map<std::string, std::string>& labels)
        : id_(id), labels_(labels) {}

    // 追加数据点
    void append(int64_t timestamp_ms, double value) {
        samples_.push_back({timestamp_ms, value});
    }

    // 查询时间范围内的数据
    std::vector<Sample> query(int64_t start_ms, int64_t end_ms) const {
        std::vector<Sample> result;
        for (const auto& sample : samples_) {
            if (sample.timestamp_ms >= start_ms && sample.timestamp_ms <= end_ms) {
                result.push_back(sample);
            }
        }
        return result;
    }

    uint64_t id() const { return id_; }
    const std::map<std::string, std::string>& labels() const { return labels_; }

private:
    uint64_t id_;
    std::map<std::string, std::string> labels_;
    std::vector<Sample> samples_;
};

// ==========================================
// Delta-of-Delta 时间戳压缩
// ==========================================

class TimestampEncoder {
public:
    // 编码时间戳序列
    std::vector<uint8_t> encode(const std::vector<int64_t>& timestamps) {
        std::vector<uint8_t> result;
        if (timestamps.empty()) return result;

        // 写入第一个时间戳（完整存储）
        write_varint(result, timestamps[0]);

        if (timestamps.size() == 1) return result;

        // 写入第一个delta
        int64_t prev = timestamps[0];
        int64_t prev_delta = timestamps[1] - timestamps[0];
        write_varint(result, prev_delta);
        prev = timestamps[1];

        // 写入后续的delta-of-delta
        for (size_t i = 2; i < timestamps.size(); ++i) {
            int64_t delta = timestamps[i] - prev;
            int64_t dod = delta - prev_delta;  // Delta of Delta

            // 使用变长编码存储dod
            // 对于固定间隔的时间序列，dod通常为0
            write_zigzag(result, dod);

            prev_delta = delta;
            prev = timestamps[i];
        }

        return result;
    }

    // 解码时间戳序列
    std::vector<int64_t> decode(const std::vector<uint8_t>& data) {
        std::vector<int64_t> result;
        if (data.empty()) return result;

        size_t pos = 0;

        // 读取第一个时间戳
        int64_t first = read_varint(data, pos);
        result.push_back(first);

        if (pos >= data.size()) return result;

        // 读取第一个delta
        int64_t prev_delta = read_varint(data, pos);
        result.push_back(first + prev_delta);

        // 读取后续的delta-of-delta
        while (pos < data.size()) {
            int64_t dod = read_zigzag(data, pos);
            int64_t delta = prev_delta + dod;
            result.push_back(result.back() + delta);
            prev_delta = delta;
        }

        return result;
    }

private:
    // 变长整数编码
    void write_varint(std::vector<uint8_t>& buf, int64_t value) {
        uint64_t uvalue = static_cast<uint64_t>(value);
        while (uvalue >= 0x80) {
            buf.push_back(static_cast<uint8_t>(uvalue | 0x80));
            uvalue >>= 7;
        }
        buf.push_back(static_cast<uint8_t>(uvalue));
    }

    int64_t read_varint(const std::vector<uint8_t>& buf, size_t& pos) {
        uint64_t result = 0;
        int shift = 0;
        while (pos < buf.size()) {
            uint8_t b = buf[pos++];
            result |= static_cast<uint64_t>(b & 0x7F) << shift;
            if ((b & 0x80) == 0) break;
            shift += 7;
        }
        return static_cast<int64_t>(result);
    }

    // ZigZag编码（将负数映射为正数）
    void write_zigzag(std::vector<uint8_t>& buf, int64_t value) {
        uint64_t encoded = (static_cast<uint64_t>(value) << 1) ^
                           (static_cast<uint64_t>(value) >> 63);
        write_varint(buf, static_cast<int64_t>(encoded));
    }

    int64_t read_zigzag(const std::vector<uint8_t>& buf, size_t& pos) {
        uint64_t encoded = static_cast<uint64_t>(read_varint(buf, pos));
        return static_cast<int64_t>((encoded >> 1) ^ -(encoded & 1));
    }
};

// ==========================================
// XOR 数值压缩
// ==========================================

class ValueEncoder {
public:
    // XOR编码数值序列
    std::vector<uint8_t> encode(const std::vector<double>& values) {
        std::vector<uint8_t> result;
        if (values.empty()) return result;

        // 第一个值完整存储
        uint64_t prev_bits = double_to_bits(values[0]);
        write_bits(result, prev_bits, 64);

        for (size_t i = 1; i < values.size(); ++i) {
            uint64_t curr_bits = double_to_bits(values[i]);
            uint64_t xor_value = prev_bits ^ curr_bits;

            if (xor_value == 0) {
                // 值相同，只写入1位标记
                write_bits(result, 0, 1);
            } else {
                // 值不同，写入XOR结果
                write_bits(result, 1, 1);

                // 找到前导零和尾随零的数量
                int leading_zeros = count_leading_zeros(xor_value);
                int trailing_zeros = count_trailing_zeros(xor_value);
                int significant_bits = 64 - leading_zeros - trailing_zeros;

                // 写入元数据和有效位
                write_bits(result, leading_zeros, 6);
                write_bits(result, significant_bits, 6);
                write_bits(result, xor_value >> trailing_zeros, significant_bits);
            }

            prev_bits = curr_bits;
        }

        return result;
    }

private:
    uint64_t double_to_bits(double value) {
        uint64_t bits;
        std::memcpy(&bits, &value, sizeof(double));
        return bits;
    }

    void write_bits(std::vector<uint8_t>& buf, uint64_t value, int bits) {
        // 简化实现：实际需要位级操作
        for (int i = bits - 1; i >= 0; --i) {
            // 按位写入
        }
    }

    int count_leading_zeros(uint64_t value) {
        if (value == 0) return 64;
        int count = 0;
        while ((value & (1ULL << 63)) == 0) {
            count++;
            value <<= 1;
        }
        return count;
    }

    int count_trailing_zeros(uint64_t value) {
        if (value == 0) return 64;
        int count = 0;
        while ((value & 1) == 0) {
            count++;
            value >>= 1;
        }
        return count;
    }
};

// ==========================================
// 倒排索引
// ==========================================
//
// 目的：快速找到匹配标签条件的时间序列
//
// 结构：
// label_name:label_value -> [series_id_1, series_id_2, ...]
//
// 示例：
// method:GET -> [1, 3, 5, 7]
// method:POST -> [2, 4, 6]
// status:200 -> [1, 2, 3, 4]
// status:500 -> [5, 6, 7]
//
// 查询 method="GET" AND status="200"：
// 取交集 [1, 3, 5, 7] ∩ [1, 2, 3, 4] = [1, 3]

class InvertedIndex {
public:
    // 添加索引条目
    void add(const std::string& label_name,
             const std::string& label_value,
             uint64_t series_id) {
        std::string key = label_name + ":" + label_value;
        std::lock_guard<std::mutex> lock(mutex_);
        index_[key].insert(series_id);
    }

    // 查询匹配的序列ID
    std::set<uint64_t> lookup(const std::string& label_name,
                               const std::string& label_value) const {
        std::string key = label_name + ":" + label_value;
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = index_.find(key);
        if (it != index_.end()) {
            return it->second;
        }
        return {};
    }

    // 多条件AND查询
    std::set<uint64_t> lookup_and(
            const std::vector<std::pair<std::string, std::string>>& matchers) const {
        if (matchers.empty()) return {};

        // 获取第一个条件的结果
        auto result = lookup(matchers[0].first, matchers[0].second);

        // 与后续条件取交集
        for (size_t i = 1; i < matchers.size() && !result.empty(); ++i) {
            auto other = lookup(matchers[i].first, matchers[i].second);
            std::set<uint64_t> intersection;
            std::set_intersection(
                result.begin(), result.end(),
                other.begin(), other.end(),
                std::inserter(intersection, intersection.begin())
            );
            result = std::move(intersection);
        }

        return result;
    }

private:
    std::map<std::string, std::set<uint64_t>> index_;
    mutable std::mutex mutex_;
};

} // namespace tsdb
```

---

#### 1.5 RED/USE/Four Golden Signals 方法论

```cpp
// ==========================================
// 监控方法论对比
// ==========================================
//
// ┌─────────────────────────────────────────────────────────────────────┐
// │                    Four Golden Signals (Google SRE)                │
// ├─────────────────────────────────────────────────────────────────────┤
// │ 1. Latency（延迟）                                                 │
// │    - 成功请求的延迟                                                │
// │    - 失败请求的延迟（通常更快或更慢）                              │
// │                                                                     │
// │ 2. Traffic（流量）                                                 │
// │    - HTTP请求数/秒                                                 │
// │    - 数据库事务数/秒                                               │
// │    - 网络I/O速率                                                   │
// │                                                                     │
// │ 3. Errors（错误）                                                  │
// │    - 显式错误（HTTP 5xx）                                          │
// │    - 隐式错误（响应错误但返回200）                                 │
// │    - 策略违规（响应时间超过SLO）                                   │
// │                                                                     │
// │ 4. Saturation（饱和度）                                            │
// │    - 资源使用率                                                     │
// │    - 预测何时会达到容量上限                                        │
// └─────────────────────────────────────────────────────────────────────┘
//
// ┌─────────────────────────────────────────────────────────────────────┐
// │                    RED Method (面向服务)                           │
// ├─────────────────────────────────────────────────────────────────────┤
// │ R - Rate（速率）                                                   │
// │     每秒处理的请求数                                               │
// │     rate(http_requests_total[5m])                                  │
// │                                                                     │
// │ E - Errors（错误）                                                 │
// │     失败请求的比例                                                 │
// │     rate(http_requests_total{status=~"5.."}[5m]) /                 │
// │     rate(http_requests_total[5m])                                  │
// │                                                                     │
// │ D - Duration（持续时间）                                           │
// │     请求处理耗时分布                                               │
// │     histogram_quantile(0.99, rate(http_duration_bucket[5m]))       │
// └─────────────────────────────────────────────────────────────────────┘
//
// ┌─────────────────────────────────────────────────────────────────────┐
// │                    USE Method (面向资源)                           │
// ├─────────────────────────────────────────────────────────────────────┤
// │ U - Utilization（利用率）                                          │
// │     资源忙于处理工作的时间比例                                     │
// │     例：CPU使用率 80%                                              │
// │                                                                     │
// │ S - Saturation（饱和度）                                           │
// │     资源超出容量的程度（队列长度）                                 │
// │     例：运行队列长度 5                                             │
// │                                                                     │
// │ E - Errors（错误）                                                 │
// │     错误事件数量                                                   │
// │     例：内存分配失败 3次                                           │
// └─────────────────────────────────────────────────────────────────────┘

#include <map>
#include <string>
#include <memory>

namespace monitoring {

// ==========================================
// 监控框架：实现四大黄金信号
// ==========================================

class ServiceMetrics {
public:
    explicit ServiceMetrics(const std::string& service_name)
        : service_name_(service_name)
    {
        // 初始化四大黄金信号指标

        // 1. Latency - 使用Histogram记录延迟分布
        request_duration_ = std::make_unique<prometheus::Histogram>(
            prometheus::Histogram::exponential_buckets(0.001, 2, 15)
        );

        // 2. Traffic - 使用Counter记录请求数
        request_total_ = std::make_unique<CounterVec>();

        // 3. Errors - Counter（按错误类型标签）
        error_total_ = std::make_unique<CounterVec>();

        // 4. Saturation - Gauge记录资源使用
        saturation_gauge_ = std::make_unique<GaugeVec>();
    }

    // 记录请求
    void record_request(const std::string& method,
                        const std::string& path,
                        const std::string& status,
                        double duration_seconds) {
        // 记录延迟
        request_duration_->observe(duration_seconds);

        // 记录请求数
        request_total_->inc({
            {"method", method},
            {"path", path},
            {"status", status}
        });

        // 如果是错误状态码，记录错误
        if (status[0] == '5') {
            error_total_->inc({
                {"method", method},
                {"path", path},
                {"error_type", "server_error"}
            });
        } else if (status[0] == '4') {
            error_total_->inc({
                {"method", method},
                {"path", path},
                {"error_type", "client_error"}
            });
        }
    }

    // 更新饱和度指标
    void update_saturation(const std::string& resource, double value) {
        saturation_gauge_->set({{"resource", resource}}, value);
    }

private:
    std::string service_name_;
    std::unique_ptr<prometheus::Histogram> request_duration_;
    std::unique_ptr<CounterVec> request_total_;
    std::unique_ptr<CounterVec> error_total_;
    std::unique_ptr<GaugeVec> saturation_gauge_;
};

// ==========================================
// USE方法：资源监控
// ==========================================

class ResourceMetrics {
public:
    explicit ResourceMetrics(const std::string& resource_name)
        : resource_name_(resource_name)
    {}

    // 利用率：资源使用比例 (0-1)
    void set_utilization(double value) {
        utilization_.set(value);
    }

    // 饱和度：队列长度或等待数
    void set_saturation(double value) {
        saturation_.set(value);
    }

    // 错误：累计错误数
    void inc_errors() {
        errors_.inc();
    }

    // 导出为Prometheus格式
    std::string collect() const {
        std::ostringstream oss;

        oss << "# HELP " << resource_name_ << "_utilization "
            << "Resource utilization ratio\n";
        oss << "# TYPE " << resource_name_ << "_utilization gauge\n";
        oss << resource_name_ << "_utilization " << utilization_.value() << "\n\n";

        oss << "# HELP " << resource_name_ << "_saturation "
            << "Resource saturation (queue length)\n";
        oss << "# TYPE " << resource_name_ << "_saturation gauge\n";
        oss << resource_name_ << "_saturation " << saturation_.value() << "\n\n";

        oss << "# HELP " << resource_name_ << "_errors_total "
            << "Resource error count\n";
        oss << "# TYPE " << resource_name_ << "_errors_total counter\n";
        oss << resource_name_ << "_errors_total " << errors_.value() << "\n";

        return oss.str();
    }

private:
    std::string resource_name_;
    prometheus::Gauge utilization_;
    prometheus::Gauge saturation_;
    prometheus::Counter errors_;
};

// ==========================================
// 常见资源的USE指标采集
// ==========================================

// CPU USE指标
struct CpuMetrics {
    double utilization;      // 用户态+内核态CPU时间比例
    double saturation;       // 运行队列长度（load average）
    uint64_t errors;         // CPU相关错误（如overheating）
};

// 内存USE指标
struct MemoryMetrics {
    double utilization;      // 已使用内存/总内存
    double saturation;       // 交换活动（swap in/out）
    uint64_t errors;         // OOM kills
};

// 磁盘I/O USE指标
struct DiskMetrics {
    double utilization;      // I/O繁忙时间比例
    double saturation;       // 等待队列长度
    uint64_t errors;         // I/O错误数
};

// 网络USE指标
struct NetworkMetrics {
    double utilization;      // 带宽使用比例
    double saturation;       // 丢包、重传
    uint64_t errors;         // 网络错误
};

} // namespace monitoring
```

---

#### 1.6 Pull vs Push 模型

```cpp
// ==========================================
// 指标收集模型对比
// ==========================================
//
// Pull模型（Prometheus采用）
// ┌─────────────┐         ┌─────────────────┐
// │  应用程序   │ ◀─────  │   Prometheus    │
// │  /metrics   │  HTTP   │  (主动抓取)     │
// └─────────────┘  GET    └─────────────────┘
//
// 优点：
// - 监控系统控制抓取频率
// - 应用只需暴露端点，无需知道监控系统地址
// - 容易判断目标是否存活（抓取失败）
// - 便于调试（可直接访问/metrics）
//
// 缺点：
// - 短生命周期任务难以监控
// - 需要服务发现机制
// - 目标必须可达
//
// ─────────────────────────────────────────────
//
// Push模型（如Graphite、InfluxDB）
// ┌─────────────┐         ┌─────────────────┐
// │  应用程序   │ ──────▶ │   监控系统      │
// │             │  推送   │  (被动接收)     │
// └─────────────┘         └─────────────────┘
//
// 优点：
// - 适合短生命周期任务
// - 目标可以在NAT后面
// - 事件驱动，时效性好
//
// 缺点：
// - 应用需要知道监控系统地址
// - 难以判断目标是否存活
// - 可能造成监控系统过载
//
// ─────────────────────────────────────────────
//
// Prometheus的混合方案：Push Gateway
// ┌─────────────┐         ┌───────────────┐         ┌─────────────────┐
// │  短生命周期 │ ──────▶ │ Push Gateway  │ ◀─────  │   Prometheus    │
// │    任务     │  推送   │               │  抓取   │                 │
// └─────────────┘         └───────────────┘         └─────────────────┘

#include <string>
#include <map>
#include <chrono>
#include <thread>
#include <functional>
#include <sstream>

namespace metrics_transport {

// ==========================================
// Pull模型：HTTP端点暴露器
// ==========================================

class MetricsExposer {
public:
    MetricsExposer(const std::string& bind_address, int port)
        : bind_address_(bind_address), port_(port) {}

    // 注册指标收集函数
    void register_collector(std::function<std::string()> collector) {
        collectors_.push_back(std::move(collector));
    }

    // 处理 /metrics 请求
    std::string handle_metrics_request() {
        std::ostringstream oss;

        for (const auto& collector : collectors_) {
            oss << collector() << "\n";
        }

        return oss.str();
    }

    // 启动HTTP服务器（简化实现）
    void start() {
        // 实际实现需要使用HTTP库（如cpp-httplib）
        // 这里只展示接口
        running_ = true;
        server_thread_ = std::thread([this]() {
            while (running_) {
                // 等待HTTP请求
                // 返回 handle_metrics_request() 的结果
                std::this_thread::sleep_for(std::chrono::milliseconds(100));
            }
        });
    }

    void stop() {
        running_ = false;
        if (server_thread_.joinable()) {
            server_thread_.join();
        }
    }

private:
    std::string bind_address_;
    int port_;
    std::vector<std::function<std::string()>> collectors_;
    bool running_ = false;
    std::thread server_thread_;
};

// ==========================================
// Push模型：Push Gateway客户端
// ==========================================

class PushGatewayClient {
public:
    PushGatewayClient(const std::string& gateway_url,
                      const std::string& job_name)
        : gateway_url_(gateway_url)
        , job_name_(job_name)
    {}

    // 设置实例标签
    void set_instance(const std::string& instance) {
        instance_ = instance;
    }

    // 推送指标
    bool push(const std::string& metrics_text) {
        // 构建URL: http://gateway:9091/metrics/job/{job}/instance/{instance}
        std::string url = gateway_url_ + "/metrics/job/" + job_name_;
        if (!instance_.empty()) {
            url += "/instance/" + instance_;
        }

        // 发送HTTP POST请求
        // 实际需要使用HTTP客户端库
        return http_post(url, metrics_text);
    }

    // 删除指标（任务结束时）
    bool delete_metrics() {
        std::string url = gateway_url_ + "/metrics/job/" + job_name_;
        if (!instance_.empty()) {
            url += "/instance/" + instance_;
        }

        // 发送HTTP DELETE请求
        return http_delete(url);
    }

private:
    bool http_post(const std::string& url, const std::string& body) {
        // 实际HTTP实现
        return true;
    }

    bool http_delete(const std::string& url) {
        // 实际HTTP实现
        return true;
    }

    std::string gateway_url_;
    std::string job_name_;
    std::string instance_;
};

// ==========================================
// 使用示例：批处理任务推送指标
// ==========================================

void batch_job_example() {
    // 创建Push Gateway客户端
    PushGatewayClient client("http://pushgateway:9091", "batch_job");
    client.set_instance("batch_job_123");

    // 创建指标
    prometheus::Counter processed_items;
    prometheus::Gauge job_duration;

    auto start = std::chrono::steady_clock::now();

    // 执行批处理...
    for (int i = 0; i < 1000; ++i) {
        // 处理项目
        processed_items.inc();
    }

    auto end = std::chrono::steady_clock::now();
    double duration = std::chrono::duration<double>(end - start).count();
    job_duration.set(duration);

    // 构建指标文本
    std::ostringstream metrics;
    metrics << "# HELP batch_processed_items_total Total items processed\n";
    metrics << "# TYPE batch_processed_items_total counter\n";
    metrics << "batch_processed_items_total " << processed_items.value() << "\n\n";
    metrics << "# HELP batch_job_duration_seconds Job duration in seconds\n";
    metrics << "# TYPE batch_job_duration_seconds gauge\n";
    metrics << "batch_job_duration_seconds " << job_duration.value() << "\n";

    // 推送指标
    client.push(metrics.str());

    // 注意：可以选择保留指标或删除
    // client.delete_metrics();  // 如果不想保留
}

} // namespace metrics_transport
```

---

#### 1.7 高基数问题与解决方案

```cpp
// ==========================================
// 高基数（High Cardinality）问题
// ==========================================
//
// 什么是高基数？
// - 标签组合产生大量唯一时间序列
// - 每个唯一的标签组合 = 一个时间序列
// - 时间序列过多会导致内存和存储压力
//
// 示例：
// 假设有以下标签：
// - method: 5种 (GET, POST, PUT, DELETE, PATCH)
// - path: 1000种 (各种API路径)
// - user_id: 100万用户
// - status: 10种 (200, 201, 400, 401, 403, 404, 500, 502, 503, 504)
//
// 总时间序列数 = 5 × 1000 × 1000000 × 10 = 50,000,000,000
// 这是不可接受的！
//
// ==========================================
// 识别高基数标签
// ==========================================
//
// 危险标签（不要使用）：
// - user_id, session_id, request_id
// - 完整的URL路径（带查询参数）
// - IP地址
// - 时间戳
// - 任何无限增长的ID
//
// 安全标签：
// - method (有限枚举)
// - status_code (有限枚举)
// - 路径模板（如 /users/{id}）
// - 服务名
// - 环境（prod, staging, dev）

#include <string>
#include <regex>
#include <map>
#include <set>

namespace cardinality {

// ==========================================
// 解决方案1：路径规范化
// ==========================================

class PathNormalizer {
public:
    // 将具体路径转换为模板
    // /users/12345 -> /users/{id}
    // /orders/abc-123/items/456 -> /orders/{id}/items/{id}
    std::string normalize(const std::string& path) {
        std::string result = path;

        // 替换数字ID
        result = std::regex_replace(result,
            std::regex("/[0-9]+"), "/{id}");

        // 替换UUID
        result = std::regex_replace(result,
            std::regex("/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"),
            "/{uuid}");

        // 替换其他常见模式
        result = std::regex_replace(result,
            std::regex("/[A-Za-z0-9_-]{20,}"), "/{token}");

        return result;
    }

    // 使用路由模式匹配
    void register_route(const std::string& pattern) {
        routes_.push_back(pattern);
    }

    std::string match_route(const std::string& path) {
        for (const auto& route : routes_) {
            if (matches(path, route)) {
                return route;
            }
        }
        // 回退到通用规范化
        return normalize(path);
    }

private:
    bool matches(const std::string& path, const std::string& pattern) {
        // 简化的模式匹配实现
        // 实际应使用正则或路由库
        return false;
    }

    std::vector<std::string> routes_;
};

// ==========================================
// 解决方案2：标签值白名单
// ==========================================

class LabelWhitelist {
public:
    // 注册允许的标签值
    void allow(const std::string& label_name,
               const std::set<std::string>& allowed_values) {
        whitelist_[label_name] = allowed_values;
    }

    // 检查标签值，如果不在白名单则返回"other"
    std::string sanitize(const std::string& label_name,
                         const std::string& value) {
        auto it = whitelist_.find(label_name);
        if (it == whitelist_.end()) {
            // 没有白名单限制
            return value;
        }

        if (it->second.count(value) > 0) {
            return value;
        }

        return "other";  // 归入"其他"类别
    }

private:
    std::map<std::string, std::set<std::string>> whitelist_;
};

// 使用示例
void whitelist_example() {
    LabelWhitelist whitelist;

    // 只允许特定的HTTP方法
    whitelist.allow("method", {"GET", "POST", "PUT", "DELETE", "PATCH"});

    // 只允许常见状态码
    whitelist.allow("status", {"200", "201", "204", "400", "401", "403", "404", "500", "502", "503"});

    // 使用
    std::string method = whitelist.sanitize("method", "GET");      // "GET"
    std::string weird = whitelist.sanitize("method", "WEIRD");     // "other"
    std::string status = whitelist.sanitize("status", "418");      // "other"
}

// ==========================================
// 解决方案3：基数限制
// ==========================================

class CardinalityLimiter {
public:
    explicit CardinalityLimiter(size_t max_series)
        : max_series_(max_series) {}

    // 检查是否允许创建新的时间序列
    bool allow_new_series(const std::string& metric_name,
                          const std::map<std::string, std::string>& labels) {
        std::string key = build_key(metric_name, labels);

        std::lock_guard<std::mutex> lock(mutex_);

        // 已存在的序列
        if (seen_series_.count(key) > 0) {
            return true;
        }

        // 检查是否超过限制
        if (seen_series_.size() >= max_series_) {
            dropped_series_++;
            return false;
        }

        seen_series_.insert(key);
        return true;
    }

    // 获取统计信息
    size_t active_series() const { return seen_series_.size(); }
    size_t dropped_series() const { return dropped_series_; }

private:
    std::string build_key(const std::string& metric_name,
                          const std::map<std::string, std::string>& labels) {
        std::ostringstream oss;
        oss << metric_name << "{";
        for (const auto& [k, v] : labels) {
            oss << k << "=\"" << v << "\",";
        }
        oss << "}";
        return oss.str();
    }

    size_t max_series_;
    std::set<std::string> seen_series_;
    size_t dropped_series_ = 0;
    mutable std::mutex mutex_;
};

// ==========================================
// 解决方案4：采样
// ==========================================
//
// 对于高基数数据，可以使用采样而非全量记录
//
// 适用场景：
// - 详细的请求级日志
// - 追踪数据
// - 需要user_id等高基数标签的分析

class SampledMetrics {
public:
    explicit SampledMetrics(double sample_rate = 0.01)  // 1%采样
        : sample_rate_(sample_rate)
        , rng_(std::random_device{}())
        , dist_(0.0, 1.0)
    {}

    // 决定是否采样这个事件
    bool should_sample() {
        return dist_(rng_) < sample_rate_;
    }

    // 记录带高基数标签的指标（仅在采样时）
    void record_sampled(const std::string& user_id,
                        const std::string& request_id,
                        double latency) {
        if (!should_sample()) {
            return;
        }

        // 记录详细信息（可以包含高基数标签）
        // 这些数据通常存储在日志或追踪系统中
        // 而不是时序数据库
    }

private:
    double sample_rate_;
    std::mt19937 rng_;
    std::uniform_real_distribution<double> dist_;
};

// ==========================================
// 最佳实践总结
// ==========================================
//
// 1. 设计指标时考虑基数
//    - 计算：标签1值数 × 标签2值数 × ... = 总序列数
//    - 目标：每个指标不超过1000个时间序列
//
// 2. 使用路径模板而非完整路径
//    - /users/{id} 而不是 /users/12345
//
// 3. 避免使用用户ID作为标签
//    - 如需用户级分析，使用日志或追踪系统
//
// 4. 对无限枚举使用白名单
//    - 未知值归入"other"类别
//
// 5. 监控基数
//    - 监控 prometheus_tsdb_head_series
//    - 设置告警：序列数超过阈值
//
// 6. 使用relabel_configs过滤高基数标签
//    - 在Prometheus配置中过滤不需要的标签

} // namespace cardinality
```

---

#### 1.8 本周练习任务

```cpp
// ==========================================
// 第一周练习任务
// ==========================================

/*
练习1：实现基础指标类型
--------------------------------------
目标：从零实现Counter、Gauge、Histogram

要求：
1. Counter必须是线程安全的，只能增加
2. Gauge必须是线程安全的，可增可减
3. Histogram需要支持自定义桶边界
4. 所有类型都能导出Prometheus文本格式

验证：
- 多线程并发写入测试
- 导出格式与Prometheus兼容
*/

/*
练习2：实现简易时序存储
--------------------------------------
目标：理解时序数据库的核心机制

要求：
1. 实现时间序列的内存存储
2. 实现倒排索引
3. 支持基于标签的查询
4. 实现简单的时间范围查询

验证：
- 插入10000个数据点
- 查询特定标签组合的序列
- 验证时间范围查询正确性
*/

/*
练习3：实现服务监控框架
--------------------------------------
目标：构建可复用的服务监控组件

要求：
1. 实现ServiceMetrics类
2. 支持Four Golden Signals
3. 提供便捷的请求记录API
4. 暴露/metrics HTTP端点

验证：
- 模拟HTTP请求并记录指标
- 验证指标值正确性
- 通过curl访问/metrics端点
*/

/*
练习4：高基数控制
--------------------------------------
目标：理解并解决高基数问题

要求：
1. 实现PathNormalizer
2. 实现LabelWhitelist
3. 实现CardinalityLimiter
4. 编写测试验证功能

验证：
- 路径规范化测试
- 标签白名单测试
- 基数限制测试
*/
```

---

#### 1.9 本周知识检验

```
思考题1：为什么Prometheus选择Pull模型而不是Push模型？
提示：从可靠性、简单性、目标健康检测等角度思考。

思考题2：Counter为什么总是单调递增？rate()函数如何处理Counter重置？
提示：思考进程重启场景，以及rate的计算方式。

思考题3：什么情况下应该使用Histogram，什么情况下使用Summary？
提示：考虑聚合需求、分位数精度、资源消耗。

思考题4：如何评估一个标签是否会导致高基数问题？
提示：计算标签值的可能数量，考虑增长趋势。

思考题5：为什么Prometheus的Histogram桶是累积的而不是独立的？
提示：考虑histogram_quantile()的计算方式。

实践题1：设计一个API网关的监控指标方案
要求：列出所有需要的指标及其标签

实践题2：计算以下场景的时间序列数量
- 5个服务，每个服务10个实例
- 监控HTTP请求，标签包括：method(5种), path(100种), status(10种)
- 每个实例独立采集
```

### 第二周：C++指标库深度实现

**学习目标**：
- 深入理解指标库的内部实现机制
- 掌握线程安全的原子操作和无锁编程
- 学会设计高性能的指标收集系统
- 理解内存模型对并发性能的影响

**阅读材料**：
- [ ] prometheus-cpp源码（core/目录）
- [ ] 《C++ Concurrency in Action》原子操作章节
- [ ] Intel Lock-free Programming文档
- [ ] OpenTelemetry C++ SDK指标部分

---

#### 2.1 生产级指标库架构设计

```cpp
// ==========================================
// 生产级指标库架构概览
// ==========================================
//
// ┌─────────────────────────────────────────────────────────────────────┐
// │                         Registry（注册表）                          │
// │  - 管理所有指标的生命周期                                           │
// │  - 提供统一的收集接口                                               │
// │  - 支持指标去重和冲突检测                                           │
// └─────────────────────────────────────────────────────────────────────┘
//                                    │
//          ┌─────────────────────────┼─────────────────────────┐
//          ▼                         ▼                         ▼
// ┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
// │   MetricFamily  │      │   MetricFamily  │      │   MetricFamily  │
// │  (Counter类型)  │      │  (Gauge类型)    │      │ (Histogram类型) │
// └─────────────────┘      └─────────────────┘      └─────────────────┘
//          │                         │                         │
//    ┌─────┴─────┐             ┌─────┴─────┐             ┌─────┴─────┐
//    ▼           ▼             ▼           ▼             ▼           ▼
// ┌──────┐   ┌──────┐      ┌──────┐   ┌──────┐      ┌──────┐   ┌──────┐
// │Child │   │Child │      │Child │   │Child │      │Child │   │Child │
// │label1│   │label2│      │label1│   │label2│      │label1│   │label2│
// └──────┘   └──────┘      └──────┘   └──────┘      └──────┘   └──────┘
//
// 设计原则：
// 1. 分离关注点：Family管理标签维度，Child存储实际数据
// 2. 延迟创建：只在第一次使用时创建Child
// 3. 线程安全：最小化锁的范围
// 4. 零拷贝导出：直接序列化，避免中间结构

#include <atomic>
#include <mutex>
#include <shared_mutex>
#include <map>
#include <unordered_map>
#include <vector>
#include <string>
#include <memory>
#include <functional>
#include <sstream>
#include <chrono>
#include <algorithm>
#include <stdexcept>
#include <cstring>
#include <random>

namespace metrics {

// ==========================================
// 基础类型定义
// ==========================================

// 标签集（有序，保证一致性）
using Labels = std::map<std::string, std::string>;

// 标签名列表
using LabelNames = std::vector<std::string>;

// 哈希函数：用于标签集的快速查找
struct LabelsHash {
    size_t operator()(const Labels& labels) const {
        size_t hash = 0;
        for (const auto& [key, value] : labels) {
            // 组合多个字符串的哈希值
            hash ^= std::hash<std::string>{}(key) + 0x9e3779b9 + (hash << 6) + (hash >> 2);
            hash ^= std::hash<std::string>{}(value) + 0x9e3779b9 + (hash << 6) + (hash >> 2);
        }
        return hash;
    }
};

// ==========================================
// 辅助函数
// ==========================================

// 格式化标签为Prometheus格式
inline std::string formatLabels(const Labels& labels) {
    if (labels.empty()) return "";

    std::ostringstream oss;
    oss << "{";
    bool first = true;
    for (const auto& [key, value] : labels) {
        if (!first) oss << ",";
        // 转义特殊字符
        oss << key << "=\"";
        for (char c : value) {
            switch (c) {
                case '\\': oss << "\\\\"; break;
                case '"':  oss << "\\\""; break;
                case '\n': oss << "\\n"; break;
                default:   oss << c;
            }
        }
        oss << "\"";
        first = false;
    }
    oss << "}";
    return oss.str();
}

// 验证指标名称
inline bool isValidMetricName(const std::string& name) {
    if (name.empty()) return false;

    // 第一个字符必须是字母或下划线
    if (!std::isalpha(name[0]) && name[0] != '_') {
        return false;
    }

    // 后续字符可以是字母、数字、下划线
    for (size_t i = 1; i < name.size(); ++i) {
        if (!std::isalnum(name[i]) && name[i] != '_') {
            return false;
        }
    }

    // 不能以__开头（保留给内部使用）
    if (name.size() >= 2 && name[0] == '_' && name[1] == '_') {
        return false;
    }

    return true;
}

// 验证标签名称
inline bool isValidLabelName(const std::string& name) {
    if (name.empty()) return false;

    // 与指标名称规则相同
    if (!std::isalpha(name[0]) && name[0] != '_') {
        return false;
    }

    for (size_t i = 1; i < name.size(); ++i) {
        if (!std::isalnum(name[i]) && name[i] != '_') {
            return false;
        }
    }

    // __开头的标签保留给内部使用
    if (name.size() >= 2 && name[0] == '_' && name[1] == '_') {
        return false;
    }

    return true;
}
```

---

#### 2.2 线程安全的原子Counter实现

```cpp
// ==========================================
// Counter 实现：深入原子操作
// ==========================================
//
// 设计考量：
// 1. 使用 atomic<double> 还是 atomic<int64_t>?
//    - double: 直接支持浮点增量
//    - int64_t: 硬件原生支持，性能更好
//    - 选择：double，因为Prometheus规范要求支持浮点数
//
// 2. 内存顺序选择：
//    - memory_order_relaxed: 最弱保证，性能最好
//    - memory_order_acquire/release: 同步点
//    - memory_order_seq_cst: 最强保证，性能最差
//    - 选择：Counter只做累加，relaxed足够
//
// 3. CAS操作 vs fetch_add:
//    - fetch_add: 整数原子操作支持
//    - CAS: 浮点数需要自己实现
//    - 选择：CAS循环实现浮点累加

class Counter {
public:
    // 默认构造函数
    Counter() : value_(0.0) {}

    // 禁止拷贝（原子变量不可拷贝）
    Counter(const Counter&) = delete;
    Counter& operator=(const Counter&) = delete;

    // 允许移动
    Counter(Counter&& other) noexcept
        : value_(other.value_.load(std::memory_order_relaxed)) {}

    Counter& operator=(Counter&& other) noexcept {
        if (this != &other) {
            value_.store(other.value_.load(std::memory_order_relaxed),
                        std::memory_order_relaxed);
        }
        return *this;
    }

    // 增加计数
    // 使用CAS循环实现线程安全的浮点数累加
    void inc(double delta = 1.0) {
        // Counter语义：只能增加
        if (delta < 0) {
            throw std::invalid_argument(
                "Counter::inc() delta必须 >= 0，当前值: " + std::to_string(delta)
            );
        }

        // CAS循环：Compare-And-Swap
        // 1. 读取当前值
        // 2. 计算新值
        // 3. 尝试原子更新
        // 4. 如果失败（其他线程修改了值），重试
        double current = value_.load(std::memory_order_relaxed);
        while (!value_.compare_exchange_weak(
            current,                        // 期望值（会被更新为实际值）
            current + delta,                // 新值
            std::memory_order_relaxed,      // 成功时的内存顺序
            std::memory_order_relaxed       // 失败时的内存顺序
        )) {
            // compare_exchange_weak可能会虚假失败
            // 循环会自动重试
        }
    }

    // 批量增加（优化：减少原子操作次数）
    void add_batch(const std::vector<double>& values) {
        // 先在本地求和，再一次性原子操作
        double total = 0.0;
        for (double v : values) {
            if (v < 0) {
                throw std::invalid_argument("Counter不能接受负值");
            }
            total += v;
        }

        // 只需一次CAS操作
        inc(total);
    }

    // 获取当前值
    double value() const noexcept {
        return value_.load(std::memory_order_relaxed);
    }

    // 重置为0（仅用于测试或进程重启模拟）
    void reset() noexcept {
        value_.store(0.0, std::memory_order_relaxed);
    }

private:
    std::atomic<double> value_;
};

// ==========================================
// CounterVec：带标签的Counter集合
// ==========================================
//
// 设计挑战：
// 1. 如何快速查找已存在的Counter?
// 2. 如何处理新标签组合的创建?
// 3. 如何在高并发下保证正确性?
//
// 解决方案：
// - 读写锁（shared_mutex）：读多写少的场景优化
// - 延迟创建：只在首次使用时创建Counter
// - 双重检查锁定：减少锁竞争

class CounterVec {
public:
    CounterVec(const std::string& name,
               const std::string& help,
               const LabelNames& label_names)
        : name_(name)
        , help_(help)
        , label_names_(label_names)
    {
        // 验证指标名称
        if (!isValidMetricName(name)) {
            throw std::invalid_argument("无效的指标名称: " + name);
        }

        // 验证标签名称
        for (const auto& label : label_names) {
            if (!isValidLabelName(label)) {
                throw std::invalid_argument("无效的标签名称: " + label);
            }
        }
    }

    // 获取或创建指定标签的Counter
    Counter& labels(const Labels& label_values) {
        // 验证标签完整性
        if (label_values.size() != label_names_.size()) {
            throw std::invalid_argument(
                "标签数量不匹配：期望 " + std::to_string(label_names_.size()) +
                "，实际 " + std::to_string(label_values.size())
            );
        }

        for (const auto& name : label_names_) {
            if (label_values.find(name) == label_values.end()) {
                throw std::invalid_argument("缺少标签: " + name);
            }
        }

        // 快速路径：读锁检查是否已存在
        {
            std::shared_lock<std::shared_mutex> read_lock(mutex_);
            auto it = counters_.find(label_values);
            if (it != counters_.end()) {
                return *it->second;
            }
        }

        // 慢速路径：写锁创建新Counter
        {
            std::unique_lock<std::shared_mutex> write_lock(mutex_);

            // 双重检查：可能其他线程已经创建
            auto it = counters_.find(label_values);
            if (it != counters_.end()) {
                return *it->second;
            }

            // 创建新Counter
            auto counter = std::make_unique<Counter>();
            Counter& ref = *counter;
            counters_[label_values] = std::move(counter);
            return ref;
        }
    }

    // 便捷方法：直接增加
    void inc(const Labels& label_values, double delta = 1.0) {
        labels(label_values).inc(delta);
    }

    // 移除指定标签的Counter
    bool remove(const Labels& label_values) {
        std::unique_lock<std::shared_mutex> lock(mutex_);
        return counters_.erase(label_values) > 0;
    }

    // 清除所有Counter
    void clear() {
        std::unique_lock<std::shared_mutex> lock(mutex_);
        counters_.clear();
    }

    // 获取当前序列数量
    size_t size() const {
        std::shared_lock<std::shared_mutex> lock(mutex_);
        return counters_.size();
    }

    // 收集所有指标
    std::string collect() const {
        std::ostringstream oss;

        oss << "# HELP " << name_ << " " << help_ << "\n";
        oss << "# TYPE " << name_ << " counter\n";

        std::shared_lock<std::shared_mutex> lock(mutex_);
        for (const auto& [labels, counter] : counters_) {
            oss << name_ << formatLabels(labels)
                << " " << counter->value() << "\n";
        }

        return oss.str();
    }

    // 获取指标名称
    const std::string& name() const { return name_; }

    // 获取帮助信息
    const std::string& help() const { return help_; }

private:
    std::string name_;
    std::string help_;
    LabelNames label_names_;

    mutable std::shared_mutex mutex_;
    std::map<Labels, std::unique_ptr<Counter>> counters_;
};
```

---

#### 2.3 高性能Gauge实现

```cpp
// ==========================================
// Gauge 实现：支持任意值设置
// ==========================================

class Gauge {
public:
    Gauge() : value_(0.0) {}

    Gauge(const Gauge&) = delete;
    Gauge& operator=(const Gauge&) = delete;

    Gauge(Gauge&& other) noexcept
        : value_(other.value_.load(std::memory_order_relaxed)) {}

    // 设置为指定值
    void set(double value) noexcept {
        value_.store(value, std::memory_order_relaxed);
    }

    // 增加
    void inc(double delta = 1.0) noexcept {
        double current = value_.load(std::memory_order_relaxed);
        while (!value_.compare_exchange_weak(
            current,
            current + delta,
            std::memory_order_relaxed,
            std::memory_order_relaxed
        ));
    }

    // 减少
    void dec(double delta = 1.0) noexcept {
        inc(-delta);
    }

    // 设置为当前Unix时间戳
    void set_to_current_time() noexcept {
        auto now = std::chrono::system_clock::now();
        auto epoch = now.time_since_epoch();
        auto seconds = std::chrono::duration<double>(epoch);
        set(seconds.count());
    }

    // 获取当前值
    double value() const noexcept {
        return value_.load(std::memory_order_relaxed);
    }

private:
    std::atomic<double> value_;
};

// ==========================================
// GaugeVec：带标签的Gauge集合
// ==========================================

class GaugeVec {
public:
    GaugeVec(const std::string& name,
             const std::string& help,
             const LabelNames& label_names)
        : name_(name)
        , help_(help)
        , label_names_(label_names)
    {}

    Gauge& labels(const Labels& label_values) {
        // 快速路径
        {
            std::shared_lock<std::shared_mutex> read_lock(mutex_);
            auto it = gauges_.find(label_values);
            if (it != gauges_.end()) {
                return *it->second;
            }
        }

        // 慢速路径
        {
            std::unique_lock<std::shared_mutex> write_lock(mutex_);
            auto it = gauges_.find(label_values);
            if (it != gauges_.end()) {
                return *it->second;
            }

            auto gauge = std::make_unique<Gauge>();
            Gauge& ref = *gauge;
            gauges_[label_values] = std::move(gauge);
            return ref;
        }
    }

    void set(const Labels& label_values, double value) {
        labels(label_values).set(value);
    }

    std::string collect() const {
        std::ostringstream oss;

        oss << "# HELP " << name_ << " " << help_ << "\n";
        oss << "# TYPE " << name_ << " gauge\n";

        std::shared_lock<std::shared_mutex> lock(mutex_);
        for (const auto& [labels, gauge] : gauges_) {
            oss << name_ << formatLabels(labels)
                << " " << gauge->value() << "\n";
        }

        return oss.str();
    }

private:
    std::string name_;
    std::string help_;
    LabelNames label_names_;
    mutable std::shared_mutex mutex_;
    std::map<Labels, std::unique_ptr<Gauge>> gauges_;
};

// ==========================================
// 回调Gauge：动态值采集
// ==========================================
//
// 场景：有些指标不需要主动设置，而是在采集时计算
// 例如：当前内存使用、打开的文件描述符数等

class CallbackGauge {
public:
    using ValueCallback = std::function<double()>;

    CallbackGauge(const std::string& name,
                  const std::string& help,
                  ValueCallback callback)
        : name_(name)
        , help_(help)
        , callback_(std::move(callback))
    {}

    // 采集时调用回调获取当前值
    std::string collect() const {
        std::ostringstream oss;

        oss << "# HELP " << name_ << " " << help_ << "\n";
        oss << "# TYPE " << name_ << " gauge\n";
        oss << name_ << " " << callback_() << "\n";

        return oss.str();
    }

private:
    std::string name_;
    std::string help_;
    ValueCallback callback_;
};

// 使用示例：收集进程信息
/*
// 当前打开的文件描述符数
auto open_fds = std::make_shared<CallbackGauge>(
    "process_open_fds",
    "Number of open file descriptors",
    []() -> double {
        // Linux: 读取 /proc/self/fd 目录
        int count = 0;
        DIR* dir = opendir("/proc/self/fd");
        if (dir) {
            while (readdir(dir)) count++;
            closedir(dir);
        }
        return static_cast<double>(count - 2);  // 减去 . 和 ..
    }
);

// 当前虚拟内存大小
auto virtual_memory = std::make_shared<CallbackGauge>(
    "process_virtual_memory_bytes",
    "Virtual memory size in bytes",
    []() -> double {
        // Linux: 读取 /proc/self/status
        std::ifstream status("/proc/self/status");
        std::string line;
        while (std::getline(status, line)) {
            if (line.find("VmSize:") == 0) {
                size_t kb = std::stoull(line.substr(7));
                return static_cast<double>(kb * 1024);
            }
        }
        return 0.0;
    }
);
*/
```

---

#### 2.4 优化的Histogram实现

```cpp
// ==========================================
// Histogram 深度实现
// ==========================================
//
// 性能优化策略：
// 1. 使用原子操作减少锁竞争
// 2. 预计算桶索引
// 3. 批量观测优化
// 4. 内存对齐优化

class Histogram {
public:
    // 预定义的桶边界模板
    static std::vector<double> defaultBuckets() {
        return {0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0};
    }

    static std::vector<double> linearBuckets(double start, double width, int count) {
        std::vector<double> buckets;
        buckets.reserve(count);
        for (int i = 0; i < count; ++i) {
            buckets.push_back(start + width * i);
        }
        return buckets;
    }

    static std::vector<double> exponentialBuckets(double start, double factor, int count) {
        std::vector<double> buckets;
        buckets.reserve(count);
        double current = start;
        for (int i = 0; i < count; ++i) {
            buckets.push_back(current);
            current *= factor;
        }
        return buckets;
    }

    explicit Histogram(const std::vector<double>& bucket_bounds = defaultBuckets())
        : bucket_bounds_(bucket_bounds)
        , sum_(0.0)
        , count_(0)
    {
        // 验证桶边界
        if (bucket_bounds_.empty()) {
            throw std::invalid_argument("桶边界不能为空");
        }

        if (!std::is_sorted(bucket_bounds_.begin(), bucket_bounds_.end())) {
            throw std::invalid_argument("桶边界必须升序排列");
        }

        // 初始化桶计数器（使用原子变量）
        bucket_counts_.resize(bucket_bounds_.size() + 1);  // +1 for +Inf
        for (auto& count : bucket_counts_) {
            count.store(0, std::memory_order_relaxed);
        }
    }

    // 记录观测值（高频调用，需要优化）
    void observe(double value) {
        // 1. 使用二分查找定位桶（O(log n)）
        auto it = std::upper_bound(bucket_bounds_.begin(), bucket_bounds_.end(), value);
        size_t bucket_index = std::distance(bucket_bounds_.begin(), it);

        // 2. 原子更新桶计数
        // 注意：Histogram的桶是累积的，所以需要更新该桶及之后的所有桶
        // 这里我们存储的是非累积计数，在导出时计算累积值
        bucket_counts_[bucket_index].fetch_add(1, std::memory_order_relaxed);

        // 3. 更新sum（使用CAS）
        double current_sum = sum_.load(std::memory_order_relaxed);
        while (!sum_.compare_exchange_weak(
            current_sum,
            current_sum + value,
            std::memory_order_relaxed,
            std::memory_order_relaxed
        ));

        // 4. 更新count
        count_.fetch_add(1, std::memory_order_relaxed);
    }

    // 批量观测（性能优化）
    void observe_batch(const std::vector<double>& values) {
        // 本地聚合
        std::vector<uint64_t> local_counts(bucket_bounds_.size() + 1, 0);
        double local_sum = 0.0;

        for (double value : values) {
            auto it = std::upper_bound(bucket_bounds_.begin(), bucket_bounds_.end(), value);
            size_t bucket_index = std::distance(bucket_bounds_.begin(), it);
            local_counts[bucket_index]++;
            local_sum += value;
        }

        // 批量更新原子变量
        for (size_t i = 0; i < local_counts.size(); ++i) {
            if (local_counts[i] > 0) {
                bucket_counts_[i].fetch_add(local_counts[i], std::memory_order_relaxed);
            }
        }

        double current_sum = sum_.load(std::memory_order_relaxed);
        while (!sum_.compare_exchange_weak(
            current_sum,
            current_sum + local_sum,
            std::memory_order_relaxed,
            std::memory_order_relaxed
        ));

        count_.fetch_add(values.size(), std::memory_order_relaxed);
    }

    // 获取观测数据
    struct Data {
        std::vector<double> bucket_bounds;
        std::vector<uint64_t> bucket_counts;  // 累积计数
        double sum;
        uint64_t count;
    };

    Data collect() const {
        Data data;
        data.bucket_bounds = bucket_bounds_;
        data.sum = sum_.load(std::memory_order_relaxed);
        data.count = count_.load(std::memory_order_relaxed);

        // 计算累积计数
        data.bucket_counts.reserve(bucket_counts_.size());
        uint64_t cumulative = 0;
        for (const auto& count : bucket_counts_) {
            cumulative += count.load(std::memory_order_relaxed);
            data.bucket_counts.push_back(cumulative);
        }

        return data;
    }

    // 格式化为Prometheus文本格式
    std::string format(const std::string& name,
                       const Labels& labels = {}) const {
        std::ostringstream oss;
        auto data = collect();

        auto format_label_string = [&labels](const std::string& extra = "") -> std::string {
            std::ostringstream label_oss;
            if (labels.empty() && extra.empty()) return "";

            label_oss << "{";
            bool first = true;
            for (const auto& [k, v] : labels) {
                if (!first) label_oss << ",";
                label_oss << k << "=\"" << v << "\"";
                first = false;
            }
            if (!extra.empty()) {
                if (!first) label_oss << ",";
                label_oss << extra;
            }
            label_oss << "}";
            return label_oss.str();
        };

        // 输出桶
        for (size_t i = 0; i < data.bucket_bounds.size(); ++i) {
            oss << name << "_bucket"
                << format_label_string("le=\"" + std::to_string(data.bucket_bounds[i]) + "\"")
                << " " << data.bucket_counts[i] << "\n";
        }

        // +Inf 桶
        oss << name << "_bucket"
            << format_label_string("le=\"+Inf\"")
            << " " << data.bucket_counts.back() << "\n";

        // sum 和 count
        oss << name << "_sum" << format_label_string() << " " << data.sum << "\n";
        oss << name << "_count" << format_label_string() << " " << data.count << "\n";

        return oss.str();
    }

private:
    std::vector<double> bucket_bounds_;
    std::vector<std::atomic<uint64_t>> bucket_counts_;
    std::atomic<double> sum_;
    std::atomic<uint64_t> count_;
};

// ==========================================
// HistogramVec：带标签的Histogram集合
// ==========================================

class HistogramVec {
public:
    HistogramVec(const std::string& name,
                 const std::string& help,
                 const LabelNames& label_names,
                 const std::vector<double>& bucket_bounds = Histogram::defaultBuckets())
        : name_(name)
        , help_(help)
        , label_names_(label_names)
        , bucket_bounds_(bucket_bounds)
    {}

    Histogram& labels(const Labels& label_values) {
        {
            std::shared_lock<std::shared_mutex> read_lock(mutex_);
            auto it = histograms_.find(label_values);
            if (it != histograms_.end()) {
                return *it->second;
            }
        }

        {
            std::unique_lock<std::shared_mutex> write_lock(mutex_);
            auto it = histograms_.find(label_values);
            if (it != histograms_.end()) {
                return *it->second;
            }

            auto histogram = std::make_unique<Histogram>(bucket_bounds_);
            Histogram& ref = *histogram;
            histograms_[label_values] = std::move(histogram);
            return ref;
        }
    }

    void observe(const Labels& label_values, double value) {
        labels(label_values).observe(value);
    }

    std::string collect() const {
        std::ostringstream oss;

        oss << "# HELP " << name_ << " " << help_ << "\n";
        oss << "# TYPE " << name_ << " histogram\n";

        std::shared_lock<std::shared_mutex> lock(mutex_);
        for (const auto& [labels, histogram] : histograms_) {
            oss << histogram->format(name_, labels);
        }

        return oss.str();
    }

private:
    std::string name_;
    std::string help_;
    LabelNames label_names_;
    std::vector<double> bucket_bounds_;
    mutable std::shared_mutex mutex_;
    std::map<Labels, std::unique_ptr<Histogram>> histograms_;
};
```

---

#### 2.5 Summary实现（客户端分位数）

```cpp
// ==========================================
// Summary 实现
// ==========================================
//
// Summary vs Histogram:
// - Summary在客户端计算分位数，不可聚合
// - Histogram在服务端计算分位数，可以聚合
//
// Summary适用场景：
// - 需要精确的分位数
// - 单实例场景
// - 对延迟敏感的场景
//
// 实现方式：
// - 滑动时间窗口
// - 分桶存储样本
// - 定期轮转桶

class Summary {
public:
    // 分位数定义：{分位数, 误差}
    using Quantile = std::pair<double, double>;

    static std::vector<Quantile> defaultQuantiles() {
        return {
            {0.5, 0.05},    // 中位数，±5%误差
            {0.9, 0.01},    // P90，±1%误差
            {0.95, 0.005},  // P95，±0.5%误差
            {0.99, 0.001}   // P99，±0.1%误差
        };
    }

    Summary(const std::vector<Quantile>& quantiles = defaultQuantiles(),
            std::chrono::seconds max_age = std::chrono::seconds(60),
            int age_buckets = 5)
        : quantiles_(quantiles)
        , max_age_(max_age)
        , age_buckets_(age_buckets)
        , sum_(0.0)
        , count_(0)
        , current_bucket_(0)
    {
        buckets_.resize(age_buckets);
        bucket_start_time_ = std::chrono::steady_clock::now();
        bucket_duration_ = max_age / age_buckets;
    }

    // 记录观测值
    void observe(double value) {
        std::lock_guard<std::mutex> lock(mutex_);

        // 检查是否需要轮转桶
        maybe_rotate();

        // 添加到当前桶
        buckets_[current_bucket_].push_back(value);

        // 更新统计
        sum_ += value;
        count_++;
    }

    // 获取分位数
    std::map<double, double> get_quantiles() const {
        std::lock_guard<std::mutex> lock(mutex_);

        // 收集所有桶的数据
        std::vector<double> all_values;
        for (const auto& bucket : buckets_) {
            all_values.insert(all_values.end(), bucket.begin(), bucket.end());
        }

        if (all_values.empty()) {
            return {};
        }

        // 排序
        std::sort(all_values.begin(), all_values.end());

        // 计算分位数
        std::map<double, double> result;
        for (const auto& [q, _] : quantiles_) {
            size_t index = static_cast<size_t>(q * (all_values.size() - 1));
            result[q] = all_values[index];
        }

        return result;
    }

    // 获取sum
    double get_sum() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return sum_;
    }

    // 获取count
    uint64_t get_count() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return count_;
    }

    // 格式化为Prometheus文本格式
    std::string format(const std::string& name,
                       const Labels& labels = {}) const {
        std::ostringstream oss;

        auto quantile_values = get_quantiles();

        auto format_label_string = [&labels](const std::string& extra = "") -> std::string {
            std::ostringstream label_oss;
            if (labels.empty() && extra.empty()) return "";

            label_oss << "{";
            bool first = true;
            for (const auto& [k, v] : labels) {
                if (!first) label_oss << ",";
                label_oss << k << "=\"" << v << "\"";
                first = false;
            }
            if (!extra.empty()) {
                if (!first) label_oss << ",";
                label_oss << extra;
            }
            label_oss << "}";
            return label_oss.str();
        };

        // 输出分位数
        for (const auto& [q, value] : quantile_values) {
            oss << name
                << format_label_string("quantile=\"" + std::to_string(q) + "\"")
                << " " << value << "\n";
        }

        // 输出sum和count
        oss << name << "_sum" << format_label_string() << " " << get_sum() << "\n";
        oss << name << "_count" << format_label_string() << " " << get_count() << "\n";

        return oss.str();
    }

private:
    // 检查并执行桶轮转
    void maybe_rotate() {
        auto now = std::chrono::steady_clock::now();
        auto elapsed = now - bucket_start_time_;

        while (elapsed >= bucket_duration_) {
            // 移动到下一个桶
            current_bucket_ = (current_bucket_ + 1) % age_buckets_;

            // 清空旧桶（这个桶的数据已经过期）
            buckets_[current_bucket_].clear();

            bucket_start_time_ += bucket_duration_;
            elapsed = now - bucket_start_time_;
        }
    }

    std::vector<Quantile> quantiles_;
    std::chrono::seconds max_age_;
    int age_buckets_;
    std::chrono::seconds bucket_duration_;

    mutable std::mutex mutex_;
    std::vector<std::vector<double>> buckets_;
    int current_bucket_;
    std::chrono::steady_clock::time_point bucket_start_time_;

    double sum_;
    uint64_t count_;
};
```

---

#### 2.6 指标注册表与收集器

```cpp
// ==========================================
// Collectable 接口
// ==========================================

class Collectable {
public:
    virtual ~Collectable() = default;

    // 收集指标并返回Prometheus格式文本
    virtual std::string collect() const = 0;

    // 获取指标名称（用于去重检测）
    virtual std::string name() const = 0;
};

// ==========================================
// Registry：指标注册表
// ==========================================
//
// 职责：
// 1. 管理所有指标的注册和生命周期
// 2. 防止同名指标重复注册
// 3. 统一收集所有指标

class Registry {
public:
    // 获取默认全局Registry
    static Registry& default_registry() {
        static Registry instance;
        return instance;
    }

    // 注册Counter
    std::shared_ptr<CounterVec> register_counter(
            const std::string& name,
            const std::string& help,
            const LabelNames& labels = {}) {

        std::unique_lock<std::shared_mutex> lock(mutex_);

        // 检查是否已存在
        if (registered_names_.count(name) > 0) {
            throw std::runtime_error("指标已注册: " + name);
        }

        auto counter = std::make_shared<CounterVec>(name, help, labels);
        collectables_.push_back(counter);
        registered_names_.insert(name);

        return counter;
    }

    // 注册Gauge
    std::shared_ptr<GaugeVec> register_gauge(
            const std::string& name,
            const std::string& help,
            const LabelNames& labels = {}) {

        std::unique_lock<std::shared_mutex> lock(mutex_);

        if (registered_names_.count(name) > 0) {
            throw std::runtime_error("指标已注册: " + name);
        }

        auto gauge = std::make_shared<GaugeVec>(name, help, labels);
        // 需要包装为Collectable
        registered_names_.insert(name);

        return gauge;
    }

    // 注册Histogram
    std::shared_ptr<HistogramVec> register_histogram(
            const std::string& name,
            const std::string& help,
            const LabelNames& labels = {},
            const std::vector<double>& buckets = Histogram::defaultBuckets()) {

        std::unique_lock<std::shared_mutex> lock(mutex_);

        if (registered_names_.count(name) > 0) {
            throw std::runtime_error("指标已注册: " + name);
        }

        auto histogram = std::make_shared<HistogramVec>(name, help, labels, buckets);
        registered_names_.insert(name);

        return histogram;
    }

    // 注册自定义Collectable
    void register_collectable(std::shared_ptr<Collectable> collectable) {
        std::unique_lock<std::shared_mutex> lock(mutex_);

        std::string name = collectable->name();
        if (registered_names_.count(name) > 0) {
            throw std::runtime_error("指标已注册: " + name);
        }

        collectables_.push_back(collectable);
        registered_names_.insert(name);
    }

    // 收集所有指标
    std::string collect() const {
        std::ostringstream oss;

        std::shared_lock<std::shared_mutex> lock(mutex_);
        for (const auto& collectable : collectables_) {
            oss << collectable->collect() << "\n";
        }

        return oss.str();
    }

    // 取消注册
    bool unregister(const std::string& name) {
        std::unique_lock<std::shared_mutex> lock(mutex_);

        if (registered_names_.erase(name) > 0) {
            collectables_.erase(
                std::remove_if(collectables_.begin(), collectables_.end(),
                    [&name](const std::shared_ptr<Collectable>& c) {
                        return c->name() == name;
                    }),
                collectables_.end()
            );
            return true;
        }
        return false;
    }

    // 清除所有注册
    void clear() {
        std::unique_lock<std::shared_mutex> lock(mutex_);
        collectables_.clear();
        registered_names_.clear();
    }

private:
    mutable std::shared_mutex mutex_;
    std::vector<std::shared_ptr<Collectable>> collectables_;
    std::set<std::string> registered_names_;
};

// ==========================================
// 便捷宏
// ==========================================

#define DEFINE_COUNTER(var, name, help, ...) \
    static auto var = metrics::Registry::default_registry().register_counter( \
        name, help, {__VA_ARGS__})

#define DEFINE_GAUGE(var, name, help, ...) \
    static auto var = metrics::Registry::default_registry().register_gauge( \
        name, help, {__VA_ARGS__})

#define DEFINE_HISTOGRAM(var, name, help, labels, buckets) \
    static auto var = metrics::Registry::default_registry().register_histogram( \
        name, help, labels, buckets)

// 使用示例
/*
// 定义指标
DEFINE_COUNTER(http_requests_total, "http_requests_total",
               "Total HTTP requests", "method", "path", "status");

DEFINE_HISTOGRAM(http_request_duration, "http_request_duration_seconds",
                 "HTTP request duration",
                 {"method", "path"},
                 Histogram::exponentialBuckets(0.001, 2, 10));

// 使用指标
http_requests_total->inc({{"method", "GET"}, {"path", "/api"}, {"status", "200"}});
http_request_duration->observe({{"method", "GET"}, {"path", "/api"}}, 0.123);
*/
```

---

#### 2.7 RAII工具类

```cpp
// ==========================================
// ScopedTimer：RAII计时器
// ==========================================
//
// 用于自动记录代码块的执行时间

class ScopedTimer {
public:
    // 使用Histogram记录
    explicit ScopedTimer(Histogram& histogram)
        : histogram_(&histogram)
        , histogram_vec_(nullptr)
        , labels_()
        , start_(std::chrono::high_resolution_clock::now())
    {}

    // 使用HistogramVec记录（带标签）
    ScopedTimer(HistogramVec& histogram_vec, const Labels& labels)
        : histogram_(nullptr)
        , histogram_vec_(&histogram_vec)
        , labels_(labels)
        , start_(std::chrono::high_resolution_clock::now())
    {}

    ~ScopedTimer() {
        auto end = std::chrono::high_resolution_clock::now();
        double duration = std::chrono::duration<double>(end - start_).count();

        if (histogram_) {
            histogram_->observe(duration);
        } else if (histogram_vec_) {
            histogram_vec_->observe(labels_, duration);
        }
    }

    // 禁止拷贝
    ScopedTimer(const ScopedTimer&) = delete;
    ScopedTimer& operator=(const ScopedTimer&) = delete;

    // 手动结束计时（可选）
    void stop() {
        if (!stopped_) {
            auto end = std::chrono::high_resolution_clock::now();
            double duration = std::chrono::duration<double>(end - start_).count();

            if (histogram_) {
                histogram_->observe(duration);
            } else if (histogram_vec_) {
                histogram_vec_->observe(labels_, duration);
            }

            stopped_ = true;
        }
    }

private:
    Histogram* histogram_;
    HistogramVec* histogram_vec_;
    Labels labels_;
    std::chrono::high_resolution_clock::time_point start_;
    bool stopped_ = false;
};

// 便捷宏
#define SCOPED_TIMER(histogram) \
    metrics::ScopedTimer _timer_##__LINE__(histogram)

#define SCOPED_TIMER_WITH_LABELS(histogram_vec, labels) \
    metrics::ScopedTimer _timer_##__LINE__(histogram_vec, labels)

// ==========================================
// ScopedGauge：RAII资源计数
// ==========================================
//
// 用于跟踪活跃资源数量（如连接数、线程数）

class ScopedGauge {
public:
    explicit ScopedGauge(Gauge& gauge)
        : gauge_(&gauge)
        , gauge_vec_(nullptr)
    {
        gauge_->inc();
    }

    ScopedGauge(GaugeVec& gauge_vec, const Labels& labels)
        : gauge_(nullptr)
        , gauge_vec_(&gauge_vec)
        , labels_(labels)
    {
        gauge_vec_->labels(labels_).inc();
    }

    ~ScopedGauge() {
        if (gauge_) {
            gauge_->dec();
        } else if (gauge_vec_) {
            gauge_vec_->labels(labels_).dec();
        }
    }

    ScopedGauge(const ScopedGauge&) = delete;
    ScopedGauge& operator=(const ScopedGauge&) = delete;

private:
    Gauge* gauge_;
    GaugeVec* gauge_vec_;
    Labels labels_;
};

// 使用示例
/*
GaugeVec active_connections("active_connections",
                            "Number of active connections",
                            {"service"});

void handle_connection(const std::string& service) {
    ScopedGauge connection_tracker(active_connections, {{"service", service}});

    // 处理连接...
    // 函数返回时自动减少计数
}
*/
```

---

#### 2.8 HTTP暴露器

```cpp
// ==========================================
// HTTP Exposer：暴露/metrics端点
// ==========================================
//
// 简化实现，实际应使用cpp-httplib或类似库

#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <cstring>
#include <thread>
#include <atomic>

class HttpExposer {
public:
    HttpExposer(const std::string& bind_address, int port)
        : bind_address_(bind_address)
        , port_(port)
        , running_(false)
        , server_fd_(-1)
    {}

    ~HttpExposer() {
        stop();
    }

    // 启动HTTP服务器
    void start() {
        if (running_) return;

        // 创建socket
        server_fd_ = socket(AF_INET, SOCK_STREAM, 0);
        if (server_fd_ < 0) {
            throw std::runtime_error("无法创建socket");
        }

        // 设置socket选项
        int opt = 1;
        setsockopt(server_fd_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

        // 绑定地址
        struct sockaddr_in address;
        address.sin_family = AF_INET;
        address.sin_addr.s_addr = INADDR_ANY;
        address.sin_port = htons(port_);

        if (bind(server_fd_, (struct sockaddr*)&address, sizeof(address)) < 0) {
            close(server_fd_);
            throw std::runtime_error("无法绑定端口: " + std::to_string(port_));
        }

        // 开始监听
        if (listen(server_fd_, 10) < 0) {
            close(server_fd_);
            throw std::runtime_error("无法监听");
        }

        running_ = true;

        // 启动接受连接的线程
        accept_thread_ = std::thread([this]() {
            while (running_) {
                struct sockaddr_in client_addr;
                socklen_t client_len = sizeof(client_addr);

                int client_fd = accept(server_fd_, (struct sockaddr*)&client_addr, &client_len);
                if (client_fd < 0) {
                    if (running_) {
                        // 记录错误但继续
                        continue;
                    }
                    break;
                }

                // 处理请求
                handle_request(client_fd);
                close(client_fd);
            }
        });
    }

    // 停止服务器
    void stop() {
        if (!running_) return;

        running_ = false;

        if (server_fd_ >= 0) {
            close(server_fd_);
            server_fd_ = -1;
        }

        if (accept_thread_.joinable()) {
            accept_thread_.join();
        }
    }

    // 注册收集器
    void register_collectable(std::shared_ptr<Collectable> collectable) {
        std::lock_guard<std::mutex> lock(mutex_);
        collectables_.push_back(collectable);
    }

    // 直接注册Registry
    void register_registry(Registry* registry) {
        registry_ = registry;
    }

private:
    void handle_request(int client_fd) {
        // 读取请求（简化：只读取第一行）
        char buffer[4096];
        ssize_t bytes_read = read(client_fd, buffer, sizeof(buffer) - 1);
        if (bytes_read <= 0) return;
        buffer[bytes_read] = '\0';

        // 解析请求行
        std::string request(buffer);
        if (request.find("GET /metrics") != std::string::npos) {
            // 收集指标
            std::string metrics;
            if (registry_) {
                metrics = registry_->collect();
            } else {
                std::lock_guard<std::mutex> lock(mutex_);
                std::ostringstream oss;
                for (const auto& c : collectables_) {
                    oss << c->collect() << "\n";
                }
                metrics = oss.str();
            }

            // 发送响应
            std::ostringstream response;
            response << "HTTP/1.1 200 OK\r\n";
            response << "Content-Type: text/plain; version=0.0.4; charset=utf-8\r\n";
            response << "Content-Length: " << metrics.size() << "\r\n";
            response << "\r\n";
            response << metrics;

            std::string response_str = response.str();
            write(client_fd, response_str.c_str(), response_str.size());
        } else {
            // 404
            const char* not_found =
                "HTTP/1.1 404 Not Found\r\n"
                "Content-Length: 9\r\n"
                "\r\n"
                "Not Found";
            write(client_fd, not_found, strlen(not_found));
        }
    }

    std::string bind_address_;
    int port_;
    std::atomic<bool> running_;
    int server_fd_;
    std::thread accept_thread_;

    std::mutex mutex_;
    std::vector<std::shared_ptr<Collectable>> collectables_;
    Registry* registry_ = nullptr;
};

// ==========================================
// 使用示例
// ==========================================

/*
int main() {
    // 创建Registry
    auto& registry = metrics::Registry::default_registry();

    // 注册指标
    auto http_requests = registry.register_counter(
        "http_requests_total",
        "Total HTTP requests",
        {"method", "path", "status"}
    );

    auto http_duration = registry.register_histogram(
        "http_request_duration_seconds",
        "HTTP request duration in seconds",
        {"method", "path"},
        Histogram::defaultBuckets()
    );

    auto active_connections = registry.register_gauge(
        "active_connections",
        "Number of active connections",
        {}
    );

    // 启动HTTP暴露器
    HttpExposer exposer("0.0.0.0", 9090);
    exposer.register_registry(&registry);
    exposer.start();

    std::cout << "Metrics available at http://localhost:9090/metrics" << std::endl;

    // 模拟请求
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_real_distribution<> latency_dist(0.001, 0.5);
    std::uniform_int_distribution<> status_dist(0, 100);

    while (true) {
        // 模拟请求
        auto start = std::chrono::high_resolution_clock::now();

        // 处理...
        std::this_thread::sleep_for(std::chrono::milliseconds(
            static_cast<int>(latency_dist(gen) * 1000)));

        auto end = std::chrono::high_resolution_clock::now();
        double duration = std::chrono::duration<double>(end - start).count();

        // 决定状态码
        std::string status = (status_dist(gen) < 95) ? "200" : "500";

        // 记录指标
        http_requests->inc({{"method", "GET"}, {"path", "/api/users"}, {"status", status}});
        http_duration->observe({{"method", "GET"}, {"path", "/api/users"}}, duration);

        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }

    return 0;
}
*/

} // namespace metrics
```

---

#### 2.9 性能优化技巧

```cpp
// ==========================================
// 性能优化专题
// ==========================================

namespace metrics_optimization {

// ==========================================
// 1. 线程本地缓存
// ==========================================
//
// 问题：高频指标更新导致大量原子操作竞争
// 解决：使用线程本地缓存，定期刷新到全局

class ThreadLocalCounter {
public:
    ThreadLocalCounter() : global_value_(0) {}

    // 每个线程有自己的本地缓存
    void inc(double delta = 1.0) {
        auto& local = get_local();
        local.value += delta;
        local.count++;

        // 每1000次或超过阈值时刷新
        if (local.count >= 1000 || local.value >= 10000) {
            flush_local(local);
        }
    }

    double value() {
        // 刷新所有线程的本地缓存
        flush_all();
        return global_value_.load(std::memory_order_relaxed);
    }

private:
    struct LocalCache {
        double value = 0;
        uint64_t count = 0;
    };

    LocalCache& get_local() {
        thread_local LocalCache cache;
        return cache;
    }

    void flush_local(LocalCache& local) {
        if (local.value > 0) {
            double current = global_value_.load(std::memory_order_relaxed);
            while (!global_value_.compare_exchange_weak(
                current, current + local.value,
                std::memory_order_relaxed, std::memory_order_relaxed
            ));
            local.value = 0;
            local.count = 0;
        }
    }

    void flush_all() {
        // 这里简化了实现
        // 实际需要遍历所有线程的本地缓存
        flush_local(get_local());
    }

    std::atomic<double> global_value_;
};

// ==========================================
// 2. 标签缓存优化
// ==========================================
//
// 问题：每次使用标签都需要构建map和计算hash
// 解决：预计算标签ID

class LabelCache {
public:
    // 预注册标签组合，返回ID
    uint64_t register_labels(const Labels& labels) {
        std::lock_guard<std::mutex> lock(mutex_);

        // 检查是否已存在
        auto it = label_to_id_.find(labels);
        if (it != label_to_id_.end()) {
            return it->second;
        }

        // 分配新ID
        uint64_t id = next_id_++;
        label_to_id_[labels] = id;
        id_to_label_[id] = labels;
        return id;
    }

    // 使用ID查找标签
    const Labels& get_labels(uint64_t id) const {
        static Labels empty;
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = id_to_label_.find(id);
        return (it != id_to_label_.end()) ? it->second : empty;
    }

private:
    mutable std::mutex mutex_;
    std::map<Labels, uint64_t> label_to_id_;
    std::map<uint64_t, Labels> id_to_label_;
    uint64_t next_id_ = 0;
};

// 使用预注册标签的Counter
class FastCounterVec {
public:
    FastCounterVec(const std::string& name, const std::string& help)
        : name_(name), help_(help) {}

    // 预注册标签，获取ID
    uint64_t register_labels(const Labels& labels) {
        return label_cache_.register_labels(labels);
    }

    // 使用ID增加计数（无锁）
    void inc(uint64_t label_id, double delta = 1.0) {
        // 直接使用数组索引，避免map查找
        if (label_id >= counters_.size()) {
            std::lock_guard<std::mutex> lock(resize_mutex_);
            if (label_id >= counters_.size()) {
                counters_.resize(label_id + 1);
            }
        }
        counters_[label_id].inc(delta);
    }

    std::string collect() const {
        std::ostringstream oss;
        oss << "# HELP " << name_ << " " << help_ << "\n";
        oss << "# TYPE " << name_ << " counter\n";

        for (size_t i = 0; i < counters_.size(); ++i) {
            const Labels& labels = label_cache_.get_labels(i);
            double value = counters_[i].value();
            if (value > 0) {
                oss << name_ << formatLabels(labels) << " " << value << "\n";
            }
        }

        return oss.str();
    }

private:
    std::string name_;
    std::string help_;
    LabelCache label_cache_;
    std::vector<Counter> counters_;
    std::mutex resize_mutex_;
};

// 使用示例
/*
FastCounterVec requests("http_requests_total", "Total HTTP requests");

// 启动时预注册所有标签组合
uint64_t get_200 = requests.register_labels({{"method", "GET"}, {"status", "200"}});
uint64_t get_500 = requests.register_labels({{"method", "GET"}, {"status", "500"}});
uint64_t post_200 = requests.register_labels({{"method", "POST"}, {"status", "200"}});

// 热路径：直接使用ID
requests.inc(get_200);  // 极快，只是数组索引
*/

// ==========================================
// 3. 内存池优化
// ==========================================
//
// 问题：频繁创建/销毁标签字符串导致内存碎片
// 解决：使用字符串池

class StringPool {
public:
    // 获取或创建字符串的内部化版本
    const std::string& intern(const std::string& s) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto [it, inserted] = strings_.insert(s);
        return *it;
    }

    // 获取池中字符串数量
    size_t size() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return strings_.size();
    }

private:
    mutable std::mutex mutex_;
    std::set<std::string> strings_;
};

// 全局字符串池
inline StringPool& get_string_pool() {
    static StringPool pool;
    return pool;
}

// ==========================================
// 4. 采样优化
// ==========================================
//
// 问题：某些场景下不需要100%精确的指标
// 解决：随机采样减少开销

class SampledHistogram {
public:
    SampledHistogram(double sample_rate,
                     const std::vector<double>& buckets = Histogram::defaultBuckets())
        : sample_rate_(sample_rate)
        , histogram_(buckets)
        , rng_(std::random_device{}())
        , dist_(0.0, 1.0)
        , total_count_(0)
        , sampled_count_(0)
    {}

    void observe(double value) {
        total_count_.fetch_add(1, std::memory_order_relaxed);

        // 采样决策
        if (dist_(rng_) >= sample_rate_) {
            return;  // 不采样
        }

        sampled_count_.fetch_add(1, std::memory_order_relaxed);
        histogram_.observe(value);
    }

    // 导出时根据采样率调整
    Histogram::Data collect() const {
        auto data = histogram_.collect();

        // 根据采样率调整计数
        double adjustment = 1.0 / sample_rate_;
        for (auto& count : data.bucket_counts) {
            count = static_cast<uint64_t>(count * adjustment);
        }
        data.sum *= adjustment;
        data.count = total_count_.load(std::memory_order_relaxed);

        return data;
    }

private:
    double sample_rate_;
    Histogram histogram_;
    std::mt19937 rng_;
    std::uniform_real_distribution<double> dist_;
    std::atomic<uint64_t> total_count_;
    std::atomic<uint64_t> sampled_count_;
};

} // namespace metrics_optimization
```

---

#### 2.10 本周练习任务

```cpp
// ==========================================
// 第二周练习任务
// ==========================================

/*
练习1：实现完整的指标库
--------------------------------------
目标：从零实现一个可用的指标库

要求：
1. 实现Counter、CounterVec
2. 实现Gauge、GaugeVec
3. 实现Histogram、HistogramVec
4. 实现Summary（可选）
5. 实现Registry
6. 实现HTTP Exposer

验证：
- 编写单元测试验证正确性
- 使用Prometheus抓取验证格式兼容
- 使用wrk或ab进行压力测试
*/

/*
练习2：线程安全测试
--------------------------------------
目标：验证指标库的线程安全性

要求：
1. 启动100个线程同时更新同一个Counter
2. 验证最终值正确
3. 测量性能（ops/sec）
4. 对比不同实现方式的性能差异

代码模板：
*/

void thread_safety_test() {
    metrics::Counter counter;
    const int num_threads = 100;
    const int iterations = 100000;

    std::vector<std::thread> threads;
    threads.reserve(num_threads);

    auto start = std::chrono::high_resolution_clock::now();

    for (int i = 0; i < num_threads; ++i) {
        threads.emplace_back([&counter, iterations]() {
            for (int j = 0; j < iterations; ++j) {
                counter.inc();
            }
        });
    }

    for (auto& t : threads) {
        t.join();
    }

    auto end = std::chrono::high_resolution_clock::now();
    double duration = std::chrono::duration<double>(end - start).count();

    double expected = static_cast<double>(num_threads) * iterations;
    double actual = counter.value();

    std::cout << "期望值: " << expected << std::endl;
    std::cout << "实际值: " << actual << std::endl;
    std::cout << "是否正确: " << (expected == actual ? "是" : "否") << std::endl;
    std::cout << "耗时: " << duration << "秒" << std::endl;
    std::cout << "吞吐量: " << (expected / duration) << " ops/sec" << std::endl;
}

/*
练习3：Histogram分位数验证
--------------------------------------
目标：验证Histogram的分位数计算

要求：
1. 生成已知分布的数据（如正态分布）
2. 使用Histogram记录
3. 验证histogram_quantile()的结果
4. 分析桶边界选择对精度的影响
*/

/*
练习4：性能优化实践
--------------------------------------
目标：实现并对比不同优化策略

要求：
1. 实现ThreadLocalCounter
2. 实现FastCounterVec（预注册标签）
3. 实现SampledHistogram
4. 对比各实现的性能差异

基准测试场景：
- 单线程高频更新
- 多线程高频更新
- 大量标签组合
*/
```

---

#### 2.11 本周知识检验

```
思考题1：为什么Counter使用atomic<double>而不是mutex？
提示：考虑性能、正确性、以及什么场景下需要强同步。

思考题2：compare_exchange_weak和compare_exchange_strong的区别？
提示：考虑虚假失败、循环结构、性能。

思考题3：Histogram为什么存储非累积计数然后导出时计算累积？
提示：考虑并发更新、导出一致性。

思考题4：读写锁在什么场景下优于互斥锁？
提示：考虑读写比例、锁持有时间。

思考题5：为什么标签预注册可以显著提升性能？
提示：分析热路径上的操作。

实践题1：设计一个支持过期清理的CounterVec
要求：长时间未更新的标签组合自动删除

实践题2：实现一个无锁的Gauge
提示：使用fetch_add的特殊用法或原子操作序列
```

### 第三周：prometheus-cpp与OpenTelemetry实战

**学习目标**：
- 深入理解prometheus-cpp库的架构和使用方法
- 掌握OpenTelemetry C++ SDK的核心概念
- 学会构建自定义Exporter和Collector
- 理解分布式追踪与指标的关联

**阅读材料**：
- [ ] prometheus-cpp源码（GitHub: jupp0r/prometheus-cpp）
- [ ] OpenTelemetry C++ SDK文档
- [ ] OpenTelemetry规范（Metrics部分）
- [ ] OTLP协议规范

---

#### 3.1 prometheus-cpp架构深度解析

```cpp
// ==========================================
// prometheus-cpp 架构概览
// ==========================================
//
// ┌─────────────────────────────────────────────────────────────────────┐
// │                         prometheus-cpp                              │
// ├─────────────────────────────────────────────────────────────────────┤
// │                                                                     │
// │  ┌───────────────┐     ┌───────────────┐     ┌───────────────┐     │
// │  │    core       │     │    pull       │     │    push       │     │
// │  │               │     │               │     │               │     │
// │  │ - Registry    │     │ - Exposer     │     │ - Gateway     │     │
// │  │ - Family      │     │ - Handler     │     │ - Client      │     │
// │  │ - Counter     │     │ - HTTP Server │     │ - HTTP Client │     │
// │  │ - Gauge       │     │               │     │               │     │
// │  │ - Histogram   │     └───────────────┘     └───────────────┘     │
// │  │ - Summary     │                                                  │
// │  │ - Serializer  │                                                  │
// │  └───────────────┘                                                  │
// │                                                                     │
// └─────────────────────────────────────────────────────────────────────┘
//
// 核心设计模式：
// 1. Builder模式：构建指标和Family
// 2. 工厂模式：Family创建Child
// 3. 观察者模式：Collectable收集指标

#include <prometheus/counter.h>
#include <prometheus/gauge.h>
#include <prometheus/histogram.h>
#include <prometheus/summary.h>
#include <prometheus/exposer.h>
#include <prometheus/registry.h>
#include <prometheus/text_serializer.h>

#include <memory>
#include <string>
#include <map>
#include <thread>
#include <chrono>
#include <random>
#include <iostream>

// ==========================================
// 基础使用示例
// ==========================================

namespace prometheus_examples {

// 创建全局Registry
// Registry是线程安全的，通常整个应用只需要一个
std::shared_ptr<prometheus::Registry> create_registry() {
    return std::make_shared<prometheus::Registry>();
}

// ==========================================
// Counter使用详解
// ==========================================

void counter_examples(prometheus::Registry& registry) {
    // 方式1：使用Builder创建Counter Family
    // Family表示一组具有相同名称但不同标签的指标
    auto& request_counter = prometheus::BuildCounter()
        .Name("http_requests_total")           // 指标名称
        .Help("Total number of HTTP requests") // 帮助文本
        .Labels({{"service", "api"}})          // 基础标签（所有子指标都会有）
        .Register(registry);                   // 注册到Registry

    // 添加具体的标签组合
    // Add()返回一个Counter引用，可以重复使用
    auto& get_requests = request_counter.Add({
        {"method", "GET"},
        {"path", "/api/users"},
        {"status", "200"}
    });

    auto& post_requests = request_counter.Add({
        {"method", "POST"},
        {"path", "/api/users"},
        {"status", "201"}
    });

    // 使用Counter
    get_requests.Increment();        // 增加1
    get_requests.Increment(10);      // 增加10
    post_requests.Increment();

    // 注意：Counter只能增加，不能减少
    // get_requests.Decrement();  // 编译错误！Counter没有Decrement方法

    // 获取当前值
    double value = get_requests.Value();
    std::cout << "GET requests: " << value << std::endl;
}

// ==========================================
// Gauge使用详解
// ==========================================

void gauge_examples(prometheus::Registry& registry) {
    // 创建Gauge Family
    auto& temperature_gauge = prometheus::BuildGauge()
        .Name("room_temperature_celsius")
        .Help("Current room temperature in Celsius")
        .Register(registry);

    auto& memory_gauge = prometheus::BuildGauge()
        .Name("process_memory_bytes")
        .Help("Current memory usage in bytes")
        .Labels({{"type", "heap"}})
        .Register(registry);

    // 添加子指标
    auto& living_room = temperature_gauge.Add({{"room", "living_room"}});
    auto& bedroom = temperature_gauge.Add({{"room", "bedroom"}});
    auto& heap_used = memory_gauge.Add({});

    // Gauge可以设置、增加、减少
    living_room.Set(22.5);           // 直接设置值
    living_room.Increment();         // 增加1
    living_room.Increment(0.5);      // 增加0.5
    living_room.Decrement(0.3);      // 减少0.3

    bedroom.Set(20.0);

    // 设置为当前时间戳（常用于记录最后更新时间）
    auto& last_update = temperature_gauge.Add({{"room", "timestamp"}});
    last_update.SetToCurrentTime();

    // 模拟内存使用变化
    heap_used.Set(1024 * 1024 * 100);  // 100MB
}

// ==========================================
// Histogram使用详解
// ==========================================

void histogram_examples(prometheus::Registry& registry) {
    // Histogram用于记录值的分布
    // 需要预定义桶边界

    // 默认桶边界（适用于延迟，单位：秒）
    auto& latency_histogram = prometheus::BuildHistogram()
        .Name("http_request_duration_seconds")
        .Help("HTTP request latency in seconds")
        .Register(registry);

    // 自定义桶边界
    prometheus::Histogram::BucketBoundaries custom_buckets = {
        0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0
    };

    // 为不同端点创建Histogram
    auto& api_latency = latency_histogram.Add(
        {{"method", "GET"}, {"path", "/api/users"}},
        custom_buckets
    );

    auto& health_latency = latency_histogram.Add(
        {{"method", "GET"}, {"path", "/health"}},
        prometheus::Histogram::BucketBoundaries{0.001, 0.01, 0.1}  // 更细粒度
    );

    // 记录观测值
    api_latency.Observe(0.023);      // 23ms
    api_latency.Observe(0.156);      // 156ms
    api_latency.Observe(0.089);      // 89ms
    api_latency.Observe(1.234);      // 1.234s

    health_latency.Observe(0.002);   // 2ms

    // 生成桶边界的辅助函数
    // 线性桶：从start开始，每次增加width，共count个
    auto linear_buckets = prometheus::Histogram::BucketBoundaries{};
    for (int i = 0; i < 10; ++i) {
        linear_buckets.push_back(100 + i * 100);  // 100, 200, 300, ..., 1000
    }

    // 指数桶：从start开始，每次乘以factor
    auto exponential_buckets = prometheus::Histogram::BucketBoundaries{};
    double value = 1.0;
    for (int i = 0; i < 10; ++i) {
        exponential_buckets.push_back(value);
        value *= 2;  // 1, 2, 4, 8, 16, 32, 64, 128, 256, 512
    }
}

// ==========================================
// Summary使用详解
// ==========================================

void summary_examples(prometheus::Registry& registry) {
    // Summary在客户端计算分位数
    // 定义分位数和可接受的误差

    prometheus::Summary::Quantiles quantiles = {
        {0.5, 0.05},    // 中位数，误差5%
        {0.9, 0.01},    // P90，误差1%
        {0.95, 0.005},  // P95，误差0.5%
        {0.99, 0.001}   // P99，误差0.1%
    };

    auto& response_size = prometheus::BuildSummary()
        .Name("http_response_size_bytes")
        .Help("HTTP response size in bytes")
        .Register(registry);

    auto& api_response = response_size.Add(
        {{"path", "/api"}},
        quantiles,
        std::chrono::seconds{60},  // 滑动窗口大小
        5                          // 时间桶数量
    );

    // 记录观测值
    api_response.Observe(1024);
    api_response.Observe(2048);
    api_response.Observe(512);
    api_response.Observe(4096);
}

} // namespace prometheus_examples
```

---

#### 3.2 prometheus-cpp高级用法

```cpp
// ==========================================
// 高级用法：自定义Collectable
// ==========================================

#include <prometheus/collectable.h>
#include <prometheus/metric_family.h>

namespace prometheus_advanced {

// 自定义Collectable：动态收集指标
// 用于需要在采集时计算的指标
class ProcessMetricsCollector : public prometheus::Collectable {
public:
    // 实现Collect方法
    std::vector<prometheus::MetricFamily> Collect() const override {
        std::vector<prometheus::MetricFamily> families;

        // 收集CPU时间
        {
            prometheus::MetricFamily cpu_family;
            cpu_family.name = "process_cpu_seconds_total";
            cpu_family.help = "Total user and system CPU time spent in seconds";
            cpu_family.type = prometheus::MetricType::Counter;

            prometheus::ClientMetric user_cpu;
            user_cpu.counter.value = get_user_cpu_seconds();
            user_cpu.label.push_back({"mode", "user"});

            prometheus::ClientMetric system_cpu;
            system_cpu.counter.value = get_system_cpu_seconds();
            system_cpu.label.push_back({"mode", "system"});

            cpu_family.metric.push_back(user_cpu);
            cpu_family.metric.push_back(system_cpu);
            families.push_back(cpu_family);
        }

        // 收集内存使用
        {
            prometheus::MetricFamily memory_family;
            memory_family.name = "process_virtual_memory_bytes";
            memory_family.help = "Virtual memory size in bytes";
            memory_family.type = prometheus::MetricType::Gauge;

            prometheus::ClientMetric memory;
            memory.gauge.value = get_virtual_memory_bytes();

            memory_family.metric.push_back(memory);
            families.push_back(memory_family);
        }

        // 收集文件描述符
        {
            prometheus::MetricFamily fd_family;
            fd_family.name = "process_open_fds";
            fd_family.help = "Number of open file descriptors";
            fd_family.type = prometheus::MetricType::Gauge;

            prometheus::ClientMetric fd;
            fd.gauge.value = static_cast<double>(get_open_fds());

            fd_family.metric.push_back(fd);
            families.push_back(fd_family);
        }

        return families;
    }

private:
    // 获取用户态CPU时间（Linux实现）
    double get_user_cpu_seconds() const {
#ifdef __linux__
        std::ifstream stat("/proc/self/stat");
        if (!stat) return 0.0;

        std::string dummy;
        unsigned long utime;
        // 跳过前13个字段，第14个是utime
        for (int i = 0; i < 13; ++i) stat >> dummy;
        stat >> utime;

        // 转换为秒（假设HZ=100）
        return static_cast<double>(utime) / 100.0;
#else
        return 0.0;
#endif
    }

    // 获取内核态CPU时间
    double get_system_cpu_seconds() const {
#ifdef __linux__
        std::ifstream stat("/proc/self/stat");
        if (!stat) return 0.0;

        std::string dummy;
        unsigned long stime;
        for (int i = 0; i < 14; ++i) stat >> dummy;
        stat >> stime;

        return static_cast<double>(stime) / 100.0;
#else
        return 0.0;
#endif
    }

    // 获取虚拟内存大小
    double get_virtual_memory_bytes() const {
#ifdef __linux__
        std::ifstream status("/proc/self/status");
        if (!status) return 0.0;

        std::string line;
        while (std::getline(status, line)) {
            if (line.find("VmSize:") == 0) {
                size_t kb;
                sscanf(line.c_str(), "VmSize: %zu", &kb);
                return static_cast<double>(kb * 1024);
            }
        }
#endif
        return 0.0;
    }

    // 获取打开的文件描述符数
    int get_open_fds() const {
#ifdef __linux__
        int count = 0;
        DIR* dir = opendir("/proc/self/fd");
        if (dir) {
            while (readdir(dir)) count++;
            closedir(dir);
            return count - 2;  // 减去 . 和 ..
        }
#endif
        return 0;
    }
};

// ==========================================
// 使用Text Serializer直接序列化
// ==========================================

void serialization_example() {
    auto registry = std::make_shared<prometheus::Registry>();

    // 创建一些指标...
    auto& counter = prometheus::BuildCounter()
        .Name("example_counter")
        .Help("An example counter")
        .Register(*registry);

    counter.Add({{"label", "value"}}).Increment(42);

    // 使用TextSerializer序列化
    prometheus::TextSerializer serializer;
    std::string output = serializer.Serialize(registry->Collect());

    std::cout << "Serialized output:\n" << output << std::endl;
    // 输出:
    // # HELP example_counter An example counter
    // # TYPE example_counter counter
    // example_counter{label="value"} 42
}

// ==========================================
// HTTP Exposer配置
// ==========================================

void exposer_configuration() {
    // 基本配置
    prometheus::Exposer exposer{"0.0.0.0:9090"};

    // 可以指定更多选项
    // prometheus::Exposer exposer{"0.0.0.0:9090", "/metrics", 2};
    // 参数：绑定地址，URI路径，工作线程数

    auto registry = std::make_shared<prometheus::Registry>();

    // 注册Registry
    exposer.RegisterCollectable(registry);

    // 注册自定义Collectable
    auto process_collector = std::make_shared<ProcessMetricsCollector>();
    exposer.RegisterCollectable(process_collector);

    // Exposer会在后台线程运行HTTP服务器
    // 主线程可以继续其他工作
}

// ==========================================
// Push Gateway客户端
// ==========================================

#include <prometheus/gateway.h>

void push_gateway_example() {
    // 创建Registry和指标
    auto registry = std::make_shared<prometheus::Registry>();

    auto& batch_counter = prometheus::BuildCounter()
        .Name("batch_job_processed_total")
        .Help("Total items processed by batch job")
        .Register(*registry);

    auto& job_duration = prometheus::BuildGauge()
        .Name("batch_job_duration_seconds")
        .Help("Duration of batch job in seconds")
        .Register(*registry);

    // 创建Gateway客户端
    prometheus::Gateway gateway{
        "localhost",   // Push Gateway地址
        "9091",        // 端口
        "batch_job",   // Job名称
        {{"instance", "batch_001"}}  // 额外标签
    };

    // 注册Registry
    gateway.RegisterCollectable(registry);

    // 模拟批处理任务
    auto start = std::chrono::steady_clock::now();

    auto& items = batch_counter.Add({});
    for (int i = 0; i < 1000; ++i) {
        // 处理项目...
        items.Increment();
    }

    auto end = std::chrono::steady_clock::now();
    double duration = std::chrono::duration<double>(end - start).count();
    job_duration.Add({}).Set(duration);

    // 推送指标到Push Gateway
    // Push(): 替换该job的所有指标
    // Add(): 仅更新发送的指标
    // Delete(): 删除该job的所有指标

    int status = gateway.Push();
    if (status != 200) {
        std::cerr << "Push failed with status: " << status << std::endl;
    }

    // 任务完成后可以选择删除指标
    // gateway.Delete();
}

} // namespace prometheus_advanced
```

---

#### 3.3 OpenTelemetry C++ SDK入门

```cpp
// ==========================================
// OpenTelemetry概述
// ==========================================
//
// OpenTelemetry是CNCF的可观测性标准，统一了：
// - 追踪（Traces）
// - 指标（Metrics）
// - 日志（Logs）
//
// 核心组件：
// ┌─────────────────────────────────────────────────────────────────────┐
// │                      OpenTelemetry架构                              │
// ├─────────────────────────────────────────────────────────────────────┤
// │                                                                     │
// │  ┌───────────┐   ┌───────────┐   ┌───────────┐                     │
// │  │  Tracer   │   │   Meter   │   │  Logger   │   ← API层           │
// │  └─────┬─────┘   └─────┬─────┘   └─────┬─────┘                     │
// │        │               │               │                            │
// │  ┌─────┴─────┐   ┌─────┴─────┐   ┌─────┴─────┐                     │
// │  │  Tracer   │   │   Meter   │   │  Logger   │   ← SDK实现层       │
// │  │  Provider │   │  Provider │   │  Provider │                     │
// │  └─────┬─────┘   └─────┬─────┘   └─────┴─────┘                     │
// │        │               │                                            │
// │  ┌─────┴─────┐   ┌─────┴─────┐                                     │
// │  │  Span     │   │   Metric  │                                     │
// │  │ Processor │   │  Reader   │   ← 处理层                          │
// │  └─────┬─────┘   └─────┴─────┘                                     │
// │        │               │                                            │
// │  ┌─────┴───────────────┴─────┐                                     │
// │  │         Exporter          │   ← 导出层                          │
// │  │  (OTLP, Prometheus, etc.) │                                     │
// │  └───────────────────────────┘                                     │
// │                                                                     │
// └─────────────────────────────────────────────────────────────────────┘

// 注意：以下代码展示OpenTelemetry C++ SDK的概念性用法
// 实际使用需要正确安装和配置SDK

#include <memory>
#include <string>
#include <chrono>

// 模拟OpenTelemetry SDK的核心接口
namespace opentelemetry {
namespace metrics {

// ==========================================
// Meter：指标创建工厂
// ==========================================

class Meter {
public:
    virtual ~Meter() = default;

    // 创建Counter
    virtual std::unique_ptr<class Counter> CreateCounter(
        const std::string& name,
        const std::string& description = "",
        const std::string& unit = "") = 0;

    // 创建UpDownCounter（可增可减的计数器）
    virtual std::unique_ptr<class UpDownCounter> CreateUpDownCounter(
        const std::string& name,
        const std::string& description = "",
        const std::string& unit = "") = 0;

    // 创建Histogram
    virtual std::unique_ptr<class Histogram> CreateHistogram(
        const std::string& name,
        const std::string& description = "",
        const std::string& unit = "") = 0;

    // 创建Observable Gauge（回调式Gauge）
    virtual void CreateObservableGauge(
        const std::string& name,
        std::function<void(class ObservableResult&)> callback,
        const std::string& description = "",
        const std::string& unit = "") = 0;
};

// ==========================================
// 同步指标类型
// ==========================================

// Attributes：OpenTelemetry中的标签
using Attributes = std::map<std::string, std::string>;

class Counter {
public:
    virtual ~Counter() = default;

    // 增加计数
    virtual void Add(double value, const Attributes& attributes = {}) = 0;
};

class UpDownCounter {
public:
    virtual ~UpDownCounter() = default;

    // 增加或减少（可以传负数）
    virtual void Add(double value, const Attributes& attributes = {}) = 0;
};

class Histogram {
public:
    virtual ~Histogram() = default;

    // 记录观测值
    virtual void Record(double value, const Attributes& attributes = {}) = 0;
};

// ==========================================
// 异步指标类型
// ==========================================

class ObservableResult {
public:
    virtual ~ObservableResult() = default;

    // 在回调中报告观测值
    virtual void Observe(double value, const Attributes& attributes = {}) = 0;
};

// ==========================================
// MeterProvider：管理Meter的生命周期
// ==========================================

class MeterProvider {
public:
    virtual ~MeterProvider() = default;

    // 获取Meter
    virtual std::shared_ptr<Meter> GetMeter(
        const std::string& name,
        const std::string& version = "") = 0;
};

} // namespace metrics

namespace trace {

// ==========================================
// Span：追踪的基本单元
// ==========================================

class Span {
public:
    virtual ~Span() = default;

    // 设置属性
    virtual void SetAttribute(const std::string& key, const std::string& value) = 0;
    virtual void SetAttribute(const std::string& key, int64_t value) = 0;
    virtual void SetAttribute(const std::string& key, double value) = 0;

    // 添加事件
    virtual void AddEvent(const std::string& name,
                          const std::map<std::string, std::string>& attributes = {}) = 0;

    // 设置状态
    enum class StatusCode { Unset, Ok, Error };
    virtual void SetStatus(StatusCode code, const std::string& description = "") = 0;

    // 结束Span
    virtual void End() = 0;

    // 获取上下文
    virtual class SpanContext GetContext() const = 0;
};

class SpanContext {
public:
    std::string trace_id;
    std::string span_id;
    bool is_valid = false;
};

// ==========================================
// Tracer：创建Span
// ==========================================

class Tracer {
public:
    virtual ~Tracer() = default;

    // 创建新Span
    virtual std::unique_ptr<Span> StartSpan(const std::string& name) = 0;
};

class TracerProvider {
public:
    virtual ~TracerProvider() = default;

    virtual std::shared_ptr<Tracer> GetTracer(
        const std::string& name,
        const std::string& version = "") = 0;
};

} // namespace trace
} // namespace opentelemetry
```

---

#### 3.4 OpenTelemetry实际使用示例

```cpp
// ==========================================
// OpenTelemetry完整使用示例
// ==========================================

namespace otel_examples {

// 模拟一个简单的OpenTelemetry实现
// 实际使用时应该使用官方SDK

class SimpleMeter : public opentelemetry::metrics::Meter {
public:
    explicit SimpleMeter(const std::string& name) : name_(name) {}

    std::unique_ptr<opentelemetry::metrics::Counter> CreateCounter(
            const std::string& name,
            const std::string& description,
            const std::string& unit) override {
        // 返回Counter实现
        return std::make_unique<SimpleCounter>(name, description, unit);
    }

    // 其他方法...

private:
    std::string name_;

    class SimpleCounter : public opentelemetry::metrics::Counter {
    public:
        SimpleCounter(const std::string& name,
                     const std::string& description,
                     const std::string& unit)
            : name_(name), description_(description), unit_(unit) {}

        void Add(double value,
                const opentelemetry::metrics::Attributes& attributes) override {
            std::lock_guard<std::mutex> lock(mutex_);
            std::string key = format_attributes(attributes);
            values_[key] += value;
        }

    private:
        std::string format_attributes(
                const opentelemetry::metrics::Attributes& attrs) const {
            std::ostringstream oss;
            for (const auto& [k, v] : attrs) {
                oss << k << "=" << v << ";";
            }
            return oss.str();
        }

        std::string name_;
        std::string description_;
        std::string unit_;
        std::mutex mutex_;
        std::map<std::string, double> values_;
    };
};

// ==========================================
// 应用层使用示例
// ==========================================

class HttpHandler {
public:
    HttpHandler(std::shared_ptr<opentelemetry::metrics::Meter> meter,
                std::shared_ptr<opentelemetry::trace::Tracer> tracer)
        : tracer_(tracer)
    {
        // 创建指标
        request_counter_ = meter->CreateCounter(
            "http.server.request.count",
            "Total number of HTTP requests",
            "{request}"
        );

        request_duration_ = meter->CreateHistogram(
            "http.server.request.duration",
            "HTTP request duration",
            "s"
        );

        active_requests_ = meter->CreateUpDownCounter(
            "http.server.active_requests",
            "Number of active requests",
            "{request}"
        );
    }

    void HandleRequest(const std::string& method,
                       const std::string& path,
                       const std::string& status) {
        // 创建Span
        auto span = tracer_->StartSpan("HTTP " + method + " " + path);

        // 增加活跃请求计数
        active_requests_->Add(1, {{"method", method}});

        auto start = std::chrono::high_resolution_clock::now();

        try {
            // 处理请求...
            span->SetAttribute("http.method", method);
            span->SetAttribute("http.target", path);
            span->AddEvent("Processing started");

            // 模拟处理
            std::this_thread::sleep_for(std::chrono::milliseconds(
                std::rand() % 100));

            span->SetAttribute("http.status_code", static_cast<int64_t>(200));
            span->SetStatus(opentelemetry::trace::Span::StatusCode::Ok);

        } catch (const std::exception& e) {
            span->SetStatus(opentelemetry::trace::Span::StatusCode::Error, e.what());
            throw;
        }

        auto end = std::chrono::high_resolution_clock::now();
        double duration = std::chrono::duration<double>(end - start).count();

        // 记录指标
        opentelemetry::metrics::Attributes attrs = {
            {"http.method", method},
            {"http.route", path},
            {"http.status_code", status}
        };

        request_counter_->Add(1, attrs);
        request_duration_->Record(duration, attrs);

        // 减少活跃请求计数
        active_requests_->Add(-1, {{"method", method}});

        // 结束Span
        span->End();
    }

private:
    std::shared_ptr<opentelemetry::trace::Tracer> tracer_;
    std::unique_ptr<opentelemetry::metrics::Counter> request_counter_;
    std::unique_ptr<opentelemetry::metrics::Histogram> request_duration_;
    std::unique_ptr<opentelemetry::metrics::UpDownCounter> active_requests_;
};

} // namespace otel_examples
```

---

#### 3.5 OTLP协议与Exporter

```cpp
// ==========================================
// OTLP (OpenTelemetry Protocol) 概述
// ==========================================
//
// OTLP是OpenTelemetry的原生数据传输协议
// 支持gRPC和HTTP两种传输方式
//
// 数据格式（简化）：
//
// ResourceMetrics {
//   Resource {
//     attributes: [
//       { key: "service.name", value: "my-service" },
//       { key: "service.version", value: "1.0.0" }
//     ]
//   }
//   ScopeMetrics {
//     Scope {
//       name: "my-meter"
//       version: "1.0.0"
//     }
//     Metrics [
//       {
//         name: "http_requests_total"
//         description: "Total HTTP requests"
//         unit: "1"
//         sum {
//           data_points: [
//             {
//               attributes: [{ key: "method", value: "GET" }]
//               start_time_unix_nano: 1234567890000000000
//               time_unix_nano: 1234567900000000000
//               value: 100
//             }
//           ]
//           aggregation_temporality: CUMULATIVE
//           is_monotonic: true
//         }
//       }
//     ]
//   }
// }

namespace otlp {

// ==========================================
// 资源定义
// ==========================================

struct Resource {
    std::map<std::string, std::string> attributes;

    // 常见的资源属性
    static Resource create(const std::string& service_name,
                           const std::string& service_version = "",
                           const std::string& environment = "") {
        Resource resource;
        resource.attributes["service.name"] = service_name;
        if (!service_version.empty()) {
            resource.attributes["service.version"] = service_version;
        }
        if (!environment.empty()) {
            resource.attributes["deployment.environment"] = environment;
        }
        // 自动添加SDK信息
        resource.attributes["telemetry.sdk.name"] = "opentelemetry";
        resource.attributes["telemetry.sdk.language"] = "cpp";
        return resource;
    }
};

// ==========================================
// 指标数据点
// ==========================================

struct NumberDataPoint {
    std::map<std::string, std::string> attributes;
    uint64_t start_time_unix_nano;
    uint64_t time_unix_nano;
    double value;
};

struct HistogramDataPoint {
    std::map<std::string, std::string> attributes;
    uint64_t start_time_unix_nano;
    uint64_t time_unix_nano;
    uint64_t count;
    double sum;
    std::vector<double> bucket_bounds;
    std::vector<uint64_t> bucket_counts;
};

// ==========================================
// 聚合时间性
// ==========================================

enum class AggregationTemporality {
    UNSPECIFIED = 0,
    DELTA = 1,       // 增量：每次报告之间的差值
    CUMULATIVE = 2   // 累积：从开始到现在的总和
};

// ==========================================
// 指标数据
// ==========================================

struct Metric {
    std::string name;
    std::string description;
    std::string unit;

    // 不同类型的指标数据
    struct Sum {
        std::vector<NumberDataPoint> data_points;
        AggregationTemporality aggregation_temporality;
        bool is_monotonic;  // true for Counter, false for UpDownCounter
    };

    struct Gauge {
        std::vector<NumberDataPoint> data_points;
    };

    struct Histogram {
        std::vector<HistogramDataPoint> data_points;
        AggregationTemporality aggregation_temporality;
    };

    std::variant<Sum, Gauge, Histogram> data;
};

// ==========================================
// Exporter接口
// ==========================================

class Exporter {
public:
    virtual ~Exporter() = default;

    // 导出指标数据
    virtual bool Export(const Resource& resource,
                        const std::vector<Metric>& metrics) = 0;

    // 强制刷新
    virtual bool ForceFlush() = 0;

    // 关闭Exporter
    virtual bool Shutdown() = 0;
};

// ==========================================
// Prometheus Exporter实现
// ==========================================

class PrometheusExporter : public Exporter {
public:
    PrometheusExporter(const std::string& endpoint = "0.0.0.0:9090")
        : endpoint_(endpoint)
    {}

    bool Export(const Resource& resource,
                const std::vector<Metric>& metrics) override {
        std::lock_guard<std::mutex> lock(mutex_);

        // 更新内部状态
        resource_ = resource;
        metrics_ = metrics;

        return true;
    }

    bool ForceFlush() override {
        return true;
    }

    bool Shutdown() override {
        return true;
    }

    // 生成Prometheus格式输出
    std::string Scrape() const {
        std::lock_guard<std::mutex> lock(mutex_);
        std::ostringstream oss;

        for (const auto& metric : metrics_) {
            oss << "# HELP " << metric.name << " " << metric.description << "\n";

            std::visit([&oss, &metric](auto&& data) {
                using T = std::decay_t<decltype(data)>;

                if constexpr (std::is_same_v<T, Metric::Sum>) {
                    oss << "# TYPE " << metric.name
                        << (data.is_monotonic ? " counter" : " gauge") << "\n";

                    for (const auto& point : data.data_points) {
                        oss << metric.name << format_labels(point.attributes)
                            << " " << point.value << "\n";
                    }
                } else if constexpr (std::is_same_v<T, Metric::Gauge>) {
                    oss << "# TYPE " << metric.name << " gauge\n";

                    for (const auto& point : data.data_points) {
                        oss << metric.name << format_labels(point.attributes)
                            << " " << point.value << "\n";
                    }
                } else if constexpr (std::is_same_v<T, Metric::Histogram>) {
                    oss << "# TYPE " << metric.name << " histogram\n";

                    for (const auto& point : data.data_points) {
                        uint64_t cumulative = 0;
                        for (size_t i = 0; i < point.bucket_bounds.size(); ++i) {
                            cumulative += point.bucket_counts[i];
                            auto labels = point.attributes;
                            labels["le"] = std::to_string(point.bucket_bounds[i]);
                            oss << metric.name << "_bucket"
                                << format_labels(labels)
                                << " " << cumulative << "\n";
                        }
                        // +Inf bucket
                        auto labels = point.attributes;
                        labels["le"] = "+Inf";
                        oss << metric.name << "_bucket"
                            << format_labels(labels)
                            << " " << point.count << "\n";

                        oss << metric.name << "_sum"
                            << format_labels(point.attributes)
                            << " " << point.sum << "\n";
                        oss << metric.name << "_count"
                            << format_labels(point.attributes)
                            << " " << point.count << "\n";
                    }
                }
            }, metric.data);
        }

        return oss.str();
    }

private:
    static std::string format_labels(
            const std::map<std::string, std::string>& labels) {
        if (labels.empty()) return "";
        std::ostringstream oss;
        oss << "{";
        bool first = true;
        for (const auto& [k, v] : labels) {
            if (!first) oss << ",";
            oss << k << "=\"" << v << "\"";
            first = false;
        }
        oss << "}";
        return oss.str();
    }

    std::string endpoint_;
    mutable std::mutex mutex_;
    Resource resource_;
    std::vector<Metric> metrics_;
};

// ==========================================
// OTLP/gRPC Exporter（概念示例）
// ==========================================

class OtlpGrpcExporter : public Exporter {
public:
    OtlpGrpcExporter(const std::string& endpoint = "localhost:4317",
                     bool use_ssl = false)
        : endpoint_(endpoint)
        , use_ssl_(use_ssl)
    {
        // 实际实现需要使用gRPC库
    }

    bool Export(const Resource& resource,
                const std::vector<Metric>& metrics) override {
        // 将数据序列化为protobuf格式
        // 通过gRPC发送到collector

        // 伪代码：
        // opentelemetry::proto::collector::metrics::v1::ExportMetricsServiceRequest request;
        // auto* rm = request.add_resource_metrics();
        // *rm->mutable_resource() = convert_resource(resource);
        // for (const auto& metric : metrics) {
        //     *rm->add_scope_metrics()->add_metrics() = convert_metric(metric);
        // }
        // stub_->Export(&context, request, &response);

        return true;
    }

    bool ForceFlush() override {
        return true;
    }

    bool Shutdown() override {
        return true;
    }

private:
    std::string endpoint_;
    bool use_ssl_;
};

} // namespace otlp
```

---

#### 3.6 指标与追踪的关联（Exemplars）

```cpp
// ==========================================
// Exemplars：指标与追踪的桥梁
// ==========================================
//
// Exemplar是从聚合指标到具体追踪的链接
// 允许从高层指标drill-down到具体请求
//
// 使用场景：
// 1. 发现P99延迟异常高
// 2. 通过Exemplar找到具体的慢请求Trace ID
// 3. 查看追踪详情定位问题

namespace exemplars {

struct Exemplar {
    // 关联的追踪信息
    std::string trace_id;
    std::string span_id;

    // 采样的值
    double value;

    // 采样时间
    uint64_t timestamp_ms;

    // 额外属性
    std::map<std::string, std::string> filtered_attributes;
};

// 支持Exemplar的Histogram
class HistogramWithExemplars {
public:
    HistogramWithExemplars(const std::vector<double>& bucket_bounds,
                           size_t max_exemplars_per_bucket = 1)
        : bucket_bounds_(bucket_bounds)
        , max_exemplars_per_bucket_(max_exemplars_per_bucket)
    {
        bucket_counts_.resize(bucket_bounds.size() + 1, 0);
        bucket_exemplars_.resize(bucket_bounds.size() + 1);
    }

    // 记录观测值（可选关联追踪）
    void Observe(double value,
                 const std::string& trace_id = "",
                 const std::string& span_id = "") {
        std::lock_guard<std::mutex> lock(mutex_);

        sum_ += value;
        count_++;

        // 找到对应的桶
        size_t bucket_index = find_bucket(value);
        bucket_counts_[bucket_index]++;

        // 如果有追踪上下文，记录Exemplar
        if (!trace_id.empty()) {
            // 采样策略：保留每个桶的最后N个Exemplar
            auto& exemplars = bucket_exemplars_[bucket_index];
            if (exemplars.size() >= max_exemplars_per_bucket_) {
                exemplars.erase(exemplars.begin());
            }
            exemplars.push_back({
                trace_id,
                span_id,
                value,
                current_timestamp_ms(),
                {}
            });
        }
    }

    // 格式化为OpenMetrics格式（支持Exemplar）
    std::string Format(const std::string& name,
                       const std::map<std::string, std::string>& labels = {}) const {
        std::lock_guard<std::mutex> lock(mutex_);
        std::ostringstream oss;

        auto format_labels_str = [&labels](const std::string& extra = "") {
            std::ostringstream label_oss;
            if (labels.empty() && extra.empty()) return std::string();
            label_oss << "{";
            bool first = true;
            for (const auto& [k, v] : labels) {
                if (!first) label_oss << ",";
                label_oss << k << "=\"" << v << "\"";
                first = false;
            }
            if (!extra.empty()) {
                if (!first) label_oss << ",";
                label_oss << extra;
            }
            label_oss << "}";
            return label_oss.str();
        };

        uint64_t cumulative = 0;
        for (size_t i = 0; i < bucket_bounds_.size(); ++i) {
            cumulative += bucket_counts_[i];

            oss << name << "_bucket"
                << format_labels_str("le=\"" + std::to_string(bucket_bounds_[i]) + "\"")
                << " " << cumulative;

            // 添加Exemplar（OpenMetrics格式）
            if (!bucket_exemplars_[i].empty()) {
                const auto& ex = bucket_exemplars_[i].back();
                oss << " # {trace_id=\"" << ex.trace_id << "\"} "
                    << ex.value << " " << (ex.timestamp_ms / 1000.0);
            }
            oss << "\n";
        }

        // +Inf bucket
        oss << name << "_bucket"
            << format_labels_str("le=\"+Inf\"")
            << " " << count_ << "\n";

        oss << name << "_sum" << format_labels_str() << " " << sum_ << "\n";
        oss << name << "_count" << format_labels_str() << " " << count_ << "\n";

        return oss.str();
    }

private:
    size_t find_bucket(double value) const {
        auto it = std::upper_bound(bucket_bounds_.begin(), bucket_bounds_.end(), value);
        return std::distance(bucket_bounds_.begin(), it);
    }

    uint64_t current_timestamp_ms() const {
        return std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::system_clock::now().time_since_epoch()
        ).count();
    }

    std::vector<double> bucket_bounds_;
    size_t max_exemplars_per_bucket_;
    mutable std::mutex mutex_;
    std::vector<uint64_t> bucket_counts_;
    std::vector<std::vector<Exemplar>> bucket_exemplars_;
    double sum_ = 0;
    uint64_t count_ = 0;
};

// ==========================================
// 使用示例：关联追踪和指标
// ==========================================

void instrumented_handler() {
    // 假设有追踪系统
    std::string trace_id = "abc123def456";
    std::string span_id = "span789";

    // Histogram记录延迟，同时关联追踪
    static HistogramWithExemplars latency({0.01, 0.05, 0.1, 0.5, 1.0, 5.0});

    auto start = std::chrono::high_resolution_clock::now();

    // 处理请求...

    auto end = std::chrono::high_resolution_clock::now();
    double duration = std::chrono::duration<double>(end - start).count();

    // 记录延迟，关联追踪
    latency.Observe(duration, trace_id, span_id);

    // 导出时，Prometheus会看到类似：
    // http_request_duration_seconds_bucket{le="0.5"} 100 # {trace_id="abc123def456"} 0.234 1234567890.123
}

} // namespace exemplars
```

---

#### 3.7 自定义Exporter开发

```cpp
// ==========================================
// 自定义Exporter示例：发送到自定义后端
// ==========================================

namespace custom_exporter {

// JSON Exporter：将指标导出为JSON格式
class JsonExporter {
public:
    JsonExporter(const std::string& endpoint)
        : endpoint_(endpoint)
    {}

    bool Export(const std::vector<metrics::Collectable*>& collectables) {
        std::ostringstream json;
        json << "{\n";
        json << "  \"timestamp\": " << current_timestamp_ms() << ",\n";
        json << "  \"metrics\": [\n";

        bool first = true;
        for (const auto* collectable : collectables) {
            // 这里需要实际获取指标数据
            // 简化示例
            if (!first) json << ",\n";
            first = false;
            json << "    {\"name\": \"example\", \"value\": 42}";
        }

        json << "\n  ]\n";
        json << "}\n";

        // 发送到端点
        return send_http_post(endpoint_, json.str());
    }

private:
    uint64_t current_timestamp_ms() const {
        return std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::system_clock::now().time_since_epoch()
        ).count();
    }

    bool send_http_post(const std::string& url, const std::string& body) {
        // 实际HTTP发送实现
        std::cout << "Sending to " << url << ":\n" << body << std::endl;
        return true;
    }

    std::string endpoint_;
};

// ==========================================
// 批量Exporter：缓冲指标批量发送
// ==========================================

class BatchingExporter {
public:
    BatchingExporter(std::unique_ptr<JsonExporter> inner,
                     size_t batch_size = 1000,
                     std::chrono::seconds flush_interval = std::chrono::seconds{5})
        : inner_(std::move(inner))
        , batch_size_(batch_size)
        , flush_interval_(flush_interval)
        , running_(true)
    {
        // 启动后台刷新线程
        flush_thread_ = std::thread([this]() {
            while (running_) {
                std::this_thread::sleep_for(flush_interval_);
                Flush();
            }
        });
    }

    ~BatchingExporter() {
        running_ = false;
        if (flush_thread_.joinable()) {
            flush_thread_.join();
        }
        Flush();  // 最后一次刷新
    }

    void Add(const std::string& metric_data) {
        std::lock_guard<std::mutex> lock(mutex_);
        buffer_.push_back(metric_data);

        if (buffer_.size() >= batch_size_) {
            flush_locked();
        }
    }

    void Flush() {
        std::lock_guard<std::mutex> lock(mutex_);
        flush_locked();
    }

private:
    void flush_locked() {
        if (buffer_.empty()) return;

        // 发送缓冲区数据
        // inner_->Export(buffer_);

        buffer_.clear();
    }

    std::unique_ptr<JsonExporter> inner_;
    size_t batch_size_;
    std::chrono::seconds flush_interval_;

    std::mutex mutex_;
    std::vector<std::string> buffer_;

    std::atomic<bool> running_;
    std::thread flush_thread_;
};

// ==========================================
// 重试Exporter：失败时自动重试
// ==========================================

class RetryingExporter {
public:
    RetryingExporter(std::unique_ptr<JsonExporter> inner,
                     int max_retries = 3,
                     std::chrono::milliseconds initial_backoff = std::chrono::milliseconds{100})
        : inner_(std::move(inner))
        , max_retries_(max_retries)
        , initial_backoff_(initial_backoff)
    {}

    bool Export(const std::string& data) {
        std::chrono::milliseconds backoff = initial_backoff_;

        for (int attempt = 0; attempt <= max_retries_; ++attempt) {
            if (attempt > 0) {
                // 指数退避
                std::this_thread::sleep_for(backoff);
                backoff *= 2;
            }

            // 尝试导出
            // if (inner_->Export(data)) {
            //     return true;
            // }
        }

        return false;
    }

private:
    std::unique_ptr<JsonExporter> inner_;
    int max_retries_;
    std::chrono::milliseconds initial_backoff_;
};

} // namespace custom_exporter
```

---

#### 3.8 本周练习任务

```cpp
// ==========================================
// 第三周练习任务
// ==========================================

/*
练习1：使用prometheus-cpp构建完整应用
--------------------------------------
目标：使用官方库实现一个HTTP服务监控

要求：
1. 使用prometheus-cpp创建以下指标：
   - http_requests_total (Counter)
   - http_request_duration_seconds (Histogram)
   - http_active_connections (Gauge)
2. 实现HTTP Exposer
3. 模拟请求并验证指标正确性
4. 使用Prometheus抓取验证
*/

/*
练习2：实现自定义Collectable
--------------------------------------
目标：动态收集系统指标

要求：
1. 实现ProcessMetricsCollector
2. 收集CPU使用、内存使用、文件描述符数
3. 注册到Exposer
4. 验证采集结果
*/

/*
练习3：实现OpenTelemetry指标适配器
--------------------------------------
目标：理解OTel和Prometheus的差异

要求：
1. 实现OTel风格的Meter接口
2. 底层使用prometheus-cpp存储
3. 支持Counter、Histogram、Gauge
4. 对比两种API风格
*/

/*
练习4：Exemplar实现
--------------------------------------
目标：关联指标和追踪

要求：
1. 实现HistogramWithExemplars
2. 生成OpenMetrics格式输出
3. 验证Grafana能正确显示Exemplar链接
4. 编写测试用例
*/

/*
练习5：自定义Exporter
--------------------------------------
目标：将指标发送到自定义后端

要求：
1. 实现JSON格式Exporter
2. 支持HTTP POST发送
3. 实现批量发送优化
4. 添加重试逻辑
*/
```

---

#### 3.9 本周知识检验

```
思考题1：prometheus-cpp中Family和Child的关系是什么？
提示：考虑标签维度和实际数据存储。

思考题2：OpenTelemetry的Delta和Cumulative聚合有什么区别？
提示：考虑数据报告方式和后端处理。

思考题3：为什么Exemplar只采样部分数据？
提示：考虑存储成本和追踪系统负载。

思考题4：Push Gateway适用于什么场景？有什么局限？
提示：考虑短生命周期任务和删除机制。

思考题5：OTel和Prometheus的指标模型有什么本质区别？
提示：考虑资源、范围、命名规范。

实践题1：设计一个支持多后端的Exporter框架
要求：支持同时发送到Prometheus和自定义后端

实践题2：实现一个指标聚合器
要求：将多个来源的相同指标聚合成一个
```

### 第四周：完整监控栈与生产实践

**学习目标**：
- 掌握Prometheus高级配置和扩展方案
- 学会设计有效的Grafana仪表板
- 理解告警系统的最佳实践
- 掌握SLO/SLI/Error Budget概念
- 能够进行容量规划和性能调优

**阅读材料**：
- [ ] Prometheus配置文档（详细版）
- [ ] Grafana最佳实践指南
- [ ] 《SRE Workbook》- Alerting on SLOs
- [ ] Thanos/Cortex架构文档
- [ ] PromQL高级查询技巧

---

#### 4.1 Prometheus高级配置详解

```yaml
# ==========================================
# prometheus.yml - 生产级Prometheus配置
# ==========================================

# 全局配置
global:
  # 抓取间隔：平衡数据精度和资源消耗
  # 建议：15s-60s，根据指标重要性调整
  scrape_interval: 15s

  # 规则评估间隔：触发告警的评估频率
  scrape_timeout: 10s

  # 外部标签：用于联邦和远程写入时标识来源
  external_labels:
    cluster: 'production-us-east-1'
    env: 'production'
    region: 'us-east-1'

# 规则文件
rule_files:
  - '/etc/prometheus/rules/*.yml'
  - '/etc/prometheus/alerts/*.yml'

# 告警管理器配置
alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - 'alertmanager-0:9093'
          - 'alertmanager-1:9093'
          - 'alertmanager-2:9093'

      # 告警推送配置
      timeout: 10s
      api_version: v2

# ==========================================
# 抓取配置
# ==========================================
scrape_configs:
  # ----------------------------------------
  # Prometheus自监控
  # ----------------------------------------
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
    # 重标签：添加额外信息
    relabel_configs:
      - target_label: 'component'
        replacement: 'prometheus'

  # ----------------------------------------
  # 静态目标配置
  # ----------------------------------------
  - job_name: 'api-servers'
    static_configs:
      - targets:
          - 'api-1.example.com:9090'
          - 'api-2.example.com:9090'
          - 'api-3.example.com:9090'
        labels:
          group: 'api'
          tier: 'backend'

    # 指标路径（默认/metrics）
    metrics_path: '/metrics'

    # 抓取超时
    scrape_timeout: 10s

    # 认证配置
    basic_auth:
      username: 'prometheus'
      password_file: '/etc/prometheus/secrets/password'

    # TLS配置
    tls_config:
      ca_file: '/etc/prometheus/certs/ca.crt'
      cert_file: '/etc/prometheus/certs/client.crt'
      key_file: '/etc/prometheus/certs/client.key'

  # ----------------------------------------
  # 文件服务发现
  # ----------------------------------------
  - job_name: 'file-discovery'
    file_sd_configs:
      - files:
          - '/etc/prometheus/targets/*.json'
          - '/etc/prometheus/targets/*.yml'
        # 文件刷新间隔
        refresh_interval: 5m

  # ----------------------------------------
  # Kubernetes服务发现
  # ----------------------------------------
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
        namespaces:
          names:
            - production
            - staging

    # 保留带有prometheus.io/scrape注解的Pod
    relabel_configs:
      # 只抓取标记了scrape: true的Pod
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true

      # 使用注解中指定的端口
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        target_label: __address__
        regex: (.+)
        replacement: $1

      # 使用注解中指定的路径
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)

      # 添加Kubernetes元数据作为标签
      - source_labels: [__meta_kubernetes_namespace]
        target_label: kubernetes_namespace

      - source_labels: [__meta_kubernetes_pod_name]
        target_label: kubernetes_pod_name

      - source_labels: [__meta_kubernetes_pod_label_app]
        target_label: app

  # ----------------------------------------
  # Consul服务发现
  # ----------------------------------------
  - job_name: 'consul-services'
    consul_sd_configs:
      - server: 'consul.example.com:8500'
        services: []  # 发现所有服务

    relabel_configs:
      # 只保留标记为可抓取的服务
      - source_labels: [__meta_consul_tags]
        regex: .*,prometheus,.*
        action: keep

      # 使用服务名作为job标签
      - source_labels: [__meta_consul_service]
        target_label: job

  # ----------------------------------------
  # EC2服务发现
  # ----------------------------------------
  - job_name: 'ec2-instances'
    ec2_sd_configs:
      - region: 'us-east-1'
        port: 9090
        filters:
          - name: 'tag:prometheus'
            values: ['true']

    relabel_configs:
      - source_labels: [__meta_ec2_tag_Name]
        target_label: instance_name

      - source_labels: [__meta_ec2_availability_zone]
        target_label: availability_zone

# ==========================================
# 远程写入配置（长期存储）
# ==========================================
remote_write:
  - url: 'http://thanos-receive:19291/api/v1/receive'
    # 队列配置
    queue_config:
      max_samples_per_send: 1000
      batch_send_deadline: 5s
      capacity: 10000
      max_shards: 200

    # 写入重试
    write_relabel_configs:
      # 删除高基数标签
      - source_labels: [__name__]
        regex: '(go_gc_duration_seconds.*|go_memstats_.*)'
        action: drop

# ==========================================
# 存储配置
# ==========================================
storage:
  tsdb:
    # 本地存储保留时间
    retention.time: 15d
    retention.size: 50GB

    # WAL压缩
    wal-compression: true
```

---

#### 4.2 PromQL高级查询技巧

```yaml
# ==========================================
# PromQL高级用法速查
# ==========================================

# ==========================================
# 1. 速率计算
# ==========================================

# rate(): 计算Counter的每秒速率（适用于慢变化）
# - 自动处理Counter重置
# - 时间范围至少包含2个数据点
queries:
  - name: "每秒请求数"
    expr: rate(http_requests_total[5m])

  # irate(): 瞬时速率（使用最后两个点，适用于快变化）
  - name: "瞬时请求速率"
    expr: irate(http_requests_total[5m])

  # increase(): 时间范围内的增量
  - name: "过去1小时的请求总数"
    expr: increase(http_requests_total[1h])

# ==========================================
# 2. 聚合操作
# ==========================================

  # sum: 求和
  - name: "所有服务的总请求数"
    expr: sum(rate(http_requests_total[5m]))

  # sum by: 按标签分组求和
  - name: "按服务分组的请求数"
    expr: sum by (service) (rate(http_requests_total[5m]))

  # sum without: 排除某些标签后求和
  - name: "排除instance后的请求数"
    expr: sum without (instance) (rate(http_requests_total[5m]))

  # avg, min, max: 平均值、最小值、最大值
  - name: "平均CPU使用率"
    expr: avg by (instance) (rate(node_cpu_seconds_total{mode!="idle"}[5m]))

  # count: 计数
  - name: "健康实例数"
    expr: count(up == 1)

  # topk/bottomk: 前N个/后N个
  - name: "请求量最高的5个端点"
    expr: topk(5, sum by (path) (rate(http_requests_total[5m])))

  # quantile: 分位数
  - name: "请求数的P90"
    expr: quantile(0.9, sum by (instance) (rate(http_requests_total[5m])))

# ==========================================
# 3. Histogram查询
# ==========================================

  # histogram_quantile: 从Histogram计算分位数
  - name: "P99延迟"
    expr: |
      histogram_quantile(0.99,
        sum by (le) (rate(http_request_duration_seconds_bucket[5m]))
      )

  # 按标签分组的分位数
  - name: "按服务的P95延迟"
    expr: |
      histogram_quantile(0.95,
        sum by (le, service) (rate(http_request_duration_seconds_bucket[5m]))
      )

  # 平均延迟（从sum和count计算）
  - name: "平均请求延迟"
    expr: |
      rate(http_request_duration_seconds_sum[5m])
      /
      rate(http_request_duration_seconds_count[5m])

# ==========================================
# 4. 时间函数
# ==========================================

  # time(): 当前Unix时间戳
  # timestamp(): 样本的时间戳
  - name: "最后更新时间距现在的秒数"
    expr: time() - timestamp(up)

  # day_of_week(), hour(): 时间分量
  - name: "工作日的请求数（周一=1到周五=5）"
    expr: |
      sum(rate(http_requests_total[5m])) and on() day_of_week() >= 1 <= 5

  # predict_linear: 线性预测
  - name: "预测4小时后的磁盘使用量"
    expr: predict_linear(node_filesystem_avail_bytes[1h], 4*3600)

  # deriv: 导数（变化速率）
  - name: "内存使用变化速率"
    expr: deriv(process_resident_memory_bytes[5m])

# ==========================================
# 5. 比较和过滤
# ==========================================

  # 比较运算符
  - name: "错误率超过5%的服务"
    expr: |
      (
        sum by (service) (rate(http_requests_total{status=~"5.."}[5m]))
        /
        sum by (service) (rate(http_requests_total[5m]))
      ) > 0.05

  # bool修饰符：返回0或1
  - name: "服务是否健康（布尔值）"
    expr: up == bool 1

  # 缺失值处理
  - name: "如果没有数据则返回0"
    expr: sum(rate(http_requests_total[5m])) or vector(0)

# ==========================================
# 6. 标签操作
# ==========================================

  # label_replace: 替换标签值
  - name: "从instance提取主机名"
    expr: |
      label_replace(
        up,
        "hostname",
        "$1",
        "instance",
        "([^:]+):.*"
      )

  # label_join: 合并标签
  - name: "创建复合标签"
    expr: |
      label_join(
        up,
        "full_name",
        "-",
        "job",
        "instance"
      )

# ==========================================
# 7. 子查询
# ==========================================

  # 子查询语法: metric[range:resolution]
  - name: "过去1小时每5分钟的最大请求率"
    expr: max_over_time(rate(http_requests_total[5m])[1h:5m])

  # 嵌套子查询
  - name: "P99延迟的1小时平均值"
    expr: |
      avg_over_time(
        histogram_quantile(0.99,
          sum by (le) (rate(http_request_duration_seconds_bucket[5m]))
        )[1h:1m]
      )

# ==========================================
# 8. 常用模式
# ==========================================

  # 错误率计算
  - name: "HTTP错误率"
    expr: |
      sum(rate(http_requests_total{status=~"5.."}[5m]))
      /
      sum(rate(http_requests_total[5m]))

  # 可用性计算
  - name: "服务可用性"
    expr: |
      avg_over_time(up[24h])

  # Apdex分数
  - name: "Apdex分数(满意<0.5s, 容忍<2s)"
    expr: |
      (
        sum(rate(http_request_duration_seconds_bucket{le="0.5"}[5m]))
        +
        sum(rate(http_request_duration_seconds_bucket{le="2"}[5m]))
      )
      /
      2
      /
      sum(rate(http_request_duration_seconds_count[5m]))

  # 饱和度
  - name: "CPU饱和度"
    expr: |
      1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m]))
```

---

#### 4.3 告警规则设计最佳实践

```yaml
# ==========================================
# 生产级告警规则示例
# ==========================================
# 文件: /etc/prometheus/alerts/application.yml

groups:
  # ==========================================
  # SLO相关告警
  # ==========================================
  - name: slo_alerts
    rules:
      # ----------------------------------------
      # 基于Error Budget的告警
      # ----------------------------------------
      - alert: ErrorBudgetBurnRateCritical
        # 快速燃烧：1小时内消耗超过2%的错误预算
        expr: |
          (
            sum(rate(http_requests_total{status=~"5.."}[1h]))
            /
            sum(rate(http_requests_total[1h]))
          ) > 14.4 * (1 - 0.999)  # 14.4倍正常燃烧率
        for: 2m
        labels:
          severity: critical
          team: platform
        annotations:
          summary: "错误预算快速燃烧"
          description: |
            服务 {{ $labels.service }} 的错误率过高。
            当前错误率: {{ $value | humanizePercentage }}
            按此速率，月度错误预算将在 {{ printf "%.1f" (30.0 / 14.4) }} 天内耗尽。
          runbook_url: "https://runbooks.example.com/error-budget-burn"

      - alert: ErrorBudgetBurnRateWarning
        # 慢速燃烧：6小时内消耗超过5%的错误预算
        expr: |
          (
            sum(rate(http_requests_total{status=~"5.."}[6h]))
            /
            sum(rate(http_requests_total[6h]))
          ) > 6 * (1 - 0.999)  # 6倍正常燃烧率
        for: 30m
        labels:
          severity: warning
          team: platform
        annotations:
          summary: "错误预算持续燃烧"
          description: |
            服务 {{ $labels.service }} 的错误率持续偏高。
            如果趋势继续，月度错误预算将提前耗尽。

      # ----------------------------------------
      # 延迟SLO告警
      # ----------------------------------------
      - alert: LatencySLOViolation
        expr: |
          histogram_quantile(0.99,
            sum by (service, le) (rate(http_request_duration_seconds_bucket[5m]))
          ) > 1.0  # P99 > 1秒
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "延迟SLO违规"
          description: |
            服务 {{ $labels.service }} 的P99延迟超过SLO。
            当前P99: {{ $value | humanizeDuration }}
            SLO目标: 1秒

  # ==========================================
  # 服务健康告警
  # ==========================================
  - name: service_health
    rules:
      # ----------------------------------------
      # 服务不可用
      # ----------------------------------------
      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "服务不可用"
          description: |
            目标 {{ $labels.instance }} (job: {{ $labels.job }}) 已宕机。
            最后一次成功抓取: {{ humanizeTimestamp $value }}

      # ----------------------------------------
      # 高错误率
      # ----------------------------------------
      - alert: HighErrorRate
        expr: |
          (
            sum by (service) (rate(http_requests_total{status=~"5.."}[5m]))
            /
            sum by (service) (rate(http_requests_total[5m]))
          ) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "高错误率"
          description: |
            服务 {{ $labels.service }} 的错误率超过5%。
            当前错误率: {{ $value | humanizePercentage }}
            影响端点: 所有

      # ----------------------------------------
      # 流量异常
      # ----------------------------------------
      - alert: TrafficAnomaly
        expr: |
          (
            sum(rate(http_requests_total[5m]))
            /
            sum(rate(http_requests_total[1h] offset 1d))  # 与昨天同一时间对比
          ) > 2 or
          (
            sum(rate(http_requests_total[5m]))
            /
            sum(rate(http_requests_total[1h] offset 1d))
          ) < 0.5
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "流量异常"
          description: |
            当前流量与昨天同期相比异常。
            变化比例: {{ $value | humanizePercentage }}

  # ==========================================
  # 资源告警
  # ==========================================
  - name: resource_alerts
    rules:
      # ----------------------------------------
      # CPU使用率
      # ----------------------------------------
      - alert: HighCpuUsage
        expr: |
          (1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m]))) > 0.85
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "CPU使用率过高"
          description: |
            实例 {{ $labels.instance }} 的CPU使用率超过85%。
            当前使用率: {{ $value | humanizePercentage }}
          action: "考虑扩容或优化应用"

      # ----------------------------------------
      # 内存使用率
      # ----------------------------------------
      - alert: HighMemoryUsage
        expr: |
          (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "内存使用率过高"
          description: |
            实例 {{ $labels.instance }} 的内存使用率超过90%。
            可用内存: {{ $value | humanize1024 }}B

      # ----------------------------------------
      # 磁盘空间预测
      # ----------------------------------------
      - alert: DiskWillFillIn24Hours
        expr: |
          predict_linear(node_filesystem_avail_bytes{fstype!="tmpfs"}[6h], 24*3600) < 0
        for: 30m
        labels:
          severity: warning
        annotations:
          summary: "磁盘空间即将耗尽"
          description: |
            按当前趋势，{{ $labels.mountpoint }} 将在24小时内耗尽。
            当前可用: {{ with query "node_filesystem_avail_bytes{instance='%s',mountpoint='%s'}" .Labels.instance .Labels.mountpoint }}{{ . | first | value | humanize1024 }}B{{ end }}

  # ==========================================
  # 应用特定告警
  # ==========================================
  - name: application_specific
    rules:
      # ----------------------------------------
      # 队列积压
      # ----------------------------------------
      - alert: QueueBacklogHigh
        expr: |
          sum by (queue) (queue_length) > 1000
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "队列积压"
          description: |
            队列 {{ $labels.queue }} 积压了 {{ $value }} 个消息。

      # ----------------------------------------
      # 数据库连接池
      # ----------------------------------------
      - alert: DatabaseConnectionPoolExhausted
        expr: |
          db_connection_pool_available / db_connection_pool_max < 0.1
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "数据库连接池即将耗尽"
          description: |
            可用连接数: {{ $value | humanize }}%
            建议立即检查慢查询或增加连接池大小。

      # ----------------------------------------
      # 缓存命中率
      # ----------------------------------------
      - alert: LowCacheHitRate
        expr: |
          rate(cache_hits_total[5m]) /
          (rate(cache_hits_total[5m]) + rate(cache_misses_total[5m])) < 0.8
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "缓存命中率低"
          description: |
            缓存命中率降至 {{ $value | humanizePercentage }}，低于80%。
            可能导致后端压力增加。
```

---

#### 4.4 Alertmanager配置

```yaml
# ==========================================
# alertmanager.yml - 告警管理器配置
# ==========================================

global:
  # 如果告警未被resolve,多久后再次发送
  resolve_timeout: 5m

  # SMTP配置
  smtp_smarthost: 'smtp.example.com:587'
  smtp_from: 'alertmanager@example.com'
  smtp_auth_username: 'alertmanager'
  smtp_auth_password_file: '/etc/alertmanager/secrets/smtp_password'
  smtp_require_tls: true

  # Slack配置
  slack_api_url_file: '/etc/alertmanager/secrets/slack_webhook'

  # PagerDuty配置
  pagerduty_url: 'https://events.pagerduty.com/v2/enqueue'

# ==========================================
# 告警模板
# ==========================================
templates:
  - '/etc/alertmanager/templates/*.tmpl'

# ==========================================
# 路由规则
# ==========================================
route:
  # 默认接收者
  receiver: 'default'

  # 分组规则
  group_by: ['alertname', 'service', 'severity']

  # 分组等待时间（收集更多同组告警）
  group_wait: 30s

  # 同组告警发送间隔
  group_interval: 5m

  # 重复告警发送间隔
  repeat_interval: 4h

  # 子路由
  routes:
    # Critical告警 -> PagerDuty
    - match:
        severity: critical
      receiver: 'pagerduty-critical'
      continue: true  # 继续匹配其他路由

    # 特定团队的告警
    - match:
        team: platform
      receiver: 'platform-team-slack'
      routes:
        - match:
            severity: critical
          receiver: 'platform-team-pagerduty'

    - match:
        team: frontend
      receiver: 'frontend-team-slack'

    # 非工作时间的告警
    - match_re:
        severity: warning|info
      mute_time_intervals:
        - 'outside-business-hours'
      receiver: 'email-oncall'

# ==========================================
# 接收者定义
# ==========================================
receivers:
  - name: 'default'
    email_configs:
      - to: 'oncall@example.com'
        send_resolved: true

  - name: 'pagerduty-critical'
    pagerduty_configs:
      - service_key_file: '/etc/alertmanager/secrets/pagerduty_key'
        severity: critical
        description: '{{ .CommonAnnotations.summary }}'
        details:
          firing: '{{ template "pagerduty.default.instances" .Alerts.Firing }}'
          num_firing: '{{ .Alerts.Firing | len }}'
          num_resolved: '{{ .Alerts.Resolved | len }}'

  - name: 'platform-team-slack'
    slack_configs:
      - channel: '#platform-alerts'
        send_resolved: true
        title: '{{ .Status | toUpper }} {{ .CommonLabels.alertname }}'
        text: |
          {{ range .Alerts }}
          *Alert:* {{ .Annotations.summary }}
          *Description:* {{ .Annotations.description }}
          *Severity:* {{ .Labels.severity }}
          *Service:* {{ .Labels.service }}
          {{ end }}
        actions:
          - type: button
            text: 'Runbook'
            url: '{{ (index .Alerts 0).Annotations.runbook_url }}'
          - type: button
            text: 'Dashboard'
            url: 'https://grafana.example.com/d/{{ .CommonLabels.service }}'

  - name: 'platform-team-pagerduty'
    pagerduty_configs:
      - service_key_file: '/etc/alertmanager/secrets/platform_pagerduty'

  - name: 'frontend-team-slack'
    slack_configs:
      - channel: '#frontend-alerts'

  - name: 'email-oncall'
    email_configs:
      - to: 'oncall@example.com'

# ==========================================
# 静默时间
# ==========================================
time_intervals:
  - name: 'outside-business-hours'
    time_intervals:
      # 周末全天
      - weekdays: ['saturday', 'sunday']
      # 工作日非工作时间
      - weekdays: ['monday:friday']
        times:
          - start_time: '00:00'
            end_time: '09:00'
          - start_time: '18:00'
            end_time: '24:00'

# ==========================================
# 抑制规则
# ==========================================
inhibit_rules:
  # 如果服务宕机，抑制其他相关告警
  - source_match:
      alertname: 'ServiceDown'
    target_match_re:
      alertname: '.*'
    equal: ['service']

  # Critical级别告警抑制Warning级别
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'service']
```

---

#### 4.5 SLO/SLI/Error Budget

```cpp
// ==========================================
// SLO/SLI/Error Budget 概念详解
// ==========================================
//
// SLI (Service Level Indicator) - 服务水平指标
//   - 可量化的服务质量指标
//   - 例如：可用性、延迟、吞吐量
//
// SLO (Service Level Objective) - 服务水平目标
//   - SLI的目标值
//   - 例如：可用性99.9%，P99延迟<500ms
//
// SLA (Service Level Agreement) - 服务水平协议
//   - 与客户的正式约定
//   - 包含SLO和违约后果
//
// Error Budget - 错误预算
//   - 允许的错误/不可用时间
//   - Error Budget = 100% - SLO
//   - 用于平衡可靠性和开发速度

#include <chrono>
#include <cmath>

namespace slo {

// ==========================================
// SLO计算器
// ==========================================

class SloCalculator {
public:
    // 计算错误预算
    static double calculateErrorBudget(double slo_target) {
        // 例如: 99.9% SLO -> 0.1% 错误预算
        return 1.0 - slo_target;
    }

    // 计算月度允许的停机时间
    static std::chrono::seconds calculateAllowedDowntime(
            double slo_target,
            std::chrono::hours period = std::chrono::hours{30 * 24}) {
        double error_budget = calculateErrorBudget(slo_target);
        auto total_seconds = std::chrono::duration_cast<std::chrono::seconds>(period);
        return std::chrono::seconds{
            static_cast<long>(total_seconds.count() * error_budget)
        };
    }

    // 计算当前错误预算消耗百分比
    static double calculateBudgetConsumed(
            double slo_target,
            uint64_t total_requests,
            uint64_t failed_requests) {
        if (total_requests == 0) return 0.0;

        double error_budget = calculateErrorBudget(slo_target);
        double allowed_failures = total_requests * error_budget;
        double consumed = static_cast<double>(failed_requests) / allowed_failures;

        return std::min(consumed, 1.0);  // 上限100%
    }

    // 计算错误预算燃烧率
    static double calculateBurnRate(
            double current_error_rate,
            double slo_target) {
        double allowed_error_rate = calculateErrorBudget(slo_target);
        return current_error_rate / allowed_error_rate;
    }
};

// ==========================================
// SLO指标
// ==========================================

struct SloMetrics {
    // 可用性SLO
    struct Availability {
        double target = 0.999;  // 99.9%

        // 计算当前可用性
        static double calculate(uint64_t successful, uint64_t total) {
            if (total == 0) return 1.0;
            return static_cast<double>(successful) / total;
        }
    };

    // 延迟SLO
    struct Latency {
        double target_percentile = 0.99;  // P99
        double target_seconds = 0.5;       // 500ms

        // 检查是否符合SLO
        static bool meetsTarget(double actual_percentile,
                                double target_seconds) {
            return actual_percentile <= target_seconds;
        }
    };

    // 吞吐量SLO
    struct Throughput {
        double min_requests_per_second = 1000.0;

        static bool meetsTarget(double actual_rps, double min_rps) {
            return actual_rps >= min_rps;
        }
    };
};

// ==========================================
// SLO仪表板PromQL查询
// ==========================================

/*
# 可用性SLO (99.9%)
slo_target = 0.999

# 当前可用性（过去30天）
availability_30d =
  sum(rate(http_requests_total{status!~"5.."}[30d]))
  /
  sum(rate(http_requests_total[30d]))

# 错误预算剩余
error_budget_remaining =
  1 - (
    (1 - availability_30d) / (1 - slo_target)
  )

# 错误预算燃烧率（快速燃烧）
burn_rate_fast =
  sum(rate(http_requests_total{status=~"5.."}[1h]))
  /
  sum(rate(http_requests_total[1h]))
  /
  (1 - slo_target)

# 错误预算燃烧率（慢速燃烧）
burn_rate_slow =
  sum(rate(http_requests_total{status=~"5.."}[6h]))
  /
  sum(rate(http_requests_total[6h]))
  /
  (1 - slo_target)
*/

} // namespace slo
```

---

#### 4.6 Grafana仪表板设计

```json
{
  "_comment": "==========================================",
  "_comment2": "生产级Grafana仪表板模板",
  "_comment3": "==========================================",

  "dashboard": {
    "title": "Service Overview - Production",
    "uid": "service-overview-prod",
    "tags": ["production", "overview", "slo"],
    "timezone": "browser",
    "refresh": "30s",

    "templating": {
      "list": [
        {
          "name": "service",
          "type": "query",
          "query": "label_values(http_requests_total, service)",
          "refresh": 1,
          "multi": false
        },
        {
          "name": "instance",
          "type": "query",
          "query": "label_values(http_requests_total{service=\"$service\"}, instance)",
          "refresh": 1,
          "multi": true,
          "includeAll": true
        }
      ]
    },

    "panels": [
      {
        "_comment": "========== 第一行：SLO概览 ==========",
        "title": "Error Budget Remaining",
        "type": "gauge",
        "gridPos": {"x": 0, "y": 0, "w": 6, "h": 4},
        "targets": [
          {
            "expr": "(1 - ((1 - (sum(rate(http_requests_total{service=\"$service\", status!~\"5..\"}[$__range])) / sum(rate(http_requests_total{service=\"$service\"}[$__range])))) / 0.001)) * 100",
            "legendFormat": "Error Budget"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "min": 0,
            "max": 100,
            "unit": "percent",
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {"color": "red", "value": 0},
                {"color": "yellow", "value": 25},
                {"color": "green", "value": 50}
              ]
            }
          }
        }
      },
      {
        "title": "Current Availability",
        "type": "stat",
        "gridPos": {"x": 6, "y": 0, "w": 6, "h": 4},
        "targets": [
          {
            "expr": "sum(rate(http_requests_total{service=\"$service\", status!~\"5..\"}[5m])) / sum(rate(http_requests_total{service=\"$service\"}[5m]))",
            "legendFormat": "Availability"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percentunit",
            "decimals": 4,
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {"color": "red", "value": 0},
                {"color": "yellow", "value": 0.99},
                {"color": "green", "value": 0.999}
              ]
            }
          }
        }
      },
      {
        "title": "P99 Latency",
        "type": "stat",
        "gridPos": {"x": 12, "y": 0, "w": 6, "h": 4},
        "targets": [
          {
            "expr": "histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket{service=\"$service\"}[5m])))",
            "legendFormat": "P99"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "s",
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {"color": "green", "value": 0},
                {"color": "yellow", "value": 0.5},
                {"color": "red", "value": 1}
              ]
            }
          }
        }
      },
      {
        "title": "Request Rate",
        "type": "stat",
        "gridPos": {"x": 18, "y": 0, "w": 6, "h": 4},
        "targets": [
          {
            "expr": "sum(rate(http_requests_total{service=\"$service\"}[5m]))",
            "legendFormat": "RPS"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "reqps",
            "decimals": 1
          }
        }
      },

      {
        "_comment": "========== 第二行：RED指标 ==========",
        "title": "Request Rate by Status",
        "type": "timeseries",
        "gridPos": {"x": 0, "y": 4, "w": 8, "h": 8},
        "targets": [
          {
            "expr": "sum by (status) (rate(http_requests_total{service=\"$service\"}[5m]))",
            "legendFormat": "{{status}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "reqps",
            "custom": {
              "drawStyle": "line",
              "lineWidth": 1,
              "fillOpacity": 10,
              "pointSize": 5,
              "stacking": {"mode": "normal"}
            }
          },
          "overrides": [
            {
              "matcher": {"id": "byRegexp", "options": "5.."},
              "properties": [{"id": "color", "value": {"mode": "fixed", "fixedColor": "red"}}]
            }
          ]
        }
      },
      {
        "title": "Error Rate",
        "type": "timeseries",
        "gridPos": {"x": 8, "y": 4, "w": 8, "h": 8},
        "targets": [
          {
            "expr": "sum(rate(http_requests_total{service=\"$service\", status=~\"5..\"}[5m])) / sum(rate(http_requests_total{service=\"$service\"}[5m]))",
            "legendFormat": "Error Rate"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percentunit",
            "min": 0,
            "max": 1,
            "custom": {
              "drawStyle": "line",
              "fillOpacity": 20
            }
          }
        },
        "options": {
          "tooltip": {"mode": "single"}
        }
      },
      {
        "title": "Latency Distribution",
        "type": "timeseries",
        "gridPos": {"x": 16, "y": 4, "w": 8, "h": 8},
        "targets": [
          {
            "expr": "histogram_quantile(0.50, sum by (le) (rate(http_request_duration_seconds_bucket{service=\"$service\"}[5m])))",
            "legendFormat": "P50"
          },
          {
            "expr": "histogram_quantile(0.90, sum by (le) (rate(http_request_duration_seconds_bucket{service=\"$service\"}[5m])))",
            "legendFormat": "P90"
          },
          {
            "expr": "histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket{service=\"$service\"}[5m])))",
            "legendFormat": "P99"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "s",
            "custom": {
              "drawStyle": "line",
              "lineWidth": 2
            }
          }
        }
      },

      {
        "_comment": "========== 第三行：资源使用 ==========",
        "title": "CPU Usage by Instance",
        "type": "timeseries",
        "gridPos": {"x": 0, "y": 12, "w": 12, "h": 6},
        "targets": [
          {
            "expr": "rate(process_cpu_seconds_total{service=\"$service\"}[5m])",
            "legendFormat": "{{instance}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percentunit"
          }
        }
      },
      {
        "title": "Memory Usage by Instance",
        "type": "timeseries",
        "gridPos": {"x": 12, "y": 12, "w": 12, "h": 6},
        "targets": [
          {
            "expr": "process_resident_memory_bytes{service=\"$service\"}",
            "legendFormat": "{{instance}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "bytes"
          }
        }
      }
    ]
  }
}
```

---

#### 4.7 长期存储方案

```yaml
# ==========================================
# Thanos架构概览
# ==========================================
#
# Thanos是Prometheus的高可用和长期存储解决方案
#
# ┌─────────────────────────────────────────────────────────────────────┐
# │                         Thanos架构                                  │
# ├─────────────────────────────────────────────────────────────────────┤
# │                                                                     │
# │  ┌───────────┐    ┌───────────┐    ┌───────────┐                   │
# │  │Prometheus │    │Prometheus │    │Prometheus │                   │
# │  │  + Sidecar│    │  + Sidecar│    │  + Sidecar│                   │
# │  └─────┬─────┘    └─────┬─────┘    └─────┬─────┘                   │
# │        │                │                │                          │
# │        └────────────────┼────────────────┘                          │
# │                         │                                           │
# │                   ┌─────┴─────┐                                     │
# │                   │   Query   │  ← 统一查询入口                      │
# │                   └─────┬─────┘                                     │
# │                         │                                           │
# │        ┌────────────────┼────────────────┐                          │
# │        │                │                │                          │
# │  ┌─────┴─────┐    ┌─────┴─────┐    ┌─────┴─────┐                   │
# │  │  Store    │    │  Store    │    │ Compact   │                   │
# │  │ Gateway   │    │ Gateway   │    │           │                   │
# │  └─────┬─────┘    └─────┬─────┘    └─────┬─────┘                   │
# │        │                │                │                          │
# │        └────────────────┼────────────────┘                          │
# │                         │                                           │
# │                   ┌─────┴─────┐                                     │
# │                   │   Object  │  ← S3/GCS/Azure Blob                │
# │                   │   Storage │                                     │
# │                   └───────────┘                                     │
# │                                                                     │
# └─────────────────────────────────────────────────────────────────────┘

# docker-compose.thanos.yml
version: '3.8'

services:
  # Prometheus + Thanos Sidecar
  prometheus:
    image: prom/prometheus:v2.45.0
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.max-block-duration=2h'
      - '--storage.tsdb.min-block-duration=2h'
      - '--web.enable-lifecycle'
      - '--web.enable-admin-api'

  thanos-sidecar:
    image: quay.io/thanos/thanos:v0.32.0
    volumes:
      - prometheus_data:/prometheus
      - ./bucket.yml:/etc/thanos/bucket.yml
    command:
      - 'sidecar'
      - '--tsdb.path=/prometheus'
      - '--prometheus.url=http://prometheus:9090'
      - '--objstore.config-file=/etc/thanos/bucket.yml'

  # Thanos Query
  thanos-query:
    image: quay.io/thanos/thanos:v0.32.0
    ports:
      - "19192:19192"
    command:
      - 'query'
      - '--http-address=0.0.0.0:19192'
      - '--store=thanos-sidecar:10901'
      - '--store=thanos-store:10901'

  # Thanos Store Gateway
  thanos-store:
    image: quay.io/thanos/thanos:v0.32.0
    volumes:
      - ./bucket.yml:/etc/thanos/bucket.yml
    command:
      - 'store'
      - '--data-dir=/var/thanos/store'
      - '--objstore.config-file=/etc/thanos/bucket.yml'

  # Thanos Compactor
  thanos-compactor:
    image: quay.io/thanos/thanos:v0.32.0
    volumes:
      - ./bucket.yml:/etc/thanos/bucket.yml
    command:
      - 'compact'
      - '--data-dir=/var/thanos/compact'
      - '--objstore.config-file=/etc/thanos/bucket.yml'
      - '--wait'

  # MinIO (本地S3兼容存储，用于测试)
  minio:
    image: minio/minio:latest
    ports:
      - "9000:9000"
    volumes:
      - minio_data:/data
    environment:
      MINIO_ACCESS_KEY: thanos
      MINIO_SECRET_KEY: thanospassword
    command: server /data

volumes:
  prometheus_data:
  minio_data:
```

```yaml
# bucket.yml - 对象存储配置
type: S3
config:
  bucket: "thanos-data"
  endpoint: "minio:9000"
  access_key: "thanos"
  secret_key: "thanospassword"
  insecure: true
```

---

#### 4.8 容量规划

```cpp
// ==========================================
// Prometheus容量规划计算器
// ==========================================

namespace capacity {

// 估算Prometheus资源需求
struct PrometheusCapacityEstimate {
    // 输入参数
    size_t num_time_series;       // 时间序列数量
    size_t scrape_interval_sec;   // 抓取间隔（秒）
    size_t retention_days;        // 保留天数
    size_t avg_labels_per_series; // 每个序列的平均标签数
    size_t avg_label_length;      // 平均标签长度

    // 计算每秒样本数
    double samples_per_second() const {
        return static_cast<double>(num_time_series) / scrape_interval_sec;
    }

    // 估算内存使用（Head Block）
    // 规则：约1.5-2KB每个活跃时间序列
    size_t estimated_memory_bytes() const {
        size_t bytes_per_series = 1500 +
            (avg_labels_per_series * avg_label_length * 2);
        return num_time_series * bytes_per_series;
    }

    // 估算磁盘使用
    // 压缩后约1-2字节每个样本
    size_t estimated_disk_bytes() const {
        double samples_per_day = samples_per_second() * 86400;
        double total_samples = samples_per_day * retention_days;
        double bytes_per_sample = 1.5;  // 压缩后
        return static_cast<size_t>(total_samples * bytes_per_sample);
    }

    // 估算CPU核心数
    // 规则：每100万时间序列约需1个CPU核心
    double estimated_cpu_cores() const {
        return num_time_series / 1000000.0 + 1;  // 基础1核
    }

    // 打印估算结果
    void print() const {
        std::cout << "=== Prometheus容量估算 ===" << std::endl;
        std::cout << "时间序列数量: " << num_time_series << std::endl;
        std::cout << "每秒样本数: " << samples_per_second() << std::endl;
        std::cout << std::endl;
        std::cout << "预估内存: " << (estimated_memory_bytes() / (1024.0 * 1024 * 1024))
                  << " GB" << std::endl;
        std::cout << "预估磁盘: " << (estimated_disk_bytes() / (1024.0 * 1024 * 1024))
                  << " GB" << std::endl;
        std::cout << "建议CPU: " << estimated_cpu_cores() << " 核心" << std::endl;
    }
};

// 时间序列数量估算
struct SeriesEstimator {
    // 估算HTTP指标的时间序列数
    static size_t http_metrics(
            size_t num_services,
            size_t instances_per_service,
            size_t endpoints_per_service,
            size_t http_methods,
            size_t status_codes) {
        // http_requests_total
        size_t counter_series = num_services * instances_per_service *
                                endpoints_per_service * http_methods * status_codes;

        // http_request_duration_seconds (histogram, 默认13个桶)
        size_t histogram_series = counter_series * 13;

        return counter_series + histogram_series;
    }

    // 估算系统指标的时间序列数
    static size_t system_metrics(
            size_t num_hosts,
            size_t cpus_per_host,
            size_t disks_per_host,
            size_t network_interfaces_per_host) {
        size_t cpu_series = num_hosts * cpus_per_host * 10;  // 多种CPU模式
        size_t disk_series = num_hosts * disks_per_host * 5;
        size_t network_series = num_hosts * network_interfaces_per_host * 8;
        size_t memory_series = num_hosts * 10;

        return cpu_series + disk_series + network_series + memory_series;
    }
};

// 使用示例
void capacity_planning_example() {
    // 场景：100个微服务，每个3个实例
    size_t http_series = SeriesEstimator::http_metrics(
        100,   // 服务数
        3,     // 每服务实例数
        10,    // 每服务端点数
        5,     // HTTP方法数
        5      // 状态码类别数
    );

    size_t system_series = SeriesEstimator::system_metrics(
        300,   // 主机数
        8,     // CPU核心
        2,     // 磁盘
        2      // 网络接口
    );

    PrometheusCapacityEstimate estimate{
        .num_time_series = http_series + system_series,
        .scrape_interval_sec = 15,
        .retention_days = 15,
        .avg_labels_per_series = 5,
        .avg_label_length = 20
    };

    estimate.print();

    // 输出示例：
    // === Prometheus容量估算 ===
    // 时间序列数量: 1000000
    // 每秒样本数: 66666.67
    //
    // 预估内存: 2.5 GB
    // 预估磁盘: 120 GB
    // 建议CPU: 2 核心
}

} // namespace capacity
```

---

#### 4.9 完整Docker Compose监控栈

```yaml
# docker-compose.monitoring.yml
# 完整的生产级监控栈

version: '3.8'

x-logging: &default-logging
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"

services:
  # ==========================================
  # Prometheus
  # ==========================================
  prometheus:
    image: prom/prometheus:v2.45.0
    container_name: prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./prometheus/rules:/etc/prometheus/rules:ro
      - ./prometheus/alerts:/etc/prometheus/alerts:ro
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=15d'
      - '--storage.tsdb.retention.size=50GB'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
      - '--web.enable-admin-api'
    logging: *default-logging
    networks:
      - monitoring

  # ==========================================
  # Alertmanager
  # ==========================================
  alertmanager:
    image: prom/alertmanager:v0.26.0
    container_name: alertmanager
    restart: unless-stopped
    ports:
      - "9093:9093"
    volumes:
      - ./alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
      - ./alertmanager/templates:/etc/alertmanager/templates:ro
      - alertmanager_data:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
      - '--web.external-url=http://alertmanager:9093'
    logging: *default-logging
    networks:
      - monitoring

  # ==========================================
  # Grafana
  # ==========================================
  grafana:
    image: grafana/grafana:10.0.0
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    volumes:
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
      - ./grafana/dashboards:/var/lib/grafana/dashboards:ro
      - grafana_data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SERVER_ROOT_URL=http://grafana:3000
      - GF_ALERTING_ENABLED=true
      - GF_UNIFIED_ALERTING_ENABLED=true
    logging: *default-logging
    networks:
      - monitoring

  # ==========================================
  # Node Exporter (主机指标)
  # ==========================================
  node-exporter:
    image: prom/node-exporter:v1.6.0
    container_name: node-exporter
    restart: unless-stopped
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--path.rootfs=/rootfs'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    logging: *default-logging
    networks:
      - monitoring

  # ==========================================
  # cAdvisor (容器指标)
  # ==========================================
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:v0.47.0
    container_name: cadvisor
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    privileged: true
    logging: *default-logging
    networks:
      - monitoring

  # ==========================================
  # Pushgateway
  # ==========================================
  pushgateway:
    image: prom/pushgateway:v1.6.0
    container_name: pushgateway
    restart: unless-stopped
    ports:
      - "9091:9091"
    logging: *default-logging
    networks:
      - monitoring

  # ==========================================
  # 示例应用
  # ==========================================
  app:
    build:
      context: ./app
      dockerfile: Dockerfile
    container_name: demo-app
    restart: unless-stopped
    ports:
      - "8000:8000"
      - "9092:9090"  # metrics port
    environment:
      - METRICS_PORT=9090
    logging: *default-logging
    networks:
      - monitoring

networks:
  monitoring:
    driver: bridge

volumes:
  prometheus_data:
  alertmanager_data:
  grafana_data:
```

---

#### 4.10 本周练习任务

```cpp
// ==========================================
// 第四周练习任务
// ==========================================

/*
练习1：部署完整监控栈
--------------------------------------
目标：使用Docker Compose部署生产级监控系统

要求：
1. 部署Prometheus + Alertmanager + Grafana
2. 配置服务发现
3. 配置告警规则
4. 创建基础仪表板
5. 验证告警流程

验证：
- 访问各组件Web界面
- 触发测试告警
- 确认Slack/Email通知
*/

/*
练习2：设计SLO并实现告警
--------------------------------------
目标：为你的服务设计SLO并配置告警

要求：
1. 定义可用性SLO（如99.9%）
2. 定义延迟SLO（如P99 < 500ms）
3. 实现Error Budget告警
4. 创建SLO仪表板
5. 编写告警runbook

交付物：
- SLO定义文档
- 告警规则YAML
- Grafana仪表板JSON
*/

/*
练习3：容量规划实践
--------------------------------------
目标：为一个中等规模系统进行容量规划

场景：
- 50个微服务
- 每个服务5个实例
- 每个服务20个HTTP端点
- 15天数据保留

要求：
1. 估算时间序列数量
2. 计算资源需求
3. 设计分片/联邦策略（如需要）
4. 制定扩容计划
*/

/*
练习4：PromQL高级查询
--------------------------------------
目标：熟练使用PromQL

要求：
1. 编写计算错误率的查询
2. 编写计算P95延迟的查询
3. 编写流量对比查询（同比/环比）
4. 编写资源饱和度查询
5. 实现Apdex分数计算
*/

/*
练习5：告警优化
--------------------------------------
目标：减少告警噪音，提高告警质量

当前问题：
- 告警过于频繁
- 误报率高
- 缺少上下文

要求：
1. 分析现有告警
2. 优化for持续时间
3. 添加抑制规则
4. 改进告警注解
5. 实现告警分级
*/
```

---

#### 4.11 本周知识检验

```
思考题1：为什么Prometheus使用Pull模型而不是Push？
提示：考虑服务发现、健康检测、配置管理。

思考题2：如何处理高基数导致的性能问题？
提示：考虑relabel_configs、聚合策略、指标设计。

思考题3：Error Budget的核心价值是什么？
提示：考虑可靠性与开发速度的平衡。

思考题4：histogram_quantile()的精度取决于什么？
提示：考虑桶边界的选择。

思考题5：什么时候应该使用Thanos而不是单机Prometheus？
提示：考虑数据量、保留时间、高可用需求。

实践题1：设计一个微服务系统的监控方案
要求：包括指标设计、告警规则、仪表板

实践题2：编写一个告警规则，当错误预算消耗超过50%时告警
要求：使用多窗口燃烧率方法

实践题3：设计一个处理100万时间序列的Prometheus架构
要求：考虑分片、联邦、长期存储
```

---

## 源码阅读任务

### 本月源码阅读计划

#### 第一周源码阅读：prometheus-cpp核心实现

**仓库**: https://github.com/jupp0r/prometheus-cpp

**重点文件**：
```
prometheus-cpp/
├── core/
│   ├── include/prometheus/
│   │   ├── counter.h          # Counter接口定义
│   │   ├── gauge.h            # Gauge接口定义
│   │   ├── histogram.h        # Histogram接口定义
│   │   ├── summary.h          # Summary接口定义
│   │   ├── family.h           # MetricFamily模板
│   │   ├── registry.h         # 注册表接口
│   │   └── collectable.h      # 收集接口
│   └── src/
│       ├── counter.cc         # Counter实现
│       ├── histogram.cc       # Histogram实现
│       └── registry.cc        # Registry实现
├── pull/
│   └── src/
│       └── exposer.cc         # HTTP暴露器
└── push/
    └── src/
        └── gateway.cc         # Push Gateway客户端
```

**阅读顺序**：
1. `counter.h` - 理解Counter的原子操作实现
2. `family.h` - 理解MetricFamily的模板设计
3. `registry.h/cc` - 理解指标注册和收集流程
4. `exposer.cc` - 理解HTTP服务器实现

**学习要点**：
- [ ] Counter的CAS原子操作
- [ ] Family管理标签维度的方式
- [ ] Registry的线程安全设计
- [ ] TextSerializer的格式化实现

---

#### 第二周源码阅读：Prometheus TSDB

**仓库**: https://github.com/prometheus/prometheus

**重点目录**：
```
prometheus/
├── tsdb/
│   ├── head.go              # Head Block（内存存储）
│   ├── block.go             # 持久化Block
│   ├── compact.go           # 压缩逻辑
│   ├── index/
│   │   └── index.go         # 倒排索引
│   ├── chunks/
│   │   └── chunk.go         # Chunk存储
│   └── wal/
│       └── wal.go           # Write-Ahead Log
└── promql/
    ├── engine.go            # 查询引擎
    ├── parser/
    │   └── lex.go           # 词法分析
    └── functions.go         # 内置函数
```

**阅读顺序**：
1. `tsdb/head.go` - 理解内存时序存储
2. `tsdb/index/index.go` - 理解倒排索引
3. `promql/engine.go` - 理解查询执行
4. `promql/functions.go` - 理解rate()等函数实现

**学习要点**：
- [ ] 时间序列的内存布局
- [ ] Delta-of-Delta时间戳压缩
- [ ] XOR值压缩算法
- [ ] PromQL执行计划

---

#### 第三周源码阅读：OpenTelemetry C++ SDK

**仓库**: https://github.com/open-telemetry/opentelemetry-cpp

**重点目录**：
```
opentelemetry-cpp/
├── api/
│   └── include/opentelemetry/
│       ├── metrics/
│       │   ├── meter.h           # Meter接口
│       │   ├── counter.h         # Counter接口
│       │   └── histogram.h       # Histogram接口
│       └── trace/
│           ├── tracer.h          # Tracer接口
│           └── span.h            # Span接口
├── sdk/
│   └── src/
│       ├── metrics/
│       │   ├── meter.cc          # Meter实现
│       │   └── aggregation/      # 聚合实现
│       └── trace/
│           └── tracer.cc         # Tracer实现
└── exporters/
    ├── prometheus/               # Prometheus导出器
    └── otlp/                     # OTLP导出器
```

**阅读顺序**：
1. `api/metrics/meter.h` - 理解API设计
2. `sdk/metrics/meter.cc` - 理解SDK实现
3. `exporters/prometheus/` - 理解格式转换
4. `exporters/otlp/` - 理解OTLP协议

**学习要点**：
- [ ] API与SDK分离设计
- [ ] 聚合临时性(Temporality)概念
- [ ] 资源(Resource)概念
- [ ] 导出器接口设计

---

#### 第四周源码阅读：Thanos/VictoriaMetrics

**Thanos仓库**: https://github.com/thanos-io/thanos
**VictoriaMetrics仓库**: https://github.com/VictoriaMetrics/VictoriaMetrics

**Thanos重点**：
```
thanos/
├── cmd/
│   ├── thanos/
│   │   ├── sidecar.go       # Sidecar组件
│   │   ├── query.go         # Query组件
│   │   └── store.go         # Store Gateway
├── pkg/
│   ├── store/
│   │   └── bucket.go        # 对象存储接口
│   └── query/
│       └── querier.go       # 分布式查询
```

**学习要点**：
- [ ] Sidecar上传机制
- [ ] Store Gateway数据读取
- [ ] 分布式查询合并
- [ ] Compaction策略

---

## 实践项目

### 综合项目：生产级C++服务监控系统

#### 项目目标
构建一个完整的C++服务监控系统，包括：
1. 自定义指标库（不依赖prometheus-cpp）
2. HTTP服务框架集成
3. 完整的监控栈部署
4. SLO仪表板和告警

#### 项目结构
```
month47-project/
├── metrics-lib/                 # 自定义指标库
│   ├── include/
│   │   └── metrics/
│   │       ├── counter.hpp
│   │       ├── gauge.hpp
│   │       ├── histogram.hpp
│   │       ├── registry.hpp
│   │       └── exposer.hpp
│   ├── src/
│   │   ├── counter.cpp
│   │   ├── histogram.cpp
│   │   └── exposer.cpp
│   └── CMakeLists.txt
│
├── demo-service/                # 示例HTTP服务
│   ├── src/
│   │   ├── main.cpp
│   │   ├── http_handler.cpp
│   │   └── metrics.cpp
│   └── CMakeLists.txt
│
├── monitoring/                  # 监控配置
│   ├── prometheus/
│   │   ├── prometheus.yml
│   │   └── alerts/
│   │       ├── slo.yml
│   │       └── resources.yml
│   ├── alertmanager/
│   │   └── alertmanager.yml
│   └── grafana/
│       ├── provisioning/
│       └── dashboards/
│           ├── service-overview.json
│           └── slo-dashboard.json
│
├── docker-compose.yml
└── README.md
```

#### 实现要求

**阶段1：指标库实现（第1-2周）**
- [ ] 实现线程安全的Counter
- [ ] 实现线程安全的Gauge
- [ ] 实现Histogram（支持自定义桶）
- [ ] 实现Registry（指标注册和收集）
- [ ] 实现HTTP Exposer
- [ ] 编写单元测试

**阶段2：服务集成（第2-3周）**
- [ ] 创建HTTP服务框架
- [ ] 集成指标收集
- [ ] 实现请求计数、延迟、错误率指标
- [ ] 实现资源使用指标
- [ ] 添加健康检查端点

**阶段3：监控部署（第3-4周）**
- [ ] 配置Prometheus抓取
- [ ] 设计告警规则
- [ ] 创建Grafana仪表板
- [ ] 配置Alertmanager
- [ ] 测试告警流程

**阶段4：SLO实现（第4周）**
- [ ] 定义服务SLO
- [ ] 实现Error Budget计算
- [ ] 创建SLO仪表板
- [ ] 配置SLO告警
- [ ] 编写文档

#### 验收标准
1. 指标库通过所有单元测试
2. 服务能正确暴露指标
3. Prometheus能成功抓取
4. Grafana仪表板显示正确
5. 告警能正确触发
6. 文档完整清晰

---

## 检验标准

### 知识掌握检验

#### 基础概念（必须掌握）
- [ ] 理解可观测性三大支柱及其关系
- [ ] 掌握Prometheus四种指标类型
- [ ] 理解Counter和Gauge的区别
- [ ] 理解Histogram的桶机制
- [ ] 掌握指标命名规范

#### 实现能力（必须掌握）
- [ ] 能够实现线程安全的Counter
- [ ] 能够实现Histogram分桶统计
- [ ] 能够实现HTTP指标暴露
- [ ] 能够使用prometheus-cpp库

#### PromQL能力（必须掌握）
- [ ] 能够使用rate()计算速率
- [ ] 能够使用histogram_quantile()计算分位数
- [ ] 能够编写聚合查询
- [ ] 能够编写告警表达式

#### 系统集成（必须掌握）
- [ ] 能够配置Prometheus抓取
- [ ] 能够编写告警规则
- [ ] 能够创建Grafana仪表板
- [ ] 能够配置Alertmanager

#### 进阶能力（建议掌握）
- [ ] 理解时序数据库存储原理
- [ ] 理解高基数问题及解决方案
- [ ] 理解SLO/Error Budget概念
- [ ] 理解OpenTelemetry标准
- [ ] 能够进行容量规划

### 综合知识检验问题

**理论问题**：
1. 解释可观测性与监控的区别
2. Counter为什么只能增加？如何处理进程重启？
3. Histogram和Summary各自的优缺点是什么？
4. 什么是高基数问题？如何避免？
5. 解释Pull和Push模型的优缺点
6. 什么是Error Budget？如何使用它平衡可靠性和开发速度？
7. 解释Prometheus的数据存储架构
8. 如何设计一个好的告警规则？

**实践问题**：
1. 编写PromQL查询计算服务的P99延迟
2. 设计一个HTTP服务的指标方案
3. 为一个微服务设计SLO和对应的告警规则
4. 进行一个中等规模系统的Prometheus容量规划
5. 设计一个支持多后端的指标导出系统

---

## 输出物清单

### 代码产出

1. **自定义指标库**
   - `metrics-lib/` - 完整的C++指标库
   - 包含Counter、Gauge、Histogram、Registry、Exposer
   - 单元测试覆盖率>80%

2. **示例服务**
   - `demo-service/` - 集成指标的HTTP服务
   - 完整的Makefile/CMakeLists.txt
   - Dockerfile

3. **监控配置**
   - `monitoring/prometheus/` - Prometheus配置和规则
   - `monitoring/alertmanager/` - Alertmanager配置
   - `monitoring/grafana/` - Grafana仪表板

### 文档产出

1. **学习笔记**
   - `notes/month47_observability.md` - 可观测性概念笔记
   - `notes/month47_metrics_impl.md` - 指标库实现笔记
   - `notes/month47_prometheus.md` - Prometheus使用笔记

2. **速查表**
   - `notes/promql_cheatsheet.md` - PromQL速查表
   - `notes/alerting_patterns.md` - 告警模式速查

3. **设计文档**
   - `docs/metrics_library_design.md` - 指标库设计文档
   - `docs/monitoring_architecture.md` - 监控架构设计
   - `docs/slo_definition.md` - SLO定义文档

---

## 时间分配表

| 周次 | 主题 | 理论学习 | 实践编码 | 源码阅读 | 总计 |
|------|------|----------|----------|----------|------|
| 第1周 | 可观测性基础 | 12h | 18h | 5h | 35h |
| 第2周 | C++指标库实现 | 10h | 20h | 5h | 35h |
| 第3周 | prometheus-cpp与OTel | 8h | 22h | 5h | 35h |
| 第4周 | 生产监控系统 | 8h | 22h | 5h | 35h |
| **合计** | | **38h** | **82h** | **20h** | **140h** |

### 每日学习建议

- **工作日**: 理论1h + 实践2h + 源码阅读0.5h = 3.5h/天
- **周末**: 理论2h + 实践4h + 源码阅读1h = 7h/天
- **总计**: 3.5h × 5 + 7h × 2 = 31.5h/周

---

## 学习资源

### 必读资源
1. [Prometheus官方文档](https://prometheus.io/docs/)
2. [SRE Book - Chapter 6: Monitoring](https://sre.google/sre-book/monitoring-distributed-systems/)
3. [prometheus-cpp GitHub](https://github.com/jupp0r/prometheus-cpp)

### 推荐阅读
1. [OpenTelemetry规范](https://opentelemetry.io/docs/specs/)
2. [Thanos设计文档](https://thanos.io/tip/thanos/design.md/)
3. [Brendan Gregg - USE Method](http://www.brendangregg.com/usemethod.html)

### 视频课程
1. PromCon演讲录像
2. KubeCon可观测性Track

---

## 下月预告

Month 48将进行**第四年总结与综合项目**，整合全年所学构建一个完整的工程化项目。

**预期内容**：
- 年度知识回顾与整合
- 大型综合项目设计与实现
- 代码review和重构
- 技术文档编写
- 面试准备和能力评估
