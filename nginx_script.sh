#!/bin/bash

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load shared helpers
source "$BASE_DIR/lib/common.sh"

echo "Running nginx security audit..."
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
check_nginx_user_locked
check_invalid_shell
# =================== ACCOUNT SECURITY END ===========================


# ================== PERMISSIONS & OWNERSHIP START ======================
for file in "$BASE_DIR/checks/permissions_&_ownerships/"*; do
    source "$file"
done

check_nginx_ownership
check_nginx_permissions
# ================== PERMISSIONS & OWNERSHIP END ======================


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


echo "--------------------------------"
echo "Summary: PASS=$PASS FAIL=$FAIL"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
