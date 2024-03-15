#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <Eyal-RP>

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

Handle g_dbDailyQuests;

char INSERT_OR_IGNORE_INTO[64];

enum QuestPrizes
{
	PRIZE_XP=0
}

enum struct Quest
{
	char sAlias[32];
	char sName[128];
	int minPrize;
	int maxPrize;
	int minObjective;
	int maxObjective;
	int minLevel;
	QuestPrizes prize;
}

// Quest after being given to a client.
enum struct ClientQuest
{
	char sAlias[32];

	int userid;

	// How close we are to max prize in %. Min 0.0 Max 1.0
	float fPrizeRNG;

	// How close we are to hardest objective in %. Min 0.0 Max 1.0
	float fObjectiveRNG;

	int progress;

	// The goal and prize will be calculated by using their respective RNG.
}

ArrayList g_aQuests;
ArrayList g_aClientQuests;

public void OnPluginStart()
{
	g_aQuests = new ArrayList(sizeof(Quests));
	g_aClientQuests = new ArrayList(sizeof(ClientQuests));

	CreateQuests();
	ConnectDatabase();
	
	RegConsoleCmd("sm_q", Command_Missions, "List of Missions");
	RegConsoleCmd("sm_quest", Command_Missions, "List of Missions");
	RegConsoleCmd("sm_quests", Command_Missions, "List of Missions");
	
}

public Action Command_Missions(int client, int args)
{
	
	for(int i=0;i < sizeof(ClientMissions[]);i++)
	{
		char TempFormat[128];
		FormatEx(TempFormat, sizeof(TempFormat), MissionTypeNames[ClientMissions[client][i].type]);
		
		Format(TempFormat, sizeof(TempFormat), "%s [%i/%i]", MissionTypeNames[ClientMissions[client][i].type],
		ClientMissions[client][i].progress, ClientMissions[client][i].targetProgress);
	}
	
	return Plugin_Handled;
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}

public void OnClientConnected(int client)
{
	for(int i=0;i < sizeof(ClientMissions[]);i++)
		ClientMissions[client][i].completed = true;
}

public void OnClientDisconnect(int client)
{
	for(int i=0;i < sizeof(ClientMissions[]);i++)
		ClientMissions[client][i].completed = true;
}

public void OnClientPostAdminCheck(int client)
{
	if(!g_dbFullConnected)
		return;
	
	LoadClientMissions(client);
}

void LoadClientMissions(int client, bool LowPrio=false)
{
	char AuthId[35]
	GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));
	
	char sQuery[256];
	SQL_FormatQuery(g_dbDailyQuests, sQuery, sizeof(sQuery), "SELECT * FROM GunXP_DailyQuests WHERE AuthId = '%s'", AuthId);

	if(!LowPrio)
		SQL_TQuery(g_dbDailyQuests, SQLCB_LoadClientMissions, sQuery, GetClientUserId(client));
	
	else
		SQL_TQuery(g_dbDailyQuests, SQLCB_LoadClientMissions, sQuery, GetClientUserId(client), DBPrio_Low);
}

public void CreateQuests()
{
	enQuest quest;

	quest.sAlias = "Kill Tanks";
	quest.sName = "Kill Tanks (Team)";
	quest.minPrize = 500;
	quest.maxPrize = 1000;
	quest.minObjective = 2;
	quest.maxObjective = 10;
	quest.minLevel = 0;
	quest.prize = PRIZE_XP;
	g_aQuests.PushArray(quest);

	quest.sAlias = "Kil";
	quest.sName = "Kill Tanks";
	quest.minPrize = 500;
	quest.maxPrize = 1000;
	quest.minObjective = 2;
	quest.maxObjective = 10;
	quest.minLevel = 0;
	quest.prize = PRIZE_XP;
	g_aQuests.PushArray(quest);

	quest.sAlias = "Kill Tanks";
	quest.sName = "Kill Tanks";
	quest.minPrize = 500;
	quest.maxPrize = 1000;
	quest.minObjective = 2;
	quest.maxObjective = 10;
	quest.minLevel = 0;
	quest.prize = PRIZE_XP;
	g_aQuests.PushArray(quest);

	quest.sAlias = "Kill Tanks";
	quest.sName = "Kill Tanks";
	quest.minPrize = 500;
	quest.maxPrize = 1000;
	quest.minObjective = 2;
	quest.maxObjective = 10;
	quest.minLevel = 0;
	quest.prize = PRIZE_XP;
	g_aQuests.PushArray(quest);
}

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
		}

		g_dbDailyQuests = hndl;

		OnDatabaseConnected();
	}
}

public void OnDatabaseConnected()
{
	g_dbDailyQuests.Query(SQLCB_Error, "CREATE TABLE IF NOT EXISTS GunXP_DailyQuests (AuthId VARCHAR(32) NOT NULL UNIQUE, TimestampGiven INT(11) NOT NULL, QuestAlias VARCHAR(32) NOT NULL, PrizeRNG FLOAT(32) NOT NULL, ObjectiveRNG FLOAT(32) NOT NULL)", 2, DBPrio_High);

	g_dbFullConnected = true;

	for (int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		OnClientPutInServer(i);
		
		if(IsClientAuthorized(i))
		{
			RequestFrame(FetchMissions, i);
		}
	}
}

public void SQLTrans_SetFailState(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	SetFailState("Transaction at index %i failed:\n%s", failIndex, error);
}


public void SQLCB_Error(Handle owner, DBResultSet hndl, const char[] Error, int QueryUniqueID)
{
	/* If something fucked up. */
	if (hndl == null)
		SetFailState("%s --> %i", Error, QueryUniqueID);
}

public void SQLCB_ErrorIgnore(Handle owner, DBResultSet hndl, const char[] Error, int Data)
{

}