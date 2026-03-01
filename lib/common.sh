#!bin/bash

PASS=0
FAIL=0

pass() {
    echo "[PASS] $1"
    ((PASS++)) 
}

fail() {
    echo "[FAIL] $1"
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