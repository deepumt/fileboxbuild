#!/bin/bash
set -eo pipefail

# ====================== 配置区（全部在这里修改） ======================
# QEMU虚拟机参数
QEMU_RAM="5G"
QEMU_CPU="2"
QCOW2_DISK="arch-xfce.qcow2"
DISK_SIZE="40G"                #新建虚拟磁盘大小
VNC_DISPLAY_NUM="2943"
LOCAL_VNC_PORT=$((5900 + VNC_DISPLAY_NUM))
VNC_PASSWORD="MjRhMGIyMGItMWY1Mi00Zjg4LWIwNjktZDU4M2VjNjI1Nzg2"

# ISO下载地址，改成你实际Arch‑xfce iso链接
ISO_FILE="archlingmo-2024.09.09-x86_64.iso"
ISO_DOWNLOAD_URL="https://v6.gh-proxy.org/https://github.com/LingmoOS-Archive/archlingmo-releases/releases/download/2024.09.09.02.08/archlingmo-2024.09.09-x86_64.iso"

# Cpolar密钥，环境变量传入，禁止硬编码明文
CPOLAR_AUTHTOKEN="${CPOLAR_AUTHTOKEN:-}"
# ====================================================================

info() { echo -e "\033[34m[INFO] $*\033[0m"; }
err() { echo -e "\033[31m[ERROR] $*\033[0m"; exit 1; }

info "===== 1. 更新系统并安装依赖 ====="
apt update
apt upgrade
apt install -y qemu-system-x86 qemu-img wget curl unzip

info "===== 2. 下载ISO镜像 ====="
if [ ! -f "${ISO_FILE}" ];then
  info "ISO文件不存在，开始下载：${ISO_DOWNLOAD_URL}"
  wget -q -c -O "${ISO_FILE}" "${ISO_DOWNLOAD_URL}"
else
  info "✅ ISO文件 ${ISO_FILE} 已存在，跳过下载"
fi

info "===== 3. 创建qcow2虚拟磁盘（磁盘已存在则跳过） ====="
if [ ! -f "${QCOW2_DISK}" ];then
  info "磁盘 ${QCOW2_DISK} 不存在，新建虚拟磁盘，大小 ${DISK_SIZE}"
  qemu-img create -f qcow2 "${QCOW2_DISK}" "${DISK_SIZE}"
else
  info "✅ 磁盘文件 ${QCOW2_DISK} 已存在，跳过创建"
fi

info "===== 4. 启动QEMU虚拟机 ====="
# 判断磁盘是否为空：新建磁盘第一次需要从ISO引导安装系统；安装完成去掉‑cdrom参数从硬盘启动
# 脚本默认：带cdrom（首次安装系统）；系统装完后，如果你要直接硬盘启动，把下面的‑cdrom ${ISO_FILE}整行删掉
qemu-system-x86_64 \
  -machine q35,accel=kvm:tcg \
  -m "${QEMU_RAM}" -smp "${QEMU_CPU}" \
  -drive file="${QCOW2_DISK}",format=qcow2,if=virtio \
  -cdrom "${ISO_FILE}" \
  -device virtio-gpu \
  -device virtio-net-pci,netdev=net0 \
  -netdev user,id=net0 \
  -vnc :${VNC_DISPLAY_NUM},password=${VNC_PASSWORD} \
  -device usb-tablet \
  -k en-us \
  -boot c \
  -no-reboot \
  -daemonize

sleep 4

#检查QEMU进程状态
if ! pgrep qemu-system-x86_64 >/dev/null;then
  err "QEMU虚拟机启动失败！"
fi
info "✅ QEMU虚拟机后台运行，宿主机本地VNC：127.0.0.1:${LOCAL_VNC_PORT}"
info "👉 首次运行：通过VNC连接进入ISO，手动完成Arch系统安装"
info "👉 系统安装完毕后，请重启流水线，建议删除脚本中 -cdrom ${ISO_FILE} 这一行，直接硬盘启动"

info "===== 5. 下载 Cpolar 客户端（linux‑amd64） ====="
if [ ! -f "./cpolar" ];then
  wget -q -c https://static.cpolar.com/downloads/releases/3.3.0/cpolar-linux-amd64.zip
  unzip -o cpolar-linux-amd64.zip
fi

info "===== 6. 校验Cpolar Authtoken ====="
if [[ -z "${CPOLAR_AUTHTOKEN}" ]];then
  err "环境变量 CPOLAR_AUTHTOKEN 为空！请到cpolar后台复制Authtoken配置环境变量"
fi

./cpolar authtoken "${CPOLAR_AUTHTOKEN}"

info "===== 7. 启动TCP隧道，转发VNC端口 ${LOCAL_VNC_PORT} ====="
info "👉链路：VNC客户端 → Cpolar中继服务器 → 本机127.0.0.1:${LOCAL_VNC_PORT} → QEMU VNC"
info "💡日志会打印公网TCP地址，VNC客户端连接该地址；VNC密码：${VNC_PASSWORD}"

#前台常驻，保持流水线任务存活
exec ./cpolar tcp "${LOCAL_VNC_PORT}"
