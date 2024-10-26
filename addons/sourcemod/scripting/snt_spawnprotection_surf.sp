#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <tf2>
#include <tf2_stocks>
#include <tf2items>

#include <morecolors>
#tryinclude <goomba>

#undef REQUIRE_PLUGIN
#include <sntdb/core>

#define PREFIX "{greenyellow}[{grey}SNT{greenyellow}]{default}"

public Plugin myinfo =
{
    name = "SNT Spawn Protection (Surf)",
    author = "Arcala the Gyiyg",
    description = "Adds spawn protection, with an option to disable it on the weekends automatically.",
    version = "1.0.0",
    url = "https://github.com/ArcalaAlien/snt_utils"
};

bool isEnabled;
bool clientEnabled[MAXPLAYERS + 1];
bool isActive[MAXPLAYERS + 1];
bool isSkurfMap;
bool currentlyWeekend = false;

ConVar isEnabledConVar;
ConVar mapTypeConVar;
ConVar isWeekendConVar;

Handle spEnabledPref;

Handle notifyProtectionOff = INVALID_HANDLE;
Handle notifySkurfMap = INVALID_HANDLE;

bool lateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    lateLoad = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    HookEvent("player_spawn", OnPlayerSpawn);
    HookEvent("teamplay_round_win", OnRoundEnd);

    isEnabledConVar = CreateConVar("snt_sp_enabled", "1.0", "Enable / disable spawn protection", 0, true, 0.0, true, 1.0);
    mapTypeConVar = FindConVar("snt_map_type");
    isWeekendConVar = FindConVar("snt_is_weekend");

    HookConVarChange(isEnabledConVar, CVC_ToggleSpawnProtection); 
    HookConVarChange(mapTypeConVar, CVC_SetAsSkurfMap);
    HookConVarChange(isWeekendConVar, CVC_UpdateWeekend);

    spEnabledPref = RegClientCookie("snt_sp_autoenable", "Whether spawn protection will be autoenabled for the player on a skill surf map.", CookieAccess_Public);

    if (lateLoad)
    {
        for (int i = 1; i < MaxClients; i++)
            OnClientPutInServer(i);
        
        OnMapStart();
    }


    RegConsoleCmd("sm_sp", USR_ToggleSP, "Usage: /sp (only on skill surf maps!)");
}

public void OnMapStart()
{
    if (mapTypeConVar.IntValue == 1)
        isSkurfMap = true;
    else
        isSkurfMap = false;

    currentlyWeekend = SNT_CheckForWeekend();

    if (currentlyWeekend)
        isEnabledConVar.SetBool(false, true);

    ToggleSP();
}

public void OnMapEnd()
{
    if (notifyProtectionOff != INVALID_HANDLE)
    {
        KillTimer(notifyProtectionOff);
        notifyProtectionOff = INVALID_HANDLE;
    }

    if (notifySkurfMap != INVALID_HANDLE)
    {
        KillTimer(notifySkurfMap);
        notifySkurfMap = INVALID_HANDLE;
    }
}

public void OnClientPutInServer(int client)
{
    if (SNT_IsValidClient(client))
    {
        SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
        if (AreClientCookiesCached(client))
        {
            char cookieSetting[8];
            GetClientCookie(client, spEnabledPref, cookieSetting, sizeof(cookieSetting));
            if (cookieSetting[0] == '\0')
            {
                SetClientCookie(client, spEnabledPref, "true");
                clientEnabled[client] = true;
            }
            else if (StrEqual(cookieSetting, "false"))
                clientEnabled[client] = false;
            else
                clientEnabled[client] = true;
        }
    }
}

public void OnClientDisconnect(int client)
{
    if (SNT_IsValidClient(client))
    {
        clientEnabled[client] = true;
        SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
    }
}

public Action OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
    if (isSkurfMap)
    {
        if (victim == attacker)
            return Plugin_Continue;

        if (clientEnabled[victim] || clientEnabled[attacker])
            return Plugin_Handled;
    }

    return Plugin_Continue;
}

public Action OnStomp(int attacker, int victim, float& damageMultiplier, float& damageBonus, float& JumpPower)
{
    if (isSkurfMap)
        if (clientEnabled[victim] || clientEnabled[attacker])
            return Plugin_Handled;

    return Plugin_Continue;
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));

    if (SNT_IsValidClient(client))
    {
        if (isEnabled)
        // if Plugin is enabled, create a timer to add uber to a player.
            CreateTimer(0.1, AddUberToPlayer_Timer, client);
    }
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    if (!currentlyWeekend)
    {
        SetConVarInt(isEnabledConVar, 0);
        CPrintToChatAll("%s END OF ROUND! {fullred}DISABLING SPAWN PROTECTION!", PREFIX);
    }
}

public void CVC_UpdateWeekend(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (StrEqual(newValue, "true"))
    {
        currentlyWeekend = true;
        isEnabledConVar.SetInt(0, true);
    }
    else
    {
        currentlyWeekend = false;
        isEnabledConVar.SetInt(1, true);
    }

}

public void CVC_ToggleSpawnProtection(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (!isSkurfMap)
    {
        int mode = StringToInt(newValue);
        if (mode == 0)
            isEnabled = false;
        else
            isEnabled = true;
    }
    else
        isEnabled = true;
}

public void CVC_SetAsSkurfMap(ConVar convar, const char[] oldValue, const char[] newValue)
{
    int mode = StringToInt(newValue);
    if (mode != 1)
        isSkurfMap = false;
    else
        isSkurfMap = true;
}

void ToggleSP()
{
    if (FindConVar("snt_sp_enabled") != null)
    {
        if (currentlyWeekend && !isSkurfMap)
            SetConVarBool(isEnabledConVar, false);
        else
            SetConVarBool(isEnabledConVar, true);

        if (isSkurfMap && notifySkurfMap == INVALID_HANDLE)
        {
            notifySkurfMap = CreateTimer(360.0, NotifySkurfMap_Timer, 0, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
            return;
        }

        if (!isEnabled && notifyProtectionOff == INVALID_HANDLE)
        {
            notifyProtectionOff = CreateTimer(360.0, NotifySPDisabled_Timer, 0, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
            return;        
        }
    }
}

public Action AddUberToPlayer_Timer(Handle timer, any client)
{
    if (SNT_IsValidClient(client))
    {
        if (isSkurfMap)
            if (clientEnabled[client])
            {
                isActive[client] = true;
                SetEntityRenderColor(client, 155, 255, 155, 50);
                SetEntityCollisionGroup(client, 2);
                TF2_AddCondition(client, TFCond_UberchargedHidden);
            }
            else
            {
                SetEntityCollisionGroup(client, 5);
                isActive[client] = false;
                SetEntityRenderColor(client, 255, 255, 255, 255);
                return Plugin_Handled;
            }
        else
        {
            SetEntityRenderColor(client, 155, 255, 155, 50);
            TF2_AddCondition(client, TFCond_UberchargedHidden, 5.0);
            CreateTimer(5.0, RenderClientNormally_Timer, client);
        }

    }
    return Plugin_Handled;
}

public void RenderClientNormally_Timer(Handle timer, any client)
{
    if (SNT_IsValidClient(client))
        SetEntityRenderColor(client, 255, 255, 255, 255);
}

public Action NotifySPDisabled_Timer(Handle timer)
{
    if (!isSkurfMap && !isEnabled)
    {
        if (!currentlyWeekend)
            CPrintToChatAll("%s {orange}SPAWN PROTECTION IS DISABLED! POINTS HAVE BEEN LOWERED!", PREFIX);
        else
            CPrintToChatAll("%s {orange}Spawn Protection is disabled on weekends! Points will be lowered!", PREFIX);
    }

    return Plugin_Handled;
}

public Action NotifySkurfMap_Timer(Handle timer)
{
    CPrintToChatAll("%s Spawn Protection is permanent on skill surf maps. Use {greenyellow}/sp{default} to toggle it!", PREFIX);
    return Plugin_Handled;
}

public Action USR_ToggleSP(int client, int args)
{
    if (client == 0)
        return Plugin_Handled;

    if (isSkurfMap)
    {
        clientEnabled[client] = !clientEnabled[client]
        if (clientEnabled[client])
        {
            CPrintToChat(client, "%s You have {greenyellow}enabled{default} spawn protection!", PREFIX);
            SetEntityRenderColor(client, 255, 255, 255, 50);
            TF2_AddCondition(client, TFCond_UberchargedHidden);
            TF2_RespawnPlayer(client);
            SetClientCookie(client, spEnabledPref, "true");
        }

        else
        {
            CPrintToChat(client, "%s You have {fullred}disabled{default} spawn protection!", PREFIX);
            SetEntityRenderColor(client, 255, 255, 255, 255);
            TF2_RemoveCondition(client, TFCond_UberchargedHidden);
            SetClientCookie(client, spEnabledPref, "false");
        }

        return Plugin_Handled;
    }
    else
    {
        CPrintToChat(client, "%s {fullred}You can only toggle spawn protection on skill surf maps! Use the {greenyellow}/votemenu {fullred}to disable spawn protection on a combat surf map.", PREFIX);
        return Plugin_Handled;
    }
}