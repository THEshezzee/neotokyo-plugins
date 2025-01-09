#include <sourcemod>
#include <sdktools>
#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
    name = "Neotokyo Auto Team Balance",
    description = "Automatically balances teams in Neotokyo based on player count",
    version = "1.0"
};

#define BALANCE_DELAY 2.0 
#define TEAM_CHANGE_DELAY 30.0 

ConVar g_hBalanceThreshold;
ConVar g_hBalanceEnabled;

float g_LastTeamChange[MAXPLAYERS + 1];

public void OnPluginStart()
{
    g_hBalanceThreshold = CreateConVar("sm_neotokyo_balance_threshold", "1", "The difference in player count between teams before balance is triggered", _, true, 1.0, true, 10.0);
    g_hBalanceEnabled = CreateConVar("sm_neotokyo_balance_enabled", "1", "Enable or disable auto team balancing", _, true, 0.0, true, 1.0);
    
    HookEvent("player_team", Event_PlayerTeam, EventHookMode_Post);
    AddCommandListener(OnJoinTeam, "jointeam");

    AutoExecConfig(true, "plugin_neotokyo_autobalance");
}

public void OnClientPostAdminCheck(int client)
{
    g_LastTeamChange[client] = 0.0;
}

public Action OnJoinTeam(int client, const char[] command, int args)
{
    if (!g_hBalanceEnabled.BoolValue || !IsClientInGame(client))
        return Plugin_Continue;

    char arg[4];
    GetCmdArg(1, arg, sizeof(arg));
    int newTeam = StringToInt(arg);

    if (newTeam != TEAM_SPECTATOR && GetClientTeam(client) != TEAM_SPECTATOR && GetGameTime() - g_LastTeamChange[client] < TEAM_CHANGE_DELAY)
    {
        PrintToChat(client, "[SM] You must wait before changing teams again.");
        return Plugin_Handled;
    }

    // Reset timer if switching to or from spectator
    if (newTeam == TEAM_SPECTATOR || GetClientTeam(client) == TEAM_SPECTATOR)
    {
        g_LastTeamChange[client] = 0.0; // Reset to 0, allowing immediate team changes after spectating
    }
    else
    {
        g_LastTeamChange[client] = GetGameTime(); // Update last team change time for non-spectator moves
    }
    
    return Plugin_Continue;
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_hBalanceEnabled.BoolValue)
        return;

    CreateTimer(BALANCE_DELAY, Timer_BalanceTeams);
}

public Action Timer_BalanceTeams(Handle timer)
{
    BalanceTeams();
    return Plugin_Handled;
}

void BalanceTeams()
{
    int jinraiCount = 0;
    int nsfCount = 0;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            int team = GetClientTeam(i);
            if (team == TEAM_JINRAI)
                jinraiCount++;
            else if (team == TEAM_NSF)
                nsfCount++;
        }
    }

    int diff = jinraiCount - nsfCount;
    int threshold = g_hBalanceThreshold.IntValue;
    
    if (Abs(diff) >= threshold)
    {
        int fromTeam = (diff > 0) ? TEAM_JINRAI : TEAM_NSF;
        int toTeam = (diff > 0) ? TEAM_NSF : TEAM_JINRAI;

        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && GetClientTeam(i) == fromTeam && !IsFakeClient(i))
            {
                ChangeClientTeam(i, toTeam);
                PrintToChatAll("[SM] Player %N was moved to balance teams.", i);
                break;
            }
        }
    }
}

public void OnClientDisconnect_Post(int client)
{
    if (g_hBalanceEnabled.BoolValue)
    {
        BalanceTeams();
    }
}

stock int Abs(int value)
{
    return (value < 0) ? -value : value;
}