#!bin/bash

if [[ -t 1 ]]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    NC='\033[0m'  # No Color
else
    GREEN=''
    RED=''
    YELLOW=''
    NC=''
fi

PASS=0
FAIL=0

pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASS++))
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAIL++))
}

apply_fix() {
    if [[ "${MODE:-audit}" == "remediate" ]]; then
        read -r -p "This will modify system configuration. Continue? (yes/no): " CONFIRM
        [[ "$CONFIRM" == "yes" ]] || {
            echo "Remediation cancelled."
            return 1
        }
        "$@"
    else
        echo "Audit mode — remediation skipped"
    fi
}