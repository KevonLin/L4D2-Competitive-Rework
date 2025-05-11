#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2util>

#define DEBUG 0
#define DEFAULT_CHARGER_SPEED_FACTOR 1.00
float g_fChargerSpeedFactor[MAXPLAYERS + 1] = { 1.00, ... };
int g_iPlayerChargerScore[MAXPLAYERS + 1] = { 0, ...};

ConVar g_hIncreasedPerHealth,
    g_hIncreasedFactor;

int g_increasedPerHealth;

float g_fIncreasedFactor;

public Plugin myinfo = {
    name = "Charger Growth System",
    author = "KevonLin",
    description = "Set unique Charger charge speed per client",
    version = "1.1",
    url = "https://github.com/KevonLin"
};

public void OnPluginStart() {
    g_hIncreasedPerHealth = CreateConVar("charger_increased_speed_per_damage", "5", "Changer每造成多少伤害提高速度倍率, 0=禁用", FCVAR_NOTIFY, true, 0.0, true, 100.0);
    g_hIncreasedFactor = CreateConVar("charger_increased_speed_factor", "0.01", "影响速度的倍率, 0=禁用", FCVAR_NOTIFY, true, 0.0, true, 100.0);
    
    HookEvent("player_death", Event_PlayerDeath_Post, EventHookMode_Post);
    HookEvent("player_hurt", Event_PlayerHurt_Post, EventHookMode_Post);
    HookEvent("ability_use", Event_AbilityUse_Post, EventHookMode_Post);
    HookEvent("charger_charge_end", Event_ChargerChargeEnd_Pre, EventHookMode_Pre);
    HookEvent("charger_carry_end", Event_ChargerChargeEnd_Pre, EventHookMode_Pre);
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

    g_increasedPerHealth = g_hIncreasedPerHealth.IntValue;
    g_fIncreasedFactor = g_hIncreasedFactor.FloatValue;

    g_hIncreasedPerHealth.AddChangeHook(Cvar_Changed);
    g_hIncreasedFactor.AddChangeHook(Cvar_Changed);
}

void Cvar_Changed(ConVar hConVar, const char[] sOldValue, const char[] sNewValue) {
    g_increasedPerHealth = g_hIncreasedPerHealth.IntValue;
    g_fIncreasedFactor = g_hIncreasedFactor.FloatValue;
}

void Event_AbilityUse_Post (Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClientIndex(client) || !IsClientInGame(client)) return;
    if (GetClientTeam(client) != view_as<int>(L4DTeam_Infected) || GetInfectedClass(client) != view_as<int>(L4D2ZombieClass_Charger)) return;
    char abilityName[32];
    event.GetString("ability", abilityName, 32);
    if (!StrEqual(abilityName, "ability_charge", false)) return;
    
    #if DEBUG
    PrintToChatAll("修改速度属性中...");
    #endif

    SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_fChargerSpeedFactor[client]);

    #if DEBUG
    PrintToChatAll("%N 的 m_flLaggedMovementValue 属性值修改为 %f", client, g_fChargerSpeedFactor[client]);
    #endif
}

void Event_ChargerChargeEnd_Pre (Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClientIndex(client) || !IsClientInGame(client)) return;

    SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", DEFAULT_CHARGER_SPEED_FACTOR);
}

public void OnClientPutInServer(int client) {
    if(!IsValidClientIndex(client)) return;
    g_fChargerSpeedFactor[client] = DEFAULT_CHARGER_SPEED_FACTOR;
    g_iPlayerChargerScore[client] = 0;
}

public void OnClientDisconnect(int client) {
    if(!IsValidClientIndex(client)) return;
    g_fChargerSpeedFactor[client] = DEFAULT_CHARGER_SPEED_FACTOR;
    g_iPlayerChargerScore[client] = 0;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast){
    for(int i = 0; i <= MaxClients; i++) {
        if (!IsValidClientIndex(i) || !IsClientInGame(i)) return Plugin_Continue;
        g_fChargerSpeedFactor[i] = DEFAULT_CHARGER_SPEED_FACTOR;
        g_iPlayerChargerScore[i] = 0;
    }
    return Plugin_Continue;
}

public Action Event_PlayerDeath_Post(Event event, const char[] name, bool dontBroadcast) {
    #if DEBUG
    PrintToChatAll("进入玩家死亡事件...");
    #endif

    int client = GetClientOfUserId(event.GetInt("userid"));

    #if DEBUG
    PrintToChatAll("获取到的玩家ID为：%d", client);
    #endif

    if (!IsValidClientIndex(client) || !IsClientInGame(client)) return Plugin_Continue;

    #if DEBUG
    PrintToChatAll("死亡玩家ID合法");
    #endif

    if (GetClientTeam(client) != TEAM_SURVIVOR) return Plugin_Continue;

    #if DEBUG
    PrintToChatAll("死亡玩家是生还");
    #endif

    for (int i = 0; i <= MaxClients; i++) {
        g_fChargerSpeedFactor[i] = DEFAULT_CHARGER_SPEED_FACTOR;
        g_iPlayerChargerScore[i] = 0;
    }

    #if DEBUG
    PrintToChatAll("清除所有玩家成长值...");
    #endif

    return Plugin_Continue;
}

public Action Event_PlayerHurt_Post(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("attacker"));
    if (!IsValidClientIndex(client) || !IsClientInGame(client)) return Plugin_Continue;
    if (GetClientTeam(client) != view_as<int>(L4DTeam_Infected) || GetInfectedClass(client) != view_as<int>(L4D2ZombieClass_Charger)) return Plugin_Continue;
    if (IsClientIncapacitated(client)) return Plugin_Continue;

    int damage = event.GetInt("dmg_health");

    g_iPlayerChargerScore[client] += damage;
    g_fChargerSpeedFactor[client] = DEFAULT_CHARGER_SPEED_FACTOR +  (g_iPlayerChargerScore[client] / g_increasedPerHealth) * g_fIncreasedFactor;

    return Plugin_Continue;
}

bool IsClientIncapacitated(int client) {
    if (!IsValidClientIndex(client) || !IsClientInGame(client)) return false;
    return GetEntProp(client, Prop_Send, "m_isIncapacitated") == 1;
}