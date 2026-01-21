# Month 11: 时间库与chrono——精确的时间处理

## 本月主题概述

时间处理是系统编程的重要部分，C++11引入的chrono库提供了类型安全的时间抽象。本月将深入理解duration、time_point、clock的设计，掌握高精度计时、超时处理和时区转换。

---

## 四周学习概览

| 周次 | 主题 | 核心目标 | 关键输出 |
|------|------|----------|----------|
| **Week 1** | chrono基础设施 | 掌握duration和ratio的设计原理 | mini_duration实现 |
| **Week 2** | 时钟（Clock）系统 | 理解三种时钟的特性和底层实现 | mini_clock跨平台实现 |
| **Week 3** | time_point深化 | 掌握时间点运算和C++20日历/时区 | mini_time_point + 时间工具 |
| **Week 4** | 实际应用 | 在并发、性能分析等场景应用chrono | 完整时间处理工具库 |

---

## 理论学习内容

### 第一周：chrono基础设施（35小时）

**学习目标**：理解chrono的核心抽象

**阅读材料**：
- [ ] 《C++ Concurrency in Action》时间相关章节
- [ ] CppCon演讲："A <chrono> Tutorial"
- [ ] cppreference chrono文档

#### 每日学习计划

| 天数 | 主题 | 学习内容 | 实践任务 | 时间 |
|------|------|----------|----------|------|
| Day 1 | ratio基础 | ratio模板原理、编译期有理数表示 | 验证ratio约简和算术 | 5h |
| Day 2 | ratio元编程 | ratio_add/multiply实现、SFINAE技巧 | 实现ratio_pow | 5h |
| Day 3 | duration核心 | 模板参数Rep/Period、类型推导规则 | 分析duration的sizeof | 5h |
| Day 4 | duration转换 | 隐式转换规则、duration_cast原理 | 编写转换陷阱测试 | 5h |
| Day 5 | 自定义duration | 游戏帧、音频采样等自定义时间单位 | 实现game_frame类型 | 5h |
| Day 6 | duration算术 | 运算符重载、common_type、浮点duration | 完善mini_duration | 5h |
| Day 7 | 综合实验 | 复习本周内容，整合测试 | mini_duration单元测试 | 5h |

**核心概念**：

#### duration（时长）
```cpp
#include <chrono>

// duration模板：duration<Rep, Period>
// Rep: 表示周期数的类型
// Period: ratio类型，表示一个周期占多少秒

// 预定义duration类型
std::chrono::nanoseconds   // duration<至少64位整数, ratio<1, 1000000000>>
std::chrono::microseconds  // ratio<1, 1000000>
std::chrono::milliseconds  // ratio<1, 1000>
std::chrono::seconds       // ratio<1, 1>
std::chrono::minutes       // ratio<60, 1>
std::chrono::hours         // ratio<3600, 1>
std::chrono::days          // C++20, ratio<86400, 1>

// 创建duration
auto d1 = std::chrono::seconds(5);
auto d2 = std::chrono::milliseconds(500);
auto d3 = 5s;    // C++14 字面量
auto d4 = 500ms;
auto d5 = 2.5s;  // 浮点数也可以

// 算术运算
auto sum = d1 + d2;  // 5500ms（自动转换为更精细的单位）
auto diff = d1 - d2; // 4500ms
auto product = d1 * 2;  // 10s
auto quotient = d1 / 2;  // 2s

// duration_cast（显式转换，可能丢失精度）
auto secs = std::chrono::duration_cast<std::chrono::seconds>(d2);  // 0s
```

#### ratio（编译期有理数）
```cpp
// ratio<Num, Denom> 表示 Num/Denom
using kilo  = std::ratio<1000, 1>;    // 1000
using milli = std::ratio<1, 1000>;    // 0.001
using mega  = std::ratio<1000000, 1>;

// 编译期算术
using product = std::ratio_multiply<kilo, milli>;  // ratio<1, 1>
using sum = std::ratio_add<std::ratio<1, 3>, std::ratio<1, 6>>;  // ratio<1, 2>
```

#### 深度扩展：ratio编译期元编程原理

ratio的设计体现了C++模板元编程的精髓——在编译期完成所有计算：

```cpp
#include <ratio>
#include <type_traits>

// ratio内部的编译期GCD实现（欧几里得算法）
template <intmax_t A, intmax_t B>
struct gcd_impl {
    static constexpr intmax_t value = gcd_impl<B, A % B>::value;
};

template <intmax_t A>
struct gcd_impl<A, 0> {
    static constexpr intmax_t value = A;
};

// 验证ratio的编译期约简
void verify_ratio_reduction() {
    // 6/9 应该被约简为 2/3
    using r1 = std::ratio<6, 9>;
    static_assert(r1::num == 2, "numerator should be 2");
    static_assert(r1::den == 3, "denominator should be 3");

    // 负数处理：分母始终为正
    using r2 = std::ratio<-4, -6>;  // 应该是 2/3
    static_assert(r2::num == 2 && r2::den == 3, "double negative");

    using r3 = std::ratio<4, -6>;   // 应该是 -2/3
    static_assert(r3::num == -2 && r3::den == 3, "negative denominator");
}

// 验证ratio算术
void verify_ratio_arithmetic() {
    // 1/3 + 1/6 = 1/2
    using sum = std::ratio_add<std::ratio<1, 3>, std::ratio<1, 6>>;
    static_assert(sum::num == 1 && sum::den == 2, "1/3 + 1/6 = 1/2");

    // 2/3 * 3/4 = 1/2
    using product = std::ratio_multiply<std::ratio<2, 3>, std::ratio<3, 4>>;
    static_assert(product::num == 1 && product::den == 2, "2/3 * 3/4 = 1/2");

    // 编译期比较
    static_assert(std::ratio_less<std::ratio<1, 3>, std::ratio<1, 2>>::value,
                  "1/3 < 1/2");
}
```

#### 深度扩展：duration类型转换陷阱

```cpp
#include <chrono>
#include <iostream>

void conversion_pitfalls() {
    using namespace std::chrono;

    // 陷阱1：整数截断
    auto ms = milliseconds(1999);
    auto s = duration_cast<seconds>(ms);  // 1s，丢失999ms！
    std::cout << "1999ms -> " << s.count() << "s\n";  // 输出: 1

    // 陷阱2：负数截断行为（向零截断，不是向下取整）
    auto neg_ms = milliseconds(-1999);
    auto neg_s = duration_cast<seconds>(neg_ms);  // -1s，不是-2s！
    std::cout << "-1999ms -> " << neg_s.count() << "s\n";  // 输出: -1

    // 陷阱3：隐式转换只允许精度提高
    milliseconds ms2 = seconds(1);  // OK: 1s -> 1000ms
    // seconds s2 = milliseconds(1500);  // 编译错误！

    // 陷阱4：混合运算的类型推导
    auto a = seconds(1);
    auto b = milliseconds(500);
    auto c = a + b;  // c的类型是milliseconds（更精细的单位）
    std::cout << "1s + 500ms = " << c.count() << "ms\n";  // 1500

    // 陷阱5：整数除法截断
    auto d = seconds(5) / 2;  // 2s，不是2.5s！
    // 正确做法：使用浮点duration
    using fsec = duration<double>;
    auto e = fsec(seconds(5)) / 2;  // 2.5s
}

// C++17的floor, ceil, round
void cpp17_rounding() {
    using namespace std::chrono;

    auto ms = milliseconds(1500);

    // floor: 向负无穷截断
    auto f = floor<seconds>(ms);  // 1s

    // ceil: 向正无穷截断
    auto c = ceil<seconds>(ms);   // 2s

    // round: 四舍五入
    auto r = round<seconds>(ms);  // 2s（1500ms更接近2s）

    // 对于负数的行为
    auto neg = milliseconds(-1500);
    std::cout << "floor(-1500ms): " << floor<seconds>(neg).count() << "s\n";  // -2
    std::cout << "ceil(-1500ms): " << ceil<seconds>(neg).count() << "s\n";    // -1
    std::cout << "round(-1500ms): " << round<seconds>(neg).count() << "s\n";  // -2
}
```

#### 深度扩展：自定义duration类型

```cpp
#include <chrono>
#include <ratio>
#include <iostream>

// 游戏开发：帧时间单位
using game_frame_60fps = std::chrono::duration<long long, std::ratio<1, 60>>;
using game_frame_30fps = std::chrono::duration<long long, std::ratio<1, 30>>;

// 音频处理：采样时间单位
using audio_sample_44100 = std::chrono::duration<long long, std::ratio<1, 44100>>;
using audio_sample_48000 = std::chrono::duration<long long, std::ratio<1, 48000>>;

// 视频处理：帧时间单位
using video_frame_24fps = std::chrono::duration<long long, std::ratio<1, 24>>;
using video_frame_30fps = std::chrono::duration<long long, std::ratio<1, 30>>;

// 物理模拟：固定时间步长
using physics_tick = std::chrono::duration<long long, std::ratio<1, 120>>;

void custom_duration_example() {
    using namespace std::chrono;

    // 游戏：3秒 = 180帧（60fps）
    auto game_time = duration_cast<game_frame_60fps>(seconds(3));
    std::cout << "3 seconds = " << game_time.count() << " frames (60fps)\n";

    // 音频：1秒 = 44100采样
    auto audio_time = duration_cast<audio_sample_44100>(seconds(1));
    std::cout << "1 second = " << audio_time.count() << " samples (44.1kHz)\n";

    // 帧到毫秒的转换
    game_frame_60fps frames(100);
    auto ms = duration_cast<milliseconds>(frames);
    std::cout << "100 frames = " << ms.count() << "ms\n";  // 约1666ms
}

// 游戏引擎时间系统示例
class GameClock {
    using Clock = std::chrono::steady_clock;
    using frame = game_frame_60fps;

    Clock::time_point start_;
    Clock::time_point last_frame_;
    double time_scale_ = 1.0;
    bool paused_ = false;

public:
    GameClock() : start_(Clock::now()), last_frame_(start_) {}

    // 获取自游戏开始以来的帧数
    frame total_frames() const {
        auto elapsed = Clock::now() - start_;
        return std::chrono::duration_cast<frame>(elapsed);
    }

    // 获取上一帧的时间（delta time）
    frame delta_time() {
        auto now = Clock::now();
        auto dt = now - last_frame_;
        last_frame_ = now;

        if (paused_) return frame(0);

        // 应用时间缩放
        auto scaled = std::chrono::duration_cast<frame>(
            std::chrono::duration<double>(dt) * time_scale_
        );

        // 限制最大delta防止spiral of death
        return std::min(scaled, frame(10));  // 最多10帧
    }

    void set_time_scale(double scale) { time_scale_ = scale; }
    void pause() { paused_ = true; }
    void resume() { paused_ = false; }
};
```

#### 练习任务

**练习1：实现ratio_pow**
```cpp
// 目标：实现 ratio^N 的编译期计算
template <class R, int N>
struct ratio_pow;

// 测试用例
static_assert(ratio_pow<std::ratio<2, 3>, 3>::num == 8, "2^3 = 8");
static_assert(ratio_pow<std::ratio<2, 3>, 3>::den == 27, "3^3 = 27");
static_assert(ratio_pow<std::ratio<2, 1>, 0>::num == 1, "x^0 = 1");
```

**练习2：实现duration_abs**
```cpp
// 目标：实现duration的绝对值函数
template <typename Rep, typename Period>
constexpr auto duration_abs(std::chrono::duration<Rep, Period> d);

// 测试用例
static_assert(duration_abs(std::chrono::seconds(-5)) == std::chrono::seconds(5));
```

**练习3：实现format_duration**
```cpp
// 目标：将duration格式化为 "Xh Ym Zs" 形式
template <typename Duration>
std::string format_hms(Duration d);

// format_hms(std::chrono::seconds(3661)) == "1h 1m 1s"
```

#### 第一周检验清单

- [ ] 能解释ratio如何在编译期进行约简
- [ ] 能说明duration隐式转换的规则
- [ ] 理解duration_cast的截断行为（特别是负数）
- [ ] 能定义自定义时间单位并与标准单位互转
- [ ] 完成mini_duration基础实现
- [ ] 笔记：`notes/week01_duration_ratio.md`

---

### 第二周：时钟（Clock）（35小时）

**学习目标**：理解不同时钟的特性和用途

#### 每日学习计划

| 天数 | 主题 | 学习内容 | 实践任务 | 时间 |
|------|------|----------|----------|------|
| Day 1 | 时钟概念 | Clock concept、静态成员、time_point类型 | 编写时钟traits检测 | 5h |
| Day 2 | system_clock | 系统时钟特性、time_t互操作、时区影响 | 测试时间调整对system_clock的影响 | 5h |
| Day 3 | steady_clock | 单调性保证、平台实现差异 | 比较steady和system的精度 | 5h |
| Day 4 | 底层API | Linux/macOS/Windows时钟API详解 | 直接调用系统API测量 | 5h |
| Day 5 | 时钟漂移 | NTP同步、时钟漂移检测 | 实现漂移检测程序 | 5h |
| Day 6 | 基准测试 | 微基准测试陷阱、正确方法 | 实现Benchmark框架 | 5h |
| Day 7 | 自定义时钟 | 实现MockClock用于测试 | 完成mini_clock | 5h |

```cpp
// 时钟类型
// 1. system_clock - 系统时钟（可能被调整）
//    - now() 返回系统当前时间
//    - 可以转换为time_t
//    - 受系统时间调整影响（NTP同步、手动调整）

// 2. steady_clock - 单调时钟
//    - 保证不会后退
//    - 适合测量时间间隔
//    - 不受系统时间调整影响

// 3. high_resolution_clock
//    - 可用的最高精度时钟
//    - 可能是system_clock或steady_clock的别名

// 4. utc_clock, tai_clock, gps_clock - C++20
//    - 特定时间系统的时钟

// 时钟的静态成员
using Clock = std::chrono::steady_clock;
auto now = Clock::now();  // 返回 time_point<Clock>
constexpr bool is_steady = Clock::is_steady;  // true for steady_clock
using duration = Clock::duration;
using rep = Clock::rep;
using period = Clock::period;
```

#### 深度扩展：三种时钟详细对比

| 特性 | system_clock | steady_clock | high_resolution_clock |
|------|-------------|--------------|----------------------|
| **单调性** | 否（可回退） | 是（保证不回退） | 取决于实现 |
| **可调整** | 是（NTP、手动） | 否 | 取决于实现 |
| **纪元** | Unix纪元（通常） | 未指定 | 未指定 |
| **精度** | 微秒级（通常） | 纳秒级（通常） | 最高可用精度 |
| **用途** | 日历时间、时间戳 | 测量间隔 | 高精度测量 |
| **to_time_t** | 支持 | 不支持 | 不保证 |

```cpp
#include <chrono>
#include <iostream>
#include <type_traits>

template <typename Clock>
void print_clock_info(const char* name) {
    std::cout << "\n=== " << name << " ===\n";
    std::cout << "is_steady: " << std::boolalpha << Clock::is_steady << "\n";

    using period = typename Clock::period;
    std::cout << "period: " << period::num << "/" << period::den << " seconds\n";
    std::cout << "resolution: "
              << (static_cast<double>(period::num) / period::den * 1e9)
              << " ns\n";
}

void compare_clocks() {
    print_clock_info<std::chrono::system_clock>("system_clock");
    print_clock_info<std::chrono::steady_clock>("steady_clock");
    print_clock_info<std::chrono::high_resolution_clock>("high_resolution_clock");

    // 检查high_resolution_clock是否是别名
    std::cout << "\nhigh_resolution_clock is steady_clock: "
              << std::is_same_v<std::chrono::high_resolution_clock,
                                std::chrono::steady_clock> << "\n";
}
```

#### 深度扩展：各平台底层API

```cpp
// ==== Linux 实现 ====
// system_clock -> clock_gettime(CLOCK_REALTIME)
// steady_clock -> clock_gettime(CLOCK_MONOTONIC)

#ifdef __linux__
#include <time.h>

void linux_clock_info() {
    struct timespec res;

    clock_getres(CLOCK_REALTIME, &res);
    printf("CLOCK_REALTIME resolution: %ld ns\n", res.tv_nsec);

    clock_getres(CLOCK_MONOTONIC, &res);
    printf("CLOCK_MONOTONIC resolution: %ld ns\n", res.tv_nsec);

    // CLOCK_MONOTONIC_RAW: 不受NTP调整影响
    clock_getres(CLOCK_MONOTONIC_RAW, &res);
    printf("CLOCK_MONOTONIC_RAW resolution: %ld ns\n", res.tv_nsec);
}
#endif

// ==== macOS 实现 ====
// steady_clock -> mach_absolute_time()

#ifdef __APPLE__
#include <mach/mach_time.h>

void macos_clock_info() {
    mach_timebase_info_data_t info;
    mach_timebase_info(&info);

    // mach_absolute_time() 返回tick数
    // 转换为纳秒：ticks * numer / denom
    printf("Mach timebase: %u/%u\n", info.numer, info.denom);
    // Intel Mac通常是 1/1（直接是纳秒）
    // ARM Mac可能不同
}
#endif

// ==== Windows 实现 ====
// steady_clock -> QueryPerformanceCounter()

#ifdef _WIN32
#include <windows.h>

void windows_clock_info() {
    LARGE_INTEGER freq;
    QueryPerformanceFrequency(&freq);

    printf("Performance counter frequency: %lld Hz\n", freq.QuadPart);
    printf("Resolution: %.3f ns\n", 1e9 / freq.QuadPart);
    // 现代Windows通常是10MHz，即100ns分辨率
}
#endif
```

#### 深度扩展：时钟漂移检测

```cpp
#include <chrono>
#include <thread>
#include <iostream>

class DriftDetector {
    using SteadyClock = std::chrono::steady_clock;
    using SystemClock = std::chrono::system_clock;

    SteadyClock::time_point steady_start_;
    SystemClock::time_point system_start_;

public:
    DriftDetector()
        : steady_start_(SteadyClock::now()),
          system_start_(SystemClock::now()) {}

    void check_drift() {
        auto steady_elapsed = SteadyClock::now() - steady_start_;
        auto system_elapsed = SystemClock::now() - system_start_;

        auto steady_ms = std::chrono::duration_cast<std::chrono::milliseconds>(
            steady_elapsed).count();
        auto system_ms = std::chrono::duration_cast<std::chrono::milliseconds>(
            system_elapsed).count();

        double drift_ppm = 0;
        if (steady_ms > 0) {
            drift_ppm = (static_cast<double>(system_ms - steady_ms) / steady_ms)
                        * 1e6;
        }

        std::cout << "Steady: " << steady_ms << "ms, "
                  << "System: " << system_ms << "ms, "
                  << "Drift: " << drift_ppm << " ppm\n";
    }
};

// 时间跳变检测
class TimeJumpDetector {
    std::chrono::system_clock::time_point last_system_;
    std::chrono::steady_clock::time_point last_steady_;
    std::chrono::milliseconds threshold_{1000};

public:
    TimeJumpDetector()
        : last_system_(std::chrono::system_clock::now()),
          last_steady_(std::chrono::steady_clock::now()) {}

    bool check_for_jump() {
        auto now_system = std::chrono::system_clock::now();
        auto now_steady = std::chrono::steady_clock::now();

        auto system_delta = now_system - last_system_;
        auto steady_delta = now_steady - last_steady_;

        auto diff = std::chrono::duration_cast<std::chrono::milliseconds>(
            system_delta - steady_delta);

        last_system_ = now_system;
        last_steady_ = now_steady;

        if (std::abs(diff.count()) > threshold_.count()) {
            std::cout << "Time jump detected: " << diff.count() << "ms\n";
            return true;
        }
        return false;
    }
};
```

#### 深度扩展：正确的基准测试方法

```cpp
#include <chrono>
#include <vector>
#include <algorithm>
#include <numeric>
#include <iostream>

// 防止编译器优化消除
template <typename T>
void DoNotOptimize(T const& value) {
    asm volatile("" : : "r,m"(value) : "memory");
}

class Benchmark {
public:
    struct Result {
        std::string name;
        double min_ns;
        double median_ns;
        double mean_ns;
        double stddev_ns;
    };

private:
    std::string name_;
    std::function<void()> func_;
    size_t warmup_ = 3;
    size_t iterations_ = 10;

public:
    Benchmark(std::string name, std::function<void()> func)
        : name_(std::move(name)), func_(std::move(func)) {}

    Result run() {
        using Clock = std::chrono::steady_clock;

        // 预热（避免缓存冷启动）
        for (size_t i = 0; i < warmup_; ++i) {
            func_();
        }

        // 测量
        std::vector<double> times;
        times.reserve(iterations_);

        for (size_t i = 0; i < iterations_; ++i) {
            auto start = Clock::now();
            func_();
            auto end = Clock::now();

            auto ns = std::chrono::duration_cast<std::chrono::nanoseconds>(
                end - start).count();
            times.push_back(static_cast<double>(ns));
        }

        // 计算统计值
        std::sort(times.begin(), times.end());

        double sum = std::accumulate(times.begin(), times.end(), 0.0);
        double mean = sum / times.size();

        double sq_sum = 0;
        for (double t : times) {
            sq_sum += (t - mean) * (t - mean);
        }
        double stddev = std::sqrt(sq_sum / times.size());

        return Result{
            name_,
            times.front(),
            times[times.size() / 2],
            mean,
            stddev
        };
    }
};

// 基准测试陷阱示例
void benchmark_pitfalls() {
    // 陷阱1：代码被优化消除
    // 错误做法
    auto bad_start = std::chrono::steady_clock::now();
    int sum = 0;
    for (int i = 0; i < 1000000; ++i) {
        sum += i;  // 可能被完全优化掉！
    }
    auto bad_end = std::chrono::steady_clock::now();
    // 可能显示0ns

    // 正确做法
    auto good_start = std::chrono::steady_clock::now();
    int sum2 = 0;
    for (int i = 0; i < 1000000; ++i) {
        sum2 += i;
    }
    DoNotOptimize(sum2);  // 防止优化
    auto good_end = std::chrono::steady_clock::now();
}
```

#### 深度扩展：MockClock用于测试

```cpp
#include <chrono>
#include <atomic>

// 可控制的时钟，用于单元测试
class MockClock {
public:
    using duration = std::chrono::nanoseconds;
    using rep = duration::rep;
    using period = duration::period;
    using time_point = std::chrono::time_point<MockClock>;
    static constexpr bool is_steady = true;

private:
    static inline std::atomic<rep> current_time_{0};

public:
    static time_point now() noexcept {
        return time_point(duration(current_time_.load()));
    }

    // 控制接口
    static void advance(duration d) {
        current_time_ += d.count();
    }

    static void set(time_point tp) {
        current_time_ = tp.time_since_epoch().count();
    }

    static void reset() {
        current_time_ = 0;
    }
};

// 使用示例
void test_with_mock_clock() {
    MockClock::reset();

    auto t1 = MockClock::now();
    MockClock::advance(std::chrono::seconds(5));
    auto t2 = MockClock::now();

    auto elapsed = t2 - t1;
    assert(elapsed == std::chrono::seconds(5));
}
```

**测量时间**：
```cpp
#include <chrono>
#include <iostream>

template <typename Func>
auto measure(Func&& f) {
    auto start = std::chrono::steady_clock::now();
    std::forward<Func>(f)();
    auto end = std::chrono::steady_clock::now();
    return end - start;
}

// 使用
auto duration = measure([]() {
    // 要测量的代码
});
auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(duration);
std::cout << "Took " << ms.count() << " ms\n";
```

#### 练习任务

**练习1：实现跨平台高精度计时器**
```cpp
class HighPrecisionTimer {
public:
    void start();
    void stop();
    long long elapsed_ns() const;
    static long long resolution_ns();
    static const char* clock_name();
};
// 要求：Linux用CLOCK_MONOTONIC_RAW，macOS用mach_absolute_time，Windows用QPC
```

**练习2：实现时钟精度检测工具**
```cpp
template <typename Clock>
struct ClockPrecision {
    static long long theoretical_resolution_ns();  // 理论精度
    static long long measured_resolution_ns();     // 实测精度
    static void print_info();
};
```

#### 第二周检验清单

- [ ] 能解释三种标准时钟的区别和适用场景
- [ ] 理解各平台的底层时钟API
- [ ] 能识别和处理时钟漂移问题
- [ ] 能编写正确的微基准测试（避免优化消除）
- [ ] 完成mini_clock跨平台实现
- [ ] 完成MockClock测试时钟
- [ ] 笔记：`notes/week02_clock_systems.md`

---

### 第三周：time_point（时间点）（35小时）

**学习目标**：理解时间点的表示和运算

#### 每日学习计划

| 天数 | 主题 | 学习内容 | 实践任务 | 时间 |
|------|------|----------|----------|------|
| Day 1 | time_point基础 | 模板参数、时钟关联、纪元概念 | 分析time_point内存布局 | 5h |
| Day 2 | 类型安全 | 不同时钟time_point不能混用的原理 | 编写编译错误测试 | 5h |
| Day 3 | 时间运算 | 与duration运算、time_point间差值 | 实现TimeInterval类 | 5h |
| Day 4 | C++20日历(1) | year_month_day、weekday | 实现日期计算器 | 5h |
| Day 5 | C++20日历(2) | sys_days、日历算术 | 实现节假日计算 | 5h |
| Day 6 | C++20时区 | zoned_time、时区转换、夏令时 | 实现跨时区调度器 | 5h |
| Day 7 | POSIX互操作 | time_t、tm、strftime | 完善时间格式化库 | 5h |

```cpp
// time_point<Clock, Duration>
// 表示特定时钟的某个时间点

using namespace std::chrono;

// 获取当前时间点
auto now = system_clock::now();

// 时间点运算
auto later = now + hours(1);  // 1小时后
auto duration = later - now;  // 得到duration

// 转换为time_t（与C接口交互）
std::time_t t = system_clock::to_time_t(now);
std::cout << std::ctime(&t);

// 从time_t转换
auto tp = system_clock::from_time_t(t);

// C++20: calendar和time zones
// year_month_day, zoned_time等
auto ymd = year_month_day{year{2025}, month{1}, day{15}};
auto sys_days = sys_days(ymd);  // 转换为system_clock的time_point
```

#### 深度扩展：time_point的类型安全设计

```cpp
#include <chrono>

void type_safety_demo() {
    auto sys_now = std::chrono::system_clock::now();
    auto steady_now = std::chrono::steady_clock::now();

    // 编译错误：不同时钟的time_point不能比较
    // if (sys_now < steady_now) { }  // ERROR

    // 编译错误：不同时钟的time_point不能相减
    // auto diff = sys_now - steady_now;  // ERROR

    // 为什么这是正确的设计？
    // 1. 两个时钟的纪元不同，差值没有意义
    // 2. 防止逻辑错误（如用系统时间计算超时）
    // 3. 编译器帮助捕获错误
}

// 安全的时钟转换模式
class ClockSnapshot {
    std::chrono::system_clock::time_point system_;
    std::chrono::steady_clock::time_point steady_;

public:
    static ClockSnapshot now() {
        ClockSnapshot snap;
        // 尽可能同时捕获两个时钟
        auto s1 = std::chrono::system_clock::now();
        auto t1 = std::chrono::steady_clock::now();
        auto s2 = std::chrono::system_clock::now();
        auto t2 = std::chrono::steady_clock::now();

        // 使用中间值
        snap.system_ = s1 + (s2 - s1) / 2;
        snap.steady_ = t1 + (t2 - t1) / 2;
        return snap;
    }

    // 从steady_clock推断system_clock时间
    std::chrono::system_clock::time_point
    steady_to_system(std::chrono::steady_clock::time_point tp) const {
        return system_ + (tp - steady_);
    }

    // 从system_clock推断steady_clock时间
    std::chrono::steady_clock::time_point
    system_to_steady(std::chrono::system_clock::time_point tp) const {
        return steady_ + (tp - system_);
    }
};
```

#### 深度扩展：C++20日历功能

```cpp
#include <chrono>
#include <iostream>

#if __cplusplus >= 202002L
using namespace std::chrono;

void calendar_basics() {
    // year_month_day: 表示日历日期
    year_month_day ymd{year{2025}, month{3}, day{15}};

    // 使用字面量（更简洁）
    auto ymd2 = 2025y/March/15d;
    auto ymd3 = March/15d/2025y;  // 美式写法

    // 访问组件
    std::cout << "Year: " << int(ymd.year()) << "\n";
    std::cout << "Month: " << unsigned(ymd.month()) << "\n";
    std::cout << "Day: " << unsigned(ymd.day()) << "\n";

    // 有效性检查
    auto invalid = 2025y/February/30d;  // 2月30日
    std::cout << "2025/2/30 ok: " << invalid.ok() << "\n";  // false

    // 转换为time_point
    sys_days sd = ymd;
    auto tp = sys_days(ymd) + 12h + 30min;
}

void calendar_arithmetic() {
    auto date = 2025y/March/15d;

    // 加减月份
    auto next_month = date + months{1};  // 2025-04-15
    auto prev_year = date - years{1};    // 2024-03-15

    // 注意：月份算术可能产生无效日期
    auto jan31 = 2025y/January/31d;
    auto feb_result = jan31 + months{1};  // 2025-02-31（无效！）

    if (!feb_result.ok()) {
        // 使用该月的最后一天
        auto valid = feb_result.year()/feb_result.month()/last;
    }
}

void weekday_demo() {
    // 从日期获取星期几
    auto date = 2025y/March/15d;
    weekday day_of_week{sys_days(date)};

    // year_month_weekday: "某月的第N个星期几"
    // 感恩节：11月的第4个星期四
    auto thanksgiving = 2025y/November/Thursday[4];
    auto thanksgiving_date = year_month_day{sys_days(thanksgiving)};

    // 某月的最后一个星期几
    auto last_friday = 2025y/March/Friday[last];
}

// 计算年龄
int calculate_age(year_month_day birth, year_month_day today) {
    auto age = int(today.year()) - int(birth.year());

    // 检查今年是否已过生日
    if (today.month() < birth.month() ||
        (today.month() == birth.month() && today.day() < birth.day())) {
        age -= 1;
    }
    return age;
}
#endif
```

#### 深度扩展：C++20时区支持

```cpp
#if __cplusplus >= 202002L
#include <chrono>
#include <iostream>

using namespace std::chrono;

void timezone_basics() {
    // 获取时区
    const time_zone* tz_tokyo = locate_zone("Asia/Tokyo");
    const time_zone* tz_ny = locate_zone("America/New_York");
    const time_zone* tz_local = current_zone();

    // zoned_time: 带时区的时间点
    auto now = system_clock::now();
    zoned_time zt_local{current_zone(), now};
    zoned_time zt_tokyo{"Asia/Tokyo", now};

    std::cout << "Local: " << zt_local << "\n";
    std::cout << "Tokyo: " << zt_tokyo << "\n";
}

void timezone_conversion() {
    // 在纽约时间创建一个时间点
    auto zt_ny = zoned_time{"America/New_York",
                            local_days{2025y/July/4d} + 12h};

    // 转换到东京时区
    auto zt_tokyo = zoned_time{"Asia/Tokyo", zt_ny};

    std::cout << "New York: " << zt_ny << "\n";
    std::cout << "Tokyo: " << zt_tokyo << "\n";
}

void daylight_saving_time() {
    const time_zone* tz_ny = locate_zone("America/New_York");

    // 夏令时开始时刻（2025年3月9日2:00 AM）
    // 这个时间不存在！
    try {
        auto nonexistent = zoned_time{tz_ny,
                                      local_days{2025y/March/9d} + 2h + 30min};
    } catch (const nonexistent_local_time& e) {
        std::cout << "Nonexistent time: " << e.what() << "\n";
    }

    // 夏令时结束时刻有歧义
    try {
        auto ambiguous = zoned_time{tz_ny,
                                    local_days{2025y/November/2d} + 1h + 30min};
    } catch (const ambiguous_local_time& e) {
        std::cout << "Ambiguous time: " << e.what() << "\n";
    }

    // 使用choose参数解决歧义
    auto earlier = zoned_time{tz_ny,
                              local_days{2025y/November/2d} + 1h + 30min,
                              choose::earliest};
}
#endif
```

#### 深度扩展：与POSIX时间函数互操作

```cpp
#include <chrono>
#include <ctime>
#include <iomanip>
#include <sstream>

class TimeConverter {
public:
    // time_t <-> system_clock::time_point
    static std::chrono::system_clock::time_point from_time_t(std::time_t t) {
        return std::chrono::system_clock::from_time_t(t);
    }

    static std::time_t to_time_t(std::chrono::system_clock::time_point tp) {
        return std::chrono::system_clock::to_time_t(tp);
    }

    // tm <-> time_point（本地时间）
    static std::chrono::system_clock::time_point from_local_tm(const std::tm& tm) {
        std::tm tm_copy = tm;
        std::time_t t = std::mktime(&tm_copy);
        return from_time_t(t);
    }

    static std::tm to_local_tm(std::chrono::system_clock::time_point tp) {
        std::time_t t = to_time_t(tp);
        std::tm tm;
        localtime_r(&t, &tm);  // 线程安全版本
        return tm;
    }

    // 字符串解析
    static std::chrono::system_clock::time_point
    parse(const std::string& str, const char* format = "%Y-%m-%d %H:%M:%S") {
        std::tm tm = {};
        std::istringstream iss(str);
        iss >> std::get_time(&tm, format);
        return from_local_tm(tm);
    }

    // 字符串格式化
    static std::string
    format(std::chrono::system_clock::time_point tp,
           const char* fmt = "%Y-%m-%d %H:%M:%S") {
        std::tm tm = to_local_tm(tp);
        std::ostringstream oss;
        oss << std::put_time(&tm, fmt);
        return oss.str();
    }
};

// 处理亚秒精度
class SubsecondTime {
public:
    static std::string format_with_ms(std::chrono::system_clock::time_point tp) {
        using namespace std::chrono;

        auto secs = floor<seconds>(tp);
        auto ms = duration_cast<milliseconds>(tp - secs);

        std::time_t t = system_clock::to_time_t(
            time_point_cast<system_clock::duration>(secs));
        std::tm tm;
        localtime_r(&t, &tm);

        std::ostringstream oss;
        oss << std::put_time(&tm, "%Y-%m-%d %H:%M:%S")
            << '.' << std::setfill('0') << std::setw(3) << ms.count();
        return oss.str();
    }
};
```

#### 练习任务

**练习1：实现ISO 8601时间解析器**
```cpp
class ISO8601Parser {
public:
    // 支持格式：2025-03-15, 2025-03-15T14:30:00, 2025-03-15T14:30:00Z
    static std::chrono::system_clock::time_point parse(const std::string& str);
    static std::string format(std::chrono::system_clock::time_point tp);
};
```

**练习2：实现工作日计算器**
```cpp
class WorkdayCalculator {
public:
    void add_holiday(std::chrono::year_month_day date);
    int count_workdays(std::chrono::year_month_day start,
                      std::chrono::year_month_day end) const;
    std::chrono::year_month_day add_workdays(
        std::chrono::year_month_day start, int days) const;
};
```

#### 第三周检验清单

- [ ] 理解time_point的类型安全设计原理
- [ ] 能使用C++20日历功能进行日期计算
- [ ] 理解时区和夏令时的复杂性
- [ ] 能在chrono和POSIX时间函数之间正确转换
- [ ] 完成mini_time_point实现
- [ ] 完成时间格式化工具
- [ ] 笔记：`notes/week03_time_point_calendar.md`

---

### 第四周：实际应用（35小时）

**学习目标**：在实际场景中应用chrono

#### 每日学习计划

| 天数 | 主题 | 学习内容 | 实践任务 | 时间 |
|------|------|----------|----------|------|
| Day 1 | 并发超时 | condition_variable/future超时模式 | 实现超时操作包装器 | 5h |
| Day 2 | 定时器模式 | 单次/周期定时、定时器调度 | 实现TimerScheduler | 5h |
| Day 3 | 性能分析(1) | 层次化Profiler、Span概念 | 实现HierarchicalProfiler | 5h |
| Day 4 | 性能分析(2) | 统计分析、报告生成 | 完善性能分析工具 | 5h |
| Day 5 | 工程案例(1) | 令牌桶限流、过期缓存 | 实现TokenBucket | 5h |
| Day 6 | 工程案例(2) | 分布式锁租约、心跳检测 | 实现ExpiringCache | 5h |
| Day 7 | 综合项目 | 整合所有工具为完整库 | 完成时间处理工具库 | 5h |

#### 超时处理
```cpp
#include <chrono>
#include <thread>
#include <mutex>
#include <condition_variable>

// 条件变量超时等待
std::mutex mtx;
std::condition_variable cv;
bool ready = false;

void wait_with_timeout() {
    std::unique_lock<std::mutex> lock(mtx);

    // 使用duration
    if (cv.wait_for(lock, std::chrono::seconds(5),
                    []{ return ready; })) {
        std::cout << "Condition met\n";
    } else {
        std::cout << "Timeout!\n";
    }

    // 使用time_point（绝对时间）
    auto deadline = std::chrono::steady_clock::now() +
                    std::chrono::seconds(5);
    if (cv.wait_until(lock, deadline,
                      []{ return ready; })) {
        std::cout << "Condition met\n";
    } else {
        std::cout << "Timeout!\n";
    }
}
```

#### 深度扩展：超时模式

```cpp
#include <chrono>
#include <future>
#include <optional>

// 操作超时包装器
template <typename T>
class TimeoutOperation {
public:
    template <typename Func, typename Duration>
    static std::optional<T> execute(Func&& func, Duration timeout) {
        std::promise<T> promise;
        auto future = promise.get_future();

        std::thread worker([&promise, f = std::forward<Func>(func)]() {
            try {
                promise.set_value(f());
            } catch (...) {
                promise.set_exception(std::current_exception());
            }
        });

        if (future.wait_for(timeout) == std::future_status::ready) {
            worker.join();
            return future.get();
        } else {
            worker.detach();  // 超时，需要其他取消机制
            return std::nullopt;
        }
    }
};

// 超时重试模式（指数退避）
template <typename Func, typename Result = std::invoke_result_t<Func>>
std::optional<Result> retry_with_timeout(
    Func&& func,
    int max_retries,
    std::chrono::milliseconds initial_delay,
    std::chrono::milliseconds max_delay,
    std::chrono::steady_clock::duration total_timeout) {

    auto deadline = std::chrono::steady_clock::now() + total_timeout;
    auto delay = initial_delay;

    for (int attempt = 0; attempt < max_retries; ++attempt) {
        if (std::chrono::steady_clock::now() >= deadline) break;

        try {
            return func();
        } catch (...) {
            auto sleep_time = std::min(delay,
                std::chrono::duration_cast<std::chrono::milliseconds>(
                    deadline - std::chrono::steady_clock::now()));

            if (sleep_time > std::chrono::milliseconds::zero()) {
                std::this_thread::sleep_for(sleep_time);
            }
            delay = std::min(delay * 2, max_delay);  // 指数退避
        }
    }
    return std::nullopt;
}
```

#### 定时器实现
```cpp
#include <chrono>
#include <functional>
#include <thread>
#include <atomic>

class Timer {
    std::atomic<bool> running_{false};
    std::thread thread_;

public:
    template <typename Func, typename Rep, typename Period>
    void start(std::chrono::duration<Rep, Period> interval, Func&& f) {
        running_ = true;
        thread_ = std::thread([this, interval, f = std::forward<Func>(f)]() {
            auto next = std::chrono::steady_clock::now() + interval;
            while (running_) {
                std::this_thread::sleep_until(next);
                if (running_) {
                    f();
                    next += interval;
                }
            }
        });
    }

    void stop() {
        running_ = false;
        if (thread_.joinable()) {
            thread_.join();
        }
    }

    ~Timer() { stop(); }
};
```

#### 深度扩展：高效定时器调度器

```cpp
#include <chrono>
#include <queue>
#include <mutex>
#include <condition_variable>
#include <functional>
#include <atomic>
#include <thread>

class TimerScheduler {
public:
    using Clock = std::chrono::steady_clock;
    using Callback = std::function<void()>;

    struct TimerTask {
        size_t id;
        Clock::time_point deadline;
        Clock::duration interval;  // 0表示单次
        Callback callback;

        bool operator>(const TimerTask& other) const {
            return deadline > other.deadline;
        }
    };

private:
    std::priority_queue<TimerTask, std::vector<TimerTask>,
                        std::greater<TimerTask>> tasks_;
    std::mutex mutex_;
    std::condition_variable cv_;
    std::atomic<bool> running_{false};
    std::thread worker_;
    size_t next_id_ = 0;

public:
    TimerScheduler() {
        running_ = true;
        worker_ = std::thread(&TimerScheduler::worker_loop, this);
    }

    ~TimerScheduler() {
        running_ = false;
        cv_.notify_all();
        if (worker_.joinable()) worker_.join();
    }

    size_t schedule_once(Clock::duration delay, Callback cb) {
        return schedule_at(Clock::now() + delay, Clock::duration::zero(),
                          std::move(cb));
    }

    size_t schedule_periodic(Clock::duration interval, Callback cb) {
        return schedule_at(Clock::now() + interval, interval, std::move(cb));
    }

private:
    size_t schedule_at(Clock::time_point time, Clock::duration interval,
                       Callback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        size_t id = next_id_++;
        tasks_.push(TimerTask{id, time, interval, std::move(cb)});
        cv_.notify_one();
        return id;
    }

    void worker_loop() {
        while (running_) {
            std::unique_lock<std::mutex> lock(mutex_);

            if (tasks_.empty()) {
                cv_.wait(lock, [this] { return !running_ || !tasks_.empty(); });
                continue;
            }

            auto& next = tasks_.top();
            if (next.deadline <= Clock::now()) {
                TimerTask task = std::move(const_cast<TimerTask&>(next));
                tasks_.pop();
                lock.unlock();

                task.callback();

                if (task.interval > Clock::duration::zero()) {
                    lock.lock();
                    task.deadline = Clock::now() + task.interval;
                    tasks_.push(std::move(task));
                }
            } else {
                cv_.wait_until(lock, next.deadline);
            }
        }
    }
};
```

#### 性能测量工具
```cpp
#include <chrono>
#include <string>
#include <iostream>
#include <map>

class Profiler {
    using Clock = std::chrono::high_resolution_clock;

    struct Measurement {
        Clock::duration total{0};
        size_t count = 0;
    };

    std::map<std::string, Measurement> measurements_;

public:
    class ScopedTimer {
        Profiler& profiler_;
        std::string name_;
        Clock::time_point start_;

    public:
        ScopedTimer(Profiler& p, std::string name)
            : profiler_(p), name_(std::move(name)), start_(Clock::now()) {}

        ~ScopedTimer() {
            auto duration = Clock::now() - start_;
            profiler_.measurements_[name_].total += duration;
            profiler_.measurements_[name_].count++;
        }
    };

    ScopedTimer measure(std::string name) {
        return ScopedTimer(*this, std::move(name));
    }

    void report() const {
        for (const auto& [name, m] : measurements_) {
            auto avg = m.total / m.count;
            auto avg_us = std::chrono::duration_cast<
                std::chrono::microseconds>(avg);
            std::cout << name << ": "
                      << "count=" << m.count
                      << ", avg=" << avg_us.count() << "us\n";
        }
    }
};

// 使用
Profiler profiler;
{
    auto timer = profiler.measure("sort");
    // 排序代码
}
profiler.report();
```

#### 深度扩展：层次化性能分析器

```cpp
#include <chrono>
#include <string>
#include <vector>
#include <stack>
#include <map>
#include <thread>
#include <mutex>

class HierarchicalProfiler {
public:
    using Clock = std::chrono::steady_clock;

    struct Span {
        std::string name;
        Clock::time_point start;
        Clock::time_point end;
        size_t parent_index;  // SIZE_MAX = no parent
        std::vector<size_t> children;
    };

private:
    std::vector<Span> spans_;
    std::map<std::thread::id, std::stack<size_t>> active_spans_;
    std::mutex mutex_;

public:
    class ScopedSpan {
        HierarchicalProfiler& profiler_;
        size_t index_;
    public:
        ScopedSpan(HierarchicalProfiler& p, const std::string& name)
            : profiler_(p), index_(p.begin_span(name)) {}
        ~ScopedSpan() { profiler_.end_span(index_); }
    };

    ScopedSpan span(const std::string& name) {
        return ScopedSpan(*this, name);
    }

    size_t begin_span(const std::string& name) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto tid = std::this_thread::get_id();
        size_t parent = SIZE_MAX;

        if (active_spans_.count(tid) && !active_spans_[tid].empty()) {
            parent = active_spans_[tid].top();
        }

        size_t index = spans_.size();
        spans_.push_back({name, Clock::now(), {}, parent, {}});

        if (parent != SIZE_MAX) {
            spans_[parent].children.push_back(index);
        }
        active_spans_[tid].push(index);
        return index;
    }

    void end_span(size_t index) {
        std::lock_guard<std::mutex> lock(mutex_);
        spans_[index].end = Clock::now();
        active_spans_[std::this_thread::get_id()].pop();
    }

    void print_report() const {
        std::cout << "\n=== Performance Report ===\n";
        for (size_t i = 0; i < spans_.size(); ++i) {
            if (spans_[i].parent_index == SIZE_MAX) {
                print_span(i, 0);
            }
        }
    }

private:
    void print_span(size_t index, int depth) const {
        const auto& span = spans_[index];
        auto duration = span.end - span.start;
        auto ms = std::chrono::duration_cast<std::chrono::microseconds>(duration);

        std::cout << std::string(depth * 2, ' ')
                  << span.name << ": " << ms.count() / 1000.0 << " ms\n";

        for (size_t child : span.children) {
            print_span(child, depth + 1);
        }
    }
};

// 使用示例
void profiler_example() {
    HierarchicalProfiler profiler;

    {
        auto s1 = profiler.span("process_request");
        {
            auto s2 = profiler.span("parse_input");
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
        }
        {
            auto s3 = profiler.span("execute_query");
            std::this_thread::sleep_for(std::chrono::milliseconds(50));
        }
    }

    profiler.print_report();
    /* 输出:
    process_request: 60.xxx ms
      parse_input: 10.xxx ms
      execute_query: 50.xxx ms
    */
}
```

#### 深度扩展：令牌桶限流器

```cpp
#include <chrono>
#include <mutex>
#include <algorithm>

class TokenBucket {
    using Clock = std::chrono::steady_clock;

    double tokens_;
    double max_tokens_;
    double refill_rate_;  // 每秒补充的令牌数
    Clock::time_point last_refill_;
    std::mutex mutex_;

public:
    TokenBucket(double max_tokens, double tokens_per_second)
        : tokens_(max_tokens),
          max_tokens_(max_tokens),
          refill_rate_(tokens_per_second),
          last_refill_(Clock::now()) {}

    bool try_acquire(double tokens = 1.0) {
        std::lock_guard<std::mutex> lock(mutex_);
        refill();

        if (tokens_ >= tokens) {
            tokens_ -= tokens;
            return true;
        }
        return false;
    }

    template <typename Duration>
    bool acquire(double tokens, Duration timeout) {
        auto deadline = Clock::now() + timeout;

        while (Clock::now() < deadline) {
            if (try_acquire(tokens)) return true;

            std::lock_guard<std::mutex> lock(mutex_);
            refill();

            double needed = tokens - tokens_;
            if (needed <= 0) continue;

            auto wait_time = std::chrono::duration_cast<Clock::duration>(
                std::chrono::duration<double>(needed / refill_rate_));
            wait_time = std::min(wait_time,
                std::chrono::duration_cast<Clock::duration>(deadline - Clock::now()));

            if (wait_time > Clock::duration::zero()) {
                std::this_thread::sleep_for(wait_time);
            }
        }
        return try_acquire(tokens);
    }

private:
    void refill() {
        auto now = Clock::now();
        auto elapsed = std::chrono::duration<double>(now - last_refill_).count();
        tokens_ = std::min(max_tokens_, tokens_ + elapsed * refill_rate_);
        last_refill_ = now;
    }
};
```

#### 深度扩展：带过期的缓存

```cpp
#include <chrono>
#include <unordered_map>
#include <optional>
#include <shared_mutex>
#include <list>

template <typename Key, typename Value>
class ExpiringCache {
    using Clock = std::chrono::steady_clock;
    using Duration = Clock::duration;

    struct Entry {
        Value value;
        Clock::time_point expiry;
        typename std::list<Key>::iterator lru_it;
    };

    std::unordered_map<Key, Entry> cache_;
    std::list<Key> lru_list_;
    Duration default_ttl_;
    size_t max_size_;
    mutable std::shared_mutex mutex_;

public:
    ExpiringCache(Duration ttl, size_t max_size)
        : default_ttl_(ttl), max_size_(max_size) {}

    void put(const Key& key, Value value,
             std::optional<Duration> ttl = std::nullopt) {
        std::unique_lock lock(mutex_);

        auto it = cache_.find(key);
        if (it != cache_.end()) {
            lru_list_.erase(it->second.lru_it);
        } else if (cache_.size() >= max_size_) {
            evict_oldest();
        }

        lru_list_.push_front(key);
        cache_[key] = Entry{
            std::move(value),
            Clock::now() + ttl.value_or(default_ttl_),
            lru_list_.begin()
        };
    }

    std::optional<Value> get(const Key& key) {
        std::shared_lock lock(mutex_);

        auto it = cache_.find(key);
        if (it == cache_.end()) return std::nullopt;

        if (Clock::now() >= it->second.expiry) {
            lock.unlock();
            std::unique_lock wlock(mutex_);
            auto wit = cache_.find(key);
            if (wit != cache_.end() && Clock::now() >= wit->second.expiry) {
                lru_list_.erase(wit->second.lru_it);
                cache_.erase(wit);
            }
            return std::nullopt;
        }
        return it->second.value;
    }

    size_t cleanup() {
        std::unique_lock lock(mutex_);
        auto now = Clock::now();
        size_t removed = 0;

        for (auto it = cache_.begin(); it != cache_.end(); ) {
            if (now >= it->second.expiry) {
                lru_list_.erase(it->second.lru_it);
                it = cache_.erase(it);
                ++removed;
            } else {
                ++it;
            }
        }
        return removed;
    }

private:
    void evict_oldest() {
        if (lru_list_.empty()) return;
        cache_.erase(lru_list_.back());
        lru_list_.pop_back();
    }
};
```

#### 练习任务

**练习1：实现滑动窗口限流器**
```cpp
class SlidingWindowRateLimiter {
public:
    SlidingWindowRateLimiter(size_t max_requests, std::chrono::seconds window);
    bool try_acquire();
    size_t available() const;
};
```

**练习2：实现心跳检测器**
```cpp
class HeartbeatMonitor {
public:
    using Callback = std::function<void(const std::string& node_id)>;
    HeartbeatMonitor(std::chrono::milliseconds timeout, Callback on_timeout);

    void register_node(const std::string& node_id);
    void heartbeat(const std::string& node_id);
    enum class NodeState { ALIVE, SUSPECT, DEAD };
    NodeState get_state(const std::string& node_id) const;
};
```

#### 第四周检验清单

- [ ] 能实现各种超时模式（wait_for、wait_until、指数退避）
- [ ] 能实现高效的定时器调度器
- [ ] 能使用层次化性能分析器
- [ ] 理解令牌桶限流算法
- [ ] 完成带过期的缓存实现
- [ ] 完成时间处理工具库整合
- [ ] 笔记：`notes/week04_chrono_applications.md`

---

## 源码阅读任务

### 深度阅读清单

- [ ] `std::chrono::duration`实现
- [ ] `std::ratio`编译期算术
- [ ] `std::chrono::steady_clock`平台实现（Linux/macOS/Windows）
- [ ] `std::this_thread::sleep_for/sleep_until`实现

---

## 实践项目

### 项目：实现时间处理库

#### Part 1: mini_duration
```cpp
// mini_chrono.hpp
#pragma once
#include <ratio>
#include <type_traits>
#include <limits>

namespace mini::chrono {

// duration
template <typename Rep, typename Period = std::ratio<1>>
class duration {
public:
    using rep = Rep;
    using period = Period;

private:
    rep count_;

public:
    constexpr duration() = default;

    template <typename Rep2,
              typename = std::enable_if_t<
                  std::is_convertible_v<Rep2, Rep> &&
                  (std::is_floating_point_v<Rep> ||
                   !std::is_floating_point_v<Rep2>)>>
    constexpr explicit duration(const Rep2& r) : count_(static_cast<Rep>(r)) {}

    // 从另一个duration转换
    template <typename Rep2, typename Period2,
              typename = std::enable_if_t<
                  std::is_floating_point_v<Rep> ||
                  (std::ratio_divide<Period2, Period>::den == 1 &&
                   !std::is_floating_point_v<Rep2>)>>
    constexpr duration(const duration<Rep2, Period2>& d)
        : count_(static_cast<Rep>(d.count() *
                 std::ratio_divide<Period2, Period>::num /
                 std::ratio_divide<Period2, Period>::den)) {}

    constexpr rep count() const { return count_; }

    // 算术运算
    constexpr duration operator+() const { return *this; }
    constexpr duration operator-() const { return duration(-count_); }

    constexpr duration& operator++() { ++count_; return *this; }
    constexpr duration operator++(int) { return duration(count_++); }
    constexpr duration& operator--() { --count_; return *this; }
    constexpr duration operator--(int) { return duration(count_--); }

    constexpr duration& operator+=(const duration& d) {
        count_ += d.count();
        return *this;
    }

    constexpr duration& operator-=(const duration& d) {
        count_ -= d.count();
        return *this;
    }

    constexpr duration& operator*=(const rep& r) {
        count_ *= r;
        return *this;
    }

    constexpr duration& operator/=(const rep& r) {
        count_ /= r;
        return *this;
    }

    // 特殊值
    static constexpr duration zero() { return duration(0); }
    static constexpr duration min() { return duration(std::numeric_limits<Rep>::lowest()); }
    static constexpr duration max() { return duration(std::numeric_limits<Rep>::max()); }
};

// duration算术运算（非成员）
template <typename Rep1, typename Period1, typename Rep2, typename Period2>
constexpr auto operator+(const duration<Rep1, Period1>& lhs,
                         const duration<Rep2, Period2>& rhs) {
    using common_type = std::common_type_t<duration<Rep1, Period1>,
                                            duration<Rep2, Period2>>;
    return common_type(common_type(lhs).count() + common_type(rhs).count());
}

template <typename Rep1, typename Period1, typename Rep2, typename Period2>
constexpr auto operator-(const duration<Rep1, Period1>& lhs,
                         const duration<Rep2, Period2>& rhs) {
    using common_type = std::common_type_t<duration<Rep1, Period1>,
                                            duration<Rep2, Period2>>;
    return common_type(common_type(lhs).count() - common_type(rhs).count());
}

template <typename Rep1, typename Period, typename Rep2>
constexpr auto operator*(const duration<Rep1, Period>& d, const Rep2& s) {
    using common_rep = std::common_type_t<Rep1, Rep2>;
    return duration<common_rep, Period>(
        static_cast<common_rep>(d.count()) * static_cast<common_rep>(s));
}

template <typename Rep1, typename Period, typename Rep2>
constexpr auto operator/(const duration<Rep1, Period>& d, const Rep2& s) {
    using common_rep = std::common_type_t<Rep1, Rep2>;
    return duration<common_rep, Period>(
        static_cast<common_rep>(d.count()) / static_cast<common_rep>(s));
}

// 比较运算
template <typename Rep1, typename Period1, typename Rep2, typename Period2>
constexpr bool operator==(const duration<Rep1, Period1>& lhs,
                          const duration<Rep2, Period2>& rhs) {
    using common_type = std::common_type_t<duration<Rep1, Period1>,
                                            duration<Rep2, Period2>>;
    return common_type(lhs).count() == common_type(rhs).count();
}

template <typename Rep1, typename Period1, typename Rep2, typename Period2>
constexpr bool operator<(const duration<Rep1, Period1>& lhs,
                         const duration<Rep2, Period2>& rhs) {
    using common_type = std::common_type_t<duration<Rep1, Period1>,
                                            duration<Rep2, Period2>>;
    return common_type(lhs).count() < common_type(rhs).count();
}

// duration_cast
template <typename ToDuration, typename Rep, typename Period>
constexpr ToDuration duration_cast(const duration<Rep, Period>& d) {
    using ratio = std::ratio_divide<Period, typename ToDuration::period>;
    using common_rep = std::common_type_t<typename ToDuration::rep, Rep>;
    return ToDuration(static_cast<typename ToDuration::rep>(
        static_cast<common_rep>(d.count()) *
        static_cast<common_rep>(ratio::num) /
        static_cast<common_rep>(ratio::den)));
}

// 预定义类型
using nanoseconds  = duration<long long, std::nano>;
using microseconds = duration<long long, std::micro>;
using milliseconds = duration<long long, std::milli>;
using seconds      = duration<long long>;
using minutes      = duration<int, std::ratio<60>>;
using hours        = duration<int, std::ratio<3600>>;

} // namespace mini::chrono
```

#### Part 2: mini_time_point
```cpp
// mini_time_point.hpp (续)
namespace mini::chrono {

template <typename Clock, typename Duration = typename Clock::duration>
class time_point {
public:
    using clock = Clock;
    using duration = Duration;
    using rep = typename Duration::rep;
    using period = typename Duration::period;

private:
    Duration d_;

public:
    constexpr time_point() : d_(Duration::zero()) {}

    constexpr explicit time_point(const Duration& d) : d_(d) {}

    template <typename Duration2,
              typename = std::enable_if_t<
                  std::is_convertible_v<Duration2, Duration>>>
    constexpr time_point(const time_point<Clock, Duration2>& t)
        : d_(t.time_since_epoch()) {}

    constexpr Duration time_since_epoch() const { return d_; }

    constexpr time_point& operator+=(const Duration& d) {
        d_ += d;
        return *this;
    }

    constexpr time_point& operator-=(const Duration& d) {
        d_ -= d;
        return *this;
    }

    static constexpr time_point min() {
        return time_point(Duration::min());
    }

    static constexpr time_point max() {
        return time_point(Duration::max());
    }
};

// time_point算术
template <typename Clock, typename Duration1, typename Rep, typename Period>
constexpr auto operator+(const time_point<Clock, Duration1>& tp,
                         const duration<Rep, Period>& d) {
    using common_dur = std::common_type_t<Duration1, duration<Rep, Period>>;
    return time_point<Clock, common_dur>(tp.time_since_epoch() + d);
}

template <typename Clock, typename Duration1, typename Duration2>
constexpr auto operator-(const time_point<Clock, Duration1>& lhs,
                         const time_point<Clock, Duration2>& rhs) {
    return lhs.time_since_epoch() - rhs.time_since_epoch();
}

// 比较
template <typename Clock, typename Duration1, typename Duration2>
constexpr bool operator==(const time_point<Clock, Duration1>& lhs,
                          const time_point<Clock, Duration2>& rhs) {
    return lhs.time_since_epoch() == rhs.time_since_epoch();
}

template <typename Clock, typename Duration1, typename Duration2>
constexpr bool operator<(const time_point<Clock, Duration1>& lhs,
                         const time_point<Clock, Duration2>& rhs) {
    return lhs.time_since_epoch() < rhs.time_since_epoch();
}

} // namespace mini::chrono
```

#### Part 3: 简单时钟实现
```cpp
// mini_clock.hpp
#pragma once
#include "mini_chrono.hpp"
#include <ctime>

#ifdef _WIN32
#include <windows.h>
#else
#include <sys/time.h>
#endif

namespace mini::chrono {

struct steady_clock {
    using duration = nanoseconds;
    using rep = duration::rep;
    using period = duration::period;
    using time_point = mini::chrono::time_point<steady_clock>;
    static constexpr bool is_steady = true;

    static time_point now() noexcept {
#ifdef _WIN32
        LARGE_INTEGER freq, count;
        QueryPerformanceFrequency(&freq);
        QueryPerformanceCounter(&count);
        return time_point(nanoseconds(
            count.QuadPart * 1000000000LL / freq.QuadPart));
#elif defined(__APPLE__)
        // macOS: mach_absolute_time
        // 简化：使用gettimeofday
        struct timeval tv;
        gettimeofday(&tv, nullptr);
        return time_point(nanoseconds(
            tv.tv_sec * 1000000000LL + tv.tv_usec * 1000LL));
#else
        // Linux: clock_gettime
        struct timespec ts;
        clock_gettime(CLOCK_MONOTONIC, &ts);
        return time_point(nanoseconds(
            ts.tv_sec * 1000000000LL + ts.tv_nsec));
#endif
    }
};

struct system_clock {
    using duration = nanoseconds;
    using rep = duration::rep;
    using period = duration::period;
    using time_point = mini::chrono::time_point<system_clock>;
    static constexpr bool is_steady = false;

    static time_point now() noexcept {
#ifdef _WIN32
        FILETIME ft;
        GetSystemTimeAsFileTime(&ft);
        ULARGE_INTEGER uli;
        uli.LowPart = ft.dwLowDateTime;
        uli.HighPart = ft.dwHighDateTime;
        // FILETIME是100纳秒单位，从1601年开始
        // 转换为Unix纪元
        return time_point(nanoseconds(
            (uli.QuadPart - 116444736000000000ULL) * 100));
#else
        struct timespec ts;
        clock_gettime(CLOCK_REALTIME, &ts);
        return time_point(nanoseconds(
            ts.tv_sec * 1000000000LL + ts.tv_nsec));
#endif
    }

    static std::time_t to_time_t(const time_point& tp) noexcept {
        return duration_cast<seconds>(tp.time_since_epoch()).count();
    }

    static time_point from_time_t(std::time_t t) noexcept {
        return time_point(seconds(t));
    }
};

using high_resolution_clock = steady_clock;

} // namespace mini::chrono
```

#### Part 4: 实用时间工具
```cpp
// time_utils.hpp
#pragma once
#include <chrono>
#include <string>
#include <sstream>
#include <iomanip>

namespace time_utils {

// 格式化持续时间为可读字符串
template <typename Duration>
std::string format_duration(Duration d) {
    using namespace std::chrono;

    auto hrs = duration_cast<hours>(d);
    d -= hrs;
    auto mins = duration_cast<minutes>(d);
    d -= mins;
    auto secs = duration_cast<seconds>(d);
    d -= secs;
    auto ms = duration_cast<milliseconds>(d);

    std::ostringstream oss;
    if (hrs.count() > 0) {
        oss << hrs.count() << "h ";
    }
    if (mins.count() > 0) {
        oss << mins.count() << "m ";
    }
    if (secs.count() > 0) {
        oss << secs.count() << "s ";
    }
    oss << ms.count() << "ms";

    return oss.str();
}

// 格式化时间点
std::string format_time(std::chrono::system_clock::time_point tp,
                        const char* fmt = "%Y-%m-%d %H:%M:%S") {
    auto t = std::chrono::system_clock::to_time_t(tp);
    std::tm tm = *std::localtime(&t);

    std::ostringstream oss;
    oss << std::put_time(&tm, fmt);
    return oss.str();
}

// 解析时间字符串
std::chrono::system_clock::time_point parse_time(
    const std::string& str,
    const char* fmt = "%Y-%m-%d %H:%M:%S") {

    std::tm tm = {};
    std::istringstream iss(str);
    iss >> std::get_time(&tm, fmt);

    return std::chrono::system_clock::from_time_t(std::mktime(&tm));
}

// 简易秒表
class Stopwatch {
    using Clock = std::chrono::steady_clock;
    Clock::time_point start_;
    Clock::duration accumulated_{0};
    bool running_ = false;

public:
    void start() {
        if (!running_) {
            start_ = Clock::now();
            running_ = true;
        }
    }

    void stop() {
        if (running_) {
            accumulated_ += Clock::now() - start_;
            running_ = false;
        }
    }

    void reset() {
        accumulated_ = Clock::duration{0};
        running_ = false;
    }

    Clock::duration elapsed() const {
        if (running_) {
            return accumulated_ + (Clock::now() - start_);
        }
        return accumulated_;
    }

    template <typename Duration = std::chrono::milliseconds>
    typename Duration::rep elapsed_count() const {
        return std::chrono::duration_cast<Duration>(elapsed()).count();
    }
};

// 速率限制器
class RateLimiter {
    using Clock = std::chrono::steady_clock;
    Clock::duration interval_;
    Clock::time_point last_allowed_;

public:
    explicit RateLimiter(Clock::duration interval)
        : interval_(interval), last_allowed_(Clock::now() - interval) {}

    bool try_acquire() {
        auto now = Clock::now();
        if (now - last_allowed_ >= interval_) {
            last_allowed_ = now;
            return true;
        }
        return false;
    }

    void wait() {
        auto now = Clock::now();
        auto next = last_allowed_ + interval_;
        if (next > now) {
            std::this_thread::sleep_until(next);
        }
        last_allowed_ = Clock::now();
    }
};

} // namespace time_utils
```

---

## 检验标准

### 知识检验
- [ ] duration、time_point、clock各自的作用是什么？
- [ ] steady_clock和system_clock的区别？各适用什么场景？
- [ ] ratio如何实现编译期有理数运算？
- [ ] 为什么测量时间间隔应该用steady_clock？
- [ ] duration_cast的截断行为是什么？负数如何处理？
- [ ] 什么是时钟漂移？如何检测？
- [ ] 基准测试中如何防止编译器优化消除？
- [ ] C++20日历和时区的主要类型有哪些？

### 实践检验
- [ ] mini_duration支持类型安全的时间运算
- [ ] mini_clock在各平台正确获取时间
- [ ] 实用工具（Stopwatch、RateLimiter）工作正常
- [ ] MockClock可用于单元测试
- [ ] 性能分析器开销足够低
- [ ] 限流器和缓存在并发场景下正确工作

### 输出物
1. `mini_chrono.hpp`（duration）
2. `mini_time_point.hpp`
3. `mini_clock.hpp`
4. `time_utils.hpp`
5. `test_chrono.cpp`
6. `notes/month11_chrono.md`

---

## 时间分配（140小时/月）

| 内容 | 时间 | 占比 |
|------|------|------|
| 理论学习 | 30小时 | 21% |
| 源码阅读 | 25小时 | 18% |
| mini_chrono实现 | 40小时 | 29% |
| mini_clock实现 | 25小时 | 18% |
| 工具与测试 | 20小时 | 14% |

---

## 每日学习安排建议

### 工作日（每天5小时）
```
早晨 (1.5h): 理论学习/源码阅读
下午 (2h):   代码实现
晚上 (1.5h): 测试调试/笔记整理
```

### 周末（每天7小时）
```
上午 (3h): 集中实践/项目开发
下午 (2h): 复习总结
晚上 (2h): 扩展阅读/休息调整
```

### 里程碑检查点

| 时间点 | 检查内容 | 验收标准 |
|--------|----------|----------|
| 第7天 | Week 1完成 | mini_duration通过基本测试 |
| 第14天 | Week 2完成 | mini_clock跨平台工作正常 |
| 第21天 | Week 3完成 | time_point + 时间格式化完成 |
| 第28天 | 全部完成 | 完整工具库 + 所有测试通过 |

---

## 下月预告

Month 12将是第一年的总结与综合项目月，整合本年学习内容，完成一个综合性项目，并进行知识复盘。
