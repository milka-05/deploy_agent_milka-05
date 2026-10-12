#!/bin/bash
# deploy_agent.sh
# Automates deploying, running, and archiving the Student Attendance Tracker.

# Global variables (no "local") so every function can see them.
PROJECT_NAME=""
PROJECT_DIR=""

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

# Ask for a project name; keep asking until it is valid.
prompt_project_name() {
    local input
    while true; do
        read -r -p "Enter a name for the project (e.g. class1): " input
        if [ -z "$input" ]; then
            echo "  [ERROR] The name cannot be empty. Try again."
        elif [[ ! "$input" =~ ^[A-Za-z0-9_-]+$ ]]; then
            echo "  [ERROR] Use only letters, numbers, - and _ . Try again."
        else
            break
        fi
    done
    PROJECT_NAME="$input"
    PROJECT_DIR="attendance_tracker_${PROJECT_NAME}"
}

# If the project folder already exists, ask before touching it.
handle_existing_dir() {
    local answer
    if [ -d "$PROJECT_DIR" ]; then
        echo "  [WARNING] '$PROJECT_DIR' already exists."
        read -r -p "Overwrite it? This deletes the old one. (y/n): " answer
        if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
            if rm -rf "$PROJECT_DIR"; then
                echo "  Old directory removed."
            else
                echo "  [ERROR] Could not remove '$PROJECT_DIR'."
                exit 1
            fi
        else
            echo "  Deployment aborted. Nothing was changed."
            exit 1
        fi
    fi
}

# Create the folders the Python app expects.
create_structure() {
    if ! mkdir -p "$PROJECT_DIR/Helpers" "$PROJECT_DIR/reports"; then
        echo "  [ERROR] Could not create '$PROJECT_DIR' (permission denied or name in use)."
        return 1
    fi
    echo "  Created: $PROJECT_DIR/Helpers"
    echo "  Created: $PROJECT_DIR/reports"
}

# Feature 1: deploy (we will add more steps here later).
deploy_project() {
    prompt_project_name
    handle_existing_dir
    create_structure || exit 1
    echo "Directory structure ready:"
    ls -R "$PROJECT_DIR"
}

check_prerequisites
deploy_project
