# Deploy Agent: Student Attendance Tracker

**Author:** Milka (GitHub: milka-05)
**Video walkthrough:** (https://youtu.be/1nt2Eylada4)

`deploy_agent.sh` is a Bash script that deploys the Student Attendance Tracker
(a Python app), runs it, and archives its logs. It also handles Ctrl+C and
Ctrl+Z cleanly while a deployment is in progress.

## Repository layout

    deploy_agent_milka-05/
    |-- deploy_agent.sh        the script (all three features + signal handling)
    |-- templates/             the three provided files, never modified
    |   |-- attendance_checker.py
    |   |-- assets.csv
    |   `-- config.json
    |-- README.md
    `-- .gitignore

A deployed project is created in the folder you run the script from:

    attendance_tracker_{name}/
    |-- attendance_checker.py
    |-- Helpers/
    |   |-- assets.csv
    |   `-- config.json
    |-- reports/               filled by the app (attendance.log, absent.log)
    `-- archives/              created by Feature 3
        |-- attendance/
        `-- absent/

## Requirements

Bash, `python3` and `zip`. The script checks for `python3` and `zip` at
startup and stops with a clear message if either is missing.

## How to run and choose a feature

    git clone https://github.com/milka-05/deploy_agent_milka-05.git
    cd deploy_agent_milka-05
    chmod +x deploy_agent.sh
    ./deploy_agent.sh

I chose an **interactive menu** (no command-line flags):

    1) Deploy a new project
    2) Run an existing project
    3) Archive logs
    4) Exit

Invalid menu input is rejected and the menu is shown again.

## Feature 1: Deploy

1. Pre-flight check for `python3` (version is printed) and `zip`.
2. Asks for a project name (letters, numbers, `-` and `_` only; empty names
   are rejected) and builds `attendance_tracker_{name}/`.
3. If that folder exists, the script asks before overwriting. Answering `n`
   aborts with exit code 1 and changes nothing.
4. Copies `attendance_checker.py` and `config.json` from `templates/`
   unmodified, then builds the roster:
   - **Option A:** copy the first N students (plus header) from
     `templates/assets.csv`. Each has 4 prior sessions.
   - **Option B:** generate N fresh students (up to 12) from arrays in the
     script, with Attendance Count and Absence Count both 0.
   N must be a whole number within range.
5. Sets permissions: `chmod +x attendance_checker.py` and
   `chmod 600 Helpers/config.json`, then prints them with `ls -l`.
6. Offers to update the alert thresholds (see below).
7. Verifies the deployment by running the application (Feature 2).

### total_sessions and the roster

`total_sessions` must always be **one more than the prior sessions recorded**
in the roster (the app prints a note when they disagree):

- Option A: 4 prior sessions, so `total_sessions` stays at **5**.
- Option B: 0 prior sessions, so the script sets `total_sessions` to **1**,
  by editing the *deployed* `config.json` with `sed` (never the template).

The app does not change `total_sessions` itself. Before each new session, the
instructor must increase it by one in `Helpers/config.json`.

### Threshold update

The script asks `Update the attendance alert thresholds? (y/n)`. If yes, it
asks for `warning` (default 75) and `failure` (default 50); pressing Enter
keeps the default. Input is validated **before** `sed` runs:

- digits only (empty, letters and negative numbers are rejected)
- at most 100
- `failure` must be lower than `warning`

Then `sed -i` edits only those two lines of the deployed `config.json`:

    sed -i "s/\"warning\": [0-9]*/\"warning\": $warning/" config.json
    sed -i "s/\"failure\": [0-9]*/\"failure\": $failure/" config.json

The file is not reformatted or reordered, and it stays valid JSON.

## Feature 2: Run

Choose option 2 and enter the project name. The script checks that the
project and its three files exist, then runs the app **from inside the
project folder**, because the app uses relative paths such as
`Helpers/config.json`:

    ( cd attendance_tracker_{name} && python3 attendance_checker.py )

## Feature 3: Archive logs

Choose option 3 and enter the project name. The script:

1. Creates `archives/attendance/` and `archives/absent/`.
2. Takes **one** timestamp (`date +%Y%m%d_%H%M%S`) for the whole run.
3. Moves `reports/attendance.log` to
   `archives/attendance/attendance_YYYYMMDD_HHMMSS.log` and
   `reports/absent.log` to `archives/absent/absent_YYYYMMDD_HHMMSS.log`.
4. Prints which logs were archived and their final paths.

**Trigger:** archiving runs only when you choose menu option 3, after a run.

**Missing logs:** if a log does not exist (for example nobody was absent, so
`absent.log` was never created), that log is reported as `[SKIPPED]` and the
other is still archived. If neither exists, the script says so. It never crashes.

**Why `mv` and not `cp`:** the app appends to its logs every session. Moving
means each archive holds only the sessions since the last archive, and
running the archive twice is safe (the second run finds nothing).

## Ctrl+C / Ctrl+Z handling during deployment

**Trigger:** while Feature 1 is running, `SIGINT` (Ctrl+C) and `SIGTSTP`
(Ctrl+Z) are trapped. On either signal the script:

1. prints that the deployment was interrupted, naming the signal;
2. zips whatever exists of the project into
   `attendance_tracker_{name}_archive.zip` (in the folder you ran the script from);
3. **deletes** the incomplete project folder, but only if the zip succeeded;
4. prints `Session closed cleanly.` and exits with code 130 (Ctrl+C) or
   148 (Ctrl+Z).

Safeguards:

- The folder is only zipped and deleted if **this run created it**. Pressing
  Ctrl+C at the "Overwrite it?" prompt leaves the user's old project untouched.
- The trap is switched off once deployment finishes, so the app's own
  Ctrl+C handling during a marking session is not affected.
- Interrupting before any file exists prints a message and creates no zip.

### How to test it

1. Run `./deploy_agent.sh`, choose 1, enter `t8`, and press **Ctrl+C** at the
   `Choose A or B:` prompt.
2. Run these one at a time:

        echo "Exit code: $?"            # 130
        ls -d attendance_tracker_t8     # should say: No such file or directory
        python3 -m zipfile -l attendance_tracker_t8_archive.zip

3. For Ctrl+Z, deploy `t9` with option B and press **Ctrl+Z** at the
   threshold question. Expect exit code 148, `jobs` printing nothing, and a
   zip that also contains `Helpers/assets.csv`.

The zip contains the project as far as it got: if you interrupt before the
roster step, it has `attendance_checker.py`, `Helpers/config.json` and an
empty `reports/`, but no `assets.csv`.

## How I tested the deployed structure

- `ls -R attendance_tracker_{name}` shows `attendance_checker.py`, `Helpers/`
  (with `assets.csv` and `config.json`) and `reports/`. `Helpers` has a capital H.
- `cmp templates/attendance_checker.py attendance_tracker_{name}/attendance_checker.py`
  and the same for `config.json` (Option A, no threshold change) print nothing,
  so the copies are identical.
- `diff` between the template config and an Option B / custom-threshold config
  shows only the `warning`, `failure` and `total_sessions` lines changed.
- `python3 -m json.tool Helpers/config.json` confirms the file is still valid JSON.
- `ls -l` shows `-rwxr-xr-x` on the app and `-rw-------` on the config.
- Running the app (deploy verification) proves structure, roster and config
  work together.
- Tested with bad input (empty and invalid names, non-numeric and
  out-of-range numbers, bad menu choices) and with the existing-folder,
  blocked-folder, missing-log and interrupt cases above.
