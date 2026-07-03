# Campus Net Keepalive

Windows campus network keepalive tool for Dr.COM / ePortal style portals.

This project is designed as a green script tool:

- no browser pop-up
- no foreground click automation
- no Windows service
- no registry changes
- no global installation
- all local state stays in this folder
- credentials are encrypted with Windows DPAPI for the current Windows user

## How It Works

The script does not blindly log in every minute.

Each run follows this conservative flow:

1. Query `online_list` through the portal IP.
2. If already online, exit quietly unless a low-frequency heartbeat log is due.
3. If offline once, record the state and exit.
4. If offline twice in a row, send one login request.
5. Re-check `online_list`.
6. If login failed, enter cooldown and stop retrying for a while.

This avoids the common "system busy" problem caused by repeated login attempts.

## Files

```text
campus_keepalive.ps1   Main background keepalive script
run_hidden.vbs         Hidden launcher used by Task Scheduler
setup_gui.ps1          Visual setup wizard for normal users
setup.ps1              Creates local config.ini and encrypted credentials.xml
install_task.ps1       Installs the Windows scheduled task
uninstall_task.ps1     Removes the Windows scheduled task
config.example.ini     Example configuration
campus_keepalive.ahk   Legacy screenshot-click fallback
```

Local files created at runtime:

```text
config.ini             Local portal/network settings, ignored by Git
credentials.xml        DPAPI-encrypted credential, ignored by Git
keepalive.log          Small rotating log, ignored by Git
keepalive.*.log        Old rotated logs, ignored by Git and auto-cleaned
state.json             Cooldown/offline state, ignored by Git
```

## Visual Setup

For normal users, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\setup_gui.ps1
```

The setup window lets you configure:

- verification website
- portal server IP and port
- operator suffix
- account and password
- self-check interval
- offline confirmation count
- failure cooldown
- log heartbeat and cleanup policy

Click `Save and configure` to write local config, save the encrypted credential, and install or update the scheduled task.

## Manual Setup

Open PowerShell in this folder:

```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

For NJUPT China Mobile style portal, the defaults are usually:

```text
Portal server IP: 10.10.244.11
Portal HTTP port: 801
Account suffix: @cmcc
Portal account prefix: ,0,
```

If auto network detection picks a VPN/TUN adapter, set:

```text
Network interface alias: WLAN
```

or fill in the WLAN IPv4 and MAC manually.

## Manual Test

Run once:

```powershell
powershell -ExecutionPolicy Bypass -File .\campus_keepalive.ps1
```

Then inspect:

```powershell
Get-Content .\keepalive.log -Tail 20
```

If you are already online, the script should not send a login request. It logs `Online` only when the state changes or when the heartbeat interval is reached.

## Log Cleanup

Default logging policy:

```text
online_heartbeat_minutes=360
max_log_bytes=65536
retention_days=3
max_archives=3
```

This means normal online checks do not create one log line per minute. The current log rotates around 64 KB, rotated logs older than 3 days are deleted, and at most 3 rotated logs are kept.

## Install Background Task

After manual test:

```powershell
powershell -ExecutionPolicy Bypass -File .\install_task.ps1
```

The task runs once every minute while Windows Task Scheduler is active for the current user.

If `setup_gui.ps1` sets another interval, `install_task.ps1` uses that value from `config.ini`.

Task Scheduler starts `run_hidden.vbs`, and the VBS launcher starts PowerShell hidden. The script exits quickly after each check. It is not a resident background process.

## Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall_task.ps1
```

This removes only the scheduled task. Local files are kept in the folder so you can inspect logs or reinstall later.

To fully remove local state, delete:

```text
config.ini
credentials.xml
keepalive.log
keepalive.*.log
state.json
```

## Proxy And VPN Notes

The script uses the portal IP directly and passes `-Proxy $null` to PowerShell web requests.

This avoids normal HTTP browser proxy settings. If your VPN/TUN client captures all traffic, add a direct route for the portal IP or configure the VPN rule engine to direct-connect `10.10.244.11`.

## Safety Rules

- Do not commit `config.ini`.
- Do not commit `credentials.xml`.
- Do not lower `cooldown_seconds` aggressively.
- Do not replace `online_list` with `chkstatus` unless your portal proves that `chkstatus` is reliable.

For this portal, `online_list` is the reliable source of truth.
