# Month 32: Envoy架构分析——云原生代理

> **本月主题**：深入学习Envoy代理架构，掌握Service Mesh核心技术，理解高性能代理的设计思想
> **前置知识**：Month-30 Reactor模式、Month-31 Proactor模式（事件驱动架构基础）
> **学习时长**：140小时（4周 × 35小时/周）
> **难度评级**：★★★★★（高级挑战——云原生架构实战）

---

## 本月导航

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     Month-32 学习路线图                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│     第一周              第二周              第三周              第四周    │
│   ┌─────────┐        ┌─────────┐        ┌─────────┐        ┌─────────┐ │
│   │ Envoy   │        │  线程   │        │ Filter  │        │  xDS    │ │
│   │架构概览 │───────▶│  模型   │───────▶│  机制   │───────▶│ 热更新  │ │
│   └─────────┘        └─────────┘        └─────────┘        └─────────┘ │
│       │                  │                  │                  │        │
│       ▼                  ▼                  ▼                  ▼        │
│   ┌─────────┐        ┌─────────┐        ┌─────────┐        ┌─────────┐ │
│   │Service  │        │Main/    │        │Network  │        │LDS/RDS/ │ │
│   │Mesh背景 │        │Worker   │        │Filter   │        │CDS/EDS  │ │
│   ├─────────┤        ├─────────┤        ├─────────┤        ├─────────┤ │
│   │核心组件 │        │TLS机制  │        │HTTP     │        │配置版本 │ │
│   │详解     │        │         │        │Filter   │        │管理     │ │
│   ├─────────┤        ├─────────┤        ├─────────┤        ├─────────┤ │
│   │请求处理 │        │Dispatcher│       │Filter   │        │Mini-    │ │
│   │流程     │        │事件循环 │        │Chain    │        │Envoy    │ │
│   └─────────┘        └─────────┘        └─────────┘        └─────────┘ │
│                                                                          │
├─────────────────────────────────────────────────────────────────────────┤
│  学习成果：理解现代云原生代理架构 → 掌握Envoy核心设计 → 实现Mini代理   │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 本月主题概述

### 为什么学习Envoy？

```
Envoy在云原生生态中的地位：
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                          │
│  云原生代理的演进：                                                     │
│                                                                          │
│  2000s               2010s               2020s                          │
│  ┌─────────┐        ┌─────────┐        ┌─────────────────┐             │
│  │传统代理 │        │微服务   │        │Service Mesh     │             │
│  │         │───────▶│代理     │───────▶│                 │             │
│  │ Nginx   │        │ HAProxy │        │ Envoy + Istio   │             │
│  │ Apache  │        │ Nginx   │        │ Linkerd         │             │
│  └─────────┘        └─────────┘        └─────────────────┘             │
│                                                                          │
│  Envoy的应用场景：                                                      │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                                                                    │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐               │ │
│  │  │  Istio      │  │  AWS App    │  │  Ambassador │               │ │
│  │  │  Sidecar    │  │  Mesh       │  │  API        │               │ │
│  │  │  Proxy      │  │             │  │  Gateway    │               │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘               │ │
│  │        │                │                │                        │ │
│  │        └────────────────┼────────────────┘                        │ │
│  │                         ▼                                          │ │
│  │               ┌─────────────────┐                                 │ │
│  │               │     Envoy       │                                 │ │
│  │               │   作为数据面    │                                 │ │
│  │               └─────────────────┘                                 │ │
│  │                                                                    │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  主要使用者：                                                           │
│  ┌────────────┬──────────────────────────────────────────────────────┐ │
│  │ 公司/项目   │ 使用场景                                             │ │
│  ├────────────┼──────────────────────────────────────────────────────┤ │
│  │ Google     │ Istio Service Mesh的默认数据面                       │ │
│  │ Lyft       │ Envoy的创造者，全公司基础设施                        │ │
│  │ AWS        │ App Mesh服务网格                                     │ │
│  │ Microsoft  │ Azure Service Fabric Mesh                            │ │
│  │ Pinterest  │ 服务间通信代理                                       │ │
│  │ Airbnb     │ API网关和服务代理                                    │ │
│  │ Stripe     │ 边缘代理和内部服务网格                               │ │
│  │ Dropbox    │ 流量管理和负载均衡                                   │ │
│  └────────────┴──────────────────────────────────────────────────────┘ │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Envoy vs 传统代理

```
Envoy与传统代理的对比：
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                          │
│  ┌──────────────┬──────────────┬──────────────┬──────────────┐         │
│  │   特性        │   Nginx      │   HAProxy    │   Envoy      │         │
│  ├──────────────┼──────────────┼──────────────┼──────────────┤         │
│  │ 语言          │ C            │ C            │ C++          │         │
│  │ 配置热更新    │ 需要reload   │ 需要reload   │ 原生支持     │         │
│  │ 服务发现      │ 静态/DNS     │ 静态/DNS     │ 动态xDS      │         │
│  │ 可观测性      │ 日志为主     │ 统计为主     │ 全面支持     │         │
│  │ HTTP/2       │ 支持         │ 支持         │ 原生支持     │         │
│  │ gRPC         │ 有限支持     │ 有限支持     │ 原生支持     │         │
│  │ 扩展机制      │ 模块/Lua     │ Lua          │ Filter/WASM  │         │
│  │ Service Mesh │ 不适合       │ 不适合       │ 专门设计     │         │
│  └──────────────┴──────────────┴──────────────┴──────────────┘         │
│                                                                          │
│  Envoy的独特优势：                                                      │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                                                                    │ │
│  │  1. 现代化设计                                                    │ │
│  │     └── 从零开始为微服务和云原生设计                              │ │
│  │     └── 原生支持HTTP/2、gRPC、WebSocket                           │ │
│  │                                                                    │ │
│  │  2. 动态配置                                                      │ │
│  │     └── xDS API实现运行时配置更新                                │ │
│  │     └── 无需重启或reload                                          │ │
│  │                                                                    │ │
│  │  3. 可观测性                                                      │ │
│  │     └── 内置丰富的统计指标                                        │ │
│  │     └── 分布式追踪支持（Jaeger、Zipkin等）                        │ │
│  │     └── 访问日志和审计                                            │ │
│  │                                                                    │ │
│  │  4. 高级负载均衡                                                  │ │
│  │     └── 多种负载均衡策略                                          │ │
│  │     └── 区域感知路由                                              │ │
│  │     └── 熔断和重试                                                │ │
│  │                                                                    │ │
│  │  5. 可扩展性                                                      │ │
│  │     └── Filter链机制                                              │ │
│  │     └── WASM扩展支持                                              │ │
│  │     └── Lua脚本                                                   │ │
│  │                                                                    │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 与Month-30/31的衔接

```
从Reactor/Proactor到Envoy：
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                          │
│  Month-30: Reactor模式          Month-31: Proactor模式                  │
│  ┌─────────────────────┐       ┌─────────────────────┐                 │
│  │ 事件就绪通知         │       │ 事件完成通知         │                 │
│  │ - epoll/kqueue      │       │ - IOCP/io_uring    │                 │
│  │ - 同步I/O            │       │ - 异步I/O           │                 │
│  └──────────┬──────────┘       └──────────┬──────────┘                 │
│             │                              │                            │
│             └──────────────┬───────────────┘                            │
│                            │                                            │
│                            ▼                                            │
│             ┌──────────────────────────────┐                           │
│             │      Month-32: Envoy         │                           │
│             │   将理论付诸实战              │                           │
│             └──────────────────────────────┘                           │
│                            │                                            │
│          ┌─────────────────┼─────────────────┐                         │
│          ▼                 ▼                 ▼                         │
│  ┌───────────────┐ ┌───────────────┐ ┌───────────────┐                │
│  │ 线程模型      │ │ Filter链      │ │ 配置热更新    │                │
│  │               │ │               │ │               │                │
│  │ Main/Worker  │ │ Network/HTTP  │ │ xDS协议      │                │
│  │ 分离设计     │ │ Filter机制   │ │ TLS传播      │                │
│  │               │ │               │ │               │                │
│  │ 使用Reactor  │ │ 请求处理     │ │ 无损更新     │                │
│  │ 事件循环     │ │ 管道设计     │ │               │                │
│  └───────────────┘ └───────────────┘ └───────────────┘                │
│                                                                          │
│  知识应用：                                                             │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                                                                    │ │
│  │  Month-30学到的              在Envoy中的应用                       │ │
│  │  ─────────────────────────────────────────────────────────────    │ │
│  │  epoll事件循环         ───▶  Dispatcher事件分发器                 │ │
│  │  非阻塞I/O             ───▶  Worker线程I/O处理                    │ │
│  │  事件驱动架构          ───▶  整体架构设计                         │ │
│  │                                                                    │ │
│  │  Month-31学到的              在Envoy中的应用                       │ │
│  │  ─────────────────────────────────────────────────────────────    │ │
│  │  异步操作抽象          ───▶  Filter异步处理                       │ │
│  │  完成回调机制          ───▶  Filter回调链                         │ │
│  │  高性能设计            ───▶  零拷贝、内存池                       │ │
│  │                                                                    │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 知识体系总览

```
Month-32知识架构：
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                          │
│                    ┌─────────────────────────────┐                      │
│                    │        应用层               │                      │
│                    │  Mini-Envoy代理框架实现     │                      │
│                    └─────────────┬───────────────┘                      │
│                                  │                                       │
│          ┌───────────────────────┼───────────────────────┐              │
│          │                       │                       │              │
│          ▼                       ▼                       ▼              │
│  ┌───────────────┐      ┌───────────────┐      ┌───────────────┐       │
│  │   线程模型     │      │   Filter机制  │      │   配置管理    │       │
│  │               │      │               │      │               │       │
│  │ Main Thread  │      │ Network Filter│      │ xDS协议      │       │
│  │ Worker Thread│      │ HTTP Filter   │      │ 配置热更新    │       │
│  │ TLS机制      │      │ Filter Chain  │      │ 版本管理     │       │
│  └───────┬───────┘      └───────┬───────┘      └───────┬───────┘       │
│          │                       │                       │              │
│          └───────────────────────┼───────────────────────┘              │
│                                  │                                       │
│                                  ▼                                       │
│                    ┌─────────────────────────────┐                      │
│                    │         核心组件            │                      │
│                    │  Listener/Cluster/Route     │                      │
│                    │  Dispatcher/Connection      │                      │
│                    └─────────────┬───────────────┘                      │
│                                  │                                       │
│                                  ▼                                       │
│                    ┌─────────────────────────────┐                      │
│                    │         基础设施            │                      │
│                    │  Reactor模式 + 内存管理     │                      │
│                    │  (Month-30/31知识应用)      │                      │
│                    └─────────────────────────────┘                      │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 学习目标

### 理论目标

| 序号 | 目标 | 验证方式 |
|:----:|------|----------|
| T1 | 理解Service Mesh概念 | 能解释Envoy在Service Mesh中的角色 |
| T2 | 掌握Envoy核心组件 | 能画出Listener/Cluster/Route架构图 |
| T3 | 理解请求处理流程 | 能追踪一个HTTP请求的完整路径 |
| T4 | 掌握线程模型设计 | 能解释Main/Worker分离的原因 |
| T5 | 理解TLS传播机制 | 能解释配置如何传播到Worker |
| T6 | 掌握Filter机制 | 能解释Network/HTTP Filter的区别 |
| T7 | 理解xDS协议 | 能解释LDS/RDS/CDS/EDS的作用 |
| T8 | 掌握配置热更新 | 能解释无损更新的实现原理 |

### 实践目标

| 序号 | 目标 | 产出物 |
|:----:|------|--------|
| P1 | 分析Envoy配置 | `envoy_config_analysis.md` |
| P2 | 实现简化Dispatcher | `dispatcher.hpp` |
| P3 | 实现TLS机制 | `thread_local.hpp` |
| P4 | 实现Network Filter | `network_filter.hpp` |
| P5 | 实现HTTP Filter | `http_filter.hpp` |
| P6 | 实现Filter Chain | `filter_chain.hpp` |
| P7 | 实现xDS客户端 | `xds_client.hpp` |
| P8 | 完成Mini-Envoy | `mini_envoy/` 完整项目 |

---

## 第一周：Envoy架构概览（Day 1-7）

> **本周目标**：理解Envoy的整体架构设计，掌握核心组件的职责和交互方式，理解请求处理的完整流程。

```
┌─────────────────────────────────────────────────────────────────┐
│                    第一周学习路线图                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   Day 1-2              Day 3-4              Day 5-7             │
│   ┌─────────┐         ┌─────────┐         ┌─────────┐          │
│   │ Envoy   │         │  核心   │         │  请求   │          │
│   │简介与生态│────────▶│组件详解 │────────▶│处理流程 │          │
│   └─────────┘         └─────────┘         └─────────┘          │
│       │                   │                   │                 │
│       ▼                   ▼                   ▼                 │
│   Service Mesh        Listener            连接生命周期          │
│   设计哲学            Filter Chain        HTTP处理路径          │
│   代理对比            Cluster             负载均衡策略          │
│                       Route               重试与超时            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Day 1-2：Envoy简介与生态（10小时）

#### 1.1 Service Mesh与Envoy的诞生

```
Service Mesh架构演进：
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                          │
│  阶段1：单体应用                                                        │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                                                                  │   │
│  │  ┌──────────────────────────────────────────────────────────┐   │   │
│  │  │                     单体应用                               │   │   │
│  │  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐         │   │   │
│  │  │  │ 用户    │ │ 订单    │ │ 库存    │ │ 支付    │         │   │   │
│  │  │  │ 模块    │ │ 模块    │ │ 模块    │ │ 模块    │         │   │   │
│  │  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘         │   │   │
│  │  │              内部函数调用                                   │   │   │
│  │  └──────────────────────────────────────────────────────────┘   │   │
│  │                                                                  │   │
│  │  特点：简单，但扩展性差                                         │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  阶段2：微服务（直接调用）                                              │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                                                                  │   │
│  │  ┌─────────┐   HTTP/gRPC   ┌─────────┐   HTTP/gRPC   ┌─────────┐│   │
│  │  │ 用户    │◄─────────────▶│ 订单    │◄─────────────▶│ 库存    ││   │
│  │  │ 服务    │               │ 服务    │               │ 服务    ││   │
│  │  └─────────┘               └─────────┘               └─────────┘│   │
│  │       │                         │                         │      │   │
│  │       │    ┌────────────────────┘                         │      │   │
│  │       │    │                                              │      │   │
│  │       ▼    ▼                                              ▼      │   │
│  │  ┌─────────┐                                        ┌─────────┐ │   │
│  │  │ 支付    │                                        │ 通知    │ │   │
│  │  │ 服务    │                                        │ 服务    │ │   │
│  │  └─────────┘                                        └─────────┘ │   │
│  │                                                                  │   │
│  │  问题：                                                          │   │
│  │  - 服务发现需要每个服务实现                                      │   │
│  │  - 负载均衡逻辑分散在各处                                        │   │
│  │  - 熔断、重试难以统一管理                                        │   │
│  │  - 可观测性难以实现                                              │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  阶段3：Service Mesh                                                    │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                                                                  │   │
│  │  ┌─────────────────────────────────────────────────────────┐    │   │
│  │  │                    控制面 (Istio)                        │    │   │
│  │  │  配置管理 | 服务发现 | 证书管理 | 策略管理              │    │   │
│  │  └─────────────────────────────────────────────────────────┘    │   │
│  │                            │ xDS API                             │   │
│  │                            ▼                                     │   │
│  │  ┌─────────────────────────────────────────────────────────┐    │   │
│  │  │                    数据面 (Envoy)                        │    │   │
│  │  │                                                          │    │   │
│  │  │  ┌───────────────┐      ┌───────────────┐               │    │   │
│  │  │  │ Pod A         │      │ Pod B         │               │    │   │
│  │  │  │ ┌───────────┐ │      │ ┌───────────┐ │               │    │   │
│  │  │  │ │ App       │ │      │ │ App       │ │               │    │   │
│  │  │  │ └─────┬─────┘ │      │ └─────┬─────┘ │               │    │   │
│  │  │  │       │       │      │       │       │               │    │   │
│  │  │  │ ┌─────▼─────┐ │      │ ┌─────▼─────┐ │               │    │   │
│  │  │  │ │ Envoy     │◄┼──────┼▶│ Envoy     │ │               │    │   │
│  │  │  │ │ Sidecar   │ │      │ │ Sidecar   │ │               │    │   │
│  │  │  │ └───────────┘ │      │ └───────────┘ │               │    │   │
│  │  │  └───────────────┘      └───────────────┘               │    │   │
│  │  └─────────────────────────────────────────────────────────┘    │   │
│  │                                                                  │   │
│  │  优势：                                                          │   │
│  │  - 业务代码与基础设施解耦                                        │   │
│  │  - 统一的流量管理、安全、可观测性                                │   │
│  │  - 支持多语言服务                                                │   │
│  │  - 无侵入式升级                                                  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

#### 1.2 Envoy的设计哲学

```
Envoy核心设计原则：
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                          │
│  原则1：进程外架构（Out of Process）                                    │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                                                                    │ │
│  │  传统库方式：                    Envoy方式：                       │ │
│  │  ┌─────────────────┐            ┌─────────────────┐               │ │
│  │  │     应用程序     │            │     应用程序     │               │ │
│  │  │  ┌───────────┐  │            └────────┬────────┘               │ │
│  │  │  │ 网络库     │  │                     │ localhost              │ │
│  │  │  │ (嵌入式)  │  │            ┌────────▼────────┐               │ │
│  │  │  └───────────┘  │            │     Envoy       │               │ │
│  │  └─────────────────┘            │  (独立进程)     │               │ │
│  │                                  └─────────────────┘               │ │
│  │                                                                    │ │
│  │  优势：                                                           │ │
│  │  - 语言无关（任何语言的应用都可以使用）                           │ │
│  │  - 独立升级（不需要重新编译应用）                                 │ │
│  │  - 故障隔离（Envoy崩溃不影响应用）                                │ │
│  │                                                                    │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  原则2：L3/L4 + L7 统一处理                                             │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                                                                    │ │
│  │  OSI模型              Envoy处理                                   │ │
│  │  ─────────────────────────────────────────────────────────────    │ │
│  │  L7 应用层   ────────  HTTP/gRPC/WebSocket Filter                │ │
│  │  L4 传输层   ────────  TCP代理、TLS终止                          │ │
│  │  L3 网络层   ────────  IP地址、端口匹配                          │ │
│  │                                                                    │ │
│  │  统一架构的好处：                                                 │ │
│  │  - 同一套配置管理所有层次                                         │ │
│  │  - 可观测性覆盖所有层次                                           │ │
│  │  - 策略可以跨层次应用                                             │ │
│  │                                                                    │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  原则3：可扩展性优先                                                    │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                                                                    │ │
│  │  扩展机制：                                                       │ │
│  │                                                                    │ │
│  │  ┌─────────────────────────────────────────────────────────────┐ │ │
│  │  │                     Filter Chain                             │ │ │
│  │  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐   │ │ │
│  │  │  │ TLS    │→│ 限流   │→│ 认证   │→│ 路由   │→│ 日志   │   │ │ │
│  │  │  │ Filter │ │ Filter │ │ Filter │ │ Filter │ │ Filter │   │ │ │
│  │  │  └────────┘ └────────┘ └────────┘ └────────┘ └────────┘   │ │ │
│  │  │             可插拔，可自定义顺序                             │ │ │
│  │  └─────────────────────────────────────────────────────────────┘ │ │
│  │                                                                    │ │
│  │  扩展方式：                                                       │ │
│  │  1. C++ Filter（性能最佳）                                        │ │
│  │  2. Lua脚本（快速原型）                                           │ │
│  │  3. WASM（安全沙箱，多语言支持）                                  │ │
│  │  4. External Processing（外部服务处理）                           │ │
│  │                                                                    │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  原则4：动态配置                                                        │ │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                                                                    │ │
│  │  传统方式：                         Envoy方式：                   │ │
│  │  ┌─────────────────────┐           ┌─────────────────────┐       │ │
│  │  │ 1. 修改配置文件      │           │ 1. 控制面推送配置    │       │ │
│  │  │ 2. 测试配置          │           │ 2. Envoy实时接收    │       │ │
│  │  │ 3. 重启/reload       │           │ 3. 热更新生效       │       │ │
│  │  │ 4. 连接中断          │           │ 4. 连接不中断       │       │ │
│  │  └─────────────────────┘           └─────────────────────┘       │ │
│  │                                                                    │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

#### 1.3 Envoy配置文件示例

```yaml
# envoy_config_example.yaml - Envoy基础配置示例

# 静态资源配置（用于学习，生产环境通常使用xDS动态配置）
static_resources:

  # Listener配置：定义Envoy监听的端口和处理方式
  listeners:
    - name: listener_0
      address:
        socket_address:
          address: 0.0.0.0
          port_value: 10000

      # Filter Chain：处理请求的过滤器链
      filter_chains:
        - filters:
            # HTTP连接管理器Filter
            - name: envoy.filters.network.http_connection_manager
              typed_config:
                "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
                stat_prefix: ingress_http
                codec_type: AUTO

                # 路由配置
                route_config:
                  name: local_route
                  virtual_hosts:
                    - name: local_service
                      domains: ["*"]
                      routes:
                        - match:
                            prefix: "/"
                          route:
                            cluster: service_backend

                # HTTP Filter链
                http_filters:
                  # Router Filter必须是最后一个
                  - name: envoy.filters.http.router
                    typed_config:
                      "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router

  # Cluster配置：定义上游服务集群
  clusters:
    - name: service_backend
      connect_timeout: 0.25s
      type: STRICT_DNS
      lb_policy: ROUND_ROBIN

      # 负载均衡配置
      load_assignment:
        cluster_name: service_backend
        endpoints:
          - lb_endpoints:
              - endpoint:
                  address:
                    socket_address:
                      address: backend
                      port_value: 8080

# 管理接口配置
admin:
  address:
    socket_address:
      address: 0.0.0.0
      port_value: 9901
```

```cpp
// envoy_config_parser.hpp - 配置解析示例
#pragma once

#include <string>
#include <vector>
#include <map>
#include <memory>
#include <iostream>

namespace mini_envoy {

// 地址配置
struct SocketAddress {
    std::string address;
    uint16_t port;
};

// 端点配置
struct Endpoint {
    SocketAddress socket_address;
    uint32_t weight = 1;
};

// 集群配置
struct ClusterConfig {
    std::string name;
    std::string type;  // STATIC, STRICT_DNS, LOGICAL_DNS, EDS
    std::string lb_policy;  // ROUND_ROBIN, LEAST_REQUEST, RANDOM
    std::chrono::milliseconds connect_timeout{250};
    std::vector<Endpoint> endpoints;
};

// 路由匹配配置
struct RouteMatch {
    std::string prefix;
    std::string path;
    std::string regex;
};

// 路由动作配置
struct RouteAction {
    std::string cluster;
    std::chrono::milliseconds timeout{0};
    uint32_t retry_count = 0;
};

// 路由配置
struct Route {
    RouteMatch match;
    RouteAction action;
};

// 虚拟主机配置
struct VirtualHost {
    std::string name;
    std::vector<std::string> domains;
    std::vector<Route> routes;
};

// HTTP连接管理器配置
struct HttpConnectionManagerConfig {
    std::string stat_prefix;
    std::string codec_type;  // AUTO, HTTP1, HTTP2
    std::vector<VirtualHost> virtual_hosts;
    std::vector<std::string> http_filters;
};

// Filter配置
struct FilterConfig {
    std::string name;
    std::string type;
    // 具体配置（简化处理）
    std::map<std::string, std::string> config;
};

// Filter Chain配置
struct FilterChainConfig {
    std::vector<FilterConfig> filters;
    // TLS配置（简化）
    bool use_tls = false;
};

// Listener配置
struct ListenerConfig {
    std::string name;
    SocketAddress address;
    std::vector<FilterChainConfig> filter_chains;
};

// 完整Envoy配置
struct EnvoyConfig {
    std::vector<ListenerConfig> listeners;
    std::vector<ClusterConfig> clusters;
    SocketAddress admin_address;
};

/*
 * 配置结构可视化：
 *
 * EnvoyConfig
 * ├── listeners[]
 * │   └── ListenerConfig
 * │       ├── name
 * │       ├── address
 * │       └── filter_chains[]
 * │           └── FilterChainConfig
 * │               └── filters[]
 * │                   └── FilterConfig
 * │                       ├── name
 * │                       └── typed_config
 * │
 * └── clusters[]
 *     └── ClusterConfig
 *         ├── name
 *         ├── type
 *         ├── lb_policy
 *         └── endpoints[]
 *             └── Endpoint
 *                 └── socket_address
 */

// 简化的配置解析器
class ConfigParser {
public:
    // 从YAML字符串解析（简化实现，实际使用yaml-cpp）
    static EnvoyConfig parse(const std::string& yaml_content) {
        EnvoyConfig config;

        // 这里应该使用yaml-cpp进行实际解析
        // 简化示例，硬编码一个默认配置

        // 默认Listener
        ListenerConfig listener;
        listener.name = "listener_0";
        listener.address = {"0.0.0.0", 10000};

        FilterChainConfig filter_chain;
        FilterConfig hcm_filter;
        hcm_filter.name = "envoy.filters.network.http_connection_manager";
        hcm_filter.type = "HttpConnectionManager";
        filter_chain.filters.push_back(hcm_filter);

        listener.filter_chains.push_back(filter_chain);
        config.listeners.push_back(listener);

        // 默认Cluster
        ClusterConfig cluster;
        cluster.name = "service_backend";
        cluster.type = "STATIC";
        cluster.lb_policy = "ROUND_ROBIN";
        cluster.endpoints.push_back({{"127.0.0.1", 8080}, 1});
        config.clusters.push_back(cluster);

        // Admin
        config.admin_address = {"0.0.0.0", 9901};

        return config;
    }

    // 验证配置
    static bool validate(const EnvoyConfig& config) {
        // 检查必要字段
        if (config.listeners.empty()) {
            std::cerr << "Error: No listeners configured" << std::endl;
            return false;
        }

        for (const auto& listener : config.listeners) {
            if (listener.filter_chains.empty()) {
                std::cerr << "Error: Listener " << listener.name
                          << " has no filter chains" << std::endl;
                return false;
            }
        }

        if (config.clusters.empty()) {
            std::cerr << "Warning: No clusters configured" << std::endl;
        }

        return true;
    }

    // 打印配置摘要
    static void printSummary(const EnvoyConfig& config) {
        std::cout << "\n=== Envoy Configuration Summary ===" << std::endl;

        std::cout << "\nListeners (" << config.listeners.size() << "):" << std::endl;
        for (const auto& l : config.listeners) {
            std::cout << "  - " << l.name << " @ "
                      << l.address.address << ":" << l.address.port << std::endl;
            std::cout << "    Filter Chains: " << l.filter_chains.size() << std::endl;
        }

        std::cout << "\nClusters (" << config.clusters.size() << "):" << std::endl;
        for (const auto& c : config.clusters) {
            std::cout << "  - " << c.name << " (" << c.type << ", "
                      << c.lb_policy << ")" << std::endl;
            std::cout << "    Endpoints: " << c.endpoints.size() << std::endl;
        }

        std::cout << "\nAdmin: " << config.admin_address.address
                  << ":" << config.admin_address.port << std::endl;
    }
};

} // namespace mini_envoy
```

### Day 3-4：核心组件详解（10小时）

#### 3.1 Envoy核心组件架构

```
Envoy核心组件详解：
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                          │
│                           Envoy进程                                      │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                                                                    │ │
│  │  ┌─────────────────────────────────────────────────────────────┐ │ │
│  │  │                    Listener Manager                          │ │ │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │ │ │
│  │  │  │ Listener 1  │  │ Listener 2  │  │ Listener N  │         │ │ │
│  │  │  │ :8080       │  │ :8443       │  │ :9090       │         │ │ │
│  │  │  │             │  │             │  │             │         │ │ │
│  │  │  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │         │ │ │
│  │  │  │ │Filter   │ │  │ │Filter   │ │  │ │Filter   │ │         │ │ │
│  │  │  │ │Chain    │ │  │ │Chain    │ │  │ │Chain    │ │         │ │ │
│  │  │  │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │         │ │ │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘         │ │ │
│  │  └─────────────────────────────────────────────────────────────┘ │ │
│  │                              │                                    │ │
│  │                              ▼ 路由                               │ │
│  │  ┌─────────────────────────────────────────────────────────────┐ │ │
│  │  │                    Cluster Manager                           │ │ │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │ │ │
│  │  │  │ Cluster A   │  │ Cluster B   │  │ Cluster C   │         │ │ │
│  │  │  │             │  │             │  │             │         │ │ │
│  │  │  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │         │ │ │
│  │  │  │ │Endpoint │ │  │ │Endpoint │ │  │ │Endpoint │ │         │ │ │
│  │  │  │ │Pool     │ │  │ │Pool     │ │  │ │Pool     │ │         │ │ │
│  │  │  │ │         │ │  │ │         │ │  │ │         │ │         │ │ │
│  │  │  │ │ Host1   │ │  │ │ Host1   │ │  │ │ Host1   │ │         │ │ │
│  │  │  │ │ Host2   │ │  │ │ Host2   │ │  │ │ Host2   │ │         │ │ │
│  │  │  │ │ Host3   │ │  │ │         │ │  │ │ Host3   │ │         │ │ │
│  │  │  │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │         │ │ │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘         │ │ │
│  │  └─────────────────────────────────────────────────────────────┘ │ │
│  │                                                                    │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  组件职责：                                                             │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                                                                  │   │
│  │  Listener                                                        │   │
│  │  ├── 绑定端口，接收下游（客户端）连接                           │   │
│  │  ├── 匹配Filter Chain（基于SNI、源IP等）                        │   │
│  │  └── 创建连接并交给Filter Chain处理                             │   │
│  │                                                                  │   │
│  │  Filter Chain                                                    │   │
│  │  ├── 由多个Filter组成的处理管道                                 │   │
│  │  ├── Network Filter处理L4数据                                   │   │
│  │  └── HTTP Filter处理L7数据                                      │   │
│  │                                                                  │   │
│  │  Cluster                                                         │   │
│  │  ├── 代表一组上游（后端）服务                                   │   │
│  │  ├── 管理连接池                                                 │   │
│  │  └── 提供负载均衡、健康检查                                     │   │
│  │                                                                  │   │
│  │  Endpoint                                                        │   │
│  │  ├── Cluster中的单个后端实例                                    │   │
│  │  ├── IP:Port + 权重                                             │   │
│  │  └── 健康状态                                                   │   │
│  │                                                                  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

#### 3.2 Listener详解

```cpp
// listener.hpp - Listener组件实现
#pragma once

#include <string>
#include <vector>
#include <memory>
#include <functional>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>
#include <fcntl.h>

namespace mini_envoy {

// 前向声明
class FilterChain;
class Connection;

/*
 * Listener在Envoy中的职责：
 *
 * 1. 绑定端口，监听连接
 * 2. 根据连接属性选择Filter Chain
 * 3. 创建Connection对象
 * 4. 将Connection交给Filter Chain处理
 *
 * 关键概念：
 * - Listener Filter：在选择Filter Chain之前执行
 * - Filter Chain Match：决定使用哪个Filter Chain
 */

// Listener Filter接口（在Filter Chain之前执行）
class ListenerFilter {
public:
    virtual ~ListenerFilter() = default;

    enum class Status {
        Continue,      // 继续下一个Listener Filter
        StopIteration, // 暂停，等待更多数据
    };

    // 新连接到达时调用
    virtual Status onAccept(int fd) = 0;
};

// Filter Chain匹配条件
struct FilterChainMatch {
    std::vector<std::string> server_names;  // SNI匹配
    std::vector<std::string> source_ips;    // 源IP匹配
    uint16_t destination_port = 0;          // 目标端口匹配

    bool matches(const std::string& sni, const std::string& source_ip,
                 uint16_t port) const {
        // SNI匹配
        if (!server_names.empty()) {
            bool sni_match = false;
            for (const auto& name : server_names) {
                if (sni == name || (name[0] == '*' &&
                    sni.ends_with(name.substr(1)))) {
                    sni_match = true;
                    break;
                }
            }
            if (!sni_match) return false;
        }

        // 源IP匹配（简化）
        if (!source_ips.empty()) {
            bool ip_match = std::find(source_ips.begin(), source_ips.end(),
                                      source_ip) != source_ips.end();
            if (!ip_match) return false;
        }

        // 端口匹配
        if (destination_port != 0 && destination_port != port) {
            return false;
        }

        return true;
    }
};

// Filter Chain配置
class FilterChainWrapper {
public:
    FilterChainMatch match;
    std::shared_ptr<FilterChain> filter_chain;
};

// Listener接口
class Listener {
public:
    virtual ~Listener() = default;

    // 启动监听
    virtual bool start() = 0;

    // 停止监听
    virtual void stop() = 0;

    // 获取监听地址
    virtual const std::string& name() const = 0;
    virtual uint16_t port() const = 0;
};

// TCP Listener实现
class TcpListener : public Listener {
public:
    TcpListener(const std::string& name, const std::string& address,
                uint16_t port)
        : name_(name), address_(address), port_(port), fd_(-1) {}

    ~TcpListener() override {
        stop();
    }

    bool start() override {
        fd_ = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK, 0);
        if (fd_ < 0) {
            return false;
        }

        int opt = 1;
        setsockopt(fd_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
        setsockopt(fd_, SOL_SOCKET, SO_REUSEPORT, &opt, sizeof(opt));

        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = INADDR_ANY;
        addr.sin_port = htons(port_);

        if (bind(fd_, (sockaddr*)&addr, sizeof(addr)) < 0) {
            close(fd_);
            fd_ = -1;
            return false;
        }

        if (listen(fd_, SOMAXCONN) < 0) {
            close(fd_);
            fd_ = -1;
            return false;
        }

        running_ = true;
        return true;
    }

    void stop() override {
        running_ = false;
        if (fd_ >= 0) {
            close(fd_);
            fd_ = -1;
        }
    }

    const std::string& name() const override { return name_; }
    uint16_t port() const override { return port_; }
    int fd() const { return fd_; }

    // 添加Filter Chain
    void addFilterChain(FilterChainMatch match,
                        std::shared_ptr<FilterChain> chain) {
        FilterChainWrapper wrapper;
        wrapper.match = std::move(match);
        wrapper.filter_chain = std::move(chain);
        filter_chains_.push_back(std::move(wrapper));
    }

    // 选择Filter Chain
    std::shared_ptr<FilterChain> selectFilterChain(
        const std::string& sni,
        const std::string& source_ip,
        uint16_t port
    ) {
        for (const auto& wrapper : filter_chains_) {
            if (wrapper.match.matches(sni, source_ip, port)) {
                return wrapper.filter_chain;
            }
        }
        // 返回默认Filter Chain（第一个无条件匹配的）
        if (!filter_chains_.empty()) {
            return filter_chains_[0].filter_chain;
        }
        return nullptr;
    }

    // 接受连接
    int accept(sockaddr_in* client_addr) {
        socklen_t len = sizeof(*client_addr);
        return accept4(fd_, (sockaddr*)client_addr, &len, SOCK_NONBLOCK);
    }

private:
    std::string name_;
    std::string address_;
    uint16_t port_;
    int fd_;
    bool running_ = false;

    std::vector<FilterChainWrapper> filter_chains_;
};

/*
 * Listener处理流程：
 *
 * ┌─────────────────────────────────────────────────────────────────┐
 * │                                                                  │
 * │  1. 连接到达                                                    │
 * │     │                                                           │
 * │     ▼                                                           │
 * │  2. 执行Listener Filters                                       │
 * │     │ - TLS Inspector（检测TLS并提取SNI）                      │
 * │     │ - HTTP Inspector（检测HTTP协议）                         │
 * │     │ - Original Destination（获取原始目标地址）               │
 * │     │                                                           │
 * │     ▼                                                           │
 * │  3. 选择Filter Chain                                           │
 * │     │ - 根据SNI、源IP、目标端口等条件匹配                      │
 * │     │ - 选择第一个匹配的Filter Chain                           │
 * │     │                                                           │
 * │     ▼                                                           │
 * │  4. 创建Connection                                             │
 * │     │ - 关联选中的Filter Chain                                 │
 * │     │ - 初始化Filter状态                                       │
 * │     │                                                           │
 * │     ▼                                                           │
 * │  5. 开始处理数据                                               │
 * │                                                                  │
 * └─────────────────────────────────────────────────────────────────┘
 */

} // namespace mini_envoy
```

#### 3.3 Cluster详解

```cpp
// cluster.hpp - Cluster组件实现
#pragma once

#include <string>
#include <vector>
#include <memory>
#include <atomic>
#include <mutex>
#include <random>
#include <chrono>

namespace mini_envoy {

/*
 * Cluster在Envoy中的职责：
 *
 * 1. 管理一组上游服务端点
 * 2. 提供负载均衡策略
 * 3. 维护连接池
 * 4. 执行健康检查
 * 5. 实现熔断机制
 */

// 端点健康状态
enum class HealthStatus {
    Healthy,
    Degraded,
    Unhealthy,
    Unknown
};

// 上游端点
class Endpoint {
public:
    Endpoint(const std::string& address, uint16_t port, uint32_t weight = 1)
        : address_(address), port_(port), weight_(weight) {}

    const std::string& address() const { return address_; }
    uint16_t port() const { return port_; }
    uint32_t weight() const { return weight_; }

    HealthStatus health() const { return health_.load(); }
    void setHealth(HealthStatus status) { health_ = status; }

    // 统计信息
    void recordSuccess() {
        success_count_++;
        last_success_time_ = std::chrono::steady_clock::now();
    }
    void recordFailure() { failure_count_++; }

    uint64_t successCount() const { return success_count_; }
    uint64_t failureCount() const { return failure_count_; }

private:
    std::string address_;
    uint16_t port_;
    uint32_t weight_;
    std::atomic<HealthStatus> health_{HealthStatus::Healthy};
    std::atomic<uint64_t> success_count_{0};
    std::atomic<uint64_t> failure_count_{0};
    std::chrono::steady_clock::time_point last_success_time_;
};

// 负载均衡策略
enum class LoadBalancerType {
    RoundRobin,       // 轮询
    LeastRequest,     // 最少请求
    Random,           // 随机
    RingHash,         // 一致性哈希
    Maglev            // Maglev哈希
};

// 负载均衡器接口
class LoadBalancer {
public:
    virtual ~LoadBalancer() = default;
    virtual Endpoint* selectEndpoint(const std::vector<Endpoint*>& healthy_endpoints) = 0;
};

// 轮询负载均衡
class RoundRobinLoadBalancer : public LoadBalancer {
public:
    Endpoint* selectEndpoint(const std::vector<Endpoint*>& endpoints) override {
        if (endpoints.empty()) return nullptr;

        size_t idx = current_index_.fetch_add(1) % endpoints.size();
        return endpoints[idx];
    }

private:
    std::atomic<size_t> current_index_{0};
};

// 最少请求负载均衡
class LeastRequestLoadBalancer : public LoadBalancer {
public:
    Endpoint* selectEndpoint(const std::vector<Endpoint*>& endpoints) override {
        if (endpoints.empty()) return nullptr;

        // 简化实现：随机选择2个，取请求数少的
        // 实际Envoy使用更复杂的P2C算法
        if (endpoints.size() == 1) return endpoints[0];

        std::random_device rd;
        std::mt19937 gen(rd());
        std::uniform_int_distribution<> dist(0, endpoints.size() - 1);

        size_t idx1 = dist(gen);
        size_t idx2 = dist(gen);
        while (idx2 == idx1 && endpoints.size() > 1) {
            idx2 = dist(gen);
        }

        // 选择活跃请求数少的（简化：用成功数代替）
        return endpoints[idx1]->successCount() <= endpoints[idx2]->successCount()
            ? endpoints[idx1] : endpoints[idx2];
    }
};

// 随机负载均衡
class RandomLoadBalancer : public LoadBalancer {
public:
    Endpoint* selectEndpoint(const std::vector<Endpoint*>& endpoints) override {
        if (endpoints.empty()) return nullptr;

        std::random_device rd;
        std::mt19937 gen(rd());
        std::uniform_int_distribution<> dist(0, endpoints.size() - 1);

        return endpoints[dist(gen)];
    }
};

// 熔断器配置
struct CircuitBreakerConfig {
    uint32_t max_connections = 1024;        // 最大连接数
    uint32_t max_pending_requests = 1024;   // 最大等待请求
    uint32_t max_requests = 1024;           // 最大并发请求
    uint32_t max_retries = 3;               // 最大重试次数
};

// 熔断器状态
enum class CircuitBreakerState {
    Closed,     // 正常
    HalfOpen,   // 半开（尝试恢复）
    Open        // 断开（拒绝请求）
};

// 熔断器
class CircuitBreaker {
public:
    CircuitBreaker(const CircuitBreakerConfig& config)
        : config_(config) {}

    // 检查是否允许请求
    bool allowRequest() {
        std::lock_guard<std::mutex> lock(mutex_);

        switch (state_) {
            case CircuitBreakerState::Closed:
                if (current_requests_ >= config_.max_requests) {
                    return false;
                }
                current_requests_++;
                return true;

            case CircuitBreakerState::Open:
                // 检查是否应该尝试恢复
                if (shouldAttemptReset()) {
                    state_ = CircuitBreakerState::HalfOpen;
                    current_requests_ = 1;
                    return true;
                }
                return false;

            case CircuitBreakerState::HalfOpen:
                // 只允许一个请求通过
                if (current_requests_ == 0) {
                    current_requests_++;
                    return true;
                }
                return false;
        }
        return false;
    }

    // 记录成功
    void recordSuccess() {
        std::lock_guard<std::mutex> lock(mutex_);
        current_requests_--;
        consecutive_failures_ = 0;

        if (state_ == CircuitBreakerState::HalfOpen) {
            state_ = CircuitBreakerState::Closed;
        }
    }

    // 记录失败
    void recordFailure() {
        std::lock_guard<std::mutex> lock(mutex_);
        current_requests_--;
        consecutive_failures_++;

        if (consecutive_failures_ >= 5) {  // 连续5次失败则断开
            state_ = CircuitBreakerState::Open;
            trip_time_ = std::chrono::steady_clock::now();
        }
    }

    CircuitBreakerState state() const { return state_; }

private:
    bool shouldAttemptReset() {
        auto now = std::chrono::steady_clock::now();
        auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(
            now - trip_time_).count();
        return elapsed >= 30;  // 30秒后尝试恢复
    }

private:
    CircuitBreakerConfig config_;
    CircuitBreakerState state_ = CircuitBreakerState::Closed;
    std::mutex mutex_;
    uint32_t current_requests_ = 0;
    uint32_t consecutive_failures_ = 0;
    std::chrono::steady_clock::time_point trip_time_;
};

// Cluster
class Cluster {
public:
    Cluster(const std::string& name, LoadBalancerType lb_type)
        : name_(name) {
        // 创建负载均衡器
        switch (lb_type) {
            case LoadBalancerType::RoundRobin:
                lb_ = std::make_unique<RoundRobinLoadBalancer>();
                break;
            case LoadBalancerType::LeastRequest:
                lb_ = std::make_unique<LeastRequestLoadBalancer>();
                break;
            case LoadBalancerType::Random:
            default:
                lb_ = std::make_unique<RandomLoadBalancer>();
                break;
        }
    }

    const std::string& name() const { return name_; }

    // 添加端点
    void addEndpoint(std::unique_ptr<Endpoint> endpoint) {
        std::lock_guard<std::mutex> lock(mutex_);
        endpoints_.push_back(std::move(endpoint));
    }

    // 选择端点
    Endpoint* selectEndpoint() {
        std::lock_guard<std::mutex> lock(mutex_);

        // 过滤健康端点
        std::vector<Endpoint*> healthy;
        for (const auto& ep : endpoints_) {
            if (ep->health() == HealthStatus::Healthy) {
                healthy.push_back(ep.get());
            }
        }

        return lb_->selectEndpoint(healthy);
    }

    // 获取统计信息
    size_t endpointCount() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return endpoints_.size();
    }

    size_t healthyEndpointCount() const {
        std::lock_guard<std::mutex> lock(mutex_);
        size_t count = 0;
        for (const auto& ep : endpoints_) {
            if (ep->health() == HealthStatus::Healthy) {
                count++;
            }
        }
        return count;
    }

private:
    std::string name_;
    std::unique_ptr<LoadBalancer> lb_;
    mutable std::mutex mutex_;
    std::vector<std::unique_ptr<Endpoint>> endpoints_;
};

/*
 * Cluster负载均衡策略对比：
 *
 * ┌────────────────┬─────────────────────────────────────────────────────┐
 * │ 策略            │ 特点                                                 │
 * ├────────────────┼─────────────────────────────────────────────────────┤
 * │ Round Robin    │ 简单高效，适合后端性能相近的场景                     │
 * │ Least Request  │ 考虑后端负载，适合请求处理时间差异大的场景           │
 * │ Random         │ 简单，随机性好                                       │
 * │ Ring Hash      │ 一致性哈希，适合缓存场景                             │
 * │ Maglev         │ 更好的一致性分布，Google设计                         │
 * └────────────────┴─────────────────────────────────────────────────────┘
 */

} // namespace mini_envoy
```

### Day 5-7：请求处理流程（15小时）

#### 5.1 请求完整生命周期

```
HTTP请求在Envoy中的完整处理流程：
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                          │
│  1. 连接建立阶段                                                        │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                                                                    │ │
│  │  Client ──────▶ Envoy (Listener)                                  │ │
│  │                     │                                              │ │
│  │                     ▼                                              │ │
│  │             ┌───────────────┐                                     │ │
│  │             │ Listener      │                                     │ │
│  │             │ Filters       │ ← TLS Inspector检测SNI              │ │
│  │             └───────┬───────┘                                     │ │
│  │                     │                                              │ │
│  │                     ▼                                              │ │
│  │             ┌───────────────┐                                     │ │
│  │             │ Filter Chain  │ ← 根据SNI选择                       │ │
│  │             │ Selection     │                                     │ │
│  │             └───────┬───────┘                                     │ │
│  │                     │                                              │ │
│  │                     ▼                                              │ │
│  │             ┌───────────────┐                                     │ │
│  │             │ TLS Handshake │ ← 如果是HTTPS                       │ │
│  │             └───────┬───────┘                                     │ │
│  │                     │                                              │ │
│  │                     ▼                                              │ │
│  │             ┌───────────────┐                                     │ │
│  │             │ Connection    │ ← 创建连接对象                      │ │
│  │             │ Created       │                                     │ │
│  │             └───────────────┘                                     │ │
│  │                                                                    │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  2. 请求处理阶段                                                        │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                                                                    │ │
│  │  HTTP Request                                                     │ │
│  │       │                                                           │ │
│  │       ▼                                                           │ │
│  │  ┌────────────────────────────────────────────────────────────┐  │ │
│  │  │                 Network Filter Chain                        │  │ │
│  │  │  ┌────────┐   ┌────────┐   ┌────────────────────────────┐  │  │ │
│  │  │  │ TCP    │──▶│ TLS    │──▶│ HTTP Connection Manager   │  │  │ │
│  │  │  │ Proxy  │   │ Filter │   │ (HCM)                      │  │  │ │
│  │  │  └────────┘   └────────┘   └────────────────────────────┘  │  │ │
│  │  └────────────────────────────────────────────────────────────┘  │ │
│  │                              │                                    │ │
│  │                              ▼                                    │ │
│  │  ┌────────────────────────────────────────────────────────────┐  │ │
│  │  │                   HTTP Filter Chain                         │  │ │
│  │  │                                                             │  │ │
│  │  │     Request Flow (Decoder Filters)                         │  │ │
│  │  │     ┌────────┐   ┌────────┐   ┌────────┐   ┌────────┐     │  │ │
│  │  │     │ CORS   │──▶│ Auth   │──▶│ Rate   │──▶│ Router │     │  │ │
│  │  │     │        │   │        │   │ Limit  │   │        │     │  │ │
│  │  │     └────────┘   └────────┘   └────────┘   └────────┘     │  │ │
│  │  │                                                │            │  │ │
│  │  │                                                ▼            │  │ │
│  │  │                                        Route Matching       │  │ │
│  │  │                                        Select Cluster       │  │ │
│  │  │                                                             │  │ │
│  │  └────────────────────────────────────────────────────────────┘  │ │
│  │                                                                    │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  3. 上游连接阶段                                                        │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                                                                    │ │
│  │  ┌───────────────────────────────────────────────────────────┐   │ │
│  │  │                   Cluster Manager                          │   │ │
│  │  │                         │                                  │   │ │
│  │  │                         ▼                                  │   │ │
│  │  │  ┌─────────────────────────────────────────────────────┐  │   │ │
│  │  │  │               Load Balancer                          │  │   │ │
│  │  │  │  Select Endpoint based on:                          │  │   │ │
│  │  │  │  - LB Policy (RoundRobin, LeastRequest, etc)        │  │   │ │
│  │  │  │  - Health Status                                     │  │   │ │
│  │  │  │  - Locality                                          │  │   │ │
│  │  │  └─────────────────────────────────────────────────────┘  │   │ │
│  │  │                         │                                  │   │ │
│  │  │                         ▼                                  │   │ │
│  │  │  ┌─────────────────────────────────────────────────────┐  │   │ │
│  │  │  │               Connection Pool                        │  │   │ │
│  │  │  │  - Reuse existing connection                        │  │   │ │
│  │  │  │  - Or create new connection                         │  │   │ │
│  │  │  └─────────────────────────────────────────────────────┘  │   │ │
│  │  │                         │                                  │   │ │
│  │  └─────────────────────────┼──────────────────────────────────┘   │ │
│  │                            │                                      │ │
│  │                            ▼                                      │ │
│  │                    Upstream Server                                │ │
│  │                                                                    │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  4. 响应处理阶段                                                        │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                                                                    │ │
│  │  Upstream Response                                                │ │
│  │       │                                                           │ │
│  │       ▼                                                           │ │
│  │  ┌────────────────────────────────────────────────────────────┐  │ │
│  │  │                   HTTP Filter Chain                         │  │ │
│  │  │                                                             │  │ │
│  │  │     Response Flow (Encoder Filters)                        │  │ │
│  │  │     ┌────────┐   ┌────────┐   ┌────────┐   ┌────────┐     │  │ │
│  │  │     │ Router │──▶│ Rate   │──▶│ Auth   │──▶│ CORS   │     │  │ │
│  │  │     │        │   │ Limit  │   │        │   │        │     │  │ │
│  │  │     └────────┘   └────────┘   └────────┘   └────────┘     │  │ │
│  │  │                                                             │  │ │
│  │  └────────────────────────────────────────────────────────────┘  │ │
│  │                              │                                    │ │
│  │                              ▼                                    │ │
│  │                          Client                                   │ │
│  │                                                                    │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

#### 5.2 路由匹配实现

```cpp
// router.hpp - 路由匹配实现
#pragma once

#include <string>
#include <vector>
#include <regex>
#include <memory>
#include <optional>

namespace mini_envoy {

/*
 * Envoy路由匹配规则：
 *
 * 1. 虚拟主机匹配（基于Host header）
 * 2. 路由匹配（基于路径、header等）
 * 3. 选择目标Cluster
 */

// 路由匹配类型
enum class MatchType {
    Prefix,     // 前缀匹配 /api/
    Exact,      // 精确匹配 /api/v1/users
    Regex,      // 正则匹配 /api/v[0-9]+/.*
    SafeRegex   // 安全正则（带超时保护）
};

// Header匹配
struct HeaderMatch {
    std::string name;
    std::string value;
    bool exact_match = true;     // true=精确匹配, false=正则
    bool present_match = false;  // 只检查header存在
    bool invert = false;         // 取反

    bool matches(const std::map<std::string, std::string>& headers) const {
        auto it = headers.find(name);

        if (present_match) {
            bool present = (it != headers.end());
            return invert ? !present : present;
        }

        if (it == headers.end()) {
            return invert;
        }

        bool match;
        if (exact_match) {
            match = (it->second == value);
        } else {
            std::regex re(value);
            match = std::regex_match(it->second, re);
        }

        return invert ? !match : match;
    }
};

// 查询参数匹配
struct QueryParamMatch {
    std::string name;
    std::string value;
    bool present_match = false;

    bool matches(const std::map<std::string, std::string>& params) const {
        auto it = params.find(name);

        if (present_match) {
            return it != params.end();
        }

        return it != params.end() && it->second == value;
    }
};

// 路由匹配条件
struct RouteMatch {
    MatchType type = MatchType::Prefix;
    std::string value;  // 路径
    bool case_sensitive = true;
    std::vector<HeaderMatch> headers;
    std::vector<QueryParamMatch> query_params;

    bool matches(const std::string& path,
                 const std::map<std::string, std::string>& headers_map,
                 const std::map<std::string, std::string>& params_map) const {
        // 路径匹配
        std::string check_path = path;
        std::string match_value = value;

        if (!case_sensitive) {
            std::transform(check_path.begin(), check_path.end(),
                          check_path.begin(), ::tolower);
            std::transform(match_value.begin(), match_value.end(),
                          match_value.begin(), ::tolower);
        }

        bool path_match = false;
        switch (type) {
            case MatchType::Prefix:
                path_match = check_path.starts_with(match_value);
                break;
            case MatchType::Exact:
                path_match = (check_path == match_value);
                break;
            case MatchType::Regex:
            case MatchType::SafeRegex:
                try {
                    std::regex re(match_value);
                    path_match = std::regex_match(check_path, re);
                } catch (...) {
                    path_match = false;
                }
                break;
        }

        if (!path_match) return false;

        // Header匹配
        for (const auto& h : headers) {
            if (!h.matches(headers_map)) return false;
        }

        // 查询参数匹配
        for (const auto& p : query_params) {
            if (!p.matches(params_map)) return false;
        }

        return true;
    }
};

// 重试策略
struct RetryPolicy {
    uint32_t num_retries = 1;
    std::chrono::milliseconds per_try_timeout{0};
    std::vector<std::string> retry_on;  // "5xx", "reset", "connect-failure"
};

// 路由动作
struct RouteAction {
    std::string cluster;
    std::optional<std::string> cluster_header;  // 从header获取cluster名
    std::chrono::milliseconds timeout{15000};
    RetryPolicy retry_policy;

    // 流量分割（金丝雀发布）
    struct WeightedCluster {
        std::string name;
        uint32_t weight;
    };
    std::vector<WeightedCluster> weighted_clusters;

    // 获取目标cluster
    std::string getCluster(const std::map<std::string, std::string>& headers) const {
        // 优先从header获取
        if (cluster_header) {
            auto it = headers.find(*cluster_header);
            if (it != headers.end()) {
                return it->second;
            }
        }

        // 权重分配
        if (!weighted_clusters.empty()) {
            uint32_t total_weight = 0;
            for (const auto& wc : weighted_clusters) {
                total_weight += wc.weight;
            }

            uint32_t r = rand() % total_weight;
            uint32_t sum = 0;
            for (const auto& wc : weighted_clusters) {
                sum += wc.weight;
                if (r < sum) {
                    return wc.name;
                }
            }
        }

        return cluster;
    }
};

// 路由条目
struct Route {
    std::string name;
    RouteMatch match;
    RouteAction action;
};

// 虚拟主机
struct VirtualHost {
    std::string name;
    std::vector<std::string> domains;  // 支持通配符 *.example.com
    std::vector<Route> routes;

    // 检查域名是否匹配
    bool matchesDomain(const std::string& host) const {
        for (const auto& domain : domains) {
            if (domain == "*") {
                return true;
            }

            if (domain.starts_with("*.")) {
                // 通配符匹配
                std::string suffix = domain.substr(1);
                if (host.ends_with(suffix)) {
                    return true;
                }
            } else {
                if (host == domain) {
                    return true;
                }
            }
        }
        return false;
    }

    // 查找匹配的路由
    const Route* findRoute(const std::string& path,
                          const std::map<std::string, std::string>& headers,
                          const std::map<std::string, std::string>& params) const {
        for (const auto& route : routes) {
            if (route.match.matches(path, headers, params)) {
                return &route;
            }
        }
        return nullptr;
    }
};

// 路由表
class RouteTable {
public:
    void addVirtualHost(VirtualHost vh) {
        virtual_hosts_.push_back(std::move(vh));
    }

    // 查找路由
    struct RouteResult {
        const VirtualHost* virtual_host = nullptr;
        const Route* route = nullptr;
        std::string cluster;
    };

    std::optional<RouteResult> findRoute(
        const std::string& host,
        const std::string& path,
        const std::map<std::string, std::string>& headers,
        const std::map<std::string, std::string>& query_params
    ) const {
        // 先找匹配的虚拟主机
        const VirtualHost* vh = nullptr;
        for (const auto& vhost : virtual_hosts_) {
            if (vhost.matchesDomain(host)) {
                vh = &vhost;
                break;
            }
        }

        if (!vh) {
            // 尝试默认虚拟主机（domain = "*"）
            for (const auto& vhost : virtual_hosts_) {
                for (const auto& d : vhost.domains) {
                    if (d == "*") {
                        vh = &vhost;
                        break;
                    }
                }
                if (vh) break;
            }
        }

        if (!vh) return std::nullopt;

        // 在虚拟主机中查找路由
        const Route* route = vh->findRoute(path, headers, query_params);
        if (!route) return std::nullopt;

        RouteResult result;
        result.virtual_host = vh;
        result.route = route;
        result.cluster = route->action.getCluster(headers);

        return result;
    }

private:
    std::vector<VirtualHost> virtual_hosts_;
};

/*
 * 路由匹配优先级：
 *
 * 1. 精确路径匹配 > 前缀匹配 > 正则匹配
 * 2. 更长的前缀优先
 * 3. 更具体的域名优先（example.com > *.example.com > *）
 * 4. 路由配置顺序（先配置的优先）
 */

} // namespace mini_envoy
```

#### 5.3 负载均衡与重试

```cpp
// load_balancing.hpp - 负载均衡和重试机制
#pragma once

#include "cluster.hpp"
#include <chrono>
#include <random>

namespace mini_envoy {

/*
 * Envoy的高级负载均衡特性：
 *
 * 1. 区域感知路由（Zone Aware Routing）
 * 2. 优先级路由（Priority Routing）
 * 3. 子集路由（Subset Routing）
 */

// 区域信息
struct Locality {
    std::string region;
    std::string zone;
    std::string sub_zone;

    bool operator==(const Locality& other) const {
        return region == other.region &&
               zone == other.zone &&
               sub_zone == other.sub_zone;
    }
};

// 带区域的端点
class LocalityEndpoint : public Endpoint {
public:
    LocalityEndpoint(const std::string& address, uint16_t port,
                     uint32_t weight, Locality locality)
        : Endpoint(address, port, weight), locality_(std::move(locality)) {}

    const Locality& locality() const { return locality_; }

private:
    Locality locality_;
};

// 区域感知负载均衡器
class ZoneAwareLoadBalancer : public LoadBalancer {
public:
    ZoneAwareLoadBalancer(const Locality& local_locality)
        : local_locality_(local_locality) {}

    Endpoint* selectEndpoint(const std::vector<Endpoint*>& endpoints) override {
        if (endpoints.empty()) return nullptr;

        // 分组：本地区域 vs 其他区域
        std::vector<Endpoint*> local_endpoints;
        std::vector<Endpoint*> remote_endpoints;

        for (auto* ep : endpoints) {
            auto* locality_ep = dynamic_cast<LocalityEndpoint*>(ep);
            if (locality_ep && locality_ep->locality() == local_locality_) {
                local_endpoints.push_back(ep);
            } else {
                remote_endpoints.push_back(ep);
            }
        }

        // 优先选择本地区域
        if (!local_endpoints.empty()) {
            // 检查本地区域是否健康
            double local_health_ratio =
                static_cast<double>(local_endpoints.size()) / endpoints.size();

            if (local_health_ratio >= min_local_ratio_) {
                return selectFromPool(local_endpoints);
            }
        }

        // 本地不够健康，从所有端点中选择
        return selectFromPool(endpoints);
    }

private:
    Endpoint* selectFromPool(const std::vector<Endpoint*>& pool) {
        // 简单轮询
        size_t idx = index_.fetch_add(1) % pool.size();
        return pool[idx];
    }

private:
    Locality local_locality_;
    double min_local_ratio_ = 0.7;  // 本地至少70%健康才优先
    std::atomic<size_t> index_{0};
};

// 重试策略执行器
class RetryExecutor {
public:
    RetryExecutor(const RetryPolicy& policy) : policy_(policy) {}

    // 判断是否应该重试
    bool shouldRetry(int status_code, const std::string& error_type) {
        if (attempts_ >= policy_.num_retries + 1) {
            return false;
        }

        for (const auto& condition : policy_.retry_on) {
            if (condition == "5xx" && status_code >= 500 && status_code < 600) {
                attempts_++;
                return true;
            }
            if (condition == "reset" && error_type == "connection_reset") {
                attempts_++;
                return true;
            }
            if (condition == "connect-failure" && error_type == "connect_failed") {
                attempts_++;
                return true;
            }
            if (condition == "retriable-4xx" &&
                (status_code == 409 || status_code == 425)) {
                attempts_++;
                return true;
            }
        }

        return false;
    }

    // 获取重试延迟（指数退避）
    std::chrono::milliseconds getRetryDelay() {
        // 基础延迟 25ms，每次翻倍，加随机抖动
        uint32_t base = 25 * (1 << (attempts_ - 1));
        uint32_t jitter = rand() % (base / 2);
        return std::chrono::milliseconds(base + jitter);
    }

    uint32_t attempts() const { return attempts_; }

private:
    RetryPolicy policy_;
    uint32_t attempts_ = 0;
};

// 超时管理器
class TimeoutManager {
public:
    struct TimeoutConfig {
        std::chrono::milliseconds connect_timeout{250};   // 连接超时
        std::chrono::milliseconds request_timeout{15000}; // 请求超时
        std::chrono::milliseconds idle_timeout{3600000};  // 空闲超时
    };

    TimeoutManager(const TimeoutConfig& config) : config_(config) {}

    // 创建连接超时定时器
    template<typename Callback>
    void setConnectTimeout(Callback&& cb) {
        // 实际实现需要集成事件循环
    }

    // 创建请求超时定时器
    template<typename Callback>
    void setRequestTimeout(Callback&& cb) {
        // 实际实现需要集成事件循环
    }

private:
    TimeoutConfig config_;
};

/*
 * Envoy重试流程：
 *
 * ┌─────────────────────────────────────────────────────────────────┐
 * │                                                                  │
 * │   Request                                                        │
 * │      │                                                           │
 * │      ▼                                                           │
 * │   ┌──────────┐                                                  │
 * │   │ Attempt 1│──────────▶ Success ──────────▶ Done              │
 * │   └────┬─────┘                                                  │
 * │        │ Failure                                                │
 * │        ▼                                                        │
 * │   ┌──────────┐                                                  │
 * │   │ Should   │──── No ──────────────────────▶ Return Error      │
 * │   │ Retry?   │                                                  │
 * │   └────┬─────┘                                                  │
 * │        │ Yes                                                    │
 * │        ▼                                                        │
 * │   ┌──────────┐                                                  │
 * │   │ Wait     │ ← 指数退避 + 抖动                                │
 * │   │ Backoff  │                                                  │
 * │   └────┬─────┘                                                  │
 * │        │                                                        │
 * │        ▼                                                        │
 * │   ┌──────────┐                                                  │
 * │   │ Select   │ ← 可能选择不同的端点                             │
 * │   │ Endpoint │                                                  │
 * │   └────┬─────┘                                                  │
 * │        │                                                        │
 * │        ▼                                                        │
 * │   ┌──────────┐                                                  │
 * │   │ Attempt N│──────────▶ ...                                   │
 * │   └──────────┘                                                  │
 * │                                                                  │
 * └─────────────────────────────────────────────────────────────────┘
 */

} // namespace mini_envoy
```

---

### 第一周自测题

#### 概念理解题

1. **Service Mesh与传统微服务架构的主要区别是什么？**

   <details>
   <summary>参考答案</summary>

   主要区别：
   - **关注点分离**：Service Mesh将网络通信逻辑从业务代码中分离，由Sidecar代理处理
   - **统一治理**：流量管理、安全、可观测性由基础设施统一提供
   - **语言无关**：任何语言的服务都可以享受相同的网络能力
   - **无侵入升级**：更新代理不需要修改业务代码
   </details>

2. **Envoy的Listener、Filter Chain、Cluster三者的关系是什么？**

   <details>
   <summary>参考答案</summary>

   - **Listener**：监听端口，接收下游连接
   - **Filter Chain**：由Listener选择，处理连接数据
   - **Cluster**：由Filter（Router）选择，代表上游服务

   数据流：Listener接收连接 → 选择Filter Chain → Filter处理 → Router选择Cluster → 连接上游
   </details>

3. **为什么Envoy要使用xDS动态配置而不是静态配置文件？**

   <details>
   <summary>参考答案</summary>

   - **无损更新**：配置更新不中断现有连接
   - **实时生效**：不需要重启或reload
   - **规模化管理**：控制面可以管理大量Envoy实例
   - **自动化**：与Kubernetes等平台集成实现自动服务发现
   </details>

---

### 第一周检验标准

| 检验项 | 标准 | 自评 |
|--------|------|------|
| 理解Service Mesh | 能解释Envoy在Service Mesh中的角色 | ☐ |
| 理解核心组件 | 能画出Listener/Cluster/Route架构图 | ☐ |
| 理解请求流程 | 能追踪HTTP请求的完整路径 | ☐ |
| 理解路由匹配 | 能解释路由匹配的优先级规则 | ☐ |
| 理解负载均衡 | 能比较不同负载均衡策略 | ☐ |
| 实现配置解析 | 代码能正确解析配置 | ☐ |
| 实现路由匹配 | 代码能正确匹配路由 | ☐ |

---

### 第一周时间分配

| 内容 | 时间 |
|------|------|
| Service Mesh概念学习 | 6小时 |
| Envoy设计哲学理解 | 4小时 |
| 核心组件分析 | 10小时 |
| 请求流程追踪 | 8小时 |
| 代码实现 | 7小时 |

---

## 第二周：线程模型与事件循环（Day 8-14）

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    第二周学习路线图                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Day 8-9              Day 10-11            Day 12-14                      │
│   ┌─────────┐         ┌─────────┐          ┌─────────┐                     │
│   │ 线程    │         │  TLS    │          │ 事件    │                     │
│   │ 模型    │────────▶│  机制   │─────────▶│ 循环    │                     │
│   │ 设计    │         │  详解   │          │ 实现    │                     │
│   └─────────┘         └─────────┘          └─────────┘                     │
│       │                   │                    │                           │
│       ▼                   ▼                    ▼                           │
│   Main/Worker         Slot机制            Dispatcher                       │
│   线程分工            配置传播            定时器/IO                         │
│                                                                             │
│   学习目标：深入理解Envoy的线程架构与事件驱动机制                            │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Day 8-9：线程模型设计（10小时）

#### Envoy线程架构概览

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Envoy 线程架构                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        Main Thread                                   │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                 │   │
│  │  │   Admin     │  │    xDS      │  │   Stats     │                 │   │
│  │  │   Server    │  │   Client    │  │  Flusher    │                 │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘                 │   │
│  │                          │                                          │   │
│  │                   配置更新通知                                       │   │
│  │                          │                                          │   │
│  └──────────────────────────┼──────────────────────────────────────────┘   │
│                             │                                               │
│          ┌──────────────────┼──────────────────┐                           │
│          │                  │                  │                           │
│          ▼                  ▼                  ▼                           │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐                   │
│  │ Worker 0     │   │ Worker 1     │   │ Worker N     │                   │
│  │ ┌──────────┐ │   │ ┌──────────┐ │   │ ┌──────────┐ │                   │
│  │ │Dispatcher│ │   │ │Dispatcher│ │   │ │Dispatcher│ │                   │
│  │ └──────────┘ │   │ └──────────┘ │   │ └──────────┘ │                   │
│  │ ┌──────────┐ │   │ ┌──────────┐ │   │ ┌──────────┐ │                   │
│  │ │  TLS     │ │   │ │  TLS     │ │   │ │  TLS     │ │                   │
│  │ │  Data    │ │   │ │  Data    │ │   │ │  Data    │ │                   │
│  │ └──────────┘ │   │ └──────────┘ │   │ └──────────┘ │                   │
│  │ ┌──────────┐ │   │ ┌──────────┐ │   │ ┌──────────┐ │                   │
│  │ │Listeners │ │   │ │Listeners │ │   │ │Listeners │ │                   │
│  │ │Connections│   │ │Connections│   │ │Connections│ │                   │
│  │ └──────────┘ │   │ └──────────┘ │   │ └──────────┘ │                   │
│  └──────────────┘   └──────────────┘   └──────────────┘                   │
│                                                                             │
│  特点：                                                                     │
│  • 每个Worker完全独立，无锁设计                                             │
│  • 连接绑定到单个Worker，避免竞争                                           │
│  • 通过TLS传播配置，保证一致性                                              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 为什么不用多线程共享？

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    多线程共享 vs Thread-per-Core                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  传统多线程共享模型：                                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                      共享数据结构                                      │  │
│  │  ┌─────────────────────────────────────────────────────────────┐    │  │
│  │  │              Route Table / Cluster Info                      │    │  │
│  │  │                    (需要加锁保护)                             │    │  │
│  │  └─────────────────────────────────────────────────────────────┘    │  │
│  │         ▲              ▲              ▲              ▲              │  │
│  │         │ lock         │ lock         │ lock         │ lock        │  │
│  │    ┌────┴────┐    ┌────┴────┐    ┌────┴────┐    ┌────┴────┐       │  │
│  │    │Thread 1 │    │Thread 2 │    │Thread 3 │    │Thread 4 │       │  │
│  │    └─────────┘    └─────────┘    └─────────┘    └─────────┘       │  │
│  │                                                                    │  │
│  │  问题：                                                            │  │
│  │  • 锁竞争严重，特别是高并发场景                                     │  │
│  │  • Cache Line Bouncing，多核性能下降                               │  │
│  │  • 死锁风险，代码复杂度高                                          │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  Envoy Thread-per-Core模型：                                                │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐              │  │
│  │  │  Worker 0   │    │  Worker 1   │    │  Worker 2   │              │  │
│  │  │ ┌─────────┐ │    │ ┌─────────┐ │    │ ┌─────────┐ │              │  │
│  │  │ │ 独立的  │ │    │ │ 独立的  │ │    │ │ 独立的  │ │              │  │
│  │  │ │Route/   │ │    │ │Route/   │ │    │ │Route/   │ │              │  │
│  │  │ │Cluster  │ │    │ │Cluster  │ │    │ │Cluster  │ │              │  │
│  │  │ │ 副本    │ │    │ │ 副本    │ │    │ │ 副本    │ │              │  │
│  │  │ └─────────┘ │    │ └─────────┘ │    │ └─────────┘ │              │  │
│  │  │   无锁访问   │    │   无锁访问   │    │   无锁访问   │              │  │
│  │  └─────────────┘    └─────────────┘    └─────────────┘              │  │
│  │                                                                    │  │
│  │  优点：                                                            │  │
│  │  • 完全无锁，每个Worker独立运行                                     │  │
│  │  • CPU缓存友好，数据局部性好                                        │  │
│  │  • 简单可靠，易于调试                                              │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 与其他系统的对比

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    线程模型对比                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┬─────────────────┬─────────────────┬────────────────┐  │
│  │     特性        │     Nginx       │    Node.js      │     Envoy      │  │
│  ├─────────────────┼─────────────────┼─────────────────┼────────────────┤  │
│  │ 进程/线程模型   │ Multi-Process   │ Single Thread   │ Multi-Thread   │  │
│  │                 │ (Master+Worker) │ (Event Loop)    │ (Main+Workers) │  │
│  ├─────────────────┼─────────────────┼─────────────────┼────────────────┤  │
│  │ 共享状态        │ 共享内存/锁     │ 无(单线程)      │ TLS副本        │  │
│  ├─────────────────┼─────────────────┼─────────────────┼────────────────┤  │
│  │ 配置更新        │ 重启Worker      │ 重启进程        │ 热更新(Drain)  │  │
│  ├─────────────────┼─────────────────┼─────────────────┼────────────────┤  │
│  │ CPU亲和性       │ 可配置          │ 单核            │ 自动绑定       │  │
│  ├─────────────────┼─────────────────┼─────────────────┼────────────────┤  │
│  │ 连接处理        │ accept_mutex    │ 单线程处理      │ SO_REUSEPORT   │  │
│  ├─────────────────┼─────────────────┼─────────────────┼────────────────┤  │
│  │ 适用场景        │ 静态内容/反代   │ I/O密集型       │ 服务代理/网格  │  │
│  └─────────────────┴─────────────────┴─────────────────┴────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 代码示例：线程模型实现

```cpp
// thread_model.hpp - Envoy风格的线程模型实现
#pragma once

#include <thread>
#include <vector>
#include <memory>
#include <functional>
#include <atomic>
#include <mutex>
#include <condition_variable>

namespace envoy_study {

// 前向声明
class Dispatcher;
class ThreadLocalStorage;

/**
 * Worker线程接口
 * 每个Worker拥有独立的事件循环和TLS数据
 */
class Worker {
public:
    using WorkerCallback = std::function<void(Worker&)>;

    virtual ~Worker() = default;

    // 获取此Worker的Dispatcher
    virtual Dispatcher& dispatcher() = 0;

    // 获取此Worker的TLS
    virtual ThreadLocalStorage& tls() = 0;

    // 向Worker投递任务
    virtual void post(std::function<void()> callback) = 0;

    // 获取Worker ID
    virtual uint32_t id() const = 0;
};

/**
 * Worker实现
 */
class WorkerImpl : public Worker {
public:
    WorkerImpl(uint32_t id, bool bind_to_cpu = true)
        : id_(id)
        , running_(false)
        , bind_to_cpu_(bind_to_cpu) {
    }

    ~WorkerImpl() override {
        stop();
    }

    void start() {
        running_ = true;
        thread_ = std::thread([this]() {
            // 可选：绑定到特定CPU核心
            if (bind_to_cpu_) {
                bindToCpu(id_);
            }

            // 初始化TLS
            initializeThreadLocal();

            // 运行事件循环
            runEventLoop();
        });
    }

    void stop() {
        if (running_) {
            running_ = false;
            // 唤醒事件循环
            wakeup();
            if (thread_.joinable()) {
                thread_.join();
            }
        }
    }

    Dispatcher& dispatcher() override {
        return *dispatcher_;
    }

    ThreadLocalStorage& tls() override {
        return *tls_;
    }

    void post(std::function<void()> callback) override {
        {
            std::lock_guard<std::mutex> lock(queue_mutex_);
            pending_callbacks_.push_back(std::move(callback));
        }
        wakeup();
    }

    uint32_t id() const override { return id_; }

private:
    void bindToCpu(uint32_t cpu_id) {
#ifdef __linux__
        cpu_set_t cpuset;
        CPU_ZERO(&cpuset);
        CPU_SET(cpu_id % std::thread::hardware_concurrency(), &cpuset);
        pthread_setaffinity_np(pthread_self(), sizeof(cpu_set_t), &cpuset);
#endif
    }

    void initializeThreadLocal();
    void runEventLoop();
    void wakeup();

    uint32_t id_;
    std::atomic<bool> running_;
    bool bind_to_cpu_;
    std::thread thread_;

    std::unique_ptr<Dispatcher> dispatcher_;
    std::unique_ptr<ThreadLocalStorage> tls_;

    std::mutex queue_mutex_;
    std::vector<std::function<void()>> pending_callbacks_;
};

/**
 * Main Thread - 管理所有Worker
 */
class MainThread {
public:
    struct Config {
        uint32_t num_workers = std::thread::hardware_concurrency();
        bool bind_workers_to_cpus = true;
    };

    explicit MainThread(const Config& config)
        : config_(config)
        , running_(false) {
    }

    ~MainThread() {
        shutdown();
    }

    // 启动所有Worker
    void start() {
        running_ = true;

        // 创建Worker线程
        for (uint32_t i = 0; i < config_.num_workers; ++i) {
            auto worker = std::make_unique<WorkerImpl>(i, config_.bind_workers_to_cpus);
            worker->start();
            workers_.push_back(std::move(worker));
        }

        std::cout << "Started " << config_.num_workers << " worker threads\n";
    }

    // 关闭所有Worker
    void shutdown() {
        if (!running_) return;
        running_ = false;

        // 停止所有Worker
        for (auto& worker : workers_) {
            worker->stop();
        }
        workers_.clear();

        std::cout << "All workers stopped\n";
    }

    // 向所有Worker广播任务
    void postToAll(std::function<void()> callback) {
        for (auto& worker : workers_) {
            worker->post(callback);
        }
    }

    // 向指定Worker投递任务
    void postToWorker(uint32_t worker_id, std::function<void()> callback) {
        if (worker_id < workers_.size()) {
            workers_[worker_id]->post(std::move(callback));
        }
    }

    // 获取Worker数量
    size_t numWorkers() const { return workers_.size(); }

    // 获取指定Worker
    Worker& worker(uint32_t id) { return *workers_[id]; }

private:
    Config config_;
    std::atomic<bool> running_;
    std::vector<std::unique_ptr<WorkerImpl>> workers_;
};

/**
 * 线程模型使用示例
 */
inline void threadModelExample() {
    std::cout << "=== Envoy Thread Model Example ===\n\n";

    // 配置
    MainThread::Config config;
    config.num_workers = 4;
    config.bind_workers_to_cpus = true;

    // 创建并启动
    MainThread main_thread(config);
    main_thread.start();

    // 向所有Worker广播任务
    main_thread.postToAll([]() {
        std::cout << "Task running on worker thread\n";
    });

    // 向特定Worker投递任务
    main_thread.postToWorker(0, []() {
        std::cout << "Task running on worker 0\n";
    });

    // 模拟运行一段时间
    std::this_thread::sleep_for(std::chrono::seconds(1));

    // 关闭
    main_thread.shutdown();
}

} // namespace envoy_study
```

---

### Day 10-11：Thread Local Storage机制（10小时）

#### TLS设计原理

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Thread Local Storage (TLS) 机制                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  设计目标：                                                                  │
│  • 让每个Worker线程拥有配置数据的独立副本                                    │
│  • 实现配置的无锁读取（读取频率远高于更新频率）                              │
│  • 支持配置的原子更新（通过Main Thread协调）                                 │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      TLS Slot 机制                                   │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                     │   │
│  │   Main Thread                                                       │   │
│  │   ┌─────────────────────────────────────────────────────────────┐  │   │
│  │   │  SlotAllocator                                               │  │   │
│  │   │  ┌────────┬────────┬────────┬────────┐                      │  │   │
│  │   │  │ Slot 0 │ Slot 1 │ Slot 2 │ Slot 3 │  ...                 │  │   │
│  │   │  │RouteTab│ClusterM│StatsBuf│ Users  │                      │  │   │
│  │   │  └────────┴────────┴────────┴────────┘                      │  │   │
│  │   └─────────────────────────────────────────────────────────────┘  │   │
│  │                          │                                          │   │
│  │                   allocateSlot()                                    │   │
│  │                   updateSlot(slot_id, data)                        │   │
│  │                          │                                          │   │
│  │          ┌───────────────┼───────────────┐                         │   │
│  │          │               │               │                         │   │
│  │          ▼               ▼               ▼                         │   │
│  │   ┌──────────────┐ ┌──────────────┐ ┌──────────────┐              │   │
│  │   │  Worker 0    │ │  Worker 1    │ │  Worker 2    │              │   │
│  │   │ TLS Data[]:  │ │ TLS Data[]:  │ │ TLS Data[]:  │              │   │
│  │   │ [0] RouteTab│ │ [0] RouteTab│ │ [0] RouteTab│              │   │
│  │   │ [1] ClusterM│ │ [1] ClusterM│ │ [1] ClusterM│              │   │
│  │   │ [2] StatsBuf│ │ [2] StatsBuf│ │ [2] StatsBuf│              │   │
│  │   │ [3] Users   │ │ [3] Users   │ │ [3] Users   │              │   │
│  │   └──────────────┘ └──────────────┘ └──────────────┘              │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Slot类型示例：                                                             │
│  • Slot 0: RouteTable - 路由配置                                           │
│  • Slot 1: ClusterManager - 集群配置                                       │
│  • Slot 2: StatsBuffer - 统计数据缓冲                                      │
│  • Slot 3: 用户自定义数据                                                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 配置更新流程

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    配置更新流程 (Config Update Flow)                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  时间线 ───────────────────────────────────────────────────────────────▶   │
│                                                                             │
│  Main Thread:                                                               │
│  ┌────────┐    ┌────────────┐    ┌────────────┐    ┌────────────┐         │
│  │ 收到   │───▶│ 解析新     │───▶│ 创建新     │───▶│ 广播到     │         │
│  │ xDS    │    │ 配置数据   │    │ 配置对象   │    │ 所有Worker │         │
│  │ 更新   │    │            │    │ (shared)   │    │            │         │
│  └────────┘    └────────────┘    └────────────┘    └────────────┘         │
│                                                      │ │ │                │
│                        ┌─────────────────────────────┘ │ │                │
│                        │    ┌──────────────────────────┘ │                │
│                        │    │    ┌───────────────────────┘                │
│                        ▼    ▼    ▼                                        │
│  Worker 0:  ──────────[更新TLS]─────────────────────────────────▶         │
│  Worker 1:  ────────────────[更新TLS]───────────────────────────▶         │
│  Worker 2:  ──────────────────────[更新TLS]─────────────────────▶         │
│                                                                             │
│  关键点：                                                                   │
│  1. Main Thread创建新配置对象（使用shared_ptr）                             │
│  2. 通过post()将更新任务投递到每个Worker                                    │
│  3. Worker在自己的事件循环中执行更新（无锁）                                │
│  4. 旧配置对象在最后一个引用释放时自动销毁                                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 代码示例：TLS机制实现

```cpp
// tls.hpp - Thread Local Storage机制实现
#pragma once

#include <vector>
#include <memory>
#include <functional>
#include <atomic>
#include <mutex>
#include <unordered_map>
#include <thread>
#include <iostream>

namespace envoy_study {

/**
 * TLS数据的基类
 */
class ThreadLocalObject {
public:
    virtual ~ThreadLocalObject() = default;
};

/**
 * TLS Slot - 代表一个可以存储线程本地数据的槽位
 */
class Slot {
public:
    virtual ~Slot() = default;

    // 获取当前线程的TLS数据
    virtual ThreadLocalObject* get() = 0;

    // 获取当前线程的TLS数据（类型安全版本）
    template <typename T>
    T* getTyped() {
        return dynamic_cast<T*>(get());
    }

    // 设置当前线程的TLS数据
    virtual void set(std::unique_ptr<ThreadLocalObject> data) = 0;

    // 在所有线程上更新TLS数据
    virtual void runOnAllThreads(
        std::function<std::unique_ptr<ThreadLocalObject>()> factory) = 0;
};

/**
 * TLS Slot实现
 */
class SlotImpl : public Slot {
public:
    explicit SlotImpl(uint32_t slot_index)
        : slot_index_(slot_index) {}

    ThreadLocalObject* get() override {
        std::thread::id tid = std::this_thread::get_id();
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = thread_data_.find(tid);
        if (it != thread_data_.end()) {
            return it->second.get();
        }
        return nullptr;
    }

    void set(std::unique_ptr<ThreadLocalObject> data) override {
        std::thread::id tid = std::this_thread::get_id();
        std::lock_guard<std::mutex> lock(mutex_);
        thread_data_[tid] = std::move(data);
    }

    void runOnAllThreads(
        std::function<std::unique_ptr<ThreadLocalObject>()> factory) override {
        // 在实际实现中，这里会通过Dispatcher将任务投递到所有Worker
        // 简化实现：直接在当前线程执行
        set(factory());
    }

    uint32_t index() const { return slot_index_; }

private:
    uint32_t slot_index_;
    std::mutex mutex_;
    std::unordered_map<std::thread::id, std::unique_ptr<ThreadLocalObject>> thread_data_;
};

/**
 * Thread Local Storage管理器
 */
class ThreadLocalStorage {
public:
    ThreadLocalStorage() : next_slot_index_(0) {}

    // 分配一个新的Slot
    std::shared_ptr<Slot> allocateSlot() {
        uint32_t index = next_slot_index_++;
        auto slot = std::make_shared<SlotImpl>(index);

        std::lock_guard<std::mutex> lock(mutex_);
        slots_.push_back(slot);

        return slot;
    }

    // 获取所有Slot数量
    size_t numSlots() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return slots_.size();
    }

private:
    std::atomic<uint32_t> next_slot_index_;
    mutable std::mutex mutex_;
    std::vector<std::shared_ptr<SlotImpl>> slots_;
};

/**
 * 示例：使用TLS存储路由配置
 */
class RouteConfigTLS : public ThreadLocalObject {
public:
    struct Route {
        std::string prefix;
        std::string cluster;
    };

    void addRoute(const std::string& prefix, const std::string& cluster) {
        routes_.push_back({prefix, cluster});
    }

    const Route* matchRoute(const std::string& path) const {
        for (const auto& route : routes_) {
            if (path.find(route.prefix) == 0) {
                return &route;
            }
        }
        return nullptr;
    }

    size_t numRoutes() const { return routes_.size(); }

private:
    std::vector<Route> routes_;
};

/**
 * 路由配置管理器 - 使用TLS实现无锁路由查找
 */
class RouteConfigManager {
public:
    explicit RouteConfigManager(ThreadLocalStorage& tls)
        : tls_(tls)
        , slot_(tls.allocateSlot()) {}

    // 更新路由配置（在Main Thread调用）
    void updateRoutes(const std::vector<std::pair<std::string, std::string>>& routes) {
        slot_->runOnAllThreads([&routes]() {
            auto config = std::make_unique<RouteConfigTLS>();
            for (const auto& [prefix, cluster] : routes) {
                config->addRoute(prefix, cluster);
            }
            return config;
        });
    }

    // 查找路由（在Worker Thread调用，无锁）
    std::string findCluster(const std::string& path) {
        auto* config = slot_->getTyped<RouteConfigTLS>();
        if (config) {
            auto* route = config->matchRoute(path);
            if (route) {
                return route->cluster;
            }
        }
        return "";
    }

private:
    ThreadLocalStorage& tls_;
    std::shared_ptr<Slot> slot_;
};

/**
 * TLS使用示例
 */
inline void tlsExample() {
    std::cout << "=== TLS Example ===\n\n";

    ThreadLocalStorage tls;

    // 创建路由配置管理器
    RouteConfigManager route_manager(tls);

    // 更新路由配置
    route_manager.updateRoutes({
        {"/api/users", "user-service"},
        {"/api/orders", "order-service"},
        {"/static", "static-service"}
    });

    // 在当前线程查找路由
    std::cout << "/api/users/123 -> "
              << route_manager.findCluster("/api/users/123") << "\n";
    std::cout << "/api/orders/456 -> "
              << route_manager.findCluster("/api/orders/456") << "\n";
    std::cout << "/static/js/app.js -> "
              << route_manager.findCluster("/static/js/app.js") << "\n";
}

} // namespace envoy_study
```

---

### Day 12-14：事件循环实现（15小时）

#### Dispatcher事件分发器

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Dispatcher 事件分发器架构                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         Dispatcher                                   │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                     │   │
│  │   ┌───────────────────────────────────────────────────────────┐    │   │
│  │   │                    libevent base                           │    │   │
│  │   │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐      │    │   │
│  │   │  │ Timer   │  │ Socket  │  │ Signal  │  │ Deferred│      │    │   │
│  │   │  │ Events  │  │ Events  │  │ Events  │  │ Tasks   │      │    │   │
│  │   │  └─────────┘  └─────────┘  └─────────┘  └─────────┘      │    │   │
│  │   └───────────────────────────────────────────────────────────┘    │   │
│  │                              │                                      │   │
│  │                              ▼                                      │   │
│  │   ┌───────────────────────────────────────────────────────────┐    │   │
│  │   │                    Event Loop                              │    │   │
│  │   │                                                            │    │   │
│  │   │    while (running) {                                       │    │   │
│  │   │        1. 处理延迟任务队列                                  │    │   │
│  │   │        2. 调用 event_base_loop()                           │    │   │
│  │   │        3. 处理定时器回调                                    │    │   │
│  │   │        4. 处理I/O事件回调                                   │    │   │
│  │   │    }                                                        │    │   │
│  │   │                                                            │    │   │
│  │   └───────────────────────────────────────────────────────────┘    │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Dispatcher提供的能力：                                                     │
│  • createTimer() - 创建定时器                                              │
│  • createFileEvent() - 监听文件描述符                                       │
│  • post() - 投递延迟任务                                                   │
│  • deferredDelete() - 延迟删除对象                                         │
│  • run() - 运行事件循环                                                    │
│  • exit() - 退出事件循环                                                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 定时器机制

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         定时器实现机制                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  定时器类型：                                                                │
│  ┌─────────────────┬────────────────────────────────────────────────────┐  │
│  │ 一次性定时器    │ 到期后自动禁用，需要重新enable才能再次触发          │  │
│  ├─────────────────┼────────────────────────────────────────────────────┤  │
│  │ 周期性定时器    │ 到期后自动重新调度，持续触发直到禁用                │  │
│  ├─────────────────┼────────────────────────────────────────────────────┤  │
│  │ 可调度定时器    │ 支持动态修改触发时间                                │  │
│  └─────────────────┴────────────────────────────────────────────────────┘  │
│                                                                             │
│  定时器在Envoy中的使用场景：                                                 │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                                                                      │  │
│  │   连接超时                健康检查                配置刷新           │  │
│  │   ┌─────────┐            ┌─────────┐            ┌─────────┐         │  │
│  │   │ 30s     │            │ 5s周期  │            │ 30s周期 │         │  │
│  │   │ 读超时  │            │ 检查    │            │ xDS刷新 │         │  │
│  │   └─────────┘            └─────────┘            └─────────┘         │  │
│  │                                                                      │  │
│  │   请求超时                重试延迟                统计上报           │  │
│  │   ┌─────────┐            ┌─────────┐            ┌─────────┐         │  │
│  │   │ 15s     │            │ 指数    │            │ 10s周期 │         │  │
│  │   │ 等待响应│            │ 退避    │            │ 上报    │         │  │
│  │   └─────────┘            └─────────┘            └─────────┘         │  │
│  │                                                                      │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 代码示例：Dispatcher实现

```cpp
// dispatcher.hpp - 事件分发器实现
#pragma once

#include <functional>
#include <memory>
#include <vector>
#include <queue>
#include <mutex>
#include <chrono>
#include <atomic>
#include <map>
#include <iostream>
#include <thread>

#ifdef __linux__
#include <sys/epoll.h>
#include <sys/eventfd.h>
#include <unistd.h>
#endif

namespace envoy_study {

using Callback = std::function<void()>;
using SteadyClock = std::chrono::steady_clock;
using TimePoint = SteadyClock::time_point;
using Duration = std::chrono::milliseconds;

/**
 * 定时器接口
 */
class Timer {
public:
    virtual ~Timer() = default;
    virtual void enableTimer(Duration timeout) = 0;
    virtual void disableTimer() = 0;
    virtual bool enabled() const = 0;
};

/**
 * 文件事件接口
 */
class FileEvent {
public:
    enum class Type { Read = 0x01, Write = 0x02, ReadWrite = 0x03 };
    virtual ~FileEvent() = default;
    virtual void setEnabled(Type events) = 0;
    virtual int fd() const = 0;
};

/**
 * 定时器实现
 */
class TimerImpl : public Timer {
public:
    TimerImpl(Callback cb, std::function<void(TimerImpl*)> enable_fn,
              std::function<void(TimerImpl*)> disable_fn)
        : callback_(std::move(cb)), enable_fn_(enable_fn),
          disable_fn_(disable_fn), enabled_(false) {}

    void enableTimer(Duration timeout) override {
        timeout_ = timeout;
        trigger_time_ = SteadyClock::now() + timeout;
        enabled_ = true;
        enable_fn_(this);
    }

    void disableTimer() override {
        if (enabled_) { enabled_ = false; disable_fn_(this); }
    }

    bool enabled() const override { return enabled_; }

    void fire() {
        if (enabled_) { enabled_ = false; callback_(); }
    }

    TimePoint triggerTime() const { return trigger_time_; }

private:
    Callback callback_;
    std::function<void(TimerImpl*)> enable_fn_;
    std::function<void(TimerImpl*)> disable_fn_;
    Duration timeout_;
    TimePoint trigger_time_;
    std::atomic<bool> enabled_;
};

/**
 * Dispatcher - 事件分发器核心实现
 */
class Dispatcher {
public:
    Dispatcher() : running_(false), wakeup_fd_(-1) {
#ifdef __linux__
        epoll_fd_ = epoll_create1(0);
        wakeup_fd_ = eventfd(0, EFD_NONBLOCK);
        struct epoll_event ev;
        ev.events = EPOLLIN;
        ev.data.fd = wakeup_fd_;
        epoll_ctl(epoll_fd_, EPOLL_CTL_ADD, wakeup_fd_, &ev);
#endif
    }

    ~Dispatcher() {
#ifdef __linux__
        if (wakeup_fd_ >= 0) close(wakeup_fd_);
        if (epoll_fd_ >= 0) close(epoll_fd_);
#endif
    }

    // 创建定时器
    std::unique_ptr<Timer> createTimer(Callback callback) {
        return std::make_unique<TimerImpl>(
            std::move(callback),
            [this](TimerImpl* t) { addTimer(t); },
            [this](TimerImpl* t) { removeTimer(t); }
        );
    }

    // 投递延迟任务
    void post(Callback callback) {
        {
            std::lock_guard<std::mutex> lock(post_mutex_);
            posted_callbacks_.push_back(std::move(callback));
        }
        wakeup();
    }

    // 运行事件循环
    void run() {
        running_ = true;
        while (running_) {
            runPostedCallbacks();
            int timeout_ms = calculateNextTimeout();
#ifdef __linux__
            struct epoll_event events[64];
            int nfds = epoll_wait(epoll_fd_, events, 64, timeout_ms);
            for (int i = 0; i < nfds; ++i) {
                if (events[i].data.fd == wakeup_fd_) {
                    uint64_t val;
                    read(wakeup_fd_, &val, sizeof(val));
                }
            }
#else
            std::this_thread::sleep_for(Duration(timeout_ms > 0 ? timeout_ms : 10));
#endif
            runExpiredTimers();
        }
    }

    void exit() { running_ = false; wakeup(); }

private:
    void addTimer(TimerImpl* timer) {
        std::lock_guard<std::mutex> lock(timer_mutex_);
        active_timers_.insert({timer->triggerTime(), timer});
    }

    void removeTimer(TimerImpl* timer) {
        std::lock_guard<std::mutex> lock(timer_mutex_);
        auto range = active_timers_.equal_range(timer->triggerTime());
        for (auto it = range.first; it != range.second; ++it) {
            if (it->second == timer) {
                active_timers_.erase(it);
                break;
            }
        }
    }

    int calculateNextTimeout() {
        std::lock_guard<std::mutex> lock(timer_mutex_);
        if (active_timers_.empty()) return 100;
        auto now = SteadyClock::now();
        auto next = active_timers_.begin()->first;
        if (next <= now) return 0;
        return static_cast<int>(
            std::chrono::duration_cast<Duration>(next - now).count());
    }

    void runExpiredTimers() {
        std::vector<TimerImpl*> expired;
        {
            std::lock_guard<std::mutex> lock(timer_mutex_);
            auto now = SteadyClock::now();
            auto it = active_timers_.begin();
            while (it != active_timers_.end() && it->first <= now) {
                expired.push_back(it->second);
                it = active_timers_.erase(it);
            }
        }
        for (auto* timer : expired) timer->fire();
    }

    void runPostedCallbacks() {
        std::vector<Callback> callbacks;
        {
            std::lock_guard<std::mutex> lock(post_mutex_);
            callbacks.swap(posted_callbacks_);
        }
        for (auto& cb : callbacks) cb();
    }

    void wakeup() {
#ifdef __linux__
        uint64_t val = 1;
        write(wakeup_fd_, &val, sizeof(val));
#endif
    }

    std::atomic<bool> running_;
    int epoll_fd_ = -1;
    int wakeup_fd_;
    std::mutex timer_mutex_;
    std::multimap<TimePoint, TimerImpl*> active_timers_;
    std::mutex post_mutex_;
    std::vector<Callback> posted_callbacks_;
};

} // namespace envoy_study
```

#### 完整的Worker线程实现

```cpp
// worker_thread.hpp - 完整的Worker线程实现
#pragma once

#include <thread>
#include <memory>
#include <atomic>
#include <functional>
#include <iostream>

namespace envoy_study {

// 前向声明
class Dispatcher;
class ThreadLocalStorage;

/**
 * 完整的Worker线程实现
 * 集成Dispatcher和TLS
 */
class WorkerThread {
public:
    explicit WorkerThread(uint32_t id)
        : id_(id), running_(false) {}

    ~WorkerThread() { stop(); }

    void start() {
        running_ = true;
        thread_ = std::thread([this]() {
            // 设置线程名
            setThreadName("worker-" + std::to_string(id_));

            // 初始化Dispatcher
            dispatcher_ = std::make_unique<Dispatcher>();

            // 初始化TLS
            tls_ = std::make_unique<ThreadLocalStorage>();

            // 通知启动完成
            {
                std::lock_guard<std::mutex> lock(init_mutex_);
                initialized_ = true;
            }
            init_cv_.notify_one();

            // 运行事件循环
            dispatcher_->run();
        });

        // 等待初始化完成
        std::unique_lock<std::mutex> lock(init_mutex_);
        init_cv_.wait(lock, [this] { return initialized_; });
    }

    void stop() {
        if (running_) {
            running_ = false;
            if (dispatcher_) dispatcher_->exit();
            if (thread_.joinable()) thread_.join();
        }
    }

    void post(std::function<void()> callback) {
        if (dispatcher_) dispatcher_->post(std::move(callback));
    }

    uint32_t id() const { return id_; }
    Dispatcher* dispatcher() { return dispatcher_.get(); }
    ThreadLocalStorage* tls() { return tls_.get(); }

private:
    void setThreadName(const std::string& name) {
#ifdef __linux__
        pthread_setname_np(pthread_self(), name.c_str());
#elif defined(__APPLE__)
        pthread_setname_np(name.c_str());
#endif
    }

    uint32_t id_;
    std::atomic<bool> running_;
    std::thread thread_;

    std::unique_ptr<Dispatcher> dispatcher_;
    std::unique_ptr<ThreadLocalStorage> tls_;

    std::mutex init_mutex_;
    std::condition_variable init_cv_;
    bool initialized_ = false;
};

/**
 * Worker管理器
 */
class WorkerManager {
public:
    explicit WorkerManager(uint32_t num_workers)
        : num_workers_(num_workers) {}

    void start() {
        for (uint32_t i = 0; i < num_workers_; ++i) {
            auto worker = std::make_unique<WorkerThread>(i);
            worker->start();
            workers_.push_back(std::move(worker));
        }
        std::cout << "Started " << num_workers_ << " workers\n";
    }

    void stop() {
        for (auto& worker : workers_) {
            worker->stop();
        }
        workers_.clear();
        std::cout << "All workers stopped\n";
    }

    // 向所有Worker广播任务
    void postToAll(std::function<void()> callback) {
        for (auto& worker : workers_) {
            worker->post(callback);
        }
    }

    // 向指定Worker投递任务
    void postToWorker(uint32_t id, std::function<void()> callback) {
        if (id < workers_.size()) {
            workers_[id]->post(std::move(callback));
        }
    }

    size_t size() const { return workers_.size(); }
    WorkerThread& worker(uint32_t id) { return *workers_[id]; }

private:
    uint32_t num_workers_;
    std::vector<std::unique_ptr<WorkerThread>> workers_;
};

/**
 * 使用示例
 */
inline void workerManagerExample() {
    std::cout << "=== Worker Manager Example ===\n";

    WorkerManager manager(4);
    manager.start();

    // 向所有Worker广播任务
    manager.postToAll([]() {
        std::cout << "Hello from worker!\n";
    });

    std::this_thread::sleep_for(std::chrono::milliseconds(100));
    manager.stop();
}

} // namespace envoy_study
```

---

### 第二周自测问题

完成第二周学习后，请尝试回答以下问题：

**理论理解：**
1. Envoy为什么选择Thread-per-Core模型而不是传统的多线程共享模型？
2. Main Thread和Worker Thread各自负责什么职责？
3. TLS机制是如何实现无锁读取的？
4. 配置更新时，旧配置是如何被安全销毁的？
5. Dispatcher的事件循环处理哪些类型的事件？

**代码实践：**
1. 实现一个简单的Worker线程池
2. 实现TLS Slot分配和数据存储
3. 实现基于epoll的Dispatcher
4. 实现定时器队列管理
5. 模拟配置热更新流程

---

### 第二周检验标准

| 检验项 | 标准 | 自评 |
|--------|------|------|
| 理解线程模型 | 能解释Thread-per-Core的优势 | ☐ |
| 理解TLS机制 | 能描述Slot分配和数据传播流程 | ☐ |
| 理解Dispatcher | 能解释事件循环的工作原理 | ☐ |
| 实现Worker池 | 代码能正确管理多个Worker | ☐ |
| 实现TLS | 代码能正确存储和获取TLS数据 | ☐ |
| 实现定时器 | 代码能正确触发定时回调 | ☐ |

---

### 第二周时间分配

| 内容 | 时间 |
|------|------|
| 线程模型设计理解 | 6小时 |
| 与其他系统对比 | 4小时 |
| TLS机制原理 | 5小时 |
| TLS代码实现 | 5小时 |
| Dispatcher设计 | 5小时 |
| 事件循环实现 | 6小时 |
| 定时器实现 | 4小时 |

---

## 第三周：Filter机制深入（Day 15-21）

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    第三周学习路线图                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Day 15-16            Day 17-18            Day 19-21                      │
│   ┌─────────┐         ┌─────────┐          ┌─────────┐                     │
│   │ Network │         │  HTTP   │          │ Filter  │                     │
│   │ Filter  │────────▶│ Filter  │─────────▶│ Chain   │                     │
│   │  详解   │         │  详解   │          │  实战   │                     │
│   └─────────┘         └─────────┘          └─────────┘                     │
│       │                   │                    │                           │
│       ▼                   ▼                    ▼                           │
│   Read/Write          Decoder/Encoder       状态机                         │
│   Filter接口          Filter接口            异步处理                        │
│                                                                             │
│   学习目标：深入理解Envoy的Filter链机制与扩展开发                            │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Day 15-16：Network Filter（10小时）

#### Filter链架构

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Filter Chain 架构                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   下游连接                                              上游连接            │
│   (Client)                                              (Upstream)          │
│      │                                                      ▲              │
│      ▼                                                      │              │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                         Listener                                       │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                              │                                              │
│                              ▼                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                    Filter Chain                                        │ │
│  │  ┌─────────────────────────────────────────────────────────────────┐  │ │
│  │  │                   Network Filters                                │  │ │
│  │  │  ┌────────────┐  ┌────────────┐  ┌────────────┐                 │  │ │
│  │  │  │  TLS       │─▶│  Rate     │─▶│   HTTP     │                 │  │ │
│  │  │  │  Inspector │  │  Limit    │  │ Connection │                 │  │ │
│  │  │  │            │  │           │  │  Manager   │                 │  │ │
│  │  │  └────────────┘  └────────────┘  └────────────┘                 │  │ │
│  │  │                                        │                         │  │ │
│  │  │                                        ▼                         │  │ │
│  │  │  ┌─────────────────────────────────────────────────────────┐   │  │ │
│  │  │  │                    HTTP Filters                          │   │  │ │
│  │  │  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐           │   │  │ │
│  │  │  │  │ CORS   │─│ Auth   │─│ Router │─│ Stats  │           │   │  │ │
│  │  │  │  │ Filter │ │ Filter │ │ Filter │ │ Filter │           │   │  │ │
│  │  │  │  └────────┘ └────────┘ └────────┘ └────────┘           │   │  │ │
│  │  │  └─────────────────────────────────────────────────────────┘   │  │ │
│  │  └─────────────────────────────────────────────────────────────────┘  │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
│  Filter执行顺序：                                                           │
│  • 请求方向：从左到右依次执行                                               │
│  • 响应方向：从右到左依次执行                                               │
│  • 任何Filter可以中断链的执行                                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Network Filter接口

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Network Filter 接口设计                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  ReadFilter（读取过滤器）                                            │   │
│  │                                                                     │   │
│  │  • onNewConnection() - 新连接建立时调用                              │   │
│  │  • onData() - 接收到数据时调用                                       │   │
│  │  • initializeReadFilterCallbacks() - 初始化回调                      │   │
│  │                                                                     │   │
│  │  返回值：                                                            │   │
│  │  • Continue - 继续执行下一个Filter                                   │   │
│  │  • StopIteration - 停止当前迭代，等待更多数据                        │   │
│  │  • StopIterationAndBuffer - 停止并缓冲数据                          │   │
│  │  • StopIterationAndWatermark - 停止并应用水位线                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  WriteFilter（写入过滤器）                                           │   │
│  │                                                                     │   │
│  │  • onWrite() - 写入数据时调用                                        │   │
│  │                                                                     │   │
│  │  返回值：                                                            │   │
│  │  • Continue - 继续执行下一个Filter                                   │   │
│  │  • StopIteration - 停止当前迭代                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Filter（同时支持读写）                                              │   │
│  │                                                                     │   │
│  │  继承自 ReadFilter 和 WriteFilter                                    │   │
│  │  可以同时处理入站和出站数据                                          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 代码示例：Network Filter实现

```cpp
// network_filter.hpp - Network Filter接口与实现
#pragma once

#include <memory>
#include <string>
#include <vector>
#include <functional>
#include <iostream>

namespace envoy_study {

// 数据缓冲区
class Buffer {
public:
    void add(const std::string& data) { data_ += data; }
    void add(const char* data, size_t len) { data_.append(data, len); }
    void drain(size_t len) { data_.erase(0, len); }
    size_t length() const { return data_.size(); }
    const std::string& toString() const { return data_; }
    void clear() { data_.clear(); }

private:
    std::string data_;
};

// Filter状态
enum class FilterStatus {
    Continue,                  // 继续执行下一个Filter
    StopIteration,            // 停止当前迭代
    StopIterationAndBuffer,   // 停止并缓冲数据
    StopIterationNoBuffer     // 停止但不缓冲
};

// 连接状态
enum class ConnectionCloseType {
    NoFlush,                  // 立即关闭
    FlushWrite,              // 刷新写缓冲后关闭
    FlushWriteAndDelay       // 刷新并延迟关闭
};

// ReadFilter回调接口
class ReadFilterCallbacks {
public:
    virtual ~ReadFilterCallbacks() = default;
    virtual void continueReading() = 0;
    virtual void injectReadDataToFilterChain(Buffer& data, bool end_stream) = 0;
    virtual Buffer& buffer() = 0;
    virtual void connection_close(ConnectionCloseType type) = 0;
};

// WriteFilter回调接口
class WriteFilterCallbacks {
public:
    virtual ~WriteFilterCallbacks() = default;
    virtual void injectWriteDataToFilterChain(Buffer& data, bool end_stream) = 0;
};

/**
 * ReadFilter接口
 */
class ReadFilter {
public:
    virtual ~ReadFilter() = default;

    // 新连接建立时调用
    virtual FilterStatus onNewConnection() { return FilterStatus::Continue; }

    // 接收到数据时调用
    virtual FilterStatus onData(Buffer& data, bool end_stream) = 0;

    // 初始化回调
    virtual void initializeReadFilterCallbacks(ReadFilterCallbacks& callbacks) {
        read_callbacks_ = &callbacks;
    }

protected:
    ReadFilterCallbacks* read_callbacks_ = nullptr;
};

/**
 * WriteFilter接口
 */
class WriteFilter {
public:
    virtual ~WriteFilter() = default;

    // 写入数据时调用
    virtual FilterStatus onWrite(Buffer& data, bool end_stream) = 0;

    // 初始化回调
    virtual void initializeWriteFilterCallbacks(WriteFilterCallbacks& callbacks) {
        write_callbacks_ = &callbacks;
    }

protected:
    WriteFilterCallbacks* write_callbacks_ = nullptr;
};

/**
 * 同时支持读写的Filter
 */
class Filter : public ReadFilter, public WriteFilter {
public:
    ~Filter() override = default;
};

/**
 * 示例：日志Network Filter
 * 记录所有进出的数据
 */
class LoggingFilter : public Filter {
public:
    explicit LoggingFilter(const std::string& name = "logging")
        : name_(name) {}

    FilterStatus onNewConnection() override {
        std::cout << "[" << name_ << "] New connection established\n";
        return FilterStatus::Continue;
    }

    FilterStatus onData(Buffer& data, bool end_stream) override {
        std::cout << "[" << name_ << "] Read " << data.length()
                  << " bytes, end_stream=" << end_stream << "\n";
        std::cout << "[" << name_ << "] Data: " << data.toString() << "\n";
        return FilterStatus::Continue;
    }

    FilterStatus onWrite(Buffer& data, bool end_stream) override {
        std::cout << "[" << name_ << "] Write " << data.length()
                  << " bytes, end_stream=" << end_stream << "\n";
        return FilterStatus::Continue;
    }

private:
    std::string name_;
};

/**
 * 示例：速率限制Filter
 */
class RateLimitFilter : public ReadFilter {
public:
    RateLimitFilter(size_t max_bytes_per_second)
        : max_bytes_(max_bytes_per_second)
        , bytes_this_second_(0)
        , last_reset_(std::chrono::steady_clock::now()) {}

    FilterStatus onData(Buffer& data, bool end_stream) override {
        auto now = std::chrono::steady_clock::now();
        auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(
            now - last_reset_).count();

        if (elapsed >= 1) {
            bytes_this_second_ = 0;
            last_reset_ = now;
        }

        bytes_this_second_ += data.length();

        if (bytes_this_second_ > max_bytes_) {
            std::cout << "[RateLimit] Rate exceeded! Closing connection.\n";
            if (read_callbacks_) {
                read_callbacks_->connection_close(ConnectionCloseType::NoFlush);
            }
            return FilterStatus::StopIteration;
        }

        return FilterStatus::Continue;
    }

private:
    size_t max_bytes_;
    size_t bytes_this_second_;
    std::chrono::steady_clock::time_point last_reset_;
};

} // namespace envoy_study
```

---

### Day 17-18：HTTP Filter（10小时）

#### HTTP Filter架构

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    HTTP Filter 处理流程                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   请求方向（Downstream → Upstream）                                         │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │  Request     Request      Request      Request     Request         │  │
│   │  Headers  →  Body      →  Trailers  →  Complete →  转发            │  │
│   │  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐                   │  │
│   │  │Decoder │─▶│Decoder │─▶│Decoder │─▶│Decoder │   ───▶ Upstream   │  │
│   │  │Headers │  │Data    │  │Trailers│  │Complete│                   │  │
│   │  └────────┘  └────────┘  └────────┘  └────────┘                   │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│   响应方向（Upstream → Downstream）                                         │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │  Response    Response     Response     Response    Response        │  │
│   │  Headers  ←  Body      ←  Trailers  ←  Complete ←  接收            │  │
│   │  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐                   │  │
│   │  │Encoder │◀─│Encoder │◀─│Encoder │◀─│Encoder │   ◀─── Upstream   │  │
│   │  │Headers │  │Data    │  │Trailers│  │Complete│                   │  │
│   │  └────────┘  └────────┘  └────────┘  └────────┘                   │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  Filter执行顺序：                                                           │
│  • Decoder (请求): Filter 1 → 2 → 3 → ... → Router                        │
│  • Encoder (响应): Router → ... → 3 → 2 → 1                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 代码示例：HTTP Filter实现

```cpp
// http_filter.hpp - HTTP Filter接口与实现
#pragma once

#include <string>
#include <map>
#include <memory>
#include <vector>
#include <functional>
#include <iostream>
#include <chrono>

namespace envoy_study {

// HTTP头部映射
class HeaderMap {
public:
    void addHeader(const std::string& key, const std::string& value) {
        headers_[key] = value;
    }
    void removeHeader(const std::string& key) { headers_.erase(key); }
    std::string getHeader(const std::string& key) const {
        auto it = headers_.find(key);
        return it != headers_.end() ? it->second : "";
    }
    bool hasHeader(const std::string& key) const {
        return headers_.find(key) != headers_.end();
    }
    size_t size() const { return headers_.size(); }

private:
    std::map<std::string, std::string> headers_;
};

using RequestHeaderMap = HeaderMap;
using ResponseHeaderMap = HeaderMap;

// Filter状态
enum class FilterHeadersStatus {
    Continue,
    StopIteration,
    StopAllIterationAndBuffer
};

enum class FilterDataStatus {
    Continue,
    StopIterationAndBuffer,
    StopIterationNoBuffer
};

// Decoder回调
class StreamDecoderFilterCallbacks {
public:
    virtual ~StreamDecoderFilterCallbacks() = default;
    virtual void continueDecoding() = 0;
    virtual void sendLocalReply(int code, const std::string& body) = 0;
};

/**
 * StreamDecoderFilter接口
 */
class StreamDecoderFilter {
public:
    virtual ~StreamDecoderFilter() = default;

    virtual FilterHeadersStatus decodeHeaders(RequestHeaderMap& headers,
                                               bool end_stream) {
        return FilterHeadersStatus::Continue;
    }

    virtual FilterDataStatus decodeData(Buffer& data, bool end_stream) {
        return FilterDataStatus::Continue;
    }

    virtual void setDecoderFilterCallbacks(StreamDecoderFilterCallbacks& cb) {
        decoder_callbacks_ = &cb;
    }

protected:
    StreamDecoderFilterCallbacks* decoder_callbacks_ = nullptr;
};

/**
 * StreamEncoderFilter接口
 */
class StreamEncoderFilter {
public:
    virtual ~StreamEncoderFilter() = default;

    virtual FilterHeadersStatus encodeHeaders(ResponseHeaderMap& headers,
                                               bool end_stream) {
        return FilterHeadersStatus::Continue;
    }

    virtual FilterDataStatus encodeData(Buffer& data, bool end_stream) {
        return FilterDataStatus::Continue;
    }

    virtual void encodeComplete() {}
};

/**
 * StreamFilter（双向过滤器）
 */
class StreamFilter : public StreamDecoderFilter, public StreamEncoderFilter {};

/**
 * 认证Filter
 */
class AuthenticationFilter : public StreamDecoderFilter {
public:
    FilterHeadersStatus decodeHeaders(RequestHeaderMap& headers,
                                      bool end_stream) override {
        std::string auth = headers.getHeader("Authorization");

        if (auth.empty()) {
            std::cout << "[Auth] Missing Authorization\n";
            if (decoder_callbacks_) {
                decoder_callbacks_->sendLocalReply(401, "Unauthorized");
            }
            return FilterHeadersStatus::StopIteration;
        }

        if (auth.find("Bearer ") != 0 || auth.length() < 15) {
            std::cout << "[Auth] Invalid token\n";
            if (decoder_callbacks_) {
                decoder_callbacks_->sendLocalReply(403, "Forbidden");
            }
            return FilterHeadersStatus::StopIteration;
        }

        std::cout << "[Auth] Authenticated\n";
        headers.addHeader("X-User-Id", auth.substr(7, 8));
        return FilterHeadersStatus::Continue;
    }
};

/**
 * CORS Filter
 */
class CorsFilter : public StreamFilter {
public:
    FilterHeadersStatus decodeHeaders(RequestHeaderMap& headers,
                                      bool end_stream) override {
        origin_ = headers.getHeader("Origin");
        return FilterHeadersStatus::Continue;
    }

    FilterHeadersStatus encodeHeaders(ResponseHeaderMap& headers,
                                      bool end_stream) override {
        if (!origin_.empty()) {
            headers.addHeader("Access-Control-Allow-Origin", origin_);
            headers.addHeader("Access-Control-Allow-Methods",
                            "GET, POST, PUT, DELETE");
            std::cout << "[CORS] Added headers for: " << origin_ << "\n";
        }
        return FilterHeadersStatus::Continue;
    }

private:
    std::string origin_;
};

/**
 * 请求日志Filter
 */
class RequestLoggingFilter : public StreamFilter {
public:
    FilterHeadersStatus decodeHeaders(RequestHeaderMap& headers,
                                      bool end_stream) override {
        start_time_ = std::chrono::steady_clock::now();
        method_ = headers.getHeader(":method");
        path_ = headers.getHeader(":path");
        std::cout << "[Log] " << method_ << " " << path_ << "\n";
        return FilterHeadersStatus::Continue;
    }

    void encodeComplete() override {
        auto end = std::chrono::steady_clock::now();
        auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
            end - start_time_).count();
        std::cout << "[Log] " << method_ << " " << path_
                  << " completed in " << ms << "ms\n";
    }

private:
    std::chrono::steady_clock::time_point start_time_;
    std::string method_, path_;
};

} // namespace envoy_study
```

---

### Day 19-21：Filter Chain实战（15小时）

#### FilterManager架构

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    FilterManager 架构                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                       FilterManager                                  │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                     │   │
│  │  ┌───────────────────────────────────────────────────────────────┐ │   │
│  │  │                    Filter Chain                                │ │   │
│  │  │  ┌────────┐   ┌────────┐   ┌────────┐   ┌────────┐           │ │   │
│  │  │  │Filter 1│ ─▶│Filter 2│ ─▶│Filter 3│ ─▶│ Router │           │ │   │
│  │  │  └────────┘   └────────┘   └────────┘   └────────┘           │ │   │
│  │  └───────────────────────────────────────────────────────────────┘ │   │
│  │                                                                     │   │
│  │  状态管理：                                                         │   │
│  │  • current_filter_index_ - 当前执行的Filter索引                    │   │
│  │  • state_ - 当前状态（Decoding/Encoding/Complete）                 │   │
│  │  • stopped_ - 是否被Filter停止                                     │   │
│  │                                                                     │   │
│  │  核心方法：                                                         │   │
│  │  • addFilter() - 添加Filter到链中                                  │   │
│  │  • decodeHeaders/Data/Trailers() - 处理请求                        │   │
│  │  • encodeHeaders/Data/Trailers() - 处理响应                        │   │
│  │  • continueDecoding/Encoding() - 恢复被停止的处理                  │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 代码示例：FilterManager实现

```cpp
// filter_manager.hpp - Filter链管理器
#pragma once

#include <vector>
#include <memory>
#include <functional>
#include <iostream>

namespace envoy_study {

/**
 * Filter工厂接口
 */
class FilterFactory {
public:
    virtual ~FilterFactory() = default;
    virtual std::unique_ptr<StreamFilter> createFilter() = 0;
    virtual std::string name() const = 0;
};

/**
 * FilterManager状态
 */
enum class FilterManagerState {
    Idle,
    DecodingHeaders,
    DecodingData,
    DecodingTrailers,
    EncodingHeaders,
    EncodingData,
    EncodingTrailers,
    Complete
};

/**
 * FilterManager - 管理Filter链的执行
 */
class FilterManager : public StreamDecoderFilterCallbacks {
public:
    FilterManager() : state_(FilterManagerState::Idle) {}

    // 添加Filter
    void addFilter(std::unique_ptr<StreamFilter> filter) {
        filter->setDecoderFilterCallbacks(*this);
        filters_.push_back(std::move(filter));
    }

    // 使用工厂创建并添加Filter
    void addFilter(FilterFactory& factory) {
        auto filter = factory.createFilter();
        std::cout << "[FilterManager] Added filter: " << factory.name() << "\n";
        addFilter(std::move(filter));
    }

    // 处理请求头
    bool decodeHeaders(RequestHeaderMap& headers, bool end_stream) {
        state_ = FilterManagerState::DecodingHeaders;
        current_filter_index_ = 0;

        while (current_filter_index_ < filters_.size()) {
            auto& filter = filters_[current_filter_index_];
            auto status = filter->decodeHeaders(headers, end_stream);

            if (status == FilterHeadersStatus::StopIteration ||
                status == FilterHeadersStatus::StopAllIterationAndBuffer) {
                stopped_ = true;
                std::cout << "[FilterManager] Filter " << current_filter_index_
                          << " stopped decoding\n";
                return false;
            }

            current_filter_index_++;
        }

        return true;
    }

    // 处理请求体
    bool decodeData(Buffer& data, bool end_stream) {
        state_ = FilterManagerState::DecodingData;

        while (current_filter_index_ < filters_.size()) {
            auto& filter = filters_[current_filter_index_];
            auto status = filter->decodeData(data, end_stream);

            if (status == FilterDataStatus::StopIterationAndBuffer ||
                status == FilterDataStatus::StopIterationNoBuffer) {
                stopped_ = true;
                return false;
            }

            current_filter_index_++;
        }

        return true;
    }

    // 处理响应头
    bool encodeHeaders(ResponseHeaderMap& headers, bool end_stream) {
        state_ = FilterManagerState::EncodingHeaders;

        // 响应是反向遍历
        for (int i = filters_.size() - 1; i >= 0; --i) {
            auto& filter = filters_[i];
            auto status = filter->encodeHeaders(headers, end_stream);

            if (status == FilterHeadersStatus::StopIteration) {
                stopped_ = true;
                current_filter_index_ = i;
                return false;
            }
        }

        return true;
    }

    // 处理响应体
    bool encodeData(Buffer& data, bool end_stream) {
        state_ = FilterManagerState::EncodingData;

        for (int i = filters_.size() - 1; i >= 0; --i) {
            auto& filter = filters_[i];
            auto status = filter->encodeData(data, end_stream);

            if (status == FilterDataStatus::StopIterationAndBuffer) {
                stopped_ = true;
                current_filter_index_ = i;
                return false;
            }
        }

        return true;
    }

    // 完成编码
    void encodeComplete() {
        state_ = FilterManagerState::Complete;
        for (auto& filter : filters_) {
            filter->encodeComplete();
        }
    }

    // StreamDecoderFilterCallbacks实现
    void continueDecoding() override {
        if (!stopped_) return;
        stopped_ = false;
        current_filter_index_++;
        std::cout << "[FilterManager] Continuing decoding from filter "
                  << current_filter_index_ << "\n";
    }

    void sendLocalReply(int status_code, const std::string& body) override {
        std::cout << "[FilterManager] Sending local reply: "
                  << status_code << " - " << body << "\n";
        local_reply_sent_ = true;
    }

    bool localReplySent() const { return local_reply_sent_; }
    size_t filterCount() const { return filters_.size(); }

private:
    std::vector<std::unique_ptr<StreamFilter>> filters_;
    FilterManagerState state_;
    size_t current_filter_index_ = 0;
    bool stopped_ = false;
    bool local_reply_sent_ = false;
};

/**
 * HTTP连接管理器（简化版）
 */
class HttpConnectionManager {
public:
    HttpConnectionManager() {
        // 添加默认Filter
        filter_manager_.addFilter(std::make_unique<RequestLoggingFilter>());
        filter_manager_.addFilter(std::make_unique<CorsFilter>());
    }

    void addFilter(std::unique_ptr<StreamFilter> filter) {
        filter_manager_.addFilter(std::move(filter));
    }

    // 处理请求
    void handleRequest(RequestHeaderMap& request_headers,
                      Buffer& request_body,
                      ResponseHeaderMap& response_headers,
                      Buffer& response_body) {
        std::cout << "\n=== Processing Request ===\n";

        // 解码请求头
        if (!filter_manager_.decodeHeaders(request_headers, false)) {
            if (filter_manager_.localReplySent()) {
                std::cout << "Request rejected by filter\n";
                return;
            }
        }

        // 解码请求体
        filter_manager_.decodeData(request_body, true);

        // 模拟上游响应
        response_headers.addHeader(":status", "200");
        response_body.add("Hello, World!");

        // 编码响应
        filter_manager_.encodeHeaders(response_headers, false);
        filter_manager_.encodeData(response_body, true);
        filter_manager_.encodeComplete();

        std::cout << "=== Request Complete ===\n\n";
    }

private:
    FilterManager filter_manager_;
};

/**
 * 使用示例
 */
inline void filterManagerExample() {
    std::cout << "=== Filter Manager Example ===\n";

    HttpConnectionManager hcm;

    // 添加认证Filter
    hcm.addFilter(std::make_unique<AuthenticationFilter>());

    // 模拟请求
    RequestHeaderMap req_headers;
    req_headers.addHeader(":method", "GET");
    req_headers.addHeader(":path", "/api/users");
    req_headers.addHeader("Origin", "https://example.com");
    req_headers.addHeader("Authorization", "Bearer abc12345678token");

    Buffer req_body;
    ResponseHeaderMap resp_headers;
    Buffer resp_body;

    hcm.handleRequest(req_headers, req_body, resp_headers, resp_body);
}

} // namespace envoy_study
```

---

### 第三周自测问题

完成第三周学习后，请尝试回答以下问题：

**理论理解：**
1. Network Filter和HTTP Filter的区别是什么？
2. Filter Chain是如何组织和执行的？
3. Filter的返回状态有哪些？各自代表什么含义？
4. 什么情况下Filter会停止链的执行？
5. 请求和响应的Filter执行顺序有什么不同？

**代码实践：**
1. 实现一个自定义的日志Filter
2. 实现一个简单的认证Filter
3. 实现FilterManager来管理Filter链
4. 实现一个CORS Filter
5. 组装完整的Filter链并测试

---

### 第三周检验标准

| 检验项 | 标准 | 自评 |
|--------|------|------|
| 理解Filter架构 | 能解释Network/HTTP Filter区别 | ☐ |
| 理解Filter接口 | 能描述Decoder/Encoder接口 | ☐ |
| 理解状态控制 | 能解释各种返回状态的作用 | ☐ |
| 实现Network Filter | 代码能正确处理连接数据 | ☐ |
| 实现HTTP Filter | 代码能正确处理HTTP请求/响应 | ☐ |
| 实现FilterManager | 代码能正确管理Filter链执行 | ☐ |

---

### 第三周时间分配

| 内容 | 时间 |
|------|------|
| Network Filter原理 | 5小时 |
| Network Filter实现 | 5小时 |
| HTTP Filter原理 | 5小时 |
| HTTP Filter实现 | 5小时 |
| FilterManager设计 | 5小时 |
| Filter链实战 | 10小时 |

---

## 第四周：配置热更新与xDS（Day 22-28）

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    第四周学习路线图                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Day 22-23            Day 24-25            Day 26-28                      │
│   ┌─────────┐         ┌─────────┐          ┌─────────┐                     │
│   │  xDS    │         │ 配置    │          │ Mini-   │                     │
│   │ 协议    │────────▶│ 热更新  │─────────▶│ Envoy   │                     │
│   │ 详解    │         │ 机制    │          │ 实战    │                     │
│   └─────────┘         └─────────┘          └─────────┘                     │
│       │                   │                    │                           │
│       ▼                   ▼                    ▼                           │
│   LDS/RDS/CDS/EDS      Drain机制            完整代理                        │
│   gRPC双向流            版本管理            框架实现                        │
│                                                                             │
│   学习目标：理解动态配置机制，实现简化版Envoy代理                            │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Day 22-23：xDS协议详解（10小时）

#### xDS协议族概览

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    xDS 协议族                                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                     控制平面 (Control Plane)                         │   │
│  │                      例如：Istio Pilot                               │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                     xDS (gRPC 双向流)                                       │
│                              │                                              │
│     ┌────────────────────────┼────────────────────────┐                    │
│     │                        │                        │                    │
│     ▼                        ▼                        ▼                    │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐               │
│  │    LDS       │     │    RDS       │     │    CDS       │               │
│  │  Listener    │     │   Route      │     │  Cluster     │               │
│  │  Discovery   │     │  Discovery   │     │  Discovery   │               │
│  │  Service     │     │  Service     │     │  Service     │               │
│  └──────────────┘     └──────────────┘     └──────────────┘               │
│         │                    │                    │                        │
│         ▼                    ▼                    ▼                        │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐               │
│  │  EDS         │     │   SDS        │     │   ECDS       │               │
│  │  Endpoint    │     │  Secret      │     │  Extension   │               │
│  │  Discovery   │     │  Discovery   │     │  Config      │               │
│  │  Service     │     │  Service     │     │  Discovery   │               │
│  └──────────────┘     └──────────────┘     └──────────────┘               │
│                                                                             │
│  xDS协议说明：                                                              │
│  • LDS: 监听器配置（端口、协议、过滤器链）                                  │
│  • RDS: 路由配置（虚拟主机、路由规则）                                      │
│  • CDS: 集群配置（负载均衡、连接池）                                        │
│  • EDS: 端点配置（服务实例IP:Port）                                         │
│  • SDS: 密钥配置（TLS证书）                                                │
│  • ECDS: 扩展配置（Filter扩展）                                            │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### xDS订阅模式

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    xDS 订阅模式                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. State of the World (SotW) - 全量模式                                    │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                                                                      │  │
│  │   Client                              Server                         │  │
│  │     │                                    │                           │  │
│  │     │──── DiscoveryRequest ─────────────▶│                           │  │
│  │     │     (resource_names: [])           │                           │  │
│  │     │                                    │                           │  │
│  │     │◀─── DiscoveryResponse ─────────────│                           │  │
│  │     │     (所有资源的完整列表)            │                           │  │
│  │     │                                    │                           │  │
│  │     │──── ACK (version_info) ────────────▶│                           │  │
│  │     │                                    │                           │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  2. Incremental (Delta) xDS - 增量模式                                      │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                                                                      │  │
│  │   Client                              Server                         │  │
│  │     │                                    │                           │  │
│  │     │──── DeltaDiscoveryRequest ─────────▶│                           │  │
│  │     │     (subscribe: ["cluster-a"])     │                           │  │
│  │     │                                    │                           │  │
│  │     │◀─── DeltaDiscoveryResponse ─────────│                           │  │
│  │     │     (只包含变化的资源)              │                           │  │
│  │     │     (removed_resources: [...])     │                           │  │
│  │     │                                    │                           │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  3. ADS (Aggregated Discovery Service) - 聚合模式                          │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                                                                      │  │
│  │   • 所有xDS类型通过单个gRPC流传输                                     │  │
│  │   • 保证配置更新的顺序性                                              │  │
│  │   • 避免配置不一致问题                                                │  │
│  │                                                                      │  │
│  │   单个gRPC流:                                                        │  │
│  │   ┌─────────────────────────────────────────────────────────────┐   │  │
│  │   │ LDS → CDS → EDS → RDS (按依赖顺序更新)                       │   │  │
│  │   └─────────────────────────────────────────────────────────────┘   │  │
│  │                                                                      │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 代码示例：xDS客户端实现

```cpp
// xds_client.hpp - xDS客户端实现
#pragma once

#include <string>
#include <vector>
#include <map>
#include <memory>
#include <functional>
#include <mutex>
#include <thread>
#include <atomic>
#include <iostream>

namespace envoy_study {

/**
 * xDS资源类型
 */
enum class XdsResourceType {
    Listener,   // LDS
    Route,      // RDS
    Cluster,    // CDS
    Endpoint,   // EDS
    Secret      // SDS
};

inline std::string resourceTypeToString(XdsResourceType type) {
    switch (type) {
        case XdsResourceType::Listener: return "type.googleapis.com/envoy.config.listener.v3.Listener";
        case XdsResourceType::Route: return "type.googleapis.com/envoy.config.route.v3.RouteConfiguration";
        case XdsResourceType::Cluster: return "type.googleapis.com/envoy.config.cluster.v3.Cluster";
        case XdsResourceType::Endpoint: return "type.googleapis.com/envoy.config.endpoint.v3.ClusterLoadAssignment";
        case XdsResourceType::Secret: return "type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.Secret";
    }
    return "";
}

/**
 * xDS请求
 */
struct DiscoveryRequest {
    std::string version_info;          // 当前版本
    std::string type_url;              // 资源类型
    std::vector<std::string> resource_names;  // 订阅的资源名
    std::string response_nonce;        // 上次响应的nonce
    std::string error_detail;          // 错误信息（NACK时使用）
    std::string node_id;               // 节点ID
};

/**
 * xDS响应
 */
struct DiscoveryResponse {
    std::string version_info;          // 新版本
    std::string type_url;              // 资源类型
    std::vector<std::string> resources;  // 资源列表（序列化的protobuf）
    std::string nonce;                 // 响应nonce
};

/**
 * xDS资源更新回调
 */
using XdsCallback = std::function<void(XdsResourceType type,
                                        const std::vector<std::string>& resources,
                                        const std::string& version)>;

/**
 * xDS订阅状态
 */
struct SubscriptionState {
    std::string version_info;
    std::string nonce;
    std::vector<std::string> resource_names;
    bool initial_fetch_complete = false;
};

/**
 * xDS客户端
 */
class XdsClient {
public:
    XdsClient(const std::string& server_address, const std::string& node_id)
        : server_address_(server_address)
        , node_id_(node_id)
        , running_(false) {}

    ~XdsClient() { stop(); }

    // 订阅资源
    void subscribe(XdsResourceType type,
                  const std::vector<std::string>& resources,
                  XdsCallback callback) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto& state = subscriptions_[type];
        state.resource_names = resources;
        callbacks_[type] = std::move(callback);

        std::cout << "[xDS] Subscribed to " << resourceTypeToString(type)
                  << " resources: ";
        for (const auto& r : resources) std::cout << r << " ";
        std::cout << "\n";

        // 发送初始请求
        sendDiscoveryRequest(type);
    }

    // 启动客户端
    void start() {
        running_ = true;
        worker_thread_ = std::thread([this]() {
            while (running_) {
                // 模拟接收xDS更新
                receiveUpdates();
                std::this_thread::sleep_for(std::chrono::seconds(1));
            }
        });
    }

    void stop() {
        running_ = false;
        if (worker_thread_.joinable()) {
            worker_thread_.join();
        }
    }

    // 模拟接收配置更新
    void simulateUpdate(XdsResourceType type,
                       const std::vector<std::string>& resources,
                       const std::string& version) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = subscriptions_.find(type);
        if (it == subscriptions_.end()) return;

        auto& state = it->second;

        // 检查版本是否更新
        if (version == state.version_info) {
            std::cout << "[xDS] Version unchanged, skipping\n";
            return;
        }

        std::cout << "[xDS] Received update for " << resourceTypeToString(type)
                  << " version: " << version << "\n";

        // 更新状态
        state.version_info = version;
        state.initial_fetch_complete = true;

        // 调用回调
        auto cb_it = callbacks_.find(type);
        if (cb_it != callbacks_.end()) {
            cb_it->second(type, resources, version);
        }

        // 发送ACK
        sendAck(type, version);
    }

private:
    void sendDiscoveryRequest(XdsResourceType type) {
        DiscoveryRequest request;
        request.node_id = node_id_;
        request.type_url = resourceTypeToString(type);

        auto it = subscriptions_.find(type);
        if (it != subscriptions_.end()) {
            request.version_info = it->second.version_info;
            request.response_nonce = it->second.nonce;
            request.resource_names = it->second.resource_names;
        }

        std::cout << "[xDS] Sending DiscoveryRequest for " << request.type_url
                  << " version: " << request.version_info << "\n";
    }

    void sendAck(XdsResourceType type, const std::string& version) {
        std::cout << "[xDS] Sending ACK for " << resourceTypeToString(type)
                  << " version: " << version << "\n";
    }

    void receiveUpdates() {
        // 在实际实现中，这里会从gRPC流接收数据
    }

    std::string server_address_;
    std::string node_id_;
    std::atomic<bool> running_;
    std::thread worker_thread_;

    std::mutex mutex_;
    std::map<XdsResourceType, SubscriptionState> subscriptions_;
    std::map<XdsResourceType, XdsCallback> callbacks_;
};

} // namespace envoy_study
```

---

### Day 24-25：配置热更新机制（10小时）

#### Drain机制

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Drain（优雅关闭）机制                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  配置更新时的连接处理：                                                      │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                                                                      │  │
│  │    旧配置                             新配置                          │  │
│  │    ┌───────────────────┐             ┌───────────────────┐           │  │
│  │    │                   │             │                   │           │  │
│  │    │ 活跃连接          │             │ 新连接            │           │  │
│  │    │ conn1, conn2, ... │─── Drain ──▶│ conn3, conn4, ... │           │  │
│  │    │                   │   Period    │                   │           │  │
│  │    │                   │             │                   │           │  │
│  │    └───────────────────┘             └───────────────────┘           │  │
│  │           │                                   │                      │  │
│  │           ▼                                   ▼                      │  │
│  │    • 停止接受新连接                    • 接受新连接                  │  │
│  │    • 等待现有连接完成                  • 使用新配置                  │  │
│  │    • 超时后强制关闭                    • 正常处理请求                │  │
│  │                                                                      │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  Drain时间线：                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                                                                      │  │
│  │  t=0         t=drain_timeout                                        │  │
│  │   │                │                                                │  │
│  │   ├────────────────┤                                                │  │
│  │   │                │                                                │  │
│  │   ▼                ▼                                                │  │
│  │  开始Drain      强制关闭                                             │  │
│  │  停止新连接     所有连接                                             │  │
│  │                                                                      │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 代码示例：配置管理器实现

```cpp
// config_manager.hpp - 配置热更新管理器
#pragma once

#include <string>
#include <memory>
#include <mutex>
#include <atomic>
#include <vector>
#include <functional>
#include <chrono>
#include <iostream>

namespace envoy_study {

/**
 * 配置版本
 */
struct ConfigVersion {
    uint64_t version;
    std::chrono::steady_clock::time_point timestamp;

    bool operator<(const ConfigVersion& other) const {
        return version < other.version;
    }
};

/**
 * 监听器配置
 */
struct ListenerConfig {
    std::string name;
    std::string address;
    uint16_t port;
    std::vector<std::string> filter_chain;
    ConfigVersion version;
};

/**
 * 集群配置
 */
struct ClusterConfig {
    std::string name;
    std::string lb_policy;  // round_robin, least_request, etc.
    std::vector<std::string> endpoints;
    uint32_t connect_timeout_ms;
    ConfigVersion version;
};

/**
 * 完整配置
 */
struct FullConfig {
    std::vector<ListenerConfig> listeners;
    std::vector<ClusterConfig> clusters;
    ConfigVersion version;
};

/**
 * 配置更新监听器
 */
class ConfigUpdateListener {
public:
    virtual ~ConfigUpdateListener() = default;
    virtual void onListenerUpdate(const ListenerConfig& config) = 0;
    virtual void onClusterUpdate(const ClusterConfig& config) = 0;
    virtual void onConfigUpdateComplete(const ConfigVersion& version) = 0;
};

/**
 * 配置管理器
 */
class ConfigManager {
public:
    ConfigManager() : current_version_{0, std::chrono::steady_clock::now()} {}

    // 添加配置更新监听器
    void addListener(ConfigUpdateListener* listener) {
        std::lock_guard<std::mutex> lock(mutex_);
        listeners_.push_back(listener);
    }

    // 应用新配置
    void applyConfig(const FullConfig& new_config) {
        std::lock_guard<std::mutex> lock(mutex_);

        if (new_config.version < current_version_) {
            std::cout << "[ConfigManager] Ignoring older config version\n";
            return;
        }

        std::cout << "[ConfigManager] Applying config version "
                  << new_config.version.version << "\n";

        // 更新监听器配置
        for (const auto& listener : new_config.listeners) {
            std::cout << "[ConfigManager] Updating listener: " << listener.name
                      << " on " << listener.address << ":" << listener.port << "\n";

            for (auto* l : listeners_) {
                l->onListenerUpdate(listener);
            }
        }

        // 更新集群配置
        for (const auto& cluster : new_config.clusters) {
            std::cout << "[ConfigManager] Updating cluster: " << cluster.name
                      << " with " << cluster.endpoints.size() << " endpoints\n";

            for (auto* l : listeners_) {
                l->onClusterUpdate(cluster);
            }
        }

        // 更新版本
        current_version_ = new_config.version;
        current_config_ = new_config;

        // 通知更新完成
        for (auto* l : listeners_) {
            l->onConfigUpdateComplete(current_version_);
        }
    }

    // 获取当前配置
    FullConfig getCurrentConfig() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return current_config_;
    }

    // 获取当前版本
    ConfigVersion getCurrentVersion() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return current_version_;
    }

private:
    mutable std::mutex mutex_;
    ConfigVersion current_version_;
    FullConfig current_config_;
    std::vector<ConfigUpdateListener*> listeners_;
};

/**
 * Drain管理器
 */
class DrainManager {
public:
    DrainManager(std::chrono::milliseconds drain_timeout)
        : drain_timeout_(drain_timeout)
        , draining_(false) {}

    // 开始Drain
    void startDrain() {
        draining_ = true;
        drain_start_ = std::chrono::steady_clock::now();
        std::cout << "[DrainManager] Starting drain, timeout: "
                  << drain_timeout_.count() << "ms\n";
    }

    // 检查是否在Drain中
    bool isDraining() const { return draining_; }

    // 检查Drain是否超时
    bool isDrainComplete() const {
        if (!draining_) return true;

        auto elapsed = std::chrono::steady_clock::now() - drain_start_;
        return elapsed >= drain_timeout_;
    }

    // 完成Drain
    void completeDrain() {
        draining_ = false;
        std::cout << "[DrainManager] Drain complete\n";
    }

    // 注册连接（Drain时跟踪活跃连接）
    void registerConnection(uint64_t conn_id) {
        std::lock_guard<std::mutex> lock(mutex_);
        active_connections_.insert(conn_id);
    }

    // 注销连接
    void unregisterConnection(uint64_t conn_id) {
        std::lock_guard<std::mutex> lock(mutex_);
        active_connections_.erase(conn_id);

        if (draining_ && active_connections_.empty()) {
            std::cout << "[DrainManager] All connections closed\n";
            completeDrain();
        }
    }

    size_t activeConnectionCount() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return active_connections_.size();
    }

private:
    std::chrono::milliseconds drain_timeout_;
    std::atomic<bool> draining_;
    std::chrono::steady_clock::time_point drain_start_;

    mutable std::mutex mutex_;
    std::set<uint64_t> active_connections_;
};

} // namespace envoy_study
```

---

### Day 26-28：Mini-Envoy代理服务器实战（15小时）

#### Mini-Envoy架构

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Mini-Envoy 架构                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                       Mini-Envoy Server                              │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                     │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │                      Main Thread                             │   │   │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │   │   │
│  │  │  │   Config    │  │    xDS      │  │   Admin     │         │   │   │
│  │  │  │   Manager   │  │   Client    │  │   Server    │         │   │   │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘         │   │   │
│  │  └─────────────────────────────────────────────────────────────┘   │   │
│  │                              │                                      │   │
│  │                    TLS Config Update                                │   │
│  │                              │                                      │   │
│  │       ┌──────────────────────┼──────────────────────┐              │   │
│  │       │                      │                      │              │   │
│  │       ▼                      ▼                      ▼              │   │
│  │  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐       │   │
│  │  │  Worker 0    │     │  Worker 1    │     │  Worker N    │       │   │
│  │  │ ┌──────────┐ │     │ ┌──────────┐ │     │ ┌──────────┐ │       │   │
│  │  │ │Dispatcher│ │     │ │Dispatcher│ │     │ │Dispatcher│ │       │   │
│  │  │ ├──────────┤ │     │ ├──────────┤ │     │ ├──────────┤ │       │   │
│  │  │ │Listeners │ │     │ │Listeners │ │     │ │Listeners │ │       │   │
│  │  │ ├──────────┤ │     │ ├──────────┤ │     │ ├──────────┤ │       │   │
│  │  │ │FilterMgr │ │     │ │FilterMgr │ │     │ │FilterMgr │ │       │   │
│  │  │ ├──────────┤ │     │ ├──────────┤ │     │ ├──────────┤ │       │   │
│  │  │ │ClusterMgr│ │     │ │ClusterMgr│ │     │ │ClusterMgr│ │       │   │
│  │  │ └──────────┘ │     │ └──────────┘ │     │ └──────────┘ │       │   │
│  │  └──────────────┘     └──────────────┘     └──────────────┘       │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 代码示例：Mini-Envoy实现

```cpp
// mini_envoy.hpp - 简化版Envoy代理服务器
#pragma once

#include <string>
#include <memory>
#include <vector>
#include <map>
#include <thread>
#include <atomic>
#include <mutex>
#include <functional>
#include <iostream>

namespace envoy_study {

/**
 * 连接信息
 */
struct ConnectionInfo {
    uint64_t id;
    std::string remote_address;
    uint16_t remote_port;
    std::chrono::steady_clock::time_point connected_at;
};

/**
 * 上游连接池
 */
class ConnectionPool {
public:
    explicit ConnectionPool(const std::string& cluster_name)
        : cluster_name_(cluster_name) {}

    // 获取连接（简化实现）
    bool getConnection(const std::string& endpoint) {
        std::lock_guard<std::mutex> lock(mutex_);

        // 检查是否有空闲连接
        auto it = idle_connections_.find(endpoint);
        if (it != idle_connections_.end() && !it->second.empty()) {
            auto conn = it->second.back();
            it->second.pop_back();
            active_connections_[endpoint].push_back(conn);
            std::cout << "[Pool] Reused connection to " << endpoint << "\n";
            return true;
        }

        // 创建新连接
        uint64_t conn_id = next_conn_id_++;
        active_connections_[endpoint].push_back(conn_id);
        std::cout << "[Pool] Created new connection " << conn_id
                  << " to " << endpoint << "\n";
        return true;
    }

    // 释放连接
    void releaseConnection(const std::string& endpoint, uint64_t conn_id) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto& active = active_connections_[endpoint];
        active.erase(std::remove(active.begin(), active.end(), conn_id),
                    active.end());

        idle_connections_[endpoint].push_back(conn_id);
        std::cout << "[Pool] Released connection " << conn_id << "\n";
    }

    size_t activeCount() const {
        std::lock_guard<std::mutex> lock(mutex_);
        size_t count = 0;
        for (const auto& [_, conns] : active_connections_) {
            count += conns.size();
        }
        return count;
    }

private:
    std::string cluster_name_;
    mutable std::mutex mutex_;
    std::atomic<uint64_t> next_conn_id_{1};

    std::map<std::string, std::vector<uint64_t>> idle_connections_;
    std::map<std::string, std::vector<uint64_t>> active_connections_;
};

/**
 * 集群管理器
 */
class ClusterManager {
public:
    // 添加集群
    void addCluster(const ClusterConfig& config) {
        std::lock_guard<std::mutex> lock(mutex_);

        clusters_[config.name] = config;
        pools_[config.name] = std::make_unique<ConnectionPool>(config.name);

        std::cout << "[ClusterManager] Added cluster: " << config.name << "\n";
    }

    // 获取集群配置
    ClusterConfig* getCluster(const std::string& name) {
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = clusters_.find(name);
        return it != clusters_.end() ? &it->second : nullptr;
    }

    // 选择端点（简单轮询）
    std::string selectEndpoint(const std::string& cluster_name) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = clusters_.find(cluster_name);
        if (it == clusters_.end() || it->second.endpoints.empty()) {
            return "";
        }

        auto& endpoints = it->second.endpoints;
        size_t& index = rr_index_[cluster_name];
        std::string endpoint = endpoints[index % endpoints.size()];
        index++;

        return endpoint;
    }

    // 获取连接池
    ConnectionPool* getPool(const std::string& cluster_name) {
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = pools_.find(cluster_name);
        return it != pools_.end() ? it->second.get() : nullptr;
    }

private:
    mutable std::mutex mutex_;
    std::map<std::string, ClusterConfig> clusters_;
    std::map<std::string, std::unique_ptr<ConnectionPool>> pools_;
    std::map<std::string, size_t> rr_index_;
};

/**
 * Mini-Envoy Worker
 */
class MiniEnvoyWorker {
public:
    MiniEnvoyWorker(uint32_t id, ClusterManager& cluster_manager)
        : id_(id)
        , cluster_manager_(cluster_manager)
        , running_(false) {}

    void start() {
        running_ = true;
        thread_ = std::thread([this]() {
            std::cout << "[Worker " << id_ << "] Started\n";
            while (running_) {
                processEvents();
                std::this_thread::sleep_for(std::chrono::milliseconds(10));
            }
        });
    }

    void stop() {
        running_ = false;
        if (thread_.joinable()) thread_.join();
    }

    void handleConnection(const ConnectionInfo& conn) {
        std::lock_guard<std::mutex> lock(mutex_);
        connections_.push_back(conn);
        std::cout << "[Worker " << id_ << "] New connection from "
                  << conn.remote_address << ":" << conn.remote_port << "\n";
    }

    // 处理HTTP请求（简化版）
    void handleRequest(const std::string& path, const std::string& cluster) {
        std::cout << "[Worker " << id_ << "] Handling request: " << path
                  << " -> cluster: " << cluster << "\n";

        // 选择上游端点
        std::string endpoint = cluster_manager_.selectEndpoint(cluster);
        if (endpoint.empty()) {
            std::cout << "[Worker " << id_ << "] No endpoints available\n";
            return;
        }

        // 获取连接
        auto* pool = cluster_manager_.getPool(cluster);
        if (pool && pool->getConnection(endpoint)) {
            std::cout << "[Worker " << id_ << "] Forwarding to " << endpoint << "\n";
            // 模拟请求转发...
            pool->releaseConnection(endpoint, 1);
        }
    }

    size_t connectionCount() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return connections_.size();
    }

private:
    void processEvents() {
        // 在实际实现中，这里会处理Dispatcher事件
    }

    uint32_t id_;
    ClusterManager& cluster_manager_;
    std::atomic<bool> running_;
    std::thread thread_;

    mutable std::mutex mutex_;
    std::vector<ConnectionInfo> connections_;
};

/**
 * Mini-Envoy Server
 */
class MiniEnvoyServer {
public:
    struct Config {
        uint32_t num_workers = 4;
        std::chrono::milliseconds drain_timeout{5000};
    };

    explicit MiniEnvoyServer(const Config& config)
        : config_(config)
        , drain_manager_(config.drain_timeout)
        , running_(false) {}

    // 启动服务器
    void start() {
        running_ = true;

        // 创建Worker线程
        for (uint32_t i = 0; i < config_.num_workers; ++i) {
            auto worker = std::make_unique<MiniEnvoyWorker>(i, cluster_manager_);
            worker->start();
            workers_.push_back(std::move(worker));
        }

        std::cout << "[MiniEnvoy] Server started with "
                  << config_.num_workers << " workers\n";
    }

    // 停止服务器
    void stop() {
        std::cout << "[MiniEnvoy] Stopping server...\n";

        // 开始Drain
        drain_manager_.startDrain();

        // 等待Drain完成或超时
        while (!drain_manager_.isDrainComplete()) {
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
        }

        // 停止所有Worker
        for (auto& worker : workers_) {
            worker->stop();
        }
        workers_.clear();

        running_ = false;
        std::cout << "[MiniEnvoy] Server stopped\n";
    }

    // 添加集群
    void addCluster(const ClusterConfig& config) {
        cluster_manager_.addCluster(config);
    }

    // 应用配置更新
    void applyConfig(const FullConfig& config) {
        std::cout << "[MiniEnvoy] Applying config version "
                  << config.version.version << "\n";

        // 更新集群
        for (const auto& cluster : config.clusters) {
            cluster_manager_.addCluster(cluster);
        }
    }

    // 获取统计信息
    void printStats() {
        std::cout << "\n=== Mini-Envoy Stats ===\n";
        std::cout << "Workers: " << workers_.size() << "\n";
        for (size_t i = 0; i < workers_.size(); ++i) {
            std::cout << "  Worker " << i << " connections: "
                      << workers_[i]->connectionCount() << "\n";
        }
        std::cout << "========================\n\n";
    }

    // 选择Worker（简单轮询）
    MiniEnvoyWorker& selectWorker() {
        size_t index = next_worker_++ % workers_.size();
        return *workers_[index];
    }

private:
    Config config_;
    DrainManager drain_manager_;
    ClusterManager cluster_manager_;
    std::vector<std::unique_ptr<MiniEnvoyWorker>> workers_;
    std::atomic<bool> running_;
    std::atomic<size_t> next_worker_{0};
};

/**
 * Mini-Envoy使用示例
 */
inline void miniEnvoyExample() {
    std::cout << "=== Mini-Envoy Example ===\n\n";

    // 配置服务器
    MiniEnvoyServer::Config config;
    config.num_workers = 2;

    MiniEnvoyServer server(config);

    // 添加集群配置
    ClusterConfig user_service;
    user_service.name = "user-service";
    user_service.lb_policy = "round_robin";
    user_service.endpoints = {"10.0.0.1:8080", "10.0.0.2:8080"};
    user_service.connect_timeout_ms = 5000;

    server.addCluster(user_service);

    // 启动服务器
    server.start();

    // 模拟处理请求
    auto& worker = server.selectWorker();
    worker.handleRequest("/api/users/123", "user-service");

    // 打印统计
    server.printStats();

    // 停止服务器
    server.stop();
}

} // namespace envoy_study
```

---

### 第四周自测问题

完成第四周学习后，请尝试回答以下问题：

**理论理解：**
1. xDS协议族包含哪些协议？各自的作用是什么？
2. SotW和Delta xDS的区别是什么？
3. ADS的优势是什么？
4. Drain机制是如何保证配置更新不丢失连接的？
5. 配置版本管理的作用是什么？

**代码实践：**
1. 实现xDS客户端订阅机制
2. 实现配置版本管理
3. 实现Drain管理器
4. 实现简化版ClusterManager
5. 组装完整的Mini-Envoy服务器

---

### 第四周检验标准

| 检验项 | 标准 | 自评 |
|--------|------|------|
| 理解xDS协议 | 能解释各xDS类型的作用 | ☐ |
| 理解订阅模式 | 能比较SotW/Delta/ADS | ☐ |
| 理解Drain机制 | 能描述优雅关闭流程 | ☐ |
| 实现xDS客户端 | 代码能订阅和接收配置 | ☐ |
| 实现配置管理器 | 代码能正确管理配置版本 | ☐ |
| 实现Mini-Envoy | 代码能完成基本代理功能 | ☐ |

---

### 第四周时间分配

| 内容 | 时间 |
|------|------|
| xDS协议学习 | 5小时 |
| xDS客户端实现 | 5小时 |
| Drain机制理解 | 3小时 |
| 配置管理器实现 | 4小时 |
| Mini-Envoy设计 | 5小时 |
| Mini-Envoy实现 | 8小时 |
| 测试与调优 | 5小时 |

---

## 本月检验标准汇总

### 理论检验（20项）

| 序号 | 检验项 | 标准 | 自评 |
|------|--------|------|------|
| T1 | Service Mesh概念 | 能解释Service Mesh的架构和优势 | ☐ |
| T2 | Envoy定位 | 能说明Envoy在云原生生态中的角色 | ☐ |
| T3 | 核心组件 | 能描述Listener/Cluster/Route的作用 | ☐ |
| T4 | 请求流程 | 能追踪HTTP请求的完整处理路径 | ☐ |
| T5 | 负载均衡 | 能比较不同负载均衡策略的适用场景 | ☐ |
| T6 | 线程模型 | 能解释Thread-per-Core的设计优势 | ☐ |
| T7 | TLS机制 | 能描述Slot分配和数据传播流程 | ☐ |
| T8 | Dispatcher | 能解释事件循环的工作原理 | ☐ |
| T9 | Network Filter | 能描述ReadFilter/WriteFilter接口 | ☐ |
| T10 | HTTP Filter | 能解释Decoder/Encoder的执行流程 | ☐ |
| T11 | Filter状态 | 能说明各种返回状态的作用 | ☐ |
| T12 | FilterManager | 能描述Filter链的组织和执行机制 | ☐ |
| T13 | xDS协议族 | 能说明LDS/RDS/CDS/EDS的作用 | ☐ |
| T14 | 订阅模式 | 能比较SotW/Delta/ADS的差异 | ☐ |
| T15 | Drain机制 | 能描述配置热更新的优雅关闭流程 | ☐ |
| T16 | 版本管理 | 能解释配置版本控制的重要性 | ☐ |
| T17 | 连接池 | 能描述上游连接池的管理策略 | ☐ |
| T18 | 熔断器 | 能解释Circuit Breaker的工作原理 | ☐ |
| T19 | 重试机制 | 能说明Envoy的重试策略配置 | ☐ |
| T20 | 可观测性 | 能描述Envoy的监控和追踪能力 | ☐ |

### 实践检验（20项）

| 序号 | 检验项 | 标准 | 自评 |
|------|--------|------|------|
| P1 | 配置解析 | 代码能正确解析Envoy配置格式 | ☐ |
| P2 | Listener实现 | 代码能正确实现监听器组件 | ☐ |
| P3 | Cluster实现 | 代码能正确实现集群管理 | ☐ |
| P4 | 路由匹配 | 代码能正确实现路由规则匹配 | ☐ |
| P5 | 负载均衡器 | 代码能实现多种负载均衡策略 | ☐ |
| P6 | Worker线程 | 代码能正确管理Worker线程池 | ☐ |
| P7 | TLS Slot | 代码能正确实现TLS存储机制 | ☐ |
| P8 | Dispatcher | 代码能正确实现事件循环 | ☐ |
| P9 | 定时器 | 代码能正确管理定时器触发 | ☐ |
| P10 | Network Filter | 代码能实现自定义Network Filter | ☐ |
| P11 | HTTP Filter | 代码能实现自定义HTTP Filter | ☐ |
| P12 | FilterManager | 代码能正确管理Filter链执行 | ☐ |
| P13 | 认证Filter | 代码能实现基本认证功能 | ☐ |
| P14 | CORS Filter | 代码能正确处理跨域请求 | ☐ |
| P15 | xDS客户端 | 代码能订阅和处理xDS更新 | ☐ |
| P16 | 配置管理器 | 代码能正确管理配置版本 | ☐ |
| P17 | Drain管理器 | 代码能实现优雅关闭机制 | ☐ |
| P18 | 连接池 | 代码能正确管理上游连接 | ☐ |
| P19 | ClusterManager | 代码能实现集群选择和端点路由 | ☐ |
| P20 | Mini-Envoy | 代码能完成简化版代理服务器 | ☐ |

---

## 输出物清单

```
mini-envoy/
├── README.md                    # 项目说明
├── CMakeLists.txt              # 构建配置
├── include/
│   ├── config/
│   │   ├── config_parser.hpp   # 配置解析器
│   │   ├── config_manager.hpp  # 配置管理器
│   │   └── xds_client.hpp      # xDS客户端
│   ├── network/
│   │   ├── listener.hpp        # 监听器
│   │   ├── connection.hpp      # 连接管理
│   │   └── connection_pool.hpp # 连接池
│   ├── thread/
│   │   ├── worker.hpp          # Worker线程
│   │   ├── dispatcher.hpp      # 事件分发器
│   │   └── tls.hpp             # Thread Local Storage
│   ├── filter/
│   │   ├── network_filter.hpp  # Network Filter
│   │   ├── http_filter.hpp     # HTTP Filter
│   │   └── filter_manager.hpp  # Filter管理器
│   ├── cluster/
│   │   ├── cluster.hpp         # 集群定义
│   │   ├── load_balancer.hpp   # 负载均衡器
│   │   └── cluster_manager.hpp # 集群管理器
│   ├── router/
│   │   └── router.hpp          # 路由器
│   └── server/
│       ├── drain_manager.hpp   # Drain管理器
│       └── mini_envoy.hpp      # 主服务器
├── src/
│   └── main.cpp                # 入口程序
├── test/
│   ├── config_test.cpp         # 配置测试
│   ├── filter_test.cpp         # Filter测试
│   ├── cluster_test.cpp        # 集群测试
│   └── integration_test.cpp    # 集成测试
└── examples/
    ├── basic_proxy.cpp         # 基础代理示例
    ├── filter_chain.cpp        # Filter链示例
    └── hot_reload.cpp          # 热更新示例
```

### 输出物完成度检查

| 输出物 | 说明 | 完成 |
|--------|------|------|
| 配置解析器 | 支持YAML格式配置解析 | ☐ |
| 监听器组件 | 支持TCP监听和连接接受 | ☐ |
| Worker线程池 | 支持多Worker并发处理 | ☐ |
| TLS机制 | 支持配置的无锁传播 | ☐ |
| Dispatcher | 支持定时器和I/O事件 | ☐ |
| Network Filter | 支持自定义Network Filter | ☐ |
| HTTP Filter | 支持自定义HTTP Filter | ☐ |
| FilterManager | 支持Filter链管理 | ☐ |
| 负载均衡器 | 支持多种LB策略 | ☐ |
| 连接池 | 支持连接复用 | ☐ |
| 路由器 | 支持路由规则匹配 | ☐ |
| xDS客户端 | 支持配置订阅 | ☐ |
| 配置管理器 | 支持版本管理 | ☐ |
| Drain管理器 | 支持优雅关闭 | ☐ |
| Mini-Envoy服务器 | 完整代理功能 | ☐ |

---

## 学习建议

### 学习路径

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Envoy架构学习路径                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  基础阶段                     进阶阶段                    高级阶段          │
│  ┌─────────────┐            ┌─────────────┐            ┌─────────────┐     │
│  │ 理解Service │            │ 深入线程    │            │ 实现Mini-   │     │
│  │ Mesh概念    │───────────▶│ 模型与TLS   │───────────▶│ Envoy代理   │     │
│  │             │            │             │            │             │     │
│  └─────────────┘            └─────────────┘            └─────────────┘     │
│        │                          │                          │             │
│        ▼                          ▼                          ▼             │
│  ┌─────────────┐            ┌─────────────┐            ┌─────────────┐     │
│  │ 核心组件    │            │ Filter机制  │            │ 配置热更新  │     │
│  │ 架构理解    │───────────▶│ 深入理解    │───────────▶│ 与xDS实现   │     │
│  │             │            │             │            │             │     │
│  └─────────────┘            └─────────────┘            └─────────────┘     │
│                                                                             │
│  推荐顺序：                                                                  │
│  1. 阅读Envoy官方文档，理解整体架构                                          │
│  2. 研究Envoy源码中的thread_local和dispatcher实现                           │
│  3. 分析HTTP Connection Manager的Filter处理流程                             │
│  4. 研究xDS协议和配置热更新机制                                              │
│  5. 动手实现Mini-Envoy，加深理解                                            │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 调试技巧

| 场景 | 技巧 |
|------|------|
| Filter调试 | 在Filter的各个回调中添加日志，追踪执行流程 |
| 线程问题 | 使用线程名称标识，打印线程ID |
| 配置更新 | 记录配置版本变化，验证TLS传播 |
| 连接池 | 监控连接创建/复用/关闭，统计连接利用率 |
| 性能分析 | 使用chrono记录各阶段耗时 |

### 常见错误

| 错误 | 原因 | 解决方案 |
|------|------|----------|
| 数据竞争 | Worker间共享数据未保护 | 使用TLS或原子操作 |
| 内存泄漏 | Filter未正确释放 | 使用智能指针管理生命周期 |
| 死锁 | 配置更新时锁嵌套 | 避免在持锁时调用外部回调 |
| 配置丢失 | 版本检查不正确 | 严格的版本比较和日志 |
| 连接泄漏 | 连接未正确归还池 | 使用RAII管理连接 |

---

## 结语

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│   ★ 恭喜完成 Month-32：Envoy架构分析——云原生代理 ★                          │
│                                                                             │
│   本月学习成果：                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │ • 掌握了Service Mesh和Envoy的核心概念                               │  │
│   │ • 理解了Thread-per-Core线程模型的设计精髓                           │  │
│   │ • 深入学习了Filter链机制和扩展开发                                   │  │
│   │ • 实现了xDS配置订阅和热更新机制                                      │  │
│   │ • 完成了Mini-Envoy代理服务器的开发                                   │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│   知识脉络：                                                                 │
│   Month-30 Reactor模式 → Month-31 Proactor模式 → Month-32 Envoy架构        │
│                                                                             │
│   从基础的I/O多路复用，到异步完成通知，再到云原生代理的完整架构，           │
│   你已经具备了设计和实现高性能网络服务的能力。                              │
│                                                                             │
│   下月预告：Month-33 将学习高性能HTTP服务器实现，将本月学到的架构           │
│   知识应用到实际的HTTP服务器开发中。                                        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 下月预告

### Month-33：高性能HTTP服务器实现

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Month-33 预告                                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  主题：高性能HTTP服务器实现                                                  │
│                                                                             │
│  第一周：HTTP协议深入                                                        │
│  • HTTP/1.1协议详解                                                         │
│  • Keep-Alive和Pipeline                                                     │
│  • Chunked Transfer Encoding                                                │
│  • HTTP/2协议基础                                                           │
│                                                                             │
│  第二周：请求解析与响应生成                                                  │
│  • 高性能HTTP解析器                                                         │
│  • 零拷贝技术                                                               │
│  • 响应序列化优化                                                           │
│                                                                             │
│  第三周：静态文件服务                                                        │
│  • 文件缓存策略                                                             │
│  • sendfile系统调用                                                         │
│  • 内存映射文件                                                             │
│                                                                             │
│  第四周：完整HTTP服务器                                                      │
│  • 路由系统                                                                 │
│  • 中间件机制                                                               │
│  • 压力测试与优化                                                           │
│                                                                             │
│  承接关系：                                                                  │
│  Month-32 Envoy架构 → Month-33 HTTP服务器（将架构知识应用于实战）           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```
