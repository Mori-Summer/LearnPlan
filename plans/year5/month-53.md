# Month 53: ECS架构 (Entity-Component-System)

## 本月主题概述

Entity-Component-System（ECS）是一种将数据与逻辑分离的架构模式，已成为现代游戏引擎和高性能应用的主流选择。ECS通过组合而非继承来构建实体，将行为封装在系统中，实现了极高的灵活性和卓越的缓存性能。本月将深入理解ECS的设计哲学，并从零构建一个高性能ECS框架。

### 学习目标
- 理解ECS架构的核心概念与设计原则
- 掌握两种主要的组件存储策略
- 实现高效的实体查询系统
- 理解系统调度与依赖管理
- 构建一个功能完整的ECS框架

**进阶目标**：
- 深入理解Entity的分代索引（Generational Index）设计，掌握版本号回收机制对悬空引用检测的关键作用，能够实现内存紧凑的Entity池
- 掌握Sparse Set与Archetype两种存储策略在缓存行为、结构变更开销、多组件查询效率上的量化差异，能够根据应用场景做出最优选择
- 能够实现高效的View迭代器，理解最小池选择、交集计算、有序遍历等优化策略，掌握SIMD加速实体过滤的技巧
- 深入理解系统依赖图的自动构建——从组件访问声明推导读写冲突，实现拓扑排序与Stage划分的并行调度器
- 掌握Command Buffer模式在ECS中的核心地位——为何在系统执行期间不能直接进行结构变更，以及延迟操作的批量化执行策略
- 能够设计并实现响应式查询（Reactive Query）与变更检测系统，理解Tick-based追踪在大规模ECS中的性能优势

---

## 理论学习内容

### 第一周：ECS核心概念（35小时）

**学习目标**：
- [ ] 深入理解Entity的本质：为何Entity只是一个ID而非对象，分代索引（index + version）如何解决悬空引用问题
- [ ] 掌握Component的设计原则：纯数据、无行为、可平凡拷贝（trivially copyable）的重要性及其对存储优化的影响
- [ ] 理解System的职责边界：为何System应该是无状态的纯函数，全局状态（Resource）与局部状态的区别
- [ ] 掌握类型擦除（Type Erasure）在ECS中的核心作用：如何在运行时操作编译期未知的组件类型
- [ ] 理解ECS与传统OOP的本质差异：组合优于继承、数据驱动vs对象驱动、缓存友好vs封装优先
- [ ] 能够对比分析主流ECS框架（EnTT/Flecs/Bevy/Unity DOTS）的设计决策及其权衡
- [ ] 理解ECS中的World概念：为何需要一个中心化的管理器，以及World如何协调Entity、Component和System

**阅读材料**：
- [ ] 《Game Programming Patterns》- Component章节（Robert Nystrom）
- [ ] Unity DOTS官方文档 - Entities, Components, Systems概念介绍
- [ ] EnTT库设计文档 - Crash Course: entity-component system
- [ ] Flecs库wiki - Design with Flecs
- [ ] CppCon 2018:《ECS Back and Forth》- Michele Caini（EnTT作者）
- [ ] GDC 2017:《Overwatch Gameplay Architecture and Netcode》- Timothy Ford
- [ ] 《Entity Systems are the future of MMOG development》- Adam Martin系列博文
- [ ] Sander Mertens博客:《Building an ECS》系列文章

---

#### 核心概念

**ECS vs 传统OOP**
```
┌─────────────────────────────────────────────────────────┐
│                    传统OOP继承                          │
└─────────────────────────────────────────────────────────┘

           GameObject
               │
    ┌──────────┼──────────┐
    │          │          │
Character   Vehicle    Projectile
    │          │          │
  ┌─┴─┐      ┌─┴─┐        │
Player Enemy Car Plane  Bullet

问题：
- 深层继承导致耦合
- 菱形继承问题
- 难以运行时改变行为
- 数据分散，缓存不友好

┌─────────────────────────────────────────────────────────┐
│                    ECS组合模式                          │
└─────────────────────────────────────────────────────────┘

Entity: 只是一个ID (uint32/uint64)

Components (纯数据):
┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│ Position │ │ Velocity │ │ Health   │ │ Sprite   │
│ x, y, z  │ │ vx,vy,vz │ │ current  │ │ textureId│
└──────────┘ └──────────┘ │ max      │ │ width,h  │
                          └──────────┘ └──────────┘

Systems (纯逻辑):
┌────────────────┐ ┌────────────────┐ ┌────────────────┐
│ MovementSystem │ │ RenderSystem   │ │ DamageSystem   │
│ Query:         │ │ Query:         │ │ Query:         │
│ Position,      │ │ Position,      │ │ Health         │
│ Velocity       │ │ Sprite         │ │                │
└────────────────┘ └────────────────┘ └────────────────┘

Entity组合示例：
Player = Entity + Position + Velocity + Health + Sprite + Input
Enemy  = Entity + Position + Velocity + Health + Sprite + AI
Bullet = Entity + Position + Velocity + Damage + Sprite
```

**ECS术语定义**
```cpp
// Entity: 唯一标识符
using Entity = uint64_t;

// 分解Entity: 索引 + 版本号（用于检测无效引用）
struct EntityId {
    uint32_t index;    // 索引
    uint32_t version;  // 版本号，每次回收递增
};

// Component: 纯数据结构，无行为
struct Position {
    float x, y, z;
};

struct Velocity {
    float x, y, z;
};

struct Health {
    int current;
    int max;
};

// System: 纯逻辑，处理具有特定组件组合的实体
class MovementSystem {
public:
    void update(float dt) {
        // 查询所有有Position和Velocity的实体
        for (auto [entity, pos, vel] : query<Position, Velocity>()) {
            pos.x += vel.x * dt;
            pos.y += vel.y * dt;
            pos.z += vel.z * dt;
        }
    }
};

// World: 管理所有Entity、Component和System
class World {
    // 实体管理
    // 组件存储
    // 系统调度
};
```

### 第二周：组件存储策略（35小时）

**学习目标**：
- [ ] 深入理解Sparse Set的内部结构：稀疏数组（sparse array）与稠密数组（dense array）的双向映射机制，掌握swap-and-pop删除的O(1)复杂度原理
- [ ] 掌握分页稀疏数组（Paged Sparse Array）的设计：为何EnTT使用分页而非连续数组，页大小选择对内存碎片与查找性能的影响
- [ ] 理解Archetype存储的完整实现：类型哈希计算、Archetype图（Graph）、边（Edge）快速迁移，以及Chunk-based内存布局
- [ ] 掌握组件迁移（Component Migration）的实现细节：当添加/删除组件时，Archetype策略如何高效地移动实体数据
- [ ] 深入理解CPU缓存对ECS性能的决定性影响：L1/L2/L3缓存行大小、预取（Prefetch）、缓存行对齐、伪共享（False Sharing）的避免
- [ ] 能够实现基于排序的Sparse Set优化（Sorting Groups）：通过保持多个池的实体顺序一致来加速多组件遍历
- [ ] 掌握两种策略在不同工作负载下的性能特征：结构频繁变更 vs 稳定遍历、宽实体 vs 窄实体、大量Archetype vs 少量Archetype
- [ ] 理解混合策略的可行性：如何在同一ECS中对不同组件使用不同的存储策略

**阅读材料**：
- [ ] Sander Mertens:《Building an ECS #2 - Archetypes and Vectorization》
- [ ] Michele Caini (EnTT作者):《ECS Back and Forth - Part 2: Where are my entities?》博文
- [ ] CppCon 2019:《Data-Oriented Design and C++》- Mike Acton
- [ ] Unity DOTS源码分析 - ArchetypeChunk与EntityComponentStore实现
- [ ] EnTT源码：`src/entt/entity/sparse_set.hpp` 分页实现细节
- [ ] Flecs文档：《Storage Model》- 表(Table)存储与列(Column)布局
- [ ] 《What Every Programmer Should Know About Memory》- Ulrich Drepper（第3章：CPU Caches）
- [ ] GDC 2018:《Unity at GDC - Data-Oriented Technology Stack》- Joachim Ante

---

#### 核心概念

**存储策略全景对比**
```
┌─────────────────────────────────────────────────────────────┐
│                    ECS存储策略全景图                          │
└─────────────────────────────────────────────────────────────┘

                    存储策略
                       │
          ┌────────────┼────────────┐
          │            │            │
     Sparse Set    Archetype    混合策略
     (Per-Type)   (Per-Group)   (Hybrid)
          │            │            │
       EnTT        Unity DOTS    Flecs v3+
       entt::      Bevy ECS
       registry

比较维度：
┌──────────────────┬──────────────┬──────────────┐
│     操作         │  Sparse Set  │  Archetype   │
├──────────────────┼──────────────┼──────────────┤
│ 添加组件         │    O(1)      │   O(n)*      │
│ 删除组件         │    O(1)      │   O(n)*      │
│ 单组件遍历       │    极快       │    快         │
│ 多组件遍历       │  需交集计算   │    极快       │
│ 随机访问组件     │    O(1)      │   O(1)**     │
│ 内存开销         │    较高       │    较低       │
│ 缓存利用率       │    中等       │    极高       │
│ 实现复杂度       │    低         │    高         │
└──────────────────┴──────────────┴──────────────┘

*  n = 实体拥有的组件数量（需要逐个拷贝/移动）
** 需要先查找实体所在的Archetype
```

**Sparse Set深入解析**
```
┌─────────────────────────────────────────────────────────────┐
│              Sparse Set 内部结构详解                          │
└─────────────────────────────────────────────────────────────┘

Sparse Array（稀疏数组）：以Entity ID为索引
┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
│ 2 │ - │ 0 │ - │ 1 │ - │ - │ 3 │ - │ - │  sparse_
└───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘
  0   1   2   3   4   5   6   7   8   9    ← Entity ID

Dense Array（稠密数组）：紧凑存储，无空洞
┌──────┬──────┬──────┬──────┐
│ Pos0 │ Pos4 │ Pos2 │ Pos7 │  dense_ (组件数据)
└──────┴──────┴──────┴──────┘
  [0]    [1]    [2]    [3]   ← Dense索引

Entity Array（实体数组）：与Dense一一对应
┌───┬───┬───┬───┐
│ 0 │ 4 │ 2 │ 7 │  entities_
└───┴───┴───┴───┘

映射关系：
  sparse_[0] = 0  →  dense_[0] = Pos0,  entities_[0] = 0
  sparse_[2] = 2  →  dense_[2] = Pos2,  entities_[2] = 2
  sparse_[4] = 1  →  dense_[1] = Pos4,  entities_[1] = 4
  sparse_[7] = 3  →  dense_[3] = Pos7,  entities_[3] = 7

删除Entity 2的过程（Swap-and-Pop）：
  Step 1: 找到dense索引 → sparse_[2] = 2
  Step 2: 将最后一个元素(Pos7)移到位置2
  Step 3: 更新sparse_[7] = 2
  Step 4: pop_back()移除末尾
  Step 5: sparse_[2] = INVALID

删除后：
  dense_:    [Pos0, Pos4, Pos7]
  entities_: [0,    4,    7   ]
  sparse_:   [0, -, -, -, 1, -, -, 2, -, -]

关键洞察：dense数组始终保持紧凑，遍历时零空洞！
```

**分页稀疏数组**
```
┌─────────────────────────────────────────────────────────────┐
│              为什么需要分页？                                  │
└─────────────────────────────────────────────────────────────┘

问题：如果Entity ID范围很大（比如最大ID=1000000），
      连续sparse数组需要 1000000 * 4 bytes = 4MB 内存！

解决：分页稀疏数组（EnTT的实际方案）

Page Size = 4096（典型值，刚好一个内存页）

Entity ID = 100000
  → Page Index = 100000 / 4096 = 24
  → Page Offset = 100000 % 4096 = 1696

┌─────────────────────────────────────────┐
│         Pages Array (页目录)             │
├──────┬──────┬──────┬──────┬──────┬──────┤
│ Page0│ null │ null │ ...  │Page24│ ...  │
└──┬───┴──────┴──────┴──────┴──┬───┴──────┘
   │                           │
   ▼                           ▼
┌──────────┐             ┌──────────┐
│ 4096个    │             │ 4096个    │
│ uint32_t │             │ uint32_t │
│ 槽位      │             │ 槽位      │
└──────────┘             └──────────┘

优势：
✓ 只分配被使用的页 → 内存按需增长
✓ 页大小=OS内存页 → 减少TLB miss
✓ 查找仍是O(1)：两次数组索引
✓ Entity ID可以很稀疏而不浪费内存
```

```cpp
// 分页稀疏数组实现
template<typename T>
class PagedSparseSet {
private:
    static constexpr size_t PAGE_SIZE = 4096;  // 每页槽位数
    static constexpr uint32_t INVALID = UINT32_MAX;

    // 页目录：按需分配
    std::vector<std::unique_ptr<std::array<uint32_t, PAGE_SIZE>>> pages_;

    std::vector<T> dense_;
    std::vector<uint32_t> entities_;

    // 获取或创建页
    uint32_t& sparseRef(uint32_t entity) {
        size_t pageIndex = entity / PAGE_SIZE;
        size_t offset = entity % PAGE_SIZE;

        if (pageIndex >= pages_.size()) {
            pages_.resize(pageIndex + 1);
        }

        if (!pages_[pageIndex]) {
            pages_[pageIndex] = std::make_unique<
                std::array<uint32_t, PAGE_SIZE>>();
            pages_[pageIndex]->fill(INVALID);
        }

        return (*pages_[pageIndex])[offset];
    }

    // 只读查找（不创建页）
    uint32_t sparseGet(uint32_t entity) const {
        size_t pageIndex = entity / PAGE_SIZE;
        size_t offset = entity % PAGE_SIZE;

        if (pageIndex >= pages_.size() || !pages_[pageIndex]) {
            return INVALID;
        }
        return (*pages_[pageIndex])[offset];
    }

public:
    template<typename... Args>
    T& emplace(uint32_t entity, Args&&... args) {
        uint32_t& slot = sparseRef(entity);

        if (slot != INVALID) {
            return dense_[slot] = T(std::forward<Args>(args)...);
        }

        slot = static_cast<uint32_t>(dense_.size());
        dense_.emplace_back(std::forward<Args>(args)...);
        entities_.push_back(entity);
        return dense_.back();
    }

    void erase(uint32_t entity) {
        uint32_t denseIdx = sparseGet(entity);
        if (denseIdx == INVALID) return;

        uint32_t lastEntity = entities_.back();

        if (denseIdx != dense_.size() - 1) {
            dense_[denseIdx] = std::move(dense_.back());
            entities_[denseIdx] = lastEntity;
            sparseRef(lastEntity) = denseIdx;
        }

        dense_.pop_back();
        entities_.pop_back();
        sparseRef(entity) = INVALID;
    }

    T* get(uint32_t entity) {
        uint32_t idx = sparseGet(entity);
        return idx != INVALID ? &dense_[idx] : nullptr;
    }

    bool contains(uint32_t entity) const {
        return sparseGet(entity) != INVALID;
    }

    // 遍历：直接遍历dense数组，极致缓存友好
    T* data() { return dense_.data(); }
    size_t size() const { return dense_.size(); }
    const std::vector<uint32_t>& entities() const { return entities_; }

    auto begin() { return dense_.begin(); }
    auto end() { return dense_.end(); }
};
```

**Sorting Group优化**
```
┌─────────────────────────────────────────────────────────────┐
│           Sorting Group: Sparse Set的多组件加速               │
└─────────────────────────────────────────────────────────────┘

问题：Sparse Set策略下，多组件遍历需要交集计算。
      Position池和Velocity池的实体顺序不同 → 随机访问！

未排序时遍历 view<Position, Velocity>：
  Position dense: [P_0, P_4, P_2, P_7, P_3]  ← 遍历主导池
  Velocity dense: [V_3, V_0, V_7, V_2, V_4]

  对于P_0: 查找V_0 → sparse查找 → 随机跳转到Velocity[1]
  对于P_4: 查找V_4 → sparse查找 → 随机跳转到Velocity[4]
  ...每次都是缓存未命中！

Sorting Group：保持两个池的实体顺序一致

排序后（按Entity ID排序两个池）：
  Position dense: [P_0, P_2, P_3, P_4, P_7]
  Velocity dense: [V_0, V_2, V_3, V_4, V_7]

  现在：Position[i]和Velocity[i]对应同一实体！
  遍历变成线性扫描，缓存利用率极高。

实现要点：
  1. 选择一个"owner"池（通常是最常查询的组件组合中的第一个）
  2. 当owner池的实体顺序变化时，同步排序其他池
  3. 排序使用Entity ID作为key
  4. 添加/删除后需要重新排序（或使用插入排序保持有序）
```

```cpp
// EnTT风格的Sorting Group实现思路
template<typename Owned, typename... Others>
class SortingGroup {
    ComponentPool<Owned>* owner_;
    std::tuple<ComponentPool<Others>*...> others_;

public:
    SortingGroup(ComponentPool<Owned>* owner,
                 ComponentPool<Others>*... others)
        : owner_(owner), others_(others...) {}

    // 按Entity ID排序owner池，然后同步其他池
    void sort() {
        // Step 1: 获取owner池的实体列表
        auto& ownerEntities = owner_->entities();

        // Step 2: 创建排序索引
        std::vector<size_t> indices(ownerEntities.size());
        std::iota(indices.begin(), indices.end(), 0);

        std::sort(indices.begin(), indices.end(),
            [&](size_t a, size_t b) {
                return ownerEntities[a] < ownerEntities[b];
            });

        // Step 3: 按索引重排owner池
        // (实际实现需要就地重排dense和entities数组)
        applyPermutation(owner_, indices);

        // Step 4: 让其他池的顺序与owner一致
        std::apply([this](auto*... pools) {
            (syncPoolOrder(pools), ...);
        }, others_);
    }

private:
    template<typename Pool>
    void syncPoolOrder(Pool* pool) {
        // 按照owner池的实体顺序，重排pool
        // 只重排两者交集部分的实体
        const auto& ownerEntities = owner_->entities();
        size_t pos = 0;

        for (uint32_t entity : ownerEntities) {
            if (pool->contains(entity)) {
                // 将entity对应的组件移到pos位置
                uint32_t currentPos = pool->getDenseIndex(entity);
                if (currentPos != pos) {
                    pool->swapElements(currentPos, pos);
                }
                ++pos;
            }
        }
    }

    template<typename Pool>
    void applyPermutation(Pool* pool,
                          const std::vector<size_t>& indices) {
        // 按排列索引重排（Fisher-Yates风格的就地置换）
        std::vector<bool> visited(indices.size(), false);
        for (size_t i = 0; i < indices.size(); ++i) {
            if (visited[i] || indices[i] == i) continue;
            size_t j = i;
            while (!visited[j]) {
                visited[j] = true;
                size_t next = indices[j];
                if (!visited[next]) {
                    pool->swapElements(j, next);
                }
                j = next;
            }
        }
    }
};
```

**Archetype存储完整解析**
```
┌─────────────────────────────────────────────────────────────┐
│              Archetype 存储架构详解                            │
└─────────────────────────────────────────────────────────────┘

核心思想：相同组件组合的实体存储在一起

Archetype = 一种组件组合的"类型签名"

示例世界：
  Entity 0: [Position, Velocity]
  Entity 1: [Position, Velocity, Health]
  Entity 2: [Position, Velocity]
  Entity 3: [Position, Sprite]
  Entity 4: [Position, Velocity, Health]

分组后：

  Archetype A {Position, Velocity}:
  ┌─────────────────────────────────────┐
  │ Columns:                            │
  │   Position: [Pos0,  Pos2 ]          │
  │   Velocity: [Vel0,  Vel2 ]          │
  │   Entity:   [E0,    E2   ]          │
  │ Count: 2                            │
  └─────────────────────────────────────┘

  Archetype B {Position, Velocity, Health}:
  ┌─────────────────────────────────────┐
  │ Columns:                            │
  │   Position: [Pos1,  Pos4 ]          │
  │   Velocity: [Vel1,  Vel4 ]          │
  │   Health:   [Hp1,   Hp4  ]          │
  │   Entity:   [E1,    E4   ]          │
  │ Count: 2                            │
  └─────────────────────────────────────┘

  Archetype C {Position, Sprite}:
  ┌─────────────────────────────────────┐
  │ Columns:                            │
  │   Position: [Pos3 ]                 │
  │   Sprite:   [Spr3 ]                 │
  │   Entity:   [E3   ]                 │
  │ Count: 1                            │
  └─────────────────────────────────────┘

查询 view<Position, Velocity> 时：
  → 匹配 Archetype A 和 B（都包含Position+Velocity）
  → 线性遍历两个Archetype的数据，极致缓存友好！
```

```
┌─────────────────────────────────────────────────────────────┐
│              Archetype Graph（原型图）                        │
└─────────────────────────────────────────────────────────────┘

组件变更时如何快速找到目标Archetype？→ 使用Archetype Graph

                    {Position}
                    /        \
            +Velocity      +Sprite
                  /            \
    {Position, Velocity}   {Position, Sprite}
              |
          +Health
              |
    {Position, Velocity, Health}

每条边(Edge)记录了：
  - 添加某个组件后到达的目标Archetype
  - 删除某个组件后到达的目标Archetype

Edge结构：
  Archetype {Pos, Vel}:
    +Health → Archetype {Pos, Vel, Health}
    -Pos    → Archetype {Vel}
    -Vel    → Archetype {Pos}

优势：组件变更的Archetype查找 = O(1)！
     （不需要每次都重新哈希查找）
```

```cpp
// Archetype存储实现
class Archetype {
public:
    // Archetype的类型签名
    struct TypeHash {
        std::vector<ComponentId> sortedIds;  // 排序后的组件ID列表

        bool operator==(const TypeHash& other) const {
            return sortedIds == other.sortedIds;
        }

        // 用于哈希表
        struct Hasher {
            size_t operator()(const TypeHash& h) const {
                size_t seed = h.sortedIds.size();
                for (auto id : h.sortedIds) {
                    // FNV-1a风格混合
                    seed ^= id + 0x9e3779b9 + (seed << 6) + (seed >> 2);
                }
                return seed;
            }
        };

        bool contains(ComponentId id) const {
            return std::binary_search(sortedIds.begin(),
                                       sortedIds.end(), id);
        }

        // 添加一个组件后的新TypeHash
        TypeHash with(ComponentId id) const {
            TypeHash result = *this;
            auto it = std::lower_bound(result.sortedIds.begin(),
                                        result.sortedIds.end(), id);
            if (it == result.sortedIds.end() || *it != id) {
                result.sortedIds.insert(it, id);
            }
            return result;
        }

        // 删除一个组件后的新TypeHash
        TypeHash without(ComponentId id) const {
            TypeHash result = *this;
            auto it = std::lower_bound(result.sortedIds.begin(),
                                        result.sortedIds.end(), id);
            if (it != result.sortedIds.end() && *it == id) {
                result.sortedIds.erase(it);
            }
            return result;
        }
    };

private:
    TypeHash typeHash_;

    // 列式存储：每个组件类型一列
    struct Column {
        ComponentInfo info;
        std::vector<std::byte> data;  // 原始字节存储
        size_t count = 0;

        void* at(size_t index) {
            return data.data() + index * info.size;
        }

        const void* at(size_t index) const {
            return data.data() + index * info.size;
        }

        void pushBack(const void* src) {
            size_t oldSize = data.size();
            data.resize(oldSize + info.size);
            info.copy(data.data() + oldSize, src);
            ++count;
        }

        void swapAndPop(size_t index) {
            if (index < count - 1) {
                info.move(at(index), at(count - 1));
            }
            info.destruct(at(count - 1));
            data.resize(data.size() - info.size);
            --count;
        }
    };

    std::unordered_map<ComponentId, Column> columns_;
    std::vector<Entity> entities_;

    // Archetype Graph: 边缓存
    struct Edge {
        Archetype* add = nullptr;   // 添加此组件后的目标
        Archetype* remove = nullptr; // 删除此组件后的目标
    };
    std::unordered_map<ComponentId, Edge> edges_;

public:
    Archetype(const TypeHash& hash,
              const std::vector<ComponentInfo>& infos)
        : typeHash_(hash) {
        for (const auto& info : infos) {
            columns_[info.id] = Column{info, {}, 0};
        }
    }

    // 添加实体（从另一个Archetype迁移）
    size_t addEntity(Entity entity) {
        entities_.push_back(entity);
        return entities_.size() - 1;
    }

    // 移除实体（swap-and-pop）
    Entity removeEntity(size_t index) {
        Entity removed = entities_[index];
        Entity last = entities_.back();

        if (index < entities_.size() - 1) {
            entities_[index] = last;
            // 同步移动所有列的数据
            for (auto& [id, col] : columns_) {
                col.swapAndPop(index);
            }
        } else {
            for (auto& [id, col] : columns_) {
                col.swapAndPop(index);
            }
        }

        entities_.pop_back();
        return last;  // 返回被交换的实体（调用方需要更新其索引）
    }

    // 获取组件数据
    void* getComponent(ComponentId compId, size_t index) {
        auto it = columns_.find(compId);
        if (it == columns_.end()) return nullptr;
        return it->second.at(index);
    }

    bool hasComponent(ComponentId compId) const {
        return columns_.find(compId) != columns_.end();
    }

    const TypeHash& type() const { return typeHash_; }
    size_t count() const { return entities_.size(); }
    const std::vector<Entity>& getEntities() const { return entities_; }

    // Graph边操作
    void setEdge(ComponentId compId, Archetype* addTarget,
                 Archetype* removeTarget) {
        edges_[compId] = {addTarget, removeTarget};
    }

    Archetype* getAddEdge(ComponentId compId) {
        auto it = edges_.find(compId);
        return it != edges_.end() ? it->second.add : nullptr;
    }

    Archetype* getRemoveEdge(ComponentId compId) {
        auto it = edges_.find(compId);
        return it != edges_.end() ? it->second.remove : nullptr;
    }
};
```

**缓存行分析与性能影响**
```
┌─────────────────────────────────────────────────────────────┐
│           CPU缓存对ECS性能的决定性影响                         │
└─────────────────────────────────────────────────────────────┘

典型CPU缓存层次（以Apple M1为例）：
  L1 Data Cache:  64KB per core,  ~1ns
  L2 Cache:       4MB per cluster, ~4ns
  L3 Cache (SLC): 16MB shared,     ~10ns
  Main Memory:    -                 ~100ns

缓存行（Cache Line）= 64 bytes

═══════════════════════════════════════════════════

场景1：OOP风格 - 每个对象分散在堆上

class GameObject {    // sizeof ≈ 200+ bytes
    Transform transform;  // 36 bytes
    Velocity velocity;    // 12 bytes
    Health health;        // 8 bytes
    Sprite sprite;        // 16 bytes
    AI* ai;              // 8 bytes
    ...padding/vtable...  // 120+ bytes
};

遍历更新Position：
  对象0: [████████████████████████████████]  ← 加载200B但只用36B
          ↓ 缓存行0-3                         利用率: 36/200 = 18%
  对象1: [████████████████████████████████]  ← 另一个位置（堆分配）
          ↓ 可能完全不同的缓存行                 每个对象 = cache miss!

═══════════════════════════════════════════════════

场景2：Sparse Set - 组件分离但不同类型不连续

Position Pool: [P0][P1][P2][P3][P4][P5][P6]...
                ↑ 连续内存，遍历Position极快
                  每64B缓存行装 64/12 ≈ 5个Position

Velocity Pool: [V3][V0][V7][V2][V4]...
                ↑ 也是连续，但顺序与Position不同
                  查找V_for_entity → 可能跳跃访问

遍历 view<Position, Velocity>:
  Position[0](E0) → 查Velocity → sparse_[0] → dense_[1]  ← 随机跳转!
  Position[1](E4) → 查Velocity → sparse_[4] → dense_[4]  ← 又跳转!

═══════════════════════════════════════════════════

场景3：Archetype - 同组合的组件连续存储

Archetype {Position, Velocity}:
  Position: [P0, P2, P5, P8, ...]  ← 连续
  Velocity: [V0, V2, V5, V8, ...]  ← 连续且对应

遍历：Position和Velocity严格线性访问
  → 硬件预取器(Prefetcher)可以完美工作
  → 几乎零cache miss！

═══════════════════════════════════════════════════

性能数据参考（100万实体，更新Position+Velocity）：
  OOP:         ~15ms (大量cache miss)
  Sparse Set:  ~3ms  (Position连续但Velocity随机)
  Sorted Set:  ~1.5ms (两者都连续)
  Archetype:   ~1ms  (极致缓存友好)
```

**设计决策分析**

```
┌─────────────────────────────────────────────────────────────┐
│           如何选择存储策略？决策框架                            │
└─────────────────────────────────────────────────────────────┘

选择 Sparse Set 当：
  ✓ 组件结构频繁变化（频繁添加/删除组件）
  ✓ 需要快速的组件随机访问（通过Entity ID直接查）
  ✓ 系统以单组件遍历为主
  ✓ 需要简单的实现和调试
  ✓ 实体之间的组件组合差异很大（Archetype爆炸问题）
  ✓ 示例：编辑器、工具链、Prototype阶段

选择 Archetype 当：
  ✓ 组件结构相对稳定（游戏运行时很少改变组件组合）
  ✓ 系统以多组件联合遍历为主
  ✓ 需要极致的遍历性能
  ✓ 实体的组件组合比较规律（不会有太多Archetype）
  ✓ 示例：大型游戏的运行时、模拟系统

混合策略（Flecs v3+的做法）：
  ✓ 核心高频组件用Archetype存储
  ✓ 标签类组件用Sparse Set存储
  ✓ 关系(Relationship)用特殊结构存储
  → 取两者之长，但实现复杂度最高
```

**练习题**

```
练习1：实现分页Sparse Set
  - 实现完整的分页稀疏集合，页大小可配置
  - 支持 insert, erase, get, contains, iterate
  - 验证：创建100万实体，ID随机分布在0~10000000范围
  - 对比：与连续sparse数组的内存消耗差异

练习2：实现基本的Archetype存储
  - 实现TypeHash、Column、Archetype类
  - 支持实体的添加、删除、组件迁移
  - 实现Archetype Graph的边缓存
  - 验证：添加/删除组件时自动迁移实体

练习3：缓存性能基准测试
  - 创建50万实体，每个有Position+Velocity
  - 分别用Sparse Set和Archetype存储
  - 测量 view<Position, Velocity> 遍历的耗时
  - 使用perf stat（Linux）或Instruments（macOS）
    观察cache-misses和instructions-per-cycle

练习4：Sorting Group实现
  - 在Sparse Set基础上实现Sorting Group
  - 让Position池和Velocity池的实体顺序一致
  - 测量排序前后 view<Position, Velocity> 的性能差异
  - 分析：在什么频率的结构变更下，排序收益大于排序开销？
```

---

### 第三周：查询系统设计（35小时）

**学习目标**：
- [ ] 掌握View迭代器的完整实现：最小池选择（Leading Pool Selection）、交集过滤、skip-ahead优化
- [ ] 理解多池交集计算的性能瓶颈：为什么选择最小池作为主导池能显著减少无效查找
- [ ] 掌握过滤器（Filter）的设计与实现：With/Without/Optional的编译期类型分派
- [ ] 实现响应式查询（Reactive Query）与变更检测：Tick-based追踪如何高效检测组件的Added/Changed/Removed
- [ ] 理解EnTT的Group机制：Owning Group vs Non-owning Group的区别，以及Group如何将多组件遍历降到O(n)
- [ ] 掌握查询缓存策略：为何Archetype方案需要缓存匹配的Archetype列表，缓存失效的触发条件
- [ ] 能够分析不同查询模式的性能特征：单组件查询 vs 多组件查询 vs 排除查询 vs 可选查询的开销比较
- [ ] 理解SIMD在实体过滤中的应用：使用位掩码向量化加速contains检查

**阅读材料**：
- [ ] EnTT源码：`src/entt/entity/view.hpp` 和 `src/entt/entity/group.hpp`
- [ ] Michele Caini:《ECS Back and Forth - Part 4: Views and Groups》博文
- [ ] Bevy ECS源码：`crates/bevy_ecs/src/query/` 目录
- [ ] Sander Mertens:《Building an ECS #3 - Querying》
- [ ] CppCon 2021:《Embracing User Defined Literals for Safety and Performance》（模板元编程技巧）
- [ ] 《C++ Templates: The Complete Guide》- Vandevoorde, Josuttis（Variadic Templates章节）
- [ ] Unity DOTS文档:《EntityQuery》设计与用法
- [ ] Flecs文档:《Queries - Filters, Cached Queries, Rules》

---

#### 核心概念

**View迭代器完整设计**
```
┌─────────────────────────────────────────────────────────────┐
│              View迭代器工作原理                                │
└─────────────────────────────────────────────────────────────┘

查询: view<Position, Velocity, Health>()

Step 1: 选择最小池（Leading Pool）

  Position Pool: 10000 entities
  Velocity Pool: 8000 entities
  Health Pool:   3000 entities  ← 最小！选为leading pool

  为什么？最小池能最大限度减少无效查找：
    - 遍历3000个实体，每个检查2次contains → 最多6000次查找
    - 如果选10000的池 → 最多20000次查找
    - 差距：3.3倍！

Step 2: 遍历leading pool，过滤交集

  Health entities: [E5, E12, E7, E99, E3, ...]
                    │
  对每个Entity:     ▼
    E5:  Position.contains(5)?  ✓  Velocity.contains(5)?  ✓  → 命中！
    E12: Position.contains(12)? ✓  Velocity.contains(12)? ✗  → 跳过
    E7:  Position.contains(7)?  ✓  Velocity.contains(7)?  ✓  → 命中！
    E99: Position.contains(99)? ✗  → 提前退出，不查Velocity → 跳过
    ...

  contains()的实现（Sparse Set）：
    bool contains(uint32_t entity) {
        return entity < sparse_.size()
            && sparse_[entity] != INVALID;
    }
    → O(1)，只是两次比较！

Step 3: 返回组件引用元组

  for (auto [entity, pos, vel, hp] : view<Position, Velocity, Health>()) {
      // pos, vel, hp 已经是引用，直接读写
  }
```

**完整View实现（优化版）**
```cpp
// 类型特征：区分普通组件和修饰符
template<typename T>
struct is_optional : std::false_type {};

template<typename T>
struct is_optional<Optional<T>> : std::true_type {};

template<typename T>
struct is_exclude : std::false_type {};

template<typename T>
struct is_exclude<Without<T>> : std::true_type {};

// 从修饰符中提取实际类型
template<typename T>
struct unwrap_type { using type = T; };

template<typename T>
struct unwrap_type<Optional<T>> { using type = T; };

template<typename T>
struct unwrap_type<Without<T>> { using type = T; };

template<typename T>
using unwrap_type_t = typename unwrap_type<T>::type;

// 优化的View实现
template<typename... Components>
class OptimizedView {
    // 将组件分为三类
    using RequiredTypes = typename FilterTypes<
        is_required, Components...>::type;   // 必需且访问
    using OptionalTypes = typename FilterTypes<
        is_optional, Components...>::type;   // 可选
    using ExcludeTypes = typename FilterTypes<
        is_exclude, Components...>::type;    // 排除

    // 所有必需组件的池
    std::tuple<ComponentPool<unwrap_type_t<Components>>*...> allPools_;

    // Leading pool（最小的必需组件池）
    ComponentPoolBase* leadingPool_;
    const std::vector<uint32_t>* leadingEntities_;

public:
    // 构造时确定leading pool
    OptimizedView(ComponentPool<unwrap_type_t<Components>>*... pools)
        : allPools_(pools...) {
        // 在必需组件的池中找最小的
        findLeadingPool();
    }

    class Iterator {
        const OptimizedView* view_;
        size_t index_;
        size_t endIndex_;

        // 检查当前位置是否有效
        bool isValid() const {
            if (index_ >= endIndex_) return false;

            uint32_t entity = (*view_->leadingEntities_)[index_];

            // 检查所有必需组件
            bool hasRequired = checkRequired(entity);
            if (!hasRequired) return false;

            // 检查所有排除组件
            bool hasExcluded = checkExcluded(entity);
            if (hasExcluded) return false;

            return true;
        }

        bool checkRequired(uint32_t entity) const {
            return std::apply([entity](auto*... pools) {
                return (checkPool<Components>(pools, entity) && ...);
            }, view_->allPools_);
        }

        template<typename C, typename Pool>
        static bool checkPool(Pool* pool, uint32_t entity) {
            if constexpr (is_optional<C>::value || is_exclude<C>::value) {
                return true;  // Optional和Exclude不参与必需性检查
            } else {
                return pool->contains(entity);
            }
        }

        bool checkExcluded(uint32_t entity) const {
            return std::apply([entity](auto*... pools) {
                return (checkExclude<Components>(pools, entity) || ...);
            }, view_->allPools_);
        }

        template<typename C, typename Pool>
        static bool checkExclude(Pool* pool, uint32_t entity) {
            if constexpr (is_exclude<C>::value) {
                return pool->contains(entity);  // 如果有排除的组件→失败
            } else {
                return false;
            }
        }

    public:
        Iterator(const OptimizedView* view, size_t index, size_t end)
            : view_(view), index_(index), endIndex_(end) {
            while (index_ < endIndex_ && !isValid()) {
                ++index_;
            }
        }

        Iterator& operator++() {
            ++index_;
            while (index_ < endIndex_ && !isValid()) {
                ++index_;
            }
            return *this;
        }

        bool operator!=(const Iterator& other) const {
            return index_ != other.index_;
        }

        auto operator*() const {
            uint32_t entity = (*view_->leadingEntities_)[index_];
            return makeResult(entity);
        }

    private:
        auto makeResult(uint32_t entity) const {
            return std::apply([entity](auto*... pools) {
                return std::tuple<Entity, decltype(getComponent<Components>(pools, entity))...>{
                    Entity{entity, 0},
                    getComponent<Components>(pools, entity)...
                };
            }, view_->allPools_);
        }

        template<typename C, typename Pool>
        static auto getComponent(Pool* pool, uint32_t entity) {
            if constexpr (is_optional<C>::value) {
                // Optional返回指针（可能为null）
                return pool->get(entity);
            } else if constexpr (is_exclude<C>::value) {
                // Exclude不返回数据
                return std::monostate{};
            } else {
                // 必需组件返回引用
                return std::ref(*pool->get(entity));
            }
        }
    };

    Iterator begin() const {
        return Iterator(this, 0, leadingEntities_->size());
    }

    Iterator end() const {
        return Iterator(this, leadingEntities_->size(),
                        leadingEntities_->size());
    }

    template<typename Func>
    void each(Func&& func) {
        for (auto it = begin(); it != end(); ++it) {
            std::apply(std::forward<Func>(func), *it);
        }
    }

    // 统计匹配的实体数量（不实际遍历组件）
    size_t count() const {
        size_t result = 0;
        for (size_t i = 0; i < leadingEntities_->size(); ++i) {
            uint32_t entity = (*leadingEntities_)[i];
            if (matchesAll(entity)) ++result;
        }
        return result;
    }

private:
    void findLeadingPool() {
        size_t minSize = SIZE_MAX;
        std::apply([&](auto*... pools) {
            ((updateLeading<Components>(pools, minSize)), ...);
        }, allPools_);
    }

    template<typename C, typename Pool>
    void updateLeading(Pool* pool, size_t& minSize) {
        if constexpr (!is_optional<C>::value && !is_exclude<C>::value) {
            if (pool->size() < minSize) {
                minSize = pool->size();
                leadingPool_ = pool;
                leadingEntities_ = &pool->entities();
            }
        }
    }

    bool matchesAll(uint32_t entity) const {
        return std::apply([entity](auto*... pools) {
            return (matchOne<Components>(pools, entity) && ...);
        }, allPools_);
    }

    template<typename C, typename Pool>
    static bool matchOne(Pool* pool, uint32_t entity) {
        if constexpr (is_optional<C>::value) {
            return true;
        } else if constexpr (is_exclude<C>::value) {
            return !pool->contains(entity);
        } else {
            return pool->contains(entity);
        }
    }
};
```

**变更检测系统（Tick-based Tracking）**
```
┌─────────────────────────────────────────────────────────────┐
│              Tick-based 变更检测                              │
└─────────────────────────────────────────────────────────────┘

核心思想：每个组件槽位记录最后一次修改的Tick（全局帧计数器）

World Tick: 全局递增计数器，每帧+1

                    World Tick = 42
                         │
  Position Pool:         │
  ┌──────────┬───────┐   │
  │ dense[0] │ tick=40│  │  ← 2帧前修改，Changed?  No
  │ dense[1] │ tick=42│  │  ← 本帧修改，  Changed?  Yes!
  │ dense[2] │ tick=38│  │  ← 4帧前修改，Changed?  No
  │ dense[3] │ tick=41│  │  ← 上帧修改，  Changed?  No
  └──────────┴───────┘   │

查询 query<Position>.changed<Position>() 时：
  只返回 tick == currentTick 的实体

实现关键：
  1. 组件池维护一个 tick 数组，与 dense 数组平行
  2. 每次 get_mut()（可变引用）时更新 tick
  3. 查询时比较 tick >= lastSystemTick
  4. 每个系统记录自己上次运行的 tick

优势（相比脏标记 dirty flag）：
  ✓ 不需要额外的清除步骤
  ✓ 多个系统可以独立追踪"上次检查时间"
  ✓ 可以查询"最近N帧内变化的组件"
  ✓ 线程安全（tick是单调递增的）
```

```cpp
// 带变更追踪的组件池
template<typename T>
class TrackedComponentPool : public ComponentPool<T> {
private:
    std::vector<uint64_t> changeTicks_;  // 与dense_平行
    std::vector<uint64_t> addTicks_;     // 组件被添加的tick

    uint64_t currentTick_ = 0;

public:
    void setCurrentTick(uint64_t tick) {
        currentTick_ = tick;
    }

    // 重写emplace，记录添加tick
    template<typename... Args>
    T& emplace(uint32_t entityIndex, Args&&... args) {
        T& result = ComponentPool<T>::emplace(
            entityIndex, std::forward<Args>(args)...);

        // 确保tick数组与dense数组同步
        size_t denseIdx = this->getDenseIndex(entityIndex);
        if (denseIdx >= changeTicks_.size()) {
            changeTicks_.resize(denseIdx + 1, currentTick_);
            addTicks_.resize(denseIdx + 1, currentTick_);
        } else {
            changeTicks_[denseIdx] = currentTick_;
            addTicks_[denseIdx] = currentTick_;
        }

        return result;
    }

    // 获取可变引用时标记为changed
    T& getMut(uint32_t entityIndex) {
        uint32_t denseIdx = this->getDenseIndex(entityIndex);
        changeTicks_[denseIdx] = currentTick_;
        return *this->get(entityIndex);
    }

    // 查询：组件是否在指定tick之后被修改
    bool changedSince(uint32_t entityIndex, uint64_t sinceTick) const {
        uint32_t denseIdx = this->getDenseIndex(entityIndex);
        if (denseIdx == UINT32_MAX) return false;
        return changeTicks_[denseIdx] > sinceTick;
    }

    // 查询：组件是否在指定tick之后被添加
    bool addedSince(uint32_t entityIndex, uint64_t sinceTick) const {
        uint32_t denseIdx = this->getDenseIndex(entityIndex);
        if (denseIdx == UINT32_MAX) return false;
        return addTicks_[denseIdx] > sinceTick;
    }

    uint64_t getChangeTick(uint32_t entityIndex) const {
        uint32_t denseIdx = this->getDenseIndex(entityIndex);
        return denseIdx < changeTicks_.size() ? changeTicks_[denseIdx] : 0;
    }

    // 遍历时同步tick数组的swap操作
    void remove(uint32_t entityIndex) override {
        uint32_t denseIdx = this->getDenseIndex(entityIndex);
        if (denseIdx == UINT32_MAX) return;

        // 同步tick数组的swap-and-pop
        if (denseIdx < changeTicks_.size() - 1) {
            changeTicks_[denseIdx] = changeTicks_.back();
            addTicks_[denseIdx] = addTicks_.back();
        }
        changeTicks_.pop_back();
        addTicks_.pop_back();

        ComponentPool<T>::remove(entityIndex);
    }
};

// 使用示例
void DamageHighlightSystem(World& world, float dt) {
    static uint64_t lastRunTick = 0;

    auto* healthPool = world.trackedPool<Health>();

    world.view<Transform, Health>().each(
        [&](Entity e, Transform& t, Health& h) {
            // 只处理上次运行后被修改的Health组件
            if (healthPool->changedSince(e.index, lastRunTick)) {
                // 生命值变化了，触发受伤闪烁效果
                // ...
            }
        }
    );

    lastRunTick = world.currentTick();
}
```

**Group机制（EnTT风格）**
```
┌─────────────────────────────────────────────────────────────┐
│              Group: Sparse Set的终极优化                      │
└─────────────────────────────────────────────────────────────┘

核心思想：预先排列多个池的实体顺序，
         使得共有实体连续排列在dense数组的前端

Before Group:
  Position dense: [P_5, P_0, P_3, P_7, P_2, P_4]
  Velocity dense: [V_0, V_7, V_3, V_2]

  共有实体: {0, 3, 7, 2}（但分散在各处）

After Group<Position, Velocity> (Owning):
  Position dense: [P_0, P_3, P_7, P_2, | P_5, P_4]
                   ←── group区域 ──→     ←非group→
  Velocity dense: [V_0, V_3, V_7, V_2]
                   ←── 完全对齐 ──→

  group_size = 4

遍历 group<Position, Velocity>：
  直接遍历 Position[0..3] 和 Velocity[0..3]
  → 无需任何contains检查！
  → 纯线性内存访问！
  → 等价于Archetype的遍历性能！

维护成本：
  添加组件时：将新实体swap到group区域末尾，group_size++
  删除组件时：将实体swap出group区域，group_size--
  → 每次变更O(1)，远比重新排序高效

限制：
  一个组件只能属于一个Owning Group
  （因为同一个dense数组不能同时为两个Group排序）
```

```cpp
// Group实现框架
template<typename... Owned>
class OwningGroup {
private:
    std::tuple<ComponentPool<Owned>*...> pools_;
    size_t groupSize_ = 0;  // group区域的大小

    // 获取第一个池作为参考（所有池的group区域大小一致）
    auto* primaryPool() {
        return std::get<0>(pools_);
    }

public:
    OwningGroup(ComponentPool<Owned>*... pools)
        : pools_(pools...) {}

    // 检查实体是否在group中
    bool inGroup(uint32_t entity) const {
        auto* pool = std::get<0>(pools_);
        uint32_t denseIdx = pool->getDenseIndex(entity);
        return denseIdx != UINT32_MAX && denseIdx < groupSize_;
    }

    // 当实体获得所有Owned组件时调用
    void tryAdd(uint32_t entity) {
        // 检查是否所有池都包含此实体
        bool hasAll = std::apply([entity](auto*... pools) {
            return (pools->contains(entity) && ...);
        }, pools_);

        if (!hasAll || inGroup(entity)) return;

        // 将实体swap到group区域的末尾
        std::apply([this, entity](auto*... pools) {
            (swapToGroupEnd(pools, entity), ...);
        }, pools_);

        ++groupSize_;
    }

    // 当实体失去任一Owned组件时调用
    void tryRemove(uint32_t entity) {
        if (!inGroup(entity)) return;

        --groupSize_;

        // 将实体swap到group区域之外
        std::apply([this, entity](auto*... pools) {
            (swapOutOfGroup(pools, entity), ...);
        }, pools_);
    }

    // 高效遍历：直接访问[0, groupSize_)，无需过滤！
    template<typename Func>
    void each(Func&& func) {
        auto& entities = primaryPool()->entities();

        for (size_t i = 0; i < groupSize_; ++i) {
            uint32_t entity = entities[i];
            func(Entity{entity, 0},
                 *std::get<ComponentPool<Owned>*>(pools_)->get(entity)...);
        }
    }

    size_t size() const { return groupSize_; }

private:
    template<typename Pool>
    void swapToGroupEnd(Pool* pool, uint32_t entity) {
        uint32_t entityDense = pool->getDenseIndex(entity);
        // 与group末尾的下一个位置交换
        pool->swapElements(entityDense, groupSize_);
    }

    template<typename Pool>
    void swapOutOfGroup(Pool* pool, uint32_t entity) {
        uint32_t entityDense = pool->getDenseIndex(entity);
        // 与group区域最后一个元素交换
        pool->swapElements(entityDense, groupSize_);
    }
};
```

**查询性能对比**
```
┌─────────────────────────────────────────────────────────────┐
│              查询模式性能对比（100万实体）                      │
└─────────────────────────────────────────────────────────────┘

测试环境：100万实体，80%有Position+Velocity，50%有Health

┌─────────────────────┬─────────┬──────────┬──────────┐
│ 查询模式            │ View    │ Group    │Archetype │
│                     │(SparseSet)│(SparseSet)│         │
├─────────────────────┼─────────┼──────────┼──────────┤
│ view<Pos>           │ 0.3ms   │  0.3ms   │  0.4ms   │
│ view<Pos, Vel>      │ 1.5ms   │  0.4ms   │  0.5ms   │
│ view<Pos, Vel, Hp>  │ 2.8ms   │  0.5ms   │  0.5ms   │
│ view<Pos>.without   │         │          │          │
│     <Static>        │ 1.8ms   │  1.2ms   │  0.4ms   │
│ view<Pos>.changed   │         │          │          │
│     <Pos>           │ 0.8ms*  │  0.4ms*  │  0.5ms*  │
└─────────────────────┴─────────┴──────────┴──────────┘

* changed查询需要额外的tick比较开销

关键观察：
  1. 单组件查询：Sparse Set略优（直接遍历dense数组）
  2. 多组件查询：Group ≈ Archetype >> 普通View
  3. 排除查询：Archetype天然支持（不匹配的Archetype直接跳过）
  4. 组件越多，View的交集检查开销越大
```

**设计决策分析**

```
┌─────────────────────────────────────────────────────────────┐
│           查询系统设计的关键决策                                │
└─────────────────────────────────────────────────────────────┘

决策1：返回引用 vs 返回拷贝
  引用 (std::reference_wrapper)：
    ✓ 零拷贝，直接修改原数据
    ✓ 适合大组件
    ✗ 生命周期风险（迭代期间不能修改结构）
    → EnTT和Bevy的选择

  拷贝：
    ✓ 安全，无生命周期问题
    ✗ 大组件有拷贝开销
    → 几乎没有ECS框架选择这个

决策2：延迟求值 vs 立即求值
  延迟求值（Iterator/Range）：
    ✓ 不需要预先分配结果数组
    ✓ 可以提前break
    ✓ 内存零开销
    → EnTT的View是延迟求值

  立即求值（收集到数组）：
    ✓ 可以多次遍历
    ✓ 可以随机访问
    ✗ 需要额外内存
    → 一般只在需要排序或多次遍历时使用

决策3：查询缓存
  Archetype方案必须缓存匹配的Archetype列表：
    → 新增Archetype时需要更新所有活跃查询的缓存
    → Bevy使用"query state"对象来缓存

  Sparse Set方案不需要缓存：
    → 每次查询直接从池构建View
    → 更简单，但可能有重复工作
```

**练习题**

```
练习1：实现带过滤器的View
  - 实现 view<Position, Velocity>().without<Static>()
  - 实现 view<Position, Optional<Velocity>>()
  - 验证：创建混合实体，确认过滤结果正确

练习2：实现变更检测
  - 在ComponentPool上添加tick追踪
  - 实现 changedSince(entity, tick) 查询
  - 编写测试：修改部分实体的Position，
    验证changed查询只返回被修改的实体

练习3：实现Owning Group
  - 为Position+Velocity创建一个Owning Group
  - 验证：添加/删除组件时group自动维护
  - 基准测试：对比Group遍历和普通View遍历的性能

练习4：查询性能分析
  - 创建50万实体，随机分配组件组合
  - 分别测试1组件、2组件、3组件、4组件查询
  - 绘制"组件数量-查询耗时"曲线
  - 分析：何时应该考虑使用Group替代普通View？

练习5：实现查询计数优化
  - 实现 view<A, B, C>().count() 的优化版本
  - 不需要获取组件引用，只统计匹配实体数量
  - 对比：优化版本 vs 普通each中累加计数的性能差异
```

---

### 第四周：系统调度与并行（35小时）

**学习目标**：
- [ ] 掌握系统依赖图的自动构建：从组件访问声明（Read/Write）推导系统间的happens-before关系
- [ ] 理解读写冲突的精确检测：Read-Read无冲突、Read-Write冲突、Write-Write冲突的分析
- [ ] 实现拓扑排序驱动的Stage划分：将依赖图分层，同一Stage内的系统可以安全并行
- [ ] 深入理解Command Buffer模式：为何系统执行期间不能直接进行结构变更（添加/删除组件、创建/销毁实体），延迟操作的设计与实现
- [ ] 掌握Job System的核心设计：任务队列、工作线程池、Work Stealing算法
- [ ] 理解并行安全模式：如何将View的遍历安全地分割到多个线程，避免数据竞争
- [ ] 能够实现完整的系统调度器：从注册系统、分析依赖、构建执行计划到并行执行的全流程
- [ ] 理解事件系统在ECS中的设计：即时事件 vs 延迟事件，事件队列与System的交互

**阅读材料**：
- [ ] Bevy ECS源码：`crates/bevy_ecs/src/schedule/` - Stage、SystemSet、依赖分析
- [ ] GDC 2017:《Parallelizing the Naughty Dog Engine Using Fibers》- Christian Gyrling
- [ ] CppCon 2016:《HPX: A C++ Standard Library for Parallelism and Concurrency》
- [ ] 《C++ Concurrency in Action》第7章 - Lock-free数据结构
- [ ] Unity DOTS文档:《System Update Order》与《JobSystem》
- [ ] Sander Mertens:《Building an ECS #4 - Systems》
- [ ] 论文：《A Dynamic Topological Sort Algorithm for DAGs》- David J. Pearce & Paul H.J. Kelly
- [ ] Sean Parent:《Better Code: Concurrency》演讲

---

#### 核心概念

**系统依赖图完整解析**
```
┌─────────────────────────────────────────────────────────────┐
│              从组件访问声明推导依赖关系                         │
└─────────────────────────────────────────────────────────────┘

系统声明其对组件的访问模式：

  InputSystem:      Read<Input>
  MovementSystem:   Read<Velocity>, Write<Position>
  PhysicsSystem:    Write<Velocity>, Read<Position>, Read<Mass>
  RenderSystem:     Read<Position>, Read<Sprite>
  AISystem:         Read<Position>, Write<Velocity>, Read<AIState>
  HealthSystem:     Read<Damage>, Write<Health>
  UISystem:         Read<Health>, Read<Score>

冲突矩阵（只有涉及至少一个Write才冲突）：

                Input  Move   Phys   Render  AI    Health  UI
  InputSystem    -      -      -      -      -      -      -
  MovementSys    -      -     R/W①   R②     R/W③   -      -
  PhysicsSys     -     W/R①   -      R④     W/W⑤   -      -
  RenderSys      -     R②    R④      -      -      -      -
  AISystem       -     W/R③  W/W⑤    -      -      -      -
  HealthSys      -      -      -      -      -      -     R⑥
  UISystem       -      -      -      -      -     R⑥      -

① Movement写Position，Physics读Position → 冲突！
② Movement写Position，Render读Position → 冲突！
③ Movement读Velocity，AI写Velocity → 冲突！
④ Physics读Position，Render读Position → 无冲突（都是Read）
⑤ Physics写Velocity，AI写Velocity → 冲突！
⑥ Health写Health，UI读Health → 冲突！

依赖图（DAG）：

        InputSystem
             │
             ▼
       MovementSystem ─────────────┐
        │         │                 │
        ▼         ▼                 ▼
  PhysicsSystem  AISystem      RenderSystem
  (冲突⑤互斥)   (冲突⑤互斥)        │
        │         │                 │
        ▼         ▼                 ▼
        └─── 同步点 ───┘           (可提前完成)
              │
              ▼
        HealthSystem
              │
              ▼
          UISystem
```

**拓扑排序与Stage划分**
```
┌─────────────────────────────────────────────────────────────┐
│              Stage划分：最大化并行度                           │
└─────────────────────────────────────────────────────────────┘

拓扑排序后的Stage划分：

Stage 0: [InputSystem]
          → 无依赖，单独执行
          → 1个系统

Stage 1: [MovementSystem, HealthSystem]
          → Movement依赖Input（Stage 0已完成）
          → Health无冲突，可以并行
          → 2个系统并行

Stage 2: [PhysicsSystem, AISystem, RenderSystem]
          → Physics和AI都写Velocity → 互斥！不能并行
          → Render只读Position → 可与Physics或AI并行
          → 选择：Physics || Render，然后AI
          → 或者：AI || Render，然后Physics

Stage 3: [UISystem]
          → 依赖HealthSystem（Stage 1完成）
          → 1个系统

优化后的执行时间线：

Thread 1: [Input]──[Movement]──[Physics ]──[  AI   ]──[UI]
Thread 2:          [Health  ]──[Render  ]──[       ]──[  ]
                                 ↑
                        与Physics并行（无冲突）

总时间 = max(各阶段时间) 而非 sum(所有系统时间)
```

```cpp
// 完整的系统调度器实现
class SystemScheduler {
public:
    // 组件访问模式
    enum class AccessMode { Read, Write };

    struct ComponentAccess {
        ComponentId componentId;
        AccessMode mode;
    };

    struct SystemInfo {
        std::string name;
        std::function<void(World&, float)> execute;
        std::vector<ComponentAccess> accesses;
        int explicitOrder = 0;  // 用户指定的顺序提示
    };

private:
    std::vector<SystemInfo> systems_;
    std::vector<std::vector<size_t>> stages_;  // 每个Stage包含的系统索引
    bool dirty_ = true;  // 是否需要重建调度

    // 检测两个系统是否有冲突
    bool hasConflict(const SystemInfo& a, const SystemInfo& b) const {
        for (const auto& accessA : a.accesses) {
            for (const auto& accessB : b.accesses) {
                if (accessA.componentId != accessB.componentId) continue;

                // Read-Read无冲突
                if (accessA.mode == AccessMode::Read &&
                    accessB.mode == AccessMode::Read) continue;

                // Read-Write 或 Write-Write 都冲突
                return true;
            }
        }
        return false;
    }

    // 构建依赖图并进行拓扑排序
    void buildSchedule() {
        size_t n = systems_.size();

        // 构建正向图（谁在谁前面）
        std::vector<std::vector<size_t>> forward(n);
        std::vector<size_t> indeg(n, 0);

        for (size_t i = 0; i < n; ++i) {
            for (size_t j = 0; j < i; ++j) {
                if (hasConflict(systems_[i], systems_[j])) {
                    forward[j].push_back(i);  // j → i（j先执行）
                    ++indeg[i];
                }
            }
        }

        // Kahn's Algorithm拓扑排序 + 分层
        stages_.clear();
        std::vector<size_t> currentLayer;

        // 找所有入度为0的节点
        for (size_t i = 0; i < n; ++i) {
            if (indeg[i] == 0) {
                currentLayer.push_back(i);
            }
        }

        while (!currentLayer.empty()) {
            stages_.push_back(currentLayer);
            std::vector<size_t> nextLayer;

            for (size_t node : currentLayer) {
                for (size_t neighbor : forward[node]) {
                    --indeg[neighbor];
                    if (indeg[neighbor] == 0) {
                        nextLayer.push_back(neighbor);
                    }
                }
            }

            currentLayer = std::move(nextLayer);
        }

        dirty_ = false;
    }

public:
    // 注册系统
    template<typename... ReadComps, typename... WriteComps>
    void addSystem(const std::string& name,
                   std::function<void(World&, float)> func,
                   std::tuple<ReadComps...> reads = {},
                   std::tuple<WriteComps...> writes = {}) {
        SystemInfo info;
        info.name = name;
        info.execute = std::move(func);

        // 收集Read访问
        std::apply([&](auto... types) {
            ((info.accesses.push_back({
                TypeIdGenerator::get<decltype(types)>(),
                AccessMode::Read
            })), ...);
        }, reads);

        // 收集Write访问
        std::apply([&](auto... types) {
            ((info.accesses.push_back({
                TypeIdGenerator::get<decltype(types)>(),
                AccessMode::Write
            })), ...);
        }, writes);

        systems_.push_back(std::move(info));
        dirty_ = true;
    }

    // 执行所有系统
    void execute(World& world, float dt) {
        if (dirty_) buildSchedule();

        for (const auto& stage : stages_) {
            if (stage.size() == 1) {
                // 单系统Stage，直接执行
                systems_[stage[0]].execute(world, dt);
            } else {
                // 多系统Stage，并行执行
                std::vector<std::thread> threads;
                for (size_t sysIdx : stage) {
                    threads.emplace_back([&, sysIdx]() {
                        systems_[sysIdx].execute(world, dt);
                    });
                }
                for (auto& t : threads) {
                    t.join();
                }
            }
        }
    }

    // 打印调度计划（用于调试）
    void printSchedule() const {
        for (size_t i = 0; i < stages_.size(); ++i) {
            std::cout << "Stage " << i << ": [";
            for (size_t j = 0; j < stages_[i].size(); ++j) {
                if (j > 0) std::cout << ", ";
                std::cout << systems_[stages_[i][j]].name;
            }
            std::cout << "]\n";
        }
    }
};
```

**Command Buffer 模式深入**
```
┌─────────────────────────────────────────────────────────────┐
│              为什么需要 Command Buffer？                      │
└─────────────────────────────────────────────────────────────┘

问题场景：在MovementSystem遍历所有实体时，
         发现一个实体出界了，想立即销毁它

  world.view<Position, Velocity>().each(
      [&](Entity e, Position& pos, Velocity& vel) {
          pos.x += vel.x * dt;
          if (pos.x > 1000.0f) {
              world.destroyEntity(e);  // 危险！！！
              // destroyEntity会修改sparse/dense数组
              // 正在遍历的迭代器可能失效！
              // → 未定义行为！
          }
      }
  );

还有更多危险操作：
  ✗ 在遍历中创建新实体（可能导致重新分配）
  ✗ 在遍历中添加/删除组件（修改池结构）
  ✗ 在并行遍历中修改共享状态

解决方案：Command Buffer —— 收集命令，延迟执行

  world.view<Position, Velocity>().each(
      [&](Entity e, Position& pos, Velocity& vel) {
          pos.x += vel.x * dt;
          if (pos.x > 1000.0f) {
              commands.destroyEntity(e);  // 记录命令，不立即执行
          }
      }
  );

  commands.flush(world);  // 遍历结束后，统一执行所有命令

优势：
  ✓ 遍历期间数据结构不变 → 迭代器安全
  ✓ 命令可以批量优化（合并重复操作）
  ✓ 天然线程安全（每个线程一个CommandBuffer）
  ✓ 可以在flush前检查/回滚命令
```

```cpp
// 完整的Command Buffer实现
class CommandBuffer {
public:
    // 命令类型
    struct CreateEntityCmd {
        Entity entity;  // 预分配的Entity ID
    };

    struct DestroyEntityCmd {
        Entity entity;
    };

    struct AddComponentCmd {
        Entity entity;
        ComponentId componentId;
        std::function<void(World&, Entity)> apply;
    };

    struct RemoveComponentCmd {
        Entity entity;
        ComponentId componentId;
    };

    // 使用variant统一存储
    using Command = std::variant<
        CreateEntityCmd,
        DestroyEntityCmd,
        AddComponentCmd,
        RemoveComponentCmd
    >;

private:
    std::vector<Command> commands_;
    // 用于线程安全的版本
    mutable std::mutex mutex_;

public:
    // 记录：销毁实体
    void destroyEntity(Entity entity) {
        commands_.emplace_back(DestroyEntityCmd{entity});
    }

    // 记录：添加组件
    template<typename T, typename... Args>
    void addComponent(Entity entity, Args&&... args) {
        // 捕获参数到lambda中延迟执行
        auto captured = std::make_shared<std::tuple<std::decay_t<Args>...>>(
            std::forward<Args>(args)...);

        commands_.emplace_back(AddComponentCmd{
            entity,
            TypeIdGenerator::get<T>(),
            [captured](World& world, Entity e) {
                std::apply([&](auto&&... cArgs) {
                    world.addComponent<T>(e, std::move(cArgs)...);
                }, std::move(*captured));
            }
        });
    }

    // 记录：删除组件
    template<typename T>
    void removeComponent(Entity entity) {
        commands_.emplace_back(RemoveComponentCmd{
            entity,
            TypeIdGenerator::get<T>()
        });
    }

    // 线程安全版本的记录
    void destroyEntityThreadSafe(Entity entity) {
        std::lock_guard<std::mutex> lock(mutex_);
        destroyEntity(entity);
    }

    // 执行所有命令
    void flush(World& world) {
        // 按类型优先级排序：先创建，再添加组件，
        // 再删除组件，最后销毁实体
        std::stable_sort(commands_.begin(), commands_.end(),
            [](const Command& a, const Command& b) {
                return a.index() < b.index();
            });

        for (auto& cmd : commands_) {
            std::visit([&world](auto& c) {
                executeCommand(world, c);
            }, cmd);
        }

        commands_.clear();
    }

    size_t pendingCount() const { return commands_.size(); }
    bool empty() const { return commands_.empty(); }

    // 清除所有待执行命令（回滚）
    void clear() { commands_.clear(); }

private:
    static void executeCommand(World& world, CreateEntityCmd& cmd) {
        // Entity已经预分配了ID
    }

    static void executeCommand(World& world, DestroyEntityCmd& cmd) {
        world.destroyEntity(cmd.entity);
    }

    static void executeCommand(World& world, AddComponentCmd& cmd) {
        if (world.isValid(cmd.entity)) {
            cmd.apply(world, cmd.entity);
        }
    }

    static void executeCommand(World& world, RemoveComponentCmd& cmd) {
        // 需要通过ComponentId动态删除
        // 实际实现需要World提供removeComponentById接口
    }
};

// 使用示例
void BulletSystem(World& world, float dt) {
    CommandBuffer commands;

    world.view<Transform, Velocity, Lifetime>().each(
        [&](Entity e, Transform& t, Velocity& v, Lifetime& life) {
            t.x += v.x * dt;
            t.y += v.y * dt;
            t.z += v.z * dt;

            life.remaining -= dt;
            if (life.remaining <= 0) {
                commands.destroyEntity(e);  // 安全：不影响遍历
            }
        }
    );

    commands.flush(world);  // 遍历完成后统一执行
}
```

**Job System设计**
```
┌─────────────────────────────────────────────────────────────┐
│              Job System 架构                                 │
└─────────────────────────────────────────────────────────────┘

                    ┌──────────┐
                    │ Main     │
                    │ Thread   │
                    └────┬─────┘
                         │ submit jobs
                    ┌────▼─────┐
                    │  Global  │
                    │  Queue   │
                    └────┬─────┘
                         │ dispatch
              ┌──────────┼──────────┐
              ▼          ▼          ▼
         ┌────────┐ ┌────────┐ ┌────────┐
         │Worker 0│ │Worker 1│ │Worker 2│
         │        │ │        │ │        │
         │ Local  │ │ Local  │ │ Local  │
         │ Queue  │ │ Queue  │ │ Queue  │
         └───┬────┘ └───┬────┘ └───┬────┘
             │          │          │
             └─── Work Stealing ───┘
              (空闲时从其他worker偷任务)

Work Stealing算法：
  1. Worker从自己的Local Queue取任务
  2. Local Queue为空 → 从Global Queue取
  3. Global Queue也空 → 随机选一个其他Worker，偷其队列尾部的任务
  4. 都没有 → 等待（条件变量或spin-wait）

为什么Work Stealing好？
  ✓ 自动负载均衡
  ✓ 减少全局竞争（大部分操作在Local Queue）
  ✓ 偷的是大任务（队列尾部 = 先入队 = 通常更大）
```

```cpp
// 简化的Job System实现
class JobSystem {
public:
    using Job = std::function<void()>;

private:
    // 线程安全的任务队列（简化版，实际应用lock-free deque）
    struct WorkQueue {
        std::deque<Job> queue;
        mutable std::mutex mutex;

        void push(Job job) {
            std::lock_guard lock(mutex);
            queue.push_back(std::move(job));
        }

        bool tryPop(Job& job) {
            std::lock_guard lock(mutex);
            if (queue.empty()) return false;
            job = std::move(queue.front());
            queue.pop_front();
            return true;
        }

        // Work Stealing: 从尾部偷
        bool trySteal(Job& job) {
            std::lock_guard lock(mutex);
            if (queue.empty()) return false;
            job = std::move(queue.back());
            queue.pop_back();
            return true;
        }

        bool empty() const {
            std::lock_guard lock(mutex);
            return queue.empty();
        }
    };

    std::vector<std::thread> workers_;
    std::vector<WorkQueue> localQueues_;
    WorkQueue globalQueue_;

    std::atomic<bool> running_{true};
    std::condition_variable cv_;
    std::mutex cvMutex_;

    size_t workerCount_;

    void workerLoop(size_t workerId) {
        while (running_) {
            Job job;

            // 1. 尝试从本地队列取
            if (localQueues_[workerId].tryPop(job)) {
                job();
                continue;
            }

            // 2. 尝试从全局队列取
            if (globalQueue_.tryPop(job)) {
                job();
                continue;
            }

            // 3. 尝试从其他worker偷
            bool stolen = false;
            for (size_t i = 0; i < workerCount_; ++i) {
                if (i == workerId) continue;
                if (localQueues_[i].trySteal(job)) {
                    job();
                    stolen = true;
                    break;
                }
            }

            if (!stolen) {
                // 4. 没有任务，等待
                std::unique_lock lock(cvMutex_);
                cv_.wait_for(lock, std::chrono::microseconds(100));
            }
        }
    }

public:
    explicit JobSystem(size_t threadCount = 0)
        : workerCount_(threadCount ? threadCount
                       : std::thread::hardware_concurrency()) {
        localQueues_.resize(workerCount_);

        for (size_t i = 0; i < workerCount_; ++i) {
            workers_.emplace_back(&JobSystem::workerLoop, this, i);
        }
    }

    ~JobSystem() {
        running_ = false;
        cv_.notify_all();
        for (auto& w : workers_) {
            w.join();
        }
    }

    // 提交Job到全局队列
    void submit(Job job) {
        globalQueue_.push(std::move(job));
        cv_.notify_one();
    }

    // 并行for：将范围[begin, end)分割到多个worker
    template<typename Func>
    void parallelFor(size_t begin, size_t end, Func&& func,
                     size_t minBatchSize = 64) {
        size_t count = end - begin;
        if (count <= minBatchSize) {
            for (size_t i = begin; i < end; ++i) {
                func(i);
            }
            return;
        }

        size_t batchSize = std::max(minBatchSize,
            (count + workerCount_ - 1) / workerCount_);
        std::atomic<size_t> completedBatches{0};
        size_t totalBatches = (count + batchSize - 1) / batchSize;

        for (size_t start = begin; start < end; start += batchSize) {
            size_t batchEnd = std::min(start + batchSize, end);

            submit([&func, start, batchEnd, &completedBatches]() {
                for (size_t i = start; i < batchEnd; ++i) {
                    func(i);
                }
                ++completedBatches;
            });
        }

        // 等待所有batch完成
        while (completedBatches.load() < totalBatches) {
            // 主线程也参与工作
            Job job;
            if (globalQueue_.tryPop(job)) {
                job();
            } else {
                std::this_thread::yield();
            }
        }
    }
};

// 与ECS结合使用
void parallelMovementSystem(World& world, float dt,
                             JobSystem& jobSystem) {
    auto* posPool = world.pool<Transform>();
    auto* velPool = world.pool<Velocity>();

    const auto& entities = posPool->entities();
    const size_t count = entities.size();

    jobSystem.parallelFor(0, count,
        [&](size_t i) {
            uint32_t entity = entities[i];
            auto* vel = velPool->get(entity);
            if (!vel) return;

            auto* pos = posPool->get(entity);
            pos->x += vel->x * dt;
            pos->y += vel->y * dt;
            pos->z += vel->z * dt;
        },
        256  // 每批至少256个实体（避免过细粒度）
    );
}
```

**事件系统设计**
```
┌─────────────────────────────────────────────────────────────┐
│              ECS中的事件系统                                  │
└─────────────────────────────────────────────────────────────┘

方式1：组件作为事件（Bevy风格）
  → 创建一个实体，附加"事件组件"
  → 系统查询该组件即可接收事件
  → 下一帧清除事件实体

  // 发送事件
  Entity event = world.createEntity();
  world.addComponent<DamageEvent>(event, {attacker, target, 50});

  // 接收事件
  world.view<DamageEvent>().each([](Entity e, DamageEvent& dmg) {
      // 处理伤害
  });

  // 清除
  world.view<DamageEvent>().each([&](Entity e, DamageEvent& dmg) {
      world.destroyEntityDeferred(e);
  });

  优点：完全复用ECS查询机制
  缺点：创建/销毁实体有开销

方式2：事件队列（独立于ECS）
  → 类型安全的事件总线
  → 生产者/消费者模式

方式3：观察者模式（EnTT风格）
  → 组件的 on_construct / on_destroy / on_update 回调
  → 当组件被添加/删除/修改时自动触发
```

```cpp
// 方式2: 类型安全的事件队列
template<typename T>
class EventQueue {
    // 双缓冲：当前帧的事件 + 上一帧的事件
    std::vector<T> current_;
    std::vector<T> previous_;

public:
    // 发送事件
    void send(const T& event) {
        current_.push_back(event);
    }

    template<typename... Args>
    void emit(Args&&... args) {
        current_.emplace_back(std::forward<Args>(args)...);
    }

    // 读取事件（上一帧的）
    class EventReader {
        const std::vector<T>* events_;
        size_t cursor_ = 0;

    public:
        explicit EventReader(const std::vector<T>* events)
            : events_(events) {}

        bool hasNext() const { return cursor_ < events_->size(); }
        const T& next() { return (*events_)[cursor_++]; }

        // Range-for支持
        auto begin() const { return events_->begin(); }
        auto end() const { return events_->end(); }
    };

    EventReader reader() const {
        return EventReader(&previous_);
    }

    // 每帧结束时调用
    void update() {
        previous_ = std::move(current_);
        current_.clear();
    }

    size_t currentCount() const { return current_.size(); }
    size_t previousCount() const { return previous_.size(); }
};

// 事件管理器
class EventManager {
    std::unordered_map<std::type_index,
                       std::shared_ptr<void>> queues_;

public:
    template<typename T>
    EventQueue<T>& getQueue() {
        auto key = std::type_index(typeid(T));
        auto it = queues_.find(key);
        if (it == queues_.end()) {
            auto queue = std::make_shared<EventQueue<T>>();
            queues_[key] = queue;
            return *queue;
        }
        return *static_cast<EventQueue<T>*>(it->second.get());
    }

    template<typename T>
    void send(const T& event) {
        getQueue<T>().send(event);
    }

    template<typename T>
    typename EventQueue<T>::EventReader read() {
        return getQueue<T>().reader();
    }

    void updateAll() {
        // 需要对每个队列调用update()
        // 实际实现需要类型擦除的update接口
    }
};

// 使用示例
struct CollisionEvent {
    Entity entityA;
    Entity entityB;
    float penetration;
};

struct DamageEvent {
    Entity target;
    Entity source;
    int amount;
};

void CollisionDetectionSystem(World& world, float dt) {
    auto& collisionEvents = world.events().getQueue<CollisionEvent>();

    // ... 检测碰撞 ...
    // collisionEvents.emit(CollisionEvent{entityA, entityB, 0.5f});
}

void DamageOnCollisionSystem(World& world, float dt) {
    auto& collisionEvents = world.events().getQueue<CollisionEvent>();
    auto& damageEvents = world.events().getQueue<DamageEvent>();

    for (const auto& collision : collisionEvents.reader()) {
        // 碰撞导致伤害
        damageEvents.emit(DamageEvent{
            collision.entityB, collision.entityA, 10
        });
    }
}
```

**并行安全模式总结**
```
┌─────────────────────────────────────────────────────────────┐
│              ECS并行安全的核心原则                              │
└─────────────────────────────────────────────────────────────┘

规则1：同一组件的Write-Write冲突
  → 两个系统不能同时写同一个组件类型
  → 调度器自动检测并排序

规则2：同一组件的Read-Write冲突
  → 一个系统写、另一个读同一组件 → 不能并行
  → 除非能保证它们操作不同的实体（细粒度锁）

规则3：结构变更必须延迟
  → 创建/销毁实体 → Command Buffer
  → 添加/删除组件 → Command Buffer
  → 永远不在遍历中直接修改结构

规则4：View的并行分割
  → 将实体范围[0, N)分成多个chunk
  → 每个chunk由一个线程处理
  → 组件数据按实体隔离 → 天然无冲突

规则5：共享资源需要同步
  → 全局计数器 → std::atomic
  → 全局配置 → 只读或mutex保护
  → 事件队列 → 线程局部+合并 或 lock-free queue

安全并行的ECS循环：
  ┌───────────────────────────┐
  │ 1. Flush Command Buffers  │ ← 单线程
  │ 2. Update Event Queues    │ ← 单线程
  ├───────────────────────────┤
  │ 3. Execute Stage 0        │ ← 按调度器并行
  │ 4. Execute Stage 1        │ ← 按调度器并行
  │ 5. ...                    │
  ├───────────────────────────┤
  │ 6. Flush Command Buffers  │ ← 单线程
  │ 7. Update Event Queues    │ ← 单线程
  └───────────────────────────┘
```

**设计决策分析**

```
┌─────────────────────────────────────────────────────────────┐
│           调度与并行的关键决策                                  │
└─────────────────────────────────────────────────────────────┘

决策1：显式依赖声明 vs 自动推导
  显式声明（用户手动指定before/after）：
    ✓ 简单直观
    ✗ 容易出错（忘记声明依赖）
    → Unity旧版的做法

  自动推导（从Read/Write声明推导）：
    ✓ 不会遗漏依赖
    ✓ 新增系统自动适配
    ✗ 可能过于保守（不必要的序列化）
    → Bevy的做法

  最佳实践：自动推导 + 显式覆盖
    → 默认按Read/Write自动排序
    → 允许用户 .before() / .after() 手动调整

决策2：固定Stage vs 动态调度
  固定Stage（每帧开始前确定执行计划）：
    ✓ 可预测的执行顺序
    ✓ 调试友好
    → 大多数游戏引擎的选择

  动态调度（运行时根据任务完成情况决定下一个）：
    ✓ 更好的负载均衡
    ✗ 执行顺序不可预测
    → 适合高吞吐量服务器

决策3：Command Buffer的执行时机
  每个Stage结束后执行：
    ✓ 结构变更更及时
    ✗ Stage间有同步开销

  每帧结束执行一次：
    ✓ 最少的同步开销
    ✓ 命令可以批量优化
    ✗ 结构变更延迟一帧
    → 大多数ECS框架的默认选择

  两者都支持（用户选择）：
    → Bevy的做法：apply_deferred可以插入到任意位置
```

**练习题**

```
练习1：实现自动依赖分析
  - 实现SystemScheduler，支持从Read/Write声明推导依赖
  - 使用Kahn算法进行拓扑排序和Stage划分
  - 测试：注册5-8个系统，打印生成的Stage计划
  - 验证：手动分析依赖是否与自动推导一致

练习2：实现Command Buffer
  - 支持 destroyEntity, addComponent, removeComponent
  - 支持 flush() 批量执行
  - 测试：在遍历中记录命令，遍历后flush
  - 验证：flush后实体状态正确

练习3：实现简化Job System
  - 实现线程池 + 全局任务队列
  - 实现 parallelFor 分批处理
  - 基准测试：100万实体的Movement系统
  - 对比：单线程 vs 2线程 vs 4线程 vs 8线程的加速比

练习4：集成测试 - 完整的ECS主循环
  - 整合：World + Scheduler + CommandBuffer + EventSystem
  - 注册至少5个系统（包含冲突和可并行的）
  - 运行100帧模拟
  - 验证：数据一致性、无崩溃、性能合理

练习5：调度可视化
  - 实现调度器的可视化输出（ASCII时间线图）
  - 显示每个Stage包含的系统
  - 标注哪些系统是并行的，哪些是串行的
  - 计算理论并行加速比
```


---

## 源码阅读任务

### 必读项目

1. **EnTT** (https://github.com/skypjack/entt)
   - 重点文件：`src/entt/entity/`, `src/entt/core/`
   - 学习目标：理解Sparse Set ECS实现
   - 阅读时间：15小时

2. **Flecs** (https://github.com/SanderMertens/flecs)
   - 重点：查询系统和关系
   - 学习目标：理解高级ECS特性
   - 阅读时间：10小时

3. **Bevy ECS** (https://github.com/bevyengine/bevy)
   - 重点：`crates/bevy_ecs/`
   - 学习目标：理解Archetype存储
   - 阅读时间：8小时

---

## 实践项目：高性能ECS框架

### 项目概述
从零构建一个高性能ECS框架，支持高效查询、系统调度和并行执行。

### 完整代码实现

#### 1. 基础类型定义 (ecs/core/types.hpp)

```cpp
#pragma once

#include <cstdint>
#include <limits>
#include <typeindex>
#include <typeinfo>
#include <atomic>

namespace ecs {

// Entity ID: 32位索引 + 32位版本
struct Entity {
    uint32_t index;
    uint32_t version;

    bool operator==(const Entity& other) const {
        return index == other.index && version == other.version;
    }

    bool operator!=(const Entity& other) const {
        return !(*this == other);
    }

    bool isValid() const {
        return index != UINT32_MAX;
    }

    static Entity invalid() {
        return {UINT32_MAX, 0};
    }
};

// Entity哈希（用于unordered_map）
struct EntityHash {
    size_t operator()(const Entity& e) const {
        return std::hash<uint64_t>()(
            (static_cast<uint64_t>(e.version) << 32) | e.index
        );
    }
};

// 组件类型ID
using ComponentId = uint32_t;

// 类型ID生成器
class TypeIdGenerator {
    static std::atomic<ComponentId> counter_;

public:
    template<typename T>
    static ComponentId get() {
        static ComponentId id = counter_++;
        return id;
    }
};

inline std::atomic<ComponentId> TypeIdGenerator::counter_{0};

// 组件类型信息
struct ComponentInfo {
    ComponentId id;
    size_t size;
    size_t alignment;
    std::string name;

    // 构造/析构函数指针
    void (*construct)(void*);
    void (*destruct)(void*);
    void (*move)(void* dst, void* src);
    void (*copy)(void* dst, const void* src);
};

template<typename T>
ComponentInfo makeComponentInfo() {
    return ComponentInfo{
        TypeIdGenerator::get<T>(),
        sizeof(T),
        alignof(T),
        typeid(T).name(),
        [](void* ptr) { new (ptr) T(); },
        [](void* ptr) { static_cast<T*>(ptr)->~T(); },
        [](void* dst, void* src) {
            new (dst) T(std::move(*static_cast<T*>(src)));
        },
        [](void* dst, const void* src) {
            new (dst) T(*static_cast<const T*>(src));
        }
    };
}

// 组件掩码（用于快速组件组合判断）
using ComponentMask = uint64_t;

constexpr size_t MAX_COMPONENTS = 64;

template<typename... Ts>
ComponentMask makeMask() {
    ComponentMask mask = 0;
    ((mask |= (1ULL << TypeIdGenerator::get<Ts>())), ...);
    return mask;
}

} // namespace ecs
```

#### 2. 组件存储池 (ecs/storage/component_pool.hpp)

```cpp
#pragma once

#include "../core/types.hpp"
#include <vector>
#include <memory>
#include <cstring>

namespace ecs {

// 非类型安全的组件池基类
class ComponentPoolBase {
public:
    virtual ~ComponentPoolBase() = default;
    virtual void remove(uint32_t index) = 0;
    virtual bool contains(uint32_t index) const = 0;
    virtual size_t size() const = 0;
    virtual void* getRaw(uint32_t index) = 0;
    virtual const ComponentInfo& info() const = 0;
};

// 类型安全的组件池（Sparse Set实现）
template<typename T>
class ComponentPool : public ComponentPoolBase {
private:
    std::vector<T> dense_;           // 组件数据
    std::vector<uint32_t> sparse_;   // Entity索引 -> dense索引
    std::vector<uint32_t> entities_; // dense索引 -> Entity索引
    ComponentInfo info_;

    static constexpr uint32_t INVALID = UINT32_MAX;

    void ensureSparseSize(uint32_t index) {
        if (index >= sparse_.size()) {
            sparse_.resize(index + 1, INVALID);
        }
    }

public:
    ComponentPool() : info_(makeComponentInfo<T>()) {}

    // 插入组件
    template<typename... Args>
    T& emplace(uint32_t entityIndex, Args&&... args) {
        ensureSparseSize(entityIndex);

        if (sparse_[entityIndex] != INVALID) {
            // 已存在，替换
            return dense_[sparse_[entityIndex]] = T(std::forward<Args>(args)...);
        }

        // 新增
        sparse_[entityIndex] = static_cast<uint32_t>(dense_.size());
        dense_.emplace_back(std::forward<Args>(args)...);
        entities_.push_back(entityIndex);

        return dense_.back();
    }

    // 插入组件（拷贝）
    T& insert(uint32_t entityIndex, const T& component) {
        return emplace(entityIndex, component);
    }

    // 移除组件
    void remove(uint32_t entityIndex) override {
        if (entityIndex >= sparse_.size() || sparse_[entityIndex] == INVALID) {
            return;
        }

        uint32_t denseIdx = sparse_[entityIndex];
        uint32_t lastEntity = entities_.back();

        // 交换到末尾
        if (denseIdx != dense_.size() - 1) {
            dense_[denseIdx] = std::move(dense_.back());
            entities_[denseIdx] = lastEntity;
            sparse_[lastEntity] = denseIdx;
        }

        dense_.pop_back();
        entities_.pop_back();
        sparse_[entityIndex] = INVALID;
    }

    // 获取组件
    T* get(uint32_t entityIndex) {
        if (entityIndex >= sparse_.size() || sparse_[entityIndex] == INVALID) {
            return nullptr;
        }
        return &dense_[sparse_[entityIndex]];
    }

    const T* get(uint32_t entityIndex) const {
        if (entityIndex >= sparse_.size() || sparse_[entityIndex] == INVALID) {
            return nullptr;
        }
        return &dense_[sparse_[entityIndex]];
    }

    void* getRaw(uint32_t entityIndex) override {
        return get(entityIndex);
    }

    // 检查是否包含
    bool contains(uint32_t entityIndex) const override {
        return entityIndex < sparse_.size() && sparse_[entityIndex] != INVALID;
    }

    // 大小
    size_t size() const override { return dense_.size(); }

    // 组件信息
    const ComponentInfo& info() const override { return info_; }

    // 迭代器
    auto begin() { return dense_.begin(); }
    auto end() { return dense_.end(); }
    auto begin() const { return dense_.begin(); }
    auto end() const { return dense_.end(); }

    // 获取实体列表
    const std::vector<uint32_t>& entities() const { return entities_; }

    // 获取dense数组（用于批量操作）
    T* data() { return dense_.data(); }
    const T* data() const { return dense_.data(); }

    // 获取dense索引
    uint32_t getDenseIndex(uint32_t entityIndex) const {
        if (entityIndex >= sparse_.size()) return INVALID;
        return sparse_[entityIndex];
    }
};

} // namespace ecs
```

#### 3. 实体管理器 (ecs/core/entity_manager.hpp)

```cpp
#pragma once

#include "types.hpp"
#include <vector>
#include <queue>
#include <cassert>

namespace ecs {

class EntityManager {
private:
    std::vector<uint32_t> versions_;       // 每个槽位的版本号
    std::vector<ComponentMask> masks_;      // 每个实体的组件掩码
    std::queue<uint32_t> freeList_;         // 可重用的槽位
    uint32_t entityCount_ = 0;

public:
    // 创建实体
    Entity create() {
        uint32_t index;

        if (!freeList_.empty()) {
            index = freeList_.front();
            freeList_.pop();
        } else {
            index = static_cast<uint32_t>(versions_.size());
            versions_.push_back(0);
            masks_.push_back(0);
        }

        ++entityCount_;
        return Entity{index, versions_[index]};
    }

    // 销毁实体
    void destroy(Entity entity) {
        if (!isValid(entity)) return;

        // 增加版本号使旧引用失效
        ++versions_[entity.index];
        masks_[entity.index] = 0;
        freeList_.push(entity.index);
        --entityCount_;
    }

    // 验证实体
    bool isValid(Entity entity) const {
        return entity.index < versions_.size() &&
               versions_[entity.index] == entity.version;
    }

    // 组件掩码操作
    void addComponent(Entity entity, ComponentId componentId) {
        if (isValid(entity)) {
            masks_[entity.index] |= (1ULL << componentId);
        }
    }

    void removeComponent(Entity entity, ComponentId componentId) {
        if (isValid(entity)) {
            masks_[entity.index] &= ~(1ULL << componentId);
        }
    }

    bool hasComponent(Entity entity, ComponentId componentId) const {
        if (!isValid(entity)) return false;
        return (masks_[entity.index] & (1ULL << componentId)) != 0;
    }

    ComponentMask getMask(Entity entity) const {
        if (!isValid(entity)) return 0;
        return masks_[entity.index];
    }

    bool matchesMask(Entity entity, ComponentMask requiredMask) const {
        if (!isValid(entity)) return false;
        return (masks_[entity.index] & requiredMask) == requiredMask;
    }

    // 统计
    uint32_t count() const { return entityCount_; }
    uint32_t capacity() const { return static_cast<uint32_t>(versions_.size()); }
};

} // namespace ecs
```

#### 4. 视图/查询系统 (ecs/query/view.hpp)

```cpp
#pragma once

#include "../storage/component_pool.hpp"
#include <tuple>
#include <algorithm>

namespace ecs {

// 查找最小池的辅助
template<typename... Pools>
auto* findSmallestPool(Pools*... pools) {
    std::array<std::pair<size_t, ComponentPoolBase*>, sizeof...(Pools)> sizes = {
        std::make_pair(pools->size(), static_cast<ComponentPoolBase*>(pools))...
    };
    auto it = std::min_element(sizes.begin(), sizes.end(),
        [](const auto& a, const auto& b) { return a.first < b.first; });
    return it->second;
}

// View迭代器
template<typename... Ts>
class ViewIterator {
private:
    std::tuple<ComponentPool<Ts>*...> pools_;
    const std::vector<uint32_t>* entities_;
    size_t index_;
    size_t endIndex_;

    bool isValid() const {
        if (index_ >= endIndex_) return false;

        uint32_t entity = (*entities_)[index_];

        // 检查所有池都包含此实体
        return std::apply([entity](auto*... pools) {
            return (pools->contains(entity) && ...);
        }, pools_);
    }

    void advance() {
        ++index_;
        while (index_ < endIndex_ && !isValid()) {
            ++index_;
        }
    }

public:
    ViewIterator(std::tuple<ComponentPool<Ts>*...> pools,
                 const std::vector<uint32_t>* entities,
                 size_t index, size_t endIndex)
        : pools_(pools), entities_(entities),
          index_(index), endIndex_(endIndex) {

        // 找到第一个有效位置
        if (index_ < endIndex_ && !isValid()) {
            advance();
        }
    }

    bool operator!=(const ViewIterator& other) const {
        return index_ != other.index_;
    }

    ViewIterator& operator++() {
        advance();
        return *this;
    }

    // 返回元组：(Entity, Components...)
    auto operator*() const {
        uint32_t entityIndex = (*entities_)[index_];
        return std::tuple_cat(
            std::make_tuple(Entity{entityIndex, 0}),  // 版本需要从EntityManager获取
            std::make_tuple(std::ref(*std::get<ComponentPool<Ts>*>(pools_)->get(entityIndex))...)
        );
    }
};

// View: 用于遍历具有特定组件的实体
template<typename... Ts>
class View {
private:
    std::tuple<ComponentPool<Ts>*...> pools_;
    ComponentPool<std::tuple_element_t<0, std::tuple<Ts...>>>* leadingPool_;

public:
    explicit View(ComponentPool<Ts>*... pools)
        : pools_(pools...) {
        // 选择最小的池作为主导池
        auto smallest = findSmallestPool(pools...);
        leadingPool_ = std::get<0>(pools_);

        // 找真正最小的
        size_t minSize = leadingPool_->size();
        std::apply([&](auto*... ps) {
            ((ps->size() < minSize ?
              (leadingPool_ = reinterpret_cast<decltype(leadingPool_)>(ps),
               minSize = ps->size()) : 0), ...);
        }, pools_);
    }

    auto begin() {
        return ViewIterator<Ts...>(
            pools_,
            &leadingPool_->entities(),
            0,
            leadingPool_->entities().size()
        );
    }

    auto end() {
        return ViewIterator<Ts...>(
            pools_,
            &leadingPool_->entities(),
            leadingPool_->entities().size(),
            leadingPool_->entities().size()
        );
    }

    // 获取单个实体的组件
    std::tuple<Ts*...> get(uint32_t entityIndex) {
        return std::make_tuple(
            std::get<ComponentPool<Ts>*>(pools_)->get(entityIndex)...
        );
    }

    // 检查实体是否在视图中
    bool contains(uint32_t entityIndex) const {
        return std::apply([entityIndex](auto*... pools) {
            return (pools->contains(entityIndex) && ...);
        }, pools_);
    }

    // 对每个匹配实体执行函数
    template<typename Func>
    void each(Func&& func) {
        for (auto it = begin(); it != end(); ++it) {
            std::apply(std::forward<Func>(func), *it);
        }
    }

    // 并行版本
    template<typename Func>
    void parallelEach(Func&& func, size_t minBatchSize = 64) {
        const auto& entities = leadingPool_->entities();
        const size_t count = entities.size();

        if (count < minBatchSize * 2) {
            each(std::forward<Func>(func));
            return;
        }

        const size_t threadCount = std::thread::hardware_concurrency();
        const size_t batchSize = std::max(minBatchSize,
                                          (count + threadCount - 1) / threadCount);

        std::vector<std::thread> threads;

        for (size_t start = 0; start < count; start += batchSize) {
            size_t end = std::min(start + batchSize, count);

            threads.emplace_back([this, &func, &entities, start, end]() {
                for (size_t i = start; i < end; ++i) {
                    uint32_t entityIndex = entities[i];

                    if (!contains(entityIndex)) continue;

                    auto components = get(entityIndex);
                    std::apply([&](auto*... ptrs) {
                        if ((ptrs && ...)) {
                            func(Entity{entityIndex, 0}, *ptrs...);
                        }
                    }, components);
                }
            });
        }

        for (auto& t : threads) {
            t.join();
        }
    }
};

} // namespace ecs
```

#### 5. 世界 (ecs/world/world.hpp)

```cpp
#pragma once

#include "../core/entity_manager.hpp"
#include "../storage/component_pool.hpp"
#include "../query/view.hpp"
#include <unordered_map>
#include <memory>
#include <functional>

namespace ecs {

class World {
private:
    EntityManager entityManager_;
    std::unordered_map<ComponentId, std::unique_ptr<ComponentPoolBase>> componentPools_;

    // 系统
    struct SystemEntry {
        std::string name;
        std::function<void(World&, float)> update;
        int priority = 0;
    };
    std::vector<SystemEntry> systems_;

    // 延迟操作队列
    struct Command {
        enum Type { CreateEntity, DestroyEntity, AddComponent, RemoveComponent };
        Type type;
        Entity entity;
        std::function<void()> execute;
    };
    std::vector<Command> commandQueue_;

    template<typename T>
    ComponentPool<T>* getOrCreatePool() {
        ComponentId id = TypeIdGenerator::get<T>();

        auto it = componentPools_.find(id);
        if (it != componentPools_.end()) {
            return static_cast<ComponentPool<T>*>(it->second.get());
        }

        auto pool = std::make_unique<ComponentPool<T>>();
        auto* ptr = pool.get();
        componentPools_[id] = std::move(pool);
        return ptr;
    }

public:
    // 创建实体
    Entity createEntity() {
        return entityManager_.create();
    }

    // 销毁实体
    void destroyEntity(Entity entity) {
        if (!entityManager_.isValid(entity)) return;

        // 从所有组件池移除
        for (auto& [id, pool] : componentPools_) {
            pool->remove(entity.index);
        }

        entityManager_.destroy(entity);
    }

    // 延迟销毁
    void destroyEntityDeferred(Entity entity) {
        commandQueue_.push_back({
            Command::DestroyEntity,
            entity,
            [this, entity]() { destroyEntity(entity); }
        });
    }

    // 检查实体有效性
    bool isValid(Entity entity) const {
        return entityManager_.isValid(entity);
    }

    // 添加组件
    template<typename T, typename... Args>
    T& addComponent(Entity entity, Args&&... args) {
        assert(entityManager_.isValid(entity));

        auto* pool = getOrCreatePool<T>();
        entityManager_.addComponent(entity, TypeIdGenerator::get<T>());

        return pool->emplace(entity.index, std::forward<Args>(args)...);
    }

    // 移除组件
    template<typename T>
    void removeComponent(Entity entity) {
        if (!entityManager_.isValid(entity)) return;

        ComponentId id = TypeIdGenerator::get<T>();
        auto it = componentPools_.find(id);
        if (it != componentPools_.end()) {
            it->second->remove(entity.index);
            entityManager_.removeComponent(entity, id);
        }
    }

    // 获取组件
    template<typename T>
    T* getComponent(Entity entity) {
        if (!entityManager_.isValid(entity)) return nullptr;

        ComponentId id = TypeIdGenerator::get<T>();
        auto it = componentPools_.find(id);
        if (it == componentPools_.end()) return nullptr;

        return static_cast<ComponentPool<T>*>(it->second.get())->get(entity.index);
    }

    template<typename T>
    const T* getComponent(Entity entity) const {
        return const_cast<World*>(this)->getComponent<T>(entity);
    }

    // 检查是否有组件
    template<typename T>
    bool hasComponent(Entity entity) const {
        return entityManager_.hasComponent(entity, TypeIdGenerator::get<T>());
    }

    // 创建视图/查询
    template<typename... Ts>
    View<Ts...> view() {
        return View<Ts...>(getOrCreatePool<Ts>()...);
    }

    // 获取组件池
    template<typename T>
    ComponentPool<T>* pool() {
        return getOrCreatePool<T>();
    }

    // 注册系统
    template<typename Func>
    void registerSystem(const std::string& name, Func&& func, int priority = 0) {
        systems_.push_back({
            name,
            std::forward<Func>(func),
            priority
        });

        // 按优先级排序
        std::sort(systems_.begin(), systems_.end(),
            [](const auto& a, const auto& b) {
                return a.priority < b.priority;
            });
    }

    // 更新所有系统
    void update(float deltaTime) {
        // 先执行延迟命令
        flushCommands();

        // 执行所有系统
        for (auto& sys : systems_) {
            sys.update(*this, deltaTime);
        }

        // 再次执行延迟命令
        flushCommands();
    }

    // 执行延迟命令
    void flushCommands() {
        for (auto& cmd : commandQueue_) {
            cmd.execute();
        }
        commandQueue_.clear();
    }

    // 统计
    size_t entityCount() const { return entityManager_.count(); }

    template<typename T>
    size_t componentCount() const {
        ComponentId id = TypeIdGenerator::get<T>();
        auto it = componentPools_.find(id);
        return it != componentPools_.end() ? it->second->size() : 0;
    }

    // 遍历所有实体
    template<typename Func>
    void forEachEntity(Func&& func) {
        for (uint32_t i = 0; i < entityManager_.capacity(); ++i) {
            Entity e{i, 0};  // 需要正确的版本
            if (entityManager_.isValid(e)) {
                func(e);
            }
        }
    }
};

} // namespace ecs
```

#### 6. 常用组件定义 (ecs/components/common.hpp)

```cpp
#pragma once

#include <string>

namespace ecs {

// 变换组件
struct Transform {
    float x = 0, y = 0, z = 0;
    float rotX = 0, rotY = 0, rotZ = 0;
    float scaleX = 1, scaleY = 1, scaleZ = 1;
};

// 速度组件
struct Velocity {
    float x = 0, y = 0, z = 0;
};

// 刚体组件
struct RigidBody {
    float mass = 1.0f;
    float drag = 0.0f;
    bool useGravity = true;
    bool isKinematic = false;
};

// 碰撞器组件（AABB）
struct BoxCollider {
    float halfWidth = 0.5f;
    float halfHeight = 0.5f;
    float halfDepth = 0.5f;
    bool isTrigger = false;
};

// 球形碰撞器
struct SphereCollider {
    float radius = 0.5f;
    bool isTrigger = false;
};

// 渲染组件
struct Renderable {
    uint32_t meshId = 0;
    uint32_t materialId = 0;
    bool visible = true;
    bool castShadow = true;
};

// 名称组件
struct Name {
    std::string value;
};

// 标签组件（空组件用于标记）
struct Active {};
struct Static {};
struct Player {};
struct Enemy {};

// 生命周期组件
struct Lifetime {
    float remaining = 1.0f;
};

// 父子关系
struct Parent {
    Entity entity = Entity::invalid();
};

struct Children {
    std::vector<Entity> entities;
};

} // namespace ecs
```

#### 7. 常用系统 (ecs/systems/common_systems.hpp)

```cpp
#pragma once

#include "../world/world.hpp"
#include "../components/common.hpp"

namespace ecs::systems {

// 移动系统
inline void MovementSystem(World& world, float dt) {
    world.view<Transform, Velocity>().each(
        [dt](Entity entity, Transform& transform, Velocity& velocity) {
            transform.x += velocity.x * dt;
            transform.y += velocity.y * dt;
            transform.z += velocity.z * dt;
        }
    );
}

// 重力系统
inline void GravitySystem(World& world, float dt) {
    constexpr float GRAVITY = -9.8f;

    world.view<Velocity, RigidBody>().each(
        [dt](Entity entity, Velocity& velocity, RigidBody& body) {
            if (body.useGravity && !body.isKinematic) {
                velocity.y += GRAVITY * dt;
            }
        }
    );
}

// 生命周期系统
inline void LifetimeSystem(World& world, float dt) {
    std::vector<Entity> toDestroy;

    world.view<Lifetime>().each(
        [&toDestroy, dt](Entity entity, Lifetime& lifetime) {
            lifetime.remaining -= dt;
            if (lifetime.remaining <= 0) {
                toDestroy.push_back(entity);
            }
        }
    );

    for (Entity e : toDestroy) {
        world.destroyEntityDeferred(e);
    }
}

// 层级更新系统
inline void HierarchySystem(World& world, float dt) {
    // 收集根实体（没有父节点的）
    std::vector<Entity> roots;

    world.view<Transform>().each(
        [&world, &roots](Entity entity, Transform& transform) {
            if (!world.hasComponent<Parent>(entity)) {
                roots.push_back(entity);
            }
        }
    );

    // 递归更新层级
    std::function<void(Entity, const Transform&)> updateHierarchy;
    updateHierarchy = [&](Entity entity, const Transform& parentWorld) {
        auto* transform = world.getComponent<Transform>(entity);
        if (!transform) return;

        // 计算世界变换（简化：只处理位移）
        Transform worldTransform;
        worldTransform.x = parentWorld.x + transform->x;
        worldTransform.y = parentWorld.y + transform->y;
        worldTransform.z = parentWorld.z + transform->z;

        // 更新子节点
        if (auto* children = world.getComponent<Children>(entity)) {
            for (Entity child : children->entities) {
                if (world.isValid(child)) {
                    updateHierarchy(child, worldTransform);
                }
            }
        }
    };

    Transform identity;
    for (Entity root : roots) {
        updateHierarchy(root, identity);
    }
}

// 碰撞检测系统（简化版）
inline void CollisionSystem(World& world, float dt) {
    auto& transforms = *world.pool<Transform>();
    auto& colliders = *world.pool<BoxCollider>();

    const auto& entities = colliders.entities();

    // O(n^2) 简单检测
    for (size_t i = 0; i < entities.size(); ++i) {
        uint32_t entityA = entities[i];
        auto* transA = transforms.get(entityA);
        auto* collA = colliders.get(entityA);
        if (!transA || !collA) continue;

        for (size_t j = i + 1; j < entities.size(); ++j) {
            uint32_t entityB = entities[j];
            auto* transB = transforms.get(entityB);
            auto* collB = colliders.get(entityB);
            if (!transB || !collB) continue;

            // AABB碰撞检测
            bool overlap =
                std::abs(transA->x - transB->x) < (collA->halfWidth + collB->halfWidth) &&
                std::abs(transA->y - transB->y) < (collA->halfHeight + collB->halfHeight) &&
                std::abs(transA->z - transB->z) < (collA->halfDepth + collB->halfDepth);

            if (overlap) {
                // 碰撞发生，可以触发事件或回调
            }
        }
    }
}

// Debug打印系统
inline void DebugPrintSystem(World& world, float dt) {
    static float timer = 0;
    timer += dt;

    if (timer >= 1.0f) {
        timer = 0;

        std::cout << "=== ECS Debug ===" << std::endl;
        std::cout << "Entities: " << world.entityCount() << std::endl;
        std::cout << "Transforms: " << world.componentCount<Transform>() << std::endl;
        std::cout << "Velocities: " << world.componentCount<Velocity>() << std::endl;
    }
}

} // namespace ecs::systems
```

#### 8. 使用示例与基准测试 (main.cpp)

```cpp
#include "ecs/world/world.hpp"
#include "ecs/components/common.hpp"
#include "ecs/systems/common_systems.hpp"
#include <iostream>
#include <chrono>
#include <random>

using namespace ecs;

void basicExample() {
    std::cout << "=== Basic ECS Example ===\n\n";

    World world;

    // 创建一些实体
    for (int i = 0; i < 10; ++i) {
        Entity e = world.createEntity();

        world.addComponent<Transform>(e, Transform{
            static_cast<float>(i), 0.0f, 0.0f
        });

        world.addComponent<Velocity>(e, Velocity{
            1.0f, 0.0f, 0.0f
        });

        if (i % 2 == 0) {
            world.addComponent<Name>(e, Name{"Entity_" + std::to_string(i)});
        }
    }

    std::cout << "Created " << world.entityCount() << " entities\n";

    // 注册系统
    world.registerSystem("Movement", systems::MovementSystem, 10);

    // 模拟几帧
    for (int frame = 0; frame < 5; ++frame) {
        std::cout << "\nFrame " << frame << ":\n";

        world.update(0.016f);

        // 打印位置
        world.view<Transform, Name>().each(
            [](Entity e, Transform& t, Name& n) {
                std::cout << "  " << n.value << ": ("
                          << t.x << ", " << t.y << ", " << t.z << ")\n";
            }
        );
    }
}

void benchmark() {
    std::cout << "\n=== ECS Benchmark ===\n\n";

    constexpr size_t ENTITY_COUNTS[] = {10000, 50000, 100000, 500000};
    constexpr int FRAMES = 100;
    constexpr float DT = 1.0f / 60.0f;

    for (size_t entityCount : ENTITY_COUNTS) {
        World world;

        std::mt19937 rng(42);
        std::uniform_real_distribution<float> dist(-100.0f, 100.0f);

        // 创建实体
        for (size_t i = 0; i < entityCount; ++i) {
            Entity e = world.createEntity();

            world.addComponent<Transform>(e, Transform{
                dist(rng), dist(rng), dist(rng)
            });

            world.addComponent<Velocity>(e, Velocity{
                dist(rng) * 0.1f, dist(rng) * 0.1f, dist(rng) * 0.1f
            });
        }

        // 预热
        for (int i = 0; i < 10; ++i) {
            world.view<Transform, Velocity>().each(
                [DT](Entity e, Transform& t, Velocity& v) {
                    t.x += v.x * DT;
                    t.y += v.y * DT;
                    t.z += v.z * DT;
                }
            );
        }

        // 基准测试：串行
        auto start = std::chrono::high_resolution_clock::now();

        for (int frame = 0; frame < FRAMES; ++frame) {
            world.view<Transform, Velocity>().each(
                [DT](Entity e, Transform& t, Velocity& v) {
                    t.x += v.x * DT;
                    t.y += v.y * DT;
                    t.z += v.z * DT;
                }
            );
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto serialTime = std::chrono::duration<double, std::milli>(end - start).count();

        // 基准测试：并行
        start = std::chrono::high_resolution_clock::now();

        for (int frame = 0; frame < FRAMES; ++frame) {
            world.view<Transform, Velocity>().parallelEach(
                [DT](Entity e, Transform& t, Velocity& v) {
                    t.x += v.x * DT;
                    t.y += v.y * DT;
                    t.z += v.z * DT;
                }
            );
        }

        end = std::chrono::high_resolution_clock::now();
        auto parallelTime = std::chrono::duration<double, std::milli>(end - start).count();

        std::cout << "Entities: " << entityCount << "\n";
        std::cout << "  Serial:   " << serialTime / FRAMES << " ms/frame\n";
        std::cout << "  Parallel: " << parallelTime / FRAMES << " ms/frame\n";
        std::cout << "  Speedup:  " << serialTime / parallelTime << "x\n\n";
    }
}

void gameSimulation() {
    std::cout << "\n=== Game Simulation ===\n\n";

    World world;

    // 注册系统
    world.registerSystem("Gravity", systems::GravitySystem, 0);
    world.registerSystem("Movement", systems::MovementSystem, 10);
    world.registerSystem("Lifetime", systems::LifetimeSystem, 20);
    world.registerSystem("Collision", systems::CollisionSystem, 30);

    // 创建玩家
    Entity player = world.createEntity();
    world.addComponent<Transform>(player, Transform{0, 10, 0});
    world.addComponent<Velocity>(player);
    world.addComponent<RigidBody>(player, RigidBody{1.0f, 0.0f, true, false});
    world.addComponent<BoxCollider>(player, BoxCollider{0.5f, 1.0f, 0.5f, false});
    world.addComponent<Name>(player, Name{"Player"});
    world.addComponent<Player>(player);

    // 创建地面
    Entity ground = world.createEntity();
    world.addComponent<Transform>(ground, Transform{0, -1, 0});
    world.addComponent<BoxCollider>(ground, BoxCollider{50.0f, 1.0f, 50.0f, false});
    world.addComponent<Name>(ground, Name{"Ground"});
    world.addComponent<Static>(ground);

    // 创建一些敌人
    std::mt19937 rng(42);
    std::uniform_real_distribution<float> posDist(-20.0f, 20.0f);

    for (int i = 0; i < 5; ++i) {
        Entity enemy = world.createEntity();
        world.addComponent<Transform>(enemy, Transform{
            posDist(rng), 5.0f, posDist(rng)
        });
        world.addComponent<Velocity>(enemy, Velocity{
            posDist(rng) * 0.1f, 0.0f, posDist(rng) * 0.1f
        });
        world.addComponent<RigidBody>(enemy);
        world.addComponent<BoxCollider>(enemy);
        world.addComponent<Name>(enemy, Name{"Enemy_" + std::to_string(i)});
        world.addComponent<Enemy>(enemy);
    }

    // 创建一些临时粒子
    for (int i = 0; i < 10; ++i) {
        Entity particle = world.createEntity();
        world.addComponent<Transform>(particle, Transform{0, 5, 0});
        world.addComponent<Velocity>(particle, Velocity{
            posDist(rng), posDist(rng), posDist(rng)
        });
        world.addComponent<Lifetime>(particle, Lifetime{1.0f + i * 0.2f});
    }

    std::cout << "Initial entities: " << world.entityCount() << "\n\n";

    // 模拟
    for (int frame = 0; frame < 120; ++frame) {
        world.update(1.0f / 60.0f);

        if (frame % 30 == 0) {
            std::cout << "Frame " << frame << ": "
                      << world.entityCount() << " entities\n";

            // 打印玩家位置
            if (auto* playerTrans = world.getComponent<Transform>(player)) {
                std::cout << "  Player Y: " << playerTrans->y << "\n";
            }
        }
    }

    std::cout << "\nFinal entities: " << world.entityCount() << "\n";
}

int main() {
    basicExample();
    benchmark();
    gameSimulation();

    return 0;
}
```

---

## 检验标准

### 知识检验
1. [ ] 能够解释ECS与传统OOP的区别
2. [ ] 理解Sparse Set和Archetype存储的优缺点
3. [ ] 掌握View/Query的实现原理
4. [ ] 理解系统调度和依赖分析
5. [ ] 能够设计合理的组件拆分

### 实践检验
1. [ ] 完成ECS框架核心实现
2. [ ] 支持组件的添加/删除/查询
3. [ ] View遍历正确且高效
4. [ ] 并行遍历正确工作
5. [ ] 100万实体达到良好性能

### 代码质量
1. [ ] 类型安全，编译期检查
2. [ ] 内存管理正确
3. [ ] 接口设计清晰易用
4. [ ] 有完整的测试

---

## 输出物清单

1. **学习笔记**
   - [ ] ECS架构设计笔记
   - [ ] 存储策略对比分析
   - [ ] 源码阅读笔记

2. **代码产出**
   - [ ] 高性能ECS框架
   - [ ] 常用组件和系统库
   - [ ] 基准测试套件

3. **文档产出**
   - [ ] ECS设计文档
   - [ ] API使用指南
   - [ ] 性能调优指南

---

## 时间分配表

| 周次 | 理论学习 | 源码阅读 | 项目实践 | 总计 |
|------|----------|----------|----------|------|
| Week 1 | 15h | 12h | 8h | 35h |
| Week 2 | 12h | 10h | 13h | 35h |
| Week 3 | 10h | 6h | 19h | 35h |
| Week 4 | 8h | 5h | 22h | 35h |
| **总计** | **45h** | **33h** | **62h** | **140h** |

---

## 下月预告

**Month 54: SYCL与异构计算入门**

下个月将进入异构计算领域：
- GPU计算基础概念
- SYCL标准与实现
- 内存模型与数据传输
- 并行执行模型
- 实践项目：使用SYCL实现矩阵运算

建议提前：
1. 了解GPU架构基础
2. 复习并行计算概念
3. 安装SYCL编译器（Intel DPC++或hipSYCL）
