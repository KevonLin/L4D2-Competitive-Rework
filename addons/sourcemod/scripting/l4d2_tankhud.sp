#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <left4dhooks>
#define L4D2UTIL_STOCKS_ONLY 1
#include <l4d2util>

#define PLUGIN_VERSION "2.1"

public Plugin myinfo = 
{
    name = "Enhanced Tank HUD",
    author = "AI Assistant & Modified by Jenny",
    description = "Advanced Tank HUD with auto-display and enhanced info",
    version = PLUGIN_VERSION,
    url = ""
};

#define HUD_UPDATE_INTERVAL 0.5
#define MAX_TANKS 4

ConVar g_hTankBurnDuration, l4d_ready_cfg_name;
bool g_bTankHudActive[MAXPLAYERS+1];
float g_fTankBurnDuration;
char sReadyCfgName[64];

public void OnPluginStart()
{
    g_hTankBurnDuration = FindConVar("tank_burn_duration");
    g_fTankBurnDuration = g_hTankBurnDuration.FloatValue;
    g_hTankBurnDuration.AddChangeHook(OnConVarChanged);

    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_team", Event_PlayerTeam);
    
    RegConsoleCmd("sm_tankhud", Command_ToggleHud);
    
    CreateTimer(HUD_UPDATE_INTERVAL, Timer_UpdateHUD, _, TIMER_REPEAT);
}

native int MTAM_GetTankPasses(int client);

void FillReadyConfig()
{
	if (l4d_ready_cfg_name != null || (l4d_ready_cfg_name = FindConVar("l4d_ready_cfg_name")) != null)
		l4d_ready_cfg_name.GetString(sReadyCfgName, sizeof(sReadyCfgName));
}

public void OnAllPluginsLoaded()
{
	FillReadyConfig();
}

public void OnClientDisconnect(int client)
{
    g_bTankHudActive[client] = false;
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    g_fTankBurnDuration = g_hTankBurnDuration.FloatValue;
}

public Action Command_ToggleHud(int client, int args)
{
    if (client && IsClientInGame(client))
    {
        g_bTankHudActive[client] = !g_bTankHudActive[client];
        CPrintToChat(client, "{default}[{olive}TankHUD{default}] {default}HUD %s", g_bTankHudActive[client] ? "enabled" : "disabled");
    }
    return Plugin_Handled;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsValidTank(client))
    {
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && GetClientTeam(i) != L4D2Team_Survivor)
            {
                g_bTankHudActive[i] = true;
            }
        }
    }
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsValidTank(client))
    {
        bool bAnyTankAlive = false;
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsValidTank(i) && IsPlayerAlive(i))
            {
                bAnyTankAlive = true;
                break;
            }
        }
        
        if (!bAnyTankAlive)
        {
            for (int i = 1; i <= MaxClients; i++)
            {
                g_bTankHudActive[i] = false;
            }
        }
    }
}

public Action Timer_UpdateHUD(Handle timer)
{
    if (!AnyTankAlive())
        return Plugin_Continue;

    int[] clients = new int[MaxClients];
    int count = 0;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && ShouldShowHud(i))
        {
            clients[count++] = i;
        }
    }

    if (count > 0)
    {
        Panel panel = new Panel();
        BuildHUDContent(panel);
        
        for (int i = 0; i < count; i++)
        {
            switch (GetClientMenu(clients[i]))
			{
				case MenuSource_External, MenuSource_Normal: continue;
			}
            panel.Send(clients[i], DummyHandler, 3);
        }
        delete panel;
    }
    return Plugin_Continue;
}

public int DummyHandler(Menu menu, MenuAction action, int param1, int param2)
{
    return 1;
}


void BuildHUDContent(Panel panel)
{
    int iTanks[MAX_TANKS];
    int tankCount = CollectAliveTanks(iTanks);

    // Header
    char sInfo[128];
    if (strlen(sReadyCfgName) == 0)
        FormatEx(sInfo, sizeof(sInfo), "Chargers 8v8 :: Tank HUD");
    else
        FormatEx(sInfo, sizeof(sInfo), "%s :: Tank HUD", sReadyCfgName);
    DrawPanelText(panel, sInfo);
    int len = strlen(sInfo);
    for (int i = 0; i < len; ++i) sInfo[i] = '_';
    DrawPanelText(panel, sInfo);
    DrawPanelText(panel, " ");

    for (int i = 0; i < tankCount; i++)
    {
        int tank = iTanks[i];
        if (!IsValidTank(tank)) continue;

        char sName[MAX_NAME_LENGTH];
        char sPassInfo[32];
        
        // 获取当前Tank的传递次数
        int passCount = MTAM_GetTankPasses(tank) + 1;
        FormatPassCount(passCount, sPassInfo, sizeof(sPassInfo));
        
        // Controller Info with pass count
        if (IsFakeClient(tank))
        {
            Format(sInfo, sizeof(sInfo), "Control : AI");
        }
        else
        {
            GetClientFixedName(tank, sName, sizeof(sName));
            Format(sInfo, sizeof(sInfo), "Control : %s (%s)", sName, sPassInfo);
        }
        DrawPanelText(panel, sInfo);

        // Health Info
        int iHealth = GetClientHealth(tank);
        int iMaxHealth = GetEntProp(tank, Prop_Send, "m_iMaxHealth");
        if (iHealth <= 0 || IsIncapacitated(tank))
        {
            sInfo = "Health  : Dead";
        }
        else
        {
            FormatEx(sInfo, sizeof(sInfo), "Health  : %i / %i", iHealth, iMaxHealth);
        }
        DrawPanelText(panel, sInfo);

        // Frustration
        if (!IsFakeClient(tank))
            Format(sInfo, sizeof(sInfo), "Frustr.  : %d", GetTankFrustration(tank));
        else
            Format(sInfo, sizeof(sInfo), "Frustr.  : AI");
        DrawPanelText(panel, sInfo);

        // Network Info
        if (!IsFakeClient(tank))
        {
            float fPing = GetClientAvgLatency(tank, NetFlow_Both) * 1000.0;
            float fLerp = GetLerpTime(tank) * 1000.0;
            Format(sInfo, sizeof(sInfo), "Network: %ims / %.1f", RoundFloat(fPing), fLerp);
        }
        else
        {
            Format(sInfo, sizeof(sInfo), "Network : AI");
        }
        DrawPanelText(panel, sInfo);

        // Fire Status
        if (IsPlayerBurning(tank))
        {
            int iTimeLeft = CalculateBurnTimeLeft(tank);
            Format(sInfo, sizeof(sInfo), "Burning : %ds", iTimeLeft);
            DrawPanelText(panel, sInfo);
        }

        if (i < tankCount - 1)
        {
            for (int j = 0; j < len; ++j) sInfo[j] = '_';
                DrawPanelText(panel, sInfo);
            DrawPanelText(panel, " ");
        }
    }
}

bool ShouldShowHud(int client)
{
    return g_bTankHudActive[client] && GetClientTeam(client) != L4D2Team_Survivor;
}

int CollectAliveTanks(int[] tanks)
{
    int count = 0;
    for (int i = 1; i <= MaxClients && count < MAX_TANKS; i++)
    {
        if (IsValidTank(i) && IsPlayerAlive(i))
        {
            tanks[count++] = i;
        }
    }
    return count;
}

void FormatPassCount(int passCount, char[] buffer, int maxlen)
{
    switch (passCount)
    {
        case 0: Format(buffer, maxlen, "Native");
        case 1: Format(buffer, maxlen, "%ist", passCount);
        case 2: Format(buffer, maxlen, "%ind", passCount);
        case 3: Format(buffer, maxlen, "%ird", passCount);
        default: Format(buffer, maxlen, "%ith", passCount);
    }
}

int CalculateBurnTimeLeft(int tank)
{
    int iHealth = GetClientHealth(tank);
    int iMaxHealth = GetEntProp(tank, Prop_Send, "m_iMaxHealth");
    float fHealthPercent = float(iHealth) / float(iMaxHealth) * 100.0;
    return RoundToCeil(fHealthPercent / 100.0 * g_fTankBurnDuration);
}

bool AnyTankAlive()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidTank(i) && IsPlayerAlive(i))
            return true;
    }
    return false;
}

bool IsPlayerBurning(int client)
{
    return GetEntityFlags(client) & FL_ONFIRE;
}

float GetLerpTime(int client)
{
    return GetEntPropFloat(client, Prop_Data, "m_fLerpTime");
}

void GetClientFixedName(int client, char[] name, int length)
{
    GetClientName(client, name, length);
    if (StrContains(name, "NPC") != -1)
        strcopy(name, length, "AI");
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (event.GetInt("team") == L4D2Team_None)
    {
        g_bTankHudActive[client] = false;
    }
}