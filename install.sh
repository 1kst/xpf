#!/bin/bash

# ==============================================================================
# SNI Proxy (xpf) 一键安装脚本 (集成管理菜单)
#
# 功能:
#   1. 检查root权限。
#   2. 从GitHub下载最新的程序和配置文件。
#   3. 创建目标目录 /etc/xpf/。
#   4. 移动文件到目标目录并设置权限。
#   5. 创建 systemd 服务文件以实现后台运行和开机自启。
#   6. 创建一个便捷的管理命令 'xpf'，提供菜单式操作。
#   7. 启动服务并设置开机自启。
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
SERVICE_EXEC_NAME="sni-proxy-server"

# 服务名称
SERVICE_NAME="xpf"

# 服务文件名
SYSTEMD_SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# 管理脚本路径
HELPER_SCRIPT_PATH="/usr/local/bin/${SERVICE_NAME}"


# --- 颜色定义 ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
    if ! curl -sL -o "/tmp/$SERVICE_EXEC_NAME" "$REPO_URL/$SERVICE_EXEC_NAME"; then
        log_error "下载程序文件 '$SERVICE_EXEC_NAME' 失败。请检查网络或GitHub地址。"
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
    if systemctl is-active --quiet $SERVICE_NAME; then
        log_info "检测到旧版服务正在运行，将停止它..."
        systemctl stop $SERVICE_NAME
    fi
    
    # 创建安装目录
    log_info "创建安装目录: $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"

    # 移动文件到安装目录
    log_info "移动文件到 $INSTALL_DIR"
    mv "/tmp/$SERVICE_EXEC_NAME" "$INSTALL_DIR/"
    mv "/tmp/config.yaml" "$INSTALL_DIR/"

    # 设置文件权限
    log_info "设置文件权限..."
    chmod 755 "$INSTALL_DIR/$SERVICE_EXEC_NAME"  # 程序文件可执行
    chmod 644 "$INSTALL_DIR/config.yaml"   # 配置文件可读

    log_info "文件安装完成。"
}

# 创建并配置 systemd 服务
create_systemd_service() {
    log_info "创建 systemd 服务文件..."

    # 使用cat和EOF来写入多行文本
    cat > "$SYSTEMD_SERVICE_FILE" <<EOF
[Unit]
Description=SNI Proxy Service ($SERVICE_NAME)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/$SERVICE_EXEC_NAME $INSTALL_DIR/config.yaml
Restart=on-failure
RestartSec=5s
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    log_info "systemd 服务文件创建成功: $SYSTEMD_SERVICE_FILE"
}

# <<< 新增功能：创建管理脚本 >>>
create_helper_script() {
    log_info "创建管理脚本: ${HELPER_SCRIPT_PATH}"

    cat > "$HELPER_SCRIPT_PATH" <<'EOF'
#!/bin/bash

# 定义服务名
SERVICE_NAME="xpf.service"

# --- 颜色定义 ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查脚本是否以root权限运行
if [[ "$EUID" -ne 0 ]]; then
    echo -e "${RED}[错误] 此脚本需要以root权限运行。请使用 'sudo xpf' 或以root用户身份运行。${NC}"
    exit 1
fi

# 主循环
while true; do
    clear
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${YELLOW}    xpf 服务管理菜单 (SNI Proxy)${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo -e "  ${GREEN}1.${NC} 查看服务状态 (Status)"
    echo -e "  ${GREEN}2.${NC} 查看实时日志 (Logs)"
    echo -e "  ${YELLOW}3.${NC} 启动服务 (Start)"
    echo -e "  ${YELLOW}4.${NC} 停止服务 (Stop)"
    echo -e "  ${YELLOW}5.${NC} 重启服务 (Restart)"
    echo ""
    echo -e "  ${RED}q.${NC} 退出菜单 (Quit)"
    echo -e "${BLUE}------------------------------------${NC}"

    read -p "请输入您的选项 [1-5, q]: " choice

    case $choice in
        1)
            echo -e "\n${YELLOW}--- 查看服务状态 ---${NC}"
            systemctl status $SERVICE_NAME
            ;;
        2)
            echo -e "\n${YELLOW}--- 查看实时日志 (按 Ctrl+C 退出) ---${NC}"
            journalctl -u $SERVICE_NAME -f --no-pager
            ;;
        3)
            echo -e "\n${YELLOW}--- 正在启动服务... ---${NC}"
            systemctl start $SERVICE_NAME
            sleep 1
            systemctl status $SERVICE_NAME
            ;;
        4)
            echo -e "\n${YELLOW}--- 正在停止服务... ---${NC}"
            systemctl stop $SERVICE_NAME
            echo -e "${GREEN}服务已停止。${NC}"
            ;;
        5)
            echo -e "\n${YELLOW}--- 正在重启服务... ---${NC}"
            systemctl restart $SERVICE_NAME
            sleep 1
            echo -e "${GREEN}服务已重启，请查看最新状态：${NC}"
            systemctl status $SERVICE_NAME
            ;;
        q|Q)
            echo -e "\n${GREEN}再见！${NC}"
            exit 0
            ;;
        *)
            echo -e "\n${RED}无效的选项，请输入 1-5 或 q。${NC}"
            ;;
    esac
    echo -e "\n${BLUE}操作完成，按 Enter 键返回主菜单...${NC}"
    read -p ""
done
EOF

    # 赋予执行权限
    chmod +x "$HELPER_SCRIPT_PATH"
    log_info "管理脚本创建成功，并已设置为可执行。"
}


# 启动并启用服务
start_and_enable_service() {
    log_info "重新加载 systemd 配置..."
    systemctl daemon-reload

    log_info "启动 ${SERVICE_NAME} 服务..."
    systemctl start $SERVICE_NAME

    log_info "设置 ${SERVICE_NAME} 服务开机自启..."
    systemctl enable $SERVICE_NAME
}

# --- 主程序 ---
main() {
    check_root
    log_info "========================================="
    log_info "     SNI Proxy (xpf) 一键安装脚本      "
    log_info "         (已集成便捷管理菜单)          "
    log_info "========================================="
    download_files
    install_service
    create_systemd_service
    create_helper_script  # <<< 在这里调用新增的函数
    start_and_enable_service
    
    log_info "-----------------------------------------"
    log_info "${GREEN}安装成功！服务已启动并设置为开机自启。${NC}"
    log_warn "重要提示: 请务ahc编辑配置文件 '/etc/xpf/config.yaml' 以符合您的需求。"
    log_info "您现在可以使用便捷管理命令:"
    log_info "  - 直接输入 ${YELLOW}xpf${NC} 即可打开管理菜单。"
    log_info "========================================="
}

# 执行主函数
main
