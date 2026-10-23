"""
AstraOS Installer Design System & Textual Theme Tokens.
Mixed-case AstraOS brand identity.
"""

from typing import Final

# Core Semantic Palette
COLOR_BG: Final[str] = "#0c1017"
COLOR_CARD: Final[str] = "#131a24"
COLOR_INPUT: Final[str] = "#182230"
COLOR_BORDER: Final[str] = "#3b4c58"
COLOR_BORDER_FOCUS: Final[str] = "#5ee6f2"

COLOR_TEXT: Final[str] = "#e8edf7"
COLOR_MUTED: Final[str] = "#8e9ea9"
COLOR_CYAN: Final[str] = "#5ee6f2"
COLOR_AMBER: Final[str] = "#e6a45a"
COLOR_RED: Final[str] = "#f26b6b"
COLOR_GREEN: Final[str] = "#6be6a8"

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
    background: #0c1017;
    color: #e8edf7;
    layout: vertical;
    align: center middle;
}

#app-container {
    width: 98%;
    max-width: 120;
    height: 96%;
    max-height: 42;
    background: #131a24;
    border: round #3b4c58;
    padding: 0 1;
}

#app-header {
    height: 3;
    dock: top;
    border-bottom: heavy #3b4c58;
    layout: horizontal;
    align: center middle;
    padding: 0 1;
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
    color: #e8edf7;
}

#header-step {
    width: auto;
    color: #8e9ea9;
    text-align: right;
}

#content-box {
    height: 1fr;
    layout: horizontal;
    padding: 1 0;
}

#rail-container {
    width: 24;
    height: 100%;
    border-right: solid #3b4c58;
    padding-right: 1;
    display: block;
}

#rail-scroll {
    height: 100%;
    overflow-y: auto;
}

.rail-item {
    padding: 0 1;
    color: #8e9ea9;
}

.rail-item-completed {
    color: #6be6a8;
}

.rail-item-current {
    color: #5ee6f2;
    text-style: bold;
    background: #1e2938;
}

.rail-item-upcoming {
    color: #4f6170;
}

#main-pane {
    width: 1fr;
    height: 100%;
    padding: 0 2;
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
    background: #16202c;
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

#footer-hints {
    height: 1;
    dock: bottom;
    border-top: solid #3b4c58;
    color: #8e9ea9;
    text-align: center;
}

.btn-primary {
    background: #5ee6f2;
    color: #0c1017;
    text-style: bold;
    border: none;
    min-width: 14;
}

.btn-primary:focus {
    background: #7ff0fa;
}

.btn-secondary {
    background: #253342;
    color: #e8edf7;
    border: none;
    min-width: 12;
}

.btn-secondary:focus {
    background: #334458;
}

.btn-danger {
    background: #f26b6b;
    color: #ffffff;
    text-style: bold;
    border: none;
}

Input {
    background: #182230;
    border: tall #3b4c58;
    color: #e8edf7;
    margin-bottom: 1;
}

Input:focus {
    border: tall #5ee6f2;
}

OptionList {
    background: #182230;
    border: tall #3b4c58;
    color: #e8edf7;
    height: auto;
    max-height: 14;
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
    height: 12;
    background: #090c10;
    border: solid #3b4c58;
    color: #9cb1c2;
    padding: 0 1;
    overflow-y: scroll;
}
"""
