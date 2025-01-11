#include <sourcemod>
#include <sdktools>
#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
    name = "NeoTokyo Hitmarker Settings",
    description = "Allows setting hitmarker options",
    version = "1.1"
};

bool g_HitMarkerEnabled[MAXPLAYERS + 1] = {false, ...};
bool g_KillMarkerEnabled[MAXPLAYERS + 1] = {false, ...};
int g_LastHealth[MAXPLAYERS + 1] = {0, ...}; // To track health before damage for damage calculation

public void OnPluginStart()
{
    RegConsoleCmd("sm_hit", Command_OpenHitMenu, "Open hitmarker settings menu");
    HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
    HookEvent("player_spawn", Event_PlayerSpawn); // To update health on spawn
}

public Action Command_OpenHitMenu(int client, int args)
{
    if (!IsPlayerValid(client))
    {
        ReplyToCommand(client, "[hitmarker] You must be a valid player to use this command.");
        return Plugin_Handled;
    }

    Menu menu = new Menu(MenuHandler_HitMarkerSettings);
    menu.SetTitle("Hit Marker Setting");

    char itemText[64];
    Format(itemText, sizeof(itemText), "%s Kill Marker", g_KillMarkerEnabled[client] ? "Disable" : "Enable");
    menu.AddItem("killmarker", itemText);

    Format(itemText, sizeof(itemText), "%s Hit Marker", g_HitMarkerEnabled[client] ? "Disable" : "Enable");
    menu.AddItem("hitmarker", itemText);

    menu.Display(client, MENU_TIME_FOREVER);
    return Plugin_Handled;
}

public int MenuHandler_HitMarkerSettings(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));

        if (StrEqual(info, "killmarker"))
        {
            g_KillMarkerEnabled[param1] = !g_KillMarkerEnabled[param1];
            PrintToChat(param1, "[hitmarker] killmarker %s", g_KillMarkerEnabled[param1] ? "enabled" : "disabled");
        }
        else if (StrEqual(info, "hitmarker"))
        {
            g_HitMarkerEnabled[param1] = !g_HitMarkerEnabled[param1];
            PrintToChat(param1, "[hitmarker] hitmarker %s", g_HitMarkerEnabled[param1] ? "enabled" : "disabled");
        }

        Command_OpenHitMenu(param1, 0); // Redisplay menu to show updated state
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int victim = GetClientOfUserId(event.GetInt("userid"));
    
    if (attacker > 0 && victim > 0 && attacker != victim && IsPlayerValid(attacker) && g_HitMarkerEnabled[attacker])
    {
        float attackerPos[3], victimPos[3];
        GetClientAbsOrigin(attacker, attackerPos);
        GetClientAbsOrigin(victim, victimPos);
        float distance = GetVectorDistance(attackerPos, victimPos) * 0.0254; // Convert to meters
        
        int currentHealth = GetClientHealth(victim);
        int damage = g_LastHealth[victim] - currentHealth; // This assumes no health gain between hits
        
        char victimName[MAX_NAME_LENGTH];
        if (GetClientName(victim, victimName, sizeof(victimName))) // Check if name was successfully retrieved
        {
            PrintToChat(attacker, "[hitmarker] you hit %s with damage %d from distance %.2f meters", victimName, damage > 0 ? damage : 1, distance);
        }
    }

    // Update last health of the victim
    if (IsClientInGame(victim))
    {
        g_LastHealth[victim] = GetClientHealth(victim);
    }
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int victim = GetClientOfUserId(event.GetInt("userid"));
    
    if (attacker > 0 && victim > 0 && attacker != victim && IsPlayerValid(attacker) && g_KillMarkerEnabled[attacker])
    {
        float attackerPos[3], victimPos[3];
        GetClientAbsOrigin(attacker, attackerPos);
        GetClientAbsOrigin(victim, victimPos);
        float distance = GetVectorDistance(attackerPos, victimPos) * 0.0254; // Convert to meters
        
        char victimName[MAX_NAME_LENGTH];
        if (GetClientName(victim, victimName, sizeof(victimName))) // Check if name was successfully retrieved
        {
            PrintToChat(attacker, "[hitmarker] you killed %s from distance %.2f meters", victimName, distance);
        }
    }
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0 && IsClientInGame(client))
    {
        g_LastHealth[client] = GetClientHealth(client);
    }
}

bool IsPlayerValid(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client));
}