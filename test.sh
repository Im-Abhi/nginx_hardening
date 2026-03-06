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

# =================== INFORMATION DISCLOSURE START ===========================
for file in "$BASE_DIR/checks/information_disclosure/"*; do
    source "$file"
done

run_control "2.5.1" "Ensure server_tokens directive is set to off" check_server_tokens remediate_server_tokens
run_control "2.5.2" "Ensure default error and index.html pages do not reference NGINX" check_default_pages_branding remediate_default_pages_branding
check_hidden_files_disabled
check_proxy_hide_headers
# =================== INFORMATION DISCLOSURE END ===========================

echo "--------------------------------"
echo "Summary: PASS=$PASS FAIL=$FAIL REMEDIATED=$REMEDIATED"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1

# =================== LOGGING START ===========================
for file in "$BASE_DIR/checks/logging/"*; do
    source "$file"
done

check_access_logging
check_error_logging
check_log_rotation
check_remote_syslog
check_remote_access_syslog
# =================== LOGGING END ===========================


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



