#!bin/bash

if [[ -t 1 ]]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'  # No Color
else
    GREEN=''
    RED=''
    BLUE=''
    YELLOW=''
    NC=''
fi

PASS=0
FAIL=0
REMEDIATED=0
MANUAL=0

pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASS++))
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAIL++))
}

remediated() {
    echo -e "${BLUE}[REMEDIATED]${NC} $1"
    ((REMEDIATED++))
}

manual() {
    echo -e "${YELLOW}[MANUAL]${NC} $1"
    ((MANUAL++))
}

run_control() {

    local control_id="$1"
    local control_name="$2"
    local check_function="$3"
    local remediate_function="$4"

    local output
    output="$($check_function)"

    # -------- PASS --------
    if [[ -z "$output" ]]; then
        pass "$control_id $control_name"
        return
    fi

    # -------- MANUAL --------
    if [[ "$output" == MANUAL:* ]]; then
        manual "$control_id $control_name"
        echo -e "${output#MANUAL:}"
        return
    fi

    # -------- FAIL / REMEDIATE --------
    if [[ "$MODE" == "remediate" && -n "$remediate_function" ]]; then
        if "$remediate_function"; then
            remediated "$control_id $control_name"
        else
            fail "$control_id $control_name"
            echo -e "$output"
        fi
    else
        fail "$control_id $control_name"
        echo -e "$output"
    fi
}

handle_failure() {
    local message="$1"
    local remediation_function="$2"

    if [[ "$MODE" == "remediate" ]]; then
        if "$remediation_function"; then
            remediated "$message"
        else
            fail "$message (remediation failed)"
        fi
    else
        fail "$message"
    fi
}

apply_fix() {
    if [[ "${MODE:-audit}" == "remediate" ]]; then
        read -r -p "This will modify system configuration. Continue? (yes/no): " CONFIRM
        [[ "$CONFIRM" == "yes" ]] || {
            echo "Remediation cancelled."
            return 1
        }
        "$@"
    fi
}