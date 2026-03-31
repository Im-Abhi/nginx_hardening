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