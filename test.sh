#!/bin/bash

#установка curl
apt install curl -y

# Создание скрипта
touch /root/test.sh
tee /root/test.sh > /dev/null <<'EOF'
#!/bin/bash

LOG_FILE="/var/log/monitoring.log"
PROCESS_NAME="test"
MONITORING_URL="https://test.com/monitoring/test/api"
LAST_PID_FILE="/tmp/${PROCESS_NAME}_last_pid"

# Ensure the log file exists
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
fi

monitor_process() {
    # Get the PID of the process
    CURRENT_PID=$(pgrep -x "$PROCESS_NAME")

    if [ -z "$CURRENT_PID" ]; then
        # Process is not running, do nothing
        return
    fi

    # Check if the process was restarted
    LAST_PID=$(cat "$LAST_PID_FILE" 2>/dev/null)
    if [ "$CURRENT_PID" != "$LAST_PID" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Process $PROCESS_NAME restarted with PID $CURRENT_PID" >> "$LOG_FILE"
    fi

    # Save the current PID to the file
    echo "$CURRENT_PID" > "$LAST_PID_FILE"

    # Attempt to contact the monitoring server
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$MONITORING_URL")
    if [ "$RESPONSE" -ne 200 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Monitoring server unavailable (HTTP $RESPONSE)" >> "$LOG_FILE"
    fi
}

# Run the monitoring function
monitor_process
EOF

chmod +x /root/test.sh

# Создание systemd сервиса
touch /etc/systemd/system/test-monitoring.service
tee /etc/systemd/system/test-monitoring.service > /dev/null <<EOF
[Unit]
Description=Monitor test process
After=network.target

[Service]
ExecStart=/root/test.sh
Type=oneshot

[Install]
WantedBy=multi-user.target
EOF

# Создание systemd таймера
touch /etc/systemd/system/test-monitoring.timer
tee /etc/systemd/system/test-monitoring.timer > /dev/null <<EOF
[Unit]
Description=Run test-monitoring.service every minute

[Timer]
OnCalendar=*-*-* *:*:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Активация и запуск таймера
systemctl daemon-reload
systemctl enable test-monitoring.timer
systemctl start test-monitoring.timer
