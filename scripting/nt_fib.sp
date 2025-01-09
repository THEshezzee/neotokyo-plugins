#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
    name = "Fibonacci Calculator",
    description = "Calculates large Fibonacci numbers",
    version = "2.3"
};

#define MAXDIGIT 5000
#define TIMEOUT_SECONDS 10.0


int Q[MAXDIGIT];
int clientRequest[MAXPLAYERS + 1];
int fibRequest[MAXPLAYERS + 1];
float startTime[MAXPLAYERS + 1];
Handle hTimeoutTimer[MAXPLAYERS + 1];

void Add(int n[MAXDIGIT], int p[MAXDIGIT], int c[MAXDIGIT], int &max)
{
    for (int i = 0; i < MAXDIGIT; i++)
    {
        Q[i] = 0;
    }

    for (int i = 0; i <= max; i++)
    {
        n[i] = p[i] + c[i] + Q[i];
        if (n[i] > 9)
        {
            if (i == max)
            {
                max++;
            }
            Q[i+1] = n[i] / 10;
            n[i] = n[i] % 10;
        }
    }
}

void ShowResult(int client, const int x[MAXDIGIT], int max, bool timedOut = false)
{
    char result[1024] = "";
    for (int j = max; j >= 0; j--)
    {
        Format(result, sizeof(result), "%s%d", result, x[j]);
    }

    if (strlen(result) > 100)
    {
        result[10] = '\0';
        StrCat(result, sizeof(result), "...");
    }

    float endTime = GetEngineTime();
    float cpuTime = endTime - startTime[client];

    if (timedOut)
    {
        if (client == 0)
        {
            PrintToServer("[SM] Fibonacci calculation timed out.");
        }
        else
        {
            PrintToChat(client, "[SM] Fibonacci calculation timed out.");
        }
    }
    else if (client == 0)
    {
        PrintToServer("[SM] Fibonacci Result: %s (CPU Time: %.6f seconds)", result, cpuTime);
    }
    else
    {
        PrintToChat(client, "[SM] Fibonacci Result: %s (CPU Time: %.6f seconds)", result, cpuTime);
    }

    if (hTimeoutTimer[client] != INVALID_HANDLE)
    {
        KillTimer(hTimeoutTimer[client]);
        hTimeoutTimer[client] = INVALID_HANDLE;
    }
}

public void OnPluginStart()
{
    RegConsoleCmd("sm_fib", Command_Fib, "Calculate Fibonacci number for given index");
    for (int i = 0; i <= MaxClients; i++)
    {
        clientRequest[i] = -1;
        fibRequest[i] = -1;
        startTime[i] = 0.0;
        hTimeoutTimer[i] = INVALID_HANDLE;
    }
}

public Action Command_Fib(int client, int args)
{
    if (args < 1)
    {
        if (client == 0)
        {
            PrintToServer("[SM] Usage: !fib <number>");
        }
        else
        {
            ReplyToCommand(client, "[SM] Usage: !fib <number>");
        }
        return Plugin_Handled;
    }

    char arg[32];
    GetCmdArg(1, arg, sizeof(arg));
    int n = StringToInt(arg);

    if (n < 0)
    {
        if (client == 0)
        {
            PrintToServer("[SM] Please provide a non-negative number.");
        }
        else
        {
            ReplyToCommand(client, "[SM] Please provide a non-negative number.");
        }
        return Plugin_Handled;
    }

    clientRequest[client] = client;
    fibRequest[client] = n;
    startTime[client] = GetEngineTime();
    hTimeoutTimer[client] = CreateTimer(TIMEOUT_SECONDS, Timer_Timeout, client);
    CreateTimer(0.1, Timer_CalcFib, client);

    return Plugin_Handled;
}

public Action Timer_CalcFib(Handle timer, int client)
{
    if (!IsClientInGame(client) || clientRequest[client] != client)
    {
        return Plugin_Stop;
    }

    int n = fibRequest[client];
    int prev[MAXDIGIT], curr[MAXDIGIT], next[MAXDIGIT];
    int max = 0;

    for(int j = 0; j < MAXDIGIT; j++)
    {
        prev[j] = curr[j] = next[j] = 0;
    }

    prev[0] = 0; curr[0] = 1;

    for (int i = 2; i <= n; i++)
    {
        Add(next, prev, curr, max);

        for (int j = 0; j < MAXDIGIT; j++)
        {
            prev[j] = curr[j];
            curr[j] = next[j];
            next[j] = 0;
        }

        if (hTimeoutTimer[client] == INVALID_HANDLE)
        {
            ShowResult(client, curr, max, true);
            return Plugin_Stop;
        }

        if (i % 100 == 0)
        {
            PrintToChat(client, "[SM] Calculating Fibonacci... Progress: %d/%d", i, n);
        }
    }

    ShowResult(client, curr, max);

    clientRequest[client] = -1;
    fibRequest[client] = -1;
    startTime[client] = 0.0;

    return Plugin_Stop;
}

public Action Timer_Timeout(Handle timer, int client)
{
    if (clientRequest[client] == client)
    {
        int dummyResult[MAXDIGIT];
        for (int i = 0; i < MAXDIGIT; i++)
        {
            dummyResult[i] = 0;
        }
        ShowResult(client, dummyResult, 0, true);
        clientRequest[client] = -1;
        fibRequest[client] = -1;
    }
    hTimeoutTimer[client] = INVALID_HANDLE;
    return Plugin_Stop;
}