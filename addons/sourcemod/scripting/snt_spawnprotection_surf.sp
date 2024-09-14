#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <sntdb_core>
#include <morecolors>
#tryinclude <goomba>

#define PREFIX "{greenyellow}[{grey}SNT{greenyellow}]{default}"

public Plugin myinfo =
{
    name = "SNT Spawn Protection (Surf)",
    author = "Arcala the Gyiyg",
    description = "Adds spawn protection, with an option to disable it on the weekends automatically.",
    version = "1.0.0",
    url = "https://github.com/ArcalaAlien/snt_utils"
};

bool isEnabled = false;
bool clientEnabled[MAXPLAYERS + 1];
bool isSkurfMap;
bool currentlyWeekend = false;

ConVar isEnabledConVar;
ConVar isSkillSurfConVar;

Handle notifyProtectionOff = INVALID_HANDLE;
Handle notifySkurfMap = INVALID_HANDLE;
File skurfMapList;

int collisionGroupOffset;

public void OnPluginStart()
{

    collisionGroupOffset = FindSendPropInfo("CBaseEntity", "m_CollisionGroup");
    HookEvent("player_spawn", OnPlayerSpawn);
    HookEvent("teamplay_round_win", OnRoundEnd);

    isEnabledConVar = CreateConVar("snt_sp_enabled", "1.0", "Enable / disable spawn protection", 0, true, 0.0, true, 1.0);
    isSkillSurfConVar = CreateConVar("snt_sp_is_skurf", "0.0", "Change spawnprotection modes between skill-surf and combat surf.", 0, true, 0.0, true, 1.0);

    HookConVarChange(isEnabledConVar, CVC_ToggleSpawnProtection); 
    HookConVarChange(isSkillSurfConVar, CVC_SetAsSkurfMap);

    for (int i = 1; i < MaxClients; i++)
    {
        OnClientPutInServer(i);
    }

    ToggleSP();
    RegConsoleCmd("sm_sp", USR_ToggleSP, "Usage: /sp (only on skill surf maps!)");
}

public void OnMapStart()
{
    char skurfFilePath[256];
    Format(skurfFilePath, sizeof(skurfFilePath), "cfg/skurf_mapcycle.txt");

    if (FileExists(skurfFilePath))
        skurfMapList = OpenFile(skurfFilePath, "r");
    else
        ThrowError("[SNT_SpawnProtection]: cfg/skurf_mapcycle.txt doesn't exist!");

    CheckIfSkurfMap();
    delete skurfMapList;

    if (isSkillSurfConVar.IntValue == 0)
        isSkurfMap = false;
    else
        isSkurfMap = true;

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
    if (IsClientInGame(client) && IsClientConnected(client))
        SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
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
        // Enable No Block on skill surf maps.
        if (isSkurfMap)
        {
            if (collisionGroupOffset != -1 || collisionGroupOffset != 0)
            {
                SetEntData(client, collisionGroupOffset, 2, 4, true);
            }
        }
        // if Plugin is enabled, create a timer to add uber to a player.
        if (isEnabled)
            CreateTimer(0.1, AddUberToPlayer_Timer, client);
    }
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    if (!CheckForWeekend())
    {
        SetConVarInt(isEnabledConVar, 0);
        CPrintToChatAll("%s END OF ROUND! {fullred}DISABLING SPAWN PROTECTION!", PREFIX);
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
    if (mode == 0)
        isSkurfMap = false;
    else
        isSkurfMap = true;
}

void CheckIfSkurfMap()
{
    if (FindConVar("snt_sp_is_skurf") != null)
    {
        char currentLine[64];
        char currentMap[64];
        GetCurrentMap(currentMap, sizeof(currentMap));

        while (ReadFileLine(skurfMapList, currentLine, sizeof(currentLine)))
        {
            TrimString(currentLine);
            if (StrEqual(currentMap, currentLine))
            {
                notifySkurfMap = CreateTimer(360.0, NotifySkurfMap_Timer, 0, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
                SetConVarInt(isSkillSurfConVar, 1);
                break;
            }
            SetConVarInt(isSkillSurfConVar, 0);
        }

        if (isSkillSurfConVar.IntValue == 1)
        {
            for (int i = 1; i < MaxClients; i++)
                clientEnabled[i] = true;
        }
    }
}

void ToggleSP()
{
    if (FindConVar("snt_sp_enabled") != null)
    {
        currentlyWeekend = CheckForWeekend();

        if (currentlyWeekend && !isSkurfMap)
            SetConVarInt(isEnabledConVar, 0);
        else
            SetConVarInt(isEnabledConVar, 1);

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
                SetEntityRenderColor(client, 155, 255, 155, 125);
                TF2_AddCondition(client, TFCond_UberchargedHidden);
            }
            else
            {
                SetEntityRenderColor(client, 255, 255, 255, 255);
                return Plugin_Handled;
            }
        else
        {
            SetEntityRenderColor(client, 155, 255, 155, 125);
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
    if (!isSkurfMap)
    {
        if (!currentlyWeekend)
            CPrintToChatAll("%s {orange}SPAWN PROTECTION IS DISABLED!!", PREFIX);
        else
            CPrintToChatAll("%s {orange}Spawn Protection is disabled on weekends!", PREFIX);
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
            SetEntityRenderColor(client, 255, 255, 255, 125);
            TF2_AddCondition(client, TFCond_UberchargedHidden);
        }

        else
        {
            CPrintToChat(client, "%s You have {fullred}disabled{default} spawn protection!", PREFIX);
            SetEntityRenderColor(client, 255, 255, 255, 255);
            TF2_RemoveCondition(client, TFCond_UberchargedHidden);
        }

        return Plugin_Handled;
    }
    else
    {
        CPrintToChat(client, "%s {fullred}You can only toggle spawn protection on skill surf maps! Use the {greenyellow}/votemenu {fullred}to disable spawn protection on a combat surf map.", PREFIX);
        return Plugin_Handled;
    }
}