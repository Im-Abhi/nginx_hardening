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

# =================== MINIMIZE MODULES START ===========================
for file in "$BASE_DIR/checks/minimize_modules/"*; do
    source "$file"
done

check_autoindex
# =================== MINIMIZE MODULES END ===========================



# =================== ACCOUNT SECURITY START ===========================
for file in "$BASE_DIR/checks/account_security/"*; do
    source "$file"
done

check_dedicated_service_account
check_service_account_locked
check_invalid_shell
# =================== ACCOUNT SECURITY END ===========================


# ================== PERMISSIONS & OWNERSHIP START ======================
for file in "$BASE_DIR/checks/permissions_&_ownerships/"*; do
    source "$file"
done

check_files_directories_owner
check_files_directories_access
check_nginx_pid_file
check_core_dump_directory
# ================== PERMISSIONS & OWNERSHIP END ======================


# ================== NETWORK CONFIGURATION START ======================
for file in "$BASE_DIR/checks/network_configuration/"*; do
    source "$file"
done

check_listen_ports
check_unknown_host_rejection
run_control "2.4.3" "Ensure keepalive_timeout is 10 seconds or less, but not 0" check_keepalive_timeout remediate_keepalive_timeout
run_control "2.4.4" "Ensure send_timeout is 10 seconds or less, but not 0" check_send_timeout remediate_send_timeout
# ================== NETWORK CONFIGURATION END =============================



# =================== INFORMATION DISCLOSURE START ===========================
for file in "$BASE_DIR/checks/information_disclosure/"*; do
    source "$file"
done

run_control "2.5.1" "Ensure server_tokens directive is set to off" check_server_tokens remediate_server_tokens
run_control "2.5.2" "Ensure default error and index.html pages do not reference NGINX" check_default_pages_branding remediate_default_pages_branding
run_control "2.5.3" "Ensure hidden file serving is disabled" check_hidden_files_disabled remediate_hidden_files_disabled
run_control "2.5.4" "Ensure the NGINX reverse proxy does not enable information disclosure" check_reverse_proxy remediate_reverse_proxy
# =================== INFORMATION DISCLOSURE END ===========================


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
run_control "4.1.11" "Ensure your domain is preloaded (HSTS Preload readiness)" check_hsts_preload remediate_hsts_preload
run_control "4.1.12" "Ensure session resumption is disabled" check_ssl_session_tickets_disabled remediate_ssl_session_tickets_disabled
check_http2_enabled
check_pfs_ciphers
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


echo "--------------------------------"
echo "Summary: PASS=$PASS FAIL=$FAIL REMEDIATED=$REMEDIATED"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
