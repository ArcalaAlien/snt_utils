#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

bool lateLoad;
int roundStarts;

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

    if (lateLoad)
        CreateTimer(5.0, Timer_CreatePowerups);
}

public void OnMapStart()
{
    roundStarts = 0;
}

public void OnMapEnd()
{
    roundStarts = 0;
}

public Action OnRoundStart (Event event, const char[] name, bool dontBroadcast)
{
    roundStarts++;
    PrintToServer("Round has started.");
    if (roundStarts == 3)
        CreateTimer(0.1, Timer_CreatePowerups);
    return Plugin_Continue;
}

public Action Timer_CreatePowerups (Handle timer, any data)
{
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

                int entIndex = CreateEntityByName(classname);

                if (StrEqual(classname, "tf_spell_pickup"))
                {
                    int tier = spellLocationsKV.GetNum("tier");

                    if (IsValidEdict(entIndex))
                    {
                        DispatchKeyValue(entIndex, "AutoMaterialize", "true");
                        DispatchKeyValueInt(entIndex, "tier", tier);
                        if (DispatchSpawn(entIndex))
                        {
                            TeleportEntity(entIndex, origin);
                            SDKHook(entIndex, SDKHook_EndTouchPost, Hook_EndTouchPost);
                            CreateTimer(0.5, Timer_EnablePowerup, entIndex);
                        }
                        else
                            ThrowError("[SNT] Unable to spawn spellbook.");
                    }
                    else
                        ThrowError("[SNT] Unable to create a valid edict.");
                }
                else if (StrEqual(classname, "info_powerup_spawn"))
                {
                    if (IsValidEdict(entIndex))
                    {
                        DispatchKeyValue(entIndex, "AutoMaterialize", "true");
                        DispatchKeyValueInt(entIndex, "TeamNum", 0);
                        DispatchKeyValue(entIndex, "StartDisabled", "false");
                        if (DispatchSpawn(entIndex))
                            TeleportEntity(entIndex, origin);
                        else
                            ThrowError("[SNT] Unable to spawn info_powerup_spawn");
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

public void Hook_EndTouchPost (int entity, int other)
{
    CreateTimer(9.5, Timer_RegenPowerup, entity);
}

public Action Timer_RegenPowerup (Handle timer, any entity)
{
    if (IsValidEdict(entity))
    {
        char classname[64];
        GetEntityClassname(entity, classname, sizeof(classname));

        if (StrEqual(classname, "tf_spell_pickup"))
        {
            float origin[3];
            GetEntPropVector(entity, Prop_Data, "m_vOriginalSpawnOrigin", origin);
            int tier = GetEntProp(entity, Prop_Data, "m_nTier");

            RemoveEdict(entity);
            CreateSingleBook(origin, tier);
        }
    }
    
    return Plugin_Handled;
}

void CreateSingleBook(float origin[3], int tier)
{
    int entIndex = CreateEntityByName("tf_spell_pickup");
    if (IsValidEdict(entIndex))
    {
        DispatchKeyValueInt(entIndex, "tier", tier);
        if (DispatchSpawn(entIndex))
        {
            TeleportEntity(entIndex, origin);
            SDKHook(entIndex, SDKHook_EndTouchPost, Hook_EndTouchPost);
            CreateTimer(0.5, Timer_EnablePowerup, entIndex);
        }
        else
            ThrowError("[SNT] Unable to spawn spellbook.");
    }
    else
        ThrowError("[SNT] Unable to create a valid edict.");
}

public Action Timer_EnablePowerup (Handle timer, any entity)
{
    if (IsValidEdict(entity))
        if(AcceptEntityInput(entity, "Enable"))
            PrintToServer("Enabled powerup with index (%i)", entity);
        else
            PrintToServer("Unable to enable Book with index (%i)", entity);

    return Plugin_Handled;
}