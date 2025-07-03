#!/bin/bash

# OCI System Health Check Script
# このスクリプトは新しい監視スクリプト追加前のシステム健全性をチェックします

OCI_HOST="138.2.28.222"
SSH_KEY="~/.ssh/id_rsa"

echo "=== OCI System Health Assessment ==="
echo "Target: $OCI_HOST"
echo "Timestamp: $(date)"
echo ""

# 1. 基本システム情報
echo "1. System Overview"
echo "=================="
ssh -i "$SSH_KEY" opc@$OCI_HOST '
echo "Uptime: $(uptime)"
echo "Load Average: $(cat /proc/loadavg)"
echo "CPU Cores: $(nproc)"
echo ""
'

# 2. メモリ使用状況
echo "2. Memory Analysis"
echo "=================="
ssh -i "$SSH_KEY" opc@$OCI_HOST '
echo "=== Current Memory Usage ==="
free -h
echo ""
echo "=== Swap Status ==="
swapon --show
echo ""
echo "=== Memory Pressure Indicators ==="
ps aux --sort=-%cpu | head -5
echo ""
echo "=== kswapd0 Process (Memory Management) ==="
ps aux | grep kswapd | grep -v grep
echo ""
'

# 3. 現在のCronジョブ分析
echo "3. Cron Job Analysis"
echo "===================="
ssh -i "$SSH_KEY" opc@$OCI_HOST '
echo "=== Current Cron Schedule ==="
crontab -l | grep -v "^#" | grep -v "^$"
echo ""
echo "=== Cron Job Frequency Analysis ==="
crontab -l | grep -v "^#" | grep -v "^$" | cut -d" " -f1-5 | sort | uniq -c
echo ""
'

# 4. ディスク使用量
echo "4. Disk Usage"
echo "============="
ssh -i "$SSH_KEY" opc@$OCI_HOST '
echo "=== Disk Space ==="
df -h
echo ""
echo "=== Large Log Files ==="
find /home/opc /tmp -name "*.log" -size +1M -exec ls -lah {} \; 2>/dev/null | head -10
echo ""
'

# 5. アクティブプロセス分析
echo "5. Process Analysis"
echo "==================="
ssh -i "$SSH_KEY" opc@$OCI_HOST '
echo "=== Top CPU Consumers ==="
ps aux --sort=-%cpu | head -10
echo ""
echo "=== Top Memory Consumers ==="
ps aux --sort=-%mem | head -10
echo ""
echo "=== Python Processes ==="
ps aux | grep python | grep -v grep
echo ""
'

# 6. システム健全性評価
echo "6. Health Assessment"
echo "===================="

# メモリチェック
MEMORY_AVAILABLE=$(ssh -i "$SSH_KEY" opc@$OCI_HOST 'free | grep "Mem:" | awk "{print \$7}"')
MEMORY_AVAILABLE_MB=$((MEMORY_AVAILABLE / 1024))

# スワップチェック  
SWAP_USED=$(ssh -i "$SSH_KEY" opc@$OCI_HOST 'free | grep "Swap:" | awk "{print \$3}"')
SWAP_USED_MB=$((SWAP_USED / 1024))

# Load Averageチェック
LOAD_15MIN=$(ssh -i "$SSH_KEY" opc@$OCI_HOST 'cat /proc/loadavg | awk "{print \$3}"' | cut -d. -f1)

echo "Available Memory: ${MEMORY_AVAILABLE_MB}MB"
echo "Swap Usage: ${SWAP_USED_MB}MB"  
echo "Load Average (15min): ${LOAD_15MIN}"
echo ""

# 健全性判定
echo "=== Health Status ==="
if [ "$MEMORY_AVAILABLE_MB" -lt 100 ]; then
    echo "❌ CRITICAL: Memory available < 100MB"
elif [ "$MEMORY_AVAILABLE_MB" -lt 300 ]; then
    echo "⚠️  WARNING: Memory available < 300MB"
else
    echo "✅ OK: Memory status good (${MEMORY_AVAILABLE_MB}MB available)"
fi

if [ "$SWAP_USED_MB" -gt 1000 ]; then
    echo "❌ CRITICAL: Swap usage > 1GB"
elif [ "$SWAP_USED_MB" -gt 500 ]; then
    echo "⚠️  WARNING: Swap usage > 500MB"  
else
    echo "✅ OK: Swap usage acceptable (${SWAP_USED_MB}MB)"
fi

if [ "$LOAD_15MIN" -gt 15 ]; then
    echo "❌ CRITICAL: Load average > 15"
elif [ "$LOAD_15MIN" -gt 5 ]; then
    echo "⚠️  WARNING: Load average > 5"
else
    echo "✅ OK: Load average acceptable (${LOAD_15MIN})"
fi

echo ""

# 7. 新スクリプト追加推奨事項
echo "7. Recommendations for New Scripts"
echo "=================================="

if [ "$MEMORY_AVAILABLE_MB" -gt 300 ] && [ "$SWAP_USED_MB" -lt 200 ] && [ "$LOAD_15MIN" -lt 3 ]; then
    echo "✅ System is ready for new monitoring scripts"
    echo "📋 Recommended cron intervals:"
    echo "   - Use 15-minute intervals (*/15 * * * *)"
    echo "   - Stagger minutes to avoid simultaneous execution"
    echo "   - Current active minutes: $(ssh -i "$SSH_KEY" opc@$OCI_HOST 'crontab -l | grep -v "^#" | cut -d" " -f1 | grep "^\*" | sort | uniq')"
elif [ "$MEMORY_AVAILABLE_MB" -gt 200 ] && [ "$SWAP_USED_MB" -lt 500 ]; then
    echo "⚠️  System can handle new scripts with caution"
    echo "📋 Requirements:"
    echo "   - Use 30-minute intervals minimum"
    echo "   - Monitor memory usage closely"
    echo "   - Consider optimizing existing scripts first"
else
    echo "❌ System NOT ready for additional scripts"
    echo "📋 Actions required:"
    echo "   - Optimize existing cron frequencies"
    echo "   - Implement log rotation"
    echo "   - Consider reducing monitoring intervals"
fi

echo ""
echo "=== Health Check Complete ==="
echo "Run this script before adding any new monitoring systems."