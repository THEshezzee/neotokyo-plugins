#include <sourcemod>
#include <sdktools>
#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
    name = "Killer Info Display",
    description = "Shows specific info about the player who killed you in a panel",
    version = "1.0"
};

#define MENU_TIMEOUT 20

int g_LastKiller[MAXPLAYERS + 1];
int g_LastKillerHealth[MAXPLAYERS + 1];
char g_LastWeaponUsed[MAXPLAYERS + 1][64];
float g_LastDistance[MAXPLAYERS + 1];

public void OnPluginStart()
{
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));

    if (victim > 0 && attacker > 0 && attacker != victim)
    {
        g_LastKiller[victim] = attacker;
        if (IsClientInGame(attacker))
        {
            g_LastKillerHealth[victim] = GetEntProp(attacker, Prop_Data, "m_iHealth");
            LogMessage("Attacker %d health: %d", attacker, g_LastKillerHealth[victim]);
            
            float victimPos[3], attackerPos[3];
            GetClientAbsOrigin(victim, victimPos);
            GetClientAbsOrigin(attacker, attackerPos);
            g_LastDistance[victim] = GetVectorDistance(victimPos, attackerPos) / 48.5; // magic value
        }
        else
        {
            g_LastKillerHealth[victim] = 0;
            LogMessage("Attacker %d not in game, setting health to 0", attacker);
            g_LastDistance[victim] = 0.0;
        }
        event.GetString("weapon", g_LastWeaponUsed[victim], sizeof(g_LastWeaponUsed[]));
        CreateTimer(0.1, Timer_ShowKillerInfo, victim);
    }
}

public Action Timer_ShowKillerInfo(Handle timer, any client)
{
    if (IsClientInGame(client))
    {
        ShowKillerPanel(client);
    }
    return Plugin_Stop;
}

void ShowKillerPanel(int client)
{
    int killer = g_LastKiller[client];
    if (!IsClientInGame(killer))
    {
        LogMessage("Killer %d not in game for client %d", killer, client);
        return;
    }

    char info[256];
    char name[MAX_NAME_LENGTH];
    GetClientName(killer, name, sizeof(name));

    Panel panel = new Panel();
    LogMessage("Displaying panel for client %d with killer %d", client, killer);

    Format(info, sizeof(info), "%s killed you", name);
    panel.SetTitle(info);

    Format(info, sizeof(info), "HP: %d", g_LastKillerHealth[client]);
    panel.DrawText(info);

    char classStr[32];
    strcopy(classStr, sizeof(classStr), GetPlayerClassString(GetPlayerClass(killer)));
    Format(info, sizeof(info), "Class: %s", classStr);
    panel.DrawText(info);

    Format(info, sizeof(info), "Weapon: %s", g_LastWeaponUsed[client]);
    panel.DrawText(info);

    Format(info, sizeof(info), "Distance: %.2fm", g_LastDistance[client]); // %.2f
    panel.DrawText(info);

    panel.Send(client, PanelHandler_KillerInfo, MENU_TIMEOUT);
    delete panel;
}

public int PanelHandler_KillerInfo(Menu panel, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        
    }
    return 0;
}

char[] GetPlayerClassString(int class)
{
    static char result[32];
    switch(class)
    {
        case CLASS_RECON: strcopy(result, sizeof(result), "Recon");
        case CLASS_ASSAULT: strcopy(result, sizeof(result), "Assault");
        case CLASS_SUPPORT: strcopy(result, sizeof(result), "Support");
        default: strcopy(result, sizeof(result), "Unknown");
    }
    return result;
}