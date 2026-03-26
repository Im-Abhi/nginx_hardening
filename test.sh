#!/usr/bin/env bash
set -uo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

MODE="audit"   # SAFE DEFAULT

usage() {
    echo "Usage: $0 [--audit | --remediate]"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --audit)
            MODE="audit"
            shift
            ;;
        --remediate)
            MODE="remediate"
            shift
            ;;
        *)
            usage
            ;;
    esac
done

export MODE

# Load shared helpers
source "$BASE_DIR/lib/common.sh"

# Confirm remediation once
if [[ "$MODE" == "remediate" ]]; then
    read -r -p "Remediation mode will modify system configuration. Continue? (yes/no): " CONFIRM
    [[ "$CONFIRM" == "yes" ]] || exit 1
fi

echo "Running nginx security script..."
echo "Mode: $MODE"
echo "--------------------------------"

# Load checks



# ============= REQUEST FILTERING & RESTRICTIONS START ===============
for file in "$BASE_DIR/checks/request_filtering_restrictions/"*; do
    source "$file"
done

run_control "5.1.1" "Ensure allow and deny filters limit access to specific IP addresses" check_ip_based_restrictions remediate_ip_based_restrictions
run_control "5.2.1" "Ensure timeout values for reading the client header and body are set correctly" check_client_timeouts remediate_client_timeouts
run_control "5.2.2" "Ensure the maximum request body size is set correctly" check_client_max_body_size remediate_client_max_body_size
run_control "5.2.3" "Ensure the maximum buffer size for URIs is defined" check_large_client_header_buffers remediate_large_client_header_buffers
run_control "5.2.4" "Ensure the number of connections per IP address is limited" check_limit_conn remediate_limit_conn
run_control "5.2.5" "Ensure rate limits by IP address are set" check_rate_limit_ip remediate_rate_limit_ip
run_control "5.3.1" "Ensure X-Frame-Options header is configured and enabled" check_x_frame_options remediate_x_frame_options
run_control "5.3.2" "Ensure X-Content-Type-Options header is configured and enabled" check_x_content_type_options remediate_x_content_type_options
check_content_security_policy
check_referrer_policy
# ============= REQUEST FILTERING & RESTRICTIONS END ===============

echo "--------------------------------"
echo "Summary: PASS=$PASS FAIL=$FAIL REMEDIATED=$REMEDIATED"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1


