# Month 50: 插件化系统设计 (Plugin System Design)

## 本月主题概述

插件化系统是实现软件可扩展性的核心技术，允许在不修改主程序的情况下动态添加、更新和移除功能。本月将深入学习插件系统的设计模式、动态加载机制、版本管理以及安全隔离策略，并构建一个生产级的插件框架。

### 学习目标
- 掌握动态链接库的加载与符号解析机制
- 理解插件生命周期管理与依赖解析
- 实现跨平台的插件加载框架
- 掌握插件热更新与版本兼容性策略
- 了解插件沙箱与安全隔离技术

**进阶目标**：
- 深入理解ELF/PE/Mach-O格式差异及GOT/PLT延迟绑定的底层实现
- 掌握插件架构的四种经典模式（微内核/管道过滤器/事件驱动/扩展点）及选型策略
- 能够设计完整的语义化版本约束系统与ABI兼容性保持方案
- 理解多层安全隔离（进程隔离/Wasm沙箱/Linux命名空间+seccomp）的实现与权衡
- 具备设计生产级跨平台插件框架的完整能力

---

## 理论学习内容

### 第一周：动态链接基础

**学习目标**：
- [ ] 深入理解ELF/PE/Mach-O三种可执行文件格式的核心结构
- [ ] 掌握GOT/PLT延迟绑定机制的完整工作流程
- [ ] 熟练使用dlopen/dlsym/dlclose API进行运行时动态加载
- [ ] 理解符号可见性控制对插件系统的关键影响
- [ ] 掌握位置无关代码（PIC）的生成原理与性能特征
- [ ] 了解各平台库搜索路径机制（RPATH/RUNPATH/@rpath）
- [ ] 能够诊断和解决常见的动态链接问题（符号冲突、版本不匹配）

**阅读材料**：
- [ ] 《程序员的自我修养：链接、装载与库》- 动态链接章节
- [ ] 《Computer Systems: A Programmer's Perspective》- Linking章节
- [ ] Linux dlopen/dlsym手册
- [ ] Windows LoadLibrary文档
- [ ] ELF规范文档（Tool Interface Standard - ELF）
- [ ] Apple Dynamic Library Programming Topics
- [ ] Ulrich Drepper《How To Write Shared Libraries》

#### 核心概念

**动态链接流程**
```
┌─────────────────────────────────────────────────────────┐
│                    程序启动                              │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│           动态链接器 (ld.so / dyld)                      │
│  1. 加载可执行文件                                       │
│  2. 解析依赖的共享库                                     │
│  3. 递归加载所有依赖                                     │
│  4. 符号重定位                                          │
│  5. 执行初始化函数                                       │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                   运行时加载                             │
│  dlopen() ─────▶ 加载共享库到进程空间                    │
│  dlsym()  ─────▶ 查找并返回符号地址                      │
│  dlclose() ────▶ 卸载共享库                             │
└─────────────────────────────────────────────────────────┘
```

**符号可见性控制**
```cpp
// 控制符号导出（Linux/macOS）
#if defined(__GNUC__) || defined(__clang__)
    #define PLUGIN_EXPORT __attribute__((visibility("default")))
    #define PLUGIN_LOCAL  __attribute__((visibility("hidden")))
#elif defined(_MSC_VER)
    #define PLUGIN_EXPORT __declspec(dllexport)
    #define PLUGIN_LOCAL
#endif

// 编译时使用 -fvisibility=hidden 隐藏所有符号
// 只有标记 PLUGIN_EXPORT 的符号才会导出
```

---

#### 1.1 ELF文件格式深度解析

```cpp
// ==========================================
// ELF (Executable and Linkable Format) 深度解析
// ==========================================
//
// ELF是Linux/Unix系统上的标准可执行文件格式，
// 理解ELF是掌握动态链接的基础。
//
// 为什么插件开发者需要了解ELF？
//   1. 插件本质上就是一个共享库（.so），其格式就是ELF
//   2. 理解ELF结构才能理解符号导出/导入机制
//   3. 调试加载问题时需要用readelf/objdump等工具分析
//   4. 符号版本化、可见性控制都建立在ELF结构之上
//
// ELF文件有两种视角：
//   链接视角（Link View）：由Section组成，编译器/链接器使用
//   执行视角（Execution View）：由Segment组成，加载器使用
//
// ┌──────────────────────────────────┐
// │          ELF Header              │  ← 文件身份标识 + 入口信息
// ├──────────────────────────────────┤
// │      Program Header Table        │  ← Segment表（执行视角）
// ├──────────────────────────────────┤
// │          .text                   │  ← 代码段（可执行）
// ├──────────────────────────────────┤
// │          .rodata                 │  ← 只读数据
// ├──────────────────────────────────┤
// │          .data                   │  ← 已初始化全局变量
// ├──────────────────────────────────┤
// │          .bss                    │  ← 未初始化全局变量
// ├──────────────────────────────────┤
// │          .dynsym                 │  ← 动态符号表（⭐插件关键）
// ├──────────────────────────────────┤
// │          .dynstr                 │  ← 动态字符串表
// ├──────────────────────────────────┤
// │          .got / .got.plt         │  ← 全局偏移表（延迟绑定核心）
// ├──────────────────────────────────┤
// │          .plt                    │  ← 过程链接表
// ├──────────────────────────────────┤
// │          .rel.dyn / .rela.dyn    │  ← 重定位表
// ├──────────────────────────────────┤
// │      Section Header Table        │  ← Section表（链接视角）
// └──────────────────────────────────┘

#include <cstdint>
#include <cstring>
#include <fstream>
#include <iostream>
#include <vector>
#include <iomanip>

namespace elf_parser {

// ==========================================
// ELF Header 结构（简化版，对应64位ELF）
// ==========================================
//
// ELF头部是文件的"身份证"，位于文件最开始的64字节（64位系统）
// 它告诉操作系统这个文件是什么类型、目标架构、入口地址在哪里

struct Elf64Header {
    uint8_t  magic[4];         // 魔数: 0x7F 'E' 'L' 'F'
    uint8_t  classType;        // 1=32位, 2=64位
    uint8_t  endianness;       // 1=小端, 2=大端
    uint8_t  version;          // ELF版本（总是1）
    uint8_t  osAbi;            // OS ABI标识
    uint8_t  padding[8];       // 填充字节
    uint16_t type;             // 文件类型: ET_EXEC/ET_DYN/ET_REL
    uint16_t machine;          // 目标架构: EM_X86_64/EM_AARCH64
    uint32_t elfVersion;       // ELF版本
    uint64_t entryPoint;       // 程序入口地址
    uint64_t phOffset;         // Program Header Table偏移
    uint64_t shOffset;         // Section Header Table偏移
    uint32_t flags;            // 处理器特定标志
    uint16_t headerSize;       // ELF头部大小
    uint16_t phEntrySize;      // Program Header条目大小
    uint16_t phCount;          // Program Header数量
    uint16_t shEntrySize;      // Section Header条目大小
    uint16_t shCount;          // Section Header数量
    uint16_t shStrIndex;       // 字符串表的Section索引
};

// 文件类型常量
// ET_DYN (3) 对插件最重要——共享库就是这个类型
constexpr uint16_t ET_NONE = 0;  // 未知类型
constexpr uint16_t ET_REL  = 1;  // 可重定位文件（.o）
constexpr uint16_t ET_EXEC = 2;  // 可执行文件
constexpr uint16_t ET_DYN  = 3;  // 共享目标文件（.so）⭐
constexpr uint16_t ET_CORE = 4;  // 核心转储文件

// Section Header结构
struct Elf64SectionHeader {
    uint32_t name;       // 段名（字符串表中的偏移）
    uint32_t type;       // 段类型
    uint64_t flags;      // 段标志
    uint64_t addr;       // 内存地址
    uint64_t offset;     // 文件偏移
    uint64_t size;       // 段大小
    uint32_t link;       // 关联段索引
    uint32_t info;       // 附加信息
    uint64_t addralign;  // 对齐要求
    uint64_t entrySize;  // 表项大小（如果是表）
};

// 动态符号表项
// 这是插件系统最关心的结构——它决定了哪些函数/变量可以被外部访问
struct Elf64Symbol {
    uint32_t name;       // 符号名（字符串表偏移）
    uint8_t  info;       // 符号类型和绑定信息
    uint8_t  other;      // 符号可见性（⭐控制插件导出的关键字段）
    uint16_t shndx;      // 所在Section索引
    uint64_t value;      // 符号值（地址）
    uint64_t size;       // 符号大小
};

// ==========================================
// 简易ELF解析器
// ==========================================
//
// 这个解析器演示如何读取ELF文件的核心信息
// 在实际插件框架中，我们不需要自己解析ELF
//（dlopen会帮我们做），但理解结构对调试至关重要

class SimpleElfParser {
private:
    std::vector<uint8_t> data_;
    const Elf64Header* header_{nullptr};

public:
    bool load(const std::string& path) {
        std::ifstream file(path, std::ios::binary);
        if (!file) return false;

        data_ = std::vector<uint8_t>(
            std::istreambuf_iterator<char>(file),
            std::istreambuf_iterator<char>()
        );

        if (data_.size() < sizeof(Elf64Header)) return false;

        header_ = reinterpret_cast<const Elf64Header*>(data_.data());

        // 验证ELF魔数
        if (header_->magic[0] != 0x7F ||
            header_->magic[1] != 'E' ||
            header_->magic[2] != 'L' ||
            header_->magic[3] != 'F') {
            std::cerr << "Not a valid ELF file" << std::endl;
            return false;
        }

        return true;
    }

    void printInfo() const {
        if (!header_) return;

        std::cout << "=== ELF Header ===" << std::endl;
        std::cout << "Class:       " << (header_->classType == 2 ? "64-bit" : "32-bit") << std::endl;
        std::cout << "Endianness:  " << (header_->endianness == 1 ? "Little" : "Big") << std::endl;

        std::cout << "Type:        ";
        switch (header_->type) {
            case ET_REL:  std::cout << "Relocatable (.o)"; break;
            case ET_EXEC: std::cout << "Executable"; break;
            case ET_DYN:  std::cout << "Shared Object (.so)"; break;
            case ET_CORE: std::cout << "Core Dump"; break;
            default:      std::cout << "Unknown"; break;
        }
        std::cout << std::endl;

        std::cout << "Entry Point: 0x" << std::hex << header_->entryPoint << std::dec << std::endl;
        std::cout << "Sections:    " << header_->shCount << std::endl;
        std::cout << "Segments:    " << header_->phCount << std::endl;
    }

    // 列出所有Section（对应readelf -S命令）
    void listSections() const {
        if (!header_) return;

        std::cout << "\n=== Sections ===" << std::endl;

        // 获取字符串表Section
        const auto* strSection = getSectionHeader(header_->shStrIndex);
        const char* strTable = reinterpret_cast<const char*>(
            data_.data() + strSection->offset);

        for (uint16_t i = 0; i < header_->shCount; ++i) {
            const auto* sh = getSectionHeader(i);
            const char* name = strTable + sh->name;
            std::cout << "  [" << std::setw(2) << i << "] "
                      << std::setw(20) << std::left << name
                      << " offset=0x" << std::hex << std::setw(8)
                      << sh->offset
                      << " size=0x" << sh->size
                      << std::dec << std::endl;
        }
    }

private:
    const Elf64SectionHeader* getSectionHeader(uint16_t index) const {
        return reinterpret_cast<const Elf64SectionHeader*>(
            data_.data() + header_->shOffset +
            index * header_->shEntrySize
        );
    }
};

} // namespace elf_parser
```

```
跨平台可执行文件格式对比：

┌────────────────┬──────────────┬──────────────┬──────────────┐
│     特性        │   ELF        │   PE/COFF    │   Mach-O     │
│                │ (Linux)      │ (Windows)    │ (macOS)      │
├────────────────┼──────────────┼──────────────┼──────────────┤
│ 魔数           │ 0x7F ELF     │ MZ + PE\0\0  │ 0xFEEDFACF  │
│ 共享库扩展名    │ .so          │ .dll         │ .dylib       │
│ 动态链接器      │ ld-linux.so  │ ntdll.dll    │ dyld         │
│ 符号表         │ .dynsym      │ Export Table │ LC_SYMTAB    │
│ 加载API        │ dlopen       │ LoadLibrary  │ dlopen       │
│ 符号查找       │ dlsym        │ GetProcAddr  │ dlsym        │
│ 位置无关代码    │ -fPIC        │ 默认PIC      │ 默认PIC      │
│ 延迟绑定       │ GOT/PLT      │ Import Table │ lazy_symbol  │
│ 符号可见性      │ visibility   │ dllexport    │ visibility   │
└────────────────┴──────────────┴──────────────┴──────────────┘
```

---

#### 1.2 可执行文件加载过程

```cpp
// ==========================================
// 动态链接器加载过程详解
// ==========================================
//
// 当你运行一个使用共享库的程序时，实际发生的流程：
//
// Step 1: 用户执行 ./my_app
//     └── 内核的execve()系统调用
//
// Step 2: 内核读取ELF Header，发现.interp段
//     └── .interp段指定了动态链接器路径（如/lib64/ld-linux-x86-64.so.2）
//
// Step 3: 内核将控制权交给动态链接器（不是直接跳到main）
//     └── 动态链接器自身也是一个共享库，但它是自举的（bootstrap）
//
// Step 4: 动态链接器开始工作
//     ├── 4a. 读取可执行文件的.dynamic段
//     ├── 4b. 找到所有DT_NEEDED条目（直接依赖的共享库）
//     ├── 4c. 按搜索路径查找这些共享库
//     ├── 4d. 递归加载所有依赖（广度优先）
//     ├── 4e. 执行重定位（修改GOT表项）
//     └── 4f. 调用每个共享库的初始化函数（.init / .init_array）
//
// Step 5: 跳转到可执行文件的入口点（通常是_start→__libc_start_main→main）
//
// 重点理解：
// - 插件框架使用dlopen()跳过了Step 1-3，直接触发Step 4的子流程
// - dlopen()本质上是"手动版"的动态链接器加载过程
// - 每次dlopen()都可能触发新的依赖解析和重定位

#include <iostream>
#include <string>
#include <vector>

namespace loading_process {

// ==========================================
// 模拟动态链接器的加载决策过程
// ==========================================
//
// 真正的ld.so远比这复杂，但核心逻辑可以抽象为：
// 1. 找到库文件
// 2. 检查是否已加载（避免重复加载）
// 3. 映射到内存
// 4. 执行重定位
// 5. 调用初始化函数

struct LibraryInfo {
    std::string name;
    std::string path;
    std::vector<std::string> dependencies;
    bool isLoaded = false;
    void* baseAddress = nullptr;
};

class DynamicLinkerSimulator {
private:
    std::vector<LibraryInfo> loadedLibs_;

    // 搜索路径优先级（Linux）：
    // 1. DT_RPATH（已弃用，但仍生效）
    // 2. LD_LIBRARY_PATH 环境变量
    // 3. DT_RUNPATH
    // 4. /etc/ld.so.cache（ldconfig缓存）
    // 5. 默认路径：/lib, /usr/lib
    std::vector<std::string> searchPaths_ = {
        "./",                    // 当前目录（不推荐依赖）
        "/usr/local/lib/",       // 用户安装库
        "/usr/lib/x86_64-linux-gnu/",  // Debian多架构路径
        "/usr/lib/",             // 系统库
        "/lib/x86_64-linux-gnu/",
        "/lib/"
    };

public:
    // 模拟dlopen的核心流程
    bool loadLibrary(const std::string& name) {
        std::cout << "=== Loading: " << name << " ===" << std::endl;

        // Step 1: 检查是否已加载（引用计数+1）
        for (auto& lib : loadedLibs_) {
            if (lib.name == name) {
                std::cout << "  Already loaded, incrementing refcount" << std::endl;
                return true;
            }
        }

        // Step 2: 搜索库文件
        std::string resolvedPath = findLibrary(name);
        if (resolvedPath.empty()) {
            std::cerr << "  ERROR: Library not found: " << name << std::endl;
            return false;
        }
        std::cout << "  Found at: " << resolvedPath << std::endl;

        // Step 3: 读取ELF头部，获取依赖列表
        auto deps = readDependencies(resolvedPath);

        // Step 4: 递归加载依赖（广度优先）
        for (const auto& dep : deps) {
            std::cout << "  Dependency: " << dep << std::endl;
            if (!loadLibrary(dep)) {
                std::cerr << "  Failed to load dependency: " << dep << std::endl;
                return false;
            }
        }

        // Step 5: 映射到内存（mmap）
        std::cout << "  Mapping to memory..." << std::endl;

        // Step 6: 执行重定位（修改GOT表项）
        std::cout << "  Performing relocations..." << std::endl;

        // Step 7: 调用.init_array中的构造函数
        std::cout << "  Running initializers..." << std::endl;

        LibraryInfo info{name, resolvedPath, deps, true, nullptr};
        loadedLibs_.push_back(std::move(info));

        std::cout << "  Loaded successfully!" << std::endl;
        return true;
    }

private:
    std::string findLibrary(const std::string& name) {
        // 简化实现：在搜索路径中查找
        for (const auto& path : searchPaths_) {
            std::string fullPath = path + name;
            // 实际应使用 std::filesystem::exists
            // 这里仅模拟
        }
        return "/usr/lib/" + name;  // 简化返回
    }

    std::vector<std::string> readDependencies(const std::string& path) {
        // 实际实现会读取ELF的.dynamic段，查找所有DT_NEEDED条目
        // 等价于命令：readelf -d libfoo.so | grep NEEDED
        return {};  // 简化
    }
};

} // namespace loading_process
```

```
加载一个插件时的完整调用链：

用户代码                     运行时库                    内核
   │                          │                         │
   │  dlopen("plugin.so",     │                         │
   │         RTLD_NOW)        │                         │
   │─────────────────────────►│                         │
   │                          │                         │
   │                          │  open("plugin.so")      │
   │                          │────────────────────────►│
   │                          │                         │
   │                          │  mmap(PROT_READ|EXEC)   │
   │                          │────────────────────────►│
   │                          │  ◄─── 映射到进程地址空间  │
   │                          │                         │
   │                          │  解析.dynamic段          │
   │                          │  查找DT_NEEDED依赖       │
   │                          │                         │
   │                          │  递归加载依赖库           │
   │                          │  ┌─ dlopen(dep1.so)     │
   │                          │  ├─ dlopen(dep2.so)     │
   │                          │  └─ ...                 │
   │                          │                         │
   │                          │  执行重定位               │
   │                          │  ┌─ 修改.got.plt表项     │
   │                          │  └─ 修改.got表项         │
   │                          │                         │
   │                          │  调用.init_array函数     │
   │                          │  （C++全局对象构造）       │
   │                          │                         │
   │  ◄── 返回handle          │                         │
   │                          │                         │
   │  dlsym(handle,           │                         │
   │       "createPlugin")    │                         │
   │─────────────────────────►│                         │
   │                          │  查找.dynsym符号表       │
   │                          │  ┌─ 计算hash            │
   │                          │  ├─ 在hash表中查找       │
   │                          │  └─ 返回符号地址         │
   │  ◄── 返回函数指针         │                         │
```

---

#### 1.3 GOT与PLT机制详解

```cpp
// ==========================================
// GOT (Global Offset Table) 与 PLT (Procedure Linkage Table)
// ==========================================
//
// GOT和PLT是动态链接的核心机制，理解它们对理解插件加载至关重要。
//
// 问题背景：
//   共享库被加载到内存的哪个地址是不确定的（ASLR + 多个库竞争地址空间）
//   所以代码中不能硬编码外部函数和全局变量的地址
//
// 解决方案：间接寻址
//   - 代码中不直接调用外部函数，而是通过一张表（GOT）间接跳转
//   - GOT表在加载时由动态链接器填充正确的地址
//
// GOT的作用：存储外部符号的实际地址
// PLT的作用：为函数调用提供延迟绑定的跳转桩（stub）
//
// ==========================================
// 延迟绑定（Lazy Binding）完整流程
// ==========================================
//
// 第一次调用 printf() 时：
//
//   main()代码:
//     call printf@PLT          ← 不是直接调用printf
//
//   PLT[printf]:
//     jmp *GOT[printf]         ← 第一次：GOT中存的是PLT下一条指令的地址
//     push reloc_index         ← 所以跳回这里
//     jmp PLT[0]               ← 跳到PLT头部（公共入口）
//
//   PLT[0]:                    ← PLT公共入口
//     push GOT[1]              ← link_map指针（标识是哪个库）
//     jmp GOT[2]               ← 跳转到_dl_runtime_resolve
//
//   _dl_runtime_resolve():
//     ├── 根据reloc_index找到重定位条目
//     ├── 查找printf的真实地址
//     ├── 将真实地址写入GOT[printf]
//     └── 跳转到printf真实地址执行
//
// 第二次及以后调用 printf()：
//   PLT[printf]:
//     jmp *GOT[printf]         ← GOT已被修改，直接跳到printf真实地址
//                                 不再经过解析过程！

#include <iostream>
#include <map>
#include <functional>
#include <string>

namespace got_plt {

// ==========================================
// 模拟GOT/PLT机制
// ==========================================
//
// 这个模拟展示了延迟绑定的核心思想：
// 第一次调用时解析并缓存，后续调用直接使用缓存

// 模拟GOT表 —— 存储函数地址
class GlobalOffsetTable {
private:
    // GOT表项：符号名 → 解析后的函数指针
    std::map<std::string, void*> entries_;

    // 标记是否已解析
    std::map<std::string, bool> resolved_;

    // 符号解析器（模拟_dl_runtime_resolve）
    std::function<void*(const std::string&)> resolver_;

public:
    explicit GlobalOffsetTable(
        std::function<void*(const std::string&)> resolver)
        : resolver_(std::move(resolver)) {}

    // 添加未解析的GOT条目（加载时设置）
    void addEntry(const std::string& symbol) {
        entries_[symbol] = nullptr;
        resolved_[symbol] = false;
    }

    // 获取符号地址（模拟jmp *GOT[symbol]）
    void* resolve(const std::string& symbol) {
        if (!resolved_[symbol]) {
            // 第一次访问：触发解析（模拟_dl_runtime_resolve）
            std::cout << "  [GOT] Resolving symbol: " << symbol << std::endl;
            entries_[symbol] = resolver_(symbol);
            resolved_[symbol] = true;
            std::cout << "  [GOT] Resolved to: " << entries_[symbol] << std::endl;
        } else {
            std::cout << "  [GOT] Cache hit for: " << symbol << std::endl;
        }
        return entries_[symbol];
    }
};

// 模拟PLT桩（Procedure Linkage Table stub）
class ProcedureLinkageTable {
private:
    GlobalOffsetTable& got_;

public:
    explicit ProcedureLinkageTable(GlobalOffsetTable& got) : got_(got) {}

    // 模拟 call symbol@PLT
    // PLT桩做的事情：从GOT读取地址并跳转
    template<typename Func, typename... Args>
    auto call(const std::string& symbol, Args&&... args) {
        // Step 1: jmp *GOT[symbol]
        void* addr = got_.resolve(symbol);

        // Step 2: 将void*转换为实际函数类型并调用
        auto func = reinterpret_cast<Func*>(addr);
        return func(std::forward<Args>(args)...);
    }
};

// 演示
void demonstrateGotPlt() {
    // 模拟动态链接器的符号解析
    auto symbolResolver = [](const std::string& name) -> void* {
        // 实际实现会在已加载的共享库中搜索符号
        std::cout << "  [Resolver] Searching for: " << name << std::endl;
        return nullptr;  // 简化
    };

    GlobalOffsetTable got(symbolResolver);
    ProcedureLinkageTable plt(got);

    // 加载时：注册需要解析的符号（但不立即解析）
    got.addEntry("printf");
    got.addEntry("malloc");

    // 运行时：第一次调用触发解析
    std::cout << "First call to printf:" << std::endl;
    got.resolve("printf");  // 触发解析

    std::cout << "\nSecond call to printf:" << std::endl;
    got.resolve("printf");  // 直接命中缓存

    std::cout << "\nFirst call to malloc:" << std::endl;
    got.resolve("malloc");  // 触发解析
}

} // namespace got_plt
```

```
GOT/PLT 延迟绑定流程图：

第一次调用 func():
                                         ┌─────────────────┐
 call func@PLT ──────►  PLT[func]:       │ _dl_runtime     │
                        ┌────────────┐   │ _resolve()      │
                        │jmp *GOT[n] │──►│                 │
                        │  (初始指向   │   │ 1.查找符号       │
                        │   下一行)   │◄──│ 2.更新GOT[n]    │
                        │push reloc_n│   │ 3.跳转到func    │
                        │jmp PLT[0]  │──►│                 │
                        └────────────┘   └────────┬────────┘
                                                  │
                                                  ▼
                                         ┌─────────────────┐
                                         │   func() 真实    │
                                         │   代码执行        │
                                         └─────────────────┘

第二次调用 func():
                        ┌────────────┐   ┌─────────────────┐
 call func@PLT ──────►  │jmp *GOT[n] │──►│   func() 真实    │
                        │ (已更新为   │   │   代码执行        │
                        │  真实地址)  │   └─────────────────┘
                        └────────────┘
                        直接跳转！无解析开销！

GOT表在内存中的布局：
┌───────────────┬──────────────────────────┐
│   GOT[0]      │ .dynamic段地址            │
│   GOT[1]      │ link_map指针（库标识）     │
│   GOT[2]      │ _dl_runtime_resolve地址   │
│   GOT[3]      │ printf真实地址 (已解析)    │
│   GOT[4]      │ PLT stub地址 (未解析)     │
│   GOT[5]      │ malloc真实地址 (已解析)    │
│   ...         │ ...                      │
└───────────────┴──────────────────────────┘
```

---

#### 1.4 dlopen/dlsym API实战

```cpp
// ==========================================
// dlopen/dlsym/dlclose API 完整实战指南
// ==========================================
//
// 这组API是构建插件系统的基石。
// dlopen = 加载共享库
// dlsym  = 查找符号（函数或变量）
// dlclose = 卸载共享库
// dlerror = 获取最近一次错误信息
//
// 关键参数解释：
//
// RTLD_NOW   - 立即解析所有符号（推荐用于插件系统）
//   优点：加载时就发现缺失符号，fail-fast
//   缺点：加载时间稍长
//
// RTLD_LAZY  - 延迟解析，调用时才解析
//   优点：加载速度快
//   缺点：运行时可能突然崩溃（找不到符号）
//
// RTLD_LOCAL - 符号不进入全局符号表（推荐用于插件）
//   效果：插件A的符号不会被插件B看到，避免冲突
//
// RTLD_GLOBAL - 符号进入全局符号表
//   效果：所有后续加载的库都能看到这些符号
//   风险：容易导致符号冲突
//
// RTLD_NODELETE - dlclose时不真正卸载（有时用于调试）
//   效果：库一旦加载就常驻内存
//
// 最佳实践组合：
//   插件加载：dlopen(path, RTLD_NOW | RTLD_LOCAL)
//   核心库加载：dlopen(path, RTLD_NOW | RTLD_GLOBAL)

#ifndef _WIN32

#include <dlfcn.h>
#include <iostream>
#include <string>
#include <memory>
#include <stdexcept>

namespace dlapi {

// ==========================================
// RAII封装 dlopen/dlclose
// ==========================================
//
// 裸用dlopen/dlclose非常容易忘记关闭或双重关闭
// 用RAII封装确保资源安全

class SharedLibrary {
private:
    void* handle_{nullptr};
    std::string path_;

public:
    // 加载共享库
    // flags默认为RTLD_NOW | RTLD_LOCAL —— 对插件最安全的选择
    explicit SharedLibrary(const std::string& path,
                          int flags = RTLD_NOW | RTLD_LOCAL) {
        // 清除之前的错误
        dlerror();

        handle_ = dlopen(path.c_str(), flags);

        if (!handle_) {
            // dlerror()返回可读的错误信息
            // 常见错误：
            //   "libfoo.so: cannot open shared object file: No such file or directory"
            //   "undefined symbol: someFunction"
            //   "wrong ELF class: ELFCLASS32" (32/64位不匹配)
            throw std::runtime_error(
                "dlopen failed: " + std::string(dlerror()));
        }

        path_ = path;
    }

    ~SharedLibrary() {
        if (handle_) {
            // dlclose返回0表示成功
            // 注意：dlclose并不一定真正卸载库
            // 内部有引用计数，只有计数降到0才卸载
            int result = dlclose(handle_);
            if (result != 0) {
                // 析构函数中不能抛异常，只能打日志
                std::cerr << "dlclose failed: " << dlerror() << std::endl;
            }
            handle_ = nullptr;
        }
    }

    // 禁止拷贝
    SharedLibrary(const SharedLibrary&) = delete;
    SharedLibrary& operator=(const SharedLibrary&) = delete;

    // 允许移动
    SharedLibrary(SharedLibrary&& other) noexcept
        : handle_(other.handle_), path_(std::move(other.path_)) {
        other.handle_ = nullptr;
    }

    SharedLibrary& operator=(SharedLibrary&& other) noexcept {
        if (this != &other) {
            if (handle_) dlclose(handle_);
            handle_ = other.handle_;
            path_ = std::move(other.path_);
            other.handle_ = nullptr;
        }
        return *this;
    }

    // 查找函数符号
    // 使用模板参数指定函数签名，自动进行类型转换
    template<typename FuncType>
    FuncType getFunction(const std::string& name) {
        // 重要：先清除旧错误
        dlerror();

        void* symbol = dlsym(handle_, name.c_str());

        // dlsym返回NULL可能有两种情况：
        // 1. 符号确实不存在（dlerror返回错误信息）
        // 2. 符号存在但值就是NULL（dlerror返回NULL）
        // 所以必须用dlerror来区分
        const char* error = dlerror();
        if (error) {
            throw std::runtime_error(
                "dlsym failed for '" + name + "': " + error);
        }

        // reinterpret_cast是必须的——dlsym返回void*
        // 这里的类型安全完全依赖调用者保证FuncType正确
        return reinterpret_cast<FuncType>(symbol);
    }

    // 查找变量符号
    template<typename T>
    T* getVariable(const std::string& name) {
        dlerror();
        void* symbol = dlsym(handle_, name.c_str());
        const char* error = dlerror();
        if (error) {
            throw std::runtime_error(
                "dlsym failed for '" + name + "': " + error);
        }
        return static_cast<T*>(symbol);
    }

    // 安全版本：找不到返回nullptr
    template<typename FuncType>
    FuncType tryGetFunction(const std::string& name) noexcept {
        dlerror();
        void* symbol = dlsym(handle_, name.c_str());
        if (dlerror()) return nullptr;
        return reinterpret_cast<FuncType>(symbol);
    }

    bool isValid() const { return handle_ != nullptr; }
    const std::string& getPath() const { return path_; }
};

// ==========================================
// 使用示例：加载插件并调用函数
// ==========================================

void demonstratePluginLoading() {
    try {
        // 加载插件
        SharedLibrary plugin("./plugins/libsample_plugin.so");
        std::cout << "Loaded: " << plugin.getPath() << std::endl;

        // 获取工厂函数
        // 注意函数签名必须与插件导出的完全匹配
        using CreateFunc = void* (*)();
        using DestroyFunc = void (*)(void*);

        auto create = plugin.getFunction<CreateFunc>("createPlugin");
        auto destroy = plugin.getFunction<DestroyFunc>("destroyPlugin");

        // 创建插件实例
        void* instance = create();
        std::cout << "Plugin instance created" << std::endl;

        // 使用插件...

        // 销毁实例（必须在dlclose之前！）
        destroy(instance);
        std::cout << "Plugin instance destroyed" << std::endl;

        // SharedLibrary析构时自动dlclose

    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
    }
}

// ==========================================
// 常见陷阱与注意事项
// ==========================================
//
// 陷阱1: dlclose后继续使用插件对象
//   void* handle = dlopen("plugin.so", RTLD_NOW);
//   auto* obj = createPlugin();
//   dlclose(handle);       // ← 库被卸载！
//   obj->doSomething();    // ← 段错误！代码已被unmap
//
// 陷阱2: C++名称修饰导致找不到符号
//   // 插件中如果不用extern "C"
//   void createPlugin();   // 实际符号名: _Z12createPluginv
//   dlsym(handle, "createPlugin");  // 找不到！
//
//   // 解决方案：总是用extern "C"导出
//   extern "C" void createPlugin();  // 实际符号名: createPlugin
//
// 陷阱3: 全局对象的构造/析构顺序
//   dlopen → 触发全局对象构造函数
//   dlclose → 触发全局对象析构函数
//   如果全局对象之间有依赖，可能导致 use-after-free
//
// 陷阱4: 线程安全
//   dlopen/dlsym/dlclose 在大多数实现中是线程安全的
//   但 dlerror 的返回值是线程局部的（thread-local）
//   多线程中每个线程有自己的错误状态

} // namespace dlapi

#endif // _WIN32
```

---

#### 1.5 符号可见性与导出控制

```cpp
// ==========================================
// 符号可见性控制——插件安全的第一道防线
// ==========================================
//
// 为什么符号可见性如此重要？
//
// 1. 减少符号冲突风险
//    想象两个插件都定义了一个叫 "helper()" 的内部函数
//    如果两个都导出了这个符号，加载第二个插件时可能意外
//    绑定到第一个插件的 helper()——这是一个极其隐蔽的bug
//
// 2. 加快加载速度
//    动态链接器需要处理每个导出符号（hash计算、重定位等）
//    一个100个函数的库，如果只需要导出5个，
//    隐藏其余95个可以显著减少加载时间
//
// 3. 减小库文件大小
//    隐藏的符号不需要出现在.dynsym表中
//
// 4. 更好的优化机会
//    编译器知道一个函数不会被外部调用后，
//    可以进行更激进的内联和优化
//
// ==========================================
// 可见性级别（GCC/Clang）
// ==========================================
//
// default  — 符号对外可见（可被dlsym找到）
// hidden   — 符号仅在库内部可见（最常用的隐藏级别）
// internal — 类似hidden，但编译器可假设不会被指针间接调用
// protected — 外部可见但不可被覆盖（性能介于default和hidden之间）

#include <string>
#include <iostream>

// ==========================================
// 实践推荐的符号可见性策略
// ==========================================
//
// 策略：默认隐藏，显式导出
//
// 编译选项：-fvisibility=hidden -fvisibility-inlines-hidden
// 效果：所有符号默认hidden，只有标记了的才导出
//
// 这是最安全的做法，也是所有主流插件系统采用的方式

// 跨平台导出宏定义
#if defined(_WIN32) || defined(__CYGWIN__)
    #ifdef BUILDING_DLL
        // 编译DLL时，标记为导出
        #define PLUGIN_API __declspec(dllexport)
    #else
        // 使用DLL时，标记为导入
        #define PLUGIN_API __declspec(dllimport)
    #endif
    #define PLUGIN_HIDDEN
#elif defined(__GNUC__) || defined(__clang__)
    // GCC/Clang使用visibility属性
    #define PLUGIN_API    __attribute__((visibility("default")))
    #define PLUGIN_HIDDEN __attribute__((visibility("hidden")))
#else
    #define PLUGIN_API
    #define PLUGIN_HIDDEN
#endif

namespace visibility_demo {

// ==========================================
// 正确的插件符号导出示例
// ==========================================

// ✅ 导出：插件的公共接口
class PLUGIN_API PublicWidget {
public:
    virtual ~PublicWidget() = default;
    virtual void doWork() = 0;
    virtual std::string getName() const = 0;
};

// ❌ 不导出：插件的内部实现
class PLUGIN_HIDDEN InternalHelper {
public:
    void helperMethod() {
        // 这个类的符号不会出现在.dynsym中
        // 其他插件无法看到、调用或冲突
    }
};

// ✅ 导出：C接口的工厂函数
extern "C" {
    PLUGIN_API PublicWidget* createWidget();
    PLUGIN_API void destroyWidget(PublicWidget* widget);
    PLUGIN_API const char* getPluginVersion();
}

// ❌ 不导出：内部工具函数
PLUGIN_HIDDEN void internalUtility() {
    // 仅供库内部使用
}

// ==========================================
// 符号版本脚本（更精细的控制方式）
// ==========================================
//
// 除了编译器属性，还可以用链接器版本脚本(.map文件)
// 来精确控制哪些符号导出
//
// 文件: plugin.map
// ─────────────────────
// {
//     global:
//         createPlugin;
//         destroyPlugin;
//         getPluginApiVersion;
//     local:
//         *;              ← 其余所有符号都隐藏
// };
// ─────────────────────
//
// 编译命令：
// g++ -shared -o plugin.so plugin.cpp \
//     -Wl,--version-script=plugin.map \
//     -fvisibility=hidden

// ==========================================
// 符号冲突问题演示
// ==========================================
//
// 场景：两个插件都定义了同名函数
//
// pluginA.so: void logMessage(const char* msg) { 写到文件 }
// pluginB.so: void logMessage(const char* msg) { 写到网络 }
//
// 如果两个都用RTLD_GLOBAL加载：
//   dlopen("pluginA.so", RTLD_GLOBAL)  → logMessage = A的版本
//   dlopen("pluginB.so", RTLD_GLOBAL)  → pluginB内部调用logMessage
//                                        可能绑定到A的版本！
//
// 解决方案组合：
//   1. 编译时：-fvisibility=hidden + 显式PLUGIN_API导出
//   2. 加载时：RTLD_LOCAL（每个插件的符号独立）
//   3. 命名空间：所有导出符号加统一前缀（如pluginA_logMessage）

} // namespace visibility_demo
```

---

#### 1.6 位置无关代码(PIC)原理

```cpp
// ==========================================
// 位置无关代码（Position Independent Code, PIC）
// ==========================================
//
// 核心问题：
//   共享库在编译时不知道自己会被加载到哪个内存地址
//   （因为地址空间随机化ASLR，以及多个库需要共存）
//   所以代码中不能使用绝对地址
//
// PIC的解决方案：
//   所有对全局数据和外部函数的引用都使用相对地址
//   具体来说，使用"当前指令地址 + 偏移量"的方式寻址
//
// 在x86-64上，这特别简单——因为有RIP-relative寻址模式：
//   mov rax, [rip + offset]  ← 获取相对于当前PC的数据
//
// 在x86-32上则更复杂，需要通过 "call + pop" 技巧获取PC值
//
// ==========================================
// PIC vs 非PIC 代码对比
// ==========================================
//
// 全局变量访问：
//
// 非PIC (绝对地址，不能用于共享库):
//   mov eax, [0x08049234]    ← 硬编码地址
//
// PIC (相对地址，可用于共享库):
//   mov eax, [rip + offset]  ← 相对PC寻址（x86-64）
//   或通过GOT间接访问:
//   mov rax, [rip + GOT_offset]   ← 先从GOT获取真实地址
//   mov eax, [rax]                 ← 再读取数据
//
// ==========================================
// 共享库必须是PIC的原因
// ==========================================
//
// 1. 代码段共享
//    PIC的.text段可以被多个进程共享同一份物理内存
//    因为代码段不包含进程特定的绝对地址
//
// 2. ASLR兼容
//    安全机制要求库加载地址随机化
//    PIC代码在任何地址都能正确运行
//
// 3. 多实例共存
//    同一个库可能被加载到不同进程的不同地址
//    PIC确保一份代码多处可用

#include <iostream>

namespace pic_demo {

// ==========================================
// PIC的性能影响
// ==========================================
//
// PIC对性能的影响在现代CPU上几乎可以忽略：
//
// x86-64:
//   - RIP-relative寻址是原生支持的，零额外开销
//   - 函数调用通过PLT多一次间接跳转（首次调用有解析开销）
//   - GOT表访问多一次内存读取（通常在L1 cache中）
//
// 实测数据（典型场景）：
//   直接函数调用：~1ns
//   PLT间接调用（已解析）：~1.5ns
//   PLT间接调用（首次，需解析）：~5-10μs
//   GOT全局变量访问：~0.5ns额外开销
//
// 结论：对插件系统来说，PIC的性能影响完全可以忽略
// 插件的IO、算法复杂度等才是真正的性能瓶颈

// ==========================================
// 编译选项说明
// ==========================================
//
// -fPIC  : Position Independent Code（共享库必须）
// -fPIE  : Position Independent Executable（可执行文件）
// -fpic  : 小写版本，使用较小的GOT（某些平台上更快但有限制）
//
// 共享库编译命令：
//   g++ -shared -fPIC -o libplugin.so plugin.cpp
//
// 如果忘记-fPIC编译共享库：
//   - 链接器会报错："relocation R_X86_64_32 against symbol ...
//     can not be used when making a shared object"
//   - 或者即使成功，每个进程都需要单独的代码段拷贝（浪费内存）

void demonstratePICImpact() {
    // 局部变量访问：PIC和非PIC完全一样（都在栈上）
    int localVar = 42;
    std::cout << localVar << std::endl;  // 无额外开销

    // 全局/静态变量访问：PIC需要通过GOT
    static int staticVar = 100;
    std::cout << staticVar << std::endl;  // PIC多一次间接寻址

    // 外部函数调用：PIC通过PLT
    // std::cout的operator<<就是一个外部函数调用
    // PIC模式下会通过PLT跳转
}

} // namespace pic_demo
```

```
PIC代码中全局变量访问的内存布局：

进程A的地址空间:                    进程B的地址空间:
┌──────────────────┐                ┌──────────────────┐
│    Stack          │                │    Stack          │
├──────────────────┤                ├──────────────────┤
│    Heap           │                │    Heap           │
├──────────────────┤                ├──────────────────┤
│                  │                │                  │
│  libplugin.so    │ 加载在0x7f01   │  libplugin.so    │ 加载在0x7f05
│  ┌────────────┐  │                │  ┌────────────┐  │
│  │ .text(代码) │  │◄──── 共享 ────►│  │ .text(代码) │  │
│  │ (PIC,只读)  │  │  同一物理页     │  │ (PIC,只读)  │  │
│  ├────────────┤  │                │  ├────────────┤  │
│  │ .got(数据)  │  │ 独立拷贝       │  │ .got(数据)  │  │
│  │ (可写)     │  │ (进程特定地址)  │  │ (可写)     │  │
│  └────────────┘  │                │  └────────────┘  │
├──────────────────┤                ├──────────────────┤
│    main程序      │                │    main程序      │
└──────────────────┘                └──────────────────┘

关键：.text段因为PIC而可以共享，节省物理内存
      .got段每个进程独立，包含进程特定的地址
```

---

#### 1.7 库搜索路径与依赖管理

```cpp
// ==========================================
// 动态库搜索路径机制
// ==========================================
//
// 当dlopen("libfoo.so")被调用时，动态链接器如何找到这个文件？
//
// Linux搜索顺序（按优先级从高到低）：
//
// 1. DT_RPATH（ELF中嵌入的路径，已过时）
//    └── 设置方式：-Wl,-rpath,/path/to/libs
//    └── 问题：不能被LD_LIBRARY_PATH覆盖
//
// 2. LD_LIBRARY_PATH 环境变量
//    └── 多个路径用冒号分隔
//    └── 仅用于开发调试，不要用于生产环境！
//    └── 安全风险：setuid程序会忽略此变量
//
// 3. DT_RUNPATH（ELF中嵌入的路径，推荐）
//    └── 设置方式：-Wl,--enable-new-dtags,-rpath,/path
//    └── 可以被LD_LIBRARY_PATH覆盖
//
// 4. /etc/ld.so.cache（ldconfig缓存）
//    └── ldconfig扫描/etc/ld.so.conf中列出的路径
//    └── 生成二进制缓存文件加速查找
//
// 5. 默认路径：/lib 和 /usr/lib
//
// ==========================================
// $ORIGIN —— 插件系统的关键技巧
// ==========================================
//
// $ORIGIN表示"包含当前ELF文件的目录"
// 这对插件系统极为重要——让程序能找到相对于自身的库
//
// 示例目录结构：
//   /opt/myapp/
//   ├── bin/myapp          ← 主程序
//   ├── lib/libcore.so     ← 核心库
//   └── plugins/           ← 插件目录
//       ├── libpluginA.so
//       └── libpluginB.so
//
// 主程序编译：
//   g++ -o myapp main.cpp -Wl,-rpath,'$ORIGIN/../lib'
//   → myapp运行时会在自身所在目录的../lib/中搜索库
//
// 插件编译：
//   g++ -shared -o libpluginA.so pluginA.cpp \
//       -Wl,-rpath,'$ORIGIN/../lib'
//   → 插件也能找到相对路径的核心库

#include <iostream>
#include <string>
#include <vector>
#include <filesystem>

namespace search_paths {

// ==========================================
// macOS的特殊情况：@rpath / @executable_path / @loader_path
// ==========================================
//
// macOS不使用LD_LIBRARY_PATH（虽然DYLD_LIBRARY_PATH类似）
// 而是有自己的一套路径变量：
//
// @executable_path — 主可执行文件所在目录
//   用于：应用程序包内的库
//   示例：@executable_path/../Frameworks/libfoo.dylib
//
// @loader_path — 当前正在加载的二进制文件所在目录
//   用于：插件找到自己附带的库
//   示例：@loader_path/deps/libhelper.dylib
//
// @rpath — 运行时搜索路径（可有多个）
//   用于：灵活的路径配置
//   设置：install_name_tool -add_rpath /path/to/libs myapp
//   引用：链接时使用 -install_name @rpath/libfoo.dylib
//
// 最佳实践（跨平台插件框架）：
//   编译时嵌入相对路径
//   Linux: $ORIGIN
//   macOS: @loader_path

class PluginPathResolver {
private:
    std::vector<std::filesystem::path> searchPaths_;
    std::string platformExtension_;

public:
    PluginPathResolver() {
#ifdef _WIN32
        platformExtension_ = ".dll";
#elif defined(__APPLE__)
        platformExtension_ = ".dylib";
#else
        platformExtension_ = ".so";
#endif
    }

    // 添加搜索路径
    void addSearchPath(const std::filesystem::path& path) {
        if (std::filesystem::exists(path) &&
            std::filesystem::is_directory(path)) {
            searchPaths_.push_back(std::filesystem::canonical(path));
        }
    }

    // 基于可执行文件位置添加相对路径
    void addRelativePath(const std::string& relativePath) {
        // 获取当前可执行文件路径
        auto exePath = std::filesystem::canonical("/proc/self/exe");
        auto basePath = exePath.parent_path();
        addSearchPath(basePath / relativePath);
    }

    // 解析插件名到完整路径
    std::optional<std::filesystem::path>
    resolve(const std::string& pluginName) const {
        // 如果是绝对路径，直接使用
        std::filesystem::path asPath(pluginName);
        if (asPath.is_absolute() && std::filesystem::exists(asPath)) {
            return asPath;
        }

        // 构建平台特定的库文件名
        std::string libName = platformLibName(pluginName);

        // 在所有搜索路径中查找
        for (const auto& searchPath : searchPaths_) {
            auto fullPath = searchPath / libName;
            if (std::filesystem::exists(fullPath)) {
                return std::filesystem::canonical(fullPath);
            }
        }

        return std::nullopt;
    }

    // 列出目录中所有插件文件
    std::vector<std::filesystem::path>
    discoverPlugins() const {
        std::vector<std::filesystem::path> plugins;

        for (const auto& searchPath : searchPaths_) {
            if (!std::filesystem::exists(searchPath)) continue;

            for (const auto& entry :
                 std::filesystem::directory_iterator(searchPath)) {
                if (entry.is_regular_file() &&
                    entry.path().extension() == platformExtension_) {
                    plugins.push_back(entry.path());
                }
            }
        }

        return plugins;
    }

private:
    std::string platformLibName(const std::string& name) const {
#ifdef _WIN32
        return name + platformExtension_;
#else
        // Unix平台库名前缀为lib
        if (name.substr(0, 3) != "lib") {
            return "lib" + name + platformExtension_;
        }
        return name + platformExtension_;
#endif
    }
};

} // namespace search_paths
```

```
各平台库搜索路径对比：

Linux:
┌─────────────────────────────────────────────┐
│ 1. DT_RPATH (ELF嵌入，已过时)                │
│ 2. LD_LIBRARY_PATH (环境变量)                │
│ 3. DT_RUNPATH (ELF嵌入，推荐)                │
│ 4. /etc/ld.so.cache (ldconfig缓存)          │
│ 5. /lib, /usr/lib (默认路径)                 │
│                                             │
│ 特殊变量: $ORIGIN = ELF文件所在目录           │
└─────────────────────────────────────────────┘

macOS:
┌─────────────────────────────────────────────┐
│ 1. DYLD_LIBRARY_PATH (环境变量，SIP限制)      │
│ 2. @rpath 搜索路径列表                       │
│ 3. DYLD_FALLBACK_LIBRARY_PATH               │
│ 4. /usr/lib, /usr/local/lib (默认路径)       │
│                                             │
│ 特殊变量:                                    │
│   @executable_path = 主程序所在目录           │
│   @loader_path = 当前加载者所在目录           │
│   @rpath = 运行时搜索路径（可配多个）          │
└─────────────────────────────────────────────┘

Windows:
┌─────────────────────────────────────────────┐
│ 1. 程序所在目录                              │
│ 2. 系统目录 (C:\Windows\System32)            │
│ 3. Windows目录 (C:\Windows)                  │
│ 4. 当前工作目录                              │
│ 5. PATH环境变量中的目录                       │
│                                             │
│ 注意: 搜索顺序可通过SetDllDirectory修改       │
│       SafeDllSearchMode影响当前目录优先级     │
└─────────────────────────────────────────────┘

推荐的插件目录结构：
┌──────────────────────────────────┐
│  myapp/                          │
│  ├── bin/                        │
│  │   └── myapp (rpath=$ORIGIN/../lib) │
│  ├── lib/                        │
│  │   ├── libcore.so              │
│  │   └── libutils.so             │
│  └── plugins/                    │
│      ├── libplugin_a.so          │
│      ├── libplugin_b.so          │
│      └── plugin_a.json (元数据)   │
└──────────────────────────────────┘
```

---

#### 1.8 本周练习任务

```cpp
// ==========================================
// 第一周练习任务
// ==========================================

/*
练习1：手动解析ELF头部
--------------------------------------
目标：深入理解ELF文件格式

要求：
1. 编写C++程序，读取任意.so文件的ELF头部
2. 解析并打印以下信息：
   - 文件类型（ET_DYN/ET_EXEC等）
   - 目标架构（x86-64/ARM等）
   - 入口地址
   - Section数量和名称列表
   - 动态符号表中所有导出符号的名称
3. 与readelf -h和readelf -s的输出进行对比验证
4. 尝试解析一个.dylib文件，理解Mach-O与ELF的区别

验证：
- 程序输出与readelf完全一致
- 能正确识别共享库的导出符号
- 撰写300字对比ELF和Mach-O的结构差异
*/

/*
练习2：实现迷你动态加载器
--------------------------------------
目标：掌握dlopen/dlsym的完整使用模式

要求：
1. 创建一个数学运算插件（math_plugin.so），导出以下C函数：
   - double add(double a, double b)
   - double multiply(double a, double b)
   - const char* getPluginName()
2. 编写宿主程序，使用dlopen/dlsym加载插件并调用所有导出函数
3. 实现RAII封装的SafeLibrary类（参考1.4节）
4. 处理所有错误情况：库不存在、符号未找到、类型不匹配
5. 实验RTLD_NOW vs RTLD_LAZY的行为差异：
   - 故意不定义一个被声明的函数
   - 观察RTLD_NOW和RTLD_LAZY下的不同表现

验证：
- 插件能正确加载和卸载
- 所有函数调用结果正确
- RAII包装确保无资源泄漏
- 能清晰解释RTLD_NOW和RTLD_LAZY的差异
*/

/*
练习3：符号冲突实验
--------------------------------------
目标：理解符号可见性的实际影响

要求：
1. 创建两个插件，各自定义一个同名函数 void logMessage(const char*)
   - pluginA: logMessage写到stdout
   - pluginB: logMessage写到stderr
2. 分别用以下方式加载并调用，记录行为差异：
   a. 两个都用RTLD_GLOBAL加载
   b. 两个都用RTLD_LOCAL加载
   c. A用RTLD_GLOBAL，B用RTLD_LOCAL
3. 然后用-fvisibility=hidden重新编译两个插件
   - 只导出必要的createPlugin/destroyPlugin
   - 验证logMessage不再冲突
4. 使用nm -D和objdump -T分析各情况下的符号表

验证：
- 能准确预测每种组合下logMessage绑定到哪个实现
- 理解RTLD_GLOBAL的"污染"效应
- 使用-fvisibility=hidden后，nm -D输出只有预期的导出符号
- 撰写500字报告，总结符号可见性最佳实践
*/

/*
练习4：跨平台库路径解析器
--------------------------------------
目标：实现可在Linux/macOS/Windows上工作的库搜索逻辑

要求：
1. 实现PluginPathResolver类（参考1.7节），支持：
   - 添加绝对路径和相对路径（相对于可执行文件）
   - 自动添加平台特定的文件名前缀和后缀
   - 在搜索路径中查找指定名称的插件
   - 扫描目录发现所有插件文件
2. 编写测试程序验证路径解析逻辑
3. 实现一个简单的配置文件（JSON/INI）指定搜索路径
4. 处理符号链接和权限问题

验证：
- 在至少两个平台上编译通过
- 路径解析正确处理各种边界情况
- 配置文件能正确加载搜索路径
- 单元测试覆盖主要分支
*/
```

---

#### 1.9 本周知识检验

```
思考题1：为什么现代操作系统都采用ASLR（地址空间随机化）？
这对插件系统的设计有什么影响？如果共享库不是PIC编译的，
在ASLR环境下会发生什么？
提示：考虑安全性（ROP/JOP攻击）、性能（text relocation的开销）、
内存效率（能否共享代码页）。

思考题2：dlclose()是否真的能完全卸载一个共享库？
在什么情况下调用dlclose()后库仍然留在内存中？
提示：考虑引用计数、RTLD_NODELETE标志、
全局对象的析构函数、C++ atexit注册的函数、
以及线程局部存储（TLS）的影响。

思考题3：为什么插件系统推荐使用extern "C"导出接口，
而不是直接导出C++类？直接导出C++类有哪些风险？
提示：考虑名称修饰（name mangling）的跨编译器差异、
vtable布局差异、异常传播问题、以及STL容器的ABI兼容性。

思考题4：延迟绑定（RTLD_LAZY）在什么场景下是更好的选择？
在什么场景下应该避免？对于插件系统你会如何选择？
提示：考虑启动时间 vs 运行时确定性、
安全敏感场景（如RELRO保护）、调试便利性。

思考题5：Linux的LD_PRELOAD机制允许在程序启动前
注入一个共享库来覆盖已有符号。这个机制的正当用途是什么？
它对插件系统的安全性有什么启示？
提示：考虑malloc替换（如jemalloc）、函数拦截（如strace原理）、
以及攻击场景（符号覆盖攻击）。

实践题1：计算动态链接的性能开销
给定条件：
- L1 cache访问延迟：1ns
- GOT表项通常在L1 cache中（热路径）
- PLT stub包含一次间接跳转指令
- 首次符号解析需要遍历所有已加载库的符号表
- 某插件导出100个符号，依赖5个共享库
计算：
a) 已解析符号的PLT调用相比直接调用的额外开销
b) 100个符号全部用RTLD_NOW解析需要多长时间（估算）
c) 如果用RTLD_LAZY，在调用最频繁的10个函数后的稳态开销

实践题2：设计一个插件加载器的错误诊断系统
要求：
- 能诊断以下常见错误并给出可读的错误信息：
  1. 库文件不存在
  2. 架构不匹配（32位 vs 64位）
  3. 符号未定义
  4. 版本不兼容
  5. 依赖缺失
- 为每种错误设计错误码和恢复建议
- 画出诊断流程图
```

---

### 第二周：插件架构模式

**学习目标**：
- [ ] 掌握四种主流插件架构模式（微内核式/管道过滤器/事件驱动/扩展点式）的适用场景
- [ ] 深入理解抽象工厂模式在插件注册中的应用
- [ ] 掌握扩展点（Extension Point）机制的设计与实现
- [ ] 理解插件发现机制（目录扫描/配置文件/注册中心）的权衡
- [ ] 完整掌握插件生命周期状态机的设计
- [ ] 学会用事件驱动模式实现插件间松耦合通信
- [ ] 理解依赖注入（DI）在插件框架中的角色
- [ ] 分析真实世界插件系统（VSCode/Eclipse）的架构决策

**阅读材料**：
- [ ] 《Plugin Architecture》- Martin Fowler
- [ ] Eclipse插件架构文档（Equinox/OSGi）
- [ ] VSCode Extension API设计文档
- [ ] Qt插件系统文档
- [ ] 《Pattern-Oriented Software Architecture Vol.1》- Microkernel模式
- [ ] Chrome Extension Architecture文档

#### 核心概念

**插件架构分层**
```
┌─────────────────────────────────────────────────────────┐
│                    应用层 (Application)                  │
│    使用插件提供的功能，不直接依赖具体插件实现              │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                  插件管理器 (Plugin Manager)             │
│    发现、加载、卸载、版本管理、依赖解析                   │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                  插件接口层 (Plugin Interface)           │
│    定义插件契约，稳定的API边界                           │
└─────────────────────────────────────────────────────────┘
                          │
         ┌────────────────┼────────────────┐
         ▼                ▼                ▼
┌─────────────┐   ┌─────────────┐   ┌─────────────┐
│  Plugin A   │   │  Plugin B   │   │  Plugin C   │
│  (.so/.dll) │   │  (.so/.dll) │   │  (.so/.dll) │
└─────────────┘   └─────────────┘   └─────────────┘
```

**插件元数据设计**
```json
{
    "id": "com.example.myplugin",
    "name": "My Plugin",
    "version": "1.2.0",
    "apiVersion": "2.0",
    "description": "A sample plugin",
    "author": "Developer Name",
    "license": "MIT",
    "entryPoint": "libmyplugin.so",
    "dependencies": [
        {"id": "com.example.core", "version": ">=1.0.0"},
        {"id": "com.example.utils", "version": "^2.0.0", "optional": true}
    ],
    "extensionPoints": [
        {"id": "editor.syntax", "handler": "SyntaxHandler"}
    ],
    "activationEvents": [
        "onCommand:myplugin.start",
        "onLanguage:python"
    ]
}
```

---

#### 2.1 插件架构模式全景

```cpp
// ==========================================
// 四种主流插件架构模式对比
// ==========================================
//
// 在设计插件系统之前，首先要选择正确的架构模式。
// 不同模式适用于不同场景，选错模式会导致系统难以演进。
//
// ==========================================
// 模式一：微内核模式（Microkernel / Plug-in Architecture）
// ==========================================
//
// 思想：最小核心 + 可插拔扩展
// 核心只提供基础设施（加载、通信、生命周期管理）
// 所有业务功能都是插件
//
// 适用场景：
//   - IDE（VSCode, Eclipse, IntelliJ）
//   - 浏览器（Chrome扩展）
//   - 操作系统（QNX微内核）
//   - 需要高度可定制的产品
//
// 优点：核心稳定，功能可任意组合
// 缺点：插件间通信需要精心设计，性能有间接调用开销
//
// ==========================================
// 模式二：管道-过滤器模式（Pipe and Filter）
// ==========================================
//
// 思想：数据流经一系列处理阶段，每个阶段是一个可替换的过滤器
//
// 适用场景：
//   - 编译器（词法→语法→语义→优化→代码生成）
//   - 图像处理（一系列滤镜）
//   - 数据转换管道（ETL）
//   - HTTP中间件
//
// 优点：插件接口统一（输入→处理→输出），易于组合
// 缺点：不适合非线性数据流，共享状态困难
//
// ==========================================
// 模式三：事件驱动模式（Event-Driven）
// ==========================================
//
// 思想：核心发布事件，插件订阅感兴趣的事件并响应
//
// 适用场景：
//   - GUI框架（Qt信号槽）
//   - 游戏引擎（Entity Component System）
//   - Web框架（Express中间件）
//   - 消息队列系统
//
// 优点：完全解耦，插件之间互不感知
// 缺点：调用链不直观（事件发了谁处理不确定），调试困难
//
// ==========================================
// 模式四：扩展点模式（Extension Point / Contribution）
// ==========================================
//
// 思想：核心声明扩展点，插件向扩展点贡献功能
// 扩展点有明确的schema，插件必须遵守
//
// 适用场景：
//   - Eclipse（Extension Registry）
//   - VSCode（Contribution Points）
//   - Webpack（Tapable hooks）
//
// 优点：类型安全，扩展有明确规范，可静态验证
// 缺点：扩展点设计需要前瞻性，后期修改困难

#include <string>
#include <vector>
#include <map>
#include <functional>
#include <memory>
#include <iostream>
#include <any>

namespace architecture_patterns {

// ==========================================
// 模式一示例：微内核模式
// ==========================================
//
// 核心特征：PluginManager管理一切
// 插件通过统一接口与核心交互

class IPlugin {
public:
    virtual ~IPlugin() = default;
    virtual std::string getId() const = 0;
    virtual bool initialize() = 0;
    virtual void execute() = 0;
};

// ==========================================
// 模式二示例：管道-过滤器模式
// ==========================================
//
// 核心特征：数据沿管道流动，每个过滤器做一步处理
// 非常适合数据处理类的插件系统

struct DataPacket {
    std::string content;
    std::map<std::string, std::string> metadata;
};

class IFilter {
public:
    virtual ~IFilter() = default;
    virtual DataPacket process(DataPacket input) = 0;
    virtual std::string getName() const = 0;
};

class Pipeline {
private:
    std::vector<std::shared_ptr<IFilter>> filters_;

public:
    void addFilter(std::shared_ptr<IFilter> filter) {
        filters_.push_back(std::move(filter));
    }

    // 在指定过滤器之前插入
    void insertBefore(const std::string& existingName,
                      std::shared_ptr<IFilter> filter) {
        for (auto it = filters_.begin(); it != filters_.end(); ++it) {
            if ((*it)->getName() == existingName) {
                filters_.insert(it, std::move(filter));
                return;
            }
        }
    }

    DataPacket execute(DataPacket input) {
        DataPacket data = std::move(input);
        for (auto& filter : filters_) {
            data = filter->process(std::move(data));
        }
        return data;
    }
};

// ==========================================
// 模式三示例：事件驱动模式
// ==========================================
//
// 核心特征：发布-订阅解耦
// 事件发布者不知道也不关心谁在监听

class EventBus {
public:
    using Handler = std::function<void(const std::any&)>;

    uint64_t subscribe(const std::string& event, Handler handler) {
        uint64_t id = ++nextId_;
        subscribers_[event].push_back({id, std::move(handler)});
        return id;
    }

    void publish(const std::string& event, const std::any& data) {
        auto it = subscribers_.find(event);
        if (it == subscribers_.end()) return;

        for (const auto& [id, handler] : it->second) {
            try {
                handler(data);
            } catch (const std::exception& e) {
                std::cerr << "Event handler error: " << e.what() << std::endl;
            }
        }
    }

private:
    struct Subscription {
        uint64_t id;
        Handler handler;
    };
    std::map<std::string, std::vector<Subscription>> subscribers_;
    uint64_t nextId_ = 0;
};

// ==========================================
// 模式四示例：扩展点模式
// ==========================================
//
// 核心特征：预定义扩展点，插件提供符合schema的贡献
// VSCode的"contributes"就是这种模式

struct ExtensionPointSchema {
    std::string id;
    std::string description;
    // 实际系统中这里可能是JSON Schema
    std::vector<std::string> requiredFields;
};

struct Contribution {
    std::string pluginId;
    std::string extensionPointId;
    std::map<std::string, std::any> properties;
};

class ExtensionRegistry {
private:
    std::map<std::string, ExtensionPointSchema> extensionPoints_;
    std::map<std::string, std::vector<Contribution>> contributions_;

public:
    // 核心声明扩展点
    void declareExtensionPoint(ExtensionPointSchema schema) {
        extensionPoints_[schema.id] = std::move(schema);
    }

    // 插件注册贡献
    bool registerContribution(Contribution contrib) {
        auto it = extensionPoints_.find(contrib.extensionPointId);
        if (it == extensionPoints_.end()) {
            std::cerr << "Unknown extension point: "
                      << contrib.extensionPointId << std::endl;
            return false;
        }

        // 验证贡献是否符合schema
        for (const auto& field : it->second.requiredFields) {
            if (contrib.properties.find(field) == contrib.properties.end()) {
                std::cerr << "Missing required field: " << field << std::endl;
                return false;
            }
        }

        contributions_[contrib.extensionPointId].push_back(
            std::move(contrib));
        return true;
    }

    // 获取某个扩展点的所有贡献
    std::vector<Contribution> getContributions(
        const std::string& extensionPointId) const {
        auto it = contributions_.find(extensionPointId);
        return it != contributions_.end() ? it->second
                                          : std::vector<Contribution>{};
    }
};

} // namespace architecture_patterns
```

```
四种插件架构模式决策树：

你的系统需要什么类型的扩展？
         │
    ┌────┴────┐
    │         │
  数据流     功能扩展
    │         │
    ▼         ▼
管道-过滤器   插件是否需要互相通信？
              │
         ┌────┴────┐
         │         │
       不需要     需要
         │         │
         ▼         ▼
     扩展点模式   通信是否有明确方向？
                  │
             ┌────┴────┐
             │         │
           有方向     无方向
             │         │
             ▼         ▼
         微内核模式  事件驱动模式

实际系统通常混合使用多种模式：
┌─────────────────────────────────┐
│  VSCode = 微内核 + 扩展点 + 事件 │
│  Eclipse = 微内核 + 扩展点       │
│  Webpack = 管道过滤器 + 事件     │
│  Express = 管道过滤器（中间件）   │
└─────────────────────────────────┘
```

---

#### 2.2 抽象工厂与插件注册

```cpp
// ==========================================
// 插件工厂注册表模式
// ==========================================
//
// 核心问题：
//   宿主程序在编译时不知道有哪些插件类存在，
//   那么运行时如何创建插件对象？
//
// 解决方案：工厂注册表
//   1. 定义统一的插件接口
//   2. 每个插件导出一个工厂函数（createPlugin）
//   3. 插件管理器通过dlsym获取工厂函数
//   4. 调用工厂函数创建插件实例
//
// 进阶方案：自注册工厂
//   利用C++全局对象的构造函数在main()之前执行的特性，
//   让插件在加载时自动将自己注册到工厂注册表中
//   （但这种方式在动态库中需要小心——dlopen的时机很重要）

#include <string>
#include <map>
#include <memory>
#include <functional>
#include <iostream>
#include <mutex>

namespace plugin_factory {

// ==========================================
// 基础版本：C风格工厂函数
// ==========================================
//
// 这是最常用也是最可靠的方式
// 每个插件.so导出一组C函数作为入口点

// 插件接口
class IPlugin {
public:
    virtual ~IPlugin() = default;
    virtual std::string getName() const = 0;
    virtual void execute() = 0;
};

// 工厂函数签名
using CreateFunc = IPlugin* (*)();
using DestroyFunc = void (*)(IPlugin*);

// ==========================================
// 进阶版本：类型安全的工厂注册表
// ==========================================
//
// 支持按名字创建不同类型的插件
// 插件DLL可以注册多个组件类型

template<typename Base>
class PluginRegistry {
public:
    using FactoryFunc = std::function<std::unique_ptr<Base>()>;

    // 单例访问
    static PluginRegistry& instance() {
        static PluginRegistry registry;
        return registry;
    }

    // 注册工厂
    bool registerFactory(const std::string& typeName,
                        FactoryFunc factory) {
        std::lock_guard<std::mutex> lock(mutex_);

        if (factories_.count(typeName)) {
            std::cerr << "Type already registered: "
                      << typeName << std::endl;
            return false;
        }

        factories_[typeName] = std::move(factory);
        std::cout << "Registered: " << typeName << std::endl;
        return true;
    }

    // 创建实例
    std::unique_ptr<Base> create(const std::string& typeName) const {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = factories_.find(typeName);
        if (it == factories_.end()) {
            std::cerr << "Unknown type: " << typeName << std::endl;
            return nullptr;
        }

        return it->second();
    }

    // 列出所有已注册类型
    std::vector<std::string> getRegisteredTypes() const {
        std::lock_guard<std::mutex> lock(mutex_);
        std::vector<std::string> types;
        for (const auto& [name, _] : factories_) {
            types.push_back(name);
        }
        return types;
    }

    // 注销（卸载插件时调用）
    void unregister(const std::string& typeName) {
        std::lock_guard<std::mutex> lock(mutex_);
        factories_.erase(typeName);
    }

private:
    PluginRegistry() = default;
    std::map<std::string, FactoryFunc> factories_;
    mutable std::mutex mutex_;
};

// ==========================================
// 自注册宏
// ==========================================
//
// 使用这个宏，插件只需要一行代码就能注册自己
// 原理：利用全局对象的构造函数在库加载时执行

#define REGISTER_PLUGIN(PluginClass, TypeName) \
    namespace { \
        struct PluginClass##Registrar { \
            PluginClass##Registrar() { \
                ::plugin_factory::PluginRegistry<IPlugin>::instance() \
                    .registerFactory(TypeName, []() { \
                        return std::make_unique<PluginClass>(); \
                    }); \
            } \
        }; \
        static PluginClass##Registrar g_##PluginClass##_registrar; \
    }

// ==========================================
// 使用示例
// ==========================================

class ConcretePluginA : public IPlugin {
public:
    std::string getName() const override { return "PluginA"; }
    void execute() override {
        std::cout << "PluginA executing" << std::endl;
    }
};

// 一行注册——加载.so时自动注册
// REGISTER_PLUGIN(ConcretePluginA, "pluginA")

} // namespace plugin_factory
```

---

#### 2.3 扩展点机制设计

```cpp
// ==========================================
// 扩展点（Extension Point）机制详解
// ==========================================
//
// 扩展点是一种声明式的插件扩展机制，
// 核心思想：宿主定义"可以被扩展的位置"，插件向这些位置贡献功能
//
// VSCode的Contribution Points就是典型案例：
//   - "commands": 插件可以注册新命令
//   - "menus": 插件可以往菜单添加项目
//   - "languages": 插件可以声明支持的编程语言
//   - "themes": 插件可以贡献颜色主题
//
// 关键优势：
//   1. 类型安全——扩展必须符合预定义的schema
//   2. 声明式——不需要编写注册代码，在配置文件中声明即可
//   3. 可枚举——系统可以在不激活插件的情况下获知所有扩展
//   4. 可验证——加载前就能检查扩展是否合法
//
// 与直接API调用的对比：
//   API方式：plugin->registerCommand("myCmd", handler);
//   扩展点方式：在manifest.json中声明 "commands": [{"id": "myCmd"}]
//
// 扩展点方式的好处是：不需要执行插件代码就能获知它提供的功能
// 这使得"懒加载"成为可能——只在真正需要时才激活插件

#include <string>
#include <vector>
#include <map>
#include <any>
#include <functional>
#include <optional>
#include <iostream>
#include <memory>

namespace extension_points {

// ==========================================
// 扩展点定义
// ==========================================

// 字段验证器
using FieldValidator = std::function<bool(const std::any& value)>;

struct FieldSchema {
    std::string name;
    std::string type;        // "string", "number", "boolean", "object"
    bool required = true;
    std::string description;
    FieldValidator validator;
};

// 扩展点Schema——定义一个扩展点接受什么样的贡献
struct ExtensionPoint {
    std::string id;                // 如 "editor.commands"
    std::string description;       // 描述此扩展点的用途
    std::vector<FieldSchema> schema;  // 贡献必须提供的字段
};

// 插件的贡献——插件向扩展点提供的具体内容
struct ExtensionContribution {
    std::string pluginId;
    std::string extensionPointId;
    std::map<std::string, std::any> data;
};

// ==========================================
// 扩展点注册表
// ==========================================

class ExtensionPointRegistry {
private:
    // 已声明的扩展点
    std::map<std::string, ExtensionPoint> points_;
    // 每个扩展点收到的贡献
    std::map<std::string, std::vector<ExtensionContribution>> contributions_;
    // 变更监听器
    std::map<std::string,
        std::vector<std::function<void(const ExtensionContribution&)>>> listeners_;

public:
    // 宿主声明扩展点
    void declarePoint(ExtensionPoint point) {
        std::cout << "Extension point declared: " << point.id << std::endl;
        points_[point.id] = std::move(point);
    }

    // 插件注册贡献
    bool contribute(ExtensionContribution contrib) {
        // 1. 检查扩展点是否存在
        auto pointIt = points_.find(contrib.extensionPointId);
        if (pointIt == points_.end()) {
            std::cerr << "Unknown extension point: "
                      << contrib.extensionPointId << std::endl;
            return false;
        }

        // 2. 验证贡献是否符合schema
        if (!validateContribution(pointIt->second, contrib)) {
            return false;
        }

        // 3. 注册贡献
        contributions_[contrib.extensionPointId].push_back(contrib);

        // 4. 通知监听器
        auto listenerIt = listeners_.find(contrib.extensionPointId);
        if (listenerIt != listeners_.end()) {
            for (const auto& listener : listenerIt->second) {
                listener(contrib);
            }
        }

        std::cout << "Contribution registered: " << contrib.pluginId
                  << " -> " << contrib.extensionPointId << std::endl;
        return true;
    }

    // 查询某扩展点的所有贡献
    std::vector<ExtensionContribution> getContributions(
        const std::string& pointId) const {
        auto it = contributions_.find(pointId);
        return it != contributions_.end() ? it->second
                                          : std::vector<ExtensionContribution>{};
    }

    // 监听新贡献
    void onContribution(const std::string& pointId,
        std::function<void(const ExtensionContribution&)> listener) {
        listeners_[pointId].push_back(std::move(listener));
    }

private:
    bool validateContribution(const ExtensionPoint& point,
                             const ExtensionContribution& contrib) {
        for (const auto& field : point.schema) {
            auto it = contrib.data.find(field.name);

            if (it == contrib.data.end()) {
                if (field.required) {
                    std::cerr << "Missing required field: "
                              << field.name << std::endl;
                    return false;
                }
                continue;
            }

            if (field.validator && !field.validator(it->second)) {
                std::cerr << "Validation failed for field: "
                          << field.name << std::endl;
                return false;
            }
        }
        return true;
    }
};

// ==========================================
// 使用示例：定义菜单扩展点
// ==========================================

void demonstrateExtensionPoints() {
    ExtensionPointRegistry registry;

    // 宿主声明"菜单"扩展点
    registry.declarePoint({
        "app.menus",
        "Register menu items in the application",
        {
            {"title", "string", true, "Menu item display text", nullptr},
            {"command", "string", true, "Command to execute", nullptr},
            {"group", "string", false, "Menu group name", nullptr},
        }
    });

    // 监听新的菜单贡献
    registry.onContribution("app.menus",
        [](const ExtensionContribution& c) {
            auto title = std::any_cast<std::string>(
                c.data.at("title"));
            std::cout << "New menu item: " << title << std::endl;
        });

    // 插件贡献菜单项
    registry.contribute({
        "com.example.git",       // 来自git插件
        "app.menus",              // 向菜单扩展点贡献
        {
            {"title", std::string("Git: Commit")},
            {"command", std::string("git.commit")},
            {"group", std::string("source_control")},
        }
    });
}

} // namespace extension_points
```

---

#### 2.4 插件发现与加载策略

```cpp
// ==========================================
// 插件发现机制
// ==========================================
//
// 插件发现是插件系统的第一步——系统如何知道有哪些插件可用？
//
// 三种主流发现机制：
//
// 1. 目录扫描（最简单，最常用）
//    └── 扫描约定目录下的所有.so/.dll文件
//    └── 优点：零配置，拷贝即安装
//    └── 缺点：无法预知插件信息，需要加载才能获取元数据
//
// 2. 配置文件声明
//    └── 在配置文件中明确列出启用的插件
//    └── 优点：精确控制，可以配置参数
//    └── 缺点：需要手动维护配置
//
// 3. 清单文件（Manifest）
//    └── 每个插件附带一个描述文件（如package.json）
//    └── 优点：不加载库就能获取元数据（最佳方案）
//    └── 缺点：需要额外文件
//
// ==========================================
// 加载策略
// ==========================================
//
// 立即加载（Eager Loading）：
//   启动时加载所有插件
//   优点：简单，启动后所有功能立即可用
//   缺点：启动慢，内存占用大
//
// 延迟加载（Lazy Loading）：
//   首次使用时才加载插件
//   优点：启动快，只加载实际需要的插件
//   缺点：首次使用有加载延迟
//
// VSCode的方案——激活事件（Activation Events）：
//   插件声明"在什么事件发生时激活我"
//   例如：onLanguage:python → 打开Python文件时才加载Python插件
//   这是目前最先进的延迟加载方案

#include <string>
#include <vector>
#include <filesystem>
#include <fstream>
#include <map>
#include <memory>
#include <iostream>
#include <optional>
#include <functional>

namespace plugin_discovery {

// 插件清单（不加载库就能获取的信息）
struct PluginManifest {
    std::string id;
    std::string name;
    std::string version;
    std::string entryPoint;       // 库文件名
    std::string description;
    std::vector<std::string> dependencies;
    std::vector<std::string> activationEvents;  // 激活条件
    std::filesystem::path basePath;  // 插件所在目录
};

// ==========================================
// 基于清单文件的插件发现器
// ==========================================
//
// 每个插件是一个目录，包含：
//   plugin-name/
//   ├── manifest.json    ← 元数据（不需要加载库）
//   └── libplugin.so     ← 实际代码

class ManifestBasedDiscoverer {
private:
    std::vector<std::filesystem::path> searchPaths_;

public:
    void addSearchPath(const std::filesystem::path& path) {
        searchPaths_.push_back(path);
    }

    // 扫描所有插件目录，解析清单文件
    std::vector<PluginManifest> discover() const {
        std::vector<PluginManifest> manifests;

        for (const auto& searchPath : searchPaths_) {
            if (!std::filesystem::exists(searchPath)) continue;

            for (const auto& entry :
                 std::filesystem::directory_iterator(searchPath)) {
                if (!entry.is_directory()) continue;

                auto manifestPath = entry.path() / "manifest.json";
                if (!std::filesystem::exists(manifestPath)) continue;

                auto manifest = parseManifest(manifestPath);
                if (manifest) {
                    manifest->basePath = entry.path();
                    manifests.push_back(std::move(*manifest));
                }
            }
        }

        return manifests;
    }

private:
    std::optional<PluginManifest> parseManifest(
        const std::filesystem::path& path) const {
        // 简化的JSON解析（实际应使用nlohmann/json等库）
        std::ifstream file(path);
        if (!file) return std::nullopt;

        PluginManifest manifest;
        // ... 解析JSON内容 ...
        return manifest;
    }
};

// ==========================================
// 激活事件驱动的懒加载管理器
// ==========================================

class LazyPluginManager {
private:
    struct PendingPlugin {
        PluginManifest manifest;
        bool loaded = false;
    };

    std::vector<PendingPlugin> pending_;
    // 激活事件 → 需要激活的插件索引列表
    std::map<std::string, std::vector<size_t>> activationMap_;

    std::function<void(const PluginManifest&)> loadCallback_;

public:
    void setLoadCallback(
        std::function<void(const PluginManifest&)> callback) {
        loadCallback_ = std::move(callback);
    }

    // 注册发现的插件（但不立即加载）
    void registerPlugin(PluginManifest manifest) {
        size_t index = pending_.size();

        // 建立激活事件映射
        for (const auto& event : manifest.activationEvents) {
            activationMap_[event].push_back(index);
        }

        // 特殊事件"*"表示立即激活
        bool immediate = manifest.activationEvents.empty() ||
            std::find(manifest.activationEvents.begin(),
                      manifest.activationEvents.end(),
                      "*") != manifest.activationEvents.end();

        pending_.push_back({std::move(manifest), false});

        if (immediate) {
            activatePlugin(index);
        }
    }

    // 触发激活事件
    void fireEvent(const std::string& event) {
        auto it = activationMap_.find(event);
        if (it == activationMap_.end()) return;

        for (size_t index : it->second) {
            activatePlugin(index);
        }
    }

    size_t pendingCount() const {
        size_t count = 0;
        for (const auto& p : pending_) {
            if (!p.loaded) ++count;
        }
        return count;
    }

private:
    void activatePlugin(size_t index) {
        auto& pending = pending_[index];
        if (pending.loaded) return;

        std::cout << "Lazy-loading plugin: "
                  << pending.manifest.name << std::endl;

        if (loadCallback_) {
            loadCallback_(pending.manifest);
        }
        pending.loaded = true;
    }
};

} // namespace plugin_discovery
```

```
VSCode激活事件（Activation Events）机制：

┌──────────────────────────────────────────────────┐
│                    VSCode Host                    │
│                                                  │
│  ┌─ Activation Event Table ───────────────────┐  │
│  │                                            │  │
│  │  "onLanguage:python"  → [Python插件]        │  │
│  │  "onCommand:git.commit" → [Git插件]         │  │
│  │  "onView:explorer"    → [FileExplorer插件]  │  │
│  │  "onDebug:node"       → [Node调试插件]      │  │
│  │  "*"                  → [核心插件]          │  │
│  │                                            │  │
│  └────────────────────────────────────────────┘  │
│                                                  │
│  启动时：                                        │
│  1. 读取所有插件的package.json（不加载JS代码）     │
│  2. 构建激活事件映射表                            │
│  3. 只加载activationEvents=["*"]的核心插件        │
│                                                  │
│  用户打开.py文件时：                              │
│  1. 触发 "onLanguage:python" 事件                │
│  2. 查表找到Python插件                           │
│  3. 此时才加载Python插件的Extension Host进程       │
│  4. 调用插件的activate()函数                      │
│                                                  │
│  效果：启动时间 < 1秒（不加载不需要的插件）         │
└──────────────────────────────────────────────────┘
```

---

#### 2.5 插件生命周期状态机

```cpp
// ==========================================
// 插件生命周期状态机
// ==========================================
//
// 一个健壮的插件系统必须有明确的生命周期管理。
// 每个插件在任何时刻都处于一个确定的状态，
// 状态之间的转换有明确的触发条件和限制。
//
// 完整的状态转换图：
//
//  ┌──────────┐    discover    ┌──────────┐
//  │ (不存在)  │──────────────►│Discovered│
//  └──────────┘                └────┬─────┘
//                                   │ resolve dependencies
//                                   ▼
//                              ┌──────────┐
//                              │ Resolved │
//                              └────┬─────┘
//                                   │ load library
//                                   ▼
//                              ┌──────────┐
//                     ┌───────►│  Loaded  │◄───────┐
//                     │        └────┬─────┘        │
//                     │             │ initialize    │
//                     │             ▼               │
//                     │        ┌──────────┐        │
//                     │        │  Ready   │        │ deactivate
//                     │        └────┬─────┘        │
//                     │             │ activate      │
//            unload   │             ▼               │
//                     │        ┌──────────┐        │
//                     │        │  Active  │────────┘
//                     │        └────┬─────┘
//                     │             │ error
//                     │             ▼
//                     │        ┌──────────┐
//                     └────────│  Error   │
//                              └──────────┘

#include <string>
#include <map>
#include <functional>
#include <iostream>
#include <optional>
#include <stdexcept>
#include <vector>
#include <mutex>

namespace lifecycle {

enum class PluginState {
    Discovered,   // 发现但未解析依赖
    Resolved,     // 依赖已解析
    Loaded,       // 库已加载到内存
    Ready,        // 已初始化，等待激活
    Active,       // 正在运行
    Error,        // 出错
    Uninstalled   // 已卸载
};

const char* stateToString(PluginState state) {
    switch (state) {
        case PluginState::Discovered:  return "Discovered";
        case PluginState::Resolved:    return "Resolved";
        case PluginState::Loaded:      return "Loaded";
        case PluginState::Ready:       return "Ready";
        case PluginState::Active:      return "Active";
        case PluginState::Error:       return "Error";
        case PluginState::Uninstalled: return "Uninstalled";
    }
    return "Unknown";
}

// ==========================================
// 状态机实现
// ==========================================

class PluginStateMachine {
public:
    using TransitionCallback = std::function<bool()>;
    using StateChangeListener = std::function<void(PluginState, PluginState)>;

private:
    PluginState currentState_ = PluginState::Discovered;
    std::string pluginId_;

    // 合法状态转换表
    // key: {from, to}, value: 执行转换的回调
    struct TransitionKey {
        PluginState from;
        PluginState to;
        bool operator<(const TransitionKey& o) const {
            if (from != o.from) return from < o.from;
            return to < o.to;
        }
    };
    std::map<TransitionKey, TransitionCallback> transitions_;
    std::vector<StateChangeListener> listeners_;
    std::mutex mutex_;

public:
    explicit PluginStateMachine(std::string pluginId)
        : pluginId_(std::move(pluginId)) {

        // 定义所有合法的状态转换
        // 非法转换（如从Discovered直接到Active）会被拒绝
    }

    // 注册状态转换处理器
    void registerTransition(PluginState from, PluginState to,
                           TransitionCallback callback) {
        transitions_[{from, to}] = std::move(callback);
    }

    // 执行状态转换
    bool transitionTo(PluginState target) {
        std::lock_guard<std::mutex> lock(mutex_);

        TransitionKey key{currentState_, target};
        auto it = transitions_.find(key);

        if (it == transitions_.end()) {
            std::cerr << "[" << pluginId_ << "] Illegal transition: "
                      << stateToString(currentState_) << " -> "
                      << stateToString(target) << std::endl;
            return false;
        }

        std::cout << "[" << pluginId_ << "] "
                  << stateToString(currentState_) << " -> "
                  << stateToString(target) << std::endl;

        // 执行转换回调
        if (it->second && !it->second()) {
            std::cerr << "[" << pluginId_
                      << "] Transition failed, entering Error state"
                      << std::endl;
            auto prev = currentState_;
            currentState_ = PluginState::Error;
            notifyListeners(prev, PluginState::Error);
            return false;
        }

        auto prev = currentState_;
        currentState_ = target;
        notifyListeners(prev, target);
        return true;
    }

    // 监听状态变更
    void addListener(StateChangeListener listener) {
        listeners_.push_back(std::move(listener));
    }

    PluginState getState() const { return currentState_; }

private:
    void notifyListeners(PluginState from, PluginState to) {
        for (const auto& listener : listeners_) {
            listener(from, to);
        }
    }
};

} // namespace lifecycle
```

---

#### 2.6 事件驱动的插件通信

```cpp
// ==========================================
// 插件间通信：事件驱动模型
// ==========================================
//
// 插件之间不应该直接引用对方（那样就变成了紧耦合的组件系统）
// 正确的方式是通过事件/消息间接通信
//
// 三种插件通信模式对比：
//
// 1. 直接调用（❌ 不推荐）
//    pluginA->getPluginB()->doSomething();
//    问题：A必须知道B的存在，B卸载后A崩溃
//
// 2. 服务注册（✅ 适中）
//    auto service = context->getService<ILogger>();
//    if (service) service->log("hello");
//    好处：通过接口解耦，但调用者需要知道接口定义
//
// 3. 事件/消息（✅ 最松耦合）
//    context->publish("file.saved", {filePath});
//    好处：发布者和订阅者完全不知道对方存在
//    缺点：间接性使调试更困难

#include <string>
#include <vector>
#include <map>
#include <functional>
#include <any>
#include <mutex>
#include <iostream>
#include <memory>
#include <queue>
#include <thread>
#include <condition_variable>
#include <atomic>

namespace plugin_events {

// 事件优先级
enum class EventPriority {
    Low = 0,
    Normal = 1,
    High = 2,
    Critical = 3
};

// 事件对象
struct Event {
    std::string type;           // 事件类型标识
    std::any data;              // 事件数据
    std::string sourcePlugin;   // 发布者插件ID
    bool cancelled = false;     // 是否被取消（可取消事件）
};

// 事件处理器
struct EventHandler {
    uint64_t id;
    std::string pluginId;       // 注册者插件ID
    EventPriority priority;
    std::function<void(Event&)> handler;
};

// ==========================================
// 高级事件总线
// ==========================================
//
// 特性：
// - 支持优先级（高优先级处理器先执行）
// - 支持事件取消（cancelable events）
// - 支持同步和异步分发
// - 支持通配符订阅（"file.*" 匹配 "file.opened", "file.closed"）
// - 自动清理：插件卸载时移除其所有订阅

class AdvancedEventBus {
private:
    std::map<std::string, std::vector<EventHandler>> handlers_;
    std::mutex mutex_;
    uint64_t nextId_ = 0;

    // 异步事件队列
    std::queue<Event> asyncQueue_;
    std::mutex queueMutex_;
    std::condition_variable queueCV_;
    std::atomic<bool> running_{false};
    std::thread asyncThread_;

public:
    AdvancedEventBus() = default;

    ~AdvancedEventBus() {
        stopAsync();
    }

    // 订阅事件
    uint64_t subscribe(const std::string& eventType,
                      const std::string& pluginId,
                      std::function<void(Event&)> handler,
                      EventPriority priority = EventPriority::Normal) {
        std::lock_guard<std::mutex> lock(mutex_);

        uint64_t id = ++nextId_;
        handlers_[eventType].push_back({
            id, pluginId, priority, std::move(handler)
        });

        // 按优先级排序（高优先级在前）
        auto& vec = handlers_[eventType];
        std::sort(vec.begin(), vec.end(),
            [](const EventHandler& a, const EventHandler& b) {
                return a.priority > b.priority;
            });

        return id;
    }

    // 同步发布事件
    void publishSync(Event event) {
        std::vector<EventHandler> handlersToCall;

        {
            std::lock_guard<std::mutex> lock(mutex_);
            auto it = handlers_.find(event.type);
            if (it != handlers_.end()) {
                handlersToCall = it->second;
            }
        }

        for (auto& handler : handlersToCall) {
            if (event.cancelled) break;
            try {
                handler.handler(event);
            } catch (const std::exception& e) {
                std::cerr << "Event handler error (" << handler.pluginId
                          << "): " << e.what() << std::endl;
            }
        }
    }

    // 异步发布事件（放入队列，由后台线程处理）
    void publishAsync(Event event) {
        std::lock_guard<std::mutex> lock(queueMutex_);
        asyncQueue_.push(std::move(event));
        queueCV_.notify_one();
    }

    // 移除某个插件的所有订阅
    void removePlugin(const std::string& pluginId) {
        std::lock_guard<std::mutex> lock(mutex_);
        for (auto& [type, handlers] : handlers_) {
            handlers.erase(
                std::remove_if(handlers.begin(), handlers.end(),
                    [&](const EventHandler& h) {
                        return h.pluginId == pluginId;
                    }),
                handlers.end());
        }
    }

    // 启动异步处理线程
    void startAsync() {
        running_ = true;
        asyncThread_ = std::thread([this] {
            while (running_) {
                Event event;
                {
                    std::unique_lock<std::mutex> lock(queueMutex_);
                    queueCV_.wait(lock, [this] {
                        return !asyncQueue_.empty() || !running_;
                    });
                    if (!running_ && asyncQueue_.empty()) break;
                    event = std::move(asyncQueue_.front());
                    asyncQueue_.pop();
                }
                publishSync(std::move(event));
            }
        });
    }

    void stopAsync() {
        running_ = false;
        queueCV_.notify_all();
        if (asyncThread_.joinable()) {
            asyncThread_.join();
        }
    }
};

} // namespace plugin_events
```

---

#### 2.7 依赖注入与服务定位器

```cpp
// ==========================================
// 依赖注入（DI）在插件框架中的应用
// ==========================================
//
// 问题：插件需要使用宿主或其他插件提供的服务
//       如何获取这些服务的引用？
//
// 方案一：服务定位器模式（Service Locator）
//   auto logger = ServiceLocator::get<ILogger>();
//   优点：简单直接
//   缺点：隐式依赖（代码中看不出需要ILogger），难以测试
//
// 方案二：依赖注入模式（Dependency Injection）
//   class MyPlugin {
//       MyPlugin(ILogger& logger) : logger_(logger) {}
//   };
//   优点：显式依赖，易测试
//   缺点：插件创建逻辑更复杂
//
// 实际插件系统通常用混合方案：
//   - 核心服务通过上下文对象注入（类似DI）
//   - 可选服务通过服务注册表查询（类似Service Locator）

#include <string>
#include <map>
#include <memory>
#include <functional>
#include <typeindex>
#include <any>
#include <mutex>
#include <iostream>

namespace dependency_injection {

// ==========================================
// 简易IoC容器
// ==========================================
//
// IoC (Inversion of Control) 容器管理服务的创建和生命周期
// 插件框架用它来为插件提供所需的服务

class ServiceContainer {
public:
    enum class Lifetime {
        Transient,   // 每次请求创建新实例
        Singleton    // 全局单例
    };

private:
    struct ServiceEntry {
        std::function<std::any()> factory;
        Lifetime lifetime;
        std::any instance;  // Singleton缓存
    };

    std::map<std::type_index, ServiceEntry> services_;
    mutable std::mutex mutex_;

public:
    // 注册服务（工厂函数）
    template<typename Interface, typename Implementation>
    void registerService(Lifetime lifetime = Lifetime::Singleton) {
        std::lock_guard<std::mutex> lock(mutex_);

        services_[std::type_index(typeid(Interface))] = {
            []() -> std::any {
                return std::make_shared<Implementation>();
            },
            lifetime,
            {}
        };
    }

    // 注册已有实例
    template<typename Interface>
    void registerInstance(std::shared_ptr<Interface> instance) {
        std::lock_guard<std::mutex> lock(mutex_);

        services_[std::type_index(typeid(Interface))] = {
            nullptr,
            Lifetime::Singleton,
            instance
        };
    }

    // 获取服务
    template<typename Interface>
    std::shared_ptr<Interface> resolve() {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = services_.find(std::type_index(typeid(Interface)));
        if (it == services_.end()) {
            return nullptr;
        }

        auto& entry = it->second;

        if (entry.lifetime == Lifetime::Singleton && entry.instance.has_value()) {
            return std::any_cast<std::shared_ptr<Interface>>(entry.instance);
        }

        auto instance = std::any_cast<std::shared_ptr<Interface>>(
            entry.factory());

        if (entry.lifetime == Lifetime::Singleton) {
            entry.instance = instance;
        }

        return instance;
    }

    // 检查服务是否已注册
    template<typename Interface>
    bool hasService() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return services_.count(std::type_index(typeid(Interface))) > 0;
    }
};

// ==========================================
// 插件上下文（注入给每个插件的服务入口）
// ==========================================
//
// 每个插件通过这个上下文获取宿主提供的服务
// 这是DI模式的体现——服务被"注入"到插件中

class PluginContext {
private:
    ServiceContainer& container_;
    std::string pluginId_;

public:
    PluginContext(ServiceContainer& container, std::string pluginId)
        : container_(container), pluginId_(std::move(pluginId)) {}

    template<typename T>
    std::shared_ptr<T> getService() {
        return container_.resolve<T>();
    }

    const std::string& getPluginId() const { return pluginId_; }
};

// 使用示例
struct ILogger {
    virtual ~ILogger() = default;
    virtual void log(const std::string& msg) = 0;
};

struct ConsoleLogger : ILogger {
    void log(const std::string& msg) override {
        std::cout << "[LOG] " << msg << std::endl;
    }
};

void demonstrate() {
    ServiceContainer container;
    container.registerService<ILogger, ConsoleLogger>();

    // 为插件创建上下文
    PluginContext ctx(container, "com.example.myplugin");

    // 插件通过上下文获取服务
    auto logger = ctx.getService<ILogger>();
    if (logger) {
        logger->log("Hello from plugin!");
    }
}

} // namespace dependency_injection
```

---

#### 2.8 真实案例分析：VSCode扩展系统

```cpp
// ==========================================
// VSCode扩展系统架构深度分析
// ==========================================
//
// VSCode是当今最成功的插件化应用之一，
// 它的扩展系统设计值得每个插件框架开发者深入学习。
//
// ==========================================
// 核心架构特征
// ==========================================
//
// 1. Extension Host进程隔离
//    VSCode主进程（Electron）和扩展运行在不同进程中
//    ┌──────────────┐     JSON-RPC      ┌──────────────────┐
//    │ Main Process │◄═════════════════►│ Extension Host   │
//    │ (UI/Editor)  │                   │ (Node.js进程)     │
//    │              │                   │ ┌──────────────┐ │
//    │              │                   │ │ Extension A  │ │
//    │              │                   │ │ Extension B  │ │
//    │              │                   │ │ Extension C  │ │
//    │              │                   │ └──────────────┘ │
//    └──────────────┘                   └──────────────────┘
//
//    好处：
//    - 扩展崩溃不影响主UI
//    - 扩展不能直接操作DOM（安全）
//    - 扩展可以做耗时操作不阻塞UI
//
// 2. package.json驱动
//    所有扩展信息都声明在package.json中
//    VSCode启动时只读取JSON，不执行扩展代码
//    这使得：
//    - 启动速度极快（不需要加载所有扩展）
//    - 可以展示扩展信息（命令面板、设置）而不激活扩展
//    - 扩展市场能展示扩展的能力
//
// 3. API surface受控
//    扩展只能使用vscode命名空间下的API
//    不能直接访问文件系统、网络等（需要通过API）
//    API是版本化的，向后兼容
//
// ==========================================
// 关键设计决策及其C++映射
// ==========================================

#include <string>
#include <vector>
#include <functional>
#include <map>
#include <memory>
#include <any>
#include <optional>

namespace vscode_analysis {

// ==========================================
// Activation Events — VSCode最重要的设计
// ==========================================
//
// 扩展不是启动时全部加载的
// 而是声明"在什么条件下激活我"
//
// 常见激活事件：
//   "onLanguage:python"       → 打开Python文件时
//   "onCommand:extension.cmd" → 执行特定命令时
//   "onView:sidebar.tree"     → 特定视图显示时
//   "onFileSystem:sftp"       → 访问特定文件系统时
//   "onStartupFinished"       → 启动完成后（低优先级）
//   "*"                       → 立即激活（尽量避免）

// C++中模拟激活事件系统
class ActivationService {
public:
    using ActivateCallback = std::function<void(const std::string& pluginId)>;

private:
    // pluginId → 其激活事件列表
    std::map<std::string, std::vector<std::string>> pluginEvents_;
    // event → 等待此事件的插件列表
    std::map<std::string, std::vector<std::string>> pendingActivations_;
    // 已激活的插件
    std::map<std::string, bool> activated_;

    ActivateCallback activateCallback_;

public:
    void setActivateCallback(ActivateCallback cb) {
        activateCallback_ = std::move(cb);
    }

    // 从manifest注册插件的激活事件
    void registerPlugin(const std::string& pluginId,
                       const std::vector<std::string>& events) {
        pluginEvents_[pluginId] = events;
        activated_[pluginId] = false;

        for (const auto& event : events) {
            pendingActivations_[event].push_back(pluginId);
        }
    }

    // 触发事件（可能激活等待此事件的插件）
    void triggerEvent(const std::string& event) {
        auto it = pendingActivations_.find(event);
        if (it == pendingActivations_.end()) return;

        for (const auto& pluginId : it->second) {
            if (!activated_[pluginId]) {
                activated_[pluginId] = true;
                if (activateCallback_) {
                    activateCallback_(pluginId);
                }
            }
        }
    }
};

// ==========================================
// Contribution Points — 声明式扩展
// ==========================================
//
// VSCode的核心扩展机制：
//
// package.json中的"contributes"字段：
// {
//     "contributes": {
//         "commands": [{
//             "command": "myplugin.helloWorld",
//             "title": "Hello World"
//         }],
//         "menus": {
//             "editor/context": [{
//                 "command": "myplugin.helloWorld",
//                 "when": "editorTextFocus"
//             }]
//         },
//         "configuration": {
//             "title": "My Plugin",
//             "properties": {
//                 "myplugin.enabled": {
//                     "type": "boolean",
//                     "default": true
//                 }
//             }
//         }
//     }
// }
//
// 这些信息在不激活扩展的情况下就能被VSCode使用：
// - 命令面板中显示 "Hello World"
// - 右键菜单中显示项目
// - 设置面板中显示配置选项

// ==========================================
// VSCode架构的C++启示
// ==========================================
//
// 如果用C++构建类似系统：
//
// 1. 进程隔离 → fork + IPC (Unix Domain Socket / Shared Memory)
// 2. package.json → manifest.json (运行时不需要加载.so就能读取)
// 3. Activation Events → 事件驱动的懒加载（参考2.4节）
// 4. Contribution Points → 扩展点注册表（参考2.3节）
// 5. API surface → 稳定的C ABI接口 + 版本检查
// 6. Extension Host → 独立进程运行插件代码

} // namespace vscode_analysis
```

```
VSCode扩展加载时序图：

时间 ──────────────────────────────────────────────────►

VSCode启动:
│
├─ 扫描extensions目录
│  ├─ 读取每个扩展的package.json
│  ├─ 构建Activation Event映射表
│  └─ 构建Contribution Points注册表
│
├─ 渲染UI（使用Contribution Points数据）
│  ├─ 填充命令面板
│  ├─ 构建菜单
│  └─ 渲染设置面板
│
├─ 激活 activationEvents=["*"] 的扩展
│
│  ... 用户开始工作 ...
│
├─ 用户打开 hello.py
│  ├─ 触发 "onLanguage:python"
│  ├─ 查找等待此事件的扩展
│  ├─ Fork Extension Host进程（如果尚未启动）
│  ├─ 加载Python扩展代码
│  └─ 调用 extension.activate()
│
├─ 用户按Ctrl+Shift+P输入命令
│  ├─ 触发 "onCommand:xxx"
│  └─ 按需激活对应扩展
│
└─ VSCode关闭
   ├─ 对所有已激活扩展调用 extension.deactivate()
   └─ 终止Extension Host进程
```

---

#### 2.9 本周练习任务

```cpp
// ==========================================
// 第二周练习任务
// ==========================================

/*
练习1：实现插件工厂注册表
--------------------------------------
目标：掌握工厂模式在插件系统中的应用

要求：
1. 实现类型安全的PluginRegistry模板类（参考2.2节）
2. 支持三种注册方式：
   - C风格工厂函数（dlsym获取）
   - 自注册宏（REGISTER_PLUGIN）
   - 手动注册（registry.registerFactory(...)）
3. 创建3个不同的插件类，分别使用以上三种方式注册
4. 实现unregister功能，模拟插件卸载
5. 编写线程安全测试：多线程同时注册和创建实例

验证：
- 三种注册方式都能正确工作
- 创建的实例类型正确
- unregister后不能再创建该类型
- 多线程测试无数据竞争（用TSan检测）
*/

/*
练习2：实现扩展点系统
--------------------------------------
目标：理解声明式扩展机制

要求：
1. 实现ExtensionPointRegistry（参考2.3节）
2. 声明以下扩展点：
   - "app.commands": 命令注册（需要title, handler字段）
   - "app.menus": 菜单项（需要title, command, position字段）
   - "app.themes": 主题（需要name, colors字段）
3. 编写3个模拟插件，各自向不同扩展点贡献
4. 实现贡献的schema验证（缺少必须字段时报错）
5. 实现变更通知机制（新贡献注册时通知监听者）

验证：
- 贡献注册和查询正确
- 非法贡献被拒绝（缺少必要字段）
- 向不存在的扩展点贡献时给出清晰错误
- 监听器能收到新贡献的通知
*/

/*
练习3：实现激活事件管理器
--------------------------------------
目标：理解延迟加载的实现方式

要求：
1. 实现LazyPluginManager（参考2.4节）
2. 创建5个模拟插件，配置不同的激活事件：
   - PluginA: "*"（立即激活）
   - PluginB: "onCommand:build"
   - PluginC: "onLanguage:cpp"
   - PluginD: "onLanguage:python"
   - PluginE: "onView:sidebar"
3. 模拟以下用户操作序列，验证激活顺序：
   a. 程序启动 → 只有A被激活
   b. 打开.cpp文件 → C被激活
   c. 执行build命令 → B被激活
   d. 打开.py文件 → D被激活
   e. 打开侧边栏 → E被激活
4. 实现pendingCount()统计待激活插件数
5. 确保同一插件不会被激活两次

验证：
- 每一步的激活顺序完全正确
- 重复触发同一事件不会重复激活
- pendingCount在每步操作后正确更新
*/

/*
练习4：实现带优先级的事件总线
--------------------------------------
目标：掌握事件驱动通信模式

要求：
1. 实现AdvancedEventBus（参考2.6节），支持：
   - 优先级订阅（高优先级先执行）
   - 事件取消（handler可以取消事件传播）
   - 通配符订阅（"file.*" 匹配所有file开头的事件）
   - 异步事件分发（放入队列，后台线程处理）
2. 编写测试场景：
   - 3个订阅者订阅同一事件但优先级不同
   - 高优先级订阅者取消事件
   - 通配符匹配测试
   - 异步事件100个的并发处理
3. 实现removePlugin清理功能

验证：
- 优先级排序正确
- 取消后低优先级handler不被调用
- 通配符匹配正确
- 异步事件全部被处理（无遗漏）
- removePlugin后该插件的handler不再被调用
*/
```

---

#### 2.10 本周知识检验

```
思考题1：VSCode为什么选择把扩展运行在独立的Extension Host进程中，
而不是像Chrome扩展那样运行在沙箱化的渲染进程中？
这两种隔离方式各有什么优劣？
提示：考虑Node.js的特性（单线程、无法沙箱化）、
扩展需要访问文件系统和网络的需求、以及性能开销。

思考题2：扩展点模式（Contribution Points）相比直接API调用有什么优势？
在什么情况下直接API调用更合适？
提示：考虑静态分析能力、懒加载需求、schema验证、
以及高度动态的交互场景。

思考题3：为什么大多数插件系统都要求用extern "C"导出工厂函数，
而不是直接导出C++类？如果一定要跨库边界传递C++对象，
需要注意什么？
提示：name mangling差异、虚表布局、异常传播、
RTTI跨库问题、STL容器的ABI差异。

思考题4：事件驱动的插件通信和直接服务调用相比，
在调试和错误追踪方面有什么挑战？
如何改善事件驱动系统的可观测性？
提示：考虑调用栈不连续、因果关系不明确，
可用方案包括correlation ID、事件溯源、分布式追踪。

思考题5：一个插件框架应该允许插件之间直接依赖吗？
如果允许，依赖管理的复杂度会如何增长？
如果不允许，有什么替代方案？
提示：考虑钻石依赖问题、版本锁定、
通过宿主服务间接通信的方式。

实践题1：设计一个IDE的插件架构
要求：
- 支持语法高亮、代码补全、调试器、主题、文件浏览器等扩展
- 画出完整的架构图，标注使用的插件模式
- 列出所有需要的扩展点
- 设计插件间通信方式
- 说明激活策略（哪些立即加载，哪些延迟加载）

实践题2：对比分析三个真实的插件系统
选择以下任意三个：VSCode、Eclipse、IntelliJ、Vim、Emacs、Chrome
要求：
- 分析各自的插件发现机制
- 比较生命周期管理方式
- 对比通信机制（直接调用 vs 事件 vs 消息）
- 总结各自的优势和不足
- 用表格形式呈现对比结果
```

---

### 第三周：版本管理与兼容性

**学习目标**：
- [ ] 掌握语义化版本规范及版本约束匹配算法的实现
- [ ] 深入理解C++ ABI稳定性——哪些变更会破坏二进制兼容
- [ ] 熟练运用PIMPL模式构建ABI防火墙
- [ ] 理解COM风格接口版本化（QueryInterface模式）
- [ ] 掌握依赖解析算法（拓扑排序 + 版本约束求解）
- [ ] 学会设计向后兼容的API演进策略
- [ ] 理解插件迁移与升级的工程实践

**阅读材料**：
- [ ] Semantic Versioning 2.0.0规范（semver.org）
- [ ] API版本化最佳实践
- [ ] ABI稳定性指南
- [ ] COM接口版本化策略
- [ ] KDE ABI Compliance Checker文档
- [ ] Itanium C++ ABI规范
- [ ] 《Large-Scale C++ Software Design》- John Lakos

#### 核心概念

**语义化版本**
```
MAJOR.MINOR.PATCH

MAJOR: 不兼容的API变更
MINOR: 向后兼容的功能新增
PATCH: 向后兼容的问题修复

版本约束示例：
  "^1.2.3"  匹配 >=1.2.3, <2.0.0
  "~1.2.3"  匹配 >=1.2.3, <1.3.0
  ">=1.0.0" 匹配 >=1.0.0
  "1.2.x"   匹配 >=1.2.0, <1.3.0
```

**ABI兼容性检查清单**
```cpp
// ABI破坏性变更示例
class Widget {
    // ❌ 添加虚函数会改变vtable布局
    // virtual void newMethod();

    // ❌ 改变成员变量会改变对象大小
    // int newMember_;

    // ❌ 改变虚函数顺序
    // virtual void methodB();  // 原来methodA在前
    // virtual void methodA();

    // ✅ 安全：添加非虚函数
    void safeMethod();

    // ✅ 安全：添加静态成员
    static void staticMethod();

    // ✅ 安全：添加友元
    friend class Helper;
};

// PIMPL模式保持ABI稳定
class StableWidget {
public:
    StableWidget();
    ~StableWidget();

    void doSomething();

private:
    class Impl;
    std::unique_ptr<Impl> pImpl_;  // 实现细节隐藏
};
```

---

#### 3.1 语义化版本解析器实现

```cpp
// ==========================================
// 语义化版本（Semantic Versioning）完整实现
// ==========================================
//
// SemVer是插件系统版本管理的基石。
// 每个插件都用SemVer标识自己的版本，
// 依赖声明也用SemVer约束表示对其他插件的版本要求。
//
// 完整格式：MAJOR.MINOR.PATCH[-prerelease][+build]
//
// 示例：
//   1.0.0           → 稳定版本
//   2.1.3-alpha.1   → 预发布版本
//   1.0.0-rc.1+001  → 带构建元数据的RC版本
//
// 版本比较规则：
//   1. MAJOR > MINOR > PATCH
//   2. 预发布版本 < 正式版本 (1.0.0-alpha < 1.0.0)
//   3. 预发布标识按字典序比较 (alpha < beta < rc)
//   4. 构建元数据不参与比较
//
// 版本约束（Range）：
//   ^1.2.3  → >=1.2.3, <2.0.0  （兼容主版本）
//   ~1.2.3  → >=1.2.3, <1.3.0  （兼容次版本）
//   >=1.0.0 → >=1.0.0           （最低版本）
//   1.2.x   → >=1.2.0, <1.3.0  （通配符）
//   >=1.0 <2.0 → 范围组合

#include <string>
#include <vector>
#include <sstream>
#include <stdexcept>
#include <optional>
#include <algorithm>
#include <regex>
#include <iostream>

namespace semver {

struct Version {
    uint32_t major = 0;
    uint32_t minor = 0;
    uint32_t patch = 0;
    std::string prerelease;   // alpha.1, beta.2, rc.1
    std::string build;        // 构建元数据（不参与比较）

    // 从字符串解析版本
    static Version parse(const std::string& str) {
        Version v;

        // 提取构建元数据（+号后面的部分）
        std::string remaining = str;
        auto plusPos = remaining.find('+');
        if (plusPos != std::string::npos) {
            v.build = remaining.substr(plusPos + 1);
            remaining = remaining.substr(0, plusPos);
        }

        // 提取预发布标识（-号后面的部分）
        auto dashPos = remaining.find('-');
        if (dashPos != std::string::npos) {
            v.prerelease = remaining.substr(dashPos + 1);
            remaining = remaining.substr(0, dashPos);
        }

        // 解析MAJOR.MINOR.PATCH
        if (std::sscanf(remaining.c_str(), "%u.%u.%u",
                        &v.major, &v.minor, &v.patch) < 1) {
            throw std::invalid_argument("Invalid version: " + str);
        }

        return v;
    }

    std::string toString() const {
        std::string result = std::to_string(major) + "." +
                            std::to_string(minor) + "." +
                            std::to_string(patch);
        if (!prerelease.empty()) result += "-" + prerelease;
        if (!build.empty()) result += "+" + build;
        return result;
    }

    // 比较运算符
    // 注意：build元数据不参与比较！
    int compare(const Version& other) const {
        if (major != other.major)
            return major < other.major ? -1 : 1;
        if (minor != other.minor)
            return minor < other.minor ? -1 : 1;
        if (patch != other.patch)
            return patch < other.patch ? -1 : 1;

        // 预发布版本比较
        // 有预发布标识 < 没有预发布标识
        if (prerelease.empty() && other.prerelease.empty()) return 0;
        if (prerelease.empty()) return 1;   // this是正式版，other是预发布
        if (other.prerelease.empty()) return -1;

        return prerelease.compare(other.prerelease);
    }

    bool operator<(const Version& o) const { return compare(o) < 0; }
    bool operator>(const Version& o) const { return compare(o) > 0; }
    bool operator==(const Version& o) const { return compare(o) == 0; }
    bool operator!=(const Version& o) const { return compare(o) != 0; }
    bool operator<=(const Version& o) const { return compare(o) <= 0; }
    bool operator>=(const Version& o) const { return compare(o) >= 0; }
};

// ==========================================
// 版本约束（Range）
// ==========================================

class VersionConstraint {
public:
    enum class Type {
        Exact,       // =1.2.3
        Caret,       // ^1.2.3 (兼容主版本)
        Tilde,       // ~1.2.3 (兼容次版本)
        GreaterEq,   // >=1.2.3
        LessEq,      // <=1.2.3
        Greater,     // >1.2.3
        Less,        // <1.2.3
        Any          // *
    };

private:
    Type type_;
    Version version_;

public:
    VersionConstraint(Type type, Version version)
        : type_(type), version_(std::move(version)) {}

    // 解析约束字符串
    static VersionConstraint parse(const std::string& str) {
        if (str == "*") return {Type::Any, {}};

        if (str[0] == '^') return {Type::Caret, Version::parse(str.substr(1))};
        if (str[0] == '~') return {Type::Tilde, Version::parse(str.substr(1))};
        if (str.substr(0, 2) == ">=") return {Type::GreaterEq, Version::parse(str.substr(2))};
        if (str.substr(0, 2) == "<=") return {Type::LessEq, Version::parse(str.substr(2))};
        if (str[0] == '>') return {Type::Greater, Version::parse(str.substr(1))};
        if (str[0] == '<') return {Type::Less, Version::parse(str.substr(1))};

        return {Type::Exact, Version::parse(str)};
    }

    // 检查版本是否满足约束
    bool satisfiedBy(const Version& v) const {
        switch (type_) {
            case Type::Any: return true;
            case Type::Exact: return v == version_;
            case Type::GreaterEq: return v >= version_;
            case Type::LessEq: return v <= version_;
            case Type::Greater: return v > version_;
            case Type::Less: return v < version_;

            case Type::Caret:
                // ^1.2.3 → >=1.2.3, <2.0.0
                // ^0.2.3 → >=0.2.3, <0.3.0 (0.x特殊处理)
                // ^0.0.3 → >=0.0.3, <0.0.4
                if (version_.major > 0) {
                    return v >= version_ && v.major == version_.major;
                } else if (version_.minor > 0) {
                    return v >= version_ &&
                           v.major == 0 && v.minor == version_.minor;
                } else {
                    return v == version_;
                }

            case Type::Tilde:
                // ~1.2.3 → >=1.2.3, <1.3.0
                return v >= version_ &&
                       v.major == version_.major &&
                       v.minor == version_.minor;
        }
        return false;
    }
};

} // namespace semver
```

---

#### 3.2 ABI稳定性深度分析

```cpp
// ==========================================
// C++ ABI稳定性——插件系统的隐形杀手
// ==========================================
//
// ABI (Application Binary Interface) 是编译后的二进制级接口。
// API是源码级兼容，ABI是二进制级兼容。
//
// 关键区别：
//   API兼容 = 重新编译后能通过
//   ABI兼容 = 不重新编译，旧的.so也能正常工作
//
// 对插件系统来说，ABI兼容至关重要！
// 因为：
//   1. 宿主升级后，用户不想重新编译所有插件
//   2. 插件来自第三方，可能无法获取源码
//   3. 不同版本的编译器可能产生不同的ABI
//
// ==========================================
// C++ ABI的组成
// ==========================================
//
// C++ ABI涉及以下方面（以Itanium ABI为准）：
//
// 1. 名称修饰（Name Mangling）
//    void foo(int) → _Z3fooi
//    不同编译器的修饰规则可能不同（但GCC/Clang/ICC遵循Itanium ABI）
//    MSVC使用自己的修饰规则
//
// 2. 虚表（vtable）布局
//    虚函数在vtable中的排列顺序
//    添加/删除/重排虚函数会破坏ABI
//
// 3. 对象内存布局
//    成员变量的偏移量
//    sizeof和alignof
//    添加/删除/重排成员变量会破坏ABI
//
// 4. 函数调用约定
//    参数如何传递（寄存器/栈）
//    返回值如何传递
//    栈如何清理
//
// 5. 异常处理
//    异常表格式
//    throw/catch的运行时机制

#include <iostream>
#include <cstddef>

namespace abi_stability {

// ==========================================
// 破坏ABI的变更示例
// ==========================================

// === 版本1 ===
class WidgetV1 {
public:
    virtual ~WidgetV1() = default;
    virtual void draw() = 0;       // vtable[0] (在析构后)
    virtual void resize() = 0;     // vtable[1]

    int getWidth() const { return width_; }

protected:
    int width_ = 100;    // offset 8 (vtable指针后)
    int height_ = 100;   // offset 12
};

// === 版本2 (ABI破坏！) ===
class WidgetV2 {
public:
    virtual ~WidgetV2() = default;
    virtual void draw() = 0;       // vtable[0]
    virtual void update() = 0;     // vtable[1] ← 新增！draw的位置没变
                                    //              但resize变成了vtable[2]
    virtual void resize() = 0;     // vtable[2] ← 偏移变了！

    int getWidth() const { return width_; }

protected:
    int width_ = 100;    // offset 8
    bool visible_ = true; // offset 12 ← 新增！
    int height_ = 100;   // offset 16 ← 偏移变了！从12变成16
};

// 用旧插件（编译时看到WidgetV1）调用新宿主（运行时是WidgetV2）：
// - 调用resize()时，实际调用的是vtable[1]，
//   但V2中vtable[1]是update()，不是resize()！
// - 访问height_时，读的是offset 12，
//   但V2中offset 12是visible_，不是height_！

} // namespace abi_stability
```

```
vtable布局变化导致的ABI破坏：

WidgetV1的vtable:                   WidgetV2的vtable:
┌────────────────────┐               ┌────────────────────┐
│ [0] ~WidgetV1()    │               │ [0] ~WidgetV2()    │
│ [1] draw()         │               │ [1] draw()         │
│ [2] resize()       │ ← 旧插件      │ [2] update()       │ ← 新增！
└────────────────────┘   调用[2]      │ [3] resize()       │ ← 偏移变了
                         期望resize   └────────────────────┘
                         实际调用
                         update()！   ← 运行时错误！

对象内存布局变化：

WidgetV1:                            WidgetV2:
┌──────────────────┐ offset          ┌──────────────────┐ offset
│ vtable_ptr       │ 0               │ vtable_ptr       │ 0
│ width_ (int)     │ 8               │ width_ (int)     │ 8
│ height_ (int)    │ 12              │ visible_ (bool)  │ 12  ← 插入！
└──────────────────┘                 │ padding (3B)     │ 13
  sizeof = 16                        │ height_ (int)    │ 16  ← 偏移变了
                                     └──────────────────┘
                                       sizeof = 24（也变了！）

旧插件访问 height_ 时读offset 12，
但新版本中offset 12是 visible_——数据错乱！
```

---

#### 3.3 PIMPL模式与ABI防火墙

```cpp
// ==========================================
// PIMPL（Pointer to Implementation）模式
// ==========================================
//
// PIMPL是C++中保持ABI稳定的最重要技术。
// 也被称为：
//   - 编译防火墙（Compilation Firewall）
//   - d-pointer（Qt中的叫法）
//   - Cheshire Cat模式
//   - 不透明指针（Opaque Pointer）
//
// 核心思想：
//   公开头文件只包含一个指向实现的指针
//   所有实现细节都放在.cpp文件中
//   修改实现不会影响公开头文件→不会破坏ABI
//
// 为什么PIMPL能保持ABI稳定？
//   因为公开类的内存布局永远是：
//   [vtable指针(如果有)] + [一个Impl指针]
//   不管实现怎么变，sizeof和成员偏移都不变

#include <memory>
#include <string>
#include <iostream>

namespace pimpl_pattern {

// ==========================================
// 公开头文件 (stable_widget.hpp)
// 这个文件发布给插件开发者
// ==========================================

class StableWidget {
public:
    // 构造/析构必须声明（因为Impl在头文件中是不完整类型）
    StableWidget();
    StableWidget(int width, int height);
    ~StableWidget();

    // 拷贝和移动操作也需要显式声明
    StableWidget(const StableWidget& other);
    StableWidget& operator=(const StableWidget& other);
    StableWidget(StableWidget&& other) noexcept;
    StableWidget& operator=(StableWidget&& other) noexcept;

    // 公开API——这些是ABI的一部分
    void draw();
    void resize(int width, int height);
    int getWidth() const;
    int getHeight() const;

    // V2新增方法——可以安全添加，因为不是虚函数
    void setVisible(bool visible);
    bool isVisible() const;

private:
    // PIMPL核心——只有一个指针
    // Impl的定义在.cpp中，外部看不到
    class Impl;
    std::unique_ptr<Impl> pImpl_;
};

// ==========================================
// 实现文件 (stable_widget.cpp)
// 这个文件不发布给插件开发者
// 可以任意修改不影响ABI
// ==========================================

// V1 实现
class StableWidget::Impl {
public:
    int width = 100;
    int height = 100;
    // V2新增——不影响ABI！
    bool visible = true;
    std::string name = "default";
    // 可以继续添加任何成员...
};

StableWidget::StableWidget()
    : pImpl_(std::make_unique<Impl>()) {}

StableWidget::StableWidget(int width, int height)
    : pImpl_(std::make_unique<Impl>()) {
    pImpl_->width = width;
    pImpl_->height = height;
}

StableWidget::~StableWidget() = default;

StableWidget::StableWidget(const StableWidget& other)
    : pImpl_(std::make_unique<Impl>(*other.pImpl_)) {}

StableWidget& StableWidget::operator=(const StableWidget& other) {
    if (this != &other) {
        *pImpl_ = *other.pImpl_;
    }
    return *this;
}

StableWidget::StableWidget(StableWidget&& other) noexcept = default;
StableWidget& StableWidget::operator=(StableWidget&& other) noexcept = default;

void StableWidget::draw() {
    std::cout << "Drawing widget: " << pImpl_->name
              << " (" << pImpl_->width << "x" << pImpl_->height << ")"
              << std::endl;
}

void StableWidget::resize(int width, int height) {
    pImpl_->width = width;
    pImpl_->height = height;
}

int StableWidget::getWidth() const { return pImpl_->width; }
int StableWidget::getHeight() const { return pImpl_->height; }
void StableWidget::setVisible(bool visible) { pImpl_->visible = visible; }
bool StableWidget::isVisible() const { return pImpl_->visible; }

// ==========================================
// PIMPL的性能考量
// ==========================================
//
// PIMPL的代价：
//   1. 堆分配：Impl对象在堆上，多一次malloc
//   2. 间接寻址：每次访问成员多一次指针解引用
//   3. 缓存不友好：Widget和Impl可能不在同一缓存行
//
// 实测开销（典型场景）：
//   堆分配：~30ns（可用内存池优化到~5ns）
//   间接寻址：~0.5ns（L1 cache命中时）
//
// 对插件系统来说这个开销完全可以接受
// ABI稳定性远比这点性能开销重要
//
// Qt的实践：
//   Qt几乎所有公开类都使用PIMPL（Q_D/Q_Q宏）
//   这使得Qt能在次版本升级中保持二进制兼容

} // namespace pimpl_pattern
```

```
PIMPL如何保持ABI稳定：

不使用PIMPL（脆弱）:                使用PIMPL（稳定）:

Widget.hpp:                         Widget.hpp:
┌──────────────────┐                ┌──────────────────┐
│ class Widget {   │                │ class Widget {   │
│   int width_;    │ ← 暴露        │   class Impl;    │
│   int height_;   │ ← 暴露        │   Impl* pImpl_;  │ ← 永远不变
│   bool visible_; │ ← 暴露        │ };               │
│ };               │                └──────────────────┘
└──────────────────┘                   sizeof永远 = 指针大小
  sizeof会随成员变化

添加新成员时:                        添加新成员时:
Widget.hpp需要修改                   Widget.hpp不需要修改
→ 所有插件必须重编译                  → 旧插件继续工作

内存布局:                            内存布局:
┌──────────────────┐                ┌────────┐     ┌──────────────────┐
│ width_ (4B)      │                │ pImpl_ │────►│ width_ (4B)      │
│ height_ (4B)     │                └────────┘     │ height_ (4B)     │
│ visible_ (1B)    │ ← 新增         永远8字节       │ visible_ (1B)    │
│ padding (3B)     │                               │ name_ (32B)      │
│ name_ (32B)      │ ← 新增                        │ ... 任意添加 ...  │
└──────────────────┘                               └──────────────────┘
  sizeof变了!                                       Impl可以随意扩展
  ABI破坏!                                          Widget的sizeof不变
```

---

#### 3.4 COM风格接口版本化

```cpp
// ==========================================
// COM风格接口版本化——无PIMPL的ABI稳定方案
// ==========================================
//
// Microsoft的COM（Component Object Model）提供了一种
// 不需要PIMPL也能保持ABI稳定的方案。
//
// 核心思想：
//   1. 接口是纯虚类，永远不修改已发布的接口
//   2. 新功能通过新接口提供（IWidget2继承IWidget）
//   3. 客户端通过QueryInterface查询对象是否支持某接口
//   4. 引用计数管理生命周期
//
// 这种方式的优势：
//   - 不需要PIMPL的性能开销
//   - 支持跨语言（C、C++、C#都能使用COM接口）
//   - 非常明确的版本演进路径
//
// 缺点：
//   - 代码冗余（很多QueryInterface/AddRef/Release样板代码）
//   - 不够"C++风格"

#include <cstdint>
#include <atomic>
#include <memory>
#include <string>
#include <iostream>
#include <map>
#include <functional>

namespace com_style {

// 接口ID类型（简化版，实际COM用GUID）
using InterfaceId = const char*;

// ==========================================
// 基础接口（类似IUnknown）
// ==========================================

class IUnknownLite {
public:
    virtual ~IUnknownLite() = default;

    // 查询是否支持某个接口
    virtual void* queryInterface(InterfaceId id) = 0;

    // 引用计数
    virtual uint32_t addRef() = 0;
    virtual uint32_t release() = 0;
};

// ==========================================
// 版本化接口示例
// ==========================================

// V1接口——一旦发布就永远不修改
class IWidget : public IUnknownLite {
public:
    static constexpr InterfaceId IID = "IWidget.v1";

    virtual void draw() = 0;
    virtual void resize(int w, int h) = 0;
    // 永远不在这里添加新方法！
};

// V2接口——通过继承扩展功能
class IWidget2 : public IWidget {
public:
    static constexpr InterfaceId IID = "IWidget2.v2";

    // 新增方法放在V2接口中
    virtual void setOpacity(float opacity) = 0;
    virtual float getOpacity() const = 0;
};

// V3接口——继续扩展
class IWidget3 : public IWidget2 {
public:
    static constexpr InterfaceId IID = "IWidget3.v3";

    virtual void setTooltip(const char* text) = 0;
};

// ==========================================
// 实现类（实现所有版本的接口）
// ==========================================

class WidgetImpl : public IWidget3 {
private:
    std::atomic<uint32_t> refCount_{1};
    int width_ = 100;
    int height_ = 100;
    float opacity_ = 1.0f;
    std::string tooltip_;

public:
    // QueryInterface实现
    void* queryInterface(InterfaceId id) override {
        if (id == IWidget::IID) return static_cast<IWidget*>(this);
        if (id == IWidget2::IID) return static_cast<IWidget2*>(this);
        if (id == IWidget3::IID) return static_cast<IWidget3*>(this);
        return nullptr;  // 不支持的接口
    }

    uint32_t addRef() override { return ++refCount_; }
    uint32_t release() override {
        uint32_t count = --refCount_;
        if (count == 0) delete this;
        return count;
    }

    // IWidget实现
    void draw() override {
        std::cout << "Drawing " << width_ << "x" << height_ << std::endl;
    }
    void resize(int w, int h) override { width_ = w; height_ = h; }

    // IWidget2实现
    void setOpacity(float opacity) override { opacity_ = opacity; }
    float getOpacity() const override { return opacity_; }

    // IWidget3实现
    void setTooltip(const char* text) override { tooltip_ = text; }
};

// ==========================================
// 客户端使用方式
// ==========================================

void clientCode(IWidget* widget) {
    // 基本功能（V1）总是可用的
    widget->draw();

    // 检查是否支持V2功能
    auto* widget2 = static_cast<IWidget2*>(
        widget->queryInterface(IWidget2::IID));
    if (widget2) {
        // 支持V2，使用新功能
        widget2->setOpacity(0.5f);
    } else {
        // 不支持V2，graceful degradation
        std::cout << "Widget V2 not supported, skipping opacity" << std::endl;
    }

    // 检查V3
    auto* widget3 = static_cast<IWidget3*>(
        widget->queryInterface(IWidget3::IID));
    if (widget3) {
        widget3->setTooltip("Hello!");
    }
}

} // namespace com_style
```

---

#### 3.5 依赖解析算法

```cpp
// ==========================================
// 插件依赖解析
// ==========================================
//
// 当插件之间有依赖关系时，需要解决两个问题：
//   1. 确定加载/初始化顺序（拓扑排序）
//   2. 检查版本约束是否可满足（约束求解）
//
// 常见问题：
//   - 循环依赖：A→B→C→A（必须检测并拒绝）
//   - 钻石依赖：A→B→D, A→C→D（D可能有版本冲突）
//   - 不可满足的约束：A需要D>=2.0, B需要D<1.5
//
// ==========================================
// 实际包管理器的策略对比
// ==========================================
//
// npm (Node.js):
//   - 允许每个包有自己的依赖版本（嵌套node_modules）
//   - 钻石依赖时可以安装多个版本
//   - 缺点：磁盘空间浪费，"依赖地狱"
//
// Cargo (Rust):
//   - SemVer兼容的版本可以合并
//   - 不兼容时允许多版本共存
//   - 使用SAT求解器解析约束
//
// Go Modules:
//   - 最小版本选择（MVS）——选择满足约束的最低版本
//   - 简单可预测，但可能错过bug修复

#include <string>
#include <vector>
#include <map>
#include <set>
#include <queue>
#include <algorithm>
#include <stdexcept>
#include <iostream>
#include <optional>
#include <functional>

namespace dependency_resolver {

// 依赖声明
struct Dependency {
    std::string id;
    std::string versionConstraint;  // 如 "^1.2.0"
    bool optional = false;
};

// 插件描述
struct PluginDescriptor {
    std::string id;
    std::string version;
    std::vector<Dependency> dependencies;
};

// ==========================================
// 依赖解析器
// ==========================================

class DependencyResolver {
private:
    std::map<std::string, PluginDescriptor> plugins_;

public:
    void addPlugin(PluginDescriptor desc) {
        plugins_[desc.id] = std::move(desc);
    }

    // 拓扑排序——确定加载顺序
    // 返回从依赖到依赖者的顺序（先加载被依赖的）
    std::vector<std::string> resolveOrder() const {
        // 构建有向图
        std::map<std::string, std::set<std::string>> graph;
        std::map<std::string, int> inDegree;

        for (const auto& [id, plugin] : plugins_) {
            if (!graph.count(id)) {
                graph[id] = {};
                inDegree[id] = 0;
            }

            for (const auto& dep : plugin.dependencies) {
                if (dep.optional && !plugins_.count(dep.id)) continue;

                if (!plugins_.count(dep.id)) {
                    throw std::runtime_error(
                        "Missing dependency: " + dep.id +
                        " required by " + id);
                }

                // dep.id → id（dep必须先加载）
                graph[dep.id].insert(id);
                inDegree[id]++;
            }
        }

        // Kahn's算法——BFS拓扑排序
        std::queue<std::string> queue;
        for (const auto& [id, degree] : inDegree) {
            if (degree == 0) queue.push(id);
        }

        std::vector<std::string> result;
        while (!queue.empty()) {
            auto current = queue.front();
            queue.pop();
            result.push_back(current);

            for (const auto& next : graph[current]) {
                if (--inDegree[next] == 0) {
                    queue.push(next);
                }
            }
        }

        // 检测循环依赖
        if (result.size() != plugins_.size()) {
            // 找出参与循环的插件
            std::vector<std::string> cycle;
            for (const auto& [id, degree] : inDegree) {
                if (degree > 0) cycle.push_back(id);
            }

            std::string cycleStr;
            for (const auto& id : cycle) {
                if (!cycleStr.empty()) cycleStr += " -> ";
                cycleStr += id;
            }

            throw std::runtime_error(
                "Circular dependency detected: " + cycleStr);
        }

        return result;
    }

    // 检查所有依赖约束是否满足
    std::vector<std::string> checkConstraints() const {
        std::vector<std::string> errors;

        for (const auto& [id, plugin] : plugins_) {
            for (const auto& dep : plugin.dependencies) {
                if (dep.optional && !plugins_.count(dep.id)) continue;

                auto it = plugins_.find(dep.id);
                if (it == plugins_.end()) {
                    errors.push_back(
                        id + " requires " + dep.id +
                        " but it's not installed");
                    continue;
                }

                // 检查版本约束
                // 这里简化处理——实际应使用semver::VersionConstraint
                // auto constraint = semver::VersionConstraint::parse(dep.versionConstraint);
                // auto version = semver::Version::parse(it->second.version);
                // if (!constraint.satisfiedBy(version)) {
                //     errors.push_back(id + " requires " + dep.id + " " +
                //         dep.versionConstraint + " but got " +
                //         it->second.version);
                // }
            }
        }

        return errors;
    }
};

} // namespace dependency_resolver
```

```
依赖解析示例：

插件关系图：
┌─────────┐     ┌─────────┐
│ App Core│     │ Logger  │
│  v1.0   │     │  v2.0   │
└────┬────┘     └────┬────┘
     │               │
     ▼               │
┌─────────┐          │
│  Auth   ├──────────┘ (依赖Logger ^2.0)
│  v1.5   │
└────┬────┘
     │
     ▼
┌─────────┐
│Database │
│  v3.0   │
└─────────┘

拓扑排序结果（加载顺序）：
  1. Logger v2.0      ← 无依赖，先加载
  2. Database v3.0    ← 无依赖
  3. Auth v1.5        ← 依赖Logger和Database
  4. App Core v1.0    ← 依赖Auth

钻石依赖问题：
         ┌──────────┐
         │ App Core │
         └──┬───┬───┘
            │   │
     ┌──────┘   └──────┐
     ▼                  ▼
┌─────────┐       ┌─────────┐
│  Auth   │       │  Cache  │
│需要Util │       │需要Util │
│  ^1.2   │       │  ^1.5   │
└────┬────┘       └────┬────┘
     │                  │
     └──────┬───────────┘
            ▼
     ┌─────────────┐
     │   Util      │
     │  选哪个版本？│
     │  1.2? 1.5?  │
     └─────────────┘

解决方案：选择满足所有约束的最高版本
  ^1.2 + ^1.5 → 需要 >=1.5, <2.0 → 选1.5.x
```

---

#### 3.6 向后兼容性工程实践

```cpp
// ==========================================
// API演进策略——如何安全地修改插件API
// ==========================================
//
// 插件API一旦发布就很难修改——因为外部插件已经在使用了。
// 但需求总在变化，API必须演进。关键是如何安全地演进。
//
// 黄金法则：
//   1. 只添加，不删除（添加新函数/参数）
//   2. 只放宽，不收紧（放宽前置条件，收紧后置条件）
//   3. 给充分的过渡期（deprecated→migration→removal）
//
// ==========================================
// API演进生命周期
// ==========================================
//
// Phase 1: 引入新API（保留旧API）
//   v2.0: 添加newMethod()
//         oldMethod() 标记为deprecated
//
// Phase 2: 过渡期（至少一个大版本周期）
//   v2.x: 旧API仍然可用，但编译时会有warning
//         文档提供迁移指南
//
// Phase 3: 移除旧API（大版本升级时）
//   v3.0: 移除oldMethod()
//         只保留newMethod()

#include <iostream>
#include <string>
#include <functional>
#include <map>
#include <vector>
#include <optional>

namespace api_evolution {

// ==========================================
// Deprecation标记（编译期警告）
// ==========================================

#if defined(__GNUC__) || defined(__clang__)
    #define PLUGIN_DEPRECATED(msg) __attribute__((deprecated(msg)))
    #define PLUGIN_DEPRECATED_SINCE(ver, msg) \
        __attribute__((deprecated("Since " ver ": " msg)))
#elif defined(_MSC_VER)
    #define PLUGIN_DEPRECATED(msg) __declspec(deprecated(msg))
    #define PLUGIN_DEPRECATED_SINCE(ver, msg) \
        __declspec(deprecated("Since " ver ": " msg))
#else
    #define PLUGIN_DEPRECATED(msg)
    #define PLUGIN_DEPRECATED_SINCE(ver, msg)
#endif

// ==========================================
// 版本化的插件API示例
// ==========================================

class IPluginHostV1 {
public:
    virtual ~IPluginHostV1() = default;

    // V1 API
    virtual void log(const std::string& message) = 0;
    virtual void registerCommand(const std::string& name,
        std::function<void()> handler) = 0;
};

class IPluginHostV2 : public IPluginHostV1 {
public:
    // V1的log已过时，用logEx替代
    PLUGIN_DEPRECATED_SINCE("2.0", "Use logEx() instead")
    void log(const std::string& message) override = 0;

    // V2新增：带级别的日志
    virtual void logEx(const std::string& level,
                      const std::string& message,
                      const std::string& source = "") = 0;

    // V2新增：带返回值的命令注册
    virtual bool registerCommandEx(
        const std::string& name,
        const std::string& title,
        std::function<void()> handler,
        std::optional<std::string> keybinding = std::nullopt) = 0;
};

// ==========================================
// 适配器模式：桥接新旧API
// ==========================================
//
// 当宿主升级到V2 API时，旧插件（使用V1 API编写）
// 可以通过适配器无缝工作

class V1ToV2Adapter : public IPluginHostV2 {
private:
    IPluginHostV2& host_;

public:
    explicit V1ToV2Adapter(IPluginHostV2& host) : host_(host) {}

    // V1的log → 转发到V2的logEx
    void log(const std::string& message) override {
        host_.logEx("INFO", message, "legacy-plugin");
    }

    // V2方法直接转发
    void logEx(const std::string& level,
              const std::string& message,
              const std::string& source) override {
        host_.logEx(level, message, source);
    }

    bool registerCommandEx(
        const std::string& name,
        const std::string& title,
        std::function<void()> handler,
        std::optional<std::string> keybinding) override {
        return host_.registerCommandEx(name, title,
            std::move(handler), keybinding);
    }

    // V1的registerCommand → 转发到V2的registerCommandEx
    void registerCommand(const std::string& name,
        std::function<void()> handler) override {
        host_.registerCommandEx(name, name, std::move(handler));
    }
};

// ==========================================
// 特性检测（Feature Detection）
// ==========================================
//
// 让插件在运行时检查宿主是否支持某个特性
// 比接口版本号更灵活——因为特性可以独立添加/删除

class FeatureRegistry {
private:
    std::map<std::string, std::string> features_;

public:
    void registerFeature(const std::string& name,
                        const std::string& version) {
        features_[name] = version;
    }

    bool hasFeature(const std::string& name) const {
        return features_.count(name) > 0;
    }

    std::optional<std::string> getFeatureVersion(
        const std::string& name) const {
        auto it = features_.find(name);
        return it != features_.end()
            ? std::optional(it->second) : std::nullopt;
    }
};

// 使用示例
void pluginCode(FeatureRegistry& features) {
    if (features.hasFeature("async_commands")) {
        // 使用异步命令特性
    } else {
        // 回退到同步模式
    }
}

} // namespace api_evolution
```

---

#### 3.7 插件迁移与升级策略

```cpp
// ==========================================
// 插件数据迁移框架
// ==========================================
//
// 当插件升级时，其存储的配置和数据格式可能发生变化。
// 需要一个迁移框架来自动升级旧数据。
//
// 设计原则：
//   1. 每个版本变更对应一个迁移函数
//   2. 迁移函数按版本顺序依次执行
//   3. 迁移前自动备份
//   4. 迁移失败时回滚
//
// 例如：从v1.0升级到v3.0
//   1.0→1.1: 添加新配置字段，填默认值
//   1.1→2.0: 重命名配置键，转换格式
//   2.0→3.0: 合并两个配置项为一个

#include <string>
#include <map>
#include <vector>
#include <functional>
#include <any>
#include <iostream>
#include <optional>

namespace migration {

// 配置数据（简化版）
using ConfigData = std::map<std::string, std::any>;

// 迁移函数：接受旧配置，返回新配置
using MigrationFunc = std::function<ConfigData(const ConfigData&)>;

struct MigrationStep {
    std::string fromVersion;
    std::string toVersion;
    std::string description;
    MigrationFunc migrate;
};

class DataMigrator {
private:
    std::vector<MigrationStep> steps_;

public:
    // 注册迁移步骤
    void addStep(MigrationStep step) {
        steps_.push_back(std::move(step));
    }

    // 从当前版本迁移到目标版本
    ConfigData migrate(const ConfigData& data,
                      const std::string& fromVersion,
                      const std::string& toVersion) {
        // 找到需要执行的迁移路径
        auto path = findMigrationPath(fromVersion, toVersion);

        ConfigData current = data;

        for (const auto& step : path) {
            std::cout << "Migrating: " << step.fromVersion
                      << " -> " << step.toVersion
                      << " (" << step.description << ")"
                      << std::endl;

            try {
                current = step.migrate(current);
            } catch (const std::exception& e) {
                std::cerr << "Migration failed at "
                          << step.fromVersion << " -> "
                          << step.toVersion << ": "
                          << e.what() << std::endl;
                throw;
            }
        }

        return current;
    }

private:
    std::vector<MigrationStep> findMigrationPath(
        const std::string& from, const std::string& to) const {
        std::vector<MigrationStep> path;
        std::string current = from;

        while (current != to) {
            bool found = false;
            for (const auto& step : steps_) {
                if (step.fromVersion == current) {
                    path.push_back(step);
                    current = step.toVersion;
                    found = true;
                    break;
                }
            }
            if (!found) {
                throw std::runtime_error(
                    "No migration path from " + current + " to " + to);
            }
        }

        return path;
    }
};

// ==========================================
// 使用示例
// ==========================================

void demonstrateMigration() {
    DataMigrator migrator;

    // 注册迁移步骤
    migrator.addStep({
        "1.0", "1.1", "Add theme setting",
        [](const ConfigData& data) {
            ConfigData newData = data;
            if (!newData.count("theme")) {
                newData["theme"] = std::string("default");
            }
            return newData;
        }
    });

    migrator.addStep({
        "1.1", "2.0", "Rename 'color' to 'primaryColor'",
        [](const ConfigData& data) {
            ConfigData newData = data;
            if (newData.count("color")) {
                newData["primaryColor"] = newData["color"];
                newData.erase("color");
            }
            return newData;
        }
    });

    // 从1.0迁移到2.0
    ConfigData oldConfig = {
        {"color", std::string("blue")},
        {"fontSize", 14}
    };

    auto newConfig = migrator.migrate(oldConfig, "1.0", "2.0");
    // 结果: {primaryColor: "blue", fontSize: 14, theme: "default"}
}

} // namespace migration
```

---

#### 3.8 本周练习任务

```cpp
// ==========================================
// 第三周练习任务
// ==========================================

/*
练习1：完整的SemVer解析器
--------------------------------------
目标：实现符合semver.org规范的版本解析和比较

要求：
1. 实现Version类（参考3.1节），支持：
   - 完整的MAJOR.MINOR.PATCH解析
   - 预发布标识解析（alpha.1, beta.2, rc.1）
   - 构建元数据解析（+build.123）
   - 所有比较运算符
2. 实现VersionConstraint类，支持以下约束类型：
   - ^1.2.3 (caret)
   - ~1.2.3 (tilde)
   - >=, <=, >, <, = (比较)
   - * (任意版本)
3. 实现组合约束（如 ">=1.0.0 <2.0.0"）
4. 编写全面的单元测试（至少30个测试用例）

验证：
- 所有semver.org官方测试用例通过
- ^0.x.y的特殊处理正确
- 预发布版本比较正确（1.0.0-alpha < 1.0.0-beta < 1.0.0）
- 构建元数据不影响比较结果
*/

/*
练习2：ABI兼容性检测器
--------------------------------------
目标：理解C++ ABI破坏的具体场景

要求：
1. 创建一个共享库（libwidget.so v1），导出一个Widget类
2. 编写使用该库的客户端程序
3. 修改Widget类（模拟V2），做以下5种变更，逐一测试：
   a. 添加虚函数到中间位置
   b. 添加成员变量
   c. 改变继承结构
   d. 改变虚函数签名（参数类型）
   e. 改变成员变量类型（int→long）
4. 每种变更后，不重编译客户端，直接替换.so运行
5. 记录每种情况下的实际表现（崩溃/错误输出/正常）
6. 使用objdump/nm工具分析两个版本的差异

验证：
- 每种ABI破坏都能复现
- 能解释每种破坏的根本原因
- 撰写500字报告总结ABI安全变更清单
*/

/*
练习3：PIMPL模式重构
--------------------------------------
目标：掌握PIMPL模式的完整实现

要求：
1. 从一个普通的Widget类开始（有5+个成员变量和方法）
2. 将其重构为PIMPL模式（参考3.3节）
3. 确保支持拷贝构造、拷贝赋值、移动构造、移动赋值
4. 编写基准测试对比重构前后的性能差异：
   - 对象创建/销毁时间
   - 方法调用时间
   - 成员访问时间
5. 验证ABI稳定性：修改Impl添加新成员后，
   旧的客户端程序不重编译能正常运行

验证：
- 五法则（Rule of Five）全部正确实现
- 性能差异在可接受范围内（<10%对大多数操作）
- ABI稳定性验证通过
*/

/*
练习4：依赖解析器
--------------------------------------
目标：实现完整的插件依赖解析

要求：
1. 实现DependencyResolver（参考3.5节），支持：
   - 拓扑排序确定加载顺序
   - 循环依赖检测（报告具体的循环链）
   - 版本约束检查（使用练习1的SemVer实现）
   - 可选依赖处理
2. 设计以下测试场景：
   - 线性依赖链：A→B→C→D
   - 钻石依赖：A→B→D, A→C→D（版本兼容）
   - 钻石依赖（版本冲突）：B要D^1.0, C要D^2.0
   - 循环依赖：A→B→C→A
   - 可选依赖缺失
3. 输出美观的依赖树（类似npm ls）

验证：
- 所有测试场景正确处理
- 循环依赖有清晰的错误信息
- 版本冲突有具体的冲突描述
- 可选依赖缺失时不报错
*/
```

---

#### 3.9 本周知识检验

```
思考题1：为什么C++没有稳定的ABI？
其他语言（如C、Java、C#）是如何解决ABI问题的？
C++的ABI不稳定是设计缺陷还是有意为之？
提示：考虑C++的设计哲学（零开销抽象）、
模板实例化、内联函数、异常实现差异。
对比C的简单ABI、Java的字节码抽象、C#的元数据。

思考题2：PIMPL模式有性能开销（堆分配+间接寻址），
在什么场景下这个开销不可接受？
有哪些替代方案可以部分地提供ABI稳定性？
提示：考虑高频创建/销毁的小对象、实时系统约束。
替代方案：固定大小缓冲区（SBO）、C接口+不透明句柄、
虚函数接口（纯虚类）。

思考题3：npm允许同一个包存在多个版本（嵌套node_modules），
这在C++共享库环境中是否可行？
如果一个进程同时加载了libfoo.so v1和v2会发生什么？
提示：考虑全局符号冲突、C++静态变量的唯一性保证、
RTLD_LOCAL的隔离效果和局限性。

思考题4：COM的QueryInterface模式和C++的dynamic_cast
有什么本质区别？为什么跨DLL边界不推荐用dynamic_cast？
提示：考虑RTTI的实现（typeinfo对象的唯一性问题）、
不同编译器的RTTI格式差异、COM的二进制标准。

思考题5：一个插件框架承诺"向后兼容"——
新版本的宿主程序能运行旧版本的插件。
如果同时还要"向前兼容"——旧宿主能运行新插件——
难度会增加多少？这在实践中可行吗？
提示：考虑特性检测 vs 版本检测、graceful degradation、
新插件调用旧宿主不存在的API时如何处理。

实践题1：设计一个ABI兼容性检查工具
要求：
- 接受两个版本的.so文件作为输入
- 比较并报告以下差异：
  1. 导出符号的增删
  2. 函数签名变化
  3. 类sizeof变化（如果可检测）
- 参考Linux的abi-compliance-checker工具的输出格式
- 画出工具的架构图

实践题2：设计一个插件市场的版本策略
背景：你维护一个有200个第三方插件的平台
问题：
- 每次宿主API升级（breaking change），如何通知插件开发者？
- 如何设计过渡期？多长合适？
- 如何处理不再维护的插件？
- 如何避免"破窗效应"——一旦开始频繁breaking change，
  生态系统信心下降的恶性循环？
```

---

### 第四周：安全隔离与沙箱

**学习目标**：
- [ ] 理解插件系统的安全威胁模型（恶意插件、供应链攻击、权限提升）
- [ ] 掌握进程隔离插件架构的设计与实现
- [ ] 了解Linux沙箱技术栈（namespaces/seccomp-bpf/capabilities）
- [ ] 理解WebAssembly作为插件沙箱的优势与实践
- [ ] 掌握资源限制与配额管理（cgroups、看门狗）
- [ ] 了解插件签名与验证的完整流程
- [ ] 学会设计基于能力的权限声明系统

**阅读材料**：
- [ ] Chromium沙箱设计文档
- [ ] WebAssembly安全模型（WASI规范）
- [ ] Java SecurityManager架构
- [ ] Linux namespaces/cgroups文档
- [ ] Flatpak/Snap沙箱设计
- [ ] 《The Tangled Web》- 浏览器安全模型参考
- [ ] seccomp-bpf内核文档

#### 核心概念

**插件隔离策略**
```
安全级别从低到高：

Level 0: 无隔离（同进程）
┌─────────────────────────────────┐
│         主进程                   │
│  ┌────────┐ ┌────────┐         │
│  │Plugin A│ │Plugin B│  共享内存│
│  └────────┘ └────────┘         │
└─────────────────────────────────┘

Level 1: 线程隔离
┌─────────────────────────────────┐
│         主进程                   │
│  Thread 1    Thread 2           │
│  ┌────────┐ ┌────────┐         │
│  │Plugin A│ │Plugin B│ 独立栈   │
│  └────────┘ └────────┘         │
└─────────────────────────────────┘

Level 2: 进程隔离
┌──────────────┐  IPC  ┌──────────────┐
│   主进程     │◄────►│ 插件进程      │
│              │       │ ┌──────────┐ │
│              │       │ │ Plugin A │ │
│              │       │ └──────────┘ │
└──────────────┘       └──────────────┘

Level 3: 沙箱进程
┌──────────────┐       ┌──────────────┐
│   主进程     │       │ 沙箱进程      │
│              │  IPC  │ ┌──────────┐ │
│              │◄────►│ │ Plugin   │ │
│              │       │ │ 受限权限  │ │
│              │       │ └──────────┘ │
└──────────────┘       └──────────────┘
                       • 无文件系统访问
                       • 无网络访问
                       • 受限内存
```

---

#### 4.1 插件安全威胁模型

```cpp
// ==========================================
// 插件系统的安全威胁分析
// ==========================================
//
// 插件系统的最大安全风险在于：
// 你在自己的进程中运行不受信任的第三方代码。
//
// ==========================================
// 威胁模型（Threat Model）
// ==========================================
//
// 攻击者类型：
//
// 1. 恶意插件开发者
//    - 直接在插件中嵌入恶意代码
//    - 窃取用户数据、安装后门、加密勒索
//    - 案例：VS Code恶意扩展事件
//
// 2. 供应链攻击
//    - 攻击插件的依赖库，间接注入恶意代码
//    - 案例：npm event-stream事件（注入加密货币窃取代码）
//    - 案例：PyPI恶意包（typosquatting）
//
// 3. 漏洞利用
//    - 插件中的无意bug被攻击者利用
//    - 缓冲区溢出、格式化字符串、注入漏洞
//    - 攻击者通过向插件提供恶意输入来触发
//
// 4. 权限提升
//    - 插件利用宿主提供的API做超出权限的事
//    - 通过读取其他插件的数据突破隔离
//    - 利用宿主的bug获得额外权限
//
// ==========================================
// 攻击面（Attack Surface）
// ==========================================
//
// 同进程插件的攻击面：
//   ┌─────────────────────────────────────┐
//   │              主进程                  │
//   │                                     │
//   │  ┌─────────┐    ┌─────────┐        │
//   │  │ 宿主    │    │ 恶意    │        │
//   │  │ 代码    │    │ 插件    │        │
//   │  └─────────┘    └────┬────┘        │
//   │                      │              │
//   │  攻击面：             │              │
//   │  ├─ 读写任意内存 ◄────┤              │
//   │  ├─ 调用任何函数 ◄────┤              │
//   │  ├─ 访问文件系统 ◄────┤              │
//   │  ├─ 网络通信     ◄────┤              │
//   │  ├─ 执行系统命令 ◄────┘              │
//   │  └─ 读取环境变量和凭据               │
//   └─────────────────────────────────────┘
//
// 进程隔离后的攻击面（大幅缩减）：
//   ┌──────────┐  受控IPC  ┌──────────┐
//   │ 宿主进程  │◄────────►│ 沙箱进程  │
//   │          │           │ ┌──────┐ │
//   │          │  攻击面：  │ │ 插件 │ │
//   │          │  仅IPC    │ └──────┘ │
//   │          │  协议     │          │
//   └──────────┘           └──────────┘
//                           无直接内存访问
//                           无文件系统
//                           无网络

#include <string>
#include <vector>
#include <map>
#include <iostream>

namespace security_model {

// ==========================================
// 权限声明模型
// ==========================================
//
// 每个插件在manifest中声明需要的权限
// 宿主在加载时检查权限，可以拒绝或提示用户

enum class Permission {
    FileRead,        // 读取文件
    FileWrite,       // 写入文件
    NetworkAccess,   // 网络访问
    ProcessSpawn,    // 创建子进程
    ClipboardRead,   // 读取剪贴板
    ClipboardWrite,  // 写入剪贴板
    ShellExecute,    // 执行shell命令
    EnvironmentRead, // 读取环境变量
    KeychainAccess,  // 访问密钥链
};

struct PermissionRequest {
    Permission permission;
    std::string reason;       // 为什么需要此权限
    bool required = true;     // 是否必须（false=可选）
};

struct SecurityPolicy {
    // 白名单：明确允许的权限
    std::vector<Permission> allowed;
    // 黑名单：明确禁止的权限
    std::vector<Permission> denied;
    // 需要用户确认的权限
    std::vector<Permission> askUser;
    // 最大资源限制
    size_t maxMemoryMB = 256;
    uint32_t maxCPUPercent = 50;
    uint32_t maxFileDescriptors = 64;
    bool networkAllowed = false;
};

// 权限检查器
class PermissionChecker {
private:
    SecurityPolicy policy_;
    std::map<std::string, std::vector<Permission>> grantedPermissions_;

public:
    explicit PermissionChecker(SecurityPolicy policy)
        : policy_(std::move(policy)) {}

    // 检查插件的权限请求
    bool checkPermissions(
        const std::string& pluginId,
        const std::vector<PermissionRequest>& requests) {

        for (const auto& req : requests) {
            // 检查黑名单
            if (isDenied(req.permission)) {
                if (req.required) {
                    std::cerr << "Plugin " << pluginId
                              << " requires denied permission"
                              << std::endl;
                    return false;
                }
                continue;
            }

            // 检查白名单
            if (isAllowed(req.permission)) {
                grantedPermissions_[pluginId].push_back(req.permission);
                continue;
            }

            // 需要用户确认
            // 实际实现中这里会弹出对话框
            std::cout << "Plugin '" << pluginId
                      << "' requests permission: "
                      << req.reason << std::endl;
        }

        return true;
    }

    // 运行时权限检查
    bool hasPermission(const std::string& pluginId,
                      Permission perm) const {
        auto it = grantedPermissions_.find(pluginId);
        if (it == grantedPermissions_.end()) return false;

        return std::find(it->second.begin(), it->second.end(), perm)
               != it->second.end();
    }

private:
    bool isDenied(Permission perm) const {
        return std::find(policy_.denied.begin(),
                        policy_.denied.end(), perm)
               != policy_.denied.end();
    }

    bool isAllowed(Permission perm) const {
        return std::find(policy_.allowed.begin(),
                        policy_.allowed.end(), perm)
               != policy_.allowed.end();
    }
};

} // namespace security_model
```

---

#### 4.2 进程隔离插件架构

```cpp
// ==========================================
// 进程隔离的插件架构设计
// ==========================================
//
// 进程隔离是安全性最高的插件隔离方式。
// 核心思想：每个插件（或每组插件）运行在独立进程中，
// 与宿主通过IPC通信。
//
// Chrome的多进程架构是最经典的参考：
//   Browser Process → 主进程（管理一切）
//   Renderer Process → 每个Tab一个（沙箱化）
//   GPU Process → GPU操作隔离
//   Plugin Process → Flash等NPAPI插件
//
// 进程隔离的好处：
//   1. 插件崩溃不影响宿主（故障隔离）
//   2. 可以用OS级别的沙箱限制插件权限
//   3. 资源限制（cgroups/Job Objects）
//   4. 强制的内存隔离（不同地址空间）
//
// 代价：
//   1. IPC开销（延迟增加1-10μs/次调用）
//   2. 内存占用增加（每个进程有自己的运行时）
//   3. 开发复杂度增加（需要序列化/反序列化）
//   4. 调试困难（跨进程调试）

#include <string>
#include <vector>
#include <map>
#include <functional>
#include <memory>
#include <iostream>
#include <any>
#include <future>

#ifndef _WIN32
#include <unistd.h>
#include <sys/socket.h>
#include <sys/wait.h>
#endif

namespace process_isolation {

// ==========================================
// 进程间通信协议设计
// ==========================================
//
// 宿主和插件进程之间需要一个通信协议。
// 常见选择：
//   - Unix Domain Socket（推荐，双向、可靠）
//   - 管道（简单，但单向）
//   - 共享内存（高性能，但需要同步）
//   - JSON-RPC over stdio（VSCode的选择，跨平台）

// 简化的消息协议
struct IPCMessage {
    uint32_t id;          // 请求ID（用于匹配响应）
    uint32_t type;        // 消息类型
    std::string method;   // 方法名
    std::string payload;  // JSON序列化的参数/结果
    bool isResponse;      // 是请求还是响应
};

// 消息类型
enum class MessageType : uint32_t {
    // 生命周期
    Initialize = 1,
    Activate = 2,
    Deactivate = 3,
    Shutdown = 4,

    // 功能调用
    CallFunction = 10,
    CallResponse = 11,
    CallError = 12,

    // 事件
    Event = 20,
    Subscribe = 21,
    Unsubscribe = 22,

    // 心跳
    Ping = 30,
    Pong = 31,
};

// ==========================================
// 插件宿主端（Host Side）
// ==========================================

class PluginHostProcess {
private:
    std::string pluginId_;
    pid_t childPid_ = -1;
    int socketFd_ = -1;
    uint32_t nextRequestId_ = 0;
    std::map<uint32_t, std::promise<std::string>> pendingRequests_;

public:
    explicit PluginHostProcess(std::string pluginId)
        : pluginId_(std::move(pluginId)) {}

    ~PluginHostProcess() {
        shutdown();
    }

    // 启动插件进程
    bool start(const std::string& pluginPath) {
#ifndef _WIN32
        // 创建socketpair用于通信
        int socks[2];
        if (socketpair(AF_UNIX, SOCK_STREAM, 0, socks) < 0) {
            return false;
        }

        childPid_ = fork();
        if (childPid_ < 0) {
            close(socks[0]);
            close(socks[1]);
            return false;
        }

        if (childPid_ == 0) {
            // 子进程（插件侧）
            close(socks[0]);

            // 将socket fd重定向到特定的fd号
            dup2(socks[1], 3);  // fd 3 用于IPC
            close(socks[1]);

            // 执行插件host进程
            // 实际应使用execvp，这里简化
            execl("./plugin_host", "plugin_host",
                  pluginPath.c_str(), nullptr);
            _exit(1);  // exec失败
        }

        // 父进程（宿主侧）
        close(socks[1]);
        socketFd_ = socks[0];

        std::cout << "Plugin process started: " << pluginId_
                  << " (pid=" << childPid_ << ")" << std::endl;
        return true;
#else
        return false;  // Windows实现使用CreateProcess
#endif
    }

    // 向插件发送RPC调用
    std::future<std::string> callFunction(
        const std::string& method,
        const std::string& params) {

        uint32_t requestId = ++nextRequestId_;

        IPCMessage msg;
        msg.id = requestId;
        msg.type = static_cast<uint32_t>(MessageType::CallFunction);
        msg.method = method;
        msg.payload = params;
        msg.isResponse = false;

        auto promise = std::promise<std::string>();
        auto future = promise.get_future();
        pendingRequests_[requestId] = std::move(promise);

        // 发送消息（简化，实际需要序列化）
        sendMessage(msg);

        return future;
    }

    // 关闭插件进程
    void shutdown() {
#ifndef _WIN32
        if (childPid_ > 0) {
            // 先发送优雅关闭消息
            IPCMessage shutdownMsg;
            shutdownMsg.type = static_cast<uint32_t>(MessageType::Shutdown);
            sendMessage(shutdownMsg);

            // 等待子进程退出（带超时）
            int status;
            // 简化实现——实际应使用select/epoll超时等待
            waitpid(childPid_, &status, 0);

            close(socketFd_);
            childPid_ = -1;
            socketFd_ = -1;
        }
#endif
    }

    bool isAlive() const {
#ifndef _WIN32
        if (childPid_ <= 0) return false;
        return kill(childPid_, 0) == 0;
#else
        return false;
#endif
    }

private:
    void sendMessage(const IPCMessage& msg) {
        // 简化实现——实际需要消息帧协议
        // (长度前缀 + 序列化数据)
    }
};

} // namespace process_isolation
```

```
进程隔离的插件架构总览：

┌──────────────────────────────────────────────────────┐
│                    宿主进程 (Host)                     │
│                                                      │
│  ┌──────────────┐  ┌────────────┐  ┌──────────────┐ │
│  │ Plugin       │  │ IPC Router │  │ Permission   │ │
│  │ Manager      │  │            │  │ Checker      │ │
│  └──────┬───────┘  └─────┬──────┘  └──────────────┘ │
│         │                │                           │
└─────────┼────────────────┼───────────────────────────┘
          │                │
    ┌─────┼──────────┬─────┼──────────┐
    │     │          │     │          │
    ▼     ▼          ▼     ▼          ▼
┌──────────┐    ┌──────────┐    ┌──────────┐
│ 插件进程A │    │ 插件进程B │    │ 插件进程C │
│┌────────┐│    │┌────────┐│    │┌────────┐│
││Plugin A││    ││Plugin B││    ││Plugin C││
│└────────┘│    │└────────┘│    │└────────┘│
│          │    │          │    │          │
│ 沙箱限制：│    │ 沙箱限制：│    │ 沙箱限制：│
│ - no net │    │ - net ok │    │ - no fs  │
│ - 256MB  │    │ - 512MB  │    │ - 128MB  │
│ - no fs  │    │ - ro fs  │    │ - no net │
└──────────┘    └──────────┘    └──────────┘

IPC调用时序：
宿主进程                    插件进程
    │  CallFunction("draw") │
    │──────────────────────►│
    │                       │ 执行draw()
    │  CallResponse(result) │
    │◄──────────────────────│
    │                       │
    │  Event("file.saved")  │
    │──────────────────────►│
    │                       │ 处理事件
```

---

#### 4.3 Linux沙箱技术栈

```cpp
// ==========================================
// Linux沙箱技术概览
// ==========================================
//
// Linux提供了多层沙箱技术，可以组合使用来限制插件进程：
//
// ┌────────────────────────────────────────────┐
// │  Layer 4: AppArmor / SELinux               │
// │  → 强制访问控制（MAC）                      │
// ├────────────────────────────────────────────┤
// │  Layer 3: seccomp-bpf                      │
// │  → 系统调用过滤                             │
// ├────────────────────────────────────────────┤
// │  Layer 2: Linux Capabilities               │
// │  → 细粒度权限控制（替代全有/全无的root）     │
// ├────────────────────────────────────────────┤
// │  Layer 1: Linux Namespaces                 │
// │  → 资源隔离（PID/NET/MNT/USER/UTS/IPC）    │
// ├────────────────────────────────────────────┤
// │  Layer 0: cgroups v2                       │
// │  → 资源限制（CPU/内存/IO/进程数）            │
// └────────────────────────────────────────────┘
//
// ==========================================
// Namespaces——创建隔离的世界
// ==========================================
//
// 每种namespace隔离一种系统资源：
//
// PID namespace:
//   插件进程看到的PID从1开始
//   看不到宿主的其他进程
//
// Mount namespace:
//   插件有自己的文件系统视图
//   可以限制只看到特定目录
//
// Network namespace:
//   插件有自己的网络栈
//   默认无网络访问（没有任何网络接口）
//
// User namespace:
//   插件内部可以是"root"但外部无特权
//   （无需真正的root权限就能创建沙箱）
//
// ==========================================
// seccomp-bpf——系统调用过滤器
// ==========================================
//
// seccomp-bpf允许精确控制进程可以使用哪些系统调用
// BPF（Berkeley Packet Filter）程序在内核中运行
// 每次系统调用时检查是否被允许
//
// 典型的插件沙箱策略：
//   允许: read, write, mmap, brk, exit_group, futex, clock_gettime
//   禁止: execve, fork, socket, mount, ptrace, setuid
//   有条件允许: open(只读), ioctl(特定设备)

#include <iostream>
#include <string>
#include <vector>

#ifdef __linux__
#include <sys/prctl.h>
#include <linux/seccomp.h>
#include <linux/filter.h>
#include <linux/audit.h>
#include <sys/syscall.h>
#include <sched.h>
#include <unistd.h>
#endif

namespace linux_sandbox {

// ==========================================
// 沙箱配置
// ==========================================

struct SandboxConfig {
    // Namespace隔离
    bool isolatePID = true;        // PID命名空间
    bool isolateNetwork = true;    // 网络命名空间
    bool isolateMount = true;      // 挂载命名空间
    bool isolateUser = true;       // 用户命名空间
    bool isolateIPC = true;        // IPC命名空间

    // 文件系统
    std::string rootfs;            // chroot路径
    std::vector<std::string> readOnlyBinds;   // 只读绑定挂载
    std::vector<std::string> readWriteBinds;  // 可读写绑定挂载

    // seccomp
    bool enableSeccomp = true;
    std::vector<int> allowedSyscalls;  // 白名单系统调用

    // 资源限制
    size_t memoryLimitBytes = 256 * 1024 * 1024;  // 256MB
    int cpuPercent = 50;           // CPU占比
    int maxProcesses = 10;         // 最大进程数
    int maxFileDescriptors = 64;   // 最大文件描述符
};

// ==========================================
// 沙箱创建器（简化版）
// ==========================================
//
// 实际实现需要处理大量细节：
// - 用户映射（uid_map/gid_map）
// - 挂载点设置（/proc, /dev等）
// - 信号处理
// - 错误恢复

class SandboxCreator {
public:
    static bool createSandboxedProcess(
        const SandboxConfig& config,
        const std::string& programPath,
        const std::vector<std::string>& args) {

#ifdef __linux__
        // 计算clone flags
        int cloneFlags = SIGCHLD;

        if (config.isolatePID)     cloneFlags |= CLONE_NEWPID;
        if (config.isolateNetwork) cloneFlags |= CLONE_NEWNET;
        if (config.isolateMount)   cloneFlags |= CLONE_NEWNS;
        if (config.isolateUser)    cloneFlags |= CLONE_NEWUSER;
        if (config.isolateIPC)     cloneFlags |= CLONE_NEWIPC;

        // clone创建子进程（指定namespace隔离）
        // 注意：实际实现应使用clone3()系统调用
        pid_t pid = fork();  // 简化，实际用clone

        if (pid == 0) {
            // 子进程——在沙箱中
            setupSandbox(config);

            // 执行插件程序
            execl(programPath.c_str(), programPath.c_str(), nullptr);
            _exit(1);
        }

        if (pid > 0) {
            std::cout << "Sandboxed process created: pid=" << pid << std::endl;
            return true;
        }
#endif
        return false;
    }

private:
    static void setupSandbox(const SandboxConfig& config) {
#ifdef __linux__
        // 1. 设置seccomp过滤器
        if (config.enableSeccomp) {
            setupSeccomp(config.allowedSyscalls);
        }

        // 2. 设置资源限制（通过写入cgroup文件系统）
        // 实际实现需要创建cgroup并将进程加入

        // 3. 限制文件描述符数量
        // setrlimit(RLIMIT_NOFILE, ...)

        // 4. 设置no_new_privs（防止权限提升）
        prctl(PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0);
#endif
    }

    static void setupSeccomp(const std::vector<int>& allowedSyscalls) {
        // seccomp-bpf过滤器设置
        // 这里是简化版——实际需要构建BPF程序
        //
        // 基本思路：
        // 1. 默认动作：SECCOMP_RET_KILL（拒绝并终止）
        // 2. 对每个白名单系统调用：SECCOMP_RET_ALLOW
        //
        // 示例BPF伪代码：
        //   if (syscall_nr == __NR_read) ALLOW
        //   if (syscall_nr == __NR_write) ALLOW
        //   if (syscall_nr == __NR_exit_group) ALLOW
        //   ...
        //   default: KILL
    }
};

} // namespace linux_sandbox
```

---

#### 4.4 WebAssembly插件沙箱

```cpp
// ==========================================
// WebAssembly作为插件沙箱
// ==========================================
//
// WebAssembly（Wasm）最初为浏览器设计，
// 但其沙箱特性使它成为插件隔离的绝佳选择。
//
// 为什么Wasm适合做插件沙箱？
//
// 1. 内存安全
//    Wasm模块只能访问自己的线性内存
//    不能读写宿主进程的任何内存
//    越界访问会被运行时捕获（不是段错误，是可恢复的trap）
//
// 2. 确定性执行
//    没有未定义行为
//    相同输入总是产生相同输出
//
// 3. 能力模型
//    Wasm模块默认没有任何系统访问能力
//    所有能力（文件、网络、时间等）必须由宿主显式授予
//    通过WASI接口标准化
//
// 4. 跨语言支持
//    C/C++/Rust/Go/Python等都可以编译为Wasm
//    插件开发者不限于特定语言
//
// 5. 接近原生性能
//    通过JIT/AOT编译，性能可达原生代码的70-90%
//
// ==========================================
// WASI (WebAssembly System Interface)
// ==========================================
//
// WASI是Wasm访问系统资源的标准化接口。
// 宿主实现WASI接口，可以对每个能力进行精确控制。
//
// WASI提供的能力（宿主按需授权）：
//   fd_read/fd_write    → 文件操作（限定目录）
//   sock_accept/send    → 网络操作
//   clock_time_get      → 获取时间
//   random_get           → 随机数
//   environ_get         → 环境变量
//   proc_exit           → 退出进程
//
// 关键：宿主完全控制每个WASI调用的行为
// 例如：fd_read可以只允许读取特定目录下的文件

#include <string>
#include <vector>
#include <map>
#include <functional>
#include <memory>
#include <iostream>
#include <optional>

namespace wasm_sandbox {

// ==========================================
// Wasm插件运行时接口（概念模型）
// ==========================================
//
// 这是一个概念实现，展示Wasm插件系统的核心设计
// 实际应使用wasmtime、wasmer或wasm3等运行时

// 插件能力声明
enum class WasmCapability {
    FileRead,        // 读取文件
    FileWrite,       // 写入文件
    NetworkClient,   // 发起网络连接
    NetworkServer,   // 监听网络端口
    Time,            // 获取系统时间
    Random,          // 随机数生成
    Environment,     // 读取环境变量
};

struct WasmPluginConfig {
    std::string wasmPath;     // .wasm文件路径
    std::string pluginId;
    // 授予的能力
    std::vector<WasmCapability> capabilities;
    // 文件系统映射（虚拟路径 → 真实路径）
    std::map<std::string, std::string> fsMap;
    // 资源限制
    size_t maxMemoryPages = 256;  // 每页64KB，256页=16MB
    uint64_t fuelLimit = 1000000; // 指令执行燃料（防止死循环）
};

// ==========================================
// Wasm插件宿主
// ==========================================

class WasmPluginHost {
private:
    WasmPluginConfig config_;
    // 实际实现中这里是wasmtime::Store, Module, Instance等

public:
    explicit WasmPluginHost(WasmPluginConfig config)
        : config_(std::move(config)) {}

    // 加载并实例化Wasm模块
    bool load() {
        std::cout << "Loading Wasm plugin: " << config_.wasmPath << std::endl;

        // 1. 读取.wasm文件
        // 2. 编译为机器码（JIT或AOT）
        // 3. 创建实例（分配线性内存）
        // 4. 链接WASI导入函数（只提供已授权的能力）

        // 关键：如果插件试图使用未授权的能力，
        // WASI导入函数会返回错误而不是崩溃

        return true;
    }

    // 调用插件导出的函数
    std::optional<int32_t> callFunction(
        const std::string& name,
        const std::vector<int32_t>& args) {

        std::cout << "Calling Wasm function: " << name << std::endl;

        // 1. 查找导出函数
        // 2. 类型检查参数
        // 3. 设置执行燃料限制（防止死循环）
        // 4. 执行函数
        // 5. 如果燃料耗尽，自动中断执行

        return 0;  // 简化返回
    }

    // 检查插件是否有特定能力
    bool hasCapability(WasmCapability cap) const {
        return std::find(config_.capabilities.begin(),
                        config_.capabilities.end(), cap)
               != config_.capabilities.end();
    }
};

} // namespace wasm_sandbox
```

```
Wasm插件 vs 原生插件的安全对比：

                   原生插件(.so)         Wasm插件(.wasm)
─────────────────────────────────────────────────────────
内存访问         任意读写宿主内存      只能访问自己的线性内存
系统调用         直接调用任何syscall    只能通过WASI接口
文件系统         完全访问              只能访问映射的目录
网络             完全访问              需要显式授权
代码执行         可以fork/exec          不能创建进程
崩溃影响         可能崩溃整个宿主       陷入trap，宿主可恢复
死循环           无法检测              燃料机制自动中断
性能             100%原生              70-90%原生
语言限制         通常C/C++             任何可编译到Wasm的语言
调试             gdb/lldb              浏览器DevTools/wasm-gdb
分发大小         平台特定              平台无关（一次编译）

推荐选择：
┌──────────────────────────────┐
│ 安全性优先 → Wasm            │
│ 性能优先   → 进程隔离原生插件 │
│ 简单优先   → 同进程原生插件   │
└──────────────────────────────┘

Wasm在以下场景特别合适：
- 运行不受信任的第三方插件
- 需要跨平台分发的插件
- 需要细粒度资源控制的场景
```

---

#### 4.5 资源限制与配额管理

```cpp
// ==========================================
// 插件资源限制
// ==========================================
//
// 即使插件不是恶意的，也可能因为bug消耗过多资源：
//   - 内存泄漏导致OOM
//   - 死循环消耗100% CPU
//   - 打开过多文件描述符
//   - 创建过多线程
//
// 资源限制机制确保单个插件不能拖垮整个系统。
//
// Linux提供两种机制：
//   1. rlimit（per-process资源限制）
//   2. cgroups v2（per-group资源限制，更灵活）

#include <string>
#include <chrono>
#include <functional>
#include <thread>
#include <atomic>
#include <iostream>
#include <map>
#include <mutex>

namespace resource_limits {

// ==========================================
// 资源配额
// ==========================================

struct ResourceQuota {
    size_t maxMemoryBytes = 256 * 1024 * 1024;  // 256MB
    uint32_t maxCPUPercent = 50;                 // 50% CPU
    uint32_t maxThreads = 16;                    // 16个线程
    uint32_t maxFileDescriptors = 64;            // 64个fd
    size_t maxDiskWriteBytes = 100 * 1024 * 1024; // 100MB写入
    std::chrono::seconds maxExecutionTime{300};   // 5分钟超时
};

// 资源使用报告
struct ResourceUsage {
    size_t currentMemoryBytes = 0;
    double cpuPercent = 0.0;
    uint32_t threadCount = 0;
    uint32_t fdCount = 0;
    size_t diskWriteBytes = 0;
    std::chrono::steady_clock::time_point startTime;
};

// ==========================================
// 看门狗（Watchdog）
// ==========================================
//
// 看门狗定期检查插件的资源使用情况
// 超过限额时采取措施（警告→限流→终止）

class PluginWatchdog {
public:
    enum class Action {
        None,
        Warn,      // 发出警告
        Throttle,  // 限流（降低优先级）
        Terminate  // 终止插件
    };

    using ActionCallback = std::function<void(
        const std::string& pluginId, Action action,
        const std::string& reason)>;

private:
    struct WatchedPlugin {
        std::string pluginId;
        ResourceQuota quota;
        std::function<ResourceUsage()> getUsage;
        int warningCount = 0;
    };

    std::map<std::string, WatchedPlugin> plugins_;
    std::mutex mutex_;
    std::atomic<bool> running_{false};
    std::thread watchThread_;
    ActionCallback actionCallback_;

    std::chrono::milliseconds checkInterval_{1000};

public:
    void setActionCallback(ActionCallback cb) {
        actionCallback_ = std::move(cb);
    }

    void watch(const std::string& pluginId,
              ResourceQuota quota,
              std::function<ResourceUsage()> getUsage) {
        std::lock_guard<std::mutex> lock(mutex_);
        plugins_[pluginId] = {
            pluginId, std::move(quota),
            std::move(getUsage), 0
        };
    }

    void unwatch(const std::string& pluginId) {
        std::lock_guard<std::mutex> lock(mutex_);
        plugins_.erase(pluginId);
    }

    void start() {
        running_ = true;
        watchThread_ = std::thread([this] { watchLoop(); });
    }

    void stop() {
        running_ = false;
        if (watchThread_.joinable()) {
            watchThread_.join();
        }
    }

private:
    void watchLoop() {
        while (running_) {
            std::this_thread::sleep_for(checkInterval_);
            checkAll();
        }
    }

    void checkAll() {
        std::lock_guard<std::mutex> lock(mutex_);

        for (auto& [id, plugin] : plugins_) {
            auto usage = plugin.getUsage();
            auto action = evaluate(plugin, usage);

            if (action != Action::None && actionCallback_) {
                std::string reason = buildReason(plugin, usage);
                actionCallback_(id, action, reason);
            }
        }
    }

    Action evaluate(WatchedPlugin& plugin,
                   const ResourceUsage& usage) {
        const auto& quota = plugin.quota;

        // 内存超限
        if (usage.currentMemoryBytes > quota.maxMemoryBytes) {
            plugin.warningCount++;
            if (plugin.warningCount > 3) return Action::Terminate;
            return Action::Warn;
        }

        // CPU超限
        if (usage.cpuPercent > quota.maxCPUPercent * 1.5) {
            return Action::Throttle;
        }

        // 执行超时
        auto elapsed = std::chrono::steady_clock::now() - usage.startTime;
        if (elapsed > quota.maxExecutionTime) {
            return Action::Terminate;
        }

        plugin.warningCount = 0;  // 重置警告计数
        return Action::None;
    }

    std::string buildReason(const WatchedPlugin& plugin,
                           const ResourceUsage& usage) {
        // 构建人类可读的原因描述
        return "Resource limit exceeded for " + plugin.pluginId;
    }
};

} // namespace resource_limits
```

---

#### 4.6 插件签名与验证

```cpp
// ==========================================
// 插件代码签名与验证
// ==========================================
//
// 代码签名确保：
//   1. 完整性（Integrity）——插件未被篡改
//   2. 来源认证（Authentication）——确认是特定开发者发布的
//   3. 不可否认（Non-repudiation）——开发者不能否认发布过这个插件
//
// 签名流程：
//   开发者:
//   1. 用SHA-256计算插件文件的哈希值
//   2. 用自己的私钥对哈希值签名
//   3. 将签名附加到插件包中（或放在manifest里）
//
//   宿主（验证时）:
//   1. 用SHA-256重新计算插件文件的哈希值
//   2. 用开发者的公钥验证签名
//   3. 对比哈希值确认文件完整
//
// 信任链模型：
//   ┌──────────────────┐
//   │  平台CA根证书     │ ← 平台方持有
//   └────────┬─────────┘
//            │ 签发
//            ▼
//   ┌──────────────────┐
//   │ 开发者证书       │ ← 通过身份验证获取
//   └────────┬─────────┘
//            │ 签名
//            ▼
//   ┌──────────────────┐
//   │ 插件签名         │ ← 附加在插件包中
//   └──────────────────┘

#include <string>
#include <vector>
#include <cstdint>
#include <optional>
#include <iostream>
#include <fstream>
#include <functional>
#include <map>

namespace plugin_signing {

// 签名信息
struct SignatureInfo {
    std::string algorithm;       // "SHA256withRSA"
    std::string signerName;      // 签名者
    std::string certificateId;   // 证书ID
    std::vector<uint8_t> signature;  // 签名数据
    std::vector<uint8_t> fileHash;   // 文件哈希
    std::string timestamp;       // 签名时间
};

// 证书信息
struct Certificate {
    std::string id;
    std::string subject;         // 持有者
    std::string issuer;          // 颁发者
    std::string notBefore;       // 有效期开始
    std::string notAfter;        // 有效期结束
    std::vector<uint8_t> publicKey;
    bool isRevoked = false;
};

// ==========================================
// 签名验证器
// ==========================================

class SignatureVerifier {
private:
    // 信任的CA证书
    std::map<std::string, Certificate> trustedCAs_;
    // 开发者证书缓存
    std::map<std::string, Certificate> developerCerts_;
    // 已撤销的证书列表(CRL)
    std::vector<std::string> revokedCerts_;

public:
    // 添加信任的CA证书
    void addTrustedCA(Certificate cert) {
        trustedCerts_[cert.id] = std::move(cert);
    }

    // 验证插件签名
    enum class VerifyResult {
        Valid,              // 签名有效
        InvalidSignature,   // 签名数据错误
        ExpiredCertificate, // 证书过期
        RevokedCertificate, // 证书已吊销
        UntrustedSigner,    // 签名者不受信任
        FileModified,       // 文件被篡改
        NoSignature         // 没有签名
    };

    VerifyResult verify(const std::string& pluginPath,
                       const SignatureInfo& signature) {
        // Step 1: 计算文件哈希
        auto fileHash = computeHash(pluginPath);
        if (!fileHash) return VerifyResult::FileModified;

        // Step 2: 对比哈希
        if (*fileHash != signature.fileHash) {
            std::cerr << "File hash mismatch - file may be tampered"
                      << std::endl;
            return VerifyResult::FileModified;
        }

        // Step 3: 查找签名者证书
        auto certIt = developerCerts_.find(signature.certificateId);
        if (certIt == developerCerts_.end()) {
            return VerifyResult::UntrustedSigner;
        }

        // Step 4: 验证证书链
        const auto& cert = certIt->second;
        if (cert.isRevoked) return VerifyResult::RevokedCertificate;

        // 检查是否在撤销列表中
        if (std::find(revokedCerts_.begin(), revokedCerts_.end(),
                     cert.id) != revokedCerts_.end()) {
            return VerifyResult::RevokedCertificate;
        }

        // Step 5: 验证签名
        // 实际使用OpenSSL/libsodium等库进行密码学验证
        // RSA_verify(hash, signature, publicKey)

        return VerifyResult::Valid;
    }

private:
    std::map<std::string, Certificate> trustedCerts_;

    std::optional<std::vector<uint8_t>> computeHash(
        const std::string& path) {
        // 使用SHA-256计算文件哈希
        // 实际实现使用OpenSSL: SHA256_Init/Update/Final
        return std::vector<uint8_t>(32, 0);  // 简化
    }
};

} // namespace plugin_signing
```

---

#### 4.7 权限声明与运行时检查

```cpp
// ==========================================
// 基于能力的权限系统
// ==========================================
//
// 借鉴Android的权限模型和Capability-based Security，
// 设计一个适合插件系统的权限框架。
//
// 设计原则：
//   1. 声明式——插件在manifest中声明需要的权限
//   2. 最小权限——只授予必要的权限
//   3. 运行时检查——每次敏感操作都检查权限
//   4. 用户可控——用户可以审查和修改权限
//   5. 可撤回——权限可以在运行时被撤回
//
// ==========================================
// 与Android权限模型的对比
// ==========================================
//
// Android:
//   <uses-permission android:name="android.permission.INTERNET" />
//   → 安装时声明，运行时部分需要动态请求（Android 6.0+）
//
// 我们的设计:
//   manifest.json: "permissions": ["fs:read", "network:client"]
//   → 加载时声明，宿主根据策略自动授权或提示用户

#include <string>
#include <vector>
#include <map>
#include <set>
#include <functional>
#include <optional>
#include <mutex>
#include <iostream>

namespace capability_system {

// ==========================================
// 权限定义
// ==========================================
//
// 权限使用层级命名：
//   domain:action:scope
//
// 示例：
//   "fs:read:*"          全文件系统读
//   "fs:read:/tmp"       只读/tmp目录
//   "fs:write:/data"     只写/data目录
//   "network:client:*"   任意网络连接
//   "network:client:443" 只连443端口
//   "process:spawn"      创建子进程
//   "clipboard:read"     读剪贴板
//   "clipboard:write"    写剪贴板

struct PermissionDescriptor {
    std::string domain;     // fs, network, process, clipboard...
    std::string action;     // read, write, spawn, client...
    std::string scope;      // 具体范围（路径、端口等），*表示全部
    std::string reason;     // 为什么需要此权限

    std::string toString() const {
        return domain + ":" + action +
               (scope.empty() ? "" : ":" + scope);
    }
};

// ==========================================
// 权限管理器
// ==========================================

class CapabilityManager {
public:
    enum class Decision {
        Allow,      // 允许
        Deny,       // 拒绝
        Ask         // 需要用户确认
    };

    using UserPrompt = std::function<bool(
        const std::string& pluginId,
        const PermissionDescriptor& perm)>;

private:
    // 插件已授权的权限
    std::map<std::string, std::set<std::string>> grants_;
    // 安全策略
    std::map<std::string, Decision> policyRules_;
    // 用户确认回调
    UserPrompt userPrompt_;
    mutable std::mutex mutex_;

public:
    void setUserPrompt(UserPrompt prompt) {
        userPrompt_ = std::move(prompt);
    }

    // 设置策略规则
    void setPolicy(const std::string& permString, Decision decision) {
        policyRules_[permString] = decision;
    }

    // 授予权限
    void grant(const std::string& pluginId,
              const PermissionDescriptor& perm) {
        std::lock_guard<std::mutex> lock(mutex_);
        grants_[pluginId].insert(perm.toString());
    }

    // 撤回权限
    void revoke(const std::string& pluginId,
               const PermissionDescriptor& perm) {
        std::lock_guard<std::mutex> lock(mutex_);
        grants_[pluginId].erase(perm.toString());
    }

    // 运行时权限检查
    bool check(const std::string& pluginId,
              const PermissionDescriptor& perm) {
        std::lock_guard<std::mutex> lock(mutex_);

        std::string permStr = perm.toString();

        // 1. 检查已授予的权限
        auto it = grants_.find(pluginId);
        if (it != grants_.end()) {
            // 精确匹配
            if (it->second.count(permStr)) return true;
            // 通配符匹配
            std::string wildcardPerm = perm.domain + ":" +
                                       perm.action + ":*";
            if (it->second.count(wildcardPerm)) return true;
        }

        // 2. 检查策略
        auto policyIt = policyRules_.find(permStr);
        if (policyIt != policyRules_.end()) {
            switch (policyIt->second) {
                case Decision::Allow:
                    grants_[pluginId].insert(permStr);
                    return true;
                case Decision::Deny:
                    return false;
                case Decision::Ask:
                    break;  // 继续到用户确认
            }
        }

        // 3. 询问用户
        if (userPrompt_) {
            bool allowed = userPrompt_(pluginId, perm);
            if (allowed) {
                grants_[pluginId].insert(permStr);
            }
            return allowed;
        }

        // 默认拒绝
        return false;
    }

    // 列出插件的所有权限
    std::vector<std::string> listPermissions(
        const std::string& pluginId) const {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = grants_.find(pluginId);
        if (it == grants_.end()) return {};

        return {it->second.begin(), it->second.end()};
    }
};

// ==========================================
// 使用示例：受权限保护的API
// ==========================================

class ProtectedFileSystem {
private:
    CapabilityManager& capabilities_;

public:
    explicit ProtectedFileSystem(CapabilityManager& cap)
        : capabilities_(cap) {}

    // 每个操作前都检查权限
    std::optional<std::string> readFile(
        const std::string& pluginId,
        const std::string& path) {

        PermissionDescriptor perm{"fs", "read", path,
            "Read file: " + path};

        if (!capabilities_.check(pluginId, perm)) {
            std::cerr << "Permission denied: " << pluginId
                      << " cannot read " << path << std::endl;
            return std::nullopt;
        }

        // 执行实际的文件读取
        return "file contents";
    }

    bool writeFile(const std::string& pluginId,
                  const std::string& path,
                  const std::string& content) {

        PermissionDescriptor perm{"fs", "write", path,
            "Write file: " + path};

        if (!capabilities_.check(pluginId, perm)) {
            std::cerr << "Permission denied: " << pluginId
                      << " cannot write " << path << std::endl;
            return false;
        }

        // 执行实际的文件写入
        return true;
    }
};

} // namespace capability_system
```

---

#### 4.8 本周练习任务

```cpp
// ==========================================
// 第四周练习任务
// ==========================================

/*
练习1：实现权限声明系统
--------------------------------------
目标：掌握基于能力的安全模型

要求：
1. 实现CapabilityManager（参考4.7节），支持：
   - 权限声明（domain:action:scope格式）
   - 策略规则（允许/拒绝/询问）
   - 通配符匹配（fs:read:* 匹配 fs:read:/any/path）
   - 权限授予和撤回
2. 实现ProtectedFileSystem，对每次文件操作做权限检查
3. 编写3个模拟插件，声明不同权限：
   - PluginA: fs:read:*, network:client:*（功能强大）
   - PluginB: fs:read:/data, clipboard:read（受限）
   - PluginC: 无任何权限（纯计算插件）
4. 设计用户确认界面（命令行模拟即可）
5. 测试权限撤回后插件的行为

验证：
- 权限正确匹配（通配符、精确匹配）
- 未授权操作被正确拒绝
- 撤回权限后立即生效
- 用户确认流程正确工作
*/

/*
练习2：实现插件资源看门狗
--------------------------------------
目标：掌握资源监控与限制

要求：
1. 实现PluginWatchdog（参考4.5节），支持：
   - 定期（1秒间隔）检查插件的资源使用
   - 内存限额、CPU限额、执行时间限额
   - 三级响应：警告→限流→终止
2. 编写一个"恶意"测试插件，分别模拟：
   - 内存泄漏（每秒分配10MB不释放）
   - CPU死循环（while(true)）
   - 打开大量文件描述符
3. 验证看门狗能在限额时间内检测并响应
4. 记录看门狗的响应时间和准确性

验证：
- 内存泄漏在超限后3秒内被检测
- CPU死循环在超限后被限流
- 执行超时后插件被终止
- 正常插件不受看门狗影响
*/

/*
练习3：进程隔离插件原型
--------------------------------------
目标：实现基于进程隔离的插件通信

要求：
1. 实现一个简单的双进程插件系统：
   - 宿主进程：加载和管理插件
   - 插件进程：运行插件代码
2. 使用Unix Domain Socket或socketpair进行通信
3. 设计简单的RPC协议（JSON-RPC格式）
4. 实现以下RPC方法：
   - initialize(config) → bool
   - callFunction(name, args) → result
   - shutdown() → void
5. 处理插件进程崩溃的情况（SIGCHLD处理）
6. 实现心跳机制检测插件进程存活

验证：
- 基本RPC调用正确
- 插件进程崩溃后宿主能检测到
- 心跳超时后正确标记插件为不可用
- 可以重启崩溃的插件进程
*/

/*
练习4：安全审计实验
--------------------------------------
目标：理解插件安全的实际挑战

要求：
1. 创建一个"诚实"插件和一个"恶意"插件
2. "恶意"插件尝试以下攻击（在同进程环境下）：
   a. 读取宿主进程的内存（通过指针运算）
   b. 修改其他插件的数据
   c. 读取环境变量中的密钥
   d. 访问宿主不希望暴露的文件
3. 记录每种攻击的成功/失败情况
4. 然后切换到进程隔离模式，重试所有攻击
5. 对比两种模式下的安全性差异
6. 撰写安全分析报告

验证：
- 同进程模式下至少3种攻击成功
- 进程隔离模式下所有攻击被阻止
- 报告详细分析了每种攻击的原理和防御方案
- 包含对实际插件系统的安全建议
*/
```

---

#### 4.9 本周知识检验

```
思考题1：为什么Chrome选择了进程隔离模型而不是Wasm沙箱？
Chrome的Site Isolation给每个网站一个进程，
这个决策背后的安全考量是什么？
提示：考虑Spectre/Meltdown侧信道攻击、
共享内存的时序攻击、以及Wasm规范中
SharedArrayBuffer带来的安全挑战。

思考题2：Linux的namespace隔离和VM（虚拟机）隔离
有什么本质区别？namespace隔离能提供和VM一样的安全性吗？
提示：考虑内核漏洞的影响范围、
container escape攻击案例、
gVisor/Firecracker等混合方案。

思考题3：插件签名可以防止恶意代码吗？
如果一个插件通过了签名验证，是否意味着它是安全的？
提示：考虑签名只证明"来源"不证明"意图"、
供应链攻击（合法开发者被攻击）、
签名密钥泄露的影响。

思考题4：基于能力（Capability）的安全模型
相比传统的ACL（Access Control List）有什么优势？
在插件系统中为什么更适合？
提示：考虑最小权限原则、
ambient authority问题、
能力传递的可控性。

思考题5：实现一个"不能作恶"的插件系统可能吗？
如果插件可以执行任意图灵完备的计算，
理论上是否总能找到绕过限制的方法？
提示：考虑停机问题的限制、
covert channel（隐蔽通道）、
timing side channel、
以及信息论视角。

实践题1：设计一个插件市场的安全审核流程
要求：
- 自动化审核：静态分析检查（危险API调用、已知漏洞）
- 权限审核：检查权限声明是否合理（读文件的插件不应该要网络权限）
- 人工审核：什么条件触发人工审核？审核什么内容？
- 签名发布：从开发者提交到用户安装的完整信任链
- 应急响应：发现恶意插件后如何快速响应？
画出完整的审核流程图

实践题2：评估以下三种隔离方案的安全性和性能
场景：一个代码编辑器需要支持第三方语法高亮插件
方案A：同进程dlopen + 符号可见性控制
方案B：子进程 + Unix Socket IPC
方案C：WebAssembly沙箱
评估维度：
- 安全性（满分10分）
- 性能影响（语法高亮延迟）
- 开发复杂度
- 插件开发者体验
- 跨平台兼容性
用表格呈现对比结果，并给出推荐方案
```

---

## 源码阅读任务

### 必读项目

1. **LLVM Plugin系统** (https://github.com/llvm/llvm-project)
   - 重点文件：`llvm/include/llvm/Pass.h`, `llvm/lib/Passes/`
   - 切入路径：
     - `llvm/include/llvm/Pass.h` — Pass基类定义，理解插件注册宏
     - `llvm/lib/Passes/PassBuilder.cpp` — Pass管道构建，理解插件发现与组装
     - `llvm/include/llvm/PassRegistry.h` — 全局注册表，理解工厂模式应用
     - `llvm/lib/Support/DynamicLibrary.cpp` — LLVM自身的跨平台dlopen封装
   - 关注点：`RegisterPass<>` 宏如何实现静态自注册、PassManager如何调度Pass链
   - 学习目标：理解编译器插件架构
   - 阅读时间：10小时

2. **Qt插件系统** (https://github.com/qt/qtbase)
   - 重点文件：`src/corelib/plugin/`
   - 切入路径：
     - `src/corelib/plugin/qlibrary.cpp` — 跨平台动态库加载核心实现
     - `src/corelib/plugin/qpluginloader.cpp` — 高层插件加载API
     - `src/corelib/plugin/qfactoryloader.cpp` — 插件工厂发现机制
     - `src/corelib/kernel/qmetaobject.cpp` — MOC元对象系统（插件接口基础）
   - 关注点：`Q_PLUGIN_METADATA` 宏如何嵌入JSON元数据、QPluginLoader的lazy loading策略
   - 学习目标：理解跨平台插件加载
   - 阅读时间：8小时

3. **Neovim插件系统** (https://github.com/neovim/neovim)
   - 重点文件：
     - `src/nvim/msgpack_rpc/channel.c` — RPC通道管理，进程间通信核心
     - `src/nvim/api/` — API定义目录，理解插件可调用的接口层
     - `src/nvim/lua/executor.c` — Lua插件执行器，理解嵌入式语言插件
     - `runtime/autoload/remote/host.vim` — 远程插件宿主发现机制
   - 关注点：msgpack-rpc协议如何实现跨进程双向通信、插件宿主进程的生命周期管理
   - 学习目标：理解进程隔离插件
   - 阅读时间：6小时

### 阅读笔记模板
```markdown
## 源码阅读笔记

### 项目名称：
### 阅读日期：
### 重点模块：

#### 架构概览
- 核心组件：
- 依赖关系：
- 插件发现机制：
- 插件加载流程：

#### 关键实现细节
1. 插件注册方式（静态/动态/声明式）：
2. 接口定义与版本管理：
3. 跨平台适配策略：

#### 设计亮点
- 值得借鉴的设计模式：
- 性能优化技巧：

#### 可改进之处
- 发现的局限性或技术债务：

#### 应用到自己项目的想法
- 可迁移到实践项目的具体技术：
```

---

## 实践项目：跨平台插件框架

### 项目概述
构建一个功能完整的跨平台插件框架，支持动态加载、版本管理、热更新和安全隔离。

### 完整代码实现

#### 1. 跨平台动态库加载器 (plugin/loader/dynamic_library.hpp)

```cpp
// ============================================================================
// DynamicLibrary — 跨平台动态库加载器
// ============================================================================
//
// 【在系统中的角色】
//   插件框架的最底层基础设施。所有上层组件（PluginManager、热重载等）
//   都通过此类与操作系统的动态链接器交互。
//
// 【设计决策】
//   - 使用 RAII 封装库句柄，确保 unload 不会被遗漏（关联：第一周 1.3 dlopen API）
//   - 条件编译隔离平台差异（Win32 LoadLibrary vs POSIX dlopen），上层代码无需感知
//   - getSymbol 返回 void*，由调用者 reinterpret_cast 为具体函数指针
//     （这是动态加载的固有约束，参见第一周 1.4 符号可见性）
//   - 移动语义确保句柄所有权唯一，避免 double-free
//
// 【与理论学习的关联】
//   第一周 1.1（ELF格式）→ 理解 handle 背后的 link_map 结构
//   第一周 1.3（dlopen API）→ 本文件是对原始 C API 的 C++ RAII 封装
//   第一周 1.7（库搜索路径）→ load() 传入的路径如何被动态链接器解析
// ============================================================================

#pragma once

#include <string>
#include <stdexcept>
#include <filesystem>

#ifdef _WIN32
    #define WIN32_LEAN_AND_MEAN
    #include <windows.h>
    using LibraryHandle = HMODULE;
#else
    #include <dlfcn.h>
    using LibraryHandle = void*;
#endif

namespace plugin {

class DynamicLibraryError : public std::runtime_error {
public:
    using std::runtime_error::runtime_error;
};

class DynamicLibrary {
private:
    LibraryHandle handle_{nullptr};
    std::filesystem::path path_;

    static std::string getLastError() {
#ifdef _WIN32
        DWORD error = GetLastError();
        if (error == 0) return "";

        LPSTR buffer = nullptr;
        size_t size = FormatMessageA(
            FORMAT_MESSAGE_ALLOCATE_BUFFER |
            FORMAT_MESSAGE_FROM_SYSTEM |
            FORMAT_MESSAGE_IGNORE_INSERTS,
            NULL, error,
            MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
            (LPSTR)&buffer, 0, NULL
        );

        std::string message(buffer, size);
        LocalFree(buffer);
        return message;
#else
        const char* error = dlerror();
        return error ? error : "";
#endif
    }

public:
    DynamicLibrary() = default;

    explicit DynamicLibrary(const std::filesystem::path& path) {
        load(path);
    }

    ~DynamicLibrary() {
        unload();
    }

    // 禁止拷贝
    DynamicLibrary(const DynamicLibrary&) = delete;
    DynamicLibrary& operator=(const DynamicLibrary&) = delete;

    // 允许移动
    DynamicLibrary(DynamicLibrary&& other) noexcept
        : handle_(other.handle_), path_(std::move(other.path_)) {
        other.handle_ = nullptr;
    }

    DynamicLibrary& operator=(DynamicLibrary&& other) noexcept {
        if (this != &other) {
            unload();
            handle_ = other.handle_;
            path_ = std::move(other.path_);
            other.handle_ = nullptr;
        }
        return *this;
    }

    void load(const std::filesystem::path& path) {
        if (handle_) {
            throw DynamicLibraryError("Library already loaded");
        }

        path_ = path;

#ifdef _WIN32
        handle_ = LoadLibraryW(path.wstring().c_str());
#else
        handle_ = dlopen(path.c_str(), RTLD_NOW | RTLD_LOCAL);
#endif

        if (!handle_) {
            throw DynamicLibraryError(
                "Failed to load library: " + path.string() +
                " - " + getLastError()
            );
        }
    }

    void unload() {
        if (handle_) {
#ifdef _WIN32
            FreeLibrary(handle_);
#else
            dlclose(handle_);
#endif
            handle_ = nullptr;
        }
    }

    template<typename T>
    T getSymbol(const std::string& name) const {
        if (!handle_) {
            throw DynamicLibraryError("Library not loaded");
        }

#ifdef _WIN32
        void* symbol = reinterpret_cast<void*>(
            GetProcAddress(handle_, name.c_str())
        );
#else
        void* symbol = dlsym(handle_, name.c_str());
#endif

        if (!symbol) {
            throw DynamicLibraryError(
                "Symbol not found: " + name + " - " + getLastError()
            );
        }

        return reinterpret_cast<T>(symbol);
    }

    template<typename T>
    std::optional<T> tryGetSymbol(const std::string& name) const noexcept {
        try {
            return getSymbol<T>(name);
        } catch (...) {
            return std::nullopt;
        }
    }

    bool isLoaded() const { return handle_ != nullptr; }
    const std::filesystem::path& getPath() const { return path_; }
};

// 获取平台特定的库文件扩展名
inline std::string getLibraryExtension() {
#ifdef _WIN32
    return ".dll";
#elif defined(__APPLE__)
    return ".dylib";
#else
    return ".so";
#endif
}

// 获取平台特定的库文件前缀
inline std::string getLibraryPrefix() {
#ifdef _WIN32
    return "";
#else
    return "lib";
#endif
}

} // namespace plugin
```

#### 2. 插件接口定义 (plugin/core/plugin_interface.hpp)

```cpp
// ============================================================================
// IPlugin / PluginInfo — 插件接口与元数据定义
// ============================================================================
//
// 【在系统中的角色】
//   插件系统的"契约层"。所有插件必须实现 IPlugin 接口，主程序通过此接口
//   与插件交互，而不依赖任何具体实现。这是整个框架解耦的核心。
//
// 【设计决策】
//   - 纯虚接口 + extern "C" 工厂函数 = C++ 多态 + C ABI 稳定性
//     （关联：第三周 3.2 ABI稳定性 — vtable 布局只要接口不变就保持兼容）
//   - PluginInfo 使用 POD-like 结构，便于跨动态库边界传递
//   - IMPLEMENT_PLUGIN 宏封装工厂函数导出，避免插件开发者手写 extern "C"
//   - 生命周期方法（initialize/shutdown）对应第二周 2.5 的状态机模型
//   - PLUGIN_EXPORT 宏处理符号可见性（关联：第一周 1.4 符号可见性控制）
//
// 【与理论学习的关联】
//   第一周 1.4（符号可见性）→ PLUGIN_EXPORT 宏的 __attribute__((visibility("default")))
//   第二周 2.1（插件架构模式）→ 接口隔离是微内核模式的核心特征
//   第三周 3.4（COM风格版本管理）→ 可扩展为 QueryInterface 多版本接口
// ============================================================================

#pragma once

#include <string>
#include <vector>
#include <memory>
#include <any>
#include <functional>
#include <optional>

namespace plugin {

// 版本结构
struct Version {
    uint32_t major = 0;
    uint32_t minor = 0;
    uint32_t patch = 0;
    std::string prerelease;

    std::string toString() const {
        std::string result = std::to_string(major) + "." +
                            std::to_string(minor) + "." +
                            std::to_string(patch);
        if (!prerelease.empty()) {
            result += "-" + prerelease;
        }
        return result;
    }

    static Version parse(const std::string& str) {
        Version v;
        std::sscanf(str.c_str(), "%u.%u.%u", &v.major, &v.minor, &v.patch);
        auto pos = str.find('-');
        if (pos != std::string::npos) {
            v.prerelease = str.substr(pos + 1);
        }
        return v;
    }

    bool operator<(const Version& other) const {
        if (major != other.major) return major < other.major;
        if (minor != other.minor) return minor < other.minor;
        if (patch != other.patch) return patch < other.patch;
        if (prerelease.empty() && !other.prerelease.empty()) return false;
        if (!prerelease.empty() && other.prerelease.empty()) return true;
        return prerelease < other.prerelease;
    }

    bool operator==(const Version& other) const {
        return major == other.major && minor == other.minor &&
               patch == other.patch && prerelease == other.prerelease;
    }

    bool operator<=(const Version& other) const {
        return *this < other || *this == other;
    }

    bool isCompatibleWith(const Version& required) const {
        // 主版本必须匹配，次版本必须>=
        return major == required.major &&
               (minor > required.minor ||
                (minor == required.minor && patch >= required.patch));
    }
};

// 依赖描述
struct Dependency {
    std::string id;
    Version minVersion;
    Version maxVersion;
    bool optional = false;
};

// 插件元数据
struct PluginMetadata {
    std::string id;
    std::string name;
    Version version;
    Version apiVersion;
    std::string description;
    std::string author;
    std::string license;
    std::vector<Dependency> dependencies;
    std::vector<std::string> providedExtensions;
};

// 前向声明
class IPluginContext;

// 插件接口 - 所有插件必须实现
class IPlugin {
public:
    virtual ~IPlugin() = default;

    // 获取插件元数据
    virtual const PluginMetadata& getMetadata() const = 0;

    // 生命周期方法
    virtual bool initialize(IPluginContext* context) = 0;
    virtual bool activate() = 0;
    virtual bool deactivate() = 0;
    virtual void dispose() = 0;

    // 配置
    virtual bool configure(const std::any& config) = 0;

    // 健康检查
    virtual bool isHealthy() const = 0;
};

// 插件上下文 - 提供给插件的宿主服务
class IPluginContext {
public:
    virtual ~IPluginContext() = default;

    // 日志
    virtual void log(const std::string& level, const std::string& message) = 0;

    // 获取其他插件
    virtual IPlugin* getPlugin(const std::string& id) = 0;

    // 扩展点注册
    virtual void registerExtension(const std::string& extensionPoint,
                                   const std::string& id,
                                   std::any extension) = 0;

    // 获取扩展
    virtual std::vector<std::any> getExtensions(
        const std::string& extensionPoint) = 0;

    // 事件发布
    virtual void publishEvent(const std::string& event,
                             const std::any& data) = 0;

    // 事件订阅
    virtual uint64_t subscribeEvent(const std::string& event,
        std::function<void(const std::any&)> handler) = 0;

    virtual void unsubscribeEvent(uint64_t subscriptionId) = 0;

    // 配置访问
    virtual std::optional<std::any> getConfig(const std::string& key) = 0;
};

// 插件工厂函数类型
using PluginFactory = IPlugin* (*)();
using PluginDestroyer = void (*)(IPlugin*);

// 插件导出宏
#define DECLARE_PLUGIN(PluginClass) \
    extern "C" { \
        PLUGIN_EXPORT ::plugin::IPlugin* createPlugin() { \
            return new PluginClass(); \
        } \
        PLUGIN_EXPORT void destroyPlugin(::plugin::IPlugin* plugin) { \
            delete plugin; \
        } \
        PLUGIN_EXPORT const char* getPluginApiVersion() { \
            return "2.0.0"; \
        } \
    }

} // namespace plugin
```

#### 3. 插件管理器 (plugin/core/plugin_manager.hpp)

```cpp
// ============================================================================
// PluginManager — 插件生命周期与加载管理器
// ============================================================================
//
// 【在系统中的角色】
//   框架的核心控制器。负责插件的发现、加载、初始化、卸载全流程，
//   并提供热重载和文件系统监控能力。是 DynamicLibrary 和 IPlugin 的协调者。
//
// 【设计决策】
//   - 内部 PluginEntry 聚合 DynamicLibrary + IPlugin* + PluginInfo，
//     将"物理加载"与"逻辑插件"绑定管理（关联：第二周 2.5 生命周期状态机）
//   - discoverPlugins 采用目录扫描 + 文件扩展名过滤的发现策略
//     （关联：第二周 2.4 插件发现机制 — 这是最简单的"约定优于配置"方式）
//   - hotReload 通过 unload → re-load → re-initialize 实现
//     （注意：此简化版不处理运行中状态迁移，生产环境需参考第二周 2.5 的完整状态机）
//   - shared_mutex 实现读写锁，允许并发查询、互斥加载卸载
//   - watchDirectory 使用轮询检测文件修改时间（跨平台兼容，性能次优）
//
// 【与理论学习的关联】
//   第二周 2.3（扩展点设计）→ PluginManager 本身就是一个扩展点的管理者
//   第二周 2.4（插件发现）→ discoverPlugins 实现了目录扫描发现策略
//   第二周 2.5（生命周期）→ load/unload/hotReload 对应 Created→Running→Destroyed
//   第三周 3.5（依赖解析）→ 当前版本未实现依赖排序，可作为扩展练习
// ============================================================================

#pragma once

#include "plugin_interface.hpp"
#include "../loader/dynamic_library.hpp"
#include <map>
#include <set>
#include <queue>
#include <shared_mutex>
#include <filesystem>

namespace plugin {

// 插件状态
enum class PluginState {
    Discovered,
    Loaded,
    Initialized,
    Active,
    Inactive,
    Error,
    Unloaded
};

// 加载的插件信息
struct LoadedPlugin {
    std::unique_ptr<DynamicLibrary> library;
    std::unique_ptr<IPlugin, PluginDestroyer> instance;
    PluginState state = PluginState::Discovered;
    std::string errorMessage;
    std::filesystem::file_time_type lastModified;
};

// 插件管理器配置
struct PluginManagerConfig {
    std::vector<std::filesystem::path> searchPaths;
    Version hostApiVersion{2, 0, 0};
    bool enableHotReload = false;
    std::chrono::milliseconds hotReloadCheckInterval{5000};
};

class PluginManager : public IPluginContext {
private:
    PluginManagerConfig config_;
    std::map<std::string, LoadedPlugin> plugins_;
    mutable std::shared_mutex pluginsMutex_;

    // 扩展点注册表
    std::map<std::string, std::map<std::string, std::any>> extensions_;
    mutable std::shared_mutex extensionsMutex_;

    // 事件系统
    struct EventSubscription {
        uint64_t id;
        std::function<void(const std::any&)> handler;
    };
    std::map<std::string, std::vector<EventSubscription>> eventSubscriptions_;
    std::atomic<uint64_t> subscriptionIdGen_{0};
    mutable std::mutex eventMutex_;

    // 配置存储
    std::map<std::string, std::any> configStore_;
    mutable std::shared_mutex configMutex_;

    // 热重载监视线程
    std::atomic<bool> watcherRunning_{false};
    std::thread watcherThread_;

    // 发现插件
    std::vector<std::filesystem::path> discoverPlugins() {
        std::vector<std::filesystem::path> found;

        for (const auto& searchPath : config_.searchPaths) {
            if (!std::filesystem::exists(searchPath)) continue;

            for (const auto& entry :
                 std::filesystem::directory_iterator(searchPath)) {
                if (!entry.is_regular_file()) continue;

                auto ext = entry.path().extension().string();
                if (ext == getLibraryExtension()) {
                    found.push_back(entry.path());
                }
            }
        }

        return found;
    }

    // 加载单个插件
    bool loadPlugin(const std::filesystem::path& path) {
        try {
            auto library = std::make_unique<DynamicLibrary>(path);

            // 检查API版本
            auto getApiVersion = library->tryGetSymbol<const char*(*)()>(
                "getPluginApiVersion");
            if (getApiVersion) {
                Version pluginApiVersion = Version::parse((*getApiVersion)());
                if (!config_.hostApiVersion.isCompatibleWith(pluginApiVersion)) {
                    std::cerr << "Plugin API version mismatch: " << path
                              << " (requires " << pluginApiVersion.toString()
                              << ", host provides "
                              << config_.hostApiVersion.toString() << ")"
                              << std::endl;
                    return false;
                }
            }

            // 获取工厂函数
            auto factory = library->getSymbol<PluginFactory>("createPlugin");
            auto destroyer = library->getSymbol<PluginDestroyer>("destroyPlugin");

            // 创建插件实例
            IPlugin* rawPlugin = factory();
            if (!rawPlugin) {
                throw std::runtime_error("Plugin factory returned null");
            }

            std::unique_ptr<IPlugin, PluginDestroyer> plugin(rawPlugin, destroyer);

            const auto& metadata = plugin->getMetadata();

            std::unique_lock lock(pluginsMutex_);

            // 检查是否已加载
            if (plugins_.count(metadata.id)) {
                std::cerr << "Plugin already loaded: " << metadata.id << std::endl;
                return false;
            }

            LoadedPlugin loaded;
            loaded.library = std::move(library);
            loaded.instance = std::move(plugin);
            loaded.state = PluginState::Loaded;
            loaded.lastModified = std::filesystem::last_write_time(path);

            plugins_[metadata.id] = std::move(loaded);

            std::cout << "Plugin loaded: " << metadata.name
                      << " v" << metadata.version.toString() << std::endl;

            return true;

        } catch (const std::exception& e) {
            std::cerr << "Failed to load plugin " << path << ": "
                      << e.what() << std::endl;
            return false;
        }
    }

    // 依赖解析 - 拓扑排序
    std::vector<std::string> resolveDependencies() {
        std::map<std::string, std::set<std::string>> graph;
        std::map<std::string, int> inDegree;

        std::shared_lock lock(pluginsMutex_);

        // 构建依赖图
        for (const auto& [id, loaded] : plugins_) {
            if (!graph.count(id)) {
                graph[id] = {};
                inDegree[id] = 0;
            }

            for (const auto& dep : loaded.instance->getMetadata().dependencies) {
                if (!dep.optional || plugins_.count(dep.id)) {
                    graph[dep.id].insert(id);
                    inDegree[id]++;
                }
            }
        }

        // Kahn's算法
        std::queue<std::string> queue;
        for (const auto& [id, degree] : inDegree) {
            if (degree == 0) {
                queue.push(id);
            }
        }

        std::vector<std::string> result;
        while (!queue.empty()) {
            auto id = queue.front();
            queue.pop();
            result.push_back(id);

            for (const auto& dependent : graph[id]) {
                if (--inDegree[dependent] == 0) {
                    queue.push(dependent);
                }
            }
        }

        if (result.size() != plugins_.size()) {
            throw std::runtime_error("Circular dependency detected");
        }

        return result;
    }

    // 热重载监视循环
    void watcherLoop() {
        while (watcherRunning_) {
            std::this_thread::sleep_for(config_.hotReloadCheckInterval);

            std::vector<std::string> toReload;

            {
                std::shared_lock lock(pluginsMutex_);
                for (const auto& [id, loaded] : plugins_) {
                    if (!loaded.library) continue;

                    auto path = loaded.library->getPath();
                    if (!std::filesystem::exists(path)) continue;

                    auto currentModTime = std::filesystem::last_write_time(path);
                    if (currentModTime > loaded.lastModified) {
                        toReload.push_back(id);
                    }
                }
            }

            for (const auto& id : toReload) {
                std::cout << "Hot reloading plugin: " << id << std::endl;
                reloadPlugin(id);
            }
        }
    }

public:
    explicit PluginManager(PluginManagerConfig config = {})
        : config_(std::move(config)) {

        if (config_.searchPaths.empty()) {
            config_.searchPaths.push_back("./plugins");
        }
    }

    ~PluginManager() {
        stopHotReload();
        unloadAll();
    }

    // 发现并加载所有插件
    void loadAll() {
        auto paths = discoverPlugins();
        for (const auto& path : paths) {
            loadPlugin(path);
        }
    }

    // 初始化并激活所有插件
    bool activateAll() {
        try {
            auto order = resolveDependencies();

            // 初始化
            for (const auto& id : order) {
                std::unique_lock lock(pluginsMutex_);
                auto& loaded = plugins_[id];

                if (loaded.state != PluginState::Loaded) continue;

                lock.unlock();

                if (!loaded.instance->initialize(this)) {
                    std::cerr << "Failed to initialize plugin: " << id << std::endl;
                    loaded.state = PluginState::Error;
                    loaded.errorMessage = "Initialization failed";
                    continue;
                }

                loaded.state = PluginState::Initialized;
            }

            // 激活
            for (const auto& id : order) {
                std::unique_lock lock(pluginsMutex_);
                auto& loaded = plugins_[id];

                if (loaded.state != PluginState::Initialized) continue;

                lock.unlock();

                if (!loaded.instance->activate()) {
                    std::cerr << "Failed to activate plugin: " << id << std::endl;
                    loaded.state = PluginState::Error;
                    loaded.errorMessage = "Activation failed";
                    continue;
                }

                loaded.state = PluginState::Active;
                std::cout << "Plugin activated: " << id << std::endl;
            }

            return true;

        } catch (const std::exception& e) {
            std::cerr << "Failed to activate plugins: " << e.what() << std::endl;
            return false;
        }
    }

    // 停用并卸载所有插件
    void unloadAll() {
        std::vector<std::string> order;

        try {
            order = resolveDependencies();
            std::reverse(order.begin(), order.end());  // 逆序卸载
        } catch (...) {
            // 如果有循环依赖，按任意顺序卸载
            std::shared_lock lock(pluginsMutex_);
            for (const auto& [id, _] : plugins_) {
                order.push_back(id);
            }
        }

        for (const auto& id : order) {
            unloadPlugin(id);
        }
    }

    // 卸载单个插件
    bool unloadPlugin(const std::string& id) {
        std::unique_lock lock(pluginsMutex_);

        auto it = plugins_.find(id);
        if (it == plugins_.end()) return false;

        auto& loaded = it->second;

        // 检查是否有其他插件依赖此插件
        for (const auto& [otherId, other] : plugins_) {
            if (otherId == id) continue;

            for (const auto& dep : other.instance->getMetadata().dependencies) {
                if (dep.id == id && !dep.optional &&
                    other.state == PluginState::Active) {
                    std::cerr << "Cannot unload " << id
                              << ": plugin " << otherId
                              << " depends on it" << std::endl;
                    return false;
                }
            }
        }

        // 停用
        if (loaded.state == PluginState::Active) {
            loaded.instance->deactivate();
        }

        // 清理
        loaded.instance->dispose();

        // 移除
        plugins_.erase(it);

        std::cout << "Plugin unloaded: " << id << std::endl;
        return true;
    }

    // 重载插件
    bool reloadPlugin(const std::string& id) {
        std::filesystem::path path;

        {
            std::shared_lock lock(pluginsMutex_);
            auto it = plugins_.find(id);
            if (it == plugins_.end()) return false;
            path = it->second.library->getPath();
        }

        if (!unloadPlugin(id)) return false;

        // 稍等文件系统
        std::this_thread::sleep_for(std::chrono::milliseconds(100));

        if (!loadPlugin(path)) return false;

        // 重新初始化和激活
        {
            std::unique_lock lock(pluginsMutex_);
            auto& loaded = plugins_[id];

            lock.unlock();

            if (!loaded.instance->initialize(this)) {
                loaded.state = PluginState::Error;
                return false;
            }
            loaded.state = PluginState::Initialized;

            if (!loaded.instance->activate()) {
                loaded.state = PluginState::Error;
                return false;
            }
            loaded.state = PluginState::Active;
        }

        publishEvent("plugin.reloaded", id);
        return true;
    }

    // 启动热重载
    void startHotReload() {
        if (!config_.enableHotReload || watcherRunning_) return;

        watcherRunning_ = true;
        watcherThread_ = std::thread(&PluginManager::watcherLoop, this);
    }

    // 停止热重载
    void stopHotReload() {
        if (!watcherRunning_) return;

        watcherRunning_ = false;
        if (watcherThread_.joinable()) {
            watcherThread_.join();
        }
    }

    // IPluginContext 实现
    void log(const std::string& level, const std::string& message) override {
        std::cout << "[" << level << "] " << message << std::endl;
    }

    IPlugin* getPlugin(const std::string& id) override {
        std::shared_lock lock(pluginsMutex_);
        auto it = plugins_.find(id);
        return it != plugins_.end() ? it->second.instance.get() : nullptr;
    }

    void registerExtension(const std::string& extensionPoint,
                          const std::string& id,
                          std::any extension) override {
        std::unique_lock lock(extensionsMutex_);
        extensions_[extensionPoint][id] = std::move(extension);
    }

    std::vector<std::any> getExtensions(
        const std::string& extensionPoint) override {
        std::shared_lock lock(extensionsMutex_);
        std::vector<std::any> result;

        auto it = extensions_.find(extensionPoint);
        if (it != extensions_.end()) {
            for (const auto& [_, ext] : it->second) {
                result.push_back(ext);
            }
        }

        return result;
    }

    void publishEvent(const std::string& event, const std::any& data) override {
        std::vector<std::function<void(const std::any&)>> handlers;

        {
            std::lock_guard lock(eventMutex_);
            auto it = eventSubscriptions_.find(event);
            if (it != eventSubscriptions_.end()) {
                for (const auto& sub : it->second) {
                    handlers.push_back(sub.handler);
                }
            }
        }

        for (const auto& handler : handlers) {
            try {
                handler(data);
            } catch (const std::exception& e) {
                log("ERROR", "Event handler error: " + std::string(e.what()));
            }
        }
    }

    uint64_t subscribeEvent(const std::string& event,
        std::function<void(const std::any&)> handler) override {
        std::lock_guard lock(eventMutex_);
        uint64_t id = ++subscriptionIdGen_;
        eventSubscriptions_[event].push_back({id, std::move(handler)});
        return id;
    }

    void unsubscribeEvent(uint64_t subscriptionId) override {
        std::lock_guard lock(eventMutex_);
        for (auto& [_, subs] : eventSubscriptions_) {
            subs.erase(
                std::remove_if(subs.begin(), subs.end(),
                    [subscriptionId](const EventSubscription& s) {
                        return s.id == subscriptionId;
                    }),
                subs.end()
            );
        }
    }

    std::optional<std::any> getConfig(const std::string& key) override {
        std::shared_lock lock(configMutex_);
        auto it = configStore_.find(key);
        return it != configStore_.end() ?
               std::optional(it->second) : std::nullopt;
    }

    // 设置配置
    void setConfig(const std::string& key, std::any value) {
        std::unique_lock lock(configMutex_);
        configStore_[key] = std::move(value);
    }

    // 获取插件状态
    std::map<std::string, PluginState> getPluginStates() const {
        std::shared_lock lock(pluginsMutex_);
        std::map<std::string, PluginState> states;
        for (const auto& [id, loaded] : plugins_) {
            states[id] = loaded.state;
        }
        return states;
    }
};

} // namespace plugin
```

#### 4. 示例插件实现 (plugins/sample_plugin/)

```cpp
// ============================================================================
// SamplePlugin — 示例插件实现
// ============================================================================
//
// 【在系统中的角色】
//   展示如何基于 IPlugin 接口开发一个完整的插件。这是插件开发者的参考模板，
//   演示了接口实现、工厂函数导出、以及生命周期回调的标准写法。
//
// 【设计决策】
//   - 继承 IPlugin 并实现所有纯虚函数 — 这是插件的最低要求
//   - 使用 IMPLEMENT_PLUGIN 宏自动生成 createPlugin/destroyPlugin
//     （关联：第一周 1.4 — extern "C" 避免 C++ name mangling）
//   - 插件以独立共享库编译，运行时由 PluginManager 动态加载
//   - 展示了插件内部状态管理（初始化标志、配置数据）
//
// 【与理论学习的关联】
//   第二周 2.2（工厂注册）→ IMPLEMENT_PLUGIN 宏就是工厂模式的实际应用
//   第二周 2.5（生命周期）→ initialize/shutdown 对应状态机的 Running/Destroyed
//   第四周 4.1（安全威胁模型）→ 插件代码在主进程中运行，无隔离，存在安全风险
// ============================================================================

// sample_plugin.hpp
#pragma once

#include "plugin/core/plugin_interface.hpp"
#include <iostream>
#include <thread>
#include <atomic>

// 必须定义导出宏
#if defined(_WIN32)
    #define PLUGIN_EXPORT __declspec(dllexport)
#else
    #define PLUGIN_EXPORT __attribute__((visibility("default")))
#endif

namespace sample {

// 自定义扩展接口
class IGreeter {
public:
    virtual ~IGreeter() = default;
    virtual std::string greet(const std::string& name) = 0;
};

class SamplePlugin : public plugin::IPlugin {
private:
    plugin::PluginMetadata metadata_;
    plugin::IPluginContext* context_{nullptr};
    std::atomic<bool> running_{false};
    std::thread workerThread_;
    uint64_t eventSubscription_{0};

    class Greeter : public IGreeter {
    public:
        std::string greet(const std::string& name) override {
            return "Hello, " + name + "! From SamplePlugin.";
        }
    };

    std::shared_ptr<Greeter> greeter_;

    void workerLoop() {
        int counter = 0;
        while (running_) {
            std::this_thread::sleep_for(std::chrono::seconds(5));
            if (running_ && context_) {
                context_->publishEvent("sample.heartbeat", ++counter);
            }
        }
    }

public:
    SamplePlugin() {
        metadata_.id = "com.example.sample";
        metadata_.name = "Sample Plugin";
        metadata_.version = {1, 0, 0};
        metadata_.apiVersion = {2, 0, 0};
        metadata_.description = "A sample plugin demonstrating the plugin API";
        metadata_.author = "Developer";
        metadata_.license = "MIT";
        metadata_.providedExtensions = {"greeter"};
    }

    const plugin::PluginMetadata& getMetadata() const override {
        return metadata_;
    }

    bool initialize(plugin::IPluginContext* context) override {
        context_ = context;
        greeter_ = std::make_shared<Greeter>();

        context_->log("INFO", "SamplePlugin initializing...");

        // 订阅事件
        eventSubscription_ = context_->subscribeEvent("app.shutdown",
            [this](const std::any&) {
                context_->log("INFO", "SamplePlugin received shutdown event");
            });

        return true;
    }

    bool activate() override {
        if (!context_) return false;

        context_->log("INFO", "SamplePlugin activating...");

        // 注册扩展
        context_->registerExtension("greeter", metadata_.id, greeter_);

        // 启动后台工作
        running_ = true;
        workerThread_ = std::thread(&SamplePlugin::workerLoop, this);

        context_->log("INFO", "SamplePlugin activated");
        return true;
    }

    bool deactivate() override {
        if (context_) {
            context_->log("INFO", "SamplePlugin deactivating...");
        }

        running_ = false;
        if (workerThread_.joinable()) {
            workerThread_.join();
        }

        return true;
    }

    void dispose() override {
        if (context_ && eventSubscription_) {
            context_->unsubscribeEvent(eventSubscription_);
        }
        greeter_.reset();
        context_ = nullptr;
    }

    bool configure(const std::any& config) override {
        // 处理配置更新
        return true;
    }

    bool isHealthy() const override {
        return running_ && context_ != nullptr;
    }
};

} // namespace sample

// 声明插件导出
DECLARE_PLUGIN(sample::SamplePlugin)
```

#### 5. 主程序 (main.cpp)

```cpp
// ============================================================================
// main.cpp — 插件框架宿主程序
// ============================================================================
//
// 【在系统中的角色】
//   框架的入口点和宿主进程。演示了从零开始使用 PluginManager 的完整流程：
//   发现 → 加载 → 使用 → 监控热重载 → 优雅退出。
//
// 【设计决策】
//   - 先 discoverPlugins 再逐个 loadPlugin，分离发现与加载阶段
//   - 信号处理确保 Ctrl+C 时能正常卸载所有插件（RAII 链式析构）
//   - watchDirectory 在后台线程运行，实现插件热重载自动触发
//   - 这是一个命令行演示程序；生产环境中宿主可能是GUI应用或服务进程
//
// 【与理论学习的关联】
//   第二周 2.4（插件发现）→ discoverPlugins 的实际调用
//   第二周 2.5（生命周期）→ 展示完整的 discover→load→init→shutdown→unload 流程
//   第二周 2.8（VSCode分析）→ 对比 VSCode 的 Extension Host 启动流程
// ============================================================================

#include "plugin/core/plugin_manager.hpp"
#include <iostream>
#include <csignal>

std::unique_ptr<plugin::PluginManager> g_manager;

void signalHandler(int signal) {
    std::cout << "\nShutting down..." << std::endl;
    if (g_manager) {
        g_manager->publishEvent("app.shutdown", true);
        g_manager->stopHotReload();
        g_manager->unloadAll();
    }
    std::exit(0);
}

int main(int argc, char* argv[]) {
    std::signal(SIGINT, signalHandler);
    std::signal(SIGTERM, signalHandler);

    // 配置插件管理器
    plugin::PluginManagerConfig config;
    config.searchPaths = {"./plugins", "/usr/local/lib/myapp/plugins"};
    config.enableHotReload = true;
    config.hotReloadCheckInterval = std::chrono::milliseconds(3000);

    g_manager = std::make_unique<plugin::PluginManager>(config);

    // 加载所有插件
    std::cout << "Discovering and loading plugins..." << std::endl;
    g_manager->loadAll();

    // 激活插件
    std::cout << "Activating plugins..." << std::endl;
    if (!g_manager->activateAll()) {
        std::cerr << "Some plugins failed to activate" << std::endl;
    }

    // 启动热重载
    g_manager->startHotReload();
    std::cout << "Hot reload enabled" << std::endl;

    // 显示已加载的插件
    std::cout << "\nLoaded plugins:" << std::endl;
    for (const auto& [id, state] : g_manager->getPluginStates()) {
        std::cout << "  - " << id << ": ";
        switch (state) {
            case plugin::PluginState::Active:
                std::cout << "Active"; break;
            case plugin::PluginState::Error:
                std::cout << "Error"; break;
            default:
                std::cout << "Other"; break;
        }
        std::cout << std::endl;
    }

    // 使用扩展
    auto extensions = g_manager->getExtensions("greeter");
    for (const auto& ext : extensions) {
        try {
            auto greeter = std::any_cast<
                std::shared_ptr<sample::IGreeter>>(ext);
            std::cout << greeter->greet("World") << std::endl;
        } catch (...) {}
    }

    // 主循环
    std::cout << "\nPress Ctrl+C to exit" << std::endl;
    while (true) {
        std::this_thread::sleep_for(std::chrono::seconds(1));
    }

    return 0;
}
```

#### 6. CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.16)
project(plugin_framework VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# 默认构建类型
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

# ==================== 核心库（header-only）====================
add_library(plugin_core INTERFACE)
target_include_directories(plugin_core INTERFACE
    ${CMAKE_SOURCE_DIR}/include
)

# ==================== 主程序 ====================
add_executable(plugin_host
    src/main.cpp
)

target_link_libraries(plugin_host PRIVATE
    plugin_core
    ${CMAKE_DL_LIBS}    # 自动链接 libdl（Linux）或无操作（macOS/Windows）
)

if(UNIX AND NOT APPLE)
    target_link_libraries(plugin_host PRIVATE pthread)
endif()

# ==================== 示例插件（共享库）====================
# 每个插件编译为独立的 .so / .dylib / .dll
add_library(sample_plugin SHARED
    plugins/sample_plugin/sample_plugin.cpp
)

target_link_libraries(sample_plugin PRIVATE plugin_core)

# 插件不需要 lib 前缀（便于按名称加载）
set_target_properties(sample_plugin PROPERTIES
    PREFIX ""
    # 输出到统一的 plugins 目录
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/plugins
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/plugins
)

# 控制符号可见性：默认隐藏，仅导出标记为 PLUGIN_EXPORT 的符号
set_target_properties(sample_plugin PROPERTIES
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON
)

# ==================== 测试 ====================
enable_testing()
find_package(GTest QUIET)

if(GTest_FOUND)
    add_executable(plugin_tests
        tests/test_dynamic_library.cpp
        tests/test_plugin_interface.cpp
        tests/test_plugin_manager.cpp
    )

    target_link_libraries(plugin_tests PRIVATE
        plugin_core
        GTest::gtest_main
        ${CMAKE_DL_LIBS}
    )

    if(UNIX AND NOT APPLE)
        target_link_libraries(plugin_tests PRIVATE pthread)
    endif()

    include(GoogleTest)
    gtest_discover_tests(plugin_tests)
else()
    message(STATUS "Google Test not found, tests will not be built")
endif()

# ==================== 安装规则 ====================
install(TARGETS plugin_host RUNTIME DESTINATION bin)
install(TARGETS sample_plugin
    LIBRARY DESTINATION lib/plugins
    RUNTIME DESTINATION lib/plugins
)
install(DIRECTORY include/ DESTINATION include)
```

#### 7. 单元测试示例 (tests/test_plugin_manager.cpp)

```cpp
// ============================================================================
// 插件管理器单元测试
// ============================================================================
//
// 测试覆盖：插件发现、加载/卸载、生命周期状态转换、热重载、异常处理
// 使用 Google Test 框架
// 关联：检验标准中"单元测试覆盖核心功能"要求
// ============================================================================

#include <gtest/gtest.h>
#include "plugin/core/plugin_manager.hpp"
#include "plugin/loader/dynamic_library.hpp"
#include <filesystem>
#include <fstream>

namespace fs = std::filesystem;

// ============================================================================
// DynamicLibrary 测试
// ============================================================================

class DynamicLibraryTest : public ::testing::Test {
protected:
    void SetUp() override {
        // 确保测试插件目录存在
        testPluginDir_ = fs::temp_directory_path() / "plugin_test";
        fs::create_directories(testPluginDir_);
    }

    void TearDown() override {
        fs::remove_all(testPluginDir_);
    }

    fs::path testPluginDir_;
};

TEST_F(DynamicLibraryTest, LoadNonexistentLibraryThrows) {
    plugin::DynamicLibrary lib;
    EXPECT_THROW(
        lib.load("/nonexistent/path/libfake.so"),
        plugin::DynamicLibraryError
    );
}

TEST_F(DynamicLibraryTest, LoadAndUnloadSystemLibrary) {
    plugin::DynamicLibrary lib;

    // 加载系统中一定存在的库
#ifdef __linux__
    EXPECT_NO_THROW(lib.load("libm.so.6"));
#elif __APPLE__
    EXPECT_NO_THROW(lib.load("libSystem.B.dylib"));
#endif

    EXPECT_TRUE(lib.isLoaded());
    lib.unload();
    EXPECT_FALSE(lib.isLoaded());
}

TEST_F(DynamicLibraryTest, GetSymbolFromLoadedLibrary) {
    plugin::DynamicLibrary lib;

#ifdef __linux__
    lib.load("libm.so.6");
    void* sym = lib.getSymbol("cos");
    EXPECT_NE(sym, nullptr);
#elif __APPLE__
    lib.load("libSystem.B.dylib");
    void* sym = lib.getSymbol("printf");
    EXPECT_NE(sym, nullptr);
#endif
}

TEST_F(DynamicLibraryTest, MoveSemantics) {
    plugin::DynamicLibrary lib1;

#ifdef __linux__
    lib1.load("libm.so.6");
#elif __APPLE__
    lib1.load("libSystem.B.dylib");
#endif

    // 移动构造
    plugin::DynamicLibrary lib2(std::move(lib1));
    EXPECT_TRUE(lib2.isLoaded());
    EXPECT_FALSE(lib1.isLoaded());  // 原对象已被移走

    // 移动赋值
    plugin::DynamicLibrary lib3;
    lib3 = std::move(lib2);
    EXPECT_TRUE(lib3.isLoaded());
    EXPECT_FALSE(lib2.isLoaded());
}

// ============================================================================
// PluginManager 测试
// ============================================================================

class PluginManagerTest : public ::testing::Test {
protected:
    void SetUp() override {
        testPluginDir_ = fs::temp_directory_path() / "plugin_mgr_test";
        fs::create_directories(testPluginDir_);

        config_.searchPaths = {testPluginDir_.string()};
        config_.enableHotReload = false;
    }

    void TearDown() override {
        manager_.reset();
        fs::remove_all(testPluginDir_);
    }

    fs::path testPluginDir_;
    plugin::PluginManagerConfig config_;
    std::unique_ptr<plugin::PluginManager> manager_;
};

TEST_F(PluginManagerTest, ConstructWithValidConfig) {
    EXPECT_NO_THROW(
        manager_ = std::make_unique<plugin::PluginManager>(config_)
    );
}

TEST_F(PluginManagerTest, DiscoverInEmptyDirectory) {
    manager_ = std::make_unique<plugin::PluginManager>(config_);
    auto discovered = manager_->discoverPlugins();
    EXPECT_TRUE(discovered.empty());
}

TEST_F(PluginManagerTest, LoadNonexistentPluginFails) {
    manager_ = std::make_unique<plugin::PluginManager>(config_);
    EXPECT_FALSE(manager_->loadPlugin("nonexistent_plugin"));
}

TEST_F(PluginManagerTest, DoubleLoadSamePluginFails) {
    // 如果插件已加载，再次加载同一插件应返回false或抛异常
    manager_ = std::make_unique<plugin::PluginManager>(config_);

    // 注意：此测试需要实际的插件共享库文件
    // 在CI环境中，先构建 sample_plugin 目标，然后复制到 testPluginDir_
    // 这里仅测试逻辑：对不存在的插件double load
    EXPECT_FALSE(manager_->loadPlugin("fake_plugin"));
    EXPECT_FALSE(manager_->loadPlugin("fake_plugin"));
}

TEST_F(PluginManagerTest, UnloadAllPlugins) {
    manager_ = std::make_unique<plugin::PluginManager>(config_);
    // 即使没有插件，unloadAll 也不应崩溃
    EXPECT_NO_THROW(manager_->unloadAll());
}

// ============================================================================
// 集成测试（需要编译好的示例插件）
// ============================================================================

class PluginIntegrationTest : public ::testing::Test {
protected:
    void SetUp() override {
        // 查找编译产物中的 sample_plugin
        pluginDir_ = fs::path(PLUGIN_BUILD_DIR) / "plugins";
        if (!fs::exists(pluginDir_)) {
            GTEST_SKIP() << "Plugin build directory not found, skipping integration tests";
        }

        config_.searchPaths = {pluginDir_.string()};
        config_.enableHotReload = false;
        manager_ = std::make_unique<plugin::PluginManager>(config_);
    }

    fs::path pluginDir_;
    plugin::PluginManagerConfig config_;
    std::unique_ptr<plugin::PluginManager> manager_;
};

TEST_F(PluginIntegrationTest, DiscoverAndLoadSamplePlugin) {
    auto plugins = manager_->discoverPlugins();
    ASSERT_FALSE(plugins.empty()) << "No plugins discovered in " << pluginDir_;

    // 加载第一个发现的插件
    EXPECT_TRUE(manager_->loadPlugin(plugins[0]));

    // 验证插件状态
    auto states = manager_->getPluginStates();
    EXPECT_EQ(states.size(), 1);
}

TEST_F(PluginIntegrationTest, PluginLifecycle) {
    auto plugins = manager_->discoverPlugins();
    ASSERT_FALSE(plugins.empty());

    // 完整生命周期：load → activate → deactivate → unload
    EXPECT_TRUE(manager_->loadPlugin(plugins[0]));
    EXPECT_TRUE(manager_->activateAll());

    auto states = manager_->getPluginStates();
    for (const auto& [id, state] : states) {
        EXPECT_EQ(state, plugin::PluginState::Active);
    }

    manager_->unloadAll();
    states = manager_->getPluginStates();
    EXPECT_TRUE(states.empty());
}
```

---

## 检验标准

### 知识检验 — 第一周：动态链接基础
1. [ ] 能够画出ELF文件的核心结构（ELF Header → Program Headers → Sections）
2. [ ] 能够解释GOT/PLT延迟绑定的完整调用链（首次调用 vs 后续调用）
3. [ ] 能够正确使用dlopen/dlsym/dlclose，并处理错误（dlerror）
4. [ ] 理解 `-fvisibility=hidden` + `__attribute__((visibility("default")))` 的符号控制策略
5. [ ] 能够解释PIC代码的生成原理及其对性能的影响
6. [ ] 理解RPATH/RUNPATH/$ORIGIN/@rpath的搜索优先级

### 知识检验 — 第二周：插件架构模式
7. [ ] 能够对比四种插件架构模式（微内核/管道过滤器/事件驱动/扩展点）的适用场景
8. [ ] 能够设计抽象工厂 + 自注册的插件注册机制
9. [ ] 理解扩展点（Extension Points）的声明与实现分离设计
10. [ ] 能够描述插件生命周期状态机的完整状态转换图
11. [ ] 理解事件总线如何实现插件间松耦合通信
12. [ ] 能够分析VSCode扩展系统的架构（Extension Host进程模型）

### 知识检验 — 第三周：版本管理与兼容性
13. [ ] 能够实现SemVer解析器并处理版本约束（^/~/>=/<）
14. [ ] 能够识别C++ ABI破坏的常见场景（添加虚函数/改变成员顺序/sizeof变化）
15. [ ] 掌握PIMPL模式在ABI稳定性中的应用
16. [ ] 理解COM风格QueryInterface的多版本接口管理
17. [ ] 能够实现拓扑排序的依赖解析算法并处理循环依赖

### 知识检验 — 第四周：安全隔离与沙箱
18. [ ] 能够描述插件系统的安全威胁模型（代码注入/资源耗尽/数据泄露/权限提升）
19. [ ] 理解进程隔离 + IPC的架构设计及性能权衡
20. [ ] 能够解释Linux命名空间/seccomp-bpf/capabilities的分层防御原理
21. [ ] 理解WebAssembly沙箱的内存隔离机制（线性内存 + 导入函数白名单）
22. [ ] 能够设计基于能力的权限系统（Capability-based Security）

### 实践检验
1. [ ] 完成跨平台动态库加载器（DynamicLibrary），支持 Windows/Linux/macOS
2. [ ] 插件能够正确经历完整生命周期（发现→加载→初始化→运行→停止→卸载）
3. [ ] 实现插件发现机制（目录扫描 + 文件扩展名过滤）
4. [ ] 依赖解析正确处理拓扑排序和循环依赖检测
5. [ ] 热重载功能正常工作（修改插件文件后自动检测并重新加载）
6. [ ] 实现至少2个功能插件，并通过扩展点提供服务
7. [ ] CMake构建系统完整，插件编译为独立共享库
8. [ ] 编写单元测试覆盖核心功能（加载/卸载/发现/生命周期）

### 代码质量
1. [ ] 跨Windows/Linux/macOS编译通过（CMake构建）
2. [ ] 无内存泄漏和资源泄漏（Valgrind/ASan检测）
3. [ ] 线程安全，shared_mutex保护并发访问
4. [ ] 异常安全，错误处理完善（自定义异常类型）
5. [ ] 代码通过静态分析检查（clang-tidy）
6. [ ] 接口设计清晰，公共API有完整注释

---

## 输出物清单

1. **学习笔记**（按周拆分）
   - [ ] Week 1：动态链接原理笔记（ELF结构图 + GOT/PLT流程图 + 各平台对比表）
   - [ ] Week 2：插件架构模式笔记（四种模式对比 + VSCode架构分析 + 生命周期状态图）
   - [ ] Week 3：版本管理与ABI兼容性笔记（SemVer约束规则 + ABI破坏清单 + PIMPL示例）
   - [ ] Week 4：安全隔离技术笔记（威胁模型表 + Linux沙箱分层图 + Wasm安全模型）
   - [ ] 源码阅读笔记（LLVM Pass系统 / Qt插件系统 / Neovim RPC机制，使用阅读笔记模板）

2. **代码产出**
   - [ ] 跨平台插件框架完整实现（6个核心文件 + CMakeLists.txt）
   - [ ] 示例插件集合（至少2个功能插件）
   - [ ] 单元测试套件（覆盖DynamicLibrary、PluginManager、集成测试）
   - [ ] 每周练习任务代码（Week 1: ELF解析器 / Week 2: 事件总线 / Week 3: SemVer解析器 / Week 4: seccomp沙箱）

3. **文档产出**
   - [ ] 插件开发指南（面向插件开发者的教程文档）
   - [ ] API参考文档（IPlugin接口、PluginManager API）
   - [ ] 版本兼容性指南（ABI保持规则 + PIMPL迁移指南）

4. **演示**
   - [ ] 录制插件框架功能演示视频（插件热重载、发现加载全流程）
   - [ ] 准备插件架构设计演讲PPT（含架构图、模式对比、安全模型）

---

## 时间分配表

| 周次 | 理论学习 | 源码阅读 | 项目实践 | 总计 |
|------|----------|----------|----------|------|
| Week 1 | 15h | 8h | 12h | 35h |
| Week 2 | 12h | 8h | 15h | 35h |
| Week 3 | 10h | 6h | 19h | 35h |
| Week 4 | 8h | 2h | 25h | 35h |
| **总计** | **45h** | **24h** | **71h** | **140h** |

### 每日建议安排
- 09:00-11:00: 理论学习/源码阅读（阅读材料 + 代码示例精读）
- 11:00-12:00: 笔记整理（将理解转化为自己的笔记）
- 14:00-17:00: 项目实践（练习任务 + 实践项目编码）
- 17:00-18:00: 代码review与优化（回顾当日代码，运行测试）

---

## 下月预告

**Month 51: 面向数据设计（DOD）基础**

下个月将学习一种与面向对象截然不同的设计范式：
- 数据局部性与缓存优化
- AoS vs SoA数据布局
- 热/冷数据分离
- 批处理与SIMD友好设计
- 实践项目：高性能粒子系统

建议提前：
1. 复习计算机体系结构缓存知识
2. 了解CPU缓存行的工作原理
3. 学习基本的性能分析工具（perf, VTune）
