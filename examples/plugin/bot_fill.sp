#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
    name = "Bot Fill",
    author = "rules_sourcemod",
    description = "Adds bots when few people are playing",
    version = "1.0",
    url = "https://github.com/lanofdoom/rules_sourcemod"
};

ConVar g_cvBotQuota;
ConVar g_cvMinPlayers;

public void OnPluginStart()
{
    g_cvBotQuota = FindConVar("bot_quota");
    if (g_cvBotQuota == null)
        SetFailState("This game has no bot_quota convar");

    g_cvMinPlayers = CreateConVar("sm_bot_fill_min_players", "6",
                                  "Add bots to reach this many players.",
                                  _, true, 0.0);
    g_cvMinPlayers.AddChangeHook(OnMinPlayersChanged);
}

public void OnMinPlayersChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    UpdateBots();
}

public void OnConfigsExecuted()
{
    UpdateBots();
}

public void OnClientPutInServer(int client)
{
    if (!IsFakeClient(client))
        UpdateBots();
}

public void OnClientDisconnect_Post(int client)
{
    UpdateBots();
}

void UpdateBots()
{
    int humans;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
            humans++;
    }

    // Bots playing alone would cycle through maps on an empty server.
    int bots = humans > 0 ? g_cvMinPlayers.IntValue - humans : 0;
    g_cvBotQuota.SetInt(bots > 0 ? bots : 0);
}
