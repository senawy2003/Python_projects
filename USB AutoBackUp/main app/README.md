# USB AutoBackup

A transparent, user-controlled Windows background application that automatically
backs up files from USB storage devices when they are connected.

---

## Features

- **System tray icon** — always visible, never hidden
- **USB auto-detection** via WMI Windows device events
- **Incremental backup** — SHA-256 hash comparison skips unchanged files
- **Preserved folder structure** from USB source
- **File type filtering** — Documents, Images, optional Videos
- **Device whitelist** — only backup approved USB labels
- **Persistent log file** at `%APPDATA%\USBAutoBackup\backup.log`
- **Settings panel** — full control over all behavior
- **Starts with Windows** (optional, via installer)

---

## Quick Start

### Requirements
- Windows 10 or 11
- Python 3.10+ ([python.org](https://python.org))

### Install
```
1. Double-click: install_and_run.bat   (run as Administrator)
2. Look for the teal USB icon in your system tray
```

### Manual run (no auto-start)
```bat
pip install -r requirements.txt
pythonw usb_backup_app.py
```

---

## Tray Menu

| Option | Description |
|---|---|
| ✓/✗ Auto Backup ON/OFF | Toggle backup on/off instantly |
| 📋 View Logs | Open live log viewer |
| ⚙ Settings | Open settings panel |
| ✕ Exit | Quit the application |

---

## Settings

| Setting | Description |
|---|---|
| Enable automatic backup | Master on/off switch |
| Backup Directory | Where files are saved (default: `D:\USB_Backups`) |
| Documents | Backs up `.pdf`, `.docx`, `.txt` |
| Images | Backs up `.jpg`, `.jpeg`, `.png` |
| Videos | Backs up `.mp4` (disabled by default — large files) |
| Whitelist | Restrict to specific USB device labels only |

---

## Backup Structure

```
D:\USB_Backups\
└── MyUSBDrive\           ← device label
    ├── Documents\
    │   └── report.pdf    ← original folder structure preserved
    └── Photos\
        └── vacation.jpg
```

---

## Files & Locations

| File | Location |
|---|---|
| Config | `%APPDATA%\USBAutoBackup\config.json` |
| Log | `%APPDATA%\USBAutoBackup\backup.log` |
| Startup shortcut | `%APPDATA%\...\Startup\USBAutoBackup.lnk` |

---

## Ethical Design

- No hidden or stealth operation
- System tray icon always visible
- User can disable at any time
- No network transmission — local backup only
- Open source — inspect `usb_backup_app.py` freely
- Uninstall completely with `uninstall.bat`

---

## Troubleshooting

**App doesn't detect USB**
- Ensure WMI service is running: `services.msc` → Windows Management Instrumentation
- Run with admin rights

**Files not copied**
- Check backup directory exists or is creatable
- Check file type is enabled in Settings
- Check whitelist if enabled

**"pythonw not found"**
- Ensure Python is in PATH during installation
- Try: `python -m pythonw usb_backup_app.py`
