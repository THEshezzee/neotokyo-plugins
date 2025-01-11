#include <sourcemod>
#include <sdktools>
#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
    name = "NeoTokyo hit marker Display",
    description = "Displays distance to killed player upon kill if enabled",
    version = "1.0",
};

bool g_DistanceEnabled[MAXPLAYERS + 1] = {false, ...};
float g_LastDistance[MAXPLAYERS + 1];

public void OnPluginStart()
{
    RegConsoleCmd("sm_distance", Command_ToggleDistance, "Toggle distance display on kill");
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
}

public Action Command_ToggleDistance(int client, int args)
{
    if (!IsPlayerValid(client))
    {
        ReplyToCommand(client, "You must be a valid player to use this command.");
        return Plugin_Handled;
    }

    g_DistanceEnabled[client] = !g_DistanceEnabled[client];
    ReplyToCommand(client, "Distance display on kill: %s", g_DistanceEnabled[client] ? "ENABLED" : "DISABLED");
    return Plugin_Handled;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));

    if (victim > 0 && attacker > 0 && attacker != victim && IsClientInGame(victim) && IsClientInGame(attacker))
    {
        float victimPos[3], attackerPos[3];
        GetClientAbsOrigin(victim, victimPos);
        GetClientAbsOrigin(attacker, attackerPos);
        float distance = GetVectorDistance(victimPos, attackerPos) * 0.0254; // Convert to meters
        
        if (g_DistanceEnabled[attacker])
        {
            PrintToChat(attacker, "Distance to killed player: %.2f meters", distance);
        }
    }
}

bool IsPlayerValid(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client));
}