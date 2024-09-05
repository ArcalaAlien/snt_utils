#include <sourcemod>
#include <sdkhooks>



public Plugin:myinfo =
{
	name = "SNT Collision Plugin",
	author = "Arcala the Gyiyg",
	description = "When two enemy players collide, checks their speeds ",
	version = "1.0.1",
	url = "N/A"
}

bool killedByCollision[MAXPLAYERS + 1] = { false, ... };
bool isEnabled;
ConVar isSkurfMap;

public void OnPluginStart()
{
    HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);

    for (int i = 1; i < MaxClients; i++)
    {
        if (ValidateClient(i))
            OnClientPutInServer(i);
    }

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
    if (ValidateClient(client))
        SDKHook(client, SDKHook_StartTouch, Hook_StartTouch);
}

public void OnClientDisconnect(int client)
{
    if (ValidateClient(client))
    {
        SDKUnhook(client, SDKHook_StartTouch, Hook_StartTouch);
        killedByCollision[client] = false;
    }
}

bool ValidateClient(int client)
{
    if (IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client))
        return true;
    else
        return false;
}

public Action OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"))
    if (killedByCollision[client])
    {
        SetEventString(event, "weapon_logclassname", "collide");
        SetEventString(event, "weapon", "taunt_scout");
        killedByCollision[client] = false;
    }
    return Plugin_Continue;
}

public Action Hook_StartTouch(int client, int client2)
{
    if (isEnabled)
    {
        float client1Vectors[3];
        float client2Vectors[3];
        float client1Velocity;
        float client2Velocity;
        float averageVelocity;
        float velocityDifference;
        
        if (client2 < MaxClients && client2 > 0)
        {
            int client1Health;
            int client2Health;

            client1Health = GetClientHealth(client);
            client2Health = GetClientHealth(client2);

            GetEntPropVector(client, Prop_Data, "m_vecVelocity", client1Vectors);
            GetEntPropVector(client2, Prop_Data, "m_vecVelocity", client2Vectors);

            for(new i = 0; i <= 2; i++)
            {
                client1Vectors[i] *= client1Vectors[i];
                client2Vectors[i] *= client2Vectors[i];
            }

            client1Velocity = SquareRoot(client1Vectors[0] + client1Vectors[1] + client1Vectors[2]);
            client2Velocity = SquareRoot(client2Vectors[0] + client2Vectors[1] + client2Vectors[2]);
            averageVelocity = ((client1Velocity + client2Velocity)/2)

            if (averageVelocity >= 1000.0)
            {
                if (client1Velocity > client2Velocity)
                {
                    if (client1Velocity >= 500.0 && client2Velocity == 0.0)
                    {
                        float floatClient2Health = float(client2Health);
                        if ((floatClient2Health * velocityDifference) > floatClient2Health)
                            killedByCollision[client2] = true;
                        SDKHooks_TakeDamage(client2, client, client, (floatClient2Health * 6.0), DMG_CRIT, -1);
                    }
                    else
                    {
                        velocityDifference = (client2Velocity/client1Velocity);
                        float floatClient2Health = float(client2Health);
                        if ((floatClient2Health * velocityDifference) > floatClient2Health)
                            killedByCollision[client2] = true;
                        SDKHooks_TakeDamage(client2, client, client, (floatClient2Health * velocityDifference), DMG_CRIT, -1);
                    }

                }
                else if (client1Velocity < client2Velocity)
                {
                    if (client2Velocity >= 500.0 && client1Velocity == 0.0)
                    {
                        float floatClient1Health = float(client1Health);
                        if ((floatClient1Health * velocityDifference) > floatClient1Health)
                            killedByCollision[client] = true;
                        SDKHooks_TakeDamage(client, client2, client2, (floatClient1Health * 6.0), DMG_CRIT, -1);
                    }
                    else
                    {
                        velocityDifference = (client1Velocity/client2Velocity);
                        float floatClient1Health = float(client1Health);
                        if ((floatClient1Health * velocityDifference) > floatClient1Health)
                            killedByCollision[client] = true;
                        SDKHooks_TakeDamage(client, client2, client2, (floatClient1Health * velocityDifference), DMG_CRIT, -1);
                    }
                }
            }
        }
    }

    return Plugin_Continue;
}