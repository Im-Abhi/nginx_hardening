#!/usr/bin/env bash

# CIS 5.2.5 – Ensure rate limits by IP address are set
# Automation Level: Manual

check_ip_rate_limits() {
    local config_dump=""
    local findings=""

    # -------- Prerequisite --------
    if ! command -v nginx >/dev/null 2>&1; then
        echo "MANUAL: nginx binary not found"
        return 0
    fi

    if ! nginx -t >/dev/null 2>&1; then
        echo "MANUAL: nginx configuration invalid"
        return 0
    fi

    if ! config_dump="$(nginx -T 2>/dev/null)"; then
        echo "MANUAL: nginx configuration dump failed"
        return 0
    fi

    # -------- 1. Check for limit_req_zone in http context --------
    # Benchmark expects something like:
    #   limit_req_zone $binary_remote_addr zone=ratelimit:10m rate=5r/s;
    if ! echo "$config_dump" | awk '
        BEGIN { in_http=0; depth=0; found=0 }
        /^[[:space:]]*#/ { next }

        /^[[:space:]]*http[[:space:]]*\{/ {
            in_http=1
            depth=1
            next
        }

        in_http {
            opens = gsub(/\{/, "{")
            closes = gsub(/\}/, "}")

            if (depth == 1 && $0 ~ /^[[:space:]]*limit_req_zone[[:space:]]+\$binary_remote_addr[[:space:]]+zone=[^:;[:space:]]+:[0-9]+[kKmM]?[[:space:]]+rate=[0-9]+r\/[smhd][[:space:]]*;/) {
                found=1
            }

            depth += opens
            depth -= closes

            if (depth <= 0) {
                in_http=0
                depth=0
            }
        }

        END { exit(found ? 0 : 1) }
    '; then
        findings+="  - No compliant 'limit_req_zone \$binary_remote_addr ... rate=...' directive found in the http{} context"$'\n'
    fi

    # -------- 2. Check for active limit_req enforcement --------
    # Benchmark expects something like:
    #   limit_req zone=ratelimit burst=10 nodelay;
    if ! echo "$config_dump" | grep -Eq '^[[:space:]]*limit_req[[:space:]]+zone=[^;[:space:]]+([[:space:]]+burst=[0-9]+)?([[:space:]]+nodelay)?[[:space:]]*;'; then
        findings+="  - No active 'limit_req zone=...' directive found in any server/location context"$'\n'
    fi

    # -------- 3. Optional benchmark-shape guidance --------
    # This is not strict fail logic, but helps benchmark alignment
    if echo "$config_dump" | grep -Eq '^[[:space:]]*limit_req_zone[[:space:]]+\$remote_addr'; then
        findings+="  - [INFO] 'limit_req_zone' uses \$remote_addr instead of the benchmark-recommended \$binary_remote_addr"$'\n'
    fi

    # -------- Final Reporting --------
    if [[ -z "$findings" ]]; then
        return 0
    fi

    echo -e "MANUAL: IP rate limiting review required:\n${findings%$'\n'}\n\
\nRemediation Guidance:\n\
  - Define a request rate limiting zone in the http{} block, for example:\n\n\
        limit_req_zone \$binary_remote_addr zone=ratelimit:10m rate=5r/s;\n\n\
  - Apply the rate limit in the relevant server{} or location{} block, for example:\n\n\
        location / {\n\
            limit_req zone=ratelimit burst=10 nodelay;\n\
        }\n\n\
  - Tune the zone name, rate, and burst values to your application's real traffic profile."

    return 0
}

remediate_ip_rate_limits() {
    # Intentionally manual:
    # Blindly enforcing request rate limits can break APIs, shared-IP clients,
    # health checks, CDNs, and burst-heavy legitimate traffic.
    return 1
}