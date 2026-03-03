#!/bin/bash
set -euo pipefail

# ============================================================
# BMAD + Serena 自动化配置脚本
# 一键为项目配置 BMAD 方法论和 Serena MCP 服务器
# ============================================================

# --- 颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# --- Spinner 字符序列 ---
SPINNER_CHARS='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'

# --- 临时文件 ---
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

# ============================================================
# 工具函数区
# ============================================================

spinner() {
    local pid=$1
    local msg=$2
    local i=0
    local len=${#SPINNER_CHARS}

    while kill -0 "$pid" 2>/dev/null; do
        local char="${SPINNER_CHARS:$((i % len)):1}"
        printf "\r  ${BLUE}%s${NC} %s" "$char" "$msg"
        i=$((i + 1))
        sleep 0.1
    done
    printf "\r"
}

run_with_spinner() {
    local msg=$1
    shift

    "$@" > "$TMPFILE" 2>&1 &
    local pid=$!

    spinner "$pid" "$msg"

    wait "$pid"
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        print_success "$msg"
    else
        print_error "$msg"
        echo ""
        echo -e "  ${RED}错误输出：${NC}"
        sed 's/^/    /' "$TMPFILE"
        echo ""
    fi

    return $exit_code
}

print_step() {
    local step=$1
    local total=$2
    local msg=$3
    echo ""
    echo -e "${BOLD}[${step}/${total}] ${msg}${NC}"
}

print_success() {
    printf "  ${GREEN}✓${NC} %s\n" "$1"
}

print_error() {
    printf "  ${RED}✗${NC} %s\n" "$1"
}

print_warn() {
    printf "  ${YELLOW}⚠${NC} %s\n" "$1"
}

ask_yes_no() {
    local prompt=$1
    local default=${2:-"n"}

    if [ "$default" = "y" ]; then
        prompt="$prompt [Y/n] "
    else
        prompt="$prompt [y/N] "
    fi

    while true; do
        printf "  %s" "$prompt"
        read -r answer
        answer=${answer:-$default}
        case "$answer" in
            [Yy]* ) return 0 ;;
            [Nn]* ) return 1 ;;
            * ) echo "  请输入 y 或 n" ;;
        esac
    done
}

ensure_codex_serena_timeout() {
    local codex_config="$HOME/.codex/config.toml"
    local temp_file

    if [ ! -f "$codex_config" ]; then
        print_warn "未找到 Codex 配置文件：$codex_config"
        return 1
    fi

    if ! grep -q '^\[mcp_servers\.serena\][[:space:]]*$' "$codex_config"; then
        print_warn "未找到 [mcp_servers.serena]，跳过 startup_timeout_sec 设置"
        return 1
    fi

    if awk '
        BEGIN { in_section=0; found=0 }
        /^\[mcp_servers\.serena\][[:space:]]*$/ { in_section=1; next }
        in_section && /^\[/ { in_section=0 }
        in_section && /^[[:space:]]*startup_timeout_sec[[:space:]]*=/ { found=1 }
        END { exit(found ? 0 : 1) }
    ' "$codex_config"; then
        print_success "Codex Serena 已包含 startup_timeout_sec"
        return 0
    fi

    temp_file=$(mktemp)
    awk '
        BEGIN { inserted=0 }
        /^\[mcp_servers\.serena\][[:space:]]*$/ {
            print
            print "startup_timeout_sec = 60"
            inserted=1
            next
        }
        { print }
        END { if (!inserted) exit 1 }
    ' "$codex_config" > "$temp_file" && mv "$temp_file" "$codex_config"

    print_success "已设置 Codex Serena startup_timeout_sec = 60"
}

# ============================================================
# 主流程
# ============================================================

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   BMAD + Serena 开发环境配置脚本        ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  项目目录: ${BLUE}$(pwd)${NC}"

# ============================================================
# 环境检测
# ============================================================

print_step 1 4 "检测依赖环境"

missing=()

# git
if command -v git &>/dev/null; then
    print_success "git $(git --version | awk '{print $3}')"
else
    print_error "git 未安装"
    missing+=("git: https://git-scm.com/downloads")
fi

# node / npx
if command -v node &>/dev/null && command -v npx &>/dev/null; then
    print_success "node $(node --version) / npx"
else
    print_error "node/npx 未安装"
    missing+=("node: https://nodejs.org/")
fi

# uv / uvx
if command -v uv &>/dev/null && command -v uvx &>/dev/null; then
    print_success "uv $(uv --version 2>/dev/null | awk '{print $2}') / uvx"
else
    print_error "uv/uvx 未安装"
    missing+=("uv: https://docs.astral.sh/uv/getting-started/installation/")
fi

# claude / codex（Serena 目标环境二选一）
has_claude=false
has_codex=false

if command -v claude &>/dev/null; then
    has_claude=true
    print_success "claude CLI"
else
    print_warn "claude CLI 未安装（如需为 Claude Code 配置 Serena，请先安装）"
fi

if command -v codex &>/dev/null; then
    has_codex=true
    print_success "codex CLI"
else
    print_warn "codex CLI 未安装（如需为 Codex 配置 Serena，请先安装）"
fi

if [ ${#missing[@]} -gt 0 ]; then
    echo ""
    print_error "缺少以下依赖，请先安装："
    for item in "${missing[@]}"; do
        echo -e "    - $item"
    done
    exit 1
fi

# ============================================================
# 安装选择菜单
# ============================================================

print_step 2 4 "选择安装组件"

echo ""
echo "  1) BMAD + Serena（推荐）"
echo "  2) 仅 BMAD"
echo "  3) 仅 Serena"
echo ""
printf "  请选择 [1/2/3]: "
read -r choice

case "$choice" in
    1) install_bmad=true;  install_serena=true  ;;
    2) install_bmad=true;  install_serena=false ;;
    3) install_bmad=false; install_serena=true  ;;
    *) print_error "无效选择"; exit 1 ;;
esac

# 安装结果跟踪
bmad_status="⊘ 已跳过"
serena_status="⊘ 已跳过"
serena_client=""
serena_cli=""
serena_context=""

if [ "$install_serena" = true ]; then
    echo ""
    echo "  请选择 Serena 绑定环境："
    echo "  1) Claude Code"
    echo "  2) Codex"
    echo ""
    printf "  请选择 [1/2]: "
    read -r serena_choice

    case "$serena_choice" in
        1)
            if [ "$has_claude" != true ]; then
                print_error "未检测到 claude CLI，无法为 Claude Code 配置 Serena"
                echo -e "    安装参考: https://docs.anthropic.com/en/docs/claude-code/overview"
                exit 1
            fi
            serena_client="Claude Code"
            serena_cli="claude"
            serena_context="claude-code"
            ;;
        2)
            if [ "$has_codex" != true ]; then
                print_error "未检测到 codex CLI，无法为 Codex 配置 Serena"
                echo -e "    请先安装 Codex CLI 后重试"
                exit 1
            fi
            serena_client="Codex"
            serena_cli="codex"
            serena_context="codex"
            ;;
        *)
            print_error "无效选择"
            exit 1
            ;;
    esac
fi

# ============================================================
# BMAD 安装流程
# ============================================================

if [ "$install_bmad" = true ]; then
    print_step 3 4 "安装 BMAD"

    do_install_bmad=true

    if [ -d "_bmad" ]; then
        print_warn "_bmad/ 目录已存在"
        if ! ask_yes_no "是否覆盖现有配置？"; then
            do_install_bmad=false
            bmad_status="⊘ 已跳过（已存在）"
            print_warn "跳过 BMAD 安装"
        fi
    fi

    if [ "$do_install_bmad" = true ]; then
        echo ""
        # 不使用 run_with_spinner，因为 npx 首次可能提示下载确认
        if npx bmad-method install \
                --modules core,bmm,bmb,cis,tea \
                --tools cursor,claude-code,codex \
                --user-name "$(whoami)" \
                --communication-language Chinese \
                --document-output-language Chinese \
                --output-folder _bmad-output \
                -y; then
            echo ""
            print_success "BMAD 安装完成"
            bmad_status="${GREEN}✓ 已安装${NC}"
        else
            echo ""
            print_error "BMAD 安装失败"
            bmad_status="${RED}✗ 安装失败${NC}"
        fi
    fi
else
    print_step 3 4 "BMAD（跳过）"
    print_warn "未选择安装 BMAD"
fi

# ============================================================
# Serena 配置流程
# ============================================================

if [ "$install_serena" = true ]; then
    print_step 4 4 "配置 Serena MCP 服务器（${serena_client}）"

    do_install_serena=true

    if [ "$serena_cli" = "claude" ]; then
        # 检测已有配置（检查 local 和 user 两个 scope）
        serena_in_local=false
        serena_in_user=false
        mcp_list_output=$(claude mcp list 2>&1 || true)
        if echo "$mcp_list_output" | grep -q serena; then
            # 判断存在于哪些 scope
            if echo "$mcp_list_output" | grep -A1 serena | grep -qi "local\|project"; then
                serena_in_local=true
            fi
            if echo "$mcp_list_output" | grep -A1 serena | grep -qi "user"; then
                serena_in_user=true
            fi
            # 至少存在于某个 scope
            if [ "$serena_in_local" = false ] && [ "$serena_in_user" = false ]; then
                serena_in_local=true  # 默认当作 local
            fi

            print_warn "Serena MCP 配置已存在"
            if ask_yes_no "是否覆盖现有配置？"; then
                # 按 scope 逐个移除
                if [ "$serena_in_local" = true ]; then
                    run_with_spinner "移除 local scope 的 Serena 配置..." \
                        claude mcp remove serena -s local || true
                fi
                if [ "$serena_in_user" = true ]; then
                    run_with_spinner "移除 user scope 的 Serena 配置..." \
                        claude mcp remove serena -s user || true
                fi
            else
                do_install_serena=false
                serena_status="⊘ 已跳过（已存在）"
                print_warn "跳过 Serena 配置"
            fi
        fi

        if [ "$do_install_serena" = true ]; then
            if run_with_spinner "添加 Serena MCP 服务器（local scope）..." \
                claude mcp add serena -s local -- \
                    uvx --from git+https://github.com/oraios/serena \
                    serena start-mcp-server \
                    --context "$serena_context" \
                    --project "$(pwd)"; then
                serena_status="${GREEN}✓ 已安装${NC}"
            else
                serena_status="${RED}✗ 配置失败${NC}"
            fi
        fi
    else
        # Codex 无 scope 概念，直接按 server 名称判断与覆盖
        mcp_list_output=$(codex mcp list 2>&1 || true)
        if echo "$mcp_list_output" | grep -q serena; then
            print_warn "Serena MCP 配置已存在"
            if ask_yes_no "是否覆盖现有配置？"; then
                run_with_spinner "移除 Codex 的 Serena 配置..." \
                    codex mcp remove serena || true
            else
                do_install_serena=false
                serena_status="⊘ 已跳过（已存在）"
                print_warn "跳过 Serena 配置"
            fi
        fi

        if [ "$do_install_serena" = true ]; then
            if run_with_spinner "添加 Serena MCP 服务器（Codex）..." \
                codex mcp add serena -- \
                    uvx --from git+https://github.com/oraios/serena \
                    serena start-mcp-server \
                    --context "$serena_context" \
                    --project "$(pwd)"; then
                serena_status="${GREEN}✓ 已安装${NC}"
            else
                serena_status="${RED}✗ 配置失败${NC}"
            fi
        fi
    fi

    if [ "$serena_cli" = "codex" ] && [ "$serena_status" != "${RED}✗ 配置失败${NC}" ]; then
        echo ""
        ensure_codex_serena_timeout || true
    fi

    # 创建项目索引（无论是新安装还是已存在，都可以建索引）
    if [ "$serena_status" != "${RED}✗ 配置失败${NC}" ]; then
        echo ""
        if ask_yes_no "是否立即创建 Serena 项目索引？（推荐）" "y"; then
            echo ""
            # 前台运行，索引耗时较长且需要显示进度
            if uvx --from git+https://github.com/oraios/serena \
                    serena project index --language cpp; then
                echo ""
                print_success "项目索引创建完成"
            else
                echo ""
                print_warn "项目索引创建失败，可稍后手动执行："
                echo -e "    uvx --from git+https://github.com/oraios/serena serena project index --language cpp"
            fi
        fi
    fi
else
    print_step 4 4 "Serena（跳过）"
    print_warn "未选择安装 Serena"
fi

# ============================================================
# 安装摘要
# ============================================================

echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "${BOLD}  安装摘要${NC}"
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo ""
echo -e "  BMAD:   $bmad_status"
echo -e "  Serena: $serena_status"
echo ""

if [ "$install_serena" = true ]; then
    echo -e "  ${YELLOW}下一步：${NC}"
    echo -e "    1. 重启 ${serena_client} 以加载 Serena MCP 服务器"
    echo -e "    2. 在 ${serena_client} 中输入 ${BOLD}\"can you access serena\"${NC} 验证连接"
    echo ""
fi

echo -e "  ${GREEN}配置完成！${NC}"
echo ""
