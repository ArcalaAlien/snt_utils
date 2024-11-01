#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <morecolors>

#undef REQUIRE_PLUGIN
#include <rtd2>
#define REQUIRE_PLUGIN

// Pickup Models
#define PRESENT_MODEL "models/items/tf_gift.mdl"
#define COOLER_MODEL  "models/props_island/mannco_case_small.mdl"
#define PUMPKIN_MODEL "models/props_halloween/pumpkin_loot.mdl"
#define TRIGGER_MODEL "error.mdl"

#define PICKUP_SOUND  "ui/trade_ready.wav"

// Pickup Colors
#define DISABLED "125, 125, 125"
#define DEFAULT "255, 255, 255"
#define RED "255 ,0 ,0"
#define ORANGE "255, 155, 0"
#define YELLOW "255, 255, 0"
#define GREEN "0, 255, 0"
#define CYAN "0, 255, 255"
#define BLUE "0, 0, 255"
#define PURPLE "155, 0, 255"
#define PINK "255, 0, 255"
#define NUM_COLORS 9

// Max pickups per map
#define MAX_PRESENTS 16

// RTD2_GetClientPerk returns -1 as a RTDPerk if the player is not in a roll.
#define INVALID_PERK view_as<RTDPerk>(-1)

bool lateLoad;
bool presentsLoaded[MAX_PRESENTS] = {false, ...};
int presentsCount;

ArrayList presentIDs;
ArrayList triggerIDs;

ConVar snt_map_type = null;

public Plugin myinfo =
{
    name = "SNT Arena Maps",
    author = "Arcala the Gyiyg",
    description = "Handles adding rtd-based powerups into maps",
    version = "2.0.1",
    url = "https://github.com/ArcalaAlien/snt_utils"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    lateLoad = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    if (!LibraryExists("RollTheDice2"))
        ThrowError("[SNT] RTD2 plugin not found!");

    HookEvent("teamplay_round_active", OnRoundStart);
    presentIDs = CreateArray();
    triggerIDs = CreateArray();

    snt_map_type = FindConVar("snt_map_type");

    if (lateLoad)
        CreateTimer(5.0, Timer_CreatePowerups);
}

public void OnMapStart() {
    if (snt_map_type.IntValue == 2) {
        ServerCommand("sv_maxvelocity 5000");
        int month = GetMonth();

        switch (month) {
            case 10:
                PrecacheModel(PUMPKIN_MODEL);
            case 12:
                PrecacheModel(PRESENT_MODEL);
            default:
                PrecacheModel(COOLER_MODEL);
        }

        PrecacheModel(TRIGGER_MODEL);
        PrecacheSound(PICKUP_SOUND);
    }
}

public void OnMapEnd() {
    if (snt_map_type.IntValue == 2) {
        presentIDs.Clear();
        triggerIDs.Clear();
        presentsCount = 0;
    }

}

public void OnGameFrame() {
    if (snt_map_type.IntValue == 2) {
        if (GetMonth() == 10 || GetMonth() == 12)
            return;

        for (int i; i < MAX_PRESENTS; i++) {
            if (!presentsLoaded[i])
                continue;
            
            int present = presentIDs.Get(i);
            if (!IsValidEdict(present))
                continue;

            float presentAngles[3];
            GetEntPropVector(present, Prop_Data, "m_angRotation", presentAngles);

            presentAngles[1] += 1.0;
            DispatchKeyValueVector(present, "angles", presentAngles);
        }
    }

}

public Action OnRoundStart (Event event, const char[] name, bool dontBroadcast) {
    CreateTimer(0.1, Timer_CreatePowerups);
    return Plugin_Continue;
}

int GetMonth()
{
    char month[4];
    FormatTime(month, sizeof(month), "%m", GetTime());

    return StringToInt(month);
}

void CreatePresent(float origin[3]) {
    if (presentsCount > MAX_PRESENTS)
        ThrowError("[SNT] Too many presents! You are over the current limit of %i", MAX_PRESENTS);

    int presentEnt = -1;
    presentEnt = CreateEntityByName("prop_dynamic");
    if (!IsValidEdict(presentEnt))
        ThrowError("[SNT] Unable to create edict for present.");
    else {
        DispatchKeyValueVector(presentEnt, "origin", origin);
        
        int month = GetMonth();

        switch (month) {
            case 10: {
                DispatchKeyValue(presentEnt, "model", PUMPKIN_MODEL);
                DispatchKeyValueFloat(presentEnt, "modelscale", 1.25);
                DispatchKeyValue(presentEnt, "DefaultAnim", "idle");
            }
            case 12: {
                DispatchKeyValue(presentEnt, "model", PRESENT_MODEL);
                DispatchKeyValueFloat(presentEnt, "modelscale", 1.5);
                DispatchKeyValue(presentEnt, "DefaultAnim", "spin");
            }
            default: {
                DispatchKeyValue(presentEnt, "model", COOLER_MODEL);
                DispatchKeyValueFloat(presentEnt, "modelscale", 1.0);
            }
        }

        DispatchKeyValueInt(presentEnt, "rendermode", 1);
        DispatchKeyValue(presentEnt, "targetname", "present_enabled");

        int colorIndex = GetRandomInt(1, NUM_COLORS);
        switch (colorIndex) {
            case 1:
                DispatchKeyValue(presentEnt, "rendercolor", RED);
            case 2:
                DispatchKeyValue(presentEnt, "rendercolor", ORANGE);
            case 3:
                DispatchKeyValue(presentEnt, "rendercolor", YELLOW);
            case 4:
                DispatchKeyValue(presentEnt, "rendercolor", GREEN);
            case 5:
                DispatchKeyValue(presentEnt, "rendercolor", CYAN);
            case 6:
                DispatchKeyValue(presentEnt, "rendercolor", BLUE);
            case 7:
                DispatchKeyValue(presentEnt, "rendercolor", PURPLE);
            case 8:
                DispatchKeyValue(presentEnt, "rendercolor", PINK);
            default:
                DispatchKeyValue(presentEnt, "rendercolor", DEFAULT);
        }

        if (DispatchSpawn(presentEnt)) {
            TeleportEntity(presentEnt, origin);
            AcceptEntityInput(presentEnt, "DisableCollision");

            int presentTrigger = -1
            presentTrigger = CreateEntityByName("trigger_multiple");
            if (!IsValidEdict(presentTrigger)) {
                AcceptEntityInput(presentEnt, "Kill");
                presentEnt = -1;
                ThrowError("[SNT] Unable to create present trigger edict.");
            }
            else {
                // Set trigger origin to the present's origin
                DispatchKeyValueVector(presentTrigger, "origin", origin);
                
                if (!DispatchSpawn(presentTrigger)) {
                    AcceptEntityInput(presentEnt, "Kill");
                    presentEnt = -1;
                    ThrowError("[SNT] Unable to spawn present trigger.");
                }
                else {
                    // Teleport trigger to origin of present
                    TeleportEntity(presentTrigger, origin);

                    // Set up trigger mins and maxs
                    float triggerMins[3];
                    float triggerMaxs[3];

                    // Make the trigger box surround the origin by 48hu
                    for (int i; i < 3; i++) {
                        triggerMins[i] = origin[i] - 48.0;
                        triggerMaxs[i] = origin[i] + 48.0;
                    }
                    
                    // Raise the whole box by 8hu to match the present better.
                    triggerMins[2] += 8.0;
                    triggerMaxs[2] += 8.0;

                    // Actually set the mins and maxes for the trigger
                    SetEntPropVector(presentTrigger, Prop_Send, "m_vecMins", triggerMins);
                    SetEntPropVector(presentTrigger, Prop_Send, "m_vecMaxs", triggerMaxs);

                    // Set the entity to an error model
                    SetEntityModel(presentTrigger, TRIGGER_MODEL);

                    // Set solid type to SOLID_BBOX (Bounding box?);
                    SetEntProp(presentTrigger, Prop_Send, "m_nSolidType", 2);

                    // Enable the trigger
                    AcceptEntityInput(presentTrigger, "Enable");

                    // Hook the trigger
                    SDKHookEx(presentTrigger, SDKHook_StartTouch, OnPresentTouched);

                    // Add present entity and trigger entity to arrays at same time to keep the same indicies
                    presentIDs.Push(presentEnt);
                    triggerIDs.Push(presentTrigger);

                    // Present has been fully loaded
                    presentsLoaded[presentsCount] = true;
                    presentsCount++;
                }
            }
        }
        else
            ThrowError("[SNT] Unable to create present!");
    }
}

bool IsValidClient (int client) {
    if (IsClientConnected(client) && IsClientInGame(client) && IsPlayerAlive(client))
        return true;
    else
        return false;
}

public Action RTD2_CanRollDice (int client) {
    if (snt_map_type.IntValue == 2) {
        CPrintToChat(client, "{white}[{orange}RTD{white}] Find RTD boxes on the map to roll the dice!");
        return Plugin_Stop;
    }

    return Plugin_Continue;
}

// int entity, int other
public Action OnPresentTouched (int trigger, int client) {
    if (!IsValidClient(client) || RTD2_GetClientPerk(client) != INVALID_PERK)
        return Plugin_Stop;

    int presentIndex = triggerIDs.FindValue(trigger);
    int present = presentIDs.Get(presentIndex);

    if (IsValidEdict(present)) {
        char targetname[32];
        GetEntPropString(present, Prop_Data, "m_iName", targetname, sizeof(targetname));
        
        if (StrEqual(targetname, "present_enabled")) {
            float presentOrigin[3];
            GetEntPropVector(present, Prop_Data, "m_vecOrigin", presentOrigin);
            
            EmitAmbientSound(PICKUP_SOUND, presentOrigin, present, SNDLEVEL_AIRCRAFT);
            EmitSoundToClient(client, PICKUP_SOUND);
            DispatchKeyValue(present, "targetname", "present_disabled");
            DispatchKeyValue(present, "rendercolor", DISABLED);
            DispatchKeyValueInt(present, "renderamt", 125);
            CreateTimer(10.0, Timer_EnablePresent, present);
            AcceptEntityInput(trigger, "Disable");

            if (IsValidClient(client)) {
                RTDPerk clientReward = RTD2_Roll(client, ROLLFLAG_IGNORE_PERK_REPEATS | ROLLFLAG_IGNORE_PLAYER_REPEATS);

                char perkGranted[RTD2_MAX_PERK_NAME_LENGTH];
                clientReward.GetToken(perkGranted, sizeof(perkGranted));

                RTD2_Force(client, perkGranted);
            }
        }
    }
    else
        ThrowError("[SNT] Present entity %i doesn't exist or is invalid.", present);

    return Plugin_Continue;
}

public Action Timer_EnablePresent (Handle timer, any present)
{
    int triggerIndex = presentIDs.FindValue(present);
    int trigger = triggerIDs.Get(triggerIndex);

    if (IsValidEdict(present) && IsValidEdict(trigger)) {
        DispatchKeyValueInt(present, "renderamt", 255);
        int colorIndex = GetRandomInt(1, NUM_COLORS);
        switch (colorIndex) {
            case 1:
                DispatchKeyValue(present, "rendercolor", RED);
            case 2:
                DispatchKeyValue(present, "rendercolor", ORANGE);
            case 3:
                DispatchKeyValue(present, "rendercolor", YELLOW);
            case 4:
                DispatchKeyValue(present, "rendercolor", GREEN);
            case 5:
                DispatchKeyValue(present, "rendercolor", CYAN);
            case 6:
                DispatchKeyValue(present, "rendercolor", BLUE);
            case 7:
                DispatchKeyValue(present, "rendercolor", PURPLE);
            case 8:
                DispatchKeyValue(present, "rendercolor", PINK);
            default:
                DispatchKeyValue(present, "rendercolor", DEFAULT);
        }
        DispatchKeyValue(present, "targetname", "present_enabled");
        AcceptEntityInput(trigger, "Enable");
    }
    else
        ThrowError("[SNT] Either present or trigger edict is invalid.");

    return Plugin_Continue;
}

public Action Timer_CreatePowerups (Handle timer, any data)
{
    char currentMap[256];
    GetCurrentMap(currentMap, sizeof(currentMap));

    char powerupOrigins[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, powerupOrigins, sizeof(powerupOrigins), "configs/sntdb/arena_maps.cfg");

    if (!FileExists(powerupOrigins))
        ThrowError("[SNT] %s doesn't exist!", powerupOrigins);


    KeyValues powerupOriginsKV = new KeyValues("Maps");
    if(powerupOriginsKV.ImportFromFile(powerupOrigins)) {
        if(powerupOriginsKV.JumpToKey(currentMap)) {
            powerupOriginsKV.GotoFirstSubKey();
            do {
                char originString[48];
                char originStringExpl[3][16];
                float origin[3];
                powerupOriginsKV.GetString("origin", originString, sizeof(originString), "0 0 0");
                ExplodeString(originString, " ", originStringExpl, 3, 16);
                
                for (int i; i < 3; i++) {
                    origin[i] = StringToFloat(originStringExpl[i]);
                }

                CreatePresent(origin);
            }
            while (powerupOriginsKV.GotoNextKey())
            powerupOriginsKV.Close();
        }
        else
            powerupOriginsKV.Close();
    }
    else
        ThrowError("[SNT] Unable to open %s as a keyvalue structure", powerupOrigins);

    return Plugin_Handled;
}