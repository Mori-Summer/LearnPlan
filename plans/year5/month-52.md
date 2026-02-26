# Month 52: 面向数据设计实践 (Data-Oriented Design in Practice)

## 本月主题概述

在上月学习DOD基础之后，本月将把这些原理应用于更复杂的实际场景。我们将实现DOD风格的空间数据结构、碰撞检测系统，并探索多线程环境下的DOD设计模式。通过构建一个高性能物理引擎核心，深入理解DOD在复杂系统中的应用。

### 学习目标
- 掌握空间数据结构的DOD实现
- 实现高效的宽相位和窄相位碰撞检测
- 理解多线程DOD设计模式
- 构建可扩展的高性能物理引擎核心
- 学会性能分析与调优

**进阶目标**：
- 深入理解均匀网格、四叉树/八叉树、BVH、SAP四种空间划分方法的缓存行为差异，能够根据场景特征选择最优方案
- 掌握GJK/EPA算法的几何直觉与DOD友好的批量化实现，理解Minkowski差的计算本质
- 能够设计无锁（lock-free）碰撞对收集器，理解memory ordering对多线程DOD的影响
- 掌握Job System架构与Work Stealing调度策略，实现物理引擎的任务图并行化
- 理解Sequential Impulse约束求解器的数学推导与迭代收敛性，实现稳定的碰撞响应
- 能够使用perf/VTune/Instruments对物理引擎进行全链路性能剖析，识别带宽瓶颈与计算瓶颈

---

## 理论学习内容

### 第一周：空间数据结构的DOD实现（35小时）

**学习目标**：
- [ ] 深入理解均匀网格（Uniform Grid）的DOD实现：计数排序映射、前缀和技巧、单元格遍历策略
- [ ] 掌握四叉树/八叉树的缓存友好实现：隐式索引vs指针、宽度优先存储布局、Morton码排序
- [ ] 理解BVH（Bounding Volume Hierarchy）的构建策略：SAH启发式、中点分割、线性BVH
- [ ] 掌握SAP（Sweep and Prune）算法的增量更新机制与DOD友好的排序数组布局
- [ ] 学会使用空间哈希（Spatial Hashing）处理动态场景，理解哈希函数选择对碰撞率的影响
- [ ] 能够量化比较不同空间划分方法的缓存命中率、内存带宽使用与查询复杂度
- [ ] 理解Morton码（Z-order curve）在空间局部性保持中的数学原理与SIMD位交错技巧

**阅读材料**：
- [ ] 《Real-Time Collision Detection》- Christer Ericson（Chapter 7: Spatial Partitioning）
- [ ] 《Game Physics Engine Development》- Ian Millington（Part III: Broad-Phase Collision Detection）
- [ ] Bullet Physics设计文档 - btDbvtBroadphase动态BVH实现
- [ ] Box2D源码分析 - b2DynamicTree与b2BroadPhase
- [ ] 《Thinking Parallel, Part III: Tree Construction on the GPU》- Tero Karras (NVIDIA)
- [ ] GDC 2015:《Physics for Game Programmers: Spatial Hashing》
- [ ] 《Morton Codes and Z-order Curves》- 深入理解空间填充曲线

---

#### 核心概念

**空间划分策略全景**
```
┌─────────────────────────────────────────────────────────────────┐
│                      空间划分方法全景                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  均匀网格 (Uniform Grid)              四叉树/八叉树               │
│  ┌──┬──┬──┬──┐                       ┌───────┬───────┐          │
│  │  │  │  │  │                       │       │   ┌─┬─┤          │
│  ├──┼──┼──┼──┤                       │       │   ├─┼─┤          │
│  │  │  │  │  │                       ├───┬───┼───┴─┴─┤          │
│  ├──┼──┼──┼──┤                       │   │   │       │          │
│  │  │  │  │  │                       └───┴───┴───────┘          │
│  └──┴──┴──┴──┘                                                   │
│  优点：O(1)查找、缓存友好、SIMD友好    优点：自适应密度、节省内存   │
│  缺点：不适应不均匀分布、内存固定开销    缺点：指针追踪、缓存不友好  │
│  最佳场景：物体大小均匀、密度均匀        最佳场景：物体大小/密度差异大│
│                                                                  │
│  BVH (层次包围盒)                     SAP (扫掠与裁剪)            │
│       ●───────────●                  按X排序: ───○─○──○──○─      │
│      / \         / \                 按Y排序: ──○──○─○───○─      │
│     ●   ●       ●   ●                只检测轴区间重叠的对象对      │
│    /|   |\     /|   |\               优点：增量更新O(n)、排序缓存好│
│   ● ●   ● ●   ● ●   ● ●            缺点：高速物体频繁重排序      │
│  优点：查询O(log n)、自适应           最佳场景：低速/静态为主       │
│  缺点：构建O(n log n)、重建开销大                                 │
│  最佳场景：射线查询、动态物体                                      │
│                                                                  │
│  空间哈希 (Spatial Hashing)                                       │
│  hash(cell) = (x*p1 ^ y*p2 ^ z*p3) % tableSize                  │
│  优点：内存自适应、支持无限空间                                    │
│  缺点：哈希冲突、不支持范围查询                                    │
│  最佳场景：稀疏场景、物体数量变化大                                │
└─────────────────────────────────────────────────────────────────┘
```

**DOD视角下的关键设计决策**
```
┌────────────────────────────────────────────────────────────┐
│        传统OOP空间结构 vs DOD空间结构                        │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  OOP方式：                    DOD方式：                      │
│  ┌──────────┐                ┌──────────┐                   │
│  │ GridCell* │──→ objects[]   │ cellStart│ 连续索引数组      │
│  │ GridCell* │──→ objects[]   │ cellCount│ 前缀和定位        │
│  │ GridCell* │──→ objects[]   │ sorted[] │ 按cell排序的ID    │
│  └──────────┘                └──────────┘                   │
│  N次指针追踪                   0次指针追踪                    │
│  N次堆分配                     1次大块分配                    │
│  随机内存访问                   顺序内存扫描                   │
│                                                             │
│  结论：DOD网格的查询速度通常比OOP网格快3-10倍               │
│  原因：消除指针追踪 + 顺序访问 = 缓存命中率从30%→95%+       │
└────────────────────────────────────────────────────────────┘
```

---

#### 1.1 均匀网格的DOD深度实现

```cpp
// ==========================================
// 均匀网格（Uniform Grid）：DOD最友好的空间结构
// ==========================================
//
// 为什么均匀网格是DOD的首选？
//   在所有空间划分方法中，均匀网格对缓存最友好，因为：
//   1. 网格单元格到索引的映射是O(1)的简单算术——无需遍历树
//   2. 所有物体可以按单元格排序，使同一单元格的物体在内存中连续
//   3. 遍历相邻单元格只需简单的索引偏移——无指针追踪
//
// 关键技巧：计数排序（Counting Sort）
//   传统方法：每个单元格持有一个动态数组 → N个堆分配 + 指针追踪
//   DOD方法：用计数排序将所有物体按单元格重新排列 → 1个连续数组
//
//   这正是GPU粒子系统和SPH流体模拟使用的技术。
//   相同思想也出现在数据库的基数排序（radix sort）中。
//
// 关键洞察（Christer Ericson《Real-Time Collision Detection》）：
//   "The uniform grid is the simplest spatial data structure to implement
//    and often the best choice for objects of similar size."
//
// 时间复杂度分析：
//   构建：O(n)——两遍扫描 + 前缀和
//   查询：O(1)定位单元格 + O(k)遍历单元格内物体
//   内存：O(n + cellCount)——物体索引 + 单元格元数据

#include <vector>
#include <cstdint>
#include <algorithm>
#include <numeric>
#include <cmath>

namespace physics::spatial {

// ──────────────────────────────────────
// DOD风格均匀网格——完整教学实现
// ──────────────────────────────────────
//
// 数据布局策略：
//   不存储"单元格对象"，只存储三个紧凑数组：
//   - cellCount[i]：第i个单元格有多少物体
//   - cellStart[i]：第i个单元格在sortedIds中的起始位置
//   - sortedIds[]：按单元格排序的物体ID
//
//   查询时：cell i 的所有物体 = sortedIds[cellStart[i] .. cellStart[i]+cellCount[i])
//   这就是经典的"间接索引"模式——DOD的基石之一。

struct UniformGrid {
    // 网格配置（只读，设置后不变）
    float originX, originY, originZ;   // 网格原点（世界空间最小角）
    float cellSize;                     // 单元格边长
    float invCellSize;                  // 1/cellSize，避免除法
    int dimX, dimY, dimZ;              // 各轴单元格数

    // 物体数据（SoA布局，外部拥有）
    // 网格本身不复制物体数据，只存储排序后的索引

    // 网格映射数据
    std::vector<uint32_t> cellCount;    // 每个单元格的物体数
    std::vector<uint32_t> cellStart;    // 前缀和——起始索引
    std::vector<uint32_t> sortedIds;    // 按单元格排序的物体ID

    // 初始化
    void init(float worldMinX, float worldMinY, float worldMinZ,
              float worldMaxX, float worldMaxY, float worldMaxZ,
              float cellSz) {
        originX = worldMinX;
        originY = worldMinY;
        originZ = worldMinZ;
        cellSize = cellSz;
        invCellSize = 1.0f / cellSz;

        dimX = std::max(1, static_cast<int>(std::ceil((worldMaxX - worldMinX) * invCellSize)));
        dimY = std::max(1, static_cast<int>(std::ceil((worldMaxY - worldMinY) * invCellSize)));
        dimZ = std::max(1, static_cast<int>(std::ceil((worldMaxZ - worldMinZ) * invCellSize)));

        size_t totalCells = static_cast<size_t>(dimX) * dimY * dimZ;
        cellCount.resize(totalCells, 0);
        cellStart.resize(totalCells, 0);
    }

    // 将世界坐标映射到单元格索引——O(1)，纯算术
    int cellIndex(float x, float y, float z) const {
        int cx = static_cast<int>((x - originX) * invCellSize);
        int cy = static_cast<int>((y - originY) * invCellSize);
        int cz = static_cast<int>((z - originZ) * invCellSize);

        // clamp防止越界
        cx = std::clamp(cx, 0, dimX - 1);
        cy = std::clamp(cy, 0, dimY - 1);
        cz = std::clamp(cz, 0, dimZ - 1);

        // 线性索引：x + y*dimX + z*dimX*dimY
        return cx + cy * dimX + cz * dimX * dimY;
    }

    // 重建网格——每帧调用（动态物体）
    //
    // 核心算法：两遍计数排序
    //   第一遍：统计每个单元格的物体数量
    //   前缀和：计算每个单元格在排序数组中的起始位置
    //   第二遍：将物体ID放到对应单元格的位置
    //
    // 这个算法的美妙之处：
    //   - O(n)时间——不需要比较排序的O(n log n)
    //   - 稳定的——同一单元格内物体的相对顺序保持不变
    //   - 缓存友好——两遍线性扫描，完美利用预取
    void rebuild(const float* posX, const float* posY, const float* posZ,
                 size_t objectCount) {
        const size_t totalCells = cellCount.size();

        // 重置计数
        std::fill(cellCount.begin(), cellCount.end(), 0);

        // 第一遍：计数
        for (size_t i = 0; i < objectCount; ++i) {
            int cell = cellIndex(posX[i], posY[i], posZ[i]);
            ++cellCount[cell];
        }

        // 前缀和（exclusive prefix sum）
        // cellStart[i] = sum(cellCount[0..i-1])
        uint32_t total = 0;
        for (size_t i = 0; i < totalCells; ++i) {
            cellStart[i] = total;
            total += cellCount[i];
        }

        // 第二遍：散布（scatter）
        sortedIds.resize(objectCount);
        // 使用临时写指针数组——每个单元格当前应该写入的位置
        std::vector<uint32_t> writePos = cellStart;  // 拷贝

        for (size_t i = 0; i < objectCount; ++i) {
            int cell = cellIndex(posX[i], posY[i], posZ[i]);
            sortedIds[writePos[cell]++] = static_cast<uint32_t>(i);
        }
    }

    // 查询：获取某个单元格的所有物体
    // 返回 [begin, end) 指针对——零拷贝
    struct CellRange {
        const uint32_t* begin;
        const uint32_t* end;
        size_t count() const { return end - begin; }
    };

    CellRange getCell(int cx, int cy, int cz) const {
        if (cx < 0 || cx >= dimX || cy < 0 || cy >= dimY || cz < 0 || cz >= dimZ) {
            return {nullptr, nullptr};
        }
        int idx = cx + cy * dimX + cz * dimX * dimY;
        uint32_t start = cellStart[idx];
        uint32_t count = cellCount[idx];
        return {sortedIds.data() + start, sortedIds.data() + start + count};
    }

    // 查询：获取某个点所在单元格及其26个邻居的所有物体
    // 这是宽相位碰撞检测的核心操作
    void queryNeighborhood(float x, float y, float z,
                           std::vector<uint32_t>& result) const {
        int cx = static_cast<int>((x - originX) * invCellSize);
        int cy = static_cast<int>((y - originY) * invCellSize);
        int cz = static_cast<int>((z - originZ) * invCellSize);

        result.clear();

        // 3x3x3邻域
        for (int dz = -1; dz <= 1; ++dz) {
            for (int dy = -1; dy <= 1; ++dy) {
                for (int dx = -1; dx <= 1; ++dx) {
                    auto range = getCell(cx + dx, cy + dy, cz + dz);
                    for (auto it = range.begin; it != range.end; ++it) {
                        result.push_back(*it);
                    }
                }
            }
        }
    }
};

} // namespace physics::spatial
```

**均匀网格的缓存行为分析**

| 操作 | 内存访问模式 | 缓存行为 | 备注 |
|------|------------|---------|------|
| rebuild 第一遍 | 顺序读posX/Y/Z，随机写cellCount | 读：完美预取；写：随机但cellCount通常在L2内 | 瓶颈在写端 |
| rebuild 前缀和 | 顺序读写cellCount/cellStart | 完美顺序访问 | 极快 |
| rebuild 第二遍 | 顺序读pos，随机写sortedIds | 与第一遍类似 | 随机写是主要开销 |
| 查询单元格 | 连续读sortedIds | 完美预取 | DOD的核心优势 |
| 查询邻域 | 最多27次连续读 | 每个单元格内连续，但27个range可能分散 | 仍远好于指针追踪 |

---

#### 1.2 四叉树/八叉树的DOD友好实现

```cpp
// ==========================================
// 八叉树的DOD实现：隐式索引消除指针
// ==========================================
//
// 传统八叉树的问题：
//   每个节点有8个子节点指针 → 树遍历 = 指针追踪链
//   典型八叉树查询：深度D的树需要追踪D次指针
//   每次追踪可能缓存未命中 → D × 100ns = 微秒级延迟
//
// DOD解决方案：隐式八叉树（Implicit Octree）
//   类似二叉堆用数组存储完全二叉树的思路：
//   节点i的8个子节点位于 8*i+1 到 8*i+8
//   无需任何指针——纯数组索引！
//
// 但完全八叉树太浪费内存（大部分节点为空），
// 所以实际使用"线性八叉树"（Linear Octree）：
//   只存储叶节点，用Morton码隐式编码其在树中的位置。
//   查询时通过Morton码的前缀匹配找到相关叶节点。
//
// 关键洞察（Tero Karras, NVIDIA）：
//   "Linear BVH construction reduces the problem to sorting,
//    and sorting is something GPUs do very well."
//   同样的思想适用于CPU八叉树。

#include <vector>
#include <cstdint>
#include <algorithm>
#include <array>

namespace physics::spatial {

// Morton码（Z-order curve）编码器
// 将3D坐标交错编码为1D整数，保持空间局部性
//
// 原理：将x,y,z的二进制位交错排列
//   x = ...x2 x1 x0
//   y = ...y2 y1 y0
//   z = ...z2 z1 z0
//   Morton = ...z2 y2 x2 z1 y1 x1 z0 y0 x0
//
// 为什么Morton码保持空间局部性？
//   相邻的Morton码对应的空间位置大致相邻。
//   排序后，空间上近的物体在数组中也倾向相邻——
//   这极大改善了缓存行为。

struct MortonEncoder {
    // 展开位：在每个位之间插入2个空位
    // 例如：0b1011 → 0b001_000_001_001（每位间隔2位）
    static uint32_t expandBits(uint32_t v) {
        v = (v | (v << 16)) & 0x030000FF;
        v = (v | (v <<  8)) & 0x0300F00F;
        v = (v | (v <<  4)) & 0x030C30C3;
        v = (v | (v <<  2)) & 0x09249249;
        return v;
    }

    // 3D坐标 → 30位Morton码
    // 每个轴10位，共30位，支持1024³网格
    static uint32_t encode(uint32_t x, uint32_t y, uint32_t z) {
        x = std::min(x, 1023u);
        y = std::min(y, 1023u);
        z = std::min(z, 1023u);
        return (expandBits(z) << 2) | (expandBits(y) << 1) | expandBits(x);
    }

    // 浮点坐标 → Morton码
    // 先归一化到[0, 1023]范围，再编码
    static uint32_t encode(float x, float y, float z,
                           float minX, float minY, float minZ,
                           float maxX, float maxY, float maxZ) {
        float nx = (x - minX) / (maxX - minX) * 1023.0f;
        float ny = (y - minY) / (maxY - minY) * 1023.0f;
        float nz = (z - minZ) / (maxZ - minZ) * 1023.0f;
        return encode(static_cast<uint32_t>(nx),
                      static_cast<uint32_t>(ny),
                      static_cast<uint32_t>(nz));
    }
};

// ──────────────────────────────────────
// 线性八叉树：只存储叶节点 + Morton码排序
// ──────────────────────────────────────
//
// 设计理念：
//   不显式构建树结构，而是：
//   1. 为每个物体计算Morton码
//   2. 按Morton码排序
//   3. 查询时用二分搜索定位相关范围
//
//   这样所有物体按空间局部性排列在连续数组中。
//   查询"某区域内的物体"变成"查找Morton码在[lo, hi]范围内的元素"——
//   而这些元素在排序后的数组中是连续的（或近似连续的）。

struct LinearOctree {
    // 物体数据（按Morton码排序后的顺序）
    std::vector<uint32_t> mortonCodes;  // 每个物体的Morton码
    std::vector<uint32_t> sortedIds;    // 按Morton码排序的物体ID

    // 世界空间范围
    float minX, minY, minZ;
    float maxX, maxY, maxZ;

    void build(const float* posX, const float* posY, const float* posZ,
               size_t count,
               float worldMinX, float worldMinY, float worldMinZ,
               float worldMaxX, float worldMaxY, float worldMaxZ) {
        minX = worldMinX; minY = worldMinY; minZ = worldMinZ;
        maxX = worldMaxX; maxY = worldMaxY; maxZ = worldMaxZ;

        mortonCodes.resize(count);
        sortedIds.resize(count);

        // 1. 计算Morton码
        for (size_t i = 0; i < count; ++i) {
            mortonCodes[i] = MortonEncoder::encode(
                posX[i], posY[i], posZ[i],
                minX, minY, minZ, maxX, maxY, maxZ);
            sortedIds[i] = static_cast<uint32_t>(i);
        }

        // 2. 按Morton码排序（保持sortedIds同步）
        // 使用间接排序保持ID映射
        std::sort(sortedIds.begin(), sortedIds.end(),
                  [this](uint32_t a, uint32_t b) {
                      return mortonCodes[a] < mortonCodes[b];
                  });

        // 重排mortonCodes使其与sortedIds对应
        std::vector<uint32_t> tempMorton(count);
        for (size_t i = 0; i < count; ++i) {
            tempMorton[i] = mortonCodes[sortedIds[i]];
        }
        mortonCodes = std::move(tempMorton);
    }

    // 范围查询：找到Morton码在[loCode, hiCode]范围内的所有物体
    // 利用排序特性，用二分搜索 → O(log n + k)
    void queryRange(uint32_t loCode, uint32_t hiCode,
                    std::vector<uint32_t>& result) const {
        auto lo = std::lower_bound(mortonCodes.begin(), mortonCodes.end(), loCode);
        auto hi = std::upper_bound(mortonCodes.begin(), mortonCodes.end(), hiCode);

        size_t startIdx = lo - mortonCodes.begin();
        size_t endIdx = hi - mortonCodes.begin();

        for (size_t i = startIdx; i < endIdx; ++i) {
            result.push_back(sortedIds[i]);
        }
    }
};

} // namespace physics::spatial
```

---

#### 1.3 BVH层次包围盒树

```cpp
// ==========================================
// BVH（Bounding Volume Hierarchy）：射线查询的利器
// ==========================================
//
// BVH vs 均匀网格：
//   均匀网格：O(1)点查询，但不擅长射线/形状查询
//   BVH：O(log n)所有类型查询，自适应物体分布
//
// BVH在物理引擎中的角色：
//   - Box2D使用动态AABB树（b2DynamicTree）作为宽相位
//   - Bullet使用dbvt（动态BVH）
//   - PhysX使用基于BVH的pruning structure
//
// DOD友好的BVH设计要点：
//   1. 节点数组存储（不用 new/delete）
//   2. 子节点用索引而非指针（32位索引 vs 64位指针）
//   3. 叶节点数据分离存储（热路径只访问节点AABB）
//   4. 宽BVH（4-wide或8-wide）适合SIMD测试
//
// 关键洞察（Ingo Wald, Intel）：
//   "A well-built BVH can answer ray queries 10x faster than
//    a uniform grid for scenes with varying object sizes."

#include <vector>
#include <cstdint>
#include <algorithm>
#include <cmath>
#include <limits>

namespace physics::spatial {

// BVH节点——紧凑布局
// 设计目标：每个节点恰好32字节，半个缓存行
// 两个相邻节点占满一个缓存行——完美对齐
struct BVHNode {
    // AABB (24 bytes)
    float minX, minY, minZ;
    float maxX, maxY, maxZ;

    // 子节点/叶数据 (8 bytes)
    union {
        struct {
            uint32_t leftChild;   // 左子节点索引
            uint32_t rightChild;  // 右子节点索引（0xFFFFFFFF = 无）
        };
        struct {
            uint32_t firstPrim;   // 叶节点：第一个图元索引
            uint32_t primCount;   // 叶节点：图元数量
        };
    };

    bool isLeaf() const { return rightChild == 0xFFFFFFFF; }
};
static_assert(sizeof(BVHNode) == 32, "BVHNode should be 32 bytes");

// ──────────────────────────────────────
// 自顶向下BVH构建器
// ──────────────────────────────────────
//
// 构建策略对比：
//   中点分割（Midpoint Split）：最简单，O(n log n)，质量一般
//   SAH（Surface Area Heuristic）：最优质，O(n² log n)或O(n log² n)
//   LBVH（Linear BVH）：Morton码排序，O(n log n)，GPU友好
//
// 这里实现中点分割——简单且对教学友好

class BVHBuilder {
public:
    std::vector<BVHNode> nodes;
    std::vector<uint32_t> primIndices;  // 图元索引重排序

    void build(const float* aabbMinX, const float* aabbMinY, const float* aabbMinZ,
               const float* aabbMaxX, const float* aabbMaxY, const float* aabbMaxZ,
               size_t primCount) {
        nodes.clear();
        nodes.reserve(primCount * 2);  // 二叉树最多2n-1个节点

        primIndices.resize(primCount);
        std::iota(primIndices.begin(), primIndices.end(), 0);

        // 计算质心用于分割
        std::vector<float> centroidX(primCount), centroidY(primCount), centroidZ(primCount);
        for (size_t i = 0; i < primCount; ++i) {
            centroidX[i] = (aabbMinX[i] + aabbMaxX[i]) * 0.5f;
            centroidY[i] = (aabbMinY[i] + aabbMaxY[i]) * 0.5f;
            centroidZ[i] = (aabbMinZ[i] + aabbMaxZ[i]) * 0.5f;
        }

        buildRecursive(0, primCount,
                       aabbMinX, aabbMinY, aabbMinZ,
                       aabbMaxX, aabbMaxY, aabbMaxZ,
                       centroidX.data(), centroidY.data(), centroidZ.data());
    }

    // AABB查询：找到与queryAABB重叠的所有图元
    void queryAABB(float qMinX, float qMinY, float qMinZ,
                   float qMaxX, float qMaxY, float qMaxZ,
                   std::vector<uint32_t>& result) const {
        if (nodes.empty()) return;

        // 栈式遍历——避免递归调用开销
        uint32_t stack[64];  // 固定大小栈，BVH深度不会超过64
        int stackPtr = 0;
        stack[stackPtr++] = 0;  // 根节点

        while (stackPtr > 0) {
            uint32_t nodeIdx = stack[--stackPtr];
            const BVHNode& node = nodes[nodeIdx];

            // AABB重叠测试
            if (qMinX > node.maxX || qMaxX < node.minX ||
                qMinY > node.maxY || qMaxY < node.minY ||
                qMinZ > node.maxZ || qMaxZ < node.minZ) {
                continue;  // 不重叠，跳过
            }

            if (node.isLeaf()) {
                // 叶节点：输出所有图元
                for (uint32_t i = 0; i < node.primCount; ++i) {
                    result.push_back(primIndices[node.firstPrim + i]);
                }
            } else {
                // 内部节点：将子节点入栈
                stack[stackPtr++] = node.leftChild;
                stack[stackPtr++] = node.rightChild;
            }
        }
    }

private:
    uint32_t buildRecursive(
        size_t begin, size_t end,
        const float* aabbMinX, const float* aabbMinY, const float* aabbMinZ,
        const float* aabbMaxX, const float* aabbMaxY, const float* aabbMaxZ,
        const float* centroidX, const float* centroidY, const float* centroidZ) {

        uint32_t nodeIdx = static_cast<uint32_t>(nodes.size());
        nodes.push_back({});
        BVHNode& node = nodes.back();

        // 计算当前范围的AABB
        node.minX = node.minY = node.minZ = std::numeric_limits<float>::max();
        node.maxX = node.maxY = node.maxZ = -std::numeric_limits<float>::max();

        for (size_t i = begin; i < end; ++i) {
            uint32_t prim = primIndices[i];
            node.minX = std::min(node.minX, aabbMinX[prim]);
            node.minY = std::min(node.minY, aabbMinY[prim]);
            node.minZ = std::min(node.minZ, aabbMinZ[prim]);
            node.maxX = std::max(node.maxX, aabbMaxX[prim]);
            node.maxY = std::max(node.maxY, aabbMaxY[prim]);
            node.maxZ = std::max(node.maxZ, aabbMaxZ[prim]);
        }

        size_t primCount = end - begin;

        // 叶节点条件：图元数量少于阈值
        if (primCount <= 4) {
            node.firstPrim = static_cast<uint32_t>(begin);
            node.primCount = static_cast<uint32_t>(primCount);
            node.rightChild = 0xFFFFFFFF;  // 标记为叶
            return nodeIdx;
        }

        // 选择分割轴：选择质心范围最大的轴
        float centroidMinX = std::numeric_limits<float>::max();
        float centroidMaxX = -std::numeric_limits<float>::max();
        float centroidMinY = centroidMinX, centroidMaxY = centroidMaxX;
        float centroidMinZ = centroidMinX, centroidMaxZ = centroidMaxX;

        for (size_t i = begin; i < end; ++i) {
            uint32_t prim = primIndices[i];
            centroidMinX = std::min(centroidMinX, centroidX[prim]);
            centroidMaxX = std::max(centroidMaxX, centroidX[prim]);
            centroidMinY = std::min(centroidMinY, centroidY[prim]);
            centroidMaxY = std::max(centroidMaxY, centroidY[prim]);
            centroidMinZ = std::min(centroidMinZ, centroidZ[prim]);
            centroidMaxZ = std::max(centroidMaxZ, centroidZ[prim]);
        }

        float rangeX = centroidMaxX - centroidMinX;
        float rangeY = centroidMaxY - centroidMinY;
        float rangeZ = centroidMaxZ - centroidMinZ;

        int splitAxis = 0;
        float splitPos;
        if (rangeY > rangeX && rangeY > rangeZ) splitAxis = 1;
        else if (rangeZ > rangeX) splitAxis = 2;

        const float* centroid = (splitAxis == 0) ? centroidX :
                                (splitAxis == 1) ? centroidY : centroidZ;
        float centroidMin = (splitAxis == 0) ? centroidMinX :
                            (splitAxis == 1) ? centroidMinY : centroidMinZ;
        float centroidMax = (splitAxis == 0) ? centroidMaxX :
                            (splitAxis == 1) ? centroidMaxY : centroidMaxZ;
        splitPos = (centroidMin + centroidMax) * 0.5f;

        // 分区（partition）
        auto mid = std::partition(
            primIndices.begin() + begin,
            primIndices.begin() + end,
            [centroid, splitPos](uint32_t idx) {
                return centroid[idx] < splitPos;
            });

        size_t midIdx = mid - primIndices.begin();

        // 防止退化：如果所有图元都在一侧，强制等分
        if (midIdx == begin || midIdx == end) {
            midIdx = begin + primCount / 2;
        }

        // 递归构建子树
        // 注意：递归调用可能导致nodes重新分配，所以用索引而非引用
        uint32_t leftChild = buildRecursive(begin, midIdx,
            aabbMinX, aabbMinY, aabbMinZ,
            aabbMaxX, aabbMaxY, aabbMaxZ,
            centroidX, centroidY, centroidZ);

        uint32_t rightChild = buildRecursive(midIdx, end,
            aabbMinX, aabbMinY, aabbMinZ,
            aabbMaxX, aabbMaxY, aabbMaxZ,
            centroidX, centroidY, centroidZ);

        nodes[nodeIdx].leftChild = leftChild;
        nodes[nodeIdx].rightChild = rightChild;

        return nodeIdx;
    }
};

} // namespace physics::spatial
```

---

#### 1.4 SAP扫掠与裁剪算法

```cpp
// ==========================================
// SAP（Sweep and Prune）：排序轴投影
// ==========================================
//
// SAP的核心思想极其优雅：
//   如果两个AABB不碰撞，那么在至少一个轴上，它们的投影区间不重叠。
//   反过来：只有当三个轴的投影都重叠时，AABB才重叠。
//
// 算法流程：
//   1. 将每个AABB在X轴上投影为[min, max]区间
//   2. 将所有min和max端点排序
//   3. 扫描排序后的端点：
//      遇到min → 物体"进入"活跃集合
//      遇到max → 物体"离开"活跃集合
//      活跃集合中的所有物体对在X轴上重叠
//   4. 对X轴重叠的对，再检测Y轴和Z轴
//
// 为什么SAP对DOD友好？
//   排序后的端点数组是连续内存——顺序扫描缓存友好。
//   而且每帧物体移动很小，排序几乎是已排序数组的微调——
//   插入排序在"几乎有序"的数据上是O(n)的！
//
// Box2D就使用SAP作为默认宽相位。
//
// 关键洞察（Erin Catto, Box2D作者）：
//   "Sweep and Prune works well when objects don't move much between frames.
//    For most games, this is the common case."

#include <vector>
#include <cstdint>
#include <algorithm>

namespace physics::spatial {

struct SweepAndPrune {
    // 端点类型
    struct Endpoint {
        float value;       // 坐标值
        uint32_t bodyId;   // 所属物体
        bool isMin;        // true=区间起点, false=区间终点
    };

    // 三轴端点数组
    std::vector<Endpoint> endpointsX;
    std::vector<Endpoint> endpointsY;
    std::vector<Endpoint> endpointsZ;

    // 重建端点列表
    void rebuild(const float* minX, const float* maxX,
                 const float* minY, const float* maxY,
                 const float* minZ, const float* maxZ,
                 size_t bodyCount) {
        endpointsX.resize(bodyCount * 2);
        endpointsY.resize(bodyCount * 2);
        endpointsZ.resize(bodyCount * 2);

        for (size_t i = 0; i < bodyCount; ++i) {
            endpointsX[i * 2]     = {minX[i], static_cast<uint32_t>(i), true};
            endpointsX[i * 2 + 1] = {maxX[i], static_cast<uint32_t>(i), false};
            endpointsY[i * 2]     = {minY[i], static_cast<uint32_t>(i), true};
            endpointsY[i * 2 + 1] = {maxY[i], static_cast<uint32_t>(i), false};
            endpointsZ[i * 2]     = {minZ[i], static_cast<uint32_t>(i), true};
            endpointsZ[i * 2 + 1] = {maxZ[i], static_cast<uint32_t>(i), false};
        }

        // 排序——首次构建用std::sort
        // 后续帧用insertion sort（几乎有序，O(n)）
        auto cmp = [](const Endpoint& a, const Endpoint& b) {
            return a.value < b.value ||
                   (a.value == b.value && a.isMin && !b.isMin);
        };
        std::sort(endpointsX.begin(), endpointsX.end(), cmp);
        std::sort(endpointsY.begin(), endpointsY.end(), cmp);
        std::sort(endpointsZ.begin(), endpointsZ.end(), cmp);
    }

    // 增量更新——每帧调用
    // 利用插入排序的O(n)特性处理微小移动
    void incrementalUpdate(const float* minX, const float* maxX,
                           const float* minY, const float* maxY,
                           const float* minZ, const float* maxZ) {
        // 更新端点值
        for (auto& ep : endpointsX) {
            ep.value = ep.isMin ? minX[ep.bodyId] : maxX[ep.bodyId];
        }
        for (auto& ep : endpointsY) {
            ep.value = ep.isMin ? minY[ep.bodyId] : maxY[ep.bodyId];
        }
        for (auto& ep : endpointsZ) {
            ep.value = ep.isMin ? minZ[ep.bodyId] : maxZ[ep.bodyId];
        }

        // 插入排序——对几乎有序的数据是O(n)
        auto insertionSort = [](std::vector<Endpoint>& eps) {
            for (size_t i = 1; i < eps.size(); ++i) {
                Endpoint key = eps[i];
                int j = static_cast<int>(i) - 1;
                while (j >= 0 && eps[j].value > key.value) {
                    eps[j + 1] = eps[j];
                    --j;
                }
                eps[j + 1] = key;
            }
        };

        insertionSort(endpointsX);
        insertionSort(endpointsY);
        insertionSort(endpointsZ);
    }

    // 扫描X轴找到重叠对，然后验证Y和Z轴
    struct CollisionPair { uint32_t a, b; };

    std::vector<CollisionPair> findPairs(
        const float* minY, const float* maxY,
        const float* minZ, const float* maxZ) const {

        std::vector<CollisionPair> pairs;
        std::vector<uint32_t> active;  // 当前活跃物体集合

        for (const auto& ep : endpointsX) {
            if (ep.isMin) {
                // 新物体进入：与所有活跃物体形成候选对
                for (uint32_t other : active) {
                    // 验证Y轴和Z轴重叠
                    if (minY[ep.bodyId] <= maxY[other] &&
                        maxY[ep.bodyId] >= minY[other] &&
                        minZ[ep.bodyId] <= maxZ[other] &&
                        maxZ[ep.bodyId] >= minZ[other]) {
                        uint32_t a = std::min(ep.bodyId, other);
                        uint32_t b = std::max(ep.bodyId, other);
                        pairs.push_back({a, b});
                    }
                }
                active.push_back(ep.bodyId);
            } else {
                // 物体离开：从活跃集合移除
                auto it = std::find(active.begin(), active.end(), ep.bodyId);
                if (it != active.end()) {
                    std::swap(*it, active.back());
                    active.pop_back();
                }
            }
        }

        return pairs;
    }
};

} // namespace physics::spatial
```

---

#### 1.5 空间哈希

```cpp
// ==========================================
// 空间哈希（Spatial Hashing）：无限世界的DOD方案
// ==========================================
//
// 均匀网格的局限：
//   世界大小固定 → 内存 = dimX × dimY × dimZ × sizeof(cell)
//   100×100×100网格 = 1M个单元格
//   1000×1000×1000 = 1G个单元格——不可行！
//
// 空间哈希的解决思路：
//   不预分配所有单元格，而是用哈希表按需创建。
//   hash(cx, cy, cz) → bucket
//   只有实际包含物体的单元格才占内存。
//
// 适用场景：
//   - 开放世界游戏（无限地形）
//   - 稀疏粒子模拟
//   - 物体分布极不均匀的场景
//
// 缺点：
//   - 哈希冲突导致误报
//   - 哈希表查找比直接索引慢
//   - 不如均匀网格缓存友好

#include <vector>
#include <cstdint>
#include <cmath>

namespace physics::spatial {

struct SpatialHash {
    // 哈希表参数
    size_t tableSize;        // 哈希表大小（应为质数）
    float cellSize;
    float invCellSize;

    // 使用与均匀网格相同的 cellStart/cellCount/sortedIds 模式
    // 只是"单元格索引"改为"哈希桶索引"
    std::vector<uint32_t> bucketCount;
    std::vector<uint32_t> bucketStart;
    std::vector<uint32_t> sortedIds;

    // 经典的空间哈希函数（来自Teschner et al. 2003）
    // 使用三个大质数进行异或混合
    static constexpr uint32_t PRIME1 = 73856093u;
    static constexpr uint32_t PRIME2 = 19349663u;
    static constexpr uint32_t PRIME3 = 83492791u;

    uint32_t hashCell(int cx, int cy, int cz) const {
        // 处理负坐标：先转为unsigned
        uint32_t h = (static_cast<uint32_t>(cx) * PRIME1) ^
                     (static_cast<uint32_t>(cy) * PRIME2) ^
                     (static_cast<uint32_t>(cz) * PRIME3);
        return h % static_cast<uint32_t>(tableSize);
    }

    void init(float cellSz, size_t tableSz) {
        cellSize = cellSz;
        invCellSize = 1.0f / cellSz;
        tableSize = tableSz;
        bucketCount.resize(tableSize, 0);
        bucketStart.resize(tableSize, 0);
    }

    // 重建——与均匀网格相同的计数排序
    void rebuild(const float* posX, const float* posY, const float* posZ,
                 size_t objectCount) {
        std::fill(bucketCount.begin(), bucketCount.end(), 0);

        // 第一遍：计数
        for (size_t i = 0; i < objectCount; ++i) {
            int cx = static_cast<int>(std::floor(posX[i] * invCellSize));
            int cy = static_cast<int>(std::floor(posY[i] * invCellSize));
            int cz = static_cast<int>(std::floor(posZ[i] * invCellSize));
            uint32_t bucket = hashCell(cx, cy, cz);
            ++bucketCount[bucket];
        }

        // 前缀和
        uint32_t total = 0;
        for (size_t i = 0; i < tableSize; ++i) {
            bucketStart[i] = total;
            total += bucketCount[i];
        }

        // 第二遍：散布
        sortedIds.resize(objectCount);
        std::vector<uint32_t> writePos = bucketStart;

        for (size_t i = 0; i < objectCount; ++i) {
            int cx = static_cast<int>(std::floor(posX[i] * invCellSize));
            int cy = static_cast<int>(std::floor(posY[i] * invCellSize));
            int cz = static_cast<int>(std::floor(posZ[i] * invCellSize));
            uint32_t bucket = hashCell(cx, cy, cz);
            sortedIds[writePos[bucket]++] = static_cast<uint32_t>(i);
        }
    }

    // 查询邻域——注意哈希冲突可能导致误报
    // 调用者需要用AABB精确测试过滤
    void queryNeighborhood(float x, float y, float z,
                           std::vector<uint32_t>& result) const {
        int cx = static_cast<int>(std::floor(x * invCellSize));
        int cy = static_cast<int>(std::floor(y * invCellSize));
        int cz = static_cast<int>(std::floor(z * invCellSize));

        result.clear();

        for (int dz = -1; dz <= 1; ++dz) {
            for (int dy = -1; dy <= 1; ++dy) {
                for (int dx = -1; dx <= 1; ++dx) {
                    uint32_t bucket = hashCell(cx + dx, cy + dy, cz + dz);
                    uint32_t start = bucketStart[bucket];
                    uint32_t count = bucketCount[bucket];
                    for (uint32_t i = 0; i < count; ++i) {
                        result.push_back(sortedIds[start + i]);
                    }
                }
            }
        }
    }
};

} // namespace physics::spatial
```

---

#### 1.6 空间数据结构性能对比分析

```cpp
// ==========================================
// 空间数据结构性能对比：理论与实测
// ==========================================
//
// 不同空间数据结构的选择取决于场景特征。
// 以下是关键性能指标的理论分析与实测经验。
//
// 场景分类：
//   A. 均匀分布、大小相似（如子弹、粒子）→ 均匀网格/空间哈希
//   B. 不均匀分布、大小差异大（如建筑+人）→ BVH/八叉树
//   C. 大量静态+少量动态（如关卡+角色）→ SAP/静态BVH+动态网格
//   D. 需要射线查询（如射击、视线检测）→ BVH

#include <chrono>
#include <iostream>
#include <random>
#include <vector>

namespace physics::spatial {

struct BenchmarkResult {
    double buildTimeMs;
    double queryTimeMs;
    size_t pairsFound;
    size_t memoryBytes;
};

// 基准测试框架
void benchmarkSpatialStructures() {
    constexpr size_t OBJECT_COUNTS[] = {1000, 5000, 10000, 50000};
    constexpr int QUERY_ITERATIONS = 100;

    std::cout << "Spatial Data Structure Benchmark\n";
    std::cout << "================================\n\n";

    std::cout << "| 物体数 | 均匀网格构建 | 均匀网格查询 | BVH构建 | BVH查询 | 空间哈希构建 | 空间哈希查询 |\n";
    std::cout << "|--------|------------|------------|---------|---------|------------|------------|\n";

    for (size_t count : OBJECT_COUNTS) {
        std::mt19937 rng(42);
        std::uniform_real_distribution<float> posDist(-50, 50);

        std::vector<float> posX(count), posY(count), posZ(count);
        for (size_t i = 0; i < count; ++i) {
            posX[i] = posDist(rng);
            posY[i] = posDist(rng);
            posZ[i] = posDist(rng);
        }

        // 1. 均匀网格基准
        UniformGrid grid;
        grid.init(-50, -50, -50, 50, 50, 50, 2.0f);

        auto t0 = std::chrono::high_resolution_clock::now();
        grid.rebuild(posX.data(), posY.data(), posZ.data(), count);
        auto t1 = std::chrono::high_resolution_clock::now();
        double gridBuild = std::chrono::duration<double, std::milli>(t1 - t0).count();

        std::vector<uint32_t> result;
        t0 = std::chrono::high_resolution_clock::now();
        for (int q = 0; q < QUERY_ITERATIONS; ++q) {
            grid.queryNeighborhood(0, 0, 0, result);
        }
        t1 = std::chrono::high_resolution_clock::now();
        double gridQuery = std::chrono::duration<double, std::milli>(t1 - t0).count() / QUERY_ITERATIONS;

        // 2. 空间哈希基准
        SpatialHash shash;
        shash.init(2.0f, 10007);  // 质数表大小

        t0 = std::chrono::high_resolution_clock::now();
        shash.rebuild(posX.data(), posY.data(), posZ.data(), count);
        t1 = std::chrono::high_resolution_clock::now();
        double hashBuild = std::chrono::duration<double, std::milli>(t1 - t0).count();

        t0 = std::chrono::high_resolution_clock::now();
        for (int q = 0; q < QUERY_ITERATIONS; ++q) {
            shash.queryNeighborhood(0, 0, 0, result);
        }
        t1 = std::chrono::high_resolution_clock::now();
        double hashQuery = std::chrono::duration<double, std::milli>(t1 - t0).count() / QUERY_ITERATIONS;

        std::cout << "| " << count
                  << " | " << gridBuild << "ms"
                  << " | " << gridQuery << "ms"
                  << " | " << "..." << "ms"
                  << " | " << "..." << "ms"
                  << " | " << hashBuild << "ms"
                  << " | " << hashQuery << "ms |\n";
    }
}

} // namespace physics::spatial
```

**空间数据结构选择决策树**
```
你的场景是什么样的？
    │
    ├── 物体大小相似？
    │   ├── 是 → 分布均匀？
    │   │   ├── 是 → ★ 均匀网格（最快、最缓存友好）
    │   │   └── 否 → 稀疏分布？
    │   │       ├── 是 → ★ 空间哈希（自适应内存）
    │   │       └── 否 → ★ 均匀网格（仍然最快）
    │   │
    │   └── 否 → 需要射线查询？
    │       ├── 是 → ★ BVH（最佳射线查询性能）
    │       └── 否 → 物体大多静态？
    │           ├── 是 → ★ SAP（增量更新O(n)）
    │           └── 否 → ★ BVH（自适应分割）
    │
    └── 世界大小已知且有限？
        ├── 是 → ★ 均匀网格 或 八叉树
        └── 否 → ★ 空间哈希（支持无限世界）
```

---

#### 1.7 性能测量工具与缓存分析

```
性能分析工具在空间数据结构开发中的应用
═════════════════════════════════════════

工具1：perf stat 快速概览
────────────────────────
  # 比较均匀网格和BVH的缓存行为
  perf stat -e L1-dcache-loads,L1-dcache-load-misses,\
    LLC-loads,LLC-load-misses \
    ./spatial_benchmark --grid

  perf stat -e L1-dcache-loads,L1-dcache-load-misses,\
    LLC-loads,LLC-load-misses \
    ./spatial_benchmark --bvh

  典型结果（10000物体，查询所有碰撞对）：
    均匀网格：L1 miss rate < 5%
    BVH遍历：L1 miss rate 10-20%（指针追踪）
    OOP网格：L1 miss rate 30-50%（随机堆分配）

工具2：perf record + flamegraph
────────────────────────────────
  # 录制CPU采样
  perf record -g ./physics_engine

  # 生成火焰图
  perf script | stackcollapse-perf.pl | flamegraph.pl > flame.svg

  关注点：
  - rebuild()占总时间的百分比
  - queryNeighborhood()中的缓存未命中热点
  - 内存分配函数（malloc/operator new）的占比

工具3：cachegrind逐行分析
──────────────────────────
  valgrind --tool=cachegrind ./spatial_benchmark

  cg_annotate cachegrind.out.* --auto=yes

  重点查看：
  - cellCount[cell]++ 的写miss（随机写模式）
  - sortedIds遍历的读miss（应该很低）
  - BVH节点访问的miss（衡量树结构的缓存友好性）
```

---

#### 1.8 本周练习任务

```
练习1：均匀网格碰撞对查找
─────────────────────────
目标：基于1.1节的UniformGrid，实现完整的宽相位碰撞对查找

要求：
1. 实现findAllPairs()函数，遍历每个非空单元格及其邻居
2. 对同一单元格和相邻单元格中的物体对进行AABB测试
3. 确保每对只输出一次（a < b排序）
4. 与暴力N²算法对比结果正确性

验证：
- 1000个随机物体时，网格方法应比N²快10倍以上
- 输出碰撞对集合应与N²完全一致（零误差）

练习2：Morton码可视化
────────────────────
目标：实现Morton码编解码，并可视化其空间局部性保持特性

要求：
1. 实现encode和decode函数（支持2D和3D）
2. 生成16×16网格中所有点的Morton码
3. 按Morton码顺序输出坐标，观察Z形遍历路径
4. 统计Morton码排序 vs 行优先排序 vs 随机顺序的缓存miss率

验证：
- Morton码遍历应比行优先遍历miss率低20-40%
- 可用cachegrind验证

练习3：BVH vs 均匀网格性能对比
──────────────────────────────
目标：在不同物体分布下比较两种空间结构的性能

要求：
1. 实现三种物体分布：均匀随机、聚簇（几个密集群）、线性（沿一条线）
2. 对每种分布，分别用均匀网格和BVH执行1000次邻域查询
3. 记录构建时间、查询时间、内存占用
4. 绘制对比图表

验证：
- 均匀分布：均匀网格应更快
- 聚簇分布：BVH应在查询阶段更快（更少的无效遍历）
- 内存：均匀网格=O(cells+n)，BVH=O(n)

练习4：空间哈希冲突分析
─────────────────────
目标：分析不同哈希表大小和哈希函数对碰撞率的影响

要求：
1. 实现至少2种不同的空间哈希函数
2. 在固定10000个物体的场景下，测试表大小从100到100000
3. 统计：平均桶大小、最大桶大小、空桶比例、哈希冲突率
4. 找到"物体数/表大小"的最佳比值

验证：
- 负载因子（物体数/表大小）在0.5-1.0时性能最佳
- 质数表大小应比2的幂表大小有更低的冲突率
```

---

#### 1.9 本周知识检验

```
思考题1：均匀网格的cellSize如何选择？如果cellSize太小（远小于物体大小），
         会有什么问题？如果太大呢？cellSize与平均物体大小的最佳比值是多少？

思考题2：BVH使用SAH（Surface Area Heuristic）分割时，分割代价公式为：
         Cost = C_traversal + P_left * N_left * C_intersect + P_right * N_right * C_intersect
         其中P是子节点被射线命中的概率。为什么P与表面积成正比？
         （提示：考虑随机射线与凸包相交的概率）

思考题3：SAP（Sweep and Prune）在2D游戏中极为高效，但在3D中性能下降。
         解释为什么维度增加会降低SAP的"裁剪"效果。
         在什么情况下3D SAP仍然是好选择？

思考题4：Morton码虽然保持空间局部性，但有一个著名的缺陷：
         在某些方向上局部性特别差（例如沿Y轴相邻的两个点Morton码可能差很远）。
         Hilbert曲线如何解决这个问题？为什么实践中仍然多用Morton码而非Hilbert？

思考题5：游戏引擎通常同时使用多种空间结构——比如一个均匀网格用于动态物体，
         一个静态BVH用于场景几何。如何高效处理"动态vs静态"的跨结构碰撞查询？

实践题1：
  给定1000个半径为0.5的球体，均匀分布在[-50,50]³空间中。
  设计均匀网格参数（cellSize, dimX/Y/Z），使得：
  (a) 平均每个单元格包含的球体数量为2-4个
  (b) 计算总单元格数和内存占用
  (c) 如果球体半径变为5.0，需要如何调整cellSize？

实践题2：
  手工推导：对于N个均匀分布的物体和M个网格单元格，
  (a) 平均每个单元格有N/M个物体
  (b) 暴力N²的碰撞检测次数 = N(N-1)/2
  (c) 网格方法的检测次数 ≈ 27 × M × (N/M)² / 2 = 27N²/(2M)
  (d) 加速比 = M/27。当M = N时，加速比 = N/27
  验证这个推导，并解释为什么实际加速比通常比理论值更高。
```

### 第二周：碰撞检测系统（35小时）

**学习目标**：
- [ ] 深入理解碰撞检测的三阶段流水线：宽相位、窄相位、碰撞响应的各自职责与性能特征
- [ ] 掌握AABB碰撞检测的SIMD批量化实现，理解数据收集（gather）与掩码提取的技巧
- [ ] 理解SAT（Separating Axis Theorem）的数学证明与实现，掌握OBB碰撞检测
- [ ] 学会GJK（Gilbert-Johnson-Keerthi）算法的几何直觉：Minkowski差、单纯形、支撑函数
- [ ] 掌握EPA（Expanding Polytope Algorithm）从GJK结果中提取穿透深度和碰撞法线
- [ ] 实现多种碰撞器组合：球-球、球-胶囊、球-盒、盒-盒的DOD批量化检测
- [ ] 理解接触流形（Contact Manifold）的生成与缓存策略，掌握warm starting技术

**阅读材料**：
- [ ] 《Real-Time Collision Detection》- Christer Ericson（Chapter 4-5: GJK & SAT）
- [ ] 《Game Programming Gems 6》- 碰撞检测章节
- [ ] GJK算法可视化教程 - Casey Muratori's GJK Video Series
- [ ] 《Physics for Game Developers》- David Bourg（Chapter 9: Contact Detection）
- [ ] PhysX 5.0 碰撞检测架构文档
- [ ] Box2D Lite源码 - Arbiter/Contact生成
- [ ] Erin Catto GDC演讲：《Contact Manifolds》(2007)

---

#### 核心概念

**碰撞检测三阶段流水线**
```
┌─────────────────────────────────────────────────────────────┐
│                    碰撞检测完整流水线                          │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│              宽相位 (Broad Phase)                             │
│  - 快速剔除不可能碰撞的对象对                                │
│  - 使用空间数据结构（网格/BVH/SAP）                          │
│  - 输出：潜在碰撞对列表                                      │
│  - 复杂度：O(n log n) 或 O(n)                                │
│  - 性能占比：~10-20%                                         │
│  - DOD关键：SoA布局的AABB、SIMD批量测试                      │
└─────────────────────────────────────────────────────────────┘
                          │ 过滤率通常95-99%
                          ▼
┌─────────────────────────────────────────────────────────────┐
│              窄相位 (Narrow Phase)                            │
│  - 精确检测实际碰撞                                          │
│  - 计算碰撞点、法线、穿透深度                                │
│  - 使用GJK、SAT等算法                                        │
│  - 输出：ContactManifold（接触流形）                          │
│  - 复杂度：O(k) where k = 潜在碰撞对数量                     │
│  - 性能占比：~30-50%                                         │
│  - DOD关键：按碰撞器类型分批处理、批量GJK                    │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│              碰撞响应 (Collision Response)                    │
│  - 顺序冲量（Sequential Impulse）求解                        │
│  - 迭代约束求解                                              │
│  - 位置修正（Baumgarte stabilization / NGS）                 │
│  - 性能占比：~30-50%                                         │
│  - DOD关键：约束数据SoA化、warm starting缓存                 │
└─────────────────────────────────────────────────────────────┘
```

**碰撞器类型与算法对应关系**

| 碰撞器对 | 推荐算法 | 复杂度 | DOD批量化 |
|---------|---------|-------|----------|
| 球-球 | 距离公式 | O(1) | 极好（纯SIMD） |
| 球-胶囊 | 点到线段距离 | O(1) | 好 |
| 球-平面 | 点到平面距离 | O(1) | 极好 |
| 球-盒(AABB) | Voronoi区域 | O(1) | 好 |
| 盒-盒(AABB) | 分离轴（6轴） | O(1) | 极好（SIMD） |
| 盒-盒(OBB) | SAT（15轴） | O(1) | 中等 |
| 凸体-凸体 | GJK+EPA | O(v) | 困难（迭代） |
| 凸体-凸体 | SAT | O(f·v) | 中等 |

---

#### 2.1 AABB碰撞检测与SIMD批量化

```cpp
// ==========================================
// AABB碰撞检测：从标量到SIMD的演进
// ==========================================
//
// AABB（Axis-Aligned Bounding Box）是碰撞检测的基石。
// 几乎所有宽相位算法都使用AABB作为第一层过滤。
//
// 标量AABB测试只需6次比较：
//   overlap = (a.min.x <= b.max.x) && (a.max.x >= b.min.x) &&
//             (a.min.y <= b.max.y) && (a.max.y >= b.min.y) &&
//             (a.min.z <= b.max.z) && (a.max.z >= b.min.z)
//
// 但当需要测试一个AABB与数千个候选时，SIMD可以一次测试8个（AVX）。
// 这是DOD+SoA的完美应用场景。
//
// 关键洞察（Mike Acton, Insomniac Games）：
//   "If you're testing collision one pair at a time, you're leaving
//    87.5% of your SIMD lanes idle."

#include <immintrin.h>
#include <vector>
#include <cstdint>

namespace physics::collision {

// AABB系统——SoA布局，为SIMD优化
struct AABBSystem {
    // Min/Max分开存储——这是SIMD友好的关键
    // 传统AoS：struct { Vec3 min, max; } → 24字节/AABB
    // SoA：6个float数组 → 每个数组连续，完美SIMD加载
    std::vector<float> minX, minY, minZ;
    std::vector<float> maxX, maxY, maxZ;

    size_t count() const { return minX.size(); }

    void resize(size_t n) {
        minX.resize(n); minY.resize(n); minZ.resize(n);
        maxX.resize(n); maxY.resize(n); maxZ.resize(n);
    }

    // ──────────────────────────────────────
    // 标量版本——用于参考和验证
    // ──────────────────────────────────────
    bool testOverlap(uint32_t a, uint32_t b) const {
        return minX[a] <= maxX[b] && maxX[a] >= minX[b] &&
               minY[a] <= maxY[b] && maxY[a] >= minY[b] &&
               minZ[a] <= maxZ[b] && maxZ[a] >= minZ[b];
    }

#ifdef __AVX__
    // ──────────────────────────────────────
    // AVX批量版本——一次测试8个AABB
    // ──────────────────────────────────────
    //
    // 策略：将查询AABB广播到8个SIMD通道，
    //       候选AABB从SoA数组连续加载（完美缓存利用）。
    //
    // 数据流：
    //   queryAABB → broadcast → 8 lanes
    //   candidates[0..7] → gather → 8 lanes
    //   → 6次SIMD比较 + 3次AND → 1次movemask → 位掩码
    //
    // 吞吐量：每次迭代测试8对，约6ns/8对 ≈ 0.75ns/对
    // 对比标量：约3ns/对 → 4倍加速

    void testOneVsMany(
        uint32_t queryIdx,
        const uint32_t* candidateIndices,
        size_t candidateCount,
        std::vector<std::pair<uint32_t, uint32_t>>& pairs) const
    {
        // 广播查询AABB到所有通道
        __m256 qMinX = _mm256_set1_ps(minX[queryIdx]);
        __m256 qMinY = _mm256_set1_ps(minY[queryIdx]);
        __m256 qMinZ = _mm256_set1_ps(minZ[queryIdx]);
        __m256 qMaxX = _mm256_set1_ps(maxX[queryIdx]);
        __m256 qMaxY = _mm256_set1_ps(maxY[queryIdx]);
        __m256 qMaxZ = _mm256_set1_ps(maxZ[queryIdx]);

        size_t i = 0;
        for (; i + 8 <= candidateCount; i += 8) {
            // 收集8个候选AABB（gather操作）
            // 注意：如果候选索引是连续的，可以直接load
            // 如果是间接索引，需要手动gather
            alignas(32) float cMinX[8], cMinY[8], cMinZ[8];
            alignas(32) float cMaxX[8], cMaxY[8], cMaxZ[8];

            for (int j = 0; j < 8; ++j) {
                uint32_t idx = candidateIndices[i + j];
                cMinX[j] = minX[idx]; cMinY[j] = minY[idx]; cMinZ[j] = minZ[idx];
                cMaxX[j] = maxX[idx]; cMaxY[j] = maxY[idx]; cMaxZ[j] = maxZ[idx];
            }

            __m256 candMinX = _mm256_load_ps(cMinX);
            __m256 candMinY = _mm256_load_ps(cMinY);
            __m256 candMinZ = _mm256_load_ps(cMinZ);
            __m256 candMaxX = _mm256_load_ps(cMaxX);
            __m256 candMaxY = _mm256_load_ps(cMaxY);
            __m256 candMaxZ = _mm256_load_ps(cMaxZ);

            // AABB重叠测试：6次比较 + 3次AND
            __m256 overlapX = _mm256_and_ps(
                _mm256_cmp_ps(qMinX, candMaxX, _CMP_LE_OQ),
                _mm256_cmp_ps(candMinX, qMaxX, _CMP_LE_OQ));
            __m256 overlapY = _mm256_and_ps(
                _mm256_cmp_ps(qMinY, candMaxY, _CMP_LE_OQ),
                _mm256_cmp_ps(candMinY, qMaxY, _CMP_LE_OQ));
            __m256 overlapZ = _mm256_and_ps(
                _mm256_cmp_ps(qMinZ, candMaxZ, _CMP_LE_OQ),
                _mm256_cmp_ps(candMinZ, qMaxZ, _CMP_LE_OQ));

            __m256 overlap = _mm256_and_ps(
                _mm256_and_ps(overlapX, overlapY), overlapZ);

            // 提取碰撞掩码——每位对应一个候选
            int mask = _mm256_movemask_ps(overlap);

            // 输出碰撞对（位扫描）
            while (mask) {
                int bit = __builtin_ctz(mask);
                pairs.emplace_back(queryIdx, candidateIndices[i + bit]);
                mask &= mask - 1;  // 清除最低位
            }
        }

        // 标量处理剩余
        for (; i < candidateCount; ++i) {
            uint32_t idx = candidateIndices[i];
            if (testOverlap(queryIdx, idx)) {
                pairs.emplace_back(queryIdx, idx);
            }
        }
    }
#endif
};

} // namespace physics::collision
```

---

#### 2.2 SAT分离轴定理

```cpp
// ==========================================
// SAT（Separating Axis Theorem）：凸多面体碰撞检测
// ==========================================
//
// SAT定理：
//   两个凸体不碰撞 ⟺ 存在一条轴（分离轴），
//   使得两个凸体在该轴上的投影区间不重叠。
//
// 对于两个3D OBB（有向包围盒），需要测试15条轴：
//   - A的3条局部轴
//   - B的3条局部轴
//   - 9条交叉轴（A的每条轴 × B的每条轴）
//
// SAT的优势：
//   1. 如果不碰撞，可以早退出（找到任一分离轴即可）
//   2. 碰撞时自然给出最小穿透轴和深度
//   3. 计算过程全是点积——SIMD友好
//
// SAT vs GJK：
//   SAT：适合顶点数固定的形状（盒、三角形）
//   GJK：适合任意凸体（通用但迭代）
//
// 关键参考：
//   Christer Ericson《Real-Time Collision Detection》Chapter 4

#include <cmath>
#include <algorithm>
#include <array>

namespace physics::collision {

struct Vec3 {
    float x, y, z;
    float dot(const Vec3& v) const { return x*v.x + y*v.y + z*v.z; }
    Vec3 cross(const Vec3& v) const {
        return {y*v.z - z*v.y, z*v.x - x*v.z, x*v.y - y*v.x};
    }
    float lengthSq() const { return dot(*this); }
    Vec3 operator-(const Vec3& v) const { return {x-v.x, y-v.y, z-v.z}; }
    Vec3 operator+(const Vec3& v) const { return {x+v.x, y+v.y, z+v.z}; }
    Vec3 operator*(float s) const { return {x*s, y*s, z*s}; }
};

// OBB（Oriented Bounding Box）
struct OBB {
    Vec3 center;            // 中心点
    Vec3 halfExtents;       // 半尺寸（沿局部轴）
    std::array<Vec3, 3> axes;  // 局部坐标系（3个正交单位向量）
};

// SAT碰撞结果
struct SATResult {
    bool colliding;
    Vec3 normal;           // 最小穿透法线（从A到B）
    float penetration;     // 最小穿透深度
};

// ──────────────────────────────────────
// OBB vs OBB的SAT检测
// ──────────────────────────────────────
//
// 15轴测试的优化技巧：
//   1. 先测试6条主轴（最可能是分离轴）
//   2. 如果主轴都重叠，再测试9条交叉轴
//   3. 使用"绝对值矩阵"避免重复计算
//
// 这个实现基于Gottschalk的OBB-OBB测试，
// 是实时应用中最广泛使用的OBB测试。

SATResult testOBBvsOBB(const OBB& a, const OBB& b) {
    SATResult result{false, {0,0,0}, std::numeric_limits<float>::max()};

    // 旋转矩阵：B的轴在A的局部空间中的表示
    float R[3][3], absR[3][3];
    for (int i = 0; i < 3; ++i) {
        for (int j = 0; j < 3; ++j) {
            R[i][j] = a.axes[i].dot(b.axes[j]);
            // 加epsilon处理平行边的退化情况
            absR[i][j] = std::abs(R[i][j]) + 1e-6f;
        }
    }

    // 从A到B的向量（A的局部空间）
    Vec3 d = b.center - a.center;
    Vec3 t = {d.dot(a.axes[0]), d.dot(a.axes[1]), d.dot(a.axes[2])};

    float ra, rb, penetration;
    Vec3 bestAxis = {0,0,0};
    float minPenetration = std::numeric_limits<float>::max();

    auto testAxis = [&](float ra_, float rb_, float dist, Vec3 axis) -> bool {
        float pen = ra_ + rb_ - std::abs(dist);
        if (pen < 0) return false;  // 找到分离轴，不碰撞
        if (pen < minPenetration) {
            minPenetration = pen;
            bestAxis = axis;
            if (dist < 0) bestAxis = bestAxis * (-1.0f);
        }
        return true;
    };

    // 测试A的3条轴
    for (int i = 0; i < 3; ++i) {
        ra = (&a.halfExtents.x)[i];
        rb = b.halfExtents.x * absR[i][0] +
             b.halfExtents.y * absR[i][1] +
             b.halfExtents.z * absR[i][2];
        if (!testAxis(ra, rb, (&t.x)[i], a.axes[i])) return result;
    }

    // 测试B的3条轴
    for (int j = 0; j < 3; ++j) {
        ra = a.halfExtents.x * absR[0][j] +
             a.halfExtents.y * absR[1][j] +
             a.halfExtents.z * absR[2][j];
        rb = (&b.halfExtents.x)[j];
        float dist = t.x * R[0][j] + t.y * R[1][j] + t.z * R[2][j];
        if (!testAxis(ra, rb, dist, b.axes[j])) return result;
    }

    // 测试9条交叉轴（A的轴i × B的轴j）
    // 这些轴可能是退化的（两轴平行时交叉积为零）
    // absR中加的epsilon处理了这种情况

    // A0 × B0
    ra = a.halfExtents.y * absR[2][0] + a.halfExtents.z * absR[1][0];
    rb = b.halfExtents.y * absR[0][2] + b.halfExtents.z * absR[0][1];
    {
        float dist = t.z * R[1][0] - t.y * R[2][0];
        Vec3 axis = a.axes[0].cross(b.axes[0]);
        if (axis.lengthSq() > 1e-6f) {
            if (!testAxis(ra, rb, dist, axis)) return result;
        }
    }

    // A0 × B1
    ra = a.halfExtents.y * absR[2][1] + a.halfExtents.z * absR[1][1];
    rb = b.halfExtents.x * absR[0][2] + b.halfExtents.z * absR[0][0];
    {
        float dist = t.z * R[1][1] - t.y * R[2][1];
        Vec3 axis = a.axes[0].cross(b.axes[1]);
        if (axis.lengthSq() > 1e-6f) {
            if (!testAxis(ra, rb, dist, axis)) return result;
        }
    }

    // A0 × B2
    ra = a.halfExtents.y * absR[2][2] + a.halfExtents.z * absR[1][2];
    rb = b.halfExtents.x * absR[0][1] + b.halfExtents.y * absR[0][0];
    {
        float dist = t.z * R[1][2] - t.y * R[2][2];
        Vec3 axis = a.axes[0].cross(b.axes[2]);
        if (axis.lengthSq() > 1e-6f) {
            if (!testAxis(ra, rb, dist, axis)) return result;
        }
    }

    // 省略A1×B0..2和A2×B0..2（结构完全相同）
    // 实际实现中应完整写出全部9条交叉轴

    // 所有15条轴都没有分离 → 碰撞
    result.colliding = true;
    result.normal = bestAxis;
    result.penetration = minPenetration;
    return result;
}

} // namespace physics::collision
```

---

#### 2.3 GJK算法详解

```cpp
// ==========================================
// GJK（Gilbert-Johnson-Keerthi）：通用凸体碰撞检测
// ==========================================
//
// GJK是碰撞检测领域最优雅的算法之一。
// 核心思想：
//   两个凸体A和B碰撞 ⟺ 它们的Minkowski差包含原点。
//
// Minkowski差的定义：
//   A ⊖ B = { a - b | a ∈ A, b ∈ B }
//   这是一个新的凸体。如果原点在其内部，则A和B重叠。
//
// GJK的巧妙之处：
//   不需要显式构建Minkowski差（那需要V_A × V_B 个顶点）。
//   而是通过"支撑函数"（Support Function）隐式探索它。
//
// 支撑函数：
//   Support(A⊖B, direction) = Support(A, d) - Support(B, -d)
//   其中 Support(Shape, d) = shape中沿d方向最远的点
//
// GJK迭代地构建一个包含原点的单纯形（simplex）：
//   1D：线段，2D：三角形，3D：四面体
//   每次迭代添加一个新的支撑点，检查原点是否被包含。
//
// 关键洞察（Casey Muratori's GJK Video）：
//   "GJK is really just a search algorithm. It searches for
//    the closest point on the Minkowski difference to the origin."

#include <vector>
#include <cmath>
#include <array>
#include <algorithm>

namespace physics::collision {

// 支撑函数——对不同碰撞器类型的实现
// DOD设计：支撑函数是纯函数，无状态，可批量调用

// 球体支撑函数
Vec3 supportSphere(const Vec3& center, float radius, const Vec3& dir) {
    float len = std::sqrt(dir.dot(dir));
    if (len < 1e-8f) return center;
    return center + dir * (radius / len);
}

// 盒体支撑函数
Vec3 supportBox(const Vec3& center, const Vec3& halfExtents,
                const std::array<Vec3, 3>& axes, const Vec3& dir) {
    return {
        center.x + (dir.dot(axes[0]) >= 0 ? halfExtents.x : -halfExtents.x) * axes[0].x
                  + (dir.dot(axes[1]) >= 0 ? halfExtents.y : -halfExtents.y) * axes[1].x
                  + (dir.dot(axes[2]) >= 0 ? halfExtents.z : -halfExtents.z) * axes[2].x,
        center.y + (dir.dot(axes[0]) >= 0 ? halfExtents.x : -halfExtents.x) * axes[0].y
                  + (dir.dot(axes[1]) >= 0 ? halfExtents.y : -halfExtents.y) * axes[1].y
                  + (dir.dot(axes[2]) >= 0 ? halfExtents.z : -halfExtents.z) * axes[2].y,
        center.z + (dir.dot(axes[0]) >= 0 ? halfExtents.x : -halfExtents.x) * axes[0].z
                  + (dir.dot(axes[1]) >= 0 ? halfExtents.y : -halfExtents.y) * axes[1].z
                  + (dir.dot(axes[2]) >= 0 ? halfExtents.z : -halfExtents.z) * axes[2].z
    };
}

// GJK单纯形
struct Simplex {
    std::array<Vec3, 4> points;
    int count = 0;

    void push(const Vec3& p) {
        // 新点总是放在最前面
        for (int i = count; i > 0; --i) {
            points[i] = points[i - 1];
        }
        points[0] = p;
        ++count;
    }
};

// GJK主函数
// 返回true如果两个凸体碰撞
// direction参数在碰撞时设为穿透方向的近似（给EPA用）
bool gjkIntersection(
    // 支撑函数A和B（通过lambda传入，支持任意碰撞器类型）
    auto supportA,  // Vec3 supportA(Vec3 direction)
    auto supportB,  // Vec3 supportB(Vec3 direction)
    Simplex& simplex,
    Vec3& direction)
{
    // Minkowski差的支撑函数
    auto support = [&](const Vec3& dir) -> Vec3 {
        Vec3 a = supportA(dir);
        Vec3 b = supportB(dir * (-1.0f));
        return a - b;
    };

    // 初始方向（可以是任意非零向量）
    direction = {1, 0, 0};
    Vec3 a = support(direction);
    simplex.count = 0;
    simplex.push(a);

    direction = a * (-1.0f);  // 指向原点

    constexpr int MAX_ITERATIONS = 32;
    for (int iter = 0; iter < MAX_ITERATIONS; ++iter) {
        a = support(direction);

        // 如果新点没有越过原点，不碰撞
        if (a.dot(direction) < 0) {
            return false;
        }

        simplex.push(a);

        // 更新单纯形和搜索方向
        if (doSimplex(simplex, direction)) {
            return true;  // 单纯形包含原点
        }
    }

    return false;  // 超过最大迭代次数，假定不碰撞
}

// 单纯形更新——GJK的核心逻辑
// 根据当前单纯形的类型（线、三角形、四面体），
// 确定最近的特征（点、边、面），并更新搜索方向
bool doSimplex(Simplex& s, Vec3& dir) {
    switch (s.count) {
        case 2: return doSimplexLine(s, dir);
        case 3: return doSimplexTriangle(s, dir);
        case 4: return doSimplexTetrahedron(s, dir);
    }
    return false;
}

// 线段情况
bool doSimplexLine(Simplex& s, Vec3& dir) {
    Vec3 a = s.points[0];  // 最新添加的点
    Vec3 b = s.points[1];
    Vec3 ab = b - a;
    Vec3 ao = a * (-1.0f);  // 从a到原点的向量

    if (ab.dot(ao) > 0) {
        // 原点在ab方向侧——保持线段，方向垂直于ab指向原点
        dir = ab.cross(ao).cross(ab);
    } else {
        // 原点在a的另一侧——退化为点
        s.count = 1;
        dir = ao;
    }
    return false;
}

// 三角形情况
bool doSimplexTriangle(Simplex& s, Vec3& dir) {
    Vec3 a = s.points[0];
    Vec3 b = s.points[1];
    Vec3 c = s.points[2];
    Vec3 ab = b - a, ac = c - a;
    Vec3 ao = a * (-1.0f);
    Vec3 abc = ab.cross(ac);  // 三角形法线

    // 检查原点在三角形的哪一侧/哪条边外
    if (abc.cross(ac).dot(ao) > 0) {
        if (ac.dot(ao) > 0) {
            s.points[0] = a; s.points[1] = c; s.count = 2;
            dir = ac.cross(ao).cross(ac);
        } else {
            s.points[0] = a; s.points[1] = b; s.count = 2;
            return doSimplexLine(s, dir);
        }
    } else if (ab.cross(abc).dot(ao) > 0) {
        s.points[0] = a; s.points[1] = b; s.count = 2;
        return doSimplexLine(s, dir);
    } else {
        // 原点在三角形"上方"或"下方"
        if (abc.dot(ao) > 0) {
            dir = abc;
        } else {
            // 翻转三角形方向
            std::swap(s.points[1], s.points[2]);
            dir = abc * (-1.0f);
        }
    }
    return false;
}

// 四面体情况
bool doSimplexTetrahedron(Simplex& s, Vec3& dir) {
    Vec3 a = s.points[0];
    Vec3 b = s.points[1];
    Vec3 c = s.points[2];
    Vec3 d = s.points[3];

    Vec3 ab = b - a, ac = c - a, ad = d - a;
    Vec3 ao = a * (-1.0f);

    Vec3 abc = ab.cross(ac);
    Vec3 acd = ac.cross(ad);
    Vec3 adb = ad.cross(ab);

    // 检查原点在四面体的哪个面外
    if (abc.dot(ao) > 0) {
        s.points[0] = a; s.points[1] = b; s.points[2] = c; s.count = 3;
        return doSimplexTriangle(s, dir);
    }
    if (acd.dot(ao) > 0) {
        s.points[0] = a; s.points[1] = c; s.points[2] = d; s.count = 3;
        return doSimplexTriangle(s, dir);
    }
    if (adb.dot(ao) > 0) {
        s.points[0] = a; s.points[1] = d; s.points[2] = b; s.count = 3;
        return doSimplexTriangle(s, dir);
    }

    // 原点在四面体内部——碰撞确认！
    return true;
}

} // namespace physics::collision
```

---

#### 2.4 EPA算法——穿透深度提取

```cpp
// ==========================================
// EPA（Expanding Polytope Algorithm）
// ==========================================
//
// GJK告诉我们"是否碰撞"，但不给出穿透深度和法线。
// EPA从GJK最后的单纯形出发，向外扩展多面体，
// 直到找到距离原点最近的面——该面的法线就是穿透方向，
// 距离就是穿透深度。
//
// 算法流程：
//   1. 从GJK的四面体（单纯形）开始
//   2. 找到距离原点最近的三角面
//   3. 沿该面法线方向计算新的支撑点
//   4. 如果新点没有显著超过该面 → 收敛，返回结果
//   5. 否则，移除被新点"看到"的面，用新点重新三角化
//   6. 重复2-5

#include <vector>
#include <limits>

namespace physics::collision {

struct EPAResult {
    Vec3 normal;       // 穿透法线（从A到B）
    float penetration; // 穿透深度
    bool valid;        // EPA是否收敛
};

struct EPATriangle {
    uint32_t a, b, c;  // 顶点索引
    Vec3 normal;
    float distance;     // 到原点的距离
};

EPAResult epa(auto supportA, auto supportB,
              const Simplex& gjkSimplex) {
    EPAResult result{{0,1,0}, 0, false};

    auto support = [&](const Vec3& dir) -> Vec3 {
        return supportA(dir) - supportB(dir * (-1.0f));
    };

    // 初始化多面体——从GJK的四面体开始
    std::vector<Vec3> vertices;
    for (int i = 0; i < gjkSimplex.count; ++i) {
        vertices.push_back(gjkSimplex.points[i]);
    }

    // 初始4个三角面（四面体的4个面）
    std::vector<EPATriangle> faces;

    auto makeFace = [&](uint32_t a, uint32_t b, uint32_t c) -> EPATriangle {
        Vec3 ab = vertices[b] - vertices[a];
        Vec3 ac = vertices[c] - vertices[a];
        Vec3 n = ab.cross(ac);
        float len = std::sqrt(n.lengthSq());
        if (len > 1e-8f) n = n * (1.0f / len);

        // 确保法线指向远离原点的方向
        if (n.dot(vertices[a]) < 0) {
            n = n * (-1.0f);
            return {a, c, b, n, std::abs(n.dot(vertices[a]))};
        }
        return {a, b, c, n, std::abs(n.dot(vertices[a]))};
    };

    faces.push_back(makeFace(0, 1, 2));
    faces.push_back(makeFace(0, 2, 3));
    faces.push_back(makeFace(0, 3, 1));
    faces.push_back(makeFace(1, 3, 2));

    constexpr int MAX_ITERATIONS = 64;
    constexpr float EPSILON = 1e-4f;

    for (int iter = 0; iter < MAX_ITERATIONS; ++iter) {
        // 找到距离原点最近的面
        int closestIdx = 0;
        float closestDist = faces[0].distance;
        for (size_t i = 1; i < faces.size(); ++i) {
            if (faces[i].distance < closestDist) {
                closestDist = faces[i].distance;
                closestIdx = static_cast<int>(i);
            }
        }

        const EPATriangle& closest = faces[closestIdx];

        // 沿最近面的法线方向找新的支撑点
        Vec3 newPoint = support(closest.normal);
        float newDist = closest.normal.dot(newPoint);

        // 收敛检查
        if (newDist - closestDist < EPSILON) {
            result.normal = closest.normal;
            result.penetration = closestDist;
            result.valid = true;
            return result;
        }

        // 添加新顶点
        uint32_t newIdx = static_cast<uint32_t>(vertices.size());
        vertices.push_back(newPoint);

        // 移除被新点"看到"的面，收集边界边
        std::vector<std::pair<uint32_t, uint32_t>> edges;
        for (int i = static_cast<int>(faces.size()) - 1; i >= 0; --i) {
            Vec3 toNew = newPoint - vertices[faces[i].a];
            if (faces[i].normal.dot(toNew) > 0) {
                // 这个面被新点看到——收集它的边
                auto addEdge = [&](uint32_t a, uint32_t b) {
                    // 如果反向边已存在，两者都移除（共享边）
                    for (auto it = edges.begin(); it != edges.end(); ++it) {
                        if (it->first == b && it->second == a) {
                            edges.erase(it);
                            return;
                        }
                    }
                    edges.push_back({a, b});
                };
                addEdge(faces[i].a, faces[i].b);
                addEdge(faces[i].b, faces[i].c);
                addEdge(faces[i].c, faces[i].a);

                faces.erase(faces.begin() + i);
            }
        }

        // 用边界边和新点创建新面
        for (const auto& [ea, eb] : edges) {
            faces.push_back(makeFace(ea, eb, newIdx));
        }
    }

    // 未收敛——返回最近面作为近似
    if (!faces.empty()) {
        int closestIdx = 0;
        for (size_t i = 1; i < faces.size(); ++i) {
            if (faces[i].distance < faces[closestIdx].distance) {
                closestIdx = static_cast<int>(i);
            }
        }
        result.normal = faces[closestIdx].normal;
        result.penetration = faces[closestIdx].distance;
        result.valid = true;
    }

    return result;
}

} // namespace physics::collision
```

---

#### 2.5 多碰撞器类型的DOD批量检测

```cpp
// ==========================================
// 碰撞器类型派发——DOD的批量处理策略
// ==========================================
//
// 传统OOP方式：虚函数双重派发
//   colliderA->collideWith(colliderB)
//   → 虚函数调用 → if/switch类型判断 → 另一个虚函数调用
//   每次碰撞检测2次虚函数调用 + 分支
//
// DOD方式：按碰撞器类型对排序，同类型批量处理
//   1. 将碰撞对按(typeA, typeB)分组
//   2. 每组使用专门的检测函数（无虚函数、无分支）
//   3. 同组内的数据可以SIMD批量处理
//
// 效果：
//   - 消除虚函数开销
//   - 消除类型判断分支
//   - 同类型碰撞器数据连续 → 缓存友好
//   - SIMD批量化（球-球可以完全SIMD化）

#include <vector>
#include <cstdint>
#include <cmath>

namespace physics::collision {

// 碰撞器类型枚举
enum class ColliderType : uint8_t {
    Sphere = 0,
    Capsule = 1,
    Box = 2,
    COUNT = 3
};

// 接触点
struct ContactPoint {
    float posX, posY, posZ;     // 接触点世界坐标
    float normalX, normalY, normalZ;  // 法线（A→B）
    float penetration;           // 穿透深度
    uint32_t bodyA, bodyB;
};

// ──────────────────────────────────────
// 球-球碰撞——最简单，完全SIMD友好
// ──────────────────────────────────────
void detectSphereSphere(
    const float* posAX, const float* posAY, const float* posAZ,
    const float* radiusA,
    const float* posBX, const float* posBY, const float* posBZ,
    const float* radiusB,
    const uint32_t* bodyA, const uint32_t* bodyB,
    size_t pairCount,
    std::vector<ContactPoint>& contacts)
{
    for (size_t i = 0; i < pairCount; ++i) {
        float dx = posBX[i] - posAX[i];
        float dy = posBY[i] - posAY[i];
        float dz = posBZ[i] - posAZ[i];

        float distSq = dx*dx + dy*dy + dz*dz;
        float radiusSum = radiusA[i] + radiusB[i];

        if (distSq < radiusSum * radiusSum) {
            float dist = std::sqrt(distSq);
            float invDist = (dist > 1e-6f) ? 1.0f / dist : 0.0f;

            float nx = dx * invDist;
            float ny = dy * invDist;
            float nz = dz * invDist;

            // 默认法线（球心重合时）
            if (dist < 1e-6f) { nx = 0; ny = 1; nz = 0; }

            contacts.push_back({
                posAX[i] + nx * (radiusA[i] - (radiusSum - dist) * 0.5f),
                posAY[i] + ny * (radiusA[i] - (radiusSum - dist) * 0.5f),
                posAZ[i] + nz * (radiusA[i] - (radiusSum - dist) * 0.5f),
                nx, ny, nz,
                radiusSum - dist,
                bodyA[i], bodyB[i]
            });
        }
    }
}

// ──────────────────────────────────────
// 球-胶囊碰撞
// ──────────────────────────────────────
//
// 胶囊体 = 线段 + 半径
// 球-胶囊碰撞 = 求球心到线段的最近点 + 距离检查

float closestPointOnSegment(
    float px, float py, float pz,  // 点
    float ax, float ay, float az,  // 线段起点
    float bx, float by, float bz,  // 线段终点
    float& outX, float& outY, float& outZ)
{
    float abx = bx - ax, aby = by - ay, abz = bz - az;
    float apx = px - ax, apy = py - ay, apz = pz - az;

    float t = (apx*abx + apy*aby + apz*abz) /
              (abx*abx + aby*aby + abz*abz + 1e-10f);
    t = std::clamp(t, 0.0f, 1.0f);

    outX = ax + t * abx;
    outY = ay + t * aby;
    outZ = az + t * abz;
    return t;
}

void detectSphereCapsule(
    const float* spherePosX, const float* spherePosY, const float* spherePosZ,
    const float* sphereRadius,
    const float* capStartX, const float* capStartY, const float* capStartZ,
    const float* capEndX, const float* capEndY, const float* capEndZ,
    const float* capRadius,
    const uint32_t* bodyA, const uint32_t* bodyB,
    size_t pairCount,
    std::vector<ContactPoint>& contacts)
{
    for (size_t i = 0; i < pairCount; ++i) {
        // 找到球心到胶囊线段的最近点
        float closestX, closestY, closestZ;
        closestPointOnSegment(
            spherePosX[i], spherePosY[i], spherePosZ[i],
            capStartX[i], capStartY[i], capStartZ[i],
            capEndX[i], capEndY[i], capEndZ[i],
            closestX, closestY, closestZ);

        // 现在退化为 球心 vs 最近点 的球-球检测
        float dx = spherePosX[i] - closestX;
        float dy = spherePosY[i] - closestY;
        float dz = spherePosZ[i] - closestZ;

        float distSq = dx*dx + dy*dy + dz*dz;
        float radiusSum = sphereRadius[i] + capRadius[i];

        if (distSq < radiusSum * radiusSum) {
            float dist = std::sqrt(distSq);
            float invDist = (dist > 1e-6f) ? 1.0f / dist : 0.0f;

            contacts.push_back({
                closestX + dx * invDist * capRadius[i],
                closestY + dy * invDist * capRadius[i],
                closestZ + dz * invDist * capRadius[i],
                dx * invDist, dy * invDist, dz * invDist,
                radiusSum - dist,
                bodyA[i], bodyB[i]
            });
        }
    }
}

} // namespace physics::collision
```

---

#### 2.6 接触流形生成与缓存

```cpp
// ==========================================
// 接触流形（Contact Manifold）
// ==========================================
//
// 一对碰撞物体通常有多个接触点。
// 例如一个盒子放在地面上 → 4个接触点（4个角）。
//
// 为什么需要多个接触点？
//   单个接触点无法正确模拟"稳定放置"。
//   盒子在地面上需要至少3个点才能不翻倒。
//
// 接触流形的生命周期：
//   1. 窄相位检测产生新的接触点
//   2. 与上一帧的流形合并（匹配已有接触点）
//   3. 保留最多4个最具代表性的接触点
//   4. warm starting：用上一帧的冲量作为初始猜测
//
// warm starting的重要性（Erin Catto）：
//   "Without warm starting, stacking is nearly impossible.
//    With it, you can stack 20 boxes with just 4 solver iterations."

#include <vector>
#include <cstdint>
#include <array>
#include <cmath>

namespace physics::collision {

// 单个接触点（带缓存数据）
struct CachedContact {
    float posX, posY, posZ;        // 接触点
    float normalX, normalY, normalZ; // 法线
    float penetration;
    float normalImpulse;           // 上一帧的法向冲量（warm starting）
    float tangentImpulseX;         // 上一帧的切向冲量X
    float tangentImpulseY;         // 上一帧的切向冲量Y
    uint32_t featureIdA;           // 特征ID（用于帧间匹配）
    uint32_t featureIdB;
};

// 接触流形——最多4个接触点
struct ContactManifold {
    uint32_t bodyA, bodyB;
    std::array<CachedContact, 4> contacts;
    uint8_t contactCount;
    float restitution;
    float friction;

    // 添加新接触点，保持最多4个最分散的点
    void addContact(const CachedContact& newContact) {
        if (contactCount < 4) {
            contacts[contactCount++] = newContact;
            return;
        }

        // 已满——替换最不重要的接触点
        // 策略：保持4个点组成的四边形面积最大
        // 简化实现：替换穿透最浅的
        int shallowest = 0;
        for (int i = 1; i < 4; ++i) {
            if (contacts[i].penetration < contacts[shallowest].penetration) {
                shallowest = i;
            }
        }

        if (newContact.penetration > contacts[shallowest].penetration) {
            contacts[shallowest] = newContact;
        }
    }

    // 帧间匹配：用特征ID匹配旧接触点
    void matchAndMerge(const ContactManifold& oldManifold) {
        for (int i = 0; i < contactCount; ++i) {
            for (int j = 0; j < oldManifold.contactCount; ++j) {
                if (contacts[i].featureIdA == oldManifold.contacts[j].featureIdA &&
                    contacts[i].featureIdB == oldManifold.contacts[j].featureIdB) {
                    // 匹配成功——继承冲量（warm starting）
                    contacts[i].normalImpulse = oldManifold.contacts[j].normalImpulse;
                    contacts[i].tangentImpulseX = oldManifold.contacts[j].tangentImpulseX;
                    contacts[i].tangentImpulseY = oldManifold.contacts[j].tangentImpulseY;
                    break;
                }
            }
        }
    }
};

// 流形缓存——存储所有活跃的碰撞对
class ManifoldCache {
    // 用body对作为key的哈希表
    struct ManifoldEntry {
        uint64_t key;  // (bodyA << 32) | bodyB
        ContactManifold manifold;
    };

    std::vector<ManifoldEntry> entries_;

public:
    // 查找或创建流形
    ContactManifold* findOrCreate(uint32_t bodyA, uint32_t bodyB) {
        uint64_t key = (static_cast<uint64_t>(std::min(bodyA, bodyB)) << 32) |
                        std::max(bodyA, bodyB);

        for (auto& entry : entries_) {
            if (entry.key == key) return &entry.manifold;
        }

        entries_.push_back({key, {}});
        auto& m = entries_.back().manifold;
        m.bodyA = std::min(bodyA, bodyB);
        m.bodyB = std::max(bodyA, bodyB);
        m.contactCount = 0;
        return &m;
    }

    // 清理不再活跃的流形
    void removeStale(const std::vector<std::pair<uint32_t, uint32_t>>& activePairs) {
        entries_.erase(
            std::remove_if(entries_.begin(), entries_.end(),
                [&](const ManifoldEntry& e) {
                    uint32_t a = static_cast<uint32_t>(e.key >> 32);
                    uint32_t b = static_cast<uint32_t>(e.key & 0xFFFFFFFF);
                    return std::find(activePairs.begin(), activePairs.end(),
                                     std::make_pair(a, b)) == activePairs.end();
                }),
            entries_.end());
    }

    auto begin() { return entries_.begin(); }
    auto end() { return entries_.end(); }
    size_t size() const { return entries_.size(); }
};

} // namespace physics::collision
```

---

#### 2.7 碰撞检测流水线集成

```cpp
// ==========================================
// 碰撞检测流水线——将所有组件串联
// ==========================================
//
// 完整流程：
//   1. 更新AABB（从刚体位置和碰撞器形状计算）
//   2. 宽相位：空间数据结构生成碰撞对
//   3. 碰撞对按类型排序
//   4. 窄相位：按类型批量检测
//   5. 流形更新：帧间匹配与warm starting
//   6. 输出：ContactManifold列表给求解器

#include <vector>
#include <algorithm>

namespace physics::collision {

class CollisionPipeline {
    ManifoldCache manifoldCache_;

public:
    struct PipelineStats {
        size_t broadPhasePairs;
        size_t narrowPhasePairs;
        size_t activeContacts;
        double broadPhaseMs;
        double narrowPhaseMs;
    };

    PipelineStats lastStats;

    // 主检测函数
    std::vector<ContactManifold> detectCollisions(
        // AABB数据（SoA）
        const float* aabbMinX, const float* aabbMinY, const float* aabbMinZ,
        const float* aabbMaxX, const float* aabbMaxY, const float* aabbMaxZ,
        // 位置数据
        const float* posX, const float* posY, const float* posZ,
        // 碰撞器类型与数据
        const ColliderType* types,
        const float* radii,     // 球体半径
        // 材质属性
        const float* restitution, const float* friction,
        size_t bodyCount,
        // 宽相位碰撞对（外部提供）
        const std::vector<std::pair<uint32_t, uint32_t>>& broadPairs)
    {
        lastStats.broadPhasePairs = broadPairs.size();

        // 按碰撞器类型对排序碰撞对
        // 这样同类型的碰撞器连续处理——缓存友好
        auto sortedPairs = broadPairs;
        std::sort(sortedPairs.begin(), sortedPairs.end(),
            [types](const auto& p1, const auto& p2) {
                auto key1 = (static_cast<int>(types[p1.first]) << 8) |
                             static_cast<int>(types[p1.second]);
                auto key2 = (static_cast<int>(types[p2.first]) << 8) |
                             static_cast<int>(types[p2.second]);
                return key1 < key2;
            });

        // 窄相位检测
        std::vector<ContactPoint> allContacts;

        // 准备批量数据——按类型分组
        std::vector<float> pairPosAX, pairPosAY, pairPosAZ, pairRadA;
        std::vector<float> pairPosBX, pairPosBY, pairPosBZ, pairRadB;
        std::vector<uint32_t> pairBodyA, pairBodyB;

        for (const auto& [a, b] : sortedPairs) {
            ColliderType typeA = types[a];
            ColliderType typeB = types[b];

            // 球-球批量
            if (typeA == ColliderType::Sphere && typeB == ColliderType::Sphere) {
                pairPosAX.push_back(posX[a]); pairPosAY.push_back(posY[a]);
                pairPosAZ.push_back(posZ[a]); pairRadA.push_back(radii[a]);
                pairPosBX.push_back(posX[b]); pairPosBY.push_back(posY[b]);
                pairPosBZ.push_back(posZ[b]); pairRadB.push_back(radii[b]);
                pairBodyA.push_back(a); pairBodyB.push_back(b);
            }
        }

        // 批量检测球-球
        if (!pairBodyA.empty()) {
            detectSphereSphere(
                pairPosAX.data(), pairPosAY.data(), pairPosAZ.data(), pairRadA.data(),
                pairPosBX.data(), pairPosBY.data(), pairPosBZ.data(), pairRadB.data(),
                pairBodyA.data(), pairBodyB.data(),
                pairBodyA.size(), allContacts);
        }

        lastStats.narrowPhasePairs = allContacts.size();

        // 更新流形缓存
        std::vector<ContactManifold> result;
        for (const auto& contact : allContacts) {
            auto* manifold = manifoldCache_.findOrCreate(contact.bodyA, contact.bodyB);
            CachedContact cached{};
            cached.posX = contact.posX; cached.posY = contact.posY; cached.posZ = contact.posZ;
            cached.normalX = contact.normalX; cached.normalY = contact.normalY;
            cached.normalZ = contact.normalZ;
            cached.penetration = contact.penetration;
            manifold->addContact(cached);
            manifold->restitution = std::min(restitution[contact.bodyA],
                                             restitution[contact.bodyB]);
            manifold->friction = std::sqrt(friction[contact.bodyA] *
                                           friction[contact.bodyB]);
        }

        // 收集所有活跃流形
        for (auto it = manifoldCache_.begin(); it != manifoldCache_.end(); ++it) {
            if (it->manifold.contactCount > 0) {
                result.push_back(it->manifold);
            }
        }

        lastStats.activeContacts = result.size();
        return result;
    }
};

} // namespace physics::collision
```

---

#### 2.8 本周练习任务

```
练习1：球-球SIMD碰撞检测
─────────────────────────
目标：实现AVX256版本的批量球-球碰撞检测

要求：
1. 一次处理8对球-球碰撞
2. 使用SIMD计算距离平方、半径和比较
3. 使用movemask提取碰撞掩码
4. 与标量版本对比正确性和性能

验证：
- 10000对球-球检测：SIMD版本应比标量快3-6倍
- 结果应与标量版本完全一致

练习2：SAT实现与可视化
─────────────────────
目标：实现完整的OBB-OBB SAT检测，并在2D中可视化

要求：
1. 完整实现15轴SAT检测（6主轴+9交叉轴）
2. 在碰撞时返回最小穿透轴和深度
3. 在2D版本中输出分离轴和投影区间的ASCII可视化
4. 测试边缘情况：平行边、点接触、完全包含

验证：
- 与已知结果对比：两个对齐的单位盒间距0.5时应检测到碰撞
- 旋转45度后仍然正确

练习3：GJK+EPA碰撞检测
─────────────────────
目标：实现GJK碰撞检测和EPA穿透深度提取

要求：
1. 实现GJK的完整4阶段单纯形更新
2. 实现EPA的多面体扩展
3. 测试球-球、球-盒、盒-盒组合
4. 与SAT的结果对比验证

验证：
- GJK+EPA的穿透深度应与SAT结果一致（误差<0.01）
- GJK迭代次数通常<10次

练习4：碰撞检测流水线基准测试
────────────────────────────
目标：搭建完整的宽相位→窄相位流水线并测量各阶段耗时

要求：
1. 创建1000-10000个随机球体场景
2. 实现宽相位（使用第一周的均匀网格）
3. 实现窄相位（球-球检测）
4. 测量各阶段耗时占比，输出报告

验证：
- 宽相位应过滤掉95%+的碰撞对
- 总耗时应随物体数量近似线性增长
```

---

#### 2.9 本周知识检验

```
思考题1：GJK算法每次迭代最多添加一个点到单纯形。为什么在3D中最多需要4个点
         （四面体），而不是更多？这与Minkowski差的维度有什么关系？

思考题2：SAT对AABB只需要测试6条轴（3对平行轴），但OBB需要15条（6+9）。
         为什么AABB不需要交叉轴？（提示：AABB的轴与世界坐标轴对齐意味着什么）

思考题3：EPA的收敛速度取决于初始单纯形的质量。如果GJK终止时只有2个点
         （线段）而非4个（四面体），EPA无法启动。Box2D是如何处理这种情况的？

思考题4：warm starting是约束求解器性能的关键。如果没有warm starting，
         Erin Catto说"堆叠几乎不可能"。解释为什么从零开始的迭代求解器
         需要更多迭代次数，以及warm starting如何解决这个问题。

思考题5：碰撞检测的"按类型排序后批量处理"与上月学到的"排序后批处理消除分支"
         本质上是同一种DOD模式。请总结这种模式的一般化原则，
         以及它为什么在缓存和分支预测两方面都有益。

实践题1：
  两个半径为1的球体，球心分别在(0,0,0)和(1.5,0,0)。
  (a) 手工计算接触点、法线和穿透深度
  (b) 如果使用GJK，画出前3次迭代的单纯形演化
  (c) 如果使用EPA，初始四面体是什么形状？

实践题2：
  一个AABB为[-1,-1,-1]到[1,1,1]的盒子和一个AABB为[0.5,-0.5,-0.5]到[2.5,0.5,0.5]
  的盒子。
  (a) 用SAT测试：在X/Y/Z三条轴上的投影区间分别是什么？
  (b) 哪些轴上重叠？哪条轴给出最小穿透？
  (c) 计算最小穿透深度和方向
```

### 第三周：多线程DOD设计（35小时）

**学习目标**：
- [ ] 理解数据并行（Data Parallelism）与任务并行（Task Parallelism）的区别与适用场景
- [ ] 掌握线程池（Thread Pool）与Job System的设计，理解任务粒度对性能的影响
- [ ] 实现无锁（Lock-Free）碰撞对收集器，深入理解原子操作与memory ordering
- [ ] 理解Work Stealing调度策略的原理与实现，掌握双端队列（deque）的无锁实现
- [ ] 掌握SPSC（单生产者单消费者）和MPMC（多生产者多消费者）队列的设计差异
- [ ] 理解C++内存模型：memory_order_relaxed/acquire/release/seq_cst的语义差别
- [ ] 实现物理引擎的任务图（Task Graph），将物理流水线分解为可并行的任务节点

**阅读材料**：
- [ ] 《C++ Concurrency in Action》2nd Edition - Anthony Williams（Chapter 5-7）
- [ ] Intel TBB文档 - Task Scheduler与parallel_for
- [ ] 《Parallelizing the Naughty Dog Engine Using Fibers》- GDC 2015
- [ ] 《Destiny's Multithreaded Rendering Architecture》- GDC 2015
- [ ] Jeff Preshing的博客 - Lock-Free Programming系列
- [ ] 《Is Parallel Programming Hard?》- Paul McKenney（Chapter 4-6）
- [ ] CppCon 2017:《C++ atomics, from basic to advanced》- Fedor Pikus

---

#### 核心概念

**并行策略选择**
```
┌─────────────────────────────────────────────────────────────┐
│              物理引擎中的并行策略                               │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  数据并行 (Data Parallel)         任务并行 (Task Parallel)    │
│  ┌───────────────────────┐       ┌─────┐ ┌─────┐ ┌─────┐  │
│  │ Thread 0: [0..N/4]    │       │重力  │ │碰撞  │ │约束  │  │
│  │ Thread 1: [N/4..N/2]  │       │计算  │→│检测  │→│求解  │  │
│  │ Thread 2: [N/2..3N/4] │       └──┬──┘ └──┬──┘ └──┬──┘  │
│  │ Thread 3: [3N/4..N]   │          │       │       │      │
│  └───────────────────────┘       并行执行独立阶段             │
│  同一操作，不同数据                不同操作，有依赖关系         │
│                                                              │
│  适用：积分、力累加、AABB更新       适用：流水线阶段、异构任务  │
│  优势：实现简单、负载均衡           优势：隐藏延迟、利用依赖图  │
│  注意：需要无竞争的数据划分         注意：需要正确的依赖管理     │
│                                                              │
│  ═══════════════════════════════════════════════════════     │
│  物理引擎的最佳实践：两者结合使用                              │
│  - 阶段间：任务并行（重力→碰撞→约束→积分）                    │
│  - 阶段内：数据并行（10000物体分4线程处理）                    │
└─────────────────────────────────────────────────────────────┘
```

---

#### 3.1 数据并行——物理引擎的基础并行模式

```cpp
// ==========================================
// 数据并行：DOD天然适合的并行模式
// ==========================================
//
// DOD的SoA布局天然适合数据并行：
//   - 每个数组可以按范围切分给不同线程
//   - 同一操作对所有元素执行——无分支分歧
//   - 元素间无依赖——完美并行
//
// 关键原则：
//   1. 避免写冲突——每个线程写自己的范围
//   2. 避免伪共享——切分边界对齐到缓存行
//   3. 任务粒度不能太细——线程切换开销约1-10μs
//
// 经验法则（Naughty Dog）：
//   "每个任务至少执行50μs的工作量。
//    更细的粒度会被调度开销吞没。"

#include <vector>
#include <thread>
#include <functional>
#include <cstdint>
#include <algorithm>
#include <atomic>

namespace physics::threading {

// ──────────────────────────────────────
// parallel_for——数据并行的基础原语
// ──────────────────────────────────────
//
// 将[0, count)范围切分给多个线程
// 切分边界对齐到16元素（64字节=16 float=1缓存行）
// 避免伪共享

void parallelFor(size_t count, size_t minChunkSize,
                 std::function<void(size_t begin, size_t end)> body) {
    const size_t threadCount = std::thread::hardware_concurrency();

    // 计算每个线程的工作量
    size_t chunkSize = (count + threadCount - 1) / threadCount;
    // 对齐到缓存行（16个float）
    chunkSize = ((chunkSize + 15) / 16) * 16;
    // 确保不低于最小粒度
    chunkSize = std::max(chunkSize, minChunkSize);

    const size_t actualThreads = (count + chunkSize - 1) / chunkSize;

    if (actualThreads <= 1) {
        body(0, count);
        return;
    }

    std::vector<std::thread> threads;
    threads.reserve(actualThreads - 1);

    for (size_t t = 1; t < actualThreads; ++t) {
        size_t begin = t * chunkSize;
        size_t end = std::min(begin + chunkSize, count);
        threads.emplace_back(body, begin, end);
    }

    // 主线程处理第一块
    body(0, std::min(chunkSize, count));

    for (auto& t : threads) t.join();
}

// 并行积分示例
void integrateParallel(
    float* posX, float* posY, float* posZ,
    float* velX, float* velY, float* velZ,
    const float* forceX, const float* forceY, const float* forceZ,
    const float* invMass,
    size_t count, float dt)
{
    parallelFor(count, 256, [&](size_t begin, size_t end) {
        for (size_t i = begin; i < end; ++i) {
            if (invMass[i] == 0) continue;

            velX[i] += forceX[i] * invMass[i] * dt;
            velY[i] += forceY[i] * invMass[i] * dt;
            velZ[i] += forceZ[i] * invMass[i] * dt;

            posX[i] += velX[i] * dt;
            posY[i] += velY[i] * dt;
            posZ[i] += velZ[i] * dt;
        }
    });
}

} // namespace physics::threading
```

---

#### 3.2 线程池与Job System

```cpp
// ==========================================
// Job System：游戏引擎的标准并行架构
// ==========================================
//
// 为什么不直接用std::thread？
//   创建/销毁线程的开销约10-100μs。
//   物理引擎每帧可能提交数百个任务，
//   如果每个任务都创建线程，开销比计算本身还大。
//
// Job System的核心思想：
//   预先创建一组工作线程（通常=核心数），
//   任务被提交到队列，工作线程从队列取任务执行。
//
// 游戏引擎Job System的演进：
//   2010前：手动线程管理，大量mutex
//   2010-15：Intel TBB, 任务窃取
//   2015+：Fiber-based（Naughty Dog），无栈协程
//   2020+：C++20 coroutine + custom scheduler

#include <thread>
#include <vector>
#include <queue>
#include <mutex>
#include <condition_variable>
#include <functional>
#include <future>
#include <atomic>

namespace physics::threading {

class ThreadPool {
    std::vector<std::thread> workers_;
    std::queue<std::function<void()>> tasks_;
    std::mutex mutex_;
    std::condition_variable cv_;
    std::atomic<bool> stop_{false};

public:
    explicit ThreadPool(size_t numThreads = 0) {
        if (numThreads == 0) {
            numThreads = std::thread::hardware_concurrency();
        }

        for (size_t i = 0; i < numThreads; ++i) {
            workers_.emplace_back([this] {
                while (true) {
                    std::function<void()> task;
                    {
                        std::unique_lock lock(mutex_);
                        cv_.wait(lock, [this] {
                            return stop_ || !tasks_.empty();
                        });
                        if (stop_ && tasks_.empty()) return;
                        task = std::move(tasks_.front());
                        tasks_.pop();
                    }
                    task();
                }
            });
        }
    }

    ~ThreadPool() {
        stop_ = true;
        cv_.notify_all();
        for (auto& w : workers_) w.join();
    }

    // 提交任务，返回future
    template<typename F>
    auto submit(F&& func) -> std::future<decltype(func())> {
        using ReturnType = decltype(func());
        auto task = std::make_shared<std::packaged_task<ReturnType()>>(
            std::forward<F>(func));
        auto future = task->get_future();

        {
            std::lock_guard lock(mutex_);
            tasks_.emplace([task] { (*task)(); });
        }
        cv_.notify_one();

        return future;
    }

    size_t threadCount() const { return workers_.size(); }
};

// ──────────────────────────────────────
// Job System——带依赖的任务调度
// ──────────────────────────────────────
//
// 与ThreadPool不同，JobSystem支持任务间的依赖关系。
// 任务只有在其所有前置任务完成后才会被调度。

struct JobHandle {
    uint32_t id;
};

class JobSystem {
    struct Job {
        std::function<void()> work;
        std::atomic<int> pendingDeps{0};
        std::vector<uint32_t> dependents;  // 依赖此任务的后续任务
        std::atomic<bool> completed{false};
    };

    std::vector<Job> jobs_;
    ThreadPool pool_;
    std::mutex scheduleMutex_;

public:
    explicit JobSystem(size_t numThreads = 0) : pool_(numThreads) {}

    // 创建任务
    JobHandle createJob(std::function<void()> work) {
        uint32_t id = static_cast<uint32_t>(jobs_.size());
        jobs_.push_back({std::move(work), {0}, {}, {false}});
        return {id};
    }

    // 添加依赖：job 依赖于 dependency
    void addDependency(JobHandle job, JobHandle dependency) {
        jobs_[job.id].pendingDeps.fetch_add(1, std::memory_order_relaxed);
        jobs_[dependency.id].dependents.push_back(job.id);
    }

    // 提交所有任务并等待完成
    void dispatch() {
        // 找到所有无依赖的任务并提交
        for (size_t i = 0; i < jobs_.size(); ++i) {
            if (jobs_[i].pendingDeps.load(std::memory_order_relaxed) == 0) {
                scheduleJob(static_cast<uint32_t>(i));
            }
        }

        // 等待所有任务完成
        for (auto& job : jobs_) {
            while (!job.completed.load(std::memory_order_acquire)) {
                std::this_thread::yield();
            }
        }
    }

    void reset() { jobs_.clear(); }

private:
    void scheduleJob(uint32_t jobId) {
        pool_.submit([this, jobId] {
            // 执行任务
            jobs_[jobId].work();
            jobs_[jobId].completed.store(true, std::memory_order_release);

            // 通知依赖此任务的后续任务
            for (uint32_t depId : jobs_[jobId].dependents) {
                if (jobs_[depId].pendingDeps.fetch_sub(1, std::memory_order_acq_rel) == 1) {
                    // 最后一个依赖完成——调度此任务
                    scheduleJob(depId);
                }
            }
        });
    }
};

} // namespace physics::threading
```

---

#### 3.3 无锁数据结构

```cpp
// ==========================================
// 无锁碰撞对收集器
// ==========================================
//
// 在多线程宽相位碰撞检测中，多个线程同时产生碰撞对。
// 使用mutex收集结果会严重降低并行效率。
//
// 无锁方案：使用原子写索引
//   - 每个线程用fetch_add获取独占的写位置
//   - 写入预分配的固定大小数组
//   - 零竞争（除了原子操作本身）
//
// 关键：使用memory_order_relaxed
//   碰撞对的顺序不重要（物理结果与顺序无关），
//   所以不需要严格的内存序——relaxed足够。
//   这比seq_cst快2-5倍。
//
// 关于memory ordering的直觉：
//   relaxed：只保证原子性（不会看到"半写入"的值）
//   acquire/release：保证在此操作前/后的写入对其他线程可见
//   seq_cst：全局总序——最慢但最安全
//
// Jeff Preshing的经验：
//   "Start with seq_cst, then relax only when profiling shows it matters."

#include <atomic>
#include <vector>
#include <cstdint>

namespace physics::threading {

// ──────────────────────────────────────
// 无锁碰撞对收集器
// ──────────────────────────────────────

class LockFreePairCollector {
private:
    // 使用缓存行对齐的原子变量
    // 避免writeIndex与其他数据的伪共享
    struct alignas(64) PaddedAtomic {
        std::atomic<uint32_t> value{0};
        char padding[64 - sizeof(std::atomic<uint32_t>)];
    };

    // 预分配的固定大小数组——不需要动态扩容
    std::vector<std::pair<uint32_t, uint32_t>> pairs_;
    PaddedAtomic writeIndex_;
    size_t capacity_;

public:
    explicit LockFreePairCollector(size_t capacity)
        : pairs_(capacity), capacity_(capacity) {}

    // 线程安全地添加碰撞对
    // 返回false如果容量不足
    bool tryAdd(uint32_t a, uint32_t b) {
        // fetch_add是原子的：每个线程获得独占的索引
        // relaxed：不需要同步其他内存操作
        uint32_t idx = writeIndex_.value.fetch_add(1, std::memory_order_relaxed);

        if (idx >= capacity_) {
            return false;  // 溢出——需要更大的缓冲区
        }

        // 写入是安全的：idx对此线程是独占的
        pairs_[idx] = {a, b};
        return true;
    }

    void clear() {
        writeIndex_.value.store(0, std::memory_order_relaxed);
    }

    size_t size() const {
        return std::min(
            static_cast<size_t>(writeIndex_.value.load(std::memory_order_relaxed)),
            capacity_);
    }

    const auto* data() const { return pairs_.data(); }
    auto begin() const { return pairs_.begin(); }
    auto end() const { return pairs_.begin() + size(); }
};

// ──────────────────────────────────────
// 无锁SPSC队列（单生产者单消费者）
// ──────────────────────────────────────
//
// SPSC是最简单的无锁队列：
//   - 只有一个线程写（生产者）
//   - 只有一个线程读（消费者）
//   - 使用环形缓冲区 + 两个原子索引
//
// 在物理引擎中的应用：
//   主线程产生碰撞对 → 求解线程消费
//   宽相位线程产生候选 → 窄相位线程消费

template<typename T, size_t Capacity>
class SPSCQueue {
    static_assert((Capacity & (Capacity - 1)) == 0, "Capacity must be power of 2");

    alignas(64) std::array<T, Capacity> buffer_;
    alignas(64) std::atomic<size_t> head_{0};  // 消费者读取位置
    alignas(64) std::atomic<size_t> tail_{0};  // 生产者写入位置

public:
    // 生产者调用——只有一个线程可以调用push
    bool push(const T& item) {
        size_t tail = tail_.load(std::memory_order_relaxed);
        size_t next = (tail + 1) & (Capacity - 1);

        if (next == head_.load(std::memory_order_acquire)) {
            return false;  // 队列满
        }

        buffer_[tail] = item;
        tail_.store(next, std::memory_order_release);
        return true;
    }

    // 消费者调用——只有一个线程可以调用pop
    bool pop(T& item) {
        size_t head = head_.load(std::memory_order_relaxed);

        if (head == tail_.load(std::memory_order_acquire)) {
            return false;  // 队列空
        }

        item = buffer_[head];
        head_.store((head + 1) & (Capacity - 1), std::memory_order_release);
        return true;
    }

    bool empty() const {
        return head_.load(std::memory_order_acquire) ==
               tail_.load(std::memory_order_acquire);
    }
};

} // namespace physics::threading
```

---

#### 3.4 Work Stealing调度

```cpp
// ==========================================
// Work Stealing：自适应负载均衡
// ==========================================
//
// 问题：静态数据切分可能导致负载不均衡。
//   例如：碰撞检测中，某些区域物体密集→那个线程工作量大。
//
// Work Stealing解决方案：
//   每个线程有自己的工作队列（双端队列/deque）。
//   线程从自己队列的"前端"取任务（LIFO——局部性好）。
//   当自己队列空了，从其他线程队列的"后端"偷任务（FIFO——粗粒度）。
//
// 为什么偷的是"后端"？
//   - 后端的任务通常更"粗粒度"（分治树的上层）
//   - 减少了偷取频率
//   - 偷取者和被偷者操作队列的不同端——减少竞争
//
// Intel TBB和Java ForkJoinPool都使用Work Stealing。

#include <deque>
#include <mutex>
#include <vector>
#include <thread>
#include <atomic>
#include <functional>
#include <random>

namespace physics::threading {

class WorkStealingScheduler {
    struct WorkerQueue {
        std::deque<std::function<void()>> tasks;
        std::mutex mutex;

        void pushLocal(std::function<void()> task) {
            std::lock_guard lock(mutex);
            tasks.push_front(std::move(task));  // LIFO端
        }

        bool popLocal(std::function<void()>& task) {
            std::lock_guard lock(mutex);
            if (tasks.empty()) return false;
            task = std::move(tasks.front());    // LIFO端
            tasks.pop_front();
            return true;
        }

        bool steal(std::function<void()>& task) {
            std::lock_guard lock(mutex);
            if (tasks.empty()) return false;
            task = std::move(tasks.back());     // FIFO端（粗粒度）
            tasks.pop_back();
            return true;
        }

        bool empty() {
            std::lock_guard lock(mutex);
            return tasks.empty();
        }
    };

    std::vector<WorkerQueue> queues_;
    std::vector<std::thread> workers_;
    std::atomic<bool> stop_{false};
    std::atomic<int> activeTasks_{0};
    size_t numWorkers_;

public:
    explicit WorkStealingScheduler(size_t numWorkers = 0)
        : numWorkers_(numWorkers ? numWorkers : std::thread::hardware_concurrency())
    {
        queues_.resize(numWorkers_);

        for (size_t i = 0; i < numWorkers_; ++i) {
            workers_.emplace_back([this, i] { workerLoop(i); });
        }
    }

    ~WorkStealingScheduler() {
        stop_ = true;
        for (auto& w : workers_) w.join();
    }

    // 提交任务到指定工作线程
    void submit(std::function<void()> task, size_t preferredWorker = 0) {
        activeTasks_.fetch_add(1, std::memory_order_relaxed);
        queues_[preferredWorker % numWorkers_].pushLocal(std::move(task));
    }

    // 等待所有任务完成
    void waitAll() {
        while (activeTasks_.load(std::memory_order_relaxed) > 0) {
            std::this_thread::yield();
        }
    }

private:
    void workerLoop(size_t workerId) {
        std::mt19937 rng(static_cast<uint32_t>(workerId));

        while (!stop_) {
            std::function<void()> task;

            // 先尝试从自己的队列取
            if (queues_[workerId].popLocal(task)) {
                task();
                activeTasks_.fetch_sub(1, std::memory_order_relaxed);
                continue;
            }

            // 自己队列空了——尝试偷
            bool stolen = false;
            // 随机选择受害者（减少竞争）
            size_t victim = rng() % numWorkers_;
            for (size_t attempts = 0; attempts < numWorkers_; ++attempts) {
                if (victim != workerId && queues_[victim].steal(task)) {
                    task();
                    activeTasks_.fetch_sub(1, std::memory_order_relaxed);
                    stolen = true;
                    break;
                }
                victim = (victim + 1) % numWorkers_;
            }

            if (!stolen) {
                std::this_thread::yield();  // 无任务可偷，让出CPU
            }
        }
    }
};

} // namespace physics::threading
```

---

#### 3.5 内存序与原子操作深入

```
C++内存序模型速查表
══════════════════

memory_order_relaxed
────────────────────
  保证：原子性（不会看到half-written值）
  不保证：与其他内存操作的顺序
  用途：计数器、统计、不需要同步的场景
  性能：最快（某些架构上等于普通加载/存储）

  示例：碰撞对收集器的writeIndex
    // 碰撞对的顺序不影响物理结果，所以relaxed足够
    idx = counter.fetch_add(1, memory_order_relaxed);

memory_order_acquire（加载时使用）
─────────────────────────────────
  保证：此加载之后的所有读写操作不会被重排到此之前
  直觉：像一道"单向门"——之后的操作不能穿越到之前

memory_order_release（存储时使用）
─────────────────────────────────
  保证：此存储之前的所有读写操作不会被重排到此之后
  直觉：像一道"单向门"——之前的操作不能穿越到之后

  示例：SPSC队列
    生产者：
      buffer[tail] = item;                          // 普通写
      tail_.store(next, memory_order_release);       // release保证上面的写入可见
    消费者：
      if (head == tail_.load(memory_order_acquire))  // acquire保证读到最新的buffer
      item = buffer[head];                           // 安全读取

  acquire-release配对的直觉：
    release"发布"了一组修改，acquire"获取"了这些修改。
    这是最常用的同步模式。

memory_order_seq_cst（默认）
────────────────────────────
  保证：全局总序——所有线程看到相同的操作顺序
  用途：简单但慢，初始开发阶段使用
  性能：最慢（x86上加载无额外开销，但存储有mfence）

常见陷阱
────────
  1. relaxed load + relaxed store 不构成同步
     → 另一个线程可能看到"旧数据"

  2. 编译器重排 ≠ CPU重排
     → volatile不能替代atomic
     → 即使编译器不重排，CPU也可能重排（ARM/POWER）

  3. x86是强内存序（TSO）
     → 某些在x86上正确的代码在ARM上会挂
     → 始终使用正确的memory order，不要依赖硬件
```

---

#### 3.6 物理引擎的任务图

```cpp
// ==========================================
// 物理引擎任务图——流水线并行化
// ==========================================
//
// 物理引擎的每帧工作可以分解为一个有向无环图（DAG）：
//
//   ┌──────────┐   ┌──────────┐
//   │ 应用重力  │   │ 更新AABB │   （并行：两者独立）
//   └────┬─────┘   └────┬─────┘
//        │              │
//        └──────┬───────┘
//               ▼
//        ┌──────────────┐
//        │   宽相位碰撞  │   （依赖AABB更新）
//        └──────┬───────┘
//               ▼
//        ┌──────────────┐
//        │   窄相位碰撞  │   （依赖宽相位结果）
//        └──────┬───────┘
//               ▼
//        ┌──────────────┐
//        │   约束求解    │   （依赖窄相位结果）
//        └──────┬───────┘
//               ▼
//        ┌──────────────┐
//        │   积分位置    │   （依赖约束求解结果）
//        └──────────────┘
//
// 每个阶段内部可以数据并行（切分给多个线程）。
// 阶段间是任务并行（按依赖关系调度）。

#include <functional>
#include <vector>

namespace physics::threading {

// 物理引擎任务图构建器
class PhysicsTaskGraph {
    JobSystem& jobSystem_;

public:
    explicit PhysicsTaskGraph(JobSystem& js) : jobSystem_(js) {}

    void buildAndExecute(
        // 各阶段的工作函数
        std::function<void()> applyGravity,
        std::function<void()> updateAABBs,
        std::function<void()> broadPhase,
        std::function<void()> narrowPhase,
        std::function<void()> solveConstraints,
        std::function<void()> integratePositions)
    {
        jobSystem_.reset();

        // 创建任务节点
        auto gravityJob = jobSystem_.createJob(applyGravity);
        auto aabbJob = jobSystem_.createJob(updateAABBs);
        auto broadJob = jobSystem_.createJob(broadPhase);
        auto narrowJob = jobSystem_.createJob(narrowPhase);
        auto solveJob = jobSystem_.createJob(solveConstraints);
        auto integrateJob = jobSystem_.createJob(integratePositions);

        // 定义依赖关系
        // 宽相位依赖AABB更新
        jobSystem_.addDependency(broadJob, aabbJob);
        // 窄相位依赖宽相位和重力（重力影响速度→影响CCD）
        jobSystem_.addDependency(narrowJob, broadJob);
        jobSystem_.addDependency(narrowJob, gravityJob);
        // 约束求解依赖窄相位
        jobSystem_.addDependency(solveJob, narrowJob);
        // 积分依赖约束求解
        jobSystem_.addDependency(integrateJob, solveJob);

        // 提交并等待
        jobSystem_.dispatch();
    }
};

} // namespace physics::threading
```

---

#### 3.7 并行碰撞检测的实际实现

```cpp
// ==========================================
// 并行宽相位碰撞检测——综合应用
// ==========================================
//
// 将均匀网格的碰撞对查找并行化：
//   1. 将网格单元格按范围分配给不同线程
//   2. 每个线程使用线程本地(thread-local)的碰撞对缓冲区
//   3. 完成后合并所有缓冲区
//
// 为什么使用线程本地缓冲区而非LockFreePairCollector？
//   - LockFreePairCollector的原子fetch_add虽然无锁，
//     但高争用下仍有CAS重试开销
//   - 线程本地缓冲区：零争用，零原子操作
//   - 最后的合并是O(results)，单线程，但只执行一次
//
// 经验规则：
//   争用少（<4线程）→ LockFreePairCollector更简单
//   争用多（>4线程）→ 线程本地缓冲区 + 合并

#include <vector>
#include <thread>
#include <cstdint>

namespace physics::threading {

struct CollisionPair { uint32_t a, b; };

std::vector<CollisionPair> parallelBroadPhase(
    // 网格数据
    const uint32_t* cellStart, const uint32_t* cellCount,
    const uint32_t* sortedIds, size_t totalCells,
    // AABB数据
    const float* minX, const float* minY, const float* minZ,
    const float* maxX, const float* maxY, const float* maxZ)
{
    const size_t threadCount = std::thread::hardware_concurrency();
    const size_t cellsPerThread = (totalCells + threadCount - 1) / threadCount;

    // 线程本地结果缓冲区
    std::vector<std::vector<CollisionPair>> localResults(threadCount);

    std::vector<std::thread> threads;
    for (size_t t = 0; t < threadCount; ++t) {
        size_t cellBegin = t * cellsPerThread;
        size_t cellEnd = std::min(cellBegin + cellsPerThread, totalCells);

        threads.emplace_back([&, t, cellBegin, cellEnd] {
            auto& local = localResults[t];
            local.reserve(1024);

            for (size_t cell = cellBegin; cell < cellEnd; ++cell) {
                uint32_t start = cellStart[cell];
                uint32_t count = cellCount[cell];

                // 单元格内部碰撞
                for (uint32_t i = 0; i < count; ++i) {
                    uint32_t bodyA = sortedIds[start + i];
                    for (uint32_t j = i + 1; j < count; ++j) {
                        uint32_t bodyB = sortedIds[start + j];

                        if (minX[bodyA] <= maxX[bodyB] && maxX[bodyA] >= minX[bodyB] &&
                            minY[bodyA] <= maxY[bodyB] && maxY[bodyA] >= minY[bodyB] &&
                            minZ[bodyA] <= maxZ[bodyB] && maxZ[bodyA] >= minZ[bodyB]) {
                            uint32_t a = std::min(bodyA, bodyB);
                            uint32_t b = std::max(bodyA, bodyB);
                            local.push_back({a, b});
                        }
                    }
                }
            }
        });
    }

    for (auto& t : threads) t.join();

    // 合并结果
    std::vector<CollisionPair> allPairs;
    size_t totalPairs = 0;
    for (const auto& local : localResults) totalPairs += local.size();
    allPairs.reserve(totalPairs);

    for (const auto& local : localResults) {
        allPairs.insert(allPairs.end(), local.begin(), local.end());
    }

    return allPairs;
}

} // namespace physics::threading
```

---

#### 3.8 本周练习任务

```
练习1：线程池实现与基准测试
─────────────────────────
目标：实现一个线程池，并测量任务提交/执行的延迟

要求：
1. 实现基本的ThreadPool（固定线程数、任务队列、condition_variable）
2. 测量空任务的提交→执行延迟（单位：微秒）
3. 测量1000个计算密集任务（每个50μs工作量）的总完成时间
4. 对比单线程执行的总时间，计算加速比

验证：
- 空任务延迟应<10μs
- 4线程加速比应接近3.5x（有调度开销）

练习2：无锁碰撞对收集器
─────────────────────
目标：实现LockFreePairCollector并在多线程碰撞检测中使用

要求：
1. 实现基于atomic fetch_add的无锁收集器
2. 4个线程同时向收集器写入碰撞对
3. 对比三种方案：mutex、LockFree、线程本地缓冲区+合并
4. 测量10000碰撞对的收集时间

验证：
- LockFree应比mutex快2-5倍
- 线程本地缓冲区应比LockFree快1.5-3倍
- 所有方案的结果集应一致（顺序可以不同）

练习3：SPSC队列实现
─────────────────
目标：实现无锁SPSC环形队列，并验证其正确性

要求：
1. 实现固定大小的SPSC队列（power-of-2大小）
2. 一个线程push 10M个元素，另一个线程pop
3. 验证所有元素都被正确接收（无丢失、无重复）
4. 使用ThreadSanitizer（-fsanitize=thread）检查数据竞争

验证：
- ThreadSanitizer不应报告任何数据竞争
- 吞吐量应>100M elements/sec

练习4：物理引擎并行化
─────────────────
目标：将实践项目中的物理引擎步骤并行化

要求：
1. 使用parallel_for并行化积分步骤
2. 使用并行宽相位碰撞检测
3. 测量10000物体场景下各阶段的耗时
4. 与单线程版本对比总体加速比

验证：
- 积分步骤：接近线性加速
- 宽相位：加速比>2x（受合并开销限制）
- 总体：4线程应达到2.5-3.5x加速
```

---

#### 3.9 本周知识检验

```
思考题1：为什么物理引擎中约束求解器难以并行化？
         （提示：两个约束可能共享同一个物体——修改同一个速度变量）
         Graph Coloring并行化策略是如何解决这个问题的？

思考题2：Work Stealing调度器中，为什么窃取者从队列"后端"取任务？
         如果改为从"前端"取会怎样？
         （提示：考虑分治递归任务的结构）

思考题3：memory_order_relaxed在x86上通常没有额外开销（因为x86的TSO模型已经提供了
         比relaxed更强的保证）。那么在x86上使用relaxed有什么好处？
         （提示：编译器优化）

思考题4：Naughty Dog使用Fiber（用户态线程/协程）而非OS线程来实现Job System。
         Fiber相比std::thread的优势和劣势各是什么？
         为什么"挂起等待依赖"在Fiber模型中很自然？

思考题5：假设你的物理引擎在8核CPU上运行，但约束求解器只能2路并行（因为依赖关系），
         其余阶段可以完美8路并行。根据Amdahl定律，整体加速比的上限是多少？
         如果约束求解器占单线程总时间的40%，结论如何？

实践题1：
  用memory_order_acquire/release实现一个简单的"发布-订阅"模式：
  线程A准备数据（写入数组），然后store(flag, release)
  线程B load(flag, acquire)后读取数据
  画出两种可能的执行顺序，说明acquire/release如何保证正确性。

实践题2：
  Amdahl定律：Speedup = 1 / ((1-P) + P/N)
  其中P=可并行比例，N=线程数

  你的物理引擎profile结果：
    积分：20%时间（完全可并行）
    碰撞检测：50%时间（90%可并行）
    约束求解：30%时间（50%可并行）

  (a) 计算8线程时的理论加速比
  (b) 如果约束求解器改进为80%可并行，加速比提升多少？
  (c) 什么是"强扩展"（Strong Scaling）和"弱扩展"（Weak Scaling）？
```

### 第四周：物理引擎集成（35小时）

**学习目标**：
- [ ] 掌握完整物理模拟流水线的设计：力累加→积分→碰撞→求解→修正的各步骤
- [ ] 深入理解Sequential Impulse（顺序冲量）约束求解器的数学推导与迭代收敛性
- [ ] 掌握Baumgarte稳定化与NGS（Non-linear Gauss-Seidel）位置修正的区别与选择
- [ ] 实现岛检测（Island Detection）优化——只唤醒互相影响的物体群
- [ ] 理解休眠系统（Sleep System）的判定条件与唤醒机制
- [ ] 学会连续碰撞检测（CCD）的基本原理——防止高速物体穿透
- [ ] 掌握物理引擎全链路性能剖析方法，识别瓶颈与优化方向

**阅读材料**：
- [ ] Box2D Lite源码 - Erin Catto（完整的教学级物理引擎）
- [ ] 《Game Physics Pearls》- Gino van den Bergen
- [ ] Erin Catto GDC 2005:《Iterative Dynamics with Temporal Coherence》
- [ ] Erin Catto GDC 2006:《Fast and Simple Physics using Sequential Impulses》
- [ ] 《Position Based Dynamics》- Müller et al. 2007
- [ ] 《Physics for Game Developers》- David Bourg（Chapter 11-13）
- [ ] Bullet Physics手册 - Sequential Impulse Solver原理

---

#### 核心概念

**物理模拟流水线**
```
┌─────────────────────────────────────────────────────────────┐
│                    物理更新完整流程                            │
└─────────────────────────────────────────────────────────────┘
        │
        ▼
┌────────────────────┐
│ 1. 应用外力        │ ──▶ 并行：每个物体独立
│   (重力、风力、弹簧)│     GPU友好：纯数据并行
└────────────────────┘
        │
        ▼
┌────────────────────┐
│ 2. 半隐式欧拉积分  │ ──▶ 并行：每个物体独立
│   v += (F/m) * dt  │     SIMD：8物体/AVX
│   p += v * dt      │
└────────────────────┘
        │
        ▼
┌────────────────────┐
│ 3. 更新AABB        │ ──▶ 并行：每个物体独立
│   worldAABB =      │
│   localAABB + pos  │
└────────────────────┘
        │
        ▼
┌────────────────────┐
│ 4. 宽相位碰撞      │ ──▶ 并行：空间分区并行
│   (均匀网格/BVH)   │     输出：候选碰撞对
└────────────────────┘
        │ 过滤率95-99%
        ▼
┌────────────────────┐
│ 5. 窄相位碰撞      │ ──▶ 并行：每个碰撞对独立
│   (GJK/SAT)        │     输出：ContactManifold
│   + 流形缓存       │
└────────────────────┘
        │
        ▼
┌────────────────────┐
│ 6. 约束求解        │ ──▶ 顺序迭代（或着色并行）
│   Sequential       │     warm starting关键
│   Impulse Solver   │     4-8次迭代
└────────────────────┘
        │
        ▼
┌────────────────────┐
│ 7. 位置修正        │ ──▶ 并行（或集成在求解器中）
│   Baumgarte / NGS  │     防止穿透积累
└────────────────────┘
        │
        ▼
┌────────────────────┐
│ 8. 休眠检测        │ ──▶ 并行：每个岛独立
│   岛检测 + 休眠    │     不活跃物体进入休眠
└────────────────────┘
```

---

#### 4.1 Sequential Impulse约束求解器

```cpp
// ==========================================
// Sequential Impulse（顺序冲量）求解器
// ==========================================
//
// Sequential Impulse是现代物理引擎的标准约束求解方法。
// Box2D、Bullet、PhysX都使用这种方法的变体。
//
// 核心思想：
//   碰撞约束 = "两物体不应穿透"
//   用冲量（impulse）修正速度来满足约束
//   多个约束时，逐个迭代求解（Gauss-Seidel方式）
//
// 数学推导：
//   设相对速度 vn = (vB - vA) · n（法向分量）
//   碰撞约束：vn >= 0（物体不应穿透）
//   如果vn < 0（正在穿透），需要施加冲量j：
//     j = -(1 + e) * vn / (1/mA + 1/mB)
//   其中e是恢复系数（弹性）
//
// Warm Starting：
//   用上一帧的冲量作为本帧的初始猜测。
//   这使得迭代从一个好的起点开始，
//   通常4次迭代就能达到良好效果。
//
// 关键洞察（Erin Catto）：
//   "Sequential Impulses with warm starting is equivalent to
//    projected Gauss-Seidel applied to the LCP formulation."

#include <vector>
#include <cstdint>
#include <cmath>
#include <algorithm>

namespace physics::solver {

// 求解器使用的接触约束数据——DOD风格
// 所有数据按约束索引对齐，SoA布局
struct ConstraintData {
    // 物体索引
    std::vector<uint32_t> bodyA, bodyB;

    // 接触法线（世界空间）
    std::vector<float> normalX, normalY, normalZ;

    // 接触点相对于质心的偏移
    std::vector<float> rAX, rAY, rAZ;  // contactPoint - posA
    std::vector<float> rBX, rBY, rBZ;  // contactPoint - posB

    // 材质属性
    std::vector<float> restitution;
    std::vector<float> friction;

    // 穿透深度
    std::vector<float> penetration;

    // 预计算的有效质量（逆）
    std::vector<float> normalMassInv;  // 1 / (1/mA + 1/mB + angular terms)
    std::vector<float> tangentMassInvX;
    std::vector<float> tangentMassInvY;

    // 累积冲量（warm starting + 本帧迭代）
    std::vector<float> normalImpulse;
    std::vector<float> tangentImpulseX;
    std::vector<float> tangentImpulseY;

    // 切线方向
    std::vector<float> tangentX1, tangentY1, tangentZ1;
    std::vector<float> tangentX2, tangentY2, tangentZ2;

    size_t count() const { return bodyA.size(); }

    void clear() {
        bodyA.clear(); bodyB.clear();
        normalX.clear(); normalY.clear(); normalZ.clear();
        rAX.clear(); rAY.clear(); rAZ.clear();
        rBX.clear(); rBY.clear(); rBZ.clear();
        restitution.clear(); friction.clear(); penetration.clear();
        normalMassInv.clear(); tangentMassInvX.clear(); tangentMassInvY.clear();
        normalImpulse.clear(); tangentImpulseX.clear(); tangentImpulseY.clear();
        tangentX1.clear(); tangentY1.clear(); tangentZ1.clear();
        tangentX2.clear(); tangentY2.clear(); tangentZ2.clear();
    }
};

class SequentialImpulseSolver {
    ConstraintData constraints_;
    int iterations_ = 4;

public:
    void setIterations(int iters) { iterations_ = iters; }

    // 预处理：从ContactManifold构建约束数据
    void prepare(
        const float* posX, const float* posY, const float* posZ,
        const float* velX, const float* velY, const float* velZ,
        const float* invMass,
        // contacts来自窄相位
        const uint32_t* contactBodyA, const uint32_t* contactBodyB,
        const float* contactNX, const float* contactNY, const float* contactNZ,
        const float* contactPosX, const float* contactPosY, const float* contactPosZ,
        const float* contactPenetration,
        const float* contactRestitution, const float* contactFriction,
        const float* warmNormalImpulse,
        size_t contactCount,
        float dt)
    {
        constraints_.clear();

        for (size_t i = 0; i < contactCount; ++i) {
            uint32_t a = contactBodyA[i];
            uint32_t b = contactBodyB[i];

            constraints_.bodyA.push_back(a);
            constraints_.bodyB.push_back(b);

            constraints_.normalX.push_back(contactNX[i]);
            constraints_.normalY.push_back(contactNY[i]);
            constraints_.normalZ.push_back(contactNZ[i]);

            // 相对偏移
            constraints_.rAX.push_back(contactPosX[i] - posX[a]);
            constraints_.rAY.push_back(contactPosY[i] - posY[a]);
            constraints_.rAZ.push_back(contactPosZ[i] - posZ[a]);
            constraints_.rBX.push_back(contactPosX[i] - posX[b]);
            constraints_.rBY.push_back(contactPosY[i] - posY[b]);
            constraints_.rBZ.push_back(contactPosZ[i] - posZ[b]);

            constraints_.restitution.push_back(contactRestitution[i]);
            constraints_.friction.push_back(contactFriction[i]);
            constraints_.penetration.push_back(contactPenetration[i]);

            // 有效质量（简化：忽略角动量项）
            float kn = invMass[a] + invMass[b];
            constraints_.normalMassInv.push_back(kn > 0 ? 1.0f / kn : 0.0f);
            constraints_.tangentMassInvX.push_back(kn > 0 ? 1.0f / kn : 0.0f);
            constraints_.tangentMassInvY.push_back(kn > 0 ? 1.0f / kn : 0.0f);

            // warm starting：继承上一帧的冲量
            constraints_.normalImpulse.push_back(warmNormalImpulse ? warmNormalImpulse[i] : 0.0f);
            constraints_.tangentImpulseX.push_back(0.0f);
            constraints_.tangentImpulseY.push_back(0.0f);

            // 计算切线方向
            float nx = contactNX[i], ny = contactNY[i], nz = contactNZ[i];
            float tx, ty, tz;
            if (std::abs(nx) < 0.9f) {
                tx = 0; ty = -nz; tz = ny;
            } else {
                tx = nz; ty = 0; tz = -nx;
            }
            float tlen = std::sqrt(tx*tx + ty*ty + tz*tz);
            if (tlen > 1e-6f) { tx /= tlen; ty /= tlen; tz /= tlen; }

            constraints_.tangentX1.push_back(tx);
            constraints_.tangentY1.push_back(ty);
            constraints_.tangentZ1.push_back(tz);

            // 第二切线 = normal × tangent1
            constraints_.tangentX2.push_back(ny*tz - nz*ty);
            constraints_.tangentY2.push_back(nz*tx - nx*tz);
            constraints_.tangentZ2.push_back(nx*ty - ny*tx);
        }
    }

    // 应用warm starting
    void warmStart(float* velX, float* velY, float* velZ,
                   const float* invMass) {
        for (size_t i = 0; i < constraints_.count(); ++i) {
            uint32_t a = constraints_.bodyA[i];
            uint32_t b = constraints_.bodyB[i];

            float jn = constraints_.normalImpulse[i];
            float nx = constraints_.normalX[i];
            float ny = constraints_.normalY[i];
            float nz = constraints_.normalZ[i];

            velX[a] -= nx * jn * invMass[a];
            velY[a] -= ny * jn * invMass[a];
            velZ[a] -= nz * jn * invMass[a];

            velX[b] += nx * jn * invMass[b];
            velY[b] += ny * jn * invMass[b];
            velZ[b] += nz * jn * invMass[b];
        }
    }

    // 迭代求解
    void solve(float* velX, float* velY, float* velZ,
               const float* invMass) {
        for (int iter = 0; iter < iterations_; ++iter) {
            for (size_t i = 0; i < constraints_.count(); ++i) {
                solveContact(i, velX, velY, velZ, invMass);
            }
        }
    }

private:
    void solveContact(size_t idx,
                      float* velX, float* velY, float* velZ,
                      const float* invMass) {
        uint32_t a = constraints_.bodyA[idx];
        uint32_t b = constraints_.bodyB[idx];
        float nx = constraints_.normalX[idx];
        float ny = constraints_.normalY[idx];
        float nz = constraints_.normalZ[idx];

        // 相对速度
        float dvx = velX[b] - velX[a];
        float dvy = velY[b] - velY[a];
        float dvz = velZ[b] - velZ[a];

        // ── 法向约束 ──
        float vn = dvx * nx + dvy * ny + dvz * nz;

        // 计算法向冲量增量
        float e = constraints_.restitution[idx];
        float dj = -(1 + e) * vn * constraints_.normalMassInv[idx];

        // 冲量钳位（clamp）：法向冲量只能是推力（>= 0）
        float oldImpulse = constraints_.normalImpulse[idx];
        constraints_.normalImpulse[idx] = std::max(0.0f, oldImpulse + dj);
        dj = constraints_.normalImpulse[idx] - oldImpulse;

        // 应用法向冲量
        velX[a] -= nx * dj * invMass[a];
        velY[a] -= ny * dj * invMass[a];
        velZ[a] -= nz * dj * invMass[a];
        velX[b] += nx * dj * invMass[b];
        velY[b] += ny * dj * invMass[b];
        velZ[b] += nz * dj * invMass[b];

        // ── 切向约束（摩擦力） ──
        dvx = velX[b] - velX[a];
        dvy = velY[b] - velY[a];
        dvz = velZ[b] - velZ[a];

        float tx1 = constraints_.tangentX1[idx];
        float ty1 = constraints_.tangentY1[idx];
        float tz1 = constraints_.tangentZ1[idx];

        float vt1 = dvx * tx1 + dvy * ty1 + dvz * tz1;
        float djt1 = -vt1 * constraints_.tangentMassInvX[idx];

        // 库仑摩擦锥：|摩擦冲量| <= μ * |法向冲量|
        float maxFriction = constraints_.friction[idx] * constraints_.normalImpulse[idx];
        float oldTangent = constraints_.tangentImpulseX[idx];
        constraints_.tangentImpulseX[idx] = std::clamp(
            oldTangent + djt1, -maxFriction, maxFriction);
        djt1 = constraints_.tangentImpulseX[idx] - oldTangent;

        velX[a] -= tx1 * djt1 * invMass[a];
        velY[a] -= ty1 * djt1 * invMass[a];
        velZ[a] -= tz1 * djt1 * invMass[a];
        velX[b] += tx1 * djt1 * invMass[b];
        velY[b] += ty1 * djt1 * invMass[b];
        velZ[b] += tz1 * djt1 * invMass[b];
    }
};

} // namespace physics::solver
```

---

#### 4.2 位置修正——Baumgarte稳定化

```cpp
// ==========================================
// Baumgarte稳定化 vs NGS位置修正
// ==========================================
//
// 问题：速度求解器只修正速度，不直接修正位置。
//   穿透的物体可能以正确的速度分离，但它们仍然重叠！
//   每帧的微小数值误差会导致穿透不断积累。
//
// Baumgarte方法：
//   将穿透误差"注入"到速度约束中：
//   vn >= β/dt * penetration
//   其中β是Baumgarte因子（通常0.1-0.3）
//
//   直觉：如果物体穿透了d距离，额外施加一个"分离速度"
//   使它们在dt时间内修正β比例的穿透。
//
// NGS（Non-linear Gauss-Seidel）/ Split Impulse：
//   Bullet使用的方法。
//   在速度求解之后，单独做一次"位置求解"：
//   直接修正位置，而不是通过速度间接修正。
//   优点：物理行为更准确（弹跳更自然）
//   缺点：额外的求解步骤
//
// Box2D使用Baumgarte，Bullet使用Split Impulse。

#include <vector>
#include <cmath>
#include <algorithm>

namespace physics::solver {

// Baumgarte位置修正——集成在速度求解器中
void applyBaumgarte(
    float* velX, float* velY, float* velZ,
    const float* invMass,
    const uint32_t* bodyA, const uint32_t* bodyB,
    const float* normalX, const float* normalY, const float* normalZ,
    const float* penetration,
    size_t constraintCount,
    float dt, float beta = 0.2f, float slop = 0.005f)
{
    float invDt = (dt > 0) ? 1.0f / dt : 0.0f;

    for (size_t i = 0; i < constraintCount; ++i) {
        uint32_t a = bodyA[i];
        uint32_t b = bodyB[i];

        // 只修正超过slop的穿透
        // slop允许微小穿透，防止抖动
        float correctionMag = std::max(penetration[i] - slop, 0.0f);
        float bias = beta * invDt * correctionMag;

        float effectiveMass = invMass[a] + invMass[b];
        if (effectiveMass <= 0) continue;

        float impulse = bias / effectiveMass;

        velX[a] -= normalX[i] * impulse * invMass[a];
        velY[a] -= normalY[i] * impulse * invMass[a];
        velZ[a] -= normalZ[i] * impulse * invMass[a];

        velX[b] += normalX[i] * impulse * invMass[b];
        velY[b] += normalY[i] * impulse * invMass[b];
        velZ[b] += normalZ[i] * impulse * invMass[b];
    }
}

// NGS位置修正——直接修改位置
void applyPositionCorrection(
    float* posX, float* posY, float* posZ,
    const float* invMass,
    const uint32_t* bodyA, const uint32_t* bodyB,
    const float* normalX, const float* normalY, const float* normalZ,
    const float* penetration,
    size_t constraintCount,
    float percent = 0.8f, float slop = 0.005f)
{
    for (size_t i = 0; i < constraintCount; ++i) {
        uint32_t a = bodyA[i];
        uint32_t b = bodyB[i];

        float correctionMag = std::max(penetration[i] - slop, 0.0f);
        float effectiveMass = invMass[a] + invMass[b];
        if (effectiveMass <= 0) continue;

        float correction = correctionMag * percent / effectiveMass;

        posX[a] -= normalX[i] * correction * invMass[a];
        posY[a] -= normalY[i] * correction * invMass[a];
        posZ[a] -= normalZ[i] * correction * invMass[a];

        posX[b] += normalX[i] * correction * invMass[b];
        posY[b] += normalY[i] * correction * invMass[b];
        posZ[b] += normalZ[i] * correction * invMass[b];
    }
}

} // namespace physics::solver
```

---

#### 4.3 岛检测与休眠系统

```cpp
// ==========================================
// 岛检测（Island Detection）与休眠
// ==========================================
//
// 物理世界中，很多物体是独立的——修改A不影响B。
// 通过碰撞图将物体分成"岛"（Island），
// 每个岛内的物体互相影响，不同岛完全独立。
//
// 岛的好处：
//   1. 独立的岛可以并行求解
//   2. 静止的岛可以整体休眠，跳过所有计算
//   3. 减少约束求解器的矩阵大小
//
// 休眠条件（典型）：
//   - 线速度 < threshold（通常0.01 m/s）
//   - 角速度 < threshold
//   - 持续时间 > sleepDelay（通常0.5s）
//   - 岛内所有物体都满足上述条件
//
// 唤醒条件：
//   - 外力施加
//   - 用户直接设置位置/速度
//   - 新碰撞进入（非休眠物体碰到休眠物体）

#include <vector>
#include <cstdint>

namespace physics::solver {

class IslandDetector {
public:
    // 使用Union-Find（并查集）检测岛
    struct UnionFind {
        std::vector<uint32_t> parent;
        std::vector<uint32_t> rank;

        void init(size_t n) {
            parent.resize(n);
            rank.resize(n, 0);
            for (size_t i = 0; i < n; ++i) parent[i] = static_cast<uint32_t>(i);
        }

        uint32_t find(uint32_t x) {
            while (parent[x] != x) {
                parent[x] = parent[parent[x]];  // 路径压缩
                x = parent[x];
            }
            return x;
        }

        void unite(uint32_t a, uint32_t b) {
            a = find(a); b = find(b);
            if (a == b) return;
            // 按秩合并
            if (rank[a] < rank[b]) std::swap(a, b);
            parent[b] = a;
            if (rank[a] == rank[b]) ++rank[a];
        }
    };

    struct Island {
        std::vector<uint32_t> bodies;
        bool canSleep;
    };

    // 从碰撞对构建岛
    std::vector<Island> detectIslands(
        size_t bodyCount,
        const std::pair<uint32_t, uint32_t>* pairs,
        size_t pairCount,
        const float* velX, const float* velY, const float* velZ,
        const float* invMass,
        float sleepThreshold = 0.01f)
    {
        UnionFind uf;
        uf.init(bodyCount);

        // 合并碰撞对的物体
        for (size_t i = 0; i < pairCount; ++i) {
            uf.unite(pairs[i].first, pairs[i].second);
        }

        // 按岛根分组
        std::vector<std::vector<uint32_t>> islandBodies(bodyCount);
        for (size_t i = 0; i < bodyCount; ++i) {
            if (invMass[i] > 0) {  // 跳过静态物体
                uint32_t root = uf.find(static_cast<uint32_t>(i));
                islandBodies[root].push_back(static_cast<uint32_t>(i));
            }
        }

        // 构建岛列表
        std::vector<Island> islands;
        for (auto& bodies : islandBodies) {
            if (bodies.empty()) continue;

            Island island;
            island.bodies = std::move(bodies);

            // 检查是否可以休眠
            island.canSleep = true;
            for (uint32_t b : island.bodies) {
                float speedSq = velX[b]*velX[b] + velY[b]*velY[b] + velZ[b]*velZ[b];
                if (speedSq > sleepThreshold * sleepThreshold) {
                    island.canSleep = false;
                    break;
                }
            }

            islands.push_back(std::move(island));
        }

        return islands;
    }
};

// 休眠管理器
class SleepManager {
    std::vector<float> sleepTimer_;      // 每个物体的休眠计时器
    std::vector<bool> sleeping_;          // 是否在休眠

public:
    void init(size_t bodyCount) {
        sleepTimer_.resize(bodyCount, 0.0f);
        sleeping_.resize(bodyCount, false);
    }

    void update(const std::vector<IslandDetector::Island>& islands,
                float dt, float sleepDelay = 0.5f) {
        for (const auto& island : islands) {
            if (island.canSleep) {
                bool allReady = true;
                for (uint32_t b : island.bodies) {
                    sleepTimer_[b] += dt;
                    if (sleepTimer_[b] < sleepDelay) {
                        allReady = false;
                    }
                }
                if (allReady) {
                    for (uint32_t b : island.bodies) {
                        sleeping_[b] = true;
                    }
                }
            } else {
                // 岛不满足休眠条件——重置计时器并唤醒
                for (uint32_t b : island.bodies) {
                    sleepTimer_[b] = 0.0f;
                    sleeping_[b] = false;
                }
            }
        }
    }

    bool isSleeping(uint32_t body) const { return sleeping_[body]; }

    void wakeUp(uint32_t body) {
        sleeping_[body] = false;
        sleepTimer_[body] = 0.0f;
    }
};

} // namespace physics::solver
```

---

#### 4.4 连续碰撞检测（CCD）基础

```cpp
// ==========================================
// 连续碰撞检测（Continuous Collision Detection）
// ==========================================
//
// 问题：离散碰撞检测在两帧之间不检查碰撞。
//   如果物体速度很高（如子弹），可能在一帧内完全穿过障碍物。
//   这就是"隧道效应"（Tunneling）。
//
// CCD解决方案：
//   检测物体在[t, t+dt]时间段内是否碰撞。
//   如果碰撞，计算"首次碰撞时间"（Time of Impact, TOI）。
//
// 常用方法：
//   1. 球体扫掠（Sphere Sweep）：将球体沿运动路径扩展
//   2. 射线检测（Raycast）：将小物体近似为射线
//   3. Conservative Advancement：逐步逼近TOI
//   4. GJK-based TOI：Erin Catto的方法（Box2D使用）
//
// 这里实现最简单的球体扫掠检测。

#include <cmath>
#include <algorithm>

namespace physics::solver {

struct CCDResult {
    bool hit;
    float toi;         // Time of Impact [0, 1]，0=帧开始，1=帧结束
    float hitX, hitY, hitZ;  // 碰撞点
    float normalX, normalY, normalZ;  // 碰撞法线
};

// 球体vs静态球体的扫掠检测
// 将运动球体A（半径rA，从posA以速度velA运动）
// 与静态球体B（半径rB，位于posB）做碰撞检测
//
// 数学：求解二次方程
//   |posA + t*velA - posB|² = (rA + rB)²
//   展开：|d + t*v|² = r²
//   其中 d = posA - posB, v = velA, r = rA + rB
//   → v·v * t² + 2*d·v * t + d·d - r² = 0

CCDResult sweepSphereVsSphere(
    float posAX, float posAY, float posAZ,
    float velAX, float velAY, float velAZ,
    float radiusA,
    float posBX, float posBY, float posBZ,
    float radiusB)
{
    CCDResult result{false, 1.0f, 0, 0, 0, 0, 0, 0};

    float dx = posAX - posBX;
    float dy = posAY - posBY;
    float dz = posAZ - posBZ;

    float a = velAX*velAX + velAY*velAY + velAZ*velAZ;
    float b = 2.0f * (dx*velAX + dy*velAY + dz*velAZ);
    float c = dx*dx + dy*dy + dz*dz -
              (radiusA + radiusB) * (radiusA + radiusB);

    // 判别式
    float discriminant = b*b - 4*a*c;
    if (discriminant < 0 || a < 1e-10f) return result;

    float sqrtDisc = std::sqrt(discriminant);
    float t = (-b - sqrtDisc) / (2 * a);

    if (t >= 0 && t <= 1.0f) {
        result.hit = true;
        result.toi = t;

        // 碰撞时A的位置
        result.hitX = posAX + velAX * t;
        result.hitY = posAY + velAY * t;
        result.hitZ = posAZ + velAZ * t;

        // 碰撞法线（从B到A）
        float nx = result.hitX - posBX;
        float ny = result.hitY - posBY;
        float nz = result.hitZ - posBZ;
        float len = std::sqrt(nx*nx + ny*ny + nz*nz);
        if (len > 1e-6f) {
            result.normalX = nx / len;
            result.normalY = ny / len;
            result.normalZ = nz / len;
        }
    }

    return result;
}

} // namespace physics::solver
```

---

#### 4.5 性能剖析与调优

```
物理引擎性能剖析方法论
═══════════════════════

第一步：确定瓶颈类型
──────────────────────
  物理引擎瓶颈通常是以下之一：
  1. 计算瓶颈（CPU cycles）→ 约束求解器
  2. 内存带宽瓶颈（cache miss）→ 宽相位遍历
  3. 同步瓶颈（lock contention）→ 多线程碰撞检测
  4. 分支预测失败 → 碰撞器类型派发

  快速诊断命令：
    perf stat -d ./physics_engine

  关键指标：
    IPC (Instructions Per Cycle)：
      > 2.0 → 计算密集，优化算法
      < 1.0 → 内存密集，优化数据布局
    L1-miss rate > 5% → 数据布局问题
    branch-miss rate > 3% → 分支预测问题

第二步：各阶段计时
──────────────────
  在代码中插入精确计时点：

  using Clock = std::chrono::high_resolution_clock;

  auto t0 = Clock::now();
  applyGravity();
  auto t1 = Clock::now();
  broadPhase();
  auto t2 = Clock::now();
  narrowPhase();
  auto t3 = Clock::now();
  solve();
  auto t4 = Clock::now();

  典型比例（10000物体，4x求解迭代）：
    重力+积分：5%
    宽相位：  15%
    窄相位：  30%
    约束求解：45%
    其他：    5%

第三步：针对性优化
──────────────────
  宽相位慢 → 检查空间数据结构选择、网格参数
  窄相位慢 → 检查碰撞器类型排序、SIMD利用率
  求解器慢 → 检查迭代次数、warm starting效果
  内存慢  → 检查SoA布局、对齐、预取

第四步：验证优化效果
───────────────────
  优化前后对比，确保：
  1. 物理行为不变（帧间差异<epsilon）
  2. 性能提升可测量（>5%才有意义）
  3. 不同场景都有效（不是只优化了基准测试）
```

---

#### 4.6 完整物理引擎步进函数

```cpp
// ==========================================
// 将所有组件集成为完整的物理步进
// ==========================================

#include <chrono>
#include <iostream>

namespace physics {

struct StepProfile {
    double gravityMs;
    double integrateMs;
    double broadPhaseMs;
    double narrowPhaseMs;
    double solveMs;
    double positionCorrectionMs;
    double totalMs;
};

// 完整的物理步进——集成所有子系统
void physicsStep(
    // 刚体数据（SoA）
    float* posX, float* posY, float* posZ,
    float* velX, float* velY, float* velZ,
    float* forceX, float* forceY, float* forceZ,
    float* invMass,
    // AABB数据
    float* aabbMinX, float* aabbMinY, float* aabbMinZ,
    float* aabbMaxX, float* aabbMaxY, float* aabbMaxZ,
    // 碰撞器数据
    const float* radii,
    const float* restitution, const float* friction,
    size_t bodyCount,
    float dt, float gravityY,
    StepProfile& profile)
{
    using Clock = std::chrono::high_resolution_clock;
    auto t0 = Clock::now();

    // 1. 应用重力
    for (size_t i = 0; i < bodyCount; ++i) {
        if (invMass[i] > 0) {
            forceY[i] += gravityY / invMass[i];
        }
    }
    auto t1 = Clock::now();

    // 2. 积分（半隐式欧拉）
    for (size_t i = 0; i < bodyCount; ++i) {
        if (invMass[i] == 0) continue;
        velX[i] += forceX[i] * invMass[i] * dt;
        velY[i] += forceY[i] * invMass[i] * dt;
        velZ[i] += forceZ[i] * invMass[i] * dt;
        posX[i] += velX[i] * dt;
        posY[i] += velY[i] * dt;
        posZ[i] += velZ[i] * dt;
    }
    auto t2 = Clock::now();

    // 3. 更新AABB
    for (size_t i = 0; i < bodyCount; ++i) {
        float r = radii[i];
        aabbMinX[i] = posX[i] - r; aabbMinY[i] = posY[i] - r; aabbMinZ[i] = posZ[i] - r;
        aabbMaxX[i] = posX[i] + r; aabbMaxY[i] = posY[i] + r; aabbMaxZ[i] = posZ[i] + r;
    }

    // 4-7. 碰撞检测与求解（使用前几周实现的子系统）
    // ... 省略具体调用，见实践项目中的PhysicsWorld

    auto tEnd = Clock::now();

    // 8. 清除力
    std::fill(forceX, forceX + bodyCount, 0.0f);
    std::fill(forceY, forceY + bodyCount, 0.0f);
    std::fill(forceZ, forceZ + bodyCount, 0.0f);

    // 记录性能
    profile.gravityMs = std::chrono::duration<double, std::milli>(t1 - t0).count();
    profile.integrateMs = std::chrono::duration<double, std::milli>(t2 - t1).count();
    profile.totalMs = std::chrono::duration<double, std::milli>(tEnd - t0).count();
}

} // namespace physics
```

---

#### 4.7 物理引擎架构总结

```
物理引擎架构全景
══════════════════

                    ┌─────────────────────────┐
                    │    PhysicsWorld          │
                    │  - config (gravity, dt)  │
                    │  - step()               │
                    │  - createBody()         │
                    └─────────┬───────────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
    ┌─────────▼─────────┐ ┌──▼──────────┐ ┌──▼───────────┐
    │  RigidBodySystem  │ │  Collision   │ │  Constraint  │
    │  (SoA数据)         │ │  Pipeline    │ │  Solver      │
    │  - pos/vel/force  │ │              │ │              │
    │  - mass/inertia   │ │  - BroadPhase│ │  - Sequential│
    │  - AABB           │ │  - NarrowPhase││    Impulse   │
    │  - colliders      │ │  - Manifold  │ │  - Baumgarte │
    └───────────────────┘ │    Cache     │ │  - Warm Start│
                          └──────────────┘ └──────────────┘

    ┌─────────────────────────────────────────────────────┐
    │                   Threading Layer                     │
    │  ThreadPool / JobSystem / Work Stealing              │
    │  parallelFor / LockFreePairCollector / SPSC Queue   │
    └─────────────────────────────────────────────────────┘

    ┌─────────────────────────────────────────────────────┐
    │                   Spatial Structures                  │
    │  UniformGrid / BVH / SpatialHash / SAP              │
    │  Morton Codes / Linear Octree                       │
    └─────────────────────────────────────────────────────┘

    DOD原则贯穿所有层次：
    ✓ SoA数据布局——每个组件的数据连续存储
    ✓ 按类型批量处理——消除分支，最大化SIMD
    ✓ 缓存行对齐——避免伪共享
    ✓ 无指针追踪——索引代替指针
    ✓ 预分配内存——无运行时分配
```

---

#### 4.8 本周练习任务

```
练习1：Sequential Impulse求解器实现
─────────────────────────────────
目标：实现完整的SI约束求解器，支持碰撞和摩擦

要求：
1. 实现法向约束求解（冲量钳位 >= 0）
2. 实现切向约束求解（库仑摩擦锥）
3. 实现warm starting（从上一帧继承冲量）
4. 测试：10个球落在地面上，观察弹跳和最终静止

验证：
- 球应该弹跳几次后停止（不应持续抖动）
- warm starting应使迭代次数从20+降到4-8
- 堆叠3个球体应稳定（不崩塌）

练习2：位置修正对比
─────────────────
目标：对比Baumgarte和NGS位置修正方法

要求：
1. 实现Baumgarte稳定化（β=0.2, slop=0.005）
2. 实现NGS直接位置修正
3. 场景：100个球掉入容器
4. 对比：穿透深度统计、视觉效果、性能

验证：
- Baumgarte：可能有微小抖动，但更快
- NGS：穿透更少，但每帧多一次求解步骤
- 两者的最大穿透深度应<0.01m

练习3：岛检测与休眠系统
────────────────────
目标：实现岛检测并用休眠系统优化性能

要求：
1. 用Union-Find实现岛检测
2. 实现休眠系统（阈值+延迟+唤醒）
3. 场景：1000个球分散在世界中，大部分逐渐静止
4. 测量有/无休眠时的每帧计算时间

验证：
- 90%物体静止后，有休眠应比无休眠快5-10倍
- 新物体碰到休眠物体应正确唤醒
- 休眠物体不应穿入地面

练习4：完整物理引擎基准测试
─────────────────────────
目标：搭建完整引擎并进行全链路性能测试

要求：
1. 集成所有组件：刚体系统、碰撞检测流水线、约束求解器
2. 场景A：1000球自由落体+碰撞
3. 场景B：10000球均匀分布随机运动
4. 输出每帧各阶段耗时报告

验证：
- 1000球@60FPS：总帧时<16.6ms
- 10000球：分析瓶颈在哪个阶段
- 约束求解器应占40-50%的总时间
```

---

#### 4.9 本周知识检验

```
思考题1：Sequential Impulse求解器中，为什么法向冲量要钳位（clamp）为>=0？
         如果允许负的法向冲量（拉力），物理行为会怎样？
         什么场景下需要允许负冲量？（提示：关节约束）

思考题2：Baumgarte因子β的选择是一个权衡：
         β太大 → 抖动，因为过度修正
         β太小 → 穿透积累，因为修正不足
         如何自适应地调整β？有没有理论最优值？

思考题3：岛检测使用Union-Find算法，时间复杂度几乎是O(n)。
         但如果物理世界是"一个大岛"（所有物体通过碰撞链相连），
         休眠系统就无法工作。在什么类型的游戏中这是个问题？
         如何解决？

思考题4：CCD（连续碰撞检测）通常只对高速物体启用，低速物体使用离散检测。
         如何设计"自动CCD触发器"——根据物体速度和大小判断是否需要CCD？
         阈值应该怎么计算？

思考题5：游戏物理引擎（Box2D/Bullet）和科学计算物理模拟（OpenFOAM/LAMMPS）
         在约束求解器设计上有根本差异。游戏引擎追求"看起来对"，
         科学模拟追求"数值精确"。这导致了哪些具体的设计选择差异？

实践题1：
  Sequential Impulse求解器的收敛速度分析：
  两个质量为1kg的球体，相对速度10m/s正面碰撞，e=0.5。
  (a) 手工计算精确解的碰撞后速度
  (b) SI求解器1次迭代后的速度是多少？
  (c) 4次迭代后呢？
  (d) 需要多少次迭代才能收敛到精确解的1%误差内？

实践题2：
  Amdahl定律在物理引擎中的应用：
  你的引擎在单线程下profile结果：
    积分：2ms（完全可并行）
    宽相位：3ms（90%可并行）
    窄相位：5ms（95%可并行）
    求解器：8ms（只有在island-parallel时50%可并行）
    总计：18ms

  (a) 8线程的理论最小帧时间是多少？
  (b) 如果引擎需要达到60FPS（16.6ms帧时），目前可以支持多少物体？
  (c) 如果求解器改进为80%可并行，帧时改善多少？
```

## 源码阅读任务

### 必读项目

1. **Box2D** (https://github.com/erincatto/box2d)
   - 重点文件：`src/collision/`, `src/dynamics/`
   - 学习目标：理解2D物理引擎架构
   - 阅读时间：12小时

2. **Bullet Physics** (https://github.com/bulletphysics/bullet3)
   - 重点文件：`src/BulletCollision/`
   - 学习目标：理解3D碰撞检测实现
   - 阅读时间：10小时

3. **ReactPhysics3D** (https://github.com/DanielChappworthy/reactphysics3d)
   - 重点：现代C++物理引擎设计
   - 阅读时间：6小时

---

## 实践项目：高性能物理引擎核心

### 项目概述
构建一个高性能的2D/3D物理引擎核心，实现完整的碰撞检测和响应系统，支持多线程并行处理。

### 完整代码实现

#### 1. 数学库 (physics/math/math_types.hpp)

```cpp
#pragma once

#include <cmath>
#include <algorithm>

#ifdef __AVX__
#include <immintrin.h>
#endif

namespace physics {

struct Vec3 {
    float x, y, z;

    Vec3() : x(0), y(0), z(0) {}
    Vec3(float x, float y, float z) : x(x), y(y), z(z) {}

    Vec3 operator+(const Vec3& v) const { return {x + v.x, y + v.y, z + v.z}; }
    Vec3 operator-(const Vec3& v) const { return {x - v.x, y - v.y, z - v.z}; }
    Vec3 operator*(float s) const { return {x * s, y * s, z * s}; }
    Vec3 operator/(float s) const { return {x / s, y / s, z / s}; }
    Vec3& operator+=(const Vec3& v) { x += v.x; y += v.y; z += v.z; return *this; }
    Vec3& operator-=(const Vec3& v) { x -= v.x; y -= v.y; z -= v.z; return *this; }
    Vec3& operator*=(float s) { x *= s; y *= s; z *= s; return *this; }

    float dot(const Vec3& v) const { return x * v.x + y * v.y + z * v.z; }
    Vec3 cross(const Vec3& v) const {
        return {y * v.z - z * v.y, z * v.x - x * v.z, x * v.y - y * v.x};
    }
    float lengthSq() const { return dot(*this); }
    float length() const { return std::sqrt(lengthSq()); }
    Vec3 normalized() const {
        float len = length();
        return len > 0 ? *this / len : Vec3{};
    }

    static Vec3 min(const Vec3& a, const Vec3& b) {
        return {std::min(a.x, b.x), std::min(a.y, b.y), std::min(a.z, b.z)};
    }
    static Vec3 max(const Vec3& a, const Vec3& b) {
        return {std::max(a.x, b.x), std::max(a.y, b.y), std::max(a.z, b.z)};
    }
};

struct AABB {
    Vec3 min, max;

    AABB() = default;
    AABB(const Vec3& min, const Vec3& max) : min(min), max(max) {}

    Vec3 center() const { return (min + max) * 0.5f; }
    Vec3 extents() const { return (max - min) * 0.5f; }

    bool overlaps(const AABB& other) const {
        return min.x <= other.max.x && max.x >= other.min.x &&
               min.y <= other.max.y && max.y >= other.min.y &&
               min.z <= other.max.z && max.z >= other.min.z;
    }

    AABB expanded(float margin) const {
        return {min - Vec3{margin, margin, margin},
                max + Vec3{margin, margin, margin}};
    }

    static AABB fromCenterExtents(const Vec3& center, const Vec3& extents) {
        return {center - extents, center + extents};
    }
};

struct Transform {
    Vec3 position;
    // 简化：只用四元数的旋转，这里用欧拉角简化
    Vec3 rotation;
    Vec3 scale{1, 1, 1};

    Vec3 transformPoint(const Vec3& p) const {
        // 简化实现
        return position + Vec3{p.x * scale.x, p.y * scale.y, p.z * scale.z};
    }
};

} // namespace physics
```

#### 2. 刚体系统 (physics/dynamics/rigid_body_system.hpp)

```cpp
#pragma once

#include "../math/math_types.hpp"
#include <vector>
#include <cstdint>

namespace physics {

// 刚体类型
enum class BodyType : uint8_t {
    Static,     // 静态物体，不移动
    Dynamic,    // 动态物体，受力影响
    Kinematic   // 运动学物体，手动控制移动
};

// 刚体系统 - DOD风格
class RigidBodySystem {
public:
    // 位置与旋转
    std::vector<float> posX, posY, posZ;
    std::vector<float> rotX, rotY, rotZ, rotW;  // 四元数

    // 线速度与角速度
    std::vector<float> velX, velY, velZ;
    std::vector<float> angVelX, angVelY, angVelZ;

    // 力与扭矩累加器
    std::vector<float> forceX, forceY, forceZ;
    std::vector<float> torqueX, torqueY, torqueZ;

    // 质量属性
    std::vector<float> invMass;      // 逆质量（0表示无限质量/静态）
    std::vector<float> invInertiaX, invInertiaY, invInertiaZ;  // 逆惯性张量对角线

    // AABB（用于碰撞检测）
    std::vector<float> aabbMinX, aabbMinY, aabbMinZ;
    std::vector<float> aabbMaxX, aabbMaxY, aabbMaxZ;

    // 材质属性
    std::vector<float> restitution;  // 弹性系数
    std::vector<float> friction;     // 摩擦系数

    // 类型与标志
    std::vector<BodyType> bodyTypes;
    std::vector<uint32_t> flags;

    // 碰撞器索引（指向碰撞器系统）
    std::vector<uint32_t> colliderIndex;

    // 用户数据
    std::vector<void*> userData;

    size_t count() const { return posX.size(); }

    // 创建刚体
    uint32_t create(const Vec3& position, BodyType type = BodyType::Dynamic) {
        uint32_t id = static_cast<uint32_t>(count());

        posX.push_back(position.x);
        posY.push_back(position.y);
        posZ.push_back(position.z);
        rotX.push_back(0); rotY.push_back(0); rotZ.push_back(0); rotW.push_back(1);

        velX.push_back(0); velY.push_back(0); velZ.push_back(0);
        angVelX.push_back(0); angVelY.push_back(0); angVelZ.push_back(0);

        forceX.push_back(0); forceY.push_back(0); forceZ.push_back(0);
        torqueX.push_back(0); torqueY.push_back(0); torqueZ.push_back(0);

        float im = (type == BodyType::Static) ? 0.0f : 1.0f;
        invMass.push_back(im);
        invInertiaX.push_back(im);
        invInertiaY.push_back(im);
        invInertiaZ.push_back(im);

        aabbMinX.push_back(-0.5f); aabbMinY.push_back(-0.5f); aabbMinZ.push_back(-0.5f);
        aabbMaxX.push_back(0.5f); aabbMaxY.push_back(0.5f); aabbMaxZ.push_back(0.5f);

        restitution.push_back(0.3f);
        friction.push_back(0.5f);

        bodyTypes.push_back(type);
        flags.push_back(0);
        colliderIndex.push_back(UINT32_MAX);
        userData.push_back(nullptr);

        return id;
    }

    // 设置质量
    void setMass(uint32_t id, float mass) {
        if (mass <= 0 || bodyTypes[id] == BodyType::Static) {
            invMass[id] = 0;
        } else {
            invMass[id] = 1.0f / mass;
        }
    }

    // 应用力
    void applyForce(uint32_t id, const Vec3& force) {
        forceX[id] += force.x;
        forceY[id] += force.y;
        forceZ[id] += force.z;
    }

    // 应用冲量
    void applyImpulse(uint32_t id, const Vec3& impulse) {
        velX[id] += impulse.x * invMass[id];
        velY[id] += impulse.y * invMass[id];
        velZ[id] += impulse.z * invMass[id];
    }

    // 清除力累加器
    void clearForces() {
        std::fill(forceX.begin(), forceX.end(), 0.0f);
        std::fill(forceY.begin(), forceY.end(), 0.0f);
        std::fill(forceZ.begin(), forceZ.end(), 0.0f);
        std::fill(torqueX.begin(), torqueX.end(), 0.0f);
        std::fill(torqueY.begin(), torqueY.end(), 0.0f);
        std::fill(torqueZ.begin(), torqueZ.end(), 0.0f);
    }

    // 积分 - 半隐式欧拉
    void integrate(float dt) {
        const size_t n = count();

        // 并行友好的循环
        for (size_t i = 0; i < n; ++i) {
            if (invMass[i] == 0) continue;  // 跳过静态物体

            // 更新速度：v += (F/m) * dt
            velX[i] += forceX[i] * invMass[i] * dt;
            velY[i] += forceY[i] * invMass[i] * dt;
            velZ[i] += forceZ[i] * invMass[i] * dt;

            // 更新位置：p += v * dt
            posX[i] += velX[i] * dt;
            posY[i] += velY[i] * dt;
            posZ[i] += velZ[i] * dt;
        }
    }

#ifdef __AVX__
    void integrateAVX(float dt) {
        const size_t n = count();
        const __m256 vdt = _mm256_set1_ps(dt);

        size_t i = 0;
        for (; i + 8 <= n; i += 8) {
            // 加载逆质量
            __m256 im = _mm256_loadu_ps(&invMass[i]);

            // 加载力
            __m256 fx = _mm256_loadu_ps(&forceX[i]);
            __m256 fy = _mm256_loadu_ps(&forceY[i]);
            __m256 fz = _mm256_loadu_ps(&forceZ[i]);

            // 加载速度
            __m256 vx = _mm256_loadu_ps(&velX[i]);
            __m256 vy = _mm256_loadu_ps(&velY[i]);
            __m256 vz = _mm256_loadu_ps(&velZ[i]);

            // 加载位置
            __m256 px = _mm256_loadu_ps(&posX[i]);
            __m256 py = _mm256_loadu_ps(&posY[i]);
            __m256 pz = _mm256_loadu_ps(&posZ[i]);

            // 计算加速度：a = F * invMass
            __m256 ax = _mm256_mul_ps(fx, im);
            __m256 ay = _mm256_mul_ps(fy, im);
            __m256 az = _mm256_mul_ps(fz, im);

            // 更新速度：v += a * dt
            vx = _mm256_fmadd_ps(ax, vdt, vx);
            vy = _mm256_fmadd_ps(ay, vdt, vy);
            vz = _mm256_fmadd_ps(az, vdt, vz);

            // 更新位置：p += v * dt
            px = _mm256_fmadd_ps(vx, vdt, px);
            py = _mm256_fmadd_ps(vy, vdt, py);
            pz = _mm256_fmadd_ps(vz, vdt, pz);

            // 存储结果
            _mm256_storeu_ps(&velX[i], vx);
            _mm256_storeu_ps(&velY[i], vy);
            _mm256_storeu_ps(&velZ[i], vz);
            _mm256_storeu_ps(&posX[i], px);
            _mm256_storeu_ps(&posY[i], py);
            _mm256_storeu_ps(&posZ[i], pz);
        }

        // 处理剩余
        for (; i < n; ++i) {
            if (invMass[i] == 0) continue;
            velX[i] += forceX[i] * invMass[i] * dt;
            velY[i] += forceY[i] * invMass[i] * dt;
            velZ[i] += forceZ[i] * invMass[i] * dt;
            posX[i] += velX[i] * dt;
            posY[i] += velY[i] * dt;
            posZ[i] += velZ[i] * dt;
        }
    }
#endif
};

} // namespace physics
```

#### 3. 宽相位碰撞检测 (physics/collision/broad_phase.hpp)

```cpp
#pragma once

#include "../math/math_types.hpp"
#include <vector>
#include <algorithm>
#include <thread>
#include <future>

namespace physics {

// 碰撞对
struct CollisionPair {
    uint32_t a, b;
};

// 均匀网格宽相位
class UniformGridBroadPhase {
private:
    float cellSize_;
    int gridSizeX_, gridSizeY_, gridSizeZ_;
    Vec3 origin_;

    // 网格数据
    std::vector<uint32_t> cellStart_;
    std::vector<uint32_t> cellCount_;
    std::vector<uint32_t> sortedBodies_;
    std::vector<int> bodyCells_;  // 每个物体所在的单元格

    int getCellIndex(float x, float y, float z) const {
        int cx = static_cast<int>((x - origin_.x) / cellSize_);
        int cy = static_cast<int>((y - origin_.y) / cellSize_);
        int cz = static_cast<int>((z - origin_.z) / cellSize_);

        cx = std::clamp(cx, 0, gridSizeX_ - 1);
        cy = std::clamp(cy, 0, gridSizeY_ - 1);
        cz = std::clamp(cz, 0, gridSizeZ_ - 1);

        return cx + cy * gridSizeX_ + cz * gridSizeX_ * gridSizeY_;
    }

public:
    UniformGridBroadPhase(
        const Vec3& worldMin,
        const Vec3& worldMax,
        float cellSize)
        : cellSize_(cellSize), origin_(worldMin) {

        Vec3 size = worldMax - worldMin;
        gridSizeX_ = std::max(1, static_cast<int>(std::ceil(size.x / cellSize)));
        gridSizeY_ = std::max(1, static_cast<int>(std::ceil(size.y / cellSize)));
        gridSizeZ_ = std::max(1, static_cast<int>(std::ceil(size.z / cellSize)));

        size_t totalCells = gridSizeX_ * gridSizeY_ * gridSizeZ_;
        cellStart_.resize(totalCells);
        cellCount_.resize(totalCells);
    }

    void update(const float* posX, const float* posY, const float* posZ,
                size_t bodyCount) {
        const size_t cellCount = cellStart_.size();

        // 重置
        std::fill(cellCount_.begin(), cellCount_.end(), 0);
        bodyCells_.resize(bodyCount);

        // 计算每个物体所在的单元格
        for (size_t i = 0; i < bodyCount; ++i) {
            int cell = getCellIndex(posX[i], posY[i], posZ[i]);
            bodyCells_[i] = cell;
            ++cellCount_[cell];
        }

        // 计算前缀和
        uint32_t total = 0;
        for (size_t i = 0; i < cellCount; ++i) {
            cellStart_[i] = total;
            total += cellCount_[i];
        }

        // 排序物体索引
        sortedBodies_.resize(bodyCount);
        std::vector<uint32_t> currentIndex = cellStart_;

        for (size_t i = 0; i < bodyCount; ++i) {
            int cell = bodyCells_[i];
            sortedBodies_[currentIndex[cell]++] = static_cast<uint32_t>(i);
        }
    }

    std::vector<CollisionPair> findPairs(
        const float* aabbMinX, const float* aabbMinY, const float* aabbMinZ,
        const float* aabbMaxX, const float* aabbMaxY, const float* aabbMaxZ,
        size_t bodyCount) {

        std::vector<CollisionPair> pairs;
        pairs.reserve(bodyCount * 4);  // 预估

        // 遍历每个单元格
        for (int cz = 0; cz < gridSizeZ_; ++cz) {
            for (int cy = 0; cy < gridSizeY_; ++cy) {
                for (int cx = 0; cx < gridSizeX_; ++cx) {
                    int cellIdx = cx + cy * gridSizeX_ +
                                  cz * gridSizeX_ * gridSizeY_;

                    uint32_t start = cellStart_[cellIdx];
                    uint32_t count = cellCount_[cellIdx];

                    if (count == 0) continue;

                    // 单元格内部碰撞
                    for (uint32_t i = 0; i < count; ++i) {
                        uint32_t bodyA = sortedBodies_[start + i];

                        // 与同单元格其他物体
                        for (uint32_t j = i + 1; j < count; ++j) {
                            uint32_t bodyB = sortedBodies_[start + j];

                            if (aabbOverlap(bodyA, bodyB,
                                aabbMinX, aabbMinY, aabbMinZ,
                                aabbMaxX, aabbMaxY, aabbMaxZ)) {
                                pairs.push_back({bodyA, bodyB});
                            }
                        }

                        // 与相邻单元格的物体（只检查"前方"邻居避免重复）
                        static const int neighborOffsets[][3] = {
                            {1, 0, 0}, {0, 1, 0}, {0, 0, 1},
                            {1, 1, 0}, {1, 0, 1}, {0, 1, 1},
                            {1, 1, 1}, {1, -1, 0}, {1, 0, -1},
                            {0, 1, -1}, {1, 1, -1}, {1, -1, 1},
                            {-1, 1, 1}
                        };

                        for (const auto& offset : neighborOffsets) {
                            int nx = cx + offset[0];
                            int ny = cy + offset[1];
                            int nz = cz + offset[2];

                            if (nx < 0 || nx >= gridSizeX_ ||
                                ny < 0 || ny >= gridSizeY_ ||
                                nz < 0 || nz >= gridSizeZ_) continue;

                            int neighborIdx = nx + ny * gridSizeX_ +
                                             nz * gridSizeX_ * gridSizeY_;

                            uint32_t nStart = cellStart_[neighborIdx];
                            uint32_t nCount = cellCount_[neighborIdx];

                            for (uint32_t k = 0; k < nCount; ++k) {
                                uint32_t bodyB = sortedBodies_[nStart + k];

                                if (aabbOverlap(bodyA, bodyB,
                                    aabbMinX, aabbMinY, aabbMinZ,
                                    aabbMaxX, aabbMaxY, aabbMaxZ)) {
                                    pairs.push_back({bodyA, bodyB});
                                }
                            }
                        }
                    }
                }
            }
        }

        return pairs;
    }

    // 并行版本
    std::vector<CollisionPair> findPairsParallel(
        const float* aabbMinX, const float* aabbMinY, const float* aabbMinZ,
        const float* aabbMaxX, const float* aabbMaxY, const float* aabbMaxZ,
        size_t bodyCount) {

        const size_t threadCount = std::thread::hardware_concurrency();
        const size_t cellsPerThread = cellStart_.size() / threadCount;

        std::vector<std::future<std::vector<CollisionPair>>> futures;

        for (size_t t = 0; t < threadCount; ++t) {
            size_t startCell = t * cellsPerThread;
            size_t endCell = (t == threadCount - 1) ?
                             cellStart_.size() : (t + 1) * cellsPerThread;

            futures.push_back(std::async(std::launch::async, [=]() {
                return findPairsInRange(startCell, endCell,
                    aabbMinX, aabbMinY, aabbMinZ,
                    aabbMaxX, aabbMaxY, aabbMaxZ);
            }));
        }

        // 合并结果
        std::vector<CollisionPair> allPairs;
        for (auto& f : futures) {
            auto pairs = f.get();
            allPairs.insert(allPairs.end(), pairs.begin(), pairs.end());
        }

        return allPairs;
    }

private:
    bool aabbOverlap(uint32_t a, uint32_t b,
        const float* minX, const float* minY, const float* minZ,
        const float* maxX, const float* maxY, const float* maxZ) const {
        return minX[a] <= maxX[b] && maxX[a] >= minX[b] &&
               minY[a] <= maxY[b] && maxY[a] >= minY[b] &&
               minZ[a] <= maxZ[b] && maxZ[a] >= minZ[b];
    }

    std::vector<CollisionPair> findPairsInRange(
        size_t startCell, size_t endCell,
        const float* aabbMinX, const float* aabbMinY, const float* aabbMinZ,
        const float* aabbMaxX, const float* aabbMaxY, const float* aabbMaxZ) {

        std::vector<CollisionPair> pairs;

        for (size_t cellIdx = startCell; cellIdx < endCell; ++cellIdx) {
            uint32_t start = cellStart_[cellIdx];
            uint32_t count = cellCount_[cellIdx];

            for (uint32_t i = 0; i < count; ++i) {
                uint32_t bodyA = sortedBodies_[start + i];

                for (uint32_t j = i + 1; j < count; ++j) {
                    uint32_t bodyB = sortedBodies_[start + j];

                    if (aabbOverlap(bodyA, bodyB,
                        aabbMinX, aabbMinY, aabbMinZ,
                        aabbMaxX, aabbMaxY, aabbMaxZ)) {
                        pairs.push_back({bodyA, bodyB});
                    }
                }
            }
        }

        return pairs;
    }
};

} // namespace physics
```

#### 4. 窄相位与碰撞求解 (physics/collision/narrow_phase.hpp)

```cpp
#pragma once

#include "../math/math_types.hpp"
#include "broad_phase.hpp"
#include <vector>

namespace physics {

// 接触点信息
struct ContactPoint {
    Vec3 position;       // 接触点世界坐标
    Vec3 normal;         // 从A指向B的法线
    float penetration;   // 穿透深度
    uint32_t bodyA, bodyB;
};

// 碰撞流形（一对物体的所有接触点）
struct ContactManifold {
    uint32_t bodyA, bodyB;
    std::vector<ContactPoint> contacts;
    float restitution;
    float friction;
};

// 球体vs球体碰撞检测
class SphereCollider {
public:
    static bool testSphereSphere(
        const Vec3& posA, float radiusA,
        const Vec3& posB, float radiusB,
        ContactPoint& contact) {

        Vec3 d = posB - posA;
        float distSq = d.lengthSq();
        float radiusSum = radiusA + radiusB;

        if (distSq >= radiusSum * radiusSum) {
            return false;
        }

        float dist = std::sqrt(distSq);

        contact.normal = dist > 0.0001f ? d / dist : Vec3{0, 1, 0};
        contact.penetration = radiusSum - dist;
        contact.position = posA + contact.normal * (radiusA - contact.penetration * 0.5f);

        return true;
    }
};

// 球体vs平面碰撞检测
class PlaneCollider {
public:
    static bool testSpherePlane(
        const Vec3& spherePos, float radius,
        const Vec3& planeNormal, float planeOffset,
        ContactPoint& contact) {

        float dist = spherePos.dot(planeNormal) - planeOffset;

        if (dist >= radius) {
            return false;
        }

        contact.normal = planeNormal;
        contact.penetration = radius - dist;
        contact.position = spherePos - planeNormal * (dist + contact.penetration * 0.5f);

        return true;
    }
};

// 窄相位碰撞检测系统
class NarrowPhaseSystem {
public:
    // 球体数据（DOD风格）
    std::vector<float> spherePosX, spherePosY, spherePosZ;
    std::vector<float> sphereRadius;
    std::vector<uint32_t> sphereBodyIndex;  // 对应的刚体索引

    // 平面数据
    std::vector<float> planeNormalX, planeNormalY, planeNormalZ;
    std::vector<float> planeOffset;

    std::vector<ContactManifold> detectCollisions(
        const std::vector<CollisionPair>& broadPhasePairs,
        const float* bodyPosX, const float* bodyPosY, const float* bodyPosZ,
        const float* bodyRestitution, const float* bodyFriction) {

        std::vector<ContactManifold> manifolds;

        for (const auto& pair : broadPhasePairs) {
            ContactManifold manifold;
            manifold.bodyA = pair.a;
            manifold.bodyB = pair.b;

            // 简化：假设所有物体都是球体
            // 实际应根据碰撞器类型选择检测算法

            Vec3 posA{bodyPosX[pair.a], bodyPosY[pair.a], bodyPosZ[pair.a]};
            Vec3 posB{bodyPosX[pair.b], bodyPosY[pair.b], bodyPosZ[pair.b]};

            // 查找对应的球体碰撞器
            float radiusA = 0.5f;  // 默认半径
            float radiusB = 0.5f;

            for (size_t i = 0; i < sphereBodyIndex.size(); ++i) {
                if (sphereBodyIndex[i] == pair.a) radiusA = sphereRadius[i];
                if (sphereBodyIndex[i] == pair.b) radiusB = sphereRadius[i];
            }

            ContactPoint contact;
            if (SphereCollider::testSphereSphere(posA, radiusA, posB, radiusB, contact)) {
                contact.bodyA = pair.a;
                contact.bodyB = pair.b;
                manifold.contacts.push_back(contact);

                // 混合材质属性
                manifold.restitution = std::min(
                    bodyRestitution[pair.a], bodyRestitution[pair.b]);
                manifold.friction = std::sqrt(
                    bodyFriction[pair.a] * bodyFriction[pair.b]);

                manifolds.push_back(manifold);
            }
        }

        return manifolds;
    }
};

// 冲量求解器
class ImpulseSolver {
public:
    static void resolveCollision(
        const ContactManifold& manifold,
        float* velX, float* velY, float* velZ,
        float* angVelX, float* angVelY, float* angVelZ,
        const float* invMass,
        const float* posX, const float* posY, const float* posZ) {

        for (const auto& contact : manifold.contacts) {
            uint32_t a = contact.bodyA;
            uint32_t b = contact.bodyB;

            // 相对速度
            Vec3 velA{velX[a], velY[a], velZ[a]};
            Vec3 velB{velX[b], velY[b], velZ[b]};
            Vec3 relVel = velB - velA;

            // 法向相对速度
            float velAlongNormal = relVel.dot(contact.normal);

            // 如果物体正在分离，不处理
            if (velAlongNormal > 0) continue;

            // 计算冲量大小
            float e = manifold.restitution;
            float j = -(1 + e) * velAlongNormal;
            j /= invMass[a] + invMass[b];

            // 应用冲量
            Vec3 impulse = contact.normal * j;

            velX[a] -= impulse.x * invMass[a];
            velY[a] -= impulse.y * invMass[a];
            velZ[a] -= impulse.z * invMass[a];

            velX[b] += impulse.x * invMass[b];
            velY[b] += impulse.y * invMass[b];
            velZ[b] += impulse.z * invMass[b];

            // 位置修正（防止穿透）
            const float percent = 0.2f;
            const float slop = 0.01f;
            float correctionMag = std::max(contact.penetration - slop, 0.0f) /
                                  (invMass[a] + invMass[b]) * percent;
            Vec3 correction = contact.normal * correctionMag;

            // 注意：实际实现中，位置修正应该在专门的步骤中进行
            // 这里为简化，直接通过速度修正来处理

            // 摩擦力
            Vec3 tangent = relVel - contact.normal * velAlongNormal;
            if (tangent.lengthSq() > 0.0001f) {
                tangent = tangent.normalized();

                float jt = -relVel.dot(tangent);
                jt /= invMass[a] + invMass[b];

                // 库仑摩擦
                Vec3 frictionImpulse;
                if (std::abs(jt) < j * manifold.friction) {
                    frictionImpulse = tangent * jt;
                } else {
                    frictionImpulse = tangent * (-j * manifold.friction);
                }

                velX[a] -= frictionImpulse.x * invMass[a];
                velY[a] -= frictionImpulse.y * invMass[a];
                velZ[a] -= frictionImpulse.z * invMass[a];

                velX[b] += frictionImpulse.x * invMass[b];
                velY[b] += frictionImpulse.y * invMass[b];
                velZ[b] += frictionImpulse.z * invMass[b];
            }
        }
    }
};

} // namespace physics
```

#### 5. 物理世界 (physics/world.hpp)

```cpp
#pragma once

#include "dynamics/rigid_body_system.hpp"
#include "collision/broad_phase.hpp"
#include "collision/narrow_phase.hpp"
#include <functional>

namespace physics {

struct WorldConfig {
    Vec3 gravity{0, -9.8f, 0};
    Vec3 worldMin{-100, -100, -100};
    Vec3 worldMax{100, 100, 100};
    float broadPhaseCellSize = 2.0f;
    int solverIterations = 4;
    float fixedDeltaTime = 1.0f / 60.0f;
};

class PhysicsWorld {
private:
    WorldConfig config_;
    RigidBodySystem bodies_;
    UniformGridBroadPhase broadPhase_;
    NarrowPhaseSystem narrowPhase_;

    float accumulator_ = 0;

    // 回调
    std::function<void(uint32_t, uint32_t, const ContactPoint&)> onCollision_;

public:
    explicit PhysicsWorld(const WorldConfig& config = {})
        : config_(config),
          broadPhase_(config.worldMin, config.worldMax, config.broadPhaseCellSize) {}

    // 创建刚体
    uint32_t createBody(const Vec3& position, BodyType type = BodyType::Dynamic) {
        return bodies_.create(position, type);
    }

    // 设置属性
    void setMass(uint32_t body, float mass) {
        bodies_.setMass(body, mass);
    }

    void setVelocity(uint32_t body, const Vec3& velocity) {
        bodies_.velX[body] = velocity.x;
        bodies_.velY[body] = velocity.y;
        bodies_.velZ[body] = velocity.z;
    }

    void setRestitution(uint32_t body, float restitution) {
        bodies_.restitution[body] = restitution;
    }

    void setFriction(uint32_t body, float friction) {
        bodies_.friction[body] = friction;
    }

    // 添加球体碰撞器
    void addSphereCollider(uint32_t body, float radius) {
        narrowPhase_.spherePosX.push_back(bodies_.posX[body]);
        narrowPhase_.spherePosY.push_back(bodies_.posY[body]);
        narrowPhase_.spherePosZ.push_back(bodies_.posZ[body]);
        narrowPhase_.sphereRadius.push_back(radius);
        narrowPhase_.sphereBodyIndex.push_back(body);

        // 更新AABB
        bodies_.aabbMinX[body] = -radius;
        bodies_.aabbMinY[body] = -radius;
        bodies_.aabbMinZ[body] = -radius;
        bodies_.aabbMaxX[body] = radius;
        bodies_.aabbMaxY[body] = radius;
        bodies_.aabbMaxZ[body] = radius;
    }

    // 应用力
    void applyForce(uint32_t body, const Vec3& force) {
        bodies_.applyForce(body, force);
    }

    // 应用冲量
    void applyImpulse(uint32_t body, const Vec3& impulse) {
        bodies_.applyImpulse(body, impulse);
    }

    // 设置碰撞回调
    void setCollisionCallback(
        std::function<void(uint32_t, uint32_t, const ContactPoint&)> callback) {
        onCollision_ = callback;
    }

    // 主更新函数
    void update(float deltaTime) {
        accumulator_ += deltaTime;

        while (accumulator_ >= config_.fixedDeltaTime) {
            step(config_.fixedDeltaTime);
            accumulator_ -= config_.fixedDeltaTime;
        }
    }

    // 单步物理模拟
    void step(float dt) {
        const size_t bodyCount = bodies_.count();
        if (bodyCount == 0) return;

        // 1. 应用重力
        for (size_t i = 0; i < bodyCount; ++i) {
            if (bodies_.invMass[i] > 0) {
                bodies_.forceY[i] += config_.gravity.y / bodies_.invMass[i];
            }
        }

        // 2. 积分速度和位置
#ifdef __AVX__
        bodies_.integrateAVX(dt);
#else
        bodies_.integrate(dt);
#endif

        // 3. 更新AABB（世界坐标）
        updateAABBs();

        // 4. 宽相位碰撞检测
        broadPhase_.update(
            bodies_.posX.data(), bodies_.posY.data(), bodies_.posZ.data(),
            bodyCount);

        auto pairs = broadPhase_.findPairsParallel(
            bodies_.aabbMinX.data(), bodies_.aabbMinY.data(), bodies_.aabbMinZ.data(),
            bodies_.aabbMaxX.data(), bodies_.aabbMaxY.data(), bodies_.aabbMaxZ.data(),
            bodyCount);

        // 5. 窄相位碰撞检测
        auto manifolds = narrowPhase_.detectCollisions(
            pairs,
            bodies_.posX.data(), bodies_.posY.data(), bodies_.posZ.data(),
            bodies_.restitution.data(), bodies_.friction.data());

        // 6. 碰撞求解
        for (int iter = 0; iter < config_.solverIterations; ++iter) {
            for (const auto& manifold : manifolds) {
                ImpulseSolver::resolveCollision(
                    manifold,
                    bodies_.velX.data(), bodies_.velY.data(), bodies_.velZ.data(),
                    bodies_.angVelX.data(), bodies_.angVelY.data(), bodies_.angVelZ.data(),
                    bodies_.invMass.data(),
                    bodies_.posX.data(), bodies_.posY.data(), bodies_.posZ.data());
            }
        }

        // 7. 调用碰撞回调
        if (onCollision_) {
            for (const auto& manifold : manifolds) {
                for (const auto& contact : manifold.contacts) {
                    onCollision_(manifold.bodyA, manifold.bodyB, contact);
                }
            }
        }

        // 8. 清除力
        bodies_.clearForces();
    }

    // 获取位置
    Vec3 getPosition(uint32_t body) const {
        return {bodies_.posX[body], bodies_.posY[body], bodies_.posZ[body]};
    }

    Vec3 getVelocity(uint32_t body) const {
        return {bodies_.velX[body], bodies_.velY[body], bodies_.velZ[body]};
    }

    size_t bodyCount() const { return bodies_.count(); }

    // 直接访问刚体系统（用于批量操作）
    RigidBodySystem& bodies() { return bodies_; }
    const RigidBodySystem& bodies() const { return bodies_; }

private:
    void updateAABBs() {
        const size_t n = bodies_.count();

        // 更新球体位置
        for (size_t i = 0; i < narrowPhase_.sphereBodyIndex.size(); ++i) {
            uint32_t body = narrowPhase_.sphereBodyIndex[i];
            narrowPhase_.spherePosX[i] = bodies_.posX[body];
            narrowPhase_.spherePosY[i] = bodies_.posY[body];
            narrowPhase_.spherePosZ[i] = bodies_.posZ[body];
        }

        // 更新世界空间AABB
        for (size_t i = 0; i < n; ++i) {
            // 找到对应的球体半径
            float radius = 0.5f;
            for (size_t j = 0; j < narrowPhase_.sphereBodyIndex.size(); ++j) {
                if (narrowPhase_.sphereBodyIndex[j] == i) {
                    radius = narrowPhase_.sphereRadius[j];
                    break;
                }
            }

            bodies_.aabbMinX[i] = bodies_.posX[i] - radius;
            bodies_.aabbMinY[i] = bodies_.posY[i] - radius;
            bodies_.aabbMinZ[i] = bodies_.posZ[i] - radius;
            bodies_.aabbMaxX[i] = bodies_.posX[i] + radius;
            bodies_.aabbMaxY[i] = bodies_.posY[i] + radius;
            bodies_.aabbMaxZ[i] = bodies_.posZ[i] + radius;
        }
    }
};

} // namespace physics
```

#### 6. 使用示例与基准测试 (main.cpp)

```cpp
#include "physics/world.hpp"
#include <iostream>
#include <chrono>
#include <random>

using namespace physics;

void benchmark() {
    constexpr size_t BODY_COUNTS[] = {1000, 5000, 10000, 50000};
    constexpr int FRAMES = 100;
    constexpr float DT = 1.0f / 60.0f;

    std::cout << "Physics Engine Benchmark\n";
    std::cout << "========================\n\n";

    for (size_t bodyCount : BODY_COUNTS) {
        WorldConfig config;
        config.worldMin = {-50, -50, -50};
        config.worldMax = {50, 50, 50};
        config.broadPhaseCellSize = 2.0f;

        PhysicsWorld world(config);

        // 创建随机分布的球体
        std::mt19937 rng(42);
        std::uniform_real_distribution<float> posDist(-40, 40);
        std::uniform_real_distribution<float> velDist(-5, 5);
        std::uniform_real_distribution<float> radiusDist(0.3f, 0.8f);

        for (size_t i = 0; i < bodyCount; ++i) {
            Vec3 pos{posDist(rng), posDist(rng), posDist(rng)};
            uint32_t body = world.createBody(pos, BodyType::Dynamic);

            world.setVelocity(body, {velDist(rng), velDist(rng), velDist(rng)});
            world.addSphereCollider(body, radiusDist(rng));
            world.setMass(body, 1.0f);
            world.setRestitution(body, 0.8f);
        }

        // 预热
        for (int i = 0; i < 10; ++i) {
            world.step(DT);
        }

        // 基准测试
        auto start = std::chrono::high_resolution_clock::now();

        for (int frame = 0; frame < FRAMES; ++frame) {
            world.step(DT);
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration<double, std::milli>(end - start);

        double avgFrameTime = duration.count() / FRAMES;
        double fps = 1000.0 / avgFrameTime;

        std::cout << "Bodies: " << bodyCount << "\n";
        std::cout << "  Avg frame time: " << avgFrameTime << " ms\n";
        std::cout << "  FPS: " << fps << "\n\n";
    }
}

void demo() {
    WorldConfig config;
    PhysicsWorld world(config);

    // 创建地面（静态）
    uint32_t ground = world.createBody({0, -5, 0}, BodyType::Static);
    // 地面使用大的AABB代替平面

    // 创建掉落的球体
    for (int i = 0; i < 10; ++i) {
        Vec3 pos{static_cast<float>(i - 5) * 2.0f, 10.0f + i * 2.0f, 0};
        uint32_t ball = world.createBody(pos, BodyType::Dynamic);
        world.addSphereCollider(ball, 0.5f);
        world.setMass(ball, 1.0f);
        world.setRestitution(ball, 0.8f);
    }

    // 设置碰撞回调
    world.setCollisionCallback([](uint32_t a, uint32_t b, const ContactPoint& cp) {
        std::cout << "Collision: " << a << " <-> " << b
                  << " at (" << cp.position.x << ", "
                  << cp.position.y << ", " << cp.position.z << ")\n";
    });

    // 模拟
    std::cout << "Running simulation...\n";
    for (int frame = 0; frame < 300; ++frame) {
        world.step(1.0f / 60.0f);

        if (frame % 60 == 0) {
            std::cout << "Frame " << frame << ":\n";
            for (uint32_t i = 0; i < std::min(static_cast<size_t>(3),
                                               world.bodyCount()); ++i) {
                Vec3 pos = world.getPosition(i);
                std::cout << "  Body " << i << ": ("
                          << pos.x << ", " << pos.y << ", " << pos.z << ")\n";
            }
        }
    }
}

int main() {
    std::cout << "Physics Engine Demo\n";
    std::cout << "===================\n\n";

    demo();
    std::cout << "\n";
    benchmark();

    return 0;
}
```

---

## 检验标准

### 知识检验
1. [ ] 能够解释均匀网格、BVH、SAP、空间哈希四种空间结构的优缺点及适用场景
2. [ ] 理解Morton码的位交错原理及其空间局部性保持特性
3. [ ] 掌握SAT和GJK两种碰撞检测算法的数学原理与实现差异
4. [ ] 能够推导Sequential Impulse求解器的冲量计算公式
5. [ ] 理解warm starting对约束求解收敛速度的影响机制
6. [ ] 掌握memory_order_relaxed/acquire/release的语义差异与使用场景
7. [ ] 能够分析物理引擎各阶段的性能瓶颈并提出优化方向
8. [ ] 理解Amdahl定律对多线程物理引擎加速比的约束

### 实践检验
1. [ ] 完成均匀网格宽相位实现，1000物体正确找到所有碰撞对
2. [ ] 实现BVH构建与AABB查询，查询正确率100%
3. [ ] 实现GJK+EPA碰撞检测，穿透深度与SAT结果一致
4. [ ] 球-球SIMD批量检测比标量版本快3倍以上
5. [ ] 实现线程池与Job System，任务延迟<10μs
6. [ ] 无锁碰撞对收集器通过ThreadSanitizer检测
7. [ ] Sequential Impulse求解器支持warm starting，堆叠稳定
8. [ ] 物理引擎10000物体达到60FPS
9. [ ] 休眠系统在90%物体静止时性能提升5倍以上
10. [ ] 完整的每帧各阶段计时报告

### 代码质量
1. [ ] 所有数据结构使用SoA布局
2. [ ] 无指针追踪——所有引用使用索引
3. [ ] 缓存行对齐——原子变量和线程间共享数据64字节对齐
4. [ ] 无数据竞争——通过ThreadSanitizer验证
5. [ ] 代码可扩展——添加新碰撞器类型不需要修改现有代码
6. [ ] 有完整的基准测试覆盖所有关键路径

---

## 输出物清单

1. **学习笔记**
   - [ ] 空间数据结构对比分析（含缓存行为量化数据）
   - [ ] 碰撞检测算法总结（SAT/GJK/EPA对比，含数学推导）
   - [ ] 多线程DOD模式总结（数据并行/任务并行/无锁设计）
   - [ ] 源码阅读笔记（Box2D/Bullet关键设计分析）

2. **代码产出**
   - [ ] 空间数据结构库（UniformGrid, BVH, SpatialHash, SAP）
   - [ ] 碰撞检测库（AABB SIMD, SAT OBB, GJK+EPA, 多碰撞器类型）
   - [ ] 多线程基础库（ThreadPool, JobSystem, LockFreePairCollector, SPSC Queue）
   - [ ] Sequential Impulse约束求解器（含warm starting和摩擦）
   - [ ] 完整物理引擎（集成所有子系统 + 岛检测 + 休眠）
   - [ ] 基准测试套件（各阶段独立基准 + 全链路基准）

3. **分析报告**
   - [ ] 性能分析报告（各阶段耗时占比、IPC、缓存命中率）
   - [ ] 多线程扩展性分析（1/2/4/8线程加速比曲线）
   - [ ] 与Box2D/Bullet性能对比（同规模场景）

4. **练习完成**
   - [ ] 16个练习任务全部完成（每周4个）
   - [ ] 28个知识检验问题全部回答（每周5思考+2实践）

---

## 时间分配表

| 周次 | 理论学习 | 源码阅读 | 项目实践 | 练习与检验 | 总计 |
|------|----------|----------|----------|-----------|------|
| Week 1 | 12h | 8h | 8h | 7h | 35h |
| Week 2 | 10h | 6h | 12h | 7h | 35h |
| Week 3 | 10h | 5h | 13h | 7h | 35h |
| Week 4 | 8h | 5h | 15h | 7h | 35h |
| **总计** | **40h** | **24h** | **48h** | **28h** | **140h** |

---

## 下月预告

**Month 53: ECS架构（Entity-Component-System）**

下个月将学习游戏开发中最流行的DOD架构模式：
- ECS核心概念与设计原则
- 组件存储策略（Archetype vs Sparse Set）
- 系统调度与并行执行
- 实践项目：构建高性能ECS框架

建议提前：
1. 了解Unity DOTS/ECS概念
2. 阅读EnTT库文档
3. 复习位操作和稀疏集合
