"""
AstraOS Installer Design System & Textual Theme Tokens.
Noctalia palette: bg #0b0e14, fg #bfbdb6, cyan #53bdfa, amber #e6b450.
Transparent Screen so Kitty's background_opacity 0.88 + Niri blur shine through,
exactly like LazyVim running inside Kitty.
"""

from typing import Final

# Noctalia colour tokens (matches kitty/themes/noctalia.conf)
COLOR_BG: Final[str] = "#0b0e14"        # kitty background
COLOR_CARD: Final[str] = "#12171f"      # slightly lighter surface
COLOR_INPUT: Final[str] = "#161c26"     # input fields
COLOR_BORDER: Final[str] = "#1e222a"    # noctalia inactive_border_color
COLOR_BORDER_FOCUS: Final[str] = "#53bdfa"  # noctalia color4 (cyan)

COLOR_TEXT: Final[str] = "#bfbdb6"      # noctalia foreground
COLOR_MUTED: Final[str] = "#8e959e"     # noctalia inactive tab fg
COLOR_DIM: Final[str] = "#475569"
COLOR_CYAN: Final[str] = "#53bdfa"      # noctalia color4
COLOR_AMBER: Final[str] = "#e6b450"     # noctalia cursor / active border
COLOR_RED: Final[str] = "#ea6c73"       # noctalia color1
COLOR_GREEN: Final[str] = "#7fd962"     # noctalia color2

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

ASTRA_BANNER: Final[str] = "[bold #bfbdb6]Astra[/][bold #53bdfa]OS[/]"

# Textual Application Stylesheet (CSS)
# Screen and #app-container are transparent so Kitty's background_opacity 0.88
# and Niri's blur compositor effect show through — matching how LazyVim looks
# inside Kitty (no opaque box-in-a-box; the terminal glass is the background).
APP_CSS: Final[str] = """
Screen {
    background: transparent;
    color: #bfbdb6;
    layout: vertical;
    padding: 0;
    margin: 0;
}

#app-container {
    width: 100%;
    height: 100%;
    background: transparent;
    border: none;
    padding: 0;
    margin: 0;
    layout: vertical;
}

#app-header {
    height: 3;
    dock: top;
    background: rgba(11,14,20,0.75);
    border-bottom: solid #1e222a;
    layout: horizontal;
    align: center middle;
    padding: 0 2;
}

#header-logo {
    width: auto;
    color: #53bdfa;
    text-style: bold;
}

#header-title {
    width: 1fr;
    text-align: left;
    margin-left: 1;
    color: #8e959e;
}

#header-step {
    width: auto;
    color: #53bdfa;
    text-style: bold;
    background: rgba(11,14,20,0.6);
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
    border-right: solid #1e222a;
    background: rgba(11,14,20,0.6);
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
    color: #7fd962;
}

.rail-item-current {
    color: #53bdfa;
    text-style: bold;
    background: rgba(83,189,250,0.12);
    border-left: wide #53bdfa;
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
    color: #53bdfa;
    text-style: bold;
    margin-bottom: 0;
}

.screen-desc {
    color: #8e959e;
    margin-bottom: 1;
}

.explain-panel {
    background: rgba(22,28,38,0.7);
    border-left: double #53bdfa;
    padding: 0 1;
    margin: 1 0;
    color: #bfbdb6;
}

.warn-panel {
    background: rgba(35,27,20,0.7);
    border-left: double #e6b450;
    padding: 0 1;
    margin: 1 0;
    color: #e6b450;
}

.danger-panel {
    background: rgba(39,20,24,0.7);
    border-left: double #ea6c73;
    padding: 0 1;
    margin: 1 0;
    color: #ea6c73;
}

#nav-buttons-bar {
    dock: bottom;
    height: 3;
    background: rgba(11,14,20,0.75);
    border-top: solid #1e222a;
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
    color: #bfbdb6;
    border: none;
    min-width: 16;
    height: 1;
}

#btn-back:hover, #btn-back:focus {
    background: #334155;
    color: #ffffff;
}

#btn-next {
    background: #53bdfa;
    color: #0b0e14;
    text-style: bold;
    border: none;
    min-width: 18;
    height: 1;
}

#btn-next:hover, #btn-next:focus {
    background: #7bd3ff;
}

#btn-next:disabled {
    background: #1e222a;
    color: #475569;
}

.btn-primary {
    background: #53bdfa;
    color: #0b0e14;
    text-style: bold;
    border: none;
    min-width: 14;
}

.btn-primary:focus, .btn-primary:hover {
    background: #7bd3ff;
}

.btn-secondary {
    background: #1e293b;
    color: #bfbdb6;
    border: none;
    min-width: 12;
}

.btn-secondary:focus, .btn-secondary:hover {
    background: #334155;
}

.btn-danger {
    background: #ea6c73;
    color: #ffffff;
    text-style: bold;
    border: none;
}

#footer-hints {
    dock: bottom;
    height: 1;
    background: transparent;
    border-top: solid #1e222a;
    color: #8e959e;
    text-align: center;
}

Input {
    background: rgba(18,23,31,0.8);
    border: tall #1e222a;
    color: #bfbdb6;
    margin-bottom: 1;
}

Input:focus {
    border: tall #53bdfa;
}

OptionList {
    background: rgba(18,23,31,0.8);
    border: tall #1e222a;
    color: #bfbdb6;
    height: 1fr;
    min-height: 8;
    max-height: 22;
}

OptionList:focus {
    border: tall #53bdfa;
}

OptionList > .option-list--option-highlighted {
    background: rgba(83,189,250,0.2);
    color: #53bdfa;
    text-style: bold;
}

RadioSet {
    background: transparent;
    border: none;
    margin-bottom: 1;
}

RadioButton {
    color: #bfbdb6;
}

RadioButton:focus {
    color: #53bdfa;
}

ProgressBar {
    width: 100%;
    color: #53bdfa;
}

#log-pane {
    height: 1fr;
    min-height: 8;
    background: transparent;
    border: solid #1e222a;
    color: #bfbdb6;
    padding: 0 1;
    overflow-y: scroll;
}
"""
