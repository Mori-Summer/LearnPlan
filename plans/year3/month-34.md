# Month 34: RPC框架基础——远程调用

## 本月主题概述

RPC（远程过程调用）是分布式系统的核心技术。本月学习RPC的基本概念，实现一个简单但完整的RPC框架，包括服务注册、序列化、网络传输等核心组件。

**学习目标**：
- 深入理解RPC的工作原理和设计哲学
- 掌握二进制序列化协议的设计与实现
- 实现生产级的RPC客户端和服务端
- 理解服务发现与治理的基本概念

---

## 详细周计划

### Week 1: RPC核心概念与协议设计

#### 学习目标
- 理解RPC的历史演进和核心思想
- 掌握RPC调用的完整流程
- 设计自己的RPC协议格式
- 理解IDL的作用和设计原则

#### 每日任务分解

| Day | 时间 | 上午任务（2.5h） | 下午任务（2.5h） | 输出物 |
|-----|------|------------------|------------------|--------|
| 1 | 5h | RPC历史：SunRPC→DCE-RPC→CORBA→gRPC演进 | 阅读Birrell & Nelson 1984年RPC论文 | `notes/rpc_history.md` |
| 2 | 5h | RPC核心概念：透明性、位置透明、访问透明 | 分析本地调用vs远程调用的差异 | `notes/rpc_concepts.md` |
| 3 | 5h | RPC调用流程详解：Stub、Skeleton、Marshal | 绘制完整的RPC调用时序图 | 时序图+笔记 |
| 4 | 5h | IDL设计原则：类型系统、版本兼容 | 对比Protobuf/Thrift/Avro IDL语法 | `notes/idl_comparison.md` |
| 5 | 5h | 设计自己的RPC协议格式 | 实现协议头解析 | `rpc_protocol.hpp` |
| 6 | 5h | 错误处理机制设计：错误码vs异常 | 实现错误类型定义 | `rpc_error.hpp` |
| 7 | 5h | 复习本周内容 | 编写Week1总结笔记 | 周总结笔记 |

#### 核心概念深入

**1. RPC的本质——让远程调用像本地调用一样简单**

```
RPC的核心目标：
┌─────────────────────────────────────────────────────────────┐
│                      透明性（Transparency）                   │
├─────────────────────────────────────────────────────────────┤
│  位置透明：调用者不需要知道服务在哪台机器                        │
│  访问透明：远程调用的语法与本地调用相同                          │
│  故障透明：网络故障对调用者尽可能透明（困难）                     │
│  并发透明：多个调用可以并发执行                                 │
└─────────────────────────────────────────────────────────────┘
```

**2. RPC调用的完整流程**

```
完整的RPC调用流程：

Client Process                              Server Process
┌─────────────────┐                        ┌─────────────────┐
│   Application   │                        │   Application   │
│  result = add(1,2)                       │  int add(a,b){  │
└────────┬────────┘                        │    return a+b;  │
         │ 1.调用                           │  }              │
         ▼                                 └────────▲────────┘
┌─────────────────┐                                 │ 6.调用
│   Client Stub   │                        ┌────────┴────────┐
│  - 序列化参数    │                        │  Server Skeleton │
│  - 构造请求消息  │                        │  - 反序列化参数   │
│  - 生成请求ID   │                        │  - 查找方法      │
└────────┬────────┘                        └────────▲────────┘
         │ 2.序列化                                  │ 5.反序列化
         ▼                                          │
┌─────────────────┐                        ┌────────┴────────┐
│  Network Layer  │                        │  Network Layer  │
│  - TCP连接管理   │   3.网络传输            │  - 监听端口     │
│  - 发送请求     │ ─────────────────────▶  │  - 接收请求     │
│  - 等待响应     │ ◀─────────────────────  │  - 发送响应     │
└─────────────────┘   4.网络传输（响应）      └─────────────────┘

时间线：
t0: 客户端发起调用
t1: Stub序列化参数（~微秒级）
t2: 网络传输请求（~毫秒级，取决于网络）
t3: 服务端反序列化（~微秒级）
t4: 执行实际方法（取决于业务逻辑）
t5: 序列化返回值
t6: 网络传输响应
t7: 客户端收到结果
```

**3. 八大谬误（Fallacies of Distributed Computing）**

```
Peter Deutsch提出的分布式计算八大谬误：

┌─────────────────────────────────────────────────────────────┐
│ 1. 网络是可靠的        → 实际：丢包、断连、分区                  │
│ 2. 延迟是零           → 实际：跨机房延迟可达数十毫秒              │
│ 3. 带宽是无限的        → 实际：网络拥塞、带宽受限                 │
│ 4. 网络是安全的        → 实际：中间人攻击、数据泄露               │
│ 5. 拓扑不会改变        → 实际：节点上下线、网络重构               │
│ 6. 只有一个管理员      → 实际：多团队、多组织协作                 │
│ 7. 传输成本是零        → 实际：序列化、网络IO都有开销             │
│ 8. 网络是同构的        → 实际：不同协议、不同版本共存             │
└─────────────────────────────────────────────────────────────┘

RPC框架需要处理这些现实问题！
```

#### RPC协议设计

```cpp
// rpc_protocol.hpp
#pragma once
#include <cstdint>
#include <string>
#include <vector>

namespace rpc {

// 魔数，用于识别RPC消息
constexpr uint32_t RPC_MAGIC = 0x52504321;  // "RPC!"

// 协议版本
constexpr uint8_t RPC_VERSION = 1;

// 消息类型
enum class MessageType : uint8_t {
    REQUEST      = 0x01,  // 请求
    RESPONSE     = 0x02,  // 响应
    HEARTBEAT    = 0x03,  // 心跳
    ERROR        = 0x04,  // 错误
};

// 序列化类型
enum class SerializationType : uint8_t {
    BINARY       = 0x01,  // 自定义二进制
    JSON         = 0x02,  // JSON（调试用）
    PROTOBUF     = 0x03,  // Protobuf（扩展）
};

// 压缩类型
enum class CompressionType : uint8_t {
    NONE         = 0x00,  // 无压缩
    GZIP         = 0x01,  // GZIP
    SNAPPY       = 0x02,  // Snappy
    LZ4          = 0x03,  // LZ4
};

/*
 * RPC消息头格式（固定24字节）
 *
 * ┌─────────────────────────────────────────────────────────┐
 * │ 0       1       2       3       4       5       6      7│
 * ├─────────────────────────────────────────────────────────┤
 * │              Magic Number (4 bytes)                     │
 * ├─────────────────────────────────────────────────────────┤
 * │ Version │MsgType│SerType│CompType│     Reserved        │
 * ├─────────────────────────────────────────────────────────┤
 * │              Request ID (8 bytes)                       │
 * ├─────────────────────────────────────────────────────────┤
 * │              Body Length (4 bytes)                      │
 * ├─────────────────────────────────────────────────────────┤
 * │              Checksum (4 bytes, CRC32)                  │
 * └─────────────────────────────────────────────────────────┘
 */
struct MessageHeader {
    uint32_t magic;              // 魔数
    uint8_t  version;            // 协议版本
    uint8_t  msg_type;           // 消息类型
    uint8_t  serialization;      // 序列化方式
    uint8_t  compression;        // 压缩方式
    uint64_t request_id;         // 请求ID（用于匹配请求和响应）
    uint32_t body_length;        // 消息体长度
    uint32_t checksum;           // CRC32校验和

    static constexpr size_t SIZE = 24;

    // 序列化为字节数组
    void serialize(char* buf) const {
        size_t offset = 0;

        // 使用网络字节序（大端）
        auto write_u32 = [&](uint32_t v) {
            buf[offset++] = (v >> 24) & 0xFF;
            buf[offset++] = (v >> 16) & 0xFF;
            buf[offset++] = (v >> 8) & 0xFF;
            buf[offset++] = v & 0xFF;
        };

        auto write_u64 = [&](uint64_t v) {
            for (int i = 7; i >= 0; --i) {
                buf[offset++] = (v >> (i * 8)) & 0xFF;
            }
        };

        write_u32(magic);
        buf[offset++] = version;
        buf[offset++] = msg_type;
        buf[offset++] = serialization;
        buf[offset++] = compression;
        write_u64(request_id);
        write_u32(body_length);
        write_u32(checksum);
    }

    // 从字节数组反序列化
    bool deserialize(const char* buf) {
        size_t offset = 0;

        auto read_u32 = [&]() -> uint32_t {
            uint32_t v = 0;
            v |= static_cast<uint8_t>(buf[offset++]) << 24;
            v |= static_cast<uint8_t>(buf[offset++]) << 16;
            v |= static_cast<uint8_t>(buf[offset++]) << 8;
            v |= static_cast<uint8_t>(buf[offset++]);
            return v;
        };

        auto read_u64 = [&]() -> uint64_t {
            uint64_t v = 0;
            for (int i = 0; i < 8; ++i) {
                v = (v << 8) | static_cast<uint8_t>(buf[offset++]);
            }
            return v;
        };

        magic = read_u32();
        if (magic != RPC_MAGIC) return false;

        version = buf[offset++];
        msg_type = buf[offset++];
        serialization = buf[offset++];
        compression = buf[offset++];
        request_id = read_u64();
        body_length = read_u32();
        checksum = read_u32();

        return true;
    }
};

// 错误码定义
enum class ErrorCode : int32_t {
    OK                    = 0,

    // 客户端错误 (1xxx)
    CLIENT_TIMEOUT        = 1001,  // 调用超时
    CLIENT_CONNECT_FAIL   = 1002,  // 连接失败
    CLIENT_SERIALIZE_FAIL = 1003,  // 序列化失败

    // 服务端错误 (2xxx)
    SERVER_ERROR          = 2001,  // 服务器内部错误
    METHOD_NOT_FOUND      = 2002,  // 方法不存在
    INVALID_ARGUMENT      = 2003,  // 参数无效
    SERVICE_UNAVAILABLE   = 2004,  // 服务不可用

    // 协议错误 (3xxx)
    PROTOCOL_ERROR        = 3001,  // 协议错误
    CHECKSUM_MISMATCH     = 3002,  // 校验和不匹配
    UNSUPPORTED_VERSION   = 3003,  // 不支持的版本
};

// 错误码转字符串
inline const char* error_string(ErrorCode code) {
    switch (code) {
        case ErrorCode::OK: return "OK";
        case ErrorCode::CLIENT_TIMEOUT: return "Client timeout";
        case ErrorCode::CLIENT_CONNECT_FAIL: return "Connection failed";
        case ErrorCode::METHOD_NOT_FOUND: return "Method not found";
        case ErrorCode::INVALID_ARGUMENT: return "Invalid argument";
        case ErrorCode::SERVER_ERROR: return "Server internal error";
        default: return "Unknown error";
    }
}

} // namespace rpc
```

#### Week 1 检验标准

- [ ] 能够解释RPC的核心思想和设计目标
- [ ] 能够绘制完整的RPC调用时序图
- [ ] 理解位置透明和访问透明的含义
- [ ] 能够列举分布式计算八大谬误
- [ ] 对比分析至少3种IDL（Protobuf/Thrift/Avro）
- [ ] 设计并实现自己的RPC协议头格式
- [ ] 理解为什么需要魔数、版本号、请求ID

---

### Week 2: 序列化协议深度实现

#### 学习目标
- 掌握二进制序列化的核心技术
- 理解TLV编码和变长整数编码
- 实现支持复杂类型的序列化框架
- 理解字节序和内存对齐问题

#### 每日任务分解

| Day | 时间 | 上午任务（2.5h） | 下午任务（2.5h） | 输出物 |
|-----|------|------------------|------------------|--------|
| 8 | 5h | 序列化基础：字节序、对齐、填充 | 实现基本类型序列化 | `serialization.hpp` v1 |
| 9 | 5h | 变长整数编码：Varint、ZigZag | 实现Varint编解码 | `varint.hpp` |
| 10 | 5h | TLV编码原理与实现 | 支持嵌套结构序列化 | `serialization.hpp` v2 |
| 11 | 5h | 字符串和容器序列化 | 支持vector/map序列化 | `serialization.hpp` v3 |
| 12 | 5h | 反射机制：编译期类型信息 | 实现自动序列化宏 | `rpc_reflect.hpp` |
| 13 | 5h | 对比Protobuf编码原理 | 分析Protobuf wire format | `notes/protobuf_encoding.md` |
| 14 | 5h | 性能优化：零拷贝、内存池 | 编写序列化性能测试 | 性能测试报告 |

#### 核心概念深入

**1. 字节序问题**

```cpp
/*
 * 字节序（Byte Order / Endianness）
 *
 * 大端序（Big-Endian）：高位字节在低地址
 * 小端序（Little-Endian）：低位字节在低地址
 *
 * 示例：存储 0x12345678
 *
 * 地址:     0x00  0x01  0x02  0x03
 * 大端序:   0x12  0x34  0x56  0x78  （网络字节序）
 * 小端序:   0x78  0x56  0x34  0x12  （x86/x64）
 *
 * 网络传输统一使用大端序（网络字节序）！
 */

// 检测当前系统字节序
inline bool is_little_endian() {
    uint32_t n = 1;
    return *reinterpret_cast<char*>(&n) == 1;
}

// 字节序转换（编译期优化）
template<typename T>
T byte_swap(T value) {
    static_assert(std::is_integral_v<T>, "Only integral types");

    if constexpr (sizeof(T) == 1) {
        return value;
    } else if constexpr (sizeof(T) == 2) {
        return ((value & 0xFF00) >> 8) |
               ((value & 0x00FF) << 8);
    } else if constexpr (sizeof(T) == 4) {
        return ((value & 0xFF000000) >> 24) |
               ((value & 0x00FF0000) >> 8) |
               ((value & 0x0000FF00) << 8) |
               ((value & 0x000000FF) << 24);
    } else if constexpr (sizeof(T) == 8) {
        return ((value & 0xFF00000000000000ULL) >> 56) |
               ((value & 0x00FF000000000000ULL) >> 40) |
               ((value & 0x0000FF0000000000ULL) >> 24) |
               ((value & 0x000000FF00000000ULL) >> 8) |
               ((value & 0x00000000FF000000ULL) << 8) |
               ((value & 0x0000000000FF0000ULL) << 24) |
               ((value & 0x000000000000FF00ULL) << 40) |
               ((value & 0x00000000000000FFULL) << 56);
    }
}

// 主机序转网络序
template<typename T>
T host_to_network(T value) {
    if constexpr (std::endian::native == std::endian::little) {
        return byte_swap(value);
    }
    return value;
}

// 网络序转主机序
template<typename T>
T network_to_host(T value) {
    return host_to_network(value);  // 同样的操作
}
```

**2. 变长整数编码（Varint）**

```cpp
/*
 * Varint编码原理（Protobuf使用）
 *
 * 每个字节的最高位（MSB）表示是否还有后续字节：
 * - MSB=1: 还有更多字节
 * - MSB=0: 这是最后一个字节
 *
 * 示例：编码 300
 * 300 的二进制：100101100
 *
 * 步骤：
 * 1. 分组（每7位一组，低位在前）：0101100, 0000010
 * 2. 添加MSB：10101100, 00000010
 * 3. 结果：0xAC 0x02
 *
 * 优点：小整数只占1字节，节省空间
 * 缺点：大整数可能占更多字节（最多10字节表示64位）
 */

// varint.hpp
#pragma once
#include <cstdint>
#include <cstddef>

namespace rpc {

class Varint {
public:
    // 编码uint64到缓冲区，返回写入字节数
    static size_t encode(uint64_t value, uint8_t* buf) {
        size_t i = 0;
        while (value >= 0x80) {
            buf[i++] = static_cast<uint8_t>(value | 0x80);
            value >>= 7;
        }
        buf[i++] = static_cast<uint8_t>(value);
        return i;
    }

    // 解码，返回读取字节数
    static size_t decode(const uint8_t* buf, uint64_t& value) {
        value = 0;
        size_t i = 0;
        int shift = 0;

        while (i < 10) {  // 最多10字节
            uint8_t byte = buf[i++];
            value |= static_cast<uint64_t>(byte & 0x7F) << shift;
            if ((byte & 0x80) == 0) break;
            shift += 7;
        }
        return i;
    }

    // 计算编码后的字节数
    static size_t encoded_size(uint64_t value) {
        size_t size = 1;
        while (value >= 0x80) {
            value >>= 7;
            ++size;
        }
        return size;
    }
};

/*
 * ZigZag编码：处理有符号整数
 *
 * 问题：负数的Varint编码总是10字节（因为补码表示）
 * 解决：将有符号数映射为无符号数
 *
 * 映射规则：
 *  0 ->  0
 * -1 ->  1
 *  1 ->  2
 * -2 ->  3
 *  2 ->  4
 *  ...
 *
 * 编码公式：(n << 1) ^ (n >> 63)  // 对于64位
 * 解码公式：(n >> 1) ^ -(n & 1)
 */

class ZigZag {
public:
    static uint64_t encode(int64_t n) {
        return (static_cast<uint64_t>(n) << 1) ^
               static_cast<uint64_t>(n >> 63);
    }

    static int64_t decode(uint64_t n) {
        return static_cast<int64_t>((n >> 1) ^
               (~(n & 1) + 1));  // -(n & 1) 的无UB写法
    }
};

} // namespace rpc
```

**3. 完整的序列化框架**

```cpp
// serialization.hpp
#pragma once
#include <vector>
#include <string>
#include <cstdint>
#include <cstring>
#include <type_traits>
#include <map>
#include <unordered_map>
#include <optional>
#include <stdexcept>
#include "varint.hpp"

namespace rpc {

// 序列化异常
class SerializationError : public std::runtime_error {
public:
    using std::runtime_error::runtime_error;
};

/*
 * Buffer类：序列化缓冲区
 *
 * 设计原则：
 * 1. 零拷贝：尽可能避免数据复制
 * 2. 内存安全：边界检查
 * 3. 高效：预分配、移动语义
 */
class Buffer {
public:
    Buffer() = default;
    explicit Buffer(size_t capacity) {
        data_.reserve(capacity);
    }

    // 移动语义
    Buffer(Buffer&&) = default;
    Buffer& operator=(Buffer&&) = default;

    // 禁止拷贝（避免意外的大量内存复制）
    Buffer(const Buffer&) = delete;
    Buffer& operator=(const Buffer&) = delete;

    //========== 写入操作 ==========

    // 写入原始字节
    void write_raw(const void* data, size_t len) {
        const char* p = static_cast<const char*>(data);
        data_.insert(data_.end(), p, p + len);
    }

    // 写入固定长度整数（网络字节序）
    template<typename T>
    std::enable_if_t<std::is_integral_v<T>>
    write_fixed(T value) {
        T network_value = host_to_network(value);
        write_raw(&network_value, sizeof(T));
    }

    // 写入变长整数
    void write_varint(uint64_t value) {
        uint8_t buf[10];
        size_t len = Varint::encode(value, buf);
        write_raw(buf, len);
    }

    // 写入有符号变长整数（ZigZag编码）
    void write_svarint(int64_t value) {
        write_varint(ZigZag::encode(value));
    }

    // 写入字符串（长度前缀）
    void write_string(const std::string& str) {
        write_varint(str.size());
        write_raw(str.data(), str.size());
    }

    // 写入二进制数据
    void write_bytes(const std::vector<uint8_t>& data) {
        write_varint(data.size());
        write_raw(data.data(), data.size());
    }

    // 写入布尔值
    void write_bool(bool value) {
        uint8_t v = value ? 1 : 0;
        write_raw(&v, 1);
    }

    // 写入浮点数（IEEE 754）
    void write_float(float value) {
        uint32_t bits;
        std::memcpy(&bits, &value, sizeof(float));
        write_fixed(bits);
    }

    void write_double(double value) {
        uint64_t bits;
        std::memcpy(&bits, &value, sizeof(double));
        write_fixed(bits);
    }

    //========== 读取操作 ==========

    // 读取原始字节
    void read_raw(void* data, size_t len) {
        check_readable(len);
        std::memcpy(data, data_.data() + read_pos_, len);
        read_pos_ += len;
    }

    // 读取固定长度整数
    template<typename T>
    std::enable_if_t<std::is_integral_v<T>, T>
    read_fixed() {
        T network_value;
        read_raw(&network_value, sizeof(T));
        return network_to_host(network_value);
    }

    // 读取变长整数
    uint64_t read_varint() {
        uint64_t value;
        size_t len = Varint::decode(
            reinterpret_cast<const uint8_t*>(data_.data() + read_pos_),
            value
        );
        read_pos_ += len;
        return value;
    }

    // 读取有符号变长整数
    int64_t read_svarint() {
        return ZigZag::decode(read_varint());
    }

    // 读取字符串
    std::string read_string() {
        uint64_t len = read_varint();
        check_readable(len);
        std::string str(data_.data() + read_pos_, len);
        read_pos_ += len;
        return str;
    }

    // 读取二进制数据
    std::vector<uint8_t> read_bytes() {
        uint64_t len = read_varint();
        check_readable(len);
        std::vector<uint8_t> data(
            data_.begin() + read_pos_,
            data_.begin() + read_pos_ + len
        );
        read_pos_ += len;
        return data;
    }

    // 读取布尔值
    bool read_bool() {
        uint8_t v;
        read_raw(&v, 1);
        return v != 0;
    }

    // 读取浮点数
    float read_float() {
        uint32_t bits = read_fixed<uint32_t>();
        float value;
        std::memcpy(&value, &bits, sizeof(float));
        return value;
    }

    double read_double() {
        uint64_t bits = read_fixed<uint64_t>();
        double value;
        std::memcpy(&bits, &value, sizeof(double));
        return value;
    }

    //========== 缓冲区管理 ==========

    const char* data() const { return data_.data(); }
    char* data() { return data_.data(); }
    size_t size() const { return data_.size(); }
    size_t readable() const { return data_.size() - read_pos_; }
    bool empty() const { return data_.empty(); }

    void clear() {
        data_.clear();
        read_pos_ = 0;
    }

    void reset_read() { read_pos_ = 0; }

    // 设置数据（用于接收）
    void set_data(const char* data, size_t len) {
        data_.assign(data, data + len);
        read_pos_ = 0;
    }

    // 预分配容量
    void reserve(size_t capacity) {
        data_.reserve(capacity);
    }

    // 获取底层数据（移动语义）
    std::vector<char> release() {
        read_pos_ = 0;
        return std::move(data_);
    }

private:
    void check_readable(size_t len) {
        if (read_pos_ + len > data_.size()) {
            throw SerializationError("Buffer underflow");
        }
    }

    std::vector<char> data_;
    size_t read_pos_ = 0;
};

//========== 类型特征 ==========

// 检测是否有serialize/deserialize成员函数
template<typename T, typename = void>
struct has_serialize : std::false_type {};

template<typename T>
struct has_serialize<T, std::void_t<
    decltype(std::declval<T>().serialize(std::declval<Buffer&>()))
>> : std::true_type {};

template<typename T, typename = void>
struct has_deserialize : std::false_type {};

template<typename T>
struct has_deserialize<T, std::void_t<
    decltype(std::declval<T>().deserialize(std::declval<Buffer&>()))
>> : std::true_type {};

//========== 泛型序列化函数 ==========

// 基本类型序列化
template<typename T>
std::enable_if_t<std::is_integral_v<T> && sizeof(T) <= 4>
serialize(Buffer& buf, T value) {
    if constexpr (std::is_signed_v<T>) {
        buf.write_svarint(value);
    } else {
        buf.write_varint(value);
    }
}

template<typename T>
std::enable_if_t<std::is_integral_v<T> && sizeof(T) == 8>
serialize(Buffer& buf, T value) {
    if constexpr (std::is_signed_v<T>) {
        buf.write_svarint(value);
    } else {
        buf.write_varint(value);
    }
}

inline void serialize(Buffer& buf, bool value) {
    buf.write_bool(value);
}

inline void serialize(Buffer& buf, float value) {
    buf.write_float(value);
}

inline void serialize(Buffer& buf, double value) {
    buf.write_double(value);
}

inline void serialize(Buffer& buf, const std::string& value) {
    buf.write_string(value);
}

// vector序列化
template<typename T>
void serialize(Buffer& buf, const std::vector<T>& vec) {
    buf.write_varint(vec.size());
    for (const auto& item : vec) {
        serialize(buf, item);
    }
}

// map序列化
template<typename K, typename V>
void serialize(Buffer& buf, const std::map<K, V>& map) {
    buf.write_varint(map.size());
    for (const auto& [key, value] : map) {
        serialize(buf, key);
        serialize(buf, value);
    }
}

// optional序列化
template<typename T>
void serialize(Buffer& buf, const std::optional<T>& opt) {
    buf.write_bool(opt.has_value());
    if (opt) {
        serialize(buf, *opt);
    }
}

// 自定义类型（有serialize成员函数）
template<typename T>
std::enable_if_t<has_serialize<T>::value>
serialize(Buffer& buf, const T& value) {
    value.serialize(buf);
}

//========== 泛型反序列化函数 ==========

template<typename T>
std::enable_if_t<std::is_integral_v<T> && sizeof(T) <= 4, T>
deserialize(Buffer& buf) {
    if constexpr (std::is_signed_v<T>) {
        return static_cast<T>(buf.read_svarint());
    } else {
        return static_cast<T>(buf.read_varint());
    }
}

template<typename T>
std::enable_if_t<std::is_integral_v<T> && sizeof(T) == 8, T>
deserialize(Buffer& buf) {
    if constexpr (std::is_signed_v<T>) {
        return static_cast<T>(buf.read_svarint());
    } else {
        return static_cast<T>(buf.read_varint());
    }
}

template<>
inline bool deserialize<bool>(Buffer& buf) {
    return buf.read_bool();
}

template<>
inline float deserialize<float>(Buffer& buf) {
    return buf.read_float();
}

template<>
inline double deserialize<double>(Buffer& buf) {
    return buf.read_double();
}

template<>
inline std::string deserialize<std::string>(Buffer& buf) {
    return buf.read_string();
}

// vector反序列化
template<typename T>
std::vector<T> deserialize_vector(Buffer& buf) {
    size_t size = buf.read_varint();
    std::vector<T> vec;
    vec.reserve(size);
    for (size_t i = 0; i < size; ++i) {
        vec.push_back(deserialize<T>(buf));
    }
    return vec;
}

// map反序列化
template<typename K, typename V>
std::map<K, V> deserialize_map(Buffer& buf) {
    size_t size = buf.read_varint();
    std::map<K, V> map;
    for (size_t i = 0; i < size; ++i) {
        K key = deserialize<K>(buf);
        V value = deserialize<V>(buf);
        map.emplace(std::move(key), std::move(value));
    }
    return map;
}

// optional反序列化
template<typename T>
std::optional<T> deserialize_optional(Buffer& buf) {
    if (buf.read_bool()) {
        return deserialize<T>(buf);
    }
    return std::nullopt;
}

// 自定义类型
template<typename T>
std::enable_if_t<has_deserialize<T>::value, T>
deserialize(Buffer& buf) {
    T value;
    value.deserialize(buf);
    return value;
}

} // namespace rpc
```

#### Week 2 检验标准

- [ ] 理解大端序和小端序的区别
- [ ] 能够手算Varint编码结果
- [ ] 理解ZigZag编码为何能优化负数
- [ ] 实现完整的序列化框架
- [ ] 支持基本类型、字符串、容器的序列化
- [ ] 理解Protobuf的wire format
- [ ] 编写序列化性能测试并分析结果

---

### Week 3: RPC客户端架构

#### 学习目标
- 实现生产级的RPC客户端
- 掌握连接管理和连接池
- 实现同步和异步调用模型
- 理解超时、重试、负载均衡

#### 每日任务分解

| Day | 时间 | 上午任务（2.5h） | 下午任务（2.5h） | 输出物 |
|-----|------|------------------|------------------|--------|
| 15 | 5h | TCP连接管理：建立、保活、断线重连 | 实现Connection类 | `rpc_connection.hpp` |
| 16 | 5h | 连接池设计：池化复用、健康检查 | 实现ConnectionPool类 | `connection_pool.hpp` |
| 17 | 5h | 同步调用实现：阻塞等待响应 | 添加超时机制 | `rpc_client.hpp` v1 |
| 18 | 5h | 异步调用实现：Future/Promise模式 | 回调机制实现 | `rpc_client.hpp` v2 |
| 19 | 5h | 负载均衡策略：轮询、随机、加权 | 实现负载均衡器 | `load_balancer.hpp` |
| 20 | 5h | 重试策略：指数退避、熔断 | 实现重试机制 | `retry_policy.hpp` |
| 21 | 5h | 客户端集成测试 | 编写Week3总结 | 测试代码+笔记 |

#### 核心实现

**1. 连接管理**

```cpp
// rpc_connection.hpp
#pragma once
#include "rpc_protocol.hpp"
#include "serialization.hpp"
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <poll.h>
#include <chrono>
#include <atomic>
#include <mutex>

namespace rpc {

// 连接状态
enum class ConnectionState {
    DISCONNECTED,
    CONNECTING,
    CONNECTED,
    CLOSED
};

// 连接配置
struct ConnectionConfig {
    std::string host;
    int port;
    int connect_timeout_ms = 3000;      // 连接超时
    int read_timeout_ms = 5000;         // 读取超时
    int write_timeout_ms = 5000;        // 写入超时
    bool tcp_nodelay = true;            // 禁用Nagle算法
    bool keepalive = true;              // TCP保活
    int keepalive_idle = 60;            // 保活空闲时间（秒）
    int keepalive_interval = 10;        // 保活探测间隔
    int keepalive_count = 3;            // 保活探测次数
};

class Connection {
public:
    explicit Connection(const ConnectionConfig& config)
        : config_(config), state_(ConnectionState::DISCONNECTED) {}

    ~Connection() {
        close();
    }

    // 禁止拷贝
    Connection(const Connection&) = delete;
    Connection& operator=(const Connection&) = delete;

    // 允许移动
    Connection(Connection&& other) noexcept
        : config_(other.config_)
        , fd_(other.fd_)
        , state_(other.state_.load()) {
        other.fd_ = -1;
        other.state_ = ConnectionState::CLOSED;
    }

    bool connect() {
        if (state_ == ConnectionState::CONNECTED) {
            return true;
        }

        state_ = ConnectionState::CONNECTING;

        // 创建socket
        fd_ = socket(AF_INET, SOCK_STREAM, 0);
        if (fd_ < 0) {
            state_ = ConnectionState::DISCONNECTED;
            return false;
        }

        // 设置非阻塞（用于连接超时）
        set_nonblocking(true);

        // 连接
        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_port = htons(config_.port);
        inet_pton(AF_INET, config_.host.c_str(), &addr.sin_addr);

        int ret = ::connect(fd_, reinterpret_cast<sockaddr*>(&addr), sizeof(addr));

        if (ret < 0 && errno != EINPROGRESS) {
            close();
            return false;
        }

        // 等待连接完成
        if (ret < 0) {
            pollfd pfd{fd_, POLLOUT, 0};
            ret = poll(&pfd, 1, config_.connect_timeout_ms);

            if (ret <= 0) {
                close();
                return false;
            }

            // 检查连接是否成功
            int error = 0;
            socklen_t len = sizeof(error);
            getsockopt(fd_, SOL_SOCKET, SO_ERROR, &error, &len);

            if (error != 0) {
                close();
                return false;
            }
        }

        // 恢复阻塞模式
        set_nonblocking(false);

        // 配置socket选项
        configure_socket();

        state_ = ConnectionState::CONNECTED;
        return true;
    }

    void close() {
        if (fd_ >= 0) {
            ::close(fd_);
            fd_ = -1;
        }
        state_ = ConnectionState::CLOSED;
    }

    // 发送消息
    bool send(const MessageHeader& header, const Buffer& body) {
        std::lock_guard<std::mutex> lock(write_mutex_);

        if (state_ != ConnectionState::CONNECTED) {
            return false;
        }

        // 发送header
        char header_buf[MessageHeader::SIZE];
        header.serialize(header_buf);

        if (!send_all(header_buf, MessageHeader::SIZE)) {
            return false;
        }

        // 发送body
        if (body.size() > 0) {
            if (!send_all(body.data(), body.size())) {
                return false;
            }
        }

        return true;
    }

    // 接收消息
    bool recv(MessageHeader& header, Buffer& body) {
        std::lock_guard<std::mutex> lock(read_mutex_);

        if (state_ != ConnectionState::CONNECTED) {
            return false;
        }

        // 接收header
        char header_buf[MessageHeader::SIZE];
        if (!recv_all(header_buf, MessageHeader::SIZE)) {
            return false;
        }

        if (!header.deserialize(header_buf)) {
            return false;
        }

        // 接收body
        if (header.body_length > 0) {
            std::vector<char> buf(header.body_length);
            if (!recv_all(buf.data(), header.body_length)) {
                return false;
            }
            body.set_data(buf.data(), buf.size());
        }

        return true;
    }

    ConnectionState state() const { return state_; }
    bool is_connected() const { return state_ == ConnectionState::CONNECTED; }

    // 获取连接地址信息
    std::string address() const {
        return config_.host + ":" + std::to_string(config_.port);
    }

private:
    void set_nonblocking(bool nonblock) {
        int flags = fcntl(fd_, F_GETFL, 0);
        if (nonblock) {
            fcntl(fd_, F_SETFL, flags | O_NONBLOCK);
        } else {
            fcntl(fd_, F_SETFL, flags & ~O_NONBLOCK);
        }
    }

    void configure_socket() {
        // TCP_NODELAY
        if (config_.tcp_nodelay) {
            int flag = 1;
            setsockopt(fd_, IPPROTO_TCP, TCP_NODELAY, &flag, sizeof(flag));
        }

        // TCP Keepalive
        if (config_.keepalive) {
            int flag = 1;
            setsockopt(fd_, SOL_SOCKET, SO_KEEPALIVE, &flag, sizeof(flag));

            #ifdef __linux__
            setsockopt(fd_, IPPROTO_TCP, TCP_KEEPIDLE,
                      &config_.keepalive_idle, sizeof(int));
            setsockopt(fd_, IPPROTO_TCP, TCP_KEEPINTVL,
                      &config_.keepalive_interval, sizeof(int));
            setsockopt(fd_, IPPROTO_TCP, TCP_KEEPCNT,
                      &config_.keepalive_count, sizeof(int));
            #endif
        }

        // 设置读写超时
        timeval tv;
        tv.tv_sec = config_.read_timeout_ms / 1000;
        tv.tv_usec = (config_.read_timeout_ms % 1000) * 1000;
        setsockopt(fd_, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));

        tv.tv_sec = config_.write_timeout_ms / 1000;
        tv.tv_usec = (config_.write_timeout_ms % 1000) * 1000;
        setsockopt(fd_, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));
    }

    bool send_all(const char* data, size_t len) {
        size_t sent = 0;
        while (sent < len) {
            ssize_t n = ::send(fd_, data + sent, len - sent, MSG_NOSIGNAL);
            if (n <= 0) {
                if (errno == EINTR) continue;
                state_ = ConnectionState::DISCONNECTED;
                return false;
            }
            sent += n;
        }
        return true;
    }

    bool recv_all(char* data, size_t len) {
        size_t received = 0;
        while (received < len) {
            ssize_t n = ::recv(fd_, data + received, len - received, 0);
            if (n <= 0) {
                if (errno == EINTR) continue;
                state_ = ConnectionState::DISCONNECTED;
                return false;
            }
            received += n;
        }
        return true;
    }

private:
    ConnectionConfig config_;
    int fd_ = -1;
    std::atomic<ConnectionState> state_;
    std::mutex read_mutex_;
    std::mutex write_mutex_;
};

} // namespace rpc
```

**2. 连接池**

```cpp
// connection_pool.hpp
#pragma once
#include "rpc_connection.hpp"
#include <queue>
#include <memory>
#include <mutex>
#include <condition_variable>
#include <chrono>

namespace rpc {

struct PoolConfig {
    size_t min_size = 2;           // 最小连接数
    size_t max_size = 10;          // 最大连接数
    int idle_timeout_ms = 60000;   // 空闲超时
    int wait_timeout_ms = 5000;    // 获取连接超时
};

class ConnectionPool {
public:
    ConnectionPool(const ConnectionConfig& conn_config,
                   const PoolConfig& pool_config)
        : conn_config_(conn_config)
        , pool_config_(pool_config) {
        // 初始化最小连接数
        for (size_t i = 0; i < pool_config_.min_size; ++i) {
            auto conn = create_connection();
            if (conn && conn->is_connected()) {
                pool_.push(std::move(conn));
            }
        }
    }

    ~ConnectionPool() {
        shutdown();
    }

    // RAII连接包装器
    class PooledConnection {
    public:
        PooledConnection(ConnectionPool* pool,
                        std::unique_ptr<Connection> conn)
            : pool_(pool), conn_(std::move(conn)) {}

        ~PooledConnection() {
            if (conn_ && pool_) {
                pool_->release(std::move(conn_));
            }
        }

        // 禁止拷贝
        PooledConnection(const PooledConnection&) = delete;
        PooledConnection& operator=(const PooledConnection&) = delete;

        // 允许移动
        PooledConnection(PooledConnection&& other) noexcept
            : pool_(other.pool_), conn_(std::move(other.conn_)) {
            other.pool_ = nullptr;
        }

        Connection* operator->() { return conn_.get(); }
        Connection& operator*() { return *conn_; }
        explicit operator bool() const { return conn_ != nullptr; }

    private:
        ConnectionPool* pool_;
        std::unique_ptr<Connection> conn_;
    };

    // 获取连接
    PooledConnection acquire() {
        std::unique_lock<std::mutex> lock(mutex_);

        // 等待可用连接
        auto deadline = std::chrono::steady_clock::now() +
                       std::chrono::milliseconds(pool_config_.wait_timeout_ms);

        while (pool_.empty() && total_count_ >= pool_config_.max_size) {
            if (cv_.wait_until(lock, deadline) == std::cv_status::timeout) {
                return PooledConnection(nullptr, nullptr);
            }
        }

        std::unique_ptr<Connection> conn;

        if (!pool_.empty()) {
            conn = std::move(pool_.front());
            pool_.pop();

            // 检查连接是否有效
            if (!conn->is_connected()) {
                --total_count_;
                conn = create_connection_locked();
            }
        } else {
            conn = create_connection_locked();
        }

        return PooledConnection(this, std::move(conn));
    }

    // 关闭连接池
    void shutdown() {
        std::lock_guard<std::mutex> lock(mutex_);
        while (!pool_.empty()) {
            pool_.pop();
        }
        total_count_ = 0;
    }

    // 统计信息
    size_t available() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return pool_.size();
    }

    size_t total() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return total_count_;
    }

private:
    std::unique_ptr<Connection> create_connection() {
        auto conn = std::make_unique<Connection>(conn_config_);
        if (conn->connect()) {
            return conn;
        }
        return nullptr;
    }

    std::unique_ptr<Connection> create_connection_locked() {
        auto conn = create_connection();
        if (conn) {
            ++total_count_;
        }
        return conn;
    }

    void release(std::unique_ptr<Connection> conn) {
        std::lock_guard<std::mutex> lock(mutex_);

        if (conn->is_connected() && pool_.size() < pool_config_.max_size) {
            pool_.push(std::move(conn));
            cv_.notify_one();
        } else {
            --total_count_;
        }
    }

private:
    ConnectionConfig conn_config_;
    PoolConfig pool_config_;

    mutable std::mutex mutex_;
    std::condition_variable cv_;
    std::queue<std::unique_ptr<Connection>> pool_;
    size_t total_count_ = 0;
};

} // namespace rpc
```

**3. 完整的RPC客户端**

```cpp
// rpc_client.hpp
#pragma once
#include "rpc_protocol.hpp"
#include "serialization.hpp"
#include "connection_pool.hpp"
#include <future>
#include <functional>
#include <unordered_map>
#include <atomic>

namespace rpc {

// 调用结果
template<typename T>
struct RpcResult {
    ErrorCode error;
    T value;

    bool ok() const { return error == ErrorCode::OK; }

    static RpcResult success(T val) {
        return {ErrorCode::OK, std::move(val)};
    }

    static RpcResult failure(ErrorCode err) {
        return {err, T{}};
    }
};

// 客户端配置
struct ClientConfig {
    std::vector<std::string> addresses;  // 服务地址列表
    int connect_timeout_ms = 3000;
    int request_timeout_ms = 5000;
    int retry_count = 3;
    int retry_delay_ms = 100;
};

class RpcClient {
public:
    explicit RpcClient(const ClientConfig& config)
        : config_(config) {
        // 为每个地址创建连接池
        for (const auto& addr : config.addresses) {
            auto pos = addr.find(':');
            if (pos == std::string::npos) continue;

            ConnectionConfig conn_config;
            conn_config.host = addr.substr(0, pos);
            conn_config.port = std::stoi(addr.substr(pos + 1));
            conn_config.connect_timeout_ms = config.connect_timeout_ms;
            conn_config.read_timeout_ms = config.request_timeout_ms;
            conn_config.write_timeout_ms = config.request_timeout_ms;

            PoolConfig pool_config;
            pools_.push_back(std::make_unique<ConnectionPool>(
                conn_config, pool_config));
        }
    }

    // 同步调用
    template<typename R, typename... Args>
    RpcResult<R> call(const std::string& method, Args&&... args) {
        // 序列化参数
        Buffer request_body;
        serialize_args(request_body, std::forward<Args>(args)...);

        // 重试循环
        for (int i = 0; i <= config_.retry_count; ++i) {
            // 选择连接池（简单轮询）
            auto& pool = pools_[next_pool_++ % pools_.size()];
            auto conn = pool->acquire();

            if (!conn) {
                if (i < config_.retry_count) {
                    std::this_thread::sleep_for(
                        std::chrono::milliseconds(config_.retry_delay_ms * (1 << i)));
                    continue;
                }
                return RpcResult<R>::failure(ErrorCode::CLIENT_CONNECT_FAIL);
            }

            // 构造请求
            MessageHeader header;
            header.magic = RPC_MAGIC;
            header.version = RPC_VERSION;
            header.msg_type = static_cast<uint8_t>(MessageType::REQUEST);
            header.serialization = static_cast<uint8_t>(SerializationType::BINARY);
            header.compression = static_cast<uint8_t>(CompressionType::NONE);
            header.request_id = next_request_id_++;

            // 方法名也需要序列化到body
            Buffer full_body;
            full_body.write_string(method);
            full_body.write_raw(request_body.data(), request_body.size());

            header.body_length = full_body.size();
            header.checksum = 0;  // TODO: 计算CRC32

            // 发送请求
            if (!conn->send(header, full_body)) {
                continue;
            }

            // 接收响应
            MessageHeader resp_header;
            Buffer resp_body;

            if (!conn->recv(resp_header, resp_body)) {
                continue;
            }

            // 检查响应
            if (resp_header.msg_type == static_cast<uint8_t>(MessageType::ERROR)) {
                auto err = static_cast<ErrorCode>(resp_body.read_fixed<int32_t>());
                return RpcResult<R>::failure(err);
            }

            // 反序列化返回值
            R result = deserialize<R>(resp_body);
            return RpcResult<R>::success(std::move(result));
        }

        return RpcResult<R>::failure(ErrorCode::CLIENT_TIMEOUT);
    }

    // 异步调用
    template<typename R, typename... Args>
    std::future<RpcResult<R>> async_call(const std::string& method, Args&&... args) {
        return std::async(std::launch::async, [=, this]() {
            return call<R>(method, args...);
        });
    }

    // 带回调的异步调用
    template<typename R, typename... Args>
    void call_async(const std::string& method,
                    std::function<void(RpcResult<R>)> callback,
                    Args&&... args) {
        std::thread([=, this]() {
            auto result = call<R>(method, args...);
            callback(std::move(result));
        }).detach();
    }

private:
    // 参数序列化辅助
    void serialize_args(Buffer& buf) {}

    template<typename T>
    void serialize_args(Buffer& buf, T&& arg) {
        serialize(buf, std::forward<T>(arg));
    }

    template<typename T, typename... Rest>
    void serialize_args(Buffer& buf, T&& first, Rest&&... rest) {
        serialize(buf, std::forward<T>(first));
        serialize_args(buf, std::forward<Rest>(rest)...);
    }

private:
    ClientConfig config_;
    std::vector<std::unique_ptr<ConnectionPool>> pools_;
    std::atomic<size_t> next_pool_{0};
    std::atomic<uint64_t> next_request_id_{0};
};

} // namespace rpc
```

#### Week 3 检验标准

- [ ] 实现TCP连接管理（建立、保活、断开）
- [ ] 实现连接池（获取、释放、超时）
- [ ] 实现同步RPC调用
- [ ] 实现异步RPC调用（Future和回调两种方式）
- [ ] 实现简单的负载均衡（轮询）
- [ ] 实现重试机制（指数退避）
- [ ] 理解TCP_NODELAY和Keepalive的作用

---

### Week 4: RPC服务端与服务治理

#### 学习目标
- 实现高性能RPC服务端
- 掌握epoll多路复用
- 理解服务注册与发现
- 了解服务治理基本概念

#### 每日任务分解

| Day | 时间 | 上午任务（2.5h） | 下午任务（2.5h） | 输出物 |
|-----|------|------------------|------------------|--------|
| 22 | 5h | epoll原理回顾：ET vs LT模式 | 实现基于epoll的事件循环 | `event_loop.hpp` |
| 23 | 5h | 服务端框架设计：方法注册、派发 | 实现服务端骨架 | `rpc_server.hpp` v1 |
| 24 | 5h | 多线程模型：线程池处理请求 | 实现工作线程池 | `thread_pool.hpp` |
| 25 | 5h | 服务注册中心设计 | 实现内存版服务注册 | `service_registry.hpp` |
| 26 | 5h | 健康检查机制 | 实现心跳和健康检查 | `health_check.hpp` |
| 27 | 5h | 综合示例：实现计算器服务 | 客户端-服务端联调 | `example_service.cpp` |
| 28 | 5h | 本月总复习 | 编写总结笔记 | `notes/month34_rpc.md` |

#### 核心实现

**1. 线程池**

```cpp
// thread_pool.hpp
#pragma once
#include <vector>
#include <queue>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <functional>
#include <future>
#include <atomic>

namespace rpc {

class ThreadPool {
public:
    explicit ThreadPool(size_t num_threads = std::thread::hardware_concurrency())
        : stop_(false) {
        for (size_t i = 0; i < num_threads; ++i) {
            workers_.emplace_back([this] {
                while (true) {
                    std::function<void()> task;

                    {
                        std::unique_lock<std::mutex> lock(mutex_);
                        cv_.wait(lock, [this] {
                            return stop_ || !tasks_.empty();
                        });

                        if (stop_ && tasks_.empty()) {
                            return;
                        }

                        task = std::move(tasks_.front());
                        tasks_.pop();
                    }

                    task();
                }
            });
        }
    }

    ~ThreadPool() {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            stop_ = true;
        }
        cv_.notify_all();

        for (auto& worker : workers_) {
            if (worker.joinable()) {
                worker.join();
            }
        }
    }

    // 提交任务
    template<typename F, typename... Args>
    auto submit(F&& f, Args&&... args)
        -> std::future<std::invoke_result_t<F, Args...>> {
        using return_type = std::invoke_result_t<F, Args...>;

        auto task = std::make_shared<std::packaged_task<return_type()>>(
            std::bind(std::forward<F>(f), std::forward<Args>(args)...)
        );

        std::future<return_type> result = task->get_future();

        {
            std::lock_guard<std::mutex> lock(mutex_);
            if (stop_) {
                throw std::runtime_error("ThreadPool is stopped");
            }
            tasks_.emplace([task]() { (*task)(); });
        }

        cv_.notify_one();
        return result;
    }

    size_t size() const { return workers_.size(); }

    size_t pending() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return tasks_.size();
    }

private:
    std::vector<std::thread> workers_;
    std::queue<std::function<void()>> tasks_;

    mutable std::mutex mutex_;
    std::condition_variable cv_;
    std::atomic<bool> stop_;
};

} // namespace rpc
```

**2. 完整的RPC服务端**

```cpp
// rpc_server.hpp
#pragma once
#include "rpc_protocol.hpp"
#include "serialization.hpp"
#include "thread_pool.hpp"
#include <sys/epoll.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <fcntl.h>
#include <functional>
#include <unordered_map>
#include <memory>
#include <atomic>

namespace rpc {

// 服务端配置
struct ServerConfig {
    int port = 8080;
    int backlog = 128;
    int max_connections = 10000;
    int thread_pool_size = 4;
    int epoll_timeout_ms = 1000;
};

class RpcServer {
public:
    // 方法处理器类型
    using Handler = std::function<Buffer(Buffer&)>;

    explicit RpcServer(const ServerConfig& config = ServerConfig())
        : config_(config)
        , thread_pool_(config.thread_pool_size) {
        epfd_ = epoll_create1(EPOLL_CLOEXEC);
    }

    ~RpcServer() {
        stop();
        if (listen_fd_ >= 0) close(listen_fd_);
        if (epfd_ >= 0) close(epfd_);
    }

    // 注册服务方法
    template<typename R, typename... Args, typename F>
    void register_method(const std::string& name, F&& func) {
        handlers_[name] = [f = std::forward<F>(func)](Buffer& args) -> Buffer {
            // 反序列化参数并调用
            R result = invoke_with_args<R, Args...>(f, args);

            // 序列化返回值
            Buffer response;
            serialize(response, result);
            return response;
        };
    }

    // 启动服务器
    bool start() {
        // 创建监听socket
        listen_fd_ = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK, 0);
        if (listen_fd_ < 0) {
            return false;
        }

        // 设置SO_REUSEADDR
        int opt = 1;
        setsockopt(listen_fd_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

        // 绑定地址
        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = INADDR_ANY;
        addr.sin_port = htons(config_.port);

        if (bind(listen_fd_, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) < 0) {
            return false;
        }

        // 开始监听
        if (listen(listen_fd_, config_.backlog) < 0) {
            return false;
        }

        // 添加到epoll
        epoll_event ev;
        ev.events = EPOLLIN;
        ev.data.fd = listen_fd_;
        epoll_ctl(epfd_, EPOLL_CTL_ADD, listen_fd_, &ev);

        return true;
    }

    // 运行事件循环
    void run() {
        running_ = true;
        std::vector<epoll_event> events(256);

        while (running_) {
            int n = epoll_wait(epfd_, events.data(), events.size(),
                              config_.epoll_timeout_ms);

            for (int i = 0; i < n; ++i) {
                int fd = events[i].data.fd;

                if (fd == listen_fd_) {
                    handle_accept();
                } else if (events[i].events & EPOLLIN) {
                    // 将请求处理提交到线程池
                    thread_pool_.submit([this, fd]() {
                        handle_request(fd);
                    });
                }
            }
        }
    }

    void stop() {
        running_ = false;
    }

    int port() const { return config_.port; }

private:
    void handle_accept() {
        while (true) {
            sockaddr_in client_addr{};
            socklen_t addr_len = sizeof(client_addr);

            int client_fd = accept4(listen_fd_,
                                   reinterpret_cast<sockaddr*>(&client_addr),
                                   &addr_len, SOCK_NONBLOCK);

            if (client_fd < 0) {
                if (errno == EAGAIN || errno == EWOULDBLOCK) {
                    break;
                }
                continue;
            }

            // 添加到epoll
            epoll_event ev;
            ev.events = EPOLLIN | EPOLLET;  // 边缘触发
            ev.data.fd = client_fd;
            epoll_ctl(epfd_, EPOLL_CTL_ADD, client_fd, &ev);
        }
    }

    void handle_request(int fd) {
        // 读取请求头
        char header_buf[MessageHeader::SIZE];
        ssize_t n = recv(fd, header_buf, MessageHeader::SIZE, MSG_WAITALL);

        if (n <= 0) {
            close_client(fd);
            return;
        }

        MessageHeader header;
        if (!header.deserialize(header_buf)) {
            send_error(fd, 0, ErrorCode::PROTOCOL_ERROR);
            return;
        }

        // 读取请求体
        std::vector<char> body_buf(header.body_length);
        n = recv(fd, body_buf.data(), header.body_length, MSG_WAITALL);

        if (n <= 0) {
            close_client(fd);
            return;
        }

        Buffer body;
        body.set_data(body_buf.data(), body_buf.size());

        // 解析方法名
        std::string method = body.read_string();

        // 查找处理器
        auto it = handlers_.find(method);
        if (it == handlers_.end()) {
            send_error(fd, header.request_id, ErrorCode::METHOD_NOT_FOUND);
            return;
        }

        // 执行方法
        try {
            Buffer result = it->second(body);
            send_response(fd, header.request_id, result);
        } catch (const std::exception& e) {
            send_error(fd, header.request_id, ErrorCode::SERVER_ERROR);
        }
    }

    void send_response(int fd, uint64_t request_id, const Buffer& body) {
        MessageHeader header;
        header.magic = RPC_MAGIC;
        header.version = RPC_VERSION;
        header.msg_type = static_cast<uint8_t>(MessageType::RESPONSE);
        header.serialization = static_cast<uint8_t>(SerializationType::BINARY);
        header.compression = static_cast<uint8_t>(CompressionType::NONE);
        header.request_id = request_id;
        header.body_length = body.size();
        header.checksum = 0;

        char header_buf[MessageHeader::SIZE];
        header.serialize(header_buf);

        send(fd, header_buf, MessageHeader::SIZE, MSG_NOSIGNAL);
        if (body.size() > 0) {
            send(fd, body.data(), body.size(), MSG_NOSIGNAL);
        }
    }

    void send_error(int fd, uint64_t request_id, ErrorCode error) {
        Buffer body;
        body.write_fixed(static_cast<int32_t>(error));

        MessageHeader header;
        header.magic = RPC_MAGIC;
        header.version = RPC_VERSION;
        header.msg_type = static_cast<uint8_t>(MessageType::ERROR);
        header.serialization = static_cast<uint8_t>(SerializationType::BINARY);
        header.compression = static_cast<uint8_t>(CompressionType::NONE);
        header.request_id = request_id;
        header.body_length = body.size();
        header.checksum = 0;

        char header_buf[MessageHeader::SIZE];
        header.serialize(header_buf);

        send(fd, header_buf, MessageHeader::SIZE, MSG_NOSIGNAL);
        send(fd, body.data(), body.size(), MSG_NOSIGNAL);
    }

    void close_client(int fd) {
        epoll_ctl(epfd_, EPOLL_CTL_DEL, fd, nullptr);
        close(fd);
    }

    // 参数反序列化并调用函数
    template<typename R, typename... Args, typename F>
    static R invoke_with_args(F&& func, Buffer& buf) {
        return invoke_impl<R>(std::forward<F>(func), buf,
                             std::index_sequence_for<Args...>{},
                             std::type_identity<Args>{}...);
    }

    template<typename R, typename F, size_t... Is, typename... Args>
    static R invoke_impl(F&& func, Buffer& buf,
                        std::index_sequence<Is...>,
                        std::type_identity<Args>...) {
        // 按顺序反序列化参数
        std::tuple<Args...> args{deserialize<Args>(buf)...};
        return func(std::get<Is>(args)...);
    }

private:
    ServerConfig config_;
    int epfd_ = -1;
    int listen_fd_ = -1;
    std::atomic<bool> running_{false};

    std::unordered_map<std::string, Handler> handlers_;
    ThreadPool thread_pool_;
};

} // namespace rpc
```

**3. 服务注册中心**

```cpp
// service_registry.hpp
#pragma once
#include <string>
#include <vector>
#include <unordered_map>
#include <mutex>
#include <chrono>
#include <random>

namespace rpc {

// 服务实例信息
struct ServiceInstance {
    std::string service_name;
    std::string host;
    int port;
    std::unordered_map<std::string, std::string> metadata;

    // 健康状态
    bool healthy = true;
    std::chrono::steady_clock::time_point last_heartbeat;

    std::string address() const {
        return host + ":" + std::to_string(port);
    }
};

// 服务注册中心（内存版）
class ServiceRegistry {
public:
    // 注册服务
    void register_service(const ServiceInstance& instance) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto& instances = services_[instance.service_name];

        // 检查是否已存在
        auto it = std::find_if(instances.begin(), instances.end(),
            [&](const ServiceInstance& i) {
                return i.host == instance.host && i.port == instance.port;
            });

        if (it != instances.end()) {
            *it = instance;
        } else {
            instances.push_back(instance);
        }

        // 更新心跳时间
        instances.back().last_heartbeat = std::chrono::steady_clock::now();
    }

    // 注销服务
    void deregister_service(const std::string& service_name,
                           const std::string& host, int port) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = services_.find(service_name);
        if (it == services_.end()) return;

        auto& instances = it->second;
        instances.erase(
            std::remove_if(instances.begin(), instances.end(),
                [&](const ServiceInstance& i) {
                    return i.host == host && i.port == port;
                }),
            instances.end()
        );
    }

    // 发现服务（返回所有健康实例）
    std::vector<ServiceInstance> discover(const std::string& service_name) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = services_.find(service_name);
        if (it == services_.end()) {
            return {};
        }

        std::vector<ServiceInstance> healthy_instances;
        for (const auto& instance : it->second) {
            if (instance.healthy) {
                healthy_instances.push_back(instance);
            }
        }

        return healthy_instances;
    }

    // 选择一个实例（简单随机负载均衡）
    std::optional<ServiceInstance> select(const std::string& service_name) {
        auto instances = discover(service_name);
        if (instances.empty()) {
            return std::nullopt;
        }

        std::random_device rd;
        std::mt19937 gen(rd());
        std::uniform_int_distribution<> dis(0, instances.size() - 1);

        return instances[dis(gen)];
    }

    // 更新心跳
    void heartbeat(const std::string& service_name,
                  const std::string& host, int port) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = services_.find(service_name);
        if (it == services_.end()) return;

        for (auto& instance : it->second) {
            if (instance.host == host && instance.port == port) {
                instance.last_heartbeat = std::chrono::steady_clock::now();
                instance.healthy = true;
                break;
            }
        }
    }

    // 检查并标记不健康的实例
    void check_health(std::chrono::seconds timeout = std::chrono::seconds(30)) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto now = std::chrono::steady_clock::now();

        for (auto& [name, instances] : services_) {
            for (auto& instance : instances) {
                auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(
                    now - instance.last_heartbeat);

                if (elapsed > timeout) {
                    instance.healthy = false;
                }
            }
        }
    }

    // 获取所有服务
    std::vector<std::string> list_services() {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<std::string> names;
        for (const auto& [name, _] : services_) {
            names.push_back(name);
        }
        return names;
    }

private:
    std::mutex mutex_;
    std::unordered_map<std::string, std::vector<ServiceInstance>> services_;
};

} // namespace rpc
```

**4. 完整示例**

```cpp
// example_service.cpp
#include "rpc_server.hpp"
#include "rpc_client.hpp"
#include "service_registry.hpp"
#include <iostream>
#include <thread>

using namespace rpc;

// 计算器服务
class CalculatorService {
public:
    int add(int a, int b) { return a + b; }
    int subtract(int a, int b) { return a - b; }
    int multiply(int a, int b) { return a * b; }
    double divide(int a, int b) {
        if (b == 0) throw std::invalid_argument("Division by zero");
        return static_cast<double>(a) / b;
    }
};

void run_server() {
    ServerConfig config;
    config.port = 8080;
    config.thread_pool_size = 4;

    RpcServer server(config);
    CalculatorService calc;

    // 注册方法
    server.register_method<int, int, int>("add",
        [&calc](int a, int b) { return calc.add(a, b); });

    server.register_method<int, int, int>("subtract",
        [&calc](int a, int b) { return calc.subtract(a, b); });

    server.register_method<int, int, int>("multiply",
        [&calc](int a, int b) { return calc.multiply(a, b); });

    server.register_method<double, int, int>("divide",
        [&calc](int a, int b) { return calc.divide(a, b); });

    std::cout << "Server starting on port " << config.port << std::endl;

    if (!server.start()) {
        std::cerr << "Failed to start server" << std::endl;
        return;
    }

    server.run();
}

void run_client() {
    // 等待服务器启动
    std::this_thread::sleep_for(std::chrono::seconds(1));

    ClientConfig config;
    config.addresses = {"127.0.0.1:8080"};
    config.request_timeout_ms = 5000;

    RpcClient client(config);

    // 同步调用
    std::cout << "\n=== Synchronous Calls ===" << std::endl;

    auto r1 = client.call<int>("add", 10, 20);
    if (r1.ok()) {
        std::cout << "add(10, 20) = " << r1.value << std::endl;
    }

    auto r2 = client.call<int>("subtract", 100, 30);
    if (r2.ok()) {
        std::cout << "subtract(100, 30) = " << r2.value << std::endl;
    }

    auto r3 = client.call<int>("multiply", 6, 7);
    if (r3.ok()) {
        std::cout << "multiply(6, 7) = " << r3.value << std::endl;
    }

    auto r4 = client.call<double>("divide", 22, 7);
    if (r4.ok()) {
        std::cout << "divide(22, 7) = " << r4.value << std::endl;
    }

    // 异步调用
    std::cout << "\n=== Asynchronous Calls ===" << std::endl;

    auto f1 = client.async_call<int>("add", 1, 2);
    auto f2 = client.async_call<int>("multiply", 3, 4);

    std::cout << "Waiting for async results..." << std::endl;

    auto ar1 = f1.get();
    auto ar2 = f2.get();

    if (ar1.ok()) {
        std::cout << "async add(1, 2) = " << ar1.value << std::endl;
    }
    if (ar2.ok()) {
        std::cout << "async multiply(3, 4) = " << ar2.value << std::endl;
    }

    // 错误处理
    std::cout << "\n=== Error Handling ===" << std::endl;

    auto r5 = client.call<int>("unknown_method", 1, 2);
    if (!r5.ok()) {
        std::cout << "Expected error: " << error_string(r5.error) << std::endl;
    }
}

int main() {
    // 启动服务器线程
    std::thread server_thread(run_server);

    // 运行客户端
    run_client();

    // 等待用户输入后退出
    std::cout << "\nPress Enter to exit..." << std::endl;
    std::cin.get();

    // 注意：实际应用中需要优雅关闭服务器
    server_thread.detach();

    return 0;
}
```

#### Week 4 检验标准

- [ ] 理解epoll的工作原理（LT vs ET）
- [ ] 实现基于epoll的事件循环
- [ ] 实现线程池处理请求
- [ ] 实现服务方法的注册和派发
- [ ] 实现服务注册中心（内存版）
- [ ] 理解服务发现的概念
- [ ] 完成客户端-服务端联调

---

## 源码阅读任务

### 推荐阅读

**gRPC源码（选择性阅读）**：
- `src/core/lib/channel/` - Channel层实现
- `src/core/lib/transport/` - 传输层抽象
- `src/cpp/client/` - C++客户端实现

**Protobuf编码**：
- `src/google/protobuf/wire_format_lite.cc` - Wire Format实现
- `src/google/protobuf/io/coded_stream.cc` - Varint编码

### 阅读笔记模板

```markdown
## [组件名] 源码分析

### 核心数据结构
- 结构体/类定义
- 关键成员变量

### 关键流程
1. 初始化流程
2. 请求处理流程
3. 错误处理流程

### 设计亮点
- 为什么这样设计？
- 有什么权衡？

### 可改进点
- 我会怎么改进？
```

---

## 综合实践项目

### 项目：迷你RPC框架

**要求**：
- [ ] 支持二进制序列化
- [ ] 支持同步和异步调用
- [ ] 连接池管理
- [ ] 服务注册与发现
- [ ] 基本的错误处理
- [ ] 完整的示例服务

**测试用例**：

```cpp
void test_rpc_framework() {
    // 1. 启动服务器
    RpcServer server(8080);
    server.register_method<int, int, int>("add",
        [](int a, int b) { return a + b; });
    std::thread t([&]() { server.start(); server.run(); });

    std::this_thread::sleep_for(std::chrono::milliseconds(100));

    // 2. 客户端调用
    RpcClient client({"127.0.0.1:8080"});

    // 同步调用
    auto result = client.call<int>("add", 1, 2);
    assert(result.ok());
    assert(result.value == 3);

    // 异步调用
    auto future = client.async_call<int>("add", 10, 20);
    auto async_result = future.get();
    assert(async_result.ok());
    assert(async_result.value == 30);

    // 错误处理
    auto error_result = client.call<int>("unknown", 1, 2);
    assert(!error_result.ok());
    assert(error_result.error == ErrorCode::METHOD_NOT_FOUND);

    server.stop();
    t.join();

    std::cout << "All tests passed!" << std::endl;
}
```

---

## 检验标准

- [ ] 理解RPC的核心概念
- [ ] 实现二进制序列化协议
- [ ] 实现RPC客户端Stub
- [ ] 实现RPC服务端Skeleton
- [ ] 理解服务发现的概念
- [ ] 能够对比分析gRPC的设计

### 输出物清单

| 文件 | 说明 |
|------|------|
| `rpc_protocol.hpp` | RPC协议定义 |
| `varint.hpp` | 变长整数编码 |
| `serialization.hpp` | 序列化库 |
| `rpc_connection.hpp` | 连接管理 |
| `connection_pool.hpp` | 连接池 |
| `rpc_client.hpp` | RPC客户端 |
| `thread_pool.hpp` | 线程池 |
| `rpc_server.hpp` | RPC服务端 |
| `service_registry.hpp` | 服务注册中心 |
| `example_service.cpp` | 示例服务 |
| `notes/month34_rpc.md` | 学习笔记 |

---

## 时间分配

| 内容 | 时间 |
|-----|------|
| Week 1: RPC概念与协议设计 | 35小时 |
| Week 2: 序列化协议实现 | 35小时 |
| Week 3: 客户端实现 | 35小时 |
| Week 4: 服务端与服务治理 | 35小时 |
| **总计** | **140小时** |

---

## 扩展阅读

1. **论文**
   - Birrell & Nelson, "Implementing Remote Procedure Calls" (1984)
   - Google, "gRPC: A High Performance, Universal RPC Framework"

2. **书籍**
   - 《分布式系统原理与范型》- RPC章节
   - 《深入理解gRPC》

3. **在线资源**
   - gRPC官方文档: https://grpc.io/docs/
   - Protobuf编码指南: https://developers.google.com/protocol-buffers/docs/encoding

---

## 下月预告

Month 35将学习**协议设计与序列化**，深入研究Protobuf和FlatBuffers的设计原理，并实现一个支持schema evolution的序列化框架。
