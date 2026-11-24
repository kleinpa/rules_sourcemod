#include <sourcemod>
#include <auth_by_url>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
    name = "Auth by URL",
    author = "rules_sourcemod",
    description = "Asks an HTTPS endpoint who may join",
    version = "1.0",
    url = "https://github.com/lanofdoom/rules_sourcemod"
};

ConVar g_cvUrl;

public void OnPluginStart()
{
    g_cvUrl = CreateConVar("sm_auth_by_url", "",
                           "Players may join if this URL, with their SteamID64 appended, succeeds. " ...
                           "If empty, everyone may join.",
                           FCVAR_PROTECTED);
}

public void OnClientAuthorized(int client, const char[] auth)
{
    char url[512];
    g_cvUrl.GetString(url, sizeof(url));
    if (url[0] == '\0' || IsFakeClient(client))
        return;

    char steamId[32];
    if (!GetClientAuthId(client, AuthId_SteamID64, steamId, sizeof(steamId)))
    {
        KickClient(client, "Could not verify your Steam ID");
        return;
    }

    StrCat(url, sizeof(url), steamId);
    AuthByUrl_Check(client, url);
}
