#include <sourcemod>
#include <sdktools>
#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"

ConVar g_cvarEnabled;
ConVar g_cvarAdminOnly;
ConVar g_cvarBroadcast;
ConVar g_cvarAllowGhost;

int g_iBroadcastTimer = 0;

public Plugin myinfo =
{
    name = "NeoTokyo Weapon Menu",
    description = "Adds a !weapon command to open a weapon selection menu.",
    version = PLUGIN_VERSION
};

public void OnPluginStart()
{
    g_cvarEnabled = CreateConVar("nt_weaponenabled", "1", "Enable or disable the plugin (1 = enabled, 0 = disabled)");
    g_cvarAdminOnly = CreateConVar("nt_weaponadmin", "0", "Restrict the !weapon command to admins only (1 = admin only, 0 = everyone)");
    g_cvarBroadcast = CreateConVar("nt_weaponbroadcast", "1", "Broadcast the existence of the !weapon command to all players (1 = enabled, 0 = disabled)");
    g_cvarAllowGhost = CreateConVar("sm_allowghost", "0", "Enable or disable the Ghost weapon in the weapon menu (1 = enabled, 0 = disabled)", _, true, 0.0, true, 1.0);

    RegConsoleCmd("sm_weapon", Command_WeaponMenu, "Open the weapon selection menu or give a specific weapon.");
    RegConsoleCmd("weapon", Command_WeaponMenu);

    g_iBroadcastTimer = CreateTimer(360.0 + GetRandomFloat(0.0, 10.0), BroadcastMessage, _, TIMER_REPEAT);
}

public Action Command_WeaponMenu(int client, int args)
{
    if (!g_cvarEnabled.BoolValue)
    {
        ReplyToCommand(client, "[NeoTokyo Weapon Menu] Plugin is currently disabled.");
        return Plugin_Handled;
    }

    if (g_cvarAdminOnly.BoolValue && !CheckCommandAccess(client, "sm_weapon", ADMFLAG_GENERIC))
    {
        ReplyToCommand(client, "[NeoTokyo Weapon Menu] You do not have permission to use this command.");
        return Plugin_Handled;
    }

    if (args == 0)
    {
        OpenWeaponMenu(client);
        return Plugin_Handled;
    }

    char weaponName[32];
    GetCmdArg(1, weaponName, sizeof(weaponName));
    Format(weaponName, sizeof(weaponName), "weapon_%s", weaponName);

    bool found = false;

    // Check primary weapons
    for (int i = 0; i < sizeof(weapons_primary); i++)
    {
        if (StrEqual(weaponName, weapons_primary[i]))
        {
            found = true;
            break;
        }
    }

    // Check secondary weapons
    if (!found)
    {
        for (int i = 0; i < sizeof(weapons_secondary); i++)
        {
            if (StrEqual(weaponName, weapons_secondary[i]))
            {
                found = true;
                break;
            }
        }
    }

    // Check grenades
    if (!found)
    {
        for (int i = 0; i < sizeof(weapons_grenade); i++)
        {
            if (StrEqual(weaponName, weapons_grenade[i]))
            {
                found = true;
                break;
            }
        }
    }

    // Special case: Check if Ghost is allowed
    if (StrEqual(weaponName, "weapon_ghost"))
    {
        if (!g_cvarAllowGhost.BoolValue)
        {
            ReplyToCommand(client, "[NeoTokyo Weapon Menu] The Ghost weapon is currently disabled.");
            return Plugin_Handled;
        }
        found = true;
    }

    if (!found)
    {
        ReplyToCommand(client, "[NeoTokyo Weapon Menu] Invalid weapon: %s", weaponName);
        return Plugin_Handled;
    }

    DropPlayerWeapons(client);
    GivePlayerWeapon(client, weaponName);

    char displayName[32];
    TrimAndReplace(weaponName, displayName, sizeof(displayName));
    PrintToChat(client, "[NeoTokyo Weapon Menu] You have been given: %s", displayName);

    return Plugin_Handled;
}

public void OpenWeaponMenu(int client)
{
    Menu menu = new Menu(MenuHandler_WeaponSelect);
    menu.SetTitle("Weapon Selection Menu");

    char displayName[32];

    // Add primary weapons
    for (int i = 0; i < sizeof(weapons_primary); i++)
    {
        TrimAndReplace(weapons_primary[i], displayName, sizeof(displayName));
        menu.AddItem(weapons_primary[i], displayName);
    }

    // Add secondary weapons
    for (int i = 0; i < sizeof(weapons_secondary); i++)
    {
        TrimAndReplace(weapons_secondary[i], displayName, sizeof(displayName));
        menu.AddItem(weapons_secondary[i], displayName);
    }

    // Add grenades
    for (int i = 0; i < sizeof(weapons_grenade); i++)
    {
        TrimAndReplace(weapons_grenade[i], displayName, sizeof(displayName));
        menu.AddItem(weapons_grenade[i], displayName);
    }

    // Add Ghost weapon if allowed
    if (g_cvarAllowGhost.BoolValue)
    {
        TrimAndReplace("weapon_ghost", displayName, sizeof(displayName));
        menu.AddItem("weapon_ghost", displayName);
    }

    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_WeaponSelect(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char item[32];
        menu.GetItem(param2, item, sizeof(item));

        // Ensure Ghost is not accessible if sm_allowghost is disabled
        if (StrEqual(item, "weapon_ghost") && !g_cvarAllowGhost.BoolValue)
        {
            PrintToChat(client, "[NeoTokyo Weapon Menu] The Ghost weapon is currently disabled.");
            return;
        }

        DropPlayerWeapons(client);
        GivePlayerWeapon(client, item);

        char displayName[32];
        TrimAndReplace(item, displayName, sizeof(displayName));
        PrintToChat(client, "[NeoTokyo Weapon Menu] You have been given: %s", displayName);
    }
    else if (action == MenuAction_Cancel)
    {
        delete menu;
    }
}

public void GivePlayerWeapon(int client, const char[] weaponClass)
{
    int weapon = GivePlayerItem(client, weaponClass);
    if (weapon != INVALID_ENT_REFERENCE)
    {
        int ammoType = GetAmmoType(weapon);
        if (ammoType != -1)
            SetWeaponAmmo(client, ammoType, 999);

        int slot = GetWeaponSlot(weapon);
        if (slot != SLOT_NONE)
            SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
    }
}

public void DropPlayerWeapons(int client)
{
    StripPlayerWeapons(client, true);
}

public void TrimAndReplace(const char[] weaponName, char[] result, int resultSize)
{
    strcopy(result, resultSize, weaponName);

    if (StrContains(result, "weapon_") == 0)
        strcopy(result, resultSize, result[7]);

    ReplaceString(result, resultSize, "_", " ");
}

public Action BroadcastMessage(Handle timer)
{
    if (!g_cvarEnabled.BoolValue || !g_cvarBroadcast.BoolValue)
        return Plugin_Continue;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i))
            PrintToChat(i, "[NeoTokyo Weapon Menu] Use !weapon to open the weapon selection menu.");
    }

    return Plugin_Continue;
}