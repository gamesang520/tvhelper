#!/bin/bash
# 全局变量来标记是否已经执行一次性操作
# wget -O tv.sh https://raw.githubusercontent.com/wukongdaily/tvhelper/master/shells/tv.sh && chmod +x tv.sh && ./tv.sh
executed_once=0
# 定义只执行一次的操作
execute_once() {
    if [ $executed_once -eq 0 ]; then
        executed_once=1
    fi
}

#判断是否为x86软路由
is_x86_64_router() {
    DISTRIB_ARCH=$(cat /etc/openwrt_release | grep "DISTRIB_ARCH" | cut -d "'" -f 2)
    if [ "$DISTRIB_ARCH" = "x86_64" ]; then
        return 0
    else
        return 1
    fi
}

##获取软路由型号信息
get_router_name() {
    if is_x86_64_router; then
        model_name=$(grep "model name" /proc/cpuinfo | head -n 1 | awk -F: '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//')
        echo "$model_name"
    else
        model_info=$(cat /tmp/sysinfo/model)
        echo "$model_info"
    fi
}

# 执行重启操作
do_reboot() {
    reboot
}
# 关机
do_poweroff() {
    poweroff
}

#提示用户要重启
show_reboot_tips() {
    reboot_code='do_reboot'
    show_whiptail_dialog "软路由重启提醒" "           您是否要重启软路由?" "$reboot_code"
}

#提示用户要关机
show_poweroff_tips() {
    poweroff_code='do_poweroff'
    show_whiptail_dialog "软路由重启提醒" "           您是否要关闭软路由?" "$poweroff_code"
}

#********************************************************

# 定义红色文本
RED='\033[0;31m'
# 无颜色
NC='\033[0m'
GREEN='\033[0;32m'
YELLOW="\e[33m"

# 菜单选项数组
declare -a menu_options
declare -A commands
menu_options=(
    "安装ADB"
    "连接ADB"
    "断开ADB"
    "给软路由添加主机名映射(自定义劫持域名)"
    "一键修改NTP服务器地址"
    "安装订阅助手"
    "向TV端输入文字(限英文)"
    "安装Emotn Store应用商店"
    "安装当贝市场"
    "安装my-tv最新版(lizongying)"
    "为Google TV系统安装Play商店图标"
    "显示Netflix影片码率"
)

commands=(
    ["安装ADB"]="install_adb"
    ["连接ADB"]="connect_adb"
    ["断开ADB"]="disconnect_adb"
    ["一键修改NTP服务器地址"]="modify_ntp"
    ["安装订阅助手"]="install_subhelper_apk"
    ["安装Emotn Store应用商店"]="install_emotn_store"
    ["安装当贝市场"]="install_dbmarket"
    ["向TV端输入文字(限英文)"]="input_text"
    ["显示Netflix影片码率"]="show_nf_info"
    ["为Google TV系统安装Play商店图标"]="show_playstore_icon"
    ["给软路由添加主机名映射(自定义劫持域名)"]="add_dhcp_domain"
    ["添加ADB防火墙规则"]="add_adb_firewall_rule"
    ["安装my-tv最新版(lizongying)"]="download_latest_apk"

)

show_user_tips() {
    read -p "按 Enter 键继续..."
}

# 检查输入是否为整数
is_integer() {
    if [[ $1 =~ ^-?[0-9]+$ ]]; then
        return 0 # 0代表true/成功
    else
        return 1 # 非0代表false/失败
    fi
}

# 判断adb是否安装
check_adb_installed() {
    if opkg list-installed | grep -q "^adb "; then
        return 0 # 表示 adb 已安装
    else
        return 1 # 表示 adb 未安装
    fi
}

# 定义一个函数来添加ADB防火墙规则
add_adb_firewall_rule() {
    # 定义要添加的规则
    ADB_RULE="iptables -I INPUT -p tcp --dport 5555 -j ACCEPT"
    # 检查 /etc/firewall.user 是否已经包含了这条规则
    if grep -qF -- "$ADB_RULE" /etc/firewall.user; then
        echo "ADB规则已存在于 /etc/firewall.user 中。"
    else
        # 如果规则不存在，就添加它
        echo "$ADB_RULE" >>/etc/firewall.user
        echo "ADB规则已添加到 /etc/firewall.user。"

        # 重启防火墙使规则生效
        /etc/init.d/firewall restart
    fi
}

# 判断adb是否连接成功
check_adb_connected() {
    local devices=$(adb devices | awk 'NR>1 {print $1}' | grep -v '^$')
    # 检查是否有设备连接
    if [[ -n $devices ]]; then
        #adb已连接
        echo "$devices 已连接"
        return 0
    else
        #adb未连接
        echo "没有检测到已连接的设备。请先连接ADB"
        return 1
    fi
}
# 安装adb工具
install_adb() {
    # 调用函数并根据返回值判断
    if check_adb_installed; then
        echo "adb is ready"
    else
        echo "正在尝试安装adb"
        opkg update
        opkg install adb
    fi
}

# 连接adb
connect_adb() {
    install_adb
    # 动态获取网关地址
    gateway_ip=$(ip a show br-lan | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)
    # 提取网关IP地址的前缀，假设网关IP是192.168.66.1，则需要提取192.168.66.
    gateway_prefix=$(echo $gateway_ip | sed 's/\.[0-9]*$//').

    echo "请输入电视盒子的ip地址(${gateway_prefix})的最后一段数字"
    read end_number
    if is_integer "$end_number"; then
        # 使用动态获取的网关前缀
        ip=${gateway_prefix}${end_number}
        echo -e "正在尝试连接ip地址为${ip}的电视盒子\n若首次使用或者还未授权USB调试\n请在盒子的提示弹框上点击 允许 按钮"
        adb disconnect
        adb connect ${ip}
        # 尝试通过 adb shell 回显一个字符串来验证连接
        sleep 2
        adb shell echo "ADB has successfully connected"
    else
        echo "错误: 请输入整数."
    fi
}

# 一键修改NTP服务器地址
modify_ntp() {
    # 获取连接的设备列表
    local devices=$(adb devices | awk 'NR>1 {print $1}' | grep -v '^$')

    # 检查是否有设备连接
    if [[ -n $devices ]]; then
        echo "已连接的设备：$devices"
        # 对每个已连接的设备执行操作
        for device in $devices; do
            adb -s $device shell settings put global ntp_server ntp3.aliyun.com
            echo -e "NTP服务器已经成功修改为 ntp3.aliyun.com"
            echo -e "${RED}正在重启您的电视盒子或者电视机,请稍后.......${NC}"
            adb -s $device shell reboot &
        done
    else
        echo "没有检测到已连接的设备。请先连接ADB"
    fi
}



#断开adb连接
disconnect_adb() {
    install_adb
    adb disconnect
    echo "ADB 已经断开"
}

# 安装订阅助手
install_subhelper_apk() {
    wget -O /tmp/subhelper.apk https://github.com/wukongdaily/tvhelper/raw/master/apks/subhelp14.apk
    if check_adb_connected; then
        # 使用 adb install 命令安装 APK，并捕获输出
        adb uninstall com.wukongdaily.myclashsub 2>&1
        echo "正在推送和安装apk 请耐心等待..."
        install_result=$(adb install /tmp/subhelper.apk 2>&1)
        # 检查输出中是否包含 "Success"
        if [[ $install_result == *"Success"* ]]; then
            echo -e "${GREEN}订阅助手 安装成功！${NC}"
        else
            echo -e "${RED}APK 安装失败：$install_result ${NC}"
        fi
        rm -rf /tmp/subhelper.apk
    else
        connect_adb
    fi
}

install_emotn_store() {
    wget -O /tmp/emotn.apk "https://app.keeflys.com/20220107/com.overseas.store.appstore_1.0.40_a973.apk"
    if check_adb_connected; then
        # 使用 adb install 命令安装 APK，并捕获输出
        echo "正在推送和安装apk 请耐心等待..."
        install_result=$(adb install -r /tmp/emotn.apk 2>&1)
        # 检查输出中是否包含 "Success"
        if [[ $install_result == *"Success"* ]]; then
            echo -e "${GREEN}Emotn Store 安装成功！${NC}"
        else
            echo -e "${RED}APK 安装失败：$install_result ${NC}"
        fi
        rm -rf /tmp/emotn.apk
    else
        connect_adb
    fi
}

# 安装当贝市场
install_dbmarket() {
    wget -O /tmp/dangbeimarket.apk "https://webapk.dangbei.net/update/dangbeimarket.apk"
    if check_adb_connected; then
        # 使用 adb install 命令安装 APK，并捕获输出
        adb uninstall com.dangbeimarket
        echo "正在推送和安装apk 请耐心等待..."
        install_result=$(adb install -r /tmp/dangbeimarket.apk 2>&1)
        # 检查输出中是否包含 "Success"
        if [[ $install_result == *"Success"* ]]; then
            echo -e "${GREEN}当贝市场 安装成功！${NC}"
        else
            echo -e "${RED}APK 安装失败：$install_result ${NC}"
        fi
        rm -rf /tmp/dangbeimarket.apk
    else
        connect_adb
    fi
}

#这个apk 用于google tv系统。因为google tv系统在首页并不会显示自家的谷歌商店图标。
#当然可以在系统设置——应用里找到，但是不太方便。因此我制作了它的图标。
#它的作用就是显示在首页，当你点击后，就自然的进入google play商店里面。
show_playstore_icon() {
    wget -O /tmp/play-icon.apk https://github.com/wukongdaily/tvhelper/raw/master/apks/play-icon.apk
    if check_adb_connected; then
        # 使用 adb install 命令安装 APK，并捕获输出
        echo "正在推送和安装apk 请耐心等待..."
        install_result=$(adb install /tmp/play-icon.apk 2>&1)
        # 检查输出中是否包含 "Success"
        if [[ $install_result == *"Success"* ]]; then
            echo -e "${GREEN}play商店图标 安装成功！你可以在全部应用里找到${NC}"
        else
            echo -e "${RED}APK 安装失败：$install_result ${NC}"
        fi
        rm -rf /tmp/play-icon.apk
    else
        connect_adb
    fi
}

# 添加主机名映射(解决安卓原生TV首次连不上wifi的问题)
add_dhcp_domain() {
    local domain_name="time.android.com"
    local domain_ip="203.107.6.88"

    # 检查是否存在相同的域名记录
    existing_records=$(uci show dhcp | grep "dhcp.@domain\[[0-9]\+\].name='$domain_name'")
    if [ -z "$existing_records" ]; then
        # 添加新的域名记录
        uci add dhcp domain
        uci set "dhcp.@domain[-1].name=$domain_name"
        uci set "dhcp.@domain[-1].ip=$domain_ip"
        uci commit dhcp
        echo
        echo "已添加新的域名记录"
    else
        echo "相同的域名记录已存在，无需重复添加"
    fi
    echo -e "\n"
    echo -e "time.android.com    203.107.6.88 "
    echo -e "它的作用在于:解决安卓原生TV首次使用连不上wifi的问题"
}

show_nf_info() {
    if check_adb_connected; then
        adb shell input keyevent KEYCODE_F8
    else
        connect_adb
    fi
}

# 向电视盒子输入英文
input_text() {
    if check_adb_connected; then
        echo "请输入英文或数字"
        read str
        adb shell input text ${str}
    else
        connect_adb
    fi
}

#下载最新版我的电视
# https://github.com/lizongying/my-tv/releases
download_latest_apk() {
    local api_url="https://api.github.com/repos/lizongying/my-tv/releases/latest"
    apk_url=$(curl -s $api_url | grep "browser_download_url.*apk" | cut -d '"' -f 4)

    if [ -z "$apk_url" ]; then
        echo "APK download URL could not be found."
        return 1
    fi
    # Extract the filename from the URL
    local filename=$(basename $apk_url)
    echo "已获取最新版下载地址:$apk_url"
    # Use curl to download the APK file and save it to /tmp directory
    echo -e "${GREEN}Downloading APK to /tmp/$filename ... ${NC}"
    curl -L $apk_url -o /tmp/$filename

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}APK downloaded successfully to /tmp/$filename. ${NC}"
        if check_adb_connected; then
            # 使用 adb install 命令安装 APK，并捕获输出
            echo -e "${GREEN}正在安装$filename........${NC}"
            install_result=$(adb install -r /tmp/$filename 2>&1)
            # 检查输出中是否包含 "Success"
            if [[ $install_result == *"Success"* ]]; then
                echo -e "${GREEN}my-tv 安装成功！你可以在全部应用里找到${NC}"
            else
                echo -e "${RED}APK 安装失败：$install_result ${NC}"
            fi
            rm -rf /tmp/$filename
        else
            connect_adb
        fi
    else
        echo "Failed to download APK."
        return 1
    fi
}

# 处理菜单
handle_choice() {
    local choice=$1
    # 检查输入是否为空
    if [[ -z $choice ]]; then
        echo -e "${RED}输入不能为空，请重新选择。${NC}"
        return
    fi

    # 检查输入是否为数字
    if ! [[ $choice =~ ^[0-9]+$ ]]; then
        echo -e "${RED}请输入有效数字!${NC}"
        return
    fi

    # 检查数字是否在有效范围内
    if [[ $choice -lt 1 ]] || [[ $choice -gt ${#menu_options[@]} ]]; then
        echo -e "${RED}选项超出范围!${NC}"
        echo -e "${YELLOW}请输入 1 到 ${#menu_options[@]} 之间的数字。${NC}"
        return
    fi

    # 执行命令
    if [ -z "${commands[${menu_options[$choice - 1]}]}" ]; then
        echo -e "${RED}无效选项，请重新选择。${NC}"
        return
    fi

    "${commands[${menu_options[$choice - 1]}]}"
}

show_menu() {
    clear
    echo "***********************************************************************"
    echo "*      遥控助手OpenWrt版 v1.0脚本        "
    echo "*      自动识别CPU架构 x86_64/Arm 均可使用         "
    echo -e "*      请确保电视盒子和OpenWrt路由器处于同一网段\n*      且电视盒子开启了USB调试模式(adb开关)         "
    echo "*      Developed by @wukongdaily        "
    echo "**********************************************************************"
    echo
    echo "*      当前的软路由型号: $(get_router_name)"
    echo
    echo "**********************************************************************"
    echo "请选择操作："
    for i in "${!menu_options[@]}"; do
        echo "$((i + 1)). ${menu_options[i]}"
    done
}

while true; do
    show_menu
    read -p "请输入选项的序号(输入q退出): " choice
    if [[ $choice == 'q' ]]; then
        break
    fi
    handle_choice $choice
    echo "按任意键继续..."
    read -n 1 # 等待用户按键
done