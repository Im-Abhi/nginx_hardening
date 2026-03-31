## Local setup 
```bash
git clone https://github.com/Im-Abhi/nginx_hardening.git
cd nginx_hardening
```

## Run with `sudo` permissions
- Audit Mode (default)
```bash
sudo ./nginx_script.sh
```
- Auto-Remediation Mode (those possible)
```bash
sudo ./nginx_script.sh --remediate
```
## Permission Errors?
Add the execute permission to the script
```bash
chmod +x nginx_script.sh
```

## Want to run specific tests??
- Copy the control block from `nginx_script.sh` to `test.sh`
OR
- use `source <control-file-path>`
```bash
run_control <control description check_<control-name> remediate_<control-name>
```
Example:
```bash
source ./checks/encryption/http2.sh
run_control "4.1.13" "Ensure HTTP/2 is used" check_http2_enabled remediate_http2_enabled
```
