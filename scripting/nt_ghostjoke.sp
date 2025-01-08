#include <sourcemod>
#include <sdktools>
#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
    name = "Ghost Burn and Explode Plugin",
    description = "Makes players burn or explode if they have ghost",
    version = "1.6"
};

ConVar g_hGhostFireEnabled;
ConVar g_hGhostExplodeChance;

bool g_bHasMessageShown[MAXPLAYERS + 1];
bool g_bIsBurning[MAXPLAYERS + 1];
bool g_bExplosionChecked[MAXPLAYERS + 1];
int g_TimeBombSerial[MAXPLAYERS + 1] = { 0, ... };
int g_Serial_Gen = 0;

// Array to hold explosion messages
char g_szExplosionMessages[][] = 
{
    "{PLAYERNAME} found an old ISIS mine",
    "{PLAYERNAME} pruned by allah",
    "allah akbar!",
    "{PLAYERNAME} felt great liberty",
    "{PLAYERNAME} оказался кбзшером",
    "{PLAYERNAME}, even a doll doesn't give it"
};

public void OnPluginStart()
{
    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_death", Event_PlayerDeath);
    
    g_hGhostFireEnabled = CreateConVar("sm_ghostfire", "0", "Enable or disable ghost burn effect", _, true, 0.0, true, 1.0);
    g_hGhostExplodeChance = CreateConVar("sm_ghostexplode", "10", "Chance in percent for player to instantly explode when picking up the ghost", _, true, 0.0, true, 100.0);

    for (int i = 1; i <= MaxClients; i++)
    {
        g_bHasMessageShown[i] = false;
        g_bIsBurning[i] = false;
        g_bExplosionChecked[i] = false;
        g_TimeBombSerial[i] = 0;
    }
}

public void OnClientPutInServer(int client)
{
    if (IsClientInGame(client))
    {
        CreateTimer(1.0, Timer_CheckGhost, client, TIMER_REPEAT);
        ResetPlayerState(client);
    }
}

public Action Timer_CheckGhost(Handle timer, any client)
{
    if (!IsClientInGame(client))
    {
        return Plugin_Stop;
    }

    bool hasGhost = PlayerHasGhost(client);
    HandleFireEffect(client, hasGhost);

    if (hasGhost && !g_bExplosionChecked[client] && g_TimeBombSerial[client] == 0)
    {
        HandleExplosionChance(client);
        g_bExplosionChecked[client] = true;
    }
    else if (!hasGhost)
    {
        g_bExplosionChecked[client] = false;
    }
    
    return Plugin_Continue;
}

void HandleFireEffect(int client, bool hasGhost)
{
    if (g_hGhostFireEnabled.IntValue == 1 && hasGhost)
    {
        IgniteEntity(client, 3.0);
        g_bIsBurning[client] = true;
        if (!g_bHasMessageShown[client])
        {
            PrintToChat(client, "Xd)0");
            g_bHasMessageShown[client] = true;
        }
    }
    else if (g_bIsBurning[client] && (!hasGhost || g_hGhostFireEnabled.IntValue == 0))
    {
        ExtinguishEntity(client);
        ResetPlayerState(client);
    }
}

void HandleExplosionChance(int client)
{
    int explodeChance = g_hGhostExplodeChance.IntValue;
    int randomValue = GetRandomInt(1, 100);
    
    if (randomValue <= explodeChance)
    {
        CreateTimeBomb(client);
    }
    
    // Debug message
    // char debugMessage[256];
    // Format(debugMessage, sizeof(debugMessage), "Explosion chance: %d, Random value: %d", explodeChance, randomValue);
    // PrintToChat(client, debugMessage);
}

void CreateTimeBomb(int client)
{
    g_TimeBombSerial[client] = ++g_Serial_Gen;
    CreateTimer(0.0, Timer_TimeBomb, client, TIMER_FLAG_NO_MAPCHANGE); // Immediate explosion
}

void KillTimeBomb(int client)
{
    g_TimeBombSerial[client] = 0;
    SetEntityRenderColor(client, 255, 255, 255, 255);
}

public Action Timer_TimeBomb(Handle timer, any client)
{
    if (!IsClientInGame(client) || !IsPlayerAlive(client) || g_TimeBombSerial[client] != g_Serial_Gen)
    {
        KillTimeBomb(client);
        return Plugin_Stop;
    }

    // Since we set the timer to 0 seconds, this will execute immediately:
    float vec[3];
    GetClientAbsOrigin(client, vec);

    // Simulate an explosion:
    ForcePlayerSuicide(client);
    KillTimeBomb(client);
    
    // Randomly select an explosion message
    int randomMessage = GetRandomInt(0, sizeof(g_szExplosionMessages) - 1);
    char formattedMessage[256], playerName[MAX_NAME_LENGTH];
    GetClientName(client, playerName, sizeof(playerName));
    
    // Replace {PLAYERNAME} with the actual player name using string replacement
    strcopy(formattedMessage, sizeof(formattedMessage), g_szExplosionMessages[randomMessage]);
    ReplaceString(formattedMessage, sizeof(formattedMessage), "{PLAYERNAME}", playerName, false);
    
    PrintToChatAll(formattedMessage);
    
    // Add visual effects for the explosion (adjust or add as needed)
    TE_SetupExplosion(vec, 0, 10.0, 1, 0, 100, 1000); // Default explosion effect
    TE_SendToAll();
    
    return Plugin_Stop;
}

bool PlayerHasGhost(int client)
{
    int weapon = GetPlayerWeaponSlot(client, 0); // Assuming primary weapon slot is 0
    if (weapon != -1)
    {
        char classname[64];
        GetEdictClassname(weapon, classname, sizeof(classname));
        if (StrEqual(classname, "weapon_ghost"))
        {
            return true;
        }
    }
    return false;
}

void ResetPlayerState(int client)
{
    g_bHasMessageShown[client] = false;
    g_bIsBurning[client] = false;
    g_bExplosionChecked[client] = false;
    KillTimeBomb(client);
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client && IsClientInGame(client))
    {
        CreateTimer(1.0, Timer_CheckGhost, client, TIMER_REPEAT);
        ResetPlayerState(client);
    }
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client && IsClientInGame(client))
    {
        ClientCommand(client, "stopsound");
        ResetPlayerState(client);
    }
}