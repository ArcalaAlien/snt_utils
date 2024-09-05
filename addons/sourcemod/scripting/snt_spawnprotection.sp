#include <sourcemod>
#include <tf2>
#include <sntdb_core>
#include <morecolors>

#define PREFIX "{greenyellow}[{grey}SNT{greenyellow}]{default}"

public Plugin myinfo =
{
    name = "SNT Spawn Protection",
    author = "Arcala the Gyiyg",
    description = "Adds spawn protection, with an option to disable it on the weekends automatically.",
    version = "1.0.0",
    url = "https://github.com/ArcalaAlien/snt_utils"
};

bool isEnabled;
bool currentlyWeekend = false;
//bool enabledLastWeekend = false;

ConVar isEnabledConVar;

Handle notifyProtectionOff;

public void OnPluginStart()
{
    HookEvent("player_spawn", OnPlayerSpawn);
    HookEvent("teamplay_round_win", OnRoundEnd);

    isEnabledConVar = CreateConVar("snt_sp_enabled", "1.0", "Enable / disable spawn protection", 0, true, 0.0, true, 1.0);
    HookConVarChange(isEnabledConVar, CVC_ToggleSpawnProtection); 

    ToggleSP();
}

public void OnMapStart()
{
    ToggleSP();
}

public void OnMapEnd()
{
    if (notifyProtectionOff != INVALID_HANDLE)
        KillTimer(notifyProtectionOff);
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int uid = GetEventInt(event, "userid");
    int client = GetClientOfUserId(uid);

    if (isEnabled)
        CreateTimer(0.1, AddUberToPlayer_Timer, client);
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    if (!CheckForWeekend())
    {
        SetConVarInt(isEnabledConVar, 0);
        CPrintToChatAll("%s END OF ROUND! {fullred}DISABLING SPAWN PROTECTION!", PREFIX);
    }
}

public void CVC_ToggleSpawnProtection (ConVar convar, const char[] oldValue, const char[] newValue)
{
    int mode = StringToInt(newValue);
    if (mode == 0)
    {
        isEnabled = false;
    }
    else
    {
        isEnabled = true;
    }
}

void ToggleSP()
{
    if (FindConVar("snt_sp_enabled") != null)
    {
        currentlyWeekend = CheckForWeekend();
        if (currentlyWeekend)
        {
            SetConVarInt(isEnabledConVar, 0);
            //enabledLastWeekend = true;
        }
        else if (!currentlyWeekend)
        {
            SetConVarInt(isEnabledConVar, 1);
            //enabledLastWeekend = false;
        }

        if (isEnabledConVar.IntValue == 0)
        {
            isEnabled = false;
            if (notifyProtectionOff == INVALID_HANDLE)
                notifyProtectionOff = CreateTimer(360.0, NotifySPDisabled_Timer, 0, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
        }
        else
            isEnabled = true;
    }
}

public Action AddUberToPlayer_Timer(Handle timer, any client)
{
    if (IsClientConnected(client) && IsClientInGame(client))
        TF2_AddCondition(client, TFCond_UberchargedCanteen, 5.0);
    return Plugin_Handled;
}

public Action NotifySPDisabled_Timer(Handle timer)
{
    if (!currentlyWeekend)
        CPrintToChatAll("%s {orange}SPAWN PROTECTION IS DISABLED!!", PREFIX);
    else
        CPrintToChatAll("%s {orange}Spawn Protection is disabled on weekends!", PREFIX);
    return Plugin_Handled;
}