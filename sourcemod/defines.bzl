"""Preprocessor defines required to compile against the SourceMod SDK.

These are a property of the SDK headers, not of any particular rule: the headers
select platform code paths from `WIN32`/`_LINUX`/`OSX`, and on POSIX they expect
the MSVC-spelled string functions to be macro-mapped to their C equivalents.

They live here, rather than only in the extension rule, so that
`@sourcemod_sdk//:sourcemod_headers` can propagate them to every dependent. That
makes a plain `cc_library` depending on the SDK compile correctly without having
to restate any of this.
"""

_POSIX_DEFINES = [
    "stricmp=strcasecmp",
    "_stricmp=strcasecmp",
    "_snprintf=snprintf",
    "_vsnprintf=vsnprintf",
    "HAVE_STDINT_H",
    "GNUC",
    "COMPILER_GCC",
]

_MSVC_DEFINES = [
    "_CRT_SECURE_NO_DEPRECATE",
    "_CRT_SECURE_NO_WARNINGS",
    "_CRT_NONSTDC_NO_DEPRECATE",
    "_ITERATOR_DEBUG_LEVEL=0",
    "COMPILER_MSVC",
    "COMPILER_MSVC32",
]

SOURCEMOD_PLATFORM_DEFINES = select({
    Label("@platforms//os:windows"): ["WIN32", "_WINDOWS"] + _MSVC_DEFINES,
    Label("@platforms//os:macos"): ["OSX", "_OSX", "POSIX"] + _POSIX_DEFINES,
    "//conditions:default": ["_LINUX", "POSIX"] + _POSIX_DEFINES,
})
