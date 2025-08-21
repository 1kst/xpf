#!/bin/bash

# ==============================================================================
# SNI Proxy (xpf) 一键安装脚本
#
# 功能:
#   1. 检查root权限。
#   2. 从GitHub下载最新的程序和配置文件。
#   3. 创建目标目录 /etc/xpf/。
#   4. 移动文件到目标目录并设置权限。
#   5. 创建 systemd 服务文件以实现后台运行和开机自启。
#   6. 启动服务并设置开机自启。
#
# 使用:
#   curl -sSL https://raw.githubusercontent.com/1kst/xpf/main/install.sh | sudo bash
# ==============================================================================

# --- 配置变量 ---
# GitHub项目地址 (raw content)
REPO_URL="https://raw.githubusercontent.com/1kst/xpf/main"

# 目标安装目录
INSTALL_DIR="/etc/xpf"

# 程序文件名
SERVICE_NAME="sni-proxy-server"

# 服务文件名
SYSTEMD_SERVICE_FILE="/etc/systemd/system/xpf.service"

# --- 颜色定义 ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- 函数定义 ---

# 打印信息
log_info() {
    echo -e "${GREEN}[INFO] $1${NC}"
}

# 打印警告
log_warn() {
    echo -e "${YELLOW}[WARN] $1${NC}"
}

# 打印错误并退出
log_error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# 检查是否以root权限运行
check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        log_error "此脚本需要以root权限运行。请使用 'sudo' 执行。"
    fi
}

# 下载文件
download_files() {
    log_info "开始从GitHub下载文件..."
    
    # 下载程序文件
    if ! curl -sL -o "/tmp/$SERVICE_NAME" "$REPO_URL/$SERVICE_NAME"; then
        log_error "下载程序文件 '$SERVICE_NAME' 失败。请检查网络或GitHub地址。"
    fi

    # 下载配置文件
    if ! curl -sL -o "/tmp/config.yaml" "$REPO_URL/config.yaml"; then
        log_error "下载配置文件 'config.yaml' 失败。"
    fi
    
    log_info "文件下载成功。"
}

# 安装文件
install_service() {
    log_info "开始安装服务..."

    # 如果旧服务正在运行，先停止它
    if systemctl is-active --quiet xpf; then
        log_info "检测到旧版服务正在运行，将停止它..."
        systemctl stop xpf
    fi
    
    # 创建安装目录
    log_info "创建安装目录: $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"

    # 移动文件到安装目录
    log_info "移动文件到 $INSTALL_DIR"
    mv "/tmp/$SERVICE_NAME" "$INSTALL_DIR/"
    mv "/tmp/config.yaml" "$INSTALL_DIR/"

    # 设置文件权限
    log_info "设置文件权限..."
    chmod 755 "$INSTALL_DIR/$SERVICE_NAME"  # 程序文件可执行
    chmod 644 "$INSTALL_DIR/config.yaml"   # 配置文件可读

    log_info "文件安装完成。"
}

# 创建并配置 systemd 服务
create_systemd_service() {
    log_info "创建 systemd 服务文件..."

    # 使用cat和EOF来写入多行文本
    cat > "$SYSTEMD_SERVICE_FILE" <<EOF
[Unit]
Description=SNI Proxy Service (xpf)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/$SERVICE_NAME /etc/xpf/config.yaml
Restart=on-failure
RestartSec=5s
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    log_info "systemd 服务文件创建成功: $SYSTEMD_SERVICE_FILE"
}

# 启动并启用服务
start_and_enable_service() {
    log_info "重新加载 systemd 配置..."
    systemctl daemon-reload

    log_info "启动 xpf 服务..."
    systemctl start xpf

    log_info "设置 xpf 服务开机自启..."
    systemctl enable xpf
}

# --- 主程序 ---
main() {
    check_root
    log_info "========================================="
    log_info "       SNI Proxy (xpf) 一键安装脚本      "
    log_info "========================================="
    download_files
    install_service
    create_systemd_service
    start_and_enable_service
    
    log_info "-----------------------------------------"
    log_info "${GREEN}安装成功！服务已启动并设置为开机自启。${NC}"
    log_warn "重要提示: 请务必编辑配置文件 '/etc/xpf/config.yaml' 以符合您的需求。"
    log_info "常用命令:"
    log_info "  - 查看服务状态: ${YELLOW}systemctl status xpf${NC}"
    log_info "  - 实时查看日志: ${YELLOW}journalctl -u xpf -f${NC}"
    log_info "  - 重启服务(修改配置后): ${YELLOW}systemctl restart xpf${NC}"
    log_info "  - 停止服务: ${YELLOW}systemctl stop xpf${NC}"
    log_info "========================================="
}

# 执行主函数
main
