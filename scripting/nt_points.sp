#include <sourcemod>
#include "neotokyo.inc"
#include <sdktools>

new Handle:g_hCvarXP;
new g_OriginalXP[MAXPLAYERS + 1];
new bool:g_XPAdded[MAXPLAYERS + 1];

public void OnPluginStart()
{
    HookEvent("player_spawn", OnPlayerSpawn);
    HookEvent("player_connect", OnPlayerConnect);
    g_hCvarXP = CreateConVar("nt_xp", "1", "Unblock all weapons (1 = enabled, 0 = disabled)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
    HookConVarChange(g_hCvarXP, OnXPControlChanged);
    RegAdminCmd("sm_xp", Command_XP, ADMFLAG_GENERIC, "Manage XP for players");

    if (GetConVarInt(g_hCvarXP) == 1)
    {
        AddXPToAllPlayers();
        PrintToChatAll("[Server] All weapons have been unblocked.");
    }
    else
    {
        PrintToChatAll("[Server] All weapons are currently blocked.");
    }
}

public Action OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (IsValidPlayer(client) && GetConVarInt(g_hCvarXP) == 1 && !g_XPAdded[client])
    {
        AddXP(client);
        g_XPAdded[client] = true;
    }
    return Plugin_Continue;
}

public Action OnPlayerConnect(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (IsValidPlayer(client))
    {
        g_XPAdded[client] = false;
    }
    return Plugin_Continue;
}

public void OnXPControlChanged(Handle:cvar, const char[] oldValue, const char[] newValue)
{
    int currentValue = StringToInt(newValue);
    if (currentValue == 0)
    {
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i))
            {
                if (g_XPAdded[i])
                {
                    int currentXP = GetPlayerXP(i);
                    SetPlayerXP(i, (currentXP > 25) ? currentXP - 25 : 0);
                    g_XPAdded[i] = false;
                }
            }
        }
        PrintToChatAll("[Server] All weapons have been blocked.");
    }
    else if (currentValue == 1)
    {
        AddXPToAllPlayers();
        PrintToChatAll("[Server] All weapons have been unblocked.");
    }
}

public Action Command_XP(int client, int args)
{
    if (args == 0)
    {
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i))
            {
                char name[MAX_NAME_LENGTH];
                GetClientName(i, name, sizeof(name));
                ReplyToCommand(client, "%s - XP: %d", name, GetPlayerXP(i));
            }
        }
    }
    else if (args == 1)
    {
        char arg1[64];
        GetCmdArg(1, arg1, sizeof(arg1));

        if (StrEqual(arg1, "*", false))
        {
            ReplyToCommand(client, "Usage: sm_xp * <+/-><value> to adjust XP for all players.");
        }
        else if (StrEqual(arg1, "jinrai", false) || StrEqual(arg1, "nsf", false))
        {
            ReplyToCommand(client, "Usage: sm_xp <jinrai/nsf> <value> to set or adjust XP for a team.");
        }
        else
        {
            int target = FindTarget(client, arg1, true, false);
            if (target != -1)
            {
                ReplyToCommand(client, "%N's XP: %d", target, GetPlayerXP(target));
            }
            else
            {
                ReplyToCommand(client, "Player not found.");
            }
        }
    }
    else if (args == 2)
    {
        char arg1[64], arg2[64];
        GetCmdArg(1, arg1, sizeof(arg1));
        GetCmdArg(2, arg2, sizeof(arg2));

        if (StrEqual(arg1, "*", false))
        {
            int xpChange = StringToInt(arg2);
            bool isAddition = arg2[0] == '+';
            bool isSubtraction = arg2[0] == '-';
            char action[16];

            if (isAddition || isSubtraction)
            {
                xpChange = StringToInt(arg2[1]);
                action = isAddition ? "added" : "subtracted";
            }
            else
            {
                action = "set";
            }

            int playersAffected = 0;
            for (int i = 1; i <= MaxClients; i++)
            {
                if (IsClientInGame(i))
                {
                    int currentXP = GetPlayerXP(i);
                    int newXP = currentXP;
                    if (isAddition)
                        newXP += xpChange;
                    else if (isSubtraction)
                        newXP -= xpChange;
                    else
                        newXP = xpChange;

                    SetPlayerXP(i, newXP);
                    playersAffected++;
                }
            }
            ReplyToCommand(client, "XP %s for %d players by %d", action, playersAffected, xpChange);
        }
        else if (StrEqual(arg1, "jinrai", false) || StrEqual(arg1, "nsf", false))
        {
            int team = StrEqual(arg1, "jinrai", false) ? TEAM_JINRAI : TEAM_NSF;
            int xpChange = StringToInt(arg2);
            bool isAddition = arg2[0] == '+';
            bool isSubtraction = arg2[0] == '-';

            if (isAddition || isSubtraction)
                xpChange = StringToInt(arg2[1]);

            int playersAffected = 0;
            char message[256] = "";
            Format(message, sizeof(message), "XP modified for players on team %s:\n", arg1);

            for (int i = 1; i <= MaxClients; i++)
            {
                if (IsClientInGame(i) && GetClientTeam(i) == team)
                {
                    char playerName[MAX_NAME_LENGTH];
                    GetClientName(i, playerName, sizeof(playerName));
                    int currentXP = GetPlayerXP(i);
                    int newXP = currentXP;
                    if (isAddition)
                        newXP += xpChange;
                    else if (isSubtraction)
                        newXP -= xpChange;
                    else
                        newXP = xpChange;

                    SetPlayerXP(i, newXP);
                    playersAffected++;

                    char temp[64];
                    Format(temp, sizeof(temp), "%s: Old XP: %d, New XP: %d\n", playerName, currentXP, newXP);
                    StrCat(message, sizeof(message), temp);
                }
            }
            ReplyToCommand(client, message);
        }
        else
        {
            int target = FindTarget(client, arg1, true, false);
            if (target != -1)
            {
                if (arg2[0] == '+' || arg2[0] == '-')
                {
                    int change = StringToInt(arg2);
                    int newXP = GetPlayerXP(target) + change;
                    SetPlayerXP(target, newXP);
                    ReplyToCommand(client, "XP modified for %N: New XP: %d", target, newXP);
                }
                else
                {
                    int newXP = StringToInt(arg2);
                    SetPlayerXP(target, newXP);
                    ReplyToCommand(client, "XP set for %N: New XP: %d", target, newXP);
                }
            }
            else
            {
                ReplyToCommand(client, "Player not found.");
            }
        }
    }
    else
    {
        ReplyToCommand(client, "Usage: sm_xp - shows all players' XP\n       sm_xp <player> - shows player's XP\n       sm_xp <player> <value> - sets player's XP\n       sm_xp <player> <+/-><value> - adds or subtracts XP from player\n       sm_xp * <+/-><value> - adjusts XP for all players\n       sm_xp <jinrai/nsf> <value> - sets or adjusts XP for a team");
    }
    return Plugin_Handled;
}

void AddXP(int client)
{
    int currentXP = GetPlayerXP(client);
    SetPlayerXP(client, currentXP + 25);
}

void AddXPToAllPlayers()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !g_XPAdded[i])
        {
            AddXP(i);
            g_XPAdded[i] = true;
        }
    }
}

public void OnClientDisconnect(int client)
{
    g_OriginalXP[client] = 0;
    g_XPAdded[client] = false;
}

stock bool IsValidPlayer(int client)
{
    return (1 <= client <= MaxClients && IsClientInGame(client));
}