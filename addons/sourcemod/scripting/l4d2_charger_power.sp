#pragma semicolon 1
#pragma newdecls required

/*

	Created by DJ_WEST - 2020 update by Silvers.

	Web: http://amx-x.ru
	AMX Mod X and SourceMod Russian Community

*/

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.3.2"
#define TEAM_INFECTED 3
#define CLASS_CHARGER 6
#define PROP_CAR (1<<0)
#define PROP_CAR_ALARM (1<<1)
#define PROP_CONTAINER	(1<<2)
#define PROP_TRUCK (1<<3)
#define PUSH_COUNT "m_iHealth"

ConVar g_h_CvarChargerPower, g_h_CvarChargerCarry, g_h_CvarMessageType, g_h_CvarObjects, g_h_CvarPushLimit, g_h_CvarRemoveObject, g_h_CvarChargerDamage;

public Plugin myinfo =
{
	name = "Charger Power",
	author = "DJ_WEST",
	description = "Allows charger to move objects (containers, cars, trucks) by hitting them when using own ability",
	version = PLUGIN_VERSION,
	url = "http://amx-x.ru"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("charger_power.phrases");

	CreateConVar("charger_power_version", PLUGIN_VERSION, "Charger Power version", FCVAR_DONTRECORD|FCVAR_REPLICATED|FCVAR_NOTIFY);
	g_h_CvarChargerPower = CreateConVar("l4d2_charger_power", "1000.0", "Charger hit power", FCVAR_NOTIFY, true, 0.0, true, 5000.0);
	g_h_CvarChargerCarry = CreateConVar("l4d2_charger_power_carry", "1", "Can move objects if charger carry the player", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_h_CvarMessageType = CreateConVar("l4d2_charger_power_message_type", "0", "Message type (0 - disable, 1 - chat, 2 - hint, 3 - instructor hint)", FCVAR_NOTIFY, true, 0.0, true, 3.0);
	g_h_CvarObjects = CreateConVar("l4d2_charger_power_objects", "15", "Can move objects this type (1 - car, 2 - car alarm, 4 - container, 8 - truck)", FCVAR_NOTIFY, true, 1.0, true, 15.0);
	g_h_CvarPushLimit = CreateConVar("l4d2_charger_power_push_limit", "3", "How many times object can be moved", FCVAR_NOTIFY, true, 1.0, true, 100.0);
	g_h_CvarRemoveObject = CreateConVar("l4d2_charger_power_remove", "60", "Remove moved object after some time (in seconds)", FCVAR_NOTIFY, true, 0.0, true, 100.0);
	g_h_CvarChargerDamage = CreateConVar("l4d2_charger_power_damage", "80", "Additional damage to charger from moving objects", FCVAR_NOTIFY, true, 0.0, true, 100.0);
	
	//Autoconfig for plugin
	AutoExecConfig(true, "l4d2_charger_power");

	HookEvent("charger_charge_end", EventChargeEnd);
	HookEvent("player_spawn", EventPlayerSpawn);
}

void EventChargeEnd(Event h_Event, const char[] s_Name, bool b_DontBroadcast)
{
	int i_UserID, i_Client;
	int i_Target, i_Type, i_PushCount, i_Health, i_Damage, i_RemoveTime;
	float f_Origin[3], f_Angles[3];

	i_UserID = h_Event.GetInt("userid");
	i_Client = GetClientOfUserId(i_UserID);

	if (!i_Client || !IsClientInGame(i_Client))
		return;

	if (!g_h_CvarChargerCarry.IntValue && GetEntProp(i_Client, Prop_Send, "m_carryVictim") > 0)
		return;

	GetClientAbsOrigin(i_Client, f_Origin);
	GetClientAbsAngles(i_Client, f_Angles);
	f_Origin[2] += 20.0;

	Handle h_Trace = TR_TraceRayFilterEx(f_Origin, f_Angles, MASK_ALL, RayType_Infinite, TraceFilterClients, i_Client);

	if (TR_DidHit(h_Trace))
	{
		float f_EndOrigin[3];

		i_Target = TR_GetEntityIndex(h_Trace);
		TR_GetEndPosition(f_EndOrigin, h_Trace);
		delete h_Trace;

		if (i_Target && IsValidEdict(i_Target) && GetVectorDistance(f_Origin, f_EndOrigin) <= 100.0)
		{
			if (GetEntityMoveType(i_Target) != MOVETYPE_VPHYSICS)
			{
				return;
			}

			i_PushCount = GetEntProp(i_Target, Prop_Data, PUSH_COUNT);

			if (i_PushCount >= g_h_CvarPushLimit.IntValue)
			{
				return;
			}

			i_Type = g_h_CvarObjects.IntValue;

			char s_ClassName[16];
			GetEdictClassname(i_Target, s_ClassName, sizeof(s_ClassName));

			if (StrEqual(s_ClassName, "prop_physics") || StrEqual(s_ClassName, "prop_car_alarm"))
			{
				char s_ModelName[64];
				GetEntPropString(i_Target, Prop_Data, "m_ModelName", s_ModelName, sizeof(s_ModelName));

				if (StrEqual(s_ClassName, "prop_car_alarm") && !(i_Type & PROP_CAR_ALARM))
					return;
				else if (StrContains(s_ModelName, "car") != -1 && !(i_Type & PROP_CAR) && !(i_Type & PROP_CAR_ALARM))
					return;
				else if (StrContains(s_ModelName, "dumpster") != -1 && !(i_Type & PROP_CONTAINER))
					return;
				else if (StrContains(s_ModelName, "forklift") != -1 && !(i_Type & PROP_TRUCK))
					return;

				i_PushCount++;
				SetEntProp(i_Target, Prop_Data, PUSH_COUNT, i_PushCount);

				float f_Velocity[3], f_Power;

				GetAngleVectors(f_Angles, f_Velocity, NULL_VECTOR, NULL_VECTOR);
				f_Power = g_h_CvarChargerPower.FloatValue;
				f_Velocity[0] *= f_Power;
				f_Velocity[1] *= f_Power;
				f_Velocity[2] *= f_Power;
				SetEntPropEnt(i_Target, Prop_Data, "m_hPhysicsAttacker", i_Client);
				SetEntPropFloat(i_Target, Prop_Data, "m_flLastPhysicsInfluenceTime", GetGameTime()); 
				TeleportEntity(i_Target, NULL_VECTOR, NULL_VECTOR, f_Velocity);

				DataPack h_Pack;
				CreateDataTimer(0.5, CheckEntity, h_Pack);
				h_Pack.WriteCell(EntIndexToEntRef(i_Target));
				h_Pack.WriteFloat(f_EndOrigin[0]);

				i_Damage = g_h_CvarChargerDamage.IntValue;
				if (i_Damage)
				{
					i_Health = GetClientHealth(i_Client);
					i_Health -= i_Damage;

					if (i_Health > 0)
						SetEntityHealth(i_Client, i_Health);
					else
						ForcePlayerSuicide(i_Client);
				}

				i_RemoveTime = g_h_CvarRemoveObject.IntValue;
				if (i_RemoveTime)
					CreateTimer(float(i_RemoveTime), TimerRemoveEntity, EntIndexToEntRef(i_Target), TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
	delete h_Trace;
}

Action TimerRemoveEntity(Handle h_Timer, any i_Ent)
{
	if (EntRefToEntIndex(i_Ent) != INVALID_ENT_REFERENCE )
	{
		RemoveEntity(i_Ent);
	}

	return Plugin_Continue;
}

bool TraceFilterClients(int i_Entity, int i_Mask, any i_Data)
{
	if (i_Entity == i_Data)
		return false;

	if (1 <= i_Entity <= MaxClients)
		return false;

	return true;
}

Action CheckEntity(Handle h_Timer, DataPack h_Pack)
{
	int i_Ent;

	h_Pack.Reset(false);
	i_Ent = h_Pack.ReadCell();
	i_Ent = EntRefToEntIndex(i_Ent);
	if( i_Ent == INVALID_ENT_REFERENCE)
	{
		return Plugin_Continue;
	}

	float f_LastOrigin = h_Pack.ReadFloat();

	if (IsValidEdict(i_Ent))
	{
		float f_Origin[3];
		GetEntPropVector(i_Ent, Prop_Data, "m_vecOrigin", f_Origin);

		if (f_Origin[0] != f_LastOrigin)
		{
			DataPack h_NewPack;
			CreateDataTimer(0.1, CheckEntity, h_NewPack);
			h_NewPack.WriteCell(EntIndexToEntRef(i_Ent));
			h_NewPack.WriteFloat(f_Origin[0]);
		}
		else
			TeleportEntity(i_Ent, NULL_VECTOR, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
	}

	return Plugin_Continue;
}

void EventPlayerSpawn(Event h_Event, const char[] s_Name, bool b_DontBroadcast)
{
	int i_UserID, i_Client;

	i_UserID = h_Event.GetInt("userid");
	i_Client = GetClientOfUserId(i_UserID);

	if (i_Client && IsClientInGame(i_Client) && !IsFakeClient(i_Client) && GetClientTeam(i_Client) == TEAM_INFECTED && GetInfectedClass(i_Client) == CLASS_CHARGER)
	{
		DataPack h_Pack;
		CreateDataTimer(0.4, DelayDisplayHint, h_Pack);
		h_Pack.WriteCell(GetClientUserId(i_Client));
		h_Pack.WriteString("Move objects");
		h_Pack.WriteString("+attack");
	}
}

Action DelayDisplayHint(Handle h_Timer, DataPack h_Pack)
{
	int i_Client;
	char s_LanguageKey[16], s_Message[256], s_Bind[10];

	h_Pack.Reset(false);
	i_Client = h_Pack.ReadCell();
	i_Client = GetClientOfUserId(i_Client);
	if( !i_Client)
	{
		return Plugin_Continue;
	}

	h_Pack.ReadString(s_LanguageKey, sizeof(s_LanguageKey));
	h_Pack.ReadString(s_Bind, sizeof(s_Bind));

	switch (g_h_CvarMessageType.IntValue)
	{
		case 1:
		{
			FormatEx(s_Message, sizeof(s_Message), "\x03[%T]\x01 %T.", "Information", i_Client, s_LanguageKey, i_Client);
			ReplaceString(s_Message, sizeof(s_Message), "\n", " ");
			PrintToChat(i_Client, s_Message);
		}
		case 2: PrintHintText(i_Client, "%T", s_LanguageKey, i_Client);
		case 3:
		{
			FormatEx(s_Message, sizeof(s_Message), "%T", s_LanguageKey, i_Client);
			DisplayInstructorHint(i_Client, s_Message, s_Bind);
		}
	}

	return Plugin_Continue;
}

void DisplayInstructorHint(int i_Client, char s_Message[256], char[] s_Bind)
{
	int i_Ent;
	char s_TargetName[32];

	i_Ent = CreateEntityByName("env_instructor_hint");
	FormatEx(s_TargetName, sizeof(s_TargetName), "hint%d", i_Client);
	ReplaceString(s_Message, sizeof(s_Message), "\n", " ");
	DispatchKeyValue(i_Client, "targetname", s_TargetName);
	DispatchKeyValue(i_Ent, "hint_target", s_TargetName);
	DispatchKeyValue(i_Ent, "hint_timeout", "5");
	DispatchKeyValue(i_Ent, "hint_range", "0.01");
	DispatchKeyValue(i_Ent, "hint_color", "255 255 255");
	DispatchKeyValue(i_Ent, "hint_icon_onscreen", "use_binding");
	DispatchKeyValue(i_Ent, "hint_caption", s_Message);
	DispatchKeyValue(i_Ent, "hint_binding", s_Bind);
	DispatchSpawn(i_Ent);
	AcceptEntityInput(i_Ent, "ShowHint");

	DataPack h_RemovePack;
	CreateDataTimer(5.0, RemoveInstructorHint, h_RemovePack);
	h_RemovePack.WriteCell(EntIndexToEntRef(i_Ent));
	h_RemovePack.WriteCell(GetClientUserId(i_Client));
}

Action RemoveInstructorHint(Handle h_Timer, DataPack h_Pack)
{
	int i_Client;

	h_Pack.Reset(false);

	// Entity
	int i_Ent = h_Pack.ReadCell();

	if (EntRefToEntIndex(i_Ent) != INVALID_ENT_REFERENCE)
	{
		RemoveEntity(i_Ent);
	}

	// Client
	i_Client = h_Pack.ReadCell();
	i_Client = GetClientOfUserId(i_Client);

	if( !i_Client || !IsClientInGame(i_Client))
	{
		return Plugin_Continue;
	}

	// ClientCommand(i_Client, "gameinstructor_enable 0");

	DispatchKeyValue(i_Client, "targetname", "");

	return Plugin_Continue;
}

stock int GetInfectedClass(int i_Client)
{
	return GetEntProp(i_Client, Prop_Send, "m_zombieClass");
}

stock int IsValidEnt(int i_Ent)
{
	return (IsValidEdict(i_Ent) && IsValidEntity(i_Ent));
}
