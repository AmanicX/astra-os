#!/usr/bin/env python3
"""Parse ~/.config/niri/keybinds.kdl and emit keybinds.json for the overlay."""

import json
import os
import re
import shlex
import sys

CONFIG = os.path.expanduser(os.environ.get("KEYBINDS_CONFIG", "~/.config/niri/keybinds.kdl"))
OUT = os.path.expanduser("~/.config/quickshell/keybinds/keybinds.json")

# ---------------------------------------------------------------- pretty keys

MODS = {
    "Mod": "Super",
    "Super": "Super",
    "Win": "Super",
    "Ctrl": "Ctrl",
    "Control": "Ctrl",
    "Shift": "Shift",
    "Alt": "Alt",
    "ISO_Level3_Shift": "AltGr",
    "Mod5": "AltGr",
}

KEYS = {
    "Left": "Left",
    "Right": "Right",
    "Up": "Up",
    "Down": "Down",
    "Return": "Enter",
    "Slash": "/",
    "BracketLeft": "[",
    "BracketRight": "]",
    "Comma": ",",
    "Period": ".",
    "Minus": "-",
    "Equal": "=",
    "Page_Down": "PageDown",
    "Page_Up": "PageUp",
    "Escape": "Esc",
    "Print": "Print",
    "Space": "Space",
    "Tab": "Tab",
    "Delete": "Delete",
    "Home": "Home",
    "End": "End",
    "WheelScrollDown": "Wheel Down",
    "WheelScrollUp": "Wheel Up",
    "WheelScrollLeft": "Wheel Left",
    "WheelScrollRight": "Wheel Right",
    "TouchpadScrollDown": "Touchpad Down",
    "TouchpadScrollUp": "Touchpad Up",
    "XF86AudioRaiseVolume": "Volume Up",
    "XF86AudioLowerVolume": "Volume Down",
    "XF86AudioMute": "Mute",
    "XF86AudioMicMute": "Mic Mute",
    "XF86AudioPlay": "Play",
    "XF86AudioStop": "Stop",
    "XF86AudioPrev": "Previous",
    "XF86AudioNext": "Next",
    "XF86MonBrightnessUp": "Brightness Up",
    "XF86MonBrightnessDown": "Brightness Down",
}

MOD_ORDER = ["Mod", "Super", "Win", "Ctrl", "Control", "Shift", "Alt",
             "ISO_Level3_Shift", "Mod5"]


def pretty_key(spec):
    parts = spec.split("+")
    mods = []
    key = parts[-1]
    for p in parts[:-1]:
        if p in MODS:
            mods.append(p)

    order = {m: i for i, m in enumerate(MOD_ORDER)}
    mods = sorted(set(mods), key=lambda m: order.get(m, 99))

    labels = [MODS[m] for m in mods]
    words = [MODS[m].lower() for m in mods]

    if key in KEYS:
        kg = KEYS[key]
        kw = key.lower()
    elif len(key) == 1:
        kg = key.upper()
        kw = key.lower()
    else:
        kg = key
        kw = key.lower()

    compact = "+".join(labels + [kg])
    search = " ".join(words + [kw])
    return compact, search


# ---------------------------------------------------------------- grouping

GROUPS = [
    ("Applications", ""),
    ("Noctalia shell", ""),
    ("Windows & layout", ""),
    ("Workspaces", ""),
    ("Monitors", ""),
    ("Media & brightness", ""),
    ("Screenshots", ""),
    ("Mouse & scroll", ""),
    ("System", ""),
]

NOCTALIA = {"noctalia"}
APPS = {"kitty", "firefox", "nautilus"}


def classify(key_spec, action_name, args):
    if "WheelScroll" in key_spec or "TouchpadScroll" in key_spec:
        return "Mouse & scroll"
    if key_spec.startswith("XF86"):
        return "Media & brightness"
    if action_name in ("screenshot", "screenshot-screen", "screenshot-window"):
        return "Screenshots"
    if key_spec.startswith("Print"):
        return "Screenshots"
    if action_name in ("quit", "power-off-monitors", "toggle-keyboard-shortcuts-inhibit"):
        return "System"
    if action_name in ("spawn", "spawn-sh") and args:
        prog = os.path.basename(args[0])
        if prog in NOCTALIA:
            if len(args) > 1 and args[1] == "session":
                return "System"
            if len(args) > 2 and args[2] in ("media", "volume-up", "volume-down",
                                             "volume-mute", "mic-mute"):
                return "Media & brightness"
            return "Noctalia shell"
        if any("keybinds-toggle" in a for a in args):
            return "System"
        if prog in APPS:
            return "Applications"
        return "Applications"
    if action_name in ("focus-workspace", "focus-workspace-down", "focus-workspace-up",
                       "focus-workspace-previous", "move-column-to-workspace",
                       "move-column-to-workspace-down", "move-column-to-workspace-up",
                       "move-window-to-workspace", "move-window-to-workspace-down",
                       "move-window-to-workspace-up", "move-workspace-down",
                       "move-workspace-up"):
        return "Workspaces"
    if "monitor" in action_name:
        return "Monitors"
    return "Windows & layout"


# ---------------------------------------------------------------- parse

BIND_RE = re.compile(r"^\s*([^\s{]+)\s+(.*?)\{\s*(.*?)\s*;?\s*\}\s*$")
TITLE_RE = re.compile(r'hotkey-overlay-title="((?:[^"\\]|\\.)*)"')


def parse_binds(path):
    binds = []
    depth = 0
    in_binds = False

    with open(path, encoding="utf-8") as f:
        for raw in f:
            line = raw.split("//")[0].rstrip() if raw.lstrip().startswith("//") else raw.rstrip()

            if not in_binds:
                if re.match(r"^\s*binds\s*\{", line):
                    in_binds = True
                    depth = line.count("{") - line.count("}")
                continue

            depth += line.count("{") - line.count("}")
            if depth <= 0:
                in_binds = False
                continue

            m = BIND_RE.match(line)
            if not m:
                continue
            key_spec, props, action = m.groups()
            if key_spec.startswith("/-") or not action:
                continue

            try:
                tokens = shlex.split(action)
            except ValueError:
                tokens = action.split()
            if not tokens:
                continue

            action_name = tokens[0]
            args = tokens[1:]

            title_m = TITLE_RE.search(props)
            title = title_m.group(1) if title_m else None

            binds.append({
                "key_spec": key_spec,
                "action_name": action_name,
                "args": args,
                "title": title,
            })
    return binds


def action_label(name, args):
    if name == "spawn" and args:
        prog = os.path.basename(args[0])
        rest = " ".join(args[1:])
        return (prog + " " + rest).strip()
    if name == "spawn-sh" and args:
        return args[0]
    return " ".join([name] + args)


def title_for(b):
    if b["title"]:
        return b["title"]
    name, args = b["action_name"], b["args"]
    labels = {
        "close-window": "Close window",
        "focus-column-left": "Focus column left",
        "focus-column-right": "Focus column right",
        "focus-window-down": "Focus window down",
        "focus-window-up": "Focus window up",
        "move-column-left": "Move column left",
        "move-column-right": "Move column right",
        "move-window-down": "Move window down",
        "move-window-up": "Move window up",
        "focus-column-first": "Focus first column",
        "focus-column-last": "Focus last column",
        "move-column-to-first": "Move column to first",
        "move-column-to-last": "Move column to last",
        "focus-workspace-down": "Focus workspace down",
        "focus-workspace-up": "Focus workspace up",
        "focus-workspace-previous": "Previous workspace",
        "move-column-to-workspace-down": "Move column to workspace down",
        "move-column-to-workspace-up": "Move column to workspace up",
        "move-workspace-down": "Move workspace down",
        "move-workspace-up": "Move workspace up",
        "move-window-to-workspace": "Move window to workspace " + " ".join(args),
        "move-column-to-workspace": "Move column to workspace " + " ".join(args),
        "focus-workspace": "Focus workspace " + " ".join(args),
        "focus-monitor-left": "Focus monitor left",
        "focus-monitor-right": "Focus monitor right",
        "focus-monitor-up": "Focus monitor up",
        "focus-monitor-down": "Focus monitor down",
        "move-column-to-monitor-left": "Move column to monitor left",
        "move-column-to-monitor-right": "Move column to monitor right",
        "move-column-to-monitor-up": "Move column to monitor up",
        "move-column-to-monitor-down": "Move column to monitor down",
        "consume-or-expel-window-left": "Consume or expel window left",
        "consume-or-expel-window-right": "Consume or expel window right",
        "consume-window-into-column": "Consume window into column",
        "expel-window-from-column": "Expel window from column",
        "switch-preset-column-width": "Cycle column width",
        "switch-preset-column-width-back": "Cycle column width back",
        "switch-preset-window-height": "Cycle window height",
        "reset-window-height": "Reset window height",
        "maximize-column": "Maximize column",
        "maximize-window-to-edges": "Maximize window to edges",
        "fullscreen-window": "Fullscreen window",
        "expand-column-to-available-width": "Expand column to full width",
        "center-column": "Center column",
        "center-visible-columns": "Center visible columns",
        "set-column-width": "Column width " + " ".join(args),
        "set-window-height": "Window height " + " ".join(args),
        "toggle-window-floating": "Toggle floating",
        "switch-focus-between-floating-and-tiling": "Focus floating / tiling",
        "toggle-column-tabbed-display": "Toggle tabbed column",
        "toggle-overview": "Toggle overview",
        "toggle-keyboard-shortcuts-inhibit": "Toggle shortcuts inhibit",
        "power-off-monitors": "Power off monitors",
        "quit": "Quit niri",
        "screenshot": "Screenshot region",
        "screenshot-screen": "Screenshot screen",
        "screenshot-window": "Screenshot window",
    }
    return labels.get(name, action_label(name, args))


def exec_for(b):
    name, args = b["action_name"], b["args"]
    if name in ("spawn", "spawn-sh"):
        if any("keybinds-toggle" in a for a in args):
            return []
        if name == "spawn" and args:
            args = [os.path.expanduser(args[0])] + args[1:]
        return ["niri", "msg", "action", name] + args
    if name == "quit":
        return ["niri", "msg", "action", "quit"]
    return ["niri", "msg", "action", name] + args


def main():
    binds = parse_binds(CONFIG)
    groups = {name: [] for name, _ in GROUPS}

    for b in binds:
        compact, search = pretty_key(b["key_spec"])
        group = classify(b["key_spec"], b["action_name"], b["args"])
        groups.setdefault(group, []).append({
            "keys": compact,
            "search": search + " " + title_for(b),
            "title": title_for(b),
            "action": action_label(b["action_name"], b["args"]),
            "exec": exec_for(b),
        })

    out = {"groups": []}
    for name, icon in GROUPS:
        items = groups.get(name) or []
        if items:
            out["groups"].append({"name": name, "icon": icon, "items": items})

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    total = sum(len(g["items"]) for g in out["groups"])
    print(f"wrote {OUT}: {total} binds in {len(out['groups'])} groups")
    return 0


if __name__ == "__main__":
    sys.exit(main())
