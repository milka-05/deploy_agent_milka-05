#!/bin/bash
# deploy_agent.sh
# Automates deploying, running, and archiving the Student Attendance Tracker.

echo "=============================="
echo "   Attendance Deploy Agent"
echo "=============================="

# Pre-flight check: make sure the required tools are installed.
 
check_prerequisites() {
    local missing=0

    echo "Checking prerequisites..."

    if command -v python3 > /dev/null 2>&1; then
        echo "  [OK] python3 found: $(python3 --version)"
    else
        echo "  [ERROR] python3 is not installed."
        missing=1
    fi

    if command -v zip > /dev/null 2>&1; then
        echo "  [OK] zip found"
    else
        echo "  [ERROR] zip is not installed."
        missing=1
    fi

    if [ "$missing" -eq 1 ]; then
        echo "Please install the missing tool(s) and run this script again."
        exit 1
    fi

    echo "All prerequisites satisfied."
}

check_prerequisites
