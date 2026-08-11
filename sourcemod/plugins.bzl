"""The SourcePawn plugins bundled with SourceMod.

Shared between the @sourcemod_sdk build overlay (which declares one
`sourcemod_plugin` target per entry) and `sourcemod_server()` (which packages
them), so the two cannot drift out of sync.

The split mirrors the `disabled_plugins` set in upstream's
tools/buildbot/PackageScript, with one deliberate difference noted below.
"""

# Shipped in plugins/disabled/ and left there. These need configuration that a
# server operator has to supply (a database connection, in the SQL cases)
# before they do anything useful.
DISABLED_PLUGINS = [
    "admin-sql-prefetch",
    "admin-sql-threaded",
    "sql-admin-manager",
    "randomcycle",
    # Upstream ships this one enabled, but it is a front end for the clientprefs
    # extension, and that extension is not among the ones built here (it needs
    # the DBI/SQLite stack). Left enabled it fails on every map load with
    # `Required extension "Client Preferences" ... not running`. Nothing else in
    # the tree includes <clientprefs>, so disabling it costs nothing until the
    # extension is built.
    "clientprefs",
]

# Upstream also ships these three disabled, but they are promoted into the
# active plugins directory here.
#
# They cannot simply be loaded from disabled/: SourceMod resolves a plugin's
# declared dependencies by file name, so a plugin that `#include`s <mapchooser>
# only finds it if it sits in plugins/ as "mapchooser". Loaded as
# "disabled/mapchooser" the name does not match and every dependent plugin
# fails with "Could not find required plugin".
PROMOTED_PLUGINS = [
    "mapchooser",
    "nominations",
    "rockthevote",
]

# Shipped enabled by upstream.
ENABLED_PLUGINS = [
    "admin-flatfile",
    "adminhelp",
    "adminmenu",
    "antiflood",
    "basebans",
    "basechat",
    "basecommands",
    "basecomm",
    "basetriggers",
    "basevotes",
    "funcommands",
    "funvotes",
    "nextmap",
    "playercommands",
    "reservedslots",
    "sounds",
]

# Everything that ends up in addons/sourcemod/plugins/.
ACTIVE_PLUGINS = PROMOTED_PLUGINS + ENABLED_PLUGINS

ALL_PLUGINS = ACTIVE_PLUGINS + DISABLED_PLUGINS

# Plugins split across a same-named subdirectory, pulled in with
# `#include "<name>/part.sp"`. Those parts must be present in the sandbox even
# though spcomp is only ever handed the top-level .sp.
PLUGINS_WITH_PARTS = [
    "admin-flatfile",
    "adminmenu",
    "basebans",
    "basecomm",
    "basecommands",
    "basevotes",
    "funcommands",
    "funvotes",
    "playercommands",
]

def plugin_label(name):
    """The @sourcemod_sdk target that compiles `name`."""
    return "@sourcemod_sdk//:plugin_" + name
