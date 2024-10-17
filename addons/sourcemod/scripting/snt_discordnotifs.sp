#include <sourcemod>
#include <discordWebhookAPI>

public Plugin myinfo =
{
    name = "[SNT] Discord Pinger",
    author = "Arcala the Gyiyg",
    description = "Pings the @surfer role on SnT Discord when a certain amount of players is in the server.",
    version = "1.0.0",
    url = "https://github.com/ArcalaAlien/snt_utils"
};

char whURL[WEBHOOK_URL_MAX_SIZE];
char whUser[MAX_NAME_LENGTH];
char whAvatarURL[WEBHOOK_URL_MAX_SIZE];
char whRoleId[48];
char whThumbURL[WEBHOOK_URL_MAX_SIZE];
int  emPingColor;
int  emInfoColor;
bool lateLoad;

Handle notificationTimer = INVALID_HANDLE;

ConVar cvMinNumPlayers;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    lateLoad = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    cvMinNumPlayers = CreateConVar("snt_min_to_ping", "6", "Minimum numbers of players in server to ping @surfers", 0, true, 4.0, true, float(MaxClients));

    LoadConfig();
    RegAdminCmd("sm_sntd_loadconf", ADM_LoadConfig, ADMFLAG_ROOT, "refresh configs");

    if (lateLoad)
    {
        OnClientConnected(0);
        OnMapStart();
    }
}

public void OnClientConnected(int client)
{
    int connectedClients = GetClientCount();
    int minToPing = cvMinNumPlayers.IntValue;

    if (connectedClients == minToPing)
        sendDiscordPing();
}

public void OnMapStart()
{
    char currentMap[64];
    GetCurrentMap(currentMap, sizeof(currentMap));
    TrimString(currentMap);
    // Set up thumbnail url for current map
    Format(whThumbURL, sizeof(whThumbURL), "https://surfnturf.games/assets/images/thumbs/%s.png", currentMap);
    PrintToServer("[SNT] Current Map: %s Looking for thumbnail @ %s", currentMap, whThumbURL);

    HTTPRequest thumbReq = new HTTPRequest(whThumbURL);
    thumbReq.Get(OnCheckForPng);

    CreateTimer(5.0, sendServerInfo_Timer);
    if (notificationTimer == INVALID_HANDLE)
        notificationTimer = CreateTimer(30.0, sendServerInfo_Timer, 0, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    else
    {
        CloseHandle(notificationTimer);
        notificationTimer = CreateTimer(30.0, sendServerInfo_Timer, 0, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE)
    }
}

public void OnMapEnd()
{
    if (notificationTimer != INVALID_HANDLE)
    {
        CloseHandle(notificationTimer);
        notificationTimer = INVALID_HANDLE;
    }
}

public void OnCheckForPng(HTTPResponse res, any value, const char[] error)
{
    if (res.Status != HTTPStatus_OK)
    {
        char currentMap[64];
        GetCurrentMap(currentMap, sizeof(currentMap));
        TrimString(currentMap);
        // Set up thumbnail url for current map
        Format(whThumbURL, sizeof(whThumbURL), "https://surfnturf.games/assets/images/thumbs/%s.jpg", currentMap);
        if (error[0] == '\0')
            PrintToServer("[SNT] Unable to find PNG thumbnail (ERROR %i) Looking for thumbnail @ %s", res.Status, whThumbURL);
        else
            PrintToServer("[SNT] Unable to find PNG thumbnail (ERROR %i: %s) Looking for thumbnail @ %s", res.Status, error, whThumbURL);

        HTTPRequest thumbReq = new HTTPRequest(whThumbURL);
        thumbReq.Get(OnCheckForJpg);
    }
}

public void OnCheckForJpg(HTTPResponse res, any value, const char[] error)
{
    if (res.Status != HTTPStatus_OK)
    {
        char currentMap[64];
        GetCurrentMap(currentMap, sizeof(currentMap));
        TrimString(currentMap);
        if (error[0] == '\0')
            PrintToServer("[SNT] Unable to find thumbnail for %s. Defaulting to placeholder. (ERROR %i)", currentMap, res.Status);
        else
            PrintToServer("[SNT] Unable to find thumbnail for %s. Defaulting to placeholder. (ERROR %i: %s)", currentMap, res.Status, error);
        Format(whThumbURL, sizeof(whThumbURL), "https://surfnturf.games/assets/images/thumbs/notfound.png");
    }
}

public void OnPingSent(HTTPResponse res, DataPack pack)
{
    if (res.Status != HTTPStatus_OK)
    {
        PrintToServer("[SNT] The ping was unable to be sent. HTTP Status Code: %i", res.Status);
        return;
    }
}

public void OnServerInfoSent(HTTPResponse res, DataPack pack)
{
    if (res.Status != HTTPStatus_OK)
    {
        PrintToServer("[SNT] The server info was unable to be sent. HTTP Status Code: %i", res.Status);
        return;
    }
}

void sendDiscordPing()
{
    char embedFieldValue[16];
    char embedDescription[4096];
    Webhook surferPing = new Webhook("");
    Embed surferPingEmbed = new Embed("🌊 Surf'n'Turf | Combat Surf");
    EmbedField embedField1 = new EmbedField("Current Players");
    EmbedField embedField2 = new EmbedField("Server Hop", "[Connect To Surf'n'Turf](https://surfnturf.games/connect.html)");

    Format(embedFieldValue, sizeof(embedFieldValue), "%i/%i Players", GetClientCount(), MaxClients);
    PrintToServer("Pinging Role: %i", whRoleId);
    Format(embedDescription, sizeof(embedDescription), "<@&%s> Hop on the server!", whRoleId);

    // Set field 1
    embedField1.SetValue(embedFieldValue);

    // Set embed
    surferPingEmbed.SetDescription(embedDescription);
    surferPingEmbed.SetTimeStampNow();
    surferPingEmbed.SetColor(emPingColor);
    surferPingEmbed.AddField(embedField1);
    surferPingEmbed.AddField(embedField2);

    // Set webhook
    surferPing.SetUsername(whUser);
    surferPing.SetAvatarURL(whAvatarURL);
    surferPing.AddEmbed(surferPingEmbed);

    if (!whURL[0])
    {
        PrintToServer("[SNT] Unable to find your Discord webhook!");
        delete surferPing;
        return;
    }

    surferPing.Execute(whURL, OnPingSent);
}

void sendServerInfo()
{
    // Variables
    char currentMap[32];
    char nextMap[32];
    char playerCount[16];
    char mapTimeLeft[16];

    int timeLeft;
    int secsLeft;
    int minsLeft;

    Webhook serverInfo = new Webhook("");
    Embed infoEmbed = new Embed("🌊 Surf'n'Turf | Combat Surf");
    EmbedField infoField1 = new EmbedField("Current Map");
    EmbedField infoField2 = new EmbedField("Next Map");
    EmbedField infoField3 = new EmbedField("Current Players");
    EmbedField infoField4 = new EmbedField("Time Left");
    EmbedField infoField5 = new EmbedField("Server Hop", "[Connect to Surf'n'Turf](https://surfnturf.games/connect.html)");
    EmbedThumbnail infoThumbnail = new EmbedThumbnail();
    EmbedImage infoImage = new EmbedImage();

    // Get current map name for field 1
    GetCurrentMap(currentMap, sizeof(currentMap));
    
    // Get next map for field 2
    // If there is no next map, set field 2 as "N/A"
    if (!GetNextMap(nextMap, sizeof(nextMap)))
            Format(nextMap, sizeof(nextMap), "N/A");

    // Get the player count. <Current Players> / <Max Players Allowed On Server>
    Format(playerCount, sizeof(playerCount), "%i / %i", GetClientCount(), MaxClients);

    /* 
        Get the map time left
        Time left is in seconds
        Modulo time left by 60 to get seconds remaining in current minute.
        Divide time left by 60 to get minutes remaining. 
    */
    GetMapTimeLeft(timeLeft);
    secsLeft = timeLeft % 60;
    minsLeft = timeLeft / 60;

    // Formatting the time left display
    // If amount of mins left is less than 10
    if (minsLeft < 10)
        // Check to see if seconds left is also less than 10
        if (secsLeft < 10)
            // If it is, format time 0m:0s
            Format(mapTimeLeft, sizeof(mapTimeLeft), "0%i:0%i", minsLeft, secsLeft);
        else
            // Otherwise, format time 0m:ss
            Format(mapTimeLeft, sizeof(mapTimeLeft), "0%i:%i", minsLeft, secsLeft);
    // If mins left is greater than or equal to 10
    else
        // Same second check up there, except time is formated mm:0s or mm:ss
        if (secsLeft < 10)
            Format(mapTimeLeft, sizeof(mapTimeLeft), "%i:0%i", minsLeft, secsLeft);
        else
            Format(mapTimeLeft, sizeof(mapTimeLeft), "%i:%i", minsLeft, secsLeft);

    // if timeLeft is 0, set time left to "Map Change"
    if (timeLeft == 0 || timeLeft == -1)
        Format(mapTimeLeft, sizeof(mapTimeLeft), "Map Change");
    else if (timeLeft < -1)
        Format(mapTimeLeft, sizeof(mapTimeLeft), "Server Idle");

    infoThumbnail.SetURL(whThumbURL);

    // Setting up the fields
    infoField1.SetValue(currentMap);
    infoField2.SetValue(nextMap);
    infoField3.SetValue(playerCount);
    infoField4.SetValue(mapTimeLeft);
    infoField4.SetInline(false);
    infoField5.SetInline(false);

    // Setting up the embed
    infoEmbed.SetTimeStampNow();
    infoEmbed.SetThumbnail(infoThumbnail);
    infoEmbed.SetColor(emInfoColor);
    infoEmbed.AddField(infoField1);
    infoEmbed.AddField(infoField2);
    infoEmbed.AddField(infoField3);
    infoEmbed.AddField(infoField4);
    infoEmbed.AddField(infoField5);

    // Finally setting up the webhook
    serverInfo.SetUsername(whUser);
    serverInfo.SetAvatarURL(whAvatarURL);
    serverInfo.AddEmbed(infoEmbed);

    // Cleanup step
    delete infoImage;

    // Check to see if we were able to get the discord webhook from the config file
    if (!whURL[0])
    {
        PrintToServer("[SNT] Unable to find your Discord webhook!");
        delete serverInfo;
        return;
    }

    // Execute webhook to send message, using OnServerInfoSent as a callback
    serverInfo.Execute(whURL, OnServerInfoSent);
}

void LoadConfig()
{
    char configFilePath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configFilePath, sizeof(configFilePath), "configs/sntdb/main_config.cfg");

    KeyValues configFile = new KeyValues("ConfigFile");
    configFile.ImportFromFile(configFilePath);

    if (!configFile)
    {
        PrintToServer("[SNT] Unable to find configs/sntdb/main_config.cfg!");
        delete configFile;
        return;
    }

    if (!configFile.JumpToKey("Discord"))
    {
        PrintToServer("[SNT] Unable to jump to the Discord key in the config!");
        configFile.Close();
        return;
    }
    else
    {
        configFile.GetString("webhookURL", whURL, sizeof(whURL));
        configFile.GetString("webhookName", whUser, sizeof(whUser));
        configFile.GetString("webhookAvatar", whAvatarURL, sizeof(whAvatarURL));

        char roleIdP1[16];
        char roleIdP2[16];
        char roleIdP3[16];
        // Get discord role
        configFile.GetString("roleP1", roleIdP1, sizeof(roleIdP1));
        configFile.GetString("roleP2", roleIdP2, sizeof(roleIdP2));
        configFile.GetString("roleP3", roleIdP3, sizeof(roleIdP3));
        Format(whRoleId, sizeof(whRoleId), "%s%s%s", roleIdP1, roleIdP2, roleIdP3);

        // configFile.GetString("pingThis", whRoleId, sizeof(whRoleId));
        PrintToServer("Got role id: %s", whRoleId);
        emPingColor = configFile.GetNum("pingColor");
        emInfoColor = configFile.GetNum("infoColor");
        cvMinNumPlayers.SetInt(configFile.GetNum("minToPing"));
    }

    configFile.Close();

    PrintToServer("[SNT] Discord settings loaded successfully!");
}

public Action sendServerInfo_Timer(Handle timer)
{
    sendServerInfo();
    return Plugin_Continue;
}

public Action ADM_LoadConfig (int client, int args)
{
    LoadConfig();
    return Plugin_Handled;
}