# Month 40: CI/CD流水线——GitHub Actions自动化实践

## 本月主题概述

本月学习持续集成/持续部署（CI/CD）的核心概念，重点掌握GitHub Actions的使用。学习如何构建自动化的构建、测试、发布流水线，实现代码质量的持续保障。

**学习目标**：
- 理解CI/CD的核心概念和最佳实践
- 掌握GitHub Actions的语法和工作原理
- 构建跨平台的C++项目CI流水线
- 实现自动化测试、代码覆盖率和发布流程

---

## 理论学习内容

### 第一周：CI/CD基础概念（35小时）

```
┌─────────────────────────────────────────────────────────────────┐
│  Week 1: CI/CD 基础概念与 GitHub Actions 入门                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Day 1-2: CI/CD 核心理念与演进                                   │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐ │
│  │ 手动构建 │ →  │ 脚本自动 │ →  │ 持续集成 │ →  │ 持续部署 │ │
│  │ (1990s) │    │ (2000s) │    │ (2010s) │    │ (2020s) │ │
│  └──────────┘    └──────────┘    └──────────┘    └──────────┘ │
│                                                                 │
│  Day 3-4: GitHub Actions 架构与核心组件                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Event → Workflow → Job → Step → Action                  │   │
│  │  (触发)   (流程)    (任务)  (步骤)   (动作)               │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Day 5-7: Workflow 语法实战与 Runner 深入                        │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  GitHub-hosted Runner  vs  Self-hosted Runner            │   │
│  │  (Ubuntu/Windows/macOS)    (自定义环境/私有网络)          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### 每日任务分解

| Day | 时间 | 上午任务(2.5h) | 下午任务(2.5h) | 输出物 |
|-----|------|---------------|---------------|--------|
| 1 | 5h | CI/CD历史与核心理念 | 阅读《持续交付》第1-2章 | notes/cicd_intro.md |
| 2 | 5h | CI vs CD vs CD对比 | DevOps文化与最佳实践 | notes/devops_culture.md |
| 3 | 5h | GitHub Actions架构概览 | Event触发器完整学习 | notes/gha_architecture.md |
| 4 | 5h | Workflow/Job/Step概念 | 编写第一个Workflow | .github/workflows/hello.yml |
| 5 | 5h | Runner类型与选择策略 | Self-hosted Runner配置 | notes/runner_guide.md |
| 6 | 5h | 阅读fmtlib CI配置 | 分析其多平台构建策略 | notes/fmt_ci_analysis.md |
| 7 | 5h | Workflow语法速查表整理 | 综合练习：基础CI流程 | practice/week1_basic_ci/ |

**学习目标**：理解持续集成和持续部署的理念

**阅读材料**：
- [ ] 《持续交付》第1-3章
- [ ] GitHub Actions官方文档
- [ ] Martin Fowler: Continuous Integration

**核心概念**：

```yaml
# ==========================================
# CI/CD核心概念
# ==========================================

# 持续集成 (CI - Continuous Integration)
# - 频繁地将代码合并到主干
# - 每次合并都触发自动化构建和测试
# - 快速发现和修复问题

# 持续交付 (CD - Continuous Delivery)
# - 保持代码始终处于可发布状态
# - 发布是手动触发的决策

# 持续部署 (CD - Continuous Deployment)
# - 自动将通过测试的代码部署到生产环境
# - 完全自动化的发布流程

# ==========================================
# GitHub Actions 基本概念
# ==========================================

# Workflow: 自动化流程定义，存放在 .github/workflows/
# Job: workflow中的一组步骤，可并行或串行执行
# Step: job中的单个任务
# Action: 可重用的自动化单元
# Runner: 执行workflow的服务器
# Event: 触发workflow的事件
```

#### CI/CD 演进历史

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CI/CD 演进时间线                                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1990s: 手动时代                                                    │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  开发 → 手动编译 → 手动测试 → 手动打包 → 手动部署            │    │
│  │  问题：耗时、易错、难以回溯                                  │    │
│  └────────────────────────────────────────────────────────────┘    │
│                              │                                       │
│                              ▼                                       │
│  2000s: 脚本自动化时代                                              │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  Makefile / Shell脚本 / Ant / Maven                         │    │
│  │  问题：脚本维护困难、环境不一致                               │    │
│  └────────────────────────────────────────────────────────────┘    │
│                              │                                       │
│                              ▼                                       │
│  2010s: CI服务器时代                                                │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  Jenkins (2011) / Travis CI (2011) / CircleCI (2011)        │    │
│  │  特点：集中式构建服务器、Webhook触发、构建可视化             │    │
│  └────────────────────────────────────────────────────────────┘    │
│                              │                                       │
│                              ▼                                       │
│  2018+: 云原生CI/CD时代                                             │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  GitHub Actions (2019) / GitLab CI / Azure Pipelines        │    │
│  │  特点：代码即配置、Marketplace生态、容器化执行              │    │
│  └────────────────────────────────────────────────────────────┘    │
│                                                                     │
│  关键里程碑:                                                        │
│  ├── 2001: Martin Fowler 提出"持续集成"概念                       │
│  ├── 2006: 《持续集成》一书出版                                    │
│  ├── 2010: 《持续交付》一书出版                                    │
│  ├── 2019: GitHub Actions 正式发布                                 │
│  └── 2020s: GitOps、IaC 成为主流                                   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

#### GitHub Actions 架构详解

```
┌─────────────────────────────────────────────────────────────────────┐
│                 GitHub Actions 架构                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  触发层 (Events)                                                    │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  push │ pull_request │ schedule │ workflow_dispatch │ ...  │    │
│  └───────────────────────────┬────────────────────────────────┘    │
│                              │                                       │
│                              ▼                                       │
│  调度层 (GitHub Orchestrator)                                       │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │    │
│  │  │ 事件匹配     │→ │ Workflow解析  │→ │  Job调度     │     │    │
│  │  │ (on:条件)    │  │ (YAML处理)   │  │  (矩阵展开)   │     │    │
│  │  └──────────────┘  └──────────────┘  └──────────────┘     │    │
│  └───────────────────────────┬────────────────────────────────┘    │
│                              │                                       │
│                              ▼                                       │
│  执行层 (Runners)                                                   │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │                                                             │    │
│  │  ┌─────────────────────┐    ┌─────────────────────┐       │    │
│  │  │  GitHub-hosted      │    │  Self-hosted        │       │    │
│  │  │  ├── ubuntu-latest  │    │  ├── 自定义环境     │       │    │
│  │  │  ├── windows-latest │    │  ├── 私有网络访问   │       │    │
│  │  │  └── macos-latest   │    │  └── 特殊硬件支持   │       │    │
│  │  └─────────────────────┘    └─────────────────────┘       │    │
│  │                                                             │    │
│  │  Runner 执行流程:                                           │    │
│  │  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐       │    │
│  │  │Checkout│→│Setup │→│ Run  │→│Upload│→│Cleanup│       │    │
│  │  │ 代码  │  │ 环境 │  │ Step │  │Artifact│ │ 清理 │       │    │
│  │  └──────┘  └──────┘  └──────┘  └──────┘  └──────┘       │    │
│  └────────────────────────────────────────────────────────────┘    │
│                              │                                       │
│                              ▼                                       │
│  结果层 (Outputs)                                                   │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  Logs │ Artifacts │ Status Checks │ Deployments │ Releases │    │
│  └────────────────────────────────────────────────────────────┘    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

#### Runner 类型详解

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Runner 类型对比                                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  GitHub-hosted Runners                                              │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │                                                             │    │
│  │  Linux (ubuntu-latest / ubuntu-22.04 / ubuntu-20.04)       │    │
│  │  ├── 2-core CPU, 7 GB RAM, 14 GB SSD                       │    │
│  │  ├── 预装: Docker, Node.js, Python, Go, .NET, GCC, Clang   │    │
│  │  └── 每月免费: 2,000 分钟 (公开仓库无限)                    │    │
│  │                                                             │    │
│  │  Windows (windows-latest / windows-2022 / windows-2019)    │    │
│  │  ├── 2-core CPU, 7 GB RAM, 14 GB SSD                       │    │
│  │  ├── 预装: Visual Studio, MSVC, Chocolatey                 │    │
│  │  └── 计费: Linux的2倍                                       │    │
│  │                                                             │    │
│  │  macOS (macos-latest / macos-13 / macos-12)                │    │
│  │  ├── 3-core CPU, 14 GB RAM, 14 GB SSD (Intel)             │    │
│  │  ├── 预装: Xcode, Homebrew, CocoaPods                      │    │
│  │  └── 计费: Linux的10倍                                      │    │
│  │                                                             │    │
│  │  优点: 零维护、即开即用、自动更新                            │    │
│  │  缺点: 资源有限、无法访问私有网络、启动时间较长               │    │
│  │                                                             │    │
│  └────────────────────────────────────────────────────────────┘    │
│                                                                     │
│  Self-hosted Runners                                                │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │                                                             │    │
│  │  使用场景:                                                  │    │
│  │  ├── 需要访问内网资源（数据库、内部服务）                    │    │
│  │  ├── 需要特殊硬件（GPU、大内存、ARM架构）                   │    │
│  │  ├── 需要自定义软件环境                                     │    │
│  │  ├── 成本优化（大量构建时）                                 │    │
│  │  └── 合规要求（数据不出境）                                 │    │
│  │                                                             │    │
│  │  配置步骤:                                                  │    │
│  │  1. Settings → Actions → Runners → New self-hosted runner  │    │
│  │  2. 下载并配置 runner 应用                                  │    │
│  │  3. 使用 labels 标识特定 runner                             │    │
│  │                                                             │    │
│  │  安全注意:                                                  │    │
│  │  ├── 不要用于公开仓库（Fork可执行任意代码）                 │    │
│  │  ├── 使用专用用户账户运行                                   │    │
│  │  └── 定期更新 runner 应用                                   │    │
│  │                                                             │    │
│  └────────────────────────────────────────────────────────────┘    │
│                                                                     │
│  选择决策树:                                                        │
│  ┌─────────────────────────────────────────────────────────┐       │
│  │  需要访问内网? ─Yes→ Self-hosted                         │       │
│  │       │No                                                 │       │
│  │       ▼                                                   │       │
│  │  需要特殊硬件? ─Yes→ Self-hosted                         │       │
│  │       │No                                                 │       │
│  │       ▼                                                   │       │
│  │  构建量>10000分钟/月? ─Yes→ 考虑Self-hosted降本          │       │
│  │       │No                                                 │       │
│  │       ▼                                                   │       │
│  │  使用 GitHub-hosted (维护成本低)                          │       │
│  └─────────────────────────────────────────────────────────┘       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

#### Event 触发器完整参考

```yaml
# ==========================================
# GitHub Actions Event 触发器完整参考
# ==========================================

on:
  # ===== 代码相关事件 =====
  push:
    branches:
      - main
      - 'releases/**'        # 通配符匹配
      - '!releases/**-alpha' # 排除模式
    tags:
      - 'v*'
    paths:
      - 'src/**'
      - '!src/**/*.md'       # 排除markdown文件

  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
    branches: [main, develop]
    paths-ignore:
      - 'docs/**'
      - '**.md'

  pull_request_target:       # 在base分支上下文运行（安全场景）
    types: [opened, synchronize]

  # ===== 手动/调度触发 =====
  workflow_dispatch:         # 手动触发
    inputs:
      environment:
        description: 'Deployment environment'
        required: true
        default: 'staging'
        type: choice
        options:
          - staging
          - production
      debug:
        description: 'Enable debug mode'
        required: false
        type: boolean
        default: false

  schedule:
    - cron: '0 0 * * 0'      # 每周日 UTC 00:00
    - cron: '30 5 * * 1-5'   # 工作日 UTC 05:30
    # 注意: 仅在默认分支运行

  # ===== 工作流联动 =====
  workflow_call:             # 被其他workflow调用（可复用工作流）
    inputs:
      config_path:
        required: true
        type: string
    secrets:
      token:
        required: true
    outputs:
      result:
        description: "Build result"
        value: ${{ jobs.build.outputs.result }}

  workflow_run:              # 另一个workflow完成后触发
    workflows: ["Build"]
    types: [completed]
    branches: [main]

  # ===== 仓库管理事件 =====
  issues:
    types: [opened, labeled, closed]

  issue_comment:
    types: [created]

  release:
    types: [published, created, released]

  # ===== 外部触发 =====
  repository_dispatch:       # API触发
    types: [deploy, test]
    # 触发: POST /repos/{owner}/{repo}/dispatches
    # Body: {"event_type": "deploy", "client_payload": {...}}

# ==========================================
# Event 属性访问
# ==========================================
# ${{ github.event_name }}        - 触发事件名
# ${{ github.event.action }}      - 事件动作（如 opened）
# ${{ github.event.pull_request.number }}
# ${{ github.event.inputs.environment }}  - workflow_dispatch输入
# ${{ github.event.client_payload }}      - repository_dispatch载荷
```

#### Workflow 语法速查表

```yaml
# ==========================================
# GitHub Actions Workflow 语法速查表
# ==========================================

name: Workflow Name            # 显示名称

on: [push, pull_request]       # 触发事件（简写）

env:                           # 全局环境变量
  CI: true
  BUILD_TYPE: Release

defaults:                      # 全局默认设置
  run:
    shell: bash
    working-directory: ./src

concurrency:                   # 并发控制
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true     # 取消正在运行的旧任务

permissions:                   # 权限控制（最小权限原则）
  contents: read
  packages: write
  pull-requests: write

jobs:
  job-id:                      # Job唯一标识（用于needs引用）
    name: Display Name         # 显示名称
    runs-on: ubuntu-latest     # Runner选择

    timeout-minutes: 60        # Job超时

    if: github.event_name == 'push'  # 条件执行

    needs: [other-job]         # 依赖其他Job

    environment:               # 部署环境（可配置保护规则）
      name: production
      url: https://example.com

    outputs:                   # Job输出（供其他Job使用）
      version: ${{ steps.extract.outputs.version }}

    strategy:
      fail-fast: false         # 矩阵某项失败不取消其他
      max-parallel: 2          # 最大并行数
      matrix:
        os: [ubuntu-latest, windows-latest]
        node: [16, 18, 20]
        include:               # 额外组合
          - os: ubuntu-latest
            node: 20
            experimental: true
        exclude:               # 排除组合
          - os: windows-latest
            node: 16

    container:                 # 在容器中运行
      image: node:18
      credentials:
        username: ${{ secrets.DOCKER_USER }}
        password: ${{ secrets.DOCKER_TOKEN }}
      env:
        NODE_ENV: test
      volumes:
        - /data:/data

    services:                  # 服务容器（如数据库）
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: test
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s

    steps:
      - name: Step Name
        id: step-id             # Step唯一标识
        if: always()            # 条件: always/success/failure/cancelled
        continue-on-error: true # 失败不中断
        timeout-minutes: 10     # Step超时

        uses: actions/checkout@v4  # 使用Action
        with:                      # Action参数
          fetch-depth: 0
          submodules: recursive
        env:                       # Step环境变量
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Run Command
        run: |
          echo "Multi-line"
          echo "Commands"
        shell: bash              # 指定shell: bash/pwsh/python/cmd
        working-directory: ./app

      - name: Set Output
        id: set-output
        run: echo "version=1.0.0" >> $GITHUB_OUTPUT

      - name: Use Output
        run: echo "Version is ${{ steps.set-output.outputs.version }}"

# ==========================================
# 常用表达式
# ==========================================
# ${{ github.ref }}              - refs/heads/main 或 refs/tags/v1.0
# ${{ github.ref_name }}         - main 或 v1.0
# ${{ github.sha }}              - 完整commit SHA
# ${{ github.actor }}            - 触发者用户名
# ${{ github.repository }}       - owner/repo
# ${{ github.workspace }}        - 工作目录路径
# ${{ runner.os }}               - Linux/Windows/macOS
# ${{ runner.arch }}             - X86/X64/ARM/ARM64
# ${{ secrets.NAME }}            - 访问Secret
# ${{ vars.NAME }}               - 访问Variable
# ${{ env.NAME }}                - 访问环境变量
# ${{ matrix.os }}               - 矩阵当前值
# ${{ needs.job-id.outputs.x }}  - 其他Job的输出
# ${{ steps.step-id.outputs.x }} - 其他Step的输出

# ==========================================
# 常用函数
# ==========================================
# contains(github.event.head_commit.message, '[skip ci]')
# startsWith(github.ref, 'refs/tags/')
# endsWith(github.repository, '-template')
# format('Hello {0} {1}', 'World', '!')
# join(matrix.os, ', ')
# toJSON(github.event)
# fromJSON(needs.job.outputs.matrix)
# hashFiles('**/package-lock.json')
# always() / success() / failure() / cancelled()
```

#### Week 1 输出物清单

| 文件 | 说明 | 完成状态 |
|------|------|---------|
| `notes/cicd_intro.md` | CI/CD核心概念笔记 | [ ] |
| `notes/devops_culture.md` | DevOps文化与实践 | [ ] |
| `notes/gha_architecture.md` | GitHub Actions架构 | [ ] |
| `.github/workflows/hello.yml` | 第一个Workflow | [ ] |
| `notes/runner_guide.md` | Runner类型与选择 | [ ] |
| `notes/fmt_ci_analysis.md` | fmt库CI分析 | [ ] |
| `practice/week1_basic_ci/` | 基础CI练习项目 | [ ] |

#### Week 1 检验标准

- [ ] 能够解释CI、CD（Delivery）、CD（Deployment）的区别
- [ ] 理解GitHub Actions的五层架构（Event/Workflow/Job/Step/Action）
- [ ] 能够区分GitHub-hosted和Self-hosted Runner的适用场景
- [ ] 掌握至少5种Event触发器的使用方法
- [ ] 能够编写包含矩阵构建的基础Workflow
- [ ] 理解`on`、`jobs`、`steps`的层级关系
- [ ] 掌握Workflow语法速查表中80%的语法
- [ ] 完成fmt库CI配置的阅读分析

---

**基本Workflow结构**：

```yaml
# .github/workflows/ci.yml
name: CI  # workflow名称

on:  # 触发事件
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
  workflow_dispatch:  # 手动触发

env:  # 全局环境变量
  BUILD_TYPE: Release

jobs:
  build:
    name: Build on ${{ matrix.os }}
    runs-on: ${{ matrix.os }}

    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
        compiler: [gcc, clang]
        exclude:
          - os: windows-latest
            compiler: gcc

    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Setup environment
        run: echo "Setting up..."

      - name: Configure
        run: cmake -B build -S . -DCMAKE_BUILD_TYPE=${{ env.BUILD_TYPE }}

      - name: Build
        run: cmake --build build --config ${{ env.BUILD_TYPE }}

      - name: Test
        run: ctest --test-dir build -C ${{ env.BUILD_TYPE }} --output-on-failure
```

### 第二周：C++项目CI配置（35小时）

```
┌─────────────────────────────────────────────────────────────────┐
│  Week 2: C++ 项目 CI 流水线配置                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Day 8-9: C++ 构建流水线架构                                     │
│  ┌───────┐  ┌───────┐  ┌───────┐  ┌───────┐  ┌───────┐       │
│  │Checkout│→│ Setup │→│ Build │→│ Test  │→│Package│       │
│  │ 代码  │  │ 依赖  │  │ 编译  │  │ 测试  │  │ 打包  │       │
│  └───────┘  └───────┘  └───────┘  └───────┘  └───────┘       │
│                                                                 │
│  Day 10-11: Matrix 策略与多平台构建                              │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  matrix:                                                 │   │
│  │    os: [ubuntu, windows, macos]                         │   │
│  │    compiler: [gcc, clang, msvc]                         │   │
│  │  → 9种组合并行执行                                       │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Day 12-14: 缓存策略与 Artifact 管理                             │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Cache: 依赖/构建产物 → Artifact: 测试报告/安装包       │   │
│  │  vcpkg binary cache → ccache → CMake build cache        │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### 每日任务分解

| Day | 时间 | 上午任务(2.5h) | 下午任务(2.5h) | 输出物 |
|-----|------|---------------|---------------|--------|
| 8 | 5h | C++构建流水线设计 | 多编译器支持策略 | notes/cpp_ci_design.md |
| 9 | 5h | CMake与GitHub Actions集成 | vcpkg CI集成配置 | .github/workflows/build.yml |
| 10 | 5h | Matrix策略深入 | include/exclude高级用法 | notes/matrix_strategy.md |
| 11 | 5h | 多平台构建实践 | 平台特定步骤处理 | practice/multiplatform/ |
| 12 | 5h | 缓存策略设计 | actions/cache深入使用 | notes/caching_guide.md |
| 13 | 5h | vcpkg二进制缓存 | ccache/sccache集成 | .github/workflows/cached-build.yml |
| 14 | 5h | Artifact上传下载 | 测试报告与覆盖率集成 | .github/workflows/test.yml |

**学习目标**：为C++项目配置完整的CI流水线

**阅读材料**：
- [ ] GitHub Actions: Caching dependencies
- [ ] CMake with GitHub Actions
- [ ] vcpkg/Conan CI integration

```yaml
# ==========================================
# .github/workflows/build.yml - 完整C++构建
# ==========================================
name: Build and Test

on:
  push:
    branches: [main, develop]
    paths-ignore:
      - '**.md'
      - 'docs/**'
  pull_request:
    branches: [main]

env:
  VCPKG_BINARY_SOURCES: "clear;x-gha,readwrite"

jobs:
  build:
    name: ${{ matrix.config.name }}
    runs-on: ${{ matrix.config.os }}

    strategy:
      fail-fast: false
      matrix:
        config:
          - name: "Ubuntu GCC 12"
            os: ubuntu-22.04
            compiler: gcc
            version: 12
            cmake_args: ""

          - name: "Ubuntu Clang 15"
            os: ubuntu-22.04
            compiler: clang
            version: 15
            cmake_args: ""

          - name: "Windows MSVC 2022"
            os: windows-2022
            compiler: msvc
            version: 2022
            cmake_args: "-A x64"

          - name: "macOS Clang"
            os: macos-13
            compiler: clang
            version: 14
            cmake_args: ""

    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          submodules: recursive
          fetch-depth: 0

      # Linux: 安装编译器
      - name: Install GCC (Linux)
        if: matrix.config.compiler == 'gcc' && runner.os == 'Linux'
        run: |
          sudo apt-get update
          sudo apt-get install -y g++-${{ matrix.config.version }}
          echo "CC=gcc-${{ matrix.config.version }}" >> $GITHUB_ENV
          echo "CXX=g++-${{ matrix.config.version }}" >> $GITHUB_ENV

      - name: Install Clang (Linux)
        if: matrix.config.compiler == 'clang' && runner.os == 'Linux'
        run: |
          wget https://apt.llvm.org/llvm.sh
          chmod +x llvm.sh
          sudo ./llvm.sh ${{ matrix.config.version }}
          echo "CC=clang-${{ matrix.config.version }}" >> $GITHUB_ENV
          echo "CXX=clang++-${{ matrix.config.version }}" >> $GITHUB_ENV

      # 缓存vcpkg
      - name: Export GitHub Actions cache variables
        uses: actions/github-script@v7
        with:
          script: |
            core.exportVariable('ACTIONS_CACHE_URL', process.env.ACTIONS_CACHE_URL || '');
            core.exportVariable('ACTIONS_RUNTIME_TOKEN', process.env.ACTIONS_RUNTIME_TOKEN || '');

      - name: Setup vcpkg
        uses: lukka/run-vcpkg@v11
        with:
          vcpkgGitCommitId: 'a34c873a9717a888f58dc05268dea15592c2f0ff'

      # 配置和构建
      - name: Configure CMake
        run: |
          cmake -B build -S . \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_TOOLCHAIN_FILE=${{ env.VCPKG_ROOT }}/scripts/buildsystems/vcpkg.cmake \
            -DBUILD_TESTS=ON \
            ${{ matrix.config.cmake_args }}

      - name: Build
        run: cmake --build build --config Release --parallel

      - name: Test
        working-directory: build
        run: ctest -C Release --output-on-failure --parallel

      # 上传构建产物
      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: build-${{ matrix.config.name }}
          path: |
            build/bin/
            build/lib/
          retention-days: 7
```

```yaml
# ==========================================
# .github/workflows/test.yml - 测试和覆盖率
# ==========================================
name: Tests and Coverage

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-22.04

    steps:
      - uses: actions/checkout@v4

      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y lcov

      - name: Configure with coverage
        run: |
          cmake -B build -S . \
            -DCMAKE_BUILD_TYPE=Debug \
            -DCMAKE_CXX_FLAGS="--coverage -fprofile-arcs -ftest-coverage" \
            -DBUILD_TESTS=ON

      - name: Build
        run: cmake --build build --parallel

      - name: Run tests
        working-directory: build
        run: ctest --output-on-failure

      - name: Generate coverage report
        run: |
          lcov --directory build --capture --output-file coverage.info
          lcov --remove coverage.info '/usr/*' '*/tests/*' --output-file coverage.info
          lcov --list coverage.info

      - name: Upload to Codecov
        uses: codecov/codecov-action@v4
        with:
          token: ${{ secrets.CODECOV_TOKEN }}
          files: coverage.info
          fail_ci_if_error: true

      - name: Upload coverage artifact
        uses: actions/upload-artifact@v4
        with:
          name: coverage-report
          path: coverage.info
```

#### C++ 构建流水线架构图

```
┌─────────────────────────────────────────────────────────────────────┐
│                C++ 项目完整 CI 流水线                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  阶段1: 代码检查 (Gate)                                             │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │    │
│  │  │clang-    │  │clang-tidy│  │cppcheck  │  │ include- │  │    │
│  │  │format    │  │静态分析   │  │静态分析   │  │ what-you │  │    │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │    │
│  │                      │                                    │    │
│  │          ←─── 任一失败则阻止合并 ───→                      │    │
│  └────────────────────────────────────────────────────────────┘    │
│                              │                                       │
│                              ▼                                       │
│  阶段2: 多平台构建 (Build)                                          │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │        ┌─────────────────────────────────────────┐         │    │
│  │        │              Matrix展开                  │         │    │
│  │        └─────────────────────────────────────────┘         │    │
│  │              │              │              │                │    │
│  │              ▼              ▼              ▼                │    │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐       │    │
│  │  │ Linux GCC   │ │ Linux Clang │ │ Windows MSVC │       │    │
│  │  │ ubuntu-22.04│ │ ubuntu-22.04│ │ windows-2022 │       │    │
│  │  └──────────────┘ └──────────────┘ └──────────────┘       │    │
│  │  ┌──────────────┐ ┌──────────────┐                        │    │
│  │  │ macOS Clang │ │ Linux ARM   │  (可选)                 │    │
│  │  │ macos-13    │ │ self-hosted │                        │    │
│  │  └──────────────┘ └──────────────┘                        │    │
│  └────────────────────────────────────────────────────────────┘    │
│                              │                                       │
│                              ▼                                       │
│  阶段3: 测试与分析 (Test & Analyze)                                 │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │    │
│  │  │  单元测试    │  │ 集成测试     │  │ 代码覆盖率   │     │    │
│  │  │  GTest/Catch │  │  端到端      │  │  lcov/gcov   │     │    │
│  │  └──────────────┘  └──────────────┘  └──────────────┘     │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │    │
│  │  │  ASan测试    │  │  TSan测试    │  │  UBSan测试   │     │    │
│  │  │ 内存错误检测  │  │ 数据竞争检测  │  │ 未定义行为   │     │    │
│  │  └──────────────┘  └──────────────┘  └──────────────┘     │    │
│  └────────────────────────────────────────────────────────────┘    │
│                              │                                       │
│                              ▼                                       │
│  阶段4: 打包与发布 (Package & Release) [仅tag/main]                 │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │    │
│  │  │  CPack打包   │  │ Docker镜像  │  │ GitHub Release│     │    │
│  │  │ DEB/RPM/ZIP │  │  构建推送    │  │  发布资产    │     │    │
│  │  └──────────────┘  └──────────────┘  └──────────────┘     │    │
│  └────────────────────────────────────────────────────────────┘    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

#### Matrix 策略深度解析

```yaml
# ==========================================
# Matrix 策略高级用法
# ==========================================

jobs:
  build:
    strategy:
      # 控制失败行为
      fail-fast: false        # 某项失败不取消其他（默认true）
      max-parallel: 4         # 最大并行数（控制资源消耗）

      matrix:
        # 基础矩阵：os × compiler = 6 种组合
        os: [ubuntu-22.04, windows-2022, macos-13]
        compiler: [gcc, clang]

        # include: 添加额外组合或覆盖属性
        include:
          # 为特定组合添加额外属性
          - os: ubuntu-22.04
            compiler: gcc
            version: 12
            cmake_args: "-DCMAKE_CXX_FLAGS=-fdiagnostics-color=always"

          - os: ubuntu-22.04
            compiler: clang
            version: 15
            cmake_args: "-DCMAKE_CXX_FLAGS=-fcolor-diagnostics"

          # 添加不在基础矩阵中的组合
          - os: windows-2022
            compiler: msvc
            version: 2022
            cmake_args: "-A x64"

          # 添加实验性组合
          - os: ubuntu-22.04
            compiler: gcc
            version: 13
            experimental: true
            cmake_args: "-DCMAKE_CXX_STANDARD=23"

        # exclude: 排除特定组合
        exclude:
          # Windows不使用gcc（MinGW复杂度高）
          - os: windows-2022
            compiler: gcc
          # macOS不需要gcc（Clang够用）
          - os: macos-13
            compiler: gcc

    runs-on: ${{ matrix.os }}
    name: "${{ matrix.os }} / ${{ matrix.compiler }}${{ matrix.version && format(' {0}', matrix.version) || '' }}"

    # 实验性任务失败不影响整体状态
    continue-on-error: ${{ matrix.experimental || false }}

    steps:
      - uses: actions/checkout@v4

      # 根据矩阵值条件执行
      - name: Setup GCC
        if: matrix.compiler == 'gcc' && runner.os == 'Linux'
        run: |
          sudo apt-get update
          sudo apt-get install -y g++-${{ matrix.version }}
          echo "CC=gcc-${{ matrix.version }}" >> $GITHUB_ENV
          echo "CXX=g++-${{ matrix.version }}" >> $GITHUB_ENV

      - name: Setup Clang
        if: matrix.compiler == 'clang' && runner.os == 'Linux'
        run: |
          wget https://apt.llvm.org/llvm.sh
          chmod +x llvm.sh
          sudo ./llvm.sh ${{ matrix.version }}
          echo "CC=clang-${{ matrix.version }}" >> $GITHUB_ENV
          echo "CXX=clang++-${{ matrix.version }}" >> $GITHUB_ENV

      - name: Setup MSVC
        if: matrix.compiler == 'msvc'
        uses: ilammy/msvc-dev-cmd@v1
        with:
          arch: x64

      - name: Configure
        run: cmake -B build ${{ matrix.cmake_args }}

# ==========================================
# 动态矩阵（从Job输出生成）
# ==========================================
jobs:
  prepare:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.set-matrix.outputs.matrix }}
    steps:
      - id: set-matrix
        run: |
          # 根据触发条件动态生成矩阵
          if [[ "${{ github.event_name }}" == "schedule" ]]; then
            # 定时任务：全量测试
            matrix='{"os":["ubuntu-22.04","windows-2022","macos-13"],"compiler":["gcc","clang","msvc"]}'
          else
            # PR：快速测试
            matrix='{"os":["ubuntu-22.04"],"compiler":["gcc"]}'
          fi
          echo "matrix=$matrix" >> $GITHUB_OUTPUT

  build:
    needs: prepare
    strategy:
      matrix: ${{ fromJSON(needs.prepare.outputs.matrix) }}
    runs-on: ${{ matrix.os }}
    # ...
```

#### 缓存策略详解

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CI 缓存策略层次                                    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  层次1: 依赖缓存 (最稳定，变化最少)                                  │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  vcpkg packages / Conan packages / apt packages            │    │
│  │  Key: 基于 vcpkg.json / conanfile.txt 的 hash              │    │
│  │  大小: 通常 100MB - 2GB                                    │    │
│  │  命中率: 高（依赖不常变化）                                 │    │
│  └────────────────────────────────────────────────────────────┘    │
│                              │                                       │
│                              ▼                                       │
│  层次2: 编译缓存 (中等稳定)                                         │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  ccache / sccache (编译器缓存)                             │    │
│  │  Key: 基于源文件内容 hash                                   │    │
│  │  大小: 通常 500MB - 5GB                                    │    │
│  │  效果: 增量构建从 10min 降到 1-2min                        │    │
│  └────────────────────────────────────────────────────────────┘    │
│                              │                                       │
│                              ▼                                       │
│  层次3: 构建产物缓存 (最易变)                                       │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  CMake build 目录 / Ninja .ninja_deps                      │    │
│  │  Key: 基于 CMakeLists.txt + 源码 hash                      │    │
│  │  注意: 跨平台/编译器不兼容，需分别缓存                      │    │
│  └────────────────────────────────────────────────────────────┘    │
│                                                                     │
│  缓存 Key 设计原则:                                                 │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  key:          精确匹配，完全命中                           │    │
│  │  restore-keys: 前缀匹配，部分命中（回退策略）               │    │
│  │                                                             │    │
│  │  推荐格式:                                                  │    │
│  │  key: {type}-{os}-{arch}-{hash}                            │    │
│  │  restore-keys:                                              │    │
│  │    - {type}-{os}-{arch}-                                   │    │
│  │    - {type}-{os}-                                          │    │
│  └────────────────────────────────────────────────────────────┘    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

```yaml
# ==========================================
# 完整缓存配置示例
# ==========================================
name: Cached Build

on: [push, pull_request]

env:
  VCPKG_BINARY_SOURCES: "clear;x-gha,readwrite"

jobs:
  build:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-22.04, windows-2022, macos-13]

    steps:
      - uses: actions/checkout@v4

      # 1. vcpkg 二进制缓存（使用 GitHub Actions 缓存后端）
      - name: Export GitHub Actions cache environment
        uses: actions/github-script@v7
        with:
          script: |
            core.exportVariable('ACTIONS_CACHE_URL', process.env.ACTIONS_CACHE_URL || '');
            core.exportVariable('ACTIONS_RUNTIME_TOKEN', process.env.ACTIONS_RUNTIME_TOKEN || '');

      - name: Setup vcpkg
        uses: lukka/run-vcpkg@v11
        with:
          vcpkgGitCommitId: 'a34c873a9717a888f58dc05268dea15592c2f0ff'

      # 2. ccache 编译缓存
      - name: Setup ccache (Linux/macOS)
        if: runner.os != 'Windows'
        run: |
          if [[ "$RUNNER_OS" == "Linux" ]]; then
            sudo apt-get install -y ccache
          else
            brew install ccache
          fi
          echo "CCACHE_DIR=${{ github.workspace }}/.ccache" >> $GITHUB_ENV
          ccache --set-config=max_size=500M
          ccache --set-config=compression=true

      - name: Cache ccache
        if: runner.os != 'Windows'
        uses: actions/cache@v4
        with:
          path: .ccache
          key: ccache-${{ matrix.os }}-${{ github.ref }}-${{ github.sha }}
          restore-keys: |
            ccache-${{ matrix.os }}-${{ github.ref }}-
            ccache-${{ matrix.os }}-refs/heads/main-
            ccache-${{ matrix.os }}-

      # 3. sccache (跨平台编译缓存，支持 Windows)
      - name: Setup sccache
        uses: mozilla-actions/sccache-action@v0.0.4

      - name: Configure sccache
        run: |
          echo "CMAKE_C_COMPILER_LAUNCHER=sccache" >> $GITHUB_ENV
          echo "CMAKE_CXX_COMPILER_LAUNCHER=sccache" >> $GITHUB_ENV

      # 4. CMake 配置缓存
      - name: Cache CMake build
        uses: actions/cache@v4
        with:
          path: build
          key: cmake-${{ matrix.os }}-${{ hashFiles('CMakeLists.txt', 'cmake/**', 'vcpkg.json') }}-${{ github.sha }}
          restore-keys: |
            cmake-${{ matrix.os }}-${{ hashFiles('CMakeLists.txt', 'cmake/**', 'vcpkg.json') }}-
            cmake-${{ matrix.os }}-

      - name: Configure
        run: |
          cmake -B build -S . \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_TOOLCHAIN_FILE=${{ env.VCPKG_ROOT }}/scripts/buildsystems/vcpkg.cmake

      - name: Build
        run: cmake --build build --config Release --parallel

      # 5. 显示缓存统计
      - name: Show ccache stats
        if: runner.os != 'Windows'
        run: ccache --show-stats

      - name: Show sccache stats
        run: sccache --show-stats
```

#### Artifact 管理最佳实践

```yaml
# ==========================================
# Artifact 上传与下载
# ==========================================

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build
        run: cmake -B build && cmake --build build

      # 上传构建产物
      - name: Upload build artifacts
        uses: actions/upload-artifact@v4
        with:
          name: build-linux-x64
          path: |
            build/bin/
            build/lib/
            !build/**/*.o        # 排除中间文件
            !build/**/*.obj
          retention-days: 7       # 保留天数（默认90天）
          compression-level: 6    # 压缩级别 0-9
          if-no-files-found: error  # warn/ignore/error

      # 上传测试报告
      - name: Upload test results
        if: always()              # 测试失败也上传
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: |
            build/Testing/
            build/*.xml
          retention-days: 30

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      # 下载单个artifact
      - name: Download build artifact
        uses: actions/download-artifact@v4
        with:
          name: build-linux-x64
          path: ./dist

      # 下载所有artifacts
      - name: Download all artifacts
        uses: actions/download-artifact@v4
        with:
          path: ./all-artifacts
          # 不指定name则下载所有

      # 合并多个artifact
      - name: Merge artifacts
        uses: actions/upload-artifact/merge@v4
        with:
          name: combined-packages
          pattern: build-*
          delete-merged: true

# ==========================================
# Artifact 使用场景
# ==========================================
#
# 1. 跨Job传递构建产物
#    build job → test job → deploy job
#
# 2. 保存测试报告和覆盖率
#    - JUnit XML → GitHub Actions 测试摘要
#    - Coverage XML → Codecov/Coveralls
#
# 3. 保存失败日志用于调试
#    if: failure()
#
# 4. 发布Release资产
#    build → upload-artifact → download-artifact → gh release create
#
# 注意事项:
# - Artifact 有大小限制（公开仓库最大 500MB）
# - 不要上传敏感信息（secrets、tokens）
# - 合理设置 retention-days 控制存储成本
```

#### 失败处理与重试策略

```yaml
# ==========================================
# 失败处理与重试
# ==========================================

jobs:
  flaky-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # 方法1: continue-on-error (不影响整体状态)
      - name: Run flaky tests
        id: flaky
        continue-on-error: true
        run: ./run_flaky_tests.sh

      - name: Handle flaky test result
        if: steps.flaky.outcome == 'failure'
        run: echo "Flaky tests failed, but continuing..."

      # 方法2: 使用retry action
      - name: Run with retry
        uses: nick-fields/retry@v3
        with:
          timeout_minutes: 10
          max_attempts: 3
          retry_wait_seconds: 30
          command: ./run_integration_tests.sh
          retry_on: error
          # retry_on: timeout / any

      # 方法3: Shell级别重试
      - name: Manual retry logic
        run: |
          max_retries=3
          count=0
          until ./test.sh; do
            count=$((count + 1))
            if [ $count -ge $max_retries ]; then
              echo "Max retries reached"
              exit 1
            fi
            echo "Attempt $count failed, retrying in 10s..."
            sleep 10
          done

      # 方法4: 网络请求重试
      - name: Download with retry
        run: |
          curl --retry 5 --retry-delay 10 --retry-all-errors \
            -o file.tar.gz https://example.com/file.tar.gz

  # 在Job失败时保存调试信息
  debug-on-failure:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build
        id: build
        run: cmake -B build && cmake --build build

      # 失败时上传日志
      - name: Upload logs on failure
        if: failure() && steps.build.outcome == 'failure'
        uses: actions/upload-artifact@v4
        with:
          name: build-logs
          path: |
            build/CMakeFiles/CMakeOutput.log
            build/CMakeFiles/CMakeError.log
            build/**/*.log

      # 失败时启用SSH调试（tmate）
      - name: Setup tmate session on failure
        if: failure()
        uses: mxschmitt/action-tmate@v3
        with:
          limit-access-to-actor: true

# ==========================================
# Job级别的重试（使用reusable workflow）
# ==========================================
jobs:
  call-with-retry:
    strategy:
      fail-fast: false
      matrix:
        attempt: [1, 2, 3]
    if: |
      matrix.attempt == 1 ||
      (matrix.attempt == 2 && needs.call-with-retry.result == 'failure') ||
      (matrix.attempt == 3 && needs.call-with-retry.result == 'failure')
    uses: ./.github/workflows/build.yml
```

#### Week 2 输出物清单

| 文件 | 说明 | 完成状态 |
|------|------|---------|
| `notes/cpp_ci_design.md` | C++ CI流水线设计笔记 | [ ] |
| `.github/workflows/build.yml` | 多平台构建配置 | [ ] |
| `notes/matrix_strategy.md` | Matrix策略详解 | [ ] |
| `practice/multiplatform/` | 多平台构建练习 | [ ] |
| `notes/caching_guide.md` | 缓存策略指南 | [ ] |
| `.github/workflows/cached-build.yml` | 带缓存的构建配置 | [ ] |
| `.github/workflows/test.yml` | 测试与覆盖率配置 | [ ] |

#### Week 2 检验标准

- [ ] 能够设计完整的C++项目CI流水线（代码检查→构建→测试→打包）
- [ ] 掌握Matrix策略的include/exclude用法
- [ ] 能够实现Linux/Windows/macOS三平台并行构建
- [ ] 理解缓存的三个层次（依赖/编译/构建）
- [ ] 能够配置vcpkg二进制缓存提升构建速度
- [ ] 掌握ccache/sccache的CI集成
- [ ] 能够正确使用Artifact进行跨Job数据传递
- [ ] 理解continue-on-error与失败重试策略

---

### 第三周：高级Actions特性（35小时）

```
┌─────────────────────────────────────────────────────────────────┐
│  Week 3: GitHub Actions 高级特性                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Day 15-16: Job 依赖与数据传递                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Job A ──needs──► Job B ──needs──► Job C                 │   │
│  │    │                │                │                   │   │
│  │    └──outputs───────┴───outputs──────┘                   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Day 17-18: 安全管理与环境保护                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Secrets (加密) │ Variables (明文) │ Environments        │   │
│  │  ├── repo级    │ ├── repo级       │ ├── 保护规则        │   │
│  │  ├── org级     │ └── env级        │ └── 审批流程        │   │
│  │  └── env级     │                   │                     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Day 19-21: 可复用工作流与自定义 Action                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Reusable Workflow │ Composite Action │ JS/Docker Action │   │
│  │  (workflow_call)   │ (runs: composite)│ (全功能)         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### 每日任务分解

| Day | 时间 | 上午任务(2.5h) | 下午任务(2.5h) | 输出物 |
|-----|------|---------------|---------------|--------|
| 15 | 5h | Job依赖关系(needs) | Job outputs传递数据 | notes/job_dependencies.md |
| 16 | 5h | 条件执行(if)深入 | 状态函数(always/failure) | practice/conditional_jobs/ |
| 17 | 5h | Secrets安全管理 | Variables与Environments | notes/security_guide.md |
| 18 | 5h | Environment保护规则 | OIDC与云服务集成 | notes/oidc_integration.md |
| 19 | 5h | Reusable Workflows设计 | workflow_call实战 | .github/workflows/reusable-*.yml |
| 20 | 5h | Composite Action编写 | Action输入输出设计 | .github/actions/setup-cpp/ |
| 21 | 5h | 并发控制(concurrency) | 资源优化与成本控制 | notes/resource_optimization.md |

**学习目标**：掌握缓存、矩阵构建、条件执行等高级特性

**阅读材料**：
- [ ] GitHub Actions: Reusable workflows
- [ ] GitHub Actions: Composite actions
- [ ] GitHub Actions: Security best practices

```yaml
# ==========================================
# .github/workflows/advanced.yml - 高级特性
# ==========================================
name: Advanced CI

on:
  push:
    branches: [main]
  pull_request:
  schedule:
    - cron: '0 0 * * 0'  # 每周日运行

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read
  packages: write

jobs:
  # 预检查
  pre-check:
    runs-on: ubuntu-latest
    outputs:
      should_skip: ${{ steps.skip_check.outputs.should_skip }}
    steps:
      - id: skip_check
        uses: fkirc/skip-duplicate-actions@v5
        with:
          concurrent_skipping: 'same_content_newer'

  # 代码检查
  lint:
    needs: pre-check
    if: needs.pre-check.outputs.should_skip != 'true'
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Run clang-format
        uses: jidiber/clang-format-action@v4
        with:
          clang-format-version: '15'
          check-path: 'src'

      - name: Run clang-tidy
        run: |
          cmake -B build -S . -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
          clang-tidy-15 -p build src/*.cpp

  # 多平台构建
  build:
    needs: [pre-check, lint]
    if: needs.pre-check.outputs.should_skip != 'true'
    strategy:
      matrix:
        include:
          - os: ubuntu-22.04
            triplet: x64-linux
          - os: windows-2022
            triplet: x64-windows
          - os: macos-13
            triplet: x64-osx

    runs-on: ${{ matrix.os }}

    steps:
      - uses: actions/checkout@v4

      # 缓存CMake构建
      - name: Cache CMake build
        uses: actions/cache@v4
        with:
          path: build
          key: build-${{ matrix.os }}-${{ hashFiles('CMakeLists.txt', 'src/**') }}
          restore-keys: |
            build-${{ matrix.os }}-

      # 缓存vcpkg
      - name: Cache vcpkg
        uses: actions/cache@v4
        with:
          path: |
            ~/.cache/vcpkg
            ~/AppData/Local/vcpkg
          key: vcpkg-${{ matrix.triplet }}-${{ hashFiles('vcpkg.json') }}
          restore-keys: |
            vcpkg-${{ matrix.triplet }}-

      - name: Setup vcpkg
        uses: lukka/run-vcpkg@v11

      - name: Configure
        run: |
          cmake -B build -S . \
            -DCMAKE_TOOLCHAIN_FILE=${{ env.VCPKG_ROOT }}/scripts/buildsystems/vcpkg.cmake \
            -DVCPKG_TARGET_TRIPLET=${{ matrix.triplet }}

      - name: Build
        run: cmake --build build --config Release

      - name: Test
        run: ctest --test-dir build -C Release --output-on-failure

      - name: Package
        run: |
          cmake --build build --target package
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'

      - name: Upload package
        uses: actions/upload-artifact@v4
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        with:
          name: package-${{ matrix.os }}
          path: build/*.tar.gz

  # 发布
  release:
    needs: build
    if: github.event_name == 'push' && startsWith(github.ref, 'refs/tags/')
    runs-on: ubuntu-latest

    steps:
      - name: Download all artifacts
        uses: actions/download-artifact@v4

      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            package-*/*.tar.gz
          generate_release_notes: true
```

```yaml
# ==========================================
# .github/workflows/reusable-build.yml - 可复用工作流
# ==========================================
name: Reusable Build

on:
  workflow_call:
    inputs:
      os:
        required: true
        type: string
      build_type:
        required: false
        type: string
        default: 'Release'
      cmake_args:
        required: false
        type: string
        default: ''
    secrets:
      token:
        required: false

jobs:
  build:
    runs-on: ${{ inputs.os }}

    steps:
      - uses: actions/checkout@v4

      - name: Configure
        run: |
          cmake -B build -S . \
            -DCMAKE_BUILD_TYPE=${{ inputs.build_type }} \
            ${{ inputs.cmake_args }}

      - name: Build
        run: cmake --build build --config ${{ inputs.build_type }}

      - name: Test
        run: ctest --test-dir build -C ${{ inputs.build_type }}
```

```yaml
# ==========================================
# 调用可复用工作流
# ==========================================
name: Multi-platform Build

on: push

jobs:
  linux:
    uses: ./.github/workflows/reusable-build.yml
    with:
      os: ubuntu-22.04
      build_type: Release

  windows:
    uses: ./.github/workflows/reusable-build.yml
    with:
      os: windows-2022
      build_type: Release
      cmake_args: '-A x64'

  macos:
    uses: ./.github/workflows/reusable-build.yml
    with:
      os: macos-13
```

#### Job 依赖关系图

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Job 依赖与数据流                                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  基本依赖 (needs)                                                   │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │                                                             │    │
│  │    ┌─────┐                                                  │    │
│  │    │lint │ ───────────────┐                                │    │
│  │    └─────┘                │                                │    │
│  │                           ▼                                │    │
│  │    ┌─────┐          ┌─────────┐          ┌────────┐       │    │
│  │    │build│─needs───►│  test   │─needs───►│release │       │    │
│  │    │linux│          │         │          │        │       │    │
│  │    └─────┘          └─────────┘          └────────┘       │    │
│  │                           ▲                                │    │
│  │    ┌─────┐                │                                │    │
│  │    │build│────────────────┘                                │    │
│  │    │win  │                                                  │    │
│  │    └─────┘                                                  │    │
│  │                                                             │    │
│  │  needs: [lint, build-linux, build-win]  # 多依赖            │    │
│  │                                                             │    │
│  └────────────────────────────────────────────────────────────┘    │
│                                                                     │
│  数据传递 (outputs)                                                 │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │                                                             │    │
│  │  Job A (prepare)                    Job B (build)          │    │
│  │  ┌─────────────────────┐           ┌─────────────────────┐│    │
│  │  │ outputs:            │           │                     ││    │
│  │  │   version: "1.2.3"  │──────────►│ ${{ needs.prepare  ││    │
│  │  │   matrix: "[...]"   │           │   .outputs.version }}│    │
│  │  └─────────────────────┘           └─────────────────────┘│    │
│  │                                                             │    │
│  │  Step outputs → Job outputs → Job needs.*.outputs          │    │
│  │                                                             │    │
│  └────────────────────────────────────────────────────────────┘    │
│                                                                     │
│  条件执行 (if)                                                      │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │                                                             │    │
│  │  Job级别:                                                   │    │
│  │  if: github.event_name == 'push'                           │    │
│  │  if: needs.build.result == 'success'                       │    │
│  │  if: always()  # 总是运行                                   │    │
│  │  if: failure() # 前置失败时运行                             │    │
│  │  if: cancelled() # 取消时运行                               │    │
│  │                                                             │    │
│  │  常用模式:                                                  │    │
│  │  if: always() && needs.build.result == 'success'           │    │
│  │  if: github.ref == 'refs/heads/main' && github.event_name != 'pull_request'│
│  │  if: contains(github.event.head_commit.message, '[skip ci]') == false     │
│  │                                                             │    │
│  └────────────────────────────────────────────────────────────┘    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

```yaml
# ==========================================
# Job依赖与数据传递完整示例
# ==========================================

jobs:
  # 准备阶段：提取版本、生成矩阵
  prepare:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.version.outputs.version }}
      matrix: ${{ steps.matrix.outputs.matrix }}
      should_deploy: ${{ steps.check.outputs.should_deploy }}

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Extract version
        id: version
        run: |
          if [[ "$GITHUB_REF" == refs/tags/* ]]; then
            version="${GITHUB_REF#refs/tags/v}"
          else
            version="0.0.0-$(git rev-parse --short HEAD)"
          fi
          echo "version=$version" >> $GITHUB_OUTPUT

      - name: Generate matrix
        id: matrix
        run: |
          # 根据条件生成不同的构建矩阵
          if [[ "${{ github.event_name }}" == "schedule" ]]; then
            matrix='{"os":["ubuntu-22.04","windows-2022","macos-13"]}'
          elif [[ "${{ github.ref }}" == "refs/heads/main" ]]; then
            matrix='{"os":["ubuntu-22.04","windows-2022"]}'
          else
            matrix='{"os":["ubuntu-22.04"]}'
          fi
          echo "matrix=$matrix" >> $GITHUB_OUTPUT

      - name: Check deployment conditions
        id: check
        run: |
          if [[ "$GITHUB_REF" == refs/tags/v* ]]; then
            echo "should_deploy=true" >> $GITHUB_OUTPUT
          else
            echo "should_deploy=false" >> $GITHUB_OUTPUT
          fi

  # 构建阶段：使用prepare的输出
  build:
    needs: prepare
    strategy:
      matrix: ${{ fromJSON(needs.prepare.outputs.matrix) }}
    runs-on: ${{ matrix.os }}

    outputs:
      artifact_name: ${{ steps.package.outputs.artifact_name }}

    steps:
      - uses: actions/checkout@v4

      - name: Build with version
        run: |
          echo "Building version ${{ needs.prepare.outputs.version }}"
          cmake -B build -DPROJECT_VERSION=${{ needs.prepare.outputs.version }}
          cmake --build build

      - name: Package
        id: package
        run: |
          artifact_name="myapp-${{ needs.prepare.outputs.version }}-${{ matrix.os }}"
          echo "artifact_name=$artifact_name" >> $GITHUB_OUTPUT

      - uses: actions/upload-artifact@v4
        with:
          name: ${{ steps.package.outputs.artifact_name }}
          path: build/bin/

  # 测试阶段：依赖构建成功
  test:
    needs: [prepare, build]
    runs-on: ubuntu-latest
    steps:
      - run: echo "Testing version ${{ needs.prepare.outputs.version }}"

  # 部署阶段：条件执行
  deploy:
    needs: [prepare, build, test]
    if: needs.prepare.outputs.should_deploy == 'true'
    runs-on: ubuntu-latest
    environment: production
    steps:
      - run: echo "Deploying version ${{ needs.prepare.outputs.version }}"

  # 状态聚合：总是运行
  status:
    needs: [build, test]
    if: always()
    runs-on: ubuntu-latest
    steps:
      - name: Check overall status
        run: |
          echo "Build result: ${{ needs.build.result }}"
          echo "Test result: ${{ needs.test.result }}"

          if [[ "${{ needs.build.result }}" != "success" ]]; then
            echo "Build failed!"
            exit 1
          fi

          if [[ "${{ needs.test.result }}" != "success" ]]; then
            echo "Tests failed!"
            exit 1
          fi

          echo "All checks passed!"
```

#### Secrets 和环境变量安全管理

```
┌─────────────────────────────────────────────────────────────────────┐
│                    安全管理层次结构                                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Secrets (加密存储，日志脱敏)                                       │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │                                                             │    │
│  │  Organization Secrets (组织级)                              │    │
│  │  ├── 所有仓库可用（或指定仓库）                              │    │
│  │  ├── 示例: DOCKER_HUB_TOKEN, NPM_TOKEN                     │    │
│  │  └── Settings → Secrets → Actions                          │    │
│  │                                                             │    │
│  │  Repository Secrets (仓库级)                                │    │
│  │  ├── 仅当前仓库可用                                         │    │
│  │  ├── 示例: CODECOV_TOKEN, DEPLOY_KEY                       │    │
│  │  └── 覆盖同名 Org Secrets                                   │    │
│  │                                                             │    │
│  │  Environment Secrets (环境级)                               │    │
│  │  ├── 仅指定 environment 的 Job 可用                        │    │
│  │  ├── 示例: PROD_DATABASE_URL, PROD_API_KEY                 │    │
│  │  └── 配合保护规则使用                                       │    │
│  │                                                             │    │
│  │  访问方式: ${{ secrets.SECRET_NAME }}                       │    │
│  │  注意: Fork的PR无法访问secrets（安全考虑）                   │    │
│  │                                                             │    │
│  └────────────────────────────────────────────────────────────┘    │
│                                                                     │
│  Variables (明文存储，可在日志显示)                                 │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │                                                             │    │
│  │  适用场景:                                                  │    │
│  │  ├── 配置值（非敏感）                                       │    │
│  │  ├── 版本号、环境名称                                       │    │
│  │  └── 特性开关                                               │    │
│  │                                                             │    │
│  │  访问方式: ${{ vars.VARIABLE_NAME }}                        │    │
│  │                                                             │    │
│  └────────────────────────────────────────────────────────────┘    │
│                                                                     │
│  Environment 保护规则                                               │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │                                                             │    │
│  │  ┌─────────────────┐    ┌─────────────────┐               │    │
│  │  │    staging      │    │   production    │               │    │
│  │  │ ─────────────── │    │ ─────────────── │               │    │
│  │  │ • 无需审批      │    │ • 需要审批      │               │    │
│  │  │ • 任何分支      │    │ • 仅main/tags   │               │    │
│  │  │                 │    │ • 等待30分钟    │               │    │
│  │  └─────────────────┘    └─────────────────┘               │    │
│  │                                                             │    │
│  │  配置项:                                                    │    │
│  │  ├── Required reviewers (必需审批人)                       │    │
│  │  ├── Wait timer (等待时间)                                 │    │
│  │  ├── Deployment branches (允许的分支)                      │    │
│  │  └── Environment secrets (环境专属secrets)                 │    │
│  │                                                             │    │
│  └────────────────────────────────────────────────────────────┘    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

```yaml
# ==========================================
# 安全管理实战配置
# ==========================================

jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    environment:
      name: staging
      url: https://staging.example.com

    steps:
      - uses: actions/checkout@v4

      # 使用 environment 专属的 secrets
      - name: Deploy to staging
        env:
          API_KEY: ${{ secrets.STAGING_API_KEY }}
          DATABASE_URL: ${{ secrets.STAGING_DATABASE_URL }}
        run: ./deploy.sh staging

  deploy-production:
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://example.com

    # 仅在特定条件下部署到生产
    if: github.ref == 'refs/heads/main' || startsWith(github.ref, 'refs/tags/v')

    steps:
      - uses: actions/checkout@v4

      # 生产环境使用 OIDC 认证（无需存储长期凭证）
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789:role/github-actions
          aws-region: us-east-1

      - name: Deploy to production
        env:
          API_KEY: ${{ secrets.PROD_API_KEY }}
        run: ./deploy.sh production

# ==========================================
# OIDC (OpenID Connect) 无密钥认证
# ==========================================
# 原理: GitHub Actions 签发 JWT，云服务验证后授权
# 优点: 无需存储长期凭证，更安全
# 支持: AWS, Azure, GCP, HashiCorp Vault

permissions:
  id-token: write  # 允许请求OIDC token
  contents: read

jobs:
  deploy-aws:
    runs-on: ubuntu-latest
    steps:
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789:role/GitHubActions
          role-session-name: github-actions-session
          aws-region: us-east-1
          # 无需 aws-access-key-id 和 aws-secret-access-key

      - name: Use AWS CLI
        run: aws s3 ls

  deploy-gcp:
    runs-on: ubuntu-latest
    steps:
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: projects/123/locations/global/workloadIdentityPools/github/providers/github
          service_account: github-actions@project.iam.gserviceaccount.com

      - name: Use gcloud CLI
        run: gcloud compute instances list
```

#### Action 类型对比

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Action 三种类型对比                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │                   Composite Action                          │    │
│  ├────────────────────────────────────────────────────────────┤    │
│  │  定义: action.yml + runs: composite                        │    │
│  │                                                             │    │
│  │  优点:                                                      │    │
│  │  ├── 纯YAML，无需编程                                       │    │
│  │  ├── 可组合现有actions和shell命令                           │    │
│  │  └── 维护简单，易于理解                                     │    │
│  │                                                             │    │
│  │  缺点:                                                      │    │
│  │  ├── 无法使用secrets（需通过inputs传递）                    │    │
│  │  ├── 逻辑复杂时YAML难以维护                                 │    │
│  │  └── 调试不如JS灵活                                         │    │
│  │                                                             │    │
│  │  适用: 封装常用步骤组合、简单工具配置                       │    │
│  └────────────────────────────────────────────────────────────┘    │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │                  JavaScript Action                          │    │
│  ├────────────────────────────────────────────────────────────┤    │
│  │  定义: action.yml + runs: node20                           │    │
│  │                                                             │    │
│  │  优点:                                                      │    │
│  │  ├── 全功能：直接访问GitHub API、文件系统                   │    │
│  │  ├── 使用 @actions/core, @actions/github 等官方库          │    │
│  │  ├── 启动快（无需拉取容器）                                 │    │
│  │  └── 跨平台运行                                             │    │
│  │                                                             │    │
│  │  缺点:                                                      │    │
│  │  ├── 需要Node.js编程知识                                    │    │
│  │  ├── 需要打包（ncc）                                        │    │
│  │  └── 依赖管理较复杂                                         │    │
│  │                                                             │    │
│  │  适用: 复杂逻辑、GitHub API交互、跨平台工具                 │    │
│  └────────────────────────────────────────────────────────────┘    │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │                    Docker Action                            │    │
│  ├────────────────────────────────────────────────────────────┤    │
│  │  定义: action.yml + runs: docker                           │    │
│  │                                                             │    │
│  │  优点:                                                      │    │
│  │  ├── 环境隔离：完全控制运行环境                             │    │
│  │  ├── 可使用任何语言/工具                                    │    │
│  │  └── 复杂依赖易于管理                                       │    │
│  │                                                             │    │
│  │  缺点:                                                      │    │
│  │  ├── 仅支持Linux runners                                   │    │
│  │  ├── 启动慢（需构建/拉取镜像）                              │    │
│  │  └── 镜像大小影响性能                                       │    │
│  │                                                             │    │
│  │  适用: 特殊环境要求、非Node工具链、复杂依赖场景             │    │
│  └────────────────────────────────────────────────────────────┘    │
│                                                                     │
│  选择决策:                                                          │
│  ┌─────────────────────────────────────────────────────────┐       │
│  │  需要组合现有步骤? ─Yes→ Composite                        │       │
│  │       │No                                                 │       │
│  │       ▼                                                   │       │
│  │  需要特殊环境? ─Yes→ Docker                               │       │
│  │       │No                                                 │       │
│  │       ▼                                                   │       │
│  │  JavaScript Action (默认最佳选择)                         │       │
│  └─────────────────────────────────────────────────────────┘       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

#### 可复用工作流设计模式

```yaml
# ==========================================
# .github/workflows/reusable-cpp-build.yml
# 可复用的C++构建工作流
# ==========================================
name: Reusable C++ Build

on:
  workflow_call:
    inputs:
      os:
        description: 'Runner OS'
        required: true
        type: string
      build_type:
        description: 'CMake build type'
        required: false
        type: string
        default: 'Release'
      cmake_args:
        description: 'Additional CMake arguments'
        required: false
        type: string
        default: ''
      run_tests:
        description: 'Whether to run tests'
        required: false
        type: boolean
        default: true
      artifact_name:
        description: 'Name for the build artifact'
        required: false
        type: string
        default: ''

    secrets:
      codecov_token:
        description: 'Codecov upload token'
        required: false

    outputs:
      artifact_path:
        description: 'Path to build artifacts'
        value: ${{ jobs.build.outputs.artifact_path }}
      test_result:
        description: 'Test result (success/failure)'
        value: ${{ jobs.build.outputs.test_result }}

jobs:
  build:
    runs-on: ${{ inputs.os }}
    outputs:
      artifact_path: ${{ steps.upload.outputs.artifact-path }}
      test_result: ${{ steps.test.outcome }}

    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Setup build environment
        uses: ./.github/actions/setup-cpp
        with:
          os: ${{ inputs.os }}

      - name: Configure CMake
        run: |
          cmake -B build -S . \
            -DCMAKE_BUILD_TYPE=${{ inputs.build_type }} \
            ${{ inputs.cmake_args }}

      - name: Build
        run: cmake --build build --config ${{ inputs.build_type }} --parallel

      - name: Test
        id: test
        if: inputs.run_tests
        run: ctest --test-dir build -C ${{ inputs.build_type }} --output-on-failure

      - name: Upload artifacts
        id: upload
        uses: actions/upload-artifact@v4
        with:
          name: ${{ inputs.artifact_name || format('build-{0}', inputs.os) }}
          path: |
            build/bin/
            build/lib/

# ==========================================
# 调用可复用工作流
# ==========================================
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  build-linux:
    uses: ./.github/workflows/reusable-cpp-build.yml
    with:
      os: ubuntu-22.04
      build_type: Release
      cmake_args: '-DBUILD_TESTS=ON'
      artifact_name: linux-release
    secrets:
      codecov_token: ${{ secrets.CODECOV_TOKEN }}

  build-windows:
    uses: ./.github/workflows/reusable-cpp-build.yml
    with:
      os: windows-2022
      build_type: Release
      cmake_args: '-A x64 -DBUILD_TESTS=ON'
      artifact_name: windows-release

  build-macos:
    uses: ./.github/workflows/reusable-cpp-build.yml
    with:
      os: macos-13
      artifact_name: macos-release

  # 使用build的outputs
  release:
    needs: [build-linux, build-windows, build-macos]
    if: startsWith(github.ref, 'refs/tags/')
    runs-on: ubuntu-latest
    steps:
      - name: Check test results
        run: |
          echo "Linux tests: ${{ needs.build-linux.outputs.test_result }}"
          echo "Windows tests: ${{ needs.build-windows.outputs.test_result }}"
```

#### 并发控制与资源优化

```yaml
# ==========================================
# 并发控制 (Concurrency)
# ==========================================

# 同一分支/PR的新提交取消旧运行
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

# 更精细的控制：按PR或commit
concurrency:
  group: |
    ${{ github.workflow }}-
    ${{ github.event.pull_request.number || github.sha }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

# 部署场景：串行执行，不取消
concurrency:
  group: deploy-${{ github.ref }}
  cancel-in-progress: false

# ==========================================
# 资源优化策略
# ==========================================

jobs:
  # 策略1: 快速失败的前置检查
  quick-checks:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - name: Check format
        run: clang-format --dry-run --Werror src/**/*.cpp
      - name: Lint
        run: cppcheck --error-exitcode=1 src/

  # 策略2: 条件跳过
  build:
    needs: quick-checks
    # 跳过 [skip ci] 提交
    if: |
      !contains(github.event.head_commit.message, '[skip ci]') &&
      !contains(github.event.head_commit.message, '[ci skip]')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: cmake -B build && cmake --build build

  # 策略3: 路径过滤
  docs:
    if: |
      github.event_name == 'push' &&
      contains(join(github.event.commits.*.modified, ','), 'docs/')
    runs-on: ubuntu-latest
    steps:
      - run: echo "Only run when docs changed"

  # 策略4: 合理使用 matrix 并行度
  matrix-build:
    strategy:
      fail-fast: true          # 快速失败
      max-parallel: 3          # 限制并行数，控制成本
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
    runs-on: ${{ matrix.os }}
    timeout-minutes: 30        # 设置超时
    steps:
      - uses: actions/checkout@v4
      - run: cmake -B build && cmake --build build

# ==========================================
# 成本监控
# ==========================================
# GitHub Free: 2,000分钟/月
# 计费倍率: Linux=1x, Windows=2x, macOS=10x
#
# 优化建议:
# 1. 主要测试在Linux进行
# 2. Windows/macOS仅在main/tags运行完整测试
# 3. PR仅运行快速验证
# 4. 使用缓存减少构建时间
# 5. 使用timeout-minutes防止卡死任务
```

#### Week 3 输出物清单

| 文件 | 说明 | 完成状态 |
|------|------|---------|
| `notes/job_dependencies.md` | Job依赖与数据传递 | [ ] |
| `practice/conditional_jobs/` | 条件执行练习 | [ ] |
| `notes/security_guide.md` | 安全管理指南 | [ ] |
| `notes/oidc_integration.md` | OIDC云服务集成 | [ ] |
| `.github/workflows/reusable-*.yml` | 可复用工作流 | [ ] |
| `.github/actions/setup-cpp/` | 自定义Composite Action | [ ] |
| `notes/resource_optimization.md` | 资源优化策略 | [ ] |

#### Week 3 检验标准

- [ ] 能够设计复杂的Job依赖关系图
- [ ] 掌握Job outputs在跨Job数据传递中的使用
- [ ] 理解Secrets/Variables/Environments三层安全机制
- [ ] 能够配置Environment保护规则（审批、分支限制）
- [ ] 了解OIDC无密钥认证原理及AWS/GCP配置
- [ ] 能够编写可复用工作流（workflow_call）
- [ ] 能够区分三种Action类型并选择合适的实现方式
- [ ] 掌握concurrency并发控制和成本优化策略

---

### 第四周：自定义Action与发布流程（35小时）

```
┌─────────────────────────────────────────────────────────────────┐
│  Week 4: 自定义 Action 与完整发布流程                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Day 22-23: 自定义 Action 开发                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  action.yml → inputs/outputs → runs: composite/node     │   │
│  │  本地测试 → 发布到Marketplace → 版本管理                  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Day 24-25: 完整发布流程设计                                     │
│  ┌───────┐  ┌───────┐  ┌───────┐  ┌───────┐  ┌───────┐       │
│  │  Tag  │→│ Build │→│ Test  │→│Package│→│Release│       │
│  │ Push  │  │       │  │       │  │       │  │       │       │
│  └───────┘  └───────┘  └───────┘  └───────┘  └───────┘       │
│                                                                 │
│  Day 26-28: 安全扫描与文档自动化                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  CodeQL │ Dependabot │ Secret Scanning │ Pages Deploy   │   │
│  │  代码扫描│  依赖更新   │   密钥检测      │  文档部署     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### 每日任务分解

| Day | 时间 | 上午任务(2.5h) | 下午任务(2.5h) | 输出物 |
|-----|------|---------------|---------------|--------|
| 22 | 5h | Composite Action编写 | action.yml语法详解 | .github/actions/lint-cpp/ |
| 23 | 5h | JavaScript Action基础 | @actions/core使用 | notes/js_action_guide.md |
| 24 | 5h | 语义版本与Conventional Commits | Changelog自动生成 | notes/semantic_versioning.md |
| 25 | 5h | 完整Release Workflow | GitHub Container Registry | .github/workflows/release.yml |
| 26 | 5h | CodeQL代码扫描配置 | Dependabot配置 | .github/workflows/codeql.yml |
| 27 | 5h | GitHub Pages文档部署 | Doxygen/MkDocs集成 | .github/workflows/docs.yml |
| 28 | 5h | 综合项目完善 | CI模板最终测试 | 完整CI/CD模板 |

**学习目标**：创建自定义Action，实现完整的发布流程

**阅读材料**：
- [ ] GitHub Actions: Creating actions
- [ ] Semantic Release
- [ ] GitHub Container Registry

```yaml
# ==========================================
# .github/actions/setup-cpp/action.yml - 自定义Composite Action
# ==========================================
name: 'Setup C++ Environment'
description: 'Setup C++ build environment with compiler and package manager'

inputs:
  compiler:
    description: 'Compiler to use (gcc, clang, msvc)'
    required: true
  compiler-version:
    description: 'Compiler version'
    required: false
    default: 'latest'
  package-manager:
    description: 'Package manager (vcpkg, conan, none)'
    required: false
    default: 'vcpkg'

outputs:
  compiler-path:
    description: 'Path to the compiler'
    value: ${{ steps.setup.outputs.compiler-path }}

runs:
  using: 'composite'
  steps:
    - name: Setup GCC
      if: inputs.compiler == 'gcc' && runner.os == 'Linux'
      shell: bash
      run: |
        sudo apt-get update
        sudo apt-get install -y g++-${{ inputs.compiler-version }}
        echo "CC=gcc-${{ inputs.compiler-version }}" >> $GITHUB_ENV
        echo "CXX=g++-${{ inputs.compiler-version }}" >> $GITHUB_ENV

    - name: Setup Clang
      if: inputs.compiler == 'clang' && runner.os == 'Linux'
      shell: bash
      run: |
        wget https://apt.llvm.org/llvm.sh
        chmod +x llvm.sh
        sudo ./llvm.sh ${{ inputs.compiler-version }}
        echo "CC=clang-${{ inputs.compiler-version }}" >> $GITHUB_ENV
        echo "CXX=clang++-${{ inputs.compiler-version }}" >> $GITHUB_ENV

    - name: Setup MSVC
      if: inputs.compiler == 'msvc'
      uses: ilammy/msvc-dev-cmd@v1
      with:
        arch: x64

    - name: Setup vcpkg
      if: inputs.package-manager == 'vcpkg'
      uses: lukka/run-vcpkg@v11

    - name: Setup Conan
      if: inputs.package-manager == 'conan'
      shell: bash
      run: |
        pip install conan
        conan profile detect
```

```yaml
# ==========================================
# .github/workflows/release.yml - 完整发布流程
# ==========================================
name: Release

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write
  packages: write

jobs:
  # 构建各平台
  build:
    strategy:
      matrix:
        include:
          - os: ubuntu-22.04
            artifact: linux-x64
            archive: tar.gz
          - os: windows-2022
            artifact: windows-x64
            archive: zip
          - os: macos-13
            artifact: macos-x64
            archive: tar.gz

    runs-on: ${{ matrix.os }}
    outputs:
      version: ${{ steps.version.outputs.version }}

    steps:
      - uses: actions/checkout@v4

      - name: Get version
        id: version
        shell: bash
        run: echo "version=${GITHUB_REF#refs/tags/v}" >> $GITHUB_OUTPUT

      - name: Setup environment
        uses: ./.github/actions/setup-cpp
        with:
          compiler: ${{ matrix.os == 'windows-2022' && 'msvc' || 'clang' }}
          package-manager: vcpkg

      - name: Configure
        run: |
          cmake -B build -S . \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_TOOLCHAIN_FILE=${{ env.VCPKG_ROOT }}/scripts/buildsystems/vcpkg.cmake \
            -DCPACK_PACKAGE_VERSION=${{ steps.version.outputs.version }}

      - name: Build
        run: cmake --build build --config Release

      - name: Test
        run: ctest --test-dir build -C Release --output-on-failure

      - name: Package
        run: |
          cd build
          cpack -G ${{ matrix.os == 'windows-2022' && 'ZIP' || 'TGZ' }}

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: ${{ matrix.artifact }}
          path: build/*.${{ matrix.archive }}

  # Docker镜像
  docker:
    runs-on: ubuntu-latest
    needs: build

    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: |
            ghcr.io/${{ github.repository }}:${{ needs.build.outputs.version }}
            ghcr.io/${{ github.repository }}:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max

  # 创建GitHub Release
  release:
    runs-on: ubuntu-latest
    needs: [build, docker]

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Download all artifacts
        uses: actions/download-artifact@v4
        with:
          path: artifacts

      - name: Generate changelog
        id: changelog
        uses: orhun/git-cliff-action@v3
        with:
          config: cliff.toml
          args: --latest --strip header

      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          body: ${{ steps.changelog.outputs.content }}
          files: artifacts/**/*
          generate_release_notes: false
```

```dockerfile
# Dockerfile - 用于CI/CD的Docker镜像
FROM ubuntu:22.04 AS builder

RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    curl \
    zip \
    unzip \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# 安装vcpkg
RUN git clone https://github.com/microsoft/vcpkg.git /opt/vcpkg \
    && /opt/vcpkg/bootstrap-vcpkg.sh

ENV VCPKG_ROOT=/opt/vcpkg
ENV PATH="${VCPKG_ROOT}:${PATH}"

WORKDIR /src
COPY . .

RUN cmake -B build -S . \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE=${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake

RUN cmake --build build --config Release

# 运行时镜像
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /src/build/bin/ /app/

WORKDIR /app
ENTRYPOINT ["./myapp"]
```

#### 发布流程完整架构图

```
┌─────────────────────────────────────────────────────────────────────┐
│                    完整发布流程架构                                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  触发: git tag v1.2.3 && git push --tags                           │
│                              │                                       │
│                              ▼                                       │
│  阶段1: 验证与准备                                                  │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐                 │    │
│  │  │ 提取版本  │  │ 验证格式  │  │ 生成矩阵  │                 │    │
│  │  │ v1.2.3   │→ │ semver   │→ │ 平台列表  │                 │    │
│  │  └──────────┘  └──────────┘  └──────────┘                 │    │
│  └────────────────────────────────────────────────────────────┘    │
│                              │                                       │
│                              ▼                                       │
│  阶段2: 多平台构建                                                  │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │        ┌─────────────────────────────────────────┐         │    │
│  │        │           并行构建 (matrix)              │         │    │
│  │        └─────────────────────────────────────────┘         │    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │    │
│  │  │Linux x64 │  │Linux ARM │  │Windows   │  │  macOS   │  │    │
│  │  │ .tar.gz  │  │ .tar.gz  │  │  .zip    │  │ .tar.gz  │  │    │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │    │
│  │                              │                             │    │
│  │              上传 artifacts ─┘                             │    │
│  └────────────────────────────────────────────────────────────┘    │
│                              │                                       │
│                              ▼                                       │
│  阶段3: 测试验证                                                    │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐                 │    │
│  │  │ 单元测试  │  │ 集成测试  │  │ 安装测试  │                 │    │
│  │  │ (已通过) │→ │ (已通过) │→ │ 验证包   │                 │    │
│  │  └──────────┘  └──────────┘  └──────────┘                 │    │
│  └────────────────────────────────────────────────────────────┘    │
│                              │                                       │
│                              ▼                                       │
│  阶段4: 容器化 (可选)                                               │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐                 │    │
│  │  │Docker构建│→ │ 多架构   │→ │ 推送到   │                 │    │
│  │  │ Buildx  │  │ manifest │  │ GHCR     │                 │    │
│  │  └──────────┘  └──────────┘  └──────────┘                 │    │
│  │                                                             │    │
│  │  标签: ghcr.io/owner/repo:1.2.3, :latest, :1.2, :1        │    │
│  └────────────────────────────────────────────────────────────┘    │
│                              │                                       │
│                              ▼                                       │
│  阶段5: 发布                                                        │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │    │
│  │  │ 生成     │  │ 下载     │  │ 创建     │  │ 通知     │  │    │
│  │  │Changelog │→ │Artifacts │→ │ Release  │→ │ Slack等  │  │    │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │    │
│  │                                                             │    │
│  │  Release内容:                                               │    │
│  │  ├── myapp-1.2.3-linux-x64.tar.gz                         │    │
│  │  ├── myapp-1.2.3-linux-arm64.tar.gz                       │    │
│  │  ├── myapp-1.2.3-windows-x64.zip                          │    │
│  │  ├── myapp-1.2.3-macos-x64.tar.gz                         │    │
│  │  ├── SHA256SUMS.txt                                        │    │
│  │  └── CHANGELOG.md (自动生成)                               │    │
│  └────────────────────────────────────────────────────────────┘    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

#### Semantic Versioning 与 Conventional Commits

```
┌─────────────────────────────────────────────────────────────────────┐
│                Semantic Versioning (语义化版本)                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  版本格式: MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]                  │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                     v 1 . 2 . 3 - beta.1 + build.456        │   │
│  │                       │   │   │     │           │            │   │
│  │  MAJOR ───────────────┘   │   │     │           │            │   │
│  │  不兼容的API变更             │   │     │           │            │   │
│  │                             │   │     │           │            │   │
│  │  MINOR ─────────────────────┘   │     │           │            │   │
│  │  向后兼容的功能新增              │     │           │            │   │
│  │                                 │     │           │            │   │
│  │  PATCH ─────────────────────────┘     │           │            │   │
│  │  向后兼容的bug修复                     │           │            │   │
│  │                                       │           │            │   │
│  │  PRERELEASE ──────────────────────────┘           │            │   │
│  │  预发布标识(alpha/beta/rc)                         │            │   │
│  │                                                   │            │   │
│  │  BUILD ───────────────────────────────────────────┘            │   │
│  │  构建元数据(git sha/构建号)                                     │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  版本递增规则:                                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  提交类型           │  版本变化      │  示例                   │  │
│  ├──────────────────────────────────────────────────────────────┤  │
│  │  fix:              │  PATCH +1     │  1.2.3 → 1.2.4         │  │
│  │  feat:             │  MINOR +1     │  1.2.3 → 1.3.0         │  │
│  │  BREAKING CHANGE   │  MAJOR +1     │  1.2.3 → 2.0.0         │  │
│  │  docs/style/refactor│  无变化       │  仅更新changelog        │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                Conventional Commits (约定式提交)                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  提交格式:                                                          │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  <type>(<scope>): <subject>                                  │  │
│  │                                                              │  │
│  │  [optional body]                                             │  │
│  │                                                              │  │
│  │  [optional footer(s)]                                        │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  Type (类型):                                                       │
│  ├── feat     新功能 (触发 MINOR 版本)                             │
│  ├── fix      Bug修复 (触发 PATCH 版本)                            │
│  ├── docs     文档变更                                             │
│  ├── style    代码格式 (不影响功能)                                 │
│  ├── refactor 重构 (不修复bug也不添加功能)                         │
│  ├── perf     性能优化                                             │
│  ├── test     测试相关                                             │
│  ├── build    构建系统或外部依赖                                    │
│  ├── ci       CI配置变更                                           │
│  └── chore    其他不修改src或test的变更                            │
│                                                                     │
│  Breaking Change:                                                  │
│  ├── 在type后加!: feat!: xxx                                       │
│  └── 或在footer中: BREAKING CHANGE: xxx                           │
│                                                                     │
│  示例:                                                              │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  feat(parser): add support for JSON5 format                  │  │
│  │                                                              │  │
│  │  Added JSON5 parsing capability to the config parser.        │  │
│  │  This allows comments and trailing commas in config files.   │  │
│  │                                                              │  │
│  │  Closes #123                                                 │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  feat!: remove deprecated API endpoints                      │  │
│  │                                                              │  │
│  │  BREAKING CHANGE: The /v1/users endpoint has been removed.   │  │
│  │  Please use /v2/users instead.                               │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

#### Changelog 自动生成 (git-cliff)

```yaml
# ==========================================
# .github/workflows/release.yml (完整版)
# ==========================================
name: Release

on:
  push:
    tags:
      - 'v[0-9]+.[0-9]+.[0-9]+*'

permissions:
  contents: write
  packages: write

jobs:
  # 阶段1: 准备
  prepare:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.version.outputs.version }}
      prerelease: ${{ steps.version.outputs.prerelease }}
      changelog: ${{ steps.changelog.outputs.content }}

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Extract version
        id: version
        run: |
          version="${GITHUB_REF#refs/tags/v}"
          echo "version=$version" >> $GITHUB_OUTPUT

          # 检测预发布版本
          if [[ "$version" == *"-"* ]]; then
            echo "prerelease=true" >> $GITHUB_OUTPUT
          else
            echo "prerelease=false" >> $GITHUB_OUTPUT
          fi

      - name: Generate changelog
        id: changelog
        uses: orhun/git-cliff-action@v3
        with:
          config: cliff.toml
          args: --latest --strip header

  # 阶段2: 构建
  build:
    needs: prepare
    strategy:
      fail-fast: false
      matrix:
        include:
          - os: ubuntu-22.04
            target: linux-x64
            archive: tar.gz
          - os: ubuntu-22.04
            target: linux-arm64
            archive: tar.gz
            cross: true
          - os: windows-2022
            target: windows-x64
            archive: zip
          - os: macos-13
            target: macos-x64
            archive: tar.gz

    runs-on: ${{ matrix.os }}

    steps:
      - uses: actions/checkout@v4

      - name: Setup cross compilation (ARM64)
        if: matrix.cross
        run: |
          sudo apt-get update
          sudo apt-get install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu
          echo "CC=aarch64-linux-gnu-gcc" >> $GITHUB_ENV
          echo "CXX=aarch64-linux-gnu-g++" >> $GITHUB_ENV

      - name: Configure
        run: |
          cmake -B build -S . \
            -DCMAKE_BUILD_TYPE=Release \
            -DPROJECT_VERSION=${{ needs.prepare.outputs.version }}

      - name: Build
        run: cmake --build build --config Release --parallel

      - name: Package
        id: package
        shell: bash
        run: |
          name="myapp-${{ needs.prepare.outputs.version }}-${{ matrix.target }}"
          mkdir -p dist

          if [[ "${{ matrix.archive }}" == "zip" ]]; then
            cd build/bin && zip -r "../../dist/${name}.zip" .
          else
            tar -czvf "dist/${name}.tar.gz" -C build/bin .
          fi

          # 生成校验和
          cd dist && sha256sum "${name}.${{ matrix.archive }}" > "${name}.sha256"

      - uses: actions/upload-artifact@v4
        with:
          name: ${{ matrix.target }}
          path: dist/*

  # 阶段3: Docker镜像
  docker:
    needs: [prepare, build]
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Download Linux artifact
        uses: actions/download-artifact@v4
        with:
          name: linux-x64
          path: dist/

      - name: Extract binary
        run: |
          mkdir -p build/bin
          tar -xzf dist/*.tar.gz -C build/bin

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          platforms: linux/amd64,linux/arm64
          tags: |
            ghcr.io/${{ github.repository }}:${{ needs.prepare.outputs.version }}
            ghcr.io/${{ github.repository }}:latest
            ghcr.io/${{ github.repository }}:${{ needs.prepare.outputs.version | cut -d. -f1-2 }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  # 阶段4: 创建Release
  release:
    needs: [prepare, build, docker]
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Download all artifacts
        uses: actions/download-artifact@v4
        with:
          path: artifacts

      - name: Organize artifacts
        run: |
          mkdir -p release
          find artifacts -type f \( -name "*.tar.gz" -o -name "*.zip" -o -name "*.sha256" \) -exec cp {} release/ \;

          # 生成总校验文件
          cd release && cat *.sha256 > SHA256SUMS.txt && rm *.sha256

      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          name: v${{ needs.prepare.outputs.version }}
          body: |
            ## What's Changed

            ${{ needs.prepare.outputs.changelog }}

            ## Docker Image

            ```bash
            docker pull ghcr.io/${{ github.repository }}:${{ needs.prepare.outputs.version }}
            ```

            ## Checksums

            See `SHA256SUMS.txt` for file integrity verification.
          prerelease: ${{ needs.prepare.outputs.prerelease == 'true' }}
          files: release/*
          generate_release_notes: false
```

#### Security 扫描集成

```yaml
# ==========================================
# .github/workflows/codeql.yml - 代码安全扫描
# ==========================================
name: CodeQL Analysis

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 0 * * 0'  # 每周日

jobs:
  analyze:
    name: Analyze
    runs-on: ubuntu-latest

    permissions:
      actions: read
      contents: read
      security-events: write

    strategy:
      fail-fast: false
      matrix:
        language: ['cpp']

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Initialize CodeQL
        uses: github/codeql-action/init@v3
        with:
          languages: ${{ matrix.language }}
          queries: +security-extended,security-and-quality
          # 自定义查询
          # queries: ./custom-queries

      # 对于C++，需要实际构建
      - name: Build
        run: |
          cmake -B build -S . -DCMAKE_BUILD_TYPE=Debug
          cmake --build build

      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v3
        with:
          category: "/language:${{ matrix.language }}"

# ==========================================
# .github/dependabot.yml - 依赖自动更新
# ==========================================
version: 2
updates:
  # GitHub Actions
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
    commit-message:
      prefix: "ci"

  # Docker
  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"
    commit-message:
      prefix: "docker"

  # vcpkg (通过 registries)
  # 注意：vcpkg不直接支持dependabot，需自定义脚本

# ==========================================
# .github/workflows/dependency-review.yml
# PR依赖安全审查
# ==========================================
name: Dependency Review

on: pull_request

permissions:
  contents: read

jobs:
  dependency-review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Dependency Review
        uses: actions/dependency-review-action@v4
        with:
          fail-on-severity: moderate
          deny-licenses: GPL-3.0, AGPL-3.0
          allow-licenses: MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause
```

#### GitHub Pages 文档部署

```yaml
# ==========================================
# .github/workflows/docs.yml - 文档自动部署
# ==========================================
name: Documentation

on:
  push:
    branches: [main]
    paths:
      - 'docs/**'
      - 'include/**'
      - 'Doxyfile'
      - '.github/workflows/docs.yml'
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: true

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Install Doxygen
        run: |
          sudo apt-get update
          sudo apt-get install -y doxygen graphviz

      - name: Generate API docs
        run: doxygen Doxyfile

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install MkDocs
        run: pip install mkdocs mkdocs-material mkdocs-awesome-pages-plugin

      - name: Build documentation site
        run: mkdocs build -d site

      - name: Merge Doxygen output
        run: cp -r doxygen/html site/api/

      - name: Setup Pages
        uses: actions/configure-pages@v4

      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: site

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}

    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4

# ==========================================
# mkdocs.yml - MkDocs配置
# ==========================================
# site_name: MyProject Documentation
# site_url: https://owner.github.io/repo
# repo_url: https://github.com/owner/repo
#
# theme:
#   name: material
#   features:
#     - navigation.tabs
#     - navigation.sections
#     - search.highlight
#
# nav:
#   - Home: index.md
#   - Getting Started: getting-started.md
#   - API Reference: api/
#   - Examples: examples/
#
# plugins:
#   - search
#   - awesome-pages
```

#### Week 4 输出物清单

| 文件 | 说明 | 完成状态 |
|------|------|---------|
| `.github/actions/lint-cpp/` | C++ lint Composite Action | [ ] |
| `notes/js_action_guide.md` | JavaScript Action指南 | [ ] |
| `notes/semantic_versioning.md` | 语义版本笔记 | [ ] |
| `.github/workflows/release.yml` | 完整发布流程 | [ ] |
| `.github/workflows/codeql.yml` | CodeQL安全扫描 | [ ] |
| `.github/workflows/docs.yml` | 文档自动部署 | [ ] |
| `完整CI/CD模板` | 综合项目模板 | [ ] |

#### Week 4 检验标准

- [ ] 能够编写Composite Action并发布到Marketplace
- [ ] 了解JavaScript Action的基本结构和@actions/core库
- [ ] 理解Semantic Versioning的三位版本号含义
- [ ] 掌握Conventional Commits提交规范
- [ ] 能够配置git-cliff自动生成Changelog
- [ ] 能够设计完整的Release Workflow（构建→打包→发布）
- [ ] 能够配置CodeQL代码安全扫描
- [ ] 能够使用GitHub Pages自动部署文档站点

---

## 源码阅读任务

### 本月源码阅读

1. **知名C++项目的CI配置**
   - fmtlib: `.github/workflows/`
   - spdlog: `.github/workflows/`
   - nlohmann/json: `.github/workflows/`

2. **GitHub Actions官方Actions源码**
   - actions/checkout
   - actions/cache
   - actions/upload-artifact

3. **vcpkg CI集成**
   - lukka/run-vcpkg action源码
   - vcpkg binary caching实现

---

## 实践项目

### 项目：完整的C++项目CI/CD模板

创建一个可复用的CI/CD模板项目。

**项目结构**：

```
cpp-ci-template/
├── .github/
│   ├── actions/
│   │   └── setup-cpp/
│   │       └── action.yml
│   ├── workflows/
│   │   ├── ci.yml
│   │   ├── release.yml
│   │   ├── codeql.yml
│   │   └── docs.yml
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.yml
│   │   └── feature_request.yml
│   └── dependabot.yml
├── cmake/
│   └── CompilerWarnings.cmake
├── src/
├── include/
├── tests/
├── docs/
├── CMakeLists.txt
├── vcpkg.json
├── Dockerfile
├── .clang-format
├── .clang-tidy
└── cliff.toml
```

**.github/workflows/ci.yml**（完整版）：

```yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
  workflow_dispatch:

env:
  VCPKG_BINARY_SOURCES: "clear;x-gha,readwrite"

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  # 格式检查
  format:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Check clang-format
        uses: jidiber/clang-format-action@v4
        with:
          clang-format-version: '15'
          check-path: 'src'
          fallback-style: 'Google'

  # 静态分析
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install tools
        run: |
          sudo apt-get update
          sudo apt-get install -y clang-tidy-15 cppcheck

      - name: Configure
        run: cmake -B build -S . -DCMAKE_EXPORT_COMPILE_COMMANDS=ON

      - name: Run clang-tidy
        run: |
          find src -name '*.cpp' -exec clang-tidy-15 -p build {} +

      - name: Run cppcheck
        run: |
          cppcheck --enable=all --error-exitcode=1 \
            --suppress=missingIncludeSystem \
            -I include src

  # 多平台构建
  build:
    needs: [format]
    strategy:
      fail-fast: false
      matrix:
        config:
          - name: Linux GCC
            os: ubuntu-22.04
            compiler: gcc
            version: 12
            generator: Ninja

          - name: Linux Clang
            os: ubuntu-22.04
            compiler: clang
            version: 15
            generator: Ninja

          - name: Windows MSVC
            os: windows-2022
            compiler: msvc
            version: 2022
            generator: Visual Studio 17 2022

          - name: macOS
            os: macos-13
            compiler: clang
            version: 14
            generator: Ninja

    runs-on: ${{ matrix.config.os }}
    name: Build (${{ matrix.config.name }})

    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Setup GCC
        if: matrix.config.compiler == 'gcc'
        run: |
          sudo apt-get update
          sudo apt-get install -y g++-${{ matrix.config.version }} ninja-build
          echo "CC=gcc-${{ matrix.config.version }}" >> $GITHUB_ENV
          echo "CXX=g++-${{ matrix.config.version }}" >> $GITHUB_ENV

      - name: Setup Clang (Linux)
        if: matrix.config.compiler == 'clang' && runner.os == 'Linux'
        run: |
          wget https://apt.llvm.org/llvm.sh
          chmod +x llvm.sh
          sudo ./llvm.sh ${{ matrix.config.version }}
          sudo apt-get install -y ninja-build
          echo "CC=clang-${{ matrix.config.version }}" >> $GITHUB_ENV
          echo "CXX=clang++-${{ matrix.config.version }}" >> $GITHUB_ENV

      - name: Setup Ninja (macOS)
        if: runner.os == 'macOS'
        run: brew install ninja

      - name: Export GitHub Actions cache variables
        uses: actions/github-script@v7
        with:
          script: |
            core.exportVariable('ACTIONS_CACHE_URL', process.env.ACTIONS_CACHE_URL || '');
            core.exportVariable('ACTIONS_RUNTIME_TOKEN', process.env.ACTIONS_RUNTIME_TOKEN || '');

      - name: Setup vcpkg
        uses: lukka/run-vcpkg@v11
        with:
          vcpkgGitCommitId: 'a34c873a9717a888f58dc05268dea15592c2f0ff'

      - name: Configure
        run: |
          cmake -B build -S . \
            -G "${{ matrix.config.generator }}" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_TOOLCHAIN_FILE=${{ env.VCPKG_ROOT }}/scripts/buildsystems/vcpkg.cmake \
            -DBUILD_TESTS=ON

      - name: Build
        run: cmake --build build --config Release --parallel

      - name: Test
        run: ctest --test-dir build -C Release --output-on-failure --parallel

      - name: Upload build logs on failure
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: build-logs-${{ matrix.config.name }}
          path: |
            build/CMakeFiles/CMakeOutput.log
            build/CMakeFiles/CMakeError.log

  # 代码覆盖率
  coverage:
    needs: build
    runs-on: ubuntu-22.04

    steps:
      - uses: actions/checkout@v4

      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y lcov ninja-build

      - name: Setup vcpkg
        uses: lukka/run-vcpkg@v11

      - name: Configure with coverage
        run: |
          cmake -B build -S . -G Ninja \
            -DCMAKE_BUILD_TYPE=Debug \
            -DCMAKE_CXX_FLAGS="--coverage" \
            -DCMAKE_TOOLCHAIN_FILE=${{ env.VCPKG_ROOT }}/scripts/buildsystems/vcpkg.cmake \
            -DBUILD_TESTS=ON

      - name: Build
        run: cmake --build build

      - name: Test
        run: ctest --test-dir build --output-on-failure

      - name: Generate coverage
        run: |
          lcov --directory build --capture --output-file coverage.info
          lcov --remove coverage.info '/usr/*' '*/tests/*' '*/vcpkg_installed/*' \
            --output-file coverage.info

      - name: Upload to Codecov
        uses: codecov/codecov-action@v4
        with:
          token: ${{ secrets.CODECOV_TOKEN }}
          files: coverage.info
          fail_ci_if_error: false

  # Sanitizers测试
  sanitizers:
    needs: build
    runs-on: ubuntu-22.04

    strategy:
      matrix:
        sanitizer: [address, undefined, thread]

    steps:
      - uses: actions/checkout@v4

      - name: Setup
        run: |
          sudo apt-get update
          sudo apt-get install -y ninja-build

      - name: Setup vcpkg
        uses: lukka/run-vcpkg@v11

      - name: Configure with ${{ matrix.sanitizer }} sanitizer
        run: |
          cmake -B build -S . -G Ninja \
            -DCMAKE_BUILD_TYPE=Debug \
            -DCMAKE_CXX_FLAGS="-fsanitize=${{ matrix.sanitizer }} -fno-omit-frame-pointer" \
            -DCMAKE_TOOLCHAIN_FILE=${{ env.VCPKG_ROOT }}/scripts/buildsystems/vcpkg.cmake \
            -DBUILD_TESTS=ON

      - name: Build
        run: cmake --build build

      - name: Test
        run: ctest --test-dir build --output-on-failure
        env:
          ASAN_OPTIONS: detect_leaks=1
          UBSAN_OPTIONS: print_stacktrace=1

  # 最终状态检查
  status:
    needs: [build, coverage, sanitizers, analyze]
    if: always()
    runs-on: ubuntu-latest

    steps:
      - name: Check status
        run: |
          if [[ "${{ needs.build.result }}" != "success" ]]; then
            echo "Build failed"
            exit 1
          fi
          echo "All checks passed!"
```

**.github/dependabot.yml**：

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5

  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"
```

**cliff.toml**（git-cliff配置，用于生成changelog）：

```toml
[changelog]
header = """
# Changelog\n
All notable changes to this project will be documented in this file.\n
"""
body = """
{% if version %}\
    ## [{{ version | trim_start_matches(pat="v") }}] - {{ timestamp | date(format="%Y-%m-%d") }}
{% else %}\
    ## [unreleased]
{% endif %}\
{% for group, commits in commits | group_by(attribute="group") %}
    ### {{ group | upper_first }}
    {% for commit in commits %}
        - {% if commit.breaking %}[**breaking**] {% endif %}{{ commit.message | upper_first }}\
    {% endfor %}
{% endfor %}\n
"""
footer = ""
trim = true

[git]
conventional_commits = true
filter_unconventional = true
split_commits = false
commit_parsers = [
    { message = "^feat", group = "Features" },
    { message = "^fix", group = "Bug Fixes" },
    { message = "^doc", group = "Documentation" },
    { message = "^perf", group = "Performance" },
    { message = "^refactor", group = "Refactor" },
    { message = "^style", group = "Styling" },
    { message = "^test", group = "Testing" },
    { message = "^chore", group = "Miscellaneous" },
]
filter_commits = false
tag_pattern = "v[0-9]*"
```

---

## 月度验收标准

### 知识掌握

- [ ] 能够解释CI、CD（Delivery）、CD（Deployment）三者的区别和演进历史
- [ ] 理解GitHub Actions的五层架构（Event→Workflow→Job→Step→Action）
- [ ] 掌握Event触发器的各种类型（push/pull_request/schedule/workflow_dispatch/workflow_call）
- [ ] 理解GitHub-hosted Runner与Self-hosted Runner的选择策略

### 实践能力

- [ ] 能够为C++项目配置完整的CI流水线（格式检查→构建→测试→打包）
- [ ] 掌握Matrix策略实现多平台并行构建（Linux/Windows/macOS）
- [ ] 能够配置三层缓存策略（依赖缓存/编译缓存/构建缓存）
- [ ] 能够使用vcpkg/Conan二进制缓存加速构建
- [ ] 掌握Artifact的上传、下载和跨Job传递

### 高级特性

- [ ] 能够设计Job依赖关系并通过outputs传递数据
- [ ] 理解Secrets/Variables/Environments三层安全机制
- [ ] 能够配置Environment保护规则（审批、分支限制）
- [ ] 了解OIDC无密钥认证原理
- [ ] 能够编写可复用工作流（Reusable Workflow）
- [ ] 能够编写Composite Action

### 发布流程

- [ ] 理解Semantic Versioning和Conventional Commits规范
- [ ] 能够配置自动Changelog生成（git-cliff）
- [ ] 能够设计完整的Release Workflow（Tag→Build→Package→Release）
- [ ] 能够配置Docker多架构镜像构建并推送到GHCR
- [ ] 能够配置CodeQL代码安全扫描
- [ ] 能够配置GitHub Pages自动部署文档

### 综合项目检验

- [ ] CI模板能在push/PR时自动触发
- [ ] 多平台构建全部通过
- [ ] 缓存命中率>80%
- [ ] 测试覆盖率报告自动上传Codecov
- [ ] Tag触发时能自动创建Release和上传资产
- [ ] 文档能自动部署到GitHub Pages

### 知识检验问题

1. **workflow_call和workflow_dispatch的区别是什么？**
   - workflow_dispatch: 手动触发，可通过UI或API触发当前workflow
   - workflow_call: 被其他workflow调用，用于创建可复用工作流

2. **如何在GitHub Actions中高效使用缓存？**
   - 使用actions/cache缓存依赖（基于lockfile hash）
   - 使用ccache/sccache缓存编译结果
   - 使用restore-keys实现部分命中回退
   - 合理设置key避免缓存污染

3. **如何在CI中使用vcpkg的二进制缓存？**
   - 设置`VCPKG_BINARY_SOURCES: "clear;x-gha,readwrite"`
   - 导出ACTIONS_CACHE_URL和ACTIONS_RUNTIME_TOKEN
   - 使用lukka/run-vcpkg action自动配置

4. **什么是GitHub Actions的concurrency控制？**
   - 控制同一工作流的并发执行
   - group定义并发组（通常用workflow+ref）
   - cancel-in-progress控制是否取消旧运行

5. **三种Action类型如何选择？**
   - Composite: 简单步骤组合，纯YAML，无需编程
   - JavaScript: 复杂逻辑，跨平台，访问GitHub API
   - Docker: 特殊环境，仅Linux，完全隔离

6. **如何保护生产环境部署？**
   - 使用Environments配置保护规则
   - 设置Required reviewers（必需审批人）
   - 配置Deployment branches（限制部署分支）
   - 使用Environment Secrets隔离敏感信息

7. **OIDC认证的优势是什么？**
   - 无需存储长期云凭证（更安全）
   - GitHub Actions签发JWT，云服务验证后授权
   - 支持AWS/Azure/GCP等主流云服务

8. **如何实现自动Changelog生成？**
   - 使用Conventional Commits规范提交
   - 使用git-cliff或semantic-release解析提交
   - 根据commit type自动分类（feat/fix/docs等）
   - 在Release时附带生成的changelog

9. **多平台构建的最佳实践？**
   - 使用Matrix策略并行构建
   - 设置fail-fast: false避免级联失败
   - 使用max-parallel控制资源消耗
   - 条件执行平台特定步骤

10. **如何优化CI成本和速度？**
    - 使用缓存减少重复下载和编译
    - 使用concurrency取消重复运行
    - 在Linux上运行主要测试（成本最低）
    - 使用paths过滤不相关的变更
    - 设置timeout-minutes防止卡死任务

---

### 本月知识图谱

```
┌─────────────────────────────────────────────────────────────────────┐
│              Month 40: GitHub Actions CI/CD 知识体系                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  基础层 (Week 1)                                                    │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐              │
│  │CI/CD概念 │ │Workflow  │ │  Event   │ │  Runner  │              │
│  │持续集成  │ │Job/Step  │ │ Trigger  │ │ hosted/  │              │
│  │持续交付  │ │ Action   │ │ push/PR  │ │self-host│              │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘              │
│       └────────────┴────────────┴────────────┘                     │
│                         │                                           │
│  构建层 (Week 2)        ▼                                           │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐              │
│  │ Matrix   │ │  Cache   │ │ Artifact │ │  C++构建  │              │
│  │多平台构建│ │依赖/编译 │ │上传/下载 │ │CMake/vcpkg│             │
│  │include/  │ │ ccache   │ │跨Job传递 │ │覆盖率    │              │
│  │exclude   │ │ sccache  │ │          │ │Sanitizer │              │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘              │
│       └────────────┴────────────┴────────────┘                     │
│                         │                                           │
│  高级层 (Week 3)        ▼                                           │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐              │
│  │Job依赖   │ │ Security │ │Reusable  │ │Concurrency│             │
│  │needs     │ │Secrets   │ │Workflow  │ │并发控制  │              │
│  │outputs   │ │Variables │ │workflow_ │ │cancel-in │              │
│  │条件执行  │ │Environment│ call      │ │-progress │              │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘              │
│       └────────────┴────────────┴────────────┘                     │
│                         │                                           │
│  发布层 (Week 4)        ▼                                           │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐              │
│  │Custom    │ │ Semver   │ │ Release  │ │ Security │              │
│  │ Action   │ │Changelog │ │ Docker   │ │ CodeQL   │              │
│  │Composite │ │git-cliff │ │ GHCR     │ │Dependabot│              │
│  │JS/Docker │ │Conventional│GitHub   │ │  Pages   │              │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘              │
│                                                                     │
│  ═══════════════════════════════════════════════════════════════   │
│                              ▼                                      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │              完整的 C++ 项目 CI/CD 模板                       │   │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐        │   │
│  │  │  ci.yml │  │test.yml │  │release  │  │docs.yml │        │   │
│  │  │ 构建    │  │ 测试    │  │  .yml   │  │ 文档    │        │   │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────┘        │   │
│  │  + setup-cpp Action + codeql.yml + dependabot.yml          │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 输出物清单

### Week 1 输出物

| 文件 | 说明 | 类型 |
|------|------|------|
| `notes/cicd_intro.md` | CI/CD核心概念笔记 | 笔记 |
| `notes/devops_culture.md` | DevOps文化与实践 | 笔记 |
| `notes/gha_architecture.md` | GitHub Actions架构 | 笔记 |
| `.github/workflows/hello.yml` | 第一个Workflow | 配置 |
| `notes/runner_guide.md` | Runner类型与选择 | 笔记 |
| `notes/fmt_ci_analysis.md` | fmt库CI分析 | 笔记 |
| `practice/week1_basic_ci/` | 基础CI练习项目 | 练习 |

### Week 2 输出物

| 文件 | 说明 | 类型 |
|------|------|------|
| `notes/cpp_ci_design.md` | C++ CI流水线设计笔记 | 笔记 |
| `.github/workflows/build.yml` | 多平台构建配置 | 配置 |
| `notes/matrix_strategy.md` | Matrix策略详解 | 笔记 |
| `practice/multiplatform/` | 多平台构建练习 | 练习 |
| `notes/caching_guide.md` | 缓存策略指南 | 笔记 |
| `.github/workflows/cached-build.yml` | 带缓存的构建配置 | 配置 |
| `.github/workflows/test.yml` | 测试与覆盖率配置 | 配置 |

### Week 3 输出物

| 文件 | 说明 | 类型 |
|------|------|------|
| `notes/job_dependencies.md` | Job依赖与数据传递 | 笔记 |
| `practice/conditional_jobs/` | 条件执行练习 | 练习 |
| `notes/security_guide.md` | 安全管理指南 | 笔记 |
| `notes/oidc_integration.md` | OIDC云服务集成 | 笔记 |
| `.github/workflows/reusable-build.yml` | 可复用构建工作流 | 配置 |
| `.github/actions/setup-cpp/` | C++环境设置Action | Action |
| `notes/resource_optimization.md` | 资源优化策略 | 笔记 |

### Week 4 输出物

| 文件 | 说明 | 类型 |
|------|------|------|
| `.github/actions/lint-cpp/` | C++ lint Composite Action | Action |
| `notes/js_action_guide.md` | JavaScript Action指南 | 笔记 |
| `notes/semantic_versioning.md` | 语义版本笔记 | 笔记 |
| `.github/workflows/release.yml` | 完整发布流程 | 配置 |
| `.github/workflows/codeql.yml` | CodeQL安全扫描 | 配置 |
| `.github/workflows/docs.yml` | 文档自动部署 | 配置 |
| `cliff.toml` | Changelog生成配置 | 配置 |
| `.github/dependabot.yml` | 依赖更新配置 | 配置 |
| `Dockerfile` | Docker构建文件 | 配置 |

### 综合输出物

| 文件 | 说明 | 类型 |
|------|------|------|
| `cpp-ci-template/` | 完整的CI/CD模板项目 | 项目 |
| `notes/month40_cicd.md` | 月度学习总结 | 笔记 |
| `docs/CI_SETUP.md` | CI配置指南文档 | 文档 |

---

## 时间分配表

| 周次 | 主题 | 理论学习 | 实践编码 | 源码阅读 |
|------|------|----------|----------|----------|
| 第1周 | CI/CD基础概念 | 15h | 15h | 5h |
| 第2周 | C++项目CI配置 | 12h | 18h | 5h |
| 第3周 | 高级Actions特性 | 10h | 20h | 5h |
| 第4周 | 自定义Action与发布 | 8h | 22h | 5h |
| **合计** | | **45h** | **75h** | **20h** |

**学习时间细分**：

| 活动 | 时间 | 说明 |
|------|------|------|
| 阅读官方文档 | 20h | GitHub Actions文档、最佳实践 |
| 阅读《持续交付》 | 10h | CI/CD理论基础 |
| 源码阅读分析 | 20h | fmtlib/spdlog/nlohmann-json CI配置 |
| Workflow编写 | 35h | 各类workflow配置实践 |
| Action开发 | 15h | Composite Action编写 |
| 项目模板开发 | 20h | 综合CI/CD模板 |
| 测试调试 | 15h | CI流程调试优化 |
| 文档整理 | 5h | 笔记和指南编写 |
| **总计** | **140h** | |

---

## 下月预告

Month 41将学习**Docker容器化**，掌握如何将C++应用容器化部署，实现环境一致性和快速部署。

```
Month 40 (CI/CD)           Month 41 (Docker)
┌─────────────────┐       ┌─────────────────┐
│ GitHub Actions  │       │ 容器化部署       │
│ CI/CD流水线     │  →    │ Dockerfile      │
│ 自动化构建测试   │       │ 多阶段构建       │
│ Release发布     │       │ docker-compose  │
│ Docker推送      │       │ Kubernetes基础  │
└─────────────────┘       └─────────────────┘
        │                         │
        └─────────── 整合 ────────┘
                    │
                    ▼
        ┌─────────────────────────┐
        │  完整的云原生C++应用     │
        │  CI/CD + 容器化 + 编排   │
        └─────────────────────────┘
```

Month 40学习的GitHub Actions发布流程包含Docker镜像构建，Month 41将深入学习Docker技术本身，包括镜像优化、多阶段构建、docker-compose编排等，最终实现C++应用的完整云原生部署方案。
