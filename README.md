# Campus Net Keepalive

Windows campus network keepalive toolkit for Dr.COM / ePortal style portals.

This repository contains two clearly separated methods:

| Method | Recommended | User experience | Best for |
| --- | --- | --- | --- |
| Method 1: HTTP background keepalive | Yes | No browser popup, no mouse click, runs hidden | Dr.COM / ePortal portals where the login API can be called directly |
| Method 2: AutoHotkey screenshot click | Fallback only | Opens browser and clicks the login button image | Portals whose HTTP login API cannot be reproduced |

If Method 1 works for your campus network, use Method 1.

## Method 1: HTTP Background Keepalive

This is the recommended method and the main direction of this project.

It calls the campus portal API directly in the background:

1. Query the portal `online_list` endpoint.
2. If already online, exit quietly.
3. If offline once, record the state and wait for the next check.
4. If offline twice in a row, send one login request.
5. Re-check online state.
6. If login fails, enter cooldown to avoid "system busy" errors.

### Features

- no browser popup
- no foreground click automation
- no mouse or keyboard interruption
- no resident background process
- no Windows service
- no registry changes
- credentials encrypted with Windows DPAPI for the current Windows user
- logs and state files stay in the project folder
- log rotation and cleanup are built in

### Quick Start

Run the visual setup wizard:

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
- scheduled task installation

Click `Save and configure` to write local config, save the encrypted credential, and install or update the scheduled task.

### Manual Test

Run once:

```powershell
powershell -ExecutionPolicy Bypass -File .\campus_keepalive.ps1
```

Inspect logs:

```powershell
Get-Content .\keepalive.log -Tail 20
```

If already online, the script should not send a login request. It writes `Online` only when the state changes or when the heartbeat interval is reached.

### Install Or Update Task

If you did not install the task from `setup_gui.ps1`, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\install_task.ps1
```

Task Scheduler starts `run_hidden.vbs`, and the VBS launcher starts PowerShell hidden. The script exits quickly after each check.

### Uninstall Task

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall_task.ps1
```

This removes only the scheduled task. Local config, credentials, logs, and state files stay in the folder unless you delete them.

## Method 2: AutoHotkey Screenshot Click

This is the old fallback method.

It opens the portal page in a browser, searches for a saved screenshot of the login button, clicks it, then closes or leaves the page according to the script behavior.

Use this method only when Method 1 cannot reproduce your campus portal login request.

### Requirements

- AutoHotkey v2
- Browser can open the campus portal page
- Browser has already saved the account and password
- A screenshot of the login button is saved as `signin_button.png`

### Basic Steps

1. Install AutoHotkey v2.
2. Put `campus_keepalive.ahk` and `signin_button.png` in the same folder.
3. Edit the AHK config values if needed.
4. Run `campus_keepalive.ahk`.

### Limitations

- may pop up a browser window
- may steal focus briefly
- depends on screen resolution, scaling, browser zoom, and button appearance
- less suitable for long-term unattended use

## Which Method Should I Use?

Use Method 1 if:

- your portal is Dr.COM / ePortal style
- your portal has an API similar to `/eportal/portal/login`
- you want no popup and no interruption
- you want a green, folder-contained tool

Use Method 2 if:

- the portal API cannot be reproduced
- the browser login works reliably with saved password
- occasional browser popup is acceptable

## Files

Method 1 files:

```text
setup_gui.ps1              Visual setup wizard
campus_keepalive.ps1       Main HTTP background keepalive script
run_hidden.vbs             Hidden launcher used by Task Scheduler
setup.ps1                  Command-line setup
install_task.ps1           Install or update scheduled task
uninstall_task.ps1         Remove scheduled task
reset_credentials_gui.ps1  Reset encrypted credential with a GUI
config.example.ini         Example configuration
```

Method 2 files:

```text
campus_keepalive.ahk       AutoHotkey screenshot-click fallback
signin_button.png          User-provided login button screenshot
```

Local runtime files, ignored by Git:

```text
config.ini                 Local portal/network settings
credentials.xml            DPAPI-encrypted credential
keepalive.log              Current log
keepalive.*.log            Rotated logs
state.json                 Cooldown/offline state
```

## Log Cleanup

Default logging policy:

```text
online_heartbeat_minutes=360
max_log_bytes=65536
retention_days=3
max_archives=3
```

Normal online checks do not create one log line per minute. The current log rotates around 64 KB, rotated logs older than 3 days are deleted, and at most 3 rotated logs are kept.

## Proxy And VPN Notes

Method 1 uses the portal IP directly and passes `-Proxy $null` to PowerShell web requests.

This avoids normal HTTP browser proxy settings. If your VPN/TUN client captures all traffic, add a direct route for the portal IP or configure the VPN rule engine to direct-connect the portal server IP.

## Safety Rules

- Do not commit `config.ini`.
- Do not commit `credentials.xml`.
- Do not commit logs.
- Do not lower `cooldown_seconds` aggressively.
- Prefer `online_list` over `chkstatus` unless your portal proves otherwise.

