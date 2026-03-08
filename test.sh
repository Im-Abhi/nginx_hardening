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

# =================== LOGGING START ===========================
for file in "$BASE_DIR/checks/logging/"*; do
    source "$file"
done

run_control "3.1" "Ensure detailed logging is enabled" check_detailed_logging remediate_detailed_logging
run_control "3.2" "Ensure access logging is enabled" check_access_logging remediate_access_logging
run_control "3.3" "Ensure error logging is enabled and set to info level" check_error_logging remediate_error_logging
run_control "3.4" "Ensure log files are rotated" check_log_rotation remediate_log_rotation
run_control "3.5" "Ensure error logs are sent to a remote syslog server" check_remote_syslog remediate_remote_syslog
run_control "3.6" "Ensure access logs are sent to a remote syslog server" check_remote_access_syslog remediate_remote_access_syslog
# =================== LOGGING END ===========================

echo "--------------------------------"
echo "Summary: PASS=$PASS FAIL=$FAIL REMEDIATED=$REMEDIATED"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1

# =================== ENCRYPTION START ===========================
for file in "$BASE_DIR/checks/encryption/"*; do
    source "$file"
done

check_http_to_https_redirect
check_ssl_certificate_configured
check_ssl_protocols
check_ssl_dhparam
check_ocsp_stapling
check_hsts_configuration
check_ssl_session_tickets_disabled
check_http2_enabled
check_pfs_ciphers
check_weak_ciphers_disabled
check_private_key_permissions
# =================== ENCRYPTION END ===========================


# ============= REQUEST FILTERING & RESTRICTIONS START ===============
for file in "$BASE_DIR/checks/request_filtering_restrictions/"*; do
    source "$file"
done

check_ip_based_restrictions
check_client_timeouts
check_client_max_body_size
check_large_client_header_buffers
check_limit_conn
check_limit_req
check_x_frame_options
check_x_content_type_options
check_content_security_policy
check_referrer_policy
# ============= REQUEST FILTERING & RESTRICTIONS END ===============



