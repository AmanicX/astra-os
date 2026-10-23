"""
AstraOS Installer Screens Registry.
Exports all 17 screens in strict sequential order.
"""

from astra_installer.screens.welcome import WelcomeScreenWidget
from astra_installer.screens.keyboard import KeyboardScreenWidget
from astra_installer.screens.locale import LocaleScreenWidget
from astra_installer.screens.timezone import TimezoneScreenWidget
from astra_installer.screens.mirrors import MirrorsScreenWidget
from astra_installer.screens.multilib import MultilibScreenWidget
from astra_installer.screens.swap import SwapScreenWidget
from astra_installer.screens.hostname import HostnameScreenWidget
from astra_installer.screens.root_pw import RootPasswordScreenWidget
from astra_installer.screens.user import UserAccountScreenWidget
from astra_installer.screens.sudo import SudoScreenWidget
from astra_installer.screens.storage import StorageScreenWidget
from astra_installer.screens.bootloader import BootloaderScreenWidget
from astra_installer.screens.packages import PackagesScreenWidget
from astra_installer.screens.summary import SummaryScreenWidget
from astra_installer.screens.progress import ProgressScreenWidget
from astra_installer.screens.finished import FinishedScreenWidget

SCREEN_NAMES = [
    "Welcome",
    "Keyboard",
    "Locale",
    "Timezone",
    "Mirror Region",
    "Multilib",
    "Swap Space",
    "Hostname",
    "Root Password",
    "User Account",
    "Sudo Access",
    "Partitioning",
    "Bootloader",
    "Extra Packages",
    "Summary",
    "Installation",
    "Finish"
]
