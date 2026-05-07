"""
USB AutoBackup - Windows Background Application
Automatically backs up files from USB devices when connected.
"""

import sys
import os
import json
import hashlib
import shutil
import logging
import threading
import time
import string
from pathlib import Path
from datetime import datetime

# Windows-specific imports
import win32api
import win32con
import win32gui
import pywintypes
import wmi
import pythoncom
import ctypes

# GUI
import tkinter as tk
from tkinter import ttk, filedialog, messagebox
import pystray
from PIL import Image, ImageDraw, ImageEnhance

# ─────────────────────────────────────────────
# CONFIG & PATHS
# ─────────────────────────────────────────────
APP_NAME = "USB AutoBackup"
APP_DIR = Path(os.getenv("APPDATA")) / "USBAutoBackup"
CONFIG_FILE = APP_DIR / "config.json"
LOG_FILE = APP_DIR / "backup.log"

APP_DIR.mkdir(parents=True, exist_ok=True)

DEFAULT_CONFIG = {
    "enabled": True,
    "backup_dir": r"D:\USB_Backups",
    "file_types": {
        "documents": [".pdf", ".docx", ".txt"],
        "images": [".jpg", ".jpeg", ".png"],
        "videos": []
    },
    "include_documents": True,
    "include_images": True,
    "include_videos": False,
    "whitelist": [],
    "whitelist_enabled": False
}

# ─────────────────────────────────────────────
# LOGGING
# ─────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE, encoding="utf-8"),
        logging.StreamHandler(sys.stdout)
    ]
)
log = logging.getLogger(APP_NAME)

# ─────────────────────────────────────────────
# CONFIG MANAGER
# ─────────────────────────────────────────────
class Config:
    def __init__(self):
        self._data = DEFAULT_CONFIG.copy()
        self.load()

    def load(self):
        if CONFIG_FILE.exists():
            try:
                with open(CONFIG_FILE, "r") as f:
                    saved = json.load(f)
                self._data.update(saved)
            except Exception as e:
                log.warning(f"Failed to load config: {e}")

    def save(self):
        try:
            with open(CONFIG_FILE, "w") as f:
                json.dump(self._data, f, indent=2)
        except Exception as e:
            log.error(f"Failed to save config: {e}")

    def __getitem__(self, key):
        return self._data[key]

    def __setitem__(self, key, value):
        self._data[key] = value
        self.save()

    def get(self, key, default=None):
        return self._data.get(key, default)

    def get_extensions(self):
        exts = []
        ft = self._data["file_types"]
        if self._data.get("include_documents", True):
            exts.extend(ft.get("documents", []))
        if self._data.get("include_images", True):
            exts.extend(ft.get("images", []))
        if self._data.get("include_videos"):
            exts.extend(ft.get("videos", [".mp4"]))
        return [e.lower() for e in exts]


config = Config()

# ─────────────────────────────────────────────
# FILE BACKUP ENGINE
# ─────────────────────────────────────────────
def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    try:
        with open(path, "rb") as f:
            for chunk in iter(lambda: f.read(65536), b""):
                h.update(chunk)
        return h.hexdigest()
    except Exception:
        return ""

def backup_usb(drive_letter: str, drive_label: str):
    if not config["enabled"]:
        log.info(f"Backup disabled — skipping {drive_letter}")
        return

    # Whitelist check
    if config["whitelist_enabled"] and drive_label:
        if drive_label not in config["whitelist"]:
            log.info(f"Device '{drive_label}' not in whitelist — skipping.")
            return

    backup_root = Path(config["backup_dir"])
    safe_label = "".join(c for c in (drive_label or drive_letter) if c.isalnum() or c in (" ", "_", "-")).strip() or drive_letter.rstrip(":\\")
    dest_base = backup_root / safe_label
    dest_base.mkdir(parents=True, exist_ok=True)

    extensions = config.get_extensions()
    src_root = Path(drive_letter)

    log.info(f"━━ Backup started: {drive_letter} ({drive_label}) → {dest_base}")
    copied = 0
    skipped = 0
    errors = 0

    try:
        for src_file in src_root.rglob("*"):
            if not src_file.is_file():
                continue
            if src_file.suffix.lower() not in extensions:
                continue

            # Preserve folder structure
            rel_path = src_file.relative_to(src_root)
            dest_file = dest_base / rel_path

            try:
                dest_file.parent.mkdir(parents=True, exist_ok=True)

                # Incremental: skip if same hash
                if dest_file.exists():
                    if sha256_file(src_file) == sha256_file(dest_file):
                        skipped += 1
                        continue

                shutil.copy2(src_file, dest_file)
                log.info(f"  COPIED  {rel_path}")
                copied += 1

            except Exception as e:
                log.error(f"  ERROR   {rel_path}: {e}")
                errors += 1

    except Exception as e:
        log.error(f"Backup scan failed: {e}")

    log.info(f"━━ Backup complete: {copied} copied, {skipped} skipped, {errors} errors")

# ─────────────────────────────────────────────
# USB MONITOR (WMI)
# ─────────────────────────────────────────────
class USBMonitor(threading.Thread):
    def __init__(self):
        super().__init__(daemon=True, name="USBMonitor")
        self._stop_event = threading.Event()

    def stop(self):
        self._stop_event.set()

    def run(self):
        pythoncom.CoInitialize()
        try:
            c = wmi.WMI()
            watcher = c.Win32_VolumeChangeEvent.watch_for(EventType=2)  # 2 = insertion
            log.info("USB monitor started — watching for devices...")
            while not self._stop_event.is_set():
                try:
                    event = watcher(timeout_ms=2000)
                    if event:
                        drive_letter = getattr(event, "DriveName", "")
                        if drive_letter:
                            self._on_usb_inserted(drive_letter)
                except wmi.x_wmi_timed_out:
                    continue
                except Exception as e:
                    log.warning(f"WMI event error: {e}")
                    time.sleep(3)
        finally:
            pythoncom.CoUninitialize()

    def _on_usb_inserted(self, drive_letter: str):
        time.sleep(2)  # Let Windows mount fully
        try:
            # Normalise to "X:\" format
            dl = drive_letter.rstrip("\\/") + "\\"

            # Use ctypes kernel32 directly — avoids pywin32 version issues
            kernel32 = ctypes.windll.kernel32

            drive_type = kernel32.GetDriveTypeW(dl)
            # DRIVE_REMOVABLE = 2
            if drive_type != 2:
                log.info(f"Ignoring non-removable drive: {dl} (type={drive_type})")
                return

            # Get volume label via ctypes
            label_buf = ctypes.create_unicode_buffer(261)
            kernel32.GetVolumeInformationW(
                dl,
                label_buf, 261,
                None, None, None,
                None, 0
            )
            label = label_buf.value or ""

            log.info(f"USB detected: {dl}  label='{label}'")
            t = threading.Thread(
                target=backup_usb,
                args=(dl, label),
                daemon=True,
                name=f"Backup-{drive_letter}"
            )
            t.start()
        except Exception as e:
            log.error(f"USB insert handler error: {e}")


# ─────────────────────────────────────────────
# SETTINGS WINDOW
# ─────────────────────────────────────────────
class SettingsWindow(tk.Toplevel):
    def __init__(self, master):
        super().__init__(master)
        self.title(f"{APP_NAME} — Settings")
        self.geometry("540x600")
        self.resizable(False, False)
        self.configure(bg="#0f0f13")
        self._build_ui()
        self.lift()
        self.focus_force()

    def _build_ui(self):
        BG = "#0f0f13"
        CARD = "#1a1a24"
        ACC = "#00d4aa"
        TXT = "#e8e8f0"
        SUB = "#888899"
        FONT = ("Consolas", 10)
        FONT_H = ("Consolas", 12, "bold")

        self.configure(bg=BG)

        # Header
        hdr = tk.Frame(self, bg="#161620", pady=16)
        hdr.pack(fill="x")
        tk.Label(hdr, text="⚙  SETTINGS", font=("Consolas", 15, "bold"),
                 bg="#161620", fg=ACC).pack()
        tk.Label(hdr, text="USB AutoBackup Configuration", font=FONT,
                 bg="#161620", fg=SUB).pack()

        scroll_frame = tk.Frame(self, bg=BG)
        scroll_frame.pack(fill="both", expand=True, padx=20, pady=10)

        def section(parent, title):
            f = tk.LabelFrame(parent, text=f"  {title}  ", font=FONT_H,
                              bg=CARD, fg=ACC, bd=1, relief="flat",
                              labelanchor="nw", pady=8, padx=10)
            f.pack(fill="x", pady=(0, 12))
            return f

        # ── Enable backup
        sec1 = section(scroll_frame, "BACKUP CONTROL")
        self._enabled_var = tk.BooleanVar(value=config["enabled"])
        tk.Checkbutton(sec1, text="Enable automatic backup on USB insertion",
                       variable=self._enabled_var, bg=CARD, fg=TXT,
                       selectcolor="#2a2a38", activebackground=CARD,
                       font=FONT).pack(anchor="w")

        # ── Backup directory
        sec2 = section(scroll_frame, "BACKUP DIRECTORY")
        dir_row = tk.Frame(sec2, bg=CARD)
        dir_row.pack(fill="x")
        self._dir_var = tk.StringVar(value=config["backup_dir"])
        dir_entry = tk.Entry(dir_row, textvariable=self._dir_var, bg="#252533",
                             fg=TXT, font=FONT, bd=0, insertbackground=ACC,
                             relief="flat")
        dir_entry.pack(side="left", fill="x", expand=True, ipady=6, padx=(0, 6))
        tk.Button(dir_row, text="Browse", command=self._browse_dir,
                  bg="#252533", fg=ACC, font=FONT, bd=0, cursor="hand2",
                  activebackground="#2f2f40", activeforeground=ACC,
                  relief="flat", padx=10).pack(side="right")

        # ── File types
        sec3 = section(scroll_frame, "FILE TYPES")
        self._docs_var = tk.BooleanVar(value=config.get("include_documents", True))
        self._imgs_var = tk.BooleanVar(value=config.get("include_images", True))
        self._vids_var = tk.BooleanVar(value=config.get("include_videos", False))
        for var, label, detail in [
            (self._docs_var, "Documents", ".pdf  .docx  .txt"),
            (self._imgs_var, "Images", ".jpg  .jpeg  .png"),
            (self._vids_var, "Videos (large files)", ".mp4"),
        ]:
            row = tk.Frame(sec3, bg=CARD)
            row.pack(fill="x", pady=2)
            tk.Checkbutton(row, text=label, variable=var, bg=CARD, fg=TXT,
                           selectcolor="#2a2a38", activebackground=CARD,
                           font=FONT, width=14, anchor="w").pack(side="left")
            tk.Label(row, text=detail, bg=CARD, fg=SUB, font=FONT).pack(side="left")

        # ── Whitelist
        sec4 = section(scroll_frame, "DEVICE WHITELIST")
        self._wl_enabled = tk.BooleanVar(value=config.get("whitelist_enabled", False))
        tk.Checkbutton(sec4, text="Only backup whitelisted devices",
                       variable=self._wl_enabled, bg=CARD, fg=TXT,
                       selectcolor="#2a2a38", activebackground=CARD,
                       font=FONT).pack(anchor="w", pady=(0, 6))

        wl_frame = tk.Frame(sec4, bg=CARD)
        wl_frame.pack(fill="x")
        self._wl_listbox = tk.Listbox(wl_frame, bg="#252533", fg=TXT, font=FONT,
                                       height=4, bd=0, selectbackground="#00d4aa22",
                                       selectforeground=ACC, relief="flat")
        self._wl_listbox.pack(side="left", fill="x", expand=True)
        for item in config.get("whitelist", []):
            self._wl_listbox.insert("end", item)

        wl_btns = tk.Frame(wl_frame, bg=CARD)
        wl_btns.pack(side="right", padx=(6, 0))
        self._wl_entry = tk.Entry(sec4, bg="#252533", fg=TXT, font=FONT, bd=0,
                                   insertbackground=ACC, relief="flat")
        self._wl_entry.pack(fill="x", pady=(4, 0), ipady=5)
        tk.Label(sec4, text="Enter device label (e.g. 'MyUSB') and click Add",
                 bg=CARD, fg=SUB, font=("Consolas", 8)).pack(anchor="w")

        btn_row = tk.Frame(sec4, bg=CARD)
        btn_row.pack(fill="x", pady=(4, 0))
        tk.Button(btn_row, text="+ Add", command=self._wl_add, bg="#00d4aa22",
                  fg=ACC, font=FONT, bd=0, cursor="hand2", relief="flat",
                  activebackground="#00d4aa44", padx=8).pack(side="left", padx=(0, 6))
        tk.Button(btn_row, text="✕ Remove", command=self._wl_remove, bg="#ff444422",
                  fg="#ff6666", font=FONT, bd=0, cursor="hand2", relief="flat",
                  activebackground="#ff444444", padx=8).pack(side="left")

        # ── Save button
        tk.Button(self, text="SAVE SETTINGS", command=self._save,
                  bg=ACC, fg="#0f0f13", font=("Consolas", 11, "bold"),
                  bd=0, cursor="hand2", activebackground="#00b894",
                  activeforeground="#0f0f13", pady=10, relief="flat"
                  ).pack(fill="x", padx=20, pady=(0, 20))

    def _browse_dir(self):
        d = filedialog.askdirectory(title="Select backup folder")
        if d:
            self._dir_var.set(d.replace("/", "\\"))

    def _wl_add(self):
        val = self._wl_entry.get().strip()
        if val:
            self._wl_listbox.insert("end", val)
            self._wl_entry.delete(0, "end")

    def _wl_remove(self):
        sel = self._wl_listbox.curselection()
        if sel:
            self._wl_listbox.delete(sel[0])

    def _save(self):
        config["enabled"] = self._enabled_var.get()
        config["backup_dir"] = self._dir_var.get()
        config["include_documents"] = self._docs_var.get()
        config["include_images"] = self._imgs_var.get()
        config["include_videos"] = self._vids_var.get()
        config["whitelist_enabled"] = self._wl_enabled.get()
        config["whitelist"] = list(self._wl_listbox.get(0, "end"))
        config.save()
        messagebox.showinfo("Saved", "Settings saved successfully!", parent=self)
        log.info("Settings updated by user.")
        self.destroy()


# ─────────────────────────────────────────────
# LOG VIEWER
# ─────────────────────────────────────────────
class LogWindow(tk.Toplevel):
    def __init__(self, master):
        super().__init__(master)
        self.title(f"{APP_NAME} — Backup Log")
        self.geometry("700x500")
        self.configure(bg="#0f0f13")
        self._build_ui()
        self.lift()
        self.focus_force()

    def _build_ui(self):
        BG = "#0f0f13"
        ACC = "#00d4aa"
        SUB = "#888899"

        hdr = tk.Frame(self, bg="#161620", pady=14)
        hdr.pack(fill="x")
        tk.Label(hdr, text="📋  BACKUP LOG", font=("Consolas", 13, "bold"),
                 bg="#161620", fg=ACC).pack()
        tk.Label(hdr, text=str(LOG_FILE), font=("Consolas", 8),
                 bg="#161620", fg=SUB).pack()

        txt_frame = tk.Frame(self, bg=BG)
        txt_frame.pack(fill="both", expand=True, padx=10, pady=10)
        scrollbar = tk.Scrollbar(txt_frame)
        scrollbar.pack(side="right", fill="y")
        self._txt = tk.Text(txt_frame, bg="#0a0a10", fg="#c8c8d8",
                            font=("Consolas", 9), bd=0, relief="flat",
                            yscrollcommand=scrollbar.set, wrap="none")
        self._txt.pack(fill="both", expand=True)
        scrollbar.config(command=self._txt.yview)

        self._txt.tag_configure("copy", foreground="#00d4aa")
        self._txt.tag_configure("error", foreground="#ff6666")
        self._txt.tag_configure("info", foreground="#888899")

        self._load_log()

        btn_row = tk.Frame(self, bg=BG)
        btn_row.pack(fill="x", padx=10, pady=(0, 10))
        tk.Button(btn_row, text="↻ Refresh", command=self._load_log,
                  bg="#252533", fg=ACC, font=("Consolas", 9), bd=0,
                  cursor="hand2", relief="flat", padx=10, pady=4).pack(side="left")
        tk.Button(btn_row, text="🗑 Clear Log", command=self._clear_log,
                  bg="#252533", fg="#ff6666", font=("Consolas", 9), bd=0,
                  cursor="hand2", relief="flat", padx=10, pady=4).pack(side="left", padx=6)

    def _load_log(self):
        self._txt.delete("1.0", "end")
        try:
            with open(LOG_FILE, "r", encoding="utf-8") as f:
                lines = f.readlines()
            for line in lines[-500:]:
                tag = "info"
                if "COPIED" in line:
                    tag = "copy"
                elif "ERROR" in line:
                    tag = "error"
                self._txt.insert("end", line, tag)
            self._txt.see("end")
        except Exception:
            self._txt.insert("end", "No log entries yet.\n", "info")

    def _clear_log(self):
        if messagebox.askyesno("Clear Log", "Clear all log entries?", parent=self):
            open(LOG_FILE, "w").close()
            self._load_log()


# ─────────────────────────────────────────────
# TRAY APPLICATION
# ─────────────────────────────────────────────
class TrayApp:
    def __init__(self):
        self._root = tk.Tk()
        self._root.withdraw()  # Hidden root window
        self._monitor = USBMonitor()
        self._monitor.start()
        self._icon = None
        self._build_tray()

    def _make_icon_image(self, enabled=True):
        p = Path(__file__).parent / "icons8-windows-10-48.ico"
        if p.exists():
            try:
                img = Image.open(p).convert("RGBA").resize((64, 64), Image.LANCZOS)
                if not enabled:
                    img = ImageEnhance.Color(img).enhance(0)
                    img = ImageEnhance.Brightness(img).enhance(0.55)
                return img
            except Exception:
                pass
        # Fallback drawn icon
        img = Image.new("RGBA", (64, 64), (0,0,0,0))
        d = ImageDraw.Draw(img)
        color = (41, 128, 235) if enabled else (80, 90, 110)
        d.rounded_rectangle([2,2,62,62], radius=14, fill=color)
        d.rounded_rectangle([18,20,46,36], radius=5, fill=(255,255,255,255))
        d.rectangle([22,12,30,22], fill=(255,255,255,255))
        d.rectangle([34,12,42,22], fill=(255,255,255,255))
        d.rectangle([29,36,35,50], fill=(255,255,255,255))
        return img

    def _build_tray(self):
        def on_toggle(icon, item):
            config["enabled"] = not config["enabled"]
            icon.icon = self._make_icon_image(config["enabled"])
            status = "enabled" if config["enabled"] else "disabled"
            log.info(f"Backup {status} by user.")

        def on_logs(icon, item):
            self._root.after(0, self._open_logs)

        def on_settings(icon, item):
            self._root.after(0, self._open_settings)

        def on_exit(icon, item):
            log.info("USB AutoBackup shutting down.")
            self._monitor.stop()
            icon.stop()
            self._root.quit()

        menu = pystray.Menu(
            pystray.MenuItem(
                lambda item: f"{'✓' if config['enabled'] else '✗'}  Auto Backup {'ON' if config['enabled'] else 'OFF'}",
                on_toggle
            ),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("📋  View Logs", on_logs),
            pystray.MenuItem("⚙  Settings", on_settings),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("✕  Exit", on_exit),
        )

        self._icon = pystray.Icon(
            name=APP_NAME,
            icon=self._make_icon_image(config["enabled"]),
            title=APP_NAME,
            menu=menu
        )

    def _open_settings(self):
        SettingsWindow(self._root)

    def _open_logs(self):
        LogWindow(self._root)

    def run(self):
        log.info(f"{APP_NAME} started. Backup dir: {config['backup_dir']}")
        # Run tray in separate thread, tk mainloop in main
        tray_thread = threading.Thread(target=self._icon.run, daemon=True)
        tray_thread.start()
        self._root.mainloop()


# ─────────────────────────────────────────────
# ENTRY POINT
# ─────────────────────────────────────────────
if __name__ == "__main__":
    app = TrayApp()
    app.run()
