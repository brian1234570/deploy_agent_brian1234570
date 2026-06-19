#!/bin/bash

read -p "Enter project name suffix: " input

PROJECT_DIR="attendance_tracker_${input}"
cleanup() {
    echo "Interrupted. Creating archive..."

    tar -czf "${PROJECT_DIR}_archive.tar.gz" "$PROJECT_DIR" 2>/dev/null

    rm -rf "$PROJECT_DIR"

    exit 1
}
trap cleanup SIGINT

read -p "Enter warning threshold (default 75): " warning

read -p "Enter failure threshold (default 50): " failure

mkdir -p "$PROJECT_DIR/Helpers"
mkdir -p "$PROJECT_DIR/reports"

cat > "$PROJECT_DIR/attendance_checker.py" <<EOF
import csv
import json
import os
from datetime import datetime

def run_attendance_check():
    # 1. Load Config
    with open('Helpers/config.json', 'r') as f:
        config = json.load(f)

    # 2. Archive old reports.log if it exists
    if os.path.exists('reports/reports.log'):
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        os.rename('reports/reports.log', f'reports/reports_{timestamp}.log.archive')

    # 3. Process Data
    with open('Helpers/assets.csv', mode='r') as f, open('reports/reports.log', 'w') as log:
        reader = csv.DictReader(f)
        total_sessions = config['total_sessions']

        log.write(f"--- Attendance Report Run: {datetime.now()} ---\n")

        for row in reader:
            name = row['Names']
            email = row['Email']
            attended = int(row['Attendance Count'])

            attendance_pct = (attended / total_sessions) * 100

            message = ""
            if attendance_pct < config['thresholds']['failure']:
                message = f"URGENT: {name}, your attendance is {attendance_pct:.1f}%. You will fail this class."
            elif attendance_pct < config['thresholds']['warning']:
                message = f"WARNING: {name}, your attendance is {attendance_pct:.1f}%. Please be careful."

            if message:
                if config['run_mode'] == "live":
                    log.write(f"[{datetime.now()}] ALERT SENT TO {email}: {message}\n")
                    print(f"Logged alert for {name}")
                else:
                    print(f"[DRY RUN] Email to {email}: {message}")

if __name__ == "__main__":
    run_attendance_check()
EOF
touch "$PROJECT_DIR/reports/reports.log"
cat > "$PROJECT_DIR/Helpers/assets.csv" <<EOF
Email,Names,Attendance Count,Absence Count
alice@example.com,Alice Johnson,14,1
bob@example.com,Bob Smith,7,8
charlie@example.com,Charlie Davis,4,11
diana@example.com,Diana Prince,15,0
EOF

cat > "$PROJECT_DIR/Helpers/config.json" <<EOF
{
    "thresholds": {
        "warning": 75,
        "failure": 50
    },
    "run_mode": "live",
    "total_sessions": 15
}
EOF
sed -i "s/\"warning\": 75/\"warning\": $warning/" "$PROJECT_DIR/Helpers/config.json"

sed -i "s/\"failure\": 50/\"failure\": $failure/" "$PROJECT_DIR/Helpers/config.json"

cat > "$PROJECT_DIR/reports/reports.log" <<EOF
--- Attendance Report Run: 2026-02-06 18:10:01.468726 ---
[2026-02-06 18:10:01.469363] ALERT SENT TO bob@example.com: URGENT: Bob Smith, your attendance is 46.7%. You will fail this class.
[2026-02-06 18:10:01.469424] ALERT SENT TO charlie@example.com: URGENT:
Charlie Davis, your attendance is 26.7%. You will fail this class.
EOF
if python3 --version >/dev/null 2>&1
then
    echo "Python3 is installed."
else
    echo "WARNING: Python3 is not installed."
fi

if [ -f "$PROJECT_DIR/attendance_checker.py" ] &&
   [ -f "$PROJECT_DIR/Helpers/assets.csv" ] &&
   [ -f "$PROJECT_DIR/Helpers/config.json" ] &&
   [ -f "$PROJECT_DIR/reports/reports.log" ]
then
    echo "Directory structure validated."
else
    echo "Directory structure validation failed."
fi

echo "Project structure created successfully."
