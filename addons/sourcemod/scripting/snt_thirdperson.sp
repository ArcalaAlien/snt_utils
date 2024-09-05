#define PREFIX "{greenyellow}[{grey}SNT{greenyellow}]{default}"

#include <sourcemod>
#include <sdktools>
#include <morecolors>
#include <tf2>

bool IsEnabled[MAXPLAYERS + 1] = {false, ...};

public Plugin myinfo =
{
    name = "SNT Third Person",
    author = "Arcala The Gyiyg",
    description = "Allows players to switch between first and third person.",
    version = "1.0.0",
    url = "https://github.com/ArcalaAlien/snt_utils"
};

public void OnPluginStart()
{
    // Register all commands
    RegConsoleCmd("sm_thirdperson",     ALL_ToggleTP, "[SNT] /thirdperson: Used to toggle between third / first person.");
    RegConsoleCmd("sm_firstperson",     ALL_ToggleTP, "[SNT] /firstperson: Used to toggle between third / first person.");
    RegConsoleCmd("sm_tp",              ALL_ToggleTP, "[SNT] /tp: Used to toggle between third / first person.");
    RegConsoleCmd("sm_fp",              ALL_ToggleTP, "[SNT] /fp: Used to toggle between third / first person.");
    RegConsoleCmd("sm_3",               ALL_ToggleTP, "[SNT] /thirdperson: Used to toggle between third / first person.");
    RegConsoleCmd("sm_1",               ALL_ToggleTP, "[SNT] /thirdperson: Used to toggle between third / first person.");

    // Register all hooks
    HookEvent("post_inventory_application", Event_OnPlayerSpawn);
}

public void OnPluginEnd()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsPlayerAlive(i))
        {
            SetVariantInt(0);
            AcceptEntityInput(i, "SetForcedTauntCam");
        }
    }
}

public void OnClientDisconnect(int client)
{
    IsEnabled[client] = false;
}

public Action Event_OnPlayerSpawn(Handle event, char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));

    if (!IsFakeClient(client))
    {
        if (IsEnabled[client])
        {
            CreateTimer(0.5, Timer_ToggleTP, client);
        }
    }
    return Plugin_Handled;
}

public Action Timer_ToggleTP(Handle timer, any client)
{
    SetVariantInt(1);
    AcceptEntityInput(client, "SetForcedTauntCam");
    return Plugin_Continue;
}

public Action ALL_ToggleTP(int client, int args)
{
    if (client == 0)
    {
        ReplyToCommand(client, "[SNT] SERVER CANNOT USE THIS COMMAND.");
        return Plugin_Handled;
    }

    if (args > 0)
    {
        CReplyToCommand(client, "%s /tp, /3, /thirdperson or /fp, /1, /firstperson: Use this to toggle between first and third person.", PREFIX);
        return Plugin_Handled;
    }

    if (IsPlayerAlive(client))
    {
        if (IsEnabled[client])
        {
            CReplyToCommand(client, "%s Disabled Third Person", PREFIX);
            
            IsEnabled[client] = !IsEnabled[client];
            SetVariantInt(0);
            AcceptEntityInput(client, "SetForcedTauntCam");
            return Plugin_Handled;
        }
        else
        {
            CReplyToCommand(client, "%s Enabled Third Person", PREFIX);

            IsEnabled[client] = !IsEnabled[client];
            SetVariantInt(1);
            AcceptEntityInput(client, "SetForcedTauntCam");
            return Plugin_Handled;
        }
    }
    return Plugin_Handled;
}

//? Why these?
public void TF2_OnConditionAdded(int client, TFCond condition)
{
    if (condition == TFCond_Zoomed && IsPlayerAlive(client) && IsEnabled[client])
    {
        SetVariantInt(0); // Set cam to first person
        AcceptEntityInput(client, "SetForcedTauntCam");
    }
}

public void TF2_OnConditionRemoved(int client, TFCond condition)
{
    if (condition == TFCond_Zoomed && IsPlayerAlive(client) && IsEnabled[client])
    {
        SetVariantInt(1); // Set cam to third person
        AcceptEntityInput(client, "SetForcedTauntCam");
    }
}
