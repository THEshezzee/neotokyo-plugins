#include <sourcemod>
#include <sdktools>
#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

#define TEAM_KILL_CHECK_TIME 5.0 
#define BAN_DURATION 5 

public Plugin myinfo = 
{
    name = "Neotokyo Team Killing Ban",
    description = "Bans players for team-killing entire team in short time frame",
    version = "1.0"
};

ArrayList g_TeamKillers[MAXPLAYERS + 1];

public void OnPluginStart()
{
    HookEvent("player_death", Event_PlayerDeath);
    for (int i = 0; i <= MAXPLAYERS; i++)
    {
        g_TeamKillers[i] = new ArrayList();
    }
}

public void OnClientDisconnect(int client)
{
    delete g_TeamKillers[client];
    g_TeamKillers[client] = new ArrayList();
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));

    if (IsValidClient(attacker) && IsValidClient(victim) && GetClientTeam(attacker) == GetClientTeam(victim) && attacker != victim)
    {
        char weapon[64];
        event.GetString("weapon", weapon, sizeof(weapon));

        if (!(StrEqual(weapon, "weapon_grenade") || StrEqual(weapon, "weapon_smokegrenade") || StrEqual(weapon, "weapon_remotedet") || StrEqual(weapon, "weapon_grenade_projectile") || StrEqual(weapon, "weapon_grenade_detapack")))
        {
            int team = GetClientTeam(attacker);
            int teamSize = 0;
            for (int i = 1; i <= MaxClients; i++)
            {
                if (IsClientInGame(i) && GetClientTeam(i) == team && i != attacker)
                {
                    teamSize++;
                }
            }

            if (teamSize > 1)
            {
                g_TeamKillers[attacker].Push(GetGameTime());

                if (g_TeamKillers[attacker].Length >= teamSize)
                {
                    float firstKillTime = g_TeamKillers[attacker].Get(0);
                    float lastKillTime = GetGameTime();

                    if (lastKillTime - firstKillTime <= TEAM_KILL_CHECK_TIME)
                    {
                        char command[128];
                        Format(command, sizeof(command), "sm_ban \"#%d\" \"5\" Banned for 5 minutes for team killing.", GetClientUserId(attacker));
                        ServerCommand(command);
                        
                        PrintToChatAll("[SM] Player %N has been banned for team killing.", attacker);

                        CreateTimer(float(BAN_DURATION * 60), Timer_UnbanPlayer, GetClientUserId(attacker));
                    }
                    g_TeamKillers[attacker].Clear();
                }
            }
        }
    }
    return Plugin_Continue;
}

public Action Timer_UnbanPlayer(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (client && IsClientConnected(client))
    {
        char clientSteamID[32];
        GetClientAuthId(client, AuthId_Steam2, clientSteamID, sizeof(clientSteamID), true);

        if (clientSteamID[0] != '\0')
        {
            char unbanCommand[128];
            Format(unbanCommand, sizeof(unbanCommand), "sm_unban %s", clientSteamID);
            ServerCommand(unbanCommand);
            PrintToServer("Unbanned player %s after %d minutes.", clientSteamID, BAN_DURATION);
        }
    }
    return Plugin_Handled;
}