"""
AstraOS Installer Design System & Textual Theme Tokens.
Astral Meridian Aesthetic: Deep Void (#05070d), Midnight (#0b1220), Cyan (#5ee6f2), Starlight (#e8edf7).
Impeccable, Emil Kowalski, and Taste skill integration.
"""

from typing import Final

# Core Semantic Palette
COLOR_BG: Final[str] = "#05070d"
COLOR_CARD: Final[str] = "#0b1220"
COLOR_INPUT: Final[str] = "#0e1726"
COLOR_BORDER: Final[str] = "#1e3a5f"
COLOR_BORDER_FOCUS: Final[str] = "#5ee6f2"

COLOR_TEXT: Final[str] = "#e8edf7"
COLOR_MUTED: Final[str] = "#8e9ea9"
COLOR_DIM: Final[str] = "#475569"
COLOR_CYAN: Final[str] = "#5ee6f2"
COLOR_AMBER: Final[str] = "#e6a45a"
COLOR_RED: Final[str] = "#f26b6b"
COLOR_GREEN: Final[str] = "#38bdf8"

# ASCII Star mark & Wordmark
ASTRA_STAR_SMALL: Final[str] = """
   ✦
 ──┼──
   │
"""

ASTRA_STAR_LARGE: Final[str] = """
          .
         / \\
       -  ✦  -
         \\ /
          '
"""

ASTRA_BANNER: Final[str] = "[bold #e8edf7]Astra[/][bold #5ee6f2]OS[/]"

# Textual Application Stylesheet (CSS)
APP_CSS: Final[str] = """
Screen {
    background: #05070d;
    color: #e8edf7;
    layout: vertical;
    padding: 0;
    margin: 0;
}

#app-container {
    width: 100%;
    height: 100%;
    background: #0b1220;
    border: none;
    padding: 0;
    margin: 0;
    layout: vertical;
}

#app-header {
    height: 3;
    dock: top;
    background: #080d17;
    border-bottom: solid #1e3a5f;
    layout: horizontal;
    align: center middle;
    padding: 0 2;
}

#header-logo {
    width: auto;
    color: #5ee6f2;
    text-style: bold;
}

#header-title {
    width: 1fr;
    text-align: left;
    margin-left: 1;
    color: #8e9ea9;
}

#header-step {
    width: auto;
    color: #5ee6f2;
    text-style: bold;
    background: #111d2e;
    padding: 0 1;
}

#content-box {
    height: 1fr;
    layout: horizontal;
    padding: 0;
    margin: 0;
}

#rail-container {
    width: 28;
    height: 100%;
    border-right: solid #1e3a5f;
    background: #080d17;
    padding: 1 1;
}

#rail-scroll {
    height: 100%;
    overflow-y: auto;
}

.rail-item {
    padding: 0 1;
    color: #475569;
    height: 1;
}

.rail-item-completed {
    color: #38bdf8;
}

.rail-item-current {
    color: #5ee6f2;
    text-style: bold;
    background: #0f2338;
    border-left: wide #5ee6f2;
}

.rail-item-upcoming {
    color: #475569;
}

#main-pane {
    width: 1fr;
    height: 100%;
    padding: 1 3;
    overflow-y: auto;
}

.screen-title {
    color: #5ee6f2;
    text-style: bold;
    margin-bottom: 0;
}

.screen-desc {
    color: #8e9ea9;
    margin-bottom: 1;
}

.explain-panel {
    background: #0e1726;
    border-left: double #5ee6f2;
    padding: 0 1;
    margin: 1 0;
    color: #e8edf7;
}

.warn-panel {
    background: #231b14;
    border-left: double #e6a45a;
    padding: 0 1;
    margin: 1 0;
    color: #e6a45a;
}

.danger-panel {
    background: #271418;
    border-left: double #f26b6b;
    padding: 0 1;
    margin: 1 0;
    color: #f26b6b;
}

#nav-buttons-bar {
    dock: bottom;
    height: 3;
    background: #080d17;
    border-top: solid #1e3a5f;
    layout: horizontal;
    align: center middle;
    padding: 0 2;
}

#nav-spacer {
    width: 1fr;
    height: 1;
}

.spacer {
    width: 1fr;
}

#btn-back {
    background: #1e293b;
    color: #cbd5e1;
    border: none;
    min-width: 16;
    height: 1;
}

#btn-back:hover, #btn-back:focus {
    background: #334155;
    color: #ffffff;
}

#btn-next {
    background: #5ee6f2;
    color: #05070d;
    text-style: bold;
    border: none;
    min-width: 18;
    height: 1;
}

#btn-next:hover, #btn-next:focus {
    background: #7ff0fa;
}

#btn-next:disabled {
    background: #1e293b;
    color: #475569;
}

.btn-primary {
    background: #5ee6f2;
    color: #05070d;
    text-style: bold;
    border: none;
    min-width: 14;
}

.btn-primary:focus, .btn-primary:hover {
    background: #7ff0fa;
}

.btn-secondary {
    background: #1e293b;
    color: #e8edf7;
    border: none;
    min-width: 12;
}

.btn-secondary:focus, .btn-secondary:hover {
    background: #334155;
}

.btn-danger {
    background: #f26b6b;
    color: #ffffff;
    text-style: bold;
    border: none;
}

#footer-hints {
    dock: bottom;
    height: 1;
    background: #05070d;
    border-top: solid #111d2e;
    color: #64748b;
    text-align: center;
}

Input {
    background: #0e1726;
    border: tall #1e3a5f;
    color: #e8edf7;
    margin-bottom: 1;
}

Input:focus {
    border: tall #5ee6f2;
}

OptionList {
    background: #0e1726;
    border: tall #1e3a5f;
    color: #e8edf7;
    height: 1fr;
    min-height: 8;
    max-height: 22;
}

OptionList:focus {
    border: tall #5ee6f2;
}

OptionList > .option-list--option-highlighted {
    background: #1f3647;
    color: #5ee6f2;
    text-style: bold;
}

RadioSet {
    background: transparent;
    border: none;
    margin-bottom: 1;
}

RadioButton {
    color: #e8edf7;
}

RadioButton:focus {
    color: #5ee6f2;
}

ProgressBar {
    width: 100%;
    color: #5ee6f2;
}

#log-pane {
    height: 1fr;
    min-height: 8;
    background: #05070d;
    border: solid #1e3a5f;
    color: #9cb1c2;
    padding: 0 1;
    overflow-y: scroll;
}
"""
