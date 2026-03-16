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

# =================== ENCRYPTION START ===========================
for file in "$BASE_DIR/checks/encryption/"*; do
    source "$file"
done

run_control "4.1.1" "Ensure HTTP is redirected to HTTPS" check_http_to_https_redirect remediate_http_to_https_redirect
run_control "4.1.2" "Ensure a trusted certificate and trust chain is installed" check_ssl_certificate_configured remediate_ssl_certificate_configured
run_control "4.1.3" "Ensure private key permissions are restricted" check_private_key_permissions remediate_private_key_permissions
run_control "4.1.4" "Ensure only modern TLS protocols are used" check_ssl_protocols remediate_ssl_protocols
run_control "4.1.5" "Disable weak ciphers" check_weak_ciphers_disabled remediate_weak_ciphers_disabled
run_control "4.1.6" "Ensure custom Diffie-Hellman parameters are used" check_ssl_dhparam remediate_ssl_dhparam
run_control "4.1.7" "Ensure OCSP stapling is enabled" check_ocsp_stapling remediate_ocsp_stapling
run_control "4.1.8" "Ensure HTTP Strict Transport Security (HSTS) is enabled" check_hsts_configuration remediate_hsts_configuration
check_ssl_session_tickets_disabled
check_http2_enabled
check_pfs_ciphers
# =================== ENCRYPTION END ===========================

echo "--------------------------------"
echo "Summary: PASS=$PASS FAIL=$FAIL REMEDIATED=$REMEDIATED"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1


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



