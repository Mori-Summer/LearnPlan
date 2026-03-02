# Month 55: GPU编程基础 (GPU Programming Fundamentals)

## 本月主题概述

在上个月学习SYCL的基础上，本月将深入GPU编程的底层细节。我们将学习CUDA/HIP编程模型，理解GPU硬件架构，掌握内存优化技术，并实现高性能GPU内核。无论是AI训练、科学计算还是图形渲染，GPU编程已成为高性能计算的核心技能。

### 学习目标
- 深入理解GPU硬件架构
- 掌握CUDA/HIP编程模型
- 理解线程执行和调度机制
- 掌握GPU内存优化技术
- 实现高性能计算内核

**进阶目标**：
- 深入理解GPU微架构演进——从Tesla到Blackwell，掌握每一代SM/CU的关键架构变化及其对性能的影响
- 精通CUDA编程模型的每一个细节——线程层次、内存层次、同步机制、错误处理，能从硬件角度解释每一个API的语义
- 掌握系统性的GPU内存优化方法论：合并访问分析、Bank冲突消除、寄存器压力控制、数据布局变换（AoS→SoA），能用Nsight量化每个优化的收益
- 精通Warp级编程——shuffle、vote、match原语，理解它们如何映射到硬件指令，能用Warp原语替代共享内存实现更高效的归约和扫描
- 掌握CUDA Streams和异步执行模型，实现计算与传输的完美重叠，理解CUDA Graph的执行优势
- 能使用HIP编写可同时在NVIDIA和AMD GPU上运行的代码，理解CUDA→HIP的迁移策略和性能差异

---

## 理论学习内容

### 第一周：GPU架构深入（35小时）

**学习目标**：
- [ ] 追溯GPU从固定功能图形管线到通用计算（GPGPU）的演进历程，理解每一代架构引入的关键特性及其动机
- [ ] 深入理解SM/CU的内部结构——执行单元、寄存器文件、共享内存、Warp调度器——能画出详细的SM架构框图并解释每个组件的作用
- [ ] 掌握SIMT执行模型的硬件机制：Warp如何被创建、调度、执行和退出；Warp Scheduler的双发射机制；Scoreboard如何跟踪依赖
- [ ] 精通GPU内存层次的每一层：寄存器（~1cycle）、共享内存（~5cycles）、L1 Cache（~30cycles）、L2 Cache（~200cycles）、全局内存（~400cycles），理解每层的容量、带宽和适用场景
- [ ] 深入理解分支分歧的硬件机制——predication、convergence barrier、Independent Thread Scheduling——能量化分析分支分歧对性能的影响
- [ ] 掌握GPU适用性分析框架：根据计算密度（FLOPs/byte）、并行度、内存访问模式判断工作负载是否适合GPU加速
- [ ] 了解现代GPU架构演进路线：Ampere→Hopper→Blackwell的关键创新（Tensor Core演进、NVLink互连、HBM集成、Transformer Engine）
- [ ] 对比NVIDIA、AMD和Intel GPU架构差异：SM vs CU vs EU，Warp vs Wavefront vs SIMD，理解跨厂商编程的挑战

**阅读材料**：
- [ ] 《CUDA C Programming Guide》- NVIDIA, Chapters 1-5（编程模型、硬件实现）
- [ ] 《Professional CUDA C Programming》- Cheng, Grossman, McKercher, Chapters 1-3（GPU架构基础）
- [ ] 《Programming Massively Parallel Processors》- Kirk & Hwu, 4th Edition, Chapters 1-4（异构计算架构）
- [ ] NVIDIA Ampere Architecture Whitepaper (GA102)：SM结构、内存层次、Tensor Core
- [ ] NVIDIA Hopper Architecture Whitepaper (H100)：DPX指令、TMA引擎、Thread Block Cluster
- [ ] AMD CDNA 3 Architecture Whitepaper：CU结构、Matrix Core、Infinity Fabric
- [ ] Intel Xe-HPC Architecture Guide：EU结构、Xe Core、HBM集成
- [ ] "Dissecting the NVIDIA Volta GPU Architecture via Microbenchmarking" - Jia et al. (2018)
- [ ] GTC 2022: "Inside the NVIDIA Ada Lovelace Architecture" by Jonah Alben
- [ ] "A Survey of Techniques for Architecting and Managing GPU Register File" - Gebhart et al.

---

#### 核心概念

**GPU计算生态全景图**

```
┌─────────────────────────────────────────────────────────────┐
│                    GPU计算生态全景                            │
└─────────────────────────────────────────────────────────────┘

应用层：
┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│ 深度学习  │ │ 科学计算  │ │ 图形渲染  │ │ 数据分析  │
│ PyTorch  │ │ CFD/MD   │ │ Vulkan   │ │ RAPIDS   │
│ TensorRT │ │ LAMMPS   │ │ DX12     │ │ cuDF     │
└────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘
     │            │            │            │
     └────────────┴────────────┴────────────┘
                       │
编程框架层：           ▼
┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│  CUDA    │ │   HIP    │ │   SYCL   │ │  OpenCL  │
│ (NVIDIA) │ │  (AMD)   │ │(Khronos) │ │(Khronos) │
└────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘
     │            │            │            │
库层：│            │            │            │
┌────▼─────┐ ┌────▼─────┐ ┌────▼─────┐     │
│ cuBLAS   │ │ rocBLAS  │ │ oneMKL   │     │
│ cuDNN    │ │ MIOpen   │ │ oneDNN   │     │
│ cuFFT    │ │ rocFFT   │ │          │     │
│ Thrust   │ │ rocThrust│ │          │     │
└────┬─────┘ └────┬─────┘ └────┬─────┘     │
     │            │            │            │
     └────────────┴────────────┴────────────┘
                       │
中间表示层：           ▼
┌──────────┐ ┌──────────┐ ┌──────────┐
│   PTX    │ │  GCN/    │ │  SPIR-V  │
│ (NVIDIA) │ │ RDNA ISA │ │(Khronos) │
└────┬─────┘ └────┬─────┘ └────┬─────┘
     │            │            │
硬件层：           ▼
┌──────────┐ ┌──────────┐ ┌──────────┐
│ NVIDIA   │ │   AMD    │ │  Intel   │
│ A100/H100│ │ MI250/300│ │ Max 1550 │
│ RTX 4090 │ │ RX 7900 │ │ Arc A770 │
└──────────┘ └──────────┘ └──────────┘
```

#### 1.1 GPU发展历程：从图形管线到通用计算

GPU的发展历程是理解当代GPU架构设计决策的关键。每一代架构的演进都有其深刻的技术和市场驱动力。

```
GPU通用计算发展时间线：

2001 ┌──── NVIDIA GeForce 3 (NV20)
     │     首次支持可编程着色器（Vertex/Pixel Shader）
     │     固定功能管线开始松动
     │
2003 ├──── ATI Radeon 9700 / NVIDIA GeForce FX
     │     Shader Model 2.0：支持浮点运算
     │     学术界开始探索"GPGPU"（BrookGPU项目）
     │
2006 ├──── NVIDIA GeForce 8800 GTX (G80) ★ 里程碑
     │     统一着色器架构（Unified Shaders）
     │     CUDA 1.0 发布：GPU通用计算正式开始
     │     首个SM设计：8个SP × 16 SM = 128 CUDA Cores
     │
2008 ├──── NVIDIA Tesla (GT200)
     │     双精度浮点支持
     │     科学计算开始采用GPU
     │
2010 ├──── NVIDIA Fermi (GF100)
     │     真正的IEEE 754双精度
     │     ECC内存、L1/L2缓存层次
     │     CUDA Compute Capability 2.0
     │
2012 ├──── NVIDIA Kepler (GK110)
     │     动态并行（Dynamic Parallelism）
     │     Hyper-Q（多流并发）
     │     GPU Boost时钟
     │
2014 ├──── NVIDIA Maxwell (GM200)
     │     能效比大幅提升（perf/watt）
     │     共享内存/L1独立配置
     │
2016 ├──── NVIDIA Pascal (GP100) / AMD Vega
     │     HBM2高带宽内存
     │     NVLink互连
     │     16nm FinFET工艺
     │
2017 ├──── NVIDIA Volta (GV100) ★ 里程碑
     │     Tensor Core首次引入（混合精度矩阵运算）
     │     Independent Thread Scheduling
     │     深度学习训练加速的转折点
     │
2020 ├──── NVIDIA Ampere (GA100/GA102)
     │     第三代Tensor Core（TF32、BF16、INT8）
     │     结构化稀疏（2:4 Sparsity）
     │     异步拷贝（cp.async）
     │
2022 ├──── NVIDIA Hopper (H100) / AMD CDNA 2 (MI250X)
     │     Thread Block Cluster
     │     DPX指令（动态规划）
     │     Transformer Engine（FP8）
     │     TMA（Tensor Memory Accelerator）
     │
2024 ├──── NVIDIA Blackwell (B200) / AMD CDNA 3 (MI300X)
     │     第五代Tensor Core
     │     双Die设计（NVLink Chip-to-Chip）
     │     FP4支持
     │     192GB HBM3e
     │
2025 └──── 当前：GPU已成为AI/HPC的核心基础设施
           数据中心GPU市场 > $500B
```

```
统一着色器架构的革命（G80, 2006）：

变革前 —— 固定功能管线：
┌──────────┐    ┌──────────┐    ┌──────────┐
│ 顶点处理  │ → │ 光栅化    │ → │ 像素处理  │
│ (专用硬件) │    │ (固定)    │    │ (专用硬件) │
│ 顶点着色器 │    │           │    │ 像素着色器 │
└──────────┘    └──────────┘    └──────────┘
   问题：顶点和像素处理负载不均，硬件利用率低

变革后 —— 统一着色器架构：
┌─────────────────────────────────────────────────┐
│              统一处理器阵列                        │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐ ... ┌────┐       │
│  │ SP │ │ SP │ │ SP │ │ SP │     │ SP │       │
│  └────┘ └────┘ └────┘ └────┘     └────┘       │
│                                                  │
│  可以执行任何类型的着色器程序                       │
│  也可以执行通用计算程序（CUDA内核）                 │
└─────────────────────────────────────────────────┘
   优势：所有计算资源可以灵活分配给任何任务

关键洞察（Ian Buck, CUDA创始人）：
"我们意识到统一着色器就是一个大规模并行处理器。
 如果给它一个通用编程模型，它可以做任何事情。"
```

#### 1.2 SM/CU微架构深度剖析

Streaming Multiprocessor（SM）是NVIDIA GPU的核心计算单元。理解SM的内部结构是编写高性能CUDA代码的基础。AMD对应的概念是Compute Unit（CU）。

```
NVIDIA Ampere SM详细架构（GA100 - A100）：
┌─────────────────────────────────────────────────────────────┐
│                    Streaming Multiprocessor                   │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │            指令缓存 (Instruction Cache)                  │ │
│  └────────────────────────┬───────────────────────────────┘ │
│                            ▼                                  │
│  ┌────────────────────────────────────────────────────────┐ │
│  │       Warp Scheduler × 4 + Dispatch Unit × 4           │ │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │ │
│  │  │Scheduler0│ │Scheduler1│ │Scheduler2│ │Scheduler3│ │ │
│  │  │Dispatch 0│ │Dispatch 1│ │Dispatch 2│ │Dispatch 3│ │ │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ │ │
│  │  每个调度器管理一组Warp，每周期可发射1条指令             │ │
│  │  4个调度器可同时从4个不同Warp发射指令                    │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                               │
│  ┌─── Processing Block 0 ──┐ ┌─── Processing Block 1 ──┐  │
│  │  FP32 ×16               │ │  FP32 ×16               │  │
│  │  INT32 ×16              │ │  INT32 ×16              │  │
│  │  FP64 ×8               │ │  FP64 ×8               │  │
│  │  LD/ST ×8              │ │  LD/ST ×8              │  │
│  │  SFU ×4 (sin/cos/rsqrt)│ │  SFU ×4                │  │
│  │  Tensor Core ×1        │ │  Tensor Core ×1        │  │
│  └─────────────────────────┘ └─────────────────────────┘  │
│  ┌─── Processing Block 2 ──┐ ┌─── Processing Block 3 ──┐  │
│  │  (结构同上)             │ │  (结构同上)             │  │
│  └─────────────────────────┘ └─────────────────────────┘  │
│                                                               │
│  合计每SM：                                                   │
│  • FP32: 64 cores (可同时执行FP32+INT32)                     │
│  • FP64: 32 cores                                            │
│  • Tensor Core: 4 (第三代，支持TF32/BF16/FP16/INT8)         │
│  • LD/ST: 32 units                                           │
│  • SFU: 16 units                                             │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │           Register File: 65536 × 32-bit = 256KB        │ │
│  │  每个线程最多使用255个寄存器                              │ │
│  │  A100: 108 SMs × 256KB = 27MB 寄存器文件总量             │ │
│  └────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────┐ │
│  │      Shared Memory / L1 Cache: 192KB（可配置比例）      │ │
│  │  配置选项：                                              │
│  │    0KB shared + 192KB L1                                │ │
│  │   64KB shared + 128KB L1                                │ │
│  │  100KB shared +  92KB L1                                │ │
│  │  132KB shared +  60KB L1                                │ │
│  │  164KB shared +  28KB L1                                │ │
│  └────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────┐ │
│  │           Texture Units: 4                              │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘

A100 GPU 完整芯片：
  108 SMs × 64 FP32 = 6912 CUDA Cores
  108 SMs × 4 TC = 432 Tensor Cores
  40MB L2 Cache
  80GB HBM2e @ 2039 GB/s
  FP32 峰值: 19.5 TFLOPS
  TF32 峰值: 156 TFLOPS (with Tensor Cores)
```

```
AMD CDNA 3 Compute Unit详细架构（MI300X）：
┌─────────────────────────────────────────────────────────────┐
│                     Compute Unit (CU)                        │
├─────────────────────────────────────────────────────────────┤
│  ┌────────────────────────────────────────────────────────┐ │
│  │       Wavefront Scheduler × 4                          │ │
│  │  AMD的wavefront = 64线程（NVIDIA warp = 32线程）       │ │
│  │  每个调度器管理一个wavefront流水线                      │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                               │
│  ┌──── SIMD Unit 0 ────┐ ┌──── SIMD Unit 1 ────┐          │
│  │  FP32/INT32 ×16     │ │  FP32/INT32 ×16     │          │
│  │  FP64 ×8            │ │  FP64 ×8            │          │
│  │  Matrix Core ×1     │ │  Matrix Core ×1     │          │
│  └─────────────────────┘ └─────────────────────┘          │
│  ┌──── SIMD Unit 2 ────┐ ┌──── SIMD Unit 3 ────┐          │
│  │  (结构同上)         │ │  (结构同上)         │          │
│  └─────────────────────┘ └─────────────────────┘          │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Vector Register File: 512 × 64 × 32-bit = 128KB      │ │
│  │  Scalar Register File: 用于标量操作和控制流              │ │
│  └────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Local Data Share (LDS): 64KB                          │ │
│  │  ≈ NVIDIA 的 Shared Memory                             │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘

NVIDIA vs AMD 术语对照：
┌───────────────────┬─────────────────┬─────────────────────┐
│  概念              │  NVIDIA          │  AMD                │
├───────────────────┼─────────────────┼─────────────────────┤
│  计算单元          │  SM              │  CU                 │
│  线程束            │  Warp (32线程)   │  Wavefront (64线程) │
│  线程              │  CUDA Thread     │  Work-item          │
│  线程块            │  Thread Block    │  Work-group         │
│  共享内存          │  Shared Memory   │  LDS                │
│  全局内存          │  Global Memory   │  Global Memory      │
│  寄存器文件        │  Register File   │  VGPR/SGPR          │
│  矩阵运算单元      │  Tensor Core     │  Matrix Core        │
│  编程框架          │  CUDA            │  HIP/ROCm           │
└───────────────────┴─────────────────┴─────────────────────┘
```

#### 1.3 SIMT执行模型与Warp调度

SIMT（Single Instruction, Multiple Threads）是GPU最核心的执行模型。与CPU的SIMD不同，SIMT允许每个线程有独立的程序计数器和执行路径（尽管同一Warp内的分支分歧会导致性能损失）。

```
Warp执行的完整生命周期：

1. Warp创建
   Thread Block被分配到SM后，硬件自动将线程分组为Warp
   ┌──────────────────────────────────────────────────┐
   │  Thread Block (256 threads, blockDim = 256)       │
   │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐   │
   │  │Warp 0  │ │Warp 1  │ │Warp 2  │ │...     │   │
   │  │T0...T31│ │T32..T63│ │T64..T95│ │Warp 7  │   │
   │  └────────┘ └────────┘ └────────┘ └────────┘   │
   │  共 256/32 = 8 个 Warp                           │
   └──────────────────────────────────────────────────┘

2. Warp调度
   每个SM有4个Warp Scheduler，每周期可从就绪Warp中选择发射
   ┌──────────────────────────────────────────────────┐
   │  Warp Scheduler 选择逻辑：                        │
   │                                                    │
   │  时钟周期 N:                                       │
   │    Scheduler 0 → 发射 Warp 3 的下一条指令          │
   │    Scheduler 1 → 发射 Warp 7 的下一条指令          │
   │    Scheduler 2 → 发射 Warp 1 的下一条指令          │
   │    Scheduler 3 → Warp 5 等待内存，跳过             │
   │                                                    │
   │  时钟周期 N+1:                                     │
   │    Scheduler 0 → 发射 Warp 0 的下一条指令          │
   │    Scheduler 1 → 发射 Warp 4 的下一条指令          │
   │    Scheduler 2 → 发射 Warp 6 的下一条指令          │
   │    Scheduler 3 → 发射 Warp 2 的下一条指令          │
   │                                                    │
   │  关键：Warp切换是零成本的！                        │
   │  每个Warp的寄存器状态常驻，不需要上下文保存/恢复    │
   └──────────────────────────────────────────────────┘

3. 延迟隐藏（Latency Hiding）
   GPU通过大量Warp切换隐藏内存延迟

   CPU方式（少量线程）：
   Thread A: ████████░░░░░░░░░░░░░████████
                     ↑等待内存400cycles↑

   GPU方式（大量Warp交替执行）：
   Warp 0: ████░░░░░░░░░░░░░░░░████
   Warp 1: ····████░░░░░░░░░░░░░░░░████
   Warp 2: ········████░░░░░░░░░░░░░░░░████
   Warp 3: ············████░░░░░░░░░░░░░░░░████
   ...
   执行单元: ████████████████████████████████████
            （持续忙碌，延迟被完全隐藏！）
```

```cpp
// 理解Warp调度的实际代码示例

// 查询设备的Warp大小
#include <cuda_runtime.h>
#include <stdio.h>

__global__ void warpInfoKernel() {
    // 内置变量获取Warp信息
    int laneId = threadIdx.x % 32;        // 线程在Warp内的位置(0-31)
    int warpId = threadIdx.x / 32;        // Warp在Block内的编号

    // 使用Warp级内置函数
    unsigned mask = __activemask();  // 当前活跃线程的位掩码
    int leader = __ffs(mask) - 1;    // 找到第一个活跃线程

    if (laneId == 0) {
        printf("Block %d, Warp %d: active mask = 0x%08X, %d active threads\n",
               blockIdx.x, warpId, mask, __popc(mask));
    }
}

// Warp同步执行的直觉验证
__global__ void warpSyncDemo(int* output) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int laneId = threadIdx.x % 32;

    // 同一Warp的所有线程"几乎同时"执行这行代码
    // 但"几乎同时"的含义是：它们共享同一条指令
    output[idx] = laneId;

    // __syncwarp(): Volta之后推荐显式同步Warp
    __syncwarp();

    // 只有lane 0读取其他线程写入的值
    if (laneId == 0) {
        int sum = 0;
        for (int i = 0; i < 32; i++) {
            sum += output[blockIdx.x * blockDim.x + i];
        }
        // sum = 0+1+2+...+31 = 496
        output[blockIdx.x * blockDim.x] = sum;
    }
}
```

```
Warp Scheduler的Scoreboard机制：

Scoreboard跟踪每条指令的操作数就绪状态：
┌──────────────────────────────────────────────┐
│  Warp 3 指令队列:                             │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐       │
│  │ ADD  │ │ MUL  │ │ LD   │ │ ADD  │ ...   │
│  │r1=r2 │ │r4=r1 │ │r5=[x]│ │r6=r5 │       │
│  │+r3   │ │*r3   │ │      │ │+r4   │       │
│  └──┬───┘ └──┬───┘ └──┬───┘ └──┬───┘       │
│     │        │        │        │             │
│  ✓就绪    ✓r1就绪  ✓可发射   ✗r5未就绪      │
│  可发射    可发射   长延迟    等待LD完成       │
└──────────────────────────────────────────────┘

当LD完成后(~400 cycles)，Scoreboard更新r5状态
→ 最后的ADD指令变为就绪，可以被调度执行

关键：需要足够多的就绪Warp来填满这400 cycles的等待
     这就是为什么高占用率（Occupancy）很重要
```

#### 1.4 GPU内存层次全景

GPU的内存层次设计是理解GPU性能优化的核心。不同层次的内存在容量、延迟、带宽和可见性方面有巨大差异。

```
GPU完整内存层次（以A100为例）：

┌─────────────────────────────────────────────────────────────┐
│                   GPU内存层次详解                             │
└─────────────────────────────────────────────────────────────┘

层级0: 寄存器 (Registers)
┌──────────────────────────────────────────────────┐
│  容量: 每SM 256KB (65536 × 32-bit)               │
│  延迟: 1 cycle                                    │
│  带宽: ~20 TB/s (估算)                            │
│  可见性: 线程私有                                  │
│  生命周期: 线程生命周期                             │
│  特点: 编译器自动分配，最快的存储                    │
│  限制: 每线程最多255个寄存器                        │
│        寄存器用多了→减少SM上的活跃Warp→降低占用率   │
└──────────────────────────────────────────────────┘
         ↓ 溢出到 Local Memory（实际在Global Memory中）

层级1: 共享内存 (Shared Memory)
┌──────────────────────────────────────────────────┐
│  容量: 每SM最大164KB (A100)                       │
│  延迟: ~5 cycles (无bank冲突时)                   │
│  带宽: ~19 TB/s per SM                            │
│  可见性: 同一Thread Block内所有线程                 │
│  生命周期: Thread Block生命周期                     │
│  特点: 程序员显式管理的scratchpad内存               │
│        32个bank，bank冲突导致串行化                 │
│  用途: 线程间数据交换、缓存复用数据、归约操作        │
└──────────────────────────────────────────────────┘

层级2: L1 Cache / Texture Cache
┌──────────────────────────────────────────────────┐
│  容量: 每SM最大192KB (与Shared Memory共享)         │
│  延迟: ~30 cycles                                 │
│  可见性: SM本地，硬件管理                          │
│  特点: 自动缓存全局内存访问                        │
│        Texture Cache优化2D空间局部性                │
└──────────────────────────────────────────────────┘

层级3: L2 Cache
┌──────────────────────────────────────────────────┐
│  容量: 40MB (A100) / 50MB (H100)                  │
│  延迟: ~200 cycles                                │
│  带宽: ~5 TB/s                                    │
│  可见性: 全GPU共享，所有SM                         │
│  特点: 硬件管理，缓存所有全局/本地内存访问          │
│        A100支持L2 Cache Residency Control          │
│        可以指定特定数据常驻L2                       │
└──────────────────────────────────────────────────┘

层级4: 全局内存 (Global Memory / Device Memory)
┌──────────────────────────────────────────────────┐
│  容量: 80GB HBM2e (A100)                          │
│  延迟: ~400 cycles                                │
│  带宽: 2039 GB/s (A100) / 3350 GB/s (H100)       │
│  可见性: 所有线程 + Host CPU                       │
│  特点: 最大容量，最高延迟                          │
│        合并访问（coalesced access）至关重要         │
│        32个线程的合并请求 → 1次内存事务             │
│        32个随机请求 → 最多32次内存事务              │
└──────────────────────────────────────────────────┘

层级5: Host Memory (CPU内存)
┌──────────────────────────────────────────────────┐
│  通过PCIe 4.0/5.0连接                             │
│  PCIe 4.0 x16: ~25 GB/s                           │
│  PCIe 5.0 x16: ~50 GB/s                           │
│  NVLink 4.0: 900 GB/s (GPU-GPU)                   │
│  数据传输是GPU编程的主要瓶颈之一                    │
└──────────────────────────────────────────────────┘

带宽梯度（A100）：
  寄存器  ████████████████████████████████ ~20 TB/s
  共享内存 ██████████████████████████████ ~19 TB/s
  L1缓存  █████████████████             ~12 TB/s
  L2缓存  ████████                       ~5 TB/s
  HBM     ███                            ~2 TB/s
  PCIe    ▎                             ~0.025 TB/s
```

```cpp
// 不同内存类型的使用示例
#include <cuda_runtime.h>

// 常量内存：64KB，所有线程只读，广播访问高效
__constant__ float constCoeffs[256];

// 全局内存上的纹理引用（用于2D空间局部性优化）
// CUDA纹理对象（现代API）
cudaTextureObject_t texObj;

__global__ void memoryHierarchyDemo(
    float* globalData,    // 全局内存
    float* output,
    int N
) {
    // 1. 寄存器 —— 编译器自动分配
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    float localVar = 0.0f;  // 存在寄存器中

    // 2. 共享内存 —— 程序员显式声明
    __shared__ float sharedTile[256];

    // 3. 加载全局内存到共享内存（协作加载）
    if (idx < N) {
        sharedTile[threadIdx.x] = globalData[idx];
    }
    __syncthreads();  // 确保所有线程加载完毕

    // 4. 从共享内存读取（~5 cycles vs 全局内存~400 cycles）
    localVar = sharedTile[threadIdx.x];

    // 5. 使用常量内存（适合所有线程读同一值）
    localVar *= constCoeffs[0];  // 广播：一次读取，32线程共享

    // 6. 写回全局内存
    if (idx < N) {
        output[idx] = localVar;
    }
}

// 本地内存（Local Memory）—— 寄存器溢出时自动使用
// 实际存储在全局内存中，但逻辑上是线程私有的
__global__ void registerSpillDemo(float* data, int N) {
    // 声明大数组会导致寄存器溢出到本地内存
    float largeArray[64];  // 编译器可能将其放入本地内存

    // 避免方法：减少每线程的数据量
    // 或使用共享内存替代
}
```

#### 1.5 分支分歧与Warp执行效率

分支分歧（Branch Divergence）是GPU编程中最常见的性能陷阱之一。当同一Warp内的线程走不同的执行路径时，GPU必须串行化执行所有路径。

```
分支分歧的硬件机制（Volta之前 vs Volta之后）：

Pre-Volta（Pascal及更早）—— Predication模式：
┌──────────────────────────────────────────────────┐
│  if (condition) {                                 │
│      path_A();  // 所有线程都执行，但不满足条件的  │
│  } else {       // 线程结果被丢弃（masked out）   │
│      path_B();  // 同上                          │
│  }                                                │
│                                                    │
│  Warp执行时间 = path_A时间 + path_B时间            │
│  (不是 max(path_A, path_B))                       │
│                                                    │
│  活跃掩码示例（32线程）：                          │
│  条件：threadIdx.x < 16                           │
│  path_A执行: ████████████████░░░░░░░░░░░░░░░░    │
│              T0-T15 执行     T16-T31 等待         │
│  path_B执行: ░░░░░░░░░░░░░░░░████████████████    │
│              T0-T15 等待     T16-T31 执行         │
└──────────────────────────────────────────────────┘

Post-Volta —— Independent Thread Scheduling：
┌──────────────────────────────────────────────────┐
│  每个线程有独立的程序计数器和调用栈                 │
│  分支分歧仍有性能损失，但更灵活：                   │
│  - 支持线程级的同步（__syncwarp）                  │
│  - 支持更细粒度的收敛（convergence barriers）      │
│  - 避免了某些deadlock场景                         │
│                                                    │
│  重要：分支分歧的性能损失并未消除！                 │
│  只是编程模型更安全了                               │
└──────────────────────────────────────────────────┘
```

```cpp
// 分支分歧的量化分析

// 场景1：最坏的分支分歧 —— 交错分支
__global__ void worstDivergence(float* data, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= n) return;

    // 偶数/奇数线程走不同路径 → 50%效率
    if (threadIdx.x % 2 == 0) {
        data[idx] = sinf(data[idx]);   // ~10 cycles
    } else {
        data[idx] = cosf(data[idx]);   // ~10 cycles
    }
    // 实际执行 ~20 cycles（串行化两个路径）
    // 效率 = 10/20 = 50%
}

// 场景2：Warp对齐的分支 —— 无分歧
__global__ void noDivergence(float* data, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= n) return;

    int warpId = threadIdx.x / 32;
    // 整个Warp走同一路径 → 100%效率
    if (warpId % 2 == 0) {
        data[idx] = sinf(data[idx]);
    } else {
        data[idx] = cosf(data[idx]);
    }
    // 实际执行 ~10 cycles
    // 效率 = 100%
}

// 场景3：边界条件的分支 —— 常见但影响小
__global__ void boundaryDivergence(float* data, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;

    // 只有最后一个Warp可能有分歧
    if (idx < n) {
        data[idx] *= 2.0f;
    }
    // 如果n = 1000, blockDim = 256:
    // Block 0-2: 所有线程都满足条件，无分歧
    // Block 3: 最后一个Warp有 1000-992=8 个线程不满足
    // 只有1个Warp有分歧，影响极小
}

// 优化技巧：用数学替代分支
__global__ void branchFree(float* data, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= n) return;

    // 替代: if (x > 0) y = x; else y = 0;
    float x = data[idx];

    // 用 fmaxf 替代分支（编译器通常自动优化）
    data[idx] = fmaxf(x, 0.0f);  // ReLU without branch

    // 替代: if (cond) y = a; else y = b;
    // 用三元运算符（编译器可能生成predicated指令）
    float result = (x > 0.0f) ? x * 2.0f : x * 0.5f;
    data[idx] = result;
}
```

#### 1.6 GPU vs CPU：何时选择GPU

不是所有计算都适合GPU。理解GPU的适用场景需要分析工作负载的并行度、计算密度和内存访问模式。

```
GPU适用性分析框架：

算术强度（Arithmetic Intensity）= FLOPs / Bytes Accessed

                  Compute-Bound
                       ↑
          高算术强度    │    ★ GPU最佳区域
          (>10 FLOP/B) │    矩阵乘法、卷积
                       │    深度学习训练
                       │
                       │
          中算术强度    │    ◆ GPU可能受益
          (1-10 FLOP/B)│    粒子模拟、FFT
                       │    图像处理
                       │
                       │
          低算术强度    │    ▲ GPU可能不适合
          (<1 FLOP/B)  │    图遍历、稀疏矩阵
                       │    除非带宽受限
 ─────────────────────┼──────────────────→
         少量并行     │      大量并行      并行度
         (<1K线程)    │      (>10K线程)

Roofline模型：
┌──────────────────────────────────────────────────┐
│  性能                                             │
│  (GFLOPS) ╱‾‾‾‾‾‾‾‾‾‾‾‾‾‾ 计算峰值              │
│          ╱                                        │
│         ╱  ← 带宽瓶颈区域  → ← 计算瓶颈区域 →   │
│        ╱                                          │
│       ╱                                           │
│      ╱     ← 优化目标：                          │
│     ╱        1. 提高算术强度（减少内存访问）        │
│    ╱         2. 提高内存带宽利用率（合并访问）      │
│   ╱          3. 提高计算利用率（减少分歧）         │
│  ╱                                                │
│ ╱                                                 │
│╱________________________________________________ │
│ 0.1   1    10   100  算术强度 (FLOP/Byte)         │
└──────────────────────────────────────────────────┘
```

```
适合GPU的工作负载特征（打分卡）：

┌────────────────────────┬──────┬───────────────────────────┐
│  特征                   │ 权重  │ GPU友好 vs GPU不友好       │
├────────────────────────┼──────┼───────────────────────────┤
│  数据并行度             │ ★★★  │ >10K并行 vs <100并行       │
│  (独立计算的数量)       │      │                           │
├────────────────────────┼──────┼───────────────────────────┤
│  算术强度               │ ★★★  │ >5 FLOP/B vs <0.5 FLOP/B │
│  (计算/内存比)          │      │                           │
├────────────────────────┼──────┼───────────────────────────┤
│  内存访问模式           │ ★★☆  │ 规则/连续 vs 随机/不规则   │
│                        │      │                           │
├────────────────────────┼──────┼───────────────────────────┤
│  控制流复杂度           │ ★★☆  │ 简单/uniform vs 复杂/不规则│
│                        │      │                           │
├────────────────────────┼──────┼───────────────────────────┤
│  数据量                 │ ★☆☆  │ >1MB（值得传输开销）       │
│                        │      │ vs <1KB（传输开销太大）    │
├────────────────────────┼──────┼───────────────────────────┤
│  精度要求               │ ★☆☆  │ FP16/FP32 vs 高精度FP128  │
│                        │      │                           │
└────────────────────────┴──────┴───────────────────────────┘

经典案例对比：
  ✓ 矩阵乘法：极高并行度 + 高算术强度 + 规则访问 → GPU最佳
  ✓ 图像卷积：高并行度 + 中等算术强度 + 2D局部性 → GPU很好
  ✓ 粒子模拟：高并行度 + 中等算术强度 + 规则计算 → GPU适合
  △ 排序算法：中等并行度 + 低算术强度 + 随机访问 → 取决于规模
  △ 图遍历：高并行度 + 极低算术强度 + 随机访问 → GPU可能受益
  ✗ 递归搜索：低并行度 + 复杂控制流 + 递归 → CPU更好
  ✗ 串行依赖链：无并行度 → CPU单线程更快
```

#### 1.7 现代GPU架构演进（Ampere → Hopper → Blackwell）

理解最新GPU架构的演进方向有助于把握高性能计算的未来趋势。

```
三代架构关键参数对比（数据中心GPU）：

┌──────────────────┬───────────────┬───────────────┬───────────────┐
│  参数             │  A100 (2020)  │  H100 (2022)  │  B200 (2024)  │
│                  │  Ampere       │  Hopper       │  Blackwell    │
├──────────────────┼───────────────┼───────────────┼───────────────┤
│  工艺制程         │  7nm (TSMC)   │  4nm (TSMC)   │  4nm (TSMC)   │
│  晶体管数         │  542亿        │  800亿        │  2080亿       │
│                  │              │              │  (双Die)      │
├──────────────────┼───────────────┼───────────────┼───────────────┤
│  SM/SMs          │  108          │  132          │  160 (2×80)   │
│  CUDA Cores      │  6912         │  16896        │  20480        │
│  Tensor Cores    │  432 (3rd)    │  528 (4th)    │  640 (5th)    │
├──────────────────┼───────────────┼───────────────┼───────────────┤
│  FP32 峰值       │  19.5 TFLOPS  │  67 TFLOPS    │  90 TFLOPS    │
│  FP16 Tensor     │  312 TFLOPS   │  990 TFLOPS   │  2250 TFLOPS  │
│  FP8 Tensor      │  -            │  1979 TFLOPS  │  4500 TFLOPS  │
│  FP4 Tensor      │  -            │  -            │  9000 TFLOPS  │
├──────────────────┼───────────────┼───────────────┼───────────────┤
│  HBM类型         │  HBM2e        │  HBM3         │  HBM3e        │
│  内存容量         │  80GB         │  80GB         │  192GB        │
│  内存带宽         │  2039 GB/s    │  3350 GB/s    │  8000 GB/s    │
├──────────────────┼───────────────┼───────────────┼───────────────┤
│  L2 Cache        │  40MB         │  50MB         │  ?(large)     │
│  互连             │  NVLink 3     │  NVLink 4     │  NVLink 5     │
│  互连带宽         │  600 GB/s     │  900 GB/s     │  1800 GB/s    │
├──────────────────┼───────────────┼───────────────┼───────────────┤
│  TDP             │  400W         │  700W         │  1000W        │
│  关键新特性       │  结构化稀疏   │  TMA引擎      │  双Die设计    │
│                  │  cp.async     │  TB Cluster   │  FP4支持      │
│                  │  TF32数据类型 │  Transformer  │  Confidential │
│                  │              │  Engine (FP8) │  Computing    │
└──────────────────┴───────────────┴───────────────┴───────────────┘

关键架构创新详解：

Ampere (A100) 引入：
┌──────────────────────────────────────────────────────────┐
│ 1. 结构化稀疏 (2:4 Sparsity)                             │
│    每4个权重中2个可以为0，硬件自动跳过零值计算             │
│    Tensor Core吞吐量翻倍（在稀疏化模型上）                │
│    ┌─────────────────────────┐                           │
│    │ 原始: [1.2, 0, 3.4, 0]  │ → 压缩为2个非零值+索引   │
│    │ 计算量减半               │                           │
│    └─────────────────────────┘                           │
│                                                           │
│ 2. 异步内存拷贝 (cp.async)                                │
│    从全局内存直接到共享内存，不经过寄存器                   │
│    与计算可以重叠执行                                      │
│    旧方式: Global → Register → Shared (2步，占用寄存器)   │
│    新方式: Global → Shared (1步，不占用寄存器)            │
│                                                           │
│ 3. TF32 (TensorFloat-32)                                  │
│    19-bit格式：8位指数 + 10位尾数 + 1位符号                │
│    FP32精度的子集，但Tensor Core吞吐量8x                  │
│    对训练精度影响极小，实践中可直接替代FP32                 │
└──────────────────────────────────────────────────────────┘

Hopper (H100) 引入：
┌──────────────────────────────────────────────────────────┐
│ 1. Thread Block Cluster                                   │
│    新的线程层次：Grid → Cluster → Block → Warp → Thread   │
│    Cluster内的Block可以直接访问彼此的Shared Memory         │
│    通过分布式共享内存(DSMEM)实现，无需经过全局内存          │
│    ┌────────────────────────────────────────┐             │
│    │  Cluster (多个Thread Block)             │             │
│    │  ┌────────┐ ┌────────┐ ┌────────┐     │             │
│    │  │Block 0 │↔│Block 1 │↔│Block 2 │     │             │
│    │  │Shared  │ │Shared  │ │Shared  │     │             │
│    │  │Memory  │ │Memory  │ │Memory  │     │             │
│    │  └────────┘ └────────┘ └────────┘     │             │
│    │  通过DSMEM直接互访（~30 cycles）       │             │
│    └────────────────────────────────────────┘             │
│                                                           │
│ 2. TMA (Tensor Memory Accelerator)                        │
│    专用硬件单元处理多维数据的地址计算和传输                 │
│    支持1D-5D张量的异步加载                                 │
│    无需手动计算索引，硬件自动处理边界和对齐                 │
│                                                           │
│ 3. Transformer Engine                                     │
│    FP8（E4M3 / E5M2）硬件支持                             │
│    自动混合精度：FP8计算 + FP32累加                        │
│    针对Transformer注意力机制的专门优化                     │
└──────────────────────────────────────────────────────────┘
```

```cpp
// 查询GPU硬件信息的完整程序
#include <cuda_runtime.h>
#include <stdio.h>

void printDetailedGPUInfo() {
    int deviceCount;
    cudaGetDeviceCount(&deviceCount);

    for (int dev = 0; dev < deviceCount; dev++) {
        cudaDeviceProp prop;
        cudaGetDeviceProperties(&prop, dev);

        printf("════════════════════════════════════════════\n");
        printf("Device %d: %s\n", dev, prop.name);
        printf("════════════════════════════════════════════\n");

        // 架构信息
        printf("[架构]\n");
        printf("  Compute Capability: %d.%d\n", prop.major, prop.minor);
        printf("  SMs: %d\n", prop.multiProcessorCount);

        // 根据Compute Capability推断架构代号
        const char* arch = "Unknown";
        if (prop.major == 7 && prop.minor == 0) arch = "Volta (V100)";
        else if (prop.major == 7 && prop.minor == 5) arch = "Turing";
        else if (prop.major == 8 && prop.minor == 0) arch = "Ampere (A100)";
        else if (prop.major == 8 && prop.minor == 6) arch = "Ampere (RTX 30x0)";
        else if (prop.major == 8 && prop.minor == 9) arch = "Ada Lovelace (RTX 40x0)";
        else if (prop.major == 9 && prop.minor == 0) arch = "Hopper (H100)";
        printf("  Architecture: %s\n", arch);

        // 内存信息
        printf("\n[内存]\n");
        printf("  Global Memory: %zu MB\n",
               prop.totalGlobalMem / (1024 * 1024));
        printf("  Shared Memory per SM: %zu KB\n",
               prop.sharedMemPerMultiprocessor / 1024);
        printf("  Shared Memory per Block: %zu KB\n",
               prop.sharedMemPerBlock / 1024);
        printf("  Registers per SM: %d\n",
               prop.regsPerMultiprocessor);
        printf("  Registers per Block: %d\n",
               prop.regsPerBlock);
        printf("  L2 Cache: %d KB\n",
               prop.l2CacheSize / 1024);
        printf("  Memory Bus Width: %d-bit\n",
               prop.memoryBusWidth);
        printf("  Memory Clock Rate: %d MHz\n",
               prop.memoryClockRate / 1000);
        printf("  Memory Bandwidth: %.1f GB/s\n",
               2.0 * prop.memoryClockRate * (prop.memoryBusWidth / 8) / 1.0e6);

        // 执行能力
        printf("\n[执行能力]\n");
        printf("  Warp Size: %d\n", prop.warpSize);
        printf("  Max Threads per Block: %d\n",
               prop.maxThreadsPerBlock);
        printf("  Max Threads per SM: %d\n",
               prop.maxThreadsPerMultiProcessor);
        printf("  Max Warps per SM: %d\n",
               prop.maxThreadsPerMultiProcessor / prop.warpSize);
        printf("  Max Blocks per SM: %d\n",
               prop.maxBlocksPerMultiProcessor);
        printf("  Max Block Dimensions: [%d, %d, %d]\n",
               prop.maxThreadsDim[0], prop.maxThreadsDim[1],
               prop.maxThreadsDim[2]);
        printf("  Max Grid Dimensions: [%d, %d, %d]\n",
               prop.maxGridSize[0], prop.maxGridSize[1],
               prop.maxGridSize[2]);

        // 时钟频率
        printf("\n[频率]\n");
        printf("  GPU Clock Rate: %d MHz\n",
               prop.clockRate / 1000);

        // 计算FP32峰值TFLOPS（粗略估算）
        // CUDA Cores per SM取决于架构
        int coresPerSM;
        if (prop.major == 8 && prop.minor == 0) coresPerSM = 64;
        else if (prop.major == 8 && prop.minor == 6) coresPerSM = 128;
        else if (prop.major == 8 && prop.minor == 9) coresPerSM = 128;
        else if (prop.major == 9) coresPerSM = 128;
        else coresPerSM = 64;  // 默认估算

        double tflops = 2.0 * coresPerSM * prop.multiProcessorCount
                        * (prop.clockRate / 1.0e6);
        printf("  Estimated FP32 Peak: %.1f TFLOPS\n", tflops / 1000.0);

        // 功能特性
        printf("\n[特性]\n");
        printf("  Concurrent Kernels: %s\n",
               prop.concurrentKernels ? "Yes" : "No");
        printf("  Async Engine Count: %d\n",
               prop.asyncEngineCount);
        printf("  Unified Addressing: %s\n",
               prop.unifiedAddressing ? "Yes" : "No");
        printf("  Cooperative Launch: %s\n",
               prop.cooperativeLaunch ? "Yes" : "No");
        printf("  Managed Memory: %s\n",
               prop.managedMemory ? "Yes" : "No");
        printf("  Pageable Memory Access: %s\n",
               prop.pageableMemoryAccess ? "Yes" : "No");
    }
}
```

#### 1.8 本周练习任务

1. **GPU硬件探测器** —— 编写一个完整的CUDA程序，枚举系统中所有GPU的详细硬件信息，包括SM数量、内存带宽、各级缓存大小、Compute Capability等。根据Compute Capability判断支持的特性。

2. **Roofline模型构建** —— 对你的GPU进行微基准测试：(a) 测量实际内存带宽（使用大数组拷贝）；(b) 测量实际FP32计算峰值（使用FMA密集循环）；(c) 画出Roofline图并标注转折点。

3. **分支分歧量化实验** —— 编写三个内核：(a) 无分支分歧（Warp对齐）；(b) 50%分支分歧（偶奇交错）；(c) 随机分支。使用CUDA事件计时，量化分支分歧对性能的影响。使用`nvprof`或Nsight Compute的Branch Efficiency指标验证。

4. **Warp执行可视化** —— 编写一个内核，让每个线程记录自己的Warp ID、Lane ID、执行时间戳（使用`clock64()`），输出到数组中。在主机端分析输出，验证同一Warp内的线程确实同步执行。

5. **GPU架构对比报告** —— 阅读NVIDIA Ampere和Hopper白皮书，写一份对比报告（1-2页），重点分析：(a) SM内部结构差异；(b) 内存层次变化；(c) 新增的硬件单元（TMA、Thread Block Cluster）对编程模型的影响。

#### 1.9 本周知识检验

- [ ] 能画出SM的内部架构图，标注每个组件的功能和参数
- [ ] 能解释SIMT与SIMD的3个关键区别
- [ ] 能计算给定GPU的理论FP32峰值和内存带宽
- [ ] 能解释Warp调度器如何通过线程切换隐藏内存延迟
- [ ] 能识别分支分歧场景，并提出至少3种消除方法
- [ ] 能使用Roofline模型判断内核是计算受限还是内存受限
- [ ] 能描述Ampere → Hopper → Blackwell三代架构的关键创新点
- [ ] 理解寄存器使用量与Occupancy之间的反向关系
- [ ] 能解释GPU内存层次中每一层的容量、延迟和适用场景
- [ ] 能对比NVIDIA SM和AMD CU的架构差异

---

### 第二周：CUDA/HIP编程模型（35小时）

**学习目标**：
- [ ] 精通CUDA编程模型的三层抽象：Grid/Block/Thread层次结构，理解每一层对应的硬件资源和调度策略
- [ ] 掌握多维索引计算：能在1D、2D、3D网格中正确计算线程的全局索引，理解Grid-Stride Loop模式
- [ ] 深入理解CUDA内核函数的限制和优化：`__global__`/`__device__`/`__host__`修饰符的语义，内核参数传递的限制
- [ ] 精通设备内存管理全流程：`cudaMalloc`/`cudaFree`/`cudaMemcpy`/`cudaMemset`，理解同步与异步传输的差异
- [ ] 掌握统一内存（Unified Memory）的工作原理：页迁移机制、预取策略、性能特征，以及与显式内存管理的对比
- [ ] 能使用HIP编写跨平台GPU代码，理解CUDA→HIP的API映射关系和性能差异
- [ ] 理解CUDA编译流程：`.cu` → `nvcc` → PTX → SASS/cubin，掌握PTX中间表示的基本语法
- [ ] 掌握完善的错误处理模式：同步/异步错误检查、cuda-memcheck使用、compute-sanitizer调试

**阅读材料**：
- [ ] CUDA C++ Programming Guide - NVIDIA, Chapters 2-4（编程模型、编程接口）
- [ ] CUDA C++ Best Practices Guide - NVIDIA（性能优化建议）
- [ ] HIP Programming Guide - AMD ROCm Documentation
- [ ] PTX ISA Reference Manual - NVIDIA（中间表示规范）
- [ ] 《Professional CUDA C Programming》- Cheng et al., Chapters 4-6（内核执行、内存管理）
- [ ] 《Programming Massively Parallel Processors》- Kirk & Hwu, 4th Ed., Chapters 5-7
- [ ] "An Introduction to GPU Computing and CUDA Architecture" - Shane Cook (Apress)
- [ ] CppCon 2019: "Better Code with CUDA" by Richard Trembecky (NVIDIA)
- [ ] ROCm Documentation: "HIP Porting Guide" - 从CUDA迁移到HIP的完整指南
- [ ] NVIDIA Blog: "Unified Memory for CUDA Beginners" - Mark Harris

---

#### 核心概念

**CUDA程序结构全景**

```
CUDA程序的完整执行流程：

Host (CPU)                              Device (GPU)
┌───────────────────┐                   ┌───────────────────┐
│ 1. 分配主机内存    │                   │                   │
│    h_data = new    │                   │                   │
│                    │                   │                   │
│ 2. 分配设备内存    │ ──cudaMalloc──→  │ d_data在此分配    │
│                    │                   │                   │
│ 3. 传输数据       │ ──cudaMemcpy──→  │ d_data = h_data   │
│    H2D             │                   │                   │
│                    │                   │                   │
│ 4. 启动内核       │ ──kernel<<<>>──→ │ ┌──────────────┐  │
│                    │                   │ │ Block 0      │  │
│                    │                   │ │  Warp0 Warp1 │  │
│                    │                   │ ├──────────────┤  │
│ 5. CPU可继续工作   │                   │ │ Block 1      │  │
│    (异步执行)      │                   │ │  Warp0 Warp1 │  │
│                    │                   │ ├──────────────┤  │
│                    │                   │ │ ...          │  │
│                    │                   │ └──────────────┘  │
│ 6. 同步等待       │ ←─cudaSync────── │ 内核执行完毕      │
│                    │                   │                   │
│ 7. 传输结果       │ ←─cudaMemcpy──── │ d_result → h_res  │
│    D2H             │                   │                   │
│                    │                   │                   │
│ 8. 处理结果       │                   │                   │
│    释放内存        │ ──cudaFree────→  │ 释放设备内存      │
└───────────────────┘                   └───────────────────┘
```

#### 2.1 CUDA编程模型详解

CUDA编程模型的核心是"单程序多数据"（SPMD）：同一个内核函数被成千上万个线程同时执行，每个线程通过内置变量获取自己的唯一标识。

```cpp
// CUDA函数修饰符详解
// __global__: 从Host调用，在Device执行
// __device__: 从Device调用，在Device执行
// __host__:   从Host调用，在Host执行（默认）
// __host__ __device__: 在Host和Device都可以调用

// __global__ 函数限制：
// 1. 返回值必须是 void
// 2. 不能是类的成员函数（除非是static）
// 3. 不能使用可变参数（...）
// 4. 不能递归（Compute Capability 3.5+ 支持动态并行的递归）
// 5. 参数通过常量内存传递，总大小限制为4KB

#include <cuda_runtime.h>
#include <stdio.h>

// 设备辅助函数 —— 可以被内核调用
__device__ float square(float x) {
    return x * x;
}

// __host__ __device__ —— 同时在CPU和GPU编译
__host__ __device__ float clamp(float x, float lo, float hi) {
    return fminf(fmaxf(x, lo), hi);
}

// 内核函数
__global__ void processData(float* data, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < n) {
        data[idx] = clamp(square(data[idx]), 0.0f, 100.0f);
    }
}

// 错误检查宏 —— 生产代码必备
#define CUDA_CHECK(call)                                          \
    do {                                                          \
        cudaError_t err = call;                                   \
        if (err != cudaSuccess) {                                 \
            fprintf(stderr, "CUDA error at %s:%d - %s\n",        \
                    __FILE__, __LINE__, cudaGetErrorString(err));  \
            exit(EXIT_FAILURE);                                   \
        }                                                         \
    } while(0)

// 异步错误检查（检查最后一个内核启动）
#define CUDA_KERNEL_CHECK()                                       \
    do {                                                          \
        cudaError_t err = cudaGetLastError();                     \
        if (err != cudaSuccess) {                                 \
            fprintf(stderr, "Kernel launch error: %s\n",          \
                    cudaGetErrorString(err));                      \
            exit(EXIT_FAILURE);                                   \
        }                                                         \
        err = cudaDeviceSynchronize();                            \
        if (err != cudaSuccess) {                                 \
            fprintf(stderr, "Kernel execution error: %s\n",       \
                    cudaGetErrorString(err));                      \
            exit(EXIT_FAILURE);                                   \
        }                                                         \
    } while(0)
```

#### 2.2 线程层次与索引计算

正确计算线程索引是CUDA编程最基本也最容易出错的地方。理解1D、2D、3D索引映射是编写正确内核的前提。

```
线程层次结构的完整视图：

Grid (网格) —— 一次内核启动创建的所有线程
├── Block(0,0) ─── Block(1,0) ─── Block(2,0) ─── ...
│     │
│     ├── Thread(0,0) ─── Thread(1,0) ─── Thread(2,0) ── ...
│     ├── Thread(0,1) ─── Thread(1,1) ─── Thread(2,1) ── ...
│     ├── Thread(0,2) ─── Thread(1,2) ─── Thread(2,2) ── ...
│     └── ...
│
├── Block(0,1) ─── Block(1,1) ─── Block(2,1) ─── ...
└── ...

硬件映射关系：
  Grid     → 整个GPU（所有SM）
  Block    → 单个SM（一个Block的所有线程在同一SM上执行）
  Warp     → SM的执行引擎（32线程为一组，硬件调度单位）
  Thread   → CUDA Core（单个计算核心）

关键约束：
  Block内线程数 ≤ 1024（MaxThreadsPerBlock）
  Block维度限制：x ≤ 1024, y ≤ 1024, z ≤ 64
  Grid维度限制：x ≤ 2^31-1, y ≤ 65535, z ≤ 65535
  同一Block的线程可以共享内存和同步
  不同Block的线程不能直接通信（需通过全局内存）
```

```cpp
// 1D索引计算 —— 向量操作
__global__ void vector1D(float* data, int N) {
    // 最基本的索引计算
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < N) {
        data[idx] *= 2.0f;
    }
}

// Grid-Stride Loop —— 处理任意大小的数据
// 优势：减少网格启动开销，提高缓存利用率
__global__ void gridStrideLoop(float* data, int N) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int stride = blockDim.x * gridDim.x;

    // 每个线程处理多个元素
    for (int i = idx; i < N; i += stride) {
        data[i] *= 2.0f;
    }
    // 如果N = 1000000, gridDim*blockDim = 65536
    // 每个线程处理约 1000000/65536 ≈ 15 个元素
}

// 2D索引计算 —— 矩阵/图像操作
__global__ void matrix2D(float* matrix, int width, int height) {
    // 2D块和网格
    int col = blockIdx.x * blockDim.x + threadIdx.x;
    int row = blockIdx.y * blockDim.y + threadIdx.y;

    if (col < width && row < height) {
        // 行主序（Row-Major）线性索引
        int linearIdx = row * width + col;
        matrix[linearIdx] *= 2.0f;
    }
}

// 2D Grid-Stride Loop
__global__ void matrix2DStride(float* matrix, int width, int height) {
    int startCol = blockIdx.x * blockDim.x + threadIdx.x;
    int startRow = blockIdx.y * blockDim.y + threadIdx.y;
    int strideX = blockDim.x * gridDim.x;
    int strideY = blockDim.y * gridDim.y;

    for (int row = startRow; row < height; row += strideY) {
        for (int col = startCol; col < width; col += strideX) {
            int idx = row * width + col;
            matrix[idx] *= 2.0f;
        }
    }
}

// 3D索引计算 —— 体数据/3D卷积
__global__ void volume3D(float* volume, int W, int H, int D) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    int z = blockIdx.z * blockDim.z + threadIdx.z;

    if (x < W && y < H && z < D) {
        int idx = z * (H * W) + y * W + x;
        volume[idx] *= 2.0f;
    }
}

// 内核启动配置的最佳实践
void launchExamples() {
    int N = 1000000;  // 1M elements

    // 1D启动
    int blockSize = 256;  // 经验值：128或256通常最优
    int gridSize = (N + blockSize - 1) / blockSize;
    vector1D<<<gridSize, blockSize>>>(data, N);

    // Grid-Stride Loop —— 限制grid大小
    int numSMs;
    cudaDeviceGetAttribute(&numSMs,
        cudaDevAttrMultiProcessorCount, 0);
    // 每SM分配足够的Block以满足Occupancy
    gridSize = 32 * numSMs;  // 经验值：每SM 32个Block
    gridStrideLoop<<<gridSize, blockSize>>>(data, N);

    // 2D启动 (1024x1024矩阵)
    int width = 1024, height = 1024;
    dim3 block2D(16, 16);  // 16*16 = 256 threads
    dim3 grid2D(
        (width + block2D.x - 1) / block2D.x,   // = 64
        (height + block2D.y - 1) / block2D.y    // = 64
    );
    matrix2D<<<grid2D, block2D>>>(matrix, width, height);

    // 3D启动
    int W = 128, H = 128, D = 128;
    dim3 block3D(8, 8, 8);  // 8*8*8 = 512 threads
    dim3 grid3D(
        (W + 7) / 8,
        (H + 7) / 8,
        (D + 7) / 8
    );
    volume3D<<<grid3D, block3D>>>(volume, W, H, D);
}
```

#### 2.3 内核函数编写规范

编写高质量的CUDA内核需要遵循一系列规范和最佳实践。

```cpp
// 完整的CUDA内核编写范式

// 1. 边界检查 —— 必须！
__global__ void safeKernel(float* data, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= n) return;  // 边界检查，防止越界访问
    data[idx] *= 2.0f;
}

// 2. 避免使用动态分配 —— GPU上new/malloc效率极低
__global__ void badKernel() {
    // ✗ 避免！GPU上的malloc非常慢
    // float* local_data = (float*)malloc(100 * sizeof(float));
    // free(local_data);

    // ✓ 使用固定大小的局部数组
    float local_data[100];  // 编译器分配到寄存器或本地内存
}

// 3. 内核参数传递 —— 通过常量内存，最大4KB
struct KernelParams {
    float alpha;
    float beta;
    int width;
    int height;
    // 不要传递大量数据作为参数！
    // 大数据应该通过指针传递（数据在设备全局内存中）
};

__global__ void paramKernel(float* data, KernelParams params) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < params.width * params.height) {
        data[idx] = data[idx] * params.alpha + params.beta;
    }
}

// 4. 避免线程间竞争
__global__ void raceConditionDemo(int* counter) {
    // ✗ 数据竞争！多个线程同时写入同一位置
    // *counter += 1;

    // ✓ 使用原子操作
    atomicAdd(counter, 1);
}

// 5. 内核内的数学函数
__global__ void mathFunctions(float* data, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= n) return;

    float x = data[idx];

    // 单精度数学函数（推荐）
    float y = sinf(x);       // 不要用 sin()，那是双精度版
    y += cosf(x);
    y += expf(x);
    y += logf(x);
    y += sqrtf(x);
    y += rsqrtf(x);          // 1/sqrt(x)，GPU有专用硬件
    y += fmaf(x, x, 1.0f);   // fused multiply-add: x*x + 1

    // 快速数学函数（精度略低，但更快）
    y += __sinf(x);    // 使用SFU，约1 cycle
    y += __cosf(x);
    y += __expf(x);
    y += __logf(x);

    // 编译选项 --use_fast_math 会全局替换为快速版本

    data[idx] = y;
}

// 6. 动态共享内存
__global__ void dynamicSharedMem(float* data, int n) {
    // 动态分配的共享内存（大小在启动时指定）
    extern __shared__ float sharedData[];

    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int tid = threadIdx.x;

    if (idx < n) {
        sharedData[tid] = data[idx];
    }
    __syncthreads();

    // 使用共享内存进行计算...
    if (idx < n && tid > 0) {
        data[idx] = sharedData[tid] + sharedData[tid - 1];
    }
}

// 启动时指定动态共享内存大小
void launchDynamic() {
    int blockSize = 256;
    int sharedBytes = blockSize * sizeof(float);
    dynamicSharedMem<<<grid, blockSize, sharedBytes>>>(data, n);
}
```

#### 2.4 设备内存管理（malloc/free/memcpy）

CUDA的设备内存管理是GPU编程的基础。理解不同类型的内存分配和传输方式对性能至关重要。

```cpp
#include <cuda_runtime.h>
#include <stdio.h>

// ═══════════════════════════════════════════
// 内存分配与释放
// ═══════════════════════════════════════════

void memoryAllocationExamples() {
    const int N = 1024 * 1024;
    const size_t bytes = N * sizeof(float);

    // 1. 基本设备内存分配
    float* d_data;
    cudaMalloc(&d_data, bytes);           // 分配
    cudaMemset(d_data, 0, bytes);         // 清零
    cudaFree(d_data);                     // 释放

    // 2. 主机内存 —— 普通分配（pageable memory）
    float* h_pageable = new float[N];
    // 数据传输时需要先拷贝到 pinned staging buffer

    // 3. 主机内存 —— 固定内存（pinned/page-locked memory）
    float* h_pinned;
    cudaMallocHost(&h_pinned, bytes);
    // 优势：传输速度更快（DMA直接访问，无需staging）
    //       可以与内核执行异步重叠
    // 劣势：分配和释放更慢，减少可用系统内存
    cudaFreeHost(h_pinned);

    // 4. 2D内存分配（自动对齐pitch）
    float* d_2d;
    size_t pitch;  // 实际每行字节数（可能大于 width*sizeof(float)）
    int width = 1024, height = 768;
    cudaMallocPitch(&d_2d, &pitch, width * sizeof(float), height);
    // pitch确保每行首地址满足合并访问的对齐要求
    // 访问元素：((float*)((char*)d_2d + row * pitch))[col]
    cudaFree(d_2d);

    // 5. 3D内存分配
    cudaPitchedPtr d_3d;
    cudaExtent extent = make_cudaExtent(
        width * sizeof(float), height, 64  // depth
    );
    cudaMalloc3D(&d_3d, extent);
    cudaFree(d_3d.ptr);
}

// ═══════════════════════════════════════════
// 数据传输
// ═══════════════════════════════════════════

void memoryTransferExamples() {
    const int N = 1024 * 1024;
    const size_t bytes = N * sizeof(float);

    float* h_data = new float[N];
    float* d_data;
    cudaMalloc(&d_data, bytes);

    // 1. 同步传输（阻塞直到完成）
    cudaMemcpy(d_data, h_data, bytes, cudaMemcpyHostToDevice);  // H→D
    cudaMemcpy(h_data, d_data, bytes, cudaMemcpyDeviceToHost);  // D→H

    // 2. 设备间传输
    float* d_data2;
    cudaMalloc(&d_data2, bytes);
    cudaMemcpy(d_data2, d_data, bytes, cudaMemcpyDeviceToDevice); // D→D

    // 3. 异步传输（需要pinned memory + stream）
    float* h_pinned;
    cudaMallocHost(&h_pinned, bytes);
    cudaStream_t stream;
    cudaStreamCreate(&stream);

    cudaMemcpyAsync(d_data, h_pinned, bytes,
                    cudaMemcpyHostToDevice, stream);
    // CPU不会等待，立即继续执行
    // 传输与后续内核可以重叠

    cudaStreamSynchronize(stream);  // 等待完成
    cudaStreamDestroy(stream);
    cudaFreeHost(h_pinned);

    // 清理
    cudaFree(d_data);
    cudaFree(d_data2);
    delete[] h_data;
}

// ═══════════════════════════════════════════
// Pinned Memory的性能影响
// ═══════════════════════════════════════════

void pinnedMemoryBenchmark() {
    const size_t bytes = 256 * 1024 * 1024;  // 256MB

    float *h_pageable, *h_pinned, *d_data;

    h_pageable = (float*)malloc(bytes);
    cudaMallocHost(&h_pinned, bytes);
    cudaMalloc(&d_data, bytes);

    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    // 测试 pageable memory 传输速度
    cudaEventRecord(start);
    cudaMemcpy(d_data, h_pageable, bytes, cudaMemcpyHostToDevice);
    cudaEventRecord(stop);
    cudaEventSynchronize(stop);
    float pageableTime;
    cudaEventElapsedTime(&pageableTime, start, stop);

    // 测试 pinned memory 传输速度
    cudaEventRecord(start);
    cudaMemcpy(d_data, h_pinned, bytes, cudaMemcpyHostToDevice);
    cudaEventRecord(stop);
    cudaEventSynchronize(stop);
    float pinnedTime;
    cudaEventElapsedTime(&pinnedTime, start, stop);

    printf("Pageable: %.2f ms (%.2f GB/s)\n",
           pageableTime, bytes / (pageableTime * 1e6));
    printf("Pinned:   %.2f ms (%.2f GB/s)\n",
           pinnedTime, bytes / (pinnedTime * 1e6));
    printf("Speedup:  %.2fx\n", pageableTime / pinnedTime);
    // 典型结果：Pinned比Pageable快1.5-2x

    free(h_pageable);
    cudaFreeHost(h_pinned);
    cudaFree(d_data);
    cudaEventDestroy(start);
    cudaEventDestroy(stop);
}
```

#### 2.5 统一内存（Unified Memory）

统一内存（Unified Memory / Managed Memory）提供了CPU和GPU共享的单一地址空间，由驱动自动处理数据迁移。

```
统一内存的工作原理：

显式内存管理：                     统一内存：
┌──────────┐  ┌──────────┐      ┌──────────────────────┐
│ CPU内存   │  │ GPU内存   │      │     统一地址空间      │
│ h_data   │  │ d_data   │      │     managed_data     │
└──────────┘  └──────────┘      └──────────────────────┘
     │              │                      │
     │  cudaMemcpy  │               CPU访问时：
     │───────────→│               页面自动迁移到CPU内存
     │              │               GPU访问时：
     │←───────────│               页面自动迁移到GPU内存
     │              │                      │
程序员手动管理数据传输            运行时自动管理页面迁移

页面迁移机制（类似虚拟内存的缺页机制）：
1. CPU访问managed_data[i]
2. 如果该页面在GPU内存 → 触发页面迁移 → 移到CPU
3. GPU访问managed_data[i]
4. 如果该页面在CPU内存 → 触发页面迁移 → 移到GPU
5. 页面大小通常为 4KB 或 64KB（GPU页面可以更大）
```

```cpp
#include <cuda_runtime.h>
#include <stdio.h>

// ═══════════════════════════════════════════
// 统一内存基础用法
// ═══════════════════════════════════════════

__global__ void addOne(float* data, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < n) {
        data[idx] += 1.0f;
    }
}

void unifiedMemoryBasic() {
    const int N = 1024 * 1024;

    // 分配统一内存 —— CPU和GPU都可以通过同一指针访问
    float* data;
    cudaMallocManaged(&data, N * sizeof(float));

    // CPU端初始化 —— 直接使用指针，无需cudaMemcpy
    for (int i = 0; i < N; i++) {
        data[i] = (float)i;
    }

    // GPU端计算 —— 同一指针直接传递
    int blockSize = 256;
    int gridSize = (N + blockSize - 1) / blockSize;
    addOne<<<gridSize, blockSize>>>(data, N);

    // 等待GPU完成
    cudaDeviceSynchronize();

    // CPU端验证 —— 直接读取，无需cudaMemcpy
    bool correct = true;
    for (int i = 0; i < N; i++) {
        if (data[i] != (float)i + 1.0f) {
            correct = false;
            break;
        }
    }
    printf("Result: %s\n", correct ? "PASS" : "FAIL");

    // 释放
    cudaFree(data);  // 注意：用cudaFree而不是free
}

// ═══════════════════════════════════════════
// 统一内存优化：预取和提示
// ═══════════════════════════════════════════

void unifiedMemoryOptimized() {
    const int N = 1024 * 1024;
    const size_t bytes = N * sizeof(float);

    float* data;
    cudaMallocManaged(&data, bytes);

    int device;
    cudaGetDevice(&device);

    // 初始化（CPU端）
    for (int i = 0; i < N; i++) data[i] = (float)i;

    // 预取到GPU —— 减少按需迁移的延迟
    cudaMemPrefetchAsync(data, bytes, device);  // 预取到GPU
    // 这会触发批量传输，比按需迁移高效得多

    // GPU计算
    addOne<<<(N+255)/256, 256>>>(data, N);

    // 预取回CPU —— 在GPU计算完成后
    cudaMemPrefetchAsync(data, bytes, cudaCpuDeviceId);

    cudaDeviceSynchronize();

    // CPU验证（数据已经在CPU端，无需等待迁移）
    printf("data[0] = %f\n", data[0]);

    // 内存使用提示
    // cudaMemAdvise(data, bytes, cudaMemAdviseSetReadMostly, device);
    // → 提示运行时该数据主要是只读的，可以在CPU和GPU都保留副本

    // cudaMemAdvise(data, bytes, cudaMemAdviseSetPreferredLocation, device);
    // → 提示数据应尽量留在GPU内存中

    // cudaMemAdvise(data, bytes, cudaMemAdviseSetAccessedBy, device);
    // → 提示该设备会频繁访问此数据

    cudaFree(data);
}

// ═══════════════════════════════════════════
// 统一内存 vs 显式内存管理：何时用哪个？
// ═══════════════════════════════════════════

/*
选择指南：

统一内存适合：
  ✓ 快速原型开发（减少代码量）
  ✓ 复杂数据结构（链表、树、图）—— 指针自动有效
  ✓ 数据访问模式不可预测
  ✓ 代码可维护性优先的场景

显式内存管理适合：
  ✓ 性能关键路径（精确控制传输时机）
  ✓ 计算与传输需要重叠
  ✓ 大批量数据的流水线处理
  ✓ 需要使用pinned memory的场景

性能对比（典型场景）：
  ┌────────────────────────────┬────────┬────────┐
  │ 场景                       │ 显式    │ 统一    │
  ├────────────────────────────┼────────┼────────┤
  │ 首次GPU访问（冷启动）       │ 1x     │ 1.5-2x │
  │ 反复GPU访问（热路径）       │ 1x     │ ~1x    │
  │ CPU-GPU乒乓访问            │ 1x     │ 3-10x  │
  │ 纯GPU计算（无回传）         │ 1x     │ ~1x    │
  └────────────────────────────┴────────┴────────┘
  注：>1x 表示统一内存更慢
*/
```

#### 2.6 HIP编程与CUDA可移植性

HIP（Heterogeneous-computing Interface for Portability）是AMD提供的GPU编程接口，API设计几乎完全对标CUDA，实现了代码的跨平台可移植性。

```
CUDA → HIP 核心API映射：

┌──────────────────────────┬──────────────────────────┐
│  CUDA                     │  HIP                      │
├──────────────────────────┼──────────────────────────┤
│  cudaMalloc               │  hipMalloc                │
│  cudaFree                 │  hipFree                  │
│  cudaMemcpy               │  hipMemcpy                │
│  cudaMemcpyAsync          │  hipMemcpyAsync           │
│  cudaMallocHost           │  hipHostMalloc            │
│  cudaFreeHost             │  hipHostFree              │
│  cudaDeviceSynchronize    │  hipDeviceSynchronize     │
│  cudaStreamCreate         │  hipStreamCreate          │
│  cudaEventCreate          │  hipEventCreate           │
│  cudaGetDeviceProperties  │  hipGetDeviceProperties   │
│  cudaSetDevice            │  hipSetDevice             │
│                           │                           │
│  __global__               │  __global__               │
│  __device__               │  __device__               │
│  __shared__               │  __shared__               │
│  __syncthreads()          │  __syncthreads()          │
│  threadIdx.x              │  threadIdx.x (hipThreadIdx_x) │
│  blockIdx.x               │  blockIdx.x  (hipBlockIdx_x)  │
│  blockDim.x               │  blockDim.x  (hipBlockDim_x)  │
│                           │                           │
│  atomicAdd                │  atomicAdd                │
│  __shfl_sync              │  __shfl                   │
│  __ballot_sync            │  __ballot                 │
│                           │                           │
│  cuBLAS                   │  rocBLAS                  │
│  cuDNN                    │  MIOpen                   │
│  cuFFT                    │  rocFFT                   │
│  Thrust                   │  rocThrust                │
└──────────────────────────┴──────────────────────────┘

转换工具：hipify-perl / hipify-clang
  自动将CUDA代码转换为HIP代码
  $ hipify-perl input.cu > output.hip.cpp
```

```cpp
// 跨平台GPU代码示例

// 方法1：使用HIP编写（在NVIDIA上通过HIP头文件转换为CUDA调用）
#include <hip/hip_runtime.h>

__global__ void vectorAddHIP(const float* a, const float* b,
                              float* c, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < n) {
        c[idx] = a[idx] + b[idx];
    }
}

void runHIP() {
    const int N = 1024 * 1024;
    const size_t bytes = N * sizeof(float);

    float *d_a, *d_b, *d_c;
    hipMalloc(&d_a, bytes);
    hipMalloc(&d_b, bytes);
    hipMalloc(&d_c, bytes);

    // HIP使用hipLaunchKernelGGL宏或<<<>>>语法
    hipLaunchKernelGGL(vectorAddHIP,
                       dim3((N+255)/256), dim3(256),
                       0, 0,  // shared mem, stream
                       d_a, d_b, d_c, N);
    // 或者直接使用<<<>>>（需要编译器支持）
    // vectorAddHIP<<<(N+255)/256, 256>>>(d_a, d_b, d_c, N);

    hipDeviceSynchronize();
    hipFree(d_a);
    hipFree(d_b);
    hipFree(d_c);
}

// 方法2：使用预处理器条件编译
#ifdef __CUDACC__
    #define GPU_MALLOC      cudaMalloc
    #define GPU_FREE        cudaFree
    #define GPU_MEMCPY      cudaMemcpy
    #define GPU_SYNC        cudaDeviceSynchronize
    #define H2D             cudaMemcpyHostToDevice
    #define D2H             cudaMemcpyDeviceToHost
#elif defined(__HIP_PLATFORM_AMD__) || defined(__HIP_PLATFORM_NVIDIA__)
    #define GPU_MALLOC      hipMalloc
    #define GPU_FREE        hipFree
    #define GPU_MEMCPY      hipMemcpy
    #define GPU_SYNC        hipDeviceSynchronize
    #define H2D             hipMemcpyHostToDevice
    #define D2H             hipMemcpyDeviceToHost
#endif

// 方法3：使用SYCL作为跨平台抽象层（参见上月学习内容）
```

```
CUDA与HIP的关键差异：

┌──────────────────────────────────────────────────────────┐
│  差异点                    │ 影响                         │
├──────────────────────────────────────────────────────────┤
│  Warp大小:                 │                              │
│  NVIDIA = 32 threads       │ 影响Warp级原语参数            │
│  AMD = 64 threads (wave)   │ 影响共享内存bank数            │
│  (AMD也支持wave32模式)     │ 影响向量化策略                │
├──────────────────────────────────────────────────────────┤
│  共享内存bank数:           │                              │
│  NVIDIA = 32 banks         │ 影响bank冲突分析              │
│  AMD = 32 banks (CDNA)     │ 内存访问模式可能不同          │
├──────────────────────────────────────────────────────────┤
│  寄存器文件:               │                              │
│  NVIDIA: 统一寄存器文件    │ HIP使用VGPR(向量)+SGPR(标量) │
│  AMD: VGPR + SGPR          │ AMD可更高效处理标量操作       │
├──────────────────────────────────────────────────────────┤
│  同步原语:                 │                              │
│  CUDA: __syncwarp(mask)    │ HIP: __syncthreads()         │
│  需要指定mask参数          │ mask参数在HIP中是可选的       │
└──────────────────────────────────────────────────────────┘
```

#### 2.7 PTX中间表示与编译流程

理解CUDA的编译流程和PTX中间表示有助于深入理解GPU代码的执行机制和性能调优。

```
CUDA编译流程：

源代码(.cu)
    │
    ▼
┌──────────────┐
│   nvcc       │  NVIDIA CUDA Compiler
│  编译驱动器   │  分离主机代码和设备代码
└──────┬───────┘
       │
  ┌────┴────┐
  │         │
  ▼         ▼
┌────────┐ ┌────────┐
│ 主机   │ │ 设备   │
│ 代码   │ │ 代码   │
│ (.cpp) │ │ (.cu)  │
└───┬────┘ └───┬────┘
    │          │
    ▼          ▼
┌────────┐ ┌────────┐
│ gcc/g++│ │ cicc   │  CUDA前端编译器
│ clang  │ │        │
└───┬────┘ └───┬────┘
    │          │
    │          ▼
    │     ┌────────┐
    │     │  PTX   │  并行线程执行 (虚拟ISA)
    │     │ (.ptx) │  可移植的中间表示
    │     └───┬────┘
    │         │
    │         ▼
    │     ┌────────┐
    │     │ ptxas  │  PTX汇编器
    │     │        │  目标架构特定
    │     └───┬────┘
    │         │
    │         ▼
    │     ┌────────┐
    │     │ SASS   │  GPU机器码（特定架构）
    │     │(.cubin)│  例如 sm_80 (Ampere)
    │     └───┬────┘
    │         │
    ▼         ▼
┌─────────────────┐
│   fatbin        │  包含PTX和/或SASS
│  (嵌入到       │  支持多架构的胖二进制
│   可执行文件)   │
└─────────────────┘

常用nvcc选项：
  nvcc -arch=sm_80           # 目标架构 (Ampere)
  nvcc -gencode arch=compute_80,code=sm_80  # 更精确控制
  nvcc --ptx                 # 只生成PTX
  nvcc --keep                # 保留中间文件
  nvcc -Xptxas -v            # 显示寄存器/共享内存使用
  nvcc --use_fast_math       # 使用快速数学库
  nvcc -O3                   # 优化级别
  nvcc -lineinfo             # 保留行号信息(profiling用)
```

```
PTX基本语法示例：

// PTX是基于寄存器的虚拟ISA
// 类型：.u32(无符号32位)、.f32(单精度浮点)、.pred(谓词)

// 向量加法的PTX表示（简化）：
.visible .entry vectorAdd(
    .param .u64 .ptr .global .align 4 a,
    .param .u64 .ptr .global .align 4 b,
    .param .u64 .ptr .global .align 4 c,
    .param .u32 n
) {
    .reg .u32 %tid, %bid, %bdim, %idx;     // 整数寄存器
    .reg .f32 %fa, %fb, %fc;                // 浮点寄存器
    .reg .pred %p;                           // 谓词寄存器
    .reg .u64 %addr_a, %addr_b, %addr_c;   // 64位地址

    // idx = blockIdx.x * blockDim.x + threadIdx.x
    mov.u32 %tid, %tid.x;
    mov.u32 %bid, %ctaid.x;
    mov.u32 %bdim, %ntid.x;
    mad.lo.u32 %idx, %bid, %bdim, %tid;     // idx = bid * bdim + tid

    // if (idx >= n) return;
    ld.param.u32 %n, [n];
    setp.ge.u32 %p, %idx, %n;
    @%p bra END;

    // 计算地址并加载
    cvt.u64.u32 %addr_offset, %idx;
    shl.b64 %addr_offset, %addr_offset, 2;  // *4 (sizeof float)

    ld.param.u64 %addr_a, [a];
    add.u64 %addr_a, %addr_a, %addr_offset;
    ld.global.f32 %fa, [%addr_a];

    ld.param.u64 %addr_b, [b];
    add.u64 %addr_b, %addr_b, %addr_offset;
    ld.global.f32 %fb, [%addr_b];

    // c[idx] = a[idx] + b[idx]
    add.f32 %fc, %fa, %fb;

    ld.param.u64 %addr_c, [c];
    add.u64 %addr_c, %addr_c, %addr_offset;
    st.global.f32 [%addr_c], %fc;

END:
    ret;
}

// 查看编译后的资源使用：
// $ nvcc -Xptxas -v kernel.cu
// 输出示例：
// ptxas info: Used 8 registers, 0 bytes shared memory
// ptxas info: Function properties for vectorAdd
//   8 bytes stack frame, 0 bytes spill stores, 0 bytes spill loads
```

```cpp
// 查看PTX和SASS的实用方法

// 1. 编译时生成PTX
// $ nvcc --ptx -arch=sm_80 kernel.cu -o kernel.ptx

// 2. 查看SASS（实际GPU汇编）
// $ cuobjdump --dump-sass ./a.out

// 3. 在代码中嵌入PTX（内联PTX汇编）
__device__ float warpReduceSum(float val) {
    // 使用内联PTX实现Warp归约
    for (int offset = 16; offset > 0; offset >>= 1) {
        // shfl.sync.bfly 是PTX指令
        asm volatile(
            "{"
            ".reg .f32 r0;"
            "shfl.sync.bfly.b32 r0, %1, %2, 0x1f, 0xffffffff;"
            "add.f32 %0, %1, r0;"
            "}"
            : "=f"(val)
            : "f"(val), "r"(offset)
        );
    }
    return val;
}

// 4. JIT编译 —— 运行时从PTX编译
// PTX是前向兼容的：为compute_70编译的PTX可以在sm_80上JIT编译
// 这就是为什么fatbin中通常包含PTX（保证未来兼容性）
```

#### 2.8 本周练习任务

1. **完整的向量运算库** —— 实现一个包含以下操作的CUDA向量库：(a) 向量加法；(b) 向量点积（使用归约）；(c) SAXPY（y = a*x + y）；(d) 向量范数。每个操作使用Grid-Stride Loop模式，支持任意大小的输入。

2. **2D矩阵操作** —— 实现矩阵加法和矩阵缩放，使用2D线程块和网格。支持任意大小的矩阵（不仅是2的幂次）。使用`cudaMallocPitch`分配2D内存并正确计算pitch偏移。

3. **统一内存对比实验** —— 编写同一个计算任务（如大数组平方和），分别用三种方式实现：(a) 显式`cudaMalloc`+`cudaMemcpy`；(b) `cudaMallocManaged`（无预取）；(c) `cudaMallocManaged`+`cudaMemPrefetchAsync`。使用CUDA事件计时，对比三种方式的性能。

4. **CUDA→HIP移植练习** —— 将你的向量加法程序用`hipify-perl`工具转换为HIP代码。阅读转换后的代码，理解API映射。如果有AMD GPU，编译并运行HIP版本；否则在NVIDIA GPU上使用HIP头文件编译。

5. **PTX分析** —— 编译一个简单的内核为PTX（`nvcc --ptx`），阅读生成的PTX代码，标注每条PTX指令对应的C代码行。修改内核（如添加分支），观察PTX代码的变化。

6. **错误处理框架** —— 实现一个完善的CUDA错误处理工具类，包括：同步错误检查宏、异步错误检查（`cudaGetLastError`+`cudaDeviceSynchronize`）、使用`compute-sanitizer`（替代已弃用的`cuda-memcheck`）检测越界访问。

#### 2.9 本周知识检验

- [ ] 能画出CUDA程序的完整执行流程图（分配→传输→计算→同步→回传→释放）
- [ ] 能正确计算1D/2D/3D网格中线程的全局索引
- [ ] 理解Grid-Stride Loop的优势，能解释为什么它比一次性映射更好
- [ ] 能解释`__global__`、`__device__`、`__host__`函数修饰符的含义和限制
- [ ] 掌握pinned memory与pageable memory的性能差异及原因
- [ ] 能解释统一内存的页迁移机制，知道何时用`cudaMemPrefetchAsync`
- [ ] 能将CUDA代码转换为HIP代码（手动或使用hipify工具）
- [ ] 理解CUDA编译流程：`.cu` → PTX → SASS/cubin
- [ ] 能阅读基本的PTX代码，理解寄存器分配和指令格式
- [ ] 知道如何使用`nvcc -Xptxas -v`查看内核资源使用情况

---

### 第三周：内存优化（35小时）

**学习目标**：
- [ ] 深入理解全局内存合并访问的硬件机制：内存事务粒度（32B/64B/128B）、地址对齐要求、Warp内线程访问模式如何影响事务数量
- [ ] 精通共享内存的Bank架构：32个Bank的映射规则、Bank冲突的产生条件、N-way冲突的串行化代价，掌握padding等消除策略
- [ ] 掌握常量内存和纹理内存的适用场景：常量内存的广播机制、纹理缓存的2D空间局部性优化
- [ ] 理解寄存器压力及其对Occupancy的影响：寄存器分配机制、溢出到本地内存的代价、`__launch_bounds__`的使用策略
- [ ] 精通AoS vs SoA数据布局变换：能分析给定数据结构的内存访问效率，设计最优的GPU数据布局
- [ ] 掌握内存对齐与向量化加载（`float4`/`int4`/`__ldg`）：理解128位加载指令如何提升全局内存带宽利用率
- [ ] 能使用Nsight Compute分析内存访问模式：读懂Memory Workload Analysis报告，识别合并率、Bank冲突、L1/L2命中率

**阅读材料**：
- [ ] CUDA C++ Programming Guide, Chapter 5（Memory Hierarchy）
- [ ] CUDA C++ Best Practices Guide, Chapters 9-12（Memory Optimizations）
- [ ] 《Professional CUDA C Programming》- Cheng et al., Chapters 5-6（Memory Model）
- [ ] 《Programming Massively Parallel Processors》- Kirk & Hwu, Chapters 5-7（Tiling, Memory Coalescing）
- [ ] "Dissecting GPU Memory Hierarchy through Microbenchmarking" - Mei & Chu (2017)
- [ ] NVIDIA Developer Blog: "How to Access Global Memory Efficiently" - Mark Harris
- [ ] NVIDIA Developer Blog: "Using Shared Memory in CUDA C/C++" - Mark Harris
- [ ] GTC 2020: "Optimizing GPU Memory Transactions" - Stephen Jones (NVIDIA)
- [ ] "Roofline: An Insightful Visual Performance Model" - Williams, Waterman, Patterson (2009)
- [ ] Nsight Compute Documentation: Memory Workload Analysis

---

#### 核心概念

**GPU内存优化策略总览**

```
GPU性能优化的三大支柱：

1. 最大化并行度（Occupancy优化）
   → 足够多的活跃Warp来隐藏延迟

2. 最大化内存吞吐量（本周重点）
   → 合并访问 + 减少事务数 + 利用缓存
   ┌──────────────────────────────────────────────────┐
   │  优化目标：                                       │
   │  • 全局内存：提高合并率（coalescing ratio）       │
   │  • 共享内存：消除bank冲突                         │
   │  • 寄存器：减少溢出（register spill）             │
   │  • 缓存：提高L1/L2命中率                         │
   │  • 数据布局：AoS → SoA 变换                      │
   │  • 向量化：使用float4/int4宽负载                  │
   └──────────────────────────────────────────────────┘

3. 最大化指令吞吐量
   → 消除分支分歧 + 使用快速数学 + 指令级并行
```

#### 3.1 全局内存合并访问深入

全局内存合并访问是GPU内存优化中最重要的概念。一个Warp的32个线程同时发出内存请求，硬件会尝试将它们合并为尽可能少的内存事务。

```
合并访问的硬件机制：

GPU内存控制器以固定粒度的内存段（segment）为单位访问DRAM
NVIDIA GPU的L1缓存行大小 = 128字节

一个Warp的32个线程发出32个float(4B)请求 = 128字节
理想情况：恰好对齐到一个128B缓存行 → 1次内存事务
最坏情况：分散到32个不同缓存行 → 32次内存事务

┌──────────────────────────────────────────────────────────┐
│  合并访问示例（连续、对齐）：                              │
│                                                            │
│  Thread:  T0  T1  T2  T3  T4  T5  ... T31                │
│  Address: 0   4   8   12  16  20      124                 │
│           └──────────────────────────────┘                │
│           一个128字节的连续区域                             │
│           → 1次内存事务 ✓                                  │
│                                                            │
│  跨步访问示例（stride=2）：                                │
│  Thread:  T0  T1   T2   T3   T4   ... T31                │
│  Address: 0   8    16   24   32       248                 │
│           └─────────────────────────────────┘             │
│           横跨256字节 → 2次128B事务 ✗                      │
│           带宽利用率 = 50%                                 │
│                                                            │
│  跨步访问（stride=32）：                                   │
│  Thread:  T0    T1    T2    ... T31                        │
│  Address: 0     128   256       3968                       │
│           每个线程在不同的缓存行！                          │
│           → 32次事务 ✗✗✗                                   │
│           带宽利用率 = 4/128 = 3.125%                      │
│                                                            │
│  随机访问：                                                │
│  Thread:  T0     T1      T2     ... T31                   │
│  Address: 41772  8388    91204      12560                  │
│           完全随机 → 最坏32次事务 ✗✗✗                      │
│           带宽利用率取决于碰巧的地址重叠                    │
└──────────────────────────────────────────────────────────┘
```

```cpp
// 合并访问实验代码

#include <cuda_runtime.h>
#include <stdio.h>

// ═══════════════════════════════════════════
// 实验1：不同跨步的内存访问
// ═══════════════════════════════════════════

template<int STRIDE>
__global__ void stridedCopy(float* dst, const float* src, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int strided_idx = idx * STRIDE;
    if (strided_idx < n) {
        dst[strided_idx] = src[strided_idx];
    }
}

void benchmarkStrides() {
    const int N = 32 * 1024 * 1024;  // 128MB
    float *d_src, *d_dst;
    cudaMalloc(&d_src, N * sizeof(float));
    cudaMalloc(&d_dst, N * sizeof(float));

    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    int blockSize = 256;
    int iterations = 100;

    printf("Stride | Bandwidth (GB/s) | Efficiency\n");
    printf("-------|------------------|----------\n");

    // 测试不同跨步
    auto test = [&](int stride, auto kernel) {
        int elements = N / stride;
        int gridSize = (elements + blockSize - 1) / blockSize;

        // Warmup
        kernel<<<gridSize, blockSize>>>(d_dst, d_src, N);
        cudaDeviceSynchronize();

        cudaEventRecord(start);
        for (int i = 0; i < iterations; i++) {
            kernel<<<gridSize, blockSize>>>(d_dst, d_src, N);
        }
        cudaEventRecord(stop);
        cudaEventSynchronize(stop);

        float ms;
        cudaEventElapsedTime(&ms, start, stop);
        ms /= iterations;

        // 实际传输字节数（每次读写各elements个float）
        double bytes = 2.0 * elements * sizeof(float);
        double bandwidth = bytes / (ms * 1e6);

        printf("%5d  | %16.1f | %5.1f%%\n",
               stride, bandwidth,
               bandwidth / 2039.0 * 100.0);  // A100理论峰值
    };

    test(1, stridedCopy<1>);    // 连续：~高带宽
    test(2, stridedCopy<2>);    // stride 2：~50%
    test(4, stridedCopy<4>);    // stride 4：~25%
    test(8, stridedCopy<8>);    // stride 8：~12.5%
    test(16, stridedCopy<16>);  // stride 16：~6.25%
    test(32, stridedCopy<32>);  // stride 32：~3.125%

    cudaFree(d_src);
    cudaFree(d_dst);
    cudaEventDestroy(start);
    cudaEventDestroy(stop);
}

// ═══════════════════════════════════════════
// 向量化加载（float4）提升带宽利用
// ═══════════════════════════════════════════

// 普通float加载
__global__ void copyFloat1(float* dst, const float* src, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < n) {
        dst[idx] = src[idx];
    }
}

// float4向量化加载 —— 每个线程一次加载128位
__global__ void copyFloat4(float4* dst, const float4* src, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < n) {
        dst[idx] = src[idx];  // 128位加载，带宽利用更高
    }
}

// __ldg() —— 通过只读数据缓存加载（Kepler+）
__global__ void copyLdg(float* dst, const float* __restrict__ src, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < n) {
        // __ldg通过纹理缓存路径加载，减少L1压力
        dst[idx] = __ldg(&src[idx]);
    }
}
```

#### 3.2 共享内存与Bank冲突

共享内存是GPU上程序员可显式控制的低延迟高带宽内存。但其Bank架构意味着不当的访问模式会导致严重的性能下降。

```
共享内存Bank架构：

共享内存被划分为32个等宽Bank（每个Bank宽4字节）
连续的32位字映射到连续的Bank

地址映射规则：
  Bank编号 = (字节地址 / 4) % 32

地址:  0    4    8    12   16   ...  124
Bank:  B0   B1   B2   B3   B4   ...  B31
       ↓    ↓    ↓    ↓    ↓         ↓
地址:  128  132  136  140  144  ...  252
Bank:  B0   B1   B2   B3   B4   ...  B31

三种访问场景：

1. 无冲突 —— 每个线程访问不同Bank
   ┌────────────────────────────────────┐
   │  T0→B0  T1→B1  T2→B2 ... T31→B31 │
   │  32个线程访问32个不同Bank           │
   │  结果：1次内存事务，~5 cycles       │
   └────────────────────────────────────┘

2. Bank冲突 —— 多个线程访问同一Bank的不同行
   ┌────────────────────────────────────┐
   │  T0→B0  T1→B0  T2→B0 ... 全部→B0 │
   │  32个线程都访问Bank 0              │
   │  结果：32-way冲突，串行化          │
   │  延迟 = 32 × ~5 cycles = ~160 cyc │
   └────────────────────────────────────┘

3. 广播 —— 多个线程读同一Bank的同一地址
   ┌────────────────────────────────────┐
   │  T0→B0[0] T1→B0[0] ... 全部→B0[0]│
   │  所有线程读取同一地址              │
   │  结果：硬件广播，无冲突！~5 cycles │
   │  （仅限读操作，写操作仍然冲突）    │
   └────────────────────────────────────┘

常见Bank冲突场景与解决方案：

Stride=2 访问 → 2-way冲突：
  T0→B0  T1→B2  T2→B4 ... T16→B0 (冲突！)
  每两个线程共享一个Bank
  解决：padding或重映射索引

Stride=32 访问 → 32-way冲突（最坏！）：
  T0→B0  T1→B0  T2→B0 ... T31→B0
  所有线程访问同一Bank
  这正是矩阵转置中的问题！
```

```cpp
// ═══════════════════════════════════════════
// Bank冲突示例与解决方案
// ═══════════════════════════════════════════

// 矩阵转置 —— Bank冲突的经典案例
#define TILE_DIM 32

// 版本1：有Bank冲突的转置
__global__ void transposeWithConflict(
    float* output, const float* input, int width, int height
) {
    __shared__ float tile[TILE_DIM][TILE_DIM];  // 32×32

    int x = blockIdx.x * TILE_DIM + threadIdx.x;
    int y = blockIdx.y * TILE_DIM + threadIdx.y;

    // 读入共享内存（合并的全局内存读取）
    if (x < width && y < height) {
        tile[threadIdx.y][threadIdx.x] = input[y * width + x];
    }
    __syncthreads();

    // 写出（转置后）
    x = blockIdx.y * TILE_DIM + threadIdx.x;
    y = blockIdx.x * TILE_DIM + threadIdx.y;

    if (x < height && y < width) {
        // 关键：这里读取 tile[threadIdx.x][threadIdx.y]
        // threadIdx.x 固定时，threadIdx.y 变化 → 跨列访问
        // 列方向stride = 32 → 32-way Bank冲突！
        output[y * height + x] = tile[threadIdx.x][threadIdx.y];
    }
}

// 版本2：无Bank冲突的转置（Padding技巧）
__global__ void transposeNoBankConflict(
    float* output, const float* input, int width, int height
) {
    // 关键优化：33列而不是32列！
    __shared__ float tile[TILE_DIM][TILE_DIM + 1];  // 32×33

    // 多出的1列改变了Bank映射：
    // tile[0][0] → Bank 0
    // tile[1][0] → Bank 33%32 = Bank 1  (而不是Bank 0!)
    // tile[2][0] → Bank 66%32 = Bank 2
    // 列方向访问不再全部落在同一Bank

    int x = blockIdx.x * TILE_DIM + threadIdx.x;
    int y = blockIdx.y * TILE_DIM + threadIdx.y;

    if (x < width && y < height) {
        tile[threadIdx.y][threadIdx.x] = input[y * width + x];
    }
    __syncthreads();

    x = blockIdx.y * TILE_DIM + threadIdx.x;
    y = blockIdx.x * TILE_DIM + threadIdx.y;

    if (x < height && y < width) {
        output[y * height + x] = tile[threadIdx.x][threadIdx.y];
        // 现在是无冲突的！
    }
}

// ═══════════════════════════════════════════
// 共享内存归约（Reduction）
// ═══════════════════════════════════════════

// 版本1：交错归约（有Bank冲突）
__global__ void reduceInterleaved(float* data, float* result, int n) {
    __shared__ float sdata[256];
    int tid = threadIdx.x;
    int idx = blockIdx.x * blockDim.x + threadIdx.x;

    sdata[tid] = (idx < n) ? data[idx] : 0.0f;
    __syncthreads();

    // 交错归约 —— stride逐渐增大
    for (int s = 1; s < blockDim.x; s *= 2) {
        if (tid % (2 * s) == 0) {
            sdata[tid] += sdata[tid + s];
        }
        __syncthreads();
    }
    // 问题：tid%(2*s)==0 导致大量分支分歧
    // 且访问模式随s变化，可能有Bank冲突

    if (tid == 0) result[blockIdx.x] = sdata[0];
}

// 版本2：顺序归约（无Bank冲突 + 无分歧）
__global__ void reduceSequential(float* data, float* result, int n) {
    __shared__ float sdata[256];
    int tid = threadIdx.x;
    int idx = blockIdx.x * blockDim.x + threadIdx.x;

    sdata[tid] = (idx < n) ? data[idx] : 0.0f;
    __syncthreads();

    // 顺序归约 —— 连续线程处理连续数据
    for (int s = blockDim.x / 2; s > 0; s >>= 1) {
        if (tid < s) {
            sdata[tid] += sdata[tid + s];
        }
        __syncthreads();
    }
    // 优势：活跃线程总是连续的 → 无分支分歧
    // 且访问模式对Bank友好

    if (tid == 0) result[blockIdx.x] = sdata[0];
}
```

#### 3.3 常量内存与纹理内存

GPU提供了两种特殊的只读内存类型：常量内存和纹理内存，各有独特的优化场景。

```
常量内存特性：
┌──────────────────────────────────────────────────┐
│  容量：64KB（所有SM共享）                         │
│  缓存：每SM 8-10KB 专用常量缓存                   │
│  延迟：缓存命中 ~5 cycles                         │
│  广播：同一Warp的线程读同一地址 → 1次读取即可      │
│  最佳场景：                                       │
│    • 所有线程读取相同的值（卷积核、物理常数）       │
│    • 小数据量（<64KB）                            │
│    • 只读数据                                     │
│  最差场景：                                       │
│    • 线程读取不同地址 → 串行化！                   │
│    • 每Warp需要32次顺序读取                       │
└──────────────────────────────────────────────────┘

纹理内存特性：
┌──────────────────────────────────────────────────┐
│  缓存：专用纹理缓存（~12KB per SM）               │
│  特点：                                          │
│    • 2D空间局部性优化（Morton/Z-order缓存布局）   │
│    • 硬件插值（线性、双线性、三线性）              │
│    • 自动边界处理（clamp/wrap/mirror）            │
│    • 支持归一化坐标（0.0-1.0）                   │
│  最佳场景：                                       │
│    • 图像处理、体渲染                             │
│    • 2D随机访问模式                               │
│    • 需要插值的查找表                             │
│  现代替代：__ldg()（L1只读数据缓存）              │
└──────────────────────────────────────────────────┘
```

```cpp
// ═══════════════════════════════════════════
// 常量内存使用示例
// ═══════════════════════════════════════════

// 声明常量内存（全局作用域）
__constant__ float c_filter[25];  // 5x5卷积核

// 在主机端设置常量内存
void setupConstantMemory() {
    float h_filter[25];
    // 初始化卷积核...
    for (int i = 0; i < 25; i++) h_filter[i] = 1.0f / 25.0f;

    // 拷贝到常量内存
    cudaMemcpyToSymbol(c_filter, h_filter, 25 * sizeof(float));
}

// 使用常量内存的卷积内核
__global__ void conv2dConstant(
    float* output, const float* input,
    int width, int height
) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    if (x >= width || y >= height) return;

    float sum = 0.0f;
    for (int ky = -2; ky <= 2; ky++) {
        for (int kx = -2; kx <= 2; kx++) {
            int ix = min(max(x + kx, 0), width - 1);
            int iy = min(max(y + ky, 0), height - 1);
            // 所有线程读取同一个filter值 → 常量内存广播
            sum += input[iy * width + ix] *
                   c_filter[(ky + 2) * 5 + (kx + 2)];
        }
    }
    output[y * width + x] = sum;
}

// ═══════════════════════════════════════════
// 纹理内存（现代CUDA纹理对象API）
// ═══════════════════════════════════════════

void textureExample() {
    int width = 1024, height = 1024;

    // 分配CUDA数组（纹理专用内存布局）
    cudaChannelFormatDesc channelDesc =
        cudaCreateChannelDesc<float>();
    cudaArray_t cuArray;
    cudaMallocArray(&cuArray, &channelDesc, width, height);

    // 创建纹理对象
    cudaResourceDesc resDesc = {};
    resDesc.resType = cudaResourceTypeArray;
    resDesc.res.array.array = cuArray;

    cudaTextureDesc texDesc = {};
    texDesc.addressMode[0] = cudaAddressModeClamp;  // 边界处理
    texDesc.addressMode[1] = cudaAddressModeClamp;
    texDesc.filterMode = cudaFilterModeLinear;       // 双线性插值
    texDesc.readMode = cudaReadModeElementType;
    texDesc.normalizedCoords = false;

    cudaTextureObject_t texObj;
    cudaCreateTextureObject(&texObj, &resDesc, &texDesc, nullptr);

    // 在内核中使用纹理
    // float val = tex2D<float>(texObj, x + 0.5f, y + 0.5f);

    // 清理
    cudaDestroyTextureObject(texObj);
    cudaFreeArray(cuArray);
}
```

#### 3.4 寄存器压力与溢出

寄存器是GPU上最快的存储，但其数量有限。每个线程使用的寄存器越多，SM上能并发的Warp就越少，导致Occupancy下降。

```
寄存器分配与Occupancy的关系：

A100 SM寄存器配额：
  总寄存器数：65536个32位寄存器 / SM
  最大Warp数：64 Warps / SM（= 2048 threads）
  每线程最多：255个寄存器

寄存器使用 vs Occupancy 示例：
┌─────────────────┬──────────────────┬───────────┐
│ 每线程寄存器数   │ 最大Warps/SM     │ Occupancy │
├─────────────────┼──────────────────┼───────────┤
│ 32              │ 65536/32/32 = 64 │ 100%      │
│ 48              │ 65536/48/32 = 42 │ 65.6%     │
│ 64              │ 65536/64/32 = 32 │ 50%       │
│ 96              │ 65536/96/32 = 21 │ 32.8%     │
│ 128             │ 65536/128/32 = 16│ 25%       │
│ 255 (最大)      │ 65536/255/32 = 8 │ 12.5%     │
└─────────────────┴──────────────────┴───────────┘

寄存器溢出（Register Spill）：
  当寄存器不够用时，编译器将变量"溢出"到本地内存
  本地内存在物理上位于全局内存中（但经过L1/L2缓存）
  ┌──────────────────────────────────────────────────┐
  │  寄存器访问：~1 cycle                             │
  │  本地内存（L1命中）：~30 cycles                   │
  │  本地内存（L2命中）：~200 cycles                  │
  │  本地内存（未命中）：~400 cycles                  │
  │                                                    │
  │  → 寄存器溢出可能导致30-400x的访问延迟增加！      │
  └──────────────────────────────────────────────────┘
```

```cpp
// ═══════════════════════════════════════════
// 控制寄存器使用的技术
// ═══════════════════════════════════════════

// 1. __launch_bounds__ —— 提示编译器优化寄存器分配
__global__ __launch_bounds__(256, 2)  // 最多256线程/块，每SM至少2个块
void regControlled(float* data, int n) {
    // 编译器知道每SM至少2个块 → 每块最多 65536/(2*256) = 128 寄存器/线程
    // 这允许编译器更好地决定是否溢出
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < n) data[idx] *= 2.0f;
}

// 2. 减少寄存器使用的编码技巧
__global__ void regOptimized(float* data, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= n) return;

    // ✗ 避免：多个独立变量同时存活
    // float a = data[idx];
    // float b = data[idx+1];
    // float c = data[idx+2];
    // float d = a + b + c;

    // ✓ 更好：复用变量，减少同时存活的寄存器数
    float temp = data[idx];
    temp += data[idx + 1];
    temp += data[idx + 2];
    data[idx] = temp;
}

// 3. 使用共享内存替代大局部数组
__global__ void sharedVsLocal(float* input, float* output, int n) {
    // ✗ 大局部数组 → 寄存器溢出到本地内存
    // float buffer[128];

    // ✓ 使用共享内存
    __shared__ float buffer[256];  // 块内所有线程共享
    int tid = threadIdx.x;
    buffer[tid] = input[blockIdx.x * blockDim.x + tid];
    __syncthreads();

    // 使用buffer进行计算...
}

// 4. 查看编译器报告的寄存器使用
// $ nvcc -Xptxas -v kernel.cu
// 输出：ptxas info: Used 24 registers, 4096 bytes shared memory
//
// $ nvcc --resource-usage kernel.cu
// 更详细的资源使用报告
```

#### 3.5 AoS vs SoA数据布局

Array of Structures（AoS）和 Structure of Arrays（SoA）是两种根本不同的数据布局方式。在GPU上，SoA几乎总是比AoS更高效。

```
AoS vs SoA 内存布局对比：

AoS（Array of Structures）：
  内存: [x0 y0 z0] [x1 y1 z1] [x2 y2 z2] [x3 y3 z3] ...
        ├──────────┤
         一个粒子的所有属性在一起

  Thread 0 读 x0: 加载 [x0 y0 z0 x1] 的128B事务
  Thread 1 读 x1: 加载 [y0 z0 x1 y1] 的128B事务
  Thread 2 读 x2: 加载 [z1 x2 y2 z2] 的128B事务
  → 每次只用到 4/12 = 33% 的加载数据！
  → 带宽浪费 67%

SoA（Structure of Arrays）：
  内存: [x0 x1 x2 x3 ... xN] [y0 y1 y2 y3 ... yN] [z0 z1 z2 z3 ... zN]
        ├──────────────────────┤
         所有粒子的x坐标在一起

  Thread 0 读 x0: 加载 [x0 x1 x2 x3] 的128B事务
  Thread 1 读 x1:   ↑ 同一事务，已经加载了！
  Thread 2 读 x2:   ↑ 同上
  → 100% 的加载数据都被使用
  → 完美合并访问
```

```cpp
// ═══════════════════════════════════════════
// AoS vs SoA 性能对比
// ═══════════════════════════════════════════

// AoS版本
struct ParticleAoS {
    float x, y, z;
    float vx, vy, vz;
    float mass;
    float padding;  // 对齐到32字节
};

__global__ void updateAoS(ParticleAoS* particles, float dt, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < n) {
        // 每个线程加载整个结构体
        // 访问x: stride = sizeof(ParticleAoS)/sizeof(float) = 8
        // → 严重的跨步访问
        particles[idx].x += particles[idx].vx * dt;
        particles[idx].y += particles[idx].vy * dt;
        particles[idx].z += particles[idx].vz * dt;
    }
}

// SoA版本
struct ParticlesSoA {
    float* x;   float* y;   float* z;
    float* vx;  float* vy;  float* vz;
    float* mass;
    int count;
};

__global__ void updateSoA(ParticlesSoA p, float dt) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < p.count) {
        // 每个数组的访问都是连续的 → 完美合并
        p.x[idx] += p.vx[idx] * dt;
        p.y[idx] += p.vy[idx] * dt;
        p.z[idx] += p.vz[idx] * dt;
    }
}

// AoSoA (Array of Structure of Arrays) —— 折中方案
// 适合需要同时访问多个属性且需要一定局部性的场景
struct ParticlesAoSoA {
    // 每组32个粒子（一个Warp处理一组）
    static constexpr int TILE = 32;

    float x[TILE];
    float y[TILE];
    float z[TILE];
    float vx[TILE];
    float vy[TILE];
    float vz[TILE];
};

__global__ void updateAoSoA(ParticlesAoSoA* tiles, float dt, int numTiles) {
    int tileIdx = blockIdx.x;
    int laneIdx = threadIdx.x;  // 0-31

    if (tileIdx < numTiles && laneIdx < ParticlesAoSoA::TILE) {
        // 一个Warp处理一个tile → 完美合并
        tiles[tileIdx].x[laneIdx] += tiles[tileIdx].vx[laneIdx] * dt;
        tiles[tileIdx].y[laneIdx] += tiles[tileIdx].vy[laneIdx] * dt;
        tiles[tileIdx].z[laneIdx] += tiles[tileIdx].vz[laneIdx] * dt;
    }
}
```

#### 3.6 内存对齐与填充策略

GPU对齐要求影响全局内存访问效率。正确的对齐和使用向量类型可以显著提升带宽利用率。

```cpp
// ═══════════════════════════════════════════
// 内存对齐技术
// ═══════════════════════════════════════════

// 1. 自然对齐 —— 数据类型对齐到自身大小
// float  → 4字节对齐
// float2 → 8字节对齐
// float4 → 16字节对齐

// 2. __align__ 属性强制对齐
struct __align__(16) AlignedStruct {  // 16字节对齐
    float x, y, z, w;
};

// 3. 向量类型加载 —— 提升内存事务效率
__global__ void vectorizedLoad(float* dst, const float* src, int n) {
    int idx = (blockIdx.x * blockDim.x + threadIdx.x) * 4;
    if (idx + 3 < n) {
        // 128位加载：一条指令加载4个float
        float4 val = *reinterpret_cast<const float4*>(&src[idx]);

        // 处理
        val.x *= 2.0f;
        val.y *= 2.0f;
        val.z *= 2.0f;
        val.w *= 2.0f;

        // 128位存储
        *reinterpret_cast<float4*>(&dst[idx]) = val;
    }
}

// 4. cudaMalloc 保证至少256字节对齐
// 这足以满足所有GPU内存访问的对齐要求

// 5. 对齐内存拷贝函数
// cudaMemcpy2D —— 支持pitch对齐
void alignedCopy2D() {
    size_t srcPitch, dstPitch;
    float *d_src, *d_dst;
    int width = 100;   // 实际数据宽度
    int height = 100;

    cudaMallocPitch(&d_src, &srcPitch, width * sizeof(float), height);
    cudaMallocPitch(&d_dst, &dstPitch, width * sizeof(float), height);

    // pitch可能大于 width*sizeof(float)
    // 例如 width=100 → 400B，但pitch可能是512B（对齐到2的幂次）
    printf("Width: %d bytes, Pitch: %zu bytes\n",
           width * 4, srcPitch);

    cudaMemcpy2D(
        d_dst, dstPitch,        // dst + pitch
        d_src, srcPitch,        // src + pitch
        width * sizeof(float),  // 每行实际数据宽度
        height,                 // 行数
        cudaMemcpyDeviceToDevice
    );

    cudaFree(d_src);
    cudaFree(d_dst);
}
```

#### 3.7 内存访问模式分析工具

使用profiling工具分析和优化内存访问模式是GPU性能调优的关键技能。

```
Nsight Compute 内存指标详解：

┌──────────────────────────────────────────────────────────────┐
│  Memory Workload Analysis（内存工作负载分析）                  │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  全局内存指标：                                               │
│  ┌──────────────────────────────┬──────────────────────────┐ │
│  │ Metric                       │ 含义                      │ │
│  ├──────────────────────────────┼──────────────────────────┤ │
│  │ gld_throughput               │ 全局加载吞吐量(GB/s)     │ │
│  │ gst_throughput               │ 全局存储吞吐量(GB/s)     │ │
│  │ gld_efficiency               │ 全局加载效率(%)          │ │
│  │ gst_efficiency               │ 全局存储效率(%)          │ │
│  │ dram_read_throughput         │ DRAM读取吞吐量           │ │
│  │ dram_write_throughput        │ DRAM写入吞吐量           │ │
│  │ l1_cache_global_hit_rate     │ L1缓存命中率             │ │
│  │ l2_cache_hit_rate            │ L2缓存命中率             │ │
│  └──────────────────────────────┴──────────────────────────┘ │
│                                                               │
│  共享内存指标：                                               │
│  ┌──────────────────────────────┬──────────────────────────┐ │
│  │ shared_load_throughput       │ 共享内存加载吞吐量       │ │
│  │ shared_store_throughput      │ 共享内存存储吞吐量       │ │
│  │ shared_efficiency            │ 共享内存效率(%)          │ │
│  │ shared_load_transactions     │ 共享内存加载事务数       │ │
│  │ shared_bank_conflict         │ Bank冲突次数             │ │
│  └──────────────────────────────┴──────────────────────────┘ │
│                                                               │
│  关键比率分析：                                               │
│  • gld_efficiency < 100%                                     │
│    → 存在非合并的全局内存加载，检查访问模式                  │
│  • gst_efficiency < 100%                                     │
│    → 存在非合并的全局内存存储，检查输出模式                  │
│  • shared_bank_conflict > 0                                  │
│    → 共享内存有bank冲突，考虑padding                        │
│  • l2_cache_hit_rate低但gld_throughput高                     │
│    → 数据工作集大于L2，考虑tiling或改变访问顺序             │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

```bash
# ═══════════════════════════════════════════
# Nsight Compute 使用示例
# ═══════════════════════════════════════════

# 基本profiling
ncu ./my_cuda_app

# 收集完整的内存指标
ncu --set full --target-processes all ./my_cuda_app

# 只收集内存相关指标
ncu --metrics \
    l1tex__t_sectors_pipe_lsu_mem_global_op_ld.sum,\
    l1tex__t_sectors_pipe_lsu_mem_global_op_st.sum,\
    smsp__sass_average_data_bytes_per_sector_mem_global_op_ld.pct,\
    smsp__sass_average_data_bytes_per_sector_mem_global_op_st.pct,\
    l1tex__data_pipe_lsu_wavefronts_mem_shared_op_ld.sum,\
    l1tex__data_pipe_lsu_wavefronts_mem_shared_op_st.sum \
    ./my_cuda_app

# 指定内核分析
ncu --kernel-name "myKernel" --launch-count 1 ./my_cuda_app

# 生成报告文件
ncu -o profile_report ./my_cuda_app
# 然后用 Nsight Compute GUI 打开 profile_report.ncu-rep

# 旧版工具（已弃用但仍有用）
# nvprof --print-gpu-trace ./my_cuda_app
# nvprof --metrics gld_efficiency,gst_efficiency ./my_cuda_app
```

```cpp
// 在代码中使用NVIDIA Tools Extension (NVTX) 标记
#include <nvtx3/nvToolsExt.h>

void myFunction() {
    nvtxRangePush("Data Transfer H2D");
    cudaMemcpy(d_data, h_data, bytes, cudaMemcpyHostToDevice);
    nvtxRangePop();

    nvtxRangePush("Kernel Execution");
    myKernel<<<grid, block>>>(d_data, n);
    cudaDeviceSynchronize();
    nvtxRangePop();

    nvtxRangePush("Data Transfer D2H");
    cudaMemcpy(h_data, d_data, bytes, cudaMemcpyDeviceToHost);
    nvtxRangePop();
}
// 在Nsight Systems中可以看到带颜色标注的时间线
```

#### 3.8 本周练习任务

1. **合并访问基准测试** —— 实现跨步拷贝内核（stride=1,2,4,8,16,32），测量每种stride的实际带宽。画出stride vs bandwidth曲线。使用Nsight Compute的`gld_efficiency`指标验证你的分析。

2. **矩阵转置优化** —— 实现四个版本的矩阵转置：(a) 朴素版本（直接全局内存）；(b) 共享内存版本（有Bank冲突）；(c) 共享内存+padding版本（无Bank冲突）；(d) float4向量化版本。对比四个版本的性能，验证每一步优化的加速比。

3. **归约优化系列** —— 实现一个完整的并行归约（求和），包括：(a) 交错归约（有分歧）；(b) 顺序归约（无分歧）；(c) 首次加载时归约（减半Block数）；(d) Warp级归约（使用`__shfl_down_sync`）。逐步优化并测量性能。

4. **AoS→SoA数据布局变换** —— 给定一个粒子系统（100万粒子，每粒子有position、velocity、color属性），分别用AoS和SoA布局实现粒子更新。测量两种布局的性能差异，用Nsight分析全局内存效率。

5. **内存带宽微基准测试** —— 实现GPU内存带宽测试工具：(a) 测量全局内存读/写/拷贝带宽；(b) 测量共享内存带宽（有/无Bank冲突）；(c) 测量L1/L2缓存带宽。生成类似CUDA Bandwidth Test的完整报告。

#### 3.9 本周知识检验

- [ ] 能画出32个线程合并访问与跨步访问的内存事务对比图
- [ ] 能解释为什么`__shared__ float tile[32][33]`比`tile[32][32]`更好
- [ ] 能根据stride计算全局内存加载效率（percentage）
- [ ] 能解释常量内存广播机制和适用场景
- [ ] 能分析给定代码的寄存器使用量对Occupancy的影响
- [ ] 能将AoS数据结构改写为SoA布局并解释性能差异
- [ ] 理解float4向量化加载如何提升带宽利用率
- [ ] 能使用Nsight Compute分析内存瓶颈并读懂关键指标
- [ ] 理解寄存器溢出到本地内存的性能代价
- [ ] 能解释cudaMallocPitch的pitch对齐目的

---

### 第四周：高级优化技术（35小时）

**学习目标**：
- [ ] 精通Occupancy分析：理解寄存器、共享内存和块大小三者如何共同决定SM上的活跃Warp数，能使用CUDA Occupancy Calculator进行量化分析
- [ ] 掌握CUDA Streams的并发执行模型：多流调度、默认流的阻塞语义、流优先级，能设计高效的流水线执行方案
- [ ] 深入理解异步内存传输与计算重叠：双缓冲（double buffering）技术、pinned memory的DMA传输，量化计算与传输重叠的收益
- [ ] 精通Warp级原语：`__shfl_sync`（shuffle）、`__ballot_sync`（vote）、`__match_any_sync`（match），理解它们如何避免共享内存往返
- [ ] 掌握原子操作的性能特征和优化策略：全局原子 vs 共享内存原子 vs Warp聚合原子，理解原子操作的硬件实现
- [ ] 能使用Nsight Systems和Nsight Compute进行端到端性能分析：识别CPU/GPU交互瓶颈、内核级优化、内存带宽利用率分析
- [ ] 了解多GPU编程基础：设备选择、P2P内存访问、NCCL集合通信、多GPU流水线设计
- [ ] 理解CUDA Graph的执行优化：减少CPU启动开销、图实例化与执行、与Streams的对比

**阅读材料**：
- [ ] CUDA C++ Programming Guide, Chapters 3.2.8（Streams）、7（Occupancy）
- [ ] CUDA C++ Best Practices Guide, Chapters 6-8（Execution Configuration, Streams, Concurrent Execution）
- [ ] 《Professional CUDA C Programming》- Cheng et al., Chapters 7-9（Streams, Atomic, Multi-GPU）
- [ ] 《Programming Massively Parallel Processors》- Kirk & Hwu, Chapters 11-13（Advanced Optimization）
- [ ] NVIDIA Developer Blog: "GPU Pro Tip: CUDA 7 Streams Simplified" - Mark Harris
- [ ] NVIDIA Developer Blog: "Using CUDA Warp-Level Primitives" - Yuan Lin
- [ ] "Optimizing Parallel Reduction in CUDA" - Mark Harris (NVIDIA SDK白皮书，经典必读)
- [ ] GTC 2021: "CUDA: New Features and Beyond" - Stephen Jones (NVIDIA)
- [ ] NVIDIA Developer Blog: "Getting Started with CUDA Graphs" - Robert Crovella
- [ ] NCCL Documentation: Multi-GPU and Multi-Node Communication

---

#### 核心概念

**GPU性能优化方法论全景**

```
GPU性能优化的系统方法：

Step 1: Profile First（先测量）
  ┌────────────────────────────────────────────┐
  │  不要猜测瓶颈！先用工具测量                  │
  │  Nsight Systems → 系统级时间线              │
  │  Nsight Compute → 内核级详细分析             │
  └────────────────────────────────────────────┘
          │
          ▼
Step 2: 识别瓶颈类型
  ┌────────────────────────────────────────────┐
  │  Compute-Bound    Memory-Bound   Latency   │
  │  (计算密集)       (内存密集)     (延迟敏感) │
  │  SM利用率高       带宽利用率高   Occupancy低 │
  │  优化：减少指令   优化：合并访问  优化：增加  │
  │  使用Tensor Core  减少事务数     并行度     │
  └────────────────────────────────────────────┘
          │
          ▼
Step 3: 应用优化（本周内容）
  ┌────────────────────────────────────────────┐
  │  • Occupancy调优（寄存器/共享内存平衡）      │
  │  • Streams并发（计算/传输重叠）              │
  │  • Warp原语（减少同步开销）                  │
  │  • 原子操作优化（聚合/分层）                 │
  │  • Multi-GPU扩展                            │
  └────────────────────────────────────────────┘
          │
          ▼
Step 4: 再次Profile，验证优化效果
```

#### 4.1 占用率分析与优化

Occupancy（占用率）是衡量GPU硬件利用率的关键指标。但高占用率不总是等于高性能——理解这一点至关重要。

```
Occupancy计算的三个约束：

约束1: 寄存器限制
  Occupancy_reg = floor(MaxRegs / (RegsPerThread × WarpSize)) / MaxWarps
  例：MaxRegs=65536, RegsPerThread=64, WarpSize=32, MaxWarps=64
  → floor(65536 / (64×32)) / 64 = 32/64 = 50%

约束2: 共享内存限制
  Occupancy_smem = floor(MaxSmem / SmemPerBlock) × (BlockSize/WarpSize) / MaxWarps
  例：MaxSmem=164KB, SmemPerBlock=48KB, BlockSize=256, MaxWarps=64
  → floor(164/48) × (256/32) / 64 = 3×8/64 = 37.5%

约束3: 块大小限制
  Occupancy_block = MaxBlocks × (BlockSize/WarpSize) / MaxWarps
  例：MaxBlocks=32, BlockSize=128, MaxWarps=64
  → 32 × 4 / 64 = 200% → cap at 100%

最终 Occupancy = min(约束1, 约束2, 约束3)

重要洞察：
┌──────────────────────────────────────────────────────────┐
│  高Occupancy ≠ 高性能                                    │
│                                                           │
│  • Occupancy足够高即可（通常>50%就不是瓶颈）              │
│  • 过度追求Occupancy可能牺牲每线程可用的寄存器/共享内存   │
│  • 有时减少Occupancy换取更多寄存器（减少溢出）反而更快    │
│  • Instruction-Level Parallelism (ILP) 可以弥补低Occupancy│
│                                                           │
│  经验法则：                                               │
│  • Memory-bound内核：Occupancy越高越好（更多延迟隐藏）   │
│  • Compute-bound内核：中等Occupancy即可（ILP更重要）     │
│  • 有大量共享内存的内核：Occupancy可能受限但性能很好      │
└──────────────────────────────────────────────────────────┘
```

```cpp
// ═══════════════════════════════════════════
// Occupancy API使用
// ═══════════════════════════════════════════

#include <cuda_runtime.h>
#include <stdio.h>

__global__ void myKernel(float* data, int n) {
    __shared__ float smem[256];
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int tid = threadIdx.x;

    if (idx < n) {
        smem[tid] = data[idx];
        __syncthreads();
        data[idx] = smem[tid] * 2.0f;
    }
}

void occupancyAnalysis() {
    int device = 0;
    cudaDeviceProp prop;
    cudaGetDeviceProperties(&prop, device);

    int blockSize = 256;
    size_t sharedMemBytes = 256 * sizeof(float);

    // 方法1：查询给定配置的Occupancy
    int numBlocks;
    cudaOccupancyMaxActiveBlocksPerMultiprocessor(
        &numBlocks, myKernel, blockSize, sharedMemBytes
    );
    int maxWarps = prop.maxThreadsPerMultiProcessor / prop.warpSize;
    int activeWarps = numBlocks * (blockSize / prop.warpSize);
    float occupancy = (float)activeWarps / maxWarps;

    printf("Block size: %d\n", blockSize);
    printf("Blocks per SM: %d\n", numBlocks);
    printf("Active Warps: %d / %d\n", activeWarps, maxWarps);
    printf("Occupancy: %.1f%%\n", occupancy * 100);

    // 方法2：自动建议最优块大小
    int minGridSize, suggestedBlockSize;
    cudaOccupancyMaxPotentialBlockSize(
        &minGridSize,
        &suggestedBlockSize,
        myKernel,
        sharedMemBytes,  // 动态共享内存
        0                // 最大块大小限制（0=无限制）
    );

    printf("Suggested block size: %d\n", suggestedBlockSize);
    printf("Min grid size for full occupancy: %d\n", minGridSize);

    // 方法3：使用动态共享内存时的Occupancy计算
    // 某些内核的共享内存大小取决于块大小
    auto sharedMemCalc = [](int blockSize) -> size_t {
        return blockSize * sizeof(float);
    };

    cudaOccupancyMaxPotentialBlockSizeVariableSMem(
        &minGridSize,
        &suggestedBlockSize,
        myKernel,
        sharedMemCalc,
        0
    );
    printf("With variable smem - suggested: %d\n", suggestedBlockSize);
}
```

#### 4.2 CUDA Streams与并发执行

CUDA Streams是实现CPU-GPU并发和GPU内多任务并发的核心机制。正确使用Streams可以实现计算与数据传输的完美重叠。

```
CUDA Stream执行模型：

默认流（Stream 0 / Legacy Default）：
  ┌──────────────────────────────────────────────────┐
  │  默认流是同步的——它等待所有其他流完成              │
  │  反之，其他流也等待默认流完成                      │
  │  → 默认流是"全局栅栏"                             │
  │                                                    │
  │  Per-Thread Default Stream（CUDA 7+）：            │
  │  编译时加 --default-stream per-thread              │
  │  每个CPU线程有自己的默认流，互不干扰               │
  └──────────────────────────────────────────────────┘

多流并发执行时间线：

单流（串行化）：
  H2D ████████
  K1          ████████
  D2H                  ████████
  总时间 ─────────────────────────→ 3T

双流流水线（理想情况）：
  Stream 1: H2D ████ K1 ████ D2H ████
  Stream 2:      H2D ████ K1 ████ D2H ████
  总时间 ──────────────────────→ ~2T （节省~33%）

三流流水线：
  Stream 1: H2D ██ K1 ██ D2H ██
  Stream 2:    H2D ██ K1 ██ D2H ██
  Stream 3:       H2D ██ K1 ██ D2H ██
  总时间 ────────────────────→ ~T+2ε

硬件支持：
  • 1个计算引擎（可以运行多个内核）
  • 2个DMA引擎（1个H2D + 1个D2H，可同时工作）
  • 计算和DMA可以完全重叠
```

```cpp
// ═══════════════════════════════════════════
// Streams实战：计算与传输重叠
// ═══════════════════════════════════════════

#include <cuda_runtime.h>
#include <stdio.h>

__global__ void processKernel(float* data, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < n) {
        // 模拟一些计算
        float val = data[idx];
        for (int i = 0; i < 100; i++) {
            val = sinf(val) + cosf(val);
        }
        data[idx] = val;
    }
}

void streamPipeline() {
    const int N = 4 * 1024 * 1024;  // 4M elements total
    const int NUM_STREAMS = 4;
    const int CHUNK = N / NUM_STREAMS;
    const size_t chunkBytes = CHUNK * sizeof(float);

    // 必须使用pinned memory才能异步传输！
    float* h_data;
    cudaMallocHost(&h_data, N * sizeof(float));
    for (int i = 0; i < N; i++) h_data[i] = (float)i;

    float* d_data;
    cudaMalloc(&d_data, N * sizeof(float));

    // 创建多个流
    cudaStream_t streams[NUM_STREAMS];
    for (int i = 0; i < NUM_STREAMS; i++) {
        cudaStreamCreate(&streams[i]);
    }

    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    // ═══ 方式1：串行执行 ═══
    cudaEventRecord(start);

    cudaMemcpy(d_data, h_data, N * sizeof(float), cudaMemcpyHostToDevice);
    processKernel<<<(N+255)/256, 256>>>(d_data, N);
    cudaMemcpy(h_data, d_data, N * sizeof(float), cudaMemcpyDeviceToHost);

    cudaEventRecord(stop);
    cudaEventSynchronize(stop);
    float serialTime;
    cudaEventElapsedTime(&serialTime, start, stop);

    // ═══ 方式2：多流流水线 ═══
    cudaEventRecord(start);

    for (int i = 0; i < NUM_STREAMS; i++) {
        int offset = i * CHUNK;

        // 每个流处理一个chunk
        cudaMemcpyAsync(d_data + offset, h_data + offset,
                        chunkBytes, cudaMemcpyHostToDevice, streams[i]);

        processKernel<<<(CHUNK+255)/256, 256, 0, streams[i]>>>(
            d_data + offset, CHUNK);

        cudaMemcpyAsync(h_data + offset, d_data + offset,
                        chunkBytes, cudaMemcpyDeviceToHost, streams[i]);
    }

    cudaEventRecord(stop);
    cudaEventSynchronize(stop);
    float pipelineTime;
    cudaEventElapsedTime(&pipelineTime, start, stop);

    printf("Serial:   %.2f ms\n", serialTime);
    printf("Pipeline: %.2f ms\n", pipelineTime);
    printf("Speedup:  %.2fx\n", serialTime / pipelineTime);

    // 清理
    for (int i = 0; i < NUM_STREAMS; i++) {
        cudaStreamDestroy(streams[i]);
    }
    cudaEventDestroy(start);
    cudaEventDestroy(stop);
    cudaFreeHost(h_data);
    cudaFree(d_data);
}

// ═══════════════════════════════════════════
// CUDA Events进行流间同步
// ═══════════════════════════════════════════

void streamSynchronization() {
    cudaStream_t stream1, stream2;
    cudaStreamCreate(&stream1);
    cudaStreamCreate(&stream2);

    cudaEvent_t event;
    cudaEventCreate(&event);

    // Stream 1: 计算数据
    kernelA<<<grid, block, 0, stream1>>>(d_data);
    // 记录事件
    cudaEventRecord(event, stream1);

    // Stream 2: 等待Stream 1完成后使用其结果
    cudaStreamWaitEvent(stream2, event);  // stream2等待event
    kernelB<<<grid, block, 0, stream2>>>(d_data);

    // 不需要cudaDeviceSynchronize
    // stream2在event触发后自动开始

    cudaEventDestroy(event);
    cudaStreamDestroy(stream1);
    cudaStreamDestroy(stream2);
}

// ═══════════════════════════════════════════
// CUDA Graphs —— 减少启动开销
// ═══════════════════════════════════════════

void cudaGraphExample() {
    // 方法1：通过Stream Capture创建Graph
    cudaStream_t stream;
    cudaStreamCreate(&stream);

    cudaGraph_t graph;
    cudaGraphExec_t graphExec;

    // 开始捕获
    cudaStreamBeginCapture(stream, cudaStreamCaptureModeGlobal);

    // 在流中放入操作（不会立即执行）
    cudaMemcpyAsync(d_data, h_data, bytes, cudaMemcpyHostToDevice, stream);
    kernel<<<grid, block, 0, stream>>>(d_data, n);
    cudaMemcpyAsync(h_data, d_data, bytes, cudaMemcpyDeviceToHost, stream);

    // 结束捕获
    cudaStreamEndCapture(stream, &graph);

    // 实例化图
    cudaGraphInstantiate(&graphExec, graph, nullptr, nullptr, 0);

    // 多次执行图（启动开销远小于多次API调用）
    for (int iter = 0; iter < 1000; iter++) {
        cudaGraphLaunch(graphExec, stream);
    }
    cudaStreamSynchronize(stream);

    // 清理
    cudaGraphExecDestroy(graphExec);
    cudaGraphDestroy(graph);
    cudaStreamDestroy(stream);
}
```

#### 4.3 异步内存传输与计算重叠

理解GPU的DMA引擎和计算引擎如何并行工作，是实现最优流水线的关键。

```
GPU内部引擎并发能力：

┌──────────────────────────────────────────────────┐
│  GPU芯片内部引擎                                  │
│                                                    │
│  ┌──────────────────┐  Host → Device               │
│  │  Copy Engine 0   │  (H2D DMA)                   │
│  └──────────────────┘                               │
│                                                    │
│  ┌──────────────────┐  Device → Host               │
│  │  Copy Engine 1   │  (D2H DMA)                   │
│  └──────────────────┘                               │
│                                                    │
│  ┌──────────────────┐  CUDA内核执行                │
│  │  Compute Engine  │  (所有SM)                     │
│  └──────────────────┘                               │
│                                                    │
│  三个引擎可以完全并行！                             │
│  最佳情况：H2D + Compute + D2H 同时进行            │
└──────────────────────────────────────────────────┘

双缓冲 (Double Buffering) 技术：
┌──────────────────────────────────────────────────┐
│                                                    │
│  Buffer A  Buffer B                               │
│  ┌─────┐  ┌─────┐                                │
│  │  A  │  │  B  │                                │
│  └─────┘  └─────┘                                │
│                                                    │
│  Step 1: 加载A到GPU     │ GPU空闲                  │
│  Step 2: 计算A          │ 加载B到GPU               │
│  Step 3: 回传A + 计算B  │ 加载下一批到A             │
│  Step 4: 回传B          │ 计算A（新数据）           │
│  ...                                               │
│                                                    │
│  稳态：每一步都有计算+传输同时进行                  │
└──────────────────────────────────────────────────┘
```

```cpp
// 双缓冲流水线实现
void doubleBufferPipeline(float* h_input, float* h_output, int totalN) {
    const int CHUNK = totalN / 2;
    const size_t chunkBytes = CHUNK * sizeof(float);

    // 两个设备缓冲区
    float *d_buf[2], *d_out[2];
    for (int i = 0; i < 2; i++) {
        cudaMalloc(&d_buf[i], chunkBytes);
        cudaMalloc(&d_out[i], chunkBytes);
    }

    // pinned内存
    float *h_pin_in, *h_pin_out;
    cudaMallocHost(&h_pin_in, totalN * sizeof(float));
    cudaMallocHost(&h_pin_out, totalN * sizeof(float));
    memcpy(h_pin_in, h_input, totalN * sizeof(float));

    // 两个流
    cudaStream_t stream[2];
    cudaStreamCreate(&stream[0]);
    cudaStreamCreate(&stream[1]);

    int numChunks = totalN / CHUNK;

    // 初始加载第一个chunk
    cudaMemcpyAsync(d_buf[0], h_pin_in, chunkBytes,
                    cudaMemcpyHostToDevice, stream[0]);

    for (int i = 0; i < numChunks; i++) {
        int curr = i % 2;
        int next = (i + 1) % 2;

        // 异步加载下一个chunk（如果存在）
        if (i + 1 < numChunks) {
            cudaMemcpyAsync(d_buf[next],
                           h_pin_in + (i + 1) * CHUNK,
                           chunkBytes,
                           cudaMemcpyHostToDevice,
                           stream[next]);
        }

        // 计算当前chunk
        processKernel<<<(CHUNK+255)/256, 256, 0, stream[curr]>>>(
            d_buf[curr], d_out[curr], CHUNK);

        // 回传前一个chunk的结果（如果存在）
        if (i > 0) {
            int prev = (i - 1) % 2;
            cudaMemcpyAsync(h_pin_out + (i - 1) * CHUNK,
                           d_out[prev],
                           chunkBytes,
                           cudaMemcpyDeviceToHost,
                           stream[prev]);
        }
    }

    // 回传最后一个chunk
    int last = (numChunks - 1) % 2;
    cudaMemcpyAsync(h_pin_out + (numChunks - 1) * CHUNK,
                   d_out[last], chunkBytes,
                   cudaMemcpyDeviceToHost, stream[last]);

    cudaDeviceSynchronize();
    memcpy(h_output, h_pin_out, totalN * sizeof(float));

    // 清理
    for (int i = 0; i < 2; i++) {
        cudaFree(d_buf[i]);
        cudaFree(d_out[i]);
        cudaStreamDestroy(stream[i]);
    }
    cudaFreeHost(h_pin_in);
    cudaFreeHost(h_pin_out);
}
```

#### 4.4 Warp级原语（Shuffle、Vote、Match）

Warp级原语允许同一Warp内的线程直接交换数据，无需经过共享内存。这些原语映射到专用硬件指令，延迟极低。

```
Warp Shuffle操作族：

__shfl_sync(mask, val, srcLane):
  从指定lane获取值
  ┌──────────────────────────────────────┐
  │ Lane:  0  1  2  3  4  5  ... 31     │
  │ Val:   A  B  C  D  E  F  ... Z      │
  │                                      │
  │ __shfl_sync(0xFFFF, val, 3):        │
  │ 所有lane都得到lane 3的值 D           │
  └──────────────────────────────────────┘

__shfl_up_sync(mask, val, delta):
  从 (laneId - delta) 获取值
  ┌──────────────────────────────────────┐
  │ 原始:  A  B  C  D  E  F  G  H       │
  │ delta=1: A  A  B  C  D  E  F  G     │
  │ delta=2: A  B  A  B  C  D  E  F     │
  │ 用途：前缀和（prefix sum）           │
  └──────────────────────────────────────┘

__shfl_down_sync(mask, val, delta):
  从 (laneId + delta) 获取值
  ┌──────────────────────────────────────┐
  │ 原始:  A  B  C  D  E  F  G  H       │
  │ delta=1: B  C  D  E  F  G  H  H     │
  │ delta=2: C  D  E  F  G  H  G  H     │
  │ 用途：归约（reduction）               │
  └──────────────────────────────────────┘

__shfl_xor_sync(mask, val, laneMask):
  从 (laneId ^ laneMask) 获取值
  ┌──────────────────────────────────────┐
  │ 原始:       A  B  C  D  E  F  G  H  │
  │ mask=1:     B  A  D  C  F  E  H  G  │
  │ mask=2:     C  D  A  B  G  H  E  F  │
  │ 用途：蝶形归约（butterfly reduction）│
  └──────────────────────────────────────┘
```

```cpp
// ═══════════════════════════════════════════
// Warp归约 —— 比共享内存归约更快
// ═══════════════════════════════════════════

// Warp级归约（无需共享内存！）
__device__ float warpReduceSum(float val) {
    // 使用butterfly pattern归约
    for (int offset = 16; offset > 0; offset >>= 1) {
        val += __shfl_down_sync(0xFFFFFFFF, val, offset);
    }
    return val;  // 只有lane 0有正确结果
}

// 完整的Block级归约（使用Warp归约 + 少量共享内存）
__device__ float blockReduceSum(float val) {
    __shared__ float warpSums[32];  // 最多32个Warp

    int warpId = threadIdx.x / 32;
    int laneId = threadIdx.x % 32;
    int numWarps = blockDim.x / 32;

    // Step 1: Warp内归约
    val = warpReduceSum(val);

    // Step 2: 每个Warp的lane 0写入共享内存
    if (laneId == 0) {
        warpSums[warpId] = val;
    }
    __syncthreads();

    // Step 3: 第一个Warp归约所有Warp的结果
    val = (threadIdx.x < numWarps) ? warpSums[threadIdx.x] : 0.0f;
    if (warpId == 0) {
        val = warpReduceSum(val);
    }

    return val;  // 只有threadIdx.x == 0 有正确结果
}

// 使用归约的向量求和内核
__global__ void vectorSum(const float* data, float* result, int n) {
    float sum = 0.0f;

    // Grid-stride loop
    for (int i = blockIdx.x * blockDim.x + threadIdx.x;
         i < n;
         i += blockDim.x * gridDim.x) {
        sum += data[i];
    }

    // Block级归约
    sum = blockReduceSum(sum);

    // 每个Block的结果用原子加到全局
    if (threadIdx.x == 0) {
        atomicAdd(result, sum);
    }
}

// ═══════════════════════════════════════════
// Warp Vote操作
// ═══════════════════════════════════════════

__global__ void warpVoteDemo(int* data, int* result, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= n) return;

    int val = data[idx];

    // __ballot_sync: 返回满足条件的线程位掩码
    unsigned mask = __ballot_sync(0xFFFFFFFF, val > 0);
    // mask的第i位 = 1 表示lane i的val > 0

    // __popc: population count，计算1的个数
    int positiveCount = __popc(mask);

    // __all_sync: 所有线程都满足条件?
    bool allPositive = __all_sync(0xFFFFFFFF, val > 0);

    // __any_sync: 至少一个线程满足条件?
    bool anyNegative = __any_sync(0xFFFFFFFF, val < 0);

    // 用途：条件过滤、流压缩（stream compaction）
    if (threadIdx.x % 32 == 0) {
        printf("Warp %d: %d/%d positive, all=%d, anyNeg=%d\n",
               threadIdx.x / 32, positiveCount, 32,
               allPositive, anyNegative);
    }
}

// ═══════════════════════════════════════════
// Warp级前缀和（Scan）
// ═══════════════════════════════════════════

__device__ float warpPrefixSum(float val) {
    // Hillis-Steele并行前缀和
    for (int d = 1; d < 32; d <<= 1) {
        float neighbor = __shfl_up_sync(0xFFFFFFFF, val, d);
        if (threadIdx.x % 32 >= d) {
            val += neighbor;
        }
    }
    return val;  // 每个lane都有正确的前缀和结果
}
```

#### 4.5 原子操作与归约优化

原子操作保证多个线程同时修改同一地址时的正确性，但可能成为性能瓶颈。理解其硬件实现和优化策略至关重要。

```
原子操作的性能层次：

┌──────────────────────────────────────────────────────────┐
│  原子操作类型        │ 延迟    │ 吞吐量    │ 硬件位置    │
├──────────────────────────────────────────────────────────┤
│  全局内存原子        │ ~400cyc │ 低        │ L2 Cache    │
│  (atomicAdd on      │         │ 高竞争时   │ 或 HBM      │
│   global memory)    │         │ 极慢      │             │
├──────────────────────────────────────────────────────────┤
│  共享内存原子        │ ~5cyc   │ 中等      │ SM内部      │
│  (atomicAdd on      │         │ 每SM独立   │ Shared Mem  │
│   shared memory)    │         │ 无SM间竞争 │             │
├──────────────────────────────────────────────────────────┤
│  Warp聚合原子        │ ~1cyc   │ 高        │ Warp内部    │
│  (Warp-aggregated    │ (摊销)  │ 减少竞争   │ + L2       │
│   atomics)          │         │ 32倍      │             │
└──────────────────────────────────────────────────────────┘
```

```cpp
// ═══════════════════════════════════════════
// 直方图 —— 原子操作优化的经典案例
// ═══════════════════════════════════════════

// 版本1：全局原子（最慢，高竞争）
__global__ void histogramGlobalAtomic(
    const unsigned char* data, int* hist, int n
) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < n) {
        atomicAdd(&hist[data[idx]], 1);  // 256个bin的竞争
    }
}

// 版本2：共享内存原子 → 全局原子（推荐）
__global__ void histogramSharedAtomic(
    const unsigned char* data, int* hist, int n
) {
    __shared__ int localHist[256];

    // 初始化局部直方图
    int tid = threadIdx.x;
    if (tid < 256) localHist[tid] = 0;
    __syncthreads();

    // 每个线程累加到共享内存（低竞争）
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int stride = blockDim.x * gridDim.x;
    for (int i = idx; i < n; i += stride) {
        atomicAdd(&localHist[data[i]], 1);
        // 共享内存原子：只有同一Block的线程竞争
    }
    __syncthreads();

    // 合并到全局直方图
    if (tid < 256) {
        atomicAdd(&hist[tid], localHist[tid]);
        // 只有gridDim.x个Block竞争，而非n个线程
    }
}

// 版本3：Warp聚合原子（最优）
__global__ void histogramWarpAggregated(
    const unsigned char* data, int* hist, int n
) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= n) return;

    unsigned char val = data[idx];

    // 找出同一Warp中有多少线程要更新同一个bin
    unsigned mask = __match_any_sync(0xFFFFFFFF, (int)val);
    // mask: 与当前线程val相同的所有线程的位掩码

    // 只有每组中第一个线程执行原子操作
    int leader = __ffs(mask) - 1;  // 找到最低位的1
    int laneId = threadIdx.x % 32;
    if (laneId == leader) {
        // 一次原子操作代替 __popc(mask) 次
        atomicAdd(&hist[val], __popc(mask));
    }
}
```

#### 4.6 Nsight性能分析实战

系统性使用profiling工具是GPU优化的核心技能。Nsight Systems提供系统级视图，Nsight Compute提供内核级详细分析。

```
Nsight工具生态：

┌──────────────────────────────────────────────────────────────┐
│  Nsight Systems                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ 系统级时间线分析                                        │ │
│  │ • CPU/GPU活动时间线                                    │ │
│  │ • 内核执行时间                                         │ │
│  │ • 内存传输时间和方向                                    │ │
│  │ • Stream并发可视化                                     │ │
│  │ • API调用追踪                                          │ │
│  │ • CPU采样（识别CPU瓶颈）                               │ │
│  │ 用途：宏观性能分析，找出大的时间浪费                    │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                               │
│  Nsight Compute                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ 内核级详细分析                                         │ │
│  │ • 每个内核的SM利用率、Occupancy                        │ │
│  │ • 内存吞吐量（全局/共享/L1/L2）                       │ │
│  │ • 指令吞吐量和混合                                     │ │
│  │ • Warp执行效率                                        │ │
│  │ • Roofline分析                                        │ │
│  │ • Source-Level分析（每行代码的性能）                    │ │
│  │ 用途：内核级深度优化                                    │ │
│  └────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘

优化工作流：
  1. nsys profile → 系统级时间线，识别瓶颈区域
  2. ncu --set full → 对瓶颈内核做详细分析
  3. 查看Speed of Light (SOL) → 计算/内存利用率
  4. 查看Roofline → 确认瓶颈类型
  5. 查看具体指标 → 指导优化方向
  6. 修改代码 → 重新profile → 验证改进
```

```bash
# ═══════════════════════════════════════════
# Nsight Systems 命令行用法
# ═══════════════════════════════════════════

# 基本系统级分析
nsys profile --stats=true ./my_cuda_app

# 生成报告（在GUI中查看）
nsys profile -o my_profile ./my_cuda_app
# 然后用 nsys-ui 打开 my_profile.nsys-rep

# 限制追踪范围
nsys profile --trace=cuda,nvtx --duration=10 ./my_cuda_app

# ═══════════════════════════════════════════
# Nsight Compute 命令行用法
# ═══════════════════════════════════════════

# 分析所有内核
ncu ./my_cuda_app

# 完整指标集
ncu --set full ./my_cuda_app

# 指定内核和启动次数
ncu --kernel-name "matMul" --launch-skip 5 --launch-count 1 ./my_cuda_app

# 源代码级分析（需要 -lineinfo 编译）
ncu --set source ./my_cuda_app

# 导出报告
ncu -o my_kernel_report ./my_cuda_app
```

```cpp
// 在代码中集成Profiling标记
#include <nvtx3/nvToolsExt.h>

// 使用RAII风格的NVTX范围标记
class NvtxRange {
    public:
    explicit NvtxRange(const char* name) { nvtxRangePush(name); }
    ~NvtxRange() { nvtxRangePop(); }
};

#define NVTX_RANGE(name) NvtxRange _nvtx_range(name)

void optimizedPipeline() {
    {
        NVTX_RANGE("Initialization");
        // 初始化代码...
    }

    {
        NVTX_RANGE("Data Transfer H2D");
        cudaMemcpy(d_data, h_data, bytes, cudaMemcpyHostToDevice);
    }

    {
        NVTX_RANGE("Kernel Execution");
        myKernel<<<grid, block>>>(d_data, n);
        cudaDeviceSynchronize();
    }

    {
        NVTX_RANGE("Data Transfer D2H");
        cudaMemcpy(h_data, d_data, bytes, cudaMemcpyDeviceToHost);
    }
}
```

#### 4.7 多GPU编程基础

当单GPU性能不够时，多GPU编程是扩展计算能力的必然选择。CUDA提供了多种多GPU编程方式。

```
多GPU通信拓扑：

┌──────────┐         ┌──────────┐
│  GPU 0   │ NVLink  │  GPU 1   │
│  (SM×N)  │←──────→ │  (SM×N)  │
│  HBM 80G │  900GB/s│  HBM 80G │
└────┬─────┘         └────┬─────┘
     │ PCIe                │ PCIe
     │ 50GB/s              │ 50GB/s
     └──────────┬──────────┘
                │
          ┌─────▼─────┐
          │   CPU     │
          │   DRAM    │
          └───────────┘

通信方式对比：
┌──────────────────┬────────────┬─────────────────┐
│  方式             │ 带宽        │ 编程复杂度       │
├──────────────────┼────────────┼─────────────────┤
│  Host Staging    │ ~25 GB/s   │ 低（cudaMemcpy）│
│  (GPU→CPU→GPU)   │ (PCIe限制) │                 │
├──────────────────┼────────────┼─────────────────┤
│  P2P Direct      │ ~300 GB/s  │ 中              │
│  (GPU→GPU直接)   │ (NVLink)   │ cudaMemcpyPeer │
├──────────────────┼────────────┼─────────────────┤
│  NCCL            │ 接近线速   │ 中高            │
│  (集合通信库)     │ 自动选路   │ AllReduce等     │
├──────────────────┼────────────┼─────────────────┤
│  CUDA-Aware MPI  │ 接近线速   │ 高              │
│  (跨节点通信)     │ 自动RDMA   │ MPI接口         │
└──────────────────┴────────────┴─────────────────┘
```

```cpp
// ═══════════════════════════════════════════
// 多GPU编程基础
// ═══════════════════════════════════════════

#include <cuda_runtime.h>
#include <stdio.h>

void multiGPUBasics() {
    int deviceCount;
    cudaGetDeviceCount(&deviceCount);
    printf("Found %d GPUs\n", deviceCount);

    // 检查P2P支持
    for (int i = 0; i < deviceCount; i++) {
        for (int j = 0; j < deviceCount; j++) {
            if (i == j) continue;
            int canAccess;
            cudaDeviceCanAccessPeer(&canAccess, i, j);
            printf("GPU %d → GPU %d P2P: %s\n",
                   i, j, canAccess ? "Yes" : "No");
        }
    }

    // 启用P2P
    for (int i = 0; i < deviceCount; i++) {
        cudaSetDevice(i);
        for (int j = 0; j < deviceCount; j++) {
            if (i != j) {
                cudaDeviceEnablePeerAccess(j, 0);
            }
        }
    }

    // 在不同GPU上分配内存
    float* d_data[4];  // 最多4个GPU
    const size_t bytes = 1024 * 1024 * sizeof(float);

    for (int i = 0; i < deviceCount; i++) {
        cudaSetDevice(i);
        cudaMalloc(&d_data[i], bytes);
    }

    // GPU 0 → GPU 1 直接传输（P2P）
    cudaMemcpyPeer(d_data[1], 1, d_data[0], 0, bytes);

    // 在不同GPU上启动内核
    for (int i = 0; i < deviceCount; i++) {
        cudaSetDevice(i);
        myKernel<<<grid, block>>>(d_data[i], n);
    }

    // 同步所有GPU
    for (int i = 0; i < deviceCount; i++) {
        cudaSetDevice(i);
        cudaDeviceSynchronize();
    }

    // 清理
    for (int i = 0; i < deviceCount; i++) {
        cudaSetDevice(i);
        cudaFree(d_data[i]);
    }
}

// ═══════════════════════════════════════════
// 多GPU数据并行示例
// ═══════════════════════════════════════════

__global__ void processChunk(float* data, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < n) {
        data[idx] = sinf(data[idx]) * cosf(data[idx]);
    }
}

void multiGPUDataParallel(float* h_data, int totalN) {
    int deviceCount;
    cudaGetDeviceCount(&deviceCount);

    int chunkSize = totalN / deviceCount;
    float* d_data[8];
    cudaStream_t streams[8];

    // 分配并传输
    for (int i = 0; i < deviceCount; i++) {
        cudaSetDevice(i);
        cudaStreamCreate(&streams[i]);
        cudaMalloc(&d_data[i], chunkSize * sizeof(float));

        cudaMemcpyAsync(d_data[i],
                       h_data + i * chunkSize,
                       chunkSize * sizeof(float),
                       cudaMemcpyHostToDevice,
                       streams[i]);
    }

    // 并行计算
    for (int i = 0; i < deviceCount; i++) {
        cudaSetDevice(i);
        processChunk<<<(chunkSize+255)/256, 256, 0, streams[i]>>>(
            d_data[i], chunkSize);
    }

    // 回传结果
    for (int i = 0; i < deviceCount; i++) {
        cudaSetDevice(i);
        cudaMemcpyAsync(h_data + i * chunkSize,
                       d_data[i],
                       chunkSize * sizeof(float),
                       cudaMemcpyDeviceToHost,
                       streams[i]);
    }

    // 同步所有
    for (int i = 0; i < deviceCount; i++) {
        cudaSetDevice(i);
        cudaStreamSynchronize(streams[i]);
        cudaFree(d_data[i]);
        cudaStreamDestroy(streams[i]);
    }
}
```

#### 4.8 本周练习任务

1. **Occupancy调优实验** —— 编写一个可调节寄存器使用量的内核（通过改变局部变量数量）。使用`cudaOccupancyMaxActiveBlocksPerMultiprocessor` API测量不同寄存器数量下的Occupancy。找到性能最优的Occupancy点（不一定是最高的）。

2. **流水线优化** —— 实现一个大数组处理任务，对比三种执行方式：(a) 单流串行（H2D→Kernel→D2H）；(b) 4流流水线；(c) 8流流水线。使用Nsight Systems可视化时间线，分析计算与传输的重叠程度。

3. **Warp归约库** —— 实现一个完整的Warp级归约库，包含：(a) `warpReduceSum`（求和）；(b) `warpReduceMax`（最大值）；(c) `warpReduceMin`（最小值）；(d) `warpPrefixSum`（前缀和）；(e) `blockReduceSum`（Block级归约）。对比Warp归约与共享内存归约的性能。

4. **直方图优化** —— 实现直方图计算的三个版本：(a) 全局原子；(b) 共享内存分层原子；(c) Warp聚合原子。用1GB随机数据测试，对比三个版本的性能和正确性。使用Nsight Compute分析原子操作的竞争情况。

5. **CUDA Graph实验** —— 将一个迭代求解算法（如Jacobi迭代法求解线性方程组）分别用(a) 普通API调用循环和(b) CUDA Graph实现。对比1000次迭代的总时间，量化Graph减少启动开销的效果。

6. **多GPU基准测试** —— 如果有多块GPU，实现一个多GPU向量加法程序。测量P2P直接传输 vs 通过Host中转的带宽差异。分析数据分区策略对性能的影响。

#### 4.9 本周知识检验

- [ ] 能解释Occupancy的三个限制因素并手动计算给定配置的Occupancy
- [ ] 理解为什么100% Occupancy不总是最优，能举出反例
- [ ] 能画出4流流水线的时间线图，标注计算与传输的重叠区域
- [ ] 掌握CUDA Stream的默认流语义（legacy vs per-thread）
- [ ] 能实现基于`__shfl_down_sync`的Warp归约，并解释其比共享内存快的原因
- [ ] 能使用`__ballot_sync`实现流压缩（stream compaction）
- [ ] 能解释原子操作的三级优化策略（全局→共享→Warp聚合）
- [ ] 能使用Nsight Systems分析CPU/GPU交互时间线
- [ ] 能使用Nsight Compute读懂Speed of Light和Roofline报告
- [ ] 理解CUDA Graph如何减少CPU端启动开销
- [ ] 能解释P2P直接内存访问的硬件要求（NVLink/NVSwitch）

---

## 源码阅读任务

### 必读项目

1. **CUTLASS** (https://github.com/NVIDIA/cutlass)
   - 重点：GEMM实现
   - 学习目标：理解高性能矩阵运算
   - 阅读时间：12小时

2. **CUB** (https://github.com/NVIDIA/cub)
   - 重点：归约和排序算法
   - 学习目标：理解GPU并行原语
   - 阅读时间：8小时

3. **Thrust** (https://github.com/NVIDIA/thrust)
   - 重点：高级算法接口
   - 学习目标：理解GPU算法库设计
   - 阅读时间：6小时

---

## 实践项目：高性能卷积实现

### 项目概述
实现高性能的2D卷积操作，这是深度学习和图像处理的核心操作。

### 完整代码实现

#### 1. CUDA工具库 (cuda_utils.cuh)

```cuda
#pragma once

#include <cuda_runtime.h>
#include <iostream>
#include <chrono>

#define CUDA_CHECK(call) \
    do { \
        cudaError_t err = call; \
        if (err != cudaSuccess) { \
            std::cerr << "CUDA error at " << __FILE__ << ":" << __LINE__ \
                      << " - " << cudaGetErrorString(err) << std::endl; \
            exit(EXIT_FAILURE); \
        } \
    } while(0)

// 设备信息
inline void printDeviceInfo() {
    int deviceCount;
    CUDA_CHECK(cudaGetDeviceCount(&deviceCount));

    for (int i = 0; i < deviceCount; ++i) {
        cudaDeviceProp prop;
        CUDA_CHECK(cudaGetDeviceProperties(&prop, i));

        std::cout << "Device " << i << ": " << prop.name << "\n";
        std::cout << "  Compute capability: " << prop.major << "." << prop.minor << "\n";
        std::cout << "  SMs: " << prop.multiProcessorCount << "\n";
        std::cout << "  Global memory: " << prop.totalGlobalMem / (1024*1024) << " MB\n";
        std::cout << "  Shared memory per block: " << prop.sharedMemPerBlock / 1024 << " KB\n";
        std::cout << "  Max threads per block: " << prop.maxThreadsPerBlock << "\n";
        std::cout << "  Warp size: " << prop.warpSize << "\n";
    }
}

// GPU计时器
class GpuTimer {
    cudaEvent_t start_, stop_;

public:
    GpuTimer() {
        CUDA_CHECK(cudaEventCreate(&start_));
        CUDA_CHECK(cudaEventCreate(&stop_));
    }

    ~GpuTimer() {
        cudaEventDestroy(start_);
        cudaEventDestroy(stop_);
    }

    void start(cudaStream_t stream = 0) {
        CUDA_CHECK(cudaEventRecord(start_, stream));
    }

    void stop(cudaStream_t stream = 0) {
        CUDA_CHECK(cudaEventRecord(stop_, stream));
    }

    float elapsed() {
        CUDA_CHECK(cudaEventSynchronize(stop_));
        float ms;
        CUDA_CHECK(cudaEventElapsedTime(&ms, start_, stop_));
        return ms;
    }
};

// 简单内存管理
template<typename T>
class DeviceArray {
    T* data_;
    size_t size_;

public:
    explicit DeviceArray(size_t size) : size_(size) {
        CUDA_CHECK(cudaMalloc(&data_, size * sizeof(T)));
    }

    ~DeviceArray() {
        if (data_) cudaFree(data_);
    }

    DeviceArray(const DeviceArray&) = delete;
    DeviceArray& operator=(const DeviceArray&) = delete;

    DeviceArray(DeviceArray&& other) noexcept
        : data_(other.data_), size_(other.size_) {
        other.data_ = nullptr;
    }

    T* data() { return data_; }
    const T* data() const { return data_; }
    size_t size() const { return size_; }

    void copyFromHost(const T* host) {
        CUDA_CHECK(cudaMemcpy(data_, host, size_ * sizeof(T), cudaMemcpyHostToDevice));
    }

    void copyToHost(T* host) const {
        CUDA_CHECK(cudaMemcpy(host, data_, size_ * sizeof(T), cudaMemcpyDeviceToHost));
    }

    void zero() {
        CUDA_CHECK(cudaMemset(data_, 0, size_ * sizeof(T)));
    }
};
```

#### 2. 朴素卷积实现 (convolution_naive.cuh)

```cuda
#pragma once

#include "cuda_utils.cuh"

// 朴素卷积内核
__global__ void conv2dNaive(
    const float* input,   // [N, C_in, H, W]
    const float* kernel,  // [C_out, C_in, K, K]
    float* output,        // [N, C_out, H_out, W_out]
    int N, int C_in, int H, int W,
    int C_out, int K,
    int H_out, int W_out,
    int pad, int stride
) {
    // 每个线程计算一个输出元素
    int w_out = blockIdx.x * blockDim.x + threadIdx.x;
    int h_out = blockIdx.y * blockDim.y + threadIdx.y;
    int c_out = blockIdx.z % C_out;
    int n = blockIdx.z / C_out;

    if (w_out >= W_out || h_out >= H_out) return;

    float sum = 0.0f;

    // 卷积
    for (int c_in = 0; c_in < C_in; ++c_in) {
        for (int kh = 0; kh < K; ++kh) {
            for (int kw = 0; kw < K; ++kw) {
                int h_in = h_out * stride - pad + kh;
                int w_in = w_out * stride - pad + kw;

                if (h_in >= 0 && h_in < H && w_in >= 0 && w_in < W) {
                    int input_idx = n * (C_in * H * W) +
                                   c_in * (H * W) +
                                   h_in * W + w_in;

                    int kernel_idx = c_out * (C_in * K * K) +
                                    c_in * (K * K) +
                                    kh * K + kw;

                    sum += input[input_idx] * kernel[kernel_idx];
                }
            }
        }
    }

    int output_idx = n * (C_out * H_out * W_out) +
                    c_out * (H_out * W_out) +
                    h_out * W_out + w_out;

    output[output_idx] = sum;
}

void conv2dNaiveLaunch(
    const float* input,
    const float* kernel,
    float* output,
    int N, int C_in, int H, int W,
    int C_out, int K,
    int pad, int stride
) {
    int H_out = (H + 2 * pad - K) / stride + 1;
    int W_out = (W + 2 * pad - K) / stride + 1;

    dim3 blockDim(16, 16);
    dim3 gridDim(
        (W_out + blockDim.x - 1) / blockDim.x,
        (H_out + blockDim.y - 1) / blockDim.y,
        N * C_out
    );

    conv2dNaive<<<gridDim, blockDim>>>(
        input, kernel, output,
        N, C_in, H, W,
        C_out, K,
        H_out, W_out,
        pad, stride
    );

    CUDA_CHECK(cudaGetLastError());
}
```

#### 3. 共享内存优化卷积 (convolution_shared.cuh)

```cuda
#pragma once

#include "cuda_utils.cuh"

// 使用共享内存的卷积
template<int TILE_W, int TILE_H, int K>
__global__ void conv2dShared(
    const float* input,
    const float* kernel,
    float* output,
    int N, int C_in, int H, int W,
    int C_out,
    int H_out, int W_out,
    int pad, int stride
) {
    // 共享内存tile大小需要包含halo区域
    constexpr int SHARED_W = TILE_W + K - 1;
    constexpr int SHARED_H = TILE_H + K - 1;

    __shared__ float sharedInput[SHARED_H][SHARED_W];
    __shared__ float sharedKernel[K][K];

    int tx = threadIdx.x;
    int ty = threadIdx.y;
    int bx = blockIdx.x * TILE_W;
    int by = blockIdx.y * TILE_H;
    int c_out = blockIdx.z % C_out;
    int n = blockIdx.z / C_out;

    int w_out = bx + tx;
    int h_out = by + ty;

    float sum = 0.0f;

    // 遍历输入通道
    for (int c_in = 0; c_in < C_in; ++c_in) {
        // 协作加载卷积核到共享内存
        if (tx < K && ty < K) {
            int kernel_idx = c_out * (C_in * K * K) +
                            c_in * (K * K) +
                            ty * K + tx;
            sharedKernel[ty][tx] = kernel[kernel_idx];
        }

        // 协作加载输入tile（包含halo）
        for (int i = ty; i < SHARED_H; i += blockDim.y) {
            for (int j = tx; j < SHARED_W; j += blockDim.x) {
                int h_in = by * stride - pad + i;
                int w_in = bx * stride - pad + j;

                float val = 0.0f;
                if (h_in >= 0 && h_in < H && w_in >= 0 && w_in < W) {
                    int input_idx = n * (C_in * H * W) +
                                   c_in * (H * W) +
                                   h_in * W + w_in;
                    val = input[input_idx];
                }
                sharedInput[i][j] = val;
            }
        }

        __syncthreads();

        // 计算卷积
        if (w_out < W_out && h_out < H_out) {
            for (int kh = 0; kh < K; ++kh) {
                for (int kw = 0; kw < K; ++kw) {
                    int sh = ty * stride + kh;
                    int sw = tx * stride + kw;
                    sum += sharedInput[sh][sw] * sharedKernel[kh][kw];
                }
            }
        }

        __syncthreads();
    }

    // 写入输出
    if (w_out < W_out && h_out < H_out) {
        int output_idx = n * (C_out * H_out * W_out) +
                        c_out * (H_out * W_out) +
                        h_out * W_out + w_out;
        output[output_idx] = sum;
    }
}

void conv2dSharedLaunch(
    const float* input,
    const float* kernel,
    float* output,
    int N, int C_in, int H, int W,
    int C_out, int K,
    int pad, int stride
) {
    int H_out = (H + 2 * pad - K) / stride + 1;
    int W_out = (W + 2 * pad - K) / stride + 1;

    constexpr int TILE_W = 16;
    constexpr int TILE_H = 16;

    dim3 blockDim(TILE_W, TILE_H);
    dim3 gridDim(
        (W_out + TILE_W - 1) / TILE_W,
        (H_out + TILE_H - 1) / TILE_H,
        N * C_out
    );

    if (K == 3) {
        conv2dShared<TILE_W, TILE_H, 3><<<gridDim, blockDim>>>(
            input, kernel, output,
            N, C_in, H, W, C_out,
            H_out, W_out, pad, stride
        );
    } else if (K == 5) {
        conv2dShared<TILE_W, TILE_H, 5><<<gridDim, blockDim>>>(
            input, kernel, output,
            N, C_in, H, W, C_out,
            H_out, W_out, pad, stride
        );
    }

    CUDA_CHECK(cudaGetLastError());
}
```

#### 4. Im2Col卷积实现 (convolution_im2col.cuh)

```cuda
#pragma once

#include "cuda_utils.cuh"
#include <cublas_v2.h>

// Im2Col变换：将卷积转换为矩阵乘法
__global__ void im2col(
    const float* input,   // [N, C, H, W]
    float* col,           // [N, C*K*K, H_out*W_out]
    int N, int C, int H, int W,
    int K, int H_out, int W_out,
    int pad, int stride
) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int total = N * C * K * K * H_out * W_out;

    if (idx >= total) return;

    // 解析索引
    int w_out = idx % W_out;
    int h_out = (idx / W_out) % H_out;
    int kw = (idx / (W_out * H_out)) % K;
    int kh = (idx / (W_out * H_out * K)) % K;
    int c = (idx / (W_out * H_out * K * K)) % C;
    int n = idx / (W_out * H_out * K * K * C);

    int h_in = h_out * stride - pad + kh;
    int w_in = w_out * stride - pad + kw;

    float val = 0.0f;
    if (h_in >= 0 && h_in < H && w_in >= 0 && w_in < W) {
        val = input[n * (C * H * W) + c * (H * W) + h_in * W + w_in];
    }

    // col layout: [N, C*K*K, H_out*W_out]
    int col_c = c * K * K + kh * K + kw;
    int col_idx = n * (C * K * K * H_out * W_out) +
                  col_c * (H_out * W_out) +
                  h_out * W_out + w_out;

    col[col_idx] = val;
}

// Col2Im（用于反向传播）
__global__ void col2im(
    const float* col,
    float* input,
    int N, int C, int H, int W,
    int K, int H_out, int W_out,
    int pad, int stride
) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int total = N * C * H * W;

    if (idx >= total) return;

    int w = idx % W;
    int h = (idx / W) % H;
    int c = (idx / (W * H)) % C;
    int n = idx / (W * H * C);

    float sum = 0.0f;

    // 找到所有对该位置有贡献的输出
    for (int kh = 0; kh < K; ++kh) {
        for (int kw = 0; kw < K; ++kw) {
            int h_out = (h + pad - kh);
            int w_out = (w + pad - kw);

            if (h_out % stride == 0 && w_out % stride == 0) {
                h_out /= stride;
                w_out /= stride;

                if (h_out >= 0 && h_out < H_out && w_out >= 0 && w_out < W_out) {
                    int col_c = c * K * K + kh * K + kw;
                    int col_idx = n * (C * K * K * H_out * W_out) +
                                  col_c * (H_out * W_out) +
                                  h_out * W_out + w_out;
                    sum += col[col_idx];
                }
            }
        }
    }

    input[idx] = sum;
}

class Conv2dIm2Col {
    cublasHandle_t handle_;
    float* col_buffer_;
    size_t col_buffer_size_;

public:
    Conv2dIm2Col() : col_buffer_(nullptr), col_buffer_size_(0) {
        cublasCreate(&handle_);
    }

    ~Conv2dIm2Col() {
        if (col_buffer_) cudaFree(col_buffer_);
        cublasDestroy(handle_);
    }

    void forward(
        const float* input,   // [N, C_in, H, W]
        const float* weight,  // [C_out, C_in, K, K]
        float* output,        // [N, C_out, H_out, W_out]
        int N, int C_in, int H, int W,
        int C_out, int K,
        int pad, int stride
    ) {
        int H_out = (H + 2 * pad - K) / stride + 1;
        int W_out = (W + 2 * pad - K) / stride + 1;

        // 分配col buffer
        size_t required_size = N * C_in * K * K * H_out * W_out;
        if (required_size > col_buffer_size_) {
            if (col_buffer_) cudaFree(col_buffer_);
            CUDA_CHECK(cudaMalloc(&col_buffer_, required_size * sizeof(float)));
            col_buffer_size_ = required_size;
        }

        // Im2Col变换
        int total_elements = N * C_in * K * K * H_out * W_out;
        int blockSize = 256;
        int gridSize = (total_elements + blockSize - 1) / blockSize;

        im2col<<<gridSize, blockSize>>>(
            input, col_buffer_,
            N, C_in, H, W,
            K, H_out, W_out,
            pad, stride
        );
        CUDA_CHECK(cudaGetLastError());

        // 使用cuBLAS进行矩阵乘法
        // output = weight * col
        // [C_out, H_out*W_out] = [C_out, C_in*K*K] * [C_in*K*K, H_out*W_out]
        float alpha = 1.0f;
        float beta = 0.0f;

        for (int n = 0; n < N; ++n) {
            cublasSgemm(
                handle_,
                CUBLAS_OP_N, CUBLAS_OP_N,
                H_out * W_out,  // M
                C_out,          // N
                C_in * K * K,   // K
                &alpha,
                col_buffer_ + n * C_in * K * K * H_out * W_out,  // A
                H_out * W_out,
                weight,  // B
                C_in * K * K,
                &beta,
                output + n * C_out * H_out * W_out,  // C
                H_out * W_out
            );
        }
    }
};
```

#### 5. Winograd卷积 (convolution_winograd.cuh)

```cuda
#pragma once

#include "cuda_utils.cuh"

// Winograd F(2x2, 3x3)变换矩阵
// 输出tile 2x2，卷积核 3x3
// G = 变换卷积核的矩阵
// B = 变换输入的矩阵
// A = 变换输出的矩阵

// 变换矩阵（存储在常量内存）
__constant__ float G[4][3] = {
    {1.0f, 0.0f, 0.0f},
    {0.5f, 0.5f, 0.5f},
    {0.5f, -0.5f, 0.5f},
    {0.0f, 0.0f, 1.0f}
};

__constant__ float Gt[3][4] = {
    {1.0f, 0.5f, 0.5f, 0.0f},
    {0.0f, 0.5f, -0.5f, 0.0f},
    {0.0f, 0.5f, 0.5f, 1.0f}
};

__constant__ float B[4][4] = {
    {1.0f, 0.0f, -1.0f, 0.0f},
    {0.0f, 1.0f, 1.0f, 0.0f},
    {0.0f, -1.0f, 1.0f, 0.0f},
    {0.0f, 1.0f, 0.0f, -1.0f}
};

__constant__ float Bt[4][4] = {
    {1.0f, 0.0f, 0.0f, 0.0f},
    {0.0f, 1.0f, -1.0f, 1.0f},
    {-1.0f, 1.0f, 1.0f, 0.0f},
    {0.0f, 0.0f, 0.0f, -1.0f}
};

__constant__ float A[2][4] = {
    {1.0f, 1.0f, 1.0f, 0.0f},
    {0.0f, 1.0f, -1.0f, -1.0f}
};

__constant__ float At[4][2] = {
    {1.0f, 0.0f},
    {1.0f, 1.0f},
    {1.0f, -1.0f},
    {0.0f, -1.0f}
};

// 变换卷积核: U = G * g * G^T
__global__ void transformKernel(
    const float* kernel,  // [C_out, C_in, 3, 3]
    float* U,             // [4, 4, C_out, C_in]
    int C_out, int C_in
) {
    int c_out = blockIdx.x * blockDim.x + threadIdx.x;
    int c_in = blockIdx.y * blockDim.y + threadIdx.y;

    if (c_out >= C_out || c_in >= C_in) return;

    // 加载3x3卷积核
    float g[3][3];
    int base = c_out * (C_in * 9) + c_in * 9;
    for (int i = 0; i < 3; ++i) {
        for (int j = 0; j < 3; ++j) {
            g[i][j] = kernel[base + i * 3 + j];
        }
    }

    // 计算 temp = G * g
    float temp[4][3];
    for (int i = 0; i < 4; ++i) {
        for (int j = 0; j < 3; ++j) {
            temp[i][j] = 0.0f;
            for (int k = 0; k < 3; ++k) {
                temp[i][j] += G[i][k] * g[k][j];
            }
        }
    }

    // 计算 U = temp * G^T
    for (int i = 0; i < 4; ++i) {
        for (int j = 0; j < 4; ++j) {
            float val = 0.0f;
            for (int k = 0; k < 3; ++k) {
                val += temp[i][k] * Gt[k][j];
            }
            // 存储格式: [4, 4, C_out, C_in]
            int idx = i * (4 * C_out * C_in) + j * (C_out * C_in) +
                     c_out * C_in + c_in;
            U[idx] = val;
        }
    }
}

// Winograd卷积的完整实现较复杂，这里给出框架
class Conv2dWinograd {
    float* U_;  // 变换后的卷积核
    bool kernel_transformed_;

public:
    Conv2dWinograd() : U_(nullptr), kernel_transformed_(false) {}

    ~Conv2dWinograd() {
        if (U_) cudaFree(U_);
    }

    void transformKernels(const float* kernel, int C_out, int C_in) {
        if (U_) cudaFree(U_);
        CUDA_CHECK(cudaMalloc(&U_, 16 * C_out * C_in * sizeof(float)));

        dim3 blockDim(16, 16);
        dim3 gridDim(
            (C_out + 15) / 16,
            (C_in + 15) / 16
        );

        transformKernel<<<gridDim, blockDim>>>(kernel, U_, C_out, C_in);
        CUDA_CHECK(cudaGetLastError());

        kernel_transformed_ = true;
    }

    // forward实现需要:
    // 1. 将输入分块并变换 (B^T * d * B)
    // 2. 逐元素乘法 (U ⊙ V)
    // 3. 反变换得到输出 (A^T * (U ⊙ V) * A)
};
```

#### 6. 基准测试 (main.cu)

```cuda
#include "cuda_utils.cuh"
#include "convolution_naive.cuh"
#include "convolution_shared.cuh"
#include "convolution_im2col.cuh"
#include <iostream>
#include <vector>
#include <random>

void benchmark() {
    printDeviceInfo();
    std::cout << "\n=== Convolution Benchmark ===\n\n";

    // 测试配置
    struct Config {
        int N, C_in, H, W, C_out, K;
    };

    std::vector<Config> configs = {
        {1, 64, 56, 56, 64, 3},     // ResNet conv1
        {1, 128, 28, 28, 128, 3},   // ResNet conv2
        {1, 256, 14, 14, 256, 3},   // ResNet conv3
        {1, 512, 7, 7, 512, 3},     // ResNet conv4
        {32, 64, 56, 56, 64, 3},    // Batch=32
    };

    int pad = 1;
    int stride = 1;

    std::mt19937 rng(42);
    std::uniform_real_distribution<float> dist(-1.0f, 1.0f);

    for (const auto& cfg : configs) {
        int H_out = (cfg.H + 2 * pad - cfg.K) / stride + 1;
        int W_out = (cfg.W + 2 * pad - cfg.K) / stride + 1;

        size_t input_size = cfg.N * cfg.C_in * cfg.H * cfg.W;
        size_t kernel_size = cfg.C_out * cfg.C_in * cfg.K * cfg.K;
        size_t output_size = cfg.N * cfg.C_out * H_out * W_out;

        // 分配内存
        std::vector<float> h_input(input_size);
        std::vector<float> h_kernel(kernel_size);
        std::vector<float> h_output(output_size);

        for (auto& v : h_input) v = dist(rng);
        for (auto& v : h_kernel) v = dist(rng);

        DeviceArray<float> d_input(input_size);
        DeviceArray<float> d_kernel(kernel_size);
        DeviceArray<float> d_output(output_size);

        d_input.copyFromHost(h_input.data());
        d_kernel.copyFromHost(h_kernel.data());

        GpuTimer timer;
        constexpr int WARMUP = 5;
        constexpr int ITERATIONS = 20;

        std::cout << "Config: N=" << cfg.N << ", C_in=" << cfg.C_in
                  << ", H=" << cfg.H << ", W=" << cfg.W
                  << ", C_out=" << cfg.C_out << ", K=" << cfg.K << "\n";

        // 朴素实现
        for (int i = 0; i < WARMUP; ++i) {
            conv2dNaiveLaunch(
                d_input.data(), d_kernel.data(), d_output.data(),
                cfg.N, cfg.C_in, cfg.H, cfg.W,
                cfg.C_out, cfg.K, pad, stride
            );
        }
        cudaDeviceSynchronize();

        timer.start();
        for (int i = 0; i < ITERATIONS; ++i) {
            conv2dNaiveLaunch(
                d_input.data(), d_kernel.data(), d_output.data(),
                cfg.N, cfg.C_in, cfg.H, cfg.W,
                cfg.C_out, cfg.K, pad, stride
            );
        }
        timer.stop();
        float naiveTime = timer.elapsed() / ITERATIONS;

        // 共享内存实现
        for (int i = 0; i < WARMUP; ++i) {
            conv2dSharedLaunch(
                d_input.data(), d_kernel.data(), d_output.data(),
                cfg.N, cfg.C_in, cfg.H, cfg.W,
                cfg.C_out, cfg.K, pad, stride
            );
        }
        cudaDeviceSynchronize();

        timer.start();
        for (int i = 0; i < ITERATIONS; ++i) {
            conv2dSharedLaunch(
                d_input.data(), d_kernel.data(), d_output.data(),
                cfg.N, cfg.C_in, cfg.H, cfg.W,
                cfg.C_out, cfg.K, pad, stride
            );
        }
        timer.stop();
        float sharedTime = timer.elapsed() / ITERATIONS;

        // Im2Col实现
        Conv2dIm2Col im2col;
        for (int i = 0; i < WARMUP; ++i) {
            im2col.forward(
                d_input.data(), d_kernel.data(), d_output.data(),
                cfg.N, cfg.C_in, cfg.H, cfg.W,
                cfg.C_out, cfg.K, pad, stride
            );
        }
        cudaDeviceSynchronize();

        timer.start();
        for (int i = 0; i < ITERATIONS; ++i) {
            im2col.forward(
                d_input.data(), d_kernel.data(), d_output.data(),
                cfg.N, cfg.C_in, cfg.H, cfg.W,
                cfg.C_out, cfg.K, pad, stride
            );
        }
        timer.stop();
        float im2colTime = timer.elapsed() / ITERATIONS;

        // 计算TFLOPS
        double flops = 2.0 * cfg.N * cfg.C_out * cfg.C_in *
                       cfg.K * cfg.K * H_out * W_out;
        double naiveTflops = flops / (naiveTime * 1e9);
        double sharedTflops = flops / (sharedTime * 1e9);
        double im2colTflops = flops / (im2colTime * 1e9);

        std::cout << "  Naive:  " << naiveTime << " ms, "
                  << naiveTflops << " TFLOPS\n";
        std::cout << "  Shared: " << sharedTime << " ms, "
                  << sharedTflops << " TFLOPS\n";
        std::cout << "  Im2Col: " << im2colTime << " ms, "
                  << im2colTflops << " TFLOPS\n";
        std::cout << "  Speedup (Shared/Naive): "
                  << naiveTime / sharedTime << "x\n";
        std::cout << "  Speedup (Im2Col/Naive): "
                  << naiveTime / im2colTime << "x\n\n";
    }
}

int main() {
    benchmark();
    return 0;
}
```

---

## 检验标准

### 知识检验
1. [ ] 能画出SM的内部架构图，标注Warp Scheduler、Processing Block、Register File、Shared Memory
2. [ ] 能解释SIMT执行模型，对比SIMT与SIMD的关键差异
3. [ ] 掌握GPU内存层次（寄存器→共享→L1→L2→全局→主机）的延迟、带宽和适用场景
4. [ ] 能分析分支分歧对Warp执行效率的影响，提出消除策略
5. [ ] 能正确计算1D/2D/3D网格中的线程索引，掌握Grid-Stride Loop模式
6. [ ] 理解pinned memory的DMA优势，能解释Unified Memory的页迁移机制
7. [ ] 掌握内存合并访问的硬件条件，能通过stride分析计算带宽效率
8. [ ] 理解共享内存Bank冲突的产生条件和padding消除策略
9. [ ] 能使用Occupancy API计算给定配置的占用率，理解三个限制因素
10. [ ] 掌握CUDA Streams并发模型，能设计计算与传输重叠的流水线
11. [ ] 能使用Warp Shuffle原语实现归约和前缀和
12. [ ] 能使用Nsight Systems和Nsight Compute进行系统级和内核级性能分析
13. [ ] 理解CUDA→HIP的API映射，能编写跨NVIDIA/AMD的可移植代码

### 实践检验
1. [ ] 完成CUDA环境搭建并编写GPU硬件探测程序
2. [ ] 实现朴素卷积并正确运行
3. [ ] 共享内存优化获得2倍以上加速
4. [ ] Im2Col实现能利用cuBLAS
5. [ ] 实现完整的向量运算库（加法、点积、SAXPY、范数）
6. [ ] 完成合并访问基准测试，画出stride vs bandwidth曲线
7. [ ] 实现矩阵转置的四个优化版本并对比
8. [ ] 实现并行归约的多个优化版本（交错→顺序→Warp归约）
9. [ ] 完成AoS vs SoA性能对比实验
10. [ ] 实现多流流水线并用Nsight Systems验证重叠
11. [ ] 使用Nsight Compute分析至少3个内核的性能瓶颈

### 代码质量
1. [ ] 所有CUDA API调用都有错误检查（CUDA_CHECK宏）
2. [ ] 无内存泄漏（使用compute-sanitizer验证）
3. [ ] 代码可配置（块大小、Grid大小等参数化）
4. [ ] 有完整的基准测试框架（warmup + 多次迭代 + 统计）
5. [ ] 使用NVTX标记关键代码段（便于profiling）

---

## 输出物清单

1. **学习笔记**
   - [ ] GPU架构详解笔记（SM结构、内存层次、SIMT模型）
   - [ ] CUDA编程要点总结（线程模型、内存管理、错误处理）
   - [ ] 内存优化技术文档（合并访问、Bank冲突、AoS/SoA）
   - [ ] 高级优化技术文档（Streams、Warp原语、原子操作）

2. **代码产出**
   - [ ] CUDA工具库（错误检查、计时器、设备内存管理）
   - [ ] 完整的向量运算库（GPU加速）
   - [ ] 多种卷积实现（朴素、共享内存、Im2Col、Winograd）
   - [ ] 归约优化系列（5个版本递进优化）
   - [ ] 矩阵转置优化系列（4个版本递进优化）
   - [ ] 性能基准测试框架

3. **分析报告**
   - [ ] 各卷积实现的TFLOPS性能对比
   - [ ] Nsight Compute内核分析报告（至少3个内核）
   - [ ] Nsight Systems流水线并发分析报告
   - [ ] GPU架构演进对比报告（Ampere vs Hopper vs Blackwell）

---

## 时间分配表

| 周次 | 理论学习 | 源码阅读 | 项目实践 | 总计 |
|------|----------|----------|----------|------|
| Week 1 | 18h | 8h | 9h | 35h |
| Week 2 | 12h | 8h | 15h | 35h |
| Week 3 | 10h | 5h | 20h | 35h |
| Week 4 | 5h | 5h | 25h | 35h |
| **总计** | **45h** | **26h** | **69h** | **140h** |

---

## 下月预告

**Month 56: C++23新特性**

下个月将学习C++23带来的新特性：
- std::expected和单子操作
- std::mdspan多维数组视图
- std::generator协程
- std::print格式化输出
- 实践项目：使用C++23重构现有代码

建议提前：
1. 确保编译器支持C++23（GCC 13+, Clang 17+）
2. 复习C++20特性（concepts, ranges, coroutines）
3. 了解函数式编程概念
