#include <sourcemod>
#include <morecolors>

#define PREFIX "{greenyellow}[{grey}SNT{greenyellow}]{default}"

bool g_bIsEnabled[MAXPLAYERS+1] = { true, ... };
bool g_bIsPlayerAlive[MAXPLAYERS+1];
Handle g_hSpeedometerTimer[MAXPLAYERS+1];
Handle g_hMessageHandles[MAXPLAYERS+1];

public Plugin:myinfo =
{
	name = "Speedometer",
	author = "Arcala the Gyiyg",
	description = "Plugin that shows a player's speed.",
	version = "1.0.0",
	url = "N/A"
}

public void OnPluginStart()
{
    LoadTranslations("common.phrases");
    LoadTranslations("sm_speedometer.phrases");
    RegConsoleCmd("sm_speedometer", ToggleSpeedometer, "Toggles the Speedometer On or Off");
    RegConsoleCmd("sm_speedo", ToggleSpeedometer);
    RegConsoleCmd("sm_speed", ToggleSpeedometer);
    RegAdminCmd("sm_speedostart", StartSpeedo, ADMFLAG_ROOT);
    HookEvent("player_death", Event_OnPlayerDeath);
    HookEvent("post_inventory_application", Event_OnPlayerSpawn);
    HookEvent("player_team", Event_OnPlayerTeam);
}

public void OnClientDisconnect(int client)
{
    if (IsClientInGame(client) && IsClientConnected(client) && !IsFakeClient(client))
    {
        g_bIsEnabled[client] = true;
        if (g_hSpeedometerTimer[client] != INVALID_HANDLE)
        {
            g_hSpeedometerTimer[client] = INVALID_HANDLE;
            KillTimer(g_hSpeedometerTimer[client]);
        }
        if (g_hMessageHandles[client] != INVALID_HANDLE)
        {
            CloseHandle(g_hMessageHandles[client]);
            g_hMessageHandles[client] = INVALID_HANDLE;
        }
    }
}

bool isValidClient(int client)
{
    if (!IsClientInGame(client) || !IsClientConnected(client) || IsFakeClient(client))
        return false;
    else if (IsClientInGame(client) && IsClientConnected(client) && !IsFakeClient(client))
        return true;
    else
        return false;
}

public Action Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    g_bIsPlayerAlive[client] = false;
    if (g_bIsEnabled[client] && g_hSpeedometerTimer[client] != INVALID_HANDLE)
    {
        KillTimer(g_hSpeedometerTimer[client]);
        g_hSpeedometerTimer[client] = INVALID_HANDLE;
    }
    return Plugin_Continue;
}


public Action Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (g_bIsEnabled[client] && g_hSpeedometerTimer[client] == INVALID_HANDLE)
    {
        g_bIsPlayerAlive[client] = true;
        g_hSpeedometerTimer[client] = CreateTimer(0.1, Speedometer_Timer, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    }
    return Plugin_Continue;
}

public Action Event_OnPlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    g_bIsPlayerAlive[client] = false;
    if (g_bIsEnabled[client] && g_hSpeedometerTimer[client] != INVALID_HANDLE)
    {
        KillTimer(g_hSpeedometerTimer[client]);
        g_hSpeedometerTimer[client] = INVALID_HANDLE;
    }
    return Plugin_Continue;
}

public Action Speedometer_Timer(Handle timer, any client)
{
    if (!g_bIsPlayerAlive[client] || !g_bIsEnabled[client] || !IsClientConnected(client))
    {
        return Plugin_Stop;
    }
    // Thanks to TheTwistedPanda for this code:
    float _fTemp[3];
    float _fVelocity;
    //get proper vector and calculate velocity
    GetEntPropVector(client, Prop_Data, "m_vecVelocity", _fTemp);
    for(new i = 0; i <= 2; i++)
    {
        _fTemp[i] *= _fTemp[i];
    }
    _fVelocity = SquareRoot(_fTemp[0] + _fTemp[1] + _fTemp[2]);
    
    //display the speed
    char sBuffer[64];
    Format(sBuffer, sizeof(sBuffer), "Current Speed: %.0f", _fVelocity);
    g_hMessageHandles[client] = StartMessageOne("KeyHintText", client);
    if (g_hMessageHandles[client] != INVALID_HANDLE)
    {
        BfWriteByte(g_hMessageHandles[client], 1); 
        BfWriteString(g_hMessageHandles[client], sBuffer); 
        EndMessage();
    }
    else
        PrintToServer("Message failed to seend to client: %i", client);

    return Plugin_Continue;
}

public Action ToggleSpeedometer(int client, int args)
{
    if (args > 0) {
        CReplyToCommand(client, "%S Usage: /speedometer, /speedo, /speed", PREFIX)
        return Plugin_Handled;
    }
    
    g_bIsEnabled[client] = !g_bIsEnabled[client];
    if (g_bIsEnabled[client] && g_bIsPlayerAlive[client]) 
    {
        g_hSpeedometerTimer[client] = CreateTimer(0.1, Speedometer_Timer, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
        if (g_hSpeedometerTimer[client])
            CReplyToCommand(client, "%s The speedometer has been enabled", PREFIX);
        else
            CReplyToCommand(client, "%s Oops! The timer couldn't start for some reason.", PREFIX);
    }
    else if (!g_bIsEnabled[client]) 
    {
        if (g_hSpeedometerTimer[client] != INVALID_HANDLE)
        {
            KillTimer(g_hSpeedometerTimer[client]);
            g_hSpeedometerTimer[client] = INVALID_HANDLE;
            CReplyToCommand(client, "%s The speedometer has been disabled", PREFIX);
        }
        else
            CReplyToCommand(client, "%s Oops! There was no timer to stop.", PREFIX);
    }
    return Plugin_Handled;
}

public Action StartSpeedo(int client, int args)
{
    for (int i = 1; i <= GetClientCount(); i++)
    {
        if (isValidClient(i) && g_bIsPlayerAlive[i] && g_hSpeedometerTimer[client] == INVALID_HANDLE && g_hMessageHandles[client] == INVALID_HANDLE)
        {
            g_hSpeedometerTimer[i] = CreateTimer(0.1, Speedometer_Timer, i, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
            CReplyToCommand(client, "%s Enabled speedometer for client: %i", PREFIX, i);
        }
    }
    return Plugin_Handled;
}