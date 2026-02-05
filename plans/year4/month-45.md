# Month 45: 性能分析与Profiling——找出程序的性能瓶颈

## 本月主题概述

本月深入学习性能分析工具和技术，掌握如何定位CPU热点、内存瓶颈和I/O问题。学习使用perf、Valgrind、Intel VTune等工具，以及如何编写高性能的C++代码。

**学习目标**：
- 掌握Linux perf工具的使用
- 学会使用Valgrind进行内存和缓存分析
- 理解CPU缓存和分支预测的影响
- 能够进行系统化的性能优化

---

## 理论学习内容

### 第一周：Linux perf基础

```
Week 1 学习路线图（35小时）

Day 1-2              Day 3-4              Day 5-6              Day 7
perf基础与安装        perf采样分析          火焰图生成与解读      gprof对比与总结
    │                    │                    │                    │
    ▼                    ▼                    ▼                    ▼
┌─────────┐      ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│perf stat │      │perf record   │    │FlameGraph    │    │gprof工具链   │
│perf list │      │perf report   │    │stackcollapse │    │vs perf对比   │
│perf top  │      │perf annotate │    │差分火焰图    │    │vs callgrind  │
│事件类型  │      │调用链采样    │    │交互式SVG     │    │工具选择策略  │
└─────────┘      └──────────────┘    └──────────────┘    └──────────────┘
    │                    │                    │                    │
    ▼                    ▼                    ▼                    ▼
 输出：理解           输出：定位           输出：可视化         输出：对比
 6类性能事件         CPU热点函数         性能瓶颈全景图       报告+选型指南
```

**每日任务分解**：

| 天数 | 主题 | 具体任务 | 时间 | 输出物 |
|------|------|----------|------|--------|
| Day 1 | perf安装与基础 | 安装perf工具链；理解Hardware/Software/Tracepoint三类事件；perf list探索可用事件 | 5h | perf环境配置文档 |
| Day 2 | perf stat深入 | 掌握perf stat各项指标含义；理解IPC/CPI概念；分析cache-misses/branch-misses；编写测试程序对比 | 5h | perf stat指标解读笔记 |
| Day 3 | perf record采样 | 理解采样原理（PMU溢出中断）；掌握-g调用链采样；-F频率控制；--call-graph选项（fp/dwarf/lbr） | 5h | 采样分析实验代码 |
| Day 4 | perf report分析 | 掌握perf report交互操作；perf annotate源码级分析；过滤与排序技巧；导出报表 | 5h | 热点分析报告 |
| Day 5 | 火焰图基础 | 安装FlameGraph工具；理解栈帧折叠原理；生成CPU火焰图；解读火焰图（宽度=采样比例） | 5h | 火焰图生成脚本 |
| Day 6 | 高级火焰图 | 差分火焰图（对比优化前后）；off-CPU火焰图；内存火焰图；自动化生成流程 | 5h | 差分火焰图对比报告 |
| Day 7 | gprof与工具对比 | gprof使用（-pg编译+gprof分析）；gprof vs perf vs callgrind全面对比；工具选择决策树 | 5h | 工具对比总结文档 |

**学习目标**：掌握perf工具进行CPU性能分析

**阅读材料**：
- [ ] Linux perf wiki
- [ ] Brendan Gregg的perf教程
- [ ] 《性能之巅》相关章节

**核心概念**：

```bash
# ==========================================
# perf基本命令
# ==========================================

# 安装perf (Ubuntu)
sudo apt-get install linux-tools-common linux-tools-generic

# 统计程序运行信息
perf stat ./myapp

# 详细统计
perf stat -d ./myapp

# 采样分析
perf record -g ./myapp
perf report

# 实时top视图
perf top

# 采样特定事件
perf record -e cache-misses,cache-references ./myapp

# 采样特定进程
perf record -p <pid> sleep 10

# 生成火焰图数据
perf record -g ./myapp
perf script > out.perf
# 然后使用FlameGraph工具

# ==========================================
# 常用perf事件
# ==========================================

# 列出所有可用事件
perf list

# CPU周期
perf stat -e cycles,instructions ./myapp

# 缓存
perf stat -e cache-references,cache-misses ./myapp
perf stat -e L1-dcache-loads,L1-dcache-load-misses ./myapp

# 分支预测
perf stat -e branch-instructions,branch-misses ./myapp

# 页面错误
perf stat -e page-faults,minor-faults,major-faults ./myapp

# 上下文切换
perf stat -e context-switches,cpu-migrations ./myapp
```

**perf输出解读**：

```bash
# perf stat输出示例
$ perf stat ./myapp

 Performance counter stats for './myapp':

         1,234.56 msec task-clock                #    0.998 CPUs utilized
               42 context-switches              #   34.023 /sec
                0 cpu-migrations                #    0.000 /sec
            1,234 page-faults                   # 999.676 /sec
    4,567,890,123 cycles                        #    3.699 GHz
    3,456,789,012 instructions                  #    0.76  insn per cycle
      567,890,123 branches                      #  459.987 M/sec
       12,345,678 branch-misses                 #    2.17% of all branches

       1.236789 seconds time elapsed
       1.234567 seconds user
       0.000123 seconds sys

# 关键指标解读：
# - insn per cycle (IPC): 每周期指令数，越高越好
# - branch-misses: 分支预测失败率，应该<5%
# - cache-misses: 缓存未命中率
# - context-switches: 上下文切换次数
```

**火焰图生成**：

```bash
# ==========================================
# 生成火焰图
# ==========================================

# 克隆FlameGraph仓库
git clone https://github.com/brendangregg/FlameGraph.git

# 记录
perf record -g ./myapp

# 转换格式
perf script > out.perf

# 折叠栈帧
FlameGraph/stackcollapse-perf.pl out.perf > out.folded

# 生成SVG
FlameGraph/flamegraph.pl out.folded > flamegraph.svg

# 一行命令
perf script | FlameGraph/stackcollapse-perf.pl | FlameGraph/flamegraph.pl > flamegraph.svg

# 差分火焰图（对比两次运行）
FlameGraph/difffolded.pl out1.folded out2.folded | FlameGraph/flamegraph.pl > diff.svg
```

**perf内部工作原理**：

```
perf工具三层架构

┌─────────────────────────────────────────────────────────────────┐
│                      用户空间 (Userspace)                       │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                    perf 命令行工具                         │  │
│  │  ┌─────────┐ ┌──────────┐ ┌──────────┐ ┌─────────────┐  │  │
│  │  │perf stat│ │perf record│ │perf report│ │perf annotate│  │  │
│  │  └────┬────┘ └────┬─────┘ └────┬─────┘ └──────┬──────┘  │  │
│  │       │           │            │               │          │  │
│  │       └───────────┴────────────┴───────────────┘          │  │
│  │                          │                                │  │
│  │                    perf_event_open()                       │  │
│  │                    系统调用接口                            │  │
│  └──────────────────────────┬────────────────────────────────┘  │
│                              │                                   │
├──────────────────────────────┼───────────────────────────────────┤
│                      内核空间 (Kernel)                           │
│  ┌──────────────────────────┴────────────────────────────────┐  │
│  │                  perf_events 子系统                        │  │
│  │  ┌────────────────────────────────────────────────────┐   │  │
│  │  │              事件调度器 (Event Scheduler)            │   │  │
│  │  │  ┌──────────┐ ┌───────────┐ ┌───────────────────┐  │   │  │
│  │  │  │Hardware   │ │Software   │ │Tracepoint         │  │   │  │
│  │  │  │Events     │ │Events     │ │Events             │  │   │  │
│  │  │  │cycles     │ │page-faults│ │sched:sched_switch │  │   │  │
│  │  │  │instructions│ │ctx-switch │ │block:block_rq_*  │  │   │  │
│  │  │  │cache-miss │ │cpu-clock  │ │syscalls:sys_enter │  │   │  │
│  │  │  └──────┬───┘ └─────┬─────┘ └────────┬──────────┘  │   │  │
│  │  └─────────┼───────────┼─────────────────┼─────────────┘   │  │
│  │            │           │                 │                  │  │
│  │            ▼           ▼                 ▼                  │  │
│  │     Ring Buffer (perf_mmap) ←── NMI/中断处理               │  │
│  │     采样数据存储                                            │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                   │
├──────────────────────────────┼───────────────────────────────────┤
│                      硬件层 (Hardware)                           │
│  ┌──────────────────────────┴────────────────────────────────┐  │
│  │            PMU (Performance Monitoring Unit)               │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │  通用计数器 (Programmable Counters) × 4-8个         │  │  │
│  │  │  固定计数器 (Fixed Counters) × 3个                  │  │  │
│  │  │   - 指令退休计数器 (Instructions Retired)           │  │  │
│  │  │   - 核心周期计数器 (Core Cycles)                    │  │  │
│  │  │   - 参考周期计数器 (Reference Cycles)               │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  │  计数器溢出 → 触发NMI → 内核记录IP+调用链 → Ring Buffer   │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

**CPU缓存层次结构**：

```
CPU缓存层次与访问延迟

              ┌───────────────────────┐
              │       CPU Core        │
              │  ┌─────────────────┐  │
              │  │   Registers     │  │  < 1 ns, ~1 cycle
              │  │   (~1 KB)       │  │
              │  └────────┬────────┘  │
              │           │           │
              │  ┌────────┴────────┐  │
              │  │   L1 Cache      │  │  ~1 ns, ~4 cycles
              │  │  I$ 32KB        │  │  带宽: ~1 TB/s
              │  │  D$ 32KB        │  │  行大小: 64 bytes
              │  └────────┬────────┘  │
              │           │           │
              │  ┌────────┴────────┐  │
              │  │   L2 Cache      │  │  ~3-10 ns, ~12 cycles
              │  │   256KB-1MB     │  │  带宽: ~200-500 GB/s
              │  └────────┬────────┘  │
              └───────────┼───────────┘
                          │
              ┌───────────┴───────────┐
              │   L3 Cache (共享)     │  ~10-40 ns, ~40 cycles
              │   8MB-64MB            │  带宽: ~100-200 GB/s
              │   所有核心共享        │
              └───────────┬───────────┘
                          │
              ┌───────────┴───────────┐
              │   主内存 (DRAM)       │  ~50-100 ns, ~200 cycles
              │   GB级别              │  带宽: ~25-50 GB/s
              └───────────┬───────────┘
                          │
              ┌───────────┴───────────┐
              │   磁盘/SSD            │  ~10μs(SSD) / ~10ms(HDD)
              │   TB级别              │  带宽: ~500MB/s(SSD)
              └───────────────────────┘

关键概念：
- Cache Line: 64字节，缓存操作的最小单位
- 空间局部性: 访问相邻数据比跳跃访问快
- 时间局部性: 最近访问的数据更可能再次访问
- 缓存未命中代价: L1 miss → L2 (~3x延迟)
                   L2 miss → L3 (~10x延迟)
                   L3 miss → DRAM (~50x延迟)
```

**perf record采样原理**：

```
perf record 采样流程

1. 配置阶段
   perf record -g -F 99 ./myapp
   │
   ├─ -g: 启用调用链采集（默认使用frame pointer）
   ├─ -F 99: 每秒采样99次（避开整数频率减少偶发偏差）
   │
   ▼
2. 硬件PMU配置
   ┌─────────────────────────────────────────┐
   │ perf_event_open() 系统调用               │
   │  type = PERF_TYPE_HARDWARE              │
   │  config = PERF_COUNT_HW_CPU_CYCLES      │
   │  sample_period = CPU_freq / 99          │
   │  sample_type = IP | CALLCHAIN | TID     │
   └────────────────────┬────────────────────┘
                        │
                        ▼
3. 运行时采样
   ┌─────────────────────────────────────────┐
   │         PMU计数器持续计数                 │
   │              │                           │
   │    计数器溢出 (达到sample_period)         │
   │              │                           │
   │         触发NMI中断                       │
   │              │                           │
   │    ┌─────────┴──────────┐                │
   │    │ 中断处理程序记录:   │                │
   │    │  - 指令地址 (IP)    │                │
   │    │  - 进程/线程ID      │                │
   │    │  - 调用链 (栈回溯)  │                │
   │    │  - 时间戳            │                │
   │    └─────────┬──────────┘                │
   │              │                           │
   │    写入 Ring Buffer (mmap共享内存)        │
   └─────────────────────────────────────────┘
                        │
                        ▼
4. 数据收集
   perf工具从Ring Buffer读取 → 写入perf.data文件
   │
   ▼
5. 分析阶段
   perf report: 解析perf.data → 符号解析 → 生成报告
   perf script: 导出原始采样数据 → 可用于火焰图

注意事项：
- 调用链方式选择：
  --call-graph fp    : 依赖帧指针，-fno-omit-frame-pointer编译
  --call-graph dwarf : 使用DWARF调试信息，更准确但开销大
  --call-graph lbr   : 使用Intel LBR硬件，最低开销
```

**性能分析工具对比**：

```
gprof vs perf vs callgrind 全面对比

┌────────────────┬──────────────────┬──────────────────┬──────────────────┐
│ 对比维度       │ gprof            │ perf             │ callgrind        │
├────────────────┼──────────────────┼──────────────────┼──────────────────┤
│ 分析方式       │ 插桩+采样        │ 硬件PMU采样      │ 动态二进制翻译   │
│ 需要重编译     │ 是（-pg）        │ 否               │ 否               │
│ 运行时开销     │ ~5-20%           │ ~1-5%            │ ~20-100x         │
│ 精度           │ 函数级别         │ 指令级别         │ 指令级别         │
│ 调用图         │ 有（基于插桩）   │ 有（基于采样）   │ 精确（全量）     │
│ 内核态分析     │ 不支持           │ 支持             │ 不支持           │
│ 多线程支持     │ 有限             │ 完整             │ 完整             │
│ 硬件计数器     │ 不支持           │ 完整支持         │ 模拟             │
│ 可视化工具     │ gprof2dot        │ FlameGraph       │ KCachegrind      │
├────────────────┼──────────────────┼──────────────────┼──────────────────┤
│ 适用场景       │ 快速函数级分析   │ 生产环境低开销   │ 精确调用计数     │
│                │ 简单应用首选     │ CPU热点定位      │ 缓存行为分析     │
│                │ 学习入门         │ 系统级全栈分析   │ 开发环境深度分析 │
├────────────────┼──────────────────┼──────────────────┼──────────────────┤
│ 主要局限       │ 不支持动态库     │ 统计采样有偏差   │ 极高的运行开销   │
│                │ 不支持内联函数   │ 短函数可能漏采   │ 不适合生产环境   │
│                │ 精度较低         │ 需要root或配置   │ 仅模拟缓存行为   │
└────────────────┴──────────────────┴──────────────────┴──────────────────┘

工具选择决策树：
                    需要性能分析
                         │
                    ┌────┴────┐
                    │生产环境？│
                    └────┬────┘
                   是 /     \ 否
                    /         \
              ┌────┐      ┌───────────┐
              │perf│      │需要精确    │
              └────┘      │调用计数？  │
                          └─────┬─────┘
                         是 /     \ 否
                          /         \
                    ┌──────────┐  ┌────┐
                    │callgrind │  │perf│
                    └──────────┘  └────┘
```

**Week 1 输出物清单**：

| 序号 | 输出物 | 说明 | 检验 |
|------|--------|------|------|
| 1 | perf环境配置文档 | 安装步骤、权限配置、内核参数调整 | ✅ |
| 2 | perf stat指标解读笔记 | 6类事件含义、IPC/CPI计算 | ✅ |
| 3 | 采样分析实验代码 | 含热点函数的测试程序 | ✅ |
| 4 | perf report分析报告 | 热点定位、调用链分析 | ✅ |
| 5 | 火焰图生成脚本 | 自动化生成CPU/差分火焰图 | ✅ |
| 6 | gprof对比实验 | 同一程序三种工具对比 | ✅ |
| 7 | 工具选择指南 | 场景化工具选择决策树 | ✅ |

**Week 1 检验标准**：

- [ ] 能独立安装配置perf工具，解决权限问题（perf_event_paranoid）
- [ ] 能解读perf stat输出的所有关键指标（IPC/CPI/cache-miss-rate/branch-miss-rate）
- [ ] 理解PMU硬件计数器的工作原理（计数器溢出→NMI→采样）
- [ ] 能使用perf record -g采集调用链，并用perf report定位热点
- [ ] 能区分--call-graph三种模式（fp/dwarf/lbr）的适用场景
- [ ] 能独立生成CPU火焰图并正确解读（x轴=采样比例，y轴=调用深度）
- [ ] 能生成差分火焰图对比优化前后的性能变化
- [ ] 能使用gprof进行基本性能分析（-pg编译→运行→gprof解析）
- [ ] 能画出perf三层架构图（Hardware PMU → Kernel perf_events → Userspace tools）
- [ ] 能根据场景选择合适的分析工具（生产→perf，精确计数→callgrind）

### 第二周：Valgrind工具集

```
Week 2 学习路线图（35小时）

Day 8-9               Day 10-11             Day 12-13             Day 14
Valgrind架构与原理     Callgrind调用分析     Cachegrind/Massif     DHAT/heaptrack
    │                      │                    │                    │
    ▼                      ▼                    ▼                    ▼
┌──────────────┐   ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│VEX IR翻译    │   │函数调用计数  │    │缓存模拟分析  │    │DHAT堆分析    │
│工具插件架构  │   │调用图生成    │    │L1/LL模拟     │    │heaptrack安装 │
│Memcheck原理  │   │KCachegrind   │    │Massif堆快照  │    │对比Massif    │
│Shadow Memory │   │瓶颈定位      │    │峰值内存分析  │    │可视化工具    │
└──────────────┘   └──────────────┘    └──────────────┘    └──────────────┘
    │                      │                    │                    │
    ▼                      ▼                    ▼                    ▼
 输出：理解              输出：调用           输出：缓存/          输出：现代
 DBI原理+架构图         热点精确定位         内存使用报告         替代方案对比
```

**每日任务分解**：

| 天数 | 主题 | 具体任务 | 时间 | 输出物 |
|------|------|----------|------|--------|
| Day 8 | Valgrind架构 | 理解DBI（动态二进制插桩）原理；VEX IR中间表示；工具插件架构（Core+Tool）；6个内置工具概览 | 5h | Valgrind架构笔记 |
| Day 9 | Memcheck深入 | Shadow Memory原理（V-bits/A-bits）；红区检测；泄漏分类（definitely/possibly/indirectly/still reachable）；抑制文件编写 | 5h | Memcheck原理文档 |
| Day 10 | Callgrind基础 | Callgrind运行和基本输出；理解self cost vs inclusive cost；函数调用计数与调用图 | 5h | Callgrind分析报告 |
| Day 11 | Callgrind+KCachegrind | KCachegrind可视化操作；调用图导航；瓶颈定位实战；callgrind_annotate命令行分析 | 5h | KCachegrind使用指南 |
| Day 12 | Cachegrind缓存分析 | 缓存模拟器原理（I1/D1/LL三级）；cg_annotate源码级标注；识别cache-unfriendly代码；优化前后对比 | 5h | Cachegrind分析报告 |
| Day 13 | Massif堆分析 | Massif快照机制；ms_print输出解读；峰值分配定位；--pages-as-heap全内存追踪；massif-visualizer使用 | 5h | Massif分析报告 |
| Day 14 | DHAT+heaptrack | DHAT在线分析（分配热度/生命周期）；heaptrack安装与使用；heaptrack vs Massif优劣对比；Helgrind线程检测概览 | 5h | 堆分析工具对比文档 |

**学习目标**：使用Valgrind进行内存和缓存分析

**阅读材料**：
- [ ] Valgrind官方文档
- [ ] Callgrind和KCachegrind使用指南
- [ ] Massif内存分析

```bash
# ==========================================
# Valgrind工具集
# ==========================================

# 安装
sudo apt-get install valgrind kcachegrind

# Memcheck - 内存错误检测
valgrind --leak-check=full --show-leak-kinds=all ./myapp

# Callgrind - 调用图分析
valgrind --tool=callgrind ./myapp
kcachegrind callgrind.out.*

# 生成调用图
valgrind --tool=callgrind --callgrind-out-file=callgrind.out ./myapp

# Cachegrind - 缓存分析
valgrind --tool=cachegrind ./myapp
cg_annotate cachegrind.out.*

# Massif - 堆内存分析
valgrind --tool=massif ./myapp
ms_print massif.out.*

# DHAT - 动态堆分析
valgrind --tool=dhat ./myapp

# Helgrind - 线程错误检测
valgrind --tool=helgrind ./myapp
```

**Cachegrind详解**：

```bash
# ==========================================
# Cachegrind缓存分析
# ==========================================

$ valgrind --tool=cachegrind ./myapp

==12345== Cachegrind, a cache and branch-prediction profiler
==12345==
==12345== I   refs:      1,234,567,890
==12345== I1  misses:           12,345
==12345== LLi misses:            1,234
==12345== I1  miss rate:          0.01%
==12345== LLi miss rate:          0.00%
==12345==
==12345== D   refs:        567,890,123  (345,678,901 rd   + 222,211,222 wr)
==12345== D1  misses:        1,234,567  (    987,654 rd   +     246,913 wr)
==12345== LLd misses:          123,456  (     98,765 rd   +      24,691 wr)
==12345== D1  miss rate:           0.2% (        0.3%     +         0.1%  )
==12345== LLd miss rate:           0.0% (        0.0%     +         0.0%  )
==12345==
==12345== LL refs:           1,246,912  (  1,000,000 rd   +     246,912 wr)
==12345== LL misses:           124,690  (     99,999 rd   +      24,691 wr)
==12345== LL miss rate:            0.0% (        0.0%     +         0.0%  )

# 指标解释：
# I refs: 指令引用
# D refs: 数据引用
# D1 misses: L1缓存未命中
# LL misses: 最后一级缓存（L3）未命中

# 按源码行注释
cg_annotate --auto=yes cachegrind.out.* source.cpp
```

**Massif内存分析**：

```bash
# ==========================================
# Massif堆内存分析
# ==========================================

valgrind --tool=massif --pages-as-heap=yes ./myapp

# 可视化
ms_print massif.out.* | head -100

# 输出示例（ASCII图）：
#     MB
# 12.00^                                                       #
#      |                                                      @#
#      |                                                     @@#
#      |                                                    @@@#
#      |                                                   @@@@#
#      |                                                  @@@@@#
#      |                                                 @@@@@@#
#      |                                                @@@@@@@#
#      |                                               @@@@@@@@#
#      |                                              @@@@@@@@@#
#      |                                             @@@@@@@@@@#
#      |                                            @@@@@@@@@@@#
#      |                                           @@@@@@@@@@@@#
#      |                                          @@@@@@@@@@@@@#
#      |                                         @@@@@@@@@@@@@@#
#   0 +--------------------------------------------------------------->Mi
#      0                                                           100

# 使用massif-visualizer（GUI）
sudo apt-get install massif-visualizer
massif-visualizer massif.out.*
```

**Valgrind工具集架构**：

```
Valgrind 动态二进制插桩 (DBI) 架构

┌─────────────────────────────────────────────────────────────────┐
│                    用户程序 (Guest Code)                         │
│                    原始机器码 (x86/ARM)                          │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼ 动态翻译
┌─────────────────────────────────────────────────────────────────┐
│                   Valgrind Core                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              VEX IR 中间表示 (Intermediate Representation) │  │
│  │                                                           │  │
│  │  原始指令 ──→ [前端解码] ──→ VEX IR ──→ [插桩] ──→       │  │
│  │                                          │                │  │
│  │               [后端编码] ←── 插桩后IR ←──┘                │  │
│  │                    │                                      │  │
│  │                    ▼                                      │  │
│  │              插桩后机器码 ──→ 代码缓存执行                 │  │
│  └───────────────────────────────────────────────────────────┘  │
│                            │                                     │
│                    ┌───────┴───────┐                             │
│                    │  工具插件接口  │                             │
│                    └───────┬───────┘                             │
│           ┌────────┬───────┼───────┬────────┬────────┐          │
│           ▼        ▼       ▼       ▼        ▼        ▼          │
│     ┌──────────┐┌──────┐┌──────┐┌──────┐┌──────┐┌──────────┐  │
│     │Memcheck  ││Call- ││Cache-││Massif││DHAT  ││Helgrind  │  │
│     │内存错误  ││grind ││grind ││堆内存││堆分析││线程错误  │  │
│     │          ││调用图││缓存  ││分析  ││热度  ││数据竞争  │  │
│     │Shadow    ││精确  ││模拟  ││快照  ││生命  ││Happens-  │  │
│     │Memory    ││计数  ││I1/D1 ││峰值  ││周期  ││Before    │  │
│     │V-bits    ││每条  ││/LL   ││追踪  ││分析  ││模型      │  │
│     │A-bits    ││指令  ││      ││      ││      ││          │  │
│     └──────────┘└──────┘└──────┘└──────┘└──────┘└──────────┘  │
│                                                                  │
│  运行开销: Memcheck ~20x | Callgrind ~20-100x | Cachegrind ~20x │
│           Massif ~20x    | DHAT ~20x          | Helgrind ~100x  │
└─────────────────────────────────────────────────────────────────┘

关键特性：
- 不需要重编译：直接分析二进制程序
- 完全模拟：每条指令都经过VEX IR翻译
- 精确计数：不是采样，是全量统计（代价是高开销）
- 插件化设计：Core负责翻译，Tool负责分析逻辑
```

**heaptrack——现代堆分析替代方案**：

```bash
# ==========================================
# heaptrack: Massif的现代替代
# ==========================================

# 安装 (Ubuntu)
sudo apt-get install heaptrack heaptrack-gui

# 基本使用（比Massif开销更低）
heaptrack ./myapp
# 输出: heaptrack.myapp.12345.gz

# GUI分析
heaptrack_gui heaptrack.myapp.12345.gz

# 命令行分析
heaptrack_print heaptrack.myapp.12345.gz

# 分析特定进程
heaptrack --pid <pid>
```

```
heaptrack vs Massif 对比

┌────────────────┬──────────────────┬──────────────────┐
│ 对比维度       │ Massif           │ heaptrack        │
├────────────────┼──────────────────┼──────────────────┤
│ 实现方式       │ Valgrind DBI     │ LD_PRELOAD劫持   │
│ 运行开销       │ ~20x             │ ~2-5x            │
│ 采集粒度       │ 周期快照         │ 每次分配/释放    │
│ 调用栈         │ 采样点调用栈     │ 完整调用栈       │
│ 峰值定位       │ 需手动找快照     │ 自动标记峰值     │
│ 泄漏检测       │ 不支持           │ 支持             │
│ 临时分配       │ 可能错过         │ 完整记录         │
│ 可视化         │ ms_print(ASCII)  │ 专用GUI(丰富)    │
│ 火焰图输出     │ 不支持           │ 内置支持         │
│ 适用场景       │ 无法安装heap-    │ 首选方案         │
│                │ track时的备选    │ 开发环境分析     │
└────────────────┴──────────────────┴──────────────────┘
```

**Callgrind输出解读指南**：

```
Callgrind 关键概念

1. Self Cost vs Inclusive Cost
   ┌─────────────────────────────────────────────┐
   │  main() ─── inclusive: 1000 instructions    │
   │    │                                         │
   │    ├── foo() ─── inclusive: 600              │
   │    │    │         self: 200                  │
   │    │    │                                    │
   │    │    └── bar() ─── inclusive: 400         │
   │    │                   self: 400             │
   │    │                                         │
   │    └── baz() ─── inclusive: 300              │
   │                   self: 300                  │
   │                                              │
   │  main的self cost = 1000 - 600 - 300 = 100   │
   │                                              │
   │  Self = 函数自身执行的指令数                  │
   │  Inclusive = 函数自身 + 所有被调用函数的总和   │
   └─────────────────────────────────────────────┘

2. callgrind_annotate 输出解读
   ┌──────────────────────────────────────────────┐
   │ Ir          file:function                     │
   │                                               │
   │ 1,234,567   main.cpp:processData()  ← self   │
   │   567,890   main.cpp:parseInput()             │
   │   345,678   vector.hpp:push_back()            │
   │                                               │
   │ Ir = 执行的指令数                              │
   │ 按self cost降序排列                            │
   └──────────────────────────────────────────────┘

3. 常用callgrind_control命令
   callgrind_control -i on    # 运行中开启采集
   callgrind_control -i off   # 运行中关闭采集
   callgrind_control -d       # 运行中dump当前数据
   callgrind_control -z       # 运行中清零计数器
```

**Massif峰值分析解读**：

```
Massif 输出解读

ms_print 输出结构：
┌─────────────────────────────────────────────────────┐
│  MB                                                  │
│ 12.00^                                          #   │
│      |                                         @#   │ ← 峰值快照
│      |                                        @@#   │
│      |                                   :::::@@#   │
│      |                              ::::::: ::@@#   │
│      |                         :::::::::::: ::@@#   │
│      |                    ::::::::: :::::::: ::@@#   │
│      |               ::::::::::::: :::::::: ::@@#   │
│      |          :::::::: :::::::::  :::::::: ::@@#   │
│      |     ::::::::::::: :::::::::  :::::::: ::@@#   │
│   0 +----------------------------------------------------->Mi │
│      0                                           100 │
│                                                      │
│  # = 详细快照 (detailed snapshot)                     │
│  @ = 峰值快照 (peak snapshot)                         │
│  : = 普通快照 (normal snapshot)                       │
└─────────────────────────────────────────────────────┘

详细快照展开：
┌─────────────────────────────────────────────────────┐
│ snapshot 25 (peak):                                  │
│   time=1,234,567                                     │
│   mem_heap_B=12,582,912                              │
│   mem_heap_extra_B=131,072                           │
│   mem_stacks_B=0                                     │
│                                                      │
│   n=4 分配树：                                        │
│   ├── 40.00% (5,033,164B) malloc (in libc)           │
│   │   ├── 25.00% processData() [main.cpp:42]        │
│   │   └── 15.00% loadConfig() [config.cpp:18]       │
│   ├── 35.00% (4,404,019B) operator new              │
│   │   └── 35.00% std::vector<>::push_back()         │
│   └── 25.00% (3,145,729B) mmap                      │
│       └── 25.00% std::string::reserve()             │
│                                                      │
│ 关键：找到峰值快照中占比最大的分配路径               │
└─────────────────────────────────────────────────────┘
```

**Week 2 输出物清单**：

| 序号 | 输出物 | 说明 | 检验 |
|------|--------|------|------|
| 1 | Valgrind架构笔记 | DBI原理、VEX IR、工具插件架构图 | ✅ |
| 2 | Memcheck原理文档 | Shadow Memory、V-bits/A-bits、泄漏分类 | ✅ |
| 3 | Callgrind分析报告 | 函数热点、调用图、self vs inclusive | ✅ |
| 4 | KCachegrind使用指南 | 可视化操作、瓶颈定位流程 | ✅ |
| 5 | Cachegrind缓存分析报告 | 缓存命中率、优化前后对比 | ✅ |
| 6 | Massif堆分析报告 | 峰值快照解读、分配热点定位 | ✅ |
| 7 | 堆分析工具对比文档 | heaptrack vs Massif、DHAT特性 | ✅ |

**Week 2 检验标准**：

- [ ] 能画出Valgrind DBI架构图（Guest Code → VEX IR → Instrumented Code → Cache）
- [ ] 能解释Valgrind为什么慢（每条指令都经过翻译和插桩，非采样而是全量）
- [ ] 能区分Valgrind 6个工具的功能定位和适用场景
- [ ] 能使用Callgrind分析程序并用KCachegrind可视化，定位函数级热点
- [ ] 能区分self cost和inclusive cost，并据此判断优化方向
- [ ] 能使用Cachegrind分析缓存行为，解读I1/D1/LL miss率
- [ ] 能使用Massif生成堆内存快照，定位峰值内存的分配来源
- [ ] 能安装使用heaptrack，说明其相对Massif的优势（低开销、泄漏检测、GUI）
- [ ] 能使用DHAT分析堆分配热度和对象生命周期
- [ ] 能根据分析目标选择合适的Valgrind工具（性能→Callgrind，缓存→Cachegrind，内存→Massif/heaptrack）

### 第三周：Google Benchmark与微基准测试

```
Week 3 学习路线图（35小时）

Day 15-16             Day 17-18             Day 19-20             Day 21
Benchmark安装与基础    高级Benchmark功能     微基准测试陷阱        CI集成与自动化
    │                      │                    │                    │
    ▼                      ▼                    ▼                    ▼
┌──────────────┐   ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│安装与CMake   │   │Fixtures      │    │死代码消除    │    │JSON输出格式  │
│基本测试编写  │   │Custom Counter│    │常量折叠      │    │compare.py    │
│State对象     │   │Threads       │    │CPU频率漂移   │    │CI性能回归    │
│Range/Args    │   │Template      │    │DoNotOptimize │    │GitHub Actions│
│Complexity    │   │Manual Timer  │    │ClobberMemory │    │基准线管理    │
└──────────────┘   └──────────────┘    └──────────────┘    └──────────────┘
    │                      │                    │                    │
    ▼                      ▼                    ▼                    ▼
 输出：掌握            输出：掌握           输出：识别           输出：自动化
 基本测试编写          高级测量技巧         7大常见陷阱         性能回归检测
```

**每日任务分解**：

| 天数 | 主题 | 具体任务 | 时间 | 输出物 |
|------|------|----------|------|--------|
| Day 15 | 安装与基础 | Google Benchmark安装（vcpkg/conan/源码）；CMake集成；编写第一个benchmark；理解State对象和迭代 | 5h | Benchmark项目模板 |
| Day 16 | 参数化测试 | Range/DenseRange/Args参数化；Complexity复杂度分析（O(N)/O(NlogN)）；SetBytesProcessed吞吐量 | 5h | 参数化benchmark代码 |
| Day 17 | 高级功能(一) | Fixtures（SetUp/TearDown）；Custom Counters（自定义指标）；Manual Timer（排除非测量代码） | 5h | 高级功能示例代码 |
| Day 18 | 高级功能(二) | 多线程测试（Threads/ThreadRange）；Template参数化类型；RegisterBenchmark动态注册 | 5h | 多线程benchmark代码 |
| Day 19 | 陷阱(一) | 死代码消除（DoNotOptimize）；常量折叠（ClobberMemory）；CPU频率漂移（--benchmark_enable_random_interleaving） | 5h | 陷阱演示代码 |
| Day 20 | 陷阱(二) | 分配器预热；冷启动vs热缓存；统计显著性（--benchmark_repetitions）；PauseTiming的陷阱 | 5h | 陷阱避免清单 |
| Day 21 | CI集成 | JSON输出格式解析；compare.py对比脚本；GitHub Actions性能回归检测；基准线管理策略 | 5h | CI benchmark workflow |

**学习目标**：编写科学的微基准测试

**阅读材料**：
- [ ] Google Benchmark文档
- [ ] 微基准测试陷阱
- [ ] CPU流水线和优化器影响

```cpp
// ==========================================
// Google Benchmark基础
// ==========================================
#include <benchmark/benchmark.h>
#include <vector>
#include <algorithm>
#include <random>

// 基本基准测试
static void BM_VectorPushBack(benchmark::State& state) {
    for (auto _ : state) {
        std::vector<int> v;
        for (int i = 0; i < state.range(0); ++i) {
            v.push_back(i);
        }
        benchmark::DoNotOptimize(v.data());
    }
    state.SetComplexityN(state.range(0));
}
BENCHMARK(BM_VectorPushBack)->Range(8, 8<<10)->Complexity();

// 带预留空间
static void BM_VectorPushBackReserved(benchmark::State& state) {
    for (auto _ : state) {
        std::vector<int> v;
        v.reserve(state.range(0));
        for (int i = 0; i < state.range(0); ++i) {
            v.push_back(i);
        }
        benchmark::DoNotOptimize(v.data());
    }
}
BENCHMARK(BM_VectorPushBackReserved)->Range(8, 8<<10);

// 比较不同排序算法
static void BM_StdSort(benchmark::State& state) {
    std::vector<int> v(state.range(0));
    std::iota(v.begin(), v.end(), 0);

    for (auto _ : state) {
        state.PauseTiming();
        std::shuffle(v.begin(), v.end(), std::mt19937{42});
        state.ResumeTiming();

        std::sort(v.begin(), v.end());
        benchmark::DoNotOptimize(v.data());
    }
}
BENCHMARK(BM_StdSort)->Range(8, 8<<16);

static void BM_StableSort(benchmark::State& state) {
    std::vector<int> v(state.range(0));
    std::iota(v.begin(), v.end(), 0);

    for (auto _ : state) {
        state.PauseTiming();
        std::shuffle(v.begin(), v.end(), std::mt19937{42});
        state.ResumeTiming();

        std::stable_sort(v.begin(), v.end());
        benchmark::DoNotOptimize(v.data());
    }
}
BENCHMARK(BM_StableSort)->Range(8, 8<<16);

// 内存访问模式比较
static void BM_SequentialAccess(benchmark::State& state) {
    std::vector<int> v(1024 * 1024, 1);

    for (auto _ : state) {
        int sum = 0;
        for (int i = 0; i < v.size(); ++i) {
            sum += v[i];
        }
        benchmark::DoNotOptimize(sum);
    }
    state.SetBytesProcessed(state.iterations() * v.size() * sizeof(int));
}
BENCHMARK(BM_SequentialAccess);

static void BM_RandomAccess(benchmark::State& state) {
    std::vector<int> v(1024 * 1024, 1);
    std::vector<int> indices(v.size());
    std::iota(indices.begin(), indices.end(), 0);
    std::shuffle(indices.begin(), indices.end(), std::mt19937{42});

    for (auto _ : state) {
        int sum = 0;
        for (int idx : indices) {
            sum += v[idx];
        }
        benchmark::DoNotOptimize(sum);
    }
    state.SetBytesProcessed(state.iterations() * v.size() * sizeof(int));
}
BENCHMARK(BM_RandomAccess);

// 缓存行效应
static void BM_StrideAccess(benchmark::State& state) {
    std::vector<int> v(1024 * 1024, 1);
    const int stride = state.range(0);

    for (auto _ : state) {
        int sum = 0;
        for (int i = 0; i < v.size(); i += stride) {
            sum += v[i];
        }
        benchmark::DoNotOptimize(sum);
    }
}
BENCHMARK(BM_StrideAccess)->RangeMultiplier(2)->Range(1, 64);

// 分支预测
static void BM_PredictableBranch(benchmark::State& state) {
    std::vector<int> v(10000);
    std::iota(v.begin(), v.end(), 0);  // 有序

    for (auto _ : state) {
        int sum = 0;
        for (int x : v) {
            if (x < 5000) {  // 可预测：前半部分都是true
                sum += x;
            }
        }
        benchmark::DoNotOptimize(sum);
    }
}
BENCHMARK(BM_PredictableBranch);

static void BM_UnpredictableBranch(benchmark::State& state) {
    std::vector<int> v(10000);
    std::iota(v.begin(), v.end(), 0);
    std::shuffle(v.begin(), v.end(), std::mt19937{42});  // 随机

    for (auto _ : state) {
        int sum = 0;
        for (int x : v) {
            if (x < 5000) {  // 不可预测
                sum += x;
            }
        }
        benchmark::DoNotOptimize(sum);
    }
}
BENCHMARK(BM_UnpredictableBranch);

BENCHMARK_MAIN();
```

```cmake
# CMakeLists.txt
find_package(benchmark REQUIRED)

add_executable(benchmarks
    benchmarks.cpp
)

target_link_libraries(benchmarks
    PRIVATE
        benchmark::benchmark
)
```

**Google Benchmark高级功能**：

```cpp
// ==========================================
// Fixtures: 测试夹具——管理SetUp/TearDown
// ==========================================
class DatabaseBenchmark : public benchmark::Fixture {
public:
    void SetUp(const benchmark::State& state) override {
        // 每次benchmark运行前初始化
        db_.clear();
        for (int i = 0; i < state.range(0); ++i) {
            db_.insert({i, "value_" + std::to_string(i)});
        }
    }

    void TearDown(const benchmark::State&) override {
        db_.clear();
    }

protected:
    std::unordered_map<int, std::string> db_;
};

BENCHMARK_DEFINE_F(DatabaseBenchmark, Lookup)(benchmark::State& state) {
    std::mt19937 rng(42);
    std::uniform_int_distribution<int> dist(0, state.range(0) - 1);

    for (auto _ : state) {
        auto it = db_.find(dist(rng));
        benchmark::DoNotOptimize(it);
    }
}
BENCHMARK_REGISTER_F(DatabaseBenchmark, Lookup)->Range(100, 100000);

// ==========================================
// Custom Counters: 自定义性能指标
// ==========================================
static void BM_CustomCounters(benchmark::State& state) {
    int64_t items_processed = 0;
    int64_t cache_hits = 0;
    int64_t cache_misses = 0;

    for (auto _ : state) {
        // 模拟缓存操作
        for (int i = 0; i < 1000; ++i) {
            if (i % 3 == 0) {
                ++cache_misses;
            } else {
                ++cache_hits;
            }
            ++items_processed;
        }
    }

    // 报告自定义计数器
    state.counters["items/s"] = benchmark::Counter(
        items_processed, benchmark::Counter::kIsRate);
    state.counters["hit_rate"] = benchmark::Counter(
        cache_hits * 100.0 / (cache_hits + cache_misses),
        benchmark::Counter::kDefaults);
    state.counters["throughput"] = benchmark::Counter(
        items_processed * sizeof(int),
        benchmark::Counter::kIsRate | benchmark::Counter::kIs1024);
}
BENCHMARK(BM_CustomCounters);

// ==========================================
// Threads: 多线程基准测试
// ==========================================
static void BM_SharedCounter(benchmark::State& state) {
    static std::atomic<int64_t> shared_counter{0};

    if (state.thread_index() == 0) {
        // 主线程初始化
        shared_counter = 0;
    }

    for (auto _ : state) {
        shared_counter.fetch_add(1, std::memory_order_relaxed);
    }

    state.counters["ops/thread"] = benchmark::Counter(
        shared_counter.load() / state.threads(),
        benchmark::Counter::kDefaults);
}
BENCHMARK(BM_SharedCounter)->Threads(1)->Threads(2)->Threads(4)->Threads(8);
// 或使用 ThreadRange
BENCHMARK(BM_SharedCounter)->ThreadRange(1, 8);

// ==========================================
// Template: 类型参数化测试
// ==========================================
template<typename Container>
static void BM_ContainerInsert(benchmark::State& state) {
    for (auto _ : state) {
        Container c;
        for (int i = 0; i < state.range(0); ++i) {
            c.insert(c.end(), i);
        }
        benchmark::DoNotOptimize(c);
    }
}
BENCHMARK_TEMPLATE(BM_ContainerInsert, std::vector<int>)->Range(8, 8<<10);
BENCHMARK_TEMPLATE(BM_ContainerInsert, std::list<int>)->Range(8, 8<<10);
BENCHMARK_TEMPLATE(BM_ContainerInsert, std::deque<int>)->Range(8, 8<<10);

// ==========================================
// Manual Timer: 排除非测量代码
// ==========================================
static void BM_WithSetup(benchmark::State& state) {
    for (auto _ : state) {
        // 暂停计时——准备阶段不计入测量
        state.PauseTiming();
        auto data = generateTestData(state.range(0));
        state.ResumeTiming();

        // 只测量这部分
        processData(data);
        benchmark::DoNotOptimize(data);
    }
}
// 注意：PauseTiming/ResumeTiming有自身开销（~100ns）
// 如果被测代码本身很快（<10ns），会导致测量不准确
// 此时应在外部准备数据，或使用Fixtures的SetUp
```

**DoNotOptimize vs ClobberMemory 语义解析**：

```
编译器优化屏障

┌─────────────────────────────────────────────────────────────────┐
│                    benchmark::DoNotOptimize(x)                  │
│                                                                  │
│  作用：告诉编译器x的值"被使用了"，阻止死代码消除               │
│                                                                  │
│  实现原理（简化）：                                              │
│    template<typename T>                                          │
│    void DoNotOptimize(T& value) {                                │
│        asm volatile("" : "+r,m"(value) : : "memory");           │
│        // "+r,m": value可能被读写（在寄存器或内存中）            │
│        // "memory": 可能读写任何内存                              │
│    }                                                             │
│                                                                  │
│  使用场景：                                                      │
│    int result = compute(data);                                   │
│    benchmark::DoNotOptimize(result);  // 阻止编译器优化掉compute│
│                                                                  │
│  等价于：假装result会被传递给一个外部函数                        │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    benchmark::ClobberMemory()                    │
│                                                                  │
│  作用：告诉编译器"所有内存可能已被修改"，强制重新加载          │
│                                                                  │
│  实现原理：                                                      │
│    void ClobberMemory() {                                        │
│        asm volatile("" : : : "memory");                          │
│        // "memory" clobber: 所有内存被认为已修改                 │
│    }                                                             │
│                                                                  │
│  使用场景：                                                      │
│    container.push_back(42);                                      │
│    benchmark::ClobberMemory();  // 强制后续访问重新从内存读取    │
│                                                                  │
│  等价于：假装有一个外部函数修改了所有全局状态                    │
└─────────────────────────────────────────────────────────────────┘

组合使用模式：
┌──────────────────────────────────────┐
│  for (auto _ : state) {              │
│      auto result = compute(data);    │
│      DoNotOptimize(result);  // ①    │
│      ClobberMemory();        // ②    │
│  }                                   │
│                                      │
│  ① 防止compute()被优化掉            │
│  ② 防止编译器缓存data的值           │
│     确保下次循环重新读取data         │
└──────────────────────────────────────┘
```

**微基准测试七大陷阱**：

```
┌─────────────────────────────────────────────────────────────────┐
│                    微基准测试 7 大陷阱                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  陷阱1: 死代码消除 (Dead Code Elimination)                       │
│  ┌─────────────────────────────────────────────────┐            │
│  │  ✗ 错误:                                        │            │
│  │    int x = expensive_compute();                  │            │
│  │    // 编译器发现x从未使用，直接删除compute调用   │            │
│  │                                                  │            │
│  │  ✓ 正确:                                        │            │
│  │    int x = expensive_compute();                  │            │
│  │    benchmark::DoNotOptimize(x);                  │            │
│  └─────────────────────────────────────────────────┘            │
│                                                                  │
│  陷阱2: 常量折叠 (Constant Folding)                              │
│  ┌─────────────────────────────────────────────────┐            │
│  │  ✗ 错误:                                        │            │
│  │    int result = fibonacci(20);                   │            │
│  │    // 编译时即可计算，运行时直接用常量           │            │
│  │                                                  │            │
│  │  ✓ 正确:                                        │            │
│  │    int n = 20;                                   │            │
│  │    benchmark::DoNotOptimize(n);                  │            │
│  │    int result = fibonacci(n);                    │            │
│  │    benchmark::DoNotOptimize(result);             │            │
│  └─────────────────────────────────────────────────┘            │
│                                                                  │
│  陷阱3: CPU频率漂移 (Frequency Scaling)                          │
│  ┌─────────────────────────────────────────────────┐            │
│  │  问题: CPU从省电模式切换到性能模式需要时间       │            │
│  │  前几次迭代可能在低频下运行                      │            │
│  │                                                  │            │
│  │  ✓ 解决方案:                                    │            │
│  │  - 使用 --benchmark_enable_random_interleaving   │            │
│  │  - 使用 --benchmark_min_warmup_time=0.5          │            │
│  │  - 系统级: cpupower frequency-set -g performance │            │
│  └─────────────────────────────────────────────────┘            │
│                                                                  │
│  陷阱4: 分配器预热 (Allocator Warmup)                            │
│  ┌─────────────────────────────────────────────────┐            │
│  │  问题: 首次malloc需要向OS申请内存（系统调用）    │            │
│  │  后续malloc从free list分配（用户态，快得多）     │            │
│  │                                                  │            │
│  │  ✓ 解决方案:                                    │            │
│  │  - 在SetUp中进行预分配                           │            │
│  │  - 使用Fixtures的SetUp/TearDown                  │            │
│  └─────────────────────────────────────────────────┘            │
│                                                                  │
│  陷阱5: 冷缓存 vs 热缓存 (Cache Effects)                        │
│  ┌─────────────────────────────────────────────────┐            │
│  │  问题: 第一次访问数据在主内存，后续在L1/L2       │            │
│  │  测量结果取决于缓存是冷还是热                    │            │
│  │                                                  │            │
│  │  ✓ 解决方案:                                    │            │
│  │  - 明确测试的是冷访问还是热访问                  │            │
│  │  - 冷: 每次迭代使用不同的数据集                  │            │
│  │  - 热: 数据集足够小，确保完全在缓存中            │            │
│  └─────────────────────────────────────────────────┘            │
│                                                                  │
│  陷阱6: PauseTiming开销 (Timer Overhead)                         │
│  ┌─────────────────────────────────────────────────┐            │
│  │  问题: PauseTiming/ResumeTiming每次~100ns       │            │
│  │  如果被测代码<10ns，计时开销比测量对象大          │            │
│  │                                                  │            │
│  │  ✓ 解决方案:                                    │            │
│  │  - 避免在内层循环使用Pause/Resume                │            │
│  │  - 改用Fixtures的SetUp准备数据                   │            │
│  │  - 或在外部提前准备好所有测试数据                │            │
│  └─────────────────────────────────────────────────┘            │
│                                                                  │
│  陷阱7: 统计不显著 (Statistical Insignificance)                  │
│  ┌─────────────────────────────────────────────────┐            │
│  │  问题: 单次运行结果不稳定，噪声可能掩盖真实差异 │            │
│  │                                                  │            │
│  │  ✓ 解决方案:                                    │            │
│  │  - --benchmark_repetitions=10 多次重复           │            │
│  │  - 自动计算mean/median/stddev                    │            │
│  │  - 标准差>5%时应关注系统噪声                     │            │
│  │  - 使用compare.py进行统计对比                    │            │
│  └─────────────────────────────────────────────────┘            │
└─────────────────────────────────────────────────────────────────┘
```

**Benchmark输出解读指南**：

```
Google Benchmark 输出格式解读

$ ./benchmarks --benchmark_format=console

--------------------------------------------------------------------
Benchmark                          Time       CPU   Iterations
--------------------------------------------------------------------
BM_VectorPushBack/8               45 ns     44 ns     15909091
BM_VectorPushBack/64             312 ns    310 ns      2258065
BM_VectorPushBack/512           2451 ns   2440 ns       286885
BM_VectorPushBack/4096         19876 ns  19790 ns        35369
BM_VectorPushBack_BigO          4.85 N     4.83 N
BM_VectorPushBack_RMS              2 %        2 %

字段解读：
┌──────────────┬────────────────────────────────────────────┐
│ Time         │ 挂钟时间（Wall Time），包含等待/调度开销    │
│ CPU          │ CPU时间，仅计算用户态+内核态CPU占用         │
│ Iterations   │ benchmark框架自动选择的迭代次数             │
│              │ 迭代越多，统计越准确                        │
│ BigO         │ 通过Complexity()自动拟合的复杂度            │
│ RMS          │ 拟合的均方根误差（越小越好）               │
└──────────────┴────────────────────────────────────────────┘

JSON输出（用于CI对比）：
$ ./benchmarks --benchmark_format=json --benchmark_out=results.json

对比两次运行结果：
$ python3 tools/compare.py benchmarks \
    baseline_results.json current_results.json

输出：
Benchmark                          Time       CPU
BM_VectorPushBack/512           -0.05     -0.04    # 改善5%
BM_RandomAccess                 +0.12     +0.11    # 退化12% ⚠️
```

**Week 3 输出物清单**：

| 序号 | 输出物 | 说明 | 检验 |
|------|--------|------|------|
| 1 | Benchmark项目模板 | CMake集成、基本测试结构 | ✅ |
| 2 | 参数化benchmark代码 | Range/Complexity/BytesProcessed | ✅ |
| 3 | 高级功能示例代码 | Fixtures/Counters/Template/ManualTimer | ✅ |
| 4 | 多线程benchmark代码 | Threads/ThreadRange/atomic对比 | ✅ |
| 5 | 陷阱演示代码 | 7大陷阱的正反对比示例 | ✅ |
| 6 | 陷阱避免清单 | 微基准测试最佳实践指南 | ✅ |
| 7 | CI benchmark workflow | JSON输出+compare.py+GitHub Actions | ✅ |

**Week 3 检验标准**：

- [ ] 能独立搭建Google Benchmark项目（CMake集成、vcpkg/conan安装）
- [ ] 能编写参数化benchmark（Range/DenseRange/Args/ArgsProduct）
- [ ] 能使用Complexity()自动拟合算法复杂度（O(N)/O(NlogN)/O(N²)）
- [ ] 能编写Fixture benchmark（SetUp/TearDown管理测试状态）
- [ ] 能使用Custom Counters报告自定义指标（ops/s、hit_rate等）
- [ ] 能编写多线程benchmark并分析锁竞争对性能的影响
- [ ] 能解释DoNotOptimize和ClobberMemory的作用原理（内联汇编约束）
- [ ] 能识别并避免微基准测试7大陷阱（死代码/常量折叠/频率漂移等）
- [ ] 能解读benchmark输出（Time/CPU/Iterations/BigO/RMS含义）
- [ ] 能使用JSON输出和compare.py进行性能回归对比

### 第四周：实际性能优化案例

```
Week 4 学习路线图（35小时）

Day 22-23             Day 24-25             Day 26-27             Day 28
矩阵乘法优化5级       DOD与Cache Line       CI性能回归检测        总结与综合实战
    │                      │                    │                    │
    ▼                      ▼                    ▼                    ▼
┌──────────────┐   ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│naive→reorder │   │AoS vs SoA   │    │benchmark JSON│    │综合优化实战  │
│→blocked      │   │Cache Line    │    │compare.py    │    │Measure→Ident-│
│→flat→SIMD    │   │False Sharing │    │GitHub Actions│    │ify→Optimize  │
│性能对比测量  │   │Padding/Align │    │自动化报告    │    │→Verify循环   │
└──────────────┘   └──────────────┘    └──────────────┘    └──────────────┘
    │                      │                    │                    │
    ▼                      ▼                    ▼                    ▼
 输出：5级优化         输出：DOD            输出：CI性能         输出：优化
 性能对比报告          实践代码+图          回归检测pipeline     方法论总结
```

**每日任务分解**：

| 天数 | 主题 | 具体任务 | 时间 | 输出物 |
|------|------|----------|------|--------|
| Day 22 | 矩阵乘法(一) | naive实现→循环重排→分块(tiling)；理解每级优化的缓存行为变化；用perf stat测量cache-misses | 5h | 3级优化对比代码 |
| Day 23 | 矩阵乘法(二) | 连续内存布局(flat Matrix)→SIMD(AVX2)；用benchmark测量5级加速比；用Cachegrind验证缓存行为 | 5h | 5级优化benchmark报告 |
| Day 24 | AoS vs SoA | Array of Structures vs Structure of Arrays；缓存利用率分析；用perf测量cache-miss差异；实际应用场景 | 5h | AoS/SoA对比代码 |
| Day 25 | Cache Line分析 | Cache line大小（64B）影响；false sharing问题与检测；alignas/padding修复；perf c2c工具 | 5h | false sharing示例+修复 |
| Day 26 | CI性能回归(一) | benchmark JSON输出格式；compare.py脚本使用；性能阈值设定策略（百分比 vs 绝对值） | 5h | 性能对比脚本 |
| Day 27 | CI性能回归(二) | GitHub Actions集成workflow；基准线管理（artifact存储）；PR性能报告自动评论；告警机制 | 5h | CI workflow YAML |
| Day 28 | 综合总结 | 性能优化方法论（Measure→Identify→Optimize→Verify）；本月知识整合；综合实战演练 | 5h | 月度总结报告 |

**学习目标**：综合运用工具进行性能优化

**阅读材料**：
- [ ] 《C++性能优化指南》
- [ ] SIMD指令入门
- [ ] 数据局部性优化

```cpp
// ==========================================
// 性能优化案例：矩阵乘法
// ==========================================
#include <vector>
#include <chrono>
#include <iostream>

// 朴素实现
void matrix_multiply_naive(
    const std::vector<std::vector<double>>& A,
    const std::vector<std::vector<double>>& B,
    std::vector<std::vector<double>>& C,
    int N
) {
    for (int i = 0; i < N; ++i) {
        for (int j = 0; j < N; ++j) {
            C[i][j] = 0;
            for (int k = 0; k < N; ++k) {
                C[i][j] += A[i][k] * B[k][j];
            }
        }
    }
}

// 优化1：改变循环顺序（更好的缓存局部性）
void matrix_multiply_reordered(
    const std::vector<std::vector<double>>& A,
    const std::vector<std::vector<double>>& B,
    std::vector<std::vector<double>>& C,
    int N
) {
    // 先清零
    for (int i = 0; i < N; ++i) {
        for (int j = 0; j < N; ++j) {
            C[i][j] = 0;
        }
    }

    // i-k-j顺序
    for (int i = 0; i < N; ++i) {
        for (int k = 0; k < N; ++k) {
            for (int j = 0; j < N; ++j) {
                C[i][j] += A[i][k] * B[k][j];
            }
        }
    }
}

// 优化2：分块（tiling）
void matrix_multiply_blocked(
    const std::vector<std::vector<double>>& A,
    const std::vector<std::vector<double>>& B,
    std::vector<std::vector<double>>& C,
    int N
) {
    constexpr int BLOCK_SIZE = 64;

    // 清零
    for (int i = 0; i < N; ++i) {
        for (int j = 0; j < N; ++j) {
            C[i][j] = 0;
        }
    }

    for (int ii = 0; ii < N; ii += BLOCK_SIZE) {
        for (int kk = 0; kk < N; kk += BLOCK_SIZE) {
            for (int jj = 0; jj < N; jj += BLOCK_SIZE) {
                // 处理块
                for (int i = ii; i < std::min(ii + BLOCK_SIZE, N); ++i) {
                    for (int k = kk; k < std::min(kk + BLOCK_SIZE, N); ++k) {
                        for (int j = jj; j < std::min(jj + BLOCK_SIZE, N); ++j) {
                            C[i][j] += A[i][k] * B[k][j];
                        }
                    }
                }
            }
        }
    }
}

// 优化3：使用连续内存布局
class Matrix {
public:
    Matrix(int rows, int cols) : rows_(rows), cols_(cols), data_(rows * cols) {}

    double& operator()(int i, int j) { return data_[i * cols_ + j]; }
    double operator()(int i, int j) const { return data_[i * cols_ + j]; }

    int rows() const { return rows_; }
    int cols() const { return cols_; }
    double* data() { return data_.data(); }

private:
    int rows_, cols_;
    std::vector<double> data_;
};

void matrix_multiply_flat(
    const Matrix& A,
    const Matrix& B,
    Matrix& C
) {
    const int N = A.rows();
    constexpr int BLOCK_SIZE = 64;

    // 清零
    std::fill(C.data(), C.data() + N * N, 0.0);

    for (int ii = 0; ii < N; ii += BLOCK_SIZE) {
        for (int kk = 0; kk < N; kk += BLOCK_SIZE) {
            for (int jj = 0; jj < N; jj += BLOCK_SIZE) {
                for (int i = ii; i < std::min(ii + BLOCK_SIZE, N); ++i) {
                    for (int k = kk; k < std::min(kk + BLOCK_SIZE, N); ++k) {
                        const double a_ik = A(i, k);
                        for (int j = jj; j < std::min(jj + BLOCK_SIZE, N); ++j) {
                            C(i, j) += a_ik * B(k, j);
                        }
                    }
                }
            }
        }
    }
}

// 优化4：SIMD（需要编译器支持）
#ifdef __AVX2__
#include <immintrin.h>

void matrix_multiply_simd(
    const Matrix& A,
    const Matrix& B,
    Matrix& C
) {
    const int N = A.rows();

    std::fill(C.data(), C.data() + N * N, 0.0);

    for (int i = 0; i < N; ++i) {
        for (int k = 0; k < N; ++k) {
            __m256d a_ik = _mm256_set1_pd(A(i, k));

            int j = 0;
            for (; j + 4 <= N; j += 4) {
                __m256d b_kj = _mm256_loadu_pd(&B(k, j));
                __m256d c_ij = _mm256_loadu_pd(&C(i, j));
                c_ij = _mm256_fmadd_pd(a_ik, b_kj, c_ij);
                _mm256_storeu_pd(&C(i, j), c_ij);
            }

            // 处理剩余元素
            for (; j < N; ++j) {
                C(i, j) += A(i, k) * B(k, j);
            }
        }
    }
}
#endif
```

**性能优化方法论**：

```
性能优化 MIVO 循环

        ┌─────────────┐
        │   Measure    │  1. 测量：建立性能基准线
        │   (测量)     │     - perf stat 获取硬件指标
        │              │     - benchmark 获取时间指标
        └──────┬───────┘     - 记录优化前的完整指标
               │
               ▼
        ┌─────────────┐
        │   Identify   │  2. 识别：定位性能瓶颈
        │   (定位)     │     - 火焰图定位CPU热点
        │              │     - Cachegrind分析缓存行为
        └──────┬───────┘     - Callgrind分析调用关系
               │
               ▼
        ┌─────────────┐
        │   Optimize   │  3. 优化：针对性改进
        │   (优化)     │     - 算法优化（复杂度降低）
        │              │     - 数据结构优化（缓存友好）
        └──────┬───────┘     - 底层优化（SIMD/内存布局）
               │
               ▼
        ┌─────────────┐
        │   Verify     │  4. 验证：确认改进有效
        │   (验证)     │     - 重新测量，对比基准线
        │              │     - 差分火焰图对比
        └──────┬───────┘     - 确保正确性未被破坏
               │
               └──────────→ 回到 Measure（继续下一轮）

关键原则：
┌────────────────────────────────────────────────────┐
│ 1. 永远先测量，不要猜测瓶颈在哪里                  │
│ 2. 优化热点（80/20法则：20%代码占80%时间）         │
│ 3. 一次只改一个地方，便于验证效果                  │
│ 4. 保持正确性——错误的快速代码没有价值              │
│ 5. 知道何时停止——过度优化降低可维护性              │
└────────────────────────────────────────────────────┘
```

**Data-Oriented Design: AoS vs SoA**：

```cpp
// ==========================================
// AoS (Array of Structures) vs SoA (Structure of Arrays)
// ==========================================
#include <vector>
#include <benchmark/benchmark.h>

// ===== AoS: 传统面向对象布局 =====
struct ParticleAoS {
    float x, y, z;      // 位置
    float vx, vy, vz;   // 速度
    float mass;          // 质量
    float radius;        // 半径
    // 每个Particle = 32 bytes，正好半个cache line
};

std::vector<ParticleAoS> particles_aos;

// 只更新位置时，速度/质量/半径也被加载进缓存
// 缓存利用率: 12/32 = 37.5%（浪费了62.5%的缓存带宽）
void updatePositions_AoS(std::vector<ParticleAoS>& p, float dt) {
    for (auto& particle : p) {
        particle.x += particle.vx * dt;   // 需要加载整个结构体
        particle.y += particle.vy * dt;    // mass和radius也进了缓存
        particle.z += particle.vz * dt;    // 但完全没用到
    }
}

// ===== SoA: 数据导向设计布局 =====
struct ParticlesSoA {
    std::vector<float> x, y, z;      // 位置（连续存储）
    std::vector<float> vx, vy, vz;   // 速度（连续存储）
    std::vector<float> mass;          // 质量（连续存储）
    std::vector<float> radius;        // 半径（连续存储）
    size_t count;
};

// 只访问需要的数据，缓存利用率接近100%
// 而且SIMD友好：连续的float数组可以直接用AVX处理
void updatePositions_SoA(ParticlesSoA& p, float dt) {
    for (size_t i = 0; i < p.count; ++i) {
        p.x[i] += p.vx[i] * dt;   // x[]连续，完美预取
        p.y[i] += p.vy[i] * dt;   // y[]连续，完美预取
        p.z[i] += p.vz[i] * dt;   // z[]连续，完美预取
    }
    // 缓存利用率: 接近100%（只加载需要的数据）
}

// Benchmark对比
static void BM_AoS_Update(benchmark::State& state) {
    const int N = state.range(0);
    std::vector<ParticleAoS> particles(N);

    for (auto _ : state) {
        updatePositions_AoS(particles, 0.016f);
        benchmark::DoNotOptimize(particles.data());
    }
    state.SetBytesProcessed(state.iterations() * N * 6 * sizeof(float));
}
BENCHMARK(BM_AoS_Update)->Range(1024, 1<<20);

static void BM_SoA_Update(benchmark::State& state) {
    const int N = state.range(0);
    ParticlesSoA particles;
    particles.count = N;
    particles.x.resize(N); particles.y.resize(N); particles.z.resize(N);
    particles.vx.resize(N); particles.vy.resize(N); particles.vz.resize(N);

    for (auto _ : state) {
        updatePositions_SoA(particles, 0.016f);
        benchmark::ClobberMemory();
    }
    state.SetBytesProcessed(state.iterations() * N * 6 * sizeof(float));
}
BENCHMARK(BM_SoA_Update)->Range(1024, 1<<20);
```

```
AoS vs SoA 缓存行为对比

AoS: 更新位置时的缓存行(64B)加载情况
┌────────────────────────────────────────────────────────────────┐
│ Cache Line 0 (64B):                                            │
│ [x₀|y₀|z₀|vx₀|vy₀|vz₀|mass₀|rad₀|x₁|y₁|z₁|vx₁|vy₁|vz₁|..│
│  ✓  ✓  ✓  ✓   ✓   ✓   ✗     ✗    ✓  ✓  ✓  ✓   ✓   ✓       │
│                                                                │
│ ✓ = 需要的数据   ✗ = 不需要但被加载的数据                      │
│ 缓存利用率 ≈ 75% (24B有用 / 32B每粒子)                        │
│ 如果只更新xyz: 37.5% (12B有用 / 32B每粒子)                    │
└────────────────────────────────────────────────────────────────┘

SoA: 更新位置时的缓存行加载情况
┌────────────────────────────────────────────────────────────────┐
│ Cache Line 0 (64B) from x[]:                                   │
│ [x₀|x₁|x₂|x₃|x₄|x₅|x₆|x₇|x₈|x₉|x₁₀|x₁₁|x₁₂|x₁₃|x₁₄|x₁₅]│
│  ✓   ✓  ✓  ✓  ✓  ✓  ✓  ✓  ✓  ✓   ✓    ✓    ✓    ✓    ✓    ✓ │
│                                                                │
│ 所有数据都是需要的！                                            │
│ 缓存利用率 = 100%                                               │
│ 而且CPU预取器可以完美预测连续访问模式                           │
└────────────────────────────────────────────────────────────────┘

选择指南：
- AoS适合: 经常需要同一对象的所有字段、对象数量少
- SoA适合: 批量处理相同字段、SIMD优化、大量对象
- 混合AoSoA: 将热数据SoA化，冷数据保持AoS
```

**Cache Line与False Sharing**：

```cpp
// ==========================================
// False Sharing: 多线程性能杀手
// ==========================================
#include <thread>
#include <atomic>
#include <vector>
#include <benchmark/benchmark.h>

// ===== 问题代码: False Sharing =====
struct CountersBad {
    std::atomic<int64_t> counter1;  // 和counter2在同一个cache line
    std::atomic<int64_t> counter2;  // 两个线程分别写，导致cache line反复失效
};

// ===== 修复方案1: Padding =====
struct CountersGood {
    alignas(64) std::atomic<int64_t> counter1;  // 独占一个cache line
    alignas(64) std::atomic<int64_t> counter2;  // 独占另一个cache line
};

// ===== 修复方案2: C++17 hardware_destructive_interference_size =====
#ifdef __cpp_lib_hardware_interference_size
    using std::hardware_destructive_interference_size;
#else
    constexpr size_t hardware_destructive_interference_size = 64;
#endif

struct CountersBetter {
    alignas(hardware_destructive_interference_size)
        std::atomic<int64_t> counter1;
    alignas(hardware_destructive_interference_size)
        std::atomic<int64_t> counter2;
};

// Benchmark: False Sharing
static void BM_FalseSharing(benchmark::State& state) {
    CountersBad counters{};

    for (auto _ : state) {
        std::thread t1([&]() {
            for (int i = 0; i < 1000000; ++i)
                counters.counter1.fetch_add(1, std::memory_order_relaxed);
        });
        std::thread t2([&]() {
            for (int i = 0; i < 1000000; ++i)
                counters.counter2.fetch_add(1, std::memory_order_relaxed);
        });
        t1.join(); t2.join();
    }
}
BENCHMARK(BM_FalseSharing);

// Benchmark: Fixed (No False Sharing)
static void BM_NoFalseSharing(benchmark::State& state) {
    CountersGood counters{};

    for (auto _ : state) {
        std::thread t1([&]() {
            for (int i = 0; i < 1000000; ++i)
                counters.counter1.fetch_add(1, std::memory_order_relaxed);
        });
        std::thread t2([&]() {
            for (int i = 0; i < 1000000; ++i)
                counters.counter2.fetch_add(1, std::memory_order_relaxed);
        });
        t1.join(); t2.join();
    }
}
BENCHMARK(BM_NoFalseSharing);
```

```
False Sharing 原理图

两个线程各自修改不同变量，但变量在同一个Cache Line中：

     CPU Core 0                    CPU Core 1
    ┌──────────┐                  ┌──────────┐
    │ Thread 1 │                  │ Thread 2 │
    │ 写counter1│                  │ 写counter2│
    └────┬─────┘                  └────┬─────┘
         │                              │
    ┌────┴────┐                   ┌────┴────┐
    │ L1 Cache│                   │ L1 Cache│
    │┌────────────────────┐│      │┌────────────────────┐│
    ││counter1│counter2│  ││      ││counter1│counter2│  ││
    │└────────────────────┘│      │└────────────────────┘│
    │  同一个Cache Line    │      │  同一个Cache Line    │
    └─────────┘                   └─────────┘
         │                              │
         └──────────┬───────────────────┘
                    │
              MESI协议通信
              反复 Invalidate
              导致cache line
              在两个核心间"乒乓"

修复后：
     CPU Core 0                    CPU Core 1
    ┌──────────┐                  ┌──────────┐
    │ Thread 1 │                  │ Thread 2 │
    └────┬─────┘                  └────┬─────┘
    ┌────┴────┐                   ┌────┴────┐
    │ L1 Cache│                   │ L1 Cache│
    │┌──────────────┐│            │┌──────────────┐│
    ││counter1│pad  ││            ││counter2│pad  ││
    │└──────────────┘│            │└──────────────┘│
    │  Cache Line A  │            │  Cache Line B  │
    └─────────┘                   └─────────┘
         独立的Cache Line，互不干扰

检测工具: perf c2c
$ perf c2c record -g ./myapp
$ perf c2c report
# 显示跨核心缓存传输（cache-to-cache transfers）
```

**CI性能回归检测**：

```yaml
# .github/workflows/benchmark.yml
# CI性能回归检测工作流

name: Performance Regression Check

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  benchmark:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4

    - name: Install dependencies
      run: |
        sudo apt-get update
        sudo apt-get install -y cmake g++ libbenchmark-dev

    - name: Build benchmarks
      run: |
        cmake -B build -DCMAKE_BUILD_TYPE=Release
        cmake --build build --target benchmarks

    - name: Run benchmarks
      run: |
        ./build/benchmarks \
          --benchmark_format=json \
          --benchmark_out=current_results.json \
          --benchmark_repetitions=5 \
          --benchmark_report_aggregates_only=true

    - name: Download baseline
      if: github.event_name == 'pull_request'
      uses: actions/download-artifact@v4
      with:
        name: benchmark-baseline
        path: baseline/
      continue-on-error: true  # 首次运行无基准线

    - name: Compare with baseline
      if: github.event_name == 'pull_request'
      run: |
        if [ -f baseline/baseline_results.json ]; then
          python3 scripts/compare_benchmarks.py \
            baseline/baseline_results.json \
            current_results.json \
            --threshold 10 \
            --output comparison_report.md
        else
          echo "No baseline found, skipping comparison"
        fi

    - name: Comment PR with results
      if: github.event_name == 'pull_request' && hashFiles('comparison_report.md') != ''
      uses: actions/github-script@v7
      with:
        script: |
          const fs = require('fs');
          const report = fs.readFileSync('comparison_report.md', 'utf8');
          github.rest.issues.createComment({
            issue_number: context.issue.number,
            owner: context.repo.owner,
            repo: context.repo.repo,
            body: report
          });

    - name: Upload baseline (main branch only)
      if: github.ref == 'refs/heads/main'
      uses: actions/upload-artifact@v4
      with:
        name: benchmark-baseline
        path: current_results.json
        overwrite: true
```

```python
#!/usr/bin/env python3
# scripts/compare_benchmarks.py
# 性能回归检测脚本

import json
import sys
import argparse

def load_benchmarks(filepath):
    """加载benchmark JSON结果"""
    with open(filepath) as f:
        data = json.load(f)
    results = {}
    for bm in data.get("benchmarks", []):
        name = bm["name"]
        if bm.get("aggregate_name") == "mean":
            results[name.replace("_mean", "")] = {
                "cpu_time": bm["cpu_time"],
                "real_time": bm["real_time"],
            }
    return results

def compare(baseline, current, threshold_pct):
    """对比基准线和当前结果"""
    regressions = []
    improvements = []
    unchanged = []

    for name, base_val in baseline.items():
        if name not in current:
            continue
        curr_val = current[name]
        change_pct = (curr_val["cpu_time"] - base_val["cpu_time"]) \
                     / base_val["cpu_time"] * 100

        entry = {
            "name": name,
            "baseline": base_val["cpu_time"],
            "current": curr_val["cpu_time"],
            "change_pct": change_pct,
        }

        if change_pct > threshold_pct:
            regressions.append(entry)
        elif change_pct < -threshold_pct:
            improvements.append(entry)
        else:
            unchanged.append(entry)

    return regressions, improvements, unchanged

def generate_report(regressions, improvements, unchanged, threshold):
    """生成Markdown报告"""
    lines = ["## Performance Benchmark Report\n"]

    if regressions:
        lines.append(f"### ⚠️ Regressions (>{threshold}%)\n")
        lines.append("| Benchmark | Baseline | Current | Change |")
        lines.append("|-----------|----------|---------|--------|")
        for r in sorted(regressions, key=lambda x: -x["change_pct"]):
            lines.append(f"| {r['name']} | {r['baseline']:.2f}ns "
                        f"| {r['current']:.2f}ns "
                        f"| +{r['change_pct']:.1f}% 🔴 |")
        lines.append("")

    if improvements:
        lines.append(f"### ✅ Improvements (>{threshold}%)\n")
        lines.append("| Benchmark | Baseline | Current | Change |")
        lines.append("|-----------|----------|---------|--------|")
        for r in sorted(improvements, key=lambda x: x["change_pct"]):
            lines.append(f"| {r['name']} | {r['baseline']:.2f}ns "
                        f"| {r['current']:.2f}ns "
                        f"| {r['change_pct']:.1f}% 🟢 |")
        lines.append("")

    lines.append(f"*{len(unchanged)} benchmarks unchanged "
                f"(within ±{threshold}%)*\n")

    return "\n".join(lines)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("baseline", help="Baseline JSON file")
    parser.add_argument("current", help="Current JSON file")
    parser.add_argument("--threshold", type=float, default=10.0)
    parser.add_argument("--output", default="comparison_report.md")
    args = parser.parse_args()

    baseline = load_benchmarks(args.baseline)
    current = load_benchmarks(args.current)
    reg, imp, unc = compare(baseline, current, args.threshold)
    report = generate_report(reg, imp, unc, args.threshold)

    with open(args.output, "w") as f:
        f.write(report)

    # 有回归时退出码非零
    if reg:
        print(f"⚠️ Found {len(reg)} performance regressions!")
        sys.exit(1)
    print("✅ No performance regressions detected.")
```

**Week 4 输出物清单**：

| 序号 | 输出物 | 说明 | 检验 |
|------|--------|------|------|
| 1 | 矩阵乘法5级优化代码 | naive→reordered→blocked→flat→SIMD | ✅ |
| 2 | 5级性能对比benchmark报告 | 每级加速比、cache-miss变化 | ✅ |
| 3 | AoS vs SoA对比代码 | Particle示例、缓存利用率分析 | ✅ |
| 4 | False Sharing示例与修复 | alignas(64)修复、perf c2c检测 | ✅ |
| 5 | compare_benchmarks.py | CI性能回归检测脚本 | ✅ |
| 6 | CI benchmark workflow | GitHub Actions完整YAML | ✅ |
| 7 | 性能优化方法论总结 | MIVO循环图+关键原则 | ✅ |
| 8 | 月度总结报告 | 4周知识整合文档 | ✅ |

**Week 4 检验标准**：

- [ ] 能解释矩阵乘法5级优化的原理（循环重排→分块→连续内存→SIMD）
- [ ] 能用perf stat/Cachegrind验证每级优化的缓存行为改善
- [ ] 能解释AoS vs SoA的缓存利用率差异，并给出适用场景建议
- [ ] 能识别false sharing问题，使用alignas(64)或padding修复
- [ ] 能使用perf c2c检测跨核心缓存传输（cache-to-cache transfers）
- [ ] 能编写CI性能回归检测脚本（JSON对比+阈值告警）
- [ ] 能设计GitHub Actions性能回归工作流（基准线管理+PR评论）
- [ ] 能画出性能优化MIVO循环图并解释每步的工具选择
- [ ] 理解hardware_destructive_interference_size的含义和用途
- [ ] 能综合运用本月所有工具（perf/Valgrind/Benchmark）完成一个完整的优化案例

---

## 源码阅读任务

```
源码阅读路线图

Google Benchmark          Linux perf工具           perf_events内核        Eigen GEMM
    │                         │                        │                    │
    ▼                         ▼                        ▼                    ▼
benchmark/                tools/perf/             kernel/events/         Eigen/src/Core/
├── src/                  ├── builtin-stat.c      ├── core.c             products/
│   ├── benchmark.cc      ├── builtin-record.c    ├── ring_buffer.c     ├── GeneralBlockPanelKernel.h
│   │   时间测量核心      │   采样实现            │   环形缓冲区        │   分块矩阵乘法核心
│   ├── cycleclock.h      ├── builtin-report.c    ├── hw_breakpoint.c   ├── GeneralMatrixMatrix.h
│   │   高精度时钟        │   报告生成            │                      │   GEMM调度
│   ├── statistics.cc     ├── util/               └── perf_event.h      └── arch/
│   │   统计分析          │   evsel.c                  内核头文件            SSE/AVX内核
│   └── complexity.cc     │   evlist.c
│       复杂度拟合        │   parse-events.c
└── include/              └── Documentation/
    benchmark.h               perf-stat.txt
    公共API                    使用文档
```

### 本月源码阅读

1. **Google Benchmark源码**（Week 3，~10h）
   - 仓库：https://github.com/google/benchmark
   - 阅读路线：
     1. `include/benchmark/benchmark.h` — 公共API和State类定义
     2. `src/cycleclock.h` — 高精度时钟获取（rdtsc/clock_gettime）
     3. `src/benchmark.cc` — 核心测量循环（自动迭代次数调整算法）
     4. `src/statistics.cc` — mean/median/stddev计算
     5. `src/complexity.cc` — BigO复杂度自动拟合（最小二乘法）
   - 学习目标：理解如何科学地测量纳秒级时间、迭代次数自动调整策略

2. **Linux perf用户态工具源码**（Week 1，~5h）
   - 路径：linux/tools/perf/
   - 阅读路线：
     1. `builtin-stat.c` — perf stat的实现逻辑
     2. `builtin-record.c` — perf record的采样实现
     3. `util/evsel.c` — 事件选择和perf_event_open封装
     4. `util/parse-events.c` — 事件名解析（如何将"cycles"映射到PMU配置）
   - 学习目标：理解perf命令如何与内核perf_events子系统交互

3. **Linux perf_events内核子系统**（Week 1，~5h）
   - 路径：linux/kernel/events/
   - 阅读路线：
     1. `include/uapi/linux/perf_event.h` — 用户态API定义（perf_event_attr结构体）
     2. `kernel/events/core.c` — perf_event_open系统调用实现
     3. `kernel/events/ring_buffer.c` — 用户态/内核态共享的环形缓冲区
   - 学习目标：理解硬件PMU计数器到用户态数据的完整路径

4. **Eigen矩阵乘法GEMM内核**（Week 4，~5h）
   - 仓库：https://gitlab.com/libeigen/eigen
   - 阅读路线：
     1. `Eigen/src/Core/products/GeneralMatrixMatrix.h` — GEMM高层调度
     2. `Eigen/src/Core/products/GeneralBlockPanelKernel.h` — 分块乘法核心（最重要）
     3. `Eigen/src/Core/arch/SSE/PacketMath.h` — SSE SIMD intrinsics封装
     4. `Eigen/src/Core/arch/AVX/PacketMath.h` — AVX SIMD intrinsics封装
   - 学习目标：理解工业级GEMM如何实现分块+SIMD+向量化优化

---

## 实践项目

### 项目：性能分析报告生成器

创建一个自动化的性能分析工具。

**项目结构**：

```
perf-analyzer/
├── CMakeLists.txt
├── include/
│   └── perfanalyzer/
│       ├── profiler.hpp
│       ├── reporter.hpp
│       └── metrics.hpp
├── src/
│   ├── profiler.cpp
│   └── reporter.cpp
├── tools/
│   └── analyze.cpp
└── scripts/
    └── generate_report.py
```

**include/perfanalyzer/profiler.hpp**：

```cpp
#pragma once

#include <string>
#include <vector>
#include <chrono>
#include <functional>
#include <map>
#include <memory>

namespace perfanalyzer {

/**
 * @brief 性能指标
 */
struct Metrics {
    double cpu_time_seconds = 0;
    double wall_time_seconds = 0;
    uint64_t cycles = 0;
    uint64_t instructions = 0;
    uint64_t cache_references = 0;
    uint64_t cache_misses = 0;
    uint64_t branch_instructions = 0;
    uint64_t branch_misses = 0;
    size_t peak_memory_bytes = 0;

    double ipc() const {
        return cycles > 0 ? static_cast<double>(instructions) / cycles : 0;
    }

    double cache_miss_rate() const {
        return cache_references > 0
            ? static_cast<double>(cache_misses) / cache_references * 100
            : 0;
    }

    double branch_miss_rate() const {
        return branch_instructions > 0
            ? static_cast<double>(branch_misses) / branch_instructions * 100
            : 0;
    }
};

/**
 * @brief RAII计时器
 */
class ScopedTimer {
public:
    explicit ScopedTimer(double& result);
    ~ScopedTimer();

private:
    double& result_;
    std::chrono::high_resolution_clock::time_point start_;
};

/**
 * @brief 性能分析器
 */
class Profiler {
public:
    Profiler();
    ~Profiler();

    // 禁用拷贝
    Profiler(const Profiler&) = delete;
    Profiler& operator=(const Profiler&) = delete;

    /**
     * @brief 开始采样
     */
    void start();

    /**
     * @brief 停止采样
     */
    void stop();

    /**
     * @brief 获取指标
     */
    Metrics getMetrics() const;

    /**
     * @brief 测量函数执行时间
     */
    template<typename Func>
    Metrics measure(Func&& func, int iterations = 1) {
        start();
        for (int i = 0; i < iterations; ++i) {
            func();
        }
        stop();
        return getMetrics();
    }

    /**
     * @brief 检查是否支持硬件性能计数器
     */
    static bool isHardwareCountersAvailable();

private:
    class Impl;
    std::unique_ptr<Impl> impl_;
};

/**
 * @brief 内存追踪器
 */
class MemoryTracker {
public:
    static size_t getCurrentUsage();
    static size_t getPeakUsage();
    static void resetPeak();
};

/**
 * @brief 性能分析会话
 */
class ProfilingSession {
public:
    struct Result {
        std::string name;
        Metrics metrics;
        std::vector<std::pair<std::string, double>> custom_metrics;
    };

    void addResult(const std::string& name, const Metrics& metrics);

    void addCustomMetric(
        const std::string& result_name,
        const std::string& metric_name,
        double value
    );

    const std::vector<Result>& getResults() const { return results_; }

    void clear() { results_.clear(); }

private:
    std::vector<Result> results_;
};

} // namespace perfanalyzer
```

**src/profiler.cpp**：

```cpp
#include "perfanalyzer/profiler.hpp"

#include <sys/resource.h>
#include <unistd.h>

#ifdef __linux__
#include <linux/perf_event.h>
#include <sys/ioctl.h>
#include <sys/syscall.h>
#endif

namespace perfanalyzer {

// ScopedTimer实现
ScopedTimer::ScopedTimer(double& result)
    : result_(result)
    , start_(std::chrono::high_resolution_clock::now())
{}

ScopedTimer::~ScopedTimer() {
    auto end = std::chrono::high_resolution_clock::now();
    result_ = std::chrono::duration<double>(end - start_).count();
}

// Profiler实现
class Profiler::Impl {
public:
    Impl() {
#ifdef __linux__
        initPerfEvents();
#endif
    }

    ~Impl() {
#ifdef __linux__
        closePerfEvents();
#endif
    }

    void start() {
        start_time_ = std::chrono::high_resolution_clock::now();
        start_cpu_time_ = getCpuTime();

#ifdef __linux__
        resetPerfCounters();
        enablePerfCounters();
#endif
    }

    void stop() {
#ifdef __linux__
        disablePerfCounters();
        readPerfCounters();
#endif

        end_time_ = std::chrono::high_resolution_clock::now();
        end_cpu_time_ = getCpuTime();
    }

    Metrics getMetrics() const {
        Metrics m;
        m.wall_time_seconds = std::chrono::duration<double>(
            end_time_ - start_time_).count();
        m.cpu_time_seconds = end_cpu_time_ - start_cpu_time_;

#ifdef __linux__
        m.cycles = counters_.cycles;
        m.instructions = counters_.instructions;
        m.cache_references = counters_.cache_references;
        m.cache_misses = counters_.cache_misses;
        m.branch_instructions = counters_.branch_instructions;
        m.branch_misses = counters_.branch_misses;
#endif

        return m;
    }

private:
    double getCpuTime() {
        struct rusage usage;
        getrusage(RUSAGE_SELF, &usage);
        return usage.ru_utime.tv_sec + usage.ru_utime.tv_usec / 1e6
             + usage.ru_stime.tv_sec + usage.ru_stime.tv_usec / 1e6;
    }

#ifdef __linux__
    struct PerfCounters {
        uint64_t cycles = 0;
        uint64_t instructions = 0;
        uint64_t cache_references = 0;
        uint64_t cache_misses = 0;
        uint64_t branch_instructions = 0;
        uint64_t branch_misses = 0;
    };

    void initPerfEvents() {
        // 初始化perf事件
        fd_cycles_ = openPerfEvent(PERF_TYPE_HARDWARE, PERF_COUNT_HW_CPU_CYCLES);
        fd_instructions_ = openPerfEvent(PERF_TYPE_HARDWARE, PERF_COUNT_HW_INSTRUCTIONS);
        fd_cache_refs_ = openPerfEvent(PERF_TYPE_HARDWARE, PERF_COUNT_HW_CACHE_REFERENCES);
        fd_cache_misses_ = openPerfEvent(PERF_TYPE_HARDWARE, PERF_COUNT_HW_CACHE_MISSES);
        fd_branches_ = openPerfEvent(PERF_TYPE_HARDWARE, PERF_COUNT_HW_BRANCH_INSTRUCTIONS);
        fd_branch_misses_ = openPerfEvent(PERF_TYPE_HARDWARE, PERF_COUNT_HW_BRANCH_MISSES);
    }

    int openPerfEvent(uint32_t type, uint64_t config) {
        struct perf_event_attr pe = {};
        pe.type = type;
        pe.size = sizeof(pe);
        pe.config = config;
        pe.disabled = 1;
        pe.exclude_kernel = 1;
        pe.exclude_hv = 1;

        return syscall(__NR_perf_event_open, &pe, 0, -1, -1, 0);
    }

    void closePerfEvents() {
        if (fd_cycles_ >= 0) close(fd_cycles_);
        if (fd_instructions_ >= 0) close(fd_instructions_);
        if (fd_cache_refs_ >= 0) close(fd_cache_refs_);
        if (fd_cache_misses_ >= 0) close(fd_cache_misses_);
        if (fd_branches_ >= 0) close(fd_branches_);
        if (fd_branch_misses_ >= 0) close(fd_branch_misses_);
    }

    void resetPerfCounters() {
        if (fd_cycles_ >= 0) ioctl(fd_cycles_, PERF_EVENT_IOC_RESET, 0);
        if (fd_instructions_ >= 0) ioctl(fd_instructions_, PERF_EVENT_IOC_RESET, 0);
        if (fd_cache_refs_ >= 0) ioctl(fd_cache_refs_, PERF_EVENT_IOC_RESET, 0);
        if (fd_cache_misses_ >= 0) ioctl(fd_cache_misses_, PERF_EVENT_IOC_RESET, 0);
        if (fd_branches_ >= 0) ioctl(fd_branches_, PERF_EVENT_IOC_RESET, 0);
        if (fd_branch_misses_ >= 0) ioctl(fd_branch_misses_, PERF_EVENT_IOC_RESET, 0);
    }

    void enablePerfCounters() {
        if (fd_cycles_ >= 0) ioctl(fd_cycles_, PERF_EVENT_IOC_ENABLE, 0);
        if (fd_instructions_ >= 0) ioctl(fd_instructions_, PERF_EVENT_IOC_ENABLE, 0);
        if (fd_cache_refs_ >= 0) ioctl(fd_cache_refs_, PERF_EVENT_IOC_ENABLE, 0);
        if (fd_cache_misses_ >= 0) ioctl(fd_cache_misses_, PERF_EVENT_IOC_ENABLE, 0);
        if (fd_branches_ >= 0) ioctl(fd_branches_, PERF_EVENT_IOC_ENABLE, 0);
        if (fd_branch_misses_ >= 0) ioctl(fd_branch_misses_, PERF_EVENT_IOC_ENABLE, 0);
    }

    void disablePerfCounters() {
        if (fd_cycles_ >= 0) ioctl(fd_cycles_, PERF_EVENT_IOC_DISABLE, 0);
        if (fd_instructions_ >= 0) ioctl(fd_instructions_, PERF_EVENT_IOC_DISABLE, 0);
        if (fd_cache_refs_ >= 0) ioctl(fd_cache_refs_, PERF_EVENT_IOC_DISABLE, 0);
        if (fd_cache_misses_ >= 0) ioctl(fd_cache_misses_, PERF_EVENT_IOC_DISABLE, 0);
        if (fd_branches_ >= 0) ioctl(fd_branches_, PERF_EVENT_IOC_DISABLE, 0);
        if (fd_branch_misses_ >= 0) ioctl(fd_branch_misses_, PERF_EVENT_IOC_DISABLE, 0);
    }

    void readPerfCounters() {
        if (fd_cycles_ >= 0) read(fd_cycles_, &counters_.cycles, sizeof(uint64_t));
        if (fd_instructions_ >= 0) read(fd_instructions_, &counters_.instructions, sizeof(uint64_t));
        if (fd_cache_refs_ >= 0) read(fd_cache_refs_, &counters_.cache_references, sizeof(uint64_t));
        if (fd_cache_misses_ >= 0) read(fd_cache_misses_, &counters_.cache_misses, sizeof(uint64_t));
        if (fd_branches_ >= 0) read(fd_branches_, &counters_.branch_instructions, sizeof(uint64_t));
        if (fd_branch_misses_ >= 0) read(fd_branch_misses_, &counters_.branch_misses, sizeof(uint64_t));
    }

    int fd_cycles_ = -1;
    int fd_instructions_ = -1;
    int fd_cache_refs_ = -1;
    int fd_cache_misses_ = -1;
    int fd_branches_ = -1;
    int fd_branch_misses_ = -1;
    PerfCounters counters_;
#endif

    std::chrono::high_resolution_clock::time_point start_time_;
    std::chrono::high_resolution_clock::time_point end_time_;
    double start_cpu_time_ = 0;
    double end_cpu_time_ = 0;
};

Profiler::Profiler() : impl_(std::make_unique<Impl>()) {}
Profiler::~Profiler() = default;

void Profiler::start() { impl_->start(); }
void Profiler::stop() { impl_->stop(); }
Metrics Profiler::getMetrics() const { return impl_->getMetrics(); }

bool Profiler::isHardwareCountersAvailable() {
#ifdef __linux__
    struct perf_event_attr pe = {};
    pe.type = PERF_TYPE_HARDWARE;
    pe.size = sizeof(pe);
    pe.config = PERF_COUNT_HW_CPU_CYCLES;
    pe.disabled = 1;

    int fd = syscall(__NR_perf_event_open, &pe, 0, -1, -1, 0);
    if (fd >= 0) {
        close(fd);
        return true;
    }
#endif
    return false;
}

// MemoryTracker实现
size_t MemoryTracker::getCurrentUsage() {
    struct rusage usage;
    getrusage(RUSAGE_SELF, &usage);
    return usage.ru_maxrss * 1024;  // KB to bytes
}

size_t MemoryTracker::getPeakUsage() {
    return getCurrentUsage();  // 简化实现
}

void MemoryTracker::resetPeak() {
    // 无法重置系统跟踪的峰值
}

} // namespace perfanalyzer
```

---

## 月度验收标准

### 知识验收（10项）

- [ ] 能画出perf三层架构图（Hardware PMU → Kernel perf_events → Userspace tools）
- [ ] 能解释PMU计数器采样原理（计数器溢出→NMI→记录IP+调用链→Ring Buffer）
- [ ] 能画出CPU缓存层次图及各级延迟（L1 ~1ns → L2 ~3-10ns → L3 ~10-40ns → DRAM ~50-100ns）
- [ ] 能画出Valgrind DBI架构图（Guest Code → VEX IR → Instrumented Code → Tool Plugin）
- [ ] 能区分Callgrind的self cost和inclusive cost，解释其优化指导意义
- [ ] 能解释DoNotOptimize和ClobberMemory的内联汇编语义和使用时机
- [ ] 能列举微基准测试7大陷阱并说明每个的解决方案
- [ ] 能解释AoS vs SoA的缓存利用率差异及各自适用场景
- [ ] 能解释false sharing的原因（同cache line被不同核心写入）和修复方案（alignas/padding）
- [ ] 能描述性能优化MIVO方法论（Measure→Identify→Optimize→Verify）的每步工具选择

### 实践验收（10项）

- [ ] 能使用perf stat分析程序并正确解读IPC、cache-miss率、branch-miss率
- [ ] 能使用perf record+FlameGraph生成CPU火焰图和差分火焰图
- [ ] 能使用Callgrind分析程序热点并通过KCachegrind可视化
- [ ] 能使用Cachegrind分析缓存行为并定位cache-unfriendly代码
- [ ] 能使用Massif/heaptrack分析堆内存使用峰值和分配来源
- [ ] 能编写规范的Google Benchmark（参数化/Fixture/Complexity/Custom Counters）
- [ ] 能实现矩阵乘法5级优化并用benchmark验证加速比
- [ ] 能编写AoS vs SoA对比代码并用perf验证缓存行为差异
- [ ] 能检测并修复false sharing问题，用perf c2c验证修复效果
- [ ] 能搭建CI性能回归检测流程（JSON对比+阈值告警+PR评论）

---

## 知识地图

```
Month 45: 性能分析与Profiling 知识全景

                        ┌──────────────────────┐
                        │  性能分析与Profiling   │
                        │  找出程序的性能瓶颈    │
                        └──────────┬───────────┘
               ┌───────────────┬───┴───┬──────────────┐
               ▼               ▼       ▼              ▼
    ┌──────────────┐  ┌────────────┐ ┌──────────┐ ┌──────────────┐
    │ CPU Profiling│  │内存/缓存   │ │微基准测试│ │性能优化实践  │
    │ (Week 1)     │  │分析(Week 2)│ │(Week 3)  │ │(Week 4)      │
    └──────┬───────┘  └─────┬──────┘ └────┬─────┘ └──────┬───────┘
           │                │              │              │
    ┌──────┴──────┐  ┌─────┴─────┐  ┌────┴────┐  ┌─────┴──────┐
    │perf工具链   │  │Valgrind   │  │Google   │  │矩阵乘法    │
    │ stat/record │  │ Memcheck  │  │Benchmark│  │5级优化     │
    │ report/top  │  │ Callgrind │  │ State   │  │ naive→SIMD │
    │PMU/采样/NMI │  │ Cachegrind│  │ Range   │  │            │
    │             │  │ Massif    │  │ Fixture │  │AoS vs SoA  │
    │火焰图       │  │ DHAT      │  │ Counter │  │Cache Line  │
    │ CPU/差分    │  │ Helgrind  │  │ Thread  │  │False Sharing│
    │ off-CPU     │  │           │  │ Template│  │             │
    │             │  │heaptrack  │  │         │  │CI性能回归   │
    │gprof对比    │  │ 现代替代  │  │7大陷阱  │  │compare.py  │
    └──────┬──────┘  └─────┬─────┘  └────┬────┘  └─────┬──────┘
           │                │              │              │
           └────────┬───────┴──────┬───────┘              │
                    ▼              ▼                       │
             ┌───────────┐  ┌──────────┐                  │
             │工具选择    │  │DoNot-    │                  │
             │决策树      │  │Optimize  │                  │
             │生产→perf   │  │Clobber-  │                  │
             │精确→callgr │  │Memory    │                  │
             └───────────┘  └──────────┘                  │
                                                           │
                    ┌──────────────────────────────────────┘
                    ▼
             ┌──────────────┐
             │性能优化方法论│
             │MIVO循环      │
             │Measure→Ident-│
             │ify→Optimize  │
             │→Verify       │
             └──────────────┘

关联知识：
┌─────────────────────────────────────────────────────────────────┐
│ Month 44 (Sanitizers)    → 运行时检测 → 正确性保障              │
│ Month 45 (Profiling)     → 性能分析   → 性能保障               │
│ Month 46 (日志系统)      → 运行时观测 → 可观测性保障            │
│                                                                  │
│ 三者构成程序质量保障的三个维度：正确性 + 性能 + 可观测性         │
└─────────────────────────────────────────────────────────────────┘
```

---

## 完整输出物清单

| 序号 | 输出物 | 所属周 | 类型 | 说明 |
|------|--------|--------|------|------|
| 1 | perf环境配置文档 | Week 1 | 文档 | 安装步骤、权限配置 |
| 2 | perf stat指标解读笔记 | Week 1 | 文档 | 6类事件、IPC/CPI |
| 3 | 采样分析实验代码 | Week 1 | 代码 | 热点函数测试程序 |
| 4 | perf report分析报告 | Week 1 | 文档 | 热点定位、调用链分析 |
| 5 | 火焰图生成脚本 | Week 1 | 脚本 | CPU/差分火焰图自动化 |
| 6 | gprof对比实验 | Week 1 | 代码 | 三种工具同一程序对比 |
| 7 | 工具选择指南 | Week 1 | 文档 | 场景化决策树 |
| 8 | Valgrind架构笔记 | Week 2 | 文档 | DBI原理、VEX IR |
| 9 | Memcheck原理文档 | Week 2 | 文档 | Shadow Memory原理 |
| 10 | Callgrind分析报告 | Week 2 | 文档 | self/inclusive cost |
| 11 | KCachegrind使用指南 | Week 2 | 文档 | 可视化操作流程 |
| 12 | Cachegrind缓存分析报告 | Week 2 | 文档 | 缓存命中率分析 |
| 13 | Massif堆分析报告 | Week 2 | 文档 | 峰值快照解读 |
| 14 | 堆分析工具对比文档 | Week 2 | 文档 | heaptrack vs Massif |
| 15 | Benchmark项目模板 | Week 3 | 代码 | CMake集成模板 |
| 16 | 参数化benchmark代码 | Week 3 | 代码 | Range/Complexity |
| 17 | 高级功能示例代码 | Week 3 | 代码 | Fixture/Counter/Template |
| 18 | 多线程benchmark代码 | Week 3 | 代码 | Threads/ThreadRange |
| 19 | 陷阱演示代码 | Week 3 | 代码 | 7大陷阱正反对比 |
| 20 | 陷阱避免清单 | Week 3 | 文档 | 最佳实践指南 |
| 21 | CI benchmark workflow | Week 3 | YAML | JSON+compare.py |
| 22 | 矩阵乘法5级优化代码 | Week 4 | 代码 | naive→SIMD |
| 23 | 5级性能对比报告 | Week 4 | 文档 | 加速比+cache-miss |
| 24 | AoS vs SoA对比代码 | Week 4 | 代码 | Particle示例 |
| 25 | False Sharing示例+修复 | Week 4 | 代码 | alignas(64)+perf c2c |
| 26 | compare_benchmarks.py | Week 4 | 脚本 | CI性能回归检测 |
| 27 | CI benchmark YAML | Week 4 | YAML | GitHub Actions完整流程 |
| 28 | 性能优化方法论总结 | Week 4 | 文档 | MIVO循环+原则 |
| 29 | perf-analyzer实践项目 | 全月 | 代码 | profiler.hpp/cpp |
| 30 | 月度学习笔记 | 全月 | 文档 | notes/month45_profiling.md |

---

## 详细时间分配表

| 天数 | 日期标记 | 主题 | 理论 | 实践 | 源码 | 合计 |
|------|----------|------|------|------|------|------|
| **Week 1: Linux perf工具** | | | | | | **35h** |
| Day 1 | W1D1 | perf安装与基础 | 2h | 2h | 1h | 5h |
| Day 2 | W1D2 | perf stat深入 | 2h | 2h | 1h | 5h |
| Day 3 | W1D3 | perf record采样 | 1h | 3h | 1h | 5h |
| Day 4 | W1D4 | perf report分析 | 1h | 3h | 1h | 5h |
| Day 5 | W1D5 | 火焰图基础 | 1h | 3h | 1h | 5h |
| Day 6 | W1D6 | 高级火焰图 | 1h | 3h | 1h | 5h |
| Day 7 | W1D7 | gprof与工具对比 | 2h | 2h | 1h | 5h |
| **Week 2: Valgrind工具集** | | | | | | **35h** |
| Day 8 | W2D1 | Valgrind架构 | 3h | 1h | 1h | 5h |
| Day 9 | W2D2 | Memcheck深入 | 2h | 2h | 1h | 5h |
| Day 10 | W2D3 | Callgrind基础 | 1h | 3h | 1h | 5h |
| Day 11 | W2D4 | KCachegrind可视化 | 1h | 3h | 1h | 5h |
| Day 12 | W2D5 | Cachegrind缓存分析 | 1h | 3h | 1h | 5h |
| Day 13 | W2D6 | Massif堆分析 | 1h | 3h | 1h | 5h |
| Day 14 | W2D7 | DHAT+heaptrack | 1h | 3h | 1h | 5h |
| **Week 3: Google Benchmark** | | | | | | **35h** |
| Day 15 | W3D1 | 安装与基础 | 2h | 2h | 1h | 5h |
| Day 16 | W3D2 | 参数化测试 | 1h | 2h | 2h | 5h |
| Day 17 | W3D3 | 高级功能(一) | 1h | 2h | 2h | 5h |
| Day 18 | W3D4 | 高级功能(二) | 1h | 2h | 2h | 5h |
| Day 19 | W3D5 | 陷阱(一) | 1h | 3h | 1h | 5h |
| Day 20 | W3D6 | 陷阱(二) | 1h | 3h | 1h | 5h |
| Day 21 | W3D7 | CI集成 | 1h | 3h | 1h | 5h |
| **Week 4: 性能优化实践** | | | | | | **35h** |
| Day 22 | W4D1 | 矩阵乘法(一) | 1h | 3h | 1h | 5h |
| Day 23 | W4D2 | 矩阵乘法(二) | 1h | 3h | 1h | 5h |
| Day 24 | W4D3 | AoS vs SoA | 1h | 3h | 1h | 5h |
| Day 25 | W4D4 | Cache Line分析 | 1h | 3h | 1h | 5h |
| Day 26 | W4D5 | CI性能回归(一) | 1h | 3h | 1h | 5h |
| Day 27 | W4D6 | CI性能回归(二) | 1h | 3h | 1h | 5h |
| Day 28 | W4D7 | 综合总结 | 2h | 2h | 1h | 5h |
| **月度合计** | | | **37h** | **75h** | **28h** | **140h** |

---

## 下月预告

```
Month 45 → Month 46 衔接

Month 45 (性能分析)                    Month 46 (日志系统设计)
┌──────────────────────┐              ┌──────────────────────┐
│ perf/Valgrind/       │              │ 高性能日志框架       │
│ Benchmark            │──────────→   │ spdlog/glog          │
│                      │              │                      │
│ 性能优化方法论       │              │ 异步日志设计         │
│ Measure→Optimize     │──────────→   │ 无锁队列+后端线程   │
│                      │              │                      │
│ AoS/SoA/SIMD        │              │ 日志级别与过滤       │
│ 数据导向设计         │──────────→   │ 格式化性能优化       │
│                      │              │                      │
│ CI性能回归           │              │ 日志轮转与管理       │
│ benchmark自动化      │──────────→   │ 结构化日志+ELK集成   │
└──────────────────────┘              └──────────────────────┘

Month 46 预告:
- Week 1: 日志系统基础——级别/格式/输出目标
- Week 2: spdlog深入——异步模式/自定义Sink/格式化
- Week 3: 高性能日志设计——无锁队列/批量写入/零拷贝
- Week 4: 日志系统工程实践——轮转/压缩/聚合/告警

延续关系：Month 45的性能分析能力将直接用于评估日志系统的性能开销
```

```
C++ 程序质量保障链（更新至 Month 45）

代码编写 → 静态分析 → 构建测试 → 运行时检测 → 性能分析 → 日志观测
   │          │          │          │            │          │
   │     Month 43    Month 42   Month 44    Month 45   Month 46
   │     Clang-Tidy  GTest      ASan/TSan   perf       (即将)
   │     静态检查    单元测试   UBSan/MSan  Valgrind   spdlog
   │                            Sanitizers  Benchmark  日志系统
   │                                        优化实践
   │
   ▼
  代码
  质量                    质量保障维度：
  保障     ┌──────────────────────────────────────────────┐
  金字塔   │ 正确性: Sanitizers + 测试 (Month 42+44)      │
           │ 代码质量: 静态分析 (Month 43)                 │
           │ 性能: Profiling + Benchmark (Month 45)        │
           │ 可观测性: 日志 + 监控 (Month 46)              │
           │ 部署: Docker + CI/CD (Month 40+41)            │
           └──────────────────────────────────────────────┘
```
