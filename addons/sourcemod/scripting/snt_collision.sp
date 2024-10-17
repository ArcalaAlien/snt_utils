#include <sourcemod>
#include <sdkhooks>
#include <goomba>

public Plugin:myinfo =
{
	name = "SNT Collision Plugin",
	author = "Arcala the Gyiyg",
	description = "When two enemy players collide, checks their speeds ",
	version = "1.0.2",
	url = "https://github.com/ArcalaAlien/snt_utils"
}

bool lateLoad;
bool killedByCollision[MAXPLAYERS + 1] = { false, ... };
bool isEnabled;
ConVar isSkurfMap;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    lateLoad = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);

    if (lateLoad)
    for (int i = 1; i < MaxClients; i++)
        if (IsValidClient(i))
            OnClientPutInServer(i);

    isSkurfMap = CreateConVar("snt_sp_is_skurf", "0.0", "Change spawnprotection modes between skill-surf and combat surf.", 0, true, 0.0, true, 1.0);
    if (FindConVar("snt_sp_is_skurf") != null)
        if (isSkurfMap.IntValue == 1)
            isEnabled = false;
        else
            isEnabled = true;
    else
        isEnabled = true;
}

public void OnMapStart()
{
    if (FindConVar("snt_sp_is_skurf") != null)
        if (isSkurfMap.IntValue == 1)
            isEnabled = false;
        else
            isEnabled = true;
    else
        isEnabled = true;
}

public void OnClientPutInServer(int client)
{
    if (IsValidClient(client))
        SDKHook(client, SDKHook_StartTouch, Hook_StartTouch);
}

public void OnClientDisconnect(int client)
{
    if (IsValidClient(client))
    {
        SDKUnhook(client, SDKHook_StartTouch, Hook_StartTouch);
        killedByCollision[client] = false;
    }
}

bool IsValidClient(int client)
{
    if (IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client))
        return true;
    else
        return false;
}

public Action OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    PrintToServer("[SNT] OnPlayerDeath Called");
    int client = GetClientOfUserId(GetEventInt(event, "userid"))
    if (killedByCollision[client])
    {
        PrintToServer("[SNT] Client was killed by collision");
        if (!SetEventString(event, "weapon_logclassname", "collision"))
            PrintToServer("[SNT] Set weapon_logclassname to collide");
        else
            PrintToServer("[SNT] Set weapon_logclassname to collide.");
        
        if (!SetEventString(event, "weapon", "vehicle"))
            PrintToServer("[SNT] Unable to set weapon to taunt_scout");
        else
            PrintToServer("[SNT] Set weapon to taunt_scout");

        killedByCollision[client] = false;
    }
    else
        PrintToServer("[SNT] Client was not killed by collision");

    return Plugin_Changed;
}

public Action Hook_StartTouch(int attacker, int victim)
{
    if ((attacker > 0 && victim > 0) && (attacker < MaxClients && victim < MaxClients))
        if (isEnabled)
        {
            if (IsValidClient(attacker) && IsValidClient(victim))
            {
                float attackerCurVel[3];
                float victimCurVel[3];
                float attackerAvgVel;
                float victimAvgVel;
                float totalAvgVel;
                float velPercent;
                float velDiff;

                int victimHealth = GetClientHealth(victim);
                GetEntPropVector(attacker, Prop_Data, "m_vecVelocity", attackerCurVel);
                GetEntPropVector(victim, Prop_Data, "m_vecVelocity", victimCurVel);

                attackerAvgVel = SquareRoot(Pow(attackerCurVel[0], 2.0) + Pow(attackerCurVel[1], 2.0));
                victimAvgVel = SquareRoot(Pow(victimCurVel[0], 2.0) + Pow(victimCurVel[1], 2.0));
                totalAvgVel = (attackerAvgVel + victimAvgVel) / 2;
                velDiff = (attackerAvgVel - victimAvgVel);
                if (attackerAvgVel > victimAvgVel)
                {
                    if (velDiff > 300.0)
                        velPercent = 6.0;
                    else
                    {
                        if (velPercent != 0)
                            velPercent = (victimAvgVel / attackerAvgVel);
                        else
                            velPercent = 6.0;
                    }
                }
                else
                    return Plugin_Continue;

                //(attackerAvgVel > victimAvgVel) ? velPercent = (victimAvgVel / attackerAvgVel) : velPercent = (attackerAvgVel / victimAvgVel);

                if (totalAvgVel > 500.0)
                {
                    float damageToDo = (float(victimHealth) * velPercent);
                    if (damageToDo > victimHealth)
                        killedByCollision[victim] = true;
                    SDKHooks_TakeDamage(victim, attacker, attacker, damageToDo, DMG_VEHICLE | DMG_CRIT, 0);
                }
            }
        }

    return Plugin_Continue;
}