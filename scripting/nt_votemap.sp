#include <sourcemod>
#include <sdktools>
#include <neotokyo>

public Plugin myinfo = 
{
    name = "NeoTokyo Next Map Vote",
    description = "Starts a vote for next map when the game is near its end"
};

#define VOTE_DELAY 5.0  // Delay before starting the vote after conditions are met
#define CHECK_INTERVAL 1.0  // Check every second

Handle g_mapCycleCvar = null;
ArrayList g_mapListArray = null;
int g_mapCount = 0;
int g_lastJinraiScore = 0;
int g_lastNsfScore = 0;
bool g_isCheckingForVote = false;
bool g_voteCompleted = false;

// Custom logging functions
stock void LogErrorToChat(const char[] message, any ...)
{
    char buffer[256];
    VFormat(buffer, sizeof(buffer), message, 2);
    PrintToChatAll(buffer);
}

stock void LogMessageToChat(const char[] message, any ...)
{
    char buffer[256];
    VFormat(buffer, sizeof(buffer), message, 2);
    PrintToChatAll(buffer);
}

public void OnPluginStart()
{
    RegConsoleCmd("sm_dumpvars", Cmd_DumpVars, "Dump variables from this plugin to console");
    
    // Initialize map cycle ConVar
    g_mapCycleCvar = FindConVar("mapcyclefile");
    if (g_mapCycleCvar == null)
    {
        LogErrorToChat("[SM] Could not find 'mapcyclefile' ConVar.");
        return;
    }

    // Initialize map list array
    g_mapListArray = new ArrayList(PLATFORM_MAX_PATH);
    if (ReadMapList(g_mapListArray, g_mapCycleCvar, "default", MAPLIST_FLAG_CLEARARRAY) == INVALID_HANDLE)
    {
        LogErrorToChat("[SM] Failed to read map list.");
        delete g_mapListArray;
        g_mapListArray = null;
    }
    else
    {
        g_mapCount = g_mapListArray.Length;
        LogMessageToChat("[SM] Map list initialized with %d maps.", g_mapCount);
    }

    // Start checking scores
    CreateTimer(CHECK_INTERVAL, Timer_CheckScores, _, TIMER_REPEAT);

    // Reset vote completion on map change
    HookEvent("round_end", Event_RoundEnd);
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
        g_voteCompleted = false; // Reset vote completion flag when the map changes
}

public Action Timer_CheckScores(Handle timer)
{
    if (g_voteCompleted) return Plugin_Continue; // Don't start another vote if one has already completed

    int jinraiScore = GetTeamScore(TEAM_JINRAI);
    int nsfScore = GetTeamScore(TEAM_NSF);

    // Check if scores have changed
    if (jinraiScore != g_lastJinraiScore || nsfScore != g_lastNsfScore)
    {
        g_lastJinraiScore = jinraiScore;
        g_lastNsfScore = nsfScore;
        LogMessageToChat("[SM] Score changed. Checking vote conditions.");

        if (!g_isCheckingForVote)
        {
            g_isCheckingForVote = true;
            CreateTimer(CHECK_INTERVAL, Timer_CheckVoteConditions, _, TIMER_REPEAT);
        }
    }

    return Plugin_Continue;
}

public Action Timer_CheckVoteConditions(Handle timer)
{
    Handle scoreLimitCvar = FindConVar("neo_score_limit");
    if (scoreLimitCvar == null)
    {
        LogErrorToChat("[SM] Could not find 'neo_score_limit' ConVar.");
        g_isCheckingForVote = false;
        return Plugin_Stop;
    }

    int scoreLimit = GetConVarInt(scoreLimitCvar);
    int jinraiScore = GetTeamScore(TEAM_JINRAI);
    int nsfScore = GetTeamScore(TEAM_NSF);

    LogMessageToChat("[SM] Checking vote conditions: Jinrai %d, NSF %d, Limit %d", jinraiScore, nsfScore, scoreLimit);

    // Check if either team is within 2 points of winning
    if (jinraiScore >= (scoreLimit - 2) || nsfScore >= (scoreLimit - 2))
    {
        if (g_mapListArray != null && g_mapCount > 0)
        {
            CreateTimer(VOTE_DELAY, Timer_StartVote);
            LogMessageToChat("[SM] Vote for next map will start soon.");
            g_isCheckingForVote = false;
            return Plugin_Stop;
        }
        else
        {
            LogErrorToChat("[SM] Cannot start vote, no valid map list.");
        }
    }

    // Continue checking if conditions are not met
    return Plugin_Continue;
}

public Action Timer_StartVote(Handle timer)
{
    if (IsVoteInProgress())
    {
        LogMessageToChat("[SM] A vote is already in progress.");
        return Plugin_Handled;
    }

    if (g_mapListArray == null || g_mapCount == 0)
    {
        LogErrorToChat("[SM] No maps available for voting.");
        return Plugin_Handled;
    }

    Menu menu = new Menu(Handler_VoteCallback, MENU_ACTIONS_ALL);
    menu.SetTitle("Vote for Next Map");
    
    char mapName[PLATFORM_MAX_PATH];
    for (int i = 0; i < g_mapCount && i < 5; ++i) // Limit to 5 maps
    {
        g_mapListArray.GetString(i, mapName, sizeof(mapName));
        menu.AddItem(mapName, mapName);
    }
    // Add a blank item for separation
    menu.AddItem("", "");
    // Add "Keep Current Map" option
    menu.AddItem("", "Keep Current Map"); // An empty string for map name to keep current map
    
    menu.ExitButton = false;
    menu.DisplayVoteToAll(20);

    return Plugin_Continue;
}

public int Handler_VoteCallback(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_End:
        {
            delete menu;
        }
        case MenuAction_VoteEnd:
        {
            char map[PLATFORM_MAX_PATH];
            menu.GetItem(param1, map, sizeof(map));
            
            if (StrEqual(map, ""))
            {
                PrintToChatAll("[SM] Players chose to keep the current map!");
                // Keep current map, do nothing for setting next map
            }
            else
            {
                PrintToChatAll("[SM] %s was chosen for the next map!", map);
                SetNextMap(map);
            }
            g_voteCompleted = true; // Set flag to true once a vote completes
        }
    }
    return 0;
}

public Action Cmd_DumpVars(int client, int args)
{
    Handle scoreLimitCvar = FindConVar("neo_score_limit");
    if (scoreLimitCvar == null)
    {
        ReplyToCommand(client, "Error: neo_score_limit not found");
        return Plugin_Handled;
    }

    int scoreLimit = GetConVarInt(scoreLimitCvar);
    int jinraiScore = GetTeamScore(TEAM_JINRAI);
    int nsfScore = GetTeamScore(TEAM_NSF);

    ReplyToCommand(client, "Variables Dump:");
    ReplyToCommand(client, "neo_score_limit: %d", scoreLimit);
    ReplyToCommand(client, "Jinrai Score: %d", jinraiScore);
    ReplyToCommand(client, "NSF Score: %d", nsfScore);
    ReplyToCommand(client, "Is Vote In Progress: %s", IsVoteInProgress() ? "true" : "false");
    ReplyToCommand(client, "mapCycleCvar: %s", g_mapCycleCvar != null ? "Valid" : "Invalid");
    ReplyToCommand(client, "mapListArray: %s", g_mapListArray != null ? "Initialized" : "Not Initialized");
    ReplyToCommand(client, "mapCount: %d", g_mapCount);

    return Plugin_Handled;
}