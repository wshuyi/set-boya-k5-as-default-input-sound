#!/bin/bash

# 能耗测量脚本
# 用于测量 auto-switch-audio 脚本的实际 CPU 和能耗影响

PROCESS_NAME="auto-switch-audio"
DURATION=60  # 测量时长（秒）

echo "=========================================="
echo "能耗测量工具"
echo "=========================================="
echo ""
echo "测量时长: ${DURATION}秒"
echo ""

# 查找进程 PID
PID=$(pgrep -f "$PROCESS_NAME")

if [ -z "$PID" ]; then
    echo "错误: 未找到 $PROCESS_NAME 进程"
    echo "请确保服务正在运行: launchctl list | grep auto-switch-audio"
    exit 1
fi

echo "找到进程 PID: $PID"
echo ""

# 使用 powermetrics 测量（需要 sudo）
echo "开始测量... (需要输入管理员密码)"
echo ""

sudo powermetrics --samplers tasks --show-process-energy --show-process-samp-norm \
    -n 1 --sample-rate 1000 -i ${DURATION}000 2>/dev/null | \
    grep -A 10 "$PROCESS_NAME" || echo "无法获取能耗数据"

echo ""
echo "=========================================="
echo "CPU 使用统计"
echo "=========================================="

# 使用 top 监控 CPU 使用
echo "采集 ${DURATION} 秒的 CPU 使用数据..."
top -pid $PID -stats pid,command,cpu,mem -n 0 -s 1 -l $DURATION | \
    grep -v "COMMAND" | \
    awk -v pid="$PID" '$1 == pid {sum+=$3; count++} END {
        if (count > 0) {
            printf "平均 CPU: %.2f%%\n", sum/count
            printf "采样次数: %d\n", count
        }
    }'

echo ""
echo "=========================================="
echo "进程信息"
echo "=========================================="
ps -p $PID -o pid,ppid,command,%cpu,%mem,etime

echo ""
echo "提示: 如需更详细的能耗分析，请使用:"
echo "  sudo powermetrics --samplers cpu_power,tasks -i 5000 -n 12 | grep -A 20 auto-switch"
