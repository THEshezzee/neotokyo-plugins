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
    
    AddCommandListener(Command_Say, "say");
    AddCommandListener(Command_Say, "say_team");
}

public Action Command_Say(int client, const char[] command, int argc)
{
    char text[192];
    GetCmdArgString(text, sizeof(text));
    
    // Remove quotes
    StripQuotes(text);
    
    // Check if the message starts with !admin
    if (strncmp(text, "!admin", 6, false) == 0)
    {
        return Plugin_Stop; // Block the message from being displayed
    }
    
    return Plugin_Continue;
}

public Action Command_Admin(int client, int args)
{
    if (args != 1)
    {
        ReplyToCommand(client, "[SM] Usage: !admin <key>");
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
            ReplyToCommand(client, "[SM] Unable to retrieve your Steam ID.");
            return Plugin_Handled;
        }

        AdminId admin = FindAdminByIdentity("steam", authID);
        if (admin == INVALID_ADMIN_ID)
        {
            admin = CreateAdmin(authID);
            if (admin == INVALID_ADMIN_ID)
            {
                ReplyToCommand(client, "[SM] Failed to create admin ID.");
                return Plugin_Handled;
            }
            admin.SetFlag(Admin_Root, true);
            admin.BindIdentity("steam", authID);
            
            if (!AddToAdminsFile(authID, "z"))
            {
                ReplyToCommand(client, "[SM] Failed to add you to the admins_simple.ini file.");
            }
        }
        else
        {
            admin.SetFlag(Admin_Root, true);
        }
        
        SetUserAdmin(client, admin, true);
        ReplyToCommand(client, "[SM] You have been granted persistent admin rights.");
        PrintToChat(client, "[SM] You have been granted persistent admin rights.");
        
        LogToGame("\"%L\" (%s) successfully authenticated with admin key.", client, authID);
    }
    else
    {
        ReplyToCommand(client, "[SM] Invalid key.");
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