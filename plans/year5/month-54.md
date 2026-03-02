# Month 54: SYCL与异构计算入门 (SYCL and Heterogeneous Computing Introduction)

## 本月主题概述

SYCL（发音"sickle"）是Khronos Group制定的跨平台异构计算标准，允许开发者使用纯C++编写在CPU、GPU、FPGA等多种设备上运行的代码。作为OpenCL的高层C++抽象，SYCL提供了现代C++17特性支持，同时保持了高性能。随着Intel oneAPI的大力推广、AMD ROCm的SYCL支持（通过AdaptiveCpp/hipSYCL）以及Codeplay对NVIDIA GPU后端的支持，SYCL 2020已经成为真正的跨厂商异构计算编程模型。在摩尔定律放缓、Dennard Scaling失效的后登纳德时代，异构计算从"可选的加速手段"变成了"获取更多算力的必经之路"。本月将从GPU微架构原理出发，系统学习SYCL编程模型、内存管理、并行执行模型和性能优化技术。

### 学习目标
- 理解异构计算的基本概念与CPU/GPU架构差异
- 掌握SYCL编程模型和核心API（Buffer/Accessor与USM）
- 理解设备内存层次和数据传输优化
- 学会编写、调试和优化SYCL内核
- 完成实用的SYCL加速应用并进行性能基准测试

**进阶目标**：
- 深入理解GPU微架构——SM/EU结构、warp/wavefront调度、寄存器压力、occupancy计算公式；能从硬件spec预测性能特征
- 精通SYCL两种内存管理范式（Buffer/Accessor vs USM），量化理解各自适用场景：accessor DAG调度开销 vs 显式控制；页迁移延迟 vs 编程便利性
- 能使用nd_range内核配合local memory实现复杂并行模式（scan、reduction、histogram、stencil），理解bank conflict及其规避策略
- 深入理解SYCL 2020特性——group算法、reduction、sub-group、specialization constants——及其在Intel/NVIDIA/AMD后端的硬件映射
- 掌握性能优化循环：使用vendor工具（Intel VTune、NVIDIA Nsight、AMD rocprof）profiling → 识别瓶颈（compute-bound vs memory-bound）→ 应用针对性优化（合并访问、tiling、occupancy调优）
- 能设计可移植的异构计算架构，实现跨设备类型的优雅降级，具备fallback策略和设备特化内核选择能力

---

## 理论学习内容

### 第一周：异构计算基础与SYCL入门（35小时）

**学习目标**：
- [ ] 深入理解CPU与GPU微架构差异：核心数量、时钟频率、缓存层次、内存带宽，以及这些差异如何导致根本不同的优化策略
- [ ] 掌握Flynn分类法（SISD/SIMD/MISD/MIMD），理解SIMT作为GPU特有扩展；量化warp大小与SIMD宽度的关系
- [ ] 理解Amdahl定律和Gustafson定律，能够为给定工作负载的并行比例计算加速比上限；识别每个定律的适用场景
- [ ] 追溯SYCL从OpenCL C++封装到SYCL 1.2.1再到SYCL 2020的演进；理解其与Khronos生态（OpenCL、SPIR-V、Vulkan Compute）的关系
- [ ] 掌握SYCL平台模型：platform、device、context、queue；能够枚举和选择设备，编写自定义selector
- [ ] 编写完整的SYCL程序，使用buffer/accessor模型实现正确的作用域同步
- [ ] 实现完善的错误处理：同步异常、异步异常处理器、设备特定错误码
- [ ] 对比SYCL、CUDA、OpenCL和HIP编程模型在可移植性、性能、表达力和生态成熟度方面的差异

**阅读材料**：
- [ ] 《Programming Massively Parallel Processors》- Kirk & Hwu, 4th Edition, Chapters 1-3（异构计算基础）
- [ ] SYCL 2020 Specification (Khronos), Sections 1-4（架构、编程模型、运行时）
- [ ] Intel oneAPI GPU Optimization Guide, Chapter 1-2（架构概述、执行模型）
- [ ] 《Data Parallel C++》- Reinders, Ashbaugh, Brodman (Apress, 2023), Chapters 1-4
- [ ] NVIDIA GPU Architecture Whitepaper (Ampere/Ada Lovelace): SM结构、内存层次
- [ ] Hennessy & Patterson《Computer Architecture: A Quantitative Approach》, Appendix C（GPU架构）
- [ ] CppCon 2022: "SYCL -- Introduction and Best Practices" by Gordon Brown (Codeplay)
- [ ] "A Comparison of Heterogeneous Programming Models: SYCL, CUDA, HIP, OpenCL" 对比研究论文

---

#### 核心概念

**异构计算全景图**

```
┌─────────────────────────────────────────────────────────────┐
│                      异构计算系统全景                         │
└─────────────────────────────────────────────────────────────┘

                    ┌─────────────────────┐
                    │     应用程序层       │
                    │  (SYCL C++ 单源码)  │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │     SYCL运行时      │
                    │  设备发现│任务调度   │
                    │  内存管理│依赖分析   │
                    └──────────┬──────────┘
                               │
              ┌────────────────┼────────────────┐
              │                │                │
    ┌─────────▼──────┐ ┌──────▼────────┐ ┌─────▼──────────┐
    │   SPIR-V/PTX   │ │  Level Zero   │ │    OpenCL      │
    │   中间表示层    │ │  (Intel)      │ │   后端         │
    └─────────┬──────┘ └──────┬────────┘ └─────┬──────────┘
              │                │                │
    ┌─────────▼──────┐ ┌──────▼────────┐ ┌─────▼──────────┐
    │   Host (CPU)   │ │   GPU         │ │   FPGA/DSP     │
    │   多核x86/ARM  │ │   NVIDIA/AMD  │ │   Xilinx/Intel │
    │   低延迟       │ │   /Intel      │ │   专用加速     │
    │   复杂控制流   │ │   高吞吐量    │ │   定制流水线   │
    └────────────────┘ └───────────────┘ └────────────────┘
              │                │                │
              └────────────────┴────────────────┘
                               │
                    ┌──────────▼──────────┐
                    │   PCIe 4.0/5.0      │
                    │   CXL 互连          │
                    │   共享虚拟内存      │
                    └─────────────────────┘

关键洞察（Jim Keller）：
"未来的每一代计算都将是异构的。我们需要把对的工作放在对的处理器上。"
```

#### 1.1 CPU与GPU微架构深入对比

CPU和GPU代表了两种截然不同的处理器设计哲学。理解这种差异是编写高性能异构程序的基础。

```
CPU核心内部结构（以Intel Golden Cove为例）：
┌─────────────────────────────────────────────────────────────┐
│                    CPU Core (单个)                           │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │  取指单元    │  │  分支预测    │  │  指令缓存 (32KB)   │ │
│  │  (宽度6)    │  │  TAGE/TAP   │  │  8-way associative │ │
│  └──────┬──────┘  └──────┬──────┘  └─────────────────────┘ │
│         ▼                ▼                                   │
│  ┌──────────────────────────────┐                           │
│  │  解码器 (6-wide decode)      │  ← 每周期6条x86指令      │
│  └──────────────┬───────────────┘                           │
│                 ▼                                            │
│  ┌──────────────────────────────┐                           │
│  │  分配/重命名 (RAT)           │  ← 寄存器重命名消除WAR    │
│  │  重排序缓冲区 (512 entries) │  ← 支持深度乱序执行       │
│  └──────────────┬───────────────┘                           │
│                 ▼                                            │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌─────┐              │
│  │ALU │ │ALU │ │ALU │ │FP  │ │FP  │ │ AGU │  ← 12+执行端口│
│  │    │ │    │ │    │ │MUL │ │ADD │ │     │              │
│  └────┘ └────┘ └────┘ └────┘ └────┘ └─────┘              │
│  ┌────────────────┐  ┌────────────────┐                     │
│  │ L1 Data Cache  │  │  Store Buffer  │                     │
│  │   48KB, 12cyc  │  │    72 entries  │                     │
│  └────────┬───────┘  └────────────────┘                     │
│           ▼                                                  │
│  ┌────────────────┐                                         │
│  │ L2 Cache 2MB   │  ← 每核心私有                           │
│  └────────┬───────┘                                         │
└───────────┼─────────────────────────────────────────────────┘
            ▼
  ┌────────────────────┐
  │ L3 Cache 36MB共享  │  ← 所有核心共享，环形总线互连
  └────────────────────┘


GPU SM内部结构（以NVIDIA Ada Lovelace SM为例）：
┌─────────────────────────────────────────────────────────────┐
│              Streaming Multiprocessor (SM)                    │
├─────────────────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────────┐          │
│  │  Instruction Cache                            │          │
│  └───────────────────────┬───────────────────────┘          │
│                          ▼                                   │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Warp Scheduler ×4 (每个调度器每周期发射1条指令)       │ │
│  │  每个调度器管理一组warp，交替发射隐藏延迟              │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  Partition 0          Partition 1                            │
│  ┌──────────────┐    ┌──────────────┐                       │
│  │ FP32 ×32     │    │ FP32 ×32     │  ← 128 FP32 cores   │
│  │ INT32 ×16    │    │ INT32 ×16    │    per SM            │
│  │ FP64 ×1      │    │ FP64 ×1     │                       │
│  │ Tensor ×1    │    │ Tensor ×1    │  ← 4th gen Tensor    │
│  │ LD/ST ×16    │    │ LD/ST ×16    │                       │
│  │ SFU ×4       │    │ SFU ×4       │                       │
│  └──────────────┘    └──────────────┘                       │
│  Partition 2          Partition 3                            │
│  ┌──────────────┐    ┌──────────────┐                       │
│  │ (同上)       │    │ (同上)       │                       │
│  └──────────────┘    └──────────────┘                       │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Register File: 65536 × 32bit = 256KB                  │ │
│  │  (所有线程共享，每线程最多255个寄存器)                  │ │
│  └────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Shared Memory / L1 Cache: 128KB (可配置分配比例)      │ │
│  │  延迟：~20-30 cycles | 带宽：~128 bytes/cycle          │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

**代表性硬件参数对比表**

```
┌──────────────────┬──────────────────────┬──────────────────────┐
│     参数          │  Intel i9-14900K     │  NVIDIA RTX 4090     │
│                  │  (CPU)               │  (GPU)               │
├──────────────────┼──────────────────────┼──────────────────────┤
│  核心数          │  24核 (8P+16E)       │  16384 CUDA cores    │
│                  │  32线程              │  (128 SM × 128)      │
├──────────────────┼──────────────────────┼──────────────────────┤
│  频率            │  5.8 GHz (boost)     │  2.52 GHz (boost)    │
├──────────────────┼──────────────────────┼──────────────────────┤
│  FP32 峰值       │  ~1.0 TFLOPS         │  82.6 TFLOPS         │
│  吞吐量          │  (AVX-512)           │  (83x CPU!)          │
├──────────────────┼──────────────────────┼──────────────────────┤
│  内存带宽        │  89.6 GB/s           │  1008 GB/s           │
│                  │  (DDR5-5600)         │  (GDDR6X, 11x CPU!)  │
├──────────────────┼──────────────────────┼──────────────────────┤
│  L1 Cache        │  48KB/core           │  128KB/SM (共享)     │
│  L2 Cache        │  2MB/core            │  72MB (全局)         │
│  L3 Cache        │  36MB (共享)         │  无                  │
├──────────────────┼──────────────────────┼──────────────────────┤
│  典型延迟        │  ~1ns (L1)           │  ~20ns (L1)          │
│  (Cache hit)     │  ~10ns (L3)          │  ~200ns (Global mem) │
├──────────────────┼──────────────────────┼──────────────────────┤
│  设计哲学        │  延迟优化            │  吞吐量优化          │
│                  │  少量复杂核心         │  大量简单核心        │
│                  │  深度乱序执行         │  SIMT大规模并行      │
│                  │  大缓存隐藏延迟       │  线程切换隐藏延迟    │
└──────────────────┴──────────────────────┴──────────────────────┘

核心洞察：
  CPU = "赛车" —— 单辆极快，适合赛道（串行复杂任务）
  GPU = "货车车队" —— 单辆较慢，但运力巨大（并行简单任务）
```

```cpp
// 设备信息探测程序 —— 你的第一个SYCL"Hello World"
// 这个程序不做任何计算，只是查询和展示硬件能力
// 理解硬件参数是优化的第一步

#include <sycl/sycl.hpp>
#include <iostream>
#include <iomanip>

void exploreDevice(const sycl::device& dev) {
    std::cout << "═══════════════════════════════════════════\n";
    std::cout << "Device: "
              << dev.get_info<sycl::info::device::name>() << "\n";
    std::cout << "Vendor: "
              << dev.get_info<sycl::info::device::vendor>() << "\n";

    // 计算能力
    auto maxCU = dev.get_info<sycl::info::device::max_compute_units>();
    auto maxFreq = dev.get_info<sycl::info::device::max_clock_frequency>();
    std::cout << "Compute Units: " << maxCU << "\n";
    std::cout << "Max Frequency: " << maxFreq << " MHz\n";

    // 内存信息 —— 这些参数决定了你的优化策略
    auto globalMem = dev.get_info<sycl::info::device::global_mem_size>();
    auto localMem = dev.get_info<sycl::info::device::local_mem_size>();
    std::cout << "Global Memory: " << globalMem / (1024*1024) << " MB\n";
    std::cout << "Local Memory:  " << localMem / 1024 << " KB\n";
    // local memory是优化的关键资源，每个work-group共享

    // 工作组信息 —— 决定了并行度的上限
    auto maxWGSize = dev.get_info<sycl::info::device::max_work_group_size>();
    std::cout << "Max Work-group Size: " << maxWGSize << "\n";

    // Sub-group信息 —— SIMT执行的基本单位
    auto sgSizes = dev.get_info<sycl::info::device::sub_group_sizes>();
    std::cout << "Sub-group Sizes: ";
    for (auto s : sgSizes) std::cout << s << " ";
    std::cout << "\n";

    // USM支持 —— 不是所有设备都支持所有USM类型
    std::cout << "USM Device Alloc: "
              << dev.has(sycl::aspect::usm_device_allocations) << "\n";
    std::cout << "USM Shared Alloc: "
              << dev.has(sycl::aspect::usm_shared_allocations) << "\n";
    std::cout << "FP64 Support:     "
              << dev.has(sycl::aspect::fp64) << "\n";
}

int main() {
    // 遍历所有平台和设备
    for (auto& platform : sycl::platform::get_platforms()) {
        std::cout << "\nPlatform: "
                  << platform.get_info<sycl::info::platform::name>() << "\n";
        for (auto& device : platform.get_devices()) {
            exploreDevice(device);
        }
    }
    return 0;
}
```

#### 1.2 并行计算范式：SIMD、SIMT与SPMD

```
┌─────────────────────────────────────────────────────────────┐
│                    Flynn分类法 (1966)                        │
├──────────────────┬──────────────────────────────────────────┤
│                  │     单数据流 (SD)    │   多数据流 (MD)    │
├──────────────────┼─────────────────────┼────────────────────┤
│  单指令流 (SI)   │      SISD           │      SIMD          │
│                  │  传统串行处理器      │  向量处理器/SSE    │
│                  │  一次一条指令        │  一条指令处理       │
│                  │  一个数据            │  多个数据           │
├──────────────────┼─────────────────────┼────────────────────┤
│  多指令流 (MI)   │      MISD           │      MIMD          │
│                  │  理论模型            │  多核CPU/GPU集群   │
│                  │  实际很少见          │  各核独立执行       │
└──────────────────┴─────────────────────┴────────────────────┘

GPU的SIMT模型（NVIDIA术语）：
┌─────────────────────────────────────────────────────────────┐
│  Warp (32个线程): 所有线程执行相同指令，但操作不同数据       │
│                                                              │
│  时钟周期 1:  ADD r1, r2, r3                                │
│  ┌─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┐        │
│  │ T0  │ T1  │ T2  │ T3  │ T4  │ T5  │ ... │ T31 │        │
│  │ ADD │ ADD │ ADD │ ADD │ ADD │ ADD │ ADD │ ADD │        │
│  │d[0] │d[1] │d[2] │d[3] │d[4] │d[5] │     │d[31]│        │
│  └─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┘        │
│                                                              │
│  分支分歧时的SIMT执行：                                      │
│  if (tid < 16) { A } else { B }                             │
│                                                              │
│  Phase 1: 执行A分支（T0-T15活跃，T16-T31等待）              │
│  ┌─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┐        │
│  │ T0  │ ... │ T15 │ T16 │ ... │ T31 │                     │
│  │ A✓  │ A✓  │ A✓  │ ██  │ ██  │ ██  │  ← 掩码禁用       │
│  └─────┴─────┴─────┴─────┴─────┴─────┘                     │
│                                                              │
│  Phase 2: 执行B分支（T16-T31活跃，T0-T15等待）              │
│  ┌─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┐        │
│  │ T0  │ ... │ T15 │ T16 │ ... │ T31 │                     │
│  │ ██  │ ██  │ ██  │ B✓  │ B✓  │ B✓  │  ← 掩码禁用       │
│  └─────┴─────┴─────┴─────┴─────┴─────┘                     │
│                                                              │
│  结果：两个分支串行执行，吞吐量减半！这就是"分支分歧"       │
│                                                              │
│  Warp大小对比：                                              │
│    NVIDIA:  32 threads/warp                                  │
│    AMD:     32 或 64 threads/wavefront (架构相关)            │
│    Intel:   8/16/32 threads/sub-group (可选)                │
└─────────────────────────────────────────────────────────────┘

SIMD vs SIMT的关键区别：
┌──────────────┬────────────────────────┬────────────────────────┐
│              │  SIMD (CPU AVX-512)    │  SIMT (GPU Warp)       │
├──────────────┼────────────────────────┼────────────────────────┤
│  编程模型    │  显式向量指令          │  标量代码自动向量化    │
│  分支处理    │  程序员手动mask        │  硬件自动predication   │
│  向量宽度    │  固定(128/256/512 bit) │  固定(32/64 threads)   │
│  内存访问    │  连续/gather/scatter   │  合并访问优化          │
│  线程概念    │  无(单线程多数据)      │  有(多线程同指令)      │
└──────────────┴────────────────────────┴────────────────────────┘
```

```cpp
// 演示sub-group操作 —— 在SYCL中观察SIMT行为
// sub-group是SYCL对warp/wavefront的抽象

#include <sycl/sycl.hpp>
#include <iostream>

int main() {
    sycl::queue q;
    constexpr size_t N = 64;

    // 使用USM便于直接读取结果
    int* result = sycl::malloc_shared<int>(N, q);
    int* sg_ids = sycl::malloc_shared<int>(N, q);
    int* sg_sizes = sycl::malloc_shared<int>(N, q);

    q.parallel_for(
        sycl::nd_range<1>(N, N),  // 所有线程在同一个work-group
        [=](sycl::nd_item<1> item) {
            auto sg = item.get_sub_group();

            size_t gid = item.get_global_id(0);
            sg_ids[gid] = sg.get_group_id()[0];    // 属于哪个sub-group
            sg_sizes[gid] = sg.get_local_range()[0]; // sub-group大小

            // sub-group内的shuffle操作 —— 不需要shared memory！
            // 直接在寄存器层面交换数据
            int my_val = static_cast<int>(gid * 10);
            // 从sub-group内相邻线程获取值
            int neighbor_val = sycl::shift_group_left(sg, my_val, 1);
            result[gid] = neighbor_val;
        }
    ).wait();

    std::cout << "Sub-group structure:\n";
    for (size_t i = 0; i < N; ++i) {
        if (i > 0 && sg_ids[i] != sg_ids[i-1])
            std::cout << "---\n";
        std::cout << "Thread " << i
                  << " -> sub-group " << sg_ids[i]
                  << " (size=" << sg_sizes[i]
                  << ") shuffle_left=" << result[i] << "\n";
    }

    sycl::free(result, q);
    sycl::free(sg_ids, q);
    sycl::free(sg_sizes, q);
}
```

#### 1.3 性能定律：Amdahl与Gustafson

```
Amdahl定律（Gene Amdahl, 1967）—— 强扩展性（Fixed Problem Size）

  公式：S(N) = 1 / ((1-P) + P/N)

  其中：P = 可并行比例，N = 处理器数量，S = 加速比

  加速比上限 = 1 / (1-P)  （当 N → ∞ 时）

  ┌────────────────────────────────────────────────────────┐
  │  加速比                                                │
  │  S(N) ▲                                               │
  │       │                                    P=99%       │
  │  100  │                               ••••••••••       │
  │       │                          •••••                 │
  │       │                     ••••      P=95%            │
  │   50  │                ••••     ••••••••••••           │
  │       │            •••     ••••                        │
  │       │         ••    •••       P=90%                  │
  │   20  │       •   •••    ••••••••••••••                │
  │       │     •  ••     •••                              │
  │   10  │    • ••   •••        P=75%                     │
  │       │   •••  •••    ••••••••••••                     │
  │    5  │  ••  ••   ••••       P=50%                     │
  │       │ •• ••  •••    ────────────                     │
  │    2  │•• •  ••                                        │
  │    1  │•─┼───┼────┼────┼────┼────┼────► N             │
  │       1  10  100  1K   10K  100K 1M   处理器数         │
  └────────────────────────────────────────────────────────┘

  例子：程序中5%是串行的（P=95%）
  → 即使用无限多处理器，加速比上限 = 1/0.05 = 20x
  → 用100个处理器时：S = 1/(0.05 + 0.95/100) = 16.8x

Gustafson定律（John Gustafson, 1988）—— 弱扩展性（Fixed Time）

  公式：S(N) = N - α(N-1)

  其中：α = 串行比例（在并行版本中测量），N = 处理器数量

  关键洞察：实际应用中，我们通常在更多处理器上处理更大的问题！

  ┌────────────────────────────────────────────────────────┐
  │                                                        │
  │  Amdahl视角（固定问题规模）：                          │
  │  ┌──┬──────────────────┐                               │
  │  │串│   可并行部分      │  总工作量固定                 │
  │  └──┴──────────────────┘                               │
  │  ┌──┬────┐                                             │
  │  │串│并/N│  N个处理器 → 并行部分缩短                   │
  │  └──┴────┘  但串行部分不变，成为瓶颈！                 │
  │                                                        │
  │  Gustafson视角（固定执行时间）：                        │
  │  ┌──┬────────┐                                         │
  │  │串│ 并行×1 │  1个处理器                              │
  │  └──┴────────┘                                         │
  │  ┌──┬────────────────────────────┐                     │
  │  │串│     并行×N（更大的问题）   │  N个处理器           │
  │  └──┴────────────────────────────┘                     │
  │  总时间相同，但处理了N倍的数据！                       │
  │                                                        │
  │  GPU计算几乎总是在Gustafson模式下：                    │
  │  有了更多核心 → 处理更大的数据集 → 串行比例越来越小    │
  └────────────────────────────────────────────────────────┘
```

**关键洞察**：
- Amdahl定律说"加速有上限"，这是真的——但只对固定大小的问题成立
- Gustafson定律说"用更多核心处理更大问题"，这更接近GPU使用的现实
- 实际GPU程序有时获得"超线性加速"（super-linear speedup），原因是缓存效应：将问题分到多个SM后，每个SM的工作集能放入L1/shared memory

#### 1.4 SYCL的历史与生态系统

```
SYCL发展时间线：

2009 ─── OpenCL 1.0发布（Khronos）
  │      分离式编程：主机C/C++ + 设备OpenCL C
  │      痛点：字符串形式的kernel、无模板、调试困难
  │
2014 ─── SYCL 1.2发布
  │      目标：OpenCL之上的C++11抽象层
  │      关键创新：单源编程、Buffer/Accessor模型
  │
2017 ─── SYCL 1.2.1发布
  │      改进：更好的C++14支持、错误处理
  │      Codeplay的ComputeCpp成为首个商业实现
  │
2018 ─── Intel宣布oneAPI计划
  │      DPC++ = SYCL + Intel扩展
  │      信号：一个CPU巨头all-in异构计算标准
  │
2020 ─── SYCL 2020发布
  │      重大更新：USM、Reductions、Group算法
  │      Sub-group支持、Specialization Constants
  │      C++17特性（CTAD、if constexpr等）
  │
2021 ─── AdaptiveCpp（原hipSYCL）支持CUDA/HIP后端
  │      SYCL不再只是Intel的 → 真正跨厂商
  │
2023 ─── Codeplay被NVIDIA收购
  │      oneAPI工具链成熟，支持NVIDIA/AMD GPU
  │      SYCL生态快速扩展
  │
2024+ ── SYCL成为ISO C++并行编程的重要候选方向
         与std::execution的关系日益紧密

SYCL实现对比：
┌──────────────────┬─────────────────┬─────────────────┬───────────────┐
│                  │  DPC++ (Intel)  │  AdaptiveCpp    │  ComputeCpp   │
├──────────────────┼─────────────────┼─────────────────┼───────────────┤
│  CPU后端         │  ✓ OpenCL/TBB   │  ✓ OpenMP      │  ✓ (有限)     │
│  Intel GPU       │  ✓ Level Zero   │  ✓             │  ✓            │
│  NVIDIA GPU      │  ✓ CUDA PTX     │  ✓ CUDA/HIP   │  ✗            │
│  AMD GPU         │  ✓ HIP          │  ✓ HIP/ROCm   │  ✗            │
│  FPGA            │  ✓ (Intel)      │  ✗             │  ✗            │
│  SYCL版本        │  2020 + 扩展    │  2020          │  1.2.1        │
│  开源            │  ✓ (LLVM)       │  ✓             │  ✗ (已停止)   │
│  C++标准         │  C++17          │  C++17/20      │  C++14        │
└──────────────────┴─────────────────┴─────────────────┴───────────────┘

SYCL vs CUDA vs OpenCL vs HIP：
┌──────────────────┬────────┬────────┬────────┬────────┐
│                  │  SYCL  │  CUDA  │ OpenCL │  HIP   │
├──────────────────┼────────┼────────┼────────┼────────┤
│  跨厂商          │  ✓     │  ✗     │  ✓     │  部分  │
│  单源代码        │  ✓     │  ✓     │  ✗     │  ✓     │
│  C++模板支持     │  完整  │  完整  │  ✗     │  完整  │
│  Lambda内核      │  ✓     │  ✗     │  ✗     │  ✗     │
│  标准C++         │  ✓     │  扩展  │  C99   │  扩展  │
│  生态成熟度      │  增长中│  最成熟│  成熟  │  成熟  │
│  调试工具        │  良好  │  最佳  │  一般  │  良好  │
│  性能            │  接近  │  基准  │  接近  │  接近  │
│  学习曲线        │  中等  │  中等  │  陡峭  │  低    │
└──────────────────┴────────┴────────┴────────┴────────┘

关键洞察（Gordon Brown, Codeplay CTO）：
"SYCL的核心优势不是性能——而是用标准C++写可移植的异构代码。
 当你的代码能在Intel、NVIDIA、AMD上都运行时，你的投资才真正安全。"
```

#### 1.5 SYCL平台模型与设备管理

```
SYCL平台模型层次结构：

┌─────────────────────────────────────────────────────────────┐
│                     SYCL Application                         │
└──────────────────────────┬──────────────────────────────────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
┌────────▼─────────┐ ┌────▼──────────┐ ┌────▼──────────┐
│  Platform 0      │ │  Platform 1   │ │  Platform 2   │
│  (Intel OpenCL)  │ │  (NVIDIA CUDA)│ │  (AMD ROCm)   │
└────────┬─────────┘ └────┬──────────┘ └────┬──────────┘
         │                │                  │
    ┌────┴────┐      ┌────┴────┐        ┌───┴────┐
    │         │      │         │        │        │
┌───▼──┐ ┌───▼──┐ ┌─▼────┐ ┌─▼────┐ ┌─▼────┐ ┌─▼────┐
│CPU   │ │Intel │ │GPU 0 │ │GPU 1 │ │GPU 0 │ │GPU 1 │
│Device│ │GPU   │ │(A100)│ │(A100)│ │(MI300)││(MI300)│
└──┬───┘ └──┬───┘ └──┬───┘ └──┬───┘ └──┬───┘ └──┬───┘
   │        │        │        │        │        │
┌──▼────────▼────────▼────────▼────────▼────────▼──┐
│              Context (上下文)                      │
│  管理：内存对象、程序对象、内核对象的共享          │
│  同一context内的设备可以共享buffer                 │
└──────────────────────┬────────────────────────────┘
                       │
              ┌────────┴────────┐
              │                 │
        ┌─────▼─────┐    ┌─────▼─────┐
        │  Queue 0  │    │  Queue 1  │
        │  (GPU 0)  │    │  (CPU)    │
        │ in-order  │    │ out-order │
        └───────────┘    └───────────┘

Queue的两种模式：
  in_order:  命令严格按提交顺序执行（简单安全）
  out_of_order: 命令可以乱序执行（需要显式依赖，性能更好）
```

```cpp
// 完整的设备选择与队列管理示例

#include <sycl/sycl.hpp>
#include <iostream>
#include <vector>

// 自定义设备选择器 —— 优先选择计算单元最多的GPU
// SYCL 2020使用callable selector（而非继承device_selector）
int gpuWithMostCUs(const sycl::device& dev) {
    // 返回负数表示拒绝，正数表示优先级（越大越优先）
    if (!dev.is_gpu()) return -1;  // 拒绝非GPU设备

    // 用计算单元数作为优先级
    return dev.get_info<sycl::info::device::max_compute_units>();
}

// 异步错误处理器 —— 某些错误在kernel提交后才发生
// 必须通过这个handler捕获，否则程序可能静默失败！
auto asyncErrorHandler = [](sycl::exception_list exceptions) {
    for (const auto& e : exceptions) {
        try {
            std::rethrow_exception(e);
        } catch (const sycl::exception& ex) {
            std::cerr << "Async SYCL error: " << ex.what() << "\n";
            std::cerr << "Error code: " << ex.code() << "\n";
        }
    }
};

int main() {
    // 方式1：使用内置selector
    try {
        sycl::queue gpuQ{sycl::gpu_selector_v, asyncErrorHandler};
        std::cout << "GPU: "
                  << gpuQ.get_device().get_info<sycl::info::device::name>()
                  << "\n";
    } catch (const sycl::exception& e) {
        std::cout << "No GPU available: " << e.what() << "\n";
    }

    // 方式2：使用自定义selector
    try {
        sycl::queue bestGpuQ{gpuWithMostCUs, asyncErrorHandler};
        std::cout << "Best GPU: "
                  << bestGpuQ.get_device().get_info<sycl::info::device::name>()
                  << "\n";
    } catch (const sycl::exception& e) {
        std::cout << "No suitable GPU: " << e.what() << "\n";
    }

    // 方式3：多队列 —— 同时利用CPU和GPU
    sycl::queue cpuQ{sycl::cpu_selector_v, asyncErrorHandler};
    sycl::queue gpuQ{sycl::gpu_selector_v, asyncErrorHandler};

    // 方式4：in-order queue（命令严格按顺序执行）
    // 适合简单场景，无需手动管理依赖
    sycl::queue orderedQ{sycl::gpu_selector_v,
                         asyncErrorHandler,
                         sycl::property::queue::in_order{}};

    // 方式5：启用profiling（性能分析）
    sycl::queue profilingQ{sycl::gpu_selector_v,
                           asyncErrorHandler,
                           sycl::property::queue::enable_profiling{}};

    // 检查设备能力 —— 在提交kernel前确认设备支持所需特性
    auto dev = gpuQ.get_device();
    if (dev.has(sycl::aspect::fp64)) {
        std::cout << "Device supports double precision\n";
    }
    if (dev.has(sycl::aspect::usm_shared_allocations)) {
        std::cout << "Device supports USM shared allocations\n";
    }

    return 0;
}
```

#### 1.6 第一个SYCL程序详解

```
SYCL程序执行流程：

  Host代码                  Device代码
  ────────                  ──────────
  1. 创建queue
  2. 分配host内存
  3. 创建buffer        ──► 运行时分配device内存
  4. q.submit()        ──► 5. 编译kernel (JIT或AOT)
     │                      6. 传输数据到device
     │                      7. 执行kernel
     │                      8. (可能)传输数据回host
  9. 访问结果           ◄── 隐式同步（buffer作用域结束
     （通过host_accessor       或buffer析构时）
      或buffer析构）

两种编程模型对比：

  Buffer/Accessor模型：              USM模型：
  ┌──────────────────┐              ┌──────────────────┐
  │  buffer<T> buf   │              │  T* ptr =        │
  │  (RAII管理)      │              │  malloc_shared() │
  ├──────────────────┤              ├──────────────────┤
  │  accessor acc    │              │  直接使用指针    │
  │  (声明访问意图)  │              │  ptr[i] = ...    │
  ├──────────────────┤              ├──────────────────┤
  │  运行时自动：    │              │  程序员手动：    │
  │  - 传输数据      │              │  - memcpy()      │
  │  - 解析依赖      │              │  - wait()        │
  │  - 同步          │              │  - free()        │
  └──────────────────┘              └──────────────────┘
  安全但有开销                      灵活但需要手动管理
```

```cpp
// 示例1：Buffer/Accessor模型的向量加法 —— 逐行详解
// 这是SYCL最典型的编程模式

#include <sycl/sycl.hpp>
#include <iostream>
#include <vector>

int main() {
    // Step 1: 创建队列
    // gpu_selector_v是SYCL 2020的设备选择器
    // 如果没有GPU，会抛出sycl::exception
    sycl::queue q{sycl::gpu_selector_v};
    std::cout << "Running on: "
              << q.get_device().get_info<sycl::info::device::name>() << "\n";

    // Step 2: 在host端准备数据
    constexpr size_t N = 1024;
    std::vector<float> a(N, 1.0f);  // 全1
    std::vector<float> b(N, 2.0f);  // 全2
    std::vector<float> c(N, 0.0f);  // 结果

    // Step 3: 创建buffer —— 关键是作用域！
    // buffer在构造时"获取"host数据的所有权
    // buffer在析构时将结果"写回"到host指针
    {
        // buffer<T, Dimensions>(host_ptr, range)
        // range<1>(N) 表示一维、N个元素
        sycl::buffer<float, 1> buf_a(a.data(), sycl::range<1>(N));
        sycl::buffer<float, 1> buf_b(b.data(), sycl::range<1>(N));
        sycl::buffer<float, 1> buf_c(c.data(), sycl::range<1>(N));

        // Step 4: 提交命令组（command group）
        // submit的lambda接收handler引用
        // handler是与运行时交互的"指令构建器"
        q.submit([&](sycl::handler& h) {

            // Step 5: 创建accessor —— 声明数据访问意图
            // 运行时通过分析accessor的读写模式自动构建依赖图（DAG）
            //
            // access::mode::read    → 只读，不从device写回
            // access::mode::write   → 只写，不从host复制（适合纯输出）
            // access::mode::read_write → 读写
            auto acc_a = buf_a.get_access<sycl::access::mode::read>(h);
            auto acc_b = buf_b.get_access<sycl::access::mode::read>(h);
            auto acc_c = buf_c.get_access<sycl::access::mode::write>(h);

            // Step 6: 定义并提交内核
            // parallel_for(range, kernel_lambda)
            // 运行时创建N个work-item，每个执行lambda一次
            // id<1> i 是当前work-item的全局索引
            h.parallel_for(sycl::range<1>(N), [=](sycl::id<1> i) {
                // 注意：lambda按值捕获[=]
                // accessor的拷贝是轻量级的（只拷贝元数据，不拷贝数据）
                acc_c[i] = acc_a[i] + acc_b[i];
            });
        });

        // Step 7: 此时kernel可能还在执行！
        // SYCL的提交是异步的
        // 同步发生在：
        //   - buffer析构时
        //   - 创建host_accessor时
        //   - 显式调用q.wait()时

    } // ← buffer析构点！运行时：
      //   1. 等待所有使用这些buffer的kernel完成
      //   2. 将device上的buf_c数据复制回c.data()

    // Step 8: 现在可以安全地在host端使用结果
    std::cout << "c[0] = " << c[0] << " (expected 3.0)\n";
    std::cout << "c[N-1] = " << c[N-1] << " (expected 3.0)\n";

    return 0;
}
```

```cpp
// 示例2：同样的向量加法，使用USM（Unified Shared Memory）
// 更接近传统C++指针编程风格

#include <sycl/sycl.hpp>
#include <iostream>

int main() {
    sycl::queue q{sycl::gpu_selector_v};

    constexpr size_t N = 1024;

    // USM方式1: malloc_shared —— 主机和设备都能访问
    // 数据会在host和device之间自动迁移（类似CUDA的Unified Memory）
    float* a = sycl::malloc_shared<float>(N, q);
    float* b = sycl::malloc_shared<float>(N, q);
    float* c = sycl::malloc_shared<float>(N, q);

    // 在host端初始化 —— 直接用指针！
    for (size_t i = 0; i < N; ++i) {
        a[i] = 1.0f;
        b[i] = 2.0f;
    }

    // 提交kernel —— 不需要buffer和accessor
    // 内核直接通过指针访问数据
    q.parallel_for(sycl::range<1>(N), [=](sycl::id<1> i) {
        c[i] = a[i] + b[i];
    }).wait();  // .wait() 显式等待完成
    // USM没有buffer的自动同步，必须手动wait！

    std::cout << "c[0] = " << c[0] << " (expected 3.0)\n";

    // 必须手动释放 —— 没有RAII！
    sycl::free(a, q);
    sycl::free(b, q);
    sycl::free(c, q);

    return 0;
}
```

```
设计决策分析：Buffer/Accessor vs USM

何时选Buffer/Accessor：
  ✓ 运行时自动管理数据传输和依赖
  ✓ 适合多kernel的复杂数据流（DAG自动调度）
  ✓ 最佳可移植性（所有SYCL实现都支持）
  ✓ 初学者更安全（不会忘记同步或释放）
  ✗ 有运行时开销（DAG分析）
  ✗ 编程模型与传统C++差异大

何时选USM (malloc_shared)：
  ✓ 编程模型接近传统C++（指针操作）
  ✓ 适合从CUDA/CPU代码快速迁移
  ✓ 适合原型开发和实验
  ✗ 首次device访问可能触发page fault（延迟抖动）
  ✗ 不是所有设备都支持
  ✗ 容易忘记wait()导致数据竞争

何时选USM (malloc_device + memcpy)：
  ✓ 最大控制权，性能最可预测
  ✓ 适合性能关键路径
  ✓ 无page fault开销
  ✗ 代码最复杂（手动管理所有传输）
  ✗ 容易出bug

决策流程：
  新项目/学习 → Buffer/Accessor
  快速原型   → malloc_shared
  性能关键   → malloc_device + explicit memcpy
```

#### 1.7 错误处理与调试基础

```cpp
// SYCL有两种异常机制，都必须处理！

#include <sycl/sycl.hpp>
#include <iostream>

int main() {
    // =============================================
    // 1. 同步异常 —— 在submit()调用时立即抛出
    // =============================================
    try {
        // 如果系统上没有GPU，这里会抛异常
        sycl::queue q{sycl::gpu_selector_v};

        // 如果内存不足，这里可能抛异常
        constexpr size_t HUGE = 1ULL << 40;  // 1TB
        float* p = sycl::malloc_device<float>(HUGE, q);
        if (!p) {
            std::cerr << "malloc_device returned nullptr\n";
        }
    } catch (const sycl::exception& e) {
        std::cerr << "Sync SYCL error: " << e.what() << "\n";
        // e.code() 返回std::error_code
        // e.category() 返回错误类别（sycl或OpenCL）
    }

    // =============================================
    // 2. 异步异常 —— kernel执行时才发生
    //    如果不注册handler，这些错误会被静默吞掉！
    // =============================================
    auto asyncHandler = [](sycl::exception_list elist) {
        for (auto& e : elist) {
            try {
                std::rethrow_exception(e);
            } catch (const sycl::exception& ex) {
                std::cerr << "Async SYCL error: " << ex.what() << "\n";
            }
        }
    };

    sycl::queue q{sycl::default_selector_v, asyncHandler};

    // 异步异常会在以下时机被报告：
    // - q.wait_and_throw()
    // - q.throw_asynchronous()
    // - queue析构时

    constexpr size_t N = 1024;
    float* data = sycl::malloc_shared<float>(N, q);

    q.parallel_for(sycl::range<1>(N), [=](sycl::id<1> i) {
        data[i] = static_cast<float>(i);
    });

    // wait_and_throw() = wait() + 触发异步异常handler
    q.wait_and_throw();

    // =============================================
    // 3. 优雅的设备回退模式
    // =============================================
    auto createQueueWithFallback = []() -> sycl::queue {
        // 优先GPU，回退到CPU
        try {
            sycl::queue q{sycl::gpu_selector_v};
            std::cout << "Using GPU: "
                      << q.get_device().get_info<sycl::info::device::name>()
                      << "\n";
            return q;
        } catch (...) {
            std::cout << "GPU not available, falling back to CPU\n";
            return sycl::queue{sycl::cpu_selector_v};
        }
    };

    auto fallbackQ = createQueueWithFallback();

    sycl::free(data, q);
    return 0;
}
```

```
SYCL常见错误与诊断：

┌──────────────────────────┬─────────────────────────────────────────┐
│  错误现象                │  可能原因                               │
├──────────────────────────┼─────────────────────────────────────────┤
│  结果全为0               │  忘记wait()导致读取未完成的结果         │
│                          │  accessor模式用了write而非read_write    │
├──────────────────────────┼─────────────────────────────────────────┤
│  段错误(SIGSEGV)         │  USM指针在host/device端越界访问         │
│                          │  buffer析构后仍使用accessor             │
├──────────────────────────┼─────────────────────────────────────────┤
│  "no kernel named..."   │  lambda捕获了不可序列化的对象            │
│                          │  device代码中调用了host-only函数        │
├──────────────────────────┼─────────────────────────────────────────┤
│  性能极差                │  malloc_shared的page fault开销           │
│                          │  反复创建/销毁buffer                    │
│                          │  work-group大小不合理                   │
├──────────────────────────┼─────────────────────────────────────────┤
│  "out of resources"     │  local memory超限                       │
│                          │  寄存器压力过大                         │
│                          │  work-group大小超过设备限制             │
└──────────────────────────┴─────────────────────────────────────────┘
```

#### 1.8 本周练习任务

```
练习1：设备能力探测报告生成器
────────────────────────────
目标：编写程序枚举所有SYCL设备并生成格式化的能力报告
要求：
1. 列出所有platform和device，标注设备类型（CPU/GPU/Accelerator）
2. 对每个device查询至少15项属性（compute units, max work group size,
   local memory size, global memory, sub-group sizes, USM支持,
   fp16/fp64支持, max_clock_frequency, image support等）
3. 输出格式化表格，用★标注"最强"设备（计算单元最多的GPU）
4. 包含device aspect查询（fp16, fp64, usm_device/host/shared）
验证：
- 在至少一种环境（CPU-only或有GPU）上正确运行
- 输出属性值合理（与硬件spec一致）
- 能正确区分CPU和GPU设备

练习2：Amdahl/Gustafson定律计算器
─────────────────────────────────
目标：实现命令行工具计算并显示加速比
要求：
1. 输入：串行比例alpha，最大处理器数N
2. 分别计算Amdahl和Gustafson的加速比
3. 以ASCII表格方式输出不同N值下的加速比
4. 标注Amdahl理论最大加速比 1/(1-P)
验证：
- 当alpha=0时加速比=N（完美线性扩展）
- 当alpha=0.5时Amdahl极限=2
- Gustafson加速比始终 >= Amdahl加速比

练习3：SYCL vs CPU向量运算基准测试
─────────────────────────────────
目标：对比CPU串行和SYCL两种方式的向量运算性能
要求：
1. 实现向量加法、点积、SAXPY三种运算
2. 测试N = 10^4, 10^5, 10^6, 10^7, 10^8
3. 计算每种方式的吞吐量(elements/sec)和带宽(GB/s)
4. 找到CPU和GPU的性能交叉点（GPU何时开始比CPU快）
验证：
- GPU在足够大的N时应比CPU快
- 带宽利用率应合理（不超过理论峰值）
- 结果数值正确

练习4：多设备负载均衡
──────────────────────
目标：在CPU+GPU两个设备上同时执行向量运算，实现简单的负载均衡
要求：
1. 创建两个queue分别绑定CPU和GPU（或两种不同设备）
2. 将数据分成两部分，分别提交到两个设备
3. 尝试不同的分割比例（10/90, 30/70, 50/50, 70/30, 90/10）
4. 测量总耗时 vs 单设备耗时，找到最优分割点
验证：
- 最优分割下的双设备总耗时应低于任一单设备
- 最优分割比例应大致反映设备算力比
```

#### 1.9 本周知识检验

```
思考题1：GPU拥有数千个核心，但单个核心的频率和IPC远低于CPU核心。
         对于一个包含大量分支判断的决策树推理任务，应该选择CPU还是GPU？
         如果将决策树展开为无分支的查表操作呢？请分析两种场景。

思考题2：SYCL选择了"单源"（single-source）编程模型，即主机代码和设备代码
         写在同一个C++文件中。相比OpenCL的"分离式"模型（主机C++，设备OpenCL C），
         单源模型的编译器实现有哪些额外挑战？
        （提示：考虑lambda捕获、模板实例化、device代码的限制）

思考题3：Amdahl定律暗示加速比存在上限 1/(1-P)。但实际GPU程序有时能获得
         超过理论上限的加速比（super-linear speedup）。
         这可能是什么原因？（提示：考虑缓存效应和问题分解后的工作集大小）

思考题4：SYCL的queue默认是in-order还是out-of-order？in-order queue的优势是什么？
         在什么场景下out-of-order queue能提供更好的性能？
         如何在out-of-order queue中表达内核之间的依赖关系？

思考题5：Intel、NVIDIA、AMD三家GPU的架构在Execution Unit/SM/CU的设计上
         有显著差异。SYCL如何在保持可移植性的同时，让程序员能利用硬件特性？
         SYCL的sub_group机制在这方面扮演什么角色？

实践题1：
  给定一个程序，串行部分耗时5ms，可并行部分在单核上耗时95ms。
  (a) 用Amdahl定律计算在64核CPU上的理论加速比
  (b) 如果GPU有4096个核心但频率是CPU的1/4，等效核心数是多少？
  (c) 考虑PCIe传输100MB数据需要约2ms，计算包含传输开销的实际加速比
  (d) 至少需要多大的并行工作量才能使GPU版本比64核CPU版本快？

实践题2：
  某SYCL程序在Intel i9 CPU（8核16线程）和NVIDIA RTX 4090 GPU上运行。
  CPU理论峰值带宽: 50 GB/s, GPU理论峰值带宽: 1 TB/s。
  向量加法 c[i] = a[i] + b[i]，N=1亿个float。
  (a) 计算理论最短执行时间（只考虑带宽，3个数组各4B/element）
  (b) 如果实际CPU带宽利用率60%，GPU带宽利用率70%，实际耗时各是多少？
  (c) 如果kernel launch overhead是10μs，PCIe传输延迟是0.1ms + N*4B/16GB/s,
      计算包含所有开销的端到端时间
```

---

### 第二周：SYCL内存模型与数据管理（35小时）

**学习目标**：
- [ ] 精通Buffer/Accessor模型：buffer从host指针/迭代器构造、访问模式（read/write/read_write）、accessor的RAII同步语义
- [ ] 理解基于accessor的DAG（有向无环图）调度：SYCL运行时如何通过分析accessor的读写模式自动解析数据依赖
- [ ] 精通三种USM分配类型：malloc_device（仅设备）、malloc_host（主机pinned）、malloc_shared（可迁移）；理解页迁移机制
- [ ] 理解SYCL内存一致性模型：happens-before关系、memory_order语义、fence操作及其与硬件内存模型的映射
- [ ] 实现sub-buffer创建和使用，用于分区数据处理而无需完整buffer拷贝
- [ ] 掌握host-device数据传输优化：pinned memory、计算与传输重叠、双缓冲、显式vs隐式传输
- [ ] 理解内存对齐要求及其对合并访问的影响：128字节对齐实现最优全局内存事务
- [ ] 通过基准测试量化Buffer/Accessor和USM在不同访问模式下的性能差异

**阅读材料**：
- [ ] SYCL 2020 Specification, Chapter 4.7（Buffers and Accessors）
- [ ] SYCL 2020 Specification, Chapter 4.8（Unified Shared Memory）
- [ ] 《Data Parallel C++》Chapters 6-7（Buffers和USM）
- [ ] Intel oneAPI GPU Optimization Guide, Chapter 3（Memory Management）
- [ ] "Understanding SYCL Memory Models" —— Khronos官方教程
- [ ] NVIDIA CUDA Best Practices Guide, Chapter 9（Memory Optimizations）—— 对比参考
- [ ] "Unified Memory in CUDA 6" —— Mark Harris, NVIDIA Developer Blog（概念适用于USM）
- [ ] Tom Deakin et al.: "Evaluating Attainable Memory Bandwidth of Parallel Programming Models via BabelStream"

---

#### 核心概念

```
┌─────────────────────────────────────────────────────────────┐
│                    SYCL内存模型全景                           │
└─────────────────────────────────────────────────────────────┘

                 ┌─────────────────────────────┐
                 │        SYCL 应用程序         │
                 └──────────────┬──────────────┘
                                │
              ┌─────────────────┼─────────────────┐
              │                 │                 │
    ┌─────────▼─────────┐ ┌────▼──────────┐ ┌────▼──────────┐
    │  Buffer/Accessor  │ │    USM        │ │   Images      │
    │  模型             │ │  (SYCL 2020)  │ │  (纹理内存)   │
    ├───────────────────┤ ├───────────────┤ ├───────────────┤
    │ ✓ 自动数据迁移    │ │ ✓ 指针语义   │ │ ✓ 硬件滤波    │
    │ ✓ DAG依赖分析     │ │ ✓ 与C++兼容  │ │ ✓ 缓存优化    │
    │ ✓ RAII同步        │ │ ✓ 显式控制   │ │ ✓ 插值        │
    │ ✗ 编程模型独特    │ │ ✗ 手动同步   │ │ ✗ 使用较少    │
    └─────────┬─────────┘ └──────┬────────┘ └───────────────┘
              │                  │
              ▼                  ▼
    ┌─────────────────────────────────────────┐
    │           物理内存层次                    │
    ├─────────────────────────────────────────┤
    │                                          │
    │  ┌──────────┐  ←── 寄存器 (~1 cycle)    │
    │  │ Register │      每work-item私有       │
    │  │ File     │      256KB per SM          │
    │  └────┬─────┘                            │
    │       ▼                                  │
    │  ┌──────────┐  ←── Local/Shared Memory  │
    │  │ Local    │      (~20-30 cycles)       │
    │  │ Memory   │      per work-group共享    │
    │  │ (SRAM)   │      48-128KB per SM       │
    │  └────┬─────┘                            │
    │       ▼                                  │
    │  ┌──────────┐  ←── L2 Cache             │
    │  │ L2 Cache │      (~200 cycles)         │
    │  │          │      全设备共享             │
    │  │          │      6-72MB                 │
    │  └────┬─────┘                            │
    │       ▼                                  │
    │  ┌──────────┐  ←── Global Memory (HBM/GDDR) │
    │  │ Global   │      (~400-600 cycles)     │
    │  │ Memory   │      全设备可见             │
    │  │          │      8-80GB, 高带宽         │
    │  └────┬─────┘                            │
    │       ▼                                  │
    │  ┌──────────┐  ←── Host Memory (DDR)    │
    │  │ Host     │      通过PCIe/CXL访问      │
    │  │ Memory   │      ~16-64 GB/s           │
    │  └──────────┘                            │
    └─────────────────────────────────────────┘

Accessor构建的DAG调度示例：

  Buffer A ──read──► Kernel 1 ──write──► Buffer B
                                            │
  Buffer C ──read──► Kernel 2 ──write──► Buffer D
                         ▲                  │
                         │ read             │ read
                    Buffer B ◄──────────────┘
                    (Kernel 2必须等K1完成！运行时自动推断)
```

#### 2.1 Buffer生命周期与所有权语义

```
Buffer生命周期状态图：

  ┌──────────┐    构造(host_ptr)     ┌──────────────┐
  │ Host     │ ──────────────────► │ Buffer       │
  │ Memory   │    buffer"借走"数据  │ Created      │
  │ (vector) │                      │ (owns data)  │
  └──────────┘                      └──────┬───────┘
                                           │
                          kernel submit     │  get_access<read_write>(h)
                                           ▼
                                    ┌──────────────┐
                                    │ Device       │
                                    │ Memory Copy  │ ← 运行时自动分配device内存
                                    │ (H→D传输)   │   并复制数据
                                    └──────┬───────┘
                                           │
                                    ┌──────▼───────┐
                                    │ Kernel       │
                                    │ Execution    │ ← 通过accessor读写
                                    └──────┬───────┘
                                           │
             host_accessor创建              │  buffer析构
             (阻塞等待kernel完成)           │  或set_final_data
                    │                      │
                    ▼                      ▼
             ┌──────────────┐       ┌──────────────┐
             │ Host Access  │       │ Write-back   │
             │ (D→H传输)   │       │ to host_ptr  │
             │ 阻塞当前线程 │       │ (自动)       │
             └──────────────┘       └──────────────┘

关键规则：
  1. Buffer构造时不一定立即复制数据（lazy）
  2. 首次device accessor创建时才触发H→D传输
  3. host_accessor创建会阻塞到所有device kernel完成
  4. Buffer析构触发D→H写回（如果有write accessor）
  5. set_final_data(nullptr) 可禁止写回
  6. set_write_back(false) 同样禁止写回
```

```cpp
// Buffer生命周期的完整演示

#include <sycl/sycl.hpp>
#include <iostream>
#include <vector>
#include <numeric>

int main() {
    sycl::queue q;
    constexpr size_t N = 1024;

    std::vector<int> data(N);
    std::iota(data.begin(), data.end(), 0);  // 0, 1, 2, ..., 1023

    // ========================================
    // 构造方式1：从host指针构造
    // buffer会在析构时将结果写回data.data()
    // ========================================
    {
        sycl::buffer<int, 1> buf(data.data(), sycl::range<1>(N));

        q.submit([&](sycl::handler& h) {
            // read_write：既读取原始数据，又写入修改后的数据
            auto acc = buf.get_access<sycl::access::mode::read_write>(h);
            h.parallel_for(sycl::range<1>(N), [=](sycl::id<1> i) {
                acc[i] *= 2;  // 每个元素乘以2
            });
        });

        // host_accessor：阻塞等待kernel完成，然后可以在host端读取
        // 这是在buffer存活期间访问设备数据的唯一安全方式
        sycl::host_accessor hostAcc(buf, sycl::read_only);
        std::cout << "Via host_accessor: " << hostAcc[0] << "\n";  // 0

    }  // ← buf析构：数据自动写回data向量
    std::cout << "After buffer destroyed: " << data[0] << "\n";  // 0

    // ========================================
    // 构造方式2：不绑定host指针
    // buffer管理自己的内存，没有写回目标
    // ========================================
    {
        sycl::buffer<float, 2> buf2d(sycl::range<2>(64, 64));
        // 2D buffer，64×64，没有初始数据

        q.submit([&](sycl::handler& h) {
            // write模式：告诉运行时"我只写不读"
            // 优化：运行时不需要将旧数据传到device
            auto acc = buf2d.get_access<sycl::access::mode::write>(h);
            h.parallel_for(sycl::range<2>(64, 64), [=](sycl::id<2> id) {
                acc[id] = static_cast<float>(id[0] * 64 + id[1]);
            });
        });
    }  // buf2d析构：因为没有绑定host指针，数据直接丢弃

    // ========================================
    // 构造方式3：控制写回行为
    // ========================================
    {
        std::vector<float> result(N);
        sycl::buffer<float> buf(result.data(), sycl::range<1>(N));

        // set_final_data: 指定写回目标（可以与构造时不同）
        // set_final_data(nullptr): 禁止写回
        buf.set_final_data(result.data());
        // buf.set_write_back(false);  // 另一种禁止写回的方式

        q.submit([&](sycl::handler& h) {
            auto acc = buf.get_access<sycl::access::mode::write>(h);
            h.parallel_for(sycl::range<1>(N), [=](sycl::id<1> i) {
                acc[i] = 3.14f;
            });
        });
    }

    return 0;
}
```

#### 2.2 Accessor深度解析：模式、目标与调度

```
Accessor分类体系：

访问模式 (access::mode):
┌──────────────────┬────────────────────────────────────────────┐
│  模式            │  语义                                      │
├──────────────────┼────────────────────────────────────────────┤
│  read            │  只读。H→D传输，不D→H写回                 │
│  write           │  只写。不H→D传输，D→H写回                 │
│                  │  （适合纯输出buffer，避免不必要的传输）     │
│  read_write      │  读写。H→D传输 + D→H写回                  │
└──────────────────┴────────────────────────────────────────────┘

访问目标 (access::target):
┌──────────────────┬────────────────────────────────────────────┐
│  目标            │  含义                                      │
├──────────────────┼────────────────────────────────────────────┤
│  global_buffer   │  全局内存（默认）                          │
│  local           │  工作组本地内存（通过local_accessor）      │
│  host_buffer     │  主机端访问（通过host_accessor）           │
└──────────────────┴────────────────────────────────────────────┘

DAG依赖分析示例：

  q.submit([&](handler& h) {
      auto a = bufA.get_access<read>(h);      // 读A
      auto b = bufB.get_access<write>(h);     // 写B
      h.parallel_for(..., K1);
  });

  q.submit([&](handler& h) {
      auto b = bufB.get_access<read>(h);      // 读B ← 依赖K1的写B！
      auto c = bufC.get_access<write>(h);     // 写C
      h.parallel_for(..., K2);
  });

  q.submit([&](handler& h) {
      auto a = bufA.get_access<read>(h);      // 读A ← 无新依赖
      auto d = bufD.get_access<write>(h);     // 写D
      h.parallel_for(..., K3);
  });

  运行时构建的DAG：
       K1 (读A, 写B)
      ╱         ╲
    K2            K3       ← K2依赖K1（因为B的RAW依赖）
  (读B,写C)   (读A,写D)      K3不依赖K1（A只被读取，无冲突）
                              K3可以与K1并行！

  依赖类型：
    RAW (Read After Write): K2读B，K1写B → 必须等待
    WAR (Write After Read): 无冲突，SYCL运行时通过copy避免
    WAW (Write After Write): 后写必须等前写完成
```

```cpp
// 多kernel流水线展示DAG自动调度

#include <sycl/sycl.hpp>
#include <iostream>
#include <vector>
#include <chrono>

int main() {
    sycl::queue q{sycl::property::queue::enable_profiling{}};
    constexpr size_t N = 1 << 20;  // 1M elements

    std::vector<float> hostA(N, 1.0f);
    std::vector<float> hostB(N, 2.0f);
    std::vector<float> hostC(N, 0.0f);
    std::vector<float> hostD(N, 0.0f);

    {
        sycl::buffer<float> bufA(hostA.data(), sycl::range<1>(N));
        sycl::buffer<float> bufB(hostB.data(), sycl::range<1>(N));
        sycl::buffer<float> bufC(hostC.data(), sycl::range<1>(N));
        sycl::buffer<float> bufD(hostD.data(), sycl::range<1>(N));

        // Kernel 1: C = A + B （读A、读B、写C）
        auto e1 = q.submit([&](sycl::handler& h) {
            auto a = bufA.get_access<sycl::access::mode::read>(h);
            auto b = bufB.get_access<sycl::access::mode::read>(h);
            auto c = bufC.get_access<sycl::access::mode::write>(h);
            h.parallel_for(sycl::range<1>(N), [=](sycl::id<1> i) {
                c[i] = a[i] + b[i];
            });
        });

        // Kernel 2: D = C * 2 （读C、写D）
        // 依赖K1！因为K1写了C，K2要读C（RAW依赖）
        // 运行时自动保证K2在K1之后执行
        auto e2 = q.submit([&](sycl::handler& h) {
            auto c = bufC.get_access<sycl::access::mode::read>(h);
            auto d = bufD.get_access<sycl::access::mode::write>(h);
            h.parallel_for(sycl::range<1>(N), [=](sycl::id<1> i) {
                d[i] = c[i] * 2.0f;
            });
        });

        // Kernel 3: A = A * 3 （读写A）
        // 与K2无依赖（不共享buffer），可以并行！
        // 但依赖K1（K1读了A，K3要写A → WAR依赖）
        auto e3 = q.submit([&](sycl::handler& h) {
            auto a = bufA.get_access<sycl::access::mode::read_write>(h);
            h.parallel_for(sycl::range<1>(N), [=](sycl::id<1> i) {
                a[i] = a[i] * 3.0f;
            });
        });

    }  // 所有buffer析构，触发同步和写回

    // 验证结果
    std::cout << "C[0] = " << hostC[0] << " (expected 3.0)\n";   // A+B
    std::cout << "D[0] = " << hostD[0] << " (expected 6.0)\n";   // C*2
    std::cout << "A[0] = " << hostA[0] << " (expected 3.0)\n";   // A*3

    return 0;
}
```

#### 2.3 USM三种分配类型详解

```
USM内存类型对比：

┌──────────────────┬──────────────┬──────────────┬──────────────┐
│                  │ malloc_device│ malloc_host  │ malloc_shared│
├──────────────────┼──────────────┼──────────────┼──────────────┤
│  Host端可访问    │  ✗           │  ✓           │  ✓           │
│  Device端可访问  │  ✓           │  ✓(通过PCIe) │  ✓           │
├──────────────────┼──────────────┼──────────────┼──────────────┤
│  内存位置        │  Device VRAM │  Host DDR    │  自动迁移    │
│                  │              │  (pinned)    │  (page-based)│
├──────────────────┼──────────────┼──────────────┼──────────────┤
│  Device访问速度  │  最快        │  慢(PCIe)    │  首次慢      │
│                  │  (~1 TB/s)   │  (~16 GB/s)  │  之后快      │
├──────────────────┼──────────────┼──────────────┼──────────────┤
│  Host访问速度    │  N/A         │  最快        │  可能有      │
│                  │              │  (~50 GB/s)  │  page fault  │
├──────────────────┼──────────────┼──────────────┼──────────────┤
│  数据传输        │  显式memcpy  │  隐式PCIe    │  隐式迁移    │
│  方式            │              │              │  (on demand) │
├──────────────────┼──────────────┼──────────────┼──────────────┤
│  适用场景        │  大数据+     │  小数据+     │  原型开发+   │
│                  │  性能关键    │  频繁host读  │  共享数据结构│
├──────────────────┼──────────────┼──────────────┼──────────────┤
│  需要显式同步    │  ✓(memcpy)   │  ✓(wait)     │  ✓(wait)     │
├──────────────────┼──────────────┼──────────────┼──────────────┤
│  Aspect要求      │  usm_device  │  usm_host    │  usm_shared  │
│                  │ _allocations │ _allocations │ _allocations │
└──────────────────┴──────────────┴──────────────┴──────────────┘

malloc_shared的页迁移机制：

  初始状态：数据在Host内存
  ┌──────────┐                  ┌──────────┐
  │  Host    │ [Page A][Page B] │  Device  │
  │  Memory  │ [Page C][Page D] │  Memory  │ (空)
  └──────────┘                  └──────────┘

  Device kernel访问Page A → 触发page fault：
  ┌──────────┐                  ┌──────────┐
  │  Host    │ [     ][Page B]  │  Device  │
  │  Memory  │ [Page C][Page D] │  Memory  │ [Page A]
  └──────────┘    ↑ migrate →   └──────────┘
                  Page A迁移到Device

  后续kernel继续访问Page A → 无page fault（已在device端）
  但如果Host读取Page A → 又一次page fault，迁移回来

  问题：随机访问模式会导致大量page fault → 性能灾难！
```

```cpp
// 三种USM类型的完整示例与性能对比

#include <sycl/sycl.hpp>
#include <iostream>
#include <chrono>
#include <vector>

using Clock = std::chrono::high_resolution_clock;

// 辅助：测量耗时
template<typename F>
double measureMs(F&& func) {
    auto start = Clock::now();
    func();
    auto end = Clock::now();
    return std::chrono::duration<double, std::milli>(end - start).count();
}

int main() {
    sycl::queue q{sycl::gpu_selector_v};
    constexpr size_t N = 1 << 22;  // 4M elements ≈ 16MB

    // ===== malloc_device: 最快的device访问 =====
    {
        int* devData = sycl::malloc_device<int>(N, q);
        std::vector<int> hostData(N, 42);

        // 必须用memcpy传输数据
        double copyToDevice = measureMs([&]() {
            q.memcpy(devData, hostData.data(), N * sizeof(int)).wait();
        });

        double kernelTime = measureMs([&]() {
            q.parallel_for(sycl::range<1>(N), [=](sycl::id<1> i) {
                devData[i] *= 2;
            }).wait();
        });

        double copyToHost = measureMs([&]() {
            q.memcpy(hostData.data(), devData, N * sizeof(int)).wait();
        });

        std::cout << "malloc_device:\n"
                  << "  H->D copy: " << copyToDevice << " ms\n"
                  << "  Kernel:    " << kernelTime << " ms\n"
                  << "  D->H copy: " << copyToHost << " ms\n"
                  << "  Total:     " << (copyToDevice + kernelTime + copyToHost)
                  << " ms\n\n";

        sycl::free(devData, q);
    }

    // ===== malloc_shared: 最方便的编程模型 =====
    {
        int* sharedData = sycl::malloc_shared<int>(N, q);

        double initTime = measureMs([&]() {
            for (size_t i = 0; i < N; ++i) sharedData[i] = 42;
        });

        // 首次device访问可能触发page migration
        double kernelTime = measureMs([&]() {
            q.parallel_for(sycl::range<1>(N), [=](sycl::id<1> i) {
                sharedData[i] *= 2;
            }).wait();
        });

        // prefetch提示：预先将数据迁移到device，减少page fault
        // q.prefetch(sharedData, N * sizeof(int)).wait();

        std::cout << "malloc_shared:\n"
                  << "  Host init: " << initTime << " ms\n"
                  << "  Kernel:    " << kernelTime << " ms (含page migration)\n\n";

        sycl::free(sharedData, q);
    }

    // ===== malloc_host: host端最快，device通过PCIe访问 =====
    {
        int* hostPinned = sycl::malloc_host<int>(N, q);

        double initTime = measureMs([&]() {
            for (size_t i = 0; i < N; ++i) hostPinned[i] = 42;
        });

        // Device通过PCIe访问host memory，带宽受限
        double kernelTime = measureMs([&]() {
            q.parallel_for(sycl::range<1>(N), [=](sycl::id<1> i) {
                hostPinned[i] *= 2;
            }).wait();
        });

        std::cout << "malloc_host:\n"
                  << "  Host init: " << initTime << " ms\n"
                  << "  Kernel:    " << kernelTime << " ms (PCIe带宽限制)\n\n";

        sycl::free(hostPinned, q);
    }

    return 0;
}
```

#### 2.4 内存一致性模型

```
SYCL内存一致性：

  SYCL采用"relaxed consistency"（松弛一致性）模型。
  这意味着：
    - 同一work-item内的操作是顺序一致的
    - 不同work-item之间没有默认的顺序保证
    - 需要显式同步来建立happens-before关系

  同步机制层次：

  ┌─────────────────────────────────────────────────────────┐
  │  作用范围            │  同步机制                         │
  ├─────────────────────┼───────────────────────────────────┤
  │  Work-item内        │  天然顺序执行                     │
  │                     │  无需同步                         │
  ├─────────────────────┼───────────────────────────────────┤
  │  Sub-group内        │  sub_group::barrier()             │
  │  (同一warp)         │  或隐式（SIMT同步执行）           │
  ├─────────────────────┼───────────────────────────────────┤
  │  Work-group内       │  group_barrier(group)             │
  │                     │  local_accessor + barrier          │
  ├─────────────────────┼───────────────────────────────────┤
  │  跨Work-group       │  ✗ 不支持kernel内同步！           │
  │                     │  必须拆分成多个kernel             │
  ├─────────────────────┼───────────────────────────────────┤
  │  跨Kernel           │  事件依赖 / accessor DAG          │
  │                     │  / in-order queue                 │
  ├─────────────────────┼───────────────────────────────────┤
  │  Host-Device        │  q.wait() / host_accessor         │
  │                     │  / buffer析构                     │
  └─────────────────────┴───────────────────────────────────┘

  memory_scope层次（SYCL 2020 atomic_ref）：
    work_item  < sub_group  < work_group  < device  < system
    (最窄scope = 最快)                    (最宽scope = 最慢)
```

```cpp
// SYCL 2020 atomic_ref 示例：安全的并发计数器

#include <sycl/sycl.hpp>
#include <iostream>

int main() {
    sycl::queue q;
    constexpr size_t N = 1 << 20;

    // 全局计数器
    int* counter = sycl::malloc_shared<int>(1, q);
    *counter = 0;

    q.parallel_for(sycl::range<1>(N), [=](sycl::id<1> i) {
        // atomic_ref：在已有内存上创建原子视图
        // memory_order::relaxed：最快但只保证原子性，不保证顺序
        // memory_scope::device：所有work-group可见
        sycl::atomic_ref<int,
                         sycl::memory_order::relaxed,
                         sycl::memory_scope::device,
                         sycl::access::address_space::global_space>
            atomicCounter(*counter);

        atomicCounter.fetch_add(1);
    }).wait();

    std::cout << "Counter = " << *counter
              << " (expected " << N << ")\n";

    // 注意：不用atomic的话，结果是不确定的！
    // 多个work-item同时执行 counter++ 会导致数据竞争

    sycl::free(counter, q);
    return 0;
}
```

#### 2.5 Sub-buffer与Buffer属性

```
Sub-buffer：Buffer的子视图

  Parent Buffer:
  ┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
  │ 0 │ 1 │ 2 │ 3 │ 4 │ 5 │ 6 │ 7 │ 8 │ 9 │10 │11 │
  └───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘

  Sub-buffer A (offset=0, size=4):
  ┌───┬───┬───┬───┐
  │ 0 │ 1 │ 2 │ 3 │
  └───┴───┴───┴───┘

  Sub-buffer B (offset=4, size=4):
                  ┌───┬───┬───┬───┐
                  │ 4 │ 5 │ 6 │ 7 │
                  └───┴───┴───┴───┘

  Sub-buffer C (offset=8, size=4):
                                  ┌───┬───┬───┬───┐
                                  │ 8 │ 9 │10 │11 │
                                  └───┴───┴───┴───┘

  优势：
  - 三个kernel可以分别处理三个sub-buffer，无需依赖等待
  - 运行时知道三个区域不重叠，可以并行执行
  - 无需额外的内存分配和拷贝
```

```cpp
// Sub-buffer实现数据分区并行处理

#include <sycl/sycl.hpp>
#include <iostream>
#include <vector>
#include <numeric>

int main() {
    sycl::queue q;
    constexpr size_t N = 1024;
    constexpr size_t CHUNK = N / 4;

    std::vector<float> data(N);
    std::iota(data.begin(), data.end(), 0.0f);

    {
        sycl::buffer<float> parentBuf(data.data(), sycl::range<1>(N));

        // 创建4个sub-buffer，各处理1/4的数据
        for (size_t chunk = 0; chunk < 4; ++chunk) {
            // sub-buffer的构造：parent_buffer, offset, range
            sycl::buffer<float> subBuf(
                parentBuf,
                sycl::id<1>(chunk * CHUNK),       // 起始偏移
                sycl::range<1>(CHUNK)              // 元素数量
            );

            // 每个sub-buffer独立提交kernel
            // 因为区域不重叠，运行时可以并行执行这4个kernel！
            q.submit([&](sycl::handler& h) {
                auto acc = subBuf.get_access<sycl::access::mode::read_write>(h);
                float multiplier = static_cast<float>(chunk + 1);

                h.parallel_for(sycl::range<1>(CHUNK), [=](sycl::id<1> i) {
                    acc[i] *= multiplier;
                });
            });
        }
    }  // 所有buffer析构，结果写回data

    // 验证：前256个×1，接下来256个×2，...
    std::cout << "data[0] = " << data[0] << "\n";      // 0 × 1 = 0
    std::cout << "data[256] = " << data[256] << "\n";   // 256 × 2 = 512
    std::cout << "data[512] = " << data[512] << "\n";   // 512 × 3 = 1536
    std::cout << "data[768] = " << data[768] << "\n";   // 768 × 4 = 3072

    return 0;
}
```

#### 2.6 数据传输优化策略

```
双缓冲（Double Buffering）流水线：

  不用双缓冲（串行执行）：
  时间 →→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→
  传输: [===chunk0===][           ][===chunk1===][           ]
  计算: [           ][===chunk0===][           ][===chunk1===]
  总时间 = 传输时间 + 计算时间（完全串行）

  使用双缓冲（计算-传输重叠）：
  时间 →→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→
  传输: [===chunk0===][===chunk1===][===chunk2===][===chunk3===]
  计算: [           ][===chunk0===][===chunk1===][===chunk2===][===chunk3===]
                      ↑            ↑
                      传输chunk1的同时计算chunk0！

  理想情况：总时间 ≈ max(传输时间, 计算时间) + 一个chunk的传输时间
  加速比 ≈ 如果传输≈计算，接近2x
```

```cpp
// 双缓冲流水线实现

#include <sycl/sycl.hpp>
#include <iostream>
#include <vector>
#include <chrono>

int main() {
    sycl::queue q{sycl::property::queue::in_order{}};
    constexpr size_t N = 1 << 24;       // 16M elements
    constexpr size_t NUM_CHUNKS = 8;
    constexpr size_t CHUNK_SIZE = N / NUM_CHUNKS;

    std::vector<float> hostInput(N, 1.0f);
    std::vector<float> hostOutput(N, 0.0f);

    // 两个device buffer用于交替（双缓冲）
    float* devBuf[2];
    devBuf[0] = sycl::malloc_device<float>(CHUNK_SIZE, q);
    devBuf[1] = sycl::malloc_device<float>(CHUNK_SIZE, q);
    float* devOut[2];
    devOut[0] = sycl::malloc_device<float>(CHUNK_SIZE, q);
    devOut[1] = sycl::malloc_device<float>(CHUNK_SIZE, q);

    // 使用out-of-order queue + events实现重叠
    sycl::queue asyncQ;  // out-of-order by default

    auto start = std::chrono::high_resolution_clock::now();

    for (size_t chunk = 0; chunk < NUM_CHUNKS; ++chunk) {
        int cur = chunk % 2;        // 当前buffer槽位
        size_t offset = chunk * CHUNK_SIZE;

        // 传输当前chunk到device
        auto copyEvent = asyncQ.memcpy(
            devBuf[cur],
            hostInput.data() + offset,
            CHUNK_SIZE * sizeof(float)
        );

        // 在传输完成后执行kernel
        auto kernelEvent = asyncQ.submit([&](sycl::handler& h) {
            h.depends_on(copyEvent);  // 等待传输完成
            float* in = devBuf[cur];
            float* out = devOut[cur];
            h.parallel_for(sycl::range<1>(CHUNK_SIZE), [=](sycl::id<1> i) {
                // 一些有意义的计算
                out[i] = in[i] * 2.0f + 1.0f;
            });
        });

        // kernel完成后拷贝回host
        asyncQ.submit([&](sycl::handler& h) {
            h.depends_on(kernelEvent);
            h.memcpy(
                hostOutput.data() + offset,
                devOut[cur],
                CHUNK_SIZE * sizeof(float)
            );
        });
    }

    asyncQ.wait();

    auto end = std::chrono::high_resolution_clock::now();
    double ms = std::chrono::duration<double, std::milli>(end - start).count();
    std::cout << "Double-buffered pipeline: " << ms << " ms\n";
    std::cout << "Result check: " << hostOutput[0]
              << " (expected 3.0)\n";

    sycl::free(devBuf[0], q); sycl::free(devBuf[1], q);
    sycl::free(devOut[0], q); sycl::free(devOut[1], q);

    return 0;
}
```

#### 2.7 内存对齐与合并访问基础

```
GPU全局内存访问的合并（Coalescing）：

  当一个warp（32线程）执行一条内存指令时，
  GPU会将32个地址合并成最少的内存事务。

  理想情况：32个线程访问连续的32×4=128字节
  ┌──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┐
  │T0│T1│T2│T3│T4│T5│T6│T7│T8│T9│..│..│..│..│..│T31│ → 1次128B事务
  └──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┘
  地址: 0  4  8  12 16 20 24 28 32 36          124
  ✓ 完美合并 —— 1次内存事务搞定

  最差情况：32个线程访问不同的cache line
  ┌──┐  ┌──┐  ┌──┐  ┌──┐
  │T0│  │T1│  │T2│  │T3│  ... → 最多32次32B事务！
  └──┘  └──┘  └──┘  └──┘
  地址: 0  256 512 768          浪费了31/32的带宽

AoS vs SoA：

  AoS (Array of Structures) —— 通常不利于GPU：
  struct Particle { float x, y, z, mass; };
  Particle particles[N];

  内存布局:
  [x0,y0,z0,m0, x1,y1,z1,m1, x2,y2,z2,m2, ...]
   ↑T0           ↑T1           ↑T2
  线程访问x时步长=16B → 不连续 → 只利用了1/4带宽

  SoA (Structure of Arrays) —— GPU友好：
  float x[N], y[N], z[N], mass[N];

  内存布局:
  x: [x0,x1,x2,x3,...,xN]    ← 所有x连续
  y: [y0,y1,y2,y3,...,yN]    ← 所有y连续
  z: [z0,z1,z2,z3,...,zN]
  m: [m0,m1,m2,m3,...,mN]

  线程访问x时步长=4B → 完美连续 → 100%带宽利用

  实测差距：SoA通常比AoS快 2-4x（取决于访问模式）
```

#### 2.8 本周练习任务

```
练习1：Accessor DAG可视化
────────────────────────
目标：编写一个多步骤数据处理流水线，观察SYCL运行时的自动调度行为
要求：
1. 创建4个buffer，提交6个kernel，形成复杂的依赖图
2. 使用enable_profiling获取每个kernel的开始和结束时间
3. 打印出哪些kernel实际并行执行了（时间重叠）
4. 故意创建WAW（Write-After-Write）依赖，观察运行时如何处理
验证：
- 无数据依赖的kernel应该并行执行（时间有重叠）
- 有依赖的kernel应严格按序执行
- 结果与纯串行执行一致

练习2：USM性能基准测试
───────────────────────
目标：量化比较三种USM分配类型的性能特征
要求：
1. 分别用malloc_device、malloc_host、malloc_shared分配N个float
2. 测量：host端初始化速度、kernel执行速度、数据回读速度
3. 测试N = 10^4, 10^5, 10^6, 10^7, 10^8
4. 输出格式化的性能对比表格
验证：
- malloc_device的kernel执行应最快
- malloc_host的host端初始化应最快
- malloc_shared在首次device访问时可能有额外开销

练习3：双缓冲流水线实现
───────────────────────
目标：实现真正的compute-transfer overlap
要求：
1. 将大数组分成8个chunk
2. 使用两个device buffer交替：传输chunk_i的同时计算chunk_{i-1}
3. 用event依赖确保正确顺序
4. 测量总耗时 vs 纯串行处理耗时
验证：
- 双缓冲应比串行快1.3-1.8x（取决于计算/传输比）
- 结果数值与串行完全一致

练习4：内存带宽利用率分析
──────────────────────────
目标：实现BabelStream风格的内存带宽基准测试
要求：
1. 实现Copy(c=a)、Scale(b=scalar*c)、Add(c=a+b)、Triad(a=b+scalar*c)
2. 测量每种操作的有效带宽 (GB/s)
3. 对比不同数组大小和不同USM类型的带宽
4. 计算与硬件理论峰值带宽的比率
验证：
- Triad带宽应达到理论峰值的50%+
- Copy带宽应最接近峰值
```

#### 2.9 本周知识检验

```
思考题1：SYCL的Buffer在构造时可以传入host pointer。Buffer是否拷贝了数据？
         如果Buffer使用set_final_data(nullptr)会怎样？
         如果Buffer生命期内host pointer指向的内存被释放了会怎样？

思考题2：Accessor的DAG调度使得程序员不需要手动管理依赖。但这有性能代价吗？
         运行时需要做什么工作来分析依赖？在什么场景下这个开销不可忽略？
         USM + explicit event依赖是否总是比Buffer/Accessor更高效？

思考题3：malloc_shared在NVIDIA GPU上使用了统一虚拟内存（UVM）的page migration机制。
         当device首次访问一个page时会触发page fault。
         如果kernel访问模式是随机的（如hash table查找），性能会怎样？
         如何通过prefetch hint缓解这个问题？

思考题4：在多GPU系统中，一个Buffer可能需要在两个GPU之间迁移。
         SYCL运行时如何决定数据存放位置？如果两个kernel分别在GPU0和GPU1上
         读取同一Buffer，会发生几次数据传输？

思考题5：内存对齐为什么对GPU性能如此重要？在CPU上我们通常只关心缓存行对齐(64B)，
         而GPU还需要考虑什么层面的对齐？SYCL提供了哪些工具来控制对齐？

实践题1：
  一个SYCL程序创建了3个Buffer A(read), B(read), C(write)，提交了以下kernel：
    K1: reads A, writes B
    K2: reads B, writes C
    K3: reads A, reads C, writes B
  (a) 画出accessor构成的依赖DAG
  (b) K1和K2能否并行？K2和K3呢？
  (c) 如果添加K4: reads C，它与哪些kernel有依赖？

实践题2：
  设备全局内存带宽为900 GB/s。一个kernel执行 c[i] = a[i] + b[i]。
  N = 1亿个double (8B each)。
  (a) 总数据移动量是多少？（读2个数组+写1个数组）
  (b) 理论最短kernel执行时间是多少？
  (c) 如果使用malloc_shared且数据尚未在device上，还需加上page migration开销。
      假设page size = 64KB，每次page fault耗时10μs，计算额外开销。
  (d) 如果改用malloc_device + explicit memcpy (16 GB/s PCIe bandwidth)，
      传输时间是多少？总时间（传输+计算）是否比malloc_shared更优？
```

---

### 第三周：并行执行模型与内核编程（35小时）

**学习目标**：
- [ ] 掌握SYCL三种内核派发形式：basic parallel_for (range)、nd_range parallel_for、hierarchical parallelism
- [ ] 理解完整的工作分解层次：nd_range → work_group → sub_group → work_item，以及各层到硬件的映射
- [ ] 实现高效的local memory使用模式：协作数据加载、bank conflict避免、local memory作为用户管理的缓存
- [ ] 掌握barrier同步：group_barrier语义、fence_space选项、死锁避免
- [ ] 实现SYCL 2020 group算法：joint_reduce、exclusive_scan、group_broadcast、shift操作——理解其到硬件shuffle指令的映射
- [ ] 掌握reduction操作：sycl::reduction配合各种运算符（plus、maximum、minimum等），跨nd_range的归约
- [ ] 实现多kernel协调：基于event的依赖、in-order queue、命令组依赖，构建复杂工作流
- [ ] 理解specialization constants实现运行时可配置的kernel行为而无需重编译

**阅读材料**：
- [ ] SYCL 2020 Specification, Chapters 4.9-4.10（Expressing Parallelism, Group Functions）
- [ ] 《Data Parallel C++》Chapters 4, 9, 14（Kernels, Group Functions, Common Patterns）
- [ ] Intel oneAPI GPU Optimization Guide, Chapter 4-5（Work-group, Sub-group, Barriers）
- [ ] NVIDIA CUDA C++ Programming Guide, Chapter 5（Thread Hierarchy）—— 硬件对比参考
- [ ] "Sub-group Operations in SYCL" —— Codeplay技术博客
- [ ] GPU Gems 3, Chapter 39: "Parallel Prefix Sum (Scan) with CUDA" —— 算法模式适用于SYCL
- [ ] "Understanding GPU Barriers and Synchronization" —— 学术综述
- [ ] Khronos SYCL 2020 Reference Guide —— group算法快速参考

---

#### 核心概念

```
┌─────────────────────────────────────────────────────────────┐
│               SYCL并行执行模型全景                           │
└─────────────────────────────────────────────────────────────┘

SYCL提供三层递进的并行抽象：

  Level 1: basic parallel_for（最简单）
  ┌─────────────────────────────────────────────┐
  │  h.parallel_for(range<1>(N), [=](id<1> i)  │
  │  {                                          │
  │      // 只知道自己的global id              │
  │      // 无local memory，无barrier          │
  │      c[i] = a[i] + b[i];                   │
  │  });                                        │
  └─────────────────────────────────────────────┘
  适用：简单的逐元素操作，无需组内协作

  Level 2: nd_range parallel_for（最常用）
  ┌─────────────────────────────────────────────┐
  │  h.parallel_for(                            │
  │      nd_range<1>({N}, {WG_SIZE}),           │
  │      [=](nd_item<1> item) {                 │
  │          // 知道global/local/group id       │
  │          // 可以用local memory              │
  │          // 可以用barrier同步               │
  │          // 可以用sub-group操作             │
  │      });                                    │
  └─────────────────────────────────────────────┘
  适用：需要work-group级协作的算法（归约、scan、tiling）

  Level 3: hierarchical parallelism（最灵活）
  ┌─────────────────────────────────────────────┐
  │  h.parallel_for_work_group(                 │
  │      range<1>(num_groups), [=](group<1> g)  │
  │  {                                          │
  │      // work-group作用域（组内所有item共享）│
  │      int shared_val = 42;                   │
  │                                              │
  │      g.parallel_for_work_item(              │
  │          range<1>(WG_SIZE), [&](h_item<1> i)│
  │      {                                      │
  │          // work-item作用域（各item私有）   │
  │          use(shared_val);                    │
  │      });                                    │
  │  });                                        │
  └─────────────────────────────────────────────┘
  适用：自然分层的算法，两级并行更直觉

工作分解与硬件映射：

  SYCL概念          │  NVIDIA映射        │  Intel映射          │ AMD映射
  ─────────────────┼───────────────────┼────────────────────┼──────────────
  nd_range          │  Grid              │  ND-Range           │ Grid
  work_group        │  Thread Block      │  Work-group (→EU)  │ Workgroup
  sub_group         │  Warp (32 threads) │  Sub-group (8/16/32)│ Wavefront(32/64)
  work_item         │  Thread            │  Work-item          │ Work-item
  local_memory      │  Shared Memory     │  SLM                │ LDS
  global_memory     │  Global Memory     │  Global Memory      │ Global Memory
```

#### 3.1 basic parallel_for与range kernel

```cpp
// range kernel：最简单的SYCL并行形式
// 只需要指定总work-item数，运行时自动分组

#include <sycl/sycl.hpp>
#include <iostream>

int main() {
    sycl::queue q;

    // ===== 1D range kernel =====
    constexpr size_t N = 1024;
    float* data = sycl::malloc_shared<float>(N, q);

    q.parallel_for(sycl::range<1>(N), [=](sycl::id<1> i) {
        // i 可以隐式转换为 size_t
        data[i] = static_cast<float>(i) * 2.0f;
    }).wait();

    // ===== 2D range kernel（图像处理风格）=====
    constexpr size_t W = 640, H = 480;
    float* image = sycl::malloc_shared<float>(W * H, q);

    q.parallel_for(sycl::range<2>(H, W), [=](sycl::id<2> idx) {
        size_t row = idx[0];
        size_t col = idx[1];
        // 生成一个渐变图像
        image[row * W + col] = static_cast<float>(row + col) / (H + W);
    }).wait();

    // ===== 3D range kernel（体积数据）=====
    constexpr size_t X = 64, Y = 64, Z = 64;
    float* volume = sycl::malloc_shared<float>(X * Y * Z, q);

    q.parallel_for(sycl::range<3>(Z, Y, X), [=](sycl::id<3> idx) {
        size_t z = idx[0], y = idx[1], x = idx[2];
        float dist = sycl::sqrt(
            static_cast<float>((x-32)*(x-32) + (y-32)*(y-32) + (z-32)*(z-32))
        );
        volume[z * Y * X + y * X + x] = dist;
    }).wait();

    std::cout << "1D: data[10] = " << data[10] << "\n";
    std::cout << "2D: image[240*640+320] = " << image[240*640+320] << "\n";
    std::cout << "3D: center = " << volume[32*64*64+32*64+32] << "\n";

    sycl::free(data, q);
    sycl::free(image, q);
    sycl::free(volume, q);
}
```

```
basic parallel_for的限制：
  ✗ 不能使用local memory（local_accessor）
  ✗ 不能调用barrier
  ✗ 不能控制work-group大小（运行时决定）
  ✗ 不能使用nd_item的方法（get_local_id等）

  ✓ 但sub-group操作在某些实现中仍可用！
    因为运行时仍然会将work-items分组到sub-groups
```

#### 3.2 nd_range并行与工作组

```
nd_range的ID空间详解：

  全局范围 = {16}，本地范围 = {4}
  → 4个work-group，每组4个work-item

  Group 0         Group 1         Group 2         Group 3
  ┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
  │WI │WI │WI │WI │WI │WI │WI │WI │WI │WI │WI │WI │WI │WI │WI │WI │
  └───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘
  gid: 0  1  2  3   4  5  6  7   8  9  10 11  12 13 14 15
  lid: 0  1  2  3   0  1  2  3   0  1  2  3   0  1  2  3
  grp: 0  0  0  0   1  1  1  1   2  2  2  2   3  3  3  3

  公式：global_id = group_id × local_range + local_id
  例：  gid(6) = 1 × 4 + 2 = 6 ✓

  2D的情况（常见于矩阵运算）：
  nd_range<2>({M, N}, {TY, TX})

  全局范围 = {8, 8}，本地范围 = {4, 4}

          col→ 0  1  2  3  4  5  6  7
  row↓   ┌─────────────┬─────────────┐
    0     │ G(0,0)      │ G(0,1)      │
    1     │   WG        │   WG        │
    2     │ (4×4 items) │ (4×4 items) │
    3     │             │             │
          ├─────────────┼─────────────┤
    4     │ G(1,0)      │ G(1,1)      │
    5     │   WG        │   WG        │
    6     │             │             │
    7     │             │             │
          └─────────────┴─────────────┘
```

```cpp
// nd_range kernel完整示例：展示所有ID查询

#include <sycl/sycl.hpp>
#include <iostream>

int main() {
    sycl::queue q;
    constexpr size_t N = 256;
    constexpr size_t WG_SIZE = 64;
    constexpr size_t NUM_GROUPS = N / WG_SIZE;

    // 存储每个work-item的信息
    struct ItemInfo {
        size_t global_id;
        size_t local_id;
        size_t group_id;
        size_t sub_group_id;
        size_t sub_group_local_id;
        size_t sub_group_size;
    };

    ItemInfo* info = sycl::malloc_shared<ItemInfo>(N, q);

    q.parallel_for(
        sycl::nd_range<1>(sycl::range<1>(N), sycl::range<1>(WG_SIZE)),
        [=](sycl::nd_item<1> item) {
            size_t gid = item.get_global_id(0);

            auto sg = item.get_sub_group();

            info[gid].global_id = gid;
            info[gid].local_id = item.get_local_id(0);
            info[gid].group_id = item.get_group(0);
            info[gid].sub_group_id = sg.get_group_id()[0];
            info[gid].sub_group_local_id = sg.get_local_id()[0];
            info[gid].sub_group_size = sg.get_local_range()[0];

            // 还有很多有用的查询：
            // item.get_global_range(0)  → N (全局总数)
            // item.get_local_range(0)   → WG_SIZE (组大小)
            // item.get_group_range(0)   → NUM_GROUPS (组数量)
        }
    ).wait();

    // 打印前几个work-item的信息
    for (size_t i = 0; i < 8; ++i) {
        std::cout << "GID=" << info[i].global_id
                  << " LID=" << info[i].local_id
                  << " GRP=" << info[i].group_id
                  << " SG=" << info[i].sub_group_id
                  << " SG_LID=" << info[i].sub_group_local_id
                  << " SG_SIZE=" << info[i].sub_group_size << "\n";
    }

    sycl::free(info, q);
}
```

#### 3.3 Local Memory与协作加载

```
Local Memory（共享内存）的角色：

  没有Local Memory的情况：
  Global Memory (慢, ~400 cycles)
  ┌──────────────────────────────────────────────┐
  │ [d0][d1][d2][d3][d4][d5][d6][d7][d8]...     │ ← 每次访问都走全局内存
  └──────┬───┬───┬───┬───┬───┬───┬───┬───────────┘
         │   │   │   │   │   │   │   │
        T0  T1  T2  T3  T4  T5  T6  T7

  使用Local Memory：
  Global Memory
  ┌──────────────────────────┐
  │ [d0][d1][d2][d3]...     │ ← 只读一次到local
  └──────┬───────────────────┘
         │ 一次批量加载
         ▼
  Local Memory (快, ~20 cycles)
  ┌──────────────────────────┐
  │ [d0][d1][d2][d3]        │ ← 多次从local读取
  └──┬───┬───┬───┬──────────┘
     │   │   │   │
    T0  T1  T2  T3    ← 每个线程可以读取local中的任意位置

  Bank Conflict问题：
  Local memory被分成32个bank（NVIDIA）或类似数量

  无冲突（步长=1，每线程访问不同bank）：
  Bank:  0   1   2   3   4   5  ...  31
  Thread:T0  T1  T2  T3  T4  T5 ...  T31
  → 1个周期完成所有访问

  2路冲突（步长=2，偶数bank有两个请求）：
  Bank:  0   1   2   3   4   5  ...
  Thread:T0  -   T1  -   T2  -  ...
         T16 -   T17 -   T18 -  ...
  → 2个周期（串行化冲突bank的访问）

  32路冲突（所有线程访问同一bank）：
  Bank:  0
  Thread:T0, T1, T2, ..., T31
  → 32个周期！性能灾难！

  避免方法：给local memory数组添加1个元素的padding
  float tile[16][16]   → 可能有bank conflict
  float tile[16][17]   → padding消除bank conflict
```

```cpp
// 使用local memory的归约（reduction）—— 经典GPU pattern

#include <sycl/sycl.hpp>
#include <iostream>
#include <vector>

float parallelReduction(sycl::queue& q, const float* data, size_t N) {
    constexpr size_t WG_SIZE = 256;
    size_t numGroups = (N + WG_SIZE - 1) / WG_SIZE;

    // 部分和存储
    float* partialSums = sycl::malloc_shared<float>(numGroups, q);

    q.submit([&](sycl::handler& h) {
        // 每个work-group分配WG_SIZE个float的local memory
        sycl::local_accessor<float, 1> localMem(sycl::range<1>(WG_SIZE), h);

        h.parallel_for(
            sycl::nd_range<1>(numGroups * WG_SIZE, WG_SIZE),
            [=](sycl::nd_item<1> item) {
                size_t gid = item.get_global_id(0);
                size_t lid = item.get_local_id(0);
                size_t groupId = item.get_group(0);

                // Step 1: 从global memory加载到local memory
                // 越界的线程加载0（不影响求和结果）
                localMem[lid] = (gid < N) ? data[gid] : 0.0f;

                // Step 2: 同步 —— 确保所有线程都完成了加载
                // 这是必须的！没有barrier，其他线程可能还没写完
                sycl::group_barrier(item.get_group());

                // Step 3: Tree reduction（树形归约）
                // 每轮将活跃线程数减半
                //
                // 初始: [a0, a1, a2, a3, a4, a5, a6, a7]
                // s=4:  [a0+a4, a1+a5, a2+a6, a3+a7, -, -, -, -]
                // s=2:  [a0+a4+a2+a6, a1+a5+a3+a7, -, -, -, -, -, -]
                // s=1:  [sum_all, -, -, -, -, -, -, -]
                for (size_t stride = WG_SIZE / 2; stride > 0; stride /= 2) {
                    if (lid < stride) {
                        localMem[lid] += localMem[lid + stride];
                    }
                    sycl::group_barrier(item.get_group());
                    // 每次归约后都需要barrier！
                }

                // Step 4: 组内第一个线程写出部分和
                if (lid == 0) {
                    partialSums[groupId] = localMem[0];
                }
            }
        );
    }).wait();

    // 在host端完成最终归约（组数通常很小）
    float total = 0;
    for (size_t i = 0; i < numGroups; ++i) {
        total += partialSums[i];
    }

    sycl::free(partialSums, q);
    return total;
}

int main() {
    sycl::queue q;
    constexpr size_t N = 1 << 20;  // 1M

    float* data = sycl::malloc_shared<float>(N, q);
    q.parallel_for(sycl::range<1>(N), [=](sycl::id<1> i) {
        data[i] = 1.0f;
    }).wait();

    float sum = parallelReduction(q, data, N);
    std::cout << "Sum of " << N << " ones = " << sum
              << " (expected " << static_cast<float>(N) << ")\n";

    sycl::free(data, q);
}
```

#### 3.4 Group算法与集体操作（SYCL 2020）

```
SYCL 2020 Group算法概览：

  这些算法利用硬件的shuffle/ballot指令，
  比手动local memory + barrier实现更快更简洁。

  ┌──────────────────────────┬──────────────────────────────────┐
  │  算法                    │  功能                            │
  ├──────────────────────────┼──────────────────────────────────┤
  │  reduce_over_group       │  组内归约（sum, max, min...）    │
  │  exclusive_scan_over_group│ 组内前缀和（exclusive）         │
  │  inclusive_scan_over_group│ 组内前缀和（inclusive）         │
  │  group_broadcast          │ 广播：一个值 → 组内所有线程    │
  │  any_of_group             │ 组内是否有true                 │
  │  all_of_group             │ 组内是否全true                 │
  │  none_of_group            │ 组内是否全false                │
  ├──────────────────────────┼──────────────────────────────────┤
  │  shift_group_left         │ 组内左移（stencil常用）        │
  │  shift_group_right        │ 组内右移                       │
  │  select_from_group        │ 从指定lane读取值               │
  │  permute_group_by_xor     │ XOR置换（butterfly pattern）   │
  └──────────────────────────┴──────────────────────────────────┘

  这些算法可以在两个层级使用：
  - work_group级：group_barrier隐式包含
  - sub_group级：利用warp shuffle，无需barrier，最快！
```

```cpp
// SYCL 2020 Group算法实战

#include <sycl/sycl.hpp>
#include <iostream>

int main() {
    sycl::queue q;
    constexpr size_t N = 256;
    constexpr size_t WG = 64;

    float* input = sycl::malloc_shared<float>(N, q);
    float* scan_result = sycl::malloc_shared<float>(N, q);
    float* reduce_result = sycl::malloc_shared<float>(N / WG, q);

    // 初始化：每个元素 = 1.0
    for (size_t i = 0; i < N; ++i) input[i] = 1.0f;

    q.parallel_for(
        sycl::nd_range<1>(N, WG),
        [=](sycl::nd_item<1> item) {
            size_t gid = item.get_global_id(0);
            auto group = item.get_group();
            auto sg = item.get_sub_group();

            float val = input[gid];

            // === 1. Group Reduce: 组内求和 ===
            // 替代手动的tree reduction + barrier！
            float group_sum = sycl::reduce_over_group(
                group, val, sycl::plus<float>{}
            );
            // group_sum对组内所有线程都相同
            if (item.get_local_id(0) == 0) {
                reduce_result[item.get_group(0)] = group_sum;
            }

            // === 2. Exclusive Scan: 前缀和 ===
            // [1, 1, 1, 1, ...] → [0, 1, 2, 3, ...]
            float prefix = sycl::exclusive_scan_over_group(
                group, val, sycl::plus<float>{}
            );
            scan_result[gid] = prefix;

            // === 3. Sub-group操作（更快，无barrier！）===
            float sg_sum = sycl::reduce_over_sub_group(
                sg, val, sycl::plus<float>{}
            );

            // === 4. Broadcast: 组长的值广播给所有人 ===
            float leader_val = input[item.get_group(0) * WG];
            float broadcasted = sycl::group_broadcast(group, leader_val);

            // === 5. Any/All/None ===
            bool has_large = sycl::any_of_group(group, val > 0.5f);

            // === 6. Shift（stencil pattern常用）===
            // 获取sub-group内左邻居的值
            float left_neighbor = sycl::shift_group_right(sg, val, 1);
        }
    ).wait();

    // 验证
    std::cout << "Reduce results (each group sum): ";
    for (size_t i = 0; i < N / WG; ++i) {
        std::cout << reduce_result[i] << " ";  // 每组64个1的和 = 64
    }
    std::cout << "\n";

    std::cout << "Scan results (first 8): ";
    for (size_t i = 0; i < 8; ++i) {
        std::cout << scan_result[i] << " ";  // 0, 1, 2, 3, 4, 5, 6, 7
    }
    std::cout << "\n";

    sycl::free(input, q);
    sycl::free(scan_result, q);
    sycl::free(reduce_result, q);
}
```

#### 3.5 Reduction操作（SYCL 2020 sycl::reduction）

```
手动归约 vs SYCL 2020 reduction API对比：

  手动方式（~30行代码）：
    1. 分配local memory
    2. 加载数据
    3. barrier
    4. Tree reduction循环 + barrier
    5. 写出部分和
    6. Host端合并

  SYCL 2020方式（~3行代码）：
    auto sum_reduction = sycl::reduction(result_ptr, sycl::plus<>());
    h.parallel_for(range, sum_reduction, [=](id<1> i, auto& sum) {
        sum += data[i];
    });

  运行时自动选择最优归约策略！
```

```cpp
// SYCL 2020 Reduction API —— 极简且高效

#include <sycl/sycl.hpp>
#include <iostream>
#include <vector>
#include <limits>

int main() {
    sycl::queue q;
    constexpr size_t N = 1 << 20;

    float* data = sycl::malloc_shared<float>(N, q);
    for (size_t i = 0; i < N; ++i) {
        data[i] = static_cast<float>(i % 100);
    }

    // ===== 求和归约 =====
    float* sum_result = sycl::malloc_shared<float>(1, q);
    *sum_result = 0.0f;

    q.parallel_for(
        sycl::range<1>(N),
        // reduction对象：指定目标地址和运算符
        sycl::reduction(sum_result, sycl::plus<float>{}),
        [=](sycl::id<1> i, auto& sum) {
            sum += data[i];  // 累加到reduction变量
            // sum不是普通的float引用！
            // 它是sycl::reducer，支持combine操作
        }
    ).wait();

    std::cout << "Sum = " << *sum_result << "\n";

    // ===== 最大值归约 =====
    float* max_result = sycl::malloc_shared<float>(1, q);
    *max_result = std::numeric_limits<float>::lowest();

    q.parallel_for(
        sycl::range<1>(N),
        sycl::reduction(max_result, sycl::maximum<float>{}),
        [=](sycl::id<1> i, auto& mx) {
            mx.combine(data[i]);  // 也可以用combine()方法
        }
    ).wait();

    std::cout << "Max = " << *max_result << "\n";

    // ===== 多重归约（同时计算sum和max！）=====
    float* sum2 = sycl::malloc_shared<float>(1, q);
    float* min2 = sycl::malloc_shared<float>(1, q);
    *sum2 = 0.0f;
    *min2 = std::numeric_limits<float>::max();

    q.parallel_for(
        sycl::range<1>(N),
        sycl::reduction(sum2, sycl::plus<float>{}),
        sycl::reduction(min2, sycl::minimum<float>{}),
        [=](sycl::id<1> i, auto& s, auto& m) {
            s += data[i];
            m.combine(data[i]);
        }
    ).wait();

    std::cout << "Sum = " << *sum2 << ", Min = " << *min2 << "\n";

    sycl::free(data, q);
    sycl::free(sum_result, q);
    sycl::free(max_result, q);
    sycl::free(sum2, q);
    sycl::free(min2, q);
}
```

#### 3.6 多内核依赖与事件同步

```
事件（Event）依赖管理：

  Out-of-order queue中的依赖表达：

  auto e1 = q.submit([&](handler& h) {
      h.parallel_for(..., kernel1);
  });

  auto e2 = q.submit([&](handler& h) {
      h.depends_on(e1);                    ← 显式依赖
      h.parallel_for(..., kernel2);
  });

  auto e3 = q.submit([&](handler& h) {
      h.depends_on({e1, e2});              ← 依赖多个事件
      h.parallel_for(..., kernel3);
  });

  时间线：
  ──────────────────────────────────────►
  [===K1===]
            [===K2===]                      ← K2等K1完成
                      [===K3===]            ← K3等K1和K2都完成

  对比in-order queue：
  ──────────────────────────────────────►
  [===K1===][===K2===][===K3===]            ← 严格顺序，无需手动依赖
                                              但可能浪费并行机会

  Event Profiling（需要enable_profiling属性）：
  auto start = e.get_profiling_info<info::event_profiling::command_start>();
  auto end   = e.get_profiling_info<info::event_profiling::command_end>();
  double ms = (end - start) / 1e6;  // 纳秒 → 毫秒
```

```cpp
// 多kernel流水线 + event profiling

#include <sycl/sycl.hpp>
#include <iostream>

int main() {
    // 启用profiling以测量kernel执行时间
    sycl::queue q{sycl::gpu_selector_v,
                  sycl::property::queue::enable_profiling{}};

    constexpr size_t N = 1 << 20;
    float* a = sycl::malloc_shared<float>(N, q);
    float* b = sycl::malloc_shared<float>(N, q);
    float* c = sycl::malloc_shared<float>(N, q);

    // 初始化
    for (size_t i = 0; i < N; ++i) {
        a[i] = 1.0f;
        b[i] = 2.0f;
    }

    // Kernel 1: c = a + b
    auto e1 = q.parallel_for(sycl::range<1>(N), [=](sycl::id<1> i) {
        c[i] = a[i] + b[i];
    });

    // Kernel 2: a = c * 2 （依赖K1，因为需要c的结果）
    auto e2 = q.submit([&](sycl::handler& h) {
        h.depends_on(e1);
        h.parallel_for(sycl::range<1>(N), [=](sycl::id<1> i) {
            a[i] = c[i] * 2.0f;
        });
    });

    // Kernel 3: b = b * 3 （不依赖K1或K2，可以并行！）
    auto e3 = q.parallel_for(sycl::range<1>(N), [=](sycl::id<1> i) {
        b[i] = b[i] * 3.0f;
    });

    // 等待所有完成
    e2.wait();
    e3.wait();

    // 输出profiling信息
    auto printProfile = [](const std::string& name, sycl::event& e) {
        auto start = e.get_profiling_info<
            sycl::info::event_profiling::command_start>();
        auto end = e.get_profiling_info<
            sycl::info::event_profiling::command_end>();
        double ms = (end - start) / 1.0e6;
        std::cout << name << ": " << ms << " ms\n";
    };

    printProfile("K1 (c=a+b)", e1);
    printProfile("K2 (a=c*2)", e2);
    printProfile("K3 (b=b*3)", e3);

    std::cout << "a[0] = " << a[0] << " (expected 6.0)\n";
    std::cout << "b[0] = " << b[0] << " (expected 6.0)\n";

    sycl::free(a, q);
    sycl::free(b, q);
    sycl::free(c, q);
}
```

#### 3.7 Hierarchical Parallelism与特化常量

```cpp
// Hierarchical Parallelism：两级并行的自然表达

#include <sycl/sycl.hpp>
#include <iostream>

int main() {
    sycl::queue q;
    constexpr size_t N = 256;
    constexpr size_t WG = 64;
    constexpr size_t NUM_GROUPS = N / WG;

    float* data = sycl::malloc_shared<float>(N, q);
    float* group_sums = sycl::malloc_shared<float>(NUM_GROUPS, q);

    for (size_t i = 0; i < N; ++i) data[i] = 1.0f;

    q.submit([&](sycl::handler& h) {
        h.parallel_for_work_group(
            sycl::range<1>(NUM_GROUPS),   // 组数量
            sycl::range<1>(WG),           // 每组大小
            [=](sycl::group<1> grp) {
                // ========== work-group作用域 ==========
                // 这里的变量被组内所有work-item共享
                // 类似于local memory
                float sum = 0.0f;

                grp.parallel_for_work_item(
                    sycl::range<1>(WG),
                    [&](sycl::h_item<1> item) {
                        // ========== work-item作用域 ==========
                        size_t gid = grp.get_group_id(0) * WG
                                   + item.get_local_id(0);

                        // 注意：这里对sum的修改不是原子的！
                        // hierarchical模型假设编译器/运行时
                        // 会正确处理归约
                        // （实际上实现质量因vendor而异）
                    }
                );
                // 隐式barrier（退出parallel_for_work_item后）
                // work-group作用域可以再次访问共享数据
            }
        );
    }).wait();

    sycl::free(data, q);
    sycl::free(group_sums, q);
}
```

```cpp
// Specialization Constants: 运行时配置kernel参数

#include <sycl/sycl.hpp>
#include <iostream>

// 声明specialization constant（编译时的占位符）
// 实际值在运行时设定，但编译器可以优化为常量
constexpr sycl::specialization_id<int> tile_size_id;
constexpr sycl::specialization_id<float> scale_factor_id;

int main() {
    sycl::queue q;
    constexpr size_t N = 1024;

    float* data = sycl::malloc_shared<float>(N, q);
    for (size_t i = 0; i < N; ++i) data[i] = static_cast<float>(i);

    // 在运行时设置specialization constant的值
    // 好处：一份kernel代码，运行时根据设备能力选择不同参数
    q.submit([&](sycl::handler& h) {
        h.set_specialization_constant<tile_size_id>(16);
        h.set_specialization_constant<scale_factor_id>(2.5f);

        h.parallel_for(
            sycl::range<1>(N),
            [=](sycl::id<1> i, sycl::kernel_handler kh) {
                // 在kernel内读取specialization constant
                int tile = kh.get_specialization_constant<tile_size_id>();
                float scale = kh.get_specialization_constant<scale_factor_id>();

                data[i] = data[i] * scale + static_cast<float>(tile);
            }
        );
    }).wait();

    std::cout << "data[0] = " << data[0] << "\n";   // 0 * 2.5 + 16 = 16
    std::cout << "data[10] = " << data[10] << "\n";  // 10 * 2.5 + 16 = 41

    sycl::free(data, q);
}
```

#### 3.8 本周练习任务

```
练习1：并行Prefix Sum（Scan）实现
──────────────────────────────────
目标：实现work-efficient parallel exclusive scan
要求：
1. 使用Blelloch算法（up-sweep + down-sweep）
2. 支持任意长度N（不限于2的幂）
3. 对于超过单个work-group的输入，实现multi-block scan
4. 同时提供使用SYCL group算法的简化版本
验证：
- 结果与std::exclusive_scan完全一致
- N = 10^7时GPU版本比CPU串行scan快5x+

练习2：矩阵转置优化
────────────────────
目标：实现高性能矩阵转置，消除bank conflict
要求：
1. 朴素版本：直接读写全局内存
2. 优化版本：使用local memory + padding消除bank conflict
3. 测量两个版本的有效带宽
4. 解释为什么朴素转置的写操作是非合并的
验证：
- 优化版本带宽应比朴素版本提高1.5x+
- 通过与copy kernel对比验证带宽利用率

练习3：直方图计算
────────────────
目标：实现并行直方图，对比不同原子操作策略
要求：
1. 版本1：global memory atomic_ref（最简单）
2. 版本2：local memory atomic + 最终merge（减少竞争）
3. 输入：10^7个uint8值（0-255），输出256-bin直方图
4. 测量并对比两个版本的性能
验证：
- 两个版本结果完全一致
- 版本2应比版本1快2-5x（竞争更少）

练习4：Multi-kernel事件流水线
─────────────────────────────
目标：构建一个数据处理流水线，使用事件管理依赖
要求：
1. 流水线：输入 → 归一化(减均值除标准差) → 缩放 → 偏移 → 输出
2. 每一步是一个独立的kernel
3. 使用event依赖确保顺序（out-of-order queue）
4. 使用event profiling测量每一步的耗时
验证：
- 流水线结果与串行实现一致
- profiling数据显示kernel间无不必要等待

练习5：SYCL 2020 Reduction vs 手动归约
───────────────────────────────────────
目标：对比sycl::reduction API与手动local memory归约的性能和代码复杂度
要求：
1. 实现sum、max、min三种归约
2. 手动版本使用local_accessor + barrier + tree reduction
3. SYCL 2020版本使用sycl::reduction
4. 测试N = 10^4到10^8，记录代码行数和性能对比
验证：
- 两种方式结果完全一致
- SYCL 2020 reduction性能应与手动版本持平或更优
```

#### 3.9 本周知识检验

```
思考题1：basic parallel_for不允许使用local memory和barriers。
         但编译器/运行时仍然会将work-items分组。那么在basic parallel_for中，
         相邻的work-items是否在同一个warp/wavefront中？
         如果是，sub-group操作是否仍然可以使用？

思考题2：work-group大小的选择对性能有巨大影响。过小（如16）导致资源利用率低，
         过大（如1024）可能因寄存器压力降低occupancy。
         如何确定最优work-group大小？
         不同GPU架构有不同的sweet spot吗？

思考题3：group_barrier(group, memory_scope::work_group)与
         group_barrier(group, memory_scope::device)有什么区别？
         在什么场景下必须使用device scope的barrier？
         SYCL是否支持跨work-group的同步？为什么不支持？

思考题4：Blelloch的work-efficient parallel scan在理论上做O(n)的工作，
         但实践中往往不如Hillis-Steele的O(n log n)版本快。为什么？
        （提示：考虑warp-level并行度和step efficiency）

思考题5：SYCL的sycl::reduction机制由运行时选择最优归约策略。
         对于不同的reduction operator（plus vs maximum vs 自定义），
         运行时可能使用不同的策略吗？
         为什么交换律(commutativity)和结合律(associativity)对并行归约很重要？

实践题1：
  一个nd_range<2>({256,256}, {16,16})的kernel。
  (a) 总共有多少个work-item？多少个work-group？
  (b) 如果每个work-item使用32个寄存器，GPU有65536个寄存器/SM，
      一个SM最多同时容纳多少个work-group？(occupancy计算)
  (c) 如果每个work-group使用4KB local memory，SM有48KB local memory，
      这会进一步限制occupancy吗？
  (d) 如果改为nd_range<2>({256,256}, {32,8})，occupancy如何变化？

实践题2：
  使用local memory的矩阵乘法tiling算法。
  TILE_SIZE = 16, 矩阵维度 M=N=K=1024, 数据类型 float。
  (a) 每个work-group需要多少local memory？（两个tile）
  (b) 全局内存总读取量：朴素版本 vs tiling版本各是多少？
  (c) 计算arithmetic intensity（FLOPS/byte）的提升倍数
  (d) 如果TILE_SIZE改为32，local memory需求翻倍。在48KB local memory的GPU上
      是否可行？会对occupancy产生什么影响？
```

---

### 第四周：性能优化与高级技术（35小时）

**学习目标**：
- [ ] 掌握内存合并访问模式：理解不同架构的事务大小；通过SoA转换和padding诊断和修复非合并访问
- [ ] 理解occupancy优化：寄存器压力、local memory用量、work-group大小选择；使用occupancy计算器找到最优启动配置
- [ ] 识别并最小化分支分歧：将分歧代码重构为uniform代码；使用predication；将不同分支分到不同kernel
- [ ] 掌握profiling工具：Intel VTune/Advisor用于Intel GPU、NVIDIA Nsight用于NVIDIA DPC++、AMD rocprof；解读关键指标
- [ ] 实现多级优化的矩阵乘法：寄存器tiling、向量化load、tile双缓冲
- [ ] 理解vendor特定优化：Intel sub-group大小选择、NVIDIA warp级原语、AMD wavefront考量
- [ ] 实现真实优化算法：prefix sum、convolution（1D/2D）、histogram、sparse matrix-vector multiply
- [ ] 设计和实现SYCL kernel性能基准框架，包含roofline模型分析

**阅读材料**：
- [ ] Intel oneAPI GPU Optimization Guide, Chapters 6-10（Performance analysis, Memory access, Kernel optimization）
- [ ] 《Data Parallel C++》Chapters 15-17（Programming for GPUs, Performance Analysis, Libraries）
- [ ] NVIDIA CUDA C++ Best Practices Guide —— 优化概念适用于DPC++在NVIDIA上的运行
- [ ] "Roofline: An Insightful Visual Performance Model for Multicore Architectures" —— Williams, Waterman, Patterson
- [ ] Intel VTune Profiler documentation for GPU analysis
- [ ] "Optimizing Parallel Reduction in CUDA" —— Mark Harris (NVIDIA) —— 经典优化论文，技术适用于SYCL
- [ ] Volkov: "Understanding Latency Hiding on GPUs" —— 寄存器tiling和ILP
- [ ] "Performance Portability of SYCL Applications" —— 跨实现学术基准测试研究

---

#### 核心概念

```
┌─────────────────────────────────────────────────────────────┐
│                    Roofline性能模型                           │
└─────────────────────────────────────────────────────────────┘

  Performance (GFLOPS/s)
  ▲
  │                                    ┌─── Peak Compute (82 TFLOPS)
  │                          ┌─────────────────────────
  │                     ╱    │
  │                ╱         │ ← Compute Bound区域
  │           ╱              │   （提高计算效率）
  │      ╱                   │
  │  ╱  ← Memory Bound区域  │
  │╱     （提高带宽利用率） │
  │                          │
  └──────────────────────────┴─────────────► Arithmetic
     1    2    4    8   16  32  64  128      Intensity
                                             (FLOP/Byte)

  拐点 = Peak Compute / Peak Bandwidth
        = 82 TFLOPS / 1 TB/s = 82 FLOP/Byte

  Arithmetic Intensity = 总FLOP / 总数据移动量(Bytes)

  常见kernel的AI值：
  ┌──────────────────┬─────────┬─────────────────────┐
  │  Kernel          │  AI     │  所在区域            │
  ├──────────────────┼─────────┼─────────────────────┤
  │  Vector Add      │  0.08   │  Memory Bound       │
  │  (c=a+b)         │(1FLOP/  │  带宽是瓶颈        │
  │                  │ 12B)    │                     │
  ├──────────────────┼─────────┼─────────────────────┤
  │  Dot Product     │  0.17   │  Memory Bound       │
  │                  │         │                     │
  ├──────────────────┼─────────┼─────────────────────┤
  │  Matrix Multiply │  ~170   │  Compute Bound      │
  │  (N=1024)        │(2N/12)  │  计算效率是关键    │
  ├──────────────────┼─────────┼─────────────────────┤
  │  Convolution 5×5 │  ~0.5   │  Memory Bound       │
  │                  │         │  可通过tiling改善   │
  └──────────────────┴─────────┴─────────────────────┘

  优化策略取决于所在区域：
    Memory Bound → 优化内存访问（合并、SoA、预取）
    Compute Bound → 优化计算（向量化、减少冗余计算）
    Both → 先优化主要瓶颈
```

#### 4.1 内存合并访问模式优化

```
AoS vs SoA 深入分析：

  AoS（Array of Structures）：
  struct Particle { float x, y, z, mass; };  // 16 bytes
  Particle p[N];

  内存布局（warp的32个线程访问x字段）：
  [x0,y0,z0,m0 | x1,y1,z1,m1 | x2,y2,z2,m2 | ...]
   ↑T0(4B)      ↑T1(4B)       ↑T2(4B)
   步长=16B      步长=16B

  → 32个4B请求分散在32×16=512B范围内
  → 需要4个128B事务，但每个事务只有1/4有用
  → 带宽利用率 = 25%

  SoA（Structure of Arrays）：
  float x[N], y[N], z[N], mass[N];

  [x0,x1,x2,...,x31 | x32,x33,...]
   ↑T0 ↑T1 ↑T2    ↑T31
   步长=4B

  → 32个4B请求覆盖连续128B
  → 1个128B事务搞定
  → 带宽利用率 = 100%

  实测性能差异（RTX 4090, N=10^7, 粒子更新）：
    AoS：~50 GB/s 有效带宽（理论1008 GB/s的5%）
    SoA：~700 GB/s 有效带宽（理论的70%）
    差距：14倍！
```

```cpp
// AoS vs SoA性能对比的完整示例

#include <sycl/sycl.hpp>
#include <iostream>
#include <chrono>

// AoS布局
struct ParticleAoS {
    float x, y, z;
    float vx, vy, vz;
    float mass;
    float padding;  // 凑到32B对齐
};

// SoA布局
struct ParticlesSoA {
    float* x;  float* y;  float* z;
    float* vx; float* vy; float* vz;
    float* mass;

    static ParticlesSoA allocate(sycl::queue& q, size_t N) {
        ParticlesSoA p;
        p.x = sycl::malloc_shared<float>(N, q);
        p.y = sycl::malloc_shared<float>(N, q);
        p.z = sycl::malloc_shared<float>(N, q);
        p.vx = sycl::malloc_shared<float>(N, q);
        p.vy = sycl::malloc_shared<float>(N, q);
        p.vz = sycl::malloc_shared<float>(N, q);
        p.mass = sycl::malloc_shared<float>(N, q);
        return p;
    }

    void free(sycl::queue& q) {
        sycl::free(x, q); sycl::free(y, q); sycl::free(z, q);
        sycl::free(vx, q); sycl::free(vy, q); sycl::free(vz, q);
        sycl::free(mass, q);
    }
};

int main() {
    sycl::queue q;
    constexpr size_t N = 1 << 22;  // 4M particles
    constexpr float dt = 0.01f;

    // ===== AoS版本 =====
    ParticleAoS* aos = sycl::malloc_shared<ParticleAoS>(N, q);

    auto start = std::chrono::high_resolution_clock::now();
    q.parallel_for(sycl::range<1>(N), [=](sycl::id<1> i) {
        // Euler积分：只更新位置
        // 问题：每个线程读x,y,z,vx,vy,vz，访问模式不连续
        aos[i].x += aos[i].vx * dt;
        aos[i].y += aos[i].vy * dt;
        aos[i].z += aos[i].vz * dt;
    }).wait();
    auto end = std::chrono::high_resolution_clock::now();
    double aosMs = std::chrono::duration<double, std::milli>(end - start).count();

    // ===== SoA版本 =====
    auto soa = ParticlesSoA::allocate(q, N);
    float *sx=soa.x, *sy=soa.y, *sz=soa.z;
    float *svx=soa.vx, *svy=soa.vy, *svz=soa.vz;

    start = std::chrono::high_resolution_clock::now();
    q.parallel_for(sycl::range<1>(N), [=](sycl::id<1> i) {
        // 每个数组都是连续访问 → 完美合并
        sx[i] += svx[i] * dt;
        sy[i] += svy[i] * dt;
        sz[i] += svz[i] * dt;
    }).wait();
    end = std::chrono::high_resolution_clock::now();
    double soaMs = std::chrono::duration<double, std::milli>(end - start).count();

    // 带宽计算：读6个float数组+写3个 = 9×N×4B
    double totalBytes = 9.0 * N * sizeof(float);
    double aosBW = totalBytes / (aosMs * 1e6);   // GB/s
    double soaBW = totalBytes / (soaMs * 1e6);

    std::cout << "AoS: " << aosMs << " ms, " << aosBW << " GB/s\n";
    std::cout << "SoA: " << soaMs << " ms, " << soaBW << " GB/s\n";
    std::cout << "Speedup: " << aosMs / soaMs << "x\n";

    sycl::free(aos, q);
    soa.free(q);
}
```

#### 4.2 Occupancy优化与资源平衡

```
Occupancy = 活跃warp数 / SM支持的最大warp数

  三个独立限制因素：

  1. 寄存器限制：
     SM寄存器总量 = 65536 (32-bit)
     每warp = 32线程
     → 如果每线程用32寄存器: 一个warp用 32×32 = 1024寄存器
     → SM最多容纳 65536/1024 = 64 warps
     → 但SM最大支持64 warps，所以不是瓶颈

     如果每线程用128寄存器:
     → 一个warp用 32×128 = 4096寄存器
     → SM最多容纳 65536/4096 = 16 warps
     → Occupancy = 16/64 = 25%

  2. Local Memory限制：
     SM共享内存 = 48KB
     → 如果每个work-group用4KB: 最多12个组
     → 每组256线程(8 warps): 最多 12×8 = 96 warps
     → 但SM最大64，不是瓶颈

     如果每个work-group用16KB:
     → 最多3个组
     → 每组256线程(8 warps): 最多 3×8 = 24 warps
     → Occupancy = 24/64 = 37.5%

  3. Work-group大小限制：
     SM最多同时容纳的work-group数也有上限（通常16-32）

  三者取最小值 → 实际occupancy

  关键洞察（Vasily Volkov, "Better Performance at Lower Occupancy"）：
  更高的occupancy ≠ 更好的性能！
  有时低occupancy + 更多寄存器 = 更好的ILP（指令级并行）
```

#### 4.3 分支分歧最小化

```cpp
// 三种处理分支的方式

#include <sycl/sycl.hpp>

void branchPatterns(sycl::queue& q, float* data, size_t N) {
    constexpr size_t WG = 256;

    // ===== 模式1（差）：线程级分歧 =====
    // 同一warp内的线程走不同路径 → 串行化
    q.parallel_for(sycl::range<1>(N), [=](sycl::id<1> i) {
        if (i % 2 == 0) {           // warp内一半走这里
            data[i] = data[i] * 2.0f + 1.0f;
            data[i] = sycl::sqrt(data[i]);
        } else {                     // 另一半走这里
            data[i] = data[i] * 0.5f - 1.0f;
            data[i] = sycl::abs(data[i]);
        }
        // 两个分支串行执行，吞吐量减半！
    }).wait();

    // ===== 模式2（好）：work-group级分支 =====
    // 整个work-group走同一路径 → 无分歧
    q.parallel_for(
        sycl::nd_range<1>(N, WG),
        [=](sycl::nd_item<1> item) {
            size_t gid = item.get_global_id(0);
            if (item.get_group(0) % 2 == 0) {
                // 整个work-group走这里
                data[gid] = data[gid] * 2.0f + 1.0f;
                data[gid] = sycl::sqrt(data[gid]);
            } else {
                // 整个work-group走这里
                data[gid] = data[gid] * 0.5f - 1.0f;
                data[gid] = sycl::abs(data[gid]);
            }
        }
    ).wait();

    // ===== 模式3（最好）：无分支（predication/select）=====
    q.parallel_for(sycl::range<1>(N), [=](sycl::id<1> i) {
        // 编译器可能将 ?: 编译为select指令而非branch
        // 两条路径都计算，最后选结果 → 无分歧
        float path_a = data[i] * 2.0f + 1.0f;
        float path_b = data[i] * 0.5f - 1.0f;
        bool cond = (i % 2 == 0);
        data[i] = cond ? sycl::sqrt(path_a) : sycl::abs(path_b);
    }).wait();
}
```

#### 4.4 Profiling工具实战

```
GPU性能分析工作流：

  ┌─────────────┐
  │ 1. Profile  │ ← 先测量，别猜！
  └──────┬──────┘
         ▼
  ┌─────────────────┐
  │ 2. 识别瓶颈     │
  │  ├─ Compute?    │ → 指标：SM利用率低、FLOP/cycle低
  │  ├─ Memory?     │ → 指标：带宽利用率低、cache miss率高
  │  └─ Latency?    │ → 指标：warp stall多、occupancy低
  └──────┬──────────┘
         ▼
  ┌─────────────────────────┐
  │ 3. 应用针对性优化        │
  │  Compute → 减少指令数    │
  │  Memory → 合并访问/SoA  │
  │  Latency → 提高occupancy │
  └──────┬──────────────────┘
         ▼
  ┌─────────────┐
  │ 4. 重新Profile│ ← 验证优化效果
  └─────────────┘

  工具选择：
  ┌──────────────────┬─────────────────┐
  │  GPU厂商         │  推荐工具        │
  ├──────────────────┼─────────────────┤
  │  Intel           │  VTune, Advisor  │
  │  NVIDIA          │  Nsight Compute  │
  │  AMD             │  rocprof         │
  │  通用            │  SYCL events     │
  └──────────────────┴─────────────────┘
```

```cpp
// 使用SYCL event profiling进行性能分析

#include <sycl/sycl.hpp>
#include <iostream>
#include <vector>

struct KernelProfile {
    std::string name;
    double submit_ms;    // 提交到开始执行的延迟
    double execute_ms;   // 实际执行时间
    double bandwidth_gb; // 有效带宽

    void print() const {
        std::cout << name << ":\n"
                  << "  Submit latency: " << submit_ms << " ms\n"
                  << "  Execution time: " << execute_ms << " ms\n"
                  << "  Bandwidth:      " << bandwidth_gb << " GB/s\n";
    }
};

KernelProfile profileKernel(const std::string& name, sycl::event& e,
                             size_t bytes) {
    auto submit = e.get_profiling_info<
        sycl::info::event_profiling::command_submit>();
    auto start = e.get_profiling_info<
        sycl::info::event_profiling::command_start>();
    auto end = e.get_profiling_info<
        sycl::info::event_profiling::command_end>();

    KernelProfile p;
    p.name = name;
    p.submit_ms = (start - submit) / 1.0e6;
    p.execute_ms = (end - start) / 1.0e6;
    p.bandwidth_gb = (bytes / 1.0e9) / (p.execute_ms / 1.0e3);
    return p;
}

int main() {
    sycl::queue q{sycl::gpu_selector_v,
                  sycl::property::queue::enable_profiling{}};

    constexpr size_t N = 1 << 24;
    float* a = sycl::malloc_device<float>(N, q);
    float* b = sycl::malloc_device<float>(N, q);
    float* c = sycl::malloc_device<float>(N, q);

    // Copy: c = a
    auto eCopy = q.parallel_for(sycl::range<1>(N), [=](sycl::id<1> i) {
        c[i] = a[i];
    });
    eCopy.wait();
    profileKernel("Copy", eCopy, 2*N*sizeof(float)).print();

    // Add: c = a + b
    auto eAdd = q.parallel_for(sycl::range<1>(N), [=](sycl::id<1> i) {
        c[i] = a[i] + b[i];
    });
    eAdd.wait();
    profileKernel("Add", eAdd, 3*N*sizeof(float)).print();

    // Triad: a = b + scalar * c
    float scalar = 3.0f;
    auto eTriad = q.parallel_for(sycl::range<1>(N), [=](sycl::id<1> i) {
        a[i] = b[i] + scalar * c[i];
    });
    eTriad.wait();
    profileKernel("Triad", eTriad, 3*N*sizeof(float)).print();

    sycl::free(a, q); sycl::free(b, q); sycl::free(c, q);
}
```

#### 4.5 矩阵乘法多级优化（案例研究）

```
矩阵乘法优化层次：

  Level 0: Naive（逐元素计算）
  ┌─────────────────────────────┐
  │  每个work-item计算C[i][j]  │
  │  从global memory读A和B     │
  │  O(K)次全局内存读取/输出元素│
  │  ~1-5 GFLOPS               │
  └─────────────────────────────┘
         │ +Local Memory Tiling
         ▼
  Level 1: Tiled（分块+共享内存）
  ┌─────────────────────────────┐
  │  work-group协作加载tile     │
  │  从local memory计算         │
  │  全局读取减少TILE_SIZE倍    │
  │  ~10-50 GFLOPS             │
  └─────────────────────────────┘
         │ +Register Tiling
         ▼
  Level 2: Register-tiled（寄存器级）
  ┌─────────────────────────────┐
  │  每个work-item计算TM×TN块  │
  │  使用寄存器数组累加         │
  │  减少local memory访问       │
  │  ~50-200 GFLOPS            │
  └─────────────────────────────┘
         │ +Vectorized Load
         ▼
  Level 3: Vectorized（向量化加载）
  ┌─────────────────────────────┐
  │  使用float4/float8加载      │
  │  减少load指令数             │
  │  提高内存带宽利用率         │
  │  ~100-500 GFLOPS           │
  └─────────────────────────────┘
         │ → 对比oneMKL/cuBLAS
         ▼
  Vendor Library: ~80-95% peak
```

```cpp
// 寄存器级优化的矩阵乘法
// 每个work-item计算一个TM×TN的小矩阵块

#include <sycl/sycl.hpp>
#include <iostream>
#include <chrono>

template<int TILE, int TM, int TN>
void matmulRegisterTiled(sycl::queue& q,
                          const float* A, const float* B, float* C,
                          size_t M, size_t N, size_t K) {
    // 每个work-group: TILE × TILE 个 work-items
    // 但每个work-item计算 TM × TN 个输出元素
    // 所以每个work-group计算 (TILE*TM) × (TILE*TN) 的输出块
    size_t globalM = ((M + TILE*TM - 1) / (TILE*TM)) * TILE;
    size_t globalN = ((N + TILE*TN - 1) / (TILE*TN)) * TILE;

    q.submit([&](sycl::handler& h) {
        // Local memory for A and B tiles
        sycl::local_accessor<float, 2> tileA({TILE * TM, TILE}, h);
        sycl::local_accessor<float, 2> tileB({TILE, TILE * TN}, h);

        h.parallel_for(
            sycl::nd_range<2>({globalM, globalN}, {TILE, TILE}),
            [=](sycl::nd_item<2> item) {
                size_t lr = item.get_local_id(0);
                size_t lc = item.get_local_id(1);
                size_t gr = item.get_group(0);
                size_t gc = item.get_group(1);

                // 每个work-item的输出起始位置
                size_t rowStart = gr * TILE * TM + lr * TM;
                size_t colStart = gc * TILE * TN + lc * TN;

                // 寄存器数组：累加部分和
                // 这些变量驻留在寄存器中，访问速度最快
                float acc[TM][TN] = {};  // 初始化为0

                size_t numTiles = (K + TILE - 1) / TILE;

                for (size_t t = 0; t < numTiles; ++t) {
                    // 协作加载A的tile (TILE*TM × TILE)
                    for (int m = 0; m < TM; ++m) {
                        size_t aRow = rowStart + m;
                        size_t aCol = t * TILE + lc;
                        tileA[lr * TM + m][lc] =
                            (aRow < M && aCol < K) ? A[aRow * K + aCol] : 0.0f;
                    }

                    // 协作加载B的tile (TILE × TILE*TN)
                    for (int n = 0; n < TN; ++n) {
                        size_t bRow = t * TILE + lr;
                        size_t bCol = colStart + n;
                        tileB[lr][lc * TN + n] =
                            (bRow < K && bCol < N) ? B[bRow * N + bCol] : 0.0f;
                    }

                    sycl::group_barrier(item.get_group());

                    // 从local memory计算，结果累加到寄存器
                    for (int k = 0; k < TILE; ++k) {
                        for (int m = 0; m < TM; ++m) {
                            float aVal = tileA[lr * TM + m][k];
                            for (int n = 0; n < TN; ++n) {
                                acc[m][n] += aVal * tileB[k][lc * TN + n];
                            }
                        }
                    }

                    sycl::group_barrier(item.get_group());
                }

                // 将寄存器中的结果写回global memory
                for (int m = 0; m < TM; ++m) {
                    for (int n = 0; n < TN; ++n) {
                        size_t row = rowStart + m;
                        size_t col = colStart + n;
                        if (row < M && col < N) {
                            C[row * N + col] = acc[m][n];
                        }
                    }
                }
            }
        );
    }).wait();
}

int main() {
    sycl::queue q{sycl::gpu_selector_v};
    constexpr size_t SIZE = 1024;

    float* A = sycl::malloc_shared<float>(SIZE * SIZE, q);
    float* B = sycl::malloc_shared<float>(SIZE * SIZE, q);
    float* C = sycl::malloc_shared<float>(SIZE * SIZE, q);

    // 初始化
    q.parallel_for(sycl::range<1>(SIZE * SIZE), [=](sycl::id<1> i) {
        A[i] = 1.0f;
        B[i] = 1.0f;
    }).wait();

    auto start = std::chrono::high_resolution_clock::now();
    matmulRegisterTiled<16, 4, 4>(q, A, B, C, SIZE, SIZE, SIZE);
    auto end = std::chrono::high_resolution_clock::now();

    double ms = std::chrono::duration<double, std::milli>(end - start).count();
    double gflops = (2.0 * SIZE * SIZE * SIZE) / (ms * 1e6);

    std::cout << "Register-tiled matmul " << SIZE << "×" << SIZE << ":\n";
    std::cout << "  Time: " << ms << " ms\n";
    std::cout << "  Performance: " << gflops << " GFLOPS\n";

    sycl::free(A, q); sycl::free(B, q); sycl::free(C, q);
}
```

#### 4.6 实际优化案例：卷积与前缀和

```cpp
// 优化的2D卷积：使用local memory + halo区域

#include <sycl/sycl.hpp>
#include <iostream>

template<int TILE, int RADIUS>
void conv2dOptimized(sycl::queue& q,
                      const float* input, float* output,
                      const float* filter,
                      size_t width, size_t height) {
    constexpr int FILTER_SIZE = 2 * RADIUS + 1;
    // Tile + halo区域
    constexpr int SHARED_SIZE = TILE + 2 * RADIUS;

    q.submit([&](sycl::handler& h) {
        sycl::local_accessor<float, 2> tile(
            {SHARED_SIZE, SHARED_SIZE}, h);

        h.parallel_for(
            sycl::nd_range<2>(
                {((height + TILE - 1) / TILE) * TILE,
                 ((width + TILE - 1) / TILE) * TILE},
                {TILE, TILE}
            ),
            [=](sycl::nd_item<2> item) {
                int lr = item.get_local_id(0);
                int lc = item.get_local_id(1);
                int gr = item.get_global_id(0);
                int gc = item.get_global_id(1);

                // 协作加载tile + halo到shared memory
                // 每个线程可能需要加载多个元素（边界halo）
                for (int dr = lr; dr < SHARED_SIZE; dr += TILE) {
                    for (int dc = lc; dc < SHARED_SIZE; dc += TILE) {
                        int srcR = static_cast<int>(item.get_group(0)) * TILE
                                   + dr - RADIUS;
                        int srcC = static_cast<int>(item.get_group(1)) * TILE
                                   + dc - RADIUS;
                        // 边界处理：clamp到有效范围
                        srcR = sycl::clamp(srcR, 0, static_cast<int>(height)-1);
                        srcC = sycl::clamp(srcC, 0, static_cast<int>(width)-1);
                        tile[dr][dc] = input[srcR * width + srcC];
                    }
                }

                sycl::group_barrier(item.get_group());

                // 计算卷积（从local memory读取）
                if (gr < height && gc < width) {
                    float sum = 0.0f;
                    for (int fr = 0; fr < FILTER_SIZE; ++fr) {
                        for (int fc = 0; fc < FILTER_SIZE; ++fc) {
                            sum += tile[lr + fr][lc + fc]
                                 * filter[fr * FILTER_SIZE + fc];
                        }
                    }
                    output[gr * width + gc] = sum;
                }
            }
        );
    }).wait();
}
```

#### 4.7 跨平台可移植性与后端特化

```
性能可移植性策略：

  ┌─────────────────────────────────────────────────────────┐
  │  代码结构设计                                            │
  │                                                          │
  │  ┌────────────────────────────────┐                     │
  │  │     Application Layer          │  纯SYCL标准代码     │
  │  │  (算法逻辑、数据管理)          │  100%可移植         │
  │  └──────────────┬─────────────────┘                     │
  │                 │                                        │
  │  ┌──────────────▼─────────────────┐                     │
  │  │     Tuning Layer               │  参数化的kernel     │
  │  │  (TILE_SIZE, WG_SIZE等)        │  运行时根据设备选择 │
  │  └──────────────┬─────────────────┘                     │
  │                 │                                        │
  │  ┌──────────────▼─────────────────┐                     │
  │  │     Device-Specific Layer      │  可选的特化路径     │
  │  │  (vendor intrinsics, if any)   │  通过#ifdef隔离    │
  │  └────────────────────────────────┘                     │
  └─────────────────────────────────────────────────────────┘

  运行时设备检测与参数调优：

  设备查询 → 选择参数 → 设置specialization constant → 执行kernel

  例如：
    Intel GPU → sub_group_size = 16, TILE = 16, WG = {16, 16}
    NVIDIA GPU → sub_group_size = 32, TILE = 32, WG = {32, 8}
    AMD GPU → sub_group_size = 64, TILE = 16, WG = {16, 16}
```

```cpp
// 运行时设备检测和参数自适应

#include <sycl/sycl.hpp>
#include <iostream>
#include <string>

struct KernelParams {
    size_t wgSizeX, wgSizeY;
    size_t tileSize;
    size_t subGroupSize;
};

KernelParams selectParams(const sycl::device& dev) {
    KernelParams params;

    auto sgSizes = dev.get_info<sycl::info::device::sub_group_sizes>();
    auto maxWG = dev.get_info<sycl::info::device::max_work_group_size>();
    auto vendor = dev.get_info<sycl::info::device::vendor>();

    // 选择最大的sub-group size
    params.subGroupSize = sgSizes.back();

    if (vendor.find("Intel") != std::string::npos) {
        // Intel GPU：较小的sub-group，较大的EU数量
        params.wgSizeX = 16;
        params.wgSizeY = 16;
        params.tileSize = 16;
    } else if (vendor.find("NVIDIA") != std::string::npos) {
        // NVIDIA：warp size = 32
        params.wgSizeX = 32;
        params.wgSizeY = 8;
        params.tileSize = 32;
    } else if (vendor.find("AMD") != std::string::npos) {
        // AMD：wavefront size可能是32或64
        params.wgSizeX = 16;
        params.wgSizeY = 16;
        params.tileSize = 16;
    } else {
        // 保守默认值
        params.wgSizeX = 16;
        params.wgSizeY = 16;
        params.tileSize = 16;
    }

    // 确保不超过设备限制
    while (params.wgSizeX * params.wgSizeY > maxWG) {
        params.wgSizeY /= 2;
    }

    std::cout << "Selected params for " << vendor << ":\n"
              << "  WG size: " << params.wgSizeX << "×" << params.wgSizeY << "\n"
              << "  Tile size: " << params.tileSize << "\n"
              << "  Sub-group size: " << params.subGroupSize << "\n";

    return params;
}

int main() {
    sycl::queue q;
    auto params = selectParams(q.get_device());

    // 使用params配置kernel...
    // 可以结合specialization constants实现编译时优化
}
```

#### 4.8 本周练习任务

```
练习1：Roofline模型分析
──────────────────────
目标：构建设备的roofline模型并将不同kernel标注在上面
要求：
1. 测量设备的峰值计算吞吐量(GFLOPS)和峰值内存带宽(GB/s)
2. 绘制ASCII roofline图
3. 实现5种kernel（copy、scale、triad、dotproduct、matmul）
4. 测量每种kernel的arithmetic intensity和achieved performance
5. 判断每个kernel是compute-bound还是memory-bound
验证：
- copy/scale/triad应在memory-bound区域
- matmul应在compute-bound区域
- 各kernel达到对应bound的50%以上

练习2：AoS vs SoA性能对比
────────────────────────
目标：量化证明SoA布局在GPU上的优势
要求：
1. 定义一个粒子结构体（position xyz, velocity xyz, mass, lifetime = 32B）
2. AoS版本和SoA版本
3. 实现同一个粒子更新kernel（Euler积分），测量两种布局的有效带宽
4. 用不同N（10^4到10^8）测试
验证：
- SoA版本带宽利用率应比AoS高2-4x
- N越大差距越明显（排除启动开销）

练习3：分块矩阵乘法寄存器级优化
──────────────────────────────
目标：实现并对比多级优化的矩阵乘法
要求：
1. Naive版本（basic parallel_for）
2. Tiled版本（local memory, TILE=16）
3. Register-tiled版本（每work-item计算4×4子块）
4. 测量N=512,1024,2048时各版本的GFLOPS
验证：
- 最优版本应达到设备峰值的20%+
- 每级优化都有可量化的性能提升
- N=2048时GFLOPS提升至少5x vs naive

练习4：完整性能优化工作流
────────────────────────
目标：对一个给定的未优化SYCL程序进行系统性优化
要求：
1. 给定程序：N-body力计算（全对方式）
2. Step 1: 使用event profiling建立性能基线
3. Step 2: 优化内存访问（SoA转换 + 合并）
4. Step 3: 使用local memory tiling减少重复全局内存访问
5. Step 4: 调整work-group大小优化occupancy
6. 记录每步优化的性能数据
验证：
- 最终版本比初始版本快3-10x
- 每步优化都有可量化的改进
- 物理模拟结果正确（与参考实现对比）
```

#### 4.9 本周知识检验

```
思考题1：一个kernel的occupancy为25%（每个SM只有一个active work-group），
         但性能比occupancy为100%的版本更好。这怎么可能？
        （提示：Vasily Volkov, "Better Performance at Lower Occupancy"）

思考题2：SoA转换在CPU上也有好处，但在GPU上好处更大。解释原因。
         如果一个kernel只访问struct的1个字段（比如8个字段中的1个），
         AoS布局浪费了多少内存带宽？

思考题3：SYCL的backend interop允许获取底层CUDA/Level Zero/OpenCL对象。
         在什么情况下需要使用这个功能？使用后还能保持跨平台可移植性吗？
         如何设计代码结构使backend-specific代码的影响最小化？

思考题4：矩阵乘法的理论arithmetic intensity是 2N^3 / (3×N^2×sizeof(float)) ≈ 2N/12。
         对于N=1024，AI ≈ 170 FLOP/byte，远在roofline的compute-bound区域。
         但实际的naive matmul性能远低于峰值。为什么？
         Tiling如何改变有效的arithmetic intensity？

思考题5：GPU vendor（Intel/NVIDIA/AMD）各自的SYCL实现在编译kernel时
         可能使用不同的优化pass。同一段SYCL代码在不同后端的性能可能差很多。
         作为应用开发者，你能做什么来保证性能可移植性？
         SYCL的specialization constants在这方面有什么作用？

实践题1：
  一个GPU有80个SM，每个SM最多支持32个active warps（1024个线程）。
  你的kernel每个work-item使用48个寄存器，每个SM有65536个寄存器。
  work-group大小设置为256（8个warps）。
  (a) 每个work-group需要多少寄存器？
  (b) 每个SM最多容纳多少个work-group？
  (c) 实际active warps是多少？occupancy是多少？
  (d) 如果减少到32个寄存器/work-item，occupancy变成多少？
  (e) 哪个配置可能性能更好？为什么？

实践题2：
  2D卷积：5×5 filter，输入图像 1024×1024 float。
  (a) 每个输出像素需要25次乘加 = 50 FLOP
  (b) 朴素实现：每个像素读取25个输入值 = 100 bytes
      Arithmetic intensity = 50/100 = 0.5 FLOP/byte
  (c) 使用local memory tiling（tile = 16×16 + 2-pixel halo = 20×20）：
      计算每个tile的数据重用率
  (d) 改用separable filter（两次1D pass, 5-tap each）：
      总FLOP = 2 × 5 × 2 = 20 per pixel
      Arithmetic intensity如何变化？哪种方法更快？
```

---

## 源码阅读任务

### 必读项目

1. **SYCL标准库实现** (hipSYCL/AdaptiveCpp)
   - https://github.com/AdaptiveCpp/AdaptiveCpp
   - 重点：runtime和编译器实现
   - 阅读时间：12小时

2. **oneDNN** (https://github.com/oneapi-src/oneDNN)
   - 重点：SYCL后端实现
   - 学习目标：理解高性能计算库设计
   - 阅读时间：8小时

3. **SYCL-BLAS** (https://github.com/codeplaysoftware/sycl-blas)
   - 学习目标：理解BLAS库的SYCL实现
   - 阅读时间：6小时

---

## 实践项目：SYCL矩阵运算库

### 项目概述
使用SYCL实现高性能矩阵运算库，包括向量运算、矩阵乘法和基本线性代数操作。通过从朴素实现到多级优化的递进过程，实践本月所学的所有概念。

### 项目目录结构

```
sycl-math-lib/
├── CMakeLists.txt              # 构建配置
├── sycl_utils/
│   └── device.hpp              # 设备工具（选择、信息、计时）
├── sycl_math/
│   ├── vector_ops.hpp          # 向量运算（add, mul, dot, axpy, norm）
│   ├── matrix_ops.hpp          # 矩阵运算（matmul naive/tiled, transpose）
│   └── advanced_ops.hpp        # 高级操作（reduction, softmax, relu, batchnorm）
└── main.cpp                    # 基准测试与演示
```

### CMakeLists.txt 示例

```cmake
cmake_minimum_required(VERSION 3.20)
project(sycl-math-lib LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# DPC++ (Intel oneAPI) 编译配置
# 使用 icpx -fsycl 编译
if(CMAKE_CXX_COMPILER_ID MATCHES "IntelLLVM" OR
   CMAKE_CXX_COMPILER MATCHES "icpx")
    set(SYCL_FLAGS "-fsycl")
    # 可选：指定目标设备
    # set(SYCL_FLAGS "${SYCL_FLAGS} -fsycl-targets=nvptx64-nvidia-cuda")
    # set(SYCL_FLAGS "${SYCL_FLAGS} -fsycl-targets=amdgcn-amd-amdhsa")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${SYCL_FLAGS}")
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${SYCL_FLAGS}")
endif()

# AdaptiveCpp (hipSYCL) 编译配置
# find_package(AdaptiveCpp REQUIRED)

add_executable(sycl_math_demo main.cpp)
target_include_directories(sycl_math_demo PRIVATE ${CMAKE_SOURCE_DIR})

# 如果使用AdaptiveCpp:
# add_sycl_to_target(TARGET sycl_math_demo SOURCES main.cpp)
```

### 完整代码实现

#### 1. SYCL工具库 (sycl_utils/device.hpp)

```cpp
#pragma once

#include <sycl/sycl.hpp>
#include <iostream>
#include <string>
#include <vector>

namespace sycl_utils {

// 设备信息打印
void printDeviceInfo(const sycl::device& device) {
    std::cout << "Device: "
              << device.get_info<sycl::info::device::name>() << "\n";
    std::cout << "  Vendor: "
              << device.get_info<sycl::info::device::vendor>() << "\n";
    std::cout << "  Max compute units: "
              << device.get_info<sycl::info::device::max_compute_units>() << "\n";
    std::cout << "  Max work group size: "
              << device.get_info<sycl::info::device::max_work_group_size>() << "\n";
    std::cout << "  Global memory: "
              << device.get_info<sycl::info::device::global_mem_size>() / (1024*1024)
              << " MB\n";
    std::cout << "  Local memory: "
              << device.get_info<sycl::info::device::local_mem_size>() / 1024
              << " KB\n";
}

// 列出所有设备
void listAllDevices() {
    auto platforms = sycl::platform::get_platforms();

    std::cout << "Available SYCL Devices:\n";
    std::cout << "=======================\n\n";

    for (const auto& platform : platforms) {
        std::cout << "Platform: "
                  << platform.get_info<sycl::info::platform::name>() << "\n";

        for (const auto& device : platform.get_devices()) {
            std::cout << "  ";
            printDeviceInfo(device);
            std::cout << "\n";
        }
    }
}

// 选择最佳设备
sycl::device selectBestDevice() {
    try {
        return sycl::device{sycl::gpu_selector_v};
    } catch (...) {
        std::cout << "No GPU found, falling back to CPU\n";
        return sycl::device{sycl::cpu_selector_v};
    }
}

// 异常处理
void handleException(const sycl::exception& e) {
    std::cerr << "SYCL exception: " << e.what() << "\n";
    if (e.code().value()) {
        std::cerr << "  Error code: " << e.code() << "\n";
    }
}

// 异步错误处理器
auto asyncHandler = [](sycl::exception_list exceptions) {
    for (const auto& e : exceptions) {
        try {
            std::rethrow_exception(e);
        } catch (const sycl::exception& ex) {
            handleException(ex);
        }
    }
};

// 创建带错误处理的队列
sycl::queue createQueue(const sycl::device& device = selectBestDevice()) {
    return sycl::queue{device, asyncHandler};
}

// 计时器
class Timer {
    std::chrono::high_resolution_clock::time_point start_;

public:
    Timer() : start_(std::chrono::high_resolution_clock::now()) {}

    double elapsed() const {
        auto end = std::chrono::high_resolution_clock::now();
        return std::chrono::duration<double, std::milli>(end - start_).count();
    }

    void reset() {
        start_ = std::chrono::high_resolution_clock::now();
    }
};

} // namespace sycl_utils
```

#### 2. 向量运算 (sycl_math/vector_ops.hpp)

```cpp
#pragma once

#include <sycl/sycl.hpp>
#include <vector>
#include <cmath>

namespace sycl_math {

// 向量加法
template<typename T>
void vectorAdd(sycl::queue& q,
               const T* a, const T* b, T* c,
               size_t n) {
    q.parallel_for(sycl::range<1>(n), [=](sycl::id<1> i) {
        c[i] = a[i] + b[i];
    }).wait();
}

// 向量乘法（逐元素）
template<typename T>
void vectorMul(sycl::queue& q,
               const T* a, const T* b, T* c,
               size_t n) {
    q.parallel_for(sycl::range<1>(n), [=](sycl::id<1> i) {
        c[i] = a[i] * b[i];
    }).wait();
}

// 标量乘法
template<typename T>
void vectorScale(sycl::queue& q,
                 const T* a, T scalar, T* c,
                 size_t n) {
    q.parallel_for(sycl::range<1>(n), [=](sycl::id<1> i) {
        c[i] = a[i] * scalar;
    }).wait();
}

// 点积（使用归约）
template<typename T>
T dotProduct(sycl::queue& q, const T* a, const T* b, size_t n) {
    constexpr size_t LOCAL_SIZE = 256;
    size_t numGroups = (n + LOCAL_SIZE - 1) / LOCAL_SIZE;

    // 部分和
    T* partialSums = sycl::malloc_device<T>(numGroups, q);

    q.submit([&](sycl::handler& h) {
        sycl::local_accessor<T, 1> localMem(sycl::range<1>(LOCAL_SIZE), h);

        h.parallel_for(
            sycl::nd_range<1>(numGroups * LOCAL_SIZE, LOCAL_SIZE),
            [=](sycl::nd_item<1> item) {
                size_t globalId = item.get_global_id(0);
                size_t localId = item.get_local_id(0);
                size_t groupId = item.get_group(0);

                // 加载并计算局部乘积
                T value = (globalId < n) ? a[globalId] * b[globalId] : T(0);
                localMem[localId] = value;

                item.barrier(sycl::access::fence_space::local_space);

                // 归约
                for (size_t stride = LOCAL_SIZE / 2; stride > 0; stride /= 2) {
                    if (localId < stride) {
                        localMem[localId] += localMem[localId + stride];
                    }
                    item.barrier(sycl::access::fence_space::local_space);
                }

                if (localId == 0) {
                    partialSums[groupId] = localMem[0];
                }
            }
        );
    }).wait();

    // 将部分和复制回主机
    std::vector<T> hostPartialSums(numGroups);
    q.memcpy(hostPartialSums.data(), partialSums, numGroups * sizeof(T)).wait();

    sycl::free(partialSums, q);

    // 最终求和
    T result = 0;
    for (size_t i = 0; i < numGroups; ++i) {
        result += hostPartialSums[i];
    }

    return result;
}

// 向量范数
template<typename T>
T vectorNorm(sycl::queue& q, const T* a, size_t n) {
    return std::sqrt(dotProduct(q, a, a, n));
}

// AXPY: y = alpha * x + y
template<typename T>
void axpy(sycl::queue& q,
          T alpha, const T* x, T* y,
          size_t n) {
    q.parallel_for(sycl::range<1>(n), [=](sycl::id<1> i) {
        y[i] = alpha * x[i] + y[i];
    }).wait();
}

// 向量归一化
template<typename T>
void vectorNormalize(sycl::queue& q, T* a, size_t n) {
    T norm = vectorNorm(q, a, n);
    if (norm > 0) {
        vectorScale(q, a, T(1) / norm, a, n);
    }
}

} // namespace sycl_math
```

#### 3. 矩阵运算 (sycl_math/matrix_ops.hpp)

```cpp
#pragma once

#include <sycl/sycl.hpp>
#include <vector>
#include <stdexcept>

namespace sycl_math {

// 矩阵类（行主序存储）
template<typename T>
class Matrix {
private:
    size_t rows_, cols_;
    T* data_;
    sycl::queue* queue_;
    bool ownsData_;

public:
    Matrix(sycl::queue& q, size_t rows, size_t cols)
        : rows_(rows), cols_(cols), queue_(&q), ownsData_(true) {
        data_ = sycl::malloc_shared<T>(rows * cols, q);
    }

    Matrix(sycl::queue& q, size_t rows, size_t cols, T* externalData)
        : rows_(rows), cols_(cols), data_(externalData),
          queue_(&q), ownsData_(false) {}

    ~Matrix() {
        if (ownsData_ && data_) {
            sycl::free(data_, *queue_);
        }
    }

    // 禁止拷贝
    Matrix(const Matrix&) = delete;
    Matrix& operator=(const Matrix&) = delete;

    // 允许移动
    Matrix(Matrix&& other) noexcept
        : rows_(other.rows_), cols_(other.cols_),
          data_(other.data_), queue_(other.queue_),
          ownsData_(other.ownsData_) {
        other.data_ = nullptr;
        other.ownsData_ = false;
    }

    size_t rows() const { return rows_; }
    size_t cols() const { return cols_; }
    T* data() { return data_; }
    const T* data() const { return data_; }
    sycl::queue& queue() { return *queue_; }

    // 元素访问（主机端）
    T& operator()(size_t i, size_t j) {
        return data_[i * cols_ + j];
    }

    const T& operator()(size_t i, size_t j) const {
        return data_[i * cols_ + j];
    }

    // 填充
    void fill(T value) {
        queue_->parallel_for(sycl::range<1>(rows_ * cols_), [=, d = data_](sycl::id<1> i) {
            d[i] = value;
        }).wait();
    }

    // 单位矩阵
    void identity() {
        fill(T(0));
        size_t n = std::min(rows_, cols_);
        T* d = data_;
        size_t c = cols_;
        queue_->parallel_for(sycl::range<1>(n), [=](sycl::id<1> i) {
            d[i * c + i] = T(1);
        }).wait();
    }
};

// 朴素矩阵乘法
template<typename T>
void matmulNaive(sycl::queue& q,
                 const Matrix<T>& A,
                 const Matrix<T>& B,
                 Matrix<T>& C) {
    if (A.cols() != B.rows()) {
        throw std::invalid_argument("Matrix dimensions mismatch");
    }

    size_t M = A.rows();
    size_t N = B.cols();
    size_t K = A.cols();

    const T* a = A.data();
    const T* b = B.data();
    T* c = C.data();

    q.parallel_for(sycl::range<2>(M, N), [=](sycl::id<2> id) {
        size_t row = id[0];
        size_t col = id[1];

        T sum = 0;
        for (size_t k = 0; k < K; ++k) {
            sum += a[row * K + k] * b[k * N + col];
        }
        c[row * N + col] = sum;
    }).wait();
}

// 分块矩阵乘法（优化版本）
template<typename T, int TILE_SIZE = 16>
void matmulTiled(sycl::queue& q,
                 const Matrix<T>& A,
                 const Matrix<T>& B,
                 Matrix<T>& C) {
    if (A.cols() != B.rows()) {
        throw std::invalid_argument("Matrix dimensions mismatch");
    }

    size_t M = A.rows();
    size_t N = B.cols();
    size_t K = A.cols();

    const T* a = A.data();
    const T* b = B.data();
    T* c = C.data();

    // 全局范围需要对齐到TILE_SIZE
    size_t globalM = ((M + TILE_SIZE - 1) / TILE_SIZE) * TILE_SIZE;
    size_t globalN = ((N + TILE_SIZE - 1) / TILE_SIZE) * TILE_SIZE;

    q.submit([&](sycl::handler& h) {
        // Local memory for tiles
        sycl::local_accessor<T, 2> tileA(
            sycl::range<2>(TILE_SIZE, TILE_SIZE), h);
        sycl::local_accessor<T, 2> tileB(
            sycl::range<2>(TILE_SIZE, TILE_SIZE), h);

        h.parallel_for(
            sycl::nd_range<2>(
                sycl::range<2>(globalM, globalN),
                sycl::range<2>(TILE_SIZE, TILE_SIZE)
            ),
            [=](sycl::nd_item<2> item) {
                size_t row = item.get_global_id(0);
                size_t col = item.get_global_id(1);
                size_t localRow = item.get_local_id(0);
                size_t localCol = item.get_local_id(1);

                T sum = 0;

                // 遍历所有tile
                size_t numTiles = (K + TILE_SIZE - 1) / TILE_SIZE;

                for (size_t t = 0; t < numTiles; ++t) {
                    // 协作加载A的tile
                    size_t aRow = row;
                    size_t aCol = t * TILE_SIZE + localCol;
                    if (aRow < M && aCol < K) {
                        tileA[localRow][localCol] = a[aRow * K + aCol];
                    } else {
                        tileA[localRow][localCol] = 0;
                    }

                    // 协作加载B的tile
                    size_t bRow = t * TILE_SIZE + localRow;
                    size_t bCol = col;
                    if (bRow < K && bCol < N) {
                        tileB[localRow][localCol] = b[bRow * N + bCol];
                    } else {
                        tileB[localRow][localCol] = 0;
                    }

                    // 等待所有线程完成加载
                    item.barrier(sycl::access::fence_space::local_space);

                    // 计算部分积
                    for (int k = 0; k < TILE_SIZE; ++k) {
                        sum += tileA[localRow][k] * tileB[k][localCol];
                    }

                    // 等待所有计算完成再加载下一个tile
                    item.barrier(sycl::access::fence_space::local_space);
                }

                // 写入结果
                if (row < M && col < N) {
                    c[row * N + col] = sum;
                }
            }
        );
    }).wait();
}

// 矩阵转置
template<typename T>
void transpose(sycl::queue& q,
               const Matrix<T>& A,
               Matrix<T>& B) {
    size_t M = A.rows();
    size_t N = A.cols();

    const T* a = A.data();
    T* b = B.data();

    q.parallel_for(sycl::range<2>(M, N), [=](sycl::id<2> id) {
        size_t i = id[0];
        size_t j = id[1];
        b[j * M + i] = a[i * N + j];
    }).wait();
}

// 矩阵加法
template<typename T>
void matrixAdd(sycl::queue& q,
               const Matrix<T>& A,
               const Matrix<T>& B,
               Matrix<T>& C) {
    size_t M = A.rows();
    size_t N = A.cols();

    const T* a = A.data();
    const T* b = B.data();
    T* c = C.data();

    q.parallel_for(sycl::range<1>(M * N), [=](sycl::id<1> i) {
        c[i] = a[i] + b[i];
    }).wait();
}

// 矩阵标量乘法
template<typename T>
void matrixScale(sycl::queue& q,
                 const Matrix<T>& A,
                 T scalar,
                 Matrix<T>& C) {
    size_t M = A.rows();
    size_t N = A.cols();

    const T* a = A.data();
    T* c = C.data();

    q.parallel_for(sycl::range<1>(M * N), [=](sycl::id<1> i) {
        c[i] = a[i] * scalar;
    }).wait();
}

} // namespace sycl_math
```

#### 4. 高级操作 (sycl_math/advanced_ops.hpp)

```cpp
#pragma once

#include "matrix_ops.hpp"
#include <limits>

namespace sycl_math {

// 归约操作：求和
template<typename T>
T reduce_sum(sycl::queue& q, const T* data, size_t n) {
    constexpr size_t LOCAL_SIZE = 256;
    size_t numGroups = (n + LOCAL_SIZE - 1) / LOCAL_SIZE;

    T* partialSums = sycl::malloc_device<T>(numGroups, q);

    q.submit([&](sycl::handler& h) {
        sycl::local_accessor<T, 1> localMem(LOCAL_SIZE, h);

        h.parallel_for(
            sycl::nd_range<1>(numGroups * LOCAL_SIZE, LOCAL_SIZE),
            [=](sycl::nd_item<1> item) {
                size_t globalId = item.get_global_id(0);
                size_t localId = item.get_local_id(0);
                size_t groupId = item.get_group(0);

                localMem[localId] = (globalId < n) ? data[globalId] : T(0);
                item.barrier(sycl::access::fence_space::local_space);

                for (size_t stride = LOCAL_SIZE / 2; stride > 0; stride /= 2) {
                    if (localId < stride) {
                        localMem[localId] += localMem[localId + stride];
                    }
                    item.barrier(sycl::access::fence_space::local_space);
                }

                if (localId == 0) {
                    partialSums[groupId] = localMem[0];
                }
            }
        );
    }).wait();

    std::vector<T> hostSums(numGroups);
    q.memcpy(hostSums.data(), partialSums, numGroups * sizeof(T)).wait();
    sycl::free(partialSums, q);

    T result = 0;
    for (size_t i = 0; i < numGroups; ++i) {
        result += hostSums[i];
    }
    return result;
}

// 归约操作：最大值
template<typename T>
T reduce_max(sycl::queue& q, const T* data, size_t n) {
    constexpr size_t LOCAL_SIZE = 256;
    size_t numGroups = (n + LOCAL_SIZE - 1) / LOCAL_SIZE;

    T* partialMax = sycl::malloc_device<T>(numGroups, q);

    q.submit([&](sycl::handler& h) {
        sycl::local_accessor<T, 1> localMem(LOCAL_SIZE, h);

        h.parallel_for(
            sycl::nd_range<1>(numGroups * LOCAL_SIZE, LOCAL_SIZE),
            [=](sycl::nd_item<1> item) {
                size_t globalId = item.get_global_id(0);
                size_t localId = item.get_local_id(0);
                size_t groupId = item.get_group(0);

                localMem[localId] = (globalId < n) ?
                    data[globalId] : std::numeric_limits<T>::lowest();
                item.barrier(sycl::access::fence_space::local_space);

                for (size_t stride = LOCAL_SIZE / 2; stride > 0; stride /= 2) {
                    if (localId < stride) {
                        localMem[localId] = sycl::max(
                            localMem[localId], localMem[localId + stride]);
                    }
                    item.barrier(sycl::access::fence_space::local_space);
                }

                if (localId == 0) {
                    partialMax[groupId] = localMem[0];
                }
            }
        );
    }).wait();

    std::vector<T> hostMax(numGroups);
    q.memcpy(hostMax.data(), partialMax, numGroups * sizeof(T)).wait();
    sycl::free(partialMax, q);

    T result = std::numeric_limits<T>::lowest();
    for (size_t i = 0; i < numGroups; ++i) {
        result = std::max(result, hostMax[i]);
    }
    return result;
}

// Softmax (行级别)
template<typename T>
void softmax(sycl::queue& q, Matrix<T>& A) {
    size_t M = A.rows();
    size_t N = A.cols();
    T* data = A.data();

    // 对每行计算softmax
    q.submit([&](sycl::handler& h) {
        h.parallel_for(sycl::range<1>(M), [=](sycl::id<1> row) {
            // 找最大值（数值稳定性）
            T maxVal = data[row * N];
            for (size_t j = 1; j < N; ++j) {
                maxVal = sycl::max(maxVal, data[row * N + j]);
            }

            // 计算exp和sum
            T sum = 0;
            for (size_t j = 0; j < N; ++j) {
                data[row * N + j] = sycl::exp(data[row * N + j] - maxVal);
                sum += data[row * N + j];
            }

            // 归一化
            for (size_t j = 0; j < N; ++j) {
                data[row * N + j] /= sum;
            }
        });
    }).wait();
}

// ReLU激活函数
template<typename T>
void relu(sycl::queue& q, T* data, size_t n) {
    q.parallel_for(sycl::range<1>(n), [=](sycl::id<1> i) {
        data[i] = sycl::max(data[i], T(0));
    }).wait();
}

// Sigmoid激活函数
template<typename T>
void sigmoid(sycl::queue& q, T* data, size_t n) {
    q.parallel_for(sycl::range<1>(n), [=](sycl::id<1> i) {
        data[i] = T(1) / (T(1) + sycl::exp(-data[i]));
    }).wait();
}

// 批量归一化（简化版本）
template<typename T>
void batchNorm(sycl::queue& q,
               T* data, size_t batchSize, size_t features,
               const T* gamma, const T* beta,
               T epsilon = 1e-5) {
    // 计算每个特征的均值和方差
    T* mean = sycl::malloc_shared<T>(features, q);
    T* variance = sycl::malloc_shared<T>(features, q);

    // 计算均值
    q.parallel_for(sycl::range<1>(features), [=](sycl::id<1> f) {
        T sum = 0;
        for (size_t b = 0; b < batchSize; ++b) {
            sum += data[b * features + f];
        }
        mean[f] = sum / batchSize;
    }).wait();

    // 计算方差
    q.parallel_for(sycl::range<1>(features), [=](sycl::id<1> f) {
        T sum = 0;
        for (size_t b = 0; b < batchSize; ++b) {
            T diff = data[b * features + f] - mean[f];
            sum += diff * diff;
        }
        variance[f] = sum / batchSize;
    }).wait();

    // 归一化
    q.parallel_for(sycl::range<2>(batchSize, features), [=](sycl::id<2> id) {
        size_t b = id[0];
        size_t f = id[1];
        T normalized = (data[b * features + f] - mean[f]) /
                       sycl::sqrt(variance[f] + epsilon);
        data[b * features + f] = gamma[f] * normalized + beta[f];
    }).wait();

    sycl::free(mean, q);
    sycl::free(variance, q);
}

} // namespace sycl_math
```

#### 5. 基准测试 (main.cpp)

```cpp
#include "sycl_utils/device.hpp"
#include "sycl_math/matrix_ops.hpp"
#include "sycl_math/vector_ops.hpp"
#include "sycl_math/advanced_ops.hpp"
#include <iostream>
#include <random>

using namespace sycl_utils;
using namespace sycl_math;

void benchmarkMatmul() {
    std::cout << "\n=== Matrix Multiplication Benchmark ===\n\n";

    auto q = createQueue();
    printDeviceInfo(q.get_device());
    std::cout << "\n";

    constexpr size_t SIZES[] = {256, 512, 1024, 2048};

    std::mt19937 rng(42);
    std::uniform_real_distribution<float> dist(0.0f, 1.0f);

    for (size_t N : SIZES) {
        Matrix<float> A(q, N, N);
        Matrix<float> B(q, N, N);
        Matrix<float> C(q, N, N);

        // 初始化
        for (size_t i = 0; i < N * N; ++i) {
            A.data()[i] = dist(rng);
            B.data()[i] = dist(rng);
        }

        // 预热
        matmulTiled<float, 16>(q, A, B, C);

        // 基准测试：朴素实现
        Timer timer;
        for (int i = 0; i < 3; ++i) {
            matmulNaive(q, A, B, C);
        }
        double naiveTime = timer.elapsed() / 3.0;

        // 基准测试：分块实现
        timer.reset();
        for (int i = 0; i < 3; ++i) {
            matmulTiled<float, 16>(q, A, B, C);
        }
        double tiledTime = timer.elapsed() / 3.0;

        // 计算GFLOPS
        double flops = 2.0 * N * N * N;  // 乘加算两次
        double naiveGflops = flops / (naiveTime * 1e6);
        double tiledGflops = flops / (tiledTime * 1e6);

        std::cout << "Matrix size: " << N << "x" << N << "\n";
        std::cout << "  Naive:  " << naiveTime << " ms, "
                  << naiveGflops << " GFLOPS\n";
        std::cout << "  Tiled:  " << tiledTime << " ms, "
                  << tiledGflops << " GFLOPS\n";
        std::cout << "  Speedup: " << naiveTime / tiledTime << "x\n\n";
    }
}

void benchmarkVectorOps() {
    std::cout << "\n=== Vector Operations Benchmark ===\n\n";

    auto q = createQueue();

    constexpr size_t SIZES[] = {1000000, 10000000, 100000000};

    for (size_t N : SIZES) {
        float* a = sycl::malloc_shared<float>(N, q);
        float* b = sycl::malloc_shared<float>(N, q);
        float* c = sycl::malloc_shared<float>(N, q);

        // 初始化
        q.parallel_for(sycl::range<1>(N), [=](sycl::id<1> i) {
            a[i] = 1.0f;
            b[i] = 2.0f;
        }).wait();

        // Vector Add
        Timer timer;
        vectorAdd(q, a, b, c, N);
        double addTime = timer.elapsed();

        // Dot Product
        timer.reset();
        float dot = dotProduct(q, a, b, N);
        double dotTime = timer.elapsed();

        // Bandwidth calculation
        double addBandwidth = (3.0 * N * sizeof(float)) / (addTime * 1e6);  // GB/s
        double dotBandwidth = (2.0 * N * sizeof(float)) / (dotTime * 1e6);

        std::cout << "Vector size: " << N << "\n";
        std::cout << "  Add: " << addTime << " ms, "
                  << addBandwidth << " GB/s\n";
        std::cout << "  Dot: " << dotTime << " ms, "
                  << dotBandwidth << " GB/s, result = " << dot << "\n\n";

        sycl::free(a, q);
        sycl::free(b, q);
        sycl::free(c, q);
    }
}

void demoNeuralNetworkLayer() {
    std::cout << "\n=== Neural Network Layer Demo ===\n\n";

    auto q = createQueue();

    constexpr size_t BATCH = 64;
    constexpr size_t INPUT = 784;   // 28x28 MNIST
    constexpr size_t HIDDEN = 256;
    constexpr size_t OUTPUT = 10;

    // 分配权重和偏置
    Matrix<float> W1(q, INPUT, HIDDEN);
    Matrix<float> W2(q, HIDDEN, OUTPUT);
    float* b1 = sycl::malloc_shared<float>(HIDDEN, q);
    float* b2 = sycl::malloc_shared<float>(OUTPUT, q);

    // 输入和中间结果
    Matrix<float> X(q, BATCH, INPUT);
    Matrix<float> H(q, BATCH, HIDDEN);
    Matrix<float> Y(q, BATCH, OUTPUT);

    // 初始化（随机）
    std::mt19937 rng(42);
    std::uniform_real_distribution<float> dist(-0.1f, 0.1f);

    for (size_t i = 0; i < INPUT * HIDDEN; ++i) W1.data()[i] = dist(rng);
    for (size_t i = 0; i < HIDDEN * OUTPUT; ++i) W2.data()[i] = dist(rng);
    for (size_t i = 0; i < HIDDEN; ++i) b1[i] = 0.0f;
    for (size_t i = 0; i < OUTPUT; ++i) b2[i] = 0.0f;

    // 模拟输入
    for (size_t i = 0; i < BATCH * INPUT; ++i) {
        X.data()[i] = dist(rng);
    }

    Timer timer;

    // 前向传播
    // H = X @ W1
    matmulTiled<float, 16>(q, X, W1, H);

    // H += b1 (广播)
    float* h = H.data();
    q.parallel_for(sycl::range<2>(BATCH, HIDDEN), [=](sycl::id<2> id) {
        h[id[0] * HIDDEN + id[1]] += b1[id[1]];
    }).wait();

    // ReLU
    relu(q, H.data(), BATCH * HIDDEN);

    // Y = H @ W2
    matmulTiled<float, 16>(q, H, W2, Y);

    // Y += b2
    float* y = Y.data();
    q.parallel_for(sycl::range<2>(BATCH, OUTPUT), [=](sycl::id<2> id) {
        y[id[0] * OUTPUT + id[1]] += b2[id[1]];
    }).wait();

    // Softmax
    softmax(q, Y);

    double elapsed = timer.elapsed();

    std::cout << "Two-layer neural network forward pass:\n";
    std::cout << "  Batch size: " << BATCH << "\n";
    std::cout << "  Architecture: " << INPUT << " -> " << HIDDEN
              << " -> " << OUTPUT << "\n";
    std::cout << "  Time: " << elapsed << " ms\n";
    std::cout << "  Throughput: " << (BATCH * 1000.0 / elapsed)
              << " samples/sec\n";

    // 打印一些输出
    std::cout << "\n  Sample output (first 3 classes of first sample):\n    ";
    for (int i = 0; i < 3; ++i) {
        std::cout << Y(0, i) << " ";
    }
    std::cout << "...\n";

    sycl::free(b1, q);
    sycl::free(b2, q);
}

int main() {
    try {
        std::cout << "SYCL Math Library Demo\n";
        std::cout << "======================\n";

        listAllDevices();

        benchmarkVectorOps();
        benchmarkMatmul();
        demoNeuralNetworkLayer();

    } catch (const sycl::exception& e) {
        handleException(e);
        return 1;
    }

    return 0;
}
```

---

## 检验标准

### 知识检验
1. [ ] 能够详细解释CPU和GPU的微架构差异，包括核心数量、缓存层次、内存带宽的量化对比
2. [ ] 理解SYCL的平台模型、执行模型和内存模型，能画出完整的概念层次图
3. [ ] 精通Buffer/Accessor和USM两种编程模型，能分析各自的适用场景和性能权衡
4. [ ] 理解工作组、子组和工作项的层次结构，能计算ID映射关系
5. [ ] 掌握Amdahl定律和Gustafson定律，能为实际问题计算理论加速比上限
6. [ ] 能够运用roofline模型分析SYCL程序是compute-bound还是memory-bound
7. [ ] 理解内存合并访问、bank conflict、分支分歧等GPU性能陷阱
8. [ ] 能够解释SYCL 2020的group算法和reduction API的优势及其硬件映射

### 实践检验
1. [ ] 完成SYCL环境搭建（DPC++或AdaptiveCpp至少一种）
2. [ ] 实现完整的向量运算库（add, mul, dot, axpy, norm, normalize）
3. [ ] 实现朴素和分块矩阵乘法，分块版本获得2x+加速
4. [ ] 实现寄存器级优化的矩阵乘法，达到设备峰值的20%+
5. [ ] 归约操作正确实现（手动版本和SYCL 2020 reduction两种）
6. [ ] 完成AoS vs SoA性能对比实验，SoA版本带宽提升2x+
7. [ ] 实现并行prefix sum（支持超出单work-group的大小）
8. [ ] 完成roofline模型分析，正确标注5种以上kernel
9. [ ] 使用event profiling测量并报告kernel执行时间
10. [ ] 在至少一种GPU上运行全部代码并获得相对CPU的性能提升

### 代码质量
1. [ ] 正确处理所有内存分配和释放（无内存泄漏）
2. [ ] 同步和异步异常处理完善
3. [ ] 代码可在DPC++和AdaptiveCpp上编译（或至少一种+CPU fallback）
4. [ ] 有完整的基准测试套件，输出格式化的性能报告
5. [ ] 使用RAII或智能指针管理USM分配（或在清理路径中正确释放）
6. [ ] Kernel代码中无未定义行为（越界访问、数据竞争）

---

## 输出物清单

1. **学习笔记**
   - [ ] 异构计算基础与CPU/GPU架构对比笔记
   - [ ] SYCL编程模型总结（Buffer/Accessor vs USM决策指南）
   - [ ] 并行执行模型与工作分解层次笔记
   - [ ] 性能优化技术文档（合并访问、occupancy、roofline）

2. **代码产出**
   - [ ] SYCL矩阵运算库（完整项目，含CMakeLists.txt）
   - [ ] 基准测试套件（向量、矩阵、归约的性能报告）
   - [ ] 示例应用（神经网络前向传播演示）

3. **练习完成**
   - [ ] 17道练习任务全部完成
   - [ ] 28道知识检验问题全部回答（含计算题）

4. **分析报告**
   - [ ] Roofline性能分析报告（含设备参数和kernel标注）
   - [ ] AoS vs SoA性能对比分析
   - [ ] 矩阵乘法多级优化性能递进分析

---

## 时间分配表

| 周次 | 理论学习 | 源码阅读 | 项目实践 | 练习与检验 | 总计 |
|------|----------|----------|----------|-----------|------|
| Week 1 | 14h | 6h | 8h | 7h | 35h |
| Week 2 | 12h | 6h | 10h | 7h | 35h |
| Week 3 | 10h | 5h | 13h | 7h | 35h |
| Week 4 | 8h | 5h | 15h | 7h | 35h |
| **总计** | **44h** | **22h** | **46h** | **28h** | **140h** |

---

## 下月预告

**Month 55: GPU编程基础**

下个月将深入GPU编程，从SYCL的可移植抽象层下沉到vendor-specific的GPU编程模型：
- CUDA/HIP编程模型——与SYCL的对应关系
- GPU内存层次详解——寄存器文件、共享内存、L1/L2缓存的硬件实现
- Warp/Wavefront执行——深入理解SIMT调度、寄存器分配、延迟隐藏
- 高级优化技术——warp shuffle、cooperative groups、dynamic parallelism
- 实践项目：实现高性能2D卷积（im2col + GEMM vs direct convolution）

建议提前：
1. 如果有NVIDIA GPU，安装CUDA工具包（cuda-toolkit-12.x）
2. 回顾本月学到的occupancy计算和roofline分析方法
3. 复习并行算法基础（特别是scan和reduction的多种实现策略）
