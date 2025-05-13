#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>

#define DEBUG 0
#define PLUGIN_VERSION "2.0"
#define TEAM_SPECTATOR 1
#define TEAM_INFECTED 3
#define ZOMBIECLASS_TANK 8

// 双重坦克控制相关变量
bool g_bTriggered;
float vecPos[3], vecAng[3];

// 怒气管理相关变量
ConVar g_cvRefillLimit;
int g_iRefillLimit;
GlobalForward g_fwdOnPassesChanged;
Handle g_hTankData;

public Plugin myinfo =
{
    name = "L4D2 Dual Tank Control with Anger Management",
    author = "KevonLin/AI",
    description = "Spawn AI tank with anger management system",
    version = PLUGIN_VERSION,
    url = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    RegPluginLibrary("l4d2_tank_frustration");
    
    CreateNative("MTAM_GetTankPasses", Native_GetTankPasses);
    
    g_fwdOnPassesChanged = new GlobalForward("MTAM_OnPassesChanged", 
        ET_Ignore, Param_Cell, Param_Cell);
    
    return APLRes_Success;
}

public void OnPluginStart()
{
    // 双重坦克控制初始化
    HookEvent("tank_spawn", Event_TankSpawn);
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

    // 怒气管理系统初始化
    g_cvRefillLimit = CreateConVar("sm_tank_refill_limit", "1", 
        "Number of times each Tank can refill anger", _, true, 0.0);
    g_iRefillLimit = g_cvRefillLimit.IntValue;
    g_cvRefillLimit.AddChangeHook(OnConVarChanged);

    g_hTankData = CreateTrie();

    HookEvent("tank_killed", Event_TankDeath);
    HookEvent("player_death", Event_PlayerDeath);
}

public void OnMapStart()
{
    g_bTriggered = false;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    g_bTriggered = false;
    ClearTrie(g_hTankData);
}

// 双重坦克控制功能
public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    // 怒气管理系统初始化
    if (IsValidTank(client))
    {
        int data[2];
        data[0] = 0; // Refill count
        data[1] = 1; // Alive state
        char key[12];
        IntToString(EntIndexToEntRef(client), key, sizeof(key));
        SetTrieArray(g_hTankData, key, data, sizeof(data));
    }

    // 双重坦克生成逻辑
    if(client && IsClientInGame(client) && GetClientTeam(client) == TEAM_INFECTED && !g_bTriggered)
    {
        g_bTriggered = true;

        GetClientAbsOrigin(client, vecPos);
        GetClientEyeAngles(client, vecAng);

        CreateTimer(5.0, Timer_SpawnAITank, _, TIMER_FLAG_NO_MAPCHANGE);
    }
}

Action Timer_SpawnAITank(Handle timer)
{
    int tank = L4D2_SpawnTank(vecPos, vecAng);
    if(tank != -1)
    {
        // 延迟初始化确保坦克完全生成
        CreateTimer(0.1, Timer_InitTankData, EntIndexToEntRef(tank), TIMER_FLAG_NO_MAPCHANGE);
        CreateTimer(3.0, Timer_TransferControl, EntIndexToEntRef(tank), TIMER_FLAG_NO_MAPCHANGE);
    }
    return Plugin_Continue;
}

Action Timer_InitTankData(Handle timer, any ref)
{
    int tank = EntRefToEntIndex(ref);
    if(tank != INVALID_ENT_REFERENCE && IsValidTank(tank))
    {
        char key[12];
        IntToString(ref, key, sizeof(key));
        
        int data[2];
        data[0] = 0;
        data[1] = 1;
        SetTrieArray(g_hTankData, key, data, sizeof(data));
    }
    return Plugin_Continue;
}

Action Timer_TransferControl(Handle timer, any ref)
{
    int oldTank = EntRefToEntIndex(ref);
    if(oldTank == INVALID_ENT_REFERENCE) return Plugin_Stop;

    int aiClient = GetClientOfTank();
    if(aiClient == -1) return Plugin_Stop;
    
    ArrayList eligible = new ArrayList();
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED && 
            !IsFakeClient(i) && IsPlayerAlive(i) && 
            GetEntProp(i, Prop_Send, "m_zombieClass") != ZOMBIECLASS_TANK)
        {
            eligible.Push(i);
        }
    }
    
    if(eligible.Length > 0)
    {
        int target = eligible.Get(GetRandomInt(0, eligible.Length - 1));
        
        // 先保存旧坦克的数据
        char oldKey[12];
        IntToString(EntIndexToEntRef(aiClient), oldKey, sizeof(oldKey));
        
        int data[2];
        if(!GetTrieArray(g_hTankData, oldKey, data, sizeof(data)))
        {
            data[0] = 0;
            data[1] = 1;
        }
        
        // 执行控制权转移
        L4D_ReplaceTank(aiClient, target);
        
        // 等待1帧确保坦克实体完成转移
        DataPack dp = new DataPack();
        dp.WriteCell(target);
        dp.WriteCellArray(data, sizeof(data));
        RequestFrame(OnNextFrame, dp);
    }
    
    delete eligible;
    return Plugin_Continue;
}

void OnNextFrame(DataPack dp)
{
    dp.Reset();
    int client = dp.ReadCell();
    int data[2];
    dp.ReadCellArray(data, sizeof(data));
    delete dp;

    if(IsValidTank(client))
    {
        char newKey[12];
        IntToString(EntIndexToEntRef(client), newKey, sizeof(newKey));
        SetTrieArray(g_hTankData, newKey, data, sizeof(data));
        
        #if DEBUG
        PrintToChatAll("成功转移怒气数据到 %N (次数: %d)", client, data[0]);
        #endif
    }
}

// 怒气管理系统功能
public int Native_GetTankPasses(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    if (!IsValidTank(client))
        return -1;
    
    char key[12];
    IntToString(EntIndexToEntRef(client), key, sizeof(key));
    
    int data[2];
    if (!GetTrieArray(g_hTankData, key, data, sizeof(data)))
        return -1;
    
    return data[0];
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    g_iRefillLimit = StringToInt(newValue);
}

public void Event_TankDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    RemoveTankData(client);
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsValidTank(client))
    {
        RemoveTankData(client);
    }
}

public void OnClientDisconnect(int client)
{
    RemoveTankData(client);
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
    if (IsValidTank(client))
    {
        char key[12];
        IntToString(EntIndexToEntRef(client), key, sizeof(key));
        
        int data[2];
        if (GetTrieArray(g_hTankData, key, data, sizeof(data)))
        {
            int anger = GetEntProp(client, Prop_Send, "m_frustration");
            
            if (anger >= 95)
            {
                if(data[0] < g_iRefillLimit)
                {
                    SetEntProp(client, Prop_Send, "m_frustration", 0);
                    data[0]++;
                    SetTrieArray(g_hTankData, key, data, sizeof(data));
                    
                    Call_StartForward(g_fwdOnPassesChanged);
                    Call_PushCell(client);
                    Call_PushCell(data[0]);
                    Call_Finish();

                    for (int i = 1; i <= MaxClients; i++) 
                    {
                        if (!IsClientInGame(i) || IsFakeClient(i))
                            continue;

                        if (client == i) 
                            CPrintToChat(i, "{red}<{default}Tank Rage{red}> Refilled");
                        else if (GetClientTeam(i) != L4D_TEAM_SURVIVOR)
                            CPrintToChat(i, "{red}<{default}Tank Rage{red}> %N Refilled", client);
                    }
                }
                ForcePlayerSuicide(client);
            }
        }
    }
    return Plugin_Continue;
}

// 辅助函数
int GetClientOfTank()
{
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i) && IsFakeClient(i) && 
            GetClientTeam(i) == TEAM_INFECTED && 
            GetEntProp(i, Prop_Send, "m_zombieClass") == ZOMBIECLASS_TANK && 
            IsPlayerAlive(i))
        {
            return i;
        }
    }
    return -1;
}

void RemoveTankData(int client)
{
    if (client < 1 || client > MaxClients || !IsClientInGame(client))
        return;

    char key[12];
    IntToString(EntIndexToEntRef(client), key, sizeof(key));
    RemoveFromTrie(g_hTankData, key);
}

bool IsValidTank(int client)
{
    return client > 0 && client <= MaxClients && 
        IsClientInGame(client) && 
        GetClientTeam(client) == TEAM_INFECTED && 
        GetEntProp(client, Prop_Send, "m_zombieClass") == ZOMBIECLASS_TANK;
}