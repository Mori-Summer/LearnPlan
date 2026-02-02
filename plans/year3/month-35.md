# Month 35: 协议设计与序列化

## 本月主题概述

高效的序列化是高性能网络应用的基础。本月学习Protobuf和FlatBuffers两种主流序列化框架，理解协议设计的最佳实践，并实现自定义协议层。

**学习目标**：
- 深入理解网络协议设计的核心原则
- 掌握Protobuf的编码原理和高级用法
- 掌握FlatBuffers的零拷贝设计哲学
- 实现支持schema evolution的序列化框架
- 进行序列化框架的性能对比分析

---

## 详细周计划

### Week 1: 网络协议设计原理

#### 学习目标
- 理解协议设计的核心要素
- 掌握消息边界识别技术
- 理解版本兼容性设计
- 实现生产级自定义协议

#### 每日任务分解

| Day | 时间 | 上午任务（2.5h） | 下午任务（2.5h） | 输出物 |
|-----|------|------------------|------------------|--------|
| 1 | 5h | 协议设计历史：从ASCII到二进制协议 | 分析HTTP/1.1、HTTP/2、gRPC协议设计 | `notes/protocol_evolution.md` |
| 2 | 5h | 消息边界识别：定长/分隔符/长度前缀 | 实现三种边界识别器 | `message_framing.hpp` |
| 3 | 5h | TLV编码深入：Type-Length-Value模式 | 实现通用TLV编解码器 | `tlv_codec.hpp` |
| 4 | 5h | 版本兼容性设计：前向/后向兼容 | 设计支持evolution的协议 | `protocol_versioning.hpp` |
| 5 | 5h | 校验和算法：CRC32、Adler32、xxHash | 实现多种校验和支持 | `checksum.hpp` |
| 6 | 5h | 综合设计：实现生产级协议框架 | 完成协议测试用例 | `protocol.hpp` v2 |
| 7 | 5h | 复习与总结 | 编写Week1笔记 | 周总结笔记 |

#### 核心概念深入

**1. 消息边界识别（Message Framing）**

```
消息边界识别的三种方式：

┌─────────────────────────────────────────────────────────────┐
│                    1. 定长消息                               │
├─────────────────────────────────────────────────────────────┤
│  ┌──────┐┌──────┐┌──────┐┌──────┐                          │
│  │ 64B  ││ 64B  ││ 64B  ││ 64B  │  每个消息固定64字节        │
│  └──────┘└──────┘└──────┘└──────┘                          │
│  优点：解析简单，无需状态                                      │
│  缺点：浪费空间，不灵活                                        │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    2. 分隔符                                 │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────┐\r\n┌───────────┐\r\n┌─────┐\r\n               │
│  │ Message1│    │ Message2  │    │ Msg3│                   │
│  └─────────┘    └───────────┘    └─────┘                   │
│  优点：简单，变长支持                                         │
│  缺点：需要转义，不适合二进制                                   │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    3. 长度前缀（推荐）                         │
├─────────────────────────────────────────────────────────────┤
│  ┌────┬────────┐┌────┬──────────────┐┌────┬────┐           │
│  │ 10 │  Data  ││ 20 │    Data      ││  5 │Data│           │
│  └────┴────────┘└────┴──────────────┘└────┴────┘           │
│  优点：高效，支持二进制                                        │
│  缺点：需要预知长度                                           │
└─────────────────────────────────────────────────────────────┘
```

**2. 协议设计最佳实践**

```
协议设计清单：

┌─────────────────────────────────────────────────────────────┐
│ ✓ 魔数（Magic Number）                                       │
│   - 用于快速识别协议类型                                       │
│   - 检测字节流是否对齐                                         │
│   - 典型：4字节，如0x12345678                                 │
├─────────────────────────────────────────────────────────────┤
│ ✓ 版本号（Version）                                          │
│   - 主版本：不兼容的改动                                       │
│   - 次版本：向后兼容的改动                                     │
│   - 预留位：未来扩展                                          │
├─────────────────────────────────────────────────────────────┤
│ ✓ 消息类型（Message Type）                                   │
│   - 请求/响应/通知/心跳                                       │
│   - 预留类型范围给用户扩展                                     │
├─────────────────────────────────────────────────────────────┤
│ ✓ 序列号（Sequence Number）                                  │
│   - 请求-响应匹配                                            │
│   - 检测重复/乱序                                            │
│   - 流量控制                                                 │
├─────────────────────────────────────────────────────────────┤
│ ✓ 长度字段（Length）                                         │
│   - 负载长度 or 总长度                                        │
│   - 考虑最大消息限制                                          │
├─────────────────────────────────────────────────────────────┤
│ ✓ 校验和（Checksum）                                         │
│   - 数据完整性验证                                            │
│   - CRC32/Adler32/xxHash                                    │
├─────────────────────────────────────────────────────────────┤
│ ✓ 扩展字段（Extension）                                      │
│   - 预留空间给未来功能                                        │
│   - 使用TLV格式便于扩展                                       │
└─────────────────────────────────────────────────────────────┘
```

#### 消息分帧实现

```cpp
// message_framing.hpp
#pragma once
#include <vector>
#include <cstdint>
#include <optional>
#include <functional>
#include <deque>

namespace protocol {

// 分帧器接口
class IFramer {
public:
    virtual ~IFramer() = default;

    // 输入数据
    virtual void feed(const uint8_t* data, size_t len) = 0;

    // 尝试提取一个完整消息
    virtual std::optional<std::vector<uint8_t>> extract() = 0;

    // 获取待处理数据大小
    virtual size_t pending() const = 0;

    // 重置状态
    virtual void reset() = 0;
};

// 1. 定长消息分帧器
class FixedLengthFramer : public IFramer {
public:
    explicit FixedLengthFramer(size_t message_size)
        : message_size_(message_size) {}

    void feed(const uint8_t* data, size_t len) override {
        buffer_.insert(buffer_.end(), data, data + len);
    }

    std::optional<std::vector<uint8_t>> extract() override {
        if (buffer_.size() < message_size_) {
            return std::nullopt;
        }

        std::vector<uint8_t> message(buffer_.begin(),
                                     buffer_.begin() + message_size_);
        buffer_.erase(buffer_.begin(), buffer_.begin() + message_size_);
        return message;
    }

    size_t pending() const override { return buffer_.size(); }
    void reset() override { buffer_.clear(); }

private:
    size_t message_size_;
    std::vector<uint8_t> buffer_;
};

// 2. 分隔符分帧器
class DelimiterFramer : public IFramer {
public:
    explicit DelimiterFramer(std::vector<uint8_t> delimiter)
        : delimiter_(std::move(delimiter)) {}

    // 便捷构造：使用字符串作为分隔符
    explicit DelimiterFramer(const std::string& delimiter)
        : delimiter_(delimiter.begin(), delimiter.end()) {}

    void feed(const uint8_t* data, size_t len) override {
        buffer_.insert(buffer_.end(), data, data + len);
    }

    std::optional<std::vector<uint8_t>> extract() override {
        if (buffer_.size() < delimiter_.size()) {
            return std::nullopt;
        }

        // 查找分隔符
        auto it = std::search(buffer_.begin(), buffer_.end(),
                             delimiter_.begin(), delimiter_.end());

        if (it == buffer_.end()) {
            return std::nullopt;
        }

        // 提取消息（不包含分隔符）
        std::vector<uint8_t> message(buffer_.begin(), it);
        buffer_.erase(buffer_.begin(), it + delimiter_.size());
        return message;
    }

    size_t pending() const override { return buffer_.size(); }
    void reset() override { buffer_.clear(); }

private:
    std::vector<uint8_t> delimiter_;
    std::vector<uint8_t> buffer_;
};

// 3. 长度前缀分帧器（推荐）
class LengthPrefixFramer : public IFramer {
public:
    // length_bytes: 长度字段占用的字节数（1/2/4）
    // include_header: 长度是否包含头部本身
    // max_message_size: 最大消息大小限制
    explicit LengthPrefixFramer(
        size_t length_bytes = 4,
        bool include_header = false,
        size_t max_message_size = 16 * 1024 * 1024)  // 16MB
        : length_bytes_(length_bytes)
        , include_header_(include_header)
        , max_message_size_(max_message_size) {}

    void feed(const uint8_t* data, size_t len) override {
        buffer_.insert(buffer_.end(), data, data + len);
    }

    std::optional<std::vector<uint8_t>> extract() override {
        // 检查是否有足够的数据读取长度
        if (buffer_.size() < length_bytes_) {
            return std::nullopt;
        }

        // 读取长度（小端序）
        size_t length = read_length();

        // 计算总消息大小
        size_t total_size = include_header_ ? length : (length_bytes_ + length);

        // 安全检查
        if (length > max_message_size_) {
            throw std::runtime_error("Message too large: " + std::to_string(length));
        }

        // 检查数据是否完整
        if (buffer_.size() < total_size) {
            return std::nullopt;
        }

        // 提取消息体（不包含长度前缀）
        std::vector<uint8_t> message(
            buffer_.begin() + length_bytes_,
            buffer_.begin() + total_size
        );

        buffer_.erase(buffer_.begin(), buffer_.begin() + total_size);
        return message;
    }

    size_t pending() const override { return buffer_.size(); }
    void reset() override { buffer_.clear(); }

    // 编码消息（添加长度前缀）
    static std::vector<uint8_t> encode(const std::vector<uint8_t>& message,
                                       size_t length_bytes = 4) {
        std::vector<uint8_t> result(length_bytes + message.size());

        // 写入长度（小端序）
        size_t len = message.size();
        for (size_t i = 0; i < length_bytes; ++i) {
            result[i] = (len >> (i * 8)) & 0xFF;
        }

        // 复制消息体
        std::copy(message.begin(), message.end(), result.begin() + length_bytes);
        return result;
    }

private:
    size_t read_length() const {
        size_t length = 0;
        for (size_t i = 0; i < length_bytes_; ++i) {
            length |= static_cast<size_t>(buffer_[i]) << (i * 8);
        }
        return length;
    }

    size_t length_bytes_;
    bool include_header_;
    size_t max_message_size_;
    std::vector<uint8_t> buffer_;
};

// 4. 高级分帧器：支持协议头解析
template<typename Header>
class HeaderFramer : public IFramer {
public:
    // 从Header结构中获取负载长度的函数
    using LengthExtractor = std::function<size_t(const Header&)>;
    // 验证Header的函数
    using Validator = std::function<bool(const Header&)>;

    HeaderFramer(LengthExtractor len_fn, Validator valid_fn = nullptr)
        : get_length_(std::move(len_fn))
        , is_valid_(std::move(valid_fn)) {}

    void feed(const uint8_t* data, size_t len) override {
        buffer_.insert(buffer_.end(), data, data + len);
    }

    std::optional<std::vector<uint8_t>> extract() override {
        constexpr size_t header_size = sizeof(Header);

        // 检查头部是否完整
        if (buffer_.size() < header_size) {
            return std::nullopt;
        }

        // 解析头部
        Header header;
        std::memcpy(&header, buffer_.data(), header_size);

        // 验证头部
        if (is_valid_ && !is_valid_(header)) {
            throw std::runtime_error("Invalid message header");
        }

        // 获取负载长度
        size_t payload_length = get_length_(header);
        size_t total_size = header_size + payload_length;

        // 检查完整性
        if (buffer_.size() < total_size) {
            return std::nullopt;
        }

        // 提取完整消息（包含头部）
        std::vector<uint8_t> message(buffer_.begin(),
                                     buffer_.begin() + total_size);
        buffer_.erase(buffer_.begin(), buffer_.begin() + total_size);

        return message;
    }

    size_t pending() const override { return buffer_.size(); }
    void reset() override { buffer_.clear(); }

private:
    LengthExtractor get_length_;
    Validator is_valid_;
    std::vector<uint8_t> buffer_;
};

} // namespace protocol
```

#### TLV编解码器

```cpp
// tlv_codec.hpp
#pragma once
#include <vector>
#include <cstdint>
#include <string>
#include <map>
#include <variant>
#include <optional>

namespace protocol {

/*
 * TLV (Type-Length-Value) 编码格式
 *
 * ┌──────────┬──────────┬─────────────────────┐
 * │  Type    │  Length  │       Value         │
 * │ (varint) │ (varint) │   (Length bytes)    │
 * └──────────┴──────────┴─────────────────────┘
 *
 * 优点：
 * - 可扩展：未知字段可以跳过
 * - 自描述：每个字段都有类型信息
 * - 紧凑：使用varint减少空间
 *
 * 字段类型：
 * - 0: varint (int, bool, enum)
 * - 1: 64-bit (double, fixed64)
 * - 2: length-delimited (string, bytes, embedded)
 * - 5: 32-bit (float, fixed32)
 */

// Wire类型
enum class WireType : uint8_t {
    VARINT = 0,
    FIXED64 = 1,
    LENGTH_DELIMITED = 2,
    FIXED32 = 5
};

// TLV值类型
using TLVValue = std::variant<
    int64_t,                    // VARINT
    double,                     // FIXED64
    float,                      // FIXED32
    std::vector<uint8_t>,       // bytes
    std::string                 // string
>;

class TLVEncoder {
public:
    // 写入varint
    void write_varint(uint64_t value) {
        while (value >= 0x80) {
            buffer_.push_back(static_cast<uint8_t>(value | 0x80));
            value >>= 7;
        }
        buffer_.push_back(static_cast<uint8_t>(value));
    }

    // 写入有符号varint (ZigZag编码)
    void write_svarint(int64_t value) {
        uint64_t encoded = (static_cast<uint64_t>(value) << 1) ^
                          static_cast<uint64_t>(value >> 63);
        write_varint(encoded);
    }

    // 写入字段标签
    void write_tag(uint32_t field_number, WireType wire_type) {
        uint32_t tag = (field_number << 3) | static_cast<uint32_t>(wire_type);
        write_varint(tag);
    }

    // 写入int字段
    void write_int(uint32_t field_number, int64_t value) {
        write_tag(field_number, WireType::VARINT);
        write_svarint(value);
    }

    // 写入uint字段
    void write_uint(uint32_t field_number, uint64_t value) {
        write_tag(field_number, WireType::VARINT);
        write_varint(value);
    }

    // 写入bool字段
    void write_bool(uint32_t field_number, bool value) {
        write_tag(field_number, WireType::VARINT);
        write_varint(value ? 1 : 0);
    }

    // 写入fixed32字段
    void write_fixed32(uint32_t field_number, uint32_t value) {
        write_tag(field_number, WireType::FIXED32);
        for (int i = 0; i < 4; ++i) {
            buffer_.push_back((value >> (i * 8)) & 0xFF);
        }
    }

    // 写入float字段
    void write_float(uint32_t field_number, float value) {
        uint32_t bits;
        std::memcpy(&bits, &value, sizeof(float));
        write_fixed32(field_number, bits);
    }

    // 写入fixed64字段
    void write_fixed64(uint32_t field_number, uint64_t value) {
        write_tag(field_number, WireType::FIXED64);
        for (int i = 0; i < 8; ++i) {
            buffer_.push_back((value >> (i * 8)) & 0xFF);
        }
    }

    // 写入double字段
    void write_double(uint32_t field_number, double value) {
        uint64_t bits;
        std::memcpy(&bits, &value, sizeof(double));
        write_fixed64(field_number, bits);
    }

    // 写入bytes字段
    void write_bytes(uint32_t field_number, const std::vector<uint8_t>& data) {
        write_tag(field_number, WireType::LENGTH_DELIMITED);
        write_varint(data.size());
        buffer_.insert(buffer_.end(), data.begin(), data.end());
    }

    // 写入string字段
    void write_string(uint32_t field_number, const std::string& value) {
        write_tag(field_number, WireType::LENGTH_DELIMITED);
        write_varint(value.size());
        buffer_.insert(buffer_.end(), value.begin(), value.end());
    }

    // 写入嵌套消息
    void write_embedded(uint32_t field_number, const TLVEncoder& embedded) {
        write_tag(field_number, WireType::LENGTH_DELIMITED);
        write_varint(embedded.size());
        buffer_.insert(buffer_.end(), embedded.data(), embedded.data() + embedded.size());
    }

    const uint8_t* data() const { return buffer_.data(); }
    size_t size() const { return buffer_.size(); }

    std::vector<uint8_t> release() {
        return std::move(buffer_);
    }

    void clear() { buffer_.clear(); }

private:
    std::vector<uint8_t> buffer_;
};

class TLVDecoder {
public:
    TLVDecoder(const uint8_t* data, size_t size)
        : data_(data), size_(size), pos_(0) {}

    bool has_more() const { return pos_ < size_; }

    // 读取varint
    uint64_t read_varint() {
        uint64_t value = 0;
        int shift = 0;

        while (pos_ < size_) {
            uint8_t byte = data_[pos_++];
            value |= static_cast<uint64_t>(byte & 0x7F) << shift;
            if ((byte & 0x80) == 0) break;
            shift += 7;
            if (shift >= 64) {
                throw std::runtime_error("Varint too long");
            }
        }
        return value;
    }

    // 读取有符号varint
    int64_t read_svarint() {
        uint64_t n = read_varint();
        return static_cast<int64_t>((n >> 1) ^ (~(n & 1) + 1));
    }

    // 读取字段标签
    std::pair<uint32_t, WireType> read_tag() {
        uint32_t tag = static_cast<uint32_t>(read_varint());
        uint32_t field_number = tag >> 3;
        WireType wire_type = static_cast<WireType>(tag & 0x07);
        return {field_number, wire_type};
    }

    // 读取fixed32
    uint32_t read_fixed32() {
        if (pos_ + 4 > size_) {
            throw std::runtime_error("Buffer underflow");
        }
        uint32_t value = 0;
        for (int i = 0; i < 4; ++i) {
            value |= static_cast<uint32_t>(data_[pos_++]) << (i * 8);
        }
        return value;
    }

    // 读取float
    float read_float() {
        uint32_t bits = read_fixed32();
        float value;
        std::memcpy(&value, &bits, sizeof(float));
        return value;
    }

    // 读取fixed64
    uint64_t read_fixed64() {
        if (pos_ + 8 > size_) {
            throw std::runtime_error("Buffer underflow");
        }
        uint64_t value = 0;
        for (int i = 0; i < 8; ++i) {
            value |= static_cast<uint64_t>(data_[pos_++]) << (i * 8);
        }
        return value;
    }

    // 读取double
    double read_double() {
        uint64_t bits = read_fixed64();
        double value;
        std::memcpy(&value, &bits, sizeof(double));
        return value;
    }

    // 读取bytes
    std::vector<uint8_t> read_bytes() {
        size_t len = read_varint();
        if (pos_ + len > size_) {
            throw std::runtime_error("Buffer underflow");
        }
        std::vector<uint8_t> data(data_ + pos_, data_ + pos_ + len);
        pos_ += len;
        return data;
    }

    // 读取string
    std::string read_string() {
        size_t len = read_varint();
        if (pos_ + len > size_) {
            throw std::runtime_error("Buffer underflow");
        }
        std::string str(reinterpret_cast<const char*>(data_ + pos_), len);
        pos_ += len;
        return str;
    }

    // 跳过当前字段
    void skip_field(WireType wire_type) {
        switch (wire_type) {
            case WireType::VARINT:
                read_varint();
                break;
            case WireType::FIXED64:
                pos_ += 8;
                break;
            case WireType::LENGTH_DELIMITED: {
                size_t len = read_varint();
                pos_ += len;
                break;
            }
            case WireType::FIXED32:
                pos_ += 4;
                break;
            default:
                throw std::runtime_error("Unknown wire type");
        }
    }

    // 读取嵌套消息
    TLVDecoder read_embedded() {
        size_t len = read_varint();
        if (pos_ + len > size_) {
            throw std::runtime_error("Buffer underflow");
        }
        TLVDecoder nested(data_ + pos_, len);
        pos_ += len;
        return nested;
    }

    size_t position() const { return pos_; }
    size_t remaining() const { return size_ - pos_; }

private:
    const uint8_t* data_;
    size_t size_;
    size_t pos_;
};

// 辅助宏：定义可序列化结构体
#define TLV_FIELD(type, name, field_number) \
    type name; \
    static constexpr uint32_t name##_field_number = field_number;

} // namespace protocol
```

#### 完整协议框架

```cpp
// protocol.hpp
#pragma once
#include <cstdint>
#include <vector>
#include <string>
#include <cstring>
#include <arpa/inet.h>
#include <optional>
#include <functional>

namespace protocol {

// CRC32校验和
class CRC32 {
public:
    static uint32_t compute(const void* data, size_t len) {
        static const uint32_t table[256] = {
            // 预计算的CRC32表（IEEE 802.3）
            0x00000000, 0x77073096, 0xee0e612c, 0x990951ba,
            0x076dc419, 0x706af48f, 0xe963a535, 0x9e6495a3,
            // ... (省略完整表)
            0xb40bbe37, 0xc30c8ea1, 0x5a05df1b, 0x2d02ef8d
        };

        uint32_t crc = 0xFFFFFFFF;
        const uint8_t* p = static_cast<const uint8_t*>(data);

        for (size_t i = 0; i < len; ++i) {
            crc = table[(crc ^ p[i]) & 0xFF] ^ (crc >> 8);
        }

        return crc ^ 0xFFFFFFFF;
    }

    // 增量计算
    CRC32() : crc_(0xFFFFFFFF) {}

    void update(const void* data, size_t len) {
        // 增量更新CRC
    }

    uint32_t finalize() const {
        return crc_ ^ 0xFFFFFFFF;
    }

private:
    uint32_t crc_;
};

// 协议版本
struct Version {
    uint8_t major;
    uint8_t minor;

    bool is_compatible(const Version& other) const {
        // 主版本相同则兼容
        return major == other.major;
    }

    static Version current() { return {1, 0}; }
};

// 消息类型
enum class MessageType : uint16_t {
    // 系统消息 (0x0000 - 0x00FF)
    HEARTBEAT       = 0x0001,
    HEARTBEAT_ACK   = 0x0002,
    HANDSHAKE       = 0x0003,
    HANDSHAKE_ACK   = 0x0004,
    DISCONNECT      = 0x0005,

    // 请求-响应 (0x0100 - 0x01FF)
    REQUEST         = 0x0100,
    RESPONSE        = 0x0101,
    ERROR           = 0x0102,

    // 推送消息 (0x0200 - 0x02FF)
    PUSH            = 0x0200,
    BROADCAST       = 0x0201,

    // 用户自定义 (0x1000+)
    USER_DEFINED    = 0x1000
};

// 消息标志
struct MessageFlags {
    uint8_t compressed : 1;      // 是否压缩
    uint8_t encrypted : 1;       // 是否加密
    uint8_t require_ack : 1;     // 是否需要确认
    uint8_t is_fragment : 1;     // 是否是分片
    uint8_t reserved : 4;        // 保留位

    static MessageFlags none() { return {0, 0, 0, 0, 0}; }
};

/*
 * 消息头格式（固定32字节）
 *
 * ┌─────────────────────────────────────────────────────────────┐
 * │ Offset │ Size │ Field          │ Description               │
 * ├────────┼──────┼────────────────┼───────────────────────────┤
 * │   0    │  4   │ Magic          │ 魔数 0x50524F54 ("PROT")   │
 * │   4    │  1   │ Major Version  │ 主版本号                   │
 * │   5    │  1   │ Minor Version  │ 次版本号                   │
 * │   6    │  2   │ Message Type   │ 消息类型                   │
 * │   8    │  4   │ Sequence       │ 序列号                     │
 * │  12    │  4   │ Timestamp      │ 时间戳（秒）                │
 * │  16    │  4   │ Payload Length │ 负载长度                   │
 * │  20    │  4   │ Header CRC     │ 头部CRC32                  │
 * │  24    │  4   │ Payload CRC    │ 负载CRC32                  │
 * │  28    │  1   │ Flags          │ 标志位                     │
 * │  29    │  3   │ Reserved       │ 保留                       │
 * └─────────────────────────────────────────────────────────────┘
 */

#pragma pack(push, 1)
struct MessageHeader {
    uint32_t magic;
    uint8_t  major_version;
    uint8_t  minor_version;
    uint16_t type;
    uint32_t sequence;
    uint32_t timestamp;
    uint32_t payload_length;
    uint32_t header_crc;
    uint32_t payload_crc;
    uint8_t  flags;
    uint8_t  reserved[3];

    static constexpr uint32_t MAGIC = 0x50524F54;  // "PROT"
    static constexpr size_t SIZE = 32;

    // 初始化头部
    void init(MessageType msg_type, uint32_t seq) {
        magic = MAGIC;
        major_version = Version::current().major;
        minor_version = Version::current().minor;
        type = static_cast<uint16_t>(msg_type);
        sequence = seq;
        timestamp = static_cast<uint32_t>(std::time(nullptr));
        payload_length = 0;
        header_crc = 0;
        payload_crc = 0;
        flags = 0;
        std::memset(reserved, 0, sizeof(reserved));
    }

    // 转换为网络字节序
    void to_network() {
        magic = htonl(magic);
        type = htons(type);
        sequence = htonl(sequence);
        timestamp = htonl(timestamp);
        payload_length = htonl(payload_length);
        header_crc = htonl(header_crc);
        payload_crc = htonl(payload_crc);
    }

    // 转换为主机字节序
    void to_host() {
        magic = ntohl(magic);
        type = ntohs(type);
        sequence = ntohl(sequence);
        timestamp = ntohl(timestamp);
        payload_length = ntohl(payload_length);
        header_crc = ntohl(header_crc);
        payload_crc = ntohl(payload_crc);
    }

    // 验证魔数
    bool is_valid() const {
        return magic == MAGIC;
    }

    // 计算并设置头部CRC（计算时header_crc字段为0）
    void compute_header_crc() {
        uint32_t saved = header_crc;
        header_crc = 0;
        header_crc = CRC32::compute(this, SIZE);
        // 如果需要保留原值：header_crc = saved;
    }

    // 验证头部CRC
    bool verify_header_crc() const {
        MessageHeader copy = *this;
        copy.header_crc = 0;
        return CRC32::compute(&copy, SIZE) == header_crc;
    }
};
#pragma pack(pop)

static_assert(sizeof(MessageHeader) == MessageHeader::SIZE,
              "MessageHeader size mismatch");

// 完整消息
class Message {
public:
    MessageHeader header;
    std::vector<uint8_t> payload;

    Message() = default;

    Message(MessageType type, uint32_t sequence) {
        header.init(type, sequence);
    }

    // 设置负载
    void set_payload(const std::vector<uint8_t>& data) {
        payload = data;
        header.payload_length = data.size();
        header.payload_crc = CRC32::compute(data.data(), data.size());
    }

    void set_payload(std::vector<uint8_t>&& data) {
        payload = std::move(data);
        header.payload_length = payload.size();
        header.payload_crc = CRC32::compute(payload.data(), payload.size());
    }

    // 序列化
    std::vector<uint8_t> serialize() const {
        std::vector<uint8_t> buffer(MessageHeader::SIZE + payload.size());

        MessageHeader h = header;
        h.compute_header_crc();
        h.to_network();

        std::memcpy(buffer.data(), &h, MessageHeader::SIZE);
        if (!payload.empty()) {
            std::memcpy(buffer.data() + MessageHeader::SIZE,
                       payload.data(), payload.size());
        }

        return buffer;
    }

    // 反序列化
    enum class ParseResult {
        OK,
        INCOMPLETE,
        INVALID_MAGIC,
        INVALID_VERSION,
        HEADER_CRC_MISMATCH,
        PAYLOAD_CRC_MISMATCH
    };

    static std::pair<ParseResult, std::optional<Message>>
    deserialize(const uint8_t* data, size_t len) {
        // 检查头部完整性
        if (len < MessageHeader::SIZE) {
            return {ParseResult::INCOMPLETE, std::nullopt};
        }

        Message msg;
        std::memcpy(&msg.header, data, MessageHeader::SIZE);
        msg.header.to_host();

        // 验证魔数
        if (!msg.header.is_valid()) {
            return {ParseResult::INVALID_MAGIC, std::nullopt};
        }

        // 验证版本
        Version v{msg.header.major_version, msg.header.minor_version};
        if (!v.is_compatible(Version::current())) {
            return {ParseResult::INVALID_VERSION, std::nullopt};
        }

        // 验证头部CRC
        if (!msg.header.verify_header_crc()) {
            return {ParseResult::HEADER_CRC_MISMATCH, std::nullopt};
        }

        // 检查负载完整性
        size_t total_size = MessageHeader::SIZE + msg.header.payload_length;
        if (len < total_size) {
            return {ParseResult::INCOMPLETE, std::nullopt};
        }

        // 复制负载
        if (msg.header.payload_length > 0) {
            msg.payload.assign(
                data + MessageHeader::SIZE,
                data + total_size
            );

            // 验证负载CRC
            uint32_t crc = CRC32::compute(msg.payload.data(), msg.payload.size());
            if (crc != msg.header.payload_crc) {
                return {ParseResult::PAYLOAD_CRC_MISMATCH, std::nullopt};
            }
        }

        return {ParseResult::OK, std::move(msg)};
    }

    // 消息类型
    MessageType type() const {
        return static_cast<MessageType>(header.type);
    }

    // 获取标志
    MessageFlags flags() const {
        MessageFlags f;
        std::memcpy(&f, &header.flags, sizeof(f));
        return f;
    }

    // 设置标志
    void set_flags(MessageFlags f) {
        std::memcpy(&header.flags, &f, sizeof(f));
    }
};

// 消息构建器
class MessageBuilder {
public:
    MessageBuilder(MessageType type, uint32_t sequence)
        : message_(type, sequence) {}

    MessageBuilder& set_payload(const std::vector<uint8_t>& data) {
        message_.set_payload(data);
        return *this;
    }

    MessageBuilder& set_payload(const std::string& data) {
        message_.set_payload(std::vector<uint8_t>(data.begin(), data.end()));
        return *this;
    }

    MessageBuilder& set_compressed(bool compressed = true) {
        auto flags = message_.flags();
        flags.compressed = compressed ? 1 : 0;
        message_.set_flags(flags);
        return *this;
    }

    MessageBuilder& set_encrypted(bool encrypted = true) {
        auto flags = message_.flags();
        flags.encrypted = encrypted ? 1 : 0;
        message_.set_flags(flags);
        return *this;
    }

    MessageBuilder& require_ack(bool require = true) {
        auto flags = message_.flags();
        flags.require_ack = require ? 1 : 0;
        message_.set_flags(flags);
        return *this;
    }

    Message build() {
        return std::move(message_);
    }

private:
    Message message_;
};

} // namespace protocol
```

#### Week 1 检验标准

- [ ] 理解三种消息边界识别方式的优缺点
- [ ] 能够实现长度前缀分帧器
- [ ] 理解TLV编码格式和varint
- [ ] 设计支持版本兼容的协议格式
- [ ] 实现CRC32校验和
- [ ] 理解大端/小端字节序转换
- [ ] 完成协议头的完整实现

---

### Week 2: Protocol Buffers深入

#### 学习目标
- 深入理解Protobuf的编码原理
- 掌握Protobuf的高级特性
- 理解schema evolution
- 实现Protobuf与RPC集成

#### 每日任务分解

| Day | 时间 | 上午任务（2.5h） | 下午任务（2.5h） | 输出物 |
|-----|------|------------------|------------------|--------|
| 8 | 5h | Protobuf安装与基本使用 | 编写第一个proto文件 | `message.proto` |
| 9 | 5h | Wire Format详解：Varint、Tag、Length | 手动解析protobuf二进制 | `notes/protobuf_wire_format.md` |
| 10 | 5h | 高级类型：oneof、map、any | 实现复杂消息结构 | `advanced.proto` |
| 11 | 5h | Schema Evolution：字段添加/删除/修改 | 版本兼容性测试 | 兼容性测试代码 |
| 12 | 5h | Protobuf反射API | 实现动态消息处理 | `protobuf_reflection.cpp` |
| 13 | 5h | Arena分配器和性能优化 | 性能基准测试 | 性能测试报告 |
| 14 | 5h | 与RPC框架集成 | 完成Week2总结 | `rpc_protobuf.hpp` |

#### 核心概念深入

**1. Protobuf Wire Format详解**

```
Protobuf编码原理：

┌─────────────────────────────────────────────────────────────┐
│                     Varint 编码                              │
├─────────────────────────────────────────────────────────────┤
│ 每个字节的MSB表示是否还有后续字节                               │
│                                                              │
│ 例：编码 300                                                 │
│ 300 = 0b100101100                                           │
│                                                              │
│ 步骤1: 分成7位一组（低位在前）                                 │
│   0101100 (第一组)  0000010 (第二组)                         │
│                                                              │
│ 步骤2: 添加MSB                                               │
│   1_0101100 (还有更多)  0_0000010 (最后一个)                  │
│                                                              │
│ 结果: 0xAC 0x02                                              │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                     字段标签（Tag）                           │
├─────────────────────────────────────────────────────────────┤
│ Tag = (field_number << 3) | wire_type                       │
│                                                              │
│ Wire Types:                                                  │
│   0 - Varint      (int32, int64, uint32, uint64, bool, enum)│
│   1 - 64-bit      (fixed64, sfixed64, double)               │
│   2 - Length-delimited (string, bytes, embedded messages)   │
│   5 - 32-bit      (fixed32, sfixed32, float)                │
│                                                              │
│ 例：field_number=1, wire_type=0 (Varint)                    │
│     Tag = (1 << 3) | 0 = 0x08                               │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                   完整消息编码示例                            │
├─────────────────────────────────────────────────────────────┤
│ message Person {                                             │
│   int32 id = 1;         // field_number=1                   │
│   string name = 2;      // field_number=2                   │
│ }                                                            │
│                                                              │
│ person.id = 150, person.name = "hello"                      │
│                                                              │
│ 编码结果：                                                   │
│ 08 96 01     // id字段: tag(08) + varint(150)               │
│ 12 05 68 65 6c 6c 6f  // name: tag(12) + len(05) + "hello" │
└─────────────────────────────────────────────────────────────┘
```

**2. ZigZag编码（有符号整数优化）**

```
问题：负数的补码表示会导致Varint编码很长
     -1 的补码 = 0xFFFFFFFFFFFFFFFF （64位）
     Varint编码需要10字节！

解决：ZigZag编码将有符号数映射为无符号数

映射表：
┌──────────┬──────────┐
│  原值    │  编码后  │
├──────────┼──────────┤
│    0     │    0     │
│   -1     │    1     │
│    1     │    2     │
│   -2     │    3     │
│    2     │    4     │
│   ...    │   ...    │
└──────────┴──────────┘

编码公式：(n << 1) ^ (n >> 63)  // 64位有符号
解码公式：(n >> 1) ^ -(n & 1)

sint32/sint64 使用ZigZag编码
int32/int64 直接用补码（适合非负数）
```

#### Protobuf消息定义

```protobuf
// message.proto
syntax = "proto3";

package myapp;

option cc_enable_arenas = true;  // 启用Arena分配器

import "google/protobuf/any.proto";
import "google/protobuf/timestamp.proto";

// 用户状态枚举
enum UserStatus {
    USER_STATUS_UNSPECIFIED = 0;
    USER_STATUS_ACTIVE = 1;
    USER_STATUS_INACTIVE = 2;
    USER_STATUS_BANNED = 3;
}

// 地址信息
message Address {
    string street = 1;
    string city = 2;
    string country = 3;
    string postal_code = 4;
}

// 用户信息
message User {
    int64 id = 1;
    string name = 2;
    string email = 3;
    UserStatus status = 4;

    // 嵌套消息
    Address address = 5;

    // repeated字段
    repeated string tags = 6;

    // map字段
    map<string, string> metadata = 7;

    // oneof字段（互斥）
    oneof contact {
        string phone = 8;
        string wechat = 9;
    }

    // 时间戳
    google.protobuf.Timestamp created_at = 10;
    google.protobuf.Timestamp updated_at = 11;

    // Any类型（动态类型）
    google.protobuf.Any extra = 12;

    // 保留字段（已删除的字段号）
    reserved 100, 101;
    reserved "old_field", "deprecated_field";
}

// RPC请求
message Request {
    uint64 request_id = 1;
    string method = 2;
    bytes payload = 3;
    map<string, string> headers = 4;
    int32 timeout_ms = 5;
}

// RPC响应
message Response {
    uint64 request_id = 1;
    int32 code = 2;
    string message = 3;
    bytes data = 4;
}

// 服务定义
service UserService {
    rpc GetUser(GetUserRequest) returns (User);
    rpc ListUsers(ListUsersRequest) returns (ListUsersResponse);
    rpc CreateUser(CreateUserRequest) returns (User);
    rpc UpdateUser(UpdateUserRequest) returns (User);
    rpc DeleteUser(DeleteUserRequest) returns (DeleteUserResponse);
}

message GetUserRequest {
    int64 id = 1;
}

message ListUsersRequest {
    int32 page = 1;
    int32 page_size = 2;
    string filter = 3;
}

message ListUsersResponse {
    repeated User users = 1;
    int32 total = 2;
}

message CreateUserRequest {
    User user = 1;
}

message UpdateUserRequest {
    int64 id = 1;
    User user = 2;
    // 字段掩码：指定要更新的字段
    repeated string update_mask = 3;
}

message DeleteUserRequest {
    int64 id = 1;
}

message DeleteUserResponse {
    bool success = 1;
}
```

#### Protobuf使用和反射

```cpp
// protobuf_usage.cpp
#include "message.pb.h"
#include <google/protobuf/util/json_util.h>
#include <google/protobuf/descriptor.h>
#include <google/protobuf/dynamic_message.h>
#include <google/protobuf/arena.h>
#include <iostream>
#include <fstream>

using namespace google::protobuf;

// 基本使用
void basic_usage() {
    myapp::User user;

    // 设置字段
    user.set_id(1);
    user.set_name("Alice");
    user.set_email("alice@example.com");
    user.set_status(myapp::USER_STATUS_ACTIVE);

    // 设置嵌套消息
    auto* address = user.mutable_address();
    address->set_city("Shanghai");
    address->set_country("China");

    // 添加repeated字段
    user.add_tags("developer");
    user.add_tags("cpp");

    // 设置map字段
    (*user.mutable_metadata())["role"] = "admin";
    (*user.mutable_metadata())["level"] = "10";

    // 设置oneof字段
    user.set_phone("1234567890");

    // 设置时间戳
    auto* created = user.mutable_created_at();
    created->set_seconds(std::time(nullptr));

    // 序列化
    std::string serialized;
    user.SerializeToString(&serialized);
    std::cout << "Serialized size: " << serialized.size() << " bytes\n";

    // 反序列化
    myapp::User parsed;
    parsed.ParseFromString(serialized);

    // 访问字段
    std::cout << "ID: " << parsed.id() << "\n";
    std::cout << "Name: " << parsed.name() << "\n";
    std::cout << "City: " << parsed.address().city() << "\n";

    // 检查oneof
    switch (parsed.contact_case()) {
        case myapp::User::kPhone:
            std::cout << "Phone: " << parsed.phone() << "\n";
            break;
        case myapp::User::kWechat:
            std::cout << "WeChat: " << parsed.wechat() << "\n";
            break;
        default:
            std::cout << "No contact\n";
    }
}

// JSON互转
void json_conversion() {
    myapp::User user;
    user.set_id(1);
    user.set_name("Bob");

    // Protobuf -> JSON
    std::string json;
    util::JsonOptions options;
    options.add_whitespace = true;
    options.preserve_proto_field_names = true;

    util::MessageToJsonString(user, &json, options);
    std::cout << "JSON:\n" << json << "\n";

    // JSON -> Protobuf
    myapp::User from_json;
    util::JsonStringToMessage(json, &from_json);
    std::cout << "From JSON: " << from_json.name() << "\n";
}

// 反射API
void reflection_example() {
    myapp::User user;
    user.set_id(42);
    user.set_name("Charlie");

    // 获取描述符
    const Descriptor* desc = user.GetDescriptor();
    const Reflection* refl = user.GetReflection();

    std::cout << "Message type: " << desc->full_name() << "\n";
    std::cout << "Field count: " << desc->field_count() << "\n";

    // 遍历所有字段
    for (int i = 0; i < desc->field_count(); ++i) {
        const FieldDescriptor* field = desc->field(i);
        std::cout << "Field " << field->number() << ": "
                  << field->name() << " ("
                  << field->type_name() << ")\n";

        // 动态获取值
        if (field->type() == FieldDescriptor::TYPE_INT64) {
            int64_t value = refl->GetInt64(user, field);
            std::cout << "  Value: " << value << "\n";
        } else if (field->type() == FieldDescriptor::TYPE_STRING) {
            std::string value = refl->GetString(user, field);
            if (!value.empty()) {
                std::cout << "  Value: " << value << "\n";
            }
        }
    }

    // 动态设置值
    const FieldDescriptor* name_field = desc->FindFieldByName("name");
    if (name_field) {
        refl->SetString(&user, name_field, "Dynamic Name");
        std::cout << "After dynamic set: " << user.name() << "\n";
    }
}

// 动态消息（无需编译proto）
void dynamic_message_example() {
    // 从proto文件或描述符池创建动态消息
    DescriptorPool pool;
    DynamicMessageFactory factory;

    // 获取User的描述符
    const Descriptor* desc = myapp::User::descriptor();

    // 创建动态消息
    const Message* prototype = factory.GetPrototype(desc);
    std::unique_ptr<Message> dynamic_msg(prototype->New());

    // 使用反射设置字段
    const Reflection* refl = dynamic_msg->GetReflection();
    const FieldDescriptor* id_field = desc->FindFieldByName("id");
    const FieldDescriptor* name_field = desc->FindFieldByName("name");

    refl->SetInt64(dynamic_msg.get(), id_field, 999);
    refl->SetString(dynamic_msg.get(), name_field, "Dynamic User");

    std::cout << "Dynamic message:\n" << dynamic_msg->DebugString();
}

// Arena分配器（减少内存分配）
void arena_example() {
    // 创建Arena
    Arena arena;

    // 在Arena上分配消息
    myapp::User* user = Arena::CreateMessage<myapp::User>(&arena);
    user->set_id(1);
    user->set_name("Arena User");

    // 嵌套消息也在Arena上分配
    myapp::Address* addr = Arena::CreateMessage<myapp::Address>(&arena);
    addr->set_city("Beijing");
    user->set_allocated_address(addr);

    // 序列化
    std::string serialized;
    user->SerializeToString(&serialized);

    // Arena销毁时自动释放所有内存
    // 无需手动delete
}

// 性能测试
void benchmark() {
    const int iterations = 100000;

    myapp::User user;
    user.set_id(12345);
    user.set_name("Benchmark User");
    user.set_email("bench@example.com");
    user.add_tags("tag1");
    user.add_tags("tag2");

    // 序列化基准
    std::string buffer;
    auto start = std::chrono::high_resolution_clock::now();

    for (int i = 0; i < iterations; ++i) {
        user.SerializeToString(&buffer);
    }

    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);

    std::cout << "Serialization: " << iterations << " iterations in "
              << duration.count() << " us\n";
    std::cout << "Per iteration: " << (double)duration.count() / iterations << " us\n";

    // 反序列化基准
    myapp::User parsed;
    start = std::chrono::high_resolution_clock::now();

    for (int i = 0; i < iterations; ++i) {
        parsed.ParseFromString(buffer);
    }

    end = std::chrono::high_resolution_clock::now();
    duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);

    std::cout << "Deserialization: " << iterations << " iterations in "
              << duration.count() << " us\n";
    std::cout << "Per iteration: " << (double)duration.count() / iterations << " us\n";
}

int main() {
    GOOGLE_PROTOBUF_VERIFY_VERSION;

    basic_usage();
    json_conversion();
    reflection_example();
    dynamic_message_example();
    arena_example();
    benchmark();

    google::protobuf::ShutdownProtobufLibrary();
    return 0;
}
```

#### Week 2 检验标准

- [ ] 理解Protobuf的Wire Format编码
- [ ] 能够手动解析Protobuf二进制数据
- [ ] 掌握Varint和ZigZag编码
- [ ] 理解schema evolution的规则
- [ ] 掌握Protobuf反射API
- [ ] 了解Arena分配器的性能优势
- [ ] 完成Protobuf性能基准测试

---

### Week 3: FlatBuffers零拷贝

#### 学习目标
- 理解FlatBuffers的设计哲学
- 掌握零拷贝反序列化
- 对比FlatBuffers与Protobuf
- 实现FlatBuffers与网络层集成

#### 每日任务分解

| Day | 时间 | 上午任务（2.5h） | 下午任务（2.5h） | 输出物 |
|-----|------|------------------|------------------|--------|
| 15 | 5h | FlatBuffers安装与基本概念 | 编写第一个fbs文件 | `message.fbs` |
| 16 | 5h | FlatBuffers内存布局详解 | 手动分析二进制格式 | `notes/flatbuffers_layout.md` |
| 17 | 5h | 构建器API深入：CreateXxx模式 | 实现复杂数据结构 | `advanced.fbs` |
| 18 | 5h | 零拷贝访问：直接读取buffer | 对比传统反序列化 | 性能对比测试 |
| 19 | 5h | FlexBuffers：schema-less变体 | 实现动态类型支持 | `flexbuffers_usage.cpp` |
| 20 | 5h | Object API：可变对象 | 与Protobuf API对比 | 对比分析文档 |
| 21 | 5h | 与网络层集成 | 完成Week3总结 | `flatbuffers_network.hpp` |

#### 核心概念深入

**1. FlatBuffers内存布局**

```
FlatBuffers内存布局（与Protobuf对比）：

┌─────────────────────────────────────────────────────────────┐
│                     Protobuf                                │
├─────────────────────────────────────────────────────────────┤
│ 读取流程：                                                   │
│   Buffer → Parse → Object → Access                          │
│                                                              │
│ 特点：                                                       │
│ - 需要完整解析                                               │
│ - 每个字段都有内存分配                                        │
│ - 解析后可修改                                               │
│ - 解析时间 O(n)                                              │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    FlatBuffers                              │
├─────────────────────────────────────────────────────────────┤
│ 读取流程：                                                   │
│   Buffer → Access（直接访问）                                │
│                                                              │
│ 特点：                                                       │
│ - 零拷贝：直接在buffer上读取                                  │
│ - 无需额外内存分配                                           │
│ - 只读（修改需要Object API）                                 │
│ - 访问时间 O(1)                                              │
└─────────────────────────────────────────────────────────────┘

FlatBuffers二进制格式：

┌─────────────────────────────────────────────────────────────┐
│                    Buffer Layout                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   ┌──────────────┐                                          │
│   │  root_offset │ ← 4字节，指向根表                         │
│   ├──────────────┤                                          │
│   │              │                                          │
│   │  VTable      │ ← 字段偏移表                              │
│   │              │                                          │
│   ├──────────────┤                                          │
│   │              │                                          │
│   │  Table Data  │ ← 实际数据（标量直接存储，引用类型存偏移）  │
│   │              │                                          │
│   ├──────────────┤                                          │
│   │ String/Vector│ ← 字符串和数组数据                        │
│   │    Data      │                                          │
│   └──────────────┘                                          │
│                                                              │
│ VTable格式：                                                 │
│ ┌──────────┬──────────┬──────────┬──────────┬───────┐       │
│ │ vtable_sz│ table_sz │ field0   │ field1   │ ...   │       │
│ │ (2bytes) │ (2bytes) │ offset   │ offset   │       │       │
│ └──────────┴──────────┴──────────┴──────────┴───────┘       │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**2. FlatBuffers vs Protobuf**

```
性能对比：
┌────────────────┬─────────────┬─────────────┐
│     操作        │  Protobuf   │ FlatBuffers │
├────────────────┼─────────────┼─────────────┤
│ 序列化         │    较慢      │    较慢      │
│ 反序列化       │    较慢      │    很快      │
│ 随机字段访问   │    O(1)      │    O(1)      │
│ 遍历所有字段   │    O(n)      │    O(n)      │
│ 编码大小       │    较小      │    稍大      │
│ 内存使用       │    较多      │    很少      │
└────────────────┴─────────────┴─────────────┘

适用场景：
- Protobuf: 通用序列化、网络传输、持久化
- FlatBuffers: 游戏、实时应用、内存映射文件
```

#### FlatBuffers Schema

```
// message.fbs
namespace MyApp;

// 枚举
enum Status : byte { Unknown = 0, Active = 1, Inactive = 2, Banned = 3 }

// 结构体（固定大小，内联存储）
struct Vec3 {
    x: float;
    y: float;
    z: float;
}

struct Color {
    r: ubyte;
    g: ubyte;
    b: ubyte;
    a: ubyte;
}

// 地址表
table Address {
    street: string;
    city: string;
    country: string;
    postal_code: string;
}

// 用户表
table User {
    id: long;
    name: string (required);     // 必填字段
    email: string;
    status: Status = Active;     // 默认值
    address: Address;            // 嵌套表
    tags: [string];              // 字符串数组
    metadata: [KeyValue];        // 键值对数组（模拟map）
    position: Vec3;              // 内联结构体
    avatar_color: Color;
    created_at: long;
    scores: [int];               // 整数数组
}

// 键值对（模拟map）
table KeyValue {
    key: string (key);           // 用于查找
    value: string;
}

// RPC请求
table Request {
    request_id: ulong;
    method: string;
    payload: [ubyte];            // 原始字节
    timeout_ms: int = 5000;
}

// RPC响应
table Response {
    request_id: ulong;
    code: int;
    message: string;
    data: [ubyte];
}

// 用户列表（用于批量操作）
table UserList {
    users: [User];
    total: int;
}

root_type User;

// 文件标识符（可选）
file_identifier "USER";

// 文件扩展名（可选）
file_extension "bin";
```

#### FlatBuffers使用

```cpp
// flatbuffers_usage.cpp
#include "message_generated.h"
#include <flatbuffers/flatbuffers.h>
#include <iostream>
#include <vector>
#include <chrono>

using namespace MyApp;

// 基本使用
void basic_usage() {
    // 创建构建器
    flatbuffers::FlatBufferBuilder builder(1024);

    // 1. 先创建所有嵌套对象（字符串、向量、表）
    auto name = builder.CreateString("Alice");
    auto email = builder.CreateString("alice@example.com");

    // 创建tags数组
    std::vector<flatbuffers::Offset<flatbuffers::String>> tags_vec;
    tags_vec.push_back(builder.CreateString("developer"));
    tags_vec.push_back(builder.CreateString("cpp"));
    auto tags = builder.CreateVector(tags_vec);

    // 创建Address
    auto street = builder.CreateString("123 Main St");
    auto city = builder.CreateString("Shanghai");
    auto country = builder.CreateString("China");
    auto address = CreateAddress(builder, street, city, country);

    // 创建metadata（模拟map）
    std::vector<flatbuffers::Offset<KeyValue>> metadata_vec;
    metadata_vec.push_back(CreateKeyValue(builder,
        builder.CreateString("role"),
        builder.CreateString("admin")));
    metadata_vec.push_back(CreateKeyValue(builder,
        builder.CreateString("level"),
        builder.CreateString("10")));
    auto metadata = builder.CreateVector(metadata_vec);

    // 创建scores数组
    std::vector<int32_t> scores_data = {95, 87, 92, 88};
    auto scores = builder.CreateVector(scores_data);

    // 2. 创建根对象
    // 使用Builder类
    UserBuilder user_builder(builder);
    user_builder.add_id(1);
    user_builder.add_name(name);
    user_builder.add_email(email);
    user_builder.add_status(Status_Active);
    user_builder.add_address(address);
    user_builder.add_tags(tags);
    user_builder.add_metadata(metadata);

    // 内联struct直接设置
    Vec3 position(1.0f, 2.0f, 3.0f);
    user_builder.add_position(&position);

    Color color(255, 128, 64, 255);
    user_builder.add_avatar_color(&color);

    user_builder.add_created_at(std::time(nullptr));
    user_builder.add_scores(scores);

    auto user = user_builder.Finish();

    // 3. 完成构建
    builder.Finish(user);

    // 获取buffer
    uint8_t* buf = builder.GetBufferPointer();
    size_t size = builder.GetSize();

    std::cout << "Serialized size: " << size << " bytes\n";

    // 4. 零拷贝访问（无需反序列化）
    auto parsed = GetUser(buf);

    std::cout << "ID: " << parsed->id() << "\n";
    std::cout << "Name: " << parsed->name()->str() << "\n";
    std::cout << "Email: " << parsed->email()->str() << "\n";
    std::cout << "Status: " << EnumNameStatus(parsed->status()) << "\n";

    // 访问嵌套对象
    if (parsed->address()) {
        std::cout << "City: " << parsed->address()->city()->str() << "\n";
    }

    // 访问数组
    if (parsed->tags()) {
        std::cout << "Tags: ";
        for (auto tag : *parsed->tags()) {
            std::cout << tag->str() << " ";
        }
        std::cout << "\n";
    }

    // 访问struct
    if (parsed->position()) {
        auto pos = parsed->position();
        std::cout << "Position: (" << pos->x() << ", "
                  << pos->y() << ", " << pos->z() << ")\n";
    }

    // 访问metadata（查找）
    if (parsed->metadata()) {
        auto kv = parsed->metadata()->LookupByKey("role");
        if (kv) {
            std::cout << "Role: " << kv->value()->str() << "\n";
        }
    }
}

// 使用CreateXxxDirect简化API
void direct_api() {
    flatbuffers::FlatBufferBuilder builder(1024);

    // CreateXxxDirect自动处理字符串和向量
    std::vector<std::string> tags = {"tag1", "tag2"};
    std::vector<int32_t> scores = {90, 85};

    auto user = CreateUserDirect(builder,
        1,                          // id
        "Bob",                      // name (自动转换为CreateString)
        "bob@example.com",          // email
        Status_Active,              // status
        0,                          // address (null)
        &tags,                      // tags (自动转换为CreateVectorOfStrings)
        nullptr,                    // metadata
        nullptr,                    // position
        nullptr,                    // avatar_color
        std::time(nullptr),         // created_at
        &scores                     // scores (自动转换为CreateVector)
    );

    builder.Finish(user);

    // 验证
    auto parsed = GetUser(builder.GetBufferPointer());
    std::cout << "Direct API - Name: " << parsed->name()->str() << "\n";
}

// Object API（可变对象）
void object_api() {
    // 创建原生C++对象
    UserT user;
    user.id = 1;
    user.name = "Charlie";
    user.email = "charlie@example.com";
    user.status = Status_Active;
    user.tags.push_back("gamer");
    user.scores.push_back(100);

    // 序列化
    flatbuffers::FlatBufferBuilder builder;
    builder.Finish(User::Pack(builder, &user));

    // 反序列化为Object
    auto parsed = GetUser(builder.GetBufferPointer());
    auto unpacked = parsed->UnPack();

    // 修改
    unpacked->name = "Charlie Updated";
    unpacked->scores.push_back(99);

    // 重新序列化
    flatbuffers::FlatBufferBuilder builder2;
    builder2.Finish(User::Pack(builder2, unpacked.get()));

    std::cout << "Object API - Modified name: "
              << GetUser(builder2.GetBufferPointer())->name()->str() << "\n";
}

// Mutable访问（直接修改buffer）
void mutable_access() {
    flatbuffers::FlatBufferBuilder builder(256);

    auto user = CreateUserDirect(builder, 1, "Dave", nullptr, Status_Active);
    builder.Finish(user);

    // 获取可变buffer
    uint8_t* buf = builder.GetBufferPointer();

    // 获取可变访问器
    auto mutable_user = GetMutableUser(buf);

    // 修改标量字段（就地修改）
    mutable_user->mutate_id(999);
    mutable_user->mutate_status(Status_Inactive);

    // 验证修改
    auto parsed = GetUser(buf);
    std::cout << "Mutable - ID: " << parsed->id() << "\n";
    std::cout << "Mutable - Status: " << EnumNameStatus(parsed->status()) << "\n";
}

// 验证buffer
void verification() {
    flatbuffers::FlatBufferBuilder builder(256);
    auto user = CreateUserDirect(builder, 1, "Eve");
    builder.Finish(user);

    uint8_t* buf = builder.GetBufferPointer();
    size_t size = builder.GetSize();

    // 验证buffer完整性
    flatbuffers::Verifier verifier(buf, size);
    if (VerifyUserBuffer(verifier)) {
        std::cout << "Buffer is valid\n";
    } else {
        std::cout << "Buffer is invalid!\n";
    }

    // 篡改buffer测试
    buf[10] = 0xFF;  // 破坏数据
    flatbuffers::Verifier verifier2(buf, size);
    if (!VerifyUserBuffer(verifier2)) {
        std::cout << "Tampering detected!\n";
    }
}

// 性能基准测试
void benchmark() {
    const int iterations = 100000;

    // 准备数据
    std::vector<std::string> tags = {"tag1", "tag2", "tag3"};
    std::vector<int32_t> scores = {95, 87, 92, 88, 90};

    // === FlatBuffers 序列化 ===
    auto start = std::chrono::high_resolution_clock::now();

    flatbuffers::FlatBufferBuilder builder(1024);
    for (int i = 0; i < iterations; ++i) {
        builder.Clear();
        auto user = CreateUserDirect(builder,
            i, "Benchmark User", "bench@test.com",
            Status_Active, 0, &tags, nullptr, nullptr, nullptr,
            std::time(nullptr), &scores);
        builder.Finish(user);
    }

    auto end = std::chrono::high_resolution_clock::now();
    auto serialize_time = std::chrono::duration_cast<std::chrono::microseconds>(end - start);

    std::cout << "FlatBuffers Serialize: " << serialize_time.count() << " us "
              << "(" << (double)serialize_time.count() / iterations << " us/op)\n";

    // === FlatBuffers 访问（零拷贝）===
    uint8_t* buf = builder.GetBufferPointer();

    start = std::chrono::high_resolution_clock::now();

    for (int i = 0; i < iterations; ++i) {
        auto user = GetUser(buf);
        volatile auto id = user->id();
        volatile auto name = user->name()->str();
        (void)id;
        (void)name;
    }

    end = std::chrono::high_resolution_clock::now();
    auto access_time = std::chrono::duration_cast<std::chrono::microseconds>(end - start);

    std::cout << "FlatBuffers Access: " << access_time.count() << " us "
              << "(" << (double)access_time.count() / iterations << " us/op)\n";

    std::cout << "Buffer size: " << builder.GetSize() << " bytes\n";
}

int main() {
    basic_usage();
    direct_api();
    object_api();
    mutable_access();
    verification();
    benchmark();
    return 0;
}
```

#### Week 3 检验标准

- [ ] 理解FlatBuffers的零拷贝设计
- [ ] 掌握FlatBuffers内存布局
- [ ] 能够使用Builder API构建消息
- [ ] 理解VTable的作用
- [ ] 对比FlatBuffers和Protobuf的性能差异
- [ ] 了解FlexBuffers动态类型
- [ ] 完成性能基准测试

---

### Week 4: 序列化层封装与综合项目

#### 学习目标
- 设计统一的序列化抽象层
- 实现多格式消息框架
- 完成序列化性能对比分析
- 构建完整的协议栈

#### 每日任务分解

| Day | 时间 | 上午任务（2.5h） | 下午任务（2.5h） | 输出物 |
|-----|------|------------------|------------------|--------|
| 22 | 5h | 设计序列化接口抽象 | 实现JSON序列化器 | `serializer.hpp` |
| 23 | 5h | 实现Protobuf序列化器 | 实现FlatBuffers序列化器 | `serializer_impl.hpp` |
| 24 | 5h | 消息注册表设计 | 实现消息工厂 | `message_registry.hpp` |
| 25 | 5h | 编解码管道设计 | 实现压缩/加密支持 | `codec_pipeline.hpp` |
| 26 | 5h | 全格式性能对比测试 | 生成性能报告 | `benchmark_report.md` |
| 27 | 5h | 与Month34 RPC框架集成 | 完成联调测试 | `rpc_serialization.hpp` |
| 28 | 5h | 本月总复习 | 编写总结笔记 | `notes/month35_serialization.md` |

#### 统一序列化接口

```cpp
// serializer.hpp
#pragma once
#include <vector>
#include <memory>
#include <string>
#include <typeinfo>
#include <functional>
#include <unordered_map>
#include <optional>

namespace serialization {

// 序列化格式
enum class Format {
    BINARY,         // 自定义二进制
    JSON,           // JSON
    PROTOBUF,       // Protocol Buffers
    FLATBUFFERS,    // FlatBuffers
    MSGPACK         // MessagePack
};

// 序列化选项
struct SerializeOptions {
    bool pretty_print = false;      // JSON美化输出
    bool include_defaults = false;  // 包含默认值字段
    int compression_level = 0;      // 压缩级别（0=不压缩）
};

// 序列化结果
struct SerializeResult {
    std::vector<uint8_t> data;
    bool success = true;
    std::string error;

    static SerializeResult ok(std::vector<uint8_t> d) {
        return {std::move(d), true, ""};
    }

    static SerializeResult fail(const std::string& err) {
        return {{}, false, err};
    }

    explicit operator bool() const { return success; }
};

// 反序列化结果
template<typename T>
struct DeserializeResult {
    std::optional<T> value;
    bool success = true;
    std::string error;

    static DeserializeResult ok(T v) {
        return {std::move(v), true, ""};
    }

    static DeserializeResult fail(const std::string& err) {
        return {std::nullopt, false, err};
    }

    explicit operator bool() const { return success; }
};

// 序列化器基类
class ISerializer {
public:
    virtual ~ISerializer() = default;

    virtual Format format() const = 0;
    virtual std::string format_name() const = 0;

    // 序列化（由派生类实现具体类型）
    virtual SerializeResult serialize_impl(
        const void* obj,
        const std::type_info& type,
        const SerializeOptions& options) = 0;

    // 反序列化
    virtual void* deserialize_impl(
        const uint8_t* data,
        size_t len,
        const std::type_info& type) = 0;

    // 便捷模板接口
    template<typename T>
    SerializeResult serialize(const T& obj,
                             const SerializeOptions& options = {}) {
        return serialize_impl(&obj, typeid(T), options);
    }

    template<typename T>
    DeserializeResult<T> deserialize(const uint8_t* data, size_t len) {
        void* ptr = deserialize_impl(data, len, typeid(T));
        if (!ptr) {
            return DeserializeResult<T>::fail("Deserialization failed");
        }
        T* typed = static_cast<T*>(ptr);
        DeserializeResult<T> result = DeserializeResult<T>::ok(std::move(*typed));
        delete typed;
        return result;
    }

    template<typename T>
    DeserializeResult<T> deserialize(const std::vector<uint8_t>& data) {
        return deserialize<T>(data.data(), data.size());
    }
};

// 序列化器工厂
class SerializerFactory {
public:
    using Creator = std::function<std::unique_ptr<ISerializer>()>;

    static SerializerFactory& instance() {
        static SerializerFactory factory;
        return factory;
    }

    void register_serializer(Format format, Creator creator) {
        creators_[format] = std::move(creator);
    }

    std::unique_ptr<ISerializer> create(Format format) {
        auto it = creators_.find(format);
        if (it != creators_.end()) {
            return it->second();
        }
        return nullptr;
    }

private:
    std::unordered_map<Format, Creator> creators_;
};

// 注册宏
#define REGISTER_SERIALIZER(format, SerializerClass) \
    static bool _registered_##SerializerClass = []() { \
        SerializerFactory::instance().register_serializer(format, []() { \
            return std::make_unique<SerializerClass>(); \
        }); \
        return true; \
    }()

} // namespace serialization
```

#### 消息注册表

```cpp
// message_registry.hpp
#pragma once
#include <memory>
#include <string>
#include <functional>
#include <unordered_map>
#include <typeindex>

namespace serialization {

// 消息接口
class IMessage {
public:
    virtual ~IMessage() = default;

    // 获取消息类型ID
    virtual uint32_t type_id() const = 0;

    // 获取消息类型名
    virtual const char* type_name() const = 0;

    // 克隆
    virtual std::unique_ptr<IMessage> clone() const = 0;
};

// 消息特征
struct MessageTraits {
    uint32_t type_id;
    std::string type_name;
    std::type_index cpp_type;
    std::function<std::unique_ptr<IMessage>()> factory;
};

// 消息注册表
class MessageRegistry {
public:
    static MessageRegistry& instance() {
        static MessageRegistry registry;
        return registry;
    }

    // 注册消息类型
    template<typename T>
    void register_message(uint32_t type_id, const std::string& type_name) {
        static_assert(std::is_base_of_v<IMessage, T>,
                     "T must derive from IMessage");

        MessageTraits traits;
        traits.type_id = type_id;
        traits.type_name = type_name;
        traits.cpp_type = std::type_index(typeid(T));
        traits.factory = []() { return std::make_unique<T>(); };

        by_type_id_[type_id] = traits;
        by_type_name_[type_name] = traits;
        by_cpp_type_[traits.cpp_type] = traits;
    }

    // 创建消息（按类型ID）
    std::unique_ptr<IMessage> create(uint32_t type_id) {
        auto it = by_type_id_.find(type_id);
        if (it != by_type_id_.end()) {
            return it->second.factory();
        }
        return nullptr;
    }

    // 创建消息（按类型名）
    std::unique_ptr<IMessage> create(const std::string& type_name) {
        auto it = by_type_name_.find(type_name);
        if (it != by_type_name_.end()) {
            return it->second.factory();
        }
        return nullptr;
    }

    // 获取类型ID
    template<typename T>
    std::optional<uint32_t> get_type_id() {
        auto it = by_cpp_type_.find(std::type_index(typeid(T)));
        if (it != by_cpp_type_.end()) {
            return it->second.type_id;
        }
        return std::nullopt;
    }

    // 获取类型名
    std::optional<std::string> get_type_name(uint32_t type_id) {
        auto it = by_type_id_.find(type_id);
        if (it != by_type_id_.end()) {
            return it->second.type_name;
        }
        return std::nullopt;
    }

    // 列出所有注册的消息
    std::vector<MessageTraits> list_all() const {
        std::vector<MessageTraits> result;
        for (const auto& [id, traits] : by_type_id_) {
            result.push_back(traits);
        }
        return result;
    }

private:
    std::unordered_map<uint32_t, MessageTraits> by_type_id_;
    std::unordered_map<std::string, MessageTraits> by_type_name_;
    std::unordered_map<std::type_index, MessageTraits> by_cpp_type_;
};

// 注册宏
#define REGISTER_MESSAGE(MessageClass, type_id, type_name) \
    static bool _msg_registered_##MessageClass = []() { \
        MessageRegistry::instance().register_message<MessageClass>(type_id, type_name); \
        return true; \
    }()

} // namespace serialization
```

#### 编解码管道

```cpp
// codec_pipeline.hpp
#pragma once
#include <vector>
#include <memory>
#include <functional>

namespace serialization {

// 编解码阶段
class ICodecStage {
public:
    virtual ~ICodecStage() = default;

    // 编码（序列化方向）
    virtual std::vector<uint8_t> encode(const std::vector<uint8_t>& data) = 0;

    // 解码（反序列化方向）
    virtual std::vector<uint8_t> decode(const std::vector<uint8_t>& data) = 0;

    virtual const char* name() const = 0;
};

// 压缩阶段
class CompressionStage : public ICodecStage {
public:
    enum class Algorithm { NONE, GZIP, LZ4, ZSTD };

    explicit CompressionStage(Algorithm algo = Algorithm::LZ4, int level = 1)
        : algorithm_(algo), level_(level) {}

    std::vector<uint8_t> encode(const std::vector<uint8_t>& data) override {
        switch (algorithm_) {
            case Algorithm::NONE:
                return data;
            case Algorithm::LZ4:
                return compress_lz4(data);
            case Algorithm::GZIP:
                return compress_gzip(data);
            case Algorithm::ZSTD:
                return compress_zstd(data);
        }
        return data;
    }

    std::vector<uint8_t> decode(const std::vector<uint8_t>& data) override {
        switch (algorithm_) {
            case Algorithm::NONE:
                return data;
            case Algorithm::LZ4:
                return decompress_lz4(data);
            case Algorithm::GZIP:
                return decompress_gzip(data);
            case Algorithm::ZSTD:
                return decompress_zstd(data);
        }
        return data;
    }

    const char* name() const override { return "Compression"; }

private:
    std::vector<uint8_t> compress_lz4(const std::vector<uint8_t>& data);
    std::vector<uint8_t> decompress_lz4(const std::vector<uint8_t>& data);
    std::vector<uint8_t> compress_gzip(const std::vector<uint8_t>& data);
    std::vector<uint8_t> decompress_gzip(const std::vector<uint8_t>& data);
    std::vector<uint8_t> compress_zstd(const std::vector<uint8_t>& data);
    std::vector<uint8_t> decompress_zstd(const std::vector<uint8_t>& data);

    Algorithm algorithm_;
    int level_;
};

// 加密阶段
class EncryptionStage : public ICodecStage {
public:
    enum class Algorithm { NONE, AES_128_GCM, AES_256_GCM, CHACHA20_POLY1305 };

    EncryptionStage(Algorithm algo, const std::vector<uint8_t>& key)
        : algorithm_(algo), key_(key) {}

    std::vector<uint8_t> encode(const std::vector<uint8_t>& data) override {
        // 实现加密
        return encrypt(data);
    }

    std::vector<uint8_t> decode(const std::vector<uint8_t>& data) override {
        // 实现解密
        return decrypt(data);
    }

    const char* name() const override { return "Encryption"; }

private:
    std::vector<uint8_t> encrypt(const std::vector<uint8_t>& data);
    std::vector<uint8_t> decrypt(const std::vector<uint8_t>& data);

    Algorithm algorithm_;
    std::vector<uint8_t> key_;
};

// 校验和阶段
class ChecksumStage : public ICodecStage {
public:
    enum class Algorithm { CRC32, ADLER32, XXHASH };

    explicit ChecksumStage(Algorithm algo = Algorithm::CRC32)
        : algorithm_(algo) {}

    std::vector<uint8_t> encode(const std::vector<uint8_t>& data) override {
        // 在数据末尾添加校验和
        std::vector<uint8_t> result = data;
        uint32_t checksum = compute_checksum(data);

        // 追加4字节校验和
        result.push_back((checksum >> 0) & 0xFF);
        result.push_back((checksum >> 8) & 0xFF);
        result.push_back((checksum >> 16) & 0xFF);
        result.push_back((checksum >> 24) & 0xFF);

        return result;
    }

    std::vector<uint8_t> decode(const std::vector<uint8_t>& data) override {
        if (data.size() < 4) {
            throw std::runtime_error("Data too short for checksum");
        }

        // 提取校验和
        uint32_t stored_checksum =
            (data[data.size() - 4] << 0) |
            (data[data.size() - 3] << 8) |
            (data[data.size() - 2] << 16) |
            (data[data.size() - 1] << 24);

        // 计算校验和
        std::vector<uint8_t> payload(data.begin(), data.end() - 4);
        uint32_t computed_checksum = compute_checksum(payload);

        if (stored_checksum != computed_checksum) {
            throw std::runtime_error("Checksum mismatch");
        }

        return payload;
    }

    const char* name() const override { return "Checksum"; }

private:
    uint32_t compute_checksum(const std::vector<uint8_t>& data);

    Algorithm algorithm_;
};

// 编解码管道
class CodecPipeline {
public:
    // 添加阶段
    CodecPipeline& add(std::unique_ptr<ICodecStage> stage) {
        stages_.push_back(std::move(stage));
        return *this;
    }

    // 编码（按添加顺序）
    std::vector<uint8_t> encode(const std::vector<uint8_t>& data) {
        std::vector<uint8_t> result = data;
        for (const auto& stage : stages_) {
            result = stage->encode(result);
        }
        return result;
    }

    // 解码（按逆序）
    std::vector<uint8_t> decode(const std::vector<uint8_t>& data) {
        std::vector<uint8_t> result = data;
        for (auto it = stages_.rbegin(); it != stages_.rend(); ++it) {
            result = (*it)->decode(result);
        }
        return result;
    }

    // 获取阶段列表
    const std::vector<std::unique_ptr<ICodecStage>>& stages() const {
        return stages_;
    }

private:
    std::vector<std::unique_ptr<ICodecStage>> stages_;
};

// 管道构建器
class PipelineBuilder {
public:
    PipelineBuilder& with_checksum(ChecksumStage::Algorithm algo = ChecksumStage::Algorithm::CRC32) {
        pipeline_.add(std::make_unique<ChecksumStage>(algo));
        return *this;
    }

    PipelineBuilder& with_compression(
        CompressionStage::Algorithm algo = CompressionStage::Algorithm::LZ4,
        int level = 1) {
        pipeline_.add(std::make_unique<CompressionStage>(algo, level));
        return *this;
    }

    PipelineBuilder& with_encryption(
        EncryptionStage::Algorithm algo,
        const std::vector<uint8_t>& key) {
        pipeline_.add(std::make_unique<EncryptionStage>(algo, key));
        return *this;
    }

    CodecPipeline build() {
        return std::move(pipeline_);
    }

private:
    CodecPipeline pipeline_;
};

} // namespace serialization
```

#### 综合性能测试

```cpp
// benchmark.cpp
#include <chrono>
#include <iostream>
#include <iomanip>
#include <vector>
#include <string>

// 性能测试结构
struct BenchmarkResult {
    std::string name;
    double serialize_us;      // 序列化耗时（微秒/次）
    double deserialize_us;    // 反序列化耗时（微秒/次）
    size_t serialized_size;   // 序列化后大小
};

// 测试函数模板
template<typename SerializeFunc, typename DeserializeFunc>
BenchmarkResult run_benchmark(
    const std::string& name,
    SerializeFunc serialize,
    DeserializeFunc deserialize,
    int iterations = 100000) {

    BenchmarkResult result;
    result.name = name;

    // 序列化测试
    auto start = std::chrono::high_resolution_clock::now();
    std::vector<uint8_t> serialized;

    for (int i = 0; i < iterations; ++i) {
        serialized = serialize();
    }

    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);
    result.serialize_us = static_cast<double>(duration.count()) / iterations;
    result.serialized_size = serialized.size();

    // 反序列化测试
    start = std::chrono::high_resolution_clock::now();

    for (int i = 0; i < iterations; ++i) {
        deserialize(serialized);
    }

    end = std::chrono::high_resolution_clock::now();
    duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);
    result.deserialize_us = static_cast<double>(duration.count()) / iterations;

    return result;
}

// 打印结果表格
void print_results(const std::vector<BenchmarkResult>& results) {
    std::cout << "\n";
    std::cout << std::setw(20) << "Format"
              << std::setw(15) << "Serialize"
              << std::setw(15) << "Deserialize"
              << std::setw(12) << "Size"
              << std::setw(15) << "Total"
              << "\n";
    std::cout << std::string(77, '-') << "\n";

    for (const auto& r : results) {
        std::cout << std::setw(20) << r.name
                  << std::setw(12) << std::fixed << std::setprecision(3)
                  << r.serialize_us << " us"
                  << std::setw(12) << r.deserialize_us << " us"
                  << std::setw(10) << r.serialized_size << " B"
                  << std::setw(12) << (r.serialize_us + r.deserialize_us) << " us"
                  << "\n";
    }

    std::cout << "\n";
}

/*
 * 预期输出示例：
 *
 *              Format    Serialize  Deserialize        Size         Total
 * ---------------------------------------------------------------------------
 *              Binary       0.150 us      0.120 us      128 B       0.270 us
 *                JSON       2.500 us      3.200 us      256 B       5.700 us
 *            Protobuf       0.450 us      0.380 us       96 B       0.830 us
 *         FlatBuffers       0.600 us      0.050 us      144 B       0.650 us
 *             MsgPack       0.350 us      0.300 us      112 B       0.650 us
 *
 * 分析：
 * - FlatBuffers反序列化最快（零拷贝）
 * - Protobuf体积最小
 * - JSON最慢但可读
 * - 自定义Binary有竞争力
 */
```

#### Week 4 检验标准

- [ ] 设计统一的序列化接口
- [ ] 实现多格式序列化器（JSON/Protobuf/FlatBuffers）
- [ ] 实现消息注册表和工厂
- [ ] 设计编解码管道（压缩、加密、校验）
- [ ] 完成全格式性能对比测试
- [ ] 与RPC框架成功集成
- [ ] 编写完整的对比分析报告

---

## 源码阅读任务

### 推荐阅读

**Protobuf源码**：
- `src/google/protobuf/wire_format_lite.cc` - 核心编码实现
- `src/google/protobuf/io/coded_stream.cc` - 流式编解码
- `src/google/protobuf/descriptor.cc` - 描述符系统
- `src/google/protobuf/arena.cc` - Arena分配器

**FlatBuffers源码**：
- `include/flatbuffers/flatbuffers.h` - 核心实现
- `src/idl_gen_cpp.cpp` - C++代码生成器
- `src/flatc.cpp` - 编译器入口

### 阅读笔记模板

```markdown
## [库名] 源码分析

### 核心数据结构
- 主要类/结构体
- 内存布局

### 编码流程
1. 输入处理
2. 核心编码逻辑
3. 输出生成

### 设计亮点
- 性能优化技巧
- 内存管理策略
- 版本兼容处理

### 与自己实现的对比
- 差异点
- 可借鉴的设计
```

---

## 综合实践项目

### 项目：多格式消息框架

**要求**：
- [ ] 支持至少3种序列化格式
- [ ] 统一的消息接口
- [ ] 自动消息注册
- [ ] 编解码管道（压缩/加密）
- [ ] 完整的性能测试套件
- [ ] 与RPC框架集成

**测试用例**：

```cpp
void test_message_framework() {
    // 1. 注册消息类型
    REGISTER_MESSAGE(UserMessage, 1001, "myapp.User");
    REGISTER_MESSAGE(RequestMessage, 1002, "myapp.Request");

    // 2. 创建序列化器
    auto json = SerializerFactory::instance().create(Format::JSON);
    auto protobuf = SerializerFactory::instance().create(Format::PROTOBUF);
    auto flatbuf = SerializerFactory::instance().create(Format::FLATBUFFERS);

    // 3. 构建管道
    auto pipeline = PipelineBuilder()
        .with_checksum()
        .with_compression(CompressionStage::Algorithm::LZ4)
        .build();

    // 4. 序列化测试
    UserMessage user;
    user.set_id(1);
    user.set_name("Test User");

    auto json_data = json->serialize(user);
    assert(json_data.success);

    auto compressed = pipeline.encode(json_data.data);
    auto decompressed = pipeline.decode(compressed);

    auto parsed = json->deserialize<UserMessage>(decompressed);
    assert(parsed.success);
    assert(parsed.value->name() == "Test User");

    // 5. 格式切换测试
    auto proto_data = protobuf->serialize(user);
    auto flat_data = flatbuf->serialize(user);

    // 比较大小
    std::cout << "JSON size: " << json_data.data.size() << "\n";
    std::cout << "Protobuf size: " << proto_data.data.size() << "\n";
    std::cout << "FlatBuffers size: " << flat_data.data.size() << "\n";

    std::cout << "All tests passed!\n";
}
```

---

## 检验标准

- [ ] 理解协议设计的核心要素
- [ ] 掌握Protobuf的使用和编码原理
- [ ] 掌握FlatBuffers的使用和内存布局
- [ ] 理解两者的优缺点和适用场景
- [ ] 实现通用序列化层封装
- [ ] 完成性能对比分析

### 输出物清单

| 文件 | 说明 |
|------|------|
| `message_framing.hpp` | 消息分帧器 |
| `tlv_codec.hpp` | TLV编解码器 |
| `protocol.hpp` | 完整协议框架 |
| `message.proto` | Protobuf消息定义 |
| `message.fbs` | FlatBuffers消息定义 |
| `serializer.hpp` | 序列化接口 |
| `message_registry.hpp` | 消息注册表 |
| `codec_pipeline.hpp` | 编解码管道 |
| `benchmark.cpp` | 性能测试 |
| `benchmark_report.md` | 性能报告 |
| `notes/month35_serialization.md` | 学习笔记 |

---

## 时间分配

| 内容 | 时间 |
|-----|------|
| Week 1: 协议设计原理 | 35小时 |
| Week 2: Protobuf深入 | 35小时 |
| Week 3: FlatBuffers零拷贝 | 35小时 |
| Week 4: 封装与综合项目 | 35小时 |
| **总计** | **140小时** |

---

## 扩展阅读

1. **论文**
   - "Protocol Buffers: A High Performance, Compact Binary Serialization Format"
   - "FlatBuffers: Memory Efficient Serialization Library"

2. **书籍**
   - 《高性能网络编程》- 序列化章节
   - 《分布式系统设计》- 协议设计

3. **在线资源**
   - Protobuf文档: https://developers.google.com/protocol-buffers
   - FlatBuffers文档: https://google.github.io/flatbuffers/
   - Cap'n Proto: https://capnproto.org/

---

## 下月预告

Month 36将进行**第三年总结与综合项目**，整合所学知识构建完整的高性能网络库，包括：
- 完整的协议栈
- 高性能RPC框架
- 服务治理组件
- 性能测试与优化
