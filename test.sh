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

# ================== PERMISSIONS & OWNERSHIP START ======================
for file in "$BASE_DIR/checks/permissions_&_ownerships/"*; do
    source "$file"
done

check_files_directories_owner
check_files_directories_access
check_nginx_pid_file
check_core_dump_directory
# ================== PERMISSIONS & OWNERSHIP END ======================


echo "--------------------------------"
echo "Summary: PASS=$PASS FAIL=$FAIL REMEDIATED=$REMEDIATED"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1


# ================== NETWORK CONFIGURATION START ======================
for file in "$BASE_DIR/checks/network_configuration/"*; do
    source "$file"
done

check_listen_ports
check_unknown_host_rejection
check_keepalive_timeout
check_send_timeout
# ================== NETWORK CONFIGURATION END =============================



# =================== INFORMATION DISCLOSURE START ===========================
for file in "$BASE_DIR/checks/information_disclosure/"*; do
    source "$file"
done

check_server_tokens
check_branding
check_hidden_files_disabled
check_proxy_hide_headers
# =================== INFORMATION DISCLOSURE END ===========================


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



