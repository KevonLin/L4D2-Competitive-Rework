#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>

#define TEAM_SPECTATOR 1
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

ArrayList g_hJoinQueue;

enum struct QueueInfo
{
    int userid;
    int queuetype;
    int jointime;
}

public Plugin myinfo = 
{
    name = "L4D2 Join Queue System",
    author = "KevonLin",
    description = "Advanced team queue management system",
    version = "1.2",
    url = "https://github.com/KevonLin"
};

public void OnPluginStart()
{
    RegConsoleCmd("sm_join", Command_JoinMenu);
    AddCommandListener(Command_JoinTeam, "jointeam");
    
    g_hJoinQueue = new ArrayList(sizeof(QueueInfo));
}

public Action Command_JoinTeam(int client, const char[] command, int argc)
{
    if (!client || !IsClientInGame(client))
        return Plugin_Continue;

    char teamArg[32];
    GetCmdArg(1, teamArg, sizeof(teamArg));

    int targetTeam;
    if (StringToIntEx(teamArg, targetTeam) == 0)
    {
        if (StrEqual(teamArg, "survivor", false))
            targetTeam = TEAM_SURVIVOR;
        else if (StrEqual(teamArg, "infected", false))
            targetTeam = TEAM_INFECTED;
        else
            return Plugin_Continue;
    }

    if (GetClientTeam(client) !=  TEAM_SPECTATOR)
    {
        ChangeClientTeam(client, TEAM_SPECTATOR);
    }

    if (targetTeam == TEAM_SURVIVOR)
    {
        AddToQueue(client, 2);
        CPrintToChat(client, "{green}[SM] {default}已加入生还者队列");
        return Plugin_Handled;
    } else if (targetTeam == TEAM_INFECTED)
    {
        AddToQueue(client, 3);
        CPrintToChat(client, "{green}[SM] {default}已加入感染者队列");
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public Action Timer_ShowMenu(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if(client && IsClientInGame(client))
    {
        ShowJoinMenu(client);
    }
    return Plugin_Stop;
}

public void OnClientDisconnect(int client)
{
    RemoveFromQueue(client);
    TryFillSlots();
}

public Action Command_JoinMenu(int client, int args)
{
    if(GetClientTeam(client) != TEAM_SPECTATOR)
    {
        CPrintToChat(client, "{green}[SM] {default}你已在游戏中!");
        return Plugin_Handled;
    }
    if(!client || !IsClientInGame(client)) return Plugin_Handled;
    
    ShowJoinMenu(client);
    return Plugin_Handled;
}

void ShowJoinMenu(int client)
{
    Menu menu = new Menu(MenuHandler_Join);
    menu.SetTitle("选择加入队列：");
    
    menu.AddItem("1", "通用队列");
    menu.AddItem("2", "生还队列");
    menu.AddItem("3", "特感队列");
    
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Join(Menu menu, MenuAction action, int client, int param)
{
    if(action == MenuAction_Select && IsClientInGame(client))
    {
        char info[8];
        menu.GetItem(param, info, sizeof(info));
        
        switch(info[0])
        {
            case '1': AddToQueue(client, 1);
            case '2': AddToQueue(client, 2);
            case '3': AddToQueue(client, 3);
        }
    }
    else if(action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void AddToQueue(int client, int queuetype)
{
    RemoveFromQueue(client);
    
    QueueInfo info;
    info.userid = GetClientUserId(client);
    info.queuetype = queuetype;
    info.jointime = GetTime();
    
    g_hJoinQueue.PushArray(info);
    
    TryFillSlots();
}

void RemoveFromQueue(int client)
{
    int userid = GetClientUserId(client);
    
    for(int i = g_hJoinQueue.Length-1; i >= 0; i--)
    {
        QueueInfo info;
        g_hJoinQueue.GetArray(i, info);
        if(info.userid == userid)
        {
            g_hJoinQueue.Erase(i);
        }
    }
}

void TryFillSlots()
{
    // 检查生还者空位
    int survivorSlots = FindEmptySurvivorSlots();
    if(survivorSlots > 0)
    {
        AttemptFillTeam(TEAM_SURVIVOR);
    }
    
    // 检查特感空位
    int infectedSlots = FindEmptyInfectedSlots();
    if(infectedSlots > 0)
    {
        AttemptFillTeam(TEAM_INFECTED);
    }
}

void AttemptFillTeam(int team)
{
    ArrayList candidates = new ArrayList(sizeof(QueueInfo));
    
    // 收集符合条件的候选人
    for(int i = 0; i < g_hJoinQueue.Length; i++)
    {
        QueueInfo info;
        g_hJoinQueue.GetArray(i, info);
        
        if((team == TEAM_SURVIVOR && (info.queuetype == 1 || info.queuetype == 2)) ||
           (team == TEAM_INFECTED && (info.queuetype == 1 || info.queuetype == 3)))
        {
            candidates.PushArray(info);
        }
    }
    
    // 按加入时间排序
    candidates.SortCustom(SortByJoinTime);
    
    // 尝试添加玩家
    for(int i = 0; i < candidates.Length; i++)
    {
        QueueInfo info;
        candidates.GetArray(i, info);
        
        int client = GetClientOfUserId(info.userid);
        if(client && IsClientInGame(client) && GetClientTeam(client) == TEAM_SPECTATOR)
        {
            if(team == TEAM_SURVIVOR && FindEmptySurvivorSlots() > 0)
            {
                AddToSurvivors(client);
                RemoveFromQueue(client);
                break;
            }
            else if(team == TEAM_INFECTED && FindEmptyInfectedSlots() > 0)
            {
                AddToInfected(client);
                RemoveFromQueue(client);
                break;
            }
        }
    }
    
    delete candidates;
}

int SortByJoinTime(int index1, int index2, Handle array, Handle hndl)
{
    QueueInfo info1, info2;
    GetArrayArray(array, index1, info1);
    GetArrayArray(array, index2, info2);
    
    return info1.jointime - info2.jointime;
}

int FindSurvivorBot()
{
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i) 
        && IsFakeClient(i) 
        && GetClientTeam(i) == TEAM_SURVIVOR 
        && IsPlayerAlive(i)
        && !HasHumanSpectator(i)) // 新增检查函数
        {
            return i;
        }
    }
    return -1;
}

int FindEmptySurvivorSlots()
{
    return GetConVarInt(FindConVar("survivor_limit")) - GetTeamHumanCount(TEAM_SURVIVOR);
}

int FindEmptyInfectedSlots()
{
    return GetConVarInt(FindConVar("z_max_player_zombies")) - GetTeamHumanCount(TEAM_INFECTED);
}

void AddToSurvivors(int client)
{
    int bot = FindSurvivorBot();
    if(bot != -1)
    {
        // 确保玩家在旁观者队伍
        if(GetClientTeam(client) != TEAM_SPECTATOR)
        {
            ChangeClientTeam(client, TEAM_SPECTATOR);
        }
        
        // 确保玩家处于存活状态
        if(!IsPlayerAlive(client))
        {
            L4D_RespawnPlayer(client);
        }

        // 设置观察目标为找到的Bot
        SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", bot);
        SetEntProp(client, Prop_Send, "m_iObserverMode", 5);

        // 设置人类旁观关系
        L4D_SetHumanSpec(bot, client);
        
        // 增加延迟确保设置生效
        DataPack dp = new DataPack();
        dp.WriteCell(GetClientUserId(client));
        dp.WriteCell(GetClientUserId(bot));
        CreateTimer(0.2, Timer_TakeOverBot, dp);
    }
    else
    {
        CPrintToChat(client, "{green}[SM] {default}当前没有可用的生还者Bot。");
    }
}

public Action Timer_TakeOverBot(Handle timer, DataPack dp)
{
    dp.Reset();
    int client = GetClientOfUserId(dp.ReadCell());
    int bot = GetClientOfUserId(dp.ReadCell());
    delete dp;

    if(client && IsClientInGame(client))
    {
        // 再次验证Bot有效性
        if(bot && IsClientInGame(bot) && IsFakeClient(bot))
        {
            // 强制设置观察目标
            SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", bot);
            L4D_TakeOverBot(client);
            
            // 确保接管成功
            if(GetClientTeam(client) != TEAM_SURVIVOR)
            {
                CPrintToChat(client, "{green}[SM] {default}接管失败，请重试。");
            }
        }
        else
        {
            CPrintToChat(client, "{green}[SM] {default}目标Bot已失效。");
        }
    }

    return Plugin_Handled;
}

void AddToInfected(int client)
{
    ChangeClientTeam(client, TEAM_INFECTED);
}

stock int GetTeamHumanCount(int team)
{
    int count = 0;
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == team)
        {
            count++;
        }
    }
    return count;
}

bool HasHumanSpectator(int bot)
{
    return GetClientOfUserId(GetEntProp(bot, Prop_Send, "m_humanSpectatorUserID")) != 0;
}