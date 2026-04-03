#!/usr/bin/env bash
set -uo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

MODE="audit"   # SAFE DEFAULT
MODULE="all"

usage() {
    echo "Usage: $0 [--audit | --remediate] [--module <module_name>]"
    echo -e "Available modules: \n * minimize_modules \n * account_security \n * permissions_ownerships \n * network_configuration \n * information_disclosure \n * logging \n * encryption \n * request_filtering_restrictions"
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
        --module|-m)
            if [[ -n "${2:-}" ]]; then
                MODULE="$2"
                shift 2
            else
                echo "Error: --module requires a module name."
                usage
            fi
            ;;
        *)
            usage
            ;;
    esac
done

export MODE
export MODULE

# Load shared helpers
source "$BASE_DIR/lib/common.sh"

# Confirm remediation once
if [[ "$MODE" == "remediate" ]]; then
    read -r -p "Remediation mode will modify system configuration. Continue? (yes/no): " CONFIRM
    [[ "$CONFIRM" == "yes" ]] || exit 1
fi

echo "Running nginx security script..."
echo "Mode: $MODE"
echo "Module: $MODULE"
echo "--------------------------------"

# Load checks

# =================== MINIMIZE MODULES START ===========================
if [[ "$MODULE" == "all" || "$MODULE" == "minimize_modules" ]]; then
    for file in "$BASE_DIR/checks/minimize_modules/"*; do
        source "$file"
    done

    run_control "2.1.4" "Ensure the autoindex module is disabled" check_autoindex remediate_autoindex
fi
# =================== MINIMIZE MODULES END ===========================



# =================== ACCOUNT SECURITY START ===========================
if [[ "$MODULE" == "all" || "$MODULE" == "account_security" ]]; then
    for file in "$BASE_DIR/checks/account_security/"*; do
        source "$file"
    done

    run_control "2.2.1" "Ensure NGINX runs as a non-privileged dedicated service account" check_dedicated_service_account remediate_dedicated_service_account
    run_control "2.2.2" "Ensure the NGINX service account is locked" check_service_account_locked remediate_service_account_locked
    run_control "2.2.3" "Ensure the NGINX service account has a non-login shell" check_invalid_shell remediate_invalid_shell
fi
# =================== ACCOUNT SECURITY END ===========================


# ================== PERMISSIONS & OWNERSHIP START ======================
if [[ "$MODULE" == "all" || "$MODULE" == "permissions_ownerships" ]]; then
    for file in "$BASE_DIR/checks/permissions_&_ownerships/"*; do
        source "$file"
    done

    run_control "2.3.1" "Ensure NGINX directories and files are owned by root" check_files_directories_owner remediate_files_directories_owner
    run_control "2.3.2" "Ensure access to NGINX directories and files is restricted" check_files_directories_access remediate_files_directories_access
    run_control "2.3.3" "Ensure the NGINX PID file is secured" check_nginx_pid_file remediate_nginx_pid_file
    run_control "2.3.4" "Ensure the core dump directory is secured" check_core_dump_directory remediate_core_dump_directory
fi
# ================== PERMISSIONS & OWNERSHIP END ======================


# ================== NETWORK CONFIGURATION START ======================
if [[ "$MODULE" == "all" || "$MODULE" == "network_configuration" ]]; then
    for file in "$BASE_DIR/checks/network_configuration/"*; do
        source "$file"
    done

    run_control "2.4.1" "Ensure NGINX only listens on authorized ports" check_listen_ports remediate_listen_ports
    run_control "2.4.2" "Ensure requests for unknown host names are rejected" check_unknown_host_rejection remediate_unknown_host_rejection
    run_control "2.4.3" "Ensure keepalive_timeout is 10 seconds or less, but not 0" check_keepalive_timeout remediate_keepalive_timeout
    run_control "2.4.4" "Ensure send_timeout is 10 seconds or less, but not 0" check_send_timeout remediate_send_timeout
fi
# ================== NETWORK CONFIGURATION END =============================



# =================== INFORMATION DISCLOSURE START ===========================
if [[ "$MODULE" == "all" || "$MODULE" == "information_disclosure" ]]; then
    for file in "$BASE_DIR/checks/information_disclosure/"*; do
        source "$file"
    done

    run_control "2.5.1" "Ensure server_tokens directive is set to off" check_server_tokens remediate_server_tokens
    run_control "2.5.2" "Ensure default error and index.html pages do not reference NGINX" check_default_pages_branding remediate_default_pages_branding
    run_control "2.5.3" "Ensure hidden file serving is disabled" check_hidden_files_disabled remediate_hidden_files_disabled
    run_control "2.5.4" "Ensure the NGINX reverse proxy does not enable information disclosure" check_proxy_hide_headers remediate_proxy_hide_headers
fi
# =================== INFORMATION DISCLOSURE END ===========================


# =================== LOGGING START ===========================
if [[ "$MODULE" == "all" || "$MODULE" == "logging" ]]; then
    for file in "$BASE_DIR/checks/logging/"*; do
        source "$file"
    done

    run_control "3.1" "Ensure detailed logging is enabled" check_detailed_logging remediate_detailed_logging
    run_control "3.2" "Ensure access logging is enabled" check_access_logging remediate_access_logging
    run_control "3.3" "Ensure error logging is enabled and set to info level" check_error_logging remediate_error_logging
    run_control "3.4" "Ensure log files are rotated" check_log_rotation remediate_log_rotation
    run_control "3.5" "Ensure error logs are sent to a remote syslog server" check_remote_syslog remediate_remote_syslog
    run_control "3.6" "Ensure access logs are sent to a remote syslog server" check_remote_access_syslog remediate_remote_access_syslog
fi
# =================== LOGGING END ===========================


# =================== ENCRYPTION START ===========================
if [[ "$MODULE" == "all" || "$MODULE" == "encryption" ]]; then
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
    run_control "4.1.13" "Ensure HTTP/2 is used" check_http2_enabled remediate_http2_enabled
    run_control "4.1.14" "Ensure only Perfect Forward Secrecy Ciphers are Leveraged" check_pfs_ciphers remediate_pfs_ciphers
fi
# =================== ENCRYPTION END ===========================


# ============= REQUEST FILTERING & RESTRICTIONS START ===============
if [[ "$MODULE" == "all" || "$MODULE" == "request_filtering_restrictions" ]]; then
    for file in "$BASE_DIR/checks/request_filtering_restrictions/"*; do
        source "$file"
    done

    run_control "5.1.1" "Ensure allow and deny filters limit access to specific IP addresses" check_ip_based_restrictions remediate_ip_based_restrictions
    run_control "5.2.1" "Ensure timeout values for reading the client header and body are set correctly" check_client_timeouts remediate_client_timeouts
    run_control "5.2.2" "Ensure the maximum request body size is set correctly" check_client_max_body_size remediate_client_max_body_size
    run_control "5.2.3" "Ensure the maximum buffer size for URIs is defined" check_large_client_header_buffers remediate_large_client_header_buffers
    run_control "5.2.4" "Ensure the number of connections per IP address is limited" check_limit_conn remediate_limit_conn
    run_control "5.2.5" "Ensure rate limits by IP address are set" check_ip_rate_limits remediate_ip_rate_limits
    run_control "5.3.1" "Ensure X-Frame-Options header is configured and enabled" check_x_frame_options remediate_x_frame_options
    run_control "5.3.2" "Ensure X-Content-Type-Options header is configured and enabled" check_x_content_type_options remediate_x_content_type_options
    run_control "5.3.3" "Ensure that Content Security Policy (CSP) is enabled and configured properly" check_content_security_policy remediate_content_security_policy
    run_control "5.3.4" "Ensure the Referrer Policy is enabled and configured properly" check_referrer_policy remediate_referrer_policy
fi
# ============= REQUEST FILTERING & RESTRICTIONS END ===============


echo "--------------------------------"
echo "Summary: PASS=$PASS FAIL=$FAIL REMEDIATED=$REMEDIATED"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1