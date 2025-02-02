#include <sourcemod>
#include <sdktools>
#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
    name = "NeoTokyo Hitmarker Settings",
    description = "Allows setting hitmarker options with advanced features",
    version = "1.5",
    url = "https://github.com/THEshezzee/neotokyo-plugins"
};

#define HITMARKER_INTERVAL 300.0

bool g_HitMarkerEnabled[MAXPLAYERS + 1];
bool g_KillMarkerEnabled[MAXPLAYERS + 1];
bool g_DamageDealedEnabled[MAXPLAYERS + 1];
bool g_HealthLeftEnabled[MAXPLAYERS + 1];
int g_LastHealth[MAXPLAYERS + 1][MAXPLAYERS + 1];
int g_TotalDamage[MAXPLAYERS + 1][MAXPLAYERS + 1];

ArrayList g_HitMarkerSounds;

char g_SelectedHitSound[MAXPLAYERS + 1][PLATFORM_MAX_PATH];
char g_SelectedKillSound[MAXPLAYERS + 1][PLATFORM_MAX_PATH];

ConVar g_cvarHitmarkerEnabled;
ConVar g_cvarHitmarkerAdminOnly;
ConVar g_cvarHitmarkerSay;

Handle g_hTimerHitmarkerSay;

public void OnPluginStart()
{
    g_cvarHitmarkerEnabled = CreateConVar("sm_hitmarker", "1", "", _, true, 0.0, true, 1.0);
    g_cvarHitmarkerAdminOnly = CreateConVar("sv_hitmarkeradminonly", "0", "", _, true, 0.0, true, 1.0);
    g_cvarHitmarkerSay = CreateConVar("sv_hitmarkersay", "1", "", _, true, 0.0, true, 1.0);
    
    RegAdminCmd("sm_hit", Command_OpenHitMenu, g_cvarHitmarkerAdminOnly.IntValue ? ADMFLAG_GENERIC : ADMFLAG_RESERVATION, "Open hitmarker settings menu");
    
    HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
    HookEvent("player_spawn", Event_PlayerSpawn);

    g_HitMarkerSounds = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));

    AutoExecConfig(true, "plugin_hitmarker");

    if (g_cvarHitmarkerSay.IntValue == 1 && g_cvarHitmarkerEnabled.IntValue == 1)
    {
        g_hTimerHitmarkerSay = CreateTimer(HITMARKER_INTERVAL, Timer_HitmarkerAnnouncement, _, TIMER_REPEAT);
    }
}

public void OnMapStart()
{
    if (g_hTimerHitmarkerSay != null)
    {
        KillTimer(g_hTimerHitmarkerSay);
        g_hTimerHitmarkerSay = null;
    }
    if (g_cvarHitmarkerSay.IntValue == 1 && g_cvarHitmarkerEnabled.IntValue == 1)
    {
        g_hTimerHitmarkerSay = CreateTimer(HITMARKER_INTERVAL, Timer_HitmarkerAnnouncement, _, TIMER_REPEAT);
    }

    LoadSounds();

    char soundPath[PLATFORM_MAX_PATH];
    char fullPath[PLATFORM_MAX_PATH];
    for (int i = 0; i < g_HitMarkerSounds.Length; i++)
    {
        g_HitMarkerSounds.GetString(i, soundPath, sizeof(soundPath));
        PrecacheSound(soundPath, true);
        Format(fullPath, sizeof(fullPath), "sound/%s", soundPath);
        AddFileToDownloadsTable(fullPath);
    }
}

void LoadSounds()
{
    char soundPath[PLATFORM_MAX_PATH];
    char buffer[PLATFORM_MAX_PATH];

    g_HitMarkerSounds.Clear();

    Format(soundPath, sizeof(soundPath), "sound/hitsounds/*.wav");
    Handle dir = OpenDirectory("sound/hitsounds");
    if (dir != null)
    {
        while (ReadDirEntry(dir, buffer, sizeof(buffer)))
        {
            if (StrContains(buffer, ".wav", false) != -1)
            {
                Format(buffer, sizeof(buffer), "hitsounds/%s", buffer);

                g_HitMarkerSounds.PushString(buffer);
            }
        }
        CloseHandle(dir);
    }
}

public Action Timer_HitmarkerAnnouncement(Handle timer)
{
    if (g_cvarHitmarkerEnabled.IntValue == 1 && g_cvarHitmarkerSay.IntValue == 1)
    {
        PrintToChatAll("Use !hit for hitmarker settings");
    }
    return Plugin_Continue;
}

public Action Command_OpenHitMenu(int client, int args)
{
    if (!IsPlayerValid(client))
    {
        ReplyToCommand(client, "[hitmarker] You must be a valid player to use this command.");
        return Plugin_Handled;
    }

    if (g_cvarHitmarkerEnabled.IntValue == 0)
    {
        ReplyToCommand(client, "[hitmarker] The hitmarker plugin is currently disabled.");
        return Plugin_Handled;
    }

    Menu menu = new Menu(MenuHandler_HitMarkerMain);
    menu.SetTitle("Hit Marker Setting");

    char itemText[64];
    Format(itemText, sizeof(itemText), "%s Kill Marker", g_KillMarkerEnabled[client] ? "Disable" : "Enable");
    menu.AddItem("killmarker", itemText);

    Format(itemText, sizeof(itemText), "%s Hit Marker", g_HitMarkerEnabled[client] ? "Disable" : "Enable");
    menu.AddItem("hitmarker", itemText);

    menu.AddItem("advanced", "Advanced options");

    menu.AddItem("hitsounds", "Hitsounds");
    menu.AddItem("killsounds", "Killsounds");

    menu.Display(client, MENU_TIME_FOREVER);
    return Plugin_Handled;
}

public void MenuHandler_HitMarkerMain(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));

        if (StrEqual(info, "killmarker"))
        {
            g_KillMarkerEnabled[param1] = !g_KillMarkerEnabled[param1];
            PrintToChat(param1, "[hitmarker] Kill Marker %s", g_KillMarkerEnabled[param1] ? "enabled" : "disabled");
            Command_OpenHitMenu(param1, 0);
        }
        else if (StrEqual(info, "hitmarker"))
        {
            g_HitMarkerEnabled[param1] = !g_HitMarkerEnabled[param1];
            PrintToChat(param1, "[hitmarker] Hit Marker %s", g_HitMarkerEnabled[param1] ? "enabled" : "disabled");
            Command_OpenHitMenu(param1, 0);
        }
        else if (StrEqual(info, "hitsounds") || StrEqual(info, "killsounds"))
        {
            ShowSoundMenu(param1);
        }
        else if (StrEqual(info, "advanced"))
        {
            ShowAdvancedMenu(param1);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

void ShowSoundMenu(int client)
{
    Menu menu = new Menu(MenuHandler_Sound);
    menu.SetTitle("Select Sound");

    char soundPath[PLATFORM_MAX_PATH];
    char soundName[PLATFORM_MAX_PATH];
    char tempPath[PLATFORM_MAX_PATH];
    for (int i = 0; i < g_HitMarkerSounds.Length; i++)
    {
        g_HitMarkerSounds.GetString(i, soundPath, sizeof(soundPath));
        int lastSlash = FindCharInString(soundPath, '/', true);
        if (lastSlash != -1)
        {
            strcopy(tempPath, sizeof(tempPath), soundPath[lastSlash + 1]);
        }
        else
        {
            strcopy(tempPath, sizeof(tempPath), soundPath);
        }
        strcopy(soundName, sizeof(soundName), tempPath);
        menu.AddItem(soundPath, soundName);
    }

    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Sound(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char info[PLATFORM_MAX_PATH];
        menu.GetItem(param2, info, sizeof(info));
        strcopy(g_SelectedHitSound[param1], sizeof(g_SelectedHitSound[]), info);
        strcopy(g_SelectedKillSound[param1], sizeof(g_SelectedKillSound[]), info);
        PrintToChat(param1, "[hitmarker] Sound set to: %s", info);
        ShowSoundMenu(param1);
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        Command_OpenHitMenu(param1, 0);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

void ShowAdvancedMenu(int client)
{
    Menu menu = new Menu(MenuHandler_HitMarkerAdvanced);
    menu.SetTitle("Advanced Hit Marker Options");

    char itemText[64];
    Format(itemText, sizeof(itemText), "%s Damage Dealt Display", g_DamageDealedEnabled[client] ? "Disable" : "Enable");
    menu.AddItem("damage_dealed", itemText);

    Format(itemText, sizeof(itemText), "%s Health Left Display", g_HealthLeftEnabled[client] ? "Disable" : "Enable");
    menu.AddItem("health_left", itemText);

    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public void MenuHandler_HitMarkerAdvanced(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));

        if (StrEqual(info, "damage_dealed"))
        {
            g_DamageDealedEnabled[param1] = !g_DamageDealedEnabled[param1];
            PrintToChat(param1, "[hitmarker] Damage Dealt Display %s", g_DamageDealedEnabled[param1] ? "enabled" : "disabled");
            ShowAdvancedMenu(param1);
        }
        else if (StrEqual(info, "health_left"))
        {
            g_HealthLeftEnabled[param1] = !g_HealthLeftEnabled[param1];
            PrintToChat(param1, "[hitmarker] Health Left Display %s", g_HealthLeftEnabled[param1] ? "enabled" : "disabled");
            ShowAdvancedMenu(param1);
        }
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        Command_OpenHitMenu(param1, 0);
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
    
    if (attacker > 0 && victim > 0 && attacker != victim && IsPlayerValid(attacker) && g_HitMarkerEnabled[attacker] && g_cvarHitmarkerEnabled.IntValue == 1)
    {
        float attackerPos[3], victimPos[3];
        GetClientAbsOrigin(attacker, attackerPos);
        GetClientAbsOrigin(victim, victimPos);
        float distance = GetVectorDistance(attackerPos, victimPos) * 0.0254;
        
        int currentHealth = GetClientHealth(victim);
        int damage = g_LastHealth[attacker][victim] - currentHealth;

        if(damage > 0)
        {
            g_TotalDamage[attacker][victim] += damage;
        }
        else
        {
            g_TotalDamage[attacker][victim] += 1;
        }

        g_LastHealth[attacker][victim] = currentHealth;
        
        char victimName[MAX_NAME_LENGTH];
        if (GetClientName(victim, victimName, sizeof(victimName))) 
        {
            if(g_HealthLeftEnabled[attacker] && currentHealth > 0)
            {
                PrintToChat(attacker, "[hitmarker] you hit %s with damage %d from distance %.2f meters (health left %d)", victimName, damage > 0 ? damage : 1, distance, currentHealth);
            }
            else
            {
                PrintToChat(attacker, "[hitmarker] you hit %s with damage %d from distance %.2f meters", victimName, damage > 0 ? damage : 1, distance);
            }
        }

        if (g_SelectedHitSound[attacker][0] != '\0')
        {
            EmitSoundToClient(attacker, g_SelectedHitSound[attacker], SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL);
        }
    }
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int victim = GetClientOfUserId(event.GetInt("userid"));
    
    if (attacker > 0 && victim > 0 && attacker != victim && IsPlayerValid(attacker) && g_KillMarkerEnabled[attacker] && g_cvarHitmarkerEnabled.IntValue == 1)
    {
        float attackerPos[3], victimPos[3];
        GetClientAbsOrigin(attacker, attackerPos);
        GetClientAbsOrigin(victim, victimPos);
        float distance = GetVectorDistance(attackerPos, victimPos) * 0.0254;
        
        char victimName[MAX_NAME_LENGTH];
        if (GetClientName(victim, victimName, sizeof(victimName))) 
        {
            int totalDamage = g_TotalDamage[attacker][victim];
            if(g_DamageDealedEnabled[attacker])
            {
                PrintToChat(attacker, "[hitmarker] you killed %s from distance %.2f meters with total damage dealed %d", victimName, distance, totalDamage);
            }
            else
            {
                PrintToChat(attacker, "[hitmarker] you killed %s from distance %.2f meters", victimName, distance);
            }
        }

        if (g_SelectedKillSound[attacker][0] != '\0')
        {
            EmitSoundToClient(attacker, g_SelectedKillSound[attacker], SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL);
        }
    }
    
    for (int i = 1; i <= MaxClients; ++i)
    {
        if (IsClientInGame(i))
        {
            g_LastHealth[i][victim] = 0;
            g_TotalDamage[i][victim] = 0;
        }
    }
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0 && IsClientInGame(client))
    {
        for (int i = 1; i <= MaxClients; ++i)
        {
            g_LastHealth[i][client] = GetClientHealth(client);
            g_TotalDamage[i][client] = 0;
        }
    }
}

bool IsPlayerValid(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

public void OnConfigsExecuted()
{
    int flags = g_cvarHitmarkerAdminOnly.IntValue ? ADMFLAG_GENERIC : ADMFLAG_RESERVATION;
    RegAdminCmd("sm_hit", Command_OpenHitMenu, flags, "Open hitmarker settings menu");
}