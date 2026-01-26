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