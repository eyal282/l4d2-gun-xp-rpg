#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <smlib>
#include <GunXP-RPG>

#undef REQUIRE_PLUGIN
#include <actions>
#define REQUIRE_PLUGIN

#define PLUGIN_VERSION "1.0"

#pragma newdecls required

public Plugin myinfo = 
{
	name = "RolePlay - Missions.",
	author = "Author was lost, heavy edit by Eyal282",
	description = "Missions that expire by time.",
	version = PLUGIN_VERSION,
	url = "N/A"
}

bool g_dbFullConnected = false;

GlobalForward g_fwOnGetMaxDailyQuests;

Database g_dbDailyQuests;

char INSERT_OR_IGNORE_INTO[64];
char SQL_UNIX_TIMESTAMP[64];

enum enPrizeType
{
	PRIZE_XP=0
}

enum struct enQuest
{
	char sAlias[32];
	char sName[128];
	int minPrize;
	int maxPrize;
	int minObjective;
	int maxObjective;
	int minLevel;
	enPrizeType prizeType;
}

// Quest after being given to a client.
enum struct enClientQuest
{
	int DBSerialNumber;

	char sAlias[32];

	int userid;

	// How close we are to max prize in %. Min 0.0 Max 1.0
	float fPrizeRNG;

	// How close we are to hardest objective in %. Min 0.0 Max 1.0
	float fObjectiveRNG;
	
	// amount of progress made vs objective. If set to -1, the quest is completed.
	int QuestProgress;

	// The goal and prize will be calculated by using their respective RNG.
}

ArrayList g_aQuests;
ArrayList g_aClientQuests;

public void OnPluginStart()
{
	g_fwOnGetMaxDailyQuests = CreateGlobalForward("RPG_DailyQuests_OnGetMaxDailyQuests", ET_Ignore, Param_Cell, Param_CellByRef);

	g_aQuests = new ArrayList(sizeof(enQuest));
	g_aClientQuests = new ArrayList(sizeof(enClientQuest));

	CreateQuests();
	ConnectDatabase();
	
	RegConsoleCmd("sm_q", Command_Missions, "List of Missions");
	RegConsoleCmd("sm_quest", Command_Missions, "List of Missions");
	RegConsoleCmd("sm_quests", Command_Missions, "List of Missions");

	HookEvent("infected_death", Event_CommonDeath, EventHookMode_Pre);
	HookEvent("award_earned", Event_AwardEarned, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
}

public void OnMapStart()
{
	CheckResetQuestsTimer();
	
	CreateTimer(1.0, Timer_CheckWitchChase, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

public void OnClientPostAdminCheck(int client)
{
	if(GunXP_RPG_IsClientLoaded(client))
	{
		RequestFrame(Frame_FetchMissions, GetClientUserId(client));
	}
}

void CheckResetQuestsTimer()
{
	CreateTimer(86405.0 - (float(GetTime() % 86400)), Timer_ResetQuests, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_CheckWitchChase(Handle hTimer)
{
	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(RPG_Perks_GetZombieType(i) != ZombieType_NotInfected)
			continue;

		else if(!HasWitchAttacker(i))
			continue;

		AddClientQuestProgress(i, "Survive Witch (sec)");
	}

	return Plugin_Continue;
}

public Action Timer_ResetQuests(Handle hTimer)
{
	g_aClientQuests.Clear();

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(IsFakeClient(i))
			continue;
		
		RequestFrame(Frame_FetchMissions, GetClientUserId(i));
	}

	CheckResetQuestsTimer();
	
	return Plugin_Stop;
}

public Action Event_AwardEarned(Handle hEvent, const char[] Name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if(client == 0)
		return Plugin_Continue;

	int award = GetEventInt(hEvent, "award");

	if(award != 8)
		return Plugin_Continue;

	if(L4D_IsMissionFinalMap() && GetConVarBool(FindConVar("rpg_tanks_instant_finale")))
		return Plugin_Continue;

	AddClientQuestProgress(client, "Beat Maps");

	return Plugin_Continue;
}
public Action Event_CommonDeath(Handle hEvent, const char[] Name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "attacker"));

	if(client == 0)
		return Plugin_Continue;

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(RPG_Perks_GetZombieType(i) != ZombieType_NotInfected)
			continue;

		AddClientQuestProgress(i, "Kill CI");
	}

	return Plugin_Continue;
}

public Action Event_PlayerDeath(Handle hEvent, char[] Name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(victim == 0)
		return Plugin_Continue;

	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	
	if(attacker == victim || attacker == 0)
		return Plugin_Continue;

	AddClientQuestProgress(attacker, "Kill SI");

	return Plugin_Continue;
}

public void GunXP_Skills_OnMultiJump(int client, bool bMultiJump)
{
	AddClientQuestProgress(client, "Jump");
}

public void RPG_Tanks_OnRPGTankCastActiveAbility(int client, int abilityIndex)
{
	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(RPG_Perks_GetZombieType(i) != ZombieType_NotInfected)
			continue;

		AddClientQuestProgress(i, "Survive Tank Abilities");
	}
}
public void RPG_Perks_OnGetReviveHealthPercent(int reviver, int victim, int &temporaryHealthPercent, int &permanentHealthPercent)
{
	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(RPG_Perks_GetZombieType(i) != ZombieType_NotInfected)
			continue;

		AddClientQuestProgress(i, "Revive Teammates");
	}
}
public void RPG_Tanks_OnUntieredTankKilled(int victim, int attacker)
{
	AddClientQuestProgress(attacker, "Kill Tanks");
}

public void RPG_Tanks_OnRPGTankKilled(int victim, int attacker, int XPReward)
{
	AddClientQuestProgress(attacker, "Kill Tiered Tanks");
	AddClientQuestProgress(attacker, "Kill Tanks");
}
public Action Command_Missions(int client, int args)
{
	Handle hMenu = CreateMenu(Missions_MenuHandler);

	char TempFormat[128];
	char name[128];
	int index = -1, progress, objective, prize;
	enPrizeType prizeType;
	bool bCompletedNow;

	while(GetClientQuests(client, "", index, 0, name, progress, objective, prize, prizeType, bCompletedNow))
	{
		if(progress == -1)
			Format(TempFormat, sizeof(TempFormat), "%s [%i/%i] [XP: %i] [COMPLETED]", name, objective, objective, prize);
		else
			Format(TempFormat, sizeof(TempFormat), "%s [%i/%i] [XP: %i]", name, progress, objective, prize);

		AddMenuItem(hMenu, "", TempFormat);
	}

	FormatTimeHMS(TempFormat, sizeof(TempFormat), RoundToFloor(86400.0 - (float(GetTime() % 86400))));

	SetMenuTitle(hMenu, "Complete daily quests for XP reward. This is unaffected by difficulty\nQuests marked as \"Team\" can be helped by your team.\nQuests reset in %s", TempFormat);

	SetMenuExitBackButton(hMenu, true);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public int Missions_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		hMenu = INVALID_HANDLE;
	}
	else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
	{
		FakeClientCommand(client, "sm_rpg");
	}
	else if(action == MenuAction_Select)
	{		
		FakeClientCommand(client, "sm_rpg");
		return 0;
	}	

	return 0;
}	

public void GunXP_OnReloadRPGPlugins()
{
	GunXP_ReloadPlugin();
}

public void GunXP_OnPlayerLoaded(int client)
{
	RequestFrame(Frame_FetchMissions, GetClientUserId(client));
}

public void CreateQuests()
{
	enQuest quest;

	quest.sAlias = "Kill Tanks";
	quest.sName = "Kill Tanks (Team)";
	quest.minPrize = 4000;
	quest.maxPrize = 8000;
	quest.minObjective = 10;
	quest.maxObjective = 50;
	quest.minLevel = 0;
	quest.prizeType = PRIZE_XP;
	g_aQuests.PushArray(quest);

	quest.sAlias = "Kill Tiered Tanks";
	quest.sName = "Kill Tiered Tanks (Team)";
	quest.minPrize = 8000;
	quest.maxPrize = 12000;
	quest.minObjective = 12;
	quest.maxObjective = 25;
	quest.minLevel = 25;
	quest.prizeType = PRIZE_XP;
	g_aQuests.PushArray(quest);

	quest.sAlias = "Kill SI";
	quest.sName = "Kill Special Infected";
	quest.minPrize = 3600;
	quest.maxPrize = 6400;
	quest.minObjective = 50;
	quest.maxObjective = 100;
	quest.minLevel = 0;
	quest.prizeType = PRIZE_XP;
	g_aQuests.PushArray(quest);

	quest.sAlias = "Kill CI";
	quest.sName = "Kill Common Infected (Team)";
	quest.minPrize = 2000;
	quest.maxPrize = 3700;
	quest.minObjective = 1500;
	quest.maxObjective = 3000;
	quest.minLevel = 0;
	quest.prizeType = PRIZE_XP;
	g_aQuests.PushArray(quest);

	quest.sAlias = "Revive Teammates";
	quest.sName = "Revive Teammates (Team)";
	quest.minPrize = 2100;
	quest.maxPrize = 3800;
	quest.minObjective = 40;
	quest.maxObjective = 70;
	quest.minLevel = 0;
	quest.prizeType = PRIZE_XP;
	g_aQuests.PushArray(quest);

	quest.sAlias = "Survive Tank Abilities";
	quest.sName = "Survive Tank Abilities";
	quest.minPrize = 5000;
	quest.maxPrize = 7500;
	quest.minObjective = 75;
	quest.maxObjective = 125;
	quest.minLevel = 35;
	quest.prizeType = PRIZE_XP;
	g_aQuests.PushArray(quest);

	quest.sAlias = "Beat Maps";
	quest.sName = "Beat Maps";
	quest.minPrize = 3000;
	quest.maxPrize = 5700;
	quest.minObjective = 10;
	quest.maxObjective = 20;
	quest.minLevel = 0;
	quest.prizeType = PRIZE_XP;
	g_aQuests.PushArray(quest);

	quest.sAlias = "Jump";
	quest.sName = "Jump";
	quest.minPrize = 1400;
	quest.maxPrize = 2500;
	quest.minObjective = 400;
	quest.maxObjective = 600;
	quest.minLevel = 0;
	quest.prizeType = PRIZE_XP;
	g_aQuests.PushArray(quest);


	SetupActionsBasedQuests();
}
#if defined _actions_included
void SetupActionsBasedQuests()
{
	enQuest quest;

	quest.sAlias = "Survive Witch (sec)";
	quest.sName = "Survive Witch (sec)";
	quest.minPrize = 4000;
	quest.maxPrize = 5300;
	quest.minObjective = 60;
	quest.maxObjective = 120;
	quest.minLevel = 0;
	quest.prizeType = PRIZE_XP;
	g_aQuests.PushArray(quest);
}
#else
void SetupActionsBasedQuests()
{
	return;
}
#endif

public void ConnectDatabase()
{
	char error[256];
	Database hndl;

	if(SQL_CheckConfig("GunXP-RPG"))
	{
		SQL_TConnect(SQLCB_DatabaseConnected, "GunXP-RPG");
	}
	else
	{
		INSERT_OR_IGNORE_INTO = "OR IGNORE INTO";
		SQL_UNIX_TIMESTAMP = "strftime('%s')";

		hndl = SQLite_UseDatabase("GunXP-RPG", error, sizeof(error));

		if(hndl == null)
		{
			SetFailState("Could not connect to SQLite. Error: %s", error);
		}
		else
		{
			g_dbDailyQuests = hndl;

			OnDatabaseConnected();
		}
	}
}


public void SQLTrans_SetFailState(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	SetFailState("Transaction at index %i failed:\n%s", failIndex, error);
}


public void SQLCB_Error(Handle owner, DBResultSet hndl, const char[] error, int QueryUniqueID)
{
	/* If something fucked up. */
	if (hndl == null)
		SetFailState("%s --> %i", error, QueryUniqueID);
}

public void SQLCB_ErrorIgnore(Handle owner, DBResultSet hndl, const char[] error, int Data)
{

}


public void SQLCB_DatabaseConnected(Handle owner, Database hndl, const char[] error, any data)
{
	if (hndl == INVALID_HANDLE)
	{
		SetFailState("Could not connect to database. Reason: %s", error);
	}
	else
	{
		char sIdentifier[11];
		hndl.Driver.GetIdentifier(sIdentifier, sizeof(sIdentifier));

		if(StrEqual(sIdentifier, "mysql", false))
		{
			INSERT_OR_IGNORE_INTO = "IGNORE INTO";
			SQL_UNIX_TIMESTAMP = "UNIX_TIMESTAMP()";
		}

		g_dbDailyQuests = hndl;

		OnDatabaseConnected();
	}
}

char SELECT_ALL_EXCEPT_PRIMARY_KEY[] = "AuthId, QuestAlias, DaysMultiplier, TimestampGiven, PrizeRNG, ObjectiveRNG, QuestProgress";

public void OnDatabaseConnected()
{
	Transaction transaction = SQL_CreateTransaction();

	char sQuery[512];
	char sFields[512];

	// Days Multiplier = 1 for daily quest, 7 for weekly, 3 or 4 for biweekly ( Nice try lol ), 30 for monthly, etc...
	sFields = "(RowSerialNumber INTEGER PRIMARY KEY AUTOINCREMENT, AuthId VARCHAR(32) NOT NULL, QuestAlias VARCHAR(32) NOT NULL, DaysMultiplier INT(11) NOT NULL, TimestampGiven INT(11) NOT NULL, PrizeRNG FLOAT(32) NOT NULL, ObjectiveRNG FLOAT(32) NOT NULL, QuestProgress INT(11) NOT NULL)";

	FormatEx(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS GunXP_DailyQuestsCompleted %s", sFields);
	SQL_AddQuery(transaction, sQuery);

	FormatEx(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS GunXP_DailyQuests %s", sFields);
	SQL_AddQuery(transaction, sQuery);

	g_dbDailyQuests.Execute(transaction, INVALID_FUNCTION, INVALID_FUNCTION, DBPrio_High);

	g_dbFullConnected = true;
}

public void Frame_FetchMissions(int userid)
{
	int client = GetClientOfUserId(userid);

	if(client == 0)
		return;

	else if(IsFakeClient(client))
		return;

	if(!g_dbFullConnected)
	{
		RequestFrame(Frame_FetchMissions, userid);

		return;
	}

	LoadClientMissions(client);
}

public void RPG_DailyQuests_OnGetMaxDailyQuests(int client, int &maxQuests)
{
	maxQuests += 2 + RoundToFloor(float(GunXP_RPG_GetClientRealLevel(client)) / 12.0);
}

void LoadClientMissions(int client)
{
	char AuthId[35]
	GetClientAuthId(client, AuthId_Steam2, AuthId, sizeof(AuthId));
	
	char sValues[4096];
	char sQuery[4096];

	Transaction transaction = SQL_CreateTransaction();

	int maxQuests;

	Call_StartForward(g_fwOnGetMaxDailyQuests);

	Call_PushCell(client);

	Call_PushCellRef(maxQuests);

	Call_Finish();

	ArrayList aQuests = g_aQuests.Clone();

	for(int i=0;i < aQuests.Length;i++)
	{
		enQuest quest;
		aQuests.GetArray(i, quest);

		if(quest.minLevel > GunXP_RPG_GetClientRealLevel(client))
		{
			aQuests.Erase(i);
			i--;
		}
	}

	for(int i=0;i < maxQuests;i++)
	{
		if(aQuests.Length == 0)
			break;

		enQuest quest;
		int RNG = GetRandomInt(0, aQuests.Length-1)


		aQuests.GetArray(RNG, quest);
		aQuests.Erase(RNG);

		Format(sValues, sizeof(sValues), "%s('%s', '%s', 1, %i, %.8f, %.8f, 0), ", sValues, AuthId, quest.sAlias, GetTime(), GetRandomFloat(0.0, 1.0), GetRandomFloat(0.0, 1.0));
	}

	delete aQuests;

	if(maxQuests <= 0)
		return;

	sValues[strlen(sValues)-2] = EOS;

	// Delete quests given yesterday
	g_dbDailyQuests.Format(sQuery, sizeof(sQuery), "DELETE FROM GunXP_DailyQuests WHERE AuthId = '%s' AND CAST(TimestampGiven / 86400 as int) < CAST(%!s / 86400 as int)", AuthId, SQL_UNIX_TIMESTAMP);

	SQL_AddQuery(transaction, sQuery);

	// Insert X quests equal to the maximum amount of daily quests user can have.
	g_dbDailyQuests.Format(sQuery, sizeof(sQuery), "INSERT %!s GunXP_DailyQuests (AuthId, QuestAlias, DaysMultiplier, TimestampGiven, PrizeRNG, ObjectiveRNG, QuestProgress) VALUES %!s", INSERT_OR_IGNORE_INTO, sValues);
	SQL_AddQuery(transaction, sQuery);

	// Delete every daily quest except the first x quests given, x = max quests.
	g_dbDailyQuests.Format(sQuery, sizeof(sQuery), "DELETE FROM GunXP_DailyQuests WHERE RowSerialNumber in (SELECT RowSerialNumber FROM GunXP_DailyQuests WHERE AuthId = '%s' LIMIT %i, 99999)", AuthId, maxQuests);
	SQL_AddQuery(transaction, sQuery);

	// Fetch actual daily quests of user.
	g_dbDailyQuests.Format(sQuery, sizeof(sQuery), "SELECT * FROM GunXP_DailyQuests WHERE AuthId = '%s'", AuthId);
	SQL_AddQuery(transaction, sQuery);

	g_dbDailyQuests.Execute(transaction, SQLTrans_LoadPlayerMissions, SQLTrans_SetFailState, GetClientUserId(client));
}

public void SQLTrans_LoadPlayerMissions(Database db, int userId, int numQueries, DBResultSet[] results, any[] queryData)
{
	int client = GetClientOfUserId(userId);

	if(client == 0)
		return;
	
	DBResultSet selection = results[3];

	ClearClientMissions(client);

	while(SQL_FetchRow(selection))
	{
		enClientQuest clientQuest;

		clientQuest.userid = userId;
		clientQuest.DBSerialNumber = SQL_FetchIntByName(selection, "RowSerialNumber");
		SQL_FetchStringByName(selection, "QuestAlias", clientQuest.sAlias, sizeof(enClientQuest::sAlias));
		clientQuest.fPrizeRNG = SQL_FetchFloatByName(selection, "PrizeRNG");
		clientQuest.fObjectiveRNG = SQL_FetchFloatByName(selection, "ObjectiveRNG");
		clientQuest.QuestProgress = SQL_FetchIntByName(selection, "QuestProgress");

		g_aClientQuests.PushArray(clientQuest);
	}
}

// Returns false if quest is invalid or unregistered, or if database didn't load yet.
stock bool AddClientQuestProgress(int client, char[] sAlias, int amount = 1)
{
	if(!g_dbFullConnected)
		return false;

	char name[128];
	int index = -1, progress, objective, prize;
	enPrizeType prizeType;
	bool bCompletedNow;


	while(GetClientQuests(client, sAlias, index, amount, name, progress, objective, prize, prizeType, bCompletedNow))
	{
		char sQuery[512];

		char AuthId[35]
		GetClientAuthId(client, AuthId_Steam2, AuthId, sizeof(AuthId));

		enClientQuest clientQuest;
		g_aClientQuests.GetArray(index, clientQuest);

		int RowSerialNumber = clientQuest.DBSerialNumber;

		if(bCompletedNow)
		{
			PrintToChat(client, "You earned %i XP for completing a daily quest!!!", prize);

			GunXP_RPG_EmitQuestCompletedSound(client);

			Transaction transaction = SQL_CreateTransaction();

			GunXP_RPG_AddClientXPTransaction(client, prize, false, transaction);

			g_dbDailyQuests.Format(sQuery, sizeof(sQuery), "UPDATE GunXP_DailyQuests SET QuestProgress = -1 WHERE AuthId = '%s' AND RowSerialNumber = %i", AuthId, RowSerialNumber);
			SQL_AddQuery(transaction, sQuery);

			g_dbDailyQuests.Format(sQuery, sizeof(sQuery), "INSERT %!s GunXP_DailyQuestsCompleted (%!s) SELECT %!s FROM GunXP_DailyQuests WHERE AuthId = '%s' AND RowSerialNumber = %i", INSERT_OR_IGNORE_INTO, SELECT_ALL_EXCEPT_PRIMARY_KEY, SELECT_ALL_EXCEPT_PRIMARY_KEY, AuthId, RowSerialNumber);
			SQL_AddQuery(transaction, sQuery);

			g_dbDailyQuests.Execute(transaction, INVALID_FUNCTION, SQLTrans_SetFailState, GetClientUserId(client));
		}
		else if(progress != -1)
		{
			g_dbDailyQuests.Format(sQuery, sizeof(sQuery), "UPDATE GunXP_DailyQuests SET QuestProgress = QuestProgress + %i WHERE AuthId = '%s' AND RowSerialNumber = %i", amount, AuthId, RowSerialNumber);

			g_dbDailyQuests.Query(SQLCB_Error, sQuery);	
		}
	}
	return true;

}

// bCompletedNow means that the value of "addProgress" completed the quest.

stock bool GetClientQuests(int client, char[] sAlias = "", int &index = -1, int addProgress = 0, char name[128], int &progress, int &objective, int &prize, enPrizeType &prizeType, bool &bCompletedNow)
{
	// Reset variables for this recursive function.
	name[0] = EOS;
	progress = 0;
	objective = 0;
	prize = 0;
	prizeType = PRIZE_XP;
	bCompletedNow = false;

	for(int a=index + 1;a < g_aClientQuests.Length;a++)
	{
		for(int i=0;i < g_aQuests.Length;i++)
		{
			enQuest quest;	
			g_aQuests.GetArray(i, quest);
			
			if(sAlias[0] == EOS || StrEqual(quest.sAlias, sAlias))
			{
				enClientQuest clientQuest;	
				g_aClientQuests.GetArray(a, clientQuest);

				if(clientQuest.userid == GetClientUserId(client) && StrEqual(quest.sAlias, clientQuest.sAlias))
				{
					index = a;
					return GetQuestData(client, a, quest, clientQuest, addProgress, name, progress, objective, prize, prizeType, bCompletedNow);
				}
			}
		}
	}

	return false;
}
stock bool GetQuestData(int client, int index, enQuest quest, enClientQuest clientQuest, int addProgress = 0, char name[128], int &progress, int &objective, int &prize, enPrizeType &prizeType, bool &bCompletedNow)
{
	if(addProgress != 0)
	{
		if(clientQuest.QuestProgress != -1)
		{
			clientQuest.QuestProgress += addProgress;

			if(clientQuest.QuestProgress >= GetGoalByRNG(quest.minObjective, quest.maxObjective, clientQuest.fObjectiveRNG))
			{
				bCompletedNow = true;
				clientQuest.QuestProgress = -1;
			}

			g_aClientQuests.SetArray(index, clientQuest);
		}
	}

	name = quest.sName;
	progress = clientQuest.QuestProgress;
	objective = GetGoalByRNG(quest.minObjective, quest.maxObjective, clientQuest.fObjectiveRNG);
	prize = GetGoalByRNG(quest.minPrize, quest.maxPrize, clientQuest.fPrizeRNG);
	prizeType = quest.prizeType;
	return true;
}

stock int GetGoalByRNG(int minObjective, int maxObjective, float fRNG)
{
	return RoundFloat(float(maxObjective - minObjective) * fRNG + float(minObjective));
}

stock void ClearClientMissions(int client)
{
	int userid = GetClientUserId(client);

	for(int i=0;i < g_aClientQuests.Length;i++)
	{
		enClientQuest clientQuest;
		g_aClientQuests.GetArray(i, clientQuest);

		if(clientQuest.userid == userid)
		{
			g_aClientQuests.Erase(i);
			i--;
		}
	}
}

methodmap EHANDLE {
	public int Get() {
	#if SOURCEMOD_V_MAJOR >= 1 && SOURCEMOD_V_MINOR >= 12 && SOURCEMOD_V_REV >= 6964
		return LoadEntityFromHandleAddress(view_as<Address>(this));
	#else
		static int s_iRandomOffsetToAnEHandle = -1;
		if (s_iRandomOffsetToAnEHandle == -1)
			s_iRandomOffsetToAnEHandle = FindSendPropInfo("CWorld", "m_hOwnerEntity");
		
		int temp = GetEntData(0, s_iRandomOffsetToAnEHandle, 4);
		SetEntData(0, s_iRandomOffsetToAnEHandle, this, 4);
		int result = GetEntDataEnt2(0, s_iRandomOffsetToAnEHandle);
		SetEntData(0, s_iRandomOffsetToAnEHandle, temp, 4);
		
		return result;
	#endif
	}
}

#if defined _actions_included
bool HasWitchAttacker(int client)
{

	int witch = -1;

	while( (witch = FindEntityByClassname(witch, "witch")) != INVALID_ENT_REFERENCE )
	{
		if( IsValidEdict(witch) )
		{
			BehaviorAction action = ActionsManager.GetAction(witch, "WitchAttack");

			if( action != INVALID_ACTION )
			{
				EHANDLE ehndl = action.Get(52);

				if( ehndl.Get() == client ) return true;
			}
		}
	}

	return false;
}
#else
bool HasWitchAttacker(int client)
{
	return client ? false : false
}
#endif

stock void FormatTimeHMS(char[] Time, int length, int timestamp, bool LimitTo24H = false)
{
	if(LimitTo24H)
		timestamp %= 86400;
	
	int HH, MM, SS;
	
	HH = timestamp / 3600
	MM = timestamp % 3600 / 60
	SS = timestamp % 3600 % 60 
	
	Format(Time, length, "%02d:%02d:%02d", HH, MM, SS);
}