#ifndef AUTH_BY_URL_SMSDK_CONFIG_H_
#define AUTH_BY_URL_SMSDK_CONFIG_H_

#define SMEXT_CONF_NAME "Auth by URL"
#define SMEXT_CONF_DESCRIPTION "Asks an HTTPS endpoint who may join"
#define SMEXT_CONF_VERSION "1.0"
#define SMEXT_CONF_AUTHOR "rules_sourcemod"
#define SMEXT_CONF_URL "https://github.com/lanofdoom/rules_sourcemod"
#define SMEXT_CONF_LOGTAG "AUTHURL"
#define SMEXT_CONF_LICENSE "GPL"
#define SMEXT_CONF_DATESTRING __DATE__

#define SMEXT_LINK(name) SDKExtension *g_pExtensionIface = name;

#define SMEXT_ENABLE_PLAYERHELPERS

#endif  // AUTH_BY_URL_SMSDK_CONFIG_H_
