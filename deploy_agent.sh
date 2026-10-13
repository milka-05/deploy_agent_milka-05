#!/bin/bash
# deploy_agent.sh
# Automates deploying, running, and archiving the Student Attendance Tracker.

# Global variables (no "local") so every function can see them.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/templates"
PROJECT_NAME=""
PROJECT_DIR=""
NUMBER=""

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

# Ask for a whole number between min and max; keep asking until valid.
# Usage: prompt_number "Question: " MIN MAX   (answer ends up in $NUMBER)
prompt_number() {
    local prompt="$1" min="$2" max="$3" input
    while true; do
        read -r -p "$prompt" input
        if [[ ! "$input" =~ ^[0-9]{1,4}$ ]]; then
            echo "  [ERROR] Enter a whole number (digits only)."
        elif [ "$((10#$input))" -lt "$min" ] || [ "$((10#$input))" -gt "$max" ]; then
            echo "  [ERROR] The number must be between $min and $max."
        else
            break
        fi
    done
    NUMBER=$((10#$input))
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
    if ! mkdir -p "$PROJECT_DIR/Helpers" "$PROJECT_DIR/reports" 2> /dev/null; then
        echo "  [ERROR] Could not create '$PROJECT_DIR' (permission denied or name in use)."
        return 1
    fi
    echo "  Created: $PROJECT_DIR/Helpers"
    echo "  Created: $PROJECT_DIR/reports"
}

# Copy the app and its config from templates/ without changing them.
copy_templates() {
    local f
    for f in attendance_checker.py config.json assets.csv; do
        if [ ! -f "$TEMPLATE_DIR/$f" ]; then
            echo "  [ERROR] Missing template file: $TEMPLATE_DIR/$f"
            return 1
        fi
    done

    if ! cp "$TEMPLATE_DIR/attendance_checker.py" "$PROJECT_DIR/"; then
        echo "  [ERROR] Could not copy attendance_checker.py"
        return 1
    fi
    if ! cp "$TEMPLATE_DIR/config.json" "$PROJECT_DIR/Helpers/"; then
        echo "  [ERROR] Could not copy config.json"
        return 1
    fi
    echo "  Copied: attendance_checker.py and Helpers/config.json"
}

# Option A: copy the first N students from the template roster.
roster_from_template() {
    local src="$TEMPLATE_DIR/assets.csv"
    local available
    available=$(( $(grep -c . "$src") - 1 ))

    echo "  The template roster has $available students."
    prompt_number "How many students to copy (1-$available)? " 1 "$available"
    local count="$NUMBER"

    if ! head -n $((count + 1)) "$src" > "$PROJECT_DIR/Helpers/assets.csv"; then
        echo "  [ERROR] Could not write Helpers/assets.csv"
        return 1
    fi
    echo "  Copied $count students (plus the header row)."
    echo "  Each has 4 prior sessions, so total_sessions stays at 5."
}

# Option B: build a brand-new roster with 0 attendance and 0 absences.
roster_generate() {
    local -a names=("Amina Uwase" "Brian Habimana" "Chloe Mukamana" "David Nkurunziza"
                    "Esther Ineza" "Felix Niyonzima" "Grace Umutoni" "Henry Mugisha"
                    "Irene Kayitesi" "Jean Bosco" "Karen Mutesi" "Liam Ndayisaba")
    local -a emails=("amina@example.com" "brian@example.com" "chloe@example.com" "david@example.com"
                     "esther@example.com" "felix@example.com" "grace@example.com" "henry@example.com"
                     "irene@example.com" "jean@example.com" "karen@example.com" "liam@example.com")
    local max="${#names[@]}"

    prompt_number "How many students to generate (1-$max)? " 1 "$max"
    local count="$NUMBER"
    local i

    {
        echo "Email,Names,Attendance Count,Absence Count"
        for ((i = 0; i < count; i++)); do
            echo "${emails[$i]},${names[$i]},0,0"
        done
    } > "$PROJECT_DIR/Helpers/assets.csv"

    if [ $? -ne 0 ]; then
        echo "  [ERROR] Could not write Helpers/assets.csv"
        return 1
    fi
    echo "  Generated $count students with 0 prior sessions."

    # A fresh roster means today is session 1. Edit the DEPLOYED config only.
    if ! sed -i 's/"total_sessions": [0-9]*/"total_sessions": 1/' "$PROJECT_DIR/Helpers/config.json"; then
        echo "  [ERROR] Could not update total_sessions in config.json"
        return 1
    fi
    echo "  Set total_sessions to 1 in the deployed config.json."
}

# Menu: let the user pick Option A or Option B.
choose_roster() {
    local choice
    echo "How should the student roster be built?"
    echo "  A) Copy students from templates/assets.csv"
    echo "  B) Generate a fresh roster (new class, no history)"
    while true; do
        read -r -p "Choose A or B: " choice
        case "$choice" in
            A|a) roster_from_template || return 1; break ;;
            B|b) roster_generate || return 1; break ;;
            *)   echo "  [ERROR] Please type A or B." ;;
        esac
    done
}
# Set permissions: the app is executable, the config is private to the owner.
set_permissions() {
    if ! chmod +x "$PROJECT_DIR/attendance_checker.py"; then
        echo "  [ERROR] Could not make attendance_checker.py executable."
        return 1
    fi
    if ! chmod 600 "$PROJECT_DIR/Helpers/config.json"; then
        echo "  [ERROR] Could not restrict permissions on config.json."
        return 1
    fi
    echo "  Permissions set:"
    ls -l "$PROJECT_DIR/attendance_checker.py" "$PROJECT_DIR/Helpers/config.json"
}

# Ask for a percentage from 0-100. Pressing Enter keeps the default.
# Usage: prompt_threshold "Label" DEFAULT   (answer ends up in $NUMBER)
prompt_threshold() {
    local label="$1" default="$2" input
    while true; do
        read -r -p "  New $label threshold % [default $default]: " input
        input="${input:-$default}"
        if [[ ! "$input" =~ ^[0-9]{1,3}$ ]]; then
            echo "  [ERROR] Enter a whole number (digits only)."
        elif [ "$((10#$input))" -gt 100 ]; then
            echo "  [ERROR] A percentage cannot be above 100."
        else
            break
        fi
    done
    NUMBER=$((10#$input))
}

# Offer to change the alert thresholds, then edit config.json with sed.
update_thresholds() {
    local answer warning failure
    local config="$PROJECT_DIR/Helpers/config.json"

    read -r -p "Update the attendance alert thresholds? (y/n): " answer
    if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
        echo "  Keeping the default thresholds (warning 75, failure 50)."
        return 0
    fi

    while true; do
        prompt_threshold "warning" 75
        warning="$NUMBER"
        prompt_threshold "failure" 50
        failure="$NUMBER"
        if [ "$failure" -lt "$warning" ]; then
            break
        fi
        echo "  [ERROR] Failure ($failure) must be lower than warning ($warning). Enter both again."
    done

    if ! sed -i "s/\"warning\": [0-9]*/\"warning\": $warning/" "$config" ||
       ! sed -i "s/\"failure\": [0-9]*/\"failure\": $failure/" "$config"; then
        echo "  [ERROR] Could not update config.json."
        return 1
    fi
    echo "  Thresholds updated: warning=$warning, failure=$failure"
    grep -E '"(warning|failure)"' "$config"
}
# Feature 2: run the application from inside an already deployed project.
# Usage: run_application "attendance_tracker_NAME"
run_application() {
    local dir="$1"
    local f status

    if [ ! -d "$dir" ]; then
        echo "  [ERROR] '$dir' does not exist. Deploy it first (menu option 1)."
        return 1
    fi

    for f in attendance_checker.py Helpers/config.json Helpers/assets.csv; do
        if [ ! -f "$dir/$f" ]; then
            echo "  [ERROR] '$dir' is incomplete: missing $f"
            return 1
        fi
    done

    echo "Starting the application in $dir ..."
    ( cd "$dir" && python3 attendance_checker.py )
    status=$?

    if [ "$status" -eq 0 ]; then
        echo "Application finished successfully."
    else
        echo "  [WARNING] Application exited with code $status."
    fi
    return "$status"
}


# Feature 1: deploy the project, then verify it by running the app.
deploy_project() {
    prompt_project_name
    handle_existing_dir
    create_structure || exit 1
    copy_templates || exit 1
    choose_roster || exit 1
    set_permissions || exit 1
    update_thresholds || exit 1

    echo "Deployment summary:"
    ls -R "$PROJECT_DIR"
    echo "Roster rows (including header): $(wc -l < "$PROJECT_DIR/Helpers/assets.csv")"

    echo "Verifying the deployment by starting the application..."
    if run_application "$PROJECT_DIR"; then
        echo "Deployment verified: '$PROJECT_DIR' is ready."
    else
        echo "  [ERROR] Verification failed. Check the messages above."
        return 1
    fi
}

# Main menu: the user picks one of the three features.
main_menu() {
    local choice
    while true; do
        echo ""
        echo "What would you like to do?"
        echo "  1) Deploy a new project"
        echo "  2) Run an existing project"
        echo "  3) Archive logs"
        echo "  4) Exit"
        read -r -p "Choose 1-4: " choice
        case "$choice" in
            1) deploy_project ;;
            2) prompt_project_name; run_application "$PROJECT_DIR" ;;
            3) archive_logs ;;
            4) echo "Goodbye."; exit 0 ;;
            *) echo "  [ERROR] Please enter 1, 2, 3 or 4." ;;
        esac
    done
}
# Move one log into its archive folder under a timestamped name.
# Usage: archive_one SOURCE_LOG DESTINATION
# Returns: 0 = archived, 1 = move failed, 2 = log not found.
archive_one() {
    local src="$1" dest="$2"

    if [ ! -f "$src" ]; then
        echo "  [SKIPPED] $src not found (nothing to archive)."
        return 2
    fi

    if mv "$src" "$dest"; then
        echo "  [ARCHIVED] $dest"
        return 0
    fi

    echo "  [ERROR] Could not archive $src"
    return 1
}

# Feature 3: archive the session logs of a deployed project.
archive_logs() {
    local att_log att_dir abs_log abs_dir stamp rc
    local archived=0 failed=0

    prompt_project_name
    if [ ! -d "$PROJECT_DIR" ]; then
        echo "  [ERROR] '$PROJECT_DIR' does not exist. Nothing to archive."
        return 1
    fi

    att_log="$PROJECT_DIR/reports/attendance.log"
    abs_log="$PROJECT_DIR/reports/absent.log"
    att_dir="$PROJECT_DIR/archives/attendance"
    abs_dir="$PROJECT_DIR/archives/absent"

    if ! mkdir -p "$att_dir" "$abs_dir"; then
        echo "  [ERROR] Could not create the archive folders."
        return 1
    fi

    # One timestamp for the whole run, so both logs share it.
    stamp=$(date +%Y%m%d_%H%M%S)
    echo "Archiving logs for $PROJECT_DIR (timestamp $stamp)..."

    archive_one "$att_log" "$att_dir/attendance_${stamp}.log"
    rc=$?
    if [ "$rc" -eq 0 ]; then archived=$((archived + 1)); fi
    if [ "$rc" -eq 1 ]; then failed=1; fi

    archive_one "$abs_log" "$abs_dir/absent_${stamp}.log"
    rc=$?
    if [ "$rc" -eq 0 ]; then archived=$((archived + 1)); fi
    if [ "$rc" -eq 1 ]; then failed=1; fi

    if [ "$archived" -eq 0 ] && [ "$failed" -eq 0 ]; then
        echo "No logs found. Run the application first (menu option 2)."
    else
        echo "Summary: $archived log(s) archived."
        ls -R "$PROJECT_DIR/archives"
    fi

    if [ "$failed" -eq 1 ]; then
        return 1
    fi
    return 0
}

check_prerequisites
main_menu
