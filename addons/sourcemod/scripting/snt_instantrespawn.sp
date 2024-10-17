#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <tf2>
#include <morecolors>

#define PREFIX "{greenyellow}[{grey}SNT{greenyellow}]{default}"

public Plugin myinfo =
{
    name = "SNT Instant Respawn",
    author = "Arcala the Gyiyg",
    description = "Allows players to choose between killcams, delayed instant respawn, and instant respawn.",
    version = "1.0.0",
    url = "https://github.com/ArcalaAlien/snt_utils"
};

int mode[MAXPLAYERS + 1];
Cookie ck_respawnMode;

public void OnPluginStart()
{
    ck_respawnMode = RegClientCookie("snt_respawn_mode", "0 - No Respawn Time, 1 - Delayed Instant Respawn, 2 - Regular Respawn", CookieAccess_Public);
    HookEvent("player_death", OnPlayerDeath);
    HookEvent("player_team", OnPlayerTeam);

    RegConsoleCmd("sm_kc", usrSetKillCam, "Usage: /kc to open killcam menu, /kc 0,1,2 || /kc i,d,r || /kc instant,delayed,regular to set your killcam without opening the menu.");
    RegConsoleCmd("sm_killcam", usrSetKillCam, "Usage: /killcam to open killcam menu, /killcam 0,1,2 || /killcam i,d,r || /killcam instant,delayed,regular to set your killcam without opening the menu.");
    RegConsoleCmd("sm_r", usrForceRespawn, "Usage: /r to force yourself to respawn.");
    RegConsoleCmd("sm_respawn", usrForceRespawn, "Usage: /respawn to force yourself to respawn.");
}

public void OnClientConnected(int client)
{
    if (isValidClient(client))
    {
        if (AreClientCookiesCached(client))
        {
            char clientCookie[16];
            getRespawnCookie(client, clientCookie, sizeof(clientCookie));

            if (StrEqual(clientCookie, "\0"))
                Format(clientCookie, sizeof(clientCookie), "0");

            switch (StringToInt(clientCookie))
            {
                case 0:
                    mode[client] = 0;
                case 1:
                    mode[client] = 1;
                case 2:
                    mode[client] = 2;
                default:
                {
                    mode[client] = 0;
                    setRespawnCookie(client, 0);
                }
            }
        }
    }
}

public void OnClientDisconnect(int client)
{
    if (isValidClient(client))
        setRespawnCookie(client, mode[client]);
    
    mode[client] = 0;
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"))
    if (client != 0 && isValidClient(client))
    {
        switch (mode[client])
        {
            case 0:
                RequestFrame(respawnPlayer, client);
            case 1:
                CreateTimer(0.5, respawnTimer, client);
        }
    }
}

public void OnPlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"))
    if (isValidClient(client))
    {
        if (AreClientCookiesCached(client))
        {
            char clientCookie[16];
            getRespawnCookie(client, clientCookie, sizeof(clientCookie));

            if (StrEqual(clientCookie, "\0"))
                Format(clientCookie, sizeof(clientCookie), "0");

            switch (StringToInt(clientCookie))
            {
                case 0:
                    mode[client] = 0;
                case 1:
                    mode[client] = 1;
                case 2:
                    mode[client] = 2;
                default:
                {
                    mode[client] = 0;
                    setRespawnCookie(client, 0);
                }
            }
        }
    }
}

bool isValidClient(int client)
{
    if (IsClientInGame(client) && IsClientConnected(client) && !IsFakeClient(client))
        return true;
    else if (!IsClientInGame(client) || !IsClientConnected(client) || IsFakeClient(client))
        return false;
    else
        return false;
}

void getRespawnCookie(int client, char[] cookieValue, int maxlen)
{
    if (isValidClient(client))
        GetClientCookie(client, ck_respawnMode, cookieValue, maxlen);
}

void setRespawnCookie(int client, int cookieMode)
{
    if (isValidClient(client))
    {
        switch (cookieMode)
        {
            case 0:
                SetClientCookie(client, ck_respawnMode, "0");
            case 1:
                SetClientCookie(client, ck_respawnMode, "1");
            case 2:
                SetClientCookie(client, ck_respawnMode, "2");
        }
    }
}

void buildSettingsMenu(int client)
{
    Panel kcMenu = CreatePanel();
    kcMenu.SetTitle("Choose an option:");
    kcMenu.DrawText(" ");

    switch(mode[client])
    {
        case 0:
            kcMenu.DrawText("Current Setting: Instant");
        case 1:
            kcMenu.DrawText("Current Setting: Delayed");
        case 2:
            kcMenu.DrawText("Current Setting: Regular");
    }

    kcMenu.DrawText(" ");
    kcMenu.DrawItem("Instant Respawn");
    kcMenu.DrawItem("1s Delayed Respawn");
    kcMenu.DrawItem("Regular Respawn");
    kcMenu.DrawText(" ");
    kcMenu.DrawItem("Exit");
    kcMenu.Send(client, kcMenu_Handler, 10);
}

public int kcMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            switch (param2)
            {
                case 1:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    mode[param1] = 0;
                    setRespawnCookie(param1, 0);
                    CPrintToChat(param1, "%s Set your preference to {greenyellow}instant respawn.", PREFIX);
                    buildSettingsMenu(param1);
                }
                case 2:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    mode[param1] = 1;
                    setRespawnCookie(param1, 1);
                    CPrintToChat(param1, "%s Set your preference to {greenyellow}1s delayed respawn.", PREFIX);
                    buildSettingsMenu(param1);
                }
                case 3:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    mode[param1] = 2;
                    setRespawnCookie(param1, 2);
                    CPrintToChat(param1, "%s Set your preference to {greenyellow}regular respawn.", PREFIX);
                    buildSettingsMenu(param1);
                }
                case 4:
                {
                    EmitSoundToClient(param1, "buttons/combine_button7.wav");
                    CloseHandle(menu);
                }
            }
        }
    }
    return 0;
}

public void respawnTimer(Handle timer, any client)
{
    RequestFrame(respawnPlayer, client);
}

public void respawnPlayer(any client)
{
    if (isValidClient(client) && !IsPlayerAlive(client) && GetClientTeam(client) != 1)
        TF2_RespawnPlayer(client);
}

public Action usrSetKillCam(int client, int args)
{
    if (client == 0)
        return Plugin_Handled;
    
    switch (args)
    {
        case 0:
        {
            buildSettingsMenu(client);
            return Plugin_Handled;
        }
        case 1:
        {
            char selMode[16];
            GetCmdArg(1, selMode, sizeof(selMode));

            if (StrEqual(selMode, "0", false) || StrEqual(selMode, "i", false) || StrEqual(selMode, "instant", false))
            {
                mode[client] = 0;
                setRespawnCookie(client, 0);
                CPrintToChat(client, "%s Set your preference to {greenyellow}instant respawn.", PREFIX);
            }

            else if (StrEqual(selMode, "1", false) || StrEqual(selMode, "d", false) || StrEqual(selMode, "delay", false) || StrEqual(selMode, "delayed", false))
            {
                mode[client] = 1;
                setRespawnCookie(client, 1);
                CPrintToChat(client, "%s Set your preference to {greenyellow}1s delayed respawn.", PREFIX);
            }

            else if (StrEqual(selMode, "2", false) || StrEqual(selMode, "r", false) || StrEqual(selMode, "reg") || StrEqual(selMode, "regular"))
            {
                mode[client] = 2;
                setRespawnCookie(client, 2);
                CPrintToChat(client, "%s Set your preference to {greenyellow}regular respawn.", PREFIX);
            }

            return Plugin_Handled;
        }
        default:
        {
            CPrintToChat(client, "%s Usage: {greenyellow}/killcam {orange}<mode>, {greenyellow}/kc {orange}<mode>", PREFIX);
            CPrintToChat(client, "%s Modes: {orange}(instant, i, 0), (delayed, d, 1), (regular, r, 1)", PREFIX);
            return Plugin_Handled;
        }
    }
}

public Action usrForceRespawn(int client, int args)
{
    if (client == 0)
        return Plugin_Handled;
    
    if (args > 0)
    {
        CPrintToChat(client, "%s Usage: {greenyellow}/respawn, /r", PREFIX);
        return Plugin_Handled;
    }

    if (isValidClient(client) && GetClientTeam(client) != 1)
        TF2_RespawnPlayer(client);

    return Plugin_Handled;
}