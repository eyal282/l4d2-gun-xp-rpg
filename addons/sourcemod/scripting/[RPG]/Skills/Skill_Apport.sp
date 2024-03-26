
#include <GunXP-RPG>
#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <left4dhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"

Menu g_hVoteTankMenu;

int g_iLastTier;
int g_iLastTank;

float g_fVoteStartTime;

int g_iVotedItem[MAXPLAYERS+1];

public Plugin myinfo =
{
	name        = "Apport Skill --> Gun XP - RPG",
	author      = "Eyal282",
	description = "Skill that gives chance to vote what Tank you fight.",
	version     = PLUGIN_VERSION,
	url         = ""
};

int apportIndex;

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "GunXP_SkillShop"))
	{
		RegisterSkill();
	}
}

public void OnConfigsExecuted()
{
    RegisterSkill();

}
public void OnPluginStart()
{
    RegisterSkill();
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}

public void RPG_Perks_OnZombiePlayerSpawned(int client)
{
	if(RPG_Perks_GetZombieType(client) != ZombieType_Tank)
		return;

	else if(RPG_Tanks_GetClientTankTier(client) == TANK_TIER_UNKNOWN || RPG_Tanks_GetClientTankTier(client) == TANK_TIER_UNTIERED)
		return;

	float fChance = 0.0;
	
	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
			continue;
			
		else if(!GunXP_RPGShop_IsSkillUnlocked(i, apportIndex))
			continue;

		fChance += 0.125;
	}

	float fGamble = GetRandomFloat(0.0, 1.0);

	// If gamble fails or succeeds, break to prevent respawning everybody...
	if(fGamble >= fChance)
		return;

	StartVoteTank(client);
}


void StartVoteTank(int client)
{
	if (!IsNewVoteAllowed())
		return;	

	for(int i=0;i < sizeof(g_iVotedItem);i++)
	{
		g_iVotedItem[i] = -1;
	}

	g_iLastTier = RPG_Tanks_GetClientTankTier(client);
	g_iLastTank = GetClientUserId(client);

	g_fVoteStartTime = GetGameTime();

	BuildUpVoteTankMenu();

	VoteMenuToAll(g_hVoteTankMenu, 15);

	CreateTimer(1.0, Timer_DrawVoteTankMenu, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
}

public Action Timer_DrawVoteTankMenu(Handle hTimer)
{
	if (g_hVoteTankMenu == null)
		return Plugin_Stop;

	BuildUpVoteTankMenu();

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		else if (!IsVoteInProgress() || !IsClientInVotePool(i))
			continue;

		RedrawClientVoteMenu(i);
	}

	return Plugin_Continue;
}

void BuildUpVoteTankMenu()
{
	if (g_hVoteTankMenu == INVALID_HANDLE)
		g_hVoteTankMenu = CreateMenu(VoteTank_VoteHandler);

	SetMenuTitle(g_hVoteTankMenu, "Choose a Tier %i to Spawn: [%i]", g_iLastTier, RoundFloat((g_fVoteStartTime + 15) - GetGameTime()));

	RemoveAllMenuItems(g_hVoteTankMenu);

	int VoteList[128];

	VoteList = CalculateVotes();

	int index = 0, tier;
	char name[32];
	
	while(RPG_Tanks_LoopTankArray(index, tier, name))
	{
		if(tier == g_iLastTier)
		{
			char sInfo[11], TempFormat[128];
			IntToString(index, sInfo, sizeof(sInfo));

			FormatEx(TempFormat, sizeof(TempFormat), "%s [%i]", name, VoteList[index]);
			AddMenuItem(g_hVoteTankMenu, sInfo, TempFormat);
		}

		index++;
	}

	SetMenuPagination(g_hVoteTankMenu, MENU_NO_PAGINATION);
}

public int VoteTank_VoteHandler(Handle hMenu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(hMenu);
		g_hVoteTankMenu = null;
	}
	else if (action == MenuAction_VoteCancel)
	{
		if (param1 == VoteCancel_NoVotes)
		{
			g_hVoteTankMenu = null;
			return 0;
		}
	}
	else if (action == MenuAction_VoteEnd)
	{
		g_hVoteTankMenu = null;
		CheckVoteTankResult();
	}
	else if (action == MenuAction_Select)
	{
		char sInfo[11];
		GetMenuItem(hMenu, param2, sInfo, sizeof(sInfo));
		g_iVotedItem[param1] = StringToInt(sInfo);
	}

	return 0;
}

void CheckVoteTankResult()
{
	int client = GetClientOfUserId(g_iLastTank);

	if(client == 0)
		return;

	int VoteList[128];

	VoteList = CalculateVotes();

	int winnerTank = TANK_TIER_UNTIERED;

	int index = 0, tier;
	char name[32];
	
	while(RPG_Tanks_LoopTankArray(index, tier, name))
	{
		if(tier == g_iLastTier)
		{
			if(winnerTank == TANK_TIER_UNTIERED)
				winnerTank = index;

			else if (VoteList[index] > 0 && (VoteList[index] > VoteList[winnerTank] || (VoteList[index] == VoteList[winnerTank] && GetRandomInt(0, 1) == 1)))
				winnerTank = index;
		}

		index++;
	}

	g_hVoteTankMenu = null;

	// 0 Votes.
	if (winnerTank == TANK_TIER_UNTIERED)
		return;

	else if(RPG_Tanks_GetClientTank(client) == winnerTank)
		return;

	RPG_Tanks_SetClientTank(client, winnerTank);

}

stock int[] CalculateVotes()
{
	int arr[128];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		else if (g_iVotedItem[i] == -1)
			continue;

		arr[g_iVotedItem[i]]++;
	}

	return arr;
}

public void RegisterSkill()
{
    apportIndex = GunXP_RPGShop_RegisterSkill("Vote on Tank", "Apport", "When a Tank spawns, 12.5% chance to vote to replace it with another Tank of the same tier (Stacks)",
		40000, GunXP_RPG_GetXPForLevel(40));
}

