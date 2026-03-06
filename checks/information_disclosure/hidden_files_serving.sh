#!/usr/bin/env bash

# CIS 2.5.3 – Ensure hidden file serving is disabled
# Automation Level: Manual (Requires admin review for Let's Encrypt exceptions)

check_hidden_files_disabled() {

    local errors=""
    local is_compliant=0

    # AWK state machine to detect a location block protecting hidden files
    if nginx -T 2>/dev/null | awk '
        BEGIN { found=0; in_loc=0 }

        # Detect location blocks targeting hidden files (/.)
        /^[[:space:]]*location[^{]*\/\\\./ {
            in_loc=1
        }

        # Look for deny all; inside the block
        in_loc && /deny[[:space:]]+all[[:space:]]*;/ {
            found=1
            exit
        }

        # Exit block when closing brace appears
        in_loc && /\}/ {
            in_loc=0
        }

        END {
            if (found) exit 0
            else exit 1
        }
    '; then
        is_compliant=1
    fi


    if [[ "$is_compliant" -eq 0 ]]; then
        errors+="  - No 'location' block found that explicitly denies access to hidden files (.*)\n"
    fi


    if [[ -n "$errors" ]]; then

        errors+="\n  Remediation Guidance:\n"
        errors+="  - Edit your NGINX configuration and add the following to your server block(s):\n"
        errors+="\n"
        errors+="      location ~ /\\. {\n"
        errors+="          deny all;\n"
        errors+="          return 404;\n"
        errors+="      }\n"
        errors+="\n"
        errors+="  - IMPORTANT: If you use Let's Encrypt you MUST add this exception above the rule:\n"
        errors+="\n"
        errors+="      location ~ /\\.well-known/acme-challenge {\n"
        errors+="          allow all;\n"
        errors+="      }\n"

        echo -e "${errors%\\n}"
    fi
}


remediate_hidden_files_disabled() {

    # This control intentionally requires manual remediation.
    # Automatically inserting location rules may break:
    #  - Let's Encrypt ACME validation
    #  - application routing
    #  - existing location precedence

    return 1
}