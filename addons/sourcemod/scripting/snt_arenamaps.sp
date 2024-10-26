#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2powups_stocks>

bool lateLoad;
int roundStarts;

ConVar tf_spells_enabled;
ConVar tf_powerup_mode;

// static int powerups[] = {

// }

public Plugin myinfo =
{
    name = "SNT Arena Maps",
    author = "Arcala the Gyiyg",
    description = "Handles adding spell books to arena surf maps",
    version = "1.0.0",
    url = "https://github.com/ArcalaAlien/snt_utils"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    lateLoad = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    HookEvent("teamplay_round_active", OnRoundStart);

    tf_spells_enabled = FindConVar("tf_spells_enabled");
    tf_powerup_mode = FindConVar("tf_powerup_mode");

    if (lateLoad)
        CreateTimer(5.0, Timer_CreatePowerups);
}

public void OnMapStart()
{
    roundStarts = 0;
    if (tf_powerup_mode.BoolValue)
        ServerCommand("sv_maxvelocity 5000");

    if (tf_powerup_mode.BoolValue)
        AddCommandListener(JoinTeam_CB ,"changeteam");
}

public void OnMapEnd()
{
    if (tf_powerup_mode != null && tf_spells_enabled != null)
    {
        RemoveCommandListener(JoinTeam_CB, "changeteam");
        tf_powerup_mode.SetInt(0);
        tf_spells_enabled.SetInt(0);
    }
    roundStarts = 0;
}

public Action OnRoundStart (Event event, const char[] name, bool dontBroadcast)
{
    roundStarts++;
    PrintToServer("Round has started.");
    CreateTimer(0.1, Timer_CreatePowerups);
    // if (roundStarts == 2)
    //     CreateTimer(0.1, Timer_CreatePowerups);
    return Plugin_Continue;
}

public Action JoinTeam_CB (int client, const char[] command, int args)
{
    PrintToServer("Client %i called changeteam", client);
    ShowVGUIPanel(client, "team");
    return Plugin_Continue;
}

public Action Timer_CreatePowerups (Handle timer, any data)
{
    PrintToServer("Powerup Timer Called");
    char currentMap[256];
    GetCurrentMap(currentMap, sizeof(currentMap));

    char spellLocations[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, spellLocations, sizeof(spellLocations), "configs/sntdb/arena_maps.cfg");

    if (!FileExists(spellLocations))
        ThrowError("[SNT] %s doesn't exist!", spellLocations);

    KeyValues spellLocationsKV = new KeyValues("Maps");
    if(spellLocationsKV.ImportFromFile(spellLocations))
    {
        if(spellLocationsKV.JumpToKey(currentMap))
        {
            char classname[64];
            spellLocationsKV.GetString("classname", classname, sizeof(classname), "tf_spell_pickup");
            spellLocationsKV.GotoFirstSubKey();

            char originStr[48];
            char originStrExpl[3][16];
            float origin[3];

            do
            {
                spellLocationsKV.GetString("origin", originStr, sizeof(originStr), "0 0 0");
                ExplodeString(originStr, " ", originStrExpl, 3, 16);
                for (int i; i < 3; i++)
                    origin[i] = StringToFloat(originStrExpl[i]);

                if (StrEqual(classname, "tf_spell_pickup"))
                {
                    int entIndex = CreateEntityByName(classname);
                    int tier = spellLocationsKV.GetNum("tier");

                    if (IsValidEdict(entIndex))
                    {
                        DispatchKeyValueInt(entIndex, "tier", tier);
                        DispatchKeyValueVector(entIndex, "origin", origin);
                        if (DispatchSpawn(entIndex))
                            TeleportEntity(entIndex, origin);
                        else
                            ThrowError("[SNT] Unable to spawn spellbook.");
                    }
                    else
                        ThrowError("[SNT] Unable to create a valid edict.");
                }
                else if (StrEqual(classname, "info_powerup_spawn"))
                {
                    int type = GetRandomInt(0, 3);
                    int entIndex = -1;
                    switch(type)
                    {
                        case 1:
                            entIndex = CreateEntityByName("item_powerup_uber");
                        default:
                            entIndex = CreateEntityByName("item_powerup_rune");
                    }
                    if (IsValidEdict(entIndex))
                    {
                        char powerupClass[32];
                        GetEntityClassname(entIndex, powerupClass, sizeof(powerupClass));

                        if (StrEqual(powerupClass, "item_powerup_rune"))
                        {
                            // Thank you Scag!!
                            eRuneTypes runeType;
                            runeType = view_as<eRuneTypes>(GetRandomInt(1, view_as<int>(Rune_LENGTH)));
                            SetRuneType(entIndex, runeType);
                            SetRuneKillTime(entIndex, 10.0);
                        }

                        int runeSpawn = -1;
                        runeSpawn = CreateEntityByName("info_powerup_spawn");

                        DispatchKeyValueVector(runeSpawn, "origin", origin);
                        DispatchKeyValueVector(entIndex, "origin", origin)
                        if (DispatchSpawn(entIndex))
                            TeleportEntity(entIndex, origin);
                        else
                            ThrowError("[SNT] Unable to spawn powerup");

                        if (DispatchSpawn(runeSpawn))
                            TeleportEntity(runeSpawn, origin);
                        else
                            ThrowError("[SNT] Unable to spawn powerup spawn location");
                    }
                    else
                        ThrowError("[SNT] Unable to create a valid edict.");
                }
                else
                    ThrowError("[SNT] Invalid classname.");
            }
            while (spellLocationsKV.GotoNextKey())
            spellLocationsKV.Close();
        }
        else
            spellLocationsKV.Close();
    }
    else
        ThrowError("[SNT] Unable to open %s as a keyvalue structure", spellLocations);

    return Plugin_Handled;
}