#include <sourcemod>
#include <sdktools>
#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.2"

bool g_bGodMode[MAXPLAYERS + 1];

public Plugin myinfo = 
{
    name = "NT God Mode",
    description = "makes fun",
    version = PLUGIN_VERSION
};

public void OnPluginStart()
{
    RegAdminCmd("sm_god", Command_God, ADMFLAG_GENERIC, "Toggle god mode: sm_god [<name>] <1|0>");
    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
}

public void OnClientPutInServer(int client)
{
    g_bGodMode[client] = false;
}

public Action Command_God(int client, int args)
{
    if (args < 1)
    {
        if (!client)
        {
            ReplyToCommand(client, "Command can only be used in-game");
            return Plugin_Handled;
        }
        
        g_bGodMode[client] = !g_bGodMode[client];
        ApplyInvincibility(client);
        ReplyToCommand(client, "God mode %s", g_bGodMode[client] ? "ON" : "OFF");
        return Plugin_Handled;
    }

    char arg1[32], arg2[4];
    GetCmdArg(1, arg1, sizeof(arg1));
    GetCmdArg(2, arg2, sizeof(arg2));

    if (args == 1)
    {
        if (!client)
        {
            ReplyToCommand(client, "Command can only be used in-game");
            return Plugin_Handled;
        }

        int value = StringToInt(arg1);
        if (value < 0 || value > 1)
        {
            ReplyToCommand(client, "Invalid value. Use 1 or 0");
            return Plugin_Handled;
        }

        g_bGodMode[client] = view_as<bool>(value);
        ApplyInvincibility(client);
        ReplyToCommand(client, "god mode %s", g_bGodMode[client] ? "ON" : "OFF");
    }
    else if (args == 2)
    {
        if (!CheckCommandAccess(client, "sm_god_target", ADMFLAG_GENERIC))
        {
            ReplyToCommand(client, "No access to target other players");
            return Plugin_Handled;
        }

        int target = FindTarget(client, arg1, true, false);
        if (target == -1)
            return Plugin_Handled;

        int value = StringToInt(arg2);
        if (value < 0 || value > 1)
        {
            ReplyToCommand(client, "Invalid value. Use 1 or 0");
            return Plugin_Handled;
        }

        g_bGodMode[target] = view_as<bool>(value);
        ApplyInvincibility(target);
        ShowActivity2(client, "[SM] ", "Set god mode %s for %N", g_bGodMode[target] ? "ON" : "OFF", target);
    }

    return Plugin_Handled;
}

void ApplyInvincibility(int client)
{
    if (!IsValidClient(client) || !IsPlayerAlive(client))
        return;

    if (g_bGodMode[client])
    {
        // Disable all damage
        SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
        
        // Additional protection against physics damage
        SetEntProp(client, Prop_Data, "m_CollisionGroup", 2); // 2 = COLLISION_GROUP_DEBRIS
    }
    else
    {
        // Restore default values
        SetEntProp(client, Prop_Data, "m_takedamage", 2, 1); // 2 = DAMAGE_YES
        SetEntProp(client, Prop_Data, "m_CollisionGroup", 5); // 5 = COLLISION_GROUP_PLAYER
    }
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsValidClient(client) && g_bGodMode[client])
    {
        CreateTimer(0.2, Timer_ApplyInvincibility, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }
    return Plugin_Continue;
}

public Action Timer_ApplyInvincibility(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (IsValidClient(client) && g_bGodMode[client])
    {
        ApplyInvincibility(client);
    }
    return Plugin_Stop;
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsValidClient(client))
    {
        g_bGodMode[client] = false;
    }
    return Plugin_Continue;
}

public void OnClientDisconnect(int client)
{
    g_bGodMode[client] = false;
}