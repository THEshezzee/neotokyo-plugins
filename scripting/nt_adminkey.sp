#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
    name = "Admin by Key",
    description = "Allows players to become persistent admins by entering a specific key and adds them to admins_simple.ini",
    version = "1.0"
};

ConVar g_cvarAdminKey;

public void OnPluginStart()
{
    g_cvarAdminKey = CreateConVar("sm_admin_key", "", "The key required to become a persistent admin.", FCVAR_PROTECTED);
    
    RegConsoleCmd("sm_admin", Command_Admin, "Add persistent admin rights with a key.");
    LoadTranslations("common.phrases");
}

public Action Command_Admin(int client, int args)
{
    if (args != 1)
    {
        PrintToConsole(client, "[SM] Usage: !admin <key>");
        return Plugin_Handled;
    }

    char arg1[64];
    GetCmdArg(1, arg1, sizeof(arg1));
    
    char adminKey[64];
    g_cvarAdminKey.GetString(adminKey, sizeof(adminKey));

    if (StrEqual(arg1, adminKey, false))
    {
        char authID[64];
        if (!GetClientAuthId(client, AuthId_Steam2, authID, sizeof(authID)))
        {
            PrintToConsole(client, "[SM] Unable to retrieve your Steam ID.");
            return Plugin_Handled;
        }

        AdminId admin = FindAdminByIdentity("steam", authID);
        if (admin == INVALID_ADMIN_ID)
        {
            admin = CreateAdmin(authID);
            if (admin == INVALID_ADMIN_ID)
            {
                PrintToConsole(client, "[SM] Failed to create admin ID.");
                return Plugin_Handled;
            }
            admin.SetFlag(Admin_Root, true);
            admin.BindIdentity("steam", authID);

            if (!AddToAdminsFile(authID, "z"))
            {
                PrintToConsole(client, "[SM] Failed to add you to the admins_simple.ini file.");
            }
        }
        else
        {
            admin.SetFlag(Admin_Root, true);
        }
        
        SetUserAdmin(client, admin, true);

        PrintToConsole(client, "[SM] You have been granted persistent admin rights.");
        PrintToChat(client, "[SM] You have been granted persistent admin rights.");
        
        LogToGame("\"%L\" (%s) successfully authenticated with admin key.", client, authID);
    }
    else
    {
        PrintToConsole(client, "[SM] Invalid key.");
        LogToGame("\"%L\" failed to authenticate with admin key.", client);
    }

    return Plugin_Handled;
}

bool AddToAdminsFile(const char[] auth, const char[] flags)
{
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/admins_simple.ini");
    
    File file = OpenFile(path, "a");
    if (file == null)
    {
        LogError("Could not open admins_simple.ini for appending.");
        return false;
    }

    file.WriteLine("\"%s\" \"%s\"", auth, flags);
    delete file;
    return true;
}