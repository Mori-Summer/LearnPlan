# Month 51: 面向数据设计（DOD）基础 (Data-Oriented Design Fundamentals)

## 本月主题概述

面向数据设计（Data-Oriented Design, DOD）是一种以数据布局和访问模式为中心的编程范式，与传统的面向对象设计形成鲜明对比。DOD通过优化数据在内存中的组织方式，最大化CPU缓存利用率，从而获得显著的性能提升。本月将深入学习DOD的核心原理，理解为何"数据的组织方式决定性能"。

### 学习目标
- 理解CPU缓存层次结构对性能的影响
- 掌握AoS与SoA数据布局的区别与选择
- 学会分析和优化数据访问模式
- 实践热/冷数据分离策略
- 构建缓存友好的数据结构

**进阶目标**：
- 深入理解缓存关联度、替换策略、写策略对DOD设计的影响
- 掌握AoSoA混合布局在SIMD宽度匹配中的优势与实现
- 能够使用perf/cachegrind/VTune等工具量化缓存性能并指导优化
- 理解Slot Map、内存池、双缓冲等DOD核心数据结构的设计哲学
- 掌握分支消除、循环分块、非时间性存储等高级优化技术
- 能够将DOD技术集成为完整的优化管线，系统性地提升数据密集型程序性能

---

## 理论学习内容

### 第一周：CPU缓存与内存层次结构（35小时）

**学习目标**：
- [ ] 深入理解CPU缓存层次结构中L1/L2/L3的具体参数差异（大小、延迟、关联度、包含性策略）
- [ ] 掌握缓存行的完整工作机制：地址映射、替换策略（LRU/PLRU/Random）、写策略（write-back vs write-through）
- [ ] 理解三种缓存未命中类型（compulsory/capacity/conflict）的成因与各自优化方法
- [ ] 掌握伪共享（false sharing）的检测方法与C++17 `alignas`/`hardware_destructive_interference_size` 解决方案
- [ ] 了解TLB（Translation Lookaside Buffer）对大数据集遍历性能的影响及大页面优化
- [ ] 学会使用perf stat/cachegrind/VTune等工具量化缓存性能
- [ ] 能够设计缓存友好的数据结构和算法（分块、Morton码布局等）

**阅读材料**：
- [ ] 《What Every Programmer Should Know About Memory》- Ulrich Drepper（重点Section 3: CPU Caches）
- [ ] 《Computer Architecture: A Quantitative Approach》第6版 - Appendix B: Memory Hierarchy
- [ ] Intel 64 and IA-32 Architectures Optimization Reference Manual - Chapter 3
- [ ] CppCon 2014：《Data-Oriented Design and C++》- Mike Acton
- [ ] CppCon 2016：《Want fast C++? Know your hardware!》- Timur Doumler
- [ ] Agner Fog《Optimizing software in C++》- Chapter 9: Optimizing memory access
- [ ] Gallery of Processor Cache Effects - Igor Ostrovsky 博客

---

#### 核心概念

**内存层次结构**
```
┌─────────────────────────────────────────────────────────┐
│                      CPU                                │
│  ┌─────────────────────────────────────────────────┐   │
│  │   寄存器 (Registers) - ~1 cycle, ~KB             │   │
│  └─────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────┐   │
│  │   L1 Cache - ~4 cycles, 32-64KB per core        │   │
│  └─────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────┐   │
│  │   L2 Cache - ~12 cycles, 256KB-1MB per core     │   │
│  └─────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────┐   │
│  │   L3 Cache - ~40 cycles, 8-64MB shared          │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼ ~100-300 cycles
┌─────────────────────────────────────────────────────────┐
│                 主内存 (DRAM) - GB级别                    │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼ ~millions cycles
┌─────────────────────────────────────────────────────────┐
│                    存储设备 (SSD/HDD)                    │
└─────────────────────────────────────────────────────────┘
```

---

#### 1.1 CPU缓存层次结构深度解析

```cpp
// ==========================================
// CPU缓存层次结构：从晶体管到纳秒
// ==========================================
//
// 为什么要深入理解缓存层次？
//   自1980年代以来，CPU计算速度的增长远超内存访问速度——
//   这就是著名的"Memory Wall"（内存墙）问题。
//   1980年CPU和DRAM速度相当（~1 cycle），
//   到2020年，CPU可以在等待一次DRAM访问的时间内执行300+条指令。
//
//   缓存的存在正是为了缓解这个差距。对DOD开发者而言，
//   理解缓存意味着理解"你的数据在哪里"——这比"你的算法复杂度"
//   更能决定实际运行速度。
//
// 关键洞察（Mike Acton 2014 CppCon）：
//   "If you don't understand the hardware, you can't reason about the cost
//    of the code you write."
//
// 缓存层次为何是多级的？
//   - 物理限制：更快的SRAM密度更低、功耗更高、造价更贵
//   - 经济原则：用少量昂贵的快速存储 + 大量廉价的慢速存储
//   - 时间局部性：最近访问过的数据很可能再次被访问
//   - 空间局部性：一个地址附近的数据很可能被接下来访问

#include <cstdint>
#include <cstddef>
#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <array>

namespace dod::cache {

// 缓存层级信息结构
struct CacheLevelInfo {
    int level;                // 缓存级别：1, 2, 3
    char type;                // 'D'=数据, 'I'=指令, 'U'=统一
    size_t size;              // 大小（字节）
    size_t lineSize;          // 缓存行大小
    int associativity;        // 关联度（N路组相联）
    int sets;                 // 组数
    bool shared;              // 是否跨核共享
};

// ==========================================
// 运行时缓存参数探测器
// ==========================================
//
// 在Linux上，缓存信息暴露在 /sys/devices/system/cpu/cpu0/cache/ 下。
// 每个 indexN 目录对应一个缓存级别，包含：
//   level:               缓存级别
//   type:                Data / Instruction / Unified
//   size:                总大小（如 "32K"）
//   coherency_line_size: 缓存行大小
//   ways_of_associativity: 关联度
//   number_of_sets:      组数
//
// 在macOS上，使用 sysctl 命令：
//   sysctl -a | grep cache
//   hw.l1dcachesize, hw.l2cachesize, hw.l3cachesize
//
// 为什么在运行时探测而不是硬编码？
//   因为DOD代码经常需要根据实际缓存大小调整分块(tiling)参数。
//   例如，L1D是32KB时分块大小和48KB时应该不同。

class CacheHierarchyExplorer {
public:
    static std::vector<CacheLevelInfo> detect() {
        std::vector<CacheLevelInfo> caches;

#ifdef __linux__
        // Linux: 从sysfs读取
        for (int index = 0; index < 10; ++index) {
            std::string base = "/sys/devices/system/cpu/cpu0/cache/index"
                             + std::to_string(index) + "/";

            std::ifstream levelFile(base + "level");
            if (!levelFile.good()) break;

            CacheLevelInfo info{};

            // 读取缓存级别
            levelFile >> info.level;

            // 读取类型
            std::ifstream typeFile(base + "type");
            std::string typeStr;
            typeFile >> typeStr;
            info.type = typeStr[0];  // 'D', 'I', 或 'U'

            // 读取大小（格式如 "32K"）
            std::ifstream sizeFile(base + "size");
            std::string sizeStr;
            sizeFile >> sizeStr;
            info.size = parseSizeString(sizeStr);

            // 读取缓存行大小
            std::ifstream lineFile(base + "coherency_line_size");
            lineFile >> info.lineSize;

            // 读取关联度
            std::ifstream waysFile(base + "ways_of_associativity");
            waysFile >> info.associativity;

            // 读取组数
            std::ifstream setsFile(base + "number_of_sets");
            setsFile >> info.sets;

            // L3通常是共享的
            std::ifstream sharedFile(base + "shared_cpu_list");
            std::string sharedStr;
            std::getline(sharedFile, sharedStr);
            info.shared = (sharedStr.find('-') != std::string::npos ||
                          sharedStr.find(',') != std::string::npos);

            caches.push_back(info);
        }
#elif defined(__APPLE__)
        // macOS: 使用 sysctlbyname
        // 简化实现——实际使用时可调用sysctlbyname API
        caches.push_back({1, 'I', 32 * 1024, 64, 8, 64, false});
        caches.push_back({1, 'D', 48 * 1024, 64, 12, 64, false});
        caches.push_back({2, 'U', 256 * 1024, 64, 8, 512, false});
        caches.push_back({3, 'U', 12 * 1024 * 1024, 64, 12, 16384, true});
#endif

        return caches;
    }

    static void printHierarchy() {
        auto caches = detect();

        std::cout << "===== CPU Cache Hierarchy =====\n\n";
        std::cout << "Level  Type       Size       Line  Ways  Sets    Shared\n";
        std::cout << "─────  ─────────  ─────────  ────  ────  ──────  ──────\n";

        for (const auto& c : caches) {
            std::string typeStr;
            switch (c.type) {
                case 'D': typeStr = "Data"; break;
                case 'I': typeStr = "Instruct"; break;
                case 'U': typeStr = "Unified"; break;
                default:  typeStr = "Unknown";
            }

            std::cout << "L" << c.level << "     "
                      << typeStr << std::string(10 - typeStr.size(), ' ')
                      << formatSize(c.size) << std::string(10 - formatSize(c.size).size(), ' ')
                      << c.lineSize << "B   "
                      << c.associativity << "     "
                      << c.sets << std::string(8 - std::to_string(c.sets).size(), ' ')
                      << (c.shared ? "Yes" : "No") << "\n";
        }

        // 计算带宽层级图
        std::cout << "\n===== 典型延迟与带宽 =====\n";
        std::cout << R"(
  Register ─── ~0.3ns ──── ~TB/s ────┐
       │                              │
  L1 Cache ─── ~1.5ns ──── ~1TB/s ───┤  CPU内部
       │                              │
  L2 Cache ─── ~5ns ────── ~500GB/s ──┤
       │                              │
  L3 Cache ─── ~15ns ───── ~200GB/s ──┘
       │
  DRAM ─────── ~60ns ───── ~50GB/s
       │
  SSD ──────── ~100μs ──── ~5GB/s
       │
  HDD ──────── ~10ms ───── ~200MB/s
)";
    }

private:
    static size_t parseSizeString(const std::string& s) {
        size_t value = std::stoull(s);
        if (s.back() == 'K' || s.back() == 'k') value *= 1024;
        else if (s.back() == 'M' || s.back() == 'm') value *= 1024 * 1024;
        return value;
    }

    static std::string formatSize(size_t bytes) {
        if (bytes >= 1024 * 1024) return std::to_string(bytes / (1024 * 1024)) + "MB";
        if (bytes >= 1024) return std::to_string(bytes / 1024) + "KB";
        return std::to_string(bytes) + "B";
    }
};

} // namespace dod::cache
```

**现代CPU缓存参数对比（典型值）**

| 参数 | L1D | L1I | L2 | L3 |
|------|-----|-----|----|----|
| **大小** | 32-48KB/核 | 32-64KB/核 | 256KB-1MB/核 | 8-64MB共享 |
| **延迟** | 4-5 cycles | 4-5 cycles | 12-14 cycles | 30-50 cycles |
| **关联度** | 8-12路 | 8路 | 8-16路 | 12-20路 |
| **缓存行** | 64B | 64B | 64B | 64B |
| **共享** | 每核独有 | 每核独有 | 每核独有 | 所有核共享 |
| **包含性(Intel)** | - | - | Non-inclusive | Inclusive→Non-inclusive |
| **包含性(AMD Zen)** | - | - | Inclusive of L1 | Exclusive(victim cache) |
| **SRAM单元** | 6T(快) | 6T | 6T/8T | 8T(密度优先) |

```
为什么L1分为数据缓存(L1D)和指令缓存(L1I)？
─────────────────────────────────────────────
这是哈佛架构在缓存层面的体现：

  CPU流水线:  取指(Fetch) → 解码(Decode) → 执行(Execute) → 访存(Memory) → 写回(Writeback)
                 │                                     │
                 ▼                                     ▼
              L1I Cache                            L1D Cache
              (指令流)                              (数据流)

分开的好处：
1. 取指和数据访问可以并行进行，不会相互争抢端口
2. 指令缓存可以针对只读特性优化（不需要dirty bit）
3. 数据缓存可以针对读写混合优化（需要写策略）

从L2开始统一（Unified），因为：
1. 不同程序的指令/数据比例不同，统一缓存更灵活
2. L2及以上更关注容量，统一设计减少浪费
```

---

#### 1.2 缓存行工作机制详解

```cpp
// ==========================================
// 缓存行：CPU与内存交互的最小单位
// ==========================================
//
// 缓存行（Cache Line）是缓存管理的基本单元。
// 即使你只需要读1个字节，CPU也会加载整个缓存行（通常64字节）。
//
// 这个事实是DOD的物理基础：
//   - 如果64字节中只有4字节有用，带宽利用率仅6.25%
//   - 如果64字节全部有用，带宽利用率100%
//   - DOD的核心目标就是让每次内存传输都"物尽其用"
//
// 地址如何映射到缓存？
//   对于一个N路组相联缓存（N-way Set-Associative），
//   物理地址被分为三部分：
//
//   ┌──────────────┬─────────────┬──────────────┐
//   │   Tag (标签)  │ Index (索引) │ Offset (偏移) │
//   └──────────────┴─────────────┴──────────────┘
//
//   Offset = log2(缓存行大小) 位
//   Index  = log2(组数) 位
//   Tag    = 剩余位
//
// 以典型的 32KB / 8路 / 64B缓存行 为例：
//   组数 = 32KB / (8 * 64B) = 64组
//   Offset = log2(64) = 6 位
//   Index  = log2(64) = 6 位
//   Tag    = 48 - 6 - 6 = 36 位（假设48位物理地址）

#include <cstdint>
#include <cstddef>
#include <vector>
#include <iostream>
#include <iomanip>
#include <cassert>

namespace dod::cache {

// ==========================================
// 简化缓存模拟器
// ==========================================
//
// 这是一个教学用的缓存模拟器，用于理解缓存行为。
// 它模拟一个N路组相联缓存，支持LRU替换策略。
//
// 使用场景：
//   1. 在不使用perf工具的情况下预测缓存行为
//   2. 比较不同数据布局的理论缓存性能
//   3. 理解为什么某些访问模式会导致冲突未命中
//
// 注意：这不是一个精确的硬件模拟器，
//       而是帮助理解概念的教学工具。

class CacheSimulator {
public:
    struct Config {
        size_t cacheSize;      // 缓存总大小（字节）
        size_t lineSize;       // 缓存行大小
        int associativity;     // 关联度（路数）
    };

    struct Stats {
        uint64_t accesses = 0;
        uint64_t hits = 0;
        uint64_t misses = 0;
        uint64_t compulsoryMisses = 0;  // 首次访问
        uint64_t evictions = 0;         // 驱逐次数

        double hitRate() const {
            return accesses > 0 ? 100.0 * hits / accesses : 0.0;
        }
        double missRate() const { return 100.0 - hitRate(); }
    };

private:
    struct CacheLine {
        bool valid = false;
        uint64_t tag = 0;
        uint64_t lastAccess = 0;  // LRU时间戳
    };

    Config config_;
    size_t numSets_;
    size_t offsetBits_;
    size_t indexBits_;

    // sets_[set_index][way] = CacheLine
    std::vector<std::vector<CacheLine>> sets_;
    Stats stats_;
    uint64_t accessCounter_ = 0;

    // 记录所有曾经访问过的缓存行地址（用于区分compulsory miss）
    std::vector<bool> seenLines_;
    static constexpr size_t MAX_TRACKED_LINES = 1 << 20;  // 跟踪100万个不同的行

public:
    explicit CacheSimulator(Config config)
        : config_(config) {
        numSets_ = config.cacheSize / (config.lineSize * config.associativity);

        // 计算位字段宽度
        offsetBits_ = __builtin_ctzll(config.lineSize);  // log2(lineSize)
        indexBits_ = __builtin_ctzll(numSets_);           // log2(numSets)

        // 初始化缓存
        sets_.resize(numSets_);
        for (auto& set : sets_) {
            set.resize(config.associativity);
        }

        seenLines_.resize(MAX_TRACKED_LINES, false);
    }

    // 模拟一次内存访问
    bool access(uint64_t address) {
        stats_.accesses++;
        accessCounter_++;

        uint64_t lineAddress = address >> offsetBits_;
        uint64_t setIndex = lineAddress & ((1ULL << indexBits_) - 1);
        uint64_t tag = lineAddress >> indexBits_;

        auto& set = sets_[setIndex];

        // 查找是否命中
        for (auto& line : set) {
            if (line.valid && line.tag == tag) {
                // 命中！
                stats_.hits++;
                line.lastAccess = accessCounter_;  // 更新LRU
                return true;
            }
        }

        // 未命中
        stats_.misses++;

        // 是否是首次访问此行？
        size_t lineHash = lineAddress % MAX_TRACKED_LINES;
        if (!seenLines_[lineHash]) {
            stats_.compulsoryMisses++;
            seenLines_[lineHash] = true;
        }

        // 查找空位或LRU替换
        CacheLine* victim = &set[0];
        for (auto& line : set) {
            if (!line.valid) {
                victim = &line;
                break;
            }
            if (line.lastAccess < victim->lastAccess) {
                victim = &line;
            }
        }

        if (victim->valid) {
            stats_.evictions++;
        }

        // 填入新行
        victim->valid = true;
        victim->tag = tag;
        victim->lastAccess = accessCounter_;

        return false;
    }

    const Stats& getStats() const { return stats_; }

    void reset() {
        stats_ = {};
        accessCounter_ = 0;
        for (auto& set : sets_) {
            for (auto& line : set) {
                line = {};
            }
        }
        std::fill(seenLines_.begin(), seenLines_.end(), false);
    }

    void printStats(const char* label = "") const {
        std::cout << "===== Cache Stats" << (label[0] ? ": " : "") << label
                  << " =====\n"
                  << "Accesses:         " << stats_.accesses << "\n"
                  << "Hits:             " << stats_.hits << "\n"
                  << "Misses:           " << stats_.misses << "\n"
                  << "  Compulsory:     " << stats_.compulsoryMisses << "\n"
                  << "  Capacity+Conf:  " << (stats_.misses - stats_.compulsoryMisses) << "\n"
                  << "Evictions:        " << stats_.evictions << "\n"
                  << "Hit Rate:         " << std::fixed << std::setprecision(2)
                  << stats_.hitRate() << "%\n\n";
    }
};

// 地址分解可视化
void explainAddressMapping(uint64_t address, size_t lineSize,
                            size_t numSets, int associativity) {
    size_t offsetBits = __builtin_ctzll(lineSize);
    size_t indexBits = __builtin_ctzll(numSets);

    uint64_t offset = address & ((1ULL << offsetBits) - 1);
    uint64_t index = (address >> offsetBits) & ((1ULL << indexBits) - 1);
    uint64_t tag = address >> (offsetBits + indexBits);

    std::cout << "地址 0x" << std::hex << address << std::dec << " 的缓存映射：\n"
              << "  Tag:    0x" << std::hex << tag << std::dec
              << " (" << (48 - offsetBits - indexBits) << " bits)\n"
              << "  Index:  " << index << " (组" << index << "/" << numSets << ")\n"
              << "  Offset: " << offset << " (行内第" << offset << "字节)\n"
              << "  → 映射到第" << index << "组，" << associativity << "路中的任意一路\n\n";
}

} // namespace dod::cache
```

```
地址分解示意图（32KB / 8路 / 64B缓存行）：

  48位物理地址
  ┌────────────────────────────────────┬────────┬────────┐
  │           Tag (36 bits)            │Index(6)│Offset(6)│
  └────────────────────────────────────┴────────┴────────┘
  │                                    │        │        │
  │  唯一标识该缓存行                   │ 决定放在 │ 行内   │
  │  在N路中通过Tag比较确定是否命中      │ 哪个组  │ 字节位 │

  组相联映射过程：
  地址 0x7FFE0040:
    二进制: ...0111 1111 1111 1110 0000 0000 0100 0000
    Offset [5:0]  = 000000 = 0（行首）
    Index  [11:6] = 000001 = 第1组
    Tag    [47:12] = 0x7FFE00

  ┌─────────────────────────────────────────┐
  │                 缓存                     │
  │  ┌──────┬──────┬──────┬──── ──┬──────┐  │
  │  │ Way0 │ Way1 │ Way2 │ ... │ Way7 │  │  ← 组0
  │  ├──────┼──────┼──────┼──────┼──────┤  │
  │  │ Way0 │ Way1 │ Way2 │ ... │ Way7 │  │  ← 组1 ← 0x7FFE0040映射到这里
  │  ├──────┼──────┼──────┼──────┼──────┤  │
  │  │ ...  │ ...  │ ...  │ ... │ ...  │  │
  │  ├──────┼──────┼──────┼──────┼──────┤  │
  │  │ Way0 │ Way1 │ Way2 │ ... │ Way7 │  │  ← 组63
  │  └──────┴──────┴──────┴──────┴──────┘  │
  └─────────────────────────────────────────┘
```

**替换策略对比**

| 策略 | 原理 | 实现开销 | 命中率 | 常见使用 |
|------|------|---------|--------|---------|
| **LRU** | 替换最久未使用的 | 高（需维护访问序） | 最优 | L1（少路数） |
| **Pseudo-LRU** | 树形近似LRU | 中等（每组N-1位） | 接近LRU | L2/L3（多路数） |
| **Random** | 随机选择替换 | 最低 | 略差 | ARM某些实现 |
| **FIFO** | 先进先出 | 低 | 一般 | 简单嵌入式 |

---

#### 1.3 缓存未命中类型与优化策略

```cpp
// ==========================================
// 三种缓存未命中（Three Cs Model）
// ==========================================
//
// 理解缓存未命中的类型是DOD优化的诊断基础。
// 就像医生需要区分不同的病症才能对症下药，
// 我们需要区分不同的miss类型才能选择正确的优化手段。
//
// 1. Compulsory Miss（强制未命中/冷启动未命中）
//    - 首次访问一个缓存行时必然发生
//    - 任何缓存都无法避免
//    - 优化手段：软件预取（提前加载）、增大缓存行
//
// 2. Capacity Miss（容量未命中）
//    - 工作集超出缓存容量时发生
//    - 即使是全相联缓存也会发生
//    - 优化手段：减小工作集（热/冷分离）、循环分块(tiling)、数据压缩
//
// 3. Conflict Miss（冲突未命中）
//    - 多个地址映射到同一组，超出关联度
//    - 全相联缓存不会发生
//    - 优化手段：数据对齐调整、增加关联度、padding避免power-of-2 stride
//
// 还有第四种（多核环境）：
// 4. Coherence Miss（一致性未命中）
//    - 其他核心修改了同一缓存行导致失效
//    - 这就是"伪共享"问题的根源（详见1.4节）

#include <vector>
#include <chrono>
#include <iostream>
#include <random>
#include <numeric>
#include <cmath>

namespace dod::cache {

class CacheMissDemo {
public:
    // ──────────────────────────────────────
    // 演示1：Compulsory Miss
    // ──────────────────────────────────────
    // 首次遍历一个大数组，每个缓存行都是首次访问
    // 无论缓存多大、关联度多高，第一次访问总是miss
    //
    // 实际影响：程序启动时的"预热"阶段较慢
    // 优化手段：软件预取（提前发起内存请求）

    static double compulsoryMissDemo(size_t arraySizeBytes) {
        size_t count = arraySizeBytes / sizeof(int);
        std::vector<int> data(count);

        // 确保数据在内存中（防止被OS延迟分配）
        for (size_t i = 0; i < count; ++i) data[i] = static_cast<int>(i);

        // 刷新缓存：访问足够大的其他数据
        std::vector<int> flush(16 * 1024 * 1024);  // 64MB
        volatile int sink = 0;
        for (auto& v : flush) sink += v;

        // 首次遍历——全部是compulsory miss
        auto start = std::chrono::high_resolution_clock::now();
        volatile int sum = 0;
        for (size_t i = 0; i < count; ++i) {
            sum += data[i];
        }
        auto end = std::chrono::high_resolution_clock::now();
        double firstPass = std::chrono::duration<double, std::milli>(end - start).count();

        // 第二次遍历——应该大部分是命中（如果数组 < 缓存大小）
        start = std::chrono::high_resolution_clock::now();
        for (size_t i = 0; i < count; ++i) {
            sum += data[i];
        }
        end = std::chrono::high_resolution_clock::now();
        double secondPass = std::chrono::duration<double, std::milli>(end - start).count();

        std::cout << "数组大小: " << (arraySizeBytes / 1024) << " KB\n"
                  << "  首次遍历: " << firstPass << " ms (compulsory misses)\n"
                  << "  再次遍历: " << secondPass << " ms (mostly hits)\n"
                  << "  比率:     " << (firstPass / secondPass) << "x\n\n";

        return firstPass;
    }

    // ──────────────────────────────────────
    // 演示2：Capacity Miss
    // ──────────────────────────────────────
    // 反复遍历不同大小的数组
    // 当数组超过缓存大小时，性能会出现"台阶式"下降
    //
    // 这是DOD最关心的miss类型：
    //   如果你的热数据超过L1（32KB），性能下降3-4倍
    //   如果超过L2（256KB），再下降3-4倍
    //   如果超过L3（8MB），又下降5-10倍
    //
    // 这就是为什么热/冷数据分离如此重要：
    //   把热数据压缩到L1能放下的大小 = 最高性能

    static void capacityMissDemo() {
        std::cout << "===== Capacity Miss 阶梯效应 =====\n";
        std::cout << "数组大小        每元素耗时(ns)  说明\n";
        std::cout << "──────────────  ──────────────  ──────────\n";

        // 从1KB到64MB，每次翻倍
        for (size_t size = 1024; size <= 64 * 1024 * 1024; size *= 2) {
            size_t count = size / sizeof(int);
            std::vector<int> data(count);
            std::iota(data.begin(), data.end(), 0);

            // 多次遍历以消除compulsory miss影响
            volatile int sum = 0;
            for (int warm = 0; warm < 3; ++warm) {
                for (size_t i = 0; i < count; ++i) sum += data[i];
            }

            constexpr int ITERATIONS = 10;
            auto start = std::chrono::high_resolution_clock::now();
            for (int iter = 0; iter < ITERATIONS; ++iter) {
                for (size_t i = 0; i < count; ++i) {
                    sum += data[i];
                }
            }
            auto end = std::chrono::high_resolution_clock::now();

            double totalNs = std::chrono::duration<double, std::nano>(end - start).count();
            double nsPerElement = totalNs / (count * ITERATIONS);

            // 标记可能的缓存边界
            std::string note;
            if (size == 32 * 1024)       note = "← ~L1D边界";
            else if (size == 256 * 1024) note = "← ~L2边界";
            else if (size == 8 * 1024 * 1024) note = "← ~L3边界";

            std::cout << std::setw(8) << (size / 1024) << " KB"
                      << std::string(6, ' ')
                      << std::fixed << std::setprecision(2)
                      << std::setw(10) << nsPerElement
                      << "        " << note << "\n";
        }
    }

    // ──────────────────────────────────────
    // 演示3：Conflict Miss
    // ──────────────────────────────────────
    // 以特定步长（2的幂次）访问数组时，
    // 不同地址映射到相同的缓存组，导致冲突
    //
    // 经典陷阱：
    //   矩阵大小恰好是2的幂（如1024x1024）时，
    //   按列访问会导致严重的冲突miss——
    //   因为每行的同一列位置映射到相同的缓存组
    //
    // 解决方案：
    //   - 添加padding让每行不是2的幂次对齐
    //   - 使用分块(tiling)减少同时活跃的行数

    static void conflictMissDemo() {
        std::cout << "\n===== Conflict Miss 演示 =====\n";

        constexpr size_t N = 1024;

        // 场景1：1024x1024矩阵按列遍历（严重冲突）
        std::vector<float> matrix(N * N);
        for (size_t i = 0; i < N * N; ++i) matrix[i] = static_cast<float>(i);

        // 按行遍历（缓存友好）
        volatile float sum = 0;
        auto start = std::chrono::high_resolution_clock::now();
        for (size_t row = 0; row < N; ++row) {
            for (size_t col = 0; col < N; ++col) {
                sum += matrix[row * N + col];
            }
        }
        auto end = std::chrono::high_resolution_clock::now();
        double rowTime = std::chrono::duration<double, std::milli>(end - start).count();

        // 按列遍历（冲突严重）
        sum = 0;
        start = std::chrono::high_resolution_clock::now();
        for (size_t col = 0; col < N; ++col) {
            for (size_t row = 0; row < N; ++row) {
                sum += matrix[row * N + col];  // 步长=N*sizeof(float)=4096字节
            }
        }
        end = std::chrono::high_resolution_clock::now();
        double colTime = std::chrono::duration<double, std::milli>(end - start).count();

        // 场景2：添加padding后按列遍历
        constexpr size_t N_PADDED = N + 16;  // 每行多16个float=64字节=1缓存行
        std::vector<float> paddedMatrix(N_PADDED * N);
        for (size_t r = 0; r < N; ++r)
            for (size_t c = 0; c < N; ++c)
                paddedMatrix[r * N_PADDED + c] = static_cast<float>(r * N + c);

        sum = 0;
        start = std::chrono::high_resolution_clock::now();
        for (size_t col = 0; col < N; ++col) {
            for (size_t row = 0; row < N; ++row) {
                sum += paddedMatrix[row * N_PADDED + col];
            }
        }
        end = std::chrono::high_resolution_clock::now();
        double paddedColTime = std::chrono::duration<double, std::milli>(end - start).count();

        std::cout << "1024x1024矩阵遍历:\n"
                  << "  按行遍历:             " << rowTime << " ms\n"
                  << "  按列遍历(冲突严重):    " << colTime << " ms ("
                  << (colTime / rowTime) << "x slower)\n"
                  << "  按列遍历(padding修复): " << paddedColTime << " ms ("
                  << (paddedColTime / rowTime) << "x slower)\n";
    }
};

} // namespace dod::cache
```

**缓存未命中优化策略总结**

| 未命中类型 | 成因 | 优化手段 | DOD相关性 |
|-----------|------|---------|----------|
| **Compulsory** | 首次访问 | 预取(prefetch)、增大缓存行 | 中：预取策略（第四周） |
| **Capacity** | 工作集>缓存 | 热冷分离、循环分块、数据压缩 | **极高**：DOD核心技术 |
| **Conflict** | 地址映射冲突 | padding、避免2的幂步长 | 高：SoA设计需注意 |
| **Coherence** | 多核修改同行 | 减少共享、padding分离 | 高：并行DOD关键 |

---

#### 1.4 伪共享问题深度分析

```cpp
// ==========================================
// 伪共享（False Sharing）：多线程DOD的隐形杀手
// ==========================================
//
// 什么是伪共享？
//   两个线程访问不同的变量，但这些变量恰好在同一个缓存行内。
//   由于MESI协议（详见 plans/C++/缓存行.md）以缓存行为粒度工作，
//   一个线程的写操作会导致另一个线程的缓存行失效。
//
// 为什么这对DOD特别重要？
//   SoA布局中，多个数组的末尾可能相邻存储。
//   如果线程A更新数组X、线程B更新数组Y，
//   当两个数组很小时，X的末尾和Y的开头可能共享缓存行——
//   这就是"SoA的伪共享陷阱"。
//
// 性能影响有多大？
//   伪共享可以让多线程程序比单线程还慢！
//   典型退化：2-10倍性能下降，极端情况100倍。
//
// C++17提供了标准解决方案：
//   std::hardware_destructive_interference_size （通常=64）
//   这是"两个独立访问的对象应该间隔至少这么远"的距离。

#include <atomic>
#include <thread>
#include <chrono>
#include <iostream>
#include <vector>
#include <new>

namespace dod::cache {

// ──────────────────────────────────────
// 场景1：经典伪共享演示
// ──────────────────────────────────────

// 不良设计：两个计数器紧挨着
struct NaiveCounters {
    std::atomic<uint64_t> counterA{0};  // 线程A使用
    std::atomic<uint64_t> counterB{0};  // 线程B使用
    // 两个计数器在同一个缓存行内！
};

// 修复方案1：alignas对齐
struct PaddedCounters {
    alignas(64) std::atomic<uint64_t> counterA{0};  // 独占一个缓存行
    alignas(64) std::atomic<uint64_t> counterB{0};  // 独占另一个缓存行
};

// 修复方案2：C++17标准方式（如果编译器支持）
#ifdef __cpp_lib_hardware_interference_size
struct StandardPaddedCounters {
    alignas(std::hardware_destructive_interference_size)
        std::atomic<uint64_t> counterA{0};
    alignas(std::hardware_destructive_interference_size)
        std::atomic<uint64_t> counterB{0};
};
#endif

template<typename Counters>
double benchmarkFalseSharing(const char* name, int64_t iterations) {
    Counters counters;

    auto worker = [&](std::atomic<uint64_t>& counter) {
        for (int64_t i = 0; i < iterations; ++i) {
            counter.fetch_add(1, std::memory_order_relaxed);
        }
    };

    auto start = std::chrono::high_resolution_clock::now();

    std::thread t1(worker, std::ref(counters.counterA));
    std::thread t2(worker, std::ref(counters.counterB));
    t1.join();
    t2.join();

    auto end = std::chrono::high_resolution_clock::now();
    double ms = std::chrono::duration<double, std::milli>(end - start).count();

    std::cout << name << ": " << ms << " ms"
              << " (counterA addr: " << &counters.counterA
              << ", counterB addr: " << &counters.counterB
              << ", distance: "
              << (reinterpret_cast<char*>(&counters.counterB) -
                  reinterpret_cast<char*>(&counters.counterA))
              << " bytes)\n";

    return ms;
}

// ──────────────────────────────────────
// 场景2：SoA的伪共享陷阱
// ──────────────────────────────────────
//
// 当SoA中的多个小数组被不同线程更新时，
// 数组之间的边界可能产生伪共享。
//
// 例如：100个粒子的SoA
//   x数组：400字节（6.25个缓存行）
//   y数组：紧跟x数组之后
//   → x数组的最后一个缓存行可能和y数组的第一个缓存行重叠！
//
//   线程A更新x数组末尾 ← → 线程B更新y数组开头
//                    共享的缓存行

struct SoAFalseSharingTrap {
    // 不良设计：小数组紧邻存储
    std::vector<float> x, y, z;

    void resize(size_t n) {
        x.resize(n); y.resize(n); z.resize(n);
    }
};

struct SoAFixedLayout {
    // 修复：确保每个数组起始地址64字节对齐
    // 使用对齐分配器（见实践项目的AlignedAllocator）
    std::vector<float, AlignedAllocator<float, 64>> x, y, z;

    void resize(size_t n) {
        // 确保每个数组的大小是缓存行的整数倍
        size_t alignedCount = ((n * sizeof(float) + 63) / 64) * 64 / sizeof(float);
        x.resize(alignedCount);
        y.resize(alignedCount);
        z.resize(alignedCount);
    }
};

// ──────────────────────────────────────
// 场景3：DOD正确的多线程模式
// ──────────────────────────────────────
//
// 最佳实践：每个线程操作自己的本地缓冲区，
// 最后再合并结果。这完全消除了伪共享。

struct ThreadLocalAccumulator {
    // 每个线程一个累加缓冲区，缓存行对齐
    struct alignas(64) LocalBuffer {
        float values[16];  // 填满一个缓存行
    };

    std::vector<LocalBuffer> perThreadBuffers;

    explicit ThreadLocalAccumulator(int numThreads)
        : perThreadBuffers(numThreads) {}

    // 每个线程写自己的buffer，零伪共享
    void accumulate(int threadId, float value) {
        perThreadBuffers[threadId].values[0] += value;
    }

    // 最后由单一线程合并
    float reduce() const {
        float total = 0;
        for (const auto& buf : perThreadBuffers) {
            total += buf.values[0];
        }
        return total;
    }
};

void runFalseSharingBenchmark() {
    constexpr int64_t ITERATIONS = 100'000'000;

    std::cout << "===== False Sharing Benchmark =====\n\n";

    double naiveTime = benchmarkFalseSharing<NaiveCounters>(
        "Naive (same cache line)  ", ITERATIONS);
    double paddedTime = benchmarkFalseSharing<PaddedCounters>(
        "Padded (separate lines)  ", ITERATIONS);

    std::cout << "\nSpeedup from fixing false sharing: "
              << (naiveTime / paddedTime) << "x\n";
}

} // namespace dod::cache
```

```
伪共享图示：

  缓存行 (64 bytes)
  ┌────────────────────────────────────────────────────────────┐
  │ counterA (8B) │ counterB (8B) │       unused (48B)         │
  └───────┬───────┴───────┬───────┴────────────────────────────┘
          │               │
     Thread A writes  Thread B writes
          │               │
          └───────────────┘
          共享同一缓存行！
          每次写入都触发MESI协议失效

  修复后：
  ┌────────────────────────────────────────────────────────────┐
  │ counterA (8B) │              padding (56B)                 │  ← 缓存行1
  └───────────────┴────────────────────────────────────────────┘
  ┌────────────────────────────────────────────────────────────┐
  │ counterB (8B) │              padding (56B)                 │  ← 缓存行2
  └───────────────┴────────────────────────────────────────────┘
  各自独占缓存行，互不干扰
```

---

#### 1.5 TLB与大页面（Huge Pages）

```cpp
// ==========================================
// TLB：被忽视的性能瓶颈
// ==========================================
//
// TLB（Translation Lookaside Buffer）是页表的缓存。
// 每次内存访问都需要虚拟地址→物理地址的转换，
// 这个转换需要查页表——但页表本身在内存中，查页表也很慢。
// TLB就是缓存这个转换结果的硬件。
//
// 为什么DOD开发者要关心TLB？
//   - 标准4KB页面：64条目的TLB只能覆盖256KB虚拟内存
//   - 1M粒子 × 4字节/float × 6数组(x,y,z,vx,vy,vz) = 24MB
//   - 24MB / 4KB = 6144页 → 远超TLB容量 → TLB miss暴增
//
//   使用2MB大页面：64条目覆盖128MB → 24MB轻松覆盖
//   性能提升：对大数据集可达10-30%
//
// 关键参数（典型Intel CPU）：
//   L1 DTLB：64条目，4路组相联，4KB页（覆盖256KB）
//   L1 DTLB：32条目，4路组相联，2MB页（覆盖64MB）
//   L2 STLB：1536条目，12路组相联（覆盖6MB/3GB）
//
// TLB miss的代价：
//   4级页表遍历 = 4次内存访问 ≈ 4 × 60ns = 240ns
//   而L1 hit仅需1.5ns —— 差160倍

#include <cstddef>
#include <chrono>
#include <vector>
#include <iostream>
#include <random>
#include <cstring>

#ifdef __linux__
#include <sys/mman.h>
#endif

namespace dod::cache {

// ==========================================
// TLB效应基准测试
// ==========================================
//
// 使用指针追踪（pointer chasing）来隔离TLB效应。
// 通过构造一个链表使得：
//   - 每次跳转恰好跨页面（4KB stride）
//   - 这样L1/L2/L3缓存不是瓶颈（每页只访问一个元素）
//   - 但TLB成为瓶颈（每次访问都是不同的页面）

class TLBBenchmark {
public:
    // 使用指针追踪测量不同工作集大小的访问延迟
    static void measureTLBEffect() {
        std::cout << "===== TLB Effect Benchmark =====\n";
        std::cout << "工作集大小    每次访问延迟(ns)  说明\n";
        std::cout << "──────────  ────────────────  ──────────\n";

        // 从64KB到256MB
        for (size_t size = 64 * 1024; size <= 256 * 1024 * 1024; size *= 2) {
            double latency = measureLatency(size, 4096);  // 4KB stride = 每页一次

            std::string note;
            if (size == 256 * 1024) note = "← ~L1 DTLB边界(64×4KB)";
            else if (size == 2 * 1024 * 1024) note = "← ~L2 STLB开始吃紧";
            else if (size == 8 * 1024 * 1024) note = "← ~L2 STLB溢出";

            std::cout << std::setw(8) << (size / 1024) << " KB"
                      << std::string(4, ' ')
                      << std::fixed << std::setprecision(1)
                      << std::setw(12) << latency
                      << "        " << note << "\n";
        }
    }

private:
    static double measureLatency(size_t arraySize, size_t stride) {
        // 创建指针追踪链
        size_t count = arraySize / sizeof(void*);
        std::vector<void*> array(count, nullptr);

        // 构造stride步长的链表
        size_t strideElements = stride / sizeof(void*);
        std::vector<size_t> indices;
        for (size_t i = 0; i < count; i += strideElements) {
            indices.push_back(i);
        }

        // 随机化访问顺序（保持stride但打乱页面顺序）
        std::mt19937 rng(42);
        std::shuffle(indices.begin(), indices.end(), rng);

        // 构造链表
        for (size_t i = 0; i < indices.size() - 1; ++i) {
            array[indices[i]] = &array[indices[i + 1]];
        }
        array[indices.back()] = &array[indices[0]];  // 闭合环

        // 预热
        void** p = reinterpret_cast<void**>(&array[indices[0]]);
        for (size_t i = 0; i < indices.size() * 2; ++i) {
            p = reinterpret_cast<void**>(*p);
        }

        // 测量
        constexpr size_t ITERATIONS = 1000000;
        auto start = std::chrono::high_resolution_clock::now();

        for (size_t i = 0; i < ITERATIONS; ++i) {
            p = reinterpret_cast<void**>(*p);
        }

        auto end = std::chrono::high_resolution_clock::now();

        // 防止编译器优化掉
        volatile void* sink = p;
        (void)sink;

        double totalNs = std::chrono::duration<double, std::nano>(end - start).count();
        return totalNs / ITERATIONS;
    }
};

// ==========================================
// 大页面分配器
// ==========================================
//
// Linux上启用大页面的方法：
//   方法1（推荐）：madvise + 透明大页面(THP)
//     分配后调用 madvise(ptr, size, MADV_HUGEPAGE)
//     系统会尝试使用2MB大页面
//
//   方法2：显式大页面
//     先分配大页面池：echo 1024 > /proc/sys/vm/nr_hugepages
//     然后使用 mmap + MAP_HUGETLB
//
//   方法3（最简单）：环境变量
//     设置 GLIBC_TUNABLES=glibc.malloc.hugetlb=2
//     glibc会自动为大分配使用大页面

#ifdef __linux__
template<typename T>
class HugePageAllocator {
public:
    using value_type = T;

    HugePageAllocator() = default;

    template<typename U>
    HugePageAllocator(const HugePageAllocator<U>&) noexcept {}

    T* allocate(size_t n) {
        size_t size = n * sizeof(T);

        // 对齐到2MB边界（大页面大小）
        size = (size + (2 * 1024 * 1024 - 1)) & ~(2UL * 1024 * 1024 - 1);

        void* ptr = mmap(nullptr, size,
                         PROT_READ | PROT_WRITE,
                         MAP_PRIVATE | MAP_ANONYMOUS | MAP_HUGETLB,
                         -1, 0);

        if (ptr == MAP_FAILED) {
            // 回退到普通页面 + madvise
            ptr = mmap(nullptr, size,
                       PROT_READ | PROT_WRITE,
                       MAP_PRIVATE | MAP_ANONYMOUS,
                       -1, 0);
            if (ptr == MAP_FAILED) throw std::bad_alloc();

            // 请求透明大页面
            madvise(ptr, size, MADV_HUGEPAGE);
        }

        return static_cast<T*>(ptr);
    }

    void deallocate(T* ptr, size_t n) {
        size_t size = n * sizeof(T);
        size = (size + (2 * 1024 * 1024 - 1)) & ~(2UL * 1024 * 1024 - 1);
        munmap(ptr, size);
    }
};
#endif

} // namespace dod::cache
```

---

#### 1.6 缓存友好算法设计模式

```cpp
// ==========================================
// 缓存友好算法：让数据为算法服务
// ==========================================
//
// DOD的核心哲学之一是"设计算法时先考虑数据在缓存中的行为"。
// 本节介绍两个经典的缓存友好算法模式：
//
// 1. 循环分块（Loop Tiling/Blocking）
//    - 将大循环分成缓存大小的小块
//    - 每个小块的工作集完全在L1中
//    - 经典应用：矩阵乘法（从O(n^3)次miss降到O(n^3/B)次）
//
// 2. Morton码（Z-order）布局
//    - 将2D/3D坐标映射为1D索引
//    - 保持空间邻近的数据在内存中也邻近
//    - 经典应用：空间数据结构、纹理映射

#include <cstdint>
#include <vector>
#include <chrono>
#include <iostream>
#include <cmath>
#include <algorithm>

namespace dod::cache {

// ──────────────────────────────────────
// 矩阵乘法：朴素 vs 分块
// ──────────────────────────────────────
//
// 朴素矩阵乘法 C = A * B：
//   for i: for j: for k: C[i][j] += A[i][k] * B[k][j]
//
// 问题：B按列访问，步长=N*sizeof(float)
//   当N=1024时，步长=4KB，每次访问B都miss（列方向不连续）
//
// 分块版本：
//   将矩阵分成BxB的小块
//   for ii(0,N,B): for jj(0,N,B): for kk(0,N,B):
//     for i(ii,ii+B): for j(jj,jj+B): for k(kk,kk+B):
//       C[i][j] += A[i][k] * B[k][j]
//
//   当B选择使得 3*B*B*sizeof(float) < L1大小 时，
//   A、B、C的子块都在L1中，内层循环几乎零miss

class MatrixBenchmark {
public:
    // 朴素矩阵乘法
    static void naiveMultiply(const float* A, const float* B, float* C, int n) {
        for (int i = 0; i < n; ++i) {
            for (int j = 0; j < n; ++j) {
                float sum = 0;
                for (int k = 0; k < n; ++k) {
                    sum += A[i * n + k] * B[k * n + j];
                }
                C[i * n + j] = sum;
            }
        }
    }

    // 分块矩阵乘法
    static void tiledMultiply(const float* A, const float* B, float* C,
                               int n, int blockSize) {
        // 清零C
        std::fill(C, C + n * n, 0.0f);

        for (int ii = 0; ii < n; ii += blockSize) {
            for (int jj = 0; jj < n; jj += blockSize) {
                for (int kk = 0; kk < n; kk += blockSize) {
                    // 处理BxB的小块
                    int iEnd = std::min(ii + blockSize, n);
                    int jEnd = std::min(jj + blockSize, n);
                    int kEnd = std::min(kk + blockSize, n);

                    for (int i = ii; i < iEnd; ++i) {
                        for (int k = kk; k < kEnd; ++k) {
                            float a = A[i * n + k];
                            for (int j = jj; j < jEnd; ++j) {
                                C[i * n + j] += a * B[k * n + j];
                            }
                        }
                    }
                }
            }
        }
    }

    static void benchmark(int n = 512) {
        std::vector<float> A(n * n), B(n * n), C(n * n);

        // 初始化
        for (int i = 0; i < n * n; ++i) {
            A[i] = static_cast<float>(i % 100) / 100.0f;
            B[i] = static_cast<float>((i * 7) % 100) / 100.0f;
        }

        std::cout << "===== Matrix Multiply Benchmark (N=" << n << ") =====\n";

        // 朴素版本
        auto start = std::chrono::high_resolution_clock::now();
        naiveMultiply(A.data(), B.data(), C.data(), n);
        auto end = std::chrono::high_resolution_clock::now();
        double naiveTime = std::chrono::duration<double, std::milli>(end - start).count();

        // 不同分块大小
        for (int bs : {16, 32, 64, 128}) {
            start = std::chrono::high_resolution_clock::now();
            tiledMultiply(A.data(), B.data(), C.data(), n, bs);
            end = std::chrono::high_resolution_clock::now();
            double tiledTime = std::chrono::duration<double, std::milli>(end - start).count();

            std::cout << "  Block=" << std::setw(3) << bs
                      << ": " << std::fixed << std::setprecision(1)
                      << tiledTime << " ms (speedup: "
                      << (naiveTime / tiledTime) << "x)\n";
        }

        std::cout << "  Naive:  " << naiveTime << " ms\n";
    }
};

// ──────────────────────────────────────
// Morton码（Z-order curve）
// ──────────────────────────────────────
//
// 将2D坐标(x,y)映射为1D索引，保持空间局部性。
//
// 原理：将x和y的二进制位交错（interleave）
//   x = 5 = 101₂
//   y = 3 = 011₂
//   Morton = 01_10_11₂ = 27₁₀
//
//   (x位用下划线标注: _1_0_1, y位: 0_1_1_)
//
// Z-order遍历路径：
//   ┌─┬─┬─┬─┐
//   │0│1│4│5│
//   ├─┼─┼─┼─┤
//   │2│3│6│7│
//   ├─┼─┼─┼─┤
//   │8│9│C│D│
//   ├─┼─┼─┼─┤
//   │A│B│E│F│
//   └─┴─┴─┴─┘
//
// 对DOD的意义：
//   粒子按Morton码排序后，空间相邻的粒子在内存中也相邻。
//   这使得邻居查询（碰撞检测、SPH模拟）变成近似顺序访问。

class MortonCode {
public:
    // 将x的位分散到偶数位
    static uint32_t expandBits(uint16_t v) {
        uint32_t x = v;
        x = (x | (x << 8)) & 0x00FF00FF;
        x = (x | (x << 4)) & 0x0F0F0F0F;
        x = (x | (x << 2)) & 0x33333333;
        x = (x | (x << 1)) & 0x55555555;
        return x;
    }

    // 从偶数位压缩回连续位
    static uint16_t compactBits(uint32_t x) {
        x &= 0x55555555;
        x = (x | (x >> 1)) & 0x33333333;
        x = (x | (x >> 2)) & 0x0F0F0F0F;
        x = (x | (x >> 4)) & 0x00FF00FF;
        x = (x | (x >> 8)) & 0x0000FFFF;
        return static_cast<uint16_t>(x);
    }

    // 2D坐标 → Morton码
    static uint32_t encode2D(uint16_t x, uint16_t y) {
        return expandBits(x) | (expandBits(y) << 1);
    }

    // Morton码 → 2D坐标
    static void decode2D(uint32_t code, uint16_t& x, uint16_t& y) {
        x = compactBits(code);
        y = compactBits(code >> 1);
    }

    // 3D坐标 → Morton码（用于粒子系统）
    static uint64_t encode3D(uint16_t x, uint16_t y, uint16_t z) {
        auto expand3 = [](uint16_t v) -> uint64_t {
            uint64_t x = v;
            x = (x | (x << 16)) & 0x030000FF;
            x = (x | (x << 8))  & 0x0300F00F;
            x = (x | (x << 4))  & 0x030C30C3;
            x = (x | (x << 2))  & 0x09249249;
            return x;
        };
        return expand3(x) | (expand3(y) << 1) | (expand3(z) << 2);
    }
};

// 基准测试：Morton码排序对邻居查询的加速
void benchmarkMortonLayout() {
    constexpr size_t N = 100000;  // 10万个粒子

    // 随机生成2D位置
    std::mt19937 rng(42);
    std::uniform_real_distribution<float> dist(0, 1000);

    struct Particle { float x, y; size_t originalIndex; };
    std::vector<Particle> particles(N);
    for (size_t i = 0; i < N; ++i) {
        particles[i] = {dist(rng), dist(rng), i};
    }

    // 查询：统计每个粒子的R范围内邻居数量
    constexpr float R = 10.0f;
    constexpr float R2 = R * R;

    // 方式1：随机布局遍历
    volatile int neighborCount = 0;
    auto start = std::chrono::high_resolution_clock::now();
    for (size_t i = 0; i < std::min(N, size_t(1000)); ++i) {
        for (size_t j = 0; j < N; ++j) {
            float dx = particles[i].x - particles[j].x;
            float dy = particles[i].y - particles[j].y;
            if (dx * dx + dy * dy < R2) ++neighborCount;
        }
    }
    auto end = std::chrono::high_resolution_clock::now();
    double randomTime = std::chrono::duration<double, std::milli>(end - start).count();

    // 方式2：按Morton码排序后遍历
    // 先将浮点坐标量化到uint16范围
    for (auto& p : particles) {
        uint16_t mx = static_cast<uint16_t>(p.x * 65.535f);
        uint16_t my = static_cast<uint16_t>(p.y * 65.535f);
        p.originalIndex = MortonCode::encode2D(mx, my);
    }

    std::sort(particles.begin(), particles.end(),
              [](const Particle& a, const Particle& b) {
                  return a.originalIndex < b.originalIndex;
              });

    neighborCount = 0;
    start = std::chrono::high_resolution_clock::now();
    for (size_t i = 0; i < std::min(N, size_t(1000)); ++i) {
        for (size_t j = 0; j < N; ++j) {
            float dx = particles[i].x - particles[j].x;
            float dy = particles[i].y - particles[j].y;
            if (dx * dx + dy * dy < R2) ++neighborCount;
        }
    }
    end = std::chrono::high_resolution_clock::now();
    double mortonTime = std::chrono::duration<double, std::milli>(end - start).count();

    std::cout << "===== Morton Layout Benchmark =====\n"
              << "Random layout:  " << randomTime << " ms\n"
              << "Morton layout:  " << mortonTime << " ms\n"
              << "Speedup:        " << (randomTime / mortonTime) << "x\n";
}

} // namespace dod::cache
```

---

#### 1.7 缓存性能分析工具实战

```
// ==========================================
// 缓存性能分析工具
// ==========================================
//
// "不测量就不优化"——DOD优化必须以数据驱动。
// 以下工具帮助量化缓存行为：

工具1：perf stat（Linux，硬件计数器，最推荐）
──────────────────────────────────────────────

  # 基础缓存计数器
  perf stat -e cache-references,cache-misses,\
    L1-dcache-loads,L1-dcache-load-misses,\
    L1-dcache-stores \
    ./my_program

  # LLC（Last Level Cache，通常L3）计数器
  perf stat -e LLC-loads,LLC-load-misses,\
    LLC-stores,LLC-store-misses \
    ./my_program

  # TLB计数器
  perf stat -e dTLB-loads,dTLB-load-misses,\
    dTLB-stores,dTLB-store-misses \
    ./my_program

  # 综合分析（推荐命令）
  perf stat -d -d ./my_program

  解读示例：
    1,234,567,890  L1-dcache-loads
      123,456,789  L1-dcache-load-misses  # 10.00% of all L1-dcache loads
    → L1缓存命中率90%
    → DOD优化目标：>95%

工具2：Valgrind/Cachegrind（跨平台，模拟器）
────────────────────────────────────────────

  # 运行cachegrind
  valgrind --tool=cachegrind ./my_program

  # 查看结果（按函数排序）
  cg_annotate cachegrind.out.<pid> --auto=yes

  优势：
  - 不需要root权限
  - 输出每个函数的精确miss数据
  - 可以看到每行代码的miss数据

  劣势：
  - 运行速度慢10-50倍
  - 使用模拟缓存参数（可能与实际硬件不同）

工具3：Intel VTune / AMD μProf
────────────────────────────────

  VTune命令：
  vtune -collect memory-access ./my_program

  功能：
  - 精确到源代码行的缓存分析
  - 可视化内存带宽使用
  - NUMA架构分析
  - 自动识别瓶颈并提供建议

工具4：Apple Instruments（macOS）
────────────────────────────────

  # 命令行方式
  xcrun xctrace record --template 'Counters' --launch ./my_program

  # 或使用Instruments GUI中的Counters模板
```

**缓存分析工具对比**

| 工具 | 平台 | 运行时开销 | 精度 | 学习曲线 | 推荐场景 |
|------|------|-----------|------|---------|---------|
| **perf stat** | Linux | ~1% | 硬件精确 | 中 | 快速概览，CI集成 |
| **cachegrind** | 跨平台 | 10-50x | 模拟 | 低 | 初学者，无root |
| **VTune** | Linux/Win | ~5% | 硬件精确 | 高 | 深度分析，生产代码 |
| **Instruments** | macOS | ~5% | 硬件精确 | 中 | Apple Silicon优化 |
| **perf record** | Linux | ~5% | 硬件精确 | 高 | 热点定位，火焰图 |

---

#### 1.8 本周练习任务

```
练习1：缓存层次探测器
──────────────────────
目标：构建一个程序，通过实验测量本机的L1/L2/L3大小和延迟

要求：
1. 创建不同大小的数组（1KB到128MB，每次翻倍）
2. 对每个大小，反复遍历并测量每元素平均延迟
3. 绘制"工作集大小 vs 延迟"曲线（可输出CSV供Excel绘图）
4. 标注观察到的缓存级别边界

验证：
- 应该观察到2-3个明显的延迟台阶
- 台阶位置应与sysfs/sysctl报告的缓存大小一致

练习2：缓存模拟器
────────────────
目标：扩展1.2节的CacheSimulator，支持可配置参数

要求：
1. 支持配置：缓存大小、行大小、关联度
2. 支持两种替换策略：LRU和Random
3. 输入：一系列地址访问（从文件或程序生成）
4. 输出：hit/miss统计，区分三种miss类型

验证：
- 用CacheSimulator分析AoS和SoA的访问模式
- SoA的模拟命中率应显著高于AoS

练习3：伪共享消除
────────────────
目标：消除多线程粒子更新中的伪共享

要求：
1. 实现一个4线程的粒子位置更新（x,y,z各由不同线程处理）
2. 先实现"不良版本"（数组紧邻，有伪共享）
3. 再实现"优化版本"（alignas对齐，消除伪共享）
4. 测量并对比两个版本的执行时间

验证：
- 优化版本应比不良版本快3-10倍
- 可用perf stat验证L1 cache miss减少

练习4：缓存友好链表
──────────────────
目标：实现unrolled linked list（展开链表）并与std::list比较

要求：
1. 每个节点包含N个元素（N使得节点大小=64字节=1缓存行）
2. 支持push_back、iteration、random insertion
3. 与std::list和std::vector做iteration性能对比

验证：
- iteration速度应该：vector > unrolled list >> std::list
- unrolled list应该达到vector速度的50-80%
```

---

#### 1.9 本周知识检验

```
思考题1：为什么L1缓存分为指令缓存和数据缓存，而L2开始是统一缓存？
         如果L2也分开设计，会有什么问题？

思考题2：高关联度（如16路组相联）的缓存查找需要比较16个Tag。
         这对延迟有什么影响？为什么L1通常只有8-12路？

思考题3：对DOD而言，Conflict Miss比Capacity Miss更难诊断。
         解释为什么，并给出一个触发Conflict Miss的具体代码示例。

思考题4：现代CPU的缓存行大小几乎都是64字节，而SIMD寄存器已经到了
         512位（AVX-512 = 64字节）。这两者的大小一致是巧合吗？

思考题5：游戏引擎普遍使用自定义内存分配器，而不是直接用malloc/new。
         从缓存角度解释这样做的三个具体好处。

实践题1：
  对于以下访问模式，手工计算32KB/8路/64B缓存的miss率：
  数组大小=256KB，步长=4096字节，连续访问10000次
  （提示：需要计算有多少不同的缓存行映射到同一组）

实践题2：
  设计一个粒子结构体，包含以下字段：
    position(3 float), velocity(3 float), color(4 uint8),
    life(float), maxLife(float), size(float), type(uint8),
    flags(uint8)
  要求：(a) 设计AoS版本，最小化padding浪费
        (b) 设计SoA版本
        (c) 分析"仅更新position"时两种布局的缓存行利用率
```

---

### 第二周：AoS vs SoA（35小时）

**学习目标**：
- [ ] 深入理解AoS和SoA的内存布局差异及其对缓存利用率的量化影响
- [ ] 掌握AoSoA（Array of Structure of Arrays）混合布局及其在SIMD宽度匹配中的优势
- [ ] 学会分析编译器自动向量化报告（-fopt-info-vec / -Rpass=loop-vectorize）
- [ ] 实现类型安全的SoA容器模板，支持编译时字段名访问
- [ ] 理解SoA布局对SIMD指令（SSE/AVX/AVX-512）的直接影响
- [ ] 掌握AoS到SoA的渐进式重构方法论
- [ ] 了解真实引擎（Unity DOTS、Unreal Mass Framework）中的数据布局选择

**阅读材料**：
- [ ] 《Game Engine Architecture》第3版 - Chapter 15: Runtime Gameplay Foundation Systems
- [ ] Intel ISPC（Implicit SPMD Program Compiler）用户指南 - AoSoA章节
- [ ] Unity DOTS架构文档 - ArchetypeChunk设计
- [ ] Godot引擎数据设计文档
- [ ] CppCon 2018：《OOP Is Dead, Long Live Data-oriented Design》- Stoyan Nikolov
- [ ] 《Foundations of Game Engine Development, Vol 1》- Eric Lengyel - 数据布局章节
- [ ] flecs ECS框架文档 - SoA存储设计

---

#### 核心概念

**数据布局对比**
```cpp
// AoS (Array of Structures) - 面向对象的自然方式
struct ParticleAoS {
    float x, y, z;       // 位置
    float vx, vy, vz;    // 速度
    float r, g, b, a;    // 颜色
    float life;          // 生命值
    float size;          // 大小
    // 48字节
};

std::vector<ParticleAoS> particlesAoS;  // [P1][P2][P3]...

// SoA (Structure of Arrays) - 数据导向的方式
struct ParticlesSoA {
    std::vector<float> x, y, z;       // 位置数组
    std::vector<float> vx, vy, vz;    // 速度数组
    std::vector<float> r, g, b, a;    // 颜色数组
    std::vector<float> life;          // 生命值数组
    std::vector<float> size;          // 大小数组

    void resize(size_t count) {
        x.resize(count); y.resize(count); z.resize(count);
        vx.resize(count); vy.resize(count); vz.resize(count);
        r.resize(count); g.resize(count); b.resize(count); a.resize(count);
        life.resize(count);
        size.resize(count);
    }
};

ParticlesSoA particlesSoA;
// x:    [x1, x2, x3, ...]
// y:    [y1, y2, y3, ...]
// ...
```

**内存访问模式对比**
```
AoS 更新位置：
内存布局: [x1,y1,z1,vx1,vy1,vz1,...][x2,y2,z2,vx2,vy2,vz2,...]
访问模式: ─○──○──○────────────────────○──○──○───────────────────
          x1 y1 z1                    x2 y2 z2
每个缓存行可能只用到部分数据，其他字段被无效加载

SoA 更新位置：
内存布局: [x1,x2,x3,x4,...][y1,y2,y3,y4,...][z1,z2,z3,z4,...]
访问模式: ─○──○──○──○──○──○──○──○──○──○──○──○──○──○──○──○───
          x1 x2 x3 x4 x5 x6 x7 x8 x9 ...
每个缓存行完全利用，无浪费
```

---

#### 2.1 内存布局的物理本质

```cpp
// ==========================================
// 从CPU的视角看数据布局
// ==========================================
//
// 上一周我们学习了缓存行：CPU每次从内存加载64字节。
// 这个事实直接决定了AoS和SoA的性能差异。
//
// 让我们用具体数字说话：
//
// 假设粒子有12个float字段（48字节），但某个系统只需要position（3 float = 12字节）
//
// AoS场景：
//   缓存行64字节，粒子48字节
//   一个缓存行只能完整放下1个粒子（还剩16字节放不下第2个）
//   实际只用到其中12字节（position）
//   缓存行利用率 = 12/64 = 18.75%
//   → 81.25%的内存带宽被浪费了！
//
// SoA场景：
//   x数组连续存储：[x0, x1, x2, ..., x15]
//   一个缓存行放16个float
//   全部16个x值都是需要的数据
//   缓存行利用率 = 64/64 = 100%
//
// 带宽放大因子（Bandwidth Amplification Factor, BAF）：
//   BAF = 加载的总字节数 / 实际需要的字节数
//   AoS: BAF = 48/12 = 4x（加载4倍于需要的数据）
//   SoA: BAF = 1x（完美利用）
//
// 当系统内存带宽是瓶颈时（现代CPU通常如此），
// BAF直接转化为性能倍数差异。

#include <cstddef>
#include <cstdint>
#include <iostream>
#include <iomanip>
#include <vector>

namespace dod::layout {

// 可视化数据在缓存行中的分布
template<typename T>
void visualizeCacheLineUsage(const T* data, size_t count,
                              size_t usefulOffset, size_t usefulSize,
                              const char* label) {
    constexpr size_t CACHE_LINE = 64;

    std::cout << "===== " << label << " =====\n";
    std::cout << "元素大小: " << sizeof(T) << " bytes, 每行有用: "
              << usefulSize << " bytes\n\n";

    uintptr_t baseAddr = reinterpret_cast<uintptr_t>(data);

    for (size_t i = 0; i < std::min(count, size_t(4)); ++i) {
        uintptr_t elemAddr = baseAddr + i * sizeof(T);
        size_t cacheLineNum = (elemAddr - baseAddr) / CACHE_LINE;
        size_t offsetInLine = (elemAddr - baseAddr) % CACHE_LINE;

        std::cout << "Element " << i << " @ offset " << (i * sizeof(T))
                  << " → cache line " << cacheLineNum
                  << ", offset " << offsetInLine << "\n";

        // 可视化缓存行内容
        std::cout << "  [";
        for (size_t b = 0; b < CACHE_LINE; ++b) {
            size_t globalOffset = cacheLineNum * CACHE_LINE + b;
            // 检查这个字节是否属于某个元素的"有用"部分
            bool isUseful = false;
            for (size_t e = 0; e < count; ++e) {
                size_t elemStart = e * sizeof(T) + usefulOffset;
                size_t elemEnd = elemStart + usefulSize;
                if (globalOffset >= elemStart && globalOffset < elemEnd) {
                    isUseful = true;
                    break;
                }
            }
            std::cout << (isUseful ? "█" : "░");
        }
        std::cout << "]\n";
    }

    // 计算利用率
    size_t totalBytes = count * sizeof(T);
    size_t usefulBytes = count * usefulSize;
    size_t cacheLines = (totalBytes + CACHE_LINE - 1) / CACHE_LINE;
    size_t loadedBytes = cacheLines * CACHE_LINE;

    std::cout << "\n利用率分析:\n"
              << "  总元素数:     " << count << "\n"
              << "  需要的数据:   " << usefulBytes << " bytes\n"
              << "  加载的数据:   " << loadedBytes << " bytes\n"
              << "  缓存行利用率: " << std::fixed << std::setprecision(1)
              << (100.0 * usefulBytes / loadedBytes) << "%\n"
              << "  带宽放大因子: " << std::setprecision(2)
              << (double(loadedBytes) / usefulBytes) << "x\n\n";
}

// 量化对比不同布局的带宽效率
void analyzeLayoutEfficiency() {
    struct AoSParticle {
        float x, y, z;        // 12B - 位置
        float vx, vy, vz;     // 12B - 速度
        float r, g, b, a;     // 16B - 颜色
        float life, size;     // 8B  - 其他
    };  // 48 bytes total

    std::cout << "========================================\n";
    std::cout << "  数据布局带宽效率分析\n";
    std::cout << "========================================\n\n";

    std::cout << "场景：更新100万粒子的位置（仅需要position + velocity）\n";
    std::cout << "需要的字段: x,y,z (12B) + vx,vy,vz (12B) = 24B/粒子\n\n";

    constexpr size_t N = 1'000'000;

    // AoS分析
    size_t aosLoadBytes = N * 64;  // 每个粒子至少加载一个缓存行
    size_t aosUsefulBytes = N * 24;
    double aosBaf = double(aosLoadBytes) / aosUsefulBytes;

    // SoA分析（6个float数组）
    size_t soaLoadBytes = N * 6 * sizeof(float);  // 精确加载需要的数组
    size_t soaUsefulBytes = soaLoadBytes;
    double soaBaf = double(soaLoadBytes) / soaUsefulBytes;

    std::cout << std::fixed << std::setprecision(2);
    std::cout << "  AoS:\n"
              << "    加载数据量:   " << (aosLoadBytes / (1024.0 * 1024)) << " MB\n"
              << "    有用数据量:   " << (aosUsefulBytes / (1024.0 * 1024)) << " MB\n"
              << "    带宽放大因子: " << aosBaf << "x\n\n";

    std::cout << "  SoA:\n"
              << "    加载数据量:   " << (soaLoadBytes / (1024.0 * 1024)) << " MB\n"
              << "    有用数据量:   " << (soaUsefulBytes / (1024.0 * 1024)) << " MB\n"
              << "    带宽放大因子: " << soaBaf << "x\n\n";

    std::cout << "  理论加速比: " << (aosBaf / soaBaf) << "x\n";
    std::cout << "  （实际加速比受到编译器向量化、指令级并行等因素影响）\n\n";
}

} // namespace dod::layout
```

**AoS vs SoA 缓存未命中率量化分析**

```
步幅（Stride）对缓存行为的影响——当字段数量变化时：

假设每个字段4字节(float)，缓存行64字节，共N=10000个实体

┌─ AoS: 访问1个字段（如仅x），结构体有F个字段 ─────────────────────────┐
│                                                                        │
│  F=2  (8B/实体):  stride=8B,  每缓存行读8实体, 利用率=4/8 = 50%       │
│  F=4  (16B/实体): stride=16B, 每缓存行读4实体, 利用率=4/16 = 25%      │
│  F=8  (32B/实体): stride=32B, 每缓存行读2实体, 利用率=4/32 = 12.5%    │
│  F=16 (64B/实体): stride=64B, 每缓存行读1实体, 利用率=4/64 = 6.25%    │
│                                                                        │
│  内存访问示意 (F=8, stride=32B):                                       │
│  [████....████....████....████....][████....████....████....████....]   │
│   ↑用到  ↑浪费   ↑用到  ↑浪费      缓存行1              缓存行2       │
└────────────────────────────────────────────────────────────────────────┘

┌─ SoA: 访问1个字段（如仅x），无论总共有多少字段 ───────────────────────┐
│                                                                        │
│  x数组: [x0,x1,x2,...,x15][x16,...,x31]...                            │
│  每缓存行读16个float，利用率恒为100%                                   │
│                                                                        │
│  内存访问示意:                                                         │
│  [████████████████████████████████████████████████████████████████]    │
│   x0  x1  x2  x3  x4  x5  x6  x7  x8  x9  x10 x11 x12 x13 x14 x15 │
│   ↑全部有用                                                           │
└────────────────────────────────────────────────────────────────────────┘

┌─ AoS: 访问K个字段，结构体有F个字段 ──────────────────────────────────┐
│                                                                        │
│  利用率 = K/F（当 F*4 >= 64 时）                                       │
│  利用率 = min(1.0, K*4 / 64 * ceil(64/(F*4)))（当 F*4 < 64 时）       │
│                                                                        │
│  关键洞察：只有当 K == F（访问所有字段）时，AoS利用率才接近100%        │
│  而在真实系统中，大多数操作只需要少量字段                              │
└────────────────────────────────────────────────────────────────────────┘
```

```cpp
// ==========================================
// AoS vs SoA 缓存未命中率量化分析
// ==========================================
//
// 上面的理论分析告诉我们：AoS的缓存利用率随着访问字段比例(K/F)线性下降。
// 但理论和实测之间总有差距——预取器、TLB、编译器优化都会影响结果。
// 这个基准测试量化测量不同字段访问模式下的真实带宽效率。

#include <vector>
#include <chrono>
#include <iostream>
#include <iomanip>
#include <cstring>
#include <numeric>
#include <cmath>

namespace dod::layout {

// 一个拥有16个float字段的实体——模拟真实游戏对象的字段数量
struct Entity16Fields {
    float f[16];  // 共64字节，恰好一个缓存行
};

// SoA版本：16个独立数组
struct Entity16SoA {
    std::vector<float> fields[16];

    void resize(size_t n) {
        for (auto& f : fields) f.resize(n);
    }
};

class CacheMissRateAnalyzer {
    static constexpr size_t N = 1'000'000;  // 100万实体
    static constexpr int ITERS = 20;

    std::vector<Entity16Fields> aos_;
    Entity16SoA soa_;

public:
    CacheMissRateAnalyzer() {
        aos_.resize(N);
        soa_.resize(N);

        // 填充测试数据——确保数据不是零（避免编译器优化掉计算）
        for (size_t i = 0; i < N; ++i) {
            for (int f = 0; f < 16; ++f) {
                float val = static_cast<float>(i * 16 + f) * 0.001f;
                aos_[i].f[f] = val;
                soa_.fields[f][i] = val;
            }
        }
    }

    // 测试AoS访问K个字段的吞吐量
    // 为什么用volatile累加器？防止编译器发现结果未使用而整体消除循环
    double benchAoS(int fieldsAccessed) {
        volatile float sink = 0;
        auto start = std::chrono::high_resolution_clock::now();

        for (int iter = 0; iter < ITERS; ++iter) {
            float sum = 0;
            for (size_t i = 0; i < N; ++i) {
                for (int f = 0; f < fieldsAccessed; ++f) {
                    sum += aos_[i].f[f];
                }
            }
            sink = sum;
        }

        auto end = std::chrono::high_resolution_clock::now();
        return std::chrono::duration<double, std::milli>(end - start).count() / ITERS;
    }

    // 测试SoA访问K个字段的吞吐量
    double benchSoA(int fieldsAccessed) {
        volatile float sink = 0;
        auto start = std::chrono::high_resolution_clock::now();

        for (int iter = 0; iter < ITERS; ++iter) {
            float sum = 0;
            for (int f = 0; f < fieldsAccessed; ++f) {
                const float* data = soa_.fields[f].data();
                for (size_t i = 0; i < N; ++i) {
                    sum += data[i];
                }
            }
            sink = sum;
        }

        auto end = std::chrono::high_resolution_clock::now();
        return std::chrono::duration<double, std::milli>(end - start).count() / ITERS;
    }

    void runFullAnalysis() {
        std::cout << "===== AoS vs SoA 缓存利用率量化分析 =====\n";
        std::cout << "实体数量: " << N << ", 每实体16个float字段(64字节)\n\n";

        // 表头
        std::cout << std::left
                  << std::setw(10) << "访问字段"
                  << std::setw(14) << "AoS(ms)"
                  << std::setw(14) << "SoA(ms)"
                  << std::setw(12) << "加速比"
                  << std::setw(16) << "理论利用率AoS"
                  << std::setw(16) << "理论利用率SoA"
                  << std::setw(16) << "实测带宽比"
                  << "\n";
        std::cout << std::string(98, '-') << "\n";

        int testCases[] = {1, 2, 4, 8, 16};
        for (int k : testCases) {
            double aosMs = benchAoS(k);
            double soaMs = benchSoA(k);
            double speedup = aosMs / soaMs;

            // 理论缓存利用率
            // AoS: 结构体64字节恰好占满一个缓存行，利用率 = K/16
            double aosUtil = static_cast<double>(k) / 16.0;
            // SoA: 总是100%（连续访问）
            double soaUtil = 1.0;

            // 实测带宽比 = SoA时间/AoS时间（反映实际利用率差异）
            double measuredRatio = soaMs / aosMs;

            std::cout << std::left
                      << std::setw(10) << k
                      << std::setw(14) << std::fixed << std::setprecision(2) << aosMs
                      << std::setw(14) << soaMs
                      << std::setw(12) << std::setprecision(2) << speedup << "x"
                      << std::setw(16) << std::setprecision(1) << (aosUtil * 100) << "%"
                      << std::setw(16) << (soaUtil * 100) << "%"
                      << std::setw(16) << std::setprecision(2) << measuredRatio
                      << "\n";
        }

        std::cout << "\n分析要点：\n"
                  << "  1. 访问1个字段时AoS浪费93.75%带宽，SoA加速比最高（通常8-16x）\n"
                  << "  2. 访问所有16字段时两者趋于一致（AoS甚至可能略快，因空间局部性更好）\n"
                  << "  3. 实测加速比通常低于理论值，因为硬件预取器能部分补偿AoS的非连续访问\n"
                  << "  4. 当K/F > 0.5时，应考虑AoSoA或干脆保留AoS布局\n";
    }
};

void demonstrateCacheMissRateAnalysis() {
    CacheMissRateAnalyzer analyzer;
    analyzer.runFullAnalysis();
}

} // namespace dod::layout
```

---

#### 2.2 AoSoA：混合布局的最佳平衡

```cpp
// ==========================================
// AoSoA（Array of Structure of Arrays）
// ==========================================
//
// 纯SoA虽然对SIMD友好，但有一个问题：
//   当同时访问多个字段时（如x和vx），它们在内存中可能相距很远。
//   对于100万粒子的SoA：
//     x数组起始地址: 0x1000_0000
//     vx数组起始地址: 0x1000_0000 + 4MB = 0x1040_0000
//   → 相距4MB！TLB和L2缓存可能无法同时覆盖两者。
//
// AoSoA是一种折中：
//   将数据分成"块"（Chunk），每块包含N个元素的SoA
//   N通常等于SIMD寄存器宽度（AVX = 8, AVX-512 = 16）
//
//   AoSoA-8 (AVX) 布局：
//   ┌──────────────────────────────────────────────┐
//   │ Block 0:                                     │
//   │   x[0..7] y[0..7] z[0..7] vx[0..7] ...      │
//   ├──────────────────────────────────────────────┤
//   │ Block 1:                                     │
//   │   x[8..15] y[8..15] z[8..15] vx[8..15] ...  │
//   ├──────────────────────────────────────────────┤
//   │ ...                                          │
//   └──────────────────────────────────────────────┘
//
//   优势：
//   1. 每个Block的所有字段在内存中连续 → 好的空间局部性
//   2. 每个字段恰好SIMD宽度个元素 → 直接_mm256_load_ps
//   3. 块内SoA布局 → SIMD友好
//   4. 块间AoS布局 → 多字段访问时在同一缓存区域

#include <vector>
#include <chrono>
#include <iostream>
#include <cmath>
#include <algorithm>

#ifdef __AVX__
#include <immintrin.h>
#endif

namespace dod::layout {

// SIMD宽度常量
#ifdef __AVX512F__
constexpr size_t SIMD_WIDTH = 16;
#elif defined(__AVX__)
constexpr size_t SIMD_WIDTH = 8;
#else
constexpr size_t SIMD_WIDTH = 4;  // SSE
#endif

// AoSoA粒子块——每块包含SIMD_WIDTH个粒子
struct alignas(64) ParticleBlock {
    float x[SIMD_WIDTH];
    float y[SIMD_WIDTH];
    float z[SIMD_WIDTH];
    float vx[SIMD_WIDTH];
    float vy[SIMD_WIDTH];
    float vz[SIMD_WIDTH];
    float life[SIMD_WIDTH];
};

class AoSoAParticles {
    std::vector<ParticleBlock> blocks_;
    size_t count_ = 0;

public:
    void resize(size_t n) {
        count_ = n;
        blocks_.resize((n + SIMD_WIDTH - 1) / SIMD_WIDTH);
    }

    size_t size() const { return count_; }

#ifdef __AVX__
    // AVX优化的位置更新
    void updatePositions(float dt) {
        const __m256 vdt = _mm256_set1_ps(dt);

        for (auto& block : blocks_) {
            // 加载——所有数据在同一块内，空间局部性优秀
            __m256 x = _mm256_load_ps(block.x);
            __m256 y = _mm256_load_ps(block.y);
            __m256 z = _mm256_load_ps(block.z);
            __m256 velX = _mm256_load_ps(block.vx);
            __m256 velY = _mm256_load_ps(block.vy);
            __m256 velZ = _mm256_load_ps(block.vz);

            // 计算
            x = _mm256_fmadd_ps(velX, vdt, x);
            y = _mm256_fmadd_ps(velY, vdt, y);
            z = _mm256_fmadd_ps(velZ, vdt, z);

            // 存储
            _mm256_store_ps(block.x, x);
            _mm256_store_ps(block.y, y);
            _mm256_store_ps(block.z, z);
        }
    }
#endif

    // 标量版本
    void updatePositionsScalar(float dt) {
        for (auto& block : blocks_) {
            for (size_t i = 0; i < SIMD_WIDTH; ++i) {
                block.x[i] += block.vx[i] * dt;
                block.y[i] += block.vy[i] * dt;
                block.z[i] += block.vz[i] * dt;
            }
        }
    }
};

// 三种布局的性能对比基准测试（包含原始AoS和SoA的对比代码，见上文核心概念部分）

} // namespace dod::layout
```

**三种数据布局对比**

| 维度 | AoS | SoA | AoSoA |
|------|-----|-----|-------|
| **缓存行利用率（单字段）** | 低（18-50%） | 高（100%） | 高（100%） |
| **缓存行利用率（多字段）** | 高（>80%） | 中（取决于数组距离） | 高（块内连续） |
| **SIMD友好度** | 差（需要gather） | 优秀（直接load） | 优秀（对齐load） |
| **空间局部性（多字段）** | 优秀（同一对象） | 差（不同数组） | 良好（同一块内） |
| **代码可读性** | 优秀 | 一般 | 中等 |
| **随机单元素访问** | 优秀（O(1)一次load） | 差（多次load） | 中等 |
| **适用场景** | 通用业务逻辑 | 大规模数值计算 | SIMD密集型计算 |
| **真实使用者** | 大多数C++程序 | ECS引擎、物理引擎 | Intel ISPC、Unity DOTS |

---

#### 2.3 编译器自动向量化分析

```cpp
// ==========================================
// 编译器向量化：让编译器为你写SIMD
// ==========================================
//
// 现代编译器（GCC、Clang、MSVC）能够自动将标量循环转换为SIMD指令。
// 但这需要满足严格的条件。SoA布局天然满足大部分条件，
// 而AoS布局常常阻止向量化。
//
// 编译器向量化的关键要求：
//   1. 内存访问必须连续（contiguous）或可预测（strided）
//   2. 循环迭代间无数据依赖
//   3. 循环次数在编译时已知或可在运行时确定
//   4. 无函数调用（除非inline或向量化版本可用）
//   5. 无条件分支（或可转换为SIMD mask操作）
//
// SoA天然满足要求1：每个数组元素连续存储。
// AoS违反要求1：同一字段的连续元素间有stride。
//
// 编译器报告命令：
//   GCC:   -O3 -march=native -fopt-info-vec-optimized -fopt-info-vec-missed
//   Clang: -O3 -march=native -Rpass=loop-vectorize -Rpass-missed=loop-vectorize
//   MSVC:  /O2 /arch:AVX2 /Qvec-report:2

namespace dod::layout {

// ──────────────────────────────────────
// AoS版本——编译器通常无法向量化
// ──────────────────────────────────────

struct SimpleParticle {
    float x, y, z;
    float vx, vy, vz;
};

// 编译器报告（GCC）：
// "loop not vectorized: not suitable for gather/scatter"
// "loop not vectorized: cannot compute loop trip count"
void updateAoS_WontVectorize(SimpleParticle* particles, size_t n, float dt) {
    for (size_t i = 0; i < n; ++i) {
        particles[i].x += particles[i].vx * dt;
        particles[i].y += particles[i].vy * dt;
        particles[i].z += particles[i].vz * dt;
    }
    // 内存访问模式：stride = sizeof(SimpleParticle) = 24 bytes
    // 编译器无法高效向量化非unit-stride访问
}

// ──────────────────────────────────────
// SoA版本——编译器自动向量化
// ──────────────────────────────────────

// 编译器报告（GCC）：
// "loop vectorized using 256 bit vectors"
void updateSoA_AutoVectorized(float* __restrict__ x,
                               const float* __restrict__ vx,
                               size_t n, float dt) {
    for (size_t i = 0; i < n; ++i) {
        x[i] += vx[i] * dt;
    }
    // __restrict__ 告诉编译器x和vx不重叠
    // unit-stride访问：完美向量化
    // 编译器自动生成：_mm256_fmadd_ps
}

// ──────────────────────────────────────
// 帮助编译器向量化的技巧
// ──────────────────────────────────────

// 技巧1：使用 __restrict__ 消除别名（aliasing）
// 没有 __restrict__，编译器不确定 x 和 vx 是否指向同一内存
// 因此不敢重排指令

// 技巧2：使用 #pragma 提示（GCC/Clang）
void updateWithPragma(float* x, const float* vx, size_t n, float dt) {
#pragma GCC ivdep  // 忽略向量依赖检查（你保证安全）
    for (size_t i = 0; i < n; ++i) {
        x[i] += vx[i] * dt;
    }
}

// 技巧3：对齐假设 __builtin_assume_aligned
void updateAligned(float* x, const float* vx, size_t n, float dt) {
    float* ax = static_cast<float*>(__builtin_assume_aligned(x, 64));
    const float* avx = static_cast<const float*>(__builtin_assume_aligned(vx, 64));

    for (size_t i = 0; i < n; ++i) {
        ax[i] += avx[i] * dt;
    }
    // 编译器可以生成对齐的load/store指令（_mm256_load_ps 而非 _mm256_loadu_ps）
}

} // namespace dod::layout
```

```
编译器向量化报告解读示例：

$ g++ -O3 -march=native -fopt-info-vec-all particle_update.cpp

成功向量化（SoA）：
  particle_update.cpp:42:5: optimized: loop vectorized using 32 byte vectors
  → 32 byte = 256 bit = AVX，每次处理8个float

向量化失败（AoS）：
  particle_update.cpp:15:5: missed: couldn't vectorize loop
  particle_update.cpp:15:5: missed: not vectorized: not suitable for gather load
  → 编译器发现了non-unit stride访问，放弃向量化

$ clang++ -O3 -march=native -Rpass=loop-vectorize -Rpass-missed=loop-vectorize

  remark: loop vectorized (vectorization width: 8, interleaved count: 4)
  → 不仅向量化了，还做了4倍循环展开（每次迭代处理32个元素）
```

---

#### 2.4 SIMD指令与SoA的天然契合

```cpp
// ==========================================
// SIMD：为什么SoA是SIMD的"母语"
// ==========================================
//
// SIMD（Single Instruction, Multiple Data）指令集一览：
//   SSE:     128位 = 4个float
//   AVX:     256位 = 8个float
//   AVX-512: 512位 = 16个float
//   ARM NEON: 128位 = 4个float
//
// SIMD的核心操作是"一条指令处理N个数据"。
// 这要求N个数据在内存中连续存放。
//
// SoA布局：x数组 = [x0, x1, x2, ..., x7, ...]
//   _mm256_load_ps(&x[0]) → 一条指令加载8个x值 ✓
//
// AoS布局：[x0,y0,z0,...,x1,y1,z1,...,x2,y2,z2,...]
//   要加载8个x值需要gather指令：_mm256_i32gather_ps
//   → gather指令比连续load慢3-4倍！
//
// 这就是为什么所有高性能数值计算代码都使用SoA或AoSoA。

#ifdef __AVX__
#include <immintrin.h>
#endif

#include <cmath>
#include <vector>
#include <chrono>
#include <iostream>

namespace dod::layout {

// ──────────────────────────────────────
// SoA SIMD：距离计算（高效）
// ──────────────────────────────────────

#ifdef __AVX__
// 计算每个粒子到原点的距离
// SoA版本：每条指令处理8个粒子
void computeDistancesSoA_AVX(const float* x, const float* y, const float* z,
                              float* distances, size_t count) {
    size_t i = 0;
    for (; i + 8 <= count; i += 8) {
        // 连续加载8个x值——一条指令
        __m256 vx = _mm256_load_ps(&x[i]);
        __m256 vy = _mm256_load_ps(&y[i]);
        __m256 vz = _mm256_load_ps(&z[i]);

        // 计算 x*x + y*y + z*z
        __m256 dist2 = _mm256_mul_ps(vx, vx);
        dist2 = _mm256_fmadd_ps(vy, vy, dist2);
        dist2 = _mm256_fmadd_ps(vz, vz, dist2);

        // 开平方
        __m256 dist = _mm256_sqrt_ps(dist2);

        // 连续存储8个距离——一条指令
        _mm256_store_ps(&distances[i], dist);
    }

    // 处理剩余
    for (; i < count; ++i) {
        distances[i] = std::sqrt(x[i]*x[i] + y[i]*y[i] + z[i]*z[i]);
    }
}

// ──────────────────────────────────────
// AoS SIMD：距离计算（低效，需要gather）
// ──────────────────────────────────────

struct ParticleForGather {
    float x, y, z;
    float padding;  // 对齐到16字节
};

// AoS版本：需要gather指令，性能差
void computeDistancesAoS_AVX(const ParticleForGather* particles,
                              float* distances, size_t count) {
    // 构造索引：每个粒子的x的偏移
    // stride = sizeof(ParticleForGather) / sizeof(float) = 4
    const __m256i vindex = _mm256_setr_epi32(0, 4, 8, 12, 16, 20, 24, 28);
    const float* base = reinterpret_cast<const float*>(particles);

    size_t i = 0;
    for (; i + 8 <= count; i += 8) {
        const float* ptr = base + i * 4;

        // gather: 从不连续的内存位置收集数据——慢！
        __m256 vx = _mm256_i32gather_ps(ptr, vindex, 4);
        __m256 vy = _mm256_i32gather_ps(ptr + 1, vindex, 4);
        __m256 vz = _mm256_i32gather_ps(ptr + 2, vindex, 4);

        __m256 dist2 = _mm256_mul_ps(vx, vx);
        dist2 = _mm256_fmadd_ps(vy, vy, dist2);
        dist2 = _mm256_fmadd_ps(vz, vz, dist2);

        __m256 dist = _mm256_sqrt_ps(dist2);
        _mm256_store_ps(&distances[i], dist);
    }

    for (; i < count; ++i) {
        const auto& p = particles[i];
        distances[i] = std::sqrt(p.x*p.x + p.y*p.y + p.z*p.z);
    }
}
#endif

// SIMD指令性能对比
void benchmarkSIMDLayouts() {
    constexpr size_t N = 1'000'000;

    // 准备SoA数据
    std::vector<float> x(N), y(N), z(N), distSoA(N);
    for (size_t i = 0; i < N; ++i) {
        x[i] = static_cast<float>(i);
        y[i] = static_cast<float>(i * 2);
        z[i] = static_cast<float>(i * 3);
    }

    // 准备AoS数据
    struct P { float x, y, z, pad; };
    std::vector<P> particles(N);
    std::vector<float> distAoS(N);
    for (size_t i = 0; i < N; ++i) {
        particles[i] = {x[i], y[i], z[i], 0};
    }

#ifdef __AVX__
    // SoA SIMD
    auto start = std::chrono::high_resolution_clock::now();
    for (int iter = 0; iter < 100; ++iter) {
        computeDistancesSoA_AVX(x.data(), y.data(), z.data(), distSoA.data(), N);
    }
    auto end = std::chrono::high_resolution_clock::now();
    double soaTime = std::chrono::duration<double, std::milli>(end - start).count();

    // AoS SIMD (gather)
    start = std::chrono::high_resolution_clock::now();
    for (int iter = 0; iter < 100; ++iter) {
        computeDistancesAoS_AVX(
            reinterpret_cast<const ParticleForGather*>(particles.data()),
            distAoS.data(), N);
    }
    end = std::chrono::high_resolution_clock::now();
    double aosTime = std::chrono::duration<double, std::milli>(end - start).count();

    std::cout << "===== SIMD Layout Benchmark =====\n"
              << "SoA + contiguous load: " << soaTime << " ms\n"
              << "AoS + gather:          " << aosTime << " ms\n"
              << "SoA speedup:           " << (aosTime / soaTime) << "x\n";
#endif
}

} // namespace dod::layout
```

**SIMD加载指令性能对比**

| 指令 | 操作 | 吞吐量(cycles) | 延迟(cycles) | 适用布局 |
|------|------|---------------|-------------|---------|
| `_mm256_load_ps` | 连续加载8个float | 0.5 | 5 | SoA |
| `_mm256_loadu_ps` | 非对齐连续加载 | 0.5 | 5 | SoA（未对齐） |
| `_mm256_i32gather_ps` | 按索引收集8个float | 4-8 | 12-20 | AoS |
| `_mm256_broadcast_ss` | 广播1个float到8个位置 | 0.5 | 5 | 常量 |

**Gather vs Contiguous: 性能深度对比**

```
Gather指令内部执行流程——为什么它比连续加载慢这么多？

┌─ _mm256_load_ps (连续加载) ──────────────────────────────────────────┐
│                                                                       │
│  请求:  从地址P连续加载8个float                                       │
│                                                                       │
│  内存:  [P+0 ][P+4 ][P+8 ][P+12][P+16][P+20][P+24][P+28]           │
│          ↓     ↓     ↓     ↓     ↓     ↓     ↓     ↓               │
│  寄存器: [lane0|lane1|lane2|lane3|lane4|lane5|lane6|lane7]           │
│                                                                       │
│  微操作: 1个load uop → 1次缓存访问 → 完成                            │
│  访问缓存行数: 1（最多2，跨行时）                                     │
└───────────────────────────────────────────────────────────────────────┘

┌─ _mm256_i32gather_ps (收集加载) ─────────────────────────────────────┐
│                                                                       │
│  请求:  从base+index[i]*scale加载8个float，index各不相同              │
│                                                                       │
│  内存:  ....[P+0]........[P+48]....[P+96]....[P+144]....            │
│              ↓             ↓         ↓          ↓                     │
│  内存:  ....[P+192]...[P+240].[P+288].[P+336]...                    │
│              ↓           ↓       ↓        ↓                           │
│  寄存器: [lane0|lane1|lane2|lane3|lane4|lane5|lane6|lane7]           │
│                                                                       │
│  Haswell: 分解为多个独立load uop                                      │
│    → 每个lane产生1个load uop，共8个uop                               │
│    → 序列化到2个load端口，需要4个周期的端口压力                       │
│    → 加上地址计算、合并开销 → 总延迟12-20周期                        │
│                                                                       │
│  Skylake: 微架构改进                                                  │
│    → gather硬件支持改进，可以合并相同缓存行的请求                     │
│    → 吞吐量约5周期，延迟约15周期                                      │
│                                                                       │
│  Ice Lake+: 进一步优化                                                │
│    → 更高效的gather单元，吞吐量约4周期                                │
│    → 但仍然比连续加载慢8x以上                                        │
└───────────────────────────────────────────────────────────────────────┘
```

**各微架构Gather指令吞吐量对比**

| 微架构 | `vgatherdps ymm` 吞吐量 | `vmovaps ymm` 吞吐量 | Gather/Load 比 | 年份 |
|--------|------------------------|---------------------|----------------|------|
| Haswell | ~8 cycles | 0.5 cycles | 16x | 2013 |
| Broadwell | ~7 cycles | 0.5 cycles | 14x | 2014 |
| Skylake | ~5 cycles | 0.5 cycles | 10x | 2015 |
| Ice Lake | ~4 cycles | 0.5 cycles | 8x | 2019 |
| Zen 3 | ~6 cycles | 0.5 cycles | 12x | 2020 |
| Sapphire Rapids | ~4 cycles | 0.5 cycles | 8x | 2023 |

```cpp
// ==========================================
// Gather vs Contiguous: 性能深度对比
// ==========================================
//
// 这个基准测试对比三种从AoS数据中提取单字段的策略：
//   1. Gather指令：直接用硬件gather从AoS中收集
//   2. Shuffle转置：先加载连续块，再用shuffle指令重排
//   3. SoA连续加载：数据预先按SoA布局，直接连续读取
//
// 为什么要测试shuffle方案？在某些场景下，如果数据已经在缓存中
// （比如需要处理多个字段），先连续加载再shuffle可能比gather更快。

#include <immintrin.h>
#include <vector>
#include <chrono>
#include <iostream>
#include <iomanip>
#include <cmath>

namespace dod::layout {

struct Vec4 {
    float x, y, z, w;  // 16字节对齐的AoS结构
};

// 方法1: Gather——从AoS中直接用gather指令收集x字段
// 优点：代码简洁，无需数据重组
// 缺点：硬件层面是多个独立load，吞吐量差
#ifdef __AVX2__
float sumX_Gather(const Vec4* data, size_t count) {
    __m256 acc = _mm256_setzero_ps();
    const __m256i vindex = _mm256_setr_epi32(0, 4, 8, 12, 16, 20, 24, 28);
    const float* base = reinterpret_cast<const float*>(data);

    size_t i = 0;
    for (; i + 8 <= count; i += 8) {
        // scale=4 因为索引单位是float（4字节）
        __m256 gathered = _mm256_i32gather_ps(base + i * 4, vindex, 4);
        acc = _mm256_add_ps(acc, gathered);
    }

    // 水平归约
    float result[8];
    _mm256_storeu_ps(result, acc);
    float sum = 0;
    for (int j = 0; j < 8; ++j) sum += result[j];
    for (; i < count; ++i) sum += data[i].x;
    return sum;
}

// 方法2: Shuffle转置——加载4个连续Vec4，用shuffle提取所有x
// 原理：4个Vec4 = [x0,y0,z0,w0, x1,y1,z1,w1, x2,y2,z2,w2, x3,y3,z3,w3]
// 通过unpacklo/unpackhi + shuffle可提取 [x0,x1,x2,x3]
// 对于AVX版本一次处理8个Vec4
float sumX_Shuffle(const Vec4* data, size_t count) {
    __m256 acc = _mm256_setzero_ps();

    size_t i = 0;
    for (; i + 8 <= count; i += 8) {
        const float* p = reinterpret_cast<const float*>(&data[i]);
        // 加载8个Vec4 = 128字节 = 2个缓存行（全部连续，对缓存友好）
        __m256 v0 = _mm256_loadu_ps(p);       // x0,y0,z0,w0, x1,y1,z1,w1
        __m256 v1 = _mm256_loadu_ps(p + 8);   // x2,y2,z2,w2, x3,y3,z3,w3
        __m256 v2 = _mm256_loadu_ps(p + 16);  // x4,y4,z4,w4, x5,y5,z5,w5
        __m256 v3 = _mm256_loadu_ps(p + 24);  // x6,y6,z6,w6, x7,y7,z7,w7

        // 4x8转置中提取第一行（所有x）
        // _MM_SHUFFLE(3,2,1,0) 选择每个128位lane中的第0个float
        __m256 xy02 = _mm256_shuffle_ps(v0, v1, _MM_SHUFFLE(0,0,0,0));
        __m256 xy46 = _mm256_shuffle_ps(v2, v3, _MM_SHUFFLE(0,0,0,0));
        __m256 xs = _mm256_blend_ps(
            _mm256_permute2f128_ps(xy02, xy46, 0x20),
            _mm256_permute2f128_ps(xy02, xy46, 0x31),
            0b11001100
        );
        acc = _mm256_add_ps(acc, xs);
    }

    float result[8];
    _mm256_storeu_ps(result, acc);
    float sum = 0;
    for (int j = 0; j < 8; ++j) sum += result[j];
    for (; i < count; ++i) sum += data[i].x;
    return sum;
}
#endif

// 方法3: SoA连续加载——基准线，理论最优
float sumX_Contiguous(const float* x, size_t count) {
#ifdef __AVX__
    __m256 acc = _mm256_setzero_ps();
    size_t i = 0;
    for (; i + 8 <= count; i += 8) {
        acc = _mm256_add_ps(acc, _mm256_loadu_ps(&x[i]));
    }
    float result[8];
    _mm256_storeu_ps(result, acc);
    float sum = 0;
    for (int j = 0; j < 8; ++j) sum += result[j];
    for (; i < count; ++i) sum += x[i];
    return sum;
#else
    float sum = 0;
    for (size_t i = 0; i < count; ++i) sum += x[i];
    return sum;
#endif
}

void benchmarkGatherVsContiguous() {
    constexpr size_t N = 2'000'000;
    constexpr int ITERS = 50;

    // 准备AoS数据
    std::vector<Vec4> aos(N);
    for (size_t i = 0; i < N; ++i) {
        aos[i] = {static_cast<float>(i) * 0.1f, 0.f, 0.f, 0.f};
    }

    // 准备SoA数据
    std::vector<float> soaX(N);
    for (size_t i = 0; i < N; ++i) soaX[i] = aos[i].x;

    volatile float sink = 0;

    // 基准: SoA连续加载
    auto t0 = std::chrono::high_resolution_clock::now();
    for (int iter = 0; iter < ITERS; ++iter) {
        sink = sumX_Contiguous(soaX.data(), N);
    }
    auto t1 = std::chrono::high_resolution_clock::now();
    double contiguousMs = std::chrono::duration<double, std::milli>(t1 - t0).count() / ITERS;

#ifdef __AVX2__
    // Gather
    t0 = std::chrono::high_resolution_clock::now();
    for (int iter = 0; iter < ITERS; ++iter) {
        sink = sumX_Gather(aos.data(), N);
    }
    t1 = std::chrono::high_resolution_clock::now();
    double gatherMs = std::chrono::duration<double, std::milli>(t1 - t0).count() / ITERS;

    // Shuffle转置
    t0 = std::chrono::high_resolution_clock::now();
    for (int iter = 0; iter < ITERS; ++iter) {
        sink = sumX_Shuffle(aos.data(), N);
    }
    t1 = std::chrono::high_resolution_clock::now();
    double shuffleMs = std::chrono::duration<double, std::milli>(t1 - t0).count() / ITERS;

    std::cout << "===== Gather vs Contiguous 性能对比 =====\n"
              << "数据量: " << N << " 个Vec4 (x,y,z,w)\n"
              << "任务: 对所有x字段求和\n\n"
              << std::fixed << std::setprecision(3)
              << "  SoA连续加载:     " << contiguousMs << " ms (基准线)\n"
              << "  AoS Gather:      " << gatherMs << " ms ("
              << std::setprecision(1) << (gatherMs / contiguousMs) << "x slower)\n"
              << "  AoS Shuffle转置: " << shuffleMs << " ms ("
              << (shuffleMs / contiguousMs) << "x slower)\n\n"
              << "结论：\n"
              << "  - Gather比连续加载慢约8-16x（取决于微架构）\n"
              << "  - Shuffle方案介于两者之间，当需要访问多个字段时更有价值\n"
              << "  - 如果只访问1个字段，SoA布局的优势无可替代\n"
              << "  - 如果必须用AoS且需要SIMD，优先考虑AoSoA而非gather\n";
#else
    std::cout << "需要AVX2支持才能运行gather基准测试\n";
    std::cout << "SoA连续加载: " << contiguousMs << " ms\n";
#endif
}

} // namespace dod::layout
```

---

#### 2.5 类型安全的SoA容器设计

```cpp
// ==========================================
// 类型安全的SoA容器
// ==========================================
//
// 实践项目中的 SoAVector<Ts...> 使用数字索引：get<0>(), get<3>()
// 这是危险的——get<3>()是vx还是life？一个错误的索引就是一个隐蔽的bug。
//
// 更好的方案：使用"标签类型"（Tag Types）实现编译时命名访问。
//
// 灵感来源：
//   - flecs ECS: 组件类型本身就是索引键
//   - entt: 利用类型ID做组件查找
//   - Unity DOTS: 组件类型通过 IComponentData 接口标识
//
// 目标API：
//   using Data = NamedSoA<PositionX, PositionY, VelocityX, Life>;
//   Data data(1000);
//   auto& xs = data.get<PositionX>();      // 类型安全！
//   float* xptr = data.data<PositionX>();   // SIMD友好的裸指针

#include <tuple>
#include <vector>
#include <type_traits>
#include <cstddef>
#include <utility>

namespace dod::layout {

// 字段标签基类——定义值类型
template<typename T>
struct SoAField {
    using ValueType = T;
};

// 具体字段定义
struct PositionX : SoAField<float> {};
struct PositionY : SoAField<float> {};
struct PositionZ : SoAField<float> {};
struct VelocityX : SoAField<float> {};
struct VelocityY : SoAField<float> {};
struct VelocityZ : SoAField<float> {};
struct Life      : SoAField<float> {};
struct MaxLife   : SoAField<float> {};
struct Size      : SoAField<float> {};
struct Flags     : SoAField<uint32_t> {};

// 编译时类型索引查找
template<typename T, typename Tuple>
struct TypeIndex;

template<typename T, typename... Ts>
struct TypeIndex<T, std::tuple<T, Ts...>> {
    static constexpr size_t value = 0;
};

template<typename T, typename U, typename... Ts>
struct TypeIndex<T, std::tuple<U, Ts...>> {
    static constexpr size_t value = 1 + TypeIndex<T, std::tuple<Ts...>>::value;
};

// 命名SoA容器
template<typename... Fields>
class NamedSoA {
private:
    using FieldTuple = std::tuple<Fields...>;
    using StorageTuple = std::tuple<std::vector<typename Fields::ValueType>...>;

    StorageTuple arrays_;
    size_t size_ = 0;

public:
    NamedSoA() = default;

    explicit NamedSoA(size_t initialSize) {
        resize(initialSize);
    }

    void resize(size_t n) {
        std::apply([n](auto&... arrays) {
            (arrays.resize(n), ...);
        }, arrays_);
        size_ = n;
    }

    void reserve(size_t n) {
        std::apply([n](auto&... arrays) {
            (arrays.reserve(n), ...);
        }, arrays_);
    }

    // 类型安全的数组访问
    template<typename Field>
    auto& get() {
        constexpr size_t idx = TypeIndex<Field, FieldTuple>::value;
        return std::get<idx>(arrays_);
    }

    template<typename Field>
    const auto& get() const {
        constexpr size_t idx = TypeIndex<Field, FieldTuple>::value;
        return std::get<idx>(arrays_);
    }

    // 原始指针访问（用于SIMD）
    template<typename Field>
    auto* data() {
        return get<Field>().data();
    }

    template<typename Field>
    const auto* data() const {
        return get<Field>().data();
    }

    // 单元素访问
    template<typename Field>
    auto& at(size_t index) {
        return get<Field>()[index];
    }

    size_t size() const { return size_; }
    bool empty() const { return size_ == 0; }
};

// 使用示例
void namedSoAExample() {
    using ParticleData = NamedSoA<PositionX, PositionY, PositionZ,
                                   VelocityX, VelocityY, VelocityZ,
                                   Life, MaxLife, Size>;

    ParticleData particles(1'000'000);

    // 类型安全的访问——编译时检查字段名
    auto& xs = particles.get<PositionX>();
    auto& vxs = particles.get<VelocityX>();

    // 初始化
    for (size_t i = 0; i < particles.size(); ++i) {
        xs[i] = 0.0f;
        vxs[i] = 1.0f;
    }

    // SIMD友好的裸指针
    float* xPtr = particles.data<PositionX>();
    const float* vxPtr = particles.data<VelocityX>();

    // 更新（可以传给SIMD函数）
    float dt = 0.016f;
    for (size_t i = 0; i < particles.size(); ++i) {
        xPtr[i] += vxPtr[i] * dt;
    }

    // 编译错误示例（取消注释会触发编译错误）：
    // particles.get<int>();  // 错误：int不是已注册的字段类型
}

} // namespace dod::layout
```

---

#### 2.6 AoS到SoA的渐进式重构

```cpp
// ==========================================
// 渐进式重构：从AoS到SoA的实战策略
// ==========================================
//
// 现实中很少有机会从零开始用SoA设计系统。
// 更常见的场景是：已有大量AoS代码，性能瓶颈出现在热路径。
//
// 三种渐进式策略：
//
// 策略1：代理模式（Proxy Pattern）
//   保持AoS的API接口，底层使用SoA存储。
//   优点：调用方代码不需要修改。
//   缺点：代理对象有额外的间接层开销。
//
// 策略2：热路径提取（Hot Path Extraction）
//   只将性能关键的循环改为SoA。
//   优点：改动最小，效果立竿见影。
//   缺点：需要在AoS和SoA之间同步数据。
//
// 策略3：影子SoA（Shadow SoA）
//   维护两份数据（AoS用于通用访问，SoA用于热路径），
//   按需同步。
//   优点：可以逐步迁移。
//   缺点：内存翻倍。

namespace dod::layout {

// ──────────────────────────────────────
// 策略1：代理模式
// ──────────────────────────────────────

// SoA存储
struct ParticleSoAStorage {
    std::vector<float> x, y, z;
    std::vector<float> vx, vy, vz;
    std::vector<float> life;
    size_t count = 0;

    void resize(size_t n) {
        x.resize(n); y.resize(n); z.resize(n);
        vx.resize(n); vy.resize(n); vz.resize(n);
        life.resize(n);
        count = n;
    }
};

// AoS风格的代理——看起来像一个粒子对象
class ParticleProxy {
    ParticleSoAStorage& storage_;
    size_t index_;

public:
    ParticleProxy(ParticleSoAStorage& storage, size_t index)
        : storage_(storage), index_(index) {}

    // 读写访问——看起来就像普通成员
    float& x() { return storage_.x[index_]; }
    float& y() { return storage_.y[index_]; }
    float& z() { return storage_.z[index_]; }
    float& vx() { return storage_.vx[index_]; }
    float& vy() { return storage_.vy[index_]; }
    float& vz() { return storage_.vz[index_]; }
    float& life() { return storage_.life[index_]; }

    const float& x() const { return storage_.x[index_]; }
    const float& y() const { return storage_.y[index_]; }
    const float& z() const { return storage_.z[index_]; }
};

// 迭代器——支持 range-for
class ParticleProxyIterator {
    ParticleSoAStorage& storage_;
    size_t index_;

public:
    ParticleProxyIterator(ParticleSoAStorage& s, size_t i)
        : storage_(s), index_(i) {}

    ParticleProxy operator*() { return {storage_, index_}; }
    ParticleProxyIterator& operator++() { ++index_; return *this; }
    bool operator!=(const ParticleProxyIterator& other) const {
        return index_ != other.index_;
    }
};

class ProxiedParticles {
    ParticleSoAStorage storage_;

public:
    void resize(size_t n) { storage_.resize(n); }

    // AoS风格访问（通过代理）
    ParticleProxy operator[](size_t i) { return {storage_, i}; }

    // Range-for 支持
    ParticleProxyIterator begin() { return {storage_, 0}; }
    ParticleProxyIterator end() { return {storage_, storage_.count}; }

    // 热路径直接访问底层SoA（性能关键代码使用）
    ParticleSoAStorage& rawSoA() { return storage_; }

    size_t size() const { return storage_.count; }
};

// 使用代理——上层代码几乎不需要修改
void gameLogicWithProxy(ProxiedParticles& particles) {
    // 通用逻辑：通过代理，看起来像AoS
    for (auto p : particles) {
        if (p.life() <= 0) {
            // 处理死亡粒子...
        }
    }

    // 热路径：直接用SoA，获得性能
    auto& soa = particles.rawSoA();
    float dt = 0.016f;
    for (size_t i = 0; i < soa.count; ++i) {
        soa.x[i] += soa.vx[i] * dt;
        soa.y[i] += soa.vy[i] * dt;
        soa.z[i] += soa.vz[i] * dt;
    }
}

} // namespace dod::layout
```

**SoA与对象生命周期管理**

```
SoA布局的一个核心挑战：元素的增删操作

AoS中删除一个对象很自然——删掉结构体即可。
SoA中删除一个"逻辑实体"意味着要在每个数组的相同索引位置操作。

三种策略对比：

┌─ 策略1: Swap-Remove（交换删除）────────────────────────────────────┐
│                                                                      │
│  删除索引3的实体（共6个实体，索引0-5）：                             │
│                                                                      │
│  x:  [x0, x1, x2, x3, x4, x5]     →   [x0, x1, x2, x5, x4, |]    │
│  y:  [y0, y1, y2, y3, y4, y5]     →   [y0, y1, y2, y5, y4, |]    │
│  vx: [v0, v1, v2, v3, v4, v5]     →   [v0, v1, v2, v5, v4, |]    │
│                      ↑       ↑                         ↑             │
│                     删除    最后元素              移到删除位置        │
│                                                                      │
│  优点: O(1)时间，保持数组紧凑，无碎片                                │
│  缺点: 改变了元素顺序（外部持有索引的引用会失效）                    │
└──────────────────────────────────────────────────────────────────────┘

┌─ 策略2: 墓碑标记（Tombstone）──────────────────────────────────────┐
│                                                                      │
│  alive: [1, 1, 1, 0, 1, 1]    ← 标记索引3为"死亡"                  │
│  x:     [x0,x1,x2,x3,x4,x5]  ← 数据不移动                         │
│                     ↑                                                │
│                    墓碑（数据仍在，但逻辑上无效）                     │
│                                                                      │
│  优点: O(1)时间，索引稳定（外部引用不失效）                          │
│  缺点: 碎片累积，遍历时需要跳过墓碑（破坏SIMD连续性）               │
└──────────────────────────────────────────────────────────────────────┘

┌─ 策略3: 代数计数器（Generation Counter）──────────────────────────┐
│                                                                      │
│  generation: [1, 1, 1, 2, 1, 1]   ← 索引3的代数+1                  │
│                                                                      │
│  外部句柄: { index=3, generation=1 }                                 │
│  验证: handle.generation != generation[handle.index] → 已失效        │
│                                                                      │
│  优点: 可以检测过期引用（use-after-free的编译期替代）                 │
│  缺点: 每次访问多一次代数检查                                        │
└──────────────────────────────────────────────────────────────────────┘
```

```cpp
// ==========================================
// SoA的元素增删与紧凑化
// ==========================================
//
// 在游戏引擎中，实体频繁创建和销毁（粒子、子弹、临时特效）。
// SoA布局需要一套高效的生命周期管理机制，否则碎片化会严重
// 影响遍历性能——这恰恰是我们选择SoA的初衷所在。
//
// 下面的CompactableSoA实现了三种策略的统一框架，
// 并提供了基于阈值的自适应紧凑化。

#include <vector>
#include <cstdint>
#include <algorithm>
#include <iostream>
#include <cassert>
#include <functional>

namespace dod::layout {

// 代数句柄——安全引用SoA中的元素
// 为什么需要generation？防止"悬空索引"问题：
//   1. 系统A持有句柄{index=5, gen=1}
//   2. 索引5的实体被删除
//   3. 新实体被分配到索引5，gen变为2
//   4. 系统A用旧句柄访问——generation不匹配，检测到过期
struct EntityHandle {
    uint32_t index;
    uint32_t generation;
};

// 支持紧凑化的SoA容器
// 模板参数化为了简洁这里用具体类型，实际项目中应该用variadic template
class CompactableSoA {
public:
    // SoA数据字段
    std::vector<float> x, y, z;
    std::vector<float> vx, vy, vz;
    std::vector<float> life;

    // 元数据——管理生命周期
    std::vector<bool> alive;              // 墓碑标记
    std::vector<uint32_t> generation;     // 代数计数器
    std::vector<uint32_t> freeList;       // 可复用的空闲索引

    size_t count = 0;       // 已分配的总槽位数（包括墓碑）
    size_t aliveCount = 0;  // 存活实体数
    size_t tombstoneCount = 0;

    // 紧凑化策略的阈值：当墓碑占比超过此值时触发紧凑化
    // 为什么是25%？经验值——太低会频繁紧凑化，太高会浪费太多遍历时间
    static constexpr float COMPACTION_THRESHOLD = 0.25f;

    // ──── 创建实体 ────
    EntityHandle add(float px, float py, float pz,
                     float pvx, float pvy, float pvz,
                     float plife) {
        uint32_t idx;

        if (!freeList.empty()) {
            // 复用空闲槽位——避免数组无限增长
            idx = freeList.back();
            freeList.pop_back();
            tombstoneCount--;
        } else {
            // 需要扩展所有数组
            idx = static_cast<uint32_t>(count);
            count++;
            x.push_back(0); y.push_back(0); z.push_back(0);
            vx.push_back(0); vy.push_back(0); vz.push_back(0);
            life.push_back(0);
            alive.push_back(false);
            generation.push_back(0);
        }

        // 填充数据
        x[idx] = px; y[idx] = py; z[idx] = pz;
        vx[idx] = pvx; vy[idx] = pvy; vz[idx] = pvz;
        life[idx] = plife;
        alive[idx] = true;
        aliveCount++;

        return EntityHandle{idx, generation[idx]};
    }

    // ──── 删除实体（墓碑标记 + 代数递增）────
    void remove(EntityHandle handle) {
        if (!isValid(handle)) return;

        alive[handle.index] = false;
        generation[handle.index]++;  // 使所有旧句柄失效
        freeList.push_back(handle.index);
        aliveCount--;
        tombstoneCount++;

        // 自适应紧凑化：超过阈值时自动触发
        if (shouldCompact()) {
            compact();
        }
    }

    // ──── Swap-Remove式紧凑化 ────
    // 将所有存活元素压缩到数组前部，消除所有墓碑
    // 注意：这会改变存活元素的索引，所有外部句柄都会失效！
    // 因此只在"安全点"调用（如帧结束时）
    void compact() {
        if (tombstoneCount == 0) return;

        size_t write = 0;
        for (size_t read = 0; read < count; ++read) {
            if (alive[read]) {
                if (write != read) {
                    // 移动数据：每个字段都要移动
                    x[write] = x[read];
                    y[write] = y[read];
                    z[write] = z[read];
                    vx[write] = vx[read];
                    vy[write] = vy[read];
                    vz[write] = vz[read];
                    life[write] = life[read];
                    alive[write] = true;
                    generation[write] = generation[read] + 1;  // 紧凑化后代数递增
                }
                write++;
            }
        }

        // 截断数组
        count = write;
        tombstoneCount = 0;
        freeList.clear();

        x.resize(count); y.resize(count); z.resize(count);
        vx.resize(count); vy.resize(count); vz.resize(count);
        life.resize(count);
        alive.resize(count);
        generation.resize(count);
    }

    // ──── 句柄有效性检查 ────
    bool isValid(EntityHandle handle) const {
        return handle.index < count
            && alive[handle.index]
            && generation[handle.index] == handle.generation;
    }

    // ──── 遍历存活实体（跳过墓碑）────
    // 热路径中应尽量避免此模式——紧凑化后直接遍历[0, count)更高效
    template<typename Func>
    void forEachAlive(Func&& func) {
        for (size_t i = 0; i < count; ++i) {
            if (alive[i]) {
                func(i);
            }
        }
    }

    // ──── 紧凑化后的高效遍历（无分支）────
    // 只有在compact()之后才能安全调用——此时数组中无墓碑
    template<typename Func>
    void forEachCompacted(Func&& func) {
        assert(tombstoneCount == 0 && "必须先compact()再调用forEachCompacted");
        for (size_t i = 0; i < count; ++i) {
            func(i);
        }
    }

private:
    bool shouldCompact() const {
        if (count == 0) return false;
        return static_cast<float>(tombstoneCount) / count > COMPACTION_THRESHOLD;
    }
};

void demonstrateSoALifecycle() {
    CompactableSoA particles;

    // 创建一批粒子
    std::vector<EntityHandle> handles;
    for (int i = 0; i < 1000; ++i) {
        handles.push_back(particles.add(
            static_cast<float>(i), 0.f, 0.f,
            1.f, 0.f, 0.f,
            static_cast<float>(i % 60)  // 生命值0-59帧
        ));
    }

    std::cout << "初始状态: " << particles.aliveCount << " 存活, "
              << particles.tombstoneCount << " 墓碑\n";

    // 删除偶数索引的粒子——模拟随机死亡
    for (size_t i = 0; i < handles.size(); i += 2) {
        particles.remove(handles[i]);
    }

    std::cout << "删除后:   " << particles.aliveCount << " 存活, "
              << particles.tombstoneCount << " 墓碑\n";

    // 验证旧句柄已失效
    assert(!particles.isValid(handles[0]));  // 已删除
    assert(particles.isValid(handles[1]));   // 仍存活

    // 紧凑化（如果阈值触发的自动紧凑化还不够彻底）
    particles.compact();

    std::cout << "紧凑后:   " << particles.aliveCount << " 存活, "
              << particles.tombstoneCount << " 墓碑, "
              << "数组大小=" << particles.count << "\n";

    // 紧凑化后可以无分支遍历——这是性能关键
    particles.forEachCompacted([&](size_t i) {
        particles.x[i] += particles.vx[i] * 0.016f;
    });
}

} // namespace dod::layout
```

**SoA生命周期管理策略选择指南**

| 场景 | 推荐策略 | 原因 |
|------|---------|------|
| 粒子系统（大量短生命期） | Swap-Remove + 每帧紧凑 | 粒子无稳定引用需求，紧凑后遍历最优 |
| ECS组件存储（需要稳定ID） | 墓碑 + 代数计数器 | 外部系统持有句柄，不能随意移动元素 |
| 子弹/投射物（中等数量） | Swap-Remove即时执行 | 数量不大时紧凑化开销可忽略 |
| 静态场景对象（极少删除） | 直接标记删除 | 几乎不需要紧凑化 |
| 网络同步实体 | 代数计数器 | 网络层需要稳定ID映射 |
| 阈值紧凑化适用场景 | 墓碑比例波动大时 | 避免每帧紧凑化的开销，只在碎片严重时触发 |

---

#### 2.7 真实引擎案例分析

```
// ==========================================
// 真实引擎的数据布局选择
// ==========================================
//
// 1. Unity DOTS (Data-Oriented Technology Stack)
// ─────────────────────────────────────────────
//   核心数据结构：ArchetypeChunk
//   - 每个Archetype = 一种唯一的组件组合（如Position+Velocity+Health）
//   - 每个Chunk = 16KB的内存块，内部使用SoA布局
//   - 这实际上是AoSoA：Chunk是"AoS中的S"，Chunk内部是SoA
//
//   Chunk内存布局（16KB）：
//   ┌──────────────────────────────────────┐
//   │ Header: entity count, archetype info │
//   ├──────────────────────────────────────┤
//   │ Position[]: [p0, p1, p2, ..., pN]   │  ← SoA
//   ├──────────────────────────────────────┤
//   │ Velocity[]: [v0, v1, v2, ..., vN]   │  ← SoA
//   ├──────────────────────────────────────┤
//   │ Health[]:   [h0, h1, h2, ..., hN]   │  ← SoA
//   └──────────────────────────────────────┘
//
//   N = 16KB / sum(component sizes)
//   例如 Position(12B) + Velocity(12B) + Health(4B) = 28B/entity
//   N ≈ 16384 / 28 ≈ 585 entities per chunk
//
//   优势：
//   - 16KB恰好适合L1缓存
//   - Chunk内SoA → SIMD友好
//   - Chunk间遍历 → 顺序访问，硬件预取器高效
//   - 内存碎片极低（Chunk统一管理）
//
//
// 2. Unreal Engine 5 - Mass Framework
// ─────────────────────────────────────────
//   类似Unity DOTS的Fragment概念
//   - Fragment ≈ Archetype
//   - 内部也是SoA存储
//   - 重点优化：线程安全的批量处理
//
//
// 3. 数据库的列存储 vs 行存储
// ─────────────────────────────────────────
//   行存储（Row Store） = AoS
//     MySQL, PostgreSQL 默认
//     适合OLTP：插入一行、按主键查找
//     每行所有列连续存储
//
//   列存储（Column Store） = SoA
//     ClickHouse, Apache Parquet, DuckDB
//     适合OLAP：聚合某一列、扫描大量行
//     每列连续存储
//
//   列存储的优势（与SoA相同的原理）：
//   - SELECT AVG(price) FROM orders → 只读price列
//   - 行存储：加载整行，price列利用率可能<5%
//   - 列存储：只加载price列，利用率100%
//   - 额外好处：同类型数据压缩率更高
//
//
// 4. 选型决策树
// ─────────────────────────────────────────
//
//   你的数据访问模式是什么？
//           │
//     ┌─────┴──────┐
//     │            │
//   批量遍历?    单个对象访问?
//     │            │
//     │          AoS ✓
//     │
//   只访问部分字段?
//     │
//   ┌─┴──┐
//   是   否（所有字段）
//   │     │
//   │   AoS也行
//   │
//   SIMD优化很重要?
//   │
//   ┌─┴──┐
//   是   否
//   │     │
//  AoSoA  SoA
```

---

#### 2.8 本周练习任务

```
练习1：三种布局性能对比
──────────────────────
目标：实现AoS、SoA、AoSoA三种布局并全面对比

要求：
1. 实现粒子系统，每个粒子包含position(3), velocity(3), life(1) = 7 float
2. 三种布局各自实现：(a)位置更新 (b)距离计算 (c)完整实体访问
3. 对每种操作，在10K/100K/1M/10M粒子规模下测试
4. 输出对比表格

验证：
- SoA在单字段操作上应比AoS快2-4倍
- AoSoA在SIMD密集操作上应比纯SoA快10-20%
- AoS在完整实体访问上应与SoA相当或略快

练习2：编译器向量化实验
────────────────────
目标：分析编译器对不同布局代码的向量化行为

要求：
1. 编写AoS和SoA版本的粒子位置更新
2. 分别用GCC和Clang编译，开启向量化报告
3. 记录哪些循环被向量化、哪些未被向量化及原因
4. 尝试使用__restrict__和#pragma帮助AoS版本向量化
5. 写出分析报告

验证：
- SoA版本应全部向量化
- AoS版本应部分失败
- 加__restrict__后是否有改善

练习3：NamedSoA容器实现
─────────────────────
目标：实现类型安全的命名SoA容器

要求：
1. 实现NamedSoA模板，支持：resize, reserve, get<Field>, data<Field>
2. 支持push_back（接受所有字段的值）
3. 支持swap_remove（交换到末尾并删除，保持紧凑）
4. 编写单元测试覆盖所有操作

验证：
- 编译时类型检查：使用错误的字段类型应触发编译错误
- 性能应与手写SoA相当（零抽象开销）

练习4：渐进式重构练习
──────────────────
目标：将一个AoS系统的热路径重构为SoA

要求：
1. 从以下AoS起始代码开始：
   struct Entity { Vec3 pos, vel; float hp, armor; string name; int team; };
   vector<Entity> entities;
   热路径：位置更新（每帧） 冷路径：名字查找（偶尔）
2. 将热路径改为SoA，保持冷路径在AoS
3. 使用代理模式提供统一接口
4. 测量重构前后热路径性能差异

验证：
- 热路径加速2-4倍
- 冷路径性能不变或轻微下降（可接受）
- 公共API保持不变
```

---

#### 2.9 本周知识检验

```
思考题1：什么情况下AoS实际上比SoA更快？
         给出具体的访问模式和数据结构示例。

思考题2：为什么AoSoA比纯SoA对AVX-512更友好？
         提示：考虑寄存器压力和预取距离。

思考题3：SoA布局如何影响序列化/反序列化？
         如果需要将粒子系统保存到文件，哪种布局更方便？

思考题4：数据库为什么OLTP用行存储（AoS）、OLAP用列存储（SoA）？
         这与游戏引擎的选择有什么相似之处？

思考题5：如果SoA这么好，为什么绝大多数C++代码仍然使用AoS？
         从工程角度（而非性能角度）分析原因。

实践题1：
  给定以下结构和访问模式，计算AoS和SoA的理论缓存行利用率：
  struct Enemy { float x,y,z; float hp; uint32_t type; char name[32]; };
  操作：遍历所有Enemy，只读取x,y,z计算与玩家距离

实践题2：
  设计一个2D物理引擎的数据布局。需要的字段：
  position(2 float), velocity(2 float), mass(float),
  shape_type(enum, 1 byte), collision_mask(uint32_t), is_static(bool)
  要求：(a) 分析哪些是热数据、哪些是冷数据
        (b) 设计最优的SoA分组
        (c) 说明为什么这样分组
```

### 第三周：热/冷数据分离（35小时）

**学习目标**：
- [ ] 掌握数据访问频率分析方法，能够识别热数据和冷数据
- [ ] 理解并实践结构体拆分的三种策略（简单分离/分层温度/SoA字段分组）
- [ ] 掌握位打包、量化压缩等数据压缩技术及其对缓存的影响
- [ ] 设计和实现面向DOD的内存池分配器
- [ ] 理解Slot Map（句柄映射）模式及其在DOD中消除指针的作用
- [ ] 了解数据导向实体系统的基本架构（ECS前奏）
- [ ] 掌握多线程场景下的数据分离策略（双缓冲、线程本地累加）

**阅读材料**：
- [ ] 《Optimizing software in C++》- Agner Fog - Chapter 7: Data structures
- [ ] Facebook Folly库文档 - FBVector、small_vector设计
- [ ] 《Game Programming Patterns》- Robert Nystrom - Component章节
- [ ] flecs ECS框架源码 - 稀疏集与Archetype存储
- [ ] Linux内核slab分配器文档
- [ ] CppCon 2017：《Designing a Fast, Efficient, Cache-friendly Hash Table》

---

#### 核心概念

```cpp
// 不良设计：冷数据混在热数据中
struct EntityBad {
    // 热数据 - 每帧访问
    float posX, posY, posZ;
    float velX, velY, velZ;

    // 冷数据 - 偶尔访问
    std::string name;           // 24-32字节
    std::string description;    // 24-32字节
    uint64_t creationTime;
    uint32_t creatorId;
    bool isStatic;
    char padding[3];
};
// 实际大小可能超过100字节，但每帧只需要24字节

// 良好设计：分离热/冷数据
struct EntityHot {
    float posX, posY, posZ;
    float velX, velY, velZ;
    uint32_t coldDataIndex;  // 指向冷数据
    // 28字节，接近缓存行一半
};

struct EntityCold {
    std::string name;
    std::string description;
    uint64_t creationTime;
    uint32_t creatorId;
    bool isStatic;
};
```

---

#### 3.1 数据访问频率分析方法论

```cpp
// ==========================================
// 数据温度分析：找到真正的热数据
// ==========================================
//
// "80/20法则"在数据访问中尤为显著：
//   通常不到20%的字段被80%以上的代码路径访问。
//
// 数据温度分类：
//   🔴 热数据（Hot）：每帧/每次更新都访问
//      例如：position, velocity, transform
//      策略：紧凑SoA，对齐到缓存行，L1友好
//
//   🟡 温数据（Warm）：每几帧访问一次
//      例如：render state, collision shape, animation state
//      策略：独立SoA或AoS，L2/L3友好即可
//
//   🔵 冷数据（Cold）：偶尔访问（编辑器、调试、保存）
//      例如：name, description, creation time
//      策略：独立存储，不污染缓存
//
// 如何确定字段温度？
//   方法1：静态分析——阅读代码，统计每个字段被访问的代码路径数
//   方法2：动态分析——运行时记录每个字段的访问次数
//   方法3：性能分析——用perf找出cache miss热点

#include <cstdint>
#include <string>
#include <iostream>
#include <iomanip>
#include <unordered_map>

namespace dod::hotcold {

// ==========================================
// 调试模式下的访问频率追踪器
// ==========================================
//
// 在开发阶段使用：包装每个字段，自动统计读写次数。
// 发布版本中通过宏替换为零开销的普通字段。

#ifdef DOD_PROFILE_ACCESS
template<typename T>
class ProfiledField {
    T value_{};
    mutable uint64_t readCount_ = 0;
    uint64_t writeCount_ = 0;
    const char* fieldName_;

public:
    explicit ProfiledField(const char* name, T initial = {})
        : value_(initial), fieldName_(name) {}

    // 隐式读取（自动计数）
    operator const T&() const {
        ++readCount_;
        return value_;
    }

    // 赋值（自动计数）
    ProfiledField& operator=(const T& v) {
        ++writeCount_;
        value_ = v;
        return *this;
    }

    // 查看统计
    void printStats() const {
        std::cout << std::setw(20) << fieldName_
                  << "  reads: " << std::setw(10) << readCount_
                  << "  writes: " << std::setw(10) << writeCount_
                  << "  total: " << std::setw(10) << (readCount_ + writeCount_);

        // 温度判断
        uint64_t total = readCount_ + writeCount_;
        if (total > 100000)     std::cout << "  [HOT]";
        else if (total > 1000)  std::cout << "  [WARM]";
        else                    std::cout << "  [COLD]";
        std::cout << "\n";
    }

    const T& raw() const { return value_; }
    T& raw() { return value_; }
};

// 使用示例
struct ProfiledEntity {
    ProfiledField<float> posX{"posX"}, posY{"posY"}, posZ{"posZ"};
    ProfiledField<float> velX{"velX"}, velY{"velY"}, velZ{"velZ"};
    ProfiledField<float> health{"health"};
    ProfiledField<std::string> name{"name"};
    ProfiledField<uint64_t> creationTime{"creationTime"};

    void printAccessReport() const {
        std::cout << "===== Entity Access Report =====\n";
        posX.printStats();
        posY.printStats();
        posZ.printStats();
        velX.printStats();
        velY.printStats();
        velZ.printStats();
        health.printStats();
        name.printStats();
        creationTime.printStats();
    }
};

#else
// 发布版本：零开销
template<typename T>
using ProfiledField = T;
#endif

} // namespace dod::hotcold
```

```
典型的访问频率分析结果（模拟10000帧游戏循环）：

  字段名               读次数      写次数      总次数      温度
  ─────────────────  ──────────  ──────────  ──────────  ──────
  posX               600,000     600,000    1,200,000   [HOT]
  posY               600,000     600,000    1,200,000   [HOT]
  posZ               600,000     600,000    1,200,000   [HOT]
  velX               600,000     10,000       610,000   [HOT]
  velY               600,000     10,000       610,000   [HOT]
  velZ               600,000     10,000       610,000   [HOT]
  health              50,000      5,000        55,000   [WARM]
  name                     3          1             4   [COLD]
  creationTime             1          1             2   [COLD]

  → position和velocity是绝对热数据，占>95%的总访问
  → health是温数据（只在碰撞检测和UI渲染时访问）
  → name和creationTime是冰冷数据
```

---

#### 3.2 结构体拆分策略与实现

```cpp
// ==========================================
// 结构体拆分：按温度组织数据
// ==========================================
//
// 策略1：简单二分（Hot + Cold）
//   最常用，实现简单，效果显著。
//   热数据紧凑存储（SoA），冷数据独立存储。
//
// 策略2：三层温度（Hot + Warm + Cold）
//   更精细的分离。Warm数据（如渲染状态）
//   在渲染帧中是热的，但在物理帧中是冷的。
//
// 策略3：SoA字段分组
//   最灵活：每个字段独立数组，按访问模式组合遍历。
//   这就是ECS的基本思想。

#include <vector>
#include <string>
#include <cstdint>
#include <cassert>
#include <iostream>

namespace dod::hotcold {

// ──────────────────────────────────────
// 策略2：三层温度实体管理器
// ──────────────────────────────────────

struct EntityHotData {
    // 每帧必访问——32字节，半个缓存行
    float posX, posY, posZ;
    float velX, velY, velZ;
    float rotation;
    float speed;  // 预计算的速度标量（避免每帧sqrt）
};

struct EntityWarmData {
    // 渲染相关——每几帧访问
    float scaleX, scaleY, scaleZ;
    uint32_t meshId;
    uint32_t materialId;
    uint32_t renderLayer;
    float boundingRadius;
    uint32_t animationState;
};

struct EntityColdData {
    // 编辑器/调试/保存——极少访问
    std::string name;
    std::string tag;
    uint64_t creationTimestamp;
    uint32_t creatorId;
    std::vector<uint32_t> childEntityIds;
    std::string serializedCustomData;
};

class TieredEntityManager {
    // 热数据——紧凑数组，每帧遍历
    std::vector<EntityHotData> hotData_;

    // 温数据——稍松散，渲染时遍历
    std::vector<EntityWarmData> warmData_;

    // 冷数据——按需访问
    std::vector<EntityColdData> coldData_;

    // 空闲索引列表（用于回收已删除的位置）
    std::vector<uint32_t> freeIndices_;
    uint32_t count_ = 0;

public:
    // 创建实体，返回索引
    uint32_t createEntity(const std::string& name = "") {
        uint32_t index;

        if (!freeIndices_.empty()) {
            index = freeIndices_.back();
            freeIndices_.pop_back();
        } else {
            index = count_;
            hotData_.emplace_back();
            warmData_.emplace_back();
            coldData_.emplace_back();
        }

        // 初始化
        hotData_[index] = {};
        warmData_[index] = {};
        coldData_[index] = {};
        coldData_[index].name = name;
        coldData_[index].creationTimestamp = 0;  // 实际应用中用时间戳

        ++count_;
        return index;
    }

    void destroyEntity(uint32_t index) {
        freeIndices_.push_back(index);
        --count_;
    }

    // ──────── 热路径：每帧调用 ────────
    void updatePositions(float dt) {
        // 只遍历热数据——32字节/实体
        // 缓存行可容纳2个实体的全部热数据
        for (size_t i = 0; i < hotData_.size(); ++i) {
            auto& h = hotData_[i];
            h.posX += h.velX * dt;
            h.posY += h.velY * dt;
            h.posZ += h.velZ * dt;
        }
    }

    // ──────── 温路径：渲染时调用 ────────
    void prepareRenderData(/* RenderQueue& queue */) {
        for (size_t i = 0; i < warmData_.size(); ++i) {
            auto& h = hotData_[i];   // position
            auto& w = warmData_[i];  // render state
            // queue.submit(h.posX, h.posY, h.posZ, w.meshId, w.materialId, ...);
        }
    }

    // ──────── 冷路径：偶尔调用 ────────
    const EntityColdData& getColdData(uint32_t index) const {
        return coldData_[index];
    }

    uint32_t entityCount() const { return count_; }
};

} // namespace dod::hotcold
```

**结构体拆分的内存布局影响**

将一个大结构体拆分为热/温/冷多层后，内存布局会发生根本性变化。
理解这些变化对于选择正确的拆分策略至关重要。

```
拆分前——单一AoS（Array of Structures）：

Entity[0]                          Entity[1]
┌─────────────────────────────┐   ┌─────────────────────────────┐
│ posX posY posZ              │   │ posX posY posZ              │
│ velX velY velZ              │   │ velX velY velZ              │
│ hp maxHp                    │   │ hp maxHp                    │
│ meshId materialId           │   │ meshId materialId           │
│ renderLayer boundingRadius  │   │ renderLayer boundingRadius  │
│ animationState              │   │ animationState              │
│ name(32B) tag(32B)          │   │ name(32B) tag(32B)          │
│ creationTime creatorId      │   │ creationTime creatorId      │
│ childIds(24B) customData    │   │ childIds(24B) customData    │
└─────────────────────────────┘   └─────────────────────────────┘
   ~160字节/实体                     ~160字节/实体

缓存行(64B)覆盖范围：读取Entity[0].posX时，
  一条缓存行只能装下该实体的前40%数据
  如果只需要pos+vel（24字节），利用率 = 24/64 ≈ 37%


2-Tier拆分后——热数据 + 冷数据：

Hot[0]  Hot[1]  Hot[2]  Hot[3]  Hot[4]  ...
┌──────┐┌──────┐┌──────┐┌──────┐┌──────┐
│24B   ││24B   ││24B   ││24B   ││24B   │
│pos+  ││pos+  ││pos+  ││pos+  ││pos+  │
│vel   ││vel   ││vel   ││vel   ││vel   │
└──────┘└──────┘└──────┘└──────┘└──────┘
  ← 一条缓存行(64B)可装2.6个实体 →
  利用率：如果只需pos+vel = 100%

Cold[0]          Cold[1]          Cold[2]
┌───────────────┐┌───────────────┐┌───────────────┐
│ ~136字节      ││ ~136字节      ││ ~136字节      │
│ hp,mesh,name..││ hp,mesh,name..││ hp,mesh,name..│
└───────────────┘└───────────────┘└───────────────┘
  ← 冷数据不影响热路径的缓存 →


3-Tier拆分后——热 + 温 + 冷：

Hot[0] Hot[1] Hot[2] Hot[3] Hot[4] Hot[5] Hot[6] Hot[7]
┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐
│24B │ │24B │ │24B │ │24B │ │24B │ │24B │ │24B │ │24B │
│pos │ │pos │ │pos │ │pos │ │pos │ │pos │ │pos │ │pos │
│+vel│ │+vel│ │+vel│ │+vel│ │+vel│ │+vel│ │+vel│ │+vel│
└────┘ └────┘ └────┘ └────┘ └────┘ └────┘ └────┘ └────┘
  ← 2条缓存行可处理5个实体的物理更新 →

Warm[0]  Warm[1]  Warm[2]  Warm[3]  ...
┌───────┐┌───────┐┌───────┐┌───────┐
│ 20B   ││ 20B   ││ 20B   ││ 20B   │
│ mesh  ││ mesh  ││ mesh  ││ mesh  │
│ matl  ││ matl  ││ matl  ││ matl  │
│ layer ││ layer ││ layer ││ layer │
└───────┘└───────┘└───────┘└───────┘
  ← 一条缓存行装3个实体的渲染数据 →
  渲染帧率和物理帧率不同时，温数据独立缓存

Cold[0]           Cold[1]           ...
┌────────────────┐┌────────────────┐
│ ~116字节       ││ ~116字节       │
│ name,tag,...   ││ name,tag,...   │
└────────────────┘└────────────────┘
```

```cpp
// ==========================================
// 结构体拆分策略的缓存性能基准测试
// ==========================================
//
// 为什么要量化测试？
//   直觉上"拆分一定更好"，但实际上拆分也有代价：
//   1. 多次间接访问（需要同时索引多个数组）
//   2. 如果热路径确实需要访问温/冷数据，反而多了缓存行加载
//   3. 代码复杂度增加
//   本基准测试帮助你在具体场景下做出量化决策

#include <vector>
#include <chrono>
#include <cstdint>
#include <cstring>
#include <cmath>
#include <iostream>
#include <numeric>
#include <algorithm>

namespace dod::hotcold {

// ========== 结构体拆分基准测试 ==========

class StructSplitBenchmark {
    // ---- 原始未拆分结构体（AoS基线） ----
    struct EntityMonolithic {
        float posX, posY, posZ;          // 热：每帧
        float velX, velY, velZ;          // 热：每帧
        float hp, maxHp;                 // 温：伤害计算时
        uint32_t meshId, materialId;     // 温：渲染时
        uint32_t renderLayer;            // 温：渲染时
        float boundingRadius;            // 温：碰撞检测
        uint32_t animationState;         // 温：渲染时
        char name[32];                   // 冷：调试/编辑器
        char tag[32];                    // 冷：编辑器
        uint64_t creationTimestamp;      // 冷：序列化
        uint32_t creatorId;              // 冷：调试
        uint32_t padding[4];             // 填充至128字节整数倍
    };  // sizeof ≈ 128字节

    // ---- 2-Tier拆分 ----
    struct Hot2T {
        float posX, posY, posZ;
        float velX, velY, velZ;
    };  // 24字节——物理更新只需这些
    struct Cold2T {
        float hp, maxHp;
        uint32_t meshId, materialId;
        uint32_t renderLayer;
        float boundingRadius;
        uint32_t animationState;
        char name[32];
        char tag[32];
        uint64_t creationTimestamp;
        uint32_t creatorId;
    };  // ~104字节

    // ---- 3-Tier拆分 ----
    struct Hot3T {
        float posX, posY, posZ;
        float velX, velY, velZ;
    };  // 24字节
    struct Warm3T {
        float hp, maxHp;
        uint32_t meshId, materialId;
        uint32_t renderLayer;
        float boundingRadius;
        uint32_t animationState;
    };  // 28字节
    struct Cold3T {
        char name[32];
        char tag[32];
        uint64_t creationTimestamp;
        uint32_t creatorId;
    };  // ~76字节

    size_t entityCount_;

public:
    explicit StructSplitBenchmark(size_t count) : entityCount_(count) {}

    // 基线：未拆分的物理更新
    double benchMonolithic() {
        std::vector<EntityMonolithic> entities(entityCount_);
        // 初始化数据（防止编译器优化掉）
        for (size_t i = 0; i < entityCount_; ++i) {
            entities[i].velX = 1.0f;
            entities[i].velY = 0.5f;
            entities[i].velZ = 0.1f;
        }

        auto start = std::chrono::high_resolution_clock::now();
        float dt = 0.016f;
        // 模拟100帧物理更新
        for (int frame = 0; frame < 100; ++frame) {
            for (size_t i = 0; i < entityCount_; ++i) {
                // 每次循环加载128字节，但只用24字节——浪费81%
                entities[i].posX += entities[i].velX * dt;
                entities[i].posY += entities[i].velY * dt;
                entities[i].posZ += entities[i].velZ * dt;
            }
        }
        auto end = std::chrono::high_resolution_clock::now();

        return std::chrono::duration<double, std::milli>(end - start).count();
    }

    // 2-Tier：只遍历热数据
    double bench2Tier() {
        std::vector<Hot2T> hot(entityCount_);
        std::vector<Cold2T> cold(entityCount_);  // 冷数据存在但不被访问
        for (size_t i = 0; i < entityCount_; ++i) {
            hot[i].velX = 1.0f;
            hot[i].velY = 0.5f;
            hot[i].velZ = 0.1f;
        }

        auto start = std::chrono::high_resolution_clock::now();
        float dt = 0.016f;
        for (int frame = 0; frame < 100; ++frame) {
            for (size_t i = 0; i < entityCount_; ++i) {
                // 每次只加载24字节——缓存行利用率接近100%
                hot[i].posX += hot[i].velX * dt;
                hot[i].posY += hot[i].velY * dt;
                hot[i].posZ += hot[i].velZ * dt;
            }
        }
        auto end = std::chrono::high_resolution_clock::now();

        return std::chrono::duration<double, std::milli>(end - start).count();
    }

    // 3-Tier：热路径性能与2-Tier相同，但温路径也被优化
    double bench3TierWarmPath() {
        std::vector<Hot3T> hot(entityCount_);
        std::vector<Warm3T> warm(entityCount_);
        std::vector<Cold3T> cold(entityCount_);  // 冷数据存在但不被访问
        for (size_t i = 0; i < entityCount_; ++i) {
            warm[i].meshId = static_cast<uint32_t>(i % 100);
            warm[i].materialId = static_cast<uint32_t>(i % 50);
        }

        auto start = std::chrono::high_resolution_clock::now();
        // 模拟100帧渲染数据准备（只访问hot.pos + warm全部）
        for (int frame = 0; frame < 100; ++frame) {
            for (size_t i = 0; i < entityCount_; ++i) {
                // 渲染准备：需要位置（热）+ 渲染状态（温）
                // 3-Tier下，温数据28字节/实体，缓存行装2个
                // 2-Tier下，冷数据104字节/实体，缓存行装不满1个
                float x = hot[i].posX;
                uint32_t mesh = warm[i].meshId;
                uint32_t mat = warm[i].materialId;
                // 模拟提交渲染命令（防止编译器优化）
                volatile float sink = x;
                volatile uint32_t sink2 = mesh + mat;
                (void)sink; (void)sink2;
            }
        }
        auto end = std::chrono::high_resolution_clock::now();

        return std::chrono::duration<double, std::milli>(end - start).count();
    }

    // 运行完整基准测试并输出结果
    void runAll() {
        std::cout << "=== 结构体拆分缓存性能测试 ===\n";
        std::cout << "实体数量: " << entityCount_ << "\n\n";

        double mono = benchMonolithic();
        double tier2 = bench2Tier();
        double tier3warm = bench3TierWarmPath();

        std::cout << "物理更新(100帧):\n";
        std::cout << "  未拆分(AoS):  " << mono << " ms\n";
        std::cout << "  2-Tier热路径: " << tier2 << " ms";
        std::cout << " (加速比: " << mono / tier2 << "x)\n\n";
        std::cout << "渲染准备(100帧):\n";
        std::cout << "  3-Tier温路径: " << tier3warm << " ms\n";
    }
};

// ========== 拆分策略决策矩阵 ==========
//
// 如何选择2-Tier还是3-Tier拆分？
//
// ┌──────────────────────┬────────────┬─────────────┬──────────────────┐
// │ 场景特征             │ 2-Tier     │ 3-Tier      │ 推荐             │
// ├──────────────────────┼────────────┼─────────────┼──────────────────┤
// │ 访问频率分为两档     │ 最优       │ 过度设计    │ 2-Tier           │
// │ (每帧 vs 偶尔)       │            │             │                  │
// ├──────────────────────┼────────────┼─────────────┼──────────────────┤
// │ 存在明显的中频访问   │ 冷数据膨胀 │ 最优        │ 3-Tier           │
// │ (物理帧 vs 渲染帧    │ 缓存行浪费 │ 每层独立    │                  │
// │  vs 偶尔)            │            │ 优化        │                  │
// ├──────────────────────┼────────────┼─────────────┼──────────────────┤
// │ 结构体 < 64字节      │ 可能不需要 │ 不需要      │ 不拆分           │
// │                      │ (已经很小) │             │ (已在1缓存行内)  │
// ├──────────────────────┼────────────┼─────────────┼──────────────────┤
// │ 实体数量 < 1000      │ 收益有限   │ 收益有限    │ 不拆分           │
// │                      │ (工作集在  │             │ (先profile)      │
// │                      │  L1/L2内)  │             │                  │
// ├──────────────────────┼────────────┼─────────────┼──────────────────┤
// │ 多线程读写不同频率   │ 减少竞争   │ 最优        │ 3-Tier           │
// │ 的数据               │            │ 每层独立锁  │ (天然线程分离)   │
// └──────────────────────┴────────────┴─────────────┴──────────────────┘
//
// 经验法则：
//   - 先从2-Tier开始（热 vs 冷），profile之后再考虑3-Tier
//   - 热数据结构体应尽量 ≤ 32字节（确保2个实体放入一条缓存行）
//   - 如果温数据 > 64字节，考虑进一步拆分温层

} // namespace dod::hotcold
```

---

#### 3.3 位打包与数据压缩技术

```cpp
// ==========================================
// 位打包：让每一位都物尽其用
// ==========================================
//
// 数据越小，每个缓存行能容纳的实体越多。
// 位打包和量化是DOD的"空间压缩"技术。
//
// 常见压缩手段：
//   1. 布尔标志位打包：32个bool → 1个uint32（节省31字节）
//   2. 浮点量化：float → int16（已知范围时精度足够）
//   3. 枚举压缩：4位enum → packed nibble array
//   4. 半精度浮点：float → float16（颜色、法线等低精度场景）
//
// 关键权衡：
//   压缩率 vs 解压开销
//   更小的数据 → 更高的缓存命中率 → 更快的遍历
//   但解压需要额外指令 → 如果ALU成为瓶颈则适得其反
//   经验法则：如果程序是内存带宽瓶颈（大多数DOD场景），压缩几乎总是值得的

#include <cstdint>
#include <cstring>
#include <cmath>
#include <vector>
#include <cassert>

namespace dod::hotcold {

// ──────────────────────────────────────
// 布尔标志位打包
// ──────────────────────────────────────

enum class EntityFlags : uint32_t {
    None        = 0,
    Active      = 1 << 0,
    Visible     = 1 << 1,
    Collidable  = 1 << 2,
    Dynamic     = 1 << 3,
    Selected    = 1 << 4,
    NeedsUpdate = 1 << 5,
    Destroyed   = 1 << 6,
    Initialized = 1 << 7,
    Grounded    = 1 << 8,
    InWater     = 1 << 9,
    OnFire      = 1 << 10,
    Frozen      = 1 << 11,
    // 还能扩展到32个标志，仍然只占4字节
};

constexpr EntityFlags operator|(EntityFlags a, EntityFlags b) {
    return static_cast<EntityFlags>(
        static_cast<uint32_t>(a) | static_cast<uint32_t>(b));
}
constexpr EntityFlags operator&(EntityFlags a, EntityFlags b) {
    return static_cast<EntityFlags>(
        static_cast<uint32_t>(a) & static_cast<uint32_t>(b));
}
constexpr bool hasFlag(EntityFlags flags, EntityFlags flag) {
    return (flags & flag) == flag;
}

// ──────────────────────────────────────
// 浮点量化
// ──────────────────────────────────────
//
// 已知位置范围[-1000, 1000]时，
// float精度其实远超需要（小数点后6位有效数字）。
// 用int16可以表示[-32767, 32767]，
// 映射后精度 = 2000/65534 ≈ 0.03，对于位置已经足够。

struct PackedTransform {
    int16_t posX, posY, posZ;  // 量化位置
    int16_t rotation;          // 量化角度 [0, 2π] → [0, 65535]
    // 仅8字节，原始float版本需要16字节

    static constexpr float POS_RANGE = 1000.0f;
    static constexpr float POS_SCALE = 32767.0f / POS_RANGE;
    static constexpr float ANGLE_SCALE = 65535.0f / (2.0f * 3.14159265f);

    static int16_t packPos(float v) {
        return static_cast<int16_t>(std::clamp(v, -POS_RANGE, POS_RANGE) * POS_SCALE);
    }
    static float unpackPos(int16_t v) {
        return static_cast<float>(v) / POS_SCALE;
    }

    static int16_t packAngle(float radians) {
        return static_cast<int16_t>(std::fmod(radians, 2.0f * 3.14159265f) * ANGLE_SCALE);
    }
    static float unpackAngle(int16_t v) {
        return static_cast<float>(v) / ANGLE_SCALE;
    }

    void pack(float x, float y, float z, float rot) {
        posX = packPos(x);
        posY = packPos(y);
        posZ = packPos(z);
        rotation = packAngle(rot);
    }

    void unpack(float& x, float& y, float& z, float& rot) const {
        x = unpackPos(posX);
        y = unpackPos(posY);
        z = unpackPos(posZ);
        rot = unpackAngle(rotation);
    }
};

// ──────────────────────────────────────
// 位数组（紧凑布尔存储）
// ──────────────────────────────────────

class BitArray {
    std::vector<uint64_t> data_;
    size_t size_ = 0;

public:
    explicit BitArray(size_t count)
        : data_((count + 63) / 64, 0), size_(count) {}

    void set(size_t index) {
        data_[index / 64] |= (1ULL << (index % 64));
    }

    void clear(size_t index) {
        data_[index / 64] &= ~(1ULL << (index % 64));
    }

    bool test(size_t index) const {
        return (data_[index / 64] >> (index % 64)) & 1;
    }

    void toggle(size_t index) {
        data_[index / 64] ^= (1ULL << (index % 64));
    }

    // 批量操作：统计设置位数量（用于快速count alive entities）
    size_t popcount() const {
        size_t count = 0;
        for (auto word : data_) {
            count += __builtin_popcountll(word);
        }
        return count;
    }

    // 遍历所有设置的位（高效跳过空word）
    template<typename Func>
    void forEachSet(Func&& func) const {
        for (size_t w = 0; w < data_.size(); ++w) {
            uint64_t word = data_[w];
            while (word) {
                size_t bit = __builtin_ctzll(word);  // 找到最低设置位
                func(w * 64 + bit);
                word &= word - 1;  // 清除最低设置位
            }
        }
    }

    size_t size() const { return size_; }

    // 内存效率对比：
    // 100万个bool用std::vector<bool>: ~125KB
    // 100万个bool用vector<uint8_t>: ~1MB
    // 100万个bool用BitArray: ~125KB（与vector<bool>相当）
    // 但BitArray支持高效的popcount和forEachSet
};

} // namespace dod::hotcold
```

---

#### 3.4 内存池设计与DOD

```cpp
// ==========================================
// 内存池：DOD的内存管理基石
// ==========================================
//
// 为什么标准分配器（malloc/new）不适合DOD？
//
// 1. 内存碎片：频繁的new/delete导致碎片化
//    → 相邻创建的对象可能在内存中相距很远
//    → 遍历时cache miss暴增
//
// 2. 分配开销：malloc有锁、内存映射等开销
//    → 每帧创建/销毁数千个粒子时成为瓶颈
//
// 3. 不可控的对齐：malloc保证8/16字节对齐
//    → DOD通常需要64字节（缓存行）对齐
//
// 内存池解决所有这些问题：
//   - 预分配大块连续内存，消除碎片
//   - O(1)分配/释放，零锁开销（单线程场景）
//   - 自定义对齐保证
//
// 关键设计：侵入式空闲链表（Intrusive Free List）
//   空闲的slot内部存储指向下一个空闲slot的指针
//   → 空闲链表不需要额外内存！

#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <new>
#include <vector>
#include <memory>
#include <cassert>
#include <iostream>

namespace dod::hotcold {

// 固定大小对象池
template<typename T, size_t BlockSize = 4096>
class PoolAllocator {
    // 侵入式空闲链表节点
    union Slot {
        T object;
        Slot* next;  // 空闲时指向下一个空闲slot

        Slot() : next(nullptr) {}
        ~Slot() {}
    };

    // 内存块
    struct Block {
        alignas(64) Slot slots[BlockSize];
    };

    std::vector<std::unique_ptr<Block>> blocks_;
    Slot* freeList_ = nullptr;
    size_t allocated_ = 0;
    size_t capacity_ = 0;

    void allocateNewBlock() {
        auto block = std::make_unique<Block>();

        // 将所有slot链入空闲链表
        for (size_t i = 0; i < BlockSize - 1; ++i) {
            block->slots[i].next = &block->slots[i + 1];
        }
        block->slots[BlockSize - 1].next = freeList_;
        freeList_ = &block->slots[0];

        capacity_ += BlockSize;
        blocks_.push_back(std::move(block));
    }

public:
    PoolAllocator() {
        allocateNewBlock();
    }

    // O(1) 分配
    template<typename... Args>
    T* allocate(Args&&... args) {
        if (!freeList_) {
            allocateNewBlock();
        }

        Slot* slot = freeList_;
        freeList_ = slot->next;
        ++allocated_;

        // 在slot中构造对象
        return new (&slot->object) T(std::forward<Args>(args)...);
    }

    // O(1) 释放
    void deallocate(T* ptr) {
        ptr->~T();  // 析构

        Slot* slot = reinterpret_cast<Slot*>(ptr);
        slot->next = freeList_;
        freeList_ = slot;
        --allocated_;
    }

    size_t allocated() const { return allocated_; }
    size_t capacity() const { return capacity_; }

    // 遍历所有已分配对象（注意：这不高效，池分配器的遍历需要额外记录）
    // DOD更推荐使用紧凑数组 + swap_remove，而不是池遍历
};

} // namespace dod::hotcold
```

**内存池高级模式**

基础的PoolAllocator已经比malloc快很多，但在DOD场景中我们还需要更多：
分块增长（避免一次分配过大内存）、缓存行对齐（消除伪共享）、
以及SoA感知的并行数组分配（让多个组件数组在同一内存块中紧凑排列）。

```
分块池内存布局（ChunkedPool）：

传统Pool——一次性分配全部容量（可能浪费大量内存）：
┌──────────────────────────────────────────────┐
│ Slot[0] Slot[1] Slot[2] ... Slot[N-1]        │  一大块连续内存
└──────────────────────────────────────────────┘

分块Pool——按需分配固定大小的Chunk：
Chunk 0 (4KB)          Chunk 1 (4KB)          Chunk 2 (4KB)
┌──────────────┐       ┌──────────────┐       ┌──────────────┐
│ S[0] S[1]... │  →    │ S[64] S[65]..│  →    │ S[128]...    │
└──────────────┘       └──────────────┘       └──────────────┘
     ↑ 初始分配              ↑ 需要时才分配         ↑ 按需增长

优势：初始内存占用小，增长平滑，不需要realloc/拷贝


SoA感知池——多组件并行分配在同一Chunk内：
Chunk 0:
┌─────────────────────────────────────────────────────┐
│ [Position × 64] [Velocity × 64] [Health × 64]      │
│  ← 768字节 →     ← 768字节 →     ← 512字节 →       │
└─────────────────────────────────────────────────────┘
  ↑ 三种组件在同一块内存中，访问局部性极佳

Chunk 1:
┌─────────────────────────────────────────────────────┐
│ [Position × 64] [Velocity × 64] [Health × 64]      │
└─────────────────────────────────────────────────────┘
```

```cpp
// ==========================================
// 内存池高级模式：分块增长 + 缓存行对齐 + SoA感知
// ==========================================
//
// 为什么需要这些高级模式？
//   1. ChunkedPool：基础池要么预分配过大（浪费），要么频繁重分配（性能差）
//      分块池在两者间取得平衡——按需增长，每次增长固定大小
//   2. AlignedPool：缓存行对齐消除伪共享，对多线程至关重要
//   3. SoA-aware Pool：让关联数据在物理内存中相邻，提升预取命中率

#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <new>
#include <vector>
#include <memory>
#include <cassert>
#include <array>
#include <algorithm>

namespace dod::hotcold {

// ========== 缓存行对齐分配工具 ==========

// 为什么64字节？因为x86/ARM主流CPU的缓存行都是64字节
// 对齐到缓存行边界可以避免两个线程的数据落在同一缓存行（伪共享）
constexpr size_t CACHE_LINE_SIZE = 64;

// 对齐内存分配（C++17 aligned_alloc的跨平台封装）
inline void* alignedMalloc(size_t size, size_t alignment) {
    // C++17标准要求size是alignment的整数倍
    size_t alignedSize = (size + alignment - 1) & ~(alignment - 1);
#if defined(_MSC_VER)
    return _aligned_malloc(alignedSize, alignment);
#else
    return std::aligned_alloc(alignment, alignedSize);
#endif
}

inline void alignedFree(void* ptr) {
#if defined(_MSC_VER)
    _aligned_free(ptr);
#else
    std::free(ptr);
#endif
}

// ========== 分块SoA内存池 ==========

// ChunkedSoAPool：将多个SoA数组打包到同一个Chunk中分配
// 每个Chunk包含固定数量的元素，所有组件的数据紧凑排列
template<size_t ElementsPerChunk = 64>
class ChunkedSoAPool {
    // 一个Chunk的布局信息
    struct ChunkLayout {
        size_t totalSize;                          // Chunk总字节数
        std::vector<size_t> offsets;               // 每个数组在Chunk内的偏移
        std::vector<size_t> elementSizes;          // 每个数组的元素大小
    };

    // 单个Chunk——一块对齐分配的内存
    struct Chunk {
        void* memory = nullptr;      // 对齐分配的内存块
        size_t usedCount = 0;        // 已使用的元素数量

        ~Chunk() {
            if (memory) {
                alignedFree(memory);
            }
        }

        // 禁止拷贝，允许移动
        Chunk() = default;
        Chunk(const Chunk&) = delete;
        Chunk& operator=(const Chunk&) = delete;
        Chunk(Chunk&& other) noexcept
            : memory(other.memory), usedCount(other.usedCount) {
            other.memory = nullptr;
            other.usedCount = 0;
        }
        Chunk& operator=(Chunk&& other) noexcept {
            if (this != &other) {
                if (memory) alignedFree(memory);
                memory = other.memory;
                usedCount = other.usedCount;
                other.memory = nullptr;
                other.usedCount = 0;
            }
            return *this;
        }
    };

    ChunkLayout layout_;
    std::vector<Chunk> chunks_;
    size_t arrayCount_ = 0;          // SoA中有多少个并行数组

    // 计算布局：确定每个数组在Chunk内的偏移
    void computeLayout(const std::vector<size_t>& elementSizes) {
        layout_.elementSizes = elementSizes;
        layout_.offsets.resize(elementSizes.size());

        size_t offset = 0;
        for (size_t i = 0; i < elementSizes.size(); ++i) {
            // 每个数组起始地址对齐到缓存行
            offset = (offset + CACHE_LINE_SIZE - 1) & ~(CACHE_LINE_SIZE - 1);
            layout_.offsets[i] = offset;
            offset += elementSizes[i] * ElementsPerChunk;
        }
        // 总大小也对齐到缓存行
        layout_.totalSize = (offset + CACHE_LINE_SIZE - 1) & ~(CACHE_LINE_SIZE - 1);
    }

    // 分配新Chunk
    void allocateChunk() {
        Chunk chunk;
        chunk.memory = alignedMalloc(layout_.totalSize, CACHE_LINE_SIZE);
        assert(chunk.memory != nullptr);
        // 零初始化——确保未使用的元素是干净的
        std::memset(chunk.memory, 0, layout_.totalSize);
        chunks_.push_back(std::move(chunk));
    }

public:
    // 构造时指定每个并行数组的元素大小
    // 例如：{sizeof(Position), sizeof(Velocity), sizeof(Health)}
    explicit ChunkedSoAPool(const std::vector<size_t>& elementSizes) {
        arrayCount_ = elementSizes.size();
        computeLayout(elementSizes);
        allocateChunk();  // 预分配第一个Chunk
    }

    // 获取指定Chunk中指定数组的指针
    // chunkIndex: 第几个Chunk
    // arrayIndex: 第几个并行数组（0=Position, 1=Velocity, ...）
    template<typename T>
    T* getArray(size_t chunkIndex, size_t arrayIndex) {
        assert(chunkIndex < chunks_.size());
        assert(arrayIndex < arrayCount_);
        assert(sizeof(T) == layout_.elementSizes[arrayIndex]);

        auto* base = static_cast<uint8_t*>(chunks_[chunkIndex].memory);
        return reinterpret_cast<T*>(base + layout_.offsets[arrayIndex]);
    }

    // 分配一个新元素，返回 (chunkIndex, elementIndex)
    std::pair<size_t, size_t> allocate() {
        // 在最后一个Chunk中寻找空间
        if (chunks_.empty() || chunks_.back().usedCount >= ElementsPerChunk) {
            allocateChunk();
        }
        size_t ci = chunks_.size() - 1;
        size_t ei = chunks_.back().usedCount++;
        return {ci, ei};
    }

    // 获取总容量和已分配数量
    size_t totalCapacity() const { return chunks_.size() * ElementsPerChunk; }
    size_t chunkCount() const { return chunks_.size(); }

    // 遍历所有已使用的元素——逐Chunk遍历，保证缓存友好
    // 回调签名：void(size_t chunkIdx, size_t elemIdx, size_t globalIdx)
    template<typename Func>
    void forEachUsed(Func&& func) const {
        size_t globalIdx = 0;
        for (size_t ci = 0; ci < chunks_.size(); ++ci) {
            for (size_t ei = 0; ei < chunks_[ci].usedCount; ++ei) {
                func(ci, ei, globalIdx++);
            }
        }
    }
};

// ========== 性能对比参考 ==========
//
// 10万次分配/释放64字节对象的吞吐量对比（典型x86-64环境）：
//
// ┌───────────────────────┬────────────┬────────────┬──────────────────┐
// │ 分配器                │ 分配(ns)   │ 释放(ns)   │ 遍历10K元素(us)  │
// ├───────────────────────┼────────────┼────────────┼──────────────────┤
// │ malloc/free           │ 50-200     │ 40-150     │ 15-30            │
// │ (通用分配器，最灵活)  │            │            │ (碎片化时更慢)   │
// ├───────────────────────┼────────────┼────────────┼──────────────────┤
// │ PoolAllocator         │ 5-15       │ 5-10       │ 12-25            │
// │ (基础池，单块)        │            │            │ (连续但可能有洞) │
// ├───────────────────────┼────────────┼────────────┼──────────────────┤
// │ ChunkedSoAPool        │ 8-20       │ N/A(批量)  │ 8-15             │
// │ (分块+对齐+SoA)       │            │            │ (缓存行对齐优势) │
// └───────────────────────┴────────────┴────────────┴──────────────────┘
//
// 关键观察：
//   1. 分配速度：Pool和ChunkedPool都比malloc快5-20倍
//      → 原因：无需搜索空闲链表、无锁（单线程场景）
//   2. 遍历速度：ChunkedSoAPool最优，因为数据缓存行对齐且紧凑
//      → 预取器可以同时追踪多个数组流
//   3. ChunkedSoAPool的释放采用批量策略（清空整个Chunk），
//      不适合频繁的单个元素释放——这恰好契合DOD的设计哲学：
//      数据的生命周期应该与系统阶段对齐，而不是与单个对象绑定

} // namespace dod::hotcold
```

---

#### 3.5 Slot Map（句柄映射）模式

```cpp
// ==========================================
// Slot Map：DOD中的安全引用
// ==========================================
//
// DOD用数组索引代替指针，但裸索引有一个致命问题：
//   如果索引i处的实体被删除，而其他地方还持有索引i，
//   下次使用索引i时会访问到一个完全不同的实体（复用了该位置）。
//   → 悬空索引（dangling index），类似于悬空指针。
//
// Slot Map通过"代际"（generation）解决这个问题：
//   Handle = (index, generation)
//   每次slot被回收时generation+1
//   访问时检查handle.generation == slot.generation
//   如果不匹配 → handle已失效（实体已删除）
//
// 这是DOD世界中的"安全引用"机制，
// 在游戏引擎中被广泛使用（Rust的generational-arena, C++的entt sparse_set等）。

#include <vector>
#include <cstdint>
#include <optional>
#include <cassert>
#include <iostream>

namespace dod::hotcold {

// 句柄：外部持有，用于访问SlotMap中的元素
struct Handle {
    uint32_t index = 0;
    uint32_t generation = 0;

    bool operator==(const Handle& other) const {
        return index == other.index && generation == other.generation;
    }
    bool operator!=(const Handle& other) const { return !(*this == other); }

    // 特殊值：无效句柄
    static Handle invalid() { return {UINT32_MAX, 0}; }
    bool isValid() const { return index != UINT32_MAX; }
};

template<typename T>
class SlotMap {
    struct Slot {
        T value;
        uint32_t generation = 0;
        bool occupied = false;
    };

    std::vector<Slot> slots_;
    std::vector<uint32_t> freeList_;  // 空闲slot索引

public:
    SlotMap() = default;

    explicit SlotMap(size_t initialCapacity) {
        slots_.reserve(initialCapacity);
        freeList_.reserve(initialCapacity);
    }

    // 插入元素，返回句柄
    Handle insert(T value) {
        uint32_t index;

        if (!freeList_.empty()) {
            index = freeList_.back();
            freeList_.pop_back();
        } else {
            index = static_cast<uint32_t>(slots_.size());
            slots_.emplace_back();
        }

        auto& slot = slots_[index];
        slot.value = std::move(value);
        slot.occupied = true;
        // generation在remove时已经递增过了，这里直接使用

        return {index, slot.generation};
    }

    // 通过句柄移除
    bool remove(Handle handle) {
        if (!isValidHandle(handle)) return false;

        auto& slot = slots_[handle.index];
        slot.occupied = false;
        slot.generation++;  // 递增代际，使所有现有句柄失效
        freeList_.push_back(handle.index);

        return true;
    }

    // 通过句柄访问（安全）
    T* get(Handle handle) {
        if (!isValidHandle(handle)) return nullptr;
        return &slots_[handle.index].value;
    }

    const T* get(Handle handle) const {
        if (!isValidHandle(handle)) return nullptr;
        return &slots_[handle.index].value;
    }

    // 检查句柄是否有效
    bool isValidHandle(Handle handle) const {
        return handle.index < slots_.size() &&
               slots_[handle.index].occupied &&
               slots_[handle.index].generation == handle.generation;
    }

    // 遍历所有活跃元素（跳过空slot）
    template<typename Func>
    void forEach(Func&& func) {
        for (size_t i = 0; i < slots_.size(); ++i) {
            if (slots_[i].occupied) {
                func(Handle{static_cast<uint32_t>(i), slots_[i].generation},
                     slots_[i].value);
            }
        }
    }

    size_t size() const {
        return slots_.size() - freeList_.size();
    }

    size_t capacity() const {
        return slots_.size();
    }
};

// 使用示例
void slotMapDemo() {
    struct Enemy {
        float x, y;
        int hp;
    };

    SlotMap<Enemy> enemies;

    // 创建实体
    Handle goblin = enemies.insert({10, 20, 100});
    Handle dragon = enemies.insert({50, 60, 500});
    Handle slime  = enemies.insert({30, 40, 50});

    // 通过句柄访问——安全
    if (auto* e = enemies.get(goblin)) {
        std::cout << "Goblin HP: " << e->hp << "\n";
    }

    // 删除slime
    enemies.remove(slime);

    // slime的句柄现在无效——安全检测
    if (enemies.get(slime) == nullptr) {
        std::cout << "Slime handle is now stale (entity was destroyed)\n";
    }

    // 即使新实体复用了slime的slot，旧句柄仍然无效
    Handle newEntity = enemies.insert({70, 80, 200});
    // newEntity可能复用了slime的index，但generation已经不同
    assert(enemies.get(slime) == nullptr);  // 旧句柄仍然安全失效

    std::cout << "Active enemies: " << enemies.size() << "\n";
}

} // namespace dod::hotcold
```

---

#### 3.6 数据导向的实体系统（ECS前奏）

```cpp
// ==========================================
// 从热/冷分离到组件化：ECS的思想基础
// ==========================================
//
// 本月学习的热/冷数据分离，本质上是在回答一个问题：
//   "哪些数据应该放在一起？"
//
// 传统OOP的回答：属于同一个对象的数据放在一起（Entity类）
// DOD的回答：被同一段代码同时访问的数据放在一起
//
// 当我们把这个思想推到极致：
//   1. 实体（Entity）不存储任何数据，只是一个ID
//   2. 数据按"组件"分类，每种组件独立存储（SoA）
//   3. "系统"是操作特定组件组合的函数
//
// 这就是ECS（Entity-Component-System）架构，
// 将在下个月（Month 52）深入学习。
//
// 本节是概念预览，展示如何从热/冷分离自然演化到ECS。

#include <vector>
#include <bitset>
#include <cstdint>
#include <unordered_map>
#include <typeindex>
#include <any>
#include <functional>

namespace dod::hotcold {

// 简化的ECS预览实现
using Entity = uint32_t;
constexpr size_t MAX_COMPONENTS = 64;
using ComponentMask = std::bitset<MAX_COMPONENTS>;

// 组件类型ID分配器
class ComponentRegistry {
    static inline uint32_t nextId_ = 0;

public:
    template<typename T>
    static uint32_t getId() {
        static uint32_t id = nextId_++;
        return id;
    }
};

// 简化的组件存储（概念展示）
class SimpleECS {
    // 每种组件类型对应一个数组
    std::unordered_map<uint32_t, std::vector<uint8_t>> componentArrays_;
    std::unordered_map<uint32_t, size_t> componentSizes_;

    // 每个实体的组件掩码
    std::vector<ComponentMask> entityMasks_;
    std::vector<bool> alive_;
    uint32_t nextEntity_ = 0;

public:
    Entity createEntity() {
        Entity e = nextEntity_++;
        if (e >= entityMasks_.size()) {
            entityMasks_.resize(e + 1);
            alive_.resize(e + 1, false);
        }
        alive_[e] = true;
        return e;
    }

    template<typename T>
    void addComponent(Entity e, const T& value) {
        uint32_t typeId = ComponentRegistry::getId<T>();

        // 确保数组足够大
        if (componentArrays_.find(typeId) == componentArrays_.end()) {
            componentArrays_[typeId] = {};
            componentSizes_[typeId] = sizeof(T);
        }

        auto& array = componentArrays_[typeId];
        size_t needed = (e + 1) * sizeof(T);
        if (array.size() < needed) {
            array.resize(needed, 0);
        }

        // 存储组件数据
        std::memcpy(&array[e * sizeof(T)], &value, sizeof(T));

        // 更新掩码
        entityMasks_[e].set(typeId);
    }

    template<typename T>
    T* getComponent(Entity e) {
        uint32_t typeId = ComponentRegistry::getId<T>();
        if (!entityMasks_[e].test(typeId)) return nullptr;

        auto& array = componentArrays_[typeId];
        return reinterpret_cast<T*>(&array[e * sizeof(T)]);
    }

    // 遍历所有拥有指定组件组合的实体
    // 这就是ECS"System"的核心操作
    template<typename... Components, typename Func>
    void forEach(Func&& func) {
        ComponentMask required;
        (required.set(ComponentRegistry::getId<Components>()), ...);

        for (Entity e = 0; e < entityMasks_.size(); ++e) {
            if (alive_[e] && (entityMasks_[e] & required) == required) {
                func(e, *getComponent<Components>(e)...);
            }
        }
    }
};

// 使用示例——展示ECS思想
void ecsPreview() {
    struct Position { float x, y, z; };
    struct Velocity { float vx, vy, vz; };
    struct Health   { float hp, maxHp; };
    struct Name     { char name[32]; };

    SimpleECS world;

    // 创建实体
    Entity player = world.createEntity();
    world.addComponent(player, Position{0, 0, 0});
    world.addComponent(player, Velocity{1, 0, 0});
    world.addComponent(player, Health{100, 100});
    world.addComponent(player, Name{"Player"});

    Entity bullet = world.createEntity();
    world.addComponent(bullet, Position{0, 0, 0});
    world.addComponent(bullet, Velocity{10, 0, 0});
    // bullet没有Health和Name——这就是组件化的灵活性

    // "移动系统"——只操作Position和Velocity
    float dt = 0.016f;
    world.forEach<Position, Velocity>([dt](Entity e, Position& pos, Velocity& vel) {
        pos.x += vel.vx * dt;
        pos.y += vel.vy * dt;
        pos.z += vel.vz * dt;
    });
    // 这段代码只访问Position和Velocity数组
    // Health和Name完全不被触碰——完美的热/冷分离！
}

} // namespace dod::hotcold
```

**ECS数据访问模式分析**

ECS的性能优势本质上源于对数据访问模式的深入理解。下面我们分析不同的
访问模式如何映射到底层内存操作，并实现一个基于Archetype的存储方案。

**ECS查询如何映射到SoA迭代**

```
顺序访问（理想情况）——forEach<Position, Velocity>：

Position数组:  [P0][P1][P2][P3][P4][P5][P6][P7] ...
                ↓   ↓   ↓   ↓   ↓   ↓   ↓   ↓
               顺序读取，预取器完美预测

Velocity数组:  [V0][V1][V2][V3][V4][V5][V6][V7] ...
                ↓   ↓   ↓   ↓   ↓   ↓   ↓   ↓
               同样顺序读取，两条流并行预取

缓存行利用率：100%（每读入一行都完整使用）


随机访问（稀疏实体）——按entity ID间接查找：

Position数组:  [P0][P1][P2][P3][P4][P5][P6][P7] ...
                ↓           ↓               ↓
               访问0       访问3           访问6
               → 缓存行中大部分数据被浪费

Archetype方案——同类实体紧凑存储：

Archetype A (Position+Velocity):
  Position: [PA0][PA1][PA2][PA3] ...    ← 只含拥有这两个组件的实体
  Velocity: [VA0][VA1][VA2][VA3] ...    ← 1:1对应，无空洞

Archetype B (Position+Velocity+Health):
  Position: [PB0][PB1] ...
  Velocity: [VB0][VB1] ...
  Health:   [HB0][HB1] ...

查询 forEach<Position, Velocity> 时：
  → 先遍历Archetype A的全部行（紧凑，100%命中）
  → 再遍历Archetype B的全部行（同样紧凑）
  → 跳过不含Position或Velocity的Archetype
```

```cpp
// ==========================================
// Archetype存储：按组件组合分组实体
// ==========================================
//
// 核心思想：拥有相同组件集合的实体存储在同一个Archetype中
// 这样每个Archetype内部的数组都是紧凑的，没有空洞
//
// 为什么这比SimpleECS更好？
//   SimpleECS用entity ID做索引，实体被删除后会留下空洞
//   Archetype内部用紧凑数组 + swap-remove，永远没有空洞
//   → 遍历时缓存行利用率始终为100%
//
// 这是 flecs、Unity DOTS、EnTT(部分) 等现代ECS的基础

#include <vector>
#include <cstdint>
#include <cstring>
#include <unordered_map>
#include <memory>
#include <bitset>
#include <cassert>
#include <algorithm>
#include <functional>

namespace dod::hotcold {

// ========== Archetype存储实现 ==========

constexpr size_t MAX_COMP_TYPES = 64;
using ArchetypeMask = std::bitset<MAX_COMP_TYPES>;

// 组件类型元信息
struct ComponentTypeInfo {
    uint32_t id;       // 全局唯一的组件类型ID
    size_t size;       // sizeof(T)
    size_t alignment;  // alignof(T)
};

// 单个Archetype：存储拥有完全相同组件集合的所有实体
class ArchetypeStorage {
public:
    // 每列对应一种组件，列内是该组件的紧凑数组
    struct ColumnHeader {
        uint32_t componentId;
        size_t elementSize;
        // 原始字节存储——实际生产代码应使用对齐分配
        std::vector<uint8_t> data;
    };

private:
    ArchetypeMask mask_;                         // 此Archetype包含哪些组件
    std::vector<ColumnHeader> columns_;          // 每种组件一列（SoA布局）
    std::vector<uint32_t> entities_;             // 实体ID列表（与行号一一对应）
    // 反向映射：entity ID → 在此Archetype中的行号
    std::unordered_map<uint32_t, size_t> entityToRow_;

public:
    explicit ArchetypeStorage(ArchetypeMask mask,
                              const std::vector<ComponentTypeInfo>& types)
        : mask_(mask) {
        // 为掩码中的每个组件创建一列
        for (const auto& info : types) {
            if (mask.test(info.id)) {
                columns_.push_back({info.id, info.size, {}});
            }
        }
    }

    const ArchetypeMask& mask() const { return mask_; }
    size_t entityCount() const { return entities_.size(); }

    // 添加实体，返回行号
    size_t addEntity(uint32_t entityId) {
        size_t row = entities_.size();
        entities_.push_back(entityId);
        entityToRow_[entityId] = row;

        // 每列扩展一个元素的空间（新元素零初始化）
        for (auto& col : columns_) {
            col.data.resize(col.data.size() + col.elementSize, 0);
        }
        return row;
    }

    // 设置指定行、指定组件的数据
    template<typename T>
    void setComponent(size_t row, uint32_t componentId, const T& value) {
        for (auto& col : columns_) {
            if (col.componentId == componentId) {
                assert(sizeof(T) == col.elementSize);
                std::memcpy(&col.data[row * col.elementSize], &value, sizeof(T));
                return;
            }
        }
    }

    // swap-remove：将最后一行交换到被删除行，保持紧凑
    // 这是DOD的经典删除策略——O(1)删除，永远没有空洞
    void removeEntity(uint32_t entityId) {
        auto it = entityToRow_.find(entityId);
        if (it == entityToRow_.end()) return;

        size_t row = it->second;
        size_t lastRow = entities_.size() - 1;

        if (row != lastRow) {
            // 将最后一行的数据复制到被删除行（所有列都要处理）
            uint32_t movedEntity = entities_[lastRow];
            for (auto& col : columns_) {
                std::memcpy(&col.data[row * col.elementSize],
                            &col.data[lastRow * col.elementSize],
                            col.elementSize);
            }
            entities_[row] = movedEntity;
            entityToRow_[movedEntity] = row;
        }

        // 缩减所有数组
        entities_.pop_back();
        for (auto& col : columns_) {
            col.data.resize(col.data.size() - col.elementSize);
        }
        entityToRow_.erase(entityId);
    }

    // 获取指定组件列的原始指针——供System遍历使用
    // 返回的指针指向紧凑数组，可以安全做指针算术
    void* getColumnData(uint32_t componentId) {
        for (auto& col : columns_) {
            if (col.componentId == componentId) {
                return col.data.data();
            }
        }
        return nullptr;
    }

    const void* getColumnData(uint32_t componentId) const {
        for (const auto& col : columns_) {
            if (col.componentId == componentId) {
                return col.data.data();
            }
        }
        return nullptr;
    }

    // 获取实体列表——System可能需要知道entity ID
    const std::vector<uint32_t>& entities() const { return entities_; }

    // 判断此Archetype是否包含查询所需的所有组件
    bool matchesQuery(ArchetypeMask queryMask) const {
        return (mask_ & queryMask) == queryMask;
    }
};

// ========== 访问模式性能分析 ==========
//
// 随机访问 vs 顺序访问的量化对比：
//
// 假设：10000个实体，Position = 12字节，缓存行 = 64字节
//
// ┌─────────────────────┬──────────────┬──────────────┬──────────────┐
// │ 访问模式            │ 缓存行加载数 │ 有效字节比   │ 相对耗时     │
// ├─────────────────────┼──────────────┼──────────────┼──────────────┤
// │ Archetype顺序遍历   │ ~1,875       │ 100%         │ 1x (基准)    │
// │ 稀疏数组顺序遍历    │ ~1,875       │ 30-80%       │ 1.2-3x       │
// │ (含空洞)            │              │ (取决于密度) │              │
// │ 随机ID查表          │ ~10,000      │ 12/64 ≈ 19%  │ 5-20x        │
// │ (完全随机)          │              │              │              │
// │ 链表遍历            │ ~10,000      │ ~19%         │ 10-50x       │
// │ (指针追踪)          │              │              │ (+ TLB miss) │
// └─────────────────────┴──────────────┴──────────────┴──────────────┘
//
// 关键结论：
//   1. Archetype模式下，查询只接触匹配的Archetype
//      → 不相关的组件完全不会被加载到缓存
//   2. 即使查询需要遍历多个Archetype，每个内部都是100%利用率
//   3. 添加/删除组件需要在Archetype间迁移实体（有开销）
//      → 这就是为什么ECS建议避免频繁动态添加/删除组件
//   4. Archetype数量爆炸时（过多组件组合），遍历开销增加
//      → 实践中通常只有几十到几百个Archetype，不会成为瓶颈

} // namespace dod::hotcold
```

---

#### 3.7 多线程场景下的数据分离

```cpp
// ==========================================
// 多线程DOD：双缓冲与线程本地存储
// ==========================================
//
// 多线程是DOD性能的放大器，但也引入了新的数据分离需求：
//
// 1. 读写分离：渲染线程读取位置数据时，
//    物理线程不应该修改同一份数据。
//    → 双缓冲：维护两份数据，轮流读写
//
// 2. 线程本地累加：多个线程需要更新同一个数组时，
//    每个线程累加到本地缓冲区，最后合并。
//    → 消除伪共享，消除锁
//
// 3. 任务划分：按数据范围而非功能划分任务。
//    线程A更新粒子[0, N/4)，线程B更新[N/4, N/2)...
//    → 每个线程操作不同的缓存行，零竞争

#include <atomic>
#include <thread>
#include <vector>
#include <array>
#include <functional>

namespace dod::hotcold {

// ──────────────────────────────────────
// 双缓冲SoA
// ──────────────────────────────────────
//
// 物理线程写buffer A → 渲染线程读buffer B
// 帧结束时交换
// → 读写永不冲突，无锁

template<typename T>
class DoubleBuffered {
    std::vector<T> buffers_[2];
    std::atomic<int> readIndex_{0};

public:
    void resize(size_t n) {
        buffers_[0].resize(n);
        buffers_[1].resize(n);
    }

    // 获取当前读缓冲区（渲染线程调用）
    const std::vector<T>& readBuffer() const {
        return buffers_[readIndex_.load(std::memory_order_acquire)];
    }

    // 获取当前写缓冲区（物理线程调用）
    std::vector<T>& writeBuffer() {
        return buffers_[1 - readIndex_.load(std::memory_order_acquire)];
    }

    // 帧结束时交换（在同步点调用）
    void swap() {
        readIndex_.store(1 - readIndex_.load(std::memory_order_relaxed),
                         std::memory_order_release);
    }
};

struct DoubleBufferedParticles {
    DoubleBuffered<float> x, y, z;    // 位置双缓冲
    std::vector<float> vx, vy, vz;    // 速度不需要双缓冲（只在物理线程用）
    std::vector<float> life;

    void resize(size_t n) {
        x.resize(n); y.resize(n); z.resize(n);
        vx.resize(n); vy.resize(n); vz.resize(n);
        life.resize(n);
    }

    // 物理线程：写入新位置
    void updatePhysics(float dt, size_t count) {
        auto& wx = x.writeBuffer();
        auto& wy = y.writeBuffer();
        auto& wz = z.writeBuffer();
        const auto& rx = x.readBuffer();  // 读取上一帧位置
        const auto& ry = y.readBuffer();
        const auto& rz = z.readBuffer();

        for (size_t i = 0; i < count; ++i) {
            wx[i] = rx[i] + vx[i] * dt;
            wy[i] = ry[i] + vy[i] * dt;
            wz[i] = rz[i] + vz[i] * dt;
        }
    }

    // 渲染线程：读取位置（完全不阻塞）
    void render(size_t count) const {
        const auto& rx = x.readBuffer();
        const auto& ry = y.readBuffer();
        const auto& rz = z.readBuffer();

        for (size_t i = 0; i < count; ++i) {
            // drawParticle(rx[i], ry[i], rz[i]);
            volatile float sink = rx[i] + ry[i] + rz[i];
            (void)sink;
        }
    }

    // 帧同步点
    void swapBuffers() {
        x.swap(); y.swap(); z.swap();
    }
};

} // namespace dod::hotcold
```

---

#### 3.8 本周练习任务

```
练习1：数据温度分析
──────────────────
目标：分析一个游戏实体系统的字段访问频率

要求：
1. 使用ProfiledField包装器，创建一个包含10个字段的实体
2. 模拟10000帧游戏循环：每帧更新位置和速度，每100帧检查生命值，
   每1000帧访问名字
3. 输出每个字段的访问频率报告
4. 根据结果提出最优的热/冷分离方案

验证：
- 输出的热/冷分类应合理
- 热数据字段应少于总字段的30%，但占访问总量的90%以上

练习2：SlotMap实现与测试
─────────────────────
目标：实现完整的SlotMap并进行压力测试

要求：
1. 实现SlotMap<T>，支持insert, remove, get, forEach
2. 压力测试：随机插入/删除100万个元素，随机访问（包含过期句柄）
3. 验证所有过期句柄返回nullptr（安全性）
4. 与std::unordered_map<uint32_t, T>做性能对比

验证：
- 零次错误地访问到已删除的元素
- 插入/删除性能比unordered_map快5-10倍
- 遍历性能比unordered_map快3-5倍

练习3：内存池基准测试
──────────────────
目标：比较PoolAllocator与标准分配器的性能

要求：
1. 实现PoolAllocator（固定大小32/64/128字节）
2. 测试场景：分配100万个对象，随机释放50%，再分配50万
3. 对比malloc/free、new/delete、PoolAllocator的吞吐量
4. 检查内存碎片情况

验证：
- PoolAllocator分配速度比malloc快5-20倍
- 内存碎片为零（连续分配的对象在内存中仍然连续）

练习4：完整实体管理器
──────────────────
目标：构建一个综合运用本周所有技术的实体管理器

要求：
1. 支持创建/销毁实体（SlotMap句柄）
2. 热/冷/温数据三层分离
3. 热数据使用SoA + 缓存行对齐
4. 标志位使用BitArray紧凑存储
5. 支持按组件掩码遍历活跃实体
6. 100万实体的遍历性能测试

验证：
- 热路径遍历速度与纯数组遍历相当（<2x开销）
- 创建/销毁实体O(1)
- 句柄安全性：删除后的句柄不会访问到新实体
```

---

#### 3.9 本周知识检验

```
思考题1：为什么代际索引（generational index）比weak_ptr更适合DOD？
         从性能和内存布局两个角度分析。

思考题2：热/冷数据分离如何影响游戏状态的序列化（存档/读档）？
         是否需要在保存时重新组装完整实体？

思考题3：位打包何时会适得其反？
         给出一个具体场景，说明解压开销超过缓存收益的情况。

思考题4：ECS的Archetype模式如何将热/冷分离推广到N种温度？
         提示：每种Archetype就是一种独特的温度组合。

思考题5：双缓冲与互斥锁相比，各自的优缺点是什么？
         在什么场景下互斥锁反而更好？

实践题1：
  给定一个MMORPG角色的数据结构：
  position(12B), velocity(12B), rotation(4B), hp(4B), mp(4B),
  name(32B), guild(32B), inventory(256B), quest_log(128B), chat_history(512B)
  设计最优的热/温/冷分离方案，计算每种温度层的缓存行利用率

实践题2：
  设计一个SlotMap变体：DenseSlotMap
  要求：遍历时没有空洞（不需要检查occupied标志）
  提示：维护一个紧凑的数据数组 + 一个稀疏的重定向表
```

### 第四周：批处理与预取（35小时）

**学习目标**：
- [ ] 掌握软件预取策略（时间性/非时间性），理解预取距离的调优方法
- [ ] 理解并实践循环分块（Loop Tiling）在多遍算法中的应用
- [ ] 掌握非时间性存储（streaming store）及其在输出密集场景中的优势
- [ ] 理解分支预测对DOD的影响，掌握排序批处理和无分支编程技术
- [ ] 学会使用缓存一致性排序（Morton码排序）优化空间查询
- [ ] 了解数据压缩/解压缩友好的内存布局设计
- [ ] 能够将全月所学DOD技术集成为完整的优化管线

**阅读材料**：
- [ ] Intel Intrinsics Guide - Prefetch/Stream相关指令
- [ ] 《Hacker's Delight》- 无分支编程技术
- [ ] Agner Fog《Optimizing software in C++》- Chapter 11: Out of order execution
- [ ] CppCon 2019：《There Are No Zero-cost Abstractions》- Chandler Carruth
- [ ] 《Is Parallel Programming Hard, And, If So, What Can You Do About It?》- Paul McKenney
- [ ] ARM NEON Programmer's Guide - 预取章节
- [ ] Daniel Lemire博客 - 无分支编程系列

---

#### 核心概念

```cpp
// 非批处理：大量函数调用开销
class ProcessorBad {
public:
    void processOne(Entity& e) {
        e.x += e.vx;
        e.y += e.vy;
    }

    void processAll(std::vector<Entity>& entities) {
        for (auto& e : entities) {
            processOne(e);  // 每次调用都有开销
        }
    }
};

// 批处理：减少函数调用，利用缓存
class ProcessorGood {
public:
    void processBatch(float* x, float* y,
                      const float* vx, const float* vy,
                      size_t count) {
        for (size_t i = 0; i < count; ++i) {
            x[i] += vx[i];
            y[i] += vy[i];
        }
    }
};
```

---

#### 4.1 软件预取策略深度解析

```cpp
// ==========================================
// 软件预取：提前告诉CPU你要什么数据
// ==========================================
//
// 硬件预取器（Hardware Prefetcher）在顺序访问时工作良好，
// 但在以下场景中失效：
//   - 链表遍历（指针追踪）
//   - 哈希表查找（随机跳转）
//   - 间接访问（通过索引数组）
//   - 步长不规则的访问
//
// 软件预取让程序员主动告知CPU"我即将需要这个地址的数据"。
// CPU会在后台异步加载数据到缓存，当程序真正访问时已经就绪。
//
// 预取提示（Hint）：
//   _MM_HINT_T0:  预取到所有缓存级别（L1+L2+L3）
//   _MM_HINT_T1:  预取到L2+L3（不污染L1）
//   _MM_HINT_T2:  预取到L3
//   _MM_HINT_NTA: 非时间性预取（用完即丢，不污染缓存）
//
// 预取距离（Prefetch Distance）：
//   提前多少个元素预取？取决于两个因素：
//   1. 内存延迟：~60ns（DRAM）
//   2. 每个元素的处理时间：假设5ns
//   → 最优距离 ≈ 60/5 = 12个元素
//
//   太近：数据还没到达就要用了（miss）
//   太远：预取的数据被后来的访问驱逐出缓存（浪费）

#include <cstddef>
#include <chrono>
#include <vector>
#include <iostream>
#include <cmath>
#include <random>
#include <algorithm>

#ifdef __SSE__
#include <xmmintrin.h>  // _mm_prefetch
#endif

namespace dod::batch {

// ──────────────────────────────────────
// 预取距离自动调优器
// ──────────────────────────────────────

class PrefetchTuner {
public:
    template<typename Func>
    static size_t findOptimalDistance(float* data, size_t count, Func process) {
        size_t bestDistance = 0;
        double bestTime = 1e18;

        for (size_t dist = 0; dist <= 32; dist += 4) {
            auto start = std::chrono::high_resolution_clock::now();

            for (size_t i = 0; i < count; ++i) {
                if (dist > 0 && i + dist * 16 < count) {
                    _mm_prefetch(reinterpret_cast<const char*>(&data[i + dist * 16]),
                                 _MM_HINT_T0);
                }
                process(data[i]);
            }

            auto end = std::chrono::high_resolution_clock::now();
            double time = std::chrono::duration<double, std::milli>(end - start).count();

            if (time < bestTime) {
                bestTime = time;
                bestDistance = dist;
            }
        }

        return bestDistance;
    }
};

// ──────────────────────────────────────
// 链表遍历的预取优化
// ──────────────────────────────────────
//
// 这是软件预取最经典的应用场景：
// 硬件预取器完全无法预测链表的下一个节点地址。
// 但程序员知道：当前节点的next指针就指向下一个节点。
// 在处理当前节点的同时，预取下一个（或下下个）节点。

struct alignas(64) ListNode {
    ListNode* next;
    float data[15];  // 填满64字节（一个缓存行）
};

// 无预取版本
double traverseNoPrefetch(ListNode* head, size_t count) {
    volatile float sum = 0;
    auto start = std::chrono::high_resolution_clock::now();

    ListNode* current = head;
    while (current) {
        sum += current->data[0];
        current = current->next;
    }

    auto end = std::chrono::high_resolution_clock::now();
    return std::chrono::duration<double, std::milli>(end - start).count();
}

// 单步预取版本
double traverseWithPrefetch(ListNode* head, size_t count) {
    volatile float sum = 0;
    auto start = std::chrono::high_resolution_clock::now();

    ListNode* current = head;
    while (current) {
        // 预取下一个节点（当CPU处理当前节点时，下一个节点正在加载）
        if (current->next) {
            _mm_prefetch(reinterpret_cast<const char*>(current->next), _MM_HINT_T0);
        }
        sum += current->data[0];
        current = current->next;
    }

    auto end = std::chrono::high_resolution_clock::now();
    return std::chrono::duration<double, std::milli>(end - start).count();
}

// 双步预取版本（提前两步）
double traverseWithDoublePrefetch(ListNode* head, size_t count) {
    volatile float sum = 0;
    auto start = std::chrono::high_resolution_clock::now();

    ListNode* current = head;
    // 预取前两个节点
    if (current && current->next) {
        _mm_prefetch(reinterpret_cast<const char*>(current->next), _MM_HINT_T0);
        if (current->next->next) {
            _mm_prefetch(reinterpret_cast<const char*>(current->next->next), _MM_HINT_T0);
        }
    }

    while (current) {
        // 预取当前节点后第二个节点
        if (current->next && current->next->next) {
            _mm_prefetch(reinterpret_cast<const char*>(current->next->next), _MM_HINT_T0);
        }

        sum += current->data[0];
        current = current->next;
    }

    auto end = std::chrono::high_resolution_clock::now();
    return std::chrono::duration<double, std::milli>(end - start).count();
}

} // namespace dod::batch
```

---

#### 4.2 循环分块（Loop Tiling）

```cpp
// ==========================================
// 循环分块：让每个缓存行被充分利用
// ==========================================
//
// 场景：粒子系统更新需要多个"遍"(pass)：
//   Pass 1: 应用重力 vy += gravity * dt
//   Pass 2: 更新位置 x += vx * dt
//   Pass 3: 碰撞检测
//   Pass 4: 更新生命值 life -= dt
//
// 不分块：每个pass遍历整个数组
//   Pass 1 加载全部vy到缓存 → Pass 2需要x,vx → vy被驱逐
//   Pass 2 加载全部x,vx → Pass 3需要其他数据 → x,vx被驱逐
//   结果：每个pass都重新从DRAM加载
//
// 分块：将数组分成L1大小的块
//   对Block[0]: Pass1→Pass2→Pass3→Pass4（数据全在L1中）
//   对Block[1]: Pass1→Pass2→Pass3→Pass4
//   结果：每块数据只从DRAM加载一次
//
// 最优块大小选择：
//   同时活跃的数组数 × 块大小 × sizeof(float) < L1D大小
//   例如：6个数组 × TILE × 4字节 < 32KB
//   TILE < 32KB / 24 ≈ 1365
//   取TILE = 1024（2的幂，对齐友好）

#include <vector>
#include <chrono>
#include <iostream>
#include <algorithm>
#include <cmath>

namespace dod::batch {

struct ParticleSoA {
    std::vector<float> x, y, z;
    std::vector<float> vx, vy, vz;
    std::vector<float> life;

    void resize(size_t n) {
        x.resize(n); y.resize(n); z.resize(n);
        vx.resize(n); vy.resize(n); vz.resize(n);
        life.resize(n);
    }

    size_t size() const { return x.size(); }
};

// 不分块：多遍遍历整个数组
void updateMultiPassNaive(ParticleSoA& p, float dt, float gravity) {
    const size_t n = p.size();

    // Pass 1: 重力
    for (size_t i = 0; i < n; ++i) {
        p.vy[i] += gravity * dt;
    }

    // Pass 2: 位置
    for (size_t i = 0; i < n; ++i) {
        p.x[i] += p.vx[i] * dt;
        p.y[i] += p.vy[i] * dt;
        p.z[i] += p.vz[i] * dt;
    }

    // Pass 3: 地面碰撞
    for (size_t i = 0; i < n; ++i) {
        if (p.y[i] < 0) {
            p.y[i] = 0;
            p.vy[i] = -p.vy[i] * 0.6f;
        }
    }

    // Pass 4: 生命值
    for (size_t i = 0; i < n; ++i) {
        p.life[i] -= dt;
    }
}

// 分块：每个块内完成所有pass
void updateMultiPassTiled(ParticleSoA& p, float dt, float gravity) {
    const size_t n = p.size();
    constexpr size_t TILE = 1024;  // L1友好的块大小

    for (size_t tile = 0; tile < n; tile += TILE) {
        size_t end = std::min(tile + TILE, n);

        // 这个块的所有pass——数据始终在L1中
        // Pass 1: 重力
        for (size_t i = tile; i < end; ++i) {
            p.vy[i] += gravity * dt;
        }

        // Pass 2: 位置
        for (size_t i = tile; i < end; ++i) {
            p.x[i] += p.vx[i] * dt;
            p.y[i] += p.vy[i] * dt;
            p.z[i] += p.vz[i] * dt;
        }

        // Pass 3: 碰撞
        for (size_t i = tile; i < end; ++i) {
            if (p.y[i] < 0) {
                p.y[i] = 0;
                p.vy[i] = -p.vy[i] * 0.6f;
            }
        }

        // Pass 4: 生命值
        for (size_t i = tile; i < end; ++i) {
            p.life[i] -= dt;
        }
    }
}

void benchmarkTiling() {
    constexpr size_t N = 2'000'000;
    constexpr int ITERATIONS = 50;
    constexpr float DT = 0.016f;
    constexpr float GRAVITY = -9.8f;

    ParticleSoA particles;
    particles.resize(N);

    // 初始化
    for (size_t i = 0; i < N; ++i) {
        particles.x[i] = particles.y[i] = particles.z[i] = 0;
        particles.vx[i] = 1; particles.vy[i] = 10; particles.vz[i] = 1;
        particles.life[i] = 5;
    }

    // 不分块
    auto start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < ITERATIONS; ++i) {
        updateMultiPassNaive(particles, DT, GRAVITY);
    }
    auto end = std::chrono::high_resolution_clock::now();
    double naiveTime = std::chrono::duration<double, std::milli>(end - start).count();

    // 重置
    for (size_t i = 0; i < N; ++i) {
        particles.y[i] = 10; particles.vy[i] = 10; particles.life[i] = 5;
    }

    // 分块
    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < ITERATIONS; ++i) {
        updateMultiPassTiled(particles, DT, GRAVITY);
    }
    end = std::chrono::high_resolution_clock::now();
    double tiledTime = std::chrono::duration<double, std::milli>(end - start).count();

    std::cout << "===== Loop Tiling Benchmark =====\n"
              << "Naive multi-pass:  " << naiveTime << " ms\n"
              << "Tiled multi-pass:  " << tiledTime << " ms\n"
              << "Speedup:           " << (naiveTime / tiledTime) << "x\n";
}

} // namespace dod::batch
```

**循环分块高级模式**

上面展示了一维数组的基础分块。实际项目中经常遇到二维甚至三维数据（图像、网格、体素），
此时分块策略更加关键。以下内容深入探讨高级分块模式。

**二维分块遍历 vs 逐行遍历：**

```
朴素行优先遍历（Row-major）              二维分块遍历（2D Tiled）

┌──────────────────────────┐          ┌──┬──┬──┬──┬──┬──┐
│ 1  2  3  4  5  6  7  8  │          │1 │5 │9 │  │  │  │
│ 9  10 11 12 13 14 15 16  │          │2 │6 │10│  │  │  │
│ 17 18 19 20 21 22 23 24  │          │3 │7 │11│  │  │  │
│ 25 26 27 28 29 30 31 32  │          │4 │8 │12│  │  │  │
│ 33 34 35 36 37 38 39 40  │          ├──┼──┼──┤  │  │  │
│ 41 42 43 44 45 46 47 48  │          │13│17│  │  │  │  │
└──────────────────────────┘          └──┴──┴──┴──┴──┴──┘

行优先：处理完第1行后，第2行开始时         分块：先遍历4×2的小块（编号1-4），
第1行的缓存行已被后续行驱逐。             再遍历右侧相邻块（编号5-8），以此类推。
卷积运算需要上下行数据→cache miss严重      同一块内的3行数据都在L1中，卷积运算
                                       的邻域数据全部命中。
```

**Cache-Oblivious vs Cache-Aware 对比：**

| 特性 | Cache-Aware (显式分块) | Cache-Oblivious (递归分块) |
|------|----------------------|---------------------------|
| 需要知道缓存大小 | 是，TILE需要手动调优 | 否，自动适应所有缓存层级 |
| 实现复杂度 | 低，双层循环即可 | 高，需要递归分治 |
| 性能（最优情况） | 最优，TILE精确匹配L1 | 接近最优，多出O(log N)因子 |
| 可移植性 | 差，不同CPU需不同TILE | 好，同一代码适用所有硬件 |
| 多级缓存利用 | 需要多层分块(L1/L2/L3) | 自动利用所有缓存层级 |
| SIMD配合 | 容易，TILE对齐SIMD宽度 | 较难，递归底层需特殊处理 |
| 典型应用 | 游戏引擎、实时系统 | 科学计算、通用库 |

**分块宽度与SIMD对齐：**

TILE宽度应该是SIMD向量宽度的整数倍。例如AVX2一次处理8个float，
所以TILE_W应为8的倍数（8, 16, 32...）。这样分块内部的内层循环可以
直接被自动向量化，不需要处理边界情况。如果TILE_W=30，那么最后6个元素
需要标量处理，既浪费SIMD吞吐量，又增加了分支开销。

```cpp
// ==========================================
// 高级循环分块：二维分块与递归分块
// ==========================================
//
// 一维分块只能解决"同一数组多遍访问"的问题。
// 对于二维数据（图像处理、矩阵运算），需要二维分块：
//   朴素遍历：逐行处理，卷积核访问上下行时cache miss
//   二维分块：将图像分成小块，每块内完成所有计算
//
// 递归分块（Cache-Oblivious）的核心思想：
//   不指定固定的块大小，而是递归地将问题一分为二，
//   直到子问题足够小以适配任意缓存大小。
//   优点：同一份代码在不同CPU上都接近最优。

#include <vector>
#include <array>
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <iostream>
#include <chrono>
#include <functional>

namespace dod::batch {

// ──────────────────────────────────────
// 二维分块操作类：图像处理场景
// ──────────────────────────────────────
//
// 图像卷积是二维分块的典型应用场景：
//   3×3卷积核需要访问每个像素的8个邻域
//   朴素逐行遍历时，处理第N行需要第N-1行的数据
//   如果图像宽度很大（比如4096像素），N-1行可能已经不在L1中
//   二维分块确保块内所有邻域数据都在缓存中
//
// 为什么卷积特别适合分块？
//   卷积核重叠——相邻像素共享大部分输入数据
//   分块让这些共享数据留在缓存中被反复利用

class TiledMatrixOps {
public:
    // TILE大小选择依据：
    //   输入块：(TILE_H + 2) × (TILE_W + 2) × 4字节（卷积核需要边界）
    //   输出块：TILE_H × TILE_W × 4字节
    //   总计：(34×34 + 32×32) × 4 = 8.7KB，远小于32KB的L1D
    //   留出空间给卷积核和其他变量
    static constexpr size_t TILE_W = 32;  // 32 = 4 × 8(AVX宽度)，SIMD友好
    static constexpr size_t TILE_H = 32;

    // 朴素逐行卷积：对大图像缓存不友好
    static void convolve3x3Naive(
        const float* input, float* output,
        size_t width, size_t height,
        const float kernel[3][3])
    {
        // 从第1行到倒数第2行，跳过边界
        for (size_t y = 1; y + 1 < height; ++y) {
            for (size_t x = 1; x + 1 < width; ++x) {
                float sum = 0.0f;
                // 3×3卷积：需要访问(y-1)行和(y+1)行
                // 当width=4096时，三行数据 = 48KB > L1D(32KB)
                // → (y-1)行在处理到一半时就被驱逐了
                for (int ky = -1; ky <= 1; ++ky) {
                    for (int kx = -1; kx <= 1; ++kx) {
                        sum += input[(y + ky) * width + (x + kx)]
                             * kernel[ky + 1][kx + 1];
                    }
                }
                output[y * width + x] = sum;
            }
        }
    }

    // 二维分块卷积：对大图像保持缓存友好
    // 将图像分成TILE_H × TILE_W的小块逐块处理
    // 每块内的所有输入数据（包括卷积核覆盖的边界）都在L1中
    static void convolve3x3Tiled(
        const float* input, float* output,
        size_t width, size_t height,
        const float kernel[3][3])
    {
        // 外层循环按块遍历——块间遍历顺序不影响缓存效率
        for (size_t ty = 1; ty < height - 1; ty += TILE_H) {
            for (size_t tx = 1; tx < width - 1; tx += TILE_W) {
                // 计算当前块的边界，注意不超出图像范围
                size_t yEnd = std::min(ty + TILE_H, height - 1);
                size_t xEnd = std::min(tx + TILE_W, width - 1);

                // 内层循环处理块内像素
                // 此时(ty-1)到(yEnd)行的(tx-1)到(xEnd)列数据都在L1中
                for (size_t y = ty; y < yEnd; ++y) {
                    for (size_t x = tx; x < xEnd; ++x) {
                        float sum = 0.0f;
                        for (int ky = -1; ky <= 1; ++ky) {
                            for (int kx = -1; kx <= 1; ++kx) {
                                sum += input[(y + ky) * width + (x + kx)]
                                     * kernel[ky + 1][kx + 1];
                            }
                        }
                        output[y * width + x] = sum;
                    }
                }
            }
        }
    }

    // 多遍处理的二维分块：对同一块连续应用多个滤波器
    // 典型场景：模糊 → 边缘检测（常见的图像处理pipeline）
    //
    // 不分块的问题：
    //   Pass 1（模糊）遍历整张图 → temp写满整个图像
    //   Pass 2（边缘检测）读temp → 但temp的前半部分已不在缓存中
    //   1024×1024图像的temp = 4MB，远超任何缓存层级
    //
    // 分块的优势：
    //   对Block[0]：模糊→temp[0]→边缘检测→output[0]
    //   temp[0]只有32×32×4=4KB，全程在L1中
    //   数据只需从主存加载一次
    static void multiPassTiled(
        const float* input, float* output, float* temp,
        size_t width, size_t height,
        const float blur[3][3],
        const float edge[3][3])
    {
        // 需要2像素边界（两遍卷积各需要1像素边界）
        for (size_t ty = 2; ty < height - 2; ty += TILE_H) {
            for (size_t tx = 2; tx < width - 2; tx += TILE_W) {
                size_t yEnd = std::min(ty + TILE_H, height - 2);
                size_t xEnd = std::min(tx + TILE_W, width - 2);

                // Pass 1: 模糊 → temp（块内完成）
                // 需要扩展一圈读取范围给Pass 2使用
                for (size_t y = ty - 1; y <= yEnd; ++y) {
                    for (size_t x = tx - 1; x <= xEnd; ++x) {
                        float sum = 0.0f;
                        for (int ky = -1; ky <= 1; ++ky)
                            for (int kx = -1; kx <= 1; ++kx)
                                sum += input[(y+ky)*width + (x+kx)]
                                     * blur[ky+1][kx+1];
                        temp[y * width + x] = sum;
                    }
                }

                // Pass 2: 边缘检测 → output
                // temp的数据还在L1中！这是分块的核心收益
                for (size_t y = ty; y < yEnd; ++y) {
                    for (size_t x = tx; x < xEnd; ++x) {
                        float sum = 0.0f;
                        for (int ky = -1; ky <= 1; ++ky)
                            for (int kx = -1; kx <= 1; ++kx)
                                sum += temp[(y+ky)*width + (x+kx)]
                                     * edge[ky+1][kx+1];
                        output[y * width + x] = sum;
                    }
                }
            }
        }
    }
};

// ──────────────────────────────────────
// 递归分块（Cache-Oblivious）：矩阵转置
// ──────────────────────────────────────
//
// 矩阵转置是cache-oblivious算法的经典示例。
// 朴素转置：B[j][i] = A[i][j]
//   对A是行访问（连续），对B是列访问（跳跃）
//   列访问 = 每次跳过整个行宽 = 步长为N的访问模式
//   当N很大时，每次列访问都是一次cache miss
//
// 递归策略：将矩阵分为子矩阵，递归处理
//   当子矩阵足够小时（自然适配L1），直接转置
//   无需指定TILE大小——递归分治自动找到最优粒度
//   更妙的是：它同时适配L1、L2、L3所有缓存层级

// 基础情况阈值：子矩阵小于此值时用朴素循环
// 这个值平衡递归调用开销与缓存局部性
// 64×64×4=16KB，对绝大多数L1D都足够小
constexpr size_t RECURSIVE_BASE = 64;

void transposeRecursive(
    const float* A, float* B,
    size_t aRowStride, size_t bRowStride,
    size_t rowStart, size_t rowEnd,
    size_t colStart, size_t colEnd)
{
    size_t rows = rowEnd - rowStart;
    size_t cols = colEnd - colStart;

    // 基础情况：子矩阵足够小，朴素处理即可
    // 此时A和B的子块都能放进L1
    if (rows <= RECURSIVE_BASE && cols <= RECURSIVE_BASE) {
        for (size_t i = rowStart; i < rowEnd; ++i) {
            for (size_t j = colStart; j < colEnd; ++j) {
                B[j * bRowStride + i] = A[i * aRowStride + j];
            }
        }
        return;
    }

    // 递归情况：沿较长维度二分
    // 为什么选较长维度？使子矩阵尽快变"方"，
    // 方形子矩阵对读写两端都有较好的空间局部性
    if (rows >= cols) {
        size_t mid = rowStart + rows / 2;
        transposeRecursive(A, B, aRowStride, bRowStride,
                          rowStart, mid, colStart, colEnd);
        transposeRecursive(A, B, aRowStride, bRowStride,
                          mid, rowEnd, colStart, colEnd);
    } else {
        size_t mid = colStart + cols / 2;
        transposeRecursive(A, B, aRowStride, bRowStride,
                          rowStart, rowEnd, colStart, mid);
        transposeRecursive(A, B, aRowStride, bRowStride,
                          rowStart, rowEnd, mid, colEnd);
    }
}

void benchmarkTiledConvolution() {
    // 用1024×1024图像测试分块卷积的效果
    // 这个尺寸足够大以触发缓存压力（4MB数据）
    constexpr size_t W = 1024;
    constexpr size_t H = 1024;
    constexpr int ITERS = 20;

    std::vector<float> input(W * H, 1.0f);
    std::vector<float> output(W * H, 0.0f);

    // 简单的均值模糊核
    const float kernel[3][3] = {
        {1.0f/9, 1.0f/9, 1.0f/9},
        {1.0f/9, 1.0f/9, 1.0f/9},
        {1.0f/9, 1.0f/9, 1.0f/9}
    };

    // 朴素逐行卷积
    auto start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < ITERS; ++i) {
        TiledMatrixOps::convolve3x3Naive(
            input.data(), output.data(), W, H, kernel);
    }
    auto end = std::chrono::high_resolution_clock::now();
    double naiveMs = std::chrono::duration<double, std::milli>(
        end - start).count();

    // 二维分块卷积
    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < ITERS; ++i) {
        TiledMatrixOps::convolve3x3Tiled(
            input.data(), output.data(), W, H, kernel);
    }
    end = std::chrono::high_resolution_clock::now();
    double tiledMs = std::chrono::duration<double, std::milli>(
        end - start).count();

    std::cout << "===== 2D Tiled Convolution Benchmark =====\n"
              << "Image size:    " << W << " x " << H << "\n"
              << "Naive:         " << naiveMs << " ms\n"
              << "Tiled (32x32): " << tiledMs << " ms\n"
              << "Speedup:       " << (naiveMs / tiledMs) << "x\n";
}

} // namespace dod::batch
```

---

#### 4.3 流处理与非时间性存储

```cpp
// ==========================================
// 非时间性存储（Streaming Store）
// ==========================================
//
// 普通存储指令会将数据写入缓存，遵循write-back策略。
// 但有些数据写入后短期不会再被读取：
//   - 渲染输出缓冲区（GPU会读取，CPU不再访问）
//   - 日志/统计数据输出
//   - 帧间传输缓冲区
//
// 对这些数据使用普通存储会"污染"缓存——
// 有用的热数据被驱逐，换来不再需要的输出数据。
//
// 非时间性存储（Non-Temporal Store / Streaming Store）：
//   _mm256_stream_ps：直接写入内存，绕过缓存
//   优势：不污染缓存，利用写合并缓冲区(Write Combining Buffer)
//   要求：目标地址必须64字节对齐
//   限制：写完后必须 _mm_sfence() 确保全局可见

#ifdef __AVX__
#include <immintrin.h>
#endif

#include <cstring>
#include <vector>
#include <chrono>
#include <iostream>

namespace dod::batch {

#ifdef __AVX__
// ──────────────────────────────────────
// 场景：SoA → 交错输出（给GPU）
// ──────────────────────────────────────
//
// GPU通常期望顶点数据是交错的：[x,y,z,w, x,y,z,w, ...]
// 但DOD内部是SoA：x[], y[], z[]
// 转换时使用streaming store避免污染缓存

void streamToInterleavedOutput(const float* x, const float* y, const float* z,
                                 float* output, size_t count) {
    // output格式：[x0,y0,z0,1, x1,y1,z1,1, ...] （w=1.0 齐次坐标）
    const __m256 vone = _mm256_set1_ps(1.0f);

    for (size_t i = 0; i < count; i += 8) {
        // 加载8个x,y,z（从缓存中读取热数据——正常load）
        __m256 vx = _mm256_load_ps(&x[i]);
        __m256 vy = _mm256_load_ps(&y[i]);
        __m256 vz = _mm256_load_ps(&z[i]);

        // 转置 8x3 → 交错格式（简化版，实际需要复杂shuffle）
        // 这里简化为逐个处理
        for (size_t j = 0; j < 8 && (i + j) < count; ++j) {
            alignas(32) float temp[4] = {x[i+j], y[i+j], z[i+j], 1.0f};

            // 非时间性存储——不污染缓存
            __m128 v = _mm_load_ps(temp);
            _mm_stream_ps(&output[(i+j) * 4], v);
        }
    }

    // 确保所有streaming store对其他核心可见
    _mm_sfence();
}

// 大数组复制：streaming store vs 普通memcpy
void benchmarkStreamingStore() {
    constexpr size_t N = 16 * 1024 * 1024;  // 64MB (N floats)

    std::vector<float> src(N), dst_normal(N), dst_stream(N);
    for (size_t i = 0; i < N; ++i) src[i] = static_cast<float>(i);

    // 普通复制（通过缓存）
    auto start = std::chrono::high_resolution_clock::now();
    for (int iter = 0; iter < 10; ++iter) {
        std::memcpy(dst_normal.data(), src.data(), N * sizeof(float));
    }
    auto end = std::chrono::high_resolution_clock::now();
    double normalTime = std::chrono::duration<double, std::milli>(end - start).count();

    // Streaming store
    start = std::chrono::high_resolution_clock::now();
    for (int iter = 0; iter < 10; ++iter) {
        for (size_t i = 0; i + 8 <= N; i += 8) {
            __m256 v = _mm256_load_ps(&src[i]);
            _mm256_stream_ps(&dst_stream[i], v);
        }
        _mm_sfence();
    }
    end = std::chrono::high_resolution_clock::now();
    double streamTime = std::chrono::duration<double, std::milli>(end - start).count();

    std::cout << "===== Streaming Store Benchmark (64MB) =====\n"
              << "Normal copy:    " << normalTime << " ms\n"
              << "Streaming store:" << streamTime << " ms\n"
              << "Speedup:        " << (normalTime / streamTime) << "x\n";
}
#endif

} // namespace dod::batch
```

---

#### 4.4 分支预测与数据导向的分支消除

```cpp
// ==========================================
// 分支消除：让CPU流水线不再停顿
// ==========================================
//
// 现代CPU流水线有15-20级。遇到分支时，CPU必须猜测走哪条路径。
// 猜对了：零开销
// 猜错了：清空流水线，浪费15-20个cycle
//
// 对DOD的影响：
//   如果100万粒子有3种类型，switch(type)的分支模式是随机的：
//   预测准确率可能只有33% → 67%的分支被错误预测
//   → 每个错误预测浪费~15 cycles
//   → 总浪费：1M × 0.67 × 15 = 10M cycles ≈ 3ms@3GHz
//
// DOD的三种分支消除策略：
//   1. 排序后批处理：按类型排序，每批内无分支
//   2. 无分支算术：用数学运算代替条件判断
//   3. 分离数组：每种类型一个数组，天然无分支

#include <vector>
#include <algorithm>
#include <chrono>
#include <iostream>
#include <numeric>
#include <random>
#include <cmath>

#ifdef __AVX__
#include <immintrin.h>
#endif

namespace dod::batch {

enum class ParticleType : uint8_t {
    Fire  = 0,
    Smoke = 1,
    Spark = 2,
    Rain  = 3
};

// ──────────────────────────────────────
// 方式1：switch分支（分支预测不友好）
// ──────────────────────────────────────

void updateBranchy(float* x, float* y, float* vx, float* vy,
                    const ParticleType* types, size_t count, float dt) {
    for (size_t i = 0; i < count; ++i) {
        switch (types[i]) {
            case ParticleType::Fire:
                vy[i] += 5.0f * dt;   // 火焰上升
                x[i] += vx[i] * dt;
                y[i] += vy[i] * dt;
                break;
            case ParticleType::Smoke:
                vy[i] += 2.0f * dt;   // 烟雾缓慢上升
                vx[i] *= 0.99f;       // 烟雾水平减速
                x[i] += vx[i] * dt;
                y[i] += vy[i] * dt;
                break;
            case ParticleType::Spark:
                vy[i] -= 9.8f * dt;   // 火花受重力
                x[i] += vx[i] * dt;
                y[i] += vy[i] * dt;
                break;
            case ParticleType::Rain:
                vy[i] -= 15.0f * dt;  // 雨滴快速下落
                x[i] += vx[i] * dt;
                y[i] += vy[i] * dt;
                break;
        }
    }
}

// ──────────────────────────────────────
// 方式2：排序后批处理（消除分支）
// ──────────────────────────────────────

struct SortedBatchProcessor {
    // 按类型分组的索引范围
    struct TypeRange {
        size_t begin, end;
    };

    // 预处理：按类型排序
    static std::vector<TypeRange> sortByType(
        float* x, float* y, float* vx, float* vy,
        ParticleType* types, size_t count) {

        // 创建排序索引
        std::vector<size_t> indices(count);
        std::iota(indices.begin(), indices.end(), 0);
        std::sort(indices.begin(), indices.end(),
                  [types](size_t a, size_t b) { return types[a] < types[b]; });

        // 按排序索引重排所有数组（原地置换或使用临时缓冲区）
        std::vector<float> tmpX(count), tmpY(count);
        std::vector<float> tmpVX(count), tmpVY(count);
        std::vector<ParticleType> tmpTypes(count);

        for (size_t i = 0; i < count; ++i) {
            tmpX[i] = x[indices[i]];
            tmpY[i] = y[indices[i]];
            tmpVX[i] = vx[indices[i]];
            tmpVY[i] = vy[indices[i]];
            tmpTypes[i] = types[indices[i]];
        }

        std::copy(tmpX.begin(), tmpX.end(), x);
        std::copy(tmpY.begin(), tmpY.end(), y);
        std::copy(tmpVX.begin(), tmpVX.end(), vx);
        std::copy(tmpVY.begin(), tmpVY.end(), vy);
        std::copy(tmpTypes.begin(), tmpTypes.end(), types);

        // 找到每种类型的范围
        std::vector<TypeRange> ranges(4);
        size_t pos = 0;
        for (int t = 0; t < 4; ++t) {
            ranges[t].begin = pos;
            while (pos < count && static_cast<int>(types[pos]) == t) ++pos;
            ranges[t].end = pos;
        }

        return ranges;
    }

    // 每种类型的专用更新函数（零分支）
    static void updateFire(float* x, float* y, float* vx, float* vy,
                           size_t begin, size_t end, float dt) {
        for (size_t i = begin; i < end; ++i) {
            vy[i] += 5.0f * dt;
            x[i] += vx[i] * dt;
            y[i] += vy[i] * dt;
        }
    }

    static void updateSmoke(float* x, float* y, float* vx, float* vy,
                            size_t begin, size_t end, float dt) {
        for (size_t i = begin; i < end; ++i) {
            vy[i] += 2.0f * dt;
            vx[i] *= 0.99f;
            x[i] += vx[i] * dt;
            y[i] += vy[i] * dt;
        }
    }

    // ... spark, rain 类似
};

// ──────────────────────────────────────
// 方式3：无分支算术（SIMD blend）
// ──────────────────────────────────────
//
// 用条件选择代替条件跳转：
//   if (y < 0) y = 0;
// 变为：
//   y = y < 0 ? 0 : y;  （CMOV指令，无分支）
// 或SIMD：
//   mask = _mm256_cmp_ps(y, zero, _CMP_LT_OQ);
//   y = _mm256_blendv_ps(y, zero, mask);  （无分支！）

#ifdef __AVX__
void updateBranchless_AVX(float* py, float* vy, size_t count,
                           float groundY, float restitution) {
    const __m256 vground = _mm256_set1_ps(groundY);
    const __m256 vneg_rest = _mm256_set1_ps(-restitution);

    for (size_t i = 0; i + 8 <= count; i += 8) {
        __m256 y = _mm256_load_ps(&py[i]);
        __m256 v = _mm256_load_ps(&vy[i]);

        // 无分支碰撞：用mask和blend代替if
        __m256 belowGround = _mm256_cmp_ps(y, vground, _CMP_LT_OQ);
        y = _mm256_blendv_ps(y, vground, belowGround);
        __m256 bounced = _mm256_mul_ps(v, vneg_rest);
        v = _mm256_blendv_ps(v, bounced, belowGround);

        _mm256_store_ps(&py[i], y);
        _mm256_store_ps(&vy[i], v);
    }
}
#endif

void benchmarkBranchElimination() {
    constexpr size_t N = 1'000'000;
    constexpr int ITERS = 100;

    std::vector<float> x(N), y(N), vx(N), vy(N);
    std::vector<ParticleType> types(N);

    // 随机初始化
    std::mt19937 rng(42);
    std::uniform_real_distribution<float> posDist(0, 100);
    std::uniform_real_distribution<float> velDist(-10, 10);
    std::uniform_int_distribution<int> typeDist(0, 3);

    for (size_t i = 0; i < N; ++i) {
        x[i] = posDist(rng); y[i] = posDist(rng);
        vx[i] = velDist(rng); vy[i] = velDist(rng);
        types[i] = static_cast<ParticleType>(typeDist(rng));
    }

    // 方式1：分支版
    auto start = std::chrono::high_resolution_clock::now();
    for (int it = 0; it < ITERS; ++it) {
        updateBranchy(x.data(), y.data(), vx.data(), vy.data(),
                     types.data(), N, 0.016f);
    }
    auto end = std::chrono::high_resolution_clock::now();
    double branchyTime = std::chrono::duration<double, std::milli>(end - start).count();

    std::cout << "===== Branch Elimination Benchmark =====\n"
              << "Branchy (random types): " << branchyTime << " ms\n";

    // 方式2需要先排序（一次性开销）
    // 方式3见AVX blend版本
}

} // namespace dod::batch
```

**高级分支消除技术**

上面介绍了排序批处理、无分支算术和SIMD blend三种基础分支消除策略。
实际工程中还有更多技巧，以及一些反直觉的场景——盲目消除分支反而更慢。

**各种分支消除方法的性能对比：**

| 方法 | 延迟/元素 | 吞吐量 | 预测器友好 | 适用场景 |
|------|----------|--------|-----------|---------|
| switch语句 | ~15 cycles (miss) | 低 | 差（随机模式） | 类型少且可预测 |
| if-else链 | ~15 cycles (miss) | 低 | 差（随机模式） | 2-3种情况 |
| 排序后批处理 | ~1 cycle | 高 | 极好（无分支） | 可以接受排序开销 |
| 函数指针表(LUT) | ~5 cycles | 中 | 中（间接跳转） | 类型多、逻辑各异 |
| CMOV指令 | ~2 cycles | 高 | 不依赖预测器 | 简单二选一赋值 |
| SIMD blend | ~1 cycle (摊还) | 极高 | 不依赖预测器 | 批量数据处理 |

**何时无分支代码反而更慢？**

分支预测器对重复模式的预测准确率极高（>99%）。如果数据具有强规律性，
例如90%的粒子是Fire类型，那么switch(type)的预测准确率高达90%，
此时分支版本每个元素只有约0.1×15=1.5 cycles的分支惩罚。
而LUT版本每次都有间接跳转的开销（~5 cycles），反而更慢。
**规则：只有当分支预测准确率低于85%时，消除分支才有显著收益。**

```cpp
// ==========================================
// 高级分支消除：LUT派发与CMOV技术
// ==========================================
//
// 基础回顾：
//   switch/if-else → CPU靠猜（分支预测器）
//   猜对0开销，猜错~15 cycles
//   当模式随机时，预测准确率低→严重惩罚
//
// 高级策略：
//   1. LUT（查找表）：用函数指针数组代替switch
//      将"猜测走哪条路径"变成"查表得到函数地址"
//      代价：间接调用开销（~5 cycles）但完全可预测
//
//   2. CMOV：编译器将简单if替换为条件移动指令
//      无需跳转，流水线永不停顿
//      只适用于简单赋值，不适用于复杂逻辑
//
//   3. Computed Goto (GCC扩展)：
//      比函数指针表更快——避免了函数调用开销
//      goto *table[index] 直接跳转到标签地址

#include <vector>
#include <array>
#include <algorithm>
#include <chrono>
#include <iostream>
#include <cstdint>
#include <functional>
#include <cmath>
#include <random>

namespace dod::batch {

// ──────────────────────────────────────
// 函数指针表（LUT）派发器
// ──────────────────────────────────────
//
// 核心思想：将类型到处理函数的映射预先建好表
// 运行时只需一次数组索引 + 一次间接调用
// 优势1：O(1)派发，不受类型数量影响（switch在类型多时退化）
// 优势2：运行时可动态修改映射（热更新处理逻辑）

class BranchFreeDispatcher {
public:
    // 处理函数签名：对单个粒子执行更新
    // 参数：x, y坐标的引用，vx, vy速度的引用，dt时间步
    using UpdateFunc = void(*)(float& x, float& y,
                                float& vx, float& vy, float dt);

    // 最多支持16种类型——足够覆盖大多数游戏场景
    static constexpr size_t MAX_TYPES = 16;

private:
    // 函数指针表——在构造时填充，运行时只读取
    // 对齐到缓存行避免false sharing
    alignas(64) std::array<UpdateFunc, MAX_TYPES> dispatchTable_{};
    size_t registeredTypes_ = 0;

public:
    BranchFreeDispatcher() {
        // 默认全部填充空操作，防止未注册类型导致崩溃
        dispatchTable_.fill([](float&, float&, float&, float&, float) {});
    }

    // 注册类型处理函数
    void registerType(uint8_t typeId, UpdateFunc func) {
        dispatchTable_[typeId] = func;
        registeredTypes_ = std::max(registeredTypes_, size_t(typeId + 1));
    }

    // 批量派发——无switch、无if-else
    // 每个粒子只需：1次数组读取(type) + 1次表查找 + 1次间接调用
    void dispatch(float* x, float* y, float* vx, float* vy,
                  const uint8_t* types, size_t count, float dt) const
    {
        for (size_t i = 0; i < count; ++i) {
            // 间接调用：CPU可以预测间接跳转目标
            // 如果连续多个粒子类型相同，间接分支预测器表现良好
            dispatchTable_[types[i]](x[i], y[i], vx[i], vy[i], dt);
        }
    }

    // 排序后派发——最快方案：排序确保同类型连续
    // 间接分支预测器对连续相同目标几乎100%准确
    void dispatchSorted(float* x, float* y, float* vx, float* vy,
                        const uint8_t* types, size_t count, float dt) const
    {
        size_t i = 0;
        while (i < count) {
            // 找到当前类型的连续范围
            uint8_t currentType = types[i];
            UpdateFunc func = dispatchTable_[currentType];
            size_t rangeStart = i;

            // 同类型的粒子连续排列——一次查表，循环调用
            while (i < count && types[i] == currentType) {
                func(x[i], y[i], vx[i], vy[i], dt);
                ++i;
            }
        }
    }
};

// ──────────────────────────────────────
// CMOV指令的利用：编译器何时生成CMOV
// ──────────────────────────────────────
//
// 关键规则：编译器只在以下条件都满足时生成CMOV：
//   1. 两个分支都是简单赋值（没有函数调用、没有内存分配）
//   2. 两个分支的值都已经计算好（没有副作用依赖）
//   3. 编译器认为分支不可预测（或开启了-O2以上优化）
//
// 经典示例：clamp操作
//   if (x < min) x = min;       → CMOV
//   if (x > max) x = max;       → CMOV
//
// 不生成CMOV的情况：
//   if (x < 0) doExpensiveWork(); → 分支跳转（两条路径代价不对称）

// 强制CMOV的无分支clamp——用于粒子边界约束
// 编译器在-O2下通常会将此优化为2条CMOV指令
inline float branchlessClamp(float val, float lo, float hi) {
    // 三元运算符提示编译器使用CMOV
    val = (val < lo) ? lo : val;
    val = (val > hi) ? hi : val;
    return val;
}

// 无分支的绝对值（避免std::abs可能的函数调用开销）
inline float branchlessAbs(float x) {
    // 利用IEEE 754：清除符号位
    // 比 x < 0 ? -x : x 更快——完全无分支，甚至无CMOV
    uint32_t bits;
    std::memcpy(&bits, &x, sizeof(float));
    bits &= 0x7FFFFFFF;  // 清除最高位（符号位）
    std::memcpy(&x, &bits, sizeof(float));
    return x;
}

// 无分支的min/max——编译器通常已经优化，但显式写更安全
inline float branchlessMin(float a, float b) {
    return (a < b) ? a : b;  // 编译器在-O2下生成MINSS指令
}

inline float branchlessMax(float a, float b) {
    return (a > b) ? a : b;  // 编译器在-O2下生成MAXSS指令
}

// 综合示例：无分支的粒子边界反弹
// 传统写法需要4个if分支，预测器在粒子随机运动时表现差
// 无分支版本使用CMOV和算术运算完全消除分支
void bounceBranchless(float* x, float* y, float* vx, float* vy,
                       size_t count,
                       float xMin, float xMax, float yMin, float yMax,
                       float restitution)
{
    for (size_t i = 0; i < count; ++i) {
        // 计算"是否越界"的掩码（0.0或1.0）
        // 利用浮点比较→0/1转换代替if判断
        float hitLeft   = (x[i] < xMin) ? 1.0f : 0.0f;
        float hitRight  = (x[i] > xMax) ? 1.0f : 0.0f;
        float hitBottom = (y[i] < yMin) ? 1.0f : 0.0f;
        float hitTop    = (y[i] > yMax) ? 1.0f : 0.0f;

        // 修正位置：越界时钳制到边界
        x[i] = branchlessClamp(x[i], xMin, xMax);
        y[i] = branchlessClamp(y[i], yMin, yMax);

        // 反弹速度：越界时反转并衰减
        // hitLeft + hitRight 最多为1（不可能同时触发）
        float xBounce = hitLeft + hitRight;   // 0或1
        float yBounce = hitBottom + hitTop;    // 0或1

        // 如果xBounce=1：vx = vx * (-restitution)
        // 如果xBounce=0：vx不变
        // 用线性插值代替分支：lerp(vx, -vx*rest, bounce)
        vx[i] = vx[i] * (1.0f - xBounce * (1.0f + restitution));
        vy[i] = vy[i] * (1.0f - yBounce * (1.0f + restitution));
    }
}

void benchmarkAdvancedBranchElimination() {
    constexpr size_t N = 1'000'000;
    constexpr int ITERS = 100;

    std::vector<float> x(N), y(N), vx(N), vy(N);
    std::vector<uint8_t> types(N);

    std::mt19937 rng(42);
    std::uniform_real_distribution<float> posDist(0, 100);
    std::uniform_real_distribution<float> velDist(-10, 10);
    std::uniform_int_distribution<int> typeDist(0, 3);

    for (size_t i = 0; i < N; ++i) {
        x[i] = posDist(rng); y[i] = posDist(rng);
        vx[i] = velDist(rng); vy[i] = velDist(rng);
        types[i] = static_cast<uint8_t>(typeDist(rng));
    }

    // 配置LUT派发器
    BranchFreeDispatcher dispatcher;
    dispatcher.registerType(0, [](float& px, float& py,
                                   float& pvx, float& pvy, float dt) {
        pvy += 5.0f * dt; px += pvx * dt; py += pvy * dt;  // Fire
    });
    dispatcher.registerType(1, [](float& px, float& py,
                                   float& pvx, float& pvy, float dt) {
        pvy += 2.0f * dt; pvx *= 0.99f; px += pvx * dt; py += pvy * dt;  // Smoke
    });
    dispatcher.registerType(2, [](float& px, float& py,
                                   float& pvx, float& pvy, float dt) {
        pvy -= 9.8f * dt; px += pvx * dt; py += pvy * dt;  // Spark
    });
    dispatcher.registerType(3, [](float& px, float& py,
                                   float& pvx, float& pvy, float dt) {
        pvy -= 15.0f * dt; px += pvx * dt; py += pvy * dt;  // Rain
    });

    // LUT派发（随机类型序列）
    auto start = std::chrono::high_resolution_clock::now();
    for (int it = 0; it < ITERS; ++it) {
        dispatcher.dispatch(x.data(), y.data(), vx.data(), vy.data(),
                           types.data(), N, 0.016f);
    }
    auto end = std::chrono::high_resolution_clock::now();
    double lutTime = std::chrono::duration<double, std::milli>(
        end - start).count();

    // 无分支边界反弹
    start = std::chrono::high_resolution_clock::now();
    for (int it = 0; it < ITERS; ++it) {
        bounceBranchless(x.data(), y.data(), vx.data(), vy.data(),
                         N, 0, 100, 0, 100, 0.6f);
    }
    end = std::chrono::high_resolution_clock::now();
    double bounceTime = std::chrono::duration<double, std::milli>(
        end - start).count();

    std::cout << "===== Advanced Branch Elimination =====\n"
              << "LUT dispatch (random): " << lutTime << " ms\n"
              << "Branchless bounce:     " << bounceTime << " ms\n";
}

} // namespace dod::batch
```

---

#### 4.5 缓存一致性排序

```cpp
// ==========================================
// 缓存一致性排序：让空间邻近的数据在内存中也邻近
// ==========================================
//
// 粒子系统中，实体的创建和销毁是随机的。
// 运行一段时间后，空间上相邻的粒子可能在数组中相距很远。
//
// 这对空间查询（邻居查找、碰撞检测）极为不利：
//   查找(10, 20)附近的粒子 → 需要访问分散在内存各处的元素
//   → 随机访问模式 → cache miss暴增
//
// 解决方案：定期按空间位置重排数组
//   使用Morton码（Z-order，见第一周1.6节）将3D位置映射为1D索引
//   按Morton码排序后，空间邻近的粒子在数组中也邻近
//   → 邻居查询变成近似顺序访问 → cache友好

#include <vector>
#include <algorithm>
#include <numeric>
#include <chrono>
#include <iostream>

namespace dod::batch {

class SpatialSorter {
public:
    // 将float坐标量化到uint16范围
    static uint16_t quantize(float v, float minVal, float maxVal) {
        float normalized = (v - minVal) / (maxVal - minVal);
        normalized = std::clamp(normalized, 0.0f, 1.0f);
        return static_cast<uint16_t>(normalized * 65535.0f);
    }

    // Morton码编码（复用第一周的MortonCode类）
    static uint64_t encodeMorton3D(uint16_t x, uint16_t y, uint16_t z) {
        auto expand = [](uint16_t v) -> uint64_t {
            uint64_t x = v;
            x = (x | (x << 16)) & 0x030000FF;
            x = (x | (x << 8))  & 0x0300F00F;
            x = (x | (x << 4))  & 0x030C30C3;
            x = (x | (x << 2))  & 0x09249249;
            return x;
        };
        return expand(x) | (expand(y) << 1) | (expand(z) << 2);
    }

    // 按空间位置排序所有SoA数组
    static void sortBySpatialLocality(
        std::vector<float>& x, std::vector<float>& y, std::vector<float>& z,
        std::vector<float>& vx, std::vector<float>& vy, std::vector<float>& vz,
        std::vector<float>& life,
        float worldMin, float worldMax) {

        const size_t n = x.size();

        // 计算每个粒子的Morton码
        std::vector<std::pair<uint64_t, size_t>> mortonIndices(n);
        for (size_t i = 0; i < n; ++i) {
            uint16_t qx = quantize(x[i], worldMin, worldMax);
            uint16_t qy = quantize(y[i], worldMin, worldMax);
            uint16_t qz = quantize(z[i], worldMin, worldMax);
            mortonIndices[i] = {encodeMorton3D(qx, qy, qz), i};
        }

        // 按Morton码排序
        std::sort(mortonIndices.begin(), mortonIndices.end());

        // 按排序顺序重排所有数组
        auto reorder = [&mortonIndices, n](std::vector<float>& arr) {
            std::vector<float> temp(n);
            for (size_t i = 0; i < n; ++i) {
                temp[i] = arr[mortonIndices[i].second];
            }
            arr = std::move(temp);
        };

        reorder(x); reorder(y); reorder(z);
        reorder(vx); reorder(vy); reorder(vz);
        reorder(life);
    }
};

} // namespace dod::batch
```

---

#### 4.6 数据压缩与解压缩友好布局

```cpp
// ==========================================
// SoA的压缩优势
// ==========================================
//
// SoA布局中，同类型的数据紧密排列。
// 同类型数据之间的差异通常很小——这正是压缩算法的最爱。
//
// 常用压缩方式：
//   1. Delta编码：存储相邻值的差（差通常很小）
//   2. Run-Length编码：连续相同值只存一次
//   3. 量化：降低精度以减小数据量
//
// 应用场景：
//   - 网络传输：客户端/服务器同步粒子状态
//   - 存档/快照：保存游戏状态
//   - 回放系统：记录每帧的粒子状态

#include <vector>
#include <cstdint>
#include <cmath>
#include <iostream>

namespace dod::batch {

struct CompressedFloatArray {
    float baseValue;               // 基准值
    float scale;                   // 量化比例
    std::vector<int16_t> deltas;   // Delta编码的量化值

    // 压缩
    static CompressedFloatArray compress(const float* data, size_t count) {
        CompressedFloatArray result;
        if (count == 0) return result;

        result.baseValue = data[0];

        // 找到最大差值以确定量化比例
        float maxDelta = 0;
        for (size_t i = 1; i < count; ++i) {
            maxDelta = std::max(maxDelta, std::abs(data[i] - data[i-1]));
        }

        result.scale = maxDelta / 32767.0f;
        if (result.scale == 0) result.scale = 1.0f;

        result.deltas.resize(count);
        result.deltas[0] = 0;
        for (size_t i = 1; i < count; ++i) {
            float delta = data[i] - data[i-1];
            result.deltas[i] = static_cast<int16_t>(
                std::clamp(delta / result.scale, -32767.0f, 32767.0f));
        }

        return result;
    }

    // 解压
    void decompress(float* output, size_t count) const {
        output[0] = baseValue;
        for (size_t i = 1; i < count; ++i) {
            output[i] = output[i-1] + deltas[i] * scale;
        }
    }

    // 压缩比
    double compressionRatio(size_t originalCount) const {
        size_t originalSize = originalCount * sizeof(float);
        size_t compressedSize = sizeof(float) * 2 + deltas.size() * sizeof(int16_t);
        return double(originalSize) / compressedSize;
    }
};

} // namespace dod::batch
```

**数据压缩与DOD的协同优化**

上面展示了基于Delta编码的浮点数压缩。在DOD系统中，SoA布局为更多种类的
压缩方案创造了理想条件——每个数组都是同质数据，可以针对其分布特征选择最优编码。

**不同数据分布下各压缩方案的效果：**

```
数据分布与压缩比示意图

                    原始数据           RLE        Delta    Frame-of-Ref  Varint
                   ──────────      ──────────  ──────────  ──────────  ──────────
布尔标记(95%=true)  █████████████   █            ██          ██████      ████
排序整数ID          █████████████   ██████████   ██           █          ████
随机浮点坐标        █████████████   █████████████ ██████████   ██████████  █████████████
枚举类型(4种)       █████████████   ████         ████████     ████        ██

█ = 压缩后大小（越短越好）

最佳匹配：
  布尔标记         → RLE（长段相同值→极高压缩比）
  排序整数ID       → Frame-of-Reference（差值小且均匀）
  随机浮点坐标     → Delta + 量化（差值有界但不规律）
  枚举类型         → 位压缩（4种只需2 bits）
```

**压缩方案选择决策表：**

| 数据特征 | 推荐编码 | 压缩比 | 解码速度 | 缓存节省 | SIMD解码 |
|---------|---------|--------|---------|---------|---------|
| 长段相同值(活跃标记) | RLE | 10-100x | 中等 | 极高 | 困难 |
| 排序的连续整数 | Frame-of-Ref | 4-8x | 极快 | 高 | 简单 |
| 小范围整数(类型ID) | 位压缩 | 2-16x | 快 | 高 | 中等 |
| 变化幅度小的浮点 | Delta+量化 | 2x | 快 | 中等 | 简单 |
| 不规则大小整数 | Varint | 1.5-4x | 中等 | 中等 | 困难 |
| 完全随机数据 | 不压缩 | 1x | 最快 | 无 | 不适用 |

```cpp
// ==========================================
// 数据压缩与DOD的协同优化
// ==========================================
//
// DOD的SoA布局天然适合压缩：
//   - 同类型数据紧密排列→高空间局部性→压缩比高
//   - 分离的数组可以各自选择最优编码
//   - 解码后直接进入热路径处理→解码和计算可以流水线化
//
// 核心权衡：
//   压缩节省的带宽 vs 解码的CPU开销
//   如果系统是memory-bound（IPC低、cache miss高），压缩几乎总是值得的
//   如果系统是compute-bound（IPC高、ALU饱和），压缩可能帮倒忙

#include <vector>
#include <cstdint>
#include <cstring>
#include <algorithm>
#include <iostream>
#include <cassert>
#include <numeric>
#include <chrono>

namespace dod::batch {

// ──────────────────────────────────────
// 多策略压缩组件存储
// ──────────────────────────────────────
//
// 根据数据特征自动选择压缩策略
// 每种编码都设计为解码友好——支持顺序批量解码

class CompressedComponentStore {
public:
    // 支持的编码方式
    enum class Encoding : uint8_t {
        None,             // 不压缩（随机数据最优）
        RLE,              // Run-Length Encoding（适合大段相同值）
        FrameOfReference, // 基准值 + 小偏移（适合排序整数）
        Varint            // 变长编码（适合不规则大小的整数）
    };

    // ── RLE编码：适合稀疏布尔数组 ──
    // 场景：100万个实体中95%是活跃的
    //   原始存储：100万个uint8_t = 1MB
    //   RLE：{value=1, count=4723}, {value=0, count=12}, {value=1, count=8891}...
    //   大约只需要几千个条目 ≈ 几KB
    struct RLEEntry {
        uint8_t value;    // 重复的值
        uint32_t count;   // 连续重复次数
    };

    static std::vector<RLEEntry> encodeRLE(const uint8_t* data, size_t count) {
        std::vector<RLEEntry> result;
        if (count == 0) return result;

        uint8_t currentVal = data[0];
        uint32_t runLen = 1;

        for (size_t i = 1; i < count; ++i) {
            if (data[i] == currentVal && runLen < UINT32_MAX) {
                ++runLen;
            } else {
                result.push_back({currentVal, runLen});
                currentVal = data[i];
                runLen = 1;
            }
        }
        result.push_back({currentVal, runLen});
        return result;
    }

    // RLE解码：顺序展开，可以直接填充到处理缓冲区
    static void decodeRLE(const std::vector<RLEEntry>& encoded,
                          uint8_t* output, size_t count)
    {
        size_t pos = 0;
        for (const auto& entry : encoded) {
            // memset对于单字节值极快——编译器会优化为SIMD fill
            size_t len = std::min(size_t(entry.count), count - pos);
            std::memset(output + pos, entry.value, len);
            pos += len;
            if (pos >= count) break;
        }
    }

    // ── Frame-of-Reference编码：适合排序整数 ──
    // 场景：实体ID排序后为 [1000, 1003, 1007, 1008, 1015, ...]
    //   原始：每个ID占32位
    //   FoR：基准值1000 + 偏移 [0, 3, 7, 8, 15, ...]
    //   偏移值都很小，可以用8位或16位存储
    //   压缩比：32/8 = 4x 或 32/16 = 2x
    struct FrameOfRefBlock {
        uint32_t baseValue;            // 块内最小值
        uint8_t bitsPerValue;          // 每个偏移值的位数
        std::vector<uint8_t> packed;   // 位压缩后的偏移值
    };

    // 计算表示最大值需要的位数
    static uint8_t bitsNeeded(uint32_t maxVal) {
        if (maxVal == 0) return 1;
        uint8_t bits = 0;
        while (maxVal > 0) { maxVal >>= 1; ++bits; }
        return bits;
    }

    static FrameOfRefBlock encodeFrameOfRef(const uint32_t* data, size_t count) {
        FrameOfRefBlock block;
        if (count == 0) return block;

        // 找基准值和最大偏移
        block.baseValue = *std::min_element(data, data + count);
        uint32_t maxOffset = 0;
        for (size_t i = 0; i < count; ++i) {
            maxOffset = std::max(maxOffset, data[i] - block.baseValue);
        }

        block.bitsPerValue = bitsNeeded(maxOffset);

        // 位压缩打包
        // 简化实现：每个偏移值用bitsPerValue位存储
        size_t totalBits = count * block.bitsPerValue;
        block.packed.resize((totalBits + 7) / 8, 0);

        for (size_t i = 0; i < count; ++i) {
            uint32_t offset = data[i] - block.baseValue;
            size_t bitPos = i * block.bitsPerValue;
            // 逐位写入（生产代码应使用SIMD加速的位打包）
            for (uint8_t b = 0; b < block.bitsPerValue; ++b) {
                if (offset & (1u << b)) {
                    block.packed[(bitPos + b) / 8] |=
                        (1u << ((bitPos + b) % 8));
                }
            }
        }

        return block;
    }

    // FoR解码：加上基准值即可，非常适合SIMD
    // _mm256_add_epi32(offsets, _mm256_set1_epi32(base))
    static void decodeFrameOfRef(const FrameOfRefBlock& block,
                                  uint32_t* output, size_t count)
    {
        for (size_t i = 0; i < count; ++i) {
            uint32_t offset = 0;
            size_t bitPos = i * block.bitsPerValue;
            for (uint8_t b = 0; b < block.bitsPerValue; ++b) {
                if (block.packed[(bitPos + b) / 8] &
                    (1u << ((bitPos + b) % 8))) {
                    offset |= (1u << b);
                }
            }
            output[i] = block.baseValue + offset;
        }
    }

    // ── Varint编码：适合不规则大小的整数 ──
    // 每个字节的最高位表示"是否还有后续字节"
    // 小值(< 128)只需1字节，中值(< 16384)需2字节
    // 优势：无需提前知道最大值
    // 劣势：变长编码→不能随机访问，必须顺序解码

    static std::vector<uint8_t> encodeVarint(const uint32_t* data,
                                              size_t count)
    {
        std::vector<uint8_t> result;
        result.reserve(count * 2);  // 预估平均2字节/值

        for (size_t i = 0; i < count; ++i) {
            uint32_t val = data[i];
            // 每次取低7位，最高位标记是否继续
            while (val >= 128) {
                result.push_back(static_cast<uint8_t>(val & 0x7F) | 0x80);
                val >>= 7;
            }
            result.push_back(static_cast<uint8_t>(val));
        }
        return result;
    }

    static void decodeVarint(const uint8_t* encoded, size_t encodedSize,
                             uint32_t* output, size_t count)
    {
        size_t pos = 0;
        for (size_t i = 0; i < count && pos < encodedSize; ++i) {
            uint32_t val = 0;
            uint32_t shift = 0;
            // 读取直到遇到最高位为0的字节
            while (pos < encodedSize) {
                uint8_t byte = encoded[pos++];
                val |= uint32_t(byte & 0x7F) << shift;
                if ((byte & 0x80) == 0) break;
                shift += 7;
            }
            output[i] = val;
        }
    }
};

// ──────────────────────────────────────
// 压缩效果基准测试
// ──────────────────────────────────────
void benchmarkCompression() {
    constexpr size_t N = 1'000'000;

    // 测试1：稀疏布尔数组（95%为1）——RLE场景
    std::vector<uint8_t> boolData(N);
    std::mt19937 rng(42);
    for (size_t i = 0; i < N; ++i) {
        boolData[i] = (rng() % 100 < 95) ? 1 : 0;
    }

    auto rleEncoded = CompressedComponentStore::encodeRLE(
        boolData.data(), N);
    size_t rleBytes = rleEncoded.size() *
        sizeof(CompressedComponentStore::RLEEntry);
    double rleRatio = double(N) / rleBytes;

    // 测试2：排序整数——Frame-of-Reference场景
    std::vector<uint32_t> sortedIds(N);
    std::iota(sortedIds.begin(), sortedIds.end(), 10000);
    // 加入一些间隙
    for (size_t i = 0; i < N; ++i) {
        sortedIds[i] += rng() % 10;
    }
    std::sort(sortedIds.begin(), sortedIds.end());

    auto forBlock = CompressedComponentStore::encodeFrameOfRef(
        sortedIds.data(), N);
    size_t forBytes = sizeof(uint32_t) + 1 + forBlock.packed.size();
    double forRatio = double(N * sizeof(uint32_t)) / forBytes;

    // 测试3：小值整数——Varint场景
    std::vector<uint32_t> smallInts(N);
    for (size_t i = 0; i < N; ++i) {
        smallInts[i] = rng() % 1000;  // 0-999，大多数只需2字节
    }

    auto varintEncoded = CompressedComponentStore::encodeVarint(
        smallInts.data(), N);
    double varintRatio = double(N * sizeof(uint32_t)) /
        varintEncoded.size();

    // 解码速度测试
    std::vector<uint8_t> rleOutput(N);
    auto start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < 100; ++i) {
        CompressedComponentStore::decodeRLE(
            rleEncoded, rleOutput.data(), N);
    }
    auto end = std::chrono::high_resolution_clock::now();
    double rleDecodeMs = std::chrono::duration<double, std::milli>(
        end - start).count();

    std::cout << "===== Compression Benchmark =====\n"
              << "RLE (95% sparse bool):\n"
              << "  Entries:     " << rleEncoded.size() << "\n"
              << "  Ratio:       " << rleRatio << "x\n"
              << "  Decode 100x: " << rleDecodeMs << " ms\n"
              << "Frame-of-Reference (sorted IDs):\n"
              << "  Bits/value:  " << int(forBlock.bitsPerValue) << "\n"
              << "  Ratio:       " << forRatio << "x\n"
              << "Varint (small ints 0-999):\n"
              << "  Ratio:       " << varintRatio << "x\n";
}

} // namespace dod::batch
```

---

#### 4.7 DOD技术集成：完整优化管线

```cpp
// ==========================================
// DOD优化管线：从分析到实施的完整方法论
// ==========================================
//
// 本月学习了大量DOD技术。如何系统性地应用？
// 以下是经过验证的8步优化管线：
//
// Step 1: 分析（Profile）
//   - 确定性能瓶颈：CPU bound? Memory bound?
//   - 工具：perf stat, VTune, cachegrind
//   - 关键指标：L1 miss rate, LLC miss rate, IPC
//
// Step 2: 分离（Separate）
//   - 识别热/温/冷数据
//   - 将热数据从大结构体中提取出来
//   - Week 3的核心技术
//
// Step 3: 重组（Reorganize）
//   - 热数据AoS → SoA
//   - 选择合适的布局（SoA vs AoSoA）
//   - Week 2的核心技术
//
// Step 4: 对齐（Align）
//   - 缓存行对齐（alignas(64)）
//   - 考虑大页面（Huge Pages）
//   - Week 1的技术
//
// Step 5: 分块（Tile）
//   - 多遍算法使用循环分块
//   - 确保分块大小适合L1缓存
//   - Week 4的4.2节
//
// Step 6: 向量化（Vectorize）
//   - 启用编译器自动向量化
//   - 关键路径手写SIMD
//   - Week 2的2.3/2.4节
//
// Step 7: 去分支（Debranch）
//   - 排序+批处理消除类型分支
//   - SIMD blend消除条件分支
//   - Week 4的4.4节
//
// Step 8: 再次分析（Profile Again）
//   - 验证优化效果
//   - 检查是否引入新瓶颈
//   - 迭代优化
```

```
DOD优化效果参考表（基于典型粒子系统，100万粒子）：

  优化步骤              典型加速    实现难度   适用时机
  ─────────────────   ──────────  ────────  ──────────────────────
  热/冷数据分离         2-4x       中等      几乎总是值得
  AoS → SoA            2-4x       中等      热路径批量遍历
  缓存行对齐            1.1-1.5x   低        总是
  消除伪共享            2-10x      低        多线程场景
  循环分块              1.5-3x     中等      多遍算法
  编译器自动向量化       2-4x       低        SoA + 简单循环
  手写SIMD             2-8x       高        数值密集计算
  分支消除              1.5-3x     中等      异构数据处理
  Morton码排序          2-5x       中等      空间查询密集
  大页面               1.1-1.3x   低        大数据集(>L3)

  全部应用后的综合加速：通常 10-50x
  （各步骤的加速不是简单相乘，存在重叠和上限效应）
```

---

#### 4.8 本周练习任务

```
练习1：预取距离调优
──────────────────
目标：实现PrefetchTuner并找到最优预取距离

要求：
1. 实现三种工作负载：(a)顺序浮点处理 (b)链表遍历 (c)间接索引访问
2. 对每种工作负载，测试预取距离0-32（步长4）
3. 记录最优距离和加速比
4. 解释为什么不同工作负载的最优距离不同

验证：
- 顺序访问：预取几乎无改善（硬件预取器已处理）
- 链表遍历：预取应提升30-50%
- 间接索引：预取应提升20-40%

练习2：循环分块优化
──────────────────
目标：将多遍粒子更新改为分块版本

要求：
1. 实现5遍更新（重力→阻力→位置→碰撞→生命值）
2. 不分块版本和分块版本（块大小512/1024/2048/4096）
3. 使用perf stat测量L1 cache miss
4. 生成"块大小 vs 缓存miss率"的数据表

验证：
- 最优块大小应在512-2048之间
- 分块版本L1 miss率应减少30-60%
- 运行时间应减少20-50%

练习3：分支消除
──────────────
目标：对比四种分支处理方式

要求：
1. 粒子系统包含4种类型，各25%
2. 实现四种方式：(a)switch (b)按类型排序+批处理
   (c)无分支算术(CMOV) (d)分离数组(每种类型独立数组)
3. 测量100万粒子×100次迭代的性能
4. 分析哪种方式在什么场景下最优

验证：
- 随机类型时，排序+批处理 > switch（约2-3x）
- 分离数组在已知类型数量时最快
- 无分支算术适合简单条件（如碰撞检测）

练习4：综合DOD优化项目
────────────────────
目标：将4.7节的优化管线完整应用于一个系统

要求：
1. 起始代码：OOP风格的粒子系统
   （Entity类，虚函数，std::list存储，频繁new/delete）
2. 按8步管线逐步优化，每步记录性能数据
3. 最终使用SoA + SIMD + 分块 + 排序
4. 生成优化报告，包含每步的加速比

验证：
- 最终版本比起始版本快10-50倍
- 每步优化都有可测量的改善
- 代码通过valgrind检查无内存问题
```

---

#### 4.9 本周知识检验

```
思考题1：软件预取什么时候会伤害性能？
         给出两个具体场景（提示：缓存污染、超发射预取）。

思考题2：为什么按类型排序比虚函数调度表更适合DOD？
         从缓存和分支预测两个角度分析。

思考题3：非时间性存储如何与多线程交互？
         如果线程A用streaming store写数据，线程B何时能看到？

思考题4：GPU本质上是一台DOD机器。
         分析GPU架构中哪些设计体现了DOD思想
         （SIMT、合并访问、shared memory、纹理缓存）。

思考题5：展望下月（ECS）：Archetype-based存储如何自然地实现循环分块？
         提示：每个Archetype Chunk就是一个"tile"。

实践题1：
  计算以下场景的最优分块大小：
  - L1D大小 = 32KB
  - 每个粒子有6个float数组（x,y,z,vx,vy,vz）
  - 更新需要同时访问所有6个数组
  - 要求分块后的工作集不超过L1D的75%

实践题2：
  设计一个DOD优化的广相碰撞检测系统（Broad Phase）：
  - 100万个AABB（轴对齐包围盒），每个6个float（minX,minY,minZ,maxX,maxY,maxZ）
  - 需要找出所有重叠的AABB对
  - 要求：(a)数据布局设计 (b)排序策略 (c)遍历策略 (d)预期缓存行为分析
```

---

## 源码阅读任务

### 必读项目

1. **EnTT** (https://github.com/skypjack/entt)
   - 重点文件：`src/entt/entity/sparse_set.hpp`
   - 学习目标：理解高性能实体存储
   - 阅读时间：10小时

2. **EASTL** (https://github.com/electronicarts/EASTL)
   - 重点文件：`include/EASTL/`目录
   - 学习目标：理解游戏优化的容器设计
   - 阅读时间：8小时

3. **Folly** (https://github.com/facebook/folly)
   - 重点：`FBVector`, `small_vector`
   - 学习目标：理解工业级优化容器
   - 阅读时间：6小时

---

## 实践项目：高性能粒子系统

### 项目概述
构建一个高性能的粒子系统，实践DOD原理，支持百万级粒子实时模拟。

### 完整代码实现

#### 1. 内存对齐工具 (dod/memory/aligned_allocator.hpp)

```cpp
#pragma once

#include <cstddef>
#include <cstdlib>
#include <new>
#include <limits>

namespace dod {

// 对齐分配器
template<typename T, size_t Alignment = 64>
class AlignedAllocator {
public:
    using value_type = T;
    using pointer = T*;
    using const_pointer = const T*;
    using reference = T&;
    using const_reference = const T&;
    using size_type = std::size_t;
    using difference_type = std::ptrdiff_t;

    static constexpr size_t alignment = Alignment;

    template<typename U>
    struct rebind {
        using other = AlignedAllocator<U, Alignment>;
    };

    AlignedAllocator() noexcept = default;

    template<typename U>
    AlignedAllocator(const AlignedAllocator<U, Alignment>&) noexcept {}

    pointer allocate(size_type n) {
        if (n > std::numeric_limits<size_type>::max() / sizeof(T)) {
            throw std::bad_alloc();
        }

        size_t size = n * sizeof(T);

#if defined(_WIN32)
        void* ptr = _aligned_malloc(size, Alignment);
#else
        void* ptr = nullptr;
        if (posix_memalign(&ptr, Alignment, size) != 0) {
            ptr = nullptr;
        }
#endif

        if (!ptr) {
            throw std::bad_alloc();
        }

        return static_cast<pointer>(ptr);
    }

    void deallocate(pointer p, size_type) noexcept {
#if defined(_WIN32)
        _aligned_free(p);
#else
        free(p);
#endif
    }

    template<typename U, size_t A>
    bool operator==(const AlignedAllocator<U, A>&) const noexcept {
        return Alignment == A;
    }

    template<typename U, size_t A>
    bool operator!=(const AlignedAllocator<U, A>&) const noexcept {
        return Alignment != A;
    }
};

// 对齐的vector
template<typename T, size_t Alignment = 64>
using AlignedVector = std::vector<T, AlignedAllocator<T, Alignment>>;

} // namespace dod
```

#### 2. SoA容器 (dod/containers/soa_vector.hpp)

```cpp
#pragma once

#include "../memory/aligned_allocator.hpp"
#include <tuple>
#include <utility>

namespace dod {

// SoA向量 - 自动管理多个对齐数组
template<typename... Ts>
class SoAVector {
private:
    std::tuple<AlignedVector<Ts>...> arrays_;
    size_t size_ = 0;
    size_t capacity_ = 0;

    // 辅助函数：对元组中的每个数组执行操作
    template<typename Func, size_t... Is>
    void forEachArray(Func&& func, std::index_sequence<Is...>) {
        (func(std::get<Is>(arrays_)), ...);
    }

    template<typename Func>
    void forEachArray(Func&& func) {
        forEachArray(std::forward<Func>(func),
                     std::index_sequence_for<Ts...>{});
    }

public:
    SoAVector() = default;

    explicit SoAVector(size_t initialCapacity) {
        reserve(initialCapacity);
    }

    // 预分配空间
    void reserve(size_t newCapacity) {
        if (newCapacity <= capacity_) return;

        forEachArray([newCapacity](auto& arr) {
            arr.reserve(newCapacity);
        });

        capacity_ = newCapacity;
    }

    // 调整大小
    void resize(size_t newSize) {
        forEachArray([newSize](auto& arr) {
            arr.resize(newSize);
        });
        size_ = newSize;
        capacity_ = std::max(capacity_, newSize);
    }

    // 添加元素
    void push_back(Ts... values) {
        if (size_ >= capacity_) {
            reserve(capacity_ == 0 ? 16 : capacity_ * 2);
        }

        std::apply([&](auto&... arrays) {
            (arrays.push_back(values), ...);
        }, arrays_);

        ++size_;
    }

    // 移除元素（交换到末尾再删除）
    void swapRemove(size_t index) {
        if (index >= size_) return;

        if (index != size_ - 1) {
            forEachArray([index, this](auto& arr) {
                std::swap(arr[index], arr[size_ - 1]);
            });
        }

        forEachArray([](auto& arr) {
            arr.pop_back();
        });

        --size_;
    }

    // 获取特定数组
    template<size_t I>
    auto& get() {
        return std::get<I>(arrays_);
    }

    template<size_t I>
    const auto& get() const {
        return std::get<I>(arrays_);
    }

    // 获取特定类型的数组
    template<typename T>
    auto& getByType() {
        return std::get<AlignedVector<T>>(arrays_);
    }

    // 获取原始指针（用于SIMD）
    template<size_t I>
    auto* data() {
        return std::get<I>(arrays_).data();
    }

    template<size_t I>
    const auto* data() const {
        return std::get<I>(arrays_).data();
    }

    size_t size() const { return size_; }
    size_t capacity() const { return capacity_; }
    bool empty() const { return size_ == 0; }

    void clear() {
        forEachArray([](auto& arr) { arr.clear(); });
        size_ = 0;
    }
};

} // namespace dod
```

#### 3. 高性能粒子系统 (dod/particles/particle_system.hpp)

```cpp
#pragma once

#include "../containers/soa_vector.hpp"
#include <random>
#include <cmath>
#include <functional>

#ifdef __AVX__
#include <immintrin.h>
#endif

namespace dod {

// 粒子系统配置
struct ParticleSystemConfig {
    size_t maxParticles = 1'000'000;
    float gravity = -9.8f;
    float drag = 0.98f;
    float bounceRestitution = 0.6f;
    float groundY = 0.0f;
};

// 发射器配置
struct EmitterConfig {
    float posX = 0, posY = 5, posZ = 0;
    float spreadX = 2, spreadY = 1, spreadZ = 2;
    float minVelX = -5, maxVelX = 5;
    float minVelY = 10, maxVelY = 20;
    float minVelZ = -5, maxVelZ = 5;
    float minLife = 2, maxLife = 5;
    float minSize = 0.1f, maxSize = 0.5f;
    uint32_t emitRate = 10000;  // 每秒发射数量
};

class ParticleSystem {
private:
    // SoA数据布局
    // 索引0: x位置, 1: y位置, 2: z位置
    // 索引3: x速度, 4: y速度, 5: z速度
    // 索引6: 生命值, 7: 最大生命值, 8: 大小
    // 索引9: r颜色, 10: g颜色, 11: b颜色, 12: alpha
    SoAVector<float, float, float,   // 位置
              float, float, float,   // 速度
              float, float, float,   // 生命值, 最大生命值, 大小
              float, float, float, float>  // 颜色
        particles_;

    ParticleSystemConfig config_;
    EmitterConfig emitterConfig_;

    std::mt19937 rng_{42};
    float emitAccumulator_ = 0;

    // 辅助函数
    float randomFloat(float min, float max) {
        std::uniform_real_distribution<float> dist(min, max);
        return dist(rng_);
    }

public:
    explicit ParticleSystem(
        ParticleSystemConfig config = {},
        EmitterConfig emitter = {})
        : config_(config), emitterConfig_(emitter) {
        particles_.reserve(config_.maxParticles);
    }

    // 发射新粒子
    void emit(float dt) {
        emitAccumulator_ += emitterConfig_.emitRate * dt;

        while (emitAccumulator_ >= 1.0f &&
               particles_.size() < config_.maxParticles) {
            emitOne();
            emitAccumulator_ -= 1.0f;
        }
    }

    void emitOne() {
        float x = emitterConfig_.posX +
                  randomFloat(-emitterConfig_.spreadX, emitterConfig_.spreadX);
        float y = emitterConfig_.posY +
                  randomFloat(-emitterConfig_.spreadY, emitterConfig_.spreadY);
        float z = emitterConfig_.posZ +
                  randomFloat(-emitterConfig_.spreadZ, emitterConfig_.spreadZ);

        float vx = randomFloat(emitterConfig_.minVelX, emitterConfig_.maxVelX);
        float vy = randomFloat(emitterConfig_.minVelY, emitterConfig_.maxVelY);
        float vz = randomFloat(emitterConfig_.minVelZ, emitterConfig_.maxVelZ);

        float life = randomFloat(emitterConfig_.minLife, emitterConfig_.maxLife);
        float size = randomFloat(emitterConfig_.minSize, emitterConfig_.maxSize);

        // 随机颜色
        float r = randomFloat(0.5f, 1.0f);
        float g = randomFloat(0.2f, 0.8f);
        float b = randomFloat(0.0f, 0.3f);

        particles_.push_back(
            x, y, z,        // 位置
            vx, vy, vz,     // 速度
            life, life, size,  // 生命值, 最大生命值, 大小
            r, g, b, 1.0f   // 颜色
        );
    }

    // 更新粒子 - 标量版本
    void updateScalar(float dt) {
        const size_t count = particles_.size();
        if (count == 0) return;

        float* px = particles_.data<0>();
        float* py = particles_.data<1>();
        float* pz = particles_.data<2>();
        float* vx = particles_.data<3>();
        float* vy = particles_.data<4>();
        float* vz = particles_.data<5>();
        float* life = particles_.data<6>();
        float* maxLife = particles_.data<7>();
        float* alpha = particles_.data<12>();

        const float gravity = config_.gravity;
        const float drag = config_.drag;

        // 更新速度和位置
        for (size_t i = 0; i < count; ++i) {
            // 重力
            vy[i] += gravity * dt;

            // 阻力
            vx[i] *= drag;
            vy[i] *= drag;
            vz[i] *= drag;

            // 位置
            px[i] += vx[i] * dt;
            py[i] += vy[i] * dt;
            pz[i] += vz[i] * dt;

            // 地面碰撞
            if (py[i] < config_.groundY) {
                py[i] = config_.groundY;
                vy[i] = -vy[i] * config_.bounceRestitution;
            }

            // 生命值和透明度
            life[i] -= dt;
            alpha[i] = std::max(0.0f, life[i] / maxLife[i]);
        }
    }

#ifdef __AVX__
    // 更新粒子 - AVX向量化版本
    void updateAVX(float dt) {
        const size_t count = particles_.size();
        if (count == 0) return;

        float* px = particles_.data<0>();
        float* py = particles_.data<1>();
        float* pz = particles_.data<2>();
        float* vx = particles_.data<3>();
        float* vy = particles_.data<4>();
        float* vz = particles_.data<5>();
        float* life = particles_.data<6>();
        float* maxLife = particles_.data<7>();
        float* alpha = particles_.data<12>();

        const __m256 vdt = _mm256_set1_ps(dt);
        const __m256 vgravity = _mm256_set1_ps(config_.gravity);
        const __m256 vdrag = _mm256_set1_ps(config_.drag);
        const __m256 vground = _mm256_set1_ps(config_.groundY);
        const __m256 vrestitution = _mm256_set1_ps(-config_.bounceRestitution);
        const __m256 vzero = _mm256_setzero_ps();
        const __m256 vneg_dt = _mm256_set1_ps(-dt);

        size_t i = 0;

        // AVX处理8个粒子一组
        for (; i + 8 <= count; i += 8) {
            // 加载数据
            __m256 x = _mm256_load_ps(&px[i]);
            __m256 y = _mm256_load_ps(&py[i]);
            __m256 z = _mm256_load_ps(&pz[i]);
            __m256 vel_x = _mm256_load_ps(&vx[i]);
            __m256 vel_y = _mm256_load_ps(&vy[i]);
            __m256 vel_z = _mm256_load_ps(&vz[i]);
            __m256 l = _mm256_load_ps(&life[i]);
            __m256 ml = _mm256_load_ps(&maxLife[i]);

            // 重力: vy += gravity * dt
            vel_y = _mm256_fmadd_ps(vgravity, vdt, vel_y);

            // 阻力
            vel_x = _mm256_mul_ps(vel_x, vdrag);
            vel_y = _mm256_mul_ps(vel_y, vdrag);
            vel_z = _mm256_mul_ps(vel_z, vdrag);

            // 位置: p += v * dt
            x = _mm256_fmadd_ps(vel_x, vdt, x);
            y = _mm256_fmadd_ps(vel_y, vdt, y);
            z = _mm256_fmadd_ps(vel_z, vdt, z);

            // 地面碰撞检测
            __m256 belowGround = _mm256_cmp_ps(y, vground, _CMP_LT_OQ);
            y = _mm256_blendv_ps(y, vground, belowGround);
            __m256 bounced_vy = _mm256_mul_ps(vel_y, vrestitution);
            vel_y = _mm256_blendv_ps(vel_y, bounced_vy, belowGround);

            // 生命值
            l = _mm256_add_ps(l, vneg_dt);

            // alpha = max(0, life / maxLife)
            __m256 a = _mm256_div_ps(l, ml);
            a = _mm256_max_ps(a, vzero);

            // 存储结果
            _mm256_store_ps(&px[i], x);
            _mm256_store_ps(&py[i], y);
            _mm256_store_ps(&pz[i], z);
            _mm256_store_ps(&vx[i], vel_x);
            _mm256_store_ps(&vy[i], vel_y);
            _mm256_store_ps(&vz[i], vel_z);
            _mm256_store_ps(&life[i], l);
            _mm256_store_ps(&alpha[i], a);
        }

        // 处理剩余粒子
        for (; i < count; ++i) {
            vy[i] += config_.gravity * dt;
            vx[i] *= config_.drag;
            vy[i] *= config_.drag;
            vz[i] *= config_.drag;

            px[i] += vx[i] * dt;
            py[i] += vy[i] * dt;
            pz[i] += vz[i] * dt;

            if (py[i] < config_.groundY) {
                py[i] = config_.groundY;
                vy[i] = -vy[i] * config_.bounceRestitution;
            }

            life[i] -= dt;
            alpha[i] = std::max(0.0f, life[i] / maxLife[i]);
        }
    }
#endif

    // 移除死亡粒子
    void removeDeadParticles() {
        float* life = particles_.data<6>();
        size_t i = 0;

        while (i < particles_.size()) {
            if (life[i] <= 0) {
                particles_.swapRemove(i);
                // 不增加i，因为当前位置现在有新粒子
            } else {
                ++i;
            }
        }
    }

    // 主更新函数
    void update(float dt) {
        emit(dt);

#ifdef __AVX__
        updateAVX(dt);
#else
        updateScalar(dt);
#endif

        removeDeadParticles();
    }

    // 获取粒子数据用于渲染
    struct RenderData {
        const float* positions;  // xyz交错? 还是分离?
        const float* colors;     // rgba
        const float* sizes;
        size_t count;
    };

    RenderData getRenderData() const {
        return {
            particles_.data<0>(),  // 实际上需要组装xyz
            particles_.data<9>(),  // 实际上需要组装rgba
            particles_.data<8>(),
            particles_.size()
        };
    }

    // 统计信息
    size_t particleCount() const { return particles_.size(); }
    size_t maxParticles() const { return config_.maxParticles; }

    // 设置发射器
    void setEmitterConfig(const EmitterConfig& config) {
        emitterConfig_ = config;
    }
};

} // namespace dod
```

#### 4. 基准测试 (dod/benchmark.cpp)

```cpp
#include "particles/particle_system.hpp"
#include <chrono>
#include <iostream>
#include <iomanip>

using namespace dod;

// AoS实现用于对比
struct ParticleAoS {
    float x, y, z;
    float vx, vy, vz;
    float life, maxLife, size;
    float r, g, b, a;
};

class ParticleSystemAoS {
    std::vector<ParticleAoS> particles_;
    float gravity_ = -9.8f;
    float drag_ = 0.98f;

public:
    void resize(size_t count) {
        particles_.resize(count);
        for (auto& p : particles_) {
            p.x = p.y = p.z = 0;
            p.vx = 1; p.vy = 10; p.vz = 1;
            p.life = p.maxLife = 5;
            p.size = 0.2f;
            p.r = p.g = p.b = p.a = 1;
        }
    }

    void update(float dt) {
        for (auto& p : particles_) {
            p.vy += gravity_ * dt;
            p.vx *= drag_;
            p.vy *= drag_;
            p.vz *= drag_;

            p.x += p.vx * dt;
            p.y += p.vy * dt;
            p.z += p.vz * dt;

            if (p.y < 0) {
                p.y = 0;
                p.vy = -p.vy * 0.6f;
            }

            p.life -= dt;
            p.a = std::max(0.0f, p.life / p.maxLife);
        }
    }

    size_t size() const { return particles_.size(); }
};

template<typename Func>
double benchmark(Func&& func, int iterations) {
    // 预热
    for (int i = 0; i < 10; ++i) {
        func();
    }

    auto start = std::chrono::high_resolution_clock::now();

    for (int i = 0; i < iterations; ++i) {
        func();
    }

    auto end = std::chrono::high_resolution_clock::now();
    return std::chrono::duration<double, std::milli>(end - start).count() /
           iterations;
}

int main() {
    constexpr size_t PARTICLE_COUNTS[] = {
        10'000, 100'000, 500'000, 1'000'000
    };
    constexpr int ITERATIONS = 100;
    constexpr float DT = 0.016f;

    std::cout << std::fixed << std::setprecision(3);
    std::cout << "Particle System Benchmark (DOD vs OOP)\n";
    std::cout << "======================================\n\n";
    std::cout << std::setw(12) << "Particles"
              << std::setw(15) << "AoS (ms)"
              << std::setw(15) << "SoA (ms)"
#ifdef __AVX__
              << std::setw(15) << "SoA+AVX (ms)"
#endif
              << std::setw(15) << "Speedup"
              << "\n";
    std::cout << std::string(70, '-') << "\n";

    for (size_t count : PARTICLE_COUNTS) {
        // AoS测试
        ParticleSystemAoS aosSystem;
        aosSystem.resize(count);
        double aosTime = benchmark([&]() {
            aosSystem.update(DT);
        }, ITERATIONS);

        // SoA测试（标量）
        ParticleSystemConfig config;
        config.maxParticles = count;
        EmitterConfig emitter;
        emitter.emitRate = 0;  // 禁用发射

        ParticleSystem soaSystem(config, emitter);
        // 预填充粒子
        for (size_t i = 0; i < count; ++i) {
            soaSystem.emitOne();
        }

        double soaScalarTime = benchmark([&]() {
            soaSystem.updateScalar(DT);
        }, ITERATIONS);

#ifdef __AVX__
        double soaAvxTime = benchmark([&]() {
            soaSystem.updateAVX(DT);
        }, ITERATIONS);

        std::cout << std::setw(12) << count
                  << std::setw(15) << aosTime
                  << std::setw(15) << soaScalarTime
                  << std::setw(15) << soaAvxTime
                  << std::setw(15) << (aosTime / soaAvxTime)
                  << "x\n";
#else
        std::cout << std::setw(12) << count
                  << std::setw(15) << aosTime
                  << std::setw(15) << soaScalarTime
                  << std::setw(15) << (aosTime / soaScalarTime)
                  << "x\n";
#endif
    }

    std::cout << "\n";

    // 缓存效率分析
    std::cout << "Memory Access Analysis:\n";
    std::cout << "======================\n";
    std::cout << "AoS particle size: " << sizeof(ParticleAoS) << " bytes\n";
    std::cout << "Particles per cache line: "
              << (64 / sizeof(ParticleAoS)) << "\n";
    std::cout << "\nSoA: Each array element is 4 bytes (float)\n";
    std::cout << "Floats per cache line: 16\n";
    std::cout << "\nFor position update only:\n";
    std::cout << "  AoS: Loads " << sizeof(ParticleAoS)
              << " bytes, uses 24 bytes (position+velocity)\n";
    std::cout << "  SoA: Loads exactly what's needed\n";

    return 0;
}
```

#### 5. CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.16)
project(dod_particles VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 优化选项
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    set(CMAKE_CXX_FLAGS_RELEASE "-O3 -march=native -DNDEBUG")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -mavx -mavx2 -mfma")
elseif(MSVC)
    set(CMAKE_CXX_FLAGS_RELEASE "/O2 /arch:AVX2 /DNDEBUG")
endif()

# 检测AVX支持
include(CheckCXXCompilerFlag)
check_cxx_compiler_flag("-mavx" COMPILER_SUPPORTS_AVX)
if(COMPILER_SUPPORTS_AVX)
    add_definitions(-D__AVX__)
endif()

# 主库
add_library(dod_core INTERFACE)
target_include_directories(dod_core INTERFACE ${CMAKE_SOURCE_DIR}/include)

# 基准测试
add_executable(dod_benchmark src/benchmark.cpp)
target_link_libraries(dod_benchmark PRIVATE dod_core)

# 示例程序
add_executable(particle_demo src/main.cpp)
target_link_libraries(particle_demo PRIVATE dod_core)

# 测试
enable_testing()
find_package(GTest QUIET)
if(GTest_FOUND)
    add_executable(dod_tests
        tests/aligned_allocator_test.cpp
        tests/soa_vector_test.cpp
        tests/particle_system_test.cpp
    )
    target_link_libraries(dod_tests PRIVATE dod_core GTest::gtest_main)
    include(GoogleTest)
    gtest_discover_tests(dod_tests)
endif()
```

---

## 检验标准

### 知识检验
1. [ ] 能够解释CPU缓存层次结构及其对性能的影响
2. [ ] 理解缓存行的工作原理和缓存未命中的代价
3. [ ] 能够分析代码的数据访问模式
4. [ ] 掌握AoS与SoA的适用场景
5. [ ] 理解SIMD向量化的基本原理

### 实践检验
1. [ ] 实现对齐内存分配器
2. [ ] 完成SoA容器的设计与实现
3. [ ] 粒子系统性能达到预期（相比AoS 2-4倍提升）
4. [ ] SIMD版本正确且有明显性能提升
5. [ ] 基准测试结果符合预期

### 代码质量
1. [ ] 代码正确处理对齐
2. [ ] 无内存泄漏
3. [ ] SIMD代码正确处理边界情况
4. [ ] 有完整的基准测试

---

## 输出物清单

1. **学习笔记**
   - [ ] CPU缓存原理笔记
   - [ ] AoS vs SoA分析文档
   - [ ] 源码阅读笔记

2. **代码产出**
   - [ ] 对齐内存分配器
   - [ ] SoA容器
   - [ ] 高性能粒子系统
   - [ ] 基准测试套件

3. **分析报告**
   - [ ] 性能分析报告
   - [ ] 缓存命中率分析
   - [ ] 优化建议文档

---

## 时间分配表

| 周次 | 理论学习 | 源码阅读 | 项目实践 | 总计 |
|------|----------|----------|----------|------|
| Week 1 | 18h | 8h | 9h | 35h |
| Week 2 | 12h | 8h | 15h | 35h |
| Week 3 | 10h | 5h | 20h | 35h |
| Week 4 | 5h | 3h | 27h | 35h |
| **总计** | **45h** | **24h** | **71h** | **140h** |

---

## 下月预告

**Month 52: 面向数据设计实践**

下个月将深入DOD实践，应用于更复杂的场景：
- 空间数据结构的DOD实现（八叉树、BVH）
- 碰撞检测系统的DOD优化
- 多线程DOD设计模式
- 实践项目：高性能物理引擎核心

建议提前：
1. 复习空间数据结构基础
2. 了解AABB碰撞检测
3. 学习Intel TBB或OpenMP基础
