# Month 33: 高性能HTTP服务器实现

> **主题**：高性能HTTP服务器实现——从协议解析到生产级服务器
> **前置知识**：Month-30 Reactor模式、Month-31 Proactor模式、Month-32 Envoy架构
> **学习时长**：140小时（4周 × 35小时）
> **难度评级**：★★★★★

---

## 本月导航

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Month-33 学习路线图                                       │
│                    高性能HTTP服务器实现                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   第一周                第二周                第三周               第四周    │
│   ┌─────────┐         ┌─────────┐          ┌─────────┐         ┌────────┐ │
│   │  HTTP   │         │ 连接管理 │          │ 文件服务 │         │ 完整   │ │
│   │ 协议与  │────────▶│   与    │─────────▶│   与    │────────▶│ 服务器 │ │
│   │ 解析器  │         │ I/O优化 │          │ 中间件  │         │ 与优化 │ │
│   └─────────┘         └─────────┘          └─────────┘         └────────┘ │
│       │                   │                    │                   │       │
│       ▼                   ▼                    ▼                   ▼       │
│   状态机解析器        零拷贝I/O            LRU缓存            HTTP/2基础  │
│   URL编解码           多线程模型           中间件链            性能优化    │
│   响应构建器          连接管理             Trie路由            Mini-HTTP   │
│                                                                             │
│   知识脉络：                                                                 │
│   Month-30(Reactor/epoll) → Month-31(Proactor/io_uring)                    │
│          → Month-32(Envoy架构) → Month-33(HTTP服务器实战)                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 本月主题概述

### 为什么要实现HTTP服务器？

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    HTTP服务器的核心价值                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  HTTP是互联网的基石协议，几乎所有Web服务都建立在HTTP之上。                    │
│  实现一个高性能HTTP服务器是检验网络编程能力的最佳实践项目。                   │
│                                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                  │
│  │   Nginx      │    │    Apache    │    │   Envoy      │                  │
│  │ 1000万+网站  │    │  3亿+网站    │    │ 云原生标配   │                  │
│  │   使用       │    │   曾使用     │    │   使用       │                  │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘                  │
│         │                   │                   │                          │
│         └───────────────────┼───────────────────┘                          │
│                             │                                              │
│                             ▼                                              │
│              ┌──────────────────────────────┐                              │
│              │  HTTP服务器核心能力            │                              │
│              ├──────────────────────────────┤                              │
│              │ • 协议解析（高效状态机）       │                              │
│              │ • 连接管理（Keep-Alive/复用）  │                              │
│              │ • I/O优化（零拷贝/缓冲管理）  │                              │
│              │ • 路由分发（Trie树匹配）      │                              │
│              │ • 中间件（Filter链）          │                              │
│              │ • 静态文件（缓存/压缩）       │                              │
│              │ • 并发模型（多线程/事件驱动）  │                              │
│              └──────────────────────────────┘                              │
│                                                                             │
│  本月目标：从零实现一个具备以上所有能力的Mini-HTTP服务器                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 与前三个月的衔接

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    知识脉络：从I/O到HTTP                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Month-30                Month-31               Month-32                  │
│   Reactor模式             Proactor模式            Envoy架构                 │
│   ┌─────────────┐        ┌─────────────┐        ┌─────────────┐           │
│   │ • epoll     │        │ • io_uring  │        │ • 线程模型  │           │
│   │ • 事件循环  │        │ • 异步I/O   │        │ • Filter链  │           │
│   │ • 非阻塞I/O │        │ • 完成通知  │        │ • 配置管理  │           │
│   │ • 多路复用  │        │ • 零拷贝    │        │ • 连接池    │           │
│   └──────┬──────┘        └──────┬──────┘        └──────┬──────┘           │
│          │                      │                      │                   │
│          └──────────────────────┼──────────────────────┘                   │
│                                 │                                          │
│                                 ▼                                          │
│                  ┌──────────────────────────────┐                          │
│                  │      Month-33                 │                          │
│                  │  高性能HTTP服务器实现          │                          │
│                  ├──────────────────────────────┤                          │
│                  │ 复用Reactor的epoll事件循环    │  ◀── Month-30           │
│                  │ 借鉴Proactor的零拷贝技术      │  ◀── Month-31           │
│                  │ 采用Envoy的线程模型与Filter链 │  ◀── Month-32           │
│                  │ 加入HTTP协议特有的处理逻辑    │  ◀── 本月新增           │
│                  └──────────────────────────────┘                          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 知识体系总览

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    HTTP服务器知识体系                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│                       高性能HTTP服务器                                       │
│                            │                                               │
│          ┌─────────────────┼─────────────────┐                             │
│          │                 │                 │                             │
│          ▼                 ▼                 ▼                             │
│    ┌──────────┐     ┌──────────┐     ┌──────────┐                         │
│    │ 协议层   │     │ 传输层   │     │ 应用层   │                         │
│    ├──────────┤     ├──────────┤     ├──────────┤                         │
│    │HTTP/1.1  │     │连接管理  │     │路由系统  │                         │
│    │请求解析  │     │缓冲区   │     │中间件   │                         │
│    │响应构建  │     │零拷贝   │     │文件服务  │                         │
│    │URL解析   │     │多线程   │     │压缩/缓存 │                         │
│    │Chunked   │     │sendfile │     │HTTP/2   │                         │
│    └──────────┘     └──────────┘     └──────────┘                         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 本月学习目标

### 理论目标

| 序号 | 目标 | 说明 |
|------|------|------|
| T1 | 掌握HTTP/1.1协议细节 | 请求行、头部、Keep-Alive、Pipeline |
| T2 | 理解Chunked传输编码 | 分块传输的格式和应用场景 |
| T3 | 理解HTTP解析器设计 | 状态机驱动、零拷贝技术 |
| T4 | 掌握连接管理策略 | 生命周期、超时、复用 |
| T5 | 理解零拷贝I/O技术 | sendfile、mmap、writev |
| T6 | 理解中间件模式 | Filter链、责任链模式 |
| T7 | 掌握路由匹配算法 | Trie树、路径参数、正则 |
| T8 | 了解HTTP/2基础 | 帧协议、多路复用、HPACK |

### 实践目标

| 序号 | 目标 | 说明 |
|------|------|------|
| P1 | 实现HTTP解析器 | 零拷贝状态机解析器 |
| P2 | 实现URL解析器 | 编解码、查询字符串 |
| P3 | 实现响应构建器 | 支持Chunked编码 |
| P4 | 实现连接管理器 | Keep-Alive超时管理 |
| P5 | 实现零拷贝文件传输 | sendfile/mmap |
| P6 | 实现中间件框架 | 日志/CORS/限流 |
| P7 | 实现Trie路由器 | 路径参数提取 |
| P8 | 组装完整HTTP服务器 | Mini-HTTP Server |

---

## 第一周：HTTP协议深入与高性能解析器（Day 1-7）

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    第一周学习路线图                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Day 1-2              Day 3-4              Day 5-7                        │
│   ┌─────────┐         ┌─────────┐          ┌─────────┐                     │
│   │  HTTP   │         │ 解析器  │          │  URL    │                     │
│   │ 协议    │────────▶│  设计   │─────────▶│ 解析与  │                     │
│   │ 深入    │         │  实现   │          │ 响应    │                     │
│   └─────────┘         └─────────┘          └─────────┘                     │
│       │                   │                    │                           │
│       ▼                   ▼                    ▼                           │
│   Keep-Alive          状态机解析          URL编解码                         │
│   Pipeline            零拷贝技术          MIME类型                          │
│   Chunked             性能对比            路径安全                          │
│                                                                             │
│   学习目标：深入理解HTTP协议，实现高性能解析器                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Day 1-2：HTTP/1.1协议深入（10小时）

#### HTTP请求/响应完整生命周期

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    HTTP请求完整生命周期                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Client                                              Server               │
│     │                                                    │                 │
│     │──── TCP三次握手 ──────────────────────────────────▶│                 │
│     │◀────────────────────────────────────── SYN+ACK ────│                 │
│     │──── ACK ──────────────────────────────────────────▶│                 │
│     │                                                    │                 │
│     │──── GET /index.html HTTP/1.1\r\n ────────────────▶│                 │
│     │     Host: example.com\r\n                          │                 │
│     │     Connection: keep-alive\r\n                     │                 │
│     │     \r\n                                           │                 │
│     │                                                    │ 解析请求         │
│     │                                                    │ 查找路由         │
│     │                                                    │ 执行Handler      │
│     │◀─── HTTP/1.1 200 OK\r\n ──────────────────────────│                 │
│     │     Content-Type: text/html\r\n                    │                 │
│     │     Content-Length: 1234\r\n                       │                 │
│     │     Connection: keep-alive\r\n                     │                 │
│     │     \r\n                                           │                 │
│     │     <html>...</html>                               │                 │
│     │                                                    │                 │
│     │──── 第二个请求（Keep-Alive复用）────────────────▶│                 │
│     │     GET /style.css HTTP/1.1\r\n                   │                 │
│     │     ...                                            │                 │
│     │                                                    │                 │
│     │◀─── 第二个响应 ──────────────────────────────────│                 │
│     │                                                    │                 │
│     │──── Connection: close ──────────────────────────▶│                 │
│     │◀─── FIN ──────────────────────────────────────────│                 │
│     │──── ACK + FIN ────────────────────────────────────▶│                 │
│     │                                                    │                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Keep-Alive与Pipeline机制

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Keep-Alive vs Pipeline                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  无Keep-Alive（HTTP/1.0默认）:                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ 请求1──▶ 响应1  [关闭]  请求2──▶ 响应2  [关闭]  请求3──▶ 响应3     │  │
│  │  ├─TCP握手─┤             ├─TCP握手─┤             ├─TCP握手─┤         │  │
│  │  延迟：3 × (RTT_握手 + RTT_请求)                                    │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  Keep-Alive（HTTP/1.1默认）:                                                │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ ├─TCP握手─┤                                                         │  │
│  │ 请求1──▶ 响应1 │ 请求2──▶ 响应2 │ 请求3──▶ 响应3  [关闭]           │  │
│  │ 延迟：RTT_握手 + 3 × RTT_请求                                      │  │
│  │ 优势：复用TCP连接，省去重复握手开销                                  │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  Pipeline（HTTP/1.1可选）:                                                   │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ ├─TCP握手─┤                                                         │  │
│  │ 请求1──▶ 请求2──▶ 请求3──▶ │ 响应1──▶ 响应2──▶ 响应3  [关闭]       │  │
│  │ 延迟：RTT_握手 + RTT_请求 + 处理时间                                │  │
│  │ 限制：响应必须按请求顺序返回（Head-of-Line Blocking）               │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  HTTP/2多路复用:                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ ├─TCP握手─┤                                                         │  │
│  │ Stream1──▶  Stream2──▶  Stream3──▶                                  │  │
│  │ ◀──Stream2  ◀──Stream1  ◀──Stream3（乱序返回）                      │  │
│  │ 优势：无Head-of-Line Blocking，真正并行                              │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Chunked Transfer Encoding

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Chunked Transfer Encoding                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  用途：在不知道响应体总长度时，分块发送数据                                   │
│                                                                             │
│  普通传输（Content-Length已知）:                                             │
│  ┌──────────────────────────────────────────────┐                          │
│  │ HTTP/1.1 200 OK\r\n                          │                          │
│  │ Content-Length: 13\r\n                        │                          │
│  │ \r\n                                         │                          │
│  │ Hello, World!                                 │                          │
│  └──────────────────────────────────────────────┘                          │
│                                                                             │
│  Chunked传输（流式发送）:                                                    │
│  ┌──────────────────────────────────────────────┐                          │
│  │ HTTP/1.1 200 OK\r\n                          │                          │
│  │ Transfer-Encoding: chunked\r\n               │                          │
│  │ \r\n                                         │                          │
│  │ 7\r\n                                        │ ← chunk-size (十六进制)  │
│  │ Hello, \r\n                                  │ ← chunk-data             │
│  │ 6\r\n                                        │ ← chunk-size             │
│  │ World!\r\n                                   │ ← chunk-data             │
│  │ 0\r\n                                        │ ← 终止块 (size=0)        │
│  │ \r\n                                         │ ← 结束                   │
│  └──────────────────────────────────────────────┘                          │
│                                                                             │
│  应用场景：                                                                  │
│  • 动态生成的内容（模板渲染、数据库查询结果）                                │
│  • Server-Sent Events                                                       │
│  • 大文件流式传输                                                           │
│  • 压缩后大小未知的响应                                                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 代码示例：HTTP消息结构

```cpp
// http_message.hpp - 改进的HTTP消息结构
#pragma once

#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>
#include <algorithm>
#include <sstream>

namespace http_server {

/**
 * HTTP方法枚举
 */
enum class HttpMethod {
    GET, POST, PUT, DELETE, HEAD, OPTIONS, PATCH, UNKNOWN
};

inline std::string_view methodToString(HttpMethod method) {
    switch (method) {
        case HttpMethod::GET:     return "GET";
        case HttpMethod::POST:    return "POST";
        case HttpMethod::PUT:     return "PUT";
        case HttpMethod::DELETE:  return "DELETE";
        case HttpMethod::HEAD:    return "HEAD";
        case HttpMethod::OPTIONS: return "OPTIONS";
        case HttpMethod::PATCH:   return "PATCH";
        default: return "UNKNOWN";
    }
}

inline HttpMethod stringToMethod(std::string_view str) {
    if (str == "GET")     return HttpMethod::GET;
    if (str == "POST")    return HttpMethod::POST;
    if (str == "PUT")     return HttpMethod::PUT;
    if (str == "DELETE")  return HttpMethod::DELETE;
    if (str == "HEAD")    return HttpMethod::HEAD;
    if (str == "OPTIONS") return HttpMethod::OPTIONS;
    if (str == "PATCH")   return HttpMethod::PATCH;
    return HttpMethod::UNKNOWN;
}

/**
 * HTTP头部（大小写不敏感的key）
 */
class HeaderMap {
public:
    void set(const std::string& key, const std::string& value) {
        std::string lower_key = toLower(key);
        headers_[lower_key] = value;
    }

    std::string get(const std::string& key) const {
        auto it = headers_.find(toLower(key));
        return it != headers_.end() ? it->second : "";
    }

    bool has(const std::string& key) const {
        return headers_.find(toLower(key)) != headers_.end();
    }

    void remove(const std::string& key) {
        headers_.erase(toLower(key));
    }

    size_t contentLength() const {
        auto val = get("content-length");
        return val.empty() ? 0 : std::stoull(val);
    }

    bool isChunked() const {
        return get("transfer-encoding") == "chunked";
    }

    bool isKeepAlive(const std::string& version) const {
        auto conn = get("connection");
        if (version == "HTTP/1.1") {
            // HTTP/1.1默认keep-alive
            return conn != "close";
        }
        // HTTP/1.0默认close
        return conn == "keep-alive";
    }

    // 遍历所有头部
    template<typename Func>
    void forEach(Func&& fn) const {
        for (const auto& [k, v] : headers_) {
            fn(k, v);
        }
    }

    // 序列化为HTTP格式
    std::string serialize() const {
        std::string result;
        for (const auto& [k, v] : headers_) {
            result += k + ": " + v + "\r\n";
        }
        return result;
    }

    size_t size() const { return headers_.size(); }

private:
    static std::string toLower(const std::string& s) {
        std::string result = s;
        std::transform(result.begin(), result.end(), result.begin(), ::tolower);
        return result;
    }

    std::unordered_map<std::string, std::string> headers_;
};

/**
 * HTTP请求
 */
struct HttpRequest {
    HttpMethod method = HttpMethod::GET;
    std::string path;            // 原始路径 (含query string)
    std::string uri_path;        // 纯路径 (不含query string)
    std::string query_string;    // 查询字符串
    std::string version = "HTTP/1.1";
    HeaderMap headers;
    std::string body;

    bool keepAlive() const {
        return headers.isKeepAlive(version);
    }

    bool hasBody() const {
        return headers.contentLength() > 0 || headers.isChunked();
    }
};

/**
 * HTTP响应
 */
class HttpResponse {
public:
    explicit HttpResponse(int status = 200)
        : status_(status), reason_(getDefaultReason(status)) {}

    void setStatus(int status) {
        status_ = status;
        reason_ = getDefaultReason(status);
    }

    void setHeader(const std::string& key, const std::string& value) {
        headers_.set(key, value);
    }

    void setBody(const std::string& body) {
        body_ = body;
        headers_.set("Content-Length", std::to_string(body_.size()));
    }

    void setBody(std::string&& body) {
        body_ = std::move(body);
        headers_.set("Content-Length", std::to_string(body_.size()));
    }

    // 序列化为完整的HTTP响应
    std::string serialize() const {
        std::string result;
        // 状态行
        result += "HTTP/1.1 " + std::to_string(status_) + " " + reason_ + "\r\n";
        // 头部
        result += headers_.serialize();
        result += "\r\n";
        // 响应体
        result += body_;
        return result;
    }

    // 快捷构造方法
    static HttpResponse ok(const std::string& body,
                          const std::string& content_type = "text/plain") {
        HttpResponse resp(200);
        resp.setHeader("Content-Type", content_type);
        resp.setBody(body);
        return resp;
    }

    static HttpResponse notFound() {
        HttpResponse resp(404);
        resp.setHeader("Content-Type", "text/html");
        resp.setBody("<html><body><h1>404 Not Found</h1></body></html>");
        return resp;
    }

    static HttpResponse badRequest(const std::string& msg = "Bad Request") {
        HttpResponse resp(400);
        resp.setHeader("Content-Type", "text/plain");
        resp.setBody(msg);
        return resp;
    }

    static HttpResponse serverError(const std::string& msg = "Internal Server Error") {
        HttpResponse resp(500);
        resp.setHeader("Content-Type", "text/plain");
        resp.setBody(msg);
        return resp;
    }

    static HttpResponse redirect(const std::string& location, int code = 302) {
        HttpResponse resp(code);
        resp.setHeader("Location", location);
        return resp;
    }

    int status() const { return status_; }
    const std::string& body() const { return body_; }
    HeaderMap& headers() { return headers_; }
    const HeaderMap& headers() const { return headers_; }

private:
    static std::string getDefaultReason(int status) {
        switch (status) {
            case 200: return "OK";
            case 201: return "Created";
            case 204: return "No Content";
            case 206: return "Partial Content";
            case 301: return "Moved Permanently";
            case 302: return "Found";
            case 304: return "Not Modified";
            case 400: return "Bad Request";
            case 401: return "Unauthorized";
            case 403: return "Forbidden";
            case 404: return "Not Found";
            case 405: return "Method Not Allowed";
            case 408: return "Request Timeout";
            case 413: return "Payload Too Large";
            case 429: return "Too Many Requests";
            case 500: return "Internal Server Error";
            case 502: return "Bad Gateway";
            case 503: return "Service Unavailable";
            default:  return "Unknown";
        }
    }

    int status_;
    std::string reason_;
    HeaderMap headers_;
    std::string body_;
};

} // namespace http_server
```

---

### Day 3-4：高性能解析器设计（10小时）

#### 解析器状态机

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    HTTP解析器状态机                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────┐   收到方法    ┌──────────────┐   收到路径               │
│  │              │──────────────▶│              │──────────┐               │
│  │  METHOD      │               │    PATH      │          │               │
│  │              │◀─ 重置 ──────│              │          │               │
│  └──────────────┘               └──────────────┘          │               │
│         ▲                                                  ▼               │
│         │                                          ┌──────────────┐       │
│         │                                          │   VERSION    │       │
│         │                                          │              │       │
│         │                                          └──────┬───────┘       │
│         │                                                 │ \r\n          │
│         │                                                 ▼               │
│         │                                          ┌──────────────┐       │
│         │                              ┌──────────│   HEADER     │       │
│         │                              │ 头部行    │   LINE       │       │
│         │                              └─────────▶│              │       │
│         │                                          └──────┬───────┘       │
│         │                                                 │ 空行\r\n      │
│         │                                                 ▼               │
│         │                                          ┌──────────────┐       │
│         │                    Content-Length > 0?    │   CHECK      │       │
│         │                     ┌─── Yes ────────────│   BODY       │       │
│         │                     │                    │              │       │
│         │                     ▼                    └──────┬───────┘       │
│         │              ┌──────────────┐                   │ No            │
│         │              │    BODY      │                   │               │
│         │              │              │                   ▼               │
│         │              └──────┬───────┘            ┌──────────────┐       │
│         │                     │ 读取完成            │   COMPLETE   │       │
│         │                     └───────────────────▶│              │       │
│         │                                          └──────┬───────┘       │
│         │                                                 │               │
│         └─── keep-alive? reset ──────────────────────────┘               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 与现有解析器的对比

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    HTTP解析器对比                                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┬──────────────┬──────────────┬──────────────┬──────────┐  │
│  │    特性     │ http-parser  │   llhttp     │ picohttpparser│ 本项目    │  │
│  │             │ (Node.js旧)  │ (Node.js新)  │  (H2O)       │          │  │
│  ├─────────────┼──────────────┼──────────────┼──────────────┼──────────┤  │
│  │ 语言        │ C            │ C (自动生成) │ C            │ C++17    │  │
│  ├─────────────┼──────────────┼──────────────┼──────────────┼──────────┤  │
│  │ 解析方式    │ 回调式       │ 回调式       │ 返回偏移     │ 状态机   │  │
│  ├─────────────┼──────────────┼──────────────┼──────────────┼──────────┤  │
│  │ 零拷贝      │ ✗ (回调拷贝) │ ✗           │ ✓            │ ✓        │  │
│  ├─────────────┼──────────────┼──────────────┼──────────────┼──────────┤  │
│  │ 增量解析    │ ✓            │ ✓            │ ✓            │ ✓        │  │
│  ├─────────────┼──────────────┼──────────────┼──────────────┼──────────┤  │
│  │ 安全性      │ 多个CVE      │ 较好         │ 较好         │ 严格验证 │  │
│  ├─────────────┼──────────────┼──────────────┼──────────────┼──────────┤  │
│  │ 性能(req/s) │ ~800K        │ ~1.5M        │ ~2M          │ 目标~1M  │  │
│  └─────────────┴──────────────┴──────────────┴──────────────┴──────────┘  │
│                                                                             │
│  关键性能技巧：                                                              │
│  1. 使用string_view避免拷贝                                                 │
│  2. 状态机减少分支预测失败                                                   │
│  3. 批量处理替代逐字节处理                                                   │
│  4. 内联关键路径函数                                                         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 代码示例：零拷贝HTTP解析器

```cpp
// http_parser_v2.hpp - 零拷贝状态机HTTP解析器
#pragma once

#include <string>
#include <string_view>
#include <cstdint>

namespace http_server {

/**
 * 解析状态
 */
enum class ParseState : uint8_t {
    METHOD,           // 解析HTTP方法
    PATH,             // 解析请求路径
    VERSION,          // 解析HTTP版本
    HEADER_KEY,       // 解析头部键
    HEADER_VALUE,     // 解析头部值
    HEADER_END,       // 头部结束判断
    BODY,             // 解析请求体
    CHUNKED_SIZE,     // Chunked: 解析块大小
    CHUNKED_DATA,     // Chunked: 解析块数据
    CHUNKED_TRAILER,  // Chunked: 解析尾部
    COMPLETE,         // 解析完成
    ERROR             // 解析错误
};

/**
 * 解析结果
 */
enum class ParseResult {
    NeedMore,     // 需要更多数据
    Complete,     // 解析完成
    Error         // 解析错误
};

/**
 * 高性能HTTP解析器
 *
 * 设计要点：
 * 1. 状态机驱动，支持增量解析
 * 2. 使用string_view实现零拷贝（数据在buffer中）
 * 3. 支持Chunked传输编码
 * 4. 严格验证防止协议攻击
 */
class HttpParserV2 {
public:
    static constexpr size_t MAX_METHOD_LEN = 7;     // OPTIONS
    static constexpr size_t MAX_PATH_LEN = 8192;
    static constexpr size_t MAX_HEADER_KEY_LEN = 256;
    static constexpr size_t MAX_HEADER_VALUE_LEN = 8192;
    static constexpr size_t MAX_HEADERS = 100;
    static constexpr size_t MAX_BODY_LEN = 10 * 1024 * 1024; // 10MB

    HttpParserV2() { reset(); }

    /**
     * 增量解析
     * @param data 新接收的数据
     * @param len 数据长度
     * @return 解析结果
     */
    ParseResult parse(const char* data, size_t len) {
        buffer_.append(data, len);

        while (pos_ < buffer_.size()) {
            switch (state_) {
            case ParseState::METHOD:
                if (!parseMethod()) return checkError();
                break;

            case ParseState::PATH:
                if (!parsePath()) return checkError();
                break;

            case ParseState::VERSION:
                if (!parseVersion()) return checkError();
                break;

            case ParseState::HEADER_KEY:
                if (!parseHeaderKey()) return checkError();
                break;

            case ParseState::HEADER_VALUE:
                if (!parseHeaderValue()) return checkError();
                break;

            case ParseState::HEADER_END:
                return handleHeaderEnd();

            case ParseState::BODY:
                if (!parseBody()) return ParseResult::NeedMore;
                state_ = ParseState::COMPLETE;
                return ParseResult::Complete;

            case ParseState::CHUNKED_SIZE:
                if (!parseChunkedSize()) return checkError();
                break;

            case ParseState::CHUNKED_DATA:
                if (!parseChunkedData()) return ParseResult::NeedMore;
                break;

            case ParseState::COMPLETE:
                return ParseResult::Complete;

            case ParseState::ERROR:
                return ParseResult::Error;
            }
        }

        return ParseResult::NeedMore;
    }

    // 重置解析器（用于Keep-Alive复用）
    void reset() {
        state_ = ParseState::METHOD;
        pos_ = 0;
        buffer_.clear();
        request_ = HttpRequest{};
        content_length_ = 0;
        chunked_ = false;
        current_header_key_.clear();
    }

    const HttpRequest& request() const { return request_; }
    ParseState state() const { return state_; }

private:
    // 查找\r\n
    size_t findCRLF(size_t start) const {
        for (size_t i = start; i + 1 < buffer_.size(); ++i) {
            if (buffer_[i] == '\r' && buffer_[i + 1] == '\n') {
                return i;
            }
        }
        return std::string::npos;
    }

    bool parseMethod() {
        size_t space = buffer_.find(' ', pos_);
        if (space == std::string::npos) return false;

        std::string_view method_str(buffer_.data() + pos_, space - pos_);

        if (method_str.size() > MAX_METHOD_LEN) {
            state_ = ParseState::ERROR;
            return false;
        }

        request_.method = stringToMethod(method_str);
        if (request_.method == HttpMethod::UNKNOWN) {
            state_ = ParseState::ERROR;
            return false;
        }

        pos_ = space + 1;
        state_ = ParseState::PATH;
        return true;
    }

    bool parsePath() {
        size_t space = buffer_.find(' ', pos_);
        if (space == std::string::npos) return false;

        size_t path_len = space - pos_;
        if (path_len > MAX_PATH_LEN) {
            state_ = ParseState::ERROR;
            return false;
        }

        request_.path = buffer_.substr(pos_, path_len);

        // 分离path和query string
        size_t qmark = request_.path.find('?');
        if (qmark != std::string::npos) {
            request_.uri_path = request_.path.substr(0, qmark);
            request_.query_string = request_.path.substr(qmark + 1);
        } else {
            request_.uri_path = request_.path;
        }

        pos_ = space + 1;
        state_ = ParseState::VERSION;
        return true;
    }

    bool parseVersion() {
        size_t crlf = findCRLF(pos_);
        if (crlf == std::string::npos) return false;

        request_.version = buffer_.substr(pos_, crlf - pos_);

        if (request_.version != "HTTP/1.0" && request_.version != "HTTP/1.1") {
            state_ = ParseState::ERROR;
            return false;
        }

        pos_ = crlf + 2;
        state_ = ParseState::HEADER_KEY;
        return true;
    }

    bool parseHeaderKey() {
        // 检查是否是空行（头部结束）
        if (pos_ + 1 < buffer_.size() &&
            buffer_[pos_] == '\r' && buffer_[pos_ + 1] == '\n') {
            pos_ += 2;
            state_ = ParseState::HEADER_END;
            return true;
        }

        size_t colon = buffer_.find(':', pos_);
        if (colon == std::string::npos) return false;

        size_t key_len = colon - pos_;
        if (key_len > MAX_HEADER_KEY_LEN) {
            state_ = ParseState::ERROR;
            return false;
        }

        current_header_key_ = buffer_.substr(pos_, key_len);
        pos_ = colon + 1;

        // 跳过OWS (optional whitespace)
        while (pos_ < buffer_.size() && buffer_[pos_] == ' ') {
            pos_++;
        }

        state_ = ParseState::HEADER_VALUE;
        return true;
    }

    bool parseHeaderValue() {
        size_t crlf = findCRLF(pos_);
        if (crlf == std::string::npos) return false;

        size_t value_len = crlf - pos_;
        if (value_len > MAX_HEADER_VALUE_LEN) {
            state_ = ParseState::ERROR;
            return false;
        }

        std::string value = buffer_.substr(pos_, value_len);
        request_.headers.set(current_header_key_, value);

        pos_ = crlf + 2;
        state_ = ParseState::HEADER_KEY;
        return true;
    }

    ParseResult handleHeaderEnd() {
        content_length_ = request_.headers.contentLength();
        chunked_ = request_.headers.isChunked();

        if (chunked_) {
            state_ = ParseState::CHUNKED_SIZE;
            return ParseResult::NeedMore;
        }

        if (content_length_ > 0) {
            if (content_length_ > MAX_BODY_LEN) {
                state_ = ParseState::ERROR;
                return ParseResult::Error;
            }
            state_ = ParseState::BODY;
            return ParseResult::NeedMore;
        }

        state_ = ParseState::COMPLETE;
        return ParseResult::Complete;
    }

    bool parseBody() {
        size_t remaining = buffer_.size() - pos_;
        if (remaining < content_length_) return false;

        request_.body = buffer_.substr(pos_, content_length_);
        pos_ += content_length_;
        return true;
    }

    bool parseChunkedSize() {
        size_t crlf = findCRLF(pos_);
        if (crlf == std::string::npos) return false;

        std::string size_str = buffer_.substr(pos_, crlf - pos_);
        chunk_size_ = std::stoull(size_str, nullptr, 16);
        pos_ = crlf + 2;

        if (chunk_size_ == 0) {
            // 终止块
            state_ = ParseState::COMPLETE;
            return true;
        }

        state_ = ParseState::CHUNKED_DATA;
        return true;
    }

    bool parseChunkedData() {
        size_t remaining = buffer_.size() - pos_;
        if (remaining < chunk_size_ + 2) return false; // +2 for \r\n

        request_.body.append(buffer_, pos_, chunk_size_);
        pos_ += chunk_size_ + 2; // skip \r\n after chunk data

        state_ = ParseState::CHUNKED_SIZE;
        return true;
    }

    ParseResult checkError() const {
        return state_ == ParseState::ERROR ? ParseResult::Error : ParseResult::NeedMore;
    }

    ParseState state_;
    std::string buffer_;
    size_t pos_ = 0;

    HttpRequest request_;
    size_t content_length_ = 0;
    bool chunked_ = false;
    size_t chunk_size_ = 0;
    std::string current_header_key_;
};

} // namespace http_server
```

---

### Day 5-7：URL解析与响应构建（15小时）

#### URL结构

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    URL 结构解析                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   http://user:pass@example.com:8080/path/to/page?key=val&a=b#section       │
│   └─┬─┘  └──┬───┘ └────┬─────┘└┬─┘└─────┬─────┘└────┬─────┘└──┬───┘     │
│   scheme  userinfo    host    port     path       query     fragment       │
│                       └───┬────┘                                           │
│                       authority                                             │
│                                                                             │
│   在HTTP服务器中，我们主要处理：                                             │
│   ┌──────────────────────────────────────────────────────────────────┐     │
│   │  /path/to/page?key=val&a=b                                      │     │
│   │  └─────┬──────┘└────┬─────┘                                      │     │
│   │      path        query                                           │     │
│   │                                                                  │     │
│   │  需要处理：                                                       │     │
│   │  • 路径解码 (%20 → 空格, %2F → /)                                │     │
│   │  • 路径规范化 (/a/../b → /b, /a/./b → /a/b)                     │     │
│   │  • 安全检查 (防止目录遍历 ../../etc/passwd)                      │     │
│   │  • 查询字符串解析 (key=val → map)                                │     │
│   └──────────────────────────────────────────────────────────────────┘     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 代码示例：URL解析器

```cpp
// url_parser.hpp - URL解析与编解码
#pragma once

#include <string>
#include <string_view>
#include <unordered_map>
#include <sstream>
#include <iomanip>

namespace http_server {

/**
 * URL编解码
 */
class UrlCodec {
public:
    // URL编码（Percent-encoding）
    static std::string encode(std::string_view input) {
        std::ostringstream oss;
        for (char c : input) {
            if (isUnreserved(c)) {
                oss << c;
            } else {
                oss << '%' << std::uppercase << std::hex
                    << std::setw(2) << std::setfill('0')
                    << static_cast<int>(static_cast<unsigned char>(c));
            }
        }
        return oss.str();
    }

    // URL解码
    static std::string decode(std::string_view input) {
        std::string result;
        result.reserve(input.size());

        for (size_t i = 0; i < input.size(); ++i) {
            if (input[i] == '%' && i + 2 < input.size()) {
                int high = hexToInt(input[i + 1]);
                int low = hexToInt(input[i + 2]);
                if (high >= 0 && low >= 0) {
                    result += static_cast<char>(high * 16 + low);
                    i += 2;
                    continue;
                }
            }
            if (input[i] == '+') {
                result += ' ';
            } else {
                result += input[i];
            }
        }
        return result;
    }

private:
    static bool isUnreserved(char c) {
        return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
               (c >= '0' && c <= '9') || c == '-' || c == '_' ||
               c == '.' || c == '~';
    }

    static int hexToInt(char c) {
        if (c >= '0' && c <= '9') return c - '0';
        if (c >= 'A' && c <= 'F') return c - 'A' + 10;
        if (c >= 'a' && c <= 'f') return c - 'a' + 10;
        return -1;
    }
};

/**
 * 查询字符串解析器
 */
class QueryString {
public:
    static std::unordered_map<std::string, std::string>
    parse(std::string_view qs) {
        std::unordered_map<std::string, std::string> params;

        size_t pos = 0;
        while (pos < qs.size()) {
            size_t amp = qs.find('&', pos);
            if (amp == std::string_view::npos) amp = qs.size();

            std::string_view pair = qs.substr(pos, amp - pos);
            size_t eq = pair.find('=');

            if (eq != std::string_view::npos) {
                std::string key = UrlCodec::decode(pair.substr(0, eq));
                std::string value = UrlCodec::decode(pair.substr(eq + 1));
                params[key] = value;
            } else if (!pair.empty()) {
                params[std::string(pair)] = "";
            }

            pos = amp + 1;
        }

        return params;
    }
};

/**
 * 路径规范化与安全检查
 */
class PathNormalizer {
public:
    /**
     * 规范化路径
     * 处理 /./, /../, // 等
     * 防止目录遍历攻击
     */
    static std::string normalize(std::string_view path) {
        // 先解码
        std::string decoded = UrlCodec::decode(path);

        // 分割路径组件
        std::vector<std::string> components;
        std::string current;

        for (char c : decoded) {
            if (c == '/') {
                if (!current.empty()) {
                    processComponent(current, components);
                    current.clear();
                }
            } else {
                current += c;
            }
        }
        if (!current.empty()) {
            processComponent(current, components);
        }

        // 重组路径
        std::string result = "/";
        for (size_t i = 0; i < components.size(); ++i) {
            result += components[i];
            if (i + 1 < components.size()) result += "/";
        }

        return result;
    }

    /**
     * 检查路径是否安全（不越过doc_root）
     */
    static bool isSafe(std::string_view path) {
        std::string normalized = normalize(path);
        // 规范化后不应包含 ..
        return normalized.find("..") == std::string::npos;
    }

private:
    static void processComponent(const std::string& comp,
                                 std::vector<std::string>& components) {
        if (comp == ".") {
            // 当前目录，忽略
            return;
        }
        if (comp == "..") {
            // 上级目录，弹出
            if (!components.empty()) {
                components.pop_back();
            }
            return;
        }
        components.push_back(comp);
    }
};

/**
 * MIME类型检测
 */
class MimeTypes {
public:
    static std::string_view detect(std::string_view path) {
        auto dot = path.rfind('.');
        if (dot == std::string_view::npos) return "application/octet-stream";

        auto ext = path.substr(dot);

        if (ext == ".html" || ext == ".htm") return "text/html; charset=utf-8";
        if (ext == ".css")   return "text/css; charset=utf-8";
        if (ext == ".js")    return "application/javascript; charset=utf-8";
        if (ext == ".json")  return "application/json; charset=utf-8";
        if (ext == ".xml")   return "application/xml; charset=utf-8";
        if (ext == ".txt")   return "text/plain; charset=utf-8";
        if (ext == ".csv")   return "text/csv; charset=utf-8";

        if (ext == ".png")   return "image/png";
        if (ext == ".jpg" || ext == ".jpeg") return "image/jpeg";
        if (ext == ".gif")   return "image/gif";
        if (ext == ".svg")   return "image/svg+xml";
        if (ext == ".ico")   return "image/x-icon";
        if (ext == ".webp")  return "image/webp";

        if (ext == ".pdf")   return "application/pdf";
        if (ext == ".zip")   return "application/zip";
        if (ext == ".gz")    return "application/gzip";
        if (ext == ".wasm")  return "application/wasm";

        if (ext == ".mp4")   return "video/mp4";
        if (ext == ".webm")  return "video/webm";
        if (ext == ".mp3")   return "audio/mpeg";

        if (ext == ".woff")  return "font/woff";
        if (ext == ".woff2") return "font/woff2";
        if (ext == ".ttf")   return "font/ttf";

        return "application/octet-stream";
    }
};

} // namespace http_server
```

#### 代码示例：改进的响应构建器

```cpp
// http_response_builder.hpp - 支持Chunked编码的响应构建器
#pragma once

#include <string>
#include <sstream>
#include <functional>
#include <iomanip>

namespace http_server {

/**
 * Chunked响应写入器
 * 支持流式写入，不需要预知响应体大小
 */
class ChunkedWriter {
public:
    using WriteFn = std::function<bool(const char* data, size_t len)>;

    explicit ChunkedWriter(WriteFn write_fn)
        : write_fn_(std::move(write_fn)) {}

    // 发送响应头
    bool sendHeaders(int status, const HeaderMap& headers) {
        std::string response = "HTTP/1.1 " + std::to_string(status) + " OK\r\n";
        response += "Transfer-Encoding: chunked\r\n";

        headers.forEach([&response](const std::string& k, const std::string& v) {
            if (k != "content-length" && k != "transfer-encoding") {
                response += k + ": " + v + "\r\n";
            }
        });

        response += "\r\n";
        return write_fn_(response.data(), response.size());
    }

    // 发送一个chunk
    bool sendChunk(const std::string& data) {
        if (data.empty()) return true;

        std::ostringstream oss;
        oss << std::hex << data.size() << "\r\n";
        oss << data << "\r\n";

        std::string chunk = oss.str();
        return write_fn_(chunk.data(), chunk.size());
    }

    // 发送终止块
    bool finish() {
        const char* end_chunk = "0\r\n\r\n";
        return write_fn_(end_chunk, 5);
    }

private:
    WriteFn write_fn_;
};

} // namespace http_server
```

---

### 第一周自测问题

完成第一周学习后，请尝试回答以下问题：

**理论理解：**
1. HTTP/1.0和HTTP/1.1在连接管理上的核心区别是什么？
2. Pipeline和多路复用(HTTP/2)有什么区别？Pipeline的局限性是什么？
3. Chunked传输编码适用于哪些场景？
4. 为什么HTTP解析器要设计成状态机？相比一次性解析有什么优势？
5. 目录遍历攻击是怎样发生的？如何防御？

**代码实践：**
1. 使用状态机实现HTTP请求解析器
2. 实现URL编解码
3. 实现查询字符串解析
4. 实现路径规范化和安全检查
5. 实现支持Chunked编码的响应构建器

---

### 第一周检验标准

| 检验项 | 标准 | 自评 |
|--------|------|------|
| 理解HTTP生命周期 | 能描述完整的请求/响应流程 | ☐ |
| 理解Keep-Alive | 能解释连接复用机制 | ☐ |
| 理解Chunked编码 | 能解释分块传输格式 | ☐ |
| 实现状态机解析器 | 代码能正确解析HTTP请求 | ☐ |
| 实现URL解析 | 代码能正确编解码URL | ☐ |
| 实现路径安全 | 代码能防御目录遍历攻击 | ☐ |

---

### 第一周时间分配

| 内容 | 时间 |
|------|------|
| HTTP协议学习 | 5小时 |
| Keep-Alive/Pipeline理解 | 3小时 |
| Chunked编码学习 | 2小时 |
| 解析器状态机设计 | 4小时 |
| 解析器代码实现 | 6小时 |
| URL解析实现 | 5小时 |
| 响应构建器实现 | 4小时 |
| 测试与验证 | 6小时 |

---

## 第二周：连接管理与I/O优化（Day 8-14）

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    第二周学习路线图                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Day 8-9              Day 10-11            Day 12-14                      │
│   ┌─────────┐         ┌─────────┐          ┌─────────┐                     │
│   │ 连接    │         │ 高性能  │          │ 多线程  │                     │
│   │ 管理    │────────▶│  I/O   │─────────▶│ 服务器  │                     │
│   │ 详解    │         │  技术   │          │  实现   │                     │
│   └─────────┘         └─────────┘          └─────────┘                     │
│       │                   │                    │                           │
│       ▼                   ▼                    ▼                           │
│   生命周期管理        sendfile/mmap        Worker线程池                     │
│   Keep-Alive超时      Buffer链管理         SO_REUSEPORT                    │
│                                                                             │
│   学习目标：掌握高性能I/O技术，实现多线程HTTP服务器                          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Day 8-9：连接生命周期管理（10小时）

#### 连接状态机

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    连接状态机                                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌──────────┐    accept()    ┌──────────┐    收到请求                     │
│   │          │───────────────▶│          │──────────┐                      │
│   │   NEW    │                │  ACTIVE  │          │                      │
│   │          │                │          │◀─────────┘                      │
│   └──────────┘                └────┬─────┘  (Keep-Alive)                  │
│                                    │                                       │
│                             请求处理完成                                    │
│                             keep-alive?                                    │
│                                    │                                       │
│                    ┌───── Yes ─────┼───── No ─────┐                       │
│                    │               │               │                       │
│                    ▼               │               ▼                       │
│              ┌──────────┐         │         ┌──────────┐                  │
│              │          │         │         │          │                  │
│              │   IDLE   │         │         │ CLOSING  │                  │
│              │          │         │         │          │                  │
│              └────┬─────┘         │         └────┬─────┘                  │
│                   │               │              │                        │
│            超时/错误               │         flush完成                     │
│                   │               │              │                        │
│                   ▼               ▼              ▼                        │
│              ┌──────────────────────────────────────┐                     │
│              │              CLOSED                    │                     │
│              │         释放资源, close(fd)            │                     │
│              └──────────────────────────────────────┘                     │
│                                                                             │
│   关键参数：                                                                 │
│   • keep_alive_timeout: 空闲连接超时（默认60s）                             │
│   • max_requests_per_conn: 单连接最大请求数（默认1000）                     │
│   • read_timeout: 读取超时（默认30s）                                       │
│   • write_timeout: 写入超时（默认30s）                                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 代码示例：连接管理器

```cpp
// connection_manager.hpp - 连接生命周期管理
#pragma once

#include <unordered_map>
#include <memory>
#include <chrono>
#include <functional>
#include <list>
#include <mutex>
#include <iostream>

namespace http_server {

using SteadyClock = std::chrono::steady_clock;
using TimePoint = SteadyClock::time_point;
using Duration = std::chrono::milliseconds;

/**
 * 连接状态
 */
enum class ConnectionState {
    New,        // 新建连接
    Active,     // 正在处理请求
    Idle,       // 空闲等待（Keep-Alive）
    Closing,    // 正在关闭
    Closed      // 已关闭
};

/**
 * 连接配置
 */
struct ConnectionConfig {
    Duration keep_alive_timeout{60000};     // 60秒
    Duration read_timeout{30000};           // 30秒
    Duration write_timeout{30000};          // 30秒
    uint32_t max_requests_per_conn = 1000;  // 单连接最大请求数
    size_t max_connections = 10000;         // 最大连接数
};

/**
 * 单个连接
 */
class Connection {
public:
    Connection(int fd, const ConnectionConfig& config)
        : fd_(fd), config_(config), state_(ConnectionState::New)
        , created_at_(SteadyClock::now())
        , last_active_(created_at_)
        , request_count_(0) {}

    int fd() const { return fd_; }
    ConnectionState state() const { return state_; }

    void setState(ConnectionState state) {
        state_ = state;
        if (state == ConnectionState::Active) {
            last_active_ = SteadyClock::now();
        }
    }

    void incrementRequestCount() {
        request_count_++;
        last_active_ = SteadyClock::now();
    }

    bool shouldClose() const {
        // 超过最大请求数
        if (request_count_ >= config_.max_requests_per_conn) return true;
        return false;
    }

    bool isIdleTimeout() const {
        if (state_ != ConnectionState::Idle) return false;
        auto elapsed = SteadyClock::now() - last_active_;
        return elapsed >= config_.keep_alive_timeout;
    }

    bool isReadTimeout() const {
        if (state_ != ConnectionState::Active) return false;
        auto elapsed = SteadyClock::now() - last_active_;
        return elapsed >= config_.read_timeout;
    }

    uint32_t requestCount() const { return request_count_; }
    TimePoint lastActive() const { return last_active_; }

    HttpParserV2& parser() { return parser_; }

private:
    int fd_;
    ConnectionConfig config_;
    ConnectionState state_;
    TimePoint created_at_;
    TimePoint last_active_;
    uint32_t request_count_;
    HttpParserV2 parser_;
};

/**
 * 连接管理器
 */
class ConnectionManager {
public:
    explicit ConnectionManager(const ConnectionConfig& config = {})
        : config_(config) {}

    // 添加新连接
    Connection* addConnection(int fd) {
        if (connections_.size() >= config_.max_connections) {
            std::cout << "[ConnMgr] Max connections reached, rejecting\n";
            return nullptr;
        }

        auto conn = std::make_unique<Connection>(fd, config_);
        auto* ptr = conn.get();
        connections_[fd] = std::move(conn);

        std::cout << "[ConnMgr] New connection fd=" << fd
                  << " total=" << connections_.size() << "\n";
        return ptr;
    }

    // 获取连接
    Connection* getConnection(int fd) {
        auto it = connections_.find(fd);
        return it != connections_.end() ? it->second.get() : nullptr;
    }

    // 移除连接
    void removeConnection(int fd) {
        connections_.erase(fd);
    }

    // 清理超时连接
    std::vector<int> cleanupTimeouts() {
        std::vector<int> to_close;

        for (auto& [fd, conn] : connections_) {
            if (conn->isIdleTimeout() || conn->isReadTimeout()) {
                to_close.push_back(fd);
            }
        }

        for (int fd : to_close) {
            std::cout << "[ConnMgr] Timeout, closing fd=" << fd << "\n";
            connections_.erase(fd);
        }

        return to_close;
    }

    size_t activeCount() const {
        size_t count = 0;
        for (const auto& [_, conn] : connections_) {
            if (conn->state() == ConnectionState::Active) count++;
        }
        return count;
    }

    size_t idleCount() const {
        size_t count = 0;
        for (const auto& [_, conn] : connections_) {
            if (conn->state() == ConnectionState::Idle) count++;
        }
        return count;
    }

    size_t totalCount() const { return connections_.size(); }

private:
    ConnectionConfig config_;
    std::unordered_map<int, std::unique_ptr<Connection>> connections_;
};

} // namespace http_server
```

---

### Day 10-11：高性能I/O技术（10小时）

#### 零拷贝技术对比

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    传统I/O vs 零拷贝I/O                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  传统方式（read + write）：4次拷贝                                          │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │  磁盘    │───▶│ 内核缓冲 │───▶│ 用户缓冲 │───▶│ Socket   │              │
│  │          │ ①  │ (Page    │ ②  │ (read()  │ ③  │ 缓冲区   │───▶ 网卡    │
│  │          │    │  Cache)  │    │  buffer) │    │ (write())│ ④           │
│  └──────────┘    └──────────┘    └──────────┘    └──────────┘              │
│  上下文切换：4次（read系统调用2次 + write系统调用2次）                       │
│                                                                             │
│  sendfile方式：2次拷贝（零用户空间拷贝）                                    │
│  ┌──────────┐    ┌──────────┐                    ┌──────────┐              │
│  │  磁盘    │───▶│ 内核缓冲 │───────────────────▶│ Socket   │              │
│  │          │ ①  │ (Page    │         ②          │ 缓冲区   │───▶ 网卡    │
│  │          │    │  Cache)  │                    │          │              │
│  └──────────┘    └──────────┘                    └──────────┘              │
│  上下文切换：2次（sendfile系统调用1次进出）                                  │
│                                                                             │
│  mmap方式：3次拷贝                                                          │
│  ┌──────────┐    ┌────────────────────┐          ┌──────────┐              │
│  │  磁盘    │───▶│  共享内存映射       │─────────▶│ Socket   │              │
│  │          │ ①  │  用户空间可直接访问  │    ②     │ 缓冲区   │───▶ 网卡    │
│  │          │    │  (无需read拷贝)     │          │          │ ③           │
│  └──────────┘    └────────────────────┘          └──────────┘              │
│  优势：用户空间可以修改数据后再发送                                          │
│                                                                             │
│  writev方式（聚集写入）：                                                    │
│  ┌──────────┐                                                              │
│  │ Buffer 1 │──┐                                                           │
│  └──────────┘  │    ┌──────────┐                                           │
│  ┌──────────┐  ├───▶│ 单次     │───▶ Socket                               │
│  │ Buffer 2 │──┤    │ writev() │                                           │
│  └──────────┘  │    └──────────┘                                           │
│  ┌──────────┐  │                                                           │
│  │ Buffer 3 │──┘    减少系统调用次数                                        │
│  └──────────┘                                                              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 代码示例：Buffer链与零拷贝

```cpp
// buffer_chain.hpp - 散列/聚集缓冲区管理
#pragma once

#include <vector>
#include <string>
#include <cstring>
#include <sys/uio.h>

namespace http_server {

/**
 * 缓冲区块
 */
class BufferSlice {
public:
    explicit BufferSlice(size_t capacity = 4096)
        : data_(capacity), size_(0) {}

    BufferSlice(const char* data, size_t len)
        : data_(data, data + len), size_(len) {}

    BufferSlice(const std::string& str)
        : data_(str.begin(), str.end()), size_(str.size()) {}

    const char* data() const { return data_.data(); }
    char* writable() { return data_.data() + size_; }
    size_t size() const { return size_; }
    size_t capacity() const { return data_.size(); }
    size_t writableBytes() const { return capacity() - size_; }
    bool empty() const { return size_ == 0; }

    size_t append(const char* data, size_t len) {
        size_t to_copy = std::min(len, writableBytes());
        std::memcpy(writable(), data, to_copy);
        size_ += to_copy;
        return to_copy;
    }

    void drain(size_t len) {
        if (len >= size_) {
            size_ = 0;
        } else {
            std::memmove(data_.data(), data_.data() + len, size_ - len);
            size_ -= len;
        }
    }

private:
    std::vector<char> data_;
    size_t size_;
};

/**
 * Buffer链 - 支持scatter-gather I/O
 */
class BufferChain {
public:
    // 添加数据
    void append(const char* data, size_t len) {
        while (len > 0) {
            if (slices_.empty() || slices_.back().writableBytes() == 0) {
                slices_.emplace_back(std::max(len, size_t(4096)));
            }
            size_t written = slices_.back().append(data, len);
            data += written;
            len -= written;
            total_size_ += written;
        }
    }

    void append(const std::string& str) {
        append(str.data(), str.size());
    }

    // 添加已有的BufferSlice
    void appendSlice(BufferSlice&& slice) {
        total_size_ += slice.size();
        slices_.push_back(std::move(slice));
    }

    // 准备iovec数组用于writev
    std::vector<struct iovec> toIovec() const {
        std::vector<struct iovec> iovecs;
        iovecs.reserve(slices_.size());

        for (const auto& slice : slices_) {
            if (!slice.empty()) {
                struct iovec iov;
                iov.iov_base = const_cast<char*>(slice.data());
                iov.iov_len = slice.size();
                iovecs.push_back(iov);
            }
        }

        return iovecs;
    }

    // 从链中消耗数据（已发送的部分）
    void drain(size_t len) {
        while (len > 0 && !slices_.empty()) {
            auto& front = slices_.front();
            if (len >= front.size()) {
                len -= front.size();
                total_size_ -= front.size();
                slices_.erase(slices_.begin());
            } else {
                front.drain(len);
                total_size_ -= len;
                len = 0;
            }
        }
    }

    size_t totalSize() const { return total_size_; }
    bool empty() const { return total_size_ == 0; }
    size_t sliceCount() const { return slices_.size(); }

private:
    std::vector<BufferSlice> slices_;
    size_t total_size_ = 0;
};

} // namespace http_server
```

#### 代码示例：零拷贝文件传输

```cpp
// zero_copy_file.hpp - sendfile和mmap文件传输
#pragma once

#include <string>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <cstring>
#include <iostream>

#ifdef __linux__
#include <sys/sendfile.h>
#endif

#ifdef __APPLE__
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/uio.h>
#endif

#include <sys/mman.h>

namespace http_server {

/**
 * 文件信息
 */
struct FileInfo {
    std::string path;
    size_t size = 0;
    time_t mtime = 0;
    bool exists = false;

    static FileInfo stat(const std::string& path) {
        FileInfo info;
        info.path = path;

        struct stat st;
        if (::stat(path.c_str(), &st) == 0 && S_ISREG(st.st_mode)) {
            info.size = st.st_size;
            info.mtime = st.st_mtime;
            info.exists = true;
        }

        return info;
    }
};

/**
 * 零拷贝文件发送器
 */
class ZeroCopyFile {
public:
    /**
     * 使用sendfile发送文件
     * @return 发送的字节数，-1表示错误
     */
    static ssize_t sendfile(int socket_fd, const std::string& path,
                            off_t offset = 0, size_t count = 0) {
        int file_fd = open(path.c_str(), O_RDONLY);
        if (file_fd < 0) return -1;

        if (count == 0) {
            struct stat st;
            fstat(file_fd, &st);
            count = st.st_size - offset;
        }

        ssize_t total_sent = 0;
        size_t remaining = count;

        while (remaining > 0) {
#ifdef __linux__
            ssize_t sent = ::sendfile(socket_fd, file_fd, &offset, remaining);
#elif defined(__APPLE__)
            off_t len = remaining;
            int ret = ::sendfile(file_fd, socket_fd, offset, &len, nullptr, 0);
            ssize_t sent = (ret == 0 || errno == EAGAIN) ? len : -1;
            offset += len;
#else
            // 回退到read+write
            char buf[8192];
            ssize_t n = pread(file_fd, buf, std::min(remaining, sizeof(buf)), offset);
            if (n <= 0) break;
            ssize_t sent = write(socket_fd, buf, n);
            offset += n;
#endif
            if (sent <= 0) {
                if (errno == EAGAIN || errno == EWOULDBLOCK) break;
                if (errno == EINTR) continue;
                close(file_fd);
                return -1;
            }

            total_sent += sent;
            remaining -= sent;
        }

        close(file_fd);
        return total_sent;
    }

    /**
     * 使用mmap映射文件
     */
    static std::pair<void*, size_t> mmapFile(const std::string& path) {
        int fd = open(path.c_str(), O_RDONLY);
        if (fd < 0) return {nullptr, 0};

        struct stat st;
        fstat(fd, &st);
        size_t size = st.st_size;

        void* addr = mmap(nullptr, size, PROT_READ, MAP_PRIVATE, fd, 0);
        close(fd);

        if (addr == MAP_FAILED) return {nullptr, 0};

        // 提示内核顺序读取
        madvise(addr, size, MADV_SEQUENTIAL);

        return {addr, size};
    }

    static void munmapFile(void* addr, size_t size) {
        if (addr && addr != MAP_FAILED) {
            munmap(addr, size);
        }
    }
};

} // namespace http_server
```

---

### Day 12-14：多线程HTTP服务器（15小时）

#### 多线程架构

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    多线程HTTP服务器架构                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  方案一：单Acceptor + Worker线程池                                          │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  Main Thread (Acceptor)                                              │  │
│  │  ┌────────────────┐                                                  │  │
│  │  │ listen_fd      │                                                  │  │
│  │  │ accept()       │──── 分发连接 ───┬──────────┬──────────┐         │  │
│  │  └────────────────┘                 │          │          │         │  │
│  │                                     ▼          ▼          ▼         │  │
│  │                              ┌──────────┐┌──────────┐┌──────────┐  │  │
│  │                              │ Worker 0 ││ Worker 1 ││ Worker N │  │  │
│  │                              │ epoll    ││ epoll    ││ epoll    │  │  │
│  │                              │ loop     ││ loop     ││ loop     │  │  │
│  │                              └──────────┘└──────────┘└──────────┘  │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  方案二：SO_REUSEPORT（每个Worker独立accept）                               │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  ┌──────────┐    ┌──────────┐    ┌──────────┐                       │  │
│  │  │ Worker 0 │    │ Worker 1 │    │ Worker N │                       │  │
│  │  │ listen   │    │ listen   │    │ listen   │                       │  │
│  │  │ accept   │    │ accept   │    │ accept   │                       │  │
│  │  │ epoll    │    │ epoll    │    │ epoll    │                       │  │
│  │  └──────────┘    └──────────┘    └──────────┘                       │  │
│  │       ▲               ▲               ▲                             │  │
│  │       └───────────────┼───────────────┘                             │  │
│  │                       │                                             │  │
│  │              内核自动负载均衡                                         │  │
│  │              (SO_REUSEPORT)                                          │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  对比：                                                                     │
│  ┌──────────────────┬────────────────────┬──────────────────────┐          │
│  │ 特性             │ 方案一 (Acceptor)  │ 方案二 (REUSEPORT)   │          │
│  ├──────────────────┼────────────────────┼──────────────────────┤          │
│  │ accept瓶颈      │ 单线程可能瓶颈     │ 无瓶颈               │          │
│  │ 负载均衡        │ 应用层控制         │ 内核自动             │          │
│  │ 连接亲和性      │ 可控               │ 自动                 │          │
│  │ 实现复杂度      │ 较高               │ 较低                 │          │
│  └──────────────────┴────────────────────┴──────────────────────┘          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 代码示例：多线程HTTP服务器

```cpp
// thread_pool_server.hpp - 多线程HTTP服务器
#pragma once

#include <thread>
#include <vector>
#include <memory>
#include <atomic>
#include <functional>
#include <iostream>
#include <unistd.h>
#include <netinet/in.h>
#include <sys/socket.h>

#ifdef __linux__
#include <sys/epoll.h>
#endif

namespace http_server {

using RequestHandler = std::function<HttpResponse(const HttpRequest&)>;

/**
 * Worker线程 - 每个Worker拥有独立的epoll和连接管理
 */
class HttpWorker {
public:
    HttpWorker(uint32_t id, int listen_fd, RequestHandler handler)
        : id_(id), listen_fd_(listen_fd)
        , handler_(std::move(handler)), running_(false) {
#ifdef __linux__
        epoll_fd_ = epoll_create1(EPOLL_CLOEXEC);
#endif
    }

    ~HttpWorker() {
        stop();
#ifdef __linux__
        if (epoll_fd_ >= 0) close(epoll_fd_);
#endif
    }

    void start() {
        running_ = true;
        thread_ = std::thread([this]() { run(); });
    }

    void stop() {
        running_ = false;
        if (thread_.joinable()) thread_.join();
    }

private:
    void run() {
        // 将listen_fd加入epoll
        addFd(listen_fd_);

        std::cout << "[Worker " << id_ << "] Started\n";

#ifdef __linux__
        std::vector<epoll_event> events(256);

        while (running_) {
            int n = epoll_wait(epoll_fd_, events.data(), events.size(), 100);

            for (int i = 0; i < n; ++i) {
                int fd = events[i].data.fd;

                if (fd == listen_fd_) {
                    handleAccept();
                } else if (events[i].events & (EPOLLERR | EPOLLHUP)) {
                    closeConnection(fd);
                } else if (events[i].events & EPOLLIN) {
                    handleRead(fd);
                }
            }

            // 周期性清理超时连接
            auto timeouts = conn_mgr_.cleanupTimeouts();
            for (int fd : timeouts) {
                close(fd);
            }
        }
#endif
    }

    void handleAccept() {
        while (true) {
            struct sockaddr_in addr;
            socklen_t len = sizeof(addr);
            int client = accept4(listen_fd_, (struct sockaddr*)&addr, &len,
                                SOCK_NONBLOCK | SOCK_CLOEXEC);
            if (client < 0) break;

            auto* conn = conn_mgr_.addConnection(client);
            if (!conn) {
                close(client);
                continue;
            }

            conn->setState(ConnectionState::Active);
            addFd(client);
        }
    }

    void handleRead(int fd) {
        auto* conn = conn_mgr_.getConnection(fd);
        if (!conn) return;

        char buf[8192];
        while (true) {
            ssize_t n = read(fd, buf, sizeof(buf));
            if (n > 0) {
                auto result = conn->parser().parse(buf, n);

                if (result == ParseResult::Complete) {
                    handleRequest(conn);

                    if (conn->shouldClose() ||
                        !conn->parser().request().keepAlive()) {
                        closeConnection(fd);
                        return;
                    }

                    conn->parser().reset();
                    conn->incrementRequestCount();
                    conn->setState(ConnectionState::Idle);
                } else if (result == ParseResult::Error) {
                    closeConnection(fd);
                    return;
                }
            } else if (n == 0) {
                closeConnection(fd);
                return;
            } else {
                if (errno == EAGAIN || errno == EWOULDBLOCK) break;
                if (errno == EINTR) continue;
                closeConnection(fd);
                return;
            }
        }
    }

    void handleRequest(Connection* conn) {
        const auto& req = conn->parser().request();
        HttpResponse resp = handler_(req);

        // 设置Connection头
        if (req.keepAlive()) {
            resp.setHeader("Connection", "keep-alive");
        } else {
            resp.setHeader("Connection", "close");
        }

        // 发送响应
        std::string response = resp.serialize();
        sendAll(conn->fd(), response.data(), response.size());
    }

    void sendAll(int fd, const char* data, size_t len) {
        size_t sent = 0;
        while (sent < len) {
            ssize_t n = write(fd, data + sent, len - sent);
            if (n > 0) sent += n;
            else if (errno == EINTR) continue;
            else break;
        }
    }

    void addFd(int fd) {
#ifdef __linux__
        epoll_event ev;
        ev.events = EPOLLIN | EPOLLET;
        ev.data.fd = fd;
        epoll_ctl(epoll_fd_, EPOLL_CTL_ADD, fd, &ev);
#endif
    }

    void closeConnection(int fd) {
#ifdef __linux__
        epoll_ctl(epoll_fd_, EPOLL_CTL_DEL, fd, nullptr);
#endif
        conn_mgr_.removeConnection(fd);
        close(fd);
    }

    uint32_t id_;
    int listen_fd_;
    int epoll_fd_ = -1;
    RequestHandler handler_;
    std::atomic<bool> running_;
    std::thread thread_;
    ConnectionManager conn_mgr_;
};

/**
 * 多线程HTTP服务器
 * 使用SO_REUSEPORT让每个Worker独立accept
 */
class ThreadPoolServer {
public:
    struct Config {
        uint16_t port = 8080;
        uint32_t num_workers = std::thread::hardware_concurrency();
        std::string doc_root;
    };

    explicit ThreadPoolServer(const Config& config)
        : config_(config) {}

    // 设置请求处理器
    void setHandler(RequestHandler handler) {
        handler_ = std::move(handler);
    }

    // 启动服务器
    bool start() {
        for (uint32_t i = 0; i < config_.num_workers; ++i) {
            int listen_fd = createListenSocket();
            if (listen_fd < 0) return false;
            listen_fds_.push_back(listen_fd);

            auto worker = std::make_unique<HttpWorker>(
                i, listen_fd, handler_);
            worker->start();
            workers_.push_back(std::move(worker));
        }

        std::cout << "[Server] Started on port " << config_.port
                  << " with " << config_.num_workers << " workers\n";
        return true;
    }

    void stop() {
        for (auto& worker : workers_) {
            worker->stop();
        }
        workers_.clear();
        for (int fd : listen_fds_) {
            close(fd);
        }
        listen_fds_.clear();
    }

private:
    int createListenSocket() {
        int fd = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK, 0);
        if (fd < 0) return -1;

        int opt = 1;
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
        setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &opt, sizeof(opt));

        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = INADDR_ANY;
        addr.sin_port = htons(config_.port);

        if (bind(fd, (sockaddr*)&addr, sizeof(addr)) < 0) {
            close(fd);
            return -1;
        }
        if (listen(fd, SOMAXCONN) < 0) {
            close(fd);
            return -1;
        }

        return fd;
    }

    Config config_;
    RequestHandler handler_;
    std::vector<int> listen_fds_;
    std::vector<std::unique_ptr<HttpWorker>> workers_;
};

} // namespace http_server
```

---

### 第二周自测问题

**理论理解：**
1. 连接生命周期有哪些状态？各状态之间如何转换？
2. sendfile相比read+write减少了哪些拷贝？
3. writev（scatter-gather I/O）的优势是什么？
4. SO_REUSEPORT方案与单Acceptor方案各有什么优缺点？
5. Keep-Alive超时管理为什么重要？

**代码实践：**
1. 实现连接管理器（含超时清理）
2. 实现Buffer链（支持writev）
3. 实现sendfile零拷贝文件传输
4. 实现基于SO_REUSEPORT的多线程服务器

---

### 第二周检验标准

| 检验项 | 标准 | 自评 |
|--------|------|------|
| 理解连接状态机 | 能描述连接生命周期 | ☐ |
| 理解零拷贝 | 能解释sendfile/mmap优势 | ☐ |
| 理解多线程模型 | 能比较两种多线程方案 | ☐ |
| 实现连接管理 | 代码能正确管理连接超时 | ☐ |
| 实现Buffer链 | 代码能支持writev | ☐ |
| 实现多线程服务器 | 代码能正确处理并发请求 | ☐ |

---

### 第二周时间分配

| 内容 | 时间 |
|------|------|
| 连接状态机设计 | 4小时 |
| 连接管理器实现 | 6小时 |
| 零拷贝I/O学习 | 4小时 |
| Buffer链实现 | 5小时 |
| 多线程架构设计 | 4小时 |
| 多线程服务器实现 | 8小时 |
| 测试与调试 | 4小时 |

---

## 第三周：静态文件服务与中间件（Day 15-21）

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    第三周学习路线图                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Day 15-16            Day 17-18            Day 19-21                      │
│   ┌─────────┐         ┌─────────┐          ┌─────────┐                     │
│   │ 静态    │         │ 中间件  │          │ 路由    │                     │
│   │ 文件    │────────▶│  机制   │─────────▶│  系统   │                     │
│   │ 服务    │         │  实现   │          │  实现   │                     │
│   └─────────┘         └─────────┘          └─────────┘                     │
│       │                   │                    │                           │
│       ▼                   ▼                    ▼                           │
│   LRU缓存            日志/CORS/限流        Trie路由                        │
│   ETag/Range          中间件链              路径参数                        │
│                                                                             │
│   学习目标：实现生产级文件服务、中间件框架和路由系统                          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Day 15-16：静态文件服务（10小时）

#### 条件请求流程

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    条件请求（Conditional Request）流程                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  首次请求：                                                                  │
│  Client ──▶ GET /logo.png                                                  │
│  Server ◀── 200 OK                                                         │
│              ETag: "abc123"                                                 │
│              Last-Modified: Wed, 01 Jan 2025 00:00:00 GMT                  │
│              Content-Length: 50000                                          │
│              [50KB 数据]                                                    │
│                                                                             │
│  后续请求（条件检查）：                                                      │
│  Client ──▶ GET /logo.png                                                  │
│              If-None-Match: "abc123"                                        │
│              If-Modified-Since: Wed, 01 Jan 2025 00:00:00 GMT              │
│                                                                             │
│         ┌─── 文件未修改 ───┐         ┌─── 文件已修改 ───┐                 │
│         ▼                  │         ▼                  │                 │
│  Server ◀── 304 Not Modified       Server ◀── 200 OK                      │
│              (无响应体)             │         ETag: "def456"                │
│              节省带宽!               │         [新数据]                     │
│                                      │                                     │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │  判断规则：                                                        │    │
│  │  1. If-None-Match 匹配 ETag → 304 (优先级高)                     │    │
│  │  2. If-Modified-Since >= Last-Modified → 304                      │    │
│  │  3. 以上不满足 → 200 (返回完整内容)                               │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 代码示例：LRU文件缓存

```cpp
// file_cache.hpp - LRU文件缓存
#pragma once

#include <string>
#include <unordered_map>
#include <list>
#include <mutex>
#include <memory>
#include <chrono>
#include <functional>
#include <sys/stat.h>
#include <fstream>
#include <sstream>

namespace http_server {

/**
 * 缓存条目
 */
struct CacheEntry {
    std::string path;
    std::string content;
    std::string etag;
    std::string content_type;
    time_t mtime;
    size_t size;
    std::chrono::steady_clock::time_point cached_at;
};

/**
 * LRU文件缓存
 */
class FileCache {
public:
    struct Config {
        size_t max_entries = 1000;            // 最大缓存条目数
        size_t max_total_size = 64 * 1024 * 1024; // 最大总缓存64MB
        size_t max_file_size = 1 * 1024 * 1024;   // 单文件最大1MB
        std::chrono::seconds ttl{300};        // 缓存TTL 5分钟
    };

    explicit FileCache(const Config& config = {}) : config_(config) {}

    /**
     * 获取文件内容（带缓存）
     */
    std::shared_ptr<CacheEntry> get(const std::string& path) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = cache_map_.find(path);
        if (it != cache_map_.end()) {
            // 检查是否过期
            auto& entry = *it->second;
            auto age = std::chrono::steady_clock::now() - entry.cached_at;
            if (age < config_.ttl) {
                // 检查文件是否被修改
                struct stat st;
                if (stat(path.c_str(), &st) == 0 && st.st_mtime == entry.mtime) {
                    // 移到LRU前端
                    moveToFront(it->second);
                    return std::make_shared<CacheEntry>(entry);
                }
            }
            // 过期或已修改，移除
            removeLRU(it->second);
            cache_map_.erase(it);
        }

        // 缓存未命中，加载文件
        auto entry = loadFile(path);
        if (!entry) return nullptr;

        // 只缓存小文件
        if (entry->size <= config_.max_file_size) {
            insertEntry(*entry);
        }

        return entry;
    }

    /**
     * 清理过期缓存
     */
    void cleanup() {
        std::lock_guard<std::mutex> lock(mutex_);
        auto now = std::chrono::steady_clock::now();

        auto it = lru_list_.begin();
        while (it != lru_list_.end()) {
            auto age = now - it->cached_at;
            if (age >= config_.ttl) {
                cache_map_.erase(it->path);
                it = lru_list_.erase(it);
            } else {
                ++it;
            }
        }
    }

    size_t size() const { return cache_map_.size(); }
    size_t totalBytes() const { return current_size_; }

private:
    std::shared_ptr<CacheEntry> loadFile(const std::string& path) {
        struct stat st;
        if (stat(path.c_str(), &st) != 0 || !S_ISREG(st.st_mode)) {
            return nullptr;
        }

        std::ifstream file(path, std::ios::binary);
        if (!file.is_open()) return nullptr;

        auto entry = std::make_shared<CacheEntry>();
        entry->path = path;
        entry->size = st.st_size;
        entry->mtime = st.st_mtime;
        entry->cached_at = std::chrono::steady_clock::now();
        entry->content_type = std::string(MimeTypes::detect(path));

        // 生成ETag: mtime-size
        entry->etag = "\"" + std::to_string(st.st_mtime) + "-"
                     + std::to_string(st.st_size) + "\"";

        // 读取文件内容
        std::ostringstream oss;
        oss << file.rdbuf();
        entry->content = oss.str();

        return entry;
    }

    void insertEntry(const CacheEntry& entry) {
        // 确保空间
        while (lru_list_.size() >= config_.max_entries ||
               current_size_ + entry.size > config_.max_total_size) {
            if (lru_list_.empty()) break;
            evictLRU();
        }

        lru_list_.push_front(entry);
        cache_map_[entry.path] = lru_list_.begin();
        current_size_ += entry.size;
    }

    void evictLRU() {
        if (lru_list_.empty()) return;
        auto& back = lru_list_.back();
        current_size_ -= back.size;
        cache_map_.erase(back.path);
        lru_list_.pop_back();
    }

    void moveToFront(std::list<CacheEntry>::iterator it) {
        lru_list_.splice(lru_list_.begin(), lru_list_, it);
    }

    void removeLRU(std::list<CacheEntry>::iterator it) {
        current_size_ -= it->size;
        lru_list_.erase(it);
    }

    Config config_;
    mutable std::mutex mutex_;
    std::list<CacheEntry> lru_list_;
    std::unordered_map<std::string, std::list<CacheEntry>::iterator> cache_map_;
    size_t current_size_ = 0;
};

/**
 * 静态文件处理器（含条件请求和Range）
 */
class StaticFileHandler {
public:
    StaticFileHandler(const std::string& doc_root, FileCache& cache)
        : doc_root_(doc_root), cache_(cache) {}

    HttpResponse handle(const HttpRequest& req) {
        // 安全检查
        std::string safe_path = PathNormalizer::normalize(req.uri_path);
        if (!PathNormalizer::isSafe(safe_path)) {
            return HttpResponse::badRequest("Invalid path");
        }

        std::string file_path = doc_root_ + safe_path;
        if (safe_path == "/") file_path += "index.html";

        // 获取文件（从缓存）
        auto entry = cache_.get(file_path);
        if (!entry) {
            return HttpResponse::notFound();
        }

        // 检查条件请求
        std::string if_none_match = req.headers.get("If-None-Match");
        if (!if_none_match.empty() && if_none_match == entry->etag) {
            HttpResponse resp(304);
            resp.setHeader("ETag", entry->etag);
            return resp;
        }

        // Range请求
        std::string range_header = req.headers.get("Range");
        if (!range_header.empty()) {
            return handleRangeRequest(entry, range_header);
        }

        // 正常响应
        HttpResponse resp(200);
        resp.setHeader("Content-Type", entry->content_type);
        resp.setHeader("ETag", entry->etag);
        resp.setHeader("Cache-Control", "public, max-age=300");
        resp.setBody(entry->content);
        return resp;
    }

private:
    HttpResponse handleRangeRequest(std::shared_ptr<CacheEntry> entry,
                                    const std::string& range_header) {
        // 解析 "bytes=start-end"
        if (range_header.find("bytes=") != 0) {
            return HttpResponse::badRequest("Invalid Range");
        }

        std::string range_spec = range_header.substr(6);
        size_t dash = range_spec.find('-');
        if (dash == std::string::npos) {
            return HttpResponse::badRequest("Invalid Range");
        }

        size_t start = 0, end = entry->size - 1;

        if (dash > 0) {
            start = std::stoull(range_spec.substr(0, dash));
        }
        if (dash + 1 < range_spec.size()) {
            end = std::stoull(range_spec.substr(dash + 1));
        }

        if (start >= entry->size || start > end) {
            HttpResponse resp(416); // Range Not Satisfiable
            resp.setHeader("Content-Range",
                "bytes */" + std::to_string(entry->size));
            return resp;
        }

        end = std::min(end, entry->size - 1);
        size_t length = end - start + 1;

        HttpResponse resp(206);
        resp.setHeader("Content-Type", entry->content_type);
        resp.setHeader("Content-Range",
            "bytes " + std::to_string(start) + "-" + std::to_string(end) +
            "/" + std::to_string(entry->size));
        resp.setBody(entry->content.substr(start, length));
        return resp;
    }

    std::string doc_root_;
    FileCache& cache_;
};

} // namespace http_server
```

---

### Day 17-18：中间件机制（10小时）

#### 中间件执行流程

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    中间件执行流程（洋葱模型）                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   请求 ──────────────────────────────────────────────────────▶              │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │  Logging Middleware (before)                                         │  │
│   │  ┌─────────────────────────────────────────────────────────────┐    │  │
│   │  │  CORS Middleware (before)                                    │    │  │
│   │  │  ┌─────────────────────────────────────────────────────┐    │    │  │
│   │  │  │  RateLimit Middleware (before)                       │    │    │  │
│   │  │  │  ┌─────────────────────────────────────────────┐    │    │    │  │
│   │  │  │  │                                             │    │    │    │  │
│   │  │  │  │           Request Handler                   │    │    │    │  │
│   │  │  │  │         (路由匹配→执行)                     │    │    │    │  │
│   │  │  │  │                                             │    │    │    │  │
│   │  │  │  └─────────────────────────────────────────────┘    │    │    │  │
│   │  │  │  RateLimit Middleware (after)                        │    │    │  │
│   │  │  └─────────────────────────────────────────────────────┘    │    │  │
│   │  │  CORS Middleware (after)                                    │    │  │
│   │  └─────────────────────────────────────────────────────────────┘    │  │
│   │  Logging Middleware (after)                                          │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│   ◀────────────────────────────────────────────────────────── 响应          │
│                                                                             │
│   借鉴自Month-32 Envoy的Filter链设计                                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 代码示例：中间件框架

```cpp
// middleware.hpp - 中间件框架
#pragma once

#include <functional>
#include <vector>
#include <memory>
#include <string>
#include <chrono>
#include <iostream>
#include <unordered_map>
#include <atomic>
#include <mutex>

namespace http_server {

// 中间件上下文
struct Context {
    HttpRequest& request;
    HttpResponse& response;
    std::unordered_map<std::string, std::string> metadata;

    void set(const std::string& key, const std::string& value) {
        metadata[key] = value;
    }

    std::string get(const std::string& key) const {
        auto it = metadata.find(key);
        return it != metadata.end() ? it->second : "";
    }
};

// 下一个中间件的调用函数
using Next = std::function<void(Context&)>;

// 中间件函数类型
using MiddlewareFunc = std::function<void(Context&, Next)>;

/**
 * 中间件管道
 */
class MiddlewarePipeline {
public:
    // 添加中间件
    void use(MiddlewareFunc mw) {
        middlewares_.push_back(std::move(mw));
    }

    // 设置最终处理器
    void setHandler(std::function<void(Context&)> handler) {
        handler_ = std::move(handler);
    }

    // 执行中间件链
    void execute(Context& ctx) {
        size_t index = 0;
        executeNext(ctx, index);
    }

private:
    void executeNext(Context& ctx, size_t index) {
        if (index < middlewares_.size()) {
            auto& mw = middlewares_[index];
            mw(ctx, [this, index](Context& c) {
                executeNext(c, index + 1);
            });
        } else if (handler_) {
            handler_(ctx);
        }
    }

    std::vector<MiddlewareFunc> middlewares_;
    std::function<void(Context&)> handler_;
};

/**
 * 日志中间件
 */
inline MiddlewareFunc loggingMiddleware() {
    return [](Context& ctx, Next next) {
        auto start = std::chrono::steady_clock::now();

        std::string method(methodToString(ctx.request.method));
        std::string path = ctx.request.uri_path;

        // 执行后续中间件
        next(ctx);

        auto end = std::chrono::steady_clock::now();
        auto ms = std::chrono::duration_cast<std::chrono::microseconds>(
            end - start).count();

        std::cout << method << " " << path << " -> "
                  << ctx.response.status() << " ("
                  << ms << "us)\n";
    };
}

/**
 * CORS中间件
 */
inline MiddlewareFunc corsMiddleware(
    const std::string& allowed_origins = "*",
    const std::string& allowed_methods = "GET, POST, PUT, DELETE, OPTIONS") {

    return [=](Context& ctx, Next next) {
        // 添加CORS头
        ctx.response.setHeader("Access-Control-Allow-Origin", allowed_origins);
        ctx.response.setHeader("Access-Control-Allow-Methods", allowed_methods);
        ctx.response.setHeader("Access-Control-Allow-Headers",
                              "Content-Type, Authorization");

        // 预检请求
        if (ctx.request.method == HttpMethod::OPTIONS) {
            ctx.response.setStatus(204);
            ctx.response.setHeader("Access-Control-Max-Age", "86400");
            return; // 不继续执行
        }

        next(ctx);
    };
}

/**
 * 限流中间件（令牌桶算法）
 */
class RateLimiter {
public:
    RateLimiter(double rate, size_t burst)
        : rate_(rate), burst_(burst), tokens_(burst)
        , last_refill_(std::chrono::steady_clock::now()) {}

    MiddlewareFunc middleware() {
        return [this](Context& ctx, Next next) {
            if (tryAcquire()) {
                next(ctx);
            } else {
                ctx.response.setStatus(429);
                ctx.response.setHeader("Retry-After", "1");
                ctx.response.setBody("Too Many Requests");
            }
        };
    }

private:
    bool tryAcquire() {
        std::lock_guard<std::mutex> lock(mutex_);
        refill();
        if (tokens_ >= 1.0) {
            tokens_ -= 1.0;
            return true;
        }
        return false;
    }

    void refill() {
        auto now = std::chrono::steady_clock::now();
        auto elapsed = std::chrono::duration<double>(now - last_refill_).count();
        tokens_ = std::min(static_cast<double>(burst_), tokens_ + elapsed * rate_);
        last_refill_ = now;
    }

    double rate_;
    size_t burst_;
    double tokens_;
    std::chrono::steady_clock::time_point last_refill_;
    std::mutex mutex_;
};

} // namespace http_server
```

---

### Day 19-21：高级路由系统（15小时）

#### Trie树路由结构

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Trie树路由匹配                                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  注册的路由：                                                                │
│  GET  /api/users          → listUsers                                      │
│  GET  /api/users/:id      → getUser                                        │
│  POST /api/users          → createUser                                     │
│  GET  /api/users/:id/posts → getUserPosts                                  │
│  GET  /static/*filepath   → staticFile                                     │
│                                                                             │
│  Trie树结构：                                                               │
│  ┌─────────┐                                                               │
│  │  root   │                                                               │
│  └────┬────┘                                                               │
│       │                                                                     │
│       ├──── "api" ─────────┐                                               │
│       │                    │                                               │
│       │                    ├──── "users" ──┬── [GET] listUsers             │
│       │                    │               │── [POST] createUser           │
│       │                    │               │                               │
│       │                    │               └── ":id" ──┬── [GET] getUser  │
│       │                    │                           │                   │
│       │                    │                           └── "posts"         │
│       │                    │                               [GET]           │
│       │                    │                               getUserPosts    │
│       │                    │                                               │
│       └──── "static" ──── "*filepath" ── [GET] staticFile                 │
│                                                                             │
│  匹配规则：                                                                  │
│  1. 精确匹配优先                                                            │
│  2. 参数匹配（:param）次之                                                  │
│  3. 通配符匹配（*param）最后                                                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 代码示例：Trie路由器

```cpp
// trie_router.hpp - Trie树路由器
#pragma once

#include <string>
#include <unordered_map>
#include <vector>
#include <memory>
#include <functional>
#include <iostream>

namespace http_server {

/**
 * 路径参数
 */
using PathParams = std::unordered_map<std::string, std::string>;
using RouteHandler = std::function<HttpResponse(const HttpRequest&, const PathParams&)>;

/**
 * Trie节点
 */
struct TrieNode {
    std::unordered_map<std::string, std::unique_ptr<TrieNode>> children;
    std::unique_ptr<TrieNode> param_child;     // :param
    std::unique_ptr<TrieNode> wildcard_child;  // *param
    std::string param_name;
    std::string wildcard_name;

    // 每个HTTP方法对应一个handler
    std::unordered_map<std::string, RouteHandler> handlers;
};

/**
 * Trie路由器
 */
class TrieRouter {
public:
    TrieRouter() : root_(std::make_unique<TrieNode>()) {}

    // 注册路由
    void addRoute(HttpMethod method, const std::string& pattern,
                  RouteHandler handler) {
        auto segments = splitPath(pattern);
        auto* node = root_.get();

        for (const auto& seg : segments) {
            if (seg.empty()) continue;

            if (seg[0] == ':') {
                // 参数节点
                if (!node->param_child) {
                    node->param_child = std::make_unique<TrieNode>();
                    node->param_name = seg.substr(1);
                }
                node = node->param_child.get();
            } else if (seg[0] == '*') {
                // 通配符节点
                if (!node->wildcard_child) {
                    node->wildcard_child = std::make_unique<TrieNode>();
                    node->wildcard_name = seg.substr(1);
                }
                node = node->wildcard_child.get();
                break; // 通配符后不再有子节点
            } else {
                // 精确匹配节点
                if (!node->children.count(seg)) {
                    node->children[seg] = std::make_unique<TrieNode>();
                }
                node = node->children[seg].get();
            }
        }

        std::string method_str(methodToString(method));
        node->handlers[method_str] = std::move(handler);
    }

    // 快捷方法
    void GET(const std::string& pattern, RouteHandler handler) {
        addRoute(HttpMethod::GET, pattern, std::move(handler));
    }

    void POST(const std::string& pattern, RouteHandler handler) {
        addRoute(HttpMethod::POST, pattern, std::move(handler));
    }

    void PUT(const std::string& pattern, RouteHandler handler) {
        addRoute(HttpMethod::PUT, pattern, std::move(handler));
    }

    void DELETE_(const std::string& pattern, RouteHandler handler) {
        addRoute(HttpMethod::DELETE, pattern, std::move(handler));
    }

    /**
     * 匹配路由
     */
    struct MatchResult {
        RouteHandler handler;
        PathParams params;
        bool found = false;
    };

    MatchResult match(HttpMethod method, const std::string& path) {
        auto segments = splitPath(path);
        PathParams params;
        auto* node = findNode(root_.get(), segments, 0, params);

        if (!node) return {nullptr, {}, false};

        std::string method_str(methodToString(method));
        auto it = node->handlers.find(method_str);
        if (it == node->handlers.end()) return {nullptr, {}, false};

        return {it->second, params, true};
    }

    // 路由分组
    class RouteGroup {
    public:
        RouteGroup(TrieRouter& router, const std::string& prefix)
            : router_(router), prefix_(prefix) {}

        void GET(const std::string& path, RouteHandler handler) {
            router_.GET(prefix_ + path, std::move(handler));
        }

        void POST(const std::string& path, RouteHandler handler) {
            router_.POST(prefix_ + path, std::move(handler));
        }

        RouteGroup group(const std::string& prefix) {
            return RouteGroup(router_, prefix_ + prefix);
        }

    private:
        TrieRouter& router_;
        std::string prefix_;
    };

    RouteGroup group(const std::string& prefix) {
        return RouteGroup(*this, prefix);
    }

private:
    std::vector<std::string> splitPath(const std::string& path) {
        std::vector<std::string> segments;
        std::string current;

        for (char c : path) {
            if (c == '/') {
                if (!current.empty()) {
                    segments.push_back(current);
                    current.clear();
                }
            } else {
                current += c;
            }
        }
        if (!current.empty()) segments.push_back(current);

        return segments;
    }

    TrieNode* findNode(TrieNode* node,
                       const std::vector<std::string>& segments,
                       size_t index, PathParams& params) {
        if (index == segments.size()) {
            return node->handlers.empty() ? nullptr : node;
        }

        const auto& seg = segments[index];

        // 1. 精确匹配（优先级最高）
        auto it = node->children.find(seg);
        if (it != node->children.end()) {
            auto* result = findNode(it->second.get(), segments,
                                    index + 1, params);
            if (result) return result;
        }

        // 2. 参数匹配
        if (node->param_child) {
            params[node->param_name] = seg;
            auto* result = findNode(node->param_child.get(), segments,
                                    index + 1, params);
            if (result) return result;
            params.erase(node->param_name);
        }

        // 3. 通配符匹配
        if (node->wildcard_child) {
            std::string remaining;
            for (size_t i = index; i < segments.size(); ++i) {
                if (i > index) remaining += "/";
                remaining += segments[i];
            }
            params[node->wildcard_name] = remaining;
            return node->wildcard_child.get();
        }

        return nullptr;
    }

    std::unique_ptr<TrieNode> root_;
};

} // namespace http_server
```

---

### 第三周自测问题

**理论理解：**
1. ETag和Last-Modified各自的优缺点是什么？
2. Range请求在哪些场景下有用？
3. 中间件的洋葱模型是如何工作的？
4. 令牌桶限流算法的原理是什么？
5. Trie树路由匹配的优先级规则是什么？

**代码实践：**
1. 实现LRU文件缓存
2. 实现条件请求（304响应）
3. 实现中间件管道
4. 实现限流中间件
5. 实现Trie路由器（含路径参数）

---

### 第三周检验标准

| 检验项 | 标准 | 自评 |
|--------|------|------|
| 理解条件请求 | 能解释ETag/304流程 | ☐ |
| 理解中间件模式 | 能描述洋葱模型 | ☐ |
| 理解路由匹配 | 能解释Trie树匹配规则 | ☐ |
| 实现文件缓存 | 代码能正确缓存和过期 | ☐ |
| 实现中间件框架 | 代码能正确执行中间件链 | ☐ |
| 实现路由器 | 代码能正确匹配路径参数 | ☐ |

---

### 第三周时间分配

| 内容 | 时间 |
|------|------|
| 文件缓存设计 | 4小时 |
| 条件请求与Range | 5小时 |
| 文件服务实现 | 6小时 |
| 中间件框架设计 | 4小时 |
| 中间件实现 | 5小时 |
| 路由系统设计 | 4小时 |
| Trie路由器实现 | 7小时 |

---

## 第四周：完整服务器与性能优化（Day 22-28）

> **本周目标**：了解HTTP/2基础，掌握性能优化技术，最终组装完整的Mini-HTTP服务器

```
第四周学习路线图：

    Day 22-23              Day 24-25              Day 26-28
    HTTP/2基础             性能优化               完整服务器
    ┌─────────┐           ┌─────────┐           ┌─────────┐
    │ 帧结构   │──────────→│ 对象池   │──────────→│ 组件组装 │
    │ 多路复用 │           │ Arena   │           │ 优雅关闭 │
    │ HPACK   │           │ 无锁统计 │           │ 信号处理 │
    │ 流状态机 │           │ 压测方法 │           │ 配置系统 │
    └─────────┘           └─────────┘           └─────────┘
         │                     │                     │
         ▼                     ▼                     ▼
    理解HTTP/2           掌握优化技术          生产级HTTP服务器
    帧层协议             内存/CPU优化
```

---

### Day 22-23：HTTP/2基础（10小时）

#### HTTP/2协议概述

HTTP/2是HTTP协议的第二个主要版本，解决了HTTP/1.1的核心性能问题：

```
HTTP/1.1 vs HTTP/2 核心差异：

HTTP/1.1 问题：
┌─────────────────────────────────────────────┐
│  连接1: GET /index.html ──→ 响应 ──→        │
│         GET /style.css  ──→ 响应 ──→        │  串行请求
│         GET /script.js  ──→ 响应 ──→        │  队头阻塞
│                                             │
│  连接2: GET /image1.png ──→ 响应 ──→        │  需要多连接
│         GET /image2.png ──→ 响应 ──→        │  来并行
│                                             │
│  连接3: GET /image3.png ──→ 响应 ──→        │  连接开销大
│         GET /font.woff  ──→ 响应 ──→        │
└─────────────────────────────────────────────┘

HTTP/2 解决方案：
┌─────────────────────────────────────────────┐
│  单一连接上的多路复用：                        │
│                                             │
│  Stream 1: ┤██ GET /index.html ██├          │
│  Stream 3: ┤███ GET /style.css ███├         │
│  Stream 5: ┤█ GET /script.js █├             │  所有请求
│  Stream 7: ┤████ GET /image1.png ████├      │  在一个连接上
│  Stream 9: ┤██ GET /image2.png ██├          │  并行传输
│  Stream 11:┤███ GET /image3.png ███├        │
│  Stream 13:┤█ GET /font.woff █├             │
│                                             │
│  ← 二进制帧在同一连接上交错传输 →              │
└─────────────────────────────────────────────┘
```

#### HTTP/2帧结构

HTTP/2的基本通信单元是帧（Frame），所有通信在一个TCP连接上完成：

```
HTTP/2 帧格式（9字节固定头部 + 可变载荷）：

 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                 Length (24)                   |   Type (8)    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|  Flags (8)  |R|         Stream Identifier (31)               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                   Frame Payload (0...)                      ...
+---------------------------------------------------------------+

帧类型：
┌──────────────────────────────────────────────┐
│  Type 0: DATA          - 传输请求/响应正文     │
│  Type 1: HEADERS       - 传输HTTP头部         │
│  Type 2: PRIORITY      - 流优先级（已废弃）     │
│  Type 3: RST_STREAM    - 取消流               │
│  Type 4: SETTINGS      - 连接配置参数          │
│  Type 5: PUSH_PROMISE  - 服务器推送预告        │
│  Type 6: PING          - 心跳/RTT测量         │
│  Type 7: GOAWAY        - 优雅关闭连接          │
│  Type 8: WINDOW_UPDATE - 流量控制窗口更新       │
│  Type 9: CONTINUATION  - 头部块延续            │
└──────────────────────────────────────────────┘

流（Stream）与帧的关系：
┌─────────────────────────────────────────────────────┐
│  Connection (TCP)                                   │
│  ┌───────────────────────────────────────────────┐  │
│  │ Stream 1 (请求/响应对)                         │  │
│  │  HEADERS帧 → DATA帧 → DATA帧                  │  │
│  ├───────────────────────────────────────────────┤  │
│  │ Stream 3 (请求/响应对)                         │  │
│  │  HEADERS帧 → DATA帧                           │  │
│  ├───────────────────────────────────────────────┤  │
│  │ Stream 5 (请求/响应对)                         │  │
│  │  HEADERS帧 → DATA帧 → DATA帧 → DATA帧         │  │
│  └───────────────────────────────────────────────┘  │
│                                                     │
│  实际传输（帧交错）：                                 │
│  [H:1][H:3][D:1][H:5][D:3][D:1][D:5][D:5][D:5]    │
│   ↑     ↑    ↑    ↑    ↑    ↑    ↑    ↑    ↑      │
│   Stream标识符区分不同流                              │
└─────────────────────────────────────────────────────┘
```

#### HTTP/2流状态机

```
流状态转换图：

                         send PP /
                        recv PP
                    +--------+
              send H|        |recv H
     ,--------|  idle  |--------.
    /         |        |         \
   v          +--------+          v
+----------+                  +----------+
|          |                  |          |
|  open    |                  |  open    |
| (half    |     send/recv    | (half    |
| closed   |<--- RST_STREAM->| closed   |
| remote)  |                  | local)   |
|          |                  |          |
+----------+                  +----------+
   |     |                       |     |
   |     | send ES               |     |
   |     | recv ES               |     |
   |     v                       |     v
   | +----------+           +----------+ |
   | |  half    |           |  half    | |
   | |  closed  |           |  closed  | |
   | | (remote) |           | (local)  | |
   | +----------+           +----------+ |
   |     |                       |     |
   |     | send ES/recv ES       |     |
   |     v                       v     |
   |  +-------------------------------+ |
   |  |           closed              | |
   |  +-------------------------------+ |
   |              ↑                      |
   +----- send/recv RST_STREAM ---------+

状态说明：
  idle          : 初始状态
  open          : 可以发送和接收帧
  half closed   : 一端已发送END_STREAM
  closed        : 双端都已结束

  H  = HEADERS帧
  PP = PUSH_PROMISE帧
  ES = END_STREAM标志
  RST= RST_STREAM帧
```

#### HPACK头部压缩

```
HPACK压缩原理：

传统HTTP/1.1（每次发送完整头部）：
┌──────────────────────────────────┐
│ 请求1:                           │
│   :method: GET                   │   ← 重复
│   :path: /index.html             │
│   :scheme: https                 │   ← 重复
│   host: example.com              │   ← 重复
│   accept: text/html              │   ← 重复
│   cookie: session=abc123def...   │   ← 很长
├──────────────────────────────────┤
│ 请求2:                           │
│   :method: GET                   │   ← 重复！
│   :path: /style.css              │   ← 仅此不同
│   :scheme: https                 │   ← 重复！
│   host: example.com              │   ← 重复！
│   accept: text/css               │   ← 略有不同
│   cookie: session=abc123def...   │   ← 重复！
└──────────────────────────────────┘

HPACK压缩后：
┌──────────────────────────────────┐
│ 请求1（构建动态表）：              │
│   [索引2] :method GET            │  2字节
│   [字面] :path /index.html       │  16字节
│   [索引7] :scheme https          │  2字节
│   [字面+索引] host example.com   │  15字节→加入动态表
│   [字面+索引] accept text/html   │  12字节→加入动态表
│   [字面+索引] cookie session=... │  25字节→加入动态表
│                                  │  总计: ~72字节
├──────────────────────────────────┤
│ 请求2（利用动态表）：              │
│   [索引2] :method GET            │  2字节
│   [字面] :path /style.css        │  14字节
│   [索引7] :scheme https          │  2字节
│   [索引62] host example.com      │  2字节  ← 索引引用！
│   [字面] accept text/css         │  11字节
│   [索引64] cookie session=...    │  2字节  ← 索引引用！
│                                  │  总计: ~33字节（节省54%）
└──────────────────────────────────┘

静态表（预定义61个常用头部）：
┌───────┬────────────────┬───────────────┐
│ Index │ Header Name    │ Header Value  │
├───────┼────────────────┼───────────────┤
│   1   │ :authority     │               │
│   2   │ :method        │ GET           │
│   3   │ :method        │ POST          │
│   4   │ :path          │ /             │
│   5   │ :path          │ /index.html   │
│   6   │ :scheme        │ http          │
│   7   │ :scheme        │ https         │
│  ...  │ ...            │ ...           │
│  61   │ www-auth...    │               │
└───────┴────────────────┴───────────────┘
```

#### 代码示例：HTTP/2帧解析器

```cpp
// http2_frame.hpp - HTTP/2帧解析器（教学简化版）
#pragma once
#include <cstdint>
#include <cstring>
#include <vector>
#include <string>
#include <string_view>
#include <unordered_map>
#include <stdexcept>
#include <algorithm>
#include <cassert>

namespace http2 {

// ============================================================
// HTTP/2帧类型定义
// ============================================================
enum class FrameType : uint8_t {
    DATA          = 0x0,
    HEADERS       = 0x1,
    PRIORITY      = 0x2,
    RST_STREAM    = 0x3,
    SETTINGS      = 0x4,
    PUSH_PROMISE  = 0x5,
    PING          = 0x6,
    GOAWAY        = 0x7,
    WINDOW_UPDATE = 0x8,
    CONTINUATION  = 0x9
};

// 帧标志位
namespace FrameFlags {
    constexpr uint8_t END_STREAM  = 0x1;   // DATA, HEADERS
    constexpr uint8_t ACK         = 0x1;   // SETTINGS, PING
    constexpr uint8_t END_HEADERS = 0x4;   // HEADERS, PUSH_PROMISE, CONTINUATION
    constexpr uint8_t PADDED      = 0x8;   // DATA, HEADERS
    constexpr uint8_t PRIORITY    = 0x20;  // HEADERS
}

// ============================================================
// 帧头部（固定9字节）
// ============================================================
struct FrameHeader {
    uint32_t length;       // 载荷长度（24位，最大16384字节）
    FrameType type;        // 帧类型
    uint8_t flags;         // 标志位
    uint32_t stream_id;    // 流标识符（31位，最高位保留）

    // 帧头部大小常量
    static constexpr size_t SIZE = 9;
    // 默认最大帧大小
    static constexpr uint32_t DEFAULT_MAX_FRAME_SIZE = 16384;
    static constexpr uint32_t MAX_FRAME_SIZE_LIMIT = 16777215; // 2^24 - 1

    // 检查特定标志
    bool hasFlag(uint8_t flag) const { return (flags & flag) != 0; }
    bool isEndStream() const { return hasFlag(FrameFlags::END_STREAM); }
    bool isEndHeaders() const { return hasFlag(FrameFlags::END_HEADERS); }
    bool isAck() const { return hasFlag(FrameFlags::ACK); }
    bool isPadded() const { return hasFlag(FrameFlags::PADDED); }
    bool hasPriority() const { return hasFlag(FrameFlags::PRIORITY); }

    // 获取帧类型名称（调试用）
    const char* typeName() const {
        switch (type) {
            case FrameType::DATA:          return "DATA";
            case FrameType::HEADERS:       return "HEADERS";
            case FrameType::PRIORITY:      return "PRIORITY";
            case FrameType::RST_STREAM:    return "RST_STREAM";
            case FrameType::SETTINGS:      return "SETTINGS";
            case FrameType::PUSH_PROMISE:  return "PUSH_PROMISE";
            case FrameType::PING:          return "PING";
            case FrameType::GOAWAY:        return "GOAWAY";
            case FrameType::WINDOW_UPDATE: return "WINDOW_UPDATE";
            case FrameType::CONTINUATION:  return "CONTINUATION";
            default:                       return "UNKNOWN";
        }
    }
};

// ============================================================
// HTTP/2错误码
// ============================================================
enum class ErrorCode : uint32_t {
    NO_ERROR            = 0x0,
    PROTOCOL_ERROR      = 0x1,
    INTERNAL_ERROR      = 0x2,
    FLOW_CONTROL_ERROR  = 0x3,
    SETTINGS_TIMEOUT    = 0x4,
    STREAM_CLOSED       = 0x5,
    FRAME_SIZE_ERROR    = 0x6,
    REFUSED_STREAM      = 0x7,
    CANCEL              = 0x8,
    COMPRESSION_ERROR   = 0x9,
    CONNECT_ERROR       = 0xa,
    ENHANCE_YOUR_CALM   = 0xb,
    INADEQUATE_SECURITY = 0xc,
    HTTP_1_1_REQUIRED   = 0xd
};

// ============================================================
// SETTINGS参数
// ============================================================
enum class SettingsId : uint16_t {
    HEADER_TABLE_SIZE      = 0x1,
    ENABLE_PUSH            = 0x2,
    MAX_CONCURRENT_STREAMS = 0x3,
    INITIAL_WINDOW_SIZE    = 0x4,
    MAX_FRAME_SIZE         = 0x5,
    MAX_HEADER_LIST_SIZE   = 0x6
};

// ============================================================
// 帧编解码器
// ============================================================
class FrameCodec {
public:
    // 编码帧头部到缓冲区（9字节）
    static void encodeHeader(uint8_t* buf, const FrameHeader& header) {
        // Length: 24 bits (big-endian)
        buf[0] = (header.length >> 16) & 0xFF;
        buf[1] = (header.length >> 8) & 0xFF;
        buf[2] = header.length & 0xFF;
        // Type: 8 bits
        buf[3] = static_cast<uint8_t>(header.type);
        // Flags: 8 bits
        buf[4] = header.flags;
        // Stream ID: 31 bits (big-endian, R bit = 0)
        buf[5] = (header.stream_id >> 24) & 0x7F;  // 清除保留位
        buf[6] = (header.stream_id >> 16) & 0xFF;
        buf[7] = (header.stream_id >> 8) & 0xFF;
        buf[8] = header.stream_id & 0xFF;
    }

    // 解码帧头部（从9字节缓冲区）
    static FrameHeader decodeHeader(const uint8_t* buf) {
        FrameHeader header;
        // Length: 24 bits
        header.length = (static_cast<uint32_t>(buf[0]) << 16) |
                        (static_cast<uint32_t>(buf[1]) << 8) |
                        static_cast<uint32_t>(buf[2]);
        // Type
        header.type = static_cast<FrameType>(buf[3]);
        // Flags
        header.flags = buf[4];
        // Stream ID: 31 bits (忽略保留位)
        header.stream_id = (static_cast<uint32_t>(buf[5] & 0x7F) << 24) |
                           (static_cast<uint32_t>(buf[6]) << 16) |
                           (static_cast<uint32_t>(buf[7]) << 8) |
                           static_cast<uint32_t>(buf[8]);
        return header;
    }

    // 构建DATA帧
    static std::vector<uint8_t> buildDataFrame(
        uint32_t stream_id,
        const uint8_t* data,
        size_t len,
        bool end_stream = false
    ) {
        std::vector<uint8_t> frame(FrameHeader::SIZE + len);
        FrameHeader header;
        header.length = static_cast<uint32_t>(len);
        header.type = FrameType::DATA;
        header.flags = end_stream ? FrameFlags::END_STREAM : 0;
        header.stream_id = stream_id;
        encodeHeader(frame.data(), header);
        if (len > 0) {
            std::memcpy(frame.data() + FrameHeader::SIZE, data, len);
        }
        return frame;
    }

    // 构建SETTINGS帧
    static std::vector<uint8_t> buildSettingsFrame(
        const std::vector<std::pair<SettingsId, uint32_t>>& settings,
        bool ack = false
    ) {
        size_t payload_len = ack ? 0 : settings.size() * 6;
        std::vector<uint8_t> frame(FrameHeader::SIZE + payload_len);
        FrameHeader header;
        header.length = static_cast<uint32_t>(payload_len);
        header.type = FrameType::SETTINGS;
        header.flags = ack ? FrameFlags::ACK : 0;
        header.stream_id = 0;  // SETTINGS必须在流0
        encodeHeader(frame.data(), header);

        if (!ack) {
            uint8_t* p = frame.data() + FrameHeader::SIZE;
            for (const auto& [id, value] : settings) {
                // Identifier: 16 bits
                p[0] = (static_cast<uint16_t>(id) >> 8) & 0xFF;
                p[1] = static_cast<uint16_t>(id) & 0xFF;
                // Value: 32 bits
                p[2] = (value >> 24) & 0xFF;
                p[3] = (value >> 16) & 0xFF;
                p[4] = (value >> 8) & 0xFF;
                p[5] = value & 0xFF;
                p += 6;
            }
        }
        return frame;
    }

    // 构建WINDOW_UPDATE帧
    static std::vector<uint8_t> buildWindowUpdateFrame(
        uint32_t stream_id, uint32_t increment
    ) {
        std::vector<uint8_t> frame(FrameHeader::SIZE + 4);
        FrameHeader header;
        header.length = 4;
        header.type = FrameType::WINDOW_UPDATE;
        header.flags = 0;
        header.stream_id = stream_id;
        encodeHeader(frame.data(), header);
        uint8_t* p = frame.data() + FrameHeader::SIZE;
        p[0] = (increment >> 24) & 0x7F;  // R bit = 0
        p[1] = (increment >> 16) & 0xFF;
        p[2] = (increment >> 8) & 0xFF;
        p[3] = increment & 0xFF;
        return frame;
    }

    // 构建GOAWAY帧
    static std::vector<uint8_t> buildGoawayFrame(
        uint32_t last_stream_id, ErrorCode error_code,
        std::string_view debug_data = ""
    ) {
        size_t payload_len = 8 + debug_data.size();
        std::vector<uint8_t> frame(FrameHeader::SIZE + payload_len);
        FrameHeader header;
        header.length = static_cast<uint32_t>(payload_len);
        header.type = FrameType::GOAWAY;
        header.flags = 0;
        header.stream_id = 0;  // GOAWAY必须在流0
        encodeHeader(frame.data(), header);
        uint8_t* p = frame.data() + FrameHeader::SIZE;
        // Last-Stream-ID
        p[0] = (last_stream_id >> 24) & 0x7F;
        p[1] = (last_stream_id >> 16) & 0xFF;
        p[2] = (last_stream_id >> 8) & 0xFF;
        p[3] = last_stream_id & 0xFF;
        // Error Code
        uint32_t ec = static_cast<uint32_t>(error_code);
        p[4] = (ec >> 24) & 0xFF;
        p[5] = (ec >> 16) & 0xFF;
        p[6] = (ec >> 8) & 0xFF;
        p[7] = ec & 0xFF;
        // Debug Data
        if (!debug_data.empty()) {
            std::memcpy(p + 8, debug_data.data(), debug_data.size());
        }
        return frame;
    }

    // 构建PING帧
    static std::vector<uint8_t> buildPingFrame(
        const uint8_t opaque_data[8], bool ack = false
    ) {
        std::vector<uint8_t> frame(FrameHeader::SIZE + 8);
        FrameHeader header;
        header.length = 8;
        header.type = FrameType::PING;
        header.flags = ack ? FrameFlags::ACK : 0;
        header.stream_id = 0;
        encodeHeader(frame.data(), header);
        std::memcpy(frame.data() + FrameHeader::SIZE, opaque_data, 8);
        return frame;
    }

    // 构建RST_STREAM帧
    static std::vector<uint8_t> buildRstStreamFrame(
        uint32_t stream_id, ErrorCode error_code
    ) {
        std::vector<uint8_t> frame(FrameHeader::SIZE + 4);
        FrameHeader header;
        header.length = 4;
        header.type = FrameType::RST_STREAM;
        header.flags = 0;
        header.stream_id = stream_id;
        encodeHeader(frame.data(), header);
        uint32_t ec = static_cast<uint32_t>(error_code);
        uint8_t* p = frame.data() + FrameHeader::SIZE;
        p[0] = (ec >> 24) & 0xFF;
        p[1] = (ec >> 16) & 0xFF;
        p[2] = (ec >> 8) & 0xFF;
        p[3] = ec & 0xFF;
        return frame;
    }
};

// ============================================================
// 流（Stream）管理
// ============================================================
enum class StreamState {
    IDLE,
    OPEN,
    HALF_CLOSED_LOCAL,
    HALF_CLOSED_REMOTE,
    CLOSED
};

struct Stream {
    uint32_t id;
    StreamState state = StreamState::IDLE;
    int32_t send_window;     // 发送窗口
    int32_t recv_window;     // 接收窗口

    // 请求信息
    std::unordered_map<std::string, std::string> headers;
    std::vector<uint8_t> data;

    Stream(uint32_t id, int32_t initial_window = 65535)
        : id(id), send_window(initial_window), recv_window(initial_window) {}

    // 状态转换
    bool receiveHeaders(bool end_stream) {
        switch (state) {
            case StreamState::IDLE:
                state = end_stream ? StreamState::HALF_CLOSED_REMOTE
                                   : StreamState::OPEN;
                return true;
            default:
                return false;  // 协议错误
        }
    }

    bool receiveData(const uint8_t* payload, size_t len, bool end_stream) {
        if (state != StreamState::OPEN &&
            state != StreamState::HALF_CLOSED_LOCAL) {
            return false;
        }
        data.insert(data.end(), payload, payload + len);
        recv_window -= static_cast<int32_t>(len);
        if (end_stream) {
            if (state == StreamState::OPEN) {
                state = StreamState::HALF_CLOSED_REMOTE;
            } else {
                state = StreamState::CLOSED;
            }
        }
        return true;
    }

    bool sendData(size_t len, bool end_stream) {
        if (state != StreamState::OPEN &&
            state != StreamState::HALF_CLOSED_REMOTE) {
            return false;
        }
        send_window -= static_cast<int32_t>(len);
        if (end_stream) {
            if (state == StreamState::OPEN) {
                state = StreamState::HALF_CLOSED_LOCAL;
            } else {
                state = StreamState::CLOSED;
            }
        }
        return true;
    }

    void reset() { state = StreamState::CLOSED; }

    const char* stateName() const {
        switch (state) {
            case StreamState::IDLE:               return "IDLE";
            case StreamState::OPEN:               return "OPEN";
            case StreamState::HALF_CLOSED_LOCAL:  return "HALF_CLOSED_LOCAL";
            case StreamState::HALF_CLOSED_REMOTE: return "HALF_CLOSED_REMOTE";
            case StreamState::CLOSED:             return "CLOSED";
            default:                              return "UNKNOWN";
        }
    }
};

// ============================================================
// HTTP/2连接管理器（简化版）
// ============================================================
class Http2Connection {
public:
    Http2Connection() {
        // 初始化默认SETTINGS
        local_settings_[SettingsId::HEADER_TABLE_SIZE]      = 4096;
        local_settings_[SettingsId::ENABLE_PUSH]            = 1;
        local_settings_[SettingsId::MAX_CONCURRENT_STREAMS] = 100;
        local_settings_[SettingsId::INITIAL_WINDOW_SIZE]    = 65535;
        local_settings_[SettingsId::MAX_FRAME_SIZE]         = 16384;
        local_settings_[SettingsId::MAX_HEADER_LIST_SIZE]   = 8192;
    }

    // 获取/创建流
    Stream& getOrCreateStream(uint32_t stream_id) {
        auto it = streams_.find(stream_id);
        if (it == streams_.end()) {
            int32_t window = static_cast<int32_t>(
                local_settings_[SettingsId::INITIAL_WINDOW_SIZE]);
            auto [iter, _] = streams_.emplace(stream_id,
                                              Stream(stream_id, window));
            if (stream_id > last_stream_id_) {
                last_stream_id_ = stream_id;
            }
            return iter->second;
        }
        return it->second;
    }

    // 处理接收到的帧
    bool processFrame(const FrameHeader& header, const uint8_t* payload) {
        switch (header.type) {
            case FrameType::SETTINGS:
                return handleSettings(header, payload);
            case FrameType::WINDOW_UPDATE:
                return handleWindowUpdate(header, payload);
            case FrameType::PING:
                return handlePing(header, payload);
            case FrameType::GOAWAY:
                return handleGoaway(header, payload);
            case FrameType::DATA:
                return handleData(header, payload);
            case FrameType::RST_STREAM:
                return handleRstStream(header, payload);
            default:
                return true;  // 忽略未知帧类型
        }
    }

    // 连接级流量控制窗口
    int32_t connectionSendWindow() const { return connection_send_window_; }
    int32_t connectionRecvWindow() const { return connection_recv_window_; }
    uint32_t lastStreamId() const { return last_stream_id_; }
    bool isGoaway() const { return goaway_received_; }

private:
    bool handleSettings(const FrameHeader& header, const uint8_t* payload) {
        if (header.stream_id != 0) return false;
        if (header.isAck()) return true;  // ACK确认

        // 解析SETTINGS参数
        for (uint32_t i = 0; i < header.length; i += 6) {
            uint16_t id = (static_cast<uint16_t>(payload[i]) << 8) |
                          payload[i + 1];
            uint32_t value = (static_cast<uint32_t>(payload[i + 2]) << 24) |
                             (static_cast<uint32_t>(payload[i + 3]) << 16) |
                             (static_cast<uint32_t>(payload[i + 4]) << 8) |
                             static_cast<uint32_t>(payload[i + 5]);

            peer_settings_[static_cast<SettingsId>(id)] = value;
        }
        // 需要发送SETTINGS ACK
        settings_ack_pending_ = true;
        return true;
    }

    bool handleWindowUpdate(const FrameHeader& header, const uint8_t* payload) {
        uint32_t increment = (static_cast<uint32_t>(payload[0] & 0x7F) << 24) |
                             (static_cast<uint32_t>(payload[1]) << 16) |
                             (static_cast<uint32_t>(payload[2]) << 8) |
                             static_cast<uint32_t>(payload[3]);
        if (increment == 0) return false;  // 协议错误

        if (header.stream_id == 0) {
            connection_send_window_ += increment;
        } else {
            auto it = streams_.find(header.stream_id);
            if (it != streams_.end()) {
                it->second.send_window += increment;
            }
        }
        return true;
    }

    bool handlePing(const FrameHeader& header, const uint8_t* payload) {
        if (header.stream_id != 0) return false;
        if (header.length != 8) return false;
        if (header.isAck()) return true;
        // 需要回复PING ACK
        ping_ack_data_.assign(payload, payload + 8);
        ping_ack_pending_ = true;
        return true;
    }

    bool handleGoaway(const FrameHeader& header, const uint8_t* payload) {
        if (header.stream_id != 0) return false;
        goaway_received_ = true;
        goaway_last_stream_ = (static_cast<uint32_t>(payload[0] & 0x7F) << 24) |
                              (static_cast<uint32_t>(payload[1]) << 16) |
                              (static_cast<uint32_t>(payload[2]) << 8) |
                              static_cast<uint32_t>(payload[3]);
        return true;
    }

    bool handleData(const FrameHeader& header, const uint8_t* payload) {
        if (header.stream_id == 0) return false;
        auto& stream = getOrCreateStream(header.stream_id);
        connection_recv_window_ -= static_cast<int32_t>(header.length);
        return stream.receiveData(payload, header.length, header.isEndStream());
    }

    bool handleRstStream(const FrameHeader& header, const uint8_t* payload) {
        if (header.stream_id == 0) return false;
        auto it = streams_.find(header.stream_id);
        if (it != streams_.end()) {
            it->second.reset();
        }
        return true;
    }

    // 流集合
    std::unordered_map<uint32_t, Stream> streams_;
    uint32_t last_stream_id_ = 0;

    // 连接级流量控制
    int32_t connection_send_window_ = 65535;
    int32_t connection_recv_window_ = 65535;

    // SETTINGS
    std::unordered_map<SettingsId, uint32_t> local_settings_;
    std::unordered_map<SettingsId, uint32_t> peer_settings_;

    // 待发送的ACK
    bool settings_ack_pending_ = false;
    bool ping_ack_pending_ = false;
    std::vector<uint8_t> ping_ack_data_;

    // GOAWAY状态
    bool goaway_received_ = false;
    uint32_t goaway_last_stream_ = 0;
};

} // namespace http2

/*
 * 使用示例：
 *
 * http2::Http2Connection conn;
 *
 * // 读取帧头部
 * uint8_t header_buf[9];
 * read(fd, header_buf, 9);
 * auto header = http2::FrameCodec::decodeHeader(header_buf);
 *
 * // 读取帧载荷
 * std::vector<uint8_t> payload(header.length);
 * read(fd, payload.data(), header.length);
 *
 * // 处理帧
 * conn.processFrame(header, payload.data());
 *
 * // 构建SETTINGS帧
 * auto settings = http2::FrameCodec::buildSettingsFrame({
 *     {http2::SettingsId::MAX_CONCURRENT_STREAMS, 100},
 *     {http2::SettingsId::INITIAL_WINDOW_SIZE, 65535}
 * });
 * write(fd, settings.data(), settings.size());
 */
```

> **Day 22-23 自测问题**：
> 1. HTTP/2如何解决HTTP/1.1的队头阻塞问题？TCP层的队头阻塞呢？
> 2. 为什么HTTP/2流ID是奇数（客户端）和偶数（服务器）？
> 3. HPACK如何平衡压缩率和安全性（CRIME攻击）？
> 4. SETTINGS帧为什么必须在流0上发送？
> 5. 流量控制窗口耗尽时会发生什么？如何恢复？

---

### Day 24-25：性能优化（10小时）

#### 内存分配优化

高性能服务器中，频繁的`new`/`delete`调用是主要性能瓶颈之一。常用优化手段：

```
内存分配策略对比：

系统malloc（默认）：
┌─────────────────────────────────────────┐
│  每次请求：                               │
│  new HttpRequest()  → malloc → 用户态锁  │
│  new HttpResponse() → malloc → 系统调用  │
│  new Buffer(4096)   → malloc → 内存碎片  │
│  delete ...         → free   → 碎片回收  │
│                                         │
│  问题：                                  │
│  • 锁竞争（多线程）                       │
│  • 系统调用开销（brk/mmap）               │
│  • 内存碎片（长期运行后）                  │
│  • 缓存不友好（分散分配）                  │
└─────────────────────────────────────────┘

对象池（Object Pool）：
┌─────────────────────────────────────────┐
│  预分配 + 复用：                          │
│                                         │
│  ┌─────┬─────┬─────┬─────┬─────┐       │
│  │ Obj │ Obj │ Obj │ Obj │ Obj │ 空闲链 │
│  │  1  │  2  │  3  │  4  │  5  │       │
│  └──┬──┴──┬──┴──┬──┴─────┴─────┘       │
│     ↓     ↓     ↓                       │
│   使用中  使用中 使用中                    │
│                                         │
│  acquire() → O(1) 取出                   │
│  release() → O(1) 归还                   │
│  无锁竞争（线程本地池）                    │
│  无内存碎片（固定大小块）                  │
└─────────────────────────────────────────┘

Arena分配器：
┌─────────────────────────────────────────┐
│  批量分配 + 一次性释放：                   │
│                                         │
│  Arena (大块内存)                        │
│  ┌──────────────────────────────┐       │
│  │████████████░░░░░░░░░░░░░░░░░│       │
│  │ 已分配区域  │  可用空间       │       │
│  └──────────────────────────────┘       │
│     ↑     ↑     ↑                       │
│   alloc alloc  cursor                   │
│                                         │
│  适用场景：                               │
│  • 请求处理（请求结束时一次性释放）         │
│  • 解析器临时对象                         │
│  • 路由匹配中间结果                       │
└─────────────────────────────────────────┘
```

#### CPU缓存优化

```
CPU缓存层次与访问延迟：

┌─────────────────────────────────────────────────┐
│                CPU Core                         │
│  ┌──────────────────────────┐                   │
│  │    L1 Cache (32-64KB)    │  ~1ns  (4周期)    │
│  │    L1d (数据) + L1i (指令) │                   │
│  └────────────┬─────────────┘                   │
│               ↓                                 │
│  ┌──────────────────────────┐                   │
│  │    L2 Cache (256KB-1MB)  │  ~3ns  (12周期)   │
│  └────────────┬─────────────┘                   │
│               ↓                                 │
│  ┌──────────────────────────┐                   │
│  │    L3 Cache (8-32MB)     │  ~10ns (40周期)   │
│  │    (所有核心共享)          │                   │
│  └────────────┬─────────────┘                   │
│               ↓                                 │
│  ┌──────────────────────────┐                   │
│  │    主内存 (GB级)          │  ~100ns (200周期) │
│  └──────────────────────────┘                   │
└─────────────────────────────────────────────────┘

缓存行（Cache Line）= 64字节，CPU缓存的最小单位

优化策略：
┌─────────────────────────────────────────────────┐
│                                                 │
│  1. 数据局部性（把相关数据放在一起）               │
│     Bad:  struct { int a; char pad[60]; int b; }│
│     Good: struct { int a; int b; }              │
│                                                 │
│  2. 避免伪共享（False Sharing）                   │
│     Bad:  两个线程写同一缓存行的不同变量            │
│     ┌──────────────────────────────┐            │
│     │ counter_A │ counter_B │ ...  │ 64字节     │
│     └──────────────────────────────┘            │
│     Thread 1 ↑       ↑ Thread 2                │
│     两个线程互相使对方缓存行失效！                 │
│                                                 │
│     Good: 对齐到不同缓存行                       │
│     ┌──────────────────────────────┐            │
│     │ counter_A │ padding...       │ 64字节     │
│     ├──────────────────────────────┤            │
│     │ counter_B │ padding...       │ 64字节     │
│     └──────────────────────────────┘            │
│                                                 │
│  3. 预取友好的数据结构                            │
│     Bad:  链表（指针跳跃，缓存不友好）             │
│     Good: 数组/vector（连续内存，预取友好）         │
│                                                 │
│  4. 热数据/冷数据分离                             │
│     把频繁访问的字段放在结构体前面                  │
│     把不常用的字段放在后面或另一个结构体             │
└─────────────────────────────────────────────────┘
```

#### 代码示例：对象池

```cpp
// object_pool.hpp - 高性能对象池
#pragma once
#include <vector>
#include <memory>
#include <mutex>
#include <cassert>
#include <cstddef>
#include <new>
#include <type_traits>
#include <atomic>

namespace perf {

// ============================================================
// 固定大小对象池（线程不安全版，用于单线程/线程本地）
// ============================================================
template<typename T, size_t BlockSize = 64>
class ObjectPool {
public:
    ObjectPool() { allocateBlock(); }

    ~ObjectPool() {
        // 释放所有内存块
        for (auto* block : blocks_) {
            ::operator delete(block);
        }
    }

    // 不可拷贝/移动
    ObjectPool(const ObjectPool&) = delete;
    ObjectPool& operator=(const ObjectPool&) = delete;

    // 从池中获取对象（完美转发构造参数）
    template<typename... Args>
    T* acquire(Args&&... args) {
        if (!free_list_) {
            allocateBlock();
        }
        // 从空闲链表取出
        Node* node = free_list_;
        free_list_ = node->next;
        ++active_count_;

        // 在已分配的内存上构造对象
        T* obj = reinterpret_cast<T*>(node);
        new (obj) T(std::forward<Args>(args)...);
        return obj;
    }

    // 归还对象到池中
    void release(T* obj) {
        if (!obj) return;
        // 调用析构函数
        obj->~T();
        // 加入空闲链表
        Node* node = reinterpret_cast<Node*>(obj);
        node->next = free_list_;
        free_list_ = node;
        --active_count_;
    }

    // 统计信息
    size_t activeCount() const { return active_count_; }
    size_t totalCapacity() const { return blocks_.size() * BlockSize; }
    size_t freeCount() const { return totalCapacity() - active_count_; }

private:
    // 空闲链表节点（复用对象内存空间）
    union Node {
        Node* next;
        alignas(T) unsigned char storage[sizeof(T)];
    };

    static_assert(sizeof(Node) >= sizeof(T),
                  "Node must be at least as large as T");

    void allocateBlock() {
        // 分配一个内存块，包含BlockSize个Node
        size_t block_size = sizeof(Node) * BlockSize;
        void* raw = ::operator new(block_size);
        blocks_.push_back(raw);

        // 将所有节点链入空闲链表
        Node* nodes = reinterpret_cast<Node*>(raw);
        for (size_t i = 0; i < BlockSize - 1; ++i) {
            nodes[i].next = &nodes[i + 1];
        }
        nodes[BlockSize - 1].next = free_list_;
        free_list_ = &nodes[0];
    }

    Node* free_list_ = nullptr;       // 空闲链表头
    std::vector<void*> blocks_;        // 所有分配的内存块
    size_t active_count_ = 0;          // 活跃对象数
};

// ============================================================
// 线程安全对象池（带线程本地缓存）
// ============================================================
template<typename T, size_t LocalCacheSize = 32>
class ThreadSafeObjectPool {
public:
    ThreadSafeObjectPool() = default;

    ~ThreadSafeObjectPool() {
        // 注意：需要确保所有线程已归还对象
        std::lock_guard<std::mutex> lock(mutex_);
        for (auto* obj : global_pool_) {
            obj->~T();
            ::operator delete(obj);
        }
    }

    template<typename... Args>
    T* acquire(Args&&... args) {
        // 1. 先尝试线程本地缓存
        auto& local = getLocalCache();
        if (!local.empty()) {
            T* obj = local.back();
            local.pop_back();
            // 重新构造（placement new）
            obj->~T();
            new (obj) T(std::forward<Args>(args)...);
            return obj;
        }

        // 2. 尝试从全局池批量获取
        {
            std::lock_guard<std::mutex> lock(mutex_);
            size_t count = std::min(global_pool_.size(), LocalCacheSize / 2);
            if (count > 0) {
                for (size_t i = 0; i < count; ++i) {
                    local.push_back(global_pool_.back());
                    global_pool_.pop_back();
                }
                T* obj = local.back();
                local.pop_back();
                obj->~T();
                new (obj) T(std::forward<Args>(args)...);
                return obj;
            }
        }

        // 3. 分配新对象
        void* mem = ::operator new(sizeof(T));
        return new (mem) T(std::forward<Args>(args)...);
    }

    void release(T* obj) {
        if (!obj) return;

        auto& local = getLocalCache();

        // 线程本地缓存未满，直接放入
        if (local.size() < LocalCacheSize) {
            local.push_back(obj);
            return;
        }

        // 本地缓存满了，批量归还一半到全局池
        std::lock_guard<std::mutex> lock(mutex_);
        size_t return_count = LocalCacheSize / 2;
        for (size_t i = 0; i < return_count; ++i) {
            global_pool_.push_back(local.back());
            local.pop_back();
        }
        local.push_back(obj);
    }

private:
    // 获取线程本地缓存
    std::vector<T*>& getLocalCache() {
        thread_local std::vector<T*> cache;
        return cache;
    }

    std::mutex mutex_;
    std::vector<T*> global_pool_;
};

// ============================================================
// RAII对象池包装器
// ============================================================
template<typename T, typename Pool>
class PooledObject {
public:
    PooledObject(Pool& pool, T* obj) : pool_(pool), obj_(obj) {}
    ~PooledObject() { pool_.release(obj_); }

    // 移动语义
    PooledObject(PooledObject&& other) noexcept
        : pool_(other.pool_), obj_(other.obj_) {
        other.obj_ = nullptr;
    }

    PooledObject(const PooledObject&) = delete;
    PooledObject& operator=(const PooledObject&) = delete;

    T* get() { return obj_; }
    T* operator->() { return obj_; }
    T& operator*() { return *obj_; }

private:
    Pool& pool_;
    T* obj_;
};

} // namespace perf

/*
 * 使用示例：
 *
 * // 1. 基本对象池
 * perf::ObjectPool<HttpRequest, 128> request_pool;
 *
 * // 获取对象
 * HttpRequest* req = request_pool.acquire();
 * // 使用...
 * request_pool.release(req);  // 归还
 *
 * // 2. 线程安全对象池
 * perf::ThreadSafeObjectPool<HttpResponse> response_pool;
 *
 * // 多线程安全使用
 * HttpResponse* resp = response_pool.acquire(200, "OK");
 * response_pool.release(resp);
 *
 * // 3. RAII包装
 * {
 *     auto req = perf::PooledObject(request_pool,
 *                                   request_pool.acquire());
 *     req->setMethod("GET");
 *     // 作用域结束自动归还
 * }
 */
```

#### 代码示例：Arena分配器

```cpp
// arena_allocator.hpp - Arena分配器（请求级内存管理）
#pragma once
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cassert>
#include <vector>
#include <string_view>
#include <type_traits>

namespace perf {

// ============================================================
// Arena分配器
//
// 特点：
// - 快速分配（指针递增）
// - 无单独释放（整体释放所有内存）
// - 非常适合请求处理：请求开始分配，请求结束一次释放
// ============================================================
class Arena {
public:
    static constexpr size_t DEFAULT_BLOCK_SIZE = 8192;  // 8KB默认块

    explicit Arena(size_t block_size = DEFAULT_BLOCK_SIZE)
        : block_size_(block_size) {
        allocateBlock(block_size_);
    }

    ~Arena() {
        for (auto& block : blocks_) {
            std::free(block.data);
        }
    }

    // 不可拷贝/移动
    Arena(const Arena&) = delete;
    Arena& operator=(const Arena&) = delete;

    // 分配指定大小的内存（对齐到alignof(max_align_t)）
    void* allocate(size_t size) {
        return allocateAligned(size, alignof(std::max_align_t));
    }

    // 分配并对齐到指定边界
    void* allocateAligned(size_t size, size_t alignment) {
        assert(alignment > 0 && (alignment & (alignment - 1)) == 0);

        // 对齐当前指针
        size_t current = reinterpret_cast<uintptr_t>(cursor_);
        size_t aligned = (current + alignment - 1) & ~(alignment - 1);
        size_t padding = aligned - current;
        size_t total = size + padding;

        if (cursor_ + total > end_) {
            // 当前块空间不足，分配新块
            size_t new_size = std::max(block_size_, size + alignment);
            allocateBlock(new_size);
            // 重新对齐
            current = reinterpret_cast<uintptr_t>(cursor_);
            aligned = (current + alignment - 1) & ~(alignment - 1);
            padding = aligned - current;
            total = size + padding;
        }

        void* result = cursor_ + padding;
        cursor_ += total;
        bytes_allocated_ += size;
        return result;
    }

    // 在Arena上构造对象
    template<typename T, typename... Args>
    T* create(Args&&... args) {
        void* mem = allocateAligned(sizeof(T), alignof(T));
        return new (mem) T(std::forward<Args>(args)...);
    }

    // 在Arena上分配数组
    template<typename T>
    T* createArray(size_t count) {
        void* mem = allocateAligned(sizeof(T) * count, alignof(T));
        T* arr = reinterpret_cast<T*>(mem);
        for (size_t i = 0; i < count; ++i) {
            new (&arr[i]) T();
        }
        return arr;
    }

    // 在Arena上复制字符串
    std::string_view duplicateString(std::string_view src) {
        if (src.empty()) return {};
        char* dst = reinterpret_cast<char*>(allocate(src.size()));
        std::memcpy(dst, src.data(), src.size());
        return std::string_view(dst, src.size());
    }

    // 重置Arena（不释放内存，只重置分配指针）
    void reset() {
        if (!blocks_.empty()) {
            cursor_ = blocks_[0].data;
            end_ = blocks_[0].data + blocks_[0].size;
            current_block_ = 0;
        }
        bytes_allocated_ = 0;
    }

    // 统计信息
    size_t bytesAllocated() const { return bytes_allocated_; }
    size_t blocksCount() const { return blocks_.size(); }
    size_t totalMemory() const {
        size_t total = 0;
        for (const auto& block : blocks_) total += block.size;
        return total;
    }
    double utilizationRate() const {
        size_t total = totalMemory();
        return total > 0 ? static_cast<double>(bytes_allocated_) / total : 0.0;
    }

private:
    struct Block {
        char* data;
        size_t size;
    };

    void allocateBlock(size_t size) {
        char* data = reinterpret_cast<char*>(std::malloc(size));
        if (!data) throw std::bad_alloc();
        blocks_.push_back({data, size});
        cursor_ = data;
        end_ = data + size;
        current_block_ = blocks_.size() - 1;
    }

    size_t block_size_;
    std::vector<Block> blocks_;
    size_t current_block_ = 0;

    char* cursor_ = nullptr;
    char* end_ = nullptr;

    size_t bytes_allocated_ = 0;
};

// ============================================================
// Arena感知的字符串（生命周期绑定Arena）
// ============================================================
class ArenaString {
public:
    ArenaString() = default;
    ArenaString(Arena& arena, std::string_view sv)
        : data_(arena.duplicateString(sv)) {}

    std::string_view view() const { return data_; }
    const char* data() const { return data_.data(); }
    size_t size() const { return data_.size(); }
    bool empty() const { return data_.empty(); }

    bool operator==(std::string_view other) const { return data_ == other; }
    bool operator!=(std::string_view other) const { return data_ != other; }

private:
    std::string_view data_;
};

// ============================================================
// 无锁统计计数器（避免False Sharing）
// ============================================================
struct alignas(64) PaddedCounter {
    std::atomic<uint64_t> value{0};

    void increment() { value.fetch_add(1, std::memory_order_relaxed); }
    void add(uint64_t n) { value.fetch_add(n, std::memory_order_relaxed); }
    uint64_t load() const { return value.load(std::memory_order_relaxed); }
    void reset() { value.store(0, std::memory_order_relaxed); }
};

struct ServerStats {
    // 每个计数器占一个完整缓存行（64字节），避免False Sharing
    PaddedCounter total_requests;       // 总请求数
    PaddedCounter active_connections;   // 当前活跃连接
    PaddedCounter bytes_received;       // 接收字节数
    PaddedCounter bytes_sent;           // 发送字节数
    PaddedCounter requests_2xx;         // 2xx响应数
    PaddedCounter requests_4xx;         // 4xx响应数
    PaddedCounter requests_5xx;         // 5xx响应数
    PaddedCounter parse_errors;         // 解析错误数

    void onRequest(int status_code) {
        total_requests.increment();
        if (status_code >= 200 && status_code < 300) requests_2xx.increment();
        else if (status_code >= 400 && status_code < 500) requests_4xx.increment();
        else if (status_code >= 500) requests_5xx.increment();
    }

    void print() const {
        printf("=== Server Statistics ===\n");
        printf("Total Requests:      %lu\n", total_requests.load());
        printf("Active Connections:  %lu\n", active_connections.load());
        printf("Bytes Received:      %lu\n", bytes_received.load());
        printf("Bytes Sent:          %lu\n", bytes_sent.load());
        printf("2xx Responses:       %lu\n", requests_2xx.load());
        printf("4xx Responses:       %lu\n", requests_4xx.load());
        printf("5xx Responses:       %lu\n", requests_5xx.load());
        printf("Parse Errors:        %lu\n", parse_errors.load());
    }
};

} // namespace perf

/*
 * 使用示例：
 *
 * // 1. 请求级Arena分配
 * perf::Arena arena(4096);  // 4KB初始块
 *
 * // 快速分配（指针递增，O(1)）
 * auto* headers = arena.createArray<HeaderPair>(32);
 * auto path = arena.duplicateString(parsed_path);
 *
 * // 请求处理完毕，一次性回收
 * arena.reset();  // 不调用free，只重置指针
 *
 * // 2. 无锁统计
 * perf::ServerStats stats;
 * // 多线程安全，无锁竞争
 * stats.total_requests.increment();
 * stats.bytes_received.add(1024);
 */
```

#### 压测方法论

```
常用HTTP压测工具对比：

┌─────────────┬───────────────┬───────────────┬───────────────┐
│   工具       │  wrk          │  ab            │  hey          │
├─────────────┼───────────────┼───────────────┼───────────────┤
│ 语言        │ C + Lua       │ C (Apache)    │ Go            │
│ 并发模型    │ 多线程+epoll  │ 单线程        │ goroutine     │
│ 脚本支持    │ Lua脚本       │ 无            │ 无            │
│ HTTP/2      │ 不支持        │ 不支持        │ 支持          │
│ 延迟分布    │ 详细          │ 基本          │ 详细          │
│ 推荐场景    │ 高性能压测    │ 简单压测      │ 快速验证      │
└─────────────┴───────────────┴───────────────┴───────────────┘

wrk使用示例：

# 基础压测：4线程，100并发，持续30秒
$ wrk -t4 -c100 -d30s http://localhost:8080/

# 输出解读：
┌────────────────────────────────────────────┐
│ Running 30s test @ http://localhost:8080/  │
│   4 threads and 100 connections            │
│   Thread Stats   Avg      Stdev     Max    │
│     Latency    120us     25us    2.5ms     │  ← 延迟
│     Req/Sec    65.2k     3.1k    72.0k     │  ← 吞吐量
│   Latency Distribution                     │
│     50%  115us    ← P50                    │
│     75%  130us    ← P75                    │
│     90%  155us    ← P90                    │
│     99%  250us    ← P99 (关键指标)          │
│   7820000 requests in 30s, 1.2GB read      │
│   Requests/sec: 260666.67                  │  ← QPS
│   Transfer/sec: 40.00MB                    │
└────────────────────────────────────────────┘

关键性能指标：
┌─────────────────────────────────────────────┐
│                                             │
│  1. QPS（每秒请求数）                        │
│     目标：单核 50K-100K（简单响应）           │
│                                             │
│  2. P99延迟                                 │
│     目标：< 1ms（内网）                      │
│     关注尾延迟，而非平均延迟                   │
│                                             │
│  3. 吞吐量（Transfer/sec）                   │
│     受限于网络带宽和I/O效率                   │
│                                             │
│  4. 错误率                                   │
│     目标：0%（压测期间无错误）                 │
│                                             │
│  5. CPU使用率                                │
│     目标：接近100%（充分利用）                 │
│     过低说明有I/O瓶颈                        │
│                                             │
│  性能调优流程：                               │
│  ┌───────┐    ┌──────┐    ┌──────┐         │
│  │ 压测   │───→│ 分析  │───→│ 优化  │───→ 循环│
│  │ (wrk)  │    │(perf) │    │(代码) │         │
│  └───────┘    └──────┘    └──────┘         │
│                                             │
│  perf常用命令：                               │
│  $ perf stat ./server          # CPU计数器  │
│  $ perf record -g ./server     # 采样       │
│  $ perf report                  # 分析报告  │
│  $ flamegraph.pl < perf.data   # 火焰图     │
└─────────────────────────────────────────────┘
```

> **Day 24-25 自测问题**：
> 1. 对象池和`malloc`相比，为什么能提升性能？核心是避免了什么？
> 2. Arena分配器适用于什么场景？不适用于什么场景？
> 3. 什么是False Sharing？为什么`alignas(64)`能解决？
> 4. P99延迟比平均延迟更重要，为什么？
> 5. 如何用perf火焰图定位性能瓶颈？

---

### Day 26-28：完整Mini-HTTP服务器（15小时）

#### 组件组装架构

将前三周开发的所有组件整合成一个完整的生产级HTTP服务器：

```
Mini-HTTP服务器完整架构：

                    ┌─────────────────────────────────────────┐
                    │           ConfigLoader                  │
                    │      (配置文件加载与热更新)               │
                    └────────────────┬────────────────────────┘
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        MiniHttpServer                               │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                     SignalHandler                            │   │
│  │              (SIGTERM/SIGINT → 优雅关闭)                      │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │
│  │   Worker 0   │  │   Worker 1   │  │   Worker N   │             │
│  │  (Thread 0)  │  │  (Thread 1)  │  │  (Thread N)  │             │
│  │              │  │              │  │              │             │
│  │ ┌──────────┐ │  │ ┌──────────┐ │  │ ┌──────────┐ │             │
│  │ │ Reactor  │ │  │ │ Reactor  │ │  │ │ Reactor  │ │  SO_REUSEPORT│
│  │ │ (epoll)  │ │  │ │ (epoll)  │ │  │ │ (epoll)  │ │             │
│  │ └────┬─────┘ │  │ └────┬─────┘ │  │ └────┬─────┘ │             │
│  │      │       │  │      │       │  │      │       │             │
│  │ ┌────▼─────┐ │  │ ┌────▼─────┐ │  │ ┌────▼─────┐ │             │
│  │ │Connection│ │  │ │Connection│ │  │ │Connection│ │             │
│  │ │ Manager  │ │  │ │ Manager  │ │  │ │ Manager  │ │             │
│  │ └────┬─────┘ │  │ └────┬─────┘ │  │ └────┬─────┘ │             │
│  │      │       │  │      │       │  │      │       │             │
│  │      ▼       │  │      ▼       │  │      ▼       │             │
│  │  Request     │  │  Request     │  │  Request     │             │
│  │  Processing  │  │  Processing  │  │  Processing  │             │
│  │  Pipeline    │  │  Pipeline    │  │  Pipeline    │             │
│  └──────────────┘  └──────────────┘  └──────────────┘             │
│                                                                     │
│  共享组件（线程安全）：                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │
│  │  TrieRouter  │  │  FileCache   │  │ ServerStats  │             │
│  │  (路由表)     │  │ (文件缓存)   │  │ (无锁统计)    │             │
│  └──────────────┘  └──────────────┘  └──────────────┘             │
└─────────────────────────────────────────────────────────────────────┘

请求处理流程（单个Worker内）：

    新连接                    请求到达
       │                         │
       ▼                         ▼
  ┌─────────┐              ┌─────────┐
  │ accept  │              │  read   │
  └────┬────┘              └────┬────┘
       │                        │
       ▼                        ▼
  ┌─────────┐              ┌─────────────┐
  │ 创建    │              │ HttpParser  │
  │Connection│             │ (状态机解析) │
  └────┬────┘              └──────┬──────┘
       │                          │
       ▼                          ▼
  ┌─────────────┐          ┌─────────────┐
  │ 加入epoll   │          │ 中间件链     │
  │ (EPOLLIN)   │          │ Logging     │
  └─────────────┘          │ CORS        │
                           │ RateLimit   │
                           └──────┬──────┘
                                  │
                                  ▼
                           ┌─────────────┐
                           │ TrieRouter  │
                           │ 路由匹配     │
                           └──────┬──────┘
                                  │
                    ┌─────────────┼─────────────┐
                    ▼             ▼             ▼
              ┌─────────┐  ┌─────────────┐ ┌─────────┐
              │ Static  │  │ API Handler │ │ 404     │
              │ Files   │  │ (用户逻辑)   │ │ Handler │
              └────┬────┘  └──────┬──────┘ └────┬────┘
                   │              │              │
                   └──────────────┼──────────────┘
                                  ▼
                           ┌─────────────┐
                           │ Response    │
                           │ Builder     │
                           └──────┬──────┘
                                  │
                                  ▼
                           ┌─────────────┐
                           │ sendfile/   │
                           │ writev      │
                           └─────────────┘
```

#### 优雅关闭（Graceful Shutdown）

```
优雅关闭流程：

正常关闭 vs 强制关闭：

强制关闭（kill -9）：
┌─────────────────────────────────────────┐
│  客户端A: 请求处理中... → 连接断开！❌    │
│  客户端B: 响应发送中... → 数据丢失！❌    │
│  客户端C: 等待响应...   → 超时错误！❌    │
└─────────────────────────────────────────┘

优雅关闭（SIGTERM）：
┌─────────────────────────────────────────┐
│  1. 收到SIGTERM信号                      │
│     │                                   │
│  2. 停止接受新连接                        │
│     ├─ 关闭listen socket                │
│     └─ 新请求返回503 Service Unavailable │
│     │                                   │
│  3. 等待现有请求完成（最长N秒）            │
│     ├─ 客户端A: 请求完成 ✓               │
│     ├─ 客户端B: 响应发送完成 ✓            │
│     └─ 客户端C: 收到响应 ✓               │
│     │                                   │
│  4. 关闭所有连接                         │
│     │                                   │
│  5. 清理资源，退出                        │
└─────────────────────────────────────────┘

状态转换：
  RUNNING ──(SIGTERM)──→ DRAINING ──(超时/完成)──→ STOPPED
     ↑                      │
     │                      │ (继续处理现有请求)
     └──────────────────────┘
```

#### 代码示例：完整Mini-HTTP服务器

```cpp
// mini_http_server.hpp - 完整的高性能HTTP服务器
#pragma once

#include <sys/socket.h>
#include <sys/epoll.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>

#include <atomic>
#include <thread>
#include <vector>
#include <memory>
#include <functional>
#include <string>
#include <string_view>
#include <unordered_map>
#include <chrono>
#include <mutex>
#include <condition_variable>

// 假设已有以下组件（前几周实现）：
// #include "http_parser_v2.hpp"
// #include "connection_manager.hpp"
// #include "trie_router.hpp"
// #include "middleware.hpp"
// #include "file_cache.hpp"
// #include "object_pool.hpp"
// #include "arena_allocator.hpp"

namespace mini {

// ============================================================
// 服务器配置
// ============================================================
struct ServerConfig {
    std::string bind_address = "0.0.0.0";
    uint16_t port = 8080;
    size_t worker_threads = 0;  // 0表示自动（CPU核心数）

    // 连接配置
    size_t max_connections = 10000;
    int keep_alive_timeout_sec = 60;
    int max_requests_per_conn = 1000;

    // 缓冲区配置
    size_t read_buffer_size = 8192;
    size_t write_buffer_size = 16384;

    // 超时配置
    int read_timeout_ms = 30000;
    int write_timeout_ms = 30000;
    int shutdown_timeout_sec = 30;

    // 静态文件配置
    std::string static_root = "./static";
    size_t file_cache_max_size = 100 * 1024 * 1024;  // 100MB
    size_t file_cache_max_entries = 1000;

    // 限流配置
    size_t rate_limit_rps = 10000;  // 每秒请求数
    size_t rate_limit_burst = 1000;

    // 默认Worker数量 = CPU核心数
    size_t effectiveWorkerThreads() const {
        return worker_threads > 0 ? worker_threads
                                  : std::thread::hardware_concurrency();
    }
};

// ============================================================
// 服务器状态
// ============================================================
enum class ServerState {
    CREATED,
    STARTING,
    RUNNING,
    DRAINING,  // 优雅关闭中
    STOPPED
};

// ============================================================
// HTTP上下文（每个请求的处理上下文）
// ============================================================
struct HttpContext {
    // 请求信息
    std::string_view method;
    std::string_view path;
    std::string_view query;
    std::unordered_map<std::string, std::string> headers;
    std::string_view body;

    // 路由参数
    std::unordered_map<std::string, std::string> params;

    // 响应构建
    int status_code = 200;
    std::unordered_map<std::string, std::string> response_headers;
    std::string response_body;

    // 连接信息
    int fd = -1;
    std::string client_ip;
    uint16_t client_port = 0;

    // 请求级Arena（请求结束时整体释放）
    // perf::Arena arena{4096};

    // 辅助方法
    void setStatus(int code) { status_code = code; }

    void setHeader(const std::string& key, const std::string& value) {
        response_headers[key] = value;
    }

    void setBody(std::string body) {
        response_body = std::move(body);
        setHeader("Content-Length", std::to_string(response_body.size()));
    }

    void json(const std::string& json_body) {
        setHeader("Content-Type", "application/json");
        setBody(json_body);
    }

    void text(const std::string& text_body) {
        setHeader("Content-Type", "text/plain");
        setBody(text_body);
    }

    void html(const std::string& html_body) {
        setHeader("Content-Type", "text/html; charset=utf-8");
        setBody(html_body);
    }

    void redirect(const std::string& url, int code = 302) {
        setStatus(code);
        setHeader("Location", url);
    }

    std::string getHeader(const std::string& key) const {
        auto it = headers.find(key);
        return it != headers.end() ? it->second : "";
    }

    std::string getParam(const std::string& key) const {
        auto it = params.find(key);
        return it != params.end() ? it->second : "";
    }
};

// 处理器类型
using Handler = std::function<void(HttpContext&)>;
using Middleware = std::function<void(HttpContext&, Handler)>;

// ============================================================
// 信号处理器（全局单例）
// ============================================================
class SignalHandler {
public:
    static SignalHandler& instance() {
        static SignalHandler handler;
        return handler;
    }

    void setup(std::function<void()> shutdown_callback) {
        shutdown_callback_ = std::move(shutdown_callback);

        struct sigaction sa{};
        sa.sa_handler = SignalHandler::signalHandler;
        sa.sa_flags = 0;
        sigemptyset(&sa.sa_mask);

        sigaction(SIGTERM, &sa, nullptr);
        sigaction(SIGINT, &sa, nullptr);

        // 忽略SIGPIPE（写入已关闭的socket）
        signal(SIGPIPE, SIG_IGN);
    }

    bool shouldShutdown() const {
        return shutdown_requested_.load(std::memory_order_relaxed);
    }

private:
    SignalHandler() = default;

    static void signalHandler(int sig) {
        (void)sig;
        auto& self = instance();
        bool expected = false;
        if (self.shutdown_requested_.compare_exchange_strong(
                expected, true, std::memory_order_relaxed)) {
            if (self.shutdown_callback_) {
                self.shutdown_callback_();
            }
        }
    }

    std::atomic<bool> shutdown_requested_{false};
    std::function<void()> shutdown_callback_;
};

// ============================================================
// Worker线程
// ============================================================
class Worker {
public:
    Worker(int worker_id, const ServerConfig& config)
        : worker_id_(worker_id), config_(config) {
        epoll_fd_ = epoll_create1(EPOLL_CLOEXEC);
        if (epoll_fd_ < 0) {
            throw std::runtime_error("epoll_create1 failed");
        }
    }

    ~Worker() {
        if (epoll_fd_ >= 0) close(epoll_fd_);
        if (listen_fd_ >= 0) close(listen_fd_);
    }

    // 设置监听socket（SO_REUSEPORT允许每个Worker有自己的监听socket）
    void setupListener() {
        listen_fd_ = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK, 0);
        if (listen_fd_ < 0) {
            throw std::runtime_error("socket failed");
        }

        int opt = 1;
        setsockopt(listen_fd_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
        setsockopt(listen_fd_, SOL_SOCKET, SO_REUSEPORT, &opt, sizeof(opt));

        // TCP优化
        setsockopt(listen_fd_, IPPROTO_TCP, TCP_NODELAY, &opt, sizeof(opt));

        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_port = htons(config_.port);
        inet_pton(AF_INET, config_.bind_address.c_str(), &addr.sin_addr);

        if (bind(listen_fd_, reinterpret_cast<sockaddr*>(&addr),
                 sizeof(addr)) < 0) {
            throw std::runtime_error("bind failed");
        }

        if (listen(listen_fd_, SOMAXCONN) < 0) {
            throw std::runtime_error("listen failed");
        }

        // 加入epoll
        epoll_event ev{};
        ev.events = EPOLLIN;
        ev.data.fd = listen_fd_;
        epoll_ctl(epoll_fd_, EPOLL_CTL_ADD, listen_fd_, &ev);
    }

    void setRouter(std::shared_ptr<void> router) {
        router_ = std::move(router);
    }

    void run() {
        running_ = true;
        constexpr int MAX_EVENTS = 256;
        epoll_event events[MAX_EVENTS];

        while (running_) {
            int nfds = epoll_wait(epoll_fd_, events, MAX_EVENTS, 100);

            if (nfds < 0) {
                if (errno == EINTR) continue;
                break;
            }

            for (int i = 0; i < nfds; ++i) {
                int fd = events[i].data.fd;

                if (fd == listen_fd_) {
                    // 新连接
                    acceptConnections();
                } else {
                    // 处理已有连接
                    if (events[i].events & EPOLLIN) {
                        handleRead(fd);
                    }
                    if (events[i].events & EPOLLOUT) {
                        handleWrite(fd);
                    }
                    if (events[i].events & (EPOLLERR | EPOLLHUP)) {
                        closeConnection(fd);
                    }
                }
            }

            // 定期清理超时连接
            cleanupTimeouts();
        }
    }

    void stop() {
        running_ = false;
    }

    void enterDrainMode() {
        // 停止接受新连接
        if (listen_fd_ >= 0) {
            epoll_ctl(epoll_fd_, EPOLL_CTL_DEL, listen_fd_, nullptr);
            close(listen_fd_);
            listen_fd_ = -1;
        }
    }

    size_t activeConnections() const {
        return connections_.size();
    }

private:
    void acceptConnections() {
        while (true) {
            sockaddr_in client_addr{};
            socklen_t addr_len = sizeof(client_addr);
            int client_fd = accept4(listen_fd_,
                                    reinterpret_cast<sockaddr*>(&client_addr),
                                    &addr_len, SOCK_NONBLOCK | SOCK_CLOEXEC);

            if (client_fd < 0) {
                if (errno == EAGAIN || errno == EWOULDBLOCK) break;
                continue;
            }

            if (connections_.size() >= config_.max_connections) {
                // 连接数已满，拒绝
                close(client_fd);
                continue;
            }

            // TCP优化
            int opt = 1;
            setsockopt(client_fd, IPPROTO_TCP, TCP_NODELAY, &opt, sizeof(opt));

            // 创建连接对象
            auto conn = std::make_unique<Connection>();
            conn->fd = client_fd;
            conn->client_ip = inet_ntoa(client_addr.sin_addr);
            conn->client_port = ntohs(client_addr.sin_port);
            conn->last_active = std::chrono::steady_clock::now();

            // 加入epoll
            epoll_event ev{};
            ev.events = EPOLLIN | EPOLLET;  // 边缘触发
            ev.data.fd = client_fd;
            epoll_ctl(epoll_fd_, EPOLL_CTL_ADD, client_fd, &ev);

            connections_[client_fd] = std::move(conn);
        }
    }

    void handleRead(int fd) {
        auto it = connections_.find(fd);
        if (it == connections_.end()) return;

        auto& conn = it->second;
        conn->last_active = std::chrono::steady_clock::now();

        // 读取数据
        char buf[8192];
        while (true) {
            ssize_t n = read(fd, buf, sizeof(buf));
            if (n > 0) {
                conn->read_buffer.append(buf, n);
            } else if (n == 0) {
                // 对端关闭
                closeConnection(fd);
                return;
            } else {
                if (errno == EAGAIN || errno == EWOULDBLOCK) break;
                closeConnection(fd);
                return;
            }
        }

        // 尝试解析HTTP请求
        tryParseAndHandle(conn.get());
    }

    void tryParseAndHandle(Connection* conn) {
        // 简化的HTTP解析（实际应使用HttpParser）
        auto& buf = conn->read_buffer;
        size_t header_end = buf.find("\r\n\r\n");
        if (header_end == std::string::npos) return;  // 请求不完整

        // 构建上下文
        HttpContext ctx;
        ctx.fd = conn->fd;
        ctx.client_ip = conn->client_ip;
        ctx.client_port = conn->client_port;

        // 解析请求行
        size_t first_line_end = buf.find("\r\n");
        std::string_view first_line(buf.data(), first_line_end);

        size_t method_end = first_line.find(' ');
        ctx.method = first_line.substr(0, method_end);

        size_t path_start = method_end + 1;
        size_t path_end = first_line.find(' ', path_start);
        std::string_view full_path = first_line.substr(path_start,
                                                       path_end - path_start);

        // 分离路径和查询字符串
        size_t query_pos = full_path.find('?');
        if (query_pos != std::string_view::npos) {
            ctx.path = full_path.substr(0, query_pos);
            ctx.query = full_path.substr(query_pos + 1);
        } else {
            ctx.path = full_path;
        }

        // 处理请求（调用路由器）
        handleRequest(ctx);

        // 发送响应
        sendResponse(conn, ctx);

        // 清理已处理的请求
        buf.erase(0, header_end + 4);
        conn->request_count++;

        // 检查是否达到最大请求数
        if (conn->request_count >= config_.max_requests_per_conn) {
            closeConnection(conn->fd);
        }
    }

    void handleRequest(HttpContext& ctx) {
        // 这里应该调用路由器，简化示例直接返回
        ctx.setStatus(200);
        ctx.json("{\"message\": \"Hello from Mini-HTTP Server!\"}");
    }

    void sendResponse(Connection* conn, const HttpContext& ctx) {
        std::string response;
        response.reserve(1024 + ctx.response_body.size());

        // 状态行
        response += "HTTP/1.1 ";
        response += std::to_string(ctx.status_code);
        response += " ";
        response += getStatusText(ctx.status_code);
        response += "\r\n";

        // 默认头部
        response += "Server: Mini-HTTP/1.0\r\n";
        response += "Connection: keep-alive\r\n";

        // 用户头部
        for (const auto& [key, value] : ctx.response_headers) {
            response += key;
            response += ": ";
            response += value;
            response += "\r\n";
        }

        response += "\r\n";
        response += ctx.response_body;

        // 发送（简化版，实际应处理EAGAIN）
        write(conn->fd, response.data(), response.size());
    }

    void handleWrite(int fd) {
        // 处理待发送数据（简化版）
        auto it = connections_.find(fd);
        if (it == connections_.end()) return;
        // 实际实现应该维护write_buffer并在这里发送
    }

    void closeConnection(int fd) {
        epoll_ctl(epoll_fd_, EPOLL_CTL_DEL, fd, nullptr);
        close(fd);
        connections_.erase(fd);
    }

    void cleanupTimeouts() {
        auto now = std::chrono::steady_clock::now();
        auto timeout = std::chrono::seconds(config_.keep_alive_timeout_sec);

        std::vector<int> to_close;
        for (const auto& [fd, conn] : connections_) {
            if (now - conn->last_active > timeout) {
                to_close.push_back(fd);
            }
        }

        for (int fd : to_close) {
            closeConnection(fd);
        }
    }

    static const char* getStatusText(int code) {
        switch (code) {
            case 200: return "OK";
            case 201: return "Created";
            case 204: return "No Content";
            case 301: return "Moved Permanently";
            case 302: return "Found";
            case 304: return "Not Modified";
            case 400: return "Bad Request";
            case 401: return "Unauthorized";
            case 403: return "Forbidden";
            case 404: return "Not Found";
            case 405: return "Method Not Allowed";
            case 429: return "Too Many Requests";
            case 500: return "Internal Server Error";
            case 502: return "Bad Gateway";
            case 503: return "Service Unavailable";
            default:  return "Unknown";
        }
    }

    // 连接结构
    struct Connection {
        int fd = -1;
        std::string client_ip;
        uint16_t client_port = 0;
        std::string read_buffer;
        std::string write_buffer;
        std::chrono::steady_clock::time_point last_active;
        int request_count = 0;
    };

    int worker_id_;
    const ServerConfig& config_;
    int epoll_fd_ = -1;
    int listen_fd_ = -1;
    std::atomic<bool> running_{false};
    std::unordered_map<int, std::unique_ptr<Connection>> connections_;
    std::shared_ptr<void> router_;
};

// ============================================================
// Mini-HTTP服务器主类
// ============================================================
class MiniHttpServer {
public:
    explicit MiniHttpServer(const ServerConfig& config = {})
        : config_(config), state_(ServerState::CREATED) {}

    ~MiniHttpServer() {
        stop();
    }

    // 路由注册
    MiniHttpServer& get(const std::string& path, Handler handler) {
        routes_.push_back({"GET", path, std::move(handler)});
        return *this;
    }

    MiniHttpServer& post(const std::string& path, Handler handler) {
        routes_.push_back({"POST", path, std::move(handler)});
        return *this;
    }

    MiniHttpServer& put(const std::string& path, Handler handler) {
        routes_.push_back({"PUT", path, std::move(handler)});
        return *this;
    }

    MiniHttpServer& del(const std::string& path, Handler handler) {
        routes_.push_back({"DELETE", path, std::move(handler)});
        return *this;
    }

    // 中间件注册
    MiniHttpServer& use(Middleware middleware) {
        middlewares_.push_back(std::move(middleware));
        return *this;
    }

    // 启动服务器
    void start() {
        if (state_ != ServerState::CREATED) {
            throw std::runtime_error("Server already started");
        }

        state_ = ServerState::STARTING;

        // 设置信号处理
        SignalHandler::instance().setup([this]() {
            gracefulShutdown();
        });

        // 创建Worker线程
        size_t worker_count = config_.effectiveWorkerThreads();
        for (size_t i = 0; i < worker_count; ++i) {
            auto worker = std::make_unique<Worker>(i, config_);
            worker->setupListener();
            workers_.push_back(std::move(worker));
        }

        // 启动Worker线程
        for (auto& worker : workers_) {
            worker_threads_.emplace_back([&worker]() {
                worker->run();
            });
        }

        state_ = ServerState::RUNNING;

        printf("Mini-HTTP Server started on %s:%d with %zu workers\n",
               config_.bind_address.c_str(), config_.port, worker_count);
    }

    // 等待服务器停止
    void wait() {
        for (auto& t : worker_threads_) {
            if (t.joinable()) t.join();
        }
    }

    // 阻塞式运行
    void run() {
        start();
        wait();
    }

    // 优雅关闭
    void gracefulShutdown() {
        if (state_ != ServerState::RUNNING) return;

        printf("\nInitiating graceful shutdown...\n");
        state_ = ServerState::DRAINING;

        // 1. 停止接受新连接
        for (auto& worker : workers_) {
            worker->enterDrainMode();
        }

        // 2. 等待现有请求完成（最长等待shutdown_timeout_sec秒）
        auto deadline = std::chrono::steady_clock::now() +
                        std::chrono::seconds(config_.shutdown_timeout_sec);

        while (std::chrono::steady_clock::now() < deadline) {
            size_t active = 0;
            for (const auto& worker : workers_) {
                active += worker->activeConnections();
            }

            if (active == 0) {
                printf("All connections closed, shutting down.\n");
                break;
            }

            printf("Waiting for %zu connections to close...\n", active);
            std::this_thread::sleep_for(std::chrono::milliseconds(500));
        }

        // 3. 停止所有Worker
        stop();
    }

    // 立即停止
    void stop() {
        if (state_ == ServerState::STOPPED) return;

        state_ = ServerState::STOPPED;

        for (auto& worker : workers_) {
            worker->stop();
        }

        for (auto& t : worker_threads_) {
            if (t.joinable()) t.join();
        }

        workers_.clear();
        worker_threads_.clear();

        printf("Server stopped.\n");
    }

    ServerState state() const { return state_; }

private:
    struct Route {
        std::string method;
        std::string path;
        Handler handler;
    };

    ServerConfig config_;
    std::atomic<ServerState> state_;
    std::vector<Route> routes_;
    std::vector<Middleware> middlewares_;
    std::vector<std::unique_ptr<Worker>> workers_;
    std::vector<std::thread> worker_threads_;
};

} // namespace mini

/*
 * 使用示例：
 *
 * int main() {
 *     mini::ServerConfig config;
 *     config.port = 8080;
 *     config.worker_threads = 4;
 *
 *     mini::MiniHttpServer server(config);
 *
 *     // 注册路由
 *     server.get("/", [](mini::HttpContext& ctx) {
 *         ctx.html("<h1>Welcome to Mini-HTTP!</h1>");
 *     });
 *
 *     server.get("/api/users/:id", [](mini::HttpContext& ctx) {
 *         std::string id = ctx.getParam("id");
 *         ctx.json("{\"id\": \"" + id + "\", \"name\": \"John\"}");
 *     });
 *
 *     server.post("/api/users", [](mini::HttpContext& ctx) {
 *         ctx.setStatus(201);
 *         ctx.json("{\"message\": \"User created\"}");
 *     });
 *
 *     // 阻塞运行，SIGTERM触发优雅关闭
 *     server.run();
 *
 *     return 0;
 * }
 */
```

#### 代码示例：配置加载器

```cpp
// config_loader.hpp - 配置文件加载与热更新
#pragma once

#include <string>
#include <fstream>
#include <sstream>
#include <unordered_map>
#include <functional>
#include <mutex>
#include <thread>
#include <atomic>
#include <chrono>
#include <sys/stat.h>

namespace mini {

// ============================================================
// 简单的INI/KV配置解析器
// ============================================================
class ConfigParser {
public:
    bool parse(const std::string& content) {
        values_.clear();
        std::istringstream stream(content);
        std::string line;
        std::string current_section;

        while (std::getline(stream, line)) {
            // 去除首尾空格
            size_t start = line.find_first_not_of(" \t\r\n");
            if (start == std::string::npos) continue;
            size_t end = line.find_last_not_of(" \t\r\n");
            line = line.substr(start, end - start + 1);

            // 跳过注释和空行
            if (line.empty() || line[0] == '#' || line[0] == ';') continue;

            // Section [name]
            if (line[0] == '[' && line.back() == ']') {
                current_section = line.substr(1, line.size() - 2) + ".";
                continue;
            }

            // Key = Value
            size_t eq_pos = line.find('=');
            if (eq_pos == std::string::npos) continue;

            std::string key = line.substr(0, eq_pos);
            std::string value = line.substr(eq_pos + 1);

            // 去除key/value首尾空格
            key.erase(key.find_last_not_of(" \t") + 1);
            key.erase(0, key.find_first_not_of(" \t"));
            value.erase(0, value.find_first_not_of(" \t"));
            value.erase(value.find_last_not_of(" \t") + 1);

            // 去除引号
            if (value.size() >= 2 &&
                ((value.front() == '"' && value.back() == '"') ||
                 (value.front() == '\'' && value.back() == '\''))) {
                value = value.substr(1, value.size() - 2);
            }

            values_[current_section + key] = value;
        }

        return true;
    }

    std::string getString(const std::string& key,
                          const std::string& default_val = "") const {
        auto it = values_.find(key);
        return it != values_.end() ? it->second : default_val;
    }

    int getInt(const std::string& key, int default_val = 0) const {
        auto it = values_.find(key);
        if (it == values_.end()) return default_val;
        try {
            return std::stoi(it->second);
        } catch (...) {
            return default_val;
        }
    }

    bool getBool(const std::string& key, bool default_val = false) const {
        auto it = values_.find(key);
        if (it == values_.end()) return default_val;
        const std::string& v = it->second;
        return v == "true" || v == "1" || v == "yes" || v == "on";
    }

    double getDouble(const std::string& key, double default_val = 0.0) const {
        auto it = values_.find(key);
        if (it == values_.end()) return default_val;
        try {
            return std::stod(it->second);
        } catch (...) {
            return default_val;
        }
    }

    const std::unordered_map<std::string, std::string>& values() const {
        return values_;
    }

private:
    std::unordered_map<std::string, std::string> values_;
};

// ============================================================
// 配置加载器（支持热更新）
// ============================================================
class ConfigLoader {
public:
    using ReloadCallback = std::function<void(const ConfigParser&)>;

    explicit ConfigLoader(const std::string& config_path)
        : config_path_(config_path) {}

    ~ConfigLoader() {
        stopWatching();
    }

    // 加载配置
    bool load() {
        std::ifstream file(config_path_);
        if (!file) return false;

        std::stringstream buffer;
        buffer << file.rdbuf();

        std::lock_guard<std::mutex> lock(mutex_);
        bool success = parser_.parse(buffer.str());
        if (success) {
            updateModTime();
        }
        return success;
    }

    // 获取配置值
    std::string getString(const std::string& key,
                          const std::string& default_val = "") const {
        std::lock_guard<std::mutex> lock(mutex_);
        return parser_.getString(key, default_val);
    }

    int getInt(const std::string& key, int default_val = 0) const {
        std::lock_guard<std::mutex> lock(mutex_);
        return parser_.getInt(key, default_val);
    }

    bool getBool(const std::string& key, bool default_val = false) const {
        std::lock_guard<std::mutex> lock(mutex_);
        return parser_.getBool(key, default_val);
    }

    // 设置热更新回调
    void onReload(ReloadCallback callback) {
        reload_callback_ = std::move(callback);
    }

    // 开始监视配置文件变化
    void startWatching(int interval_seconds = 5) {
        if (watching_) return;
        watching_ = true;
        watch_thread_ = std::thread([this, interval_seconds]() {
            while (watching_) {
                std::this_thread::sleep_for(
                    std::chrono::seconds(interval_seconds));

                if (!watching_) break;

                if (hasChanged()) {
                    printf("Config file changed, reloading...\n");
                    if (load() && reload_callback_) {
                        std::lock_guard<std::mutex> lock(mutex_);
                        reload_callback_(parser_);
                    }
                }
            }
        });
    }

    // 停止监视
    void stopWatching() {
        watching_ = false;
        if (watch_thread_.joinable()) {
            watch_thread_.join();
        }
    }

    // 将配置应用到ServerConfig
    void applyTo(ServerConfig& config) const {
        std::lock_guard<std::mutex> lock(mutex_);

        config.bind_address = parser_.getString("server.bind", "0.0.0.0");
        config.port = parser_.getInt("server.port", 8080);
        config.worker_threads = parser_.getInt("server.workers", 0);

        config.max_connections = parser_.getInt("connection.max", 10000);
        config.keep_alive_timeout_sec =
            parser_.getInt("connection.keepalive_timeout", 60);
        config.max_requests_per_conn =
            parser_.getInt("connection.max_requests", 1000);

        config.static_root = parser_.getString("static.root", "./static");
        config.file_cache_max_size =
            parser_.getInt("static.cache_size", 100 * 1024 * 1024);

        config.rate_limit_rps = parser_.getInt("ratelimit.rps", 10000);
        config.rate_limit_burst = parser_.getInt("ratelimit.burst", 1000);

        config.shutdown_timeout_sec =
            parser_.getInt("server.shutdown_timeout", 30);
    }

private:
    void updateModTime() {
        struct stat st;
        if (stat(config_path_.c_str(), &st) == 0) {
            last_mod_time_ = st.st_mtime;
        }
    }

    bool hasChanged() const {
        struct stat st;
        if (stat(config_path_.c_str(), &st) != 0) return false;
        return st.st_mtime != last_mod_time_;
    }

    std::string config_path_;
    ConfigParser parser_;
    mutable std::mutex mutex_;

    time_t last_mod_time_ = 0;
    std::atomic<bool> watching_{false};
    std::thread watch_thread_;
    ReloadCallback reload_callback_;
};

} // namespace mini

/*
 * 配置文件示例 (server.conf):
 *
 * [server]
 * bind = 0.0.0.0
 * port = 8080
 * workers = 4
 * shutdown_timeout = 30
 *
 * [connection]
 * max = 10000
 * keepalive_timeout = 60
 * max_requests = 1000
 *
 * [static]
 * root = ./static
 * cache_size = 104857600  # 100MB
 *
 * [ratelimit]
 * rps = 10000
 * burst = 1000
 *
 * 使用示例：
 *
 * mini::ConfigLoader loader("server.conf");
 * loader.load();
 *
 * mini::ServerConfig config;
 * loader.applyTo(config);
 *
 * // 热更新
 * loader.onReload([&config](const mini::ConfigParser& parser) {
 *     // 更新可热更新的配置项
 *     config.rate_limit_rps = parser.getInt("ratelimit.rps", 10000);
 * });
 * loader.startWatching(5);  // 每5秒检查一次
 */
```

> **Day 26-28 自测问题**：
> 1. 为什么使用SO_REUSEPORT而不是单个监听socket+锁？
> 2. 优雅关闭的关键步骤是什么？为什么不能直接kill -9？
> 3. 边缘触发（EPOLLET）相比水平触发有什么优势和注意事项？
> 4. 配置热更新时，哪些配置可以热更新，哪些不能？
> 5. 如何确保多Worker统计数据的准确性？

---

### 第四周自测问题汇总

1. HTTP/2帧层协议的设计目标是什么？
2. 流多路复用如何解决HTTP/1.1的队头阻塞？
3. HPACK压缩的静态表和动态表分别有什么作用？
4. 对象池如何避免内存分配开销？
5. Arena分配器为什么适合请求处理场景？
6. 什么是False Sharing？如何避免？
7. 压测时应该关注哪些关键指标？
8. 优雅关闭为什么重要？实现时要注意什么？
9. SO_REUSEPORT如何实现负载均衡？
10. 配置热更新有哪些限制？

---

### 第四周检验标准

| 检验项 | 标准 | 自评 |
|--------|------|------|
| 理解HTTP/2帧结构 | 能解释帧头部字段含义 | ☐ |
| 理解流多路复用 | 能描述流状态转换 | ☐ |
| 理解HPACK压缩 | 能解释静态/动态表机制 | ☐ |
| 理解对象池 | 能描述空闲链表实现 | ☐ |
| 理解Arena分配器 | 能解释指针递增分配 | ☐ |
| 理解无锁统计 | 能解释alignas(64)作用 | ☐ |
| 实现帧解析器 | 代码能正确解析HTTP/2帧 | ☐ |
| 实现对象池 | 代码能正确复用对象 | ☐ |
| 实现Mini服务器 | 代码能正确处理HTTP请求 | ☐ |
| 实现优雅关闭 | 代码能正确处理SIGTERM | ☐ |

---

### 第四周时间分配

| 内容 | 时间 |
|------|------|
| HTTP/2协议学习 | 4小时 |
| 帧解析器实现 | 6小时 |
| 对象池设计 | 3小时 |
| Arena分配器实现 | 3小时 |
| 压测方法学习 | 2小时 |
| 服务器组装 | 8小时 |
| 优雅关闭实现 | 4小时 |
| 配置系统实现 | 3小时 |
| 集成测试 | 2小时 |

---

## 本月检验标准汇总

### 理论掌握检验（20项）

| 序号 | 检验项 | 标准 | 自评 |
|------|--------|------|------|
| T1 | HTTP/1.1 Keep-Alive | 能解释连接复用机制和Pipeline限制 | ☐ |
| T2 | Chunked编码 | 能描述分块传输格式和应用场景 | ☐ |
| T3 | 状态机解析器 | 能画出HTTP解析状态转换图 | ☐ |
| T4 | 零拷贝解析 | 能解释string_view避免拷贝的原理 | ☐ |
| T5 | URL编码规范 | 能解释percent-encoding规则 | ☐ |
| T6 | 目录遍历攻击 | 能描述攻击原理和防护方法 | ☐ |
| T7 | 连接状态机 | 能描述连接生命周期各状态转换 | ☐ |
| T8 | 零拷贝I/O | 能解释sendfile/mmap工作原理 | ☐ |
| T9 | scatter-gather I/O | 能描述iovec和writev的优势 | ☐ |
| T10 | SO_REUSEPORT | 能解释多监听socket负载均衡机制 | ☐ |
| T11 | 条件请求 | 能描述ETag/If-None-Match/304流程 | ☐ |
| T12 | Range请求 | 能解释206响应和断点续传实现 | ☐ |
| T13 | 中间件模式 | 能画出洋葱模型执行流程 | ☐ |
| T14 | 令牌桶算法 | 能描述令牌桶限流原理 | ☐ |
| T15 | Trie树路由 | 能解释Trie树匹配和优先级规则 | ☐ |
| T16 | HTTP/2帧结构 | 能描述9字节帧头各字段含义 | ☐ |
| T17 | 流多路复用 | 能解释HTTP/2如何解决队头阻塞 | ☐ |
| T18 | HPACK压缩 | 能描述静态表/动态表机制 | ☐ |
| T19 | False Sharing | 能解释缓存行伪共享问题和解决方案 | ☐ |
| T20 | 优雅关闭 | 能描述SIGTERM处理和draining流程 | ☐ |

### 实践能力检验（20项）

| 序号 | 检验项 | 标准 | 自评 |
|------|--------|------|------|
| P1 | HTTP消息结构 | 实现HeaderMap和请求/响应类 | ☐ |
| P2 | 状态机解析器 | 实现零拷贝HTTP解析器 | ☐ |
| P3 | URL解析器 | 实现URL编解码和查询字符串解析 | ☐ |
| P4 | 路径规范化 | 实现安全的路径规范化函数 | ☐ |
| P5 | MIME检测 | 实现基于扩展名的MIME类型检测 | ☐ |
| P6 | 连接管理器 | 实现连接状态机和超时清理 | ☐ |
| P7 | Buffer链 | 实现scatter-gather缓冲区 | ☐ |
| P8 | 零拷贝文件 | 实现sendfile和mmap文件传输 | ☐ |
| P9 | 多线程服务器 | 实现SO_REUSEPORT多Worker架构 | ☐ |
| P10 | LRU文件缓存 | 实现带TTL的LRU缓存 | ☐ |
| P11 | 条件响应 | 实现ETag生成和304响应 | ☐ |
| P12 | Range处理 | 实现206部分内容响应 | ☐ |
| P13 | 中间件框架 | 实现中间件管道和洋葱模型 | ☐ |
| P14 | 日志中间件 | 实现请求日志记录 | ☐ |
| P15 | 限流中间件 | 实现令牌桶限流 | ☐ |
| P16 | Trie路由器 | 实现带路径参数的Trie路由 | ☐ |
| P17 | HTTP/2帧解析 | 实现基本帧编解码 | ☐ |
| P18 | 对象池 | 实现线程安全对象池 | ☐ |
| P19 | Arena分配器 | 实现请求级Arena分配器 | ☐ |
| P20 | 完整服务器 | 组装Mini-HTTP服务器并通过压测 | ☐ |

---

## 输出物清单

### 项目目录结构

```
mini-http-server/
├── include/
│   ├── http/
│   │   ├── http_message.hpp          # HTTP消息结构
│   │   ├── http_parser_v2.hpp        # 状态机解析器
│   │   ├── http_response_builder.hpp # 响应构建器
│   │   └── http2_frame.hpp           # HTTP/2帧解析
│   │
│   ├── url/
│   │   ├── url_parser.hpp            # URL编解码
│   │   ├── query_string.hpp          # 查询字符串
│   │   └── mime_types.hpp            # MIME类型
│   │
│   ├── connection/
│   │   ├── connection_manager.hpp    # 连接管理器
│   │   ├── buffer_chain.hpp          # 散列缓冲区
│   │   └── zero_copy_file.hpp        # 零拷贝文件
│   │
│   ├── server/
│   │   ├── thread_pool_server.hpp    # 多线程服务器
│   │   ├── mini_http_server.hpp      # 完整服务器
│   │   └── config_loader.hpp         # 配置加载
│   │
│   ├── middleware/
│   │   ├── middleware.hpp            # 中间件框架
│   │   ├── logging_mw.hpp            # 日志中间件
│   │   ├── cors_mw.hpp               # CORS中间件
│   │   └── rate_limit_mw.hpp         # 限流中间件
│   │
│   ├── router/
│   │   ├── trie_router.hpp           # Trie路由器
│   │   └── route_group.hpp           # 路由分组
│   │
│   ├── cache/
│   │   └── file_cache.hpp            # LRU文件缓存
│   │
│   └── perf/
│       ├── object_pool.hpp           # 对象池
│       └── arena_allocator.hpp       # Arena分配器
│
├── src/
│   └── main.cpp                      # 示例主程序
│
├── static/                           # 静态文件目录
│   ├── index.html
│   └── style.css
│
├── config/
│   └── server.conf                   # 配置文件示例
│
├── tests/
│   ├── test_parser.cpp               # 解析器测试
│   ├── test_router.cpp               # 路由器测试
│   └── test_cache.cpp                # 缓存测试
│
├── benchmarks/
│   ├── bench_parser.cpp              # 解析器性能测试
│   └── wrk_scripts/                  # wrk压测脚本
│       └── mixed_load.lua
│
├── docs/
│   └── architecture.md               # 架构文档
│
├── CMakeLists.txt
└── README.md
```

### 完成度检查表

| 组件 | 文件 | 状态 | 测试 |
|------|------|------|------|
| HTTP消息 | http_message.hpp | ☐ | ☐ |
| HTTP解析器 | http_parser_v2.hpp | ☐ | ☐ |
| URL解析 | url_parser.hpp | ☐ | ☐ |
| 连接管理 | connection_manager.hpp | ☐ | ☐ |
| Buffer链 | buffer_chain.hpp | ☐ | ☐ |
| 零拷贝 | zero_copy_file.hpp | ☐ | ☐ |
| 多线程服务器 | thread_pool_server.hpp | ☐ | ☐ |
| 文件缓存 | file_cache.hpp | ☐ | ☐ |
| 中间件框架 | middleware.hpp | ☐ | ☐ |
| Trie路由器 | trie_router.hpp | ☐ | ☐ |
| HTTP/2帧 | http2_frame.hpp | ☐ | ☐ |
| 对象池 | object_pool.hpp | ☐ | ☐ |
| Arena分配器 | arena_allocator.hpp | ☐ | ☐ |
| 完整服务器 | mini_http_server.hpp | ☐ | ☐ |
| 配置加载 | config_loader.hpp | ☐ | ☐ |

### 性能基准

| 指标 | 目标值 | 实测值 |
|------|--------|--------|
| QPS（简单响应） | > 100K | _____ |
| P99延迟 | < 1ms | _____ |
| 内存占用（10K连接） | < 500MB | _____ |
| CPU利用率 | > 90% | _____ |
| 解析器吞吐量 | > 500MB/s | _____ |

---

## 学习建议

### 学习路径图

```
本月学习路径：

Week 1: HTTP基础
    │
    ├── Day 1-2: HTTP/1.1协议
    │   └── 重点：Keep-Alive、Pipeline、Chunked
    │
    ├── Day 3-4: 状态机解析器
    │   └── 重点：零拷贝、string_view
    │
    └── Day 5-7: URL与MIME
        └── 重点：安全性（目录遍历防护）
    │
    ▼
Week 2: I/O优化
    │
    ├── Day 8-9: 连接管理
    │   └── 重点：状态机、超时处理
    │
    ├── Day 10-11: 零拷贝I/O
    │   └── 重点：sendfile、mmap、writev
    │
    └── Day 12-14: 多线程服务器
        └── 重点：SO_REUSEPORT、Worker模式
    │
    ▼
Week 3: 功能完善
    │
    ├── Day 15-16: 静态文件服务
    │   └── 重点：LRU缓存、条件请求
    │
    ├── Day 17-18: 中间件机制
    │   └── 重点：洋葱模型、限流算法
    │
    └── Day 19-21: 路由系统
        └── 重点：Trie树、路径参数
    │
    ▼
Week 4: 优化与集成
    │
    ├── Day 22-23: HTTP/2基础
    │   └── 重点：帧结构、多路复用
    │
    ├── Day 24-25: 性能优化
    │   └── 重点：对象池、Arena、压测
    │
    └── Day 26-28: 完整服务器
        └── 重点：组装、优雅关闭
```

### 调试技巧

```
常见调试场景：

1. 解析器问题
   ┌─────────────────────────────────────────┐
   │ 症状：请求解析失败或不完整               │
   ├─────────────────────────────────────────┤
   │ 调试：                                   │
   │ • 打印原始字节（hexdump）                │
   │ • 检查状态机当前状态                      │
   │ • 验证\r\n边界处理                       │
   │ • 检查Content-Length计算                 │
   └─────────────────────────────────────────┘

2. 连接泄漏
   ┌─────────────────────────────────────────┐
   │ 症状：fd数量持续增长                     │
   ├─────────────────────────────────────────┤
   │ 调试：                                   │
   │ • lsof -p <pid> | grep socket           │
   │ • 检查close()调用是否在所有路径上         │
   │ • 检查epoll事件是否正确删除               │
   │ • 添加连接计数日志                       │
   └─────────────────────────────────────────┘

3. 性能瓶颈
   ┌─────────────────────────────────────────┐
   │ 症状：QPS低于预期                        │
   ├─────────────────────────────────────────┤
   │ 调试：                                   │
   │ • perf record -g ./server               │
   │ • perf report 分析热点                   │
   │ • 生成火焰图定位瓶颈                      │
   │ • 检查锁竞争（mutex contention）          │
   └─────────────────────────────────────────┘

4. 内存问题
   ┌─────────────────────────────────────────┐
   │ 症状：内存持续增长或崩溃                  │
   ├─────────────────────────────────────────┤
   │ 调试：                                   │
   │ • valgrind --leak-check=full ./server   │
   │ • AddressSanitizer编译                   │
   │ • 检查string/vector是否正确清理          │
   │ • 检查对象池释放逻辑                      │
   └─────────────────────────────────────────┘
```

### 常见错误表

| 错误 | 原因 | 解决方案 |
|------|------|----------|
| EADDRINUSE | 端口被占用 | 等待TIME_WAIT或使用SO_REUSEADDR |
| EAGAIN | 非阻塞I/O无数据 | 正常情况，继续epoll_wait |
| EPIPE | 写入已关闭连接 | 忽略SIGPIPE，检查返回值 |
| ECONNRESET | 对端重置连接 | 正常关闭连接即可 |
| 解析超时 | 请求不完整 | 设置读取超时，关闭慢连接 |
| 内存溢出 | 请求过大 | 限制最大请求大小 |
| 文件描述符耗尽 | 连接泄漏 | 检查close()调用 |
| 惊群效应 | 多进程accept | 使用SO_REUSEPORT |

---

## 结语

### 本月知识总结

```
知识脉络回顾：

Month-30: Reactor模式
    ├── epoll事件驱动
    ├── 非阻塞I/O
    └── 事件循环设计
         │
         ▼
Month-31: Proactor模式
    ├── io_uring异步I/O
    ├── 提交队列/完成队列
    └── 批量提交优化
         │
         ▼
Month-32: Envoy架构
    ├── 线程模型（Thread-per-Core）
    ├── Filter链机制
    └── 配置热更新
         │
         ▼
Month-33: HTTP服务器实现 ← 本月
    ├── HTTP协议深入
    │   └── 状态机解析、零拷贝
    ├── 连接与I/O优化
    │   └── sendfile、mmap、writev
    ├── 功能组件
    │   └── 缓存、中间件、路由
    └── 性能优化
        └── 对象池、Arena、压测

能力提升：
┌─────────────────────────────────────────────┐
│                                             │
│  理论 → 实践 → 优化 → 生产级                 │
│                                             │
│  • 从epoll到完整HTTP服务器                  │
│  • 从单线程到多Worker架构                   │
│  • 从功能正确到性能优化                      │
│  • 从简单demo到可压测的服务器                │
│                                             │
└─────────────────────────────────────────────┘
```

### 核心收获

1. **协议理解**：深入理解HTTP/1.1和HTTP/2协议细节
2. **解析技术**：掌握状态机驱动的零拷贝解析器设计
3. **I/O优化**：理解sendfile、mmap等零拷贝技术原理
4. **架构设计**：掌握多Worker、中间件、路由等架构模式
5. **性能优化**：掌握对象池、Arena等内存优化技术
6. **工程实践**：实现一个可压测的生产级HTTP服务器

---

## 下月预告：Month-34 RPC框架基础

```
Month-34 学习主题：RPC框架设计与实现

从HTTP到RPC：
┌─────────────────────────────────────────────┐
│                                             │
│  HTTP服务器（本月）                          │
│  └── 请求/响应模式                           │
│  └── 文本协议（人类可读）                     │
│  └── Web服务场景                             │
│                                             │
│           ↓ 演进                             │
│                                             │
│  RPC框架（下月）                             │
│  └── 远程过程调用抽象                        │
│  └── 二进制协议（高效紧凑）                   │
│  └── 微服务通信场景                          │
│                                             │
└─────────────────────────────────────────────┘

下月内容预览：

Week 1: RPC基础概念
├── RPC原理与调用流程
├── IDL与代码生成
└── 序列化协议（Protobuf）

Week 2: 网络传输层
├── 自定义二进制协议
├── 连接池与复用
└── 超时与重试机制

Week 3: 服务治理
├── 服务注册与发现
├── 负载均衡策略
└── 熔断与限流

Week 4: 完整RPC框架
├── 组装mini-rpc框架
├── 性能优化
└── 可观测性（tracing/metrics）

复用本月知识：
• HTTP服务器经验 → RPC服务器设计
• 连接管理 → RPC连接池
• 中间件模式 → RPC拦截器
• 路由匹配 → 服务方法分发
• 性能优化 → RPC性能调优
```

---

**本月学习完成后，你将具备从零实现生产级HTTP服务器的完整能力，为下月深入RPC框架设计打下坚实基础。**

---

[返回目录](../README.md) | [上一月：Month-32 Envoy架构](./month-32.md) | [下一月：Month-34 RPC框架](./month-34.md)